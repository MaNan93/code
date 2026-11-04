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
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/PTM/ptm_responder_fsm.sv#5 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the Precision Time Measurement Extended Capability (PTM) registers. 
// --- This module is instantiated for each function across all functions.
// -----------------------------------------------------------------------------



`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module ptm_responder_fsm
#(
    parameter INST                  = 0,                                // The uniquifying parameter for each port logic instance.
    parameter FUNC_NUM              = 0                                 // uniquifying parameter per function  
   )

  
                         (

  input                                   aux_clk,
  input                                   non_sticky_rst_n,
  input                                   sticky_rst_n,
           
  input                                   xdlh_retry_req,
  input                                   rdlh_duplicate_tlp,

  input                                   cfg_ptm_enabled,
  input                                   cfg_ptm_responder_capable,

  input                                   ptm_clock_period_change,
  input                                   pm_sel_aux_clk,
  input                                   ptm_status_context_valid,
  input                                   ptm_request_msg_rec,

  input                                   phy_link_up,
  input                                   pm_linkst_in_l0,              //input from pm_active_ctrl indicating PM state in L0
  input                                   pm_linkst_in_l0s,             //input from pm_active_ctrl indicating PM state in L0s
                
  output                                  ptm_gen_res_msg,                 
  output                                  ptm_gen_res_d_msg,                


  output                                  ptm_state_at_res_d                  //Next message sent will be Response D
);

  localparam TP = `TP;

  reg [3:0] responder_state;
  reg [3:0] res_next_state;
  reg       replay_set;
  reg       dup_set;

  wire      replay_or_dup_found;

  // Responder State machine

  localparam IDLE                     = 4'b0000;                //Idle
  localparam WAIT_FOR_REQUEST         = 4'b0001;                //PTM enableand Responder Capable bits set in PTM Capability header
  localparam SEND_RESPONSE            = 4'b0011;                //Send the Response type message
  localparam WAIT_FOR_REQUEST_2       = 4'b0101;                //Response was sent
  localparam CALC_PROP_DELAY          = 4'b0111;                //Calculate propagation delay (t3-t2)
  localparam SEND_RESPONSE_D          = 4'b1000;                // Send the Response D message


  assign ptm_state_at_res_d = (responder_state[3:0] >= WAIT_FOR_REQUEST_2);

  always@(posedge aux_clk or negedge non_sticky_rst_n)      //flag to state that the TLP is a replay
  begin 
    if(!non_sticky_rst_n) begin
      replay_set   <= #TP 0;

    end else  begin
      replay_set   <= #TP (responder_state == WAIT_FOR_REQUEST_2  && xdlh_retry_req)                                          ? 1 :
                          (responder_state == CALC_PROP_DELAY     && xdlh_retry_req)                                          ? 1 :
                          (responder_state == SEND_RESPONSE_D     && xdlh_retry_req)                                          ? 1 :
                          (responder_state == WAIT_FOR_REQUEST                                                              ) ? 0 : 
                          replay_set;

    end 
  end


  always@(posedge aux_clk or negedge non_sticky_rst_n)      //flag to state that the TLP is a duplicate
  begin 
    if(!non_sticky_rst_n) begin
      dup_set   <= #TP 0;

    end else  begin
      dup_set   <= #TP    (responder_state == WAIT_FOR_REQUEST_2  && rdlh_duplicate_tlp)                                          ? 1 :
                          (responder_state == CALC_PROP_DELAY     && rdlh_duplicate_tlp)                                          ? 1 :
                          (responder_state == SEND_RESPONSE_D     && rdlh_duplicate_tlp)                                          ? 1 :
                          (responder_state == WAIT_FOR_REQUEST                                                                  ) ? 0 : 
                          dup_set;

    end 
  end

  assign replay_or_dup_found = replay_set || xdlh_retry_req || dup_set || rdlh_duplicate_tlp;

  always@(posedge aux_clk or negedge non_sticky_rst_n) 
  begin 
    if(!non_sticky_rst_n) begin
      responder_state <= #TP IDLE;
               //if link is down or PTM disabled or the clock period changes go to IDLE (start of resync)
    end else if(!phy_link_up || !cfg_ptm_enabled || ptm_clock_period_change || pm_sel_aux_clk || !(pm_linkst_in_l0 || pm_linkst_in_l0s)) begin            //place holder
      responder_state <= #TP IDLE;

    end else begin
      responder_state[3:0] <= #TP res_next_state;
    end
  end

  always@(*) 
  begin 
 
      case (responder_state[3:0])

        IDLE:
          if(phy_link_up && cfg_ptm_enabled && cfg_ptm_responder_capable && !ptm_clock_period_change && !pm_sel_aux_clk)
            res_next_state = WAIT_FOR_REQUEST;
          else
            res_next_state = IDLE;

        WAIT_FOR_REQUEST:
          if(ptm_request_msg_rec)
            res_next_state = SEND_RESPONSE;
          else
            res_next_state = WAIT_FOR_REQUEST;

        SEND_RESPONSE:
          if (replay_or_dup_found || !ptm_status_context_valid) // if a replay or duplicate occurs go back to waiting for the first request
            res_next_state = WAIT_FOR_REQUEST;
          else 
            res_next_state = WAIT_FOR_REQUEST_2;

        WAIT_FOR_REQUEST_2:                     
          if (ptm_request_msg_rec && ptm_status_context_valid && !replay_or_dup_found)
            res_next_state = CALC_PROP_DELAY;              //permitted to send response D if it has historical timestamps and if there were no replays or duplicates

          else if(ptm_request_msg_rec)
            res_next_state = SEND_RESPONSE;

          else 
            res_next_state = WAIT_FOR_REQUEST_2;

        CALC_PROP_DELAY:                                      //calculate t3-t2
          res_next_state = SEND_RESPONSE_D;

        SEND_RESPONSE_D:                                                            //if duplicate or replay, restart the PTM dialog state
          res_next_state = (replay_or_dup_found) ? WAIT_FOR_REQUEST : 
                           WAIT_FOR_REQUEST_2;    

        default:
          res_next_state = IDLE;

      endcase
  end

                                            //MUST always at least send a response to a request message
  assign ptm_gen_res_msg = (responder_state[3:0]==SEND_RESPONSE) || 
                           (responder_state[3:0]==SEND_RESPONSE_D && (dup_set || rdlh_duplicate_tlp));

                                                                        //only send a Response D if not duplicate, Response should already be sent
  assign ptm_gen_res_d_msg = ((responder_state[3:0]==SEND_RESPONSE_D) && !dup_set && !rdlh_duplicate_tlp);  


  //aDoubleGen : assert property ( !(ptm_gen_res_msg && ptm_gen_res_d_msg) );


endmodule //ptm_responder_fsm 
