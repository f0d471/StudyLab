# YSYX 资料目录与维护规则

本目录保存一生一芯与 PA 的离线讲义、自编专题、依赖来源和资料核对记录。日常阅读从本页进入；课程实际进度统一记录在[项目 README](../README.md)。

## 1. 从哪里开始看

| 目的 | 入口 |
| --- | --- |
| 按现行讲义学习 | [一生一芯课程主页](site/ysyx.oscc.cc/docs/index.html) |
| 直接进入 E4 | [E4：处理器的仿真和验证](site/ysyx.oscc.cc/docs/2607/e/4.html) |
| 阅读 PA 实验 | [PA 实验主页](site/ysyx.oscc.cc/docs/ics-pa/index.html) |
| 搜索全部已下载页面 | [离线首页与全文搜索](site/index.html) |
| 查看学习记录的组织方式（教程/基础/实验/工程文档） | [学习记录 README](topics/README.md) |
| 查看 RISC-V 官方手册的来源与版本 | [riscv-spec-source.json](riscv-spec-source.json) |
| 查看下载范围、统计和缺失项 | [离线镜像记录](offline-report.md) |
| 查看环境和日常命令 | [平台开发环境](../../../docs/通用学习平台.md)、[主工程日常实验](../ysyx-workbench/docs/日常实验.md) |

离线网页可以直接用浏览器打开，不需要启动服务器。站外视频、文章、云文档和账号服务保留在线链接，访问时仍需网络。镜像只代表下载时的内容；当前课程要求有变化时，以官方讲义为准，并明确采用的版本。

## 2. 实际目录结构

~~~text
docs/
├── README.md                 本页：手工维护的阅读入口和管理规则
├── topics/                   学习记录区：两棵树，入口见其 README
│   ├── Engineering/          对工程的改造文档：Todo / Bugs / TechReports
│   └── Knowledge/            知识库：tutorials / fundamentals / labs
├── sources/                  外部规格手册等下载资料；本地保留，不入 Git
│   └── riscv/                RISC-V 官方手册（riscv-spec.pdf）
├── site/                     适合直接阅读的离线网站
│   ├── index.html            总目录与全文搜索
│   ├── ysyx.oscc.cc/          按来源域名保存的官方站点内容
│   │   ├── docs/             讲义：2607、ics-pa、往期版本与语言版本等
│   │   ├── slides/           课件的离线连续阅读版
│   │   └── res/              站点引用的资源
│   ├── cdn.jsdelivr.net/     从公共资源服务取得的依赖
│   │   └── npm/
│   │       └── mathjax@3.2.2/ 公式显示所需的 MathJax
│   └── _offline/             镜像工具生成的阅读与搜索支持文件
├── originals/                下载得到的原始网页、样式和路由脚本
│   └── ysyx.oscc.cc/
├── qa/                       离线阅读检查留下的截图
├── offline-report.md         下载与核对结果的可读报告
├── manifest.json             下载文件与来源的登记清单
├── progress.json             抓取工具的运行进度
├── verification.json         本地链接、依赖与缺失项核对结果
├── content-check.json        原网页与离线网页的正文/结构比较结果
├── external-links.json       保留在线访问的站外链接
├── browser-check.json        浏览器断网抽查记录与截图索引
├── rt-thread-source.json     RT-Thread 依赖仓的来源与版本登记
└── riscv-spec-source.json    RISC-V 官方手册的来源、版本与摘要登记
~~~

上述目录均已存在。topics/ 下的教程、基础、实验与工程文档随学习进度建立，不提前写空篇目。

### site 内的名字为什么这样写

site 的路径保留来源网站结构，便于从官方链接定位本地页面。这里的英文名和数字多数来自原站，不是额外的学习任务。

| 名字 | 含义 |
| --- | --- |
| ysyx.oscc.cc | 官方讲义的来源域名 |
| docs/2607 | v26.07 版讲义；其中 e/4.html 对应 E4 |
| docs/2205、2306、2407 | 往期讲义，按版本使用，不能与 2607 的要求混用 |
| docs/ics-pa | 南京大学计算机系统基础 PA 实验讲义 |
| docs/en、docs/ru | 原站的英文、俄文内容 |
| docs/assets、docs/res | 原站使用的样式、图片等公共资源 |
| slides | 演示课件；镜像工具将站内课件整理成连续阅读页 |
| cdn.jsdelivr.net | 公共资源服务的域名；本地保留对应资源路径 |
| _offline | 本地阅读支持：reader.css、reader.js 和搜索数据/脚本 |
| originals | 原始下载内容，用于来源比对和重新生成离线网页 |
| qa | Quality Assurance，即质量检查；这里存检查截图 |

不要把这些目录改成中文名或按课程重新搬动。页面、样式、搜索索引和下载清单共同引用了这些路径；分类由阅读首页完成。

### 各种文件后缀表示什么

- .md：Markdown 文档，适合直接阅读和人工维护。
- .html：浏览器打开的网页。
- .json：工具读取的结构化记录，日常不需要逐行阅读。
- .css / .js：网页样式和脚本，支撑阅读、公式与搜索。
- .png：检查截图或文档配图。

## 3. 哪些可以手写，哪些由工具生成

| 对象 | 谁维护 | 维护方式 |
| --- | --- | --- |
| README.md | 人工 | 修改目录说明、入口和维护规则；镜像工具不得覆盖 |
| topics/ | 人工 | 学习记录区（Knowledge 与 Engineering）；收录与体例规则见 [topics README](topics/README.md) |
| riscv-spec-source.json | 手册登记过程 | 手册版本变化后重新下载、更新登记并复核摘要；同一来源不另建重复登记 |
| rt-thread-source.json | 依赖登记过程 | 依赖版本改变后核对并更新；同一来源不另建重复登记 |
| site/、originals/ | mirror_docs.py | 通过工具抓取、重生成，不在镜像正文内插入个人笔记 |
| manifest.json | mirror_docs.py | 保存来源、状态、路径和下载登记；不手改成功/失败状态 |
| progress.json | mirror_docs.py | 记录抓取队列与本次处理进度；它不是课程进度 |
| verification.json | mirror_docs.py | 保存最终核对结果，定位缺失链接和资源 |
| content-check.json | mirror_docs.py | 保存原文与离线内容比较结果 |
| external-links.json | mirror_docs.py | 保存没有递归复制的站外链接 |
| offline-report.md | 镜像工具；现有历史附录保留 | 可读的下载报告；刷新时可以重生成，不承载管理规则 |
| browser-check.json、qa/ | 浏览器检查过程 | 保留实际检查时间、范围和截图；不能用旧记录宣称新页面已验证 |

manifest 是“登记清单”，verification 是“核对结果”。progress 的运行计数和 verification 的最终缺失统计口径不同，不能仅凭某个数字判断整份资料是否完整。

[topics/](topics/README.md)是学习记录区，与官方讲义正文分开维护：Knowledge 汲取讲义与手册的知识（主线教程、前置基础、实验记录），Engineering 记录对工程的改造（路线、缺陷、开发过程）。记录中的篇目与实验不等同于课程完成；实际进度只看[项目 README](../README.md)。

## 4. 新文件应该放哪里

新增材料前先确定用途和唯一归属；相同内容已有主位置时，新增链接即可。

| 新增内容 | 放置位置 | 约束 |
| --- | --- | --- |
| 主线教程篇目 | topics/Knowledge/tutorials/<阶段>/ | 按讲义部分一篇，篇首注明出处，篇末作答讲义必答题 |
| 前置知识与罗列型手册 | topics/Knowledge/fundamentals/ | 用到才加；没被任何教程引用的篇不开 |
| 实验记录与判据 | topics/Knowledge/labs/<阶段>/ | 实验代码在主工程，这里放跑法、判据与实测 |
| 工程改造文档 | topics/Engineering/ 的 Todo / Bugs / TechReports | 流转与提交同步规则见其 README |
| 学习记录配图 | 所在文档目录内的 assets/<主题>/ | 图片名称说明内容；在正文引用，不单独堆无说明截图 |
| 官方讲义及站内资源 | 镜像工具管理的 site/、originals/ | 保留原路径和来源；更新工具，不手工拼接另一套镜像 |
| 外部规格手册等下载资料 | sources/<来源>/，本地保留不入 Git | 在 <名称>-source.json 登记来源、版本、摘要与用途 |
| 新依赖的来源与固定版本 | 优先使用该依赖已有的来源登记 | 外置项目依赖可采用 <依赖名>-source.json，说明 URL、分支/版本、提交、用途与范围 |
| 主工程的构建、接口和运行说明 | ../ysyx-workbench/docs/ | 随对应源码仓维护，本目录引用入口 |
| 通用平台环境与隔离规则 | ../../../docs/ | 项目内只链接，不复制平台说明 |
| 可复用脚本 | ../tools/ | 在工具 README 登记，不将脚本散放在资料目录 |
| 程序日志、波形、编译产物与大文件 | 对应 logs/、cache/ 或已有忽略目录 | 文档引用证据位置和范围，不把它们混进笔记 |

根目录只保留本入口、镜像工具固定的清单/报告和项目级依赖来源登记。新写的课程笔记与专题进入上述分类目录；新类别需要在本页说明用途后再加入。

### 自编文档的最低要求

1. 开头写明解决的问题、采用的讲义版本/章节和来源链接。
2. 引用源码时注明仓库内相对路径，必要时注明提交或配置；代码与说明发生变化后同步更新。
3. 新术语先给中文含义、全称和具体对象，再解释工作机制；代码片段应说明输入、输出和关键步骤。
4. 实验结果写清输入、命令、预期、实际结果与限制；原始输出放在对应日志位置。
5. 区分教程示例、已有源码、实际运行结果和待验证设想。工具安装、历史日志、候选实验不等同于课程完成。
6. 使用 UTF-8、LF、相对链接和稳定文件名。引用确切页面、章节或版本，避免依赖只在一台机器有效的绝对路径。

实际学习进度只在[项目 README](../README.md)维护。本目录的笔记可以记录单次实验结果，但不另建一份重复的总进度表。

## 5. 镜像更新与检查

镜像工具是 [mirror_docs.py](../tools/mirror_docs.py)，完整用途登记在[工具 README](../tools/README.md)。该工具的可读报告写入 offline-report.md，README.md 始终由人工维护。

以下命令从 Workspace 根目录执行，通过规定的 WSL 沙箱入口运行。

仅核对已有本地资料，不下载：

~~~powershell
& .\Tools\wsl-sandbox\sandbox.ps1 -Action Run -Project ysyx -Command @('python3', '-B', '../tools/mirror_docs.py', '--verify-only')
~~~

按已有下载清单续传，需要联网：

~~~powershell
& .\Tools\wsl-sandbox\sandbox.ps1 -Action Run -Project ysyx -Network -Command @('python3', '-B', '../tools/mirror_docs.py')
~~~

只有确实要重新取得上游内容时才使用 --refresh；只修复失败请求时使用 --retry-failed；仅从已有原始内容重生成网页时使用 --render-only。离线副本不会自动同步到最新讲义。

更新后的核对范围按改动选择：

- 新增或移动人工文档：检查 README 索引、正文相对链接、引用者和 Git 白名单。
- 修改镜像工具或重新生成网页：检查本地引用与正文保留；页面交互、资源或公式有变化时再做对应浏览器抽查。
- 更换依赖版本：更新唯一来源登记，并按实际消费者验证；不要直接改 JSON 让旧结果看起来通过。
- 查看下载统计时同时查看记录时间。页面数量、失败项和检查结论以对应原始记录为准，不在多个文件中重复抄录数字或长摘要。
- 删除或改名文件：核对用途、来源、引用和唯一副本，再同步入口。失败记录、原始材料和被引用证据按其用途保留。

下载和文档检查通过，仅说明相应资料范围通过检查；CPU、操作系统和课程实验使用各自的功能判据。

## 6. Git 与仓内维护标准

本目录由 StudyLab 平台仓管理；ysyx-workbench 和 rt-thread-am 各自保留独立 Git。平台仓默认忽略项目 docs 下未明确允许的内容，是否在文件夹中可见与是否被 Git 收录是两回事。

当前收录：

- 本 README；
- topics/ 下的 Markdown（Engineering 与 Knowledge 的全部篇目与 README）；
- rt-thread-source.json、riscv-spec-source.json。

本地保留且默认不收录：

- site/、originals/ 与镜像使用的资源；
- sources/ 下载的规格手册等原始资料；
- 下载清单、运行进度、核对 JSON 和 offline-report.md；
- 浏览器检查记录与截图。

这些本地文件仍有用途；只克隆平台仓不会自动恢复离线资料、依赖源码、缓存和原始证据。

新增需要收录的文档类型时，同步检查平台 [.gitignore](../../../.gitignore)。当前规则放行 topics/ 下全部 Markdown；labs 的判据脚本、配图等非 Markdown 内容按实际引用另行放行。保持镜像、临时文件、大型二进制和未核对再分发权的资料处于忽略范围，不整体放开 docs，也不用强制添加绕过分类规则。

保留原文作者、来源与许可。自编分析注明所用资料；外部文献采用引用或合法来源，不把个人学习副本当作自编作品发布。资料目录结构、工具说明、项目规则和引用路径在同一次改动中保持一致。

