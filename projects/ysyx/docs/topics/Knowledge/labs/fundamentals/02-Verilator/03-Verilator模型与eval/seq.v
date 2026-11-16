module seq(
  input      clk,
  input      in,
  output reg q
);
  wire d = ~in;
  always @(posedge clk) q <= d;
endmodule
