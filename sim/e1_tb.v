/*
 * e1_tb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019-2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-W-2.0
 */

`default_nettype none
`timescale 1ns / 100ps

module e1_tb;

	// Signals
	reg rst = 1;
	reg clk_16m = 0;
	reg clk_30m72 = 0;

	reg  [7:0] in_file_data;
	reg  in_file_valid;
	reg  in_file_done;

	wire e1_in_tip;
	wire e1_in_ring;

	wire e1_bit;
	wire e1_valid;

	wire e1_out_tip;
	wire e1_out_ring;

	wire df_valid;
	wire [7:0] df_data;
	wire [4:0] df_ts;

	// Setup recording
	initial begin
		$dumpfile("e1_tb.vcd");
		$dumpvars(0,e1_tb);
	end

	// Reset pulse
	initial begin
		# 200 rst = 0;
		# 10000000 $finish;
	end

	// Clocks
	always #31.25 clk_16m = !clk_16m;
	always #16.276 clk_30m72 = !clk_30m72;

	// DUT
	e1_rx rx_I (
		.pad_rx_hi_p( e1_in_ring),
		.pad_rx_hi_n(~e1_in_ring),
		.pad_rx_lo_p( e1_in_tip),
		.pad_rx_lo_n(~e1_in_tip),
		.lb_bit(e1_bit),
		.lb_valid(e1_valid),
		.ctrl_mode_mf(1'b0),
		.clk(clk_30m72),
		.rst(rst)
	);

	e1_tx tx_I (
		.pad_tx_hi(e1_out_ring),
		.pad_tx_lo(e1_out_tip),
		.lb_bit(e1_bit),
		.lb_valid(e1_valid),
		.ctrl_time_src(1'b0),
		.ctrl_do_framing(1'b0),
		.ctrl_do_crc4(1'b0),
		.ctrl_loopback(1'b1),
		.alarm(1'b0),
		.clk(clk_30m72),
		.rst(rst)
	);

	e1_rx_deframer rx_deframer_I (
		.in_bit(e1_bit),
		.in_valid(e1_valid),
		.out_data(df_data),
		.out_valid(df_valid),
		.out_ts(df_ts),
		.clk(clk_30m72),
		.rst(rst)
	);

	// Read file
	integer fh_in, rv;

	initial
		fh_in = $fopen("../data/capture_e1_raw.bin", "rb");

	always @(posedge clk_16m)
	begin
		if (rst) begin
			in_file_data  <= 8'h00;
			in_file_valid <= 1'b0;
			in_file_done  <= 1'b0;
		end else begin
			if (!in_file_done) begin
				rv = $fread(in_file_data, fh_in);
				in_file_valid <= (rv == 1);
				in_file_done  <= (rv != 1);
			end else begin
				in_file_data  <= 8'h00;
				in_file_valid <= 1'b0;
				in_file_done  <= 1'b1;
			end
		end
	end

	// Write file
	integer fh_out;

	initial
		fh_out = $fopen("/tmp/e1.txt", "w");

	always @(posedge clk_30m72)
	begin
		if (e1_valid) begin
			$fwrite(fh_out, "%d", e1_bit);
		end
	end

	// Input
	assign e1_in_tip  = in_file_data[0] & in_file_valid;
	assign e1_in_ring = in_file_data[1] & in_file_valid;

endmodule // e1_tb
