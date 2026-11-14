// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vgood.h for the primary calling header

#include "Vgood__pch.h"

void Vgood___024root___ctor_var_reset(Vgood___024root* vlSelf);

Vgood___024root::Vgood___024root(Vgood__Syms* symsp, const char* namep)
 {
    vlSymsp = symsp;
    vlNamep = strdup(namep);
    // Reset structure values
    Vgood___024root___ctor_var_reset(this);
}

void Vgood___024root::__Vconfigure(bool first) {
    (void)first;  // Prevent unused variable warning
}

Vgood___024root::~Vgood___024root() {
    VL_DO_DANGLING(std::free(const_cast<char*>(vlNamep)), vlNamep);
}
