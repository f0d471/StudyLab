// 补全 else：每个分支都有明确的值
module lat_good(
  input en,
  input d,
  output reg q
);
  always @(*) if (en) q = d; else q = 1'b0;
endmodule
