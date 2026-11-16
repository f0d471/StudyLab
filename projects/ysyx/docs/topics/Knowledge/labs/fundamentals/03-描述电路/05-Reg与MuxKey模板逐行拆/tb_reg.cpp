// Reg 模板探针 testbench：复位、保持、采样、再复位，逐拍打印 dout
#include <stdio.h>
#include "verilated.h"
#include "Vreg_top.h"

static Vreg_top* top;
static void cycle() { top->clk = 0; top->eval(); top->clk = 1; top->eval(); }

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);
  top = new Vreg_top;
  top->rst = 1; top->wen = 0; top->din = 0xa; cycle(); cycle();
  printf("after reset: dout=%x\n", top->dout);
  top->rst = 0; top->wen = 0; top->din = 0xa; cycle();
  printf("wen=0 din=a: dout=%x\n", top->dout);
  top->wen = 1; top->din = 0xa; cycle();
  printf("wen=1 din=a: dout=%x\n", top->dout);
  top->wen = 0; top->din = 0x3; cycle();
  printf("wen=0 din=3: dout=%x\n", top->dout);
  top->rst = 1; cycle();
  printf("reset again: dout=%x\n", top->dout);
  top->final();
  delete top;
  return 0;
}
