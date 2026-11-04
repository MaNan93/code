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
// ---    $DateTime: 2023/04/29 12:35:01 $
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/PTM/ptm_requester.sv#7 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the Precision Time Measurement Extended Capability (PTM) registers. 
// --- This module is instantiated for each function across all functions.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module ptm_requester
#(
    parameter INST                  = 0,                                // The uniquifying parameter for each port logic instance.
    parameter FUNC_NUM              = 0                                 // uniquifying parameter per function
    ,parameter PTM_REQ_VALUE        = `CX_PTM_REQUESTER_VALUE
    ,parameter NPTMREQVSEC          = 26
    ,parameter WF = 16
   )


                    (
  input                                   aux_clk, 
  input                                   non_sticky_rst_n,
  input                                   sticky_rst_n,

  input                                   lbc_cdm_dbi,
  input [3:0]                             write_pulse,
  input [NPTMREQVSEC-1:0]                 reg_id,
  input [31:0]                            lbc_cdm_data,
  input                                   dbi_ro_wr_en,

  input                                   phy_link_up,
  input                                   cfg_ptm_enabled,
  input                                   cfg_ptm_root_select,
  input                                   pm_sel_aux_clk,
  input                                   smlh_in_l0,

  input [7+WF:0]                          ptm_nom_clock_period, // Nominal PTM clock period based on clock speed
  input [7+WF:0]                          ptm_clock_period,     // Selected PTM clock period
  input                                   ptm_clock_period_change,
  input [63:0]                            ptm_local_clk,
  input                                   ptm_link_speed_change,
  input [11:0]                            ptm_eof_latency,             // Distance, in nsec, between flit eof and ptm bit.
  input                                   flit_mode_link,              // Indicates the link has come up in flit mode

  input                                   xdlh_rbuf_replaying,
  input                                   xdlh_ptm_sot,                //time stamped on this pulse
  input                                   xdlh_ptm_multi_cycle,          //time move to t1 on this pulse
  input                                   xdlh_ptm_request,              //time move to t1 on this pulse
  input                                   rdlh_ptm_sot,                //time stamped on this pulse
  input                                   rdlh_ptm_multi_cycle,             //time move to t4 on this pulse
  input                                   rdlh_ptm_response,                //time move to t4 on this pulse
  input                                   rdlh_duplicate_tlp,

  input [2:0]                             ptm_latency_sel,            // latency select

  input                                   ptm_manual_update_pulse,            //top level input
  input                                   ptm_auto_update_signal,            //top level input
  input                                   pm_linkst_in_l0,              //input from pm_active_ctrl indicating PM state in L0
  input                                   pm_linkst_in_l0s,             //input from pm_active_ctrl indicating PM state in L0s
  
  input                                   radm_ptm_res_msg,       //radm filter detects ptm response message
  input                                   radm_ptm_res_d_msg,     //radm filter detects ptm response D message
  input [63:0]                            radm_ptm_master_time,   // Master Time from response D message
  input [31:0]                            radm_ptm_prop_delay,    // Propagation Delay from response D message


  output [7+WF:0]                         ptm_scaled_clock_period,    // Scaled PTM clock period from VSEC register
  output                                  ptm_scaled_clock_period_en, // Enable Scaled PTM clock period from VSEC register
  output                                  ptm_gen_req_msg,         // to msg_gen to output ptm request message

  output                                  ptm_trigger_allowed,          // when system is not in the middle of an update a manual request may be made
  output                                  ptm_context_valid,
  output                                  ptm_clock_updated,            //pulse to indicate clock was updated

  output [31:0]                           ptm_reg_data,
  output                                  ptm_update_local_clk,
  output signed [63:0]                    ptm_requester_adjust_value,
  output signed [63:0]                    ptm_clock_correction,

  output                                  ptm_updating,                 //PTM Update is in progress

  output                                  ptm_req_response_timeout,     //Pulse indicating PTM Request sent but no response after 100us
  output                                  ptm_req_dup_rx,               //Pulse indicating Duplicate TLP received during PTM update process or response received during wait for next update
  output                                  ptm_req_replay_tx             //Pulse indicating Replay TLP sent during PTM update process or Request sent during wait for next update
  );


  wire [7:0]                    ptm_long_timer;
  wire                          ptm_manual_update_reg;
  wire                          ptm_auto_update_en_reg;
  wire                          ptm_fast_timer;
  wire                          ptm_calc_round_trip;
  wire                          ptm_calc_update;



ptm_request_fsm
 
u_ptm_requester_fsm
(

  .non_sticky_rst_n             (non_sticky_rst_n),
  .aux_clk                      (aux_clk),

  .phy_link_up                  (phy_link_up),
  .pm_sel_aux_clk               (pm_sel_aux_clk),
  .smlh_in_l0                   (smlh_in_l0),

  .radm_ptm_res_msg             (radm_ptm_res_msg),
  .radm_ptm_res_d_msg           (radm_ptm_res_d_msg),
  .xdlh_ptm_request             (xdlh_ptm_request),
  .xdlh_rbuf_replaying          (xdlh_rbuf_replaying),
  .xdlh_ptm_sot                 (xdlh_ptm_sot),                 //layer 2
  .rdlh_ptm_response            (rdlh_ptm_response),
  .rdlh_duplicate_tlp           (rdlh_duplicate_tlp),
  .rdlh_ptm_sot                 (rdlh_ptm_sot),                 //layer 2

  .ptm_manual_update_reg        (ptm_manual_update_reg),
  .ptm_manual_update_pulse      (ptm_manual_update_pulse),

  .cfg_ptm_enabled              (cfg_ptm_enabled),
  
  .ptm_auto_update_en_reg       (ptm_auto_update_en_reg),
  .ptm_auto_update_signal       (ptm_auto_update_signal),
  .ptm_clock_period             (ptm_clock_period),
  .ptm_clock_period_change      (ptm_clock_period_change),
  .ptm_link_speed_change        (ptm_link_speed_change),

  .ptm_fast_timer               (ptm_fast_timer),
  .ptm_long_timer               (ptm_long_timer),

  .pm_linkst_in_l0              (pm_linkst_in_l0),              //from pm_active_ctrl indicating PM state in L0
  .pm_linkst_in_l0s             (pm_linkst_in_l0s),             //from pm_active_ctrl indicating PM state in L0s

  // outputs

  .ptm_update_local_clk         (ptm_update_local_clk),         // to ptm_clock block
  .ptm_calc_round_trip          (ptm_calc_round_trip),          // to reg block
  .ptm_calc_update              (ptm_calc_update),              // to reg block
  .ptm_trigger_allowed          (ptm_trigger_allowed),          // to reg block and top level output
  .ptm_context_valid            (ptm_context_valid),            // top level output
  .ptm_clock_updated            (ptm_clock_updated),            // top level output

  .ptm_gen_req_msg              (ptm_gen_req_msg),

  .ptm_updating                 (ptm_updating),            // to pm_ctrl block AND top level output

  .ptm_req_response_timeout     (ptm_req_response_timeout),     // top level output
  .ptm_req_dup_rx               (ptm_req_dup_rx),               // top level output
  .ptm_req_replay_tx            (ptm_req_replay_tx)             // top level output
);


ptm_request_reg
 #(.NPTMREQVSEC(NPTMREQVSEC))
u_ptm_requester_reg
(

  .sticky_rst_n                 (sticky_rst_n),
  .aux_clk                      (aux_clk),
  .non_sticky_rst_n             (non_sticky_rst_n),

  .lbc_cdm_dbi                  (lbc_cdm_dbi),
  .lbc_cdm_data                 (lbc_cdm_data),
  .dbi_ro_wr_en                 (dbi_ro_wr_en),
  .write_pulse                  (write_pulse),
  .reg_id                       (reg_id),

  .cfg_ptm_root_select          (cfg_ptm_root_select),
  .cfg_ptm_enabled              (cfg_ptm_enabled),
  .phy_link_up                  (phy_link_up),
  

  .xdlh_ptm_sot                 (xdlh_ptm_sot),                 //layer 2
  .xdlh_ptm_multi_cycle         (xdlh_ptm_multi_cycle),
  .xdlh_ptm_request             (xdlh_ptm_request),
  .rdlh_ptm_sot                 (rdlh_ptm_sot),                 //layer 2
  .rdlh_ptm_multi_cycle         (rdlh_ptm_multi_cycle),
  .rdlh_ptm_response            (rdlh_ptm_response),
  .ptm_eof_latency              (ptm_eof_latency),
  .flit_mode_link               (flit_mode_link),

  .ptm_latency_sel              (ptm_latency_sel),             //latency select

  .ptm_nom_clock_period         (ptm_nom_clock_period),
  .ptm_clock_period             (ptm_clock_period),
  .ptm_fast_timer               (ptm_fast_timer),
  .ptm_long_timer               (ptm_long_timer),

  .ptm_calc_round_trip          (ptm_calc_round_trip),
  .ptm_calc_update              (ptm_calc_update),
  .ptm_update_local_clk         (ptm_update_local_clk),             

  .radm_ptm_res_d_msg           (radm_ptm_res_d_msg),
  .radm_ptm_master_time         (radm_ptm_master_time),              //input from RADM
  .radm_ptm_prop_delay          (radm_ptm_prop_delay),               //input from RADM

  .ptm_scaled_clock_period      (ptm_scaled_clock_period),
  .ptm_scaled_clock_period_en   (ptm_scaled_clock_period_en),
 
  .ptm_requester_adjust_value   (ptm_requester_adjust_value),
  .ptm_clock_correction         (ptm_clock_correction),


  .ptm_auto_update_en_reg       (ptm_auto_update_en_reg),
  .ptm_manual_update_reg        (ptm_manual_update_reg),
  .ptm_req_reg_data             (ptm_reg_data),
  .ptm_trigger_allowed          (ptm_trigger_allowed),
  .ptm_context_valid            (ptm_context_valid),
  .ptm_clock_period_change      (ptm_clock_period_change),
  .local_clk                    (ptm_local_clk)

);

endmodule //ptm_requester 
