// 带 #5 延迟的触发器（verilator 侧，需 --timing）：用 timeInc 推进仿真时间
// late.v 的时间单位是 1ns、精度 1ps，所以仿真时间的一个计数是 1ps，#5 等于 5000 个计数
#include <stdio.h>
#include "verilated.h"
#include "Vlate.h"

int main(int argc, char** argv) {
  VerilatedContext* contextp = new VerilatedContext;
  contextp->commandArgs(argc, argv);
  Vlate* top = new Vlate{contextp};
  top->clk = 0; top->d = 0; top->eval();
  contextp->timeInc(10000); top->d = 1; top->eval();     // t=10000ps：d 置 1
  contextp->timeInc(5000);  top->clk = 1; top->eval();   // t=15000ps：上升沿，采到 d=1
  printf("t=%lu q=%d\n", (unsigned long)contextp->time(), top->q);
  contextp->timeInc(4000);  top->eval();                 // t=19000ps：延迟还没到
  printf("t=%lu q=%d\n", (unsigned long)contextp->time(), top->q);
  contextp->timeInc(1000);  top->eval();                 // t=20000ps：#5 到期
  printf("t=%lu q=%d\n", (unsigned long)contextp->time(), top->q);
  top->final();
  delete top;
  delete contextp;
  return 0;
}
