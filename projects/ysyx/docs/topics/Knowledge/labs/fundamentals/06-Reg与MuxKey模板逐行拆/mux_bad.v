// 声明的键值对数量（2）少于实际拼接的（3）：端口位宽对不上
module mux_bad(
  input  [1:0] key,
  output [3:0] y
);
  MuxKey #(2, 2, 4) m0 (y, key, {
    2'b00, 4'h1,
    2'b01, 4'h2,
    2'b10, 4'h4
  });
endmodule
