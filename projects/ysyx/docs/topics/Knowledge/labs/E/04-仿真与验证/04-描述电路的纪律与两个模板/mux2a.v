module mux2a(
  input a,
  input b,
  input s,
  output y
);
  assign y = s ? b : a;   // 数据流建模
endmodule
