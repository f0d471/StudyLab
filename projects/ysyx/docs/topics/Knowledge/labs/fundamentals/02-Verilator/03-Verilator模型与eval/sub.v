module sub(
  input        clk,
  input  [7:0] d,
  output [7:0] q
);
  reg [7:0] r;
  always @(posedge clk) r <= d;
  assign q = r;
endmodule
