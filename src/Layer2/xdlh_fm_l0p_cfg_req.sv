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
// ---   $DateTime: 2024/01/08 11:48:14 $
// ---   $Revision: #6 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_fm_l0p_cfg_req.sv#6 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// L0P Link Width Configuration Master FSM
//
// Description: If L0P is enabled a port can initiate a link resize negotiation.
// The port requesting the link resize transmits L0P_Request DLLP's 
// until the link partner returns an L0P_Request_Ack or L0P_Request_Nak.
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"

module xdlh_fm_l0p_cfg_req 
  import cx_pl_pkg::l0p_dllp_struct;
  import cx_pl_pkg::L0P_Request;
  import cx_pl_pkg::L0P_Request_Ack;
  import cx_pl_pkg::L0P_Request_Nak;
  import cx_pl_pkg::L0P;
  import cx_pl_pkg::LINK_MANAGEMENT;
#(
  parameter TP = `TP
)(
  // -------------------------------------------------------------------------------------
  // Clock and Reset
  // -------------------------------------------------------------------------------------
  input                   core_clk,                 // Core clock
  input                   core_rst_n,               // Active low asynchronous reset
  // -------------------------------------------------------------------------------------
  // CDM Interface
  // -------------------------------------------------------------------------------------
  input                   cdm_l0p_enabled,          // Indicates that L0P is enabled for this port
  input                   cfg_hw_autowidth_dis,     // HW autonomous width disable  
  input                   cdm_xdlh_link_req,        // Request to resize the link
  input   [2 : 0]         cdm_xdlh_link_width,      // Target link width
  input                   cfg_l0p_priority,         // L0P Priority Request 
  input   [2 : 0]         current_data_rate,        // 0=running at gen1 rate (2.5 GT/s) (8b/10b)
                                                    // 1=running at gen2 rate (5.0 GT/s) (8b/10b) 
                                                    // 2=running at gen3 rate (8.0 GT/s) (128b/130b)
                                                    // 3=running at gen4 rate (16.0 GT/s)(128b/130b)
                                                    // 4=running at gen5 rate (32.0 GT/s)(128b/130b)
                                                    // 5=running at gen6 rate (64.0 GT/s)(1b/1b)
  output  logic           xdlh_cdm_link_ack,        // Acknowledge the CDM that the request is sent and ACKed, NAKed, or Abandoned.
  output  logic           xdlh_l0p_rejected,        // pulse to indicate that the l0p request is NAK'ed or Abandoned

  // -------------------------------------------------------------------------------------
  // LTSSM Interface 
  // -------------------------------------------------------------------------------------
  input                   smlh_l0p_capable,        // Layer1 L0P Capable
  input                   smlh_in_rcvry,           // Layer1 LTSSM In Recovery
  input                   smlh_xdlh_eios_rcvd,     // Layer1 received EIOSQ Ordered Set
  output  logic [4:0]     xdlh_smlh_link_width,    // requested link width
  input                   smlh_ltssm_l0p_ready,    // Ltssm is ready
  output  logic           xdlh_smlh_link_req,      // Link resize request
  output  logic           xdlh_smlh_enter_recovery,// Direct LTSSM to enter recovery
  input   [3:0]           smlh_l0p_link_mode,      // L0P negotiated link width 
  input   [5:0]           smlh_link_mode,          // Negotiated link width during Cfg state of LTSSM
  // -------------------------------------------------------------------------------------
  // L0P Timer Interface
  // -------------------------------------------------------------------------------------
  input                   l0p_1us_timeout,          // 1us Timeout indication from L0P timer
  input                   l0p_4us_timeout,          // 4us Timeout indication from L0P timer
  input                   l0p_8us_timeout,          // 8us Timeout indication from L0P timer
  input                   l0p_16us_timeout,         // 16us timeout indication from L0P timer
  output  logic           xdlh_l0p_en_timer,        // Enable the L0P watchdog timer
  // -------------------------------------------------------------------------------------
  // Flit Counter Interface
  // -------------------------------------------------------------------------------------
  input   [2 : 0]           xdlh_flit_cnt,            // Flit counter value
  output  logic             xdlh_en_flit_cnt,         // Enable Flit counter
  input                     xplh_l0p_dllps_count,     // Count Number of L0P Request DLLPs Sent
  // -------------------------------------------------------------------------------------
  // DLLP Transmit/Receive Interface
  // -------------------------------------------------------------------------------------
  input   l0p_dllp_struct rdlh_l0p_dllp,               // Received L0P DLLP Structure
  output  l0p_dllp_struct xdlh_l0p_cfg_dllp,           // Transmit L0P DLLP Structure
  output  logic           Request_is_initiated,        // Indicates if request is initiated
  input                   xdlh_smlh_link_req_responder,// Responder Ack request
  input                   l0p_dllp_ack                 // L0P Support DLLP has been sent by the DLLP generator
);

// L0P Support State
typedef enum {
  IDLE,
  ACTIVE,
  WAIT_1US,
  WAIT_4US,
  WAIT_16US,
  L0P_UDSIZE_REQ,
  WAIT_5FLITS,
  WAIT_DLLPs_SENT,
  WAIT_ACK_NAK,
  L0P_UDSIZE_NAK,
  L0P_UDSIZE_ACK,
  L0P_ABANDON
} l0p_cfg_state_e;

l0p_cfg_state_e next_state, state_r , previous_state;
logic [4:0] xdlh_smlh_link_width_map;
logic [1:0] req_sent;
logic [1:0] req_sent_r;
logic [1:0] xplh_l0p_dllps_count_r;
logic [3:0] cdm_xdlh_link_width_map;
logic       first_timeout_r;
logic       abandon_req;
logic       s_l0p_req_lower;
logic       r_l0p_req_lower;
logic       l0p_ignore_req;
logic       r_l0p_ignore_req;
logic       cfg_hw_autowidth_dis_r;
logic       cfg_hw_autowidth_dis_l;
logic       cfg_hw_autowidth_dis_p;
logic       cdm_l0p_enabled_r;
logic       cdm_l0p_enabled_l;
logic       cdm_l0p_enabled_p;
logic       ack_rec_during_wait_dllps;
logic       nak_rec_during_wait_dllps;
logic       xdlh_smlh_link_req_responder_latched;
logic       valid_ack_resp;
logic       valid_nak_resp;
logic       timeout;
logic       valid_eios;
logic       initiate_max_req;
logic       ignore_in_progrs_req;

// Ignore In progress request
assign ignore_in_progrs_req = cfg_hw_autowidth_dis_p || cdm_l0p_enabled_p || smlh_in_rcvry ;

// Initiate Upsize request with max link width
assign initiate_max_req = (cfg_hw_autowidth_dis_p || cdm_l0p_enabled_p) && !cdm_xdlh_link_req && (smlh_l0p_link_mode != smlh_link_mode[3:0]);

// Received a valid eios
assign valid_eios = smlh_xdlh_eios_rcvd && r_l0p_req_lower && !xdlh_smlh_link_req_responder_latched;

assign timeout = (current_data_rate== 3'b000 || current_data_rate==3'b001) ? l0p_8us_timeout : l0p_4us_timeout ;

// Received a valid ACK
assign valid_ack_resp = rdlh_l0p_dllp.valid && (rdlh_l0p_dllp.l0p_cmd == L0P_Request_Ack) && (rdlh_l0p_dllp.resp_pyld == xdlh_smlh_link_width [3:0]);

// Received a valid NAK
assign valid_nak_resp = rdlh_l0p_dllp.valid && (rdlh_l0p_dllp.l0p_cmd == L0P_Request_Nak) && (rdlh_l0p_dllp.resp_pyld == xdlh_smlh_link_width [3:0]);

// Determine if the request is for a lower link width that the current link width
// Encoding of 0000 is x16 so it cannot be lower than another request.
assign s_l0p_req_lower = (xdlh_l0p_cfg_dllp.link_width == smlh_l0p_link_mode)? 1'b0 :
                         (xdlh_l0p_cfg_dllp.link_width < smlh_l0p_link_mode);

// Consider simulatnous case only if request is initiated and being served.
always_ff @(posedge core_clk or negedge core_rst_n) begin : Request_is_initiated_proc
  if(!core_rst_n)
    Request_is_initiated<= #TP 1'b0;
  else if ((state_r == ACTIVE) && cdm_xdlh_link_req)
    Request_is_initiated<= #TP 1'b1;  
  else if (state_r inside {L0P_UDSIZE_ACK,L0P_UDSIZE_NAK,L0P_ABANDON}) 
    Request_is_initiated<= #TP 1'b0;  
end : Request_is_initiated_proc


//Link Width mapping between CDM and Layer1
always_comb begin : smlh_map_PROC 
            xdlh_smlh_link_width_map = 5'b00000;
    unique case(cdm_xdlh_link_width)
        3'b000: begin
            xdlh_smlh_link_width_map = 5'b00001;
        end
        3'b001: begin
            xdlh_smlh_link_width_map = 5'b00010;
        end
        3'b010: begin
            xdlh_smlh_link_width_map = 5'b00100;
        end
        3'b011: begin
            xdlh_smlh_link_width_map = 5'b01000;
        end
        default: begin
            xdlh_smlh_link_width_map = 5'b00000;
        end
    endcase
end : smlh_map_PROC 

//Check if the responder FSM is sending an Ack while there is an outstanding request 
always_ff @(posedge core_clk or negedge core_rst_n) begin : Request_in_progress
  if(!core_rst_n)
   xdlh_smlh_link_req_responder_latched <= #TP 1'b0;
  else if ((state_r inside {L0P_UDSIZE_REQ,WAIT_5FLITS,WAIT_DLLPs_SENT,WAIT_ACK_NAK}) && xdlh_smlh_link_req_responder)
   xdlh_smlh_link_req_responder_latched <= #TP 1'b1;
  else if ( state_r inside {L0P_UDSIZE_ACK,L0P_UDSIZE_NAK,L0P_ABANDON})
   xdlh_smlh_link_req_responder_latched <= #TP 1'b0;
end 

// Cannot use L0P to turn on lanes that have been disabled in Configuration
assign l0p_ignore_req = (xdlh_smlh_link_width_map > smlh_link_mode[4:0]);

always_ff @(posedge core_clk or negedge core_rst_n) begin : ignore_req_PROC
  if(!core_rst_n)
    r_l0p_ignore_req    <= #TP '0;
  else begin
    if(!cdm_xdlh_link_req)
      r_l0p_ignore_req  <= #TP '0;
    else if(l0p_ignore_req && cdm_xdlh_link_req)
      r_l0p_ignore_req  <= #TP '1;
  end
end : ignore_req_PROC

// Check if ACK is received during sending the request
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    ack_rec_during_wait_dllps <= #TP 1'b0;
  else begin
   if ((state_r == WAIT_DLLPs_SENT) && (valid_ack_resp || valid_eios ))
     ack_rec_during_wait_dllps <= #TP 1'b1;
    else if (state_r == ACTIVE) 
     ack_rec_during_wait_dllps <= #TP 1'b0;
  end
end

// Check if NAK is received during sending the request
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    nak_rec_during_wait_dllps <= #TP 1'b0;
  else begin
   if ((state_r == WAIT_DLLPs_SENT) && valid_nak_resp)
     nak_rec_during_wait_dllps <= #TP 1'b1;
    else if (state_r == ACTIVE) 
     nak_rec_during_wait_dllps <= #TP 1'b0;
  end
end

//Link Width mapping between CDM and Layer2
assign cdm_xdlh_link_width_map= xdlh_smlh_link_width_map [3:0];

// Next_state logic
always_comb begin : l0p_cfg_fsm_PROC 
  next_state = state_r;
  case (state_r)

    // Wait at least 1us untill LTSSM is ready to serve new requests
    WAIT_1US: begin
      if (l0p_1us_timeout || smlh_in_rcvry)
        next_state = ACTIVE;
      else if (ignore_in_progrs_req && cdm_xdlh_link_req)
        next_state = L0P_ABANDON;
      else if (initiate_max_req)
        next_state = L0P_UDSIZE_REQ;
      else
        next_state = WAIT_1US;
    end

    // Wait at least 4us untill LTSSM is ready to serve new requests
    WAIT_4US: begin
      if (l0p_4us_timeout || smlh_in_rcvry)
        next_state = ACTIVE;
      else if (ignore_in_progrs_req && cdm_xdlh_link_req)
        next_state = L0P_ABANDON;
      else if (initiate_max_req)
        next_state = L0P_UDSIZE_REQ;
      else
        next_state = WAIT_4US;
    end

    // If CDM requests link UP/down size 
    ACTIVE : begin
      if (initiate_max_req)
        next_state = L0P_UDSIZE_REQ;
      else if(cdm_xdlh_link_req && l0p_ignore_req)
        next_state = L0P_ABANDON;
      else if(cdm_xdlh_link_req && smlh_ltssm_l0p_ready)
        next_state = L0P_UDSIZE_REQ;
      else
        next_state = ACTIVE;
    end

    // Send the L0P Request DLLP to resize the link
    L0P_UDSIZE_REQ : begin
      if (ignore_in_progrs_req)
        next_state = L0P_ABANDON;
      else if(l0p_dllp_ack)
        next_state = WAIT_5FLITS;
      else
        next_state = L0P_UDSIZE_REQ;
    end

    // Send up to 3 identical Link Management DLLPs within 5 consecutive Flits
    WAIT_5FLITS : begin
      if (ignore_in_progrs_req)
        next_state = L0P_ABANDON;
      else if(l0p_dllp_ack && ((req_sent == 2) || ((req_sent >= 1) && (xdlh_flit_cnt == 4))))
        next_state = WAIT_DLLPs_SENT;
      else
        next_state = WAIT_5FLITS;
    end

    WAIT_DLLPs_SENT : begin
      if (cfg_hw_autowidth_dis_p || cdm_l0p_enabled_p || smlh_in_rcvry)
        next_state = L0P_ABANDON;
      else if (req_sent_r == xplh_l0p_dllps_count_r)
        next_state = WAIT_ACK_NAK;
      else
        next_state = WAIT_DLLPs_SENT;  
    end

    // Wait to receive L0P Request Ack or L0P Request Nak.
    // If no Ack/Nak within 4us/8us according to encoding rate -> restart the negotiation.
    // If no Ack/Nak within 4us/8us according to encoding rate for the second time -> abandon the request.
    // On link down size request if the requesting Port did not receive an Ack for the L0p request, but sees the Link Partner sending the EIOSQ Ordered Set, it must treat that as an Ack.
    // Except if responder FSM is sending an Ack while there is an outstanding request the smlh_xdlh_eios_rcvd should not be considered. 
    WAIT_ACK_NAK : begin
       if (ignore_in_progrs_req)
        next_state = L0P_ABANDON;
       else if((valid_ack_resp && !timeout) || valid_eios || ack_rec_during_wait_dllps)
         next_state = L0P_UDSIZE_ACK;
       else if((valid_nak_resp && !timeout) || nak_rec_during_wait_dllps)
         next_state = L0P_UDSIZE_NAK;
       else if(abandon_req)
         next_state = L0P_ABANDON;
       else if(timeout)
         next_state = L0P_UDSIZE_REQ;
       else
         next_state = WAIT_ACK_NAK;
    end

    L0P_ABANDON : begin
      if (initiate_max_req)
        next_state = L0P_UDSIZE_REQ;
      // Return the ack to CDM for ignored requests 
      else if(r_l0p_ignore_req && !cdm_xdlh_link_req)
        next_state = ACTIVE;
      // After abandoning a down/up size request wait at least 16us
      else if((previous_state == WAIT_ACK_NAK))
        next_state = WAIT_16US;
      // If request if abandoned after receving an ACK
      else if((previous_state == L0P_UDSIZE_ACK))
        next_state = ACTIVE;
      else if ((cfg_hw_autowidth_dis_l || !cdm_l0p_enabled_l) && (smlh_l0p_link_mode != smlh_link_mode[3:0]))
        next_state = L0P_UDSIZE_REQ;
      else if ((cfg_hw_autowidth_dis_l || !cdm_l0p_enabled_l) && (smlh_l0p_link_mode == smlh_link_mode[3:0]))
        next_state = ACTIVE; 
      else if (!smlh_in_rcvry)
        next_state = ACTIVE; 
      else 
        next_state = L0P_ABANDON;
    end

    WAIT_16US: begin
      if ((l0p_16us_timeout && smlh_ltssm_l0p_ready)|| smlh_in_rcvry)
        next_state = ACTIVE;
      else if (ignore_in_progrs_req && cdm_xdlh_link_req)
        next_state = L0P_ABANDON;
      else if (initiate_max_req)
        next_state = L0P_UDSIZE_REQ;
      else
        next_state = WAIT_16US;
    end

    L0P_UDSIZE_ACK : begin
      if(!cdm_xdlh_link_req) begin
        if (initiate_max_req)
         next_state = L0P_UDSIZE_REQ;
        else if ((current_data_rate inside {3'b000,3'b001}) && smlh_ltssm_l0p_ready) 
         next_state = WAIT_4US;
        else if ((current_data_rate > 3'b001) && smlh_ltssm_l0p_ready) 
         next_state = WAIT_1US;
      end else begin
        if (ignore_in_progrs_req)
         next_state = L0P_ABANDON;
        else
         next_state = L0P_UDSIZE_ACK;
        end
    end

    L0P_UDSIZE_NAK : begin
      if(!cdm_xdlh_link_req) begin
        if (initiate_max_req)
        next_state = L0P_UDSIZE_REQ;
        else
        next_state = ACTIVE;
      end else begin
       if (ignore_in_progrs_req)
        next_state = L0P_ABANDON;
       else
        next_state = L0P_UDSIZE_NAK;
       end
    end

    // Wait until L0P is enabled
    default : begin // IDLE
      if(cdm_l0p_enabled && smlh_l0p_capable)
        next_state = ACTIVE;
      else
        next_state = IDLE;
    end
  endcase
end : l0p_cfg_fsm_PROC

//Count the request L0P DLLPs sent
always_ff @(posedge core_clk or negedge core_rst_n) begin : DLLPs_out_count
  if(!core_rst_n)
    req_sent <= #TP '0;
  else if(!xdlh_l0p_cfg_dllp.valid)
    req_sent <= #TP '0;
  else if (xdlh_l0p_cfg_dllp.valid && l0p_dllp_ack)
    req_sent <= #TP req_sent + 1'b1;
  else
    req_sent <= #TP req_sent;
end : DLLPs_out_count

//Save the number of sent DLLPs
always_ff @(posedge core_clk or negedge core_rst_n) begin : DLLPs_sent_count
  if(!core_rst_n)
    req_sent_r <= #TP '0;
  else if (state_r == WAIT_5FLITS)
    req_sent_r <= #TP req_sent + 1'b1;
  else if (state_r == ACTIVE)
    req_sent_r <= #TP '0;
end : DLLPs_sent_count

// Count number of sent DLLPs by XPLH
always_ff @(posedge core_clk or negedge core_rst_n) begin 
  if(!core_rst_n)
    xplh_l0p_dllps_count_r <= #TP '0;
  else if ((state_r inside {WAIT_DLLPs_SENT,WAIT_5FLITS}) && xplh_l0p_dllps_count)
    xplh_l0p_dllps_count_r <= #TP xplh_l0p_dllps_count_r + 1'b1;
  else if (state_r == ACTIVE)
    xplh_l0p_dllps_count_r <= #TP '0;
end 

// Enable the Flit Counter
assign xdlh_en_flit_cnt = (state_r == WAIT_5FLITS);

// Direct LTSSM to enter recovery
assign xdlh_smlh_enter_recovery = (((state_r == L0P_UDSIZE_NAK) || ((state_r == WAIT_ACK_NAK) && abandon_req)) && (cfg_hw_autowidth_dis_l || !cdm_l0p_enabled_l))? 1'b1 : 1'b0;

// Latch the HAWD bit
always_ff @(posedge core_clk or negedge core_rst_n) begin : latch_hw_autowidth
  if(!core_rst_n) begin
    cfg_hw_autowidth_dis_l    <= #TP '0;
  end else if (cfg_hw_autowidth_dis) begin
    cfg_hw_autowidth_dis_l    <= #TP '1;
  end else if (state_r == ACTIVE) begin
    cfg_hw_autowidth_dis_l    <= #TP '0;
  end
end : latch_hw_autowidth

// Latch the L0P En bit
always_ff @(posedge core_clk or negedge core_rst_n) begin : latch_l0p_enable
  if(!core_rst_n) begin
    cdm_l0p_enabled_l         <= #TP '1;
  end else if (!cdm_l0p_enabled) begin
    cdm_l0p_enabled_l         <= #TP '0;
  end else if (state_r == ACTIVE) begin
    cdm_l0p_enabled_l         <= #TP '1;
  end
end : latch_l0p_enable

// Register HAWD bit
always_ff @(posedge core_clk or negedge core_rst_n) begin : register_hw_autowidth
  if(!core_rst_n) 
    cfg_hw_autowidth_dis_r    <= #TP '0;
  else 
    cfg_hw_autowidth_dis_r    <= #TP cfg_hw_autowidth_dis;
end : register_hw_autowidth

// Register L0P En bit
always_ff @(posedge core_clk or negedge core_rst_n) begin : register_l0p_enable
  if(!core_rst_n) 
    cdm_l0p_enabled_r         <= #TP '0;
  else 
    cdm_l0p_enabled_r         <= #TP cdm_l0p_enabled;
end : register_l0p_enable

// Generate a pulsed version from the hardware disable bit and l0p enable bit
assign cfg_hw_autowidth_dis_p = (state_r != IDLE) ? (cfg_hw_autowidth_dis && !cfg_hw_autowidth_dis_r): cfg_hw_autowidth_dis;
assign cdm_l0p_enabled_p      = (state_r != IDLE) ? (!cdm_l0p_enabled && cdm_l0p_enabled_r): cdm_l0p_enabled;


always_ff @(posedge core_clk or negedge core_rst_n) begin : Current_State_Logic
  if(!core_rst_n)
    state_r <= #TP IDLE;
  else
    state_r <= #TP next_state;
end : Current_State_Logic

// Previous state logic
always_ff @(posedge core_clk or negedge core_rst_n) begin : Previous_State_Logic
    if (!core_rst_n)
        previous_state            <= #TP IDLE;
    else
        previous_state            <= #TP state_r;
end : Previous_State_Logic

// Abandon the link width request if 4us timeout occurs for a second time during WAIT_ACK_NAK state
always_ff @(posedge core_clk or negedge core_rst_n) begin : abandon_PROC
  if(!core_rst_n)
    first_timeout_r <= #TP '0;
  else begin
    if(state_r inside  {L0P_ABANDON,ACTIVE})
      first_timeout_r <= #TP '0;
    else if( timeout && !(next_state inside {L0P_UDSIZE_ACK, L0P_UDSIZE_NAK, WAIT_1US, WAIT_4US}))
      first_timeout_r <= #TP '1;
  end
end : abandon_PROC

assign abandon_req = timeout && first_timeout_r;

// Enable the L0P Timer
assign xdlh_l0p_en_timer = (state_r inside {WAIT_ACK_NAK,WAIT_1US,WAIT_4US,WAIT_16US}) && (!cfg_hw_autowidth_dis_p && !cdm_l0p_enabled_p) && !(smlh_in_rcvry && (!(state_r inside {IDLE,ACTIVE})));

// Transmit L0P REQUEST
always_comb begin : l0p_cfg_dllp_PROC
  xdlh_l0p_cfg_dllp = '0;
  if(state_r inside {WAIT_5FLITS, L0P_UDSIZE_REQ}) begin
    xdlh_l0p_cfg_dllp.resp_pyld = 5'b00000;
// Width mapping between CDM/Layer1 and Layer2 DLLP
    xdlh_l0p_cfg_dllp.link_width = (cfg_hw_autowidth_dis_l || !cdm_l0p_enabled_l)? smlh_link_mode[3:0] : cdm_xdlh_link_width_map;
    xdlh_l0p_cfg_dllp.priority_bit=(cfg_hw_autowidth_dis_l || !cdm_l0p_enabled_l)? 1'b1 : cfg_l0p_priority;
    xdlh_l0p_cfg_dllp.l0p_cmd = L0P_Request;
    xdlh_l0p_cfg_dllp.link_mng_type = L0P;
    xdlh_l0p_cfg_dllp.dllp_type = LINK_MANAGEMENT;
    xdlh_l0p_cfg_dllp.valid = 1'b1;
  end
end : l0p_cfg_dllp_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin : l0p_req_lower_PROC
  if(!core_rst_n)
    r_l0p_req_lower <=  #TP '0;
  else begin
    if(state_r == ACTIVE)
      r_l0p_req_lower <= #TP '0;
    else if(xdlh_l0p_cfg_dllp.valid && s_l0p_req_lower)
      r_l0p_req_lower <= #TP '1;
  end
end : l0p_req_lower_PROC

// Send the requested link width to Layer1
always_ff @(posedge core_clk or negedge core_rst_n) begin : smlh_link_width_PROC
  if(!core_rst_n) begin
      xdlh_smlh_link_width <= #TP 5'h0;
  end else if((next_state == L0P_UDSIZE_REQ) && (cfg_hw_autowidth_dis_l || !cdm_l0p_enabled_l) )begin
      xdlh_smlh_link_width <= #TP smlh_link_mode[4:0];
  end else if(next_state == L0P_UDSIZE_REQ)begin
      xdlh_smlh_link_width <= #TP xdlh_smlh_link_width_map;
  end
end : smlh_link_width_PROC

// Send link width changes request to Layer1 in case of ACKed requests
always_comb begin 
    xdlh_smlh_link_req =  1'b0;
    if ((state_r == L0P_UDSIZE_ACK) && (cdm_xdlh_link_req || cfg_hw_autowidth_dis_l || !cdm_l0p_enabled_l) ) 
    xdlh_smlh_link_req =  1'b1;
end

// Send ACK to the CDM when the request is served (ACKed or NAKed)
always_comb begin
   xdlh_cdm_link_ack = 1'b0;
   if (state_r inside {L0P_UDSIZE_ACK,L0P_UDSIZE_NAK,L0P_ABANDON} && cdm_xdlh_link_req) 
   xdlh_cdm_link_ack = 1'b1;
end

always_comb begin
   xdlh_l0p_rejected = 1'b0;
   if (state_r inside {L0P_UDSIZE_NAK,L0P_ABANDON} && cdm_xdlh_link_req) 
   xdlh_l0p_rejected = 1'b1;
end

endmodule : xdlh_fm_l0p_cfg_req
