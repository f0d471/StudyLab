# 06 Reg 与 MuxKey 模板逐行拆

    实验    批 4：流水灯重构为 Reg 实例 + 四问作答（labs/E/04 回填）
    依据    讲义 2607 版 E4「若干代码风格和规范」节模板原文；
            IEEE 1364-2005 第 9/11 章（过程赋值/事件模型，四问作答的出处）。
            教程引用处：tutorials/E/04 4.2、4.4 节

这一篇把讲义给的两个官方模板逐行拆开。模板的地位：初学者不写 always（规范），触发器和选择器全部靠实例化这两个模板描述电路。拆开不是为了让你写这类代码，而是让你用的时候知道脚下是什么、并给批 4 的四问作答垫底。

## 你会在哪里撞见它

- 批 4：流水灯的 always 版参考实现重构为 Reg 实例
- 之后所有阶段的时序部件：D8 的 NPC 里寄存器堆、PC 全是 Reg 实例
- 选择器：译码器（E5 的 IDU）全是 MuxKey 实例

## 这篇要回答的问题

1. Reg 模板内部那个 always 为什么合规？实例化参数怎么对应电路？
2. MuxKey 的 lut 打包格式是什么？内部用"或运算阵列"怎么实现键值匹配？
3. 两个使用注意（参数匹配、键值互异）为什么是真约束而不是仪式？

## 1 Reg 模板逐行

```verilog
module Reg #(WIDTH = 1, RESET_VAL = 0) (   // 两个参数：位宽、复位值，均有默认
  input clk,
  input rst,                               // 同步复位（posedge clk 采样）
  input  [WIDTH-1:0] din,                  // 数据输入
  output reg [WIDTH-1:0] dout,             // 数据输出（reg：always 内赋值所需类型）
  input wen                                // 写使能
);
  always @(posedge clk) begin              // 时序语义：clk 上升沿触发
    if (rst)      dout <= RESET_VAL;       // 复位：装默认值
    else if (wen) dout <= din;             // 使能有效：采样输入；无效则保持（不写 else 保持）
  end
endmodule
```

要点：

1. 这是**唯一允许的 always 形态**：posedge 单事件 + 非阻塞赋值 + 无锁存器结构（rst/wen 两分支覆盖全部情况，dout 每沿必被赋值或保持）。规范禁的是"初学者随手写行为建模"，模板内部是讲义审查过的例外。
2. 电路对应：一个 N 位 D 触发器组 + 复位逻辑 + 使能门。
3. 实例化（讲义示例）：

```verilog
Reg #(1, 1'b1) i0 (clk, rst, in[0], out[0], 1'b1);  // 1 位，复位值 1，写使能恒 1（每拍都采）
Reg #(3, 3'b0) i1 (clk, rst, in[3:1], out[3:1], out[0]);  // 3 位，复位 0，使能是另一根信号
```

端口按位置连接，参数 #(...) 在前。

## 2 MuxKey 模板逐行

### 2.1 使用面

```verilog
MuxKeyWithDefault #(NR_KEY, KEY_LEN, DATA_LEN) 实例名 (
  out, key, default_out,
  {
    键值0, 数据0,
    键值1, 数据1,
    ...
  }
);   // 不带默认值的 MuxKey 则少一个 default_out 端口
```

lut 是一个大拼接位串：`NR_KEY * (KEY_LEN + DATA_LEN)` 位，每对 (键, 数据) 依序首尾拼接。

### 2.2 内部（MuxKeyInternal）

```verilog
module MuxKeyInternal #(NR_KEY = 2, KEY_LEN = 1, DATA_LEN = 1, HAS_DEFAULT = 0) (
  output reg [DATA_LEN-1:0] out,
  input [KEY_LEN-1:0] key,
  input [DATA_LEN-1:0] default_out,
  input [NR_KEY*(KEY_LEN + DATA_LEN)-1:0] lut
);
  localparam PAIR_LEN = KEY_LEN + DATA_LEN;          // 每对 (键,数据) 的位宽
  wire [PAIR_LEN-1:0]        pair_list [NR_KEY-1:0]; // 切开的每对
  wire [KEY_LEN-1:0]         key_list  [NR_KEY-1:0]; // 每对的键
  wire [DATA_LEN-1:0]        data_list [NR_KEY-1:0]; // 每对的数据
  genvar n;
  generate
    for (n = 0; n < NR_KEY; n = n + 1) begin         // 展开期循环：硬件批量生成，不是运行时
      assign pair_list[n] = lut[PAIR_LEN*(n+1)-1 : PAIR_LEN*n];  // 从大位串切下第 n 对
      assign data_list[n] = pair_list[n][DATA_LEN-1:0];          // 低段是数据
      assign key_list[n]  = pair_list[n][PAIR_LEN-1:DATA_LEN];   // 高段是键
    end
  endgenerate
  reg [DATA_LEN-1:0] lut_out;
  reg hit;
  integer i;
  always @(*) begin                       // 组合逻辑（模板内部允许；仍是初学者禁区）
    lut_out = 0; hit = 0;
    for (i = 0; i < NR_KEY; i = i + 1) begin
      lut_out = lut_out | ({DATA_LEN{key == key_list[i]}} & data_list[i]);
      // key 命中第 i 对时，{DATA_LEN{1}} 全 1，选出该对数据；不中则全 0，或运算不干扰
      hit = hit | (key == key_list[i]);   // 记录是否命中过任一对
    end
    if (!HAS_DEFAULT) out = lut_out;                      // 无默认：不中则 out=0
    else out = (hit ? lut_out : default_out);             // 有默认：不中取 default_out
  end
endmodule
```

机制一句话：**把"等值比较"乘到数据上再按位或**——每个键一个比较器，命中选出该对数据，全部或起来。这就是 N 选一选择器的硬件本质，等价于 case 语句综合出的结构。

### 2.3 使用两注意（讲义原文的两条，都是真约束）

1. 参数必须与信号宽度一致：NR_KEY/KEY_LEN/DATA_LEN 与 lut 拼接的位数不符，切分错位，结果错——而且 MuxKeyInternal 内部没写位宽检查，错位不报错，直接输出错值
2. 键值必须互异：同键命中多对时 lut_out 是多对数据的按位或——未定义结果。硬件不帮你查重

### 2.4 讲义示例对照

mux21（2 选 1）与 mux41（4 选 1）见 tutorials/E/04 或讲义原文；读法：先数键值对、再验证参数、最后对 lut 拼接逐对点名。

## 3 与四问的接口

模板内部有 always @(*)、generate、for——它们为什么合规而你的 always 不合规，正是批 4 事件模型四问要回答的：generate for 是**展开期**批量生成硬件（结构化），always @(*) 是**描述组合逻辑的约束**而非过程式编程。四问作答进 tutorials/E/04 4.3 节。
