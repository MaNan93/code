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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/pipe_regif_mac_reg.sv#6 $
// --------------------------------------------------------------------------------------------
// --- Module Description: Sub-module of pipe_regif_slv
// --------------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "common/pipe_regif_pkg.svh"

module pipe_regif_mac_reg

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
  input logic [7:0]   din,
  input logic         clr,
  input logic         we,
  input logic         upd,
// ------------ outputs ---------------
  output logic [7:0]  dout
);

  localparam  TP = `TP;

  logic [7:0]  shadow_reg, pre_shadow_data, stb_shadow_data;

  always_ff @(posedge clk or negedge rst_n) begin: shadow_reg_PROC
    if(!rst_n) begin
      shadow_reg <= #TP REG_DEFAULT;
    end
    else if(ce) begin
      if(clr) begin
        shadow_reg <= #TP REG_DEFAULT;
      end
      else if(we) begin
        shadow_reg <= #TP pre_shadow_data;
      end
      else begin
        shadow_reg <= #TP stb_shadow_data;
      end
    end
  end: shadow_reg_PROC

  logic [7:0]  mac_reg, pre_mac_data, stb_mac_data;
  assign dout = mac_reg;

  always_ff @(posedge clk or negedge rst_n) begin: mac_reg_PROC
    if(!rst_n) begin
      mac_reg <= #TP REG_DEFAULT;
    end
    else if(ce) begin
      if(clr) begin
        mac_reg <= #TP REG_DEFAULT;
      end
      else if(upd) begin
        mac_reg <= #TP pre_mac_data;
      end
      else begin
        mac_reg <= #TP stb_mac_data;
      end
    end
  end: mac_reg_PROC

  generate
    for(genvar i = 0; i < 8; i++) begin: shadow_mac_data_assign_itr
      case(REG_ATTR[i])
        LEVEL: begin: level_data_assign
          assign pre_shadow_data[i] = din[i];
          assign stb_shadow_data[i] = shadow_reg[i];
          assign pre_mac_data[i] = (we) ? din[i] : shadow_reg[i];
          assign stb_mac_data[i] = mac_reg[i];
        end: level_data_assign
        CYCLE: begin: cycle_data_assign
          assign pre_shadow_data[i] = (upd) ? 1'h0 : din[i];
          assign stb_shadow_data[i] = (upd) ? 1'h0 : shadow_reg[i];
          assign pre_mac_data[i] = (we) ? din[i] : shadow_reg[i];
          assign stb_mac_data[i] = 1'h0;
        end: cycle_data_assign
        RESERVED: begin: rsvd_data_assign
          assign pre_shadow_data[i] = 1'h0;
          assign stb_shadow_data[i] = 1'h0;
          assign pre_mac_data[i] = 1'h0;
          assign stb_mac_data[i] = 1'h0;
        end: rsvd_data_assign
      endcase
    end: shadow_mac_data_assign_itr
  endgenerate

endmodule: pipe_regif_mac_reg
