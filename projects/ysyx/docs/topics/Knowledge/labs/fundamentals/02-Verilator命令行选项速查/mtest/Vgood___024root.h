// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vgood.h for the primary calling header

#ifndef VERILATED_VGOOD___024ROOT_H_
#define VERILATED_VGOOD___024ROOT_H_  // guard

#include "verilated.h"


class Vgood__Syms;

class alignas(VL_CACHE_LINE_BYTES) Vgood___024root final {
  public:

    // DESIGN SPECIFIC STATE
    VL_IN8(a,0,0);
    VL_IN8(b,0,0);
    VL_OUT8(f,0,0);
    CData/*0:0*/ __Vtrigprevexpr___TOP__a__0;
    CData/*0:0*/ __Vtrigprevexpr___TOP__b__0;
    CData/*0:0*/ __VicoDidInit;
    VlUnpacked<QData/*63:0*/, 1> __VstlTriggered;
    VlUnpacked<QData/*63:0*/, 2> __VicoTriggered;

    // INTERNAL VARIABLES
    Vgood__Syms* vlSymsp;
    const char* vlNamep;

    // CONSTRUCTORS
    Vgood___024root(Vgood__Syms* symsp, const char* namep);
    ~Vgood___024root();
    VL_UNCOPYABLE(Vgood___024root);

    // INTERNAL METHODS
    void __Vconfigure(bool first);
};


#endif  // guard
