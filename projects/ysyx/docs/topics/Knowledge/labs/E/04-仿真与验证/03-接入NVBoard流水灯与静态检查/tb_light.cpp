#include <cstdio>
#include "Vlight.h"
#include "Vlight___024root.h"
#include "verilated.h"

static Vlight* dut;

static void single_cycle() {
  dut->clk = 0; dut->eval();
  dut->clk = 1; dut->eval();
}

static void reset(int n) {
  dut->rst = 1;
  while (n -- > 0) single_cycle();
  dut->rst = 0;
}

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    dut = new Vlight{contextp};

    if (argc > 1) {
      printf("no reset:   led=%04x count=%u\n", dut->led,
             dut->rootp->light__DOT__count);
    } else {
      reset(10);
      printf("after reset: led=%04x count=%u\n", dut->led,
             dut->rootp->light__DOT__count);
    }

    single_cycle();
    printf("1 cycle:    led=%04x count=%u\n", dut->led,
           dut->rootp->light__DOT__count);
    for (int step = 1; step <= 2; step++) {
      for (unsigned i = 0; i < 5000001; i++) single_cycle();
      printf("step %d:     led=%04x count=%u\n", step, dut->led,
             dut->rootp->light__DOT__count);
    }

    dut->final();
    delete dut;
    delete contextp;
    return 0;
}
