/*
 * e1_wb_rx.v
 *
 * vim: ts=4 sw=4
 *
 * E1 wishbone RX submodule - NOT MEANT TO BE USED INDEPENDENTLY
 *
 * Copyright (C) 2019-2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-W-2.0
 */

`default_nettype none

module e1_wb_rx #(
	parameter integer LIU = 0,
	parameter integer MFW = 7
)(
	// IO pads
		// Raw PHY
	input  wire pad_rx_hi_p,
	input  wire pad_rx_hi_n,
	input  wire pad_rx_lo_p,
	input  wire pad_rx_lo_n,

		// LIU
	input  wire pad_rx_data,
	input  wire pad_rx_clk,

	// Buffer interface
	output wire     [7:0] buf_rx_data,
	output wire     [4:0] buf_rx_ts,
	output wire     [3:0] buf_rx_frame,
	output wire [MFW-1:0] buf_rx_mf,
	output wire           buf_rx_we,
	input  wire           buf_rx_rdy,

	// Bus interface
	input  wire        bus_addr_sel,
	input  wire  [0:0] bus_addr_lsb,
	input  wire [15:0] bus_wdata,
	output wire [15:0] bus_rdata,
	input  wire        bus_clr,
	input  wire        bus_we,

	// RX/TX cross status
	output reg  [1:0] tx_crc_e_auto,
	input  wire       tx_crc_e_ack,

	// External strobes
	output wire irq,
	output wire [2:0] mon_tick,

	// Loopback path
	output wire lb_bit,
	output wire lb_valid,

	// Common
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// CSRs and bus access
	reg  crx_wren;
	reg  crx_clear;

	wire [15:0] bus_rd_rx_status;
	wire [15:0] bus_rd_rx_bdout;

	// FIFOs
		// BD RX In
	wire [MFW-1:0] bri_di;
	wire [MFW-1:0] bri_do;
	reg  bri_wren;
	wire bri_rden;
	wire bri_full;
	wire bri_empty;

		// BD RX Out
	wire [MFW+1:0] bro_di;
	wire [MFW+1:0] bro_do;
	wire bro_wren;
	reg  bro_rden;
	wire bro_full;
	wire bro_empty;

	// Control
	reg  rx_rst;
	reg  rx_enabled;
	reg  [1:0] rx_mode;
	wire rx_aligned;
	reg  rx_overflow;

	// BD interface
	wire [MFW-1:0] bdrx_mf;
	wire [1:0] bdrx_crc_e;
	wire bdrx_valid;
	wire bdrx_done;
	wire bdrx_miss;


	// CSRs & FIFO bus access
	// ----------------------

	// Control WrEn
	always @(posedge clk)
		if (bus_clr | ~bus_we) begin
			crx_wren  <= 1'b0;
			crx_clear <= 1'b0;
		end else begin
			crx_wren  <= bus_addr_sel & (bus_addr_lsb == 1'b0);
			crx_clear <= bus_addr_sel & (bus_addr_lsb == 1'b0) & bus_wdata[12];
		end

	// Control regs
	always @(posedge clk or posedge rst)
		if (rst) begin
			rx_mode     <= 2'b00;
			rx_enabled  <= 1'b0;
		end else if (crx_wren) begin
			rx_mode     <= bus_wdata[2:1];
			rx_enabled  <= bus_wdata[0];
		end

	// Status data
	assign bus_rd_rx_status = {
		3'b000,
		rx_overflow,
		bro_full,
		bro_empty,
		bri_full,
		bri_empty,
		6'b000000,
		rx_aligned,
		rx_enabled
	};

	// BD FIFO WrEn / RdEn
		// (note we must mask on full/empty here to be consistent with what we
		//  return in the data !)
	always @(posedge clk)
		if (bus_clr) begin
			bri_wren <= 1'b0;
			bro_rden <= 1'b0;
		end else begin
			bri_wren <=  bus_we & ~bri_full  & bus_addr_sel & (bus_addr_lsb == 1'b1);
			bro_rden <= ~bus_we & ~bro_empty & bus_addr_sel & (bus_addr_lsb == 1'b1);
		end

	// BD FIFO Data
	assign bri_di = bus_wdata[MFW-1:0];

	assign bus_rd_rx_bdout = { ~bro_empty, bro_do[MFW+1:MFW], {(13-MFW){1'b0}}, bro_do[MFW-1:0] };

	// Read Mux
	assign bus_rdata = bus_addr_sel ? ( bus_addr_lsb[0] ? bus_rd_rx_bdout : bus_rd_rx_status ) : 16'h0000;
//	{ 16{bus_addr_sel} } & (bus_addr_lsb[0] ? bus_rd_rx_bdout : bus_rd_rx_status);


	// BD fifos
	// --------

	// BD RX In
	fifo_sync_shift #(
		.DEPTH(4),
		.WIDTH(MFW)
	) bd_rx_in_I (
		.wr_data(bri_di),
		.wr_ena(bri_wren),
		.wr_full(bri_full),
		.rd_data(bri_do),
		.rd_ena(bri_rden),
		.rd_empty(bri_empty),
		.clk(clk),
		.rst(rst)
	);

	// BD RX Out
	fifo_sync_shift #(
		.DEPTH(4),
		.WIDTH(MFW+2)
	) bd_rx_out_I (
		.wr_data(bro_di),
		.wr_ena(bro_wren),
		.wr_full(bro_full),
		.rd_data(bro_do),
		.rd_ena(bro_rden),
		.rd_empty(bro_empty),
		.clk(clk),
		.rst(rst)
	);


	// RX submodule
	// ------------

	// RX core
	e1_rx #(
		.LIU(LIU),
		.MFW(MFW)
	) rx_I (
		.pad_rx_hi_p(pad_rx_hi_p),
		.pad_rx_hi_n(pad_rx_hi_n),
		.pad_rx_lo_p(pad_rx_lo_p),
		.pad_rx_lo_n(pad_rx_lo_n),
		.pad_rx_data(pad_rx_data),
		.pad_rx_clk(pad_rx_clk),
		.buf_data(buf_rx_data),
		.buf_ts(buf_rx_ts),
		.buf_frame(buf_rx_frame),
		.buf_mf(buf_rx_mf),
		.buf_we(buf_rx_we),
		.buf_rdy(buf_rx_rdy),
		.bd_mf(bdrx_mf),
		.bd_crc_e(bdrx_crc_e),
		.bd_valid(bdrx_valid),
		.bd_done(bdrx_done),
		.bd_miss(bdrx_miss),
		.lb_bit(lb_bit),
		.lb_valid(lb_valid),
		.ctrl_mode_mf(rx_mode[0]),
		.status_aligned(rx_aligned),
		.mon_tick(mon_tick),
		.clk(clk),
		.rst(rx_rst)
	);

	// BD FIFO interface
	assign bdrx_mf    =  bri_do;
	assign bdrx_valid = ~bri_empty;

	assign bri_rden = bdrx_done;

	assign bro_di   = { bdrx_crc_e, bdrx_mf };
	assign bro_wren = ~bro_full & bdrx_done;

	// Control logic
		// Local reset
	always @(posedge clk or posedge rst)
		if (rst)
			rx_rst <= 1'b1;
		else
			rx_rst <= ~rx_enabled;

		// Overflow
	always @(posedge clk or posedge rst)
		if (rst)
			rx_overflow <= 1'b0;
		else
			rx_overflow <= (rx_overflow & ~crx_clear) | bdrx_miss;

	// Generate auto E bits for TX side
	always @(posedge clk)
		tx_crc_e_auto <= (tx_crc_e_ack ? {2{rx_aligned}} : tx_crc_e_auto) & (bdrx_done ? bdrx_crc_e : 2'b11);


	// External strobes
	// ----------------

	assign irq  = ~bro_empty | rx_overflow;

endmodule // e1_wb_rx
