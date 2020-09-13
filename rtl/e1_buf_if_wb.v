/*
 * e1_buf_if_wb.v
 *
 * vim: ts=4 sw=4
 *
 * E1 buffer interface to wishbone master conversion
 *
 * Copyright (C) 2019-2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-W-2.0
 */

`default_nettype none

module e1_buf_if_wb #(
	parameter integer N = 1,					// Number of units
	parameter UNIT_HAS_RX = 1'b1,				// 1 bit per unit
	parameter UNIT_HAS_TX = 1'b1,				// 1 bit per unit
	parameter integer MFW = 7,					// Multi-Frame width
	parameter integer DW = 32,					// 16 or 32

	// auto-set parameters
	parameter integer MW = DW / 8,				// Mask Width
	parameter integer AW = MFW + 9 - $clog2(MW)	// Address Width
)(
	// Wishbone master
	output reg  [AW-1:0] wb_addr,
	input  wire [DW-1:0] wb_rdata,
	output wire [DW-1:0] wb_wdata,
	output wire [MW-1:0] wb_wmsk,
	output wire          wb_cyc,
	output wire          wb_we,
	input  wire          wb_ack,

	// Buffer interface
		// E1 RX (write)
	input  wire [(N*8)  -1:0] buf_rx_data,
	input  wire [(N*5)  -1:0] buf_rx_ts,
	input  wire [(N*4)  -1:0] buf_rx_frame,
	input  wire [(N*MFW)-1:0] buf_rx_mf,
	input  wire [ N     -1:0] buf_rx_we,
	output wire [ N     -1:0] buf_rx_rdy,

		// E1 TX (read)
	output wire [(N*8)  -1:0] buf_tx_data,
	input  wire [(N*5)  -1:0] buf_tx_ts,
	input  wire [(N*4)  -1:0] buf_tx_frame,
	input  wire [(N*MFW)-1:0] buf_tx_mf,
	input  wire [ N     -1:0] buf_tx_re,
	output wire [ N     -1:0] buf_tx_rdy,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	localparam integer LW = $clog2(MW);		// LSB width
	localparam integer FW = AW + LW;		// Full-Address width
	localparam integer CW = $clog2(2*N);	// Channel width


	// Signals
	// -------

	genvar i;

	// RX
	reg  [ N-1:0] rx_pending;
	wire [ N-1:0] rx_done;
	reg  [   7:0] rx_data_reg[0:N-1];
	reg  [FW-1:0] rx_addr_reg[0:N-1];

	// TX
	reg  [ N-1:0] tx_pending;
	wire [ N-1:0] tx_done;
	reg  [   7:0] tx_data_reg[0:N-1];
	reg  [FW-1:0] tx_addr_reg[0:N-1];

	// Transactions
	wire [2*N-1:0] t_pending;
	reg  [2*N-1:0] t_done;

	reg            t_nxt_busy;
	reg            t_busy;
	reg   [CW-1:0] t_nxt_chan;
	reg   [CW-1:0] t_chan; // MSB = RX(0) / TX(1)

	reg   [LW-1:0] wb_addr_lsb;
	reg   [   7:0] wb_wdata_byte;
	wire  [   7:0] wb_rdata_mux;


	// E1 RX (write)
	// -------------

	generate
		for (i=0; i<N; i=i+1) begin
			if (UNIT_HAS_RX[i]) begin

				// Capture
				always @(posedge clk)
					if (buf_rx_we[i]) begin
						rx_data_reg[i] <= buf_rx_data[8*i+:8];
						rx_addr_reg[i] <= {
							buf_rx_mf [MFW*i+:MFW],
							buf_rx_frame[4*i+:  4],
							buf_rx_ts   [5*i+:  5]
						};
					end

				// Pending flag
				always @(posedge clk or posedge rst)
					if (rst)
						rx_pending[i] <= 1'b0;
					else
						rx_pending[i] <= (rx_pending[i] | buf_rx_we[i]) & ~rx_done[i];

				// Ready status
				assign buf_rx_rdy[i] = ~rx_pending[i];

			end else begin

				// Dummy
				always @(posedge clk)
				begin
					rx_pending[i]  <= 0;
					rx_data_reg[i] <= 8'h00;
					rx_addr_reg[i] <= 0;
				end

			end
		end
	endgenerate


	// E1 TX (read)
	// ------------

	generate
		for (i=0; i<N; i=i+1) begin
			if (UNIT_HAS_TX[i]) begin

				// Capture
				always @(posedge clk)
					if (buf_tx_re[i]) begin
						tx_addr_reg[i] <= {
							buf_tx_mf [MFW*i+:MFW],
							buf_tx_frame[4*i+:  4],
							buf_tx_ts   [5*i+:  5]
						};
					end

				// Pending flag
				always @(posedge clk or posedge rst)
					if (rst)
						tx_pending[i] <= 1'b0;
					else
						tx_pending[i] <= (tx_pending[i] | buf_tx_re[i]) & ~tx_done[i];

				// Ready status
				assign buf_tx_rdy[i] = ~tx_pending[i];

				// Read data
				always @(posedge clk)
					if (tx_done[i])
						tx_data_reg[i] <= wb_rdata_mux;

				assign buf_tx_data[8*i+:8] = tx_data_reg[i];

			end else begin

				// Dummy
				always @(posedge clk)
				begin
					tx_pending[i]  <= 0;
					tx_data_reg[i] <= 8'h00;
					tx_addr_reg[i] <= 0;
				end

			end
		end
	endgenerate


	// Wishbone transactions
	// ---------------------

	// "Next" selection
	assign t_pending = { tx_pending, rx_pending };

	always @(*)
	begin : next_sel
		integer j;

		// Anything pending ?
		t_nxt_busy = |t_pending;

		// Select one
		t_nxt_chan = 0;

		for (j=0; j<2*N; j=j+1)
			if (t_pending[j])
				t_nxt_chan = j;
	end

	// State
	always @(posedge clk or posedge rst)
		if (rst)
			t_busy <= 1'b0;
		else
			t_busy <= wb_ack ? 1'b0 : t_nxt_busy;

	always @(posedge clk)
		if (~t_busy)
			t_chan <= t_nxt_chan;

	// Cycle
	assign wb_cyc = t_busy;
	assign wb_we  = ~t_chan[CW-1];

	// Muxing
	always @(posedge clk)
	begin : mux
		integer j;
		if (~t_busy) begin
			// Defaults
			wb_wdata_byte <= 8'hxx;
			wb_addr       <= 0;
			wb_addr_lsb   <= 0;

			// Find match
				// RX
			for (j=0; j<N; j=j+1)
				if (t_nxt_chan == j) begin
					wb_wdata_byte <= rx_data_reg[j];
					wb_addr       <= rx_addr_reg[j][FW-1:LW];
					wb_addr_lsb   <= rx_addr_reg[j][LW-1: 0];
				end

				// TX
			for (j=0; j<N; j=j+1)
				if (t_nxt_chan == (N+j)) begin
					wb_addr       <= tx_addr_reg[j][FW-1:LW];
					wb_addr_lsb   <= tx_addr_reg[j][LW-1: 0];
				end
		end
	end

	// Write data map
	generate
		for (i=0; i<MW; i=i+1)
		begin
			assign wb_wdata[8*i+:8] = wb_wdata_byte;
			assign wb_wmsk[i] = wb_addr_lsb != i;
		end
	endgenerate

	// Read mux between bytes
	assign wb_rdata_mux = wb_rdata[8*wb_addr_lsb+:8];

	// Done signals
	always @(*)
	begin
		// Default is no change
		t_done = 0;

		// If we have a 'ack', see who got completed
		if (wb_ack)
			t_done[t_chan] = 1'b1;
	end

	assign { tx_done, rx_done } = t_done;

endmodule // e1_buf_if_wb
