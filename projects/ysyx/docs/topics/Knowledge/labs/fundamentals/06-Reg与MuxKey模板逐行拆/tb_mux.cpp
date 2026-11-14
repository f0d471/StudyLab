// MuxKey 探针 testbench：key 从 0 到 3 各打一行
#include <stdio.h>
#include "verilated.h"
#include "Vmux_top.h"

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);
  Vmux_top* top = new Vmux_top;
  for (int k = 0; k < 4; k++) {
    top->key = k;
    top->eval();
    printf("key=%d plain=%x def=%x dup=%x mis=%x\n", k, top->y_plain, top->y_def, top->y_dup, top->y_mis);
  }
  top->final();
  delete top;
  return 0;
}
