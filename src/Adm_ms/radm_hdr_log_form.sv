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
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_hdr_log_form.sv#4 $
// -------------------------------------------------------------------------
// ----------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
//  This module reconstructs header again to get it transmitted to AER Capability Structure
// ----------------------------------------------------------------------------
`include "DWC_pcie_ctl_pkg.svh"
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Adm_ms/xaim_ms_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"
`include "products/pcie_pkg.svh"

module radm_hdr_log_form
import xaim_ms_pkg::*;

  ///////////////////////////////////////// 
  //import radm_ms_pkg starts
  import radm_ms_pkg::CX_MAX_HDR_LOG_SZ;
  import radm_ms_pkg::FLT_Q_ADDR_WIDTH;
  import radm_ms_pkg::flt_hdr_s;
  import radm_ms_pkg::radm_hdr_dec_com_ohc_decx_present_s;
  import radm_ms_pkg::radm_hdr_log_rcvd_flds_s ;
  import radm_ms_pkg::little_end_hdr_prfx;
  import radm_ms_pkg::e2e_prfx_log_in;
  //import radm_ms_pkg ends
  //////////////////////////////////////////

  //////////////////////////////////////////
  //import DWC_pcie_ctl_pkg starts
  import DWC_pcie_ctl_pkg::NW_PRFX;
  import DWC_pcie_ctl_pkg::NF;
  //import DWC_pcie_ctl_pkg ends
  /////////////////////////////////////

  /////////////////////////////////////
  //import pcie_pkg starts 
  import pcie_pkg::decoded_tlp_type_s ;
  import pcie_pkg::f_decode_ohc_len; 
  import pcie_pkg::f_decode_tlp_type ;
  //import pcie_pkg ends
  ////////////////////////////////////

  ///////////////////////////////////
  //import pcie_pkg starts 

  import pcie_pkg::mode_e;
  //importing enum values of mode_e datatype
  import pcie_pkg::E_NFM;
  import pcie_pkg::E_FM;
  import pcie_pkg::addr_size_e;
  //importing all used enum_values of addr_size_e
  import pcie_pkg::E_ADDR32;
  import pcie_pkg::E_ADDR64;
  import pcie_pkg::prfx_type_e;
  //importing all used enum values of prfx_type_e
  import pcie_pkg::E_TLP_PRFX_RESERVED;
  import pcie_pkg::E_TLP_E2E_PRFX_TPH;
  import pcie_pkg::E_TLP_E2E_PRFX_PASID;
  import pcie_pkg::E_TLP_E2E_PRFX_IDE;
  import pcie_pkg::msg_route_e;
  //importing all used enum values of msg_route_e
  import pcie_pkg::E_MR_TO_RC;
  import pcie_pkg::E_MR_BY_ADDR;
  import pcie_pkg::E_MR_BY_ID;
  import pcie_pkg::tlp_hdr_pkt_s;
  import pcie_pkg::tlp_hdr_decode_s;
  //importing all used values of tlp_hdr_decode_s
  import pcie_pkg::E_CPL;
  //importing all used values of trans_type_e
  import pcie_pkg::E_MRD;
  import pcie_pkg::E_MWR;
  import pcie_pkg::E_DMWR;
  import pcie_pkg::E_IORD;
  import pcie_pkg::E_IOWR;
  import pcie_pkg::E_CFGRD;
  import pcie_pkg::E_CFGWR;
  import pcie_pkg::E_MSG;
  import pcie_pkg::f_tlp_prfx_is_e2e;
  import pcie_pkg::f_tlp_is_cpl;
  import pcie_pkg::f_tlp_is_cpld;
  import pcie_pkg::f_tlp_is_iord;
  import pcie_pkg::f_tlp_is_iowr;
  import pcie_pkg::f_tlp_is_io;
  import pcie_pkg::f_tlp_is_cfgrd;
  import pcie_pkg::f_tlp_is_cfgwr;
  import pcie_pkg::f_tlp_is_cfg;
  import pcie_pkg::f_tlp_is_msg;
  import pcie_pkg::f_tlp_is_msgd;
  import pcie_pkg::f_tlp_is_atomic;
  import pcie_pkg::f_tlp_addr_size;
  import pcie_pkg::f_tlp_msg_routing;
  import pcie_pkg::f_tlp_hdr_decode;
  import pcie_pkg::f_tlp_prfx_is_local;
  import pcie_pkg::f_tlp_prfx_decode;

  //import pcie_pkg ends
  ////////////////////////////////////////////


 
                        (
   input  logic                                     flit_mode,
   input  logic [2*NF-1:0]                          cfg_max_end2end_tlp_prfxs,
   input  flt_hdr_s                                 flt_hdr,
   //----- Outputs -----//  
   output logic [$clog2(CX_MAX_HDR_LOG_SZ+1)-1:0]   log_hdr_size,
   output logic [32*CX_MAX_HDR_LOG_SZ-1:0]          log_hdr_prfx   
);

// Local Param Defines
localparam OHC_A  = 0;
localparam OHC_B  = 1;
localparam OHC_C  = 2;
localparam OHC_E1 = 3;
localparam OHC_E2 = 4;
localparam OHC_E3 = 5;
localparam OHC_E4 = 6;
localparam  NW_PRFX_E2E                = `CX_MAX_END2END_TLP_PRFXS_VALUE ;
localparam  CX_MAX_HDR_LOG_PW          = $clog2(CX_MAX_HDR_LOG_SZ+1) ;
///////////////////////////////////////////
// Configuration
///////////////////////////////////////////
mode_e MODE;

assign MODE = mode_e'(flit_mode);

///////////////////////////////////////////
// Hdr/Data Dwen Calculation
///////////////////////////////////////////
// flt_hdr_s to tlp_hdr_pkt_s
//tlp_hdr_pkt_s       tlp_hdr_pkt ; // to be assigned to flt_hdr

tlp_hdr_pkt_s tlp_hdr_pkt_frm;   // Newly Formed, modified packet used to populate fields
decoded_tlp_type_s decoded_tlp_int ;
logic [3:0] hdr_dw_cnt;
assign decoded_tlp_int = f_decode_tlp_type({tlp_hdr_pkt_frm.tlp_fmt,tlp_hdr_pkt_frm.tlp_type}, 1'b0 || flit_mode ) ;

assign hdr_dw_cnt =  decoded_tlp_int.hdr_base_len + ((MODE == E_FM) ? f_decode_ohc_len(tlp_hdr_pkt_frm.tlp_ohc) : 0) ;
///////////////////////////////////////////
// TLP Prefix Decode Logic
///////////////////////////////////////////
logic                 [2:0] prfx_dw_cnt;
logic                 [7:0] prfx_type;
prfx_type_e   [NW_PRFX-1:0] prfx_type_decode;
logic         [NW_PRFX-1:0] tlp_prfx_is_local;
logic         [NW_PRFX-1:0] tlp_prfx_is_e2e;
logic         [NW_PRFX-1:0] tlp_prfx_total;
logic         [NW_PRFX-1:0] tlp_prfx_is_ide;
logic         [NW_PRFX-1:0] tlp_prfx_is_ohc_e;
logic          [3:0] [31:0] tlp_prfx_e2e;
logic          [7:0] [31:0] tlp_prfx_extract;

always_comb begin
  prfx_dw_cnt       = '0;
  prfx_type_decode  = prfx_type_e'(0);
  tlp_prfx_is_local = '0;
  tlp_prfx_is_e2e   = '0;
  tlp_prfx_is_ide   = '0;
  tlp_prfx_extract  = '0;
  for (int i=0; i<NW_PRFX; i++) begin
    prfx_type            = flt_hdr.flt_q_prfx[i*32+7-:8];               // Extract byte0
    prfx_type_decode[i]  = f_tlp_prfx_decode      (prfx_type);          // Decode the Prefix Types
    tlp_prfx_is_local[i] = f_tlp_prfx_is_local    (prfx_type);          // Local TLP Prefix Types
    tlp_prfx_is_e2e[i]   = f_tlp_prfx_is_e2e      (prfx_type);          // End-to-End TLP Prefix Types
    tlp_prfx_total[i]    = tlp_prfx_is_local[i] | tlp_prfx_is_e2e[i];   // Total No of Prefixes
    tlp_prfx_is_ide[i]   = (prfx_type_decode[i] == E_TLP_E2E_PRFX_IDE); // Decode Prefix is IDE
    tlp_prfx_is_ohc_e[i] = f_tlp_prfx_is_e2e_ohce (prfx_type);          // Prefix to be sent in OHCE

    if ((( MODE == E_NFM ) & tlp_prfx_is_e2e[i])) begin
      tlp_prfx_extract[prfx_dw_cnt] = flt_hdr.flt_q_prfx[i*32+31 -: 32];
      prfx_dw_cnt = prfx_dw_cnt + 1'b1;
    end
  end
end

///////////////////////////////////////////
// TLP Header Decode Logic
///////////////////////////////////////////
tlp_hdr_decode_s tlp_hdr_decode_pre_frm;  assign tlp_hdr_decode_pre_frm  = f_tlp_hdr_decode(MODE, tlp_hdr_pkt_frm);

addr_size_e addr_size;           assign addr_size           = f_tlp_addr_size   (MODE, tlp_hdr_pkt_frm);
logic       tlp_is_mem;          assign tlp_is_mem          = (tlp_hdr_decode_pre_frm.trans_type == E_MRD) | (tlp_hdr_decode_pre_frm.trans_type == E_MWR) | (tlp_hdr_decode_pre_frm.trans_type == E_DMWR);
logic       tlp_is_mem_rd;       assign tlp_is_mem_rd       = (tlp_hdr_decode_pre_frm.trans_type == E_MRD);
logic       tlp_is_mem_wr;       assign tlp_is_mem_wr       = (tlp_hdr_decode_pre_frm.trans_type == E_MWR);
logic       tlp_is_def_mem_wr;   assign tlp_is_def_mem_wr   = (tlp_hdr_decode_pre_frm.trans_type == E_DMWR);
logic       tlp_is_atomic;       assign tlp_is_atomic       = f_tlp_is_atomic   (MODE, tlp_hdr_pkt_frm);
msg_route_e msgRoute;            assign msgRoute            = f_tlp_msg_routing (MODE, tlp_hdr_pkt_frm);
logic       tlp_is_at_trans_req; assign tlp_is_at_trans_req = ((tlp_hdr_decode_pre_frm.trans_type == E_MRD) &  (tlp_hdr_pkt_frm.tlp_at == `DC_AT_TRANS_REQ));
logic       tlp_is_io;           assign tlp_is_io           = f_tlp_is_io       (MODE, tlp_hdr_pkt_frm);
logic       tlp_is_io_rd;        assign tlp_is_io_rd        = f_tlp_is_iord     (MODE, tlp_hdr_pkt_frm);
logic       tlp_is_io_wr;        assign tlp_is_io_wr        = f_tlp_is_iowr     (MODE, tlp_hdr_pkt_frm);
logic       tlp_is_cfg;          assign tlp_is_cfg          = f_tlp_is_cfg      (MODE, tlp_hdr_pkt_frm);
logic       tlp_is_cfg_rd;       assign tlp_is_cfg_rd       = f_tlp_is_cfgrd    (MODE, tlp_hdr_pkt_frm);
logic       tlp_is_cfg_wr;       assign tlp_is_cfg_wr       = f_tlp_is_cfgwr    (MODE, tlp_hdr_pkt_frm);
logic       tlp_is_cpl;          assign tlp_is_cpl          = f_tlp_is_cpl      (MODE, tlp_hdr_pkt_frm);
logic       tlp_is_cpld;         assign tlp_is_cpld         = f_tlp_is_cpld     (MODE, tlp_hdr_pkt_frm);
logic       tlp_is_msg;          assign tlp_is_msg          = f_tlp_is_msg      (MODE, tlp_hdr_pkt_frm);
logic       tlp_is_msgd;         assign tlp_is_msgd         = f_tlp_is_msgd     (MODE, tlp_hdr_pkt_frm);

///////////////////////////////////////////
// Incoming TLP Reformat
///////////////////////////////////////////
logic       dw0_B1_b7;
logic       dw0_B1_b3;
logic [3:0] dw2_B10_b7_4;
logic       dw2_B11_b7;
logic [4:0] ohc_a_present;
logic       ohc_b_present;
logic       ohc_c_present;
logic [2:0] ohc_e_present;
logic [1:0] ohc_e_cnt;

logic       rcvd_ohc_a_present;
logic       rcvd_ohc_b_present;
logic       rcvd_ohc_c_present;

assign rcvd_ohc_a_present = flt_hdr.log_rcvd_flds.ohc_decx_present.ohc_dec_a_present ;
assign rcvd_ohc_b_present = flt_hdr.log_rcvd_flds.ohc_decx_present.ohc_dec_b_present ;
assign rcvd_ohc_c_present = flt_hdr.log_rcvd_flds.ohc_decx_present.ohc_dec_c_present ;

always_comb begin
  tlp_hdr_pkt_frm                                 = '0 ;
  {tlp_hdr_pkt_frm.tlp_fmt[2:0],tlp_hdr_pkt_frm.tlp_type} = ({flt_hdr.flt_q_fmt, flt_hdr.flt_q_type}==`MRD32) && flit_mode? {flt_hdr.flt_q_fmt2,`FLIT_MRD32}:{flt_hdr.flt_q_fmt2,flt_hdr.flt_q_fmt, flt_hdr.flt_q_type} ;
  tlp_hdr_pkt_frm.tlp_tc                          = flt_hdr.flt_q_tc ; // 3-bit width // Set with different defines but both with constant width (3 bits)
  tlp_hdr_pkt_frm.tlp_th                          = flt_hdr.flt_q_th ; // 1-bit width if CX_TPH_ENABLED is defined
  tlp_hdr_pkt_frm.tlp_ph                          = flt_hdr.flt_q_ph ; // 2-bit width
  tlp_hdr_pkt_frm.tlp_st[7:0]                     = flt_hdr.flt_q_st ; // Check for that // 8 msbs of ST come from prefixes
  tlp_hdr_pkt_frm.tlp_attr[`FLT_Q_ATTR_WIDTH-1:0] = flt_hdr.flt_q_attr ; // 3-bit width for LHS and for RHS 3 bits if CX_IDO_ENABLE is defined and 2 bits otherwise
  tlp_hdr_pkt_frm.tlp_td                          = flt_hdr.flt_q_td_hdr_log   ;   // 1-bit width 
  tlp_hdr_pkt_frm.tlp_ep                          = flt_hdr.flt_q_poisoned ; // 1-bit width
  tlp_hdr_pkt_frm.tlp_len                         = flt_hdr.flt_q_dw_len ;   // 10-bit width
  tlp_hdr_pkt_frm.tlp_req_id                      = flt_hdr.flt_q_REQID ;    // 16-bit width
  tlp_hdr_pkt_frm.tlp_cpl_id                      = flt_hdr.flt_q_cplid ;    // 16-bit width
  tlp_hdr_pkt_frm.tlp_tag                         = flt_hdr.flt_q_TAG ;      // CX_TAG_SIZE - bit width for both
  tlp_hdr_pkt_frm.tlp_fdw_be                      = flt_hdr.flt_q_first_be ; // 4-bit width for both
  tlp_hdr_pkt_frm.tlp_ldw_be                      = flt_hdr.flt_q_last_be  ; // 4-bit width for both
  //tlp_hdr_pkt_frm.tlp_fn[`FLT_Q_FUNC_NMBR_WIDTH -1:0] = flt_hdr.flt_q_func_nmbr ;
  tlp_hdr_pkt_frm.tlp_addr[`FLT_Q_ADDR_WIDTH-1:`FLT_Q_CPL_LOWER_ADDR_WIDTH] = flt_hdr.flt_q_addr[`FLT_Q_ADDR_WIDTH-1:`FLT_Q_CPL_LOWER_ADDR_WIDTH] ;     // FLT_Q_ADDR_WIDTH-bit width for RHS and 64-bit width for LHS
  tlp_hdr_pkt_frm.tlp_addr[`FLT_Q_CPL_LOWER_ADDR_WIDTH-1:0] = tlp_is_cpl?flt_hdr.flt_q_cpl_lower_addr:flt_hdr.flt_q_addr[`FLT_Q_CPL_LOWER_ADDR_WIDTH-1:0]; // Putting Least 7 bits in Completion in consideration
  tlp_hdr_pkt_frm.tlp_cpl_status                  = flt_hdr.flt_q_cpl_status ; // 3-bit width for both
  tlp_hdr_pkt_frm.tlp_byte_count                  = flt_hdr.flt_q_byte_cnt ; // 12-bit width for both
  tlp_hdr_pkt_frm.tlp_bcm                         = flt_hdr.flt_q_cpl_bcm ;  // 1-bit width for both
  tlp_hdr_pkt_frm.tlp_nw                          = flt_hdr.flt_q_nw  ;      // 1-bit width for both
  tlp_hdr_pkt_frm.tlp_cxlsrc                      = flt_hdr.flt_q_cxlsrc ;   // 1-bit width for both
  tlp_hdr_pkt_frm.tlp_at                          = flt_hdr.flt_q_ats ;      // 2-bit width for both
  tlp_hdr_pkt_frm.tlp_dst_seg                     = flt_hdr.hdr_dec_flt_dest_seg[7:0] ;
  tlp_hdr_pkt_frm.tlp_dsv                         = flt_hdr.hdr_dec_flt_dest_seg[8] ;
  tlp_hdr_pkt_frm.tlp_cpl_seg                     = flt_hdr.hdr_dec_flt_cpltr_seg ;
  tlp_hdr_pkt_frm.tlp_req_seg                     = flt_hdr.hdr_dec_flt_reqtr_seg[7:0] ;
  tlp_hdr_pkt_frm.tlp_rsv                         = flt_hdr.hdr_dec_flt_reqtr_seg[8] ;
  tlp_hdr_pkt_frm.tlp_msg_code                    = {flt_hdr.flt_q_last_be,flt_hdr.flt_q_first_be}; // 8-bit width for both
  dw0_B1_b7    = '0;
  dw0_B1_b3    = '0;
  dw2_B10_b7_4 = '0;
  dw2_B11_b7   = '0;
  tlp_hdr_pkt_frm.tlp_sub_stream = 4'h7;
 
  // 1. Handle Reserved Header Bits
  if ( ~(tlp_is_mem_wr & tlp_hdr_pkt_frm.tlp_th) ) begin
      dw0_B1_b7    = tlp_hdr_pkt_frm.tlp_tag[9];
      dw0_B1_b3    = tlp_hdr_pkt_frm.tlp_tag[8];
  end


  // 2. Handle Destination ID/Ext Reg Num & Reg Num - Cfg Requests
  tlp_hdr_pkt_frm.tlp_dst_id      = flt_hdr.flt_q_addr[31:16]; // Need to know Dst ID stuff.. What is this?
  tlp_hdr_pkt_frm.tlp_ext_reg_num = flt_hdr.flt_q_addr[11:8];  // Need to know external Reg stuff
  tlp_hdr_pkt_frm.tlp_reg_num     = flt_hdr.flt_q_addr[7:2];


  // 3. Handle OHC Header Content  
  tlp_hdr_pkt_frm.tlp_ohc = {flt_hdr.log_rcvd_flds.ohc_uppr_43[1], flt_hdr.log_rcvd_flds.ohc_uppr_43[0], rcvd_ohc_c_present, rcvd_ohc_b_present, rcvd_ohc_a_present};

  tlp_hdr_pkt_frm.tlp_hv[0]     = tlp_hdr_pkt_frm.tlp_th;
  tlp_hdr_pkt_frm.tlp_hv[1]     = flt_hdr.log_rcvd_flds.hv_1;
  // 13. Extract E2E Prefix Info
  ohc_e_cnt    = '0;
  tlp_prfx_e2e = '0;
  for ( int i=0; i<NW_PRFX; i++) begin
    if ( prfx_type_decode[i] == E_TLP_E2E_PRFX_PASID ) begin
      tlp_hdr_pkt_frm.tlp_pasid = {flt_hdr.flt_q_prfx[i*32+11-:4], flt_hdr.flt_q_prfx[i*32+23-:8], flt_hdr.flt_q_prfx[i*32+31-:8]};
      tlp_hdr_pkt_frm.tlp_pmr   = flt_hdr.flt_q_prfx[i*32+15];
      tlp_hdr_pkt_frm.tlp_er    = flt_hdr.flt_q_prfx[i*32+14];
      tlp_hdr_pkt_frm.tlp_pv    = 1'b1;
    end else if ( prfx_type_decode[i] == E_TLP_E2E_PRFX_TPH ) begin
      tlp_hdr_pkt_frm.tlp_st[15:8]    = flt_hdr.flt_q_prfx[i*32+15-:8];  // Extract uppermost bits of steering tag.
      tlp_hdr_pkt_frm.tlp_ama         = flt_hdr.flt_q_prfx[i*32+23-:3];
      tlp_hdr_pkt_frm.tlp_av          = flt_hdr.flt_q_prfx[i*32+20];
    end else if ( prfx_type_decode[i] == E_TLP_E2E_PRFX_IDE ) begin
      tlp_hdr_pkt_frm.tlp_pr_sent_cnt = flt_hdr.flt_q_prfx[i*32+15-:8];
      tlp_hdr_pkt_frm.tlp_stream_id   = flt_hdr.flt_q_prfx[i*32+23-:8];
      tlp_hdr_pkt_frm.tlp_sub_stream  = flt_hdr.flt_q_prfx[i*32+31-:4];
      tlp_hdr_pkt_frm.tlp_p           = flt_hdr.flt_q_prfx[i*32+27];
      tlp_hdr_pkt_frm.tlp_m           = flt_hdr.flt_q_prfx[i*32+26];
      tlp_hdr_pkt_frm.tlp_k           = flt_hdr.flt_q_prfx[i*32+25];
      tlp_hdr_pkt_frm.tlp_t           = flt_hdr.flt_q_prfx[i*32+24];
    end else if ( tlp_prfx_is_ohc_e[i] ) begin
      tlp_prfx_e2e[ohc_e_cnt] = flt_hdr.flt_q_prfx[i*32+31-:32];
      ohc_e_cnt = ohc_e_cnt + 'd1;
    end
  end

  // 12. Handle Trailer Size
  tlp_hdr_pkt_frm.tlp_ts = flt_hdr.log_rcvd_flds.ts_field ;
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
assign ohc_a_present[0] = (( tlp_is_mem & (ohc_be_explicit | tlp_hdr_pkt_frm.tlp_pv | rcvd_ohc_a_present)) | ( tlp_is_atomic & (tlp_hdr_pkt_frm.tlp_pv | rcvd_ohc_a_present))                                                                          // OHC-A1
                           | ( tlp_is_at_trans_req & (tlp_hdr_pkt_frm.tlp_nw | tlp_hdr_pkt_frm.tlp_pv) ) | ( tlp_is_msg & ((msgRoute == E_MR_BY_ADDR) | (msgRoute == E_MR_TO_RC)) & tlp_hdr_pkt_frm.tlp_pv)); 
assign ohc_a_present[1] = (( tlp_hdr_decode_pre_frm.trans_type == E_IORD)  | ( tlp_hdr_decode_pre_frm.trans_type == E_IOWR));                                                                                                                                                              // OHC-A2
assign ohc_a_present[2] = (( tlp_hdr_decode_pre_frm.trans_type == E_CFGRD) | ( tlp_hdr_decode_pre_frm.trans_type == E_CFGWR));                                                                                                                                                             // OHC-A3
assign ohc_a_present[3] = ((tlp_is_msg & ( msgRoute == E_MR_BY_ID )) & (tlp_hdr_pkt_frm.tlp_pv | ( tlp_hdr_pkt_frm.tlp_dsv & ohc_dst_seg_required) | rcvd_ohc_a_present));                                                                                              // OHC-A4
assign ohc_a_present[4] = ((tlp_hdr_decode_pre_frm.fc_type == E_CPL) & (((tlp_hdr_pkt_frm.tlp_dsv & (tlp_hdr_pkt_frm.tlp_dst_seg != tlp_hdr_pkt_frm.tlp_cpl_seg)) | (|tlp_hdr_pkt_frm.tlp_cpl_status) | (|tlp_hdr_pkt_frm.tlp_addr[1:0])) | rcvd_ohc_a_present));   // OHC-A5
assign ohc_b_present    = rcvd_ohc_b_present;                                                                                                                                                                                                            // OHC-B
assign ohc_c_present    = |(tlp_prfx_is_ide) | (tlp_hdr_pkt_frm.tlp_rsv & tlp_is_msg) | ((tlp_is_mem | tlp_is_atomic) & ( tlp_hdr_pkt_frm.tlp_rsv & rcvd_ohc_c_present ));                                                                    // OHC-C
assign ohc_e_present[0] = (ohc_e_cnt == 3'd1) | 0;                                                                                                                                                                                                  // OHC-E1
assign ohc_e_present[1] = ((ohc_e_cnt == 3'd2) | (ohc_e_cnt == 3'd3)) | 0;                                                                                                                                                                          // OHC-E2
assign ohc_e_present[2] = (ohc_e_cnt == 3'd4) | 0;                                                                                                                                                                                                 // OHC-E4
///////////////////////////////////////////
// Format OHC Fields if required
///////////////////////////////////////////
assign ohc_be               = {tlp_hdr_pkt_frm.tlp_ldw_be, tlp_hdr_pkt_frm.tlp_fdw_be};
assign ohc_be_explicit      = ~(( &ohc_be & ( tlp_hdr_pkt_frm.tlp_len >= 2)) | ((ohc_be == 8'h0F) & (tlp_hdr_pkt_frm.tlp_len == 1)));
assign ohc_invalid_req      = ((tlp_is_msgd & ( msgRoute == E_MR_BY_ID )) & (tlp_hdr_pkt_frm.tlp_msg_code == `INVALIDATE_REQUEST));
assign ohc_invalid_cpl      = ((tlp_is_msg  & ( msgRoute == E_MR_BY_ID )) & (tlp_hdr_pkt_frm.tlp_msg_code == `INVALIDATE_COMPLETION));
assign ohc_prg_rsp          = ((tlp_is_msg  & ( msgRoute == E_MR_BY_ID )) & (tlp_hdr_pkt_frm.tlp_msg_code == `PRG_RES_TYPE));
assign ohc_dst_seg_required = (ohc_invalid_req | ohc_invalid_cpl | ohc_prg_rsp | (tlp_hdr_pkt_frm.tlp_dst_seg != tlp_hdr_pkt_frm.tlp_req_seg));

///////////////////////////////////////////
// TLP OHC-A Logic
///////////////////////////////////////////
logic  [7:0] tlp_ohc_a_dw_B0;
logic  [7:0] tlp_ohc_a_dw_B1;
logic  [7:0] tlp_ohc_a_dw_B2;
logic  [7:0] tlp_ohc_a_dw_B3;

always_comb begin
  tlp_ohc_a_dw_B0 = '0;
  tlp_ohc_a_dw_B1 = '0;
  tlp_ohc_a_dw_B2 = '0;
  tlp_ohc_a_dw_B3 = '0;  

  if ( ohc_a_present[0] ) begin
    tlp_ohc_a_dw_B0 = {tlp_hdr_pkt_frm.tlp_nw, tlp_hdr_pkt_frm.tlp_pv, tlp_hdr_pkt_frm.tlp_pmr, tlp_hdr_pkt_frm.tlp_er, tlp_hdr_pkt_frm.tlp_pasid[19:16]};
    tlp_ohc_a_dw_B1 = tlp_hdr_pkt_frm.tlp_pasid[15:8];
    tlp_ohc_a_dw_B2 = tlp_hdr_pkt_frm.tlp_pasid[7:0];
    tlp_ohc_a_dw_B3 = {tlp_hdr_pkt_frm.tlp_ldw_be, tlp_hdr_pkt_frm.tlp_fdw_be};
  end

  if ( ohc_a_present[1] ) begin
    tlp_ohc_a_dw_B3 = {tlp_hdr_pkt_frm.tlp_ldw_be, tlp_hdr_pkt_frm.tlp_fdw_be};
  end

  if ( ohc_a_present[2] ) begin
    tlp_ohc_a_dw_B0 = tlp_hdr_pkt_frm.tlp_dst_seg;
    tlp_ohc_a_dw_B2 = {tlp_hdr_pkt_frm.tlp_dsv, 7'h00};
    tlp_ohc_a_dw_B3 = {tlp_hdr_pkt_frm.tlp_ldw_be, tlp_hdr_pkt_frm.tlp_fdw_be};
  end

  if ( ohc_a_present[3] ) begin
    tlp_ohc_a_dw_B0 = tlp_hdr_pkt_frm.tlp_dst_seg;
    tlp_ohc_a_dw_B1 = tlp_hdr_pkt_frm.tlp_pasid[15:8];
    tlp_ohc_a_dw_B2 = {tlp_hdr_pkt_frm.tlp_dsv, tlp_hdr_pkt_frm.tlp_pv, 2'b00, tlp_hdr_pkt_frm.tlp_pasid[19:16]};
    tlp_ohc_a_dw_B3 = tlp_hdr_pkt_frm.tlp_pasid[7:0];
  end
 
  if ( ohc_a_present[4] ) begin
    tlp_ohc_a_dw_B0 = tlp_hdr_pkt_frm.tlp_dst_seg;
    tlp_ohc_a_dw_B1 = tlp_hdr_pkt_frm.tlp_cpl_seg;
    tlp_ohc_a_dw_B2 = {tlp_hdr_pkt_frm.tlp_dsv, 7'h00};
    tlp_ohc_a_dw_B3 = {3'h0, tlp_hdr_pkt_frm.tlp_addr[1:0], tlp_hdr_pkt_frm.tlp_cpl_status};
  end
end

assign tlp_ohc_dw[OHC_A] = {tlp_ohc_a_dw_B3, tlp_ohc_a_dw_B2, tlp_ohc_a_dw_B1, tlp_ohc_a_dw_B0};

///////////////////////////////////////////
// TLP OHC-B Logic
///////////////////////////////////////////
logic  [7:0] tlp_ohc_b_dw_B0;
logic  [7:0] tlp_ohc_b_dw_B1;
logic  [7:0] tlp_ohc_b_dw_B2;
logic  [7:0] tlp_ohc_b_dw_B3;

always_comb begin
  tlp_ohc_b_dw_B0 = '0;
  tlp_ohc_b_dw_B1 = '0;
  tlp_ohc_b_dw_B2 = '0;
  tlp_ohc_b_dw_B3 = '0;

  if ( ohc_b_present ) begin
    tlp_ohc_b_dw_B1 = tlp_hdr_pkt_frm.tlp_st[15:8];
    tlp_ohc_b_dw_B2 = tlp_hdr_pkt_frm.tlp_st[7:0];
    tlp_ohc_b_dw_B3 = {tlp_hdr_pkt_frm.tlp_ph, tlp_hdr_pkt_frm.tlp_hv, tlp_hdr_pkt_frm.tlp_ama, tlp_hdr_pkt_frm.tlp_av};
  end
end

assign tlp_ohc_dw[OHC_B] = {tlp_ohc_b_dw_B3, tlp_ohc_b_dw_B2, tlp_ohc_b_dw_B1, tlp_ohc_b_dw_B0};

///////////////////////////////////////////
// TLP OHC-C Logic
///////////////////////////////////////////
logic  [7:0] tlp_ohc_c_dw_B0;
logic  [7:0] tlp_ohc_c_dw_B1;
logic  [7:0] tlp_ohc_c_dw_B2;
logic  [7:0] tlp_ohc_c_dw_B3;

always_comb begin
  tlp_ohc_c_dw_B0 = '0;
  tlp_ohc_c_dw_B1 = '0;
  tlp_ohc_c_dw_B2 = '0;
  tlp_ohc_c_dw_B3 = '0;


  if ( ohc_c_present ) begin
    tlp_ohc_c_dw_B0 = tlp_hdr_pkt_frm.tlp_req_seg;
    tlp_ohc_c_dw_B1 = tlp_hdr_pkt_frm.tlp_pr_sent_cnt;
    tlp_ohc_c_dw_B2 = tlp_hdr_pkt_frm.tlp_stream_id;
    tlp_ohc_c_dw_B3 = {tlp_hdr_pkt_frm.tlp_sub_stream, tlp_hdr_pkt_frm.tlp_rsv, 1'b0, tlp_hdr_pkt_frm.tlp_k, tlp_hdr_pkt_frm.tlp_t};
  end
end

assign tlp_ohc_dw[OHC_C] = {tlp_ohc_c_dw_B3, tlp_ohc_c_dw_B2, tlp_ohc_c_dw_B1, tlp_ohc_c_dw_B0};

///////////////////////////////////////////
// TLP OHC-E Logic
///////////////////////////////////////////
assign tlp_ohc_dw[OHC_E1] = (|ohc_e_present)      ? {tlp_prfx_e2e[0][31:8], 4'b0001, tlp_prfx_e2e[0][3:0]} : 32'h0;
assign tlp_ohc_dw[OHC_E2] = (|ohc_e_present[2:1]) ? {tlp_prfx_e2e[1][31:8], 4'b0001, tlp_prfx_e2e[1][3:0]} : 32'h0;
assign tlp_ohc_dw[OHC_E3] = (ohc_e_present[2])    ? {tlp_prfx_e2e[2][31:8], 4'b0001, tlp_prfx_e2e[2][3:0]} : 32'h0;
assign tlp_ohc_dw[OHC_E4] = (ohc_e_present[2])    ? {tlp_prfx_e2e[3][31:8], 4'b0001, tlp_prfx_e2e[3][3:0]} : 32'h0;

///////////////////////////////////////////
// TLP OHC Mapping
///////////////////////////////////////////
logic       [3:0] tlp_ohc_base;
logic [6:0] [3:0] tlp_ohc_map;


always_comb begin
  tlp_ohc_map  = '0;
  tlp_ohc_base  = {{1{1'b0}},decoded_tlp_int.hdr_base_len} ;

  // Mapping for OHC-A
  if ( rcvd_ohc_a_present ) begin
    tlp_ohc_map[OHC_A] = tlp_ohc_base;
  end

  // Mapping for OHC-B
  if ( rcvd_ohc_b_present ) begin
    if ( |tlp_ohc_map[OHC_A] )
      tlp_ohc_map[OHC_B] = tlp_ohc_map[OHC_A] + 'd1;
    else
      tlp_ohc_map[OHC_B] = tlp_ohc_base;
  end

  // Mapping for OHC-C
  if ( rcvd_ohc_c_present ) begin
    if ( |tlp_ohc_map[OHC_B] )
      tlp_ohc_map[OHC_C] = tlp_ohc_map[OHC_B] + 'd1;
    else if ( |tlp_ohc_map[OHC_A] )
      tlp_ohc_map[OHC_C] = tlp_ohc_map[OHC_A] + 'd1;
    else
      tlp_ohc_map[OHC_C] = tlp_ohc_base;
  end

  // Mapping for OHC-E
  if ( |ohc_e_present ) begin
    if ( |tlp_ohc_map[OHC_C] )
      tlp_ohc_map[OHC_E1] = tlp_ohc_map[OHC_C] + 'd1;  // OHC-E1
    else if ( |tlp_ohc_map[OHC_B] )
      tlp_ohc_map[OHC_E1] = tlp_ohc_map[OHC_B] + 'd1;
    else if ( |tlp_ohc_map[OHC_A] )
      tlp_ohc_map[OHC_E1] = tlp_ohc_map[OHC_A] + 'd1;
    else
      tlp_ohc_map[OHC_E1] = tlp_ohc_base;

    if (|ohc_e_present[2:1])                           // OHC-E2
      tlp_ohc_map[OHC_E2] = tlp_ohc_map[OHC_E1] + 'd1;
    else if (ohc_e_present[2]) begin                   // OHC-E4
      tlp_ohc_map[OHC_E3] = tlp_ohc_map[OHC_E1] + 'd2;
      tlp_ohc_map[OHC_E4] = tlp_ohc_map[OHC_E1] + 'd3;
    end
  end
end


//////////////////////////////////
//   Overflow Prefix Handling   //
//////////////////////////////////
logic [1:0]   end2end_max_pf ;
logic [2:0]   end2end_max ;
logic [159:0] transformed_tlp_prfx ;
logic [31:0]  ovrflw_end_end_prfx ;

assign transformed_tlp_prfx  = e2e_prfx_log_in(tlp_prfx_extract);
//assign tlp_prfx_formed       = transformed_tlp_prfx[0+:CX_NE2E_PRFX_NFM] ;
//assign tlp_prfx_formed_extnd = {{256-160{1'b0}},transformed_tlp_prfx} ;

always_comb begin : end_2_end_max_prfxs
    integer i;
    end2end_max_pf = `CX_MAX_END2END_TLP_PRFXS; // @CX_NPRFX < 4 ? @CX_NPRFX : 0
    for(i = 0; i < NF; i = i + 1) begin
      if (i==flt_hdr.flt_q_func_nmbr) begin
        end2end_max_pf = {cfg_max_end2end_tlp_prfxs[(2*(i+1))-1], cfg_max_end2end_tlp_prfxs[2*i]};
      end
    end
end

 assign end2end_max     = end2end_max_pf == 2'b00 ? 3'h4 :
                          end2end_max_pf == 2'b01 ? 3'h1 :
                          end2end_max_pf == 2'b10 ? 3'h2 :
                          3'h3; 

assign ovrflw_end_end_prfx = end2end_max == 3'h1 ? transformed_tlp_prfx[63:32]   :         // overflow is 2nd end to end prefix
                             end2end_max == 3'h2 ? transformed_tlp_prfx[95:64]   :         // overflow is 3rd end to end prefix
                             end2end_max == 3'h3 ? transformed_tlp_prfx[127:96]  :         // overflow is 4th end to end prefix
                             end2end_max == 3'h4 ? transformed_tlp_prfx[159:128] :         // overflow is 5th end to end prefix
                             32'h0;

///////////////////////////////////////////
// TLP DW0 Logic
///////////////////////////////////////////
logic [CX_MAX_HDR_LOG_SZ-1:0] [31:0] tlp_hdr_dw;
logic [7:0]                          tlp_hdr_dw0_B0;
logic [7:0]                          tlp_hdr_dw0_B1;
logic [7:0]                          tlp_hdr_dw0_B2;
logic [7:0]                          tlp_hdr_dw0_B3;

always_comb begin
  tlp_hdr_dw0_B0 = '0;
  tlp_hdr_dw0_B1 = '0;
  tlp_hdr_dw0_B2 = '0;
  tlp_hdr_dw0_B3 = '0;
  if ( tlp_hdr_decode_pre_frm.mode == E_FM ) begin
    tlp_hdr_dw0_B0 = { tlp_hdr_pkt_frm.tlp_fmt, tlp_hdr_pkt_frm.tlp_type }; // Technically Type is a 8 bit field in FM // workaraound concatenate 1'b0 to the left // Technically width is DC_FMT_WD
    tlp_hdr_dw0_B1 = { tlp_hdr_pkt_frm.tlp_tc, tlp_hdr_pkt_frm.tlp_ohc};
    tlp_hdr_dw0_B2 = { tlp_hdr_pkt_frm.tlp_ts, tlp_hdr_pkt_frm.tlp_attr, tlp_hdr_pkt_frm.tlp_len[9:8] };
    tlp_hdr_dw0_B3 = tlp_hdr_pkt_frm.tlp_len[7:0];
  end else
  if ( tlp_hdr_decode_pre_frm.mode == E_NFM ) begin
    tlp_hdr_dw0_B0 = { tlp_hdr_pkt_frm.tlp_fmt, tlp_hdr_pkt_frm.tlp_type };
    tlp_hdr_dw0_B1 = { dw0_B1_b7, tlp_hdr_pkt_frm.tlp_tc, dw0_B1_b3, tlp_hdr_pkt_frm.tlp_attr[2], tlp_hdr_pkt_frm.tlp_ln, tlp_hdr_pkt_frm.tlp_th };
    tlp_hdr_dw0_B2 = { tlp_hdr_pkt_frm.tlp_td, tlp_hdr_pkt_frm.tlp_ep, tlp_hdr_pkt_frm.tlp_attr[1:0], tlp_hdr_pkt_frm.tlp_at, tlp_hdr_pkt_frm.tlp_len[9:8] };
    tlp_hdr_dw0_B3 = tlp_hdr_pkt_frm.tlp_len[7:0];
  end
end


///////////////////////////////////////////
// TLP DW1 Logic
///////////////////////////////////////////
logic [7:0] tlp_hdr_dw1_B4;
logic [7:0] tlp_hdr_dw1_B5;
logic [7:0] tlp_hdr_dw1_B6;
logic [7:0] tlp_hdr_dw1_B7;

always_comb begin
  tlp_hdr_dw1_B4 = tlp_hdr_pkt_frm.tlp_req_id[15:8];
  tlp_hdr_dw1_B6 = '0;
  tlp_hdr_dw1_B7 = '0;
  if ( tlp_is_cpl ) begin
    tlp_hdr_dw1_B4 = tlp_hdr_pkt_frm.tlp_cpl_id[15:8];
    tlp_hdr_dw1_B5 = tlp_hdr_pkt_frm.tlp_cpl_id[7:0];
  end else begin
    tlp_hdr_dw1_B4 = tlp_hdr_pkt_frm.tlp_req_id[15:8];
    tlp_hdr_dw1_B5 = tlp_hdr_pkt_frm.tlp_req_id[7:0];
  end
  if ( tlp_hdr_decode_pre_frm.mode == E_FM ) begin
    if ( tlp_is_cpl )
      tlp_hdr_dw1_B6 = {tlp_hdr_pkt_frm.tlp_ep, tlp_hdr_pkt_frm.tlp_addr[6], tlp_hdr_pkt_frm.tlp_tag[13:8]};
    else if ( tlp_is_msg )
      tlp_hdr_dw1_B6 = {tlp_hdr_pkt_frm.tlp_ep, tlp_hdr_pkt_frm.tlp_tag[6:0]};
    else
      tlp_hdr_dw1_B6 = {tlp_hdr_pkt_frm.tlp_ep, 1'b0, tlp_hdr_pkt_frm.tlp_tag[13:8]};

    if ( tlp_is_msg )
      tlp_hdr_dw1_B7 = tlp_hdr_pkt_frm.tlp_msg_code;
    else
      tlp_hdr_dw1_B7 = tlp_hdr_pkt_frm.tlp_tag[7:0];
  end else
  if ( tlp_hdr_decode_pre_frm.mode == E_NFM ) begin
    if ( tlp_hdr_decode_pre_frm.fc_type == E_CPL ) begin
      tlp_hdr_dw1_B6 = {tlp_hdr_pkt_frm.tlp_cpl_status, tlp_hdr_pkt_frm.tlp_bcm, tlp_hdr_pkt_frm.tlp_byte_count[11:8]};
    end else if ( tlp_is_mem_wr & tlp_hdr_pkt_frm.tlp_th ) begin
      tlp_hdr_dw1_B6 = tlp_hdr_pkt_frm.tlp_st[7:0];
    end else begin
      tlp_hdr_dw1_B6 = tlp_hdr_pkt_frm.tlp_tag[7:0];
    end

    if ( tlp_hdr_decode_pre_frm.fc_type == E_CPL ) begin
      tlp_hdr_dw1_B7 = tlp_hdr_pkt_frm.tlp_byte_count[7:0];
    end else if ( tlp_hdr_decode_pre_frm.trans_type == E_MSG ) begin
      tlp_hdr_dw1_B7 = tlp_hdr_pkt_frm.tlp_msg_code;
    end else if ( ( tlp_is_mem_rd | tlp_is_def_mem_wr | tlp_is_atomic ) & tlp_hdr_pkt_frm.tlp_th ) begin
      tlp_hdr_dw1_B7 = tlp_hdr_pkt_frm.tlp_st[7:0];
    end else begin
      tlp_hdr_dw1_B7 = {tlp_hdr_pkt_frm.tlp_ldw_be, tlp_hdr_pkt_frm.tlp_fdw_be};
    end
  end
end


///////////////////////////////////////////
// TLP DW2 Logic
///////////////////////////////////////////
logic [7:0] tlp_hdr_dw2_B8;
logic [7:0] tlp_hdr_dw2_B9;
logic [7:0] tlp_hdr_dw2_B10;
logic [7:0] tlp_hdr_dw2_B11;

always_comb begin
  if ( ( tlp_is_io | tlp_is_mem | tlp_is_atomic ) & ( addr_size == E_ADDR32) ) begin
    tlp_hdr_dw2_B8  = tlp_hdr_pkt_frm.tlp_addr[31:24];
    tlp_hdr_dw2_B9  = tlp_hdr_pkt_frm.tlp_addr[23:16];
    tlp_hdr_dw2_B10 = tlp_hdr_pkt_frm.tlp_addr[15:8];
    if ( tlp_hdr_decode_pre_frm.mode == E_FM ) begin
      if ( tlp_is_at_trans_req ) begin
        tlp_hdr_dw2_B11 = {tlp_hdr_pkt_frm.tlp_addr[7:4], tlp_hdr_pkt_frm.tlp_cxlsrc, tlp_hdr_pkt_frm.tlp_addr[2], tlp_hdr_pkt_frm.tlp_at};
      end else begin
        tlp_hdr_dw2_B11 = {tlp_hdr_pkt_frm.tlp_addr[7:2], tlp_hdr_pkt_frm.tlp_at};
      end
    end else
    if ( tlp_is_at_trans_req )
      tlp_hdr_dw2_B11 = {tlp_hdr_pkt_frm.tlp_addr[7:4], tlp_hdr_pkt_frm.tlp_cxlsrc, tlp_hdr_pkt_frm.tlp_addr[2:1], tlp_hdr_pkt_frm.tlp_nw};
    else if ( tlp_hdr_pkt_frm.tlp_th & ( tlp_is_atomic | tlp_is_mem_rd | tlp_is_mem_wr )) 
      tlp_hdr_dw2_B11 = {tlp_hdr_pkt_frm.tlp_addr[7:2], tlp_hdr_pkt_frm.tlp_ph};
    else
      tlp_hdr_dw2_B11 = {tlp_hdr_pkt_frm.tlp_addr[7:2], 2'b00};
  end else if ( tlp_is_cfg ) begin
    tlp_hdr_dw2_B8  = tlp_hdr_pkt_frm.tlp_dst_id[15:8];
    tlp_hdr_dw2_B9  = tlp_hdr_pkt_frm.tlp_dst_id[7:0];
    tlp_hdr_dw2_B10 = {dw2_B10_b7_4, tlp_hdr_pkt_frm.tlp_ext_reg_num};
    tlp_hdr_dw2_B11 = {tlp_hdr_pkt_frm.tlp_reg_num, 2'b00};
  end else if ( tlp_is_cpl & (tlp_hdr_decode_pre_frm.mode == E_FM) ) begin
    tlp_hdr_dw2_B8  = tlp_hdr_pkt_frm.tlp_req_id[15:8];
    tlp_hdr_dw2_B9  = tlp_hdr_pkt_frm.tlp_req_id[7:0];
    tlp_hdr_dw2_B10 = {tlp_hdr_pkt_frm.tlp_addr[5:2], tlp_hdr_pkt_frm.tlp_byte_count[11:8]};
    tlp_hdr_dw2_B11 = tlp_hdr_pkt_frm.tlp_byte_count[7:0];
  end else if ( tlp_is_cpl & (tlp_hdr_decode_pre_frm.mode == E_NFM)) begin
    tlp_hdr_dw2_B8  = tlp_hdr_pkt_frm.tlp_req_id[15:8];
    tlp_hdr_dw2_B9  = tlp_hdr_pkt_frm.tlp_req_id[7:0];
    tlp_hdr_dw2_B10 = tlp_hdr_pkt_frm.tlp_tag[7:0];
    tlp_hdr_dw2_B11 = {dw2_B11_b7, tlp_hdr_pkt_frm.tlp_addr[6:0]}; 
  end else begin
    tlp_hdr_dw2_B8  = tlp_hdr_pkt_frm.tlp_addr[63:56];
    tlp_hdr_dw2_B9  = tlp_hdr_pkt_frm.tlp_addr[55:48];
    tlp_hdr_dw2_B10 = tlp_hdr_pkt_frm.tlp_addr[47:40];
    tlp_hdr_dw2_B11 = tlp_hdr_pkt_frm.tlp_addr[39:32];
  end
end


///////////////////////////////////////////
// TLP DW3 Logic
///////////////////////////////////////////
logic [7:0] tlp_hdr_dw3_B12;
logic [7:0] tlp_hdr_dw3_B13;
logic [7:0] tlp_hdr_dw3_B14;
logic [7:0] tlp_hdr_dw3_B15;

always_comb begin
  tlp_hdr_dw3_B12 = '0;
  tlp_hdr_dw3_B13 = '0;
  tlp_hdr_dw3_B14 = '0;
  tlp_hdr_dw3_B15 = '0;

  if ( ( tlp_is_io | tlp_is_mem | tlp_is_atomic | tlp_is_msg | tlp_is_msgd ) & ( addr_size == E_ADDR64) ) begin // fix on the fly
    tlp_hdr_dw3_B12 = tlp_hdr_pkt_frm.tlp_addr[31:24];
    tlp_hdr_dw3_B13 = tlp_hdr_pkt_frm.tlp_addr[23:16];
    tlp_hdr_dw3_B14 = tlp_hdr_pkt_frm.tlp_addr[15:8];
    if ( tlp_is_msg ) begin
      tlp_hdr_dw3_B15 = tlp_hdr_pkt_frm.tlp_addr[7:0];
    end else if ( tlp_hdr_decode_pre_frm.mode == E_FM ) begin
      if ( tlp_is_at_trans_req ) begin
        tlp_hdr_dw3_B15 = {tlp_hdr_pkt_frm.tlp_addr[7:4], tlp_hdr_pkt_frm.tlp_cxlsrc, tlp_hdr_pkt_frm.tlp_addr[2], tlp_hdr_pkt_frm.tlp_at};
      end else begin 
        tlp_hdr_dw3_B15 = {tlp_hdr_pkt_frm.tlp_addr[7:2], tlp_hdr_pkt_frm.tlp_at};
      end
    end else if ( tlp_is_at_trans_req )
      tlp_hdr_dw3_B15 = {tlp_hdr_pkt_frm.tlp_addr[7:4], tlp_hdr_pkt_frm.tlp_cxlsrc, tlp_hdr_pkt_frm.tlp_addr[2:1], tlp_hdr_pkt_frm.tlp_nw};
    else if ( tlp_hdr_pkt_frm.tlp_th & ( tlp_is_atomic | tlp_is_mem_rd | tlp_is_mem_wr ))
      tlp_hdr_dw3_B15 = {tlp_hdr_pkt_frm.tlp_addr[7:2], tlp_hdr_pkt_frm.tlp_ph};
    else
      tlp_hdr_dw3_B15 = {tlp_hdr_pkt_frm.tlp_addr[7:2], 2'b00};
  end
  else if (tlp_is_msg | tlp_is_msgd) begin
      // Not to do a thing here
  end
    else if ( tlp_hdr_decode_pre_frm.mode == E_FM ) begin
    //{tlp_hdr_dw3_B15, tlp_hdr_dw3_B14, tlp_hdr_dw3_B13, tlp_hdr_dw3_B12} = f_mux_ohc_dw (4'd3, tlp_ohc_dw, tlp_ohc_map);
    for (int i=0; i<7; i++) begin
      if ( tlp_ohc_map[i] == 4'd3 )
        {tlp_hdr_dw3_B15, tlp_hdr_dw3_B14, tlp_hdr_dw3_B13, tlp_hdr_dw3_B12} = tlp_ohc_dw[i];
    end
  end
end


///////////////////////////////////////////
// TLP DW1-DW11 Logic
///////////////////////////////////////////
always_comb begin
  tlp_hdr_dw[0]  = |ovrflw_end_end_prfx? ovrflw_end_end_prfx : {tlp_hdr_dw0_B3, tlp_hdr_dw0_B2, tlp_hdr_dw0_B1, tlp_hdr_dw0_B0};
  tlp_hdr_dw[1] = {tlp_hdr_dw1_B7, tlp_hdr_dw1_B6, tlp_hdr_dw1_B5, tlp_hdr_dw1_B4};
  tlp_hdr_dw[2] = {tlp_hdr_dw2_B11, tlp_hdr_dw2_B10, tlp_hdr_dw2_B9, tlp_hdr_dw2_B8};
  tlp_hdr_dw[3] = {tlp_hdr_dw3_B15, tlp_hdr_dw3_B14, tlp_hdr_dw3_B13, tlp_hdr_dw3_B12};
  for (int i=4; i<CX_MAX_HDR_LOG_SZ; i++) begin
    tlp_hdr_dw[i] = '0;
    if ( tlp_hdr_decode_pre_frm.mode == E_FM ) begin
      //tlp_hdr_dw[i] = f_mux_ohc_dw (i, tlp_ohc_dw, tlp_ohc_map);
      for (int j=0; j<7; j++) begin
        if ( tlp_ohc_map[j] == (4)'(i) )
          tlp_hdr_dw[i] = tlp_ohc_dw[j];
      end
    end else
    if ( tlp_hdr_decode_pre_frm.mode == E_NFM ) begin
      tlp_hdr_dw[i] = '0;
    end
  end
end

logic [CX_MAX_HDR_LOG_SZ-1:0] [31:0] tlp_prfx_hdr_dw;

///////////////////////////////////////////
// Merge Prefix and Header
///////////////////////////////////////////
logic [2:0] e2e_prfx_dw_cnt ;
assign e2e_prfx_dw_cnt = flit_mode? '0: (3)'(NW_PRFX_E2E) ;
always_comb begin
  tlp_prfx_hdr_dw = '0;
  for (int i=0; i<CX_MAX_HDR_LOG_SZ; i++) begin
    if (i < e2e_prfx_dw_cnt )                    // Hardstop placed here on the NW_PRFX to fix spyglass issues
      tlp_prfx_hdr_dw[i] = tlp_prfx_extract[i];
    else if ( i < CX_MAX_HDR_LOG_SZ)
      tlp_prfx_hdr_dw[i] = tlp_hdr_dw[i-e2e_prfx_dw_cnt];
  end
end

assign log_hdr_prfx = little_end_hdr_prfx(tlp_prfx_hdr_dw) ;

assign log_hdr_size  = flit_mode? (hdr_dw_cnt>CX_MAX_HDR_LOG_SZ?CX_MAX_HDR_LOG_SZ:CX_MAX_HDR_LOG_PW'(hdr_dw_cnt)) : 'h4 ;

///////////////////////////////////////////
// TLP Reformatting Functions 
///////////////////////////////////////////

/*`ifdef CX_FLIT_MODE_ENABLE
function automatic logic [2:0] f_no_ohcs (
  input logic          [4:0] tlp_ohc
);
  logic [2:0] cnt; cnt = 0;
  if (tlp_ohc[0]) cnt = cnt + 1'b1; // OHC-A
  if (tlp_ohc[1]) cnt = cnt + 1'b1; // OHC-B
  if (tlp_ohc[2]) cnt = cnt + 1'b1; // OHC-C
  case(tlp_ohc[4:3])
    2'b00 : cnt = cnt;
    2'b01 : cnt = cnt + 3'd1;       // OHC-E1
    2'b10 : cnt = cnt + 3'd2;       // OHC-E2
    2'b11 : cnt = cnt + 3'd4;       // OHC-E4
  endcase
  f_no_ohcs = cnt;
endfunction // f_no_ohcs
`endif // CX_FLIT_MODE_ENABLE
*/
function automatic logic f_tlp_prfx_is_e2e_ohce (
  input logic [7:0] prfx_type
);                           // E2E Prefix
  f_tlp_prfx_is_e2e_ohce   = (prfx_type[7:4] == 4'b1001) & (|prfx_type[3:2] | (prfx_type[3:0] == 4'b0011));
endfunction // f_tlp_prfx_is_e2e_ohce







endmodule
