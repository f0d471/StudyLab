#include <cstdio>
#include "Vchain_pub.h"
#include "Vchain_pub_chain_pub.h"
#include "verilated.h"

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    Vchain_pub* top = new Vchain_pub{contextp};
    top->a = 1; top->b = 0; top->eval();
    printf("t1=%d f=%d\n", top->chain_pub->t1, top->f);
    top->final();
    delete top;
    delete contextp;
    return 0;
}
