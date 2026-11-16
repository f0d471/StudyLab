module widths(
  input  [0:0]  w1,
  input  [7:0]  w8,
  input  [8:0]  w9,
  input  [15:0] w16,
  input  [16:0] w17,
  input  [31:0] w32,
  input  [32:0] w33,
  input  [63:0] w64,
  input  [64:0] w65,
  output [64:0] o
);
  assign o = {64'b0, w1} ^ {57'b0, w8} ^ {56'b0, w9} ^ {49'b0, w16} ^ {48'b0, w17}
           ^ {33'b0, w32} ^ {32'b0, w33} ^ {1'b0, w64} ^ w65;
endmodule
