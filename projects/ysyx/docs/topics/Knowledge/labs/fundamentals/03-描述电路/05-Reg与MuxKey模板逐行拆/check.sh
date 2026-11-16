#!/bin/bash
# fundamentals/05（Reg 与 MuxKey 模板逐行拆）的判据自动核对
#
# 用法：在沙箱里 bash check.sh
# 三组：Reg 模板的复位/保持/采样行为；MuxKey 的命中/不命中/键重复/参数错位；
# 两条使用注意的实测证明（错位在位宽恰好相等时静默出错、位宽不符时被 WIDTH 拦下）。
# 各节标题里的"第 N 节"就是正文的小节号。正文"注错见红"由 mutate.sh 实跑。

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

echo "=== 第 1 节 Reg 模板：复位、保持、采样 ==="
verilator --cc --exe --build -j 0 --top-module reg_top --Mdir "$B/r" tpl.v reg_top.v tb_reg.cpp > "$B/r.log" 2>&1
"$B/r/Vreg_top" > "$B/r.run" 2>&1
grep -q 'after reset: dout=5'    "$B/r.run" && ok '复位后 dout 等于 RESET_VAL（5）'      || no '复位后 dout 等于 RESET_VAL（5）'      "实得 $(sed -n 1p "$B/r.run")"
grep -q 'wen=0 din=a: dout=5'    "$B/r.run" && ok 'wen=0 时保持（din 变了也不采）'      || no 'wen=0 时保持（din 变了也不采）'      "实得 $(sed -n 2p "$B/r.run")"
grep -q 'wen=1 din=a: dout=a'    "$B/r.run" && ok 'wen=1 时采样 din'                    || no 'wen=1 时采样 din'                    "实得 $(sed -n 3p "$B/r.run")"
grep -q 'wen=0 din=3: dout=a'    "$B/r.run" && ok '采到的值在下拍保持'                  || no '采到的值在下拍保持'                  "实得 $(sed -n 4p "$B/r.run")"
grep -q 'reset again: dout=5'    "$B/r.run" && ok '运行中再复位回到 RESET_VAL'          || no '运行中再复位回到 RESET_VAL'          "实得 $(sed -n 5p "$B/r.run")"

echo "=== 第 2 节 MuxKey：命中、不命中、键重复 ==="
verilator --cc --exe --build -j 0 --top-module mux_top --Mdir "$B/m" tpl.v mux_top.v tb_mux.cpp > "$B/m.log" 2>&1
"$B/m/Vmux_top" > "$B/m.run" 2>&1
if grep -q 'key=0 plain=1' "$B/m.run" && grep -q 'key=1 plain=2' "$B/m.run" && grep -q 'key=2 plain=4' "$B/m.run"; then
	ok '三个键各自选出对应的数据（1、2、4）'
else
	no '三个键各自选出对应的数据（1、2、4）' "$(cat "$B/m.run" | tr '\n' ' ')"
fi
if grep -q 'key=3 plain=0' "$B/m.run" && grep -q 'key=3 .*def=f' "$B/m.run"; then
	ok '不命中：MuxKey 输出 0，MuxKeyWithDefault 输出默认值 f'
else
	no '不命中：MuxKey 输出 0，MuxKeyWithDefault 输出默认值 f' "$(grep 'key=3' "$B/m.run")"
fi
if grep -q 'key=1 .*dup=6' "$B/m.run" && grep -q 'key=2 .*dup=0' "$B/m.run"; then
	ok '键值重复时输出是两份数据的按位或（6），原键 10 落空（0）'
else
	no '键值重复时输出是两份数据的按位或（6），原键 10 落空（0）' "$(grep 'dup' "$B/m.run" | tr '\n' ' ')"
fi

echo "=== 第 3 节 两条使用注意的实测 ==="
# 参数错位但总位宽恰好相等：静默出错
if grep -q 'key=0 .*mis=1' "$B/m.run" && grep -q 'key=1 .*mis=0' "$B/m.run" && grep -q 'key=2 .*mis=2' "$B/m.run"; then
	ok '参数错位（位宽恰好相等）：不报警告，key=1 与 key=2 的输出和预期不符'
else
	no '参数错位（位宽恰好相等）：不报警告，key=1 与 key=2 的输出和预期不符' "$(grep 'mis' "$B/m.run" | tr '\n' ' ')"
fi
if [ ! -s "$B/m.log" ] || ! grep -qE '^%(Warning|Error)' "$B/m.log"; then
	ok '上一条的构建日志里没有任何警告（静默成立）'
else
	no '上一条的构建日志里没有任何警告（静默成立）' "日志里出现：$(grep -m2 -E '^%' "$B/m.log" | tr '\n' ' ')"
fi
# 对数声明与实际拼接不符：位宽对不上，WIDTH 类警告拦下
verilator --lint-only mux_bad.v tpl.v > "$B/bad.log" 2>&1
rc=$?
if [ "$rc" -ne 0 ] && grep -qE 'Warning-WIDTH' "$B/bad.log"; then
	ok '对数声明不符被 WIDTH 类警告拦下（默认致命）'
else
	no '对数声明不符被 WIDTH 类警告拦下（默认致命）' "退出码 $rc：$(grep -m2 -E '^%' "$B/bad.log" | tr '\n' ' ')"
fi

echo
printf '  %d PASS / %d FAIL / %d SKIP\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
