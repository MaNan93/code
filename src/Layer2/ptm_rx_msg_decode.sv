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
// ---    $DateTime: 2024/01/19 09:25:58 $
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/ptm_rx_msg_decode.sv#8 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module generates a PTM request/response message recognition,
// --- to be used by PTM related blocks. 
// -----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module ptm_rx_msg_decode
#(
    parameter NW                    = (`CX_NW>16) ? 16 : `CX_NW,  // The uniquifying parameter for each port logic instance.
    parameter RX_TLP_NFM            = `CX_RX_TLP_NFM                    // Number of TLPs that can be processed in a single cycle
   )

                         (
// ----- Inputs-----
input                           core_rst_n,
input                           core_clk,

input   [NW-1:0]                tlp_sot,         // Start of TLP
input   [32*NW-1:0]             tlp_data,        // TLP data including hdr, prefix and paylaod
input                           tlp_dv,          // Data valid
input   [NW-1:0]                tlp_eot,         // End of transaction
input   [RX_TLP_NFM-1:0]        tlp_error,       // End of nullified transaction
input                           tlp_halt,        // Data link layer halt

// ----- Outputs-----
output wire                     ptm_sot,         // Output sot to XADM layer
output reg                      ptm_multi_cycle, // Output informing if the sot of the PTM message started during the current clock cycle
output reg                      ptm_request,     // Output PTM Request Msg
output reg                      ptm_response     // Output PTM Response Msg
);

// =============================================================================
// -- Parameters
// =============================================================================

parameter MSG_4       = `MSG_4; 
parameter MSGD_4      = `MSGD_4; 
parameter MSGCODE_REQ = `PTM_REQ_TYPE; 
parameter MSGCODE_RES = `PTM_RES_TYPE; 
parameter TP          = `TP;      // Clock to Q delay (simulator insurance)

localparam RX_TLP_LOG2 = (RX_TLP_NFM==4) ? 2 : 1;

// ================== Internal Design ==========================================

reg [NW-1:0] msg; 
reg [NW-1:0] msg_d; 
reg [NW-1:0] routing; 
reg [NW-1:0] fmt_resD; 
reg [NW-1:0] dwlen1; 
reg [NW-1:0] tlp_tc;
reg [NW-1:0] msgcode_req; 
reg [NW-1:0] msgcode_res; 
reg [NW-1:0] is_prfx; 
reg r_tlp_eot; 

 always @(*)
   begin : PTM_CAPTURE
   integer i;
   
   msg            = 0;  
   msg_d          = 0;  
   routing        = 0;  
   fmt_resD       = 0;  
   dwlen1         = 0;  
   tlp_tc         = 0; 
   msgcode_req    = 0; 
   msgcode_res    = 0; 
   is_prfx        = 0;

   for (i=0; i<NW; i=i+1) 
      begin 
          msg[i]         = (tlp_data[32*i+3 +:4] == MSG_4);  
          msg_d[i]       = (tlp_data[32*i+3 +:4] == MSGD_4);  
          routing[i]     = (tlp_data[32*i +: 3] == 3'b100);  
          fmt_resD[i]    = {tlp_data[32*i+5 +:3]} == 3'b011;  
          dwlen1[i]      = {tlp_data[32*i+16 +:2],tlp_data[32*i+24 +:8]} == 1;  
          tlp_tc[i]      = (tlp_data[32*i+12 +:3]) == 0; 
          msgcode_req[i] = tlp_data[32*i+24 +:8] == MSGCODE_REQ; 
          msgcode_res[i] = tlp_data[32*i+24 +:8] == MSGCODE_RES; 
          is_prfx[i]     = tlp_data[32*i+5 +:3] == 3'b100;
     end 
    end 

always @(posedge core_clk or negedge core_rst_n)
begin
  if(!core_rst_n) begin
    r_tlp_eot            <= #TP 1'b0;
  end 
  else begin
    if (tlp_dv && !tlp_halt) begin 
      r_tlp_eot         <= #TP tlp_eot[NW-1];
    end 
  end
end    

logic[NW-1:0] tlp_soh;
assign tlp_soh = tlp_sot;
// ======= Processing of a PTM Request Message =======

reg [NW-1:0] ptm_msg_req_dw0; 
reg [NW-1:0] ptm_msg_req_dw1; 
reg [NW-1:0] ptm_msg_req; 
reg r_ptm_msg_req_dw0; 
reg r_ptm_msg_req; 

always @(*) begin : PTM_REQUEST_DECODE 
  integer i; 
  ptm_msg_req_dw0 = 0; 
  ptm_msg_req_dw1 = 0; 
  ptm_msg_req     = 0; 

// Decode DW0 of a PTM request message on a per DW basis 
if(tlp_dv && !tlp_halt) begin
  for(i=0; i<NW; i = i + 1) begin 
    ptm_msg_req_dw0[i] = tlp_soh[i] && msg[i] && routing[i]  && tlp_tc[i]; 
  end 

// Decode dw1 of a PTM requests message on a per DW basis, relative to dw0 
// DW1 requires that DW0 was a message in previous cycle  
  ptm_msg_req_dw1[0] = r_ptm_msg_req_dw0 && msgcode_req[0]; 
  for(i=1; i<NW; i = i + 1) begin 
    ptm_msg_req_dw1[i] = ptm_msg_req_dw0[i-1] && msgcode_req[i]; 
  end 

// Once dw0 and dw1 of the message have been decoded, remember that we are in a message 
 ptm_msg_req[0] = (r_ptm_msg_req  && !r_tlp_eot || ptm_msg_req_dw1[0]); 
  for(i=1;i<NW;i = i + 1) begin 
    ptm_msg_req[i] = (ptm_msg_req[i-1] && !tlp_eot[i-1] || ptm_msg_req_dw1[i]); 
  end 
end
end 

always @(posedge core_clk or negedge core_rst_n)
begin
  if(!core_rst_n) begin
    r_ptm_msg_req_dw0                <= #TP 1'b0;
    r_ptm_msg_req                    <= #TP 1'b0;
  end 
  else begin
    if (tlp_dv && !tlp_halt) begin 
      r_ptm_msg_req_dw0 <= #TP ptm_msg_req_dw0[NW-1]; 
      r_ptm_msg_req     <= #TP ptm_msg_req[NW-1]; 
    end 
  end
end    

// ======= Processing of a PTM Response Message =======

reg [NW-1:0] ptm_msg_res_dw0; 
reg [NW-1:0] ptm_msg_res_dw1; 
reg [NW-1:0] ptm_msg_res; 
reg r_ptm_msg_res_dw0; 
reg r_ptm_msg_res; 

always @(*) begin : PTM_RESPONSE_DECODE 
  integer i; 
  ptm_msg_res_dw0 = 0; 
  ptm_msg_res_dw1 = 0; 
  ptm_msg_res     = 0; 

// Decode DW0 of a PTM response message on a per DW basis 
if(tlp_dv && !tlp_halt) begin
  for(i=0; i<NW; i = i + 1) begin 
    if ( fmt_resD[i] == 1 )
      ptm_msg_res_dw0[i] = tlp_soh[i] && (msg[i] || msg_d[i]) && routing[i]  && tlp_tc[i] && dwlen1[i]; 
    else
      ptm_msg_res_dw0[i] = tlp_soh[i] && (msg[i] || msg_d[i]) && routing[i]  && tlp_tc[i]; 
  end 

// Decode dw1 of a PTM response message on a per DW basis, relative to dw0 
// DW1 requires that DW0 was a message in previous cycle  
  ptm_msg_res_dw1[0] = r_ptm_msg_res_dw0 && msgcode_res[0]; 
  for(i=1; i<NW; i = i + 1) begin 
    ptm_msg_res_dw1[i] = ptm_msg_res_dw0[i-1] && msgcode_res[i]; 
  end 

// Once DW0 and DW1 of the message have been decoded, remember that we are in a message 
 ptm_msg_res[0] = (r_ptm_msg_res  && !r_tlp_eot || ptm_msg_res_dw1[0]); 
  for(i=1;i<NW;i = i + 1) begin 
    ptm_msg_res[i] = (ptm_msg_res[i-1] && !tlp_eot[i-1] || ptm_msg_res_dw1[i]); 
  end 
end
end
 
always @(posedge core_clk or negedge core_rst_n)
begin
  if(!core_rst_n) begin
    r_ptm_msg_res_dw0                <= #TP 1'b0;
    r_ptm_msg_res                    <= #TP 1'b0;
  end 
  else begin
    if (tlp_dv && !tlp_halt) begin 
      r_ptm_msg_res_dw0 <= #TP ptm_msg_res_dw0[NW-1]; 
      r_ptm_msg_res     <= #TP ptm_msg_res[NW-1]; 
    end 
  end
end    

reg           ptm_sot_i;
always @(*) 
   begin : PTM_SOT 
   ptm_sot_i = 1'b0; 
   if(|tlp_sot && tlp_dv && !tlp_halt) begin 
      ptm_sot_i = 1'b1; 
   end 
end


reg [RX_TLP_NFM-1:0] ptm_aligned_req ; //  bit "i" set means i+1 eots are present
reg [RX_TLP_NFM-1:0] ptm_aligned_res ; //  bit "i" set means i+1 eots are present
always @(*) begin : GET_REQ_TLP_ALIGNED
    integer i;
    reg [RX_TLP_LOG2-1:0] j;
    ptm_aligned_req = 0;
    j = 0;
    for(i = 0; i < NW; i = i + 1) begin
        if((tlp_eot[i])) 
        begin
          ptm_aligned_req[j] = ptm_msg_req[i] & tlp_eot[i];
          if( tlp_error[j] == 1'b1 )
            ptm_aligned_req[j] = 1'b0;
          if( (NW >= 8) && (j < RX_TLP_NFM - 1 ) ) 
            j = j + 1 ;
        end
    end
end

always @(*) begin : GET_RES_TLP_ALIGNED
    integer i;
    reg [RX_TLP_LOG2-1:0] j;
    ptm_aligned_res = 0;
    j = 0;
    for(i = 0; i < NW; i = i + 1) begin
        if((tlp_eot[i])) 
          begin
            ptm_aligned_res[j] = ptm_msg_res[i] & tlp_eot[i];
            if( tlp_error[j] == 1'b1 )
              ptm_aligned_res[j] = 1'b0;
            if( (NW >= 8) && (j < RX_TLP_NFM - 1 ) ) 
              j = j + 1 ;
          end
    end
end

assign ptm_sot      = ptm_sot_i;   
assign ptm_request  = |ptm_aligned_req; 
assign ptm_response = |ptm_aligned_res; 
assign ptm_multi_cycle  = (|ptm_aligned_res && (!((|ptm_msg_res_dw0) && (|ptm_msg_res_dw1)) || ptm_msg_res_dw1[0] || ptm_msg_res[0])) || (|ptm_aligned_req && (!((|ptm_msg_req_dw0) && (|ptm_msg_req_dw1)) || ptm_msg_req_dw1[0] || ptm_msg_req[0]));

    
endmodule
