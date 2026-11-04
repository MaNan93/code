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
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/xaim_hdrdw_form_ms.sv#7 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
//  The major funcions:
//  (1) Based on inputs to form tlp pkt as PCI-Express required.  Calculation of DW_LEN, DW_LAST, DW_FIRST
//      and 128-bit data aligment for memory address because of address offset and DW align offset
//  (2) 128-bit data alignment based on addr[1:0] offset
//  interfaces

//  Notes for interface requirement:
//  (1) for header only transaction, client_xadm_hv and client_xadm_eot are
//      asserted at the same time, but client_xadm_dv is always deasserted
//  (2) for 1 DW payload transaction, client_xadm_hv, client_xadm_eot and client_xadm_dv are
//      asserted at the same time
//  (3) output dv and hv will be always asserted together if there is
//      payload in the current tlp
// ----------------------------------------------------------------------------

`include "DWC_pcie_ctl_pkg.svh"
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Adm_ms/xaim_ms_pkg.svh"
`include "products/pcie_pkg.svh"

module xaim_hdrdw_form_ms
import DWC_pcie_core_pkg::*;
import DWC_pcie_ctl_pkg::*;
import xaim_ms_pkg::*;
import pcie_pkg::*;
#( 
  parameter tx_port_id_e PORT_E = E_TX_PORT_ID_LBC
) (
  // Clocks/Resets
  input                              core_clk,
  input                              core_rst_n,
  // Configuration Structs
  input  xali_xaim_cfg_t             xali_xaim_cfg,    // Configuration from Application
  input  cdm_xaim_cfg_t              cdm_xaim_cfg,     // Configuration from CDM
  // TLP Packet from Application/CDM/LBC
  input  xaim_pkt_t                  i_xaim_pkt,       // From Application/CDM/LBC
  output logic                       o_xaim_halt,      // To Application/CDM/LBC
  // Header Formed TLP Packet to XADM
  output xadm_pkt_t                  o_xadm_pkt,       // To XADM
  input  logic                       i_xadm_halt       // From XADM
);

///////////////////////////////////////////
// Configuration
///////////////////////////////////////////
logic  tlp_hdr_passthrough;
assign tlp_hdr_passthrough = 1'b0;

///////////////////////////////////////////
// Hdr/Data Dwen Calculation
///////////////////////////////////////////
tlp_hdr_pkt_s               tlp_hdr_pkt_frm;     // Newly Formed, modified packet used to populate fields
logic                 [3:0] hdr_dw_cnt;
logic [ADM_PRFX_HDR_NW-1:0] hdr_dwen;
logic              [NW-1:0] data_dwen;

always_comb begin
  hdr_dw_cnt = '0;
  hdr_dwen   = '0;
  data_dwen  = '0;

  hdr_dw_cnt = (tlp_hdr_pkt_frm.tlp_fmt[0] ? 4'd4 : 3'd3) + ((cdm_xaim_cfg.mode == E_FM) ? f_decode_ohc_len(tlp_hdr_pkt_frm.tlp_ohc) : 0);
  hdr_dwen   = (ADM_PRFX_HDR_NW)'(f_int_to_dwen((5)'(hdr_dw_cnt)));
  data_dwen  = f_dw_decode(tlp_hdr_pkt_frm.tlp_len[LEN_OFFSET_WIDTH-1:0]);
end

logic [NW-1:0] data_dwen_d;
logic          quashed_dv;
logic          quashed_dv_d;

assign quashed_dv = tlp_hdr_pkt_frm.tlp_fmt[1];  // DV should be quashed when there is no data to be sent.

always_ff @ ( posedge core_clk or negedge core_rst_n ) begin
  if ( ~core_rst_n ) begin
    data_dwen_d  <= #TP '0;
    quashed_dv_d <= #TP '0;
  end else begin
    if ( i_xaim_pkt.fs.hv ) begin
      data_dwen_d  <= #TP data_dwen;
      quashed_dv_d <= #TP quashed_dv;
    end
  end
end

///////////////////////////////////////////
// Port Type Decode Logic
///////////////////////////////////////////
logic port_msg;       assign port_msg       = (PORT_E == E_TX_PORT_ID_MSG);
logic port_lbc;       assign port_lbc       = (PORT_E == E_TX_PORT_ID_LBC);
logic port_xali;      assign port_xali      = (PORT_E == E_TX_PORT_ID_XALI);

///////////////////////////////////////////
// Device Type Decode Logic
///////////////////////////////////////////
logic dev_rc;         assign dev_rc         = (xali_xaim_cfg.device_type == `PCIE_RC);
logic dev_ep;         assign dev_ep         = (xali_xaim_cfg.device_type == `PCIE_EP);
logic dev_sw_dwn;     assign dev_sw_dwn     = (xali_xaim_cfg.device_type == `PCIE_SW_DOWN);
logic dev_sw_up;      assign dev_sw_up      = (xali_xaim_cfg.device_type == `PCIE_SW_UP);
logic dev_pcix;       assign dev_pcix       = (xali_xaim_cfg.device_type == `PCIE_PCIX);
logic dev_pcie;       assign dev_pcie       = (xali_xaim_cfg.device_type == `PCIX_PCIE);
logic dev_up_stream;  assign dev_up_stream  = dev_ep | dev_sw_up;
logic dev_dwn_stream; assign dev_dwn_stream = dev_rc | dev_sw_dwn;


///////////////////////////////////////////
// TLP Prefix Decode Logic
///////////////////////////////////////////
logic       [$clog2(NW_PRFX+1)-1:0] prfx_dw_cnt;
logic                         [7:0] prfx_type;
prfx_type_e           [NW_PRFX-1:0] prfx_type_decode;
logic                 [NW_PRFX-1:0] tlp_prfx_is_local;
logic                 [NW_PRFX-1:0] tlp_prfx_is_e2e;
logic                 [NW_PRFX-1:0] tlp_prfx_total;
logic                 [NW_PRFX-1:0] tlp_prfx_is_ide;
logic                 [NW_PRFX-1:0] tlp_prfx_is_ohc_e;
logic                         [7:0] [31:0] tlp_prfx_e2e;
logic                 [NW_PRFX-1:0] [31:0] tlp_prfx_extract;

always_comb begin
  prfx_dw_cnt       = '0;
  prfx_type_decode  = prfx_type_e'(0);
  tlp_prfx_is_local = '0;
  tlp_prfx_is_e2e   = '0;
  tlp_prfx_is_ide   = '0;
  tlp_prfx_extract  = '0;
  for (int i=0; i<NW_PRFX; i++) begin
    prfx_type            = i_xaim_pkt.prfx[i*32+7-:8];                  // Extract byte0
    prfx_type_decode[i]  = f_tlp_prfx_decode      (prfx_type);          // Decode the Prefix Types
    tlp_prfx_is_local[i] = f_tlp_prfx_is_local    (prfx_type);          // Local TLP Prefix Types
    tlp_prfx_is_e2e[i]   = f_tlp_prfx_is_e2e      (prfx_type);          // End-to-End TLP Prefix Types
    tlp_prfx_total[i]    = tlp_prfx_is_local[i] | tlp_prfx_is_e2e[i];   // Total No of Prefixes
    tlp_prfx_is_ohc_e[i] = f_tlp_prfx_is_e2e_ohce (prfx_type);          // Prefix to be sent in OHCE

    if ((( cdm_xaim_cfg.mode == E_NFM ) & tlp_prfx_total[i]) | (( cdm_xaim_cfg.mode == E_FM ) & tlp_prfx_is_local[i])) begin
      tlp_prfx_extract[prfx_dw_cnt[$clog2((NW_PRFX == 1)? 2 : NW_PRFX)-1:0]] = i_xaim_pkt.prfx[i*32+31 -: 32];
      prfx_dw_cnt = prfx_dw_cnt + 1'b1;
    end
  end
end

///////////////////////////////////////////
// TLP Header Decode Logic
///////////////////////////////////////////
tlp_hdr_decode_s tlp_hdr_decode_pre_frm;  assign tlp_hdr_decode_pre_frm  = f_tlp_hdr_decode(cdm_xaim_cfg.mode, i_xaim_pkt.tlp_hdr_pkt);
tlp_hdr_decode_s tlp_hdr_decode_post_frm; assign tlp_hdr_decode_post_frm = f_tlp_hdr_decode(cdm_xaim_cfg.mode, tlp_hdr_pkt_frm       );

addr_size_e addr_size;           assign addr_size           = f_tlp_addr_size   (cdm_xaim_cfg.mode, tlp_hdr_pkt_frm);
logic       tlp_is_mem_rd;       assign tlp_is_mem_rd       = f_tlp_is_memrd    (cdm_xaim_cfg.mode, tlp_hdr_pkt_frm);
logic       tlp_is_mem_wr;       assign tlp_is_mem_wr       = f_tlp_is_memwr    (cdm_xaim_cfg.mode, tlp_hdr_pkt_frm);
logic       tlp_is_def_mem_wr;   assign tlp_is_def_mem_wr   = f_tlp_is_defmemwr (cdm_xaim_cfg.mode, tlp_hdr_pkt_frm);
logic       tlp_is_mem;          assign tlp_is_mem          = tlp_is_mem_rd | tlp_is_mem_wr | tlp_is_def_mem_wr;
logic       tlp_is_atomic;       assign tlp_is_atomic       = f_tlp_is_atomic   (cdm_xaim_cfg.mode, tlp_hdr_pkt_frm);
msg_route_e msgRoute;            assign msgRoute            = f_tlp_msg_routing (cdm_xaim_cfg.mode, tlp_hdr_pkt_frm);
logic       tlp_is_at_trans_req; assign tlp_is_at_trans_req = ((tlp_hdr_decode_post_frm.trans_type == E_MRD) &  (tlp_hdr_pkt_frm.tlp_at == `DC_AT_TRANS_REQ));
logic       tlp_is_io;           assign tlp_is_io           = f_tlp_is_io       (cdm_xaim_cfg.mode, tlp_hdr_pkt_frm);
logic       tlp_is_io_rd;        assign tlp_is_io_rd        = f_tlp_is_iord     (cdm_xaim_cfg.mode, tlp_hdr_pkt_frm);
logic       tlp_is_io_wr;        assign tlp_is_io_wr        = f_tlp_is_iowr     (cdm_xaim_cfg.mode, tlp_hdr_pkt_frm);
logic       tlp_is_cfg;          assign tlp_is_cfg          = f_tlp_is_cfg      (cdm_xaim_cfg.mode, tlp_hdr_pkt_frm);
logic       tlp_is_cfg_rd;       assign tlp_is_cfg_rd       = f_tlp_is_cfgrd    (cdm_xaim_cfg.mode, tlp_hdr_pkt_frm);
logic       tlp_is_cfg_wr;       assign tlp_is_cfg_wr       = f_tlp_is_cfgwr    (cdm_xaim_cfg.mode, tlp_hdr_pkt_frm);
logic       tlp_is_cfg1;         assign tlp_is_cfg1         = f_tlp_is_cfg1     (cdm_xaim_cfg.mode, i_xaim_pkt.tlp_hdr_pkt);
logic       tlp_is_cpl;          assign tlp_is_cpl          = f_tlp_is_cpl      (cdm_xaim_cfg.mode, tlp_hdr_pkt_frm);
logic       tlp_is_cpld;         assign tlp_is_cpld         = f_tlp_is_cpld     (cdm_xaim_cfg.mode, tlp_hdr_pkt_frm);
logic       tlp_is_msg;          assign tlp_is_msg          = f_tlp_is_msg      (cdm_xaim_cfg.mode, tlp_hdr_pkt_frm);
logic       tlp_is_msgd;         assign tlp_is_msgd         = f_tlp_is_msgd     (cdm_xaim_cfg.mode, tlp_hdr_pkt_frm);
logic       tlp_is_nop;          assign tlp_is_nop          = f_tlp_is_nop      (cdm_xaim_cfg.mode, i_xaim_pkt.tlp_hdr_pkt);
logic       tlp_is_known;        assign tlp_is_known        = f_tlp_is_known    (cdm_xaim_cfg.mode, tlp_hdr_pkt_frm);


///////////////////////////////////////////
// Request ID Muxing
///////////////////////////////////////////
logic [15:0] rid_bdf;
logic [15:0] req_id_app;
logic [15:0] req_id_sel;
logic [15:0] req_id;

assign req_id_app = f_req_id_from_bdf(cdm_xaim_cfg.cfg_pbus_num, cdm_xaim_cfg.cfg_pbus_dev_num, (NF_WD)'(i_xaim_pkt.tlp_hdr_pkt.tlp_fn), cdm_xaim_cfg, xali_xaim_cfg);
assign req_id_sel = (port_msg | port_lbc) ? i_xaim_pkt.tlp_hdr_pkt.tlp_cpl_id : req_id_app;
assign req_id     = req_id_sel;

///////////////////////////////////////////
// Secondary Bus Matching
///////////////////////////////////////////
logic int_bus_num_match;
assign int_bus_num_match = '0 ;

///////////////////////////////////////////
// Incoming TLP Reformat
///////////////////////////////////////////
logic [7:0] tlp_fn;
logic       dw0_B1_b7;
logic       dw0_B1_b3;
logic [3:0] dw2_B10_b7_4;
logic       dw2_B11_b7;
logic [4:0] ohc_a_present;
logic       ohc_b_present;
logic       ohc_c_present;
logic [2:0] ohc_e_present;
logic [2:0] ohc_e_cnt;

always_comb begin
  tlp_hdr_pkt_frm = i_xaim_pkt.tlp_hdr_pkt; // Assign the incoming packet to the Re-Formed Version
  dw0_B1_b7    = '0;
  dw0_B1_b3    = '0;
  tlp_fn       = '0;
  dw2_B10_b7_4 = '0;
  dw2_B11_b7   = '0;
  tlp_hdr_pkt_frm.tlp_sub_stream = 4'h7;
  //rid_bdf      = f_req_id_from_bdf(cdm_xaim_cfg.cfg_pbus_num, cdm_xaim_cfg.cfg_pbus_dev_num, (NF_WD)'(i_xaim_pkt.tlp_hdr_pkt.tlp_fn), cdm_xaim_cfg, xali_xaim_cfg); 

  // 1. Extract E2E Prefix Info
  ohc_e_cnt    = '0;
  tlp_prfx_e2e = '0;
  for ( int i=0; i<NW_PRFX; i++) begin
    if ( prfx_type_decode[i] == E_TLP_E2E_PRFX_PASID ) begin
      tlp_hdr_pkt_frm.tlp_pasid = {i_xaim_pkt.prfx[i*32+11-:4], i_xaim_pkt.prfx[i*32+23-:8], i_xaim_pkt.prfx[i*32+31-:8]};
      tlp_hdr_pkt_frm.tlp_pmr   = i_xaim_pkt.prfx[i*32+15];
      tlp_hdr_pkt_frm.tlp_er    = i_xaim_pkt.prfx[i*32+14];
      tlp_hdr_pkt_frm.tlp_pv    = 1'b1;
    end else if ( prfx_type_decode[i] == E_TLP_E2E_PRFX_TPH ) begin
      tlp_hdr_pkt_frm.tlp_st[15:8] = i_xaim_pkt.prfx[i*32+15-:8];  // Extract uppermost bits of steering tag.
      tlp_hdr_pkt_frm.tlp_ama      = i_xaim_pkt.prfx[i*32+23-:3];
      tlp_hdr_pkt_frm.tlp_av       = i_xaim_pkt.prfx[i*32+20];
      tlp_hdr_pkt_frm.tlp_hv[1]    = (i_xaim_pkt.tlp_hdr_pkt.tlp_th & |tlp_hdr_pkt_frm.tlp_st[15:8]);
    end else if ( tlp_prfx_is_ohc_e[i] ) begin
      tlp_prfx_e2e[ohc_e_cnt] = i_xaim_pkt.prfx[i*32+31-:32];
      ohc_e_cnt = ohc_e_cnt + 'd1;
    end
  end

  // 2. Handle Reserved Header Bits
  if ( ~(tlp_is_mem_wr & i_xaim_pkt.tlp_hdr_pkt.tlp_th) ) begin
    dw0_B1_b7    = i_xaim_pkt.tlp_hdr_pkt.tlp_tag[9];
    dw0_B1_b3    = i_xaim_pkt.tlp_hdr_pkt.tlp_tag[8];
  end


  // 3. Handle Length Field ( Calculated or Provided )
  if ( ~tlp_hdr_passthrough )
    tlp_hdr_pkt_frm.tlp_len    = f_calc_len(cdm_xaim_cfg.mode, i_xaim_pkt, tlp_hdr_decode_pre_frm);

  // 4. Handle Byte Enables ( Calculated or Provided )
  tlp_hdr_pkt_frm.tlp_ldw_be   = tlp_is_atomic ? 4'h0 : i_xaim_pkt.addr_align_en ? f_tlp_ldw_be_calc(cdm_xaim_cfg.mode, tlp_hdr_pkt_frm.tlp_len, i_xaim_pkt) : i_xaim_pkt.tlp_hdr_pkt.tlp_ldw_be;
  tlp_hdr_pkt_frm.tlp_fdw_be   = tlp_is_atomic ? 4'h0 : i_xaim_pkt.addr_align_en ? f_tlp_fdw_be_calc(i_xaim_pkt)                                : i_xaim_pkt.tlp_hdr_pkt.tlp_fdw_be;

  // 5. Handle TLP Digest
  tlp_hdr_pkt_frm.tlp_td = i_xaim_pkt.tlp_hdr_pkt.tlp_td | ( ~tlp_hdr_passthrough & f_get_ecrc_en(cdm_xaim_cfg.cfg_ecrc_gen_en, (NF_WD)'(i_xaim_pkt.tlp_hdr_pkt.tlp_fn)));

  // 6. Handle Request ID
  tlp_hdr_pkt_frm.tlp_req_id      = tlp_is_cpl ? i_xaim_pkt.tlp_hdr_pkt.tlp_req_id : req_id;

  // 7. Handle Destination ID/Ext Reg Num & Reg Num - Cfg Requests
  tlp_hdr_pkt_frm.tlp_dst_id      = i_xaim_pkt.tlp_hdr_pkt.tlp_addr[31:16];
  tlp_hdr_pkt_frm.tlp_ext_reg_num = i_xaim_pkt.tlp_hdr_pkt.tlp_addr[11:8];
  tlp_hdr_pkt_frm.tlp_reg_num     = i_xaim_pkt.tlp_hdr_pkt.tlp_addr[7:2];

  // 8. Handle Completion ID
  tlp_hdr_pkt_frm.tlp_cpl_id      = req_id;

  // 9. Handle Bus, Device and Function Numbers
  tlp_hdr_pkt_frm.tlp_bn = cdm_xaim_cfg.cfg_pbus_num;
  tlp_hdr_pkt_frm.tlp_dn = cdm_xaim_cfg.cfg_pbus_dev_num;
  tlp_fn         = (NF>1) ? ((dev_sw_up | dev_sw_dwn | dev_pcix | dev_pcie) & (tlp_is_cpl)) ? (8)'(i_xaim_pkt.tlp_hdr_pkt.tlp_req_id[NF_WD-1:0]) : (8)'(tlp_hdr_pkt_frm.tlp_cpl_id[NF_WD-1:0]) : '0;
  tlp_hdr_pkt_frm.tlp_fn = dev_rc ? (tlp_fn & 8'b00000111) : tlp_fn;

  // 10. Handle Destination Segment
  tlp_hdr_pkt_frm.tlp_dsv     = '0;
  tlp_hdr_pkt_frm.tlp_dst_seg = '0;
  if (i_xaim_pkt.tlp_hdr_pkt.tlp_dsv & (PORT_E == E_TX_PORT_ID_XALI) & ~tlp_is_cfg & ~tlp_is_cpl) begin
    tlp_hdr_pkt_frm.tlp_dsv     = i_xaim_pkt.tlp_hdr_pkt.tlp_dsv;
    tlp_hdr_pkt_frm.tlp_dst_seg = i_xaim_pkt.tlp_hdr_pkt.tlp_dst_seg;
  end else if ((PORT_E == E_TX_PORT_ID_XALI) & tlp_is_cpl) begin
    tlp_hdr_pkt_frm.tlp_dsv       = i_xaim_pkt.tlp_hdr_pkt.tlp_dsv;
    tlp_hdr_pkt_frm.tlp_dst_seg   = i_xaim_pkt.tlp_hdr_pkt.tlp_dst_seg;
  end else if (( PORT_E == E_TX_PORT_ID_LBC) && tlp_is_cpl) begin
    if (i_xaim_pkt.tlp_hdr_pkt.tlp_dsv) begin
      tlp_hdr_pkt_frm.tlp_dsv     = i_xaim_pkt.tlp_hdr_pkt.tlp_dsv;
      tlp_hdr_pkt_frm.tlp_dst_seg = i_xaim_pkt.tlp_hdr_pkt.tlp_dst_seg;
    end
  end else if (( PORT_E == E_TX_PORT_ID_MSG) && tlp_is_msg) begin // dst segment is sent with IDE messegs
    if (i_xaim_pkt.tlp_hdr_pkt.tlp_dsv) begin
      tlp_hdr_pkt_frm.tlp_dsv     = i_xaim_pkt.tlp_hdr_pkt.tlp_dsv;
      tlp_hdr_pkt_frm.tlp_dst_seg = i_xaim_pkt.tlp_hdr_pkt.tlp_dst_seg; 
    end
  end else if ( cdm_xaim_cfg.cfg_segment_id[8] ) begin
    tlp_hdr_pkt_frm.tlp_dsv     =  cdm_xaim_cfg.cfg_segment_id[8];
    tlp_hdr_pkt_frm.tlp_dst_seg =  cdm_xaim_cfg.cfg_segment_id[7:0];
  end

  // 11. Handle Requester Completer Segment
  tlp_hdr_pkt_frm.tlp_cpl_seg = '0;
  if ( dev_dwn_stream ) begin
    if ( i_xaim_pkt.tlp_hdr_pkt.tlp_rsv ) begin
      tlp_hdr_pkt_frm.tlp_cpl_seg = i_xaim_pkt.tlp_hdr_pkt.tlp_req_seg;
    end else if ( cdm_xaim_cfg.cfg_segment_id[8] ) begin
      tlp_hdr_pkt_frm.tlp_req_seg = cdm_xaim_cfg.cfg_segment_id[7:0];
      tlp_hdr_pkt_frm.tlp_cpl_seg = cdm_xaim_cfg.cfg_segment_id[7:0];
      tlp_hdr_pkt_frm.tlp_rsv     = ~tlp_is_cpl;
    end else begin
      tlp_hdr_pkt_frm.tlp_req_seg = '0;
      tlp_hdr_pkt_frm.tlp_cpl_seg = '0;
    end
  end else begin
    if ( cdm_xaim_cfg.cfg_segment_id[8] ) begin
      tlp_hdr_pkt_frm.tlp_req_seg = cdm_xaim_cfg.cfg_segment_id[7:0];
      tlp_hdr_pkt_frm.tlp_cpl_seg = cdm_xaim_cfg.cfg_segment_id[7:0];
      tlp_hdr_pkt_frm.tlp_rsv     = tlp_is_msg | ~tlp_is_cpl;
    end else begin
      tlp_hdr_pkt_frm.tlp_req_seg = '0;
      tlp_hdr_pkt_frm.tlp_cpl_seg = '0;
      tlp_hdr_pkt_frm.tlp_rsv     = '0;
    end
  end
   
  // 12. Handle OHC Header Content  
  tlp_hdr_pkt_frm.tlp_ohc = {|ohc_e_present[2:1], ohc_e_present[2] | ohc_e_present[0], ohc_c_present, ohc_b_present, |ohc_a_present};

  // 13. Handle Trailer Size
  if (|tlp_prfx_is_ide & tlp_hdr_pkt_frm.tlp_m)
    tlp_hdr_pkt_frm.tlp_ts = {tlp_hdr_pkt_frm.tlp_m, tlp_hdr_pkt_frm.tlp_p, ~tlp_hdr_pkt_frm.tlp_p};
  else
    tlp_hdr_pkt_frm.tlp_ts = {2'b00, tlp_hdr_pkt_frm.tlp_td};

  // 14. Handle TLP Hints
  tlp_hdr_pkt_frm.tlp_hv[0] = i_xaim_pkt.tlp_hdr_pkt.tlp_th;

  // 15. Convert Fmt/Type in the case of FM Nops. Convert Type in the case of Cfg1 Types
  tlp_hdr_pkt_frm.tlp_fmt  = tlp_is_nop ? 2'd00 : i_xaim_pkt.tlp_hdr_pkt.tlp_fmt;
  tlp_hdr_pkt_frm.tlp_type = tlp_is_nop ? 5'd03 : (tlp_is_cfg1 & int_bus_num_match) ? 5'd04 : i_xaim_pkt.tlp_hdr_pkt.tlp_type;

end



logic [6:0] [31:0] tlp_ohc_dw;
logic        [7:0] ohc_be;
logic              ohc_be_explicit;
logic              ohc_invalid_req;
logic              ohc_invalid_cpl;
logic              ohc_prg_rsp;
logic              ohc_dst_seg_required;

///////////////////////////////////////////
// Determine which OHCs are present
/////////////////////////////////////////// 
assign ohc_a_present[0] = (( tlp_is_mem & (ohc_be_explicit | tlp_hdr_pkt_frm.tlp_pv | cdm_xaim_cfg.cfg_optional_ohc_ctrl[0])) | ( tlp_is_atomic & (tlp_hdr_pkt_frm.tlp_pv | cdm_xaim_cfg.cfg_optional_ohc_ctrl[0])) | tlp_is_at_trans_req | ( tlp_is_msg & ((msgRoute == E_MR_BY_ADDR) | (msgRoute == E_MR_TO_RC)) & tlp_hdr_pkt_frm.tlp_pv)); // OHC-A1 
assign ohc_a_present[1] = (( tlp_hdr_decode_pre_frm.trans_type == E_IORD)  | ( tlp_hdr_decode_pre_frm.trans_type == E_IOWR)); // OHC-A2
assign ohc_a_present[2] = (( tlp_hdr_decode_pre_frm.trans_type == E_CFGRD) | ( tlp_hdr_decode_pre_frm.trans_type == E_CFGWR)); // OHC-A3
assign ohc_a_present[3] = ((tlp_is_msg & ( msgRoute == E_MR_BY_ID )) & (tlp_hdr_pkt_frm.tlp_pv | ( tlp_hdr_pkt_frm.tlp_dsv & ohc_dst_seg_required) | cdm_xaim_cfg.cfg_optional_ohc_ctrl[0])); // OHC-A4
assign ohc_a_present[4] = ((tlp_hdr_decode_pre_frm.fc_type == E_CPL) & (((tlp_hdr_pkt_frm.tlp_dsv & (tlp_hdr_pkt_frm.tlp_dst_seg != tlp_hdr_pkt_frm.tlp_cpl_seg)) | (|tlp_hdr_pkt_frm.tlp_cpl_status) | (|tlp_hdr_pkt_frm.tlp_addr[1:0])) 
 | cdm_xaim_cfg.cfg_optional_ohc_ctrl[0])); // OHC-A5
assign ohc_b_present    = tlp_hdr_pkt_frm.tlp_th | tlp_hdr_pkt_frm.tlp_av; // OHC-B
assign ohc_c_present    = |(tlp_prfx_is_ide) | (tlp_hdr_pkt_frm.tlp_rsv & tlp_is_msg) | ((tlp_is_mem | tlp_is_atomic) & (tlp_hdr_pkt_frm.tlp_rsv & cdm_xaim_cfg.cfg_optional_ohc_ctrl[1])); // OHC-C
assign ohc_e_present[0] = (ohc_e_cnt == 3'd1) | 0; // OHC-E1
assign ohc_e_present[1] = (ohc_e_cnt == 3'd2) | 0; // OHC-E2
assign ohc_e_present[2] = ((ohc_e_cnt == 3'd3)| (ohc_e_cnt == 3'd4)) | 0; // OHC-E4

///////////////////////////////////////////
// Format OHC Fields if required
///////////////////////////////////////////
assign ohc_be               = {tlp_hdr_pkt_frm.tlp_ldw_be, tlp_hdr_pkt_frm.tlp_fdw_be};
assign ohc_be_explicit      = ~(( &ohc_be & ( tlp_hdr_pkt_frm.tlp_len != 1)) | ((ohc_be == 8'h0F) & (tlp_hdr_pkt_frm.tlp_len == 1)));
assign ohc_invalid_req      = ((tlp_is_msgd & ( msgRoute == E_MR_BY_ID )) & (tlp_hdr_pkt_frm.tlp_msg_code == `INVALIDATE_REQUEST));
assign ohc_invalid_cpl      = ((tlp_is_msg  & ( msgRoute == E_MR_BY_ID )) & (tlp_hdr_pkt_frm.tlp_msg_code == `INVALIDATE_COMPLETION));
assign ohc_prg_rsp          = ((tlp_is_msg  & ( msgRoute == E_MR_BY_ID )) & (tlp_hdr_pkt_frm.tlp_msg_code == `PRG_RES_TYPE));
assign ohc_dst_seg_required = (ohc_invalid_req | ohc_invalid_cpl | ohc_prg_rsp | (tlp_hdr_pkt_frm.tlp_dst_seg != tlp_hdr_pkt_frm.tlp_req_seg));

///////////////////////////////////////////
// TLP OHC-A/B/C Logic
///////////////////////////////////////////
logic [31:0] tlp_ohc_a_dw;
logic [31:0] tlp_ohc_b_dw;
logic [31:0] tlp_ohc_c_dw;
tlp_hdr_pkt_s tlp_hdr_pkt_rs_gated; // Formed Packet but with RSV/Requester Segment Gated

always_comb begin
  tlp_hdr_pkt_rs_gated             = tlp_hdr_pkt_frm;
  tlp_hdr_pkt_rs_gated.tlp_rsv     = |tlp_prfx_is_ide ? 1'b0  : tlp_hdr_pkt_frm.tlp_rsv;
  tlp_hdr_pkt_rs_gated.tlp_req_seg = |tlp_prfx_is_ide ? 8'h00 : tlp_hdr_pkt_frm.tlp_req_seg;

  case (ohc_a_present)
    5'b00001 : tlp_ohc_a_dw = f_ohc_a_pack(cdm_xaim_cfg.mode, tlp_hdr_pkt_frm, E_OHC_A1);
    5'b00010 : tlp_ohc_a_dw = f_ohc_a_pack(cdm_xaim_cfg.mode, tlp_hdr_pkt_frm, E_OHC_A2);
    5'b00100 : tlp_ohc_a_dw = f_ohc_a_pack(cdm_xaim_cfg.mode, tlp_hdr_pkt_frm, E_OHC_A3);
    5'b01000 : tlp_ohc_a_dw = f_ohc_a_pack(cdm_xaim_cfg.mode, tlp_hdr_pkt_frm, E_OHC_A4);
    5'b10000 : tlp_ohc_a_dw = f_ohc_a_pack(cdm_xaim_cfg.mode, tlp_hdr_pkt_frm, E_OHC_A5);
    default  : tlp_ohc_a_dw = '0;
  endcase

  tlp_ohc_b_dw = ohc_b_present ? f_ohc_b_pack(cdm_xaim_cfg.mode, tlp_hdr_pkt_frm,      E_OHC_B) : '0;
  tlp_ohc_c_dw = ohc_c_present ? f_ohc_c_pack(cdm_xaim_cfg.mode, tlp_hdr_pkt_rs_gated, E_OHC_C) : '0;

end

assign tlp_ohc_dw[OHC_A] = tlp_ohc_a_dw;
assign tlp_ohc_dw[OHC_B] = tlp_ohc_b_dw;
assign tlp_ohc_dw[OHC_C] = tlp_ohc_c_dw;

///////////////////////////////////////////
// TLP OHC-E Logic
///////////////////////////////////////////
assign tlp_ohc_dw[OHC_E1] = (|ohc_e_present)      ? {tlp_prfx_e2e[0][31:8], 4'b0001, tlp_prfx_e2e[0][3:0]} : 32'h0;
assign tlp_ohc_dw[OHC_E2] = (|ohc_e_present[2:1]) ? {tlp_prfx_e2e[1][31:8], 4'b0001, tlp_prfx_e2e[1][3:0]} : 32'h0;
assign tlp_ohc_dw[OHC_E3] = (ohc_e_present[2])    ? {tlp_prfx_e2e[2][31:8], 4'b0001, tlp_prfx_e2e[2][3:0]} : 32'h0;
assign tlp_ohc_dw[OHC_E4] = (ohc_e_present[2]) && (tlp_prfx_e2e[3][3:1] == 3'b111) ? {tlp_prfx_e2e[3][31:8], 4'b0001, tlp_prfx_e2e[3][3:0]} : 32'h0;

///////////////////////////////////////////
// TLP OHC Mapping
///////////////////////////////////////////
logic       [3:0] tlp_ohc_base;
logic [6:0] [3:0] tlp_ohc_map;

always_comb begin
  tlp_ohc_map = '0;
  if ( ( tlp_is_io | tlp_is_mem | tlp_is_atomic | tlp_is_msg ) & ( addr_size == E_ADDR64) )
    tlp_ohc_base = 'd4;
  else
    tlp_ohc_base = 'd3;

  tlp_ohc_map = f_ohc_map(tlp_ohc_base, ohc_a_present, ohc_b_present, ohc_c_present, ohc_e_present);
end


///////////////////////////////////////////
// TLP DW0-DW3 Logic - Base Header
///////////////////////////////////////////
logic [ADM_PRFX_HDR_NW-1:0] [31:0] tlp_hdr_dw;
logic                 [3:0] [31:0] tlp_hdr_dw_base;

assign tlp_hdr_dw_base = f_base_hdr_form (cdm_xaim_cfg.mode, tlp_hdr_pkt_frm);

///////////////////////////////////////////
// Merge Base Header + OHCs
///////////////////////////////////////////
always_comb begin
  tlp_hdr_dw = '0;
  for (int i=0; i<4; i++) begin
    tlp_hdr_dw[i] = tlp_hdr_dw_base[i];
  end  
  if ( tlp_hdr_decode_pre_frm.mode == E_FM ) begin
    for (int i=3; i<ADM_PRFX_HDR_NW; i++) begin
      for (int j=0; j<7; j++) begin
        if ( tlp_ohc_map[j] == (4)'(i) )
          tlp_hdr_dw[i] = tlp_ohc_dw[j];
      end
    end
  end else
  if ( tlp_hdr_decode_pre_frm.mode == E_NFM ) begin
    for (int i=4; i<ADM_PRFX_HDR_NW; i++)
      tlp_hdr_dw[i] = '0;
  end
end

logic [ADM_PRFX_HDR_NW-1:0] [31:0] tlp_prfx_hdr_dw;

///////////////////////////////////////////
// Merge Prefix and Header
///////////////////////////////////////////
always_comb begin
  tlp_prfx_hdr_dw = '0;
  for (int i=0; i<ADM_PRFX_HDR_NW; i++) begin
    if ((i < prfx_dw_cnt) && (i < NW_PRFX) )                    // Hardstop placed here on the NW_PRFX to fix spyglass issues
      tlp_prfx_hdr_dw[i] = tlp_prfx_extract[i];
    else if ( i < ADM_PRFX_HDR_NW)
      tlp_prfx_hdr_dw[i] = tlp_hdr_dw[i-prfx_dw_cnt];
  end
end

///////////////////////////////////////////
// XADM Packet Formation
///////////////////////////////////////////
assign o_xaim_halt = i_xadm_halt; // Straight passthrough on the halt


always_comb begin
  o_xadm_pkt = '0;
  o_xadm_pkt.prfx_hdr                  = tlp_prfx_hdr_dw; // Straight Assign?
  o_xadm_pkt.hv                        = i_xaim_pkt.fs.hv;
  o_xadm_pkt.dv                        =( i_xaim_pkt.fs.hv & i_xaim_pkt.fs.eot ) ? quashed_dv : ( !i_xaim_pkt.fs.hv & i_xaim_pkt.fs.eot ) ? quashed_dv_d : i_xaim_pkt.fs.dv;
  o_xadm_pkt.eot                       = i_xaim_pkt.fs.eot;
  o_xadm_pkt.bad_eot                   = i_xaim_pkt.fs.bad_eot;
  o_xadm_pkt.data                      = i_xaim_pkt.data;
  o_xadm_pkt.ras_dp_err_inband_kbd     = i_xaim_pkt.rasdp_kbd_prfx || i_xaim_pkt.rasdp_kbd_hdr || i_xaim_pkt.rasdp_kbd_data
;
  o_xadm_pkt.prfx_dwen                 = (ADM_PRFX_NW)'(f_int_to_dwen((5)'(prfx_dw_cnt)));
  o_xadm_pkt.hdr_dwen                  = (ADM_PRFX_HDR_NW)'({hdr_dwen<<prfx_dw_cnt});
  o_xadm_pkt.data_dwen                 = ( i_xaim_pkt.fs.hv & i_xaim_pkt.fs.eot ) ? data_dwen : ( !i_xaim_pkt.fs.hv & i_xaim_pkt.fs.eot ) ? data_dwen_d : {NW{1'b1}};
  o_xadm_pkt.order_seqnum              = i_xaim_pkt.fs.order_seqnum;
  o_xadm_pkt.origin_port               = i_xaim_pkt.tlp_is_dma ? E_TX_PORT_ID_DMA : PORT_E;
  // Support signals
  o_xadm_pkt.support.requester_segment = ( !tlp_is_cpl && !tlp_is_cfg ) ? {tlp_hdr_pkt_frm.tlp_rsv, tlp_hdr_pkt_frm.tlp_req_seg} : '0;
  o_xadm_pkt.support.ep                = tlp_hdr_pkt_frm.tlp_ep;
  o_xadm_pkt.support.td                = tlp_hdr_pkt_frm.tlp_td;

  o_xadm_pkt.support.func_num          = (NF_WD)'(tlp_hdr_pkt_frm.tlp_fn);
  //o_xadm_pkt.support.vc                = '0;
  o_xadm_pkt.support.low_addr          = tlp_hdr_pkt_frm.tlp_addr[6:0];
  o_xadm_pkt.support.is_atomic_cas     = f_tlp_is_cas( cdm_xaim_cfg.mode, tlp_hdr_pkt_frm );
  //o_xadm_pkt.support.np_req_type       = f_tlp_is_np ( cdm_xaim_cfg.mode, tlp_hdr_pkt_frm );
  //o_xadm_pkt.support.p_req_type        = f_tlp_is_p  ( cdm_xaim_cfg.mode, tlp_hdr_pkt_frm );
  //o_xadm_pkt.support.cpl_type          = f_tlp_is_cpl( cdm_xaim_cfg.mode, tlp_hdr_pkt_frm );
  o_xadm_pkt.support.np_req_type       =                                           tlp_is_def_mem_wr   ? E_NP_REQ_TX_DMWR :
                                           tlp_is_atomic     ? E_NP_REQ_TX_ATOMIC :
                                           tlp_is_at_trans_req ? E_NP_REQ_TX_MEMRD_ATS :
                                           tlp_is_cfg_rd      ? E_NP_REQ_TX_CFG_RD :
                                           tlp_is_cfg_wr      ? E_NP_REQ_TX_CFG_WR :
                                           tlp_is_io_rd       ? E_NP_REQ_TX_IO_RD :
                                           tlp_is_io_wr       ? E_NP_REQ_TX_IO_WR :
                                           E_NP_REQ_TX_MEMRD_NON_ATS;
  o_xadm_pkt.support.p_req_type        =   tlp_is_mem_wr      ? E_P_REQ_TX_MEMWR : E_P_REQ_TX_MSG;
  o_xadm_pkt.support.cpl_type          = ({tlp_hdr_pkt_frm.tlp_fmt, tlp_hdr_pkt_frm.tlp_type} == `CPL) ? E_CPL_TX_CPL : E_CPL_TX_CPLD;

  o_xadm_pkt.support.len_dw            = tlp_hdr_passthrough ? i_xaim_pkt.tlp_hdr_pkt.tlp_len : tlp_hdr_pkt_frm.tlp_len;
  o_xadm_pkt.support.has_payload       = tlp_hdr_decode_pre_frm.payload;
  o_xadm_pkt.support.msg_is_ptm        = ((tlp_is_msg &                 (msgRoute == E_MR_LOCAL) & (tlp_hdr_pkt_frm.tlp_msg_code == `PTM_RES_TYPE)) | 
                                         ((tlp_is_msg & ~tlp_is_msgd) & (msgRoute == E_MR_LOCAL) & (tlp_hdr_pkt_frm.tlp_msg_code == `PTM_REQ_TYPE)));
  o_xadm_pkt.support.msg_is_pme_to_ack = port_msg ? (tlp_hdr_pkt_frm.tlp_msg_code == `PME_TO_ACK ) : 0;
  o_xadm_pkt.support.msg_is_ltr        = (( tlp_hdr_pkt_frm.tlp_msg_code == `LTR_MSG_CODE ) && (tlp_is_msg & ~tlp_is_msgd) && (msgRoute == E_MR_LOCAL));
  
end

///////////////////////////////////////////
// TLP Reformatting Functions 
///////////////////////////////////////////
function automatic [NW-1:0] f_dw_decode (
  input [LEN_OFFSET_WIDTH-1:0] len
);
  begin
    f_dw_decode = {NW{1'b0}} ;

      for (int i=0; i<NW; i++) begin
        if ( (len == 0) || (i < len) )
          f_dw_decode[i] = 1'b1;
        else
          f_dw_decode[i] = 1'b0;
      end
    //f_dw_decode = l_decode[NW-1:0];
  end
endfunction // f_dw_decode

function automatic f_get_ecrc_en (
  input    [NF-1:0] cfg_ecrc_gen_en,
  input [NF_WD-1:0] tlp_func_num
);
  begin
    f_get_ecrc_en = '0;
    for (int i=0; i<NF; i++) begin
      if (i == tlp_func_num)
        f_get_ecrc_en = cfg_ecrc_gen_en[i];
    end
  end
endfunction // f_get_ecrc_en

function automatic logic [9:0] f_calc_len (
  input mode_e         mode,
  input xaim_pkt_t     xaim_pkt,
  input tlp_hdr_decode_s tlp_hdr_decode
);
  begin
    logic [`SF_HDR_TLP_BYTE_LEN-1:0] tlp_byte_len;
    logic                            lenIncr;
    //tlp_byte_len = {xaim_pkt.tlp_hdr_pkt.tlp_len,xaim_pkt.tlp_byte_len[1:0]};
    tlp_byte_len = xaim_pkt.tlp_byte_len;
    //lenIncr    = `ifdef CX_HEADER_PASS_THROUGH xaim_pkt.tlp_hdr_pt `else 1'b0 `endif & xaim_pkt.tlp_hdr_pkt.tlp_td;
    lenIncr    = 1'b0;
    

    if (( ~tlp_hdr_decode.payload | tlp_byte_len[12] ) & ( tlp_hdr_decode.fc_type == E_CPL | tlp_hdr_decode.trans_type == E_MSG)) 
      f_calc_len = 10'd0 + lenIncr;
    else if ( tlp_hdr_decode.trans_type == E_CFGRD | tlp_hdr_decode.trans_type == E_IORD )
      f_calc_len = 10'd1;
    else if ( tlp_hdr_decode.trans_type == E_CFGWR | tlp_hdr_decode.trans_type == E_IOWR )
      f_calc_len = 10'd1 + lenIncr;
    else if ( xaim_pkt.tlp_byte_len == 0 )
      f_calc_len = 10'd1;
    else if ( tlp_hdr_decode.fc_type == E_CPL | tlp_hdr_decode.trans_type == E_MSG )
      f_calc_len = tlp_byte_len[11:2];
    else if ( ~xaim_pkt.addr_align_en )
      f_calc_len = tlp_byte_len[11:2];
    else
      f_calc_len = f_len_align ( mode, xaim_pkt ); // From some Function!!!!
  end
endfunction // f_calc_len

function automatic logic [9:0] f_len_align (
  input mode_e         mode,
  input xaim_pkt_t     xaim_pkt
);
  begin
    logic     [12:0] tlp_byte_len;
    logic      [2:0] dw_offset;
    logic      [1:0] extra_dw;
    logic     [10:0] num_of_dw;
    tlp_byte_len = f_len_w_ecrc(mode, xaim_pkt);

    f_len_align = |tlp_byte_len ? (|tlp_byte_len[1:0] ? (tlp_byte_len[11:2] + 1'b1) : tlp_byte_len[11:2] ) : 'd1;
  end
endfunction // f_len_align

///////////////////////////////////////////
// Len with ECRC Enabled
///////////////////////////////////////////
function automatic logic [12:0] f_len_w_ecrc (
  input  mode_e     mode,
  input  xaim_pkt_t xaim_pkt
);
  begin
    logic [12:0] tlp_byte_len;
    logic tlp_is_mem_rd;
    tlp_byte_len  = '0;
    tlp_byte_len  = (13)'({xaim_pkt.tlp_hdr_pkt.tlp_len, xaim_pkt.tlp_byte_len[1:0]}); // DW Length + Bytes!
    f_len_w_ecrc  = tlp_byte_len;
  end
endfunction // f_len_w_ecrc

///////////////////////////////////////////
// First Data Word Calculation
///////////////////////////////////////////
function automatic logic [3:0] f_tlp_fdw_be_calc (
  input  xaim_pkt_t xaim_pkt
);
  begin
    logic len_non_zero = |xaim_pkt.tlp_hdr_pkt.tlp_len;
    casez({xaim_pkt.tlp_hdr_pkt.tlp_addr[1:0],xaim_pkt.tlp_byte_len[1:0]})
      4'b0000 : f_tlp_fdw_be_calc = len_non_zero ? 4'b1111 : 4'b0000;
      // ccx_line_cond_begin: ; Redundant code for configs where GLOB_ADDR_ALIGN_EN = 0 because the core does not support address alignment and does not generate the first and last byte enables (FBE, LBE) based on the address and number of bytes of the TLP requested from the client interface
      4'b0001 : f_tlp_fdw_be_calc = len_non_zero ? 4'b1111 : 4'b0001;
      4'b0010 : f_tlp_fdw_be_calc = len_non_zero ? 4'b1111 : 4'b0011;
      4'b0011 : f_tlp_fdw_be_calc = len_non_zero ? 4'b1111 : 4'b0111;
      // ccx_line_cond_end
      4'b0100 : f_tlp_fdw_be_calc = len_non_zero ? 4'b1110 : 4'b0000;
      // ccx_line_cond_begin: ; Redundant code for configs where GLOB_ADDR_ALIGN_EN = 0
      4'b0101 : f_tlp_fdw_be_calc = len_non_zero ? 4'b1110 : 4'b0010;
      4'b0110 : f_tlp_fdw_be_calc = len_non_zero ? 4'b1110 : 4'b0110;
      4'b0111 : f_tlp_fdw_be_calc = 4'b1110;
      // ccx_line_cond_end
      4'b1000 : f_tlp_fdw_be_calc = len_non_zero ? 4'b1100 : 4'b0000;
      // ccx_line_cond_begin: ; Redundant code for configs where GLOB_ADDR_ALIGN_EN = 0
      4'b1001 : f_tlp_fdw_be_calc = len_non_zero ? 4'b1100 : 4'b0100;
      4'b101? : f_tlp_fdw_be_calc = 4'b1100;
      // ccx_line_cond_end
      4'b1100 : f_tlp_fdw_be_calc = len_non_zero ? 4'b1000 : 4'b0000;
      // ccx_line_begin: ; Redundant code for configs where GLOB_ADDR_ALIGN_EN = 0
      4'b1101 : f_tlp_fdw_be_calc = 4'b1000;
      4'b111? : f_tlp_fdw_be_calc = 4'b1000;
      // ccx_line_end
    endcase
  end
endfunction // f_tlp_fdw_be_calc

///////////////////////////////////////////
// Last Data Word Calculation
///////////////////////////////////////////
function automatic logic [3:0] f_tlp_ldw_be_calc (
  input mode_e      mode,
  input logic [9:0] len_align,
  input xaim_pkt_t  xaim_pkt
);
  begin
    f_tlp_ldw_be_calc = 4'b0000;
  end
endfunction // f_tlp_ldw_be_calc

///////////////////////////////////////////
// Get Request ID from BDF
///////////////////////////////////////////
function automatic logic [15:0] f_req_id_from_bdf (
  input logic [BUSNUM_WD-1:0] tlp_bn,
  input logic [DEVNUM_WD-1:0] tlp_dn,
  input logic     [PF_WD-1:0] tlp_fn,
  input cdm_xaim_cfg_t        cdm_xaim_cfg,
  input xali_xaim_cfg_t       xali_xaim_cfg
);

  logic [7:0] int_bus_num;
  logic [4:0] int_dev_num;
  logic [7:0] int_func_num;

  int_bus_num  = tlp_bn;
  int_dev_num  = tlp_dn;
  int_func_num = (8)'(tlp_fn);

  f_req_id_from_bdf = {int_bus_num, int_dev_num, int_func_num[2:0]};
endfunction // f_req_id_from_bdf

function automatic logic f_tlp_prfx_is_e2e_ohce (
  input logic [7:0] prfx_type
);                           // E2E Prefix
  f_tlp_prfx_is_e2e_ohce   = (prfx_type[7:4] == 4'b1001) & (|prfx_type[3:2] | (prfx_type[3:0] == 4'b0011));
endfunction // f_tlp_prfx_is_e2e_ohce

endmodule
