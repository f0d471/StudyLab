#!/bin/bash
# check.sh 的注错自检
#
# 用法：在沙箱里 bash mutate.sh（每项完整跑一遍 check.sh，本机约 1 分钟）
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
mut 删掉dump tb_vcd.cpp '/tfp->dump/d' \
	'定义段结束之后才出现时间戳'

echo "=== 第 2 节 ==="
mut 循环改9000 tb_cnt.cpp 's/i < 10000/i < 9000/' \
	'cnt 一万拍的 VCD 有 10001 个时间戳'

echo "=== 第 3 节 ==="
mut 去掉USE_FST check.sh 's/-CFLAGS -DUSE_FST //' \
	'FST 的首字节不是 $（它不是文本）'

echo
printf '  %d OK / %d BAD\n' "$GOOD" "$BAD"
[ "$BAD" -eq 0 ]
