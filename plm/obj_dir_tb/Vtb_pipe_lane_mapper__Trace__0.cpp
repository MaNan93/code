// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Tracing implementation internals

#include "verilated_vcd_c.h"
#include "Vtb_pipe_lane_mapper__Syms.h"


void Vtb_pipe_lane_mapper___024root__trace_chg_0_sub_0(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd::Buffer* bufp);

void Vtb_pipe_lane_mapper___024root__trace_chg_0(void* voidSelf, VerilatedVcd::Buffer* bufp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root__trace_chg_0\n"); );
    // Body
    Vtb_pipe_lane_mapper___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtb_pipe_lane_mapper___024root*>(voidSelf);
    Vtb_pipe_lane_mapper__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    if (VL_UNLIKELY(!vlSymsp->__Vm_activity)) return;
    Vtb_pipe_lane_mapper___024root__trace_chg_0_sub_0((&vlSymsp->TOP), bufp);
}

void Vtb_pipe_lane_mapper___024root__trace_chg_0_sub_0(Vtb_pipe_lane_mapper___024root* vlSelf, VerilatedVcd::Buffer* bufp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root__trace_chg_0_sub_0\n"); );
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
    uint32_t* const oldp VL_ATTR_UNUSED = bufp->oldp(vlSymsp->__Vm_baseCode + 0);
    if (VL_UNLIKELY(((vlSelfRef.__Vm_traceActivity[1U] 
                      | vlSelfRef.__Vm_traceActivity[2U])))) {
        bufp->chgCData(oldp+0,(vlSelfRef.tb_pipe_lane_mapper__DOT__ctrl_rst_n),4);
        bufp->chgCData(oldp+1,((3U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__ctrl_rst_n))),2);
        bufp->chgBit(oldp+2,((1U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__ctrl_rst_n))));
        bufp->chgBit(oldp+3,((1U & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__ctrl_rst_n) 
                                    >> 1U))));
        bufp->chgBit(oldp+4,((1U & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__ctrl_rst_n) 
                                    >> 2U))));
        bufp->chgBit(oldp+5,((1U & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__ctrl_rst_n) 
                                    >> 3U))));
        bufp->chgCData(oldp+6,((3U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__ctrl_rst_n))),2);
    }
    if (VL_UNLIKELY((vlSelfRef.__Vm_traceActivity[3U]))) {
        bufp->chgCData(oldp+7,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__branch_clk),2);
        bufp->chgCData(oldp+8,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__branch_clk),2);
        bufp->chgCData(oldp+9,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__branch_clk),3);
    }
    if (VL_UNLIKELY((vlSelfRef.__Vm_traceActivity[4U]))) {
        bufp->chgCData(oldp+10,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_decoder__DOT__sel_tgt),7);
        bufp->chgCData(oldp+11,((3U & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_decoder__DOT__sel_tgt) 
                                       >> 5U))),2);
        bufp->chgCData(oldp+12,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__branch_rst_n),2);
        bufp->chgCData(oldp+13,((3U & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_decoder__DOT__sel_tgt) 
                                       >> 3U))),2);
        bufp->chgCData(oldp+14,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__branch_rst_n),3);
        bufp->chgCData(oldp+15,((7U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_decoder__DOT__sel_tgt))),3);
        bufp->chgCData(oldp+16,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__branch_rst_n),2);
        bufp->chgCData(oldp+17,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__branch_rst_n),3);
    }
    if (VL_UNLIKELY((vlSelfRef.__Vm_traceActivity[5U]))) {
        __Vtemp_23[0U] = 0U;
        __Vtemp_23[1U] = (0x00c00000U ^ (0x80c00000U 
                                         & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q)))));
        __Vtemp_23[2U] = (0x500000ccU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
        __Vtemp_23[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
        __Vtemp_23[4U] = (0x0c000000U ^ (0x0c000000U 
                                         & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))) 
                                            << 4U)));
        __Vtemp_23[5U] = ((8U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))) 
                                 >> 0x0000001cU)) | 
                          (0x00000dd0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))) 
                                          << 4U)));
        __Vtemp_23[6U] = ((5U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))) 
                                 >> 0x0000001cU)) | 
                          (0x000000a0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))) 
                                          << 4U)));
        __Vtemp_23[7U] = (0xc0000000U ^ (0xc0000000U 
                                         & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))) 
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
                                    >> 0x0000001cU)) 
                             | (0x00000ff0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))) 
                                               << 4U))) 
                            >> 0x00000018U) | (((5U 
                                                 & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))) 
                                                    >> 0x0000001cU)) 
                                                | (0x000000a0U 
                                                   & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))) 
                                                      << 4U))) 
                                               << 8U));
        bufp->chgWData(oldp+18,(__Vtemp_23),400);
        bufp->chgBit(oldp+31,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q));
        bufp->chgBit(oldp+32,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q));
        bufp->chgBit(oldp+33,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__DOT__meta));
        __Vtemp_28[0U] = 0U;
        __Vtemp_28[1U] = (0x00c00000U ^ (0x80c00000U 
                                         & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q)))));
        __Vtemp_28[2U] = (0x500000ccU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
        __Vtemp_28[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+34,(__Vtemp_28),100);
        __Vtemp_31[0U] = 0U;
        __Vtemp_31[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
        __Vtemp_31[2U] = (0x500000ccU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
        __Vtemp_31[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+38,(__Vtemp_31),100);
        __Vtemp_36[0U] = 0U;
        __Vtemp_36[1U] = (0x00c00000U ^ (0x80c00000U 
                                         & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q)))));
        __Vtemp_36[2U] = (0x500000ddU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
        __Vtemp_36[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+42,(__Vtemp_36),100);
        __Vtemp_39[0U] = 0U;
        __Vtemp_39[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
        __Vtemp_39[2U] = (0x500000ddU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
        __Vtemp_39[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+46,(__Vtemp_39),100);
        __Vtemp_44[0U] = 0U;
        __Vtemp_44[1U] = (0x00c00000U ^ (0x80c00000U 
                                         & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q)))));
        __Vtemp_44[2U] = (0x500000eeU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
        __Vtemp_44[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+50,(__Vtemp_44),100);
        __Vtemp_47[0U] = 0U;
        __Vtemp_47[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
        __Vtemp_47[2U] = (0x500000eeU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
        __Vtemp_47[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+54,(__Vtemp_47),100);
        __Vtemp_52[0U] = 0U;
        __Vtemp_52[1U] = (0x00c00000U ^ (0x80c00000U 
                                         & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q)))));
        __Vtemp_52[2U] = (0x500000ffU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
        __Vtemp_52[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+58,(__Vtemp_52),100);
        __Vtemp_55[0U] = 0U;
        __Vtemp_55[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
        __Vtemp_55[2U] = (0x500000ffU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
        __Vtemp_55[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+62,(__Vtemp_55),100);
    }
    if (VL_UNLIKELY((((vlSelfRef.__Vm_traceActivity[5U] 
                       | vlSelfRef.__Vm_traceActivity[6U]) 
                      | vlSelfRef.__Vm_traceActivity[7U])))) {
        __Vtemp_65[0U] = 0U;
        __Vtemp_65[1U] = (0x00400002U ^ ((0xc8400002U 
                                          & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[1U]) 
                                         | ((0x08400002U 
                                             & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[1U]) 
                                            | (0x48400002U 
                                               & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[1U]))));
        __Vtemp_65[2U] = ((0x0000000cU & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[2U]) 
                          | ((0x30000000U & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[2U]) 
                             | (0x20000004U & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[2U])));
        bufp->chgWData(oldp+66,(__Vtemp_65),96);
        __Vtemp_73[0U] = 0U;
        __Vtemp_73[1U] = ((0xc8400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[1U]) 
                          | ((0x08400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[1U]) 
                             | (0x48400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[1U])));
        __Vtemp_73[2U] = ((0x0000000cU & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[2U]) 
                          | ((0x30000000U & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[2U]) 
                             | (0x20000004U & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[2U])));
        bufp->chgWData(oldp+69,(__Vtemp_73),96);
        __Vtemp_83[0U] = 0U;
        __Vtemp_83[1U] = (0x00400002U ^ ((0xd8400002U 
                                          & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[1U]) 
                                         | ((0x18400002U 
                                             & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[1U]) 
                                            | (0x58400002U 
                                               & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[1U]))));
        __Vtemp_83[2U] = ((0x0000000dU & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[2U]) 
                          | ((0x30000001U & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[2U]) 
                             | (0x20000005U & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[2U])));
        bufp->chgWData(oldp+72,(__Vtemp_83),96);
        __Vtemp_91[0U] = 0U;
        __Vtemp_91[1U] = ((0xd8400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[1U]) 
                          | ((0x18400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[1U]) 
                             | (0x58400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[1U])));
        __Vtemp_91[2U] = ((0x0000000dU & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[2U]) 
                          | ((0x30000001U & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[2U]) 
                             | (0x20000005U & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[2U])));
        bufp->chgWData(oldp+75,(__Vtemp_91),96);
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
        bufp->chgWData(oldp+78,(__Vtemp_101),96);
        __Vtemp_109[0U] = 0U;
        __Vtemp_109[1U] = ((0xe8400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[1U]) 
                           | ((0x28400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[1U]) 
                              | (0x68400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[1U])));
        __Vtemp_109[2U] = ((0x0000000eU & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[2U]) 
                           | ((0x30000002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[2U]) 
                              | (0x20000006U & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[2U])));
        bufp->chgWData(oldp+81,(__Vtemp_109),96);
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
        bufp->chgWData(oldp+84,(__Vtemp_119),96);
        __Vtemp_127[0U] = 0U;
        __Vtemp_127[1U] = ((0xf8400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[1U]) 
                           | ((0x78400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[1U]) 
                              | (0x38400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[1U])));
        __Vtemp_127[2U] = ((0x0000000fU & vlSelfRef.__VdfgRegularize_hebeb780c_0_11[2U]) 
                           | ((0x20000007U & vlSelfRef.__VdfgRegularize_hebeb780c_0_12[2U]) 
                              | (0x30000003U & vlSelfRef.__VdfgRegularize_hebeb780c_0_13[2U])));
        bufp->chgWData(oldp+87,(__Vtemp_127),96);
    }
    if (VL_UNLIKELY((vlSelfRef.__Vm_traceActivity[6U]))) {
        __Vtemp_174[0U] = 0U;
        __Vtemp_174[1U] = (0x00c00000U ^ (0x80c00000U 
                                          & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)))));
        __Vtemp_174[2U] = (0x50000088U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_174[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_174[4U] = (0x0c000000U ^ (0x0c000000U 
                                          & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                             << 4U)));
        __Vtemp_174[5U] = ((8U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                  >> 0x0000001cU)) 
                           | (0x00000990U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                             << 4U)));
        __Vtemp_174[6U] = ((5U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                  >> 0x0000001cU)) 
                           | (0x000000a0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                             << 4U)));
        __Vtemp_174[7U] = (0xc0000000U ^ (0xc0000000U 
                                          & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
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
                                     >> 0x0000001cU)) 
                              | (0x00000bb0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                                << 4U))) 
                             >> 0x00000018U) | (((5U 
                                                  & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
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
                                     >> 0x0000001cU)) 
                              | (0x00000dd0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                                << 4U))) 
                             >> 0x00000010U) | (((5U 
                                                  & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                                     >> 0x0000001cU)) 
                                                 | (0x000000a0U 
                                                    & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                                       << 4U))) 
                                                << 0x00000010U));
        __Vtemp_174[19U] = (((5U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                    >> 0x0000001cU)) 
                             | (0x000000a0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                               << 4U))) 
                            >> 0x00000010U);
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
                                 | (0x00000ff0U & (
                                                   (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                                   << 4U))) 
                                << 8U)) << 0x00000010U);
        __Vtemp_174[24U] = ((((0x0000000cU ^ (0x0000000cU 
                                              & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                                 >> 0x00000014U))) 
                              | (((8U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                         >> 0x0000001cU)) 
                                  | (0x00000ff0U & 
                                     ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                      << 4U))) << 8U)) 
                             >> 0x00000010U) | ((0x00ff0000U 
                                                 & (((8U 
                                                      & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                                         >> 0x0000001cU)) 
                                                     | (0x00000ff0U 
                                                        & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                                           << 4U))) 
                                                    >> 8U)) 
                                                | (((5U 
                                                     & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                                        >> 0x0000001cU)) 
                                                    | (0x000000a0U 
                                                       & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                                          << 4U))) 
                                                   << 0x00000018U)));
        bufp->chgWData(oldp+90,(__Vtemp_174),800);
        bufp->chgBit(oldp+115,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q));
        bufp->chgBit(oldp+116,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q));
        bufp->chgBit(oldp+117,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q));
        bufp->chgBit(oldp+118,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__DOT__meta));
        bufp->chgBit(oldp+119,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q));
        bufp->chgBit(oldp+120,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__DOT__meta));
        __Vtemp_179[0U] = 0U;
        __Vtemp_179[1U] = (0x00c00000U ^ (0x80c00000U 
                                          & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)))));
        __Vtemp_179[2U] = (0x50000088U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_179[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+121,(__Vtemp_179),100);
        __Vtemp_182[0U] = 0U;
        __Vtemp_182[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_182[2U] = (0x50000088U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_182[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+125,(__Vtemp_182),100);
        __Vtemp_187[0U] = 0U;
        __Vtemp_187[1U] = (0x00c00000U ^ (0x80c00000U 
                                          & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)))));
        __Vtemp_187[2U] = (0x50000099U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_187[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+129,(__Vtemp_187),100);
        __Vtemp_190[0U] = 0U;
        __Vtemp_190[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_190[2U] = (0x50000099U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_190[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+133,(__Vtemp_190),100);
        __Vtemp_195[0U] = 0U;
        __Vtemp_195[1U] = (0x00c00000U ^ (0x80c00000U 
                                          & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)))));
        __Vtemp_195[2U] = (0x500000aaU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_195[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+137,(__Vtemp_195),100);
        __Vtemp_198[0U] = 0U;
        __Vtemp_198[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_198[2U] = (0x500000aaU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_198[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+141,(__Vtemp_198),100);
        __Vtemp_203[0U] = 0U;
        __Vtemp_203[1U] = (0x00c00000U ^ (0x80c00000U 
                                          & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)))));
        __Vtemp_203[2U] = (0x500000bbU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_203[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+145,(__Vtemp_203),100);
        __Vtemp_206[0U] = 0U;
        __Vtemp_206[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_206[2U] = (0x500000bbU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_206[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+149,(__Vtemp_206),100);
        __Vtemp_211[0U] = 0U;
        __Vtemp_211[1U] = (0x00c00000U ^ (0x80c00000U 
                                          & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)))));
        __Vtemp_211[2U] = (0x500000ccU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_211[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+153,(__Vtemp_211),100);
        __Vtemp_214[0U] = 0U;
        __Vtemp_214[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_214[2U] = (0x500000ccU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_214[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+157,(__Vtemp_214),100);
        __Vtemp_219[0U] = 0U;
        __Vtemp_219[1U] = (0x00c00000U ^ (0x80c00000U 
                                          & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)))));
        __Vtemp_219[2U] = (0x500000ddU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_219[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+161,(__Vtemp_219),100);
        __Vtemp_222[0U] = 0U;
        __Vtemp_222[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_222[2U] = (0x500000ddU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_222[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+165,(__Vtemp_222),100);
        __Vtemp_227[0U] = 0U;
        __Vtemp_227[1U] = (0x00c00000U ^ (0x80c00000U 
                                          & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)))));
        __Vtemp_227[2U] = (0x500000eeU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_227[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+169,(__Vtemp_227),100);
        __Vtemp_230[0U] = 0U;
        __Vtemp_230[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_230[2U] = (0x500000eeU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_230[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+173,(__Vtemp_230),100);
        __Vtemp_235[0U] = 0U;
        __Vtemp_235[1U] = (0x00c00000U ^ (0x80c00000U 
                                          & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)))));
        __Vtemp_235[2U] = (0x500000ffU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_235[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+177,(__Vtemp_235),100);
        __Vtemp_238[0U] = 0U;
        __Vtemp_238[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_238[2U] = (0x500000ffU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_238[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+181,(__Vtemp_238),100);
    }
    if (VL_UNLIKELY(((vlSelfRef.__Vm_traceActivity[6U] 
                      | vlSelfRef.__Vm_traceActivity[7U])))) {
        __Vtemp_245[0U] = 0U;
        __Vtemp_245[1U] = (0x00400002U ^ ((0xa8400002U 
                                           & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[1U]) 
                                          | (0x28400002U 
                                             & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[1U])));
        __Vtemp_245[2U] = ((0x0000000aU & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[2U]) 
                           | (0x20000002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[2U]));
        bufp->chgWData(oldp+185,(__Vtemp_245),96);
        __Vtemp_250[0U] = 0U;
        __Vtemp_250[1U] = ((0xa8400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[1U]) 
                           | (0x28400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[1U]));
        __Vtemp_250[2U] = ((0x0000000aU & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[2U]) 
                           | (0x20000002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[2U]));
        bufp->chgWData(oldp+188,(__Vtemp_250),96);
        __Vtemp_257[0U] = 0U;
        __Vtemp_257[1U] = (0x00400002U ^ ((0xb8400002U 
                                           & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[1U]) 
                                          | (0x38400002U 
                                             & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[1U])));
        __Vtemp_257[2U] = ((0x0000000bU & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[2U]) 
                           | (0x20000003U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[2U]));
        bufp->chgWData(oldp+191,(__Vtemp_257),96);
        __Vtemp_262[0U] = 0U;
        __Vtemp_262[1U] = ((0xb8400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[1U]) 
                           | (0x38400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[1U]));
        __Vtemp_262[2U] = ((0x0000000bU & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[2U]) 
                           | (0x20000003U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[2U]));
        bufp->chgWData(oldp+194,(__Vtemp_262),96);
        __Vtemp_269[0U] = 0U;
        __Vtemp_269[1U] = (0x00400002U ^ ((0x88400002U 
                                           & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[1U]) 
                                          | (0x08400002U 
                                             & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[1U])));
        __Vtemp_269[2U] = ((8U & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[2U]) 
                           | (0x20000000U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[2U]));
        bufp->chgWData(oldp+197,(__Vtemp_269),96);
        __Vtemp_274[0U] = 0U;
        __Vtemp_274[1U] = ((0x88400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[1U]) 
                           | (0x08400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[1U]));
        __Vtemp_274[2U] = ((8U & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[2U]) 
                           | (0x20000000U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[2U]));
        bufp->chgWData(oldp+200,(__Vtemp_274),96);
        __Vtemp_281[0U] = 0U;
        __Vtemp_281[1U] = (0x00400002U ^ ((0x98400002U 
                                           & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[1U]) 
                                          | (0x18400002U 
                                             & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[1U])));
        __Vtemp_281[2U] = ((9U & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[2U]) 
                           | (0x20000001U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[2U]));
        bufp->chgWData(oldp+203,(__Vtemp_281),96);
        __Vtemp_286[0U] = 0U;
        __Vtemp_286[1U] = ((0x98400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[1U]) 
                           | (0x18400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[1U]));
        __Vtemp_286[2U] = ((9U & vlSelfRef.__VdfgRegularize_hebeb780c_0_7[2U]) 
                           | (0x20000001U & vlSelfRef.__VdfgRegularize_hebeb780c_0_8[2U]));
        bufp->chgWData(oldp+206,(__Vtemp_286),96);
    }
    if (VL_UNLIKELY((vlSelfRef.__Vm_traceActivity[7U]))) {
        __Vtemp_333[24U] = ((((0x0000000cU ^ (0x0000000cU 
                                              & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                                 >> 0x00000014U))) 
                              | (((8U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                         >> 0x0000001cU)) 
                                  | (0x00000ff0U & 
                                     ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                      << 4U))) << 8U)) 
                             >> 0x00000010U) | ((0x00ff0000U 
                                                 & (((8U 
                                                      & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                                         >> 0x0000001cU)) 
                                                     | (0x00000ff0U 
                                                        & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                                           << 4U))) 
                                                    >> 8U)) 
                                                | (((5U 
                                                     & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                                        >> 0x0000001cU)) 
                                                    | (0x000000a0U 
                                                       & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
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
                                            >> 8U)) 
                            | (0x0a000000U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
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
                                     >> 0x0000001cU)) 
                              | (0x00000770U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
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
                                   >> 0x0000001cU)) 
                            | (0x00000990U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                              << 4U)));
        __Vtemp_358[31U] = ((5U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                   >> 0x0000001cU)) 
                            | (0x000000a0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
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
                                     >> 0x0000001cU)) 
                              | (0x00000bb0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                                << 4U))) 
                             >> 0x00000018U) | (((5U 
                                                  & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
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
                                     >> 0x0000001cU)) 
                              | (0x00000dd0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                                << 4U))) 
                             >> 0x00000010U) | (((5U 
                                                  & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                                     >> 0x0000001cU)) 
                                                 | (0x000000a0U 
                                                    & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                                       << 4U))) 
                                                << 0x00000010U));
        __Vtemp_358[44U] = (((5U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                    >> 0x0000001cU)) 
                             | (0x000000a0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                               << 4U))) 
                            >> 0x00000010U);
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
                                 | (0x00000ff0U & (
                                                   (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))) 
                                                   << 4U))) 
                                << 8U)) << 0x00000010U);
        __Vtemp_358[49U] = __Vtemp_333[24U];
        bufp->chgWData(oldp+209,(__Vtemp_358),1600);
        bufp->chgBit(oldp+259,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q));
        bufp->chgBit(oldp+260,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q));
        bufp->chgBit(oldp+261,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q));
        bufp->chgBit(oldp+262,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q));
        bufp->chgBit(oldp+263,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__DOT__meta));
        bufp->chgBit(oldp+264,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q));
        bufp->chgBit(oldp+265,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__DOT__meta));
        bufp->chgBit(oldp+266,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q));
        bufp->chgBit(oldp+267,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__DOT__meta));
        __Vtemp_363[0U] = 0U;
        __Vtemp_363[1U] = (0x00c00000U ^ (0x80c00000U 
                                          & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)))));
        __Vtemp_363[2U] = (0x500000aaU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_363[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+268,(__Vtemp_363),100);
        __Vtemp_366[0U] = 0U;
        __Vtemp_366[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_366[2U] = (0x500000aaU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_366[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+272,(__Vtemp_366),100);
        __Vtemp_371[0U] = 0U;
        __Vtemp_371[1U] = (0x00c00000U ^ (0x80c00000U 
                                          & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)))));
        __Vtemp_371[2U] = (0x500000bbU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_371[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+276,(__Vtemp_371),100);
        __Vtemp_374[0U] = 0U;
        __Vtemp_374[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_374[2U] = (0x500000bbU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_374[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+280,(__Vtemp_374),100);
        __Vtemp_379[0U] = 0U;
        __Vtemp_379[1U] = (0x00c00000U ^ (0x80c00000U 
                                          & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)))));
        __Vtemp_379[2U] = (0x500000ccU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_379[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+284,(__Vtemp_379),100);
        __Vtemp_382[0U] = 0U;
        __Vtemp_382[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_382[2U] = (0x500000ccU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_382[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+288,(__Vtemp_382),100);
        __Vtemp_387[0U] = 0U;
        __Vtemp_387[1U] = (0x00c00000U ^ (0x80c00000U 
                                          & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)))));
        __Vtemp_387[2U] = (0x500000ddU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_387[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+292,(__Vtemp_387),100);
        __Vtemp_390[0U] = 0U;
        __Vtemp_390[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_390[2U] = (0x500000ddU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_390[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+296,(__Vtemp_390),100);
        __Vtemp_395[0U] = 0U;
        __Vtemp_395[1U] = (0x00c00000U ^ (0x80c00000U 
                                          & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)))));
        __Vtemp_395[2U] = (0x500000eeU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_395[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+300,(__Vtemp_395),100);
        __Vtemp_398[0U] = 0U;
        __Vtemp_398[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_398[2U] = (0x500000eeU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_398[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+304,(__Vtemp_398),100);
        __Vtemp_403[0U] = 0U;
        __Vtemp_403[1U] = (0x00c00000U ^ (0x80c00000U 
                                          & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)))));
        __Vtemp_403[2U] = (0x500000ffU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_403[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+308,(__Vtemp_403),100);
        __Vtemp_406[0U] = 0U;
        __Vtemp_406[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_406[2U] = (0x500000ffU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_406[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+312,(__Vtemp_406),100);
        __Vtemp_411[0U] = 0U;
        __Vtemp_411[1U] = (0x00c00000U ^ (0x80c00000U 
                                          & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)))));
        __Vtemp_411[2U] = (0x50000044U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_411[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+316,(__Vtemp_411),100);
        __Vtemp_414[0U] = 0U;
        __Vtemp_414[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_414[2U] = (0x50000044U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_414[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+320,(__Vtemp_414),100);
        __Vtemp_419[0U] = 0U;
        __Vtemp_419[1U] = (0x00c00000U ^ (0x80c00000U 
                                          & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)))));
        __Vtemp_419[2U] = (0x50000055U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_419[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+324,(__Vtemp_419),100);
        __Vtemp_422[0U] = 0U;
        __Vtemp_422[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_422[2U] = (0x50000055U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_422[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+328,(__Vtemp_422),100);
        __Vtemp_427[0U] = 0U;
        __Vtemp_427[1U] = (0x00c00000U ^ (0x80c00000U 
                                          & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)))));
        __Vtemp_427[2U] = (0x50000066U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_427[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+332,(__Vtemp_427),100);
        __Vtemp_430[0U] = 0U;
        __Vtemp_430[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_430[2U] = (0x50000066U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_430[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+336,(__Vtemp_430),100);
        __Vtemp_435[0U] = 0U;
        __Vtemp_435[1U] = (0x00c00000U ^ (0x80c00000U 
                                          & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)))));
        __Vtemp_435[2U] = (0x50000077U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_435[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+340,(__Vtemp_435),100);
        __Vtemp_438[0U] = 0U;
        __Vtemp_438[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_438[2U] = (0x50000077U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_438[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+344,(__Vtemp_438),100);
        __Vtemp_443[0U] = 0U;
        __Vtemp_443[1U] = (0x00c00000U ^ (0x80c00000U 
                                          & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)))));
        __Vtemp_443[2U] = (0x50000088U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_443[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+348,(__Vtemp_443),100);
        __Vtemp_446[0U] = 0U;
        __Vtemp_446[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_446[2U] = (0x50000088U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_446[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+352,(__Vtemp_446),100);
        __Vtemp_451[0U] = 0U;
        __Vtemp_451[1U] = (0x00c00000U ^ (0x80c00000U 
                                          & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q)))));
        __Vtemp_451[2U] = (0x50000099U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_451[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+356,(__Vtemp_451),100);
        __Vtemp_454[0U] = 0U;
        __Vtemp_454[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_454[2U] = (0x50000099U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        __Vtemp_454[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+360,(__Vtemp_454),100);
    }
    if (VL_UNLIKELY(((vlSelfRef.__Vm_traceActivity[7U] 
                      | vlSelfRef.__Vm_traceActivity[8U])))) {
        __Vtemp_461[0U] = 0U;
        __Vtemp_461[1U] = (0x00400002U ^ ((0x08400002U 
                                           & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[1U]) 
                                          | (0x48400002U 
                                             & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[1U])));
        __Vtemp_461[2U] = ((0x10000000U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[2U]) 
                           | (4U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[2U]));
        bufp->chgWData(oldp+364,(__Vtemp_461),96);
        __Vtemp_466[0U] = 0U;
        __Vtemp_466[1U] = ((0x08400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[1U]) 
                           | (0x48400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[1U]));
        __Vtemp_466[2U] = ((0x10000000U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[2U]) 
                           | (4U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[2U]));
        bufp->chgWData(oldp+367,(__Vtemp_466),96);
        __Vtemp_473[0U] = 0U;
        __Vtemp_473[1U] = (0x00400002U ^ ((0x18400002U 
                                           & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[1U]) 
                                          | (0x58400002U 
                                             & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[1U])));
        __Vtemp_473[2U] = ((0x10000001U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[2U]) 
                           | (5U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[2U]));
        bufp->chgWData(oldp+370,(__Vtemp_473),96);
        __Vtemp_478[0U] = 0U;
        __Vtemp_478[1U] = ((0x18400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[1U]) 
                           | (0x58400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[1U]));
        __Vtemp_478[2U] = ((0x10000001U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[2U]) 
                           | (5U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[2U]));
        bufp->chgWData(oldp+373,(__Vtemp_478),96);
        __Vtemp_485[0U] = 0U;
        __Vtemp_485[1U] = (0x00400002U ^ ((0x28400002U 
                                           & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[1U]) 
                                          | (0x68400002U 
                                             & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[1U])));
        __Vtemp_485[2U] = ((0x10000002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[2U]) 
                           | (6U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[2U]));
        bufp->chgWData(oldp+376,(__Vtemp_485),96);
        __Vtemp_490[0U] = 0U;
        __Vtemp_490[1U] = ((0x28400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[1U]) 
                           | (0x68400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[1U]));
        __Vtemp_490[2U] = ((0x10000002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[2U]) 
                           | (6U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[2U]));
        bufp->chgWData(oldp+379,(__Vtemp_490),96);
        __Vtemp_497[0U] = 0U;
        __Vtemp_497[1U] = (0x00400002U ^ ((0x78400002U 
                                           & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[1U]) 
                                          | (0x38400002U 
                                             & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[1U])));
        __Vtemp_497[2U] = ((7U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[2U]) 
                           | (0x10000003U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[2U]));
        bufp->chgWData(oldp+382,(__Vtemp_497),96);
        __Vtemp_502[0U] = 0U;
        __Vtemp_502[1U] = ((0x78400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[1U]) 
                           | (0x38400002U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[1U]));
        __Vtemp_502[2U] = ((7U & vlSelfRef.__VdfgRegularize_hebeb780c_0_9[2U]) 
                           | (0x10000003U & vlSelfRef.__VdfgRegularize_hebeb780c_0_10[2U]));
        bufp->chgWData(oldp+385,(__Vtemp_502),96);
    }
    if (VL_UNLIKELY((vlSelfRef.__Vm_traceActivity[8U]))) {
        __Vtemp_525[0U] = 0U;
        __Vtemp_525[1U] = (0x00c00000U ^ (0x80c00000U 
                                          & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)))));
        __Vtemp_525[2U] = (0x50000044U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_525[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_525[4U] = (0x0c000000U ^ (0x0c000000U 
                                          & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                             << 4U)));
        __Vtemp_525[5U] = ((8U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                  >> 0x0000001cU)) 
                           | (0x00000550U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                             << 4U)));
        __Vtemp_525[6U] = ((5U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                  >> 0x0000001cU)) 
                           | (0x000000a0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                             << 4U)));
        __Vtemp_525[7U] = (0xc0000000U ^ (0xc0000000U 
                                          & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
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
                                     >> 0x0000001cU)) 
                              | (0x00000770U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                                << 4U))) 
                             >> 0x00000018U) | (((5U 
                                                  & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                                     >> 0x0000001cU)) 
                                                 | (0x000000a0U 
                                                    & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))) 
                                                       << 4U))) 
                                                << 8U));
        bufp->chgWData(oldp+388,(__Vtemp_525),400);
        bufp->chgBit(oldp+401,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q));
        bufp->chgBit(oldp+402,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q));
        bufp->chgBit(oldp+403,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__DOT__meta));
        __Vtemp_530[0U] = 0U;
        __Vtemp_530[1U] = (0x00c00000U ^ (0x80c00000U 
                                          & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)))));
        __Vtemp_530[2U] = (0x50000044U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_530[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+404,(__Vtemp_530),100);
        __Vtemp_533[0U] = 0U;
        __Vtemp_533[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_533[2U] = (0x50000044U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_533[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+408,(__Vtemp_533),100);
        __Vtemp_538[0U] = 0U;
        __Vtemp_538[1U] = (0x00c00000U ^ (0x80c00000U 
                                          & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)))));
        __Vtemp_538[2U] = (0x50000055U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_538[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+412,(__Vtemp_538),100);
        __Vtemp_541[0U] = 0U;
        __Vtemp_541[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_541[2U] = (0x50000055U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_541[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+416,(__Vtemp_541),100);
        __Vtemp_546[0U] = 0U;
        __Vtemp_546[1U] = (0x00c00000U ^ (0x80c00000U 
                                          & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)))));
        __Vtemp_546[2U] = (0x50000066U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_546[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+420,(__Vtemp_546),100);
        __Vtemp_549[0U] = 0U;
        __Vtemp_549[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_549[2U] = (0x50000066U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_549[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+424,(__Vtemp_549),100);
        __Vtemp_554[0U] = 0U;
        __Vtemp_554[1U] = (0x00c00000U ^ (0x80c00000U 
                                          & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q)))));
        __Vtemp_554[2U] = (0x50000077U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_554[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+428,(__Vtemp_554),100);
        __Vtemp_557[0U] = 0U;
        __Vtemp_557[1U] = (0x80c00000U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_557[2U] = (0x50000077U & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        __Vtemp_557[3U] = (0x0000000aU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q))));
        bufp->chgWData(oldp+432,(__Vtemp_557),100);
    }
    if (VL_UNLIKELY((vlSelfRef.__Vm_traceActivity[9U]))) {
        bufp->chgCData(oldp+436,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__en),2);
        bufp->chgBit(oldp+437,((1U & (~ (0U != (2U 
                                                & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__en)))))));
        bufp->chgBit(oldp+438,((1U & (~ (0U != (1U 
                                                & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__en)))))));
    }
    if (VL_UNLIKELY((vlSelfRef.__Vm_traceActivity[10U]))) {
        bufp->chgCData(oldp+439,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__en),3);
        bufp->chgBit(oldp+440,((1U & (~ (0U != (6U 
                                                & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__en)))))));
        bufp->chgBit(oldp+441,((1U & (~ (0U != (5U 
                                                & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__en)))))));
        bufp->chgBit(oldp+442,((1U & (~ (0U != (3U 
                                                & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__en)))))));
    }
    if (VL_UNLIKELY((vlSelfRef.__Vm_traceActivity[11U]))) {
        bufp->chgCData(oldp+443,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__en),2);
        bufp->chgBit(oldp+444,((1U & (~ (0U != (2U 
                                                & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__en)))))));
        bufp->chgBit(oldp+445,((1U & (~ (0U != (1U 
                                                & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__en)))))));
    }
    if (VL_UNLIKELY((vlSelfRef.__Vm_traceActivity[12U]))) {
        bufp->chgWData(oldp+446,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy),1536);
        bufp->chgCData(oldp+494,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__sel_tgt),7);
    }
    bufp->chgSData(oldp+495,(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out),16);
    bufp->chgCData(oldp+496,(vlSelfRef.tb_pipe_lane_mapper__DOT__mode),2);
    bufp->chgCData(oldp+497,(((8U & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                                     >> 9U)) | ((4U 
                                                 & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                                                    >> 6U)) 
                                                | (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__branch_clk)))),4);
    bufp->chgSData(oldp+498,(((((0x000000f0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__pclk_in_g3))) 
                                                << 4U)) 
                                | (0x0000000fU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__pclk_in_g2))))) 
                               << 8U) | ((0x000000f0U 
                                          & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__pclk_in_g1))) 
                                             << 4U)) 
                                         | (0x0000000fU 
                                            & (- (IData)(
                                                         (1U 
                                                          & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out)))))))),16);
    bufp->chgSData(oldp+499,(((((0x000000f0U & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__u_rst_g3__DOT__dout))) 
                                                << 4U)) 
                                | (0x0000000fU & (- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__u_rst_g2__DOT__dout))))) 
                               << 8U) | ((0x000000f0U 
                                          & ((- (IData)((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__u_rst_g1__DOT__dout))) 
                                             << 4U)) 
                                         | (0x0000000fU 
                                            & (- (IData)(
                                                         (1U 
                                                          & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__ctrl_rst_n)))))))),16);
    bufp->chgIData(oldp+500,(vlSelfRef.tb_pipe_lane_mapper__DOT__err_count),32);
    bufp->chgCData(oldp+501,(((0x1ffffffeU & (((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g1_b1__DOT__en_latched) 
                                               << 1U) 
                                              & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                                                 >> 3U))) 
                              | ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g1_b0__DOT__en_latched) 
                                 & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out)))),2);
    bufp->chgBit(oldp+502,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__pclk_in_g1));
    bufp->chgCData(oldp+503,(((0x01fffffeU & (((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g2_b1__DOT__en_latched) 
                                               << 1U) 
                                              & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                                                 >> 7U))) 
                              | ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g2_b0__DOT__en_latched) 
                                 & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out)))),2);
    bufp->chgBit(oldp+504,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__pclk_in_g2));
    bufp->chgCData(oldp+505,(((0x003ffffcU & (((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g3_b2__DOT__en_latched) 
                                               << 2U) 
                                              & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                                                 >> 0x0000000aU))) 
                              | ((0x01fffffeU & (((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g3_b1__DOT__en_latched) 
                                                  << 1U) 
                                                 & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                                                    >> 7U))) 
                                 | ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g3_b0__DOT__en_latched) 
                                    & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out))))),3);
    bufp->chgBit(oldp+506,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__pclk_in_g3));
    bufp->chgBit(oldp+507,((1U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out))));
    bufp->chgBit(oldp+508,(((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g1_b0__DOT__en_latched) 
                            & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out))));
    bufp->chgBit(oldp+509,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g1_b0__DOT__en_latched));
    bufp->chgBit(oldp+510,((1U & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                                  >> 4U))));
    bufp->chgBit(oldp+511,(((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g1_b1__DOT__en_latched) 
                            & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                               >> 4U))));
    bufp->chgBit(oldp+512,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g1_b1__DOT__en_latched));
    bufp->chgBit(oldp+513,(((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g2_b0__DOT__en_latched) 
                            & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out))));
    bufp->chgBit(oldp+514,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g2_b0__DOT__en_latched));
    bufp->chgBit(oldp+515,((1U & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                                  >> 8U))));
    bufp->chgBit(oldp+516,(((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g2_b1__DOT__en_latched) 
                            & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                               >> 8U))));
    bufp->chgBit(oldp+517,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g2_b1__DOT__en_latched));
    bufp->chgBit(oldp+518,(((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g3_b0__DOT__en_latched) 
                            & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out))));
    bufp->chgBit(oldp+519,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g3_b0__DOT__en_latched));
    bufp->chgBit(oldp+520,(((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g3_b1__DOT__en_latched) 
                            & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                               >> 8U))));
    bufp->chgBit(oldp+521,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g3_b1__DOT__en_latched));
    bufp->chgBit(oldp+522,((1U & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                                  >> 0x0000000cU))));
    bufp->chgBit(oldp+523,(((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g3_b2__DOT__en_latched) 
                            & ((IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__phy_pclk_out) 
                               >> 0x0000000cU))));
    bufp->chgBit(oldp+524,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g3_b2__DOT__en_latched));
    bufp->chgBit(oldp+525,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__tgt_r));
    bufp->chgBit(oldp+526,(((~ (0U != (2U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__en)))) 
                            & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__tgt_r))));
    bufp->chgBit(oldp+527,(((~ (0U != (2U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__en)))) 
                            & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__tgt_r))));
    bufp->chgBit(oldp+528,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__tgt_r));
    bufp->chgBit(oldp+529,(((~ (0U != (1U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__en)))) 
                            & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__tgt_r))));
    bufp->chgBit(oldp+530,(((~ (0U != (1U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__en)))) 
                            & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__tgt_r))));
    bufp->chgBit(oldp+531,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__tgt_r));
    bufp->chgBit(oldp+532,(((~ (0U != (2U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__en)))) 
                            & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__tgt_r))));
    bufp->chgBit(oldp+533,(((~ (0U != (2U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__en)))) 
                            & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__tgt_r))));
    bufp->chgBit(oldp+534,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__tgt_r));
    bufp->chgBit(oldp+535,(((~ (0U != (1U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__en)))) 
                            & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__tgt_r))));
    bufp->chgBit(oldp+536,(((~ (0U != (1U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__en)))) 
                            & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__tgt_r))));
    bufp->chgBit(oldp+537,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__tgt_r));
    bufp->chgBit(oldp+538,(((~ (0U != (6U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__en)))) 
                            & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__tgt_r))));
    bufp->chgBit(oldp+539,(((~ (0U != (6U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__en)))) 
                            & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__tgt_r))));
    bufp->chgBit(oldp+540,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__tgt_r));
    bufp->chgBit(oldp+541,(((~ (0U != (5U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__en)))) 
                            & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__tgt_r))));
    bufp->chgBit(oldp+542,(((~ (0U != (5U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__en)))) 
                            & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__tgt_r))));
    bufp->chgBit(oldp+543,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__2__KET____DOT__tgt_r));
    bufp->chgBit(oldp+544,(((~ (0U != (3U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__en)))) 
                            & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__2__KET____DOT__tgt_r))));
    bufp->chgBit(oldp+545,(((~ (0U != (3U & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__en)))) 
                            & (IData)(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__2__KET____DOT__tgt_r))));
    bufp->chgBit(oldp+546,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__u_rst_g1__DOT__dout));
    bufp->chgBit(oldp+547,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__u_rst_g2__DOT__dout));
    bufp->chgBit(oldp+548,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__u_rst_g3__DOT__dout));
    bufp->chgBit(oldp+549,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__u_rst_g1__DOT__dout));
    bufp->chgBit(oldp+550,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__u_rst_g2__DOT__dout));
    bufp->chgBit(oldp+551,(vlSelfRef.tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__u_rst_g3__DOT__dout));
    bufp->chgIData(oldp+552,(vlSelfRef.tb_pipe_lane_mapper__DOT__unnamedblk15__DOT__unnamedblk16__DOT__pulse_cid),32);
    bufp->chgBit(oldp+553,(vlSelfRef.tb_pipe_lane_mapper__DOT__unnamedblk15__DOT__unnamedblk16__DOT__unnamedblk17__DOT__unnamedblk18__DOT__expect_low));
}

void Vtb_pipe_lane_mapper___024root__trace_cleanup(void* voidSelf, VerilatedVcd* /*unused*/) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_pipe_lane_mapper___024root__trace_cleanup\n"); );
    // Body
    Vtb_pipe_lane_mapper___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtb_pipe_lane_mapper___024root*>(voidSelf);
    Vtb_pipe_lane_mapper__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    vlSymsp->__Vm_activity = false;
    vlSymsp->TOP.__Vm_traceActivity[0U] = 0U;
    vlSymsp->TOP.__Vm_traceActivity[1U] = 0U;
    vlSymsp->TOP.__Vm_traceActivity[2U] = 0U;
    vlSymsp->TOP.__Vm_traceActivity[3U] = 0U;
    vlSymsp->TOP.__Vm_traceActivity[4U] = 0U;
    vlSymsp->TOP.__Vm_traceActivity[5U] = 0U;
    vlSymsp->TOP.__Vm_traceActivity[6U] = 0U;
    vlSymsp->TOP.__Vm_traceActivity[7U] = 0U;
    vlSymsp->TOP.__Vm_traceActivity[8U] = 0U;
    vlSymsp->TOP.__Vm_traceActivity[9U] = 0U;
    vlSymsp->TOP.__Vm_traceActivity[10U] = 0U;
    vlSymsp->TOP.__Vm_traceActivity[11U] = 0U;
    vlSymsp->TOP.__Vm_traceActivity[12U] = 0U;
}
