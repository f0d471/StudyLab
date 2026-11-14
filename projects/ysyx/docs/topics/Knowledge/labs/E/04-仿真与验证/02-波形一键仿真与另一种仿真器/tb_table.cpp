// 双控开关的四种输入组合（verilator 侧），与 iverilog 的 tb_top_iv.v 打印同一张表
#include <stdio.h>
#include "verilated.h"
#include "Vtop.h"

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);
  Vtop* top = new Vtop;
  const int vs[4][2] = {{0,0},{0,1},{1,0},{1,1}};
  for (int i = 0; i < 4; i++) {
    top->a = vs[i][0]; top->b = vs[i][1];
    top->eval();
    printf("a=%d b=%d f=%d\n", top->a, top->b, top->f);
  }
  top->final();
  delete top;
  return 0;
}
