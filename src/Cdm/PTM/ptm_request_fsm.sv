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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/PTM/ptm_request_fsm.sv#8 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the Precision Time Measurement Extended Capability (PTM) registers. 
// --- This module is instantiated for each function across all functions.
// -----------------------------------------------------------------------------



`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module ptm_request_fsm
#(
    parameter INST                  = 0,                                // The uniquifying parameter for each port logic instance.
    parameter FUNC_NUM              = 0                                 // uniquifying parameter per function    
    ,parameter WF = 16
   )

  
                       (

  input                                   aux_clk,
  input                                   non_sticky_rst_n,

  input                                   phy_link_up,
  input                                   pm_sel_aux_clk,
  input                                   cfg_ptm_enabled,              //PTM Enable signal from PTM Header
  input                                   smlh_in_l0,

  input                                   radm_ptm_res_msg,             //PTM Response Message received, signal is a pulse from radm
  input                                   radm_ptm_res_d_msg,           //PTM ResponseD Message received, signal is a pulse from radm
  input                                   xdlh_ptm_request,             // PTM request message has been sent on wire, to start 100us timer
  input                                   xdlh_rbuf_replaying,          // Retry Event 
  input                                   xdlh_ptm_sot,                 // 
  input                                   rdlh_ptm_response,            // To check for duplicates
  input                                   rdlh_duplicate_tlp,           // 
  input                                   rdlh_ptm_sot,                 // 

  input                                   ptm_auto_update_en_reg,       //Automatic PTM Requester timing update signal from register
  input                                   ptm_auto_update_signal,       //Automatic PTM Requester timing update signal from top level           
  input                                   ptm_manual_update_reg,        //Manual PTM Requester timing update signal from register
  input                                   ptm_manual_update_pulse,      //Manual PTM Requester timing update signal signal from top level
  input                                   pm_linkst_in_l0,              //input from pm_active_ctrl indicating PM state in L0
  input                                   pm_linkst_in_l0s,             //input from pm_active_ctrl indicating PM state in L0s

  input [7+WF:0]                          ptm_clock_period,             //Per cycle clock period
  input                                   ptm_clock_period_change,
  input                                   ptm_link_speed_change,
  input                                   ptm_fast_timer,               //bit in control register to use fast timers for quicker times in debug mode
  input [7:0]                             ptm_long_timer,               //sets the auto update timer in millseconds

  output                                  ptm_calc_round_trip,          //Trigger to calculate intermediate step of (t4 - t1) - (t3 - t2)
  output                                  ptm_calc_update,              //Trigger to calculate update for PTM local clock
  output reg                              ptm_update_local_clk,         //Trigger to update PTM local clock 
  output                                  ptm_trigger_allowed,          // when system is not in the middle of an update a manual request may be made
  output reg                              ptm_context_valid,            //local clock context is valid
  output reg                              ptm_clock_updated,            //pulse to indicate clock was updated

  output                                  ptm_gen_req_msg,              //generate a PTM Request Message
  output                                  ptm_updating,                 //PTM Update is in progress

  output reg                              ptm_req_response_timeout,     //Pulse indicating PTM Request sent but no response after 100us
  output reg                              ptm_req_dup_rx,               //Pulse indicating Duplicate TLP received during PTM update process or response received during wait for next update
  output reg                              ptm_req_replay_tx             //Pulse indicating Replay TLP sent during PTM update process or Request sent during wait for next update
);


  localparam TP = `TP;

  reg [3:0]                               ptm_requester_state;
  reg [3:0]                               ptm_next_state;

  reg                                     ptm_timer_run;                //run signal for the 100us and 10ms timers
  wire                                    ptm_timer_1us;
  wire                                    ptm_timer_100us;
  wire                                    ptm_timer_1us_in_l0;
  wire                                    ptm_timer_100us_in_l0;
  wire                                    ptm_timer_10ms;
  wire                                    ptm_timer_re_zero;

  reg                                     replay_set;
  reg                                     dup_set;

  wire                                    ptm_req_response_timeout_int; //Pulse indicating PTM Request sent but no response after 100us
  wire                                    ptm_check_dup_replay;         //Signal indicating any duplicate or replay should cause requester state machine to go to invalid PTM Context states
  wire                                    ptm_req_dup_rx_int;           //Pulse indicating Duplicate TLP received during PTM update process or response received during wait for next update
  wire                                    ptm_req_replay_tx_int;        //Pulse indicating Replay TLP sent during PTM update process or Request sent during wait for next update

  reg                                     ptm_context_valid_int;

  wire                                    repeat_tlp;

  //////////////////////////////////////////////////////
  //
  //  requester_state machine
  //
  //////////////////////////////////////////////////////
   
  localparam INVALID_PTM_CONTEXT      = 4'b0000;    // Initial condition - Context Invalid
  localparam ISSUE_PTM_REQUEST        = 4'b0001;    // Send PTM request message
  localparam WAIT_FOR_RESPONSE        = 4'b0010;    // wait for any response, either Response or Response D
  localparam WAIT_MICROSEC_1          = 4'b0011;    // hold for 1us 
  localparam ISSUE_PTM_REQUEST_2      = 4'b0100;    // issue a second PTM request message. MUST have gotten at least 1 response or response D before
  localparam WAIT_FOR_RESPONSE_D      = 4'b0101;    // Wait for a response D message. If receive response go back and request again
  localparam RESPONSE_D_REC           = 4'b0110;    // Received response D message
  localparam CALC_RESULT              = 4'b0111;    // Calculate the result
  localparam VALID_CONTEXT            = 4'b1000;    // Valid context, wait here for [Long Timer] ms or manual update
  localparam WAIT_FOR_REQUEST_SENT    = 4'b1001;    //wait for the request to be sent out
  localparam WAIT_FOR_REQUEST_SENT_2  = 4'b1010;    //wait for the request to be sent out
  localparam WAIT_MICROSEC_2          = 4'b1011;    // hold for 1us 
  localparam INVALID_PTM_CONTEXT_WAIT = 4'b1100;    // Context Invalid - Wait for 100us timeout since last request sent to start next update cycle

  assign ptm_start_update = (ptm_manual_update_reg   ||       //Write to the manual update register (self clearing)
                             ptm_manual_update_pulse ||       //Manual update signal pulse from top level
                             ptm_auto_update_en_reg  ||       //Write to auto update enable register (not self clearing)
                             ptm_auto_update_signal           //Auto update signal level from top level
                            );

  assign ptm_request_active =         (ptm_requester_state == WAIT_FOR_RESPONSE ||
                                       ptm_requester_state == WAIT_FOR_RESPONSE_D ||
                                       ptm_requester_state == WAIT_FOR_REQUEST_SENT ||
                                       ptm_requester_state == WAIT_FOR_REQUEST_SENT_2 ||
                                       ptm_requester_state == ISSUE_PTM_REQUEST ||
                                       ptm_requester_state == ISSUE_PTM_REQUEST_2);

  always@(posedge aux_clk or negedge non_sticky_rst_n)      //flag to state that the TLP is a replay
  begin 
    if(!non_sticky_rst_n) begin
      replay_set   <= #TP 0;

    end else  begin
      replay_set   <= #TP ptm_check_dup_replay && xdlh_rbuf_replaying && xdlh_ptm_sot && !replay_set;

    end 
  end


  always@(posedge aux_clk or negedge non_sticky_rst_n)      //flag to state that the TLP is a replay
  begin 
    if(!non_sticky_rst_n) begin
      dup_set   <= #TP 0;

    end else  begin
      dup_set   <= #TP    ptm_check_dup_replay && rdlh_duplicate_tlp && !dup_set;

    end 
  end

  
  always@(posedge aux_clk or negedge non_sticky_rst_n) 
  begin 
    if(!non_sticky_rst_n) begin
      ptm_requester_state   <= #TP INVALID_PTM_CONTEXT;

              //state returns to invalid context if Link Down OR PTM Disabled OR AUX clock active OR Core Clock Rate changes OR Response Timeout OR Duplicate or Replay during update process
    end else if(!phy_link_up || !cfg_ptm_enabled) begin  
        ptm_requester_state   <= #TP INVALID_PTM_CONTEXT;
    end else if(pm_sel_aux_clk || !(pm_linkst_in_l0 || pm_linkst_in_l0s) ||ptm_clock_period_change || (ptm_link_speed_change && ptm_updating) || repeat_tlp || ptm_req_response_timeout_int) begin  
      if (!ptm_req_response_timeout_int && (ptm_request_active || (ptm_next_state==INVALID_PTM_CONTEXT_WAIT))) //Continue to wait for response timeout if a request is active
        ptm_requester_state   <= #TP INVALID_PTM_CONTEXT_WAIT;        
      else
        ptm_requester_state   <= #TP INVALID_PTM_CONTEXT;
    end else begin
      ptm_requester_state[3:0] <= #TP ptm_next_state;
    end 
  end  

  always@(*)
  begin 
      case (ptm_requester_state[3:0])

        INVALID_PTM_CONTEXT_WAIT:     //Context is Invalid, request issued, waiting for 100us timeout from last request sent before starting update cycle
          if((ptm_req_response_timeout_int) || (radm_ptm_res_msg || radm_ptm_res_d_msg)) // PTM Response timeout or a response arrives
            ptm_next_state = INVALID_PTM_CONTEXT;
          else
            ptm_next_state = INVALID_PTM_CONTEXT_WAIT;

        INVALID_PTM_CONTEXT:          //Initial state, Context is Invalid, and 1us since last Reponse has passed and the PM link state is in L0 or L0s
          if(ptm_start_update && phy_link_up && cfg_ptm_enabled && !pm_sel_aux_clk && (pm_linkst_in_l0 || pm_linkst_in_l0s)) 
            ptm_next_state = WAIT_MICROSEC_1;
          else
            ptm_next_state = INVALID_PTM_CONTEXT;

         WAIT_MICROSEC_1:                //Wait for at least 1 microsecond (spec defined)
          if (ptm_timer_1us_in_l0)           //permitted to Request PTM Master Time only when PTM Enabled, when PM link state is L0 and 1us after last response
            ptm_next_state = ISSUE_PTM_REQUEST;
          else
            ptm_next_state = WAIT_MICROSEC_1;
          
        ISSUE_PTM_REQUEST:            //Send PTM Request message
            ptm_next_state = WAIT_FOR_REQUEST_SENT;

        WAIT_FOR_REQUEST_SENT:  
          if(xdlh_ptm_request)         //if the request has been sent
            ptm_next_state = WAIT_FOR_RESPONSE;
          else
            ptm_next_state = WAIT_FOR_REQUEST_SENT;

        WAIT_FOR_RESPONSE:            //Wait for either Response or ResponseD
          if(radm_ptm_res_msg || radm_ptm_res_d_msg)    //lock up protection, need to continue if 1st message is ResponseD
            ptm_next_state = WAIT_MICROSEC_2;
          else
            ptm_next_state = WAIT_FOR_RESPONSE;

        WAIT_MICROSEC_2:                //Wait for at least 1 microsecond (spec defined)
          if (ptm_timer_1us_in_l0)           //permitted to Request PTM Master Time only when PTM Enabled, when PM link state is L0 and 1us after last response
            ptm_next_state = ISSUE_PTM_REQUEST_2;
          else
            ptm_next_state = WAIT_MICROSEC_2;

        ISSUE_PTM_REQUEST_2:          //Issue 2nd Request message to get Response D 
            ptm_next_state = WAIT_FOR_REQUEST_SENT_2;

        WAIT_FOR_REQUEST_SENT_2:
          if(xdlh_ptm_request)        //Wait until the request has been sent
            ptm_next_state = WAIT_FOR_RESPONSE_D;
          else
            ptm_next_state = WAIT_FOR_REQUEST_SENT_2;     
          
        WAIT_FOR_RESPONSE_D:          //Wait for the ResponseD
          if(radm_ptm_res_d_msg)
            ptm_next_state = RESPONSE_D_REC;
          else if(radm_ptm_res_msg)                         //if not ResponseD send another request after waiting 1us
            ptm_next_state = WAIT_MICROSEC_2;
          else
            ptm_next_state = WAIT_FOR_RESPONSE_D;

        RESPONSE_D_REC:               //Calculate 1st part of Result Round Trip ((t4 - t1) - Propagation Delay )
          ptm_next_state = CALC_RESULT;

        CALC_RESULT:                  //Calculate 2nd part of Result, Adjust value = Local_clk + (Master Time - Round Trip/2 ) - T1             
          ptm_next_state = VALID_CONTEXT; 

        VALID_CONTEXT:        //Local Clock time context is now valid
          if((ptm_timer_10ms && (ptm_auto_update_en_reg || ptm_auto_update_signal)) ||        //10 ms timeout with auto update reg or signal enabled 
             ((ptm_manual_update_reg || ptm_manual_update_pulse)) ||                          //manual update pulse or reg write
             (!ptm_timer_run && (ptm_auto_update_en_reg || ptm_auto_update_signal)))          //auto update signal or reg transition 0 to 1
            ptm_next_state = WAIT_MICROSEC_2;
          else 
            ptm_next_state = VALID_CONTEXT;
          

        default
          ptm_next_state = INVALID_PTM_CONTEXT;

      endcase 
  end    

  always@(posedge aux_clk or negedge non_sticky_rst_n) 
  begin 
    if(!non_sticky_rst_n) begin
      ptm_context_valid_int     <= #TP 0;   
      ptm_context_valid         <= #TP 0;   //Top Level signal indication that Requester Local Clock context is now valid as defined in Spec
    end else begin                  
      ptm_context_valid_int     <= #TP (ptm_requester_state[3:0]==CALC_RESULT) ? 1'b1 : 
                               ((ptm_requester_state[3:0]==INVALID_PTM_CONTEXT) || (ptm_requester_state[3:0]==INVALID_PTM_CONTEXT_WAIT)) ? 1'b0 : 
                                ptm_context_valid_int;
      ptm_context_valid         <= #TP ptm_context_valid_int; //delay of 1 clock cycle to align the output signal assertion with the PTM local clock update
    end
  end


  always@(posedge aux_clk or negedge non_sticky_rst_n) 
  begin 
    if(!non_sticky_rst_n) begin
      ptm_update_local_clk  <= #TP 0;    //Pulse indication to update Requester Local Clock
      ptm_clock_updated     <= #TP 0;    //Top Level pulse indication that Requester Local Clock has been updated
    end else begin                       //Pulse will align with rising edge of ptm_context_valid_int signal
      ptm_update_local_clk  <= #TP ptm_calc_update;
      ptm_clock_updated     <= #TP ptm_update_local_clk; //delay of 1 clock cycle to align the output signal assertion with the PTM local clock update
    end
  end

  // Register top-level outputs for timing purposes
   always@(posedge aux_clk or negedge non_sticky_rst_n) 
  begin 
    if(!non_sticky_rst_n) begin
      ptm_req_response_timeout <= #TP 0;
      ptm_req_dup_rx           <= #TP 0;
      ptm_req_replay_tx        <= #TP 0;
    end else begin
      ptm_req_response_timeout <= #TP ptm_req_response_timeout_int;
      ptm_req_dup_rx           <= #TP ptm_req_dup_rx_int;
      ptm_req_replay_tx        <= #TP ptm_req_replay_tx_int;
    end
  end
                                      
  assign ptm_gen_req_msg      = ptm_requester_state[3:0]== ISSUE_PTM_REQUEST ||       //generate a request message
                                ptm_requester_state[3:0]== ISSUE_PTM_REQUEST_2;                                      

  assign ptm_trigger_allowed  = ((ptm_requester_state[3:0]==VALID_CONTEXT || 
                                  ptm_requester_state[3:0]==INVALID_PTM_CONTEXT) && ptm_timer_1us_in_l0 &&
                                  (pm_linkst_in_l0 || pm_linkst_in_l0s)); //a trigger is allowed if update not already in progress, & not waiting 100us since request & 1us since response & in L0 & PM link state L0 or L0s

  assign ptm_calc_round_trip  = ptm_requester_state[3:0]==RESPONSE_D_REC;     //calculate the Round Trip when a Response D has been received

  assign ptm_calc_update      = ptm_requester_state[3:0]==CALC_RESULT;    //Calculate the requester clock update value
 
  assign ptm_timer_re_zero = (  ptm_requester_state[3:0]==INVALID_PTM_CONTEXT ||        //Rezero on an invalid context
                                ptm_requester_state[3:0]== WAIT_FOR_REQUEST_SENT ||     // or sending a request message
                                ptm_requester_state[3:0]== WAIT_FOR_REQUEST_SENT_2 ||
                                ptm_requester_state[3:0]== ISSUE_PTM_REQUEST ||         // or if a PTM Request was issued
                                ptm_requester_state[3:0]== ISSUE_PTM_REQUEST_2
                             ); 

  assign ptm_updating = (ptm_requester_state[3:0]!=VALID_CONTEXT && 
                         ptm_requester_state[3:0]!=INVALID_PTM_CONTEXT && ptm_requester_state[3:0]!=INVALID_PTM_CONTEXT_WAIT);   //PTM dialog in progress

  assign ptm_req_response_timeout_int = ptm_timer_100us_in_l0 && ((ptm_requester_state==WAIT_FOR_RESPONSE) ||        //PTM Response timeout when waiting for response
                                                              (ptm_requester_state==WAIT_FOR_RESPONSE_D) ||
                                                              (ptm_requester_state==INVALID_PTM_CONTEXT_WAIT)); 

  assign ptm_check_dup_replay = (ptm_updating && ptm_requester_state[3:0]!=WAIT_MICROSEC_1) || ptm_update_local_clk; //Any duplicate or replay in these states will cause a transition to invalid PTM Context states

  assign ptm_req_dup_rx_int = (ptm_requester_state==VALID_CONTEXT) && !ptm_update_local_clk ?  // VALID_CONTEXT except first cycle, following CALC_RESULT
                              (cfg_ptm_enabled && rdlh_ptm_response) :                         //If PTM update complete then any PTM response must be a duplicate
                               dup_set;                                                        //otherwise signal a duplicate in any of the states prior to VALID_CONTEXT and after WAIT_MICROSEC_1

  assign ptm_req_replay_tx_int = (ptm_requester_state==VALID_CONTEXT) && !ptm_update_local_clk ?  // VALID_CONTEXT except first cycle, following CALC_RESULT
                                 (cfg_ptm_enabled && xdlh_ptm_request) :                          //If PTM update complete then any PTM request must be a replay
                                  replay_set;                                                     //otherwise signal a replay in any of the states prior to VALID_CONTEXT and after WAIT_MICROSEC_1

  assign repeat_tlp = ptm_req_dup_rx_int || ptm_req_replay_tx_int; //Repeat TLP is a Duplicate or Replay TLP.

  always@(posedge aux_clk or negedge non_sticky_rst_n) 
  begin 
    if(!non_sticky_rst_n) begin
      ptm_timer_run   <= #TP 1'b0;

    end else begin           //timer starts if either 1st or 2nd request message has been sent
      ptm_timer_run   <= #TP ((ptm_requester_state[3:0]== WAIT_FOR_RESPONSE) || (ptm_requester_state[3:0]== WAIT_FOR_RESPONSE_D) || 
                             //timer runs if a PTM request was issued and PTM context went invalid
                              (ptm_requester_state[3:0]== INVALID_PTM_CONTEXT_WAIT))                                                              ? 1'b1 :

                              //timer stops on a Valid Context AND 1us has passed AND the auto enable signal AND register are NOT set
                              (ptm_requester_state[3:0]== VALID_CONTEXT && (!ptm_auto_update_en_reg && !ptm_auto_update_signal) && ptm_timer_1us) ? 1'b0 :
                              
                              ptm_timer_run;
    end
  end


ptm_timer
                       //timer performs 100us timeout check and auto update timer trigger (ie 10ms)
u_ptm_requester_timer(

  .non_sticky_rst_n             (non_sticky_rst_n),
  .aux_clk                      (aux_clk),

  .ptm_timer_run                (ptm_timer_run),
  .ptm_timer_re_zero            (ptm_timer_re_zero),
  .ptm_clock_period             (ptm_clock_period),
  .ptm_fast_timer               (ptm_fast_timer),
  .ptm_long_timer               (ptm_long_timer),

  .ptm_timer_100us              (ptm_timer_100us),
  .ptm_timer_10ms               (ptm_timer_10ms)
);

assign ptm_timer_100us_in_l0 = ptm_timer_100us & smlh_in_l0;

ptm_timer_1micro
                //spec defined 1us timer from reception of Response to sending of next Request
u_ptm_requester_timer_1us
(
  .non_sticky_rst_n             (non_sticky_rst_n),
  .aux_clk                      (aux_clk),

  .ptm_timer_re_zero            (radm_ptm_res_msg || radm_ptm_res_d_msg),   //Re-zero 1us timer on reception of either a Response or Response D
  .ptm_clock_period             (ptm_clock_period),

  .ptm_timer_1us                (ptm_timer_1us)
);

assign ptm_timer_1us_in_l0 = ptm_timer_1us & smlh_in_l0;
  


endmodule //ptm_request_fsm 
