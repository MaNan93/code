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
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/xtlh_tlp_len_calc.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module performs FC merging for nfm data path. 
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "products/cx_pl_pkg.svh"
`include "Layer3/xtlh_ms_pkg.svh"

module xtlh_tlp_len_calc
  import  xtlh_ms_pkg::xtlh_vc_pkt_struct;
  import  DWC_pcie_core_pkg::xtlh_pkt_t;
  import  DWC_pcie_core_pkg::ADM_PRFX_NW;
#(
  parameter TP        = `TP
) 
                          (
  input                                 core_clk,
  input                                 core_rst_n,
  input                                 halt_in,
  input xtlh_pkt_t                      pkt_in
  ,
  input                                 flit_mode_en
  ,
  output  logic [10:0]                  xtlh_tlp_len
);

logic [9:0]   int_tlp_len;
logic [10:0]  int_calc_tlp_len;
logic [10:0]  payload_len;
logic [1:0]   int_tlp_fmt;
logic         int_tlp_td;
logic [7 : 0] int_prfx_dwen;
logic [3:0]   int_prfx_nw;                      
logic         int_soh_found;                      
// Calculate the number of prefixes
always_comb begin : prfx_dwen_PROC
  int_prfx_dwen = '0;
  int_soh_found = '0;
  if(pkt_in.sot && !halt_in) begin
    for(int i = 0; i < ADM_PRFX_NW; i = i + 1) begin 
      int_prfx_dwen[i] = !pkt_in.soh[i] && pkt_in.dwen[i] && !int_soh_found;
      int_soh_found = int_soh_found || pkt_in.soh[i];
    end
  end
end : prfx_dwen_PROC

always_comb begin : prfx_nw_PROC
  if(pkt_in.sot && !halt_in) begin
    case(int_prfx_dwen)
      8'hff:    int_prfx_nw = 4'b1000; // 8 Prefix DWs
      8'h7f:    int_prfx_nw = 4'b0111; // 7 Prefix DWs
      8'h3f:    int_prfx_nw = 4'b0110; // 6 Prefix DWs
      8'h1f:    int_prfx_nw = 4'b0101; // 5 Prefix DWs
      8'h0f:    int_prfx_nw = 4'b0100; // 4 Prefix DWs
      8'h07:    int_prfx_nw = 4'b0011; // 3 Prefix DWs
      8'h03:    int_prfx_nw = 4'b0010; // 2 Prefix DWs
      8'h01:    int_prfx_nw = 4'b0001; // 1 Prefix DWs
      default:  int_prfx_nw = 4'b0000; // 0 pREFIX dwS
    endcase
  end
  else  int_prfx_nw = 4'b0000;     
end : prfx_nw_PROC

always_comb begin : hdr_decode_PROC
  int_tlp_fmt = '0; 
  int_tlp_len = '0;
  int_tlp_td = '0; 

  if(pkt_in.sot && !halt_in) begin 
    for (int i=0; i<$bits(pkt_in.soh); i=i+1) begin
      if (pkt_in.soh[i]) begin
        int_tlp_fmt = pkt_in.data[i][5 +:2];
        int_tlp_td  = pkt_in.data[i][23];
        int_tlp_len = {pkt_in.data[i][16 +:2], pkt_in.data[i][24 +:8]};
      end
    end
  end
end : hdr_decode_PROC

assign payload_len[10]  = int_tlp_fmt[1] ? (int_tlp_len == '0) : '0;
assign payload_len[9:0] = int_tlp_fmt[1] ? int_tlp_len : '0; 

// Calculate TLP Length for STP Token, -> What about TLP Prefix ??
assign int_calc_tlp_len = `CX_GEN3_MIN_TLP_LEN // Minimum TLP Length is 5DW 
                         + payload_len          // Add Payload Length
                         + int_tlp_fmt[0]       // Add 1DW if 4DW Header Format
                         + int_tlp_td           // Add 1DW if TLP Digest present
                         + int_prfx_nw
                         ;


assign xtlh_tlp_len = flit_mode_en ? '0 : int_calc_tlp_len;


endmodule
