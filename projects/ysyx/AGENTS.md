# YSYX 项目规则

- ysyx-workbench/ 是官方框架建立的新工程，raw/ 两个旧仓仅供历史查阅；不把旧工程验收当成新 ysyx-workbench 完成。
- 从 Workspace 根目录使用 Tools/wsl-sandbox/sandbox.ps1 -Action Shell -Project ysyx；默认工作目录为 ysyx-workbench。编译、仿真、回归、调试和波形均在受限环境内进行。
- NEMU_HOME、AM_HOME、NPC_HOME、NVBOARD_HOME 等由本项目 project.json 注入；官方 tracer-ysyx 追踪机制及分支必须保留。
- 现有工具的旧安装前缀只在本项目沙箱内兼容映射；不依赖宿主 YSYX 目录运行。
- 专用工具与资料在本项目 tools/、docs/；历史日志在 logs/，工具源码与构建缓存在 cache/。历史记录保持原文，路径变化查平台迁移记录。
- 初始来源在 ysyx-workbench/docs/sources.json。ysyx-workbench 文档与新运行记录随路径适配更新，third-party 与 raw 不做格式重写。

- rt-thread-am/ 是讲义指定的独立依赖仓，与 ysyx-workbench/ 并列；保留自身 Git。AM_HOME 继续指向主工程 abstract-machine，运行时进入 ../rt-thread-am/bsp/abstract-machine，不重复初始化另一份 RTT。
- 实际进度只维护在项目 README；上游讲义、旧工程与候选实验不能计作本轮完成。

- docs/ 的新增、移动、刷新和 Git 收录遵循 docs/README.md；自编专题在 topics/，课程笔记按需归 notes/<章节编号>/。镜像工具只生成 offline-report.md 等资料产物，不覆盖手写 README；路径变化同步索引和引用。
