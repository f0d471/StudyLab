#!/bin/bash
# fundamentals/07（验证方法学总览）的判据自动核对
#
# 用法：在沙箱里 bash check.sh
# 本篇是地图型篇目：判据形态是"引用可核对"，不是电路实验。
# 标准条款对着书签摘录（1800-toc-excerpt.md，由标准 PDF 书签生成）核对，
# 工具声明对着 man 页核对，标准 PDF 完整性用登记的 sha256 核对，
# 外部链接的登记行对着正文核对（链接可达性由生产者经 WebFetch 核对，状态写在正文里）。
# 各节标题里的"第 N 节"就是正文的小节号。
# 改坏必红的核对由 mutate.sh 逐项实跑（改的是本脚本的期望值，期望清单登记在
# mutate.sh 的参数里，正文不写注错）。

cd "$(dirname "$0")" || exit 1

PASS=0; FAIL=0; SKIP=0
ok()   { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
no()   { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '        %s\n' "$2"; }
skip() { SKIP=$((SKIP+1)); printf '  SKIP  %s\n' "$1"; }
eq()   { if [ "$2" = "$3" ]; then ok "$1"; else no "$1" "期望 $3，实得 $2"; fi; }
has()  { if grep -qE -e "$3" <<< "$2"; then ok "$1"; else no "$1" "输出里找不到 $3"; fi; }
hasnt(){ if grep -qE -e "$3" <<< "$2"; then no "$1" "输出里不该有 $3"; else ok "$1"; fi; }

command -v verilator >/dev/null 2>&1 || { echo "找不到 verilator：本脚本要在沙箱里运行"; exit 1; }

PDF=/workspace/docs/sources/systemverilog/sv-1800-2017.pdf
MAN=/workspace/tools/verilator-5.052/share/man/man1/verilator.1
COVMAN=/workspace/tools/verilator-5.052/share/man/man1/verilator_coverage.1
CH=/workspace/docs/topics/Knowledge/fundamentals/07-验证方法学总览.md
TOC=1800-toc-excerpt.md
SHA=12e3dc7bafafca28af2b89ebc2761fb7a606d68716cf04c2d93c8617c78eebec

B=build
rm -rf "$B" && mkdir -p "$B"

echo "=== 第 1 节 地图怎么用 ==="
V="$(verilator --version 2>&1 | head -1)"
if grep -qE '^Verilator 5\.052 ' <<< "$V"; then
	ok 'Verilator 版本是 5.052（工具声明按这个版本的 man 页核对）'
else
	no 'Verilator 版本是 5.052（工具声明按这个版本的 man 页核对）' "实得 $V"
fi
if [ -f "$PDF" ]; then
	got=$(sha256sum "$PDF" | cut -d' ' -f1)
	eq '标准 PDF 在位，校验和与登记一致' "$got" "$SHA"
else
	no '标准 PDF 在位，校验和与登记一致' "找不到 $PDF"
fi
if [ -f "$TOC" ]; then ok '书签摘录文件在位'; else no '书签摘录文件在位' "找不到 $TOC"; fi

TOCTXT="$(cat "$TOC" 2>/dev/null)"
CHTXT="$(tr -d '\n' < "$CH" 2>/dev/null | tr -s ' ')"

echo "=== 第 2 节 覆盖率 ==="
if grep -qE '^19\. Functional coverage' <<< "$TOCTXT"; then ok '功能覆盖是标准第 19 章'; else no '功能覆盖是标准第 19 章' '书签摘录里没有第 19 章条目'; fi
if grep -qE '^  19\.3 .*covergroup' <<< "$TOCTXT"; then ok 'covergroup 定义在 19.3'; else no 'covergroup 定义在 19.3' '书签摘录里没有 19.3'; fi
if grep -qE '^  19\.5 .*coverage points' <<< "$TOCTXT"; then ok '覆盖点定义在 19.5'; else no '覆盖点定义在 19.5' '书签摘录里没有 19.5'; fi
if grep -qE 'code coverage' <<< "$TOCTXT"; then
	no '书签摘录里没有 code coverage 条目（代码覆盖不在标准里）' '摘录里出现了 code coverage'
else
	ok '书签摘录里没有 code coverage 条目（代码覆盖不在标准里）'
fi
if [ -f "$COVMAN" ]; then ok 'verilator_coverage 的 man 页在工具链里'; else no 'verilator_coverage 的 man 页在工具链里' "找不到 $COVMAN"; fi
# man 页是 roff 源文件，连字符写作 \-，所以模式里每个 - 前有一个反斜杠
if grep -q -- '\\-\\-coverage .*Enable all coverage' "$MAN" 2>/dev/null; then ok 'man 页有 --coverage（代码覆盖由工具选项开启）'; else no 'man 页有 --coverage（代码覆盖由工具选项开启）' 'man 页里找不到 --coverage'; fi

echo "=== 第 3 节 断言 ==="
if grep -qE '^16\. Assertions' <<< "$TOCTXT"; then ok '断言是标准第 16 章'; else no '断言是标准第 16 章' '书签摘录里没有第 16 章'; fi
if grep -qE '^  16\.3 Immediate assertions' <<< "$TOCTXT"; then ok '立即断言在 16.3'; else no '立即断言在 16.3' '书签摘录里没有 16.3'; fi
if grep -qE '^  16\.5 Concurrent assertions' <<< "$TOCTXT"; then ok '并发断言在 16.5'; else no '并发断言在 16.5' '书签摘录里没有 16.5'; fi
if grep -qE '^  16\.7 Sequences' <<< "$TOCTXT"; then ok '序列在 16.7'; else no '序列在 16.7' '书签摘录里没有 16.7'; fi
if grep -q -- '\\-\\-no\\-assert .*Disable all assertions' "$MAN" 2>/dev/null; then ok '--no-assert 在 man 页（断言默认启用，这个选项用来关闭）'; else no '--no-assert 在 man 页（断言默认启用，这个选项用来关闭）' 'man 页里找不到 --no-assert'; fi

echo "=== 第 4 节 形式验证 ==="
if grep -qE 'symbiyosys\.readthedocs\.io' <<< "$CHTXT" && grep -qE '2026-11-14 核对可达' <<< "$CHTXT"; then
	ok '正文登记了 SymbiYosys 入口与核对状态'
else
	no '正文登记了 SymbiYosys 入口与核对状态' '正文里找不到登记行'
fi

echo "=== 第 5 节 UVM 与验证语言 ==="
if grep -qE 'accellera\.org/downloads/standards/uvm' <<< "$CHTXT" && grep -qE '未能核对' <<< "$CHTXT"; then
	ok '正文登记了 Accellera UVM 入口，并标明未能核对'
else
	no '正文登记了 Accellera UVM 入口，并标明未能核对' '正文里找不到登记行'
fi
if grep -qE '^18\. Constrained random' <<< "$TOCTXT"; then ok '约束随机值生成是标准第 18 章'; else no '约束随机值生成是标准第 18 章' '书签摘录里没有第 18 章'; fi

echo "=== 第 6 节 参考模型与差分测试 ==="
if grep -qE 'riscv-isa-sim' <<< "$CHTXT" && grep -qE '2026-11-14 核对可达' <<< "$CHTXT"; then
	ok '正文登记了 spike 入口与核对状态'
else
	no '正文登记了 spike 入口与核对状态' '正文里找不到登记行'
fi
if grep -qE '^4\. Scheduling semantics' <<< "$TOCTXT"; then ok '调度语义是标准第 4 章'; else no '调度语义是标准第 4 章' '书签摘录里没有第 4 章'; fi
if grep -qE '^  4\.5 SystemVerilog simulation reference algorithm' <<< "$TOCTXT"; then ok '参考算法在 4.5'; else no '参考算法在 4.5' '书签摘录里没有 4.5'; fi

echo "=== 第 7 节 SystemC/TLM ==="
if grep -qE 'https://www\.accellera\.org' <<< "$CHTXT" && grep -qE '未能核对' <<< "$CHTXT"; then
	ok '正文登记了 Accellera 站点入口，并标明未能核对'
else
	no '正文登记了 Accellera 站点入口，并标明未能核对' '正文里找不到登记行或核对状态标注'
fi

echo
printf '  %d PASS / %d FAIL / %d SKIP\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
