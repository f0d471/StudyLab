// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vgood.h for the primary calling header

#include "Vgood__pch.h"

void Vgood___024root___eval_sample(Vgood___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgood___024root___eval_sample\n"); );
    Vgood__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vgood___024root___dump_triggers__ico(const VlUnpacked<QData/*63:0*/, 2> &triggers, const std::string &tag);
#endif  // VL_DEBUG
bool Vgood___024root___trigger_anySet__ico(const VlUnpacked<QData/*63:0*/, 2> &in);

bool Vgood___024root___eval_ico(Vgood___024root* vlSelf, CData/*0:0*/ firstIteration) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgood___024root___eval_ico\n"); );
    Vgood__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VicoExecute;
    // Body
    vlSelfRef.__VicoTriggered[1U] = ((0xfffffffffffffffeULL 
                                      & vlSelfRef.__VicoTriggered[1U]) 
                                     | (IData)((IData)(firstIteration)));
    {
        // Inlined CFunc: _eval_triggers_vec__ico
        vlSelfRef.__VicoTriggered[0U] = (QData)((IData)(
                                                        ((((IData)(vlSelfRef.b) 
                                                           != (IData)(vlSelfRef.__Vtrigprevexpr___TOP__b__0)) 
                                                          << 1U) 
                                                         | ((IData)(vlSelfRef.a) 
                                                            != (IData)(vlSelfRef.__Vtrigprevexpr___TOP__a__0)))));
        vlSelfRef.__Vtrigprevexpr___TOP__a__0 = vlSelfRef.a;
        vlSelfRef.__Vtrigprevexpr___TOP__b__0 = vlSelfRef.b;
        if (VL_UNLIKELY(((1U & (~ (IData)(vlSelfRef.__VicoDidInit)))))) {
            vlSelfRef.__VicoDidInit = 1U;
            vlSelfRef.__VicoTriggered[0U] = (1ULL | vlSelfRef.__VicoTriggered[0U]);
            vlSelfRef.__VicoTriggered[0U] = (2ULL | vlSelfRef.__VicoTriggered[0U]);
        }
    }
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vgood___024root___dump_triggers__ico(vlSelfRef.__VicoTriggered, "ico"s);
    }
#endif
    __VicoExecute = Vgood___024root___trigger_anySet__ico(vlSelfRef.__VicoTriggered);
    if (__VicoExecute) {
        {
            // Inlined CFunc: _eval_body__ico
            if ((3ULL & vlSelfRef.__VicoTriggered[0U])) {
                {
                    // Inlined CFunc: _ico_comb__TOP__0
                    vlSelfRef.f = ((IData)(vlSelfRef.a) 
                                   ^ (IData)(vlSelfRef.b));
                }
            }
        }
    }
    return (__VicoExecute);
}

bool Vgood___024root___eval_act(Vgood___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgood___024root___eval_act\n"); );
    Vgood__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    return (0U);
}

bool Vgood___024root___eval_inact(Vgood___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgood___024root___eval_inact\n"); );
    Vgood__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    return (0U);
}

bool Vgood___024root___eval_nba(Vgood___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgood___024root___eval_nba\n"); );
    Vgood__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    return (0U);
}

bool Vgood___024root___eval_obs(Vgood___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgood___024root___eval_obs\n"); );
    Vgood__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    return (0U);
}

bool Vgood___024root___eval_react(Vgood___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgood___024root___eval_react\n"); );
    Vgood__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    return (0U);
}

void Vgood___024root___eval_postponed(Vgood___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgood___024root___eval_postponed\n"); );
    Vgood__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

bool Vgood___024root___trigger_anySet__ico(const VlUnpacked<QData/*63:0*/, 2> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgood___024root___trigger_anySet__ico\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        if (in[n]) {
            return (1U);
        }
        n = ((IData)(1U) + n);
    } while ((2U > n));
    return (0U);
}

#ifdef VL_DEBUG
void Vgood___024root___eval_debug_assertions(Vgood___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgood___024root___eval_debug_assertions\n"); );
    Vgood__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if (VL_UNLIKELY(((vlSelfRef.a & 0xfeU)))) {
        Verilated::overWidthError("a");
    }
    if (VL_UNLIKELY(((vlSelfRef.b & 0xfeU)))) {
        Verilated::overWidthError("b");
    }
}
#endif  // VL_DEBUG
