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

更新：2026-11-16。

- 主工程仍是课程初始工程；NEMU 已实现的指令为 auipc、lbu、sb、ebreak，NPC 仍为空模块和 Hello 示例。
- 改名后通过平台 Doctor；Windows PowerShell 5.1 入口完成 NEMU 四指令 GOOD TRAP 和 Verilator 官方示例检查，PowerShell 7 入口完成 NVBoard 5 秒图形启动。证据集中登记在 logs/workbench-rename.json。
- RT-Thread 已完成克隆、Git 连通性与干净状态核对；本轮未新增依赖（环境已有 scons）；未执行 make init、未编译或运行。context.c 中课程要求填写的断言占位保留。
- 2026-10-19：建立二周目学习记录结构——docs/topics/ 下 Engineering（Todo / Bugs / TechReports）与 Knowledge（tutorials / fundamentals / labs），总路线在 Engineering/Todo/学习与项目路线.md；RISC-V 官方手册（合并版 riscv-spec.pdf）已下载到 docs/sources/riscv/ 并登记来源。主线尚未开课。
- E4（仿真与验证）：批 0 环境四查完成（2026-11-12，记录在 docs/topics/Knowledge/labs/E/04-仿真与验证/00-环境四查.md）。批 1 资产定稿（2026-11-13）：教程第 01 章「Verilator 把电路变成程序」check.sh 82 PASS / 0 FAIL / 0 SKIP、mutate.sh 25 OK / 0 BAD；fundamentals 03「Verilator 模型与 eval」check.sh 91 PASS / 0 FAIL / 0 SKIP、mutate.sh 16 OK / 0 BAD。批 1 的学习检验未做，npc 里的双控开关与 testbench 未写。
- E4 资产线 2026-11-14 批量推进：教程第 02 章（波形一键仿真与另一种仿真器，check 13 / 0、mutate 10 OK）、第 03 章（接入NVBoard流水灯与静态检查，check 20 / 0、mutate 11 OK）、第 04 章（描述电路的纪律与两个模板，check 6 / 0、mutate 7 OK）；fundamentals 01（11 / 0、7 OK）、04（17 / 0、6 OK）、02（6 / 0、5 OK）、05（12 / 0、9 OK）、06（地图型引用核对制，21 / 0、6 OK）。旧整篇教程与全部素材稿已删除，RTL 仿真段资产齐备。
- E4 资产线 2026-11-16 收官：七篇新资产全部走完独立审稿并修复（每篇由未参与写作的审稿子代理交问题单，共 89 项发现全部逐条处理；修复涉及的判据改动已复跑，t04 的 LATCH 无 -Wall 判据改为真实无 -Wall 实跑、fundamentals 06 的 Accellera 判据补"未能核对"条件，复跑后基线不变），七篇在 tutorials/fundamentals README 改标"定稿 2026-11-16"。同日完成章内 apparatus 清除（验证装置只在 labs，章内零判据清单与注错说明；labs 判据与基线未动）与结构重排（教程四章尾节裁撤；fundamentals 分主题目录重编号 01~06，labs 同步迁移）。全部八篇 check.sh 复跑全绿、数字与登记一致。
- E4 学习线 2026-11-16 开课推进：教程第 01 章按渐退制逐段对话带做，C++ 零基础第一课（类与对象、new、指针）自测全过；2.1 收货全对，2.2 示范段对账完成，接续点为 touch our.v 对照实验收货后进 2.3。三类检验与 npc 内独立复现未开始。详见 E4 spec 第九节日志。
- 完整 CPU、NPC 差分链路、操作系统和后续课程单元尚未完成；旧工程的验收不能计入本工程进度。

## 日常入口

从 Workspace 根目录执行：

```powershell
& .\Tools\wsl-sandbox\sandbox.ps1 -Action Shell -Project ysyx
```

默认进入 /workspace/ysyx-workbench，AM_HOME 等由 project.json 注入。RTT 适配目录位于 ../rt-thread-am/bsp/abstract-machine；编译、仿真、调试均在该隔离环境中进行。

现行环境见 [平台开发环境](../../docs/通用学习平台.md)，交互用法见 [日常实验](ysyx-workbench/docs/日常实验.md)，初始化历史见 [主工程开发环境](ysyx-workbench/docs/开发环境.md)。当前运行日志由平台写入 StudyLab/logs/ysyx/；迁移前的项目 logs/ 保留原文。
