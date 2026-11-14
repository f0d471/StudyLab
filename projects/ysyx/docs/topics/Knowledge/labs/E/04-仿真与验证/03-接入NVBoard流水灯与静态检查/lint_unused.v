module lint_unused(
  input a,
  input b,         // 端口 b 从未被使用
  output y
);
  assign y = a;
endmodule
