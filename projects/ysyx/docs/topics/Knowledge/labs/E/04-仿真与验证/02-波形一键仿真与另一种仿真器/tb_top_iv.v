// 双控开关的四种输入组合（iverilog 侧），与 tb_table.cpp 打印同一张表
`timescale 1ns/1ps
module tb_top_iv;
  reg a, b;
  wire f;
  top dut(.a(a), .b(b), .f(f));
  integer i;
  reg [1:0] v;
  initial begin
    for (i = 0; i < 4; i = i + 1) begin
      v = i;
      #1 a = v[1]; b = v[0];
      #1 $display("a=%d b=%d f=%d", a, b, f);
    end
    $finish;
  end
endmodule
