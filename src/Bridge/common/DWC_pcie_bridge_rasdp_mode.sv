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
// ---    $DateTime: 2021/11/03 04:24:46 $
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/common/DWC_pcie_bridge_rasdp_mode.sv#5 $
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_bridge_rasdp_mode
  #(
    parameter EVENTB_WD = 16,
    parameter TP        = `TP
    )
   (
    input                 clk,
    input                 aresetn,

    input                 cfg_rasdp_err_mode_en,
    input                 i_rasdp_mode,
    input [EVENTB_WD-1:0] eventb,

    output                o_rasdp_mode
    );

   
   reg                    r_rasdp_mode;
   reg                    r_comb_rasdp_mode;
   reg                    s_comb_rasdp_mode;

   
   // registered version of rasdp mode
   always @ (posedge clk or negedge aresetn) begin : PROC_seq_r_rasdpmode
      if (!aresetn) begin
         r_rasdp_mode <= #TP 1'b0;
      end else begin
         r_rasdp_mode <= #TP i_rasdp_mode;
      end
   end

   always @ (posedge clk or negedge aresetn) begin : PROC_seq_rasdp_mode
      if (!aresetn) begin
         r_comb_rasdp_mode <= #TP 1'b0;
      end else begin
         r_comb_rasdp_mode <= #TP s_comb_rasdp_mode;
      end
   end

   always @ (*) begin : PROC_comb_rasdp_mode
      s_comb_rasdp_mode = r_comb_rasdp_mode;
      if (!cfg_rasdp_err_mode_en) begin
         s_comb_rasdp_mode = 1'b0;
      end else begin
         if (|eventb) begin
            s_comb_rasdp_mode = 1'b1;
         end
         if (r_rasdp_mode & !i_rasdp_mode) begin
            s_comb_rasdp_mode = 1'b0;
         end            
      end
   end

   
   assign o_rasdp_mode = s_comb_rasdp_mode | i_rasdp_mode;

endmodule
