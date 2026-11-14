#include <cstdio>
#include "Vseq.h"
#include "verilated.h"

static void mark(const char* s) { printf("== %s\n", s); fflush(stdout); }

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    Vseq* top = new Vseq{contextp};

    // in 1->0 makes d 0->1 in the same eval as the rising edge
    mark("S1 clk=0 in=1");
    top->clk = 0; top->in = 1; top->eval();
    mark("S2 clk=1 and in=0 in the same eval");
    top->clk = 1; top->in = 0; top->eval();
    printf("same eval:     q=%d\n", top->q);

    // in settles in its own eval, then the rising edge alone
    mark("S3 clk=0 in=1");
    top->clk = 0; top->in = 1; top->eval();
    mark("S4 clk=1 alone");
    top->clk = 1; top->eval();
    printf("separate eval: q=%d\n", top->q);
    mark("END");

    top->final();
    delete top;
    delete contextp;
    return 0;
}
