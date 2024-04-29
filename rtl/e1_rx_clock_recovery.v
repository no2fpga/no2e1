/*
 * e1_rx_clock_recovery.v
 *
 * vim: ts=4 sw=4
 *
 * E1 Clock recovery/sampling
 *
 * Copyright (C) 2019-2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-W-2.0
 */

`default_nettype none

module e1_rx_clock_recovery (
	// Input
	input  wire in_hi,
	input  wire in_lo,
	input  wire in_stb,

	// Output
	output wire out_hi,
	output wire out_lo,
	output wire out_stb,

	// Common
	input  wire clk,
	input  wire rst
);

	reg [5:0] cnt;

	always @(posedge clk)
	begin
		if (rst)
			cnt <= 5'h0f;
		else begin
			if (in_stb)
				cnt <= 5'h01;
			else if (cnt[5])
				cnt <= 5'h0d;
			else
				cnt <= cnt - 1;
		end
	end

	assign out_hi = in_hi;
	assign out_lo = in_lo;
	assign out_stb = cnt[5];

endmodule // e1_rx_clock_recovery
