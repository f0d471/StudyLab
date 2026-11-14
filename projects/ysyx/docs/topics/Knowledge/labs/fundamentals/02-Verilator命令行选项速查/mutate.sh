#!/bin/bash
# check.sh 的注错自检
#
# 用法：在沙箱里 bash mutate.sh（每项完整跑一遍 check.sh，本机约 1 分钟）
# 本篇核对对象是 man 页与命令行为，实验目录里没有可改坏的电路。按生产指南坑 24，
# 注错做在 check.sh 副本上：改坏期望值或探针命令里的一个选项名/匹配串，
# 确认恰好对应判据变红。第一项"原样"是对照：一条都不能变红。
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
	cp ./*.v check.sh "$d/"
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
		grep '^        ' "$d/run.log" | grep -v '^  FAIL' | sed 's/^        /        /'
	else
		BAD=$((BAD+1)); printf '  BAD   %s：变红的判据与正文不一致（< 正文写的，> 实际变红的）\n' "$name"
		diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep '^[<>]' | sed 's/^/        /'
	fi
}

echo "=== 对照 ==="
mut 原样 "" ""

echo "=== 第 1 节 ==="
mut 版本改5.051 check.sh 's/\^Verilator 5\\\.052 /\^Verilator 5\\.051 /' \
	'Verilator 版本是 5.052'

echo "=== 第 2 节 ==="
mut tracefst拼错 check.sh 's/--trace-fst --trace-depth/--trace-fstx --trace-depth/' \
	'波形组 11 个选项都在 man 页'

echo "=== 第 3 节 ==="
mut 宽度匹配拼错 check.sh 's/Warning-WIDTHTRUNC:/Warning-WIDTHTRUNX:/' \
	'宽度不匹配默认触发 WIDTHTRUNC 警告且致命（退出码 1）'
mut Wno拼错 check.sh 's/lint-only -Wno-WIDTHTRUNC/lint-only -Wno-WIDTHTRUNX/' \
	'-Wno-WIDTHTRUNC 关闭该警告后退出码 0'
mut Mdir拼错 check.sh 's/--Mdir "\$B\/md1"/--Mdirx "$B\/md1"/;s/--Mdir "\$B\/md2"/--Mdirx "$B\/md2"/' \
	'--Mdir 把模型放进指定目录' \
	'--trace-fst 编译探针通过（模型照常生成）'

echo
printf '  %d OK / %d BAD\n' "$GOOD" "$BAD"
[ "$BAD" -eq 0 ]
