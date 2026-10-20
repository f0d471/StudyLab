# YSYX 学习项目

本目录是 StudyLab 中的 RISC-V、组成原理与体系结构学习项目。主工程沿官方 OSCPU/ysyx-workbench 框架推进，二周目以讲义主线为准；资料结构与维护标准见 [docs README](docs/README.md)，学习记录（教程/基础/实验/工程文档）的组织见 [topics README](docs/topics/README.md)。

## 工程与资料

| 位置 | 用途 |
| --- | --- |
| ysyx-workbench/ | 新主工程；原 Main 于 2026-10-16 原地改名，保留 Git 与 tracer-ysyx |
| rt-thread-am/ | 讲义指定的 NJU-ProjectN/rt-thread-am，master 分支；与主工程并列的独立 Git 仓 |
| raw/ | 两份旧工程与原有历史，供查阅与复盘 |
| docs/ | 离线讲义、学习记录（topics/ 下的 Engineering 与 Knowledge）、来源登记与资料核对记录；入口见 [资料目录](docs/README.md) |
| tools/、cache/、logs/ | 专用工具、源码与构建缓存、迁移前原始证据 |

RT-Thread 来源与版本集中登记在 [rt-thread-source.json](docs/rt-thread-source.json)。主工程初始来源见 [sources.json](ysyx-workbench/docs/sources.json)。独立 RTT 源码由自身 Git 管理，不纳入平台仓；无需再次运行主工程 init.sh 的 rt-thread 子命令。

## 当前进度

更新：2026-10-19。

- 主工程仍是课程初始工程；NEMU 已实现的指令为 auipc、lbu、sb、ebreak，NPC 仍为空模块和 Hello 示例。
- 改名后通过平台 Doctor；Windows PowerShell 5.1 入口完成 NEMU 四指令 GOOD TRAP 和 Verilator 官方示例检查，PowerShell 7 入口完成 NVBoard 5 秒图形启动。证据集中登记在 logs/workbench-rename.json。
- RT-Thread 已完成克隆、Git 连通性与干净状态核对；本轮未新增依赖（环境已有 scons）；未执行 make init、未编译或运行。context.c 中课程要求填写的断言占位保留。
- 2026-10-19：建立二周目学习记录结构——docs/topics/ 下 Engineering（Todo / Bugs / TechReports）与 Knowledge（tutorials / fundamentals / labs），总路线在 Engineering/Todo/学习与项目路线.md；RISC-V 官方手册（合并版 riscv-spec.pdf）已下载到 docs/sources/riscv/ 并登记来源。主线尚未开课。
- 完整 CPU、NPC 差分链路、操作系统和后续课程单元尚未完成；旧工程的验收不能计入本工程进度。

## 日常入口

从 Workspace 根目录执行：

```powershell
& .\Tools\wsl-sandbox\sandbox.ps1 -Action Shell -Project ysyx
```

默认进入 /workspace/ysyx-workbench，AM_HOME 等由 project.json 注入。RTT 适配目录位于 ../rt-thread-am/bsp/abstract-machine；编译、仿真、调试均在该隔离环境中进行。

现行环境见 [平台开发环境](../../docs/通用学习平台.md)，交互用法见 [日常实验](ysyx-workbench/docs/日常实验.md)，初始化历史见 [主工程开发环境](ysyx-workbench/docs/开发环境.md)。当前运行日志由平台写入 StudyLab/logs/ysyx/；迁移前的项目 logs/ 保留原文。
