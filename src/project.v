/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_purdue_socet_uart (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // All output pins must be assigned. If not used, assign to 0.
  assign uo_out[7:5] = 3'b0;
  assign uio_oe = (ui_in[5:4] == 2'd2) ? {8{1'b1}} : 8'b0;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, ui_in[7:6], 1'b0};

  // Instantiate project
  AHBUart_tapeout uart_proj (
    .clk(clk),
    .nReset(rst_n),
    .control(ui_in[5:2]),
    .tx_data(uio_in),
    .rx_data(uio_out),
    .rx(ui_in[0]),
    .tx(uo_out[0]),
    .cts(ui_in[1]),
    .rts(uo_out[1]),
    .err(uo_out[2]),
    .tx_buffer_full(uo_out[3]),
    .rx_buffer_empty(uo_out[4])
  );

endmodule
