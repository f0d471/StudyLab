# YSYX 专用环境工具

本目录属于 StudyLab/projects/ysyx。普通编译、仿真和工具源码构建经 Workspace/Tools/wsl-sandbox 的 ysyx 项目入口；系统包安装是 Linux root 的包管理例外。

- install-dependencies.sh：安装原 NEMU、Verilator 与 NVBoard 所需系统包；历史前后清单在项目 logs/dependencies/，本轮未重装。
- build-verilator.sh：按 ysyx-workbench/docs/sources.json 登记的源码提交构建。默认安装到项目 cache/toolchain-install/verilator-5.052，或显式设置 STUDYLAB_TOOLCHAIN_PREFIX；不覆盖已经只读共享的工具版本。构建验证后再由平台管理方登记共享位置。
- restore-native-link.ps1：在 Windows 按已有权限恢复 ysyx-workbench 的 RV64 相对目录链接；原始操作与模式验证见 ysyx-workbench/docs/开发环境.md，不用普通文本文件替代链接。
- mirror_docs.py：YSYX 与 PA 离线资料工具，输出保留在本项目 docs/；可读结果写入 offline-report.md，保留手写 README.md。结构与管理见 [资料目录说明](../docs/README.md)。

现有已验证的 Verilator 5.052 保留在 tools/verilator-5.052，由平台注册为只读共享工具。日常环境检查从 Workspace 根目录执行 sandbox.ps1 -Action Run -Project ysyx -Command @('python3','-B','tools/first-run.py')。此 tools/first-run.py 指 ysyx-workbench 内的工具，因为默认 cwd 是 ysyx-workbench。

通用配置、挂载与隔离维护见 [平台工具](../../../../Tools/wsl-sandbox/README.md)。本目录的历史日志保持原文，旧路径按平台迁移记录定位。

## 离线资料维护

从 Workspace 根目录调用以下入口，默认输出为本项目 docs/。

仅核对已有资料，不下载：

~~~powershell
& .\Tools\wsl-sandbox\sandbox.ps1 -Action Run -Project ysyx -Command @('python3', '-B', '../tools/mirror_docs.py', '--verify-only')
~~~

按现有清单继续抓取，需要联网：

~~~powershell
& .\Tools\wsl-sandbox\sandbox.ps1 -Action Run -Project ysyx -Network -Command @('python3', '-B', '../tools/mirror_docs.py')
~~~

--refresh 重新获取上游内容；--retry-failed 重试失败请求；--render-only 从已保存原始内容重生成网页。清单和核对结果由工具维护，课程进度仍在项目 README。人工笔记、专题和配图不写入镜像生成目录。
