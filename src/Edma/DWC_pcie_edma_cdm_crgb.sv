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
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edma/DWC_pcie_edma_cdm_crgb.sv#6 $
// -------------------------------------------------------------------------
// --- Module description: Converts CDM writes and reads to CRGB and vice versa
// -------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"


 module DWC_pcie_edma_cdm_crgb
 #(//------------Parameters-----------------
   parameter                       INST         = 00
  ,parameter                       ADDR_WIDTH   = 12
  ,parameter                       DATA_WIDTH   = 32
  ,parameter                       BE_WIDTH     = 04
  )(

   //------------Common signals-----------
   input  logic                                      clk
  ,input  logic                                      reset_n
   //------------CDM interface------------
  ,input  logic                                      cdm_cs
  ,output logic                                      cdm_ack
  ,input  logic                   [ADDR_WIDTH - 1:0] cdm_addr
  ,input  logic                   [DATA_WIDTH - 1:0] cdm_datain
  ,output logic                   [DATA_WIDTH - 1:0] cdm_dataout
  ,input  logic                     [BE_WIDTH - 1:0] cdm_wr
  ,input  logic                                      cdm_source
   //------------CRGB interface-----------
  ,output logic                   [ADDR_WIDTH - 1:0] crgb_addr
  ,output logic                                      crgb_re
  ,output logic                                      crgb_we
  ,input  logic                   [DATA_WIDTH - 1:0] crgb_din
  ,output logic                   [DATA_WIDTH - 1:0] crgb_dout
  ,output logic                     [BE_WIDTH - 1:0] crgb_byte_en
  ,output logic                                      crgb_source
  ,input  logic                                      crgb_ready
);
//------------Local Parameters----------
  localparam                      NO_OF_STATES = 5;
  localparam                      S_IDLE       = 0;
  localparam                      S_WRITE      = 1;
  localparam                      S_READ       = 2;
  localparam                      S_WAIT       = 3;
  localparam                      S_ACK        = 4;
//-------Internal wire and regs---------
  logic                           wr_en;
  logic                           rd_en;
  logic                           rd_tx;
  logic                           [NO_OF_STATES - 1:0 ] cur_state;
  logic                           [NO_OF_STATES - 1:0 ] next_state;

 //---------------------------------------------------------
 //Assign statements
 //---------------------------------------------------------
 assign rd_en  = (cdm_cs && (cdm_wr == {BE_WIDTH{1'b0}})) ? 1'b1 :  1'b0;
 assign wr_en  = (cdm_cs && (cdm_wr != {BE_WIDTH{1'b0}})) ? 1'b1 :  1'b0;
//---------------------------------------------------------
//REG Block FSM
//---------------------------------------------------------
always_ff @(posedge clk or negedge reset_n)
begin: PROC_FSM_SEQ
  if (!reset_n) begin
    cur_state[S_IDLE ] <= #(`TP)  1'b1;
    cur_state[S_WRITE] <= #(`TP)  1'b0;
    cur_state[S_READ ] <= #(`TP)  1'b0;
    cur_state[S_WAIT ] <= #(`TP)  1'b0;
    cur_state[S_ACK  ] <= #(`TP)  1'b0;
  end
  else begin
    cur_state <= #(`TP) next_state;
  end
end //always_ff
 //---------------------------------------------------------
always_comb
begin: PROC_FSM_COMBOC
 next_state = {NO_OF_STATES{1'b0}};
 case (1'b1)
   //-----------------------
   cur_state[S_IDLE]: begin
     if (cdm_cs) begin
      if(wr_en) begin
       next_state[S_WRITE] = 1'b1;
      end
      else begin
       next_state[S_READ] = 1'b1;
      end
     end
     else begin
       next_state[S_IDLE] = 1'b1;
     end
   end
   //-----------------------
   cur_state[S_WRITE]: begin
     if (crgb_ready) begin
       next_state[S_ACK] = 1'b1;
     end
     else begin
       next_state[S_WRITE] = 1'b1;
     end
   end
   //-----------------------
   cur_state[S_READ]: begin
     if (crgb_ready) begin
        next_state[S_ACK] = 1'b1;
     end
     else begin
       next_state[S_READ] = 1'b1; //WAIT for RData to be available
     end
   end
   //-----------------------
   cur_state[S_WAIT]: begin
     if (crgb_ready) begin
       next_state[S_ACK] = 1'b1;
     end
     else begin
       next_state[S_WAIT] = 1'b1;
     end
   end
   //-----------------------
   cur_state[S_ACK]: begin
     if(cdm_cs) begin
        next_state[S_ACK] = 1'b1; //Wait here until cdm_cs is deasserted.
     end
     else begin
        next_state[S_IDLE] = 1'b1; //Once cs is deasserted goto idle
     end
   end
   default : begin
      //This should never be reached
      next_state = {NO_OF_STATES{1'b0}};
   end
 endcase
end //always_comb
 //---------------------------------------------------------
 //Always Blocks
 //---------------------------------------------------------
 //Ack Signal
 always_ff @(posedge clk or negedge reset_n) begin: PROC_cdm_ack
   if(!reset_n) begin
     cdm_ack <= #(`TP) 1'b0;
   end
   else begin
     if(next_state[S_ACK]) begin
       cdm_ack <= #(`TP) 1'b1;
     end
     else begin
       cdm_ack <= #(`TP) 1'b0;
     end
   end
 end //always
 //---------------------------------------------------------
 //CRGB Interface
 always_ff @(posedge clk or negedge reset_n) begin: PROC_crgb_reg_ops
   if(!reset_n) begin
     crgb_re      <= #(`TP) 1'b0;
     crgb_we      <= #(`TP) 1'b0;
     crgb_addr    <= #(`TP) {ADDR_WIDTH{1'b0}};
     crgb_dout    <= #(`TP) {DATA_WIDTH{1'b0}};
     crgb_byte_en <= #(`TP) {BE_WIDTH{1'b0}};
     crgb_source  <= #(`TP) 1'b0;

   end
   else begin
     if ((next_state[S_WRITE] || next_state[S_READ])) begin
        crgb_re      <= #(`TP) rd_en;
        crgb_we      <= #(`TP) wr_en;
        crgb_addr    <= #(`TP) cdm_addr;
        crgb_dout    <= #(`TP) cdm_datain;
        crgb_byte_en <= #(`TP) cdm_wr;
        crgb_source  <= #(`TP) cdm_source;
      end
      else begin
        crgb_re      <= #(`TP) 1'b0;
        crgb_we      <= #(`TP) 1'b0;
        crgb_addr    <= #(`TP) {ADDR_WIDTH{1'b0}};
        crgb_dout    <= #(`TP) {DATA_WIDTH{1'b0}};
        crgb_byte_en <= #(`TP) {BE_WIDTH{1'b0}};
        crgb_source  <= #(`TP) 1'b0;
      end
   end
 end //always
 //---------------------------------------------------------
 // CDM DATA OUT
 always_ff @(posedge clk or negedge reset_n) begin: PROC_ack_gen
   if(!reset_n) begin
     cdm_dataout <= #(`TP) {DATA_WIDTH{1'b0}};
   end
   else begin
     if (!next_state[S_ACK]) begin
       cdm_dataout <= #(`TP) {DATA_WIDTH{1'b0}};
     end
     else begin
       if(cur_state[S_READ] && crgb_ready)
       cdm_dataout <= #(`TP) crgb_din;
     end
   end
 end //always

//---------------------------------------------------------
`ifndef SYNTHESIS

//---------------------------------------------------------


wire    [10*8:0]         CURRENT_STATE;
wire    [10*8:0]         NEXT_STATE;

assign  NEXT_STATE    =  (next_state[S_IDLE])     ? "IDLE "   :
                         (next_state[S_WRITE])    ? "WRITE" :
                         (next_state[S_READ])     ? "READ " :
                         (next_state[S_WAIT])     ? "WAIT " :
                         (next_state[S_ACK])      ? "ACK" : "ERROR";


assign  CURRENT_STATE =  (cur_state[S_IDLE])      ? "IDLE"   :
                         (cur_state[S_WRITE])     ? "WRITE" :
                         (cur_state[S_READ])      ? "READ" :
                         (cur_state[S_WAIT])      ? "WAIT" :
                         (cur_state[S_ACK])       ? "ACK" : "ERROR";

`endif // SYNTHESIS
//---------------------------------------------------------
endmodule //DWC_pcie_edma_cdm_crgb
