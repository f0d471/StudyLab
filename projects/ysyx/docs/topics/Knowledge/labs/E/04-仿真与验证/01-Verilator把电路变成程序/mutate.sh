#!/bin/bash
# check.sh 的注错自检
#
# 用法：在沙箱里 bash mutate.sh（每种注错完整跑一遍 check.sh，本机共约 15 分钟）
# 正文每个 [判] 块末尾的"注错见红"写了改坏哪里、哪几条判据变红。本脚本把每一种改坏
# 做在一份副本上，跑副本的 check.sh，核对变红的判据恰好是正文写的那几条，不多也不少。
# 变红判据里用 eq 比较的，副本给出的实际值也一并打印（"期望 ...，实得 ..."）。
# 第一项"原样"是对照：副本不做改动，一条都不能变红。
# 版本、文件大小、信号编号、timeout 的说明这类环境判据，实验目录里没有可改坏的源码，
# 改的是 check.sh 里的期望值。
# 产物在 build/mut/；check.sh 开头清空 build/ 时会一起删掉，所以两个脚本不要同时跑。

cd "$(dirname "$0")" || exit 1
command -v verilator >/dev/null 2>&1 || { echo "找不到 verilator：本脚本要在沙箱里运行"; exit 1; }

M=build/mut
rm -rf "$M" && mkdir -p "$M"
GOOD=0; BAD=0

# 用法：mut 名字 要改的文件 sed表达式 预期变红的判据...
# 判据名照抄 check.sh 里 FAIL 时打印的那句；sed 表达式为空表示不改。
mut() {
	local name=$1 file=$2 expr=$3; shift 3
	local d=$M/$name got want
	mkdir -p "$d"
	cp ./*.v ./*.cpp check.sh "$d/"
	if [ -n "$expr" ]; then
		sed -i -e "$expr" "$d/$file"
		if cmp -s "$file" "$d/$file"; then
			BAD=$((BAD+1)); printf '  BAD   %s：sed 没有改动 %s\n' "$name" "$file"; return
		fi
	fi
	( cd "$d" && bash check.sh > run.log 2>&1 )
	got=$(grep '^  FAIL  ' "$d/run.log" | sed 's/^  FAIL  //' | sort)
	if [ $# -eq 0 ]; then want=""; else want=$(printf '%s\n' "$@" | sort); fi
	if [ "$got" = "$want" ]; then
		GOOD=$((GOOD+1)); printf '  OK    %s：变红 %d 条，与正文一致\n' "$name" "$#"
		grep '^        期望 ' "$d/run.log"
	else
		BAD=$((BAD+1)); printf '  BAD   %s：变红的判据与正文不一致（< 正文写的，> 实际变红的）\n' "$name"
		diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep '^[<>]' | sed 's/^/        /'
	fi
}

echo "=== 对照 ==="
mut 原样 "" ""

echo "=== 第 1、2 节 ==="
mut 版本改5.051 check.sh 's/"Verilator 5.052 2026-09-05 rev 5.052-983a06a"/"Verilator 5.051"/' \
	'Verilator 版本是本章实测的 5.052'
mut 大小改230881 check.sh 's/"230880"/"230881"/' \
	'Vour 的大小（本机工具链）：230880 字节'
mut hello our.v 's/Hello World/Hello/' \
	'生成代码：$display 变成 VL_WRITEF_NX' \
	'运行 Vour：第 1 行是 $display 的 Hello World'
mut 改before fin.v 's/"before"/"BEFORE"/' \
	'fin.v：第 1 行是 before'
mut 删after fin.v 's/ \$display("after");//' \
	'fin.v：$finish 之后的 $display 照样执行，第 3 行是 after' \
	'fin.v：一共 3 行'
mut 期望改stop check.sh 's/VL_FINISH_MT\\(/VL_STOP_MT\\(/;s/Verilog \\\$finish/Verilog \\\$stop/' \
	'生成代码：$finish 变成 VL_FINISH_MT，带着文件名和行号 2' \
	'运行 Vour：第 2 行是 $finish 的报告' \
	'fin.v：$finish 的报告紧跟在 before 后面，当场打印'

echo "=== 第 3、4 节 ==="
mut P1前插eval tb_eval.cpp 's/^    printf("P1/    top->eval();\n    printf("P1/' \
	'P1 改了输入但没调 eval：f 还是 0'
mut 删P2前的eval tb_eval.cpp '0,/top->eval();/{/top->eval();/d}' \
	'P2 调了 eval：f 变成 1'
mut 删commandArgs tb_eval.cpp '/commandArgs/d' \
	'P0 的 0 来自运行时默认：加 +verilator+rand+reset+1 运行，P0 变成全 1'
mut 写1不越界 tb_eval.cpp 's/top->a = 2;/top->a = 1;/' \
	'P5 普通构建：给 1 位端口写 2，不报错，f 算成 2' \
	'调试构建：写 2 被当场拦下' \
	'调试构建：P5 那一行没有打印出来' \
	'调试构建应失败'
mut abc改8位 top.v 's/^  input a,/  input [7:0] a,/;s/^  input b,/  input [7:0] b,/;s/^  output f/  output [7:0] f/' \
	'端口 a 是 8 位成员（宽 1 位）' \
	'端口 b 是 8 位成员（宽 1 位）' \
	'端口 f 是 8 位成员（宽 1 位）' \
	'P0 的 0 来自运行时默认：加 +verilator+rand+reset+1 运行，P0 变成全 1' \
	'普通构建的生成代码里也写着这条检查（被 #ifdef VL_DEBUG 包住）' \
	'调试构建：写 2 被当场拦下' \
	'调试构建：P5 那一行没有打印出来' \
	'调试构建应失败'
mut 异或改或 top.v 's/a ^ b/a | b/' \
	'assign f = a ^ b 变成了一行 C++ 赋值' \
	'跑 10 次：退出码 0（assert 一次也没失败）' \
	'跑 10 次：打印 10 行 a/b/f' \
	'跑 10 次：四种输入组合的出现次数' \
	'跑 1000 次：退出码 0' \
	'跑 1000 次：打印 1000 行 a/b/f' \
	'跑 1000 次：四种组合都出现过'

echo "=== 第 5 节 ==="
mut 播种1 tb_switch.cpp 's/int n = 10;/srand(1); int n = 10;/'
mut 播种2 tb_switch.cpp 's/int n = 10;/srand(2); int n = 10;/' \
	'跑 10 次：四种输入组合的出现次数' \
	'注错 1：在伪终端里运行（相当于直接在终端里敲），assert 前的 2 行打印都在'

echo "=== 第 6 节 ==="
mut 注错1不改坏 check.sh 's#a ^ b/a | b/#a ^ b/a ^ b/#' \
	'注错 1（^ 改成 |）：assert 失败，abort 退出码 134' \
	'注错 1：报错里写着哪一行、哪个条件' \
	'注错 1：stdout 重定向到文件时，assert 前的打印全丢（abort 不刷缓冲）' \
	'注错 1：在伪终端里运行（相当于直接在终端里敲），assert 前的 2 行打印都在' \
	'注错 1：伪终端里退出码同样是 134' \
	'注错 4：独立判据逐行重算，抓出 3 行不对（11 出现 3 次）'
mut 注错3不改坏 check.sh 's#\$B/m3/switch\.v#$B/m3/top.v#g' \
	'注错 3 应构建失败' \
	'注错 3：原因是 DECLFILENAME' \
	'注错 3 对照的类名' \
	'注错 3 对照：g++ 编译 tb_switch.cpp 时找不到 Vtop.h' \
	'-Wno-DECLFILENAME 时也应失败在 Vtop.h' \
	'-Wall 加 --top top 应仍因 DECLFILENAME 失败'
mut 注错2不改坏 check.sh 's#/top->eval();/d#/no-such-line/d#' \
	'注错 2（删掉 eval）：f 永远是 0，assert 失败，退出码 134'
mut 注错4不改坏 check.sh 's#/assert(/d#/no-such-line/d#' \
	'注错 4（电路改成 |，再删掉 assert）：程序自己发现不了，退出码 0' \
	'注错 4：打印 10 行 a/b/f' \
	'注错 4：独立判据逐行重算，抓出 3 行不对（11 出现 3 次）'
mut ABRT改KILL check.sh 's/"ABRT"/"KILL"/' \
	'SIGABRT 是 6 号信号'

echo "=== 第 7 节 ==="
mut INT改QUIT check.sh 's/"INT"/"QUIT"/' \
	'SIGINT 是 2 号信号'
mut 124改125 check.sh "s/'124 +if COMMAND/'125 +if COMMAND/" \
	'timeout --help：超时且没加 --preserve-status 时返回 124'
mut 循环加上限 tb_forever.cpp 's/while (!contextp->gotFinish()) {/for (int i = 0; i < 10 \&\& !contextp->gotFinish(); i++) {/' \
	'1 秒后仍在运行，被 timeout 发 SIGINT 打断（timeout 返回 124）' \
	'让 timeout 转交程序自己的退出状态：130 = 128 + 2（SIGINT 是 2 号信号）' \
	'1 秒内的行数'

echo "=== 第 8 节 ==="
mut 环不取反 loop.v 's/~x/x/' \
	'en=1：环闭合，eval 报 DIDNOTCONVERGE' \
	'en=1：那一行 printf 没有机会执行' \
	'en=1：退出码 1'
mut 断开环 loop.v 's/~x/~en/' \
	'-Wall 下组合环应构建失败' \
	'失败原因是 UNOPTFLAT 警告' \
	'报完警告就以错误退出（Verilator 的警告默认致命）' \
	'不加 -Wall 时组合环也应构建失败' \
	'en=1：环闭合，eval 报 DIDNOTCONVERGE' \
	'en=1：那一行 printf 没有机会执行' \
	'en=1：退出码 1'

echo
printf '  %d OK / %d BAD（用时 %d 秒）\n' "$GOOD" "$BAD" "$SECONDS"
[ "$BAD" -eq 0 ]
