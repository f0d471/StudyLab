#!/bin/bash
# fundamentals/04（Verilator 命令行选项速查）的判据自动核对
#
# 用法：在沙箱里 bash check.sh
# 三部分：版本与 man 页在位；第 2 节十个选项组逐组核对存在性；第 3 节五条行为探针实测。
# 选项核对的做法：把 man 页的 roff 转义（\- 换回 -）后存进 build/man.txt，
# 再对每个登记选项做固定字符串匹配。
# 各节标题里的"第 N 节"就是正文的小节号。改坏必红的核对由 mutate.sh 逐项实跑
# （改的是本脚本的期望值与探针命令）。

cd "$(dirname "$0")" || exit 1

PASS=0; FAIL=0; SKIP=0
ok()   { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
no()   { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '        %s\n' "$2"; }
skip() { SKIP=$((SKIP+1)); printf '  SKIP  %s\n' "$1"; }

command -v verilator >/dev/null 2>&1 || { echo "找不到 verilator：本脚本要在沙箱里运行"; exit 1; }

MAN=/workspace/tools/verilator-5.052/share/man/man1/verilator.1
B=build
rm -rf "$B" && mkdir -p "$B"

echo "=== 第 1 节 怎么查本机的 man 页 ==="
V="$(verilator --version 2>&1 | head -1)"
if grep -qE '^Verilator 5\.052 ' <<< "$V"; then
	ok 'Verilator 版本是 5.052'
else
	no 'Verilator 版本是 5.052' "实得 $V"
fi
if [ -f "$MAN" ]; then
	ok 'man 页在位'
else
	no 'man 页在位' "找不到 $MAN"
fi

# roff 反转义：\- 换回 -（撇号不参与核对，不替换）
sed 's/\\-/-/g' "$MAN" > "$B/man.txt" 2>/dev/null

# 用法：grp 判据句 选项...
# 每个选项在 build/man.txt 里做固定字符串匹配。带占位符的族选项按 man 页
# 的原样（如 -Wno-<message>）登记，避免短名撞上别的选项行。
grp() {
	local name=$1; shift
	local miss=() o
	for o in "$@"; do
		grep -qF -- "$o" "$B/man.txt" || miss+=("$o")
	done
	if [ "${#miss[@]}" -eq 0 ]; then
		ok "$name"
	else
		no "$name" "man 页里找不到：${miss[*]}"
	fi
}

echo "=== 第 2 节 选项分组总表 ==="
grp '产物形态组 12 个选项都在 man 页' \
	--cc --sc --binary --lint-only --build --exe --main -o --Mdir -j --build-jobs --verilate-jobs
grp '顶层与端口组 3 个选项都在 man 页' \
	--top-module --top --pins-bv
grp '预处理与编译传参组 5 个选项都在 man 页' \
	'-D<' '-I<' -CFLAGS -LDFLAGS -E
grp 'lint 与警告组 8 个选项都在 man 页' \
	-Wall '-Wno-<message>' '-Werror-<message>' '-Wwarn-<message>' '-Wfuture-<message>' \
	-Wno-fatal -Wno-lint -Wno-style
grp '波形组 11 个选项都在 man 页' \
	--trace --trace-vcd --trace-fst --trace-depth --trace-max-array --trace-max-width \
	--trace-params --trace-underscore --trace-structs --trace-saif --trace-coverage
grp '时序与断言组 6 个选项都在 man 页' \
	--timing --no-timing --no-assert --no-assert-case --assert-unroll-limit --autoflush
grp 'x 值组 3 个选项都在 man 页' \
	--x-initial --x-assign --x-initial-edge
grp '覆盖率组 2 个选项都在 man 页' \
	--coverage --coverage-line
grp '公开信号组 5 个选项都在 man 页' \
	--public --public-depth --public-flat-rw --public-params --public-ignore
grp '杂项常用组 7 个选项都在 man 页' \
	--quiet --quiet-build --stats --threads --converge-limit --help --version

echo "=== 第 3 节 行为探针 ==="
# 探针 1：无警告模块
verilator --lint-only good.v > "$B/p1.log" 2>&1
rc=$?
if [ "$rc" -eq 0 ] && ! grep -qE '%(Warning|Error)' "$B/p1.log"; then
	ok '--lint-only 对无警告模块退出码 0 且无警告输出'
else
	no '--lint-only 对无警告模块退出码 0 且无警告输出' "退出码 $rc"
fi

# 探针 2：宽度不匹配默认致命
verilator --lint-only badw.v > "$B/p2.log" 2>&1
rc=$?
if [ "$rc" -eq 1 ] && grep -q 'Warning-WIDTHTRUNC:' "$B/p2.log"; then
	ok '宽度不匹配默认触发 WIDTHTRUNC 警告且致命（退出码 1）'
else
	no '宽度不匹配默认触发 WIDTHTRUNC 警告且致命（退出码 1）' "退出码 $rc"
fi

# 探针 3：-Wno-WIDTHTRUNC 关闭该警告
verilator --lint-only -Wno-WIDTHTRUNC badw.v > "$B/p3.log" 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
	ok '-Wno-WIDTHTRUNC 关闭该警告后退出码 0'
else
	no '-Wno-WIDTHTRUNC 关闭该警告后退出码 0' "退出码 $rc"
fi

# 探针 4：--Mdir
rm -rf "$B/md1"
verilator --cc --Mdir "$B/md1" good.v > "$B/p4.log" 2>&1
if [ -f "$B/md1/Vgood.h" ] && [ -f "$B/md1/Vgood.cpp" ] && [ -f "$B/md1/Vgood.mk" ]; then
	ok '--Mdir 把模型放进指定目录'
else
	no '--Mdir 把模型放进指定目录' '指定目录里没有 Vgood.h/.cpp/.mk'
fi

# 探针 5：--trace-fst 编译探针
rm -rf "$B/md2"
verilator --cc --trace-fst --Mdir "$B/md2" good.v > "$B/p5.log" 2>&1
rc=$?
if [ "$rc" -eq 0 ] && [ -f "$B/md2/Vgood.h" ]; then
	ok '--trace-fst 编译探针通过（模型照常生成）'
else
	no '--trace-fst 编译探针通过（模型照常生成）' "退出码 $rc"
fi

echo
printf '  %d PASS / %d FAIL / %d SKIP\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
