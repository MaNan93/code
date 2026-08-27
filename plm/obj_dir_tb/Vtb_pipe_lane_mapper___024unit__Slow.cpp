// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtb_pipe_lane_mapper.h for the primary calling header

#include "Vtb_pipe_lane_mapper__pch.h"


Vtb_pipe_lane_mapper___024unit::Vtb_pipe_lane_mapper___024unit() = default;
Vtb_pipe_lane_mapper___024unit::~Vtb_pipe_lane_mapper___024unit() = default;

void Vtb_pipe_lane_mapper___024unit::ctor(Vtb_pipe_lane_mapper__Syms* symsp, const char* namep) {
    vlSymsp = symsp;
    vlNamep = strdup(Verilated::catName(vlSymsp->name(), namep));
    // Reset structure values
}

void Vtb_pipe_lane_mapper___024unit::__Vconfigure(bool first) {
    (void)first;  // Prevent unused variable warning
}

void Vtb_pipe_lane_mapper___024unit::dtor() {
    VL_DO_DANGLING(std::free(const_cast<char*>(vlNamep)), vlNamep);
}
