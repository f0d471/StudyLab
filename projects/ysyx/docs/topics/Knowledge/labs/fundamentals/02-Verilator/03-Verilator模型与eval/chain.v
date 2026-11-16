module chain(
  input  a,
  input  b,
  output f
);
  wire t1, t2;
  assign f  = t2 & a;
  assign t2 = ~t1;
  assign t1 = a ^ b;
endmodule
