/*
 * hdb3_dec.v
 *
 * vim: ts=4 sw=4
 *
 * HDB3 symbols -> bit decoding as described in G.703
 *
 * Copyright (C) 2019-2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-W-2.0
 */

`default_nettype none

module hdb3_dec (
	// Input
	input  wire in_pos,
	input  wire in_neg,
	input  wire in_valid,

	// Output
	output wire out_data,
	output reg  out_valid,

	// Common
	input  wire clk,
	input  wire rst
);

	// Signals
	wire violation;
	reg [3:0] data;
	reg pstate;			// Pulse state

	// Output
	assign out_data = data[3];

	always @(posedge clk)
		out_valid <= in_valid;

	// Main logic
	assign violation = (in_pos & pstate) | (in_neg & ~pstate);

	always @(posedge clk)
	begin
		if (rst) begin
			// Reset state
			data   <= 4'h0;
			pstate <= 1'b0;

		end else if (in_valid) begin
			if (in_pos ^ in_neg) begin
				// Is it a violation ?
				if (violation) begin
					// Violation
					data   <= 4'h0;
					pstate <= pstate;

				end else begin
					// Normal data (or possibly balancing pulse that will be
					// post-corrected)
					data   <= { data[2:0], 1'b1 };
					pstate <= pstate ^ 1;
				end
			end else begin
				// Zero (or error, we map to 0)
				data   <= { data[2:0], 1'b0 };
				pstate <= pstate;
			end
		end
	end

endmodule // hdb3_dec
