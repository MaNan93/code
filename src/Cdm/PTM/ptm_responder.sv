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
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/PTM/ptm_responder.sv#8 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the Precision Time Measurement Extended Capability (PTM) registers. 
// --- This module is instantiated for each function across all functions.
// -----------------------------------------------------------------------------



`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module ptm_responder  
#(
    parameter INST                  = 0,                                // The uniquifying parameter for each port logic instance.
    parameter FUNC_NUM              = 0                                 // uniquifying parameter per function  
    ,parameter WF = 16
    ,parameter NPTMRESVSEC          = 19
   )

                     (
  input                                   aux_clk, 
  input                                   non_sticky_rst_n,
  input                                   sticky_rst_n,

  input                                   lbc_cdm_dbi,
  input [3:0]                             write_pulse,
  input [NPTMRESVSEC-1:0]                 reg_id,
  input [31:0]                            lbc_cdm_data,
  input                                   dbi_ro_wr_en,

  input                                   phy_link_up,
  input                                   cfg_ptm_enabled,
  input                                   cfg_ptm_responder_capable,

  input                                   pm_sel_aux_clk,
  input [7+WF:0]                          ptm_nom_clock_period, // Nominal PTM clock period based on clock speed
  input [7+WF:0]                          ptm_clock_period,     // Selected PTM clock period
  input                                   ptm_clock_period_change,
  input [11:0]                            ptm_eof_latency,             // Distance, in nsec, between flit eof and ptm bit.
  input                                   flit_mode_link,              // Indicates the link has come up in flit mode

  input [2:0]                             ptm_latency_sel,        // latency select

  input                                   xdlh_retry_req,
  input                                   xdlh_ptm_sot,                 //layer 2
  input                                   xdlh_ptm_multi_cycle,
  input                                   xdlh_ptm_response,
  input                                   rdlh_duplicate_tlp,
  input                                   rdlh_ptm_sot,                 //layer 2
  input                                   rdlh_ptm_multi_cycle,
  input                                   rdlh_ptm_request,
  input                                   pm_linkst_in_l0,              //input from pm_active_ctrl indicating PM state in L0
  input                                   pm_linkst_in_l0s,             //input from pm_active_ctrl indicating PM state in L0s
  input                                   radm_ptm_req_msg,

  input [63:0]                            ptm_local_clk,


  input                                   ptm_responder_rdy_to_validate,
  input                                   ptm_external_master_strobe,    


  output [7+WF:0]                         ptm_scaled_clock_period,    // Scaled PTM clock period from VSEC register
  output                                  ptm_scaled_clock_period_en, // Enable Scaled PTM clock period from VSEC register
  output                                  ptm_gen_res_msg,
  output                                  ptm_gen_res_d_msg,
  output [63:0]                           ptm_master_time,
  output [31:0]                           ptm_prop_delay,  
  output                                  ptm_status_context_valid,         
  output [31:0]                           ptm_reg_data
);


  wire                                   ptm_state_at_res_d;

ptm_responder_reg
 #(.NPTMRESVSEC(NPTMRESVSEC))
u_ptm_responder_reg(

  .non_sticky_rst_n             (non_sticky_rst_n),
  .sticky_rst_n                 (sticky_rst_n),
  .aux_clk                      (aux_clk),

  .lbc_cdm_dbi                  (lbc_cdm_dbi),
  .lbc_cdm_data                 (lbc_cdm_data),
  .dbi_ro_wr_en                 (dbi_ro_wr_en),
  .write_pulse                  (write_pulse),
  .reg_id                       (reg_id),
  .cfg_ptm_enabled              (cfg_ptm_enabled),
  .phy_link_up                  (phy_link_up),
  
  .local_clk                    (ptm_local_clk),

  .rdlh_ptm_sot                 (rdlh_ptm_sot),                 //layer 2
  .rdlh_ptm_multi_cycle         (rdlh_ptm_multi_cycle),
  .rdlh_ptm_request             (rdlh_ptm_request),
  .xdlh_ptm_sot                 (xdlh_ptm_sot),                 //layer 2
  .xdlh_ptm_multi_cycle         (xdlh_ptm_multi_cycle),
  .xdlh_ptm_response            (xdlh_ptm_response),
  .ptm_eof_latency              (ptm_eof_latency),
  .flit_mode_link               (flit_mode_link),

  .ptm_latency_sel              (ptm_latency_sel),              //latency select

  .ptm_state_at_res_d           (ptm_state_at_res_d),           //have received at least 1 PTM request message, will now send PTM Response D messages
  .pm_sel_aux_clk               (pm_sel_aux_clk),
  .ptm_nom_clock_period         (ptm_nom_clock_period),
  .ptm_clock_period             (ptm_clock_period),
  .ptm_clock_period_change      (ptm_clock_period_change),
  

  .ptm_responder_rdy_to_validate (ptm_responder_rdy_to_validate),
  .ptm_external_master_strobe    (ptm_external_master_strobe),



  //outputs 
  .ptm_scaled_clock_period      (ptm_scaled_clock_period),
  .ptm_scaled_clock_period_en   (ptm_scaled_clock_period_en),

  .ptm_master_time              (ptm_master_time),              //output to msg_gen
  .ptm_prop_delay               (ptm_prop_delay),               //output to msg_gen
  .ptm_status_context_valid     (ptm_status_context_valid),
  .ptm_res_reg_data             (ptm_reg_data)
);


ptm_responder_fsm
 
u_ptm_responder_fsm(

  .non_sticky_rst_n             (non_sticky_rst_n),
  .sticky_rst_n                 (sticky_rst_n),
  .aux_clk                      (aux_clk),

  .rdlh_duplicate_tlp           (rdlh_duplicate_tlp),
  .xdlh_retry_req               (xdlh_retry_req),
  
  .ptm_request_msg_rec          (radm_ptm_req_msg),
  .phy_link_up                  (phy_link_up),
  .cfg_ptm_enabled              (cfg_ptm_enabled),
  .pm_sel_aux_clk               (pm_sel_aux_clk),
  .ptm_clock_period_change      (ptm_clock_period_change),
  .ptm_status_context_valid     (ptm_status_context_valid),

  .cfg_ptm_responder_capable    (cfg_ptm_responder_capable),
  .pm_linkst_in_l0              (pm_linkst_in_l0),              //from pm_active_ctrl indicating PM state in L0
  .pm_linkst_in_l0s             (pm_linkst_in_l0s),             //from pm_active_ctrl indicating PM state in L0s
  //outputs

  .ptm_gen_res_msg              (ptm_gen_res_msg),
  .ptm_gen_res_d_msg            (ptm_gen_res_d_msg),

  .ptm_state_at_res_d           (ptm_state_at_res_d)
);




endmodule //ptm_reponder 
