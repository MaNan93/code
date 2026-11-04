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
// ---    $DateTime: 2023/09/27 02:27:25 $
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/pipe_regif_phy_shadow_reg.sv#6 $
// --------------------------------------------------------------------------------------------
// --- Module Description: Sub-module of pipe_regif_mst
// --------------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "common/pipe_regif_pkg.svh"

module pipe_regif_phy_shadow_reg

import pipe_regif_pkg::*;
#(
  parameter bit [7:0]         REG_DEFAULT = 8'h0,
  parameter reg_attr_e [7:0]  REG_ATTR = {8{RESERVED}}
) 
                                (
  // ------------ inputs ---------------
  input logic         clk,
  input logic         rst_n,
  input logic         ce,
  input logic [7:0]   clr,
  input logic [7:0]   den,
  input logic [7:0]   din,
  input logic         ack,
  // ------------ outputs ---------------
  output logic [7:0]  dout,
  output logic        req
);

  localparam  TP = `TP;

  logic        we;
  logic        detect_chg;
  logic [7:0]  detect_chgs;
  assign we = (req) ? ack : 1'h1;
  assign detect_chg = (|detect_chgs);

  always_ff @(posedge clk or negedge rst_n) begin: req_PROC
    if(!rst_n) begin
      req <= #TP '0;
    end
    else if(ce) begin
      if(we) begin
        req <= #TP detect_chg;
      end
    end
  end: req_PROC

  logic [7:0]  buf_reg;

  always_ff @(posedge clk or negedge rst_n) begin: buf_reg_PROC
    if(!rst_n) begin
      buf_reg <= #TP REG_DEFAULT;
    end
    else if(ce) begin
      if(|clr) begin
        buf_reg <= #TP (buf_reg & ~clr) ^ (clr & REG_DEFAULT);
      // ccx_cond: ; 0; 00+01; "Possible redundant condition. Due to property of MAC register."
      end else if(we || !detect_chg) begin
        buf_reg <= #TP (buf_reg & ~den) ^ (din & den);
      end
    end
  end: buf_reg_PROC

  logic [7:0]  phy_shadow_reg;
  assign dout = phy_shadow_reg;

  always_ff @(posedge clk or negedge rst_n) begin: phy_shadow_reg_PROC
    if(!rst_n) begin
      phy_shadow_reg <= #TP REG_DEFAULT;
    end
    else if(ce) begin
      if(|clr) begin
        phy_shadow_reg <= #TP (phy_shadow_reg & ~clr) ^ (clr & REG_DEFAULT);
      end else if(we) begin
        phy_shadow_reg <= #TP buf_reg;
      end
    end
  end

  generate
    for(genvar i = 0; i < 8; i++) begin: detect_chgs_itr
      case(REG_ATTR[i])
        LEVEL: begin: level_detect_chgs
          assign detect_chgs[i] = (buf_reg[i] != phy_shadow_reg[i]);
        end: level_detect_chgs
        CYCLE: begin: cycle_detect_chgs
          assign detect_chgs[i] = (buf_reg[i] & ~phy_shadow_reg[i]);
        end: cycle_detect_chgs
        RESERVED: begin: rsvd_detect_chgs
          assign detect_chgs[i] = 1'h0;
        end: rsvd_detect_chgs
      endcase
    end: detect_chgs_itr
  endgenerate


endmodule: pipe_regif_phy_shadow_reg
