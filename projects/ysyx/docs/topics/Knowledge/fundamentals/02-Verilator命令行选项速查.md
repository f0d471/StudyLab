# 02 Verilator 命令行选项速查

    实验    批 1~3 的 verilator 命令实跑（labs/E/01~03 回填实测）
    依据    Verilator User Guide："Executable and Argument Reference"章与"Errors and Warnings"章
            （在线 5.054；版本裁定向 man verilator）。教程引用处：tutorials/E/04 1.7、2.2、3.3 节

这一篇是清单型篇目：Verilator 选项上百个，全背不现实，用到哪组查哪组。每组先给要解决的问题，再给选项清单。标注规则："批 N 实测"是本机跑过的；"guide"是按手册登记的。清单中警告类别的成因以手册 Errors and Warnings 章节为准，在线版 5.054 与沙箱 5.052 个别新增警告可能有差，版本敏感处查 man。

## 你会在哪里撞见它

- tutorials/E/04 1.7 节的仿真命令：--cc/--exe/--build/--top-module
- 批 2 写 npc/Makefile 的 sim 规则：同一串命令进 Makefile
- 批 3 的 lint：--lint-only -Wall 与 -Wno-<MSG>

## 这篇要回答的问题

1. 让 Verilator 只检查不生成、或生成并编译，各停在哪个开关上？
2. 波形（VCD/FST）分别怎么开？
3. 警告体系：全部打开、按类关闭、按类升级为错误，各用什么选项？常见警告类别有哪些？

## 0 先查三条

| 你要解决 | 去第几节 |
| --- | --- |
| 仿真命令的骨架选项 | 1 |
| 输出目录、产物名、并行编译 | 2 |
| 生成波形（VCD/FST） | 3 |
| lint 与警告（打开/关闭/查含义） | 4 |
| 两态初值与未初始化策略 | 5 |

## 1 仿真命令骨架

| 选项 | 作用 | 依据 |
| --- | --- | --- |
| `--cc` | 生成 C++ 模型（相对 SystemC 的 --sc） | guide |
| `--exe` | 把随后的 C/C++ 文件作为 main 链接进模型 | guide |
| `--build` | 生成模型后自动调用编译，产出可执行文件 | guide |
| `--top-module <名>` | 指定顶层模块；多顶层必须写，单顶层建议显式写 | guide |
| `-j <N>` | 本地编译并行度 | guide |
| `-o <名>` | 可执行文件改名（默认 V+顶层模块名） | guide |
| `-CFLAGS '<串>'` | 传给 g++ 的编译选项 | guide |
| `-LDFLAGS '<串>'` | 传给链接的选项（接 NVBoard 库时用） | guide |
| `-I<目录> -L<目录> -l<库>` | 头文件/库路径与库名的惯用转发 | guide |

典型组合（批 1）：`verilator --cc --exe --build --top-module top vsrc/top.v csrc/main.cpp`；批 3 接 NVBoard 时加 `-CFLAGS/-LDFLAGS` 指向 nvboard 库（具体串以 nvboard.mk 实读为准）。

## 2 输出控制

| 选项 | 作用 | 依据 |
| --- | --- | --- |
| `--Mdir <目录>` | 模型产物目录（默认 obj_dir） | guide |
| `--lint-only` | 只检查不生成模型（lint 模式） | guide |
| `--dump-tree` | 把优化后的 AST 打成文本（调试 Verilator 本身时用，主线不需要） | guide |

## 3 波形

| 选项/动作 | 位置 | 作用 |
| --- | --- | --- |
| `--trace` | 编译期 | 开 VCD 波形支持 |
| `--trace-fst` | 编译期 | 开 FST 波形支持（推荐，体积约 VCD 的 1/50，讲义经验值） |
| `Verilated::traceEverOn(true);` | 运行期 main 里 | 打开运行时 tracing |
| trace 对象 `trace(top, 99, "文件名")` | 运行期 | 绑定模型与波形文件；99=层次深度上限 |
| `dump(...)` | 运行期每拍 | 把当前各信号值写进波形 |

三步的完整代码见 05-波形格式与GTKWave；纪律：波形文件只写 /tmp（tutorials/E/04 2.1 节）。

## 4 lint 与警告

| 选项 | 作用 | 依据 |
| --- | --- | --- |
| `--lint-only` | 只检查，出警告不生成模型 | guide |
| `-Wall` | 打开全部检查类别（含风格类） | guide |
| `-Wno-<MSG>` | 关闭单个警告类别（风格类且确认不影响逻辑才用，讲义例 DECLFILENAME） | guide |
| `-Wwarn-<MSG>` | 把该类降级为普通警告 | guide |
| `-Werror-<MSG>` | 把该类升级为错误（关键逻辑类可这样钉死） | guide |

常见警告类别速查（成因以手册 Errors and Warnings 对应条目为准，先查章节再动手）：

| 类别 | 一句话成因 |
| --- | --- |
| WIDTH / WIDTHEXPAND / WIDTHTRUNC | 赋值或连线两侧位宽不等（截断/扩展） |
| PINMISSING | 实例化端口没接全 |
| IMPLICIT | 隐式声明 1 位 wire（没声明就用的信号名） |
| DECLFILENAME | 文件名与模块名不一致 |
| UNDRIVEN | 有声明无驱动的信号 |
| UNUSED | 有定义无使用的信号 |
| MULTIDRIVEN | 一根信号多处驱动 |
| LATCH | 行为建模推出了锁存器（规范红线 3 的信号） |
| CASEINCOMPLETE | case 分支没覆盖全且无 default |
| COMBDLY | 组合逻辑里用了非阻塞赋值 |
| BLKSEQ | 时序块里用阻塞赋值（模板体系下少见） |
| ALWCOMBORDER | always_comb 里的顺序问题 |

注错见红（批 3 判据）：故意留未驱动信号，UNDRIVEN 必须出现。

## 5 两态初值

| 选项 | 作用 | 依据 |
| --- | --- | --- |
| `--x-initial <策略>` | 未初始化变量的初值策略（unique=尽量随机以暴露未复位；allN/0 等） | guide |
| `--x-assign <策略>` | 对模型内 x 赋值的处理策略 | guide |

主线用法：不复位的 bug 要靠 unique 的随机初值暴露——这也是"时序电路必须先复位"（教程 3.2 节 reset(10)）的机制级理由。两态四态总述见 00-仿真器的两种范式与工具谱系。
