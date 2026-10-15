# YSYX 学习项目

本目录是 StudyLab 中的 RISC-V、组成原理与体系结构学习项目，源码来自官方 OSCPU/ysyx-workbench。Main/ 为新工程，raw/ 保留两个旧仓库与原有历史；docs/ 保存讲义镜像和 [体系结构专题](docs/体系结构专题.md)。

从 Workspace 根目录使用 Tools/wsl-sandbox/sandbox.ps1 -Action Shell -Project ysyx，默认进入 Main。环境与当前验证范围见 [平台开发环境](../../docs/开发环境.md)，历史初始化来源和证据见 [Main 开发环境](Main/docs/开发环境.md)。

Main 当前仍是课程初始工程；环境示例通过不代表完整 CPU、差分测试、OS 或后续实验完成。旧证据在 logs/，工具与源码缓存分别在 tools/、cache/；当前运行记录由平台写到 logs/ysyx/。
