// 带 #5 延迟的触发器（iverilog 侧）：$monitor 打印每个时间点的值
`timescale 1ns/1ps
module tb_late_iv;
  reg clk, d;
  wire q;
  late dut(.clk(clk), .d(d), .q(q));
  initial $monitor("t=%0t d=%b q=%b", $time, d, q);
  initial begin
    clk = 0; d = 0;
    #10 d = 1;
    #5 clk = 1;          // t=15 上升沿，q 应在 t=20 才变
    #10 d = 0;
    #5 clk = 0;
    #10 $finish;
  end
endmodule
