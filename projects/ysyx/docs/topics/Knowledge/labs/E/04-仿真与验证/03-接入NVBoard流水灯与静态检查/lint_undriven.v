module lint_undriven(
  output y
);
  wire w;          // 声明了、用了，但没有任何驱动
  assign y = w;
endmodule
