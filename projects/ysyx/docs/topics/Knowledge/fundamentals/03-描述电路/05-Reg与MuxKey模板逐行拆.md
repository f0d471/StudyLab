# 05 Reg 与 MuxKey 模板逐行拆

    实验目录    labs/fundamentals/03-描述电路/05-Reg与MuxKey模板逐行拆/
    环境        沙箱 Ubuntu 26.04 LTS；Verilator 5.052 2026-09-05 rev 5.052-983a06a
                本篇的输出均为 2026-11-14 在沙箱里实跑，2026-11-16 复跑判据全绿、输出一致
    依据        讲义「若干代码风格和规范」小节的模板原文（labs/tpl.v 一字未改）；
                行为全部来自本篇 lab 实测

**读前须知**：本篇拆讲义给的两个官方模板。读它之前需要：触发器和多路选择器是什么
（第 03 章的流水灯见过触发器，选择器在教程第 04 章第 2 节刚用过）；教程第 04 章讲了
"为什么初学者不写 always、用模板描述电路"，本篇回答"模板里面到底是什么"。
模板逐行拆的意义在于使用得放心：两条使用注意（参数错位、键值重复）的后果本篇都
实测给你看。

## 你会在哪里撞见它

1. 教程第 04 章的重构练习：把行为建模换成模板实例，来本篇查模板的端口和参数
2. 以后 NPC 的寄存器堆、PC、译码器全是这两个模板的实例
3. 某次 MuxKey 输出"莫名其妙不对"时：先查本篇第 3 节的两条注意

## 这篇要回答的问题

1. Reg 模板内部那四行 always 在做什么？复位、保持、采样各是什么行为？
2. MuxKey 的 lut 怎么切？命中怎么选数？不命中输出什么？
3. 讲义警告的两条使用注意（参数错位、键值重复），实测后果是什么？

## 1 Reg 模板：四行 always 的三个行为

模板原文（labs/tpl.v，讲义一字未改）：

```verilog
module Reg #(WIDTH = 1, RESET_VAL = 0) (
  input clk,
  input rst,
  input [WIDTH-1:0] din,
  output reg [WIDTH-1:0] dout,
  input wen
);
  always @(posedge clk) begin
    if (rst) dout <= RESET_VAL;
    else if (wen) dout <= din;
  end
endmodule
```

逐行读：参数 WIDTH 定位宽、RESET_VAL 定复位值，都有默认。always 块只在 clk 上升沿
执行；执行时三选一：rst 有效就装入 RESET_VAL；否则 wen（write enable，写使能）有效
就采样 din；两者都不有效时一行都不执行，dout 保持。赋值用 `<=`（非阻塞赋值，更新
推迟到 NBA 区，fundamentals/01 第 1 节讲调度区、第 5 节讲它为什么要紧）。
`output reg` 的 reg 是"能在 always 里赋值"的类型名，和"寄存器"是两回事（第 03 章
流水灯的 output reg led 同理）。

三个行为实测（tb_reg.cpp，4 位、复位值 5，本机实测输出）：

```text
after reset: dout=5      复位装入 RESET_VAL
wen=0 din=a: dout=5      使能无效：摆着的 din 也不采，保持复位值
wen=1 din=a: dout=a      使能有效：采样 din
wen=0 din=3: dout=a      采到的值继续保持；din 这次从 a 变到 3，也不采
reset again: dout=5      运行中再复位，回到 RESET_VAL
```

## 2 MuxKey：lut 怎么切，命中怎么选

### 2.1 使用面

实例化时给三个参数（键值对数量 NR_KEY、键位宽 KEY_LEN、数据位宽 DATA_LEN），把
(键, 数据) 对依次拼进 lut（look-up table，查表，就是那条拼接起来的大位串）：

```verilog
MuxKeyWithDefault #(3, 2, 4) m1 (y_def, key, 4'hf, {
  2'b00, 4'h1,
  2'b01, 4'h2,
  2'b10, 4'h4
});
```

模板有三个变体：MuxKey（不带默认值）、MuxKeyWithDefault（带默认值）、MuxKeyInternal
（两者共用的内部实现）。MuxKey 的三个端口依次是 out、key、lut；MuxKeyWithDefault
多一个 default_out，夹在 key 与 lut 之间。

### 2.2 内部机制

先看模板原文（labs/tpl.v，讲义一字未改）：

```verilog
module MuxKeyInternal #(NR_KEY = 2, KEY_LEN = 1, DATA_LEN = 1, HAS_DEFAULT = 0) (
  output reg [DATA_LEN-1:0] out,
  input [KEY_LEN-1:0] key,
  input [DATA_LEN-1:0] default_out,
  input [NR_KEY*(KEY_LEN + DATA_LEN)-1:0] lut
);

  localparam PAIR_LEN = KEY_LEN + DATA_LEN;
  wire [PAIR_LEN-1:0] pair_list [NR_KEY-1:0];
  wire [KEY_LEN-1:0] key_list [NR_KEY-1:0];
  wire [DATA_LEN-1:0] data_list [NR_KEY-1:0];

  genvar n;
  generate
    for (n = 0; n < NR_KEY; n = n + 1) begin
      assign pair_list[n] = lut[PAIR_LEN*(n+1)-1 : PAIR_LEN*n];
      assign data_list[n] = pair_list[n][DATA_LEN-1:0];
      assign key_list[n]  = pair_list[n][PAIR_LEN-1:DATA_LEN];
    end
  endgenerate

  reg [DATA_LEN-1 : 0] lut_out;
  reg hit;
  integer i;
  always @(*) begin
    lut_out = 0;
    hit = 0;
    for (i = 0; i < NR_KEY; i = i + 1) begin
      lut_out = lut_out | ({DATA_LEN{key == key_list[i]}} & data_list[i]);
      hit = hit | (key == key_list[i]);
    end
    if (!HAS_DEFAULT) out = lut_out;
    else out = (hit ? lut_out : default_out);
  end
endmodule

// 不带默认值的选择器模板
module MuxKey #(NR_KEY = 2, KEY_LEN = 1, DATA_LEN = 1) (
  output [DATA_LEN-1:0] out,
  input [KEY_LEN-1:0] key,
  input [NR_KEY*(KEY_LEN + DATA_LEN)-1:0] lut
);
  MuxKeyInternal #(NR_KEY, KEY_LEN, DATA_LEN, 0) i0 (out, key, {DATA_LEN{1'b0}}, lut);
endmodule

// 带默认值的选择器模板
module MuxKeyWithDefault #(NR_KEY = 2, KEY_LEN = 1, DATA_LEN = 1) (
  output [DATA_LEN-1:0] out,
  input [KEY_LEN-1:0] key,
  input [DATA_LEN-1:0] default_out,
  input [NR_KEY*(KEY_LEN + DATA_LEN)-1:0] lut
);
  MuxKeyInternal #(NR_KEY, KEY_LEN, DATA_LEN, 1) i0 (out, key, default_out, lut);
endmodule
```

逐段读。参数 NR_KEY 是对数、KEY_LEN 是键宽、DATA_LEN 是数据宽，HAS_DEFAULT 是
内外有别的开关（外部包装用参数把它定死）。端口四个：out、key、default_out
（HAS_DEFAULT=0 时不接实际值）、lut。

第一段是编译期的 generate 循环，管"切表"：每对占 PAIR_LEN 位（localparam 在展开期
算好），pair_list[n] 从 lut 的第 PAIR_LEN*n 位起切 PAIR_LEN 位；对里数据在低段、键
在高段，data_list 与 key_list 各取半边。拿 2.1 节的实例算 n=0：PAIR_LEN=5，
pair_list[0] = lut[4:0]，正是 2'b00 连 4'h1 那五位的拼接；data_list[0]=4'h1，
key_list[0]=2'b00。

第二段是运行期的组合 always，管"选数"：lut_out 先清 0，随后对每一对算
`{DATA_LEN{key == key_list[i]}} & data_list[i]`。复制算子把比较结果（1 位）复制成
DATA_LEN 位当掩码，命中是全 1、不命中是全 0；与该对数据相与，命中留下数据、不命中
清 0，再或进 lut_out。全部或完，命中的数据就到了 lut_out。hit 记录是否有任何一对
命中。收尾按 HAS_DEFAULT 二选一：不带默认值的版本 out 恒为 lut_out（全不命中时
lut_out 就是 0，等效输出 0，不查 hit）；带默认值的版本 out = hit ? lut_out :
default_out。

外部包装 MuxKey 把 HAS_DEFAULT 固定为 0、default_out 接 `{DATA_LEN{1'b0}}`；
MuxKeyWithDefault 与它的差别只有两处，HAS_DEFAULT 传 1、端口表多出 default_out。
两者共用同一段内部实现，只差最后那一步二选一。

以后拼更大的选择器（4 选 1、8 选 1）还是这段机制：每个键一个比较器，命中选数，
全或起来。

### 2.3 实测

tb_mux.cpp 对同一个 key 驱动四个探针（本机实测）：

```text
key=0 plain=1 def=1 dup=1 mis=1
key=1 plain=2 def=2 dup=6 mis=0
key=2 plain=4 def=4 dup=0 mis=2
key=3 plain=0 def=f dup=0 mis=0
```

plain 列读三件事：三个键各选对数据（1、2、4）；key=3 不命中，MuxKey 输出 0 而
MuxKeyWithDefault 输出默认值 f。dup 列见第 3 节，mis 列见第 3 节。

## 3 两条使用注意的实测后果

讲义要求使用者保证两条：参数与实际一致、键值互异。违反了会怎样，本篇实测。

### 3.1 键值重复：输出是按位或

dup 探针的 lut 里放了两个 2'b01（数据分别是 2 和 4）。key=1 时两对同时命中，
`2 | 4 = 6`，实测输出 6；原本想用的 2'b10 键已经不在表里，key=2 落空输出 0。
结果未定义的意思是模板不给你任何语义承诺：这里实测是按位或的 6，但这只是实现碰巧
如此，换模板写法、换工具不保证还是它。

### 3.2 参数错位：位宽恰好相等时静默出错

mis 探针把同一份 18 位 lut 按 (3 位键, 3 位数据) 去声明。每对 6 位、三对共 18 位，
总位宽和 (2, 4) 版恰好一样，于是没有任何宽度警告，构建日志干净。但切出来的表变了：
按 3 位键去比 2 位的 key（探针把 key 显式接成 `{1'b0, key}`，补零是实验自己做的，
labs/mux_top.v），key=1 补成 001，表里的键是 000、010、100，
比不中，输出 0；key=0 与 key=2 恰好撞上 000 和 010，输出 1 和 2。对照第 2.3 节：
预期的 1、2、4 变成了实测的 1、0、2。位宽不等的错位（比如声明两对实际拼三对）会被
WIDTH 类警告拦下（mux_bad.v 实测，默认致命）；恰好相等的错位没人拦，只能靠人保证。

## 4 模板里的 always 为什么合规

教程第 04 章要求初学者不写 always，模板里却有两个。它们合规的理由：

1. Reg 的 always：posedge 单事件、非阻塞赋值。边沿触发的块综合出触发器，本来就不涉
   锁存器（"分支不全推锁存器"是组合块的规则，教程第 04 章第 3 节那颗雷长在
   `always @(*)` 上）；rst 与 wen 两个条件把"赋值还是保持"说全，是语义完整而
   不是防锁存器的手段，wen 即使能。这是标准的同步时序描述
2. MuxKeyInternal 的组合 always：描述的是一张查表（组合逻辑），不是时序；
   `always @(*)` 是"本块是组合逻辑"的声明，配合块内每个分支都给 out 赋值

模板是被讲义背书的例外：使用者通过实例化获得这两个电路，不自己动手写过程描述。
标准里这两类块的调度位置（NBA 区更新、组合在活动区求值）见
[fundamentals/01](../01-仿真器/01-两种范式与工具谱系.md) 第 1 节与标准 4.4、4.9。

## 依据

| 正文说法 | 依据 |
| --- | --- |
| 模板原文 | 讲义「若干代码风格和规范」小节；labs/tpl.v 与讲义逐字一致 |
| Reg 五个行为 | tb_reg 实测输出 |
| 命中选数、不命中 0 与默认值、重复键按位或 | tb_mux 实测 |
| 参数错位静默出错（1、0、2 对预期 1、2、4） | tb_mux 实测；切分推演在正文 3.2 节 |
| 位宽不符被 WIDTH 拦下 | mux_bad.v 实测（默认致命） |
| 两类 always 的调度位置 | IEEE 1800-2017 的 4.4（分层调度区，fundamentals/01 第 1 节引）与 4.9（赋值的调度含义，含 4.9.4 非阻塞赋值） |
