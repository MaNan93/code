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
// ---    $DateTime: 2024/01/26 07:16:49 $
// ---    $Revision: #19 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_filter_p.sv#19 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
//  1. process and disassemble received p (includes msg tlps)
//  3. determine supported/unsupported requests.
//  4. provide data steering control for received tlp's (flt_q_destination)
//  5. detect tlp error conditions  and generate error signaling
//  6. provide error logging strobe/header.
//  7. Intercept decode message tlps, and signal CDM
//  9. multi-function supported
// -----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"
`include "products/pcie_pkg.svh"


module radm_filter_p
  import pcie_pkg::mode_e;
  import pcie_pkg::tlp_hdr_pkt_s;
  import pcie_pkg::f_tlp_is_fm_p_rsvd;
  import pcie_pkg::E_P;

  import radm_ms_pkg::DATA_PAR_WD;                // data bus parity width
  import radm_ms_pkg::FLT_NUM;
  import radm_ms_pkg::TRGT1_ADDR_WD;
  import radm_ms_pkg::PKT_ORD_WD;
  import radm_ms_pkg::HW_NFT;
  import radm_ms_pkg::HW_NFT_PAR;
  import radm_ms_pkg::ATU_IN_MIN1;
  import radm_ms_pkg::FILTER_DEMUX_TRGT1_CKH_CNTS;
  import radm_ms_pkg::FILTER_CHK_CNTS;
  import radm_ms_pkg::FLT_OUT_PROT_WD;
  import radm_ms_pkg::HEW;
  import radm_ms_pkg::P_TYPE;
  import radm_ms_pkg::CPL_TYPE;
  import radm_ms_pkg::RAS_STAT_WD;
  import radm_ms_pkg::FLT_Q_ADDR_WIDTH;
  import radm_ms_pkg::CX_ELBI_NW;
  import radm_ms_pkg::ERROR_LOG_PIPE_DELAY;
  import radm_ms_pkg::FLT_Q_PIPE_DELAY;
  import radm_ms_pkg::hdr_destination;
  import radm_ms_pkg::hdr_fmt;
  import radm_ms_pkg::radm_flt_atu_s;
  import radm_ms_pkg::ATU_IPIPE_PROT_WD ; 
  import radm_ms_pkg::radm_cfg_i_s;
  import radm_ms_pkg::radm_cfg_tlp_i_s;
  import radm_ms_pkg::radm_cfg_tlp_o_s;
  import radm_ms_pkg::radm_ord_mgr_flt_data_s;
  import radm_ms_pkg::radm_hdr_dec_com_ohc_decx_present_s;
  import radm_ms_pkg::radm_hdr_dec_flt_s;
  import radm_ms_pkg::flt_q_dmux_o_s;
  import radm_ms_pkg::flt_p_hdr_s;
  import radm_ms_pkg::FLT_P_HDR_WIDTH;       
  import radm_ms_pkg::FLT_P_HDR_PROT_WIDTH;
  import radm_ms_pkg::flt_data_o_s;
  import radm_ms_pkg::flt_p_hdr_o_s;
  import radm_ms_pkg::route_error_to_func;
  import radm_ms_pkg::get_pm_block;
  import radm_ms_pkg::radm_hdr_log_err_index;
  import radm_ms_pkg::radm_hdr_log_rcvd_flds_s ;
  import radm_ms_pkg::get_bar_num;
  import radm_ms_pkg:: pcie_max_pyld_err ;
  import radm_ms_pkg:: ctig_error;
  import radm_ms_pkg::get_tc_enable;
    import radm_ms_pkg::little_end_prfx;
  import radm_ms_pkg::int_mlf_msg_in_ep;
  import radm_ms_pkg::int_mlf_msg_in_rc;
  import radm_ms_pkg::e2e_prfx_log_in;
  import radm_ms_pkg::get_VC;
  import radm_ms_pkg::compressed_hdr_gen_ctl_s;
  import radm_ms_pkg::radm_tlp_hdr_s;

  import DWC_pcie_ctl_pkg::TP;
  import DWC_pcie_ctl_pkg::NW;
  import DWC_pcie_ctl_pkg::NVC;
  import DWC_pcie_ctl_pkg::NPRFX;
  import DWC_pcie_ctl_pkg::TAG_SIZE;
  import DWC_pcie_ctl_pkg::ATTR_WD;
  import DWC_pcie_ctl_pkg::DW;
  import DWC_pcie_ctl_pkg::PRFX_W_PAR;
  import DWC_pcie_ctl_pkg::NF;  
  import DWC_pcie_ctl_pkg::NVF;  
  import DWC_pcie_ctl_pkg::PF_WD;  
  import DWC_pcie_ctl_pkg::VF_WD; 
  import DWC_pcie_ctl_pkg::VFI_WD; 
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::ANTI_CTRL_PIPE_DELAY; 
  import DWC_pcie_ctl_pkg::PRFX_PROT_WD;

#(
  parameter RAS_DP_PROT_CHK_ID_BASE  = 0,
  parameter RC_NF                     = 1,
  parameter ADDR_TRANSLATION_SUPPORT  =  0 +1 ,
  localparam PIPE_DELAY  =  1,

  localparam ERR_INJ_INDEX            = (FLT_NUM==0)? 20 : 77,

  parameter PIPE_VF_INDEX             = 0 ,
  parameter PIPE_VF_INDEX_WIDTH       = PF_WD +3  // func_num + in_membar_range   
 // in_vf_membar_range + mem_vf_num
                                        ,
  parameter PIPE_CFG_WIDTH_EP         = (6*NF) + (6*NF) + NF + 1 //radm_cfg_tlp_i.cfg_bar_match + radm_cfg_i.cfg_bar_is_io + radm_cfg_tlp_i.cfg_rom_match  + coerce_cfg_tlp_to_trgt1
                                        ,

  parameter PIPE_CFG_WIDTH_RC         = (6*RC_NF) + (6*RC_NF) + RC_NF                          //radm_cfg_tlp_i.cfg_bar_match + radm_cfg_i.cfg_bar_is_io + radm_cfg_tlp_i.cfg_rom_match 
                                           + RC_NF + RC_NF   // FOR RC only 1 FUNCTION is used 
                                        ,


    localparam ALT_PF_WD            = NF == 1 ? 1 : $clog2(NF), // Alternative number of bits needed to address the physical functions
    localparam IDLE                   = 4'b0000,
    localparam OBFF                   = 4'b0001,
    localparam CPU_ACTIVE             = 4'b1111,

  parameter ERROR_LOG_PIPEWIDTH       = 128
                                          + 128
                                            + 1
                                          + PF_WD                       // flt_q_func_num
                                          + 8                           // set_radm_mlf_tlp_err_ptr
                                        + 7
                                        ,

  //parameter RAS_STAT_WD               = `CX_RAS_STAT_FILTER_EP_WD,
  parameter N_FLT_MASK                = `CX_N_FLT_MASK,
  //parameter FLT_Q_PIPEWIDTH           =  DW + DATA_PAR_WD + 1 + NW + 1 + 1 + FLT_P_HDR_WIDTH +FLT_OUT_PROT_WD + 1 + 3 
  parameter FLT_Q_PIPEWIDTH           = DW + DATA_PAR_WD + 1 + NW + 1 + 1 + $bits(flt_p_hdr_o_s)
                                         + 1 
                                         +1
                                        + 1
                                        + 1
                                        +5
                                        +1
                                        +1
                                        ,
parameter MASTER_BUS_ADDR_WIDTH = `MASTER_BUS_ADDR_WIDTH
) 

                      (

  // ---- inputs ---------------
  input                                                 core_clk,
  input                                                 radm_clk_ug,
  input                                                 core_rst_n,
  input                                                 flit_mode,
  // Config
  input   radm_cfg_i_s                                  radm_cfg_i,
  input   radm_cfg_tlp_i_s                              radm_cfg_tlp_i,
  output  radm_cfg_tlp_o_s                              radm_cfg_o,
  input   radm_hdr_dec_flt_s                            hdr_dec_flt_p, 
  // end config
  // Raw header interface
  input   radm_tlp_hdr_s                                rx_tlp_hdr,

  input   [15:0]                                        filt_ant_rid, 
  input                                                 rtlh_radm_parerr_int, 
  input                                                 radm_ecrc_err, 
  input                                                 malform_ecrc_err, 

  input                                                 app_req_retry_en,
  input [NF-1:0]                                        app_pf_req_retry_en,
  input radm_ord_mgr_flt_data_s                         ord_flt_data_p,
  // `ifdef CX_CCIX_INTERFACE_ENABLE
    // input [CCIX_WD-1:0]                              hdr_dec_flt_p_ccix_tlp,
  // `endif // CX_CCIX_INTERFACE_ENABLE
  input                                                 rtlh_radm_parerr,
//input [63:0]                                          form_filt_ant_addr,
//input [15:0]                                          form_filt_ant_rid,
  // ATU
  input [63:0]                                          rtranslated_addr_in_d,
  input [1:0]                                           rtranslated_err_in_d,
  input                                                 radm_atu_uppr_bytes_valid,
  output radm_flt_atu_s                                 radm_flt_atu_out,
  output logic                                          radm_flt_atu_hv,
  output   [ATU_IPIPE_PROT_WD-1:0]                      radm_flt_atu_hdr_prot,
  output logic                                          radm_flt_atu_eot,
  input [$clog2(ATU_IN_MIN1)-1:0]                       radm_atu_sloc_region,
  input                                                 radm_atu_sloc_match,
  input                                                 radm_atu_cbuf_err,
  // ATU end
  output ras_dp_err_log_t  [FILTER_CHK_CNTS-1:0]          ras_dp_err_log,
  input  ras_dp_err_inj_t                               ras_dp_err_inj,  
  // ---- outputs ---------------
  // output flt_q_dmux_o_s                                 flt_q_dmux_o_p
  output flt_data_o_s                                   flt_q_data_o_p,
  output flt_p_hdr_o_s                                  flt_q_hdr_o_p

);
  localparam PROT_RANGE      = `CX_RAS_PROT_RANGE;
  localparam PROT_TYPE       = `CX_RAS_PROT_TYPE;
  localparam PARITY_MODE     = `CX_RAS_PARITY_MODE;
  localparam PROT_CORRECT_EN = PROT_TYPE? 0 : `CX_RAS_CORRECTION_EN;
  localparam PRF_CHK_NO      = 0;
  localparam FLT_HDR_CHK_NO  = 0 + 1;
  // ------------------------------ Signal declaration ------------------------------
   radm_hdr_dec_flt_s                  hdr_dec_flt_p_in; 
   radm_ord_mgr_flt_data_s             ord_flt_data_p_in; 
  logic                                device_is_ep;
  logic                                device_is_rc;
  logic                                device_is_ep_int;
  logic                                device_is_rc_int;
  logic    [15:0]                      flt_reqid;
  logic    [NF-1:0]                    radm_hdr_log_valid_in;
  logic                                radm_hdr_log_valid_in_vf;
  logic [1:0] flt_q_header_at_fmt;
  logic                               l_set_outrange_req_ur;
  logic                               set_outrange_req_ur;
  logic  [5-1:0]                      radm_hdr_log_err_index_c;
  logic                               radm_hdr_log_vld_c;
  logic                               radm_hdr_log_vld_all_fn_c;

 // Following logic is to generate vendor ID match information for
 // Vendor defined register. In Gen5 this logic was part of cpl_lut 
 // to keep as common to decode the information from DW3 of received Header 

  assign  int_reqid_match             = (flt_reqid[15:3] == {radm_cfg_i.cfg_pbus_num, radm_cfg_i.cfg_pbus_dev_num});

assign reqid_match = int_reqid_match || radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_CPL_REQID_MATCH ];

assign vendor_msg_id_match_int = reqid_match;

/////////////////


  assign hdr_dec_flt_p_in            =  hdr_dec_flt_p ;              
  assign ord_flt_data_p_in           =  ord_flt_data_p ;              
  logic                               mem_req;
  logic                               radm_ptm_req;
  logic                               msg_req;
  logic [NF-1:0]                      radm_rcvd_wreq_poisoned_int;
  logic [NF-1:0]                      radm_hdr_log_valid_int;
  logic                               radm_rcvd_req_ca_int;
  logic [NF-1:0]                      radm_rcvd_req_ur_int;
  logic                               radm_hdr_vf_active;
  logic                               pf_hidden_for_vendor_msg0;
  logic                               pf_hidden_for_vendor_msg1;
  logic [7:0]                         extrct_malfm_tlp_err_ptr;
  logic                               extrct_malfm_tlp_errsts;
  logic                               is_qw_aligned;
  logic                               msg_route_bc;
  logic                               msg_type;
  logic                               msg;
  logic                               msg_route_rc ;
  logic [11:0]                        int_addr_11_dt_0;
  logic [11:0]                        addr_11_dt_0;
  logic [HEW-1:0]                     hdr_dw1;                    // sync with rtlh time domain
  logic [HEW-1:0]                     hdr_dw2;
  logic [HEW-1:0]                     hdr_dw3;
  logic [HEW-1:0]                     hdr_dw4;
  logic                               pcie_valid_tc;
  logic                               pcie_format;
  logic [2:0]                         tlp_type;
  logic [4:0]                         hdr_type;
  logic [1:0]                         fmt;
  logic [3:0]                         tlpmsg;
  logic                               tlp_is_msg;
  logic                               int_mlf_msg;
  logic                               int_mlf_msg_ep;
  logic                               int_mlf_msg_rc;
  logic                               flt_drop_msg_ep;
  logic                               flt_drop_msg_rc;
  logic                               flt_q_ecrc_discard;              
  logic                               flt_q_ecrc_discard_ep;              
  logic                               flt_q_ecrc_discard_rc;              
  logic                               p_tlp;
  logic                               flt_q_invalid_tlp;
  logic                               addr_len_error;
  logic     [2:0]                     fm_p_rsvd;
  logic     [2:0]                     fm_p_rsvd_r;
    logic [(5*NPRFX)-1:0]             flt_q_prfx_type;        // Type field of received TLP Prefix.
    logic [NPRFX-1:0]                 prfx_type_rsrvd;        // the bit of a given Prefix is set if Type field is a reserved value
    logic                             flt_q_prfx_type_error;  // asserted if any prefix type is reserved.
      logic                           flt_q_prfx_local_after_end_err; // asserted if a local type prefix follows an end-end type prefix
      logic                           flt_q_prfx_end_end_max_err;     // Asserted when max End-End limit is exceeded
      logic [31:0]                    ovrflw_end_end_prfx;            // the first overflow End-End TLP Prefix (exceeds Function's Max End-End TLP Prefixes field)
    logic                             flt_q_invalid_prfx;
  logic                               flt_q_pcie_format;
  logic                               flt_q_pcie_valid_tc;
    logic [1:0]                       ats;
    logic [3:0]                       obff_code;
  logic [9:0]                         dw_len;
  logic [ATTR_WD-1:0]                 attr;
  logic                               tlp_w_pyld;
  logic                               td;
  logic [2:0]                         tc;
  logic [3:0]                         first_be;
  logic [3:0]                         last_be;
  logic                               msg_is_slotpwr;
  logic                               msg_is_vendor_msg0;
  logic                               msg_is_vendor_msg1;
  radm_hdr_log_rcvd_flds_s                              l_flt_q_log_rcvd_flds ;
  logic                               dwlenEq1;
  logic [7:0]                         msg_code;
  logic [11:0]                        rcvd_tlp_byte_cnt;
  logic [6:0]                         rcvd_tlp_low_addr;
  logic                               flt_q_rtlh_abort;
  logic                               flt_q_msg_mlf_err;
  logic [HEW-1:0]                     flt_q_hdr_dw1;                  // sync with q time domain
  logic [HEW-1:0]                     flt_q_hdr_dw2;
  logic [HEW-1:0]                     flt_q_hdr_dw3;
  logic [HEW-1:0]                     flt_q_hdr_dw4;
  logic [14-1:0]                      flt_q_14Bit_tag;
  logic [1:0]                         flt_q_hdr_dec_ph;
  logic [7:0]                         flt_q_ohc_b_st_lb;
  logic                               flt_q_hdr_ohc_err;
  logic [8:0]                         flt_q_hdr_dec_flt_dest_seg ;
  logic [8:0]                         flt_q_hdr_dec_flt_reqtr_seg;
  logic [2:0]                         raw_flt_q_in_membar_range;
  logic [2:0]                         flt_q_in_membar_range;
  logic [2:0]                         flt_q_in_membar_range_ep;
  logic [2:0]                         flt_q_in_membar_range_rc;
  logic                               flt_q_mem_req_in_range;
  logic                               flt_q_rom_req_in_range;
  logic                               flt_q_rcrb_req_in_range;
  logic [DW+DATA_PAR_WD-1:0]          l_flt_q_data;                   //tlp data sent to queue
  // logic [PKT_ORD_WD-1:0]              l_ord_flt_p_pkt_num;            // flt_q  //tlp data sent to queue
  // aux bus to decouple the internal wiring from the use of RAS. If RAS is used chk_l_flt_q_data holds the 
  // value of l_flt_q_data at the output of bus_protect_chk. If RAS is not used chk_l_flt_q_data is just a 
  // feedthrough
  logic [DW+DATA_PAR_WD-1:0]          chk_l_flt_q_data;
  logic                               l_flt_q_dllp_abort;             //Recall packet (Malformed TLP, etc.)
  logic [NW-1:0]                      l_flt_q_dwen;                   //DWord Enable for Data Interface.
  logic                               l_flt_q_ecrc_err;               // -> radm_q
  flt_p_hdr_o_s                       l_flt_q_header;                 //tlp compressed header sent to queue
  flt_p_hdr_o_s                       l_flt_q_header_d;               //tlp compressed header sent to queue
  flt_p_hdr_s                         chk_l_flt_q_header_d;           //tlp compressed header sent to queue, output of bus_protect_chk if RAS is enabled
  // decouple the internal header wiring from the use of RAS. If RAS is used then chk_prfxHdr_flt_hdr_p is the output of
  // bus_protect_chk module. Without RAS it's just a feedthrough of hdr_dec_flt_hdr_p
  logic [HW_NFT+HW_NFT_PAR-1:0]       chk_prfxHdr_flt_hdr_p;           // 128-bit packet header

  logic                               l_flt_q_tlp_abort;               // flt_q  //Recall packet (Malformed TLP, etc.)
  logic [2:0]                         l_flt_q_tlp_type;                // flt_q  //one hot signal indicating to indicate {CPL, NP, P} TLP, valid @ l_flt_q_hv
  logic                               l_flt_q_parerr;
          
  logic                               l_set_radm_ecrc_err;
  logic                               l_set_radm_hdr_log_valid;
  logic                               l_set_radm_mlf_tlp_err;
  logic                               l_set_radm_rcvd_req_ca;
  logic                               l_set_radm_rcvd_req_ur;
  logic                               l_set_radm_rcvd_wreq_poisoned;
  logic [127:0]                       l_radm_hdr_log;
  logic                               set_radm_ecrc_err;
  logic                               set_radm_hdr_log_valid;
  logic                               set_radm_mlf_tlp_err;
  logic                               set_radm_rcvd_req_ca;
  logic                               set_radm_rcvd_req_ur;
  logic                               set_radm_rcvd_wreq_poisoned;
  logic                               flt_q_mem_req_range_rc;
  logic                               flt_q_mem_req_range_ep;
  logic [1:0]                         int_flt_q_destination;
  logic [1:0]                         int_flt_q_destination_rc;
  logic [1:0]                         int_flt_q_destination_ep;
  logic [1:0]                         latchd_flt_q_destination;
  logic [1:0]                         flt_q_destination;
  logic [1:0]                         flt_destination_at;
  logic [ATTR_WD-1:0]                 flt_q_attr;
  logic [2:0]                         flt_q_tc;
  logic [TAG_SIZE-1:0]                flt_q_TAG;
  logic [15:0]                        flt_q_REQID;
  logic [4:0]                         flt_q_type;
  logic [1:0]                         flt_q_fmt;
  logic                               flt_q_fmt2; // second [2] bit of FMT field used to detect reserved TLP in FLIT mode 
  logic                               flt_q_iord_req;
  logic                               flt_q_iowr_req;
  logic                               flt_q_memrd_req;
  logic                               flt_q_memwr_req;
  logic                               flt_q_def_memwr_req;
  logic                               flt_q_cfg1rd_req;
  logic                               flt_q_cfg1wr_req;
  logic                               flt_q_atomic_op;
  logic                               flt_q_mem_req;
  logic                               flt_q_func_mismatch;
  logic                               flt_q_td;
  logic                               flt_q_td_hdr_log;
  logic                               flt_q_poisoned;
  logic                               flt_q_poisoned_err;
  logic                               flt_q_addr64;
  logic [3:0]                         flt_q_first_be;
  logic [3:0]                         flt_q_last_be;
  logic [7:0]                         flt_q_msg_code;
  logic [7:0]                         flt_q_bus_num;
    logic [4:0]                       flt_q_dev_num;
  logic [PF_WD-1:0]                   flt_q_cfg_func_num;
  logic [PF_WD-1:0]                   flt_q_func_num;
  logic [PF_WD-1:0]                   flt_q_func_num_ep;
  logic [PF_WD-1:0]                   flt_q_func_num_rc;
  logic [PF_WD-1:0]                   raw_flt_q_func_num;
  logic [PF_WD-1:0]                   raw_mem_func_num;
  logic [PF_WD-1:0]                   flt_q_func_num_d;
  logic [PF_WD-1:0]                   pf;
  logic [PF_WD-1:0]                   pfvf_func_num;
  logic [3:0]                         flt_q_ext_reg_num;
  logic [5:0]                         flt_q_reg_num;
  logic [63:0]                        flt_q_addr;
  logic [64-1:0]                      flt_q_addr_tph;
  logic [63:0]                        flt_q_addr_hdr_log1;
  logic [63:0]                        flt_q_addr_int;
  logic [7:0]                         flt_q_addr_byte0;
  logic [7:0]                         flt_q_addr_byte1;
  logic [7:0]                         flt_q_addr_byte2;
  logic [7:0]                         flt_q_addr_byte3;
  logic [7:0]                         flt_q_addr_byte4;
  logic [7:0]                         flt_q_addr_byte5;
  logic [7:0]                         flt_q_addr_byte6;
  logic [7:0]                         flt_q_addr_byte7;
  logic [9:0]                         flt_q_dw_len;
  logic                               flt_q_valid_p;
  logic                               flt_q_valid_p_rc;
  logic                               flt_q_valid_p_ep;
  logic                               flt_q_valid_ur_p;
  logic                               flt_q_ur_p_wo_poisn;
  logic                               flt_q_valid_ca_p;
  logic [2:0]                         flt_q_cpl_status;
  logic [2:0]                         flt_q_cpl_status_ep;
  logic [2:0]                         flt_q_cpl_status_rc;
  logic [2:0]                         flt_q_actual_cpl_status;
  logic                               flt_q_tlp_is_msg;
  logic                               int_flt_q_invalid_msg;
  logic                               int_flt_q_vendor_msg_id_match;
  logic                               flt_q_invalid_msg_ep;
  logic                               flt_q_invalid_msg_rc;
  logic                               flt_q_invalid_msg;
  logic                               flt_q_vendor_msg_id_match;  
  logic                               flt_q_vendor_msg;
  logic                               flt_q_vendor_msg0;
  logic                               flt_q_vendor_msg0_ep;
  logic                               flt_q_vendor_msg0_rc;
  logic                               flt_q_vendor_msg1;
  logic                               flt_q_vendor_msg1_ep;
  logic                               flt_q_vendor_msg1_rc;
    logic                             flt_q_obff_msg;
  logic                               flt_q_invalidate_msg;
  logic                               flt_q_invalidate_msg_ep;
  logic                               flt_q_invalidate_msg_rc;
  logic [3:0]                         flt_q_tlpmsg;
  flt_p_hdr_o_s                       compressed_hdr_gen_out;
    logic [1:0]                       flt_q_ats;
  logic                               flt_q_th;
  logic [6:0]                         tlp_fmt_type;
  logic                               rtlh_dllp_err_d;
  logic    [PKT_ORD_WD-1:0]           ord_flt_p_pkt_num_d;
  logic                               l_flt_q_tlp_poisoned;
  logic                               flt_q_unqual_dv;
  logic                               flt_q_unqual_dv_ep;
  logic                               flt_q_unqual_hv;
  logic                               flt_q_unqual_hv_ep;
  logic                               flt_q_unqual_eot;
  logic                               flt_q_unqual_eot_ep;
  logic                               flt_q_unqual_dv_rc;
  logic                               flt_q_unqual_hv_rc;
  logic                               flt_q_unqual_eot_rc;
  
  // CPL declarations
  logic                               flt_q_outrange_ur;
  logic                               flt_q_outrange_ur_int;
  logic [1:0]                         target_acquisition;             // dynamic tlp steering, depending on bar mapping, 1-trgt1; 0-trgt0;
  logic [1:0]                         target_acquisition_rc_int;             // dynamic tlp steering, depending on bar mapping, 1-trgt1; 0-trgt0;
  logic [1:0]                         target_acquisition_rc;             // dynamic tlp steering, depending on bar mapping, 1-trgt1; 0-trgt0;
  logic [1:0]                         target_acquisition_ep;             // dynamic tlp steering, depending on bar mapping, 1-trgt1; 0-trgt0;
  logic                               rom_trgt_map;
  logic                               mem_trgt_map;
  logic                               pm_block_tlp;
  logic                               flt_q_pm_radm_block_tlp;
  logic                               flt_q_poisoned_discard;
  logic                               flr_in_progress;
  logic                               flr_pf_in_progress;
  logic                               flr_vf_in_progress;
            
  logic                               coerce_cfg_tlp_to_trgt1;
  logic                               coerce_cfg_tlp_to_trgt1_int;
  logic                               rtlh_mem_req;
  logic [PF_WD-1:0]                   rtlh_cfg_func_num;

  logic [NF-1:0][5:0]                 cfg_bar_is_io_reg;                  // indication that tlp is within MEM BAR, which is IO space
  logic [NF-1:0][5:0]                 cfg_bar_is_io_reg_ep;                  // indication that tlp is within MEM BAR, which is IO space
  logic [RC_NF-1:0][5:0]              cfg_bar_is_io_reg_rc;
  logic [NF-1:0]                      cfg_rom_match_reg;                  // indication that tlp is within a ROM BAR
  logic [NF-1:0]                      cfg_rom_match_reg_ep;                  // indication that tlp is within a ROM BAR
  logic [RC_NF-1:0]                   cfg_rom_match_reg_rc;
  logic [NF-1:0][5:0]                 cfg_bar_match_reg;                  // indication that tlp is within a MEM BAR
  logic [RC_NF-1:0][5:0]              cfg_bar_match_reg_rc;
  logic [NF-1:0][5:0]                 cfg_bar_match_reg_ep;


  // Sending and Receiving of TLP Prefixes enabled
    logic [PRFX_W_PAR-1:0]               flt_q_prfx;                     // retimed rtlh_radm_prfx
    logic [PRFX_W_PAR-1:0]               chk_flt_q_prfx;                 // aux wire to decouple from RAS
    //logic                             flt_q_prfx_err_detect;
    //logic                             flt_q_prfx_err_multpl;

  logic                               radm_ecrc_err_int;  
  logic                               malform_ecrc_err_int;
  logic                               target_ca;                      // target completion abort; asserted if target 0 - ELBI limitations not met.
  logic                               tmp_mlf_err;
  logic [7:0]                         tmp_mlf_err_ptr;
  logic [7:0]                         flt_q_rtlh_abort_ptr;
    logic [7:0]                       l_set_radm_mlf_tlp_err_ptr;
    logic [7:0]                       set_radm_mlf_tlp_err_ptr;

  logic                               coerce_cfg_tlp_to_trgt1_en;     // Target destination control signal; allows Cfg requests to reach Target1.

  logic                               l_flt_q_header_d_prot_err; 
  logic                               int_flt_q_parerr;
  logic                               app_req_retry_en_tmp;
  logic                               int_app_req_retry_en;
  logic [NF-1:0]                      int_app_pf_req_retry_en;
  logic                               fmt2;
    logic [7:0]                       msg_subtype;
    logic [15:0]                      vendor_id;

    logic                             int_ptm_res;
    logic                             int_ptm_resD;
    logic [63:0]                      ptm_master_time;
    logic [31:0]                      ptm_prop_delay;
    logic                             int_prg_response;
    logic                             flt_q_prg_response;
  
    logic [7:0]                       flt_q_addr_byte0_i;
    logic [63:0]                      obff_addr;
    logic                             obff_cpu_active;
    logic [3:0]                       flt_q_obff_code;
  logic [1:0]                         flt_q_ph;
  logic [1:0]                         flt_q_ph_int;
  logic [7:0]                         flt_q_st;
  
  logic                               flt_q_mask_wreq_poisoned_reporting;
  logic                               flt_q_mask_cpl_poisoned_reporting;
  logic                               enable_mask_pois_if_trgt0_destination_ep;
  logic                               enable_mask_pois_if_trgt0_destination_rc;
  

  logic                               p_wr;
  logic [9:0]                         tlp_dw_len;
  logic                               tlp_has_pyld;
  logic                               dw_len_is0;
  logic                               intrup_msg;
  logic                               pm_msg;
  logic                               err_msg;
  logic                               lock_msg;
  logic                               sspl_msg;
    logic                             obff_msg;
    logic                             ltr_msg;
    logic                             ptm_msg;
    logic                             prs_msg;
  logic                               msg_route_err;
  logic [10:0]                        tmp_dw_len;
  logic                               len_mismatch;
  logic                               hdr_err;
  logic [7:0]                         hdr_err_ptr;
  logic                               max_pyld_err;
  logic                               do_check;
  logic                               hdr_len_mismatch;
  logic                               fbe_error;
  logic                               lbe_error;
  logic                               be_error;
  logic                               rtlh_extrct_ecrc_len_mismatch; 
  assign                              rtlh_extrct_ecrc_len_mismatch = 0;  // ms_con : WIll be added after ECRC implementation
  logic [NW-1:0]                      l_tmp_dwcnt;
  logic [NW-1:0]                      tmp_dwcnt;
  logic [10:0]                        prev_pyld_dwcnt;
  logic [10:0]                        pyld_dwcnt;
  `ifndef SYNTHESIS
    //VCS coverage off
    logic [8*5:0]                     RADM_Q_DEST;
    logic [8*5:0]                     TARGET_MAP;
    logic [8*9:0]                     RADM_Q_VALID_TYPE;
    logic [8*3:0]                     RADM_Q_TLP_TYPE;
    //  ENCODED valid type          
    logic [2:0]                       flt_q_valid_type;
    //VCS coverage on
  `endif
  logic                               update_destination_en;
    logic                             ptm_res_msg;    
    logic                             ptm_resD_msg;   
    logic                             ptm_res_msg_d;
    logic                             ptm_resD_msg_d;   
    logic [63:0]                      ptm_master_time_reg;
    logic [31:0]                      ptm_prop_delay_reg;
  // MESSAGE interception
  logic                               int_pm_asnak;
  logic                               int_pm_turnoff;
  logic                               int_inta_asserted;
  logic                               int_intb_asserted;
  logic                               int_intc_asserted;
  logic                               int_intd_asserted;
  logic                               int_inta_deasserted;
  logic                               int_intb_deasserted;
  logic                               int_intc_deasserted;
  logic                               int_intd_deasserted;
  logic                               int_att_ind_on;
  logic                               int_att_ind_blink;
  logic                               int_att_ind_off;
  logic                               int_pwr_ind_on;
  logic                               int_pwr_ind_blink;
  logic                               int_pwr_ind_off;
  logic                               int_msg_unlock;
  logic                               int_att_button_pressed;
  logic                               int_vendor_msg_id_match;
  logic                               int_ltr;
  logic                               int_invalidate_request;
  logic                               int_invalidate_cmplt;
    logic                             int_obff_msg;
  logic                               flt_q_pcie_good_eot;
  logic                               flt_q_pcie_good_eot_ep;
  logic                               flt_q_pcie_good_eot_rc;
  logic                               valid_ats;
    logic                             flt_q_rd_size_in_range;
    logic                             flt_q_len_zero;
  logic                               latch_hdr_pipe_en_ep;
  logic                               latch_hdr_pipe_en_rc;
  logic                               flt_q_pipe_en;
  logic                               flt_q_pipe_en_rc;
  logic                               flt_q_pipe_en_ep;
  logic                               l_flt_data_parerr;
    logic                             flt_q_memwr_req_d;
      logic                           flt_q_tlp_is_msg_d;
    logic                             translate_enable;
    logic [63:0]                      rtranslated_tlp_addr;
    logic [63:0]                      rtranslated_tlp_addr_tph;
    flt_p_hdr_o_s                     flt_q_header_at; 
    flt_p_hdr_o_s                     gen_flt_q_header_at; 
    logic [4:0]                       flt_q_type_d;
    logic                             rtranslated_tlp_hdr_fmt;
  logic                               pipe_error_log_en;
  logic                               pipe_error_log_en_reg;
  logic                               error_log_pipe_en;
  logic                               error_log_pipe_en_ep;
  logic                               error_log_pipe_en_rc;
  logic [63:0]                        extract_addr;
    logic [255:0]                     pre_tlp_prfx_log;       // This bus must have max possible width = 8 x TLP Prefixes
    logic [159:0]                     e2e_prfx_log;           // This bus must have max possible width = 8 x TLP Prefixes
    logic [127:0]                     l_radm_tlp_prfx_log;    // 4 DWs stored in TLP Prefix log
      logic [4:0]                     end2end_max;
      logic [NPRFX-1:0]               prfx_is_end;            // A received prefix is of type end to end 
      logic [NPRFX-1:0]               prfx_is_local;          // A received prefix is of type local
      logic [NPRFX-1:0]               prfx_type_msb;          // Type[4] bit of prefix.
      logic [NPRFX-1:0]               prfx_fmt_msb;           // Fmt[2] bit of prefix.
      logic [4:0]                     end_end_cnt;
      logic [1:0]                     end2end_max_pf;
  logic [2:0]                         in_membar_range;
  logic [2:0]                         in_membar_range_unreg;
  logic [PF_WD-1:0]                   raw_func_num_unreg;
  logic [PF_WD-1:0]                   raw_cfg_func_num;

  logic [PF_WD-1:0]                   pf_to_match;
  logic                               flt_q_valid_ur_xtrash_wo_poisn ;
  logic                               flt_q_valid_ur_xtrgt0_wo_poisn;
  logic                               flt_q_valid_ur_xtrgt1_wo_poisn;
  logic                               flt_q_valid_ur_wo_poisn_err;
  logic                               flt_q_valid_ur_wo_poisn_err_rc;
  logic                               flt_q_valid_ur_wo_poisn_err_ep;
  logic                               flt_q_valid_ur_xtrash;
  logic                               flt_q_valid_ur_xtrgt0;
  logic                               flt_q_valid_ur_xtrgt1;
  logic                               flt_q_valid_ur_err;
  logic                               flt_q_valid_ur_err_rc;
  logic                               flt_q_valid_ur_err_ep;
  logic                               flt_q_poisoned_discard_rc;
  logic                               flt_q_poisoned_discard_ep;
  logic                               flt_q_valid_ca_err;
  logic                               radm_hdr_log_valid;
  logic                               radm_hdr_log_valid_c;


  logic                               int_flt_q_tlp_abort;              // flt_q - delayed version of l_flt_q_tlp_abort
  logic                               flt_q_tlp_abort_rc;               // flt_q - delayed version of l_flt_q_tlp_abort
    logic                             flt_q_outside_mem_range;
    logic                             flt_q_outside_prefmem_range;
    logic                             flt_q_outside_alt_mem_range;
    logic                             flt_q_outside_alt_prefmem_range;
    logic                             flt_q_outside_alt_range;
    logic                             alt_bus_num_valid;
    logic [RC_NF-1:0]                 cfg_cxl_alt_mem_match_reg;         // indication that tlp is within Alternate Memory Range
    logic [RC_NF-1:0]                 cfg_cxl_alt_prefmem_match_reg;     // indication that tlp is within Prefetchable Alternate Memory Range
    logic [RC_NF-1:0]                 cfg_mem_match_reg_rc;
    logic [RC_NF-1:0]                 cfg_prefmem_match_reg_rc;
    logic                             flt_q_valid_ur_p_wo_poisoned;
    logic                             int_err_cor;
    logic                             int_err_nf;
    logic                             int_err_f;
    logic                             l_set_cdm_err_advisory;
    logic                             set_radm_rcvd_acs_err;
    logic                             l_set_radm_rcvd_acs_err;
    logic                             acs_src_valid;
    logic                             acs_at_valid;
    logic                             flt_q_acs_err;
    logic [3:0]                       reason;
    logic                             msg_is_drs_msg;
    logic                             flt_q_drs_msg;
    logic                             int_ltr_msg_det;

  logic                               int_pm_to_ack;
  logic                               int_pm_pme;
  logic                               ptm_req_msg;
  logic                               ptm_req_msg_d;
  logic                               pre_dpc_err_nf;
  logic                               pre_dpc_err_f;
  logic                               cdm_core_in_dpc_reg[FLT_Q_PIPE_DELAY-1:0];
  logic                               l_flt_q_hv_int     ;
  logic                               l_flt_q_dv_int     ;
  logic                               l_flt_q_eot_int    ;
  logic                               l_flt_q_hv     ;
  logic                               l_flt_q_dv     ;
  logic                               l_flt_q_eot    ;
  logic   [64-1:0]                    radm_msg_payload_rc;
  logic   [64-1:0]                    radm_msg_payload_ep;

  logic                              msg_is_frs_msg;
  logic                              flt_q_frs_msg;
  logic [3:0]                        flt_q_frs_msg_reason;
  logic                              flt_q_addr_gt_bus_width_at;
  logic                              flt_q_addr_gt_mstr_addr_width_at;


   radm_cfg_tlp_o_s                              radm_cfg_o_int;

  // ----------------------------------- Signal declaration ends -------------------------

  delay_n
  
  #( .N (ANTI_CTRL_PIPE_DELAY-1), .WD (1) ) 
  u_ecrc_err_delay
  (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        (radm_ecrc_err),
    .dout       (radm_ecrc_err_int)
  );

  // Added pipeline to align malform_ecrc_err with hdr_dec_flt_p_in.hdr_dec_flt_hv/eot 
  delay_n
  
  #( .N (ANTI_CTRL_PIPE_DELAY+1), .WD (1) ) 
  u_ecrc_mlf_err_delay
  (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        (malform_ecrc_err),
    .dout       (malform_ecrc_err_int)
  );



    assign device_is_ep_int = radm_cfg_i.device_type == 4'b0000;
    assign device_is_rc_int = radm_cfg_i.device_type == 4'b0100;


  delay_n
   
    #( .N(1), .WD(1))
    u_radm_device_type_0_pipe (
    .clk    (core_clk),
    .rst_n  (core_rst_n),
    .clear  (1'b0),
    .din    (device_is_rc_int),
    .dout   (device_is_rc)
  );

  delay_n
   
    #( .N(1), .WD(1))
    u_radm_device_type_1_pipe (
    .clk    (core_clk),
    .rst_n  (core_rst_n),
    .clear  (1'b0),
    .din    (device_is_ep_int),
    .dout   (device_is_ep)
  );


    assign flt_q_outrange_ur                        =  device_is_ep ? flt_q_outrange_ur_int : 1'b0;
    assign flt_q_invalid_msg                        =  device_is_ep ? flt_q_invalid_msg_ep : flt_q_invalid_msg_rc;
    assign int_mlf_msg                              =  device_is_ep ? int_mlf_msg_ep : int_mlf_msg_rc;
    assign flt_q_valid_ur_wo_poisn_err              =  device_is_ep ? flt_q_valid_ur_wo_poisn_err_ep : flt_q_valid_ur_wo_poisn_err_rc;
    assign radm_cfg_o.radm_msg_payload              =  device_is_ep ? radm_msg_payload_ep            : radm_msg_payload_rc;
      //assign  radm_cfg_o.radm_rcvd_acs_err          =  device_is_rc ? route_error_to_func( set_radm_rcvd_acs_err, flt_q_func_num_d) : 0 ;
      assign  radm_cfg_o.radm_rcvd_acs_err          =  device_is_rc ? set_radm_rcvd_acs_err : 0 ;
  
    assign  flt_q_cpl_status                        =  device_is_rc ? flt_q_cpl_status_rc                  : flt_q_cpl_status_ep;
    assign  radm_cfg_o.int_radm_pm_pme              =  device_is_rc ? radm_cfg_o_int.int_radm_pm_pme       : 0;
    assign  radm_cfg_o.radm_inta_asserted           =  device_is_rc ? radm_cfg_o_int.radm_inta_asserted    : 0;
    assign  radm_cfg_o.radm_intb_asserted           =  device_is_rc ? radm_cfg_o_int.radm_intb_asserted    : 0;
    assign  radm_cfg_o.radm_intc_asserted           =  device_is_rc ? radm_cfg_o_int.radm_intc_asserted    : 0;
    assign  radm_cfg_o.radm_intd_asserted           =  device_is_rc ? radm_cfg_o_int.radm_intd_asserted    : 0;
    assign  radm_cfg_o.radm_inta_deasserted         =  device_is_rc ? radm_cfg_o_int.radm_inta_deasserted  : 0;
    assign  radm_cfg_o.radm_intb_deasserted         =  device_is_rc ? radm_cfg_o_int.radm_intb_deasserted  : 0;
    assign  radm_cfg_o.radm_intc_deasserted         =  device_is_rc ? radm_cfg_o_int.radm_intc_deasserted  : 0;
    assign  radm_cfg_o.radm_intd_deasserted         =  device_is_rc ? radm_cfg_o_int.radm_intd_deasserted  : 0;
    assign  radm_cfg_o.radm_err_cor                 =  device_is_rc ? radm_cfg_o_int.radm_err_cor          : 0;
    assign  radm_cfg_o.radm_err_nf                  =  device_is_rc ? radm_cfg_o_int.radm_err_nf           : 0;
    assign  radm_cfg_o.radm_err_f                   =  device_is_rc ? radm_cfg_o_int.radm_err_f            : 0;
    assign  flt_q_pipe_en                           =  device_is_rc ? flt_q_pipe_en_rc                     : flt_q_pipe_en_ep;
    assign  latch_hdr_pipe_en                       =  device_is_rc ? latch_hdr_pipe_en_rc                 : latch_hdr_pipe_en_ep;
  
      assign radm_cfg_o.radm_drs_msg                =  device_is_rc ? radm_cfg_o_int.radm_drs_msg          : 0;
        assign radm_cfg_o.radm_frs_msg              =  device_is_rc ? radm_cfg_o_int.radm_frs_msg          : 0;
        assign radm_cfg_o.radm_frs_msg_reason       =  device_is_rc ? radm_cfg_o_int.radm_frs_msg_reason   : 0; 
      assign radm_cfg_o.radm_msg_ltr_latency        =  device_is_rc ? radm_cfg_o_int.radm_msg_ltr_latency  : 0; 
      assign radm_cfg_o.radm_msg_ltr                =  device_is_rc ? radm_cfg_o_int.radm_msg_ltr          : 0; 
  
      assign radm_cfg_o.radm_rcvd_req_ca            =  device_is_ep  ? radm_cfg_o_int.radm_rcvd_req_ca      : radm_rcvd_req_ca_int;
      assign radm_cfg_o.radm_rcvd_req_ur            =  device_is_ep  ? radm_cfg_o_int.radm_rcvd_req_ur      : radm_rcvd_req_ur_int;
      assign radm_cfg_o.radm_rcvd_wreq_poisoned     =  device_is_ep  ? radm_cfg_o_int.radm_rcvd_wreq_poisoned : radm_rcvd_wreq_poisoned_int;
      assign radm_cfg_o.radm_hdr_log_valid          =  device_is_ep  ? radm_cfg_o_int.radm_hdr_log_valid    : radm_hdr_log_valid_int;
      assign radm_hdr_log_valid_in                  =  device_is_ep  ? radm_cfg_o_int.radm_hdr_log_valid    : radm_hdr_log_valid_int;


      assign  radm_cfg_o.radm_pm_turnoff            =  device_is_ep ? radm_cfg_o_int.radm_pm_turnoff        : 0;
      assign  radm_cfg_o.radm_msg_unlock            =  device_is_ep ? radm_cfg_o_int.radm_msg_unlock        : 0;
      assign  radm_cfg_o.radm_slot_pwr_limit        =  device_is_ep ? radm_cfg_o_int.radm_slot_pwr_limit    : 0;
      assign    radm_cfg_o.radm_msg_obff            =  device_is_ep ? radm_cfg_o_int.radm_msg_obff          : 0;
      assign    radm_cfg_o.radm_msg_cpu_active      =  device_is_ep ? radm_cfg_o_int.radm_msg_cpu_active    : 0;
      assign    radm_cfg_o.radm_msg_idle            =  device_is_ep ? radm_cfg_o_int.radm_msg_idle          : 0;
      assign radm_cfg_o.radm_ptm_req                =  device_is_ep ?  0 : radm_ptm_req;
      assign radm_cfg_o.radm_ptm_res_msg            =  device_is_ep ? radm_cfg_o_int.radm_ptm_res_msg       : 0;
      assign radm_cfg_o.radm_ptm_res_d_msg          =  device_is_ep ? radm_cfg_o_int.radm_ptm_res_d_msg     : 0;
      assign radm_cfg_o.radm_ptm_master_time        =  device_is_ep ? radm_cfg_o_int.radm_ptm_master_time   : 0;
      assign radm_cfg_o.radm_ptm_prop_delay         =  device_is_ep ? radm_cfg_o_int.radm_ptm_prop_delay    : 0;
    assign flt_q_ecrc_discard                       =  device_is_ep ? flt_q_ecrc_discard_ep                     : flt_q_ecrc_discard_rc  ;
    assign l_flt_q_hv_int                           =  device_is_ep ? (flt_q_unqual_hv_ep)  : (flt_q_unqual_hv_rc); 
    assign l_flt_q_dv_int                           =  device_is_ep ? (flt_q_unqual_dv_ep)  : (flt_q_unqual_dv_rc);
    assign l_flt_q_eot_int                          =  device_is_ep ? (flt_q_unqual_eot_ep) : (flt_q_unqual_eot_rc);
    assign int_flt_q_destination                    =  device_is_ep ? int_flt_q_destination_ep :  int_flt_q_destination_rc;
      assign target_acquisition_rc_int              =  `FLT_DESTINATION_TRGT1;
    assign  target_acquisition                      =  device_is_ep ? target_acquisition_ep      : target_acquisition_rc_int;
    assign  flt_q_unqual_eot                        =  device_is_ep ? flt_q_unqual_eot_ep        : flt_q_unqual_eot_rc;
    assign  flt_q_unqual_hv                         =  device_is_ep ? flt_q_unqual_hv_ep         : flt_q_unqual_hv_rc;
    assign  flt_q_valid_p                           =  device_is_ep ? flt_q_valid_p_ep           : flt_q_valid_p_rc;
    assign  flt_q_unqual_dv                         =  device_is_ep ? flt_q_unqual_dv_ep         : flt_q_unqual_dv_rc;
    assign flt_q_in_membar_range                    =  device_is_ep ? flt_q_in_membar_range_ep   : flt_q_in_membar_range_rc;
    assign flt_q_vendor_msg0                        =  device_is_ep ? flt_q_vendor_msg0_ep       : flt_q_vendor_msg0_rc;
    assign flt_q_vendor_msg1                        =  device_is_ep ? flt_q_vendor_msg1_ep       : flt_q_vendor_msg1_rc;
    //assign flt_q_invalidate_msg                     = device_is_ep ? flt_q_invalidate_msg_ep  : flt_q_invalidate_msg_rc;
    assign flt_q_pcie_good_eot                      =  device_is_ep ? flt_q_pcie_good_eot_ep     : flt_q_pcie_good_eot_rc;
    assign flt_q_func_num                           =  device_is_ep ? flt_q_func_num_ep          : flt_q_func_num_rc;
    assign error_log_pipe_en                        =  device_is_ep ? error_log_pipe_en_ep       : error_log_pipe_en_rc;           
    assign flt_q_valid_ur_err                       =  device_is_ep ? flt_q_valid_ur_err_ep      : flt_q_valid_ur_err_rc;
    assign  flt_q_poisoned_discard                  =  device_is_ep ? flt_q_poisoned_discard_ep  : flt_q_poisoned_discard_rc; 
    //assign flt_q_data_o_p.flt_q_tlp_abort = device_is_ep ? int_flt_q_tlp_abort : flt_q_tlp_abort_rc;
    assign flt_q_data_o_p.flt_q_tlp_abort           = device_is_ep ? int_flt_q_tlp_abort : flt_q_tlp_abort_rc;  
    assign cfg_bar_match_reg                        = device_is_ep ? cfg_bar_match_reg_ep : {{((NF*6)-(RC_NF*6)){1'b0}},cfg_bar_match_reg_rc};
    assign cfg_bar_is_io_reg                        = device_is_ep ? cfg_bar_is_io_reg_ep : {{((NF*6)-(RC_NF*6)){1'b0}},cfg_bar_is_io_reg_rc};
    assign cfg_rom_match_reg                        = device_is_ep ? cfg_rom_match_reg_ep : {{(NF-RC_NF){1'b0}},cfg_rom_match_reg_rc};
  
  
  assign radm_cfg_o.flt_cdm_pf = flt_q_func_num_d;  

  // COmmon signals for CX_RN_DRS_SUPPORTED and CX_LN_ENABLE

  assign  vendor_id               = {hdr_dw3[23:16], hdr_dw3[31:24]};
  assign  msg_subtype             = hdr_dw4[7:0];
  //////
  
    //assign  radm_cfg_o_int.radm_rcvd_acs_err         = route_error_to_func( set_radm_rcvd_acs_err  , flt_q_func_num_d);
    assign  radm_cfg_o_int.radm_rcvd_acs_err         = set_radm_rcvd_acs_err ;
    assign radm_cfg_o_int.radm_drs_msg               = (flt_q_drs_msg && flt_q_pcie_good_eot_rc && !(tmp_mlf_err));
      assign radm_cfg_o_int.radm_frs_msg             = (flt_q_frs_msg && flt_q_pcie_good_eot_rc && !(tmp_mlf_err));    // radm_frs_msg gates reason 
      assign radm_cfg_o_int.radm_frs_msg_reason[3:0] = flt_q_frs_msg_reason[3:0];
    assign radm_cfg_o_int.radm_msg_ltr_latency       = flt_q_hdr_dw4; // the format is {byte15, byte14, byte13, byte12}
    // The VDM/LTR message payload is defined from bytes 12 to byte 15.
    // To be consistent with the format on the RTRGT1 address bus the byte  order is reversed.
    // DW3 output on bits [63:32], DW4 output on [31:0].
      assign  radm_msg_payload_rc = (radm_cfg_o_int.radm_msg_ltr | flt_q_vendor_msg) ?
                                    {flt_q_hdr_dw3[7:0],flt_q_hdr_dw3[15:8],flt_q_hdr_dw3[23:16],flt_q_hdr_dw3[31:24],
                                     flt_q_hdr_dw4[7:0],flt_q_hdr_dw4[15:8],flt_q_hdr_dw4[23:16],flt_q_hdr_dw4[31:24]} :
                                    {32'b0, chk_l_flt_q_data[31:0]};


    assign  reason                  = hdr_dw4[27:24];

    assign msg_is_drs_msg = ((tc == `DRS_TC) && (radm_cfg_o.flt_dwlenEq0) && (msg_code == `VENDOR_TYPE1) && (vendor_id == `PCISIG_ID) && (msg_subtype == `DRS_SUBTYPE) && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);

    always @(posedge core_clk or negedge core_rst_n)
    begin
      if(!core_rst_n) begin
        flt_q_drs_msg               <= #TP 1'b0;
      end else begin
        flt_q_drs_msg               <= #TP msg_is_drs_msg && tlp_is_msg && !radm_cfg_o.tlp_poisoned;        
      end
    end



      assign msg_is_frs_msg = ((tc == `FRS_TC) && (radm_cfg_o.flt_dwlenEq0) && (msg_code == `VENDOR_TYPE1) && (vendor_id == `PCISIG_ID) && (msg_subtype == `FRS_SUBTYPE) && (hdr_type[2:0] == 3'b000) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);

      always @(posedge core_clk or negedge core_rst_n)
      begin
        if(!core_rst_n) begin
          flt_q_frs_msg               <= #TP 1'b0;
          flt_q_frs_msg_reason[3:0]   <= #TP 4'h0;
        end else begin
          flt_q_frs_msg               <= #TP msg_is_frs_msg && tlp_is_msg && !radm_cfg_o.tlp_poisoned;
          flt_q_frs_msg_reason[3:0]   <= #TP (tlp_is_msg && !radm_cfg_o.tlp_poisoned) ? reason[3:0] : flt_q_frs_msg_reason[3:0];        
        end
      end


    logic    int_ptm_req;
    assign  int_ptm_req           = ((msg_code == `PTM_REQ_TYPE) && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);

    logic    int_prs_request;
    logic     flt_q_prs_request;
    assign  int_prs_request       = ((msg_code == `PRS_REQ_TYPE) && (hdr_type[2:0] == 3'b000) && (tlpmsg == `MSG_4) && radm_cfg_o.flt_dwlenEq0  &&  !int_mlf_msg && pcie_format);

  always_comb
  begin: FUNC_NUMBER_LOOKUP
    logic [PF_WD-1:0] tmp_func_num;
    flt_q_outside_mem_range         = 0;
    flt_q_outside_prefmem_range     = 0;
    flt_q_outside_alt_mem_range     = 0;
    flt_q_outside_alt_prefmem_range = 0;
    flt_q_func_num_rc               = `CX_RC_FUNC_NUM;
    tmp_func_num                    = 0;

    if (flt_q_memwr_req) begin             // memory access
      {tmp_func_num, flt_q_outside_mem_range}     = one_hot_decode_2_zero(cfg_mem_match_reg_rc);
      {tmp_func_num, flt_q_outside_prefmem_range} = one_hot_decode_2_zero(cfg_prefmem_match_reg_rc);
      {tmp_func_num, flt_q_outside_alt_mem_range}     = one_hot_decode_2_zero(cfg_cxl_alt_mem_match_reg);
      {tmp_func_num, flt_q_outside_alt_prefmem_range} = one_hot_decode_2_zero(cfg_cxl_alt_prefmem_match_reg);
         // ACS Upstream Forwarding:
        if (radm_cfg_i.cfg_acs_up_forward_cap & radm_cfg_i.cfg_acs_up_forward_en ) begin
          flt_q_outside_mem_range       = 1;
          flt_q_outside_prefmem_range   = 1;
            flt_q_outside_alt_mem_range     = 1;
            flt_q_outside_alt_prefmem_range = 1;
        end
    end
  end


  assign  flt_q_in_membar_range_rc         = (cfg_bar_match_reg_rc[0][0]) ? 0 : (cfg_bar_match_reg_rc[0][1]) ? 1:3'b111;
  assign  flt_q_valid_ur_p_wo_poisoned     = (flt_q_memwr_req || flt_q_tlp_is_msg) && (!flt_q_valid_p_rc);
  assign  flt_q_valid_ur_wo_poisn_err_rc   = flt_q_valid_ur_p_wo_poisoned;  // vendor msg is supported, msg with poison is a ur
  assign  flt_q_valid_ur_err_rc            = flt_q_valid_ur_p;  // UR, including poisoned tlp
  assign error_log_pipe_en_rc              = !radm_cfg_i.upstream_port && (pipe_error_log_en | pipe_error_log_en_reg); //  to flush the ERROR pipe and set error only for a cycle.
    assign enable_mask_pois_if_trgt0_destination_rc = 1;

    assign  flt_q_ecrc_discard_rc      = l_flt_q_ecrc_err & !radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_ECRC_DISCARD]; // when discard an ECRC TLP is desired
    assign  flt_q_poisoned_discard_rc  = flt_q_poisoned_err & !(radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_UR_POIS] & enable_mask_pois_if_trgt0_destination_rc) ;

  always_comb
  begin:  FILTER_PROCESS_RC
    int_flt_q_destination_rc            = `FLT_DESTINATION_TRASH;             // DEFAULT to trash
    if (flt_q_invalid_tlp) begin
      int_flt_q_destination_rc           = `FLT_DESTINATION_TRASH;
    end else begin
      if (l_flt_q_tlp_type[P_TYPE])                                             // [------------- POSTED -------------]
      begin                                                                     //
        if (flt_q_tlp_is_msg & flt_drop_msg_rc)                                 //  MESSAGE will not pass to application
          int_flt_q_destination_rc        = `FLT_DESTINATION_TRASH;             //
        else if (!flt_q_valid_ur_p & !flt_q_valid_ca_p) begin                   // VADID EXCEPT for MESSAGE
          int_flt_q_destination_rc        = `FLT_DESTINATION_TRGT1;             //  ALL (EXCEPT message), valid or not
        end
        else if (radm_cfg_i.default_target)                                     // target determined by default_target
          int_flt_q_destination_rc        = `FLT_DESTINATION_TRGT1;             //  ALL others, valid or not
        else                                                                    //
          int_flt_q_destination_rc        = `FLT_DESTINATION_TRASH;             //

      end
    end      
  end

  logic cpl_req_id_match;
    assign cpl_req_id_match = 1'b1;

  assign latch_hdr_pipe_en_rc = !radm_cfg_i.upstream_port && (ord_flt_data_p_in.ord_flt_dv | hdr_dec_flt_p_in.hdr_dec_flt_hv); 

  // Detect if an access greater than the address bus width occurs
  // Check both the AMBA address bus and Core. Don't do this check here if
  // address translation support is enabled. Need to do it after we get the
  // address back
  logic flt_q_addr_gt_bus_width;
  logic flt_q_addr_gt_mstr_addr_width;
    assign flt_q_addr_gt_bus_width        = 0;
    assign flt_q_addr_gt_mstr_addr_width  = 0;

  //AX subordinate inbound behaviour adding TDISP rules

  assign  flt_q_valid_p_rc           = ((flt_q_mem_req_range_rc && flt_q_memwr_req && valid_ats && flt_q_pcie_valid_tc) || (flt_q_tlp_is_msg && !flt_q_invalid_msg_rc)           // !(poisoned or outrange)
                                       )
                                      ;

    assign  acs_src_valid             = (((flt_q_REQID[15:8] < radm_cfg_i.cfg_2ndbus_num[7:0]) || (flt_q_REQID[15:8] > radm_cfg_i.cfg_subbus_num[7:0])) && !(alt_bus_num_valid && radm_cfg_i.cfg_cxl_alt_bme) && (radm_cfg_i.cfg_acs_validation_cap && radm_cfg_i.cfg_acs_validation_en)) ? 0 : 1;              // If acs_src_valid == 0, an ACS Violation Error is generated
      assign  acs_at_valid            = !(flt_q_memwr_req ) ? 1: (flt_q_ats != 2'b0) && (radm_cfg_i.cfg_acs_at_blocking_cap & radm_cfg_i.cfg_acs_at_blocking_en ) ? 0 : 1;  // If acs_at_valid == 0, an ACS Violation Error is generated
    assign  flt_q_acs_err             = (!acs_src_valid || !acs_at_valid) && flt_q_pcie_format;      // The TLP has an ACS Violation if any of the ACS conditions acs_src_valid or acs_at_valid are not met

    assign  int_ltr_msg_det           = ((msg_code ==`LTR_MSG_CODE)  && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg  && pcie_format);


  always @(posedge core_clk or negedge core_rst_n)
  begin:  MESSAGE_INTERCEPTION_PROCESS_RC_INT
    if (!core_rst_n)
    begin
      flt_q_invalid_msg_rc       <= #TP 1'b0;
      flt_q_vendor_msg0_rc       <= #TP 1'b0;
      flt_q_vendor_msg1_rc       <= #TP 1'b0;
        flt_q_invalidate_msg_rc  <= #TP 1'b0;
        flt_q_prs_request        <= #TP 1'b0;
        flt_q_pcie_good_eot_rc   <= #TP 1'b0;
        ptm_req_msg               <= #TP 1'b0;
        ptm_req_msg_d             <= #TP 1'b0;
    end
    else
    begin
        ptm_req_msg_d                       <= #TP ptm_req_msg;
      flt_q_vendor_msg0_rc                  <= #TP msg_is_vendor_msg0 && tlp_is_msg;
      flt_q_vendor_msg1_rc                  <= #TP msg_is_vendor_msg1 && tlp_is_msg;
      flt_q_invalidate_msg_rc               <= #TP (( int_invalidate_request | int_invalidate_cmplt) && `CX_ATS_ENABLE_VALUE==1)
                                              && tlp_is_msg && !radm_cfg_o.tlp_poisoned;
        flt_q_prs_request                   <= #TP int_prs_request && tlp_is_msg && !radm_cfg_o.tlp_poisoned;
      flt_q_pcie_good_eot_rc                <= #TP ord_flt_data_p_in.ord_flt_eot && pcie_valid_tc && !(ord_flt_data_p_in.ord_flt_dllp_err | radm_ecrc_err_int | radm_cfg_o.tlp_poisoned );

        // DV and HV may not asserted at the same cycle, so we must
        // latch the slot message to assert when payload data is ready

        if (hdr_dec_flt_p_in.hdr_dec_flt_hv & !radm_cfg_o.tlp_poisoned & tlp_is_msg & pcie_valid_tc & !(ord_flt_data_p_in.ord_flt_dllp_err | radm_ecrc_err_int )) begin
          ptm_req_msg             <= #TP int_ptm_req && radm_cfg_i.cfg_ptm_enable;
        end else if (ord_flt_data_p_in.ord_flt_eot & !radm_cfg_o.tlp_poisoned & tlp_is_msg & pcie_valid_tc & !(ord_flt_data_p_in.ord_flt_dllp_err | radm_ecrc_err_int )) begin
          ptm_req_msg             <= #TP ptm_req_msg;
        end else begin
          ptm_req_msg             <= #TP 1'b0;
        end

        flt_q_invalid_msg_rc            <= #TP ~( (pcie_valid_tc &
                                                ((msg_is_vendor_msg0 & radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_VENMSG0_DROP]) | // When vendor 0 is dropped, it'll create a UR
                                                  msg_is_vendor_msg1      |         // VENDOR_MSG1 valid if routing 000b, 010b, 011b or 100b
                                                  int_pm_asnak            |
                                                  int_pm_pme              |
                                                  int_pm_to_ack           |
                                                  int_inta_asserted       |
                                                  int_intb_asserted       |
                                                  int_intc_asserted       |
                                                  int_intd_asserted       |
                                                  int_inta_deasserted     |
                                                  int_intb_deasserted     |
                                                  int_intc_deasserted     |
                                                  int_intd_deasserted     |
                                                  int_err_cor             |
                                                  int_err_nf              |
                                                  int_err_f               |
                                                  int_att_ind_on          |
                                                  int_att_ind_blink       |
                                                  int_att_ind_off         |
                                                  int_pwr_ind_on          |
                                                  int_pwr_ind_blink       |
                                                  int_pwr_ind_off         |
                                                  int_att_button_pressed
                                                                            |
                                                    int_invalidate_request  |
                                                    int_invalidate_cmplt
                                                  // Accept LTR message if LTR mechanism enabled else generate UR
                                                                            |
                                                    (radm_cfg_i.cfg_ltr_m_en & int_ltr_msg_det)
                                                                            |
                                                    (int_ptm_req & radm_cfg_i.cfg_ptm_enable)
                                                                            |
                                                      int_prs_request 
                                                  ))
                                                  )
                                                  & tlp_is_msg & (hdr_dec_flt_p_in.hdr_dec_flt_hv | ord_flt_data_p_in.ord_flt_dv) & ord_flt_data_p_in.ord_flt_eot
                                                  & !(ord_flt_data_p_in.ord_flt_dllp_err | radm_ecrc_err_int | extrct_malfm_tlp_errsts | int_mlf_msg);
    end
  end
    // Generate signals for error messages which will trigger DPC.
    always_comb begin:  ERROR_MESSAGE_FOR_DPC_PROCESS
        pre_dpc_err_nf             = 1'b0;
        pre_dpc_err_f              = 1'b0;
        if (hdr_dec_flt_p_in.hdr_dec_flt_hv & ord_flt_data_p_in.ord_flt_eot & !radm_cfg_o.tlp_poisoned & tlp_is_msg & pcie_valid_tc & !(ord_flt_data_p_in.ord_flt_dllp_err | radm_ecrc_err_int | tmp_mlf_err)) begin
            pre_dpc_err_nf         = int_err_nf & radm_cfg_i.dpc_nonfatal_err_gate;
            pre_dpc_err_f          = int_err_f & radm_cfg_i.dpc_fatal_err_gate;
        end
    end

    assign radm_ptm_req       = ~ptm_req_msg_d  & ptm_req_msg & pcie_valid_tc & !(ord_flt_data_p_in.ord_flt_eot & (ord_flt_data_p_in.ord_flt_dllp_err | radm_ecrc_err_int | extrct_malfm_tlp_errsts | radm_cfg_o.tlp_poisoned ) & !flt_q_unqual_eot_rc);

  delay_n
  
  #(  .N        (PIPE_VF_INDEX), 
      .WD       (PIPE_CFG_WIDTH_RC)
  ) u_cfg_delay_rc
  (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({radm_cfg_tlp_i.cfg_bar_match[5:0], 
                  radm_cfg_i.cfg_bar_is_io[5:0], 
                  radm_cfg_tlp_i.cfg_rom_match[0],  
                  radm_cfg_tlp_i.cfg_mem_match[0],
                  radm_cfg_tlp_i.cfg_prefmem_match[0]
                 }),
    .dout       ({cfg_bar_match_reg_rc, cfg_bar_is_io_reg_rc, cfg_rom_match_reg_rc
                  ,cfg_mem_match_reg_rc
                  ,cfg_prefmem_match_reg_rc
                 })
    );

// Detect when translated address value is greater than the RADM or AMBA master
// address bus widths, report UR.
      assign flt_q_addr_gt_bus_width_at       = 1'b0;
      assign flt_q_addr_gt_mstr_addr_width_at = 1'b0;

  assign flt_q_pipe_en_rc = !radm_cfg_i.upstream_port && ((|l_flt_q_hv) || (|l_flt_q_dv)); // delay_n_w_enable should handle inside enable_delayed signal to flush the pipe

  assign  flt_drop_msg_rc           = (!radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_MSG_DROP] & !(flt_q_vendor_msg | flt_q_invalidate_msg_rc 
                                        | flt_q_prs_request
                                       ))
                                        || (!radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_VENMSG0_DROP] & flt_q_vendor_msg0_rc)
                                        || ((!radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_VENMSG1_DROP] & flt_q_vendor_msg1_rc)
                                        )
                                        || (radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_PRS_DROP] & !radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_MSG_DROP] & flt_q_prs_request)
                                       ;

  // CTRL_registers_path
  always_ff @(posedge core_clk or negedge core_rst_n)
  begin  
    if (!core_rst_n) begin
      flt_q_unqual_dv_rc  <= #TP 0;
      flt_q_unqual_hv_rc  <= #TP 0;
      flt_q_unqual_eot_rc <= #TP 0;
    end else if(!radm_cfg_i.upstream_port) begin
      flt_q_unqual_dv_rc  <= #TP ord_flt_data_p_in.ord_flt_dv;
      flt_q_unqual_hv_rc  <= #TP hdr_dec_flt_p_in.hdr_dec_flt_hv;
      flt_q_unqual_eot_rc <= #TP ord_flt_data_p_in.ord_flt_eot;
    end
  end



  assign  flt_q_mem_req_range_rc     =  (radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_UR_OUTSIDE_BAR] ||
                                        (flt_q_mem_req_in_range
                                        )
                                        || flt_q_outside_alt_range
                                        || (flt_q_outside_mem_range && flt_q_outside_prefmem_range && !(radm_cfg_i.cfg_cxl_alt_bme & alt_bus_num_valid)) && 
                                        !(flt_q_addr_gt_mstr_addr_width || flt_q_addr_gt_bus_width) 
                                        );

  assign  int_inta_asserted       = ((msg_code == `ASSERT_INTA)    && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
  assign  int_intb_asserted       = ((msg_code == `ASSERT_INTB)    && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
  assign  int_intc_asserted       = ((msg_code == `ASSERT_INTC)    && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
  assign  int_intd_asserted       = ((msg_code == `ASSERT_INTD)    && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
  assign  int_inta_deasserted     = ((msg_code == `DEASSERT_INTA)  && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
  assign  int_intb_deasserted     = ((msg_code == `DEASSERT_INTB)  && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
  assign  int_intc_deasserted     = ((msg_code == `DEASSERT_INTC)  && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
  assign  int_intd_deasserted     = ((msg_code == `DEASSERT_INTD)  && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
  assign  flt_q_cpl_status_rc     = ( flt_q_valid_ur_p) ? `UR_CPL_STATUS : ( flt_q_valid_ca_p) ? `CA_CPL_STATUS: `SU_CPL_STATUS;
  assign  int_err_cor             = ((msg_code == `ERR_COR)                     && (hdr_type[2:0] == 3'b000) && (tlpmsg == `MSG_4) && !int_mlf_msg  && pcie_format);
  assign  int_err_nf              = ((msg_code == `ERR_NF)                      && (hdr_type[2:0] == 3'b000) && (tlpmsg == `MSG_4) && !int_mlf_msg  && pcie_format);
  assign  int_err_f               = ((msg_code == `ERR_F)                       && (hdr_type[2:0] == 3'b000) && (tlpmsg == `MSG_4) && !int_mlf_msg  && pcie_format);
                                      
  
//// END_OF_RC 


    // The VDM message payload is defined from bytes 12 to byte 15.
    // To be consistent with the format on the RTRGT1 address bus the byte  order is reversed.
    // DW3 output on bits [63:32], DW4 output on [31:0].
    assign  radm_msg_payload_ep = (flt_q_vendor_msg) ?
                                          {flt_q_hdr_dw3[7:0],flt_q_hdr_dw3[15:8],flt_q_hdr_dw3[23:16],flt_q_hdr_dw3[31:24],
                                          flt_q_hdr_dw4[7:0],flt_q_hdr_dw4[15:8],flt_q_hdr_dw4[23:16],flt_q_hdr_dw4[31:24]} :
                                          {32'b0, chk_l_flt_q_data[31:0]};

    assign radm_cfg_o_int.radm_rcvd_req_ca           = radm_rcvd_req_ca_int;
    assign radm_cfg_o_int.radm_rcvd_req_ur           = radm_rcvd_req_ur_int;
    assign radm_cfg_o_int.radm_rcvd_wreq_poisoned    = radm_rcvd_wreq_poisoned_int;
    assign radm_cfg_o_int.radm_hdr_log_valid         = radm_hdr_log_valid_int;


  always_ff @(posedge core_clk or negedge core_rst_n)
  begin:  MESSAGE_INTERCEPTION_PROCESS_EP
    if (!core_rst_n)
    begin
        radm_cfg_o_int.radm_pm_turnoff            <= #TP 1'b0;
        radm_cfg_o_int.radm_msg_unlock            <= #TP 1'b0;
      radm_cfg_o_int.radm_slot_pwr_limit          <= #TP 1'b0;
        radm_cfg_o_int.radm_msg_obff              <= #TP 1'b0;
        radm_cfg_o_int.radm_msg_cpu_active        <= #TP 1'b0;
        radm_cfg_o_int.radm_msg_idle              <= #TP 1'b0;
    end
    else
    begin

      if (hdr_dec_flt_p_in.hdr_dec_flt_hv && !(ord_flt_data_p_in.ord_flt_dllp_err | radm_ecrc_err_int | extrct_malfm_tlp_errsts)
          && ord_flt_data_p_in.ord_flt_eot && !radm_cfg_o.tlp_poisoned && tlp_is_msg && pcie_valid_tc) begin
          radm_cfg_o_int.radm_pm_turnoff       <= #TP  int_pm_turnoff;
          radm_cfg_o_int.radm_msg_unlock       <= #TP  int_msg_unlock;
          radm_cfg_o_int.radm_slot_pwr_limit   <= #TP radm_cfg_i.upstream_port  && msg_is_slotpwr && dwlenEq1;
          radm_cfg_o_int.radm_msg_idle         <= #TP radm_cfg_i.cfg_obff_en && int_obff_msg && (obff_code == IDLE);
          radm_cfg_o_int.radm_msg_obff         <= #TP radm_cfg_i.cfg_obff_en && int_obff_msg && (obff_code == OBFF);
          // An obff message where the obff_code is anything other
          // than IDLE or OBFF is treated as CPU_ACTIVE.
          radm_cfg_o_int.radm_msg_cpu_active   <= #TP radm_cfg_i.cfg_obff_en && int_obff_msg && ((obff_code != IDLE) && (obff_code != OBFF));
      end else begin
          radm_cfg_o_int.radm_pm_turnoff       <= #TP 1'b0;
          radm_cfg_o_int.radm_msg_unlock       <= #TP 1'b0;
          radm_cfg_o_int.radm_slot_pwr_limit   <= #TP 1'b0;
          radm_cfg_o_int.radm_msg_obff         <= #TP 1'b0;
          radm_cfg_o_int.radm_msg_cpu_active   <= #TP 1'b0;
          radm_cfg_o_int.radm_msg_idle         <= #TP 1'b0;
      end

    end
  end


    assign radm_cfg_o_int.radm_ptm_res_msg       = ~ptm_res_msg_d  & ptm_res_msg  & pcie_valid_tc & !(ord_flt_data_p_in.ord_flt_eot & (ord_flt_data_p_in.ord_flt_dllp_err | radm_ecrc_err_int | extrct_malfm_tlp_errsts | radm_cfg_o.tlp_poisoned ) & !flt_q_unqual_eot);
    assign radm_cfg_o_int.radm_ptm_res_d_msg     = ~ptm_resD_msg_d & ptm_resD_msg & pcie_valid_tc & !(ord_flt_data_p_in.ord_flt_eot & (ord_flt_data_p_in.ord_flt_dllp_err | radm_ecrc_err_int | extrct_malfm_tlp_errsts | radm_cfg_o.tlp_poisoned ) & !flt_q_unqual_eot); 
    assign radm_cfg_o_int.radm_ptm_master_time   = ptm_master_time_reg;
    assign radm_cfg_o_int.radm_ptm_prop_delay    = ptm_prop_delay_reg;




  

  always_ff @(posedge core_clk or negedge core_rst_n)
  begin
    if(!core_rst_n)
      int_app_req_retry_en    <= #TP 0;
    else
      int_app_req_retry_en    <= #TP app_req_retry_en;
  end

  
  always_ff @(posedge core_clk or negedge core_rst_n)
  begin: APP_PF_REQ_RETRY
    integer j;
    if (!core_rst_n) begin
      int_app_pf_req_retry_en           <= #TP 0;
    end else begin
      for (j=0; j<NF; j=j+1) begin
        int_app_pf_req_retry_en[j]      <= #TP app_pf_req_retry_en[j];
      end // for j
    end
  end


  assign app_req_retry_en_tmp         = int_app_req_retry_en   || ((raw_flt_q_func_num < NF) && int_app_pf_req_retry_en[raw_flt_q_func_num[ALT_PF_WD-1:0]])
 ;



    assign obff_code                = hdr_dw4[27:24];

  assign  msg_is_slotpwr            = ((hdr_dw2[31:24] == `SET_SLOT_PWR_LIMIT) && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSGD_4) && !int_mlf_msg && pcie_format);

    assign  int_ptm_res             = ((msg_code == `PTM_RES_TYPE) && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
    assign  int_ptm_resD            = ((msg_code == `PTM_RES_TYPE) && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSGD_4) && dwlenEq1 && !int_mlf_msg && pcie_format);
    assign  ptm_master_time         = {hdr_dw3[7:0], hdr_dw3[15:8], hdr_dw3[23:16], hdr_dw3[31:24], hdr_dw4[7:0], hdr_dw4[15:8], hdr_dw4[23:16], hdr_dw4[31:24]};
    assign  ptm_prop_delay          = ord_flt_data_p_in.ord_flt_data[31:0];
  
    assign  int_prg_response        = ((msg_code == `PRG_RES_TYPE) && (hdr_type[2:0] == 3'b010) && (tlpmsg == `MSG_4) && radm_cfg_o.flt_dwlenEq0  &&  !int_mlf_msg && pcie_format);

  assign enable_mask_pois_if_trgt0_destination_ep  = !(radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_UNMASK_UR_POIS_TRGT0] && (target_acquisition_ep == `FLT_DESTINATION_TRGT0));



    assign pf = flt_q_cfg_func_num;

  always_comb begin 
    target_acquisition_ep         = `FLT_DESTINATION_TRASH;
    if (flt_q_mem_req) begin // MEMORY (or ROM)
      if (flt_q_rcrb_req_in_range) begin
          target_acquisition_ep   =  `FLT_DESTINATION_TRGT0;
      end
      else
      if (flt_q_mem_req_in_range)
        if (mem_trgt_map)
          target_acquisition_ep   =  `FLT_DESTINATION_TRGT1;
        else

      target_acquisition_ep       =  `FLT_DESTINATION_TRGT0;
    else if (flt_q_rom_req_in_range)
        if (rom_trgt_map)
          target_acquisition_ep   =  `FLT_DESTINATION_TRGT1;
        else
      target_acquisition_ep       =  `FLT_DESTINATION_TRGT0;
    else if (radm_cfg_i.default_target)
      target_acquisition_ep       =  `FLT_DESTINATION_TRGT1;
    else
      target_acquisition_ep       =  `FLT_DESTINATION_TRGT0;
    end    // Mem transactions
  end
  assign  msg_req      = PIPE_VF_INDEX == 1 ? tlp_is_msg && (hdr_type[2:0]==3'b010) :
                                              flt_q_tlp_is_msg && (flt_q_type[2:0] == 3'b010) ;
    assign raw_func_num_unreg   = mem_req   ?  pfvf_func_num  :
                                  msg_req   ?  pf             : 'd0;

  // If PIPE_VF_INDEX==1, cfg_*match are anticipated by one cycle
  // and so are function and bar numbers.
  // We need to delay them in order to align to flt_q* domain
  delay_n
  
  #(  .N          (PIPE_VF_INDEX), 
      .WD         (PIPE_VF_INDEX_WIDTH)
  ) u_vf_index_delay
  (
      .clk        (core_clk),
      .rst_n      (core_rst_n),
      .clear      (1'b0),
      .din        ({raw_func_num_unreg, in_membar_range_unreg  
                    }),
      .dout       ({raw_flt_q_func_num, in_membar_range  
                   })
    );

  delay_n
  
  #(  .N        (PIPE_VF_INDEX), 
      .WD       (PIPE_CFG_WIDTH_EP)
  ) u_cfg_delay_ep
  (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({radm_cfg_tlp_i.cfg_bar_match, radm_cfg_i.cfg_bar_is_io, radm_cfg_tlp_i.cfg_rom_match  
                   ,
                   coerce_cfg_tlp_to_trgt1_int
                 }),
    .dout       ({cfg_bar_match_reg_ep, cfg_bar_is_io_reg_ep, cfg_rom_match_reg_ep
                   , 
                   coerce_cfg_tlp_to_trgt1
                 })
    );

  assign raw_flt_q_in_membar_range =
                                                           (flt_q_mem_req ) ? in_membar_range    :
                                                           `RADM_OUTSIDE_MEMBAR;

  // If a UR is due to a function specific error then the function number of the
  // targeted function is used in the Completer ID of the Completion TLP.
  // If a UR is due to a non-function specific error then the Completion is not
  // associated with a specific function within the device and the function
  // number is Reserved (i.e. the function number field of the Completer ID is
  // set to all 0s).
  // set membar to outside range if this is a UR
  assign  flt_q_func_num_ep                   = flt_q_outrange_ur ? 0 : raw_flt_q_func_num;
  assign  flt_q_in_membar_range_ep            = ( flt_q_valid_ur_p | flr_in_progress) ? `RADM_OUTSIDE_MEMBAR : raw_flt_q_in_membar_range;

  // derive the signals used for error log
  assign  flt_q_valid_ur_xtrash_wo_poisn      = ( flt_q_ur_p_wo_poisn) && (flt_q_destination == `FLT_DESTINATION_TRASH);
  assign  flt_q_valid_ur_xtrgt0_wo_poisn      = ( flt_q_ur_p_wo_poisn) && (flt_q_destination == `FLT_DESTINATION_TRGT0);
  assign  flt_q_valid_ur_xtrgt1_wo_poisn      = ( flt_q_ur_p_wo_poisn) && (flt_q_destination == `FLT_DESTINATION_TRGT1) && !(radm_cfg_i.ur_ca_mask_4_trgt1); // this `define will mask out the report of UR or CA
  assign  flt_q_valid_ur_wo_poisn_err_ep      = flt_q_valid_ur_xtrgt0_wo_poisn || flt_q_valid_ur_xtrgt1_wo_poisn || flt_q_valid_ur_xtrash_wo_poisn  || flr_in_progress;// UR, assuming no poisoned tlp

  assign  flt_q_valid_ur_err_ep               = flt_q_valid_ur_xtrgt0 || flt_q_valid_ur_xtrgt1 || flt_q_valid_ur_xtrash  || flr_in_progress;

  assign error_log_pipe_en_ep  = radm_cfg_i.upstream_port && (pipe_error_log_en | pipe_error_log_en_reg); //  to flush the ERROR pipe and set error only for a cycle.

  assign flt_q_pipe_en_ep      = radm_cfg_i.upstream_port && ((|l_flt_q_hv) || (|l_flt_q_dv)); // delay_n_w_enable should handle inside enable_delayed signal to flush the pipe

// KARAM
  assign  flt_drop_msg_ep            = (!radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_MSG_DROP] & !(flt_q_vendor_msg || flt_q_invalidate_msg_ep 
                                        || flt_q_prg_response
                                       )) ||
                                       (!radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_VENMSG0_DROP] & flt_q_vendor_msg0_ep) ||
                                       pf_hidden_for_vendor_msg0 ||
                                       ((!radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_VENMSG1_DROP] & flt_q_vendor_msg1_ep) 
                                       )
                                       || pf_hidden_for_vendor_msg1 
                                        || (radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_PRS_DROP] & !radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_MSG_DROP] & flt_q_prg_response)
                                       ;


  assign  flt_q_ecrc_discard_ep      = l_flt_q_ecrc_err & !radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_ECRC_DISCARD]; // when discard an ECRC TLP is desired
  assign  flt_q_poisoned_discard_ep  = flt_q_poisoned_err & !(radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_UR_POIS] & enable_mask_pois_if_trgt0_destination_ep);

  always_comb begin:  FILTER_PROCESS
    int_flt_q_destination_ep               = `FLT_DESTINATION_TRASH;            // DEFAULT to trash
    if (flt_q_invalid_tlp) begin
      int_flt_q_destination_ep           = `FLT_DESTINATION_TRASH;
    end else begin
      if (l_flt_q_tlp_type[P_TYPE])  begin                                        // [------------- POSTED -------------]
        if (flt_q_tlp_is_msg & (flt_drop_msg_ep | flt_q_valid_ur_p | flt_q_valid_ca_p | flr_in_progress))// (message)
          int_flt_q_destination_ep           = `FLT_DESTINATION_TRASH;
        else if (flt_q_tlp_is_msg )                                               // (message)
          int_flt_q_destination_ep           = `FLT_DESTINATION_TRGT1;
      else if (!flt_q_valid_ur_p & !flr_in_progress & !flt_q_valid_ca_p)                      // VALID
        int_flt_q_destination_ep             = target_acquisition;                            // target determined by bar-mapping
      else if (radm_cfg_i.default_target)                                                     // target determined by radm_cfg_i.default_target
        int_flt_q_destination_ep             = `FLT_DESTINATION_TRGT1;
      else      
        int_flt_q_destination_ep             = `FLT_DESTINATION_TRASH;
      end
    end
  end

  // -----------------------------------------------------------------------------
  // output drives
  // -----------------------------------------------------------------------------
  // CTRL_registers_path
  always_ff @(posedge core_clk or negedge core_rst_n)
  begin  
    if (!core_rst_n) begin
      flt_q_unqual_dv_ep    <= #TP 0;
      flt_q_unqual_hv_ep    <= #TP 0;
      flt_q_unqual_eot_ep   <= #TP 0;
    end else if(radm_cfg_i.upstream_port) begin
      flt_q_unqual_dv_ep    <= #TP ord_flt_data_p_in.ord_flt_dv;
      flt_q_unqual_hv_ep    <= #TP hdr_dec_flt_p_in.hdr_dec_flt_hv;
      flt_q_unqual_eot_ep   <= #TP ord_flt_data_p_in.ord_flt_eot;
    end
  end


  assign latch_hdr_pipe_en_ep = radm_cfg_i.upstream_port && (ord_flt_data_p_in.ord_flt_dv | hdr_dec_flt_p_in.hdr_dec_flt_hv); 

  assign pm_block_tlp         =  get_pm_block(radm_cfg_i.pm_radm_block_tlp,raw_flt_q_func_num);

  assign  flt_q_mem_req_range_ep       =  (radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_UR_OUTSIDE_BAR] ||
                                          (flt_q_mem_req_in_range
                                            || flt_q_rcrb_req_in_range
                                            || flt_q_rom_req_in_range
                                          )
                                          );
  assign  flt_q_pm_radm_block_tlp      = !(radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_UR_OUTSIDE_BAR    ] || !pm_block_tlp);

    assign flr_pf_in_progress   = 0;
    assign flr_vf_in_progress   = 0;
  
  // In order to avoid dropping Messages which have the Routing Type set to, for example Broadcast,
  // we need to include only Messages with Routing ID = Route by ID;
  // so, if the TLP is a MSG TLP, only Routed by ID are affected by FLR in Progress:
  assign flr_in_progress      = (flr_pf_in_progress | flr_vf_in_progress) && ((flt_q_type[4:3] != 2'b10) || (flt_q_type[2:0] == 3'b010)); 


    assign pf_hidden_for_vendor_msg0  = 1'b0;
    assign pf_hidden_for_vendor_msg1  = 1'b0;

  assign  flt_q_outrange_ur_int          = (!flt_q_mem_req_range_ep && (flt_q_memwr_req ))  ||
                                       ( pf_hidden_for_vendor_msg0 || 
                                       (flt_q_tlp_is_msg    && flt_q_invalid_msg_ep      && !(flt_q_vendor_msg_id_match && (flt_q_type[2:0]==3'b010))));
   
  assign  flt_q_valid_p_ep           = (((flt_q_mem_req_range_ep ) && flt_q_memwr_req &&
                                      flt_q_pcie_valid_tc &&
                                      !flt_q_pm_radm_block_tlp && valid_ats)
                                      | (flt_q_tlp_is_msg && 
                                      !flt_q_invalid_msg_ep && !pf_hidden_for_vendor_msg0)
                                      )
                                      ;


  assign  flt_q_ur_p_wo_poisn        = (flt_q_memwr_req | flt_q_tlp_is_msg) && (!flt_q_valid_p_ep);

    assign  int_vendor_msg_id_match        = vendor_msg_id_match_int; 
    assign  flt_q_vendor_msg_id_match      = int_flt_q_vendor_msg_id_match;
    assign  flt_q_invalid_msg_ep           = int_flt_q_invalid_msg;

// SANJAY
//

  always_ff @(posedge core_clk or negedge core_rst_n)
  begin:  MESSAGE_INTERCEPTION_PROCESS
    if (!core_rst_n)
    begin
        flt_q_obff_msg                        <= #TP 1'b0;
      int_flt_q_invalid_msg                   <= #TP 1'b0;
      int_flt_q_vendor_msg_id_match           <= #TP 1'b0;
      flt_q_vendor_msg0_ep                    <= #TP 1'b0;
      flt_q_vendor_msg1_ep                    <= #TP 1'b0;
      flt_q_invalidate_msg_ep                 <= #TP 1'b0;
        flt_q_prg_response                    <= #TP 1'b0;
      flt_q_pcie_good_eot_ep                  <= #TP 1'b0;
        ptm_res_msg                           <= #TP 1'b0;
        ptm_resD_msg                          <= #TP 1'b0;
        ptm_res_msg_d                         <= #TP 1'b0;
        ptm_resD_msg_d                        <= #TP 1'b0;
        ptm_master_time_reg                   <= #TP 0; 
        ptm_prop_delay_reg                    <= #TP 0; 
    end
    else
    begin
        ptm_res_msg_d                      <= #TP ptm_res_msg;
        ptm_resD_msg_d                     <= #TP ptm_resD_msg; 
      flt_q_vendor_msg0_ep                 <= #TP msg_is_vendor_msg0 && tlp_is_msg;
      flt_q_vendor_msg1_ep                 <= #TP msg_is_vendor_msg1 && tlp_is_msg;
        flt_q_obff_msg                     <= #TP (int_obff_msg && tlp_is_msg);
      flt_q_invalidate_msg_ep              <= #TP ((int_invalidate_request | int_invalidate_cmplt) && `CX_ATS_ENABLE_VALUE==1)
                                                && tlp_is_msg && !radm_cfg_o.tlp_poisoned;
      flt_q_pcie_good_eot_ep               <= #TP ord_flt_data_p_in.ord_flt_eot && pcie_valid_tc && !(ord_flt_data_p_in.ord_flt_dllp_err | radm_ecrc_err_int  | radm_cfg_o.tlp_poisoned);

        flt_q_prg_response                 <= #TP int_prg_response && tlp_is_msg && !radm_cfg_o.tlp_poisoned;

        if (hdr_dec_flt_p_in.hdr_dec_flt_hv && !(ord_flt_data_p_in.ord_flt_dllp_err | radm_ecrc_err_int | extrct_malfm_tlp_errsts)
            && !radm_cfg_o.tlp_poisoned && tlp_is_msg && pcie_valid_tc) begin
          ptm_res_msg                   <= #TP int_ptm_res && radm_cfg_i.cfg_ptm_enable; 
          ptm_resD_msg                  <= #TP int_ptm_resD && radm_cfg_i.cfg_ptm_enable;
          ptm_master_time_reg           <= #TP ptm_master_time;
          ptm_prop_delay_reg            <= #TP ptm_prop_delay; 
        end else if (!(ord_flt_data_p_in.ord_flt_dllp_err | radm_ecrc_err_int | extrct_malfm_tlp_errsts)
                      && ord_flt_data_p_in.ord_flt_eot && !radm_cfg_o.tlp_poisoned && tlp_is_msg && pcie_valid_tc) begin
          ptm_res_msg                   <= #TP ptm_res_msg;
          ptm_resD_msg                  <= #TP ptm_resD_msg;
          ptm_master_time_reg           <= #TP ptm_master_time_reg; 
          ptm_prop_delay_reg            <= #TP ptm_prop_delay_reg; 
        end else begin      
          ptm_res_msg                   <= #TP 1'b0;
          ptm_resD_msg                  <= #TP 1'b0;
          ptm_master_time_reg           <= #TP 0; 
          ptm_prop_delay_reg            <= #TP 0; 
        end

      int_flt_q_invalid_msg                <= #TP ~((pcie_valid_tc &
                                                   (((msg_is_vendor_msg0 & radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_VENMSG0_DROP])// When vendor 0 is dropped, it'll create a UR
                                                    & (
                                                      (hdr_type[2:0] == 3'b010 & int_vendor_msg_id_match) |
                                                    (hdr_type[2:0] == 3'b011) | (hdr_type[2:0] == 3'b100)))  |
                                                    msg_is_vendor_msg1           |         // VENDOR_MSG1 valid if routing 000b, 010b, 011b or 100b
                                                    (msg_is_slotpwr & dwlenEq1)  |
                                                    (int_msg_unlock)             |
                                                    (int_pm_asnak  )             |
                                                    (int_pm_turnoff)             |
                                                    int_att_ind_on               |
                                                    int_att_ind_blink            |
                                                    int_att_ind_off              |
                                                    int_pwr_ind_on               |
                                                    int_pwr_ind_blink            |
                                                    int_att_button_pressed       |
                                                    int_pwr_ind_off
                                                                                 |
                                                      (int_obff_msg & radm_cfg_i.cfg_obff_en)
                                                                                 |
                                                      int_invalidate_request     |
                                                      int_invalidate_cmplt
                                                                                 |
                                                      int_ptm_res                |
                                                      int_ptm_resD
                                                                                 |
                                                        (int_prg_response & int_vendor_msg_id_match)
                                                  )
                                                )
                                                )
                                                && (hdr_dec_flt_p_in.hdr_dec_flt_hv | ord_flt_data_p_in.ord_flt_dv) && ord_flt_data_p_in.ord_flt_eot  && tlp_is_msg
                                                && !(ord_flt_data_p_in.ord_flt_dllp_err | radm_ecrc_err_int | extrct_malfm_tlp_errsts | int_mlf_msg);

      int_flt_q_vendor_msg_id_match     <= #TP int_vendor_msg_id_match;
    end
  end

  assign  flt_q_actual_cpl_status =   (flt_q_valid_ur_p | flr_in_progress)  ? `UR_CPL_STATUS :     // when it is invalid ur, it is
                                                         (flt_q_valid_ca_p) ? `CA_CPL_STATUS                                                                        // the CA status: 1. TRGT0 is the destination and more than 1 dword is
                                                                            // being requested. This is a limitation of current LBC module.
                                                                            // 2. when ecrc detected and it is non posted TLP
                                                                             : `SU_CPL_STATUS;
  assign  flt_q_cpl_status_ep     = (((int_flt_q_destination[1:0] == `FLT_DESTINATION_TRGT0) && app_req_retry_en_tmp) ? `UR_CPL_STATUS   : flt_q_actual_cpl_status);


// End of EP

  //assign  radm_cfg_o.flt_cdm_addr   = form_filt_ant_addr;

  assign  radm_cfg_o.tlp_poisoned   = (hdr_dw1[22] & pcie_format) || (ord_flt_data_p_in.ord_flt_eot && ord_flt_data_p_in.ord_flt_poisoned);



always @(posedge core_clk or negedge core_rst_n)
begin:  MESSAGE_INTERCEPTION_PROCESS_RC
  if (!core_rst_n)
  begin
      radm_cfg_o.radm_pm_asnak                  <= #TP 1'b0;
    radm_cfg_o.radm_pm_to_ack                   <= #TP 1'b0;
    radm_cfg_o_int.int_radm_pm_pme              <= #TP 'd0;
      radm_cfg_o_int.radm_inta_asserted         <= #TP 1'b0;
      radm_cfg_o_int.radm_intb_asserted         <= #TP 1'b0;
      radm_cfg_o_int.radm_intc_asserted         <= #TP 1'b0;
      radm_cfg_o_int.radm_intd_asserted         <= #TP 1'b0;
      radm_cfg_o_int.radm_inta_deasserted       <= #TP 1'b0;
      radm_cfg_o_int.radm_intb_deasserted       <= #TP 1'b0;
      radm_cfg_o_int.radm_intc_deasserted       <= #TP 1'b0;
      radm_cfg_o_int.radm_intd_deasserted       <= #TP 1'b0;
      radm_cfg_o_int.radm_err_cor               <= #TP 1'b0;
      radm_cfg_o_int.radm_err_nf                <= #TP 1'b0;
      radm_cfg_o_int.radm_err_f                 <= #TP 1'b0;
        radm_cfg_o_int.radm_msg_ltr             <= #TP 1'b0;
  end
  else
  begin

    if (hdr_dec_flt_p_in.hdr_dec_flt_hv & ord_flt_data_p_in.ord_flt_eot & !radm_cfg_o.tlp_poisoned  & tlp_is_msg & pcie_valid_tc & !(ord_flt_data_p_in.ord_flt_dllp_err | radm_ecrc_err_int | extrct_malfm_tlp_errsts )) begin
  //EHERE
        radm_cfg_o.radm_pm_asnak                <= #TP  int_pm_asnak            ;
      radm_cfg_o.radm_pm_to_ack                 <= #TP  int_pm_to_ack           ;
      radm_cfg_o_int.int_radm_pm_pme            <= #TP  int_pm_pme              ;
        radm_cfg_o_int.radm_inta_asserted       <= #TP  int_inta_asserted       ;
        radm_cfg_o_int.radm_intb_asserted       <= #TP  int_intb_asserted       ;
        radm_cfg_o_int.radm_intc_asserted       <= #TP  int_intc_asserted       ;
        radm_cfg_o_int.radm_intd_asserted       <= #TP  int_intd_asserted       ;
        radm_cfg_o_int.radm_inta_deasserted     <= #TP  int_inta_deasserted     ;
        radm_cfg_o_int.radm_intb_deasserted     <= #TP  int_intb_deasserted     ;
        radm_cfg_o_int.radm_intc_deasserted     <= #TP  int_intc_deasserted     ;
        radm_cfg_o_int.radm_intd_deasserted     <= #TP  int_intd_deasserted     ;
        radm_cfg_o_int.radm_err_cor             <= #TP  int_err_cor             ;
        radm_cfg_o_int.radm_err_nf              <= #TP  int_err_nf              ;
        radm_cfg_o_int.radm_err_f               <= #TP  int_err_f               ;
          radm_cfg_o_int.radm_msg_ltr           <= #TP  (int_ltr_msg_det & radm_cfg_i.cfg_ltr_m_en);
    end
    else
    begin
        radm_cfg_o.radm_pm_asnak                <= #TP 1'b0;
        radm_cfg_o.radm_pm_to_ack               <= #TP 1'b0;
        radm_cfg_o_int.int_radm_pm_pme          <= #TP 'd0;
        radm_cfg_o_int.radm_inta_asserted       <= #TP 1'b0;
        radm_cfg_o_int.radm_intb_asserted       <= #TP 1'b0;
        radm_cfg_o_int.radm_intc_asserted       <= #TP 1'b0;
        radm_cfg_o_int.radm_intd_asserted       <= #TP 1'b0;
        radm_cfg_o_int.radm_inta_deasserted     <= #TP 1'b0;
        radm_cfg_o_int.radm_intb_deasserted     <= #TP 1'b0;
        radm_cfg_o_int.radm_intc_deasserted     <= #TP 1'b0;
        radm_cfg_o_int.radm_intd_deasserted     <= #TP 1'b0;
        radm_cfg_o_int.radm_err_cor             <= #TP 1'b0;
        radm_cfg_o_int.radm_err_nf              <= #TP 1'b0;
        radm_cfg_o_int.radm_err_f               <= #TP 1'b0;
        radm_cfg_o_int.radm_msg_ltr             <= #TP 1'b0;
    end
  end
end


      // ATU Header valid and EoT pipeline 
      always_ff @(posedge core_clk or negedge core_rst_n)
      begin  
        if (!core_rst_n) begin
          radm_flt_atu_hv  <= #TP 0;
          radm_flt_atu_eot <= #TP 0;
        end else begin
          radm_flt_atu_hv  <= #TP hdr_dec_flt_p_in.hdr_dec_flt_hv;
          radm_flt_atu_eot <= #TP (hdr_dec_flt_p_in.hdr_dec_flt_hv | ord_flt_data_p_in.ord_flt_dv) && ord_flt_data_p_in.ord_flt_eot;
        end
      end
      assign  radm_flt_atu_out.r_rombar_out        = flt_q_rom_req_in_range;
      assign  radm_flt_atu_out.r_addr_out          = flt_q_addr_tph[63:0];
       assign  radm_flt_atu_out.r_func_out         = device_is_ep ? ({{(8-PF_WD){1'b0}}, raw_flt_q_func_num}) : ({{(8-PF_WD){1'b0}}, flt_q_func_num});
      assign  radm_flt_atu_out.r_type_out          = flt_q_type[4:0];
      assign  radm_flt_atu_out.r_bar_out           = flt_q_in_membar_range[2:0];
      assign  radm_flt_atu_out.r_tc_out            = flt_q_tc;
      assign  radm_flt_atu_out.r_td_out            = flt_q_hdr_dw1[23];
      assign  radm_flt_atu_out.r_attr_out          = flt_q_attr;
        assign    radm_flt_atu_out.r_at_out        = flt_q_ats;
        assign  radm_flt_atu_out.r_msgcode_out     = flt_q_msg_code;  
        assign  radm_flt_atu_out.r_th_out          = flt_q_th;
        assign  radm_flt_atu_out.r_ph_out          = flt_q_ph;
        assign  radm_flt_atu_out.r_st_out          = flt_q_st;
      assign  radm_flt_atu_out.r_dw_len_out        = flt_q_dw_len;

           ras_dp_pipe
            #(
                .PIPELINE_TYPE           (0),                  // No pipeline only checker instance
                .RESETVAL                (0),                  
                .N_STAGES                (0),                  
                .CAN_STALL               (0),                  
                .RESET_STALL             (0),                  
                .BUS_PROTECT_GEN_EN      (1),                   
                .BUS_PROTECT_CHK_EN      (0),                  
                .PROT_TYPE               (PROT_TYPE),          // cc
                .PROT_RANGE              (PROT_RANGE),         // cc
                .PROT_WD                 (ATU_IPIPE_PROT_WD),
                .PARITY_MODE             (PARITY_MODE),        // cc
                .PROT_CORRECT_EN         (PROT_CORRECT_EN),    // cc
                .TOTAL_WIDTH             ($bits(radm_flt_atu_s)),             
                .EXCLUDE_PROT_WIDTH      (0),
                .RAS_DP_PROT_CHK_ID_BASE (0)
            ) u_ras_dp_pipe_gen_atu_hdr (
                .clk      (core_clk           ),
                .rst_n    (core_rst_n         ),
                .en       (1'b1               ),
                .bypass   (1'b0               ),
                .stall    (1'b0               ),
                .stallout (                   ),
                
                .valid_in (1'b1               ),
                .din      (radm_flt_atu_out ),
                .din_prot ('0                  ),
                .halt_out (                   ),
                
                .valid_out(                   ),
                .dout     (                   ),
                .dout_prot(radm_flt_atu_hdr_prot ),
                .halt_in  (1'b0               ),
                .ras_dp_err_inband_kbd_in(1'b0),
                .ras_dp_err_inband_kbd_out(   ),
                .ras_dp_err_log  ()
                ,
                .ras_dp_err_inj  (ras_dp_err_inj)
                );


  assign  radm_cfg_o.flt_dwlenEq0       = !(|dw_len);                             // dw_len == 10'b0
  //assign radm_cfg_o.radm_ecrc_err       = {NF{set_radm_ecrc_err}};
  //assign radm_cfg_o.radm_mlf_tlp_err    = {NF{set_radm_mlf_tlp_err}};
  assign radm_cfg_o.radm_ecrc_err       = set_radm_ecrc_err;
  assign radm_cfg_o.radm_mlf_tlp_err    = set_radm_mlf_tlp_err;  
    assign radm_cfg_o.radm_mlf_tlp_err_ptr       = set_radm_mlf_tlp_err_ptr;


  // for short Vendor message, we can send to SII interface
  //--------------------------------
  // Extract SII message header info
  //--------------------------------
  assign  radm_cfg_o.radm_vendor_msg  = ((flt_q_vendor_msg && flt_q_pcie_good_eot && !(tmp_mlf_err))
 );

//inidcating the type of vendor message
// if radm_vendor_msg is high: radm_vendor_msg_type 1 indicate VDM type 1 message
// else VDM Type 0 message
//do not have any significance if radm_vendor_msg is low
assign    radm_cfg_o.radm_vendor_msg_type = (flt_q_vendor_msg1 && flt_q_pcie_good_eot && !(tmp_mlf_err))
                                            ;
                                            


  assign  radm_cfg_o.radm_rcvd_tlp_req_id = flt_q_REQID;
  //  ---------------------------- Signal declaration ends ----------------------------
  // DPP checker for prefix input
            ras_dp_pipe
             #(
                .PIPELINE_TYPE           (0),                       // No pipeline only checker instance
                .RESETVAL                (0),                       // Reset value set to 0
                .N_STAGES                (0),                       // No pipeline delay from module
                .CAN_STALL               (0),                       // No stalling
                .RESET_STALL             (0),                       // Stall reset value set to 0.
                .BUS_PROTECT_GEN_EN      (0),                       // generater disabled
                .BUS_PROTECT_CHK_EN      (1),                       // Checker enabled
                .PROT_TYPE               (PROT_TYPE),               
                .PROT_RANGE              (PROT_RANGE),    
                .PROT_WD                 ((PRFX_W_PAR-PRFX_PROT_WD)/PROT_RANGE),
                .PARITY_MODE             (PARITY_MODE),             
                .PROT_CORRECT_EN         (PROT_CORRECT_EN),         
                .TOTAL_WIDTH             (PRFX_W_PAR-PRFX_PROT_WD),                      // Total width  
                .EXCLUDE_PROT_WIDTH      (0),
                .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE),
                .PIPE_RAS_DP_ERR_LOG     (1)
            ) u_ras_dp_pipe_prfx_chk (
                .clk      (core_clk           ),
                .rst_n    (core_rst_n         ),
                .en       (1'b1               ),
                .bypass   (1'b0               ),
                .stall    (1'b0               ),
                .stallout (                   ),
                
                .valid_in (l_flt_q_hv         ),
                .din      (flt_q_prfx[PRFX_W_PAR-PRFX_PROT_WD-1:0]),
                .din_prot (flt_q_prfx[PRFX_W_PAR-1:PRFX_W_PAR-PRFX_PROT_WD]),
                .halt_out (                   ),
                
                .valid_out(                   ),
                .dout     (                   ),
                .dout_prot(                   ),
                .halt_in  (1'b0               ),
                .ras_dp_err_inband_kbd_in(1'b0),
                .ras_dp_err_inband_kbd_out(   ),
                .ras_dp_err_log  (ras_dp_err_log[PRF_CHK_NO] )
                ,
                .ras_dp_err_inj  (ras_dp_err_inj)
                );

      assign chk_flt_q_prfx = flt_q_prfx;


  assign tlp_fmt_type                             = {fmt,hdr_type}; 

  // DPP checker for hdr input
            ras_dp_pipe
             #(
                .PIPELINE_TYPE           (0),                       // No pipeline only checker instance
                .RESETVAL                (0),                       // Reset value set to 0
                .N_STAGES                (0),                       // No pipeline delay from module
                .CAN_STALL               (0),                       // No stalling
                .RESET_STALL             (0),                       // Stall reset value set to 0.
                .BUS_PROTECT_GEN_EN      (0),                       // generater disabled
                .BUS_PROTECT_CHK_EN      (1),                       // Checker enabled
                .PROT_TYPE               (PROT_TYPE),               
                .PROT_RANGE              (PROT_RANGE),    
                .PROT_WD                 (HW_NFT_PAR),
                .PARITY_MODE             (PARITY_MODE),             
                .PROT_CORRECT_EN         (PROT_CORRECT_EN),         
                .TOTAL_WIDTH             (HW_NFT),                      // Total width  
                .EXCLUDE_PROT_WIDTH      (0),
                .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+FLT_HDR_CHK_NO),
                .PIPE_RAS_DP_ERR_LOG     (1)
            ) u_ras_dp_pipe_hdr_chk (
                .clk      (core_clk           ),
                .rst_n    (core_rst_n         ),
                .en       (1'b1               ),
                .bypass   (1'b0               ),
                .stall    (1'b0               ),
                .stallout (                   ),
                
                .valid_in (hdr_dec_flt_p_in.hdr_dec_flt_hv         ),
                .din      (hdr_dec_flt_p_in.hdr_dec_flt_hdr[HW_NFT-1:0]),
                .din_prot (hdr_dec_flt_p_in.hdr_dec_flt_hdr[HW_NFT+HW_NFT_PAR-1:HW_NFT]),
                .halt_out (                   ),
                
                .valid_out(                   ),
                .dout     (                   ),
                .dout_prot(                   ),
                .halt_in  (1'b0               ),
                .ras_dp_err_inband_kbd_in(1'b0),
                .ras_dp_err_inband_kbd_out(   ),
                .ras_dp_err_log  (ras_dp_err_log[FLT_HDR_CHK_NO] )
                ,
                .ras_dp_err_inj  (ras_dp_err_inj)
                );

  assign chk_prfxHdr_flt_hdr_p       = hdr_dec_flt_p_in.hdr_dec_flt_hdr;
  assign flt_q_data_o_p.flt_q_parerr = int_flt_q_parerr;

  assign  hdr_dw1                 = chk_prfxHdr_flt_hdr_p[31:0];
  assign  hdr_dw2                 = chk_prfxHdr_flt_hdr_p[63:32];
  assign  hdr_dw3                 = chk_prfxHdr_flt_hdr_p[95:64];
  assign  hdr_dw4                 = chk_prfxHdr_flt_hdr_p[127:96];
  assign  hdr_type                = hdr_dw1[4:0];
  assign  fmt                     = hdr_dw1[6:5];
  assign  tlpmsg                  = hdr_dw1[6:3];

  assign  flt_reqid               = {hdr_dw3[7:0], hdr_dw3[15:8]};
  assign  attr                    = {hdr_dw1[10],hdr_dw1[21:20]};
  assign  tlp_w_pyld              = hdr_dw1[6];         // Supported PCIe format only

  assign  tlp_is_msg              = ((tlpmsg           == `MSG_4) || (tlpmsg         == `MSGD_4)) && pcie_format;
  assign  p_tlp                   = (((({fmt,hdr_type} == `MWR32) || ({fmt,hdr_type} == `MWR64)) && pcie_format) || tlp_is_msg || fm_p_rsvd[1])
                                    ;

  //assign  tlp_type [P_TYPE]       = p_tlp;               //sync with rtlh time domain

  assign  tlp_type                = ({2'b00, p_tlp});               

  assign rtlh_mem_req             = pcie_format &&
                                    ({fmt,hdr_type} == `MWR32        || {fmt,hdr_type}  == `MWR64 );
            

  assign rtlh_cfg_func_num        = hdr_dw3[(PF_WD-1)+8:8];


    assign  pcie_valid_tc           = 1'b1;
    assign  pcie_format             = 1'b1;


    assign  ats                     = hdr_dw1[19:18];
  assign  dw_len                    = {hdr_dw1[17:16], hdr_dw1[31:24]};   // Supported PCIe format only
  assign  td                        = hdr_dw1[23];
  assign  tc                        = hdr_dw1[14:12];
  

  assign  msg_is_vendor_msg0        = ((hdr_dw2[31:24] == `VENDOR_TYPE0)       && ((hdr_type[2:0] == 3'b000) || (hdr_type[2:0] == 3'b010) || (hdr_type[2:0] == 3'b011) || (hdr_type[2:0] == 3'b100)) && ((tlpmsg == `MSG_4) || (tlpmsg == `MSGD_4)) && !int_mlf_msg && pcie_format);
  assign  msg_is_vendor_msg1        = ((hdr_dw2[31:24] == `VENDOR_TYPE1)       && ((hdr_type[2:0] == 3'b000) || (hdr_type[2:0] == 3'b010) || (hdr_type[2:0] == 3'b011) || (hdr_type[2:0] == 3'b100)) && ((tlpmsg == `MSG_4) || (tlpmsg == `MSGD_4)) && !int_mlf_msg && pcie_format);



  delay_n_w_enable
  
  #(  .N(ERROR_LOG_PIPE_DELAY), 
      .WD(ERROR_LOG_PIPEWIDTH)
  ) u_error_log_pipeline 
  (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (error_log_pipe_en),
    .din        ({  l_radm_hdr_log
                      ,l_radm_tlp_prfx_log

                    ,l_set_radm_rcvd_req_ca 
                    ,l_set_radm_rcvd_req_ur, l_set_radm_rcvd_wreq_poisoned,
                    l_set_radm_ecrc_err
                    ,l_set_radm_rcvd_acs_err
                    ,l_set_radm_mlf_tlp_err, l_set_radm_hdr_log_valid,
                    flt_q_func_num
                      ,l_set_radm_mlf_tlp_err_ptr
                    ,l_set_outrange_req_ur}),
    .dout       ({  radm_cfg_o.radm_hdr_log
                      ,radm_cfg_o.radm_tlp_prfx_log

                    ,set_radm_rcvd_req_ca 
                    ,set_radm_rcvd_req_ur, set_radm_rcvd_wreq_poisoned
                    ,set_radm_ecrc_err
                     ,set_radm_rcvd_acs_err
                    ,set_radm_mlf_tlp_err, set_radm_hdr_log_valid
                    ,flt_q_func_num_d



                      ,set_radm_mlf_tlp_err_ptr
                    ,set_outrange_req_ur
                    })

  );

  assign  first_be                  = hdr_dw2[27:24];
  assign  last_be                   = hdr_dw2[31:28];
  assign  dwlenEq1                  = (dw_len[0] & (!(|dw_len[9:1])));        // dw_len == 10'b01
  
  assign  msg_code                  = ( hdr_dw2[31:24]);
 
  assign  fmt2                      = hdr_dw1[7]; 
  
  assign  rcvd_tlp_byte_cnt         = {hdr_dw2[19:16], hdr_dw2[31:24]};
  assign  rcvd_tlp_low_addr         = hdr_dw3[30:24];




  always_ff @(posedge core_clk or negedge core_rst_n)
  begin:  LATCH_TLP_TYPE_PROCESS
    if(!core_rst_n)
    begin
      l_flt_q_tlp_type          <= #TP 3'b000;          // delayed to be sync with q time domain
    end
    else
    begin
      //l_flt_q_tlp_type[P_TYPE]  <= #TP tlp_type [P_TYPE];
      l_flt_q_tlp_type  <= #TP tlp_type ;
    end
  end

  //
  // [ ----------------  sync with q time domain  -----------------------]
  //
    assign  flt_q_attr              = {flt_q_hdr_dw1[10],flt_q_hdr_dw1[21:20]};
  assign  flt_q_tc                  = flt_q_hdr_dw1[14:12];
     assign  flt_q_TAG              = flit_mode ? flt_q_14Bit_tag  : {4'h0,flt_q_hdr_dw1[15], flt_q_hdr_dw1[11], flt_q_hdr_dw2[23:16]};

  assign  flt_q_REQID               = {flt_q_hdr_dw2[7:0],flt_q_hdr_dw2[15:8]};
  assign  flt_q_dw_len              = {flt_q_hdr_dw1[17:16], flt_q_hdr_dw1[31:24]};
  assign  flt_q_type                = flt_q_hdr_dw1[4:0];
  assign  flt_q_fmt                 = flt_q_hdr_dw1[6:5];
  assign  flt_q_fmt2                = flt_q_hdr_dw1[7]; // second [2] bit of FMT field used to detect reserved TLP in FLIT mode 
  
  assign  flt_q_tlpmsg              = flt_q_hdr_dw1[6:3];
  assign  flt_q_tlp_is_msg          = (((flt_q_tlpmsg == `MSG_4) || (flt_q_tlpmsg == `MSGD_4)) && flt_q_pcie_format);

  assign  flt_q_memwr_req           = (({flt_q_fmt, flt_q_type} == `MWR32)        || ({flt_q_fmt, flt_q_type} == `MWR64  )) && flt_q_pcie_format;
  assign  flt_q_mem_req             = ( flt_q_memwr_req  );
  assign  flt_q_invalid_tlp         =  !flt_q_memwr_req & !flt_q_tlp_is_msg
                                       & !fm_p_rsvd_r[1]
                                      ;
    
      assign  flt_q_invalid_prfx      = flt_q_prfx_type_error | flt_q_prfx_end_end_max_err | flt_q_prfx_local_after_end_err; // Invalid prefix when prefix rules not met.


      logic flt_q_mismatch_func_num;
      assign  flt_q_mismatch_func_num  = (flt_q_cfg_func_num   > radm_cfg_i.cfg_max_func_num);

      assign  flt_q_func_mismatch         = flt_q_mismatch_func_num;

    assign  flt_q_td_hdr_log          = flt_q_hdr_dw1[23]; // Assigned without masking
    assign  flt_q_td                  = 
                                          radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_UNMASK_TD] ? flt_q_hdr_dw1[23] : 1'b0;
  assign  flt_q_poisoned              = flt_q_hdr_dw1[22];
  assign  flt_q_poisoned_err          = (flt_q_poisoned && flt_q_pcie_format) || l_flt_q_tlp_poisoned; // Poisoned error detection with EP bit set in header or Flit marker poisoned error received in Flit mode.
  assign  flt_q_addr64                = flt_q_hdr_dw1[5] && flt_q_pcie_format;
  assign  flt_q_first_be              = flt_q_hdr_dw2[27:24];
  assign  flt_q_last_be               = flt_q_hdr_dw2[31:28];
  assign  flt_q_msg_code              = flt_q_hdr_dw2[31:24];                         // for message transactions only
  assign  flt_q_bus_num               = flt_q_hdr_dw3[7:0];                           // for cfg transaction only
    assign  flt_q_dev_num             = flt_q_hdr_dw3[15:11];                         // for cfg transaction only
  assign  flt_q_cfg_func_num          = flt_q_hdr_dw3[(PF_WD-1)+8:8];                 // for cfg transaction only
  assign  flt_q_ext_reg_num           = flt_q_hdr_dw3[19:16];                         // for cfg transaction only
  assign  flt_q_reg_num               = flt_q_hdr_dw3[31:26];                         // for cfg transaction only
    
  //  
  assign  flt_q_addr_byte7            = (flt_q_addr64) ? flt_q_hdr_dw3[7:0]   : 8'h00;
  assign  flt_q_addr_byte6            = (flt_q_addr64) ? flt_q_hdr_dw3[15:8]  : 8'h00;
  assign  flt_q_addr_byte5            = (flt_q_addr64) ? flt_q_hdr_dw3[23:16] : 8'h00;
  assign  flt_q_addr_byte4            = (flt_q_addr64) ? flt_q_hdr_dw3[31:24] : 8'h00;
  assign  flt_q_addr_byte3            = (flt_q_addr64) ? flt_q_hdr_dw4[7:0]   : flt_q_hdr_dw3[7:0];
  assign  flt_q_addr_byte2            = (flt_q_addr64) ? flt_q_hdr_dw4[15:8]  : flt_q_hdr_dw3[15:8];
  assign  flt_q_addr_byte1            = (flt_q_addr64) ? flt_q_hdr_dw4[23:16] : flt_q_hdr_dw3[23:16];
  assign  flt_q_addr_byte0            = (flt_q_addr64) ? flt_q_hdr_dw4[31:24] : flt_q_hdr_dw3[31:24];
  assign extract_addr                 = {flt_q_addr_byte7, flt_q_addr_byte6, flt_q_addr_byte5, flt_q_addr_byte4,
                                        flt_q_addr_byte3, flt_q_addr_byte2, flt_q_addr_byte1, flt_q_addr_byte0};

  logic [TRGT1_ADDR_WD-1:0] flt_q_hdr_uppr_bytes;
  
// Sending upper_bytes as it is received at input to filter 
 
  always_comb begin  : uppr_bytes_proc 
    flt_q_hdr_uppr_bytes = 0;
      
      flt_q_hdr_uppr_bytes = (flt_q_addr64) ? {flt_q_hdr_dw4[31:0], flt_q_hdr_dw3[31:0]} : {32'b0, flt_q_hdr_dw3[31:0]}; 
  end


    assign flt_q_obff_code  = flt_q_addr_byte0[3:0];
    assign obff_addr        = {flt_q_addr_byte7, flt_q_addr_byte6, flt_q_addr_byte5, flt_q_addr_byte4,
                                flt_q_addr_byte3, flt_q_addr_byte2, flt_q_addr_byte1, flt_q_addr_byte0_i};

    // An obff message where the obff_code is anything other
    // than IDLE or OBFF is treated as CPU_ACTIVE.
    assign obff_cpu_active  = |l_flt_q_hv && flt_q_obff_msg && (flt_q_obff_code != IDLE) && (flt_q_obff_code != OBFF);

    assign flt_q_addr       = obff_cpu_active ? obff_addr : flt_q_addr_int;

    always_comb begin : proc_comb_obff_code
      // Initialise
      flt_q_addr_byte0_i        = flt_q_addr_byte0;

      if (obff_cpu_active && !l_set_radm_hdr_log_valid) begin // in case of logging, address is not changed.
        flt_q_addr_byte0_i[3:0] = CPU_ACTIVE;
      end
    end

    assign  flt_q_ats               = flt_q_hdr_dw1[19:18];
  assign flt_q_th                   = flt_q_hdr_dw1[8];

  assign flt_q_ph_int               = (flit_mode) ? flt_q_hdr_dec_ph : flt_q_addr[1:0];
  assign flt_q_ph                   = (flt_q_memwr_req) ? flt_q_ph_int : 2'b0;

  assign flt_q_st                   = flt_q_memwr_req ? flt_q_TAG[7:0] : 8'b0;

    assign flt_q_pcie_valid_tc      = 1'b1;
    assign flt_q_pcie_format        = 1'b1;

  assign flt_q_mask_wreq_poisoned_reporting     = (radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_UR_POIS] & (int_flt_q_destination == `FLT_DESTINATION_TRGT1));
  assign flt_q_mask_cpl_poisoned_reporting      = radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_POIS_ERROR_REPORTING];

  // ----------------------------------------------------------------------------
  // Register CDM Interface Inputs
  // ----------------------------------------------------------------------------
  logic                  cfg_rcrb_mbar0_match_reg;          // indication that tlp is within RCRB MEMBAR0
  logic                  cfg_rcrb_mbar0_match_int_reg;      // indication that tlp is within RCRB MEMBAR0 in CDM
  logic                  rcrb_mbar0_access_wire;
  logic                  cfg_rcrb_match_reg;                // indication that tlp is within RCRB
  logic [NF-1:0]         cfg_cxl_mbar0_match_reg;           // indication that tlp is within the CXL Component Registers Memory Range
  logic                  rcrb_access_wire;
  logic                  cxl_2_0_mbar0_access_int_reg;      // indication that tlp is within the CXL Component Registers Memory Range in CDM
  logic                  cxl_2_0_mbar0_access_wire;
  logic [NF-1:0][5:0]    cfg_cxl_mbar0_match_reg_ext;

  always_comb begin
    cfg_cxl_mbar0_match_reg_ext = '1;
    for(int i=0; i<NF; i++)
        cfg_cxl_mbar0_match_reg_ext[i][0] = ~cfg_cxl_mbar0_match_reg[i];
  end
  assign alt_bus_num_valid       = ((flt_q_REQID[15:8] >= radm_cfg_i.cfg_cxl_alt_bus_base[7:0]) && (flt_q_REQID[15:8] <= radm_cfg_i.cfg_cxl_alt_bus_limit[7:0]));
  assign flt_q_outside_alt_range = alt_bus_num_valid & (flt_q_outside_alt_mem_range & flt_q_outside_alt_prefmem_range);

   delay_n
    #(
    .N  (PIPE_VF_INDEX), 
    .WD (0 + 2 + NF + 2 + 2)
  ) u_cfg_delay_cxl (
    .clk        (core_clk   ),
    .rst_n      (core_rst_n ),
    .clear      (1'b0       ),
    .din        ({
                  radm_cfg_tlp_i.cfg_rcrb_mbar0_match,
                  radm_cfg_tlp_i.cfg_rcrb_mbar0_match_int,
                  radm_cfg_tlp_i.cfg_rcrb_match,
                  radm_cfg_tlp_i.cfg_cxl_mbar0_match,
                  radm_cfg_tlp_i.cxl_2_0_mbar0_access_int
                  ,
                  radm_cfg_tlp_i.cfg_cxl_alt_mem_match[0],
                  radm_cfg_tlp_i.cfg_cxl_alt_prefmem_match[0]
                 }),
    .dout       ({
                  cfg_rcrb_mbar0_match_reg,
                  cfg_rcrb_mbar0_match_int_reg,
                  cfg_rcrb_match_reg,
                  cfg_cxl_mbar0_match_reg,
                  cxl_2_0_mbar0_access_int_reg
                  ,
                  cfg_cxl_alt_mem_match_reg,
                  cfg_cxl_alt_prefmem_match_reg
                 })
  );
  // ----------------------------------------------------------------------------

  // ----------------------------------------------------------------------------
  // RCRB Request in Range
  // ----------------------------------------------------------------------------
  assign  flt_q_rcrb_req_in_range  = (cfg_rcrb_match_reg || cfg_rcrb_mbar0_match_reg) && flt_q_mem_req;
  // ----------------------------------------------------------------------------

  // -----------------------------------------------------------------------------
  // TLP destination calculation
  // -----------------------------------------------------------------------------
    assign  mem_trgt_map              = |(radm_cfg_i.target_mem_map & cfg_bar_match_reg & (~cfg_bar_is_io_reg) & cfg_cxl_mbar0_match_reg_ext);
    assign  rom_trgt_map              = |(radm_cfg_i.target_rom_map  & cfg_rom_match_reg);  //
    assign coerce_cfg_tlp_to_trgt1_en = (!int_app_req_retry_en & radm_cfg_i.cfg_cfg_tlp_bypass_en) | coerce_cfg_tlp_to_trgt1;

    assign  flt_q_mem_req_in_range        = (|(cfg_bar_match_reg & (~cfg_bar_is_io_reg))) & flt_q_mem_req;
  assign  flt_q_rom_req_in_range        = (|cfg_rom_match_reg & flt_q_mem_req);


  // Used for cfg/msg/cpl only
    assign pf_to_match = (flt_q_tlp_is_msg && (flt_q_type[2:0] == 3'b010))
                          ? flt_q_cfg_func_num : 'd0;


  always_comb begin : GET_MEM_BAR_PF_PROC
    integer idx;

    in_membar_range_unreg = `RADM_OUTSIDE_MEMBAR;
    raw_mem_func_num      = 0;

    for (idx=0; idx<NF; idx=idx+1)
    begin
      if (radm_cfg_tlp_i.cfg_rom_match [idx])
        raw_mem_func_num = idx;
      else
        if ((|radm_cfg_tlp_i.cfg_bar_match[(idx*6) +: 6]))
        begin
          raw_mem_func_num      = idx;
          in_membar_range_unreg = get_bar_num(radm_cfg_tlp_i.cfg_bar_match[(idx*6) +: 6]);
        end
    end
  end

  always_comb
  begin : GEN_RAW_CFG_FUNC_NUM
    integer idx;
  
    raw_cfg_func_num = 0;
    coerce_cfg_tlp_to_trgt1_int = 1'b0;
  
    for (idx=0; idx<NF; idx=idx+1)
    begin
      if (idx==pf_to_match)
      begin
          coerce_cfg_tlp_to_trgt1_int = radm_cfg_tlp_i.cfg_config_above_match[idx];
        raw_cfg_func_num = pf_to_match;
      end
    end //for idx
  end



  assign  mem_req      = PIPE_VF_INDEX == 1 ? rtlh_mem_req : flt_q_mem_req ;
  assign pfvf_func_num = 
                          mem_req ? raw_mem_func_num : 0;                            



  assign  flt_q_valid_ur_xtrash            = ( flt_q_valid_ur_p) && (flt_q_destination == `FLT_DESTINATION_TRASH);
  assign  flt_q_valid_ur_xtrgt0            = ( flt_q_valid_ur_p) && (flt_q_destination == `FLT_DESTINATION_TRGT0);
  assign  flt_q_valid_ur_xtrgt1            = ( flt_q_valid_ur_p) && (flt_q_destination == `FLT_DESTINATION_TRGT1) && !(radm_cfg_i.ur_ca_mask_4_trgt1); // this `define will mask out the report of UR or CA
  assign  flt_q_valid_ca_err               =  flt_q_valid_ca_p;

  // Per PCIe Base Spec: TLP Prefix Logging 6.2.4.4  -  "A Function that receives a TLP containing more End-End TLP Prefixes than are indicated by
  // the Function's Max End-End TLP Prefixes field must handle the TLP as an error and store the first 
  // overflow End-End TLP Prefix in the 1st DW of the Header Log register with the remainder of the Header Log register being undefined. "
    assign  l_radm_hdr_log          =  |ovrflw_end_end_prfx ? {flt_q_hdr_dw3,flt_q_hdr_dw2,flt_q_hdr_dw1,ovrflw_end_end_prfx} : {flt_q_hdr_dw4,flt_q_hdr_dw3,flt_q_hdr_dw2,flt_q_hdr_dw1};


    // Identify PASID prefix received
    // ------------------------------
    // Type field is in bits 4:0 of prefix.
    always_comb begin : extract_prefix_type
      integer i;
      for(i = 0; i < NPRFX; i = i + 1) begin           // Repeat for every allocated prefix slot
        flt_q_prfx_type[(5*i) +: 5]  =  chk_flt_q_prfx[(32*i) +: 5];
      end
    end

    // Determine if a prefix type is reserved. Non-reserved includes ExtTPH, PASID, Vendor Defined and MRIOV.

    always_comb begin : detect_prefix_type
      integer i;
      for(i = 0; i < NPRFX; i = i + 1) begin
        casez ({flt_q_prfx_type[5*i +: 5],flit_mode})
          6'b00000?,6'b01110?, 6'b01111?, 6'b10000?, 6'b10001?, 6'b11110?, 6'b11111? : prfx_type_rsrvd[i] = 0;
          6'b011011: prfx_type_rsrvd[i] = 0;
          default  : prfx_type_rsrvd[i] = 1;  // all other values => reserved type
        endcase
      end
    end


    // If any Prefix has reserved type, then assert error.
    assign flt_q_prfx_type_error = |prfx_type_rsrvd;

      // Local after end-end and max configured end-end prefix rule checks: these
      // only come into effecgt when there are 2 or more prefixes in a TLP.

      // --------------------------------------------------------------
      // Count Number of End-End TLP Prefixes received for a given TLP.
      // --------------------------------------------------------------
      // The Type[4] bit in the prefix field determines whether it is end-end or
      // local
      always_comb begin : detect_prefix_end_end_type
        integer j;
        for(j = 0; j < NPRFX; j = j + 1) begin
          prfx_type_msb[j] = chk_flt_q_prfx[32*j+4];
          prfx_fmt_msb[j]  = chk_flt_q_prfx[32*j+7];
          case (prfx_type_msb[j])
            1'b1     : prfx_is_end[j] = 1;  // End-End prefix is present.
            default  : prfx_is_end[j] = 0;
          endcase
          case ({prfx_fmt_msb[j], prfx_type_msb[j]})
            2'b10    : prfx_is_local[j] = 1;  // Local prefix is present.
            default  : prfx_is_local[j] = 0;
          endcase
        end
      end

      always_comb begin : end_end_type_count
        integer n;
        end_end_cnt = 0;
        for(n = 0; n < NPRFX; n = n + 1) begin
          end_end_cnt = prfx_is_end[n] ? end_end_cnt + 1 : end_end_cnt;
        end
      end

      // Report error if more than 4 End-End TLP Prefixes received in one TLP. Check
      // is performed based on the function number.
      
      always_comb begin : end_2_end_max_prfxs
        integer i;
        end2end_max_pf = `CX_MAX_END2END_TLP_PRFXS; // @CX_NPRFX < 4 ? @CX_NPRFX : 0
        for(i = 0; i < NF; i = i + 1) begin
          if (i==flt_q_func_num) begin
            end2end_max_pf = {radm_cfg_i.cfg_max_end2end_tlp_prfxs[(2*(i+1))-1], radm_cfg_i.cfg_max_end2end_tlp_prfxs[2*i]};
          end
        end
      end

      assign end2end_max                = end2end_max_pf == 2'b00 ? 5'h4 :
                                          end2end_max_pf == 2'b01 ? 5'h1 :
                                          end2end_max_pf == 2'b10 ? 5'h2 :
                                          5'h3;                              
      assign flt_q_prfx_end_end_max_err = (end_end_cnt > end2end_max) ? 1'b1 : 1'b0;

      // ---------------------------------------------------
      // Determine if local prefix follows End-End (illegal)
      // ---------------------------------------------------

      always_comb begin : detect_local_after_end_end_prefix
        integer k;
        flt_q_prfx_local_after_end_err     = 1'b0;
        for(k = 1; k < NPRFX; k = k + 1) begin
          if (|prfx_fmt_msb && prfx_is_local[k] && prfx_is_end[k-1]) begin
            flt_q_prfx_local_after_end_err = 1'b1;
          end
        end
      end



    
    //------------------------------------------------------------------------------------------
    //  TLP Prefix log
    //------------------------------------------------------------------------------------------
    // First, convert TLP Prefix bus from Big Endian to Little Endian before making
    // available for TLP Prefix Log (when required).
    // Width of flt_q_prfx depends on CX_NPRFX parameter, so append zeros as required.
    always_comb begin : pre_prefix_log
        pre_tlp_prfx_log                = 0;
        pre_tlp_prfx_log[32*NPRFX-1:0]  = chk_flt_q_prfx[32*NPRFX-1:0];
    end

    // TLP Prefix Log only records End-End TLP Prefixes. Hence, find first
    // End-End and then capture the the next 4 DWs (to allow for one overflow
    // End-End). Assumes that only End-End, if any, can follow first End-End. If no 
    // prefix follows first or subsequent prefixes, then zeros are recorded.
    // Bit 4 of first DW is TYPE[4], and so on.
   
    assign  e2e_prfx_log         = e2e_prfx_log_in(pre_tlp_prfx_log);

    // A maximum of 4 End-End prefixes can be stored in the Prefix Log.
    assign l_radm_tlp_prfx_log   = little_end_prfx(e2e_prfx_log);

      assign ovrflw_end_end_prfx = end2end_max == 5'h1 ? e2e_prfx_log[63:32]   :         // overflow is 2nd end to end prefix
                                   end2end_max == 5'h2 ? e2e_prfx_log[95:64]   :         // overflow is 3rd end to end prefix
                                   end2end_max == 5'h3 ? e2e_prfx_log[127:96]  :         // overflow is 4th end to end prefix
                                   end2end_max == 5'h4 ? e2e_prfx_log[159:128] :         // overflow is 5th end to end prefix
                                   32'h0;


  assign {tmp_mlf_err_ptr, tmp_mlf_err} = flt_q_rtlh_abort  ?        {flt_q_rtlh_abort_ptr, 1'b1} :
                                          flt_q_invalid_tlp ?        {`MFPTR_TLP_TYP      , 1'b1} :
                                          flt_q_msg_mlf_err ?        {`MFPTR_MSG_TC0      , 1'b1} :
                                            flt_q_invalid_prfx ?     {`MFPTR_PFX          , 1'b1} :
                                                                     {`MFPTR_NO_ERR       , 1'b0} ;


  always_comb begin: set_err_PROC
    l_set_radm_rcvd_req_ca            = 1'b0;
    l_set_radm_rcvd_req_ur            = 1'b0;
    l_set_radm_rcvd_wreq_poisoned     = 1'b0;
    l_set_radm_hdr_log_valid          = 1'b0;
    l_set_radm_ecrc_err               = 1'b0;
    l_set_radm_mlf_tlp_err            = 1'b0;
      l_set_radm_mlf_tlp_err_ptr      = 8'd0;
      l_set_radm_rcvd_acs_err         = 1'b0;
    l_set_outrange_req_ur             = 1'b0;
    // RTLH layer reported errors
    if (flt_q_unqual_eot && !rtlh_dllp_err_d  ) begin
      l_set_radm_ecrc_err             =  l_flt_q_ecrc_err;
      l_set_radm_mlf_tlp_err          =  tmp_mlf_err ;
        l_set_radm_mlf_tlp_err_ptr    =  tmp_mlf_err_ptr;
      l_set_radm_rcvd_wreq_poisoned   =  flt_q_poisoned_err & !l_flt_q_tlp_type[CPL_TYPE] & (!l_flt_q_ecrc_err) & (!tmp_mlf_err) & (!flt_q_valid_ur_wo_poisn_err) & (!flt_q_valid_ca_err) &                             
                                         !flt_q_mask_wreq_poisoned_reporting;

      // filter detected errors for a received request
      // EP's CA generated for dwlen>1
      l_set_radm_rcvd_req_ca          =  flt_q_valid_ca_err & !tmp_mlf_err & !l_flt_q_ecrc_err;
      l_set_radm_rcvd_req_ur          =  flt_q_valid_ur_err & !tmp_mlf_err 
                                         & !l_flt_q_ecrc_err & !(flt_q_poisoned_err & (!flt_q_valid_ur_wo_poisn_err));
      l_set_outrange_req_ur           =  flt_q_outrange_ur;

      // filter detected errors for a received message
      l_set_radm_hdr_log_valid        =  (l_flt_q_ecrc_err    ||
                                          tmp_mlf_err         ||
                                          l_set_radm_rcvd_wreq_poisoned  ||
                                          flt_q_valid_ur_wo_poisn_err ||
                                          flt_q_valid_ur_err  ||
                                          flt_q_valid_ca_err  
                                            || flt_q_acs_err
                                          );
        l_set_radm_rcvd_acs_err         = flt_q_acs_err & !tmp_mlf_err & !l_flt_q_ecrc_err ;
    end
  end

  // Output registering (optional)
  // CTRL_registers_path  
  assign pipe_error_log_en = (flt_q_unqual_dv | flt_q_unqual_hv); // delay_n_w_enable should handle inside enable_delayed signal to flush the pipe

  generate 
    if (ERROR_LOG_PIPE_DELAY > 0) begin : gen_error_log_pipe 
      always_ff @(posedge core_clk or negedge core_rst_n)
      begin  
        if (!core_rst_n) begin
          pipe_error_log_en_reg    <= #TP 0;
        end else begin
          pipe_error_log_en_reg    <= #TP pipe_error_log_en;
        end
      end// always
    end else begin : gen_error_log_pipe_eq0 
      assign  pipe_error_log_en_reg  = 0;
    end
  endgenerate


            ras_dp_pipe
             #(
                .PIPELINE_TYPE           (0),                  // No pipeline only checker instance
                .RESETVAL                (0),                  
                .N_STAGES                (0),                  
                .CAN_STALL               (0),                  
                .RESET_STALL             (0),                  
                .BUS_PROTECT_GEN_EN      (1),                   
                .BUS_PROTECT_CHK_EN      (0),                  
                .PROT_TYPE               (PROT_TYPE),          // cc
                .PROT_RANGE              (PROT_RANGE),         // cc
                .PROT_WD                 (FLT_P_HDR_PROT_WIDTH),
                .PARITY_MODE             (PARITY_MODE),        // cc
                .PROT_CORRECT_EN         (PROT_CORRECT_EN),    // cc
                .TOTAL_WIDTH             (FLT_P_HDR_WIDTH),             
                .EXCLUDE_PROT_WIDTH      (0),
                .RAS_DP_PROT_CHK_ID_BASE (0)
            ) u_ras_dp_pipe_gen_hdr_at (
                .clk      (core_clk           ),
                .rst_n    (core_rst_n         ),
                .en       (1'b1               ),
                .bypass   (1'b0               ),
                .stall    (1'b0               ),
                .stallout (                   ),
                
                .valid_in (1'b1               ),
                .din      ({flt_q_header_at[FLT_P_HDR_WIDTH:3], 2'b00}), // flt_p_destination is taken 0 for parity calculation to avoid any issue at the trgt1 checker.
                .din_prot ('0                 ),
                .halt_out (                   ),
                
                .valid_out(                   ),
                .dout     (),
                .dout_prot(gen_flt_q_header_at.flt_hdr_prot),
                .halt_in  (1'b0               ),
                .ras_dp_err_inband_kbd_in(1'b0),
                .ras_dp_err_inband_kbd_out(   ),
                .ras_dp_err_log  ()
                ,
                .ras_dp_err_inj  (ras_dp_err_inj)
                );
      assign gen_flt_q_header_at[FLT_P_HDR_WIDTH:1] =  flt_q_header_at[FLT_P_HDR_WIDTH:1];     
      assign gen_flt_q_header_at.flt_q_hv = 1'b0;
  
    assign flt_q_addr_int         = extract_addr;

    assign translate_enable       = ((chk_l_flt_q_header_d[`FLT_Q_DESTINATION_RANGE] == `FLT_DESTINATION_TRGT1) && !flt_q_data_o_p.flt_q_tlp_abort && !flt_q_data_o_p.flt_q_ecrc_err &&
                                      ( flt_q_memwr_req_d ||  flt_q_tlp_is_msg_d // CX_ATU_CTRL_EN
                                    ));
    //`endif // CX_ATU_CTRL_EN
      assign  rtranslated_tlp_addr                 =  rtranslated_addr_in_d;


    assign rtranslated_tlp_addr_tph = chk_l_flt_q_header_d.flt_q_th ? {rtranslated_tlp_addr[64-1:2],2'b00} :
 (flit_mode && (|chk_l_flt_q_header_d.flt_q_ats)) ? {rtranslated_tlp_addr[64-1:2],2'b00} :
                                      (chk_l_flt_q_header_d.flt_q_ats == 2'b01) ? {rtranslated_tlp_addr[64-1:1],1'b0} :
                                      rtranslated_tlp_addr;

    assign flt_q_type_d            = chk_l_flt_q_header_d[`FLT_Q_TYPE_FO +: 5];

    always_comb begin : translate_fmt0
      rtranslated_tlp_hdr_fmt = (flt_q_type_d[4:1] == 4'b0000) ?  ~(rtranslated_tlp_addr[63:32] == 32'b0) : //mem
                                (flt_q_type_d[4:2] == 3'b011 ) ?  ~(rtranslated_tlp_addr[63:32] == 32'b0) : //Atomic
                                (flt_q_type_d[4:1] == 4'b0010) ?  1'b0                                    : //cfg 0 and 1
                                (flt_q_type_d == 5'b00010)     ?  1'b0                                    : // I/O
                                chk_l_flt_q_header_d[`FLT_Q_FMT_FO]; 
    end   // translate_fmt0

    always_comb begin
      flt_q_header_at                                = l_flt_q_header_d;
      flt_q_header_at.flt_q_hdr.flt_q_addr           = rtranslated_tlp_addr_tph[FLT_Q_ADDR_WIDTH-1:0];
      flt_q_header_at.flt_q_hdr.flt_q_cpl_status     = (translate_enable && rtranslated_err_in_d[0]) ? `UR_CPL_STATUS
                                                       : (translate_enable && rtranslated_err_in_d[1]) ? `CA_CPL_STATUS :  chk_l_flt_q_header_d.flt_q_cpl_status;
      flt_destination_at                             = (translate_enable && (|rtranslated_err_in_d || flt_q_addr_gt_mstr_addr_width_at || flt_q_addr_gt_bus_width_at )) ?   `FLT_DESTINATION_TRASH : chk_l_flt_q_header_d.flt_q_destination; // always send to target0
      flt_q_header_at.flt_q_hdr.flt_q_destination    = hdr_destination'(flt_destination_at);
      flt_q_header_at_fmt                            = {chk_l_flt_q_header_d[3],rtranslated_tlp_hdr_fmt};
      flt_q_header_at.flt_q_hdr.flt_q_fmt            = hdr_fmt'(flt_q_header_at_fmt);      

          flt_q_header_at.flt_q_hdr.radm_atu_uppr_bytes_valid = radm_atu_uppr_bytes_valid;
          flt_q_header_at.radm_atu_sloc_region       = radm_atu_sloc_region;
          flt_q_header_at.radm_atu_sloc_match        = radm_atu_sloc_match;
          flt_q_header_at.radm_atu_cbuf_err          = radm_atu_cbuf_err;
    end

 always_comb begin

           flt_q_hdr_o_p[1 +: ($bits(flt_p_hdr_o_s)-1)]   =  l_flt_q_header_d[1 +: ($bits(flt_p_hdr_o_s)-1)];

           if (radm_hdr_log_valid) begin
             flt_q_hdr_o_p.flt_q_hdr.flt_q_addr           =  flt_q_addr_hdr_log1[FLT_Q_ADDR_WIDTH-1:0] ;
           end else if (translate_enable) begin
             flt_q_hdr_o_p[1 +: ($bits(flt_p_hdr_o_s)-1)] =  gen_flt_q_header_at[1 +: ($bits(flt_p_hdr_o_s)-1)];
           end else begin
             flt_q_hdr_o_p[1 +: ($bits(flt_p_hdr_o_s)-1)] =  l_flt_q_header_d[1 +: ($bits(flt_p_hdr_o_s)-1)];
           end
 end
    //assign flt_q_dmux_o_p.flt_q_header   = (translate_enable) ? 'd0 : chk_l_flt_q_header_d;


    assign chk_l_flt_q_data  = l_flt_q_data;
    assign l_flt_data_parerr = 1'b0;

  // CTRL_registers_path
  generate 
    if (FLT_Q_PIPE_DELAY > 0) begin : gen_flt_q_pipe_delay 
       logic [NVC-1:0] l_flt_q_hv_reg[FLT_Q_PIPE_DELAY-1:0];
       logic [NVC-1:0] l_flt_q_dv_reg[FLT_Q_PIPE_DELAY-1:0];
       logic [NVC-1:0] l_flt_q_eot_reg[FLT_Q_PIPE_DELAY-1:0];



      always_ff @(posedge core_clk or negedge core_rst_n)
      begin  
        integer i;
        if (!core_rst_n) begin
          for(i = 0; i < FLT_Q_PIPE_DELAY; i = i + 1) begin 
            l_flt_q_hv_reg[i]      <= #TP 0;
            l_flt_q_dv_reg[i]      <= #TP 0;
            l_flt_q_eot_reg[i]     <= #TP 0;
              cdm_core_in_dpc_reg[i] <= #TP 0;

          end
        end else begin
          for(i = 0; i < FLT_Q_PIPE_DELAY; i = i + 1) begin
            if(i==0) begin
              l_flt_q_hv_reg[i]         <= #TP l_flt_q_hv_int ;
              l_flt_q_dv_reg[i]         <= #TP l_flt_q_dv_int ;
              l_flt_q_eot_reg[i]        <= #TP l_flt_q_eot_int ;
                 cdm_core_in_dpc_reg[i] <= #TP radm_cfg_i.cdm_core_in_dpc;

            end else begin
              l_flt_q_hv_reg[i]         <= #TP l_flt_q_hv_reg[i-1]; 
              l_flt_q_dv_reg[i]         <= #TP l_flt_q_dv_reg[i-1] ;
              l_flt_q_eot_reg[i]        <= #TP l_flt_q_eot_reg[i-1] ;
                cdm_core_in_dpc_reg[i]  <= #TP cdm_core_in_dpc_reg[i-1];

            end
          end // for
        end
      end
      assign  flt_q_hdr_o_p.flt_q_hv     = l_flt_q_hv_reg[FLT_Q_PIPE_DELAY-1];
      assign  flt_q_data_o_p.flt_q_dv    = l_flt_q_dv_reg[FLT_Q_PIPE_DELAY-1];
      assign  flt_q_data_o_p.flt_q_eot   = l_flt_q_eot_reg[FLT_Q_PIPE_DELAY-1];
          assign  flt_q_tlp_abort_rc = cdm_core_in_dpc_reg[FLT_Q_PIPE_DELAY-1] ? |l_flt_q_eot_reg[FLT_Q_PIPE_DELAY-1] : int_flt_q_tlp_abort;


    end else begin : gen_flt_q_pipe_delay_eq0
      assign  flt_q_hdr_o_p.flt_q_hv     = l_flt_q_hv;
      assign  flt_q_data_o_p.flt_q_dv    = l_flt_q_dv;
      assign  flt_q_data_o_p.flt_q_eot   = l_flt_q_eot;
        assign  flt_q_tlp_abort_rc =  radm_cfg_i.cdm_core_in_dpc & |l_flt_q_eot ; 
    end
  endgenerate

  delay_n_w_enable
  
  #(  .N(FLT_Q_PIPE_DELAY), 
      .WD(FLT_Q_PIPEWIDTH)
   ) 
   u_flt_q_pipeline
   (
      .clk          (core_clk),
      .rst_n        (core_rst_n),
      .clear        (1'b0),
      .en           (flt_q_pipe_en),
      .din          ({
                      chk_l_flt_q_data,
                      l_flt_q_dllp_abort,
                      l_flt_q_tlp_poisoned,
                      l_flt_q_dwen,
                      1'b0,
                      l_flt_q_parerr,
                      l_flt_q_header,
                      l_flt_q_tlp_abort,
                        flt_q_memwr_req,
                          flt_q_tlp_is_msg,
                      radm_hdr_log_err_index_c,
                      radm_hdr_log_vld_all_fn_c,
                      radm_hdr_log_vld_c
                     }),
      .dout         ({
                      flt_q_data_o_p.flt_q_data,
                      flt_q_data_o_p.flt_q_dllp_abort,
                      flt_q_data_o_p.flt_q_tlp_poisoned,
                      flt_q_data_o_p.flt_q_dwen,
                      flt_q_data_o_p.flt_q_ecrc_err,
                      int_flt_q_parerr,
                      l_flt_q_header_d,
                      //flt_q_data_o_p.flt_q_tlp_abort,
                      int_flt_q_tlp_abort, 
                        flt_q_memwr_req_d,
                          flt_q_tlp_is_msg_d,
                      flt_q_data_o_p.radm_hdr_log_err_index,
                      flt_q_data_o_p.radm_hdr_log_vld_all_fn,
                      flt_q_data_o_p.radm_hdr_log_vld
                    })

  );



    assign l_flt_q_header_d_prot_err  = 1'b0;
    assign chk_l_flt_q_header_d       = l_flt_q_header_d.flt_q_hdr;


  /////////////////////////////////////////////////////////////////////////
  // Error indications for Cdm
  /////////////////////////////////////////////////////////////////////////
   // assign  radm_rcvd_req_ca_int        = route_error_to_func( (set_radm_rcvd_req_ca || (translate_enable && rtranslated_err_in_d[1] && |flt_q_data_o_p.flt_q_eot && !flt_q_data_o_p.flt_q_dllp_abort ))        , flt_q_func_num_d);
    assign  radm_rcvd_req_ur_int        = set_outrange_req_ur ? {NF{(set_radm_rcvd_req_ur ||(translate_enable && rtranslated_err_in_d[0] && |flt_q_data_o_p.flt_q_eot && !flt_q_data_o_p.flt_q_dllp_abort )) }}      // when an UR wo function number, go all functions
                                                              : route_error_to_func( (set_radm_rcvd_req_ur || (translate_enable && rtranslated_err_in_d[0] && |flt_q_data_o_p.flt_q_eot && !flt_q_data_o_p.flt_q_dllp_abort)), flt_q_func_num_d);
  // logic [NF-1:0] radm_rcvd_cpl_poisoned_int  = route_error_to_func( set_radm_rcvd_cpl_poisoned  , flt_q_func_num_d);
 // assign  radm_rcvd_wreq_poisoned_int   = route_error_to_func( set_radm_rcvd_wreq_poisoned , flt_q_func_num_d);
  assign  radm_hdr_log_valid_int        = 
                                         (set_radm_ecrc_err | set_radm_mlf_tlp_err | set_outrange_req_ur)  ? {NF{set_radm_hdr_log_valid}}  : route_error_to_func( set_radm_hdr_log_valid      , flt_q_func_num_d);

    

    assign  radm_rcvd_req_ca_int        =(set_radm_rcvd_req_ca || (translate_enable && rtranslated_err_in_d[1] && |flt_q_data_o_p.flt_q_eot && !flt_q_data_o_p.flt_q_dllp_abort ));
   // assign  radm_rcvd_req_ur_int        = set_outrange_req_ur ? (set_radm_rcvd_req_ur ||(translate_enable && rtranslated_err_in_d[0] && |flt_q_data_o_p.flt_q_eot && !flt_q_data_o_p.flt_q_dllp_abort ))      // when an UR wo function number, go all functions
   //                                                           :  (set_radm_rcvd_req_ur || (translate_enable && rtranslated_err_in_d[0] && |flt_q_data_o_p.flt_q_eot && !flt_q_data_o_p.flt_q_dllp_abort));
  // logic [NF-1:0] radm_rcvd_cpl_poisoned_int  = route_error_to_func( set_radm_rcvd_cpl_poisoned  , flt_q_func_num_d);
  assign  radm_rcvd_wreq_poisoned_int   = route_error_to_func( set_radm_rcvd_wreq_poisoned  , flt_q_func_num_d);

 // assign  radm_hdr_log_valid_int        = 
 //                                          `ifdef CX_IDE_ENABLE 
 //                                              (set_radm_ide_check_failed_to_report | set_radm_ide_pcrc_failed | set_radm_ide_misrouted) ?  set_radm_hdr_log_valid : 
 //                                          `endif 
 //                                        (set_radm_ecrc_err | set_radm_mlf_tlp_err | set_outrange_req_ur)  ? set_radm_hdr_log_valid : set_radm_hdr_log_valid   ;

  
  always_ff @(posedge core_clk or negedge core_rst_n)
  begin: LATCH_HDR_PROCESS
  integer j;
    if(!core_rst_n)
    begin
      // l_ord_flt_p_pkt_num         <= #TP 0;
      l_flt_q_data                <= #TP 0;
      l_flt_q_dwen                <= #TP 0;
      l_flt_q_ecrc_err            <= #TP 0;
      flt_q_msg_mlf_err           <= #TP 0;
      flt_q_rtlh_abort            <= #TP 0;
      flt_q_rtlh_abort_ptr        <= #TP 0;
      l_flt_q_dllp_abort          <= #TP 0;
      rtlh_dllp_err_d             <= #TP 0;
      ord_flt_p_pkt_num_d         <= #TP 0;
      l_flt_q_tlp_poisoned        <= #TP 1'b0;
      flt_q_hdr_dw1               <= #TP 0;
      flt_q_hdr_dw2               <= #TP 0;
      flt_q_hdr_dw3               <= #TP 0;
      flt_q_hdr_dw4               <= #TP 0;
      flt_q_hdr_dec_ph            <= #TP 'd0;
      flt_q_ohc_b_st_lb           <= #TP 'd0;
      flt_q_hdr_ohc_err           <= #TP 'd0;
      flt_q_hdr_dec_flt_dest_seg  <= #TP 'd0;
      flt_q_hdr_dec_flt_reqtr_seg <= #TP 'd0;
      flt_q_14Bit_tag             <= #TP 0;
      l_flt_q_log_rcvd_flds       <= #TP '0 ;
      l_flt_q_parerr              <= #TP 0;
      flt_q_prfx                  <= #TP 0;
    end
    else if (latch_hdr_pipe_en)
    begin
      // l_ord_flt_p_pkt_num         <= #TP ord_flt_data_p_in.ord_flt_p_pkt_num;
      l_flt_q_data                <= #TP ord_flt_data_p_in.ord_flt_data;
      l_flt_q_dwen                <= #TP ord_flt_data_p_in.ord_flt_dwen;
      l_flt_q_dllp_abort          <= #TP ord_flt_data_p_in.ord_flt_dllp_err;
      rtlh_dllp_err_d             <= #TP ord_flt_data_p_in.ord_flt_dllp_err;
      ord_flt_p_pkt_num_d         <= #TP ord_flt_data_p_in.ord_flt_p_pkt_num;
      l_flt_q_tlp_poisoned        <= #TP ord_flt_data_p_in.ord_flt_poisoned;
      {flt_q_rtlh_abort_ptr, flt_q_rtlh_abort} <= #TP ord_flt_data_p_in.ord_flt_dllp_err ? {`MFPTR_NO_ERR,    1'b0} :  extrct_malfm_tlp_errsts  ? {extrct_malfm_tlp_err_ptr, 1'b1} : {`MFPTR_NO_ERR, 1'b0} ;
      l_flt_q_ecrc_err            <= #TP radm_ecrc_err_int;
      flt_q_msg_mlf_err           <= #TP tlp_is_msg && int_mlf_msg;
      flt_q_hdr_dw1               <= #TP chk_prfxHdr_flt_hdr_p[31:0];
      flt_q_hdr_dw2               <= #TP chk_prfxHdr_flt_hdr_p[63:32];
      flt_q_hdr_dw3               <= #TP chk_prfxHdr_flt_hdr_p[95:64];
      flt_q_hdr_dw4               <= #TP chk_prfxHdr_flt_hdr_p[127:96];
      flt_q_hdr_ohc_err            <= #TP hdr_dec_flt_p_in.hdr_dec_flt_c_d_r_14bit_t[51];
      flt_q_hdr_dec_ph            <= #TP hdr_dec_flt_p_in.hdr_dec_flt_c_d_r_14bit_t[49:48];

      flt_q_ohc_b_st_lb           <= #TP hdr_dec_flt_p_in.hdr_dec_flt_c_d_r_14bit_t[47:40];
      flt_q_hdr_dec_flt_dest_seg  <= #TP hdr_dec_flt_p_in.hdr_dec_flt_c_d_r_14bit_t[31:23];
      flt_q_hdr_dec_flt_reqtr_seg <= #TP hdr_dec_flt_p_in.hdr_dec_flt_c_d_r_14bit_t[22:14];
      flt_q_14Bit_tag             <= #TP hdr_dec_flt_p_in.hdr_dec_flt_c_d_r_14bit_t[13:0];
      l_flt_q_log_rcvd_flds       <= #TP hdr_dec_flt_p_in.log_rcvd_flds ;
      l_flt_q_parerr              <= #TP rtlh_radm_parerr_int | l_flt_data_parerr;
        flt_q_prfx                <= #TP hdr_dec_flt_p_in.hdr_dec_flt_prfx;
    end
  end

  assign  l_flt_q_tlp_abort         = (( flt_q_rtlh_abort | flt_q_msg_mlf_err | flt_q_invalid_prfx
                                        | flt_q_invalid_msg
                                      ) & flt_q_unqual_eot) ;

  assign  l_flt_q_hv                = l_flt_q_hv_int;
  assign  l_flt_q_dv                = l_flt_q_dv_int;
  assign  l_flt_q_eot               = l_flt_q_eot_int;

    assign valid_ats      =  (!flt_q_ats[0] && (flt_q_memwr_req ));
  
    assign flt_q_len_zero             = !(|flt_q_dw_len);

      assign flt_q_rd_size_in_range   = ({flt_q_len_zero, flt_q_dw_len,2'b0} <= radm_cfg_i.cfg_remote_rd_req_bridge_size_dec);

// Reserved TLP decoding. As per spec, if reserved TLP detected in FLIT mode controller should report UR
  // Section 2.2.1.2 from PCIE express base spec 6.01
  //Endpoint Upstream Ports and Root Ports must handle received TLPs using Reserved Type[7:0] encodings 
  //of FC Type PR and NPR as Unsupported Requests, and of FC Type CPL as Unexpected Completions.

 tlp_hdr_pkt_s tlp_hdr_pkt;
  
  always_comb begin
    tlp_hdr_pkt = '0;
    tlp_hdr_pkt.tlp_fmt = {fmt2,fmt};
    tlp_hdr_pkt.tlp_type = hdr_type;
  end

  assign fm_p_rsvd  = f_tlp_is_fm_p_rsvd(mode_e'(flit_mode), tlp_hdr_pkt);

  always @(posedge core_clk or negedge core_rst_n)
  begin
    if(!core_rst_n) begin
      fm_p_rsvd_r <= #TP '0;
    end else begin
      fm_p_rsvd_r <= #TP fm_p_rsvd;
    end
  end

  assign  flt_q_valid_ur_p        = ((flt_q_memwr_req | flt_q_tlp_is_msg) && (!flt_q_valid_p | flt_q_poisoned_discard | flt_q_ecrc_discard | flt_q_hdr_ohc_err)) ||
  // Added UR status for ecrc_discard error
  (fm_p_rsvd_r[1] & !tmp_mlf_err & !l_flt_q_ecrc_err) ;

    assign rcrb_mbar0_access_wire     = (flt_q_mem_req && cfg_rcrb_mbar0_match_int_reg  && radm_cfg_i.cxl_rcrb_enable); 
    assign rcrb_access_wire           = (flt_q_mem_req && cfg_rcrb_match_reg && radm_cfg_i.cxl_rcrb_enable); 
    assign cxl_2_0_mbar0_access_wire  = (flt_q_mem_req && cxl_2_0_mbar0_access_int_reg);  



// target_is_cdm and target_is_elbi indicate if the tlp will be routed to CDM or ELBI.
// This will later be used to compute the completion as the ELBI and CDM have different limitation of the payload size.

wire target_is_cdm , target_is_elbi;

assign target_is_cdm          =          1'b0
                                          || rcrb_mbar0_access_wire
                                          || ( rcrb_access_wire | cxl_2_0_mbar0_access_wire)
                                             ;

assign  target_is_elbi          =  ~target_is_cdm;


assign  target_ca               = ((flt_q_dw_len == 0) || ((flt_q_dw_len > CX_ELBI_NW) && target_is_elbi) 
                                  || ((flt_q_dw_len > 1) && target_is_cdm)) && (target_acquisition == `FLT_DESTINATION_TRGT0);



  assign  flt_q_valid_ca_p        = (flt_q_memwr_req | flt_q_tlp_is_msg) && flt_q_valid_p && 
                                    (target_ca 
                                        || flt_q_acs_err      // CA condition met if any of the TLP has an ACS Violation 
                                    );

 
  //
  // [ ----------------  MESSAGE interception  -----------------------]
  //
  
  // Several Messages are required to be sent with TC0  and checking is required.
  // Section 2.2.8.x:
  // "x Messages must use the default Traffic Class designator (TC0). Receivers
  // must check for violations of this rule. If a Receiver determines that
  // a TLP violates this rule, it must handle the TLP as a Malformed TLP"
  // Also Section 2.2.8.1:
  // "Assert_INTx/Deassert_INTx Messages are only issued by Upstream Ports
  // Receivers may optionally check for violations of this rule. If a Receiver
  // implementing this 15 check determines that an Assert_INTx/Deassert_INTx
  // violates this rule, it must handle the TLP as a Malformed TLP"
  assign  int_mlf_msg_ep             = int_mlf_msg_in_ep(pcie_format,tc,msg_code); 
  assign  int_mlf_msg_rc             = int_mlf_msg_in_rc(pcie_format,tc,msg_code); 
  assign  int_pm_asnak            = ((msg_code == `PM_ACTIVE_STATE_NAK)                 && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
  assign  int_pm_turnoff          = ((msg_code == `PME_TURN_OFF)                        && (hdr_type[2:0] == 3'b011) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
  assign  int_pm_to_ack           = ((msg_code == `PME_TO_ACK)                          && (hdr_type[2:0] == 3'b101) && (tlpmsg == `MSG_4) && !int_mlf_msg  && pcie_format);
  assign  int_pm_pme              = ((msg_code == `PM_PME)                              && (hdr_type[2:0] == 3'b000) && (tlpmsg == `MSG_4) && !int_mlf_msg  && pcie_format);

  assign  int_att_ind_on          = ((msg_code == `ATTENTION_INDICATOR_ON)              && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
  assign  int_att_ind_blink       = ((msg_code == `ATTENTION_INDICATOR_BLINK)           && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
  assign  int_att_ind_off         = ((msg_code == `ATTENTION_INDICATOR_OFF)             && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
  assign  int_pwr_ind_on          = ((msg_code == `POWER_INDICATOR_ON)                  && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
  assign  int_pwr_ind_blink       = ((msg_code == `POWER_INDICATOR_BLINK)               && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
  assign  int_pwr_ind_off         = ((msg_code == `POWER_INDICATOR_OFF)                 && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);

//`ifdef CX_IS_DM_OR_EP
  assign  int_msg_unlock          = ((msg_code == `UNLOCK)                              && (hdr_type[2:0] == 3'b011) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
    assign  int_obff_msg          = ((msg_code == `OBFF)                                && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
  assign  int_att_button_pressed  = ((msg_code == `ATTENTION_BUTTON_PRESSED)            && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
  assign  int_ltr                 = ((msg_code == `LATENCY_TOLERANCE_REPORTING)         && (hdr_type[2:0] == 3'b100) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
//`endif //CX_IS_DM_OR_EP

  assign  int_invalidate_request  = ((msg_code == `INVALIDATE_REQUEST)                  && (hdr_type[2:0] == 3'b010) && (tlpmsg == `MSGD_4) && !int_mlf_msg && pcie_format);
  assign  int_invalidate_cmplt    = ((msg_code == `INVALIDATE_COMPLETION)               && (hdr_type[2:0] == 3'b010) && (tlpmsg == `MSG_4) && !int_mlf_msg && pcie_format);
  assign  flt_q_vendor_msg        = flt_q_vendor_msg0 || flt_q_vendor_msg1;


  
            ras_dp_pipe
             #(
                .PIPELINE_TYPE           (0),                  // No pipeline only checker instance
                .RESETVAL                (0),                  
                .N_STAGES                (0),                  
                .CAN_STALL               (0),                  
                .RESET_STALL             (0),                  
                .BUS_PROTECT_GEN_EN      (1),                   
                .BUS_PROTECT_CHK_EN      (0),                  
                .PROT_TYPE               (PROT_TYPE),          // cc
                .PROT_RANGE              (PROT_RANGE),         // cc
                .PROT_WD                 (FLT_P_HDR_PROT_WIDTH),
                .PARITY_MODE             (PARITY_MODE),        // cc
                .PROT_CORRECT_EN         (PROT_CORRECT_EN),    // cc
                .TOTAL_WIDTH             (FLT_P_HDR_WIDTH),             
                .EXCLUDE_PROT_WIDTH      (0),
                .RAS_DP_PROT_CHK_ID_BASE (0)
            ) u_ras_dp_pipe_gen_hdr_comp (
                .clk      (core_clk           ),
                .rst_n    (core_rst_n         ),
                .en       (1'b1               ),
                .bypass   (1'b0               ),
                .stall    (1'b0               ),
                .stallout (                   ),
                
                .valid_in (1'b1               ),
                .din      ({compressed_hdr_gen_out[FLT_P_HDR_WIDTH:3],2'b00}), // flt_p_destination is taken 0 for parity calculation to avoid any issue at the trgt1 checker.
                .din_prot ('0                  ),
                .halt_out (                   ),
                
                .valid_out(                   ),
                .dout     (),
                .dout_prot(l_flt_q_header.flt_hdr_prot),
                .halt_in  (1'b0               ),
                .ras_dp_err_inband_kbd_in(1'b0),
                .ras_dp_err_inband_kbd_out(   ),
                .ras_dp_err_log  ()
                ,
                .ras_dp_err_inj  (ras_dp_err_inj)
                );
    assign l_flt_q_header[FLT_P_HDR_WIDTH:1] = compressed_hdr_gen_out[FLT_P_HDR_WIDTH:1];        
    assign l_flt_q_header.flt_q_hv   = 1'b0;

  // ECRC error can cause store and forward queue to drop the TLP. The drop
  // was decidied by destination. Therefore, the destination needs to be
  // reevaluated at the end of ecrc errored packet

  assign  update_destination_en   = (latchd_flt_q_destination != `FLT_DESTINATION_TRASH);
  assign  flt_q_destination       = (flt_q_unqual_hv | (flt_q_unqual_eot & update_destination_en)) ? int_flt_q_destination[1:0] : latchd_flt_q_destination[1:0];          // Q DEMUX control

  // We need to latch the decision made for destination because the context
  // may be varied during a non hv cycle
  always_ff @(posedge core_clk or negedge core_rst_n)
  begin
    if (!core_rst_n)
    begin
      latchd_flt_q_destination    <= #TP 'd0;
    end
    else if (flt_q_unqual_hv)
    begin
      latchd_flt_q_destination    <= #TP int_flt_q_destination;
    end
  end

  logic  [`FLT_Q_PRFX_WIDTH -1:0]  chk_flt_q_prfx_temp;
    logic [`CX_RX_PRFX_PAR_WD-1:0] prfx_par;
    assign  prfx_par           = 'd0;
    assign chk_flt_q_prfx_temp = chk_flt_q_prfx;

 logic [1:0]                   flt_q_ph_tph;
 logic [7:0]                   flt_q_st_tph;
 logic [3:0]                   flt_q_first_be_tph;
 logic [3:0]                   flt_q_last_be_tph;

radm_tph_ctrl
 u_radm_tph_ctrl(
      .flt_q_fmt_in      (flt_q_fmt),
      .flt_q_type_in     (flt_q_type),
      .flt_q_th_in       (flt_q_th),
      .flt_q_ph_in       (flt_q_ph_int),
      .flit_mode         (flit_mode),
      .flt_q_addr_in     (flt_q_addr),
      .flt_q_tag         (flt_q_TAG[7:0])
  ,
      .flt_q_ohc_b_st_lb (flt_q_ohc_b_st_lb ),

      .flt_q_dw_len_in   (flt_q_dw_len),
      .flt_q_last_be_in  (flt_q_last_be),
      .flt_q_first_be_in (flt_q_first_be),
      .flt_q_ats_in      (flt_q_ats),
      .flt_q_addr_tph    (flt_q_addr_tph),
      .flt_q_ph_tph      (flt_q_ph_tph),
      .flt_q_st          (flt_q_st_tph ),
      .flt_q_first_be_tph(flt_q_first_be_tph),
      .flt_q_last_be_tph (flt_q_last_be_tph)
      );


delay_n_w_enable

  #( .N (FLT_Q_PIPE_DELAY), .WD (FLT_Q_ADDR_WIDTH) ) 
u_data_trgt_delay (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (radm_hdr_log_vld_c),
    .din        (flt_q_addr[FLT_Q_ADDR_WIDTH-1:0]),
    .dout       (flt_q_addr_hdr_log1[FLT_Q_ADDR_WIDTH-1:0])
    );

delay_n

   #( .N (FLT_Q_PIPE_DELAY), .WD (1) ) 
u_hdr_log_v_delay (
  .clk        (core_clk),
  .rst_n      (core_rst_n),
  .clear      (1'b0),
  .din        (radm_hdr_log_vld_c),
  .dout       (radm_hdr_log_valid)
);

assign radm_hdr_log_valid_c =  (|radm_hdr_log_valid_in );  

////////////////////////////////////////////////////////////////////////
// Following block is to report HDR log error in the form of Index.
// Total 32 errors are considered as per PCIE Gen6 spec section 7.8.4.2
// THe priority of these errors are not defined in the spec. 
// Currently assigning priority as per bit assigned in the diagram 
// Figure 7-155 Uncorrectable Error Status Register from the spec 
// Few errors are not defined in the filter those are assigned "0" 
// /////////////////////////////////////////////////////////////////////
  
  
logic  [17:0] radm_hdr_log_all_err;
logic  [5:0] rsvd_err_bits;     
logic  dl_protocol_error;
logic  surprise_dwn_error;
logic  fc_protocol_error;
logic  unexpected_cpl;
logic  receiver_overflow;
logic  acs_err;
logic  uncorrect_int_err;
logic  mc_blocked_tlp;
logic  atomic_op_egr_blked;
logic  tlp_prefix_blocked;
logic  poisoned_tlp_egr_blked;
logic  dmwr_request_egr_blked;
logic  pcrc_check_failed;
logic  misrouted_ide_tlp;
logic  tlp_translation_egr_blked;
logic  atomic_dmwr_trans_blked;
logic  ur_unexp_cpl;
logic  poisoned_tlp;



assign rsvd_err_bits = 6'd0;     
assign dl_protocol_error = 1'b0;
assign surprise_dwn_error = 1'b0;
assign fc_protocol_error = 1'b0;
assign cpl_timeout =  1'b0;
assign unexpected_cpl = 1'b0;
assign receiver_overflow = 1'b0;
    assign acs_err  = flt_q_acs_err;
  assign uncorrect_int_err = 1'b0; //l_set_outrange_req_ur;
  assign mc_blocked_tlp = 1'b0;
  assign atomic_op_egr_blked =  1'b0;
  assign tlp_prefix_blocked =  1'b0;
  assign poisoned_tlp_egr_blked =  1'b0;
  assign dmwr_request_egr_blked =  1'b0;
   assign ide_check_failed  = 1'b0;
   assign pcrc_check_failed = 1'b0;
   assign misrouted_ide_tlp = 1'b0;
 assign tlp_translation_egr_blked = 1'b0;
 assign  atomic_dmwr_trans_blked = (atomic_op_egr_blked | dmwr_request_egr_blked | tlp_translation_egr_blked);
 assign  ur_unexp_cpl  = (unexpected_cpl | flt_q_valid_ur_err);
 assign  poisoned_tlp  = (poisoned_tlp_egr_blked | flt_q_poisoned_err);

 assign radm_hdr_log_all_err = {poisoned_tlp_egr_blked,l_set_radm_rcvd_wreq_poisoned,pcrc_check_failed,unexpected_cpl, flt_q_valid_ca_err,l_set_radm_rcvd_req_ur,mc_blocked_tlp,acs_err, tlp_prefix_blocked,tlp_translation_egr_blked,dmwr_request_egr_blked, atomic_op_egr_blked,misrouted_ide_tlp,l_flt_q_ecrc_err,ide_check_failed,tmp_mlf_err,receiver_overflow, uncorrect_int_err};
 assign  radm_hdr_log_err_index_c[4:0]  =  radm_hdr_log_err_index(radm_hdr_log_all_err);
 assign  radm_hdr_log_vld_c             =  l_set_radm_hdr_log_valid;

///////////////////////////////////////////////////////////////////
 // This logic is to detect HDR log should  report function specific or per function 
 // //////////////////////////////////////////////////////////////
 assign  radm_hdr_log_vld_all_fn_c        =  (l_flt_q_ecrc_err && !(ide_check_failed)) | tmp_mlf_err  | ((flt_q_valid_ur_err && flt_q_outrange_ur) && !(ide_check_failed||misrouted_ide_tlp))  ;
  
 //---------------------------------------------------------------------------------         
 // compressed header generation module   
 //---------------------------------------------------------------------------------

 // fields that will be used from filter inside radm_compressed_hdr module to form compressed hdr
 logic [PF_WD-1:0]  flt_q_func_num_c;

 logic              rom_req_in_range_c;
 assign rom_req_in_range_c = flt_q_rom_req_in_range & ~(flt_q_valid_ur_p | flr_in_progress);

 assign flt_q_func_num_c   = flt_q_func_num;                  

 compressed_hdr_gen_ctl_s compressed_hdr_gen_in;
 radm_tlp_hdr_s           algn_rx_tlp_hdr, flt_rx_tlp_hdr, flt_rx_tlp_hdr_out;

 assign compressed_hdr_gen_in.destination        = flt_q_destination;
 assign compressed_hdr_gen_in.cpl_status         = flt_q_cpl_status;
 assign compressed_hdr_gen_in.func_num_c         = flt_q_func_num_c;
 assign compressed_hdr_gen_in.in_membar_range    = flt_q_in_membar_range;
 assign compressed_hdr_gen_in.rom_req_in_range_c = rom_req_in_range_c;
 assign compressed_hdr_gen_in.io_req_in_range_c  = 1'b0;
 assign compressed_hdr_gen_in.cpl_last           = 1'b0;
 assign compressed_hdr_gen_in.np_req_type        = '0;
 assign compressed_hdr_gen_in.hdr_log_valid      = l_set_radm_hdr_log_valid;

 // align input raw header with old input header interface to the filter after ecrc extraction & address anticipation
 // ANTI_CTRL_PIPE_DELAY can be 1 or 2 cycles
 delay_n
 
 #(.N(ANTI_CTRL_PIPE_DELAY + 1), .WD($bits(radm_tlp_hdr_s))) 
 u_flt_prfx_hdr
 (
   .clk        (core_clk),
   .rst_n      (core_rst_n),
   .clear      (1'b0),
   .din        (rx_tlp_hdr),
   .dout       (algn_rx_tlp_hdr)
 );

 always_ff @(posedge core_clk or negedge core_rst_n)
 begin: LATCH_HDR_PROCESS_COMPRESSED_GEN
   if (!core_rst_n)
     flt_rx_tlp_hdr <= #TP '0;
   else if (latch_hdr_pipe_en)
     flt_rx_tlp_hdr <= #TP algn_rx_tlp_hdr;
 end

 // re-assign pkt_num from ecrc extract module
 always_comb begin
   flt_rx_tlp_hdr_out = flt_rx_tlp_hdr;
   flt_rx_tlp_hdr_out.p_pkt_num = ord_flt_p_pkt_num_d;
 end

 // instantiation of radm_comressed_hdr_gen module
 radm_compressed_hdr_gen
  #(
   .COMPRESSED_HDR_TYPE(flt_p_hdr_o_s),
   .FC_TYPE(E_P)
 ) u_radm_compressed_hdr_gen (
   .core_clk             (core_clk),               
   .radm_clk_ug          (radm_clk_ug),            
   .core_rst_n           (core_rst_n),             
   .flit_mode            (flit_mode),
   .radm_cfg_i           (radm_cfg_i),
   .rx_tlp_hdr           (flt_rx_tlp_hdr_out),
   .compressed_hdr_flds  (compressed_hdr_gen_in),
   .log_rcvd_flds        (l_flt_q_log_rcvd_flds),
   .tlp_prfx             (chk_flt_q_prfx_temp),
   .compressed_hdr       (compressed_hdr_gen_out)
 );
  
  // ----------------------
  // FUNCTIONS 
  ///---------------------
//`ifdef CX_IS_DM_OR_RC
//function automatic [PF_WD:0] one_hot_decode_2_zero;
//    input [NF-1:0]      one_hot_target;
//    reg   [PF_WD-1:0]   encoded;
//    reg                 target_eq_0;
//    integer             i;
//
//    begin
//      // only function 0 is supported in RC mode
//      encoded = 0;
//      target_eq_0 = 1'b1;
//      for (i=NF-1; i>=0 ; i=i-1) begin
//        if(one_hot_target[i] == 1'b1) begin
//          encoded     = i;
//          target_eq_0 = 1'b0;
//        end
//      end
//
//      one_hot_decode_2_zero = {encoded,target_eq_0};
//    end
//endfunction
//`endif //CX_IS_DM_OR_RC




//  `ifndef SYNTHESIS
//    //VCS coverage off
//    always_ff @(posedge core_clk)
//    begin
//      if (|l_flt_q_hv && radm_cfg_i.upstream_port)
//      begin
//        if (l_flt_q_tlp_type[P_TYPE] && (flt_q_destination == `FLT_DESTINATION_TRASH))
//            $display ("%t %m WARNING:  Posted transaction intended was TRASHED by RADM Filter", $time);
//      end
//    end
//
//    always_comb 
//    begin:  ENCODE_VALID_TYPE
//      case({flt_q_valid_ur_p,1'b0,flt_q_valid_p,1'b0})
//        4'b0010:  flt_q_valid_type  = `FLT_VALID_P_TYPE;
//        4'b1000:  flt_q_valid_type  = `FLT_VALID_UR_P_TYPE;
//        default:  flt_q_valid_type  = 3'b100; //
//      endcase //
//    end
//
//
//    assign  TARGET_MAP              =  ( target_acquisition == `FLT_DESTINATION_TRASH ) ? "trash"     :
//                                       ( target_acquisition == `FLT_DESTINATION_TRGT0 ) ? "TRGT0"     :
//                                       ( target_acquisition == `FLT_DESTINATION_TRGT1 ) ? "TRGT1"     : "bogus";
//
//    assign  RADM_Q_DEST             =  ( compressed_hdr_gen_out[ `FLT_Q_DESTINATION_RANGE ] == `FLT_DESTINATION_TRASH ) ? "trash"     :
//                                       ( compressed_hdr_gen_out[ `FLT_Q_DESTINATION_RANGE ] == `FLT_DESTINATION_TRGT0 ) ? "TRGT0"     :
//                                       ( compressed_hdr_gen_out[ `FLT_Q_DESTINATION_RANGE ] == `FLT_DESTINATION_TRGT1 ) ? "TRGT1"     : "bogus";
//
//                                       ( flt_q_valid_type  == `FLT_VALID_P_TYPE      ) ? "val_P"     :
//                                       ( flt_q_valid_type  == `FLT_VALID_UR_P_TYPE   ) ? "val_UR_P"  : "----";
//
//
//    assign  RADM_Q_TLP_TYPE         =  ( l_flt_q_tlp_type == 3'b001 ) ? "P"  :
//                                       ( l_flt_q_tlp_type == 3'b000 ) ? "---": "BGS";
//    //VCS coverage on
//
//     `ifdef CX_RASDP_EN
//       logic [DW-1:0] ras_data;
//       logic [DATA_PAR_WD-1:0] ras_ecc;
//       assign ras_data = ord_flt_data_p[DW-1:0];
//       assign ras_ecc  = ord_flt_data_p[DW +: DATA_PAR_WD];
//     `endif // CX_RASDP_EN
//                      
//     `ifdef SNPS_ASSERT_ON
//     
//     logic check_flt_q_cpl_crs;
//     logic [4:0] cov_cpl_crs;
//     logic [2:0] cov_bins;
//     
//     // CPL with CRS status
//     assign check_flt_q_cpl_crs = (flt_q_cpl_status == `CRS_CPL_STATUS);
//     assign cov_cpl_crs = {check_flt_q_cpl_crs, flt_q_cfg0rd_req, flt_q_cfg0wr_req, flt_q_cfg1rd_req, flt_q_cfg1wr_req};
//     
//     always_comb
//     begin
//       case(cov_cpl_crs)
//         5'b11000  : cov_bins = 3'b000;
//         5'b10100  : cov_bins = 3'b001;
//         5'b10010  : cov_bins = 3'b010;
//         5'b10001  : cov_bins = 3'b011;
//         default   : cov_bins = 3'b100;
//       endcase
//     end
//     
//     property p_return_cpl_crs;
//       @(posedge core_clk) disable iff (core_rst_n !== 1'b1)
//         (!radm_cfg_i.cfg_cfg_tlp_bypass_en && flt_q_valid_np &&l_flt_q_hv &&  (flt_q_cfg1rd_req || flt_q_cfg1wr_req || flt_q_cfg0rd_req || flt_q_cfg0wr_req) && (app_req_retry_en_tmp)) |-> check_flt_q_cpl_crs;
//     endproperty
//     //`CX_ASSERTION( p_return_cpl_crs, "CPL with CRS status should be returned" )
//     
//     covergroup cg_cpl_crs @(posedge core_clk);
//       cp_cpl_crs : coverpoint cov_bins iff(core_rst_n) {
//         option.comment = "CPL with CRS status sent for Type0 or Type1 Cfg Requests";
//         bins CFGRD0_CRS = {3'b000};
//         bins CFGWR0_CRS = {3'b001};
//         bins CFGRD1_CRS = {3'b010};
//         bins CFGWR1_CRS = {3'b011};
//         ignore_bins ignore = {cov_bins[2]};
//       }
//     endgroup
//     
//     cg_cpl_crs cg_inst_cpl_crs;
//     
//     initial begin
//       cg_inst_cpl_crs = new();
//     end
//     
//     `endif // SNPS_ASSERT_ON
//
//  `endif // SYNTHESIS

///  `ifdef CX_DEBUG_SOURCE
///    assign prfxHdr_flt_hdr_p_fmt_type = hdr_dec_flt_p_in.hdr_dec_flt_hv ? hdr_dw1[6:0] : 7'bz;
///  `endif // CX_DEBUG_SOURCE



  /// Additional error check from RTLH

  assign  p_wr          =  (tlp_fmt_type[6:0] == `MWR32) |
                             (tlp_fmt_type[6:0] == `MWR64) |
                             (tlp_fmt_type[6:3] == `MSG_4) |
                             (tlp_fmt_type[6:3] == `MSGD_4);

  assign tlp_dw_len       = dw_len;
  assign tlp_has_pyld     = (tlp_fmt_type[6]  & !fm_p_rsvd[1])  || fm_p_rsvd[0];
  assign dw_len_is0       = (tlp_dw_len == 10'b0);


  always_comb  begin : count_dwen
    integer i;
    l_tmp_dwcnt = 0;
    for(i = 0; i < NW; i = i + 1) begin
      if(ord_flt_data_p_in.ord_flt_dwen[i]) begin
      l_tmp_dwcnt = i;
      end
    end
    if(|ord_flt_data_p_in.ord_flt_dwen) begin
    l_tmp_dwcnt = l_tmp_dwcnt + 1;
    end
  end
  assign tmp_dwcnt      = l_tmp_dwcnt;

  always_ff @(posedge core_clk or negedge core_rst_n)
  begin
    if (!core_rst_n)
      prev_pyld_dwcnt   <= #TP 0;
    else if (ord_flt_data_p_in.ord_flt_eot) 
      prev_pyld_dwcnt   <= #TP 0;
    else
      prev_pyld_dwcnt   <= #TP pyld_dwcnt;
  end


// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: This logic is designed to be modulo. pyld_dwcnt counters are intended to
// wrap without preseveration of carry/borrow
  assign pyld_dwcnt     = (ord_flt_data_p_in.ord_flt_dv) ? prev_pyld_dwcnt + tmp_dwcnt :  prev_pyld_dwcnt;                          
// spyglass enable_block W164a                         
  // all errors below are latched to form the malformaed error at the final
  // cycle of the current tlp due to the abort issue of the currnt tlp
  // This error can only be generated based on long payload tlps
  // detect the interrupt message with TC non zero err according to page 67 of rev1.0
  always_comb
  begin
    intrup_msg    = 1'b0;
    pm_msg        = 1'b0;
    err_msg       = 1'b0;
    lock_msg      = 1'b0;
    sspl_msg      = 1'b0;
      obff_msg    = 1'b0;
      ltr_msg     = 1'b0;
      ptm_msg     = 1'b0;
      prs_msg     = 1'b0;

    casez (msg_code)
      8'b0010_????   : intrup_msg = 1'b1;
      8'b0001_0100,
      8'b0001_1000,
      8'b0001_1001,
      8'b0001_1011   : pm_msg     = 1'b1;
      8'b0011_????   : err_msg    = 1'b1;
      8'b0000_0000   : lock_msg   = 1'b1;
      8'b0101_0000   : sspl_msg   = 1'b1;
        8'b0001_0010 : obff_msg   = 1'b1;
      `LTR_MSG_CODE  : ltr_msg    = 1'b1;
        8'b0101_001? : ptm_msg    = 1'b1;
        8'b0000_010? : prs_msg    = 1'b1;
      default : begin
        intrup_msg                = 1'b0;
        pm_msg                    = 1'b0;
        err_msg                   = 1'b0;
        lock_msg                  = 1'b0;
        sspl_msg                  = 1'b0;
          obff_msg                = 1'b0;
          ltr_msg                 = 1'b0;
          ptm_msg                 = 1'b0;
          prs_msg                 = 1'b0;
      end
    endcase
  end

  //assign msg_route_rc  = (tlp_fmt_type[2:0]    == 3'b000) | (tlp_fmt_type[2:0] == 3'b101);

  assign msg           = (tlp_fmt_type[6:3] == `MSG_4) | (tlp_fmt_type[6:3] == `MSGD_4);
  assign msg_route_rc  = (tlp_fmt_type[2:0] == 3'b000) | (tlp_fmt_type[2:0] == 3'b101);
  assign msg_route_bc  = (tlp_fmt_type[2:0] == 3'b011);
// detect the message route errors : upstream port can not receive
// the route code as routed to root complex
// Downstream port can not receive the route code as broadcast from
// root complex
// This error detection is only there for switch
 assign  msg_route_err             = msg & !radm_cfg_i.cfg_endpoint & !radm_cfg_i.cfg_root_compx &  ((msg_route_rc & radm_cfg_i.upstream_port) | (msg_route_bc & !radm_cfg_i.upstream_port));

  assign msg_type      = msg & (intrup_msg |
                         pm_msg            |
                         err_msg           |
                         lock_msg          |
                         sspl_msg
                         | obff_msg
                         | ltr_msg
                         | ptm_msg
                         | prs_msg &  (radm_cfg_i.cfg_root_compx | radm_cfg_i.cfg_endpoint)
                         );

  // detect the VC/TC errors with TC non zero err according to page 84,85 of rev1.0
  //assign curnt_struc_vc        = get_VC(radm_cfg_i.cfg_tc_struc_vc_map,tc);
  assign  tc_err                    = ~( get_tc_enable(radm_cfg_i.cfg_tc_enable,tc)
                                      // `ifdef CX_CCIX_INTERFACE_ENABLE
                                      //    | get_tc_enable(cfg_ccix_tc_enable,tc)
                                      // `endif // CX_CCIX_INTERFACE_ENABLE
                                      );

  assign tmp_dw_len                  = {dw_len_is0, dw_len} ;


    assign len_mismatch              = ord_flt_data_p_in.ord_flt_eot & ((td & tlp_has_pyld ) ? (tmp_dw_len != pyld_dwcnt) :
                                       (td )                ? (pyld_dwcnt != 11'h0)      :
                                       (tlp_has_pyld )      ? (tmp_dw_len != pyld_dwcnt) : (pyld_dwcnt != 11'h0));

  // This block implements the optional address/length check according to page 62 of spec 1.1
  // "Requests must not specify an Address/Length combination which causes a Memory Space access to cross a 4-KB boundary"
  assign int_addr_11_dt_0  = tlp_fmt_type[5] ? {hdr_dec_flt_p_in.hdr_dec_flt_hdr[115:112], hdr_dec_flt_p_in.hdr_dec_flt_hdr[127:120]}
                                             : {hdr_dec_flt_p_in.hdr_dec_flt_hdr[83:80], hdr_dec_flt_p_in.hdr_dec_flt_hdr[95:88]};

  // We strip the PH for checking purposes, regardless of whether TPH is set.
  assign addr_11_dt_0      =  {int_addr_11_dt_0[11:2],2'b00};

    always_comb  begin
      addr_len_error    = 1'b0;
      if ((tlp_fmt_type[6:0] == `MWR32)        || (tlp_fmt_type[6:0] == `MWR64))      
        addr_len_error  = (({1'b0, addr_11_dt_0[11:2]} + tmp_dw_len[10:0]) > 12'h400) ? 1'b1 : 1'b0;
    end


  //logic  pcie_max_pyld_err;
  assign max_pyld_err           = pcie_max_pyld_err(radm_cfg_i.cfg_max_payload,dw_len_is0,tlp_dw_len,tlp_has_pyld);
  assign {hdr_err_ptr, hdr_err} = max_pyld_err             ? {`MFPTR_TLP_MXPL, 1'b1} :
                                 (msg_type & (tc != 3'b0)) ? {`MFPTR_MSG_TC0,  1'b1} :
                                  tc_err                   ? {`MFPTR_TLP_TC,   1'b1} :
                                  msg_route_err            ? {`MFPTR_MSG_R,    1'b1} :
                                                             {`MFPTR_NO_ERR,   1'b0} ;

  assign  do_check              = (p_wr ) &&
                                  (tlp_fmt_type[6:3] != `MSG_4) &&
                                  (tlp_fmt_type[6:3] != `MSGD_4);
  
  assign hdr_len_mismatch       = hdr_dec_flt_p_in.radm_malf_tlp_err_hdr || malform_ecrc_err_int;
  assign is_qw_aligned          = ~addr_11_dt_0[2];
  assign fbe_error              = (do_check && ((tlp_dw_len > 1) && (first_be == 4'b0000))) ? 1'b1 : 1'b0;
  // LBE Check
  assign lbe_error              = (do_check && ((tlp_dw_len == 1) && (last_be != 4'b0000))) ? 1'b1 :
                                  (do_check && ((tlp_dw_len > 1) && (last_be == 4'b0000))) ? 1'b1 : 1'b0;

  // Compound byte enable error signal
  assign be_error               = fbe_error || lbe_error || ctig_error(do_check,is_qw_aligned,
                                  tlp_dw_len,first_be,last_be);

  assign  {extrct_malfm_tlp_err_ptr, extrct_malfm_tlp_errsts} = ord_flt_data_p_in.ord_flt_eot ?  
                                                                ord_flt_data_p_in.ord_flt_dllp_err ? {`MFPTR_NO_ERR,    1'b0} :
                                                                len_mismatch ? {`MFPTR_TLP_DLEN,  1'b1} :
                                                                (hdr_len_mismatch  || ord_flt_data_p_in.ord_flt_malformed_tlp_err) ? {`MFPTR_TLP_HLEN,  1'b1} :
                                                                hdr_err ? {hdr_err_ptr,      1'b1} :
                                                                be_error ? {`MFPTR_TLP_BE,    1'b1} :
                                                                addr_len_error ? {`MFPTR_TLP_4KBND, 1'b1} :
                                                                ((fmt2 & (~flit_mode) ) | hdr_dec_flt_p_in.radm_malf_tlp_err_hdr_prfx ) ? { `MFPTR_PFX,       1'b1} :
                                                                ( hdr_dec_flt_p_in.radm_malf_tlp_err_hdr_flit ) ? {`MFPTR_TLP_FLIT,       1'b1} :
                                                                rtlh_extrct_ecrc_len_mismatch ? {`MFPTR_TLP_ELEN,  1'b1} :
                                                                {`MFPTR_NO_ERR,    1'b0} : {`MFPTR_NO_ERR, 1'b0};

                                                               
  assign radm_cfg_o.radm_snoop_bus_num = 'd0;
  assign radm_cfg_o.radm_snoop_dev_num = 'd0;
  assign radm_cfg_o.radm_snoop_upd     = 'd0;
  assign radm_cfg_o.cfg_segment_id     = 'd0;


assign  radm_cfg_o.radm_rcvd_cpl_poisoned =1'b0;
assign  radm_cfg_o.radm_rcvd_cpl_ur       =1'b0;
assign  radm_cfg_o.radm_rcvd_cpl_ca       =1'b0;
assign  radm_cfg_o.radm_unexp_cpl_err     =1'b0;






function automatic [PF_WD:0] one_hot_decode_2_zero;
    input [RC_NF-1:0]   one_hot_target;
    reg   [PF_WD-1:0]   encoded;
    reg                 target_eq_0;
    integer             i;

    begin
      // only function 0 is supported in RC mode
      encoded = 0;
      target_eq_0 = 1'b1;
      for (i=RC_NF-1; i>=0 ; i=i-1) begin
        if(one_hot_target[i] == 1'b1) begin
          encoded     = i;
          target_eq_0 = 1'b0;
        end
      end

      one_hot_decode_2_zero = {encoded,target_eq_0};
    end
endfunction



endmodule
