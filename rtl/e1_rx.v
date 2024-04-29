/*
 * e1_rx.v
 *
 * vim: ts=4 sw=4
 *
 * E1 RX top-level
 *
 * Copyright (C) 2019-2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-W-2.0
 */

`default_nettype none

module e1_rx #(
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
	output wire [7:0] buf_data,
	output wire [4:0] buf_ts,
	output wire [3:0] buf_frame,
	output wire [MFW-1:0] buf_mf,
	output wire buf_we,
	input  wire buf_rdy,

	// BD interface
	input  wire [MFW-1:0] bd_mf,
	output reg  [1:0] bd_crc_e,
	input  wire bd_valid,
	output reg  bd_done,
	output reg  bd_miss,

	// Loopback output
	output wire lb_bit,
	output wire lb_valid,

	// Control
	input  wire ctrl_mode_mf,

	// Status
	output wire status_aligned,

	// Monitor pulses
		// [2] rx_one		Every sampled '1' bit
		// [1] rx_sample	Every sample
		// [0] rx_pulse		Every detected pulse
	output wire [2:0] mon_tick,

	// Common
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// Low level (input -> bits)
	wire ll_raw_hi, ll_raw_lo;
	wire ll_flt_hi, ll_flt_lo, ll_flt_stb;
	wire ll_cdr_hi, ll_cdr_lo, ll_cdr_stb;

	wire ll_bit;
	wire ll_valid;

	// Deframer
	wire [7:0] df_data;
	wire [3:0] df_frame;
	wire [4:0] df_ts;
	wire df_ts_is0;
	wire df_first;
	wire df_last;
	wire df_valid;

	wire df_err_crc;
	wire df_err_mfa;
	wire df_err_fas;
	wire df_err_nfas;

	wire df_aligned;

	// Buffer Descriptor handling
	reg  mf_valid;


	// Low-level bit recovery
	// ----------------------

	generate
		if (LIU == 0) begin

			// PHY
			e1_rx_phy phy_I (
				.pad_rx_hi_p(pad_rx_hi_p),
				.pad_rx_hi_n(pad_rx_hi_n),
				.pad_rx_lo_p(pad_rx_lo_p),
				.pad_rx_lo_n(pad_rx_lo_n),
				.rx_hi(ll_raw_hi),
				.rx_lo(ll_raw_lo),
				.clk(clk),
				.rst(rst)
			);

			// Glitch filtering
			e1_rx_filter filter_I (
				.in_hi(ll_raw_hi),
				.in_lo(ll_raw_lo),
				.out_hi(ll_flt_hi),
				.out_lo(ll_flt_lo),
				.out_stb(ll_flt_stb),
				.clk(clk),
				.rst(rst)
			);

			// Clock recovery
			e1_rx_clock_recovery clock_I (
				.in_hi(ll_flt_hi),
				.in_lo(ll_flt_lo),
				.in_stb(ll_flt_stb),
				.out_hi(ll_cdr_hi),
				.out_lo(ll_cdr_lo),
				.out_stb(ll_cdr_stb),
				.clk(clk),
				.rst(rst)
			);

			// HDB3 decoding
			hdb3_dec hdb3_I (
				.in_pos(ll_cdr_hi),
				.in_neg(ll_cdr_lo),
				.in_valid(ll_cdr_stb),
				.out_data(ll_bit),
				.out_valid(ll_valid),
				.clk(clk),
				.rst(rst)
			);

		end else begin

			// LIU interface
			e1_rx_liu liuif_I (
				.pad_rx_data(pad_rx_data),
				.pad_rx_clk(pad_rx_clk),
				.out_data(ll_bit),
				.out_valid(ll_valid),
				.clk(clk),
				.rst(rst)
			);

			// Dummy for monitor ticks
			assign ll_flt_stb = 1'b0;

		end
	endgenerate

	// Loopback output
	assign lb_bit = ll_bit;
	assign lb_valid = ll_valid;


	// High-level frame recovery
	// -------------------------

	// Deframer
	e1_rx_deframer deframer_I (
		.in_bit(ll_bit),
		.in_valid(ll_valid),
		.out_data(df_data),
		.out_frame(df_frame),
		.out_ts(df_ts),
		.out_ts_is0(df_ts_is0),
		.out_first(df_first),
		.out_last(df_last),
		.out_valid(df_valid),
		.out_err_crc(df_err_crc),
		.out_err_mfa(df_err_mfa),
		.out_err_fas(df_err_fas),
		.out_err_nfas(df_err_nfas),
		.aligned(df_aligned),
		.ctrl_mode_mf(ctrl_mode_mf),
		.clk(clk),
		.rst(rst)
	);

	// Buffer Descriptor
		// Keep track if we have a valid MF capture
	always @(posedge clk or posedge rst)
		if (rst)
			mf_valid <= 1'b0;
		else
			mf_valid <= ((df_valid & df_first) ? bd_valid : mf_valid) & df_aligned;

		// We register those because a 1 cycle delay doesn't matter
		// (we won't get another byte write for ~ 120 cycle)
	always @(posedge clk)
	begin
		bd_done <= df_valid & df_last  &  mf_valid;
		bd_miss <= df_valid & df_first & ~bd_valid;
	end

		// Track the CRC status of the two SMF
	always @(posedge clk or posedge rst)
		if (rst)
			bd_crc_e <= 2'b11;
		else
			bd_crc_e <= (bd_done) ? 2'b11 : (bd_crc_e & ~{
				df_valid & df_err_crc &  df_frame[3],	// CRC error in second SMF
				df_valid & df_err_crc & ~df_frame[3]	// CRC error in first SMF
			});

	// Buffer write
	assign buf_data  = df_data;
	assign buf_ts    = df_ts;
	assign buf_frame = df_frame;
	assign buf_mf    = bd_mf;
	assign buf_we    = df_valid & bd_valid;

	// Status output
	assign status_aligned = df_aligned;

	// Monitoring tick
	assign mon_tick = {
		ll_valid & ll_bit,
		ll_valid,
		ll_flt_stb
	};

endmodule // e1_rx
