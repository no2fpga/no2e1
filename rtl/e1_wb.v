/*
 * e1_wb.v
 *
 * vim: ts=4 sw=4
 *
 * E1 wishbone top-level
 *
 * Copyright (C) 2019-2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-W-2.0
 */

`default_nettype none

module e1_wb #(
	parameter integer N = 1,		// Number of units
	parameter UNIT_HAS_RX = 1'b1,	// 1 bit per unit
	parameter UNIT_HAS_TX = 1'b1,	// 1 bit per unit
	parameter integer LIU = 0,
	parameter integer MFW = 7
)(
	// IO pads
		// Raw PHY
	input  wire [N-1:0] pad_rx_hi_p,
	input  wire [N-1:0] pad_rx_hi_n,
	input  wire [N-1:0] pad_rx_lo_p,
	input  wire [N-1:0] pad_rx_lo_n,

	output wire [N-1:0] pad_tx_hi,
	output wire [N-1:0] pad_tx_lo,

		// LIU
	input  wire [N-1:0] pad_rx_data,
	input  wire [N-1:0] pad_rx_clk,

	output wire [N-1:0] pad_tx_data,
	output wire [N-1:0] pad_tx_clk,

	// Buffer interface
		// E1 RX (write)
	output wire [(N*8)  -1:0] buf_rx_data,
	output wire [(N*5)  -1:0] buf_rx_ts,
	output wire [(N*4)  -1:0] buf_rx_frame,
	output wire [(N*MFW)-1:0] buf_rx_mf,
	output wire [ N     -1:0] buf_rx_we,
	input  wire [ N     -1:0] buf_rx_rdy,

		// E1 TX (read)
	input  wire [(N*8)  -1:0] buf_tx_data,
	output wire [(N*5)  -1:0] buf_tx_ts,
	output wire [(N*4)  -1:0] buf_tx_frame,
	output wire [(N*MFW)-1:0] buf_tx_mf,
	output wire [ N     -1:0] buf_tx_re,
	input  wire [ N     -1:0] buf_tx_rdy,

	// Wishbone slave
	input  wire [ 7:0] wb_addr,
	output reg  [15:0] wb_rdata,
	input  wire [15:0] wb_wdata,
	input  wire        wb_we,
	input  wire        wb_cyc,
	output reg         wb_ack,

	// External strobes
	output reg            irq,
	output wire [4*N-1:0] mon_tick,

	// Common
	input  wire clk,
	input  wire rst
);

	// --------------------------------------------------------------------------
	// Common part
	// --------------------------------------------------------------------------

	localparam integer MB = $clog2(2*N);


	// Signals
	// -------

	// Bus access
	wire        bus_clr;

	wire [ 0:0] bus_addr_lsb;
	wire [15:0] bus_rdata_rx[0:N-1];
	wire [15:0] bus_rdata_tx[0:N-1];
	reg  [15:0] bus_rdata;
	wire [15:0] bus_wdata;
	wire        bus_we;

	// Loopback paths
	wire [N-1:0] lb_bit;
	wire [N-1:0] lb_valid;

	// IRQs
	wire [N-1:0] irq_rx;
	wire [N-1:0] irq_tx;


	// Bus access
	// ----------

	// Ack is always 1 cycle after access
	always @(posedge clk)
		wb_ack <= wb_cyc & ~wb_ack;

	assign bus_clr = ~wb_cyc | wb_ack;

	// Direct map of some signals to custom local bus
	assign bus_addr_lsb = wb_addr[0];
	assign bus_wdata = wb_wdata;
	assign bus_we = wb_we;

	// Read MUX
	always @(*)
	begin : rdata_or
		integer j;
		bus_rdata = 0;
		for (j=0; j<N; j=j+1)
			bus_rdata = bus_rdata | bus_rdata_rx[j] | bus_rdata_tx[j];
    end

	always @(posedge clk)
		if (bus_clr)
			wb_rdata <= 16'h0000;
		else
			wb_rdata <= bus_rdata;


	// --------------------------------------------------------------------------
	// Per-unit part
	// --------------------------------------------------------------------------

	genvar i;

	generate
		for (i=0; i<N; i=i+1)
		begin
			// Signals
			// -------

			// Address pre-match
			(* keep *) wire bus_addr_sel_rx;
			(* keep *) wire bus_addr_sel_tx;

			assign bus_addr_sel_rx = (wb_addr[MB:1] == (2*i+0));
			assign bus_addr_sel_tx = (wb_addr[MB:1] == (2*i+1));

			// Cross status
			wire [1:0] tx_crc_e_auto;
			wire       tx_crc_e_ack;

			// Loopback path
			wire lb_bit_cross;
			wire lb_valid_cross;


			// RX
			// --

			if (UNIT_HAS_RX[i]) begin

				// Sub-Instance
				e1_wb_rx #(
					.LIU(LIU),
					.MFW(MFW)
				) srx_I (
					.pad_rx_hi_p  (pad_rx_hi_p[i]),
					.pad_rx_hi_n  (pad_rx_hi_n[i]),
					.pad_rx_lo_p  (pad_rx_lo_p[i]),
					.pad_rx_lo_n  (pad_rx_lo_n[i]),
					.pad_rx_data  (pad_rx_data[i]),
					.pad_rx_clk   (pad_rx_clk[i]),
					.buf_rx_data  (buf_rx_data [i*8+:8]),
					.buf_rx_ts    (buf_rx_ts   [i*5+:5]),
					.buf_rx_frame (buf_rx_frame[i*4+:4]),
					.buf_rx_mf    (buf_rx_mf   [i*MFW+:MFW]),
					.buf_rx_we    (buf_rx_we   [i]),
					.buf_rx_rdy   (buf_rx_rdy  [i]),
					.bus_addr_sel (bus_addr_sel_rx),
					.bus_addr_lsb (bus_addr_lsb),
					.bus_wdata    (bus_wdata),
					.bus_rdata    (bus_rdata_rx[i]),
					.bus_clr      (bus_clr),
					.bus_we       (bus_we),
					.tx_crc_e_auto(tx_crc_e_auto),
					.tx_crc_e_ack (tx_crc_e_ack),
					.irq          (irq_rx[i]),
					.mon_tick     (mon_tick[4*i+1+:3]),
					.lb_bit       (lb_bit[i]),
					.lb_valid     (lb_valid[i]),
					.clk          (clk),
					.rst          (rst)
				);

			end else begin

				// Dummy
				assign lb_bit[i]   = 1'b0;
				assign lb_valid[i] = 1'b0;

				assign bus_rdata_rx[i] = 16'h0000;

				assign tx_crc_e_auto = 2'b00;

				assign irq_rx[i] = 1'b0;

				assign mon_tick[4*i+1+:3] = 3'b000;

			end


			// TX
			// --

			if (UNIT_HAS_TX[i]) begin

				// Sub-Instance
				e1_wb_tx #(
					.LIU(LIU),
					.MFW(MFW)
				) stx_I (
					.pad_tx_hi    (pad_tx_hi[i]),
					.pad_tx_lo    (pad_tx_lo[i]),
					.pad_tx_data  (pad_tx_data[i]),
					.pad_tx_clk   (pad_tx_clk[i]),
					.buf_tx_data  (buf_tx_data [i*8+:8]),
					.buf_tx_ts    (buf_tx_ts   [i*5+:5]),
					.buf_tx_frame (buf_tx_frame[i*4+:4]),
					.buf_tx_mf    (buf_tx_mf   [i*MFW+:MFW]),
					.buf_tx_re    (buf_tx_re   [i]),
					.buf_tx_rdy   (buf_tx_rdy  [i]),
					.bus_addr_sel (bus_addr_sel_tx),
					.bus_addr_lsb (bus_addr_lsb),
					.bus_wdata    (bus_wdata),
					.bus_rdata    (bus_rdata_tx[i]),
					.bus_clr      (bus_clr),
					.bus_we       (bus_we),
					.tx_crc_e_auto(tx_crc_e_auto),
					.tx_crc_e_ack (tx_crc_e_ack),
					.irq          (irq_tx[i]),
					.mon_tick     (mon_tick[4*i]),
					.lb_bit       ({lb_bit_cross,   lb_bit[i]  }),
					.lb_valid     ({lb_valid_cross, lb_valid[i]}),
					.clk          (clk),
					.rst          (rst)
				);

				// Loopback cross-path
				if (((i^1) < N) && UNIT_HAS_RX[i^1]) begin
					assign lb_bit_cross   = lb_bit[i^1];
					assign lb_valid_cross = lb_valid[i^1];
				end else begin
					assign lb_bit_cross   = 1'b0;
					assign lb_valid_cross = 1'b0;
				end

			end else begin

				// Dummy
				assign bus_rdata_tx[i] = 16'h0000;
				assign irq_tx[i] = 1'b0;

				assign mon_tick[4*i] = 1'b0;

			end

		end
	endgenerate

endmodule // e1_wb
