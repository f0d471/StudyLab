# StudyLab 学习与研究平台

StudyLab 提供可复查的课程实验与研究环境，内容包括计算机基础、体系结构、操作系统、编译原理和机器学习系统。YSYX 是其中一个项目。

项目内容、目录、接入状态、日常使用、环境限制与恢复见 [通用学习平台](docs/通用学习平台.md)。

在 Workspace 根目录运行：

```powershell
& .\Tools\wsl-sandbox\sandbox.ps1 -Action List
& .\Tools\wsl-sandbox\sandbox.ps1 -Action Shell -Project ysyx
& .\Tools\wsl-sandbox\sandbox.ps1 -Action Shell -Project cs61b
```

projects/ 下各项目独立维护代码与学习进度。本仓管理平台规则、文档与注册配置，不收录课程的大型资料、模型、缓存和构建产物。
