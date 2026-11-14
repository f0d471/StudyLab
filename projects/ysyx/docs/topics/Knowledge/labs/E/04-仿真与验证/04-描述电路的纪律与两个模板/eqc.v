// 两个计数器同顶层，共用时钟、复位、使能
module eqc(
  input clk,
  input rst,
  input en,
  output [7:0] qa,
  output [7:0] qt
);
  cnta m0 (clk, rst, en, qa);
  cntt m1 (clk, rst, en, qt);
endmodule
