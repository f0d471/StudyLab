#!/bin/bash
# fundamentals/01（Verilator 生成的模型与 eval）的判据自动核对
#
# 用法：在沙箱里 bash check.sh
# 从源码重建一切（产物清单、端口类型、层次命名、eval 调试轨迹、静态排序、收敛上限、
# 输入与时钟同拍、延迟与 --timing），逐条核对。产物全部落在 build/，开头先清空。
# 各节标题里的"第 N 节"就是正文的小节号。
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

# 从调试轨迹里截出两个标记之间的那一段
between() { awk -v s="== $2" -v e="== $3" 'index($0, s) == 1 { on = 1; next } index($0, e) == 1 { on = 0 } on' "$1"; }
# 只留 eval 各区的函数名，按出现顺序用空格连起来
regions() { grep -oE '___eval_(static|initial|stl|sample|ico|act|inact|nba|obs|react|postponed|final)$' | sed 's/___eval_//' | tr '\n' ' ' | sed 's/ $//'; }
# 取出生成代码里某个函数的整段（从函数名那一行到下一个顶格的 }）
func() { awk -v f="$2(" 'index($0, f) && /^[A-Za-z]/ { on = 1 } on { print } on && /^}/ { exit }' "$1"; }

command -v verilator >/dev/null 2>&1 || { echo "找不到 verilator：本脚本要在沙箱里运行"; exit 1; }

VL="verilator --cc --exe --build -j 0 -Wall"
B=build
rm -rf "$B" && mkdir -p "$B"
INC="$(verilator --getenv VERILATOR_ROOT)/include"

echo "=== 环境 ==="
echo "  $(verilator --version)"
echo "  $(g++ --version | head -1)；$(make --version | head -1)"
echo "  $(. /etc/os-release && echo "$PRETTY_NAME")，内核 $(uname -r)"
echo "  运行库头文件：$INC"
has "Verilator 版本是 5.052（本篇的生成代码与行号按这个版本写）" "$(verilator --version)" '^Verilator 5\.052 '
echo

echo "=== 构建 ==="
verilator --cc -Wall --Mdir $B/cc top.v                > $B/cc.log 2>&1  || die "top.v 只做 --cc 失败"
verilator --cc -Wall --Mdir $B/w  widths.v             > $B/w.log 2>&1   || die "widths.v 失败"
verilator --cc -Wall --Mdir $B/h  hier.v sub.v         > $B/h.log 2>&1   || die "hier.v sub.v 失败"
$VL --runtime-debug --Mdir $B/tr tb_trace.cpp top.v   > $B/tr.log 2>&1  || die "eval 轨迹版构建失败"
$VL --Mdir $B/ch tb_chain.cpp chain.v                 > $B/ch.log 2>&1  || die "chain 构建失败"
verilator --cc -Wall --Mdir $B/cp chain_pub.v          > $B/cp.log 2>&1  || die "chain_pub.v 失败"
verilator --cc -Wall --Mdir $B/cf chain_flat.v         > $B/cf.log 2>&1  || die "chain_flat.v 失败"
$VL -Wno-UNOPTFLAT --converge-limit 50 --Mdir $B/lp tb_loop.cpp loop.v > $B/lp.log 2>&1 || die "loop 构建失败"
$VL --Mdir $B/sq tb_seq.cpp seq.v                     > $B/sq.log 2>&1  || die "seq 构建失败"
$VL --runtime-debug --Mdir $B/sqd tb_seq.cpp seq.v    > $B/sqd.log 2>&1 || die "seq 轨迹版构建失败"
verilator --binary -j 0 -Wall --Mdir $B/d dly.v        > $B/d.log 2>&1   || die "dly.v --binary 失败"
echo "  完成"
echo

echo "=== 第 1 节 obj_dir 里有什么：只做 --cc 的产物清单 ==="
echo "  $(ls $B/cc | tr '\n' ' ')"
MISS=""
for f in Vtop.h Vtop.cpp Vtop___024root.h Vtop___024root__0.cpp Vtop___024root__0__Slow.cpp \
         Vtop___024root__Slow.cpp Vtop__Syms.h Vtop__Syms__Slow.cpp Vtop__pch.h \
         Vtop.mk Vtop_classes.mk Vtop__ver.d Vtop__verFiles.dat; do
	[ -f $B/cc/$f ] || MISS="$MISS $f"
done
eq "清单上的 13 个产物都在（缺失的列在这里）" "$MISS" ""
eq "产物总数正好 13 个" "$(ls $B/cc | wc -l)" "13"
H=$(cat $B/cc/Vtop.h); CPP=$(cat $B/cc/Vtop.cpp)
has "Vtop.h：eval() 只是调 eval_step()" "$H" 'void eval\(\) \{ eval_step\(\); \}'
has "Vtop.h：没开波形时 eval_end_step() 是空函数" "$H" 'void eval_end_step\(\) \{\}'
has "Vtop.h：rootp 指向设计内部的 Vtop___024root" "$H" 'Vtop___024root\* const rootp;'
has "Vtop.h：端口 a 是引用（带 &）" "$H" 'VL_IN8\(&a,0,0\);'
has "Vtop.cpp：端口引用绑到 rootp 那边的同名成员" "$CPP" ', a\{vlSymsp->TOP\.a\}'
has "Vtop.cpp：收敛上限默认 10000" "$CPP" 'convergeLimit:\*/ 10000\}'
has "Vtop.cpp：没有延迟的设计 eventsPending() 恒为 false" "$CPP" 'bool Vtop::eventsPending\(\) \{ return false; \}'
echo

echo "=== 第 2 节 端口宽度决定 C++ 类型 ==="
W=$(cat $B/w/Vwidths.h)
has "1 位  -> VL_IN8"   "$W" 'VL_IN8\(&w1,0,0\);'
has "8 位  -> VL_IN8"   "$W" 'VL_IN8\(&w8,7,0\);'
has "9 位  -> VL_IN16"  "$W" 'VL_IN16\(&w9,8,0\);'
has "16 位 -> VL_IN16"  "$W" 'VL_IN16\(&w16,15,0\);'
has "17 位 -> VL_IN"    "$W" 'VL_IN\(&w17,16,0\);'
has "32 位 -> VL_IN"    "$W" 'VL_IN\(&w32,31,0\);'
has "33 位 -> VL_IN64"  "$W" 'VL_IN64\(&w33,32,0\);'
has "64 位 -> VL_IN64"  "$W" 'VL_IN64\(&w64,63,0\);'
has "65 位 -> VL_INW，3 个 32 位字" "$W" 'VL_INW\(&w65,64,0,3\);'
has "VL_OUTW 输出同理" "$W" 'VL_OUTW\(&o,64,0,3\);'
has "调试构建的宽度检查：w33 的掩码是 0ULL" "$(tr -d ' \n' < $B/w/Vwidths___024root__0.cpp)" 'vlSelfRef\.w33&0ULL'
T=$(cat $INC/verilated.h)
has "CData = uint8_t"  "$T" '^using CData = uint8_t;'
has "SData = uint16_t" "$T" '^using SData = uint16_t;'
has "IData = uint32_t" "$T" '^using IData = uint32_t;'
has "QData = uint64_t" "$T" '^using QData = uint64_t;'
has "EData = uint32_t（VlWide 的一个字）" "$T" '^using EData = uint32_t;'
has "VL_IN8 展开成 CData" "$(cat $INC/verilated_types.h)" '#define VL_IN8\(name, msb, lsb\) CData name'
echo

echo "=== 第 3 节 层次信号的 C++ 名字 ==="
eq "hier：build/h 也是 13 个文件，没有 Vhier_sub 开头的" "$(ls $B/h | wc -l) $(ls $B/h | grep -c '^Vhier_sub')" "13 0"
R=$(cat $B/h/Vhier___024root.h)
has "hier 里实例 u_sub 的寄存器 r：hier__DOT__u_sub__DOT__r" "$R" 'CData/\*7:0\*/ hier__DOT__u_sub__DOT__r;'
$VL --Mdir $B/hr tb_hier.cpp hier.v sub.v > $B/hr.log 2>&1; RC=$?
eq "tb_hier.cpp（包含 Vhier___024root.h，经 rootp 读 r）构建成功" "$RC" "0"
eq "tb_hier 读到 r = 5a" "$($B/hr/Vhier 2>&1)" "r=5a"
echo

echo "=== 第 4 节 一次 eval 里发生了什么（--runtime-debug + +verilator+debug） ==="
$B/tr/Vtop +verilator+debug > $B/trace.txt 2>&1; RC=$?
eq "轨迹程序退出码 0" "$RC" "0"
eq "trace.txt 一共 136 行" "$(wc -l < $B/trace.txt)" "136"
E1=$(between $B/trace.txt E1 E2)
eq "E1 第一次 eval：先初始化，再按区走一遍" "$(regions <<< "$E1")" "static initial stl stl sample ico ico act inact nba obs react postponed"
has "E1：初始化只在第一次 eval 出现" "$E1" '^-V\{t1,[0-9]+\}\+ Initial$'
has "E1：stl 区第一次调用 index 0 为 1" "$E1" "'stl' region trigger index 0 is active: Internal 'stl' trigger - first iteration"
has "E1：ico 第一次调用 index 0（a）为 1" "$E1" "'ico' region trigger index 0 is active: @\( a\)"
has "E1：ico 第一次调用 index 1（b）为 1" "$E1" "'ico' region trigger index 1 is active: @\( b\)"
has "eval_static 把此刻的 a、b 记成上次的值" "$(func $B/tr/Vtop___024root__0__Slow.cpp Vtop___024root___eval_static | tr -d ' \n')" 'vlSelfRef\.__Vtrigprevexpr___TOP__a__0=vlSelfRef\.a;vlSelfRef\.__Vtrigprevexpr___TOP__b__0=vlSelfRef\.b;'
has "ico 第一次被调用（__VicoDidInit 为 0）时把第 0、1 位强制置 1" "$(tr -d ' \n' < $B/tr/Vtop___024root__0.cpp)" 'if\(VL_UNLIKELY\(\(\(1U&\(~\(IData\)\(vlSelfRef\.__VicoDidInit\)\)\)\)\)\)\{vlSelfRef\.__VicoDidInit=1U;vlSelfRef\.__VicoTriggered\[0U\]=\(1ULL\|vlSelfRef\.__VicoTriggered\[0U\]\);vlSelfRef\.__VicoTriggered\[0U\]=\(2ULL\|vlSelfRef\.__VicoTriggered\[0U\]\);\}'
E2=$(between $B/trace.txt E2 E3)
eq "E2 只改 b：不再初始化，ico 调用两次，其余各区各一次" "$(regions <<< "$E2")" "sample ico ico act inact nba obs react postponed"
hasnt "E2：没有 Initial" "$E2" '\+ Initial$'
has "E2：index 1（b）为 1" "$E2" "trigger index 1 is active: @\( b\)"
hasnt "E2：index 0（a）不为 1" "$E2" "trigger index 0 is active"
E3=$(between $B/trace.txt E3 E4)
hasnt "E3 什么都没改：index 0、1 都不为 1" "$E3" "trigger index [01] is active"
has "E3：只有 index 64 的内部位" "$E3" "trigger index 64 is active: Internal 'ico' trigger - first iteration"
eq "E1 至 E5 之后的 f 依次是 1 0 0 7 1" "$(grep -E '^after E[1-5]: f=' $B/trace.txt | sed 's/.*=//' | tr '\n' ' ')" "1 0 0 7 1 "
has "final() 调的是 eval_final" "$(between $B/trace.txt END ZZZ)" '___eval_final$'
echo

echo "=== 第 5 节 静态排序：源码顺序倒着写，一次 eval 也对 ==="
eq "chain 真值表（f = ~(a^b) & a）" "$($B/ch/Vchain | tr '\n' ' ')" "a=0 b=0 f=0 a=0 b=1 f=0 a=1 b=0 f=0 a=1 b=1 f=1 "
J=$(tr -d ' \n' < $B/ch/Vchain___024root__0.cpp)
has "三条 assign 被并成一条 C++ 表达式" "$J" 'vlSelfRef\.f=\(\(~\(\(IData\)\(vlSelfRef\.a\)\^\(IData\)\(vlSelfRef\.b\)\)\)&\(IData\)\(vlSelfRef\.a\)\);'
eq "中间线 t1、t2 在模型里不存在" "$(grep -c 't1\|t2' $B/ch/Vchain___024root.h)" "0"
eq "public：build/cp 有 19 个文件" "$(ls $B/cp | wc -l)" "19"
has "t1 加 /*verilator public*/：模块不再被并进 root，单独成类，root 里只留一个指针" "$(cat $B/cp/Vchain_pub___024root.h)" 'Vchain_pub_chain_pub\* chain_pub;'
CP=$(cat $B/cp/Vchain_pub_chain_pub.h)
has "public：t1 是那个类的成员" "$CP" 'CData/\*0:0\*/ t1;'
hasnt "public：没加标记的 t2 照样被优化掉" "$CP" 't2'
$VL --Mdir $B/cpr tb_pub.cpp chain_pub.v > $B/cpr.log 2>&1; RC=$?
eq "tb_pub.cpp（包含 Vchain_pub_chain_pub.h，读 top->chain_pub->t1）构建成功" "$RC" "0"
eq "tb_pub：a=1 b=0 时读到 t1=1，f=0" "$($B/cpr/Vchain_pub 2>&1)" "t1=1 f=0"
eq "public_flat：build/cf 有 15 个文件" "$(ls $B/cf | wc -l)" "15"
CF=$(cat $B/cf/Vchain_flat___024root.h)
has "t1 加 /*verilator public_flat*/：留在 root 里，名字是 chain_flat__DOT__t1" "$CF" 'CData/\*0:0\*/ chain_flat__DOT__t1;'
hasnt "public_flat：t2 照样被优化掉" "$CF" 't2'
eq "public_flat：没有生成单独的模块类" "$(ls $B/cf | grep -c '^Vchain_flat_chain_flat')" "0"
eq "public_flat：ico 区里先算 t1、后算 f（源码里 f 写在最前）" "$(grep -oE 'vlSelfRef\.(chain_flat__DOT__t1|f) = ' $B/cf/Vchain_flat___024root__0.cpp | sed 's/vlSelfRef\.//; s/ = //' | tr '\n' ' ')" "chain_flat__DOT__t1 f "
$VL --Mdir $B/cfr tb_flat.cpp chain_flat.v > $B/cfr.log 2>&1; RC=$?
eq "tb_flat.cpp（包含 Vchain_flat___024root.h，经 rootp 读 t1）构建成功" "$RC" "0"
eq "tb_flat：a=1 b=0 时读到 t1=1，f=0" "$($B/cfr/Vchain_flat 2>&1)" "t1=1 f=0"
echo

echo "=== 第 6 节 收敛上限：--converge-limit ==="
has "生成代码里收敛上限改成了 50" "$(cat $B/lp/Vloop.cpp)" 'convergeLimit:\*/ 50\}'
$B/lp/Vloop > $B/lp.txt 2>&1; RC=$?
eq "en 一开始就是 1：在第一次 eval 的 Settle 区就转不停，试满 50 次报错" "$(grep DIDNOTCONVERGE $B/lp.txt)" "%Error-DIDNOTCONVERGE: Settle region did not converge after '--converge-limit' of 50 tries"
eq "退出码 1" "$RC" "1"
echo

echo "=== 第 7 节 输入和时钟在同一次 eval 里变 ==="
SQ=$($B/sq/Vseq)
eq "同一次 eval 里 in 1->0、clk 0->1：q 取到新的 d = 1" "$(grep '^same eval' <<< "$SQ")" "same eval:     q=1"
eq "先改 in 并 eval，再单独给上升沿：q 取到 d = 0" "$(grep '^separate eval' <<< "$SQ")" "separate eval: q=0"
has "生成代码里 d 被并进了 q 的赋值" "$(tr -d ' \n' < $B/sq/Vseq___024root__0.cpp)" 'vlSelfRef\.q=\(1U&\(~\(IData\)\(vlSelfRef\.in\)\)\);'
$B/sqd/Vseq +verilator+debug > $B/seqtrace.txt 2>&1; RC=$?
eq "seq 轨迹程序退出码 0" "$RC" "0"
eq "S1 第一次 eval（clk=0）：ico 一次，act 到 nba 一圈" "$(between $B/seqtrace.txt S1 S2 | regions)" "static initial stl sample ico act inact nba obs react postponed"
S2=$(between $B/seqtrace.txt S2 S3)
eq "S2 上升沿：act、inact、nba 转两圈" "$(regions <<< "$S2")" "sample ico act inact nba act inact nba obs react postponed"
has "S2：act 区因 posedge clk 触发" "$S2" "'act' region trigger index 0 is active: @\(posedge clk\)"
eq "S3 下降沿：act 到 nba 一圈" "$(between $B/seqtrace.txt S3 S4 | regions)" "sample ico act inact nba obs react postponed"
hasnt "S3：act 区没有触发" "$(between $B/seqtrace.txt S3 S4)" "'act' region trigger index 0 is active"
echo

echo "=== 第 8 节 延迟：--timing、--no-timing 与 --binary ==="
verilator --cc -Wall --Mdir $B/d1 dly.v > $B/d1.log 2>&1; RC=$?
if [ "$RC" -ne 0 ]; then ok "不说怎么处理延迟：构建失败（退出码 $RC）"; else no "不给 timing 选项应失败" "退出码 0"; fi
has "原因是 NEEDTIMINGOPT" "$(cat $B/d1.log)" '%Error-NEEDTIMINGOPT: dly\.v:3:5: Use --timing or --no-timing to specify how delays should be handled'
verilator --cc --no-timing --Mdir $B/d2 dly.v > $B/d2.log 2>&1; RC=$?
if [ "$RC" -ne 0 ]; then ok "--no-timing 不加 -Wall：构建照样失败（退出码 $RC）"; else no "--no-timing 不加 -Wall 应失败" "退出码 0"; fi
has "原因是 STMTDLY 警告，警告让 Verilator 以错误退出" "$(cat $B/d2.log)" '%Warning-STMTDLY: dly\.v:3:5: Ignoring delay on this statement due to --no-timing'
has "d2.log 的最后一行：Exiting due to 1 warning(s)" "$(tail -1 $B/d2.log)" '^%Error: Exiting due to 1 warning\(s\)$'
verilator --binary -j 0 -Wall --no-timing -Wno-STMTDLY --Mdir $B/d3 dly.v > $B/d3.log 2>&1; RC=$?
eq "--binary --no-timing -Wno-STMTDLY：构建成功" "$RC" "0"
has "--no-timing 时 VM_TIMING = 0" "$(cat $B/d3/Vdly_classes.mk 2>&1)" '^VM_TIMING = 0$'
$B/d3/Vdly > $B/d3.txt 2>&1
eq "--no-timing：#10 被忽略，打印 t=0 hello" "$(head -1 $B/d3.txt)" "t=0 hello"
has "--no-timing：\$finish 发生在 0s" "$(cat $B/d3.txt)" 'Verilator: \$finish at 0s'
has "--binary 自动生成了 main：Vdly__main.cpp" "$(ls $B/d)" '^Vdly__main\.cpp$'
has "--binary 打开了 timing：VM_TIMING = 1" "$(cat $B/d/Vdly_classes.mk)" '^VM_TIMING = 1$'
has "有延迟的设计 eventsPending() 去查调度队列" "$(cat $B/d/Vdly.cpp)" 'bool Vdly::eventsPending\(\) \{ return !vlSymsp->TOP\.__VdlySched\.empty\(\)'
$B/d/Vdly > $B/d.txt 2>&1; RC=$?
eq "#10 之后打印，\$time 是 10" "$(head -1 $B/d.txt)" "t=10 hello"
has "\$finish 发生在 10ps" "$(cat $B/d.txt)" 'Verilator: \$finish at 10ps'
eq "退出码 0" "$RC" "0"
echo

printf '  %d PASS / %d FAIL / %d SKIP（用时 %d 秒）\n' "$PASS" "$FAIL" "$SKIP" "$SECONDS"
[ "$FAIL" -eq 0 ]
