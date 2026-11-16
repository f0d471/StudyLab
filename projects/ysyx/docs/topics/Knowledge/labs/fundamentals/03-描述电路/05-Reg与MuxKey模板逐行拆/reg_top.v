// Reg 模板的探针：4 位、复位值 5
module reg_top(
  input clk,
  input rst,
  input [3:0] din,
  input wen,
  output [3:0] dout
);
  Reg #(4, 4'h5) r0 (clk, rst, din, dout, wen);
endmodule
