// 计数器：给波形实验制造足够多的值变化
module cnt(
  input clk,
  input rst,
  output reg [31:0] out
);
  always @(posedge clk)
    if (rst) out <= 32'd0;
    else    out <= out + 32'd1;
endmodule
