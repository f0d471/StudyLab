#include <cstdio>
#include "Vhier.h"
#include "Vhier___024root.h"
#include "verilated.h"

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    Vhier* top = new Vhier{contextp};
    top->clk = 0; top->d = 0x5a; top->eval();
    top->clk = 1; top->eval();
    printf("r=%02x\n", top->rootp->hier__DOT__u_sub__DOT__r);
    top->final();
    delete top;
    delete contextp;
    return 0;
}
