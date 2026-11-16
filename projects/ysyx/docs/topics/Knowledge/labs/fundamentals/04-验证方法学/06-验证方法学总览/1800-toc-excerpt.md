# IEEE 1800-2017 书签摘录（验证方法学篇引用核对用）

来源：docs/sources/systemverilog/sv-1800-2017.pdf 的 PDF 书签（outline）。
再生成方法：WSL python3 + pypdf 的 reader.outline 遍历，或任何可读 PDF 书签的工具。
check.sh 用本文件核对正文引用的条款号确实存在于标准书签中。
注：PDF 书签自身把 4.4 的子节印作 3.4.x（标准排版遗留），本摘录原样保留，正文只引用到 4.4。

4. Scheduling semantics  ->p60
  4.3 Event simulation  ->p60
  4.4 Stratified event scheduler  ->p61
  4.5 SystemVerilog simulation reference algorithm  ->p66
  4.6 Determinism  ->p66
  4.7 Nondeterminism  ->p67
16. Assertions  ->p365
  16.3 Immediate assertions  ->p365
  16.5 Concurrent assertions overview  ->p375
  16.7 Sequences  ->p379
17. Checkers  ->p485
18. Constrained random value generation  ->p504
19. Functional coverage  ->p554
  19.3 Defining the coverage model: covergroup  ->p555
  19.5 Defining coverage points  ->p559
