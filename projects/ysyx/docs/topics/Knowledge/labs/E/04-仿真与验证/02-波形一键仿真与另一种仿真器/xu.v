module xu(
  input clk,
  output reg r
);
  always @(posedge clk) r <= r;
endmodule
