#include <cassert>
#include <cstdio>
#include <cstdlib>
#include "Vtop.h"
#include "verilated.h"

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    Vtop* top = new Vtop{contextp};

    int n = 10;
    if (argc > 1 && argv[1][0] != '+') n = atoi(argv[1]);
    int seen[4] = {0, 0, 0, 0};

    for (int i = 0; i < n; i++) {
        int a = rand() & 1;
        int b = rand() & 1;
        top->a = a;
        top->b = b;
        top->eval();
        printf("a = %d, b = %d, f = %d\n", a, b, top->f);
        assert(top->f == (a ^ b));
        seen[a * 2 + b]++;
    }
    printf("seen: 00=%d 01=%d 10=%d 11=%d\n", seen[0], seen[1], seen[2], seen[3]);

    top->final();
    delete top;
    delete contextp;
    return 0;
}
