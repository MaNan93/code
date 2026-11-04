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
// --- RCS information:
// ---   $DateTime: 2023/06/26 08:32:07 $
// ---   $Revision: #7 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mst_link_ctrl.sv#7 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// DWC_cxl_mst_link_ctrl - Manages the link control for corresponding channels - Low power FSM state 
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

`include "CXL/svif/DWC_cxl_clk_rst_if.svh"

module DWC_cxl_mst_link_ctrl
  import DWC_cxl_pkg::*;
#(
     parameter TP = `TP
) (
    input                           clk                 ,
    input                           rst_n               ,
    output  logic                   cxl_mst_req         ,
    input                           cxl_mst_ack         ,
    input                           cxl_rx_active_req   ,
    input                           cxl_rx_dl_idle      , // CXL RX Data Link Layer Idle
    input                           cxl_rx_tl_pending   , // RX TL Pending Transaction Indication
    output  logic                   cxl_rx_link_idle    , // RX Link Deinitialization Acknowledge
    output  logic                   ch_msg_halt         , 
    output  logic                   nullify_crd         , //nullify_crd & run_crd_cnt, nullify_crd is checked first then run_crd_cnt
    output  logic                   run_crd_cnt     
);

parameter CXL_MST_LINK_IDLE         =   5'b00001;
parameter CXL_MST_LINK_INIT         =   5'b00010;
parameter CXL_MST_LINK_RUN          =   5'b00100;
parameter CXL_MST_LINK_DEINIT_MST   =   5'b01000;
parameter CXL_MST_LINK_DEINIT_SLV   =   5'b10000; 

parameter MST_REQ_HALT_DELAY        =  2;

logic [4:0] curr_state      ;
logic [4:0] next_state      ;
logic       next_cxl_mst_req;
logic       cxl_mst_ack_q   ;
logic [1:0] halt_dly_cnt    ;
logic [1:0] n_halt_dly_cnt  ;
logic       clr_halt_dly_cnt;
logic       inc_halt_dly_cnt;

assign cxl_rx_link_idle =  (curr_state == CXL_MST_LINK_IDLE) || (((curr_state == CXL_MST_LINK_INIT) && !cxl_rx_active_req )  && !cxl_rx_tl_pending);

always_comb begin 
   if(clr_halt_dly_cnt)       n_halt_dly_cnt = 0;
   else if(inc_halt_dly_cnt)  n_halt_dly_cnt = halt_dly_cnt + 1'b1;
   else                       n_halt_dly_cnt = 0;
end
always_ff @(posedge clk or negedge rst_n) begin 
  if (!rst_n) begin
   curr_state   <= # TP CXL_MST_LINK_IDLE;
   cxl_mst_req  <= # TP 1'b0             ;
   cxl_mst_ack_q<= # TP 1'b0             ;
   halt_dly_cnt <= # TP 2'h0             ;
  end else begin
   curr_state   <= # TP next_state       ;
   cxl_mst_req  <= # TP next_cxl_mst_req ;
   cxl_mst_ack_q<= # TP cxl_mst_ack      ;
   halt_dly_cnt <= # TP n_halt_dly_cnt   ;
  end
end 
always_comb begin 
            next_state          = curr_state;
            next_cxl_mst_req    = cxl_mst_req;
            ch_msg_halt         = 1'b0;
            nullify_crd         = 1'b0;
            run_crd_cnt         = 1'b0;
            inc_halt_dly_cnt    = 1'b0;
            clr_halt_dly_cnt    = 1'b0;
  unique case(curr_state)
    CXL_MST_LINK_IDLE: begin
        // If RX datapath activation is requested by Link vLSM
        if (cxl_rx_active_req) begin
            next_state          = CXL_MST_LINK_INIT;
            next_cxl_mst_req    = 1'b1;         
        end
    end
    CXL_MST_LINK_INIT: begin
        // Wait for cxl_mst_ack from the application acknowledging RX initialization request
        if (cxl_mst_ack_q == 1'b1) begin
            run_crd_cnt         = 1'b1;         
            next_state          = CXL_MST_LINK_RUN; 
        end
    end
    CXL_MST_LINK_RUN: begin             //run_crd_cnt, cxl_mst_req, cxl_mst_ack_q is 1 through out this state
        // If cxl_rx_active_req is de-asserted due to VLSM exiting from ACTIVE state
        // when VLSM is in transitional state on entry to RESET, L1, or L2 state then wait for all
        // pending messages to be flushed from Receive Buffer before de-assertion of initialization request
            run_crd_cnt         = 1'b1;         
//check on halt_dly_cnt allow to enter this state once cxl_rx_tl_pending/cxl_rx_link_up low atleast once.
        if ( (!cxl_rx_active_req || (halt_dly_cnt>0)) && !cxl_rx_tl_pending && cxl_rx_dl_idle)begin            //DEINIT.MST has higher priority check over DEINIT.SLV, wait for cxl_rx_link_up    to be deasserted.
            inc_halt_dly_cnt    = 1'b1;
           if(halt_dly_cnt==MST_REQ_HALT_DELAY)begin    //Added to delay Deasserting cxl_mst_ack in this state, to avoid PROT_ERR:Transaction received in DEINIT_MST state
            clr_halt_dly_cnt    = 1'b1;
            next_state          = CXL_MST_LINK_DEINIT_MST;
            next_cxl_mst_req    = 1'b0;
           end
            ch_msg_halt         = 1'b1;
        end else  if(cxl_mst_ack_q==1'b0)begin
            next_state          = CXL_MST_LINK_DEINIT_SLV;
        end
    end
    CXL_MST_LINK_DEINIT_MST: begin          //nullify_crd = 1, run_crd_cn = 0, cxl_mst_req = 0 throughout this state.
            ch_msg_halt         = 1'b1;
            run_crd_cnt         = 1'b1;         
        if(cxl_mst_ack_q==1'b0)begin            //wait for cxl_mst_ack_q = 0 
            next_state          = CXL_MST_LINK_IDLE;
            nullify_crd         = 1'b1;
        end
    end
    CXL_MST_LINK_DEINIT_SLV: begin
        // If Slave initiates link de-initialization then wait for all pending messages to be offloaded from Receive Buffer
        // before de-asserting initialization request
            run_crd_cnt         = 1'b1;         
        if((~cxl_rx_tl_pending)||(halt_dly_cnt>0))begin //check on halt_dly_cnt allow to enter this state once cxl_rx_tl_pending low atleast once.        
            inc_halt_dly_cnt    = 1'b1;
           if(halt_dly_cnt==MST_REQ_HALT_DELAY)begin    //Added to delay Deasserting cxl_mst_req in this state, to avoid PROT_ERR:Transaction received in IDLE state
            clr_halt_dly_cnt    = 1'b1;
            next_state          = CXL_MST_LINK_IDLE;
            next_cxl_mst_req    = 1'b0;
           end
            ch_msg_halt         = 1'b1;
            nullify_crd         = 1'b1;
        end
    end
    default:begin
            next_state          = curr_state;
            next_cxl_mst_req    = cxl_mst_req;
            ch_msg_halt         = 1'b0;
            nullify_crd         = 1'b0;
            run_crd_cnt         = 1'b0;
            inc_halt_dly_cnt    = 1'b0;
            clr_halt_dly_cnt    = 1'b0;
    end
  endcase
end  


endmodule
