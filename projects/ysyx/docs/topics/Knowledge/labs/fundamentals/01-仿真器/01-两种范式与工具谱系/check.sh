#!/bin/bash
# fundamentals/01（仿真器的两种范式与工具谱系）的判据自动核对
#
# 用法：在沙箱里 bash check.sh
# 三组：1800 条款引用核对（对书签摘录）；四态语义实测（iverilog 的 x 传染）；
# 两态语义实测（verilator 的默认初值与 --x-initial unique 随机初值）。
# 各节标题里的"第 N 节"就是正文的小节号。正文"注错见红"由 mutate.sh 实跑。

cd "$(dirname "$0")" || exit 1

PASS=0; FAIL=0; SKIP=0
ok()   { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
no()   { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '        %s\n' "$2"; }
skip() { SKIP=$((SKIP+1)); printf '  SKIP  %s\n' "$1"; }

command -v verilator >/dev/null 2>&1 || { echo "找不到 verilator：本脚本要在沙箱里运行"; exit 1; }

B=build
rm -rf "$B" && mkdir -p "$B"
TOC=1800-toc-excerpt.md

echo "=== 环境 ==="
V="$(verilator --version 2>&1 | head -1)"
if grep -qE '^Verilator 5\.052 ' <<< "$V"; then ok 'Verilator 版本是 5.052'; else no 'Verilator 版本是 5.052' "实得 $V"; fi
IV="$(iverilog -V 2>&1 | head -1)"
if grep -qE 'Icarus Verilog version 12\.0' <<< "$IV"; then ok 'iverilog 版本是 12.0'; else no 'iverilog 版本是 12.0' "实得 $IV"; fi

echo "=== 第 1 节 事件驱动：标准怎么定义 ==="
TOCTXT="$(cat "$TOC" 2>/dev/null)"
# 用法：check1800 书签模式 判据句（判据句独立给出，注错改模式时判据名不变）
check1800() {
	local pat=$1 name=$2
	if grep -qE "^  $pat" <<< "$TOCTXT"; then ok "$name"; else no "$name" '书签摘录里找不到'; fi
}
check1800 '4\.3 Event simulation' '标准书签里有 4.3 Event simulation'
check1800 '4\.4 Stratified event scheduler' '标准书签里有 4.4 Stratified event scheduler'
check1800 '4\.5 SystemVerilog simulation reference algorithm' '标准书签里有 4.5 SystemVerilog simulation reference algorithm'
check1800 '4\.6 Determinism' '标准书签里有 4.6 Determinism'
check1800 '4\.7 Nondeterminism' '标准书签里有 4.7 Nondeterminism'

echo "=== 第 2 节 两个正交维度 ==="
# iverilog 的产物是带 shebang 的中间文件，由 vvp 解释执行（两维度中"解释执行"一侧的实证）
iverilog -o "$B/ivmid" tb_xprop.v 2> "$B/ivmid.err"
if head -c 16 "$B/ivmid" 2>/dev/null | grep -q '^#! /usr/bin/vvp'; then
	ok 'iverilog 的产物首行是 #! /usr/bin/vvp（中间文件由 vvp 解释执行）'
else
	no 'iverilog 的产物首行是 #! /usr/bin/vvp（中间文件由 vvp 解释执行）' "实得 $(head -c 20 "$B/ivmid" 2>/dev/null)"
fi

echo "=== 第 4 节 四态与两态 ==="
# iverilog：x 的传染与短路
iverilog -o "$B/xprop" tb_xprop.v 2> "$B/xprop.err" && vvp "$B/xprop" > "$B/xprop.run" 2>&1
if grep -q '0&x=0 1&x=x x+1=xxxx' "$B/xprop.run"; then
	ok 'iverilog：0 & x 得 0，1 & x 得 x，x + 1 得 xxxx'
else
	no 'iverilog：0 & x 得 0，1 & x 得 x，x + 1 得 xxxx' "实得 $(head -1 "$B/xprop.run")"
fi
# verilator 默认：未初始化为 0
verilator --cc --exe --build -j 0 --top-module xu32 --Mdir "$B/d" xu32.v tb_xu32.cpp > "$B/d.log" 2>&1
"$B/d/Vxu32" > "$B/d.run" 2>&1
if grep -q 'r=00000000' "$B/d.run"; then
	ok 'verilator 默认：未初始化的 32 位 r 是 0'
else
	no 'verilator 默认：未初始化的 32 位 r 是 0' "实得 $(cat "$B/d.run")"
fi
# verilator --x-initial unique + 运行时随机：非 0
verilator --cc --exe --build -j 0 --top-module xu32 --x-initial unique --Mdir "$B/u" xu32.v tb_xu32.cpp > "$B/u.log" 2>&1
"$B/u/Vxu32" +verilator+rand+reset+2 > "$B/u.run" 2>&1
if grep -qE 'r=[0-9a-f]{8}' "$B/u.run" && ! grep -q 'r=00000000' "$B/u.run"; then
	ok 'verilator --x-initial unique 加运行期随机：未初始化的 r 不是 0'
	printf '        实得 %s\n' "$(cat "$B/u.run")"
else
	no 'verilator --x-initial unique 加运行期随机：未初始化的 r 不是 0' "实得 $(cat "$B/u.run")"
fi

echo
printf '  %d PASS / %d FAIL / %d SKIP\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
