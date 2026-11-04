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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/xtlh_tlp_shift_merge.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module performs tlp shift and merge with accumulated data 
// -----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "products/cx_pl_pkg.svh"
`include "Layer3/xtlh_ms_pkg.svh"

module xtlh_tlp_shift_merge
  import  xtlh_ms_pkg::xtlh_merge_pkt_struct;
  import  xtlh_ms_pkg::P_NDW;
  import  xtlh_ms_pkg::expand_to_vector;
  import  xtlh_ms_pkg::P_MERGE_NW;
  import  xtlh_ms_pkg::P_N_SHIFT_MERGE;
  import  DWC_pcie_core_pkg::xtlh_pkt_t;
  import  cx_pl_pkg::P_NW;
#(
  parameter   P_START_INDEX = 0
) 
                             (
  input                         intf,
  input   [7:0]                 accum_dwen,
  input   xtlh_merge_pkt_struct accum_data,
  input   xtlh_pkt_t            pkt_in
  ,
  input   [10:0]                tlp_len
  ,
  output  xtlh_merge_pkt_struct merge_pkt_out
);

localparam P_PAD_NW = (P_N_SHIFT_MERGE * 8) + P_NW;

logic [P_NDW - 1 : 0]             pkt_in_sot_vector;
logic [P_NDW - 1 : 0]             pkt_in_eot_vector;
logic [P_NDW - 1 : 0]             pkt_in_intf_vector;
logic [P_NDW - 1 : 0]             pkt_in_ep_vector;
logic [P_NDW - 1 : 0]             pkt_in_badeot_vector;
logic [P_NDW - 1 : 0]             pkt_in_ptm_vector;
logic [P_NDW - 1 : 0]             pkt_in_is_from_msg_gen;
logic [P_NDW - 1 : 0]             pkt_in_is_from_dma;
logic [P_PAD_NW - 1 : 0]          pad_pkt_in_dma_vector;
logic [P_NDW - 1 : 0]             pkt_in_pme_to_ack_vector;
logic [P_NDW - 1 : 0]             pkt_in_soh_vector;
logic [P_PAD_NW - 1 : 0]          pad_pkt_in_sot_vector;
logic [P_PAD_NW - 1 : 0]          pad_pkt_in_msg_gen_vector;
logic [P_PAD_NW - 1 : 0][10:0]    pad_pkt_in_tlp_len_vector;
logic [P_PAD_NW - 1 : 0]          pad_pkt_in_dwen_vector;
logic [P_PAD_NW - 1 : 0][31:0]    pad_pkt_in_data_vector;
logic [P_PAD_NW - 1 : 0]          pad_pkt_in_eot_vector;
logic [P_PAD_NW - 1 : 0]          pad_pkt_in_intf_vector;
logic [P_PAD_NW - 1 : 0]          pad_pkt_in_ep_vector;
logic [P_PAD_NW - 1 : 0]          pad_pkt_in_badeot_vector;
logic [P_PAD_NW - 1 : 0]          pad_pkt_in_ptm_vector;
logic [P_PAD_NW - 1 : 0]          pad_pkt_in_pme_to_ack_vector;
logic [P_PAD_NW - 1 : 0]          pad_pkt_in_soh_vector;

logic [P_PAD_NW - 1 : 0]          pad_accum_is_from_dma;
logic [P_PAD_NW - 1 : 0]          pad_accum_sot;
logic [P_PAD_NW - 1 : 0]          pad_accum_is_from_msg_gen;
logic [P_PAD_NW - 1 : 0][10:0]    pad_accum_tlp_len;
logic [P_PAD_NW - 1 : 0]          pad_accum_dwen;
logic [P_PAD_NW - 1 : 0][31:0]    pad_accum_data;
logic [P_PAD_NW - 1 : 0]          pad_accum_eot;
logic [P_PAD_NW - 1 : 0]          pad_accum_intf;
logic [P_PAD_NW - 1 : 0]          pad_accum_ep;
logic [P_PAD_NW - 1 : 0]          pad_accum_badeot;
logic [P_PAD_NW - 1 : 0]          pad_accum_ptm;
logic [P_PAD_NW - 1 : 0]          pad_accum_pme_to_ack;
logic [P_PAD_NW - 1 : 0]          pad_accum_soh;

logic [P_PAD_NW - 1 : 0]          pad_merge_is_from_dma;
logic [P_PAD_NW - 1 : 0]          pad_merge_sot;
logic [P_PAD_NW - 1 : 0]          pad_merge_is_from_msg_gen;
logic [P_PAD_NW - 1 : 0][10:0]    pad_merge_tlp_len;
logic [P_PAD_NW - 1 : 0]          pad_merge_dwen;
logic [P_PAD_NW - 1 : 0][31:0]    pad_merge_data;
logic [P_PAD_NW - 1 : 0]          pad_merge_eot;
logic [P_PAD_NW - 1 : 0]          pad_merge_intf;
logic [P_PAD_NW - 1 : 0]          pad_merge_ep;
logic [P_PAD_NW - 1 : 0]          pad_merge_badeot;
logic [P_PAD_NW - 1 : 0]          pad_merge_ptm;
logic [P_PAD_NW - 1 : 0]          pad_merge_pme_to_ack;
logic [P_PAD_NW - 1 : 0]          pad_merge_soh;
logic [P_NDW - 1 : 0]             int_dwen_vector;

assign int_dwen_vector = pkt_in.dv ? pkt_in.dwen : '0;
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
assign pad_pkt_in_soh_vector = {{(P_PAD_NW - P_NDW){1'b0}}, pkt_in_soh_vector};
assign pad_pkt_in_sot_vector = {{(P_PAD_NW - P_NDW){1'b0}}, pkt_in_sot_vector};
assign pad_pkt_in_msg_gen_vector = {{(P_PAD_NW - P_NDW){1'b0}}, pkt_in_is_from_msg_gen};
assign pad_pkt_in_dma_vector = {{(P_PAD_NW - P_NDW){1'b0}}, pkt_in_is_from_dma};
assign pad_pkt_in_tlp_len_vector = pkt_in.sot ? {{(P_PAD_NW - 1){11'b0}}, tlp_len} : '0;
assign pad_pkt_in_dwen_vector = {{(P_PAD_NW - P_NDW){1'b0}}, int_dwen_vector};
assign pad_pkt_in_data_vector = pkt_in.dv ? {{(P_PAD_NW - P_NDW){32'b0}}, pkt_in.data} : '0;
assign pad_pkt_in_eot_vector = {{(P_PAD_NW - P_NDW){1'b0}}, pkt_in_eot_vector};
assign pad_pkt_in_intf_vector = {{(P_PAD_NW - P_NDW){1'b0}}, pkt_in_intf_vector};
assign pad_pkt_in_ep_vector = {{(P_PAD_NW - P_NDW){1'b0}}, pkt_in_ep_vector};
assign pad_pkt_in_badeot_vector = {{(P_PAD_NW - P_NDW){1'b0}}, pkt_in_badeot_vector};
assign pad_pkt_in_ptm_vector = {{(P_PAD_NW - P_NDW){1'b0}}, pkt_in_ptm_vector};
assign pad_pkt_in_pme_to_ack_vector = {{(P_PAD_NW - P_NDW){1'b0}}, pkt_in_pme_to_ack_vector};

assign pad_accum_soh = {{(P_PAD_NW - P_MERGE_NW){1'b0}}, accum_data.soh};
assign pad_accum_sot = {{(P_PAD_NW - P_MERGE_NW){1'b0}}, accum_data.sot};
assign pad_accum_is_from_msg_gen = {{(P_PAD_NW - P_MERGE_NW){1'b0}}, accum_data.is_from_msg_gen};
assign pad_accum_is_from_dma = {{(P_PAD_NW - P_MERGE_NW){1'b0}}, accum_data.is_from_dma};
assign pad_accum_tlp_len = {{(P_PAD_NW - P_MERGE_NW){11'b0}}, accum_data.tlp_len};
assign pad_accum_dwen = {{(P_PAD_NW - P_MERGE_NW){1'b0}}, accum_data.dwen};
assign pad_accum_data = {{(P_PAD_NW - P_MERGE_NW){32'b0}}, accum_data.data};
assign pad_accum_eot = {{(P_PAD_NW - P_MERGE_NW){1'b0}}, accum_data.eot};
assign pad_accum_intf = {{(P_PAD_NW - P_MERGE_NW){1'b0}}, accum_data.intf};
assign pad_accum_ep = {{(P_PAD_NW - P_MERGE_NW){1'b0}}, accum_data.ep};
assign pad_accum_badeot = {{(P_PAD_NW - P_MERGE_NW){1'b0}}, accum_data.badeot};
assign pad_accum_ptm = {{(P_PAD_NW - P_MERGE_NW){1'b0}}, accum_data.ptm};
assign pad_accum_pme_to_ack = {{(P_PAD_NW - P_MERGE_NW){1'b0}}, accum_data.pme_to_ack};

always_comb begin : shift_merge_PROC
  unique casez(accum_dwen)
    8'b00000001 : begin
      pad_merge_intf = {pad_pkt_in_intf_vector[P_PAD_NW - P_START_INDEX - 2 : 0], pad_accum_intf[P_NW + P_START_INDEX + 0 : P_NW]};
      pad_merge_sot = {pad_pkt_in_sot_vector[P_PAD_NW - P_START_INDEX - 2 : 0] , pad_accum_sot[P_NW + P_START_INDEX + 0 : P_NW]};
      pad_merge_is_from_msg_gen = {pad_pkt_in_msg_gen_vector[P_PAD_NW - P_START_INDEX - 2 : 0] , pad_accum_is_from_msg_gen[P_NW + P_START_INDEX + 0 : P_NW]};
      pad_merge_is_from_dma = {pad_pkt_in_dma_vector[P_PAD_NW - P_START_INDEX - 2 : 0] , pad_accum_is_from_dma[P_NW + P_START_INDEX + 0 : P_NW]};
      pad_merge_eot = {pad_pkt_in_eot_vector[P_PAD_NW - P_START_INDEX - 2 : 0], pad_accum_eot[P_NW + P_START_INDEX + 0 : P_NW]};
      pad_merge_dwen = {pad_pkt_in_dwen_vector[P_PAD_NW - P_START_INDEX - 2 : 0], pad_accum_dwen[P_NW + P_START_INDEX + 0 : P_NW]};
      pad_merge_ep = {pad_pkt_in_ep_vector[P_PAD_NW - P_START_INDEX - 2 : 0], pad_accum_ep[P_NW + P_START_INDEX + 0 : P_NW]};
      pad_merge_badeot = {pad_pkt_in_badeot_vector[P_PAD_NW - P_START_INDEX - 2 : 0], pad_accum_badeot[P_NW + P_START_INDEX + 0 : P_NW]};
      pad_merge_soh = {pad_pkt_in_soh_vector[P_PAD_NW - P_START_INDEX - 2 : 0], pad_accum_soh[P_NW + P_START_INDEX + 0 : P_NW]};
      pad_merge_ptm = {pad_pkt_in_ptm_vector[P_PAD_NW - P_START_INDEX - 2 : 0], pad_accum_ptm[P_NW + P_START_INDEX + 0 : P_NW]};
      pad_merge_pme_to_ack = {pad_pkt_in_pme_to_ack_vector[P_PAD_NW - P_START_INDEX - 2 : 0], pad_accum_pme_to_ack[P_NW + P_START_INDEX + 0 : P_NW]};
      pad_merge_data = {pad_pkt_in_data_vector[P_PAD_NW - P_START_INDEX - 2 : 0], pad_accum_data[P_NW + P_START_INDEX + 0 : P_NW]};
      pad_merge_tlp_len = {pad_pkt_in_tlp_len_vector[P_PAD_NW - P_START_INDEX - 2 : 0], pad_accum_tlp_len[P_NW + P_START_INDEX + 0 : P_NW]};
    end
    8'b0000001? : begin
      pad_merge_intf = {pad_pkt_in_intf_vector[P_PAD_NW - P_START_INDEX - 3 : 0], pad_accum_intf[P_NW + P_START_INDEX + 1 : P_NW]};
      pad_merge_sot = {pad_pkt_in_sot_vector[P_PAD_NW - P_START_INDEX - 3 : 0] , pad_accum_sot[P_NW + P_START_INDEX + 1 : P_NW]};
      pad_merge_is_from_msg_gen = {pad_pkt_in_msg_gen_vector[P_PAD_NW - P_START_INDEX - 3 : 0] , pad_accum_is_from_msg_gen[P_NW + P_START_INDEX + 1 : P_NW]};
      pad_merge_is_from_dma = {pad_pkt_in_dma_vector[P_PAD_NW - P_START_INDEX - 3 : 0] , pad_accum_is_from_dma[P_NW + P_START_INDEX + 1 : P_NW]};
      pad_merge_eot = {pad_pkt_in_eot_vector[P_PAD_NW - P_START_INDEX - 3 : 0], pad_accum_eot[P_NW + P_START_INDEX + 1 : P_NW]};
      pad_merge_dwen = {pad_pkt_in_dwen_vector[P_PAD_NW - P_START_INDEX - 3 : 0], pad_accum_dwen[P_NW + P_START_INDEX + 1 : P_NW]};
      pad_merge_ep = {pad_pkt_in_ep_vector[P_PAD_NW - P_START_INDEX - 3 : 0], pad_accum_ep[P_NW + P_START_INDEX + 1 : P_NW]};
      pad_merge_badeot = {pad_pkt_in_badeot_vector[P_PAD_NW - P_START_INDEX - 3 : 0], pad_accum_badeot[P_NW + P_START_INDEX + 1 : P_NW]};
      pad_merge_soh = {pad_pkt_in_soh_vector[P_PAD_NW - P_START_INDEX - 3 : 0], pad_accum_soh[P_NW + P_START_INDEX + 1 : P_NW]};
      pad_merge_ptm = {pad_pkt_in_ptm_vector[P_PAD_NW - P_START_INDEX - 3 : 0], pad_accum_ptm[P_NW + P_START_INDEX + 1 : P_NW]};
      pad_merge_pme_to_ack = {pad_pkt_in_pme_to_ack_vector[P_PAD_NW - P_START_INDEX - 3 : 0], pad_accum_pme_to_ack[P_NW + P_START_INDEX + 1 : P_NW]};
      pad_merge_data = {pad_pkt_in_data_vector[P_PAD_NW - P_START_INDEX - 3 : 0], pad_accum_data[P_NW + P_START_INDEX + 1 : P_NW]};
      pad_merge_tlp_len = {pad_pkt_in_tlp_len_vector[P_PAD_NW - P_START_INDEX - 3 : 0], pad_accum_tlp_len[P_NW + P_START_INDEX + 1 : P_NW]};
    end
    8'b000001?? : begin
      pad_merge_intf = {pad_pkt_in_intf_vector[P_PAD_NW - P_START_INDEX - 4 : 0], pad_accum_intf[P_NW + P_START_INDEX + 2 : P_NW]};
      pad_merge_sot = {pad_pkt_in_sot_vector[P_PAD_NW - P_START_INDEX - 4 : 0] , pad_accum_sot[P_NW + P_START_INDEX + 2 : P_NW]};
      pad_merge_is_from_msg_gen = {pad_pkt_in_msg_gen_vector[P_PAD_NW - P_START_INDEX - 4 : 0] , pad_accum_is_from_msg_gen[P_NW + P_START_INDEX + 2 : P_NW]};
      pad_merge_is_from_dma = {pad_pkt_in_dma_vector[P_PAD_NW - P_START_INDEX - 4 : 0] , pad_accum_is_from_dma[P_NW + P_START_INDEX + 2 : P_NW]};
      pad_merge_eot = {pad_pkt_in_eot_vector[P_PAD_NW - P_START_INDEX - 4 : 0], pad_accum_eot[P_NW + P_START_INDEX + 2 : P_NW]};
      pad_merge_dwen = {pad_pkt_in_dwen_vector[P_PAD_NW - P_START_INDEX - 4 : 0], pad_accum_dwen[P_NW + P_START_INDEX + 2 : P_NW]};
      pad_merge_ep = {pad_pkt_in_ep_vector[P_PAD_NW - P_START_INDEX - 4 : 0], pad_accum_ep[P_NW + P_START_INDEX + 2 : P_NW]};
      pad_merge_badeot = {pad_pkt_in_badeot_vector[P_PAD_NW - P_START_INDEX - 4 : 0], pad_accum_badeot[P_NW + P_START_INDEX + 2 : P_NW]};
      pad_merge_soh = {pad_pkt_in_soh_vector[P_PAD_NW - P_START_INDEX - 4 : 0], pad_accum_soh[P_NW + P_START_INDEX + 2 : P_NW]};
      pad_merge_ptm = {pad_pkt_in_ptm_vector[P_PAD_NW - P_START_INDEX - 4 : 0], pad_accum_ptm[P_NW + P_START_INDEX + 2 : P_NW]};
      pad_merge_pme_to_ack = {pad_pkt_in_pme_to_ack_vector[P_PAD_NW - P_START_INDEX - 4 : 0], pad_accum_pme_to_ack[P_NW + P_START_INDEX + 2 : P_NW]};
      pad_merge_data = {pad_pkt_in_data_vector[P_PAD_NW - P_START_INDEX - 4 : 0], pad_accum_data[P_NW + P_START_INDEX + 2 : P_NW]};
      pad_merge_tlp_len = {pad_pkt_in_tlp_len_vector[P_PAD_NW - P_START_INDEX - 4 : 0], pad_accum_tlp_len[P_NW + P_START_INDEX + 2 : P_NW]};
    end
    8'b00001??? : begin
      pad_merge_intf = {pad_pkt_in_intf_vector[P_PAD_NW - P_START_INDEX - 5 : 0], pad_accum_intf[P_NW + P_START_INDEX + 3 : P_NW]};
      pad_merge_sot = {pad_pkt_in_sot_vector[P_PAD_NW - P_START_INDEX - 5 : 0] , pad_accum_sot[P_NW + P_START_INDEX + 3 : P_NW]};
      pad_merge_is_from_msg_gen = {pad_pkt_in_msg_gen_vector[P_PAD_NW - P_START_INDEX - 5 : 0] , pad_accum_is_from_msg_gen[P_NW + P_START_INDEX + 3 : P_NW]};
      pad_merge_is_from_dma = {pad_pkt_in_dma_vector[P_PAD_NW - P_START_INDEX - 5 : 0] , pad_accum_is_from_dma[P_NW + P_START_INDEX + 3 : P_NW]};
      pad_merge_eot = {pad_pkt_in_eot_vector[P_PAD_NW - P_START_INDEX - 5 : 0], pad_accum_eot[P_NW + P_START_INDEX + 3 : P_NW]};
      pad_merge_dwen = {pad_pkt_in_dwen_vector[P_PAD_NW - P_START_INDEX - 5 : 0], pad_accum_dwen[P_NW + P_START_INDEX + 3 : P_NW]};
      pad_merge_ep = {pad_pkt_in_ep_vector[P_PAD_NW - P_START_INDEX - 5 : 0], pad_accum_ep[P_NW + P_START_INDEX + 3 : P_NW]};
      pad_merge_badeot = {pad_pkt_in_badeot_vector[P_PAD_NW - P_START_INDEX - 5 : 0], pad_accum_badeot[P_NW + P_START_INDEX + 3 : P_NW]};
      pad_merge_soh = {pad_pkt_in_soh_vector[P_PAD_NW - P_START_INDEX - 5 : 0], pad_accum_soh[P_NW + P_START_INDEX + 3 : P_NW]};
      pad_merge_ptm = {pad_pkt_in_ptm_vector[P_PAD_NW - P_START_INDEX - 5 : 0], pad_accum_ptm[P_NW + P_START_INDEX + 3 : P_NW]};
      pad_merge_pme_to_ack = {pad_pkt_in_pme_to_ack_vector[P_PAD_NW - P_START_INDEX - 5 : 0], pad_accum_pme_to_ack[P_NW + P_START_INDEX + 3 : P_NW]};
      pad_merge_data = {pad_pkt_in_data_vector[P_PAD_NW - P_START_INDEX - 5 : 0], pad_accum_data[P_NW + P_START_INDEX + 3 : P_NW]};
      pad_merge_tlp_len = {pad_pkt_in_tlp_len_vector[P_PAD_NW - P_START_INDEX - 5 : 0], pad_accum_tlp_len[P_NW + P_START_INDEX + 3 : P_NW]};
    end
    8'b0001???? : begin
      pad_merge_intf = {pad_pkt_in_intf_vector[P_PAD_NW - P_START_INDEX - 6 : 0], pad_accum_intf[P_NW + P_START_INDEX + 4 : P_NW]};
      pad_merge_sot = {pad_pkt_in_sot_vector[P_PAD_NW - P_START_INDEX - 6 : 0] , pad_accum_sot[P_NW + P_START_INDEX + 4 : P_NW]};
      pad_merge_is_from_msg_gen = {pad_pkt_in_msg_gen_vector[P_PAD_NW - P_START_INDEX - 6 : 0] , pad_accum_is_from_msg_gen[P_NW + P_START_INDEX + 4 : P_NW]};
      pad_merge_is_from_dma = {pad_pkt_in_dma_vector[P_PAD_NW - P_START_INDEX - 6 : 0] , pad_accum_is_from_dma[P_NW + P_START_INDEX + 4 : P_NW]};
      pad_merge_eot = {pad_pkt_in_eot_vector[P_PAD_NW - P_START_INDEX - 6 : 0], pad_accum_eot[P_NW + P_START_INDEX + 4 : P_NW]};
      pad_merge_dwen = {pad_pkt_in_dwen_vector[P_PAD_NW - P_START_INDEX - 6 : 0], pad_accum_dwen[P_NW + P_START_INDEX + 4 : P_NW]};
      pad_merge_ep = {pad_pkt_in_ep_vector[P_PAD_NW - P_START_INDEX - 6 : 0], pad_accum_ep[P_NW + P_START_INDEX + 4 : P_NW]};
      pad_merge_badeot = {pad_pkt_in_badeot_vector[P_PAD_NW - P_START_INDEX - 6 : 0], pad_accum_badeot[P_NW + P_START_INDEX + 4 : P_NW]};
      pad_merge_soh = {pad_pkt_in_soh_vector[P_PAD_NW - P_START_INDEX - 6 : 0], pad_accum_soh[P_NW + P_START_INDEX + 4 : P_NW]};
      pad_merge_ptm = {pad_pkt_in_ptm_vector[P_PAD_NW - P_START_INDEX - 6 : 0], pad_accum_ptm[P_NW + P_START_INDEX + 4 : P_NW]};
      pad_merge_pme_to_ack = {pad_pkt_in_pme_to_ack_vector[P_PAD_NW - P_START_INDEX - 6 : 0], pad_accum_pme_to_ack[P_NW + P_START_INDEX + 4 : P_NW]};
      pad_merge_data = {pad_pkt_in_data_vector[P_PAD_NW - P_START_INDEX - 6 : 0], pad_accum_data[P_NW + P_START_INDEX + 4 : P_NW]};
      pad_merge_tlp_len = {pad_pkt_in_tlp_len_vector[P_PAD_NW - P_START_INDEX - 6 : 0], pad_accum_tlp_len[P_NW + P_START_INDEX + 4 : P_NW]};
    end
    8'b001????? : begin
      pad_merge_intf = {pad_pkt_in_intf_vector[P_PAD_NW - P_START_INDEX - 7 : 0], pad_accum_intf[P_NW + P_START_INDEX + 5 : P_NW]};
      pad_merge_sot = {pad_pkt_in_sot_vector[P_PAD_NW - P_START_INDEX - 7 : 0] , pad_accum_sot[P_NW + P_START_INDEX + 5 : P_NW]};
      pad_merge_is_from_msg_gen = {pad_pkt_in_msg_gen_vector[P_PAD_NW - P_START_INDEX - 7 : 0] , pad_accum_is_from_msg_gen[P_NW + P_START_INDEX + 5 : P_NW]};
      pad_merge_is_from_dma = {pad_pkt_in_dma_vector[P_PAD_NW - P_START_INDEX - 7 : 0] , pad_accum_is_from_dma[P_NW + P_START_INDEX + 5 : P_NW]};
      pad_merge_eot = {pad_pkt_in_eot_vector[P_PAD_NW - P_START_INDEX - 7 : 0], pad_accum_eot[P_NW + P_START_INDEX + 5 : P_NW]};
      pad_merge_dwen = {pad_pkt_in_dwen_vector[P_PAD_NW - P_START_INDEX - 7 : 0], pad_accum_dwen[P_NW + P_START_INDEX + 5 : P_NW]};
      pad_merge_ep = {pad_pkt_in_ep_vector[P_PAD_NW - P_START_INDEX - 7 : 0], pad_accum_ep[P_NW + P_START_INDEX + 5 : P_NW]};
      pad_merge_badeot = {pad_pkt_in_badeot_vector[P_PAD_NW - P_START_INDEX - 7 : 0], pad_accum_badeot[P_NW + P_START_INDEX + 5 : P_NW]};
      pad_merge_soh = {pad_pkt_in_soh_vector[P_PAD_NW - P_START_INDEX - 7 : 0], pad_accum_soh[P_NW + P_START_INDEX + 5 : P_NW]};
      pad_merge_ptm = {pad_pkt_in_ptm_vector[P_PAD_NW - P_START_INDEX - 7 : 0], pad_accum_ptm[P_NW + P_START_INDEX + 5 : P_NW]};
      pad_merge_pme_to_ack = {pad_pkt_in_pme_to_ack_vector[P_PAD_NW - P_START_INDEX - 7 : 0], pad_accum_pme_to_ack[P_NW + P_START_INDEX + 5 : P_NW]};
      pad_merge_data = {pad_pkt_in_data_vector[P_PAD_NW - P_START_INDEX - 7 : 0], pad_accum_data[P_NW + P_START_INDEX + 5 : P_NW]};
      pad_merge_tlp_len = {pad_pkt_in_tlp_len_vector[P_PAD_NW - P_START_INDEX - 7 : 0], pad_accum_tlp_len[P_NW + P_START_INDEX + 5 : P_NW]};
    end
    8'b01?????? : begin
      pad_merge_intf = {pad_pkt_in_intf_vector[P_PAD_NW - P_START_INDEX - 8 : 0], pad_accum_intf[P_NW + P_START_INDEX + 6 : P_NW]};
      pad_merge_sot = {pad_pkt_in_sot_vector[P_PAD_NW - P_START_INDEX - 8 : 0] , pad_accum_sot[P_NW + P_START_INDEX + 6 : P_NW]};
      pad_merge_is_from_msg_gen = {pad_pkt_in_msg_gen_vector[P_PAD_NW - P_START_INDEX - 8 : 0] , pad_accum_is_from_msg_gen[P_NW + P_START_INDEX + 6 : P_NW]};
      pad_merge_is_from_dma = {pad_pkt_in_dma_vector[P_PAD_NW - P_START_INDEX - 8 : 0] , pad_accum_is_from_dma[P_NW + P_START_INDEX + 6 : P_NW]};
      pad_merge_eot = {pad_pkt_in_eot_vector[P_PAD_NW - P_START_INDEX - 8 : 0], pad_accum_eot[P_NW + P_START_INDEX + 6 : P_NW]};
      pad_merge_dwen = {pad_pkt_in_dwen_vector[P_PAD_NW - P_START_INDEX - 8 : 0], pad_accum_dwen[P_NW + P_START_INDEX + 6 : P_NW]};
      pad_merge_ep = {pad_pkt_in_ep_vector[P_PAD_NW - P_START_INDEX - 8 : 0], pad_accum_ep[P_NW + P_START_INDEX + 6 : P_NW]};
      pad_merge_badeot = {pad_pkt_in_badeot_vector[P_PAD_NW - P_START_INDEX - 8 : 0], pad_accum_badeot[P_NW + P_START_INDEX + 6 : P_NW]};
      pad_merge_soh = {pad_pkt_in_soh_vector[P_PAD_NW - P_START_INDEX - 8 : 0], pad_accum_soh[P_NW + P_START_INDEX + 6 : P_NW]};
      pad_merge_ptm = {pad_pkt_in_ptm_vector[P_PAD_NW - P_START_INDEX - 8 : 0], pad_accum_ptm[P_NW + P_START_INDEX + 6 : P_NW]};
      pad_merge_pme_to_ack = {pad_pkt_in_pme_to_ack_vector[P_PAD_NW - P_START_INDEX - 8 : 0], pad_accum_pme_to_ack[P_NW + P_START_INDEX + 6 : P_NW]};
      pad_merge_data = {pad_pkt_in_data_vector[P_PAD_NW - P_START_INDEX - 8 : 0], pad_accum_data[P_NW + P_START_INDEX + 6 : P_NW]};
      pad_merge_tlp_len = {pad_pkt_in_tlp_len_vector[P_PAD_NW - P_START_INDEX - 8 : 0], pad_accum_tlp_len[P_NW + P_START_INDEX + 6 : P_NW]};
    end
    8'b1??????? : begin
      pad_merge_intf = {pad_pkt_in_intf_vector[P_PAD_NW - P_START_INDEX - 9 : 0], pad_accum_intf[P_NW + P_START_INDEX + 7 : P_NW]};
      pad_merge_sot = {pad_pkt_in_sot_vector[P_PAD_NW - P_START_INDEX - 9 : 0] , pad_accum_sot[P_NW + P_START_INDEX + 7 : P_NW]};
      pad_merge_is_from_msg_gen = {pad_pkt_in_msg_gen_vector[P_PAD_NW - P_START_INDEX - 9 : 0] , pad_accum_is_from_msg_gen[P_NW + P_START_INDEX + 7 : P_NW]};
      pad_merge_is_from_dma = {pad_pkt_in_dma_vector[P_PAD_NW - P_START_INDEX - 9 : 0] , pad_accum_is_from_dma[P_NW + P_START_INDEX + 7 : P_NW]};
      pad_merge_eot = {pad_pkt_in_eot_vector[P_PAD_NW - P_START_INDEX - 9 : 0], pad_accum_eot[P_NW + P_START_INDEX + 7 : P_NW]};
      pad_merge_dwen = {pad_pkt_in_dwen_vector[P_PAD_NW - P_START_INDEX - 9 : 0], pad_accum_dwen[P_NW + P_START_INDEX + 7 : P_NW]};
      pad_merge_ep = {pad_pkt_in_ep_vector[P_PAD_NW - P_START_INDEX - 9 : 0], pad_accum_ep[P_NW + P_START_INDEX + 7 : P_NW]};
      pad_merge_badeot = {pad_pkt_in_badeot_vector[P_PAD_NW - P_START_INDEX - 9 : 0], pad_accum_badeot[P_NW + P_START_INDEX + 7 : P_NW]};
      pad_merge_soh = {pad_pkt_in_soh_vector[P_PAD_NW - P_START_INDEX - 9 : 0], pad_accum_soh[P_NW + P_START_INDEX + 7 : P_NW]};
      pad_merge_ptm = {pad_pkt_in_ptm_vector[P_PAD_NW - P_START_INDEX - 9 : 0], pad_accum_ptm[P_NW + P_START_INDEX + 7 : P_NW]};
      pad_merge_pme_to_ack = {pad_pkt_in_pme_to_ack_vector[P_PAD_NW - P_START_INDEX - 9 : 0], pad_accum_pme_to_ack[P_NW + P_START_INDEX + 7 : P_NW]};
      pad_merge_data = {pad_pkt_in_data_vector[P_PAD_NW - P_START_INDEX - 9 : 0], pad_accum_data[P_NW + P_START_INDEX + 7 : P_NW]};
      pad_merge_tlp_len = {pad_pkt_in_tlp_len_vector[P_PAD_NW - P_START_INDEX - 9 : 0], pad_accum_tlp_len[P_NW + P_START_INDEX + 7 : P_NW]};
    end
    default : begin
      pad_merge_intf = '0;
      pad_merge_sot = '0;
      pad_merge_is_from_msg_gen = '0;
      pad_merge_is_from_dma = '0;
      pad_merge_eot = '0;
      pad_merge_dwen = '0;
      pad_merge_ep = '0;
      pad_merge_badeot = '0;
      pad_merge_soh = '0;
      pad_merge_ptm = '0;
      pad_merge_pme_to_ack = '0;
      pad_merge_data = '0;
      pad_merge_tlp_len = '0;
    end
  endcase
  merge_pkt_out.dv = |accum_dwen;
  merge_pkt_out.ras_dp_err_inband_kbd = pkt_in.ras_dp_err_inband_kbd || accum_data.ras_dp_err_inband_kbd;
  merge_pkt_out.tlp_prot = '0;
  merge_pkt_out.intf = pad_merge_intf[P_MERGE_NW - 1 : 0];
  merge_pkt_out.sot = pad_merge_sot[P_MERGE_NW - 1 : 0];
  merge_pkt_out.is_from_dma = pad_merge_is_from_dma[P_MERGE_NW - 1 : 0];
  merge_pkt_out.is_from_msg_gen = pad_merge_is_from_msg_gen[P_MERGE_NW - 1 : 0];
  merge_pkt_out.eot = pad_merge_eot[P_MERGE_NW - 1 : 0];
  merge_pkt_out.dwen = pad_merge_dwen[P_MERGE_NW - 1 : 0];
  merge_pkt_out.ep = pad_merge_ep[P_MERGE_NW - 1 : 0];
  merge_pkt_out.badeot = pad_merge_badeot[P_MERGE_NW - 1 : 0];
  merge_pkt_out.soh = pad_merge_soh[P_MERGE_NW - 1 : 0];
  merge_pkt_out.ptm = pad_merge_ptm[P_MERGE_NW - 1 : 0];
  merge_pkt_out.pme_to_ack = pad_merge_pme_to_ack[P_MERGE_NW - 1 : 0];
  merge_pkt_out.data = pad_merge_data[P_MERGE_NW - 1 : 0];
  merge_pkt_out.tlp_len = pad_merge_tlp_len[P_MERGE_NW - 1 : 0];
end : shift_merge_PROC

endmodule
