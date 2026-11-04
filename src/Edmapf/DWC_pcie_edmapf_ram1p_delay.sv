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
// ---    $Revision: #5 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ram1p_delay.sv#5 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ram1p_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ram1p_delay #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter PW = 12
  ,parameter WD = 12
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_aclks_if.slave_mp  b_clk
  ,DWC_pcie_edmapf_ram1p_if.slave_mp  b_iram
  ,DWC_pcie_edmapf_ram1p_if.master_mp b_oram
  );


// SNPS_SysML_CODE_START
  typedef struct packed {
    logic [PW-1:0] addr        ;
    logic [WD-1:0] din         ;
    logic [WD-1:0] dout        ;
    logic          lock        ;
    logic          rden        ;
    logic          rdone       ;
    logic          wdone       ;
    logic          wren        ;
  } ram1p_s;

  ram1p_s r_ram;
  always_ff @ (posedge b_clk.w_aux_clk or negedge b_clk.w_reset_n) begin
    if (!b_clk.w_reset_n) begin
      r_ram <= # `TP '0;
    end else begin
      r_ram.addr          <= # `TP b_iram.w_addr        ;
      r_ram.din           <= # `TP b_iram.w_din         ;
      if (b_oram.w_rdone) begin
        r_ram.dout        <= # `TP b_oram.w_dout        ;
      end
      r_ram.lock          <= # `TP b_iram.w_lock        ;
      r_ram.rden          <= # `TP b_iram.w_rden        ;
      r_ram.rdone         <= # `TP b_oram.w_rdone       ;
      r_ram.wdone         <= # `TP b_oram.w_wdone       ;
      r_ram.wren          <= # `TP b_iram.w_wren        ;
    end
  end

  assign b_iram.w_dout        = r_ram.dout        ;
  assign b_iram.w_rdone       = r_ram.rdone       ;
  assign b_iram.w_wdone       = r_ram.wdone       ;
  
  assign b_oram.w_addr        = r_ram.addr        ;
  assign b_oram.w_din         = r_ram.din         ;
  assign b_oram.w_lock        = r_ram.lock        ;
  assign b_oram.w_rden        = r_ram.rden        ;
  assign b_oram.w_wren        = r_ram.wren        ;
 
// SNPS_SysML_CODE_END

endmodule
