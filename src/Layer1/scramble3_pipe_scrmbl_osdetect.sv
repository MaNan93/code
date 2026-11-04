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
// ---    $DateTime: 2023/12/22 07:15:34 $
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/scramble3_pipe_scrmbl_osdetect.sv#6 $
// -------------------------------------------------------------------------
//
// Description :pipe_scrmbl_osdetect generates three signals indicating the 
// begining/end (one pulse wide) and active OS (high during the OS
//
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module scramble3_pipe_scrmbl_osdetect
  #(parameter REGIN  = 1,
    parameter REGOUT = 1,
    parameter TP     = `TP
   )
   (
  input wire core_clk,
  input wire core_rst_n,
  input wire scramble_en,
  input wire os_detect, 
  input wire in_startblock,
  input wire in_aligned,
  output wire int_os_active,
  output wire os_active
   );
   
  // os_start is the same as startblock once the OS once is  detected  
  // os_active is a signal which gets trigered  by os_detect
  // and gets deasserted by the next startblock
  reg int_os_active_reg;

  always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n)
      int_os_active_reg <= #TP 1'b0;
    else
      if( scramble_en ) begin
      //must be reset to 0 if outside in_aligned (phy_mac_rxvalid)
        int_os_active_reg <= #TP (os_detect | (int_os_active & !in_startblock)) & in_aligned;
      end
  end

generate if (REGIN==1) begin : gen_regin_on
  assign int_os_active = int_os_active_reg;
end else begin : gen_regin_off
  assign int_os_active = (os_detect | (int_os_active_reg & !in_startblock)) & in_aligned & scramble_en;
end endgenerate

  // to align the os_start with the outgoing data
  // we have to stage them accordingly
  // int_os_start needs to be delayed to cycles
generate if (REGOUT==1) begin : gen_regout_on
  reg os_active_reg;

  always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
      os_active_reg <= #TP 1'b0;
    end
    else begin
      if( scramble_en ) begin
        os_active_reg <= #TP int_os_active;
      end
    end
  end

  assign os_active = os_active_reg;
end else begin : gen_regout_off
  assign os_active = int_os_active;
end endgenerate

endmodule
////////////////////////////////////////////////////////////////////////////// 
