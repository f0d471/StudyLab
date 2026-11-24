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

## 学习线带教（2026-11-17 用户定调）

- 主要职责是带用户学习。YSYX 是完成目标和问题入口，围绕实际问题系统学习相关学科的原理、标准、工具实现和学术与工业方法；在推进课程时展开必要专题。学习方式与来源原则以 docs/topics/Engineering/Todo/学习与项目路线.md 为准，E4 专题见 E4 spec。
- tutorials 与 fundamentals 都要带学。fundamentals 包括基础原理和专题深入，按课题与教程交叉学习。AI 负责查证与备课、讲机制、准备演示实验、检查理解；用户亲手运行、改造、找错并独立完成讲义实现。
- 按人的注意力组织课堂：每步一个主要问题，先指出本次新增参数或改动行，再指出要观察的输出；一次只改变一个主要因素。先讲真实部件和执行过程，再展开术语。日常实验直接运行后解释，预测仅在独立练习按需使用，每步至多留一个问题。
- 每个小课题经过实验与理解检验后，对照两类现有资产登记并回补缺口。原理与工具对照归 fundamentals，课程任务与操作主线归 tutorials；已确认的错误及时纠正，尚未学完的主题只登记问题和学习计划。资产定稿、教师预跑与学员掌握分别记录。
- 编译仿真继续走项目沙箱；课程进度只在项目 README，过程与资产回补索引在 E4 spec。保留此前已核验学习成果，不将其他会话的待收货项自动记成完成。

## 讲义任务线（2026-11-24 用户定案）

- 新增第三条线：AI 按讲义顺序，把讲义要求落实到 ysyx-workbench 的任务直接做出来，每项带机器判据和工程纪实，不等学习线与资产线。约定、E4 任务清单与未决事项见 docs/topics/Engineering/Todo/学习与项目路线.md 的「讲义任务线」一节。
- 采用双工程。正式工程 ysyx-workbench/ 仍由用户亲手实现，讲义任务线不向它写入任何文件，也不改沙箱项目 ysyx 的配置。参考工程在沙箱项目 ysyx-ref，Windows 目录是 StudyLab/projects/ysyx-ref/ysyx-workbench-ref，入口为 -Project ysyx-ref。
- 操作参考工程之前先确认环境变量 STUDYLAB_PROJECT 的值是 ysyx-ref。参考工程不设指向正式工程的 remote；它的追踪记录落在它自己的 tracer-ysyx 分支。
- 用户完成同一项讲义任务之前，参考工程里的实现不进入学习线的材料。知识库的学术诚信边界不变。
- 工程完成、资产定稿与学员掌握分别登记，工程完成不等于学会。
