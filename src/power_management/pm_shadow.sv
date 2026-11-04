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
// ---    $Revision: #10 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_shadow.sv#10 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// --- This module contains shadow registers which are used to retain
// --- information during low power states.
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "power_management/DWC_pcie_pm_pkg.svh"
 
 module pm_shadow
    import DWC_pcie_pm_pkg::usp_link_fsm_state_e;
    import DWC_pcie_pm_pkg::dsp_link_fsm_state_e;
    // Parameters
    #(
        parameter INST = 0,
        parameter NL = 0
    )
    
                     (
    // Inputs
    input                                       aux_clk,                // always on clock
    input                                       pwr_rst_n,              // power on reset
    input                                       smlh_link_up,           // Link status from smlh
    input                                       pm_hold,                // Hold signal from power management circuit active in L1.2
    input                                       pm_hold_perst,          // Hold signal from power management circuit active in L2
    input                                       pm_update,              // Update signal from power management circuit active in L1.2
    input                                       pm_update_perst,        // Update signal from power management circuit active in L2
    input                                       rstctl_ltssm_enable,    // LTSSM enable to be shadowed in always on domain 
    input [2:0]                                 current_data_rate,      // Current data rate from LTSSM
    input [NL-1:0]                              rmlh_descrambled_even_parity,   // Current tx skip even data parity from RMLH
    input [NL-1:0]                              xmlh_scramble_even_parity,      // Current rx skip even data parity from XMLH
    input                                       trgt_cpl_lut_empty,     // Target CPL lut empty
    input                                       brdg_mstr_xfer_pending,
    input                                       radm_idle,              // RADM Idle indication
    input [NL-1:0]                              latched_rxdetected,
    input [4:0]                                 cdm_pm_state_trans_tracker,
    input                                       smlh_pm_state_trans1_flag,
    input                                       smlh_pm_state_trans2_flag,
    input  usp_link_fsm_state_e                 pm_usp_link_state,
    input  dsp_link_fsm_state_e                 pm_dsp_link_state,
    input                                       pm_linkst_in_l0s,
    input                                       pm_linkst_in_l0,
    input                                       pm_l1_entry_started,
    input                                       pm_aspm_l1_enter_ready,
    input                                       pm_l1_in_progress,
    input                                       latch_as_entr_l1,
    input                                       pl_pcie_phyinl1,
    input                                       pl_pcie_phyinl2,
    input                                       pl_pcie_state_l1,
    input                                       pl_pcie_state_l2,
    input                                       pl_pcie_state_active,
    input                                       pl_pcie_link_up,
    input                                       pl_cxl_phyinl1,
    input                                       pl_cxl_phyinl2,
    input                                       pl_cxl_state_l1,
    input                                       pl_cxl_state_l2,
    input                                       pl_cxl_mode_enable,
    input                                       lp_sdb_l1sub_aspm,
    input                                       lp_sdb_l1sub_pcipm,
    input                                       pm_prot_idle_flag,
    input                                       pm_xdlh_enter_l23,
    // Outputs
    output wire                                 pm_smlh_link_up,        // SMLH link status mirrored in always on domain
    output wire                                 pm_ltssm_enable,        // LTSSM enable shadowed in always on domain
    output wire [2:0]                           pm_current_data_rate    // Current data rate shadowed in always on domain
    ,
    output [NL-1:0]                             pm_rmlh_descrambled_even_parity,   // Current tx skip even data parity shadowed in always on domain
    output [NL-1:0]                             pm_xmlh_scramble_even_parity       // Current rx skip even data parity shadowed in always on domain
    ,
    output wire                                 pm_trgt_cpl_lut_empty_n   // Target CPL lut empty active low
    ,
    output wire                                 pm_radm_idle_n            // RADM Idle active low

    ,
    output wire [NL-1:0]                       pm_latched_rxdetected
    ,
    output wire [4:0]                                pm_cdm_pm_state_trans_tracker,
    output wire                                     pm_smlh_pm_state_trans1_flag,
    output wire                                     pm_smlh_pm_state_trans2_flag
    ,
    output usp_link_fsm_state_e                 shadow_pm_usp_link_state,
    output dsp_link_fsm_state_e                 shadow_pm_dsp_link_state,
    output                                      shadow_pm_linkst_in_l0s,
    output                                      shadow_pm_linkst_in_l0,
    output                                      shadow_pm_l1_entry_started,
    output                                      shadow_pm_aspm_l1_enter_ready,
    output                                      shadow_pm_l1_in_progress,
    output                                      shadow_latch_as_entr_l1,
    output                                      shadow_pl_pcie_phyinl1,
    output                                      shadow_pl_pcie_phyinl2,
    output                                      shadow_pl_pcie_state_l1,
    output                                      shadow_pl_pcie_state_l2,
    output                                      shadow_pl_pcie_state_active,
    output                                      shadow_pl_pcie_link_up,
    output                                      shadow_pl_cxl_phyinl1,
    output                                      shadow_pl_cxl_phyinl2,
    output                                      shadow_pl_cxl_state_l1,
    output                                      shadow_pl_cxl_state_l2,
    output                                      shadow_pl_cxl_mode_enable,
    output                                      shadow_lp_sdb_l1sub_aspm,
    output                                      shadow_lp_sdb_l1sub_pcipm,
    output                                      shadow_pm_prot_idle_flag,
    output                                      shadow_pm_xdlh_enter_l23
);

// ----------------------------------------------------------------------------
// Parameter Declarations
// ----------------------------------------------------------------------------
parameter  TP = `TP;
localparam SHADOW_REG_SIZE = 5; // hardcoded to match the sum of the width of all signals
                                // input to the array of shadow registers

// ----------------------------------------------------------------------------
// Wire Declarations
// ----------------------------------------------------------------------------
wire    [SHADOW_REG_SIZE - 1 : 0]   int_shadow_in_s;
wire    [SHADOW_REG_SIZE - 1 : 0]   int_shadow_out_s;
wire                                int_sel_epm_en_s;

// ----------------------------------------------------------------------------
// Logic
// ----------------------------------------------------------------------------
assign int_sel_epm_en_s = 1'b0;

// Concatenate signals to be shadowed to create input bus to array of instances
assign int_shadow_in_s = {
smlh_link_up, rstctl_ltssm_enable, current_data_rate};

// Instantiate the shadow register
shadow_reg

#(.INST (INST)) u_shadow_reg[SHADOW_REG_SIZE - 1 : 0] (
    // Inputs
    .clk            (aux_clk),
    .rst_n          (pwr_rst_n),
    .en_shadow      (int_sel_epm_en_s),
    .hold_data      (pm_hold),
    .update         (pm_update),
    .data           (int_shadow_in_s),
    // Outputs
    .shadow_data    (int_shadow_out_s)
);

// Assignment of outputs from array of instances
assign {
pm_smlh_link_up, pm_ltssm_enable, pm_current_data_rate}
 = int_shadow_out_s;

localparam PARITY_SHADOW_SIZE = NL*2;
wire [PARITY_SHADOW_SIZE - 1: 0] int_parity_shadow_in_s;
wire [PARITY_SHADOW_SIZE - 1: 0] int_parity_shadow_out_s;

assign int_parity_shadow_in_s = {rmlh_descrambled_even_parity,xmlh_scramble_even_parity};

shadow_reg

#(.INST (INST)) u_parity_shadow_reg[PARITY_SHADOW_SIZE - 1: 0] (
    // Inputs
    .clk            (aux_clk),
    .rst_n          (pwr_rst_n),
    .en_shadow      (int_sel_epm_en_s),
    .hold_data      (pm_hold),
    .update         (pm_update),
    .data           (int_parity_shadow_in_s),
    // Outputs
    .shadow_data    (int_parity_shadow_out_s)
);

assign {pm_rmlh_descrambled_even_parity, pm_xmlh_scramble_even_parity} = int_parity_shadow_out_s;



shadow_reg

#(.INST (INST)) u_trgt_cpl_lut_shadow_reg (
    // Inputs
    .clk            (aux_clk),
    .rst_n          (pwr_rst_n),
    .en_shadow      (int_sel_epm_en_s),
    .hold_data      (pm_hold),
    .update         (pm_update),
    .data           (!trgt_cpl_lut_empty),
    // Outputs
    .shadow_data    (pm_trgt_cpl_lut_empty_n)
);

wire s_radm_idle;

assign s_radm_idle = radm_idle && !brdg_mstr_xfer_pending;

shadow_reg

#(.INST (INST)) u_radm_idle_shadow_reg (
    // Inputs
    .clk            (aux_clk),
    .rst_n          (pwr_rst_n),
    .en_shadow      (int_sel_epm_en_s),
    .hold_data      (pm_hold),
    .update         (pm_update),
    .data           (!s_radm_idle),
    // Outputs
    .shadow_data    (pm_radm_idle_n)
);


shadow_reg

#(.INST (INST)) u_latched_rxdetected_shadow_reg[NL - 1: 0] (
    // Inputs
    .clk            (aux_clk),
    .rst_n          (pwr_rst_n),
    .en_shadow      (int_sel_epm_en_s),
    .hold_data      (pm_hold),
    .update         (pm_update),
    .data           (latched_rxdetected),
    // Outputs
    .shadow_data    (pm_latched_rxdetected)
);


shadow_reg

#(.INST (INST)) u_ltssm_state_trans_tracking [6 : 0] (
    // Inputs
    .clk            (aux_clk),
    .rst_n          (pwr_rst_n),
    .en_shadow      (int_sel_epm_en_s),
    .hold_data      (pm_hold),
    .update         (pm_update),
    .data           ({cdm_pm_state_trans_tracker, smlh_pm_state_trans1_flag, smlh_pm_state_trans2_flag}),
    // Outputs
    .shadow_data    ({pm_cdm_pm_state_trans_tracker, pm_smlh_pm_state_trans1_flag, pm_smlh_pm_state_trans2_flag})
);

shadow_reg

#(.INST (INST)) u_pm_link_protocol_signals [11 + $bits(usp_link_fsm_state_e) + $bits(dsp_link_fsm_state_e) + 2 + 2 + 5 : 0] (
    // Inputs
    .clk            (aux_clk),
    .rst_n          (pwr_rst_n),
    .en_shadow      (int_sel_epm_en_s),
    .hold_data      (pm_hold || pm_hold_perst),
    .update         (pm_update || pm_update_perst),
    .data           ({pm_linkst_in_l0s,
                      pm_linkst_in_l0,
                      pm_l1_entry_started,
                      pm_aspm_l1_enter_ready,
                      pm_usp_link_state,
                      pm_dsp_link_state,
                      pm_l1_in_progress,
                      latch_as_entr_l1,
                      pl_pcie_phyinl1,
                      pl_pcie_phyinl2,
                      pl_pcie_state_l1,
                      pl_pcie_state_l2,
                      pl_pcie_state_active,
                      pl_pcie_link_up,
                      pl_cxl_phyinl1,
                      pl_cxl_phyinl2,
                      pl_cxl_state_l1,
                      pl_cxl_state_l2,
                      pl_cxl_mode_enable,
                      lp_sdb_l1sub_aspm,
                      lp_sdb_l1sub_pcipm,
                      pm_prot_idle_flag,
                      pm_xdlh_enter_l23}),
    // Outputs
    .shadow_data    ({shadow_pm_linkst_in_l0s,
                      shadow_pm_linkst_in_l0,
                      shadow_pm_l1_entry_started,
                      shadow_pm_aspm_l1_enter_ready,
                      shadow_pm_usp_link_state,
                      shadow_pm_dsp_link_state,
                      shadow_pm_l1_in_progress,
                      shadow_latch_as_entr_l1,
                      shadow_pl_pcie_phyinl1,
                      shadow_pl_pcie_phyinl2,
                      shadow_pl_pcie_state_l1,
                      shadow_pl_pcie_state_l2,
                      shadow_pl_pcie_state_active,
                      shadow_pl_pcie_link_up,
                      shadow_pl_cxl_phyinl1,
                      shadow_pl_cxl_phyinl2,
                      shadow_pl_cxl_state_l1,
                      shadow_pl_cxl_state_l2,
                      shadow_pl_cxl_mode_enable,
                      shadow_lp_sdb_l1sub_aspm,
                      shadow_lp_sdb_l1sub_pcipm,
                      shadow_pm_prot_idle_flag,
                      shadow_pm_xdlh_enter_l23})
);

endmodule
