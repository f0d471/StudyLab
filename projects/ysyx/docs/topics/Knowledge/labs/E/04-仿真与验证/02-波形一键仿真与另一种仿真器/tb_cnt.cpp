// 计数器波形 testbench：USE_FST 宏决定接 VCD 还是 FST 的 trace 类
// 编译两种版本的差异只有 -CFLAGS -DUSE_FST 与 --trace/--trace-fst
#include <stdio.h>
#include "verilated.h"
#include "Vcnt.h"
#ifdef USE_FST
#include "verilated_fst_c.h"
#define TRACEC VerilatedFstC
#else
#include "verilated_vcd_c.h"
#define TRACEC VerilatedVcdC
#endif

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);
  Vcnt* top = new Vcnt;
  Verilated::traceEverOn(true);
  TRACEC* tfp = new TRACEC;
  top->trace(tfp, 99);
#ifdef USE_FST
  tfp->open("/tmp/cnt.fst");
#else
  tfp->open("/tmp/cnt.vcd");
#endif
  top->rst = 1; top->clk = 0; top->eval(); tfp->dump((uint64_t)0);   // t=0 复位
  top->rst = 0;
  long t = 1;
  for (int i = 0; i < 10000; i++) {
    top->clk = 0; top->eval();
    top->clk = 1; top->eval();      // 制造上升沿
    tfp->dump((uint64_t)t); t += 10;          // 每拍推进 10 个时间单位
  }
  printf("final out = %u\n", top->out);
  tfp->close();
  top->final();
  delete top;
  return 0;
}
