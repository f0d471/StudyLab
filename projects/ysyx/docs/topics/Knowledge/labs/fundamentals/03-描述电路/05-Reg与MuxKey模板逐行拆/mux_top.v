// MuxKey 模板的四个探针，共用同一个 2 位的 key
module mux_top(
  input  [1:0] key,
  output [3:0] y_plain,   // 正常：三个键各对一份数据
  output [3:0] y_def,     // 带默认值
  output [3:0] y_dup,     // 键值重复：两个 2'b01
  output [2:0] y_mis      // 参数错位：声明成 KEY_LEN=3、DATA_LEN=3，位宽恰好相等
);
  MuxKey #(3, 2, 4) m0 (y_plain, key, {
    2'b00, 4'h1,
    2'b01, 4'h2,
    2'b10, 4'h4
  });
  MuxKeyWithDefault #(3, 2, 4) m1 (y_def, key, 4'hf, {
    2'b00, 4'h1,
    2'b01, 4'h2,
    2'b10, 4'h4
  });
  MuxKey #(3, 2, 4) m2 (y_dup, key, {
    2'b00, 4'h1,
    2'b01, 4'h2,
    2'b01, 4'h4
  });
  // 同一份 18 位的 lut，按 (3 位键, 3 位数据) 去切：每对仍是 6 位，总位宽不变
  MuxKey #(3, 3, 3) m3 (y_mis, {1'b0, key}, {
    2'b00, 4'h1,
    2'b01, 4'h2,
    2'b10, 4'h4
  });
endmodule
