#include <cstdio>
#include "Vtop.h"
#include "verilated.h"

static void mark(const char* s) { printf("== %s\n", s); fflush(stdout); }

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    Vtop* top = new Vtop{contextp};

    mark("E1 first eval, a=1 b=0");
    top->a = 1; top->b = 0; top->eval();
    printf("after E1: f=%d\n", top->f);
    mark("E2 change b only, b=1");
    top->b = 1; top->eval();
    printf("after E2: f=%d\n", top->f);
    mark("E3 nothing changed");
    top->eval();
    printf("after E3: f=%d\n", top->f);
    mark("E4 overwrite output f=7, nothing changed");
    top->f = 7; top->eval();
    printf("after E4: f=%d\n", top->f);
    mark("E5 change a, a=0");
    top->a = 0; top->eval();
    printf("after E5: f=%d\n", top->f);
    mark("END");

    top->final();
    delete top;
    delete contextp;
    return 0;
}
