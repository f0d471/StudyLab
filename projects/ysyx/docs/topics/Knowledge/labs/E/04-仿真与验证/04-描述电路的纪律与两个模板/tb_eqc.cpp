// 两种计数器写法的对照：200 拍随机使能（每 64 拍复位一拍），逐拍比对
#include <stdio.h>
#include <stdlib.h>
#include "verilated.h"
#include "Veqc.h"

static Veqc* top;
static void cycle() { top->clk = 0; top->eval(); top->clk = 1; top->eval(); }

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);
  top = new Veqc;
  top->rst = 1; top->en = 0; cycle(); top->rst = 0;
  int bad = 0;
  for (int i = 0; i < 200; i++) {
    top->en = rand() & 1;
    if (i % 64 == 0) { top->rst = 1; }
    cycle();
    top->rst = 0;
    if (top->qa != top->qt) {
      bad++;
      if (bad <= 3) printf("i=%d qa=%d qt=%d\n", i, top->qa, top->qt);
    }
  }
  printf("mismatches=%d\n", bad);
  top->final();
  delete top;
  return 0;
}
