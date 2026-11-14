#!/bin/bash
# 教程第 02 章（波形、一键仿真与另一种仿真器）的判据自动核对
#
# 用法：在沙箱里 bash check.sh
# 五组：VCD 的生成与文本结构；FST 与体积对比；make sim 一键仿真；
# iverilog 对照（真值表一致、四态对两态、延迟支持）。
# 各节标题里的"第 N 节"就是正文的小节号。正文各节"注错见红"由 mutate.sh 实跑。
# GTKWave 的可视部分是学员确认项，本脚本只做文件级判据。

cd "$(dirname "$0")" || exit 1

PASS=0; FAIL=0; SKIP=0
ok()   { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
no()   { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '        %s\n' "$2"; }
skip() { SKIP=$((SKIP+1)); printf '  SKIP  %s\n' "$1"; }

command -v verilator >/dev/null 2>&1 || { echo "找不到 verilator：本脚本要在沙箱里运行"; exit 1; }

B=build
rm -rf "$B" && mkdir -p "$B"
# 波形写在 /tmp（正文纪律）。先删掉上一次留下的，旧文件会冒充新结果。
rm -f /tmp/top.vcd /tmp/cnt.vcd /tmp/cnt.fst

echo "=== 环境 ==="
V="$(verilator --version 2>&1 | head -1)"
if grep -qE '^Verilator 5\.052 ' <<< "$V"; then ok 'Verilator 版本是 5.052'; else no 'Verilator 版本是 5.052' "实得 $V"; fi
IV="$(iverilog -V 2>&1 | head -1)"
if grep -qE 'Icarus Verilog version 12\.0' <<< "$IV"; then ok 'iverilog 在沙箱中可用（12.0）'; else no 'iverilog 在沙箱中可用（12.0）' "实得 $IV"; fi

echo "=== 第 1 节 VCD：生成与文本结构 ==="
verilator --cc --exe --build -j 0 --top-module top --trace \
	--Mdir "$B/sw" top.v tb_vcd.cpp > "$B/sw.log" 2>&1
"$B/sw/Vtop" > "$B/sw.run" 2>&1
if [ -f /tmp/top.vcd ] && grep -q '\$var .* a \$end' /tmp/top.vcd && grep -q '\$var .* b \$end' /tmp/top.vcd && grep -q '\$var .* f \$end' /tmp/top.vcd; then
	ok 'switch 的 VCD 生成且包含 a、b、f 的 $var 声明'
else
	no 'switch 的 VCD 生成且包含 a、b、f 的 $var 声明' '/tmp/top.vcd 缺失或 $var 不全'
fi
cp /tmp/top.vcd "$B/top.vcd" 2>/dev/null
if grep -qE '^#[0-9]+$' "$B/top.vcd" && grep -qE '^[01]["#$]$' "$B/top.vcd"; then
	ok 'VCD 含时间戳与值变化行'
else
	no 'VCD 含时间戳与值变化行' '找不到 #时间戳 或 值变化行'
fi

echo "=== 第 2 节 FST 与体积对比 ==="
verilator --cc --exe --build -j 0 --top-module cnt --trace \
	--Mdir "$B/cv" cnt.v tb_cnt.cpp > "$B/cv.log" 2>&1
verilator --cc --exe --build -j 0 --top-module cnt --trace-fst \
	-CFLAGS -DUSE_FST --Mdir "$B/cf" cnt.v tb_cnt.cpp > "$B/cf.log" 2>&1
"$B/cv/Vcnt" > "$B/cv.run" 2>&1
"$B/cf/Vcnt" > "$B/cf.run" 2>&1
if [ -f /tmp/cnt.vcd ] && [ -f /tmp/cnt.fst ] && grep -q 'final out = 10000' "$B/cv.run" && grep -q 'final out = 10000' "$B/cf.run"; then
	ok 'cnt 的 VCD 与 FST 均生成（一万拍）'
else
	no 'cnt 的 VCD 与 FST 均生成（一万拍）' "vcd/fst 缺失或计数不是 10000"
fi
vcdsz=$(stat -c %s /tmp/cnt.vcd 2>/dev/null || echo 0)
fstsz=$(stat -c %s /tmp/cnt.fst 2>/dev/null || echo 0)
ratio=$(( vcdsz / (fstsz > 0 ? fstsz : 1) ))
if [ "$fstsz" -gt 0 ] && [ "$ratio" -ge 5 ]; then
	ok 'FST 比 VCD 小（判据至少 5 倍）'
	printf '        实得 vcd=%s fst=%s 比=%s\n' "$vcdsz" "$fstsz" "$ratio"
else
	no 'FST 比 VCD 小（判据至少 5 倍）' "vcd=$vcdsz fst=$fstsz 比=$ratio"
fi
cp /tmp/cnt.vcd "$B/cnt.vcd" 2>/dev/null; cp /tmp/cnt.fst "$B/cnt.fst" 2>/dev/null

echo "=== 第 4 节 make sim 一键仿真 ==="
make sim > "$B/make.log" 2>&1
rc=$?
if [ "$rc" -eq 0 ] && [ "$(grep -c 'f=' "$B/make.log")" -ge 4 ]; then
	ok 'make sim 一键完成编译与运行（退出码 0 且打印四行真值表）'
else
	no 'make sim 一键完成编译与运行（退出码 0 且打印四行真值表）' "make 退出码 $rc"
fi

echo "=== 第 5 节 iverilog 对照 ==="
# 真值表一致
verilator --cc --exe --build -j 0 --top-module top --Mdir "$B/tv" top.v tb_table.cpp > "$B/tv.log" 2>&1
"$B/tv/Vtop" > "$B/tabv.run" 2>&1
iverilog -o "$B/tabi" top.v tb_top_iv.v 2> "$B/tabi.err" && vvp "$B/tabi" > "$B/tabi.run" 2>&1
if diff -q <(grep '^a=' "$B/tabv.run" | sort) <(grep '^a=' "$B/tabi.run" | sort) >/dev/null 2>&1; then
	ok 'iverilog 与 verilator 对同一开关打印同一张真值表'
else
	no 'iverilog 与 verilator 对同一开关打印同一张真值表' '两张表不一致'
fi
# 四态对两态
verilator --cc --exe --build -j 0 --top-module xu --Mdir "$B/xv" xu.v tb_xu.cpp > "$B/xv.log" 2>&1
"$B/xv/Vxu" > "$B/xuv.run" 2>&1
iverilog -o "$B/xui" xu.v tb_xu_iv.v 2> "$B/xui.err" && vvp "$B/xui" > "$B/xui.run" 2>&1
if grep -q 'r=x' "$B/xui.run"; then
	ok '未初始化的 r：iverilog 打印 x'
else
	no '未初始化的 r：iverilog 打印 x' "实得 $(cat "$B/xui.run")"
fi
if grep -q 'r=0' "$B/xuv.run"; then
	ok '未初始化的 r：verilator 打印 0'
else
	no '未初始化的 r：verilator 打印 0' "实得 $(cat "$B/xuv.run")"
fi
# 延迟：iverilog 原生，q 在 t=20 才变
iverilog -o "$B/lti" late.v tb_late_iv.v 2> "$B/lti.err" && vvp "$B/lti" > "$B/lti.run" 2>&1
if grep -q 't=10000 d=1 q=x' "$B/lti.run" && grep -q 't=20000 d=1 q=1' "$B/lti.run"; then
	ok '带 #5 的设计：iverilog 原生仿真，q 在 t=20000ps 才变 1'
else
	no '带 #5 的设计：iverilog 原生仿真，q 在 t=20000ps 才变 1' 'monitor 序列里找不到 t=10000 q=x 与 t=20000 q=1'
fi
# 延迟：verilator 显式关掉 timing 并开 -Wall，赋值内延迟报 ASSIGNDLY
verilator --lint-only --no-timing -Wall late.v > "$B/nt.log" 2>&1
rc=$?
if [ "$rc" -ne 0 ] && grep -q 'Warning-ASSIGNDLY' "$B/nt.log"; then
	ok 'verilator --no-timing -Wall 对赋值内延迟报 ASSIGNDLY 并失败'
else
	no 'verilator --no-timing -Wall 对赋值内延迟报 ASSIGNDLY 并失败' "退出码 $rc"
fi
# 延迟：verilator 带 --timing，#5 在 20000ps 生效
verilator --cc --exe --build -j 0 --timing --top-module late --Mdir "$B/ltv" late.v tb_late.cpp > "$B/ltv.log" 2>&1
"$B/ltv/Vlate" > "$B/latev.run" 2>&1
rc=$?
if [ "$rc" -eq 0 ] && grep -q 't=15000 q=0' "$B/latev.run" && grep -q 't=19000 q=0' "$B/latev.run" && grep -q 't=20000 q=1' "$B/latev.run"; then
	ok '带 --timing 运行：#5 生效，t=19000 仍为 0，t=20000 变 1'
else
	no '带 --timing 运行：#5 生效，t=19000 仍为 0，t=20000 变 1' "退出码 $rc，输出 $(head -c 160 "$B/latev.run")"
fi

echo
printf '  %d PASS / %d FAIL / %d SKIP\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
