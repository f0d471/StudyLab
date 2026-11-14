# 01 Verilator 把电路变成程序

    实验    labs/E/04-仿真与验证/01-Verilator把电路变成程序/
            check.sh 基线 82 PASS / 0 FAIL / 0 SKIP（本机约 32 秒）
            mutate.sh 基线 25 OK / 0 BAD（本机约 15 分钟）
    环境    WSL2 沙箱：Ubuntu 26.04 LTS，内核 6.6.114.1-microsoft-standard-WSL2
            Verilator 5.052 2026-09-05 rev 5.052-983a06a
            g++ 15.2.0，GNU Make 4.4.1，GNU Awk 5.3.2
            timeout 来自 uutils coreutils 0.8.0，script 来自 util-linux 2.41.3
            本章的输出、退出码、文件大小均为 2026-11-13 在沙箱里实跑
    讲义    2607 版 E4「RTL仿真(Simulation) - 功能验证」的前两小节：
            "STFW + RTFM搭建Verilator仿真环境"与"示例: 双控开关(组合逻辑电路)"

---

**读前须知**：

- C 语言的指针与 `->`，以及 `rand()`、`assert` 和 `printf`：testbench 的主体就是这些。程序的退出码和 `$?` 也要会看，第 6、7 节靠退出码判断程序是怎样结束的。
- C++ 的类：只需要读得懂 `new`、`delete` 和 `指针->成员函数()`。第 2.2 节就地讲到够用为止。
- Verilog：`module`、端口、`assign`，HDLBits 的程度。
- Linux 终端：输出重定向 `>`、`2>`、`2>&1` 与管道 `|`。

[fundamentals/01 Verilator 模型与 eval](../../../fundamentals/01-Verilator模型与eval.md) 可以读完本章再看。它把本章第 3、4、8 节用到的机制展开：生成文件全表、端口宽度与 C++ 类型的对应、`eval` 每个区的实测轨迹、组合逻辑的静态排序、收敛上限，以及时钟和延迟。

**这一章在整条链里的位置**：上接 E4 的环境检查（[00-环境四查](../../../labs/E/04-仿真与验证/00-环境四查.md)：Verilator 5.052 在位，NPC_HOME 已设）。本章搭的是此后所有仿真共用的骨架：Verilator 把一个 Verilog 模块翻译成一个 C++ 类，一段 C++ 主循环（testbench）反复做四件事，写输入、调用 `eval`、读输出、检查。后面的内容都往这个循环里加东西：波形是在循环里记录信号，NVBoard 是在循环里把信号接到虚拟板卡，DiffTest 是在循环里把处理器的状态和参考模型逐步比较。下一章讲波形和 Makefile，对应讲义"打印并查看波形"与"编写Makefile"两小节。

**不学它会怎样**：

1. 改了输入却忘了调用 `eval`，读到的输出是旧值，`assert` 失败，退出码 134（第 4、6 节）。
2. `assert` 失败时，重定向到文件的打印一行都不剩，出错前的现场看不到（第 6.1 节）。
3. 文件名和模块名不一致：加 `-Wall` 时构建报 DECLFILENAME；不加 `-Wall` 时 g++ 报 `fatal error: Vtop.h: No such file or directory`（第 6.3 节）。
4. 循环条件沿用 `!contextp->gotFinish()` 的写法，跑起来停不下来，只能按 Ctrl+C（第 7 节）。
5. 给 1 位的端口写进 2，普通构建不报错，输出悄悄变成 2（第 4.5 节）。
6. 电路里有组合环：构建报 UNOPTFLAT；把这个警告关掉，运行时报 DIDNOTCONVERGE 退出（第 8 节）。

## 0 起点

讲义给了一个双控开关模块，一共 7 行 Verilog：

```verilog
module top(
  input a,
  input b,
  output f
);
  assign f = a ^ b;
endmodule
```

一条命令把它和一个 C++ 文件一起变成可执行文件 `Vtop`。运行 `Vtop`，它打印 10 行和一行统计：

```bash
verilator --cc --exe --build -j 0 -Wall --Mdir build/switch tb_switch.cpp top.v
build/switch/Vtop
```

```text
a = 1, b = 0, f = 1
a = 1, b = 1, f = 0
a = 1, b = 1, f = 0
a = 0, b = 0, f = 0
a = 1, b = 1, f = 0
a = 0, b = 1, f = 1
a = 0, b = 1, f = 1
a = 1, b = 0, f = 1
a = 0, b = 0, f = 0
a = 0, b = 0, f = 0
seen: 00=3 01=2 10=2 11=3
```

每一行的 `f` 都等于 `a` 异或 `b`，程序以退出码 0 结束。读完本章，要能把这个结果从头解释一遍：

1. 那条命令把 Verilog 变成了什么，`Vtop` 里装的是什么（第 1、2 节）
2. 端口 `a`、`b`、`f` 在 C++ 里是什么，`assign` 变成了什么（第 3 节）
3. 写了输入以后为什么必须调用 `eval`，`f` 在哪一刻被算出来，这个电路为什么不需要时钟（第 4 节）
4. testbench 的每一行在做什么，最后一行的数字怎么来，为什么每次运行结果都一样（第 5 节）
5. 怎样确认这个测试真的能发现错误（第 6 节）
6. 循环为什么停不下来，要按 Ctrl+C 才能退出（第 7 节）
7. 什么样的电路会让 `eval` 停不下来（第 8 节）

**怎么跟着做**：所有命令都在沙箱里运行。从 Workspace 根目录进入沙箱的交互 shell，再进入实验目录，先把 check.sh 跑一遍：

```powershell
& .\Tools\wsl-sandbox\sandbox.ps1 -Action Shell -Project ysyx
```

```bash
cd /workspace/docs/topics/Knowledge/labs/E/04-仿真与验证/01-Verilator把电路变成程序
bash check.sh
```

check.sh 先清空 `build/`，再从源码重建本章的全部产物，逐条核对，最后一行打印 `82 PASS / 0 FAIL / 0 SKIP`，本机约 32 秒。跑完以后，正文里的每条命令都可以在这个目录里再手敲一遍，产物和输出都落在 `build/` 下。不用本平台的读者，在装有 Verilator 5.052 的 Linux 里进入实验目录同样可以跑；版本不同时，第 1 节的版本判据会先变红。

每个 [判] 块末尾都有一段"注错见红"，写着改坏哪一处、哪几条判据会变红。这些说法由同一目录的 mutate.sh 逐条实跑：它把每一种改坏做在一份副本上，跑副本的 check.sh，核对变红的判据恰好是正文写的那几条，最后一行打印 `25 OK / 0 BAD`。注错见红里写的条数按 check.sh 的判据行计，[判] 列表有时把几条判据合写在一行里。它要把 check.sh 完整跑 25 遍，本机约 15 分钟，不必每次都跑；改了 check.sh 或实验源码以后再跑。

---

## 1 Verilator 是什么

起点那条命令的第一个词是 `verilator`。这一节的问题：这个工具是什么，沙箱里装的是哪个版本。

### 1.1 [做 L1] 官网与版本

讲义要求先通过搜索找到 Verilator 的官网。官网是 https://verilator.org ，用户指南在 https://verilator.org/guide/latest/ 。指南第 1 章的概述给出了它的身份：Verilator 读入 Verilog 或 SystemVerilog 设计，把它转换成一个 C++（或 SystemC）模型，这个模型经过编译以后可以执行。概述把它定位为编译器，和传统仿真器分开。典型用法分五步，前四步是每次都要走的：

1. 运行 `verilator`。它读入设计，做 lint 检查，输出模型的 `.cpp` 和 `.h` 文件。这一步叫 Verilate，产物叫 Verilated 模型。
2. 用户写一个 C++ 的包装文件，里面是 `main()`，在 `main()` 里创建模型对象。
3. 用 C++ 编译器把包装文件、Verilator 生成的文件和 Verilator 自带的运行库一起编译，得到仿真可执行文件。
4. 运行这个可执行文件，这就是仿真本身。
5. 如果构建时打开了相应的选项，可执行文件还会记录波形，或者输出覆盖率数据供事后分析。本章不用这一步，波形在下一章。

第 2 节在一个最小的例子上把前四步逐一看一遍。

讲义要求从 git 安装 stable 版本。沙箱里已经装好了从源码构建的 5.052，命令路径是 `/toolchains/verilator-5052/bin/verilator`，本仓不重装。查版本：

```bash
verilator --version
```

```text
Verilator 5.052 2026-09-05 rev 5.052-983a06a
```

三段依次是版本号 5.052、发布日期 2026-09-05、构建所用的源码修订。

在线指南比沙箱里的版本新：本章写作时 https://verilator.org/guide/latest/ 是 5.054，比 5.052 新，在线页面也不按版本分路径。所以凡是和版本有关的行为，本章以 5.052 的 man 页与实测为准。man 页在沙箱里可以这样打开：

```bash
man /toolchains/verilator-5052/share/man/man1/verilator.1
```

**这一节搭好的积木**：Verilator 是一个编译器，输入 Verilog，输出 C++ 模型；仿真要靠我们自己写的 `main()` 和 C++ 编译器才能跑起来。沙箱里是 5.052。接下来的问题：前四步在一个最小的例子上各自产出什么。

---

## 2 手册示例：从 Verilog 到可执行文件

讲义要求找到 Verilator 手册里的 C++ 示例并照着做。它在指南第 2.2 节"Example C++ Execution"。这一节的问题：第 1 节的前四步，每一步产出了什么。

### 2.1 [做 L1] 只做第一步：`--cc`

示例的设计文件 `our.v`：

```verilog
module our;
initial begin $display("Hello World"); $finish; end
endmodule
```

1. `module our;`：一个名叫 `our` 的模块，没有端口。
2. `initial begin ... end`：`initial` 块在仿真开始时执行一次。块里有两条语句：`$display("Hello World")` 打印一行文字，`$finish` 结束仿真。
3. `endmodule`：模块结束。

先让 Verilator 只做第一步，不编译：

```bash
verilator --cc -Wall --Mdir build/cconly our.v
```

- `--cc`：输出 C++ 模型（另一种输出是 `--sc`，SystemC 模型）。
- `-Wall`：打开 lint 警告和代码风格警告，包括通常默认关闭的风格警告；少数专用警告不在其中。第 6.3 节会看到它的后果。
- `--Mdir build/cconly`：产物放进 `build/cconly/`。不给这个参数时，产物放在 `obj_dir/`。
- `our.v`：设计文件。

输出是三行报告（`build/cconly.log`）：

```text
- V e r i l a t i o n   R e p o r t: Verilator 5.052 2026-09-05 rev 5.052-983a06a
- Verilator: Built from 0.029 MB sources in 2 modules, into 0.022 MB in 5 C++ files needing 0.000 MB
- Verilator: Walltime 0.169 s (elab=0.007, cvt=0.044, bld=0.000); cpu 0.017 s on 1 threads; allocated 17.941 MB
```

第 2 行说生成了 5 个 C++ 文件。第 3 行是耗时和内存：`Walltime`、括号里的 `elab` 与 `cvt`、`cpu` 和 `allocated` 每次运行都可能不一样，不变的是 `bld=0.000`。bld 统计的是构建，也就是调用 make 编译 C++ 的时间；这条命令没有编译，所以是零。2.2 节加上 `--build` 以后，这个数就不再是零。

产物目录里一共 13 个文件：

```bash
ls -1 build/cconly
```

```text
Vour.cpp
Vour.h
Vour.mk
Vour__Syms.h
Vour__Syms__Slow.cpp
Vour___024root.h
Vour___024root__0.cpp
Vour___024root__0__Slow.cpp
Vour___024root__Slow.cpp
Vour__pch.h
Vour__ver.d
Vour__verFiles.dat
Vour_classes.mk
```

| 文件 | 是什么 |
| --- | --- |
| `Vour.h`、`Vour.cpp` | 模型类 `Vour` 的声明和实现。testbench 只需要 `#include "Vour.h"` |
| `Vour___024root.h`、`Vour___024root__0.cpp` | 设计本体。`__024` 是 Verilator 对字符 `$` 的转义（`$` 的 ASCII 码是 0x24），`___024root` 读作 `$root`，即 SystemVerilog 设计层次的根 |
| `Vour___024root__Slow.cpp`、`Vour___024root__0__Slow.cpp` | 设计本体里很少执行的冷代码，例如变量初始化和 `initial` 块 |
| `Vour__Syms.h`、`Vour__Syms__Slow.cpp` | 符号表，把模型的各部分连在一起 |
| `Vour.mk`、`Vour_classes.mk` | 编译这些文件用的 Makefile 片段 |
| `Vour__pch.h` | 生成的每个 `.cpp` 开头都先包含它 |
| `Vour__ver.d`、`Vour__verFiles.dat` | Verilator 自己的依赖与时间戳记录，下次运行时用来判断要不要重新翻译 |

目录里没有 `.o`，也没有可执行文件：第一步只产出 C++ 源码。

所有文件名都以 `Vour` 开头，这也是模型类的类名。类名的规则是：没有用 `--top` 指定顶层模块时，取 `V` 加上命令行里第一个 Verilog 文件的文件名（去掉扩展名）。`our.v` 于是得到 `Vour`。第 2.4 节和第 6.3 节都要用到这条规则。

### 2.2 [做 L1] 后三步：`--exe --build`

包装文件 `sim_main.cpp` 与指南 2.2 节的示例逐字相同：

```cpp
#include "Vour.h"
#include "verilated.h"
int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    Vour* top = new Vour{contextp};
    while (!contextp->gotFinish()) { top->eval(); }
    delete top;
    delete contextp;
    return 0;
}
```

1. `#include "Vour.h"`：2.1 节生成的头文件，里面声明了类 `Vour`。`#include "verilated.h"`：Verilator 运行库的头文件，里面声明了 `VerilatedContext` 等类。
2. `VerilatedContext* contextp = new VerilatedContext;`：`new 类名` 在堆上创建一个该类的对象，返回指向它的指针，作用相当于 C 里的 `malloc` 加上初始化。`VerilatedContext` 是仿真上下文，仿真时间、命令行参数和"是否已经 `$finish`"这类全局状态都存在它里面。
3. `contextp->commandArgs(argc, argv);`：`argc` 和 `argv` 是 `main` 收到的命令行参数，`argc` 是个数，`argv` 是字符串数组，`argv[0]` 是程序名。`->` 和 C 里用结构体指针访问成员的写法相同。C++ 的成员可以是函数，这里调用的就是成员函数 `commandArgs`。它把命令行参数交给运行库，以 `+verilator+` 开头的参数由运行库自己解释，第 4.4 节会用到。
4. `Vour* top = new Vour{contextp};`：创建模型对象，构造时告诉它属于哪个上下文。花括号里是传给构造函数的参数。
5. `while (!contextp->gotFinish()) { top->eval(); }`：只要上下文里"已经 `$finish`"的标志还没立起来，就一直调用模型的成员函数 `eval()`。`eval` 做什么是第 4 节的问题。
6. `delete top;`、`delete contextp;`：销毁对象，释放内存，与 `new` 成对。
7. `return 0;`：程序以退出码 0 结束。

一条命令做完后三步：

```bash
verilator --cc --exe --build -j 0 -Wall --Mdir build/our sim_main.cpp our.v
```

- `--exe`：要生成可执行文件，`main()` 在命令行里给出的 C++ 文件中。
- `--build`：Verilator 翻译完以后自己调用 make 编译，不用再手敲 make。
- `-j 0`：并行任务数，0 表示按机器的 CPU 数决定。
- `sim_main.cpp`：C++ 文件也写在命令行上。它会被写进生成的 Makefile，和模型一起编译。

输出在 `build/our.log`。每条 g++ 命令都很长，下面用省略号代替其中一长串 `-I`、`-D` 与 `-Wno-` 选项，其余原样：

```text
make: Entering directory '/workspace/docs/topics/Knowledge/labs/E/04-仿真与验证/01-Verilator把电路变成程序/build/our'
ccache g++  -I.  -MMD ... -Os  -c -o sim_main.o ../../sim_main.cpp
ccache g++ -Os  -I.  -MMD ... -c -o verilated.o /toolchains/verilator-5052/share/verilator/include/verilated.cpp
ccache g++ -Os  -I.  -MMD ... -c -o verilated_threads.o /toolchains/verilator-5052/share/verilator/include/verilated_threads.cpp
python3 /toolchains/verilator-5052/share/verilator/bin/verilator_includer -DVL_INCLUDE_OPT=include Vour.cpp Vour___024root__0.cpp Vour___024root__Slow.cpp Vour___024root__0__Slow.cpp Vour__Syms__Slow.cpp > Vour__ALL.cpp
ccache g++ -Os  -I.  -MMD ... -c -o Vour__ALL.o Vour__ALL.cpp
g++    sim_main.o verilated.o verilated_threads.o Vour__ALL.a    -pthread -lpthread -latomic   -o Vour
rm Vour__ALL.verilator_deplist.tmp
make: Leaving directory '/workspace/docs/topics/Knowledge/labs/E/04-仿真与验证/01-Verilator把电路变成程序/build/our'
- V e r i l a t i o n   R e p o r t: Verilator 5.052 2026-09-05 rev 5.052-983a06a
- Verilator: Built from 0.029 MB sources in 2 modules, into 0.022 MB in 5 C++ files needing 0.000 MB
- Verilator: Walltime 0.933 s (elab=0.008, cvt=0.036, bld=0.807); cpu 0.020 s on 4 threads; allocated 18.223 MB
```

1. `make: Entering directory '.../build/our'`：`--build` 让 make 进入产物目录，按生成的 `Vour.mk` 工作。
2. 前三条 `ccache g++ ... -c`：`-c` 表示只编译不链接，每条产出一个 `.o`。`sim_main.o` 来自我们的包装文件；`verilated.o` 和 `verilated_threads.o` 来自 Verilator 安装目录里的运行库源码（`/toolchains/verilator-5052/share/verilator/include/`），也就是第 1 节第 3 步说的运行库。`ccache` 是编译缓存：同样的输入再编译一次时，直接取上次的结果。
3. `python3 .../verilator_includer ... > Vour__ALL.cpp`：把生成的 5 个 `.cpp` 合成一个 `Vour__ALL.cpp`。这 5 个就是 2.1 节报告里的"5 C++ files"。合成的文件里只有 1 行注释、1 行 `#define` 和 5 行 `#include`，下一条 g++ 把它编成 `Vour__ALL.o`。
4. `Vour__ALL.a`：日志里看不到打包它的命令。Verilator 的 `verilated.mk` 第 255 行在这段命令前加了 `@`，make 执行带 `@` 的命令时不回显。`.a` 是静态库，里面是一包 `.o`。
5. `g++ sim_main.o verilated.o verilated_threads.o Vour__ALL.a ... -o Vour`：链接，把四样东西拼成可执行文件 `Vour`。`-pthread -lpthread -latomic` 是运行库需要的线程库和原子操作库。
6. 最后三行是 Verilator 的报告，`bld` 这一次不再是零。

耗时每次不同。上面这次 Walltime 是 0.933 秒，其中 bld 是 0.807 秒，这么快是因为 ccache 里已经有这几个文件的编译结果。check.sh 还会设置环境变量 `CCACHE_DISABLE=1`，关掉 ccache 再构建一次（产物在 `build/ournc/`，日志是 `build/ournc.log`）。同一次运行里，那一次的 bld 是 5.115 秒，Walltime 是 5.350 秒。这两个数是本机数字，check.sh 只判"不用 ccache 的 bld 超过用 ccache 时的 2 倍"，并打印两个实得值。

四步和产物的对应关系如下图。

```text
  our.v                  sim_main.cpp          verilated.cpp
    |                         |                verilated_threads.cpp
    | verilator --cc          |                     |
    v                         |                     |
  Vour.h Vour.cpp ...         |                     |
  (5 .cpp, Vour.mk)           |                     |
    |                         |                     |
    | includer, g++ -c, ar    | g++ -c              | g++ -c
    v                         v                     v
  Vour__ALL.a             sim_main.o     verilated.o verilated_threads.o
    |                         |                     |
    +------------+------------+---------------------+
                 |
                 | g++ ... -o Vour
                 v
               Vour
```

从左上角看起：`our.v` 经 `verilator --cc` 变成 C++ 源码，这是第 1 步。中间一列的 `sim_main.cpp` 是第 2 步用户写的包装文件。右边一列是 Verilator 自带的运行库。三列各自编译成 `.o`（模型那一列再打包成 `.a`），最后链接成 `Vour`，这是第 3 步。第 4 步是运行它。

`Vour` 是一个普通的 Linux 程序：

```bash
file build/our/Vour
stat -c %s build/our/Vour
```

```text
build/our/Vour: ELF 64-bit LSB pie executable, x86-64, version 1 (GNU/Linux), dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2, BuildID[sha1]=a0deed3dd492777bfe0e30448059d9065fc350c1, for GNU/Linux 3.2.0, not stripped
230880
```

它和 `gcc hello.c -o hello` 的产物是同一种格式：x86-64 的 ELF 可执行文件，本机工具链下 230880 字节。程序里已经没有 Verilog，仿真器就是这个程序本身。

### 2.3 [做 L1] 运行：两行输出各从哪里来

```bash
build/our/Vour; echo "exit=$?"
```

```text
Hello World
- our.v:2: Verilog $finish
exit=0
```

`$display` 和 `$finish` 变成了什么，看生成代码 `build/our/Vour___024root__0__Slow.cpp` 第 13 至 23 行：

```cpp
VL_ATTR_COLD void Vour___024root___eval_initial(Vour___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vour___024root___eval_initial\n"); );
    Vour__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    {
        // Inlined CFunc: _eval_initial__TOP
        VL_WRITEF_NX("Hello World\n",0);
        VL_FINISH_MT("our.v", 2, "");
    }
}
```

`initial` 块变成了函数 `eval_initial`。前四行可以先跳过：一句调试打印、一个指向符号表的指针 `vlSymsp`、一个根对象的引用 `vlSelfRef` 和一行 `// Body` 注释，多数生成函数都有类似的开头。块里的两条语句各变成一个函数调用：`$display` 变成打印函数 `VL_WRITEF_NX`；`$finish` 变成 `VL_FINISH_MT`，带着源文件名 `our.v` 和行号 2。输出第 2 行里的 `our.v:2` 就是这两个参数。

这个函数在 sim_main 第一次调用 `top->eval()` 时执行。`eval` 的内部在运行库 `verilated.cpp` 里，第 4066 至 4079 行：模型第一次求值时先做一次性的初始化，其中一步是 `evalInitial()`，也就是上面这个函数。整个过程按顺序是：

1. 第一次 `eval`：执行 `initial` 块，`VL_WRITEF_NX` 打印 `Hello World`。
2. `VL_FINISH_MT`（`verilated.cpp` 第 245 至 252 行）把"调用 `vl_finish`"包成一条消息投递出去。投递函数（`verilated_imp.h` 第 158 至 163 行）先看当前线程的任务编号：多线程模型的工作线程会把消息排进队列，等 `eval` 结束时再处理；编号为 0 时当场执行。本章的模型都是单线程的，编号保持默认值 0（`verilated.h` 第 1003 行），所以这条消息当场执行。
3. `vl_finish`（`verilated.cpp` 第 166 至 171 行）打印 `- our.v:2: Verilog $finish`，再把上下文里的 `gotFinish` 标志置为真。
4. `eval` 返回。`while` 检查 `!contextp->gotFinish()`，条件为假，循环结束。`eval` 一共只调用了一次。
5. 两次 `delete`，`return 0`，退出码 0。

### 2.4 [做 L1] `$finish` 之后的语句照样执行

2.3 节的第 2、3 步说明，`$finish` 在 Verilator 模型里做的事是打印一行报告、立起一个标志；让仿真停下来的是 C++ 里的 `while`。由此可以推出一个预测：同一个 `initial` 块里写在 `$finish` 后面的语句，照样会执行。`fin.v` 用来验证这个预测：

```verilog
module fin;
initial begin $display("before"); $finish; $display("after"); end
endmodule
```

按 2.1 节的类名规则，`fin.v` 的模型类叫 `Vfin`，所以包装文件要把 `sim_main.cpp` 里的 `Vour` 全部换成 `Vfin`。用 sed 生成一份，再构建、运行：

```bash
mkdir -p build/fin && sed 's/Vour/Vfin/g' sim_main.cpp > build/fin/sim_main.cpp
verilator --cc --exe --build -j 0 -Wall --Mdir build/fin/obj build/fin/sim_main.cpp fin.v
build/fin/obj/Vfin; echo "exit=$?"
```

`sed 's/Vour/Vfin/g'` 把每一行里的 `Vour` 替换成 `Vfin`，末尾的 `g` 表示一行里出现几次就替换几次。

```text
before
- fin.v:2: Verilog $finish
after
exit=0
```

`$finish` 的报告紧跟在 `before` 后面，说明它是当场打印的；`after` 照样出现，说明 `$finish` 没有打断 `initial` 块。仿真在哪里结束，由 testbench 的循环决定。第 7 节会看到这件事的另一面：设计里没有 `$finish`，循环又只看 `gotFinish`，程序就停不下来。

### 2.5 [判] 第 1、2 节

    [ ] verilator --version 输出 Verilator 5.052 2026-09-05 rev 5.052-983a06a
    [ ] 只给 --cc：build/cconly 里 13 个文件，有 Vour.h、Vour.cpp、Vour.mk，
        没有 .o 和 Vour；报告里 bld=0.000
    [ ] 生成的 5 个 .cpp 都包含 Vour__pch.h
    [ ] 加 --exe --build：日志里有一行 g++ 把 sim_main.o verilated.o
        verilated_threads.o Vour__ALL.a 链接成 Vour
    [ ] Vour__ALL.cpp 是 1 行注释、1 行 #define、5 行 #include
    [ ] 设置 CCACHE_DISABLE=1 再构建一次，bld 超过用 ccache 时的 2 倍
        （本次实得 5.115 秒与 0.807 秒，本机数字）
    [ ] Vour 是 x86-64 的 ELF 可执行文件，230880 字节（本机工具链）
    [ ] 生成代码里有 VL_WRITEF_NX("Hello World\n",0); 和 VL_FINISH_MT("our.v", 2, "");
    [ ] Vour 一共打印 2 行：Hello World 与 - our.v:2: Verilog $finish，退出码 0
    [ ] Vfin 一共打印 3 行：before、$finish 的报告、after，退出码 0

    注错见红：版本和文件大小是环境判据，实验目录里没有能改坏的源码，mutate.sh
    改的是 check.sh 里的期望值（改成 5.051、230881），各自那一条变红。把 our.v 的
    "Hello World" 改成 "Hello"，VL_WRITEF_NX 与第 1 行输出两条判据变红；把 fin.v
    的 "before" 改成 "BEFORE"，before 那一条变红；删掉 fin.v 里的 $display("after");，
    after 与"一共 3 行"两条变红。VL_FINISH_MT、"第 2 行是 $finish 的报告"与 fin.v
    的"报告紧跟在 before 后面"三条核对生成代码与工具输出，mutate.sh 改 check.sh
    里的期望值（VL_FINISH_MT 改成 VL_STOP_MT，期望报告里的 $finish 改成 $stop），
    这三条变红。真把 our.v 的 $finish
    改成 $stop 也实测过：报告变成 %Error: our.v:2: Verilog $stop，多出一行
    Aborting...，退出码 1；这个改法还会让 ccache 那条一起变红，源码变了，缓存里
    没有这次编译，第一次构建拿不到加速，所以 mutate.sh 不采用它，改成动期望值。
    其余几条（13 个文件、没有 .o、bld=0.000、
    5 个 .cpp 都包含 Vour__pch.h、链接行、Vour__ALL.cpp 的行数、ccache 的倍数）说的是
    Verilator 和工具链的行为，实验源码改不坏它们，由第 1 节的版本判据兜底。

**这一节搭好的积木**：`verilator --cc` 把 Verilog 翻译成一个 C++ 类（类名是 `V` 加文件名）；`--exe --build` 再调用 make 和 g++，把这个类、我们写的 `main()` 和运行库链接成普通的可执行文件。`initial` 块在第一次 `eval` 里执行；`$finish` 只是打印报告、立起 `gotFinish` 标志，停不停由 `main()` 里的循环决定。手册示例没有端口，接下来的问题：一个有输入输出的电路，端口和 `assign` 在 C++ 里变成了什么。

---

## 3 端口变成 C++ 成员，assign 变成 C++ 赋值

讲义的下一步是双控开关。这一节的问题：它的三个端口和一条 `assign`，在生成的 C++ 里分别是什么。

### 3.1 [做 L1] 端口：三个引用

`top.v` 就是第 0 节那 7 行。

1. `module top(` 到 `);`：模块 `top` 有三个端口，`input a`、`input b` 是输入，`output f` 是输出。没有写宽度的端口宽 1 位。
2. `assign f = a ^ b;`：连续赋值，`f` 始终等于 `a` 和 `b` 的异或。真值表是 00 得 0、01 得 1、10 得 1、11 得 0。
3. `endmodule`：模块结束。

双控开关的用途是两个开关（`a`、`b`）控制同一盏灯（`f`）：拨动任意一个开关，灯的亮灭都会翻转。

构建（命令里的 `tb_switch.cpp` 是第 5 节要讲的 testbench，这一节只看生成代码）：

```bash
verilator --cc --exe --build -j 0 -Wall --Mdir build/switch tb_switch.cpp top.v
```

类名按 2.1 节的规则是 `Vtop`。打开 `build/switch/Vtop.h`，第 31 至 36 行：

```cpp
    // PORTS
    // The application code writes and reads these signals to
    // propagate new values into/out from the Verilated model.
    VL_IN8(&a,0,0);
    VL_IN8(&b,0,0);
    VL_OUT8(&f,0,0);
```

注释说这些是应用代码读写的信号，用来把新值送进模型、把结果取出来。`VL_IN8` 和 `VL_OUT8` 是宏，定义在运行库的 `verilated_types.h` 第 251 行与第 261 行：

```cpp
#define VL_IN8(name, msb, lsb) CData name  ///< Declare input signal, 1-8 bits
#define VL_OUT8(name, msb, lsb) CData name  ///< Declare output signal, 1-8 bits
```

宏展开以后，`VL_IN8(&a,0,0);` 变成 `CData &a;`。`msb` 与 `lsb` 两个参数（这里都是 0，即 Verilog 的 `[0:0]`）在展开时被丢掉，只起说明作用。`CData` 又定义在 `verilated.h` 第 119 行：`using CData = uint8_t;`。所以端口 `a` 的 C++ 类型是 `uint8_t &`。

第一，1 位的端口用 8 位整数存。C++ 里最小的整数类型就是 8 位，1 到 8 位宽的端口都用 `CData`；更宽的端口依次用 16 位的 `SData`、32 位的 `IData`、64 位的 `QData`（`verilated.h` 第 119 至 123 行），超过 64 位用数组 `VlWide`（`verilated_types.h` 第 255 行的 `VL_INW`；对照表见 fundamentals/01 第 2 节）。8 位里只有最低位是这个端口的值，其余 7 位按约定必须是 0。第 4.5 节会看到不守这个约定的后果。

第二，`&` 表示引用。C++ 的引用是一个已有变量的另一个名字：读写引用，就是读写它绑定的那个变量。可以把它看成一个自动解引用、并且不能改指向的指针。绑定发生在构造函数里，`build/switch/Vtop.cpp` 第 13 至 15 行：

```cpp
    , a{vlSymsp->TOP.a}
    , b{vlSymsp->TOP.b}
    , f{vlSymsp->TOP.f}
```

真正存放 `a`、`b`、`f` 的地方是根对象 `TOP`，它的类型是 `Vtop___024root`，也就是 `$root`。`top->a = 1` 写的就是 `TOP.a`。

### 3.2 [做 L1] assign：一行 C++ 赋值

`assign f = a ^ b;` 在 `build/switch/Vtop___024root__0.cpp` 第 53 至 59 行：

```cpp
            if ((3ULL & vlSelfRef.__VicoTriggered[0U])) {
                {
                    // Inlined CFunc: _ico_comb__TOP__0
                    vlSelfRef.f = ((IData)(vlSelfRef.a) 
                                   ^ (IData)(vlSelfRef.b));
                }
            }
```

`vlSelfRef` 就是根对象 `TOP`。`(IData)` 把 8 位的 `a`、`b` 先转换成 32 位无符号数再做异或，结果写回 8 位的 `f`。Verilog 的连续赋值变成了一条 C++ 赋值语句，前面还套着一个 `if`。

这条语句写在函数 `Vtop___024root___eval_ico` 里（同一文件第 18 行起）。函数里的语句只在函数被调用时执行，`if` 的条件也要成立才执行。

**这一节搭好的积木**：端口 `a`、`b`、`f` 是模型类里的三个 `uint8_t` 引用，绑定在根对象 `TOP` 的同名成员上；`assign` 变成函数 `eval_ico` 里的一条赋值语句，外面套着一个条件。接下来的问题：这个函数是谁调用的，在什么时候调用，条件是什么。

---

## 4 eval：不调用就不计算

上一节：`f = a ^ b` 是一个函数里的一条语句。这一节的问题：它在什么时候执行；testbench 改了 `top->a` 以后，`f` 在哪一刻变成新值。

### 4.1 [做 L1] 探针：在每一步之后看一眼

`tb_eval.cpp` 在每个动作之后打印一次端口：

```cpp
#include <cstdio>
#include "Vtop.h"
#include "verilated.h"

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    Vtop* top = new Vtop{contextp};

    printf("P0 constructed, no eval yet:  a=%d b=%d f=%d\n", top->a, top->b, top->f);
    top->a = 1;
    top->b = 0;
    printf("P1 set a=1 b=0, no eval:      f=%d\n", top->f);
    top->eval();
    printf("P2 after eval:                f=%d\n", top->f);
    top->eval();
    printf("P3 eval again, inputs same:   f=%d\n", top->f);
    printf("P4 simulation time:           %llu\n", (unsigned long long)contextp->time());
    fflush(stdout);
    top->a = 2;
    top->b = 0;
    top->eval();
    printf("P5 a=2 (wider than 1 bit):    f=%d\n", top->f);

    top->final();
    delete top;
    delete contextp;
    return 0;
}
```

开头多了一行 `#include <cstdio>`，`printf` 和 `fflush` 声明在这个头文件里；其余的开头与 sim_main 相同，只是类名换成了 `Vtop`。1. P0：刚构造完，一次 `eval` 都没调，打印三个端口。
2. P1：写入 `a=1`、`b=0`，不调 `eval`，打印 `f`。
3. P2：调一次 `eval`，打印 `f`。
4. P3：输入不变，再调一次 `eval`，打印 `f`。
5. P4：打印仿真时间 `contextp->time()`。它返回 64 位无符号整数，转换成 `unsigned long long` 以配合 `%llu`。`fflush(stdout)` 把前面的打印立即写出去，原因在 4.5 节。
6. P5：给 1 位的端口 `a` 写 2，调 `eval`，打印 `f`。

最后的 `top->final()` 执行设计里的 `final` 块（本设计没有），仿真结束时按约定调用一次。

```bash
verilator --cc --exe --build -j 0 -Wall --Mdir build/eval tb_eval.cpp top.v
build/eval/Vtop > build/eval.txt 2>&1; echo "exit=$?"; cat build/eval.txt
```

```text
exit=0
P0 constructed, no eval yet:  a=0 b=0 f=0
P1 set a=1 b=0, no eval:      f=0
P2 after eval:                f=1
P3 eval again, inputs same:   f=1
P4 simulation time:           0
P5 a=2 (wider than 1 bit):    f=2
```

先读 P1 到 P3：

1. P1 的 `f=0`：`top->a = 1` 只是往 `TOP.a` 这个字节里写了一个数（3.1 节），没有任何代码去算 `f`。
2. P2 的 `f=1`：调用 `eval` 以后，`f` 变成 `1 ^ 0 = 1`。
3. P3 的 `f=1`：输入没变，再调一次，`f` 不变。

所以 `f` 是在 `eval` 里算出来的，不调用就不计算。P0、P4、P5 留给 4.3 至 4.5 节。

### 4.2 eval 内部：按区循环

`top->eval()` 一路调用下去：

```text
top->eval()                        Vtop.h:61
  Vtop::eval_step()                Vtop.cpp:59-62
    VerilatedEvalLoop::eval()      verilated.h:390-396
      evalImpl()                   verilated.cpp:4055
        evalBegin()                4064       调试构建在这里查输入宽度
        if (!m_didInit) {          4067-4079  只在第一次 eval 时执行
          evalStatic()
          evalInitial()                       initial 块在这里
          do {} while (evalStl())             Settle 区
        }
        evalSample()               4082
        do {} while (evalIco())    4088-4091  ico 区，f = a ^ b 在这里
        do {...} while (evalReact())          act 到 react 五个区，
                                   4095-4126  循环一层套一层
        evalPostponed()            4130
        evalEnd()                  4132
```

图里的 `Vtop::eval_step()` 读作"类 `Vtop` 的成员函数 `eval_step`"，`::` 后面是成员名。从第一行往下读：`eval()` 只有一句，调用 `eval_step()`；`eval_step()` 交给成员 `m_evalLoop`，最后进入运行库的 `evalImpl()`。`evalImpl()` 把一次求值分成若干个区（region），每个区是一个 `do ... while` 循环：调用模型的 `evalXxx()`，只要它返回真，就再调用一次。act、inact、nba、obs、react 五个区的循环一层套一层，react 在最外层，act 在最里层；第 4095、4096 行的注释说明了套法：外层的循环每转一圈，就把排在它前面的各区重跑一遍。

这些区来自 IEEE 1800-2017 第 4.4 节的调度模型。Active、Inactive、NBA（nonblocking assignment update，非阻塞赋值更新）、Observed、Reactive、Postponed 是标准里的区名，对应这里的 act、inact、nba、obs、react 和 postponed；ico 与 stl 是 Verilator 自己加的两个区。ico 是 input combinational 的缩写，专门计算只由顶层输入驱动的组合逻辑；stl（Settle，安定）在第一次 `eval` 的初始化阶段先把组合逻辑算到稳定。双控开关只有一条 `assign`，它只依赖输入 `a`、`b`，所以全部落在 ico 区；`build/switch/Vtop___024root__0.cpp` 第 65 至 103 行的 act、inact、nba、obs、react 五个函数都只有一句 `return (0U);`，各转一圈就退出。

ico 区的函数是 3.2 节看到的 `Vtop___024root___eval_ico`，第 18 至 63 行：

```cpp
bool Vtop___024root___eval_ico(Vtop___024root* vlSelf, CData/*0:0*/ firstIteration) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___eval_ico\n"); );
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VicoExecute;
    // Body
    vlSelfRef.__VicoTriggered[1U] = ((0xfffffffffffffffeULL 
                                      & vlSelfRef.__VicoTriggered[1U]) 
                                     | (IData)((IData)(firstIteration)));
    {
        // Inlined CFunc: _eval_triggers_vec__ico
        vlSelfRef.__VicoTriggered[0U] = (QData)((IData)(
                                                        ((((IData)(vlSelfRef.b) 
                                                           != (IData)(vlSelfRef.__Vtrigprevexpr___TOP__b__0)) 
                                                          << 1U) 
                                                         | ((IData)(vlSelfRef.a) 
                                                            != (IData)(vlSelfRef.__Vtrigprevexpr___TOP__a__0)))));
        vlSelfRef.__Vtrigprevexpr___TOP__a__0 = vlSelfRef.a;
        vlSelfRef.__Vtrigprevexpr___TOP__b__0 = vlSelfRef.b;
        if (VL_UNLIKELY(((1U & (~ (IData)(vlSelfRef.__VicoDidInit)))))) {
            vlSelfRef.__VicoDidInit = 1U;
            vlSelfRef.__VicoTriggered[0U] = (1ULL | vlSelfRef.__VicoTriggered[0U]);
            vlSelfRef.__VicoTriggered[0U] = (2ULL | vlSelfRef.__VicoTriggered[0U]);
        }
    }
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vtop___024root___dump_triggers__ico(vlSelfRef.__VicoTriggered, "ico"s);
    }
#endif
    __VicoExecute = Vtop___024root___trigger_anySet__ico(vlSelfRef.__VicoTriggered);
    if (__VicoExecute) {
        {
            // Inlined CFunc: _eval_body__ico
            if ((3ULL & vlSelfRef.__VicoTriggered[0U])) {
                {
                    // Inlined CFunc: _ico_comb__TOP__0
                    vlSelfRef.f = ((IData)(vlSelfRef.a) 
                                   ^ (IData)(vlSelfRef.b));
                }
            }
        }
    }
    return (__VicoExecute);
}
```

1. 第 25 至 27 行：把"这是本轮第一次调用"记进 `__VicoTriggered[1]` 的最低位。这一位是 Verilator 的内部触发位，下面的 `if` 只看 `__VicoTriggered[0]`。
2. 第 30 至 35 行：算出两个触发位。第 0 位是"`a` 和上次记下的值不同"，第 1 位是"`b` 和上次记下的值不同"。上次的值存在 `__Vtrigprevexpr___TOP__a__0` 与 `__Vtrigprevexpr___TOP__b__0` 两个成员里。
3. 第 36、37 行：把当前的 `a`、`b` 记下来，留给下一次比较。
4. 第 38 至 42 行：标志 `__VicoDidInit` 为 0 说明这是模型的第一次 ico 调用。这时不管比较结果如何，两个触发位都强制置 1，同时把标志置 1，以后不再进来。下面推 P2 时会看到，第一次 `eval` 里只靠比较是看不到输入变化的，这两行让 ico 区的逻辑在第一次 `eval` 里一定执行一次。
5. 第 49 行：`trigger_anySet__ico`（同一文件第 111 至 124 行）把 `__VicoTriggered` 的两个 64 位字逐个检查，有一位是 1，`__VicoExecute` 就为真。第 25 至 27 行那个内部位也算在内，所以在本设计里，每次 `eval` 的 ico 区第一次调用总是返回真，ico 区每次 `eval` 都要调用两次。没有 ico 逻辑的设计不是这样：fundamentals/01 第 7 节的时序电路里，`eval_ico` 直接返回假。
6. 第 53 至 59 行：`a` 或 `b` 有一个变了（`3ULL` 是 64 位无符号整数字面量 3，二进制 11，同时看第 0、1 位），就执行 `f = a ^ b`。
7. 第 62 行：返回"这一次有没有执行"。`evalImpl()` 的 `do ... while` 看到真，就再调用一次。

用它推一遍 P2。P2 前面的 `eval` 是模型的第一次 `eval`，ico 区之前先走 4.2 节图里 `if (!m_didInit)` 那一段初始化：

1. `eval_static`（`build/switch/Vtop___024root__0__Slow.cpp` 第 12、13 行）只有两句，把此刻的 `a=1`、`b=0` 记成"上次的值"。
2. Settle 区的 `eval_stl`（同一文件第 27 至 56 行）第一次调用时执行同一句 `f = a ^ b`，`f` 在这里已经变成 1。
3. ico 区第一次调用：`a`、`b` 和刚记下的值相同，按比较两个触发位都是 0；但 `__VicoDidInit` 还是 0，第 38 至 42 行把两位强制置 1，于是再执行一次 `f = 1 ^ 0`，`f` 仍是 1，返回真。
4. ico 区第二次调用：内部位和两个触发位都是 0，不执行，返回假，ico 区的循环结束。

P3 同样调用两次：

1. 第一次调用：`a`、`b` 和上次记下的值相同，第 0、1 位都是 0，`f = a ^ b` 不执行；但这是本轮第一次调用，内部位是 1，函数照样返回真。
2. 第二次调用：内部位也变成 0，没有任何一位触发，返回假，循环结束。

`f` 在两次调用里都没有被重算，保持 P2 算出的 1。每次 `eval` 里各区实际被调用几次，fundamentals/01 第 4 节用运行库的调试输出逐行看了一遍。

### 4.3 为什么不需要时钟

4.2 节的机制里，算 `f` 的条件只有一个：调用 `eval` 时，`a` 或 `b` 和上次不同（第一次 `eval` 例外，那时 ico 区无条件执行一次，见 4.2 节 P2 的推导）。`Vtop.h` 里只有 `a`、`b`、`f` 三个端口，没有时钟信号，也不需要。

双控开关是组合电路：输出只由当前的输入决定，电路里没有需要保存的状态。testbench 每写一组新输入、调用一次 `eval`，`f` 就在这次调用里算好。"什么时候算"由 testbench 决定，调用 `eval` 的那一刻就是。

时钟在电路里有寄存器时才需要。寄存器只在时钟沿更新，testbench 要自己把时钟输入从 0 写成 1、再从 1 写成 0，每改一次调用一次 `eval`，寄存器的更新才会发生。在 Verilator 的模型里，时钟就是又一个输入，它的变化触发执行 `always @(posedge clk)` 那部分逻辑的区。输入与时钟同一次 `eval` 里变化时的先后关系，fundamentals/01 第 7 节有实测；时序电路的 testbench 留到流水灯那一章。

P4 的 0 说明了另一件事：两次 `eval` 以后，仿真时间仍是 0。仿真时间是上下文里的一个计数器，`eval` 不推进它；要推进，由 testbench 调用 `contextp->timeInc(n)`，它就是把计数器加上 `n`（`verilated.h` 第 746 行）。本章用不到时间，下一章记录波形时要用。

### 4.4 [做 L1] P0 的 0 从哪里来

P0 打印的 `a=0 b=0 f=0` 是构造函数赋的初值。生成代码 `build/switch/Vtop___024root__0__Slow.cpp` 第 167 至 169 行：

```cpp
    vlSelf->a = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 510903276987443985ull);
    vlSelf->b = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 16900879642891266615ull);
    vlSelf->f = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 6217145520856553898ull);
```

`VL_SCOPED_RAND_RESET_I` 在运行库 `verilated.cpp` 第 577 至 587 行：

```cpp
IData VL_SCOPED_RAND_RESET_I(int obits, uint64_t scopeHash, uint64_t salt) VL_MT_UNSAFE {
    const int randReset = Verilated::threadContextp()->randReset();
    if (randReset == 0) return 0;
    IData data = ~0;
    if (randReset != 1) {  // if 2, randomize
        VlRNG rng{Verilated::threadContextp()->randSeed() ^ scopeHash ^ salt};
        data = rng.rand64();
    }
    data &= VL_MASK_I(obits);
    return data;
}
```

初值由运行时设置 `randReset` 决定：0 给全 0，1 给全 1，2 给随机数，最后按位宽 `obits` 截断。Verilator 基本上是二值仿真器，信号没有表示未知的 `x`，Verilog 里"还没赋过值"的状态没法照原样表示，所以由这个设置决定给什么值。它的默认值是 0，P0 的三个 0 就是这么来的。

这个设置可以在运行时用 `+verilator+rand+reset+<值>` 改：

```bash
build/eval/Vtop +verilator+rand+reset+1 > build/eval_ones.txt 2>&1; cat build/eval_ones.txt
```

```text
P0 constructed, no eval yet:  a=1 b=1 f=1
P1 set a=1 b=0, no eval:      f=1
P2 after eval:                f=1
P3 eval again, inputs same:   f=1
P4 simulation time:           0
P5 a=2 (wider than 1 bit):    f=2
```

P0 变成了全 1；P1 的 `f=1` 也是初值，还没算过。这个参数能起作用，靠的是 `main()` 里的 `contextp->commandArgs(argc, argv)`：它把命令行交给运行库。把这一行删掉重新构建，同样的命令下 P0 不再变成全 1，参数被忽略了。

### 4.5 [做 L1] 写进超宽的值：普通构建不拦，调试构建拦

P5 给 1 位的 `a` 写了 2，打印出 `f=2`。按 3.1 节，`a` 是一个 `uint8_t`，写 2 就存下 2；生成代码对整个字节做异或，`2 ^ 0 = 2`，结果原样写进 `f`。普通构建没有任何检查。

模型对 testbench 的要求是：写进输入的值不能有超出端口宽度的位。检查这一条的代码已经生成了，在 `build/eval/Vtop___024root__0.cpp` 第 126 至 139 行，被 `#ifdef VL_DEBUG` 包着：

```cpp
#ifdef VL_DEBUG
void Vtop___024root___eval_debug_assertions(Vtop___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___eval_debug_assertions\n"); );
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if (VL_UNLIKELY(((vlSelfRef.a & 0xfeU)))) {
        Verilated::overWidthError("a");
    }
    if (VL_UNLIKELY(((vlSelfRef.b & 0xfeU)))) {
        Verilated::overWidthError("b");
    }
}
#endif  // VL_DEBUG
```

`0xfe` 是二进制 1111 1110，`a & 0xfe` 不为 0，说明第 1 位到第 7 位里有 1，也就是超出了 1 位。调用它的地方是 4.2 节图里的 `evalBegin()`（`build/switch/Vtop.cpp` 第 64 至 70 行），同样被 `#ifdef VL_DEBUG` 包着。普通构建没有定义 `VL_DEBUG`，这段代码根本不参加编译。

加 `--runtime-debug` 构建一份调试版：

```bash
verilator --cc --exe --build -j 0 -Wall --Mdir build/evaldbg --runtime-debug tb_eval.cpp top.v
build/evaldbg/Vtop > build/evaldbg.txt 2>&1; echo "exit=$?"; cat build/evaldbg.txt
```

构建日志 `build/evaldbg.log` 里，每条 g++ 编译命令都多了 `-ggdb -fsanitize=address,undefined -D_GLIBCXX_DEBUG -DVL_DEBUG=1`，最后的链接命令也多了 `-fsanitize=address,undefined`。其中 `-DVL_DEBUG=1` 定义了宏 `VL_DEBUG`，上面那段检查于是参加编译；`-ggdb` 加入调试信息，`-fsanitize=...` 打开地址和未定义行为的运行时检查，`-D_GLIBCXX_DEBUG` 打开 C++ 标准库的检查，这三项本章不展开。运行结果：

```text
exit=1
P0 constructed, no eval yet:  a=0 b=0 f=0
P1 set a=1 b=0, no eval:      f=0
P2 after eval:                f=1
P3 eval again, inputs same:   f=1
P4 simulation time:           0
%Error: unknown:0: Testbench C set input 'a' to value that overflows what the signal's width can fit
Aborting...
```

1. P0 至 P4 与普通构建相同。
2. `%Error: unknown:0: ...`：写进 2 以后的那次 `eval`，在 `evalBegin()` 里被拦下。`overWidthError`（`verilated.cpp` 第 3943 至 3949 行）拼出这句话，交给 `vl_fatal`，并把文件名写成 `unknown`、行号写成 0，因为出错的地方在 testbench 里，模型不知道是哪一行。
3. `Aborting...`：`vl_fatal`（`verilated.cpp` 第 194 至 214 行）打印完错误，接着打印这一行，然后结束程序。调试级别为 0 时它调用 `exit(1)`，所以退出码是 1；只有用 `+verilator+debug` 打开调试级别时，它才改调 `abort()`。
4. 没有 P5：程序在打印 P5 之前就结束了。

`%Error` 和 `Aborting...` 这两行与 `printf` 一样走 stdout（`vl_print_warn_error` 用的 `VL_PRINTF` 就是 `printf`，`verilated.h` 第 421、422 行）。`exit(1)` 退出前会把 stdout 的缓冲写出去，所以这里即使没有 P4 后面那句 `fflush(stdout)`，P0 至 P4 也不会丢；那句 `fflush` 防的是另一条路：调试级别打开时 `vl_fatal` 走 `abort()`，而 `abort()` 不写出缓冲（第 6.1 节）。

testbench 里写 `rand() & 1` 而不是直接写 `rand()`，就是为了让输入只有最低位可能是 1，满足这条约定（第 5 节）。

### 4.6 [判] 第 3、4 节

    [ ] Vtop.h 的三个端口是 VL_IN8(&a,0,0);、VL_IN8(&b,0,0); 与 VL_OUT8(&f,0,0);
    [ ] 生成代码里有 vlSelfRef.f = ((IData)(vlSelfRef.a) ^ (IData)(vlSelfRef.b));
        （去掉空白和换行后比较）
    [ ] eval 探针：P0 全 0，P1 f=0，P2 f=1，P3 f=1，P4 时间为 0，P5 f=2，
        一共 6 行，退出码 0
    [ ] 加 +verilator+rand+reset+1 运行，P0 变成 a=1 b=1 f=1
    [ ] 调试构建：每条编译命令带 -ggdb -fsanitize=address,undefined
        -D_GLIBCXX_DEBUG -DVL_DEBUG=1，链接命令带 -fsanitize=address,undefined
    [ ] 普通构建的生成代码里也有 overWidthError("a")，被 #ifdef VL_DEBUG 包着
    [ ] 调试构建运行时报 Testbench C set input 'a' to value that overflows ...，
        没有 P5 那一行，退出码非 0（实得 1）

    注错见红：在 P1 的 printf 之前插一句 top->eval();，P1 那条判据变红；删掉 P2
    之前的 top->eval();，P2 那条变红；删掉 contextp->commandArgs(argc, argv);，
    rand+reset 那条变红；把 top->a = 2; 改成 top->a = 1;（不再越界），P5 f=2 和
    调试构建的三条（拦下、没有 P5、退出码）变红；把 top.v 的 a ^ b 改成 a | b，
    生成代码那条变红，第 5 节的六条判据也跟着变红。第 5 节的两条独立判据不变红：
    assert 在第一个 11 上就 abort，a/b/f 的打印一行也没写进文件（缓冲的原因在
    6.1 节，文件里只有 stderr 重定向进来的报错一行），awk 数出的错行自然是 0。
    这正是 6.4 节的注错 4 要先删掉 assert 的原因。
    把 top.v 的 input a、input b、output f 都改成 [7:0]：端口 a、b、f 三条，rand+reset
    那条（a、b、f 的初值都变成 255），普通构建里的 overWidthError("a") 那条（端口
    正好装满 CData，检查不再生成），以及调试构建的三条（拦下、P5 行、退出码）变红。
    f 的生成表达式不变，那条不动。调试构建的编译与链接选项是工具链行为，实验源码
    改不坏，同样由版本判据兜底。

**这一节搭好的积木**：`eval` 按区依次循环；ico 区比较顶层输入和上一次的值，有变化就执行由输入驱动的组合逻辑，一直重复到没有变化为止。所以写了输入必须调用 `eval`，`f` 在这次调用里算好；组合电路不需要时钟，`eval` 也不推进仿真时间。没赋值的信号初值默认是 0。端口宽度的约定要 testbench 自己守，普通构建不检查。接下来的问题：把"写输入、`eval`、读输出"放进循环，怎样让程序自己判断电路对不对。

---

## 5 双控开关的 testbench：随机驱动、eval、assert

上一节手动驱动了一组输入。这一节的问题：怎样让程序自己产生很多组输入，并且自动检查每一组的输出。

### 5.1 [做 L2] 把手册示例的循环改成"驱动、计算、检查"

讲义给的伪代码是这样一个循环：每一轮随机产生 `a`、`b`，写进模型，调用 `eval`，打印，再用 `assert` 检查 `f == (a ^ b)`。讲义同时提醒，顶层模块名与手册示例不同，C++ 文件要相应修改。把它写成完整的程序就是 `tb_switch.cpp`：

```cpp
#include <cassert>
#include <cstdio>
#include <cstdlib>
#include "Vtop.h"
#include "verilated.h"

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    Vtop* top = new Vtop{contextp};

    int n = 10;
    if (argc > 1 && argv[1][0] != '+') n = atoi(argv[1]);
    int seen[4] = {0, 0, 0, 0};

    for (int i = 0; i < n; i++) {
        int a = rand() & 1;
        int b = rand() & 1;
        top->a = a;
        top->b = b;
        top->eval();
        printf("a = %d, b = %d, f = %d\n", a, b, top->f);
        assert(top->f == (a ^ b));
        seen[a * 2 + b]++;
    }
    printf("seen: 00=%d 01=%d 10=%d 11=%d\n", seen[0], seen[1], seen[2], seen[3]);

    top->final();
    delete top;
    delete contextp;
    return 0;
}
```

讲义在这个任务后面放了一个绿色提示框，标题是"上述代码是什么意思?"，内容是：不知道应该怎样修改，说明还不熟悉 C 程序的编写，应该先回去复习 C 语言。

1. 第 1 至 3 行：`<cassert>`、`<cstdio>` 与 `<cstdlib>` 是 C 的 `assert.h`、`stdio.h` 和 `stdlib.h` 在 C++ 里的写法，分别提供 `assert`、`printf` 与 `rand`、`atoi`。
2. 第 4 行与第 10 行：手册示例的 `Vour` 换成了 `Vtop`。讲义要求的"相应修改"就是这两处：头文件名和类名都跟着 `top.v` 变成 `Vtop`（2.1 节的类名规则）。
3. 第 12、13 行：循环次数 `n` 默认是 10；命令行给了第一个参数，并且它不以 `+` 开头，就用 `atoi` 把它转成整数作为次数。排除 `+` 开头的参数，是因为 `+verilator+...` 这类运行时参数也会出现在 `argv` 里（4.4 节）。
4. 第 14 行：`seen` 数组记录四种输入组合各出现了几次。
5. 第 17、18 行：`rand()` 返回 0 到 `RAND_MAX` 之间的整数，`& 1` 只留最低位，结果是 0 或 1。这同时满足了 4.5 节的宽度约定。
6. 第 19、20 行：写输入，写的是根对象里的 `TOP.a`、`TOP.b`（3.1 节）。
7. 第 21 行：`eval`，`f` 在这里算出来（4.2 节）。
8. 第 22 行：打印这一轮的输入和输出。
9. 第 23 行：`assert(条件)` 在条件为假时打印出错位置并调用 `abort()` 结束程序。期望值 `a ^ b` 由 C 自己的异或算出来，不读模型，所以它是一个独立于电路的检查。
10. 第 24 行：`a * 2 + b` 把 00、01、10、11 映射成 0、1、2、3，对应的计数加一。
11. 第 26 行：循环结束后打印四个计数。
12. 第 28 至 31 行：`final()`、两次 `delete`、`return 0`。

和讲义伪代码相比有三处改动：`while (???)` 补全成固定次数的 `for`，循环跑完 `n` 次就自己结束，退出码可以交给机器判断；循环次数可以从命令行读入；加了 `seen` 数组，统计四种输入组合各出现几次。把条件补全成手册示例的 `!contextp->gotFinish()` 的版本放在第 7 节。

这段代码按讲义给出的伪代码补全，属于讲义允许直接给出示例的环境搭建部分。学员在 ysyx-workbench 的 npc 目录里仍要自己写一遍，不要复制本实验目录里的文件。

### 5.2 [做 L1] 跑 10 次：逐行核对，数出 seen

```bash
build/switch/Vtop > build/run10.txt 2>&1; echo "exit=$?"; cat build/run10.txt
```

```text
exit=0
a = 1, b = 0, f = 1
a = 1, b = 1, f = 0
a = 1, b = 1, f = 0
a = 0, b = 0, f = 0
a = 1, b = 1, f = 0
a = 0, b = 1, f = 1
a = 0, b = 1, f = 1
a = 1, b = 0, f = 1
a = 0, b = 0, f = 0
a = 0, b = 0, f = 0
seen: 00=3 01=2 10=2 11=3
```

对照真值表逐行核对，10 行的 `f` 都对，`assert` 一次也没有失败，退出码 0。最后一行对着前 10 行数一遍：

1. 00 出现在第 4、9、10 行，3 次。
2. 01 出现在第 6、7 行，2 次。
3. 10 出现在第 1、8 行，2 次。
4. 11 出现在第 2、3、5 行，3 次。

3 + 2 + 2 + 3 = 10，与循环次数相符。

再运行一次，输出与第一次逐字节相同（`cmp build/run10.txt build/run10b.txt` 没有输出）。原因在 `rand()`：程序从来没有调用 `srand` 设置种子，而 `rand` 的规则是没有设置种子时，等同于用种子 1 开始（man 3 rand）。好处是每次都能复现同一组输入；代价是每次测的也都是这同一组。check.sh 正是利用这一点，对这 10 行做精确判据。

跑 1000 次：

```bash
build/switch/Vtop 1000 > build/run1000.txt 2>&1; echo "exit=$?"; tail -1 build/run1000.txt
```

```text
exit=0
seen: 00=246 01=245 10=265 11=244
```

246 + 245 + 265 + 244 = 1000，四种组合都出现过，1000 次 `assert` 全部通过。

双控开关只有两个 1 位输入，四种组合可以全部枚举，随机驱动在这里不是必需的。它的价值在输入变宽以后：组合多到无法枚举时，随机产生输入、逐一检查仍然可行。

### 5.3 [做 L1] 独立判据：不靠程序自己的 assert

check.sh 不相信程序自己的 `assert`，它从打印出来的每一行重新算一遍 `a ^ b`：

```bash
awk -F'[=,]' '/^a = /{ if ($6+0 != (($2+0) != ($4+0))) n++ } END { print n+0 }' build/run10.txt
```

```text
0
```

1. `-F'[=,]'`：用 `=` 和 `,` 切分字段。`a = 1, b = 0, f = 1` 被切成 6 段，第 2、4、6 段分别是 ` 1`、` 0`、` 1`，即 `a`、`b`、`f` 的值。
2. `/^a = /`：只处理以 `a = ` 开头的行，跳过 `seen:` 那一行。
3. `$2+0`：加 0 把带空格的字段转成数。`(($2+0) != ($4+0))` 在 `a`、`b` 不同时为 1，相同时为 0，对 1 位的值来说就是异或。
4. 和第 6 段 `f` 不相等，就把计数 `n` 加一；最后打印 `n+0`，`+0` 让一行都没匹配、`n` 还是空串时也打印 0 而不是空行。

这个判据只依赖输出的文本，不依赖程序内部有没有检查。第 6.4 节会看到它的用处。

### 5.4 [判] 第 5 节

    [ ] 跑 10 次：退出码 0，打印 10 行，awk 重算不对的行数为 0
    [ ] 最后一行是 seen: 00=3 01=2 10=2 11=3
    [ ] 连续运行两次，输出逐字节相同
    [ ] 跑 1000 次：退出码 0，打印 1000 行，awk 重算不对的行数为 0，
        四种组合都出现过

    注错见红：在 tb_switch.cpp 的 int n = 10; 前面加上 srand(2);，输入序列改变，
    seen 那条精确判据变红。第 6 节注错 1 的伪终端判据也跟着变红：输入序列变了，
    第一次出错的位置跟着变，assert 前打印的行数不再是 2。对照：加的是 srand(1);
    时一条都不变红，种子 1 就是不设种子时的默认值。"两次运行逐字节相同"依赖
    rand() 的默认种子行为，属于工具链事实，实验源码上没有能只改坏它的注错，
    由第 1 节的版本判据兜底。

**这一节搭好的积木**：testbench 的骨架是一个循环，每一轮随机产生输入、写进模型、调用 `eval`、读出输出，再用一个独立算出的期望值去检查。`rand()` 不设置种子时，每次运行的输入序列相同。程序之外还可以用 awk 从输出重算一遍。接下来的问题：所有判据都是绿的，能不能说明测试有用。

---

## 6 注错见红：测试自己能不能报错

上一节全部通过。这一节的问题：一个永远不会失败的测试什么也证明不了；怎样确认这个测试在电路错了的时候真的会报错。办法是故意改坏一处，看判据是否变红。check.sh 自己构建四份改坏的副本，产物放在 `build/m1/` 到 `build/m4/`。

### 6.1 [做 L2] 注错 1：电路写错

把异或改成或，构建、运行，stdout 和 stderr 分别写进两个文件：

```bash
mkdir -p build/m1 && sed 's/a ^ b/a | b/' top.v > build/m1/top.v
verilator --cc --exe --build -j 0 -Wall --Mdir build/m1/obj tb_switch.cpp build/m1/top.v
build/m1/obj/Vtop > build/m1/out.txt 2> build/m1/err.txt; echo "exit=$?"
cat build/m1/err.txt; wc -l < build/m1/out.txt
```

```text
exit=134
Vtop: ../../../tb_switch.cpp:23: int main(int, char**): Assertion `top->f == (a ^ b)' failed.
0
```

运行这条命令时，shell 自己还会在终端上补一行提示，说进程被 abort 终止，措辞随 shell 而定，这里不列。

先读 `err.txt` 里的那一行，它由 `assert` 打印，依次是：

1. `Vtop`：程序名。
2. `../../../tb_switch.cpp:23`：源文件和行号。make 在 `build/m1/obj/` 里编译，从那里看源文件的路径是 `../../../tb_switch.cpp`；第 23 行就是 `assert` 那一行。
3. `int main(int, char**)`：所在的函数。
4. `` Assertion `top->f == (a ^ b)' failed. ``：失败的条件，原样照抄源码。

再读退出码 134。`assert` 失败时调用 `abort()`，`abort()` 给进程发 SIGABRT 信号。信号是操作系统递给进程的一条短消息，进程没有处理它时就按默认动作结束，SIGABRT 的默认动作就是终止进程。它的编号是 6（man 7 signal），在 shell 里运行 `kill -l 6` 也能查到，输出是 `ABRT`。进程被信号终止时，shell 报告的退出码是 128 加信号编号（man bash 的 EXIT STATUS 一节），128 + 6 = 134。

哪一轮失败的：5.2 节的输入序列里，第 1 行是 `a=1 b=0`，或和异或都得 1，通过；第 2 行是 `a=1 b=1`，或得 1，异或得 0，`assert` 失败。所以程序在失败前已经执行过两次 `printf`。

可是 `out.txt` 是 0 行。原因是 stdout 的缓冲方式随输出目标变化：指向终端时按行缓冲，遇到换行就写出去；指向文件时按块缓冲，攒满一块或者程序正常退出时才写出去（man 3 setbuf）。`abort()` 结束进程时不写出缓冲（glibc 2.27 起，man 3 abort），于是缓冲里的两行跟着进程一起消失了。

对照：让程序在伪终端里运行，相当于直接在终端里敲这条命令。`script` 命令可以做到：

```bash
script -qec build/m1/obj/Vtop /dev/null; echo "exit=$?"
```

`-q` 不打印 `script` 自己的提示，`-e` 让 `script` 返回被运行程序的退出码，`-c` 后面是要运行的命令，最后的 `/dev/null` 是 `script` 的记录文件，这里不需要，丢掉。输出：

```text
a = 1, b = 0, f = 1
a = 1, b = 1, f = 1
Vtop: ../../../tb_switch.cpp:23: int main(int, char**): Assertion `top->f == (a ^ b)' failed.
exit=134
```

两行打印都在，第 2 行就是出错的那一轮：`a=1 b=1`，`f` 是 1。退出码同样是 134。

testbench 的输出重定向到文件时（check.sh 和以后的 Makefile 都会这样做），程序崩溃前的打印可能全部丢失。要保住现场，把诊断信息打印到 stderr（默认不缓冲），或者在 `assert` 之前调用 `fflush(stdout)`。

### 6.2 [做 L2] 注错 2：忘了调用 eval

```bash
mkdir -p build/m2 && sed '/top->eval();/d' tb_switch.cpp > build/m2/tb_switch.cpp
verilator --cc --exe --build -j 0 -Wall --Mdir build/m2/obj build/m2/tb_switch.cpp top.v
build/m2/obj/Vtop > /dev/null 2>&1; echo "exit=$?"
```

```text
exit=134
```

`sed '/top->eval();/d'` 删掉含 `top->eval();` 的那一行。没有 `eval`，`f` 一直是构造时的初值 0（4.4 节）。第 1 轮 `a=1 b=0`，期望 1，读到 0，`assert` 当场失败。这正是 4.1 节 P1 的情形放进了循环里。

### 6.3 [做 L2] 注错 3：文件名和模块名不一致

把 `top.v` 换个名字叫 `switch.v`，内容不变：

```bash
mkdir -p build/m3 && cp top.v build/m3/switch.v
verilator --cc --exe --build -j 0 -Wall --Mdir build/m3/obj tb_switch.cpp build/m3/switch.v; echo "exit=$?"
```

构建失败，日志 `build/m3/build.log`：

```text
%Warning-DECLFILENAME: build/m3/switch.v:1:8: Filename 'switch' does not match MODULE name: 'top'
    1 | module top(
      |        ^~~
                       ... For warning description see https://verilator.org/warn/DECLFILENAME?v=5.052
                       ... Use "/* verilator lint_off DECLFILENAME */" and lint_on around source to disable this message.
%Error: Exiting due to 1 warning(s)
```

1. `%Warning-DECLFILENAME`：警告的名字叫 DECLFILENAME。位置是 `switch.v` 第 1 行第 8 列，也就是模块名 `top` 的起点；内容是文件名 `switch` 与模块名 `top` 不一致。这条规则的用意是让 Verilator 按文件名在目录里查找模块（`-y` 选项）时能找到。它属于代码风格警告，默认关闭，`-Wall` 把它打开了。
2. 中间四行：出错的源码行、指向列号的 `^~~`、说明链接、关掉这条警告的写法。
3. `%Error: Exiting due to 1 warning(s)`：只有一条警告，Verilator 也以错误退出。Verilator 的警告默认是致命的；要让它只报不停，得加 `-Wno-fatal`。

去掉 `-Wall`，DECLFILENAME 回到默认的关闭状态：

```bash
verilator --cc --exe --build -j 0 --Mdir build/m3/nowall tb_switch.cpp build/m3/switch.v; echo "exit=$?"
```

警告没了，构建仍然失败，这次是 g++ 报错（`build/m3/nowall.log`）：

```text
../../../tb_switch.cpp:4:10: fatal error: Vtop.h: No such file or directory
    4 | #include "Vtop.h"
      |          ^~~~~~~~
compilation terminated.
```

原因是 2.1 节的类名规则：类名取 `V` 加上第一个 Verilog 文件的文件名，这次是 `Vswitch`。`build/m3/nowall/` 里生成的是 `Vswitch.h`，没有 `Vtop.h`，而 `tb_switch.cpp` 第 4 行要的是 `Vtop.h`。加上 `-Wall -Wno-DECLFILENAME`（打开 `-Wall` 的那些警告，再单独关掉这一条）也是同样的结果：警告没了，类名仍是 `Vswitch`，g++ 照样找不到 `Vtop.h`。

所以文件名在这里起两次作用，一次是风格检查，一次是类名。

1. 文件名改回和模块名一致（`top.v`）。两个问题一起消失，这是正解。
2. 不加 `-Wall`，加 `--top top` 指定顶层模块。类名的规则里，`--top` 优先于文件名，类名回到 `Vtop`，构建成功。保留 `-Wall`、只加 `--top top` 不够：DECLFILENAME 照报，构建照样失败。
3. 保留 `-Wall`，同时加 `-Wno-DECLFILENAME` 和 `--top top`：前者关掉这条风格警告，后者让类名回到 `Vtop`，构建成功。

后两种都不用改 `tb_switch.cpp`，但文件名和模块名仍然不一致，以后每条构建命令都要带上这些选项。

### 6.4 [做 L2] 注错 4：电路错了，检查也删了

用注错 1 那份改成或的电路，再把 `assert` 那一行删掉：

```bash
mkdir -p build/m4 && sed '/assert(/d' tb_switch.cpp > build/m4/tb_switch.cpp
verilator --cc --exe --build -j 0 -Wall --Mdir build/m4/obj build/m4/tb_switch.cpp build/m1/top.v
build/m4/obj/Vtop > build/m4/out.txt 2>&1; echo "exit=$?"; cat build/m4/out.txt
```

```text
exit=0
a = 1, b = 0, f = 1
a = 1, b = 1, f = 1
a = 1, b = 1, f = 1
a = 0, b = 0, f = 0
a = 1, b = 1, f = 1
a = 0, b = 1, f = 1
a = 0, b = 1, f = 1
a = 1, b = 0, f = 1
a = 0, b = 0, f = 0
a = 0, b = 0, f = 0
seen: 00=3 01=2 10=2 11=3
```

电路是错的，程序却以退出码 0 正常结束。第 2、3、5 行的 `f` 都是错的，没有任何东西报警；最后一行的 `seen` 和正确电路一模一样，因为它数的是输入，不看输出。5.3 节的 awk 判据照样能抓出来：

```bash
awk -F'[=,]' '/^a = /{ if ($6+0 != (($2+0) != ($4+0))) n++ } END { print n+0 }' build/m4/out.txt
```

```text
3
```

3 行不对，正好是 11 出现的那 3 次。

四种注错合起来说明三件事：testbench 里必须有检查，否则退出码 0 什么也不说明（注错 4）；检查的期望值要独立于电路算出来，`assert` 用 C 的 `^`，awk 从文本重算（注错 1、4）；构建本身也可能因为名字出错，构建失败要先读懂报错再改（注错 3）。

### 6.5 [判] 第 6 节

    [ ] 注错 1：退出码 134；kill -l 6 输出 ABRT，即 SIGABRT 是 6 号信号
    [ ] 注错 1：stderr 里有 tb_switch.cpp 加行号、函数名和 Assertion `top->f == (a ^ b)' failed.
    [ ] 注错 1：stdout 重定向到文件时是 0 行；伪终端里有 2 行，退出码同为 134
    [ ] 注错 2：退出码 134
    [ ] 注错 3：-Wall 下构建失败，原因是 DECLFILENAME
    [ ] 注错 3：不加 -Wall 时没有 DECLFILENAME，生成的是 Vswitch.h，g++ 报找不到 Vtop.h；
        -Wall -Wno-DECLFILENAME 同样失败在 Vtop.h
    [ ] 注错 3：不加 -Wall、加 --top top 构建成功；加 -Wall 时 --top top 仍因
        DECLFILENAME 失败；-Wall -Wno-DECLFILENAME --top top 构建成功
    [ ] 注错 4：退出码 0，打印 10 行，awk 抓出 3 行

    注错见红：这一节的判据核对的是"注错真的报错"，反过来让注错什么也不改坏，
    判据就必须变红。mutate.sh 改的是 check.sh 里做注错的命令：
    把注错 1 的 sed 改成 s/a ^ b/a ^ b/，电路是对的，注错 1 的五条判据变红；
    注错 4 用的是注错 1 的电路，它的 awk 判据也一起变红，一共六条。
    把注错 3 的副本名 switch.v 换回 top.v，文件名和模块名一致，"构建失败"、
    "原因是 DECLFILENAME"、"类名是 Vswitch"、"找不到 Vtop.h"、"-Wno-DECLFILENAME
    也失败"、"-Wall 加 --top 也失败"六条变红。
    把注错 2 的 sed 换成删除一行不存在的内容，eval 还在，注错 2 那一条变红。
    把注错 4 的 sed 也这样换，assert 还在，程序在第 2 轮 abort，a/b/f 打印 0 行
    （文件里只有报错一行），注错 4 的三条全部变红。
    SIGABRT 的编号是环境判据，mutate.sh 把 check.sh 里期望的 ABRT 改成 KILL，
    那一条变红。

**这一节搭好的积木**：判断一个测试有没有用，要先把被测对象改坏，看测试会不会报错。assert 失败的退出码是 134（128 加 SIGABRT 的 6），它的报错带着文件、行号和条件；stdout 写文件时，abort 前的打印会丢。Verilator 的警告默认致命，类名跟着文件名走。接下来的问题：把循环条件补全成手册示例的 `!contextp->gotFinish()`，而双控开关没有 `$finish`，会怎样。

---

## 7 没有 `$finish` 的循环不会自己停

讲义的伪代码把循环条件留作 `???`，任务框里写明这个项目没有指示仿真结束的语句，退出要键入 Ctrl+C。沿用手册示例的 `!contextp->gotFinish()`，是最自然的填法。这一节的问题：这样填为什么停不下来，Ctrl+C 做了什么。

### 7.1 [做 L1] 讲义版本的循环

`tb_forever.cpp`：

```cpp
#include <cstdio>
#include <cstdlib>
#include "Vtop.h"
#include "verilated.h"

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    Vtop* top = new Vtop{contextp};
    while (!contextp->gotFinish()) {
        int a = rand() & 1;
        int b = rand() & 1;
        top->a = a;
        top->b = b;
        top->eval();
        printf("a = %d, b = %d, f = %d\n", a, b, top->f);
    }
    delete top;
    delete contextp;
    return 0;
}
```

和 `tb_switch.cpp` 相比，循环条件换成了 `!contextp->gotFinish()`，去掉了 `assert` 和计数。构建，在交互 shell 里运行：

```bash
verilator --cc --exe --build -j 0 -Wall --Mdir build/forever tb_forever.cpp top.v
build/forever/Vtop
```

终端里的行不停地往上滚，直到按下 Ctrl+C。

停不下来的原因：`gotFinish` 标志只有三个地方会把它置为真，`vl_finish`（`$finish`，`verilated.cpp` 第 170 行）、`vl_stop`（`$stop`，第 183 行）和 `vl_fatal`（致命错误，第 197 行）。`top.v` 里没有 `$finish` 和 `$stop`，双控开关也不会触发致命错误，于是标志永远是假，循环永远继续。

Ctrl+C 的作用是让终端给前台进程发 SIGINT 信号。程序没有处理这个信号，按默认动作被终止。SIGINT 的编号是 2（man 7 signal，`kill -l 2` 输出 `INT`），按 6.1 节的规则，shell 报告的退出码是 128 + 2 = 130。

### 7.2 [做 L1] 用 timeout 代替手按 Ctrl+C

机器没法按键盘。`timeout` 可以在指定时间后给程序发一个指定的信号，效果和手按 Ctrl+C 相同：

```bash
timeout -s INT 1 build/forever/Vtop > /dev/null; echo "exit=$?"
timeout --preserve-status -s INT 1 build/forever/Vtop > /dev/null; echo "exit=$?"
```

```text
exit=124
exit=130
```

`-s INT 1` 表示 1 秒后发 SIGINT。第一条返回 124，这是 `timeout` 自己的退出码，含义是"时间到了，程序是被我打断的"（`timeout --help`：124 if COMMAND times out, and --preserve-status is not specified）。第二条加了 `--preserve-status`，`timeout` 改为转交程序自己的退出状态，得到 130，与 7.1 节推出来的一致。

1 秒里程序转了多少圈：

```bash
timeout -s INT 1 build/forever/Vtop | wc -l
```

1 秒写出的行数每次不同，最近一次 check.sh 实得 5634457 行（本机数字）。check.sh 只判"不少于 1 万行"，并打印实得值。

不想按 Ctrl+C，办法是让循环有尽头：像 `tb_switch.cpp` 那样数次数，或者在条件里同时检查 `gotFinish` 和一个圈数上限。

### 7.3 [判] 第 7 节

    [ ] kill -l 2 输出 INT，即 SIGINT 是 2 号信号
    [ ] timeout --help 的 Exit status 一段写着
        124  if COMMAND times out, and --preserve-status is not specified
    [ ] timeout -s INT 1 打断无限循环，返回 124
    [ ] 加 --preserve-status 返回 130，即 128 加 SIGINT 的 2
    [ ] 1 秒内写出的行数不少于 1 万（最近一次实得 5634457 行，本机数字）

    注错见红：把 tb_forever.cpp 的 while (!contextp->gotFinish()) 换成
    for (int i = 0; i < 10 && !contextp->gotFinish(); i++)，循环 10 圈就结束，
    timeout 等不到 1 秒，后三条判据全部变红。前两条是环境判据，mutate.sh 改的是
    check.sh 里的期望值：INT 改成 QUIT、124 改成 125，各自那一条变红。

**这一节搭好的积木**：`gotFinish` 只由 `$finish`、`$stop` 和致命错误立起来；设计里没有 `$finish` 时，只看这个标志的循环永不结束，只能靠 SIGINT 打断，退出码 130。接下来的问题：第 4 节说 ico 区"一直重复到没有变化为止"，有没有一种电路，让这个"为止"永远等不到。

---

## 8 组合环：eval 不一定停得下来

第 4.2 节：ico 区反复调用 `eval_ico`，直到某一次没有触发；双控开关只要两次。这一节的问题：如果一个组合电路的输出永远稳定不下来，`eval` 会怎样。

### 8.1 [做 L1] 一个停不下来的电路

`loop.v`：

```verilog
module loop(
  input  en,
  output f
);
  wire x;
  assign x = en ? ~x : 1'b0;
  assign f = x;
endmodule
```

1. 第 1 至 4 行：输入 `en`，输出 `f`。
2. 第 5 行：一根内部连线 `x`。
3. 第 6 行：`en` 为 1 时 `x` 等于 `x` 取反，`en` 为 0 时 `x` 等于 0。`x` 的值依赖它自己，这就是组合环。
4. 第 7 行：把 `x` 送到输出。

`en=0` 时 `x=0`，稳定。`en=1` 时要求 `x = ~x`，0 和 1 都不满足，没有任何稳定状态。Verilator 的模型只能一轮一轮地重算。

先照常加 `-Wall` 构建：

```bash
verilator --cc --exe --build -j 0 -Wall --Mdir build/loopwall tb_loop.cpp loop.v; echo "exit=$?"
```

构建失败，退出码 1，日志 `build/loopwall.log`：

```text
%Warning-UNOPTFLAT: loop.v:3:10: Signal unoptimizable: Circular combinational logic: 'f'
    3 |   output f
      |          ^
                    ... For warning description see https://verilator.org/warn/UNOPTFLAT?v=5.052
                    ... Use "/* verilator lint_off UNOPTFLAT */" and lint_on around source to disable this message.
                    loop.v:3:10:      Example path: f
                    loop.v:6:12:      Example path: ASSIGNW
                    loop.v:5:8:      Example path: loop.x
                    loop.v:7:12:      Example path: ASSIGNW
                    loop.v:3:10:      Example path: f
%Error: Exiting due to 1 warning(s)
```

1. `%Warning-UNOPTFLAT`：信号 `f` 无法优化，原因是"环形的组合逻辑"。位置 `loop.v:3:10` 是 `output f` 里 `f` 的位置。
2. 五行 `Example path`：环上的一条路径，从 `f` 出发，经过第 6 行的连续赋值（`ASSIGNW`，第 12 列是 `=`），到第 5 行的 `x`，再经过第 7 行的连续赋值，回到 `f`。
3. `%Error: Exiting due to 1 warning(s)`：和 6.3 节一样，警告默认致命。

UNOPTFLAT 的意思要从 Verilator 怎样排组合逻辑说起。它在编译时按依赖关系给所有组合赋值排一个固定顺序，先算被依赖的，后算依赖别人的，这样每次求值每条赋值只需要执行一次。环上的赋值排不出这样的顺序，Verilator 只好放弃这个优化，改为反复执行直到稳定，并发出这条警告。它的分析按整个信号进行，不区分每一位，所以有些按位看并不成环的写法（例如 `wire [2:0] x = {x[1:0], shift_in};`）也会被报出来，那种情况只是变慢；`loop.v` 是真的环。排序与反复执行的细节见 fundamentals/01 第 5、6 节。

去掉 `-Wall` 也一样失败：UNOPTFLAT 默认就开着，构建日志 `build/loopnowall.log` 里是同样的警告。

### 8.2 [做 L1] 关掉警告，问题推迟到运行时

`tb_loop.cpp` 先让 `en=0` 求值一次，再让 `en=1` 求值一次：

```cpp
#include <cstdio>
#include "Vloop.h"
#include "verilated.h"

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    Vloop* top = new Vloop{contextp};

    top->en = 0;
    top->eval();
    printf("en=0: f=%d\n", top->f);
    fflush(stdout);
    top->en = 1;
    top->eval();
    printf("en=1: f=%d\n", top->f);

    top->final();
    delete top;
    delete contextp;
    return 0;
}
```

用 `-Wno-UNOPTFLAT` 单独关掉这条警告再构建，运行：

```bash
verilator --cc --exe --build -j 0 -Wall --Mdir build/loop -Wno-UNOPTFLAT tb_loop.cpp loop.v
build/loop/Vloop > build/loop.txt 2>&1; echo "exit=$?"; cat build/loop.txt
```

```text
exit=1
en=0: f=0
%Error-DIDNOTCONVERGE: Input combinational region did not converge after '--converge-limit' of 10000 tries
Aborting...
```

`en=0` 那次求值正常，`f=0`。`en=1` 那次 `eval` 没有返回：报 DIDNOTCONVERGE（did not converge，不收敛），`Input combinational region` 就是 ico 区，重试了 10000 次仍不稳定，`Aborting...` 后以退出码 1 结束，`en=1:` 那行 `printf` 没有机会执行。

机制在生成的 `build/loop/Vloop___024root__0.cpp` 第 18 至 67 行，结构与 4.2 节的 `eval_ico` 相同，关键的两处是触发条件（第 30 至 37 行）和函数体（第 56 至 61 行）：

```cpp
        vlSelfRef.__VicoTriggered[0U] = (QData)((IData)(
                                                        ((((IData)(vlSelfRef.en) 
                                                           != (IData)(vlSelfRef.__Vtrigprevexpr___TOP__en__0)) 
                                                          << 1U) 
                                                         | ((IData)(vlSelfRef.f) 
                                                            != (IData)(vlSelfRef.__Vtrigprevexpr___TOP__f__0)))));
        vlSelfRef.__Vtrigprevexpr___TOP__f__0 = vlSelfRef.f;
        vlSelfRef.__Vtrigprevexpr___TOP__en__0 = vlSelfRef.en;
```

```cpp
                    CData/*0:0*/ __Vinline_0__eval_body__ico___Vinline_1__ico_comb__TOP__0_loop__DOT__x;
                    __Vinline_0__eval_body__ico___Vinline_1__ico_comb__TOP__0_loop__DOT__x = 0;
                    __Vinline_0__eval_body__ico___Vinline_1__ico_comb__TOP__0_loop__DOT__x 
                        = ((~ (IData)(vlSelfRef.f)) 
                           & (IData)(vlSelfRef.en));
                    vlSelfRef.f = __Vinline_0__eval_body__ico___Vinline_1__ico_comb__TOP__0_loop__DOT__x;
```

触发条件除了输入 `en`，还多了输出 `f`：环上的 `f` 一变，ico 区就要再算一次。函数体里那个很长的名字就是 `x`（`loop__DOT__x` 是 `loop.x`），两句合起来是 `x = ~f & en; f = x;`。`en` 为 1 时 `~f & 1` 就是 `f` 取反。

推一遍 `en=1` 的那次 `eval`：

1. 第 1 次调用：`en` 从 0 变成 1，触发；`f` 从 0 变成 1，返回真。
2. 第 2 次调用：`f` 和上次记下的 0 不同，触发；`f` 变回 0，返回真。
3. 第 3 次调用：`f` 又和上次记下的 1 不同，触发；`f` 变成 1，返回真。以后每次都这样。

`evalImpl()` 每转一圈先调用 `checkConvergence`（`verilated.h` 第 408 至 411 行）：圈数超过上限 `m_convergeLimit` 就调用 `didNotConverge`（`verilated.cpp` 第 4044 至 4052 行），拼出上面那句报错，交给 `vl_fatal`，退出码 1（4.5 节）。上限在模型构造时给定，`build/loop/Vloop.cpp` 第 12 行写着 `m_evalLoop{*this, /*convergeLimit:*/ 10000}`，可以用 Verilator 的 `--converge-limit` 选项改。

`en=0` 那次只要两次调用：第 1 次是模型的第一次 ico 调用，强制触发，`x = ~f & 0 = 0`，`f` 是 0，返回真；第 2 次 `en` 和 `f` 都和上次记下的相同，不触发，返回假，收敛。

构建时的 UNOPTFLAT 和运行时的 DIDNOTCONVERGE 说的是同一个环。`-Wno-UNOPTFLAT` 只是不让构建失败，环还在，问题推迟到运行时才暴露，而且要等到输入恰好让环闭合（这里是 `en=1`）才出现。

### 8.3 [判] 第 8 节

    [ ] loop.v 在 -Wall 下构建失败；日志有
        %Warning-UNOPTFLAT: loop.v:3:10: Signal unoptimizable: Circular combinational logic
        和 %Error: Exiting due to 1 warning(s)
    [ ] 不加 -Wall 同样构建失败，日志里有 UNOPTFLAT
    [ ] 加 -Wno-UNOPTFLAT 构建后运行：en=0 打印 f=0；en=1 报 DIDNOTCONVERGE
        （Input combinational region ... 10000 tries），没有 en=1 那一行，退出码 1

    注错见红：把 loop.v 的 ~x 改成 x，x = x 在 en=1 时也稳定，构建仍报 UNOPTFLAT，
    运行时不再 DIDNOTCONVERGE，en=1 的三条判据变红；把 ~x 改成 ~en，环断开，构建
    不再失败，构建的四条判据也变红，只剩 en=0 那条通过。

**这一节搭好的积木**：ico 区反复执行到没有触发为止；组合环让触发永不停止，`eval` 在 10000 圈后报 DIDNOTCONVERGE 退出。Verilator 在构建时用 UNOPTFLAT 提前指出这种环，这条警告默认开着、默认致命。

---

## 9 速查清单

本章用到的命令与选项，各一行，括号里是小节号。依据是本章 2026-11-13 的实测与 5.052 的 man 页。

构建与运行：

    verilator --version                          查版本                         (1.1)
    verilator --cc -Wall --Mdir D x.v            只翻译成 C++，不编译           (2.1)
    verilator --cc --exe --build -j 0 -Wall --Mdir D main.cpp x.v
                                                 翻译、编译、链接一步完成       (2.2)
    --runtime-debug                              调试构建：定义 VL_DEBUG，加 sanitizer，运行时查输入宽度  (4.5)
    -Wno-<警告名>                                单独关掉一种警告               (6.3 8.2)
    -Wno-fatal                                   警告照报，但不终止             (6.3)
    --top <模块名>                               指定顶层模块，类名随之变成 V<模块名>  (6.3)
    --converge-limit <n>                         eval 每个区最多转多少圈，默认 10000  (8.2)
    +verilator+rand+reset+<0|1|2>                运行时参数：初值取全 0、全 1 或随机  (4.4)
    CCACHE_DISABLE=1 verilator ...               关掉 ccache 构建，看不靠缓存的编译耗时  (2.2)
    kill -l 6                                    查 6 号信号的名字（ABRT）       (6.1 7.1)
    timeout -s INT 1 <程序>                      1 秒后发 SIGINT；打断了就返回 124  (7.2)

testbench 骨架：

    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);         让 +verilator+ 参数生效
    Vtop* top = new Vtop{contextp};            类名 = V + 文件名（或 --top）
    循环 {
        top->a = ...;                          只写有效位（rand() & 1）
        top->eval();                           不调用就不计算
        检查 top->f 与独立算出的期望值
    }
    top->final(); delete top; delete contextp;

退出码：

    0     正常结束
    1     vl_fatal：DIDNOTCONVERGE、调试构建的超宽输入        (4.5 8.2)
    124   timeout 打断了程序（不加 --preserve-status）          (7.2)
    130   被 SIGINT 终止：128 + 2                               (7.1 7.2)
    134   assert 失败，abort：128 + 6                           (6.1)

构建失败的三种报错：

    %Warning-DECLFILENAME ... Exiting due to 1 warning(s)   文件名与模块名不一致，加了 -Wall   (6.3)
    fatal error: Vtop.h: No such file or directory          类名跟着文件名变了                (6.3)
    %Warning-UNOPTFLAT ... Circular combinational logic     组合环                            (8.1)

---

## 10 回看：整章的问题链

| 问题 | 答案 | 证据在哪 |
| --- | --- | --- |
| Verilator 是什么 | 编译器：Verilog 进，C++ 模型出 | 1.1 |
| `--cc` 产出什么 | 13 个文件：C++ 源码、Makefile 片段和 Verilator 自己的依赖记录，没有 `.o` | 2.1 |
| 可执行文件怎么来 | make 调 g++，把模型、包装文件、运行库链接成 ELF | 2.2 |
| `Hello World` 和 `$finish` 报告是谁打印的 | 第一次 `eval` 执行 `initial` 块，`VL_WRITEF_NX` 与 `vl_finish` | 2.3 |
| `$finish` 会打断后面的语句吗 | 不会，它只打印报告、立起标志 | 2.4 |
| 端口在 C++ 里是什么 | 绑定到根对象成员的 `uint8_t` 引用 | 3.1 |
| `assign` 变成了什么 | `eval_ico` 里一条带条件的赋值 | 3.2 |
| 改了输入为什么必须 `eval` | 只有 `eval` 的 ico 区会比较输入并重算 `f` | 4.1、4.2 |
| 为什么不需要时钟 | 组合电路没有状态，每次 `eval` 按当前输入算好 | 4.3 |
| 构造后的 0 从哪来 | `VL_SCOPED_RAND_RESET_I`，运行时默认全 0 | 4.4 |
| 给 1 位端口写 2 会怎样 | 普通构建照算成 2；调试构建报错退出 | 4.5 |
| testbench 的每一行在做什么 | 随机驱动、`eval`、打印、独立检查、计数 | 5.1 |
| 为什么每次结果一样 | `rand()` 没设种子，等同种子 1 | 5.2 |
| 测试真的会报错吗 | 四种注错各自变红；注错 4 只有 awk 能抓 | 6.1 至 6.4 |
| assert 失败前的打印去哪了 | 写文件时块缓冲，`abort()` 不写出 | 6.1 |
| 改个文件名为什么构建失败 | DECLFILENAME 致命；类名跟着文件名变 | 6.3 |
| 循环为什么要按 Ctrl+C 才能退出 | 没有 `$finish`，`gotFinish` 永远是假 | 7.1 |
| Ctrl+C 之后的退出码 | 130 = 128 + SIGINT 的 2 | 7.1、7.2 |
| `eval` 会不会停不下来 | 组合环让 ico 区一直触发，10000 圈后 DIDNOTCONVERGE | 8.1、8.2 |

---

## 11 自检

答不上来就回到对应小节。每题都能用命令验证，不要凭印象答。

    1. 只给 --cc 时 build/cconly 里有没有 .o？报告里哪个数说明没有编译？        (2.1)

    2. 构建日志里一共编译了几个 .o，各来自哪个源文件？Vour__ALL.a 是谁打包的，
       为什么日志里看不到那条命令？                                              (2.2)

    3. sim_main 的 while 一共调用了几次 eval？用 2.3 节的五步说明理由。         (2.3)

    4. 把 fin.v 里 $finish 和第二个 $display 的位置对调，输出会变成什么？
       先写预测，再运行验证。                                                    (2.4)

    5. top->a 的 C++ 类型是什么？写 top->a = 1 时，真正被写的是哪个变量？       (3.1)

    6. P1 为什么是 0？P2 那次 eval 里 f = a ^ b 一共执行了几次，各在哪个区？
       P3 调用了两次 eval_ico，f 为什么没有被重算？                             (4.1 4.2)

    7. 不看本章，向别人解释"这个电路为什么不需要时钟"；有寄存器的电路又为什么
       需要。                                                                     (4.3)

    8. 用 +verilator+rand+reset+1 运行 tb_switch，第 1 行的输出会变吗？为什么？
       先预测，再运行验证。                                                      (4.4 5.1)

    9. 普通构建里给 a 写 2，f 是多少？调试构建呢？退出码为什么是 1 而不是 134？  (4.5)

   10. 对着 run10.txt 数一遍 seen。把 srand(2) 加进 tb_switch.cpp，check.sh 里
       哪几条判据会变红？换成 srand(1) 呢？                                     (5.2 5.4)

   11. 注错 1 的 out.txt 为什么是 0 行？怎样改 tb_switch.cpp，让重定向到文件时
       也能留下出错的那一行？改完用注错 1 验证。                                (6.1)

   12. 把 top.v 改名成 switch.v，有哪两种办法让 tb_switch.cpp 不改一个字就能构建？
       加 -Wall 时哪一种还管用？                                                (6.3)

   13. 注错 4 里程序退出码是 0，为什么不能说明电路是对的？用哪条命令抓出错误？  (6.4)

   14. timeout 返回 124 和 130 的差别在哪里？                                    (7.2)

   15. loop.v 里 en=1 时，eval_ico 每次调用后 f 怎样变化？为什么 en=0 时两次
       就收敛？                                                                   (8.2)

---

## 12 已知的坑

    坑 1   改了输入忘记调用 eval，读到的是旧值；刚构造时是初值 0。
           写完输入就调用 eval，再读输出。                                (4.1 6.2)

    坑 2   stdout 写进文件时按块缓冲，assert 失败调用 abort()，缓冲里的
           打印全部丢失（实测 0 行；终端里能看到 2 行）。诊断信息打到
           stderr，或者在 assert 前 fflush(stdout)。                      (6.1)

    坑 3   文件名与模块名不一致：-Wall 下 DECLFILENAME 让构建失败；不加
           -Wall 时类名跟着文件名变，找不到 Vtop.h。文件名与模块名保持
           一致。                                                          (6.3)

    坑 4   Verilator 的警告默认致命，一条警告就以错误退出。DECLFILENAME
           默认关闭，-Wall 打开它；UNOPTFLAT 默认就开着。-Wno-fatal 让
           警告只报不停。                                                  (6.3 8.1)

    坑 5   给 1 位端口写 2，普通构建不报错，f 被算成 2；只有 --runtime-debug
           构建会拦下。写输入时只写有效位，例如 rand() & 1。              (4.5)

    坑 6   rand() 不设种子时每次序列相同：可以复现，但每次测的都是同一组
           输入。改成 srand(time(0)) 时，要同时改掉依赖这组序列的判据。  (5.2)

    坑 7   $finish 不打断 initial 块，它后面的语句照样执行；停不停由
           testbench 的循环决定。                                          (2.4)

    坑 8   循环条件只有 !gotFinish()，设计里又没有 $finish，程序永不结束。
           用计数循环，或在条件里加圈数上限。                              (7.1)

    坑 9   timeout 返回的是它自己的 124；要拿到程序自己的退出状态，加
           --preserve-status（得到 130）。                                 (7.2)

    坑 10  -Wno-UNOPTFLAT 只是让构建通过；真的组合环在运行时 DIDNOTCONVERGE，
           退出码 1，而且要等输入让环闭合才出现。                         (8.2)

    坑 11  在线指南（5.054）比沙箱里的 5.052 新，页面不分版本。和版本有关
           的行为以 5.052 的 man 页与实测为准。                            (1.1)

---

## 13 交出了什么

现在能独立做到：

- 照手册示例把一个 Verilog 模块构建成可执行文件，说出每一步的产物和产物来自哪个程序
- 在生成代码里找到端口和 `assign`，说出端口的 C++ 类型和存放位置
- 解释 `eval` 里 ico 区的触发与循环，用它说明"改了输入必须 `eval`"和"组合电路不需要时钟"
- 写出"随机驱动、`eval`、独立检查"的 testbench，用注错确认它真的会报错
- 看懂 134、130、124、1 这几个退出码，以及 DECLFILENAME、UNOPTFLAT、DIDNOTCONVERGE 三种报错

还做不到：

- 记录波形、用 Makefile 一键仿真：下一章，对应讲义"打印并查看波形"与"编写Makefile"
- 时序电路的 testbench（时钟、复位）：机制在 fundamentals/01 第 7 节，动手在流水灯那一章
- 把电路接到 NVBoard：接入 NVBoard 那一章

学员接下来做两件事。第一，按[生产指南](../../../生产指南.md)第 8 节做本章的三类学习检验（预测、闭卷讲解、找错），记录写进 [E4 spec](../../../../Engineering/Todo/E4-仿真与验证.md) 第九节。第二，在 ysyx-workbench 的 npc 目录里独立完成讲义任务：自己写双控开关模块和 testbench，判据是 `assert` 全部通过，并且能讲清"为什么不需要时钟"。

---

## 14 依据

| 节 | 说法 | 依据 |
| --- | --- | --- |
| 1.1 | Verilator 把 Verilog/SystemVerilog 转换成可编译执行的 C++/SystemC 模型，定位为编译器；典型用法五步，第 5 步（波形与覆盖率）要另外打开 | Verilator 指南 5.054 第 1 章 Overview（抽取文本 `E:\Workspace\Temp\ysyx-e4\src\verilator-guide.txt` 第 99 至 116 行） |
| 1.1 | 沙箱里是 5.052，路径 `/toolchains/verilator-5052/bin/verilator` | check.sh 环境段（`command -v verilator`）与第 1 节 |
| 1.1 | 在线指南是 5.054 | 指南抽取文本第 3、4 行（Release 5.054） |
| 2.1、2.2 | `--cc`、`--exe`、`--build`、`-j`、`-Wall`、`--Mdir` 的含义 | man 页 `tools/verilator-5.052/share/man/man1/verilator.1` 第 113、161、110、193、316、213 行；指南 2.2 节（抽取文本第 204 至 213 行） |
| 2.1 | 只给 `--cc` 产出 13 个文件，没有 `.o`，`bld=0.000` | check.sh 第 2 节；`build/cconly.log` |
| 2.1 | 各生成文件的用途；`___024root` 来自 `$root` | 指南 15.2 节 Files Read/Written（抽取文本第 6489 至 6535 行）；指南 6.1 节（第 971 至 973 行） |
| 2.1、2.4、6.3 | 类名默认取 `V` 加 `--top` 的模块名，否则取 `V` 加第一个 Verilog 文件名 | 指南 13.1 节 `--prefix`（第 4108 至 4110 行）、`--top`（第 4340 至 4343 行）；check.sh 第 6 节注错 3 |
| 2.2 | 构建过程：三个 `.o`、`verilator_includer` 合成 `Vour__ALL.cpp`、链接成 `Vour` | `build/our.log`；`build/our/Vour__ALL.cpp` |
| 2.2 | 打包 `.a` 的命令带 `@`，不回显 | `share/verilator/include/verilated.mk` 第 253 至 258 行 |
| 2.2 | 用 ccache 时 bld=0.807 秒，`CCACHE_DISABLE=1` 时 bld=5.115 秒；check.sh 判后者超过前者 2 倍 | check.sh 第 2 节；`build/our.log`、`build/ournc.log`（2026-11-13 实跑） |
| 2.2 | `Vour__ALL.cpp` 是 1 行注释、1 行 `#define`、5 行 `#include` | check.sh 第 2 节；`build/our/Vour__ALL.cpp` |
| 2.2 | `Vour` 是 x86-64 ELF，230880 字节 | check.sh 第 2 节；`file`、`stat` 输出 |
| 2.3 | `$display` 变成 `VL_WRITEF_NX`，`$finish` 变成 `VL_FINISH_MT` | `build/our/Vour___024root__0__Slow.cpp` 第 13 至 23 行；check.sh 第 2 节 |
| 2.3 | 第一次 `eval` 执行 static、initial 与 Settle | `share/verilator/include/verilated.cpp` 第 4066 至 4079 行 |
| 2.3 | `VL_FINISH_MT` 在单线程模型里当场执行 `vl_finish` | `verilated.cpp` 第 245 至 252 行；`verilated_imp.h` 第 158 至 163 行；`verilated.h` 第 1003 行 |
| 2.3、7.1 | `vl_finish` 打印报告并置 `gotFinish`；`vl_stop`、`vl_fatal` 也置 `gotFinish` | `verilated.cpp` 第 166 至 171 行、第 182 至 183 行、第 196 至 197 行 |
| 2.4 | `$finish` 之后的 `$display` 照样执行 | check.sh 第 2 节（fin.v） |
| 3.1 | 端口宏与类型：`VL_IN8`/`VL_OUT8` 展开成 `CData`，`CData` 是 `uint8_t`；更宽的类型 | `build/switch/Vtop.h` 第 31 至 36 行；`verilated_types.h` 第 251、261、255 行；`verilated.h` 第 119 至 123 行 |
| 3.1 | 端口是绑定到根对象成员的引用 | `build/switch/Vtop.cpp` 第 13 至 16 行 |
| 3.2 | `assign` 变成 `eval_ico` 里的赋值 | `build/switch/Vtop___024root__0.cpp` 第 18、53 至 59 行；check.sh 第 3 节 |
| 4.1 | P0 至 P5 的输出与退出码 | check.sh 第 4 节；`build/eval.txt` |
| 4.2 | `eval` 的调用链与各区循环 | `build/switch/Vtop.h` 第 61 行；`Vtop.cpp` 第 59 至 62 行；`verilated.h` 第 390 至 396 行；`verilated.cpp` 第 4055 至 4135 行 |
| 4.2 | ico 区的触发与计算；其余各区返回 0 | `build/switch/Vtop___024root__0.cpp` 第 18 至 63 行、第 65 至 103 行 |
| 4.2 | act 到 react 五个区的循环层层嵌套 | `verilated.cpp` 第 4095 至 4126 行 |
| 4.2 | 第一次 `eval`：`eval_static` 记下此刻的输入，Settle 区先算出 `f`，ico 区第一次调用强制置 1 | `build/switch/Vtop___024root__0__Slow.cpp` 第 7 至 14 行、第 27 至 56 行；`build/switch/Vtop___024root__0.cpp` 第 38 至 42 行 |
| 4.2 | 没有 ico 逻辑的设计里 `eval_ico` 直接返回假 | fundamentals/01 第 7.3 节及其依据表 |
| 4.2 | Active、Inactive、NBA、Observed、Reactive、Postponed 等调度区 | IEEE 1800-2017 第 4.4.1、4.4.2 节（抽取文本 `E:\Workspace\Temp\ysyx-e4\src\1800-clause4.txt` 第 129 至 182 行；该文本把这两节的标题误印为 3.4.1、3.4.2，见第 129、140 行） |
| 4.3 | 仿真时间由 `timeInc` 推进 | `verilated.h` 第 746 行；`build/eval.txt` 的 P4 |
| 4.4 | Verilator 基本上是二值仿真器 | 指南 10.3.8 节 Unknown States（抽取文本第 2141 至 2143 行） |
| 4.4 | 初值由 `VL_SCOPED_RAND_RESET_I` 按 `randReset` 决定，默认 0 | `build/switch/Vtop___024root__0__Slow.cpp` 第 167 至 169 行；`verilated.cpp` 第 577 至 587 行；指南 13.5 节 `+verilator+rand+reset`（第 4894 至 4896 行）；man 页第 354 行 |
| 4.4 | 加 `+verilator+rand+reset+1` 后 P0 全 1；删掉 `commandArgs` 后参数失效 | check.sh 第 4 节；mutate.sh 的"删commandArgs"一项 |
| 4.5 | 输入不得有超出宽度的位，`--runtime-debug` 检查 | 指南 6.2 节（第 980、981 行）；man 页第 265 行；`build/eval/Vtop___024root__0.cpp` 第 126 至 139 行；`build/switch/Vtop.cpp` 第 64 至 70 行 |
| 4.5 | 调试构建的编译选项 `-ggdb -fsanitize=address,undefined -D_GLIBCXX_DEBUG -DVL_DEBUG=1`，链接带 `-fsanitize=address,undefined` | check.sh 第 4 节；`build/evaldbg.log` |
| 4.5 | 报错文字、`unknown:0`、退出码 1 | `verilated.cpp` 第 3943 至 3949 行、第 194 至 214 行；check.sh 第 4 节；`build/evaldbg.txt` |
| 4.5 | `%Error` 走 stdout；`exit` 写出缓冲 | `verilated.cpp` 第 133 至 158 行；`verilated.h` 第 421、422 行；man 3 exit |
| 4.1 | `final()` 在仿真结束时调用 | 指南 6.2 节（第 982、983 行） |
| 5.2 | 10 次与 1000 次的输出、两次运行逐字节相同 | check.sh 第 5 节；`build/run10.txt`、`build/run1000.txt` |
| 5.2 | 不设种子的 `rand()` 等同种子 1 | man 3 rand；mutate.sh 的"播种1"一项（一条都不变红） |
| 6.1 | `assert` 失败调用 `abort()`，报错带文件、函数、行号和条件 | man 3 assert |
| 6.1、7.2 | 进程被信号 n 终止时，shell 报告的退出码是 128+n | man bash 的 EXIT STATUS 一节；check.sh 第 6、7 节实测 134 与 130 |
| 6.1、7.1 | SIGABRT 是 6，SIGINT 是 2；Ctrl+C 产生 SIGINT | man 7 signal（SIGINT：Interrupt from keyboard）；`kill -l 6`、`kill -l 2`（check.sh 第 6、7 节） |
| 6.1 | 终端按行缓冲，文件按块缓冲，stderr 不缓冲 | man 3 setbuf |
| 6.1 | glibc 2.27 起 `abort()` 不写出缓冲 | man 3 abort |
| 6.1 | 注错 1 的退出码、报错、文件里 0 行、伪终端里 2 行 | check.sh 第 6 节；`build/m1/err.txt`、`build/m1/pty.txt` |
| 6.1 | `script` 的 `-q`、`-e`、`-c` | `script --help`（util-linux 2.41.3） |
| 6.3 | DECLFILENAME 的含义与默认关闭 | 指南 14.3 节（第 5232 至 5237 行）；check.sh 第 6 节 |
| 6.3 | `-Wall` 打开风格警告；`-Wno-fatal` 让警告不终止 | 指南 13.1 节（第 4474 至 4476 行、第 4495 至 4498 行）；man 页第 316、319、321 行 |
| 6.3 | 不加 -Wall、加 -Wno-DECLFILENAME、加 --top，以及三者组合的各种结果 | check.sh 第 6 节；`build/m3/` 下的日志 |
| 6.4 | 注错 4 退出码 0，awk 抓出 3 行 | check.sh 第 6 节；`build/m4/out.txt` |
| 7.2 | `timeout` 的 124 与 `--preserve-status` | `timeout --help`（uutils coreutils 0.8.0，`build/timeout-help.txt`）；check.sh 第 7 节 |
| 7.2 | 1 秒内的行数 | check.sh 第 7 节，2026-11-13 多次实跑，最近一次 5634457 行 |
| 各 [判] 块 | 注错见红：每种改坏让哪几条判据变红 | mutate.sh，2026-11-13 实跑 25 OK / 0 BAD，用时 824 秒 |
| 8.1 | UNOPTFLAT 的含义，按信号而非按位分析 | 指南 14.3 节（第 6227 至 6241 行）；`build/loopwall.log`；check.sh 第 8 节 |
| 8.2 | DIDNOTCONVERGE 的含义 | 指南 14.3 节（第 5289 至 5300 行）；`build/loop.txt`；check.sh 第 8 节 |
| 8.2 | 收敛检查与上限 10000 | `verilated.h` 第 408 至 411 行；`verilated.cpp` 第 4044 至 4052 行、第 4088 至 4091 行；`build/loop/Vloop.cpp` 第 12 行；man 页第 118 行 |
| 8.2 | 组合环的生成代码 | `build/loop/Vloop___024root__0.cpp` 第 18 至 67 行 |

`build/` 下的生成代码由 check.sh 重建，行号对应 Verilator 5.052；运行库源码路径相对于 `/toolchains/verilator-5052/`（Windows 侧是 `projects/ysyx/tools/verilator-5.052/`）。

### 讲义任务对照

本章覆盖的两小节里，讲义有四个黄色任务框、两个绿色提示框和一个红色提醒框，其余是正文。

| 讲义内容 | 本章落点 | 学员在 ysyx-workbench 里做什么 |
| --- | --- | --- |
| 正文：`bash init.sh npc`，设置 NPC_HOME | 本章不覆盖，E4 环境检查已完成（[00-环境四查](../../../labs/E/04-仿真与验证/00-环境四查.md)） | 无 |
| 提醒框"竟然连仿真框架都没有"：解释为什么环境要自己搭 | 背景说明，无任务 | 无 |
| 提示框"如果你想使用Chisel"：建议先搭好 Verilog 工作流，再考虑切换 | 本章用 Verilog，不覆盖 Chisel | 无 |
| 任务框"认识Verilator"：STFW 找到官网，阅读介绍 | 1.1 | 自己打开官网读概述 |
| 任务框"安装Verilator"：从 git 安装 stable 版，`verilator --version` | 1.1（沙箱已装 5.052，不重装） | 运行 `verilator --version` |
| 任务框"运行示例"：在手册里找到 C++ 示例并照做 | 2.1 至 2.3 | 在 npc 外的临时目录照手册做一遍 |
| 正文：双控开关模块与 while 循环的伪代码（随机驱动、`eval`、打印、`assert`） | 3.1、4、5.1 | 在 `npc/vsrc/` 和 `npc/csrc/` 里自己写模块和 testbench |
| 任务框"对双控开关模块进行仿真"：顶层模块名不同，C++ 文件要相应修改 | 2.1、5.1、6.3 | 让类名、头文件名与自己的文件名一致 |
| 同一任务框：没有结束语句，键入 Ctrl+C 退出 | 7.1、7.2 | 亲手按一次 Ctrl+C，`echo $?` 看到 130 |
| 提示框"上述代码是什么意思?"：不知道怎样修改就回去复习 C | 5.1 的逐行讲解 | 合上本章，自己讲一遍 |
| E4 spec 判据：能解释为什么不需要时钟 | 4.3 | 闭卷讲解时讲清 |

### 勘误

本章覆盖的两小节没有发现事实错误。一处表述需要补充：讲义写"Verilator会编译出C++文件, 然后将C++文件编译成可执行文件"，实测第二步由 make 调用 g++ 完成，Verilator 在 `--build` 下负责调用 make（2.2 节，Verilator 5.052）。
