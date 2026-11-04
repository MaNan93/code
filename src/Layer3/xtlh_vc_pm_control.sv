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
// ---    $DateTime: 2023/12/08 08:15:20 $
// ---    $Revision: #1 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/xtlh_vc_pm_control.sv#1 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
//  Power management control for vc packer module
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Layer3/xtlh_ms_pkg.svh"
`include "products/cx_pl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

module xtlh_vc_pm_control #(
  parameter TP  = `TP
) (
  input         core_clk,
  input         core_rst_n,
  input         p_fc_packer_pending,
  input         np_fc_packer_pending,
  input         cpl_fc_packer_pending,
  input         merge_pending,
  input         lp_req,
  output  logic xtlh_vc_pm_control_pending,
  output  logic xtlh_vc_pm_control_lp_ack,
  output  logic xtlh_vc_pm_control_lp_req
);

logic int_pending;
logic int_lp_ack;

assign int_pending = p_fc_packer_pending || np_fc_packer_pending || cpl_fc_packer_pending || merge_pending;

// Low Power Request Acknowledge
assign int_lp_ack = !int_pending;

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    xtlh_vc_pm_control_pending  <= #TP 1'b0;
  else
    xtlh_vc_pm_control_pending  <= #TP int_pending;
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    xtlh_vc_pm_control_lp_req <= #TP 1'b0;
  else begin
    if(xtlh_vc_pm_control_lp_req && !(lp_req || xtlh_vc_pm_control_lp_ack))
      xtlh_vc_pm_control_lp_req <= #TP 1'b0;
    else
      xtlh_vc_pm_control_lp_req <= #TP lp_req;
  end
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    xtlh_vc_pm_control_lp_ack <= #TP 1'b0;
  else begin
    if(!lp_req)
      xtlh_vc_pm_control_lp_ack <= #TP 1'b0;
    else
      xtlh_vc_pm_control_lp_ack <= #TP xtlh_vc_pm_control_lp_req && int_lp_ack;
  end
end

endmodule
