/*
 * e1_rx_liu.v
 *
 * vim: ts=4 sw=4
 *
 * E1 RX interface to external LIU
 *
 * Copyright (C) 2019-2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-W-2.0
 */

`default_nettype none

module e1_rx_liu (
	// Pads
	input  wire pad_rx_data,
	input  wire pad_rx_clk,

	// Output
	output reg  out_data,
	output reg  out_valid,

	// Common
	input  wire clk,
	input  wire rst
);

	wire rx_data;
	wire rx_clk;

	reg  rx_data_r;
	reg  rx_clk_r;

	// IOBs (registered)
	SB_IO #(
		.PIN_TYPE(6'b0000_00),
		.PULLUP(1'b0),
		.NEG_TRIGGER(1'b0)
	) rx_iobs_I[1:0] (
		.PACKAGE_PIN({pad_rx_data, pad_rx_clk}),
		.LATCH_INPUT_VALUE(1'b0),
		.CLOCK_ENABLE(1'b1),
		.INPUT_CLK(clk),
		.OUTPUT_CLK(1'b0),
		.OUTPUT_ENABLE(1'b0),
		.D_OUT_0(1'b0),
		.D_OUT_1(1'b0),
		.D_IN_0({rx_data, rx_clk}),
		.D_IN_1()
	);

	// First internal register
	always @(posedge clk)
	begin
		rx_data_r <= rx_data;
		rx_clk_r  <= rx_clk;
	end

	// Second internal register + clk falling edge detect
	always @(posedge clk)
	begin
		out_data  <= rx_data_r;
		out_valid <= rx_clk_r & ~rx_clk;
	end

endmodule // e1_rx_liu
