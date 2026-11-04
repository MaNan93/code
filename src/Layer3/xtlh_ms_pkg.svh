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

// -----------------------------------------------------------------------------
// --- RCS information:
// ---   $DateTime: 2024/02/16 12:12:17 $
// ---   $Author: eoghain $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/xtlh_ms_pkg.svh#16 $
// -----------------------------------------------------------------------------

`ifndef __GUARD__XTLH_MS_PKG__SVH__
`define __GUARD__XTLH_MS_PKG__SVH__

`include "DWC_pcie_ctl_pkg.svh"
`include "products/cx_pl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
// -----------------------------------------------------------------------------
// --- Package Description: Package containing common variables and functions for xtlh 
// -----------------------------------------------------------------------------
package xtlh_ms_pkg;

  import DWC_pcie_ctl_pkg::NPRFX;
  import DWC_pcie_ctl_pkg::N_XADM_IF_VC;
  import DWC_pcie_core_pkg::xtlh_pkt_t;
  import cx_pl_pkg::P_DW;
  import cx_pl_pkg::P_NW;
  import cx_pl_pkg::P_NFM_NW;
  import cx_pl_pkg::DATA_PAR_WD;

  localparam      P_NW_CNT_WD = $clog2(P_NW);
  localparam int  P_N_TLP_LEN = (P_NW == 32) ? 2 : 1;
  localparam      P_MERGE_MAX_CNT = 3;
  localparam      P_MERGE_MAX_CNT_WD = 4;
  // Parameter Declarations
  localparam int  P_NW_PROT = `CX_NW_PROT;
  localparam int  P_NDW_PROT  = `CX_NDW_PROT;
  localparam int  P_NFM_NW_PROT = `CX_NFM_NW_PROT;
  localparam int  P_MERGE_NW_PROT = P_NDW_PROT + P_NW_PROT;
  localparam int  P_NDW = `CX_NDW;
  localparam int  P_MERGE_NW = P_NDW + P_NW;
  // Round up P_NDW to the nearest multiple of 8
  localparam int  P_N_SHIFT_MERGE = (P_NDW + (8 - (P_NDW % 8))) / 8;
  localparam int  P_NDW_CNT_WD = $clog2(P_NDW);
  localparam int  P_XTLH_PACKER_MAX_P_IF = 1;
  localparam int  P_XTLH_PACKER_MAX_NP_IF = 1;
  localparam int  P_XTLH_PACKER_MAX_CPL_IF = 1;
  localparam int  P_XTLH_PACKER_MAX_IF= P_XTLH_PACKER_MAX_P_IF + P_XTLH_PACKER_MAX_NP_IF + P_XTLH_PACKER_MAX_CPL_IF;
  localparam int  P_CTL_CNT_WD = $clog2(P_NW);
  localparam int  P_OVER_CNT_WD = $clog2(P_NW+5);
  localparam int  P_XTLH_MAX_TLP_CNT = 8;
  localparam int  P_XTLH_MAX_TLP_CNT_WD = $clog2(P_XTLH_MAX_TLP_CNT) + 1;
  // Shift register width 2 * DW plus additional 8DW to accomodate the Flit overhead along with NOP to 4DW boundary
  localparam int  P_SHIFT_NW = (2*P_NW) + 5;
  localparam int  P_SHIFT_WD = P_SHIFT_NW * 32;
  localparam int  P_DW_CNT_WD = $clog2(2048/P_DW);
  localparam int  P_DW_LAST = (2048 / P_DW) - 1;
  localparam int  P_DW_HALF = (2048 / (P_DW * 2)) - 1;
  localparam      P_NOP = 32'h0000_0000;
  localparam int  P_ACCUM_DW_WD = 4 + 1 + 1 ;

  // Maximum TLP's ending per cycle
  localparam P_MAX_SOT = P_NW / 4;
  // Maximum outstanding responses
  localparam  P_MAX_RSP = 8;
  localparam P_SOT_CNT_MSB = $clog2(P_MAX_SOT);
  localparam P_MAX_RSP_MSB = $clog2(P_MAX_RSP);

  localparam int P_FC_MERGE_LOG_WD = 3







                                     ;

  typedef enum logic [1:0] {
    E_NONE = 2'b00,
    E_NULLIFIED = 2'b01,
    E_POISON = 2'b10,
    E_RSVD = 2'b11
  } flit_status_e;

  typedef struct packed {
    logic         flit_marker_indication;
    flit_status_e flit_status;
    logic         ptm_in_flit;
  } flit_marker_struct;

  // Flit Mode Shift Structure
  typedef struct packed {
    logic               [P_SHIFT_NW-1:0]        data_valid;   // TLP data contained in this cycle
    logic               [P_SHIFT_NW-1:0] [31:0] data;         // TLP data
    logic               [P_SHIFT_NW-1:0]        sot;          // Start of TLP markers
    logic               [P_SHIFT_NW-1:0]        eot;          // End of TLP markers
    flit_marker_struct  [P_SHIFT_NW-1:0]        flit_marker;  // Flit Marker
      logic [DATA_PAR_WD-1:0]  flit_prot; 
      logic                    ras_dp_err_inband_kbd;
  } flit_shift_struct;

  

  // FC Arbitration Phases
  typedef enum logic [1:0] {
    E_NOP_PHASE = 2'b00,
    E_P_PHASE = 2'b01,
    E_NP_PHASE = 2'b10,
    E_CPL_PHASE = 2'b11
  } fc_phase_e;

  // FC Merge Interface 
  typedef struct packed {
    logic [P_MERGE_NW-1:0]        soh;        // Start of TLP Header 
    logic [P_MERGE_NW-1:0]        sot;        // Start of TLP
    logic [P_MERGE_NW-1:0][31:0]  data;       // TLP Data
    logic [P_MERGE_NW-1:0]        dwen;       // DW Enable
    logic [P_MERGE_NW-1:0]        eot;        // End of TLP marker
    logic [P_MERGE_NW-1:0]        intf;       // Indicates which interface the TLP comes from valid on EOT
    logic                         dv;         // Data valid indication
    logic [P_MERGE_NW-1:0]        ep;         // Poisoned TLP marker 
    logic [P_MERGE_NW-1:0]        badeot;     // Nullified TLP marker
    logic [P_NW_PROT-1:0]         tlp_prot;  
    logic                         ras_dp_err_inband_kbd;
    logic [P_MERGE_NW-1:0]        ptm;              // This flit contains last symbol of PTM message
    logic [P_MERGE_NW-1:0]        pme_to_ack;       // This flit contains last symbol of PME_To_Ack message
    logic [P_MERGE_NW-1:0][10:0]  tlp_len;          // TLP Length aligned to SOT
    logic [P_MERGE_NW-1:0]        is_from_msg_gen;  // TLP is from message gen module
    logic [P_MERGE_NW-1:0]        is_from_dma;      // TLP is from DMA
  } xtlh_merge_pkt_struct;

  // VC Packer Interface 
  typedef struct packed {
    logic [P_NW-1:0]        soh;        // Start of TLP Header 
    logic [P_NW-1:0]        sot;            // Start of TLP Marker
    logic [P_NW-1:0][31:0]  data;           // TLP Data
    logic [P_NW-1:0]        dwen;           // DW Enable
    logic                   dv;
    logic [P_NW-1:0]        eot;            // End of TLP marker
    logic [P_NW-1:0]        intf;           // Indicates which interface the TLP comes from 1/0 only valid on EOT
    logic [P_NW-1:0]        ep;             // Poisoned TLP marker 
    logic [P_NW-1:0]        badeot;         // Nullified TLP marker
      logic [P_NW_PROT-1:0]  tlp_prot;  
      logic                  ras_dp_err_inband_kbd;
    logic [P_NW-1:0]        ptm;            // This flit contains last symbol of PTM message
    logic [P_NW-1:0]        pme_to_ack;     // This flit contains last symbol of PME_To_Ack message
    logic [P_NW-1:0][10:0]  tlp_len;        // TLP Length aligned to SOT
    logic [P_NW-1:0]        is_from_msg_gen;// TLP is from message gen module
    logic [P_NW-1:0]        is_from_dma;    // TLP is from DMA
  } xtlh_vc_pkt_struct;
  

  // TLP End struct
  typedef struct packed {
    logic [P_NW-1:0][3:0] vc; // Virtual channel number per EOT
    logic [P_NW-1:0]      eot;  // End of TLP
  } tlp_end_struct;

  // -----------------------------------------------------------------------------
  // Functions
  // -----------------------------------------------------------------------------
  // Function Name  : pack_merged_data_vector 
  // Description    : This function packs data from merged TLPs into the data stream
  //                  
  // Inputs         : accum_data <xtlh_vc_pkt_struct>
  //                  pkt_in <xtlh_merge_tlp_struct>
  // Outputs        : pack_data_vector <xtlh_merge_pkt_struct>
  function automatic xtlh_merge_pkt_struct pack_merged_data_vector (
    input xtlh_merge_pkt_struct accum_data,
    input xtlh_merge_pkt_struct pkt_in
  );
  begin
    logic [P_MERGE_NW - 1 : 0] pkt_in_soh_vector;
    logic [35 : 0]        int_dwen;
    int_dwen = {{($bits(int_dwen)-P_NDW){1'b0}}, accum_data.dwen[P_MERGE_NW - 1 : P_NW]};
    pack_merged_data_vector= '0;
    pkt_in_soh_vector = (|pkt_in.sot) ? pkt_in.soh : '0;
    casez(int_dwen)
    36'b000000000000000000000000000000000001 : begin
    pack_merged_data_vector.is_from_msg_gen = {pkt_in.is_from_msg_gen[P_MERGE_NW - 2 : 0] , accum_data.is_from_msg_gen[P_NW + 0 : P_NW]};
    pack_merged_data_vector.is_from_dma = {pkt_in.is_from_dma[P_MERGE_NW - 2 : 0] , accum_data.is_from_dma[P_NW + 0 : P_NW]};
    pack_merged_data_vector.sot = {pkt_in.sot[P_MERGE_NW - 2 : 0] , accum_data.sot[P_NW + 0 : P_NW]};
    pack_merged_data_vector.eot = {pkt_in.eot[P_MERGE_NW - 2 : 0], accum_data.eot[P_NW + 0 : P_NW]};
    pack_merged_data_vector.intf = {pkt_in.intf[P_MERGE_NW - 2 : 0], accum_data.intf[P_NW + 0 : P_NW]};
    pack_merged_data_vector.dwen = {pkt_in.dwen[P_MERGE_NW - 2 : 0], accum_data.dwen[P_NW + 0 : P_NW]};
    pack_merged_data_vector.ep = {pkt_in.ep[P_MERGE_NW - 2 : 0], accum_data.ep[P_NW + 0 : P_NW]};
    pack_merged_data_vector.badeot = {pkt_in.badeot[P_MERGE_NW - 2 : 0], accum_data.badeot[P_NW + 0 : P_NW]};
    pack_merged_data_vector.soh = {pkt_in_soh_vector[P_MERGE_NW - 2 : 0], accum_data.soh[P_NW + 0 : P_NW]};
    pack_merged_data_vector.ptm = {pkt_in.ptm[P_MERGE_NW - 2 : 0], accum_data.ptm[P_NW + 0 : P_NW]};
    pack_merged_data_vector.pme_to_ack = {pkt_in.pme_to_ack[P_MERGE_NW - 2 : 0], accum_data.pme_to_ack[P_NW + 0 : P_NW]};
    pack_merged_data_vector.data = {pkt_in.data[P_MERGE_NW - 2 : 0], accum_data.data[P_NW + 0 : P_NW]};
    pack_merged_data_vector.tlp_len = {pkt_in.tlp_len[P_MERGE_NW - 2 : 0], accum_data.tlp_len[P_NW + 0 : P_NW]};
    end
    36'b00000000000000000000000000000000001? : begin
    pack_merged_data_vector.is_from_msg_gen = {pkt_in.is_from_msg_gen[P_MERGE_NW - 3 : 0] , accum_data.is_from_msg_gen[P_NW + 1 : P_NW]};
    pack_merged_data_vector.is_from_dma = {pkt_in.is_from_dma[P_MERGE_NW - 3 : 0] , accum_data.is_from_dma[P_NW + 1 : P_NW]};
    pack_merged_data_vector.sot = {pkt_in.sot[P_MERGE_NW - 3 : 0] , accum_data.sot[P_NW + 1 : P_NW]};
    pack_merged_data_vector.eot = {pkt_in.eot[P_MERGE_NW - 3 : 0], accum_data.eot[P_NW + 1 : P_NW]};
    pack_merged_data_vector.intf = {pkt_in.intf[P_MERGE_NW - 3 : 0], accum_data.intf[P_NW + 1 : P_NW]};
    pack_merged_data_vector.dwen = {pkt_in.dwen[P_MERGE_NW - 3 : 0], accum_data.dwen[P_NW + 1 : P_NW]};
    pack_merged_data_vector.ep = {pkt_in.ep[P_MERGE_NW - 3 : 0], accum_data.ep[P_NW + 1 : P_NW]};
    pack_merged_data_vector.badeot = {pkt_in.badeot[P_MERGE_NW - 3 : 0], accum_data.badeot[P_NW + 1 : P_NW]};
    pack_merged_data_vector.soh = {pkt_in_soh_vector[P_MERGE_NW - 3 : 0], accum_data.soh[P_NW + 1 : P_NW]};
    pack_merged_data_vector.ptm = {pkt_in.ptm[P_MERGE_NW - 3 : 0], accum_data.ptm[P_NW + 1 : P_NW]};
    pack_merged_data_vector.pme_to_ack = {pkt_in.pme_to_ack[P_MERGE_NW - 3 : 0], accum_data.pme_to_ack[P_NW + 1 : P_NW]};
    pack_merged_data_vector.data = {pkt_in.data[P_MERGE_NW - 3 : 0], accum_data.data[P_NW + 1 : P_NW]};
    pack_merged_data_vector.tlp_len = {pkt_in.tlp_len[P_MERGE_NW - 3 : 0], accum_data.tlp_len[P_NW + 1 : P_NW]};
    end
    36'b0000000000000000000000000000000001?? : begin
    pack_merged_data_vector.is_from_msg_gen = {pkt_in.is_from_msg_gen[P_MERGE_NW - 4 : 0] , accum_data.is_from_msg_gen[P_NW + 2 : P_NW]};
    pack_merged_data_vector.is_from_dma = {pkt_in.is_from_dma[P_MERGE_NW - 4 : 0] , accum_data.is_from_dma[P_NW + 2 : P_NW]};
    pack_merged_data_vector.sot = {pkt_in.sot[P_MERGE_NW - 4 : 0] , accum_data.sot[P_NW + 2 : P_NW]};
    pack_merged_data_vector.eot = {pkt_in.eot[P_MERGE_NW - 4 : 0], accum_data.eot[P_NW + 2 : P_NW]};
    pack_merged_data_vector.intf = {pkt_in.intf[P_MERGE_NW - 4 : 0], accum_data.intf[P_NW + 2 : P_NW]};
    pack_merged_data_vector.dwen = {pkt_in.dwen[P_MERGE_NW - 4 : 0], accum_data.dwen[P_NW + 2 : P_NW]};
    pack_merged_data_vector.ep = {pkt_in.ep[P_MERGE_NW - 4 : 0], accum_data.ep[P_NW + 2 : P_NW]};
    pack_merged_data_vector.badeot = {pkt_in.badeot[P_MERGE_NW - 4 : 0], accum_data.badeot[P_NW + 2 : P_NW]};
    pack_merged_data_vector.soh = {pkt_in_soh_vector[P_MERGE_NW - 4 : 0], accum_data.soh[P_NW + 2 : P_NW]};
    pack_merged_data_vector.ptm = {pkt_in.ptm[P_MERGE_NW - 4 : 0], accum_data.ptm[P_NW + 2 : P_NW]};
    pack_merged_data_vector.pme_to_ack = {pkt_in.pme_to_ack[P_MERGE_NW - 4 : 0], accum_data.pme_to_ack[P_NW + 2 : P_NW]};
    pack_merged_data_vector.data = {pkt_in.data[P_MERGE_NW - 4 : 0], accum_data.data[P_NW + 2 : P_NW]};
    pack_merged_data_vector.tlp_len = {pkt_in.tlp_len[P_MERGE_NW - 4 : 0], accum_data.tlp_len[P_NW + 2 : P_NW]};
    end
    36'b000000000000000000000000000000001??? : begin
    pack_merged_data_vector.is_from_msg_gen = {pkt_in.is_from_msg_gen[P_MERGE_NW - 5 : 0] , accum_data.is_from_msg_gen[P_NW + 3 : P_NW]};
    pack_merged_data_vector.is_from_dma = {pkt_in.is_from_dma[P_MERGE_NW - 5 : 0] , accum_data.is_from_dma[P_NW + 3 : P_NW]};
    pack_merged_data_vector.sot = {pkt_in.sot[P_MERGE_NW - 5 : 0] , accum_data.sot[P_NW + 3 : P_NW]};
    pack_merged_data_vector.eot = {pkt_in.eot[P_MERGE_NW - 5 : 0], accum_data.eot[P_NW + 3 : P_NW]};
    pack_merged_data_vector.intf = {pkt_in.intf[P_MERGE_NW - 5 : 0], accum_data.intf[P_NW + 3 : P_NW]};
    pack_merged_data_vector.dwen = {pkt_in.dwen[P_MERGE_NW - 5 : 0], accum_data.dwen[P_NW + 3 : P_NW]};
    pack_merged_data_vector.ep = {pkt_in.ep[P_MERGE_NW - 5 : 0], accum_data.ep[P_NW + 3 : P_NW]};
    pack_merged_data_vector.badeot = {pkt_in.badeot[P_MERGE_NW - 5 : 0], accum_data.badeot[P_NW + 3 : P_NW]};
    pack_merged_data_vector.soh = {pkt_in_soh_vector[P_MERGE_NW - 5 : 0], accum_data.soh[P_NW + 3 : P_NW]};
    pack_merged_data_vector.ptm = {pkt_in.ptm[P_MERGE_NW - 5 : 0], accum_data.ptm[P_NW + 3 : P_NW]};
    pack_merged_data_vector.pme_to_ack = {pkt_in.pme_to_ack[P_MERGE_NW - 5 : 0], accum_data.pme_to_ack[P_NW + 3 : P_NW]};
    pack_merged_data_vector.data = {pkt_in.data[P_MERGE_NW - 5 : 0], accum_data.data[P_NW + 3 : P_NW]};
    pack_merged_data_vector.tlp_len = {pkt_in.tlp_len[P_MERGE_NW - 5 : 0], accum_data.tlp_len[P_NW + 3 : P_NW]};
    end
    36'b00000000000000000000000000000001???? : begin
    pack_merged_data_vector.is_from_msg_gen = {pkt_in.is_from_msg_gen[P_MERGE_NW - 6 : 0] , accum_data.is_from_msg_gen[P_NW + 4 : P_NW]};
    pack_merged_data_vector.is_from_dma = {pkt_in.is_from_dma[P_MERGE_NW - 6 : 0] , accum_data.is_from_dma[P_NW + 4 : P_NW]};
    pack_merged_data_vector.sot = {pkt_in.sot[P_MERGE_NW - 6 : 0] , accum_data.sot[P_NW + 4 : P_NW]};
    pack_merged_data_vector.eot = {pkt_in.eot[P_MERGE_NW - 6 : 0], accum_data.eot[P_NW + 4 : P_NW]};
    pack_merged_data_vector.intf = {pkt_in.intf[P_MERGE_NW - 6 : 0], accum_data.intf[P_NW + 4 : P_NW]};
    pack_merged_data_vector.dwen = {pkt_in.dwen[P_MERGE_NW - 6 : 0], accum_data.dwen[P_NW + 4 : P_NW]};
    pack_merged_data_vector.ep = {pkt_in.ep[P_MERGE_NW - 6 : 0], accum_data.ep[P_NW + 4 : P_NW]};
    pack_merged_data_vector.badeot = {pkt_in.badeot[P_MERGE_NW - 6 : 0], accum_data.badeot[P_NW + 4 : P_NW]};
    pack_merged_data_vector.soh = {pkt_in_soh_vector[P_MERGE_NW - 6 : 0], accum_data.soh[P_NW + 4 : P_NW]};
    pack_merged_data_vector.ptm = {pkt_in.ptm[P_MERGE_NW - 6 : 0], accum_data.ptm[P_NW + 4 : P_NW]};
    pack_merged_data_vector.pme_to_ack = {pkt_in.pme_to_ack[P_MERGE_NW - 6 : 0], accum_data.pme_to_ack[P_NW + 4 : P_NW]};
    pack_merged_data_vector.data = {pkt_in.data[P_MERGE_NW - 6 : 0], accum_data.data[P_NW + 4 : P_NW]};
    pack_merged_data_vector.tlp_len = {pkt_in.tlp_len[P_MERGE_NW - 6 : 0], accum_data.tlp_len[P_NW + 4 : P_NW]};
    end
    36'b0000000000000000000000000000001????? : begin
    pack_merged_data_vector.is_from_msg_gen = {pkt_in.is_from_msg_gen[P_MERGE_NW - 7 : 0] , accum_data.is_from_msg_gen[P_NW + 5 : P_NW]};
    pack_merged_data_vector.is_from_dma = {pkt_in.is_from_dma[P_MERGE_NW - 7 : 0] , accum_data.is_from_dma[P_NW + 5 : P_NW]};
    pack_merged_data_vector.sot = {pkt_in.sot[P_MERGE_NW - 7 : 0] , accum_data.sot[P_NW + 5 : P_NW]};
    pack_merged_data_vector.eot = {pkt_in.eot[P_MERGE_NW - 7 : 0], accum_data.eot[P_NW + 5 : P_NW]};
    pack_merged_data_vector.intf = {pkt_in.intf[P_MERGE_NW - 7 : 0], accum_data.intf[P_NW + 5 : P_NW]};
    pack_merged_data_vector.dwen = {pkt_in.dwen[P_MERGE_NW - 7 : 0], accum_data.dwen[P_NW + 5 : P_NW]};
    pack_merged_data_vector.ep = {pkt_in.ep[P_MERGE_NW - 7 : 0], accum_data.ep[P_NW + 5 : P_NW]};
    pack_merged_data_vector.badeot = {pkt_in.badeot[P_MERGE_NW - 7 : 0], accum_data.badeot[P_NW + 5 : P_NW]};
    pack_merged_data_vector.soh = {pkt_in_soh_vector[P_MERGE_NW - 7 : 0], accum_data.soh[P_NW + 5 : P_NW]};
    pack_merged_data_vector.ptm = {pkt_in.ptm[P_MERGE_NW - 7 : 0], accum_data.ptm[P_NW + 5 : P_NW]};
    pack_merged_data_vector.pme_to_ack = {pkt_in.pme_to_ack[P_MERGE_NW - 7 : 0], accum_data.pme_to_ack[P_NW + 5 : P_NW]};
    pack_merged_data_vector.data = {pkt_in.data[P_MERGE_NW - 7 : 0], accum_data.data[P_NW + 5 : P_NW]};
    pack_merged_data_vector.tlp_len = {pkt_in.tlp_len[P_MERGE_NW - 7 : 0], accum_data.tlp_len[P_NW + 5 : P_NW]};
    end
    36'b000000000000000000000000000001?????? : begin
    pack_merged_data_vector.is_from_msg_gen = {pkt_in.is_from_msg_gen[P_MERGE_NW - 8 : 0] , accum_data.is_from_msg_gen[P_NW + 6 : P_NW]};
    pack_merged_data_vector.is_from_dma = {pkt_in.is_from_dma[P_MERGE_NW - 8 : 0] , accum_data.is_from_dma[P_NW + 6 : P_NW]};
    pack_merged_data_vector.sot = {pkt_in.sot[P_MERGE_NW - 8 : 0] , accum_data.sot[P_NW + 6 : P_NW]};
    pack_merged_data_vector.eot = {pkt_in.eot[P_MERGE_NW - 8 : 0], accum_data.eot[P_NW + 6 : P_NW]};
    pack_merged_data_vector.intf = {pkt_in.intf[P_MERGE_NW - 8 : 0], accum_data.intf[P_NW + 6 : P_NW]};
    pack_merged_data_vector.dwen = {pkt_in.dwen[P_MERGE_NW - 8 : 0], accum_data.dwen[P_NW + 6 : P_NW]};
    pack_merged_data_vector.ep = {pkt_in.ep[P_MERGE_NW - 8 : 0], accum_data.ep[P_NW + 6 : P_NW]};
    pack_merged_data_vector.badeot = {pkt_in.badeot[P_MERGE_NW - 8 : 0], accum_data.badeot[P_NW + 6 : P_NW]};
    pack_merged_data_vector.soh = {pkt_in_soh_vector[P_MERGE_NW - 8 : 0], accum_data.soh[P_NW + 6 : P_NW]};
    pack_merged_data_vector.ptm = {pkt_in.ptm[P_MERGE_NW - 8 : 0], accum_data.ptm[P_NW + 6 : P_NW]};
    pack_merged_data_vector.pme_to_ack = {pkt_in.pme_to_ack[P_MERGE_NW - 8 : 0], accum_data.pme_to_ack[P_NW + 6 : P_NW]};
    pack_merged_data_vector.data = {pkt_in.data[P_MERGE_NW - 8 : 0], accum_data.data[P_NW + 6 : P_NW]};
    pack_merged_data_vector.tlp_len = {pkt_in.tlp_len[P_MERGE_NW - 8 : 0], accum_data.tlp_len[P_NW + 6 : P_NW]};
    end
    36'b00000000000000000000000000001??????? : begin
    pack_merged_data_vector.is_from_msg_gen = {pkt_in.is_from_msg_gen[P_MERGE_NW - 9 : 0] , accum_data.is_from_msg_gen[P_NW + 7 : P_NW]};
    pack_merged_data_vector.is_from_dma = {pkt_in.is_from_dma[P_MERGE_NW - 9 : 0] , accum_data.is_from_dma[P_NW + 7 : P_NW]};
    pack_merged_data_vector.sot = {pkt_in.sot[P_MERGE_NW - 9 : 0] , accum_data.sot[P_NW + 7 : P_NW]};
    pack_merged_data_vector.eot = {pkt_in.eot[P_MERGE_NW - 9 : 0], accum_data.eot[P_NW + 7 : P_NW]};
    pack_merged_data_vector.intf = {pkt_in.intf[P_MERGE_NW - 9 : 0], accum_data.intf[P_NW + 7 : P_NW]};
    pack_merged_data_vector.dwen = {pkt_in.dwen[P_MERGE_NW - 9 : 0], accum_data.dwen[P_NW + 7 : P_NW]};
    pack_merged_data_vector.ep = {pkt_in.ep[P_MERGE_NW - 9 : 0], accum_data.ep[P_NW + 7 : P_NW]};
    pack_merged_data_vector.badeot = {pkt_in.badeot[P_MERGE_NW - 9 : 0], accum_data.badeot[P_NW + 7 : P_NW]};
    pack_merged_data_vector.soh = {pkt_in_soh_vector[P_MERGE_NW - 9 : 0], accum_data.soh[P_NW + 7 : P_NW]};
    pack_merged_data_vector.ptm = {pkt_in.ptm[P_MERGE_NW - 9 : 0], accum_data.ptm[P_NW + 7 : P_NW]};
    pack_merged_data_vector.pme_to_ack = {pkt_in.pme_to_ack[P_MERGE_NW - 9 : 0], accum_data.pme_to_ack[P_NW + 7 : P_NW]};
    pack_merged_data_vector.data = {pkt_in.data[P_MERGE_NW - 9 : 0], accum_data.data[P_NW + 7 : P_NW]};
    pack_merged_data_vector.tlp_len = {pkt_in.tlp_len[P_MERGE_NW - 9 : 0], accum_data.tlp_len[P_NW + 7 : P_NW]};
    end
    36'b0000000000000000000000000001???????? : begin
    pack_merged_data_vector.is_from_msg_gen = {pkt_in.is_from_msg_gen[P_MERGE_NW - 10 : 0] , accum_data.is_from_msg_gen[P_NW + 8 : P_NW]};
    pack_merged_data_vector.is_from_dma = {pkt_in.is_from_dma[P_MERGE_NW - 10 : 0] , accum_data.is_from_dma[P_NW + 8 : P_NW]};
    pack_merged_data_vector.sot = {pkt_in.sot[P_MERGE_NW - 10 : 0] , accum_data.sot[P_NW + 8 : P_NW]};
    pack_merged_data_vector.eot = {pkt_in.eot[P_MERGE_NW - 10 : 0], accum_data.eot[P_NW + 8 : P_NW]};
    pack_merged_data_vector.intf = {pkt_in.intf[P_MERGE_NW - 10 : 0], accum_data.intf[P_NW + 8 : P_NW]};
    pack_merged_data_vector.dwen = {pkt_in.dwen[P_MERGE_NW - 10 : 0], accum_data.dwen[P_NW + 8 : P_NW]};
    pack_merged_data_vector.ep = {pkt_in.ep[P_MERGE_NW - 10 : 0], accum_data.ep[P_NW + 8 : P_NW]};
    pack_merged_data_vector.badeot = {pkt_in.badeot[P_MERGE_NW - 10 : 0], accum_data.badeot[P_NW + 8 : P_NW]};
    pack_merged_data_vector.soh = {pkt_in_soh_vector[P_MERGE_NW - 10 : 0], accum_data.soh[P_NW + 8 : P_NW]};
    pack_merged_data_vector.ptm = {pkt_in.ptm[P_MERGE_NW - 10 : 0], accum_data.ptm[P_NW + 8 : P_NW]};
    pack_merged_data_vector.pme_to_ack = {pkt_in.pme_to_ack[P_MERGE_NW - 10 : 0], accum_data.pme_to_ack[P_NW + 8 : P_NW]};
    pack_merged_data_vector.data = {pkt_in.data[P_MERGE_NW - 10 : 0], accum_data.data[P_NW + 8 : P_NW]};
    pack_merged_data_vector.tlp_len = {pkt_in.tlp_len[P_MERGE_NW - 10 : 0], accum_data.tlp_len[P_NW + 8 : P_NW]};
    end
    36'b000000000000000000000000001????????? : begin
    pack_merged_data_vector.is_from_msg_gen = {pkt_in.is_from_msg_gen[P_MERGE_NW - 11 : 0] , accum_data.is_from_msg_gen[P_NW + 9 : P_NW]};
    pack_merged_data_vector.is_from_dma = {pkt_in.is_from_dma[P_MERGE_NW - 11 : 0] , accum_data.is_from_dma[P_NW + 9 : P_NW]};
    pack_merged_data_vector.sot = {pkt_in.sot[P_MERGE_NW - 11 : 0] , accum_data.sot[P_NW + 9 : P_NW]};
    pack_merged_data_vector.eot = {pkt_in.eot[P_MERGE_NW - 11 : 0], accum_data.eot[P_NW + 9 : P_NW]};
    pack_merged_data_vector.intf = {pkt_in.intf[P_MERGE_NW - 11 : 0], accum_data.intf[P_NW + 9 : P_NW]};
    pack_merged_data_vector.dwen = {pkt_in.dwen[P_MERGE_NW - 11 : 0], accum_data.dwen[P_NW + 9 : P_NW]};
    pack_merged_data_vector.ep = {pkt_in.ep[P_MERGE_NW - 11 : 0], accum_data.ep[P_NW + 9 : P_NW]};
    pack_merged_data_vector.badeot = {pkt_in.badeot[P_MERGE_NW - 11 : 0], accum_data.badeot[P_NW + 9 : P_NW]};
    pack_merged_data_vector.soh = {pkt_in_soh_vector[P_MERGE_NW - 11 : 0], accum_data.soh[P_NW + 9 : P_NW]};
    pack_merged_data_vector.ptm = {pkt_in.ptm[P_MERGE_NW - 11 : 0], accum_data.ptm[P_NW + 9 : P_NW]};
    pack_merged_data_vector.pme_to_ack = {pkt_in.pme_to_ack[P_MERGE_NW - 11 : 0], accum_data.pme_to_ack[P_NW + 9 : P_NW]};
    pack_merged_data_vector.data = {pkt_in.data[P_MERGE_NW - 11 : 0], accum_data.data[P_NW + 9 : P_NW]};
    pack_merged_data_vector.tlp_len = {pkt_in.tlp_len[P_MERGE_NW - 11 : 0], accum_data.tlp_len[P_NW + 9 : P_NW]};
    end
    36'b00000000000000000000000001?????????? : begin
    pack_merged_data_vector.is_from_msg_gen = {pkt_in.is_from_msg_gen[P_MERGE_NW - 12 : 0] , accum_data.is_from_msg_gen[P_NW + 10 : P_NW]};
    pack_merged_data_vector.is_from_dma = {pkt_in.is_from_dma[P_MERGE_NW - 12 : 0] , accum_data.is_from_dma[P_NW + 10 : P_NW]};
    pack_merged_data_vector.sot = {pkt_in.sot[P_MERGE_NW - 12 : 0] , accum_data.sot[P_NW + 10 : P_NW]};
    pack_merged_data_vector.eot = {pkt_in.eot[P_MERGE_NW - 12 : 0], accum_data.eot[P_NW + 10 : P_NW]};
    pack_merged_data_vector.intf = {pkt_in.intf[P_MERGE_NW - 12 : 0], accum_data.intf[P_NW + 10 : P_NW]};
    pack_merged_data_vector.dwen = {pkt_in.dwen[P_MERGE_NW - 12 : 0], accum_data.dwen[P_NW + 10 : P_NW]};
    pack_merged_data_vector.ep = {pkt_in.ep[P_MERGE_NW - 12 : 0], accum_data.ep[P_NW + 10 : P_NW]};
    pack_merged_data_vector.badeot = {pkt_in.badeot[P_MERGE_NW - 12 : 0], accum_data.badeot[P_NW + 10 : P_NW]};
    pack_merged_data_vector.soh = {pkt_in_soh_vector[P_MERGE_NW - 12 : 0], accum_data.soh[P_NW + 10 : P_NW]};
    pack_merged_data_vector.ptm = {pkt_in.ptm[P_MERGE_NW - 12 : 0], accum_data.ptm[P_NW + 10 : P_NW]};
    pack_merged_data_vector.pme_to_ack = {pkt_in.pme_to_ack[P_MERGE_NW - 12 : 0], accum_data.pme_to_ack[P_NW + 10 : P_NW]};
    pack_merged_data_vector.data = {pkt_in.data[P_MERGE_NW - 12 : 0], accum_data.data[P_NW + 10 : P_NW]};
    pack_merged_data_vector.tlp_len = {pkt_in.tlp_len[P_MERGE_NW - 12 : 0], accum_data.tlp_len[P_NW + 10 : P_NW]};
    end
    36'b0000000000000000000000001??????????? : begin
    pack_merged_data_vector.is_from_msg_gen = {pkt_in.is_from_msg_gen[P_MERGE_NW - 13 : 0] , accum_data.is_from_msg_gen[P_NW + 11 : P_NW]};
    pack_merged_data_vector.is_from_dma = {pkt_in.is_from_dma[P_MERGE_NW - 13 : 0] , accum_data.is_from_dma[P_NW + 11 : P_NW]};
    pack_merged_data_vector.sot = {pkt_in.sot[P_MERGE_NW - 13 : 0] , accum_data.sot[P_NW + 11 : P_NW]};
    pack_merged_data_vector.eot = {pkt_in.eot[P_MERGE_NW - 13 : 0], accum_data.eot[P_NW + 11 : P_NW]};
    pack_merged_data_vector.intf = {pkt_in.intf[P_MERGE_NW - 13 : 0], accum_data.intf[P_NW + 11 : P_NW]};
    pack_merged_data_vector.dwen = {pkt_in.dwen[P_MERGE_NW - 13 : 0], accum_data.dwen[P_NW + 11 : P_NW]};
    pack_merged_data_vector.ep = {pkt_in.ep[P_MERGE_NW - 13 : 0], accum_data.ep[P_NW + 11 : P_NW]};
    pack_merged_data_vector.badeot = {pkt_in.badeot[P_MERGE_NW - 13 : 0], accum_data.badeot[P_NW + 11 : P_NW]};
    pack_merged_data_vector.soh = {pkt_in_soh_vector[P_MERGE_NW - 13 : 0], accum_data.soh[P_NW + 11 : P_NW]};
    pack_merged_data_vector.ptm = {pkt_in.ptm[P_MERGE_NW - 13 : 0], accum_data.ptm[P_NW + 11 : P_NW]};
    pack_merged_data_vector.pme_to_ack = {pkt_in.pme_to_ack[P_MERGE_NW - 13 : 0], accum_data.pme_to_ack[P_NW + 11 : P_NW]};
    pack_merged_data_vector.data = {pkt_in.data[P_MERGE_NW - 13 : 0], accum_data.data[P_NW + 11 : P_NW]};
    pack_merged_data_vector.tlp_len = {pkt_in.tlp_len[P_MERGE_NW - 13 : 0], accum_data.tlp_len[P_NW + 11 : P_NW]};
    end
    36'b000000000000000000000001???????????? : begin
    pack_merged_data_vector.is_from_msg_gen = {pkt_in.is_from_msg_gen[P_MERGE_NW - 14 : 0] , accum_data.is_from_msg_gen[P_NW + 12 : P_NW]};
    pack_merged_data_vector.is_from_dma = {pkt_in.is_from_dma[P_MERGE_NW - 14 : 0] , accum_data.is_from_dma[P_NW + 12 : P_NW]};
    pack_merged_data_vector.sot = {pkt_in.sot[P_MERGE_NW - 14 : 0] , accum_data.sot[P_NW + 12 : P_NW]};
    pack_merged_data_vector.eot = {pkt_in.eot[P_MERGE_NW - 14 : 0], accum_data.eot[P_NW + 12 : P_NW]};
    pack_merged_data_vector.intf = {pkt_in.intf[P_MERGE_NW - 14 : 0], accum_data.intf[P_NW + 12 : P_NW]};
    pack_merged_data_vector.dwen = {pkt_in.dwen[P_MERGE_NW - 14 : 0], accum_data.dwen[P_NW + 12 : P_NW]};
    pack_merged_data_vector.ep = {pkt_in.ep[P_MERGE_NW - 14 : 0], accum_data.ep[P_NW + 12 : P_NW]};
    pack_merged_data_vector.badeot = {pkt_in.badeot[P_MERGE_NW - 14 : 0], accum_data.badeot[P_NW + 12 : P_NW]};
    pack_merged_data_vector.soh = {pkt_in_soh_vector[P_MERGE_NW - 14 : 0], accum_data.soh[P_NW + 12 : P_NW]};
    pack_merged_data_vector.ptm = {pkt_in.ptm[P_MERGE_NW - 14 : 0], accum_data.ptm[P_NW + 12 : P_NW]};
    pack_merged_data_vector.pme_to_ack = {pkt_in.pme_to_ack[P_MERGE_NW - 14 : 0], accum_data.pme_to_ack[P_NW + 12 : P_NW]};
    pack_merged_data_vector.data = {pkt_in.data[P_MERGE_NW - 14 : 0], accum_data.data[P_NW + 12 : P_NW]};
    pack_merged_data_vector.tlp_len = {pkt_in.tlp_len[P_MERGE_NW - 14 : 0], accum_data.tlp_len[P_NW + 12 : P_NW]};
    end
    36'b00000000000000000000001????????????? : begin
    pack_merged_data_vector.is_from_msg_gen = {pkt_in.is_from_msg_gen[P_MERGE_NW - 15 : 0] , accum_data.is_from_msg_gen[P_NW + 13 : P_NW]};
    pack_merged_data_vector.is_from_dma = {pkt_in.is_from_dma[P_MERGE_NW - 15 : 0] , accum_data.is_from_dma[P_NW + 13 : P_NW]};
    pack_merged_data_vector.sot = {pkt_in.sot[P_MERGE_NW - 15 : 0] , accum_data.sot[P_NW + 13 : P_NW]};
    pack_merged_data_vector.eot = {pkt_in.eot[P_MERGE_NW - 15 : 0], accum_data.eot[P_NW + 13 : P_NW]};
    pack_merged_data_vector.intf = {pkt_in.intf[P_MERGE_NW - 15 : 0], accum_data.intf[P_NW + 13 : P_NW]};
    pack_merged_data_vector.dwen = {pkt_in.dwen[P_MERGE_NW - 15 : 0], accum_data.dwen[P_NW + 13 : P_NW]};
    pack_merged_data_vector.ep = {pkt_in.ep[P_MERGE_NW - 15 : 0], accum_data.ep[P_NW + 13 : P_NW]};
    pack_merged_data_vector.badeot = {pkt_in.badeot[P_MERGE_NW - 15 : 0], accum_data.badeot[P_NW + 13 : P_NW]};
    pack_merged_data_vector.soh = {pkt_in_soh_vector[P_MERGE_NW - 15 : 0], accum_data.soh[P_NW + 13 : P_NW]};
    pack_merged_data_vector.ptm = {pkt_in.ptm[P_MERGE_NW - 15 : 0], accum_data.ptm[P_NW + 13 : P_NW]};
    pack_merged_data_vector.pme_to_ack = {pkt_in.pme_to_ack[P_MERGE_NW - 15 : 0], accum_data.pme_to_ack[P_NW + 13 : P_NW]};
    pack_merged_data_vector.data = {pkt_in.data[P_MERGE_NW - 15 : 0], accum_data.data[P_NW + 13 : P_NW]};
    pack_merged_data_vector.tlp_len = {pkt_in.tlp_len[P_MERGE_NW - 15 : 0], accum_data.tlp_len[P_NW + 13 : P_NW]};
    end
    36'b0000000000000000000001?????????????? : begin
    pack_merged_data_vector.is_from_msg_gen = {pkt_in.is_from_msg_gen[P_MERGE_NW - 16 : 0] , accum_data.is_from_msg_gen[P_NW + 14 : P_NW]};
    pack_merged_data_vector.is_from_dma = {pkt_in.is_from_dma[P_MERGE_NW - 16 : 0] , accum_data.is_from_dma[P_NW + 14 : P_NW]};
    pack_merged_data_vector.sot = {pkt_in.sot[P_MERGE_NW - 16 : 0] , accum_data.sot[P_NW + 14 : P_NW]};
    pack_merged_data_vector.eot = {pkt_in.eot[P_MERGE_NW - 16 : 0], accum_data.eot[P_NW + 14 : P_NW]};
    pack_merged_data_vector.intf = {pkt_in.intf[P_MERGE_NW - 16 : 0], accum_data.intf[P_NW + 14 : P_NW]};
    pack_merged_data_vector.dwen = {pkt_in.dwen[P_MERGE_NW - 16 : 0], accum_data.dwen[P_NW + 14 : P_NW]};
    pack_merged_data_vector.ep = {pkt_in.ep[P_MERGE_NW - 16 : 0], accum_data.ep[P_NW + 14 : P_NW]};
    pack_merged_data_vector.badeot = {pkt_in.badeot[P_MERGE_NW - 16 : 0], accum_data.badeot[P_NW + 14 : P_NW]};
    pack_merged_data_vector.soh = {pkt_in_soh_vector[P_MERGE_NW - 16 : 0], accum_data.soh[P_NW + 14 : P_NW]};
    pack_merged_data_vector.ptm = {pkt_in.ptm[P_MERGE_NW - 16 : 0], accum_data.ptm[P_NW + 14 : P_NW]};
    pack_merged_data_vector.pme_to_ack = {pkt_in.pme_to_ack[P_MERGE_NW - 16 : 0], accum_data.pme_to_ack[P_NW + 14 : P_NW]};
    pack_merged_data_vector.data = {pkt_in.data[P_MERGE_NW - 16 : 0], accum_data.data[P_NW + 14 : P_NW]};
    pack_merged_data_vector.tlp_len = {pkt_in.tlp_len[P_MERGE_NW - 16 : 0], accum_data.tlp_len[P_NW + 14 : P_NW]};
    end
    36'b000000000000000000001??????????????? : begin
    pack_merged_data_vector.is_from_msg_gen = {pkt_in.is_from_msg_gen[P_MERGE_NW - 17 : 0] , accum_data.is_from_msg_gen[P_NW + 15 : P_NW]};
    pack_merged_data_vector.is_from_dma = {pkt_in.is_from_dma[P_MERGE_NW - 17 : 0] , accum_data.is_from_dma[P_NW + 15 : P_NW]};
    pack_merged_data_vector.sot = {pkt_in.sot[P_MERGE_NW - 17 : 0] , accum_data.sot[P_NW + 15 : P_NW]};
    pack_merged_data_vector.eot = {pkt_in.eot[P_MERGE_NW - 17 : 0], accum_data.eot[P_NW + 15 : P_NW]};
    pack_merged_data_vector.intf = {pkt_in.intf[P_MERGE_NW - 17 : 0], accum_data.intf[P_NW + 15 : P_NW]};
    pack_merged_data_vector.dwen = {pkt_in.dwen[P_MERGE_NW - 17 : 0], accum_data.dwen[P_NW + 15 : P_NW]};
    pack_merged_data_vector.ep = {pkt_in.ep[P_MERGE_NW - 17 : 0], accum_data.ep[P_NW + 15 : P_NW]};
    pack_merged_data_vector.badeot = {pkt_in.badeot[P_MERGE_NW - 17 : 0], accum_data.badeot[P_NW + 15 : P_NW]};
    pack_merged_data_vector.soh = {pkt_in_soh_vector[P_MERGE_NW - 17 : 0], accum_data.soh[P_NW + 15 : P_NW]};
    pack_merged_data_vector.ptm = {pkt_in.ptm[P_MERGE_NW - 17 : 0], accum_data.ptm[P_NW + 15 : P_NW]};
    pack_merged_data_vector.pme_to_ack = {pkt_in.pme_to_ack[P_MERGE_NW - 17 : 0], accum_data.pme_to_ack[P_NW + 15 : P_NW]};
    pack_merged_data_vector.data = {pkt_in.data[P_MERGE_NW - 17 : 0], accum_data.data[P_NW + 15 : P_NW]};
    pack_merged_data_vector.tlp_len = {pkt_in.tlp_len[P_MERGE_NW - 17 : 0], accum_data.tlp_len[P_NW + 15 : P_NW]};
    end
    36'b00000000000000000001???????????????? : begin
    pack_merged_data_vector.is_from_msg_gen = {pkt_in.is_from_msg_gen[P_MERGE_NW - 18 : 0] , accum_data.is_from_msg_gen[P_NW + 16 : P_NW]};
    pack_merged_data_vector.is_from_dma = {pkt_in.is_from_dma[P_MERGE_NW - 18 : 0] , accum_data.is_from_dma[P_NW + 16 : P_NW]};
    pack_merged_data_vector.sot = {pkt_in.sot[P_MERGE_NW - 18 : 0] , accum_data.sot[P_NW + 16 : P_NW]};
    pack_merged_data_vector.eot = {pkt_in.eot[P_MERGE_NW - 18 : 0], accum_data.eot[P_NW + 16 : P_NW]};
    pack_merged_data_vector.intf = {pkt_in.intf[P_MERGE_NW - 18 : 0], accum_data.intf[P_NW + 16 : P_NW]};
    pack_merged_data_vector.dwen = {pkt_in.dwen[P_MERGE_NW - 18 : 0], accum_data.dwen[P_NW + 16 : P_NW]};
    pack_merged_data_vector.ep = {pkt_in.ep[P_MERGE_NW - 18 : 0], accum_data.ep[P_NW + 16 : P_NW]};
    pack_merged_data_vector.badeot = {pkt_in.badeot[P_MERGE_NW - 18 : 0], accum_data.badeot[P_NW + 16 : P_NW]};
    pack_merged_data_vector.soh = {pkt_in_soh_vector[P_MERGE_NW - 18 : 0], accum_data.soh[P_NW + 16 : P_NW]};
    pack_merged_data_vector.ptm = {pkt_in.ptm[P_MERGE_NW - 18 : 0], accum_data.ptm[P_NW + 16 : P_NW]};
    pack_merged_data_vector.pme_to_ack = {pkt_in.pme_to_ack[P_MERGE_NW - 18 : 0], accum_data.pme_to_ack[P_NW + 16 : P_NW]};
    pack_merged_data_vector.data = {pkt_in.data[P_MERGE_NW - 18 : 0], accum_data.data[P_NW + 16 : P_NW]};
    pack_merged_data_vector.tlp_len = {pkt_in.tlp_len[P_MERGE_NW - 18 : 0], accum_data.tlp_len[P_NW + 16 : P_NW]};
    end
    36'b0000000000000000001????????????????? : begin
    pack_merged_data_vector.is_from_msg_gen = {pkt_in.is_from_msg_gen[P_MERGE_NW - 19 : 0] , accum_data.is_from_msg_gen[P_NW + 17 : P_NW]};
    pack_merged_data_vector.is_from_dma = {pkt_in.is_from_dma[P_MERGE_NW - 19 : 0] , accum_data.is_from_dma[P_NW + 17 : P_NW]};
    pack_merged_data_vector.sot = {pkt_in.sot[P_MERGE_NW - 19 : 0] , accum_data.sot[P_NW + 17 : P_NW]};
    pack_merged_data_vector.eot = {pkt_in.eot[P_MERGE_NW - 19 : 0], accum_data.eot[P_NW + 17 : P_NW]};
    pack_merged_data_vector.intf = {pkt_in.intf[P_MERGE_NW - 19 : 0], accum_data.intf[P_NW + 17 : P_NW]};
    pack_merged_data_vector.dwen = {pkt_in.dwen[P_MERGE_NW - 19 : 0], accum_data.dwen[P_NW + 17 : P_NW]};
    pack_merged_data_vector.ep = {pkt_in.ep[P_MERGE_NW - 19 : 0], accum_data.ep[P_NW + 17 : P_NW]};
    pack_merged_data_vector.badeot = {pkt_in.badeot[P_MERGE_NW - 19 : 0], accum_data.badeot[P_NW + 17 : P_NW]};
    pack_merged_data_vector.soh = {pkt_in_soh_vector[P_MERGE_NW - 19 : 0], accum_data.soh[P_NW + 17 : P_NW]};
    pack_merged_data_vector.ptm = {pkt_in.ptm[P_MERGE_NW - 19 : 0], accum_data.ptm[P_NW + 17 : P_NW]};
    pack_merged_data_vector.pme_to_ack = {pkt_in.pme_to_ack[P_MERGE_NW - 19 : 0], accum_data.pme_to_ack[P_NW + 17 : P_NW]};
    pack_merged_data_vector.data = {pkt_in.data[P_MERGE_NW - 19 : 0], accum_data.data[P_NW + 17 : P_NW]};
    pack_merged_data_vector.tlp_len = {pkt_in.tlp_len[P_MERGE_NW - 19 : 0], accum_data.tlp_len[P_NW + 17 : P_NW]};
    end
    36'b000000000000000001?????????????????? : begin
    pack_merged_data_vector.is_from_msg_gen = {pkt_in.is_from_msg_gen[P_MERGE_NW - 20 : 0] , accum_data.is_from_msg_gen[P_NW + 18 : P_NW]};
    pack_merged_data_vector.is_from_dma = {pkt_in.is_from_dma[P_MERGE_NW - 20 : 0] , accum_data.is_from_dma[P_NW + 18 : P_NW]};
    pack_merged_data_vector.sot = {pkt_in.sot[P_MERGE_NW - 20 : 0] , accum_data.sot[P_NW + 18 : P_NW]};
    pack_merged_data_vector.eot = {pkt_in.eot[P_MERGE_NW - 20 : 0], accum_data.eot[P_NW + 18 : P_NW]};
    pack_merged_data_vector.intf = {pkt_in.intf[P_MERGE_NW - 20 : 0], accum_data.intf[P_NW + 18 : P_NW]};
    pack_merged_data_vector.dwen = {pkt_in.dwen[P_MERGE_NW - 20 : 0], accum_data.dwen[P_NW + 18 : P_NW]};
    pack_merged_data_vector.ep = {pkt_in.ep[P_MERGE_NW - 20 : 0], accum_data.ep[P_NW + 18 : P_NW]};
    pack_merged_data_vector.badeot = {pkt_in.badeot[P_MERGE_NW - 20 : 0], accum_data.badeot[P_NW + 18 : P_NW]};
    pack_merged_data_vector.soh = {pkt_in_soh_vector[P_MERGE_NW - 20 : 0], accum_data.soh[P_NW + 18 : P_NW]};
    pack_merged_data_vector.ptm = {pkt_in.ptm[P_MERGE_NW - 20 : 0], accum_data.ptm[P_NW + 18 : P_NW]};
    pack_merged_data_vector.pme_to_ack = {pkt_in.pme_to_ack[P_MERGE_NW - 20 : 0], accum_data.pme_to_ack[P_NW + 18 : P_NW]};
    pack_merged_data_vector.data = {pkt_in.data[P_MERGE_NW - 20 : 0], accum_data.data[P_NW + 18 : P_NW]};
    pack_merged_data_vector.tlp_len = {pkt_in.tlp_len[P_MERGE_NW - 20 : 0], accum_data.tlp_len[P_NW + 18 : P_NW]};
    end
    36'b00000000000000001??????????????????? : begin
    pack_merged_data_vector.is_from_msg_gen = {pkt_in.is_from_msg_gen[P_MERGE_NW - 21 : 0] , accum_data.is_from_msg_gen[P_NW + 19 : P_NW]};
    pack_merged_data_vector.is_from_dma = {pkt_in.is_from_dma[P_MERGE_NW - 21 : 0] , accum_data.is_from_dma[P_NW + 19 : P_NW]};
    pack_merged_data_vector.sot = {pkt_in.sot[P_MERGE_NW - 21 : 0] , accum_data.sot[P_NW + 19 : P_NW]};
    pack_merged_data_vector.eot = {pkt_in.eot[P_MERGE_NW - 21 : 0], accum_data.eot[P_NW + 19 : P_NW]};
    pack_merged_data_vector.intf = {pkt_in.intf[P_MERGE_NW - 21 : 0], accum_data.intf[P_NW + 19 : P_NW]};
    pack_merged_data_vector.dwen = {pkt_in.dwen[P_MERGE_NW - 21 : 0], accum_data.dwen[P_NW + 19 : P_NW]};
    pack_merged_data_vector.ep = {pkt_in.ep[P_MERGE_NW - 21 : 0], accum_data.ep[P_NW + 19 : P_NW]};
    pack_merged_data_vector.badeot = {pkt_in.badeot[P_MERGE_NW - 21 : 0], accum_data.badeot[P_NW + 19 : P_NW]};
    pack_merged_data_vector.soh = {pkt_in_soh_vector[P_MERGE_NW - 21 : 0], accum_data.soh[P_NW + 19 : P_NW]};
    pack_merged_data_vector.ptm = {pkt_in.ptm[P_MERGE_NW - 21 : 0], accum_data.ptm[P_NW + 19 : P_NW]};
    pack_merged_data_vector.pme_to_ack = {pkt_in.pme_to_ack[P_MERGE_NW - 21 : 0], accum_data.pme_to_ack[P_NW + 19 : P_NW]};
    pack_merged_data_vector.data = {pkt_in.data[P_MERGE_NW - 21 : 0], accum_data.data[P_NW + 19 : P_NW]};
    pack_merged_data_vector.tlp_len = {pkt_in.tlp_len[P_MERGE_NW - 21 : 0], accum_data.tlp_len[P_NW + 19 : P_NW]};
    end
    36'b0000000000000001???????????????????? : begin
    pack_merged_data_vector.is_from_msg_gen = {pkt_in.is_from_msg_gen[P_MERGE_NW - 22 : 0] , accum_data.is_from_msg_gen[P_NW + 20 : P_NW]};
    pack_merged_data_vector.is_from_dma = {pkt_in.is_from_dma[P_MERGE_NW - 22 : 0] , accum_data.is_from_dma[P_NW + 20 : P_NW]};
    pack_merged_data_vector.sot = {pkt_in.sot[P_MERGE_NW - 22 : 0] , accum_data.sot[P_NW + 20 : P_NW]};
    pack_merged_data_vector.eot = {pkt_in.eot[P_MERGE_NW - 22 : 0], accum_data.eot[P_NW + 20 : P_NW]};
    pack_merged_data_vector.intf = {pkt_in.intf[P_MERGE_NW - 22 : 0], accum_data.intf[P_NW + 20 : P_NW]};
    pack_merged_data_vector.dwen = {pkt_in.dwen[P_MERGE_NW - 22 : 0], accum_data.dwen[P_NW + 20 : P_NW]};
    pack_merged_data_vector.ep = {pkt_in.ep[P_MERGE_NW - 22 : 0], accum_data.ep[P_NW + 20 : P_NW]};
    pack_merged_data_vector.badeot = {pkt_in.badeot[P_MERGE_NW - 22 : 0], accum_data.badeot[P_NW + 20 : P_NW]};
    pack_merged_data_vector.soh = {pkt_in_soh_vector[P_MERGE_NW - 22 : 0], accum_data.soh[P_NW + 20 : P_NW]};
    pack_merged_data_vector.ptm = {pkt_in.ptm[P_MERGE_NW - 22 : 0], accum_data.ptm[P_NW + 20 : P_NW]};
    pack_merged_data_vector.pme_to_ack = {pkt_in.pme_to_ack[P_MERGE_NW - 22 : 0], accum_data.pme_to_ack[P_NW + 20 : P_NW]};
    pack_merged_data_vector.data = {pkt_in.data[P_MERGE_NW - 22 : 0], accum_data.data[P_NW + 20 : P_NW]};
    pack_merged_data_vector.tlp_len = {pkt_in.tlp_len[P_MERGE_NW - 22 : 0], accum_data.tlp_len[P_NW + 20 : P_NW]};
    end
    36'b000000000000001????????????????????? : begin
    pack_merged_data_vector.is_from_msg_gen = {pkt_in.is_from_msg_gen[P_MERGE_NW - 23 : 0] , accum_data.is_from_msg_gen[P_NW + 21 : P_NW]};
    pack_merged_data_vector.is_from_dma = {pkt_in.is_from_dma[P_MERGE_NW - 23 : 0] , accum_data.is_from_dma[P_NW + 21 : P_NW]};
    pack_merged_data_vector.sot = {pkt_in.sot[P_MERGE_NW - 23 : 0] , accum_data.sot[P_NW + 21 : P_NW]};
    pack_merged_data_vector.eot = {pkt_in.eot[P_MERGE_NW - 23 : 0], accum_data.eot[P_NW + 21 : P_NW]};
    pack_merged_data_vector.intf = {pkt_in.intf[P_MERGE_NW - 23 : 0], accum_data.intf[P_NW + 21 : P_NW]};
    pack_merged_data_vector.dwen = {pkt_in.dwen[P_MERGE_NW - 23 : 0], accum_data.dwen[P_NW + 21 : P_NW]};
    pack_merged_data_vector.ep = {pkt_in.ep[P_MERGE_NW - 23 : 0], accum_data.ep[P_NW + 21 : P_NW]};
    pack_merged_data_vector.badeot = {pkt_in.badeot[P_MERGE_NW - 23 : 0], accum_data.badeot[P_NW + 21 : P_NW]};
    pack_merged_data_vector.soh = {pkt_in_soh_vector[P_MERGE_NW - 23 : 0], accum_data.soh[P_NW + 21 : P_NW]};
    pack_merged_data_vector.ptm = {pkt_in.ptm[P_MERGE_NW - 23 : 0], accum_data.ptm[P_NW + 21 : P_NW]};
    pack_merged_data_vector.pme_to_ack = {pkt_in.pme_to_ack[P_MERGE_NW - 23 : 0], accum_data.pme_to_ack[P_NW + 21 : P_NW]};
    pack_merged_data_vector.data = {pkt_in.data[P_MERGE_NW - 23 : 0], accum_data.data[P_NW + 21 : P_NW]};
    pack_merged_data_vector.tlp_len = {pkt_in.tlp_len[P_MERGE_NW - 23 : 0], accum_data.tlp_len[P_NW + 21 : P_NW]};
    end
    36'b00000000000001?????????????????????? : begin
    pack_merged_data_vector.is_from_msg_gen = {pkt_in.is_from_msg_gen[P_MERGE_NW - 24 : 0] , accum_data.is_from_msg_gen[P_NW + 22 : P_NW]};
    pack_merged_data_vector.is_from_dma = {pkt_in.is_from_dma[P_MERGE_NW - 24 : 0] , accum_data.is_from_dma[P_NW + 22 : P_NW]};
    pack_merged_data_vector.sot = {pkt_in.sot[P_MERGE_NW - 24 : 0] , accum_data.sot[P_NW + 22 : P_NW]};
    pack_merged_data_vector.eot = {pkt_in.eot[P_MERGE_NW - 24 : 0], accum_data.eot[P_NW + 22 : P_NW]};
    pack_merged_data_vector.intf = {pkt_in.intf[P_MERGE_NW - 24 : 0], accum_data.intf[P_NW + 22 : P_NW]};
    pack_merged_data_vector.dwen = {pkt_in.dwen[P_MERGE_NW - 24 : 0], accum_data.dwen[P_NW + 22 : P_NW]};
    pack_merged_data_vector.ep = {pkt_in.ep[P_MERGE_NW - 24 : 0], accum_data.ep[P_NW + 22 : P_NW]};
    pack_merged_data_vector.badeot = {pkt_in.badeot[P_MERGE_NW - 24 : 0], accum_data.badeot[P_NW + 22 : P_NW]};
    pack_merged_data_vector.soh = {pkt_in_soh_vector[P_MERGE_NW - 24 : 0], accum_data.soh[P_NW + 22 : P_NW]};
    pack_merged_data_vector.ptm = {pkt_in.ptm[P_MERGE_NW - 24 : 0], accum_data.ptm[P_NW + 22 : P_NW]};
    pack_merged_data_vector.pme_to_ack = {pkt_in.pme_to_ack[P_MERGE_NW - 24 : 0], accum_data.pme_to_ack[P_NW + 22 : P_NW]};
    pack_merged_data_vector.data = {pkt_in.data[P_MERGE_NW - 24 : 0], accum_data.data[P_NW + 22 : P_NW]};
    pack_merged_data_vector.tlp_len = {pkt_in.tlp_len[P_MERGE_NW - 24 : 0], accum_data.tlp_len[P_NW + 22 : P_NW]};
    end
    36'b0000000000001??????????????????????? : begin
    pack_merged_data_vector.is_from_msg_gen = {pkt_in.is_from_msg_gen[P_MERGE_NW - 25 : 0] , accum_data.is_from_msg_gen[P_NW + 23 : P_NW]};
    pack_merged_data_vector.is_from_dma = {pkt_in.is_from_dma[P_MERGE_NW - 25 : 0] , accum_data.is_from_dma[P_NW + 23 : P_NW]};
    pack_merged_data_vector.sot = {pkt_in.sot[P_MERGE_NW - 25 : 0] , accum_data.sot[P_NW + 23 : P_NW]};
    pack_merged_data_vector.eot = {pkt_in.eot[P_MERGE_NW - 25 : 0], accum_data.eot[P_NW + 23 : P_NW]};
    pack_merged_data_vector.intf = {pkt_in.intf[P_MERGE_NW - 25 : 0], accum_data.intf[P_NW + 23 : P_NW]};
    pack_merged_data_vector.dwen = {pkt_in.dwen[P_MERGE_NW - 25 : 0], accum_data.dwen[P_NW + 23 : P_NW]};
    pack_merged_data_vector.ep = {pkt_in.ep[P_MERGE_NW - 25 : 0], accum_data.ep[P_NW + 23 : P_NW]};
    pack_merged_data_vector.badeot = {pkt_in.badeot[P_MERGE_NW - 25 : 0], accum_data.badeot[P_NW + 23 : P_NW]};
    pack_merged_data_vector.soh = {pkt_in_soh_vector[P_MERGE_NW - 25 : 0], accum_data.soh[P_NW + 23 : P_NW]};
    pack_merged_data_vector.ptm = {pkt_in.ptm[P_MERGE_NW - 25 : 0], accum_data.ptm[P_NW + 23 : P_NW]};
    pack_merged_data_vector.pme_to_ack = {pkt_in.pme_to_ack[P_MERGE_NW - 25 : 0], accum_data.pme_to_ack[P_NW + 23 : P_NW]};
    pack_merged_data_vector.data = {pkt_in.data[P_MERGE_NW - 25 : 0], accum_data.data[P_NW + 23 : P_NW]};
    pack_merged_data_vector.tlp_len = {pkt_in.tlp_len[P_MERGE_NW - 25 : 0], accum_data.tlp_len[P_NW + 23 : P_NW]};
    end
    36'b000000000001???????????????????????? : begin
    pack_merged_data_vector.is_from_msg_gen = {pkt_in.is_from_msg_gen[P_MERGE_NW - 26 : 0] , accum_data.is_from_msg_gen[P_NW + 24 : P_NW]};
    pack_merged_data_vector.is_from_dma = {pkt_in.is_from_dma[P_MERGE_NW - 26 : 0] , accum_data.is_from_dma[P_NW + 24 : P_NW]};
    pack_merged_data_vector.sot = {pkt_in.sot[P_MERGE_NW - 26 : 0] , accum_data.sot[P_NW + 24 : P_NW]};
    pack_merged_data_vector.eot = {pkt_in.eot[P_MERGE_NW - 26 : 0], accum_data.eot[P_NW + 24 : P_NW]};
    pack_merged_data_vector.intf = {pkt_in.intf[P_MERGE_NW - 26 : 0], accum_data.intf[P_NW + 24 : P_NW]};
    pack_merged_data_vector.dwen = {pkt_in.dwen[P_MERGE_NW - 26 : 0], accum_data.dwen[P_NW + 24 : P_NW]};
    pack_merged_data_vector.ep = {pkt_in.ep[P_MERGE_NW - 26 : 0], accum_data.ep[P_NW + 24 : P_NW]};
    pack_merged_data_vector.badeot = {pkt_in.badeot[P_MERGE_NW - 26 : 0], accum_data.badeot[P_NW + 24 : P_NW]};
    pack_merged_data_vector.soh = {pkt_in_soh_vector[P_MERGE_NW - 26 : 0], accum_data.soh[P_NW + 24 : P_NW]};
    pack_merged_data_vector.ptm = {pkt_in.ptm[P_MERGE_NW - 26 : 0], accum_data.ptm[P_NW + 24 : P_NW]};
    pack_merged_data_vector.pme_to_ack = {pkt_in.pme_to_ack[P_MERGE_NW - 26 : 0], accum_data.pme_to_ack[P_NW + 24 : P_NW]};
    pack_merged_data_vector.data = {pkt_in.data[P_MERGE_NW - 26 : 0], accum_data.data[P_NW + 24 : P_NW]};
    pack_merged_data_vector.tlp_len = {pkt_in.tlp_len[P_MERGE_NW - 26 : 0], accum_data.tlp_len[P_NW + 24 : P_NW]};
    end
    36'b00000000001????????????????????????? : begin
    pack_merged_data_vector.is_from_msg_gen = {pkt_in.is_from_msg_gen[P_MERGE_NW - 27 : 0] , accum_data.is_from_msg_gen[P_NW + 25 : P_NW]};
    pack_merged_data_vector.is_from_dma = {pkt_in.is_from_dma[P_MERGE_NW - 27 : 0] , accum_data.is_from_dma[P_NW + 25 : P_NW]};
    pack_merged_data_vector.sot = {pkt_in.sot[P_MERGE_NW - 27 : 0] , accum_data.sot[P_NW + 25 : P_NW]};
    pack_merged_data_vector.eot = {pkt_in.eot[P_MERGE_NW - 27 : 0], accum_data.eot[P_NW + 25 : P_NW]};
    pack_merged_data_vector.intf = {pkt_in.intf[P_MERGE_NW - 27 : 0], accum_data.intf[P_NW + 25 : P_NW]};
    pack_merged_data_vector.dwen = {pkt_in.dwen[P_MERGE_NW - 27 : 0], accum_data.dwen[P_NW + 25 : P_NW]};
    pack_merged_data_vector.ep = {pkt_in.ep[P_MERGE_NW - 27 : 0], accum_data.ep[P_NW + 25 : P_NW]};
    pack_merged_data_vector.badeot = {pkt_in.badeot[P_MERGE_NW - 27 : 0], accum_data.badeot[P_NW + 25 : P_NW]};
    pack_merged_data_vector.soh = {pkt_in_soh_vector[P_MERGE_NW - 27 : 0], accum_data.soh[P_NW + 25 : P_NW]};
    pack_merged_data_vector.ptm = {pkt_in.ptm[P_MERGE_NW - 27 : 0], accum_data.ptm[P_NW + 25 : P_NW]};
    pack_merged_data_vector.pme_to_ack = {pkt_in.pme_to_ack[P_MERGE_NW - 27 : 0], accum_data.pme_to_ack[P_NW + 25 : P_NW]};
    pack_merged_data_vector.data = {pkt_in.data[P_MERGE_NW - 27 : 0], accum_data.data[P_NW + 25 : P_NW]};
    pack_merged_data_vector.tlp_len = {pkt_in.tlp_len[P_MERGE_NW - 27 : 0], accum_data.tlp_len[P_NW + 25 : P_NW]};
    end
    36'b0000000001?????????????????????????? : begin
    pack_merged_data_vector.is_from_msg_gen = {pkt_in.is_from_msg_gen[P_MERGE_NW - 28 : 0] , accum_data.is_from_msg_gen[P_NW + 26 : P_NW]};
    pack_merged_data_vector.is_from_dma = {pkt_in.is_from_dma[P_MERGE_NW - 28 : 0] , accum_data.is_from_dma[P_NW + 26 : P_NW]};
    pack_merged_data_vector.sot = {pkt_in.sot[P_MERGE_NW - 28 : 0] , accum_data.sot[P_NW + 26 : P_NW]};
    pack_merged_data_vector.eot = {pkt_in.eot[P_MERGE_NW - 28 : 0], accum_data.eot[P_NW + 26 : P_NW]};
    pack_merged_data_vector.intf = {pkt_in.intf[P_MERGE_NW - 28 : 0], accum_data.intf[P_NW + 26 : P_NW]};
    pack_merged_data_vector.dwen = {pkt_in.dwen[P_MERGE_NW - 28 : 0], accum_data.dwen[P_NW + 26 : P_NW]};
    pack_merged_data_vector.ep = {pkt_in.ep[P_MERGE_NW - 28 : 0], accum_data.ep[P_NW + 26 : P_NW]};
    pack_merged_data_vector.badeot = {pkt_in.badeot[P_MERGE_NW - 28 : 0], accum_data.badeot[P_NW + 26 : P_NW]};
    pack_merged_data_vector.soh = {pkt_in_soh_vector[P_MERGE_NW - 28 : 0], accum_data.soh[P_NW + 26 : P_NW]};
    pack_merged_data_vector.ptm = {pkt_in.ptm[P_MERGE_NW - 28 : 0], accum_data.ptm[P_NW + 26 : P_NW]};
    pack_merged_data_vector.pme_to_ack = {pkt_in.pme_to_ack[P_MERGE_NW - 28 : 0], accum_data.pme_to_ack[P_NW + 26 : P_NW]};
    pack_merged_data_vector.data = {pkt_in.data[P_MERGE_NW - 28 : 0], accum_data.data[P_NW + 26 : P_NW]};
    pack_merged_data_vector.tlp_len = {pkt_in.tlp_len[P_MERGE_NW - 28 : 0], accum_data.tlp_len[P_NW + 26 : P_NW]};
    end
    36'b000000001??????????????????????????? : begin
    pack_merged_data_vector.is_from_msg_gen = {pkt_in.is_from_msg_gen[P_MERGE_NW - 29 : 0] , accum_data.is_from_msg_gen[P_NW + 27 : P_NW]};
    pack_merged_data_vector.is_from_dma = {pkt_in.is_from_dma[P_MERGE_NW - 29 : 0] , accum_data.is_from_dma[P_NW + 27 : P_NW]};
    pack_merged_data_vector.sot = {pkt_in.sot[P_MERGE_NW - 29 : 0] , accum_data.sot[P_NW + 27 : P_NW]};
    pack_merged_data_vector.eot = {pkt_in.eot[P_MERGE_NW - 29 : 0], accum_data.eot[P_NW + 27 : P_NW]};
    pack_merged_data_vector.intf = {pkt_in.intf[P_MERGE_NW - 29 : 0], accum_data.intf[P_NW + 27 : P_NW]};
    pack_merged_data_vector.dwen = {pkt_in.dwen[P_MERGE_NW - 29 : 0], accum_data.dwen[P_NW + 27 : P_NW]};
    pack_merged_data_vector.ep = {pkt_in.ep[P_MERGE_NW - 29 : 0], accum_data.ep[P_NW + 27 : P_NW]};
    pack_merged_data_vector.badeot = {pkt_in.badeot[P_MERGE_NW - 29 : 0], accum_data.badeot[P_NW + 27 : P_NW]};
    pack_merged_data_vector.soh = {pkt_in_soh_vector[P_MERGE_NW - 29 : 0], accum_data.soh[P_NW + 27 : P_NW]};
    pack_merged_data_vector.ptm = {pkt_in.ptm[P_MERGE_NW - 29 : 0], accum_data.ptm[P_NW + 27 : P_NW]};
    pack_merged_data_vector.pme_to_ack = {pkt_in.pme_to_ack[P_MERGE_NW - 29 : 0], accum_data.pme_to_ack[P_NW + 27 : P_NW]};
    pack_merged_data_vector.data = {pkt_in.data[P_MERGE_NW - 29 : 0], accum_data.data[P_NW + 27 : P_NW]};
    pack_merged_data_vector.tlp_len = {pkt_in.tlp_len[P_MERGE_NW - 29 : 0], accum_data.tlp_len[P_NW + 27 : P_NW]};
    end
    default : begin
    pack_merged_data_vector.is_from_msg_gen = pkt_in.is_from_msg_gen;
    pack_merged_data_vector.is_from_dma = pkt_in.is_from_dma;
    pack_merged_data_vector.sot = pkt_in.sot;
    pack_merged_data_vector.eot = pkt_in.eot;
    pack_merged_data_vector.intf = pkt_in.intf;
    pack_merged_data_vector.dwen = pkt_in.dwen;
    pack_merged_data_vector.ep = pkt_in.ep;
    pack_merged_data_vector.badeot = pkt_in.badeot;
    pack_merged_data_vector.soh = pkt_in_soh_vector;
    pack_merged_data_vector.ptm = pkt_in.ptm;
    pack_merged_data_vector.data = pkt_in.data;
    pack_merged_data_vector.tlp_len = pkt_in.tlp_len;
    end
    endcase
  end
  pack_merged_data_vector.dv = |pack_merged_data_vector.dwen[P_NW-1:0];
  pack_merged_data_vector.tlp_prot = '0;
  pack_merged_data_vector.ras_dp_err_inband_kbd = pkt_in.ras_dp_err_inband_kbd || accum_data.ras_dp_err_inband_kbd;
  return pack_merged_data_vector;
  endfunction

  // Function Name  : halt_single_tlp
  // Description    : This function generates the halt for a single TLP interface
  //                  If an SOT or EOT is in the accumulation dont unhalt the interface
  //                  This is to avoid merging a new TLP with previous TLP content.
  // Inputs         : accum_data <xtlh_merge_pkt_struct>
  // Outputs        : halt_single_tlp <logic>
  function automatic logic halt_single_tlp (
    input xtlh_merge_pkt_struct  accum_data
  );
    begin
      halt_single_tlp = '0;
      if((|accum_data.sot) || (|accum_data.eot))
        halt_single_tlp = '1;
    end
    return halt_single_tlp;
  endfunction

  // Function Name  : count_dw
  // Description    : This function returns a count of the number of valid DW 
  //                  din <logic [P_NW-1:0]>
  // Outputs        : count_dw 
  function automatic logic [P_NW_CNT_WD : 0] count_dw (
    input [P_NW - 1 : 0] din
  );
    begin
      logic [P_NW_CNT_WD : 0] per_ndw_cnt [P_NW-1:0];
      count_dw = 0;
      for(int i = 0; i < P_NW; i++) begin
        if(i==0)
          per_ndw_cnt[i] = din[i] ? 1 : 0;
        else
          per_ndw_cnt[i] = per_ndw_cnt[i-1] + (din[i] ? 1 : 0);
      end
      count_dw = per_ndw_cnt[(P_NW-1)];
    end
    return count_dw;
  endfunction

  // Function Name  : count_sot_per_dw
  // Description    : This function returns a count of the number of valid DW 
  //                  din <logic [P_NW-1:0]>
  // Outputs        : count_sot_per_dw
  function automatic logic [P_NW_CNT_WD : 0] count_sot_per_dw (
    input [P_NW - 1 : 0] din
  );
    begin
      logic [P_NW_CNT_WD : 0] per_ndw_cnt [P_NW-1:0];
      count_sot_per_dw = 0;
      for(int i = 0; i < P_NW; i++) begin
        if(i==0)
          per_ndw_cnt[i] = din[i] ? 1 : 0;
        else
          per_ndw_cnt[i] = per_ndw_cnt[i-1] + (din[i] ? 1 : 0);
      end
      count_sot_per_dw = per_ndw_cnt[P_NW-1];
    end
    return count_sot_per_dw;
  endfunction

  // Function Name  : count_valid_dw 
  // Description    : This function returns a count of the number of valid DW 
  //                  dwen <logic [P_NDW-1:0]>
  // Outputs        : dw_cnt <int>
  function automatic logic [P_NDW_CNT_WD - 1 : 0] count_valid_dw (
    input [P_NDW - 1 : 0] dwen
  );
    begin
      logic [P_NDW_CNT_WD - 1 : 0] per_ndw_cnt [P_NDW-1:0];
      count_valid_dw = 0;
      for(int i = 0; i < P_NDW; i++) begin
        if(i==0)
          per_ndw_cnt[i] = dwen[i] ? 1 : 0;
        else
          per_ndw_cnt[i] = per_ndw_cnt[i-1] + (dwen[i] ? 1 : 0);
      end
      count_valid_dw = per_ndw_cnt[P_NDW-1];
    end
    return count_valid_dw;
  endfunction

  // Function Name  : calculate_num_if_fm 
  // Description    : This function calculates the number of interfaces that can be packed 
  //                  dwen0 <logic [P_NDW-1:0]>
  //                  dwen1 <logic [P_NDW-1:0]>
  //                  accum_dwen <logic [P_MERGE_NW-1:0]>
  // Outputs        : dw_cnt <int>
  function automatic integer calculate_num_if_fm (
    input [P_NDW - 1 : 0]   dwen0,
    input [P_NDW - 1 : 0]   dwen1,
    input [P_MERGE_NW - 1 : 0] accum_dwen
  );
    begin
      logic [P_NDW_CNT_WD : 0]  total_dwen;
      calculate_num_if_fm = 0;
      total_dwen = count_valid_dw(dwen0) + count_valid_dw(dwen1) + count_valid_dw(accum_dwen[P_NDW-1:0]);
      // If total dwen is less than P_NDW grant both interfaces
      if(total_dwen < P_NDW)
        calculate_num_if_fm = 2;
      else
        calculate_num_if_fm = 1;
    end
    return calculate_num_if_fm;
  endfunction

  // Function Name  : calculate_num_if_nfm 
  // Description    : This function calculates the number of interfaces that can be packed in non-flit mode
  //                  The first step is to calculate what would be the accumulated data path width by adding DWEN.
  //                  In non-flit if an SOT or EOT is accumulated we cant grant both interfaces.
  //                  dwen0 <logic [P_NDW-1:0]>
  //                  dwen1 <logic [P_NDW-1:0]>
  //                  accum_dwen <logic [P_MERGE_NW-1:0]>
  // Outputs        : dw_cnt <int>
  function automatic logic [1:0] calculate_num_if_nfm (
    input [P_NDW - 1 : 0]       dwen0,
    input [P_NDW - 1 : 0]       dwen1,
    input xtlh_merge_pkt_struct accum_data
  );
    begin
      int total_dwen;
      calculate_num_if_nfm = '0;
      total_dwen = count_valid_dw(dwen0) + count_valid_dw(dwen1) + count_valid_dw(accum_data.dwen[P_NDW-1:0]);
      // If total dwen is less than P_NDW we could grant both interfaces
      if(total_dwen < P_NDW) begin
        // If no EOT or SOT accumulated we can grant both interfaces
        if(!(|(accum_data.sot | accum_data.eot)))
          calculate_num_if_nfm = 2'd2;
        else
          calculate_num_if_nfm = 2'd1;
      end else
        calculate_num_if_nfm = 2'd1;
    end
    return calculate_num_if_nfm;
  endfunction

  // Function Name  : expand_to_vector 
  // Description    : This function expands a single bit input to a P_NDW width vector.
  //                  It is used to convert 1-bit signals like eot/ep/badeot to a P_NDW width vector.
  //                  The last bit set to 1 in the dwen vector determines which bit in the output vector is set to 1 all other bits in the vector are set to 0.
  //                  Example: dwen = 0xF && eot => expand_to_vector = 0x8
  // Inputs         : dwen <logic [P_NDW-1:0]>
  //                  single_bit <logic>
  // Outputs        : expand_to_vector <logic [P_NDW-1:0]>
  function automatic logic [P_NDW - 1 : 0] expand_to_vector(
    input                 single_bit,
    input [P_NDW - 1 : 0] dwen
  );
    logic [35 : 0]  int_dwen;
    expand_to_vector = '0;
    int_dwen = {{($bits(int_dwen)-P_NDW){1'b0}}, dwen};
    casez(int_dwen)
      36'b000000000000000000000000000000000001 : expand_to_vector = {{(P_NDW - 1 - 0){1'b0}}, single_bit, {0{1'b0}}};
      36'b00000000000000000000000000000000001? : expand_to_vector = {{(P_NDW - 1 - 1){1'b0}}, single_bit, {1{1'b0}}};
      36'b0000000000000000000000000000000001?? : expand_to_vector = {{(P_NDW - 1 - 2){1'b0}}, single_bit, {2{1'b0}}};
      36'b000000000000000000000000000000001??? : expand_to_vector = {{(P_NDW - 1 - 3){1'b0}}, single_bit, {3{1'b0}}};
      36'b00000000000000000000000000000001???? : expand_to_vector = {{(P_NDW - 1 - 4){1'b0}}, single_bit, {4{1'b0}}};
      36'b0000000000000000000000000000001????? : expand_to_vector = {{(P_NDW - 1 - 5){1'b0}}, single_bit, {5{1'b0}}};
      36'b000000000000000000000000000001?????? : expand_to_vector = {{(P_NDW - 1 - 6){1'b0}}, single_bit, {6{1'b0}}};
      36'b00000000000000000000000000001??????? : expand_to_vector = {{(P_NDW - 1 - 7){1'b0}}, single_bit, {7{1'b0}}};
      36'b0000000000000000000000000001???????? : expand_to_vector = {{(P_NDW - 1 - 8){1'b0}}, single_bit, {8{1'b0}}};
      36'b000000000000000000000000001????????? : expand_to_vector = {{(P_NDW - 1 - 9){1'b0}}, single_bit, {9{1'b0}}};
      36'b00000000000000000000000001?????????? : expand_to_vector = {{(P_NDW - 1 - 10){1'b0}}, single_bit, {10{1'b0}}};
      36'b0000000000000000000000001??????????? : expand_to_vector = {{(P_NDW - 1 - 11){1'b0}}, single_bit, {11{1'b0}}};
      36'b000000000000000000000001???????????? : expand_to_vector = {{(P_NDW - 1 - 12){1'b0}}, single_bit, {12{1'b0}}};
      36'b00000000000000000000001????????????? : expand_to_vector = {{(P_NDW - 1 - 13){1'b0}}, single_bit, {13{1'b0}}};
      36'b0000000000000000000001?????????????? : expand_to_vector = {{(P_NDW - 1 - 14){1'b0}}, single_bit, {14{1'b0}}};
      36'b000000000000000000001??????????????? : expand_to_vector = {{(P_NDW - 1 - 15){1'b0}}, single_bit, {15{1'b0}}};
      36'b00000000000000000001???????????????? : expand_to_vector = {{(P_NDW - 1 - 16){1'b0}}, single_bit, {16{1'b0}}};
      36'b0000000000000000001????????????????? : expand_to_vector = {{(P_NDW - 1 - 17){1'b0}}, single_bit, {17{1'b0}}};
      36'b000000000000000001?????????????????? : expand_to_vector = {{(P_NDW - 1 - 18){1'b0}}, single_bit, {18{1'b0}}};
      36'b00000000000000001??????????????????? : expand_to_vector = {{(P_NDW - 1 - 19){1'b0}}, single_bit, {19{1'b0}}};
      36'b0000000000000001???????????????????? : expand_to_vector = {{(P_NDW - 1 - 20){1'b0}}, single_bit, {20{1'b0}}};
      36'b000000000000001????????????????????? : expand_to_vector = {{(P_NDW - 1 - 21){1'b0}}, single_bit, {21{1'b0}}};
      36'b00000000000001?????????????????????? : expand_to_vector = {{(P_NDW - 1 - 22){1'b0}}, single_bit, {22{1'b0}}};
      36'b0000000000001??????????????????????? : expand_to_vector = {{(P_NDW - 1 - 23){1'b0}}, single_bit, {23{1'b0}}};
      36'b000000000001???????????????????????? : expand_to_vector = {{(P_NDW - 1 - 24){1'b0}}, single_bit, {24{1'b0}}};
      36'b00000000001????????????????????????? : expand_to_vector = {{(P_NDW - 1 - 25){1'b0}}, single_bit, {25{1'b0}}};
      36'b0000000001?????????????????????????? : expand_to_vector = {{(P_NDW - 1 - 26){1'b0}}, single_bit, {26{1'b0}}};
      36'b000000001??????????????????????????? : expand_to_vector = {{(P_NDW - 1 - 27){1'b0}}, single_bit, {27{1'b0}}};
      default : expand_to_vector = '0;
      endcase
    return expand_to_vector;
  endfunction
  
  // Function Name  : shift_data_only
  // Description    : Accumulated data exceeds CX_NW so the next cycle is shift without loading new data.
  // Inputs         : flit_dw_cnt - the flit data word count
  // Outputs        : shift_data_only <flit_shift_struct> 
  function automatic flit_shift_struct shift_data_only (
    input flit_shift_struct             prev_shift_data,
    input logic [P_DW_CNT_WD - 1 : 0]   flit_dw_cnt
  );
    shift_data_only = '0;
    // For 256-bit architecture or above the overhead is added in the last cycle of the flit.
    // If in the EOF cycle need to accomodate 5DW overhead.
    if(flit_dw_cnt == P_DW_LAST - 1) begin
      shift_data_only.data_valid = {{(P_SHIFT_NW-(2*P_NW)){1'b0}}, {(2*P_NW){prev_shift_data.data_valid[P_NW]}}};
      shift_data_only.data = {{(P_NW-5){P_NOP}}, prev_shift_data.data[P_SHIFT_NW - 1 : (P_NW+(P_NW-5))], {5{P_NOP}}, prev_shift_data.data[(P_NW+(P_NW-5)) - 1 : P_NW]};
      shift_data_only.sot = {{(P_NW-5){1'b0}}, prev_shift_data.sot[P_SHIFT_NW - 1 : (P_NW+(P_NW-5))], {5{1'b0}}, prev_shift_data.sot[(P_NW+(P_NW-5)) - 1 : P_NW]};
      shift_data_only.eot = {{(P_NW-5){1'b0}}, prev_shift_data.eot[P_SHIFT_NW - 1 : (P_NW+(P_NW-5))], {5{1'b0}}, prev_shift_data.eot[(P_NW+(P_NW-5)) - 1 : P_NW]};
      shift_data_only.flit_marker = {{(P_NW-5){4'h0}}, prev_shift_data.flit_marker[P_SHIFT_NW - 1 : (P_NW+(P_NW-5))], {5{4'h0}}, prev_shift_data.flit_marker[(P_NW+(P_NW-5)) - 1 : P_NW]};
    end
    else begin
      shift_data_only.data_valid = {{P_NW{P_NOP}}, prev_shift_data.data_valid[P_SHIFT_NW - 1 : P_NW]};
      shift_data_only.data = {{P_NW{P_NOP}}, prev_shift_data.data[P_SHIFT_NW - 1 : P_NW]};
      shift_data_only.sot = {{P_NW{P_NOP}}, prev_shift_data.sot[P_SHIFT_NW - 1 : P_NW]};
      shift_data_only.eot = {{P_NW{P_NOP}}, prev_shift_data.eot[P_SHIFT_NW - 1 : P_NW]};
      shift_data_only.flit_marker = {{P_NW{4'h0}}, prev_shift_data.flit_marker[P_SHIFT_NW - 1 : P_NW]};
    end
    return shift_data_only;
  endfunction

  // Function Name  : load_data
  // Description    : Load new data
  function automatic flit_shift_struct load_data (
    input flit_shift_struct             prev_shift_data,
    input                               dv,
    input [P_NW-1:0] [31:0]             data,
    input [P_NW-1:0]                    sot,
    input [P_NW-1:0]                    eot,
    input flit_marker_struct [P_NW-1:0] flit_marker,
    input logic [P_DW_CNT_WD - 1 : 0]   flit_dw_cnt
  );
    logic dv_overflow;
    load_data = '0;
    dv_overflow = '0;
    if(dv) begin
      // If the data path width is 256-bit or greater the overflow is accounted for in the last flit cycle
      if(flit_dw_cnt == P_DW_LAST - 1) begin
          // No EOT in overflow position and EOT and SOT < EOT
          dv_overflow = (!(|eot[(P_NW-1) : (P_NW-5)]) && (|eot) && (sot<=eot)) ? '0 : dv;
          load_data.data_valid = {{(P_SHIFT_NW-(2*P_NW)){1'b0}}, {P_NW{dv_overflow}}, {P_NW{dv}}};
          load_data.data = {{(P_SHIFT_NW-5-P_NW){P_NOP}}, data[P_NW-1 : (P_NW-5)], {5{P_NOP}}, data[(P_NW-5-1) : 0]};
          load_data.sot = {{(P_SHIFT_NW-5-P_NW){1'b0}}, sot[P_NW-1 : (P_NW-5)], {5{1'b0}}, sot[(P_NW-5-1) : 0]};
          load_data.eot = {{(P_SHIFT_NW-5-P_NW){1'b0}}, eot[P_NW-1 : (P_NW-5)], {5{1'b0}}, eot[(P_NW-5-1) : 0]};
          load_data.flit_marker = {{(P_SHIFT_NW-5-P_NW){4'h0}}, flit_marker[P_NW-1 : (P_NW-5)], {5{4'h0}}, flit_marker[(P_NW-5-1) : 0]};
      end
      else begin
        load_data.data_valid = {{(P_SHIFT_NW-P_NW){1'b0}}, {P_NW{dv}}};
        load_data.data = {{(P_SHIFT_NW-P_NW){P_NOP}}, data};
        load_data.sot = {{(P_SHIFT_NW-P_NW){1'b0}}, sot};
        load_data.eot = {{(P_SHIFT_NW-P_NW){1'b0}}, eot};
        load_data.flit_marker = {{(P_SHIFT_NW-P_NW){4'h0}}, flit_marker};
      end
    end
    return load_data;
  endfunction

  // Function Name  : load_accum_1dw 
  // Description    : Load new data and merge with 1DW accumulated in the previous cycle
  function automatic flit_shift_struct load_accum_1dw (
    input flit_shift_struct             prev_shift_data,
    input                               dv,
    input [P_NW-1:0] [31:0]             data,
    input [P_NW-1:0]                    sot,
    input [P_NW-1:0]                    eot,
    input flit_marker_struct [P_NW-1:0] flit_marker,
    input logic [P_DW_CNT_WD - 1 : 0]   flit_dw_cnt
  );
    logic dv_overflow;
    load_accum_1dw = '0;
    dv_overflow = '0;
    if(dv) begin
      // If the data path width is 256-bit or greater the overflow is accounted for in the last flit cycle
      if(flit_dw_cnt == P_DW_LAST - 1) begin
        // No EOT in overflow position and SOT < EOT
        dv_overflow = (!(|eot[(P_NW-1) : (P_NW-5-1)]) && (|eot) && (sot<=eot)) ? '0 : dv;
        load_accum_1dw.data_valid = {{(P_SHIFT_NW-(P_NW+5-2+2+1)){1'b0}}, {(P_NW+5-2){dv_overflow}}, {2{dv}}, prev_shift_data.data_valid[P_NW : P_NW]};
        load_accum_1dw.data = {{(P_SHIFT_NW-6-P_NW){P_NOP}}, data[P_NW - 1 : (P_NW-5-1)], {5{P_NOP}}, data[(P_NW-5-1-1) : 0], prev_shift_data.data[P_NW : P_NW]};
        load_accum_1dw.sot = {{(P_SHIFT_NW-6-P_NW){1'b0}}, sot[P_NW - 1 : (P_NW-5-1)], {5{1'b0}}, sot[(P_NW-5-1-1) : 0], prev_shift_data.sot[P_NW : P_NW]};
        load_accum_1dw.eot = {{(P_SHIFT_NW-6-P_NW){1'b0}}, eot[P_NW - 1 : (P_NW-5-1)], {5{1'b0}}, eot[(P_NW-5-1-1) : 0], prev_shift_data.eot[P_NW : P_NW]};
        load_accum_1dw.flit_marker = {{(P_SHIFT_NW-6-P_NW){4'h0}}, flit_marker[P_NW - 1 : (P_NW-5-1)], {5{4'h0}}, flit_marker[(P_NW-5-1-1) : 0], prev_shift_data.flit_marker[P_NW : P_NW]};
      end
      else begin
        load_accum_1dw.data_valid = {{(P_SHIFT_NW-(2*P_NW)){1'b0}}, {P_NW{dv}}, {P_NW{prev_shift_data.data_valid[P_NW : P_NW]}}};
        load_accum_1dw.data = {{(P_SHIFT_NW-1-P_NW){P_NOP}}, data, prev_shift_data.data[P_NW : P_NW]};
        load_accum_1dw.sot = {{(P_SHIFT_NW-1-P_NW){1'b0}}, sot, prev_shift_data.sot[P_NW : P_NW]};
        load_accum_1dw.eot = {{(P_SHIFT_NW-1-P_NW){1'b0}}, eot, prev_shift_data.eot[P_NW : P_NW]};
        load_accum_1dw.flit_marker = {{(P_SHIFT_NW-1-P_NW){4'h0}}, flit_marker, prev_shift_data.flit_marker[P_NW : P_NW]};
      end
    end else begin
      load_accum_1dw.data_valid = {{(P_SHIFT_NW-1){1'b0}}, prev_shift_data.data_valid[P_NW : P_NW]};
      load_accum_1dw.data = {{(P_SHIFT_NW-1){P_NOP}}, prev_shift_data.data[P_NW : P_NW]};
      load_accum_1dw.sot = {{(P_SHIFT_NW-1){1'b0}}, prev_shift_data.sot[P_NW : P_NW]};
      load_accum_1dw.eot = {{(P_SHIFT_NW-1){1'b0}}, prev_shift_data.eot[P_NW : P_NW]};
      load_accum_1dw.flit_marker = {{(P_SHIFT_NW-1){4'h0}}, prev_shift_data.flit_marker[P_NW : P_NW]};
    end
    return load_accum_1dw;
  endfunction

  // Function Name  : load_accum_2dw 
  // Description    : Load new data and merge with 2DW accumulated in the previous cycle
  function automatic flit_shift_struct load_accum_2dw (
    input flit_shift_struct             prev_shift_data,
    input                               dv,
    input [P_NW-1:0] [31:0]             data,
    input [P_NW-1:0]                    sot,
    input [P_NW-1:0]                    eot,
    input flit_marker_struct [P_NW-1:0] flit_marker,
    input logic [P_DW_CNT_WD - 1 : 0]   flit_dw_cnt
  );
    logic dv_overflow;
    logic prev_dv;
    load_accum_2dw = '0;
    dv_overflow = '0;
    prev_dv = '0;
    if(dv) begin
      // If the data path width is 256-bit or greater the overflow is accounted for in the last flit cycle
      if(flit_dw_cnt == P_DW_LAST - 1) begin
        // No EOT in overflow position and SOT < EOT
        dv_overflow = (!(|eot[(P_NW-1) : (P_NW-5-2)]) && (|eot) && (sot<=eot)) ? '0 : dv;
        load_accum_2dw.data_valid = {{(P_SHIFT_NW-(P_NW+5-1+1+2)){1'b0}}, {(P_NW+5-1){dv_overflow}}, dv, prev_shift_data.data_valid[(P_NW+1) : P_NW]};
        load_accum_2dw.data = {{(P_SHIFT_NW-7-P_NW){P_NOP}}, data[P_NW - 1 : (P_NW-5-2)], {5{P_NOP}}, data[(P_NW-5-2-1) : 0], prev_shift_data.data[(P_NW+1) : P_NW]};
        load_accum_2dw.sot = {{(P_SHIFT_NW-7-P_NW){1'b0}}, sot[P_NW - 1 : (P_NW-5-2)], {5{1'b0}}, sot[(P_NW-5-2-1) : 0], prev_shift_data.sot[(P_NW+1) : P_NW]};
        load_accum_2dw.eot = {{(P_SHIFT_NW-7-P_NW){1'b0}}, eot[P_NW - 1 : (P_NW-5-2)], {5{1'b0}}, eot[(P_NW-5-2-1) : 0], prev_shift_data.eot[(P_NW+1) : P_NW]};
        load_accum_2dw.flit_marker = {{(P_SHIFT_NW-7-P_NW){4'h0}}, flit_marker[P_NW - 1 : (P_NW-5-2)], {5{4'h0}}, flit_marker[(P_NW-5-2-1) : 0], prev_shift_data.flit_marker[(P_NW+1) : P_NW]};
      end
      else begin
        prev_dv = |prev_shift_data.data_valid[(P_NW+1) : P_NW] || dv;
        load_accum_2dw.data_valid = {{(P_SHIFT_NW-(2*P_NW)){1'b0}}, {P_NW{dv}}, {P_NW{prev_dv}}};
        load_accum_2dw.data = {{(P_SHIFT_NW-2-P_NW){P_NOP}}, data, prev_shift_data.data[(P_NW+1) : P_NW]};
        load_accum_2dw.sot = {{(P_SHIFT_NW-2-P_NW){1'b0}}, sot, prev_shift_data.sot[(P_NW+1) : P_NW]};
        load_accum_2dw.eot = {{(P_SHIFT_NW-2-P_NW){1'b0}}, eot, prev_shift_data.eot[(P_NW+1) : P_NW]};
        load_accum_2dw.flit_marker = {{(P_SHIFT_NW-2-P_NW){4'h0}}, flit_marker, prev_shift_data.flit_marker[(P_NW+1) : P_NW]};
      end
    end else begin
        prev_dv = |prev_shift_data.data_valid[(P_NW+1) : P_NW];
        load_accum_2dw.data_valid = {{(P_SHIFT_NW-P_NW){1'b0}}, {P_NW{prev_dv}}};
        load_accum_2dw.data = {{(P_SHIFT_NW-2){P_NOP}}, prev_shift_data.data[(P_NW+1) : P_NW]};
        load_accum_2dw.sot = {{(P_SHIFT_NW-2){1'b0}}, prev_shift_data.sot[(P_NW+1) : P_NW]};
        load_accum_2dw.eot = {{(P_SHIFT_NW-2){1'b0}}, prev_shift_data.eot[(P_NW+1) : P_NW]};
        load_accum_2dw.flit_marker = {{(P_SHIFT_NW-2){4'h0}}, prev_shift_data.flit_marker[(P_NW+1) : P_NW]};
    end
    return load_accum_2dw;
  endfunction

  // Function Name  : load_accum_3dw 
  // Description    : Load new data and merge with 3DW accumulated in the previous cycle
  function automatic flit_shift_struct load_accum_3dw (
    input flit_shift_struct             prev_shift_data,
    input                               dv,
    input [P_NW-1:0] [31:0]             data,
    input [P_NW-1:0]                    sot,
    input [P_NW-1:0]                    eot,
    input flit_marker_struct [P_NW-1:0] flit_marker,
    input logic [P_DW_CNT_WD - 1 : 0]   flit_dw_cnt
  );
    logic dv_overflow;
    logic prev_dv;
    load_accum_3dw = '0;
    dv_overflow = '0;
    prev_dv = |prev_shift_data.data_valid[(P_NW+2) : P_NW];
    if(dv) begin
      // If the data path width is 512-bit or greater the overflow is accounted for in the last flit cycle
      if(flit_dw_cnt == P_DW_LAST - 1) begin
        // No EOT in overflow position and SOT < EOT
        dv_overflow = (!(|eot[(P_NW-1) : (P_NW-5-3)]) && (|eot) && (sot<=eot)) ? '0 : dv;
        load_accum_3dw.data_valid = {{(P_SHIFT_NW-(P_NW+5+3)){1'b0}}, {(P_NW+5){dv_overflow}}, prev_shift_data.data_valid[(P_NW+2) : P_NW]};
        load_accum_3dw.data_valid = {{(P_SHIFT_NW-(2*P_NW)){1'b0}}, {P_NW{dv_overflow}}, {P_NW{dv}}};
        load_accum_3dw.data = {{(P_SHIFT_NW-8-P_NW){P_NOP}}, data[P_NW - 1 : (P_NW-5-3)], {5{P_NOP}}, data[(P_NW-5-3-1) : 0], prev_shift_data.data[(P_NW+2) : P_NW]};
        load_accum_3dw.sot = {{(P_SHIFT_NW-8-P_NW){1'b0}}, sot[P_NW - 1 : (P_NW-5-3)], {5{1'b0}}, sot[(P_NW-5-3-1) : 0], prev_shift_data.sot[(P_NW+2) : P_NW]};
        load_accum_3dw.eot = {{(P_SHIFT_NW-8-P_NW){1'b0}}, eot[P_NW - 1 : (P_NW-5-3)], {5{1'b0}}, eot[(P_NW-5-3-1) : 0], prev_shift_data.eot[(P_NW+2) : P_NW]};
        load_accum_3dw.flit_marker = {{(P_SHIFT_NW-8-P_NW){4'h0}}, flit_marker[P_NW - 1 : (P_NW-5-3)], {5{4'h0}}, flit_marker[(P_NW-5-3-1) : 0], prev_shift_data.flit_marker[(P_NW+2) : P_NW]};
      end
      else begin
        load_accum_3dw.data_valid = {{(P_SHIFT_NW-(2*P_NW)){1'b0}}, {P_NW{dv}}, {P_NW{prev_dv}}};
        load_accum_3dw.data = {{(P_SHIFT_NW-3-P_NW){P_NOP}}, data, prev_shift_data.data[(P_NW+2) : P_NW]};
        load_accum_3dw.sot = {{(P_SHIFT_NW-3-P_NW){1'b0}}, sot, prev_shift_data.sot[(P_NW+2) : P_NW]};
        load_accum_3dw.eot = {{(P_SHIFT_NW-3-P_NW){1'b0}}, eot, prev_shift_data.eot[(P_NW+2) : P_NW]};
        load_accum_3dw.flit_marker = {{(P_SHIFT_NW-3-P_NW){4'h0}}, flit_marker, prev_shift_data.flit_marker[(P_NW+2) : P_NW]};
      end
    end else begin
      load_accum_3dw.data_valid = {{(P_SHIFT_NW-P_NW){1'b0}}, {P_NW{prev_dv}}};
      load_accum_3dw.data = {{(P_SHIFT_NW-3){P_NOP}}, prev_shift_data.data[(P_NW+2) : P_NW]};
      load_accum_3dw.sot = {{(P_SHIFT_NW-3){1'b0}}, prev_shift_data.sot[(P_NW+2) : P_NW]};
      load_accum_3dw.eot = {{(P_SHIFT_NW-3){1'b0}}, prev_shift_data.eot[(P_NW+2) : P_NW]};
      load_accum_3dw.flit_marker = {{(P_SHIFT_NW-3){4'h0}}, prev_shift_data.flit_marker[(P_NW+2) : P_NW]};
    end
    return load_accum_3dw;
  endfunction

  // Function Name  : load_accum_4dw 
  // Description    : Load new data and merge with 4DW accumulated in the previous cycle
  function automatic flit_shift_struct load_accum_4dw (
    input flit_shift_struct             prev_shift_data,
    input                               dv,
    input [P_NW-1:0] [31:0]             data,
    input [P_NW-1:0]                    sot,
    input [P_NW-1:0]                    eot,
    input flit_marker_struct [P_NW-1:0] flit_marker,
    input logic [P_DW_CNT_WD - 1 : 0]   flit_dw_cnt
  );
    logic dv_overflow;
    logic prev_dv;
    load_accum_4dw = '0;
    dv_overflow = '0;
    prev_dv = |prev_shift_data.data_valid[(P_NW+3) : P_NW];
    if(dv) begin
      // If the data path width is 512-bit or greater the overflow is accounted for in the last flit cycle
      if(flit_dw_cnt == P_DW_LAST - 1) begin
        // No EOT in overflow position and SOT < EOT
        dv_overflow = (!(|eot[(P_NW-1) : (P_NW-5-4)]) && (|eot) && (sot<=eot)) ? '0 : dv;
        load_accum_4dw.data_valid = {{(P_SHIFT_NW-(2*P_NW)){1'b0}}, {P_NW{dv_overflow}}, {P_NW{dv}}};
        load_accum_4dw.data = {{(P_SHIFT_NW-9-P_NW){P_NOP}}, data[P_NW - 1 : (P_NW-5-4)], {5{P_NOP}}, data[(P_NW-5-4-1) : 0], prev_shift_data.data[(P_NW+3) : P_NW]};
        load_accum_4dw.sot = {{(P_SHIFT_NW-9-P_NW){1'b0}}, sot[P_NW - 1 : (P_NW-5-4)], {5{1'b0}}, sot[(P_NW-5-4-1) : 0], prev_shift_data.sot[(P_NW+3) : P_NW]};
        load_accum_4dw.eot = {{(P_SHIFT_NW-9-P_NW){1'b0}}, eot[P_NW - 1 : (P_NW-5-4)], {5{1'b0}}, eot[(P_NW-5-4-1) : 0], prev_shift_data.eot[(P_NW+3) : P_NW]};
        load_accum_4dw.flit_marker = {{(P_SHIFT_NW-9-P_NW){4'h0}}, flit_marker[P_NW - 1 : (P_NW-5-4)], {5{4'h0}}, flit_marker[(P_NW-5-4-1) : 0], prev_shift_data.flit_marker[(P_NW+3) : P_NW]};
      end
      else begin
        load_accum_4dw.data_valid = {{(P_SHIFT_NW-(2*P_NW)){1'b0}}, {P_NW{dv}}, {P_NW{prev_dv}}};
        load_accum_4dw.data = {{(P_SHIFT_NW-4-P_NW){P_NOP}}, data, prev_shift_data.data[(P_NW+3) : P_NW]};
        load_accum_4dw.sot = {{(P_SHIFT_NW-4-P_NW){1'b0}}, sot, prev_shift_data.sot[(P_NW+3) : P_NW]};
        load_accum_4dw.eot = {{(P_SHIFT_NW-4-P_NW){1'b0}}, eot, prev_shift_data.eot[(P_NW+3) : P_NW]};
        load_accum_4dw.flit_marker = {{(P_SHIFT_NW-4-P_NW){4'h0}}, flit_marker, prev_shift_data.flit_marker[(P_NW+3) : P_NW]};
      end
    end else begin
          load_accum_4dw.data_valid = {{(P_SHIFT_NW-P_NW){1'b0}}, {P_NW{prev_dv}}};
          load_accum_4dw.data = {{(P_SHIFT_NW-4){P_NOP}}, prev_shift_data.data[(P_NW+3) : P_NW]};
          load_accum_4dw.sot = {{(P_SHIFT_NW-4){1'b0}}, prev_shift_data.sot[(P_NW+3) : P_NW]};
          load_accum_4dw.eot = {{(P_SHIFT_NW-4){1'b0}}, prev_shift_data.eot[(P_NW+3) : P_NW]};
          load_accum_4dw.flit_marker = {{(P_SHIFT_NW-4){4'h0}}, prev_shift_data.flit_marker[(P_NW+3) : P_NW]};
      end
    return load_accum_4dw;
  endfunction

  // Function Name  : load_accum_5dw 
  // Description    : Load new data and merge with 5DW accumulated in the previous cycle
  function automatic flit_shift_struct load_accum_5dw (
    input flit_shift_struct             prev_shift_data,
    input                               dv,
    input [P_NW-1:0] [31:0]             data,
    input [P_NW-1:0]                    sot,
    input [P_NW-1:0]                    eot,
    input flit_marker_struct [P_NW-1:0] flit_marker,
    input logic [P_DW_CNT_WD - 1 : 0]   flit_dw_cnt
  );
    logic dv_overflow;
    logic prev_dv;
    load_accum_5dw = '0;
    dv_overflow = '0;
    prev_dv = |prev_shift_data.data_valid[(P_NW+4) : P_NW];
    if(dv) begin
      // If the data path width is 512-bit or greater the overflow is accounted for in the last flit cycle
      if(flit_dw_cnt == P_DW_LAST - 1) begin
        // No EOT in overflow position and SOT < EOT
        dv_overflow = (!(|eot[(P_NW-1) : (P_NW-5-5)]) && (|eot) && (sot<=eot)) ? '0 : dv;
        load_accum_5dw.data_valid = {{(P_SHIFT_NW-(2*P_NW)){1'b0}}, {P_NW{dv_overflow}}, {P_NW{dv}}};
        load_accum_5dw.data = {{(P_SHIFT_NW-10-P_NW){P_NOP}}, data[P_NW - 1 : (P_NW-5-5)], {5{P_NOP}}, data[(P_NW-5-5-1) : 0], prev_shift_data.data[(P_NW+4) : P_NW]};
        load_accum_5dw.sot = {{(P_SHIFT_NW-10-P_NW){1'b0}}, sot[P_NW - 1 : (P_NW-5-5)], {5{1'b0}}, sot[(P_NW-5-5-1) : 0], prev_shift_data.sot[(P_NW+4) : P_NW]};
        load_accum_5dw.eot = {{(P_SHIFT_NW-10-P_NW){1'b0}}, eot[P_NW - 1 : (P_NW-5-5)], {5{1'b0}}, eot[(P_NW-5-5-1) : 0], prev_shift_data.eot[(P_NW+4) : P_NW]};
        load_accum_5dw.flit_marker = {{(P_SHIFT_NW-10-P_NW){4'h0}}, flit_marker[P_NW - 1 : (P_NW-5-5)], {5{4'h0}}, flit_marker[(P_NW-5-5-1) : 0], prev_shift_data.flit_marker[(P_NW+4) : P_NW]};
      end
      else begin
        load_accum_5dw.data_valid = {{(P_SHIFT_NW-(2*P_NW)){1'b0}}, {P_NW{dv}}, {P_NW{prev_dv}}};
        load_accum_5dw.data = {{(P_SHIFT_NW-5-P_NW){P_NOP}}, data, prev_shift_data.data[(P_NW+4) : P_NW]};
        load_accum_5dw.sot = {{(P_SHIFT_NW-5-P_NW){1'b0}}, sot, prev_shift_data.sot[(P_NW+4) : P_NW]};
        load_accum_5dw.eot = {{(P_SHIFT_NW-5-P_NW){1'b0}}, eot, prev_shift_data.eot[(P_NW+4) : P_NW]};
        load_accum_5dw.flit_marker = {{(P_SHIFT_NW-5-P_NW){4'h0}}, flit_marker, prev_shift_data.flit_marker[(P_NW+4) : P_NW]};
      end
    end else begin
        load_accum_5dw.data_valid = {{(P_SHIFT_NW-P_NW){1'b0}}, {P_NW{prev_dv}}};
        load_accum_5dw.data = {{(P_SHIFT_NW-5){P_NOP}}, prev_shift_data.data[(P_NW+4) : P_NW]};
        load_accum_5dw.sot = {{(P_SHIFT_NW-5){1'b0}}, prev_shift_data.sot[(P_NW+4) : P_NW]};
        load_accum_5dw.eot = {{(P_SHIFT_NW-5){1'b0}}, prev_shift_data.eot[(P_NW+4) : P_NW]};
        load_accum_5dw.flit_marker = {{(P_SHIFT_NW-5){4'h0}}, prev_shift_data.flit_marker[(P_NW+4) : P_NW]};
    end
    return load_accum_5dw;
  endfunction

  // Function Name  : load_accum_6dw 
  // Description    : Load new data and merge with 4DW accumulated in the previous cycle
  function automatic flit_shift_struct load_accum_6dw (
    input flit_shift_struct             prev_shift_data,
    input                               dv,
    input [P_NW-1:0] [31:0]             data,
    input [P_NW-1:0]                    sot,
    input [P_NW-1:0]                    eot,
    input flit_marker_struct [P_NW-1:0] flit_marker,
    input logic [P_DW_CNT_WD - 1 : 0]   flit_dw_cnt
  );
    logic dv_overflow;
    logic prev_dv;
    load_accum_6dw = '0;
    dv_overflow = '0;
    prev_dv = |prev_shift_data.data_valid[(P_NW+5) : P_NW];
    if(dv) begin
      // If the data path width is 512-bit or greater the overflow is accounted for in the last flit cycle
      if(flit_dw_cnt == P_DW_LAST - 1) begin
        dv_overflow = (!(|eot[(P_NW-1) : (P_NW-5-6)]) && (|eot) && (sot<=eot)) ? '0 : dv;
        load_accum_6dw.data_valid = {{(P_SHIFT_NW-(2*P_NW)){1'b0}}, {P_NW{dv_overflow}}, {P_NW{dv}}};
        load_accum_6dw.data = {{(P_SHIFT_NW-11-P_NW){P_NOP}}, data[P_NW - 1 : (P_NW-5-6)], {5{P_NOP}}, data[(P_NW-5-6-1) : 0], prev_shift_data.data[(P_NW+5) : P_NW]};
        load_accum_6dw.sot = {{(P_SHIFT_NW-11-P_NW){1'b0}}, sot[P_NW - 1 : (P_NW-5-6)], {5{1'b0}}, sot[(P_NW-5-6-1) : 0], prev_shift_data.sot[(P_NW+5) : P_NW]};
        load_accum_6dw.eot = {{(P_SHIFT_NW-11-P_NW){1'b0}}, eot[P_NW - 1 : (P_NW-5-6)], {5{1'b0}}, eot[(P_NW-5-6-1) : 0], prev_shift_data.eot[(P_NW+5) : P_NW]};
        load_accum_6dw.flit_marker = {{(P_SHIFT_NW-11-P_NW){4'h0}}, flit_marker[P_NW - 1 : (P_NW-5-6)], {5{4'h0}}, flit_marker[(P_NW-5-6-1) : 0], prev_shift_data.flit_marker[(P_NW+5) : P_NW]};
      end
      else begin
        load_accum_6dw.data_valid = {{(P_SHIFT_NW-(2*P_NW)){1'b0}}, {P_NW{dv}}, {P_NW{prev_dv}}};
        load_accum_6dw.data = {{(P_SHIFT_NW-6-P_NW){P_NOP}}, data, prev_shift_data.data[(P_NW+5) : P_NW]};
        load_accum_6dw.sot = {{(P_SHIFT_NW-6-P_NW){1'b0}}, sot, prev_shift_data.sot[(P_NW+5) : P_NW]};
        load_accum_6dw.eot = {{(P_SHIFT_NW-6-P_NW){1'b0}}, eot, prev_shift_data.eot[(P_NW+5) : P_NW]};
        load_accum_6dw.flit_marker = {{(P_SHIFT_NW-6-P_NW){4'h0}}, flit_marker, prev_shift_data.flit_marker[(P_NW+5) : P_NW]};
      end
    end else begin
        load_accum_6dw.data_valid = {{(P_SHIFT_NW-P_NW){1'b0}}, {P_NW{prev_dv}}};
        load_accum_6dw.data = {{(P_SHIFT_NW-6){P_NOP}}, prev_shift_data.data[(P_NW+5) : P_NW]};
        load_accum_6dw.sot = {{(P_SHIFT_NW-6){1'b0}}, prev_shift_data.sot[(P_NW+5) : P_NW]};
        load_accum_6dw.eot = {{(P_SHIFT_NW-6){1'b0}}, prev_shift_data.eot[(P_NW+5) : P_NW]};
        load_accum_6dw.flit_marker = {{(P_SHIFT_NW-6){4'h0}}, prev_shift_data.flit_marker[(P_NW+5) : P_NW]};
    end
    return load_accum_6dw;
  endfunction

  // Function Name  : load_accum_7dw 
  // Description    : Load new data and merge with 4DW accumulated in the previous cycle
  function automatic flit_shift_struct load_accum_7dw (
    input flit_shift_struct             prev_shift_data,
    input                               dv,
    input [P_NW-1:0] [31:0]             data,
    input [P_NW-1:0]                    sot,
    input [P_NW-1:0]                    eot,
    input flit_marker_struct [P_NW-1:0] flit_marker,
    input logic [P_DW_CNT_WD - 1 : 0]   flit_dw_cnt
  );
    logic dv_overflow;
    logic prev_dv;
    load_accum_7dw = '0;
    dv_overflow = '0;
    prev_dv = |prev_shift_data.data_valid[(P_NW+6) : P_NW];
    if(dv) begin
      // If the data path width is 512-bit or greater the overflow is accounted for in the last flit cycle
      if(flit_dw_cnt == P_DW_LAST - 1) begin
        dv_overflow = (!(|eot[(P_NW-1) : (P_NW-5-7)]) && (|eot) && (sot<=eot)) ? '0 : dv;
        load_accum_7dw.data_valid = {{(P_SHIFT_NW-(2*P_NW)){1'b0}}, {P_NW{dv_overflow}}, {P_NW{dv}}};
        load_accum_7dw.data = {{(P_SHIFT_NW-12-P_NW){P_NOP}}, data[P_NW - 1 : (P_NW-5-7)], {5{P_NOP}}, data[(P_NW-5-7-1) : 0], prev_shift_data.data[(P_NW+6) : P_NW]};
        load_accum_7dw.sot = {{(P_SHIFT_NW-12-P_NW){1'b0}}, sot[P_NW - 1 : (P_NW-5-7)], {5{1'b0}}, sot[(P_NW-5-7-1) : 0], prev_shift_data.sot[(P_NW+6) : P_NW]};
        load_accum_7dw.eot = {{(P_SHIFT_NW-12-P_NW){1'b0}}, eot[P_NW - 1 : (P_NW-5-7)], {5{1'b0}}, eot[(P_NW-5-7-1) : 0], prev_shift_data.eot[(P_NW+6) : P_NW]};
        load_accum_7dw.flit_marker = {{(P_SHIFT_NW-12-P_NW){4'h0}}, flit_marker[P_NW - 1 : (P_NW-5-7)], {5{4'h0}}, flit_marker[(P_NW-5-7-1) : 0], prev_shift_data.flit_marker[(P_NW+6) : P_NW]};
      end
      else begin
        load_accum_7dw.data_valid = {{(P_SHIFT_NW-(2*P_NW)){1'b0}}, {P_NW{dv}}, {P_NW{prev_dv}}};
        load_accum_7dw.data = {{(P_SHIFT_NW-7-P_NW){P_NOP}}, data, prev_shift_data.data[(P_NW+6) : P_NW]};
        load_accum_7dw.sot = {{(P_SHIFT_NW-7-P_NW){1'b0}}, sot, prev_shift_data.sot[(P_NW+6) : P_NW]};
        load_accum_7dw.eot = {{(P_SHIFT_NW-7-P_NW){1'b0}}, eot, prev_shift_data.eot[(P_NW+6) : P_NW]};
        load_accum_7dw.flit_marker = {{(P_SHIFT_NW-7-P_NW){4'h0}}, flit_marker, prev_shift_data.flit_marker[(P_NW+6) : P_NW]};
      end
    end else begin
        load_accum_7dw.data_valid = {{(P_SHIFT_NW-P_NW){1'b0}}, {P_NW{prev_dv}}};
        load_accum_7dw.data = {{(P_SHIFT_NW-7){P_NOP}}, prev_shift_data.data[(P_NW+6) : P_NW]};
        load_accum_7dw.sot = {{(P_SHIFT_NW-7){1'b0}}, prev_shift_data.sot[(P_NW+6) : P_NW]};
        load_accum_7dw.eot = {{(P_SHIFT_NW-7){1'b0}}, prev_shift_data.eot[(P_NW+6) : P_NW]};
        load_accum_7dw.flit_marker = {{(P_SHIFT_NW-7){4'h0}}, prev_shift_data.flit_marker[(P_NW+6) : P_NW]};
    end
    return load_accum_7dw;
  endfunction

  // Function Name  : load_accum_8dw 
  // Description    : Load new data and merge with 4DW accumulated in the previous cycle
  function automatic flit_shift_struct load_accum_8dw (
    input flit_shift_struct             prev_shift_data,
    input                               dv,
    input [P_NW-1:0] [31:0]             data,
    input [P_NW-1:0]                    sot,
    input [P_NW-1:0]                    eot,
    input flit_marker_struct [P_NW-1:0] flit_marker,
    input logic [P_DW_CNT_WD - 1 : 0]   flit_dw_cnt
  );
    logic dv_overflow;
    logic prev_dv;
    load_accum_8dw = '0;
    dv_overflow = '0;
    prev_dv = |prev_shift_data.data_valid[(P_NW+7) : P_NW];
    if(dv) begin
      // If the data path width is 512-bit or greater the overflow is accounted for in the last flit cycle
      if(flit_dw_cnt == P_DW_LAST - 1) begin
        dv_overflow = (!(|eot[(P_NW-1) : (P_NW-5-8)]) && (|eot) && (sot<=eot)) ? '0 : dv;
        load_accum_8dw.data_valid = {{(P_SHIFT_NW-(2*P_NW)){1'b0}}, {P_NW{dv_overflow}}, {P_NW{dv}}};
        load_accum_8dw.data = {{(P_SHIFT_NW-13-P_NW){P_NOP}}, data[P_NW - 1 : (P_NW-5-8)], {5{P_NOP}}, data[(P_NW-5-8-1) : 0], prev_shift_data.data[(P_NW+7) : P_NW]};
        load_accum_8dw.sot = {{(P_SHIFT_NW-13-P_NW){1'b0}}, sot[P_NW - 1 : (P_NW-5-8)], {5{1'b0}}, sot[(P_NW-5-8-1) : 0], prev_shift_data.sot[(P_NW+7) : P_NW]};
        load_accum_8dw.eot = {{(P_SHIFT_NW-13-P_NW){1'b0}}, eot[P_NW - 1 : (P_NW-5-8)], {5{1'b0}}, eot[(P_NW-5-8-1) : 0], prev_shift_data.eot[(P_NW+7) : P_NW]};
        load_accum_8dw.flit_marker = {{(P_SHIFT_NW-13-P_NW){4'h0}}, flit_marker[P_NW - 1 : (P_NW-5-8)], {5{4'h0}}, flit_marker[(P_NW-5-8-1) : 0], prev_shift_data.flit_marker[(P_NW+7) : P_NW]};
      end
      else begin
        load_accum_8dw.data_valid = {{(P_SHIFT_NW-(2*P_NW)){1'b0}}, {P_NW{dv}}, {P_NW{prev_dv}}};
        load_accum_8dw.data = {{(P_SHIFT_NW-8-P_NW){P_NOP}}, data, prev_shift_data.data[(P_NW+7) : P_NW]};
        load_accum_8dw.sot = {{(P_SHIFT_NW-8-P_NW){1'b0}}, sot, prev_shift_data.sot[(P_NW+7) : P_NW]};
        load_accum_8dw.eot = {{(P_SHIFT_NW-8-P_NW){1'b0}}, eot, prev_shift_data.eot[(P_NW+7) : P_NW]};
        load_accum_8dw.flit_marker = {{(P_SHIFT_NW-8-P_NW){4'h0}}, flit_marker, prev_shift_data.flit_marker[(P_NW+7) : P_NW]};
      end
    end else begin
        load_accum_8dw.data_valid = {{(P_SHIFT_NW-P_NW){1'b0}}, {P_NW{prev_dv}}};
        load_accum_8dw.data = {{(P_SHIFT_NW-8){P_NOP}}, prev_shift_data.data[(P_NW+7) : P_NW]};
        load_accum_8dw.sot = {{(P_SHIFT_NW-8){1'b0}}, prev_shift_data.sot[(P_NW+7) : P_NW]};
        load_accum_8dw.eot = {{(P_SHIFT_NW-8){1'b0}}, prev_shift_data.eot[(P_NW+7) : P_NW]};
        load_accum_8dw.flit_marker = {{(P_SHIFT_NW-8){4'h0}}, prev_shift_data.flit_marker[(P_NW+7) : P_NW]};
    end
    return load_accum_8dw;
  endfunction

  // Function Name  : load_accum_9dw
  // Description    : Load new data and merge with 4DW accumulated in the previous cycle
  function automatic flit_shift_struct load_accum_9dw (
    input flit_shift_struct             prev_shift_data,
    input                               dv,
    input [P_NW-1:0] [31:0]             data,
    input [P_NW-1:0]                    sot,
    input [P_NW-1:0]                    eot,
    input flit_marker_struct [P_NW-1:0] flit_marker,
    input logic [P_DW_CNT_WD - 1 : 0]   flit_dw_cnt
  );
    logic dv_overflow;
    logic prev_dv;
    load_accum_9dw = '0;
    dv_overflow = '0;
    prev_dv = |prev_shift_data.data_valid[(P_NW+8) : P_NW];
    dv_overflow = (!(|eot[(P_NW-1) : (P_NW-5-9)]) && (|eot) && (sot<=eot)) ? '0 : dv;
    if(dv) begin
      // If the data path width is 512-bit or greater the overflow is accounted for in the last flit cycle
      if(flit_dw_cnt == P_DW_LAST - 1) begin
        load_accum_9dw.data_valid = {{(P_SHIFT_NW-(P_NW+5+9)){1'b0}}, {P_NW{dv_overflow}}, {(5+9){prev_dv}}};
        load_accum_9dw.data = {{(P_SHIFT_NW-14-P_NW){P_NOP}}, data[P_NW - 1 : (P_NW-5-9)], {5{P_NOP}}, data[(P_NW-5-9-1) : 0], prev_shift_data.data[(P_NW+8) : P_NW]};
        load_accum_9dw.sot = {{(P_SHIFT_NW-14-P_NW){1'b0}}, sot[P_NW - 1 : (P_NW-5-9)], {5{1'b0}}, sot[(P_NW-5-9-1) : 0], prev_shift_data.sot[(P_NW+8) : P_NW]};
        load_accum_9dw.eot = {{(P_SHIFT_NW-14-P_NW){1'b0}}, eot[P_NW - 1 : (P_NW-5-9)], {5{1'b0}}, eot[(P_NW-5-9-1) : 0], prev_shift_data.eot[(P_NW+8) : P_NW]};
        load_accum_9dw.flit_marker = {{(P_SHIFT_NW-14-P_NW){4'h0}}, flit_marker[P_NW - 1 : (P_NW-5-9)], {5{4'h0}}, flit_marker[(P_NW-5-9-1) : 0], prev_shift_data.flit_marker[(P_NW+8) : P_NW]};
      end
      else begin
        load_accum_9dw.data_valid = {{(P_SHIFT_NW-(2*P_NW)){1'b0}}, {P_NW{dv}}, {P_NW{prev_dv}}};
        load_accum_9dw.data = {{(P_SHIFT_NW-9-P_NW){P_NOP}}, data, prev_shift_data.data[(P_NW+8) : P_NW]};
        load_accum_9dw.sot = {{(P_SHIFT_NW-9-P_NW){1'b0}}, sot, prev_shift_data.sot[(P_NW+8) : P_NW]};
        load_accum_9dw.eot = {{(P_SHIFT_NW-9-P_NW){1'b0}}, eot, prev_shift_data.eot[(P_NW+8) : P_NW]};
        load_accum_9dw.flit_marker = {{(P_SHIFT_NW-9-P_NW){4'h0}}, flit_marker, prev_shift_data.flit_marker[(P_NW+8) : P_NW]};
      end
    end else begin
      load_accum_9dw.data_valid = {{(P_SHIFT_NW-P_NW){1'b0}}, {P_NW{prev_dv}}};
      load_accum_9dw.data = {{(P_SHIFT_NW-9){P_NOP}}, prev_shift_data.data[(P_NW+8) : P_NW]};
      load_accum_9dw.sot = {{(P_SHIFT_NW-9){1'b0}}, prev_shift_data.sot[(P_NW+8) : P_NW]};
      load_accum_9dw.eot = {{(P_SHIFT_NW-9){1'b0}}, prev_shift_data.eot[(P_NW+8) : P_NW]};
      load_accum_9dw.flit_marker = {{(P_SHIFT_NW-9){4'h0}}, prev_shift_data.flit_marker[(P_NW+8) : P_NW]};
    end
    return load_accum_9dw;
  endfunction

  // Function Name  : load_accum_10dw
  // Description    : Load new data and merge with 4DW accumulated in the previous cycle
  function automatic flit_shift_struct load_accum_10dw (
    input flit_shift_struct             prev_shift_data,
    input                               dv,
    input [P_NW-1:0] [31:0]             data,
    input [P_NW-1:0]                    sot,
    input [P_NW-1:0]                    eot,
    input flit_marker_struct [P_NW-1:0] flit_marker,
    input logic [P_DW_CNT_WD - 1 : 0]   flit_dw_cnt
  );
    logic dv_overflow;
    logic prev_dv;
    load_accum_10dw = '0;
    dv_overflow = '0;
    prev_dv = |prev_shift_data.data_valid[(P_NW+9) : P_NW];
    dv_overflow = (!(|eot[(P_NW-1) : (P_NW-5-10)]) && (|eot) && (sot<=eot)) ? '0 : dv;
    if(dv) begin
      // If the data path width is 512-bit or greater the overflow is accounted for in the last flit cycle
      if(flit_dw_cnt == P_DW_LAST - 1) begin
        load_accum_10dw.data_valid = {{(P_SHIFT_NW-(P_NW+5+10)){1'b0}}, {P_NW{dv_overflow}}, {(5+10){prev_dv}}};
        load_accum_10dw.data = {{(P_SHIFT_NW-15-P_NW){P_NOP}}, data[P_NW - 1 : (P_NW-5-10)], {5{P_NOP}}, data[(P_NW-5-10-1) : 0], prev_shift_data.data[(P_NW+9) : P_NW]};
        load_accum_10dw.sot = {{(P_SHIFT_NW-15-P_NW){1'b0}}, sot[P_NW - 1 : (P_NW-5-10)], {5{1'b0}}, sot[(P_NW-5-10-1) : 0], prev_shift_data.sot[(P_NW+9) : P_NW]};
        load_accum_10dw.eot = {{(P_SHIFT_NW-15-P_NW){1'b0}}, eot[P_NW - 1 : (P_NW-5-10)], {5{1'b0}}, eot[(P_NW-5-10-1) : 0], prev_shift_data.eot[(P_NW+9) : P_NW]};
        load_accum_10dw.flit_marker = {{(P_SHIFT_NW-15-P_NW){4'h0}}, flit_marker[P_NW - 1 : (P_NW-5-10)], {5{4'h0}}, flit_marker[(P_NW-5-10-1) : 0], prev_shift_data.flit_marker[(P_NW+9) : P_NW]};
      end
      else begin
        load_accum_10dw.data_valid = {{(P_SHIFT_NW-(2*P_NW)){1'b0}}, {P_NW{dv}}, {P_NW{prev_dv}}};
        load_accum_10dw.data = {{(P_SHIFT_NW-10-P_NW){P_NOP}}, data, prev_shift_data.data[(P_NW+9) : P_NW]};
        load_accum_10dw.sot = {{(P_SHIFT_NW-10-P_NW){1'b0}}, sot, prev_shift_data.sot[(P_NW+9) : P_NW]};
        load_accum_10dw.eot = {{(P_SHIFT_NW-10-P_NW){1'b0}}, eot, prev_shift_data.eot[(P_NW+9) : P_NW]};
        load_accum_10dw.flit_marker = {{(P_SHIFT_NW-10-P_NW){4'h0}}, flit_marker, prev_shift_data.flit_marker[(P_NW+9) : P_NW]};
      end
    end else begin
      load_accum_10dw.data_valid = {{(P_SHIFT_NW-P_NW){1'b0}}, {P_NW{prev_dv}}};
      load_accum_10dw.data = {{(P_SHIFT_NW-10){P_NOP}}, prev_shift_data.data[(P_NW+9) : P_NW]};
      load_accum_10dw.sot = {{(P_SHIFT_NW-10){1'b0}}, prev_shift_data.sot[(P_NW+9) : P_NW]};
      load_accum_10dw.eot = {{(P_SHIFT_NW-10){1'b0}}, prev_shift_data.eot[(P_NW+9) : P_NW]};
      load_accum_10dw.flit_marker = {{(P_SHIFT_NW-10){4'h0}}, prev_shift_data.flit_marker[(P_NW+9) : P_NW]};
    end
    return load_accum_10dw;
  endfunction

  // Function Name  : load_accum_11dw
  // Description    : Load new data and merge with 4DW accumulated in the previous cycle
  function automatic flit_shift_struct load_accum_11dw (
    input flit_shift_struct             prev_shift_data,
    input                               dv,
    input [P_NW-1:0] [31:0]             data,
    input [P_NW-1:0]                    sot,
    input [P_NW-1:0]                    eot,
    input flit_marker_struct [P_NW-1:0] flit_marker,
    input logic [P_DW_CNT_WD - 1 : 0]   flit_dw_cnt
  );
    logic dv_overflow;
    logic prev_dv;
    load_accum_11dw = '0;
    dv_overflow = '0;
    prev_dv = |prev_shift_data.data_valid[(P_NW+10) : P_NW];
    if(dv) begin
      // If the data path width is 512-bit accomodate 11-DW in the last flit cycle
      if(flit_dw_cnt == P_DW_LAST - 1) begin
        dv_overflow = (!(|eot[(P_NW-1) : (P_NW-5-11)]) && (|eot) && (sot<=eot)) ? '0 : dv;
        load_accum_11dw.data_valid = {{(P_SHIFT_NW-(P_NW+5+11)){1'b0}}, {P_NW{dv_overflow}}, {(5+11){prev_dv}}};
        load_accum_11dw.data = {{(P_SHIFT_NW-16-P_NW){P_NOP}}, data, {5{P_NOP}}, prev_shift_data.data[(P_NW+10) : P_NW]};
        load_accum_11dw.sot = {{(P_SHIFT_NW-16-P_NW){1'b0}}, sot, {5{1'b0}}, prev_shift_data.sot[(P_NW+10) : P_NW]};
        load_accum_11dw.eot = {{(P_SHIFT_NW-16-P_NW){1'b0}}, eot, {5{1'b0}}, prev_shift_data.eot[(P_NW+10) : P_NW]};
        load_accum_11dw.flit_marker = {{(P_SHIFT_NW-16-P_NW){4'h0}}, flit_marker, {5{4'h0}}, prev_shift_data.flit_marker[(P_NW+10) : P_NW]};
      end
      else begin
        load_accum_11dw.data_valid = {{(P_SHIFT_NW-(2*P_NW)){1'b0}}, {P_NW{dv}}, {P_NW{prev_dv}}};
        load_accum_11dw.data = {{(P_SHIFT_NW-11-P_NW){P_NOP}}, data, prev_shift_data.data[(P_NW+10) : P_NW]};
        load_accum_11dw.sot = {{(P_SHIFT_NW-11-P_NW){1'b0}}, sot, prev_shift_data.sot[(P_NW+10) : P_NW]};
        load_accum_11dw.eot = {{(P_SHIFT_NW-11-P_NW){1'b0}}, eot, prev_shift_data.eot[(P_NW+10) : P_NW]};
        load_accum_11dw.flit_marker = {{(P_SHIFT_NW-11-P_NW){4'h0}}, flit_marker, prev_shift_data.flit_marker[(P_NW+10) : P_NW]};
      end
    end else begin
      load_accum_11dw.data_valid = {{(P_SHIFT_NW-P_NW){1'b0}}, {P_NW{prev_dv}}};
      load_accum_11dw.data = {{(P_SHIFT_NW-11){P_NOP}}, prev_shift_data.data[(P_NW+10) : P_NW]};
      load_accum_11dw.sot = {{(P_SHIFT_NW-11){1'b0}}, prev_shift_data.sot[(P_NW+10) : P_NW]};
      load_accum_11dw.eot = {{(P_SHIFT_NW-11){1'b0}}, prev_shift_data.eot[(P_NW+10) : P_NW]};
      load_accum_11dw.flit_marker = {{(P_SHIFT_NW-11){4'h0}}, prev_shift_data.flit_marker[(P_NW+10) : P_NW]};
    end
    return load_accum_11dw;
  endfunction

  // Function Name  : load_accum_12dw
  // Description    : Load new data and merge with 4DW accumulated in the previous cycle
  function automatic flit_shift_struct load_accum_12dw (
    input flit_shift_struct             prev_shift_data,
    input                               dv,
    input [P_NW-1:0] [31:0]             data,
    input [P_NW-1:0]                    sot,
    input [P_NW-1:0]                    eot,
    input flit_marker_struct [P_NW-1:0] flit_marker,
    input logic [P_DW_CNT_WD - 1 : 0]   flit_dw_cnt
  );
    logic prev_dv;
    load_accum_12dw = '0;
    prev_dv = |prev_shift_data.data_valid[(P_NW+11) : P_NW];
    if(dv) begin
      // If the data path width is 512-bit or greater the overflow is accounted for in the last flit cycle
      if(flit_dw_cnt == P_DW_LAST - 1) begin
        load_accum_12dw.data_valid = {{(P_SHIFT_NW-(P_NW+12+5)){1'b0}}, {P_NW{dv}}, {(12+5){prev_dv}}};
        load_accum_12dw.data = {{(P_SHIFT_NW-17-P_NW){P_NOP}}, data, prev_shift_data.data[(P_NW+11) : (P_NW+11)], {5{P_NOP}}, prev_shift_data.data[(P_NW+10) : P_NW]};
        load_accum_12dw.sot = {{(P_SHIFT_NW-17-P_NW){1'b0}}, sot, prev_shift_data.sot[(P_NW+11) : (P_NW+11)], {5{1'b0}}, prev_shift_data.sot[(P_NW+10) : P_NW]};
        load_accum_12dw.eot = {{(P_SHIFT_NW-17-P_NW){1'b0}}, eot, prev_shift_data.eot[(P_NW+11) : (P_NW+11)], {5{1'b0}}, prev_shift_data.eot[(P_NW+10) : P_NW]};
        load_accum_12dw.flit_marker = {{(P_SHIFT_NW-17-P_NW){4'h0}}, flit_marker, prev_shift_data.flit_marker[(P_NW+11) : (P_NW+11)], {5{4'h0}}, prev_shift_data.flit_marker[(P_NW+10) : P_NW]};
      end
      else begin
        load_accum_12dw.data_valid = {{(P_SHIFT_NW-(2*P_NW)){1'b0}}, {P_NW{dv}}, {P_NW{prev_dv}}};
        load_accum_12dw.data = {{(P_SHIFT_NW-12-P_NW){P_NOP}}, data, prev_shift_data.data[(P_NW+11) : P_NW]};
        load_accum_12dw.sot = {{(P_SHIFT_NW-12-P_NW){1'b0}}, sot, prev_shift_data.sot[(P_NW+11) : P_NW]};
        load_accum_12dw.eot = {{(P_SHIFT_NW-12-P_NW){1'b0}}, eot, prev_shift_data.eot[(P_NW+11) : P_NW]};
        load_accum_12dw.flit_marker = {{(P_SHIFT_NW-12-P_NW){4'h0}}, flit_marker, prev_shift_data.flit_marker[(P_NW+11) : P_NW]};
      end
    end else begin
      if(flit_dw_cnt == P_DW_LAST - 1) begin
        load_accum_12dw.data_valid = {{(P_SHIFT_NW-(2*P_NW)){1'b0}}, {(2*P_NW){prev_dv}}};
        load_accum_12dw.data = {{(P_SHIFT_NW-17){P_NOP}}, prev_shift_data.data[(P_NW+11) : (P_NW+11)], {5{P_NOP}}, prev_shift_data.data[(P_NW+10) : P_NW]};
        load_accum_12dw.sot = {{(P_SHIFT_NW-17){1'b0}}, prev_shift_data.sot[(P_NW+11) : (P_NW+11)], {5{1'b0}}, prev_shift_data.sot[(P_NW+10) : P_NW]};
        load_accum_12dw.eot = {{(P_SHIFT_NW-17){1'b0}}, prev_shift_data.eot[(P_NW+11) : (P_NW+11)], {5{1'b0}}, prev_shift_data.eot[(P_NW+10) : P_NW]};
        load_accum_12dw.flit_marker = {{(P_SHIFT_NW-17){4'h0}}, prev_shift_data.flit_marker[(P_NW+11) : (P_NW+11)], {5{4'h0}}, prev_shift_data.flit_marker[(P_NW+10) : P_NW]};
      end else begin
        load_accum_12dw.data_valid = {{(P_SHIFT_NW-P_NW){1'b0}}, {P_NW{prev_dv}}};
        load_accum_12dw.data = {{(P_SHIFT_NW-12){P_NOP}}, prev_shift_data.data[(P_NW+11) : P_NW]};
        load_accum_12dw.sot = {{(P_SHIFT_NW-12){1'b0}}, prev_shift_data.sot[(P_NW+11) : P_NW]};
        load_accum_12dw.eot = {{(P_SHIFT_NW-12){1'b0}}, prev_shift_data.eot[(P_NW+11) : P_NW]};
        load_accum_12dw.flit_marker = {{(P_SHIFT_NW-12){4'h0}}, prev_shift_data.flit_marker[(P_NW+11) : P_NW]};
      end
    end
    return load_accum_12dw;
  endfunction

  // Function Name  : load_accum_13dw
  // Description    : Load new data and merge with 4DW accumulated in the previous cycle
  function automatic flit_shift_struct load_accum_13dw (
    input flit_shift_struct             prev_shift_data,
    input                               dv,
    input [P_NW-1:0] [31:0]             data,
    input [P_NW-1:0]                    sot,
    input [P_NW-1:0]                    eot,
    input flit_marker_struct [P_NW-1:0] flit_marker,
    input logic [P_DW_CNT_WD - 1 : 0]   flit_dw_cnt
  );
    logic prev_dv;
    load_accum_13dw = '0;
    prev_dv = |prev_shift_data.data_valid[(P_NW+12) : P_NW];
    if(dv) begin
      // If the data path width is 512-bit or greater the overflow is accounted for in the last flit cycle
      if(flit_dw_cnt == P_DW_LAST - 1) begin
        load_accum_13dw.data_valid = {{(P_SHIFT_NW-(P_NW+13+5)){1'b0}}, {P_NW{dv}}, {(13+5){prev_dv}}};
        load_accum_13dw.data = {{(P_SHIFT_NW-18-P_NW){P_NOP}}, data, prev_shift_data.data[(P_NW+12) : (P_NW+11)], {5{P_NOP}}, prev_shift_data.data[(P_NW+10) : P_NW]};
        load_accum_13dw.sot = {{(P_SHIFT_NW-18-P_NW){1'b0}}, sot, prev_shift_data.sot[(P_NW+12) : (P_NW+11)], {5{1'b0}}, prev_shift_data.sot[(P_NW+10) : P_NW]};
        load_accum_13dw.eot = {{(P_SHIFT_NW-18-P_NW){1'b0}}, eot, prev_shift_data.eot[(P_NW+12) : (P_NW+11)], {5{1'b0}}, prev_shift_data.eot[(P_NW+10) : P_NW]};
        load_accum_13dw.flit_marker = {{(P_SHIFT_NW-18-P_NW){4'h0}}, flit_marker, prev_shift_data.flit_marker[(P_NW+12) : (P_NW+11)], {5{4'h0}}, prev_shift_data.flit_marker[(P_NW+10) : P_NW]};
      end
      else begin
        load_accum_13dw.data_valid = {{(P_SHIFT_NW-(2*P_NW)){1'b0}}, {P_NW{dv}}, {P_NW{prev_dv}}};
        load_accum_13dw.data = {{(P_SHIFT_NW-13-P_NW){P_NOP}}, data, prev_shift_data.data[(P_NW+12) : P_NW]};
        load_accum_13dw.sot = {{(P_SHIFT_NW-13-P_NW){1'b0}}, sot, prev_shift_data.sot[(P_NW+12) : P_NW]};
        load_accum_13dw.eot = {{(P_SHIFT_NW-13-P_NW){1'b0}}, eot, prev_shift_data.eot[(P_NW+12) : P_NW]};
        load_accum_13dw.flit_marker = {{(P_SHIFT_NW-13-P_NW){4'h0}}, flit_marker, prev_shift_data.flit_marker[(P_NW+12) : P_NW]};
      end
    end else begin
      if(flit_dw_cnt == P_DW_LAST - 1) begin
        load_accum_13dw.data_valid = {{(P_SHIFT_NW-(2*P_NW)){1'b0}}, {(2*P_NW){prev_dv}}};
        load_accum_13dw.data = {{(P_SHIFT_NW-18){P_NOP}}, prev_shift_data.data[(P_NW+12) : (P_NW+11)], {5{P_NOP}}, prev_shift_data.data[(P_NW+10) : P_NW]};
        load_accum_13dw.sot = {{(P_SHIFT_NW-18){1'b0}}, prev_shift_data.sot[(P_NW+12) : (P_NW+11)], {5{1'b0}}, prev_shift_data.sot[(P_NW+10) : P_NW]};
        load_accum_13dw.eot = {{(P_SHIFT_NW-18){1'b0}}, prev_shift_data.eot[(P_NW+12) : (P_NW+11)], {5{1'b0}}, prev_shift_data.eot[(P_NW+10) : P_NW]};
        load_accum_13dw.flit_marker = {{(P_SHIFT_NW-18){4'h0}}, prev_shift_data.flit_marker[(P_NW+12) : (P_NW+11)], {5{4'h0}}, prev_shift_data.flit_marker[(P_NW+10) : P_NW]};
      end else begin
        load_accum_13dw.data_valid = {{(P_SHIFT_NW-P_NW){1'b0}}, {P_NW{prev_dv}}};
        load_accum_13dw.data = {{(P_SHIFT_NW-13){P_NOP}}, prev_shift_data.data[(P_NW+12) : P_NW]};
        load_accum_13dw.sot = {{(P_SHIFT_NW-13){1'b0}}, prev_shift_data.sot[(P_NW+12) : P_NW]};
        load_accum_13dw.eot = {{(P_SHIFT_NW-13){1'b0}}, prev_shift_data.eot[(P_NW+12) : P_NW]};
        load_accum_13dw.flit_marker = {{(P_SHIFT_NW-13){4'h0}}, prev_shift_data.flit_marker[(P_NW+12) : P_NW]};
      end
    end
    return load_accum_13dw;
  endfunction

  // Function Name  : load_accum_14dw
  // Description    : Load new data and merge with 4DW accumulated in the previous cycle
  function automatic flit_shift_struct load_accum_14dw (
    input flit_shift_struct             prev_shift_data,
    input                               dv,
    input [P_NW-1:0] [31:0]             data,
    input [P_NW-1:0]                    sot,
    input [P_NW-1:0]                    eot,
    input flit_marker_struct [P_NW-1:0] flit_marker,
    input logic [P_DW_CNT_WD - 1 : 0]   flit_dw_cnt
  );
    logic prev_dv;
    load_accum_14dw = '0;
    prev_dv = |prev_shift_data.data_valid[(P_NW+13) : P_NW];
    if(dv) begin
      // If the data path width is 512-bit or greater the overflow is accounted for in the last flit cycle
      if(flit_dw_cnt == P_DW_LAST - 1) begin
        load_accum_14dw.data_valid = {{(P_SHIFT_NW-(P_NW+14+5)){1'b0}}, {P_NW{dv}}, {(14+5){prev_dv}}};
        load_accum_14dw.data = {{(P_SHIFT_NW-19-P_NW){P_NOP}}, data, prev_shift_data.data[(P_NW+13) : (P_NW+11)], {5{P_NOP}}, prev_shift_data.data[(P_NW+10) : P_NW]};
        load_accum_14dw.sot = {{(P_SHIFT_NW-19-P_NW){1'b0}}, sot, prev_shift_data.sot[(P_NW+13) : (P_NW+11)], {5{1'b0}}, prev_shift_data.sot[(P_NW+10) : P_NW]};
        load_accum_14dw.eot = {{(P_SHIFT_NW-19-P_NW){1'b0}}, eot, prev_shift_data.eot[(P_NW+13) : (P_NW+11)], {5{1'b0}}, prev_shift_data.eot[(P_NW+10) : P_NW]};
        load_accum_14dw.flit_marker = {{(P_SHIFT_NW-19-P_NW){4'h0}}, flit_marker, prev_shift_data.flit_marker[(P_NW+13) : (P_NW+11)], {5{4'h0}}, prev_shift_data.flit_marker[(P_NW+10) : P_NW]};
      end
      else begin
        load_accum_14dw.data_valid = {{(P_SHIFT_NW-(2*P_NW)){1'b0}}, {P_NW{dv}}, {P_NW{prev_dv}}};
        load_accum_14dw.data = {{(P_SHIFT_NW-14-P_NW){P_NOP}}, data, prev_shift_data.data[(P_NW+13) : P_NW]};
        load_accum_14dw.sot = {{(P_SHIFT_NW-14-P_NW){1'b0}}, sot, prev_shift_data.sot[(P_NW+13) : P_NW]};
        load_accum_14dw.eot = {{(P_SHIFT_NW-14-P_NW){1'b0}}, eot, prev_shift_data.eot[(P_NW+13) : P_NW]};
        load_accum_14dw.flit_marker = {{(P_SHIFT_NW-14-P_NW){4'h0}}, flit_marker, prev_shift_data.flit_marker[(P_NW+13) : P_NW]};
      end
    end else begin
      if(flit_dw_cnt == P_DW_LAST - 1) begin
        load_accum_14dw.data_valid = {{(P_SHIFT_NW-(2*P_NW)){1'b0}}, {(2*P_NW){prev_dv}}};
        load_accum_14dw.data = {{(P_SHIFT_NW-19){P_NOP}}, prev_shift_data.data[(P_NW+13) : (P_NW+11)], {5{P_NOP}}, prev_shift_data.data[(P_NW+10) : P_NW]};
        load_accum_14dw.sot = {{(P_SHIFT_NW-19){1'b0}}, prev_shift_data.sot[(P_NW+13) : (P_NW+11)], {5{1'b0}}, prev_shift_data.sot[(P_NW+10) : P_NW]};
        load_accum_14dw.eot = {{(P_SHIFT_NW-19){1'b0}}, prev_shift_data.eot[(P_NW+13) : (P_NW+11)], {5{1'b0}}, prev_shift_data.eot[(P_NW+10) : P_NW]};
        load_accum_14dw.flit_marker = {{(P_SHIFT_NW-19){4'h0}}, prev_shift_data.flit_marker[(P_NW+13) : (P_NW+11)], {5{4'h0}}, prev_shift_data.flit_marker[(P_NW+10) : P_NW]};
      end else begin
        load_accum_14dw.data_valid = {{(P_SHIFT_NW-P_NW){1'b0}}, {P_NW{prev_dv}}};
        load_accum_14dw.data = {{(P_SHIFT_NW-14){P_NOP}}, prev_shift_data.data[(P_NW+13) : P_NW]};
        load_accum_14dw.sot = {{(P_SHIFT_NW-14){1'b0}}, prev_shift_data.sot[(P_NW+13) : P_NW]};
        load_accum_14dw.eot = {{(P_SHIFT_NW-14){1'b0}}, prev_shift_data.eot[(P_NW+13) : P_NW]};
        load_accum_14dw.flit_marker = {{(P_SHIFT_NW-14){4'h0}}, prev_shift_data.flit_marker[(P_NW+13) : P_NW]};
      end
    end
    return load_accum_14dw;
  endfunction

  // Function Name  : load_accum_15dw
  // Description    : Load new data and merge with 4DW accumulated in the previous cycle
  function automatic flit_shift_struct load_accum_15dw (
    input flit_shift_struct             prev_shift_data,
    input                               dv,
    input [P_NW-1:0] [31:0]             data,
    input [P_NW-1:0]                    sot,
    input [P_NW-1:0]                    eot,
    input flit_marker_struct [P_NW-1:0] flit_marker,
    input logic [P_DW_CNT_WD - 1 : 0]   flit_dw_cnt
  );
    logic prev_dv;
    load_accum_15dw = '0;
    prev_dv = |prev_shift_data.data_valid[(P_NW+14) : P_NW];
    if(dv) begin
      // If the data path width is 512-bit or greater the overflow is accounted for in the last flit cycle
      if(flit_dw_cnt == P_DW_LAST - 1) begin
        load_accum_15dw.data_valid = {{(P_SHIFT_NW-(P_NW+15+5)){1'b0}}, {P_NW{dv}}, {(15+5){prev_dv}}};
        load_accum_15dw.data = {{(P_SHIFT_NW-20-P_NW){P_NOP}}, data, prev_shift_data.data[(P_NW+14) : (P_NW+11)], {5{P_NOP}}, prev_shift_data.data[(P_NW+10) : P_NW]};
        load_accum_15dw.sot = {{(P_SHIFT_NW-20-P_NW){1'b0}}, sot, prev_shift_data.sot[(P_NW+14) : (P_NW+11)], {5{1'b0}}, prev_shift_data.sot[(P_NW+10) : P_NW]};
        load_accum_15dw.eot = {{(P_SHIFT_NW-20-P_NW){1'b0}}, eot, prev_shift_data.eot[(P_NW+14) : (P_NW+11)], {5{1'b0}}, prev_shift_data.eot[(P_NW+10) : P_NW]};
        load_accum_15dw.flit_marker = {{(P_SHIFT_NW-20-P_NW){4'h0}}, flit_marker, prev_shift_data.flit_marker[(P_NW+14) : (P_NW+11)], {5{4'h0}}, prev_shift_data.flit_marker[(P_NW+10) : P_NW]};
      end
      else begin
        load_accum_15dw.data_valid = {{(P_SHIFT_NW-(2*P_NW)){1'b0}}, {P_NW{dv}}, {P_NW{prev_dv}}};
        load_accum_15dw.data = {{(P_SHIFT_NW-15-P_NW){P_NOP}}, data, prev_shift_data.data[(P_NW+14) : P_NW]};
        load_accum_15dw.sot = {{(P_SHIFT_NW-15-P_NW){1'b0}}, sot, prev_shift_data.sot[(P_NW+14) : P_NW]};
        load_accum_15dw.eot = {{(P_SHIFT_NW-15-P_NW){1'b0}}, eot, prev_shift_data.eot[(P_NW+14) : P_NW]};
        load_accum_15dw.flit_marker = {{(P_SHIFT_NW-15-P_NW){4'h0}}, flit_marker, prev_shift_data.flit_marker[(P_NW+14) : P_NW]};
      end
    end else begin
      if(flit_dw_cnt == P_DW_LAST - 1) begin
        load_accum_15dw.data_valid = {{(P_SHIFT_NW-(2*P_NW)){1'b0}}, {(2*P_NW){prev_dv}}};
        load_accum_15dw.data = {{(P_SHIFT_NW-20){P_NOP}}, prev_shift_data.data[(P_NW+14) : (P_NW+11)], {5{P_NOP}}, prev_shift_data.data[(P_NW+10) : P_NW]};
        load_accum_15dw.sot = {{(P_SHIFT_NW-20){1'b0}}, prev_shift_data.sot[(P_NW+14) : (P_NW+11)], {5{1'b0}}, prev_shift_data.sot[(P_NW+10) : P_NW]};
        load_accum_15dw.eot = {{(P_SHIFT_NW-20){1'b0}}, prev_shift_data.eot[(P_NW+14) : (P_NW+11)], {5{1'b0}}, prev_shift_data.eot[(P_NW+10) : P_NW]};
        load_accum_15dw.flit_marker = {{(P_SHIFT_NW-20){4'h0}}, prev_shift_data.flit_marker[(P_NW+14) : (P_NW+11)], {5{4'h0}}, prev_shift_data.flit_marker[(P_NW+10) : P_NW]};
      end else begin
        load_accum_15dw.data_valid = {{(P_SHIFT_NW-P_NW){1'b0}}, {P_NW{prev_dv}}};
        load_accum_15dw.data = {{(P_SHIFT_NW-15){P_NOP}}, prev_shift_data.data[(P_NW+14) : P_NW]};
        load_accum_15dw.sot = {{(P_SHIFT_NW-15){1'b0}}, prev_shift_data.sot[(P_NW+14) : P_NW]};
        load_accum_15dw.eot = {{(P_SHIFT_NW-15){1'b0}}, prev_shift_data.eot[(P_NW+14) : P_NW]};
        load_accum_15dw.flit_marker = {{(P_SHIFT_NW-15){4'h0}}, prev_shift_data.flit_marker[(P_NW+14) : P_NW]};
      end
    end
    return load_accum_15dw;
  endfunction

  // Function Name  : load_accum_16dw
  // Description    : Load new data and merge with 4DW accumulated in the previous cycle
  function automatic flit_shift_struct load_accum_16dw (
    input flit_shift_struct             prev_shift_data,
    input                               dv,
    input [P_NW-1:0] [31:0]             data,
    input [P_NW-1:0]                    sot,
    input [P_NW-1:0]                    eot,
    input flit_marker_struct [P_NW-1:0] flit_marker,
    input logic [P_DW_CNT_WD - 1 : 0]   flit_dw_cnt
  );
    logic prev_dv;
    load_accum_16dw = '0;
    prev_dv = |prev_shift_data.data_valid[(P_NW+15) : P_NW];
    if(dv) begin
      // If the data path width is 512-bit or greater the overflow is accounted for in the last flit cycle
      if(flit_dw_cnt == P_DW_LAST - 1) begin
        load_accum_16dw.data_valid = {{(P_SHIFT_NW-(P_NW+16+5)){1'b0}}, {P_NW{dv}}, {(16+5){prev_dv}}};
        load_accum_16dw.data = {{(P_SHIFT_NW-21-P_NW){P_NOP}}, data, prev_shift_data.data[(P_NW+15) : (P_NW+11)], {5{P_NOP}}, prev_shift_data.data[(P_NW+10) : P_NW]};
        load_accum_16dw.sot = {{(P_SHIFT_NW-21-P_NW){1'b0}}, sot, prev_shift_data.sot[(P_NW+15) : (P_NW+11)], {5{1'b0}}, prev_shift_data.sot[(P_NW+10) : P_NW]};
        load_accum_16dw.eot = {{(P_SHIFT_NW-21-P_NW){1'b0}}, eot, prev_shift_data.eot[(P_NW+15) : (P_NW+11)], {5{1'b0}}, prev_shift_data.eot[(P_NW+10) : P_NW]};
        load_accum_16dw.flit_marker = {{(P_SHIFT_NW-21-P_NW){4'h0}}, flit_marker, prev_shift_data.flit_marker[(P_NW+15) : (P_NW+11)], {5{4'h0}}, prev_shift_data.flit_marker[(P_NW+10) : P_NW]};
      end
      else begin
        load_accum_16dw.data_valid = {{(P_SHIFT_NW-(2*P_NW)){1'b0}}, {P_NW{dv}}, {P_NW{prev_dv}}};
        load_accum_16dw.data = {{(P_SHIFT_NW-16-P_NW){P_NOP}}, data, prev_shift_data.data[(P_NW+15) : P_NW]};
        load_accum_16dw.sot = {{(P_SHIFT_NW-16-P_NW){1'b0}}, sot, prev_shift_data.sot[(P_NW+15) : P_NW]};
        load_accum_16dw.eot = {{(P_SHIFT_NW-16-P_NW){1'b0}}, eot, prev_shift_data.eot[(P_NW+15) : P_NW]};
        load_accum_16dw.flit_marker = {{(P_SHIFT_NW-16-P_NW){4'h0}}, flit_marker, prev_shift_data.flit_marker[(P_NW+15) : P_NW]};
      end
    end else begin
      if(flit_dw_cnt == P_DW_LAST - 1) begin
        load_accum_16dw.data_valid = {{(P_SHIFT_NW-(2*P_NW)){1'b0}}, {(2*P_NW){prev_dv}}};
        load_accum_16dw.data = {{(P_SHIFT_NW-21){P_NOP}}, prev_shift_data.data[(P_NW+15) : (P_NW+11)], {5{P_NOP}}, prev_shift_data.data[(P_NW+10) : P_NW]};
        load_accum_16dw.sot = {{(P_SHIFT_NW-21){1'b0}}, prev_shift_data.sot[(P_NW+15) : (P_NW+11)], {5{1'b0}}, prev_shift_data.sot[(P_NW+10) : P_NW]};
        load_accum_16dw.eot = {{(P_SHIFT_NW-21){1'b0}}, prev_shift_data.eot[(P_NW+15) : (P_NW+11)], {5{1'b0}}, prev_shift_data.eot[(P_NW+10) : P_NW]};
        load_accum_16dw.flit_marker = {{(P_SHIFT_NW-21){4'h0}}, prev_shift_data.flit_marker[(P_NW+15) : (P_NW+11)], {5{4'h0}}, prev_shift_data.flit_marker[(P_NW+10) : P_NW]};
      end else begin
        load_accum_16dw.data_valid = {{(P_SHIFT_NW-P_NW){1'b0}}, {P_NW{prev_dv}}};
        load_accum_16dw.data = {{(P_SHIFT_NW-16){P_NOP}}, prev_shift_data.data[(P_NW+15) : P_NW]};
        load_accum_16dw.sot = {{(P_SHIFT_NW-16){1'b0}}, prev_shift_data.sot[(P_NW+15) : P_NW]};
        load_accum_16dw.eot = {{(P_SHIFT_NW-16){1'b0}}, prev_shift_data.eot[(P_NW+15) : P_NW]};
        load_accum_16dw.flit_marker = {{(P_SHIFT_NW-16){4'h0}}, prev_shift_data.flit_marker[(P_NW+15) : P_NW]};
      end
    end
    return load_accum_16dw;
  endfunction


  // Function Name  : calculate_overflow 
  // Description    : Load new data and merge with 4DW accumulated in the previous cycle
  function automatic logic [P_ACCUM_DW_WD - 1 : 0] calculate_overflow(
    input                         dv,
    input [P_ACCUM_DW_WD - 1 : 0] prev_accum_dw,
    input [P_DW_CNT_WD - 1 : 0]   flit_dw_cnt,
    input [P_SHIFT_NW - 1 : 0]    merged_sot,
    input [P_SHIFT_NW - 1 : 0]    merged_eot
  );
    calculate_overflow = '0;
    // If EOT occurs after the last SOT in the overflow portion of the shifter overflow is dependent on the EOT location 
    if(merged_eot[P_SHIFT_NW-1:P_NW] > merged_sot[P_SHIFT_NW-1:P_NW]) begin
      casez(merged_eot[P_SHIFT_NW-1:P_NW])
        21'b00000_00000000_00000001 : calculate_overflow = 6'd1;
        21'b00000_00000000_0000001? : calculate_overflow = 6'd2;
        21'b00000_00000000_000001?? : calculate_overflow = 6'd3;
        21'b00000_00000000_00001??? : calculate_overflow = 6'd4;
        21'b00000_00000000_0001???? : calculate_overflow = 6'd5;
        21'b00000_00000000_001????? : calculate_overflow = 6'd6;
        21'b00000_00000000_01?????? : calculate_overflow = 6'd7;
        21'b00000_00000000_1??????? : calculate_overflow = 6'd8;
        21'b00000_00000001_???????? : calculate_overflow = 6'd9;
        21'b00000_0000001?_???????? : calculate_overflow = 6'd10;
        21'b00000_000001??_???????? : calculate_overflow = 6'd11;
        21'b00000_00001???_???????? : calculate_overflow = 6'd12;
        21'b00000_0001????_???????? : calculate_overflow = 6'd13;
        21'b00000_001?????_???????? : calculate_overflow = 6'd14;
        21'b00000_01??????_???????? : calculate_overflow = 6'd15;
        21'b00000_1???????_???????? : calculate_overflow = 6'd16;
        21'b00001_????????_???????? : calculate_overflow = 6'd17;
        21'b0001?_????????_???????? : calculate_overflow = 6'd18;
        21'b001??_????????_???????? : calculate_overflow = 6'd19;
        21'b01???_????????_???????? : calculate_overflow = 6'd20;
        21'b1????_????????_???????? : calculate_overflow = 6'd21;
        default : calculate_overflow = '0;
      endcase
    end else begin
      // If EOT occured last no overflow
      if(merged_eot > merged_sot) begin
        calculate_overflow = '0;
      // In the last cycle of the flit accumulate 5DW if there is valid data
      end else begin
        if(dv) begin
          calculate_overflow = (flit_dw_cnt == P_DW_LAST - 1) ? prev_accum_dw + 'd5 : prev_accum_dw;
        end
      end
    end
    return calculate_overflow;
  endfunction

  // Function Name  : count_sots
  // Description    : This function returns a count of the number of sots 
  //                  sot <logic [P_NW-1:0]>
  // Outputs        : sot_cnt <logic>
  function automatic logic [P_XTLH_MAX_TLP_CNT_WD - 1 : 0] count_sots (
    input [P_NW + 5 - 1 : 0] sot
  );
    begin
      logic [P_XTLH_MAX_TLP_CNT_WD - 1 : 0] per_sot_cnt [P_NW+5-1:0];
      count_sots = 0;
      for(int i = 0; i < P_NW+5; i++) begin
        if(i==0)
          per_sot_cnt[i] = sot[i] ? 1 : 0;
        else
          per_sot_cnt[i] = per_sot_cnt[i-1] + (sot[i] ? 1 : 0);
      end
      count_sots = per_sot_cnt[P_NW+5-1];
    end
    return count_sots;
  endfunction


  // Return onehot encoding of first bit set in the vector
  function automatic logic [P_NW - 1 : 0] find_first(
    input [P_NW - 1 : 0]  sig_in 
  );
    logic found_first;
    find_first = '0;
    found_first = 0;
    if(sig_in[0])
      find_first[0] = 1'b1;
    else begin
      for(int i = 1; i < $bits(sig_in); i++) begin
        if(!found_first && (sig_in[i] == 1)) begin
          find_first[i] = 1'b1;
          found_first = 1'b1;
        end
      end
    end
    return find_first;
  endfunction

  // Return onehot encoding of first bit set in the vector
  function automatic logic [P_NFM_NW - 1 : 0] nfm_find_first(
    input [P_NFM_NW - 1 : 0]  sig_in 
  );
    logic found_first;
    nfm_find_first = '0;
    found_first = 0;
    if(sig_in[0])
      nfm_find_first[0] = 1'b1;
    else begin
      for(int i = 1; i < $bits(sig_in); i++) begin
        if(!found_first && (sig_in[i] == 1)) begin
          nfm_find_first[i] = 1'b1;
          found_first = 1'b1;
        end
      end
    end
    return nfm_find_first;
  endfunction

  // Return onehot encoding of first bit set in the vector
  function automatic logic [P_NW + 5 - 1 : 0] find_first_over(
    input [P_NW + 5 - 1 : 0]  sig_in 
  );
    logic found_first;
    find_first_over = '0;
    found_first = 0;
    if(sig_in[0])
      find_first_over[0] = 1'b1;
    else begin
      for(int i = 1; i < $bits(sig_in); i++) begin
        if(!found_first && (sig_in[i] == 1)) begin
          find_first_over[i] = 1'b1;
          found_first = 1'b1;
        end
      end
    end
    return find_first_over;
  endfunction

endpackage // xtlh_ms_pkg
`endif // __GUARD__XTLH_MS_PKG__SVH__
