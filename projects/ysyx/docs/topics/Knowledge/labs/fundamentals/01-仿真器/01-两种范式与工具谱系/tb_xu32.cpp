// 打印未初始化寄存器的值（两态模型）
#include <stdio.h>
#include "verilated.h"
#include "Vxu32.h"

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);   // 把 +verilator+rand+reset+N 这类运行期参数交给运行库
  Vxu32* top = new Vxu32;
  top->clk = 0; top->eval();
  top->clk = 1; top->eval();
  printf("r=%08x\n", top->r);
  top->final();
  delete top;
  return 0;
}
