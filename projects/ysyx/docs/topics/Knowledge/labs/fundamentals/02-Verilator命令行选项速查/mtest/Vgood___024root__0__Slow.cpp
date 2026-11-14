// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vgood.h for the primary calling header

#include "Vgood__pch.h"

VL_ATTR_COLD void Vgood___024root___eval_static(Vgood___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgood___024root___eval_static\n"); );
    Vgood__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__Vtrigprevexpr___TOP__a__0 = vlSelfRef.a;
    vlSelfRef.__Vtrigprevexpr___TOP__b__0 = vlSelfRef.b;
}

VL_ATTR_COLD void Vgood___024root___eval_initial(Vgood___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgood___024root___eval_initial\n"); );
    Vgood__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vgood___024root___dump_triggers__stl(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG
VL_ATTR_COLD bool Vgood___024root___trigger_anySet__stl(const VlUnpacked<QData/*63:0*/, 1> &in);

VL_ATTR_COLD bool Vgood___024root___eval_stl(Vgood___024root* vlSelf, CData/*0:0*/ firstIteration) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgood___024root___eval_stl\n"); );
    Vgood__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VstlExecute;
    // Body
    vlSelfRef.__VstlTriggered[0U] = ((0xfffffffffffffffeULL 
                                      & vlSelfRef.__VstlTriggered[0U]) 
                                     | (IData)((IData)(firstIteration)));
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vgood___024root___dump_triggers__stl(vlSelfRef.__VstlTriggered, "stl"s);
    }
#endif
    __VstlExecute = Vgood___024root___trigger_anySet__stl(vlSelfRef.__VstlTriggered);
    if (__VstlExecute) {
        {
            // Inlined CFunc: _eval_body__stl
            if ((1ULL & vlSelfRef.__VstlTriggered[0U])) {
                {
                    // Inlined CFunc: _ico_comb__TOP__0
                    vlSelfRef.f = ((IData)(vlSelfRef.a) 
                                   ^ (IData)(vlSelfRef.b));
                }
            }
        }
    }
    return (__VstlExecute);
}

VL_ATTR_COLD void Vgood___024root___eval_dump_triggers__stl(Vgood___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgood___024root___eval_dump_triggers__stl\n"); );
    Vgood__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
#ifdef VL_DEBUG
    Vgood___024root___dump_triggers__stl(vlSelfRef.__VstlTriggered, "stl"s);
#endif
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vgood___024root___dump_triggers__ico(const VlUnpacked<QData/*63:0*/, 2> &triggers, const std::string &tag);
#endif  // VL_DEBUG

VL_ATTR_COLD void Vgood___024root___eval_dump_triggers__ico(Vgood___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgood___024root___eval_dump_triggers__ico\n"); );
    Vgood__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
#ifdef VL_DEBUG
    Vgood___024root___dump_triggers__ico(vlSelfRef.__VicoTriggered, "ico"s);
#endif
}

VL_ATTR_COLD void Vgood___024root___eval_dump_triggers__act(Vgood___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgood___024root___eval_dump_triggers__act\n"); );
    Vgood__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

VL_ATTR_COLD void Vgood___024root___eval_dump_triggers__nba(Vgood___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgood___024root___eval_dump_triggers__nba\n"); );
    Vgood__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

VL_ATTR_COLD void Vgood___024root___eval_dump_triggers__obs(Vgood___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgood___024root___eval_dump_triggers__obs\n"); );
    Vgood__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

VL_ATTR_COLD void Vgood___024root___eval_dump_triggers__react(Vgood___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgood___024root___eval_dump_triggers__react\n"); );
    Vgood__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

VL_ATTR_COLD void Vgood___024root___eval_final(Vgood___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgood___024root___eval_final\n"); );
    Vgood__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vgood___024root___dump_triggers__stl(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgood___024root___dump_triggers__stl\n"); );
    // Body
    if ((1U & (~ (IData)(Vgood___024root___trigger_anySet__stl(triggers))))) {
        VL_DBG_MSGS("         No '" + tag + "' region triggers active\n");
    }
    if ((1U & (IData)(triggers[0U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 0 is active: Internal 'stl' trigger - first iteration\n");
    }
}
#endif  // VL_DEBUG

VL_ATTR_COLD bool Vgood___024root___trigger_anySet__stl(const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgood___024root___trigger_anySet__stl\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        if (in[n]) {
            return (1U);
        }
        n = ((IData)(1U) + n);
    } while ((1U > n));
    return (0U);
}

bool Vgood___024root___trigger_anySet__ico(const VlUnpacked<QData/*63:0*/, 2> &in);

#ifdef VL_DEBUG
VL_ATTR_COLD void Vgood___024root___dump_triggers__ico(const VlUnpacked<QData/*63:0*/, 2> &triggers, const std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgood___024root___dump_triggers__ico\n"); );
    // Body
    if ((1U & (~ (IData)(Vgood___024root___trigger_anySet__ico(triggers))))) {
        VL_DBG_MSGS("         No '" + tag + "' region triggers active\n");
    }
    if ((1U & (IData)(triggers[0U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 0 is active: @( a)\n");
    }
    if ((1U & (IData)((triggers[0U] >> 1U)))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 1 is active: @( b)\n");
    }
    if ((1U & (IData)(triggers[1U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 64 is active: Internal 'ico' trigger - first iteration\n");
    }
}
#endif  // VL_DEBUG

VL_ATTR_COLD void Vgood___024root___ctor_var_reset(Vgood___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgood___024root___ctor_var_reset\n"); );
    Vgood__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    const uint64_t __VscopeHash = VL_MURMUR64_HASH(vlSelf->vlNamep);
    vlSelf->a = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 510903276987443985ull);
    vlSelf->b = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 16900879642891266615ull);
    vlSelf->f = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 6217145520856553898ull);
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->__VstlTriggered[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 2; ++__Vi0) {
        vlSelf->__VicoTriggered[__Vi0] = 0;
    }
    vlSelf->__Vtrigprevexpr___TOP__a__0 = 0;
    vlSelf->__Vtrigprevexpr___TOP__b__0 = 0;
    vlSelf->__VicoDidInit = 0;
}
