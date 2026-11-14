module cntt(          // 模板版：实例化 + 连线
  input clk,
  input rst,
  input en,
  output [7:0] q
);
  wire [7:0] qn;
  assign qn = q + 8'd1;                    // 下一拍的值是一条连线规则
  Reg #(8, 8'd0) r0 (clk, rst, qn, q, en);  // 状态只存在模板触发器里
endmodule
