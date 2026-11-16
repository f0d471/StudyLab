#include <cstdio>
#include "Vchain_flat.h"
#include "Vchain_flat___024root.h"
#include "verilated.h"

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    Vchain_flat* top = new Vchain_flat{contextp};
    top->a = 1; top->b = 0; top->eval();
    printf("t1=%d f=%d\n", top->rootp->chain_flat__DOT__t1, top->f);
    top->final();
    delete top;
    delete contextp;
    return 0;
}
