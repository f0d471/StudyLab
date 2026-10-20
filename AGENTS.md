# StudyLab 平台规则

- 本目录是有容量上限的虚拟卷挂载入口，不能按普通目录递归删除或移动；只处理核对过的具体子目录，不遍历重解析点。
- projects/ 下各项目并列，ysyx-workbench、YSYX、NEMU 等名称不作为其他课程的隐含约定。当前项目与接入状态见 docs/通用学习平台.md。
- Windows 编辑与日常 Git；项目的编译、仿真、调试、课程实验与波形查看必须经 ../Tools/wsl-sandbox/sandbox.ps1 或等价 run.sh。不得退回普通 WSL 运行。
- 使用 -Project 选择项目；默认 ysyx。联网、GUI、GPU 需要项目描述声明并显式启用。平台资源总池由 profiles/studylab.json 管理，不按项目数扩大。
- 项目只写自身目录、HOME、缓存和临时盘；共享输入和工具只读。跨项目结果用明确版本与输入声明引用，不复制另一份真源。
- 系统包管理可在 WSL 沙箱外由 root 安装；源码构建、工具验证与课程运行仍走隔离入口。依赖按项目固定，避免全局 CFLAGS、工具链和 Python 包相互污染。
- 项目登记的唯一入口是 platform/projects.json，运行参数在项目 project.json；学习进度在该项目 README/STATUS，禁止重复维护。
- 课程可以保留简化实现与负向结果；完成范围以题目、实验或声明的判据为准。安装成功、历史日志和 GPU 查询不等于课程、CPU 或训练完成。
- 通用工具在 ../Tools/wsl-sandbox/；项目工具在各自 tools/，README 登记。一次性材料使用系统临时目录或已有忽略目录，核对后清理。
- 保留 .wsl-sandbox-volume.json、卷外 state/ysyx.json、迁移恢复记录、引用的日志、原始证据和有用 HOME 配置。卷身份与显示名称分离，不能手工生成新 token。
- 文本采用 UTF-8、LF；PowerShell 工具同时兼容 Windows PowerShell 5.1 与 PowerShell 7。校验遵循 Workspace 规则，普通移动不重复全量哈希。
