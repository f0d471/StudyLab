#!/bin/bash
# tutorials/E/04-仿真与验证/01-Verilator把电路变成程序.md 的判据自动核对
#
# 用法：在沙箱里 bash check.sh
# 从源码重建一切（手册示例、$finish 之后的语句、双控开关、eval 探针、四种注错、无限循环、组合环），逐条核对。
# 产物全部落在 build/，开头先清空，所以每次都是从零构建。
# 各节标题里的"第 N 节"就是正文的小节号。第 6 节是正文第 6 节的四种注错，由本脚本自己构建。
# 正文各节"注错见红"写的改坏由同目录的 mutate.sh 逐项实跑。

cd "$(dirname "$0")" || exit 1

PASS=0; FAIL=0; SKIP=0
ok()   { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
no()   { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '        %s\n' "$2"; }
skip() { SKIP=$((SKIP+1)); printf '  SKIP  %s\n' "$1"; }
eq()   { if [ "$2" = "$3" ]; then ok "$1"; else no "$1" "期望 $3，实得 $2"; fi; }
has()  { if grep -qE -e "$3" <<< "$2"; then ok "$1"; else no "$1" "输出里找不到 $3"; fi; }
hasnt(){ if grep -qE -e "$3" <<< "$2"; then no "$1" "输出里不该有 $3"; else ok "$1"; fi; }

die() {
	FAIL=$((FAIL+1))
	printf '  FAIL  构建：%s\n\n  %d PASS / %d FAIL / %d SKIP（构建没过）\n' "$1" "$PASS" "$FAIL" "$SKIP"
	exit 1
}

# 独立判据：不信程序自己的 assert，逐行重算 f 是否等于 a 异或 b，输出不对的行数
bad_lines() { awk -F'[=,]' '/^a = /{ if ($6+0 != (($2+0) != ($4+0))) n++ } END { print n+0 }' "$1"; }

command -v verilator >/dev/null 2>&1 || { echo "找不到 verilator：本脚本要在沙箱里运行"; exit 1; }

VL="verilator --cc --exe --build -j 0 -Wall"
VLN="verilator --cc --exe --build -j 0"
B=build
rm -rf "$B" && mkdir -p "$B"

echo "=== 环境 ==="
{
	echo "$(verilator --version)"
	echo "路径：$(command -v verilator)"
	echo "$(g++ --version | head -1)；$(make --version | head -1)；$(awk --version | head -1 | cut -d, -f1)"
	echo "$(. /etc/os-release && echo "$PRETTY_NAME")，内核 $(uname -r)"
	echo "timeout：$(timeout --version 2>&1 | head -1)；script：$(script --version 2>&1 | head -1)"
} > $B/env.txt
sed 's/^/  /' $B/env.txt
timeout --help > $B/timeout-help.txt 2>&1
echo

echo "=== 构建 ==="
verilator --cc -Wall --Mdir $B/cconly our.v            > $B/cconly.log 2>&1 || die "只做 --cc 失败（见 $B/cconly.log）"
$VL --Mdir $B/our     sim_main.cpp our.v              > $B/our.log 2>&1     || die "手册示例构建失败（见 $B/our.log）"
CCACHE_DISABLE=1 $VL --Mdir $B/ournc sim_main.cpp our.v > $B/ournc.log 2>&1 || die "手册示例（不用 ccache）构建失败（见 $B/ournc.log）"
mkdir -p $B/fin && sed 's/Vour/Vfin/g' sim_main.cpp > $B/fin/sim_main.cpp
$VL --Mdir $B/fin/obj $B/fin/sim_main.cpp fin.v       > $B/fin.log 2>&1     || die "\$finish 之后还有语句的示例构建失败（见 $B/fin.log）"
$VL --Mdir $B/switch  tb_switch.cpp top.v             > $B/switch.log 2>&1  || die "双控开关构建失败（见 $B/switch.log）"
$VL --Mdir $B/forever tb_forever.cpp top.v            > $B/forever.log 2>&1 || die "无限循环版构建失败（见 $B/forever.log）"
$VL --Mdir $B/eval    tb_eval.cpp top.v               > $B/eval.log 2>&1    || die "eval 探针构建失败（见 $B/eval.log）"
$VL --Mdir $B/evaldbg --runtime-debug tb_eval.cpp top.v > $B/evaldbg.log 2>&1 || die "eval 探针调试版构建失败（见 $B/evaldbg.log）"
$VL --Mdir $B/loop    -Wno-UNOPTFLAT tb_loop.cpp loop.v > $B/loop.log 2>&1  || die "组合环（关掉 UNOPTFLAT）构建失败（见 $B/loop.log）"
echo "  完成"
echo

echo "=== 第 1 节 版本 ==="
eq "Verilator 版本是本章实测的 5.052" "$(verilator --version)" "Verilator 5.052 2026-09-05 rev 5.052-983a06a"
echo

echo "=== 第 2 节 手册示例：Verilog 到 C++ 到可执行文件 ==="
C=$B/cconly
if [ -f $C/Vour.h ] && [ -f $C/Vour.cpp ] && [ -f $C/Vour.mk ]; then ok "只给 --cc：产出 Vour.h、Vour.cpp、Vour.mk"; else no "只给 --cc 的产物" "缺 Vour.h/Vour.cpp/Vour.mk"; fi
eq "只给 --cc：一共 13 个文件" "$(ls $C | wc -l)" "13"
if [ ! -e $C/Vour ] && [ -z "$(ls $C/*.o 2>/dev/null)" ]; then ok "只给 --cc：没有 .o，也没有可执行文件"; else no "只给 --cc 不该编译" "$C 里出现了 .o 或 Vour"; fi
has "只给 --cc：报告里编译耗时 bld=0.000" "$(cat $B/cconly.log)" 'bld=0\.000\)'
eq "生成的 5 个 .cpp 都包含 Vour__pch.h" "$(grep -l '^#include "Vour__pch.h"' $C/*.cpp | wc -l)" "5"
has "加 --exe --build：make 调用 g++ 把四样东西链成 Vour" "$(cat $B/our.log)" '^g\+\+ +sim_main\.o verilated\.o verilated_threads\.o Vour__ALL\.a .*-o Vour$'
eq "Vour__ALL.cpp：1 行注释、1 行 #define、5 行 #include" "$(grep -c '^//' $B/our/Vour__ALL.cpp) $(grep -c '^#define' $B/our/Vour__ALL.cpp) $(grep -c '^#include' $B/our/Vour__ALL.cpp)" "1 1 5"
BLD1=$(grep -oE 'bld=[0-9.]+' $B/our.log | cut -d= -f2)
BLD2=$(grep -oE 'bld=[0-9.]+' $B/ournc.log | cut -d= -f2)
echo "  用 ccache：$(grep -oE 'Walltime [0-9.]+ s \([^)]*\)' $B/our.log)"
echo "  不用 ccache：$(grep -oE 'Walltime [0-9.]+ s \([^)]*\)' $B/ournc.log)"
if awk -v a="$BLD1" -v b="$BLD2" 'BEGIN { exit !(a > 0 && b > 2 * a) }'; then ok "不用 ccache 时 bld 至少是用 ccache 时的 2 倍（实得 $BLD2 与 $BLD1 秒）"; else no "ccache 的效果" "用 ccache bld=$BLD1，不用 ccache bld=$BLD2"; fi
file $B/our/Vour > $B/file.txt
has "Vour 是一个普通的 x86-64 ELF 可执行文件" "$(cat $B/file.txt)" 'ELF 64-bit LSB .*executable, x86-64'
eq "Vour 的大小（本机工具链）：230880 字节" "$(stat -c %s $B/our/Vour)" "230880"
S=$(cat $B/our/Vour___024root__0__Slow.cpp)
has "生成代码：\$display 变成 VL_WRITEF_NX" "$S" 'VL_WRITEF_NX\("Hello World\\n",0\);'
has "生成代码：\$finish 变成 VL_FINISH_MT，带着文件名和行号 2" "$S" 'VL_FINISH_MT\("our\.v", 2, ""\);'
OUT=$($B/our/Vour 2>&1); RC=$?
eq "运行 Vour：退出码 0" "$RC" "0"
eq "运行 Vour：第 1 行是 \$display 的 Hello World" "$(printf '%s\n' "$OUT" | sed -n 1p)" "Hello World"
eq "运行 Vour：第 2 行是 \$finish 的报告" "$(printf '%s\n' "$OUT" | sed -n 2p)" "- our.v:2: Verilog \$finish"
eq "运行 Vour：一共 2 行" "$(printf '%s\n' "$OUT" | wc -l)" "2"
OUT=$($B/fin/obj/Vfin 2>&1); RC=$?
eq "fin.v：第 1 行是 before" "$(printf '%s\n' "$OUT" | sed -n 1p)" "before"
eq "fin.v：\$finish 的报告紧跟在 before 后面，当场打印" "$(printf '%s\n' "$OUT" | sed -n 2p)" "- fin.v:2: Verilog \$finish"
eq "fin.v：\$finish 之后的 \$display 照样执行，第 3 行是 after" "$(printf '%s\n' "$OUT" | sed -n 3p)" "after"
eq "fin.v：一共 3 行" "$(printf '%s\n' "$OUT" | wc -l)" "3"
eq "fin.v：退出码 0" "$RC" "0"
echo

echo "=== 第 3 节 端口变成 C++ 成员，assign 变成 C++ 赋值 ==="
H=$(cat $B/switch/Vtop.h)
has "端口 a 是 8 位成员（宽 1 位）" "$H" 'VL_IN8\(&a,0,0\);'
has "端口 b 是 8 位成员（宽 1 位）" "$H" 'VL_IN8\(&b,0,0\);'
has "端口 f 是 8 位成员（宽 1 位）" "$H" 'VL_OUT8\(&f,0,0\);'
J=$(tr -d ' \n' < $B/switch/Vtop___024root__0.cpp)
has "assign f = a ^ b 变成了一行 C++ 赋值" "$J" 'vlSelfRef\.f=\(\(IData\)\(vlSelfRef\.a\)\^\(IData\)\(vlSelfRef\.b\)\);'
echo

echo "=== 第 4 节 eval 探针：不调 eval 就不算 ==="
$B/eval/Vtop > $B/eval.txt 2>&1; RC=$?
E=$(cat $B/eval.txt)
has "P0 刚构造：输入输出都是 0" "$E" '^P0 .*a=0 b=0 f=0$'
has "P1 改了输入但没调 eval：f 还是 0" "$E" '^P1 .*f=0$'
has "P2 调了 eval：f 变成 1" "$E" '^P2 .*f=1$'
has "P3 输入没变再调一次：f 仍是 1" "$E" '^P3 .*f=1$'
has "P4 整个过程仿真时间没有走：0" "$E" '^P4 .* 0$'
has "P5 普通构建：给 1 位端口写 2，不报错，f 算成 2" "$E" '^P5 .*f=2$'
eq "eval 探针一共打印 6 行" "$(wc -l < $B/eval.txt)" "6"
eq "普通构建：退出码 0" "$RC" "0"
$B/eval/Vtop +verilator+rand+reset+1 > $B/eval_ones.txt 2>&1
has "P0 的 0 来自运行时默认：加 +verilator+rand+reset+1 运行，P0 变成全 1" "$(cat $B/eval_ones.txt)" '^P0 .*a=1 b=1 f=1$'
CN=$(grep -c ' -c -o ' $B/evaldbg.log)
CF=$(grep ' -c -o ' $B/evaldbg.log | grep -c -- '-ggdb -fsanitize=address,undefined -D_GLIBCXX_DEBUG -DVL_DEBUG=1 ')
eq "调试构建：每条 g++ 编译命令多了 -ggdb -fsanitize=address,undefined -D_GLIBCXX_DEBUG -DVL_DEBUG=1" "$CF" "$CN"
has "调试构建：链接命令也带 -fsanitize=address,undefined" "$(grep -e '-o Vtop$' $B/evaldbg.log)" '-fsanitize=address,undefined'
has "普通构建的生成代码里也写着这条检查（被 #ifdef VL_DEBUG 包住）" "$(cat $B/eval/Vtop___024root__0.cpp)" 'overWidthError\("a"\)'
$B/evaldbg/Vtop > $B/evaldbg.txt 2>&1; RC=$?
D=$(cat $B/evaldbg.txt)
has "调试构建：写 2 被当场拦下" "$D" "Testbench C set input 'a' to value that overflows what the signal's width can fit"
hasnt "调试构建：P5 那一行没有打印出来" "$D" '^P5 '
if [ "$RC" -ne 0 ]; then ok "调试构建：退出码非 0（实得 $RC）"; else no "调试构建应失败" "退出码 0"; fi
echo

echo "=== 第 5 节 双控开关 testbench：随机驱动、eval、assert ==="
$B/switch/Vtop > $B/run10.txt 2>&1; RC=$?
eq "跑 10 次：退出码 0（assert 一次也没失败）" "$RC" "0"
eq "跑 10 次：打印 10 行 a/b/f" "$(grep -c '^a = ' $B/run10.txt)" "10"
eq "跑 10 次：独立判据逐行重算，不对的行数为 0" "$(bad_lines $B/run10.txt)" "0"
eq "跑 10 次：四种输入组合的出现次数" "$(tail -1 $B/run10.txt)" "seen: 00=3 01=2 10=2 11=3"
$B/switch/Vtop > $B/run10b.txt 2>&1
if cmp -s $B/run10.txt $B/run10b.txt; then ok "rand() 没播种：两次运行逐字节相同"; else no "两次运行应相同" "run10.txt 与 run10b.txt 不同"; fi
$B/switch/Vtop 1000 > $B/run1000.txt 2>&1; RC=$?
eq "跑 1000 次：退出码 0" "$RC" "0"
eq "跑 1000 次：打印 1000 行 a/b/f" "$(grep -c '^a = ' $B/run1000.txt)" "1000"
eq "跑 1000 次：独立判据不对的行数为 0" "$(bad_lines $B/run1000.txt)" "0"
has "跑 1000 次：四种组合都出现过" "$(tail -1 $B/run1000.txt)" '^seen: 00=[1-9][0-9]* 01=[1-9][0-9]* 10=[1-9][0-9]* 11=[1-9][0-9]*$'
echo

echo "=== 第 6 节 注错见红：测试自己能不能报错 ==="
mkdir -p $B/m1 && sed 's/a ^ b/a | b/' top.v > $B/m1/top.v
$VL --Mdir $B/m1/obj tb_switch.cpp $B/m1/top.v > $B/m1/build.log 2>&1 || die "注错 1 构建失败"
{ $B/m1/obj/Vtop > $B/m1/out.txt 2> $B/m1/err.txt; } 2>/dev/null; RC=$?
eq "注错 1（^ 改成 |）：assert 失败，abort 退出码 134" "$RC" "134"
eq "SIGABRT 是 6 号信号" "$(kill -l 6)" "ABRT"
has "注错 1：报错里写着哪一行、哪个条件" "$(cat $B/m1/err.txt)" "tb_switch\.cpp:[0-9]+: int main\(int, char\*\*\): Assertion \`top->f == \(a \^ b\)' failed\."
eq "注错 1：stdout 重定向到文件时，assert 前的打印全丢（abort 不刷缓冲）" "$(wc -l < $B/m1/out.txt)" "0"
if command -v script >/dev/null 2>&1; then
	script -qec "$B/m1/obj/Vtop" /dev/null > $B/m1/pty.txt 2>&1; RC=$?
	eq "注错 1：在伪终端里运行（相当于直接在终端里敲），assert 前的 2 行打印都在" "$(tr -d '\r' < $B/m1/pty.txt | grep -c '^a = ')" "2"
	eq "注错 1：伪终端里退出码同样是 134" "$RC" "134"
else
	skip "注错 1 的伪终端对照：沙箱里没有 script 命令"
	skip "注错 1 的伪终端退出码：沙箱里没有 script 命令"
fi
mkdir -p $B/m2 && sed '/top->eval();/d' tb_switch.cpp > $B/m2/tb_switch.cpp
$VL --Mdir $B/m2/obj $B/m2/tb_switch.cpp top.v > $B/m2/build.log 2>&1 || die "注错 2 构建失败"
{ $B/m2/obj/Vtop > /dev/null 2>&1; } 2>/dev/null; RC=$?
eq "注错 2（删掉 eval）：f 永远是 0，assert 失败，退出码 134" "$RC" "134"
mkdir -p $B/m3 && cp top.v $B/m3/switch.v
$VL --Mdir $B/m3/obj tb_switch.cpp $B/m3/switch.v > $B/m3/build.log 2>&1; RC=$?
if [ "$RC" -ne 0 ]; then ok "注错 3（文件改名 switch.v）：-Wall 下构建失败"; else no "注错 3 应构建失败" "退出码 0"; fi
has "注错 3：原因是 DECLFILENAME" "$(cat $B/m3/build.log)" "%Warning-DECLFILENAME: .*switch\.v:1:8: Filename 'switch' does not match MODULE name: 'top'"
$VLN --Mdir $B/m3/nowall tb_switch.cpp $B/m3/switch.v > $B/m3/nowall.log 2>&1
hasnt "注错 3 对照（不加 -Wall）：DECLFILENAME 默认不开，这条警告没有出现" "$(cat $B/m3/nowall.log)" 'DECLFILENAME'
if [ -f $B/m3/nowall/Vswitch.h ] && [ ! -e $B/m3/nowall/Vtop.h ]; then ok "注错 3 对照：类名取自文件名，生成的是 Vswitch.h，没有 Vtop.h"; else no "注错 3 对照的类名" "没有 Vswitch.h，或者出现了 Vtop.h"; fi
has "注错 3 对照：g++ 编译 tb_switch.cpp 时找不到 Vtop.h" "$(cat $B/m3/nowall.log)" 'fatal error: Vtop\.h: No such file or directory'
$VL -Wno-DECLFILENAME --Mdir $B/m3/nodecl tb_switch.cpp $B/m3/switch.v > $B/m3/nodecl.log 2>&1; RC=$?
if [ "$RC" -ne 0 ] && grep -q 'fatal error: Vtop\.h' $B/m3/nodecl.log && ! grep -q '%Warning-DECLFILENAME' $B/m3/nodecl.log; then ok "注错 3 对照：-Wall -Wno-DECLFILENAME 只关掉警告，类名仍是 Vswitch，构建照样失败"; else no "-Wno-DECLFILENAME 时也应失败在 Vtop.h" "退出码 $RC"; fi
$VLN --top top --Mdir $B/m3/top tb_switch.cpp $B/m3/switch.v > $B/m3/top.log 2>&1; RC=$?
if [ "$RC" -eq 0 ] && [ -f $B/m3/top/Vtop.h ]; then ok "注错 3 的另一种修法：不加 -Wall 时给 --top top，类名回到 Vtop，构建成功"; else no "--top top 应让类名回到 Vtop" "退出码 $RC，或没有 Vtop.h"; fi
$VL --top top --Mdir $B/m3/walltop tb_switch.cpp $B/m3/switch.v > $B/m3/walltop.log 2>&1; RC=$?
if [ "$RC" -ne 0 ] && grep -q '%Warning-DECLFILENAME' $B/m3/walltop.log; then ok "注错 3：加了 -Wall 时 --top top 救不回来，DECLFILENAME 照报，构建失败"; else no "-Wall 加 --top top 应仍因 DECLFILENAME 失败" "退出码 $RC"; fi
$VL -Wno-DECLFILENAME --top top --Mdir $B/m3/walltopnd tb_switch.cpp $B/m3/switch.v > $B/m3/walltopnd.log 2>&1; RC=$?
if [ "$RC" -eq 0 ] && [ -f $B/m3/walltopnd/Vtop.h ]; then ok "注错 3 的第三种修法：-Wall -Wno-DECLFILENAME --top top，构建成功"; else no "-Wall -Wno-DECLFILENAME --top top 应构建成功" "退出码 $RC，或没有 Vtop.h"; fi
mkdir -p $B/m4 && sed '/assert(/d' tb_switch.cpp > $B/m4/tb_switch.cpp
$VL --Mdir $B/m4/obj $B/m4/tb_switch.cpp $B/m1/top.v > $B/m4/build.log 2>&1 || die "注错 4 构建失败"
$B/m4/obj/Vtop > $B/m4/out.txt 2>&1; RC=$?
eq "注错 4（电路改成 |，再删掉 assert）：程序自己发现不了，退出码 0" "$RC" "0"
eq "注错 4：打印 10 行 a/b/f" "$(grep -c '^a = ' $B/m4/out.txt)" "10"
eq "注错 4：独立判据逐行重算，抓出 3 行不对（11 出现 3 次）" "$(bad_lines $B/m4/out.txt)" "3"
echo

echo "=== 第 7 节 没有 \$finish 的循环不会自己停 ==="
eq "SIGINT 是 2 号信号" "$(kill -l 2)" "INT"
has "timeout --help：超时且没加 --preserve-status 时返回 124" "$(cat $B/timeout-help.txt)" '124 +if COMMAND times out, and --preserve-status is not specified'
timeout -s INT 1 $B/forever/Vtop > /dev/null 2>&1; RC=$?
eq "1 秒后仍在运行，被 timeout 发 SIGINT 打断（timeout 返回 124）" "$RC" "124"
timeout --preserve-status -s INT 1 $B/forever/Vtop > /dev/null 2>&1; RC=$?
eq "让 timeout 转交程序自己的退出状态：130 = 128 + 2（SIGINT 是 2 号信号）" "$RC" "130"
N=$(timeout -s INT 1 $B/forever/Vtop 2>/dev/null | wc -l)
if [ "$N" -ge 10000 ]; then ok "1 秒内至少写出 1 万行（实得 $N 行，本机数字）"; else no "1 秒内的行数" "只有 $N 行"; fi
echo

echo "=== 第 8 节 组合环：eval 不一定停得下来 ==="
$VL --Mdir $B/loopwall tb_loop.cpp loop.v > $B/loopwall.log 2>&1; RC=$?
if [ "$RC" -ne 0 ]; then ok "-Wall 下组合环构建失败（退出码 $RC）"; else no "-Wall 下组合环应构建失败" "退出码 0"; fi
has "失败原因是 UNOPTFLAT 警告" "$(cat $B/loopwall.log)" '%Warning-UNOPTFLAT: loop\.v:3:10: Signal unoptimizable: Circular combinational logic'
has "报完警告就以错误退出（Verilator 的警告默认致命）" "$(cat $B/loopwall.log)" '%Error: Exiting due to 1 warning\(s\)'
$VLN --Mdir $B/loopnowall tb_loop.cpp loop.v > $B/loopnowall.log 2>&1; RC=$?
if [ "$RC" -ne 0 ] && grep -q '%Warning-UNOPTFLAT' $B/loopnowall.log; then ok "不加 -Wall 也构建失败：UNOPTFLAT 默认就开着"; else no "不加 -Wall 时组合环也应构建失败" "退出码 $RC，或日志里没有 UNOPTFLAT"; fi
$B/loop/Vloop > $B/loop.txt 2>&1; RC=$?
LP=$(cat $B/loop.txt)
has "en=0：环被切断，eval 收敛，f=0" "$LP" '^en=0: f=0$'
has "en=1：环闭合，eval 报 DIDNOTCONVERGE" "$LP" "%Error-DIDNOTCONVERGE: Input combinational region did not converge after '--converge-limit' of 10000 tries"
hasnt "en=1：那一行 printf 没有机会执行" "$LP" '^en=1'
eq "en=1：退出码 1" "$RC" "1"
echo

printf '  %d PASS / %d FAIL / %d SKIP（用时 %d 秒）\n' "$PASS" "$FAIL" "$SKIP" "$SECONDS"
[ "$FAIL" -eq 0 ]
