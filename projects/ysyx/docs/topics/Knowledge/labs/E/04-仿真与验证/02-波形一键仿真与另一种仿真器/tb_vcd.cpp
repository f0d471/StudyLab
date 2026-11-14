// 双控开关的 VCD 波形 testbench：跑 10 轮随机输入，每轮 dump 一次
#include <stdio.h>
#include <stdlib.h>
#include "verilated.h"
#include "Vtop.h"
#include "verilated_vcd_c.h"

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);
  Vtop* top = new Vtop;
  Verilated::traceEverOn(true);          // 运行期总开关
  VerilatedVcdC* tfp = new VerilatedVcdC;
  top->trace(tfp, 99);                   // 绑定模型，99 层深度
  tfp->open("/tmp/top.vcd");             // 波形只写 /tmp（见正文纪律）
  long t = 0;
  for (int i = 0; i < 10; i++) {
    int a = rand() & 1, b = rand() & 1;
    top->a = a; top->b = b;
    top->eval();
    tfp->dump((uint64_t)t++);                      // 记录当前所有信号值
    printf("a = %d, b = %d, f = %d\n", a, b, top->f);
  }
  tfp->close();
  top->final();
  delete top;
  return 0;
}
