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
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_fm_l0p_cfg_rsp.sv#6 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// L0P Link Configure Slave FSM
//
// Description: This FSM is responsible for generating the L0P Request Ack or L0P Request Nak
// response to link resize requests received as L0P_Request DLLP's.
//
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"

module xdlh_fm_l0p_cfg_rsp 
  import cx_pl_pkg::l0p_dllp_struct;
  import cx_pl_pkg::L0P_Request;
  import cx_pl_pkg::L0P_Request_Ack;
  import cx_pl_pkg::L0P_Request_Nak;
  import cx_pl_pkg::L0P;
  import cx_pl_pkg::LINK_MANAGEMENT;
#(
  parameter TP = `TP
)
                            (
  // -------------------------------------------------------------------------------------
  // Clock and Reset
  // -------------------------------------------------------------------------------------
  input                   core_clk,                 // Core clock
  input                   core_rst_n,               // Active low asynchronous reset
  // -------------------------------------------------------------------------------------
  // CDM Interface
  // -------------------------------------------------------------------------------------
  input                   cfg_l0p_priority,         // L0P Priority Request 
  input                   cfg_upstream_port,        // upstream port
  input                   cfg_hw_autowidth_dis,     // HW autonomous width disable  
  input                   cdm_l0p_enabled,          // Indicates that L0P is enabled for this port
  input                   cdm_xdlh_link_req,        // Request to resize the link
  input   [2 : 0]         cdm_xdlh_link_width,      // Target link width
  // -------------------------------------------------------------------------------------
  // LTSSM Interface 
  // -------------------------------------------------------------------------------------
  input   [3:0]           smlh_l0p_link_mode,       // Indicate the active lanes and final negotiated link width
  input   [5:0]           smlh_link_mode,           // Negotiated link width during Cfg state of LTSSM
  input                   req_to_l1,                // Set to 1 when a request is being sent to L1 either from request FSM
  output logic            xdlh_smlh_link_req,       // Send ACK to SMLH
  output logic [4:0]      xdlh_smlh_link_width,     // requested link width
  input                   smlh_ltssm_l0p_ready,     // Indication that the OS negotiation for l0p in Layer1 has completed
  input                   smlh_in_rcvry,            // Layer1 LTSSM In Recovery
  // -------------------------------------------------------------------------------------
  // DLLP Transmit/Receive Interface
  // -------------------------------------------------------------------------------------
  input   l0p_dllp_struct rdlh_l0p_dllp,            // Received L0P DLLP Structure
  output  l0p_dllp_struct xdlh_l0p_cfg_dllp,        // Transmit L0P DLLP Structure
  input                   Request_is_initiated,     // Indicates if request is initiated
  input                   rdlh_xdlh_fm_dllp_valid,  // Valid DLLP data
  input                   xplh_l0p_dllps_count,
  input                   l0p_dllp_ack              // L0P Support DLLP has been sent by the DLLP generator
);

// L0P Support State
typedef enum {
  IDLE,
  L0P_REQ_ACK,
  L0P_REQ_NAK,
  WAIT_DLLP_SENT,
  L0P_REQ_IGNORE
} l0p_cfg_state_e;

l0p_cfg_state_e next_state, state_r,previous_state;
logic       s_l0p_req_nak;
logic [3:0] cdm_xdlh_link_width_map;
logic [3:0] resp_pyld;
logic       s_l0p_req_lower;
logic       s_l0p_rec_lower_than_req;
logic [4:0] s_smlh_link_width;
logic [3:0] max_link_width;
logic       identical_req;
logic       rplh_flit_count_en;
logic       valid_current_request;
logic [2:0] rplh_flit_count;
l0p_dllp_struct previous_req; 

always_comb begin : Link_width_mapping
            cdm_xdlh_link_width_map = 4'b0000;
    unique case(cdm_xdlh_link_width)
        3'b000: begin
            cdm_xdlh_link_width_map = 4'b0001;
        end
        3'b001: begin
            cdm_xdlh_link_width_map = 4'b0010;
        end
        3'b010: begin
            cdm_xdlh_link_width_map = 4'b0100;
        end
        3'b011: begin
            cdm_xdlh_link_width_map = 4'b1000;
        end
        default: begin 
            cdm_xdlh_link_width_map = 4'b0000;
        end
    endcase
end : Link_width_mapping

// Received a valid L0P request
assign valid_current_request = rdlh_l0p_dllp.valid && (rdlh_l0p_dllp.l0p_cmd == L0P_Request);


// Received Identical request to the previous
assign identical_req = rplh_flit_count_en && valid_current_request && (previous_req == rdlh_l0p_dllp) && !smlh_in_rcvry;

// Flit counter to check every 5 flits
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    rplh_flit_count_en <= #TP 1'b0;
  else if (valid_current_request && (state_r == IDLE) && (rplh_flit_count==0))
    rplh_flit_count_en <= #TP 1'b1;
  else if ((rplh_flit_count==4) || smlh_in_rcvry)
    rplh_flit_count_en <= #TP 1'b0;
end


// Determine if the request is for a lower link width that the current link width
// Encoding of 0000 is x16 so it cannot be lower than another request.
assign s_l0p_req_lower = (smlh_l0p_link_mode == rdlh_l0p_dllp.link_width) ? 1'b0 : 
                         (rdlh_l0p_dllp.link_width < smlh_l0p_link_mode);

// Received request is lower than the requested one
// Encoding of 0000 is x16 so it cannot be lower than another request.
assign s_l0p_rec_lower_than_req = (cdm_xdlh_link_width_map == rdlh_l0p_dllp.link_width)  ? 1'b0 :
                                  (rdlh_l0p_dllp.link_width < cdm_xdlh_link_width_map);

// Maximum negotiated link width
assign max_link_width= smlh_link_mode[3:0];

//NAK Conditions:
//---------------
//  1 A Port is permitted to Nak an L0p Request for a lower width than the current width if L0p.Priority is not set.
//  2 If the Hardware Autonomous Width Disable bit in the Link Control register is set to 1b, a Port Must not request any down-size.
//  3 If both Ports are simultaneously requesting link width change,
//    If both requests have L0p.Priority set, the one with the lower width wins.
//    If one request has L0p.Priority set, it wins. 
//    If neither side has L0p.Priority set, the one with the higher width wins.
assign s_l0p_req_nak = (!cdm_xdlh_link_req && s_l0p_req_lower && !rdlh_l0p_dllp.priority_bit) || ((cfg_hw_autowidth_dis || !cdm_l0p_enabled) && (rdlh_l0p_dllp.link_width != max_link_width))
|| ((Request_is_initiated) && ((rdlh_l0p_dllp.priority_bit && cfg_l0p_priority && !s_l0p_rec_lower_than_req && !(cdm_xdlh_link_width_map == rdlh_l0p_dllp.link_width))
||(!cfg_upstream_port && rdlh_l0p_dllp.priority_bit && cfg_l0p_priority && (rdlh_l0p_dllp.link_width == cdm_xdlh_link_width_map))
|| (!cfg_upstream_port && !rdlh_l0p_dllp.priority_bit && !cfg_l0p_priority && (rdlh_l0p_dllp.link_width == cdm_xdlh_link_width_map))
||(!rdlh_l0p_dllp.priority_bit && cfg_l0p_priority)
||(!rdlh_l0p_dllp.priority_bit && !cfg_l0p_priority && s_l0p_rec_lower_than_req)));


always_comb begin : l0p_sup_fsm_PROC 
  next_state = state_r;

  case (state_r)

    // If the LTSSM entered recovery return to IDLE
    // If the L0P Request Ack DLLP is sent return to IDLE
    L0P_REQ_ACK : begin
     if (smlh_in_rcvry)
        next_state = IDLE;
     else if (l0p_dllp_ack)
        next_state = WAIT_DLLP_SENT;
     else
        next_state = L0P_REQ_ACK;
    end

    // If the LTSSM entered recovery return to IDLE
    // If the L0P Request Nak DLLP is sent return to ACTIVE
    L0P_REQ_NAK : begin
      if (smlh_in_rcvry || l0p_dllp_ack)
        next_state = IDLE;
      else
        next_state = L0P_REQ_NAK;
      end

    WAIT_DLLP_SENT: begin
      if (smlh_in_rcvry || xplh_l0p_dllps_count) 
        next_state = IDLE;
     else
        next_state = WAIT_DLLP_SENT;
    end

    // Request is Ignored
    L0P_REQ_IGNORE : begin
       next_state = IDLE;
    end

    default : begin // IDLE
        if (valid_current_request) begin //valid_current_request
         if (req_to_l1 && (rdlh_l0p_dllp.link_width == cdm_xdlh_link_width_map))
             next_state = L0P_REQ_IGNORE;
        // Generate same response
         else if (identical_req) begin
            if (previous_state==L0P_REQ_ACK)
                next_state = IDLE;
            else 
                next_state = previous_state;
         end else begin // Generate new response
            if(s_l0p_req_nak || ((rdlh_l0p_dllp.link_width == smlh_l0p_link_mode) && (smlh_l0p_link_mode == max_link_width)))
                next_state = L0P_REQ_NAK;
            else if((rdlh_l0p_dllp.link_width == smlh_l0p_link_mode) && (smlh_l0p_link_mode != max_link_width))
                next_state = L0P_REQ_IGNORE;
            else if(smlh_ltssm_l0p_ready)
                next_state = L0P_REQ_ACK;
            else 
                next_state = L0P_REQ_IGNORE;
         end
        end else //!valid_current_request
               next_state = IDLE;
    end //IDLE

  endcase
end : l0p_sup_fsm_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    state_r <= #TP IDLE;
  else
    state_r <= #TP next_state;
end

// Save previous request and response
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n) begin
    previous_req   <= #TP '0;
    previous_state <= #TP IDLE;
  end
  else if ((next_state inside {L0P_REQ_ACK,L0P_REQ_NAK,L0P_REQ_IGNORE}) && valid_current_request) begin
    previous_req   <= #TP rdlh_l0p_dllp;
    previous_state <= #TP next_state;
  end
  else if (!rplh_flit_count_en) begin
    previous_req   <= #TP '0;
    previous_state <= #TP IDLE;
  end
end

always_ff @(posedge core_clk or negedge core_rst_n) begin : l0p_flit_cnt_PROC
  if(!core_rst_n) begin
    rplh_flit_count <= #TP '0;
  end else begin
    if(rplh_flit_count_en) begin
      if(rdlh_xdlh_fm_dllp_valid && (rplh_flit_count <= 4))
        rplh_flit_count <= #TP rplh_flit_count + 1;
    end else begin
      rplh_flit_count <= #TP '0;
    end
  end
end : l0p_flit_cnt_PROC

// Send the request to Layer1
always_ff @(posedge core_clk or negedge core_rst_n) begin 
  if(!core_rst_n) begin
    xdlh_smlh_link_req    <= #TP 1'b0;
    xdlh_smlh_link_width  <= #TP '0;
  end else if((state_r == WAIT_DLLP_SENT) && xplh_l0p_dllps_count) begin
    xdlh_smlh_link_req    <= #TP 1'b1;
    xdlh_smlh_link_width  <= #TP s_smlh_link_width;
  end else begin
    xdlh_smlh_link_req    <= #TP 1'b0;
    xdlh_smlh_link_width  <= #TP xdlh_smlh_link_width;
  end
end 

// Requested Link Width Encoding for Layer1
always_comb begin
   s_smlh_link_width = xdlh_smlh_link_width;
   if ((state_r == WAIT_DLLP_SENT) && xplh_l0p_dllps_count) begin
     unique case(resp_pyld)
        4'b0001: begin
            s_smlh_link_width = 5'b00001;
        end
        4'b0010: begin
            s_smlh_link_width = 5'b00010;
        end
        4'b0100: begin
            s_smlh_link_width = 5'b00100;
        end
        4'b1000: begin
            s_smlh_link_width = 5'b01000;
        end
        default: begin
            s_smlh_link_width = 5'b00000;
        end
     endcase
   end 
end 

// FSM Output Drivers
// Transmit L0P Request ACK/NAK
always_comb begin
    xdlh_l0p_cfg_dllp='0;
  if(state_r inside {L0P_REQ_ACK, L0P_REQ_NAK}) begin
    xdlh_l0p_cfg_dllp.link_width = 4'h0;
    xdlh_l0p_cfg_dllp.l0p_cmd = (state_r == L0P_REQ_ACK) ? L0P_Request_Ack : L0P_Request_Nak;
    xdlh_l0p_cfg_dllp.priority_bit=1'b0;
    xdlh_l0p_cfg_dllp.link_mng_type = L0P;
    xdlh_l0p_cfg_dllp.dllp_type = LINK_MANAGEMENT;
    xdlh_l0p_cfg_dllp.valid = 1'b1;
    xdlh_l0p_cfg_dllp.resp_pyld = resp_pyld;
  end
end 

always_ff @(posedge core_clk or negedge core_rst_n) begin 
  if(!core_rst_n) begin
    resp_pyld     <= #TP 4'b0000;
  end else if (state_r == IDLE) begin
    resp_pyld  <= #TP rdlh_l0p_dllp.link_width;
  end
end 

endmodule : xdlh_fm_l0p_cfg_rsp
