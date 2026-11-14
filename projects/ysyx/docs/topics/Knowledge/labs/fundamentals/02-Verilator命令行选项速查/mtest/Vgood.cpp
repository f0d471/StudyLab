// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Model implementation (design independent parts)

#include "Vgood__pch.h"
#include "verilated_fst_c.h"

//============================================================
// Constructors

Vgood::Vgood(VerilatedContext* _vcontextp__, const char* _vcname__)
    : VerilatedModel{*_vcontextp__}
    , vlSymsp{new Vgood__Syms(contextp(), _vcname__, this)}
    , m_evalLoop{*this, /*convergeLimit:*/ 10000}
    , a{vlSymsp->TOP.a}
    , b{vlSymsp->TOP.b}
    , f{vlSymsp->TOP.f}
    , rootp{&(vlSymsp->TOP)}
{
    // Register model with the context
    contextp()->addModel(this);
    contextp()->traceBaseModelCbAdd(
        [this](VerilatedTraceBaseC* tfp, int levels, int options) { traceBaseModel(tfp, levels, options); });
}

Vgood::Vgood(const char* _vcname__)
    : Vgood(Verilated::threadContextp(), _vcname__)
{
}

//============================================================
// Destructor

Vgood::~Vgood() {
    delete vlSymsp;
}

//============================================================
// Evaluation function

#ifdef VL_DEBUG
void Vgood___024root___eval_debug_assertions(Vgood___024root* vlSelf);
#endif  // VL_DEBUG
VL_ATTR_COLD void Vgood___024root___eval_static(Vgood___024root* vlSelf);
VL_ATTR_COLD void Vgood___024root___eval_initial(Vgood___024root* vlSelf);
VL_ATTR_COLD bool Vgood___024root___eval_stl(Vgood___024root* vlSelf, CData/*0:0*/ firstIteration);
void Vgood___024root___eval_sample(Vgood___024root* vlSelf);
bool Vgood___024root___eval_ico(Vgood___024root* vlSelf, CData/*0:0*/ firstIteration);
bool Vgood___024root___eval_act(Vgood___024root* vlSelf);
bool Vgood___024root___eval_inact(Vgood___024root* vlSelf);
bool Vgood___024root___eval_nba(Vgood___024root* vlSelf);
bool Vgood___024root___eval_obs(Vgood___024root* vlSelf);
bool Vgood___024root___eval_react(Vgood___024root* vlSelf);
void Vgood___024root___eval_postponed(Vgood___024root* vlSelf);
VL_ATTR_COLD void Vgood___024root___eval_final(Vgood___024root* vlSelf);
VL_ATTR_COLD void Vgood___024root___eval_dump_triggers__stl(Vgood___024root* vlSelf);
VL_ATTR_COLD void Vgood___024root___eval_dump_triggers__ico(Vgood___024root* vlSelf);
VL_ATTR_COLD void Vgood___024root___eval_dump_triggers__act(Vgood___024root* vlSelf);
VL_ATTR_COLD void Vgood___024root___eval_dump_triggers__nba(Vgood___024root* vlSelf);
VL_ATTR_COLD void Vgood___024root___eval_dump_triggers__obs(Vgood___024root* vlSelf);
VL_ATTR_COLD void Vgood___024root___eval_dump_triggers__react(Vgood___024root* vlSelf);

void Vgood::eval_step() {
    VL_DEBUG_IF(VL_DBG_MSGF("+++++TOP Evaluate Vgood::eval_step\n"); );
    m_evalLoop.eval();
}

void Vgood::evalBegin() {
#ifdef VL_DEBUG
    // Debug assertions
    Vgood___024root___eval_debug_assertions(&(vlSymsp->TOP));
#endif  // VL_DEBUG
    vlSymsp->__Vm_activity = true;
    vlSymsp->__Vm_deleter.deleteAll();
}

void Vgood::evalEnd() {
    // Evaluate cleanup
    Verilated::endOfEval(vlSymsp->__Vm_evalMsgQp);
}

void Vgood::evalStatic() {
    Vgood___024root___eval_static(&(vlSymsp->TOP));
}

void Vgood::evalInitial() {
    Vgood___024root___eval_initial(&(vlSymsp->TOP));
}

bool Vgood::evalStl(bool firstIteration) {
    return Vgood___024root___eval_stl(&(vlSymsp->TOP), firstIteration);
}

void Vgood::evalSample() {
    Vgood___024root___eval_sample(&(vlSymsp->TOP));
}

bool Vgood::evalIco(bool firstIteration) {
    return Vgood___024root___eval_ico(&(vlSymsp->TOP), firstIteration);
}

bool Vgood::evalAct() {
    return Vgood___024root___eval_act(&(vlSymsp->TOP));
}

bool Vgood::evalInact() {
    return Vgood___024root___eval_inact(&(vlSymsp->TOP));
}

bool Vgood::evalNba() {
    return Vgood___024root___eval_nba(&(vlSymsp->TOP));
}

bool Vgood::evalObs() {
    return Vgood___024root___eval_obs(&(vlSymsp->TOP));
}

bool Vgood::evalReact() {
    return Vgood___024root___eval_react(&(vlSymsp->TOP));
}

void Vgood::evalPostponed() {
    Vgood___024root___eval_postponed(&(vlSymsp->TOP));
}

void Vgood::evalFinal() {
    Vgood___024root___eval_final(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vgood::dumpTriggersStl() {
    Vgood___024root___eval_dump_triggers__stl(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vgood::dumpTriggersIco() {
    Vgood___024root___eval_dump_triggers__ico(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vgood::dumpTriggersAct() {
    Vgood___024root___eval_dump_triggers__act(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vgood::dumpTriggersNba() {
    Vgood___024root___eval_dump_triggers__nba(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vgood::dumpTriggersObs() {
    Vgood___024root___eval_dump_triggers__obs(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vgood::dumpTriggersReact() {
    Vgood___024root___eval_dump_triggers__react(&(vlSymsp->TOP));
}

//============================================================
// Events and timing
bool Vgood::eventsPending() { return false; }

uint64_t Vgood::nextTimeSlot() {
    VL_FATAL_MT(__FILE__, __LINE__, "", "No delays in the design");
    return 0;
}

//============================================================
// Utilities

const char* Vgood::name() const {
    return vlSymsp->name();
}

//============================================================
// Invoke final blocks

VL_ATTR_COLD void Vgood::final() {
    contextp()->executingFinal(true);
    evalFinal();
    contextp()->executingFinal(false);
}

//============================================================
// Implementations of abstract methods from VerilatedModel

const char* Vgood::hierName() const { return vlSymsp->name(); }
const char* Vgood::modelName() const { return "Vgood"; }
unsigned Vgood::threads() const { return 1; }
void Vgood::prepareClone() const { contextp()->prepareClone(); }
void Vgood::atClone() const {
    contextp()->threadPoolpOnClone();
}
std::unique_ptr<VerilatedTraceConfig> Vgood::traceConfig() const {
    return std::unique_ptr<VerilatedTraceConfig>{new VerilatedTraceConfig{false}};
};

//============================================================
// Trace configuration

void Vgood___024root__trace_decl_types(VerilatedFst* tracep);

void Vgood___024root__trace_init_top(Vgood___024root* vlSelf, VerilatedFst* tracep);

VL_ATTR_COLD static void trace_init(void* voidSelf, VerilatedFst* tracep, uint32_t code) {
    // Callback from tracep->open()
    Vgood___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vgood___024root*>(voidSelf);
    Vgood__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    if (!vlSymsp->_vm_contextp__->calcUnusedSigs()) {
        VL_FATAL_MT(__FILE__, __LINE__, __FILE__,
            "Turning on wave traces requires Verilated::traceEverOn(true) call before time 0.");
    }
    vlSymsp->__Vm_baseCode = code;
    tracep->pushPrefix(vlSymsp->name(), VerilatedTracePrefixType::SCOPE_MODULE);
    Vgood___024root__trace_decl_types(tracep);
    Vgood___024root__trace_init_top(vlSelf, tracep);
    tracep->popPrefix();
}

VL_ATTR_COLD void Vgood___024root__trace_register(Vgood___024root* vlSelf, VerilatedFst* tracep);

VL_ATTR_COLD void Vgood::traceBaseModel(VerilatedTraceBaseC* tfp, int levels, int options) {
    (void)levels; (void)options;
    VerilatedFstC* const stfp = dynamic_cast<VerilatedFstC*>(tfp);
    if (VL_UNLIKELY(!stfp)) {
        vl_fatal(__FILE__, __LINE__, __FILE__,"'Vgood::trace()' called on non-VerilatedFstC object;"
            " use --trace-fst with VerilatedFst object, and --trace-vcd with VerilatedVcd object");
    }
    stfp->spTrace()->addModel(this);
    stfp->spTrace()->addInitCb(&trace_init, &(vlSymsp->TOP), name(), false, 3);
    Vgood___024root__trace_register(&(vlSymsp->TOP), stfp->spTrace());
}
