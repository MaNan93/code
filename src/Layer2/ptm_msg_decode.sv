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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/ptm_msg_decode.sv#8 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module generates a PTM request/response message recognition,
// --- to be used by PTM related blocks. 
// -----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module ptm_msg_decode
#(
    parameter NW                    = (`CX_NW>16) ? 16 : `CX_NW  // The uniquifying parameter for each port logic instance.
   )

                      (
// ----- Inputs-----
input                       core_rst_n,
input                       core_clk,

input   [2:0]               current_data_rate,    // 0=running at gen1 speeds, 1=running at gen2 speeds, 2-gen3, 3-gen4

input   [NW-1:0]            tlp_sot,         // Start of TLP
input   [32*NW-1:0]         tlp_data,        // TLP data including hdr, prefix and paylaod
input                       tlp_dv,          // Data valid
input   [NW-1:0]            tlp_eot,         // End of transaction
input                       tlp_error,       // End of nullified transaction
input                       tlp_halt,        // Data link layer halt
input                       xmlh_stp_start,  // Single pulse to indicate stp starts, taken over from Layer1

// ----- Outputs-----
output  wire                ptm_sot,         // Output sot to XADM layer
output  reg                 ptm_multi_cycle, // Output informing if the sot of the PTM message started during the current clock cycle
output  reg                 ptm_request,     // Output PTM Request Msg
output  reg                 ptm_response     // Output PTM Response Msg
);

// =============================================================================
// -- Parameters
// =============================================================================

parameter MSG_4       = `MSG_4; 
parameter MSGD_4      = `MSGD_4; 
parameter MSGCODE_REQ = `PTM_REQ_TYPE; 
parameter MSGCODE_RES = `PTM_RES_TYPE; 
parameter TP          = `TP;      // Clock to Q delay (simulator insurance)

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
reg multi_cycle; 

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

// For Gen3/Gen4 data rate, there are 32 bits added in front of the TLP
  if (current_data_rate >= `GEN3_RATE) begin
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
// For Gen1/Gen2 data rate, there are 24 bits added in front of the TLP, the data is shifted with 24 bits
  else begin
   for (i=0; i<NW; i=i+1) 
      begin 
          msg[i]         = (tlp_data[32*i+27 +:4] == MSG_4);  
          msg_d[i]       = (tlp_data[32*i+27 +:4] == MSGD_4);  
          routing[i]     = (tlp_data[32*i+24 +:3] == 3'b100);  
          fmt_resD[i]    = {tlp_data[32*i+29 +:3]} == 3'b011;  
          dwlen1[i]      = {tlp_data[32*i+8 +:2],tlp_data[32*i+16 +:8]} == 1;  
          tlp_tc[i]      = (tlp_data[32*i+4 +:3]) == 0; 
          msgcode_req[i] = tlp_data[32*i+16 +:8] == MSGCODE_REQ; 
          msgcode_res[i] = tlp_data[32*i+16 +:8] == MSGCODE_RES; 
          is_prfx[i]     = tlp_data[32*i+29 +:3] == 3'b100;
     end 
    end 
  end

logic[NW-1:0] tlp_soh_gen12;
logic[NW-1:0] tlp_soh_gen345;
assign tlp_soh_gen12 = tlp_sot;
assign tlp_soh_gen345 = '1;


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

// ======= Processing of a PTM Request Message =======

reg [NW-1:0] ptm_msg_req_dw0; 
reg [NW-1:0] ptm_msg_req_dw1; 
reg [NW-1:0] ptm_msg_req_dw2; 
reg [NW-1:0] ptm_msg_req; 
reg r_ptm_msg_req_dw0; 
reg r_ptm_msg_req_dw1; 
reg r_ptm_msg_req; 

always @(*) begin : PTM_REQUEST_DECODE 
  integer i; 
  ptm_msg_req_dw0 = 0; 
  ptm_msg_req_dw1 = 0; 
  ptm_msg_req_dw2 = 0; 
  ptm_msg_req     = 0; 

// Decode the SOT of a PTM request message
if(tlp_dv && !tlp_halt) begin
  for(i=0; i<NW; i = i + 1) begin 
    if (current_data_rate >= `GEN3_RATE)begin      // For Gen3/Gen4 data rate, there are 32 bits added in front of the TLP 
      ptm_msg_req_dw0[i] = tlp_sot[i]; 
    end else begin                                     // For Gen1/Gen2 data rate, there are 24 bits added in front of the TLP 
      ptm_msg_req_dw0[i] = tlp_soh_gen12[i] && msg[i] && routing[i]; 
    end
  end 

// Decode DW1 of a PTM request message on a per DW basis 
  if (current_data_rate >= `GEN3_RATE) begin
    ptm_msg_req_dw1[0] = r_ptm_msg_req_dw0 && msg[0] && routing[0]  && tlp_tc[0] && tlp_soh_gen345[0]; 
    for(i=1; i<NW; i = i + 1) begin 
      ptm_msg_req_dw1[i] = ptm_msg_req_dw0[i-1] && msg[i] && routing[i]  && tlp_tc[i] && tlp_soh_gen345[i]; 
    end 
  end
  else begin
    ptm_msg_req_dw1[0] = r_ptm_msg_req_dw0 && tlp_tc[0]; 
    for(i=1; i<NW; i = i + 1) begin 
      ptm_msg_req_dw1[i] = ptm_msg_req_dw0[i-1] && tlp_tc[i]; 
    end 
  end
  
// Decode DW2 of a PTM requests message on a per DW basis, relative to DW1 
// DW2 requires that DW1 was a PTM message in previous cycle  
  ptm_msg_req_dw2[0] = r_ptm_msg_req_dw1 && msgcode_req[0]; 
  for(i=1; i<NW; i = i + 1) begin 
    ptm_msg_req_dw2[i] = ptm_msg_req_dw1[i-1] && msgcode_req[i]; 
  end 

// Once DW0 DW1 and DW2 of the message have been decoded, remember that we are in a message 
 ptm_msg_req[0] = (r_ptm_msg_req && !r_tlp_eot || ptm_msg_req_dw2[0]); 
  for(i=1;i<NW;i = i + 1) begin 
    ptm_msg_req[i] = (ptm_msg_req[i-1] && !tlp_eot[i-1] || ptm_msg_req_dw2[i]); 
  end 
end
end 

always @(posedge core_clk or negedge core_rst_n)
begin
  if(!core_rst_n) begin
    r_ptm_msg_req_dw0                <= #TP 1'b0;
    r_ptm_msg_req_dw1                <= #TP 1'b0;
    r_ptm_msg_req                    <= #TP 1'b0;
  end 
  else begin
    if (tlp_dv && !tlp_halt) begin 
      r_ptm_msg_req_dw0 <= #TP ptm_msg_req_dw0[NW-1]; 
      r_ptm_msg_req_dw1 <= #TP ptm_msg_req_dw1[NW-1]; 
      r_ptm_msg_req     <= #TP ptm_msg_req[NW-1]; 
    end 
  end
end    

// ======= Processing of a PTM Response Message =======

reg [NW-1:0] ptm_msg_res_dw0; 
reg [NW-1:0] ptm_msg_res_dw1; 
reg [NW-1:0] ptm_msg_res_dw2; 
reg [NW-1:0] ptm_msg_res; 
reg r_ptm_msg_res_dw0; 
reg r_ptm_msg_res_dw1; 
reg r_ptm_msg_res; 
reg r_fmt_resD; 

always @(*) begin : PTM_RESPONSE_DECODE
  integer i; 
  ptm_msg_res_dw0 = 0; 
  ptm_msg_res_dw1 = 0; 
  ptm_msg_res_dw2 = 0; 
  ptm_msg_res     = 0; 

// Decode the SOT of a PTM Response or ResponseD message
if(tlp_dv && !tlp_halt) begin
  for(i=0; i<NW; i = i + 1) begin 
    if (current_data_rate >= `GEN3_RATE)begin      // For Gen3/Gen4 data rate, there are 32 bits added in front of the TLP 
      ptm_msg_res_dw0[i] = tlp_sot[i]; 
    end else begin                                      // For Gen1/Gen2 data rate, there are 24 bits added in front of the TLP 
      ptm_msg_res_dw0[i] = tlp_soh_gen12[i] && (msg[i] || msg_d[i]) && routing[i]; 
    end
  end 

// Decode DW1 of a PTM Response or ResponseD message on a per DW basis 
  if (current_data_rate >= `GEN3_RATE) begin
    if (fmt_resD[0] == 1)
      ptm_msg_res_dw1[0] = r_ptm_msg_res_dw0 && (msg[0] || msg_d[0]) && routing[0]  && tlp_tc[0] && dwlen1[0] && tlp_soh_gen345[0]; 
    else
      ptm_msg_res_dw1[0] = r_ptm_msg_res_dw0 && (msg[0] || msg_d[0]) && routing[0]  && tlp_tc[0] && tlp_soh_gen345[0]; 
    for(i=1; i<NW; i = i + 1) begin 
      if (fmt_resD[i] == 1)    
        ptm_msg_res_dw1[i] = ptm_msg_res_dw0[i-1] && (msg[i] || msg_d[i]) && routing[i]  && tlp_tc[i] && dwlen1[i] && tlp_soh_gen345[i]; 
      else
        ptm_msg_res_dw1[i] = ptm_msg_res_dw0[i-1] && (msg[i] || msg_d[i]) && routing[i]  && tlp_tc[i] && tlp_soh_gen345[i]; 
    end 
  end
  else begin
    if (r_fmt_resD == 1)                     // For Gen1/Gen2, the 2nd DW needs to account for the format information available in the 1st DW
      ptm_msg_res_dw1[0] = r_ptm_msg_res_dw0 && tlp_tc[0] && dwlen1[0]; 
    else
      ptm_msg_res_dw1[0] = r_ptm_msg_res_dw0 && tlp_tc[0]; 
    for(i=1; i<NW; i = i + 1) begin 
      if (fmt_resD[i-1] == 1)    
        ptm_msg_res_dw1[i] = ptm_msg_res_dw0[i-1] && tlp_tc[i] && dwlen1[i]; 
      else
        ptm_msg_res_dw1[i] = ptm_msg_res_dw0[i-1] && tlp_tc[i]; 
    end 
  end
  
// Decode DW2 of a PTM Response or ResponseD message on a per DW basis, relative to DW1 
// DW2 requires that DW1 was a PTM message in previous cycle  
  ptm_msg_res_dw2[0] = r_ptm_msg_res_dw1 && msgcode_res[0]; 
  for(i=1; i<NW; i = i + 1) begin 
    ptm_msg_res_dw2[i] = ptm_msg_res_dw1[i-1] && msgcode_res[i]; 
  end 

// Once DW0 DW1 and DW2 of the message have been decoded, remember that we are in a message 
 ptm_msg_res[0] = (r_ptm_msg_res && !r_tlp_eot || ptm_msg_res_dw2[0]); 
  for(i=1;i<NW;i = i + 1) begin 
    ptm_msg_res[i] = (ptm_msg_res[i-1] && !tlp_eot[i-1] || ptm_msg_res_dw2[i]); 
  end 
end
end 

always @(posedge core_clk or negedge core_rst_n)
begin
  if(!core_rst_n) begin
    r_ptm_msg_res_dw0                <= #TP 1'b0;
    r_ptm_msg_res_dw1                <= #TP 1'b0;
    r_ptm_msg_res                    <= #TP 1'b0;
    r_fmt_resD                       <= #TP 1'b0;
  end 
  else begin
    if (tlp_dv && !tlp_halt) begin 
      r_ptm_msg_res_dw0 <= #TP ptm_msg_res_dw0[NW-1]; 
      r_ptm_msg_res_dw1 <= #TP ptm_msg_res_dw1[NW-1]; 
      r_ptm_msg_res     <= #TP ptm_msg_res[NW-1] && (!tlp_eot[NW-1]); 
      r_fmt_resD        <= #TP fmt_resD[NW-1]; 
    end 
  end
end    


// We gate xmlh_stp_start for any TLP received when a PTM TLP is in progress (i.e. multi_cycle = 1) while also tlp_halt is asserted.
// Signal multi_cycle is asserted as soon the PTM TLP was decoded (rising edge at the same time with r_ptm_msg_res or r_ptm_msg_req)
// and de-asserted whenever the end of the TLP is encountered (tlp_eot asserted).
// As an example, we can have a new TLP starting while a PTM TLP is in progress; the xmlh_stp_start is gated and not passed out on the ptm_sot output
/*
                  ________
_________________/        \_______     tlp_eot (input)
                  ____
_________________/    \___________     tlp_halt (input)
                  ____
_________________/    \___________     xmlh_stp_start (input)
                  ________
_________________/        \_______     internal r_ptm_msg_req or r_ptm_msg_res
                  ____
_________________/    \___________     internal multi_cycle (asserted because a PTM TLP is in progress)
                      
__________________________________     ptm_sot (output), gated by multi_cycle and blocking therefore the xmlh_stp_start
                       ____
______________________/    \______     ptm_request or ptm_response (output)
                       ____
______________________/    \______     ptm_multi_cycle (output)


*/


always @(*)
   begin : PTM_Multi_cycle
         multi_cycle = 1'b0;
       if ((|(ptm_msg_req & tlp_eot) || |(ptm_msg_res & tlp_eot)) && tlp_dv && !tlp_halt) begin
         multi_cycle = 1'b0;
       end else begin 
         multi_cycle = (r_ptm_msg_res && !tlp_error) || (r_ptm_msg_req && !tlp_error) ;
       end
       
end    

// We pass out any sot for which the input xmlh_stp_start is asserted, even while tlp_halt is asserted. 
// We gate xmlh_stp_start for any TLP received when a PTM TLP is in progress (i.e. multi_cycle = 1) while also tlp_halt is asserted.
reg           ptm_sot_i;
always @(*) 
   begin : PTM_SOT 
   ptm_sot_i = 1'b0; 
   if (|tlp_sot && tlp_dv && (xmlh_stp_start && !(multi_cycle && tlp_halt))) begin 
      ptm_sot_i = 1'b1; 
   end 
end

assign ptm_sot      = ptm_sot_i;   
assign ptm_request  = |(ptm_msg_req & tlp_eot) && !tlp_error; 
assign ptm_response = |(ptm_msg_res & tlp_eot) && !tlp_error; 
assign ptm_multi_cycle  = (|(ptm_msg_res & tlp_eot) && !tlp_error && (!((|ptm_msg_res_dw0) && (|ptm_msg_res_dw2)) || ptm_msg_res_dw1[0] || ptm_msg_res_dw2[0] || ptm_msg_res[0])) || (|(ptm_msg_req & tlp_eot) && !tlp_error && (!((|ptm_msg_req_dw0) && (|ptm_msg_req_dw2)) || ptm_msg_req_dw1[0] || ptm_msg_req_dw2[0] || ptm_msg_req[0]));

endmodule
