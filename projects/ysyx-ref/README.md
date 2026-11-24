# ysyx-ref：讲义任务线的参考工程

本目录是沙箱项目 ysyx-ref，存放讲义任务线使用的参考工程 ysyx-workbench-ref。参考工程由 AI 按讲义要求直接搭建。它和 `projects/ysyx` 里的正式工程是两份独立的仓库：正式工程由用户亲手实现，本项目不向它写入任何内容。约定与任务清单见[学习与项目路线](../ysyx/docs/topics/Engineering/Todo/学习与项目路线.md) 的「讲义任务线」一节。

## 项目文件

| 项 | 值 |
| --- | --- |
| 状态 | 环境已建并通过验证，讲义任务未开工 |
| 建立 | 2026-11-24 |
| 来源 | 正式工程 ysyx-workbench 的 master 分支，提交 0e7bd5b |
| 入口 | Tools/wsl-sandbox/sandbox.ps1 -Action Shell -Project ysyx-ref |
| 工程位置 | ysyx-workbench-ref/，沙箱内为 /workspace/ysyx-workbench-ref |

## 要解决什么

讲义要求落实到 ysyx-workbench 的内容有两类：让仿真、板卡和测试跑起来的管线，以及讲义写着"实现 X"的设计任务。本工程由 AI 把两类任务按讲义顺序各做一遍，用来提前排除管线风险，提供不依赖被测程序的判据，并在用户完成自己的实现之后作为对照。

## 前置条件

1. 平台卷已挂载，`sandbox.ps1 -Action Doctor -Project ysyx-ref` 通过。
2. Verilator 5.052 由平台只读共享，位置是 `/toolchains/verilator-5052`，已加入 PATH。其余工具是 WSL 系统包：git 2.53.0、GNU Make 4.4.1、g++ 15.2.0、Python 3.14、GTKWave、Icarus Verilog、OpenJDK 17。
3. 环境变量 YSYX_HOME、NEMU_HOME、AM_HOME、NPC_HOME、NVBOARD_HOME 由 project.json 注入，全部指向 `/workspace/ysyx-workbench-ref` 下的对应目录。
4. 沙箱默认不通网。需要新依赖时先从正式工程离线复制；确需联网时显式加 `-Network`。

## 来源版本

| 部件 | 来源 | 提交 |
| --- | --- | --- |
| ysyx-workbench-ref | 本地克隆 projects/ysyx/ysyx-workbench 的 master，对象独立复制，克隆后删除 remote | 0e7bd5b |
| nvboard | 本地克隆正式工程内的 NVBoard 仓库，克隆后删除 remote | b5f49b6 |
| nemu/tools/capstone/repo | 原样复制正式工程内的上游 Capstone 及其编译产物；该目录被 NEMU 的 .gitignore 挡在主仓之外 | 5.0.6（accf4df） |

## 已验证范围（2026-11-24）

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| Doctor | 通过，工作目录为 ysyx-workbench-ref | 命令只打印不落盘 |
| 项目内探查 | STUDYLAB_PROJECT 为 ysyx-ref；默认目录与环境变量全部指向 -ref 路径；git、make、g++、python3、verilator、gtkwave、iverilog 在位 | logs/ysyx-ref/studylab-ysyx-ref-20261124T153228-9b5853bb.json |
| bash init.sh npc | NPC_HOME 写入本项目 HOME 的 .bashrc | 同上 |
| NEMU 内置镜像 | HIT GOOD TRAP，4 条指令 | studylab-ysyx-ref-20261124T153938-3355035e |
| Verilator 官方示例 | 构建成功，输出 Hello World! | studylab-ysyx-ref-20261124T154155-7a5424df |
| NVBoard 上游示例 | 构建成功，Verilator 报告 8 个模块；无界面运行到 280 秒时限后被终止，日志无报错 | studylab-ysyx-ref-20261124T154300-d3c6887b；完整输出在 cache/nvboard-example.log |
| 追踪机制 | 参考工程的 tracer-ysyx 分支新增 4 条记录：compile NEMU 两条，run NEMU 一条，sim RTL 一条 | studylab-ysyx-ref-20261124T154918-248dd708 及此前两条 |
| 参考工程起点 | master 仍为 0e7bd5b，工作区干净，没有 remote；4 条追踪记录的内容树与 master 相同 | Windows 侧 git status 与 git log |

正式工程在操作前后的对照值相同：master 为 0e7bd5b，tracer-ysyx 为 a02ec5a，未提交改动 5 行。参考工程整体占 136 MiB，其中 Capstone 约 123 MiB。

## 未完成与已知限制

1. 讲义任务未开工。npc 仍是官方的空模块与 Hello 示例。
2. 图形界面未验证。NVBoard 与 GTKWave 需要加 -Gui 另行确认。
3. Chisel 工具链未安装。沙箱有 OpenJDK 17，没有 mill、coursier、scala，要到联网模式下安装。
4. nemu/src/isa/riscv64 在本工程是普通文件，内容为 riscv32。正式工程里它是指向 riscv32 的符号链接，创建符号链接需要管理员权限，本轮没有做。默认构建用 riscv32，不受影响；启用 RV64 之前要恢复链接。
5. tools/first-run.py 的 Verilator 部分写死了 ysyx 项目的工具链路径 /workspace/tools/verilator-5.052，在本项目只能用 --component nemu。Verilator 官方示例本轮用同等命令手动跑通。
6. 复制 Capstone 时，tests/libcapstone.so 原本是符号链接，在本工程是普通文件副本。NEMU 链接的是 repo/libcapstone.so.5，不受影响。
7. NVBoard 示例被 timeout 终止后，返回值这次是 0 而不是 124，原因没有查。
8. 工程没有 remote，未做异地备份。
9. fceux-am、navy-apps 等其余讲义依赖尚未初始化，到用到的阶段再处理。
