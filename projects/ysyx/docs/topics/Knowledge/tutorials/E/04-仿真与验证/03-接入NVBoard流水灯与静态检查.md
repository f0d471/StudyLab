# 03 接入 NVBoard、流水灯与静态检查

    实验目录    labs/E/04-仿真与验证/03-接入NVBoard流水灯与静态检查/
    环境        沙箱 Ubuntu 26.04 LTS；Verilator 5.052 2026-09-05 rev 5.052-983a06a；
                NVBoard（workbench 内置副本）；SDL2 2.32.10
                本章的输出、退出码均为 2026-11-14 在沙箱里实跑，2026-11-16 复跑判据全绿
    对应讲义    2607 版 E4「接入NVBoard」「示例: 流水灯(时序逻辑电路)」「静态代码检查」
                三小节

**读前须知**：需要第 01、02 章的底子：

1. testbench 骨架与模型对象（第 01 章）：NVBoard 的 main 就是又一个 testbench，
   只是输入来自板卡界面
2. 波形与 make（第 02 章）：本章的构建照搬同样的结构，多接一个 NVBoard 库
3. lint 的警告分级（第 01 章 DECLFILENAME 一节）：本章第 4 节系统化

板上可视行为由学员当面确认：机器只核到"构建成功 + 无头运行
健康"为止。本章用了 SDL_VIDEODRIVER=dummy 让程序无头跑起来验证主循环不崩，窗口里
的画面要靠学员看。

**在整条链里的位置**：上接第 02 章（波形与一键仿真已经就位），下接第 04 章（描述
电路的纪律）。本章把"仿真环境"升级成"虚拟板卡环境"：输入不再是 C++ 里的赋值，
而是板上的开关；输出落到 LED。流水灯是第一个时序电路实验，复位、时钟、分频三件事
一起练。静态检查收尾，把 lint 从"见过几条警告"变成一套用得起的纪律。

往后 NPC 的所有外设实验（蜂鸣器、数码管、VGA）都长在 NVBoard 上，
接不进去就没有以后；时序电路不复位的坑（第 3.3 节实测给你看）会在真项目里以"灯
全灭、查不出原因"的形态出现；静态检查本章现场配齐：三类常见问题在编译期就有警告
可抓（第 4 节逐类实测）。

## 0 起点

第 02 章结束时，你的双控开关能一键仿真、能录波形，但输入是 testbench 里写死的赋值。
三个问题引出本章：

1. 输入能不能来自一个看得见的界面（板上的开关），输出落到 LED？
2. 流水灯要时钟和复位了：testbench 怎么"造"时钟、复位是干什么的？
3. 代码越写越多，能不能在编译期就抓住一批错误？

读完本章你要能解释：约束文件的三行字怎么变成 C++ 里的绑定调用；`single_cycle` 里
两次 eval 各干什么；复位改成不复位，流水灯会发生什么；
`-Wall` 下哪些警告默认就开、哪些要它才开。

## 1 NVBoard 三件套怎么建立联系

### 1.1 [做 L1] 从 make 命令开始读

讲义给的读法是"从 make 命令开始，看看一切是如何发生的"。NVBoard 官方示例的
Makefile 值得通读；本篇 labs 里的 Makefile.nv 是它的缩减版，把三件套的关系收在
五十四行。从上往下读：

1. 顶层与源文件由变量给出（TOPNAME、VSRC、CSRC）
2. 约束文件 .nxdc 经一条规则变成 C++：
   `python3 $(NVBOARD_HOME)/scripts/auto_pin_bind.py $^ $@`（`$^` 是规则的全部依赖，
   这里即约束文件；`$@` 是规则的目标，这里即生成的绑定文件）。这就是把"端口名对
   板卡元件"的声明翻译成绑定代码的机器
3. `include $(NVBOARD_HOME)/scripts/nvboard.mk`：NVBoard 是库不是框架。它提供两条
   规则：把 src/ 下全部源码编成 build/nvboard.a 归档，以及 SDL2 的编译链接选项。
   它只把头文件目录追加进 INC_PATH，转成 -I 参数是使用方的职责（example 里有这行，
   漏抄会报 nvboard.h 找不到，本库踩过）
4. 最终规则把你的 .v、你的 main.cpp、auto_bind.cpp、nvboard.a 一起交给 verilator

### 1.2 [做 L1] 约束文件：三行字进，绑定代码出

top.nxdc 的全部内容：

```text
top=top

a SW0
b SW1
f LD0
```

第一行声明顶层模块名，随后每行"端口名 板卡引脚"。跑一遍构建后，build/top/auto_bind.cpp
里生成（原文摘录）：

```cpp
nvboard_bind_pin( &top->a, 1, SW0);
nvboard_bind_pin( &top->b, 1, SW1);
nvboard_bind_pin( &top->f, 1, LD0);
```

三行声明变成三次绑定调用，参数依次是：模型成员的地址、位宽、板卡引脚枚举。这个
生成物让"改引脚分配"变成改三行文本，不用动 C++。

## 2 双控开关上板

### 2.1 [做 L2] main 换成板卡驱动

接 NVBoard 的 main 与第 01 章的 testbench 骨架同构，差别在输入输出走板卡。labs 里的
main_sw.cpp 全文：

```cpp
#include <nvboard.h>
#include <Vtop.h>

static TOP_NAME dut;

void nvboard_bind_all_pins(TOP_NAME* top);

int main() {
  nvboard_bind_all_pins(&dut);
  nvboard_init();

  while (1) {
    nvboard_update();
    dut.eval();
  }
}
```

与第 01 章的 testbench 相比多了三处：`nvboard_bind_all_pins(&dut)` 执行 auto_bind.cpp
生成的绑定；`nvboard_init()` 起板卡窗口；循环里每圈先调 `nvboard_update()` 再
`eval()`。

`nvboard_update` 管界面这一侧：它按帧率节流（每秒 FPS 次），读输入事件、把输出端口
的值刷到 LED 这类元件上。开关的输入不经过它：你在窗口里点一下开关，NVBoard 的事件
处理当场经 `pin_poke` 把新状态写进绑定的模型端口（auto_bind 绑的就是这个地址），
下一次 `eval()` 就用上了。构建
（make -f Makefile.nv，产物 build/top/top）后无头验证：SDL_VIDEODRIVER=dummy 下跑
3 秒仍活着（timeout 收掉时返回 124），说明主循环健康。真窗口里拨 SW0/SW1，LD0 按
异或亮灭，这半句要学员当面确认。

## 3 流水灯：时序逻辑与复位

### 3.1 讲义的参考实现

light.v（讲义原文，本章照录）：

```verilog
module light(
  input clk,
  input rst,
  output reg [15:0] led
);
  reg [31:0] count;
  always @(posedge clk) begin
    if (rst) begin led <= 1; count <= 0; end
    else begin
      if (count == 0) led <= {led[14:0], led[15]};
      count <= (count >= 5000000 ? 32'b0 : count + 1);
    end
  end
endmodule
```

三件事逐行看：复位时装入 led=1（第 0 号灯亮）并清零计数器；计数器数到 5000000 归零，
把时钟分频到肉眼可见的节拍；count 为零的那个周期把 led 左移一位（最高位绕回最低
位），形成流动。这是一个标准的同步时序电路：全部状态变化发生在 clk 上升沿。

### 3.2 testbench 造时钟与复位

main_light.cpp 里两个仿真原语（讲义伪代码的落地，labs 原文）：

```cpp
static void single_cycle() {
  dut.clk = 0; dut.eval();
  dut.clk = 1; dut.eval();
}
static void reset(int n) {
  dut.rst = 1;
  while (n -- > 0) single_cycle();
  dut.rst = 0;
}
```

`single_cycle` 先把 clk 摆 0、再把 clk 摆 1，各自 eval 一次：0 到 1 的跳变就是上升沿。
仿真器里没有天生的时钟：clk 只是模型上的一个成员，你把它从 0 改成 1 再 eval，
沿就造出来了。复位 10 拍是惯例量，作用见下一小节的对照实验。

### 3.3 [做 L1] 不复位会怎样：一次对照实验

labs 里的 tb_light.cpp 不开窗口，直接看模型状态（led 和内部计数器 count）。带参数
运行跳过复位。两次运行，本机实测：

```text
正常（先 reset(10)）：              不复位：
after reset: led=0001 count=0      no reset:   led=0000 count=0
1 cycle:    led=0002 count=1       1 cycle:    led=0000 count=1
step 1:     led=0004 count=1       step 1:     led=0000 count=1
step 2:     led=0008 count=1       step 2:     led=0000 count=1
```

不复位的分支里，led 的初值是 0（两态模型的默认初值），把 0 移位一万次还是 0：
灯永远不亮。这就是"时序电路必须复位"的机制级解释：复位给状态一个确定的起点，
没有它，电路的行为取决于初值，而两态模型里初值默认全 0，恰好把"该亮的第 0 号灯"
也熄灭了。正常分支还能看出分频节拍：复位后第一拍 led 从 0001 移到 0002，此后 tb_light
每跑 5000001 拍，led 恰好多移一位（0004、0008，每步结束时 count 都回到 1）。5000001
这样数出来：移位发生在 count==0 的那一拍，同一拍 count 装进 1；接下来 count 从 1
一路加到 5000000 要走 4999999 拍，数满的下一拍归零，归零后的下一拍 count 又是 0、
再移一次。两次移位之间恰是 4999999+1+1=5000001 拍，肉眼可见的"流动"就是这个节拍。

## 4 静态检查：把 lint 用成纪律

### 4.1 [做 L1] 参考实现本身就该零警告

先给基线：讲义的 light.v 在 `--lint-only -Wall` 下退出码 0、无诊断行（Verilation
统计行不算警告）。写时序电路可以既快又干净。

### 4.2 [做 L2] 三类典型警告：触发、默认状态、修法

labs 里三个小文件各埋一类问题，实测（5.052）：

1. 未驱动（lint_undriven.v）：wire w 声明了、用了、没人驱动。
   `--lint-only -Wall` 报 `Warning-UNDRIVEN: Signal is not driven: 'w'` 并退出码 1。
   修法：接上驱动，或删掉
2. 未使用（lint_unused.v）：端口 b 从未被用到。报
   `Warning-UNUSEDSIGNAL: Signal is not used: 'b'`。这一类与 UNDRIVEN 一样默认关闭，
   `-Wall` 才打开（不带 -Wall 时两者都安静地过）。
   修法：用上它，或删掉
3. 位宽截断（lint_width.v）：4 位赋给 3 位。报
   `Warning-WIDTHTRUNC: ... expects 3 bits ... generates 4 bits`，并且不开 `-Wall`
   也报（默认开，见已知的坑第 4 条）。修法：把位宽对齐（lint_clean.v 就是对齐版，
   `-Wall` 零警告）

三类修完的对照：lint_clean.v 在 `-Wall` 下退出码 0、无诊断行。

处置分级照讲义：代码逻辑类的警告改代码消除；确认不影响逻辑的风格类才用
`-Wno-<类别>` 单独关。总开着 lint 的理由第 4.2 节的实测本身就给了：三类问题都能在
编译期抓住，其中位宽截断语法上完全合法，编译期唯一的拦截点就是这条默认就开、默认
致命的警告，把它 `-Wno-` 掉，这类代码就一路编过进到仿真里了。

## 回看

1. 三件套：约束文件声明端口对引脚，auto_pin_bind.py 翻译成绑定调用，nvboard.mk
   把库编成归档并递上 SDL 选项，证据在第 1 节
2. 上板的 main 与普通 testbench 同构，多的是 nvboard_init/update，证据在第 2 节
3. 时钟是造出来的，复位给状态确定的起点，不复位的流水灯灯全灭，证据在第 3.3 节
4. lint 纪律：`-Wall` 开全，逻辑类修代码，风格类单独关，证据在第 4 节

## 自检

1. 改引脚分配要动几个文件、几行？（第 1.2 节）
2. `single_cycle` 里的两次 eval 能不能换顺序？换了对沿有什么影响？（第 3.2 节，
   先猜再用 tb_light 验证）
3. 把流水灯的分频常数改成 500，板上会看到什么？tb_light 会看到什么？（第 3.3 节）
4. 哪类警告不用 -Wall 也报？为什么恰恰是它？（第 4.2 节）
5. nvboard.h 找不到，第一个该查什么？（第 1.1 节第 3 条）

## 已知的坑

1. 抄 example 的 Makefile 漏掉 INCFLAGS 那行，nvboard.h 报找不到：nvboard.mk 只
   追加 INC_PATH，转 -I 是使用方的活（第 1.1 节，踩过）
2. 两个工程共用一个 build/ 目录，第二个工程的 auto_bind.cpp 不重生（比 nxdc 新）：
   按顶层名分目录（Makefile.nv 的 BUILD_DIR 设计，踩过）
3. `-s` 判日志为空会把 Verilation 统计行当警告：判零警告要看"无 % 开头的诊断行"
   （labs 脚本踩过）
4. UNDRIVEN 在 5.052 默认关，`-Wall` 才开；WIDTHTRUNC 默认开。写"默认"之前跑一遍
   不带 -Wall 的（第 4.2 节，实测纠过）
5. NVBoard 是库，构建会在 NVBOARD_HOME 下写 build/：workbench 只读，先拷副本再编
   （labs 的做法）

## 交出了什么

现在你能够：把任何模块接上 NVBoard（约束、构建、无头验证三步）；写带时钟复位的
testbench 并解释每一拍；用对照实验证明复位的必要性；把 lint 开到最严并分类处置。

往 npc 里接入 NVBoard、把双控开关和流水灯在自己的工程里复现，是讲义任务，归学员
（核对方式与本章相同，外加 tracer 记录）。下一章换赛道：不学新工具，学描述电路的纪律
（为什么讲义禁行为建模、两个官方模板怎么用）。

## 依据

| 正文说法 | 依据 |
| --- | --- |
| 三件套关系与 nvboard.mk 的职责 | nvboard/scripts/nvboard.mk 原文；Makefile.nv 构建实测 |
| auto_bind.cpp 的三行绑定 | labs build/top/auto_bind.cpp 原文 |
| main_sw/main_light 的循环结构 | labs 文件；无头运行 timeout 124 实测 |
| 点开关经 pin_poke 直写绑定端口，nvboard_update 按帧率节流刷新界面 | nvboard/src/event.cpp（mousedown 调 pin_poke）、src/nvboard.cpp（diff > 1000000/FPS 分支）、include/pins.h（pin_poke 写绑定的地址） |
| 复位后 0001、每 5000001 拍移一位、不复位恒 0000 | tb_light 实测输出（build/tl.run）；5000001 的推导在第 3.3 节 |
| light.v 在 -Wall 下零警告 | labs 实测 |
| 三类警告的文本与默认开关状态 | labs 实测：UNDRIVEN/UNUSEDSIGNAL 需 -Wall，WIDTHTRUNC 默认开 |
| 讲义对警告分级处置的要求 | 讲义「静态代码检查」小节（任务框） |

## 讲义任务对照

| 讲义任务（框类型） | 本章落点 |
| --- | --- |
| 运行 NVBoard 示例、从 make 开始读懂（任务+提示） | 第 1 节（example 通读 + Makefile.nv 缩减版） |
| 在 NVBoard 上实现双控开关（任务） | 第 2 节；npc 内接入为学员任务 |
| 将流水灯接入 NVBoard（任务） | 第 3 节；可视化由学员确认 |
| 通过 Verilator 进行静态代码检查（任务） | 第 4 节 |
| Verilator 进阶学习（链接） | 超出本章范围，官方文档已入库 |
