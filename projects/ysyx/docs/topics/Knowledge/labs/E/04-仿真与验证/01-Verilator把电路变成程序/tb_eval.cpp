#include <cstdio>
#include "Vtop.h"
#include "verilated.h"

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    Vtop* top = new Vtop{contextp};

    printf("P0 constructed, no eval yet:  a=%d b=%d f=%d\n", top->a, top->b, top->f);
    top->a = 1;
    top->b = 0;
    printf("P1 set a=1 b=0, no eval:      f=%d\n", top->f);
    top->eval();
    printf("P2 after eval:                f=%d\n", top->f);
    top->eval();
    printf("P3 eval again, inputs same:   f=%d\n", top->f);
    printf("P4 simulation time:           %llu\n", (unsigned long long)contextp->time());
    fflush(stdout);
    top->a = 2;
    top->b = 0;
    top->eval();
    printf("P5 a=2 (wider than 1 bit):    f=%d\n", top->f);

    top->final();
    delete top;
    delete contextp;
    return 0;
}
