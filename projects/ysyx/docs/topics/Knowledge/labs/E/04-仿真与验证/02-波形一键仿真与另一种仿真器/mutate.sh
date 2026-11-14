#!/bin/bash
# check.sh 的注错自检
#
# 用法：在沙箱里 bash mutate.sh（每项完整跑一遍 check.sh，本机约 6 分钟）
# 正文各节 [判] 块末尾的"注错见红"写了改坏哪里、哪几条判据变红。本脚本把每一种改坏
# 做在一份副本上，跑副本的 check.sh，核对变红的判据恰好是正文写的那几条。
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
	cp ./*.v ./*.cpp Makefile check.sh "$d/"
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
	'VCD 含时间戳与值变化行'
mut 去掉trace选项 check.sh 's/--top-module top --trace \\/--top-module top \\/' \
	'switch 的 VCD 生成且包含 a、b、f 的 $var 声明' \
	'VCD 含时间戳与值变化行'

echo "=== 第 2 节 ==="
mut 去掉USE_FST check.sh 's/-CFLAGS -DUSE_FST //' \
	'cnt 的 VCD 与 FST 均生成（一万拍）' \
	'FST 比 VCD 小（判据至少 5 倍）'

echo "=== 第 4 节 ==="
mut sim目标改名 Makefile 's/^sim:/simx:/' \
	'make sim 一键完成编译与运行（退出码 0 且打印四行真值表）'

echo "=== 第 5 节 ==="
mut iverilog表打错 tb_top_iv.v 's/a, b, f);/a, b, ~f);/' \
	'iverilog 与 verilator 对同一开关打印同一张真值表'
mut r接成0 xu.v "s/r <= r;/r <= 1'b0;/" \
	'未初始化的 r：iverilog 打印 x'
mut 延迟改10 late.v 's/#5 d/#10 d/' \
	'带 #5 的设计：iverilog 原生仿真，q 在 t=20000ps 才变 1' \
	'带 --timing 运行：#5 生效，t=19000 仍为 0，t=20000 变 1'
mut 去掉timing check.sh 's/--timing --top-module late/--top-module late/' \
	'带 --timing 运行：#5 生效，t=19000 仍为 0，t=20000 变 1'

echo
printf '  %d OK / %d BAD\n' "$GOOD" "$BAD"
[ "$BAD" -eq 0 ]
