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
// ---    $DateTime: 2023/12/22 07:15:34 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/rplh_fm_pkt_finder_256b_dec.sv#4 $
// -------------------------------------------------------------------------
// --- Module Description: As a function of current state and current raw tokens, decode actual
// ---                     tokens for the current 256 cycle and state for next 256b cycle.
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/pcie_pkg.svh"
`include "products/cx_pl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

module rplh_fm_pkt_finder_256b_dec
  import cx_pl_pkg::tlp_state_t;
  import DWC_pcie_core_pkg::fm_raw_tkn_t;
  import pcie_pkg::NOP_TKN;
  import pcie_pkg::PFX_TKN;
  import pcie_pkg::HDR_TKN;

                                    (
// ---- inputs ---------------
input tlp_state_t      prev_tlp_state,
fm_raw_tkn_t [7:0]     raw,
// ---- outputs ---------------
output tlp_state_t     next_tlp_state,
output reg   [7:0]     tlp_pfx,
output reg   [7:0]     tlp_soh,
output reg   [7:0]     tlp_end,
output reg   [7:0]     tlp_idl
);

wire   prev_tlp_none ,  // No previous TLP
       prev_tlp_eot_0,  // Previous TLP ends in DW 0
       prev_tlp_eot_1,  // Previous TLP ends in DW 1
       prev_tlp_eot_2,  // Previous TLP ends in DW 2
       prev_tlp_eot_3,  // Previous TLP ends in DW 3
       prev_tlp_eot_4,  // Previous TLP ends in DW 4
       prev_tlp_eot_5,  // Previous TLP ends in DW 5
       prev_tlp_eot_6,  // Previous TLP ends in DW 6
       prev_tlp_eot_7,  // Previous TLP ends in DW 7
       prev_tlp_eot_n;  // Previous TLP not ending in this decoder
assign prev_tlp_none  = !prev_tlp_state.pending;
assign prev_tlp_eot_0 =  prev_tlp_state.pending && {prev_tlp_state.eot_flt, prev_tlp_state.eot_dec}==0 && prev_tlp_state.eot_pos[0];
assign prev_tlp_eot_1 =  prev_tlp_state.pending && {prev_tlp_state.eot_flt, prev_tlp_state.eot_dec}==0 && prev_tlp_state.eot_pos[1];
assign prev_tlp_eot_2 =  prev_tlp_state.pending && {prev_tlp_state.eot_flt, prev_tlp_state.eot_dec}==0 && prev_tlp_state.eot_pos[2];
assign prev_tlp_eot_3 =  prev_tlp_state.pending && {prev_tlp_state.eot_flt, prev_tlp_state.eot_dec}==0 && prev_tlp_state.eot_pos[3];
assign prev_tlp_eot_4 =  prev_tlp_state.pending && {prev_tlp_state.eot_flt, prev_tlp_state.eot_dec}==0 && prev_tlp_state.eot_pos[4];
assign prev_tlp_eot_5 =  prev_tlp_state.pending && {prev_tlp_state.eot_flt, prev_tlp_state.eot_dec}==0 && prev_tlp_state.eot_pos[5];
assign prev_tlp_eot_6 =  prev_tlp_state.pending && {prev_tlp_state.eot_flt, prev_tlp_state.eot_dec}==0 && prev_tlp_state.eot_pos[6];
assign prev_tlp_eot_7 =  prev_tlp_state.pending && {prev_tlp_state.eot_flt, prev_tlp_state.eot_dec}==0 && prev_tlp_state.eot_pos[7];
assign prev_tlp_eot_n =  prev_tlp_state.pending && {prev_tlp_state.eot_flt, prev_tlp_state.eot_dec}>0;

wire   hdr_0_eot_n, hdr_0_eot_2, hdr_0_eot_3, hdr_0_eot_4, hdr_0_eot_5, hdr_0_eot_6, hdr_0_eot_7, // TLP starts in DW 0 and ends in DW ?
       hdr_1_eot_n,              hdr_1_eot_3, hdr_1_eot_4, hdr_1_eot_5, hdr_1_eot_6, hdr_1_eot_7, // TLP starts in DW 1 and ends in DW ?
       hdr_2_eot_n,                           hdr_2_eot_4, hdr_2_eot_5, hdr_2_eot_6, hdr_2_eot_7, // TLP starts in DW 2 and ends in DW ?
       hdr_3_eot_n,                                        hdr_3_eot_5, hdr_3_eot_6, hdr_3_eot_7, // TLP starts in DW 3 and ends in DW ?
       hdr_4_eot_n,                                                     hdr_4_eot_6, hdr_4_eot_7, // TLP starts in DW 4 and ends in DW ?
       hdr_5_eot_n,                                                                  hdr_5_eot_7, // TLP starts in DW 5 and ends in DW ?
       hdr_6_eot_n,                                                                               // TLP starts in DW 6 does not end
       hdr_7_eot_n;                                                                               // TLP starts in DW 6 does not end
assign hdr_0_eot_2 = raw[0].tkn==HDR_TKN & {raw[0].eot_flt, raw[0].eot_dec}==0 & raw[0].eot_pos[2];
assign hdr_0_eot_3 = raw[0].tkn==HDR_TKN & {raw[0].eot_flt, raw[0].eot_dec}==0 & raw[0].eot_pos[3];
assign hdr_0_eot_4 = raw[0].tkn==HDR_TKN & {raw[0].eot_flt, raw[0].eot_dec}==0 & raw[0].eot_pos[4];
assign hdr_0_eot_5 = raw[0].tkn==HDR_TKN & {raw[0].eot_flt, raw[0].eot_dec}==0 & raw[0].eot_pos[5];
assign hdr_0_eot_6 = raw[0].tkn==HDR_TKN & {raw[0].eot_flt, raw[0].eot_dec}==0 & raw[0].eot_pos[6];
assign hdr_0_eot_7 = raw[0].tkn==HDR_TKN & {raw[0].eot_flt, raw[0].eot_dec}==0 & raw[0].eot_pos[7];
assign hdr_0_eot_n = raw[0].tkn==HDR_TKN & {raw[0].eot_flt, raw[0].eot_dec}>0;
assign hdr_1_eot_3 = raw[1].tkn==HDR_TKN & {raw[1].eot_flt, raw[1].eot_dec}==0 & raw[1].eot_pos[3];
assign hdr_1_eot_4 = raw[1].tkn==HDR_TKN & {raw[1].eot_flt, raw[1].eot_dec}==0 & raw[1].eot_pos[4];
assign hdr_1_eot_5 = raw[1].tkn==HDR_TKN & {raw[1].eot_flt, raw[1].eot_dec}==0 & raw[1].eot_pos[5];
assign hdr_1_eot_6 = raw[1].tkn==HDR_TKN & {raw[1].eot_flt, raw[1].eot_dec}==0 & raw[1].eot_pos[6];
assign hdr_1_eot_7 = raw[1].tkn==HDR_TKN & {raw[1].eot_flt, raw[1].eot_dec}==0 & raw[1].eot_pos[7];
assign hdr_1_eot_n = raw[1].tkn==HDR_TKN & {raw[1].eot_flt, raw[1].eot_dec}>0;
assign hdr_2_eot_4 = raw[2].tkn==HDR_TKN & {raw[2].eot_flt, raw[2].eot_dec}==0 & raw[2].eot_pos[4];
assign hdr_2_eot_5 = raw[2].tkn==HDR_TKN & {raw[2].eot_flt, raw[2].eot_dec}==0 & raw[2].eot_pos[5];
assign hdr_2_eot_6 = raw[2].tkn==HDR_TKN & {raw[2].eot_flt, raw[2].eot_dec}==0 & raw[2].eot_pos[6];
assign hdr_2_eot_7 = raw[2].tkn==HDR_TKN & {raw[2].eot_flt, raw[2].eot_dec}==0 & raw[2].eot_pos[7];
assign hdr_2_eot_n = raw[2].tkn==HDR_TKN & {raw[2].eot_flt, raw[2].eot_dec}>0;
assign hdr_3_eot_5 = raw[3].tkn==HDR_TKN & {raw[3].eot_flt, raw[3].eot_dec}==0 & raw[3].eot_pos[5];
assign hdr_3_eot_6 = raw[3].tkn==HDR_TKN & {raw[3].eot_flt, raw[3].eot_dec}==0 & raw[3].eot_pos[6];
assign hdr_3_eot_7 = raw[3].tkn==HDR_TKN & {raw[3].eot_flt, raw[3].eot_dec}==0 & raw[3].eot_pos[7];
assign hdr_3_eot_n = raw[3].tkn==HDR_TKN & {raw[3].eot_flt, raw[3].eot_dec}>0;
assign hdr_4_eot_6 = raw[4].tkn==HDR_TKN & {raw[4].eot_flt, raw[4].eot_dec}==0 & raw[4].eot_pos[6];
assign hdr_4_eot_7 = raw[4].tkn==HDR_TKN & {raw[4].eot_flt, raw[4].eot_dec}==0 & raw[4].eot_pos[7];
assign hdr_4_eot_n = raw[4].tkn==HDR_TKN & {raw[4].eot_flt, raw[4].eot_dec}>0;
assign hdr_5_eot_7 = raw[5].tkn==HDR_TKN & {raw[5].eot_flt, raw[5].eot_dec}==0 & raw[5].eot_pos[7];
assign hdr_5_eot_n = raw[5].tkn==HDR_TKN & {raw[5].eot_flt, raw[5].eot_dec}>0;
assign hdr_6_eot_n = raw[6].tkn==HDR_TKN & {raw[6].eot_flt, raw[6].eot_dec}>0; // "& {raw[6].eot_flt, raw[6].eot_dec}>0" is implicit and not required (just to pass formality)
assign hdr_7_eot_n = raw[7].tkn==HDR_TKN & {raw[7].eot_flt, raw[7].eot_dec}>0; // "& {raw[7].eot_flt, raw[6].eot_dec}>0" is implicit and not required (just to pass formality)

tlp_state_t [7:0]    raw_next_tlp_state;       // Per each DW[x], what would be the next tlp state assuming the previous TLP ends in DW[x-1]
logic       [7:0]    raw_next_tlp_state_valid; // 1: if any case item is actually hit; 0: default case. Timing improvement.

// START MARKER FOR SCRIPT GENERATED CODE
enum int {
    ddd_ddd_ddd_ddd_ddd_ddd_ddd_hdr,
    end_ddd_ddd_ddd_ddd_ddd_ddd_hdr,
    hdr_end_ddd_ddd_ddd_ddd_ddd_hdr,
    nop_end_ddd_ddd_ddd_ddd_ddd_hdr,
    pfx_end_ddd_ddd_ddd_ddd_ddd_hdr,
    ddd_hdr_end_ddd_ddd_ddd_ddd_hdr,
    nop_nop_end_ddd_ddd_ddd_ddd_hdr,
    hdr_pfx_end_ddd_ddd_ddd_ddd_hdr,
    pfx_pfx_end_ddd_ddd_ddd_ddd_hdr,
    ddd_ddd_hdr_end_ddd_ddd_ddd_hdr,
    end_ddd_hdr_end_ddd_ddd_ddd_hdr,
    nop_nop_nop_end_ddd_ddd_ddd_hdr,
    ddd_hdr_pfx_end_ddd_ddd_ddd_hdr,
    hdr_pfx_pfx_end_ddd_ddd_ddd_hdr,
    pfx_pfx_pfx_end_ddd_ddd_ddd_hdr,
    ddd_ddd_ddd_hdr_end_ddd_ddd_hdr,
    end_ddd_ddd_hdr_end_ddd_ddd_hdr,
    hdr_end_ddd_hdr_end_ddd_ddd_hdr,
    nop_end_ddd_hdr_end_ddd_ddd_hdr,
    pfx_end_ddd_hdr_end_ddd_ddd_hdr,
    nop_nop_nop_nop_end_ddd_ddd_hdr,
    ddd_ddd_hdr_pfx_end_ddd_ddd_hdr,
    end_ddd_hdr_pfx_end_ddd_ddd_hdr,
    ddd_hdr_pfx_pfx_end_ddd_ddd_hdr,
    hdr_pfx_pfx_pfx_end_ddd_ddd_hdr,
    pfx_pfx_pfx_pfx_end_ddd_ddd_hdr,
    ddd_ddd_ddd_ddd_hdr_end_ddd_hdr,
    end_ddd_ddd_ddd_hdr_end_ddd_hdr,
    hdr_end_ddd_ddd_hdr_end_ddd_hdr,
    nop_end_ddd_ddd_hdr_end_ddd_hdr,
    pfx_end_ddd_ddd_hdr_end_ddd_hdr,
    ddd_hdr_end_ddd_hdr_end_ddd_hdr,
    nop_nop_end_ddd_hdr_end_ddd_hdr,
    hdr_pfx_end_ddd_hdr_end_ddd_hdr,
    pfx_pfx_end_ddd_hdr_end_ddd_hdr,
    ddd_ddd_ddd_hdr_nop_end_ddd_hdr,
    end_ddd_ddd_hdr_nop_end_ddd_hdr,
    hdr_end_ddd_hdr_nop_end_ddd_hdr,
    nop_end_ddd_hdr_nop_end_ddd_hdr,
    pfx_end_ddd_hdr_nop_end_ddd_hdr,
    nop_nop_nop_nop_nop_end_ddd_hdr,
    ddd_ddd_hdr_pfx_nop_end_ddd_hdr,
    end_ddd_hdr_pfx_nop_end_ddd_hdr,
    ddd_hdr_pfx_pfx_nop_end_ddd_hdr,
    hdr_pfx_pfx_pfx_nop_end_ddd_hdr,
    pfx_pfx_pfx_pfx_nop_end_ddd_hdr,
    ddd_ddd_ddd_hdr_pfx_end_ddd_hdr,
    end_ddd_ddd_hdr_pfx_end_ddd_hdr,
    hdr_end_ddd_hdr_pfx_end_ddd_hdr,
    nop_end_ddd_hdr_pfx_end_ddd_hdr,
    pfx_end_ddd_hdr_pfx_end_ddd_hdr,
    ddd_ddd_hdr_pfx_pfx_end_ddd_hdr,
    end_ddd_hdr_pfx_pfx_end_ddd_hdr,
    ddd_hdr_pfx_pfx_pfx_end_ddd_hdr,
    hdr_pfx_pfx_pfx_pfx_end_ddd_hdr,
    pfx_pfx_pfx_pfx_pfx_end_ddd_hdr,
    ddd_ddd_ddd_ddd_ddd_ddd_ddd_ddd,
    end_ddd_ddd_ddd_ddd_ddd_ddd_ddd,
    hdr_end_ddd_ddd_ddd_ddd_ddd_ddd,
    nop_end_ddd_ddd_ddd_ddd_ddd_ddd,
    pfx_end_ddd_ddd_ddd_ddd_ddd_ddd,
    ddd_hdr_end_ddd_ddd_ddd_ddd_ddd,
    nop_nop_end_ddd_ddd_ddd_ddd_ddd,
    hdr_pfx_end_ddd_ddd_ddd_ddd_ddd,
    pfx_pfx_end_ddd_ddd_ddd_ddd_ddd,
    ddd_ddd_hdr_end_ddd_ddd_ddd_ddd,
    end_ddd_hdr_end_ddd_ddd_ddd_ddd,
    nop_nop_nop_end_ddd_ddd_ddd_ddd,
    ddd_hdr_pfx_end_ddd_ddd_ddd_ddd,
    hdr_pfx_pfx_end_ddd_ddd_ddd_ddd,
    pfx_pfx_pfx_end_ddd_ddd_ddd_ddd,
    ddd_ddd_ddd_hdr_end_ddd_ddd_ddd,
    end_ddd_ddd_hdr_end_ddd_ddd_ddd,
    hdr_end_ddd_hdr_end_ddd_ddd_ddd,
    nop_end_ddd_hdr_end_ddd_ddd_ddd,
    pfx_end_ddd_hdr_end_ddd_ddd_ddd,
    nop_nop_nop_nop_end_ddd_ddd_ddd,
    ddd_ddd_hdr_pfx_end_ddd_ddd_ddd,
    end_ddd_hdr_pfx_end_ddd_ddd_ddd,
    ddd_hdr_pfx_pfx_end_ddd_ddd_ddd,
    hdr_pfx_pfx_pfx_end_ddd_ddd_ddd,
    pfx_pfx_pfx_pfx_end_ddd_ddd_ddd,
    ddd_ddd_ddd_ddd_hdr_end_ddd_ddd,
    end_ddd_ddd_ddd_hdr_end_ddd_ddd,
    hdr_end_ddd_ddd_hdr_end_ddd_ddd,
    nop_end_ddd_ddd_hdr_end_ddd_ddd,
    pfx_end_ddd_ddd_hdr_end_ddd_ddd,
    ddd_hdr_end_ddd_hdr_end_ddd_ddd,
    nop_nop_end_ddd_hdr_end_ddd_ddd,
    hdr_pfx_end_ddd_hdr_end_ddd_ddd,
    pfx_pfx_end_ddd_hdr_end_ddd_ddd,
    ddd_ddd_ddd_hdr_nop_end_ddd_ddd,
    end_ddd_ddd_hdr_nop_end_ddd_ddd,
    hdr_end_ddd_hdr_nop_end_ddd_ddd,
    nop_end_ddd_hdr_nop_end_ddd_ddd,
    pfx_end_ddd_hdr_nop_end_ddd_ddd,
    nop_nop_nop_nop_nop_end_ddd_ddd,
    ddd_ddd_hdr_pfx_nop_end_ddd_ddd,
    end_ddd_hdr_pfx_nop_end_ddd_ddd,
    ddd_hdr_pfx_pfx_nop_end_ddd_ddd,
    hdr_pfx_pfx_pfx_nop_end_ddd_ddd,
    pfx_pfx_pfx_pfx_nop_end_ddd_ddd,
    ddd_ddd_ddd_hdr_pfx_end_ddd_ddd,
    end_ddd_ddd_hdr_pfx_end_ddd_ddd,
    hdr_end_ddd_hdr_pfx_end_ddd_ddd,
    nop_end_ddd_hdr_pfx_end_ddd_ddd,
    pfx_end_ddd_hdr_pfx_end_ddd_ddd,
    ddd_ddd_hdr_pfx_pfx_end_ddd_ddd,
    end_ddd_hdr_pfx_pfx_end_ddd_ddd,
    ddd_hdr_pfx_pfx_pfx_end_ddd_ddd,
    hdr_pfx_pfx_pfx_pfx_end_ddd_ddd,
    pfx_pfx_pfx_pfx_pfx_end_ddd_ddd,
    ddd_ddd_ddd_ddd_ddd_hdr_end_ddd,
    end_ddd_ddd_ddd_ddd_hdr_end_ddd,
    hdr_end_ddd_ddd_ddd_hdr_end_ddd,
    nop_end_ddd_ddd_ddd_hdr_end_ddd,
    pfx_end_ddd_ddd_ddd_hdr_end_ddd,
    ddd_hdr_end_ddd_ddd_hdr_end_ddd,
    nop_nop_end_ddd_ddd_hdr_end_ddd,
    hdr_pfx_end_ddd_ddd_hdr_end_ddd,
    pfx_pfx_end_ddd_ddd_hdr_end_ddd,
    ddd_ddd_hdr_end_ddd_hdr_end_ddd,
    end_ddd_hdr_end_ddd_hdr_end_ddd,
    nop_nop_nop_end_ddd_hdr_end_ddd,
    ddd_hdr_pfx_end_ddd_hdr_end_ddd,
    hdr_pfx_pfx_end_ddd_hdr_end_ddd,
    pfx_pfx_pfx_end_ddd_hdr_end_ddd,
    ddd_ddd_ddd_hdr_nop_nop_end_ddd,
    end_ddd_ddd_hdr_nop_nop_end_ddd,
    hdr_end_ddd_hdr_nop_nop_end_ddd,
    nop_end_ddd_hdr_nop_nop_end_ddd,
    pfx_end_ddd_hdr_nop_nop_end_ddd,
    nop_nop_nop_nop_nop_nop_end_ddd,
    ddd_ddd_hdr_pfx_nop_nop_end_ddd,
    end_ddd_hdr_pfx_nop_nop_end_ddd,
    ddd_hdr_pfx_pfx_nop_nop_end_ddd,
    hdr_pfx_pfx_pfx_nop_nop_end_ddd,
    pfx_pfx_pfx_pfx_nop_nop_end_ddd,
    ddd_ddd_ddd_ddd_hdr_pfx_end_ddd,
    end_ddd_ddd_ddd_hdr_pfx_end_ddd,
    hdr_end_ddd_ddd_hdr_pfx_end_ddd,
    nop_end_ddd_ddd_hdr_pfx_end_ddd,
    pfx_end_ddd_ddd_hdr_pfx_end_ddd,
    ddd_hdr_end_ddd_hdr_pfx_end_ddd,
    nop_nop_end_ddd_hdr_pfx_end_ddd,
    hdr_pfx_end_ddd_hdr_pfx_end_ddd,
    pfx_pfx_end_ddd_hdr_pfx_end_ddd,
    ddd_ddd_ddd_hdr_pfx_pfx_end_ddd,
    end_ddd_ddd_hdr_pfx_pfx_end_ddd,
    hdr_end_ddd_hdr_pfx_pfx_end_ddd,
    nop_end_ddd_hdr_pfx_pfx_end_ddd,
    pfx_end_ddd_hdr_pfx_pfx_end_ddd,
    ddd_ddd_hdr_pfx_pfx_pfx_end_ddd,
    end_ddd_hdr_pfx_pfx_pfx_end_ddd,
    ddd_hdr_pfx_pfx_pfx_pfx_end_ddd,
    hdr_pfx_pfx_pfx_pfx_pfx_end_ddd,
    pfx_pfx_pfx_pfx_pfx_pfx_end_ddd,
    ddd_ddd_ddd_ddd_ddd_ddd_hdr_end,
    end_ddd_ddd_ddd_ddd_ddd_hdr_end,
    hdr_end_ddd_ddd_ddd_ddd_hdr_end,
    nop_end_ddd_ddd_ddd_ddd_hdr_end,
    pfx_end_ddd_ddd_ddd_ddd_hdr_end,
    ddd_hdr_end_ddd_ddd_ddd_hdr_end,
    nop_nop_end_ddd_ddd_ddd_hdr_end,
    hdr_pfx_end_ddd_ddd_ddd_hdr_end,
    pfx_pfx_end_ddd_ddd_ddd_hdr_end,
    ddd_ddd_hdr_end_ddd_ddd_hdr_end,
    end_ddd_hdr_end_ddd_ddd_hdr_end,
    nop_nop_nop_end_ddd_ddd_hdr_end,
    ddd_hdr_pfx_end_ddd_ddd_hdr_end,
    hdr_pfx_pfx_end_ddd_ddd_hdr_end,
    pfx_pfx_pfx_end_ddd_ddd_hdr_end,
    ddd_ddd_ddd_hdr_end_ddd_hdr_end,
    end_ddd_ddd_hdr_end_ddd_hdr_end,
    hdr_end_ddd_hdr_end_ddd_hdr_end,
    nop_end_ddd_hdr_end_ddd_hdr_end,
    pfx_end_ddd_hdr_end_ddd_hdr_end,
    nop_nop_nop_nop_end_ddd_hdr_end,
    ddd_ddd_hdr_pfx_end_ddd_hdr_end,
    end_ddd_hdr_pfx_end_ddd_hdr_end,
    ddd_hdr_pfx_pfx_end_ddd_hdr_end,
    hdr_pfx_pfx_pfx_end_ddd_hdr_end,
    pfx_pfx_pfx_pfx_end_ddd_hdr_end,
    ddd_ddd_ddd_hdr_nop_nop_nop_end,
    end_ddd_ddd_hdr_nop_nop_nop_end,
    hdr_end_ddd_hdr_nop_nop_nop_end,
    nop_end_ddd_hdr_nop_nop_nop_end,
    pfx_end_ddd_hdr_nop_nop_nop_end,
    nop_nop_nop_nop_nop_nop_nop_end,
    ddd_ddd_hdr_pfx_nop_nop_nop_end,
    end_ddd_hdr_pfx_nop_nop_nop_end,
    ddd_hdr_pfx_pfx_nop_nop_nop_end,
    hdr_pfx_pfx_pfx_nop_nop_nop_end,
    pfx_pfx_pfx_pfx_nop_nop_nop_end,
    ddd_ddd_ddd_ddd_ddd_hdr_pfx_end,
    end_ddd_ddd_ddd_ddd_hdr_pfx_end,
    hdr_end_ddd_ddd_ddd_hdr_pfx_end,
    nop_end_ddd_ddd_ddd_hdr_pfx_end,
    pfx_end_ddd_ddd_ddd_hdr_pfx_end,
    ddd_hdr_end_ddd_ddd_hdr_pfx_end,
    nop_nop_end_ddd_ddd_hdr_pfx_end,
    hdr_pfx_end_ddd_ddd_hdr_pfx_end,
    pfx_pfx_end_ddd_ddd_hdr_pfx_end,
    ddd_ddd_hdr_end_ddd_hdr_pfx_end,
    end_ddd_hdr_end_ddd_hdr_pfx_end,
    nop_nop_nop_end_ddd_hdr_pfx_end,
    ddd_hdr_pfx_end_ddd_hdr_pfx_end,
    hdr_pfx_pfx_end_ddd_hdr_pfx_end,
    pfx_pfx_pfx_end_ddd_hdr_pfx_end,
    ddd_ddd_ddd_ddd_hdr_pfx_pfx_end,
    end_ddd_ddd_ddd_hdr_pfx_pfx_end,
    hdr_end_ddd_ddd_hdr_pfx_pfx_end,
    nop_end_ddd_ddd_hdr_pfx_pfx_end,
    pfx_end_ddd_ddd_hdr_pfx_pfx_end,
    ddd_hdr_end_ddd_hdr_pfx_pfx_end,
    nop_nop_end_ddd_hdr_pfx_pfx_end,
    hdr_pfx_end_ddd_hdr_pfx_pfx_end,
    pfx_pfx_end_ddd_hdr_pfx_pfx_end,
    ddd_ddd_ddd_hdr_pfx_pfx_pfx_end,
    end_ddd_ddd_hdr_pfx_pfx_pfx_end,
    hdr_end_ddd_hdr_pfx_pfx_pfx_end,
    nop_end_ddd_hdr_pfx_pfx_pfx_end,
    pfx_end_ddd_hdr_pfx_pfx_pfx_end,
    ddd_ddd_hdr_pfx_pfx_pfx_pfx_end,
    end_ddd_hdr_pfx_pfx_pfx_pfx_end,
    ddd_hdr_pfx_pfx_pfx_pfx_pfx_end,
    hdr_pfx_pfx_pfx_pfx_pfx_pfx_end,
    pfx_pfx_pfx_pfx_pfx_pfx_pfx_end,
    ddd_ddd_ddd_hdr_nop_nop_nop_nop,
    end_ddd_ddd_hdr_nop_nop_nop_nop,
    hdr_end_ddd_hdr_nop_nop_nop_nop,
    nop_end_ddd_hdr_nop_nop_nop_nop,
    pfx_end_ddd_hdr_nop_nop_nop_nop,
    nop_nop_nop_nop_nop_nop_nop_nop,
    ddd_ddd_hdr_pfx_nop_nop_nop_nop,
    end_ddd_hdr_pfx_nop_nop_nop_nop,
    ddd_hdr_pfx_pfx_nop_nop_nop_nop,
    hdr_pfx_pfx_pfx_nop_nop_nop_nop,
    pfx_pfx_pfx_pfx_nop_nop_nop_nop,
    ddd_ddd_ddd_ddd_ddd_ddd_hdr_pfx,
    end_ddd_ddd_ddd_ddd_ddd_hdr_pfx,
    hdr_end_ddd_ddd_ddd_ddd_hdr_pfx,
    nop_end_ddd_ddd_ddd_ddd_hdr_pfx,
    pfx_end_ddd_ddd_ddd_ddd_hdr_pfx,
    ddd_hdr_end_ddd_ddd_ddd_hdr_pfx,
    nop_nop_end_ddd_ddd_ddd_hdr_pfx,
    hdr_pfx_end_ddd_ddd_ddd_hdr_pfx,
    pfx_pfx_end_ddd_ddd_ddd_hdr_pfx,
    ddd_ddd_hdr_end_ddd_ddd_hdr_pfx,
    end_ddd_hdr_end_ddd_ddd_hdr_pfx,
    nop_nop_nop_end_ddd_ddd_hdr_pfx,
    ddd_hdr_pfx_end_ddd_ddd_hdr_pfx,
    hdr_pfx_pfx_end_ddd_ddd_hdr_pfx,
    pfx_pfx_pfx_end_ddd_ddd_hdr_pfx,
    ddd_ddd_ddd_hdr_end_ddd_hdr_pfx,
    end_ddd_ddd_hdr_end_ddd_hdr_pfx,
    hdr_end_ddd_hdr_end_ddd_hdr_pfx,
    nop_end_ddd_hdr_end_ddd_hdr_pfx,
    pfx_end_ddd_hdr_end_ddd_hdr_pfx,
    nop_nop_nop_nop_end_ddd_hdr_pfx,
    ddd_ddd_hdr_pfx_end_ddd_hdr_pfx,
    end_ddd_hdr_pfx_end_ddd_hdr_pfx,
    ddd_hdr_pfx_pfx_end_ddd_hdr_pfx,
    hdr_pfx_pfx_pfx_end_ddd_hdr_pfx,
    pfx_pfx_pfx_pfx_end_ddd_hdr_pfx,
    ddd_ddd_ddd_ddd_ddd_hdr_pfx_pfx,
    end_ddd_ddd_ddd_ddd_hdr_pfx_pfx,
    hdr_end_ddd_ddd_ddd_hdr_pfx_pfx,
    nop_end_ddd_ddd_ddd_hdr_pfx_pfx,
    pfx_end_ddd_ddd_ddd_hdr_pfx_pfx,
    ddd_hdr_end_ddd_ddd_hdr_pfx_pfx,
    nop_nop_end_ddd_ddd_hdr_pfx_pfx,
    hdr_pfx_end_ddd_ddd_hdr_pfx_pfx,
    pfx_pfx_end_ddd_ddd_hdr_pfx_pfx,
    ddd_ddd_hdr_end_ddd_hdr_pfx_pfx,
    end_ddd_hdr_end_ddd_hdr_pfx_pfx,
    nop_nop_nop_end_ddd_hdr_pfx_pfx,
    ddd_hdr_pfx_end_ddd_hdr_pfx_pfx,
    hdr_pfx_pfx_end_ddd_hdr_pfx_pfx,
    pfx_pfx_pfx_end_ddd_hdr_pfx_pfx,
    ddd_ddd_ddd_ddd_hdr_pfx_pfx_pfx,
    end_ddd_ddd_ddd_hdr_pfx_pfx_pfx,
    hdr_end_ddd_ddd_hdr_pfx_pfx_pfx,
    nop_end_ddd_ddd_hdr_pfx_pfx_pfx,
    pfx_end_ddd_ddd_hdr_pfx_pfx_pfx,
    ddd_hdr_end_ddd_hdr_pfx_pfx_pfx,
    nop_nop_end_ddd_hdr_pfx_pfx_pfx,
    hdr_pfx_end_ddd_hdr_pfx_pfx_pfx,
    pfx_pfx_end_ddd_hdr_pfx_pfx_pfx,
    ddd_ddd_ddd_hdr_pfx_pfx_pfx_pfx,
    end_ddd_ddd_hdr_pfx_pfx_pfx_pfx,
    hdr_end_ddd_hdr_pfx_pfx_pfx_pfx,
    nop_end_ddd_hdr_pfx_pfx_pfx_pfx,
    pfx_end_ddd_hdr_pfx_pfx_pfx_pfx,
    ddd_ddd_hdr_pfx_pfx_pfx_pfx_pfx,
    end_ddd_hdr_pfx_pfx_pfx_pfx_pfx,
    ddd_hdr_pfx_pfx_pfx_pfx_pfx_pfx,
    hdr_pfx_pfx_pfx_pfx_pfx_pfx_pfx,
    pfx_pfx_pfx_pfx_pfx_pfx_pfx_pfx,
    xxx_xxx_xxx_xxx_xxx_xxx_xxx_xxx
} dec_case;

always_comb begin : tlp_out_PROC
    dec_case = xxx_xxx_xxx_xxx_xxx_xxx_xxx_xxx;
    tlp_pfx = 8'b00000000;
    tlp_soh = 8'b00000000;
    tlp_idl = 8'b00000000;
    unique case ( 1'b1 )
      prev_tlp_none && hdr_0_eot_n :
        begin
          dec_case = ddd_ddd_ddd_ddd_ddd_ddd_ddd_hdr;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000001;
          tlp_end = 8'b00000000;
        end

      prev_tlp_none && hdr_0_eot_7 :
        begin
          dec_case = end_ddd_ddd_ddd_ddd_ddd_ddd_hdr;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000001;
          tlp_end = 8'b10000000;
        end

      prev_tlp_none && hdr_0_eot_6 && hdr_7_eot_n :
        begin
          dec_case = hdr_end_ddd_ddd_ddd_ddd_ddd_hdr;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10000001;
          tlp_end = 8'b01000000;
        end

      prev_tlp_none && hdr_0_eot_6 && raw[7].tkn==NOP_TKN :
        begin
          dec_case = nop_end_ddd_ddd_ddd_ddd_ddd_hdr;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b10000000;
          tlp_soh = 8'b00000001;
          tlp_end = 8'b01000000;
        end

      prev_tlp_none && hdr_0_eot_6 && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_end_ddd_ddd_ddd_ddd_ddd_hdr;
          tlp_pfx = 8'b10000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000001;
          tlp_end = 8'b01000000;
        end

      prev_tlp_none && hdr_0_eot_5 && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_end_ddd_ddd_ddd_ddd_hdr;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b01000001;
          tlp_end = 8'b00100000;
        end

      prev_tlp_none && hdr_0_eot_5 && raw[6].tkn==NOP_TKN :
        begin
          dec_case = nop_nop_end_ddd_ddd_ddd_ddd_hdr;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b11000000;
          tlp_soh = 8'b00000001;
          tlp_end = 8'b00100000;
        end

      prev_tlp_none && hdr_0_eot_5 && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_end_ddd_ddd_ddd_ddd_hdr;
          tlp_pfx = 8'b01000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10000001;
          tlp_end = 8'b00100000;
        end

      prev_tlp_none && hdr_0_eot_5 && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_end_ddd_ddd_ddd_ddd_hdr;
          tlp_pfx = 8'b11000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000001;
          tlp_end = 8'b00100000;
        end

      prev_tlp_none && hdr_0_eot_4 && hdr_5_eot_n :
        begin
          dec_case = ddd_ddd_hdr_end_ddd_ddd_ddd_hdr;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100001;
          tlp_end = 8'b00010000;
        end

      prev_tlp_none && hdr_0_eot_4 && hdr_5_eot_7 :
        begin
          dec_case = end_ddd_hdr_end_ddd_ddd_ddd_hdr;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100001;
          tlp_end = 8'b10010000;
        end

      prev_tlp_none && hdr_0_eot_4 && raw[5].tkn==NOP_TKN :
        begin
          dec_case = nop_nop_nop_end_ddd_ddd_ddd_hdr;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b11100000;
          tlp_soh = 8'b00000001;
          tlp_end = 8'b00010000;
        end

      prev_tlp_none && hdr_0_eot_4 && raw[5].tkn==PFX_TKN && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_pfx_end_ddd_ddd_ddd_hdr;
          tlp_pfx = 8'b00100000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b01000001;
          tlp_end = 8'b00010000;
        end

      prev_tlp_none && hdr_0_eot_4 && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_pfx_end_ddd_ddd_ddd_hdr;
          tlp_pfx = 8'b01100000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10000001;
          tlp_end = 8'b00010000;
        end

      prev_tlp_none && hdr_0_eot_4 && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_pfx_end_ddd_ddd_ddd_hdr;
          tlp_pfx = 8'b11100000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000001;
          tlp_end = 8'b00010000;
        end

      prev_tlp_none && hdr_0_eot_3 && hdr_4_eot_n :
        begin
          dec_case = ddd_ddd_ddd_hdr_end_ddd_ddd_hdr;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00010001;
          tlp_end = 8'b00001000;
        end

      prev_tlp_none && hdr_0_eot_3 && hdr_4_eot_7 :
        begin
          dec_case = end_ddd_ddd_hdr_end_ddd_ddd_hdr;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00010001;
          tlp_end = 8'b10001000;
        end

      prev_tlp_none && hdr_0_eot_3 && hdr_4_eot_6 && hdr_7_eot_n :
        begin
          dec_case = hdr_end_ddd_hdr_end_ddd_ddd_hdr;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10010001;
          tlp_end = 8'b01001000;
        end

      prev_tlp_none && hdr_0_eot_3 && hdr_4_eot_6 && raw[7].tkn==NOP_TKN :
        begin
          dec_case = nop_end_ddd_hdr_end_ddd_ddd_hdr;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b10000000;
          tlp_soh = 8'b00010001;
          tlp_end = 8'b01001000;
        end

      prev_tlp_none && hdr_0_eot_3 && hdr_4_eot_6 && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_end_ddd_hdr_end_ddd_ddd_hdr;
          tlp_pfx = 8'b10000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00010001;
          tlp_end = 8'b01001000;
        end

      prev_tlp_none && hdr_0_eot_3 && raw[4].tkn==NOP_TKN :
        begin
          dec_case = nop_nop_nop_nop_end_ddd_ddd_hdr;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b11110000;
          tlp_soh = 8'b00000001;
          tlp_end = 8'b00001000;
        end

      prev_tlp_none && hdr_0_eot_3 && raw[4].tkn==PFX_TKN && hdr_5_eot_n :
        begin
          dec_case = ddd_ddd_hdr_pfx_end_ddd_ddd_hdr;
          tlp_pfx = 8'b00010000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100001;
          tlp_end = 8'b00001000;
        end

      prev_tlp_none && hdr_0_eot_3 && raw[4].tkn==PFX_TKN && hdr_5_eot_7 :
        begin
          dec_case = end_ddd_hdr_pfx_end_ddd_ddd_hdr;
          tlp_pfx = 8'b00010000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100001;
          tlp_end = 8'b10001000;
        end

      prev_tlp_none && hdr_0_eot_3 && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_pfx_pfx_end_ddd_ddd_hdr;
          tlp_pfx = 8'b00110000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b01000001;
          tlp_end = 8'b00001000;
        end

      prev_tlp_none && hdr_0_eot_3 && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_pfx_pfx_end_ddd_ddd_hdr;
          tlp_pfx = 8'b01110000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10000001;
          tlp_end = 8'b00001000;
        end

      prev_tlp_none && hdr_0_eot_3 && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_pfx_pfx_end_ddd_ddd_hdr;
          tlp_pfx = 8'b11110000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000001;
          tlp_end = 8'b00001000;
        end

      prev_tlp_none && hdr_0_eot_2 && hdr_3_eot_n :
        begin
          dec_case = ddd_ddd_ddd_ddd_hdr_end_ddd_hdr;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00001001;
          tlp_end = 8'b00000100;
        end

      prev_tlp_none && hdr_0_eot_2 && hdr_3_eot_7 :
        begin
          dec_case = end_ddd_ddd_ddd_hdr_end_ddd_hdr;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00001001;
          tlp_end = 8'b10000100;
        end

      prev_tlp_none && hdr_0_eot_2 && hdr_3_eot_6 && hdr_7_eot_n :
        begin
          dec_case = hdr_end_ddd_ddd_hdr_end_ddd_hdr;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10001001;
          tlp_end = 8'b01000100;
        end

      prev_tlp_none && hdr_0_eot_2 && hdr_3_eot_6 && raw[7].tkn==NOP_TKN :
        begin
          dec_case = nop_end_ddd_ddd_hdr_end_ddd_hdr;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b10000000;
          tlp_soh = 8'b00001001;
          tlp_end = 8'b01000100;
        end

      prev_tlp_none && hdr_0_eot_2 && hdr_3_eot_6 && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_end_ddd_ddd_hdr_end_ddd_hdr;
          tlp_pfx = 8'b10000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00001001;
          tlp_end = 8'b01000100;
        end

      prev_tlp_none && hdr_0_eot_2 && hdr_3_eot_5 && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_end_ddd_hdr_end_ddd_hdr;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b01001001;
          tlp_end = 8'b00100100;
        end

      prev_tlp_none && hdr_0_eot_2 && hdr_3_eot_5 && raw[6].tkn==NOP_TKN :
        begin
          dec_case = nop_nop_end_ddd_hdr_end_ddd_hdr;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b11000000;
          tlp_soh = 8'b00001001;
          tlp_end = 8'b00100100;
        end

      prev_tlp_none && hdr_0_eot_2 && hdr_3_eot_5 && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_end_ddd_hdr_end_ddd_hdr;
          tlp_pfx = 8'b01000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10001001;
          tlp_end = 8'b00100100;
        end

      prev_tlp_none && hdr_0_eot_2 && hdr_3_eot_5 && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_end_ddd_hdr_end_ddd_hdr;
          tlp_pfx = 8'b11000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00001001;
          tlp_end = 8'b00100100;
        end

      prev_tlp_none && hdr_0_eot_2 && raw[3].tkn==NOP_TKN && hdr_4_eot_n :
        begin
          dec_case = ddd_ddd_ddd_hdr_nop_end_ddd_hdr;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00001000;
          tlp_soh = 8'b00010001;
          tlp_end = 8'b00000100;
        end

      prev_tlp_none && hdr_0_eot_2 && raw[3].tkn==NOP_TKN && hdr_4_eot_7 :
        begin
          dec_case = end_ddd_ddd_hdr_nop_end_ddd_hdr;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00001000;
          tlp_soh = 8'b00010001;
          tlp_end = 8'b10000100;
        end

      prev_tlp_none && hdr_0_eot_2 && raw[3].tkn==NOP_TKN && hdr_4_eot_6 && hdr_7_eot_n :
        begin
          dec_case = hdr_end_ddd_hdr_nop_end_ddd_hdr;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00001000;
          tlp_soh = 8'b10010001;
          tlp_end = 8'b01000100;
        end

      prev_tlp_none && hdr_0_eot_2 && raw[3].tkn==NOP_TKN && hdr_4_eot_6 && raw[7].tkn==NOP_TKN :
        begin
          dec_case = nop_end_ddd_hdr_nop_end_ddd_hdr;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b10001000;
          tlp_soh = 8'b00010001;
          tlp_end = 8'b01000100;
        end

      prev_tlp_none && hdr_0_eot_2 && raw[3].tkn==NOP_TKN && hdr_4_eot_6 && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_end_ddd_hdr_nop_end_ddd_hdr;
          tlp_pfx = 8'b10000000;
          tlp_idl = 8'b00001000;
          tlp_soh = 8'b00010001;
          tlp_end = 8'b01000100;
        end

      prev_tlp_none && hdr_0_eot_2 && raw[3].tkn==NOP_TKN && raw[4].tkn==NOP_TKN :
        begin
          dec_case = nop_nop_nop_nop_nop_end_ddd_hdr;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b11111000;
          tlp_soh = 8'b00000001;
          tlp_end = 8'b00000100;
        end

      prev_tlp_none && hdr_0_eot_2 && raw[3].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && hdr_5_eot_n :
        begin
          dec_case = ddd_ddd_hdr_pfx_nop_end_ddd_hdr;
          tlp_pfx = 8'b00010000;
          tlp_idl = 8'b00001000;
          tlp_soh = 8'b00100001;
          tlp_end = 8'b00000100;
        end

      prev_tlp_none && hdr_0_eot_2 && raw[3].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && hdr_5_eot_7 :
        begin
          dec_case = end_ddd_hdr_pfx_nop_end_ddd_hdr;
          tlp_pfx = 8'b00010000;
          tlp_idl = 8'b00001000;
          tlp_soh = 8'b00100001;
          tlp_end = 8'b10000100;
        end

      prev_tlp_none && hdr_0_eot_2 && raw[3].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_pfx_pfx_nop_end_ddd_hdr;
          tlp_pfx = 8'b00110000;
          tlp_idl = 8'b00001000;
          tlp_soh = 8'b01000001;
          tlp_end = 8'b00000100;
        end

      prev_tlp_none && hdr_0_eot_2 && raw[3].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_pfx_pfx_nop_end_ddd_hdr;
          tlp_pfx = 8'b01110000;
          tlp_idl = 8'b00001000;
          tlp_soh = 8'b10000001;
          tlp_end = 8'b00000100;
        end

      prev_tlp_none && hdr_0_eot_2 && raw[3].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_pfx_pfx_nop_end_ddd_hdr;
          tlp_pfx = 8'b11110000;
          tlp_idl = 8'b00001000;
          tlp_soh = 8'b00000001;
          tlp_end = 8'b00000100;
        end

      prev_tlp_none && hdr_0_eot_2 && raw[3].tkn==PFX_TKN && hdr_4_eot_n :
        begin
          dec_case = ddd_ddd_ddd_hdr_pfx_end_ddd_hdr;
          tlp_pfx = 8'b00001000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00010001;
          tlp_end = 8'b00000100;
        end

      prev_tlp_none && hdr_0_eot_2 && raw[3].tkn==PFX_TKN && hdr_4_eot_7 :
        begin
          dec_case = end_ddd_ddd_hdr_pfx_end_ddd_hdr;
          tlp_pfx = 8'b00001000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00010001;
          tlp_end = 8'b10000100;
        end

      prev_tlp_none && hdr_0_eot_2 && raw[3].tkn==PFX_TKN && hdr_4_eot_6 && hdr_7_eot_n :
        begin
          dec_case = hdr_end_ddd_hdr_pfx_end_ddd_hdr;
          tlp_pfx = 8'b00001000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10010001;
          tlp_end = 8'b01000100;
        end

      prev_tlp_none && hdr_0_eot_2 && raw[3].tkn==PFX_TKN && hdr_4_eot_6 && raw[7].tkn==NOP_TKN :
        begin
          dec_case = nop_end_ddd_hdr_pfx_end_ddd_hdr;
          tlp_pfx = 8'b00001000;
          tlp_idl = 8'b10000000;
          tlp_soh = 8'b00010001;
          tlp_end = 8'b01000100;
        end

      prev_tlp_none && hdr_0_eot_2 && raw[3].tkn==PFX_TKN && hdr_4_eot_6 && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_end_ddd_hdr_pfx_end_ddd_hdr;
          tlp_pfx = 8'b10001000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00010001;
          tlp_end = 8'b01000100;
        end

      prev_tlp_none && hdr_0_eot_2 && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && hdr_5_eot_n :
        begin
          dec_case = ddd_ddd_hdr_pfx_pfx_end_ddd_hdr;
          tlp_pfx = 8'b00011000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100001;
          tlp_end = 8'b00000100;
        end

      prev_tlp_none && hdr_0_eot_2 && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && hdr_5_eot_7 :
        begin
          dec_case = end_ddd_hdr_pfx_pfx_end_ddd_hdr;
          tlp_pfx = 8'b00011000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100001;
          tlp_end = 8'b10000100;
        end

      prev_tlp_none && hdr_0_eot_2 && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_pfx_pfx_pfx_end_ddd_hdr;
          tlp_pfx = 8'b00111000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b01000001;
          tlp_end = 8'b00000100;
        end

      prev_tlp_none && hdr_0_eot_2 && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_pfx_pfx_pfx_end_ddd_hdr;
          tlp_pfx = 8'b01111000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10000001;
          tlp_end = 8'b00000100;
        end

      prev_tlp_none && hdr_0_eot_2 && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_pfx_pfx_pfx_end_ddd_hdr;
          tlp_pfx = 8'b11111000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000001;
          tlp_end = 8'b00000100;
        end

      prev_tlp_eot_n :
        begin
          dec_case = ddd_ddd_ddd_ddd_ddd_ddd_ddd_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000000;
          tlp_end = 8'b00000000;
        end

      prev_tlp_eot_7 :
        begin
          dec_case = end_ddd_ddd_ddd_ddd_ddd_ddd_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000000;
          tlp_end = 8'b10000000;
        end

      prev_tlp_eot_6 && hdr_7_eot_n :
        begin
          dec_case = hdr_end_ddd_ddd_ddd_ddd_ddd_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10000000;
          tlp_end = 8'b01000000;
        end

      prev_tlp_eot_6 && raw[7].tkn==NOP_TKN :
        begin
          dec_case = nop_end_ddd_ddd_ddd_ddd_ddd_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b10000000;
          tlp_soh = 8'b00000000;
          tlp_end = 8'b01000000;
        end

      prev_tlp_eot_6 && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_end_ddd_ddd_ddd_ddd_ddd_ddd;
          tlp_pfx = 8'b10000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000000;
          tlp_end = 8'b01000000;
        end

      prev_tlp_eot_5 && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_end_ddd_ddd_ddd_ddd_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b01000000;
          tlp_end = 8'b00100000;
        end

      prev_tlp_eot_5 && raw[6].tkn==NOP_TKN :
        begin
          dec_case = nop_nop_end_ddd_ddd_ddd_ddd_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b11000000;
          tlp_soh = 8'b00000000;
          tlp_end = 8'b00100000;
        end

      prev_tlp_eot_5 && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_end_ddd_ddd_ddd_ddd_ddd;
          tlp_pfx = 8'b01000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10000000;
          tlp_end = 8'b00100000;
        end

      prev_tlp_eot_5 && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_end_ddd_ddd_ddd_ddd_ddd;
          tlp_pfx = 8'b11000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000000;
          tlp_end = 8'b00100000;
        end

      prev_tlp_eot_4 && hdr_5_eot_n :
        begin
          dec_case = ddd_ddd_hdr_end_ddd_ddd_ddd_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100000;
          tlp_end = 8'b00010000;
        end

      prev_tlp_eot_4 && hdr_5_eot_7 :
        begin
          dec_case = end_ddd_hdr_end_ddd_ddd_ddd_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100000;
          tlp_end = 8'b10010000;
        end

      prev_tlp_eot_4 && raw[5].tkn==NOP_TKN :
        begin
          dec_case = nop_nop_nop_end_ddd_ddd_ddd_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b11100000;
          tlp_soh = 8'b00000000;
          tlp_end = 8'b00010000;
        end

      prev_tlp_eot_4 && raw[5].tkn==PFX_TKN && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_pfx_end_ddd_ddd_ddd_ddd;
          tlp_pfx = 8'b00100000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b01000000;
          tlp_end = 8'b00010000;
        end

      prev_tlp_eot_4 && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_pfx_end_ddd_ddd_ddd_ddd;
          tlp_pfx = 8'b01100000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10000000;
          tlp_end = 8'b00010000;
        end

      prev_tlp_eot_4 && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_pfx_end_ddd_ddd_ddd_ddd;
          tlp_pfx = 8'b11100000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000000;
          tlp_end = 8'b00010000;
        end

      prev_tlp_eot_3 && hdr_4_eot_n :
        begin
          dec_case = ddd_ddd_ddd_hdr_end_ddd_ddd_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b00001000;
        end

      prev_tlp_eot_3 && hdr_4_eot_7 :
        begin
          dec_case = end_ddd_ddd_hdr_end_ddd_ddd_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b10001000;
        end

      prev_tlp_eot_3 && hdr_4_eot_6 && hdr_7_eot_n :
        begin
          dec_case = hdr_end_ddd_hdr_end_ddd_ddd_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10010000;
          tlp_end = 8'b01001000;
        end

      prev_tlp_eot_3 && hdr_4_eot_6 && raw[7].tkn==NOP_TKN :
        begin
          dec_case = nop_end_ddd_hdr_end_ddd_ddd_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b10000000;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b01001000;
        end

      prev_tlp_eot_3 && hdr_4_eot_6 && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_end_ddd_hdr_end_ddd_ddd_ddd;
          tlp_pfx = 8'b10000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b01001000;
        end

      prev_tlp_eot_3 && raw[4].tkn==NOP_TKN :
        begin
          dec_case = nop_nop_nop_nop_end_ddd_ddd_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b11110000;
          tlp_soh = 8'b00000000;
          tlp_end = 8'b00001000;
        end

      prev_tlp_eot_3 && raw[4].tkn==PFX_TKN && hdr_5_eot_n :
        begin
          dec_case = ddd_ddd_hdr_pfx_end_ddd_ddd_ddd;
          tlp_pfx = 8'b00010000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100000;
          tlp_end = 8'b00001000;
        end

      prev_tlp_eot_3 && raw[4].tkn==PFX_TKN && hdr_5_eot_7 :
        begin
          dec_case = end_ddd_hdr_pfx_end_ddd_ddd_ddd;
          tlp_pfx = 8'b00010000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100000;
          tlp_end = 8'b10001000;
        end

      prev_tlp_eot_3 && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_pfx_pfx_end_ddd_ddd_ddd;
          tlp_pfx = 8'b00110000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b01000000;
          tlp_end = 8'b00001000;
        end

      prev_tlp_eot_3 && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_pfx_pfx_end_ddd_ddd_ddd;
          tlp_pfx = 8'b01110000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10000000;
          tlp_end = 8'b00001000;
        end

      prev_tlp_eot_3 && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_pfx_pfx_end_ddd_ddd_ddd;
          tlp_pfx = 8'b11110000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000000;
          tlp_end = 8'b00001000;
        end

      prev_tlp_eot_2 && hdr_3_eot_n :
        begin
          dec_case = ddd_ddd_ddd_ddd_hdr_end_ddd_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00001000;
          tlp_end = 8'b00000100;
        end

      prev_tlp_eot_2 && hdr_3_eot_7 :
        begin
          dec_case = end_ddd_ddd_ddd_hdr_end_ddd_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00001000;
          tlp_end = 8'b10000100;
        end

      prev_tlp_eot_2 && hdr_3_eot_6 && hdr_7_eot_n :
        begin
          dec_case = hdr_end_ddd_ddd_hdr_end_ddd_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10001000;
          tlp_end = 8'b01000100;
        end

      prev_tlp_eot_2 && hdr_3_eot_6 && raw[7].tkn==NOP_TKN :
        begin
          dec_case = nop_end_ddd_ddd_hdr_end_ddd_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b10000000;
          tlp_soh = 8'b00001000;
          tlp_end = 8'b01000100;
        end

      prev_tlp_eot_2 && hdr_3_eot_6 && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_end_ddd_ddd_hdr_end_ddd_ddd;
          tlp_pfx = 8'b10000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00001000;
          tlp_end = 8'b01000100;
        end

      prev_tlp_eot_2 && hdr_3_eot_5 && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_end_ddd_hdr_end_ddd_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b01001000;
          tlp_end = 8'b00100100;
        end

      prev_tlp_eot_2 && hdr_3_eot_5 && raw[6].tkn==NOP_TKN :
        begin
          dec_case = nop_nop_end_ddd_hdr_end_ddd_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b11000000;
          tlp_soh = 8'b00001000;
          tlp_end = 8'b00100100;
        end

      prev_tlp_eot_2 && hdr_3_eot_5 && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_end_ddd_hdr_end_ddd_ddd;
          tlp_pfx = 8'b01000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10001000;
          tlp_end = 8'b00100100;
        end

      prev_tlp_eot_2 && hdr_3_eot_5 && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_end_ddd_hdr_end_ddd_ddd;
          tlp_pfx = 8'b11000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00001000;
          tlp_end = 8'b00100100;
        end

      prev_tlp_eot_2 && raw[3].tkn==NOP_TKN && hdr_4_eot_n :
        begin
          dec_case = ddd_ddd_ddd_hdr_nop_end_ddd_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00001000;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b00000100;
        end

      prev_tlp_eot_2 && raw[3].tkn==NOP_TKN && hdr_4_eot_7 :
        begin
          dec_case = end_ddd_ddd_hdr_nop_end_ddd_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00001000;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b10000100;
        end

      prev_tlp_eot_2 && raw[3].tkn==NOP_TKN && hdr_4_eot_6 && hdr_7_eot_n :
        begin
          dec_case = hdr_end_ddd_hdr_nop_end_ddd_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00001000;
          tlp_soh = 8'b10010000;
          tlp_end = 8'b01000100;
        end

      prev_tlp_eot_2 && raw[3].tkn==NOP_TKN && hdr_4_eot_6 && raw[7].tkn==NOP_TKN :
        begin
          dec_case = nop_end_ddd_hdr_nop_end_ddd_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b10001000;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b01000100;
        end

      prev_tlp_eot_2 && raw[3].tkn==NOP_TKN && hdr_4_eot_6 && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_end_ddd_hdr_nop_end_ddd_ddd;
          tlp_pfx = 8'b10000000;
          tlp_idl = 8'b00001000;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b01000100;
        end

      prev_tlp_eot_2 && raw[3].tkn==NOP_TKN && raw[4].tkn==NOP_TKN :
        begin
          dec_case = nop_nop_nop_nop_nop_end_ddd_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b11111000;
          tlp_soh = 8'b00000000;
          tlp_end = 8'b00000100;
        end

      prev_tlp_eot_2 && raw[3].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && hdr_5_eot_n :
        begin
          dec_case = ddd_ddd_hdr_pfx_nop_end_ddd_ddd;
          tlp_pfx = 8'b00010000;
          tlp_idl = 8'b00001000;
          tlp_soh = 8'b00100000;
          tlp_end = 8'b00000100;
        end

      prev_tlp_eot_2 && raw[3].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && hdr_5_eot_7 :
        begin
          dec_case = end_ddd_hdr_pfx_nop_end_ddd_ddd;
          tlp_pfx = 8'b00010000;
          tlp_idl = 8'b00001000;
          tlp_soh = 8'b00100000;
          tlp_end = 8'b10000100;
        end

      prev_tlp_eot_2 && raw[3].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_pfx_pfx_nop_end_ddd_ddd;
          tlp_pfx = 8'b00110000;
          tlp_idl = 8'b00001000;
          tlp_soh = 8'b01000000;
          tlp_end = 8'b00000100;
        end

      prev_tlp_eot_2 && raw[3].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_pfx_pfx_nop_end_ddd_ddd;
          tlp_pfx = 8'b01110000;
          tlp_idl = 8'b00001000;
          tlp_soh = 8'b10000000;
          tlp_end = 8'b00000100;
        end

      prev_tlp_eot_2 && raw[3].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_pfx_pfx_nop_end_ddd_ddd;
          tlp_pfx = 8'b11110000;
          tlp_idl = 8'b00001000;
          tlp_soh = 8'b00000000;
          tlp_end = 8'b00000100;
        end

      prev_tlp_eot_2 && raw[3].tkn==PFX_TKN && hdr_4_eot_n :
        begin
          dec_case = ddd_ddd_ddd_hdr_pfx_end_ddd_ddd;
          tlp_pfx = 8'b00001000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b00000100;
        end

      prev_tlp_eot_2 && raw[3].tkn==PFX_TKN && hdr_4_eot_7 :
        begin
          dec_case = end_ddd_ddd_hdr_pfx_end_ddd_ddd;
          tlp_pfx = 8'b00001000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b10000100;
        end

      prev_tlp_eot_2 && raw[3].tkn==PFX_TKN && hdr_4_eot_6 && hdr_7_eot_n :
        begin
          dec_case = hdr_end_ddd_hdr_pfx_end_ddd_ddd;
          tlp_pfx = 8'b00001000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10010000;
          tlp_end = 8'b01000100;
        end

      prev_tlp_eot_2 && raw[3].tkn==PFX_TKN && hdr_4_eot_6 && raw[7].tkn==NOP_TKN :
        begin
          dec_case = nop_end_ddd_hdr_pfx_end_ddd_ddd;
          tlp_pfx = 8'b00001000;
          tlp_idl = 8'b10000000;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b01000100;
        end

      prev_tlp_eot_2 && raw[3].tkn==PFX_TKN && hdr_4_eot_6 && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_end_ddd_hdr_pfx_end_ddd_ddd;
          tlp_pfx = 8'b10001000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b01000100;
        end

      prev_tlp_eot_2 && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && hdr_5_eot_n :
        begin
          dec_case = ddd_ddd_hdr_pfx_pfx_end_ddd_ddd;
          tlp_pfx = 8'b00011000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100000;
          tlp_end = 8'b00000100;
        end

      prev_tlp_eot_2 && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && hdr_5_eot_7 :
        begin
          dec_case = end_ddd_hdr_pfx_pfx_end_ddd_ddd;
          tlp_pfx = 8'b00011000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100000;
          tlp_end = 8'b10000100;
        end

      prev_tlp_eot_2 && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_pfx_pfx_pfx_end_ddd_ddd;
          tlp_pfx = 8'b00111000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b01000000;
          tlp_end = 8'b00000100;
        end

      prev_tlp_eot_2 && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_pfx_pfx_pfx_end_ddd_ddd;
          tlp_pfx = 8'b01111000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10000000;
          tlp_end = 8'b00000100;
        end

      prev_tlp_eot_2 && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_pfx_pfx_pfx_end_ddd_ddd;
          tlp_pfx = 8'b11111000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000000;
          tlp_end = 8'b00000100;
        end

      prev_tlp_eot_1 && hdr_2_eot_n :
        begin
          dec_case = ddd_ddd_ddd_ddd_ddd_hdr_end_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000100;
          tlp_end = 8'b00000010;
        end

      prev_tlp_eot_1 && hdr_2_eot_7 :
        begin
          dec_case = end_ddd_ddd_ddd_ddd_hdr_end_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000100;
          tlp_end = 8'b10000010;
        end

      prev_tlp_eot_1 && hdr_2_eot_6 && hdr_7_eot_n :
        begin
          dec_case = hdr_end_ddd_ddd_ddd_hdr_end_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10000100;
          tlp_end = 8'b01000010;
        end

      prev_tlp_eot_1 && hdr_2_eot_6 && raw[7].tkn==NOP_TKN :
        begin
          dec_case = nop_end_ddd_ddd_ddd_hdr_end_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b10000000;
          tlp_soh = 8'b00000100;
          tlp_end = 8'b01000010;
        end

      prev_tlp_eot_1 && hdr_2_eot_6 && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_end_ddd_ddd_ddd_hdr_end_ddd;
          tlp_pfx = 8'b10000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000100;
          tlp_end = 8'b01000010;
        end

      prev_tlp_eot_1 && hdr_2_eot_5 && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_end_ddd_ddd_hdr_end_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b01000100;
          tlp_end = 8'b00100010;
        end

      prev_tlp_eot_1 && hdr_2_eot_5 && raw[6].tkn==NOP_TKN :
        begin
          dec_case = nop_nop_end_ddd_ddd_hdr_end_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b11000000;
          tlp_soh = 8'b00000100;
          tlp_end = 8'b00100010;
        end

      prev_tlp_eot_1 && hdr_2_eot_5 && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_end_ddd_ddd_hdr_end_ddd;
          tlp_pfx = 8'b01000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10000100;
          tlp_end = 8'b00100010;
        end

      prev_tlp_eot_1 && hdr_2_eot_5 && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_end_ddd_ddd_hdr_end_ddd;
          tlp_pfx = 8'b11000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000100;
          tlp_end = 8'b00100010;
        end

      prev_tlp_eot_1 && hdr_2_eot_4 && hdr_5_eot_n :
        begin
          dec_case = ddd_ddd_hdr_end_ddd_hdr_end_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100100;
          tlp_end = 8'b00010010;
        end

      prev_tlp_eot_1 && hdr_2_eot_4 && hdr_5_eot_7 :
        begin
          dec_case = end_ddd_hdr_end_ddd_hdr_end_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100100;
          tlp_end = 8'b10010010;
        end

      prev_tlp_eot_1 && hdr_2_eot_4 && raw[5].tkn==NOP_TKN :
        begin
          dec_case = nop_nop_nop_end_ddd_hdr_end_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b11100000;
          tlp_soh = 8'b00000100;
          tlp_end = 8'b00010010;
        end

      prev_tlp_eot_1 && hdr_2_eot_4 && raw[5].tkn==PFX_TKN && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_pfx_end_ddd_hdr_end_ddd;
          tlp_pfx = 8'b00100000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b01000100;
          tlp_end = 8'b00010010;
        end

      prev_tlp_eot_1 && hdr_2_eot_4 && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_pfx_end_ddd_hdr_end_ddd;
          tlp_pfx = 8'b01100000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10000100;
          tlp_end = 8'b00010010;
        end

      prev_tlp_eot_1 && hdr_2_eot_4 && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_pfx_end_ddd_hdr_end_ddd;
          tlp_pfx = 8'b11100000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000100;
          tlp_end = 8'b00010010;
        end

      prev_tlp_eot_1 && raw[2].tkn==NOP_TKN && hdr_4_eot_n :
        begin
          dec_case = ddd_ddd_ddd_hdr_nop_nop_end_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00001100;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b00000010;
        end

      prev_tlp_eot_1 && raw[2].tkn==NOP_TKN && hdr_4_eot_7 :
        begin
          dec_case = end_ddd_ddd_hdr_nop_nop_end_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00001100;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b10000010;
        end

      prev_tlp_eot_1 && raw[2].tkn==NOP_TKN && hdr_4_eot_6 && hdr_7_eot_n :
        begin
          dec_case = hdr_end_ddd_hdr_nop_nop_end_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00001100;
          tlp_soh = 8'b10010000;
          tlp_end = 8'b01000010;
        end

      prev_tlp_eot_1 && raw[2].tkn==NOP_TKN && hdr_4_eot_6 && raw[7].tkn==NOP_TKN :
        begin
          dec_case = nop_end_ddd_hdr_nop_nop_end_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b10001100;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b01000010;
        end

      prev_tlp_eot_1 && raw[2].tkn==NOP_TKN && hdr_4_eot_6 && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_end_ddd_hdr_nop_nop_end_ddd;
          tlp_pfx = 8'b10000000;
          tlp_idl = 8'b00001100;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b01000010;
        end

      prev_tlp_eot_1 && raw[2].tkn==NOP_TKN && raw[4].tkn==NOP_TKN :
        begin
          dec_case = nop_nop_nop_nop_nop_nop_end_ddd;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b11111100;
          tlp_soh = 8'b00000000;
          tlp_end = 8'b00000010;
        end

      prev_tlp_eot_1 && raw[2].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && hdr_5_eot_n :
        begin
          dec_case = ddd_ddd_hdr_pfx_nop_nop_end_ddd;
          tlp_pfx = 8'b00010000;
          tlp_idl = 8'b00001100;
          tlp_soh = 8'b00100000;
          tlp_end = 8'b00000010;
        end

      prev_tlp_eot_1 && raw[2].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && hdr_5_eot_7 :
        begin
          dec_case = end_ddd_hdr_pfx_nop_nop_end_ddd;
          tlp_pfx = 8'b00010000;
          tlp_idl = 8'b00001100;
          tlp_soh = 8'b00100000;
          tlp_end = 8'b10000010;
        end

      prev_tlp_eot_1 && raw[2].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_pfx_pfx_nop_nop_end_ddd;
          tlp_pfx = 8'b00110000;
          tlp_idl = 8'b00001100;
          tlp_soh = 8'b01000000;
          tlp_end = 8'b00000010;
        end

      prev_tlp_eot_1 && raw[2].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_pfx_pfx_nop_nop_end_ddd;
          tlp_pfx = 8'b01110000;
          tlp_idl = 8'b00001100;
          tlp_soh = 8'b10000000;
          tlp_end = 8'b00000010;
        end

      prev_tlp_eot_1 && raw[2].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_pfx_pfx_nop_nop_end_ddd;
          tlp_pfx = 8'b11110000;
          tlp_idl = 8'b00001100;
          tlp_soh = 8'b00000000;
          tlp_end = 8'b00000010;
        end

      prev_tlp_eot_1 && raw[2].tkn==PFX_TKN && hdr_3_eot_n :
        begin
          dec_case = ddd_ddd_ddd_ddd_hdr_pfx_end_ddd;
          tlp_pfx = 8'b00000100;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00001000;
          tlp_end = 8'b00000010;
        end

      prev_tlp_eot_1 && raw[2].tkn==PFX_TKN && hdr_3_eot_7 :
        begin
          dec_case = end_ddd_ddd_ddd_hdr_pfx_end_ddd;
          tlp_pfx = 8'b00000100;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00001000;
          tlp_end = 8'b10000010;
        end

      prev_tlp_eot_1 && raw[2].tkn==PFX_TKN && hdr_3_eot_6 && hdr_7_eot_n :
        begin
          dec_case = hdr_end_ddd_ddd_hdr_pfx_end_ddd;
          tlp_pfx = 8'b00000100;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10001000;
          tlp_end = 8'b01000010;
        end

      prev_tlp_eot_1 && raw[2].tkn==PFX_TKN && hdr_3_eot_6 && raw[7].tkn==NOP_TKN :
        begin
          dec_case = nop_end_ddd_ddd_hdr_pfx_end_ddd;
          tlp_pfx = 8'b00000100;
          tlp_idl = 8'b10000000;
          tlp_soh = 8'b00001000;
          tlp_end = 8'b01000010;
        end

      prev_tlp_eot_1 && raw[2].tkn==PFX_TKN && hdr_3_eot_6 && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_end_ddd_ddd_hdr_pfx_end_ddd;
          tlp_pfx = 8'b10000100;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00001000;
          tlp_end = 8'b01000010;
        end

      prev_tlp_eot_1 && raw[2].tkn==PFX_TKN && hdr_3_eot_5 && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_end_ddd_hdr_pfx_end_ddd;
          tlp_pfx = 8'b00000100;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b01001000;
          tlp_end = 8'b00100010;
        end

      prev_tlp_eot_1 && raw[2].tkn==PFX_TKN && hdr_3_eot_5 && raw[6].tkn==NOP_TKN :
        begin
          dec_case = nop_nop_end_ddd_hdr_pfx_end_ddd;
          tlp_pfx = 8'b00000100;
          tlp_idl = 8'b11000000;
          tlp_soh = 8'b00001000;
          tlp_end = 8'b00100010;
        end

      prev_tlp_eot_1 && raw[2].tkn==PFX_TKN && hdr_3_eot_5 && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_end_ddd_hdr_pfx_end_ddd;
          tlp_pfx = 8'b01000100;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10001000;
          tlp_end = 8'b00100010;
        end

      prev_tlp_eot_1 && raw[2].tkn==PFX_TKN && hdr_3_eot_5 && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_end_ddd_hdr_pfx_end_ddd;
          tlp_pfx = 8'b11000100;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00001000;
          tlp_end = 8'b00100010;
        end

      prev_tlp_eot_1 && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && hdr_4_eot_n :
        begin
          dec_case = ddd_ddd_ddd_hdr_pfx_pfx_end_ddd;
          tlp_pfx = 8'b00001100;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b00000010;
        end

      prev_tlp_eot_1 && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && hdr_4_eot_7 :
        begin
          dec_case = end_ddd_ddd_hdr_pfx_pfx_end_ddd;
          tlp_pfx = 8'b00001100;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b10000010;
        end

      prev_tlp_eot_1 && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && hdr_4_eot_6 && hdr_7_eot_n :
        begin
          dec_case = hdr_end_ddd_hdr_pfx_pfx_end_ddd;
          tlp_pfx = 8'b00001100;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10010000;
          tlp_end = 8'b01000010;
        end

      prev_tlp_eot_1 && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && hdr_4_eot_6 && raw[7].tkn==NOP_TKN :
        begin
          dec_case = nop_end_ddd_hdr_pfx_pfx_end_ddd;
          tlp_pfx = 8'b00001100;
          tlp_idl = 8'b10000000;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b01000010;
        end

      prev_tlp_eot_1 && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && hdr_4_eot_6 && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_end_ddd_hdr_pfx_pfx_end_ddd;
          tlp_pfx = 8'b10001100;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b01000010;
        end

      prev_tlp_eot_1 && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && hdr_5_eot_n :
        begin
          dec_case = ddd_ddd_hdr_pfx_pfx_pfx_end_ddd;
          tlp_pfx = 8'b00011100;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100000;
          tlp_end = 8'b00000010;
        end

      prev_tlp_eot_1 && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && hdr_5_eot_7 :
        begin
          dec_case = end_ddd_hdr_pfx_pfx_pfx_end_ddd;
          tlp_pfx = 8'b00011100;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100000;
          tlp_end = 8'b10000010;
        end

      prev_tlp_eot_1 && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_pfx_pfx_pfx_pfx_end_ddd;
          tlp_pfx = 8'b00111100;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b01000000;
          tlp_end = 8'b00000010;
        end

      prev_tlp_eot_1 && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_pfx_pfx_pfx_pfx_end_ddd;
          tlp_pfx = 8'b01111100;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10000000;
          tlp_end = 8'b00000010;
        end

      prev_tlp_eot_1 && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_pfx_pfx_pfx_pfx_end_ddd;
          tlp_pfx = 8'b11111100;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000000;
          tlp_end = 8'b00000010;
        end

      prev_tlp_eot_0 && hdr_1_eot_n :
        begin
          dec_case = ddd_ddd_ddd_ddd_ddd_ddd_hdr_end;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000010;
          tlp_end = 8'b00000001;
        end

      prev_tlp_eot_0 && hdr_1_eot_7 :
        begin
          dec_case = end_ddd_ddd_ddd_ddd_ddd_hdr_end;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000010;
          tlp_end = 8'b10000001;
        end

      prev_tlp_eot_0 && hdr_1_eot_6 && hdr_7_eot_n :
        begin
          dec_case = hdr_end_ddd_ddd_ddd_ddd_hdr_end;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10000010;
          tlp_end = 8'b01000001;
        end

      prev_tlp_eot_0 && hdr_1_eot_6 && raw[7].tkn==NOP_TKN :
        begin
          dec_case = nop_end_ddd_ddd_ddd_ddd_hdr_end;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b10000000;
          tlp_soh = 8'b00000010;
          tlp_end = 8'b01000001;
        end

      prev_tlp_eot_0 && hdr_1_eot_6 && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_end_ddd_ddd_ddd_ddd_hdr_end;
          tlp_pfx = 8'b10000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000010;
          tlp_end = 8'b01000001;
        end

      prev_tlp_eot_0 && hdr_1_eot_5 && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_end_ddd_ddd_ddd_hdr_end;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b01000010;
          tlp_end = 8'b00100001;
        end

      prev_tlp_eot_0 && hdr_1_eot_5 && raw[6].tkn==NOP_TKN :
        begin
          dec_case = nop_nop_end_ddd_ddd_ddd_hdr_end;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b11000000;
          tlp_soh = 8'b00000010;
          tlp_end = 8'b00100001;
        end

      prev_tlp_eot_0 && hdr_1_eot_5 && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_end_ddd_ddd_ddd_hdr_end;
          tlp_pfx = 8'b01000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10000010;
          tlp_end = 8'b00100001;
        end

      prev_tlp_eot_0 && hdr_1_eot_5 && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_end_ddd_ddd_ddd_hdr_end;
          tlp_pfx = 8'b11000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000010;
          tlp_end = 8'b00100001;
        end

      prev_tlp_eot_0 && hdr_1_eot_4 && hdr_5_eot_n :
        begin
          dec_case = ddd_ddd_hdr_end_ddd_ddd_hdr_end;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100010;
          tlp_end = 8'b00010001;
        end

      prev_tlp_eot_0 && hdr_1_eot_4 && hdr_5_eot_7 :
        begin
          dec_case = end_ddd_hdr_end_ddd_ddd_hdr_end;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100010;
          tlp_end = 8'b10010001;
        end

      prev_tlp_eot_0 && hdr_1_eot_4 && raw[5].tkn==NOP_TKN :
        begin
          dec_case = nop_nop_nop_end_ddd_ddd_hdr_end;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b11100000;
          tlp_soh = 8'b00000010;
          tlp_end = 8'b00010001;
        end

      prev_tlp_eot_0 && hdr_1_eot_4 && raw[5].tkn==PFX_TKN && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_pfx_end_ddd_ddd_hdr_end;
          tlp_pfx = 8'b00100000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b01000010;
          tlp_end = 8'b00010001;
        end

      prev_tlp_eot_0 && hdr_1_eot_4 && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_pfx_end_ddd_ddd_hdr_end;
          tlp_pfx = 8'b01100000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10000010;
          tlp_end = 8'b00010001;
        end

      prev_tlp_eot_0 && hdr_1_eot_4 && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_pfx_end_ddd_ddd_hdr_end;
          tlp_pfx = 8'b11100000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000010;
          tlp_end = 8'b00010001;
        end

      prev_tlp_eot_0 && hdr_1_eot_3 && hdr_4_eot_n :
        begin
          dec_case = ddd_ddd_ddd_hdr_end_ddd_hdr_end;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00010010;
          tlp_end = 8'b00001001;
        end

      prev_tlp_eot_0 && hdr_1_eot_3 && hdr_4_eot_7 :
        begin
          dec_case = end_ddd_ddd_hdr_end_ddd_hdr_end;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00010010;
          tlp_end = 8'b10001001;
        end

      prev_tlp_eot_0 && hdr_1_eot_3 && hdr_4_eot_6 && hdr_7_eot_n :
        begin
          dec_case = hdr_end_ddd_hdr_end_ddd_hdr_end;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10010010;
          tlp_end = 8'b01001001;
        end

      prev_tlp_eot_0 && hdr_1_eot_3 && hdr_4_eot_6 && raw[7].tkn==NOP_TKN :
        begin
          dec_case = nop_end_ddd_hdr_end_ddd_hdr_end;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b10000000;
          tlp_soh = 8'b00010010;
          tlp_end = 8'b01001001;
        end

      prev_tlp_eot_0 && hdr_1_eot_3 && hdr_4_eot_6 && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_end_ddd_hdr_end_ddd_hdr_end;
          tlp_pfx = 8'b10000000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00010010;
          tlp_end = 8'b01001001;
        end

      prev_tlp_eot_0 && hdr_1_eot_3 && raw[4].tkn==NOP_TKN :
        begin
          dec_case = nop_nop_nop_nop_end_ddd_hdr_end;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b11110000;
          tlp_soh = 8'b00000010;
          tlp_end = 8'b00001001;
        end

      prev_tlp_eot_0 && hdr_1_eot_3 && raw[4].tkn==PFX_TKN && hdr_5_eot_n :
        begin
          dec_case = ddd_ddd_hdr_pfx_end_ddd_hdr_end;
          tlp_pfx = 8'b00010000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100010;
          tlp_end = 8'b00001001;
        end

      prev_tlp_eot_0 && hdr_1_eot_3 && raw[4].tkn==PFX_TKN && hdr_5_eot_7 :
        begin
          dec_case = end_ddd_hdr_pfx_end_ddd_hdr_end;
          tlp_pfx = 8'b00010000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100010;
          tlp_end = 8'b10001001;
        end

      prev_tlp_eot_0 && hdr_1_eot_3 && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_pfx_pfx_end_ddd_hdr_end;
          tlp_pfx = 8'b00110000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b01000010;
          tlp_end = 8'b00001001;
        end

      prev_tlp_eot_0 && hdr_1_eot_3 && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_pfx_pfx_end_ddd_hdr_end;
          tlp_pfx = 8'b01110000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10000010;
          tlp_end = 8'b00001001;
        end

      prev_tlp_eot_0 && hdr_1_eot_3 && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_pfx_pfx_end_ddd_hdr_end;
          tlp_pfx = 8'b11110000;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000010;
          tlp_end = 8'b00001001;
        end

      prev_tlp_eot_0 && raw[1].tkn==NOP_TKN && hdr_4_eot_n :
        begin
          dec_case = ddd_ddd_ddd_hdr_nop_nop_nop_end;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00001110;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b00000001;
        end

      prev_tlp_eot_0 && raw[1].tkn==NOP_TKN && hdr_4_eot_7 :
        begin
          dec_case = end_ddd_ddd_hdr_nop_nop_nop_end;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00001110;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b10000001;
        end

      prev_tlp_eot_0 && raw[1].tkn==NOP_TKN && hdr_4_eot_6 && hdr_7_eot_n :
        begin
          dec_case = hdr_end_ddd_hdr_nop_nop_nop_end;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00001110;
          tlp_soh = 8'b10010000;
          tlp_end = 8'b01000001;
        end

      prev_tlp_eot_0 && raw[1].tkn==NOP_TKN && hdr_4_eot_6 && raw[7].tkn==NOP_TKN :
        begin
          dec_case = nop_end_ddd_hdr_nop_nop_nop_end;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b10001110;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b01000001;
        end

      prev_tlp_eot_0 && raw[1].tkn==NOP_TKN && hdr_4_eot_6 && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_end_ddd_hdr_nop_nop_nop_end;
          tlp_pfx = 8'b10000000;
          tlp_idl = 8'b00001110;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b01000001;
        end

      prev_tlp_eot_0 && raw[1].tkn==NOP_TKN && raw[4].tkn==NOP_TKN :
        begin
          dec_case = nop_nop_nop_nop_nop_nop_nop_end;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b11111110;
          tlp_soh = 8'b00000000;
          tlp_end = 8'b00000001;
        end

      prev_tlp_eot_0 && raw[1].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && hdr_5_eot_n :
        begin
          dec_case = ddd_ddd_hdr_pfx_nop_nop_nop_end;
          tlp_pfx = 8'b00010000;
          tlp_idl = 8'b00001110;
          tlp_soh = 8'b00100000;
          tlp_end = 8'b00000001;
        end

      prev_tlp_eot_0 && raw[1].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && hdr_5_eot_7 :
        begin
          dec_case = end_ddd_hdr_pfx_nop_nop_nop_end;
          tlp_pfx = 8'b00010000;
          tlp_idl = 8'b00001110;
          tlp_soh = 8'b00100000;
          tlp_end = 8'b10000001;
        end

      prev_tlp_eot_0 && raw[1].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_pfx_pfx_nop_nop_nop_end;
          tlp_pfx = 8'b00110000;
          tlp_idl = 8'b00001110;
          tlp_soh = 8'b01000000;
          tlp_end = 8'b00000001;
        end

      prev_tlp_eot_0 && raw[1].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_pfx_pfx_nop_nop_nop_end;
          tlp_pfx = 8'b01110000;
          tlp_idl = 8'b00001110;
          tlp_soh = 8'b10000000;
          tlp_end = 8'b00000001;
        end

      prev_tlp_eot_0 && raw[1].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_pfx_pfx_nop_nop_nop_end;
          tlp_pfx = 8'b11110000;
          tlp_idl = 8'b00001110;
          tlp_soh = 8'b00000000;
          tlp_end = 8'b00000001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && hdr_2_eot_n :
        begin
          dec_case = ddd_ddd_ddd_ddd_ddd_hdr_pfx_end;
          tlp_pfx = 8'b00000010;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000100;
          tlp_end = 8'b00000001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && hdr_2_eot_7 :
        begin
          dec_case = end_ddd_ddd_ddd_ddd_hdr_pfx_end;
          tlp_pfx = 8'b00000010;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000100;
          tlp_end = 8'b10000001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && hdr_2_eot_6 && hdr_7_eot_n :
        begin
          dec_case = hdr_end_ddd_ddd_ddd_hdr_pfx_end;
          tlp_pfx = 8'b00000010;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10000100;
          tlp_end = 8'b01000001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && hdr_2_eot_6 && raw[7].tkn==NOP_TKN :
        begin
          dec_case = nop_end_ddd_ddd_ddd_hdr_pfx_end;
          tlp_pfx = 8'b00000010;
          tlp_idl = 8'b10000000;
          tlp_soh = 8'b00000100;
          tlp_end = 8'b01000001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && hdr_2_eot_6 && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_end_ddd_ddd_ddd_hdr_pfx_end;
          tlp_pfx = 8'b10000010;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000100;
          tlp_end = 8'b01000001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && hdr_2_eot_5 && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_end_ddd_ddd_hdr_pfx_end;
          tlp_pfx = 8'b00000010;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b01000100;
          tlp_end = 8'b00100001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && hdr_2_eot_5 && raw[6].tkn==NOP_TKN :
        begin
          dec_case = nop_nop_end_ddd_ddd_hdr_pfx_end;
          tlp_pfx = 8'b00000010;
          tlp_idl = 8'b11000000;
          tlp_soh = 8'b00000100;
          tlp_end = 8'b00100001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && hdr_2_eot_5 && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_end_ddd_ddd_hdr_pfx_end;
          tlp_pfx = 8'b01000010;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10000100;
          tlp_end = 8'b00100001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && hdr_2_eot_5 && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_end_ddd_ddd_hdr_pfx_end;
          tlp_pfx = 8'b11000010;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000100;
          tlp_end = 8'b00100001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && hdr_2_eot_4 && hdr_5_eot_n :
        begin
          dec_case = ddd_ddd_hdr_end_ddd_hdr_pfx_end;
          tlp_pfx = 8'b00000010;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100100;
          tlp_end = 8'b00010001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && hdr_2_eot_4 && hdr_5_eot_7 :
        begin
          dec_case = end_ddd_hdr_end_ddd_hdr_pfx_end;
          tlp_pfx = 8'b00000010;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100100;
          tlp_end = 8'b10010001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && hdr_2_eot_4 && raw[5].tkn==NOP_TKN :
        begin
          dec_case = nop_nop_nop_end_ddd_hdr_pfx_end;
          tlp_pfx = 8'b00000010;
          tlp_idl = 8'b11100000;
          tlp_soh = 8'b00000100;
          tlp_end = 8'b00010001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && hdr_2_eot_4 && raw[5].tkn==PFX_TKN && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_pfx_end_ddd_hdr_pfx_end;
          tlp_pfx = 8'b00100010;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b01000100;
          tlp_end = 8'b00010001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && hdr_2_eot_4 && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_pfx_end_ddd_hdr_pfx_end;
          tlp_pfx = 8'b01100010;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10000100;
          tlp_end = 8'b00010001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && hdr_2_eot_4 && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_pfx_end_ddd_hdr_pfx_end;
          tlp_pfx = 8'b11100010;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000100;
          tlp_end = 8'b00010001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && hdr_3_eot_n :
        begin
          dec_case = ddd_ddd_ddd_ddd_hdr_pfx_pfx_end;
          tlp_pfx = 8'b00000110;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00001000;
          tlp_end = 8'b00000001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && hdr_3_eot_7 :
        begin
          dec_case = end_ddd_ddd_ddd_hdr_pfx_pfx_end;
          tlp_pfx = 8'b00000110;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00001000;
          tlp_end = 8'b10000001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && hdr_3_eot_6 && hdr_7_eot_n :
        begin
          dec_case = hdr_end_ddd_ddd_hdr_pfx_pfx_end;
          tlp_pfx = 8'b00000110;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10001000;
          tlp_end = 8'b01000001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && hdr_3_eot_6 && raw[7].tkn==NOP_TKN :
        begin
          dec_case = nop_end_ddd_ddd_hdr_pfx_pfx_end;
          tlp_pfx = 8'b00000110;
          tlp_idl = 8'b10000000;
          tlp_soh = 8'b00001000;
          tlp_end = 8'b01000001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && hdr_3_eot_6 && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_end_ddd_ddd_hdr_pfx_pfx_end;
          tlp_pfx = 8'b10000110;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00001000;
          tlp_end = 8'b01000001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && hdr_3_eot_5 && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_end_ddd_hdr_pfx_pfx_end;
          tlp_pfx = 8'b00000110;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b01001000;
          tlp_end = 8'b00100001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && hdr_3_eot_5 && raw[6].tkn==NOP_TKN :
        begin
          dec_case = nop_nop_end_ddd_hdr_pfx_pfx_end;
          tlp_pfx = 8'b00000110;
          tlp_idl = 8'b11000000;
          tlp_soh = 8'b00001000;
          tlp_end = 8'b00100001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && hdr_3_eot_5 && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_end_ddd_hdr_pfx_pfx_end;
          tlp_pfx = 8'b01000110;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10001000;
          tlp_end = 8'b00100001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && hdr_3_eot_5 && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_end_ddd_hdr_pfx_pfx_end;
          tlp_pfx = 8'b11000110;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00001000;
          tlp_end = 8'b00100001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && hdr_4_eot_n :
        begin
          dec_case = ddd_ddd_ddd_hdr_pfx_pfx_pfx_end;
          tlp_pfx = 8'b00001110;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b00000001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && hdr_4_eot_7 :
        begin
          dec_case = end_ddd_ddd_hdr_pfx_pfx_pfx_end;
          tlp_pfx = 8'b00001110;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b10000001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && hdr_4_eot_6 && hdr_7_eot_n :
        begin
          dec_case = hdr_end_ddd_hdr_pfx_pfx_pfx_end;
          tlp_pfx = 8'b00001110;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10010000;
          tlp_end = 8'b01000001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && hdr_4_eot_6 && raw[7].tkn==NOP_TKN :
        begin
          dec_case = nop_end_ddd_hdr_pfx_pfx_pfx_end;
          tlp_pfx = 8'b00001110;
          tlp_idl = 8'b10000000;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b01000001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && hdr_4_eot_6 && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_end_ddd_hdr_pfx_pfx_pfx_end;
          tlp_pfx = 8'b10001110;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b01000001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && hdr_5_eot_n :
        begin
          dec_case = ddd_ddd_hdr_pfx_pfx_pfx_pfx_end;
          tlp_pfx = 8'b00011110;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100000;
          tlp_end = 8'b00000001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && hdr_5_eot_7 :
        begin
          dec_case = end_ddd_hdr_pfx_pfx_pfx_pfx_end;
          tlp_pfx = 8'b00011110;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100000;
          tlp_end = 8'b10000001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_pfx_pfx_pfx_pfx_pfx_end;
          tlp_pfx = 8'b00111110;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b01000000;
          tlp_end = 8'b00000001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_pfx_pfx_pfx_pfx_pfx_end;
          tlp_pfx = 8'b01111110;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10000000;
          tlp_end = 8'b00000001;
        end

      prev_tlp_eot_0 && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_pfx_pfx_pfx_pfx_pfx_end;
          tlp_pfx = 8'b11111110;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000000;
          tlp_end = 8'b00000001;
        end

      prev_tlp_none && raw[0].tkn==NOP_TKN && hdr_4_eot_n :
        begin
          dec_case = ddd_ddd_ddd_hdr_nop_nop_nop_nop;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00001111;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b00000000;
        end

      prev_tlp_none && raw[0].tkn==NOP_TKN && hdr_4_eot_7 :
        begin
          dec_case = end_ddd_ddd_hdr_nop_nop_nop_nop;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00001111;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b10000000;
        end

      prev_tlp_none && raw[0].tkn==NOP_TKN && hdr_4_eot_6 && hdr_7_eot_n :
        begin
          dec_case = hdr_end_ddd_hdr_nop_nop_nop_nop;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b00001111;
          tlp_soh = 8'b10010000;
          tlp_end = 8'b01000000;
        end

      prev_tlp_none && raw[0].tkn==NOP_TKN && hdr_4_eot_6 && raw[7].tkn==NOP_TKN :
        begin
          dec_case = nop_end_ddd_hdr_nop_nop_nop_nop;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b10001111;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b01000000;
        end

      prev_tlp_none && raw[0].tkn==NOP_TKN && hdr_4_eot_6 && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_end_ddd_hdr_nop_nop_nop_nop;
          tlp_pfx = 8'b10000000;
          tlp_idl = 8'b00001111;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b01000000;
        end

      prev_tlp_none && raw[0].tkn==NOP_TKN && raw[4].tkn==NOP_TKN :
        begin
          dec_case = nop_nop_nop_nop_nop_nop_nop_nop;
          tlp_pfx = 8'b00000000;
          tlp_idl = 8'b11111111;
          tlp_soh = 8'b00000000;
          tlp_end = 8'b00000000;
        end

      prev_tlp_none && raw[0].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && hdr_5_eot_n :
        begin
          dec_case = ddd_ddd_hdr_pfx_nop_nop_nop_nop;
          tlp_pfx = 8'b00010000;
          tlp_idl = 8'b00001111;
          tlp_soh = 8'b00100000;
          tlp_end = 8'b00000000;
        end

      prev_tlp_none && raw[0].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && hdr_5_eot_7 :
        begin
          dec_case = end_ddd_hdr_pfx_nop_nop_nop_nop;
          tlp_pfx = 8'b00010000;
          tlp_idl = 8'b00001111;
          tlp_soh = 8'b00100000;
          tlp_end = 8'b10000000;
        end

      prev_tlp_none && raw[0].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_pfx_pfx_nop_nop_nop_nop;
          tlp_pfx = 8'b00110000;
          tlp_idl = 8'b00001111;
          tlp_soh = 8'b01000000;
          tlp_end = 8'b00000000;
        end

      prev_tlp_none && raw[0].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_pfx_pfx_nop_nop_nop_nop;
          tlp_pfx = 8'b01110000;
          tlp_idl = 8'b00001111;
          tlp_soh = 8'b10000000;
          tlp_end = 8'b00000000;
        end

      prev_tlp_none && raw[0].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_pfx_pfx_nop_nop_nop_nop;
          tlp_pfx = 8'b11110000;
          tlp_idl = 8'b00001111;
          tlp_soh = 8'b00000000;
          tlp_end = 8'b00000000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && hdr_1_eot_n :
        begin
          dec_case = ddd_ddd_ddd_ddd_ddd_ddd_hdr_pfx;
          tlp_pfx = 8'b00000001;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000010;
          tlp_end = 8'b00000000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && hdr_1_eot_7 :
        begin
          dec_case = end_ddd_ddd_ddd_ddd_ddd_hdr_pfx;
          tlp_pfx = 8'b00000001;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000010;
          tlp_end = 8'b10000000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && hdr_1_eot_6 && hdr_7_eot_n :
        begin
          dec_case = hdr_end_ddd_ddd_ddd_ddd_hdr_pfx;
          tlp_pfx = 8'b00000001;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10000010;
          tlp_end = 8'b01000000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && hdr_1_eot_6 && raw[7].tkn==NOP_TKN :
        begin
          dec_case = nop_end_ddd_ddd_ddd_ddd_hdr_pfx;
          tlp_pfx = 8'b00000001;
          tlp_idl = 8'b10000000;
          tlp_soh = 8'b00000010;
          tlp_end = 8'b01000000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && hdr_1_eot_6 && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_end_ddd_ddd_ddd_ddd_hdr_pfx;
          tlp_pfx = 8'b10000001;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000010;
          tlp_end = 8'b01000000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && hdr_1_eot_5 && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_end_ddd_ddd_ddd_hdr_pfx;
          tlp_pfx = 8'b00000001;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b01000010;
          tlp_end = 8'b00100000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && hdr_1_eot_5 && raw[6].tkn==NOP_TKN :
        begin
          dec_case = nop_nop_end_ddd_ddd_ddd_hdr_pfx;
          tlp_pfx = 8'b00000001;
          tlp_idl = 8'b11000000;
          tlp_soh = 8'b00000010;
          tlp_end = 8'b00100000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && hdr_1_eot_5 && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_end_ddd_ddd_ddd_hdr_pfx;
          tlp_pfx = 8'b01000001;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10000010;
          tlp_end = 8'b00100000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && hdr_1_eot_5 && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_end_ddd_ddd_ddd_hdr_pfx;
          tlp_pfx = 8'b11000001;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000010;
          tlp_end = 8'b00100000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && hdr_1_eot_4 && hdr_5_eot_n :
        begin
          dec_case = ddd_ddd_hdr_end_ddd_ddd_hdr_pfx;
          tlp_pfx = 8'b00000001;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100010;
          tlp_end = 8'b00010000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && hdr_1_eot_4 && hdr_5_eot_7 :
        begin
          dec_case = end_ddd_hdr_end_ddd_ddd_hdr_pfx;
          tlp_pfx = 8'b00000001;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100010;
          tlp_end = 8'b10010000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && hdr_1_eot_4 && raw[5].tkn==NOP_TKN :
        begin
          dec_case = nop_nop_nop_end_ddd_ddd_hdr_pfx;
          tlp_pfx = 8'b00000001;
          tlp_idl = 8'b11100000;
          tlp_soh = 8'b00000010;
          tlp_end = 8'b00010000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && hdr_1_eot_4 && raw[5].tkn==PFX_TKN && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_pfx_end_ddd_ddd_hdr_pfx;
          tlp_pfx = 8'b00100001;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b01000010;
          tlp_end = 8'b00010000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && hdr_1_eot_4 && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_pfx_end_ddd_ddd_hdr_pfx;
          tlp_pfx = 8'b01100001;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10000010;
          tlp_end = 8'b00010000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && hdr_1_eot_4 && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_pfx_end_ddd_ddd_hdr_pfx;
          tlp_pfx = 8'b11100001;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000010;
          tlp_end = 8'b00010000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && hdr_1_eot_3 && hdr_4_eot_n :
        begin
          dec_case = ddd_ddd_ddd_hdr_end_ddd_hdr_pfx;
          tlp_pfx = 8'b00000001;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00010010;
          tlp_end = 8'b00001000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && hdr_1_eot_3 && hdr_4_eot_7 :
        begin
          dec_case = end_ddd_ddd_hdr_end_ddd_hdr_pfx;
          tlp_pfx = 8'b00000001;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00010010;
          tlp_end = 8'b10001000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && hdr_1_eot_3 && hdr_4_eot_6 && hdr_7_eot_n :
        begin
          dec_case = hdr_end_ddd_hdr_end_ddd_hdr_pfx;
          tlp_pfx = 8'b00000001;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10010010;
          tlp_end = 8'b01001000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && hdr_1_eot_3 && hdr_4_eot_6 && raw[7].tkn==NOP_TKN :
        begin
          dec_case = nop_end_ddd_hdr_end_ddd_hdr_pfx;
          tlp_pfx = 8'b00000001;
          tlp_idl = 8'b10000000;
          tlp_soh = 8'b00010010;
          tlp_end = 8'b01001000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && hdr_1_eot_3 && hdr_4_eot_6 && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_end_ddd_hdr_end_ddd_hdr_pfx;
          tlp_pfx = 8'b10000001;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00010010;
          tlp_end = 8'b01001000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && hdr_1_eot_3 && raw[4].tkn==NOP_TKN :
        begin
          dec_case = nop_nop_nop_nop_end_ddd_hdr_pfx;
          tlp_pfx = 8'b00000001;
          tlp_idl = 8'b11110000;
          tlp_soh = 8'b00000010;
          tlp_end = 8'b00001000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && hdr_1_eot_3 && raw[4].tkn==PFX_TKN && hdr_5_eot_n :
        begin
          dec_case = ddd_ddd_hdr_pfx_end_ddd_hdr_pfx;
          tlp_pfx = 8'b00010001;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100010;
          tlp_end = 8'b00001000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && hdr_1_eot_3 && raw[4].tkn==PFX_TKN && hdr_5_eot_7 :
        begin
          dec_case = end_ddd_hdr_pfx_end_ddd_hdr_pfx;
          tlp_pfx = 8'b00010001;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100010;
          tlp_end = 8'b10001000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && hdr_1_eot_3 && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_pfx_pfx_end_ddd_hdr_pfx;
          tlp_pfx = 8'b00110001;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b01000010;
          tlp_end = 8'b00001000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && hdr_1_eot_3 && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_pfx_pfx_end_ddd_hdr_pfx;
          tlp_pfx = 8'b01110001;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10000010;
          tlp_end = 8'b00001000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && hdr_1_eot_3 && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_pfx_pfx_end_ddd_hdr_pfx;
          tlp_pfx = 8'b11110001;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000010;
          tlp_end = 8'b00001000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && hdr_2_eot_n :
        begin
          dec_case = ddd_ddd_ddd_ddd_ddd_hdr_pfx_pfx;
          tlp_pfx = 8'b00000011;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000100;
          tlp_end = 8'b00000000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && hdr_2_eot_7 :
        begin
          dec_case = end_ddd_ddd_ddd_ddd_hdr_pfx_pfx;
          tlp_pfx = 8'b00000011;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000100;
          tlp_end = 8'b10000000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && hdr_2_eot_6 && hdr_7_eot_n :
        begin
          dec_case = hdr_end_ddd_ddd_ddd_hdr_pfx_pfx;
          tlp_pfx = 8'b00000011;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10000100;
          tlp_end = 8'b01000000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && hdr_2_eot_6 && raw[7].tkn==NOP_TKN :
        begin
          dec_case = nop_end_ddd_ddd_ddd_hdr_pfx_pfx;
          tlp_pfx = 8'b00000011;
          tlp_idl = 8'b10000000;
          tlp_soh = 8'b00000100;
          tlp_end = 8'b01000000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && hdr_2_eot_6 && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_end_ddd_ddd_ddd_hdr_pfx_pfx;
          tlp_pfx = 8'b10000011;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000100;
          tlp_end = 8'b01000000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && hdr_2_eot_5 && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_end_ddd_ddd_hdr_pfx_pfx;
          tlp_pfx = 8'b00000011;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b01000100;
          tlp_end = 8'b00100000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && hdr_2_eot_5 && raw[6].tkn==NOP_TKN :
        begin
          dec_case = nop_nop_end_ddd_ddd_hdr_pfx_pfx;
          tlp_pfx = 8'b00000011;
          tlp_idl = 8'b11000000;
          tlp_soh = 8'b00000100;
          tlp_end = 8'b00100000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && hdr_2_eot_5 && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_end_ddd_ddd_hdr_pfx_pfx;
          tlp_pfx = 8'b01000011;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10000100;
          tlp_end = 8'b00100000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && hdr_2_eot_5 && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_end_ddd_ddd_hdr_pfx_pfx;
          tlp_pfx = 8'b11000011;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000100;
          tlp_end = 8'b00100000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && hdr_2_eot_4 && hdr_5_eot_n :
        begin
          dec_case = ddd_ddd_hdr_end_ddd_hdr_pfx_pfx;
          tlp_pfx = 8'b00000011;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100100;
          tlp_end = 8'b00010000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && hdr_2_eot_4 && hdr_5_eot_7 :
        begin
          dec_case = end_ddd_hdr_end_ddd_hdr_pfx_pfx;
          tlp_pfx = 8'b00000011;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100100;
          tlp_end = 8'b10010000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && hdr_2_eot_4 && raw[5].tkn==NOP_TKN :
        begin
          dec_case = nop_nop_nop_end_ddd_hdr_pfx_pfx;
          tlp_pfx = 8'b00000011;
          tlp_idl = 8'b11100000;
          tlp_soh = 8'b00000100;
          tlp_end = 8'b00010000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && hdr_2_eot_4 && raw[5].tkn==PFX_TKN && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_pfx_end_ddd_hdr_pfx_pfx;
          tlp_pfx = 8'b00100011;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b01000100;
          tlp_end = 8'b00010000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && hdr_2_eot_4 && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_pfx_end_ddd_hdr_pfx_pfx;
          tlp_pfx = 8'b01100011;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10000100;
          tlp_end = 8'b00010000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && hdr_2_eot_4 && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_pfx_end_ddd_hdr_pfx_pfx;
          tlp_pfx = 8'b11100011;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000100;
          tlp_end = 8'b00010000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && hdr_3_eot_n :
        begin
          dec_case = ddd_ddd_ddd_ddd_hdr_pfx_pfx_pfx;
          tlp_pfx = 8'b00000111;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00001000;
          tlp_end = 8'b00000000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && hdr_3_eot_7 :
        begin
          dec_case = end_ddd_ddd_ddd_hdr_pfx_pfx_pfx;
          tlp_pfx = 8'b00000111;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00001000;
          tlp_end = 8'b10000000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && hdr_3_eot_6 && hdr_7_eot_n :
        begin
          dec_case = hdr_end_ddd_ddd_hdr_pfx_pfx_pfx;
          tlp_pfx = 8'b00000111;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10001000;
          tlp_end = 8'b01000000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && hdr_3_eot_6 && raw[7].tkn==NOP_TKN :
        begin
          dec_case = nop_end_ddd_ddd_hdr_pfx_pfx_pfx;
          tlp_pfx = 8'b00000111;
          tlp_idl = 8'b10000000;
          tlp_soh = 8'b00001000;
          tlp_end = 8'b01000000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && hdr_3_eot_6 && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_end_ddd_ddd_hdr_pfx_pfx_pfx;
          tlp_pfx = 8'b10000111;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00001000;
          tlp_end = 8'b01000000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && hdr_3_eot_5 && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_end_ddd_hdr_pfx_pfx_pfx;
          tlp_pfx = 8'b00000111;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b01001000;
          tlp_end = 8'b00100000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && hdr_3_eot_5 && raw[6].tkn==NOP_TKN :
        begin
          dec_case = nop_nop_end_ddd_hdr_pfx_pfx_pfx;
          tlp_pfx = 8'b00000111;
          tlp_idl = 8'b11000000;
          tlp_soh = 8'b00001000;
          tlp_end = 8'b00100000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && hdr_3_eot_5 && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_end_ddd_hdr_pfx_pfx_pfx;
          tlp_pfx = 8'b01000111;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10001000;
          tlp_end = 8'b00100000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && hdr_3_eot_5 && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_end_ddd_hdr_pfx_pfx_pfx;
          tlp_pfx = 8'b11000111;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00001000;
          tlp_end = 8'b00100000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && hdr_4_eot_n :
        begin
          dec_case = ddd_ddd_ddd_hdr_pfx_pfx_pfx_pfx;
          tlp_pfx = 8'b00001111;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b00000000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && hdr_4_eot_7 :
        begin
          dec_case = end_ddd_ddd_hdr_pfx_pfx_pfx_pfx;
          tlp_pfx = 8'b00001111;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b10000000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && hdr_4_eot_6 && hdr_7_eot_n :
        begin
          dec_case = hdr_end_ddd_hdr_pfx_pfx_pfx_pfx;
          tlp_pfx = 8'b00001111;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10010000;
          tlp_end = 8'b01000000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && hdr_4_eot_6 && raw[7].tkn==NOP_TKN :
        begin
          dec_case = nop_end_ddd_hdr_pfx_pfx_pfx_pfx;
          tlp_pfx = 8'b00001111;
          tlp_idl = 8'b10000000;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b01000000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && hdr_4_eot_6 && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_end_ddd_hdr_pfx_pfx_pfx_pfx;
          tlp_pfx = 8'b10001111;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00010000;
          tlp_end = 8'b01000000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && hdr_5_eot_n :
        begin
          dec_case = ddd_ddd_hdr_pfx_pfx_pfx_pfx_pfx;
          tlp_pfx = 8'b00011111;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100000;
          tlp_end = 8'b00000000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && hdr_5_eot_7 :
        begin
          dec_case = end_ddd_hdr_pfx_pfx_pfx_pfx_pfx;
          tlp_pfx = 8'b00011111;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00100000;
          tlp_end = 8'b10000000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && hdr_6_eot_n :
        begin
          dec_case = ddd_hdr_pfx_pfx_pfx_pfx_pfx_pfx;
          tlp_pfx = 8'b00111111;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b01000000;
          tlp_end = 8'b00000000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n :
        begin
          dec_case = hdr_pfx_pfx_pfx_pfx_pfx_pfx_pfx;
          tlp_pfx = 8'b01111111;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b10000000;
          tlp_end = 8'b00000000;
        end

      prev_tlp_none && raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && raw[7].tkn==PFX_TKN :
        begin
          dec_case = pfx_pfx_pfx_pfx_pfx_pfx_pfx_pfx;
          tlp_pfx = 8'b11111111;
          tlp_idl = 8'b00000000;
          tlp_soh = 8'b00000000;
          tlp_end = 8'b00000000;
        end

      default :
        begin
          dec_case = xxx_xxx_xxx_xxx_xxx_xxx_xxx_xxx;
          tlp_end = 8'b11111111;
        end
    endcase
end // tlp_out_PROC


always_comb begin : raw_next_tlp_state_0_PROC
    raw_next_tlp_state[0] = '0;
    raw_next_tlp_state_valid[0] = 1'b1;
    unique case ( 1'b1 )
      /* ddd_ddd_ddd_ddd_ddd_ddd_ddd_hdr */ hdr_0_eot_n:
         raw_next_tlp_state[0] = get_next_tlp_state(raw[0]);

      /* ddd_ddd_ddd_ddd_ddd_ddd_hdr_pfx */ raw[0].tkn==PFX_TKN && hdr_1_eot_n:
         raw_next_tlp_state[0] = get_next_tlp_state(raw[1]);

      /* ddd_ddd_ddd_ddd_ddd_hdr_pfx_pfx */ raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && hdr_2_eot_n:
         raw_next_tlp_state[0] = get_next_tlp_state(raw[2]);

      /* ddd_ddd_ddd_ddd_hdr_end_ddd_hdr */ hdr_0_eot_2 && hdr_3_eot_n,
      /* ddd_ddd_ddd_ddd_hdr_pfx_pfx_pfx */ raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && hdr_3_eot_n:
         raw_next_tlp_state[0] = get_next_tlp_state(raw[3]);

      /* ddd_ddd_ddd_hdr_end_ddd_ddd_hdr */ hdr_0_eot_3 && hdr_4_eot_n,
      /* ddd_ddd_ddd_hdr_nop_end_ddd_hdr */ hdr_0_eot_2 && raw[3].tkn==NOP_TKN && hdr_4_eot_n,
      /* ddd_ddd_ddd_hdr_pfx_end_ddd_hdr */ hdr_0_eot_2 && raw[3].tkn==PFX_TKN && hdr_4_eot_n,
      /* ddd_ddd_ddd_hdr_nop_nop_nop_nop */ raw[0].tkn==NOP_TKN && hdr_4_eot_n,
      /* ddd_ddd_ddd_hdr_end_ddd_hdr_pfx */ raw[0].tkn==PFX_TKN && hdr_1_eot_3 && hdr_4_eot_n,
      /* ddd_ddd_ddd_hdr_pfx_pfx_pfx_pfx */ raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && hdr_4_eot_n:
         raw_next_tlp_state[0] = get_next_tlp_state(raw[4]);

      /* ddd_ddd_hdr_end_ddd_ddd_ddd_hdr */ hdr_0_eot_4 && hdr_5_eot_n,
      /* ddd_ddd_hdr_pfx_end_ddd_ddd_hdr */ hdr_0_eot_3 && raw[4].tkn==PFX_TKN && hdr_5_eot_n,
      /* ddd_ddd_hdr_pfx_nop_end_ddd_hdr */ hdr_0_eot_2 && raw[3].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && hdr_5_eot_n,
      /* ddd_ddd_hdr_pfx_pfx_end_ddd_hdr */ hdr_0_eot_2 && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && hdr_5_eot_n,
      /* ddd_ddd_hdr_pfx_nop_nop_nop_nop */ raw[0].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && hdr_5_eot_n,
      /* ddd_ddd_hdr_end_ddd_ddd_hdr_pfx */ raw[0].tkn==PFX_TKN && hdr_1_eot_4 && hdr_5_eot_n,
      /* ddd_ddd_hdr_pfx_end_ddd_hdr_pfx */ raw[0].tkn==PFX_TKN && hdr_1_eot_3 && raw[4].tkn==PFX_TKN && hdr_5_eot_n,
      /* ddd_ddd_hdr_end_ddd_hdr_pfx_pfx */ raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && hdr_2_eot_4 && hdr_5_eot_n,
      /* ddd_ddd_hdr_pfx_pfx_pfx_pfx_pfx */ raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && hdr_5_eot_n:
         raw_next_tlp_state[0] = get_next_tlp_state(raw[5]);

      /* ddd_hdr_end_ddd_ddd_ddd_ddd_hdr */ hdr_0_eot_5 && hdr_6_eot_n,
      /* ddd_hdr_pfx_end_ddd_ddd_ddd_hdr */ hdr_0_eot_4 && raw[5].tkn==PFX_TKN && hdr_6_eot_n,
      /* ddd_hdr_pfx_pfx_end_ddd_ddd_hdr */ hdr_0_eot_3 && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && hdr_6_eot_n,
      /* ddd_hdr_end_ddd_hdr_end_ddd_hdr */ hdr_0_eot_2 && hdr_3_eot_5 && hdr_6_eot_n,
      /* ddd_hdr_pfx_pfx_nop_end_ddd_hdr */ hdr_0_eot_2 && raw[3].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && hdr_6_eot_n,
      /* ddd_hdr_pfx_pfx_pfx_end_ddd_hdr */ hdr_0_eot_2 && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && hdr_6_eot_n,
      /* ddd_hdr_pfx_pfx_nop_nop_nop_nop */ raw[0].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && hdr_6_eot_n,
      /* ddd_hdr_end_ddd_ddd_ddd_hdr_pfx */ raw[0].tkn==PFX_TKN && hdr_1_eot_5 && hdr_6_eot_n,
      /* ddd_hdr_pfx_end_ddd_ddd_hdr_pfx */ raw[0].tkn==PFX_TKN && hdr_1_eot_4 && raw[5].tkn==PFX_TKN && hdr_6_eot_n,
      /* ddd_hdr_pfx_pfx_end_ddd_hdr_pfx */ raw[0].tkn==PFX_TKN && hdr_1_eot_3 && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && hdr_6_eot_n,
      /* ddd_hdr_end_ddd_ddd_hdr_pfx_pfx */ raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && hdr_2_eot_5 && hdr_6_eot_n,
      /* ddd_hdr_pfx_end_ddd_hdr_pfx_pfx */ raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && hdr_2_eot_4 && raw[5].tkn==PFX_TKN && hdr_6_eot_n,
      /* ddd_hdr_end_ddd_hdr_pfx_pfx_pfx */ raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && hdr_3_eot_5 && hdr_6_eot_n,
      /* ddd_hdr_pfx_pfx_pfx_pfx_pfx_pfx */ raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && hdr_6_eot_n:
         raw_next_tlp_state[0] = get_next_tlp_state(raw[6]);

      /* hdr_end_ddd_ddd_ddd_ddd_ddd_hdr */ hdr_0_eot_6 && hdr_7_eot_n,
      /* hdr_pfx_end_ddd_ddd_ddd_ddd_hdr */ hdr_0_eot_5 && raw[6].tkn==PFX_TKN && hdr_7_eot_n,
      /* hdr_pfx_pfx_end_ddd_ddd_ddd_hdr */ hdr_0_eot_4 && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n,
      /* hdr_end_ddd_hdr_end_ddd_ddd_hdr */ hdr_0_eot_3 && hdr_4_eot_6 && hdr_7_eot_n,
      /* hdr_pfx_pfx_pfx_end_ddd_ddd_hdr */ hdr_0_eot_3 && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n,
      /* hdr_end_ddd_ddd_hdr_end_ddd_hdr */ hdr_0_eot_2 && hdr_3_eot_6 && hdr_7_eot_n,
      /* hdr_pfx_end_ddd_hdr_end_ddd_hdr */ hdr_0_eot_2 && hdr_3_eot_5 && raw[6].tkn==PFX_TKN && hdr_7_eot_n,
      /* hdr_end_ddd_hdr_nop_end_ddd_hdr */ hdr_0_eot_2 && raw[3].tkn==NOP_TKN && hdr_4_eot_6 && hdr_7_eot_n,
      /* hdr_pfx_pfx_pfx_nop_end_ddd_hdr */ hdr_0_eot_2 && raw[3].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n,
      /* hdr_end_ddd_hdr_pfx_end_ddd_hdr */ hdr_0_eot_2 && raw[3].tkn==PFX_TKN && hdr_4_eot_6 && hdr_7_eot_n,
      /* hdr_pfx_pfx_pfx_pfx_end_ddd_hdr */ hdr_0_eot_2 && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n,
      /* hdr_end_ddd_hdr_nop_nop_nop_nop */ raw[0].tkn==NOP_TKN && hdr_4_eot_6 && hdr_7_eot_n,
      /* hdr_pfx_pfx_pfx_nop_nop_nop_nop */ raw[0].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n,
      /* hdr_end_ddd_ddd_ddd_ddd_hdr_pfx */ raw[0].tkn==PFX_TKN && hdr_1_eot_6 && hdr_7_eot_n,
      /* hdr_pfx_end_ddd_ddd_ddd_hdr_pfx */ raw[0].tkn==PFX_TKN && hdr_1_eot_5 && raw[6].tkn==PFX_TKN && hdr_7_eot_n,
      /* hdr_pfx_pfx_end_ddd_ddd_hdr_pfx */ raw[0].tkn==PFX_TKN && hdr_1_eot_4 && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n,
      /* hdr_end_ddd_hdr_end_ddd_hdr_pfx */ raw[0].tkn==PFX_TKN && hdr_1_eot_3 && hdr_4_eot_6 && hdr_7_eot_n,
      /* hdr_pfx_pfx_pfx_end_ddd_hdr_pfx */ raw[0].tkn==PFX_TKN && hdr_1_eot_3 && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n,
      /* hdr_end_ddd_ddd_ddd_hdr_pfx_pfx */ raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && hdr_2_eot_6 && hdr_7_eot_n,
      /* hdr_pfx_end_ddd_ddd_hdr_pfx_pfx */ raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && hdr_2_eot_5 && raw[6].tkn==PFX_TKN && hdr_7_eot_n,
      /* hdr_pfx_pfx_end_ddd_hdr_pfx_pfx */ raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && hdr_2_eot_4 && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n,
      /* hdr_end_ddd_ddd_hdr_pfx_pfx_pfx */ raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && hdr_3_eot_6 && hdr_7_eot_n,
      /* hdr_pfx_end_ddd_hdr_pfx_pfx_pfx */ raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && hdr_3_eot_5 && raw[6].tkn==PFX_TKN && hdr_7_eot_n,
      /* hdr_end_ddd_hdr_pfx_pfx_pfx_pfx */ raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && hdr_4_eot_6 && hdr_7_eot_n,
      /* hdr_pfx_pfx_pfx_pfx_pfx_pfx_pfx */ raw[0].tkn==PFX_TKN && raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n:
         raw_next_tlp_state[0] = get_next_tlp_state(raw[7]);

      default :
         raw_next_tlp_state_valid[0] = 1'b0;
    endcase
end // raw_next_tlp_state_0_PROC

always_comb begin : raw_next_tlp_state_1_PROC
    raw_next_tlp_state[1] = '0;
    raw_next_tlp_state_valid[1] = 1'b1;
    unique case ( 1'b1 )
      /* ddd_ddd_ddd_ddd_ddd_ddd_hdr_end */ hdr_1_eot_n:
         raw_next_tlp_state[1] = get_next_tlp_state(raw[1]);

      /* ddd_ddd_ddd_ddd_ddd_hdr_pfx_end */ raw[1].tkn==PFX_TKN && hdr_2_eot_n:
         raw_next_tlp_state[1] = get_next_tlp_state(raw[2]);

      /* ddd_ddd_ddd_ddd_hdr_pfx_pfx_end */ raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && hdr_3_eot_n:
         raw_next_tlp_state[1] = get_next_tlp_state(raw[3]);

      /* ddd_ddd_ddd_hdr_end_ddd_hdr_end */ hdr_1_eot_3 && hdr_4_eot_n,
      /* ddd_ddd_ddd_hdr_nop_nop_nop_end */ raw[1].tkn==NOP_TKN && hdr_4_eot_n,
      /* ddd_ddd_ddd_hdr_pfx_pfx_pfx_end */ raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && hdr_4_eot_n:
         raw_next_tlp_state[1] = get_next_tlp_state(raw[4]);

      /* ddd_ddd_hdr_end_ddd_ddd_hdr_end */ hdr_1_eot_4 && hdr_5_eot_n,
      /* ddd_ddd_hdr_pfx_end_ddd_hdr_end */ hdr_1_eot_3 && raw[4].tkn==PFX_TKN && hdr_5_eot_n,
      /* ddd_ddd_hdr_pfx_nop_nop_nop_end */ raw[1].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && hdr_5_eot_n,
      /* ddd_ddd_hdr_end_ddd_hdr_pfx_end */ raw[1].tkn==PFX_TKN && hdr_2_eot_4 && hdr_5_eot_n,
      /* ddd_ddd_hdr_pfx_pfx_pfx_pfx_end */ raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && hdr_5_eot_n:
         raw_next_tlp_state[1] = get_next_tlp_state(raw[5]);

      /* ddd_hdr_end_ddd_ddd_ddd_hdr_end */ hdr_1_eot_5 && hdr_6_eot_n,
      /* ddd_hdr_pfx_end_ddd_ddd_hdr_end */ hdr_1_eot_4 && raw[5].tkn==PFX_TKN && hdr_6_eot_n,
      /* ddd_hdr_pfx_pfx_end_ddd_hdr_end */ hdr_1_eot_3 && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && hdr_6_eot_n,
      /* ddd_hdr_pfx_pfx_nop_nop_nop_end */ raw[1].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && hdr_6_eot_n,
      /* ddd_hdr_end_ddd_ddd_hdr_pfx_end */ raw[1].tkn==PFX_TKN && hdr_2_eot_5 && hdr_6_eot_n,
      /* ddd_hdr_pfx_end_ddd_hdr_pfx_end */ raw[1].tkn==PFX_TKN && hdr_2_eot_4 && raw[5].tkn==PFX_TKN && hdr_6_eot_n,
      /* ddd_hdr_end_ddd_hdr_pfx_pfx_end */ raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && hdr_3_eot_5 && hdr_6_eot_n,
      /* ddd_hdr_pfx_pfx_pfx_pfx_pfx_end */ raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && hdr_6_eot_n:
         raw_next_tlp_state[1] = get_next_tlp_state(raw[6]);

      /* hdr_end_ddd_ddd_ddd_ddd_hdr_end */ hdr_1_eot_6 && hdr_7_eot_n,
      /* hdr_pfx_end_ddd_ddd_ddd_hdr_end */ hdr_1_eot_5 && raw[6].tkn==PFX_TKN && hdr_7_eot_n,
      /* hdr_pfx_pfx_end_ddd_ddd_hdr_end */ hdr_1_eot_4 && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n,
      /* hdr_end_ddd_hdr_end_ddd_hdr_end */ hdr_1_eot_3 && hdr_4_eot_6 && hdr_7_eot_n,
      /* hdr_pfx_pfx_pfx_end_ddd_hdr_end */ hdr_1_eot_3 && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n,
      /* hdr_end_ddd_hdr_nop_nop_nop_end */ raw[1].tkn==NOP_TKN && hdr_4_eot_6 && hdr_7_eot_n,
      /* hdr_pfx_pfx_pfx_nop_nop_nop_end */ raw[1].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n,
      /* hdr_end_ddd_ddd_ddd_hdr_pfx_end */ raw[1].tkn==PFX_TKN && hdr_2_eot_6 && hdr_7_eot_n,
      /* hdr_pfx_end_ddd_ddd_hdr_pfx_end */ raw[1].tkn==PFX_TKN && hdr_2_eot_5 && raw[6].tkn==PFX_TKN && hdr_7_eot_n,
      /* hdr_pfx_pfx_end_ddd_hdr_pfx_end */ raw[1].tkn==PFX_TKN && hdr_2_eot_4 && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n,
      /* hdr_end_ddd_ddd_hdr_pfx_pfx_end */ raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && hdr_3_eot_6 && hdr_7_eot_n,
      /* hdr_pfx_end_ddd_hdr_pfx_pfx_end */ raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && hdr_3_eot_5 && raw[6].tkn==PFX_TKN && hdr_7_eot_n,
      /* hdr_end_ddd_hdr_pfx_pfx_pfx_end */ raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && hdr_4_eot_6 && hdr_7_eot_n,
      /* hdr_pfx_pfx_pfx_pfx_pfx_pfx_end */ raw[1].tkn==PFX_TKN && raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n:
         raw_next_tlp_state[1] = get_next_tlp_state(raw[7]);

      default :
         raw_next_tlp_state_valid[1] = 1'b0;
    endcase
end // raw_next_tlp_state_1_PROC

always_comb begin : raw_next_tlp_state_2_PROC
    raw_next_tlp_state[2] = '0;
    raw_next_tlp_state_valid[2] = 1'b1;
    unique case ( 1'b1 )
      /* ddd_ddd_ddd_ddd_ddd_hdr_end_ddd */ hdr_2_eot_n:
         raw_next_tlp_state[2] = get_next_tlp_state(raw[2]);

      /* ddd_ddd_ddd_ddd_hdr_pfx_end_ddd */ raw[2].tkn==PFX_TKN && hdr_3_eot_n:
         raw_next_tlp_state[2] = get_next_tlp_state(raw[3]);

      /* ddd_ddd_ddd_hdr_nop_nop_end_ddd */ raw[2].tkn==NOP_TKN && hdr_4_eot_n,
      /* ddd_ddd_ddd_hdr_pfx_pfx_end_ddd */ raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && hdr_4_eot_n:
         raw_next_tlp_state[2] = get_next_tlp_state(raw[4]);

      /* ddd_ddd_hdr_end_ddd_hdr_end_ddd */ hdr_2_eot_4 && hdr_5_eot_n,
      /* ddd_ddd_hdr_pfx_nop_nop_end_ddd */ raw[2].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && hdr_5_eot_n,
      /* ddd_ddd_hdr_pfx_pfx_pfx_end_ddd */ raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && hdr_5_eot_n:
         raw_next_tlp_state[2] = get_next_tlp_state(raw[5]);

      /* ddd_hdr_end_ddd_ddd_hdr_end_ddd */ hdr_2_eot_5 && hdr_6_eot_n,
      /* ddd_hdr_pfx_end_ddd_hdr_end_ddd */ hdr_2_eot_4 && raw[5].tkn==PFX_TKN && hdr_6_eot_n,
      /* ddd_hdr_pfx_pfx_nop_nop_end_ddd */ raw[2].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && hdr_6_eot_n,
      /* ddd_hdr_end_ddd_hdr_pfx_end_ddd */ raw[2].tkn==PFX_TKN && hdr_3_eot_5 && hdr_6_eot_n,
      /* ddd_hdr_pfx_pfx_pfx_pfx_end_ddd */ raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && hdr_6_eot_n:
         raw_next_tlp_state[2] = get_next_tlp_state(raw[6]);

      /* hdr_end_ddd_ddd_ddd_hdr_end_ddd */ hdr_2_eot_6 && hdr_7_eot_n,
      /* hdr_pfx_end_ddd_ddd_hdr_end_ddd */ hdr_2_eot_5 && raw[6].tkn==PFX_TKN && hdr_7_eot_n,
      /* hdr_pfx_pfx_end_ddd_hdr_end_ddd */ hdr_2_eot_4 && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n,
      /* hdr_end_ddd_hdr_nop_nop_end_ddd */ raw[2].tkn==NOP_TKN && hdr_4_eot_6 && hdr_7_eot_n,
      /* hdr_pfx_pfx_pfx_nop_nop_end_ddd */ raw[2].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n,
      /* hdr_end_ddd_ddd_hdr_pfx_end_ddd */ raw[2].tkn==PFX_TKN && hdr_3_eot_6 && hdr_7_eot_n,
      /* hdr_pfx_end_ddd_hdr_pfx_end_ddd */ raw[2].tkn==PFX_TKN && hdr_3_eot_5 && raw[6].tkn==PFX_TKN && hdr_7_eot_n,
      /* hdr_end_ddd_hdr_pfx_pfx_end_ddd */ raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && hdr_4_eot_6 && hdr_7_eot_n,
      /* hdr_pfx_pfx_pfx_pfx_pfx_end_ddd */ raw[2].tkn==PFX_TKN && raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n:
         raw_next_tlp_state[2] = get_next_tlp_state(raw[7]);

      default :
         raw_next_tlp_state_valid[2] = 1'b0;
    endcase
end // raw_next_tlp_state_2_PROC

always_comb begin : raw_next_tlp_state_3_PROC
    raw_next_tlp_state[3] = '0;
    raw_next_tlp_state_valid[3] = 1'b1;
    unique case ( 1'b1 )
      /* ddd_ddd_ddd_ddd_hdr_end_ddd_ddd */ hdr_3_eot_n:
         raw_next_tlp_state[3] = get_next_tlp_state(raw[3]);

      /* ddd_ddd_ddd_hdr_nop_end_ddd_ddd */ raw[3].tkn==NOP_TKN && hdr_4_eot_n,
      /* ddd_ddd_ddd_hdr_pfx_end_ddd_ddd */ raw[3].tkn==PFX_TKN && hdr_4_eot_n:
         raw_next_tlp_state[3] = get_next_tlp_state(raw[4]);

      /* ddd_ddd_hdr_pfx_nop_end_ddd_ddd */ raw[3].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && hdr_5_eot_n,
      /* ddd_ddd_hdr_pfx_pfx_end_ddd_ddd */ raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && hdr_5_eot_n:
         raw_next_tlp_state[3] = get_next_tlp_state(raw[5]);

      /* ddd_hdr_end_ddd_hdr_end_ddd_ddd */ hdr_3_eot_5 && hdr_6_eot_n,
      /* ddd_hdr_pfx_pfx_nop_end_ddd_ddd */ raw[3].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && hdr_6_eot_n,
      /* ddd_hdr_pfx_pfx_pfx_end_ddd_ddd */ raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && hdr_6_eot_n:
         raw_next_tlp_state[3] = get_next_tlp_state(raw[6]);

      /* hdr_end_ddd_ddd_hdr_end_ddd_ddd */ hdr_3_eot_6 && hdr_7_eot_n,
      /* hdr_pfx_end_ddd_hdr_end_ddd_ddd */ hdr_3_eot_5 && raw[6].tkn==PFX_TKN && hdr_7_eot_n,
      /* hdr_end_ddd_hdr_nop_end_ddd_ddd */ raw[3].tkn==NOP_TKN && hdr_4_eot_6 && hdr_7_eot_n,
      /* hdr_pfx_pfx_pfx_nop_end_ddd_ddd */ raw[3].tkn==NOP_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n,
      /* hdr_end_ddd_hdr_pfx_end_ddd_ddd */ raw[3].tkn==PFX_TKN && hdr_4_eot_6 && hdr_7_eot_n,
      /* hdr_pfx_pfx_pfx_pfx_end_ddd_ddd */ raw[3].tkn==PFX_TKN && raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n:
         raw_next_tlp_state[3] = get_next_tlp_state(raw[7]);

      default :
         raw_next_tlp_state_valid[3] = 1'b0;
    endcase
end // raw_next_tlp_state_3_PROC

always_comb begin : raw_next_tlp_state_4_PROC
    raw_next_tlp_state[4] = '0;
    raw_next_tlp_state_valid[4] = 1'b1;
    unique case ( 1'b1 )
      /* ddd_ddd_ddd_hdr_end_ddd_ddd_ddd */ hdr_4_eot_n:
         raw_next_tlp_state[4] = get_next_tlp_state(raw[4]);

      /* ddd_ddd_hdr_pfx_end_ddd_ddd_ddd */ raw[4].tkn==PFX_TKN && hdr_5_eot_n:
         raw_next_tlp_state[4] = get_next_tlp_state(raw[5]);

      /* ddd_hdr_pfx_pfx_end_ddd_ddd_ddd */ raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && hdr_6_eot_n:
         raw_next_tlp_state[4] = get_next_tlp_state(raw[6]);

      /* hdr_end_ddd_hdr_end_ddd_ddd_ddd */ hdr_4_eot_6 && hdr_7_eot_n,
      /* hdr_pfx_pfx_pfx_end_ddd_ddd_ddd */ raw[4].tkn==PFX_TKN && raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n:
         raw_next_tlp_state[4] = get_next_tlp_state(raw[7]);

      default :
         raw_next_tlp_state_valid[4] = 1'b0;
    endcase
end // raw_next_tlp_state_4_PROC

always_comb begin : raw_next_tlp_state_5_PROC
    raw_next_tlp_state[5] = '0;
    raw_next_tlp_state_valid[5] = 1'b1;
    unique case ( 1'b1 )
      /* ddd_ddd_hdr_end_ddd_ddd_ddd_ddd */ hdr_5_eot_n:
         raw_next_tlp_state[5] = get_next_tlp_state(raw[5]);

      /* ddd_hdr_pfx_end_ddd_ddd_ddd_ddd */ raw[5].tkn==PFX_TKN && hdr_6_eot_n:
         raw_next_tlp_state[5] = get_next_tlp_state(raw[6]);

      /* hdr_pfx_pfx_end_ddd_ddd_ddd_ddd */ raw[5].tkn==PFX_TKN && raw[6].tkn==PFX_TKN && hdr_7_eot_n:
         raw_next_tlp_state[5] = get_next_tlp_state(raw[7]);

      default :
         raw_next_tlp_state_valid[5] = 1'b0;
    endcase
end // raw_next_tlp_state_5_PROC

always_comb begin : raw_next_tlp_state_6_PROC
    raw_next_tlp_state[6] = '0;
    raw_next_tlp_state_valid[6] = 1'b1;
    unique case ( 1'b1 )
      /* ddd_hdr_end_ddd_ddd_ddd_ddd_ddd */ hdr_6_eot_n:
         raw_next_tlp_state[6] = get_next_tlp_state(raw[6]);

      /* hdr_pfx_end_ddd_ddd_ddd_ddd_ddd */ raw[6].tkn==PFX_TKN && hdr_7_eot_n:
         raw_next_tlp_state[6] = get_next_tlp_state(raw[7]);

      default :
         raw_next_tlp_state_valid[6] = 1'b0;
    endcase
end // raw_next_tlp_state_6_PROC

always_comb begin : raw_next_tlp_state_7_PROC
    raw_next_tlp_state[7] = '0;
    raw_next_tlp_state_valid[7] = 1'b1;
    unique case ( 1'b1 )
      /* hdr_end_ddd_ddd_ddd_ddd_ddd_ddd */ hdr_7_eot_n:
         raw_next_tlp_state[7] = get_next_tlp_state(raw[7]);

      default :
         raw_next_tlp_state_valid[7] = 1'b0;
    endcase
end // raw_next_tlp_state_7_PROC
// END MARKER FOR SCRIPT GENERATED CODE

always_comb begin : next_state_PROC
    unique case ( 1'b1 )
      prev_tlp_none                                : next_tlp_state = raw_next_tlp_state[0];
      prev_tlp_eot_0 & raw_next_tlp_state_valid[1] : next_tlp_state = raw_next_tlp_state[1];
      prev_tlp_eot_1 & raw_next_tlp_state_valid[2] : next_tlp_state = raw_next_tlp_state[2];
      prev_tlp_eot_2 & raw_next_tlp_state_valid[3] : next_tlp_state = raw_next_tlp_state[3];
      prev_tlp_eot_3 & raw_next_tlp_state_valid[4] : next_tlp_state = raw_next_tlp_state[4];
      prev_tlp_eot_4 & raw_next_tlp_state_valid[5] : next_tlp_state = raw_next_tlp_state[5];
      prev_tlp_eot_5 & raw_next_tlp_state_valid[6] : next_tlp_state = raw_next_tlp_state[6];
      prev_tlp_eot_6 & raw_next_tlp_state_valid[7] : next_tlp_state = raw_next_tlp_state[7];
      prev_tlp_eot_n                               : next_tlp_state = get_next_tlp_state(cast_state(prev_tlp_state));
      default                                      : next_tlp_state = '0;
    endcase
end // next_state_PROC

// Timing considerations.
// Note that next_state_PROC and tlp_out_PROC must be combinatorial because they depend on the
// previous TLP state and must produce next state to the next decoder in chain (or next clock cycle).
// Instead, raw_next_tlp_state and hdr_*_eot_* can be pipelined. 

function automatic tlp_state_t get_next_tlp_state (
    input fm_raw_tkn_t raw_tlp_state
);
    begin
        get_next_tlp_state.eot_pos = raw_tlp_state.eot_pos;
        get_next_tlp_state.eot_dec = (raw_tlp_state.eot_flt==0)? raw_tlp_state.eot_dec-1'b1 : raw_tlp_state.eot_dec;
        get_next_tlp_state.eot_flt = raw_tlp_state.eot_flt;
        get_next_tlp_state.pending = 1;
    end
endfunction

// Cast tlp_state_t into fm_raw_tkn_t
function automatic fm_raw_tkn_t cast_state (
    input tlp_state_t tlp_state
);
    begin
        cast_state = '0;
        cast_state.eot_pos = tlp_state.eot_pos;
        cast_state.eot_dec = tlp_state.eot_dec;
        cast_state.eot_flt = tlp_state.eot_flt;
    end
endfunction


endmodule // rplh_fm_pkt_finder_256b_dec

