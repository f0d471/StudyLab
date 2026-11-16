module loop(
  input  en,
  output f
);
  wire x;
  assign x = en ? ~x : 1'b0;
  assign f = x;
endmodule
