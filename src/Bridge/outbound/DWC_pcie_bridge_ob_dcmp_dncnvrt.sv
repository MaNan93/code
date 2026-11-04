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

//  ------------------------------------------------------------------------
//
//                    (C) COPYRIGHT 2014 SYNOPSYS, INC.
//                            ALL RIGHTS RESERVED
//
//  This software and the associated documentation are confidential and
//  proprietary to Synopsys, Inc.  Your use or disclosure of this
//  software is subject to the terms and conditions of a written
//  license agreement between you, or your company, and Synopsys, Inc.
//
// The entire notice above must be reproduced on all authorized copies.
//
//  ------------------------------------------------------------------------

// -------------------------------------------------------------------------
// ---  RCS information:
// ---    $DateTime: 2022/04/14 09:36:50 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/outbound/DWC_pcie_bridge_ob_dcmp_dncnvrt.sv#4 $
// -------------------------------------------------------------------------
// ----------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
//
//  DWC_pcie_decomp_dwncnvrt.v, this Verilog module is intended for the DW_pcie
//  design. This perpose of this module is to downsize the input data of width
//  IW onto the output data bus in chunks of OW width.
//  IW and OW must be log2 values.
//  This Module requires, as a parameter, the number of chunks required to
//  convert between the source and destination or the "Width Of Number To
//  Unstack", which is:
//                       Log2(IW / OW)
//
//  Obviously, IW must be larger than OW. Intended to take data from FIFO
//  output.
//
//  Modification History :
//
//  18/11/08 - Initial Release by MW.
//
// ----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"


 module DWC_pcie_bridge_ob_dcmp_dncnvrt (
    clk,
    rst_n,
    halt_in,
    data_byte_len,
    outq_pkt_hv,
    outq_pkt_dv,
    outq_pkt_eot,
    data_in,
    // Outputs
    halt_out,
    data_out,
    hv_out,
    dv_out,
    eot_out
  );

  // -----------------------------------------------------------------
  // External Parameters
  // -----------------------------------------------------------------
  parameter IW     =  64 ;     // Input Data Width
  parameter OW     =  32 ;     // Output Data Width
  parameter DOWN_CONVERSION_RATIO_WD = 1 ;     // log2(IW/OW)
  parameter PKT_LEN_WD     =  13 ;     // log2(DWord length expressed in bytes)

  // -----------------------------------------------------------------
  // Internal Parameters
  // -----------------------------------------------------------------
  parameter TP = `TP;
  // Down conversion ratio
  parameter DOWN_CONVERSION_RATIO = IW/OW;
  // Number of down converted DWORDS per cycle
  parameter DOWN_CVRTD_DWORDS_PER_CYC = `CX_NW;

  localparam NUMBER_OUTPUT_BYTES = `PCIE_CORE_DATA_BUS_WD / 8;

  // -----------------------------------------------------------------
  // Ports
  // -----------------------------------------------------------------
  input  wire                  clk;           // Sys Clock
  input  wire                  rst_n;         // Async Reset
  input  wire                  halt_in;       // Halt due to decomposer
  input  wire [PKT_LEN_WD-1:0] data_byte_len; // DWord length expressed in bytes
  input  wire                  outq_pkt_hv;
  input  wire                  outq_pkt_dv;   // OutQ State data valid indication
  input  wire                  outq_pkt_eot;   // OutQ State end of transfer indication
  input  wire [IW-1:0]         data_in;       // Data

  output wire                  halt_out;      // Halt due to downsizing
  output reg  [OW-1:0]         data_out;      // Data
  output wire                  hv_out;
  output wire                  dv_out;
  output wire                  eot_out;

  // -----------------------------------------------------------------
  // Internal Wires/Regs
  // -----------------------------------------------------------------
   reg [DOWN_CONVERSION_RATIO_WD:0] dword_slice_ptr_r;
   reg [IW-1:0]                     data_in_r;
   wire [IW-1:0]                    data_int;

   wire [PKT_LEN_WD-1:0]            s_data_byte_cnt;
   reg [PKT_LEN_WD-1:0]             r_data_byte_cnt;

   wire                             last_dword_slice;
   wire                             first_dword_slice;

  // -----------------------------------------------------------------
  // Capture data
  // -----------------------------------------------------------------
   always @(posedge clk or negedge rst_n) begin : proc_seq_data_in_r
      if (!rst_n) begin
        data_in_r <= # TP 0;
      end else if (outq_pkt_dv) begin
        data_in_r <= # TP data_in;
      end
   end

   assign data_int = outq_pkt_dv ? data_in : data_in_r;

   //--------------------------------------------------------------------
   // Pointer to down converted DWORD slice
   //--------------------------------------------------------------------
   always @(posedge clk or negedge rst_n) begin : proc_seq_dword_slice_ptr_r
      if (!rst_n) begin
        dword_slice_ptr_r <= # TP 0;
      end else begin
        if(!halt_in) begin
          if ((dword_slice_ptr_r == DOWN_CONVERSION_RATIO-1) || last_dword_slice)begin
            dword_slice_ptr_r <= # TP 0;
          end else if (outq_pkt_dv) begin
            dword_slice_ptr_r <= # TP dword_slice_ptr_r + 1;
     end
   end
      end
   end

   //--------------------------------------------------------------------
   // Counter for remaining bytes
   //--------------------------------------------------------------------
   always @(posedge clk or negedge rst_n) begin : proc_seq_r_data_byte_cnt
      if (!rst_n) begin
        r_data_byte_cnt <= # TP 0;
      end else begin
        if(!halt_in) begin
     if(outq_pkt_dv)begin
       r_data_byte_cnt <= # TP s_data_byte_cnt - NUMBER_OUTPUT_BYTES;
     end else begin
       r_data_byte_cnt <= # TP 0;
     end
   end else begin
     r_data_byte_cnt <= # TP r_data_byte_cnt;
        end
      end
   end

   assign s_data_byte_cnt   = first_dword_slice ? data_byte_len : r_data_byte_cnt;

   assign first_dword_slice = outq_pkt_hv && dword_slice_ptr_r == 0;
   assign last_dword_slice  = (s_data_byte_cnt <= NUMBER_OUTPUT_BYTES);

   // -----------------------------------------------------------------
   // Data Select Mux
   // -----------------------------------------------------------------
   always @ (*) begin : proc_comb_data_out_sel_mux
     integer i,j;

     // Initialise
     data_out = 0;

     // Search for down converted DWord slice
     for(i=0; i < (DOWN_CONVERSION_RATIO); i=i+1) begin
       if (dword_slice_ptr_r==(i)) begin
         // Select DWord slice
         for(j=0; j < (OW); j=j+1) begin
           data_out[j] = data_int[(i * OW) + j];
         end
       end
     end
   end

   //--------------------------------------------------------------------
   // Generate halt out
   //--------------------------------------------------------------------
   assign halt_out = halt_in || ((outq_pkt_dv && (dword_slice_ptr_r < ( DOWN_CONVERSION_RATIO-1))) && !last_dword_slice);

   //--------------------------------------------------------------------
   // Generate dv out
   //--------------------------------------------------------------------
   assign dv_out   = outq_pkt_dv;

   //--------------------------------------------------------------------
   // Generate eot out
   //--------------------------------------------------------------------
   assign eot_out  = last_dword_slice && outq_pkt_eot;

   //--------------------------------------------------------------------
   // Generate hv out
   //--------------------------------------------------------------------
   assign hv_out   = first_dword_slice;


endmodule
