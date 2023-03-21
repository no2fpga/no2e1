/*
 * e1_tx_phy.v
 *
 * vim: ts=4 sw=4
 *
 * E1 TX IOB instances
 *
 * Copyright (C) 2019-2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-W-2.0
 */

`default_nettype none

module e1_tx_phy (
	// IO pads
	output wire pad_tx_hi,
	output wire pad_tx_lo,

	// Input
	input  wire tx_hi,
	input  wire tx_lo,

	// Common
	input  wire clk,
	input  wire rst
);

    SB_IO #(
        .PIN_TYPE(6'b010100),
        .PULLUP(1'b0),
        .NEG_TRIGGER(1'b0),
        .IO_STANDARD("SB_LVCMOS")
    ) tx_hi_I (
        .PACKAGE_PIN(pad_tx_hi),
        .CLOCK_ENABLE(1'b1),
        .INPUT_CLK(1'b0),
        .OUTPUT_CLK(clk),
        .OUTPUT_ENABLE(1'b0),
        .D_OUT_0(tx_hi),
        .D_OUT_1(1'b0),
        .D_IN_0(),
        .D_IN_1()
    );

    SB_IO #(
        .PIN_TYPE(6'b010100),
        .PULLUP(1'b0),
        .NEG_TRIGGER(1'b0),
        .IO_STANDARD("SB_LVCMOS")
    ) tx_lo_I (
        .PACKAGE_PIN(pad_tx_lo),
        .CLOCK_ENABLE(1'b1),
        .INPUT_CLK(1'b0),
        .OUTPUT_CLK(clk),
        .OUTPUT_ENABLE(1'b0),
        .D_OUT_0(tx_lo),
        .D_OUT_1(1'b0),
        .D_IN_0(),
        .D_IN_1()
    );

endmodule // e1_tx_phy
