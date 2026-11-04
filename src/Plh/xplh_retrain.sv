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

// -------------------------------------------------------------------------------------
// --- RCS information:
// ---   $DateTime: 2023/10/26 13:05:23 $
// ---   $Revision: #3 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_retrain.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// XPLH RETRAIN
//
// Description: This module implements the RASDES feature allowing the link layer to force a link down reset after several REPLAY NUM rollovers has occurred. 
//
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"

module xplh_retrain
  import  cx_pl_pkg::tx_cmd_struct;
  import  cx_pl_pkg::CMD_RESET;
#(
  parameter   TP        = `TP
) (
  input        core_clk,
  input        core_rst_n,
  input        cdm_ras_des_force_linkdown_noack, // Force link down enable signal
  input        replay_num_rollover,              // Replay num roll over 
  input        tx_cmd_struct xmlh_xplh_cmd,      // XMLH Commands
  input        ack_nak_upd,                      // An updated ack or nak has been received
  output logic xplh_retrain_req_link_down        // Request to LTSSM to go to detect, it is set to 1 when the retrain counter rolls over and cdm_ras_des_force_linkdown_noack is set to 1
);


   logic [1:0] rollover_cnt;
   logic       int_xplh_retrain_req_link_down;


   always_ff @(posedge core_clk or negedge core_rst_n) begin : replay_num_rollover_counter
     if (!core_rst_n) begin
       rollover_cnt <= #TP 2'b00;
     end else if (xmlh_xplh_cmd.tx_cmd == CMD_RESET || ack_nak_upd) begin
       rollover_cnt <= #TP 2'b00;
     end else if((replay_num_rollover)) begin
       rollover_cnt <= #TP rollover_cnt + 2'b01;
     end else begin
       rollover_cnt <= #TP rollover_cnt;
     end
   end : replay_num_rollover_counter
   
   always_ff @(posedge core_clk or negedge core_rst_n) begin : hold_linkdown_req_value_for_ltssm
     if (!core_rst_n) begin
       int_xplh_retrain_req_link_down <= #TP 1'b0;
     end else if (xmlh_xplh_cmd.tx_cmd == CMD_RESET) begin
       int_xplh_retrain_req_link_down <= #TP 1'b0;
     end else if (rollover_cnt == 2'b11 && cdm_ras_des_force_linkdown_noack && replay_num_rollover) begin
       int_xplh_retrain_req_link_down <= #TP 1'b1;
     end else begin
       int_xplh_retrain_req_link_down <= #TP int_xplh_retrain_req_link_down;
     end
   end : hold_linkdown_req_value_for_ltssm


assign xplh_retrain_req_link_down = int_xplh_retrain_req_link_down;

endmodule 
