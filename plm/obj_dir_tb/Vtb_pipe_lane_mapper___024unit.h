// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vtb_pipe_lane_mapper.h for the primary calling header

#ifndef VERILATED_VTB_PIPE_LANE_MAPPER___024UNIT_H_
#define VERILATED_VTB_PIPE_LANE_MAPPER___024UNIT_H_  // guard

#include "verilated.h"
#include "verilated_timing.h"


class Vtb_pipe_lane_mapper__Syms;

class alignas(VL_CACHE_LINE_BYTES) Vtb_pipe_lane_mapper___024unit final {
  public:

    // INTERNAL VARIABLES
    Vtb_pipe_lane_mapper__Syms* vlSymsp;
    const char* vlNamep;

    // CONSTRUCTORS
    Vtb_pipe_lane_mapper___024unit();
    ~Vtb_pipe_lane_mapper___024unit();
    void ctor(Vtb_pipe_lane_mapper__Syms* symsp, const char* namep);
    void dtor();
    VL_UNCOPYABLE(Vtb_pipe_lane_mapper___024unit);

    // INTERNAL METHODS
    void __Vconfigure(bool first);
};


#endif  // guard
