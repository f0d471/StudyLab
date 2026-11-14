# 教程第 02 章的一键仿真演示件
# 真正的 npc/Makefile 由学员按讲义写；那份里有一行不许动的
#   $(call git_commit, "sim RTL")
# 它属于 ysyx-workbench 的 tracer 机制（正文第 4 节解剖），labs 里没有也不需要。
TOPNAME = top
VSRCS = top.v tb_table.cpp

sim:
	verilator --cc --exe --build -j 0 --top-module $(TOPNAME) \
		--Mdir build/obj -o $(CURDIR)/build/tablesims \
		$(VSRCS)
	./build/tablesims

clean:
	rm -rf build

.PHONY: sim clean
