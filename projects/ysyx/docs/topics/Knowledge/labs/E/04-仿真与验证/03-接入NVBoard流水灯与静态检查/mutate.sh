#!/bin/bash
# check.sh 的注错自检
#
# 用法：在沙箱里 bash mutate.sh（每项完整跑一遍 check.sh；NVBoard 库副本在各项之间
# 复用 /tmp 里的已编版本，本机共约 15 分钟）
# 每项改坏一处源码，重跑 check.sh，期望变红的判据清单写在本项末尾参数里。本脚本
# 逐项实跑核对。第一项"原样"是对照：一条都不能变红。
# 产物在 build/mut/；check.sh 开头清空 build/ 时会一起删掉，两个脚本不要同时跑。

cd "$(dirname "$0")" || exit 1
command -v verilator >/dev/null 2>&1 || { echo "找不到 verilator：本脚本要在沙箱里运行"; exit 1; }

M=build/mut
rm -rf "$M" && mkdir -p "$M"
GOOD=0; BAD=0
export CH03_REUSE_NV=1     # 各项复用 /tmp/ch03-nvboard 里编好的 NVBoard 库副本

mut() {
	local name=$1 file=$2 expr=$3; shift 3
	local d=$M/$name got want
	mkdir -p "$d"
	cp ./*.v ./*.cpp ./*.nxdc Makefile.nv check.sh "$d/"
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

echo "=== 第 1 节 ==="
mut 约束少绑f top.nxdc '/^f LD0/d' \
	'auto_pin_bind.py 把 top.nxdc 的三行绑定生成三次 nvboard_bind_pin' \
	'绑定内容是 a 到 SW0、f 到 LD0'

echo "=== 第 2 节 ==="
mut 开关循环改成不转 main_sw.cpp 's/while (1) {/while (0) {/' \
	'双控开关无头运行 3 秒仍在循环（timeout 返回 124）'

echo "=== 第 3 节 ==="
mut 复位值写成0 light.v 's/led <= 1; count <= 0;/led <= 0; count <= 0;/' \
	'reset(10) 后 led=0001、count=0' \
	'第一个周期 led 移到 0002' \
	'每 5000001 个周期左移一位：0004、0008'
mut 移位方向改反 light.v 's/{led\[14:0\], led\[15\]}/{led[0], led[15:1]}/' \
	'第一个周期 led 移到 0002' \
	'每 5000001 个周期左移一位：0004、0008'
mut 分频改小 light.v 's/5000000/500000/' \
	'每 5000001 个周期左移一位：0004、0008'

echo "=== 第 4 节 ==="
mut 参考实现加未用端口 light.v 's/input rst,/input rst,\n  input never_used,/' \
	'讲义的流水灯参考实现在 -Wall 下零警告（退出码 0 且无诊断行）'
mut 未驱动的线接上 lint_undriven.v "s/wire w;.*/wire w = 1'b0;/" \
	'未驱动的线触发 UNDRIVEN（-Wall 打开且致命）'
mut 对齐版改窄 lint_clean.v 's/output \[3:0\] y/output [2:0] y/' \
	'位宽对齐的版本 -Wall 零警告（退出码 0 且无诊断行）'
mut 默认关判据加Wall check.sh 's/--lint-only lint_undriven\.v > "\$B\/d1\.log"/--lint-only -Wall lint_undriven.v > "$B\/d1.log"/' \
	'不带 -Wall 时 UNDRIVEN 与 UNUSEDSIGNAL 都不报（默认关闭）'

echo
printf '  %d OK / %d BAD\n' "$GOOD" "$BAD"
[ "$BAD" -eq 0 ]
