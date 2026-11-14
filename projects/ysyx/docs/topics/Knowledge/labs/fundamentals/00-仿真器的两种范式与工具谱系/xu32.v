// 从未初始化的 32 位自保持寄存器
module xu32(
  input clk,
  output reg [31:0] r
);
  always @(posedge clk) r <= r;
endmodule
