# 05 波形格式与 GTKWave

    实验    批 2 生成 VCD/FST 并查看（labs/E/02 回填实测截图与体积对比）
    依据    VCD：IEEE 1364-2005 第 19 章（value change dump 格式标准定义）；
            FST：Verilator User Guide "Simulating"章 tracing 小节；GTKWave 文档。
            教程引用处：tutorials/E/04 2.1 节

这一篇讲波形文件的格式本质和查看工具的最小用法。

## 你会在哪里撞见它

- 批 2：给双控开关加波形，VCD 和 FST 各生成一次，对比体积
- 批 3：流水灯调试，看 led/count/count>=5000000 的时序关系
- 讲义警告"不要长时间生成波形"：磁盘耗尽会崩系统（纪律见下）

## 这篇要回答的问题

1. VCD 文件里到底装了什么？（它是一份什么结构的文本）
2. FST 凭什么小约 50 倍？代价是什么？
3. Verilator 侧开波形要哪几步？GTKWave 最小用法是什么？

## 1 VCD：标准定义的文本格式

VCD（Value Change Dump）是 IEEE 1364-2005 第 19 章标准定义的格式：按时间顺序记录"哪根信号在哪个时刻变成了什么值"。骨架长这样（示意）：

```text
$date ... $end
$timescale 1ps $end          # 时间单位与精度
$var wire 1 ! a $end         # 信号声明：类型 宽度 代号 名字
$var wire 1 " b $end
$upscope $end $enddefinitions $end
#0                           # 时间戳：0 时刻
0!                           # 代号 ! 的信号（a）变为 0
1"                           # 代号 " 的信号（b）变为 1
#10                          # 下一时刻
...
```

全部是文本，可读性好，代价是体积：每根信号每个变化一行，信号多、时间长就爆炸。

## 2 FST：压缩二进制

FST（Fast Signal Trace）：GTKWave 作者为 VCD 做的压缩替代——信号声明去重、值变化差分编码、二进制存储。讲义经验值约 VCD 的 1/50。代价：只有 GTKWave 支持（FST 是它生态的格式）。结论：查看工具锁定 GTKWave 的场景（我们就是）无脑选 FST。

## 3 Verilator 侧开波形的三步

1. 编译期：verilator 命令加 `--trace-fst`（VCD 则 `--trace`）
2. 运行期 main 里初始化并绑定：

```cpp
#include "verilated_fst_c.h"          // FST 的 trace 类（VCD 是 verilated_vcd_c.h）
Verilated::traceEverOn(true);         // 打开运行时 tracing 开关
VerilatedFstC* tfp = new VerilatedFstC;
top->trace(tfp, 99);                  // 绑定模型；99=记录的层次深度
tfp->open("/tmp/top.fst");            // 只写 /tmp（纪律见第 5 节）
```

3. 每拍循环里：`tfp->dump(sim_time); sim_time++;` 记当前值；收尾 `tfp->close();`

类名以批 2 实测为准回填（不同版本头文件名可能有差）。

## 4 GTKWave 最小用法

1. 打开：`gtkwave /tmp/top.fst`（沙箱要 -Gui 批次，批 0 实测无 DISPLAY 连 --version 都报错）
2. 左侧层级树点开模块，中部信号列表选中要看的，Append 加入右侧波形窗
3. Zoom Fit 全览；滚轮缩放；标尺测两事件间隔；信号名右键改显示进制（二进制看单根线，十六进制看总线）

## 5 纪律：波形只写 /tmp

两条原因叠加：

1. 磁盘：讲义警告长时间生成波形会耗尽磁盘；/tmp 在沙箱有独立容量上限，崩不了卷
2. tracer：git_commit 宏会 `git add . -A`，波形落进 npc 目录会被收进 tracer 提交（见 04-Makefile语法速查 第 6 节）；/tmp 在 workbench 仓外，天然隔离
