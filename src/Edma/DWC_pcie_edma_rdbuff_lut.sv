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
// ---    $DateTime: 2022/04/14 09:36:50 $
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edma/DWC_pcie_edma_rdbuff_lut.sv#7 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"


 module DWC_pcie_edma_rdbuff_lut (
                                 // Inputs,
                                 clk,
                                 reset_n,
                                 rawreg2rdctrl_en,
                                 tmgr2lut_req,
                                 tmgr2lut_req_tag,
                                 tmgr2lut_req_seg_num,
                                 tmgr2lut_channel,
                                 ctrl2lut_cpl_tag,
                                 ctrl2lut_timeout_tag,
                                 ctrl2lut_error_tag,
                                 ctrl2lut_timeout_seg_num,
                                 ctrl2lut_timeout_seg_num_async,
                                 ctrl2lut_rd_seg_num_recycle,
                                 ctrl2lut_rd_seg_num,
                                 // Outputs
                                 lut2ctrl_req_seg_num,
                                 lut2ctrl_timeout_seg_num,
                                 lut2ctrl_timeout_chan_num,
                                 lut2ctrl_error_chan_num,
                                 lut2ctrl_channel,
                                 lut2ctrl_timeout_channel,
                                 lut2ctrl_timeout_channel_async,
                                 lut2ctrl_error
                                ,lut2ctrl_active
                                 );

//--------------------------------------------------------------------------------
// Parameter declarations
//--------------------------------------------------------------------------------
   parameter TP                         = `TP;

   parameter NUM_DMA_RD_TAG             = 16;
   parameter NUM_DMA_RD_TAG_WIDTH       = 4;

   parameter NUM_DMA_RD_SEGMENTS        = NUM_DMA_RD_TAG;
   parameter NUM_DMA_RD_SEGMENTS_WIDTH  = NUM_DMA_RD_TAG_WIDTH;

   parameter NUM_DMA_RD_CHAN_WIDTH      = 1;

   parameter DMA_RD_TAG_HIGH            = 31; // @CX_MAX_TAG
   parameter DMA_RD_TAG_HIGH_WIDTH      = 5;
   parameter DMA_RD_TAG_LOW             = 16; // @CX_MAX_TAG + 1 - @CC_NUM_DMA_RD_TAG

   parameter CX_TAG_SIZE                = `CX_TAG_SIZE;

//--------------------------------------------------------------------------------
// Input declarations
//--------------------------------------------------------------------------------
   input                                  clk;
   input                                  reset_n;
   input                                  rawreg2rdctrl_en;

   input                                  tmgr2lut_req;            // Consumed DMA Read request.
   input  [CX_TAG_SIZE-1:0]               tmgr2lut_req_tag;        // Consumed PCIe tag.
   input  [NUM_DMA_RD_SEGMENTS_WIDTH-1:0] tmgr2lut_req_seg_num;    // Consumed segment number.
   input  [NUM_DMA_RD_CHAN_WIDTH-1:0]     tmgr2lut_channel;        // Consumed channel number.

   input  [CX_TAG_SIZE-1:0]               ctrl2lut_cpl_tag;
   input  [CX_TAG_SIZE-1:0]               ctrl2lut_timeout_tag;
   input  [CX_TAG_SIZE-1:0]               ctrl2lut_error_tag;       // An error was received, supply the tag
   input  [NUM_DMA_RD_SEGMENTS_WIDTH-1:0] ctrl2lut_timeout_seg_num; // Cpl timeout segment number
   input  [NUM_DMA_RD_SEGMENTS_WIDTH-1:0] ctrl2lut_timeout_seg_num_async; // Asynchronous (immediate)

   input                                  ctrl2lut_rd_seg_num_recycle; // Recycle read segment number
   input  [NUM_DMA_RD_SEGMENTS_WIDTH-1:0] ctrl2lut_rd_seg_num;         // Read segment number

//--------------------------------------------------------------------------------
// Output declarations
//--------------------------------------------------------------------------------
   output [NUM_DMA_RD_SEGMENTS_WIDTH-1:0] lut2ctrl_req_seg_num;
   output [NUM_DMA_RD_SEGMENTS_WIDTH-1:0] lut2ctrl_timeout_seg_num;
   output [NUM_DMA_RD_CHAN_WIDTH-1:0]     lut2ctrl_timeout_chan_num;
   output [NUM_DMA_RD_CHAN_WIDTH-1:0]     lut2ctrl_error_chan_num; //One bit per channel (pulse based), decoded from ctrl2lut_error_tag
   output [NUM_DMA_RD_CHAN_WIDTH-1:0]     lut2ctrl_channel;
   output [NUM_DMA_RD_CHAN_WIDTH-1:0]     lut2ctrl_timeout_channel;
   output [NUM_DMA_RD_CHAN_WIDTH-1:0]     lut2ctrl_timeout_channel_async;
   output                                 lut2ctrl_error;
   output [NUM_DMA_RD_SEGMENTS-1:0]       lut2ctrl_active;


//--------------------------------------------------------------------------------
// Internal design
//--------------------------------------------------------------------------------
//--------------------------------------------------------------------------------
// Map the PCIe request tag to the corresponding channel and segment number
//--------------------------------------------------------------------------------
   reg [NUM_DMA_RD_SEGMENTS_WIDTH-1:0] seg_num_lut [DMA_RD_TAG_HIGH:DMA_RD_TAG_LOW];
   reg [NUM_DMA_RD_CHAN_WIDTH-1:0] chan_num_lut [DMA_RD_TAG_HIGH:DMA_RD_TAG_LOW];

   always @(posedge clk or negedge reset_n) begin: proc_seq_seg_num_lut
     integer i;

     if (!reset_n) begin
        for (i=DMA_RD_TAG_LOW; i<DMA_RD_TAG_HIGH+1; i=i+1) begin
            seg_num_lut[i] <= # TP {NUM_DMA_RD_SEGMENTS_WIDTH{1'b0}};
            chan_num_lut[i] <= # TP {NUM_DMA_RD_CHAN_WIDTH{1'b0}};
        end
     end else if(!rawreg2rdctrl_en) begin
        for (i=DMA_RD_TAG_LOW; i<DMA_RD_TAG_HIGH+1; i=i+1) begin
            seg_num_lut[i] <= # TP {NUM_DMA_RD_SEGMENTS_WIDTH{1'b0}};
            chan_num_lut[i] <= # TP {NUM_DMA_RD_CHAN_WIDTH{1'b0}};
        end
     end else begin
        for (i=DMA_RD_TAG_LOW; i<DMA_RD_TAG_HIGH+1; i=i+1) begin
           if ((i==tmgr2lut_req_tag) && tmgr2lut_req) begin
              seg_num_lut[i] <= # TP tmgr2lut_req_seg_num;
              chan_num_lut[i] <= # TP tmgr2lut_channel;
           end
        end
     end
   end

   // Extract LUT info when completion returns
   // Note: completions and timeouts can occur simultaneously.
   reg [NUM_DMA_RD_SEGMENTS_WIDTH-1:0] lut2ctrl_req_seg_num;
   reg [NUM_DMA_RD_SEGMENTS_WIDTH-1:0] lut2ctrl_timeout_seg_num;
   reg [NUM_DMA_RD_CHAN_WIDTH-1:0]     lut2ctrl_channel;
   reg [NUM_DMA_RD_CHAN_WIDTH-1:0]     lut2ctrl_error_chan_num;
   reg [NUM_DMA_RD_CHAN_WIDTH-1:0]     lut2ctrl_timeout_chan_num;



   always @( * ) begin : proc_comb_lut2ctrl_info
     integer i;

     // Initialise
     lut2ctrl_req_seg_num = {NUM_DMA_RD_SEGMENTS_WIDTH{1'b0}};
     lut2ctrl_timeout_seg_num = {NUM_DMA_RD_SEGMENTS_WIDTH{1'b0}};
     lut2ctrl_channel = {NUM_DMA_RD_CHAN_WIDTH{1'b0}};
     lut2ctrl_error_chan_num = {NUM_DMA_RD_CHAN_WIDTH{1'b0}};
     lut2ctrl_timeout_chan_num = {NUM_DMA_RD_CHAN_WIDTH{1'b0}};

     for (i=DMA_RD_TAG_LOW; i<DMA_RD_TAG_HIGH+1; i=i+1) begin
        if (i==ctrl2lut_cpl_tag) begin
          lut2ctrl_req_seg_num = seg_num_lut[i];
          lut2ctrl_channel = chan_num_lut[i];
        end

        if (i==ctrl2lut_timeout_tag) begin
           lut2ctrl_timeout_seg_num = seg_num_lut[i];
           lut2ctrl_timeout_chan_num = chan_num_lut[i];
        end

        if (i==ctrl2lut_error_tag) begin
           lut2ctrl_error_chan_num = chan_num_lut[i];
        end
     end
   end

//--------------------------------------------------------------------------------
// Map the PCIe segment number to the corresponding channel number.
// LUT used to extract channel number when timeout request pushed into read request queue.
//--------------------------------------------------------------------------------
   reg [NUM_DMA_RD_CHAN_WIDTH-1:0] timeout_chan_num_lut [NUM_DMA_RD_SEGMENTS-1:0];

   always @(posedge clk or negedge reset_n) begin: proc_seq_timeout_chan_num_lut
     integer i;

     if (!reset_n) begin
        for (i=0; i<NUM_DMA_RD_SEGMENTS; i=i+1) begin
            timeout_chan_num_lut[i] <= # TP {NUM_DMA_RD_CHAN_WIDTH{1'b0}};
        end
     end else if (!rawreg2rdctrl_en) begin
        for (i=0; i<NUM_DMA_RD_SEGMENTS; i=i+1) begin
            timeout_chan_num_lut[i] <= # TP {NUM_DMA_RD_CHAN_WIDTH{1'b0}};
        end
     end else begin
        for (i=0; i<NUM_DMA_RD_SEGMENTS; i=i+1) begin
           if ((i==tmgr2lut_req_seg_num) && tmgr2lut_req) begin
              timeout_chan_num_lut[i] <= # TP tmgr2lut_channel;
           end
        end
     end
   end

   assign lut2ctrl_timeout_channel       = timeout_chan_num_lut[ctrl2lut_timeout_seg_num];
   assign lut2ctrl_timeout_channel_async = timeout_chan_num_lut[ctrl2lut_timeout_seg_num_async];

//--------------------------------------------------------------------------------
// Detect LUT error conditions:
// - receive completion tag but no entry in LUT;
// - receive timeout tag but no entry in LUT;
// - receive request but request already outstanding.
// Note: requesting and recycling the same segment should never occur at the same time.
//--------------------------------------------------------------------------------
   reg [NUM_DMA_RD_SEGMENTS-1:0] seg_num_valid_vec;

   always @(posedge clk or negedge reset_n) begin: proc_seq_seg_num_valid
     integer i;

     if (!reset_n) begin
        for (i=0; i<NUM_DMA_RD_SEGMENTS; i=i+1) begin
            seg_num_valid_vec[i] <= # TP 1'b0;
        end
     end else if (!rawreg2rdctrl_en) begin
        for (i=0; i<NUM_DMA_RD_SEGMENTS; i=i+1) begin
            seg_num_valid_vec[i] <= # TP 1'b0;
        end
     end else begin
        for (i=0; i<NUM_DMA_RD_SEGMENTS; i=i+1) begin
           if ((i==tmgr2lut_req_seg_num) && tmgr2lut_req) begin
             seg_num_valid_vec[i] <= # TP 1'b1;
           end else if (ctrl2lut_rd_seg_num_recycle && (i==ctrl2lut_rd_seg_num)) begin
             seg_num_valid_vec[i] <= # TP 1'b0;
           end
        end
     end
   end

   assign lut2ctrl_error  = !seg_num_valid_vec[ctrl2lut_rd_seg_num] && ctrl2lut_rd_seg_num_recycle;
   assign lut2ctrl_active =  seg_num_valid_vec;



endmodule
