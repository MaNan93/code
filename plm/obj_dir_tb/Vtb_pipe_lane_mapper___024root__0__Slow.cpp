// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtb_pipe_lane_mapper.h for the primary calling header

#include "Vtb_pipe_lane_mapper__pch.h"

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root___eval_static(Vtb_pipe_lane_mapper___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root___eval_static\n"); );
    Vtb_pipe_lane_mapper__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    {
        // Inlined CFunc: _eval_static__TOP
        vlSelfRef.tb_pipe_lane_mapper__DOT__ctrl_rst_n = 0U;
        vlSelfRef.tb_pipe_lane_mapper__DOT__mode = 0U;
        vlSelfRef.tb_pipe_lane_mapper__DOT__err_count = 0U;
        vlSelfRef.tb_pipe_lane_mapper__DOT__unnamedblk15__DOT__unnamedblk16__DOT__pulse_cid = 0U;
        vlSelfRef.tb_pipe_lane_mapper__DOT__unnamedblk15__DOT__unnamedblk16__DOT__unnamedblk17__DOT__unnamedblk18__DOT__expect_low = 0U;
    }
    {
        // Inlined CFunc: __Vm_traceActivitySetAll
        vlSelfRef.__Vm_traceActivity[0U] = 1U;
        vlSelfRef.__Vm_traceActivity[1U] = 1U;
        vlSelfRef.__Vm_traceActivity[2U] = 1U;
        vlSelfRef.__Vm_traceActivity[3U] = 1U;
        vlSelfRef.__Vm_traceActivity[4U] = 1U;
        vlSelfRef.__Vm_traceActivity[5U] = 1U;
        vlSelfRef.__Vm_traceActivity[6U] = 1U;
        vlSelfRef.__Vm_traceActivity[7U] = 1U;
        vlSelfRef.__Vm_traceActivity[8U] = 1U;
        vlSelfRef.__Vm_traceActivity[9U] = 1U;
        vlSelfRef.__Vm_traceActivity[10U] = 1U;
        vlSelfRef.__Vm_traceActivity[11U] = 1U;
        vlSelfRef.__Vm_traceActivity[12U] = 1U;
    }
    vlSelfRef.__VactTriggered[1U] = (1ULL | vlSelfRef.__VactTriggered[1U]);
    vlSelfRef.__Vtrigprevexpr_h8385d5c9__0 = (1U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__branch_clk));
    vlSelfRef.__Vtrigprevexpr_h372891da__0 = (1U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__branch_rst_n));
    vlSelfRef.__Vtrigprevexpr_h8385cf81__0 = (1U & 
                                              ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__branch_clk) 
                                               >> 1U));
    vlSelfRef.__Vtrigprevexpr_h37287ca2__0 = (1U & 
                                              ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__branch_rst_n) 
                                               >> 1U));
    vlSelfRef.__Vtrigprevexpr_h8385d64b__0 = (1U & 
                                              ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__branch_clk) 
                                               >> 2U));
    vlSelfRef.__Vtrigprevexpr_h37289568__0 = (1U & 
                                              ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__branch_rst_n) 
                                               >> 2U));
    vlSelfRef.__Vtrigprevexpr_h4fd220d6__0 = 0U;
    vlSelfRef.__Vtrigprevexpr_h3c9f729d__0 = (1U & 
                                              ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                                               >> 0x0000000cU));
    vlSelfRef.__Vtrigprevexpr_h4fd22095__0 = 0U;
    vlSelfRef.__Vtrigprevexpr_h3c9f779e__0 = (1U & 
                                              ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                                               >> 8U));
    vlSelfRef.__Vtrigprevexpr_h4fd2200b__0 = 0U;
    vlSelfRef.__Vtrigprevexpr_h3c9eb7c8__0 = (1U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out));
    vlSelfRef.__Vtrigprevexpr_hd9e332bd__0 = (1U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__branch_clk));
    vlSelfRef.__Vtrigprevexpr_hc2cd7bff__0 = (1U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__branch_rst_n));
    vlSelfRef.__Vtrigprevexpr_hd9e31e8d__0 = (1U & 
                                              ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__branch_clk) 
                                               >> 1U));
    vlSelfRef.__Vtrigprevexpr_hc2cd7acf__0 = (1U & 
                                              ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__branch_rst_n) 
                                               >> 1U));
    vlSelfRef.__Vtrigprevexpr_h76fca2d2__0 = (1U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__branch_clk));
    vlSelfRef.__Vtrigprevexpr_h4fd2204c__0 = 0U;
    vlSelfRef.__Vtrigprevexpr_h76fca402__0 = (1U & 
                                              ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__branch_clk) 
                                               >> 1U));
    vlSelfRef.__Vtrigprevexpr_h3c9eacc7__0 = (1U & 
                                              ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                                               >> 4U));
    vlSelfRef.__Vtrigprevexpr___TOP__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__sel_tgt__0 
        = vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__sel_tgt;
    do {
        vlSelfRef.__VactTriggeredAcc[vlSelfRef.__Vi] 
            = vlSelfRef.__VactTriggered[vlSelfRef.__Vi];
        vlSelfRef.__Vi = ((IData)(1U) + vlSelfRef.__Vi);
    } while ((1U >= vlSelfRef.__Vi));
}

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root___eval_final(Vtb_pipe_lane_mapper___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root___eval_final\n"); );
    Vtb_pipe_lane_mapper__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root___dump_triggers__stl(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG
VL_ATTR_COLD bool Vtb_pipe_lane_mapper___024root___eval_phase__stl(Vtb_pipe_lane_mapper___024root* vlSelf);

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root___eval_settle(Vtb_pipe_lane_mapper___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root___eval_settle\n"); );
    Vtb_pipe_lane_mapper__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    IData/*31:0*/ __VstlIterCount;
    // Body
    __VstlIterCount = 0U;
    vlSelfRef.__VstlFirstIteration = 1U;
    do {
        if (VL_UNLIKELY(((0x00002710U < __VstlIterCount)))) {
#ifdef VL_DEBUG
            Vtb_pipe_lane_mapper___024root___dump_triggers__stl(vlSelfRef.__VstlTriggered, "stl"s);
#endif
            VL_FATAL_MT("tb/tb_pipe_lane_mapper.sv", 20, "", "DIDNOTCONVERGE: Settle region did not converge after '--converge-limit' of 10000 tries");
        }
        __VstlIterCount = ((IData)(1U) + __VstlIterCount);
        vlSelfRef.__VstlPhaseResult = Vtb_pipe_lane_mapper___024root___eval_phase__stl(vlSelf);
        vlSelfRef.__VstlFirstIteration = 0U;
    } while (vlSelfRef.__VstlPhaseResult);
}

VL_ATTR_COLD bool Vtb_pipe_lane_mapper___024root___trigger_anySet__stl(const VlUnpacked<QData/*63:0*/, 1> &in);

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root___dump_triggers__stl(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root___dump_triggers__stl\n"); );
    // Body
    if ((1U & (~ (IData)(Vtb_pipe_lane_mapper___024root___trigger_anySet__stl(triggers))))) {
        VL_DBG_MSGS("         No '" + tag + "' region triggers active\n");
    }
    if ((1U & (IData)(triggers[0U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 0 is active: Internal 'stl' trigger - first iteration\n");
    }
}
#endif  // VL_DEBUG

VL_ATTR_COLD bool Vtb_pipe_lane_mapper___024root___trigger_anySet__stl(const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root___trigger_anySet__stl\n"); );
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

extern const VlWide<10>/*319:0*/ Vtb_pipe_lane_mapper__ConstPool__CONST_hb4617e49_0;
extern const VlUnpacked<CData/*6:0*/, 5> Vtb_pipe_lane_mapper__ConstPool__TABLE_h1064a8d7_0;

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root___stl_sequent__TOP__0(Vtb_pipe_lane_mapper___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root___stl_sequent__TOP__0\n"); );
    Vtb_pipe_lane_mapper__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*2:0*/ __VdfgRegularize_hebeb780c_0_14;
    __VdfgRegularize_hebeb780c_0_14 = 0;
    IData/*31:0*/ __Vtemp_1;
    // Body
    if ((1U & (~ VL_ONEHOT_I(((((3U == (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__mode)) 
                                << 3U) | ((2U == (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__mode)) 
                                          << 2U)) | 
                              (((1U == (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__mode)) 
                                << 1U) | (0U == (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__mode)))))))) {
        if ((0U != ((((3U == (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__mode)) 
                      << 3U) | ((2U == (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__mode)) 
                                << 2U)) | (((1U == (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__mode)) 
                                            << 1U) 
                                           | (0U == (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__mode)))))) {
            if (VL_UNLIKELY((vlSymsp->_vm_contextp__->assertOn()))) {
                VL_WRITEF_NX("[%0t] %%Error: pipe_lane_decoder.sv:22: Assertion failed in %m: unique case, but multiple matches found for '32'h%X'\n",4, 'M',vlSymsp->name(),"tb_pipe_lane_mapper.dut.u_clk_top.u_decoder", 'T',-9
                             , '#',64,VL_TIME_UNITED_Q(1000)
                             , '#',32,(IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__mode));
                VL_STOP_MT("tb/../rtl/src/pipe_lane_decoder.sv", 22, "");
            }
        }
    }
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__branch_clk 
        = ((4U & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                  >> 0x0000000aU)) | ((2U & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                                             >> 7U)) 
                                      | (1U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out))));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__branch_clk 
        = ((2U & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                  >> 7U)) | (1U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out)));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__branch_clk 
        = ((2U & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                  >> 3U)) | (1U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out)));
    __Vtemp_1 = VL_MATCHMASKED_I(32, (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__mode), Vtb_pipe_lane_mapper__ConstPool__CONST_hb4617e49_0);
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_decoder__DOT__sel_tgt 
        = Vtb_pipe_lane_mapper__ConstPool__TABLE_h1064a8d7_0
        [__Vtemp_1];
    if ((1U & (~ ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                  >> 8U)))) {
        vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g2_b1__DOT__en_latched 
            = vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q;
        vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g3_b1__DOT__en_latched 
            = vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q;
    }
    if ((1U & (~ (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out)))) {
        vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g2_b0__DOT__en_latched 
            = vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q;
        vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g1_b0__DOT__en_latched 
            = vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q;
        vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g3_b0__DOT__en_latched 
            = vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q;
    }
    if ((1U & (~ ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                  >> 4U)))) {
        vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g1_b1__DOT__en_latched 
            = vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q;
    }
    if ((1U & (~ ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                  >> 0x0000000cU)))) {
        vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g3_b2__DOT__en_latched 
            = vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q;
    }
    vlSelfRef.__VdfgRegularize_hebeb780c_0_7[0U] = 
        (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)));
    vlSelfRef.__VdfgRegularize_hebeb780c_0_7[1U] = 
        (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)));
    vlSelfRef.__VdfgRegularize_hebeb780c_0_7[2U] = 
        (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)));
    vlSelfRef.__VdfgRegularize_hebeb780c_0_8[0U] = 
        (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)));
    vlSelfRef.__VdfgRegularize_hebeb780c_0_8[1U] = 
        (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)));
    vlSelfRef.__VdfgRegularize_hebeb780c_0_8[2U] = 
        (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)));
    vlSelfRef.__VdfgRegularize_hebeb780c_0_9[0U] = 
        (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)));
    vlSelfRef.__VdfgRegularize_hebeb780c_0_9[1U] = 
        (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)));
    vlSelfRef.__VdfgRegularize_hebeb780c_0_9[2U] = 
        (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)));
    vlSelfRef.__VdfgRegularize_hebeb780c_0_10[0U] = 
        (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)));
    vlSelfRef.__VdfgRegularize_hebeb780c_0_10[1U] = 
        (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)));
    vlSelfRef.__VdfgRegularize_hebeb780c_0_10[2U] = 
        (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)));
    vlSelfRef.__VdfgRegularize_hebeb780c_0_11[0U] = 
        (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)));
    vlSelfRef.__VdfgRegularize_hebeb780c_0_11[1U] = 
        (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)));
    vlSelfRef.__VdfgRegularize_hebeb780c_0_11[2U] = 
        (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)));
    vlSelfRef.__VdfgRegularize_hebeb780c_0_12[0U] = 
        (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)));
    vlSelfRef.__VdfgRegularize_hebeb780c_0_12[1U] = 
        (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)));
    vlSelfRef.__VdfgRegularize_hebeb780c_0_12[2U] = 
        (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)));
    vlSelfRef.__VdfgRegularize_hebeb780c_0_13[0U] = 
        (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q)));
    vlSelfRef.__VdfgRegularize_hebeb780c_0_13[1U] = 
        (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q)));
    vlSelfRef.__VdfgRegularize_hebeb780c_0_13[2U] = 
        (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q)));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__branch_rst_n 
        = ((2U & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__ctrl_rst_n) 
                  >> 1U)) | (1U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__ctrl_rst_n)));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__branch_rst_n 
        = ((6U & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__ctrl_rst_n) 
                  >> 1U)) | (1U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__ctrl_rst_n)));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__en 
        = (((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q) 
            << 1U) | (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__en 
        = (((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q) 
            << 1U) | (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__en 
        = (((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q) 
            << 2U) | (((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q) 
                       << 1U) | (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__pclk_in_g2 
        = (((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g2_b0__DOT__en_latched) 
            & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out)) 
           | ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g2_b1__DOT__en_latched) 
              & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                 >> 8U)));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__pclk_in_g1 
        = (((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g1_b0__DOT__en_latched) 
            & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out)) 
           | ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g1_b1__DOT__en_latched) 
              & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                 >> 4U)));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__pclk_in_g3 
        = (((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g3_b0__DOT__en_latched) 
            & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out)) 
           | (((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g3_b1__DOT__en_latched) 
               & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                  >> 8U)) | ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g3_b2__DOT__en_latched) 
                             & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                                >> 0x0000000cU))));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[0U] = 0U;
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[1U] = 0x08000000U;
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[2U] = 0U;
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[3U] = 0U;
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[4U] = 0x18000000U;
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[5U] = 1U;
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[6U] = 0U;
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[7U] = 0x28000000U;
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[8U] = 2U;
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[9U] = 0U;
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[10U] = 0x38000000U;
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[11U] = 3U;
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[12U] = 0U;
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[13U] 
        = (0x00400002U ^ ((0x08400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[1U]) 
                          | (0x48400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[1U])));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[14U] 
        = ((0x10000000U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[2U]) 
           | (4U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[2U]));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[15U] = 0U;
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[16U] 
        = (0x00400002U ^ ((0x18400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[1U]) 
                          | (0x58400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[1U])));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[17U] 
        = ((0x10000001U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[2U]) 
           | (5U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[2U]));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[18U] = 0U;
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[19U] 
        = (0x00400002U ^ ((0x28400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[1U]) 
                          | (0x68400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[1U])));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[20U] 
        = ((0x10000002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[2U]) 
           | (6U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[2U]));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[21U] = 0U;
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[22U] 
        = (0x00400002U ^ ((0x78400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[1U]) 
                          | (0x38400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[1U])));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[23U] 
        = ((7U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[2U]) 
           | (0x10000003U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[2U]));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[24U] = 0U;
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[25U] 
        = (0x00400002U ^ ((0x88400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[1U]) 
                          | (0x08400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[1U])));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[26U] 
        = ((8U & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[2U]) 
           | (0x20000000U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[2U]));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[27U] = 0U;
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[28U] 
        = (0x00400002U ^ ((0x98400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[1U]) 
                          | (0x18400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[1U])));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[29U] 
        = ((9U & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[2U]) 
           | (0x20000001U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[2U]));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[30U] = 0U;
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[31U] 
        = (0x00400002U ^ ((0xa8400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[1U]) 
                          | (0x28400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[1U])));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[32U] 
        = ((0x0000000aU & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[2U]) 
           | (0x20000002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[2U]));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[33U] = 0U;
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[34U] 
        = (0x00400002U ^ ((0xb8400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[1U]) 
                          | (0x38400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[1U])));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[35U] 
        = ((0x0000000bU & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[2U]) 
           | (0x20000003U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[2U]));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[36U] = 0U;
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[37U] 
        = (0x00400002U ^ ((0xc8400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[1U]) 
                          | ((0x08400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[1U]) 
                             | (0x48400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[1U]))));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[38U] 
        = ((0x0000000cU & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[2U]) 
           | ((0x30000000U & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[2U]) 
              | (0x20000004U & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[2U])));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[39U] = 0U;
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[40U] 
        = (0x00400002U ^ ((0xd8400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[1U]) 
                          | ((0x18400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[1U]) 
                             | (0x58400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[1U]))));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[41U] 
        = ((0x0000000dU & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[2U]) 
           | ((0x30000001U & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[2U]) 
              | (0x20000005U & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[2U])));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[42U] = 0U;
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[43U] 
        = (0x00400002U ^ ((0xe8400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[1U]) 
                          | ((0x28400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[1U]) 
                             | (0x68400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[1U]))));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[44U] 
        = ((0x0000000eU & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[2U]) 
           | ((0x30000002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[2U]) 
              | (0x20000006U & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[2U])));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[45U] = 0U;
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[46U] 
        = (0x00400002U ^ ((0xf8400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[1U]) 
                          | ((0x78400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[1U]) 
                             | (0x38400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[1U]))));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy[47U] 
        = ((0x0000000fU & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[2U]) 
           | ((0x20000007U & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[2U]) 
              | (0x30000003U & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[2U])));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__u_rst_g2__DOT__dout 
        = (0U != ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__branch_rst_n) 
                  & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__en)));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__u_rst_g1__DOT__dout 
        = (0U != ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__ctrl_rst_n) 
                  & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__en)));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__sel_tgt 
        = (((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__en) 
            << 5U) | (((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__en) 
                       << 3U) | (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__en)));
    __VdfgRegularize_hebeb780c_0_14 = ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__branch_rst_n) 
                                       & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__en));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__u_rst_g3__DOT__dout 
        = (IData)((0U != (IData)(__VdfgRegularize_hebeb780c_0_14)));
    vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__phy_rst_n 
        = ((((0x000000f0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__u_rst_g3__DOT__dout))) 
                             << 4U)) | (0x0000000fU 
                                        & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__u_rst_g2__DOT__dout))))) 
            << 8U) | ((0x000000f0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__u_rst_g1__DOT__dout))) 
                                      << 4U)) | (0x0000000fU 
                                                 & (- (IData)(
                                                              (1U 
                                                               & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__ctrl_rst_n)))))));
}

VL_ATTR_COLD bool Vtb_pipe_lane_mapper___024root___eval_phase__stl(Vtb_pipe_lane_mapper___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root___eval_phase__stl\n"); );
    Vtb_pipe_lane_mapper__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VstlExecute;
    // Body
    {
        // Inlined CFunc: _eval_triggers_vec__stl
        vlSelfRef.__VstlTriggered[0U] = ((0xfffffffffffffffeULL 
                                          & vlSelfRef.__VstlTriggered[0U]) 
                                         | (IData)((IData)(vlSelfRef.__VstlFirstIteration)));
    }
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vtb_pipe_lane_mapper___024root___dump_triggers__stl(vlSelfRef.__VstlTriggered, "stl"s);
    }
#endif
    __VstlExecute = Vtb_pipe_lane_mapper___024root___trigger_anySet__stl(vlSelfRef.__VstlTriggered);
    if (__VstlExecute) {
        {
            // Inlined CFunc: _eval_stl
            if ((1ULL & vlSelfRef.__VstlTriggered[0U])) {
                Vtb_pipe_lane_mapper___024root___stl_sequent__TOP__0(vlSelf);
                {
                    // Inlined CFunc: __Vm_traceActivitySetAll
                    vlSelfRef.__Vm_traceActivity[0U] = 1U;
                    vlSelfRef.__Vm_traceActivity[1U] = 1U;
                    vlSelfRef.__Vm_traceActivity[2U] = 1U;
                    vlSelfRef.__Vm_traceActivity[3U] = 1U;
                    vlSelfRef.__Vm_traceActivity[4U] = 1U;
                    vlSelfRef.__Vm_traceActivity[5U] = 1U;
                    vlSelfRef.__Vm_traceActivity[6U] = 1U;
                    vlSelfRef.__Vm_traceActivity[7U] = 1U;
                    vlSelfRef.__Vm_traceActivity[8U] = 1U;
                    vlSelfRef.__Vm_traceActivity[9U] = 1U;
                    vlSelfRef.__Vm_traceActivity[10U] = 1U;
                    vlSelfRef.__Vm_traceActivity[11U] = 1U;
                    vlSelfRef.__Vm_traceActivity[12U] = 1U;
                }
            }
        }
    }
    return (__VstlExecute);
}

bool Vtb_pipe_lane_mapper___024root___trigger_anySet__act(const VlUnpacked<QData/*63:0*/, 2> &in);

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root___dump_triggers__act(const VlUnpacked<QData/*63:0*/, 2> &triggers, const std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root___dump_triggers__act\n"); );
    // Body
    if ((1U & (~ (IData)(Vtb_pipe_lane_mapper___024root___trigger_anySet__act(triggers))))) {
        VL_DBG_MSGS("         No '" + tag + "' region triggers active\n");
    }
    if ((1U & (IData)(triggers[0U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 0 is active: @(posedge tb_pipe_lane_mapper.dut.u_clk_top.u_sel_sync_g3.branch_clk[0])\n");
    }
    if ((1U & (IData)((triggers[0U] >> 1U)))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 1 is active: @(negedge tb_pipe_lane_mapper.dut.u_clk_top.u_sel_sync_g3.branch_rst_n[0])\n");
    }
    if ((1U & (IData)((triggers[0U] >> 2U)))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 2 is active: @(posedge tb_pipe_lane_mapper.dut.u_clk_top.u_sel_sync_g3.branch_clk[1])\n");
    }
    if ((1U & (IData)((triggers[0U] >> 3U)))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 3 is active: @(negedge tb_pipe_lane_mapper.dut.u_clk_top.u_sel_sync_g3.branch_rst_n[1])\n");
    }
    if ((1U & (IData)((triggers[0U] >> 4U)))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 4 is active: @(posedge tb_pipe_lane_mapper.dut.u_clk_top.u_sel_sync_g3.branch_clk[2])\n");
    }
    if ((1U & (IData)((triggers[0U] >> 5U)))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 5 is active: @(negedge tb_pipe_lane_mapper.dut.u_clk_top.u_sel_sync_g3.branch_rst_n[2])\n");
    }
    if ((1U & (IData)((triggers[0U] >> 6U)))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 6 is active: @(negedge tb_pipe_lane_mapper.ctrl_rst_n[3])\n");
    }
    if ((1U & (IData)((triggers[0U] >> 7U)))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 7 is active: @(posedge tb_pipe_lane_mapper.phy_pclk_out[12])\n");
    }
    if ((1U & (IData)((triggers[0U] >> 8U)))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 8 is active: @(negedge tb_pipe_lane_mapper.ctrl_rst_n[2])\n");
    }
    if ((1U & (IData)((triggers[0U] >> 9U)))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 9 is active: @(posedge tb_pipe_lane_mapper.phy_pclk_out[8])\n");
    }
    if ((1U & (IData)((triggers[0U] >> 0x0000000aU)))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 10 is active: @(negedge tb_pipe_lane_mapper.ctrl_rst_n[0])\n");
    }
    if ((1U & (IData)((triggers[0U] >> 0x0000000bU)))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 11 is active: @(posedge tb_pipe_lane_mapper.phy_pclk_out[0])\n");
    }
    if ((1U & (IData)((triggers[0U] >> 0x0000000cU)))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 12 is active: @(posedge tb_pipe_lane_mapper.dut.u_clk_top.u_sel_sync_g2.branch_clk[0])\n");
    }
    if ((1U & (IData)((triggers[0U] >> 0x0000000dU)))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 13 is active: @(negedge tb_pipe_lane_mapper.dut.u_clk_top.u_sel_sync_g2.branch_rst_n[0])\n");
    }
    if ((1U & (IData)((triggers[0U] >> 0x0000000eU)))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 14 is active: @(posedge tb_pipe_lane_mapper.dut.u_clk_top.u_sel_sync_g2.branch_clk[1])\n");
    }
    if ((1U & (IData)((triggers[0U] >> 0x0000000fU)))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 15 is active: @(negedge tb_pipe_lane_mapper.dut.u_clk_top.u_sel_sync_g2.branch_rst_n[1])\n");
    }
    if ((1U & (IData)((triggers[0U] >> 0x00000010U)))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 16 is active: @(posedge tb_pipe_lane_mapper.dut.u_clk_top.u_sel_sync_g1.branch_clk[0])\n");
    }
    if ((1U & (IData)((triggers[0U] >> 0x00000011U)))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 17 is active: @(negedge tb_pipe_lane_mapper.ctrl_rst_n[1])\n");
    }
    if ((1U & (IData)((triggers[0U] >> 0x00000012U)))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 18 is active: @(posedge tb_pipe_lane_mapper.dut.u_clk_top.u_sel_sync_g1.branch_clk[1])\n");
    }
    if ((1U & (IData)((triggers[0U] >> 0x00000013U)))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 19 is active: @(posedge tb_pipe_lane_mapper.phy_pclk_out[4])\n");
    }
    if ((1U & (IData)(triggers[1U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 64 is active: @( tb_pipe_lane_mapper.dut.u_clk_top.sel_tgt)\n");
    }
    if ((1U & (IData)((triggers[1U] >> 1U)))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 65 is active: @([true] __VdlySched.awaitingCurrentTime())\n");
    }
}
#endif  // VL_DEBUG

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root___dump_triggers__act_ext(const VlUnpacked<QData/*63:0*/, 3> &ext, const std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root___dump_triggers__act_ext\n"); );
    // Locals
    VlUnpacked<QData/*63:0*/, 2> vec;
    IData/*31:0*/ i;
    VlUnpacked<QData/*63:0*/, 2> pre;
    IData/*31:0*/ j;
    // Body
    i = 0U;
    do {
        vec[i] = ext[i];
        i = ((IData)(1U) + i);
    } while ((2U > i));
    Vtb_pipe_lane_mapper___024root___dump_triggers__act(vec, tag);
    j = 0U;
    do {
        pre[j] = ext[j];
        j = ((IData)(1U) + j);
    } while ((1U > j));
    do {
        pre[j] = 0ULL;
        j = ((IData)(1U) + j);
    } while ((2U > j));
    Vtb_pipe_lane_mapper___024root___dump_triggers__act(pre, 
                                                        VL_CONCATN_NNN(tag, " pre"s));
}
#endif  // VL_DEBUG

VL_ATTR_COLD void Vtb_pipe_lane_mapper___024root___ctor_var_reset(Vtb_pipe_lane_mapper___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root___ctor_var_reset\n"); );
    Vtb_pipe_lane_mapper__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    const uint64_t __VscopeHash = VL_MURMUR64_HASH(vlSelf->vlNamep);
    vlSelf->tb_pipe_lane_mapper__DOT__phy_pclk_out = VL_SCOPED_RAND_RESET_I(16, __VscopeHash, 3476498483130210205ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__sel_tgt = VL_SCOPED_RAND_RESET_I(7, __VscopeHash, 13084835275884064038ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__pclk_in_g1 = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 15641199767344046557ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__pclk_in_g2 = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 12866003045289602190ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__pclk_in_g3 = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 10775757377480023514ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__branch_clk = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 8611396382724043763ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__branch_rst_n = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 6638210004981156988ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__en = VL_SCOPED_RAND_RESET_I(3, __VscopeHash, 1004227304047677480ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__tgt_r = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 8562221395882064090ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q = 0;
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__tgt_r = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 3082375608192597991ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q = 0;
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__2__KET____DOT__tgt_r = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 6441895396108902973ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q = 0;
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__DOT__meta = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 7378867206306477372ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__DOT__meta = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 10109832239933602127ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__DOT__meta = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 7671877002335438299ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__branch_clk = VL_SCOPED_RAND_RESET_I(2, __VscopeHash, 15825799435364445721ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__branch_rst_n = VL_SCOPED_RAND_RESET_I(2, __VscopeHash, 11817345443137422144ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__en = VL_SCOPED_RAND_RESET_I(2, __VscopeHash, 5612416237168820700ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__tgt_r = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 14948406850069408590ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q = 0;
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__tgt_r = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 4917910454957154480ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q = 0;
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__DOT__meta = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 17592567766403626697ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__DOT__meta = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 391296082572167032ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__branch_clk = VL_SCOPED_RAND_RESET_I(2, __VscopeHash, 9320926934181117780ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__en = VL_SCOPED_RAND_RESET_I(2, __VscopeHash, 8888352240495505250ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__tgt_r = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 12499710867140374750ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q = 0;
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__tgt_r = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 5688618841233312476ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q = 0;
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__DOT__meta = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 8801001730284069776ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__DOT__meta = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 13655030464660705584ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g3_b2__DOT__en_latched = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 7329727653798762255ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g3_b1__DOT__en_latched = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 14660476718942656634ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g3_b0__DOT__en_latched = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 12496246432319682663ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g2_b1__DOT__en_latched = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 2458844877104612963ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g2_b0__DOT__en_latched = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 12258492956781604097ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g1_b1__DOT__en_latched = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 16183417815992249915ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g1_b0__DOT__en_latched = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 11210137254439359679ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_decoder__DOT__sel_tgt = VL_SCOPED_RAND_RESET_I(7, __VscopeHash, 18399431621970929875ull);
    VL_SCOPED_RAND_RESET_W(1536, vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy, __VscopeHash, 7370954315765546046ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__phy_rst_n = VL_SCOPED_RAND_RESET_I(16, __VscopeHash, 6125422246049242619ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__u_rst_g2__DOT__dout = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 6298472361175723458ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__u_rst_g1__DOT__dout = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 6463617343187880203ull);
    vlSelf->tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__u_rst_g3__DOT__dout = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 5475827887846696159ull);
    vlSelf->__Vtask_tb_pipe_lane_mapper__DOT__check_mode__44__m = 0;
    vlSelf->__Vtask_tb_pipe_lane_mapper__DOT__check_mode__44__unnamedblk10__DOT__c = 0;
    VL_ZERO_RESET_W(100, vlSelf->__Vtask_tb_pipe_lane_mapper__DOT__check_mode__44__exp_p2m);
    vlSelf->__Vtask_tb_pipe_lane_mapper__DOT__check_mode__88__m = 0;
    VL_ZERO_RESET_W(96, vlSelf->__Vtask_tb_pipe_lane_mapper__DOT__check_mode__88__exp_m2p);
    VL_ZERO_RESET_W(100, vlSelf->__Vtask_tb_pipe_lane_mapper__DOT__check_mode__88__exp_p2m);
    vlSelf->__Vtask_tb_pipe_lane_mapper__DOT__check_mode__88__cid = 0;
    vlSelf->__Vtask_tb_pipe_lane_mapper__DOT__check_mode__88__port = 0;
    vlSelf->__Vfunc_tb_pipe_lane_mapper__DOT__owner_of__89__Vfuncout = 0;
    vlSelf->__Vfunc_tb_pipe_lane_mapper__DOT__owner_of__89__m = 0;
    vlSelf->__Vfunc_tb_pipe_lane_mapper__DOT__port_of__90__Vfuncout = 0;
    vlSelf->__Vfunc_tb_pipe_lane_mapper__DOT__port_of__90__m = 0;
    VL_ZERO_RESET_W(96, vlSelf->__Vfunc_tb_pipe_lane_mapper__DOT__make_m2p__91__Vfuncout);
    vlSelf->__Vfunc_tb_pipe_lane_mapper__DOT__make_m2p__91__cid = 0;
    vlSelf->__Vfunc_tb_pipe_lane_mapper__DOT__make_m2p__91__port = 0;
    VL_ZERO_RESET_W(96, vlSelf->__Vfunc_tb_pipe_lane_mapper__DOT__make_m2p__91__v);
    vlSelf->__Vtask_tb_pipe_lane_mapper__DOT__chk__92__ok = 0;
    vlSelf->__Vtask_tb_pipe_lane_mapper__DOT__chk__93__ok = 0;
    VL_ZERO_RESET_W(96, vlSelf->__VdfgRegularize_hebeb780c_0_7);
    VL_ZERO_RESET_W(96, vlSelf->__VdfgRegularize_hebeb780c_0_8);
    VL_ZERO_RESET_W(96, vlSelf->__VdfgRegularize_hebeb780c_0_9);
    VL_ZERO_RESET_W(96, vlSelf->__VdfgRegularize_hebeb780c_0_10);
    VL_ZERO_RESET_W(96, vlSelf->__VdfgRegularize_hebeb780c_0_11);
    VL_ZERO_RESET_W(96, vlSelf->__VdfgRegularize_hebeb780c_0_12);
    VL_ZERO_RESET_W(96, vlSelf->__VdfgRegularize_hebeb780c_0_13);
    vlSelf->__Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__tgt_r = 0;
    vlSelf->__Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__tgt_r = 0;
    vlSelf->__Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__2__KET____DOT__tgt_r = 0;
    vlSelf->__Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__DOT__meta = 0;
    vlSelf->__Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q = 0;
    vlSelf->__Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__DOT__meta = 0;
    vlSelf->__Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q = 0;
    vlSelf->__Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__DOT__meta = 0;
    vlSelf->__Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q = 0;
    vlSelf->__Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__tgt_r = 0;
    vlSelf->__Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__tgt_r = 0;
    vlSelf->__Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__DOT__meta = 0;
    vlSelf->__Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q = 0;
    vlSelf->__Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__DOT__meta = 0;
    vlSelf->__Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q = 0;
    vlSelf->__Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__tgt_r = 0;
    vlSelf->__Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__tgt_r = 0;
    vlSelf->__Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__DOT__meta = 0;
    vlSelf->__Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q = 0;
    vlSelf->__Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__DOT__meta = 0;
    vlSelf->__Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q = 0;
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->__VstlTriggered[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 3; ++__Vi0) {
        vlSelf->__VactTriggered[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 2; ++__Vi0) {
        vlSelf->__VactTriggeredAcc[__Vi0] = 0;
    }
    vlSelf->__Vtrigprevexpr_h8385d5c9__0 = 0;
    vlSelf->__Vtrigprevexpr_h372891da__0 = 0;
    vlSelf->__Vtrigprevexpr_h8385cf81__0 = 0;
    vlSelf->__Vtrigprevexpr_h37287ca2__0 = 0;
    vlSelf->__Vtrigprevexpr_h8385d64b__0 = 0;
    vlSelf->__Vtrigprevexpr_h37289568__0 = 0;
    vlSelf->__Vtrigprevexpr_h4fd220d6__0 = 0;
    vlSelf->__Vtrigprevexpr_h3c9f729d__0 = 0;
    vlSelf->__Vtrigprevexpr_h4fd22095__0 = 0;
    vlSelf->__Vtrigprevexpr_h3c9f779e__0 = 0;
    vlSelf->__Vtrigprevexpr_h4fd2200b__0 = 0;
    vlSelf->__Vtrigprevexpr_h3c9eb7c8__0 = 0;
    vlSelf->__Vtrigprevexpr_hd9e332bd__0 = 0;
    vlSelf->__Vtrigprevexpr_hc2cd7bff__0 = 0;
    vlSelf->__Vtrigprevexpr_hd9e31e8d__0 = 0;
    vlSelf->__Vtrigprevexpr_hc2cd7acf__0 = 0;
    vlSelf->__Vtrigprevexpr_h76fca2d2__0 = 0;
    vlSelf->__Vtrigprevexpr_h4fd2204c__0 = 0;
    vlSelf->__Vtrigprevexpr_h76fca402__0 = 0;
    vlSelf->__Vtrigprevexpr_h3c9eacc7__0 = 0;
    vlSelf->__Vtrigprevexpr___TOP__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__sel_tgt__0 = 0;
    for (int __Vi0 = 0; __Vi0 < 2; ++__Vi0) {
        vlSelf->__VnbaTriggered[__Vi0] = 0;
    }
    vlSelf->__Vi = 0;
    for (int __Vi0 = 0; __Vi0 < 13; ++__Vi0) {
        vlSelf->__Vm_traceActivity[__Vi0] = 0;
    }
}
