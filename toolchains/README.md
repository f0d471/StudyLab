# 共享工具登记

共享版本由 Tools/wsl-sandbox/profiles/studylab.json 的 toolchains 唯一登记，在沙箱映射到 /toolchains/<ID> 并只读开放。

现有 verilator-5052 的物理安装仍在 projects/ysyx/tools/verilator-5.052。保留安装前缀和 YSYX 兼容路径，避免重编译整个工具；其他项目通过描述文件选择这一注册版本即可。后续新共享工具可安装到本目录，再更新注册项，不复制同一版本。
