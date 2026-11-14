// 把两种写法放在同一个顶层里对比
module eq2(
  input a,
  input b,
  input s,
  output ya,
  output yt
);
  mux2a m0 (a, b, s, ya);
  mux2t m1 (a, b, s, yt);
endmodule
