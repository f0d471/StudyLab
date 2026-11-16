#!/bin/bash
# check.sh 的注错自检
#
# 用法：在沙箱里 bash mutate.sh（每项完整跑一遍 check.sh，本篇全是文本核对，约半分钟）
# 本篇是地图型篇目，实验目录里没有可改坏的电路源码。按生产指南坑 24 的办法，
# 注错做在 check.sh 的期望值上：把副本里某一个期望改错，确认恰好对应判据变红。
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
	cp ./*.md check.sh "$d/"
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
		grep '^        期望 ' "$d/run.log" | sed 's/^        /        /'
	else
		BAD=$((BAD+1)); printf '  BAD   %s：变红的判据与脚本内登记不一致（< 登记的，> 实际变红的）\n' "$name"
		diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep '^[<>]' | sed 's/^/        /'
	fi
}

echo "=== 对照 ==="
mut 原样 "" ""

echo "=== 第 1 节 ==="
mut 校验和改一位 check.sh 's/12e3dc7bafafca28af2b89ebc2761fb7a606d68716cf04c2d93c8617c78eebec/02e3dc7bafafca28af2b89ebc2761fb7a606d68716cf04c2d93c8617c78eebec/' \
	'标准 PDF 在位，校验和与登记一致'
mut 版本改5.051 check.sh 's/\^Verilator 5\\\.052 /\^Verilator 5\\.051 /' \
	'Verilator 版本是 5.052（工具声明按这个版本的 man 页核对）'

echo "=== 第 2 节 ==="
mut 覆盖章改20 check.sh 's/\^19\\\. Functional coverage/\^20\. Functional coverage/' \
	'功能覆盖是标准第 19 章'

echo "=== 第 3 节 ==="
mut 并发断言改15 check.sh 's/\^  16\\\.5 Concurrent assertions/\^  15\.5 Concurrent assertions/' \
	'并发断言在 16.5'
mut noassert拼错 check.sh 's/Disable all assertions/Disable all asserts/' \
	'--no-assert 在 man 页（断言默认启用，这个选项用来关闭）'

echo
printf '  %d OK / %d BAD\n' "$GOOD" "$BAD"
[ "$BAD" -eq 0 ]
