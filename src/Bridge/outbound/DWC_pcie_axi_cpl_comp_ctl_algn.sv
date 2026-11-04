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
// ---    $DateTime: 2022/05/05 01:39:57 $
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/outbound/DWC_pcie_axi_cpl_comp_ctl_algn.sv#6 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// This module performs data alignement on data read from the completion composer segmented buffer.
// Completions to outbound read requests can be split and when this happens data beats are written
// to the segment buffer as they are received from the wire. If the read address is not aligned to
// the data bus boundary when a split occurs, the last beat of the first split completion will have
// some empty bytes. This beat then needs to be completed with the initial data bytes from the first
// beat of the next completion which implies realignment of all data beats read from the segemented
// buffer from that point onwards until the end of the TLP.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
module DWC_pcie_axi_cpl_comp_ctl_algn (
// ------ Inputs ------
    clk,
    rst_n,
    in_pkt_hv,
    in_pkt_dv,
    in_pkt_eot,
    in_pkt_hdr,
    in_pkt_data,
    in_pkt_dwen,
    in_pkt_byte_len,
    in_pkt_low_addr,
    in_pkt_tag,
    in_pkt_4rd,
    in_pkt_rreq_dma,
    in_pkt_rreq_dma_chan,
    in_pkt_err,

    out_halt,

    aligned_pkt_hv,
    aligned_pkt_dv,
    aligned_pkt_eot,
    aligned_pkt_hdr,
    aligned_pkt_data,
    aligned_pkt_dwen,
    aligned_pkt_byte_len,
    aligned_pkt_low_addr,
    aligned_pkt_tag,
    aligned_pkt_4rd,
    aligned_pkt_rreq_dma,
    aligned_pkt_rreq_dma_chan,
    aligned_pkt_err,

    in_halt

);

//  ========================================================================================================================
//  ---------------------- Parameters ------------------------
//  ========================================================================================================================

parameter                         NW                     = `CX_NW;                      // Number of 32-bit dwords handled by the datapath each clock.
parameter                         HDR_WD                 = `RADM_P_HWD;                 // a header macro
parameter                         CORE_DATA_BUS_WD       = `CC_CORE_DATA_BUS_WD;
parameter                         MAX_RD_SIZE_PW         = `CC_SLV_RD_REQ_SIZE_PW;      // pointer size for MAX rd size
parameter                         MAX_OUT_TAG_PW         = `CC_MAX_SLV_TAG_PW;          // pointer of MAX_OUT_TAG
parameter                         TP                     = `TP;                         // Clock to Q delay
parameter                         DBUS_DWORD_WD_WITH_PAR = `CC_DBUS_DWORD_WD_WITH_PAR;
parameter                         CX_RAS_RAM_PROT_RANGE  = `CX_RAS_RAM_PROT_RANGE;
parameter                         CX_RAS_PROT_RANGE      = `CX_RAS_PROT_RANGE;
parameter                         CX_RAS_PARITY_MODE     = `CX_RAS_PARITY_MODE;

//  ========================================================================================================================
//  ---------------------- Local parameters ------------------------
//  ========================================================================================================================

localparam                        S_ALIGN_IDLE           = 4'b0000; // 0
localparam                        S_SINGLE_BEAT          = 4'b0001; // 1
localparam                        S_FIRST_BEAT_WAIT_DATA = 4'b0010; // 2
localparam                        S_FIRST_BEAT           = 4'b0011; // 3
localparam                        S_FIRST_TO_EXTRA_BEAT  = 4'b1011; // B
localparam                        S_INTMD_BEAT_WAIT_DATA = 4'b0100; // 4
localparam                        S_INTMD_BEAT           = 4'b0101; // 5
localparam                        S_INTMD_TO_EXTRA_BEAT  = 4'b1101; // D
localparam                        S_FINAL_BEAT           = 4'b0111; // 7
localparam                        S_EXTRA_BEAT           = 4'b1000; // 8
localparam                        S_ERROR                = 4'b1111; // F

localparam                  [8:0] BUS_INIT_BYTE          = CX_RAS_PARITY_MODE ? 9'b100000000 : 9'b000000000;
localparam                        BYTE_WD_W_PAR          = 9;
localparam                        BUS_N_BYTES            = NW * 4;
localparam                        L_DATA_SHIFT_HIGH      = 31;
localparam                        L_DATA_SHIFT_LOW       = 1;

typedef logic [L_DATA_SHIFT_HIGH:L_DATA_SHIFT_LOW] [CORE_DATA_BUS_WD-1:0] dataShift_t;

function automatic dataShift_t f_getDataRshift();
  dataShift_t l_data_rshift;

  for(int i = L_DATA_SHIFT_LOW; i <= L_DATA_SHIFT_HIGH; i++) begin
    l_data_rshift[i] = (~({CORE_DATA_BUS_WD{1'b1}} >>  BYTE_WD_W_PAR * 4 * i)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
  end

  f_getDataRshift = l_data_rshift;
endfunction

function automatic dataShift_t f_getDataLshift();
  dataShift_t l_data_lshift;

  for(int i = L_DATA_SHIFT_LOW; i <= L_DATA_SHIFT_HIGH; i++) begin
    for(int j = 0; j < CORE_DATA_BUS_WD; j++) begin
      l_data_lshift[i][j] = (j < i*DBUS_DWORD_WD_WITH_PAR);
    end
  end

  f_getDataLshift = l_data_lshift;
endfunction

localparam dataShift_t            L_DATA_RSHIFT          = f_getDataRshift();
localparam dataShift_t            L_DATA_LSHIFT          = f_getDataLshift();

localparam [CORE_DATA_BUS_WD-1:0] BUS_INIT               = {BUS_N_BYTES{BUS_INIT_BYTE}};

localparam                        DW_CNT_WD              = (NW<2) ? 1 : $clog2(NW); // Count to 0, ..., NW-1

// ========================================================================================================================
// -------------------- inputs ------------------
// ========================================================================================================================
input                         clk;                          // clock
input                         rst_n;                        // reset

//  ========================================================================================================================
//  ---------------------- inputs ------------------
//  ========================================================================================================================
input                         in_pkt_hv;                    // Received composed completion data is valid
input                         in_pkt_dv;                    // start of a composed completion
input                         in_pkt_eot;                   // End of a composed completion
input  [          HDR_WD-1:0] in_pkt_hdr;                   // hdr infor of a composed completion
input  [CORE_DATA_BUS_WD-1:0] in_pkt_data;                  // Received data
input  [              NW-1:0] in_pkt_dwen;                  // Received data dword enable
input                         in_pkt_4rd;                   // completion is for a nonposted read
input  [                 2:0] in_pkt_rreq_dma;              // DMA Write response request type
input  [                 2:0] in_pkt_rreq_dma_chan;         // DMA Write response channel number
input  [  MAX_RD_SIZE_PW-1:0] in_pkt_byte_len;              // Received response dword length
input  [                 6:0] in_pkt_low_addr;              // Received response dword length
input                         in_pkt_err;                   // Received err, needs to be aborted, this causes a pointer rewind
input  [  MAX_OUT_TAG_PW-1:0] in_pkt_tag;                   // Received TAG
input                         in_halt;                      // Halt the incoming PKT

//  ========================================================================================================================
//  ---------------------- outputs ------------------
//  ========================================================================================================================
output                        aligned_pkt_hv;               // Received composed completion data is valid
output                        aligned_pkt_dv;               // start of a composed completion
output                        aligned_pkt_eot;              // End of a composed completion
output [          HDR_WD-1:0] aligned_pkt_hdr;              // hdr infor of a composed completion
output [CORE_DATA_BUS_WD-1:0] aligned_pkt_data;             // Received data
output [              NW-1:0] aligned_pkt_dwen;             // Received data dword enable
output                        aligned_pkt_4rd;              // completion is for a nonposted read
output [                 2:0] aligned_pkt_rreq_dma;         // DMA Write response request type
output [                 2:0] aligned_pkt_rreq_dma_chan;    // DMA Write response channel number
output [  MAX_RD_SIZE_PW-1:0] aligned_pkt_byte_len;         // Received response dword length
output [                 6:0] aligned_pkt_low_addr;         // Received response dword length
output                        aligned_pkt_err;              // Received err, needs to be aborted, this causes a pointer rewind
output [  MAX_OUT_TAG_PW-1:0] aligned_pkt_tag;              // Received TAG
output                        out_halt;                     // Halt the incoming PKT

//  ========================================================================================================================
//  ---------------------- IO signal declarations ------------------------
//  ========================================================================================================================
reg                           aligned_pkt_hv;               // Received composed completion data is valid
reg                           aligned_pkt_dv;               // start of a composed completion
reg                           aligned_pkt_eot;              // End of a composed completion
reg    [          HDR_WD-1:0] aligned_pkt_hdr;              // hdr infor of a composed completion
reg    [CORE_DATA_BUS_WD-1:0] aligned_pkt_data;             // Received data
reg    [              NW-1:0] aligned_pkt_dwen;             // Received data dword enable
reg                           aligned_pkt_4rd;              // completion is for a nonposted read
reg    [                 2:0] aligned_pkt_rreq_dma;         // DMA Write response request type
reg    [                 2:0] aligned_pkt_rreq_dma_chan;    // DMA Write response channel number
reg    [  MAX_RD_SIZE_PW-1:0] aligned_pkt_byte_len;         // Received response dword length
reg    [                 6:0] aligned_pkt_low_addr;         // Received response dword length
reg                           aligned_pkt_err;              // Received err, needs to be aborted, this causes a pointer rewind
reg    [  MAX_OUT_TAG_PW-1:0] aligned_pkt_tag;              // Received TAG
wire                          out_halt;

//  ========================================================================================================================
//  ---------------------- Internal variable declaration ------------------------
//  ========================================================================================================================

wire                          s_rd_dwen_all_ones;           // Indicates if all the DWs in a data beat are valid
reg    [         DW_CNT_WD:0] s_rd_data_valid_dw_cnt;       // Number of valid DWs in every input data beat
reg    [         DW_CNT_WD:0] r_dw_shift_left;              // Number of DWs by which input data needs to be shifted left after after a beat with empty DWs is received
wire   [         DW_CNT_WD:0] s_dw_shift_left;              // Number of DWs by which input data is shifted left before being used as output data
wire   [         DW_CNT_WD:0] s_dw_shift_right;             // Number of DWs by which input data is shifted right before being saved to be used on the next output data beat
reg    [CORE_DATA_BUS_WD-1:0] r_previous_valid_rd_data;
reg    [              NW-1:0] r_previous_valid_rd_dwen;
logic         [DW_CNT_WD-1:0] dw_shift_left,
                              dw_shift_right;


wire   [       DW_CNT_WD+1:0] s_current_valid_dw_cnt;
wire                          s_insert_wait_cycle;          // Indicates the need to insert a wait cycle because a beat with empty DWs was received
wire                          s_insert_extra_cycle;         // Indicates the need to insert an extra cycle after the last input beat is received because there is data left to be sent
wire                          s_accept_data_beat;           // When in S_ALIGN_IDLE, S_FIRST_BEAT_WAIT_DATA or S_INTMD_BEAT_WAIT_DATA we always accept data even if in_halt is high

reg    [CORE_DATA_BUS_WD-1:0] left_shifted_rd_data;
reg    [CORE_DATA_BUS_WD-1:0] right_shifted_rd_data;
reg    [CORE_DATA_BUS_WD-1:0] int_previous_valid_rd_data;
reg    [              NW-1:0] left_shifted_rd_dwen;
reg    [              NW-1:0] right_shifted_rd_dwen;

reg    [                 3:0] align_state;
reg    [                 3:0] next_align_state;

wire                          s_next_aligned_pkt_hv;
wire                          s_next_aligned_pkt_dv;
wire                          s_next_aligned_pkt_eot;
wire   [CORE_DATA_BUS_WD-1:0] s_next_aligned_pkt_data;
wire                 [NW-1:0] s_next_aligned_pkt_dwen;

// ===============================================================================================================
//        Data Alignment Logic
// ===============================================================================================================

// The shift alignment is done to read  out data.
// The alignment is required due to the split of a transaction.
// There are holes created within a bus width where a particular dword may not be enabled when received responses
// Therefore, we need to shift the data to make  up the holes.
// In general, the scheme used here is to shift data left to align with the most significant dword location.


assign  s_rd_dwen_all_ones = &in_pkt_dwen;

always @(*) begin : COMB_S_RD_DATA_VALID_DW_CNT_PROC

  integer i;

  s_rd_data_valid_dw_cnt    = {(DW_CNT_WD+1){1'b0}};

  for(i=0; i<NW; i=i+1) begin
    if(in_pkt_dv && in_pkt_dwen[i])
      s_rd_data_valid_dw_cnt = s_rd_data_valid_dw_cnt + 1;     // increment the counter for every DW enable bit set to 1
  end

end


always @(posedge clk or negedge rst_n) begin: SEQ_PROC_R_DW_SHIFT_LEFT_PROC
  if (!rst_n) begin
    r_dw_shift_left <= #TP 0;
  end else if (!in_halt || !aligned_pkt_dv) begin
    if (s_next_aligned_pkt_eot) begin                                           // if at the end of the TLP
      r_dw_shift_left <= #TP 0;                                                 //   reset the 
    end else if (!s_rd_dwen_all_ones) begin                                     // else if a beat with empty DWs is received
      r_dw_shift_left <= #TP s_rd_data_valid_dw_cnt;                            //   load the number of valid DWs in that beat
    end
  end
end

assign s_dw_shift_left      = r_dw_shift_left;
assign s_dw_shift_right     = ({1'b1,{(DW_CNT_WD){1'b0}}} - r_dw_shift_left);

always @(posedge clk or negedge rst_n) begin: SEQ_PREVIOUS_VALID_RD_DATA_PROC
  if (!rst_n) begin
    r_previous_valid_rd_data   <= #TP BUS_INIT;
    r_previous_valid_rd_dwen   <= #TP 0;
  end else if (!in_halt || s_accept_data_beat) begin
    r_previous_valid_rd_data   <= #TP right_shifted_rd_data;
    r_previous_valid_rd_dwen   <= #TP right_shifted_rd_dwen;
  end
end

assign s_current_valid_dw_cnt = ( NW==1 ) ? {(DW_CNT_WD+1){1'b0}} : ({1'b0,s_dw_shift_left} +  {1'b0,s_rd_data_valid_dw_cnt});
assign s_insert_wait_cycle    = ( NW==1 ) ?                1'b0   : ( s_current_valid_dw_cnt < {2'b01,{(DW_CNT_WD){1'b0}}} );
assign s_insert_extra_cycle   = ( NW==1 ) ?                1'b0   : ( s_current_valid_dw_cnt > {2'b01,{(DW_CNT_WD){1'b0}}} );


// Process of Read STATE machine
always @(posedge clk or negedge rst_n) begin : SEQ_ALIGN_STATE_PROC
  if (!rst_n)
    align_state <= #TP S_ALIGN_IDLE;
  else
    align_state <= #TP next_align_state;
end


always @(*) begin : COMB_ALIGN_STATE_PROC

      case (align_state)
        S_ALIGN_IDLE:                                                           // When in idle state we monitor the input waiting for a TLP to process
            begin
              if (in_pkt_dv && in_pkt_eot)                                      //   if dv and eot are set at the same time then
                next_align_state    = S_SINGLE_BEAT;                            //     it's a single beat TLP
              else if (in_pkt_dv && !in_pkt_eot && s_insert_wait_cycle)         //   else if dv is set, eot is not set and there are empty DWs in the first input beat
                next_align_state    = S_FIRST_BEAT_WAIT_DATA;                   //     it's a multi-beat TLP, go into a wait cycle and wait for the second input beat so enough data is available for the first output beat
              else if (in_pkt_dv && !in_pkt_eot && !s_insert_wait_cycle)        //   else if dv is set, eot is not set and there are no empty DWs in the first input beat
                next_align_state    = S_FIRST_BEAT;                             //     it's a multi-beat TLP, issue the first output beat
              else                                                              //   else (dv is not set)
                next_align_state    = S_ALIGN_IDLE;                             //     there's no TLP to process so stay in idle state
            end
        S_SINGLE_BEAT:                                                          // While processing a single beat TLP we monitor the input so we can start processing any subsequent TLP already on the next cycle if required
            begin
              if (!in_halt) begin                                               //   if the current output beat is accepted
                if (!in_pkt_dv)                                                 //     if no more data is received (dv is not set)
                  next_align_state    = S_ALIGN_IDLE;                           //       then we go to idle and wait for the first beat of the next TLP
                else if (in_pkt_dv && in_pkt_eot)                               //     else if dv and eot are set at the same time then
                  next_align_state  = S_SINGLE_BEAT;                            //       there's a new single beat TLP after the one currently being processed so stay in this state
                else if (in_pkt_dv && !in_pkt_eot && s_insert_wait_cycle)       //     else if dv is set, eot is not set and there are empty DWs in the first input beat of the next TLP
                  next_align_state  = S_FIRST_BEAT_WAIT_DATA;                   //       go into a wait cycle and wait for the second input beat so enough data is available for the first output beat
                else // (in_pkt_dv && !in_pkt_eot && !s_insert_wait_cycle)      //     else if dv is set, eot is not set and there are no empty DWs in the first input beat of the next TLP
                  next_align_state  = S_FIRST_BEAT;                             //       issue the first output beat
              end else                                                          //   else (current output beat is not accepted)
                next_align_state    = S_SINGLE_BEAT;                            //     stay in this state until it is
            end
        S_FIRST_BEAT_WAIT_DATA:                                                 // While waiting for the second input beat to gather enough data to be able to issue the first output beat
            begin
              if (in_pkt_dv && !in_pkt_eot)                                     //   if the second beat is received with dv set but with eot not set 
                next_align_state    = S_FIRST_BEAT;                             //     this is a multi beat TLP so process this beat as the first one
              else if (in_pkt_dv && in_pkt_eot && !s_insert_extra_cycle)        //   else if both dv and eot are set on the second beat and no data will be left after the first output beat is issued
                next_align_state    = S_SINGLE_BEAT;                            //     this is effectively a single beat TLP
              else if (in_pkt_dv && in_pkt_eot && s_insert_extra_cycle)         //   else if both dv and eot are set on the second beat and data will be left after the first output beat is issued
                next_align_state    = S_FIRST_TO_EXTRA_BEAT;                    //     we will need to insert an extra output beat after the first one
              else                                                              //   else (dv is not set)
                next_align_state    = S_ERROR;                                  //     then it's an error condition as data should always be available until the last beat is issued
            end
        S_FIRST_BEAT:                                                           // When processing the first beat
            begin
              if (!in_halt) begin                                               //   if the current output beat is accepted
                if (in_pkt_dv && !in_pkt_eot && s_insert_wait_cycle)            //     if the next input beat is received (dv is set) with eot not set and with empty DWs
                  next_align_state  = S_INTMD_BEAT_WAIT_DATA;                   //       go into a wait cycle and wait for one more input beat so enough data is available for the next output beat
                else if (in_pkt_dv && !in_pkt_eot && !s_insert_wait_cycle)      //     else if the next input beat is received (dv is set) with eot not set and without empty DWs
                  next_align_state  = S_INTMD_BEAT;                             //       the next output beat is not the last one, process it as an intermediate beat
                else if (in_pkt_dv && in_pkt_eot && s_insert_extra_cycle)       //     else if the next input beat is received (dv is set) with eot set and data will be left after the intermediate output beat is issued
                  next_align_state  = S_INTMD_TO_EXTRA_BEAT;                    //       we will need to insert an extra output beat after the intermediate one
                else if (in_pkt_dv && in_pkt_eot && !s_insert_extra_cycle)      //     else if the next input beat is received (dv is set) with eot set and no data will be left after the current output beat is issued
                  next_align_state  = S_FINAL_BEAT;                             //       the next output beat is the last one, process it as such
                else                                                            //     else (dv is not set)
                  next_align_state  = S_ERROR;                                  //       then it's an error condition as data should always be available until the last beat is issued
              end else                                                          //   else (current output beat is not accepted)
                next_align_state    = S_FIRST_BEAT;                             //     stay in this state until it is
            end
        S_FIRST_TO_EXTRA_BEAT:                                                  // When we are processing the first beat and know we need to generate an extra beat afterwards
            begin
              if (!in_halt) begin                                               //   if the current output beat is accepted
                next_align_state    = S_EXTRA_BEAT;                             //     we don't need to wait for any more data, the eot was already received so we can issue the extra beat as soon as the first one is accepted
              end else                                                          //   else (current output beat is not accepted)
                next_align_state    = S_FIRST_TO_EXTRA_BEAT;                    //     stay in this state until it is
            end
        S_INTMD_BEAT_WAIT_DATA:                                                 // While waiting for an input beat to gather enough data to be able to issue an intermediate beat
            begin
              if (in_pkt_dv && !in_pkt_eot)                                     //   if the next input beat is received (dv is set) with eot not set 
                next_align_state    = S_INTMD_BEAT;                             //     we have all the data we need so issue the intermediate output beat
              else if (in_pkt_dv && in_pkt_eot && s_insert_extra_cycle)         //   else if the next input beat is received (dv is set) with eot set and data will be left after the intermediate output beat is issued
                next_align_state    = S_INTMD_TO_EXTRA_BEAT;                    //     we will need to insert an extra output beat after the intermediate one
              else if (in_pkt_dv && in_pkt_eot && !s_insert_extra_cycle)        //   else if the next input beat is received (dv is set) with eot set and no data will be left after the current output beat is issued
                next_align_state    = S_FINAL_BEAT;                             //     it's no longer an intermediate beat, it's the last one; we have all the data we need to  issue it
              else                                                              //   else (dv is not set)
                next_align_state    = S_ERROR;                                  //     then it's an error condition as data should always be available until the last beat is issued
            end
        S_INTMD_BEAT:                                                           // When processing an intermediate beat
            begin
              if (!in_halt) begin                                               //   if the current output beat is accepted
                if (in_pkt_dv && !in_pkt_eot && s_insert_wait_cycle)            //     if the next input beat is received (dv is set) with eot not set and with empty DWs
                  next_align_state  = S_INTMD_BEAT_WAIT_DATA;                   //       go into a wait cycle and wait for one more input beat so enough data is available for the next output beat
                else if (in_pkt_dv && !in_pkt_eot && !s_insert_wait_cycle)      //     else if the next input beat is received (dv is set) with eot not set and without empty DWs
                  next_align_state  = S_INTMD_BEAT;                             //       the next output beat is not the last one, process it as an intermediate beat
                else if (in_pkt_dv && in_pkt_eot && !s_insert_extra_cycle)      //     else if the next input beat is received (dv is set) with eot set and no data will be left after the current output beat is issued
                  next_align_state  = S_FINAL_BEAT;                             //       the next output beat is the last one, process it as such
                else if (in_pkt_dv && in_pkt_eot && s_insert_extra_cycle)       //     else if the next input beat is received (dv is set) with eot set and data will be left after the current output beat is issued
                  next_align_state  = S_INTMD_TO_EXTRA_BEAT;                    //       we will need to insert an extra output beat after the intermediate one
                else                                                            //     else (dv is not set)
                  next_align_state  = S_ERROR;                                  //       then it's an error condition as data should always be available until the last beat is issued
              end else                                                          //   else (current output beat is not accepted)
                next_align_state    = S_INTMD_BEAT;                             //     stay in this state until it is
            end
        S_INTMD_TO_EXTRA_BEAT:                                                  // When we are processing an intermediate beat and know we need to generate an extra beat afterwards
            begin
              if (!in_halt) begin                                               //   if the current output beat is accepted
                next_align_state    = S_EXTRA_BEAT;                             //     we don't need to wait for any more data, the eot was already received so we can issue the extra beat as soon as the first one is accepted
              end else                                                          //   else (current output beat is not accepted)
                next_align_state    = S_INTMD_TO_EXTRA_BEAT;                    //     stay in this state until it is
            end
        S_FINAL_BEAT:                                                           // When processing the last beat
            begin
              if (!in_halt) begin                                               //   if the current output beat is accepted
                if (!in_pkt_dv)                                                 //     if no more data is received (dv is not set)
                  next_align_state  = S_ALIGN_IDLE;                             //       then we go to idle and wait for the first beat of the next TLP
                else if (in_pkt_dv && in_pkt_eot)                               //     else if data is received (dv is set) and eot is set
                  next_align_state  = S_SINGLE_BEAT;                            //       we immediately start to process the next TLP which is single-beat
                else if (in_pkt_dv && !in_pkt_eot && s_insert_wait_cycle)       //     else if data is received (dv is set), eot is not set and there are empty DWs in the first input beat
                  next_align_state  = S_FIRST_BEAT_WAIT_DATA;                   //       it's a multi-beat TLP, go into a wait cycle and wait for the second input beat so enough data is available for the first output beat
                else // (in_pkt_dv && !in_pkt_eot && !s_insert_wait_cycle)      //     else if dv is set, eot is not set and there are no empty DWs in the first input beat
                  next_align_state  = S_FIRST_BEAT;                             //       it's a multi-beat TLP, issue the first output beat
              end else                                                          //   else (current output beat is not accepted)
                next_align_state    = S_FINAL_BEAT;                             //     stay in this state until it is
            end
        S_EXTRA_BEAT:                                                           // When processing the extra beat
            begin
              if (!in_halt) begin                                               //   if the current output beat is accepted
                if (!in_pkt_dv)                                                 //     if no more data is received (dv is not set)
                  next_align_state  = S_ALIGN_IDLE;                             //       then we go to idle and wait for the first beat of the next TLP
                else if (in_pkt_dv && in_pkt_eot)                               //     else if data is received (dv is set) and eot is set
                  next_align_state  = S_SINGLE_BEAT;                            //       we immediately start to process the next TLP which is single-beat
                else if (in_pkt_dv && !in_pkt_eot && s_insert_wait_cycle)       //     else if data is received (dv is set), eot is not set and there are empty DWs in the first input beat
                  next_align_state  = S_FIRST_BEAT_WAIT_DATA;                   //       it's a multi-beat TLP, go into a wait cycle and wait for the second input beat so enough data is available for the first output beat
                else // (in_pkt_dv && !in_pkt_eot && !s_insert_wait_cycle)      //     else if dv is set, eot is not set and there are no empty DWs in the first input beat
                  next_align_state  = S_FIRST_BEAT;                             //       it's a multi-beat TLP, issue the first output beat
              end else                                                          //   else (current output beat is not accepted)
                next_align_state    = S_EXTRA_BEAT;                             //     stay in this state until it is
            end
        default:
            begin
              next_align_state      = S_ALIGN_IDLE;
            end
      endcase
end

assign s_accept_data_beat = (align_state == S_ALIGN_IDLE) || (align_state == S_FIRST_BEAT_WAIT_DATA) || (align_state == S_INTMD_BEAT_WAIT_DATA);

//  ===================================================================
//  Data Alignment
//  ===================================================================
  assign dw_shift_left              = s_dw_shift_left[DW_CNT_WD-1:0];
  assign left_shifted_rd_data       = in_pkt_data << (DBUS_DWORD_WD_WITH_PAR * dw_shift_left);
  assign int_previous_valid_rd_data = |dw_shift_left ? r_previous_valid_rd_data & L_DATA_LSHIFT[dw_shift_left] : r_previous_valid_rd_data;
  assign left_shifted_rd_dwen       = in_pkt_dwen << dw_shift_left;

  assign dw_shift_right             = s_dw_shift_right[DW_CNT_WD-1:0];
  assign right_shifted_rd_data      = |dw_shift_right ? (in_pkt_data >> DBUS_DWORD_WD_WITH_PAR*dw_shift_right) | (L_DATA_RSHIFT[dw_shift_right] & {CORE_DATA_BUS_WD{in_pkt_eot}}) : in_pkt_data;
  assign right_shifted_rd_dwen      = in_pkt_dwen >> dw_shift_right;

  assign s_next_aligned_pkt_hv   = (next_align_state == S_SINGLE_BEAT) || (next_align_state == S_FIRST_BEAT) || (next_align_state == S_FIRST_TO_EXTRA_BEAT);
  assign s_next_aligned_pkt_dv   = (next_align_state == S_SINGLE_BEAT) || (next_align_state == S_FIRST_BEAT) || (next_align_state == S_FIRST_TO_EXTRA_BEAT) || (next_align_state == S_INTMD_BEAT) || (next_align_state == S_INTMD_TO_EXTRA_BEAT)  || (next_align_state == S_FINAL_BEAT) || (next_align_state == S_EXTRA_BEAT);
  assign s_next_aligned_pkt_eot  = (next_align_state == S_SINGLE_BEAT)                                                                                                                                                                            || (next_align_state == S_FINAL_BEAT) || (next_align_state == S_EXTRA_BEAT);
  assign s_next_aligned_pkt_data = ( |s_dw_shift_left ? (left_shifted_rd_data | int_previous_valid_rd_data) : left_shifted_rd_data );
  assign s_next_aligned_pkt_dwen = ( |s_dw_shift_left ? (left_shifted_rd_dwen |   r_previous_valid_rd_dwen) : left_shifted_rd_dwen );

  always @(posedge clk or negedge rst_n) begin: SEQ_ALIGNED_PKT_PROC
    if (!rst_n) begin
      aligned_pkt_hv            <= #TP 0;
      aligned_pkt_dv            <= #TP 0;
      aligned_pkt_eot           <= #TP 0;
      aligned_pkt_data          <= #TP 0;
      aligned_pkt_dwen          <= #TP 0;
      aligned_pkt_err           <= #TP 0;
      aligned_pkt_hdr           <= #TP 0;
      aligned_pkt_tag           <= #TP 0;
      aligned_pkt_byte_len      <= #TP 0;
      aligned_pkt_low_addr      <= #TP 0;
      aligned_pkt_4rd           <= #TP 0;
      aligned_pkt_rreq_dma      <= #TP 0;
      aligned_pkt_rreq_dma_chan <= #TP 0;
    end else if (!in_halt || !aligned_pkt_dv) begin
      aligned_pkt_hv            <= #TP s_next_aligned_pkt_hv;
      aligned_pkt_dv            <= #TP s_next_aligned_pkt_dv;
      aligned_pkt_eot           <= #TP s_next_aligned_pkt_eot;
      aligned_pkt_data          <= #TP s_next_aligned_pkt_dv ? s_next_aligned_pkt_data : '0;
      aligned_pkt_dwen          <= #TP s_next_aligned_pkt_dv ? s_next_aligned_pkt_dwen : '0;
      if ((next_align_state == S_SINGLE_BEAT) || (next_align_state == S_FIRST_BEAT) || (next_align_state == S_FIRST_TO_EXTRA_BEAT)) begin
        aligned_pkt_err           <= #TP in_pkt_err;
        aligned_pkt_hdr           <= #TP in_pkt_hdr;
        aligned_pkt_tag           <= #TP in_pkt_tag;
        aligned_pkt_byte_len      <= #TP in_pkt_byte_len;
        aligned_pkt_low_addr      <= #TP in_pkt_low_addr;
        aligned_pkt_4rd           <= #TP in_pkt_4rd;
        aligned_pkt_rreq_dma      <= #TP in_pkt_rreq_dma;
        aligned_pkt_rreq_dma_chan <= #TP in_pkt_rreq_dma_chan;
      end else if (next_align_state==S_ALIGN_IDLE) begin
        aligned_pkt_err           <= #TP 0;
        aligned_pkt_hdr           <= #TP 0;
        aligned_pkt_tag           <= #TP 0;
        aligned_pkt_byte_len      <= #TP 0;
        aligned_pkt_low_addr      <= #TP 0;
        aligned_pkt_4rd           <= #TP 0;
        aligned_pkt_rreq_dma      <= #TP 0;
        aligned_pkt_rreq_dma_chan <= #TP 0;
      end
    end  
  end

assign out_halt = !((align_state == S_ALIGN_IDLE) || (align_state == S_FIRST_BEAT_WAIT_DATA) || (align_state == S_INTMD_BEAT_WAIT_DATA)) && ( in_halt || ( next_align_state == S_EXTRA_BEAT ) );

`ifndef SYNTHESIS
//VCS coverage off
wire    [32*8-1:0] ALIGN_STATE;
assign  ALIGN_STATE = ( align_state == S_ALIGN_IDLE           ) ? "S_ALIGN_IDLE"           :
                      ( align_state == S_SINGLE_BEAT          ) ? "S_SINGLE_BEAT"          :
                      ( align_state == S_FIRST_BEAT_WAIT_DATA ) ? "S_FIRST_BEAT_WAIT_DATA" :
                      ( align_state == S_FIRST_BEAT           ) ? "S_FIRST_BEAT"           :
                      ( align_state == S_FIRST_TO_EXTRA_BEAT  ) ? "S_FIRST_TO_EXTRA_BEAT"  :
                      ( align_state == S_INTMD_BEAT_WAIT_DATA ) ? "S_INTMD_BEAT_WAIT_DATA" :
                      ( align_state == S_INTMD_BEAT           ) ? "S_INTMD_BEAT"           :
                      ( align_state == S_INTMD_TO_EXTRA_BEAT  ) ? "S_INTMD_TO_EXTRA_BEAT"  :
                      ( align_state == S_FINAL_BEAT           ) ? "S_FINAL_BEAT"           :
                      ( align_state == S_EXTRA_BEAT           ) ? "S_EXTRA_BEAT"           :
                      ( align_state == S_ERROR                ) ? "S_ERROR"                :
                                                                   "";

//VCS coverage on
`endif // SYNTHESIS

endmodule

