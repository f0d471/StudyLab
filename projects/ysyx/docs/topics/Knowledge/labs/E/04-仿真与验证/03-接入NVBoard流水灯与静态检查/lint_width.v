module lint_width(
  input  [3:0] a,
  output [2:0] y   // 4 位赋给 3 位：高位被截掉
);
  assign y = a;
endmodule
