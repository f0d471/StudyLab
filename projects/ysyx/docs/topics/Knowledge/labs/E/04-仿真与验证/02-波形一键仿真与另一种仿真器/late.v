`timescale 1ns/1ps
module late(
  input clk,
  input d,
  output reg q
);
  always @(posedge clk) q <= #5 d;
endmodule
