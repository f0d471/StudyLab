#!/bin/bash
# check.sh 的注错自检
#
# 用法：在沙箱里 bash mutate.sh（每种注错完整跑一遍 check.sh，本机共约 9 分钟）
# 正文各节 [判] 块末尾的"注错见红"写了改坏哪里、哪几条判据变红。本脚本把每一种改坏
# 做在一份副本上，跑副本的 check.sh，核对变红的判据恰好是正文写的那几条，不多也不少。
# 变红判据里用 eq 比较的，副本给出的实际值也一并打印（"期望 ...，实得 ..."）。
# 第一项"原样"是对照：副本不做改动，一条都不能变红。
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
		grep '^        期望 ' "$d/run.log" | sed 's/^        /        /'
	else
		BAD=$((BAD+1)); printf '  BAD   %s：变红的判据与正文不一致（< 正文写的，> 实际变红的）\n' "$name"
		diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep '^[<>]' | sed 's/^/        /'
	fi
}

echo "=== 对照 ==="
mut 原样 "" ""

echo "=== 环境 ==="
mut 版本改5.051 check.sh 's/\^Verilator 5\\\.052 /^Verilator 5\\.051 /' \
	'Verilator 版本是 5.052（本篇的生成代码与行号按这个版本写）'

echo "=== 第 1 节 ==="
mut 上限改20 check.sh 's#--cc -Wall --Mdir \$B/cc top.v#--cc -Wall --converge-limit 20 --Mdir $B/cc top.v#' \
	'Vtop.cpp：收敛上限默认 10000'

echo "=== 第 2 节 ==="
mut w9改8位 widths.v "s/\[8:0\]  w9/[7:0]  w9/;s/{56'b0, w9}/{57'b0, w9}/" \
	'9 位  -> VL_IN16'
mut w33改32位 widths.v "s/\[32:0\] w33/[31:0] w33/;s/{32'b0, w33}/{33'b0, w33}/" \
	'33 位 -> VL_IN64' \
	'调试构建的宽度检查：w33 的掩码是 0ULL'

echo "=== 第 3 节 ==="
mut 实例改名 hier.v 's/u_sub/u_s/' \
	'hier 里实例 u_sub 的寄存器 r：hier__DOT__u_sub__DOT__r' \
	'tb_hier.cpp（包含 Vhier___024root.h，经 rootp 读 r）构建成功' \
	'tb_hier 读到 r = 5a'
mut 不含根类头文件 tb_hier.cpp '/Vhier___024root\.h/d' \
	'tb_hier.cpp（包含 Vhier___024root.h，经 rootp 读 r）构建成功' \
	'tb_hier 读到 r = 5a'

echo "=== 第 4 节 ==="
mut 不写f tb_trace.cpp 's/top->f = 7; //' \
	'E1 至 E5 之后的 f 依次是 1 0 0 7 1'

echo "=== 第 5 节 ==="
mut t2不取反 chain.v 's/assign t2 = ~t1;/assign t2 = t1;/' \
	'chain 真值表（f = ~(a^b) & a）' \
	'三条 assign 被并成一条 C++ 表达式'
mut 去掉public chain_pub.v 's#/\*verilator public\*/##' \
	'public：build/cp 有 19 个文件' \
	't1 加 /*verilator public*/：模块不再被并进 root，单独成类，root 里只留一个指针' \
	'public：t1 是那个类的成员' \
	'tb_pub.cpp（包含 Vchain_pub_chain_pub.h，读 top->chain_pub->t1）构建成功' \
	'tb_pub：a=1 b=0 时读到 t1=1，f=0'
mut 不含模块类头文件 tb_pub.cpp '/Vchain_pub_chain_pub\.h/d' \
	'tb_pub.cpp（包含 Vchain_pub_chain_pub.h，读 top->chain_pub->t1）构建成功' \
	'tb_pub：a=1 b=0 时读到 t1=1，f=0'
mut 去掉public_flat chain_flat.v 's#/\*verilator public_flat\*/##' \
	'public_flat：build/cf 有 15 个文件' \
	't1 加 /*verilator public_flat*/：留在 root 里，名字是 chain_flat__DOT__t1' \
	'public_flat：ico 区里先算 t1、后算 f（源码里 f 写在最前）' \
	'tb_flat.cpp（包含 Vchain_flat___024root.h，经 rootp 读 t1）构建成功' \
	'tb_flat：a=1 b=0 时读到 t1=1，f=0'

echo "=== 第 6 节 ==="
mut 不给上限50 check.sh 's/ --converge-limit 50 / /' \
	'生成代码里收敛上限改成了 50' \
	'en 一开始就是 1：在第一次 eval 的 Settle 区就转不停，试满 50 次报错'
mut 环不取反 loop.v 's/assign x = en ? ~x/assign x = en ? x/' \
	'en 一开始就是 1：在第一次 eval 的 Settle 区就转不停，试满 50 次报错' \
	'退出码 1'

echo "=== 第 7 节 ==="
mut 输入不同拍 tb_seq.cpp 's/top->clk = 1; top->in = 0; top->eval();/top->clk = 1; top->eval();/' \
	'同一次 eval 里 in 1->0、clk 0->1：q 取到新的 d = 1'

echo "=== 第 8 节 ==="
mut 延迟改20 dly.v 's/#10 /#20 /' \
	'#10 之后打印，$time 是 10' \
	'$finish 发生在 10ps'

echo
printf '  %d OK / %d BAD（用时 %d 秒）\n' "$GOOD" "$BAD" "$SECONDS"
[ "$BAD" -eq 0 ]
