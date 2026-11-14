// 未初始化的自保持触发器（verilator 侧）：两态模型给默认初值
#include <stdio.h>
#include "verilated.h"
#include "Vxu.h"

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);
  Vxu* top = new Vxu;
  for (int i = 0; i < 3; i++) {
    top->clk = 0; top->eval();
    top->clk = 1; top->eval();
  }
  printf("r=%d\n", top->r);
  top->final();
  delete top;
  return 0;
}
