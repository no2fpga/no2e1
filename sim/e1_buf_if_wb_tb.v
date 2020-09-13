/*
 * e1_buf_if_wb_tb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019-2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-W-2.0
 */

`default_nettype none
`timescale 1ns / 100ps

module e1_buf_if_wb_tb;

	// Signals
	reg rst = 1;
	reg clk = 1;

	// Wishbone master
	wire [13:0] wb_addr;
	wire [31:0] wb_rdata;
	wire [31:0] wb_wdata;
	wire [ 3:0] wb_wmsk;
	wire        wb_cyc;
	wire        wb_we;
	reg         wb_ack;

	// Buffer interface
	wire [15:0] buf_rx_data;
	wire [ 9:0] buf_rx_ts;
	wire [ 7:0] buf_rx_frame;
	wire [13:0] buf_rx_mf;
	wire [ 1:0] buf_rx_we;
	wire [ 1:0] buf_rx_rdy;

	wire [15:0] buf_tx_data;
	wire [ 9:0] buf_tx_ts;
	wire [ 7:0] buf_tx_frame;
	wire [13:0] buf_tx_mf;
	wire [ 1:0] buf_tx_re;
	wire [ 1:0] buf_tx_rdy;

	// Setup recording
	initial begin
		$dumpfile("e1_buf_if_wb_tb.vcd");
		$dumpvars(0,e1_buf_if_wb_tb);
	end

	// Reset pulse
	initial begin
		# 31 rst = 0;
		# 20000 $finish;
	end

	// Clocks
	always #5 clk = !clk;

	// DUT
	e1_buf_if_wb #(
		.N(2),
		.UNIT_HAS_RX(2'b01),
		.UNIT_HAS_TX(2'b11),
		.MFW(7),
		.DW(32)
	) e1_I (
		.wb_addr     (wb_addr),
		.wb_rdata    (wb_rdata),
		.wb_wdata    (wb_wdata),
		.wb_wmsk     (wb_wmsk),
		.wb_cyc      (wb_cyc),
		.wb_we       (wb_we),
		.wb_ack      (wb_ack),
		.buf_rx_data (buf_rx_data),
		.buf_rx_ts   (buf_rx_ts),
		.buf_rx_frame(buf_rx_frame),
		.buf_rx_mf   (buf_rx_mf),
		.buf_rx_we   (buf_rx_we),
		.buf_rx_rdy  (buf_rx_rdy),
		.buf_tx_data (buf_tx_data),
		.buf_tx_ts   (buf_tx_ts),
		.buf_tx_frame(buf_tx_frame),
		.buf_tx_mf   (buf_tx_mf),
		.buf_tx_re   (buf_tx_re),
		.buf_tx_rdy  (buf_tx_rdy),
		.clk         (clk),
		.rst         (rst)
	);

	// Dummy wishbone responder
	always @(posedge clk)
		wb_ack <= wb_cyc & ~wb_ack;

	assign wb_rdata = 32'h01234567;

	//
	reg        rdy;
	reg [31:0] cnt;
	reg [ 3:0] sub;

	always @(posedge clk)
		if (rst)
			rdy <= 1'b0;
		else
			rdy <= 1'b1;

	always @(posedge clk)
		if (rst)
			cnt <= 0;
		else if (wb_ack)
			cnt <= cnt + 1;

	always @(posedge clk)
		if (rst)
			sub <= 0;
		else
			sub <= {
				($random & 7) == 0,
				($random & 7) == 0,
				($random & 7) == 0,
				($random & 7) == 0
			};

	// RX submit
	assign buf_rx_data  = { 8'hxx,     8'h34 };
	assign buf_rx_ts    = {  5'dx,  cnt[4:0] };
	assign buf_rx_frame = {  4'dx,  cnt[8:5] };
	assign buf_rx_mf    = {  7'dx, cnt[15:9] };
	assign buf_rx_we    = buf_rx_rdy & { 1'b0, sub[0] };

	// TX submit
	assign buf_tx_ts    = {   5'd7,  cnt[4:0] };
	assign buf_tx_frame = {   4'd2,  cnt[8:5] };
	assign buf_tx_mf    = { 7'd100, cnt[15:9] };
	assign buf_tx_re    = buf_tx_rdy & sub[3:2];

endmodule // e1_buf_if_wb_tb
