# labs：实验源码与判据

每个实验目录服务一篇教程或一篇 fundamentals，路径一一对应：

```text
tutorials/E/04-仿真与验证/01-Verilator把电路变成程序.md
labs/E/04-仿真与验证/01-Verilator把电路变成程序/

fundamentals/01-Verilator模型与eval.md
labs/fundamentals/01-Verilator模型与eval/
```

## 实验目录里有什么

1. **实验源码**（`.v` `.sv` `.c` `.cpp` `.h` `Makefile`）：为讲解写的演示代码，正文贴出的版本与这里逐字一致。它们不是讲义作业的答案，不进 ysyx-workbench。
2. **check.sh**：从源码重建全部产物，逐条核对正文里每个可观测的说法，并自己构建改坏的副本，确认判据能变红。末尾打印 `N PASS / N FAIL / N SKIP`，有 FAIL 时退出码非 0。写法见[生产指南](../生产指南.md)第 3 节。
3. **mutate.sh**：核对正文"注错见红"的说法。每一项把实验文件复制到 `build/mut/<项名>/`，改坏一处，跑副本的 check.sh，确认变红的判据恰好是正文写的那几条。第一项"原样"不改动，作对照。末尾打印 `N OK / N BAD`。写法见生产指南第 3 节第 11 条。
4. **build/**：check.sh 与 mutate.sh 的产物，check.sh 每次运行先清空，被 .gitignore 挡住。两个脚本共用它，不要同时跑。

学员在 ysyx-workbench 里做的实验，代码留在主工程，这里只放一份 `.md` 记录，例如 [E/04-仿真与验证/00-环境四查.md](E/04-仿真与验证/00-环境四查.md)。记录写清输入、命令、预期、实际结果与限制。

## 怎么跑

从 Workspace 根目录执行，以第 01 章为例：

```powershell
& .\Tools\wsl-sandbox\sandbox.ps1 -Action Run -Project ysyx -Command @('bash', '-lc', "bash '/workspace/docs/topics/Knowledge/labs/E/04-仿真与验证/01-Verilator把电路变成程序/check.sh' > /workspace/cache/e4-scratch/last.log 2>&1")
```

沙箱 Run 任务里 `/workspace` 就是 `projects/ysyx`。完整输出在 `projects/ysyx/cache/e4-scratch/last.log`。跑 mutate.sh 把命令里的 `check.sh` 换成 `mutate.sh`。

| 实验目录 | check.sh 基线 | mutate.sh 基线 | 本机耗时 |
| --- | --- | --- | --- |
| E/04-仿真与验证/01-Verilator把电路变成程序 | 82 PASS / 0 FAIL / 0 SKIP | 25 OK / 0 BAD | check.sh 约 32 秒，mutate.sh 约 15 分钟 |
| fundamentals/01-Verilator模型与eval | 91 PASS / 0 FAIL / 0 SKIP | 16 OK / 0 BAD | check.sh 约 65 秒，mutate.sh 约 9 分钟 |

## 规则

1. 判据要能注错见红：故意改坏一处，判据必须失败。
2. 讲义判据含糊的地方（如"观察输出"）落成机器可查的具体条件，转化过程写在 check.sh 的注释或记录开头。
3. 失败与否定结论照记，不删除，它们是回归网的一部分。
4. 原始日志在 StudyLab/logs/ysyx/ 或项目 cache/，记录里引用位置，不整段粘贴。
5. 各 check.sh 与 mutate.sh 的基线（`N PASS`、`N OK`）登记在上表和[项目 README](../../../../README.md) 的当前进度节；判据有变化的提交同步更新两处。
