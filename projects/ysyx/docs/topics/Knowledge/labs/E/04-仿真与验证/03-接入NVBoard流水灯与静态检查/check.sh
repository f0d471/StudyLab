#!/bin/bash
# 教程第 03 章（接入NVBoard、流水灯与静态检查）的判据自动核对
#
# 用法：在沙箱里 bash check.sh
# 四组：NVBoard 三件套如何建立联系（auto_pin_bind 产物与库归档）；双控开关上板
# （构建 + 无头运行）；流水灯（复位/移位/分频的模型级实测 + 上板构建）；静态检查
# （讲义参考实现零警告、三类典型警告的触发与默认开关状态）。
# NVBoard 是第三方库：从 /workspace/ysyx-workbench/nvboard 拷一份可写副本到 build/
# 再编（workbench 只读）。mutate.sh 逐项重跑本脚本时，设 CH03_REUSE_NV=1 复用
# /tmp 里已编好的库副本（库源码不变），省去每项重复编译第三方库的时间。
# 窗口画面机器读不了：板上可视行为是学员确认项，本脚本判据到"构建成功 + 无头运行
# 健康循环"为止（SDL_VIDEODRIVER=dummy）。
# 各节标题里的"第 N 节"就是正文的小节号。改坏必红的核对由 mutate.sh 逐项实跑。

cd "$(dirname "$0")" || exit 1

PASS=0; FAIL=0; SKIP=0
ok()   { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
no()   { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '        %s\n' "$2"; }
skip() { SKIP=$((SKIP+1)); printf '  SKIP  %s\n' "$1"; }

command -v verilator >/dev/null 2>&1 || { echo "找不到 verilator：本脚本要在沙箱里运行"; exit 1; }

B=build
rm -rf "$B" && mkdir -p "$B"

echo "=== 环境 ==="
V="$(verilator --version 2>&1 | head -1)"
if grep -qE '^Verilator 5\.052 ' <<< "$V"; then ok 'Verilator 版本是 5.052'; else no 'Verilator 版本是 5.052' "实得 $V"; fi
if [ -d /workspace/ysyx-workbench/nvboard/scripts ]; then ok 'NVBoard 源码在位'; else no 'NVBoard 源码在位' '找不到 /workspace/ysyx-workbench/nvboard/scripts'; fi
SDL="$(pkg-config --modversion sdl2 2>/dev/null)"
if [ -n "$SDL" ]; then ok "SDL2 开发库在位（$SDL）"; else no 'SDL2 开发库在位' 'pkg-config 查不到 sdl2'; fi

# NVBoard 可写副本：正常跑从源拷贝并清理旧产物；REUSE 模式复用 /tmp 的副本
NV=/tmp/ch03-nvboard
if [ "${CH03_REUSE_NV:-0}" = "1" ] && [ -f "$NV/build/nvboard.a" ]; then
	cp -r "$NV" "$B/nvboard"
else
	rm -rf "$NV"
	cp -r /workspace/ysyx-workbench/nvboard "$B/nvboard"
	rm -rf "$B/nvboard/build" "$B/nvboard/example/build"
fi
export NVBOARD_HOME="$PWD/$B/nvboard"

echo "=== 第 1 节 三件套怎么建立联系 ==="
# 先用双控开关的工程跑一遍三件套
make -f Makefile.nv TOPNAME=top NXDC=top.nxdc VSRC=top.v CSRC=main_sw.cpp > "$B/sw.log" 2>&1
n="$(grep -c 'nvboard_bind_pin' "$B/top/auto_bind.cpp" 2>/dev/null)"
if [ "$n" = "3" ]; then
	ok 'auto_pin_bind.py 把 top.nxdc 的三行绑定生成三次 nvboard_bind_pin'
else
	no 'auto_pin_bind.py 把 top.nxdc 的三行绑定生成三次 nvboard_bind_pin' "实得 $n 次"
fi
if grep -q '&top->a, 1, SW0' "$B/top/auto_bind.cpp" && grep -q '&top->f, 1, LD0' "$B/top/auto_bind.cpp"; then
	ok '绑定内容是 a 到 SW0、f 到 LD0'
else
	no '绑定内容是 a 到 SW0、f 到 LD0' 'auto_bind.cpp 里找不到对应行'
fi
if [ -f "$B/nvboard/build/nvboard.a" ]; then
	ok 'NVBoard 库源码编成 build/nvboard.a（nvboard.mk 的产物）'
else
	no 'NVBoard 库源码编成 build/nvboard.a（nvboard.mk 的产物）' '归档不存在'
fi

echo "=== 第 2 节 双控开关上板 ==="
if [ -x "$B/top/top" ]; then
	ok '双控开关的 NVBoard 工程构建成功'
else
	no '双控开关的 NVBoard 工程构建成功' 'build/top/top 不存在'
fi
SDL_VIDEODRIVER=dummy timeout 3 "$B/top/top" > "$B/top/run.log" 2>&1
rc=$?
if [ "$rc" -eq 124 ]; then
	ok '双控开关无头运行 3 秒仍在循环（timeout 返回 124）'
else
	no '双控开关无头运行 3 秒仍在循环（timeout 返回 124）' "退出码 $rc：$(head -c 100 "$B/top/run.log")"
fi

echo "=== 第 3 节 流水灯：复位、移位、分频 ==="
verilator --cc --exe --build -j 0 --top-module light --Mdir "$B/tl" light.v tb_light.cpp > "$B/tl.log" 2>&1
"$B/tl/Vlight" > "$B/tl.run" 2>&1
if grep -q 'after reset: led=0001 count=0' "$B/tl.run"; then
	ok 'reset(10) 后 led=0001、count=0'
else
	no 'reset(10) 后 led=0001、count=0' "实得 $(head -1 "$B/tl.run")"
fi
if grep -q '1 cycle:    led=0002 count=1' "$B/tl.run"; then
	ok '第一个周期 led 移到 0002'
else
	no '第一个周期 led 移到 0002' "实得 $(sed -n 2p "$B/tl.run")"
fi
if grep -q 'step 1:     led=0004' "$B/tl.run" && grep -q 'step 2:     led=0008' "$B/tl.run"; then
	ok '每 5000001 个周期左移一位：0004、0008'
else
	no '每 5000001 个周期左移一位：0004、0008' "实得 $(sed -n '3,4p' "$B/tl.run" | tr '\n' ' ')"
fi
"$B/tl/Vlight" noreset > "$B/tln.run" 2>&1
if grep -q 'no reset:   led=0000' "$B/tln.run" && ! grep -q 'led=000[1-9a-f]' "$B/tln.run"; then
	ok '不复位：led 恒为 0000，灯永远不亮'
else
	no '不复位：led 恒为 0000，灯永远不亮' "实得 $(cat "$B/tln.run" | tr '\n' ' ')"
fi
make -f Makefile.nv TOPNAME=light NXDC=light.nxdc VSRC=light.v CSRC=main_light.cpp > "$B/lt.log" 2>&1
if [ -x "$B/light/light" ]; then
	ok '流水灯的 NVBoard 工程构建成功'
else
	no '流水灯的 NVBoard 工程构建成功' 'build/light/light 不存在'
fi
SDL_VIDEODRIVER=dummy timeout 3 "$B/light/light" > "$B/light/run.log" 2>&1
rc=$?
if [ "$rc" -eq 124 ]; then
	ok '流水灯无头运行 3 秒仍在循环（timeout 返回 124）'
else
	no '流水灯无头运行 3 秒仍在循环（timeout 返回 124）' "退出码 $rc：$(head -c 100 "$B/light/run.log")"
fi

echo "=== 第 4 节 静态检查 ==="
verilator --lint-only -Wall light.v > "$B/ll.log" 2>&1
rc=$?
if [ "$rc" -eq 0 ] && ! grep -qE '^%' "$B/ll.log"; then
	ok '讲义的流水灯参考实现在 -Wall 下零警告（退出码 0 且无诊断行）'
else
	no '讲义的流水灯参考实现在 -Wall 下零警告（退出码 0 且无诊断行）' "退出码 $rc：$(grep -m2 -E '^%' "$B/ll.log" | tr '\n' ' ')"
fi
verilator --lint-only -Wall lint_undriven.v > "$B/l1.log" 2>&1
rc=$?
if [ "$rc" -ne 0 ] && grep -q 'Warning-UNDRIVEN' "$B/l1.log"; then
	ok '未驱动的线触发 UNDRIVEN（-Wall 打开且致命）'
else
	no '未驱动的线触发 UNDRIVEN（-Wall 打开且致命）' "退出码 $rc"
fi
verilator --lint-only -Wall lint_unused.v > "$B/l2.log" 2>&1
rc=$?
if [ "$rc" -ne 0 ] && grep -q 'Warning-UNUSEDSIGNAL' "$B/l2.log"; then
	ok '未使用的端口触发 UNUSEDSIGNAL（-Wall 打开）'
else
	no '未使用的端口触发 UNUSEDSIGNAL（-Wall 打开）' "退出码 $rc"
fi
# 这两类不带 -Wall 时不报：默认关闭
verilator --lint-only lint_undriven.v > "$B/d1.log" 2>&1; r1=$?
verilator --lint-only lint_unused.v > "$B/d2.log" 2>&1; r2=$?
if [ "$r1" -eq 0 ] && [ "$r2" -eq 0 ] && ! grep -qE '^%' "$B/d1.log" && ! grep -qE '^%' "$B/d2.log"; then
	ok '不带 -Wall 时 UNDRIVEN 与 UNUSEDSIGNAL 都不报（默认关闭）'
else
	no '不带 -Wall 时 UNDRIVEN 与 UNUSEDSIGNAL 都不报（默认关闭）' "退出码 $r1 与 $r2"
fi
verilator --lint-only lint_width.v > "$B/l3.log" 2>&1
rc=$?
if [ "$rc" -ne 0 ] && grep -q 'Warning-WIDTHTRUNC' "$B/l3.log"; then
	ok '位宽截断触发 WIDTHTRUNC（不开 -Wall 也报）'
else
	no '位宽截断触发 WIDTHTRUNC（不开 -Wall 也报）' "退出码 $rc"
fi
verilator --lint-only -Wall lint_clean.v > "$B/l4.log" 2>&1
rc=$?
if [ "$rc" -eq 0 ] && ! grep -qE '^%' "$B/l4.log"; then
	ok '位宽对齐的版本 -Wall 零警告（退出码 0 且无诊断行）'
else
	no '位宽对齐的版本 -Wall 零警告（退出码 0 且无诊断行）' "退出码 $rc：$(grep -m2 -E '^%' "$B/l4.log" | tr '\n' ' ')"
fi

# REUSE 模式结束时把编好的库副本留在 /tmp 供下一项复用
if [ "${CH03_REUSE_NV:-0}" = "1" ]; then
	rm -rf "$NV"; cp -r "$B/nvboard" "$NV" 2>/dev/null
fi

echo
printf '  %d PASS / %d FAIL / %d SKIP\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
