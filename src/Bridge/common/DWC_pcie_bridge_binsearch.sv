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
// ---    $Revision: #2 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/common/DWC_pcie_bridge_binsearch.sv#2 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Binary search; returns the index for the first result found on an input array
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
module DWC_pcie_bridge_binsearch (

    valid_in,
    array_in,
    valid_out,
    index_out,
    element_out

);

parameter  ARRAY_DP                      = 1024;
parameter  ARRAY_WD                      = 8;
parameter  INDEX_WD                      = 10;

input  [ARRAY_DP-1:0] valid_in;
input  [ARRAY_WD-1:0] array_in [ARRAY_DP-1:0];
output                valid_out;
output [INDEX_WD-1:0] index_out;
output [ARRAY_WD-1:0] element_out;

assign valid_out   = |valid_in;
assign index_out   = binsearch(valid_in);
assign element_out = array_in[index_out];

   //Do a binary search over the input array and find the index of the 1st valid entry
   function automatic [INDEX_WD-1:0] binsearch;
      input [ARRAY_DP-1:0] array_i;

      //This function is able to handle up to 1024 tags, internally it's fixed to 1024.
      //Un-used logic is tied to 0's, since it detects the first 1 in the LUT

      reg [1023:0]        array_int;
      
      //Search net matrix
      reg [1023:0]        matrix_0_search;
      reg [511:0]         matrix_1_search;
      reg [255:0]         matrix_2_search;
      reg [127:0]         matrix_3_search;
      reg [63:0]          matrix_4_search;
      reg [31:0]          matrix_5_search;
      reg [15:0]          matrix_6_search;
      reg [7:0]           matrix_7_search;
      reg [3:0]           matrix_8_search;
      reg [1:0]           matrix_9_search;

      //Mux selection for the search matrix
      reg [9:0]           mux_sel;      

      begin : func_binsearch
         array_int = {1024{1'b0}};
         array_int[ARRAY_DP-1: 0] = array_i[ARRAY_DP-1: 0];

         matrix_0_search[1023:0] = array_int;

         mux_sel[9] = !(|matrix_0_search[511:0]);
         matrix_1_search[511:0] = mux_sel[9] ? matrix_0_search[1023:512] : matrix_0_search[511:0];
         
         mux_sel[8] = !(|matrix_1_search[255:0]);
         matrix_2_search[255:0] = mux_sel[8] ? matrix_1_search[511:256] : matrix_1_search[255:0];
         
         mux_sel[7] = !(|matrix_2_search[127:0]);
         matrix_3_search[127:0] = mux_sel[7] ? matrix_2_search[255:128] : matrix_2_search[127:0];
         
         mux_sel[6] = !(|matrix_3_search[63:0]);
         matrix_4_search[63:0]  = mux_sel[6] ? matrix_3_search[127:64]  : matrix_3_search[63:0];
         
         mux_sel[5] = !(|matrix_4_search[31:0]);
         matrix_5_search[31:0]  = mux_sel[5] ? matrix_4_search[63:32]   : matrix_4_search[31:0];
         
         mux_sel[4] = !(|matrix_5_search[15:0]);
         matrix_6_search[15:0]  = mux_sel[4] ? matrix_5_search[31:16]   : matrix_5_search[15:0];
         
         mux_sel[3] = !(|matrix_6_search[7:0]);
         matrix_7_search[7:0]   = mux_sel[3] ? matrix_6_search[15:8]    : matrix_6_search[7:0];
         
         mux_sel[2] = !(|matrix_7_search[3:0]);
         matrix_8_search[3:0]   = mux_sel[2] ? matrix_7_search[7:4]     : matrix_7_search[3:0];
         
         mux_sel[1] = !(|matrix_8_search[1:0]);
         matrix_9_search[1:0]   = mux_sel[1] ? matrix_8_search[3:2]     : matrix_8_search[1:0];
         
         mux_sel[0] = !matrix_9_search[0];

         binsearch[INDEX_WD-1:0] = mux_sel[INDEX_WD-1:0];
         
      end 
      
   endfunction

endmodule

