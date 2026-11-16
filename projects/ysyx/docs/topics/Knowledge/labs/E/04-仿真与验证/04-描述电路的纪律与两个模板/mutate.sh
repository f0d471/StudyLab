#!/bin/bash
# check.sh 的注错自检
#
# 用法：在沙箱里 bash mutate.sh（每项完整跑一遍 check.sh，本机约 2 分钟）
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
		GOOD=$((GOOD+1)); printf '  OK    %s：变红 %d 条，与脚本内登记一致\n' "$name" "$#"
	else
		BAD=$((BAD+1)); printf '  BAD   %s：变红的判据与脚本内登记不一致（< 登记的，> 实际变红的）\n' "$name"
		diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep '^[<>]' | sed 's/^/        /'
	fi
}

echo "=== 对照 ==="
mut 原样 "" ""

echo "=== 环境 ==="
mut 版本改5.051 check.sh 's/\^Verilator 5\\\.052 /\^Verilator 5\\.051 /' \
	'Verilator 版本是 5.052'

echo "=== 第 2 节 ==="
mux2a_sel_a=$(printf 's/s ? b : a;/s ? a : b;/')
mut mux选路改反 mux2a.v "$mux2a_sel_a" \
	'2 选 1：assign 版与 MuxKey 版在 1000 组随机输入下输出一致（独立判据重算）'
mut 行为版步长改2 cnta.v "s/q <= q + 8'd1;/q <= q + 8'd2;/" \
	'计数器：行为建模版与模板版在 200 拍随机使能下逐拍一致'
mut 模板版使能恒1 cntt.v "s/(clk, rst, qn, q, en);/(clk, rst, qn, q, 1'b1);/" \
	'计数器：行为建模版与模板版在 200 拍随机使能下逐拍一致'

echo "=== 第 3 节 ==="
mut 雷版补全 lat_bad.v "s/always @(\*) if (en) q = d;/always @(*) if (en) q = d; else q = 1'b0;/" \
	'不完整的 if 推断锁存器：-Wall 报 LATCH 且致命' \
	'LATCH 不开 -Wall 也报（默认开且致命）'
mut 修版删else lat_good.v "s/ else q = 1'b0;//" \
	'补全 else 后 -Wall 零警告（退出码 0 且无诊断行）'

echo
printf '  %d OK / %d BAD\n' "$GOOD" "$BAD"
[ "$BAD" -eq 0 ]
