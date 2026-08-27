// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Tracing implementation internals

#include "verilated_vcd_c.h"
#include "Vtb_pipe_lane_mapper__Syms.h"


VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_init_sub__TOP__pipe_pkg__0(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd* tracep);
VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_init_dtype____0(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd* tracep, const char* name, uint32_t fidx, uint32_t c, VerilatedTraceSigDirection direction);
VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_init_dtype____1(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd* tracep, const char* name, uint32_t fidx, uint32_t c, VerilatedTraceSigDirection direction);
VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_init_dtype____2(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd* tracep, const char* name, uint32_t fidx, uint32_t c, VerilatedTraceSigDirection direction);
VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_init_dtype____3(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd* tracep, const char* name, uint32_t fidx, uint32_t c, VerilatedTraceSigDirection direction);

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_init_sub__TOP__0(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd* tracep) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root__trace_init_sub__TOP__0\n"); );
    Vtb_pipe_lane_mapper__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    const int c = vlSymsp->__Vm_baseCode;
    VL_TRACE_PUSH_PREFIX(tracep, "pipe_pkg", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    Vtb_pipe_lane_mapper___024root__trace_init_sub__TOP__pipe_pkg__0(vlSelf, tracep);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "tb_pipe_lane_mapper", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+554,0,"NUM_MODES",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+555,0,"LANE_COUNT",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+554,0,"NUM_CTRL",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);

    Vtb_pipe_lane_mapper___024root__trace_init_dtype____0(vlSelf, tracep, "PERIOD_NS", 0, c+556, VerilatedTraceSigDirection::NONE);
    VL_TRACE_DECL_BUS(tracep,c+495,0,"phy_pclk_out",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 15,0);
    VL_TRACE_DECL_BIT(tracep,c+572,0,"test_en",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BUS(tracep,c+0,0,"ctrl_rst_n",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 3,0);
    VL_TRACE_DECL_BUS(tracep,c+496,0,"mode",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_BUS(tracep,c+497,0,"ctrl_pclk",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 3,0);
    VL_TRACE_DECL_BUS(tracep,c+498,0,"phy_pclk_in",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 15,0);
    VL_TRACE_DECL_BUS(tracep,c+499,0,"phy_rst_n",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 15,0);
    VL_TRACE_DECL_WIDE(tracep,c+446,0,"phy_mac2phy",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 1535,0);
    VL_TRACE_DECL_WIDE(tracep,c+573,0,"phy_phy2mac",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 1599,0);
    VL_TRACE_DECL_WIDE(tracep,c+623,0,"ctrl0_mac2phy",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 1535,0);
    VL_TRACE_DECL_WIDE(tracep,c+209,0,"ctrl0_phy2mac",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 1599,0);
    VL_TRACE_DECL_WIDE(tracep,c+671,0,"ctrl1_mac2phy",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 383,0);
    VL_TRACE_DECL_WIDE(tracep,c+388,0,"ctrl1_phy2mac",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 399,0);
    VL_TRACE_DECL_WIDE(tracep,c+683,0,"ctrl2_mac2phy",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 767,0);
    VL_TRACE_DECL_WIDE(tracep,c+90,0,"ctrl2_phy2mac",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 799,0);
    VL_TRACE_DECL_WIDE(tracep,c+707,0,"ctrl3_mac2phy",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 383,0);
    VL_TRACE_DECL_WIDE(tracep,c+18,0,"ctrl3_phy2mac",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 399,0);
    VL_TRACE_DECL_BUS(tracep,c+500,0,"err_count",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::INT, 31,0);

    Vtb_pipe_lane_mapper___024root__trace_init_dtype____1(vlSelf, tracep, "G1_LANES", 0, c+719, VerilatedTraceSigDirection::NONE);

    Vtb_pipe_lane_mapper___024root__trace_init_dtype____2(vlSelf, tracep, "G2_LANES", 0, c+723, VerilatedTraceSigDirection::NONE);

    Vtb_pipe_lane_mapper___024root__trace_init_dtype____3(vlSelf, tracep, "G3_LANES", 0, c+727, VerilatedTraceSigDirection::NONE);
    VL_TRACE_DECL_DOUBLE(tracep,c+731,0,"SETTLE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::DOUBLE);
    VL_TRACE_PUSH_PREFIX(tracep, "dut", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+554,0,"NUM_MODES",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+555,0,"LANE_COUNT",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+554,0,"NUM_CTRL",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+495,0,"phy_pclk_out",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 15,0);
    VL_TRACE_DECL_BIT(tracep,c+572,0,"test_en",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BUS(tracep,c+0,0,"ctrl_rst_n",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 3,0);
    VL_TRACE_DECL_BUS(tracep,c+496,0,"mode",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_BUS(tracep,c+497,0,"ctrl_pclk",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 3,0);
    VL_TRACE_DECL_BUS(tracep,c+498,0,"phy_pclk_in",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 15,0);
    VL_TRACE_DECL_BUS(tracep,c+499,0,"phy_rst_n",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 15,0);
    VL_TRACE_DECL_WIDE(tracep,c+446,0,"phy_mac2phy",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1535,0);
    VL_TRACE_DECL_WIDE(tracep,c+573,0,"phy_phy2mac",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1599,0);
    VL_TRACE_DECL_WIDE(tracep,c+623,0,"ctrl0_mac2phy",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1535,0);
    VL_TRACE_DECL_WIDE(tracep,c+209,0,"ctrl0_phy2mac",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1599,0);
    VL_TRACE_DECL_WIDE(tracep,c+671,0,"ctrl1_mac2phy",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 383,0);
    VL_TRACE_DECL_WIDE(tracep,c+388,0,"ctrl1_phy2mac",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 399,0);
    VL_TRACE_DECL_WIDE(tracep,c+683,0,"ctrl2_mac2phy",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 767,0);
    VL_TRACE_DECL_WIDE(tracep,c+90,0,"ctrl2_phy2mac",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 799,0);
    VL_TRACE_DECL_WIDE(tracep,c+707,0,"ctrl3_mac2phy",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 383,0);
    VL_TRACE_DECL_WIDE(tracep,c+18,0,"ctrl3_phy2mac",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 399,0);
    VL_TRACE_DECL_BUS(tracep,c+494,0,"sel_tgt",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 6,0);
    VL_TRACE_PUSH_PREFIX(tracep, "u_clk_top", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+554,0,"NUM_MODES",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+555,0,"LANE_COUNT",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+554,0,"NUM_CTRL",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+495,0,"phy_pclk_out",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 15,0);
    VL_TRACE_DECL_BIT(tracep,c+572,0,"test_en",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BUS(tracep,c+496,0,"mode",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_BUS(tracep,c+0,0,"ctrl_rst_n",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 3,0);
    VL_TRACE_DECL_BUS(tracep,c+497,0,"ctrl_pclk",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 3,0);
    VL_TRACE_DECL_BUS(tracep,c+498,0,"phy_pclk_in",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 15,0);
    VL_TRACE_DECL_BUS(tracep,c+494,0,"sel_tgt",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 6,0);
    VL_TRACE_DECL_BUS(tracep,c+10,0,"dec_tgt",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 6,0);
    VL_TRACE_DECL_BUS(tracep,c+501,0,"pin_gated_g1",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_BIT(tracep,c+502,0,"pclk_in_g1",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BUS(tracep,c+503,0,"pin_gated_g2",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_BIT(tracep,c+504,0,"pclk_in_g2",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BUS(tracep,c+505,0,"pin_gated_g3",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 2,0);
    VL_TRACE_DECL_BIT(tracep,c+506,0,"pclk_in_g3",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_PUSH_PREFIX(tracep, "u_decoder", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+554,0,"NUM_MODES",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+554,0,"NUM_CTRL",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+496,0,"mode",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_BUS(tracep,c+10,0,"sel_tgt",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 6,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_pin_gate_g1_b0", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BIT(tracep,c+507,0,"clk_in",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+259,0,"en",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+572,0,"test_en",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+508,0,"clk_out",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+509,0,"en_latched",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_pin_gate_g1_b1", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BIT(tracep,c+510,0,"clk_in",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+401,0,"en",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+572,0,"test_en",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+511,0,"clk_out",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+512,0,"en_latched",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_pin_gate_g2_b0", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BIT(tracep,c+507,0,"clk_in",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+260,0,"en",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+572,0,"test_en",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+513,0,"clk_out",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+514,0,"en_latched",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_pin_gate_g2_b1", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BIT(tracep,c+515,0,"clk_in",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+115,0,"en",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+572,0,"test_en",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+516,0,"clk_out",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+517,0,"en_latched",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_pin_gate_g3_b0", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BIT(tracep,c+507,0,"clk_in",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+261,0,"en",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+572,0,"test_en",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+518,0,"clk_out",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+519,0,"en_latched",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_pin_gate_g3_b1", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BIT(tracep,c+515,0,"clk_in",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+116,0,"en",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+572,0,"test_en",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+520,0,"clk_out",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+521,0,"en_latched",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_pin_gate_g3_b2", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BIT(tracep,c+522,0,"clk_in",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+31,0,"en",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+572,0,"test_en",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+523,0,"clk_out",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+524,0,"en_latched",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_sel_sync_g1", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+733,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BIT(tracep,c+734,0,"SYNC",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::BIT);
    VL_TRACE_DECL_BUS(tracep,c+7,0,"branch_clk",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_BUS(tracep,c+1,0,"branch_rst_n",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_BUS(tracep,c+11,0,"tgt",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_BUS(tracep,c+443,0,"en",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_PUSH_PREFIX(tracep, "g_sync", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_PUSH_PREFIX(tracep, "g_branch[0]", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+735,0,"self_mask",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_BIT(tracep,c+444,0,"other_idle",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+525,0,"tgt_r",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+526,0,"d_in",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_PUSH_PREFIX(tracep, "u_sync_en", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+736,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BIT(tracep,c+507,0,"clk",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+2,0,"rst_n",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BUS(tracep,c+527,0,"d",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 0,0);
    VL_TRACE_DECL_BUS(tracep,c+262,0,"q",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 0,0);
    VL_TRACE_DECL_BUS(tracep,c+263,0,"meta",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 0,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "g_branch[1]", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+737,0,"self_mask",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_BIT(tracep,c+445,0,"other_idle",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+528,0,"tgt_r",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+529,0,"d_in",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_PUSH_PREFIX(tracep, "u_sync_en", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+736,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BIT(tracep,c+510,0,"clk",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+3,0,"rst_n",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BUS(tracep,c+530,0,"d",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 0,0);
    VL_TRACE_DECL_BUS(tracep,c+402,0,"q",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 0,0);
    VL_TRACE_DECL_BUS(tracep,c+403,0,"meta",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 0,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_sel_sync_g2", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+733,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BIT(tracep,c+734,0,"SYNC",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::BIT);
    VL_TRACE_DECL_BUS(tracep,c+8,0,"branch_clk",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_BUS(tracep,c+12,0,"branch_rst_n",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_BUS(tracep,c+13,0,"tgt",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_BUS(tracep,c+436,0,"en",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_PUSH_PREFIX(tracep, "g_sync", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_PUSH_PREFIX(tracep, "g_branch[0]", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+735,0,"self_mask",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_BIT(tracep,c+437,0,"other_idle",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+531,0,"tgt_r",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+532,0,"d_in",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_PUSH_PREFIX(tracep, "u_sync_en", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+736,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BIT(tracep,c+507,0,"clk",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+2,0,"rst_n",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BUS(tracep,c+533,0,"d",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 0,0);
    VL_TRACE_DECL_BUS(tracep,c+264,0,"q",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 0,0);
    VL_TRACE_DECL_BUS(tracep,c+265,0,"meta",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 0,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "g_branch[1]", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+737,0,"self_mask",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_BIT(tracep,c+438,0,"other_idle",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+534,0,"tgt_r",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+535,0,"d_in",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_PUSH_PREFIX(tracep, "u_sync_en", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+736,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BIT(tracep,c+515,0,"clk",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+4,0,"rst_n",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BUS(tracep,c+536,0,"d",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 0,0);
    VL_TRACE_DECL_BUS(tracep,c+117,0,"q",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 0,0);
    VL_TRACE_DECL_BUS(tracep,c+118,0,"meta",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 0,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_sel_sync_g3", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+738,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BIT(tracep,c+734,0,"SYNC",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::BIT);
    VL_TRACE_DECL_BUS(tracep,c+9,0,"branch_clk",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 2,0);
    VL_TRACE_DECL_BUS(tracep,c+14,0,"branch_rst_n",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 2,0);
    VL_TRACE_DECL_BUS(tracep,c+15,0,"tgt",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 2,0);
    VL_TRACE_DECL_BUS(tracep,c+439,0,"en",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 2,0);
    VL_TRACE_PUSH_PREFIX(tracep, "g_sync", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_PUSH_PREFIX(tracep, "g_branch[0]", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+739,0,"self_mask",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 2,0);
    VL_TRACE_DECL_BIT(tracep,c+440,0,"other_idle",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+537,0,"tgt_r",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+538,0,"d_in",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_PUSH_PREFIX(tracep, "u_sync_en", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+736,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BIT(tracep,c+507,0,"clk",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+2,0,"rst_n",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BUS(tracep,c+539,0,"d",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 0,0);
    VL_TRACE_DECL_BUS(tracep,c+266,0,"q",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 0,0);
    VL_TRACE_DECL_BUS(tracep,c+267,0,"meta",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 0,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "g_branch[1]", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+740,0,"self_mask",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 2,0);
    VL_TRACE_DECL_BIT(tracep,c+441,0,"other_idle",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+540,0,"tgt_r",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+541,0,"d_in",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_PUSH_PREFIX(tracep, "u_sync_en", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+736,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BIT(tracep,c+515,0,"clk",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+4,0,"rst_n",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BUS(tracep,c+542,0,"d",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 0,0);
    VL_TRACE_DECL_BUS(tracep,c+119,0,"q",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 0,0);
    VL_TRACE_DECL_BUS(tracep,c+120,0,"meta",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 0,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "g_branch[2]", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+741,0,"self_mask",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 2,0);
    VL_TRACE_DECL_BIT(tracep,c+442,0,"other_idle",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+543,0,"tgt_r",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+544,0,"d_in",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_PUSH_PREFIX(tracep, "u_sync_en", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+736,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BIT(tracep,c+522,0,"clk",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+5,0,"rst_n",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BUS(tracep,c+545,0,"d",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 0,0);
    VL_TRACE_DECL_BUS(tracep,c+32,0,"q",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 0,0);
    VL_TRACE_DECL_BUS(tracep,c+33,0,"meta",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 0,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_data_m2p", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+555,0,"LANE_COUNT",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+494,0,"sel_tgt",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 6,0);
    VL_TRACE_DECL_WIDE(tracep,c+446,0,"phy_mac2phy",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1535,0);
    VL_TRACE_DECL_WIDE(tracep,c+623,0,"ctrl0_mac2phy",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1535,0);
    VL_TRACE_DECL_WIDE(tracep,c+671,0,"ctrl1_mac2phy",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 383,0);
    VL_TRACE_DECL_WIDE(tracep,c+683,0,"ctrl2_mac2phy",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 767,0);
    VL_TRACE_DECL_WIDE(tracep,c+707,0,"ctrl3_mac2phy",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 383,0);
    VL_TRACE_PUSH_PREFIX(tracep, "u_m2p_l10", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+742,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+733,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+743,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_DECL_BUS(tracep,c+436,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_WIDE(tracep,c+746,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 191,0);
    VL_TRACE_DECL_WIDE(tracep,c+185,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_DECL_WIDE(tracep,c+188,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_m2p_l11", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+742,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+733,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+743,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_DECL_BUS(tracep,c+436,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_WIDE(tracep,c+752,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 191,0);
    VL_TRACE_DECL_WIDE(tracep,c+191,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_DECL_WIDE(tracep,c+194,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_m2p_l12", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+742,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+738,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+743,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_DECL_BUS(tracep,c+439,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 2,0);
    VL_TRACE_DECL_WIDE(tracep,c+758,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 287,0);
    VL_TRACE_DECL_WIDE(tracep,c+66,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_DECL_WIDE(tracep,c+69,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_m2p_l13", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+742,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+738,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+743,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_DECL_BUS(tracep,c+439,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 2,0);
    VL_TRACE_DECL_WIDE(tracep,c+767,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 287,0);
    VL_TRACE_DECL_WIDE(tracep,c+72,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_DECL_WIDE(tracep,c+75,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_m2p_l14", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+742,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+738,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+743,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_DECL_BUS(tracep,c+439,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 2,0);
    VL_TRACE_DECL_WIDE(tracep,c+776,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 287,0);
    VL_TRACE_DECL_WIDE(tracep,c+78,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_DECL_WIDE(tracep,c+81,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_m2p_l15", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+742,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+738,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+743,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_DECL_BUS(tracep,c+439,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 2,0);
    VL_TRACE_DECL_WIDE(tracep,c+785,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 287,0);
    VL_TRACE_DECL_WIDE(tracep,c+84,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_DECL_WIDE(tracep,c+87,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_m2p_l4", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+742,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+733,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+743,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_DECL_BUS(tracep,c+443,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_WIDE(tracep,c+794,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 191,0);
    VL_TRACE_DECL_WIDE(tracep,c+364,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_DECL_WIDE(tracep,c+367,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_m2p_l5", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+742,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+733,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+743,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_DECL_BUS(tracep,c+443,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_WIDE(tracep,c+800,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 191,0);
    VL_TRACE_DECL_WIDE(tracep,c+370,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_DECL_WIDE(tracep,c+373,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_m2p_l6", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+742,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+733,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+743,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_DECL_BUS(tracep,c+443,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_WIDE(tracep,c+806,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 191,0);
    VL_TRACE_DECL_WIDE(tracep,c+376,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_DECL_WIDE(tracep,c+379,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_m2p_l7", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+742,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+733,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+743,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_DECL_BUS(tracep,c+443,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_WIDE(tracep,c+812,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 191,0);
    VL_TRACE_DECL_WIDE(tracep,c+382,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_DECL_WIDE(tracep,c+385,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_m2p_l8", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+742,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+733,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+743,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_DECL_BUS(tracep,c+436,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_WIDE(tracep,c+818,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 191,0);
    VL_TRACE_DECL_WIDE(tracep,c+197,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_DECL_WIDE(tracep,c+200,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_m2p_l9", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+742,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+733,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+743,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_DECL_BUS(tracep,c+436,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_WIDE(tracep,c+824,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 191,0);
    VL_TRACE_DECL_WIDE(tracep,c+203,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_DECL_WIDE(tracep,c+206,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_data_p2m", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+555,0,"LANE_COUNT",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+494,0,"sel_tgt",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 6,0);
    VL_TRACE_DECL_WIDE(tracep,c+573,0,"phy_phy2mac",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1599,0);
    VL_TRACE_DECL_WIDE(tracep,c+209,0,"ctrl0_phy2mac",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1599,0);
    VL_TRACE_DECL_WIDE(tracep,c+388,0,"ctrl1_phy2mac",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 399,0);
    VL_TRACE_DECL_WIDE(tracep,c+90,0,"ctrl2_phy2mac",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 799,0);
    VL_TRACE_DECL_WIDE(tracep,c+18,0,"ctrl3_phy2mac",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 399,0);
    VL_TRACE_PUSH_PREFIX(tracep, "u_p2m_ctrl0_10", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+830,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+733,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+831,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_BUS(tracep,c+436,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_WIDE(tracep,c+835,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 199,0);
    VL_TRACE_DECL_WIDE(tracep,c+268,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_WIDE(tracep,c+272,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_p2m_ctrl0_11", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+830,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+733,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+831,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_BUS(tracep,c+436,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_WIDE(tracep,c+842,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 199,0);
    VL_TRACE_DECL_WIDE(tracep,c+276,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_WIDE(tracep,c+280,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_p2m_ctrl0_12", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+830,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+738,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+831,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_BUS(tracep,c+439,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 2,0);
    VL_TRACE_DECL_WIDE(tracep,c+849,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 299,0);
    VL_TRACE_DECL_WIDE(tracep,c+284,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_WIDE(tracep,c+288,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_p2m_ctrl0_13", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+830,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+738,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+831,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_BUS(tracep,c+439,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 2,0);
    VL_TRACE_DECL_WIDE(tracep,c+859,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 299,0);
    VL_TRACE_DECL_WIDE(tracep,c+292,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_WIDE(tracep,c+296,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_p2m_ctrl0_14", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+830,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+738,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+831,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_BUS(tracep,c+439,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 2,0);
    VL_TRACE_DECL_WIDE(tracep,c+869,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 299,0);
    VL_TRACE_DECL_WIDE(tracep,c+300,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_WIDE(tracep,c+304,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_p2m_ctrl0_15", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+830,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+738,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+831,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_BUS(tracep,c+439,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 2,0);
    VL_TRACE_DECL_WIDE(tracep,c+879,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 299,0);
    VL_TRACE_DECL_WIDE(tracep,c+308,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_WIDE(tracep,c+312,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_p2m_ctrl0_4", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+830,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+733,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+831,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_BUS(tracep,c+443,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_WIDE(tracep,c+889,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 199,0);
    VL_TRACE_DECL_WIDE(tracep,c+316,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_WIDE(tracep,c+320,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_p2m_ctrl0_5", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+830,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+733,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+831,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_BUS(tracep,c+443,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_WIDE(tracep,c+896,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 199,0);
    VL_TRACE_DECL_WIDE(tracep,c+324,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_WIDE(tracep,c+328,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_p2m_ctrl0_6", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+830,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+733,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+831,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_BUS(tracep,c+443,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_WIDE(tracep,c+903,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 199,0);
    VL_TRACE_DECL_WIDE(tracep,c+332,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_WIDE(tracep,c+336,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_p2m_ctrl0_7", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+830,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+733,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+831,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_BUS(tracep,c+443,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_WIDE(tracep,c+910,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 199,0);
    VL_TRACE_DECL_WIDE(tracep,c+340,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_WIDE(tracep,c+344,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_p2m_ctrl0_8", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+830,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+733,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+831,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_BUS(tracep,c+436,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_WIDE(tracep,c+917,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 199,0);
    VL_TRACE_DECL_WIDE(tracep,c+348,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_WIDE(tracep,c+352,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_p2m_ctrl0_9", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+830,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+733,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+831,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_BUS(tracep,c+436,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_WIDE(tracep,c+924,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 199,0);
    VL_TRACE_DECL_WIDE(tracep,c+356,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_WIDE(tracep,c+360,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_p2m_ctrl1_0", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+830,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+733,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+831,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_BUS(tracep,c+443,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_WIDE(tracep,c+931,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 199,0);
    VL_TRACE_DECL_WIDE(tracep,c+404,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_WIDE(tracep,c+408,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_p2m_ctrl1_1", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+830,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+733,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+831,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_BUS(tracep,c+443,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_WIDE(tracep,c+938,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 199,0);
    VL_TRACE_DECL_WIDE(tracep,c+412,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_WIDE(tracep,c+416,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_p2m_ctrl1_2", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+830,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+733,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+831,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_BUS(tracep,c+443,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_WIDE(tracep,c+945,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 199,0);
    VL_TRACE_DECL_WIDE(tracep,c+420,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_WIDE(tracep,c+424,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_p2m_ctrl1_3", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+830,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+733,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+831,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_BUS(tracep,c+443,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_WIDE(tracep,c+952,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 199,0);
    VL_TRACE_DECL_WIDE(tracep,c+428,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_WIDE(tracep,c+432,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_p2m_ctrl2_0", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+830,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+733,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+831,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_BUS(tracep,c+436,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_WIDE(tracep,c+959,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 199,0);
    VL_TRACE_DECL_WIDE(tracep,c+121,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_WIDE(tracep,c+125,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_p2m_ctrl2_1", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+830,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+733,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+831,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_BUS(tracep,c+436,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_WIDE(tracep,c+966,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 199,0);
    VL_TRACE_DECL_WIDE(tracep,c+129,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_WIDE(tracep,c+133,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_p2m_ctrl2_2", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+830,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+733,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+831,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_BUS(tracep,c+436,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_WIDE(tracep,c+973,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 199,0);
    VL_TRACE_DECL_WIDE(tracep,c+137,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_WIDE(tracep,c+141,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_p2m_ctrl2_3", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+830,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+733,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+831,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_BUS(tracep,c+436,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_WIDE(tracep,c+980,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 199,0);
    VL_TRACE_DECL_WIDE(tracep,c+145,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_WIDE(tracep,c+149,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_p2m_ctrl2_4", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+830,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+738,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+831,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_BUS(tracep,c+439,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 2,0);
    VL_TRACE_DECL_WIDE(tracep,c+987,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 299,0);
    VL_TRACE_DECL_WIDE(tracep,c+153,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_WIDE(tracep,c+157,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_p2m_ctrl2_5", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+830,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+738,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+831,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_BUS(tracep,c+439,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 2,0);
    VL_TRACE_DECL_WIDE(tracep,c+997,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 299,0);
    VL_TRACE_DECL_WIDE(tracep,c+161,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_WIDE(tracep,c+165,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_p2m_ctrl2_6", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+830,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+738,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+831,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_BUS(tracep,c+439,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 2,0);
    VL_TRACE_DECL_WIDE(tracep,c+1007,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 299,0);
    VL_TRACE_DECL_WIDE(tracep,c+169,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_WIDE(tracep,c+173,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_p2m_ctrl2_7", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+830,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+738,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+831,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_BUS(tracep,c+439,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 2,0);
    VL_TRACE_DECL_WIDE(tracep,c+1017,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 299,0);
    VL_TRACE_DECL_WIDE(tracep,c+177,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_WIDE(tracep,c+181,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_p2m_ctrl3_0", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+830,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+738,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+831,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_BUS(tracep,c+439,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 2,0);
    VL_TRACE_DECL_WIDE(tracep,c+1027,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 299,0);
    VL_TRACE_DECL_WIDE(tracep,c+34,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_WIDE(tracep,c+38,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_p2m_ctrl3_1", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+830,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+738,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+831,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_BUS(tracep,c+439,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 2,0);
    VL_TRACE_DECL_WIDE(tracep,c+1037,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 299,0);
    VL_TRACE_DECL_WIDE(tracep,c+42,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_WIDE(tracep,c+46,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_p2m_ctrl3_2", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+830,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+738,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+831,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_BUS(tracep,c+439,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 2,0);
    VL_TRACE_DECL_WIDE(tracep,c+1047,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 299,0);
    VL_TRACE_DECL_WIDE(tracep,c+50,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_WIDE(tracep,c+54,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_p2m_ctrl3_3", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+830,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+738,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_WIDE(tracep,c+831,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_BUS(tracep,c+439,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 2,0);
    VL_TRACE_DECL_WIDE(tracep,c+1057,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 299,0);
    VL_TRACE_DECL_WIDE(tracep,c+58,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_DECL_WIDE(tracep,c+62,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 99,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_rst_top", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+555,0,"LANE_COUNT",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+554,0,"NUM_CTRL",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+0,0,"ctrl_rst_n",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 3,0);
    VL_TRACE_DECL_BUS(tracep,c+494,0,"sel_tgt",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 6,0);
    VL_TRACE_DECL_BUS(tracep,c+499,0,"phy_rst_n",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 15,0);
    VL_TRACE_DECL_BIT(tracep,c+546,0,"rst_n_g1",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+547,0,"rst_n_g2",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_DECL_BIT(tracep,c+548,0,"rst_n_g3",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC);
    VL_TRACE_PUSH_PREFIX(tracep, "u_rst_g1", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+736,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+733,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+1067,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 0,0);
    VL_TRACE_DECL_BUS(tracep,c+443,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_BUS(tracep,c+6,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_BUS(tracep,c+549,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 0,0);
    VL_TRACE_DECL_BUS(tracep,c+549,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 0,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_rst_g2", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+736,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+733,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+1067,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 0,0);
    VL_TRACE_DECL_BUS(tracep,c+436,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_BUS(tracep,c+16,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 1,0);
    VL_TRACE_DECL_BUS(tracep,c+550,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 0,0);
    VL_TRACE_DECL_BUS(tracep,c+550,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 0,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "u_rst_g3", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+736,0,"WIDTH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+738,0,"N",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_DECL_BUS(tracep,c+1067,0,"SAFE",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 0,0);
    VL_TRACE_DECL_BUS(tracep,c+439,0,"sel",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 2,0);
    VL_TRACE_DECL_BUS(tracep,c+17,0,"din",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 2,0);
    VL_TRACE_DECL_BUS(tracep,c+551,0,"dout",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, 0,0);
    VL_TRACE_DECL_BUS(tracep,c+551,0,"acc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, 0,0);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_PUSH_PREFIX(tracep, "unnamedblk15", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_PUSH_PREFIX(tracep, "unnamedblk16", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BUS(tracep,c+552,0,"pulse_cid",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::INT, 31,0);
    VL_TRACE_PUSH_PREFIX(tracep, "unnamedblk17", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_PUSH_PREFIX(tracep, "unnamedblk18", VerilatedTracePrefixType::SCOPE_MODULE, 0, 0);
    VL_TRACE_DECL_BIT(tracep,c+553,0,"expect_low",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::BIT);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_POP_PREFIX(tracep);
    VL_TRACE_POP_PREFIX(tracep);
}

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_init_dtype_sub____0(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd* tracep, const char* name, uint32_t fidx, uint32_t c, VerilatedTraceSigDirection direction);

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_init_dtype____0(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd* tracep, const char* name, uint32_t fidx, uint32_t c, VerilatedTraceSigDirection direction) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root__trace_init_dtype____0\n"); );
    Vtb_pipe_lane_mapper__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    Vtb_pipe_lane_mapper___024root__trace_init_dtype_sub____0(vlSelf, tracep, name, fidx, c, direction);
}

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_init_dtype_sub____0(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd* tracep, const char* name, uint32_t fidx, uint32_t c, VerilatedTraceSigDirection direction) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root__trace_init_dtype_sub____0\n"); );
    Vtb_pipe_lane_mapper__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    VL_TRACE_PUSH_PREFIX(tracep, name, VerilatedTracePrefixType::ARRAY_UNPACKED, 0, 15);
    for (int i = 0; i < 16; ++i) {
        VL_TRACE_DECL_BUS_ARRAY(tracep,c+0+i*1,fidx,"",-1, direction, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, (i + 0), 31,0);
    }
    VL_TRACE_POP_PREFIX(tracep);
}

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_init_dtype_sub____1(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd* tracep, const char* name, uint32_t fidx, uint32_t c, VerilatedTraceSigDirection direction);

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_init_dtype____1(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd* tracep, const char* name, uint32_t fidx, uint32_t c, VerilatedTraceSigDirection direction) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root__trace_init_dtype____1\n"); );
    Vtb_pipe_lane_mapper__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    Vtb_pipe_lane_mapper___024root__trace_init_dtype_sub____1(vlSelf, tracep, name, fidx, c, direction);
}

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_init_dtype_sub____1(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd* tracep, const char* name, uint32_t fidx, uint32_t c, VerilatedTraceSigDirection direction) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root__trace_init_dtype_sub____1\n"); );
    Vtb_pipe_lane_mapper__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    VL_TRACE_PUSH_PREFIX(tracep, name, VerilatedTracePrefixType::ARRAY_UNPACKED, 0, 3);
    for (int i = 0; i < 4; ++i) {
        VL_TRACE_DECL_BUS_ARRAY(tracep,c+0+i*1,fidx,"",-1, direction, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, (i + 0), 31,0);
    }
    VL_TRACE_POP_PREFIX(tracep);
}

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_init_dtype_sub____2(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd* tracep, const char* name, uint32_t fidx, uint32_t c, VerilatedTraceSigDirection direction);

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_init_dtype____2(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd* tracep, const char* name, uint32_t fidx, uint32_t c, VerilatedTraceSigDirection direction) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root__trace_init_dtype____2\n"); );
    Vtb_pipe_lane_mapper__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    Vtb_pipe_lane_mapper___024root__trace_init_dtype_sub____2(vlSelf, tracep, name, fidx, c, direction);
}

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_init_dtype_sub____2(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd* tracep, const char* name, uint32_t fidx, uint32_t c, VerilatedTraceSigDirection direction) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root__trace_init_dtype_sub____2\n"); );
    Vtb_pipe_lane_mapper__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    VL_TRACE_PUSH_PREFIX(tracep, name, VerilatedTracePrefixType::ARRAY_UNPACKED, 0, 3);
    for (int i = 0; i < 4; ++i) {
        VL_TRACE_DECL_BUS_ARRAY(tracep,c+0+i*1,fidx,"",-1, direction, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, (i + 0), 31,0);
    }
    VL_TRACE_POP_PREFIX(tracep);
}

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_init_dtype_sub____3(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd* tracep, const char* name, uint32_t fidx, uint32_t c, VerilatedTraceSigDirection direction);

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_init_dtype____3(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd* tracep, const char* name, uint32_t fidx, uint32_t c, VerilatedTraceSigDirection direction) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root__trace_init_dtype____3\n"); );
    Vtb_pipe_lane_mapper__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    Vtb_pipe_lane_mapper___024root__trace_init_dtype_sub____3(vlSelf, tracep, name, fidx, c, direction);
}

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_init_dtype_sub____3(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd* tracep, const char* name, uint32_t fidx, uint32_t c, VerilatedTraceSigDirection direction) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root__trace_init_dtype_sub____3\n"); );
    Vtb_pipe_lane_mapper__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    VL_TRACE_PUSH_PREFIX(tracep, name, VerilatedTracePrefixType::ARRAY_UNPACKED, 0, 3);
    for (int i = 0; i < 4; ++i) {
        VL_TRACE_DECL_BUS_ARRAY(tracep,c+0+i*1,fidx,"",-1, direction, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::INT, (i + 0), 31,0);
    }
    VL_TRACE_POP_PREFIX(tracep);
}

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_init_sub__TOP__pipe_pkg__0(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd* tracep) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root__trace_init_sub__TOP__pipe_pkg__0\n"); );
    Vtb_pipe_lane_mapper__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    const int c = vlSymsp->__Vm_baseCode;
    VL_TRACE_DECL_WIDE(tracep,c+1068,0,"SAFE_M2P",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 95,0);
    VL_TRACE_DECL_WIDE(tracep,c+1071,0,"SAFE_P2M",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, 99,0);
}

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_init_top(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd* tracep) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root__trace_init_top\n"); );
    Vtb_pipe_lane_mapper__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    Vtb_pipe_lane_mapper___024root__trace_init_sub__TOP__0(vlSelf, tracep);
}

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_const_0(void* voidSelf, VerilatedVcd::Buffer* bufp);
VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_full_0(void* voidSelf, VerilatedVcd::Buffer* bufp);
void Vtb_pipe_lane_mapper___024root__trace_chg_0(void* voidSelf, VerilatedVcd::Buffer* bufp);
void Vtb_pipe_lane_mapper___024root__trace_cleanup(void* voidSelf, VerilatedVcd* /*unused*/);

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_register(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd* tracep) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root__trace_register\n"); );
    Vtb_pipe_lane_mapper__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    tracep->addConstCb(&Vtb_pipe_lane_mapper___024root__trace_const_0, 0, vlSelf);
    tracep->addFullCb(&Vtb_pipe_lane_mapper___024root__trace_full_0, 0, vlSelf);
    tracep->addChgCb(&Vtb_pipe_lane_mapper___024root__trace_chg_0, 0, vlSelf);
    tracep->addCleanupCb(&Vtb_pipe_lane_mapper___024root__trace_cleanup, vlSelf);
}

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_const_0_sub_0(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd::Buffer* bufp);

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_const_0(void* voidSelf, VerilatedVcd::Buffer* bufp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root__trace_const_0\n"); );
    // Body
    Vtb_pipe_lane_mapper___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtb_pipe_lane_mapper___024root*>(voidSelf);
    Vtb_pipe_lane_mapper__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    Vtb_pipe_lane_mapper___024root__trace_const_0_sub_0((&vlSymsp->TOP), bufp);
}

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_const_dtype____0(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd::Buffer* bufp, uint32_t offset, const VlUnpacked<IData/*31:0*/, 16>& __VdtypeVar);
extern const VlWide<50>/*1599:0*/ Vtb_pipe_lane_mapper__ConstPool__CONST_h3578e490_0;
extern const VlWide<48>/*1535:0*/ Vtb_pipe_lane_mapper__ConstPool__CONST_he7f146c0_0;
extern const VlWide<12>/*383:0*/ Vtb_pipe_lane_mapper__ConstPool__CONST_h8ce6f391_0;
extern const VlWide<24>/*767:0*/ Vtb_pipe_lane_mapper__ConstPool__CONST_h139a1b6e_0;
extern const VlWide<12>/*383:0*/ Vtb_pipe_lane_mapper__ConstPool__CONST_hd75dab91_0;
VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_const_dtype____1(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd::Buffer* bufp, uint32_t offset, const VlUnpacked<IData/*31:0*/, 4>& __VdtypeVar);
VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_const_dtype____2(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd::Buffer* bufp, uint32_t offset, const VlUnpacked<IData/*31:0*/, 4>& __VdtypeVar);
VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_const_dtype____3(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd::Buffer* bufp, uint32_t offset, const VlUnpacked<IData/*31:0*/, 4>& __VdtypeVar);
extern const VlWide<9>/*287:0*/ Vtb_pipe_lane_mapper__ConstPool__CONST_h60bc3080_0;
extern const VlWide<9>/*287:0*/ Vtb_pipe_lane_mapper__ConstPool__CONST_h85fef1e4_0;
extern const VlWide<9>/*287:0*/ Vtb_pipe_lane_mapper__ConstPool__CONST_h9e491bf0_0;
extern const VlWide<9>/*287:0*/ Vtb_pipe_lane_mapper__ConstPool__CONST_h575c62a6_0;
extern const VlWide<10>/*319:0*/ Vtb_pipe_lane_mapper__ConstPool__CONST_hf21946c8_0;
extern const VlWide<10>/*319:0*/ Vtb_pipe_lane_mapper__ConstPool__CONST_hd03174da_0;
extern const VlWide<10>/*319:0*/ Vtb_pipe_lane_mapper__ConstPool__CONST_h3eeda4a3_0;
extern const VlWide<10>/*319:0*/ Vtb_pipe_lane_mapper__ConstPool__CONST_ha44718a6_0;
extern const VlWide<10>/*319:0*/ Vtb_pipe_lane_mapper__ConstPool__CONST_h902d76cc_0;
extern const VlWide<10>/*319:0*/ Vtb_pipe_lane_mapper__ConstPool__CONST_h550ae1e3_0;
extern const VlWide<10>/*319:0*/ Vtb_pipe_lane_mapper__ConstPool__CONST_h512ebaca_0;
extern const VlWide<10>/*319:0*/ Vtb_pipe_lane_mapper__ConstPool__CONST_h2ef9b4cc_0;
extern const VlWide<10>/*319:0*/ Vtb_pipe_lane_mapper__ConstPool__CONST_h0ec89f90_0;
extern const VlWide<10>/*319:0*/ Vtb_pipe_lane_mapper__ConstPool__CONST_h0ecdcfd0_0;
extern const VlWide<10>/*319:0*/ Vtb_pipe_lane_mapper__ConstPool__CONST_h0ed02210_0;
extern const VlWide<10>/*319:0*/ Vtb_pipe_lane_mapper__ConstPool__CONST_h0eb9e450_0;

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_const_0_sub_0(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd::Buffer* bufp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root__trace_const_0_sub_0\n"); );
    Vtb_pipe_lane_mapper__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    VlWide<3>/*95:0*/ __Vtemp_1;
    VlWide<6>/*191:0*/ __Vtemp_2;
    VlWide<6>/*191:0*/ __Vtemp_3;
    VlWide<6>/*191:0*/ __Vtemp_4;
    VlWide<6>/*191:0*/ __Vtemp_5;
    VlWide<6>/*191:0*/ __Vtemp_6;
    VlWide<6>/*191:0*/ __Vtemp_7;
    VlWide<6>/*191:0*/ __Vtemp_8;
    VlWide<6>/*191:0*/ __Vtemp_9;
    VlWide<4>/*127:0*/ __Vtemp_10;
    VlWide<7>/*223:0*/ __Vtemp_11;
    VlWide<7>/*223:0*/ __Vtemp_12;
    VlWide<7>/*223:0*/ __Vtemp_13;
    VlWide<7>/*223:0*/ __Vtemp_14;
    VlWide<7>/*223:0*/ __Vtemp_15;
    VlWide<7>/*223:0*/ __Vtemp_16;
    VlWide<7>/*223:0*/ __Vtemp_17;
    VlWide<7>/*223:0*/ __Vtemp_18;
    VlWide<7>/*223:0*/ __Vtemp_19;
    VlWide<7>/*223:0*/ __Vtemp_20;
    VlWide<7>/*223:0*/ __Vtemp_21;
    VlWide<7>/*223:0*/ __Vtemp_22;
    VlWide<7>/*223:0*/ __Vtemp_23;
    VlWide<7>/*223:0*/ __Vtemp_24;
    VlWide<7>/*223:0*/ __Vtemp_25;
    VlWide<7>/*223:0*/ __Vtemp_26;
    VlWide<3>/*95:0*/ __Vtemp_27;
    VlWide<4>/*127:0*/ __Vtemp_28;
    // Body
    uint32_t* const oldp VL_ATTR_UNUSED = bufp->oldp(vlSymsp->__Vm_baseCode);
    bufp->fullIData(oldp+554,(4U),32);
    bufp->fullIData(oldp+555,(0x00000010U),32);
    Vtb_pipe_lane_mapper___024root__trace_const_dtype____0(vlSelf, bufp, 556, vlSelfRef.tb_pipe_lane_mapper__DOT__PERIOD_NS);
    bufp->fullBit(oldp+572,(0U));
    bufp->fullWData(oldp+573,(Vtb_pipe_lane_mapper__ConstPool__CONST_h3578e490_0),1600);
    bufp->fullWData(oldp+623,(Vtb_pipe_lane_mapper__ConstPool__CONST_he7f146c0_0),1536);
    bufp->fullWData(oldp+671,(Vtb_pipe_lane_mapper__ConstPool__CONST_h8ce6f391_0),384);
    bufp->fullWData(oldp+683,(Vtb_pipe_lane_mapper__ConstPool__CONST_h139a1b6e_0),768);
    bufp->fullWData(oldp+707,(Vtb_pipe_lane_mapper__ConstPool__CONST_hd75dab91_0),384);
    Vtb_pipe_lane_mapper___024root__trace_const_dtype____1(vlSelf, bufp, 719, vlSelfRef.tb_pipe_lane_mapper__DOT__G1_LANES);
    Vtb_pipe_lane_mapper___024root__trace_const_dtype____2(vlSelf, bufp, 723, vlSelfRef.tb_pipe_lane_mapper__DOT__G2_LANES);
    Vtb_pipe_lane_mapper___024root__trace_const_dtype____3(vlSelf, bufp, 727, vlSelfRef.tb_pipe_lane_mapper__DOT__G3_LANES);
    bufp->fullDouble(oldp+731,(300.0));
    bufp->fullIData(oldp+733,(2U),32);
    bufp->fullBit(oldp+734,(1U));
    bufp->fullCData(oldp+735,(2U),2);
    bufp->fullIData(oldp+736,(1U),32);
    bufp->fullCData(oldp+737,(1U),2);
    bufp->fullIData(oldp+738,(3U),32);
    bufp->fullCData(oldp+739,(6U),3);
    bufp->fullCData(oldp+740,(5U),3);
    bufp->fullCData(oldp+741,(3U),3);
    bufp->fullIData(oldp+742,(0x00000060U),32);
    __Vtemp_1[0U] = 0U;
    __Vtemp_1[1U] = 0x00400002U;
    __Vtemp_1[2U] = 0U;
    bufp->fullWData(oldp+743,(__Vtemp_1),96);
    __Vtemp_2[0U] = 0U;
    __Vtemp_2[1U] = 0xa8000000U;
    __Vtemp_2[2U] = 0x0000000aU;
    __Vtemp_2[3U] = 0U;
    __Vtemp_2[4U] = 0x28000000U;
    __Vtemp_2[5U] = 0x20000002U;
    bufp->fullWData(oldp+746,(__Vtemp_2),192);
    __Vtemp_3[0U] = 0U;
    __Vtemp_3[1U] = 0xb8000000U;
    __Vtemp_3[2U] = 0x0000000bU;
    __Vtemp_3[3U] = 0U;
    __Vtemp_3[4U] = 0x38000000U;
    __Vtemp_3[5U] = 0x20000003U;
    bufp->fullWData(oldp+752,(__Vtemp_3),192);
    bufp->fullWData(oldp+758,(Vtb_pipe_lane_mapper__ConstPool__CONST_h60bc3080_0),288);
    bufp->fullWData(oldp+767,(Vtb_pipe_lane_mapper__ConstPool__CONST_h85fef1e4_0),288);
    bufp->fullWData(oldp+776,(Vtb_pipe_lane_mapper__ConstPool__CONST_h9e491bf0_0),288);
    bufp->fullWData(oldp+785,(Vtb_pipe_lane_mapper__ConstPool__CONST_h575c62a6_0),288);
    __Vtemp_4[0U] = 0U;
    __Vtemp_4[1U] = 0x48000000U;
    __Vtemp_4[2U] = 4U;
    __Vtemp_4[3U] = 0U;
    __Vtemp_4[4U] = 0x08000000U;
    __Vtemp_4[5U] = 0x10000000U;
    bufp->fullWData(oldp+794,(__Vtemp_4),192);
    __Vtemp_5[0U] = 0U;
    __Vtemp_5[1U] = 0x58000000U;
    __Vtemp_5[2U] = 5U;
    __Vtemp_5[3U] = 0U;
    __Vtemp_5[4U] = 0x18000000U;
    __Vtemp_5[5U] = 0x10000001U;
    bufp->fullWData(oldp+800,(__Vtemp_5),192);
    __Vtemp_6[0U] = 0U;
    __Vtemp_6[1U] = 0x68000000U;
    __Vtemp_6[2U] = 6U;
    __Vtemp_6[3U] = 0U;
    __Vtemp_6[4U] = 0x28000000U;
    __Vtemp_6[5U] = 0x10000002U;
    bufp->fullWData(oldp+806,(__Vtemp_6),192);
    __Vtemp_7[0U] = 0U;
    __Vtemp_7[1U] = 0x78000000U;
    __Vtemp_7[2U] = 7U;
    __Vtemp_7[3U] = 0U;
    __Vtemp_7[4U] = 0x38000000U;
    __Vtemp_7[5U] = 0x10000003U;
    bufp->fullWData(oldp+812,(__Vtemp_7),192);
    __Vtemp_8[0U] = 0U;
    __Vtemp_8[1U] = 0x88000000U;
    __Vtemp_8[2U] = 8U;
    __Vtemp_8[3U] = 0U;
    __Vtemp_8[4U] = 0x08000000U;
    __Vtemp_8[5U] = 0x20000000U;
    bufp->fullWData(oldp+818,(__Vtemp_8),192);
    __Vtemp_9[0U] = 0U;
    __Vtemp_9[1U] = 0x98000000U;
    __Vtemp_9[2U] = 9U;
    __Vtemp_9[3U] = 0U;
    __Vtemp_9[4U] = 0x18000000U;
    __Vtemp_9[5U] = 0x20000001U;
    bufp->fullWData(oldp+824,(__Vtemp_9),192);
    bufp->fullIData(oldp+830,(0x00000064U),32);
    __Vtemp_10[0U] = 0U;
    __Vtemp_10[1U] = 0x00c00000U;
    __Vtemp_10[2U] = 0U;
    __Vtemp_10[3U] = 0U;
    bufp->fullWData(oldp+831,(__Vtemp_10),100);
    __Vtemp_11[0U] = 0U;
    __Vtemp_11[1U] = 0x80000000U;
    __Vtemp_11[2U] = 0x500000aaU;
    __Vtemp_11[3U] = 0x0000000aU;
    __Vtemp_11[4U] = 0x0c000000U;
    __Vtemp_11[5U] = 0U;
    __Vtemp_11[6U] = 0U;
    bufp->fullWData(oldp+835,(__Vtemp_11),200);
    __Vtemp_12[0U] = 0U;
    __Vtemp_12[1U] = 0x80000000U;
    __Vtemp_12[2U] = 0x500000bbU;
    __Vtemp_12[3U] = 0x0000000aU;
    __Vtemp_12[4U] = 0x0c000000U;
    __Vtemp_12[5U] = 0U;
    __Vtemp_12[6U] = 0U;
    bufp->fullWData(oldp+842,(__Vtemp_12),200);
    bufp->fullWData(oldp+849,(Vtb_pipe_lane_mapper__ConstPool__CONST_hf21946c8_0),300);
    bufp->fullWData(oldp+859,(Vtb_pipe_lane_mapper__ConstPool__CONST_hd03174da_0),300);
    bufp->fullWData(oldp+869,(Vtb_pipe_lane_mapper__ConstPool__CONST_h3eeda4a3_0),300);
    bufp->fullWData(oldp+879,(Vtb_pipe_lane_mapper__ConstPool__CONST_ha44718a6_0),300);
    __Vtemp_13[0U] = 0U;
    __Vtemp_13[1U] = 0x80000000U;
    __Vtemp_13[2U] = 0x50000044U;
    __Vtemp_13[3U] = 0x0000000aU;
    __Vtemp_13[4U] = 0x0c000000U;
    __Vtemp_13[5U] = 0U;
    __Vtemp_13[6U] = 0U;
    bufp->fullWData(oldp+889,(__Vtemp_13),200);
    __Vtemp_14[0U] = 0U;
    __Vtemp_14[1U] = 0x80000000U;
    __Vtemp_14[2U] = 0x50000055U;
    __Vtemp_14[3U] = 0x0000000aU;
    __Vtemp_14[4U] = 0x0c000000U;
    __Vtemp_14[5U] = 0U;
    __Vtemp_14[6U] = 0U;
    bufp->fullWData(oldp+896,(__Vtemp_14),200);
    __Vtemp_15[0U] = 0U;
    __Vtemp_15[1U] = 0x80000000U;
    __Vtemp_15[2U] = 0x50000066U;
    __Vtemp_15[3U] = 0x0000000aU;
    __Vtemp_15[4U] = 0x0c000000U;
    __Vtemp_15[5U] = 0U;
    __Vtemp_15[6U] = 0U;
    bufp->fullWData(oldp+903,(__Vtemp_15),200);
    __Vtemp_16[0U] = 0U;
    __Vtemp_16[1U] = 0x80000000U;
    __Vtemp_16[2U] = 0x50000077U;
    __Vtemp_16[3U] = 0x0000000aU;
    __Vtemp_16[4U] = 0x0c000000U;
    __Vtemp_16[5U] = 0U;
    __Vtemp_16[6U] = 0U;
    bufp->fullWData(oldp+910,(__Vtemp_16),200);
    __Vtemp_17[0U] = 0U;
    __Vtemp_17[1U] = 0x80000000U;
    __Vtemp_17[2U] = 0x50000088U;
    __Vtemp_17[3U] = 0x0000000aU;
    __Vtemp_17[4U] = 0x0c000000U;
    __Vtemp_17[5U] = 0U;
    __Vtemp_17[6U] = 0U;
    bufp->fullWData(oldp+917,(__Vtemp_17),200);
    __Vtemp_18[0U] = 0U;
    __Vtemp_18[1U] = 0x80000000U;
    __Vtemp_18[2U] = 0x50000099U;
    __Vtemp_18[3U] = 0x0000000aU;
    __Vtemp_18[4U] = 0x0c000000U;
    __Vtemp_18[5U] = 0U;
    __Vtemp_18[6U] = 0U;
    bufp->fullWData(oldp+924,(__Vtemp_18),200);
    __Vtemp_19[0U] = 0U;
    __Vtemp_19[1U] = 0x00c00000U;
    __Vtemp_19[2U] = 0U;
    __Vtemp_19[3U] = 0U;
    __Vtemp_19[4U] = 0U;
    __Vtemp_19[5U] = 0x00000448U;
    __Vtemp_19[6U] = 0x000000a5U;
    bufp->fullWData(oldp+931,(__Vtemp_19),200);
    __Vtemp_20[0U] = 0U;
    __Vtemp_20[1U] = 0x00c00000U;
    __Vtemp_20[2U] = 0U;
    __Vtemp_20[3U] = 0U;
    __Vtemp_20[4U] = 0U;
    __Vtemp_20[5U] = 0x00000558U;
    __Vtemp_20[6U] = 0x000000a5U;
    bufp->fullWData(oldp+938,(__Vtemp_20),200);
    __Vtemp_21[0U] = 0U;
    __Vtemp_21[1U] = 0x00c00000U;
    __Vtemp_21[2U] = 0U;
    __Vtemp_21[3U] = 0U;
    __Vtemp_21[4U] = 0U;
    __Vtemp_21[5U] = 0x00000668U;
    __Vtemp_21[6U] = 0x000000a5U;
    bufp->fullWData(oldp+945,(__Vtemp_21),200);
    __Vtemp_22[0U] = 0U;
    __Vtemp_22[1U] = 0x00c00000U;
    __Vtemp_22[2U] = 0U;
    __Vtemp_22[3U] = 0U;
    __Vtemp_22[4U] = 0U;
    __Vtemp_22[5U] = 0x00000778U;
    __Vtemp_22[6U] = 0x000000a5U;
    bufp->fullWData(oldp+952,(__Vtemp_22),200);
    __Vtemp_23[0U] = 0U;
    __Vtemp_23[1U] = 0x00c00000U;
    __Vtemp_23[2U] = 0U;
    __Vtemp_23[3U] = 0U;
    __Vtemp_23[4U] = 0U;
    __Vtemp_23[5U] = 0x00000888U;
    __Vtemp_23[6U] = 0x000000a5U;
    bufp->fullWData(oldp+959,(__Vtemp_23),200);
    __Vtemp_24[0U] = 0U;
    __Vtemp_24[1U] = 0x00c00000U;
    __Vtemp_24[2U] = 0U;
    __Vtemp_24[3U] = 0U;
    __Vtemp_24[4U] = 0U;
    __Vtemp_24[5U] = 0x00000998U;
    __Vtemp_24[6U] = 0x000000a5U;
    bufp->fullWData(oldp+966,(__Vtemp_24),200);
    __Vtemp_25[0U] = 0U;
    __Vtemp_25[1U] = 0x00c00000U;
    __Vtemp_25[2U] = 0U;
    __Vtemp_25[3U] = 0U;
    __Vtemp_25[4U] = 0U;
    __Vtemp_25[5U] = 0x00000aa8U;
    __Vtemp_25[6U] = 0x000000a5U;
    bufp->fullWData(oldp+973,(__Vtemp_25),200);
    __Vtemp_26[0U] = 0U;
    __Vtemp_26[1U] = 0x00c00000U;
    __Vtemp_26[2U] = 0U;
    __Vtemp_26[3U] = 0U;
    __Vtemp_26[4U] = 0U;
    __Vtemp_26[5U] = 0x00000bb8U;
    __Vtemp_26[6U] = 0x000000a5U;
    bufp->fullWData(oldp+980,(__Vtemp_26),200);
    bufp->fullWData(oldp+987,(Vtb_pipe_lane_mapper__ConstPool__CONST_h902d76cc_0),300);
    bufp->fullWData(oldp+997,(Vtb_pipe_lane_mapper__ConstPool__CONST_h550ae1e3_0),300);
    bufp->fullWData(oldp+1007,(Vtb_pipe_lane_mapper__ConstPool__CONST_h512ebaca_0),300);
    bufp->fullWData(oldp+1017,(Vtb_pipe_lane_mapper__ConstPool__CONST_h2ef9b4cc_0),300);
    bufp->fullWData(oldp+1027,(Vtb_pipe_lane_mapper__ConstPool__CONST_h0ec89f90_0),300);
    bufp->fullWData(oldp+1037,(Vtb_pipe_lane_mapper__ConstPool__CONST_h0ecdcfd0_0),300);
    bufp->fullWData(oldp+1047,(Vtb_pipe_lane_mapper__ConstPool__CONST_h0ed02210_0),300);
    bufp->fullWData(oldp+1057,(Vtb_pipe_lane_mapper__ConstPool__CONST_h0eb9e450_0),300);
    bufp->fullBit(oldp+1067,(0U));
    __Vtemp_27[0U] = 0U;
    __Vtemp_27[1U] = 0x00400002U;
    __Vtemp_27[2U] = 0U;
    bufp->fullWData(oldp+1068,(__Vtemp_27),96);
    __Vtemp_28[0U] = 0U;
    __Vtemp_28[1U] = 0x00c00000U;
    __Vtemp_28[2U] = 0U;
    __Vtemp_28[3U] = 0U;
    bufp->fullWData(oldp+1071,(__Vtemp_28),100);
}

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_const_dtype____0(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd::Buffer* bufp, uint32_t offset, const VlUnpacked<IData/*31:0*/, 16>& __VdtypeVar) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root__trace_const_dtype____0\n"); );
    Vtb_pipe_lane_mapper__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    uint32_t* const oldp VL_ATTR_UNUSED = bufp->oldp(vlSymsp->__Vm_baseCode + offset);
    bufp->fullIData(oldp+0,(__VdtypeVar[0]),32);
    bufp->fullIData(oldp+1,(__VdtypeVar[1]),32);
    bufp->fullIData(oldp+2,(__VdtypeVar[2]),32);
    bufp->fullIData(oldp+3,(__VdtypeVar[3]),32);
    bufp->fullIData(oldp+4,(__VdtypeVar[4]),32);
    bufp->fullIData(oldp+5,(__VdtypeVar[5]),32);
    bufp->fullIData(oldp+6,(__VdtypeVar[6]),32);
    bufp->fullIData(oldp+7,(__VdtypeVar[7]),32);
    bufp->fullIData(oldp+8,(__VdtypeVar[8]),32);
    bufp->fullIData(oldp+9,(__VdtypeVar[9]),32);
    bufp->fullIData(oldp+10,(__VdtypeVar[10]),32);
    bufp->fullIData(oldp+11,(__VdtypeVar[11]),32);
    bufp->fullIData(oldp+12,(__VdtypeVar[12]),32);
    bufp->fullIData(oldp+13,(__VdtypeVar[13]),32);
    bufp->fullIData(oldp+14,(__VdtypeVar[14]),32);
    bufp->fullIData(oldp+15,(__VdtypeVar[15]),32);
}

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_const_dtype____1(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd::Buffer* bufp, uint32_t offset, const VlUnpacked<IData/*31:0*/, 4>& __VdtypeVar) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root__trace_const_dtype____1\n"); );
    Vtb_pipe_lane_mapper__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    uint32_t* const oldp VL_ATTR_UNUSED = bufp->oldp(vlSymsp->__Vm_baseCode + offset);
    bufp->fullIData(oldp+0,(__VdtypeVar[0]),32);
    bufp->fullIData(oldp+1,(__VdtypeVar[1]),32);
    bufp->fullIData(oldp+2,(__VdtypeVar[2]),32);
    bufp->fullIData(oldp+3,(__VdtypeVar[3]),32);
}

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_const_dtype____2(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd::Buffer* bufp, uint32_t offset, const VlUnpacked<IData/*31:0*/, 4>& __VdtypeVar) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root__trace_const_dtype____2\n"); );
    Vtb_pipe_lane_mapper__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    uint32_t* const oldp VL_ATTR_UNUSED = bufp->oldp(vlSymsp->__Vm_baseCode + offset);
    bufp->fullIData(oldp+0,(__VdtypeVar[0]),32);
    bufp->fullIData(oldp+1,(__VdtypeVar[1]),32);
    bufp->fullIData(oldp+2,(__VdtypeVar[2]),32);
    bufp->fullIData(oldp+3,(__VdtypeVar[3]),32);
}

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_const_dtype____3(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd::Buffer* bufp, uint32_t offset, const VlUnpacked<IData/*31:0*/, 4>& __VdtypeVar) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root__trace_const_dtype____3\n"); );
    Vtb_pipe_lane_mapper__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    uint32_t* const oldp VL_ATTR_UNUSED = bufp->oldp(vlSymsp->__Vm_baseCode + offset);
    bufp->fullIData(oldp+0,(__VdtypeVar[0]),32);
    bufp->fullIData(oldp+1,(__VdtypeVar[1]),32);
    bufp->fullIData(oldp+2,(__VdtypeVar[2]),32);
    bufp->fullIData(oldp+3,(__VdtypeVar[3]),32);
}

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_full_0_sub_0(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd::Buffer* bufp);

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_full_0(void* voidSelf, VerilatedVcd::Buffer* bufp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root__trace_full_0\n"); );
    // Body
    Vtb_pipe_lane_mapper___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtb_pipe_lane_mapper___024root*>(voidSelf);
    Vtb_pipe_lane_mapper__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    Vtb_pipe_lane_mapper___024root__trace_full_0_sub_0((&vlSymsp->TOP), bufp);
}

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root__trace_full_0_sub_0(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd::Buffer* bufp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root__trace_full_0_sub_0\n"); );
    Vtb_pipe_lane_mapper__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    VlWide<13>/*415:0*/ __Vtemp_23;
    VlWide<4>/*127:0*/ __Vtemp_28;
    VlWide<4>/*127:0*/ __Vtemp_31;
    VlWide<4>/*127:0*/ __Vtemp_36;
    VlWide<4>/*127:0*/ __Vtemp_39;
    VlWide<4>/*127:0*/ __Vtemp_44;
    VlWide<4>/*127:0*/ __Vtemp_47;
    VlWide<4>/*127:0*/ __Vtemp_52;
    VlWide<4>/*127:0*/ __Vtemp_55;
    VlWide<3>/*95:0*/ __Vtemp_65;
    VlWide<3>/*95:0*/ __Vtemp_73;
    VlWide<3>/*95:0*/ __Vtemp_83;
    VlWide<3>/*95:0*/ __Vtemp_91;
    VlWide<3>/*95:0*/ __Vtemp_101;
    VlWide<3>/*95:0*/ __Vtemp_109;
    VlWide<3>/*95:0*/ __Vtemp_119;
    VlWide<3>/*95:0*/ __Vtemp_127;
    VlWide<25>/*799:0*/ __Vtemp_174;
    VlWide<4>/*127:0*/ __Vtemp_179;
    VlWide<4>/*127:0*/ __Vtemp_182;
    VlWide<4>/*127:0*/ __Vtemp_187;
    VlWide<4>/*127:0*/ __Vtemp_190;
    VlWide<4>/*127:0*/ __Vtemp_195;
    VlWide<4>/*127:0*/ __Vtemp_198;
    VlWide<4>/*127:0*/ __Vtemp_203;
    VlWide<4>/*127:0*/ __Vtemp_206;
    VlWide<4>/*127:0*/ __Vtemp_211;
    VlWide<4>/*127:0*/ __Vtemp_214;
    VlWide<4>/*127:0*/ __Vtemp_219;
    VlWide<4>/*127:0*/ __Vtemp_222;
    VlWide<4>/*127:0*/ __Vtemp_227;
    VlWide<4>/*127:0*/ __Vtemp_230;
    VlWide<4>/*127:0*/ __Vtemp_235;
    VlWide<4>/*127:0*/ __Vtemp_238;
    VlWide<3>/*95:0*/ __Vtemp_245;
    VlWide<3>/*95:0*/ __Vtemp_250;
    VlWide<3>/*95:0*/ __Vtemp_257;
    VlWide<3>/*95:0*/ __Vtemp_262;
    VlWide<3>/*95:0*/ __Vtemp_269;
    VlWide<3>/*95:0*/ __Vtemp_274;
    VlWide<3>/*95:0*/ __Vtemp_281;
    VlWide<3>/*95:0*/ __Vtemp_286;
    VlWide<25>/*799:0*/ __Vtemp_333;
    VlWide<50>/*1599:0*/ __Vtemp_358;
    VlWide<4>/*127:0*/ __Vtemp_363;
    VlWide<4>/*127:0*/ __Vtemp_366;
    VlWide<4>/*127:0*/ __Vtemp_371;
    VlWide<4>/*127:0*/ __Vtemp_374;
    VlWide<4>/*127:0*/ __Vtemp_379;
    VlWide<4>/*127:0*/ __Vtemp_382;
    VlWide<4>/*127:0*/ __Vtemp_387;
    VlWide<4>/*127:0*/ __Vtemp_390;
    VlWide<4>/*127:0*/ __Vtemp_395;
    VlWide<4>/*127:0*/ __Vtemp_398;
    VlWide<4>/*127:0*/ __Vtemp_403;
    VlWide<4>/*127:0*/ __Vtemp_406;
    VlWide<4>/*127:0*/ __Vtemp_411;
    VlWide<4>/*127:0*/ __Vtemp_414;
    VlWide<4>/*127:0*/ __Vtemp_419;
    VlWide<4>/*127:0*/ __Vtemp_422;
    VlWide<4>/*127:0*/ __Vtemp_427;
    VlWide<4>/*127:0*/ __Vtemp_430;
    VlWide<4>/*127:0*/ __Vtemp_435;
    VlWide<4>/*127:0*/ __Vtemp_438;
    VlWide<4>/*127:0*/ __Vtemp_443;
    VlWide<4>/*127:0*/ __Vtemp_446;
    VlWide<4>/*127:0*/ __Vtemp_451;
    VlWide<4>/*127:0*/ __Vtemp_454;
    VlWide<3>/*95:0*/ __Vtemp_461;
    VlWide<3>/*95:0*/ __Vtemp_466;
    VlWide<3>/*95:0*/ __Vtemp_473;
    VlWide<3>/*95:0*/ __Vtemp_478;
    VlWide<3>/*95:0*/ __Vtemp_485;
    VlWide<3>/*95:0*/ __Vtemp_490;
    VlWide<3>/*95:0*/ __Vtemp_497;
    VlWide<3>/*95:0*/ __Vtemp_502;
    VlWide<13>/*415:0*/ __Vtemp_525;
    VlWide<4>/*127:0*/ __Vtemp_530;
    VlWide<4>/*127:0*/ __Vtemp_533;
    VlWide<4>/*127:0*/ __Vtemp_538;
    VlWide<4>/*127:0*/ __Vtemp_541;
    VlWide<4>/*127:0*/ __Vtemp_546;
    VlWide<4>/*127:0*/ __Vtemp_549;
    VlWide<4>/*127:0*/ __Vtemp_554;
    VlWide<4>/*127:0*/ __Vtemp_557;
    // Body
    uint32_t* const oldp VL_ATTR_UNUSED = bufp->oldp(vlSymsp->__Vm_baseCode);
    bufp->fullCData(oldp+0,(vlSelfRef.tb_pipe_lane_mapper__DOT__ctrl_rst_n),4);
    bufp->fullCData(oldp+1,((3U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__ctrl_rst_n))),2);
    bufp->fullBit(oldp+2,((1U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__ctrl_rst_n))));
    bufp->fullBit(oldp+3,((1U & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__ctrl_rst_n) 
                                 >> 1U))));
    bufp->fullBit(oldp+4,((1U & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__ctrl_rst_n) 
                                 >> 2U))));
    bufp->fullBit(oldp+5,((1U & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__ctrl_rst_n) 
                                 >> 3U))));
    bufp->fullCData(oldp+6,((3U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__ctrl_rst_n))),2);
    bufp->fullCData(oldp+7,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__branch_clk),2);
    bufp->fullCData(oldp+8,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__branch_clk),2);
    bufp->fullCData(oldp+9,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__branch_clk),3);
    bufp->fullCData(oldp+10,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_decoder__DOT__sel_tgt),7);
    bufp->fullCData(oldp+11,((3U & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_decoder__DOT__sel_tgt) 
                                    >> 5U))),2);
    bufp->fullCData(oldp+12,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__branch_rst_n),2);
    bufp->fullCData(oldp+13,((3U & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_decoder__DOT__sel_tgt) 
                                    >> 3U))),2);
    bufp->fullCData(oldp+14,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__branch_rst_n),3);
    bufp->fullCData(oldp+15,((7U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_decoder__DOT__sel_tgt))),3);
    bufp->fullCData(oldp+16,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__branch_rst_n),2);
    bufp->fullCData(oldp+17,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__branch_rst_n),3);
    __Vtemp_23[0U] = 0U;
    __Vtemp_23[1U] = (0x00c00000U ^ (0x80c00000U & 
                                     (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q)))));
    __Vtemp_23[2U] = (0x500000ccU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
    __Vtemp_23[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
    __Vtemp_23[4U] = (0x0c000000U ^ (0x0c000000U & 
                                     ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))) 
                                      << 4U)));
    __Vtemp_23[5U] = ((8U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))) 
                             >> 0x0000001cU)) | (0x00000dd0U 
                                                 & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))) 
                                                    << 4U)));
    __Vtemp_23[6U] = ((5U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))) 
                             >> 0x0000001cU)) | (0x000000a0U 
                                                 & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))) 
                                                    << 4U)));
    __Vtemp_23[7U] = (0xc0000000U ^ (0xc0000000U & 
                                     ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))) 
                                      << 8U)));
    __Vtemp_23[8U] = ((0x00000080U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))) 
                                      >> 0x00000018U)) 
                      | (0x0000ee00U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))) 
                                        << 8U)));
    __Vtemp_23[9U] = ((0x00000050U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))) 
                                      >> 0x00000018U)) 
                      | (0x00000a00U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))) 
                                        << 8U)));
    __Vtemp_23[10U] = 0U;
    __Vtemp_23[11U] = ((0x0000000cU ^ (0x0000000cU 
                                       & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))) 
                                          >> 0x00000014U))) 
                       | (((8U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))) 
                                  >> 0x0000001cU)) 
                           | (0x00000ff0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))) 
                                             << 4U))) 
                          << 8U));
    __Vtemp_23[12U] = ((((8U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))) 
                                >> 0x0000001cU)) | 
                         (0x00000ff0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))) 
                                         << 4U))) >> 0x00000018U) 
                       | (((5U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))) 
                                  >> 0x0000001cU)) 
                           | (0x000000a0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))) 
                                             << 4U))) 
                          << 8U));
    bufp->fullWData(oldp+18,(__Vtemp_23),400);
    bufp->fullBit(oldp+31,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q));
    bufp->fullBit(oldp+32,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q));
    bufp->fullBit(oldp+33,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__DOT__meta));
    __Vtemp_28[0U] = 0U;
    __Vtemp_28[1U] = (0x00c00000U ^ (0x80c00000U & 
                                     (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q)))));
    __Vtemp_28[2U] = (0x500000ccU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
    __Vtemp_28[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+34,(__Vtemp_28),100);
    __Vtemp_31[0U] = 0U;
    __Vtemp_31[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
    __Vtemp_31[2U] = (0x500000ccU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
    __Vtemp_31[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+38,(__Vtemp_31),100);
    __Vtemp_36[0U] = 0U;
    __Vtemp_36[1U] = (0x00c00000U ^ (0x80c00000U & 
                                     (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q)))));
    __Vtemp_36[2U] = (0x500000ddU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
    __Vtemp_36[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+42,(__Vtemp_36),100);
    __Vtemp_39[0U] = 0U;
    __Vtemp_39[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
    __Vtemp_39[2U] = (0x500000ddU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
    __Vtemp_39[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+46,(__Vtemp_39),100);
    __Vtemp_44[0U] = 0U;
    __Vtemp_44[1U] = (0x00c00000U ^ (0x80c00000U & 
                                     (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q)))));
    __Vtemp_44[2U] = (0x500000eeU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
    __Vtemp_44[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+50,(__Vtemp_44),100);
    __Vtemp_47[0U] = 0U;
    __Vtemp_47[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
    __Vtemp_47[2U] = (0x500000eeU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
    __Vtemp_47[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+54,(__Vtemp_47),100);
    __Vtemp_52[0U] = 0U;
    __Vtemp_52[1U] = (0x00c00000U ^ (0x80c00000U & 
                                     (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q)))));
    __Vtemp_52[2U] = (0x500000ffU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
    __Vtemp_52[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+58,(__Vtemp_52),100);
    __Vtemp_55[0U] = 0U;
    __Vtemp_55[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
    __Vtemp_55[2U] = (0x500000ffU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
    __Vtemp_55[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+62,(__Vtemp_55),100);
    __Vtemp_65[0U] = 0U;
    __Vtemp_65[1U] = (0x00400002U ^ ((0xc8400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[1U]) 
                                     | ((0x08400002U 
                                         & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[1U]) 
                                        | (0x48400002U 
                                           & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[1U]))));
    __Vtemp_65[2U] = ((0x0000000cU & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[2U]) 
                      | ((0x30000000U & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[2U]) 
                         | (0x20000004U & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[2U])));
    bufp->fullWData(oldp+66,(__Vtemp_65),96);
    __Vtemp_73[0U] = 0U;
    __Vtemp_73[1U] = ((0xc8400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[1U]) 
                      | ((0x08400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[1U]) 
                         | (0x48400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[1U])));
    __Vtemp_73[2U] = ((0x0000000cU & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[2U]) 
                      | ((0x30000000U & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[2U]) 
                         | (0x20000004U & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[2U])));
    bufp->fullWData(oldp+69,(__Vtemp_73),96);
    __Vtemp_83[0U] = 0U;
    __Vtemp_83[1U] = (0x00400002U ^ ((0xd8400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[1U]) 
                                     | ((0x18400002U 
                                         & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[1U]) 
                                        | (0x58400002U 
                                           & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[1U]))));
    __Vtemp_83[2U] = ((0x0000000dU & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[2U]) 
                      | ((0x30000001U & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[2U]) 
                         | (0x20000005U & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[2U])));
    bufp->fullWData(oldp+72,(__Vtemp_83),96);
    __Vtemp_91[0U] = 0U;
    __Vtemp_91[1U] = ((0xd8400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[1U]) 
                      | ((0x18400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[1U]) 
                         | (0x58400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[1U])));
    __Vtemp_91[2U] = ((0x0000000dU & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[2U]) 
                      | ((0x30000001U & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[2U]) 
                         | (0x20000005U & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[2U])));
    bufp->fullWData(oldp+75,(__Vtemp_91),96);
    __Vtemp_101[0U] = 0U;
    __Vtemp_101[1U] = (0x00400002U ^ ((0xe8400002U 
                                       & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[1U]) 
                                      | ((0x28400002U 
                                          & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[1U]) 
                                         | (0x68400002U 
                                            & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[1U]))));
    __Vtemp_101[2U] = ((0x0000000eU & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[2U]) 
                       | ((0x30000002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[2U]) 
                          | (0x20000006U & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[2U])));
    bufp->fullWData(oldp+78,(__Vtemp_101),96);
    __Vtemp_109[0U] = 0U;
    __Vtemp_109[1U] = ((0xe8400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[1U]) 
                       | ((0x28400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[1U]) 
                          | (0x68400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[1U])));
    __Vtemp_109[2U] = ((0x0000000eU & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[2U]) 
                       | ((0x30000002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[2U]) 
                          | (0x20000006U & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[2U])));
    bufp->fullWData(oldp+81,(__Vtemp_109),96);
    __Vtemp_119[0U] = 0U;
    __Vtemp_119[1U] = (0x00400002U ^ ((0xf8400002U 
                                       & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[1U]) 
                                      | ((0x78400002U 
                                          & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[1U]) 
                                         | (0x38400002U 
                                            & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[1U]))));
    __Vtemp_119[2U] = ((0x0000000fU & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[2U]) 
                       | ((0x20000007U & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[2U]) 
                          | (0x30000003U & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[2U])));
    bufp->fullWData(oldp+84,(__Vtemp_119),96);
    __Vtemp_127[0U] = 0U;
    __Vtemp_127[1U] = ((0xf8400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[1U]) 
                       | ((0x78400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[1U]) 
                          | (0x38400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[1U])));
    __Vtemp_127[2U] = ((0x0000000fU & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[2U]) 
                       | ((0x20000007U & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[2U]) 
                          | (0x30000003U & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[2U])));
    bufp->fullWData(oldp+87,(__Vtemp_127),96);
    __Vtemp_174[0U] = 0U;
    __Vtemp_174[1U] = (0x00c00000U ^ (0x80c00000U & 
                                      (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)))));
    __Vtemp_174[2U] = (0x50000088U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_174[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_174[4U] = (0x0c000000U ^ (0x0c000000U & 
                                      ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                       << 4U)));
    __Vtemp_174[5U] = ((8U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                              >> 0x0000001cU)) | (0x00000990U 
                                                  & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                                     << 4U)));
    __Vtemp_174[6U] = ((5U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                              >> 0x0000001cU)) | (0x000000a0U 
                                                  & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                                     << 4U)));
    __Vtemp_174[7U] = (0xc0000000U ^ (0xc0000000U & 
                                      ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                       << 8U)));
    __Vtemp_174[8U] = ((0x00000080U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                       >> 0x00000018U)) 
                       | (0x0000aa00U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                         << 8U)));
    __Vtemp_174[9U] = ((0x00000050U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                       >> 0x00000018U)) 
                       | (0x00000a00U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                         << 8U)));
    __Vtemp_174[10U] = 0U;
    __Vtemp_174[11U] = ((0x0000000cU ^ (0x0000000cU 
                                        & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                           >> 0x00000014U))) 
                        | (((8U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                   >> 0x0000001cU)) 
                            | (0x00000bb0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                              << 4U))) 
                           << 8U));
    __Vtemp_174[12U] = ((((8U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                 >> 0x0000001cU)) | 
                          (0x00000bb0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                          << 4U))) 
                         >> 0x00000018U) | (((5U & 
                                              ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                               >> 0x0000001cU)) 
                                             | (0x000000a0U 
                                                & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                                   << 4U))) 
                                            << 8U));
    __Vtemp_174[13U] = 0U;
    __Vtemp_174[14U] = ((0x000000c0U ^ (0x000080c0U 
                                        & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                           >> 0x00000010U))) 
                        | (0x00cc0000U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                          << 0x00000010U)));
    __Vtemp_174[15U] = ((0x00005000U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                        >> 0x00000010U)) 
                        | (0x000a0000U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                          << 0x00000010U)));
    __Vtemp_174[16U] = 0U;
    __Vtemp_174[17U] = ((0x00000c00U ^ (0x00000c00U 
                                        & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                           >> 0x0000000cU))) 
                        | (((8U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                   >> 0x0000001cU)) 
                            | (0x00000dd0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                              << 4U))) 
                           << 0x00000010U));
    __Vtemp_174[18U] = ((((8U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                 >> 0x0000001cU)) | 
                          (0x00000dd0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                          << 4U))) 
                         >> 0x00000010U) | (((5U & 
                                              ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                               >> 0x0000001cU)) 
                                             | (0x000000a0U 
                                                & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                                   << 4U))) 
                                            << 0x00000010U));
    __Vtemp_174[19U] = (((5U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                >> 0x0000001cU)) | 
                         (0x000000a0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                         << 4U))) >> 0x00000010U);
    __Vtemp_174[20U] = ((0x0000c000U ^ (0x0000c000U 
                                        & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                           >> 8U))) 
                        | (((0x00000080U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                            >> 0x00000018U)) 
                            | (0x0000ee00U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                              << 8U))) 
                           << 0x00000010U));
    __Vtemp_174[21U] = ((((0x00000080U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                          >> 0x00000018U)) 
                          | (0x0000ee00U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                            << 8U))) 
                         >> 0x00000010U) | (((0x00000050U 
                                              & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                                 >> 0x00000018U)) 
                                             | (0x00000a00U 
                                                & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                                   << 8U))) 
                                            << 0x00000010U));
    __Vtemp_174[22U] = (((0x00000050U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                         >> 0x00000018U)) 
                         | (0x00000a00U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                           << 8U))) 
                        >> 0x00000010U);
    __Vtemp_174[23U] = (((0x0000000cU ^ (0x0000000cU 
                                         & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                            >> 0x00000014U))) 
                         | (((8U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                    >> 0x0000001cU)) 
                             | (0x00000ff0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                               << 4U))) 
                            << 8U)) << 0x00000010U);
    __Vtemp_174[24U] = ((((0x0000000cU ^ (0x0000000cU 
                                          & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                             >> 0x00000014U))) 
                          | (((8U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                     >> 0x0000001cU)) 
                              | (0x00000ff0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                                << 4U))) 
                             << 8U)) >> 0x00000010U) 
                        | ((0x00ff0000U & (((8U & (
                                                   (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                                   >> 0x0000001cU)) 
                                            | (0x00000ff0U 
                                               & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                                  << 4U))) 
                                           >> 8U)) 
                           | (((5U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                      >> 0x0000001cU)) 
                               | (0x000000a0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                                 << 4U))) 
                              << 0x00000018U)));
    bufp->fullWData(oldp+90,(__Vtemp_174),800);
    bufp->fullBit(oldp+115,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q));
    bufp->fullBit(oldp+116,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q));
    bufp->fullBit(oldp+117,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q));
    bufp->fullBit(oldp+118,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__DOT__meta));
    bufp->fullBit(oldp+119,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q));
    bufp->fullBit(oldp+120,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__DOT__meta));
    __Vtemp_179[0U] = 0U;
    __Vtemp_179[1U] = (0x00c00000U ^ (0x80c00000U & 
                                      (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)))));
    __Vtemp_179[2U] = (0x50000088U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_179[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+121,(__Vtemp_179),100);
    __Vtemp_182[0U] = 0U;
    __Vtemp_182[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_182[2U] = (0x50000088U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_182[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+125,(__Vtemp_182),100);
    __Vtemp_187[0U] = 0U;
    __Vtemp_187[1U] = (0x00c00000U ^ (0x80c00000U & 
                                      (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)))));
    __Vtemp_187[2U] = (0x50000099U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_187[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+129,(__Vtemp_187),100);
    __Vtemp_190[0U] = 0U;
    __Vtemp_190[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_190[2U] = (0x50000099U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_190[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+133,(__Vtemp_190),100);
    __Vtemp_195[0U] = 0U;
    __Vtemp_195[1U] = (0x00c00000U ^ (0x80c00000U & 
                                      (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)))));
    __Vtemp_195[2U] = (0x500000aaU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_195[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+137,(__Vtemp_195),100);
    __Vtemp_198[0U] = 0U;
    __Vtemp_198[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_198[2U] = (0x500000aaU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_198[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+141,(__Vtemp_198),100);
    __Vtemp_203[0U] = 0U;
    __Vtemp_203[1U] = (0x00c00000U ^ (0x80c00000U & 
                                      (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)))));
    __Vtemp_203[2U] = (0x500000bbU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_203[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+145,(__Vtemp_203),100);
    __Vtemp_206[0U] = 0U;
    __Vtemp_206[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_206[2U] = (0x500000bbU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_206[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+149,(__Vtemp_206),100);
    __Vtemp_211[0U] = 0U;
    __Vtemp_211[1U] = (0x00c00000U ^ (0x80c00000U & 
                                      (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)))));
    __Vtemp_211[2U] = (0x500000ccU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_211[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+153,(__Vtemp_211),100);
    __Vtemp_214[0U] = 0U;
    __Vtemp_214[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_214[2U] = (0x500000ccU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_214[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+157,(__Vtemp_214),100);
    __Vtemp_219[0U] = 0U;
    __Vtemp_219[1U] = (0x00c00000U ^ (0x80c00000U & 
                                      (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)))));
    __Vtemp_219[2U] = (0x500000ddU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_219[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+161,(__Vtemp_219),100);
    __Vtemp_222[0U] = 0U;
    __Vtemp_222[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_222[2U] = (0x500000ddU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_222[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+165,(__Vtemp_222),100);
    __Vtemp_227[0U] = 0U;
    __Vtemp_227[1U] = (0x00c00000U ^ (0x80c00000U & 
                                      (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)))));
    __Vtemp_227[2U] = (0x500000eeU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_227[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+169,(__Vtemp_227),100);
    __Vtemp_230[0U] = 0U;
    __Vtemp_230[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_230[2U] = (0x500000eeU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_230[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+173,(__Vtemp_230),100);
    __Vtemp_235[0U] = 0U;
    __Vtemp_235[1U] = (0x00c00000U ^ (0x80c00000U & 
                                      (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)))));
    __Vtemp_235[2U] = (0x500000ffU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_235[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+177,(__Vtemp_235),100);
    __Vtemp_238[0U] = 0U;
    __Vtemp_238[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_238[2U] = (0x500000ffU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_238[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+181,(__Vtemp_238),100);
    __Vtemp_245[0U] = 0U;
    __Vtemp_245[1U] = (0x00400002U ^ ((0xa8400002U 
                                       & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[1U]) 
                                      | (0x28400002U 
                                         & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[1U])));
    __Vtemp_245[2U] = ((0x0000000aU & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[2U]) 
                       | (0x20000002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[2U]));
    bufp->fullWData(oldp+185,(__Vtemp_245),96);
    __Vtemp_250[0U] = 0U;
    __Vtemp_250[1U] = ((0xa8400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[1U]) 
                       | (0x28400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[1U]));
    __Vtemp_250[2U] = ((0x0000000aU & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[2U]) 
                       | (0x20000002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[2U]));
    bufp->fullWData(oldp+188,(__Vtemp_250),96);
    __Vtemp_257[0U] = 0U;
    __Vtemp_257[1U] = (0x00400002U ^ ((0xb8400002U 
                                       & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[1U]) 
                                      | (0x38400002U 
                                         & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[1U])));
    __Vtemp_257[2U] = ((0x0000000bU & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[2U]) 
                       | (0x20000003U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[2U]));
    bufp->fullWData(oldp+191,(__Vtemp_257),96);
    __Vtemp_262[0U] = 0U;
    __Vtemp_262[1U] = ((0xb8400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[1U]) 
                       | (0x38400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[1U]));
    __Vtemp_262[2U] = ((0x0000000bU & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[2U]) 
                       | (0x20000003U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[2U]));
    bufp->fullWData(oldp+194,(__Vtemp_262),96);
    __Vtemp_269[0U] = 0U;
    __Vtemp_269[1U] = (0x00400002U ^ ((0x88400002U 
                                       & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[1U]) 
                                      | (0x08400002U 
                                         & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[1U])));
    __Vtemp_269[2U] = ((8U & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[2U]) 
                       | (0x20000000U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[2U]));
    bufp->fullWData(oldp+197,(__Vtemp_269),96);
    __Vtemp_274[0U] = 0U;
    __Vtemp_274[1U] = ((0x88400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[1U]) 
                       | (0x08400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[1U]));
    __Vtemp_274[2U] = ((8U & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[2U]) 
                       | (0x20000000U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[2U]));
    bufp->fullWData(oldp+200,(__Vtemp_274),96);
    __Vtemp_281[0U] = 0U;
    __Vtemp_281[1U] = (0x00400002U ^ ((0x98400002U 
                                       & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[1U]) 
                                      | (0x18400002U 
                                         & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[1U])));
    __Vtemp_281[2U] = ((9U & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[2U]) 
                       | (0x20000001U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[2U]));
    bufp->fullWData(oldp+203,(__Vtemp_281),96);
    __Vtemp_286[0U] = 0U;
    __Vtemp_286[1U] = ((0x98400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[1U]) 
                       | (0x18400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[1U]));
    __Vtemp_286[2U] = ((9U & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[2U]) 
                       | (0x20000001U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[2U]));
    bufp->fullWData(oldp+206,(__Vtemp_286),96);
    __Vtemp_333[24U] = ((((0x0000000cU ^ (0x0000000cU 
                                          & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                             >> 0x00000014U))) 
                          | (((8U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                     >> 0x0000001cU)) 
                              | (0x00000ff0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                                << 4U))) 
                             << 8U)) >> 0x00000010U) 
                        | ((0x00ff0000U & (((8U & (
                                                   (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                                   >> 0x0000001cU)) 
                                            | (0x00000ff0U 
                                               & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                                  << 4U))) 
                                           >> 8U)) 
                           | (((5U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                      >> 0x0000001cU)) 
                               | (0x000000a0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                                 << 4U))) 
                              << 0x00000018U)));
    __Vtemp_358[0U] = 0U;
    __Vtemp_358[1U] = 0x80000000U;
    __Vtemp_358[2U] = 0x50000000U;
    __Vtemp_358[3U] = 0x0000000aU;
    __Vtemp_358[4U] = 0U;
    __Vtemp_358[5U] = 0x00000118U;
    __Vtemp_358[6U] = 0x000000a5U;
    __Vtemp_358[7U] = 0U;
    __Vtemp_358[8U] = 0x00002280U;
    __Vtemp_358[9U] = 0x00000a50U;
    __Vtemp_358[10U] = 0U;
    __Vtemp_358[11U] = 0x00033800U;
    __Vtemp_358[12U] = 0x0000a500U;
    __Vtemp_358[13U] = 0U;
    __Vtemp_358[14U] = ((0x000000c0U ^ (0x000080c0U 
                                        & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                           >> 0x00000010U))) 
                        | (0x00440000U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                          << 0x00000010U)));
    __Vtemp_358[15U] = ((0x00005000U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                        >> 0x00000010U)) 
                        | (0x000a0000U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                          << 0x00000010U)));
    __Vtemp_358[16U] = 0U;
    __Vtemp_358[17U] = ((0x00000c00U ^ (0x00080c00U 
                                        & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                           >> 0x0000000cU))) 
                        | (0x05500000U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                          << 0x00000014U)));
    __Vtemp_358[18U] = ((0x00050000U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                        >> 0x0000000cU)) 
                        | (0x00a00000U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                          << 0x00000014U)));
    __Vtemp_358[19U] = 0U;
    __Vtemp_358[20U] = ((0x0000c000U ^ (0x0080c000U 
                                        & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                           >> 8U))) 
                        | (0x66000000U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                          << 0x00000018U)));
    __Vtemp_358[21U] = ((0x00500000U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                        >> 8U)) | (0x0a000000U 
                                                   & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                                      << 0x00000018U)));
    __Vtemp_358[22U] = 0U;
    __Vtemp_358[23U] = ((0x000c0000U ^ (0x000c0000U 
                                        & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                           >> 4U))) 
                        | (((8U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                   >> 0x0000001cU)) 
                            | (0x00000770U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                              << 4U))) 
                           << 0x00000018U));
    __Vtemp_358[24U] = ((((8U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                 >> 0x0000001cU)) | 
                          (0x00000770U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                          << 4U))) 
                         >> 8U) | (((5U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                           >> 0x0000001cU)) 
                                    | (0x000000a0U 
                                       & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                          << 4U))) 
                                   << 0x00000018U));
    __Vtemp_358[25U] = 0U;
    __Vtemp_358[26U] = (0x00c00000U ^ (0x80c00000U 
                                       & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)))));
    __Vtemp_358[27U] = (0x50000088U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_358[28U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_358[29U] = (0x0c000000U ^ (0x0c000000U 
                                       & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                          << 4U)));
    __Vtemp_358[30U] = ((8U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                               >> 0x0000001cU)) | (0x00000990U 
                                                   & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                                      << 4U)));
    __Vtemp_358[31U] = ((5U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                               >> 0x0000001cU)) | (0x000000a0U 
                                                   & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                                      << 4U)));
    __Vtemp_358[32U] = (0xc0000000U ^ (0xc0000000U 
                                       & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                          << 8U)));
    __Vtemp_358[33U] = ((0x00000080U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                        >> 0x00000018U)) 
                        | (0x0000aa00U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                          << 8U)));
    __Vtemp_358[34U] = ((0x00000050U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                        >> 0x00000018U)) 
                        | (0x00000a00U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                          << 8U)));
    __Vtemp_358[35U] = 0U;
    __Vtemp_358[36U] = ((0x0000000cU ^ (0x0000000cU 
                                        & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                           >> 0x00000014U))) 
                        | (((8U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                   >> 0x0000001cU)) 
                            | (0x00000bb0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                              << 4U))) 
                           << 8U));
    __Vtemp_358[37U] = ((((8U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                 >> 0x0000001cU)) | 
                          (0x00000bb0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                          << 4U))) 
                         >> 0x00000018U) | (((5U & 
                                              ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                               >> 0x0000001cU)) 
                                             | (0x000000a0U 
                                                & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                                   << 4U))) 
                                            << 8U));
    __Vtemp_358[38U] = 0U;
    __Vtemp_358[39U] = ((0x000000c0U ^ (0x000080c0U 
                                        & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                           >> 0x00000010U))) 
                        | (0x00cc0000U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                          << 0x00000010U)));
    __Vtemp_358[40U] = ((0x00005000U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                        >> 0x00000010U)) 
                        | (0x000a0000U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                          << 0x00000010U)));
    __Vtemp_358[41U] = 0U;
    __Vtemp_358[42U] = ((0x00000c00U ^ (0x00000c00U 
                                        & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                           >> 0x0000000cU))) 
                        | (((8U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                   >> 0x0000001cU)) 
                            | (0x00000dd0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                              << 4U))) 
                           << 0x00000010U));
    __Vtemp_358[43U] = ((((8U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                 >> 0x0000001cU)) | 
                          (0x00000dd0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                          << 4U))) 
                         >> 0x00000010U) | (((5U & 
                                              ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                               >> 0x0000001cU)) 
                                             | (0x000000a0U 
                                                & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                                   << 4U))) 
                                            << 0x00000010U));
    __Vtemp_358[44U] = (((5U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                >> 0x0000001cU)) | 
                         (0x000000a0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                         << 4U))) >> 0x00000010U);
    __Vtemp_358[45U] = ((0x0000c000U ^ (0x0000c000U 
                                        & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                           >> 8U))) 
                        | (((0x00000080U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                            >> 0x00000018U)) 
                            | (0x0000ee00U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                              << 8U))) 
                           << 0x00000010U));
    __Vtemp_358[46U] = ((((0x00000080U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                          >> 0x00000018U)) 
                          | (0x0000ee00U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                            << 8U))) 
                         >> 0x00000010U) | (((0x00000050U 
                                              & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                                 >> 0x00000018U)) 
                                             | (0x00000a00U 
                                                & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                                   << 8U))) 
                                            << 0x00000010U));
    __Vtemp_358[47U] = (((0x00000050U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                         >> 0x00000018U)) 
                         | (0x00000a00U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                           << 8U))) 
                        >> 0x00000010U);
    __Vtemp_358[48U] = (((0x0000000cU ^ (0x0000000cU 
                                         & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                            >> 0x00000014U))) 
                         | (((8U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                    >> 0x0000001cU)) 
                             | (0x00000ff0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                               << 4U))) 
                            << 8U)) << 0x00000010U);
    __Vtemp_358[49U] = __Vtemp_333[24U];
    bufp->fullWData(oldp+209,(__Vtemp_358),1600);
    bufp->fullBit(oldp+259,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q));
    bufp->fullBit(oldp+260,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q));
    bufp->fullBit(oldp+261,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q));
    bufp->fullBit(oldp+262,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q));
    bufp->fullBit(oldp+263,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__DOT__meta));
    bufp->fullBit(oldp+264,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q));
    bufp->fullBit(oldp+265,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__DOT__meta));
    bufp->fullBit(oldp+266,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q));
    bufp->fullBit(oldp+267,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__DOT__meta));
    __Vtemp_363[0U] = 0U;
    __Vtemp_363[1U] = (0x00c00000U ^ (0x80c00000U & 
                                      (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)))));
    __Vtemp_363[2U] = (0x500000aaU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_363[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+268,(__Vtemp_363),100);
    __Vtemp_366[0U] = 0U;
    __Vtemp_366[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_366[2U] = (0x500000aaU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_366[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+272,(__Vtemp_366),100);
    __Vtemp_371[0U] = 0U;
    __Vtemp_371[1U] = (0x00c00000U ^ (0x80c00000U & 
                                      (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)))));
    __Vtemp_371[2U] = (0x500000bbU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_371[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+276,(__Vtemp_371),100);
    __Vtemp_374[0U] = 0U;
    __Vtemp_374[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_374[2U] = (0x500000bbU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_374[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+280,(__Vtemp_374),100);
    __Vtemp_379[0U] = 0U;
    __Vtemp_379[1U] = (0x00c00000U ^ (0x80c00000U & 
                                      (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)))));
    __Vtemp_379[2U] = (0x500000ccU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_379[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+284,(__Vtemp_379),100);
    __Vtemp_382[0U] = 0U;
    __Vtemp_382[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_382[2U] = (0x500000ccU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_382[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+288,(__Vtemp_382),100);
    __Vtemp_387[0U] = 0U;
    __Vtemp_387[1U] = (0x00c00000U ^ (0x80c00000U & 
                                      (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)))));
    __Vtemp_387[2U] = (0x500000ddU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_387[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+292,(__Vtemp_387),100);
    __Vtemp_390[0U] = 0U;
    __Vtemp_390[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_390[2U] = (0x500000ddU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_390[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+296,(__Vtemp_390),100);
    __Vtemp_395[0U] = 0U;
    __Vtemp_395[1U] = (0x00c00000U ^ (0x80c00000U & 
                                      (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)))));
    __Vtemp_395[2U] = (0x500000eeU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_395[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+300,(__Vtemp_395),100);
    __Vtemp_398[0U] = 0U;
    __Vtemp_398[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_398[2U] = (0x500000eeU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_398[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+304,(__Vtemp_398),100);
    __Vtemp_403[0U] = 0U;
    __Vtemp_403[1U] = (0x00c00000U ^ (0x80c00000U & 
                                      (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)))));
    __Vtemp_403[2U] = (0x500000ffU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_403[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+308,(__Vtemp_403),100);
    __Vtemp_406[0U] = 0U;
    __Vtemp_406[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_406[2U] = (0x500000ffU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_406[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+312,(__Vtemp_406),100);
    __Vtemp_411[0U] = 0U;
    __Vtemp_411[1U] = (0x00c00000U ^ (0x80c00000U & 
                                      (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)))));
    __Vtemp_411[2U] = (0x50000044U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_411[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+316,(__Vtemp_411),100);
    __Vtemp_414[0U] = 0U;
    __Vtemp_414[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_414[2U] = (0x50000044U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_414[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+320,(__Vtemp_414),100);
    __Vtemp_419[0U] = 0U;
    __Vtemp_419[1U] = (0x00c00000U ^ (0x80c00000U & 
                                      (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)))));
    __Vtemp_419[2U] = (0x50000055U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_419[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+324,(__Vtemp_419),100);
    __Vtemp_422[0U] = 0U;
    __Vtemp_422[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_422[2U] = (0x50000055U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_422[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+328,(__Vtemp_422),100);
    __Vtemp_427[0U] = 0U;
    __Vtemp_427[1U] = (0x00c00000U ^ (0x80c00000U & 
                                      (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)))));
    __Vtemp_427[2U] = (0x50000066U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_427[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+332,(__Vtemp_427),100);
    __Vtemp_430[0U] = 0U;
    __Vtemp_430[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_430[2U] = (0x50000066U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_430[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+336,(__Vtemp_430),100);
    __Vtemp_435[0U] = 0U;
    __Vtemp_435[1U] = (0x00c00000U ^ (0x80c00000U & 
                                      (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)))));
    __Vtemp_435[2U] = (0x50000077U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_435[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+340,(__Vtemp_435),100);
    __Vtemp_438[0U] = 0U;
    __Vtemp_438[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_438[2U] = (0x50000077U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_438[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+344,(__Vtemp_438),100);
    __Vtemp_443[0U] = 0U;
    __Vtemp_443[1U] = (0x00c00000U ^ (0x80c00000U & 
                                      (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)))));
    __Vtemp_443[2U] = (0x50000088U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_443[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+348,(__Vtemp_443),100);
    __Vtemp_446[0U] = 0U;
    __Vtemp_446[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_446[2U] = (0x50000088U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_446[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+352,(__Vtemp_446),100);
    __Vtemp_451[0U] = 0U;
    __Vtemp_451[1U] = (0x00c00000U ^ (0x80c00000U & 
                                      (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)))));
    __Vtemp_451[2U] = (0x50000099U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_451[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+356,(__Vtemp_451),100);
    __Vtemp_454[0U] = 0U;
    __Vtemp_454[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_454[2U] = (0x50000099U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    __Vtemp_454[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+360,(__Vtemp_454),100);
    __Vtemp_461[0U] = 0U;
    __Vtemp_461[1U] = (0x00400002U ^ ((0x08400002U 
                                       & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[1U]) 
                                      | (0x48400002U 
                                         & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[1U])));
    __Vtemp_461[2U] = ((0x10000000U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[2U]) 
                       | (4U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[2U]));
    bufp->fullWData(oldp+364,(__Vtemp_461),96);
    __Vtemp_466[0U] = 0U;
    __Vtemp_466[1U] = ((0x08400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[1U]) 
                       | (0x48400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[1U]));
    __Vtemp_466[2U] = ((0x10000000U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[2U]) 
                       | (4U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[2U]));
    bufp->fullWData(oldp+367,(__Vtemp_466),96);
    __Vtemp_473[0U] = 0U;
    __Vtemp_473[1U] = (0x00400002U ^ ((0x18400002U 
                                       & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[1U]) 
                                      | (0x58400002U 
                                         & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[1U])));
    __Vtemp_473[2U] = ((0x10000001U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[2U]) 
                       | (5U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[2U]));
    bufp->fullWData(oldp+370,(__Vtemp_473),96);
    __Vtemp_478[0U] = 0U;
    __Vtemp_478[1U] = ((0x18400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[1U]) 
                       | (0x58400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[1U]));
    __Vtemp_478[2U] = ((0x10000001U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[2U]) 
                       | (5U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[2U]));
    bufp->fullWData(oldp+373,(__Vtemp_478),96);
    __Vtemp_485[0U] = 0U;
    __Vtemp_485[1U] = (0x00400002U ^ ((0x28400002U 
                                       & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[1U]) 
                                      | (0x68400002U 
                                         & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[1U])));
    __Vtemp_485[2U] = ((0x10000002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[2U]) 
                       | (6U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[2U]));
    bufp->fullWData(oldp+376,(__Vtemp_485),96);
    __Vtemp_490[0U] = 0U;
    __Vtemp_490[1U] = ((0x28400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[1U]) 
                       | (0x68400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[1U]));
    __Vtemp_490[2U] = ((0x10000002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[2U]) 
                       | (6U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[2U]));
    bufp->fullWData(oldp+379,(__Vtemp_490),96);
    __Vtemp_497[0U] = 0U;
    __Vtemp_497[1U] = (0x00400002U ^ ((0x78400002U 
                                       & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[1U]) 
                                      | (0x38400002U 
                                         & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[1U])));
    __Vtemp_497[2U] = ((7U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[2U]) 
                       | (0x10000003U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[2U]));
    bufp->fullWData(oldp+382,(__Vtemp_497),96);
    __Vtemp_502[0U] = 0U;
    __Vtemp_502[1U] = ((0x78400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[1U]) 
                       | (0x38400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[1U]));
    __Vtemp_502[2U] = ((7U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[2U]) 
                       | (0x10000003U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[2U]));
    bufp->fullWData(oldp+385,(__Vtemp_502),96);
    __Vtemp_525[0U] = 0U;
    __Vtemp_525[1U] = (0x00c00000U ^ (0x80c00000U & 
                                      (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)))));
    __Vtemp_525[2U] = (0x50000044U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_525[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_525[4U] = (0x0c000000U ^ (0x0c000000U & 
                                      ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                       << 4U)));
    __Vtemp_525[5U] = ((8U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                              >> 0x0000001cU)) | (0x00000550U 
                                                  & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                                     << 4U)));
    __Vtemp_525[6U] = ((5U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                              >> 0x0000001cU)) | (0x000000a0U 
                                                  & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                                     << 4U)));
    __Vtemp_525[7U] = (0xc0000000U ^ (0xc0000000U & 
                                      ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                       << 8U)));
    __Vtemp_525[8U] = ((0x00000080U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                       >> 0x00000018U)) 
                       | (0x00006600U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                         << 8U)));
    __Vtemp_525[9U] = ((0x00000050U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                       >> 0x00000018U)) 
                       | (0x00000a00U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                         << 8U)));
    __Vtemp_525[10U] = 0U;
    __Vtemp_525[11U] = ((0x0000000cU ^ (0x0000000cU 
                                        & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                           >> 0x00000014U))) 
                        | (((8U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                   >> 0x0000001cU)) 
                            | (0x00000770U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                              << 4U))) 
                           << 8U));
    __Vtemp_525[12U] = ((((8U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                 >> 0x0000001cU)) | 
                          (0x00000770U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                          << 4U))) 
                         >> 0x00000018U) | (((5U & 
                                              ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                               >> 0x0000001cU)) 
                                             | (0x000000a0U 
                                                & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                                   << 4U))) 
                                            << 8U));
    bufp->fullWData(oldp+388,(__Vtemp_525),400);
    bufp->fullBit(oldp+401,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q));
    bufp->fullBit(oldp+402,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q));
    bufp->fullBit(oldp+403,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__DOT__meta));
    __Vtemp_530[0U] = 0U;
    __Vtemp_530[1U] = (0x00c00000U ^ (0x80c00000U & 
                                      (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)))));
    __Vtemp_530[2U] = (0x50000044U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_530[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+404,(__Vtemp_530),100);
    __Vtemp_533[0U] = 0U;
    __Vtemp_533[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_533[2U] = (0x50000044U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_533[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+408,(__Vtemp_533),100);
    __Vtemp_538[0U] = 0U;
    __Vtemp_538[1U] = (0x00c00000U ^ (0x80c00000U & 
                                      (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)))));
    __Vtemp_538[2U] = (0x50000055U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_538[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+412,(__Vtemp_538),100);
    __Vtemp_541[0U] = 0U;
    __Vtemp_541[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_541[2U] = (0x50000055U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_541[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+416,(__Vtemp_541),100);
    __Vtemp_546[0U] = 0U;
    __Vtemp_546[1U] = (0x00c00000U ^ (0x80c00000U & 
                                      (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)))));
    __Vtemp_546[2U] = (0x50000066U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_546[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+420,(__Vtemp_546),100);
    __Vtemp_549[0U] = 0U;
    __Vtemp_549[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_549[2U] = (0x50000066U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_549[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+424,(__Vtemp_549),100);
    __Vtemp_554[0U] = 0U;
    __Vtemp_554[1U] = (0x00c00000U ^ (0x80c00000U & 
                                      (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)))));
    __Vtemp_554[2U] = (0x50000077U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_554[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+428,(__Vtemp_554),100);
    __Vtemp_557[0U] = 0U;
    __Vtemp_557[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_557[2U] = (0x50000077U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    __Vtemp_557[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
    bufp->fullWData(oldp+432,(__Vtemp_557),100);
    bufp->fullCData(oldp+436,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__en),2);
    bufp->fullBit(oldp+437,((1U & (~ (0U != (2U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__en)))))));
    bufp->fullBit(oldp+438,((1U & (~ (0U != (1U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__en)))))));
    bufp->fullCData(oldp+439,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__en),3);
    bufp->fullBit(oldp+440,((1U & (~ (0U != (6U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__en)))))));
    bufp->fullBit(oldp+441,((1U & (~ (0U != (5U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__en)))))));
    bufp->fullBit(oldp+442,((1U & (~ (0U != (3U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__en)))))));
    bufp->fullCData(oldp+443,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__en),2);
    bufp->fullBit(oldp+444,((1U & (~ (0U != (2U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__en)))))));
    bufp->fullBit(oldp+445,((1U & (~ (0U != (1U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__en)))))));
    bufp->fullWData(oldp+446,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy),1536);
    bufp->fullCData(oldp+494,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__sel_tgt),7);
    bufp->fullSData(oldp+495,(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out),16);
    bufp->fullCData(oldp+496,(vlSelfRef.tb_pipe_lane_mapper__DOT__mode),2);
    bufp->fullCData(oldp+497,(((8U & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                                      >> 9U)) | ((4U 
                                                  & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                                                     >> 6U)) 
                                                 | (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__branch_clk)))),4);
    bufp->fullSData(oldp+498,(((((0x000000f0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__pclk_in_g3))) 
                                                 << 4U)) 
                                 | (0x0000000fU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__pclk_in_g2))))) 
                                << 8U) | ((0x000000f0U 
                                           & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__pclk_in_g1))) 
                                              << 4U)) 
                                          | (0x0000000fU 
                                             & (- (IData)(
                                                          (1U 
                                                           & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out)))))))),16);
    bufp->fullSData(oldp+499,(((((0x000000f0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__u_rst_g3__DOT__dout))) 
                                                 << 4U)) 
                                 | (0x0000000fU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__u_rst_g2__DOT__dout))))) 
                                << 8U) | ((0x000000f0U 
                                           & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__u_rst_g1__DOT__dout))) 
                                              << 4U)) 
                                          | (0x0000000fU 
                                             & (- (IData)(
                                                          (1U 
                                                           & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__ctrl_rst_n)))))))),16);
    bufp->fullIData(oldp+500,(vlSelfRef.tb_pipe_lane_mapper__DOT__err_count),32);
    bufp->fullCData(oldp+501,(((0x1ffffffeU & (((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g1_b1__DOT__en_latched) 
                                                << 1U) 
                                               & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                                                  >> 3U))) 
                               | ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g1_b0__DOT__en_latched) 
                                  & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out)))),2);
    bufp->fullBit(oldp+502,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__pclk_in_g1));
    bufp->fullCData(oldp+503,(((0x01fffffeU & (((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g2_b1__DOT__en_latched) 
                                                << 1U) 
                                               & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                                                  >> 7U))) 
                               | ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g2_b0__DOT__en_latched) 
                                  & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out)))),2);
    bufp->fullBit(oldp+504,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__pclk_in_g2));
    bufp->fullCData(oldp+505,(((0x003ffffcU & (((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g3_b2__DOT__en_latched) 
                                                << 2U) 
                                               & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                                                  >> 0x0000000aU))) 
                               | ((0x01fffffeU & (((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g3_b1__DOT__en_latched) 
                                                   << 1U) 
                                                  & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                                                     >> 7U))) 
                                  | ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g3_b0__DOT__en_latched) 
                                     & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out))))),3);
    bufp->fullBit(oldp+506,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__pclk_in_g3));
    bufp->fullBit(oldp+507,((1U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out))));
    bufp->fullBit(oldp+508,(((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g1_b0__DOT__en_latched) 
                             & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out))));
    bufp->fullBit(oldp+509,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g1_b0__DOT__en_latched));
    bufp->fullBit(oldp+510,((1U & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                                   >> 4U))));
    bufp->fullBit(oldp+511,(((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g1_b1__DOT__en_latched) 
                             & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                                >> 4U))));
    bufp->fullBit(oldp+512,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g1_b1__DOT__en_latched));
    bufp->fullBit(oldp+513,(((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g2_b0__DOT__en_latched) 
                             & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out))));
    bufp->fullBit(oldp+514,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g2_b0__DOT__en_latched));
    bufp->fullBit(oldp+515,((1U & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                                   >> 8U))));
    bufp->fullBit(oldp+516,(((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g2_b1__DOT__en_latched) 
                             & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                                >> 8U))));
    bufp->fullBit(oldp+517,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g2_b1__DOT__en_latched));
    bufp->fullBit(oldp+518,(((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g3_b0__DOT__en_latched) 
                             & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out))));
    bufp->fullBit(oldp+519,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g3_b0__DOT__en_latched));
    bufp->fullBit(oldp+520,(((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g3_b1__DOT__en_latched) 
                             & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                                >> 8U))));
    bufp->fullBit(oldp+521,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g3_b1__DOT__en_latched));
    bufp->fullBit(oldp+522,((1U & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                                   >> 0x0000000cU))));
    bufp->fullBit(oldp+523,(((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g3_b2__DOT__en_latched) 
                             & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                                >> 0x0000000cU))));
    bufp->fullBit(oldp+524,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g3_b2__DOT__en_latched));
    bufp->fullBit(oldp+525,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__tgt_r));
    bufp->fullBit(oldp+526,(((~ (0U != (2U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__en)))) 
                             & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__tgt_r))));
    bufp->fullBit(oldp+527,(((~ (0U != (2U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__en)))) 
                             & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__tgt_r))));
    bufp->fullBit(oldp+528,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__tgt_r));
    bufp->fullBit(oldp+529,(((~ (0U != (1U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__en)))) 
                             & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__tgt_r))));
    bufp->fullBit(oldp+530,(((~ (0U != (1U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__en)))) 
                             & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__tgt_r))));
    bufp->fullBit(oldp+531,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__tgt_r));
    bufp->fullBit(oldp+532,(((~ (0U != (2U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__en)))) 
                             & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__tgt_r))));
    bufp->fullBit(oldp+533,(((~ (0U != (2U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__en)))) 
                             & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__tgt_r))));
    bufp->fullBit(oldp+534,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__tgt_r));
    bufp->fullBit(oldp+535,(((~ (0U != (1U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__en)))) 
                             & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__tgt_r))));
    bufp->fullBit(oldp+536,(((~ (0U != (1U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__en)))) 
                             & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__tgt_r))));
    bufp->fullBit(oldp+537,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__tgt_r));
    bufp->fullBit(oldp+538,(((~ (0U != (6U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__en)))) 
                             & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__tgt_r))));
    bufp->fullBit(oldp+539,(((~ (0U != (6U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__en)))) 
                             & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__tgt_r))));
    bufp->fullBit(oldp+540,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__tgt_r));
    bufp->fullBit(oldp+541,(((~ (0U != (5U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__en)))) 
                             & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__tgt_r))));
    bufp->fullBit(oldp+542,(((~ (0U != (5U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__en)))) 
                             & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__tgt_r))));
    bufp->fullBit(oldp+543,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__2__KET____DOT__tgt_r));
    bufp->fullBit(oldp+544,(((~ (0U != (3U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__en)))) 
                             & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__2__KET____DOT__tgt_r))));
    bufp->fullBit(oldp+545,(((~ (0U != (3U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__en)))) 
                             & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__2__KET____DOT__tgt_r))));
    bufp->fullBit(oldp+546,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__u_rst_g1__DOT__dout));
    bufp->fullBit(oldp+547,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__u_rst_g2__DOT__dout));
    bufp->fullBit(oldp+548,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__u_rst_g3__DOT__dout));
    bufp->fullBit(oldp+549,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__u_rst_g1__DOT__dout));
    bufp->fullBit(oldp+550,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__u_rst_g2__DOT__dout));
    bufp->fullBit(oldp+551,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__u_rst_g3__DOT__dout));
    bufp->fullIData(oldp+552,(vlSelfRef.tb_pipe_lane_mapper__DOT__unnamedblk15__DOT__unnamedblk16__DOT__pulse_cid),32);
    bufp->fullBit(oldp+553,(vlSelfRef.tb_pipe_lane_mapper__DOT__unnamedblk15__DOT__unnamedblk16__DOT__unnamedblk17__DOT__unnamedblk18__DOT__expect_low));
}
