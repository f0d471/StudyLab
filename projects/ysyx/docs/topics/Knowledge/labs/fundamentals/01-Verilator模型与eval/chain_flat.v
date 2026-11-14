module chain_flat(
  input  a,
  input  b,
  output f
);
  wire t1 /*verilator public_flat*/;
  wire t2;
  assign f  = t2 & a;
  assign t2 = ~t1;
  assign t1 = a ^ b;
endmodule
