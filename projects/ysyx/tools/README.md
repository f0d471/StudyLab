# YSYX 专用环境工具

本目录属于 StudyLab/projects/ysyx。普通编译、仿真和工具源码构建经 Workspace/Tools/wsl-sandbox 的 ysyx 项目入口；系统包安装是 Linux root 的包管理例外。

- install-dependencies.sh：安装原 NEMU、Verilator 与 NVBoard 所需系统包；历史前后清单在项目 logs/dependencies/，本轮未重装。
- build-verilator.sh：按 Main/docs/sources.json 登记的源码提交构建。默认安装到项目 cache/toolchain-install/verilator-5.052，或显式设置 STUDYLAB_TOOLCHAIN_PREFIX；不覆盖已经只读共享的工具版本。构建验证后再由平台管理方登记共享位置。
- restore-native-link.ps1：在 Windows 按已有权限恢复 Main 的 RV64 相对目录链接；原始操作与模式验证见 Main/docs/开发环境.md，不用普通文本文件替代链接。
- mirror_docs.py：YSYX 与 PA 离线资料工具，输出保留在本项目 docs/，不把镜像当作自编资料发布。

现有已验证的 Verilator 5.052 保留在 tools/verilator-5.052，由平台注册为只读共享工具。日常环境检查从 Workspace 根目录执行 sandbox.ps1 -Action Run -Project ysyx -Command @('python3','-B','tools/first-run.py')。此 tools/first-run.py 指 Main 内的工具，因为默认 cwd 是 Main。

通用配置、挂载与隔离维护见 [平台工具](../../../../Tools/wsl-sandbox/README.md)。本目录的历史日志保持原文，旧路径按平台迁移记录定位。
