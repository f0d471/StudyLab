// x 的传染：iverilog 四态语义下的三条运算
`timescale 1ns/1ps
module tb_xprop;
  reg x1;                 // 从未赋值，值为 x
  reg [3:0] v;            // 从未赋值，四位全 x
  initial begin
    #1;
    $display("0&x=%b 1&x=%b x+1=%b", 1'b0 & x1, 1'b1 & x1, v + 4'd1);
    $finish;
  end
endmodule
