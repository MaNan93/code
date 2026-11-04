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
// ---    $DateTime: 2021/10/29 02:04:56 $
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/slave/DWC_pcie_axi_slv_upcnvrt.sv#6 $
// -------------------------------------------------------------------------
// ----------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
//
//  DWC_pcie_axi_slv_upcnvrt.v Verilog module for DW_pcie design. This module
//  converts input data and transfer parameters to output data that is wider
//  and maintains parameters. Module requires as a parameter the "Width Of
//  Number To Stack", which is:
//      Log2(OW / DW) = Log2((# Out Data Width)/(# In Data Width))
//
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"


 module DWC_pcie_axi_slv_upcnvrt (
            clk,
            rst_n,
            init_n,
            stall_in,
            data_vld_in,
            params_in,
            data_last_in,
            data_strb_in,
            data_ep_in,
            data_in,
            data_vld_out,
            params_out,
            data_last_out,
            data_strb_out,
            data_ep_out,
            data_out
            );

   // External Parameters
   parameter PW     =   9 ;     // Params Width
   parameter IR     =   4 ;     // Input Data Strobe Width
   parameter DW     =  32 ;     // Input Data Width
   parameter OW     =  64 ;     // Output Data Width
   parameter NW     =   1 ;     // Width Of Number To Stack
                                //  Log2(ON / IN)


   // Internal Parameters
   parameter NC     = OW / DW ; // Number Input Data To Stack
   parameter NS     = NC -  1 ; // Number Input Data To Save
   parameter SW     = DW * NS ; // Save Data Width
   parameter SS     = IR * NS ; // Save Strobe Width
   parameter OS     = NC * IR ; // Output Strobe Width

   parameter TP     = `TP; // Clock to Q delay (simulator insurance)

   localparam CX_RAS_PARITY_MODE = `CX_RAS_PARITY_MODE;

   localparam INBYTE = DW / 9; // Input N bytes
   localparam SNBYTE = SW / 9; // Saved N Bytes
   localparam [8:0] BUS_INIT_BYTE = CX_RAS_PARITY_MODE ? 9'b100000000 : 9'b000000000;

   // -----------------------------------------------------------------
   // Ports
   // -----------------------------------------------------------------
   input            clk;            // Sys Clock
   input            rst_n;          // Async Reset
   input            init_n;         // Sync Init
   input            stall_in;       // Stall In
   input            data_vld_in;    // Data Valid In
   input [PW-1:0]   params_in;      // Params In
   input            data_last_in;   // Data Last In
   input [IR-1:0]   data_strb_in;   // Data Strobes In
   input            data_ep_in;     // Data EP In
   input [DW-1:0]   data_in;        // Data  In

   output           data_vld_out;   // Data Valid Out
   output [PW-1:0]  params_out;     // Params Out
   output           data_last_out;  // Data Last Out
   output [OS-1:0]  data_strb_out;  // Data Strobes Out
   output           data_ep_out;    // Data EP Out
   output [OW-1:0]  data_out;       // Data Out


   // -----------------------------------------------------------------
   // Output Wires
   // -----------------------------------------------------------------
   wire             data_vld_out;   // Data Valid Out
   wire [PW-1:0]    params_out;     // Params Out
   wire             data_last_out;  // Data Last Out
   wire [OS-1:0]    data_strb_out;  // Data Strobes Out
   wire [OW-1:0]    data_out;       // Data Out


   // -----------------------------------------------------------------
   // Internal Signals
   // -----------------------------------------------------------------
   wire [NW-1:0]    count_nxt;      // Next Count
   reg [NW-1:0]     count;          // Select Count
   wire             end_det;        // End Det

   wire             not_first_nxt;  // Not First Chunk Next
   reg              not_first;      // Not First Chunk
   wire             act_xfer_nxt;   // Active Transfer Next
   reg              act_xfer;       // Active Transfer
   wire             new_params_det; // New Params Det
   wire             sav_params_det; // Save Params Det
   wire [PW-1:0]    sav_params_nxt; // Save Params Next
   reg [PW-1:0]     sav_params;     // Save Params

   reg [OS-1:0]     strb_sel;       // Strobe Select
   reg [SS-1:0]     sav_strb_sel;   // Save Data Valid Select
   wire [SS-1:0]    sav_strb_nxt;   // Save Data Valid Next
   reg [SS-1:0]     sav_strb;       // Save Data


   reg [OW-1:0]     data_sel;       // Save Data Select
   reg [SW-1:0]     sav_data_sel;   // Save Data Select
   wire [SW-1:0]    sav_data_nxt;   // Save Data Next
   reg [SW-1:0]     sav_data;       // Save Data

   reg              r_data_ep_out;

   // -----------------------------------------------------------------
   // Design Block
   // -----------------------------------------------------------------

   // End Detect
   // Last In Forces Completion
   assign end_det = data_last_in || (count == (NW-1));

   // Count Valid Data Inputs
   // Uses Realign To Set
   assign count_nxt = (!data_vld_in || stall_in) ? count :
                  end_det ? {NW{1'b0}} :
                  (count  + 1'b1);


   // Determine Phases Of Transfer

   // Determine When Not First Part of Output Data
   assign not_first_nxt = (data_vld_out && !stall_in) ? 1'b0 :
                          data_vld_in ? 1'b1 : not_first;

   // Determine Transfer Active
   assign act_xfer_nxt = (data_vld_out && !stall_in && end_det) ? 1'b0 :
                     data_vld_out ? 1'b1 : act_xfer;

   // Control Release Of Transfer Parameters
   // Akways Updates With First Data Out

   // New Parameters Detection
   assign new_params_det = (data_vld_in && !not_first && !act_xfer);

   // Save Parameters Detection
   assign sav_params_det = (new_params_det &&
                 !(end_det && !stall_in));

   // Save Parameters
   assign sav_params_nxt = sav_params_det ? params_in : sav_params;

   // Parameters Out
   assign params_out = (new_params_det && end_det) ? params_in :
                   sav_params;


   // Next Data Select Mux
   always @(*) begin : data_sel_mux_seq_PROC

      integer      ds;
      integer      i;
      integer      j;
      reg [NW-1:0] dsel_chk;

      dsel_chk     = {NW{1'b0}};
      strb_sel     = {{IR{1'b0}}, sav_strb};
      data_sel     = {{INBYTE{BUS_INIT_BYTE}}, sav_data};

      for(ds=0; ds < (NC); ds=ds+1) begin

         // Update Save Data
        if (data_vld_in) begin
          if (dsel_chk == count) begin

             for(i=0; i < (IR); i=i+1) begin
               strb_sel[(ds * IR) + i] = data_strb_in[i];
             end

             for(j=0; j < (DW); j=j+1) begin
               data_sel[(ds * DW) + j] = data_in[j];
             end
          end
        end

        // Advance data select if not finsihed
        if (dsel_chk < NC) begin
          dsel_chk = dsel_chk + 1'b1;
        end

      end

      sav_strb_sel = strb_sel[SS-1:0];
      sav_data_sel = data_sel[SW-1:0];

   end

   // Facilitate Clock Gating On Save Strobes
   // Also, Saved Strobes Must Be Zeroed On Output
   assign sav_strb_nxt = (data_vld_out && !stall_in) ? {SS{1'b0}} : data_vld_in ? sav_strb_sel : sav_strb;

   // Facilitate Clock Gating On Save Data
   assign sav_data_nxt = (data_vld_out && !stall_in) ? {SNBYTE{BUS_INIT_BYTE}} : data_vld_in ? sav_data_sel : sav_data;

   // Data Valid Out
   assign data_vld_out = (data_vld_in && end_det);

   // Data Last Out
   assign data_last_out = data_last_in;

   // Data Strobes Out
   assign data_strb_out = strb_sel;

   // EP bit out
   always@(posedge clk or negedge rst_n) begin : r_data_ep_out_seq_PROC
     if (rst_n == 1'b0) begin
       r_data_ep_out      <= #TP 1'b0;
     end else begin
       if(data_vld_in && !stall_in)begin
         if(data_last_in)
           r_data_ep_out      <= #TP 1'b0;
         else
           r_data_ep_out      <= #TP r_data_ep_out || data_ep_in;
       end
     end
   end

   assign data_ep_out = r_data_ep_out || data_ep_in;

   // Data Out
   assign data_out = data_sel;


  // Main Sequential Process
  always @(posedge clk or negedge rst_n) begin : gs_upcnvrt_seq_PROC
     if (rst_n == 1'b0) begin
       count      <= #TP {NW{1'b0}};
       not_first  <= #TP 1'b0;
       act_xfer   <= #TP 1'b0;
       sav_params <= #TP {PW{1'b0}};
       sav_strb   <= #TP {SS{1'b0}};
       sav_data   <= #TP {SNBYTE{BUS_INIT_BYTE}};
     end
     else begin
       count      <= #TP ({NW{init_n}} & count_nxt);
       not_first  <= #TP (init_n && not_first_nxt);
       act_xfer   <= #TP (init_n && act_xfer_nxt);
       sav_params <= #TP ({PW{init_n}} & sav_params_nxt);
       sav_strb   <= #TP ({SS{init_n}} & sav_strb_nxt);
       sav_data   <= #TP init_n ? sav_data_nxt : {SNBYTE{BUS_INIT_BYTE}};
     end
  end

endmodule

