// ------------------------------------------------------------------------------
// 
// Copyright 2002 - 2024 Synopsys, INC.
// 
// This Synopsys IP and all associated documentation are proprietary to
// Synopsys, Inc. and may only be used pursuant to the terms and conditions of a
// written license agreement with Synopsys, Inc. All other use, reproduction,
// modification, or distribution of the Synopsys IP or the associated
// documentation is strictly prohibited.
// Inclusivity & Diversity - Visit SolvNetPlus to read the "Synopsys Statement on
//            Inclusivity and Diversity" (Refer to article 000036315 at
//                        https://solvnetplus.synopsys.com)
// 
// Component Name   : DWC_pcie_ctl_cxl
// Component Version: 6.14a-lca02
// Release Type     : LCA
// Build ID         : 69.19.33.11.PCIeParseConfig_1.PCIeSimulate_24.PCIeTbCommon_85.SNPSPHYSetup_21
// ------------------------------------------------------------------------------

// -------------------------------------------------------------------------
// ---  RCS information:
// ---    $DateTime: 2024/01/12 11:11:14 $
// ---    $Revision: #13 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_atu_ctrl.sv#13 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the registers for the integrated ATU
// --- Address translation ranges are defined by the base and limit registers
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_atu_ctrl(
// ------------ Inputs ---------------
    core_clk,
    sticky_rst_n,
    cdm_clk_g,
    lbc_cdm_data,
    atu_ctrl_write_pulse,
    lbc_cdm_addr,
    atu_reg_sel,
// ------------ Outputs --------------
    atu_ctrl_reg_data,

// ATU outbound Region controls
    atu_reg_out_type,
    atu_reg_out_tc,
    atu_reg_out_td,
    atu_reg_out_attr,
    atu_reg_out_at,
    atu_reg_out_func_num,
    atu_reg_out_func_bypass,
    atu_reg_out_snp,
    atu_reg_out_dma_bypass,
    atu_reg_out_inhibit_payload,
    atu_reg_out_hdr_substitute_en,
    atu_reg_out_tag_substitute_en,
    atu_reg_out_tag,
    atu_reg_out_msg_code,
    atu_reg_out_th,
    atu_reg_out_ph,
    atu_reg_out_st,
// Mode Settings
    atu_reg_out_shift,
    atu_reg_out_invert,
// Region Enable
    atu_reg_out_en,
// Base, Limit and Target Registers
    atu_reg_out_base,
    atu_reg_out_upr_base,
    atu_reg_out_limit,
    atu_reg_out_uppr_limit,
    atu_reg_out_lwr_trgt,
    atu_reg_out_upr_trgt,
    atu_reg_out_lwr_trgt_lwr,
    atu_reg_out_incr_rgn_size,
    atu_reg_out_hdr_flds_bypass,

// ATU inbound Region controls
    atu_reg_in_type,
    atu_reg_in_tc,
    atu_reg_in_td,
    atu_reg_in_attr,
    atu_reg_in_at,
    atu_reg_in_func_num,
    atu_reg_in_msg_code,
    atu_reg_in_bar_num,
    atu_reg_in_th,
    atu_reg_in_ph,
    atu_reg_in_st,
// Inbound field match enables
    atu_reg_in_tc_match_en,
    atu_reg_in_td_match_en,
    atu_reg_in_attr_match_en,
    atu_reg_in_at_match_en,
    atu_reg_in_func_match_en,
    atu_reg_in_msgcode_match_en,
    atu_reg_in_th_match_en,
    atu_reg_in_ph_match_en,
    atu_reg_in_st_match_en,
    atu_reg_in_single_addr_loc_en,
    atu_reg_in_msg_type_match_mode,
// Response and mode settings
    atu_reg_in_rsp_code,
    atu_reg_in_fuzzy,
    atu_reg_in_shift,
    atu_reg_in_invert,
    atu_reg_in_bar_match,
// Region Enable
    atu_reg_in_en,
// Base, Limit and Target Registers
    atu_reg_in_base,
    atu_reg_in_upr_base,
    atu_reg_in_limit,
    atu_reg_in_cbuf_incr,
    atu_reg_in_cbuf_restart,
    atu_reg_in_uppr_limit,
    atu_reg_in_lwr_trgt,
    atu_reg_in_upr_trgt,
    atu_reg_in_incr_rgn_size
);

// LMD: Range index out of bound
// LJ: Triggers Bogus Leda Error. This func is only used in parameter calculation.
// leda E267 off
function automatic integer log2floor;
    input integer value;
    begin
        log2floor = 1;

        // LMD: Illegal statement for synthesis
        // LJ: Triggers Bogus Leda Error. This func is only used in parameter calculation.
        // leda W182 off

        while(1<<log2floor < value)

        // leda W182 on

            log2floor = log2floor + 1;
    end
endfunction

localparam DATA_DELAY_BCM36_NHS = 3;  // Type of random delay to be added to signal in simulation by bcm36_nhs

parameter INST  = 0;  // The uniquifying parameter for each port logic instance.
parameter ATU_OUT_REGIONS = 2;
parameter ATU_IN_REGIONS = 2;
// Size of upper base and target registers
parameter ATU_BASE_WD = 32;
// Size of lower base, limit and target registers
parameter ATU_REG_WD = 16;
parameter ATU_CTRL_REG_ID_WD = 10;
parameter TP    = `TP;// Clock to Q delay (simulator insurance)
localparam ATU_IN_LESS_OUT_REGIONS = ATU_IN_REGIONS > ATU_OUT_REGIONS ? (ATU_IN_REGIONS - ATU_OUT_REGIONS) : 1;
// Used to prevent setting of application side upper address registers in 32
// bit system
localparam IN64 = `AMBA_INTERFACE != 0 ? `MASTER_BUS_ADDR_WIDTH > 32 :
    `FLT_Q_ADDR_WIDTH > 32;

// Be nice to lint tools when 0 REGIONS are set(IN|OUT not both)
localparam ATU_OUT_MIN1 = ATU_OUT_REGIONS > 0 ? ATU_OUT_REGIONS : 1;
localparam ATU_IN_MIN1 = ATU_IN_REGIONS > 0 ? ATU_IN_REGIONS : 1;
// max(ATU_OUT_REGIONS,ATU_IN_REGIONS)
localparam ATU_MAX_REGIONS = ATU_IN_REGIONS > ATU_OUT_REGIONS ?
    ATU_IN_REGIONS : ATU_OUT_REGIONS;
// LOG2 ATU_MAX_REGIONS. Used for bitwidth, of viewport register
localparam ATU_LOG2_REGIONS = log2floor(ATU_MAX_REGIONS);

parameter PF_WD         = `CX_NFUNC_WD;             // number of bits needed to represent the pf number [0..NF-1], when this block is configured for sriov it is calculated as log2(NF), hardcoded to 3 otherwise
localparam ATTR_WD = `FLT_Q_ATTR_WIDTH;

localparam ATU_REG_LWR_WD = 32-ATU_REG_WD;     // width of lower address register which are not hardwired.
parameter ATU_UPR_LMT_WD = `CX_ATU_MAX_REGION_SIZE;        // Width of Upper Limit Address register

localparam TAG_SIZE = `CX_TAG_SIZE;

// ----- Inputs ---------------
input            core_clk;                       // Core clock
input            sticky_rst_n;     // Reset for non-sticky registers
input            cdm_clk_g;                   // gated version of the aux_clk_g, based on access activity to cdm, enable signal comes from lbc
input     [31:0] lbc_cdm_data;                   // Write Data
input     [3:0]  atu_ctrl_write_pulse;           // Write Data Byte Enables
input     [31:0] lbc_cdm_addr;
input            atu_reg_sel;
// ---------- Outputs --------
output    [31:0]                atu_ctrl_reg_data;   // ATU register read data

// ATU outbound Region controls
output    [5*ATU_OUT_MIN1-1:0]              atu_reg_out_type;
output    [3*ATU_OUT_MIN1-1:0]              atu_reg_out_tc;
output    [ATU_OUT_MIN1-1:0]                atu_reg_out_td;
output    [ATTR_WD*ATU_OUT_MIN1-1:0]        atu_reg_out_attr;
output    [2*ATU_OUT_MIN1-1:0]              atu_reg_out_at;
output    [PF_WD*ATU_OUT_MIN1-1:0]          atu_reg_out_func_num;
output    [ATU_OUT_MIN1-1:0]                atu_reg_out_func_bypass;
output    [ATU_OUT_MIN1-1:0]                atu_reg_out_snp;
output    [ATU_OUT_MIN1-1:0]                atu_reg_out_dma_bypass;
output    [ATU_OUT_MIN1-1:0]                atu_reg_out_inhibit_payload;
output    [ATU_OUT_MIN1-1:0]                atu_reg_out_hdr_substitute_en;
output    [ATU_OUT_MIN1-1:0]                atu_reg_out_tag_substitute_en;
output    [TAG_SIZE*ATU_OUT_MIN1-1:0]       atu_reg_out_tag;
output    [8*ATU_OUT_MIN1-1:0]              atu_reg_out_msg_code;
output    [ATU_OUT_MIN1-1:0]                atu_reg_out_th;
output    [2*ATU_OUT_MIN1-1:0]              atu_reg_out_ph;
output    [8*ATU_OUT_MIN1-1:0]              atu_reg_out_st;
// Mode Settings
output    [ATU_OUT_MIN1-1:0]                atu_reg_out_shift;
output    [ATU_OUT_MIN1-1:0]                atu_reg_out_invert;
// Region Enable
output    [ATU_OUT_MIN1-1:0]                atu_reg_out_en;
// Base, Limit and Target Registers
output    [ATU_REG_WD*ATU_OUT_MIN1-1:0]     atu_reg_out_base;
output    [ATU_BASE_WD*ATU_OUT_MIN1-1:0]    atu_reg_out_upr_base;
output    [ATU_REG_WD*ATU_OUT_MIN1-1:0]     atu_reg_out_limit;
output    [ATU_UPR_LMT_WD*ATU_OUT_MIN1-1:0] atu_reg_out_uppr_limit;
output    [ATU_REG_WD*ATU_OUT_MIN1-1:0]     atu_reg_out_lwr_trgt;
output    [ATU_BASE_WD*ATU_OUT_MIN1-1:0]    atu_reg_out_upr_trgt;
output    [ATU_REG_LWR_WD*ATU_OUT_MIN1-1:0] atu_reg_out_lwr_trgt_lwr;
output    [ATU_OUT_MIN1-1:0]                atu_reg_out_incr_rgn_size;    // Maximum region size control bit
output    [ATU_OUT_MIN1-1:0]                atu_reg_out_hdr_flds_bypass;  // TLP Header fields bypass control bit

// ATU inbound Region controls
output    [5*ATU_IN_MIN1 -1:0]              atu_reg_in_type;
output    [3*ATU_IN_MIN1 -1:0]              atu_reg_in_tc;
output    [ATU_IN_MIN1 -1:0]                atu_reg_in_td;
output    [ATTR_WD*ATU_IN_MIN1 -1:0]        atu_reg_in_attr;
output    [2*ATU_IN_MIN1 -1:0]              atu_reg_in_at;
output    [PF_WD*ATU_IN_MIN1 -1:0]          atu_reg_in_func_num;
output    [8*ATU_IN_MIN1 -1:0]              atu_reg_in_msg_code;
output    [3*ATU_IN_MIN1 -1:0]              atu_reg_in_bar_num;
output    [ATU_IN_MIN1-1:0]                 atu_reg_in_th;
output    [2*ATU_IN_MIN1-1:0]               atu_reg_in_ph;
output    [8*ATU_IN_MIN1-1:0]               atu_reg_in_st;
// Inbound field match enables
output    [ATU_IN_MIN1 -1:0]                atu_reg_in_tc_match_en;
output    [ATU_IN_MIN1 -1:0]                atu_reg_in_td_match_en;
output    [ATU_IN_MIN1 -1:0]                atu_reg_in_attr_match_en;
output    [ATU_IN_MIN1 -1:0]                atu_reg_in_at_match_en;
output    [ATU_IN_MIN1 -1:0]                atu_reg_in_func_match_en;
output    [ATU_IN_MIN1 -1:0]                atu_reg_in_msgcode_match_en;
output    [ATU_IN_MIN1 -1:0]                atu_reg_in_th_match_en;
output    [ATU_IN_MIN1 -1:0]                atu_reg_in_ph_match_en;
output    [ATU_IN_MIN1 -1:0]                atu_reg_in_st_match_en;
output    [ATU_IN_MIN1 -1:0]                atu_reg_in_single_addr_loc_en;
output    [ATU_IN_MIN1 -1:0]                atu_reg_in_msg_type_match_mode;
// Response and mode settings
output    [2*ATU_IN_MIN1 -1:0]              atu_reg_in_rsp_code;
output    [ATU_IN_MIN1 -1:0]                atu_reg_in_fuzzy;
output    [ATU_IN_MIN1 -1:0]                atu_reg_in_shift;
output    [ATU_IN_MIN1 -1:0]                atu_reg_in_invert;
output    [ATU_IN_MIN1 -1:0]                atu_reg_in_bar_match;
// Region Enable
output    [ATU_IN_MIN1 -1:0]                atu_reg_in_en;
// Base, Limit and Target Registers
output    [ATU_REG_WD*ATU_IN_MIN1 -1:0]     atu_reg_in_base;
output    [ATU_BASE_WD*ATU_IN_MIN1 -1:0]    atu_reg_in_upr_base;
output    [ATU_REG_WD*ATU_IN_MIN1 -1:0]     atu_reg_in_limit;
output    [4*ATU_IN_MIN1 -1:0]              atu_reg_in_cbuf_incr;
output    [ATU_IN_MIN1 -1:0]                atu_reg_in_cbuf_restart;
output    [ATU_UPR_LMT_WD*ATU_IN_MIN1 -1:0] atu_reg_in_uppr_limit;
output    [ATU_REG_WD*ATU_IN_MIN1 -1:0]     atu_reg_in_lwr_trgt;
output    [ATU_BASE_WD*ATU_IN_MIN1 -1:0]    atu_reg_in_upr_trgt;
output    [ATU_IN_MIN1-1:0]                 atu_reg_in_incr_rgn_size;    // Maximum region size control bit

// ---------- Internal Signals --------
reg     [31:0]                      atu_ctrl_reg_data_int;    // register read data
reg     [31:0]                      atu_ctrl_reg_data;
reg     [31:0]                      n;                    // ATU viewport
reg                                 n_is_in;              // ATU viewport in/out

// ATU outbound Region controls
wire      [5*ATU_OUT_MIN1-1:0]              atu_reg_out_type;
wire      [3*ATU_OUT_MIN1-1:0]              atu_reg_out_tc;
wire      [ATU_OUT_MIN1-1:0]                atu_reg_out_td;
wire      [ATTR_WD*ATU_OUT_MIN1-1:0]        atu_reg_out_attr;
wire      [2*ATU_OUT_MIN1-1:0]              atu_reg_out_at;
wire      [PF_WD*ATU_OUT_MIN1-1:0]          atu_reg_out_func_num;
wire      [ATU_OUT_MIN1-1:0]                atu_reg_out_func_bypass;
wire      [ATU_OUT_MIN1-1:0]                atu_reg_out_snp;
wire      [ATU_OUT_MIN1-1:0]                atu_reg_out_dma_bypass;
wire      [ATU_OUT_MIN1-1:0]                atu_reg_out_inhibit_payload;
wire      [ATU_OUT_MIN1-1:0]                atu_reg_out_hdr_substitute_en;
wire      [ATU_OUT_MIN1-1:0]                atu_reg_out_tag_substitute_en;
wire      [TAG_SIZE*ATU_OUT_MIN1-1:0]       atu_reg_out_tag;
wire      [8*ATU_OUT_MIN1-1:0]              atu_reg_out_msg_code;
wire      [ATU_OUT_MIN1-1:0]                atu_reg_out_th;
wire      [2*ATU_OUT_MIN1-1:0]              atu_reg_out_ph;
wire      [8*ATU_OUT_MIN1-1:0]              atu_reg_out_st;
// Mode Settings
wire      [ATU_OUT_MIN1-1:0]                atu_reg_out_shift;
wire      [ATU_OUT_MIN1-1:0]                atu_reg_out_invert;
// Region Enable
wire      [ATU_OUT_MIN1-1:0]                atu_reg_out_en;
// Base, Limit and Target Registers
wire      [ATU_REG_WD*ATU_OUT_MIN1-1:0]     atu_reg_out_base;
wire      [ATU_BASE_WD*ATU_OUT_MIN1-1:0]    atu_reg_out_upr_base;
wire      [ATU_REG_WD*ATU_OUT_MIN1-1:0]     atu_reg_out_limit;
wire      [ATU_UPR_LMT_WD*ATU_OUT_MIN1-1:0] atu_reg_out_uppr_limit;
wire      [ATU_REG_WD*ATU_OUT_MIN1-1:0]     atu_reg_out_lwr_trgt;
wire      [ATU_BASE_WD*ATU_OUT_MIN1-1:0]    atu_reg_out_upr_trgt;
wire      [ATU_REG_LWR_WD*ATU_OUT_MIN1-1:0] atu_reg_out_lwr_trgt_lwr;
wire      [ATU_OUT_MIN1-1:0]                atu_reg_out_incr_rgn_size;    // Maximum region size control bit
wire      [ATU_OUT_MIN1-1:0]                atu_reg_out_hdr_flds_bypass;  // TLP Header fields bypass control bit

// ATU inbound Region controls
wire      [5*ATU_IN_MIN1 -1:0]              atu_reg_in_type;
wire      [3*ATU_IN_MIN1 -1:0]              atu_reg_in_tc;
wire      [ATU_IN_MIN1 -1:0]                atu_reg_in_td;
wire      [ATTR_WD*ATU_IN_MIN1 -1:0]        atu_reg_in_attr;
wire      [2*ATU_IN_MIN1 -1:0]              atu_reg_in_at;
wire      [PF_WD*ATU_IN_MIN1 -1:0]          atu_reg_in_func_num;
wire      [8*ATU_IN_MIN1 -1:0]              atu_reg_in_msg_code;
wire      [3*ATU_IN_MIN1 -1:0]              atu_reg_in_bar_num;
wire      [ATU_IN_MIN1-1:0]                 atu_reg_in_th;
wire      [2*ATU_IN_MIN1-1:0]               atu_reg_in_ph;
wire      [8*ATU_IN_MIN1-1:0]               atu_reg_in_st;
// Inbound field match enables
wire      [ATU_IN_MIN1 -1:0]                atu_reg_in_tc_match_en;
wire      [ATU_IN_MIN1 -1:0]                atu_reg_in_td_match_en;
wire      [ATU_IN_MIN1 -1:0]                atu_reg_in_attr_match_en;
wire      [ATU_IN_MIN1 -1:0]                atu_reg_in_at_match_en;
wire      [ATU_IN_MIN1 -1:0]                atu_reg_in_func_match_en;
wire      [ATU_IN_MIN1 -1:0]                atu_reg_in_msgcode_match_en;
wire      [ATU_IN_MIN1 -1:0]                atu_reg_in_th_match_en;
wire      [ATU_IN_MIN1 -1:0]                atu_reg_in_ph_match_en;
wire      [ATU_IN_MIN1 -1:0]                atu_reg_in_st_match_en;
wire      [ATU_IN_MIN1 -1:0]                atu_reg_in_single_addr_loc_en;
wire      [ATU_IN_MIN1 -1:0]                atu_reg_in_msg_type_match_mode;
// Response and mode settings
wire      [2*ATU_IN_MIN1 -1:0]              atu_reg_in_rsp_code;
wire      [ATU_IN_MIN1 -1:0]                atu_reg_in_fuzzy;
wire      [ATU_IN_MIN1 -1:0]                atu_reg_in_shift;
wire      [ATU_IN_MIN1 -1:0]                atu_reg_in_invert;
wire      [ATU_IN_MIN1 -1:0]                atu_reg_in_bar_match;
// Region Enable
wire      [ATU_IN_MIN1 -1:0]                atu_reg_in_en;
// Base, Limit and Target Registers
wire      [ATU_REG_WD*ATU_IN_MIN1 -1:0]     atu_reg_in_base;
wire      [ATU_BASE_WD*ATU_IN_MIN1 -1:0]    atu_reg_in_upr_base;
wire      [ATU_REG_WD*ATU_IN_MIN1 -1:0]     atu_reg_in_limit;
wire      [4*ATU_IN_MIN1 -1:0]              atu_reg_in_cbuf_incr;
wire      [ATU_IN_MIN1 -1:0]                atu_reg_in_cbuf_restart;
wire      [ATU_UPR_LMT_WD*ATU_IN_MIN1 -1:0] atu_reg_in_uppr_limit;
wire      [ATU_REG_WD*ATU_IN_MIN1 -1:0]     atu_reg_in_lwr_trgt;
wire      [ATU_BASE_WD*ATU_IN_MIN1 -1:0]    atu_reg_in_upr_trgt;
wire      [ATU_IN_MIN1-1:0]                 atu_reg_in_incr_rgn_size;    // Maximum region size control bit

// LMD:  undriven net
// LJ: All net range are driven through the "for" statement generate by the genvar atu_i
// leda NTL_CON12 off
// ATU inbound Region controls

// Internal Signals
reg       [5*ATU_MAX_REGIONS-1:0]               int_atu_out_type;
reg       [ATU_MAX_REGIONS-1:0][4:0]            int_atu_out_type_packed_arr;
reg       [3*ATU_MAX_REGIONS-1:0]               int_atu_out_tc;
reg       [ATU_MAX_REGIONS-1:0][2:0]            int_atu_out_tc_packed_arr;
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_out_td;
reg       [ATTR_WD*ATU_MAX_REGIONS-1:0]         int_atu_out_attr;
reg       [ATU_MAX_REGIONS-1:0][ATTR_WD-1:0]    int_atu_out_attr_packed_arr;
reg       [2*ATU_MAX_REGIONS-1:0]               int_atu_out_at;
reg       [ATU_MAX_REGIONS-1:0][1:0]            int_atu_out_at_packed_arr;
reg       [PF_WD*ATU_MAX_REGIONS-1:0]           int_atu_out_func_num;
reg       [ATU_MAX_REGIONS-1:0][PF_WD-1:0]      int_atu_out_func_num_packed_arr;
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_out_func_bypass;
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_out_snp;
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_out_dma_bypass;
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_out_hdr_flds_bypass;
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_out_inhibit_payload;
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_out_hdr_substitute_en; 
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_out_tag_substitute_en;
reg       [TAG_SIZE*ATU_MAX_REGIONS-1:0]        int_atu_out_tag;
reg       [ATU_MAX_REGIONS-1:0][TAG_SIZE-1:0]   int_atu_out_tag_packed_arr;
reg       [8*ATU_MAX_REGIONS-1:0]               int_atu_out_msg_code;
reg       [ATU_MAX_REGIONS-1:0][7:0]            int_atu_out_msg_code_packed_arr;
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_out_th;
reg       [2*ATU_MAX_REGIONS-1:0]               int_atu_out_ph;
reg       [ATU_MAX_REGIONS-1:0][1:0]            int_atu_out_ph_packed_arr;
wire      [8*ATU_MAX_REGIONS-1:0]               int_atu_out_st;
// Mode Settings
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_out_shift;
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_out_invert;
// Region Enable
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_out_en;
// Base, Limit and Target Registers
reg       [ATU_REG_WD*ATU_MAX_REGIONS-1:0]      int_atu_out_base;
reg       [ATU_MAX_REGIONS-1:0][ATU_REG_WD-1:0] int_atu_out_base_packed_arr;
reg       [ATU_BASE_WD*ATU_MAX_REGIONS-1:0]     int_atu_out_upr_base;
reg       [ATU_MAX_REGIONS-1:0][ATU_BASE_WD-1:0] int_atu_out_upr_base_packed_arr;

reg       [ATU_REG_WD*ATU_MAX_REGIONS-1:0]      int_atu_out_limit;
reg       [ATU_MAX_REGIONS-1:0][ATU_REG_WD-1:0] int_atu_out_limit_packed_arr;
reg       [ATU_UPR_LMT_WD*ATU_MAX_REGIONS-1:0]  int_atu_out_uppr_limit;
reg       [ATU_MAX_REGIONS-1:0][ATU_UPR_LMT_WD-1:0] int_atu_out_uppr_limit_packed_arr;
reg       [ATU_REG_WD*ATU_MAX_REGIONS-1:0]      int_atu_out_lwr_trgt;
reg       [ATU_MAX_REGIONS-1:0][ATU_REG_WD-1:0] int_atu_out_lwr_trgt_packed_arr;
reg       [ATU_BASE_WD*ATU_MAX_REGIONS-1:0]     int_atu_out_upr_trgt;
reg       [ATU_MAX_REGIONS-1:0][ATU_BASE_WD-1:0] int_atu_out_upr_trgt_packed_arr;
reg       [ATU_REG_LWR_WD*ATU_MAX_REGIONS-1:0]  int_atu_out_lwr_trgt_lwr;
reg       [ATU_MAX_REGIONS-1:0][ATU_REG_LWR_WD-1:0] int_atu_out_lwr_trgt_lwr_packed_arr;
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_out_incr_rgn_size;    // Maximum region size control bit

reg       [5*ATU_MAX_REGIONS-1:0]               int_atu_in_type;
reg       [ATU_MAX_REGIONS-1:0][4:0]            int_atu_in_type_packed_arr;
reg       [3*ATU_MAX_REGIONS-1:0]               int_atu_in_tc;
reg       [ATU_MAX_REGIONS-1:0][2:0]            int_atu_in_tc_packed_arr;
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_in_td;
reg       [ATTR_WD*ATU_MAX_REGIONS-1:0]         int_atu_in_attr;
reg       [ATU_MAX_REGIONS-1:0][ATTR_WD-1:0]    int_atu_in_attr_packed_arr;
reg       [2*ATU_MAX_REGIONS-1:0]               int_atu_in_at;
reg       [ATU_MAX_REGIONS-1:0][1:0]            int_atu_in_at_packed_arr;
reg       [PF_WD*ATU_MAX_REGIONS-1:0]           int_atu_in_func_num;
reg       [ATU_MAX_REGIONS-1:0][PF_WD-1:0]      int_atu_in_func_num_packed_arr;
reg       [8*ATU_MAX_REGIONS-1:0]               int_atu_in_msg_code; 
reg       [ATU_MAX_REGIONS-1:0][7:0]            int_atu_in_msg_code_packed_arr;
reg       [3*ATU_MAX_REGIONS-1:0]               int_atu_in_bar_num;
reg       [ATU_MAX_REGIONS-1:0][2:0]            int_atu_in_bar_num_packed_arr;
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_in_th;
reg       [2*ATU_MAX_REGIONS-1:0]               int_atu_in_ph;
reg       [ATU_MAX_REGIONS-1:0][1:0]               int_atu_in_ph_packed_arr;
wire      [8*ATU_MAX_REGIONS-1:0]               int_atu_in_st;
// Inbound field match enables
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_in_msg_type_match_mode;
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_in_tc_match_en;
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_in_td_match_en;
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_in_attr_match_en;
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_in_at_match_en;
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_in_func_match_en;
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_in_msgcode_match_en;
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_in_th_match_en;
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_in_ph_match_en;
wire      [ATU_MAX_REGIONS-1:0]                 int_atu_in_st_match_en;
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_in_single_addr_loc_en;
// Response and mode settings
reg       [2*ATU_MAX_REGIONS-1:0]               int_atu_in_rsp_code;
reg       [ATU_MAX_REGIONS-1:0][1:0]            int_atu_in_rsp_code_packed_arr;
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_in_fuzzy;
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_in_shift;
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_in_invert;
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_in_bar_match;
// Region Enable
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_in_en;
// Base, Limit and Target Registers
reg       [ATU_REG_WD*ATU_MAX_REGIONS-1:0]      int_atu_in_base;
reg       [ATU_MAX_REGIONS-1:0][ATU_REG_WD-1:0] int_atu_in_base_packed_arr;
reg       [ATU_BASE_WD*ATU_MAX_REGIONS-1:0]     int_atu_in_upr_base;
reg       [ATU_MAX_REGIONS-1:0][ATU_BASE_WD-1:0] int_atu_in_upr_base_packed_arr;
reg       [ATU_REG_WD*ATU_MAX_REGIONS-1:0]      int_atu_in_limit;
reg       [ATU_MAX_REGIONS-1:0][ATU_REG_WD-1:0] int_atu_in_limit_packed_arr;
reg       [4*ATU_MAX_REGIONS-1:0]               int_atu_in_cbuf_incr;
reg       [ATU_MAX_REGIONS-1:0][3:0]            int_atu_in_cbuf_incr_packed_arr;
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_in_cbuf_restart;
reg       [ATU_UPR_LMT_WD*ATU_MAX_REGIONS-1:0]  int_atu_in_uppr_limit;
reg       [ATU_MAX_REGIONS-1:0][ATU_UPR_LMT_WD-1:0] int_atu_in_uppr_limit_packed_arr;
reg       [ATU_REG_WD*ATU_MAX_REGIONS-1:0]      int_atu_in_lwr_trgt;
reg       [ATU_MAX_REGIONS-1:0][ATU_REG_WD-1:0] int_atu_in_lwr_trgt_packed_arr;
logic     [ATU_BASE_WD*ATU_MAX_REGIONS-1:0]     int_atu_in_upr_trgt;
logic     [ATU_MAX_REGIONS-1:0][ATU_BASE_WD-1:0] int_atu_in_upr_trgt_packed_arr;
reg       [ATU_MAX_REGIONS-1:0]                 int_atu_in_incr_rgn_size;    // Maximum region size control bit
// leda NTL_CON12 on

// -----------------------------------------------------------------------------
// Adding bcm for false path
// -----------------------------------------------------------------------------

typedef struct packed {
// Internal Signals
logic       [5*ATU_MAX_REGIONS-1:0]               int_atu_out_type;
logic       [3*ATU_MAX_REGIONS-1:0]               int_atu_out_tc;
logic       [ATU_MAX_REGIONS-1:0]                 int_atu_out_td;
logic       [ATTR_WD*ATU_MAX_REGIONS-1:0]         int_atu_out_attr;
logic       [2*ATU_MAX_REGIONS-1:0]               int_atu_out_at;
logic       [PF_WD*ATU_MAX_REGIONS-1:0]           int_atu_out_func_num;
logic       [ATU_MAX_REGIONS-1:0]                 int_atu_out_func_bypass;
logic       [ATU_MAX_REGIONS-1:0]                 int_atu_out_snp;
logic       [ATU_MAX_REGIONS-1:0]                 int_atu_out_dma_bypass;
logic       [ATU_MAX_REGIONS-1:0]                 int_atu_out_hdr_flds_bypass;
logic       [ATU_MAX_REGIONS-1:0]                 int_atu_out_inhibit_payload;
logic       [ATU_MAX_REGIONS-1:0]                 int_atu_out_hdr_substitute_en; 
logic       [ATU_MAX_REGIONS-1:0]                 int_atu_out_tag_substitute_en;
logic       [TAG_SIZE*ATU_MAX_REGIONS-1:0]        int_atu_out_tag;
logic       [8*ATU_MAX_REGIONS-1:0]               int_atu_out_msg_code;
logic       [ATU_MAX_REGIONS-1:0]                 int_atu_out_th;
logic       [2*ATU_MAX_REGIONS-1:0]               int_atu_out_ph;
// Mode Settings
logic       [ATU_MAX_REGIONS-1:0]                 int_atu_out_shift;
logic       [ATU_MAX_REGIONS-1:0]                 int_atu_out_invert;
// Region Enable
logic       [ATU_MAX_REGIONS-1:0]                 int_atu_out_en;
// Base, Limit and Target Registers
logic       [ATU_REG_WD*ATU_MAX_REGIONS-1:0]      int_atu_out_base;
logic       [ATU_BASE_WD*ATU_MAX_REGIONS-1:0]     int_atu_out_upr_base;

logic       [ATU_REG_WD*ATU_MAX_REGIONS-1:0]      int_atu_out_limit;
logic       [ATU_UPR_LMT_WD*ATU_MAX_REGIONS-1:0]  int_atu_out_uppr_limit;
logic       [ATU_REG_WD*ATU_MAX_REGIONS-1:0]      int_atu_out_lwr_trgt;
logic       [ATU_BASE_WD*ATU_MAX_REGIONS-1:0]     int_atu_out_upr_trgt;
logic       [ATU_REG_LWR_WD*ATU_MAX_REGIONS-1:0]  int_atu_out_lwr_trgt_lwr;
logic       [ATU_MAX_REGIONS-1:0]                 int_atu_out_incr_rgn_size;    // Maximum region size control bit

logic       [5*ATU_MAX_REGIONS-1:0]               int_atu_in_type;
logic       [3*ATU_MAX_REGIONS-1:0]               int_atu_in_tc;
logic       [ATU_MAX_REGIONS-1:0]                 int_atu_in_td;
logic       [ATTR_WD*ATU_MAX_REGIONS-1:0]         int_atu_in_attr;
logic       [2*ATU_MAX_REGIONS-1:0]               int_atu_in_at;
logic       [PF_WD*ATU_MAX_REGIONS-1:0]           int_atu_in_func_num;
logic       [8*ATU_MAX_REGIONS-1:0]               int_atu_in_msg_code; 
logic       [3*ATU_MAX_REGIONS-1:0]               int_atu_in_bar_num;
logic       [ATU_MAX_REGIONS-1:0]                 int_atu_in_th;
logic       [2*ATU_MAX_REGIONS-1:0]               int_atu_in_ph;
// Inbound field match enables
logic       [ATU_MAX_REGIONS-1:0]                 int_atu_in_msg_type_match_mode;
logic       [ATU_MAX_REGIONS-1:0]                 int_atu_in_tc_match_en;
logic       [ATU_MAX_REGIONS-1:0]                 int_atu_in_td_match_en;
logic       [ATU_MAX_REGIONS-1:0]                 int_atu_in_attr_match_en;
logic       [ATU_MAX_REGIONS-1:0]                 int_atu_in_at_match_en;
logic       [ATU_MAX_REGIONS-1:0]                 int_atu_in_func_match_en;
logic       [ATU_MAX_REGIONS-1:0]                 int_atu_in_msgcode_match_en;
logic       [ATU_MAX_REGIONS-1:0]                 int_atu_in_th_match_en;
logic       [ATU_MAX_REGIONS-1:0]                 int_atu_in_ph_match_en;
logic       [ATU_MAX_REGIONS-1:0]                 int_atu_in_single_addr_loc_en;
// Response and mode settings
logic       [2*ATU_MAX_REGIONS-1:0]               int_atu_in_rsp_code;
logic       [ATU_MAX_REGIONS-1:0]                 int_atu_in_fuzzy;
logic       [ATU_MAX_REGIONS-1:0]                 int_atu_in_shift;
logic       [ATU_MAX_REGIONS-1:0]                 int_atu_in_invert;
logic       [ATU_MAX_REGIONS-1:0]                 int_atu_in_bar_match;
// Region Enable
logic       [ATU_MAX_REGIONS-1:0]                 int_atu_in_en;
// Base, Limit and Target Registers
logic       [ATU_REG_WD*ATU_MAX_REGIONS-1:0]      int_atu_in_base;
logic       [ATU_BASE_WD*ATU_MAX_REGIONS-1:0]     int_atu_in_upr_base;
logic       [ATU_REG_WD*ATU_MAX_REGIONS-1:0]      int_atu_in_limit;
logic       [4*ATU_MAX_REGIONS-1:0]               int_atu_in_cbuf_incr;
logic       [ATU_UPR_LMT_WD*ATU_MAX_REGIONS-1:0]  int_atu_in_uppr_limit;
logic       [ATU_REG_WD*ATU_MAX_REGIONS-1:0]      int_atu_in_lwr_trgt;
logic     [ATU_BASE_WD*ATU_MAX_REGIONS-1:0]     int_atu_in_upr_trgt;
logic       [ATU_MAX_REGIONS-1:0]                 int_atu_in_incr_rgn_size;    // Maximum region size control bit
} int_atu_false_path_reg;

int_atu_false_path_reg reg_bcm36_nhs_s, reg_bcm36_nhs_d; // input and output of bcm36_nhs

assign reg_bcm36_nhs_s = '{

 int_atu_out_type                       : int_atu_out_type
,int_atu_out_tc                         : int_atu_out_tc
,int_atu_out_td                         : int_atu_out_td
,int_atu_out_attr                       : int_atu_out_attr
,int_atu_out_at                         : int_atu_out_at
,int_atu_out_func_num                   : int_atu_out_func_num
,int_atu_out_func_bypass                : int_atu_out_func_bypass
,int_atu_out_snp                        : int_atu_out_snp
,int_atu_out_dma_bypass                 : int_atu_out_dma_bypass
,int_atu_out_hdr_flds_bypass            : int_atu_out_hdr_flds_bypass
,int_atu_out_inhibit_payload            : int_atu_out_inhibit_payload
,int_atu_out_hdr_substitute_en          : int_atu_out_hdr_substitute_en 
,int_atu_out_tag_substitute_en          : int_atu_out_tag_substitute_en
,int_atu_out_tag                        : int_atu_out_tag
,int_atu_out_msg_code                   : int_atu_out_msg_code
,int_atu_out_th                         : int_atu_out_th
,int_atu_out_ph                         : int_atu_out_ph
// Mode Settings    
,int_atu_out_shift                      : int_atu_out_shift
,int_atu_out_invert                     : int_atu_out_invert
// Region Enable    
,int_atu_out_en                         : int_atu_out_en
// Base, Limit and Target Registers 
,int_atu_out_base                       : int_atu_out_base
,int_atu_out_upr_base                   : int_atu_out_upr_base
    
,int_atu_out_limit                      : int_atu_out_limit
,int_atu_out_uppr_limit                 : int_atu_out_uppr_limit
,int_atu_out_lwr_trgt                   : int_atu_out_lwr_trgt
,int_atu_out_upr_trgt                   : int_atu_out_upr_trgt
,int_atu_out_lwr_trgt_lwr               : int_atu_out_lwr_trgt_lwr
,int_atu_out_incr_rgn_size              : int_atu_out_incr_rgn_size    

,int_atu_in_type                        : int_atu_in_type
,int_atu_in_tc                          : int_atu_in_tc
,int_atu_in_td                          : int_atu_in_td
,int_atu_in_attr                        : int_atu_in_attr
,int_atu_in_at                          : int_atu_in_at
,int_atu_in_func_num                    : int_atu_in_func_num
,int_atu_in_msg_code                    : int_atu_in_msg_code 
,int_atu_in_bar_num                     : int_atu_in_bar_num
,int_atu_in_th                          : int_atu_in_th
,int_atu_in_ph                          : int_atu_in_ph
// Inbound field match enables
,int_atu_in_msg_type_match_mode         : int_atu_in_msg_type_match_mode
,int_atu_in_tc_match_en                 : int_atu_in_tc_match_en
,int_atu_in_td_match_en                 : int_atu_in_td_match_en
,int_atu_in_attr_match_en               : int_atu_in_attr_match_en
,int_atu_in_at_match_en                 : int_atu_in_at_match_en
,int_atu_in_func_match_en               : int_atu_in_func_match_en
,int_atu_in_msgcode_match_en            : int_atu_in_msgcode_match_en
,int_atu_in_th_match_en                 : int_atu_in_th_match_en
,int_atu_in_ph_match_en                 : int_atu_in_ph_match_en
,int_atu_in_single_addr_loc_en          : int_atu_in_single_addr_loc_en
// Response and mode settings
,int_atu_in_rsp_code                    : int_atu_in_rsp_code
,int_atu_in_fuzzy                       : int_atu_in_fuzzy
,int_atu_in_shift                       : int_atu_in_shift
,int_atu_in_invert                      : int_atu_in_invert
,int_atu_in_bar_match                   : int_atu_in_bar_match
// Region Enable
,int_atu_in_en                          : int_atu_in_en
// Base, Limit and Target Registers
,int_atu_in_base                        : int_atu_in_base
,int_atu_in_upr_base                    : int_atu_in_upr_base
,int_atu_in_limit                       : int_atu_in_limit
,int_atu_in_cbuf_incr                   : int_atu_in_cbuf_incr
,int_atu_in_uppr_limit                  : int_atu_in_uppr_limit
,int_atu_in_lwr_trgt                    : int_atu_in_lwr_trgt
,int_atu_in_upr_trgt                    : int_atu_in_upr_trgt
,int_atu_in_incr_rgn_size               : int_atu_in_incr_rgn_size    
};


DWC_pcie_ctl_bcm36_nhs
 #(
  .WIDTH      ($bits(int_atu_false_path_reg)),
  .DATA_DELAY (DATA_DELAY_BCM36_NHS)
) u_bcm36_nhs_int_atu_reg (
`ifndef SYNTHESIS
  .clk_d   (core_clk),
  .rst_d_n (sticky_rst_n),
`endif // SYNTHESIS
  .data_s  (reg_bcm36_nhs_s),
  .data_d  (reg_bcm36_nhs_d)
);


always @(posedge core_clk or negedge sticky_rst_n)
begin : reg_data 
    if(!sticky_rst_n) begin
       atu_ctrl_reg_data <=  #TP 32'd0;
    end else begin
       atu_ctrl_reg_data <= #TP atu_ctrl_reg_data_int;
    end
 end



reg [ATU_CTRL_REG_ID_WD-1:0] atu_ctrl_reg_id;
wire valid_region;

assign valid_region =   (  lbc_cdm_addr[8] && (lbc_cdm_addr[16:9] < ATU_IN_REGIONS  ))
                     || ( ~lbc_cdm_addr[8] && (lbc_cdm_addr[16:9] < ATU_OUT_REGIONS ));



always @(*)
begin
n = {24'b0,lbc_cdm_addr [ 16: 9]}; //region in on the address
n_is_in = lbc_cdm_addr[8]; //INBOUND/OUTBOUND IS MAPPED ON THE ADDRESS
end

//Decode addresses into ATU one-hot
always @(*)
begin
        atu_ctrl_reg_id[9] =  valid_region & atu_reg_sel & (lbc_cdm_addr[7:2] ==  6'h08  );
        atu_ctrl_reg_id[0] =  1'b0                                         ;
        atu_ctrl_reg_id[1] =  valid_region & atu_reg_sel & (lbc_cdm_addr[7:2] ==  6'h00  );
        atu_ctrl_reg_id[2] =  valid_region & atu_reg_sel & (lbc_cdm_addr[7:2] ==  6'h01  );
        atu_ctrl_reg_id[3] =  valid_region & atu_reg_sel & (lbc_cdm_addr[7:2] ==  6'h02  );
        atu_ctrl_reg_id[4] =  valid_region & atu_reg_sel & (lbc_cdm_addr[7:2] ==  6'h03  );
        atu_ctrl_reg_id[5] =  valid_region & atu_reg_sel & (lbc_cdm_addr[7:2] ==  6'h04  );
        atu_ctrl_reg_id[6] =  valid_region & atu_reg_sel & (lbc_cdm_addr[7:2] ==  6'h05  );
        atu_ctrl_reg_id[7] =  valid_region & atu_reg_sel & (lbc_cdm_addr[7:2] ==  6'h06  );
        atu_ctrl_reg_id[8] =  valid_region & atu_reg_sel & (lbc_cdm_addr[7:2] ==  6'h07  );
end



// Expand the write pulse to allow fully parameterizable widths for Base,Limit
// and Target registers
wire [31:0] write_pulse_full;
assign write_pulse_full = {
    {8{atu_ctrl_write_pulse[3]}},
    {8{atu_ctrl_write_pulse[2]}},
    {8{atu_ctrl_write_pulse[1]}},
    {8{atu_ctrl_write_pulse[0]}}
};


generate
if(ATU_OUT_REGIONS > 0) begin : gen_atu_out
// Output Assignments
// ATU outbound Region controls
assign atu_reg_out_type             = reg_bcm36_nhs_d.int_atu_out_type[5*ATU_OUT_REGIONS-1:0];
assign atu_reg_out_tc               = reg_bcm36_nhs_d.int_atu_out_tc[3*ATU_OUT_REGIONS-1:0];
assign atu_reg_out_td               = reg_bcm36_nhs_d.int_atu_out_td[ATU_OUT_REGIONS-1:0];
assign atu_reg_out_attr             = reg_bcm36_nhs_d.int_atu_out_attr[ATTR_WD*ATU_OUT_REGIONS-1:0];
assign atu_reg_out_at               = reg_bcm36_nhs_d.int_atu_out_at[2*ATU_OUT_REGIONS-1:0];
assign atu_reg_out_func_num         =
    reg_bcm36_nhs_d.int_atu_out_func_num[PF_WD*ATU_OUT_REGIONS-1:0];
assign atu_reg_out_func_bypass      =
    reg_bcm36_nhs_d.int_atu_out_func_bypass[ATU_OUT_REGIONS-1:0];
assign atu_reg_out_snp              = reg_bcm36_nhs_d.int_atu_out_snp[ATU_OUT_REGIONS-1:0];
assign atu_reg_out_dma_bypass       =
    reg_bcm36_nhs_d.int_atu_out_dma_bypass[ATU_OUT_REGIONS-1:0];
assign atu_reg_out_hdr_flds_bypass   = reg_bcm36_nhs_d.int_atu_out_hdr_flds_bypass[ATU_OUT_REGIONS-1:0]; 
assign atu_reg_out_inhibit_payload   = reg_bcm36_nhs_d.int_atu_out_inhibit_payload[ATU_OUT_REGIONS-1:0];
assign atu_reg_out_hdr_substitute_en = reg_bcm36_nhs_d.int_atu_out_hdr_substitute_en[ATU_OUT_REGIONS-1:0];
assign atu_reg_out_tag_substitute_en = reg_bcm36_nhs_d.int_atu_out_tag_substitute_en[ATU_OUT_REGIONS-1:0];
assign atu_reg_out_tag               = reg_bcm36_nhs_d.int_atu_out_tag[TAG_SIZE*ATU_OUT_REGIONS-1:0];
assign atu_reg_out_msg_code         =
    reg_bcm36_nhs_d.int_atu_out_msg_code[8*ATU_OUT_REGIONS-1:0];
assign atu_reg_out_th               = reg_bcm36_nhs_d.int_atu_out_th[ATU_OUT_REGIONS-1:0];
assign atu_reg_out_ph               = reg_bcm36_nhs_d.int_atu_out_ph[2*ATU_OUT_REGIONS-1:0];
assign atu_reg_out_st               = int_atu_out_st[8*ATU_OUT_REGIONS-1:0];
// Mode Settings
assign atu_reg_out_shift            = reg_bcm36_nhs_d.int_atu_out_shift[ATU_OUT_REGIONS-1:0];
assign atu_reg_out_invert           = reg_bcm36_nhs_d.int_atu_out_invert[ATU_OUT_REGIONS-1:0];
// Region Enable
assign atu_reg_out_en               = reg_bcm36_nhs_d.int_atu_out_en[ATU_OUT_REGIONS-1:0];
// Base, Limit and Target Registers
assign atu_reg_out_base             =
    reg_bcm36_nhs_d.int_atu_out_base[ATU_REG_WD*ATU_OUT_REGIONS-1:0];
assign atu_reg_out_upr_base         =
    reg_bcm36_nhs_d.int_atu_out_upr_base[ATU_BASE_WD*ATU_OUT_REGIONS-1:0];
assign atu_reg_out_limit            =
    reg_bcm36_nhs_d.int_atu_out_limit[ATU_REG_WD*ATU_OUT_REGIONS-1:0];
assign atu_reg_out_uppr_limit            =
    reg_bcm36_nhs_d.int_atu_out_uppr_limit[ATU_UPR_LMT_WD*ATU_OUT_REGIONS-1:0];
assign atu_reg_out_lwr_trgt         =
    reg_bcm36_nhs_d.int_atu_out_lwr_trgt[ATU_REG_WD*ATU_OUT_REGIONS-1:0];
assign atu_reg_out_upr_trgt         =
    reg_bcm36_nhs_d.int_atu_out_upr_trgt[ATU_BASE_WD*ATU_OUT_REGIONS-1:0];
assign atu_reg_out_lwr_trgt_lwr     =
    reg_bcm36_nhs_d.int_atu_out_lwr_trgt_lwr[ATU_REG_LWR_WD*ATU_OUT_REGIONS-1:0];
assign atu_reg_out_incr_rgn_size     = reg_bcm36_nhs_d.int_atu_out_incr_rgn_size[ATU_OUT_REGIONS-1:0];


// -----------------------------------------------------------------------------
// Outbound Region n Control Register 1
// -----------------------------------------------------------------------------
// atu_ctrl_reg_id      - 1
// Port Logic Offset    -`CFG_PL_REG + 204h
// -----------------------------------------------------------------------------
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin : proc_atu_out_ctrl_1
  integer atu_o;
    if(!sticky_rst_n) begin
      for(atu_o = 0; atu_o < ATU_OUT_REGIONS; atu_o = atu_o + 1) begin
        int_atu_out_type[atu_o*5 +: 5]            <= #TP {5{1'b0}};
        int_atu_out_tc[atu_o*3 +: 3]              <= #TP {3{1'b0}};
        int_atu_out_td[atu_o]                     <= #TP 1'b0;
        int_atu_out_attr[atu_o*ATTR_WD +: ATTR_WD]<= #TP {2{1'b0}};
        int_atu_out_at[atu_o*2 +: 2]              <= #TP {2{1'b0}};
        int_atu_out_func_num[atu_o*PF_WD +: PF_WD]<= #TP {PF_WD{1'b0}};
        int_atu_out_th[atu_o]                     <= #TP 1'b0;
        int_atu_out_ph[atu_o*2 +: 2]              <= #TP {2{1'b0}};
        int_atu_out_incr_rgn_size[atu_o]           <= #TP 1'b0;
      end
    end
    else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      for(atu_o = 0; atu_o < ATU_OUT_REGIONS; atu_o = atu_o + 1) begin
        int_atu_out_type[atu_o*5 +: 5]  <= #TP (atu_ctrl_write_pulse[0] &&
            atu_ctrl_reg_id[1] && !n_is_in && n[ATU_LOG2_REGIONS-1:0] == atu_o) ?
            lbc_cdm_data[4:0] : int_atu_out_type[atu_o*5 +: 5];
        int_atu_out_tc[atu_o*3 +: 3]  <= #TP (atu_ctrl_write_pulse[0] &&
            atu_ctrl_reg_id[1] && !n_is_in && n[ATU_LOG2_REGIONS-1:0] == atu_o) ?
            lbc_cdm_data[7:5] : int_atu_out_tc[atu_o*3 +: 3];
        int_atu_out_td[atu_o]  <= #TP (atu_ctrl_write_pulse[1] &&
            atu_ctrl_reg_id[1] && !n_is_in && n[ATU_LOG2_REGIONS-1:0] == atu_o) ?
            lbc_cdm_data[8] : int_atu_out_td[atu_o];
        int_atu_out_attr[atu_o*ATTR_WD +: ATTR_WD]  <= #TP (atu_ctrl_write_pulse[1] &&
            atu_ctrl_reg_id[1] && !n_is_in && n[ATU_LOG2_REGIONS-1:0] == atu_o) ?
            lbc_cdm_data[9 +: ATTR_WD] : int_atu_out_attr[atu_o*ATTR_WD +: ATTR_WD];
        int_atu_out_th[atu_o]         <= #TP (atu_ctrl_write_pulse[1] &&
            atu_ctrl_reg_id[1] && !n_is_in && n[ATU_LOG2_REGIONS-1:0] == atu_o) ?
            lbc_cdm_data[12] : int_atu_out_th[atu_o];
        int_atu_out_incr_rgn_size[atu_o]  <= #TP (atu_ctrl_write_pulse[1] &&
            atu_ctrl_reg_id[1] && !n_is_in && n[ATU_LOG2_REGIONS-1:0] == atu_o) ?
            lbc_cdm_data[13] : int_atu_out_incr_rgn_size[atu_o];
        int_atu_out_at[atu_o*2 +: 2]  <= #TP (atu_ctrl_write_pulse[2] &&
            atu_ctrl_reg_id[1] && !n_is_in && n[ATU_LOG2_REGIONS-1:0] == atu_o) ?
            lbc_cdm_data[17:16] : int_atu_out_at[atu_o*2 +: 2];
        int_atu_out_ph[atu_o*2 +: 2]  <= #TP (atu_ctrl_write_pulse[2] &&
          atu_ctrl_reg_id[1] && !n_is_in && n[ATU_LOG2_REGIONS-1:0] == atu_o) ?
          lbc_cdm_data[19:18] : int_atu_out_ph[atu_o*2 +: 2];
        int_atu_out_func_num[atu_o*PF_WD +: PF_WD]  <= #TP
        (atu_ctrl_reg_id[1] && !n_is_in && n[ATU_LOG2_REGIONS-1:0] == atu_o) ?
            ~write_pulse_full[20 +: PF_WD] &
            int_atu_out_func_num[atu_o*PF_WD +: PF_WD] |
            write_pulse_full[20 +: PF_WD] & lbc_cdm_data[20 +: PF_WD] :
            int_atu_out_func_num[atu_o*PF_WD +: PF_WD];
      end
    end
end
// -----------------------------------------------------------------------------
// Outbound Region n Control Register 2
// -----------------------------------------------------------------------------
// atu_ctrl_reg_id      - 2
// Port Logic Offset    -`CFG_PL_REG + 208h
// -----------------------------------------------------------------------------
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin : proc_atu_out_ctrl_2
  integer atu_o;
    if(!sticky_rst_n) begin
      for(atu_o = 0; atu_o < ATU_OUT_REGIONS; atu_o = atu_o + 1) begin
        int_atu_out_msg_code[atu_o*8 +: 8]  <= #TP {8{1'b0}};
        int_atu_out_func_bypass[atu_o]      <= #TP 1'b0;
        int_atu_out_snp[atu_o]              <= #TP 1'b0;
        int_atu_out_hdr_flds_bypass[atu_o]  <= #TP 1'b0;
        int_atu_out_inhibit_payload[atu_o]  <= #TP 1'b0;
        int_atu_out_hdr_substitute_en[atu_o] <= #TP 1'b0;
        int_atu_out_tag_substitute_en[atu_o] <= #TP 1'b0;
        int_atu_out_tag[atu_o*TAG_SIZE +: TAG_SIZE] <= #TP {TAG_SIZE{1'b0}};
        int_atu_out_dma_bypass[atu_o]       <= #TP 1'b0;
        int_atu_out_shift[atu_o]            <= #TP 1'b0;
        int_atu_out_invert[atu_o]           <= #TP 1'b0;
        int_atu_out_en[atu_o]               <= #TP 1'b0;
      end
    end
    else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      for(atu_o = 0; atu_o < ATU_OUT_REGIONS; atu_o = atu_o + 1) begin
        int_atu_out_msg_code[atu_o*8 +: 8]  <= #TP (atu_ctrl_write_pulse[0] &&
            atu_ctrl_reg_id[2] && !n_is_in && n[ATU_LOG2_REGIONS-1:0] == atu_o) ?
            lbc_cdm_data[7:0] : int_atu_out_msg_code[atu_o*8 +: 8];
        int_atu_out_tag[atu_o*TAG_SIZE +: 8]  <= #TP (atu_ctrl_write_pulse[1] && 
            atu_ctrl_reg_id[2] && !n_is_in && n[ATU_LOG2_REGIONS-1:0] == atu_o) ?
            lbc_cdm_data[15:8] : int_atu_out_tag[atu_o*TAG_SIZE +: 8];
        int_atu_out_tag[(atu_o*TAG_SIZE)+8 +: 2]  <= #TP (atu_ctrl_write_pulse[2] && 
            atu_ctrl_reg_id[2] && !n_is_in && n[ATU_LOG2_REGIONS-1:0] == atu_o) ?
            lbc_cdm_data[18:17] : int_atu_out_tag[(atu_o*TAG_SIZE)+8 +: 2];
        int_atu_out_tag[(atu_o*TAG_SIZE)+10 +: 4]  <= #TP 4'b0000; 
        int_atu_out_tag_substitute_en[atu_o]  <= #TP (atu_ctrl_write_pulse[2] &&
            atu_ctrl_reg_id[2] && !n_is_in && n[ATU_LOG2_REGIONS-1:0] == atu_o) ?
            lbc_cdm_data[16] : int_atu_out_tag_substitute_en[atu_o];
        int_atu_out_snp[atu_o]              <= #TP (atu_ctrl_write_pulse[2] &&
            atu_ctrl_reg_id[2] && !n_is_in && n[ATU_LOG2_REGIONS-1:0] == atu_o) ?
            lbc_cdm_data[20] : int_atu_out_snp[atu_o];
        int_atu_out_func_bypass[atu_o]      <= #TP (atu_ctrl_write_pulse[2] &&
            atu_ctrl_reg_id[2] && !n_is_in && n[ATU_LOG2_REGIONS-1:0] == atu_o) ?
            lbc_cdm_data[19] : int_atu_out_func_bypass[atu_o];
        int_atu_out_hdr_flds_bypass[atu_o]  <= #TP (atu_ctrl_write_pulse[2] &&
            atu_ctrl_reg_id[2] && !n_is_in && n[ATU_LOG2_REGIONS-1:0] == atu_o) ?
            lbc_cdm_data[21] : int_atu_out_hdr_flds_bypass[atu_o];
        int_atu_out_inhibit_payload[atu_o]  <= #TP (atu_ctrl_write_pulse[2] &&
            atu_ctrl_reg_id[2] && !n_is_in && n[ATU_LOG2_REGIONS-1:0] == atu_o) ?
            lbc_cdm_data[22] : int_atu_out_inhibit_payload[atu_o];
        int_atu_out_hdr_substitute_en[atu_o]  <= #TP (atu_ctrl_write_pulse[2] &&
            atu_ctrl_reg_id[2] && !n_is_in && n[ATU_LOG2_REGIONS-1:0] == atu_o) ?
            lbc_cdm_data[23] : int_atu_out_hdr_substitute_en[atu_o];
        int_atu_out_dma_bypass[atu_o]       <= #TP (atu_ctrl_write_pulse[3] &&
            atu_ctrl_reg_id[2] && !n_is_in && n[ATU_LOG2_REGIONS-1:0] == atu_o) ?
            lbc_cdm_data[27] : int_atu_out_dma_bypass[atu_o];
        int_atu_out_shift[atu_o]  <= #TP (atu_ctrl_write_pulse[3] &&
            atu_ctrl_reg_id[2] && !n_is_in && n[ATU_LOG2_REGIONS-1:0] == atu_o) ?
            lbc_cdm_data[28] : int_atu_out_shift[atu_o];
        int_atu_out_invert[atu_o]  <= #TP (atu_ctrl_write_pulse[3] &&
            atu_ctrl_reg_id[2] && !n_is_in && n[ATU_LOG2_REGIONS-1:0] == atu_o) ?
            lbc_cdm_data[29] : int_atu_out_invert[atu_o];
        int_atu_out_en[atu_o]  <= #TP (atu_ctrl_write_pulse[3] &&
            atu_ctrl_reg_id[2] && !n_is_in && n[ATU_LOG2_REGIONS-1:0] == atu_o) ?
            lbc_cdm_data[31] : int_atu_out_en[atu_o];
      end
    end
end
//ST is an alias for msg_code
assign int_atu_out_st = reg_bcm36_nhs_d.int_atu_out_msg_code;

// -----------------------------------------------------------------------------
// Outbound Region n Lower Base Address Register
// -----------------------------------------------------------------------------
// atu_ctrl_reg_id      - 3
// Port Logic Offset    -`CFG_PL_REG + 20Ch
// -----------------------------------------------------------------------------

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin : proc_int_atu_out_base
  integer atu_o;
    if(!sticky_rst_n) begin
      for(atu_o = 0; atu_o < ATU_OUT_REGIONS; atu_o = atu_o + 1) begin
        int_atu_out_base[atu_o*ATU_REG_WD +: ATU_REG_WD] <=
            #TP {ATU_REG_WD{1'b0}};
       end
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      for(atu_o = 0; atu_o < ATU_OUT_REGIONS; atu_o = atu_o + 1) begin
        int_atu_out_base[atu_o*ATU_REG_WD +: ATU_REG_WD] <= #TP
            atu_ctrl_reg_id[3] && !n_is_in && n[ATU_LOG2_REGIONS-1:0] == atu_o?
            ~write_pulse_full[31 -: ATU_REG_WD] &
            int_atu_out_base[atu_o*ATU_REG_WD +: ATU_REG_WD] |
            write_pulse_full[31 -: ATU_REG_WD] &
            lbc_cdm_data[31 -: ATU_REG_WD] :
            int_atu_out_base[atu_o*ATU_REG_WD +: ATU_REG_WD];
        end
    end
end

// -----------------------------------------------------------------------------
// Outbound Region n Upper Base Address Register
// -----------------------------------------------------------------------------
// atu_ctrl_reg_id      - 4
// Port Logic Offset    -`CFG_PL_REG + 210h
// -----------------------------------------------------------------------------
// Only used when 64 bit system
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin : proc_int_atu_out_upr_base
  integer atu_o;
    if(!sticky_rst_n) begin
      for(atu_o = 0; atu_o < ATU_OUT_REGIONS; atu_o = atu_o + 1) begin
        int_atu_out_upr_base[atu_o*ATU_BASE_WD +: ATU_BASE_WD] <=
            #TP {ATU_BASE_WD{1'b0}};
        end
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      for(atu_o = 0; atu_o < ATU_OUT_REGIONS; atu_o = atu_o + 1) begin
        int_atu_out_upr_base[atu_o*ATU_BASE_WD +: ATU_BASE_WD] <= #TP
            atu_ctrl_reg_id[4] && !n_is_in && n[ATU_LOG2_REGIONS-1:0] == atu_o?
            ~write_pulse_full[0 +: ATU_BASE_WD] &
            int_atu_out_upr_base[atu_o*ATU_BASE_WD +: ATU_BASE_WD] |
            write_pulse_full[0 +: ATU_BASE_WD] &
            lbc_cdm_data[0 +: ATU_BASE_WD] :
            int_atu_out_upr_base[atu_o*ATU_BASE_WD +: ATU_BASE_WD];
        end
    end
end

// -----------------------------------------------------------------------------
// Outbound Region n Limit Address Register
// -----------------------------------------------------------------------------
// atu_ctrl_reg_id      - 5
// Port Logic Offset    -`CFG_PL_REG + 214h
// -----------------------------------------------------------------------------
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin : proc_int_atu_out_limit
  integer atu_o;
    if(!sticky_rst_n) begin
      for(atu_o = 0; atu_o < ATU_OUT_REGIONS; atu_o = atu_o + 1) begin
       int_atu_out_limit[atu_o*ATU_REG_WD +: ATU_REG_WD] <=
           #TP {ATU_REG_WD{1'b0}};
       end
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      for(atu_o = 0; atu_o < ATU_OUT_REGIONS; atu_o = atu_o + 1) begin
        int_atu_out_limit[atu_o*ATU_REG_WD +: ATU_REG_WD] <= #TP
            atu_ctrl_reg_id[5] && !n_is_in && n[ATU_LOG2_REGIONS-1:0] == atu_o?
            ~write_pulse_full[31 -: ATU_REG_WD] &
            int_atu_out_limit[atu_o*ATU_REG_WD +: ATU_REG_WD] |
            write_pulse_full[31 -: ATU_REG_WD] &
            lbc_cdm_data[31 -: ATU_REG_WD] :
            int_atu_out_limit[atu_o*ATU_REG_WD +: ATU_REG_WD];
        end
    end
end

// -----------------------------------------------------------------------------
// Outbound Region n Upper Limit Address Register
// -----------------------------------------------------------------------------
// atu_ctrl_reg_id      - 9
// Port Logic Offset    -`CFG_PL_REG + 224h
// -----------------------------------------------------------------------------
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin : proc_int_atu_out_uppr_limit
  integer atu_o;
    if(!sticky_rst_n) begin
      for(atu_o = 0; atu_o < ATU_OUT_REGIONS; atu_o = atu_o + 1) begin
       int_atu_out_uppr_limit[atu_o*ATU_UPR_LMT_WD +: ATU_UPR_LMT_WD] <=
           #TP {ATU_UPR_LMT_WD{1'b0}};
       end
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      for(atu_o = 0; atu_o < ATU_OUT_REGIONS; atu_o = atu_o + 1) begin
        int_atu_out_uppr_limit[atu_o*ATU_UPR_LMT_WD +: ATU_UPR_LMT_WD] <= #TP
            atu_ctrl_reg_id[9] && !n_is_in && n[ATU_LOG2_REGIONS-1:0] == atu_o?
            ~write_pulse_full[0 +: ATU_UPR_LMT_WD] &
            int_atu_out_uppr_limit[atu_o*ATU_UPR_LMT_WD +: ATU_UPR_LMT_WD] |
            write_pulse_full[0 +: ATU_UPR_LMT_WD] &
            lbc_cdm_data[0 +: ATU_UPR_LMT_WD] :
            int_atu_out_uppr_limit[atu_o*ATU_UPR_LMT_WD +: ATU_UPR_LMT_WD];
      end
    end
end


// -----------------------------------------------------------------------------
// Outbound Region n Lower Target Address Register
// -----------------------------------------------------------------------------
// atu_ctrl_reg_id      - 6
// Port Logic Offset    -`CFG_PL_REG + 218h
// -----------------------------------------------------------------------------

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin : proc_int_atu_out_lwr_trgt
  integer atu_o;
    if(!sticky_rst_n) begin
      for(atu_o = 0; atu_o < ATU_OUT_REGIONS; atu_o = atu_o + 1) begin
        int_atu_out_lwr_trgt[atu_o*ATU_REG_WD +: ATU_REG_WD] <=
            #TP {ATU_REG_WD{1'b0}};
      end
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      for(atu_o = 0; atu_o < ATU_OUT_REGIONS; atu_o = atu_o + 1) begin
        int_atu_out_lwr_trgt[atu_o*ATU_REG_WD +: ATU_REG_WD] <= #TP
            atu_ctrl_reg_id[6] && !n_is_in && n[ATU_LOG2_REGIONS-1:0] == atu_o?
            ~write_pulse_full[31 -: ATU_REG_WD] &
            int_atu_out_lwr_trgt[atu_o*ATU_REG_WD +: ATU_REG_WD] |
            write_pulse_full[31 -: ATU_REG_WD] &
            lbc_cdm_data[31 -: ATU_REG_WD] :
            int_atu_out_lwr_trgt[atu_o*ATU_REG_WD +: ATU_REG_WD];
      end
    end
end

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin : proc_int_atu_out_lwr_trgt_lwr
  integer atu_o;
    if(!sticky_rst_n) begin
      for(atu_o = 0; atu_o < ATU_OUT_REGIONS; atu_o = atu_o + 1) begin
        int_atu_out_lwr_trgt_lwr[atu_o*(ATU_REG_LWR_WD) +: ATU_REG_LWR_WD] <=
            #TP {(ATU_REG_LWR_WD){1'b0}};
       end
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      for(atu_o = 0; atu_o < ATU_OUT_REGIONS; atu_o = atu_o + 1) begin
        int_atu_out_lwr_trgt_lwr[atu_o*ATU_REG_LWR_WD +: ATU_REG_LWR_WD] <= #TP
            atu_ctrl_reg_id[6] && !n_is_in && n[ATU_LOG2_REGIONS-1:0] == atu_o?
            ~write_pulse_full[0 +: ATU_REG_LWR_WD] &
            int_atu_out_lwr_trgt_lwr[atu_o*ATU_REG_LWR_WD +: ATU_REG_LWR_WD] |
            write_pulse_full[0 +: ATU_REG_LWR_WD] &
            lbc_cdm_data[0 +: ATU_REG_LWR_WD] :
            int_atu_out_lwr_trgt_lwr[atu_o*ATU_REG_LWR_WD +: ATU_REG_LWR_WD];
      end
    end
end


// -----------------------------------------------------------------------------
// Outbound Region n Upper Target Address Register
// -----------------------------------------------------------------------------
// atu_ctrl_reg_id      - 7
// Port Logic Offset    -`CFG_PL_REG + 21Ch
// -----------------------------------------------------------------------------

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin : proc_int_atu_out_upr_trgt
  integer atu_o;
    if(!sticky_rst_n) begin
      for(atu_o = 0; atu_o < ATU_OUT_REGIONS; atu_o = atu_o + 1) begin
        int_atu_out_upr_trgt[atu_o*ATU_BASE_WD +: ATU_BASE_WD] <=
            #TP {ATU_BASE_WD{1'b0}};
        end
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      for(atu_o = 0; atu_o < ATU_OUT_REGIONS; atu_o = atu_o + 1) begin
        int_atu_out_upr_trgt[atu_o*ATU_BASE_WD +: ATU_BASE_WD] <= #TP
            atu_ctrl_reg_id[7] && !n_is_in && n[ATU_LOG2_REGIONS-1:0] == atu_o?
            ~write_pulse_full[0 +: ATU_BASE_WD] &
            int_atu_out_upr_trgt[atu_o*ATU_BASE_WD +: ATU_BASE_WD] |
            write_pulse_full[0 +: ATU_BASE_WD] &
            lbc_cdm_data[0 +: ATU_BASE_WD] :
            int_atu_out_upr_trgt[atu_o*ATU_BASE_WD +: ATU_BASE_WD];
        end
    end
end

// -----------------------------------------------------------------------------
// Outbound Region n Control Register 3
// -----------------------------------------------------------------------------
// atu_ctrl_reg_id      - 8
// Port Logic Offset    -`CFG_PL_REG + 220h
// -----------------------------------------------------------------------------


// Avoid undefined ranges when ATU_OUT_REGIONS < ATU_IN_REGIONS
//for(atu_o = ATU_OUT_REGIONS; atu_o < ATU_MAX_REGIONS; atu_o = atu_o + 1)
//begin : atu_out_null_region
    wire zero;
    assign zero = 1'b0;
    always @(*) begin : proc_atu_out_null

  integer atu_o;
  for(atu_o = ATU_OUT_REGIONS; atu_o < ATU_MAX_REGIONS; atu_o = atu_o + 1) begin
// ATU outbound Region controls
        int_atu_out_type[atu_o*5 +: 5]                  =  {5{zero}};
        int_atu_out_tc[atu_o*3 +: 3]                    =  {3{zero}};
        int_atu_out_td[atu_o]                           =  {zero};
        int_atu_out_attr[atu_o*ATTR_WD +: ATTR_WD]      =  {ATTR_WD{zero}};
        int_atu_out_at[atu_o*2 +: 2]                    =  {2{zero}};
        int_atu_out_func_num[atu_o*PF_WD +: PF_WD]      =  {PF_WD{zero}};
        int_atu_out_func_bypass[atu_o]                  =  {zero};
        int_atu_out_snp[atu_o]                          =  {zero};
        int_atu_out_hdr_flds_bypass[atu_o]              =  {zero};
        int_atu_out_inhibit_payload[atu_o]              =  {zero};
        int_atu_out_hdr_substitute_en[atu_o]            =  {zero};
        int_atu_out_tag_substitute_en[atu_o]            =  {zero};
        int_atu_out_tag[atu_o*TAG_SIZE +: TAG_SIZE]     =  {TAG_SIZE{zero}};
        int_atu_out_dma_bypass[atu_o]                   =  {zero};
        int_atu_out_msg_code[atu_o*8 +: 8]              =  {8{zero}};
        int_atu_out_th[atu_o]                           = {zero};
        int_atu_out_ph[atu_o*2 +: 2]                    = {2{zero}};
        int_atu_out_incr_rgn_size[atu_o]                = {zero};
// Mode Settings
        int_atu_out_shift[atu_o]                        =  {zero};
        int_atu_out_invert[atu_o]                       =  {zero};
// Region Enable
        int_atu_out_en[atu_o]                           =  {zero};
// Base, Limit and Target Registers
        int_atu_out_base[atu_o*ATU_REG_WD +: ATU_REG_WD] =
             {ATU_REG_WD{zero}};
        int_atu_out_upr_base[atu_o*ATU_BASE_WD +: ATU_BASE_WD] =
             {ATU_BASE_WD{zero}};
        int_atu_out_limit[atu_o*ATU_REG_WD +: ATU_REG_WD] =
             {ATU_REG_WD{zero}};
        int_atu_out_uppr_limit[atu_o*ATU_UPR_LMT_WD +: ATU_UPR_LMT_WD] =
             {ATU_UPR_LMT_WD{zero}};
        int_atu_out_lwr_trgt[atu_o*ATU_REG_WD +: ATU_REG_WD] =
             {ATU_REG_WD{zero}};
        int_atu_out_upr_trgt[atu_o*ATU_BASE_WD +: ATU_BASE_WD] =
             {ATU_BASE_WD{zero}};
        int_atu_out_lwr_trgt_lwr[atu_o*ATU_REG_LWR_WD +: ATU_REG_LWR_WD] =
             {ATU_REG_LWR_WD{zero}};
         end
    end
end else begin : atu_out_zero_region // ATU_OUT_REGIONS <= 0
    wire zero;
    assign zero = 1'b0;
    // When there are 0 regions drive all the controls to 0
    always @(*) begin : proc_atu_out_zero
// ATU outbound Region controls
        int_atu_out_type        = {ATU_IN_LESS_OUT_REGIONS*5{zero}};
        int_atu_out_tc          = {ATU_IN_LESS_OUT_REGIONS*3{zero}};
        int_atu_out_td          = {ATU_IN_LESS_OUT_REGIONS{zero}};
        int_atu_out_attr        = {ATU_IN_LESS_OUT_REGIONS*ATTR_WD{zero}};
        int_atu_out_at          = {ATU_IN_LESS_OUT_REGIONS*2{zero}};
        int_atu_out_func_num    = {ATU_IN_LESS_OUT_REGIONS*PF_WD{zero}};
        int_atu_out_func_bypass = {ATU_IN_LESS_OUT_REGIONS{zero}};
        int_atu_out_snp         = {ATU_IN_LESS_OUT_REGIONS{zero}};
        int_atu_out_hdr_flds_bypass = {ATU_IN_LESS_OUT_REGIONS{zero}};
        int_atu_out_inhibit_payload = {ATU_IN_LESS_OUT_REGIONS{zero}};
        int_atu_out_hdr_substitute_en = {ATU_IN_LESS_OUT_REGIONS{zero}};
        int_atu_out_tag_substitute_en =  {ATU_IN_LESS_OUT_REGIONS{zero}};
        int_atu_out_tag             =  {ATU_IN_LESS_OUT_REGIONS*TAG_SIZE{zero}};
        int_atu_out_dma_bypass  = {ATU_IN_LESS_OUT_REGIONS{zero}};
        int_atu_out_msg_code    = {ATU_IN_LESS_OUT_REGIONS*8{zero}};
        int_atu_out_th          = {ATU_IN_LESS_OUT_REGIONS{zero}};
        int_atu_out_ph          = {ATU_IN_LESS_OUT_REGIONS*2{zero}};
        int_atu_out_incr_rgn_size = {ATU_IN_LESS_OUT_REGIONS{zero}};
// Mode Settings
        int_atu_out_shift       = {ATU_IN_LESS_OUT_REGIONS{zero}};
        int_atu_out_invert      = {ATU_IN_LESS_OUT_REGIONS{zero}};
// Region Enable
        int_atu_out_en          = {ATU_IN_LESS_OUT_REGIONS{zero}};
// Base, Limit and Target Registers
        int_atu_out_base        = {ATU_IN_LESS_OUT_REGIONS*ATU_REG_WD{zero}};
        int_atu_out_upr_base    = {ATU_IN_LESS_OUT_REGIONS*ATU_BASE_WD{zero}};
        int_atu_out_limit       = {ATU_IN_LESS_OUT_REGIONS*ATU_REG_WD{zero}};
        int_atu_out_uppr_limit  = {ATU_IN_LESS_OUT_REGIONS*ATU_UPR_LMT_WD{zero}};
        int_atu_out_lwr_trgt    = {ATU_IN_LESS_OUT_REGIONS*ATU_REG_WD{zero}};
        int_atu_out_upr_trgt    = {ATU_IN_LESS_OUT_REGIONS*ATU_BASE_WD{zero}};
        int_atu_out_lwr_trgt_lwr = {ATU_IN_LESS_OUT_REGIONS*ATU_REG_LWR_WD{zero}};
    end
// Output Assignments
// ATU outbound Region controls
assign atu_reg_out_type             = 0;
assign atu_reg_out_tc               = 0;
assign atu_reg_out_td               = 0;
assign atu_reg_out_attr             = 0;
assign atu_reg_out_at               = 0;
assign atu_reg_out_func_num         = 0;
assign atu_reg_out_func_bypass      = 0;
assign atu_reg_out_snp              = 0;
assign atu_reg_out_inhibit_payload  = 0;
assign atu_reg_out_hdr_substitute_en = 0;
assign atu_reg_out_tag_substitute_en = 0;
assign atu_reg_out_tag              = 0;
assign atu_reg_out_dma_bypass       = 0;
assign atu_reg_out_msg_code         = 0;
assign atu_reg_out_th               = 0;
assign atu_reg_out_ph               = 0;
assign atu_reg_out_st               = 0;
assign atu_reg_out_incr_rgn_size    = 0;
assign atu_reg_out_hdr_flds_bypass  = 0;
// Mode Settings
assign atu_reg_out_shift            = 0;
assign atu_reg_out_invert           = 0;
// Region Enable
assign atu_reg_out_en               = 0;
// Base, Limit and Target Registers
assign atu_reg_out_base             = 0;
assign atu_reg_out_upr_base         = 0;
assign atu_reg_out_limit            = 0;
assign atu_reg_out_uppr_limit       = 0;
assign atu_reg_out_lwr_trgt         = 0;
assign atu_reg_out_upr_trgt         = 0;
assign atu_reg_out_lwr_trgt_lwr     = 0;

end
endgenerate


generate
if (ATU_IN_REGIONS > 0) begin : gen_atu_in
// Output assignments
// ATU inbound Region controls
assign atu_reg_in_type              = reg_bcm36_nhs_d.int_atu_in_type[5*ATU_IN_REGIONS-1:0];
assign atu_reg_in_tc                = reg_bcm36_nhs_d.int_atu_in_tc[3*ATU_IN_REGIONS-1:0];
assign atu_reg_in_td                = reg_bcm36_nhs_d.int_atu_in_td[ATU_IN_REGIONS-1:0];
assign atu_reg_in_attr              = reg_bcm36_nhs_d.int_atu_in_attr[ATTR_WD*ATU_IN_REGIONS-1:0];
assign atu_reg_in_at                = reg_bcm36_nhs_d.int_atu_in_at[2*ATU_IN_REGIONS-1:0];
assign atu_reg_in_func_num          = reg_bcm36_nhs_d.int_atu_in_func_num[PF_WD*ATU_IN_REGIONS-1:0];
assign atu_reg_in_msg_code          = reg_bcm36_nhs_d.int_atu_in_msg_code[8*ATU_IN_REGIONS-1:0];
assign atu_reg_in_bar_num           = reg_bcm36_nhs_d.int_atu_in_bar_num[3*ATU_IN_REGIONS-1:0];
assign atu_reg_in_th                = reg_bcm36_nhs_d.int_atu_in_th[ATU_IN_REGIONS-1:0];
assign atu_reg_in_ph                = reg_bcm36_nhs_d.int_atu_in_ph[2*ATU_IN_REGIONS-1:0];
assign atu_reg_in_st                = int_atu_in_st[8*ATU_IN_REGIONS-1:0];
// Inbound field match enables
assign atu_reg_in_tc_match_en       =
    reg_bcm36_nhs_d.int_atu_in_tc_match_en[ATU_IN_REGIONS-1:0];
assign atu_reg_in_td_match_en       =
    reg_bcm36_nhs_d.int_atu_in_td_match_en[ATU_IN_REGIONS-1:0];
assign atu_reg_in_attr_match_en     =
    reg_bcm36_nhs_d.int_atu_in_attr_match_en[ATU_IN_REGIONS-1:0];
assign atu_reg_in_at_match_en       =
    reg_bcm36_nhs_d.int_atu_in_at_match_en[ATU_IN_REGIONS-1:0];
assign atu_reg_in_func_match_en     =
    reg_bcm36_nhs_d.int_atu_in_func_match_en[ATU_IN_REGIONS-1:0];
assign atu_reg_in_msgcode_match_en  =
    reg_bcm36_nhs_d.int_atu_in_msgcode_match_en[ATU_IN_REGIONS-1:0];
assign atu_reg_in_th_match_en       =
    reg_bcm36_nhs_d.int_atu_in_th_match_en[ATU_IN_REGIONS-1:0];
assign atu_reg_in_ph_match_en       =
    reg_bcm36_nhs_d.int_atu_in_ph_match_en[ATU_IN_REGIONS-1:0];
assign atu_reg_in_st_match_en       =
    int_atu_in_st_match_en[ATU_IN_REGIONS-1:0];
assign atu_reg_in_single_addr_loc_en  = reg_bcm36_nhs_d.int_atu_in_single_addr_loc_en[ATU_IN_REGIONS-1:0];
assign atu_reg_in_msg_type_match_mode = reg_bcm36_nhs_d.int_atu_in_msg_type_match_mode[ATU_IN_REGIONS-1:0];
// Response and mode settings
assign atu_reg_in_rsp_code          = reg_bcm36_nhs_d.int_atu_in_rsp_code[2*ATU_IN_REGIONS-1:0];
assign atu_reg_in_fuzzy             = reg_bcm36_nhs_d.int_atu_in_fuzzy[ATU_IN_REGIONS-1:0];
assign atu_reg_in_shift             = reg_bcm36_nhs_d.int_atu_in_shift[ATU_IN_REGIONS-1:0];
assign atu_reg_in_invert            = reg_bcm36_nhs_d.int_atu_in_invert[ATU_IN_REGIONS-1:0];
assign atu_reg_in_bar_match         = reg_bcm36_nhs_d.int_atu_in_bar_match[ATU_IN_REGIONS-1:0];
// Region Enable
assign atu_reg_in_en                = reg_bcm36_nhs_d.int_atu_in_en[ATU_IN_REGIONS-1:0];
// Base, Limit and Target Registers
assign atu_reg_in_base              =
    reg_bcm36_nhs_d.int_atu_in_base[ATU_REG_WD*ATU_IN_REGIONS-1:0];
assign atu_reg_in_upr_base          =
    reg_bcm36_nhs_d.int_atu_in_upr_base[ATU_BASE_WD*ATU_IN_REGIONS-1:0];
assign atu_reg_in_limit            =
    reg_bcm36_nhs_d.int_atu_in_limit[ATU_REG_WD*ATU_IN_REGIONS-1:0];
assign atu_reg_in_cbuf_incr         = reg_bcm36_nhs_d.int_atu_in_cbuf_incr[4*ATU_IN_REGIONS-1:0];
assign atu_reg_in_cbuf_restart      = int_atu_in_cbuf_restart[ATU_IN_REGIONS-1:0];
assign atu_reg_in_uppr_limit            =
    reg_bcm36_nhs_d.int_atu_in_uppr_limit[ATU_UPR_LMT_WD*ATU_IN_REGIONS-1:0];
assign atu_reg_in_lwr_trgt          =
    reg_bcm36_nhs_d.int_atu_in_lwr_trgt[ATU_REG_WD*ATU_IN_REGIONS-1:0];
assign atu_reg_in_upr_trgt          =
    reg_bcm36_nhs_d.int_atu_in_upr_trgt[ATU_BASE_WD*ATU_IN_REGIONS-1:0];
assign atu_reg_in_incr_rgn_size      = reg_bcm36_nhs_d.int_atu_in_incr_rgn_size[ATU_IN_REGIONS-1:0];

// -----------------------------------------------------------------------------
// Inbound Region n Control Register 1
// -----------------------------------------------------------------------------
// atu_ctrl_reg_id      - 1
// Port Logic Offset    -`CFG_PL_REG + 204h
// -----------------------------------------------------------------------------
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin : proc_atu_in_ctrl_1
    integer atu_i;
    if(!sticky_rst_n) begin
      for(atu_i = 0; atu_i < ATU_IN_REGIONS; atu_i = atu_i + 1) begin
        int_atu_in_type[atu_i*5 +: 5]             <= #TP {5{1'b0}};
        int_atu_in_tc[atu_i*3 +: 3]               <= #TP {3{1'b0}};
        int_atu_in_td[atu_i]                      <= #TP 1'b0;
        int_atu_in_attr[atu_i*ATTR_WD +: ATTR_WD] <= #TP {2{1'b0}};
        int_atu_in_at[atu_i*2 +: 2]               <= #TP {2{1'b0}};
        int_atu_in_func_num[atu_i*PF_WD +: PF_WD] <= #TP {PF_WD{1'b0}};
        int_atu_in_th[atu_i]                      <= #TP 1'b0;
        int_atu_in_ph[atu_i*2 +: 2]               <= #TP {2{1'b0}};
        int_atu_in_incr_rgn_size[atu_i]            <= #TP 1'b0;              // Maximum Region Size = 4GB by default
      end
    end
    else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      for(atu_i = 0; atu_i < ATU_IN_REGIONS; atu_i = atu_i + 1) begin
        int_atu_in_type[atu_i*5 +: 5]  <= #TP (atu_ctrl_write_pulse[0] &&
            atu_ctrl_reg_id[1] && n_is_in && n == atu_i) ?
            lbc_cdm_data[4:0] : int_atu_in_type[atu_i*5 +: 5];
        int_atu_in_tc[atu_i*3 +: 3]  <= #TP (atu_ctrl_write_pulse[0] &&
            atu_ctrl_reg_id[1] && n_is_in && n == atu_i) ?
            lbc_cdm_data[7:5] : int_atu_in_tc[atu_i*3 +: 3];
        int_atu_in_td[atu_i]  <= #TP (atu_ctrl_write_pulse[1] &&
            atu_ctrl_reg_id[1] && n_is_in && n == atu_i) ?
            lbc_cdm_data[8] : int_atu_in_td[atu_i];
        int_atu_in_attr[atu_i*ATTR_WD +: ATTR_WD]  <= #TP (atu_ctrl_write_pulse[1] &&
            atu_ctrl_reg_id[1] && n_is_in && n == atu_i) ?
            lbc_cdm_data[9 +: ATTR_WD] : int_atu_in_attr[atu_i*ATTR_WD +: ATTR_WD];
        int_atu_in_th[atu_i]         <= #TP (atu_ctrl_write_pulse[1] &&
            atu_ctrl_reg_id[1] && n_is_in && n == atu_i) ?
            lbc_cdm_data[12] : int_atu_in_th[atu_i];
        int_atu_in_incr_rgn_size[atu_i]  <= #TP (atu_ctrl_write_pulse[1] &&
            atu_ctrl_reg_id[1] && n_is_in && n == atu_i) ?
            lbc_cdm_data[13] : int_atu_in_incr_rgn_size[atu_i];
        int_atu_in_at[atu_i*2 +: 2]  <= #TP (atu_ctrl_write_pulse[2] &&
            atu_ctrl_reg_id[1] && n_is_in && n == atu_i) ?
            lbc_cdm_data[17:16] : int_atu_in_at[atu_i*2 +: 2];
        int_atu_in_ph[atu_i*2 +: 2]  <= #TP (atu_ctrl_write_pulse[2] &&
            atu_ctrl_reg_id[1] && n_is_in && n == atu_i) ?
            lbc_cdm_data[19:18] : int_atu_in_ph[atu_i*2 +: 2];
        int_atu_in_func_num[atu_i*PF_WD +: PF_WD]  <= #TP
        (atu_ctrl_reg_id[1] && n_is_in && n == atu_i) ?
            ~write_pulse_full[20 +: PF_WD] &
            int_atu_in_func_num[atu_i*PF_WD +: PF_WD] |
            write_pulse_full[20 +: PF_WD] & lbc_cdm_data[20 +: PF_WD] :
            int_atu_in_func_num[atu_i*PF_WD +: PF_WD];
      end
    end
end
// -----------------------------------------------------------------------------
// Inbound Region n Control Register 2
// -----------------------------------------------------------------------------
// atu_ctrl_reg_id      - 2
// Port Logic Offset    -`CFG_PL_REG + 208h
// -----------------------------------------------------------------------------
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin : proc_atu_in_ctrl_2
    integer atu_i;
    if(!sticky_rst_n) begin
      for(atu_i = 0; atu_i < ATU_IN_REGIONS; atu_i = atu_i + 1) begin
        int_atu_in_msg_code[atu_i*8 +: 8]   <= #TP {8{1'b0}};
        int_atu_in_bar_num[atu_i*3 +: 3]    <= #TP {3{1'b0}};
        int_atu_in_msg_type_match_mode[atu_i] <= #TP 1'b0;
        int_atu_in_tc_match_en[atu_i]       <= #TP 1'b0;
        int_atu_in_td_match_en[atu_i]       <= #TP 1'b0;
        int_atu_in_attr_match_en[atu_i]     <= #TP 1'b0;
        int_atu_in_at_match_en[atu_i]       <= #TP 1'b0;
        int_atu_in_func_match_en[atu_i]     <= #TP 1'b0;
        int_atu_in_msgcode_match_en[atu_i]  <= #TP 1'b0;
        int_atu_in_th_match_en[atu_i]       <= #TP 1'b0;
        int_atu_in_ph_match_en[atu_i]       <= #TP 1'b0;
        int_atu_in_single_addr_loc_en[atu_i] <= #TP 1'b0;
// Response and mode settings
        int_atu_in_rsp_code[atu_i*2 +: 2]   <= #TP {2{1'b0}};
        int_atu_in_fuzzy[atu_i]             <= #TP 1'b0;
        int_atu_in_shift[atu_i]             <= #TP 1'b0;
        int_atu_in_invert[atu_i]            <= #TP 1'b0;
        int_atu_in_bar_match[atu_i]         <= #TP 1'b0;
        int_atu_in_en[atu_i]                <= #TP 1'b0;
      end
    end
    else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      for(atu_i = 0; atu_i < ATU_IN_REGIONS; atu_i = atu_i + 1) begin
        int_atu_in_msg_code[atu_i*8 +: 8]  <= #TP (atu_ctrl_write_pulse[0] &&
            atu_ctrl_reg_id[2] && n_is_in && n == atu_i) ?
            lbc_cdm_data[7:0] : int_atu_in_msg_code[atu_i*8 +: 8];
        int_atu_in_bar_num[atu_i*3 +: 3]  <= #TP (atu_ctrl_write_pulse[1] &&
            atu_ctrl_reg_id[2] && n_is_in && n == atu_i) ?
            lbc_cdm_data[10:8] : int_atu_in_bar_num[atu_i*3 +: 3];
        int_atu_in_msg_type_match_mode[atu_i] <= #TP (atu_ctrl_write_pulse[1] &&
            atu_ctrl_reg_id[2] && n_is_in && n == atu_i) ?
            lbc_cdm_data[13] : int_atu_in_msg_type_match_mode[atu_i];
        int_atu_in_tc_match_en[atu_i]  <= #TP (atu_ctrl_write_pulse[1] &&
            atu_ctrl_reg_id[2] && n_is_in && n == atu_i) ?
            lbc_cdm_data[14] : int_atu_in_tc_match_en[atu_i];
        int_atu_in_td_match_en[atu_i]  <= #TP (atu_ctrl_write_pulse[1] &&
            atu_ctrl_reg_id[2] && n_is_in && n == atu_i) ?
            lbc_cdm_data[15] : int_atu_in_td_match_en[atu_i];
        int_atu_in_attr_match_en[atu_i]  <= #TP (atu_ctrl_write_pulse[2] &&
            atu_ctrl_reg_id[2] && n_is_in && n == atu_i) ?
            lbc_cdm_data[16] : int_atu_in_attr_match_en[atu_i];
        int_atu_in_th_match_en[atu_i]    <= #TP (atu_ctrl_write_pulse[2] &&
            atu_ctrl_reg_id[2] && n_is_in && n == atu_i) ?
            lbc_cdm_data[17] : int_atu_in_th_match_en[atu_i];
        int_atu_in_at_match_en[atu_i]  <= #TP (atu_ctrl_write_pulse[2] &&
            atu_ctrl_reg_id[2] && n_is_in && n == atu_i) ?
            lbc_cdm_data[18] : int_atu_in_at_match_en[atu_i];
        int_atu_in_func_match_en[atu_i]  <= #TP (atu_ctrl_write_pulse[2] &&
            atu_ctrl_reg_id[2] && n_is_in && n == atu_i) ?
            lbc_cdm_data[19] : int_atu_in_func_match_en[atu_i];
        int_atu_in_msgcode_match_en[atu_i]  <= #TP (atu_ctrl_write_pulse[2] &&
            atu_ctrl_reg_id[2] && n_is_in && n == atu_i) ?
            lbc_cdm_data[21] : int_atu_in_msgcode_match_en[atu_i];
        int_atu_in_ph_match_en[atu_i]    <= #TP (atu_ctrl_write_pulse[2] &&
            atu_ctrl_reg_id[2] && n_is_in && n == atu_i) ?
            lbc_cdm_data[22] : int_atu_in_ph_match_en[atu_i];
        int_atu_in_single_addr_loc_en[atu_i] <= #TP (atu_ctrl_write_pulse[2] &&
            atu_ctrl_reg_id[2] && n_is_in && n == atu_i) ?
            lbc_cdm_data[23] : int_atu_in_single_addr_loc_en[atu_i];
        int_atu_in_rsp_code[atu_i*2 +: 2]  <= #TP (atu_ctrl_write_pulse[3] &&
            atu_ctrl_reg_id[2] && n_is_in && n == atu_i) ?
            lbc_cdm_data[25:24] : int_atu_in_rsp_code[atu_i*2 +: 2];
        int_atu_in_fuzzy[atu_i]  <= #TP (atu_ctrl_write_pulse[3] &&
            atu_ctrl_reg_id[2] && n_is_in && n == atu_i) ?
            lbc_cdm_data[27] : int_atu_in_fuzzy[atu_i];
        int_atu_in_shift[atu_i]  <= #TP (atu_ctrl_write_pulse[3] &&
            atu_ctrl_reg_id[2] && n_is_in && n == atu_i) ?
            lbc_cdm_data[28] : int_atu_in_shift[atu_i];
        int_atu_in_invert[atu_i]  <= #TP (atu_ctrl_write_pulse[3] &&
            atu_ctrl_reg_id[2] && n_is_in && n == atu_i) ?
            lbc_cdm_data[29] : int_atu_in_invert[atu_i];
        int_atu_in_bar_match[atu_i]  <= #TP (atu_ctrl_write_pulse[3] &&
            atu_ctrl_reg_id[2] && n_is_in && n == atu_i) ?
            lbc_cdm_data[30] : int_atu_in_bar_match[atu_i];
        int_atu_in_en[atu_i]  <= #TP (atu_ctrl_write_pulse[3] &&
            atu_ctrl_reg_id[2] && n_is_in && n == atu_i) ?
            lbc_cdm_data[31] : int_atu_in_en[atu_i];
        end
    end
end
// ST is an alias for msg_code
assign int_atu_in_st = int_atu_in_msg_code;
assign int_atu_in_st_match_en = int_atu_in_msgcode_match_en;

// -----------------------------------------------------------------------------
// Inbound Region n Lower Base Address Register
// -----------------------------------------------------------------------------
// atu_ctrl_reg_id      - 3
// Port Logic Offset    -`CFG_PL_REG + 20Ch
// -----------------------------------------------------------------------------

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin : proc_int_atu_in_base
    integer atu_i;
    if(!sticky_rst_n) begin
      for(atu_i = 0; atu_i < ATU_IN_REGIONS; atu_i = atu_i + 1) begin
        int_atu_in_base[atu_i*ATU_REG_WD +: ATU_REG_WD] <=
            #TP {ATU_REG_WD{1'b0}};
        end
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      for(atu_i = 0; atu_i < ATU_IN_REGIONS; atu_i = atu_i + 1) begin
        int_atu_in_base[atu_i*ATU_REG_WD +: ATU_REG_WD] <= #TP
            atu_ctrl_reg_id[3] && n_is_in && n == atu_i?
            ~write_pulse_full[31 -: ATU_REG_WD] &
            int_atu_in_base[atu_i*ATU_REG_WD +: ATU_REG_WD] |
            write_pulse_full[31 -: ATU_REG_WD] &
            lbc_cdm_data[31 -: ATU_REG_WD] :
            int_atu_in_base[atu_i*ATU_REG_WD +: ATU_REG_WD];
        end
    end
end

// -----------------------------------------------------------------------------
// Inbound Region n Upper Base Address Register
// -----------------------------------------------------------------------------
// atu_ctrl_reg_id      - 4
// Port Logic Offset    -`CFG_PL_REG + 210h
// -----------------------------------------------------------------------------

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin : proc_int_atu_in_upr_base
    integer atu_i;
    if(!sticky_rst_n) begin
      for(atu_i = 0; atu_i < ATU_IN_REGIONS; atu_i = atu_i + 1) begin
        int_atu_in_upr_base[atu_i*ATU_BASE_WD +: ATU_BASE_WD] <=
            #TP {ATU_BASE_WD{1'b0}};
      end
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      for(atu_i = 0; atu_i < ATU_IN_REGIONS; atu_i = atu_i + 1) begin
        int_atu_in_upr_base[atu_i*ATU_BASE_WD +: ATU_BASE_WD] <= #TP
            atu_ctrl_reg_id[4] && n_is_in && n == atu_i?
            ~write_pulse_full[0 +: ATU_BASE_WD] &
            int_atu_in_upr_base[atu_i*ATU_BASE_WD +: ATU_BASE_WD] |
            write_pulse_full[0 +: ATU_BASE_WD] &
            lbc_cdm_data[0 +: ATU_BASE_WD] :
            int_atu_in_upr_base[atu_i*ATU_BASE_WD +: ATU_BASE_WD];
      end
    end
end

// -----------------------------------------------------------------------------
// Inbound Region n Limit Address Register
// -----------------------------------------------------------------------------
// atu_ctrl_reg_id      - 5
// Port Logic Offset    -`CFG_PL_REG + 214h
// -----------------------------------------------------------------------------
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin : proc_int_atu_in_limit
    integer atu_i;
    if(!sticky_rst_n) begin
      for(atu_i = 0; atu_i < ATU_IN_REGIONS; atu_i = atu_i + 1) begin
       int_atu_in_limit[atu_i*ATU_REG_WD +: ATU_REG_WD] <=
           #TP {ATU_REG_WD{1'b0}};
       int_atu_in_cbuf_incr[atu_i*4 +: 4] <= #TP 4'b0000;
       int_atu_in_cbuf_restart[atu_i]     <= #TP 1'b0;
       end
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      for(atu_i = 0; atu_i < ATU_IN_REGIONS; atu_i = atu_i + 1) begin
        int_atu_in_limit[atu_i*ATU_REG_WD +: ATU_REG_WD] <= #TP
            atu_ctrl_reg_id[5] && n_is_in && n == atu_i?
            ~write_pulse_full[31 -: ATU_REG_WD] &
            int_atu_in_limit[atu_i*ATU_REG_WD +: ATU_REG_WD] |
            write_pulse_full[31 -: ATU_REG_WD] &
            lbc_cdm_data[31 -: ATU_REG_WD] :
            int_atu_in_limit[atu_i*ATU_REG_WD +: ATU_REG_WD];
       int_atu_in_cbuf_incr[atu_i*4 +: 4] <= #TP (atu_ctrl_write_pulse[0] &&
            atu_ctrl_reg_id[5] && n_is_in && n == atu_i) ?
            lbc_cdm_data[3:0] : int_atu_in_cbuf_incr[atu_i*4 +: 4];
       int_atu_in_cbuf_restart[atu_i]     <= #TP (atu_ctrl_write_pulse[0] &&
            atu_ctrl_reg_id[5] && n_is_in && n == atu_i) ? 1'b1 : 1'b0;
      end
    end
end

// -----------------------------------------------------------------------------
// Inbound Region n Upper Limit Address Register
// -----------------------------------------------------------------------------
// atu_ctrl_reg_id      - 9
// Port Logic Offset    -`CFG_PL_REG + 224h
// -----------------------------------------------------------------------------
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin : proc_int_atu_in_uppr_limit
    integer atu_i;
    if(!sticky_rst_n) begin
      for(atu_i = 0; atu_i < ATU_IN_REGIONS; atu_i = atu_i + 1) begin
       int_atu_in_uppr_limit[atu_i*ATU_UPR_LMT_WD +: ATU_UPR_LMT_WD] <=
           #TP {ATU_UPR_LMT_WD{1'b0}};
       end
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      for(atu_i = 0; atu_i < ATU_IN_REGIONS; atu_i = atu_i + 1) begin
        int_atu_in_uppr_limit[atu_i*ATU_UPR_LMT_WD +: ATU_UPR_LMT_WD] <= #TP
            atu_ctrl_reg_id[9] && n_is_in && n == atu_i?
            ~write_pulse_full[0 +: ATU_UPR_LMT_WD] &
            int_atu_in_uppr_limit[atu_i*ATU_UPR_LMT_WD +: ATU_UPR_LMT_WD] |
            write_pulse_full[0 +: ATU_UPR_LMT_WD] &
            lbc_cdm_data[0 +: ATU_UPR_LMT_WD] :
            int_atu_in_uppr_limit[atu_i*ATU_UPR_LMT_WD +: ATU_UPR_LMT_WD];
      end
    end
end


// -----------------------------------------------------------------------------
// Inbound Region n Lower Target Address Register
// -----------------------------------------------------------------------------
// atu_ctrl_reg_id      - 6
// Port Logic Offset    -`CFG_PL_REG + 218h
// -----------------------------------------------------------------------------

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin : proc_int_atu_in_lwr_trgt
    integer atu_i;
    if(!sticky_rst_n) begin
      for(atu_i = 0; atu_i < ATU_IN_REGIONS; atu_i = atu_i + 1) begin
        int_atu_in_lwr_trgt[atu_i*ATU_REG_WD +: ATU_REG_WD] <=
            #TP {ATU_REG_WD{1'b0}};
      end
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      for(atu_i = 0; atu_i < ATU_IN_REGIONS; atu_i = atu_i + 1) begin
        int_atu_in_lwr_trgt[atu_i*ATU_REG_WD +: ATU_REG_WD] <= #TP
            atu_ctrl_reg_id[6] && n_is_in && n == atu_i?
            ~write_pulse_full[31 -: ATU_REG_WD] &
            int_atu_in_lwr_trgt[atu_i*ATU_REG_WD +: ATU_REG_WD] |
            write_pulse_full[31 -: ATU_REG_WD] &
            lbc_cdm_data[31 -: ATU_REG_WD] :
            int_atu_in_lwr_trgt[atu_i*ATU_REG_WD +: ATU_REG_WD];
      end
    end
end

// -----------------------------------------------------------------------------
// Inbound Region n Upper Target Address Register
// -----------------------------------------------------------------------------
// atu_ctrl_reg_id      - 7
// Port Logic Offset    -`CFG_PL_REG + 21Ch
// -----------------------------------------------------------------------------
// Only used when 64 bit system
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin : proc_int_atu_in_upr_trgt
    integer atu_i;
    if(!sticky_rst_n) begin
      for(atu_i = 0; atu_i < ATU_IN_REGIONS; atu_i = atu_i + 1) begin
        int_atu_in_upr_trgt[atu_i*ATU_BASE_WD +: ATU_BASE_WD] <=
            #TP {ATU_BASE_WD{1'b0}};
        end
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      for(atu_i = 0; atu_i < ATU_IN_REGIONS; atu_i = atu_i + 1) begin
        int_atu_in_upr_trgt[atu_i*ATU_BASE_WD +: ATU_BASE_WD] <= #TP
            IN64 && atu_ctrl_reg_id[7] && n_is_in && n == atu_i?
            ~write_pulse_full[0 +: ATU_BASE_WD] &
            int_atu_in_upr_trgt[atu_i*ATU_BASE_WD +: ATU_BASE_WD] |
            write_pulse_full[0 +: ATU_BASE_WD] &
            lbc_cdm_data[0 +: ATU_BASE_WD] :
            int_atu_in_upr_trgt[atu_i*ATU_BASE_WD +: ATU_BASE_WD];
       end
    end
end

// -----------------------------------------------------------------------------
// Inbound Region n Control Register 3
// -----------------------------------------------------------------------------
// atu_ctrl_reg_id      - 8
// Port Logic Offset    -`CFG_PL_REG + 220h
// -----------------------------------------------------------------------------

// Avoid undefined ranges when ATU_IN_REGIONS < ATU_OUT_REGIONS
    wire zero;
    assign zero = 1'b0;
    always @(*) begin : proc_atu_in_null
      integer atu_i;
      for(atu_i = ATU_IN_REGIONS; atu_i < ATU_MAX_REGIONS; atu_i = atu_i + 1) begin
// ATU inbound Region controls
        int_atu_in_type[atu_i*5 +: 5]                   = {5{zero}};
        int_atu_in_tc[atu_i*3 +: 3]                     = {3{zero}};
        int_atu_in_td[atu_i]                            = {{zero}};
        int_atu_in_attr[atu_i*ATTR_WD +: ATTR_WD]       = {ATTR_WD{zero}};
        int_atu_in_at[atu_i*2 +: 2]                     = {2{zero}};
        int_atu_in_func_num[atu_i*PF_WD +: PF_WD]       = {PF_WD{zero}};
        int_atu_in_msg_code[atu_i*8 +: 8]   = {8{zero}};
        int_atu_in_bar_num[atu_i*3 +: 3]    = {3{zero}};
        int_atu_in_msg_type_match_mode[atu_i] = {zero};
        int_atu_in_th[atu_i]                = {zero};
        int_atu_in_ph[atu_i*2 +: 2]         = {2{zero}};
        int_atu_in_incr_rgn_size[atu_i]     = {zero};
// Inbound field match enables
        int_atu_in_tc_match_en[atu_i]       = {zero};
        int_atu_in_td_match_en[atu_i]       = {zero};
        int_atu_in_attr_match_en[atu_i]     = {zero};
        int_atu_in_at_match_en[atu_i]       = {zero};
        int_atu_in_func_match_en[atu_i]     = {zero};
        int_atu_in_msgcode_match_en[atu_i]  = {zero};
        int_atu_in_th_match_en[atu_i]       = {zero};
        int_atu_in_ph_match_en[atu_i]       = {zero};
        int_atu_in_single_addr_loc_en[atu_i] = {zero};
// Response and mode settings
        int_atu_in_rsp_code[atu_i*2 +: 2]   = {2{zero}};
        int_atu_in_fuzzy[atu_i]             = {zero};
        int_atu_in_shift[atu_i]             = {zero};
        int_atu_in_invert[atu_i]            = {zero};
        int_atu_in_bar_match[atu_i]         = {zero};
// Region Enable
        int_atu_in_en[atu_i]                = {zero};
// Base, Limit and Target Registers
        int_atu_in_base[atu_i*ATU_REG_WD +: ATU_REG_WD] =
            {ATU_REG_WD{zero}};
        int_atu_in_upr_base[atu_i*ATU_BASE_WD +: ATU_BASE_WD] =
            {ATU_BASE_WD{zero}};
        int_atu_in_limit[atu_i*ATU_REG_WD +: ATU_REG_WD] =
            {ATU_REG_WD{zero}};
        int_atu_in_cbuf_incr[atu_i*4 +: 4]   = {4{zero}};
        int_atu_in_cbuf_restart[atu_i]       = {zero};
        int_atu_in_uppr_limit[atu_i*ATU_UPR_LMT_WD +: ATU_UPR_LMT_WD] =
            {ATU_UPR_LMT_WD{zero}};
        int_atu_in_lwr_trgt[atu_i*ATU_REG_WD +: ATU_REG_WD] =
            {ATU_REG_WD{zero}};
        int_atu_in_upr_trgt[atu_i*ATU_BASE_WD +: ATU_BASE_WD] =
            {ATU_BASE_WD{zero}};
      end
    end
end
else begin : atu_in_zero_region // ATU_IN_REGIONS <= 0
    wire zero;
    assign zero = 1'b0;
    // When there are 0 regions drive all the controls to 0
    always @(*) begin : proc_atu_in_zero
// ATU inbound Region controls
        int_atu_in_type             = {5*ATU_MAX_REGIONS{zero}};
        int_atu_in_tc               = {3*ATU_MAX_REGIONS{zero}};
        int_atu_in_td               = {ATU_MAX_REGIONS{zero}};
        int_atu_in_attr             = {ATTR_WD*ATU_MAX_REGIONS{zero}};
        int_atu_in_at               = {2*ATU_MAX_REGIONS{zero}};
        int_atu_in_func_num         = {PF_WD*ATU_MAX_REGIONS{zero}};
        int_atu_in_msg_code         = {8*ATU_MAX_REGIONS{zero}};
        int_atu_in_bar_num          = {3*ATU_MAX_REGIONS{zero}};
        int_atu_in_th               = {ATU_MAX_REGIONS{zero}};
        int_atu_in_ph               = {2*ATU_MAX_REGIONS{zero}};
        int_atu_in_incr_rgn_size    = {ATU_MAX_REGIONS{zero}};
// Inbound field match enables
        int_atu_in_msg_type_match_mode = {ATU_MAX_REGIONS{zero}};
        int_atu_in_tc_match_en      = {ATU_MAX_REGIONS{zero}};
        int_atu_in_td_match_en      = {ATU_MAX_REGIONS{zero}};
        int_atu_in_attr_match_en    = {ATU_MAX_REGIONS{zero}};
        int_atu_in_at_match_en      = {ATU_MAX_REGIONS{zero}};
        int_atu_in_func_match_en    = {ATU_MAX_REGIONS{zero}};
        int_atu_in_msgcode_match_en = {ATU_MAX_REGIONS{zero}};
        int_atu_in_th_match_en      = {ATU_MAX_REGIONS{zero}};
        int_atu_in_ph_match_en      = {ATU_MAX_REGIONS{zero}};
        int_atu_in_single_addr_loc_en = {ATU_MAX_REGIONS{zero}};
// Response and mode settings
        int_atu_in_rsp_code         = {2*ATU_MAX_REGIONS{zero}};
        int_atu_in_fuzzy            = {ATU_MAX_REGIONS{zero}};
        int_atu_in_shift            = {ATU_MAX_REGIONS{zero}};
        int_atu_in_invert           = {ATU_MAX_REGIONS{zero}};
        int_atu_in_bar_match        = {ATU_MAX_REGIONS{zero}};
// Region Enable
        int_atu_in_en               = {ATU_MAX_REGIONS{zero}};
// Base, Limit and Target Registers
        int_atu_in_base             = {ATU_REG_WD*ATU_MAX_REGIONS{zero}};
        int_atu_in_upr_base         = {ATU_BASE_WD*ATU_MAX_REGIONS{zero}};
        int_atu_in_limit            = {ATU_REG_WD*ATU_MAX_REGIONS{zero}};
        int_atu_in_cbuf_incr        = {4*ATU_MAX_REGIONS{zero}};
        int_atu_in_cbuf_restart     = {ATU_MAX_REGIONS{zero}};
        int_atu_in_uppr_limit       = {ATU_UPR_LMT_WD*ATU_MAX_REGIONS{zero}};
        int_atu_in_lwr_trgt         = {ATU_REG_WD*ATU_MAX_REGIONS{zero}};
        int_atu_in_upr_trgt         = {ATU_BASE_WD*ATU_MAX_REGIONS{zero}};
    end
// Output assignments
// ATU inbound Region controls
assign atu_reg_in_type              = 0;
assign atu_reg_in_tc                = 0;
assign atu_reg_in_td                = 0;
assign atu_reg_in_attr              = 0;
assign atu_reg_in_at                = 0;
assign atu_reg_in_func_num          = 0;
assign atu_reg_in_msg_code          = 0;
assign atu_reg_in_bar_num           = 0;
assign atu_reg_in_th                = 0;
assign atu_reg_in_ph                = 0;
assign atu_reg_in_st                = 0;
assign atu_reg_in_incr_rgn_size     = 0;
// Inbound field match enables
assign atu_reg_in_tc_match_en       = 0;
assign atu_reg_in_td_match_en       = 0;
assign atu_reg_in_attr_match_en     = 0;
assign atu_reg_in_at_match_en       = 0;
assign atu_reg_in_func_match_en     = 0;
assign atu_reg_in_msgcode_match_en  = 0;
assign atu_reg_in_th_match_en       = 0;
assign atu_reg_in_ph_match_en       = 0;
assign atu_reg_in_st_match_en       = 0;
assign atu_reg_in_single_addr_loc_en = 0;
assign atu_reg_in_msg_type_match_mode = 0;
// Response and mode settings
assign atu_reg_in_rsp_code          = 0;
assign atu_reg_in_fuzzy             = 0;
assign atu_reg_in_shift             = 0;
assign atu_reg_in_invert            = 0;
assign atu_reg_in_bar_match         = 0;
// Region Enable
assign atu_reg_in_en                = 0;
// Base, Limit and Target Registers
assign atu_reg_in_base              = 0;
assign atu_reg_in_upr_base          = 0;
assign atu_reg_in_limit             = 0;
assign atu_reg_in_cbuf_incr         = 0;
assign atu_reg_in_cbuf_restart      = 0;
assign atu_reg_in_uppr_limit        = 0;
assign atu_reg_in_lwr_trgt          = 0;
assign atu_reg_in_upr_trgt          = 0;

end
endgenerate

// -----------------------------------------------------------------------------
// Read Mux
// -----------------------------------------------------------------------------
always @(*)
begin : read_data_proc
    atu_ctrl_reg_data_int = 0;
    for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
      int_atu_in_func_num_packed_arr[j]      = {PF_WD{1'b0}};
      int_atu_in_attr_packed_arr[j]          = {ATTR_WD{1'b0}};
      int_atu_in_tc_packed_arr[j]            = {3{1'b0}};
      int_atu_in_type_packed_arr[j]          = {5{1'b0}};
      int_atu_out_func_num_packed_arr[j]     = {PF_WD{1'b0}};
      int_atu_out_attr_packed_arr[j]         = {ATTR_WD{1'b0}};
      int_atu_out_type_packed_arr[j]         = {5{1'b0}};
      int_atu_out_tc_packed_arr[j]           = {3{1'b0}};
      int_atu_in_rsp_code_packed_arr[j]      = {2{1'b0}};
      int_atu_in_bar_num_packed_arr[j]       = {3{1'b0}};
      int_atu_in_msg_code_packed_arr[j]      = {8{1'b0}};
      int_atu_out_tag_packed_arr[j]          = {TAG_SIZE{1'b0}};
      int_atu_out_msg_code_packed_arr[j]     = {8{1'b0}};
      int_atu_in_base_packed_arr[j]          = {ATU_REG_WD{1'b0}};
      int_atu_out_base_packed_arr[j]         = {ATU_REG_WD{1'b0}};    
      int_atu_in_upr_base_packed_arr[j]      = {ATU_BASE_WD{1'b0}};
      int_atu_out_upr_base_packed_arr[j]     = {ATU_BASE_WD{1'b0}};
      int_atu_in_limit_packed_arr[j]         = {ATU_REG_WD{1'b0}};
      int_atu_out_limit_packed_arr[j]        = {ATU_REG_WD{1'b0}};
      int_atu_out_lwr_trgt_packed_arr[j]     = {ATU_REG_WD{1'b0}};
      int_atu_out_upr_trgt_packed_arr[j]     = {ATU_BASE_WD{1'b0}};
      int_atu_out_lwr_trgt_lwr_packed_arr[j] = {ATU_REG_LWR_WD{1'b0}};
      int_atu_in_lwr_trgt_packed_arr[j]      = {ATU_REG_WD{1'b0}};
      int_atu_in_upr_trgt_packed_arr[j]      = {ATU_BASE_WD{1'b0}};
      int_atu_in_uppr_limit_packed_arr[j]    = {ATU_UPR_LMT_WD{1'b0}};
      int_atu_out_uppr_limit_packed_arr[j]   = {ATU_UPR_LMT_WD{1'b0}};
      int_atu_in_ph_packed_arr[j]            = {2{1'b0}};
      int_atu_out_ph_packed_arr[j]           = {2{1'b0}};
      int_atu_in_at_packed_arr[j]            = {2{1'b0}};
      int_atu_out_at_packed_arr[j]           = {2{1'b0}};
      int_atu_in_cbuf_incr_packed_arr[j]     = {4{1'b0}};
    end
    unique case (1'b1)
        atu_ctrl_reg_id[0] : begin
            atu_ctrl_reg_data_int[31] = n_is_in;
            atu_ctrl_reg_data_int[0 +: ATU_LOG2_REGIONS] = n[ATU_LOG2_REGIONS-1:0];
        end
        atu_ctrl_reg_id[1] :
            if(n_is_in) begin
                for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
                  int_atu_in_func_num_packed_arr[j]  = reg_bcm36_nhs_d.int_atu_in_func_num[j*PF_WD +: PF_WD];
                end
                atu_ctrl_reg_data_int[20 +: PF_WD]  = int_atu_in_func_num_packed_arr[n[ATU_LOG2_REGIONS-1:0]];
                for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
                  int_atu_in_ph_packed_arr[j] = reg_bcm36_nhs_d.int_atu_in_ph[j*2 +: 2];
                end
                atu_ctrl_reg_data_int[19:18]        = int_atu_in_ph_packed_arr[n[ATU_LOG2_REGIONS-1:0]];
                for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
                  int_atu_in_at_packed_arr[j] = reg_bcm36_nhs_d.int_atu_in_at[j*2 +: 2];
                end
                atu_ctrl_reg_data_int[17:16]        = int_atu_in_at_packed_arr[n[ATU_LOG2_REGIONS-1:0]];
                for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
                  int_atu_in_attr_packed_arr[j]  = reg_bcm36_nhs_d.int_atu_in_attr[j*ATTR_WD +: ATTR_WD];
                end
                atu_ctrl_reg_data_int[9 +: ATTR_WD] = int_atu_in_attr_packed_arr[n[ATU_LOG2_REGIONS-1:0]];
                atu_ctrl_reg_data_int[13]           = reg_bcm36_nhs_d.int_atu_in_incr_rgn_size[n[ATU_LOG2_REGIONS-1:0]];
                atu_ctrl_reg_data_int[12]           = reg_bcm36_nhs_d.int_atu_in_th[n[ATU_LOG2_REGIONS-1:0]];
                atu_ctrl_reg_data_int[8]            = reg_bcm36_nhs_d.int_atu_in_td[n[ATU_LOG2_REGIONS-1:0]];
                for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
                  int_atu_in_tc_packed_arr[j]  = reg_bcm36_nhs_d.int_atu_in_tc[j*3 +: 3];
                end
                atu_ctrl_reg_data_int[7:5]          = int_atu_in_tc_packed_arr[n[ATU_LOG2_REGIONS-1:0]];
                for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
                  int_atu_in_type_packed_arr[j]  = reg_bcm36_nhs_d.int_atu_in_type[j*5 +: 5];
                end
                atu_ctrl_reg_data_int[4:0]          = int_atu_in_type_packed_arr[n[ATU_LOG2_REGIONS-1:0]];
            end else begin
                for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
                  int_atu_out_func_num_packed_arr[j]  = reg_bcm36_nhs_d.int_atu_out_func_num[j*PF_WD +: PF_WD];
                end
                atu_ctrl_reg_data_int[20 +: PF_WD]  = int_atu_out_func_num_packed_arr[n[ATU_LOG2_REGIONS-1:0]];
                for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
                  int_atu_out_ph_packed_arr[j] = reg_bcm36_nhs_d.int_atu_out_ph[j*2 +: 2];
                end
                atu_ctrl_reg_data_int[19:18]        = int_atu_out_ph_packed_arr[n[ATU_LOG2_REGIONS-1:0]];
                for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
                  int_atu_out_at_packed_arr[j]      = reg_bcm36_nhs_d.int_atu_out_at[j*2 +: 2];
                end
                atu_ctrl_reg_data_int[17:16]        = int_atu_out_at_packed_arr[n[ATU_LOG2_REGIONS-1:0]];
                atu_ctrl_reg_data_int[13]           = reg_bcm36_nhs_d.int_atu_out_incr_rgn_size[n[ATU_LOG2_REGIONS-1:0]];
                atu_ctrl_reg_data_int[12]           = reg_bcm36_nhs_d.int_atu_out_th[n[ATU_LOG2_REGIONS-1:0]];
                for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
                  int_atu_out_attr_packed_arr[j]  = reg_bcm36_nhs_d.int_atu_out_attr[j*ATTR_WD +: ATTR_WD];
                end
                atu_ctrl_reg_data_int[9 +: ATTR_WD] = int_atu_out_attr_packed_arr[n[ATU_LOG2_REGIONS-1:0]];
                atu_ctrl_reg_data_int[8]            = reg_bcm36_nhs_d.int_atu_out_td[n[ATU_LOG2_REGIONS-1:0]];
                for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
                  int_atu_out_tc_packed_arr[j]  = reg_bcm36_nhs_d.int_atu_out_tc[j*3 +: 3];
                end
                atu_ctrl_reg_data_int[7:5]          = int_atu_out_tc_packed_arr[n[ATU_LOG2_REGIONS-1:0]];
                for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
                  int_atu_out_type_packed_arr[j]  = reg_bcm36_nhs_d.int_atu_out_type[j*5 +: 5];
                end
                atu_ctrl_reg_data_int[4:0]          = int_atu_out_type_packed_arr[n[ATU_LOG2_REGIONS-1:0]];
            end
        atu_ctrl_reg_id[2]  : begin
            if(n_is_in) begin
                atu_ctrl_reg_data_int[31]       = reg_bcm36_nhs_d.int_atu_in_en[n[ATU_LOG2_REGIONS-1:0]];
                atu_ctrl_reg_data_int[30]       = reg_bcm36_nhs_d.int_atu_in_bar_match[n[ATU_LOG2_REGIONS-1:0]];
                atu_ctrl_reg_data_int[29]       = reg_bcm36_nhs_d.int_atu_in_invert[n[ATU_LOG2_REGIONS-1:0]];
                atu_ctrl_reg_data_int[28]       = reg_bcm36_nhs_d.int_atu_in_shift[n[ATU_LOG2_REGIONS-1:0]];
                atu_ctrl_reg_data_int[27]       = reg_bcm36_nhs_d.int_atu_in_fuzzy[n[ATU_LOG2_REGIONS-1:0]];
                for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
                 int_atu_in_rsp_code_packed_arr[j]  = reg_bcm36_nhs_d.int_atu_in_rsp_code[j*2 +: 2];
                end
                atu_ctrl_reg_data_int[25:24]    = int_atu_in_rsp_code_packed_arr[n[ATU_LOG2_REGIONS-1:0]];
                atu_ctrl_reg_data_int[23]       = reg_bcm36_nhs_d.int_atu_in_single_addr_loc_en[n[ATU_LOG2_REGIONS-1:0]];
                atu_ctrl_reg_data_int[22]       = reg_bcm36_nhs_d.int_atu_in_ph_match_en[n[ATU_LOG2_REGIONS-1:0]];
                atu_ctrl_reg_data_int[21]       = reg_bcm36_nhs_d.int_atu_in_msgcode_match_en[n[ATU_LOG2_REGIONS-1:0]];
                atu_ctrl_reg_data_int[19]       = reg_bcm36_nhs_d.int_atu_in_func_match_en[n[ATU_LOG2_REGIONS-1:0]];
                atu_ctrl_reg_data_int[18]       = reg_bcm36_nhs_d.int_atu_in_at_match_en[n[ATU_LOG2_REGIONS-1:0]];
                atu_ctrl_reg_data_int[17]       = reg_bcm36_nhs_d.int_atu_in_th_match_en[n[ATU_LOG2_REGIONS-1:0]];
                atu_ctrl_reg_data_int[16]       = reg_bcm36_nhs_d.int_atu_in_attr_match_en[n[ATU_LOG2_REGIONS-1:0]];
                atu_ctrl_reg_data_int[15]       = reg_bcm36_nhs_d.int_atu_in_td_match_en[n[ATU_LOG2_REGIONS-1:0]];
                atu_ctrl_reg_data_int[14]       = reg_bcm36_nhs_d.int_atu_in_tc_match_en[n[ATU_LOG2_REGIONS-1:0]];
                atu_ctrl_reg_data_int[13]       = reg_bcm36_nhs_d.int_atu_in_msg_type_match_mode[n[ATU_LOG2_REGIONS-1:0]];
                for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
                 int_atu_in_bar_num_packed_arr[j]  = reg_bcm36_nhs_d.int_atu_in_bar_num[j*3 +: 3];
                end
                atu_ctrl_reg_data_int[10:8]     = int_atu_in_bar_num_packed_arr[n[ATU_LOG2_REGIONS-1:0]];
                for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
                 int_atu_in_msg_code_packed_arr[j]  = reg_bcm36_nhs_d.int_atu_in_msg_code[j*8 +: 8];
                end
                atu_ctrl_reg_data_int[7:0]      = int_atu_in_msg_code_packed_arr[n[ATU_LOG2_REGIONS-1:0]];
            end else begin
                atu_ctrl_reg_data_int[31]       = reg_bcm36_nhs_d.int_atu_out_en[n[ATU_LOG2_REGIONS-1:0]];
                atu_ctrl_reg_data_int[29]       = reg_bcm36_nhs_d.int_atu_out_invert[n[ATU_LOG2_REGIONS-1:0]];
                atu_ctrl_reg_data_int[28]       = reg_bcm36_nhs_d.int_atu_out_shift[n[ATU_LOG2_REGIONS-1:0]];
                atu_ctrl_reg_data_int[27]       = reg_bcm36_nhs_d.int_atu_out_dma_bypass[n[ATU_LOG2_REGIONS-1:0]];
                atu_ctrl_reg_data_int[23]       = reg_bcm36_nhs_d.int_atu_out_hdr_substitute_en[n[ATU_LOG2_REGIONS-1:0]];
                atu_ctrl_reg_data_int[22]       = reg_bcm36_nhs_d.int_atu_out_inhibit_payload[n[ATU_LOG2_REGIONS-1:0]];
                atu_ctrl_reg_data_int[21]       = reg_bcm36_nhs_d.int_atu_out_hdr_flds_bypass[n[ATU_LOG2_REGIONS-1:0]];
                atu_ctrl_reg_data_int[20]       = reg_bcm36_nhs_d.int_atu_out_snp[n[ATU_LOG2_REGIONS-1:0]];
                atu_ctrl_reg_data_int[19]       = reg_bcm36_nhs_d.int_atu_out_func_bypass[n[ATU_LOG2_REGIONS-1:0]];
                for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
                 int_atu_out_tag_packed_arr[j]  = reg_bcm36_nhs_d.int_atu_out_tag[j*TAG_SIZE +: TAG_SIZE];
                end
                atu_ctrl_reg_data_int[18:17]    = int_atu_out_tag_packed_arr[n[ATU_LOG2_REGIONS-1:0]][9:8];
                atu_ctrl_reg_data_int[16]       = reg_bcm36_nhs_d.int_atu_out_tag_substitute_en[n[ATU_LOG2_REGIONS-1:0]];
                atu_ctrl_reg_data_int[15:8]     = int_atu_out_tag_packed_arr[n[ATU_LOG2_REGIONS-1:0]][7:0];
                for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
                 int_atu_out_msg_code_packed_arr[j]  = reg_bcm36_nhs_d.int_atu_out_msg_code[j*8 +: 8];
                end
                atu_ctrl_reg_data_int[7:0]      = int_atu_out_msg_code_packed_arr[n[ATU_LOG2_REGIONS-1:0]];
            end
        end
        atu_ctrl_reg_id[3]  : begin
            if(n_is_in) begin
                for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
                 int_atu_in_base_packed_arr[j]  = reg_bcm36_nhs_d.int_atu_in_base[j*ATU_REG_WD +: ATU_REG_WD];
                end
                atu_ctrl_reg_data_int[31 -: ATU_REG_WD] =
                    int_atu_in_base_packed_arr[n[ATU_LOG2_REGIONS-1:0]];
            end 
            else begin
                for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
                 int_atu_out_base_packed_arr[j]  = reg_bcm36_nhs_d.int_atu_out_base[j*ATU_REG_WD +: ATU_REG_WD];
                end
                atu_ctrl_reg_data_int[31 -: ATU_REG_WD] =
                    int_atu_out_base_packed_arr[n[ATU_LOG2_REGIONS-1:0]];
            end
        end
        atu_ctrl_reg_id[4]  : begin
            if(n_is_in) begin
                for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
                 int_atu_in_upr_base_packed_arr[j]  = reg_bcm36_nhs_d.int_atu_in_upr_base[j*ATU_BASE_WD +: ATU_BASE_WD];
                end
                atu_ctrl_reg_data_int[0 +: ATU_BASE_WD] =
                    int_atu_in_upr_base_packed_arr[n[ATU_LOG2_REGIONS-1:0]];
            end
            else begin
                for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
                 int_atu_out_upr_base_packed_arr[j]  = reg_bcm36_nhs_d.int_atu_out_upr_base[j*ATU_BASE_WD +: ATU_BASE_WD];
                end
                atu_ctrl_reg_data_int[0 +: ATU_BASE_WD] =
                    int_atu_out_upr_base_packed_arr[n[ATU_LOG2_REGIONS-1:0]];
            end
        end
        atu_ctrl_reg_id[5]  : begin
            if(n_is_in) begin
                for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
                  int_atu_in_cbuf_incr_packed_arr[j] = reg_bcm36_nhs_d.int_atu_in_cbuf_incr[j*4 +: 4];
                end
                atu_ctrl_reg_data_int[0 +: 32-ATU_REG_WD] = {{28-ATU_REG_WD{1'b1}}, int_atu_in_cbuf_incr_packed_arr[n[ATU_LOG2_REGIONS-1:0]]};
                for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
                 int_atu_in_limit_packed_arr[j]  = reg_bcm36_nhs_d.int_atu_in_limit[j*ATU_REG_WD +: ATU_REG_WD];
                end
                atu_ctrl_reg_data_int[31 -: ATU_REG_WD] =
                    int_atu_in_limit_packed_arr[n[ATU_LOG2_REGIONS-1:0]];
            end else begin
                atu_ctrl_reg_data_int[0 +: 32-ATU_REG_WD] = {32-ATU_REG_WD{1'b1}};
                for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
                 int_atu_out_limit_packed_arr[j]  = reg_bcm36_nhs_d.int_atu_out_limit[j*ATU_REG_WD +: ATU_REG_WD];
                end
                atu_ctrl_reg_data_int[31 -: ATU_REG_WD] =
                    int_atu_out_limit_packed_arr[n[ATU_LOG2_REGIONS-1:0]];
            end
        end
        atu_ctrl_reg_id[6]  : begin
            if(n_is_in) begin
                for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
                 int_atu_in_lwr_trgt_packed_arr[j]  = reg_bcm36_nhs_d.int_atu_in_lwr_trgt[j*ATU_REG_WD +: ATU_REG_WD];
                end
                atu_ctrl_reg_data_int[31 -: ATU_REG_WD] =
                    int_atu_in_lwr_trgt_packed_arr[n[ATU_LOG2_REGIONS-1:0]];
            end
            else begin
                for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
                 int_atu_out_lwr_trgt_packed_arr[j]      = reg_bcm36_nhs_d.int_atu_out_lwr_trgt[j*ATU_REG_WD +: ATU_REG_WD];
                 int_atu_out_lwr_trgt_lwr_packed_arr[j]  = reg_bcm36_nhs_d.int_atu_out_lwr_trgt_lwr[j*ATU_REG_LWR_WD +: ATU_REG_LWR_WD];
                end
                atu_ctrl_reg_data_int[31 -: ATU_BASE_WD] =
                    {int_atu_out_lwr_trgt_packed_arr[n[ATU_LOG2_REGIONS-1:0]], int_atu_out_lwr_trgt_lwr_packed_arr[n[ATU_LOG2_REGIONS-1:0]]};
            end
        end
        atu_ctrl_reg_id[7]  : begin
            if(n_is_in) begin
                for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
                 int_atu_in_upr_trgt_packed_arr[j]  = reg_bcm36_nhs_d.int_atu_in_upr_trgt[j*ATU_BASE_WD +: ATU_BASE_WD];
                end
                atu_ctrl_reg_data_int[0 +: ATU_BASE_WD] =
                    int_atu_in_upr_trgt_packed_arr[n[ATU_LOG2_REGIONS-1:0]];
            end 
            else begin
                for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
                 int_atu_out_upr_trgt_packed_arr[j]  = reg_bcm36_nhs_d.int_atu_out_upr_trgt[j*ATU_BASE_WD +: ATU_BASE_WD];
                end
                atu_ctrl_reg_data_int[0 +: ATU_BASE_WD] =
                    int_atu_out_upr_trgt_packed_arr[n[ATU_LOG2_REGIONS-1:0]];
            end
        end
        atu_ctrl_reg_id[9]  : begin
            if(n_is_in) begin
                for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
                 int_atu_in_uppr_limit_packed_arr[j]  = reg_bcm36_nhs_d.int_atu_in_uppr_limit[j*ATU_UPR_LMT_WD +: ATU_UPR_LMT_WD];
                end
                atu_ctrl_reg_data_int[0 +: ATU_UPR_LMT_WD] =
                    int_atu_in_uppr_limit_packed_arr[n[ATU_LOG2_REGIONS-1:0]];
            end
            else begin
                for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
                 int_atu_out_uppr_limit_packed_arr[j]  = reg_bcm36_nhs_d.int_atu_out_uppr_limit[j*ATU_UPR_LMT_WD +: ATU_UPR_LMT_WD];
                end
                atu_ctrl_reg_data_int[0 +: ATU_UPR_LMT_WD] =
                    int_atu_out_uppr_limit_packed_arr[n[ATU_LOG2_REGIONS-1:0]];
            end
        end
        default             : begin
            atu_ctrl_reg_data_int = 32'b0;
            for (int j = 0; j < ATU_MAX_REGIONS; j = j + 1) begin
              int_atu_in_func_num_packed_arr[j]      = {PF_WD{1'b0}};
              int_atu_in_attr_packed_arr[j]          = {ATTR_WD{1'b0}};
              int_atu_in_tc_packed_arr[j]            = {3{1'b0}};
              int_atu_in_type_packed_arr[j]          = {5{1'b0}};
              int_atu_out_func_num_packed_arr[j]     = {PF_WD{1'b0}};
              int_atu_out_attr_packed_arr[j]         = {ATTR_WD{1'b0}};
              int_atu_out_type_packed_arr[j]         = {5{1'b0}};
              int_atu_out_tc_packed_arr[j]           = {3{1'b0}};
              int_atu_in_rsp_code_packed_arr[j]      = {2{1'b0}};
              int_atu_in_bar_num_packed_arr[j]       = {3{1'b0}};
              int_atu_in_msg_code_packed_arr[j]      = {8{1'b0}};
              int_atu_out_tag_packed_arr[j]          = {TAG_SIZE{1'b0}};
              int_atu_out_msg_code_packed_arr[j]     = {8{1'b0}};
              int_atu_in_base_packed_arr[j]          = {ATU_REG_WD{1'b0}};
              int_atu_out_base_packed_arr[j]         = {ATU_REG_WD{1'b0}};    
              int_atu_in_upr_base_packed_arr[j]      = {ATU_BASE_WD{1'b0}};
              int_atu_out_upr_base_packed_arr[j]     = {ATU_BASE_WD{1'b0}};
              int_atu_in_limit_packed_arr[j]         = {ATU_REG_WD{1'b0}};
              int_atu_out_limit_packed_arr[j]        = {ATU_REG_WD{1'b0}};
              int_atu_out_lwr_trgt_packed_arr[j]     = {ATU_REG_WD{1'b0}};
              int_atu_out_upr_trgt_packed_arr[j]     = {ATU_BASE_WD{1'b0}};
              int_atu_out_lwr_trgt_lwr_packed_arr[j] = {ATU_REG_LWR_WD{1'b0}};
              int_atu_in_lwr_trgt_packed_arr[j]      = {ATU_REG_WD{1'b0}};
              int_atu_in_upr_trgt_packed_arr[j]      = {ATU_BASE_WD{1'b0}};
              int_atu_in_uppr_limit_packed_arr[j]    = {ATU_UPR_LMT_WD{1'b0}};
              int_atu_out_uppr_limit_packed_arr[j]   = {ATU_UPR_LMT_WD{1'b0}};
              int_atu_in_ph_packed_arr[j]            = {2{1'b0}};
              int_atu_out_ph_packed_arr[j]           = {2{1'b0}};
              int_atu_in_at_packed_arr[j]            = {2{1'b0}};
              int_atu_out_at_packed_arr[j]           = {2{1'b0}};
              int_atu_in_cbuf_incr_packed_arr[j]     = {4{1'b0}};
            end
        end
    endcase
end
// leda E267 on
endmodule
