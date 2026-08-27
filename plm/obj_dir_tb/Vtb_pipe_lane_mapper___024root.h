// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vtb_pipe_lane_mapper.h for the primary calling header

#ifndef VERILATED_VTB_PIPE_LANE_MAPPER___024ROOT_H_
#define VERILATED_VTB_PIPE_LANE_MAPPER___024ROOT_H_  // guard

#include "verilated.h"
#include "verilated_timing.h"


class Vtb_pipe_lane_mapper__Syms;

class alignas(VL_CACHE_LINE_BYTES) Vtb_pipe_lane_mapper___024root final {
  public:

    // DESIGN SPECIFIC STATE
    // Anonymous structures to workaround compiler member-count bugs
    struct {
        CData/*3:0*/ tb_pipe_lane_mapper__DOT__ctrl_rst_n;
        CData/*1:0*/ tb_pipe_lane_mapper__DOT__mode;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__unnamedblk15__DOT__unnamedblk16__DOT__unnamedblk17__DOT__unnamedblk18__DOT__expect_low;
        CData/*6:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__sel_tgt;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__pclk_in_g1;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__pclk_in_g2;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__pclk_in_g3;
        CData/*2:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__branch_clk;
        CData/*2:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__branch_rst_n;
        CData/*2:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__en;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__tgt_r;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__tgt_r;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__2__KET____DOT__tgt_r;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__DOT__meta;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__DOT__meta;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__DOT__meta;
        CData/*1:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__branch_clk;
        CData/*1:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__branch_rst_n;
        CData/*1:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__en;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__tgt_r;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__tgt_r;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__DOT__meta;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__DOT__meta;
        CData/*1:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__branch_clk;
        CData/*1:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__en;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__tgt_r;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__tgt_r;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__DOT__meta;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__DOT__meta;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g3_b2__DOT__en_latched;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g3_b1__DOT__en_latched;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g3_b0__DOT__en_latched;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g2_b1__DOT__en_latched;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g2_b0__DOT__en_latched;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g1_b1__DOT__en_latched;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_pin_gate_g1_b0__DOT__en_latched;
        CData/*6:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_decoder__DOT__sel_tgt;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__u_rst_g2__DOT__dout;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__u_rst_g1__DOT__dout;
        CData/*0:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__u_rst_g3__DOT__dout;
        CData/*0:0*/ __Vtask_tb_pipe_lane_mapper__DOT__chk__92__ok;
        CData/*0:0*/ __Vtask_tb_pipe_lane_mapper__DOT__chk__93__ok;
        CData/*0:0*/ __Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__tgt_r;
        CData/*0:0*/ __Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__tgt_r;
        CData/*0:0*/ __Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__2__KET____DOT__tgt_r;
        CData/*0:0*/ __Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__DOT__meta;
        CData/*0:0*/ __Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__2__KET____DOT__u_sync_en__q;
        CData/*0:0*/ __Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__DOT__meta;
        CData/*0:0*/ __Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q;
        CData/*0:0*/ __Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__DOT__meta;
        CData/*0:0*/ __Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g3__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q;
        CData/*0:0*/ __Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__tgt_r;
        CData/*0:0*/ __Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__tgt_r;
        CData/*0:0*/ __Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__DOT__meta;
        CData/*0:0*/ __Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q;
        CData/*0:0*/ __Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__DOT__meta;
        CData/*0:0*/ __Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g2__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q;
    };
    struct {
        CData/*0:0*/ __Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__tgt_r;
        CData/*0:0*/ __Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__tgt_r;
        CData/*0:0*/ __Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__DOT__meta;
        CData/*0:0*/ __Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__1__KET____DOT__u_sync_en__q;
        CData/*0:0*/ __Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__DOT__meta;
        CData/*0:0*/ __Vdly__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__u_sel_sync_g1__DOT____Vcellout__g_sync__DOT__g_branch__BRA__0__KET____DOT__u_sync_en__q;
        CData/*0:0*/ __VstlFirstIteration;
        CData/*0:0*/ __VstlPhaseResult;
        CData/*0:0*/ __Vtrigprevexpr_h8385d5c9__0;
        CData/*0:0*/ __Vtrigprevexpr_h372891da__0;
        CData/*0:0*/ __Vtrigprevexpr_h8385cf81__0;
        CData/*0:0*/ __Vtrigprevexpr_h37287ca2__0;
        CData/*0:0*/ __Vtrigprevexpr_h8385d64b__0;
        CData/*0:0*/ __Vtrigprevexpr_h37289568__0;
        CData/*0:0*/ __Vtrigprevexpr_h4fd220d6__0;
        CData/*0:0*/ __Vtrigprevexpr_h3c9f729d__0;
        CData/*0:0*/ __Vtrigprevexpr_h4fd22095__0;
        CData/*0:0*/ __Vtrigprevexpr_h3c9f779e__0;
        CData/*0:0*/ __Vtrigprevexpr_h4fd2200b__0;
        CData/*0:0*/ __Vtrigprevexpr_h3c9eb7c8__0;
        CData/*0:0*/ __Vtrigprevexpr_hd9e332bd__0;
        CData/*0:0*/ __Vtrigprevexpr_hc2cd7bff__0;
        CData/*0:0*/ __Vtrigprevexpr_hd9e31e8d__0;
        CData/*0:0*/ __Vtrigprevexpr_hc2cd7acf__0;
        CData/*0:0*/ __Vtrigprevexpr_h76fca2d2__0;
        CData/*0:0*/ __Vtrigprevexpr_h4fd2204c__0;
        CData/*0:0*/ __Vtrigprevexpr_h76fca402__0;
        CData/*0:0*/ __Vtrigprevexpr_h3c9eacc7__0;
        CData/*6:0*/ __Vtrigprevexpr___TOP__tb_pipe_lane_mapper__DOT__dut__DOT__u_clk_top__DOT__sel_tgt__0;
        CData/*0:0*/ __VactPhaseResult;
        CData/*0:0*/ __VinactPhaseResult;
        CData/*0:0*/ __VnbaPhaseResult;
        SData/*15:0*/ tb_pipe_lane_mapper__DOT__phy_pclk_out;
        SData/*15:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_rst_top__DOT__phy_rst_n;
        IData/*31:0*/ tb_pipe_lane_mapper__DOT____VlemCall_6__owner_of;
        IData/*31:0*/ tb_pipe_lane_mapper__DOT____VlemCall_5__owner_of;
        IData/*31:0*/ tb_pipe_lane_mapper__DOT__err_count;
        IData/*31:0*/ tb_pipe_lane_mapper__DOT__unnamedblk15__DOT__unnamedblk16__DOT__pulse_cid;
        IData/*31:0*/ __Vtask_tb_pipe_lane_mapper__DOT__check_mode__44__m;
        IData/*31:0*/ __Vtask_tb_pipe_lane_mapper__DOT__check_mode__44__unnamedblk10__DOT__c;
        IData/*31:0*/ __Vtask_tb_pipe_lane_mapper__DOT__check_mode__88__m;
        IData/*31:0*/ __Vtask_tb_pipe_lane_mapper__DOT__check_mode__88__cid;
        IData/*31:0*/ __Vtask_tb_pipe_lane_mapper__DOT__check_mode__88__port;
        IData/*31:0*/ __Vfunc_tb_pipe_lane_mapper__DOT__owner_of__89__Vfuncout;
        IData/*31:0*/ __Vfunc_tb_pipe_lane_mapper__DOT__owner_of__89__m;
        IData/*31:0*/ __Vfunc_tb_pipe_lane_mapper__DOT__port_of__90__Vfuncout;
        IData/*31:0*/ __Vfunc_tb_pipe_lane_mapper__DOT__port_of__90__m;
        IData/*31:0*/ __Vfunc_tb_pipe_lane_mapper__DOT__make_m2p__91__cid;
        IData/*31:0*/ __Vfunc_tb_pipe_lane_mapper__DOT__make_m2p__91__port;
        VlWide<3>/*95:0*/ __VdfgRegularize_hebeb780c_0_7;
        VlWide<3>/*95:0*/ __VdfgRegularize_hebeb780c_0_8;
        VlWide<3>/*95:0*/ __VdfgRegularize_hebeb780c_0_9;
        VlWide<3>/*95:0*/ __VdfgRegularize_hebeb780c_0_10;
        VlWide<3>/*95:0*/ __VdfgRegularize_hebeb780c_0_11;
        VlWide<3>/*95:0*/ __VdfgRegularize_hebeb780c_0_12;
        VlWide<3>/*95:0*/ __VdfgRegularize_hebeb780c_0_13;
        IData/*31:0*/ __VactIterCount;
        IData/*31:0*/ __VinactIterCount;
        IData/*31:0*/ __Vi;
        VlWide<48>/*1535:0*/ tb_pipe_lane_mapper__DOT__dut__DOT__u_data_m2p__DOT__phy_mac2phy;
        VlWide<4>/*99:0*/ __Vtask_tb_pipe_lane_mapper__DOT__check_mode__44__exp_p2m;
        VlWide<3>/*95:0*/ __Vtask_tb_pipe_lane_mapper__DOT__check_mode__88__exp_m2p;
        VlWide<4>/*99:0*/ __Vtask_tb_pipe_lane_mapper__DOT__check_mode__88__exp_p2m;
        VlWide<3>/*95:0*/ __Vfunc_tb_pipe_lane_mapper__DOT__make_m2p__91__Vfuncout;
    };
    struct {
        VlWide<3>/*95:0*/ __Vfunc_tb_pipe_lane_mapper__DOT__make_m2p__91__v;
        VlUnpacked<QData/*63:0*/, 1> __VstlTriggered;
        VlUnpacked<QData/*63:0*/, 3> __VactTriggered;
        VlUnpacked<QData/*63:0*/, 2> __VactTriggeredAcc;
        VlUnpacked<QData/*63:0*/, 2> __VnbaTriggered;
        VlUnpacked<CData/*0:0*/, 13> __Vm_traceActivity;
    };
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__5__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__6__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__7__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__15__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__16__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__19__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__21__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__26__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__27__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__30__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__32__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__37__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__38__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__41__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__43__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__48__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__49__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__52__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__54__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__59__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__60__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__63__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__65__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__70__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__71__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__74__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__76__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__81__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__82__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__85__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__87__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__92__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__93__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__96__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__98__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__101__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__106__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__107__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__110__msg;
    std::string __Vtask_tb_pipe_lane_mapper__DOT__chk__112__msg;
    VlDelayScheduler __VdlySched;

    // INTERNAL VARIABLES
    Vtb_pipe_lane_mapper__Syms* vlSymsp;
    const char* vlNamep;

    // PARAMETERS
    static constexpr VlUnpacked<IData/*31:0*/, 16> tb_pipe_lane_mapper__DOT__PERIOD_NS = {{
        6U, 3U, 4U, 5U,
        0x0000000aU, 7U, 8U, 9U,
        0x0000000eU, 0x0000000bU, 0x0000000cU, 0x0000000dU,
        0x00000012U, 0x0000000fU, 0x00000010U, 0x00000011U
    }};
    static constexpr VlUnpacked<IData/*31:0*/, 4> tb_pipe_lane_mapper__DOT__G1_LANES = {{
        4U, 5U, 6U, 7U
    }};
    static constexpr VlUnpacked<IData/*31:0*/, 4> tb_pipe_lane_mapper__DOT__G2_LANES = {{
        8U, 9U, 0x0000000aU, 0x0000000bU
    }};
    static constexpr VlUnpacked<IData/*31:0*/, 4> tb_pipe_lane_mapper__DOT__G3_LANES = {{
        0x0000000cU, 0x0000000dU, 0x0000000eU, 0x0000000fU
    }};

    // CONSTRUCTORS
    Vtb_pipe_lane_mapper___024root(Vtb_pipe_lane_mapper__Syms* symsp, const char* namep);
    ~Vtb_pipe_lane_mapper___024root();
    VL_UNCOPYABLE(Vtb_pipe_lane_mapper___024root);

    // INTERNAL METHODS
    void __Vconfigure(bool first);
};


#endif  // guard
