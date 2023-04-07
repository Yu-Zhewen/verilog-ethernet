/*

Copyright (c) 2014-2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall `timescale 1ns / 1ps `default_nettype none

/*
 * FPGA top-level module
 */
module eth_top (
    /*
     * Clock: 100MHz
     * Reset: Push button, active low
     */
    input wire clk,
    input wire reset_n,

    /*
     * GPIO
     */
    input  wire [3:0] sw,
    input  wire [3:0] btn,
    output wire       led0_r,
    output wire       led0_g,
    output wire       led0_b,
    output wire       led1_r,
    output wire       led1_g,
    output wire       led1_b,
    output wire       led2_r,
    output wire       led2_g,
    output wire       led2_b,
    output wire       led3_r,
    output wire       led3_g,
    output wire       led3_b,
    output wire       led4,
    output wire       led5,
    output wire       led6,
    output wire       led7,

    /*
     * Ethernet: 100BASE-T MII
     */
    output wire       phy_ref_clk,
    input  wire       phy_rx_clk,
    input  wire [3:0] phy_rxd,
    input  wire       phy_rx_dv,
    input  wire       phy_rx_er,
    input  wire       phy_tx_clk,
    output wire [3:0] phy_txd,
    output wire       phy_tx_en,
    input  wire       phy_col,
    input  wire       phy_crs,
    output wire       phy_reset_n,

    /*
     * UART: 500000 bps, 8N1
     */
    input  wire uart_rxd,
    output wire uart_txd,


    output wire [7:0] partition_input_axis_tdata,
    output wire partition_input_axis_tvalid,
    input wire partition_input_axis_tready,
    output wire partition_input_axis_tlast,

    input wire [7:0] partition_output_axis_tdata,
    input wire partition_output_axis_tvalid,
    output wire partition_output_axis_tready,
    input wire partition_output_axis_tlast,

    output wire clk_int,
    output wire rst_int

);

  // Clock and reset

  wire clk_ibufg;

  // Internal 125 MHz clock
  wire clk_mmcm_out;


  wire mmcm_rst = ~reset_n;
  wire mmcm_locked;
  wire mmcm_clkfb;

  IBUFG clk_ibufg_inst (
      .I(clk),
      .O(clk_ibufg)
  );

  wire clk_50mhz_mmcm_out;
  wire clk_50mhz_int;

  // MMCM instance
  // 100 MHz in, 125 MHz out
  // PFD range: 10 MHz to 550 MHz
  // VCO range: 600 MHz to 1200 MHz
  // M = 10, D = 1 sets Fvco = 1000 MHz (in range)
  // Divide by 8 to get output frequency of 125 MHz
  // Divide by 20 to get output frequency of 50 MHz
  // 1000 / 5 = 200 MHz
  MMCME2_BASE #(
      .BANDWIDTH("OPTIMIZED"),
      .CLKOUT0_DIVIDE_F(8),
      .CLKOUT0_DUTY_CYCLE(0.5),
      .CLKOUT0_PHASE(0),
      .CLKOUT1_DIVIDE(20),
      .CLKOUT1_DUTY_CYCLE(0.5),
      .CLKOUT1_PHASE(0),
      .CLKOUT2_DIVIDE(1),
      .CLKOUT2_DUTY_CYCLE(0.5),
      .CLKOUT2_PHASE(0),
      .CLKOUT3_DIVIDE(1),
      .CLKOUT3_DUTY_CYCLE(0.5),
      .CLKOUT3_PHASE(0),
      .CLKOUT4_DIVIDE(1),
      .CLKOUT4_DUTY_CYCLE(0.5),
      .CLKOUT4_PHASE(0),
      .CLKOUT5_DIVIDE(1),
      .CLKOUT5_DUTY_CYCLE(0.5),
      .CLKOUT5_PHASE(0),
      .CLKOUT6_DIVIDE(1),
      .CLKOUT6_DUTY_CYCLE(0.5),
      .CLKOUT6_PHASE(0),
      .CLKFBOUT_MULT_F(10),
      .CLKFBOUT_PHASE(0),
      .DIVCLK_DIVIDE(1),
      .REF_JITTER1(0.010),
      .CLKIN1_PERIOD(10.0),
      .STARTUP_WAIT("FALSE"),
      .CLKOUT4_CASCADE("FALSE")
  ) clk_mmcm_inst (
      .CLKIN1(clk_ibufg),
      .CLKFBIN(mmcm_clkfb),
      .RST(mmcm_rst),
      .PWRDWN(1'b0),
      .CLKOUT0(clk_mmcm_out),
      .CLKOUT0B(),
      .CLKOUT1(clk_50mhz_mmcm_out),
      .CLKOUT1B(),
      .CLKOUT2(),
      .CLKOUT2B(),
      .CLKOUT3(),
      .CLKOUT3B(),
      .CLKOUT4(),
      .CLKOUT5(),
      .CLKOUT6(),
      .CLKFBOUT(mmcm_clkfb),
      .CLKFBOUTB(),
      .LOCKED(mmcm_locked)
  );

  BUFG clk_bufg_inst (
      .I(clk_mmcm_out),
      .O(clk_int)
  );

  BUFG clk_50mhz_bufg_inst (
      .I(clk_50mhz_mmcm_out),
      .O(clk_50mhz_int)
  );

  sync_reset #(
      .N(4)
  ) sync_reset_inst (
      .clk(clk_int),
      .rst(~mmcm_locked),
      .out(rst_int)
  );

  // GPIO
  wire [3:0] btn_int;
  wire [3:0] sw_int;

  debounce_switch #(
      .WIDTH(8),
      .N(4),
      .RATE(125000)
  ) debounce_switch_inst (
      .clk(clk_int),
      .rst(rst_int),
      .in ({btn, sw}),
      .out({btn_int, sw_int})
  );

  wire uart_rxd_int;

  sync_signal #(
      .WIDTH(1),
      .N(2)
  ) sync_signal_inst (
      .clk(clk_int),
      .in ({uart_rxd}),
      .out({uart_rxd_int})
  );

  assign phy_ref_clk = clk_50mhz_int;

  wire [7:0] rx_fifo_udp_payload_axis_tdata;
  wire       rx_fifo_udp_payload_axis_tvalid;
  wire       rx_fifo_udp_payload_axis_tready;
  wire       rx_fifo_udp_payload_axis_tlast;
  wire       rx_fifo_udp_payload_axis_tuser;

  wire [7:0] tx_fifo_udp_payload_axis_tdata;
  wire       tx_fifo_udp_payload_axis_tvalid;
  wire       tx_fifo_udp_payload_axis_tready;
  wire       tx_fifo_udp_payload_axis_tlast;
  wire       tx_fifo_udp_payload_axis_tuser;

  eth_core #(
      .TARGET("GENERIC")
  ) core_inst (
      /*
     * Clock: 125MHz
     * Synchronous reset
     */
      .clk(clk_int),
      .rst(rst_int),
      /*
     * GPIO
     */
      .btn(btn_int),
      .sw(sw_int),
      .led0_r(led0_r),
      .led0_g(led0_g),
      .led0_b(led0_b),
      .led1_r(led1_r),
      .led1_g(led1_g),
      .led1_b(led1_b),
      .led2_r(led2_r),
      .led2_g(led2_g),
      .led2_b(led2_b),
      .led3_r(led3_r),
      .led3_g(led3_g),
      .led3_b(led3_b),
      .led4(led4),
      .led5(led5),
      .led6(led6),
      .led7(led7),
      /*
     * Ethernet: 100BASE-T MII
     */
      .phy_rx_clk(phy_rx_clk),
      .phy_rxd(phy_rxd),
      .phy_rx_dv(phy_rx_dv),
      .phy_rx_er(phy_rx_er),
      .phy_tx_clk(phy_tx_clk),
      .phy_txd(phy_txd),
      .phy_tx_en(phy_tx_en),
      .phy_col(phy_col),
      .phy_crs(phy_crs),
      .phy_reset_n(phy_reset_n),
      /*
     * UART: 115200 bps, 8N1
     */
      .uart_rxd(uart_rxd_int),
      .uart_txd(uart_txd),

      .rx_fifo_udp_payload_axis_tdata (rx_fifo_udp_payload_axis_tdata),
      .rx_fifo_udp_payload_axis_tvalid(rx_fifo_udp_payload_axis_tvalid),
      .rx_fifo_udp_payload_axis_tready(rx_fifo_udp_payload_axis_tready),
      .rx_fifo_udp_payload_axis_tlast (rx_fifo_udp_payload_axis_tlast),
      .rx_fifo_udp_payload_axis_tuser (rx_fifo_udp_payload_axis_tuser),

      .tx_fifo_udp_payload_axis_tdata (tx_fifo_udp_payload_axis_tdata),
      .tx_fifo_udp_payload_axis_tvalid(tx_fifo_udp_payload_axis_tvalid),
      .tx_fifo_udp_payload_axis_tready(tx_fifo_udp_payload_axis_tready),
      .tx_fifo_udp_payload_axis_tlast (tx_fifo_udp_payload_axis_tlast),
      .tx_fifo_udp_payload_axis_tuser (tx_fifo_udp_payload_axis_tuser)
  );





  //axis_async_fifo_adapter #(
  //    .DEPTH(4096),
  //    .S_DATA_WIDTH(8),
  //    .M_DATA_WIDTH(8)
  //)
  //tx_fifo (
  //    // AXI input
  //    .s_clk(clk),
  //    .s_rst(!reset_n),
  //    .s_axis_tdata(partition_output_axis_tdata),
  //    .s_axis_tkeep(0),
  //    .s_axis_tvalid(partition_output_axis_tvalid),
  //    .s_axis_tready(partition_output_axis_tready),
  //    .s_axis_tlast(partition_output_axis_tlast),
  //    .s_axis_tid(0),
  //    .s_axis_tdest(0),
  //    .s_axis_tuser(0),
  //    // AXI output
  //    .m_clk(clk_int),
  //    .m_rst(rst_int),
  //    .m_axis_tdata(tx_fifo_udp_payload_axis_tdata),
  //    .m_axis_tkeep(),
  //    .m_axis_tvalid(tx_fifo_udp_payload_axis_tvalid),
  //    .m_axis_tready(tx_fifo_udp_payload_axis_tready),
  //    .m_axis_tlast(tx_fifo_udp_payload_axis_tlast),
  //    .m_axis_tid(),
  //    .m_axis_tdest(),
  //    .m_axis_tuser(tx_fifo_udp_payload_axis_tuser),
  //    // Status
  //    .s_status_overflow(),
  //    .s_status_bad_frame(),
  //    .s_status_good_frame(),
  //    .m_status_overflow(),
  //    .m_status_bad_frame(),
  //    .m_status_good_frame()
  //);

  //axis_async_fifo_adapter #(
  //    .DEPTH(4096),
  //    .S_DATA_WIDTH(8),
  //    .M_DATA_WIDTH(8)
  //)
  //rx_fifo (
  //    // AXI input
  //    .s_clk(clk_int),
  //    .s_rst(rst_int),
  //    .s_axis_tdata(rx_fifo_udp_payload_axis_tdata),
  //    .s_axis_tkeep(0),
  //    .s_axis_tvalid(rx_fifo_udp_payload_axis_tvalid),
  //    .s_axis_tready(rx_fifo_udp_payload_axis_tready),
  //    .s_axis_tlast(rx_fifo_udp_payload_axis_tlast),
  //    .s_axis_tid(0),
  //    .s_axis_tdest(0),
  //    .s_axis_tuser(rx_fifo_udp_payload_axis_tuser),
  //    // AXI output
  //    .m_clk(clk),
  //    .m_rst(!reset_n),
  //    .m_axis_tdata(partition_input_axis_tdata),
  //    .m_axis_tkeep(),
  //    .m_axis_tvalid(partition_input_axis_tvalid),
  //    .m_axis_tready(partition_input_axis_tready),
  //    .m_axis_tlast(),
  //    .m_axis_tid(),
  //    .m_axis_tdest(),
  //    .m_axis_tuser(),
  //    // Status
  //    .s_status_overflow(),
  //    .s_status_bad_frame(),
  //    .s_status_good_frame(),
  //    .m_status_overflow(),
  //    .m_status_bad_frame(),
  //    .m_status_good_frame()
  //);


  axis_fifo #(
      .DEPTH(8192),
      .DATA_WIDTH(8),
      .KEEP_ENABLE(0),
      .ID_ENABLE(0),
      .DEST_ENABLE(0),
      .USER_ENABLE(1),
      .USER_WIDTH(1),
      .FRAME_FIFO(0)
  ) udp_payload_fifo (
      .clk(clk_int),
      .rst(rst_int),

      // AXI input
      .s_axis_tdata(rx_fifo_udp_payload_axis_tdata),
      .s_axis_tkeep(0),
      .s_axis_tvalid(rx_fifo_udp_payload_axis_tvalid),
      .s_axis_tready(rx_fifo_udp_payload_axis_tready),
      .s_axis_tlast(rx_fifo_udp_payload_axis_tlast),
      .s_axis_tid(0),
      .s_axis_tdest(0),
      .s_axis_tuser(rx_fifo_udp_payload_axis_tuser),

      // AXI output
      .m_axis_tdata(partition_input_axis_tdata),
      .m_axis_tkeep(),
      .m_axis_tvalid(partition_input_axis_tvalid),
      .m_axis_tready(partition_input_axis_tready),
      .m_axis_tlast(partition_input_axis_tlast),
      .m_axis_tid(),
      .m_axis_tdest(),
      .m_axis_tuser(),

      // Status
      .status_overflow  (),
      .status_bad_frame (),
      .status_good_frame()
  );

  axis_fifo #(
      .DEPTH(8192),
      .DATA_WIDTH(8),
      .KEEP_ENABLE(0),
      .ID_ENABLE(0),
      .DEST_ENABLE(0),
      .USER_ENABLE(1),
      .USER_WIDTH(1),
      .FRAME_FIFO(0)
  ) udp_payload_fifo2 (
      .clk(clk_int),
      .rst(rst_int),

      // AXI input
      .s_axis_tdata(partition_output_axis_tdata),
      .s_axis_tkeep(0),
      .s_axis_tvalid(partition_output_axis_tvalid),
      .s_axis_tready(partition_output_axis_tready),
      .s_axis_tlast(partition_output_axis_tlast),
      .s_axis_tid(0),
      .s_axis_tdest(0),
      .s_axis_tuser(0),

      // AXI output
      .m_axis_tdata(tx_fifo_udp_payload_axis_tdata),
      .m_axis_tkeep(),
      .m_axis_tvalid(tx_fifo_udp_payload_axis_tvalid),
      .m_axis_tready(tx_fifo_udp_payload_axis_tready),
      .m_axis_tlast(tx_fifo_udp_payload_axis_tlast),
      .m_axis_tid(),
      .m_axis_tdest(),
      .m_axis_tuser(tx_fifo_udp_payload_axis_tuser),

      // Status
      .status_overflow  (),
      .status_bad_frame (),
      .status_good_frame()
  );


endmodule

`resetall
