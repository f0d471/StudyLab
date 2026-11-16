# 01 Verilator 模型与 eval

    实验    labs/fundamentals/01-Verilator模型与eval/
    环境    WSL2 沙箱：Ubuntu 26.04 LTS，内核 6.6.114.1-microsoft-standard-WSL2
            Verilator 5.052 2026-09-05 rev 5.052-983a06a，g++ 15.2.0，GNU Make 4.4.1
            本篇的输出与生成代码均为 2026-11-13 在沙箱里实跑
    被引用  tutorials/E/04-仿真与验证/01 第 3、4、8 节

---

**读前须知**：先读完 [tutorials/E/04-仿真与验证/01](../tutorials/E/04-仿真与验证/01-Verilator把电路变成程序.md) 的第 1 至 4 节。本篇默认读者已经知道这几件事：`verilator --cc --exe --build` 做了哪四步；端口是模型类里的引用，绑定在根对象 `TOP` 的同名成员上；`eval` 在运行库里按区循环；ico 区靠"和上次记下的值比较"决定要不要重算。本篇从这些结论往下挖一层，回答下面八个问题。

1. testbench 写 `new Vtop{contextp}` 时，构造出来的是哪几个对象，它们怎样连在一起（第 1 节）
2. 端口的 C++ 类型怎样随位宽变化，超过 64 位怎么存（第 2 节）
3. 子模块里的信号在 C++ 里叫什么名字（第 3 节）
4. 一次 `eval` 里各区按什么顺序执行、各执行几次（第 4 节）
5. 源码里 `assign` 写的先后顺序为什么不影响结果（第 5 节）
6. 不收敛的上限在哪里设，报错里的区名从哪里来（第 6 节）
7. 输入和时钟在同一次 `eval` 里变化，寄存器取到的是哪个值（第 7 节）
8. `#10` 这样的延迟能不能用（第 8 节）

**怎么跟着做**：在沙箱里进入实验目录，先跑 check.sh：

```bash
cd /workspace/docs/topics/Knowledge/labs/fundamentals/01-Verilator模型与eval
bash check.sh
```

本篇引用的生成代码和行号都来自 Verilator 5.052；版本不同时，后面的行号可能对不上。


---

## 1 模型的三层对象

教程第 2.1 节列过 `--cc` 产出的 13 个文件。这一节的问题：testbench 写 `new Vtop{contextp}` 时，这些文件里的哪些类被构造出来，它们之间怎样连接。

### 1.1 [做 L1] 产物清单

```bash
verilator --cc -Wall --Mdir build/cc top.v
ls -1 build/cc
```

`top.v` 就是教程里的双控开关。输出：

```text
Vtop.cpp
Vtop.h
Vtop.mk
Vtop__Syms.h
Vtop__Syms__Slow.cpp
Vtop___024root.h
Vtop___024root__0.cpp
Vtop___024root__0__Slow.cpp
Vtop___024root__Slow.cpp
Vtop__pch.h
Vtop__ver.d
Vtop__verFiles.dat
Vtop_classes.mk
```

本篇的其他实验还会多出几类文件，实测见过的全部在下表。

| 文件 | 内容 | 什么时候出现 |
| --- | --- | --- |
| `Vtop.h`、`Vtop.cpp` | 模型类 `Vtop`。testbench 只需要包含 `Vtop.h` | 总有 |
| `Vtop___024root.h` | 根类 `Vtop___024root` 的声明：设计的全部状态，包括端口、寄存器和触发记录 | 总有 |
| `Vtop___024root__0.cpp` | 每次 `eval` 都可能执行的函数：`eval_sample`、`eval_ico`、`eval_act` 到 `eval_postponed`，以及调试构建的宽度检查 | 总有 |
| `Vtop___024root__Slow.cpp`、`Vtop___024root__0__Slow.cpp` | 很少执行的函数：赋初值、`eval_static`、`eval_initial`、Settle 区、`eval_final`、调试打印 | 总有 |
| `Vtop__Syms.h`、`Vtop__Syms__Slow.cpp` | 符号表类 `Vtop__Syms`，根对象 `TOP` 是它的成员 | 总有 |
| `Vtop__pch.h` | 生成的每个 `.cpp` 开头都先包含它 | 总有 |
| `Vtop.mk`、`Vtop_classes.mk` | 编译这些文件用的 Makefile 片段 | 总有 |
| `Vtop__ver.d`、`Vtop__verFiles.dat` | Verilator 自己的依赖与时间戳记录 | 总有 |
| `V..._chain_pub.h` 与三个 `V..._chain_pub*.cpp` | 没有被并进根类的模块，单独成一个类 | 信号上有 `/*verilator public*/` 时（第 5 节） |
| `V...__Dpi.h`、`V...__Dpi.cpp` | DPI 的声明与包装 | 信号上有 `public` 或 `public_flat` 标记时（第 5 节） |
| `V...__main.cpp` | 生成的 `main()` | 加 `--main` 或 `--binary` 时（第 8 节） |
| `V...__ALL.cpp`、`.o`、`.a`、`.d` 和可执行文件 | 编译产物 | 加 `--build` 以后（教程 2.2 节） |

### 1.2 三个类

testbench 构造的是 `Vtop`。它的构造函数在 `build/cc/Vtop.cpp` 第 9 至 20 行：

```cpp
Vtop::Vtop(VerilatedContext* _vcontextp__, const char* _vcname__)
    : VerilatedModel{*_vcontextp__}
    , vlSymsp{new Vtop__Syms(contextp(), _vcname__, this)}
    , m_evalLoop{*this, /*convergeLimit:*/ 10000}
    , a{vlSymsp->TOP.a}
    , b{vlSymsp->TOP.b}
    , f{vlSymsp->TOP.f}
    , rootp{&(vlSymsp->TOP)}
{
    // Register model with the context
    contextp()->addModel(this);
}
```

冒号后面那一串是成员初始化列表：构造函数体执行之前，按这里写的值初始化各个成员。

1. `vlSymsp{new Vtop__Syms(...)}`：再 `new` 一个符号表对象 `Vtop__Syms`，把指针存进 `vlSymsp`。
2. `m_evalLoop{*this, 10000}`：构造求值循环对象，告诉它属于哪个模型、收敛上限是 10000（第 6 节）。
3. `a{vlSymsp->TOP.a}` 三行：把端口引用 `a`、`b`、`f` 绑定到符号表里 `TOP` 的同名成员（教程 3.1 节）。
4. `rootp{&(vlSymsp->TOP)}`：`rootp` 存的是 `TOP` 的地址。

`TOP` 是什么，看 `build/cc/Vtop__Syms.h` 第 20 至 28 行：

```cpp
class alignas(VL_CACHE_LINE_BYTES) Vtop__Syms final : public VerilatedSyms {
  public:
    // INTERNAL STATE
    Vtop* const __Vm_modelp;
    VlDeleter __Vm_deleter;
    bool& __Vm_didInit;

    // MODULE INSTANCE STATE
    Vtop___024root                 TOP;
```

`TOP` 是 `Vtop__Syms` 里的一个成员对象，类型是 `Vtop___024root`，直接嵌在符号表对象里，不是指针。`__Vm_modelp` 反过来指回模型。

根类在 `build/cc/Vtop___024root.h` 第 16 至 24 行：

```cpp
    // DESIGN SPECIFIC STATE
    VL_IN8(a,0,0);
    VL_IN8(b,0,0);
    VL_OUT8(f,0,0);
    CData/*0:0*/ __Vtrigprevexpr___TOP__a__0;
    CData/*0:0*/ __Vtrigprevexpr___TOP__b__0;
    CData/*0:0*/ __VicoDidInit;
    VlUnpacked<QData/*63:0*/, 1> __VstlTriggered;
    VlUnpacked<QData/*63:0*/, 2> __VicoTriggered;
```

这里的 `VL_IN8(a,0,0)` 没有 `&`，展开成 `CData a;`，是真正存放端口值的字节。`Vtop.h` 第 34 行的 `VL_IN8(&a,0,0)` 带 `&`，是引用。后五个成员是教程 4.2 节见过的触发记录：上次记下的 `a`、`b`，"ico 区是否第一次调用"的标志，以及 Settle 区和 ico 区的触发位。`VlUnpacked<QData/*63:0*/, 2>` 是运行库的数组类型，读作"2 个 64 位无符号数"：触发位最多 128 个，第 0 至 63 位在第一个字里，第 64 位是第二个字的最低位。

三者的关系：

```text
Vtop (new Vtop{contextp})          Vtop__Syms (new in Vtop ctor)
+--------------------------+       +-------------------------------+
| vlSymsp  ----------------+------>| __Vm_modelp                   |
| m_evalLoop (limit 10000) |       | TOP : Vtop___024root          |
| a, b, f  (references) ---+------>|   a, b, f       (CData)       |
| rootp  ------------------+------>|   __Vtrigprevexpr___TOP__a__0 |
+--------------------------+       |   __VicoTriggered[2] ...      |
                                   +-------------------------------+
```

从左边看起：testbench 手里只有 `Vtop*`。`top->a` 读写的是右边 `TOP.a` 那个字节。`rootp` 也指向同一个 `TOP`，通过它能看到端口以外的状态，例如第 3 节子模块里的寄存器。

### 1.3 eval 怎样从运行库回到生成代码

`Vtop` 的声明以 `class ... Vtop VL_NOT_FINAL : public VerilatedModel` 开头（`Vtop.h` 第 17 行），意思是 `Vtop` 继承自运行库的通用类 `VerilatedModel`。运行库的求值循环 `VerilatedEvalLoop` 只认识 `VerilatedModel` 这个通用接口，接口里声明了 `evalIco`、`evalAct` 等函数；`Vtop` 为本设计填上它们的实现（`Vtop.h` 第 91 至 110 行带 `override` 的那一组）。这里的机制是 C++ 的虚函数：基类 `VerilatedModel` 把 `evalIco`、`evalAct` 这些函数声明成虚函数，`Vtop` 用 `override` 提供自己的实现；`VerilatedEvalLoop` 手里的 `m_model` 是基类引用 `VerilatedModel&`，通过基类引用调用虚函数时，执行的是实际对象（`Vtop`）的那一份实现。教程 4.2 节的调用链因此是一个来回：

```text
top->eval()                         Vtop.h:61          generated
  Vtop::eval_step()                 Vtop.cpp:59-62     generated
    m_evalLoop.eval()               verilated.h:390    runtime
      evalImpl()                    verilated.cpp:4055 runtime
        m_model.evalIco(first)      verilated.cpp:4091 runtime
          Vtop::evalIco(first)      Vtop.cpp:93-95     generated
            Vtop___024root___eval_ico(&TOP, first)     generated
```

前两层和最后两层是生成代码，中间是运行库。运行库决定区的顺序和循环次数，生成代码决定每个区里算什么。所有设计共用同一个 `evalImpl()`，不同设计的区别全在 `Vtop___024root___eval_*` 这些函数里。

`Vtop.h` 里还有三个和本篇后面有关的成员：

1. 第 66 行 `void eval_end_step() {}`：没有打开波形时是空函数。
2. 第 70 行 `eventsPending()`，`Vtop.cpp` 第 151 行的实现是 `return false;`：设计里没有延迟，就永远没有待处理的定时事件。
3. 第 72 行 `nextTimeSlot()`，`Vtop.cpp` 第 153 至 156 行的实现直接报致命错误 `No delays in the design`。

后两个在第 8 节有延迟的设计里会变样。

最后一个名字：`___024root` 里的 `024` 是十六进制数，`$` 的 ASCII 码是 0x24，`___024root` 就是 `$root`（教程 2.1 节）。

**这一节搭好的积木**：`new Vtop` 构造出三层对象。`Vtop` 是对外的接口，`Vtop__Syms` 持有根对象 `TOP`，`TOP` 里存着设计的全部状态；端口引用和 `rootp` 都指向 `TOP`。运行库的 `evalImpl()` 通过 `VerilatedModel` 接口回调生成代码里的各区函数。接下来的问题：`TOP` 里的成员用什么 C++ 类型存放。

---

## 2 端口宽度决定 C++ 类型

上一节：端口 `a` 在 `TOP` 里是一个 `CData`。这一节的问题：位宽变化时类型怎样变，超过 64 位的信号怎样存。

### 2.1 [做 L1] 九种宽度

`widths.v` 声明了九个宽度各不相同的输入和一个 65 位的输出：

```verilog
module widths(
  input  [0:0]  w1,
  input  [7:0]  w8,
  input  [8:0]  w9,
  input  [15:0] w16,
  input  [16:0] w17,
  input  [31:0] w32,
  input  [32:0] w33,
  input  [63:0] w64,
  input  [64:0] w65,
  output [64:0] o
);
  assign o = {64'b0, w1} ^ {57'b0, w8} ^ {56'b0, w9} ^ {49'b0, w16} ^ {48'b0, w17}
           ^ {33'b0, w32} ^ {32'b0, w33} ^ {1'b0, w64} ^ w65;
endmodule
```

输出 `o` 把所有输入补零到 65 位后异或起来。这样写是为了让每个输入都被用到，否则 `-Wall` 会报"信号没有使用"的警告，构建失败。

```bash
verilator --cc -Wall --Mdir build/w widths.v
```

`build/w/Vwidths.h` 第 34 至 43 行：

```cpp
    VL_IN8(&w1,0,0);
    VL_IN8(&w8,7,0);
    VL_IN16(&w9,8,0);
    VL_IN16(&w16,15,0);
    VL_IN(&w17,16,0);
    VL_IN(&w32,31,0);
    VL_INW(&w65,64,0,3);
    VL_OUTW(&o,64,0,3);
    VL_IN64(&w33,32,0);
    VL_IN64(&w64,63,0);
```

声明的顺序和源码不同，找端口要按名字找。后两个参数是 Verilog 的 `[msb:lsb]`，`VL_INW` 多出的第四个参数是字数。

### 2.2 宏、类型与底层整数

这些宏定义在运行库的 `verilated_types.h` 第 251 至 255 行（输入）与第 261 至 265 行（输出）：

```cpp
#define VL_IN8(name, msb, lsb) CData name  ///< Declare input signal, 1-8 bits
#define VL_IN16(name, msb, lsb) SData name  ///< Declare input signal, 9-16 bits
#define VL_IN64(name, msb, lsb) QData name  ///< Declare input signal, 33-64 bits
#define VL_IN(name, msb, lsb) IData name  ///< Declare input signal, 17-32 bits
#define VL_INW(name, msb, lsb, words) VlWide<words> name  ///< Declare input signal, 65+ bits
```

类型名定义在 `verilated.h` 第 119 至 123 行：

```cpp
using CData = uint8_t;    ///< Data representing 'bit' of 1-8 packed bits
using SData = uint16_t;   ///< Data representing 'bit' of 9-16 packed bits
using IData = uint32_t;   ///< Data representing 'bit' of 17-32 packed bits
using QData = uint64_t;   ///< Data representing 'bit' of 33-64 packed bits
using EData = uint32_t;   ///< Data representing one element of VlWide
```

把端口宏、类型与底层整数合成一张表。

| Verilog 位宽 | 输入宏 | 输出宏 | C++ 类型 | 底层整数 |
| --- | --- | --- | --- | --- |
| 1 至 8 | `VL_IN8` | `VL_OUT8` | `CData` | `uint8_t` |
| 9 至 16 | `VL_IN16` | `VL_OUT16` | `SData` | `uint16_t` |
| 17 至 32 | `VL_IN` | `VL_OUT` | `IData` | `uint32_t` |
| 33 至 64 | `VL_IN64` | `VL_OUT64` | `QData` | `uint64_t` |
| 65 及以上 | `VL_INW` | `VL_OUTW` | `VlWide<字数>` | 字数个 `EData`（`uint32_t`） |

规律：取能装下这个位宽的最小无符号整数。注意 32 位一档的宏名不带数字，是 `VL_IN`。

### 2.3 超过 64 位：VlWide

`VlWide` 在 `verilated_types.h` 第 80 至 86 行：

```cpp
template <std::size_t N_Words>
struct VlWide final {
    static constexpr size_t Words = N_Words;

    // MEMBERS
    // This should be the only data member, otherwise generated static initializers need updating
    EData m_storage[N_Words];  // Contents of the packed array
```

`template <std::size_t N_Words>` 是 C++ 的模板：`VlWide<3>` 就是把 `N_Words` 换成 3 得到的结构体，里面只有一个成员 `EData m_storage[3]`，即三个 32 位无符号整数的数组。

字数怎么算：`verilatedos.h` 第 488 行 `#define VL_WORDS_I(nbits) (((nbits) + (VL_EDATASIZE - 1)) >> VL_EDATASIZE_LOG2)`，其中 `VL_EDATASIZE` 是 32、`VL_EDATASIZE_LOG2` 是 5（第 477、478 行）。右移 5 位就是除以 32，加 31 是为了向上取整。65 位：(65 + 31) / 32 = 96 / 32 = 3 个字。

三个字里哪一个装最高位，看调试构建的宽度检查（教程 4.5 节）。`build/w/Vwidths___024root__0.cpp` 第 215 至 217 行：

```cpp
    if (VL_UNLIKELY(((vlSelfRef.w65[2U] & 0xfffffffeU)))) {
        Verilated::overWidthError("w65");
    }
```

第 2 个字（下标从 0 数）只允许最低位为 1：65 位里前 64 位占满下标 0 和 1 两个字，第 64 位落在下标 2 的最低位。所以低位在前，`w65[0]` 是第 31 至 0 位。

同一个函数里，不满宽的端口各有一条检查，掩码是"超出宽度的那些位"，例如第 203 至 211 行：

```cpp
    if (VL_UNLIKELY(((vlSelfRef.w1 & 0xfeU)))) {
        Verilated::overWidthError("w1");
    }
    if (VL_UNLIKELY(((vlSelfRef.w9 & 0xfe00U)))) {
        Verilated::overWidthError("w9");
    }
    if (VL_UNLIKELY(((vlSelfRef.w17 & 0xfffe0000U)))) {
        Verilated::overWidthError("w17");
    }
```

`w9` 用 16 位的 `SData` 存，有效的是低 9 位，掩码 `0xfe00` 正好是第 15 至 9 位。`w8`、`w16`、`w32`、`w64` 正好占满整数，没有多余的位，也就没有检查。第 212 行 `w33` 那一条的掩码是 `0ULL`，与 0 相与恒为 0，这条 `if` 永远不成立；按上面的规律，33 位应当用 `0xfffffffe00000000ULL`。这是本版本生成代码的样子：至少本例这个 33 位的输入越界时，调试构建的这条检查也拦不下来。

**这一节搭好的积木**：端口和内部信号按位宽存进能装下它的最小无符号整数，超过 64 位存成 32 位字的数组，低位在前；多出来的高位按约定必须是 0。接下来的问题：设计有层次时，子模块里的信号存在哪里、叫什么。

---

## 3 子模块里的信号叫什么

上一节：`TOP` 的成员按位宽取类型。这一节的问题：顶层例化了一个子模块，子模块里的寄存器在 C++ 里叫什么，从哪里读。

### 3.1 [做 L1] 两层设计

`sub.v` 是一个 8 位寄存器：

```verilog
module sub(
  input        clk,
  input  [7:0] d,
  output [7:0] q
);
  reg [7:0] r;
  always @(posedge clk) r <= d;
  assign q = r;
endmodule
```

`hier.v` 例化它，实例名 `u_sub`：

```verilog
module hier(
  input        clk,
  input  [7:0] d,
  output [7:0] q
);
  sub u_sub (.clk(clk), .d(d), .q(q));
endmodule
```

```bash
verilator --cc -Wall --Mdir build/h hier.v sub.v
```

`build/h` 里同样是 13 个文件，没有任何以 `Vhier_sub` 开头的文件：子模块 `sub` 没有自己的类，被整个并进了根类。`build/h/Vhier___024root.h` 第 16 至 28 行：

```cpp
    // DESIGN SPECIFIC STATE
    VL_IN8(clk,0,0);
    VL_IN8(d,7,0);
    VL_OUT8(q,7,0);
    CData/*7:0*/ hier__DOT__u_sub__DOT__r;
    CData/*0:0*/ __Vtrigprevexpr___TOP__clk__0;
    CData/*7:0*/ __Vtrigprevexpr___TOP__d__0;
    CData/*0:0*/ __VicoDidInit;
    CData/*0:0*/ __Vtrigprevexpr___TOP__clk__1;
    VlUnpacked<QData/*63:0*/, 1> __VstlTriggered;
    VlUnpacked<QData/*63:0*/, 2> __VicoTriggered;
    VlUnpacked<QData/*63:0*/, 1> __VactTriggered;
    VlUnpacked<QData/*63:0*/, 1> __VnbaTriggered;
```

### 3.2 命名规则

寄存器 `r` 在 Verilog 里的层次路径是 `hier.u_sub.r`。C++ 的名字里不能有 `.`，Verilator 把每个 `.` 换成 `__DOT__`，于是成员名是 `hier__DOT__u_sub__DOT__r`。类型 `CData` 对应 8 位（第 2 节），后面的注释 `/*7:0*/` 记下了 Verilog 里的位范围。

### 3.3 [做 L1] 从 C++ 读 r

从 C++ 读它，要经过第 1 节的 `rootp`。`tb_hier.cpp` 给 `d` 写 0x5a，给一个上升沿，然后读 `r`：

```cpp
#include <cstdio>
#include "Vhier.h"
#include "Vhier___024root.h"
#include "verilated.h"

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    Vhier* top = new Vhier{contextp};
    top->clk = 0; top->d = 0x5a; top->eval();
    top->clk = 1; top->eval();
    printf("r=%02x\n", top->rootp->hier__DOT__u_sub__DOT__r);
    top->final();
    delete top;
    delete contextp;
    return 0;
}
```

```bash
verilator --cc --exe --build -j 0 -Wall --Mdir build/hr tb_hier.cpp hier.v sub.v
build/hr/Vhier
```

```text
r=5a
```

`%02x` 按两位十六进制打印。第三行 `#include "Vhier___024root.h"` 不能省。`rootp` 的类型是 `Vhier___024root*`，`Vhier.h` 第 14 行只写了 `class Vhier___024root;`，这叫提前声明：编译器只知道有这么一个类，不知道它有哪些成员。成员定义在 `Vhier___024root.h` 里。删掉这一行再构建，g++ 报错（删掉一行后 `printf` 那行成了第 11 行）：

```text
../../tb_hier.cpp:11:34: error: invalid use of incomplete type ‘class Vhier___024root’
```

incomplete type 指的就是只有提前声明、看不到成员的类型。

这种读法只适合调试时临时看一眼。`Vtop.h` 第 38 至 44 行的注释把 `rootp` 能访问到的东西称为模型内部（model internals），对外公开的只有用 `public` 一类标记标过的内容。内部成员的名字会随优化变化，第 5 节会看到没有标记的中间信号整个消失。

3.1 节根类里剩下几个成员：`__Vtrigprevexpr___TOP__clk__1` 记录上一次的 `clk`，用来在 act 区判断上升沿（第 7 节）；`__VactTriggered`、`__VnbaTriggered` 是 act 区和 NBA（nonblocking assignment update，非阻塞赋值更新）区的触发位。双控开关是组合电路，根类里没有这两个。

**这一节搭好的积木**：子模块默认被并进根类，里面的信号以层次路径命名，`.` 换成 `__DOT__`，经 `rootp` 可以读到。这些名字是内部实现。接下来的问题：这些成员在一次 `eval` 里按什么顺序被计算。

---

## 4 一次 eval 的逐行轨迹

教程 4.2 节从源码推出了 ico 区的循环。这一节换一种办法：让运行库把一次 `eval` 里调用的每个函数都打印出来，逐行对照。

### 4.1 调试打印的两个开关

生成代码里每个函数的第一行都是这样一句，例如 `eval_ico`：

```cpp
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___024root___eval_ico\n"); );
```

`VL_DEBUG_IF` 定义在 `verilated_types.h` 第 48 至 65 行，分两种情况：

```cpp
#ifdef VL_DEBUG
...
#define VL_DEBUG_IF(stmt) \
    do { \
        if (VL_UNLIKELY(Verilated::debug())) { stmt } \
    } while (false)
#else
...
#define VL_DEBUG_IF(stmt) \
    do { \
    } while (false)
#endif
```

1. 编译时定义了 `VL_DEBUG`：展开成"调试级别非 0 时执行这句打印"。
2. 没有定义：展开成空循环，打印语句根本不进程序。

所以要两个开关同时打开。编译时加 Verilator 的 `--runtime-debug`，它让 g++ 带上 `-DVL_DEBUG`（教程 4.5 节）；运行时加参数 `+verilator+debug`，由 `contextp->commandArgs` 交给运行库，把调试级别设成非 0（man 页第 343 行）。只开第二个时，运行库会提示 `Verilated::debug attempted, but compiled without VL_DEBUG, so messages suppressed.`（`verilated.cpp` 第 3836 至 3839 行）。

`VL_DBG_MSGF` 在 `verilated.cpp` 第 365 至 379 行，最后一句是：

```cpp
    VL_PRINTF("-V{t%u,%" PRIu64 "}%s", VL_THREAD_ID(), _vl_dbg_sequence_number(), result.c_str());
```

每条消息前面加上 `-V{t线程号,序号}`，再用 `VL_PRINTF` 打印，`VL_PRINTF` 就是 `printf`（`verilated.h` 第 422 行）。它和 testbench 的 `printf` 写进同一个 stdout，出现的先后就是执行的先后。

### 4.2 [做 L1] 插上标记再跑

`tb_trace.cpp` 在每次 `eval` 之前打印一行以 `==` 开头的标记：

```cpp
#include <cstdio>
#include "Vtop.h"
#include "verilated.h"

static void mark(const char* s) { printf("== %s\n", s); fflush(stdout); }

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    Vtop* top = new Vtop{contextp};

    mark("E1 first eval, a=1 b=0");
    top->a = 1; top->b = 0; top->eval();
    printf("after E1: f=%d\n", top->f);
    mark("E2 change b only, b=1");
    top->b = 1; top->eval();
    printf("after E2: f=%d\n", top->f);
    mark("E3 nothing changed");
    top->eval();
    printf("after E3: f=%d\n", top->f);
    mark("E4 overwrite output f=7, nothing changed");
    top->f = 7; top->eval();
    printf("after E4: f=%d\n", top->f);
    mark("E5 change a, a=0");
    top->a = 0; top->eval();
    printf("after E5: f=%d\n", top->f);
    mark("END");

    top->final();
    delete top;
    delete contextp;
    return 0;
}
```

1. `static void mark(...)`：一个只在本文件里用的小函数，打印标记后立刻 `fflush`，让标记不会滞留在缓冲里。
2. E1 至 E5 是五次 `eval`，每次之前改的东西不同：E1 是模型的第一次 `eval`；E2 只改 `b`；E3 什么都不改；E4 直接往输出 `f` 里写 7；E5 只改 `a`。
3. 每次 `eval` 之后打印一次 `f`，以 `after` 开头。

```bash
verilator --cc --exe --build -j 0 -Wall --runtime-debug --Mdir build/tr tb_trace.cpp top.v
build/tr/Vtop +verilator+debug > build/trace.txt 2>&1; echo "exit=$?"
```

退出码 0，`build/trace.txt` 一共 136 行。前 40 行是构造和 E1：

```text
-V{t1,1}- Verilated::debug is on. Message prefix indicates {<thread>,<sequence_number>}.
-V{t1,2}+    Vtop___024root___ctor_var_reset
== E1 first eval, a=1 b=0
-V{t1,3}+++++TOP Evaluate Vtop::eval_step
-V{t1,4}+ Eval
-V{t1,5}+    Vtop___024root___eval_debug_assertions
-V{t1,6}+ Initial
-V{t1,7}+    Vtop___024root___eval_static
-V{t1,8}+    Vtop___024root___eval_initial
-V{t1,9}+    Vtop___024root___eval_stl
-V{t1,10}+    Vtop___024root___dump_triggers__stl
-V{t1,11}+    Vtop___024root___trigger_anySet__stl
-V{t1,12}         'stl' region trigger index 0 is active: Internal 'stl' trigger - first iteration
-V{t1,13}+    Vtop___024root___trigger_anySet__stl
-V{t1,14}+    Vtop___024root___eval_stl
-V{t1,15}+    Vtop___024root___dump_triggers__stl
-V{t1,16}+    Vtop___024root___trigger_anySet__stl
-V{t1,17}         No 'stl' region triggers active
-V{t1,18}+    Vtop___024root___trigger_anySet__stl
-V{t1,19}+    Vtop___024root___eval_sample
-V{t1,20}+    Vtop___024root___eval_ico
-V{t1,21}+    Vtop___024root___dump_triggers__ico
-V{t1,22}+    Vtop___024root___trigger_anySet__ico
-V{t1,23}         'ico' region trigger index 0 is active: @( a)
-V{t1,24}         'ico' region trigger index 1 is active: @( b)
-V{t1,25}         'ico' region trigger index 64 is active: Internal 'ico' trigger - first iteration
-V{t1,26}+    Vtop___024root___trigger_anySet__ico
-V{t1,27}+    Vtop___024root___eval_ico
-V{t1,28}+    Vtop___024root___dump_triggers__ico
-V{t1,29}+    Vtop___024root___trigger_anySet__ico
-V{t1,30}         No 'ico' region triggers active
-V{t1,31}+    Vtop___024root___trigger_anySet__ico
-V{t1,32}+    Vtop___024root___eval_act
-V{t1,33}+    Vtop___024root___eval_inact
-V{t1,34}+    Vtop___024root___eval_nba
-V{t1,35}+    Vtop___024root___eval_obs
-V{t1,36}+    Vtop___024root___eval_react
-V{t1,37}+    Vtop___024root___eval_postponed
-V{t1,38}End-of-eval cleanup
after E1: f=1
```

### 4.3 逐段读 E1

1. 第 1 行：`commandArgs` 读到 `+verilator+debug`，运行库宣布调试打开（`verilated.cpp` 第 3834、3835 行）。
2. 第 2 行 `ctor_var_reset`：`new Vtop` 时给所有变量赋初值（教程 4.4 节），在 E1 的标记之前。
3. `+++++TOP Evaluate Vtop::eval_step` 与 `+ Eval`：分别来自 `Vtop.cpp` 第 60 行和 `verilated.cpp` 第 4056 行，一次 `eval` 开始。
4. `eval_debug_assertions`：`evalBegin()`（`Vtop.cpp` 第 64 至 70 行）在调试构建里调用它，检查输入有没有超出宽度的位（第 2.3 节）。
5. `+ Initial`、`eval_static`、`eval_initial`：只在第一次 `eval` 出现的初始化（`verilated.cpp` 第 4067 至 4079 行）。`eval_static` 的函数体只有两句（`build/tr/Vtop___024root__0__Slow.cpp` 第 12、13 行），把此刻的 `a`、`b` 记成"上次的值"。testbench 在 E1 之前已经写了 `a=1`、`b=0`，所以记下的就是 1 和 0。
6. 两次 `eval_stl`：Settle 区。它在初始化之后用初值把组合逻辑算一遍。本设计的 Settle 区只有一个触发位，就是"本轮第一次调用"的内部位，编号 0（`build/tr/Vtop___024root__0__Slow.cpp` 第 34 至 36 行），函数体是 `f = a ^ b`（第 46 至 51 行）。第一次调用内部位为 1，执行并返回真；第二次没有任何触发，返回假，Settle 结束。
7. `eval_sample`：每次 `eval` 一次。
8. 两次 `eval_ico`：第一次调用时三个触发位为 1。按比较算，第 0、1 位本该是 0：`eval_static` 刚把 `a=1`、`b=0` 记成上次的值，`a`、`b` 都没变。它们为 1，是因为这是模型的第一次 ico 调用，标志 `__VicoDidInit` 还是 0，生成代码在比较之后把这两位强制置 1，同时把标志置 1（`build/tr/Vtop___024root__0.cpp` 第 30 至 42 行，教程 4.2 节第 4 点）。函数体因此执行一次 `f = a ^ b`，结果和 Settle 区算出的相同。第 64 位是 `__VicoTriggered[1]` 的最低位，即"本轮第一次调用"的内部位（64 加 0）。第二次调用没有触发，返回假。
9. `eval_act` 到 `eval_react` 各一次：本设计在这些区里没有逻辑，函数直接返回假（教程 4.2 节），各循环转一圈就退出。`eval_postponed` 也在末尾被调用一次，但它是 `void` 函数，没有返回值，不在任何循环里，由运行库直接调用（`verilated.cpp` 第 4129、4130 行）。
10. `End-of-eval cleanup`：`evalEnd()`（`Vtop.cpp` 第 72 至 75 行）调用 `Verilated::endOfEval`，打印这一行（`verilated.cpp` 第 4029 行）。
11. `after E1: f=1`：testbench 自己的打印，1 ^ 0 = 1。

每次调用 `eval_ico` 后面都跟着 `dump_triggers__ico` 和两次 `trigger_anySet__ico`。`dump_triggers__ico` 是调试打印本身，它先调用一次 `trigger_anySet__ico` 决定要不要打印 `No 'ico' region triggers active`（`build/tr/Vtop___024root__0__Slow.cpp` 第 146 行），然后逐位打印；第二次 `trigger_anySet__ico` 才是 `eval_ico` 自己用来决定执不执行函数体的那次（教程 4.2 节第 5 点）。

把每段里的区名按出现顺序抽出来，去掉 `dump_triggers` 与 `trigger_anySet` 这些辅助调用。E1 和 E2 抽出来是：

```text
E1: static initial stl stl sample ico ico act inact nba obs react postponed
E2: sample ico ico act inact nba obs react postponed
```

### 4.4 E2 至 E5 与 final

E2 至 E5 的结构和 E2 相同，差别只在 ico 区第一次调用时哪些位触发，以及函数体执不执行。只看那几行和打印：

| 段 | 改了什么 | ico 第一次调用的触发位 | 执行 `f = a ^ b` 吗 | `f` |
| --- | --- | --- | --- | --- |
| E2 | `b` 从 0 改成 1 | 1（`@( b)`）、64 | 执行 | 1 ^ 1 = 0 |
| E3 | 什么都没改 | 只有 64 | 不执行 | 仍是 0 |
| E4 | 往输出 `f` 写 7 | 只有 64 | 不执行 | 仍是 7 |
| E5 | `a` 从 1 改成 0 | 0（`@( a)`）、64 | 执行 | 0 ^ 1 = 1 |

`trace.txt` 里五行 `after` 依次是：

```text
after E1: f=1
after E2: f=0
after E3: f=0
after E4: f=7
after E5: f=1
```

E3 说明本设计的 ico 区每次 `eval` 都调用两次：内部位让第一次调用总是返回真，但 `f = a ^ b` 外面那个 `if` 只看第 0、1 位（`build/tr/Vtop___024root__0.cpp` 第 53 行，教程 4.2 节第 6 点），这两位为 0 时函数体不执行。"两次"取决于设计：第 7 节的 `seq` 在 ico 区没有要算的东西，它的 `eval_ico` 无条件返回假，每次 `eval` 只调用一次。

E4 说明 `eval` 判断要不要重算，只看输入有没有变，不看输出对不对。`f` 只是 `TOP` 里的一个字节，testbench 往里写 7，它就是 7；输入没变，`eval` 不会去纠正它，直到 E5 的 `a` 变了才重算。testbench 不应该写输出端口。

最后一段：

```text
== END
-V{t1,125}+    Vtop___024root___eval_final
```

`top->final()`（`Vtop.cpp` 第 168 至 172 行）调用 `evalFinal()`，执行设计里的 `final` 块。本设计没有 `final` 块，函数是空的。

把每个区在一次 `eval` 里被调用的次数整理成表。

| 区 | E1 | E2 至 E5 |
| --- | --- | --- |
| static、initial | 1 | 0 |
| stl（Settle） | 2 | 0 |
| sample | 1 | 1 |
| ico | 2 | 2 |
| act、inact、nba、obs、react | 各 1 | 各 1 |
| postponed | 1 | 1 |

这张表只对本设计成立：有寄存器的设计在 act、nba 区会有触发，循环次数随之变化（第 7 节）。

**这一节搭好的积木**：一次 `eval` 的执行顺序可以直接打印出来。第一次 `eval` 先初始化、跑 Settle 区，之后每次依次是 sample、ico、act 到 react、postponed。本设计的 ico 区每次调用两次，函数体只在输入变化时执行，第一次 `eval` 例外，那时触发位被强制置 1；输出端口只是存储，`eval` 不会去纠正它。接下来的问题：一个区里有多条 `assign` 时，它们按什么顺序执行。

---

## 5 静态排序：assign 写的先后不影响结果

上一节：ico 区的函数体执行一次就把 `f` 算好。这一节的问题：函数体里有好几条赋值、而且源码里倒着写时，一次执行还能不能算对。

### 5.1 [做 L1] 倒着写的三条 assign

`chain.v`：

```verilog
module chain(
  input  a,
  input  b,
  output f
);
  wire t1, t2;
  assign f  = t2 & a;
  assign t2 = ~t1;
  assign t1 = a ^ b;
endmodule
```

三条 `assign` 的依赖关系是 `t1` 到 `t2` 到 `f`，源码却按 `f`、`t2`、`t1` 的顺序写。

一个对照：如果只按源码顺序把这三句各执行一次，会怎样？三根线都是 1 位，按位算，设 `t1`、`t2` 初值都是 0，输入 `a=1`、`b=1`：

1. `f = t2 & a = 0 & 1 = 0`
2. `t2 = ~t1`，1 位的取反，`~0` 得 1
3. `t1 = a ^ b = 1 ^ 1 = 0`

`f` 得到 0，第 1 步用到的是还没更新的 `t2`。而电路的真实行为按依赖走：先算 `t1 = 0`，再算 `t2 = 1`，最后 `f = 1 & 1 = 1`。下面的实验说明生成代码按的是后一种。

`tb_chain.cpp` 用两层循环把四种输入各写一次，每次只调用一次 `eval`：

```cpp
#include <cstdio>
#include "Vchain.h"
#include "verilated.h"

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    Vchain* top = new Vchain{contextp};
    for (int a = 0; a < 2; a++) {
        for (int b = 0; b < 2; b++) {
            top->a = a;
            top->b = b;
            top->eval();
            printf("a=%d b=%d f=%d\n", a, b, top->f);
        }
    }
    top->final();
    delete top;
    delete contextp;
    return 0;
}
```

```bash
verilator --cc --exe --build -j 0 -Wall --Mdir build/ch tb_chain.cpp chain.v
build/ch/Vchain
```

```text
a=0 b=0 f=0
a=0 b=1 f=0
a=1 b=0 f=0
a=1 b=1 f=1
```

四行都对：`f = ~(a ^ b) & a`，只有 `a=1`、`b=1` 时为 1。

### 5.2 生成代码：排好序，再并成一条

`build/ch/Vchain___024root__0.cpp` 第 56 至 58 行，ico 区的函数体：

```cpp
                    vlSelfRef.f = ((~ ((IData)(vlSelfRef.a) 
                                       ^ (IData)(vlSelfRef.b))) 
                                   & (IData)(vlSelfRef.a));
```

三条 `assign` 变成了一条表达式，`t1`、`t2` 不见了。根类 `build/ch/Vchain___024root.h` 第 16 至 24 行的成员只有端口和触发记录，没有 `t1`、`t2`。

`t1`、`t2` 的消失是编译时两件事的结果，一是排序，二是代入。

1. **排序**：Verilator 在编译时分析每条赋值读哪些信号、写哪个信号，按依赖关系排出固定的顺序，被依赖的先算（教程 8.1 节）。源码里的书写顺序不参与决定。
2. **代入**：`t1`、`t2` 只被用了一次，Verilator 把它们的表达式直接代进 `f` 的式子，中间线就不再需要存储。

所以 Verilog 里的 `assign` 描述的是连线关系，写的先后不影响结果。代价是中间线从模型里消失了，C++ 读不到 `t1`。

### 5.3 [做 L1] 想读中间线：public 与 public_flat

`chain_pub.v` 只在 `t1` 的声明后面加了一条注释形式的标记：

```verilog
module chain_pub(
  input  a,
  input  b,
  output f
);
  wire t1 /*verilator public*/;
  wire t2;
  assign f  = t2 & a;
  assign t2 = ~t1;
  assign t1 = a ^ b;
endmodule
```

`chain_flat.v` 换成另一种标记：

```verilog
module chain_flat(
  input  a,
  input  b,
  output f
);
  wire t1 /*verilator public_flat*/;
  wire t2;
  assign f  = t2 & a;
  assign t2 = ~t1;
  assign t1 = a ^ b;
endmodule
```

```bash
verilator --cc -Wall --Mdir build/cp chain_pub.v
verilator --cc -Wall --Mdir build/cf chain_flat.v
```

给 `t1` 加上 `/*verilator public*/` 以后，生成的文件变了。

1. `build/cp` 有 19 个文件，比第 1 节多出 `Vchain_pub_chain_pub.h`、三个 `Vchain_pub_chain_pub*.cpp` 和 `Vchain_pub__Dpi.h`、`Vchain_pub__Dpi.cpp`。
2. 模块 `chain_pub` 没有被并进根类，单独成为一个类。`build/cp/Vchain_pub_chain_pub.h` 第 16 至 20 行：

    ```cpp
        // DESIGN SPECIFIC STATE
        CData/*0:0*/ a;
        CData/*0:0*/ b;
        CData/*0:0*/ f;
        CData/*0:0*/ t1;
    ```

3. 根类里只留一个指向它的指针：`Vchain_pub___024root.h` 第 17 行 `Vchain_pub_chain_pub* chain_pub;`。模型类里也有一个：`Vchain_pub.h` 第 44 行 `Vchain_pub_chain_pub* const chain_pub;`。C++ 里写 `top->chain_pub->t1` 就能读到。
4. 没加标记的 `t2` 照样被优化掉。

`tb_pub.cpp` 给 `a=1`、`b=0`，`eval` 一次，读 `t1`：

```cpp
#include <cstdio>
#include "Vchain_pub.h"
#include "Vchain_pub_chain_pub.h"
#include "verilated.h"

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    Vchain_pub* top = new Vchain_pub{contextp};
    top->a = 1; top->b = 0; top->eval();
    printf("t1=%d f=%d\n", top->chain_pub->t1, top->f);
    top->final();
    delete top;
    delete contextp;
    return 0;
}
```

```bash
verilator --cc --exe --build -j 0 -Wall --Mdir build/cpr tb_pub.cpp chain_pub.v
build/cpr/Vchain_pub
```

```text
t1=1 f=0
```

`t1 = 1 ^ 0 = 1`，`f = ~1 & 1 = 0`。和第 3 节同理，第三行要包含模块类的头文件 `Vchain_pub_chain_pub.h`：`Vchain_pub.h` 第 16 行只提前声明了 `class Vchain_pub_chain_pub;`，删掉这一行，g++ 同样报 `invalid use of incomplete type ‘class Vchain_pub_chain_pub’`。

给 `t1` 加上 `/*verilator public_flat*/` 以后，结果不同。

1. `build/cf` 有 15 个文件，多出的只有 `__Dpi.h`、`__Dpi.cpp` 两个，没有单独的模块类。
2. `t1` 留在根类里，按第 3 节的规则命名：`Vchain_flat___024root.h` 第 20 行 `CData/*0:0*/ chain_flat__DOT__t1;`。
3. `t2` 同样被优化掉。
4. `t1` 没有被代入，5.2 节说的排序这次直接看得到。`build/cf/Vchain_flat___024root__0.cpp` 的 ico 区里先算 `t1`（第 56、57 行），再算 `f`（第 64、65 行）：

    ```cpp
                        vlSelfRef.chain_flat__DOT__t1 = 
                            ((IData)(vlSelfRef.a) ^ (IData)(vlSelfRef.b));
    ...
                        vlSelfRef.f = ((~ (IData)(vlSelfRef.chain_flat__DOT__t1)) 
                                       & (IData)(vlSelfRef.a));
    ```

    源码里 `f` 写在最前、`t1` 写在最后，生成代码的顺序正好反过来。`t2` 被代进了 `f` 的式子，所以只看到 `~t1`。

`tb_flat.cpp` 由 `tb_pub.cpp` 改三处得到：`Vchain_pub` 都换成 `Vchain_flat`；第三行改为包含根类头文件 `Vchain_flat___024root.h`；`printf` 里读 `top->rootp->chain_flat__DOT__t1`。

```bash
verilator --cc --exe --build -j 0 -Wall --Mdir build/cfr tb_flat.cpp chain_flat.v
build/cfr/Vchain_flat
```

```text
t1=1 f=0
```

两种标记的区别在于模块会不会被拆出来：给变量加 `public`，连带把它所在的模块也变成 public，模块因此单独成类；只想保住这一个变量、不拆模块，用 `public_flat`（指南 `/*verilator public*/` 一条）。两者都只保住被标记的那个信号。

**这一节搭好的积木**：Verilator 在编译时按依赖关系给组合赋值排序，并把只用一次的中间线代入表达式，所以 `assign` 的书写顺序不影响结果，一次求值就能算对。代价是中间线从模型里消失；需要从 C++ 读时，用 `public` 或 `public_flat` 标记保住它。接下来的问题：依赖关系排不出顺序（组合环）时，反复执行的上限从哪里来。

---

## 6 收敛上限

教程第 8 节的组合环在第二次 `eval` 里报 `Input combinational region did not converge after '--converge-limit' of 10000 tries`。这一节的问题：10000 从哪里来，能不能改；报错里的区名为什么是 Input combinational。

### 6.1 [做 L1] 把上限改成 50，一开始就闭合环

`loop.v` 与教程第 8 节相同：

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

`tb_loop.cpp` 和教程的不同：在第一次 `eval` 之前就把 `en` 设成 1。

```cpp
#include <cstdio>
#include "Vloop.h"
#include "verilated.h"

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    Vloop* top = new Vloop{contextp};
    top->en = 1;
    top->eval();
    printf("en=1: f=%d\n", top->f);
    top->final();
    delete top;
    delete contextp;
    return 0;
}
```

这个设计里有一个组合环，`x` 的表达式用到 `x` 自己，构建时 Verilator 会报 UNOPTFLAT 警告；警告默认是致命的，所以加 `-Wno-UNOPTFLAT` 单独关掉它（教程 8.1 节）。环本身并没有被修好，只是推迟到运行时才暴露。另一个选项是 `--converge-limit 50`：

```bash
verilator --cc --exe --build -j 0 -Wall -Wno-UNOPTFLAT --converge-limit 50 --Mdir build/lp tb_loop.cpp loop.v
build/lp/Vloop; echo "exit=$?"
```

```text
%Error-DIDNOTCONVERGE: Settle region did not converge after '--converge-limit' of 50 tries
Aborting...
exit=1
```

两处和教程不同：上限是 50，区名是 Settle。

### 6.2 上限写在哪里

`build/lp/Vloop.cpp` 第 12 行：

```cpp
    , m_evalLoop{*this, /*convergeLimit:*/ 50}
```

第 1 节的 `Vtop.cpp` 第 12 行在同一个位置写的是 10000。上限是 Verilator 生成代码时写进构造函数的常数，`--converge-limit` 改的就是这个数，默认 10000（指南 13.1 节 `--converge-limit`）。要改上限得重新运行 Verilator，运行时改不了。

### 6.3 区名从哪里来

运行库 `verilated.cpp` 的 `evalImpl()` 里，Settle 区和 ico 区各有一个循环，每转一圈先调用 `checkConvergence`，传进去的名字不同：

```cpp
        do {
            checkConvergence(++stlIterCount, "Settle", &VerilatedModel::dumpTriggersStl);
        } while (m_model.evalStl(stlIterCount == 1));
```

（第 4075 至 4077 行，只在第一次 `eval` 里执行）

```cpp
        do {
            checkConvergence(++icoIterCount, "Input combinational",
                             &VerilatedModel::dumpTriggersIco);
        } while (m_model.evalIco(icoIterCount == 1));
```

（第 4088 至 4091 行，每次 `eval` 都执行）

`checkConvergence`（`verilated.h` 第 408 至 411 行）在圈数大于上限时调用 `didNotConverge`，后者把这个名字拼进报错（`verilated.cpp` 第 4044 至 4052 行）。

教程第 8 节先用 `en=0` 做了第一次 `eval`：Settle 区收敛，然后 `en=1` 的第二次 `eval` 里环在 ico 区闭合，所以报 Input combinational。本节在第一次 `eval` 之前就设了 `en=1`，环在 Settle 区就闭合了。Settle 区的函数体 `build/lp/Vloop___024root__0__Slow.cpp` 第 58 至 67 行和 ico 区一样是 `x = ~f & en; f = x;`。函数体执行的条件是"本轮第一次调用"的内部位为 1，或者 `f` 和上次记下的值不同（第 35 至 42 行、第 58、59 行）。`en=1` 时每执行一次 `f` 就翻转一次，第二个条件永远成立。

圈数怎样数：`++stlIterCount` 先加一再检查，检查通过才调用 `evalStl`。第 1 至 50 圈的检查都通过，`evalStl` 执行了 50 次；第 51 圈时 51 大于 50，报错退出。退出码 1 的来由见教程 4.5 节（`vl_fatal` 调用 `exit(1)`）。

上限只决定"多久以后放弃"。真的组合环在任何上限下都不会收敛，正确的做法是把环拆掉（教程第 8 节）。

**这一节搭好的积木**：收敛上限是生成代码时写进模型构造函数的常数，默认 10000，用 `--converge-limit` 改。报错里的区名告诉你环是在哪个区闭合的：第一次 `eval` 里就闭合是 Settle，之后才闭合是 Input combinational。接下来的问题：有寄存器时，act 区和 NBA 区怎样工作，输入和时钟同时变化会怎样。

---

## 7 输入和时钟在同一次 eval 里变

时钟在 Verilator 的模型里就是又一个输入（教程 4.3 节）。这一节的问题：testbench 在同一次 `eval` 之前同时改了数据输入和时钟，寄存器取到的是改之前还是改之后的数据。

### 7.1 [做 L1] 两种写法

`seq.v`：一个寄存器 `q`，在 `clk` 上升沿取 `d`，`d` 是输入 `in` 取反。

```verilog
module seq(
  input      clk,
  input      in,
  output reg q
);
  wire d = ~in;
  always @(posedge clk) q <= d;
endmodule
```

`tb_seq.cpp` 用两种写法各给一次上升沿：

```cpp
#include <cstdio>
#include "Vseq.h"
#include "verilated.h"

static void mark(const char* s) { printf("== %s\n", s); fflush(stdout); }

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    Vseq* top = new Vseq{contextp};

    // in 1->0 makes d 0->1 in the same eval as the rising edge
    mark("S1 clk=0 in=1");
    top->clk = 0; top->in = 1; top->eval();
    mark("S2 clk=1 and in=0 in the same eval");
    top->clk = 1; top->in = 0; top->eval();
    printf("same eval:     q=%d\n", top->q);

    // in settles in its own eval, then the rising edge alone
    mark("S3 clk=0 in=1");
    top->clk = 0; top->in = 1; top->eval();
    mark("S4 clk=1 alone");
    top->clk = 1; top->eval();
    printf("separate eval: q=%d\n", top->q);
    mark("END");

    top->final();
    delete top;
    delete contextp;
    return 0;
}
```

1. 第一种（S1、S2）：先 `clk=0`、`in=1`，`eval`，此时 `d = ~1 = 0`。然后在同一次 `eval` 之前把 `clk` 改成 1、`in` 改成 0。
2. 第二种（S3、S4）：先 `clk=0`、`in=1`，`eval`；然后只把 `clk` 改成 1，`eval`。
3. `mark` 和第 4 节的一样，打印以 `==` 开头的标记，7.3 节看轨迹时用。不开调试时，标记只是多出来的几行打印。

```bash
verilator --cc --exe --build -j 0 -Wall --Mdir build/sq tb_seq.cpp seq.v
build/sq/Vseq
```

```text
== S1 clk=0 in=1
== S2 clk=1 and in=0 in the same eval
same eval:     q=1
== S3 clk=0 in=1
== S4 clk=1 alone
separate eval: q=0
== END
```

第一种写法里，上升沿之前的 `d` 是 0，`q` 却取到了 1，也就是 `in` 改成 0 以后的新 `d`。第二种写法取到 0。

### 7.2 生成代码：act 区判沿，NBA 区赋值

`build/sq/Vseq___024root__0.cpp` 里，act 区（第 54 至 73 行）判断上升沿：

```cpp
        vlSelfRef.__VactTriggered[0U] = (QData)((IData)(
                                                        ((IData)(vlSelfRef.clk) 
                                                         & (~ (IData)(vlSelfRef.__Vtrigprevexpr___TOP__clk__1)))));
        vlSelfRef.__Vtrigprevexpr___TOP__clk__1 = vlSelfRef.clk;
```

（第 61 至 64 行）当前 `clk` 是 1、上次记下的是 0，就是上升沿，触发位置 1；然后记下当前值。第 71 行把这个触发位并进 NBA 区的触发位。

NBA 区（第 86 至 107 行）在触发时执行寄存器的更新：

```cpp
            if ((1ULL & vlSelfRef.__VnbaTriggered[0U])) {
                {
                    // Inlined CFunc: _nba_sequent__TOP__0
                    vlSelfRef.q = (1U & (~ (IData)(vlSelfRef.in)));
                }
            }
```

（第 97 至 102 行）`wire d = ~in` 被代进了这条赋值（第 5 节的代入），`q` 直接取 `~in`，读的是执行到这一行时 `in` 的当前值。

用它推第一种写法的第二次 `eval`：进入 `eval` 时 `clk` 已经是 1、`in` 已经是 0。act 区看到上升沿，NBA 区执行 `q = ~in = ~0 = 1`。`in` 的旧值 1 在这时已经被覆盖，模型里根本没有地方存着"沿之前的 `d`"。

第二种写法：`in=1` 在前一次 `eval` 里就写好了，上升沿那次 `eval` 里 `q = ~1 = 0`。

### 7.3 [做 L1] 一次上升沿的区轨迹

用第 4 节的办法看 act 区和 NBA 区怎样转。带 `--runtime-debug` 再构建一份：

```bash
verilator --cc --exe --build -j 0 -Wall --runtime-debug --Mdir build/sqd tb_seq.cpp seq.v
build/sqd/Vseq +verilator+debug > build/seqtrace.txt 2>&1; echo "exit=$?"
```

退出码 0，`build/seqtrace.txt` 一共 122 行。S2 那一段（`clk` 0 到 1，同时 `in` 1 到 0）：

```text
== S2 clk=1 and in=0 in the same eval
-V{t1,32}+++++TOP Evaluate Vseq::eval_step
-V{t1,33}+ Eval
-V{t1,34}+    Vseq___024root___eval_debug_assertions
-V{t1,35}+    Vseq___024root___eval_sample
-V{t1,36}+    Vseq___024root___eval_ico
-V{t1,37}+    Vseq___024root___dump_triggers__ico
-V{t1,38}+    Vseq___024root___trigger_anySet__ico
-V{t1,39}         'ico' region trigger index 0 is active: @( clk)
-V{t1,40}         'ico' region trigger index 1 is active: @( in)
-V{t1,41}         'ico' region trigger index 64 is active: Internal 'ico' trigger - first iteration
-V{t1,42}+    Vseq___024root___eval_act
-V{t1,43}+    Vseq___024root___dump_triggers__act
-V{t1,44}+    Vseq___024root___trigger_anySet__act
-V{t1,45}         'act' region trigger index 0 is active: @(posedge clk)
-V{t1,46}+    Vseq___024root___trigger_orInto__act_vec_vec
-V{t1,47}+    Vseq___024root___eval_inact
-V{t1,48}+    Vseq___024root___eval_nba
-V{t1,49}+    Vseq___024root___trigger_anySet__act
-V{t1,50}+    Vseq___024root___trigger_clear__act
-V{t1,51}+    Vseq___024root___eval_act
-V{t1,52}+    Vseq___024root___dump_triggers__act
-V{t1,53}+    Vseq___024root___trigger_anySet__act
-V{t1,54}         No 'act' region triggers active
-V{t1,55}+    Vseq___024root___trigger_orInto__act_vec_vec
-V{t1,56}+    Vseq___024root___eval_inact
-V{t1,57}+    Vseq___024root___eval_nba
-V{t1,58}+    Vseq___024root___trigger_anySet__act
-V{t1,59}+    Vseq___024root___eval_obs
-V{t1,60}+    Vseq___024root___eval_react
-V{t1,61}+    Vseq___024root___eval_postponed
-V{t1,62}End-of-eval cleanup
same eval:     q=1
```

按第 4 节的办法可以从轨迹里抽出四段的区名，前三段抽出来是：

```text
S1: static initial stl sample ico act inact nba obs react postponed
S2: sample ico act inact nba act inact nba obs react postponed
S3: sample ico act inact nba obs react postponed
S4: sample ico act inact nba act inact nba obs react postponed
```

逐条读：

1. ico 区每次只调用一次。触发位照样算了、也打印了，可是 `Vseq` 的 `eval_ico` 最后无条件返回假（`build/sq/Vseq___024root__0.cpp` 第 46 行）。`d = ~in` 已经被代进 NBA 区的赋值（7.2 节），ico 区没有要算的东西。第 4 节的 `Vtop` 每次调用两次，是因为它的 ico 区里有 `f = a ^ b`。S1 里的 Settle 区也只调用一次，原因相同。
2. S2 里 act 区第一次调用打印 `@(posedge clk)`，即 7.2 节那个上升沿触发位为 1。`eval_act` 把它并进 NBA 区的触发位（第 71 行），自己返回假（第 72 行），所以 act 循环只转一圈。
3. `eval_nba` 先调用 `trigger_anySet__act` 看 NBA 区的触发位，有触发就执行 `q = ~in`，清掉触发位，返回真（第 93 至 106 行）。
4. 运行库的 NBA 循环把 act 循环和 inact 循环包在里面（`verilated.cpp` 第 4107 至 4122 行）：`evalNba()` 返回真，就从 act 区重新转一圈，因为寄存器更新以后，可能有别的逻辑要跟着变。第二圈 act 区没有触发，NBA 区返回假，循环结束。act、inact、nba 因此各出现两次。
5. S3 是下降沿。act 区算的是"当前 `clk` 为 1 且上次为 0"，这次为假，没有触发，NBA 区不执行，各转一圈。
6. S4 只有上升沿，区序列和 S2 相同。

### 7.4 哪一种是对的

真实的触发器在时钟沿到来之前采样 `d`，数据要在沿之前稳定。第二种写法对应的正是这件事：数据先变、稳定，时钟再上升。

第一种写法里，数据和时钟在同一个时刻变化。IEEE 1800-2017 第 4.7 节规定，同一时刻的活动事件可以按任意顺序处理，第 4.8 节把这类情况称为竞争（race）：结果取决于仿真器先处理哪一个。标准不保证哪一种结果，Verilator 5.052 在这个例子里取到新值，这只是一次实测，不能依赖。

testbench 的写法由此确定：改数据输入和给上升沿放在两次 `eval` 里。在 `clk=0` 时写好输入并 `eval`，再把 `clk` 改成 1 并 `eval`。

**这一节搭好的积木**：寄存器的更新在 act 区判沿、在 NBA 区赋值，赋值读的是执行那一刻的输入；NBA 区执行过，运行库就从 act 区再转一圈。数据和时钟同一次 `eval` 里变化是竞争，Verilator 5.052 取新值；testbench 要把数据和时钟沿分到两次 `eval` 里。接下来的问题：时间本身怎样推进，Verilog 里写的 `#10` 能不能用。

---

## 8 延迟：--timing、--no-timing 与 --binary

仿真时间由 testbench 调用 `timeInc` 推进，`eval` 自己不推进时间（教程 4.3 节）。这一节的问题：设计里写了 `#10` 这样的延迟，Verilator 怎样处理。

### 8.1 [做 L1] 四种构建

`dly.v`：

```verilog
module dly;
  initial begin
    #10 $display("t=%0t hello", $time);
    $finish;
  end
endmodule
```

等 10 个时间单位，打印当前时间，然后 `$finish`。

第一种，什么都不说：

```bash
verilator --cc -Wall --Mdir build/d1 dly.v
```

```text
%Error-NEEDTIMINGOPT: dly.v:3:5: Use --timing or --no-timing to specify how delays should be handled
                               : ... note: In instance 'dly'
    3 |     #10 $display("t=%0t hello", $time);
      |     ^
                      ... For error description see https://verilator.org/warn/NEEDTIMINGOPT?v=5.052
%Error: Exiting due to 1 error(s)
```

退出码 1。Verilator 要求明确选择怎样处理延迟（指南 10.2 节，NEEDTIMINGOPT 一条）。

第二种，`--no-timing`，这次不加 `-Wall`：

```bash
verilator --cc --no-timing --Mdir build/d2 dly.v
```

```text
%Warning-STMTDLY: dly.v:3:5: Ignoring delay on this statement due to --no-timing
                           : ... note: In instance 'dly'
    3 |     #10 $display("t=%0t hello", $time);
      |     ^
                  ... For warning description see https://verilator.org/warn/STMTDLY?v=5.052
                  ... Use "/* verilator lint_off STMTDLY */" and lint_on around source to disable this message.
%Error: Exiting due to 1 warning(s)
```

退出码非 0。`--no-timing` 表示忽略延迟，和综合工具的做法一样，同时给出 STMTDLY 警告（指南 10.2 节）。这条警告不靠 `-Wall` 打开，默认就会报。Verilator 默认把警告当致命错误处理：打印完警告，以最后一行 `%Error: Exiting due to 1 warning(s)` 退出（`-Wno-fatal` 的说明，指南 13.1 节）。所以只加 `--no-timing` 构建不出来。要继续构建有两条路：单独关掉这条警告（加 `-Wno-STMTDLY`，见下面第四种），或者加 `-Wno-fatal` 让警告照报、但不致命。

第三种，`--binary`：

```bash
verilator --binary -j 0 -Wall --Mdir build/d dly.v
build/d/Vdly; echo "exit=$?"
```

```text
t=10 hello
- dly.v:4: Verilog $finish
- S i m u l a t i o n   R e p o r t: Verilator 5.052 2026-09-05
- Verilator: $finish at 10ps; walltime 0.000 s; speed 21.242 ns/s
- Verilator: cpu 0.000 s on 1 threads; allocated 4 MB
exit=0
```

`--binary` 等于 `--main --exe --build --timing` 四个选项合在一起（指南 13.1 节 `--binary`）：自动生成 `main()`，打开延迟支持，直接构建出可执行文件。延迟生效了，`$time` 是 10，`$finish` 发生在 10ps。walltime 与 speed 每次运行不同。

时间单位是 ps：没有写 `` `timescale `` 时，默认的时间单位和精度都是 1ps（指南 13.1 节 `--timescale`）。

第四种，在 `--binary` 后面再加 `--no-timing`，并用 `-Wno-STMTDLY` 关掉那条警告：

```bash
verilator --binary -j 0 -Wall --no-timing -Wno-STMTDLY --Mdir build/d3 dly.v
build/d3/Vdly
```

```text
t=0 hello
- dly.v:4: Verilog $finish
- S i m u l a t i o n   R e p o r t: Verilator 5.052 2026-09-05
- Verilator: $finish at 0s; walltime 0.000 s; speed 0.000 s/s
- Verilator: cpu 0.000 s on 1 threads; allocated 4 MB
```

构建成功，`build/d3/Vdly_classes.mk` 里是 `VM_TIMING = 0`：`--no-timing` 盖过了 `--binary` 隐含的 `--timing`。`#10` 被整个忽略，`$display` 在时刻 0 执行，`$finish` 也发生在时刻 0。这就是"忽略延迟"的实际效果：设计里靠延迟安排先后的代码，全部挤到同一时刻。

### 8.2 生成的 main 怎样推进时间

`build/d/Vdly__main.cpp` 第 19 至 26 行：

```cpp
    // Simulate until $finish
    while (VL_LIKELY(!contextp->gotFinish())) {
        // Evaluate model
        topp->eval();
        // Advance time
        if (!topp->eventsPending()) break;
        contextp->time(topp->nextTimeSlot());
    }
```

每转一圈：`eval` 一次；问模型还有没有待处理的定时事件，没有就退出；有就把仿真时间直接设成下一个事件的时刻。

这正是第 1 节那两个函数。没有延迟的 `Vtop` 里 `eventsPending()` 恒为假、`nextTimeSlot()` 直接报错；有延迟的 `Vdly` 里（`build/d/Vdly.cpp` 第 149、151 行）：

```cpp
bool Vdly::eventsPending() { return !vlSymsp->TOP.__VdlySched.empty() && !contextp()->gotFinish(); }

uint64_t Vdly::nextTimeSlot() { return vlSymsp->TOP.__VdlySched.nextTimeSlot(); }
```

`__VdlySched` 是根类里的延迟调度器（`Vdly___024root.h` 第 24 行，类型 `VlDelayScheduler`），记录着哪些代码在等哪个时刻。

### 8.3 initial 块变成了协程

`initial` 块在 `build/d/Vdly___024root__0.cpp` 第 132 至 143 行：

```cpp
VlCoroutine Vdly___024root___eval_initial__TOP__Vtiming__0(Vdly___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vdly___024root___eval_initial__TOP__Vtiming__0\n"); );
    Vdly__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    co_await vlSelfRef.__VdlySched.delay(0x000000000000000aULL, 
                                         nullptr, "dly.v", 
                                         3);
    VL_WRITEF_NX("t=%0t hello\n",2, 'T',-12, '#',64,VL_TIME_UNITED_Q(1));
    VL_FINISH_MT("dly.v", 4, "");
    co_return;
}
```

返回类型 `VlCoroutine` 和 `co_await`、`co_return` 说明这是 C++ 的协程：执行到 `co_await` 时，函数把自己挂起，把控制交还给调用者，以后可以从挂起的地方接着执行。`#10` 变成了 `co_await __VdlySched.delay(0xa, ...)`，`0xa` 就是 10：向调度器登记"10 时刻叫醒我"，然后挂起。`VL_WRITEF_NX` 参数里的 `-12` 是时间单位的指数，10 的 -12 次方秒即 ps。打开延迟支持需要支持协程的 C++ 编译器（指南 13.1 节 `--timing`），构建时多链接了运行库的 `verilated_timing.o`（`build/d.log` 第 7 行），`Vdly_classes.mk` 第 11 行是 `VM_TIMING = 1`。

把 8.2 节的循环和协程合起来推一遍：

1. 时刻 0，第一次 `eval`：初始化时启动 `initial` 协程，执行到 `co_await` 登记 10 时刻并挂起，`eval` 返回。
2. `eventsPending()` 为真，`nextTimeSlot()` 返回 10，仿真时间设成 10。
3. 时刻 10 的 `eval`：act 区的触发条件是调度器里有等待当前时刻的协程（`Vdly___024root__0.cpp` 第 58 行），成立，于是调用 `__VdlySched.resume()`（第 73 行）恢复协程。协程打印 `t=10 hello`，执行 `$finish`，`gotFinish` 立起来（教程 2.3 节）。
4. 循环条件不再成立，退出循环，调用 `final()`，再调用 `statsPrintSummary()` 打印 Simulation Report 那三行（`Vdly__main.cpp` 第 32 至 36 行）。

本课程的电路由 C++ testbench 驱动，时间由 testbench 推进（教程 4.3 节），设计本身是可综合的 RTL，不写 `#` 延迟。`#` 延迟出现在用 Verilog 写的 testbench 里，读到这样的代码时，用 `--timing` 或 `--binary` 构建。

**这一节搭好的积木**：Verilator 遇到延迟必须明确选择：`--no-timing` 忽略延迟，所有延迟都当 0，构建时还要再加 `-Wno-STMTDLY` 关掉警告，或者用 `-Wno-fatal` 让警告不致命；`--timing` 把带延迟的过程编译成协程，由延迟调度器在到点时恢复。时间由 `main()` 的循环用 `eventsPending()` 和 `nextTimeSlot()` 推进，`--binary` 会生成这个循环。没有延迟的设计里，推进时间是 testbench 的事。

---

## 9 速查

| 想做的事 | 做法 | 节 |
| --- | --- | --- |
| 看一次 `eval` 调用了哪些区 | 构建加 `--runtime-debug`，运行加 `+verilator+debug` | 4 |
| 从 C++ 读子模块里的寄存器（调试用） | 包含 `V<顶层>___024root.h`，读 `top->rootp-><顶层>__DOT__<实例>__DOT__<信号>` | 3 |
| 保住一根会被优化掉的线 | 声明后加 `/*verilator public_flat*/`；要连模块一起拆出来用 `/*verilator public*/` | 5 |
| 改不收敛的上限 | `--converge-limit N`，默认 10000，写进模型构造函数 | 6 |
| 时序电路的 testbench 改输入 | `clk=0` 时写输入并 `eval`，再 `clk=1` 并 `eval` | 7 |
| 从 C++ 读 `public` 标记的信号 | 包含模块类头文件（本篇是 `Vchain_pub_chain_pub.h`），经 `V<顶层>.h` 里的指针读，例如 `top->chain_pub->t1` | 5 |
| 从 C++ 读 `public_flat` 标记的信号 | 包含根类头文件，读 `top->rootp-><顶层>__DOT__<信号>` | 5 |
| 构建带 `#` 延迟的 Verilog | `--timing`，或用 `--binary` 一步生成 `main()` 并构建 | 8 |
| 忽略延迟 | `--no-timing -Wno-STMTDLY`；只加 `--no-timing` 会因 STMTDLY 构建失败 | 8 |

把调试轨迹里常出现的行与含义整理成表。

| 行 | 含义 |
| --- | --- |
| `-V{t1,N}` | 线程 1 的第 N 条调试消息 |
| `+++++TOP Evaluate ... eval_step`、`+ Eval` | 一次 `eval` 开始 |
| `+ Initial` | 第一次 `eval` 的初始化 |
| `+    V..._eval_<区>` | 调用了这个区的函数一次 |
| `'<区>' region trigger index N is active: @( x)` | 这个区的第 N 个触发位为 1：信号 `x` 和上次记下的值不同，或者是模型第一次 ico 调用时被强制置 1 |
| `'act' region trigger index N is active: @(posedge clk)` | `clk` 的上升沿 |
| `... is active: Internal '<区>' trigger - first iteration` | "本轮第一次调用"的内部位。编号随设计变：`Vtop` 的 ico 区是 64，stl 区是 0 |
| `No '<区>' region triggers active` | 这个区的触发位全为 0 |
| `End-of-eval cleanup` | 一次 `eval` 结束 |

---

## 10 自检

答不上来就回到对应小节，每题都用命令验证。

    1. top->a 和 top->rootp->a 是不是同一个字节？用第 1 节的构造函数说明。    (1.2)
    2. 一个 40 位的输入端口是什么 C++ 类型？100 位的呢，几个字？             (2.2 2.3)
    3. 把 hier.v 里的 sub 再套一层（sub 里例化 sub2，实例名 u2，寄存器 r），
       r 在根类里叫什么？先写预测，再构建验证。                               (3.2)
    4. E1 之前 a、b 已经写好，eval_ico 比较时它们都没变，为什么第 0、1 位仍为 1？(4.3)
    5. E3 什么都没改，为什么 eval_ico 仍被调用两次？seq 为什么每次只调用一次？(4.4 7.3)
    6. tb_hier.cpp 不包含 Vhier___024root.h 会怎样？Vhier.h 里的提前声明为什么不够？(3.3)
    7. 把 chain.v 的三条 assign 改回正序，生成代码会变吗？                    (5.2)
    8. 教程第 8 节报 Input combinational，本篇第 6 节报 Settle，差别从哪里来？ (6.3)
    9. 上升沿那次 eval 里，act、inact、nba 为什么各出现两次？                 (7.3)
    10. 时序电路的 testbench 为什么不能在 clk 从 0 改成 1 的同一次 eval 前改数据？(7.4)
    11. 只加 --no-timing 为什么构建失败？忽略延迟以后 dly.v 打印什么？         (8.1)
    12. 不加 --timing，能不能用 C++ testbench 实现"等 10 个时间单位再打印"？
        该怎么写？                                                            (8.2)

---

## 11 依据

| 节 | 说法 | 依据 |
| --- | --- | --- |
| 1.1 | 只做 `--cc` 产出 13 个文件 | `ls build/cc` |
| 1.1 | 各生成文件的用途 | 指南 15.2 节 Files Read/Written（抽取文本 `E:\Workspace\Temp\ysyx-e4\src\verilator-guide.txt` 第 6489 至 6535 行）；`build/tr/Vtop___024root__0.cpp`、`__0__Slow.cpp` 的函数分布 |
| 1.1 | public 时多出模块类与 `__Dpi` 文件；`--binary` 多出 `__main.cpp`；构建后的产物 | `build/cp`、`build/cf`、`build/d` 的文件清单 |
| 1.2 | 构造函数、端口绑定、`rootp`、收敛上限 | `build/cc/Vtop.cpp` 第 9 至 20 行 |
| 1.2 | `TOP` 是 `Vtop__Syms` 的成员对象 | `build/cc/Vtop__Syms.h` 第 20 至 28 行 |
| 1.2 | 根类里存放端口与触发记录 | `build/cc/Vtop___024root.h` 第 16 至 24 行 |
| 1.3 | `Vtop` 继承 `VerilatedModel`，覆盖各区函数 | `build/cc/Vtop.h` 第 17、91 至 110 行；`Vtop.cpp` 第 93 至 95 行 |
| 1.3 | 调用链 | `Vtop.h` 第 61 行；`Vtop.cpp` 第 59 至 62 行；`verilated.h` 第 390 至 396 行；`verilated.cpp` 第 4055、4088 至 4091 行 |
| 1.3 | `eval_end_step` 为空；`eventsPending` 为假；`nextTimeSlot` 报错 | `Vtop.h` 第 66、70、72 行；`Vtop.cpp` 第 151、153 至 156 行 |
| 1.3 | `rootp` 指向 `$root`，`__024` 是 `$` 的转义 | 指南 6.1 节（第 938 至 943 行、第 971 至 973 行） |
| 2.1 | 十个端口的宏 | `build/w/Vwidths.h` 第 34 至 43 行 |
| 2.2 | 宏的定义与适用位宽 | `verilated_types.h` 第 251 至 255、261 至 265 行 |
| 2.2 | 类型名与底层整数 | `verilated.h` 第 119 至 123 行 |
| 2.3 | `VlWide` 的存储 | `verilated_types.h` 第 80 至 86 行 |
| 2.3 | 字数公式 | `verilatedos.h` 第 477、478、488 行 |
| 2.3 | 宽度检查的掩码；`w33` 的掩码为 `0ULL` | `build/w/Vwidths___024root__0.cpp` 第 198 至 217 行 |
| 3.1 | 子模块并进根类，没有单独的类 | `build/h` 的文件清单 |
| 3.1、3.2 | 层次信号名 `hier__DOT__u_sub__DOT__r` | `build/h/Vhier___024root.h` 第 16 至 28 行 |
| 3.2 | `.` 换成 `__DOT__`，因为 C++ 名字里不能有 `.` | 指南 `/*verilator inline_module*/` 一条（第 2510、2511 行） |
| 3.3 | 读内部成员要包含 `___024root.h`，经 `rootp` 访问 | 指南 6.1.2 节（第 963 至 975 行）；实测（`tb_hier` 构建并打印 `r=5a`） |
| 3.3 | `Vhier.h` 只提前声明根类；漏包含时的报错 | `build/h/Vhier.h` 第 14 行；删除包含行后重编的 `build/hr.log` |
| 3.3 | 未标记 public 的成员是内部实现 | `build/cc/Vtop.h` 第 38 至 44 行的注释 |
| 4.1 | `VL_DEBUG_IF` 的两种展开 | `verilated_types.h` 第 48 至 65 行 |
| 4.1 | `+verilator+debug` | man 页 `tools/verilator-5.052/share/man/man1/verilator.1` 第 343 行 |
| 4.1 | 未编入 `VL_DEBUG` 时的提示；调试打开的提示 | `verilated.cpp` 第 3830 至 3840 行 |
| 4.1 | 调试消息的前缀与输出通道 | `verilated.cpp` 第 365 至 379 行；`verilated.h` 第 422 行 |
| 4.2、4.3、4.4 | 轨迹全文 | `build/trace.txt` |
| 4.3 | 各行来源 | `Vtop.cpp` 第 60、64 至 75 行；`verilated.cpp` 第 4029、4056、4067 至 4079 行 |
| 4.3 | `eval_static` 记下此刻的 `a`、`b` | `build/tr/Vtop___024root__0__Slow.cpp` 第 7 至 14 行 |
| 4.3 | 第一次 ico 调用强制置 1 | `build/tr/Vtop___024root__0.cpp` 第 30 至 42 行 |
| 4.3 | Settle 区的内部位与函数体 | `build/tr/Vtop___024root__0__Slow.cpp` 第 27 至 56 行 |
| 4.3 | `dump_triggers` 内部调用 `trigger_anySet` | `build/switch/Vtop___024root__0__Slow.cpp` 第 143 至 158 行（教程实验目录） |
| 4.4 | 函数体只看第 0、1 位 | `build/tr/Vtop___024root__0.cpp` 第 53 行 |
| 4.4 | `final()` 调用 `eval_final` | `Vtop.cpp` 第 168 至 172 行 |
| 5.1 | chain 的真值表 | `build/ch/Vchain` 的输出 |
| 5.2 | 三条 `assign` 并成一条表达式，`t1`、`t2` 消失 | `build/ch/Vchain___024root__0.cpp` 第 56 至 58 行；`build/ch/Vchain___024root.h` 第 16 至 24 行 |
| 5.2 | 编译时按依赖排序 | 教程 8.1 节；指南 14.3 节 UNOPTFLAT（第 6227 至 6241 行） |
| 5.3 | `public` 拆出模块类、`public_flat` 留在根类 | `build/cp/Vchain_pub_chain_pub.h` 第 13 至 20 行、`Vchain_pub___024root.h` 第 17 行、`Vchain_pub.h` 第 44 行；`build/cf/Vchain_flat___024root.h` 第 20 行 |
| 5.3 | 变量上的 `public` 连带模块变成 public，否则用 `public_flat` | 指南 `/*verilator public*/ (on variable)` 一条（第 2600 至 2603 行） |
| 5.3 | `tb_pub`、`tb_flat` 读到 `t1=1 f=0`；`Vchain_pub.h` 只提前声明模块类 | `build/cp/Vchain_pub.h` 第 16 行 |
| 5.3 | `public_flat` 时先算 `t1` 后算 `f` | `build/cf/Vchain_flat___024root__0.cpp` 第 56、57、64、65 行 |
| 6.1 | 上限 50 时的报错与退出码 | `build/lp.txt` |
| 6.2 | 上限写进构造函数；默认 10000 | `build/lp/Vloop.cpp` 第 12 行；`build/cc/Vtop.cpp` 第 12 行；指南 13.1 节 `--converge-limit`（第 3370 至 3372 行） |
| 6.3 | 两个循环传入的区名；检查与报错 | `verilated.cpp` 第 4044 至 4052、4075 至 4077、4088 至 4091 行；`verilated.h` 第 408 至 411 行 |
| 6.3 | Settle 区的触发条件与函数体 | `build/lp/Vloop___024root__0__Slow.cpp` 第 28 至 73 行 |
| 7.1 | 两种写法的 `q` | `build/sq/Vseq` 的输出 |
| 7.2 | act 区判沿、NBA 区赋值、`d` 被代入 | `build/sq/Vseq___024root__0.cpp` 第 54 至 107 行 |
| 7.3 | 四段的区序列；S2 的 act 触发 | `build/seqtrace.txt` |
| 7.3 | `eval_ico`、`eval_stl` 无条件返回假 | `build/sq/Vseq___024root__0.cpp` 第 46 行；`build/sq/Vseq___024root__0__Slow.cpp` 第 40 行 |
| 7.3 | act 并入 NBA 触发位；NBA 执行后返回真 | `build/sq/Vseq___024root__0.cpp` 第 71、72、93 至 106 行 |
| 7.3 | NBA 循环包住 act、inact 循环 | `verilated.cpp` 第 4107 至 4122 行 |
| 7.4 | 同一时刻活动事件的顺序不确定；竞争 | IEEE 1800-2017 第 4.7、4.8 节（抽取文本 `E:\Workspace\Temp\ysyx-e4\src\1800-clause4.txt` 第 378 至 395 行） |
| 8.1 | NEEDTIMINGOPT 与 STMTDLY 的输出 | `build/d1.log`、`build/d2.log` |
| 8.1 | STMTDLY 只在 `--no-timing` 时报，不靠 `-Wall`；警告默认致命 | 指南 14.3 节 STMTDLY（第 6136 行）；指南 13.1 节 `-Wno-fatal`（第 4495 至 4498 行）；实测（不加 `-Wall` 也失败） |
| 8.1 | `--no-timing -Wno-STMTDLY` 的结果 | `build/d3.txt`；`build/d3/Vdly_classes.mk` 第 11 行 |
| 8.1 | 不给 timing 选项报 NEEDTIMINGOPT；`--no-timing` 忽略延迟并报 STMTDLY | 指南 10.2 节（第 2085、2086、2097 行）；指南 14.3 节（第 5760 至 5762、6129 至 6138 行） |
| 8.1 | `--binary` 等于 `--main --exe --build --timing` | 指南 13.1 节（第 3298、3299 行）；man 页第 109 行 |
| 8.1 | 运行输出与退出码 | lab 实测 |
| 8.1 | 默认时间单位 1ps | 指南 13.1 节 `--timescale`（第 4325 至 4327 行） |
| 8.2 | 生成的 `main()` 循环 | `build/d/Vdly__main.cpp` 第 19 至 36 行；指南 6.7 节（第 1231 至 1237 行） |
| 8.2 | 有延迟时的 `eventsPending`、`nextTimeSlot`；延迟调度器 | `build/d/Vdly.cpp` 第 149、151 行；`build/d/Vdly___024root.h` 第 24 行 |
| 8.3 | `initial` 编译成协程，`#10` 变成 `co_await` | `build/d/Vdly___024root__0.cpp` 第 132 至 143 行 |
| 8.3 | act 区恢复协程 | `build/d/Vdly___024root__0.cpp` 第 58、72、73 行 |
| 8.3 | `--timing` 需要支持协程的编译器 | 指南 13.1 节（第 4334 至 4339 行） |
| 8.3 | 链接 `verilated_timing.o`；`VM_TIMING = 1` | `build/d.log` 第 7 行；`build/d/Vdly_classes.mk` 第 11 行 |

`build/` 下的生成代码行号对应 Verilator 5.052；运行库源码路径相对于 `/toolchains/verilator-5052/share/verilator/include/`（Windows 侧是 `projects/ysyx/tools/verilator-5.052/share/verilator/include/`）。指南是在线版 5.054 的抽取文本，与 5.052 有出入的行为以实测为准。
