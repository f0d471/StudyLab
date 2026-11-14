// 两种 2 选 1 写法的对照：1000 组随机输入，独立判据逐组重算
#include <stdio.h>
#include <stdlib.h>
#include "verilated.h"
#include "Veq2.h"

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);
  Veq2* top = new Veq2;
  int bad = 0;
  for (int i = 0; i < 1000; i++) {
    int a = rand() & 1, b = rand() & 1, s = rand() & 1;
    top->a = a; top->b = b; top->s = s;
    top->eval();
    int want = s ? b : a;                 // 独立判据：不依赖被测代码
    if (top->ya != want || top->yt != want || top->ya != top->yt) {
      bad++;
      if (bad <= 3) printf("a=%d b=%d s=%d ya=%d yt=%d want=%d\n", a, b, s, top->ya, top->yt, want);
    }
  }
  printf("mismatches=%d\n", bad);
  top->final();
  delete top;
  return 0;
}
