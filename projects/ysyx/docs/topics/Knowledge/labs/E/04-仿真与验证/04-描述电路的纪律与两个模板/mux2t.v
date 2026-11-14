module mux2t(
  input a,
  input b,
  input s,
  output y
);
  MuxKey #(2, 1, 1) i0 (y, s, {   // 结构化建模：实例化 + 连线
    1'b0, a,
    1'b1, b
  });
endmodule
