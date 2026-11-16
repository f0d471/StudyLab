#!/bin/bash
# 教程第 04 章（描述电路的纪律与两个模板）的判据自动核对
#
# 用法：在沙箱里 bash check.sh
# 四组：环境；两种建模写法的等价（2 选 1 与计数器各一组随机对照）；
# 行为建模的典型雷（不完整 if 推断锁存器）；修法对照。
# 模板文件 tpl.v 是讲义原文，与 fundamentals/06 的副本逐字一致。
# 各节标题里的"第 N 节"就是正文的小节号。改坏必红的核对由 mutate.sh 逐项实跑。

cd "$(dirname "$0")" || exit 1

PASS=0; FAIL=0; SKIP=0
ok()   { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
no()   { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '        %s\n' "$2"; }
skip() { SKIP=$((SKIP+1)); printf '  SKIP  %s\n' "$1"; }

command -v verilator >/dev/null 2>&1 || { echo "找不到 verilator：本脚本要在沙箱里运行"; exit 1; }

B=build
rm -rf "$B" && mkdir -p "$B"

echo "=== 环境 ==="
V="$(verilator --version 2>&1 | head -1)"
if grep -qE '^Verilator 5\.052 ' <<< "$V"; then ok 'Verilator 版本是 5.052'; else no 'Verilator 版本是 5.052' "实得 $V"; fi

echo "=== 第 2 节 两种写法，同一种电路 ==="
verilator --cc --exe --build -j 0 --top-module eq2 --Mdir "$B/e2" \
	tpl.v mux2a.v mux2t.v eq2.v tb_eq2.cpp > "$B/e2.log" 2>&1
"$B/e2/Veq2" > "$B/e2.run" 2>&1
rc=$?
if [ "$rc" -eq 0 ] && grep -q 'mismatches=0' "$B/e2.run"; then
	ok '2 选 1：assign 版与 MuxKey 版在 1000 组随机输入下输出一致（独立判据重算）'
else
	no '2 选 1：assign 版与 MuxKey 版在 1000 组随机输入下输出一致（独立判据重算）' "退出码 $rc：$(head -2 "$B/e2.run" | tr '\n' ' ')"
fi
verilator --cc --exe --build -j 0 --top-module eqc --Mdir "$B/ec" \
	tpl.v cnta.v cntt.v eqc.v tb_eqc.cpp > "$B/ec.log" 2>&1
"$B/ec/Veqc" > "$B/ec.run" 2>&1
rc=$?
if [ "$rc" -eq 0 ] && grep -q 'mismatches=0' "$B/ec.run"; then
	ok '计数器：行为建模版与模板版在 200 拍随机使能下逐拍一致'
else
	no '计数器：行为建模版与模板版在 200 拍随机使能下逐拍一致' "退出码 $rc：$(head -2 "$B/ec.run" | tr '\n' ' ')"
fi

echo "=== 第 3 节 行为建模的雷：锁存器 ==="
verilator --lint-only -Wall lat_bad.v > "$B/lb.log" 2>&1
rc=$?
if [ "$rc" -ne 0 ] && grep -q 'Warning-LATCH' "$B/lb.log"; then
	ok '不完整的 if 推断锁存器：-Wall 报 LATCH 且致命'
else
	no '不完整的 if 推断锁存器：-Wall 报 LATCH 且致命' "退出码 $rc：$(grep -m2 -E '^%' "$B/lb.log" | tr '\n' ' ')"
fi
verilator --lint-only lat_bad.v > "$B/lb2.log" 2>&1
rc=$?
if [ "$rc" -ne 0 ] && grep -q 'Warning-LATCH' "$B/lb2.log"; then
	ok 'LATCH 不开 -Wall 也报（默认开且致命）'
else
	no 'LATCH 不开 -Wall 也报（默认开且致命）' "退出码 $rc"
fi
verilator --lint-only -Wall lat_good.v > "$B/lg.log" 2>&1
rc=$?
if [ "$rc" -eq 0 ] && ! grep -qE '^%' "$B/lg.log"; then
	ok '补全 else 后 -Wall 零警告（退出码 0 且无诊断行）'
else
	no '补全 else 后 -Wall 零警告（退出码 0 且无诊断行）' "退出码 $rc：$(grep -m2 -E '^%' "$B/lg.log" | tr '\n' ' ')"
fi

echo
printf '  %d PASS / %d FAIL / %d SKIP\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
