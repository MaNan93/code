// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtb_pipe_lane_mapper.h for the primary calling header

#include "Vtb_pipe_lane_mapper__pch.h"

// Parameter definitions for Vtb_pipe_lane_mapper___024root
constexpr VlUnpacked<IData/*31:0*/, 16> Vtb_pipe_lane_mapper___024root::tb_pipe_lane_mapper__DOT__PERIOD_NS;
constexpr VlUnpacked<IData/*31:0*/, 4> Vtb_pipe_lane_mapper___024root::tb_pipe_lane_mapper__DOT__G1_LANES;
constexpr VlUnpacked<IData/*31:0*/, 4> Vtb_pipe_lane_mapper___024root::tb_pipe_lane_mapper__DOT__G2_LANES;
constexpr VlUnpacked<IData/*31:0*/, 4> Vtb_pipe_lane_mapper___024root::tb_pipe_lane_mapper__DOT__G3_LANES;


void Vtb_pipe_lane_mapper___024root___ctor_var_reset(Vtb_pipe_lane_mapper___024root* vlSelf);

Vtb_pipe_lane_mapper___024root::Vtb_pipe_lane_mapper___024root(Vtb_pipe_lane_mapper__Syms* symsp, const char* namep)
    : __VdlySched{*symsp->_vm_contextp__}
 {
    vlSymsp = symsp;
    vlNamep = strdup(namep);
    // Reset structure values
    Vtb_pipe_lane_mapper___024root___ctor_var_reset(this);
}

void Vtb_pipe_lane_mapper___024root::__Vconfigure(bool first) {
    (void)first;  // Prevent unused variable warning
}

Vtb_pipe_lane_mapper___024root::~Vtb_pipe_lane_mapper___024root() {
    VL_DO_DANGLING(std::free(const_cast<char*>(vlNamep)), vlNamep);
}
