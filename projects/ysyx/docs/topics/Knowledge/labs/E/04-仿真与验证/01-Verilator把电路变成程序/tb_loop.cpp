#include <cstdio>
#include "Vloop.h"
#include "verilated.h"

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    Vloop* top = new Vloop{contextp};

    top->en = 0;
    top->eval();
    printf("en=0: f=%d\n", top->f);
    fflush(stdout);
    top->en = 1;
    top->eval();
    printf("en=1: f=%d\n", top->f);

    top->final();
    delete top;
    delete contextp;
    return 0;
}
