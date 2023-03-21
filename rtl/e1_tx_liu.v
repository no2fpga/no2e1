/*
 * e1_tx_liu.v
 *
 * vim: ts=4 sw=4
 *
 * E1 RX interface to external LIU
 *
 * Copyright (C) 2019-2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-W-2.0
 */

`default_nettype none

module e1_tx_liu (
	// Pads
	input  wire pad_tx_data,
	input  wire pad_tx_clk,

	// Intput
	input  wire in_data,
	input  wire in_valid,

	// Common
	input  wire clk,
	input  wire rst
);
	// Signals
	reg [5:0] cnt_cur;
	reg [5:0] cnt_nxt;

	reg  tx_data;
	wire tx_clk;

	// Counters
	always @(posedge clk)
		if (in_valid)
			cnt_nxt <= 0;
		else
			cnt_nxt <= cnt_nxt + 1;

	always @(posedge clk)
		if (in_valid)
			cnt_cur <= { 1'b1, cnt_nxt[5:1] };
		else
			cnt_cur <= cnt_cur - 1;

	// TX
	always @(posedge clk)
		if (in_valid)
			tx_data <= in_data;

	assign tx_clk = cnt_cur[5];

	// IOBs (registered)
	SB_IO #(
		.PIN_TYPE(6'b0101_00),
		.PULLUP(1'b0),
		.NEG_TRIGGER(1'b0)
	) tx_data_iob_I (
		.PACKAGE_PIN(pad_tx_data),
		.CLOCK_ENABLE(1'b1),
		.INPUT_CLK(1'b0),
		.OUTPUT_CLK(clk),
		.OUTPUT_ENABLE(1'b1),
		.D_OUT_0(tx_data),
		.D_OUT_1(1'b0),
		.D_IN_0(),
		.D_IN_1()
	);

	SB_IO #(
		.PIN_TYPE(6'b0101_00),
		.PULLUP(1'b0),
		.NEG_TRIGGER(1'b0)
	) tx_clk_iob_I (
		.PACKAGE_PIN(pad_tx_clk),
		.CLOCK_ENABLE(1'b1),
		.INPUT_CLK(1'b0),
		.OUTPUT_CLK(clk),
		.OUTPUT_ENABLE(1'b1),
		.D_OUT_0(tx_clk),
		.D_OUT_1(1'b0),
		.D_IN_0(),
		.D_IN_1()
	);

endmodule // e1_tx_liu
