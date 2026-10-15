# YSYX 项目规则

- Main/ 是官方框架建立的新工程，raw/ 两个旧仓仅供历史查阅；不把旧工程验收当成新 Main 完成。
- 从 Workspace 根目录使用 Tools/wsl-sandbox/sandbox.ps1 -Action Shell -Project ysyx；默认工作目录为 Main。编译、仿真、回归、调试和波形均在受限环境内进行。
- NEMU_HOME、AM_HOME、NPC_HOME、NVBOARD_HOME 等由本项目 project.json 注入；官方 tracer-ysyx 追踪机制及分支必须保留。
- 现有工具的旧安装前缀只在本项目沙箱内兼容映射；不依赖宿主 YSYX 目录运行。
- 专用工具与资料在本项目 tools/、docs/；历史日志在 logs/，工具源码与构建缓存在 cache/。历史记录保持原文，路径变化查平台迁移记录。
- 初始来源在 Main/docs/sources.json。Main 文档与新运行记录随路径适配更新，third-party 与 raw 不做格式重写。
