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
// ---    $DateTime: 2024/01/19 11:41:19 $
// ---    $Revision: #2 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DWC_pcie_ctl_cdc_mux.sv#2 $
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

module DWC_pcie_ctl_cdc_mux
 #(
   parameter WIDTH      = 8,
   parameter DEPTH      = 4,
   parameter ADDR_WIDTH = 2
  ) 
  (
   input   [DEPTH-1:0][WIDTH-1:0] mem_ary ,
   input   [ADDR_WIDTH-1:0]       rd_addr,
   input                          rd_n,
   output  [WIDTH-1:0]            rd_data
  );

// NAND first stage array; one NAND placed on the output of each FF
  wire [DEPTH-1:0][WIDTH-1:0] data_out_nand;

  generate
  genvar depth,width;

  for(width=0;width<WIDTH;width=width+1)begin : nand_array_width
    wire [DEPTH-1:0] data_out_nand_column;

    for(depth=0;depth<DEPTH;depth=depth+1)begin : nand_array_depth
      wire sel = (rd_addr == depth) && !rd_n;

      // library cell array, not allowed to be optimized by synthesis
      DWC_pcie_ctl_bcm00_nand
      
        u_data_out_nand (
                         .a ( sel                         ),
                         .b ( mem_ary      [depth][width] ),
                         .zn( data_out_nand[depth][width] )
                        );

      assign data_out_nand_column[depth] = data_out_nand[depth][width];
    end

    assign rd_data[width] = ~(&data_out_nand_column[DEPTH-1:0]); // second stage NAND; synthesis tool is allowed to optimize this logic

  end

  endgenerate

endmodule
