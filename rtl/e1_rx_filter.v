/*
 * e1_rx_filter.v
 *
 * vim: ts=4 sw=4
 *
 * E1 RX glitch filtering and pulse detection
 *
 * Copyright (C) 2019-2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-W-2.0
 */

`default_nettype none

module e1_rx_filter (
	// Input
	input  wire in_hi,
	input  wire in_lo,

	// Output
	output reg  out_hi,
	output reg  out_lo,
	output reg  out_stb,		// Strobe on any 0->1 transition

	// Common
	input  wire clk,
	input  wire rst
);

	// Signals
	reg in_hi_r;
	reg in_lo_r;

	reg [1:0] cnt_hi;
	reg [1:0] cnt_lo;

	// Register incoming data first
		// They come from IO register buffer, but from async data, so a
		// second FF is good practice
	always @(posedge clk)
	begin
		in_hi_r <= in_hi;
		in_lo_r <= in_lo;
	end

	// Counters
	always @(posedge clk)
	begin
		if (rst) begin
			cnt_hi <= 2'b00;
			cnt_lo <= 2'b00;
		end else begin
			// Hi
			if (in_hi_r & ~in_lo_r & (cnt_hi != 2'b11))
				cnt_hi <= cnt_hi + 1;
			else if (~in_hi_r & cnt_hi != 2'b00)
				cnt_hi <= cnt_hi - 1;
			else
				cnt_hi <= cnt_hi;

			// Lo
			if (in_lo_r & ~in_hi_r & (cnt_lo != 2'b11))
				cnt_lo <= cnt_lo + 1;
			else if (~in_lo_r & (cnt_lo != 2'b00))
				cnt_lo <= cnt_lo - 1;
			else
				cnt_lo <= cnt_lo;
		end
	end

	// Flip flops
	always @(posedge clk)
	begin
		// Default is no 1->0 transition
		out_stb <= 1'b0;

		// Hi
		if (cnt_hi == 2'b11 & ~out_hi & ~out_lo) begin
			out_hi <= 1'b1;
			out_stb <= 1'b1;
		end else if (cnt_hi == 2'b00)
			out_hi <= 1'b0;

		// Lo
		if (cnt_lo == 2'b11 & ~out_lo & ~out_hi) begin
			out_lo <= 1'b1;
			out_stb <= 1'b1;
		end else if (cnt_lo == 2'b00)
			out_lo <= 1'b0;
	end

endmodule // e1_rx_filter
