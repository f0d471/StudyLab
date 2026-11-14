// 不完整的 if：没有 else 分支
module lat_bad(
  input en,
  input d,
  output reg q
);
  always @(*) if (en) q = d;
endmodule
