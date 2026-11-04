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
// ---    $Revision: #2 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/xtlh_tlp_shift.sv#2 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module performs tlp shift only 
// -----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "products/cx_pl_pkg.svh"
`include "Layer3/xtlh_ms_pkg.svh"

module xtlh_tlp_shift
  import  xtlh_ms_pkg::xtlh_merge_pkt_struct;
  import  xtlh_ms_pkg::P_MERGE_NW;
  import  cx_pl_pkg::P_NW;
(
  input                         shift_en,
  input   xtlh_merge_pkt_struct accum_data,
  output  xtlh_merge_pkt_struct merge_pkt_out
);

localparam P_ZERO_IN      = {P_NW{1'b0}};
localparam P_ZERO_DATA_IN = {P_NW{32'b0}};
localparam P_ZERO_LEN_IN  = {P_NW{11'b0}};

always_comb begin : shift_PROC
  if(shift_en) begin
    merge_pkt_out.intf = {P_ZERO_IN, accum_data.intf[P_MERGE_NW - 1 : P_NW]};
    merge_pkt_out.sot = {P_ZERO_IN, accum_data.sot[P_MERGE_NW - 1 : P_NW]};
    merge_pkt_out.soh = {P_ZERO_IN, accum_data.soh[P_MERGE_NW - 1 : P_NW]};
    merge_pkt_out.is_from_msg_gen = {P_ZERO_IN, accum_data.is_from_msg_gen[P_MERGE_NW - 1 : P_NW]};
    merge_pkt_out.is_from_dma = {P_ZERO_IN, accum_data.is_from_dma[P_MERGE_NW - 1 : P_NW]};
    merge_pkt_out.eot = {P_ZERO_IN, accum_data.eot[P_MERGE_NW - 1 : P_NW]};
    merge_pkt_out.dwen = {P_ZERO_IN, accum_data.dwen[P_MERGE_NW - 1 : P_NW]};
    merge_pkt_out.ep = {P_ZERO_IN, accum_data.ep[P_MERGE_NW - 1 : P_NW]};
    merge_pkt_out.badeot = {P_ZERO_IN, accum_data.badeot[P_MERGE_NW - 1 : P_NW]};
    merge_pkt_out.ptm = {P_ZERO_IN, accum_data.ptm[P_MERGE_NW - 1 : P_NW]};
    merge_pkt_out.pme_to_ack = {P_ZERO_IN, accum_data.pme_to_ack[P_MERGE_NW - 1 : P_NW]};
    merge_pkt_out.data = {P_ZERO_DATA_IN, accum_data.data[P_MERGE_NW - 1 : P_NW]};
    merge_pkt_out.tlp_len = {P_ZERO_LEN_IN, accum_data.tlp_len[P_MERGE_NW - 1 : P_NW]};
    merge_pkt_out.dv = |accum_data.dwen;
    merge_pkt_out.ras_dp_err_inband_kbd = accum_data.ras_dp_err_inband_kbd;
    merge_pkt_out.tlp_prot = '0;
  end else begin
    merge_pkt_out = '0;
  end
end : shift_PROC

endmodule
