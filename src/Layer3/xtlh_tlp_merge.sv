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
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/xtlh_tlp_merge.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module performs tlp merge into merged packet structure
// -----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "products/cx_pl_pkg.svh"
`include "Layer3/xtlh_ms_pkg.svh"

module xtlh_tlp_merge
  import  xtlh_ms_pkg::xtlh_merge_pkt_struct;
  import  xtlh_ms_pkg::P_NDW;
  import  xtlh_ms_pkg::expand_to_vector;
  import  xtlh_ms_pkg::P_MERGE_NW;
  import  DWC_pcie_core_pkg::xtlh_pkt_t;
  import  DWC_pcie_core_pkg::ADM_PRFX_HDR_DATA_NW;
  import  cx_pl_pkg::P_NW;
#(
  parameter   P_START_INDEX = 0
) 
                       (
  input                         intf,
  input   xtlh_pkt_t            pkt_in
  ,
  input   [10:0]                tlp_len
  ,
  output  xtlh_merge_pkt_struct merge_pkt_out
);

logic [ADM_PRFX_HDR_DATA_NW-1:0][31:0] int_data_vector;
logic [P_NDW - 1 : 0] int_dwen_vector;
logic [P_NDW - 1 : 0] pkt_in_sot_vector;
logic [P_NDW - 1 : 0] pkt_in_eot_vector;
logic [P_NDW - 1 : 0] pkt_in_intf_vector;
logic [P_NDW - 1 : 0] pkt_in_ep_vector;
logic [P_NDW - 1 : 0] pkt_in_badeot_vector;
logic [P_NDW - 1 : 0] pkt_in_ptm_vector;
logic [P_NDW - 1 : 0] pkt_in_is_from_msg_gen;
logic [P_NDW - 1 : 0] pkt_in_is_from_dma;
logic [P_NDW - 1 : 0] pkt_in_pme_to_ack_vector;
logic [P_NDW - 1 : 0] pkt_in_soh_vector;

assign int_dwen_vector = pkt_in.dv ? pkt_in.dwen : '0;
assign int_data_vector = pkt_in.dv ? pkt_in.data : '0;
assign pkt_in_is_from_msg_gen = pkt_in.sot ? {{(P_NDW-1){1'b0}}, pkt_in.is_from_msg_gen} : '0;
assign pkt_in_is_from_dma = pkt_in.sot ? {{(P_NDW-1){1'b0}}, pkt_in.is_from_dma} : '0;
assign pkt_in_sot_vector = {{(P_NDW - 1){1'b0}}, pkt_in.sot};
assign pkt_in_eot_vector = expand_to_vector(pkt_in.eot, int_dwen_vector);
assign pkt_in_intf_vector = intf ? pkt_in_sot_vector : '0;
assign pkt_in_ep_vector =  pkt_in.eot ? expand_to_vector(pkt_in.ep, int_dwen_vector) : '0;
assign pkt_in_badeot_vector =  expand_to_vector(pkt_in.badeot, int_dwen_vector);
assign pkt_in_ptm_vector =  pkt_in.eot ? expand_to_vector(pkt_in.ptm, int_dwen_vector) : '0;
assign pkt_in_pme_to_ack_vector =  pkt_in.eot ? expand_to_vector(pkt_in.pme_to_ack, int_dwen_vector) : '0;
assign pkt_in_soh_vector = pkt_in.sot ? {{(P_NDW - $bits(pkt_in.soh)){1'b0}}, pkt_in.soh} : '0;

always_comb begin : merge_PROC
  merge_pkt_out.dv = |int_dwen_vector;
  merge_pkt_out.ras_dp_err_inband_kbd = pkt_in.ras_dp_err_inband_kbd;
  merge_pkt_out.tlp_prot = '0;
  merge_pkt_out.sot = {{P_NW{1'b0}}, pkt_in_sot_vector};
  merge_pkt_out.soh = {{P_NW{1'b0}}, pkt_in_soh_vector};
  merge_pkt_out.is_from_msg_gen = {{P_NW{1'b0}}, pkt_in_is_from_msg_gen};
  merge_pkt_out.is_from_dma = {{P_NW{1'b0}}, pkt_in_is_from_dma};
  merge_pkt_out.eot = {{P_NW{1'b0}}, pkt_in_eot_vector};
  merge_pkt_out.intf = {{P_NW{1'b0}}, pkt_in_intf_vector};
  merge_pkt_out.dwen = {{P_NW{1'b0}}, int_dwen_vector};
  merge_pkt_out.ep = {{P_NW{1'b0}}, pkt_in_ep_vector};
  merge_pkt_out.badeot = {{P_NW{1'b0}}, pkt_in_badeot_vector};
  merge_pkt_out.ptm = {{P_NW{1'b0}}, pkt_in_ptm_vector};
  merge_pkt_out.pme_to_ack = {{P_NW{1'b0}}, pkt_in_pme_to_ack_vector};
  merge_pkt_out.data = {{P_NW{32'b0}}, int_data_vector};
  merge_pkt_out.tlp_len = {{(P_MERGE_NW-1){11'b0}}, tlp_len};
end : merge_PROC

endmodule
