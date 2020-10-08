/*
 * e1_wb_tx.v
 *
 * vim: ts=4 sw=4
 *
 * E1 wishbone TX submodule - NOT MEANT TO BE USED INDEPENDENTLY
 *
 * Copyright (C) 2019-2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-W-2.0
 */

`default_nettype none

module e1_wb_tx #(
	parameter integer LIU = 0,
	parameter integer MFW = 7
)(
	// IO pads
		// Raw PHY
	output wire pad_tx_hi,
	output wire pad_tx_lo,

		// LIU
	output wire pad_tx_data,
	output wire pad_tx_clk,

	// Buffer interface
	input  wire     [7:0] buf_tx_data,
	output wire     [4:0] buf_tx_ts,
	output wire     [3:0] buf_tx_frame,
	output wire [MFW-1:0] buf_tx_mf,
	output wire           buf_tx_re,
	input  wire           buf_tx_rdy,

	// Bus interface
	input  wire        bus_addr_sel,
	input  wire  [0:0] bus_addr_lsb,
	input  wire [15:0] bus_wdata,
	output wire [15:0] bus_rdata,
	input  wire        bus_clr,
	input  wire        bus_we,

	// RX/TX cross status
	input  wire [1:0] tx_crc_e_auto,
    output wire       tx_crc_e_ack,

	// External strobes
	output wire irq,
	output wire tick,

	// Loopback path
	input  wire [1:0] lb_bit,
	input  wire [1:0] lb_valid,

	// Common
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// CSRs and bus access
	reg  ctx_wren;
	reg  ctx_clear;

	wire [15:0] bus_rd_tx_status;
	wire [15:0] bus_rd_tx_bdout;

	// FIFOs
		// BD TX In
	wire [MFW+1:0] bti_di;
	wire [MFW+1:0] bti_do;
	reg  bti_wren;
	wire bti_rden;
	wire bti_full;
	wire bti_empty;

		// BD TX Out
	wire [MFW-1:0] bto_di;
	wire [MFW-1:0] bto_do;
	wire bto_wren;
	reg  bto_rden;
	wire bto_full;
	wire bto_empty;

	// Control
	reg  tx_rst;
	reg  tx_enabled;
	reg  [1:0] tx_mode;
	reg  tx_time_src;
	reg  tx_alarm;
	reg  [1:0] tx_loopback;
	reg  tx_underflow;

	// BD interface
	wire [MFW-1:0] bdtx_mf;
	wire [1:0] bdtx_crc_e;
	wire bdtx_valid;
	wire bdtx_done;
	wire bdtx_miss;

	// Timing
	wire ext_tick;
	wire int_tick;


	// CSRs & FIFO bus access
	// ----------------------

	// Control WrEn
	always @(posedge clk)
		if (bus_clr | ~bus_we) begin
			ctx_wren  <= 1'b0;
			ctx_clear <= 1'b0;
		end else begin
			ctx_wren  <= bus_addr_sel & (bus_addr_lsb == 1'b0);
			ctx_clear <= bus_addr_sel & (bus_addr_lsb == 1'b0) & bus_wdata[12];
		end

	// Control regs
	always @(posedge clk or posedge rst)
		if (rst) begin
			tx_loopback <= 2'b00;
			tx_alarm    <= 1'b0;
			tx_time_src <= 1'b0;
			tx_mode     <= 2'b00;
			tx_enabled  <= 1'b0;
		end else if (ctx_wren) begin
			tx_loopback <= bus_wdata[6:5];
			tx_alarm    <= bus_wdata[4];
			tx_time_src <= bus_wdata[3];
			tx_mode     <= bus_wdata[2:1];
			tx_enabled  <= bus_wdata[0];
		end

	// Status data
	assign bus_rd_tx_status = {
		3'b000,
		tx_underflow,
		bto_full,
		bto_empty,
		bti_full,
		bti_empty,
		7'b0000000,
		tx_enabled
	};

	// BD FIFO WrEn / RdEn
		// (note we must mask on full/empty here to be consistent with what we
		//  return in the data !)
	always @(posedge clk)
		if (bus_clr) begin
			bti_wren <= 1'b0;
			bto_rden <= 1'b0;
		end else begin
			bti_wren <=  bus_we & ~bti_full  & bus_addr_sel & (bus_addr_lsb == 1'b1);
			bto_rden <= ~bus_we & ~bto_empty & bus_addr_sel & (bus_addr_lsb == 1'b1);
		end

	// BD FIFO Data
	assign bti_di = { bus_wdata[14:13], bus_wdata[MFW-1:0] };

	assign bus_rd_tx_bdout = { ~bto_empty, {(15-MFW){1'b0}}, bto_do[MFW-1:0] };

	// Read Mux
	assign bus_rdata = bus_addr_sel ? ( bus_addr_lsb[0] ? bus_rd_tx_bdout : bus_rd_tx_status ) : 16'h0000;
	//assign bus_rdata = { 16{bus_addr_sel} } & (bus_addr_lsb[0] ? bus_rd_tx_bdout : bus_rd_tx_status);


	// BD fifos
	// --------

	// BD TX In
	fifo_sync_shift #(
		.DEPTH(4),
		.WIDTH(MFW+2)
	) bd_tx_in_I (
		.wr_data(bti_di),
		.wr_ena(bti_wren),
		.wr_full(bti_full),
		.rd_data(bti_do),
		.rd_ena(bti_rden),
		.rd_empty(bti_empty),
		.clk(clk),
		.rst(rst)
	);

	// BD TX Out
	fifo_sync_shift #(
		.DEPTH(4),
		.WIDTH(MFW)
	) bd_tx_out_I (
		.wr_data(bto_di),
		.wr_ena(bto_wren),
		.wr_full(bto_full),
		.rd_data(bto_do),
		.rd_ena(bto_rden),
		.rd_empty(bto_empty),
		.clk(clk),
		.rst(rst)
	);


	// TX submodule
	// ------------

	// TX core
	e1_tx #(
		.LIU(LIU),
		.MFW(MFW)
	) tx_I (
		.pad_tx_hi(pad_tx_hi),
		.pad_tx_lo(pad_tx_lo),
		.pad_tx_data(pad_tx_data),
		.pad_tx_clk(pad_tx_clk),
		.buf_data(buf_tx_data),
		.buf_ts(buf_tx_ts),
		.buf_frame(buf_tx_frame),
		.buf_mf(buf_tx_mf),
		.buf_re(buf_tx_re),
		.buf_rdy(buf_tx_rdy),
		.bd_mf(bdtx_mf),
		.bd_crc_e(bdtx_crc_e),
		.bd_valid(bdtx_valid),
		.bd_done(bdtx_done),
		.bd_miss(bdtx_miss),
		.lb_bit(lb_bit[tx_loopback[1]]),
		.lb_valid(lb_valid[tx_loopback[1]]),
		.ext_tick(ext_tick),
		.int_tick(int_tick),
		.ctrl_time_src(tx_time_src),
		.ctrl_do_framing(tx_mode != 2'b00),
		.ctrl_do_crc4(tx_mode[1]),
		.ctrl_loopback(tx_loopback[0]),
		.alarm(tx_alarm),
		.clk(clk),
		.rst(tx_rst)
	);

	assign ext_tick = lb_valid;

	// Auto E-bit tracking
	assign tx_crc_e_ack = bdtx_done;

	// BD FIFO interface
	assign bdtx_mf    =  bti_do[MFW-1:0];
	assign bdtx_crc_e = (tx_mode == 2'b11) ? tx_crc_e_auto : bti_do[MFW+1:MFW];
	assign bdtx_valid = ~bti_empty;

	assign bti_rden = bdtx_done;

	assign bto_di   =  bdtx_mf;
	assign bto_wren = ~bto_full & bdtx_done;

	// Control logic
		// Local reset
	always @(posedge clk or posedge rst)
		if (rst)
			tx_rst <= 1'b1;
		else
			tx_rst <= ~tx_enabled;

		// Underflow
	always @(posedge clk or posedge rst)
		if (rst)
			tx_underflow <= 1'b0;
		else
			tx_underflow <= (tx_underflow & ~ctx_clear) | bdtx_miss;


	// External strobes
	// ----------------

	assign irq  = ~bto_empty | tx_underflow;
	assign tick = int_tick;		/* tick used for TX */

endmodule // e1_wb_tx
