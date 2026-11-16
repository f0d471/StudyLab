module hier(
  input        clk,
  input  [7:0] d,
  output [7:0] q
);
  sub u_sub (.clk(clk), .d(d), .q(q));
endmodule
