#!/bin/bash
# check.sh 的注错自检
#
# 用法：在沙箱里 bash mutate.sh（每项完整跑一遍 check.sh，本机约 1 分钟）
# 注错做在副本的源码或 check.sh 期望上，核对正文"注错见红"写的变红集合。
# 第一项"原样"是对照：一条都不能变红。
# 产物在 build/mut/；check.sh 开头清空 build/ 时会一起删掉，两个脚本不要同时跑。

cd "$(dirname "$0")" || exit 1
command -v verilator >/dev/null 2>&1 || { echo "找不到 verilator：本脚本要在沙箱里运行"; exit 1; }

M=build/mut
rm -rf "$M" && mkdir -p "$M"
GOOD=0; BAD=0

mut() {
	local name=$1 file=$2 expr=$3; shift 3
	local d=$M/$name got want
	mkdir -p "$d"
	cp ./*.v ./*.cpp ./*.md check.sh "$d/"
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
	else
		BAD=$((BAD+1)); printf '  BAD   %s：变红的判据与正文不一致（< 正文写的，> 实际变红的）\n' "$name"
		diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep '^[<>]' | sed 's/^/        /'
	fi
}

echo "=== 对照 ==="
mut 原样 "" ""

echo "=== 环境 ==="
mut 版本改5.051 check.sh 's/\^Verilator 5\\\.052 /\^Verilator 5\\.051 /' \
	'Verilator 版本是 5.052'

echo "=== 第 1 节 ==="
mut 条款号改错 check.sh 's/4\\\.4 Stratified/3.4 Stratified/' \
	'标准书签里有 4.4 Stratified event scheduler'

echo "=== 第 2 节 ==="
mut vvp拼错 check.sh 's/\^#! \/usr\/bin\/vvp/^#! \/usr\/bin\/vvq/' \
	'iverilog 的产物首行是 #! /usr/bin/vvp（中间文件由 vvp 解释执行）'

echo "=== 第 4 节 ==="
mut x传染期望改错 check.sh 's/0&x=0 1&x=x x+1=xxxx/0\&x=x 1\&x=x x+1=xxxx/' \
	'iverilog：0 & x 得 0，1 & x 得 x，x + 1 得 xxxx'
mut 默认期望改错 check.sh 's/r=00000000/r=00000001/' \
	'verilator 默认：未初始化的 32 位 r 是 0'
mut 随机参数去掉 check.sh 's/ +verilator+rand+reset+2 //' \
	'verilator --x-initial unique 加运行期随机：未初始化的 r 不是 0'

echo
printf '  %d OK / %d BAD\n' "$GOOD" "$BAD"
[ "$BAD" -eq 0 ]
