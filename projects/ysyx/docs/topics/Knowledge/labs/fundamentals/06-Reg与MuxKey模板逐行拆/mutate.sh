#!/bin/bash
# check.sh 的注错自检
#
# 用法：在沙箱里 bash mutate.sh（每项完整跑一遍 check.sh，本机约 3 分钟）
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
mut 复位值改0 reg_top.v 's/4'"'"'h5/4'"'"'h0/' \
	'复位后 dout 等于 RESET_VAL（5）' \
	'wen=0 时保持（din 变了也不采）' \
	'运行中再复位回到 RESET_VAL'
mut 采样拍改成不采 tb_reg.cpp 's/top->wen = 1; top->din = 0xa; cycle();/top->wen = 0; top->din = 0xa; cycle();/' \
	'wen=1 时采样 din' \
	'采到的值在下拍保持'

echo "=== 第 2 节 ==="
mut 数据改错 mux_top.v 's/2'"'"'b10, 4'"'"'h4/2'"'"'b10, 4'"'"'h5/' \
	'三个键各自选出对应的数据（1、2、4）'
mut 默认值改0 mux_top.v 's/m1 (y_def, key, 4'"'"'hf,/m1 (y_def, key, 4'"'"'h0,/' \
	'不命中：MuxKey 输出 0，MuxKeyWithDefault 输出默认值 f'
mut 重复键改回唯一 mux_top.v 's/2'"'"'b01, 4'"'"'h4/2'"'"'b10, 4'"'"'h4/' \
	'键值重复时输出是两份数据的按位或（6），原键 10 落空（0）'

echo "=== 第 3 节 ==="
mut 错位版位宽改坏 mux_top.v 's/output \[2:0\] y_mis/output [3:0] y_mis/' \
	'三个键各自选出对应的数据（1、2、4）' \
	'不命中：MuxKey 输出 0，MuxKeyWithDefault 输出默认值 f' \
	'键值重复时输出是两份数据的按位或（6），原键 10 落空（0）' \
	'参数错位（位宽恰好相等）：不报警告，key=1 与 key=2 的输出和预期不符' \
	'上一条的构建日志里没有任何警告（静默成立）'
mut 坏版修好 mux_bad.v 's/MuxKey #(2, 2, 4)/MuxKey #(3, 2, 4)/' \
	'对数声明不符被 WIDTH 类警告拦下（默认致命）'

echo
printf '  %d OK / %d BAD\n' "$GOOD" "$BAD"
[ "$BAD" -eq 0 ]
