#include <cstdio>
#include "Vchain.h"
#include "verilated.h"

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    Vchain* top = new Vchain{contextp};
    for (int a = 0; a < 2; a++) {
        for (int b = 0; b < 2; b++) {
            top->a = a;
            top->b = b;
            top->eval();
            printf("a=%d b=%d f=%d\n", a, b, top->f);
        }
    }
    top->final();
    delete top;
    delete contextp;
    return 0;
}
