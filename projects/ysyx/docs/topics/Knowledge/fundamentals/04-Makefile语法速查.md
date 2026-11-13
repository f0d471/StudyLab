# 04 Makefile 语法速查

    实验    npc/Makefile 的 sim 规则（批 2 实做）
    依据    GNU make 手册（https://www.gnu.org/software/make/manual/）；
            本仓实件：ysyx-workbench/Makefile 与 npc/Makefile。教程引用处：tutorials/E/04 2.2 节

这一篇是清单型篇目：主线用到的 make 语法一次登记。例句全部取自 ysyx-workbench 里真实存在的文件，学完能逐行读懂 npc/Makefile 和根 Makefile 的 git_commit 机制。

## 你会在哪里撞见它

- 批 2：把仿真命令写进 npc/Makefile 的 sim 规则
- 红线 1：`$(call git_commit, "sim RTL")` 为什么不能动——读懂本篇第 6 节就明白它背后是整套 tracer 机制
- Embedded-linux 线的 Makefile 与本篇同一套语法，互相印证

## 这篇要回答的问题

1. 规则的完整形态是什么？TAB 和空格差在哪？
2. 变量赋值 =、:=、?=、+= 各是什么展开时机？
3. $(call ...) 和 define 多行变量怎么配合？git_commit 那一行到底做了什么？

## 1 规则

```makefile
目标: 依赖
<TAB>命令
```

- 命令行必须以 TAB 开头，空格不行（make 报 "missing separator" 的头号来源）
- make 的工作循环：目标是过时（不存在或依赖比它新）就执行命令；依赖又是别的目标就先递归
- 命令前加 `@` 不回显命令本身；加 `-` 该行失败不中断

## 2 变量

| 写法 | 含义 | 例子 |
| --- | --- | --- |
| `A = x` | 递归展开：用到 A 时才替换当时值 | 递归引用不死循环但易踩坑 |
| `A := x` | 立即展开：赋值行当场求值 | 行为最像直觉，优先用 |
| `A ?= x` | 未定义才赋值 | 默认值惯用 |
| `A += x` | 追加 | 拼列表（如源文件清单） |

引用 `$(A)` 或 `${A}`。

## 3 自动变量与常用函数

| 写法 | 含义 |
| --- | --- |
| `$@` | 当前规则的目标名 |
| `$<` | 第一个依赖 |
| `$^` | 全部依赖（去重） |
| `$(shell 命令)` | 执行 shell 命令取其输出（根 Makefile 取当前分支名即用它） |
| `$(call 名,参数...)` | 把 define 多行变量当函数调用，参数进 $(1) $(2) |
| `$(wildcard *.c)` | 通配展开文件清单 |

## 4 include 与 .PHONY

- `include ../Makefile`：把另一份 Makefile 原地并入（npc/Makefile 第 7 行——git_commit 宏从根文件来）
- `.PHONY: all sim`：声明"这些目标不是文件"。不加的话，目录里恰好有同名文件时 make 会认为目标已是最新的而不执行——sim、all 这类动作型目标必须声明

## 5 本仓实件逐段读：npc/Makefile

```makefile
all:
	@echo "Write this Makefile by your self."

sim:
	$(call git_commit, "sim RTL") # DO NOT REMOVE THIS LINE!!!
	@echo "Write this Makefile by your self."

include ../Makefile
```

- sim 规则下第一行：调用根 Makefile 的 git_commit 宏，参数 "sim RTL" 是这次追踪的提交说明。批 2 把真仿真命令加在它下面（红线：这行留在 sim 规则内不动）

## 6 git_commit 宏解剖（红线为什么不能动）

根 Makefile 里的定义（摘主干）：

```makefile
define git_commit
	-@flock $(LOCK_DIR) $(MAKE) -C $(YSYX_HOME) .git_commit MSG='$(1)'
	-@sync $(LOCK_DIR)
endef
```

展开后的 .git_commit 目标（根 Makefile，逐行）：

1. 等 .git/index.lock 释放（防止和其他 git 操作互踩）
2. 建/复用 tracer-ysyx 分支
3. 备份当前 git index；detach 切到 tracer 分支
4. `git add . -A --ignore-errors`——把工作区全部改动（含 npc 里新写的代码）收进暂存
5. 以固定作者（tracer-ysyx）提交，提交说明含 MSG（"sim RTL"）、学号、机器信息
6. 切回原工作分支并还原 index

这就是"原创性追踪"：每次仿真都自动在 tracer 分支留一条带时间线的记录，证明工作过程。两处推论：1) 这行删了或改了，追踪就断，断点无法补录（红线 1 的真实后果）；2) 波形等大文件不能落进 npc 目录，否则每次 sim 都被收进 tracer 提交（纪律见 tutorials/E/04 2.1 节）。

## 7 惯用骨架（批 2 写 sim 规则的模板）

```makefile
.PHONY: sim
sim:
	$(call git_commit, "sim RTL") # DO NOT REMOVE THIS LINE!!!
	verilator --cc --exe --build --top-module top vsrc/top.v csrc/main.cpp
```

具体命令形态以批 2 实测为准（产物位置、-j 并行度、波形选项都可能要加）。
