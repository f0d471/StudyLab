# 02 Verilator 命令行选项速查

    实验目录    labs/fundamentals/02-Verilator命令行选项速查/
    环境        沙箱 Ubuntu；Verilator 5.052 2026-09-05 rev 5.052-983a06a
    依据        man 页（5.052 版，tools/verilator-5.052/share/man/man1/verilator.1 的 ARGUMENT
                SUMMARY 节，共 259 行选项）；行为探针为本篇 labs 实测。在线指南是 5.054，
                与所装版本不一致时以 man 页与实测为准

**读前须知**：这是清单型篇目，供查不供读。每组开头一句"这组解决什么问题"，然后是表格。
表格里每个选项的作用按 man 页转述，选项名都存在于所装版本的
man 页。第 3 节的五条行为探针是实测，不是转述。想系统地走一遍选项怎么用，读教程
E/04 各章，本篇是它们背后的案头手册。

## 你会在哪里撞见它

1. 教程各章的命令行：--cc/--exe/--build/--top-module 的语义在教程第 01 章，本篇是全量
2. lint 报错要关某类警告、或要把某类升级为错误时，查第 2.4 组
3. 读别人的 Makefile（如 nvboard 的 example）时见到陌生选项，来对表

## 这篇要回答的问题

1. 所装版本的选项总表在哪，怎么查才不被在线文档的新版本带偏？
2. 各组选项分别管什么？
3. 几条容易拿不准的行为（默认致命、-Wno 的效力、--Mdir），实测是什么样？

## 1 怎么查本机的 man 页

所装 5.052 的完整选项总表在 man 页的 ARGUMENT SUMMARY 节，共 259 行，每行一个选项加
一句说明。两种读法：

1. 沙箱里 `man verilator`（分页阅读）
2. 直接读源文件 tools/verilator-5.052/share/man/man1/verilator.1。注意它是 roff 源码，
   连字符写成 `\-`（所以文件里是 `\-\-cc`），撇号写成 `\*(Aq`；把 `\-` 换回 `-` 就是
   干净的总表

在线指南（verilator.org/guide）跟随最新 release，写的是 5.054；两个 patch 之间选项
可能有增减。本篇一律按 5.052 的 man 页写。

## 2 选项分组总表

### 2.1 产物形态：让 Verilator 停在哪一步、产出什么

| 选项 | 作用 |
| --- | --- |
| `--cc` | 生成 C++ 输出 |
| `--sc` | 生成 SystemC 输出 |
| `--binary` | 连模型带可执行一步构建 |
| `--lint-only` | 只做 lint，不产出 |
| `--build` | 生成模型后接着构建可执行或库 |
| `--exe` | 链接生成可执行（配合提交给它的 C++ 文件） |
| `--main` | 自动生成 C++ 的 main() 文件 |
| `-o <executable>` | 最终可执行文件的名字 |
| `--Mdir <directory>` | 产物目录名（默认 obj_dir） |
| `-j <jobs>` | 构建并行度（管 --build-jobs 与 --verilate-jobs） |
| `--build-jobs <jobs>` | 本地编译阶段的并行度 |
| `--verilate-jobs` | Verilation（生成模型）阶段的并行度 |

### 2.2 顶层与端口

| 选项 | 作用 |
| --- | --- |
| `--top-module <topname>` | 指定顶层模块名 |
| `--top <topname>` | --top-module 的别名 |
| `--pins-bv <bits>` | 指定顶层端口在 C++ 侧的类型上限（端口类型见 fundamentals/01） |

### 2.3 预处理与编译传参

| 选项 | 作用 |
| --- | --- |
| `-D<var>[=<value>]` | 定义预处理宏 |
| `-I<dir>` | 头文件搜索目录 |
| `-CFLAGS <flags>` | 传给 C++ 编译器的参数（进生成的 makefile） |
| `-LDFLAGS <flags>` | 传给链接器的参数 |
| `-E` | 只做预处理，不编译 |

### 2.4 lint 与警告

| 选项 | 作用 |
| --- | --- |
| `-Wall` | 打开全部风格类警告 |
| `-Wno-<message>` | 关闭一类警告 |
| `-Werror-<message>` | 把一类警告升级为错误 |
| `-Wwarn-<message>` | 打开指定的一类警告 |
| `-Wfuture-<message>` | 未知警告名的处理（跨版本兼容用） |
| `-Wno-fatal` | 警告不再致命（照常生成） |
| `-Wno-lint` | 关闭全部 lint 类警告 |
| `-Wno-style` | 关闭全部风格类警告 |

警告默认致命（不走 -Wno-fatal 就因警告失败）。逐条警告的成因查在线指南的 Errors and
Warnings 章（按 5.054 写，多数条目两版一致；敏感条目以实测为准）。

### 2.5 波形

| 选项 | 作用 |
| --- | --- |
| `--trace` | 生成 VCD 波形 |
| `--trace-vcd` | 生成 VCD 波形（显式写法） |
| `--trace-fst` | 生成 FST 波形 |
| `--trace-depth <levels>` | 记录的层次深度 |
| `--trace-max-array <depth>` | 记录数组的最大深度 |
| `--trace-max-width <width>` | 记录信号的最大位宽 |
| `--trace-params` | 记录参数 |
| `--trace-underscore` | 记录下划线开头的信号 |
| `--trace-structs` | 记录结构体名 |
| `--trace-saif` | 生成 SAIF 文件 |
| `--trace-coverage` | 记录覆盖率相关信号 |

### 2.6 时序与断言

| 选项 | 作用 |
| --- | --- |
| `--timing` | 打开延迟（#）支持 |
| `--no-timing` | 关闭延迟支持 |
| `--no-assert` | 关闭全部断言（断言默认启用） |
| `--no-assert-case` | 关闭 unique/priority-case 断言 |
| `--assert-unroll-limit <iter>` | SVA 断言重复次数上限 |
| `--autoflush` | 每次 $display 后刷新流缓冲 |

### 2.7 x 值（两态模型怎么安放未初始化）

| 选项 | 作用 |
| --- | --- |
| `--x-initial <mode>` | 初始 x 的取值策略 |
| `--x-assign <mode>` | 运行中 x 赋值的取值策略 |
| `--x-initial-edge` | 允许初始 x 到 0/1 的跳变当边沿 |

### 2.8 覆盖率

`--coverage` 打开全部；分项有 `--coverage-line`、`--coverage-expr`、`--coverage-fsm`、
`--coverage-toggle` 等。展开见 [fundamentals/07](07-验证方法学总览.md) 第 2 节。

### 2.9 公开信号（给外部访问内部状态用）

| 选项 | 作用 |
| --- | --- |
| `--public` | 把信号标为 public |
| `--public-depth <level>` | public 到指定模块深度 |
| `--public-flat-rw` | 全部变量按 public_flat_rw 标注 |
| `--public-params` | 全部参数按 public 标注 |
| `--public-ignore` | 忽略代码里的 public 标注 |

DiffTest 要从 C++ 侧读寄存器堆时用到这一组（教程后段再见）。

### 2.10 杂项常用

| 选项 | 作用 |
| --- | --- |
| `--quiet` | 最小化附加打印 |
| `--quiet-build` | 不打印构建进度 |
| `--stats` | 生成统计文件 |
| `--threads <threads>` | 模型多线程 |
| `--converge-limit <loops>` | 组合收敛上限（默认 10000，见 fundamentals/01） |
| `--help` | 打印帮助 |
| `--version` | 打印版本 |

## 3 行为探针（实测）

总表只保证"选项存在"。这五条把容易拿不准的行为实测一遍，命令与退出码出自本篇 labs
实测（2026-11-14）。

1. `verilator --lint-only good.v`：无警告的模块，退出码 0，无警告输出
2. `verilator --lint-only badw.v`：把 4 位信号赋给 3 位，默认就触发 WIDTHTRUNC 警告，
   且警告致命，退出码 1（不用 -Wall，WIDTH 类默认打开）
3. `verilator --lint-only -Wno-WIDTHTRUNC badw.v`：关闭这一类后退出码 0
4. `verilator --cc --Mdir 指定目录 good.v`：模型产物出现在指定目录（Vgood.h 等三个文件）
5. `verilator --cc --trace-fst --Mdir 指定目录 good.v`：--trace-fst 被接受且不影响生成，
   退出码 0

## 依据

| 正文说法 | 依据 |
| --- | --- |
| 259 行选项总表、各选项作用 | 5.052 man 页 ARGUMENT SUMMARY 节 |
| 警告默认致命 | 探针 2 实测退出码 1；生产指南坑 7（DECLFILENAME 一节）同结论 |
| WIDTHTRUNC 默认打开 | 探针 2 实测（未加 -Wall） |
| -Wno-<message> 关闭单类 | 探针 3 实测退出码 0 |
| --Mdir、--trace-fst 行为 | 探针 4、5 实测 |
| 端口类型随 --pins-bv | man 页该行；类型展开见 fundamentals/01 第 2 节 |
| 覆盖率分项 | man 页；展开见 fundamentals/07 第 2 节 |
