// 未初始化的自保持触发器（iverilog 侧）：四态模型如实打印 x
`timescale 1ns/1ps
module tb_xu_iv;
  reg clk;
  wire r;
  xu dut(.clk(clk), .r(r));
  initial begin
    clk = 0;
    #1 clk = 1; #1 clk = 0;
    #1 clk = 1; #1 clk = 0;
    #1 clk = 1; #1 clk = 0;
    $display("r=%b", r);
    $finish;
  end
endmodule
