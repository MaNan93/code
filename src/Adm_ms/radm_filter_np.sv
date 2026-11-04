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
// ---    $Revision: #21 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_filter_np.sv#21 $
// -------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
//  1. process and disassemble received np
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


module radm_filter_np


  import pcie_pkg::mode_e;
  import pcie_pkg::tlp_hdr_pkt_s;
  import pcie_pkg::f_tlp_is_fm_np_rsvd;
  import pcie_pkg::E_NP;

  import DWC_pcie_ctl_pkg::NF;
  import DWC_pcie_ctl_pkg::VF_WD;
  import DWC_pcie_ctl_pkg::PF_WD;
  import DWC_pcie_ctl_pkg::VFI_WD;
  import DWC_pcie_ctl_pkg::ATTR_WD;
  import DWC_pcie_ctl_pkg::NVF;
  import radm_ms_pkg::DATA_PAR_WD;
  import radm_ms_pkg::FLT_NUM;
  import radm_ms_pkg::PKT_ORD_WD;
  import radm_ms_pkg::HW_NFT;
  import radm_ms_pkg::HW_NFT_PAR;
  import radm_ms_pkg::ST_WD;
  import radm_ms_pkg::ATU_IN_MIN1;
  import radm_ms_pkg::FILTER_CHK_CNTS;
  import radm_ms_pkg::FLT_OUT_PROT_WD;
  import radm_ms_pkg::CX_NFUNC_WD;
  import radm_ms_pkg::HEW ;
  import radm_ms_pkg::NP_TYPE;
  import radm_ms_pkg::CPL_TYPE;
  import radm_ms_pkg::FLT_Q_ADDR_WIDTH;
  import radm_ms_pkg::CX_ELBI_NW;
  import radm_ms_pkg::ERROR_LOG_PIPE_DELAY;
  import radm_ms_pkg::FLT_Q_PIPE_DELAY;
  import radm_ms_pkg::hdr_destination;
  import radm_ms_pkg::hdr_fmt;
  import radm_ms_pkg::radm_cfg_atu_s;
  import radm_ms_pkg::radm_flt_atu_s;
     import radm_ms_pkg::ATU_IPIPE_PROT_WD; 
  import radm_ms_pkg::radm_cfg_i_s;
  import radm_ms_pkg::radm_cfg_tlp_i_s;
  import radm_ms_pkg::radm_cfg_tlp_o_s;
  import radm_ms_pkg::radm_ord_mgr_flt_data_s;
  import radm_ms_pkg::radm_hdr_dec_com_ohc_decx_present_s;
  import radm_ms_pkg::radm_hdr_dec_flt_s;
  import radm_ms_pkg::flt_q_dmux_o_s;
  import radm_ms_pkg::flt_np_hdr_s;
  import radm_ms_pkg::flt_cpl_hdr_s;
  import radm_ms_pkg::FLT_NP_HDR_WIDTH;
  import radm_ms_pkg::FLT_NP_HDR_PROT_WIDTH;
  import radm_ms_pkg::flt_data_o_s;
  import radm_ms_pkg::flt_np_hdr_o_s;
  import radm_ms_pkg::flt_q_byte_addr_in;
  import radm_ms_pkg::route_error_to_func;
  import radm_ms_pkg::get_pm_block;
  import radm_ms_pkg::radm_hdr_log_err_index;
  import radm_ms_pkg::radm_hdr_log_rcvd_flds_s ;
  import radm_ms_pkg::get_bar_num;
  import radm_ms_pkg:: pcie_max_pyld_err ;
  import radm_ms_pkg:: ctig_error;
  import radm_ms_pkg::get_tc_enable;
  import radm_ms_pkg::little_end_prfx;
  import radm_ms_pkg::e2e_prfx_log_in;
  import radm_ms_pkg::q_select_from_tc;
  import radm_ms_pkg::compressed_hdr_gen_ctl_s;
  import radm_ms_pkg::radm_tlp_hdr_s;

  import DWC_pcie_ctl_pkg::TP;
  import DWC_pcie_ctl_pkg::NW;
  import DWC_pcie_ctl_pkg::NVC;
  import DWC_pcie_ctl_pkg::NPRFX;
  import DWC_pcie_ctl_pkg::TAG_SIZE;
  import DWC_pcie_ctl_pkg::DW  ;// Width of datapath in bits - For ECC we export the check bits.
  import DWC_pcie_ctl_pkg::PRFX_W_PAR;
 
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::ANTI_CTRL_PIPE_DELAY; 
  import DWC_pcie_ctl_pkg::PRFX_PROT_WD;  //KN


#(
  parameter RAS_DP_PROT_CHK_ID_BASE  = 0,
  // Segbuf parametersRC_
  parameter RC_NF                     = 1,
  parameter  ST_CT_CTRL               = 0,   
  localparam ST_CT_CTRL_INT           = (ST_CT_CTRL == 1 ) ? 1 : 0,
  localparam PIPE_DELAY               = 1,
  parameter SEG_WIDTH                 = `CX_SEG_WIDTH,
  parameter SNOOP_VPD_WD              = `CX_SNOOP_VPD_WD,
  parameter ERROR_LOG_PIPEWIDTH       = 128
                                          + 128
                                            + 1
                                          + PF_WD                   // flt_q_func_num
                                          + 8                       // set_radm_mlf_tlp_err_ptr
                                          + 1 
                                          + 6
                                        ,
    
  localparam ALT_PF_WD                = NF == 1 ? 1 : $clog2(NF), // Alternative number of bits needed to address the physical functions


  parameter ADDR_TRANSLATION_SUPPORT  = 0 +1 ,


    localparam ERR_INJ_INDEX          = (FLT_NUM==0)? 20 : 77,

  parameter PIPE_VF_INDEX             = 0 ,
  parameter PIPE_VF_INDEX_WIDTH       = PF_WD +3 +3 + 8                               // func_num + in_membar_range + in_io_range + bar_is_io
 // in_vf_membar_range + mem_vf_num
                                        ,
  parameter PIPE_CFG_WIDTH_EP         = (6*NF) + (6*NF) + NF                          //radm_cfg_tlp_i.cfg_bar_match + radm_cfg_i.cfg_bar_is_io + radm_cfg_tlp_i.cfg_rom_match 
                                          + 1 
                                        ,


  parameter PIPE_CFG_WIDTH_RC         = (6*RC_NF) + (6*RC_NF) + RC_NF                          //radm_cfg_tlp_i.cfg_bar_match + radm_cfg_i.cfg_bar_is_io + radm_cfg_tlp_i.cfg_rom_match 
                                           + RC_NF + RC_NF   // FOR RC only 1 FUNCTION is used 
                                        ,




  localparam GATING_CTRL_PATH_WD      = 3*NVC,                                        // [NVC-1:0]  l_flt_q_hv, l_flt_q_dv, l_flt_q_eot   

    localparam IDLE                   = 4'b0000,
    localparam OBFF                   = 4'b0001,
    localparam CPU_ACTIVE             = 4'b1111,

  localparam DMWR_ADDITIONAL_FLT_RULES = `CX_DMWR_ADDITIONAL_FLT_RULES,
  localparam MAX_DMWR_SIZE            = (`CX_DEF_MEM_WR_LEN_SUPP == 0)? 10'd16 : 10'd32,
  parameter N_CYCLE_DELAY_ERR_OUT     = 0,
  localparam ERR_OUT_WIDTH            =  1                              // extrct_fc_dllp_err
                                          +8                            // extrct_fc_malfm_tlp_err_ptr
                                        +1,                             // extrct_fc_malfm_tlp_err
  //parameter FLT_Q_PIPEWIDTH           = DW + DATA_PAR_WD + 1 + NW + 1 + 1 + FLT_NP_HDR_WIDTH +FLT_OUT_PROT_WD + 1 + 3
  parameter FLT_Q_PIPEWIDTH           = 3 + DW + DATA_PAR_WD + 1 + NW + 1 + 1 +  $bits(flt_np_hdr_o_s)
                                        + 1
                                         +1
                                          + 4
                                            + 1
                                          + 1
                                            + 2
                                        +5
                                        +1
                                        +1
                                        ,

 parameter MASTER_BUS_ADDR_WIDTH     = `MASTER_BUS_ADDR_WIDTH

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
  // output  flt_q_dmux_o_s                                flt_q_dmux_o_np,
  output flt_data_o_s                                   flt_q_data_o_np,
  output flt_np_hdr_o_s                                 flt_q_hdr_o_np,
  // end config
  input   [15:0]                                        filt_ant_rid, 
  input                                                 rtlh_radm_parerr_int, 
  input                                                 radm_ecrc_err, 
  input                                                 malform_ecrc_err, 
  
  // Raw header interface
  input   radm_tlp_hdr_s                                rx_tlp_hdr,

  input radm_ord_mgr_flt_data_s                         ord_flt_data_np, 
  input                                                 app_req_retry_en,
  input [NF-1:0]                                        app_pf_req_retry_en
  ,
  //  `ifdef CX_CCIX_INTERFACE_ENABLE
  //    input   [CCIX_WD-1:0]                           hdr_dec_flt_np_ccix_tlp,
  //  `endif // CX_CCIX_INTERFACE_ENABLE
  input radm_hdr_dec_flt_s                              hdr_dec_flt_np

//input [15:0]                                          rtlh_radm_ant_rid,
//input [63:0]                                          rtlh_radm_ant_addr
  // ATU
  ,
  input [63:0]                                          rtranslated_addr_in_d,
  input [1:0]                                           rtranslated_err_in_d
  ,
  input                                                 radm_atu_uppr_bytes_valid,
  output radm_flt_atu_s                                 radm_flt_atu_out,
  output logic                                          radm_flt_atu_hv
  ,output   [ATU_IPIPE_PROT_WD-1:0]                      radm_flt_atu_hdr_prot
  
  ,
  output logic                                          radm_flt_atu_eot,
  input [$clog2(ATU_IN_MIN1)-1:0]                       radm_atu_sloc_region,
  input                                                 radm_atu_sloc_match,
  input                                                 radm_atu_cbuf_err
  // ATU end  
  ,
  output  logic  [51:0]                                 rcrb_base_addr,             // Indicates the base address for the RCRB region. The upper address bits[63:12] of the first memory access received after link initialization is the RCRB base address
  output  logic                                         rcrb_base_addr_valid        // Indicates the base address valid for the RCRB region
  ,
  output ras_dp_err_log_t      [FILTER_CHK_CNTS-1:0]    ras_dp_err_log,
  input  ras_dp_err_inj_t                               ras_dp_err_inj  

);
  localparam PROT_RANGE      = `CX_RAS_PROT_RANGE;
  localparam PROT_TYPE       = `CX_RAS_PROT_TYPE;
  localparam PARITY_MODE     = `CX_RAS_PARITY_MODE;
  localparam PROT_CORRECT_EN = PROT_TYPE? 0 : `CX_RAS_CORRECTION_EN;
  localparam PRF_CHK_NO      = 0;
  localparam FLT_HDR_CHK_NO  = 0 + 1;
  // --------------------------------- Signal declaration ---------------------------------
  

  flt_np_hdr_o_s                                compressed_hdr_gen_out;
  radm_cfg_tlp_o_s                              radm_cfg_o_int;
  radm_hdr_dec_flt_s                            hdr_dec_flt_np_in; 
  radm_ord_mgr_flt_data_s                       ord_flt_data_np_in;
  logic                                         int_flt_q_tlp_abort;
  logic [1:0]                                   flt_q_header_at_fmt;
  //
  logic                                         flt_q_valid_ca_err;
  logic                                         radm_hdr_log_valid;
  logic  [NF-1:0]                                radm_hdr_log_valid_in;
  logic                                         radm_hdr_log_valid_in_vf;
  logic                                         radm_hdr_log_valid_c;
  logic                                         radm_rcvd_req_ca_int;
  logic [NF-1:0]                                radm_rcvd_req_ur_int;
  logic                                         radm_rcvd_req_ca;
  logic [NF-1:0]                                radm_rcvd_req_ur;
  logic [NF-1:0]                                radm_rcvd_wreq_poisoned_int;
  logic [NF-1:0]                                radm_hdr_log_valid_int_rc;
  logic [NF-1:0]                                radm_hdr_log_valid_int_ep;
  logic                                         radm_hdr_vf_active ;
  logic                                         radm_ecrc_err_int;
  logic                                         malform_ecrc_err_int;
  logic [31:0]                                  addr_low;
  logic [31:0]                                  addr_high;
  logic                                         addr64;
  logic [HEW-1:0]                               hdr_dw1;                    // sync with rtlh time domain
  logic [HEW-1:0]                               hdr_dw2;
  logic [HEW-1:0]                               hdr_dw3;
  logic [HEW-1:0]                               hdr_dw4;
  logic                                         pcie_valid_tc;
  logic                                         pcie_format;
  logic [2:0]                                   tlp_type;
  logic [4:0]                                   hdr_type;
  logic [1:0]                                   fmt;
  logic                                         fmt2;
  logic [3:0]                                   tlpmsg;
  logic                                         flt_q_ecrc_discard_rc;
  logic                                         flt_q_ecrc_discard_ep;
  logic                                         flt_q_invalid_tlp;
  logic   [2:0]                                 fm_np_rsvd;
  logic   [2:0]                                 fm_np_rsvd_r;
  logic [(5*NPRFX)-1:0]                         flt_q_prfx_type;        // Type field of received TLP Prefix.
  logic [NPRFX-1:0]                             prfx_type_rsrvd;        // the bit of a given Prefix is set if Type field is a reserved value
  logic                                         flt_q_prfx_type_error;  // asserted if any prefix type is reserved.
  logic                                         flt_q_prfx_local_after_end_err; // asserted if a local type prefix follows an end-end type prefix
  logic                                         flt_q_prfx_end_end_max_err;     // Asserted when max End-End limit is exceeded
  logic [31:0]                                  ovrflw_end_end_prfx;            // the first overflow End-End TLP Prefix (exceeds Function's Max End-End TLP Prefixes field)
  logic                                         flt_q_invalid_prfx;
  logic                                         flt_q_pcie_format;
  logic                                         flt_q_pcie_valid_tc;
  logic [1:0]                                   ats;
  logic [3:0]                                   obff_code;
  logic [9:0]                                   dw_len;
  logic [ATTR_WD-1:0]                           attr;
  logic                                         tlp_w_pyld;
  logic                                         td;
  logic [2:0]                                   tc;
  logic [3:0]                                   first_be;
  logic [3:0]                                   last_be;
  radm_hdr_log_rcvd_flds_s                              l_flt_q_log_rcvd_flds ;
  logic                                         dwlenEq1;
  logic [11:0]                                  rcvd_tlp_byte_cnt;
  logic [6:0]                                   rcvd_tlp_low_addr;
  logic                                         flt_q_rtlh_abort;
  logic [HEW-1:0]                               flt_q_hdr_dw1;                  // sync with q time domain
  logic [HEW-1:0]                               flt_q_hdr_dw2;
  logic [HEW-1:0]                               flt_q_hdr_dw3;
  logic [HEW-1:0]                               flt_q_hdr_dw4;
  logic [14-1:0]                                flt_q_14Bit_tag;
  logic [8:0]                                   flt_q_cfg_segment_id;
  logic                                         cfg_segment_id_vld;
  logic                                         flt_q_io_req_in_range;
  logic                                         flt_q_io_req_in_range_ep;
  logic                                         flt_q_io_req_in_range_rc;
  logic [2:0]                                   raw_flt_q_in_membar_range;
  logic [2:0]                                   flt_q_in_membar_range;
  logic [2:0]                                   flt_q_in_membar_range_ep;
  logic [2:0]                                   flt_q_in_membar_range_rc;
  logic                                         flt_q_mem_req_in_range;
  logic                                         flt_q_rom_req_in_range;
  logic                                         flt_q_outside_mem_range;
  logic                                         flt_q_outside_prefmem_range;
  logic                                         flt_q_outside_alt_mem_range;
  logic                                         flt_q_outside_alt_prefmem_range;
  logic                                         flt_q_outside_alt_range;
  logic                                         alt_bus_num_valid;
  logic [RC_NF-1:0]                             cfg_cxl_alt_mem_match_reg;         // indication that tlp is within Alternate Memory Range
  logic [RC_NF-1:0]                             cfg_cxl_alt_prefmem_match_reg;     // indication that tlp is within Prefetchable Alternate Memory Range

  logic [DW+DATA_PAR_WD-1:0]                    l_flt_q_data;                   //tlp data sent to queue
  // aux bus to decouple the internal wiring from the use of RAS. If RAS is used chk_l_flt_q_data holds the 
  // value of l_flt_q_data at the output of bus_protect_chk. If RAS is not used chk_l_flt_q_data is just a 
  // feedthrough
  logic [DW+DATA_PAR_WD-1:0]                    chk_l_flt_q_data; 
  logic                                         l_flt_q_dllp_abort;             //Recall packet (Malformed TLP, etc.)
  logic [NVC-1:0]                               l_flt_q_dv;                     //1 when flt_q_data   is valid
  logic [NVC-1:0]                               l_flt_q_dv_int;                 //1 when flt_q_data   is valid
  logic [NW-1:0]                                l_flt_q_dwen;                   //DWord Enable for Data Interface.
  logic                                         l_flt_q_ecrc_err;               // flt_q  // -> radm_q
  logic                                         set_radm_ecrc_err;            // flt_q  // -> radm_q
  logic                                         l_set_radm_ecrc_err;            // flt_q  // -> radm_q
  logic                                         l_set_radm_ecrc_err_rc;         // flt_q  // -> radm_q
  logic                                         l_set_radm_ecrc_err_ep;         // flt_q  // -> radm_q
  logic [NVC-1:0]                               l_flt_q_eot;                    // flt_q  //Indicate end of packet
  logic [NVC-1:0]                               l_flt_q_eot_int;                // flt_q  //Indicate end of packet
  flt_np_hdr_o_s                                l_flt_q_header;                 //tlp compressed header sent to queue
  flt_np_hdr_o_s                                l_flt_q_header_d;               //tlp compressed header sent to queue
  flt_np_hdr_s                                  chk_l_flt_q_header_d;           //tlp compressed header sent to queue, output of bus_protect_chk if RAS is enabled

  // decouple the internal header wiring from the use of RAS. If RAS is used then chk_prfxHdr_flt_hdr_np is the output of
  // bus_protect_chk module. Without RAS it's just a feedthrough of prfxHdr_flt_hdr_np
  logic [HW_NFT+HW_NFT_PAR-1:0]                            chk_prfxHdr_flt_hdr_np;         // 128-bit packet header
  logic [NVC-1:0]                               l_flt_q_hv;                     // flt_q  //1 when l_flt_q_header is valid
  logic [NVC-1:0]                               l_flt_q_hv_int;                 // flt_q  //1 when l_flt_q_header is valid
  logic                                         l_flt_q_tlp_abort;              // flt_q  //Recall packet (Malformed TLP, etc.)
  logic [2:0]                                   l_flt_q_tlp_type;               // flt_q  //one hot signal indicating to indicate {CPL, NP, P} TLP, valid @ l_flt_q_hv
  logic [2:0]                                   l_flt_q_tlp_type_d;               // flt_q  //one hot signal indicating to indicate {CPL, NP, P} TLP, valid @ l_flt_q_hv
  logic                                         l_flt_q_parerr;
  logic                                         int_flt_q_parerr;               // error indication at the output of the delay module
  logic                                         mem_req;
  logic                                         io_req ;
  logic                                         cfg_req;
  logic                                         l_set_radm_hdr_log_valid;
  logic                                         l_set_radm_hdr_log_valid_ep;
  logic                                         l_set_radm_hdr_log_valid_rc;
  logic                                         l_set_radm_mlf_tlp_err;
  logic                                         l_set_radm_mlf_tlp_err_rc;
  logic                                         l_set_radm_mlf_tlp_err_ep;
  logic                                         l_set_radm_rcvd_req_ur;
  logic                                         l_set_radm_rcvd_req_ur_ep;
  logic                                         l_set_radm_rcvd_req_ur_rc;
  logic                                         l_set_radm_rcvd_req_ca;
  logic                                         set_radm_rcvd_req_ca;
  logic                                         l_set_radm_rcvd_req_ca_ep;
  logic                                         l_set_radm_rcvd_req_ca_rc;
  logic                                         l_set_radm_rcvd_wreq_poisoned;
  logic                                         l_set_radm_rcvd_wreq_poisoned_ep;
  logic                                         l_set_radm_rcvd_wreq_poisoned_rc;
  logic                                         l_set_radm_rcvd_cpl_ur;
  logic                                         l_set_outrange_req_ur;
  logic [127:0]                                 l_radm_hdr_log;
  logic                                         set_radm_hdr_log_valid;
  logic                                         set_radm_mlf_tlp_err;
  logic                                         set_radm_rcvd_req_ur;
  logic                                         set_outrange_req_ur;
  logic [1:0]                                   target_acquisition_rc_int;
  logic [1:0]                                   int_flt_q_destination;
  logic [1:0]                                   int_flt_q_destination_rc;
  logic [1:0]                                   int_flt_q_destination_ep;
  logic [1:0]                                   latchd_flt_q_destination;
  logic [1:0]                                   flt_q_destination;
  logic [1:0]                                   flt_destination_at;
  logic                                         rtlh_mem_req;
  logic [ATTR_WD-1:0]                           flt_q_attr;
  logic                                         device_is_rc;
  logic                                         device_is_rc_int;
  logic                                         device_is_ep;
  logic                                         device_is_ep_int;
  logic [2:0]                                   flt_q_tc;
  logic [TAG_SIZE-1:0]                          flt_q_TAG;
  logic [15:0]                                  flt_q_REQID;
  logic [4:0]                                   flt_q_type;
  logic [1:0]                                   flt_q_fmt;
  logic                                         flt_q_fmt2; // second [2] bit of FMT field used to detect reserved TLP in FLIT mode 
  logic                                         flt_q_np_rd;
  logic                                         flt_q_iord_req;
  logic                                         flt_q_iowr_req;
  logic                                         flt_q_locked_rd;
  logic                                         flt_q_memrd_req;
  logic                                         flt_q_def_memwr_req;
  logic                                         atomic_fetchadd;
  logic                                         atomic_swap;
  logic                                         atomic_cas;
  logic                                         flt_q_cfg0rd_req;
  logic                                         flt_q_cfg0wr_req;
  logic                                         flt_q_cfg1rd_req;
  logic                                         flt_q_cfg1wr_req;
  logic                                         flt_q_cfg_req;
  logic                                         flt_q_cfg1_req;
  logic                                         flt_q_atomic_op;
  logic                                         flt_q_func_mismatch_ep;
  logic                                         flt_q_func_mismatch_rc;
  logic                                         flt_q_td;
  logic                                         flt_q_td_hdr_log;
  logic                                         flt_q_poisoned;
  logic                                         flt_q_poisoned_err;
  logic                                         flt_q_addr64;
  logic [3:0]                                   flt_q_first_be;
  logic [3:0]                                   flt_q_last_be;
  logic [7:0]                                   flt_q_msg_code;
  logic [7:0]                                   flt_q_bus_num;

  logic [4:0]                                   flt_q_dev_num_rc;
  logic [RC_NF-1:0]                             cfg_mem_match_reg_rc;
  logic [RC_NF-1:0]                             cfg_prefmem_match_reg_rc;
  logic                                         l_set_radm_rcvd_acs_err;
  logic                                         flt_q_acs_err;
  logic                                         acs_at_valid;
  logic                                         acs_src_valid;
  logic                                         flt_q_cpl_tlp;
  logic                                         flt_q_tlp_abort_rc;   
  logic [PF_WD-1:0]                             flt_q_func_num_rc;
  logic [63:0]                                  flt_q_addr_rc;
  logic                                         flt_q_valid_np_rc;
  logic                                         flt_q_valid_ca_np_rc;
  logic                                         flt_q_unqual_dv_rc;
  logic                                         flt_q_unqual_hv_rc;
  logic                                         flt_q_unqual_eot_rc;
  logic [1:0]                                   target_acquisition_rc;             // dynamic tlp steering, depending on bar mapping, 1-trgt1; 0-trgt0;  

   logic [4:0]                                  flt_q_dev_num_ep;
  
  logic [PF_WD-1:0]                             flt_q_cfg_func_num;
  logic [PF_WD-1:0]                             flt_q_func_num;
  logic [PF_WD-1:0]                             flt_q_func_num_ep;
  logic [PF_WD-1:0]                             raw_flt_q_func_num;
  logic [PF_WD-1:0]                             raw_func_num_unreg;
  logic [PF_WD-1:0]                             raw_mem_func_num;
  logic [PF_WD-1:0]                             flt_q_func_num_d;
  logic [PF_WD-1:0]                             pf;
  logic [PF_WD-1:0]                             pfvf_func_num;
  logic [3:0]                                   flt_q_ext_reg_num;
  logic [5:0]                                   flt_q_reg_num;
  logic [63:0]                                  flt_q_addr;
  logic [64-1:0]                                flt_q_addr_tph;
  logic [63:0]                                  flt_q_addr_hdr_log1;
  logic [63:0]                                  flt_q_addr_ep;
  logic [63:0]                                  flt_q_addr_int;
  logic [7:0]                                   flt_q_addr_byte0;
  logic [7:0]                                   flt_q_addr_byte1;
  logic [7:0]                                   flt_q_addr_byte2;
  logic [7:0]                                   flt_q_addr_byte3;
  logic [7:0]                                   flt_q_addr_byte4;
  logic [7:0]                                   flt_q_addr_byte5;
  logic [7:0]                                   flt_q_addr_byte6;
  logic [7:0]                                   flt_q_addr_byte7;
  logic [6:0]                                   flt_q_lower_addr;
  logic [9:0]                                   flt_q_dw_len;
  logic [NVC-1:0]                               flt_q_vc_select;
  logic [1:0]                                   flt_q_byte_addr;
  logic                                         flt_q_valid_np;
  logic                                         flt_q_valid_np_ep;
  logic                                         flt_q_valid_ur_np;
  logic                                         flt_q_ur_np_wo_poisn;
  logic                                         flt_q_valid_ca_np;
  logic                                         flt_q_valid_ca_np_ep;
  logic                                         flt_q_tlp_is_msg;
  logic                                         flt_q_vendor_msg0;
  logic                                         flt_q_vendor_msg1;
  logic [3:0]                                   flt_q_tlpmsg;
  logic [2:0]                                   flt_q_rcvd_cpl_status;
  logic                                         flt_q_reserved_status;
  logic                                         flt_q_status_sc;
  logic                                         flt_q_status_ur;
  logic [1:0]                                   flt_q_ats;
  logic                                         flt_q_nw_in;
  logic                                         flt_q_nw;
  logic                                         flt_q_cxlsrc_in;
  logic                                         flt_q_cxlsrc;
  logic                                         flt_q_th;
  logic                                         rtlh_radm_parerr;
  logic                                         rtlh_dllp_err_d;
  logic   [PKT_ORD_WD-1:0]                      ord_flt_p_pkt_num_d;
  logic                                         l_flt_q_tlp_poisoned;
  logic      [ST_WD-1:0]                        flt_q_ohc_b_st_lb;
  logic [1:0]                                   flt_q_hdr_dec_ph;
  logic                                         flt_q_hdr_dec_nw;
  logic                                         flt_q_hdr_ohc_err;
  logic                                         flt_q_hdr_dec_cxlsrc;
  logic [8:0]                                   flt_q_hdr_dec_flt_dest_seg ;
  logic [8:0]                                   flt_q_hdr_dec_flt_reqtr_seg;
  logic                                         flt_q_unqual_dv;
  logic                                         flt_q_unqual_dv_ep;
  logic                                         flt_q_unqual_hv;
  logic                                         flt_q_unqual_hv_ep;
  logic                                         flt_q_unqual_eot;
  logic                                         flt_q_unqual_eot_ep;

  // CPL declarations
  logic                                         flt_q_outrange_ur;
  logic                                         flt_q_outrange_ur_int;
  logic [1:0]                                   target_acquisition;             // dynamic tlp steering, depending on bar mapping, 1-trgt1; 0-trgt0;
  logic [1:0]                                   target_acquisition_ep;             // dynamic tlp steering, depending on bar mapping, 1-trgt1; 0-trgt0;
  logic                                         rom_trgt_map_rc;
  logic                                         rom_trgt_map_ep;
  logic                                         mem_trgt_map_rc;
  logic                                         mem_trgt_map_ep;
  logic                                         flt_q_mem_req;
  logic                                         io_trgt_map;
  logic                                         pm_block_tlp;
  logic                                         flt_q_io_req_range;
  logic                                         flt_q_pm_radm_block_tlp;
  logic                                         flt_q_poisoned_discard;
  logic                                         flt_q_ecrc_discard;
  logic                                         flt_q_poisoned_discard_rc;
  logic                                         flt_q_poisoned_discard_ep;
  logic                                         flt_q_func_mismatch_tlp;
  logic                                         flt_q_locked_rd_tlp;
  logic                                         flt_q_locked_rd_tlp_ep;
  logic                                         flt_q_locked_rd_tlp_rc;
  logic                                         flr_in_progress;
  logic                                         flr_pf_in_progress;
  logic                                         flr_vf_in_progress;
  logic                                         coerce_cfg_tlp_to_trgt1;
  logic                                         coerce_cfg_tlp_to_trgt1_int;
  logic                                         rtlh_io_req;
  logic                                         rtlh_cfg_req;
  logic [PF_WD-1:0]                             rtlh_cfg_func_num;

  // Sending and Receiving of TLP Prefixes enabled
  logic [PRFX_W_PAR-1:0]                           flt_q_prfx;                      // retimed prfxHdr_flt_prfx_np
  logic [PRFX_W_PAR-1:0]                           chk_flt_q_prfx;                  
  logic                                         target_ca;                       
  logic                                         tmp_mlf_err;                     
  logic [7:0]                                   tmp_mlf_err_ptr;                 
  logic [7:0]                                   flt_q_rtlh_abort_ptr;            
  logic                                         coerce_cfg_tlp_to_trgt1_en;      // Target destination control signal; allows Cfg requests to reach Target1.
  logic [7:0]                                   l_set_radm_mlf_tlp_err_ptr;
  logic [7:0]                                   l_set_radm_mlf_tlp_err_ptr_ep;
  logic [7:0]                                   l_set_radm_mlf_tlp_err_ptr_rc;
  logic [7:0]                                   set_radm_mlf_tlp_err_ptr;
  logic                                         l_flt_q_header_d_prot_err;
  logic                                         app_req_retry_en_tmp;
  logic                                         int_app_req_retry_en;
  logic [NF-1:0]                                int_app_pf_req_retry_en;
  logic [15:0]                                  flt_q_cpl_reqid;
  logic [2:0]                                   flt_q_cpl_status;
  logic [2:0]                                   flt_q_cpl_status_ep;
  logic [2:0]                                   flt_q_actual_cpl_status;
  logic [2:0]                                   flt_q_cpl_status_rc;
  logic [1:0]                                   flt_q_ph;
  logic [1:0]                                   flt_q_ph_int;
  logic [7:0]                                   flt_q_st;

  logic                                         enable_mask_pois_if_trgt0_destination_ep;
  logic                                         enable_mask_pois_if_trgt0_destination_rc;
  logic                                         flt_q_mask_wreq_poisoned_reporting;
  logic                                         flt_q_mask_cpl_poisoned_reporting;
  logic [PF_WD-1:0]                             raw_io_func_num;
  logic [2:0]                                   in_membar_range;
  logic [2:0]                                   in_membar_range_unreg;
  logic [2:0]                                   in_iobar_range_unreg;
  logic [2:0]                                   in_iobar_range;
  logic [PF_WD-1:0]                             raw_cfg_func_num;
  logic [PF_WD-1:0]                             pf_to_match;
  logic [7:0]                                   shft_bar_is_io_unreg;
  logic [7:0]                                   shft_bar_is_io;
  logic                                         flt_q_valid_ur_xtrash_wo_poisn;
  logic                                         flt_q_valid_ur_xtrgt0_wo_poisn;
  logic                                         flt_q_valid_ur_xtrgt1_wo_poisn;
  logic                                         flt_q_valid_ur_wo_poisn_err;
  logic                                         flt_q_valid_ur_wo_poisn_err_rc;
  logic                                         flt_q_valid_ur_wo_poisn_err_ep;
  logic                                         flt_q_valid_ur_np_wo_poisoned;
  logic                                         flt_q_valid_ur_xtrash ;
  logic                                         flt_q_valid_ur_xtrgt0; 
  logic                                         flt_q_valid_ur_xtrgt1 ;
  logic                                         flt_q_valid_ur_err;
  logic                                         flt_q_valid_ur_err_rc;
  logic                                         flt_q_valid_ur_err_ep;
  logic [4:0]                                   end2end_max;
  logic [NPRFX-1:0]                             prfx_is_end;            // A received prefix is of type end to end 
  logic [NPRFX-1:0]                             prfx_is_local;          // A received prefix is of type local
  logic [NPRFX-1:0]                             prfx_type_msb;          // Type[4] bit of prefix.
  logic [NPRFX-1:0]                             prfx_fmt_msb;           // Fmt[2] bit of prefix.
  logic [4:0]                                   end_end_cnt;

  logic [255:0]                                 pre_tlp_prfx_log;       // This bus must have max possible width = 8 x TLP Prefixes
  logic [159:0]                                 e2e_prfx_log;           // This bus must have max possible width = 8 x TLP Prefixes
  logic [127:0]                                 l_radm_tlp_prfx_log;    // 4 DWs stored in TLP Prefix log
  // CTRL_registers_path
  logic                                         pipe_error_log_en;
  logic                                         pipe_error_log_en_reg;
  logic                                         error_log_pipe_en;
  logic [63:0]                                  extract_addr;

  logic                                         flt_q_iord_req_d;
  logic                                         flt_q_iowr_req_d;
  logic                                         flt_q_locked_rd_d;
  logic                                         flt_q_memrd_req_d;
  logic                                         flt_q_memwr_req_d;
  logic                                         flt_q_def_memwr_req_d;
  logic                                         flt_q_atomic_op_d;
  logic [4:0]                                   flt_q_type_d;
  logic                                         rtranslated_tlp_hdr_fmt;
  logic                                         flt_q_cfg0_req_d;
  logic                                         flt_q_cfg1_req_d;
  logic                                         flt_q_tlp_is_msg_d;
  logic                                         translate_enable;
  logic [63:0]                                  rtranslated_tlp_addr;
  logic [63:0]                                  rtranslated_tlp_addr_tph;
  logic [63:0]                                  rtranslated_tlp_addr_ep;
  logic [63:0]                                  rtranslated_tlp_addr_rc;
  flt_np_hdr_o_s                                flt_q_header_at;
  flt_np_hdr_o_s                                gen_flt_q_header_at; 
  logic [FLT_NP_HDR_WIDTH-1:0]     der_at; 
  logic                                         l_flt_data_parerr;
  logic                                         flt_q_pipe_en;
  logic                                         flt_q_pipe_en_rc;
  logic                                         flt_q_pipe_en_ep;
  logic                                         pf_hidden_for_vendor_msg0;
  logic                                         pf_hidden_for_vendor_msg1;
  logic                                         latch_hdr_pipe_en;
  logic                                         latch_hdr_pipe_en_rc;
  logic                                         latch_hdr_pipe_en_ep;
  logic                                         valid_atomic_request;
  logic                                         flt_q_valid_atomic_request;
  logic                                         atomic_operand32;
  logic                                         atomic_operand64;
  logic                                         atomic_operand128;
  logic                                         flt_q_atomic_discard_ep;
  logic                                         flt_q_atomic_discard_rc;
  logic                                         valid_def_memwr_request;
  logic                                         valid_def_memwr_request_ep;
  logic                                         valid_def_memwr_request_rc;
  logic                                         unsupported_def_memwr_request_ep;
  logic                                         unsupported_def_memwr_request_rc;
  logic                                         flt_q_def_memwr_discard_ep;
  logic                                         flt_q_def_memwr_discard_rc;
  logic                                         valid_ats;
  logic                                         flt_q_rd_size_in_range;
  logic                                         flt_q_len_zero;
  logic                                         pf_hidden_for_cfg_req;
  logic                                         flt_q_pcie_good_eot;
  logic                                         update_destination_en;
  `ifndef SYNTHESIS
  logic [8*5:0]                                 RADM_Q_DEST;
  logic [8*5:0]                                 TARGET_MAP;
  logic [8*9:0]                                 RADM_Q_VALID_TYPE;
  logic [8*3:0]                                 RADM_Q_TLP_TYPE;
  //  ENCODED valid type
  logic [2:0]                                   flt_q_valid_type;
  `endif // SYNTHESIS
  
  // Additional Erro checks from RTLH 
  logic                                         max_pyld_err;
  logic                                         tc_err;
  logic                                         msg_type  ;
  logic                                         np_wr  ;
  logic                                         np_rd  ;
  logic                                         atomic_op;
  logic                                         hdr_4dw;
  logic                                         tlp_has_pyld;
  logic [1:0]                                   fc_type;
  logic [7:0]                                   hdr_err_ptr;
  logic                                         extrct_malfm_tlp_errsts;
  logic [7:0]                                   extrct_malfm_tlp_err_ptr; // Indicates the detail of malformed for RASDES
  logic                                         hdr_len_mismatch;
  logic                                         cfg_tph_enable;
  logic [6:0]                                   tlp_fmt_type;
  logic                                         th;
  logic [9:0]                                   tlp_dw_len;
  logic [3:0]                                   fbe;                    // First DW byte enable
  logic [3:0]                                   lbe;                    // Last DW byte enable
  logic [11:0]                                  int_addr_11_dt_0;
  logic [11:0]                                  addr_11_dt_0;

   // For AtomicOp Requests addr[1:0] is not defined, these bits are repurposed as PH
   // We strip the PH for checking purposes, regardless of whether TPH is set.

  logic [10:0]                                  pyld_dwcnt;
  logic                                         next_incr_enable;
  logic [1:0]                                   next_fctype;
  logic [8:0]                                   next_incr_amt;
  logic [10:0]                                  tmp_dw_len;
  logic                                         len_mismatch;
  logic                                         atomic_operand_err;
  logic                                         atomic_be_err;
  logic                                         atomic_addr_align_err;
  logic                                         do_check;
  logic                                         is_qw_aligned;
  logic                                         tph_memrd;
  logic                                         mem_rd;
  logic                                         fbe_error;
  logic                                         lbe_error;
  logic                                         be_error;
  logic                                         addr_len_error;
  logic                                         hdr_err;
  logic [1:0]                                   end2end_max_pf;
  logic [NF-1:0]                                cfg_rom_match_reg;
  logic [NF-1:0]                                cfg_rom_match_reg_ep;
  logic [RC_NF-1:0]                             cfg_rom_match_reg_rc;
  logic [NF-1:0][5:0]                           cfg_bar_is_io_reg; 
  logic [NF-1:0][5:0]                           cfg_bar_is_io_reg_ep; 
  logic [RC_NF-1:0][5:0]                        cfg_bar_is_io_reg_rc; 
  logic [NF-1:0][5:0]                           cfg_bar_match_reg;
  logic [NF-1:0][5:0]                           cfg_bar_match_reg_ep;
  logic [(6*RC_NF)-1:0]                         cfg_bar_match_reg_rc;
  logic                                         flt_q_mem_req_range;
  logic                                         flt_q_mem_req_range_rc;
  logic                                         flt_q_mem_req_range_ep;
  logic                                         cdm_core_in_dpc_reg[FLT_Q_PIPE_DELAY-1:0];
  logic                                         set_radm_rcvd_acs_err;
  logic      [5-1:0]                            radm_hdr_log_err_index_c;
  logic                                         radm_hdr_log_vld_all_fn_c;
  logic                                         radm_hdr_log_vld_c;
  logic     [2:0]                               flt_q_actual_cpl_status_ecrc_flt;
  logic [1:0]                                   flt_q_ph_tph;
  logic [7:0]                                   flt_q_st_tph;
  logic [3:0]                                   flt_q_first_be_tph;
  logic [3:0]                                   flt_q_last_be_tph;

  // ------------------------------- Signal declaration ends --------------------------------
  //
  //
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
  assign ord_flt_data_np_in          = ord_flt_data_np;
  assign hdr_dec_flt_np_in           = hdr_dec_flt_np;


always_comb begin
  if (flt_q_unqual_eot && !rtlh_dllp_err_d  ) begin
  end
end 


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

    assign flt_q_cpl_status                         = device_is_ep  ? flt_q_cpl_status_ep            : flt_q_cpl_status_rc ;
    assign flt_q_outrange_ur                        = device_is_ep  ? flt_q_outrange_ur_int     : 1'b0 ;
    assign flt_q_valid_np                           = device_is_ep  ? flt_q_valid_np_ep              : flt_q_valid_np_rc ;
    assign flt_q_addr                               = device_is_ep  ? flt_q_addr_ep                  : flt_q_addr_rc ;
    assign flt_q_io_req_in_range                    = device_is_ep  ? flt_q_io_req_in_range_ep       : flt_q_io_req_in_range_rc ;
    assign flt_q_func_num                           = device_is_ep  ? flt_q_func_num_ep              : flt_q_func_num_rc;
    assign flt_q_in_membar_range                    = device_is_ep  ? flt_q_in_membar_range_ep       : flt_q_in_membar_range_rc;
    assign l_set_radm_rcvd_req_ca                   = device_is_ep  ? l_set_radm_rcvd_req_ca_ep      : l_set_radm_rcvd_req_ca_rc;
    assign l_set_radm_rcvd_req_ur                   = device_is_ep  ? l_set_radm_rcvd_req_ur_ep      : l_set_radm_rcvd_req_ur_rc;
    assign l_set_radm_hdr_log_valid                 = device_is_ep  ? l_set_radm_hdr_log_valid_ep    : l_set_radm_hdr_log_valid_rc;
    assign l_set_radm_ecrc_err                      = device_is_ep  ? l_set_radm_ecrc_err_ep         : l_set_radm_ecrc_err_rc;
    assign flt_q_valid_ur_wo_poisn_err              = device_is_ep  ? flt_q_valid_ur_wo_poisn_err_ep : flt_q_valid_ur_wo_poisn_err_rc;
    assign l_set_radm_mlf_tlp_err                   = device_is_ep  ? l_set_radm_mlf_tlp_err_ep : l_set_radm_mlf_tlp_err_rc; // ms_con_np    
    assign cfg_bar_match_reg                        = device_is_ep  ? cfg_bar_match_reg_ep           : {{((NF*6)-(RC_NF*6)){1'b0}},cfg_bar_match_reg_rc};
    assign cfg_bar_is_io_reg                        = device_is_ep  ? cfg_bar_is_io_reg_ep           : {{((NF*6)-(RC_NF*6)){1'b0}},cfg_bar_is_io_reg_rc};
    assign cfg_rom_match_reg                        = device_is_ep  ? cfg_rom_match_reg_ep           : {{((NF)-(RC_NF)){1'b0}},cfg_rom_match_reg_rc};
    assign l_set_radm_mlf_tlp_err_ptr               = device_is_ep  ? l_set_radm_mlf_tlp_err_ptr_ep  : l_set_radm_mlf_tlp_err_ptr_rc;

    assign rtranslated_tlp_addr                     = device_is_ep  ? rtranslated_tlp_addr_ep        : rtranslated_tlp_addr_rc;

    assign flt_q_pipe_en                            = device_is_ep  ? flt_q_pipe_en_ep               : flt_q_pipe_en_rc ;
    assign target_acquisition_rc_int                = `FLT_DESTINATION_TRGT1;
    assign target_acquisition                       = device_is_ep  ? target_acquisition_ep          : target_acquisition_rc_int;
    assign int_flt_q_destination                    = device_is_ep  ? int_flt_q_destination_ep       : int_flt_q_destination_rc;
    assign flt_q_valid_ur_err                       =  device_is_ep ? flt_q_valid_ur_err_ep      : flt_q_valid_ur_err_rc;
    assign flt_q_poisoned_discard                   = device_is_ep  ? flt_q_poisoned_discard_ep      : flt_q_poisoned_discard_rc;
    assign flt_q_ecrc_discard                       = device_is_ep  ? flt_q_ecrc_discard_ep      : flt_q_ecrc_discard_rc;
    assign latch_hdr_pipe_en                        = device_is_ep  ? latch_hdr_pipe_en_ep           : latch_hdr_pipe_en_rc;
    assign flt_q_mem_req_range                      = device_is_ep  ? flt_q_mem_req_range_ep         : flt_q_mem_req_range_rc;
    assign flt_q_locked_rd_tlp                      = device_is_ep  ? flt_q_locked_rd_tlp_ep         : flt_q_locked_rd_tlp_rc; 
    assign valid_def_memwr_request                  = device_is_ep  ? valid_def_memwr_request_ep     : valid_def_memwr_request_rc;
    assign flt_q_valid_ca_np                        = device_is_ep  ? flt_q_valid_ca_np_ep           : flt_q_valid_ca_np_rc;
    assign flt_q_unqual_dv                          = device_is_ep  ? flt_q_unqual_dv_ep             : flt_q_unqual_dv_rc;
    assign flt_q_unqual_hv                          = device_is_ep  ? flt_q_unqual_hv_ep             : flt_q_unqual_hv_rc;
    assign flt_q_unqual_eot                         = device_is_ep  ? flt_q_unqual_eot_ep            : flt_q_unqual_eot_rc;
    assign l_flt_q_hv_int                           = device_is_ep  ? (flt_q_unqual_hv_ep) : (flt_q_unqual_hv_rc); 
    assign l_flt_q_dv_int                           = device_is_ep  ? (flt_q_unqual_dv_ep) : (flt_q_unqual_dv_rc);
    assign l_flt_q_eot_int                          = device_is_ep  ? (flt_q_unqual_eot_ep): (flt_q_unqual_eot_rc);
    // cfg
    assign  radm_cfg_o.radm_rcvd_acs_err            = device_is_ep  ? 0 : radm_cfg_o_int.radm_rcvd_acs_err;

    assign radm_cfg_o.radm_snoop_upd                = device_is_ep  ? radm_cfg_o_int.radm_snoop_upd     : 0;
    assign radm_cfg_o.radm_snoop_bus_num            = device_is_ep  ? radm_cfg_o_int.radm_snoop_bus_num : 0;
    assign radm_cfg_o.radm_snoop_dev_num            = device_is_ep  ? radm_cfg_o_int.radm_snoop_dev_num : 0;
    assign radm_cfg_o.cfg_segment_id                = device_is_ep  ? radm_cfg_o_int.cfg_segment_id     : 0;
    assign radm_cfg_o.radm_rcvd_req_ca              = device_is_ep  ? radm_cfg_o_int.radm_rcvd_req_ca   : radm_rcvd_req_ca;
    assign radm_cfg_o.radm_rcvd_req_ur              = device_is_ep  ? radm_cfg_o_int.radm_rcvd_req_ur : radm_rcvd_req_ur ;
    assign radm_cfg_o.radm_hdr_log_valid            = device_is_ep  ? radm_cfg_o_int.radm_hdr_log_valid : radm_hdr_log_valid_int_rc;
    assign radm_hdr_log_valid_in            = device_is_ep  ? radm_cfg_o_int.radm_hdr_log_valid : radm_hdr_log_valid_int_rc;
    assign flt_q_data_o_np.flt_q_tlp_abort          = device_is_ep  ? int_flt_q_tlp_abort : flt_q_tlp_abort_rc;
    assign radm_cfg_o.radm_rcvd_wreq_poisoned       = device_is_ep ? radm_cfg_o_int.radm_rcvd_wreq_poisoned : radm_rcvd_wreq_poisoned_int;
    assign l_set_radm_rcvd_wreq_poisoned            = device_is_ep ?  l_set_radm_rcvd_wreq_poisoned_ep : l_set_radm_rcvd_wreq_poisoned_rc;

    // cfg end


  assign radm_cfg_o.flt_cdm_pf = flt_q_func_num_d;

  // RC logic
    assign  flt_q_func_mismatch_rc       = (flt_q_cfg_func_num  > RC_NF-1);
    assign  flt_q_dev_num_rc             = flt_q_hdr_dw3[15:11];                         // for cfg transaction only
    assign  flt_q_addr_rc                = flt_q_addr_int;

   //`ifdef CX_RC_ELBI
   //reg [1:0] target_acquisition;
   //assign enable_mask_pois_if_trgt0_destination = !(radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_UNMASK_UR_POIS_TRGT0] && (target_acquisition == `FLT_DESTINATION_TRGT0));
   //`else
   //assign enable_mask_pois_if_trgt0_destination = 1;
   //`endif

    always_comb
    begin: FUNC_NUMBER_LOOKUP
      logic  [PF_WD-1:0] tmp_func_num;

      flt_q_io_req_in_range_rc        = 0;
      flt_q_outside_mem_range         = 0;
      flt_q_outside_prefmem_range     = 0;
      flt_q_outside_alt_mem_range     = 0;
      flt_q_outside_alt_prefmem_range = 0;
      flt_q_func_num_rc               = `CX_RC_FUNC_NUM;
      tmp_func_num                    = 0;

      if ( flt_q_iord_req || flt_q_iowr_req)    begin                                                  // IO transaction
        {flt_q_func_num_rc,flt_q_io_req_in_range_rc} = one_hot_decode_2_zero(radm_cfg_tlp_i.cfg_io_match[0]);
          // ACS Upstream Forwarding:
          if (radm_cfg_i.cfg_acs_up_forward_cap & radm_cfg_i.cfg_acs_up_forward_en ) begin
            flt_q_io_req_in_range_rc   = 1;
          end
      end
        else
        if (flt_q_locked_rd || flt_q_memrd_req  || flt_q_def_memwr_req || flt_q_atomic_op) begin             // memory access
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
        else
          if (flt_q_cfg_req & !flt_q_func_mismatch_rc)
              flt_q_func_num_rc = flt_q_cfg_func_num;
    end


    assign  flt_q_in_membar_range_rc       = (cfg_bar_match_reg_rc[0]) ? 0 : (cfg_bar_match_reg_rc[1]) ? 1:3'b111;
    assign  flt_q_valid_ur_wo_poisn_err_rc = flt_q_valid_ur_np_wo_poisoned;  // vendor msg is supported, msg with poison is a ur
    assign  flt_q_valid_ur_err_rc          = flt_q_valid_ur_np;  // UR, including poisoned tlp

    always_comb
    begin: ERROR_PROCESSING
        l_set_radm_rcvd_req_ca_rc              = 1'b0;
        l_set_radm_rcvd_req_ur_rc              = 1'b0;
        l_set_radm_rcvd_wreq_poisoned_rc       = 1'b0;
        l_set_radm_rcvd_cpl_ur                 = 1'b0;
        l_set_radm_hdr_log_valid_rc            = 1'b0;
        l_set_radm_ecrc_err_rc                 = 1'b0;
        l_set_radm_mlf_tlp_err_rc              = 1'b0;
        l_set_radm_mlf_tlp_err_ptr_rc          = 8'd0;
        l_set_radm_rcvd_acs_err                = 1'b0;
        if (flt_q_unqual_eot && !rtlh_dllp_err_d  ) begin
            l_set_radm_ecrc_err_rc                 =  l_flt_q_ecrc_err & (!tmp_mlf_err);
            l_set_radm_mlf_tlp_err_rc              =  tmp_mlf_err ;
            l_set_radm_mlf_tlp_err_ptr_rc          =  tmp_mlf_err_ptr;
            l_set_radm_rcvd_wreq_poisoned_rc       =  flt_q_poisoned_err & !l_flt_q_tlp_type[CPL_TYPE] & (!l_flt_q_ecrc_err) & (!tmp_mlf_err) & (!flt_q_valid_ur_wo_poisn_err_rc) & (!flt_q_valid_ca_err) 
                                                      & !flt_q_mask_wreq_poisoned_reporting;
            // filter detected errors for a received request
            // RC CA when ECRC is for target0 to complete with CA
            l_set_radm_rcvd_req_ca_rc          =  flt_q_valid_ca_err & !tmp_mlf_err & !l_flt_q_ecrc_err
                                                   & !flt_q_acs_err
                                                  ;
            l_set_radm_rcvd_req_ur_rc          =  flt_q_valid_ur_err_rc & !tmp_mlf_err 
                                                  & !l_flt_q_ecrc_err
                                                   & !flt_q_acs_err
                                                   & !(flt_q_poisoned_err & (!flt_q_valid_ur_wo_poisn_err_rc))   
                                                  ; 
            // filter detected errors for a received completion
            // filter detected errors for a received message
            l_set_radm_hdr_log_valid_rc        =  (l_flt_q_ecrc_err      ||
                                                   tmp_mlf_err                ||
                                                   l_set_radm_rcvd_wreq_poisoned_rc    ||
                                                   flt_q_valid_ur_wo_poisn_err_rc ||
                                                   flt_q_valid_ur_err_rc  ||
                                                   flt_q_valid_ca_err  
                                                   || flt_q_acs_err
                                                   );
              l_set_radm_rcvd_acs_err         = flt_q_acs_err & !tmp_mlf_err & !l_flt_q_ecrc_err;
        end
    end 



    assign  rtranslated_tlp_addr_rc                 =  rtranslated_addr_in_d;


    // Detect when translated address value is greater than the RADM or AMBA master
    // address bus widths, report UR.
    logic flt_q_addr_gt_bus_width_at;
    logic flt_q_addr_gt_mstr_addr_width_at;
    assign flt_q_addr_gt_bus_width_at       = 1'b0;
    assign flt_q_addr_gt_mstr_addr_width_at = 1'b0;

    assign flt_q_pipe_en_rc = !radm_cfg_i.upstream_port && ((|l_flt_q_hv) || (|l_flt_q_dv)); // delay_n_w_enable should handle inside enable_delayed signal to flush the pipe

      assign enable_mask_pois_if_trgt0_destination_rc = 1;

      assign  flt_q_ecrc_discard_rc      = l_flt_q_ecrc_err & !radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_ECRC_DISCARD]; // when discard an ECRC TLP is desired
      assign  flt_q_poisoned_discard_rc  = flt_q_poisoned_err & !(radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_UR_POIS] & enable_mask_pois_if_trgt0_destination_rc) ;



    assign latch_hdr_pipe_en_rc = !radm_cfg_i.upstream_port && (ord_flt_data_np_in.ord_flt_dv | hdr_dec_flt_np_in.hdr_dec_flt_hv); 

    // Detect if an access greater than the address bus width occurs
    // Check both the AMBA address bus and Core. Don't do this check here if
    // address translation support is enabled. Need to do it after we get the
    // address back
    logic flt_q_addr_gt_bus_width;
    logic flt_q_addr_gt_mstr_addr_width;
      assign flt_q_addr_gt_bus_width        = 0;
      assign flt_q_addr_gt_mstr_addr_width  = 0;

    assign  flt_q_mem_req_range_rc     =  (     radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_UR_OUTSIDE_BAR    ]
                                            ||  flt_q_mem_req_in_range
                                            || (flt_q_outside_mem_range && flt_q_outside_prefmem_range && !(radm_cfg_i.cfg_cxl_alt_bme & alt_bus_num_valid))
                                            || flt_q_outside_alt_range
                                           ) && !(flt_q_addr_gt_mstr_addr_width || flt_q_addr_gt_bus_width);

    assign  flt_q_locked_rd_tlp_rc     =  (!radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_LOCKED_RD_AS_UR  ] &&  flt_q_locked_rd       );


      assign flt_q_atomic_discard_rc = 1'b0;

    assign valid_def_memwr_request_rc = flt_q_def_memwr_req && (`CX_DEF_MEM_WR_CPL_EN || `CX_DEF_MEM_WR_ROUTING_EN);

    generate 
      if (DMWR_ADDITIONAL_FLT_RULES) begin : gen_dmwr_add_flt_rules_rc
        wire not_16_dw_aligned_rc;
        assign not_16_dw_aligned_rc = | flt_q_addr_rc[5:2];
        assign unsupported_def_memwr_request_rc = `CX_DEF_MEM_WR_CPL_EN && valid_def_memwr_request_rc &&
                                                  ( 
                                                      flt_q_dw_len != 10'd16       // Transaction is not 64-Bytes in Size
                                                   || not_16_dw_aligned_rc         // Address is not 64-bytes Aligned
                                                   || !(&flt_q_first_be_tph && &flt_q_last_be_tph)
                                                  );
      end
      else begin : gen_dmwr_noadd_flt_rules_rc
        assign unsupported_def_memwr_request_rc = `CX_DEF_MEM_WR_CPL_EN && valid_def_memwr_request_rc &&
                                                  ( 
                                                      flt_q_dw_len > MAX_DMWR_SIZE // Transaction Size > MAX_DMWR_SIZE
                                                   || flt_q_dw_len == 10'h0        // Transaction Size = zero
                                                  );
      end
    endgenerate

    // We don't support DMWrs Ops targeting TRGT0 (ELBI)
      assign flt_q_def_memwr_discard_rc = valid_def_memwr_request_rc && unsupported_def_memwr_request_rc;

    assign  flt_q_valid_ur_np_wo_poisoned = (flt_q_cfg1rd_req    ||
                                             flt_q_cfg1wr_req    ||
                                             flt_q_cfg0rd_req    ||
                                             flt_q_cfg0wr_req    ||
                                             flt_q_memrd_req     ||
                                             (flt_q_def_memwr_req && !flt_q_def_memwr_discard_rc) ||
                                             flt_q_locked_rd     ||
                                             flt_q_iord_req      ||
                                             flt_q_iowr_req      ||
                                             (flt_q_atomic_op && !flt_q_atomic_discard_rc)
                                             ) && (!flt_q_valid_np);


        assign  flt_q_valid_ca_np_rc       = flt_q_valid_np && (!flt_q_rd_size_in_range  || flt_q_atomic_discard_rc || flt_q_def_memwr_discard_rc
                                              || flt_q_acs_err      // CA condition met if any of the TLP has an ACS Violation
                                              );


      assign  flt_q_cpl_tlp           = (({flt_q_fmt,flt_q_type} == `CPLLK) || ({flt_q_fmt,flt_q_type} == `CPLDLK) ||
                                         ({flt_q_fmt,flt_q_type} == `CPL)   || ({flt_q_fmt,flt_q_type} == `CPLD));
      assign  acs_src_valid           = (flt_q_cpl_tlp) ? 1: ((((flt_q_REQID[15:8] < radm_cfg_i.cfg_2ndbus_num[7:0]) || (flt_q_REQID[15:8] > radm_cfg_i.cfg_subbus_num[7:0])) && !(alt_bus_num_valid && radm_cfg_i.cfg_cxl_alt_bme)) && (radm_cfg_i.cfg_acs_validation_cap && radm_cfg_i.cfg_acs_validation_en)) ? 0 : 1;              // If acs_src_valid == 0, an ACS Violation Error is generated
      assign  acs_at_valid            = !(flt_q_memrd_req ||  valid_def_memwr_request_rc || flt_q_locked_rd || flt_q_valid_atomic_request) ? 1: (flt_q_ats != 2'b0) && (radm_cfg_i.cfg_acs_at_blocking_cap & radm_cfg_i.cfg_acs_at_blocking_en ) ? 0 : 1;  // If acs_at_valid == 0, an ACS Violation Error is generated

      assign  flt_q_acs_err           = (!acs_src_valid || !acs_at_valid) && flt_q_pcie_format;      // The TLP has an ACS Violation if any of the ACS conditions acs_src_valid or acs_at_valid are not met

      //assign  radm_cfg_o_int.radm_rcvd_acs_err       = route_error_to_func( set_radm_rcvd_acs_err                  , flt_q_func_num_d);
      assign  radm_cfg_o_int.radm_rcvd_acs_err       = set_radm_rcvd_acs_err ;


  assign  flt_q_cpl_status_rc        = (flt_q_valid_ur_np ) ? `UR_CPL_STATUS :
                                       (flt_q_valid_ca_np ) ? (l_flt_q_ecrc_err ? flt_q_actual_cpl_status_ecrc_flt : `CA_CPL_STATUS ) : `SU_CPL_STATUS;

  delay_n
  
  #(  .N  (PIPE_VF_INDEX       ), 
      .WD (PIPE_CFG_WIDTH_RC   )
  ) u_cfg_delay_rc 
  (
    .clk        (core_clk   ),
    .rst_n      (core_rst_n ),
    .clear      (1'b0       ),
    .din        ({radm_cfg_tlp_i.cfg_bar_match[5:0], 
                  radm_cfg_i.cfg_bar_is_io[5:0], 
                  radm_cfg_tlp_i.cfg_rom_match[0], 
                  radm_cfg_tlp_i.cfg_mem_match[0],
                  radm_cfg_tlp_i.cfg_prefmem_match[0]
                 }),
    .dout       ({cfg_bar_match_reg_rc, 
                  cfg_bar_is_io_reg_rc, 
                  cfg_rom_match_reg_rc, 
                  cfg_mem_match_reg_rc,
                  cfg_prefmem_match_reg_rc
                 })
  );

//    assign  radm_rcvd_req_ca                = route_error_to_func((set_radm_rcvd_req_ca || (translate_enable && |flt_q_data_o_np.flt_q_eot && !flt_q_data_o_np.flt_q_dllp_abort && rtranslated_err_in_d[1])) , flt_q_func_num_d);
    assign  radm_rcvd_req_ur                = route_error_to_func((set_radm_rcvd_req_ur || (translate_enable && |flt_q_data_o_np.flt_q_eot && !flt_q_data_o_np.flt_q_dllp_abort && (rtranslated_err_in_d[0] || flt_q_addr_gt_mstr_addr_width_at || flt_q_addr_gt_bus_width_at))) , flt_q_func_num_d);
  assign  radm_hdr_log_valid_int_rc         =  route_error_to_func( set_radm_hdr_log_valid , flt_q_func_num_d);

    assign  radm_rcvd_req_ca                = (set_radm_rcvd_req_ca || (translate_enable && |flt_q_data_o_np.flt_q_eot && !flt_q_data_o_np.flt_q_dllp_abort && rtranslated_err_in_d[1])) ;
//    assign  radm_rcvd_req_ur                = (set_radm_rcvd_req_ur || (translate_enable && |flt_q_data_o_np.flt_q_eot && !flt_q_data_o_np.flt_q_dllp_abort && (rtranslated_err_in_d[0] || flt_q_addr_gt_mstr_addr_width_at || flt_q_addr_gt_bus_width_at)));
//  assign  radm_hdr_log_valid_int_rc         =  set_radm_hdr_log_valid;


  always_comb begin:  FILTER_PROCESS_RC
    int_flt_q_destination_rc             = `FLT_DESTINATION_TRASH;           // DEFAULT to trash
    if (flt_q_invalid_tlp) begin
      int_flt_q_destination_rc           = `FLT_DESTINATION_TRASH;
    end else begin
      if (l_flt_q_tlp_type[NP_TYPE])
      begin                                                                    // [----------- NON-POSTED -----------]
        if (!flt_q_valid_ur_np & !flt_q_valid_ca_np)                      // VALID
        begin
              int_flt_q_destination_rc     = `FLT_DESTINATION_TRGT1;           //  VALID, or VALID UR
        end
      else                                                                     // VALID UR
        if (radm_cfg_i.default_target)                                         // target determined by radm_cfg_i.default_target
        begin
          int_flt_q_destination_rc         = `FLT_DESTINATION_TRGT1;           //  ALL others, valid or not
        end
        else    
        begin
          int_flt_q_destination_rc         = `FLT_DESTINATION_TRGT0; 
        end
      end
    end
  end

//  // CTRL_registers_path
  always_ff @(posedge core_clk or negedge core_rst_n)
  begin  
    if (!core_rst_n) begin
      flt_q_unqual_dv_rc    <= #TP 0;
      flt_q_unqual_hv_rc    <= #TP 0;
      flt_q_unqual_eot_rc   <= #TP 0;
    end else if(!radm_cfg_i.upstream_port) begin
      flt_q_unqual_dv_rc    <= #TP ord_flt_data_np_in.ord_flt_dv;
      flt_q_unqual_hv_rc    <= #TP hdr_dec_flt_np_in.hdr_dec_flt_hv;
      flt_q_unqual_eot_rc   <= #TP ord_flt_data_np_in.ord_flt_eot;
    end
  end

  //AX subordinate inbound behaviour adding TDISP rules

  assign  flt_q_valid_np_rc          = ((flt_q_mem_req_range && (flt_q_valid_atomic_request | flt_q_memrd_req | valid_def_memwr_request | flt_q_locked_rd_tlp) && valid_ats && flt_q_pcie_valid_tc)
                                       || ((flt_q_cfg1rd_req || flt_q_cfg1wr_req || flt_q_cfg0rd_req || flt_q_cfg0wr_req) & flt_q_pcie_valid_tc & radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_RC_CFG_DISCARD])
                                       || ((flt_q_iord_req   || flt_q_iowr_req) && flt_q_pcie_valid_tc && radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_RC_IO_DISCARD]))
                                        ;

    assign  radm_cfg_o.radm_drs_msg          = 'd0;
      assign  radm_cfg_o.radm_frs_msg        = 'd0;
      assign  radm_cfg_o.radm_frs_msg_reason = 'd0;  //req id already input above
    assign radm_cfg_o.radm_msg_ltr_latency   =  0; 
    assign radm_cfg_o.radm_msg_ltr           =  0; 


    assign alt_bus_num_valid       = ((flt_q_REQID[15:8] >= radm_cfg_i.cfg_cxl_alt_bus_base[7:0]) && (flt_q_REQID[15:8] <= radm_cfg_i.cfg_cxl_alt_bus_limit[7:0]));
    assign flt_q_outside_alt_range = alt_bus_num_valid & (flt_q_outside_alt_mem_range & flt_q_outside_alt_prefmem_range);



// Addition of UR cpl status  for ECRC error when link is in FLIT mode 
 assign flt_q_actual_cpl_status_ecrc_flt = l_flt_q_ecrc_err ? `UR_CPL_STATUS : `SU_CPL_STATUS;   


 // RC logic ends




  always_ff @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n)
      int_app_req_retry_en    <= #TP 0;
    else
      int_app_req_retry_en    <= #TP app_req_retry_en;

  always_ff @(posedge core_clk or negedge core_rst_n)
  begin: APP_PF_REQ_RETRY
    if (!core_rst_n) begin
      int_app_pf_req_retry_en           <= #TP 0;
    end else begin
      for (int j=0; j<NF; j=j+1) begin
        int_app_pf_req_retry_en[j]      <= #TP app_pf_req_retry_en[j];
      end // for j
    end
  end


  assign app_req_retry_en_tmp    = int_app_req_retry_en || ((raw_flt_q_func_num < NF) && int_app_pf_req_retry_en[raw_flt_q_func_num[ALT_PF_WD-1:0]])
 ;


    assign  flt_q_dev_num_ep             =  flt_q_hdr_dw3[15:11];                         // for cfg transaction only
  


    logic flt_q_mismatch_func_num;
    assign  flt_q_mismatch_func_num  = (flt_q_cfg_func_num   > radm_cfg_i.cfg_max_func_num);


      // cfg type 1 on ide selective stream must match the entire BDF 
      assign  flt_q_func_mismatch_ep         = flt_q_mismatch_func_num;

    assign  flt_q_addr_ep      = flt_q_addr_int;



  assign  flt_q_actual_cpl_status =   (flt_q_valid_ur_np | flr_in_progress)  ? `UR_CPL_STATUS :
                                      (flt_q_valid_ca_np) ? (l_flt_q_ecrc_err ? flt_q_actual_cpl_status_ecrc_flt : `CA_CPL_STATUS ) : `SU_CPL_STATUS;                                        // the CA status: 1. TRGT0 is the destination and more than 1 dword is
                                                                            // being requested. This is a limitation of current LBC module.
                                                                            // 2. when ecrc detected and it is non posted TLP
  assign  flt_q_cpl_status_ep        = (((int_flt_q_destination[1:0] == `FLT_DESTINATION_TRGT0) && app_req_retry_en_tmp && flt_q_cfg_req) ? `CRS_CPL_STATUS:
                                        ((int_flt_q_destination[1:0] == `FLT_DESTINATION_TRGT0) && app_req_retry_en_tmp) ? `UR_CPL_STATUS   :
                                        flt_q_actual_cpl_status);


    always_comb begin 
      radm_cfg_o_int.radm_snoop_upd           = 0;
        cfg_segment_id_vld                    = 0;  
      radm_cfg_o_int.radm_snoop_upd           = (|l_flt_q_eot) & !rtlh_dllp_err_d   & !flt_q_rtlh_abort & !l_flt_q_ecrc_err &  flt_q_cfg0wr_req & !flt_q_poisoned_discard_ep & flt_q_valid_np;

        if(flit_mode==1) begin
          radm_cfg_o_int.radm_snoop_upd   =  radm_cfg_o_int.radm_snoop_upd && (!flt_q_hdr_ohc_err);
        end

        cfg_segment_id_vld                    = (|l_flt_q_eot) & !rtlh_dllp_err_d   & !flt_q_rtlh_abort & !l_flt_q_ecrc_err &  flt_q_cfg0wr_req & !flt_q_poisoned_discard_ep & flt_q_valid_np & flt_q_cfg_segment_id[8];
    end
  assign  radm_cfg_o_int.radm_snoop_bus_num         = flt_q_cpl_reqid[15:8];

    assign  radm_cfg_o_int.cfg_segment_id           = {cfg_segment_id_vld,flt_q_cfg_segment_id[7:0]};
    assign  radm_cfg_o_int.radm_snoop_dev_num       = flt_q_cpl_reqid[7:3];


  assign enable_mask_pois_if_trgt0_destination_ep  = !(radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_UNMASK_UR_POIS_TRGT0] 
                                                     & (target_acquisition_ep == `FLT_DESTINATION_TRGT0));


    assign pf             = flt_q_cfg_func_num;


  // ----------------------------------------------------------------------------
  // Register CDM Interface Inputs
  // ----------------------------------------------------------------------------
  logic                  cfg_rcrb_mbar0_match_reg;          // indication that tlp is within RCRB MEMBAR0
  logic                  cfg_rcrb_mbar0_match_int_reg;      // indication that tlp is within RCRB MEMBAR0 in CDM
  logic                  rcrb_mbar0_access_wire;
  logic                  cfg_rcrb_match_reg;                // indication that tlp is within RCRB
  logic [NF-1:0]         cfg_cxl_mbar0_match_reg;           // indication that tlp is within the CXL Component Registers Memory Range
  logic                  cxl_2_0_mbar0_access_int_reg;      // indication that tlp is within the CXL Component Registers Memory Range in CDM
  logic                  rcrb_access_wire;
  logic                  cxl_2_0_mbar0_access_wire;
  logic [NF-1:0][5:0]    cfg_cxl_mbar0_match_reg_ext;

  always_comb begin
    cfg_cxl_mbar0_match_reg_ext = '1;
    for(int i=0; i<NF; i++)
        cfg_cxl_mbar0_match_reg_ext[i][0] = ~cfg_cxl_mbar0_match_reg[i];
  end
  
  // ----------------------------------------------------------------------------
  // RCRB Base Address Latching
  // ----------------------------------------------------------------------------
  logic          first_mem_access_cxl;
  logic          cxl_rcrb_enable_d;
  
  always_ff @(posedge core_clk or negedge core_rst_n)
  begin: first_mem_access_PROC
    if (!core_rst_n) begin
      first_mem_access_cxl <= #TP 1'b0;
      cxl_rcrb_enable_d    <= #TP 1'b0;
    end
    else begin
      cxl_rcrb_enable_d    <= #TP radm_cfg_i.cxl_rcrb_enable;

      if (radm_cfg_i.upstream_port && radm_cfg_i.cxl_rcrb_enable && !cxl_rcrb_enable_d) 
        first_mem_access_cxl <= #TP 1'b1;
      else if (flt_q_mem_req && flt_q_data_o_np.flt_q_eot/*[0]*/)
        first_mem_access_cxl <= #TP 1'b0;
    end
  end
  
  always_ff @(posedge core_clk or negedge core_rst_n)
  begin: rcrb_base_address_PROC
    if (!core_rst_n) begin
      rcrb_base_addr       <= #TP 1'b0;
      rcrb_base_addr_valid <= #TP 1'b0;
    end
    else begin
      rcrb_base_addr_valid <= #TP 1'b0;
      if (radm_cfg_i.cxl_rcrb_enable && first_mem_access_cxl && flt_q_mem_req && flt_q_unqual_hv_ep)
      begin
        rcrb_base_addr       <= #TP extract_addr[63:12];
        rcrb_base_addr_valid <= #TP 1'b1;
      end
    end
  end
  // ----------------------------------------------------------------------------

  // ----------------------------------------------------------------------------
  // RCRB Request in Range
  // ----------------------------------------------------------------------------
  assign  flt_q_rcrb_req_in_range  = ((cfg_rcrb_match_reg || cfg_rcrb_mbar0_match_reg) && flt_q_mem_req) || first_mem_access_cxl;
  // ----------------------------------------------------------------------------

  assign  io_trgt_map                = |(radm_cfg_i.target_mem_map & cfg_bar_match_reg_ep & (cfg_bar_is_io_reg_ep)); 
  assign  mem_trgt_map_ep            = |(radm_cfg_i.target_mem_map & cfg_bar_match_reg_ep & (~cfg_bar_is_io_reg_ep) & cfg_cxl_mbar0_match_reg_ext);
  assign  rom_trgt_map_ep            = |(radm_cfg_i.target_rom_map & cfg_rom_match_reg_ep); 


  // TLP Bypass feature. radm_cfg_i.cfg_cfg_tlp_bypass_en is the value of register CFG_TLP_BYPASS_EN_REG.
  // When radm_cfg_i.cfg_cfg_tlp_bypass_en is set, the destination control signal coerce_cfg_tlp_to_trgt1 (from CONFIG_LIMIT_REG) is disabled. 
  // If the top level application pin app_req_retry_en is asserted, the value of radm_cfg_i.cfg_cfg_tlp_bypass_en is ignored.

  assign coerce_cfg_tlp_to_trgt1_en  = (!int_app_req_retry_en & radm_cfg_i.cfg_cfg_tlp_bypass_en) | coerce_cfg_tlp_to_trgt1;

  always_comb begin
    target_acquisition_ep        = `FLT_DESTINATION_TRASH;
    if (flt_q_cfg_req)    begin
      if (coerce_cfg_tlp_to_trgt1_en)
        target_acquisition_ep    = radm_cfg_i.cfg_target_above_config_limit;
      else    
        target_acquisition_ep    = `FLT_DESTINATION_TRGT0;
    end
    else if (flt_q_iord_req || flt_q_iowr_req)  begin
      if (flt_q_io_req_in_range_ep)
        if (io_trgt_map)
          target_acquisition_ep  =  `FLT_DESTINATION_TRGT1;
        else
          target_acquisition_ep  =  `FLT_DESTINATION_TRGT0;
      else  if (radm_cfg_i.default_target)
        target_acquisition_ep    =  `FLT_DESTINATION_TRGT1;
      else
        target_acquisition_ep    =  `FLT_DESTINATION_TRGT0;
    end
    else if (flt_q_mem_req) begin // MEMORY (or ROM)
      if (flt_q_rcrb_req_in_range) begin
          target_acquisition_ep  =  `FLT_DESTINATION_TRGT0;
      end
      else
      if (flt_q_mem_req_in_range)
        if (mem_trgt_map_ep)
          target_acquisition_ep  =  `FLT_DESTINATION_TRGT1;
        else
          target_acquisition_ep  =  `FLT_DESTINATION_TRGT0;
      else if (flt_q_rom_req_in_range)
        if (rom_trgt_map_ep)
          target_acquisition_ep  =  `FLT_DESTINATION_TRGT1;
        else
          target_acquisition_ep  =  `FLT_DESTINATION_TRGT0;
    else if (radm_cfg_i.default_target)
      target_acquisition_ep      =  `FLT_DESTINATION_TRGT1;
    else
      target_acquisition_ep      =  `FLT_DESTINATION_TRGT0;
    end    // Mem transactions
  end

  assign  flt_q_io_req_in_range_ep      = |(cfg_bar_match_reg_ep & cfg_bar_is_io_reg_ep) ;

  // Used for cfg/msg/cpl only
    assign pf_to_match    = (flt_q_tlp_is_msg && (flt_q_type[2:0] == 3'b010))
                            | flt_q_cfg_req ? flt_q_cfg_func_num : flt_q_REQID[PF_WD-1:0];

  always_comb 
  begin : GEN_RAW_CFG_FUNC_NUM

    raw_cfg_func_num            = 0;
    coerce_cfg_tlp_to_trgt1_int = 1'b0;

    for (int idx=0; idx<NF; idx=idx+1)
    begin
      if (idx==pf_to_match)
      begin
          coerce_cfg_tlp_to_trgt1_int = radm_cfg_tlp_i.cfg_config_above_match[idx];
        raw_cfg_func_num              = pf_to_match;
      end
    end //for idx
  end

    assign raw_func_num_unreg   = (mem_req | io_req)    ?  pfvf_func_num  :
                                  (cfg_req )            ?  pf             :
                                  flt_q_REQID[PF_WD-1:0]; //completions

  // If PIPE_VF_INDEX==1, cfg_*match are anticipated by one cycle
  // and so are function and bar numbers.
  // We need to delay them in order to align to flt_q* domain
  delay_n
  
  #(  .N        (PIPE_VF_INDEX      ), 
      .WD       (PIPE_VF_INDEX_WIDTH)
  ) u_vf_index_delay
  (
    .clk        (core_clk   ),
    .rst_n      (core_rst_n ),
    .clear      (1'b0       ),
    .din        ({raw_func_num_unreg    , 
                  in_membar_range_unreg , 
                  in_iobar_range_unreg  , 
                  shft_bar_is_io_unreg
                  }),
    .dout       ({raw_flt_q_func_num  , 
                  in_membar_range     , 
                  in_iobar_range      , 
                  shft_bar_is_io
                 })
    );


  delay_n
  
  #(  .N  (PIPE_VF_INDEX      ), 
      .WD (PIPE_CFG_WIDTH_EP  )
  ) u_cfg_delay_ep 
  (
    .clk        (core_clk   ),
    .rst_n      (core_rst_n ),
    .clear      (1'b0       ),
    .din        ({radm_cfg_tlp_i.cfg_bar_match  , 
                  radm_cfg_i.cfg_bar_is_io      , 
                  radm_cfg_tlp_i.cfg_rom_match 
                    ,
                    coerce_cfg_tlp_to_trgt1_int
                 }),
    .dout       ({cfg_bar_match_reg_ep  , 
                  cfg_bar_is_io_reg_ep  , 
                  cfg_rom_match_reg_ep 
                    ,
                    coerce_cfg_tlp_to_trgt1
                 })
    );


  assign raw_flt_q_in_membar_range =                                     (flt_q_mem_req && !shft_bar_is_io[in_membar_range]) ? in_membar_range :
                                     ((flt_q_iord_req | flt_q_iowr_req)
                                     && shft_bar_is_io[in_iobar_range])                  ? in_iobar_range  :
                                     `RADM_OUTSIDE_MEMBAR;

  // If a UR is due to a function specific error then the function number of the
  // targeted function is used in the Completer ID of the Completion TLP.
  // If a UR is due to a non-function specific error then the Completion is not
  // associated with a specific function within the device and the function
  // number is Reserved (i.e. the function number field of the Completer ID is
  // set to all 0s).
  assign  flt_q_func_num_ep                   = flt_q_outrange_ur ? 0 : raw_flt_q_func_num;
  // set membar to outside range if this is a UR
  assign  flt_q_in_membar_range_ep            = (flt_q_valid_ur_np | flr_in_progress) ? `RADM_OUTSIDE_MEMBAR : raw_flt_q_in_membar_range;

  assign  flt_q_valid_ur_wo_poisn_err_ep      = flt_q_valid_ur_xtrgt0_wo_poisn || flt_q_valid_ur_xtrgt1_wo_poisn || flt_q_valid_ur_xtrash_wo_poisn || flr_in_progress;// UR, assuming no poisoned tlp

  assign  flt_q_valid_ur_err_ep               = flt_q_valid_ur_xtrgt0 || flt_q_valid_ur_xtrgt1 || flt_q_valid_ur_xtrash || flr_in_progress;// UR, including poisoned tlp

  always_comb 
  begin: set_err_PROC
    l_set_radm_rcvd_req_ca_ep                       = 1'b0;
    l_set_radm_rcvd_req_ur_ep                       = 1'b0;
    l_set_radm_rcvd_wreq_poisoned_ep                = 1'b0;
    l_set_radm_hdr_log_valid_ep                     = 1'b0;
    l_set_radm_ecrc_err_ep                          = 1'b0;
    l_set_radm_mlf_tlp_err_ep                       = 1'b0;
      l_set_radm_mlf_tlp_err_ptr_ep                 = 8'd0;
    l_set_outrange_req_ur                           = 1'b0;
    // RTLH layer reported errors
    if (flt_q_unqual_eot && !rtlh_dllp_err_d  ) begin
      l_set_radm_ecrc_err_ep                          =  l_flt_q_ecrc_err & (!tmp_mlf_err);
      l_set_radm_mlf_tlp_err_ep                       =  tmp_mlf_err;
        l_set_radm_mlf_tlp_err_ptr_ep                 =  tmp_mlf_err_ptr;
      l_set_radm_rcvd_wreq_poisoned_ep                =  flt_q_poisoned_err & !l_flt_q_tlp_type[CPL_TYPE] & (!l_flt_q_ecrc_err) & (!tmp_mlf_err) & (!flt_q_valid_ur_wo_poisn_err_ep) & (!flt_q_valid_ca_err) &                             
                                                         !flt_q_mask_wreq_poisoned_reporting;

      // filter detected errors for a received request
      // EP's CA generated for dwlen>1
      l_set_radm_rcvd_req_ca_ep          =  flt_q_valid_ca_err    & !tmp_mlf_err & !l_flt_q_ecrc_err;
      l_set_radm_rcvd_req_ur_ep          =  flt_q_valid_ur_err_ep & !tmp_mlf_err & !l_flt_q_ecrc_err
                                             & !(flt_q_poisoned_err & (!flt_q_valid_ur_wo_poisn_err_ep))
                                           ;
      l_set_outrange_req_ur              =  flt_q_outrange_ur;
      // filter detected errors for a received completion
      // remain_byte_err is inaccurate,  FIX is TBD

      // filter detected errors for a received message
      l_set_radm_hdr_log_valid_ep        =  (l_flt_q_ecrc_err       ||
                                             tmp_mlf_err            ||
                                             l_set_radm_rcvd_wreq_poisoned_ep     ||
                                             flt_q_valid_ur_wo_poisn_err_ep ||
                                             flt_q_valid_ur_err_ep  ||
                                             flt_q_valid_ca_err  
                                            );
    end
  end

      assign  rtranslated_tlp_addr_ep                 =  rtranslated_addr_in_d;

  assign flt_q_pipe_en_ep               = radm_cfg_i.upstream_port && ((|l_flt_q_hv) || (|l_flt_q_dv)); // delay_n_w_enable should handle inside enable_delayed signal to flush the pipe
  
   // assign  radm_rcvd_req_ca_int        = route_error_to_func( (set_radm_rcvd_req_ca || (translate_enable && rtranslated_err_in_d[1]))        , flt_q_func_num_d);
    assign  radm_rcvd_req_ur_int        = set_outrange_req_ur ? {NF{(set_radm_rcvd_req_ur ||(translate_enable && rtranslated_err_in_d[0])) }}      // when an UR wo function number, go all functions
                                                              : route_error_to_func( (set_radm_rcvd_req_ur || (translate_enable && rtranslated_err_in_d[0])), flt_q_func_num_d);

   assign  radm_hdr_log_valid_int_ep     = 
                                           (set_radm_ecrc_err | set_radm_mlf_tlp_err | set_outrange_req_ur  ) ? {NF{set_radm_hdr_log_valid}} :
                                                                                                               route_error_to_func( set_radm_hdr_log_valid , flt_q_func_num_d);


 
    assign  radm_rcvd_req_ca_int        =  (set_radm_rcvd_req_ca || (translate_enable && rtranslated_err_in_d[1]));
   // assign  radm_rcvd_req_ur_int        = set_outrange_req_ur ? (set_radm_rcvd_req_ur ||(translate_enable && rtranslated_err_in_d[0]))       // when an UR wo function number, go all functions
   //                                                           : (set_radm_rcvd_req_ur || (translate_enable && rtranslated_err_in_d[0]));

//  assign  radm_hdr_log_valid_int_ep     = 
//                                            `ifdef CX_IDE_ENABLE 
//                                               (set_radm_ide_check_failed_to_report | set_radm_ide_pcrc_failed | set_radm_ide_misrouted) ? set_radm_hdr_log_valid : 
//                                           `endif
//                                           (set_radm_ecrc_err | set_radm_mlf_tlp_err | set_outrange_req_ur  ) ? set_radm_hdr_log_valid :
//                                                                                                               set_radm_hdr_log_valid ;
//
    assign radm_cfg_o_int.radm_rcvd_req_ur            = radm_rcvd_req_ur_int;
    assign radm_cfg_o_int.radm_rcvd_wreq_poisoned     = radm_rcvd_wreq_poisoned_int;
    assign radm_cfg_o_int.radm_hdr_log_valid          = radm_hdr_log_valid_int_ep;
    assign radm_cfg_o_int.radm_rcvd_req_ca            =  radm_rcvd_req_ca_int;



  assign  flt_q_ecrc_discard_ep                              = l_flt_q_ecrc_err & !radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_ECRC_DISCARD]; // when discard an ECRC TLP is desired
  assign  flt_q_poisoned_discard_ep                          = flt_q_poisoned_err & !(radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_UR_POIS] & enable_mask_pois_if_trgt0_destination_ep);

  always_comb begin:  FILTER_PROCESS_EP
    int_flt_q_destination_ep           = `FLT_DESTINATION_TRASH;           // DEFAULT to trash
    if (flt_q_invalid_tlp) begin
      int_flt_q_destination_ep           = `FLT_DESTINATION_TRASH;
    end else begin
      if (l_flt_q_tlp_type[NP_TYPE])
      begin                                    // [----------- NON-POSTED -----------]
        if (!flt_q_valid_ur_np & !flr_in_progress & !flt_q_valid_ca_np)                   // VALID
        begin
          int_flt_q_destination_ep       = target_acquisition_ep; 
        end
      else                                                                // VALID UR
        if (radm_cfg_i.default_target)                                             // target determined by radm_cfg_i.default_target
        begin
          int_flt_q_destination_ep       = `FLT_DESTINATION_TRGT1;           //  ALL others, valid or not
        end
        else    
        begin
          int_flt_q_destination_ep       = `FLT_DESTINATION_TRGT0; 
        end
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
      flt_q_unqual_dv_ep    <= #TP ord_flt_data_np_in.ord_flt_dv;
      flt_q_unqual_hv_ep    <= #TP hdr_dec_flt_np_in.hdr_dec_flt_hv;
      flt_q_unqual_eot_ep   <= #TP ord_flt_data_np_in.ord_flt_eot;
    end
  end


  assign latch_hdr_pipe_en_ep = radm_cfg_i.upstream_port && (ord_flt_data_np_in.ord_flt_dv | hdr_dec_flt_np_in.hdr_dec_flt_hv); 

    assign pm_block_tlp           =  get_pm_block(radm_cfg_i.pm_radm_block_tlp,raw_flt_q_func_num);

  assign  flt_q_mem_req_range_ep  =  (radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_UR_OUTSIDE_BAR    ]  || (flt_q_mem_req_in_range
                                                                                                        || flt_q_rcrb_req_in_range
                                                                                                        || flt_q_rom_req_in_range));
  assign  flt_q_io_req_range      =  (radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_UR_OUTSIDE_BAR    ]  ||  flt_q_io_req_in_range );
  assign  flt_q_pm_radm_block_tlp = !(radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_UR_OUTSIDE_BAR    ]  || !pm_block_tlp);
  assign  flt_q_func_mismatch_tlp = !(radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_UR_FUNC_MISMATCH  ]  || !flt_q_func_mismatch_ep);
  assign  flt_q_locked_rd_tlp_ep  =  (radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_LOCKED_RD_AS_UR   ] &&  flt_q_locked_rd        );
  // Unexpected CPL error when a completion received during pm block or CPL is not from CPL lookup table

    assign flr_pf_in_progress   = 0;
    assign flr_vf_in_progress   = 0;
  // In order to avoid dropping Messages which have the Routing Type set to, for example Broadcast,
  // we need to include only Messages with Routing ID = Route by ID;
  // so, if the TLP is a MSG TLP, only Routed by ID are affected by FLR in Progress:
  assign flr_in_progress      = (flr_pf_in_progress | flr_vf_in_progress) && ((flt_q_type[4:3] != 2'b10) || (flt_q_type[2:0] == 3'b010)); 


// We don't support Atomic Ops targeting TRGT0 (ELBI)

  assign flt_q_atomic_discard_ep    = flt_q_valid_atomic_request && (target_acquisition_ep == `FLT_DESTINATION_TRGT0) && flt_q_valid_np;


  // Check for valid DMWr Requests
  assign valid_def_memwr_request_ep = flt_q_def_memwr_req && (`CX_DEF_MEM_WR_CPL_EN);

  // Properly formed DMWr Requests with types or operand sizes not supported [...] must be handled as Completer Abort
  generate 
    if (DMWR_ADDITIONAL_FLT_RULES) begin : gen_dmwr_add_flt_rules_ep
      wire   not_16_dw_aligned_ep;
      assign not_16_dw_aligned_ep = |flt_q_addr_ep[5:2];
      assign unsupported_def_memwr_request_ep = valid_def_memwr_request_ep &&
                                                ( 
                                                    flt_q_dw_len != 10'd16       // Transaction is not 64-Bytes in Size
                                                 || not_16_dw_aligned_ep         // Address is not 64-bytes Aligned
                                                 || !(&flt_q_first_be_tph && &flt_q_last_be_tph)
                                                );
    end
    else begin : gen_dmwr_noadd_flt_rules_ep
      assign unsupported_def_memwr_request_ep = valid_def_memwr_request_ep &&
                                                ( 
                                                    flt_q_dw_len > MAX_DMWR_SIZE // Transaction Size > MAX_DMWR_SIZE
                                                 || flt_q_dw_len == 10'h0        // Transaction Size = zero
                                                );
    end
  endgenerate
  
  // We don't support DMWrs Ops targeting TRGT0 (ELBI)
  assign flt_q_def_memwr_discard_ep       = valid_def_memwr_request_ep && flt_q_valid_np && 
                                         (target_acquisition_ep == `FLT_DESTINATION_TRGT0 ||
                                         unsupported_def_memwr_request_ep                );

    assign pf_hidden_for_cfg_req      = 1'b0;
    assign pf_hidden_for_vendor_msg0  = 1'b0;
    assign pf_hidden_for_vendor_msg1  = 1'b0;

  assign  flt_q_valid_np_ep          =  (((((flt_q_mem_req_range_ep || flt_q_rcrb_req_in_range) && (flt_q_valid_atomic_request || flt_q_memrd_req || valid_def_memwr_request || flt_q_locked_rd_tlp)
                                          && valid_ats
                                          && flt_q_pcie_valid_tc
                                          )  ||
                                        ((flt_q_iord_req      || flt_q_iowr_req)       &&  flt_q_io_req_range))     && !flt_q_pm_radm_block_tlp && flt_q_pcie_valid_tc) ||
                                        ((((flt_q_cfg0rd_req  || flt_q_cfg0wr_req)     && !flt_q_func_mismatch_tlp  && flt_q_pcie_valid_tc) ||
                                        ((flt_q_cfg1rd_req    || flt_q_cfg1wr_req)     && !flt_q_func_mismatch_tlp  && flt_q_pcie_valid_tc &&
                                        radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_CFG_TYPE1_REQ_AS_UR ]))                  &&
                                        !pf_hidden_for_cfg_req
                                        ))
                                        ;



  assign  flt_q_outrange_ur_int    = (!flt_q_mem_req_range_ep && (flt_q_valid_atomic_request || flt_q_memrd_req       || flt_q_locked_rd_tlp_ep || valid_def_memwr_request_ep))  ||
                                    ((flt_q_iord_req      || flt_q_iowr_req)       && !flt_q_io_req_range)     ||
                                    (((flt_q_cfg0rd_req   || flt_q_cfg0wr_req)     && flt_q_func_mismatch_tlp) ||
                                    ((flt_q_cfg1rd_req    || flt_q_cfg1wr_req)     && (flt_q_func_mismatch_tlp ||
                                    !radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_CFG_TYPE1_REQ_AS_UR ]))      ||
                                    pf_hidden_for_cfg_req)                                                     ||
                                    pf_hidden_for_vendor_msg0                                                  ||
                                    (flt_q_tlp_is_msg     && !((flt_q_type[2:0]==3'b010)));


    assign  flt_q_valid_ca_np_ep       = flt_q_valid_np && (target_ca || !flt_q_rd_size_in_range   || flt_q_atomic_discard_ep || flt_q_def_memwr_discard_ep );
  

                                     


  

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


  assign hdr_len_mismatch             = hdr_dec_flt_np_in.radm_malf_tlp_err_hdr || ord_flt_data_np_in.ord_flt_malformed_tlp_err || malform_ecrc_err_int;
  assign tlp_fmt_type                 = {fmt,hdr_type};
  assign th                           = cfg_tph_enable && hdr_dec_flt_np_in.hdr_dec_flt_hdr[8];
  assign tlp_dw_len                   = { hdr_dec_flt_np_in.hdr_dec_flt_hdr[17:16], hdr_dec_flt_np_in.hdr_dec_flt_hdr[31:24]};
  assign fbe                          = hdr_dw2[27:24];//'d0; 
  assign lbe                          = hdr_dw2[31:28];//'d0; 
  assign int_addr_11_dt_0             = tlp_fmt_type[5] ? {hdr_dec_flt_np_in.hdr_dec_flt_hdr[115:112], 
                                        hdr_dec_flt_np_in.hdr_dec_flt_hdr[127:120]}
                                        : {hdr_dec_flt_np_in.hdr_dec_flt_hdr[83:80], hdr_dec_flt_np_in.hdr_dec_flt_hdr[95:88]};
  assign addr_11_dt_0                 =  {int_addr_11_dt_0[11:2],2'b00};

  logic [NW-1:0] l_tmp_dwcnt;
  logic [NW-1:0] tmp_dwcnt;
  logic [10:0]   prev_pyld_dwcnt;
  always_comb  begin : count_dwen
    integer i;
    l_tmp_dwcnt = 0;
    for(i = 0; i < NW; i = i + 1) begin
      if(ord_flt_data_np_in.ord_flt_dwen[i]) begin
      l_tmp_dwcnt = i;
      end
    end
    if(|ord_flt_data_np_in.ord_flt_dwen) begin
    l_tmp_dwcnt = l_tmp_dwcnt + 1;
    end
  end
  assign tmp_dwcnt = l_tmp_dwcnt;

  always_ff @(posedge core_clk or negedge core_rst_n)
  begin
    if (!core_rst_n)
      prev_pyld_dwcnt   <= #TP 0;
    else if (ord_flt_data_np_in.ord_flt_eot) 
      prev_pyld_dwcnt   <= #TP 0;
    else
      prev_pyld_dwcnt   <= #TP pyld_dwcnt;
  end

// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: This logic is designed to be modulo. pyld_dwcnt counters are intended to
// wrap without preseveration of carry/borrow
  assign pyld_dwcnt     = (ord_flt_data_np_in.ord_flt_dv) ? prev_pyld_dwcnt + tmp_dwcnt :  prev_pyld_dwcnt;                          
// spyglass enable_block W164a                         

 
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
   
      assign chk_flt_q_prfx   = flt_q_prfx;

  assign  rtlh_extrct_abort             = 1'b0;  

  assign  radm_cfg_o.int_radm_pm_pme        = 1'b0;                         // PME should not be received by endpoint device
  assign  radm_cfg_o.radm_vendor_msg        ='d0;
  assign  radm_cfg_o.radm_vendor_msg_type   ='d0;
  assign  rtlh_radm_parerr                  = 1'b0;                         // PME should not be received by endpoint device
  assign  radm_cfg_o.radm_pm_to_ack         = 1'b0; 
  //
  // [ ----------------  sync with rtlh time domain  -----------------------]
  //
  // aux logic to indicate a protection error has been detected at the output of the delay module
  // if the delay is 0 then there is no check and hence no error
   

  assign flt_q_data_o_np.flt_q_parerr = int_flt_q_parerr | l_flt_q_header_d_prot_err;

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
                
                .valid_in (hdr_dec_flt_np_in.hdr_dec_flt_hv         ),
                .din      (hdr_dec_flt_np_in.hdr_dec_flt_hdr[HW_NFT-1:0]),
                .din_prot (hdr_dec_flt_np_in.hdr_dec_flt_hdr[HW_NFT+HW_NFT_PAR-1:HW_NFT]),
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

  assign chk_prfxHdr_flt_hdr_np   = hdr_dec_flt_np_in.hdr_dec_flt_hdr;
  assign  hdr_dw1                   = chk_prfxHdr_flt_hdr_np[31:0];
  assign  hdr_dw2                   = chk_prfxHdr_flt_hdr_np[63:32];
  assign  hdr_dw3                   = chk_prfxHdr_flt_hdr_np[95:64];
  assign  hdr_dw4                   = chk_prfxHdr_flt_hdr_np[127:96];
  
  assign  hdr_type                  = hdr_dw1[4:0];
  assign  fmt                       = hdr_dw1[6:5];
  assign  fmt2                      = hdr_dw1[7];
  assign  tlpmsg                    = hdr_dw1[6:3];
    assign  attr                    = {hdr_dw1[10],hdr_dw1[21:20]};
  assign  tlp_w_pyld                = hdr_dw1[6]; // Supported PCIe format only


  //assign  tlp_type [NP_TYPE]        = rtlh_mem_req | rtlh_io_req | rtlh_cfg_req;
  logic np_type_in;
  assign np_type_in                 =  rtlh_mem_req | rtlh_io_req | rtlh_cfg_req | fm_np_rsvd[1];
  assign tlp_type                   =  ({1'b0,np_type_in,1'b0});
  assign rtlh_mem_req               = pcie_format && (                                      {fmt,hdr_type} == `DMWR32       || {fmt,hdr_type}  == `DMWR64       ||
                                      {fmt,hdr_type} == `MRD32        || {fmt,hdr_type}  == `MRD64        ||
                                      {fmt,hdr_type} == `MRDLK32      || {fmt,hdr_type}  == `MRDLK64      ||
                                      {fmt,hdr_type} == `FETCHADD32   || {fmt, hdr_type} == `FETCHADD64   ||
                                      {fmt,hdr_type} == `SWAP32       || {fmt, hdr_type} == `SWAP64       ||
                                      {fmt,hdr_type} == `CAS32        || {fmt, hdr_type} == `CAS64 );
              
              
  assign rtlh_io_req                = pcie_format && 
                                      ({fmt,hdr_type} == `IOWR        || {fmt,hdr_type}  == `IORD);
  assign rtlh_cfg_req               = pcie_format &&
                                      ({fmt,hdr_type} == `CFGRD0      || {fmt,hdr_type}  == `CFGRD1       ||
                                      {fmt,hdr_type}  == `CFGWR0      || {fmt,hdr_type}  == `CFGWR1);
              
  assign rtlh_cfg_func_num          = hdr_dw3[(PF_WD-1)+8:8];


    assign  pcie_valid_tc           = 1'b1;
    assign  pcie_format             = 1'b1;

  //assign  radm_cfg_o.flt_cdm_addr   = rtlh_radm_ant_addr;
  //assign  flt_cdm_addr_np           = rtlh_radm_ant_addr;
    assign obff_code                = hdr_dw4[27:24];
    assign  ats                     = hdr_dw1[19:18];
  assign  dw_len                    = {hdr_dw1[17:16], hdr_dw1[31:24]};   // Supported PCIe format only
  assign  radm_cfg_o.tlp_poisoned   = hdr_dw1[22] & pcie_format;
  assign  td                        = hdr_dw1[23];
  assign  tc                        = hdr_dw1[14:12];
  
  assign  first_be                  = hdr_dw2[27:24];
  assign  last_be                   = hdr_dw2[31:28];
  assign  dwlenEq1                  = (dw_len[0] & (!(|dw_len[9:1])));    // dw_len == 10'b01
  assign  radm_cfg_o.flt_dwlenEq0   = !(|dw_len);                         // dw_len == 10'b0

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
      //l_flt_q_tlp_type[NP_TYPE] <= #TP tlp_type [NP_TYPE];
      l_flt_q_tlp_type <= #TP tlp_type;
    end
  end

  // [ ----------------  sync with q time domain  -----------------------]
  //
    assign  flt_q_attr              = {flt_q_hdr_dw1[10],flt_q_hdr_dw1[21:20]};
  assign  flt_q_tc                  = flt_q_hdr_dw1[14:12];
    assign  flt_q_TAG               = flit_mode ? flt_q_14Bit_tag  : {4'h0,flt_q_hdr_dw1[15], flt_q_hdr_dw1[11], flt_q_hdr_dw2[23:16]};//14'd0; //for ms need to consider
  assign  flt_q_REQID               =  {flt_q_hdr_dw2[7:0],flt_q_hdr_dw2[15:8]};
  assign  flt_q_dw_len              = {flt_q_hdr_dw1[17:16], flt_q_hdr_dw1[31:24]};
  assign  flt_q_type                = flt_q_hdr_dw1[4:0];
  assign  flt_q_fmt                 = flt_q_hdr_dw1[6:5];
  assign  flt_q_fmt2                = flt_q_hdr_dw1[7]; // second [2] bit of FMT field used to detect reserved TLP in FLIT mode 
  assign  flt_q_tlpmsg              = flt_q_hdr_dw1[6:3];
  assign  flt_q_tlp_is_msg          = 1'b0;

  assign  flt_q_iord_req            = ( {flt_q_fmt, flt_q_type} == `IORD) && (flt_q_dw_len == 10'h1) && flt_q_pcie_format;  // check also that length field = 1
  assign  flt_q_iowr_req            = ( {flt_q_fmt, flt_q_type} == `IOWR) && (flt_q_dw_len == 10'h1) && flt_q_pcie_format;
  assign  flt_q_locked_rd           = (({flt_q_fmt, flt_q_type} == `MRDLK32)      || ({flt_q_fmt, flt_q_type} == `MRDLK64)) && flt_q_pcie_format;
  assign  flt_q_memrd_req           = (({flt_q_fmt, flt_q_type} == `MRD32)        || 
                                      ({flt_q_fmt, flt_q_type} == `MRD64  )) && flt_q_pcie_format;
    assign  flt_q_def_memwr_req     = (({flt_q_fmt, flt_q_type} == `DMWR32)       || ({flt_q_fmt, flt_q_type} == `DMWR64 )) && flt_q_pcie_format;
  assign  flt_q_cfg0rd_req          = ( {flt_q_fmt, flt_q_type} == `CFGRD0) && (flt_q_dw_len == 10'h1) && flt_q_pcie_format;
  assign  flt_q_cfg0wr_req          = ( {flt_q_fmt, flt_q_type} == `CFGWR0) && (flt_q_dw_len == 10'h1) && flt_q_pcie_format;
  assign  flt_q_cfg1rd_req          = ( {flt_q_fmt, flt_q_type} == `CFGRD1) && (flt_q_dw_len == 10'h1) && flt_q_pcie_format;
  assign  flt_q_cfg1wr_req          = ( {flt_q_fmt, flt_q_type} == `CFGWR1) && (flt_q_dw_len == 10'h1) && flt_q_pcie_format;
  assign  flt_q_cfg_req             = (flt_q_cfg0rd_req      || flt_q_cfg0wr_req  || flt_q_cfg1rd_req || flt_q_cfg1wr_req);
  assign  flt_q_cfg1_req            = (flt_q_cfg1rd_req      || flt_q_cfg1wr_req);
  assign  flt_q_mem_req             = (flt_q_locked_rd       || flt_q_memrd_req   || flt_q_def_memwr_req || flt_q_atomic_op);
  
  assign  flt_q_invalid_tlp         = !flt_q_iord_req & !flt_q_iowr_req & !flt_q_locked_rd & !flt_q_memrd_req
                                      & !flt_q_def_memwr_req & !flt_q_cfg0rd_req & !flt_q_cfg0wr_req & !flt_q_tlp_is_msg
                                      & !flt_q_cfg1rd_req & !flt_q_cfg1wr_req 
                                      & !flt_q_atomic_op & !fm_np_rsvd_r[1];
      
      assign  flt_q_invalid_prfx    = flt_q_prfx_type_error | flt_q_prfx_end_end_max_err | flt_q_prfx_local_after_end_err; // Invalid prefix when prefix rules not met.

  // `ifdef CX_CCIX_INTERFACE_ENABLE
  // assign  flt_q_ccix_fmt_err      = flt_q_ccix_valid_tc
  //                                && ( (flt_q_hdr_dw0_rsvd[0]==1'b1)
  //   `ifdef CX_TLP_PREFIX_ENABLE
  //                                  || (chk_flt_q_prfx[PRFX_W_PAR-PRFX_PROT_WD-1:0]>{PRFX_W_PAR-PRFX_PROT_WD{1'b0}}) // If CCIX TLPs with prefix are received
  //   `endif // CX_TLP_PREFIX_ENABLE
  //                                   ) ;
  // `endif // CX_CCIX_INTERFACE_ENABLE

  assign  flt_q_np_rd               = ( flt_q_iord_req || flt_q_cfg0rd_req || flt_q_cfg1rd_req || flt_q_memrd_req || flt_q_locked_rd || flt_q_atomic_op);


    assign  flt_q_td_hdr_log        = flt_q_hdr_dw1[23]; // Assigned without masking
    assign  flt_q_td                = 
                                      radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_UNMASK_TD] ? flt_q_hdr_dw1[23] : 1'b0;
  assign  flt_q_poisoned            = flt_q_hdr_dw1[22];
  assign  flt_q_poisoned_err        = (flt_q_poisoned  && flt_q_pcie_format) || l_flt_q_tlp_poisoned; // Poisoned error detection with EP bit set in header or Flit marker poisoned error received in Flit mode.
  assign  flt_q_addr64              = flt_q_hdr_dw1[5] && flt_q_pcie_format;
  assign  flt_q_first_be            = flt_q_hdr_dw2[27:24];
  assign  flt_q_last_be             = flt_q_hdr_dw2[31:28];
  assign  flt_q_msg_code            = flt_q_hdr_dw2[31:24];                         // for message transactions only
  assign  flt_q_bus_num             = flt_q_hdr_dw3[7:0];                           // for cfg transaction only

  assign  flt_q_cfg_func_num          = flt_q_hdr_dw3[(PF_WD-1)+8:8];                 // for cfg transaction only
  assign  flt_q_ext_reg_num           = flt_q_hdr_dw3[19:16];                         // for cfg transaction only
  assign  flt_q_reg_num               = flt_q_hdr_dw3[31:26];                         // for cfg transaction only
  assign  flt_q_rcvd_cpl_status       = flt_q_hdr_dw2[23:21];                         // for cpl receptions only
      
  assign  flt_q_status_sc             = (flt_q_rcvd_cpl_status == `SU_CPL_STATUS);    // Successful  Completion
  assign  flt_q_status_ca             = (flt_q_rcvd_cpl_status == `CA_CPL_STATUS);    // Completion  Abort
  assign  flt_q_status_crs            = (flt_q_rcvd_cpl_status == `CRS_CPL_STATUS);   // Request Retry Status
  assign  flt_q_status_ur             = !(flt_q_status_sc || flt_q_status_ca || flt_q_status_crs); 
  // 2.3.2 Completions with a Reserved Completion
  // Status value are treated as if the Completion
  // Status was Unsupported Request (UR)
  assign  flt_q_reserved_status       = !(flt_q_status_sc  || flt_q_rcvd_cpl_status == `UR_CPL_STATUS  || flt_q_status_ca  || flt_q_status_crs);
  assign  flt_q_cpl_reqid             = {flt_q_hdr_dw3[7:0], flt_q_hdr_dw3[15:8]};
  assign  flt_q_cpl_bcm               = flt_q_hdr_dw2[20];                            // for cpl receptions only
    
  assign  flt_q_addr_byte7            = (flt_q_addr64) ? flt_q_hdr_dw3[7:0]   : 8'h00;
  assign  flt_q_addr_byte6            = (flt_q_addr64) ? flt_q_hdr_dw3[15:8]  : 8'h00;
  assign  flt_q_addr_byte5            = (flt_q_addr64) ? flt_q_hdr_dw3[23:16] : 8'h00;
  assign  flt_q_addr_byte4            = (flt_q_addr64) ? flt_q_hdr_dw3[31:24] : 8'h00;
  assign  flt_q_addr_byte3            = (flt_q_addr64) ? flt_q_hdr_dw4[7:0]   : flt_q_hdr_dw3[7:0];
  assign  flt_q_addr_byte2            = (flt_q_addr64) ? flt_q_hdr_dw4[15:8]  : flt_q_hdr_dw3[15:8];
  assign  flt_q_addr_byte1            = (flt_q_addr64) ? flt_q_hdr_dw4[23:16] : flt_q_hdr_dw3[23:16];
  assign  flt_q_addr_byte0            = (flt_q_addr64) ? flt_q_hdr_dw4[31:24] : flt_q_hdr_dw3[31:24];

  assign extract_addr = {flt_q_addr_byte7, flt_q_addr_byte6, flt_q_addr_byte5, flt_q_addr_byte4,
                         flt_q_addr_byte3, flt_q_addr_byte2, flt_q_addr_byte1, flt_q_addr_byte0};
  assign  flt_q_lower_addr        = flt_q_memrd_req ? {flt_q_hdr_dw3[30:26], flt_q_byte_addr_in(flt_q_first_be)} : 7'h00;

     assign flt_q_nw_in     = flit_mode ? flt_q_hdr_dec_nw : flt_q_addr[0];
     assign flt_q_cxlsrc_in = flit_mode ? flt_q_hdr_dec_cxlsrc : flt_q_addr[3];


    assign  flt_q_ats               = flt_q_hdr_dw1[19:18];
    assign  flt_q_nw                = flt_q_nw_in;
    assign  flt_q_cxlsrc            = flt_q_cxlsrc_in;
  assign flt_q_th                   = flt_q_hdr_dw1[8];
 // assign flt_q_ph                   = (flt_q_memwr_req || flt_q_memrd_req || flt_q_atomic_op) ? flt_q_addr[1:0] :
 //                                     2'b0;
 // assign flt_q_st                   = flt_q_memwr_req ? flt_q_TAG[7:0] :
 //                                     (flt_q_memrd_req || flt_q_atomic_op) ? {flt_q_last_be, flt_q_first_be} :
 //                                     8'b0;
  assign flt_q_ph_int               = (flit_mode) ? flt_q_hdr_dec_ph : flt_q_addr[1:0];
  assign flt_q_ph                   = (flt_q_memrd_req || flt_q_atomic_op) ? flt_q_ph_int : 2'b0;

    assign flt_q_st                 = (flt_q_memrd_req || flt_q_atomic_op) ? (flit_mode ? flt_q_ohc_b_st_lb :  {flt_q_last_be, flt_q_first_be}) : 8'h00;



    assign flt_q_pcie_valid_tc      = 1'b1;
    assign flt_q_pcie_format        = 1'b1;

  assign flt_q_mask_wreq_poisoned_reporting     = ( radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_UR_POIS] 
                                                  & (int_flt_q_destination == `FLT_DESTINATION_TRGT1));
  assign flt_q_mask_cpl_poisoned_reporting      = radm_cfg_i.cfg_filter_rule_mask  [`CX_FLT_MASK_POIS_ERROR_REPORTING];


  // -----------------------------------------------------------------------------
  // TLP destination calculation
  // -----------------------------------------------------------------------------
  always_comb begin: DECODE_BYTE_ADDR
    casez(flt_q_first_be)
      4'b0000:     flt_q_byte_addr = 2'b00;
      4'b???1:     flt_q_byte_addr = 2'b00;
      4'b??10:     flt_q_byte_addr = 2'b01;
      4'b?100:     flt_q_byte_addr = 2'b10;
      4'b1000:     flt_q_byte_addr = 2'b11;
    endcase // casez(flt_q_first_be)
  end

    assign  flt_q_mem_req_in_range  = (|(cfg_bar_match_reg & (~cfg_bar_is_io_reg))) & flt_q_mem_req;
  assign  flt_q_rom_req_in_range        = (|cfg_rom_match_reg) & flt_q_mem_req;


  // Extract info from radm_cfg_tlp_i.cfg_bar_match and derive the bar number
  // (in_membar_range), the function number (raw_mem_func_num)
  // and the corresponding *bar_is_io vector.

  always_comb 
  begin : GET_MEM_BAR_PF_PROC
    in_membar_range_unreg = `RADM_OUTSIDE_MEMBAR;
    raw_mem_func_num      = 0;
    for (int idx=0; idx<NF; idx=idx+1)
    begin
      if (radm_cfg_tlp_i.cfg_rom_match[idx])
        raw_mem_func_num        = idx;
      else
        if ((|radm_cfg_tlp_i.cfg_bar_match[(idx*6) +: 6]))
        begin
          raw_mem_func_num      = idx;
          in_membar_range_unreg = get_bar_num(radm_cfg_tlp_i.cfg_bar_match[(idx*6) +: 6]);
        end
    end
  end

  always_comb 
  begin : GET_IO_BAR_PF_PROC

    in_iobar_range_unreg  = `RADM_OUTSIDE_MEMBAR;
    raw_io_func_num       = 0;
    shft_bar_is_io_unreg  = 0;

    for (int idx=0; idx<NF; idx=idx+1)
    begin
      if (|(radm_cfg_tlp_i.cfg_bar_match[(idx*6) +: 6] & radm_cfg_i.cfg_bar_is_io[idx*6 +: 6]))
        begin
          raw_io_func_num           = idx;
          in_iobar_range_unreg      = get_bar_num((radm_cfg_tlp_i.cfg_bar_match[idx*6 +: 6] & radm_cfg_i.cfg_bar_is_io[idx*6 +: 6]));
          shft_bar_is_io_unreg[5:0] = radm_cfg_i.cfg_bar_is_io[idx*6 +: 6];
        end
    end
  end



  assign mem_req       = PIPE_VF_INDEX == 1 ? rtlh_mem_req : flt_q_mem_req ;
  assign io_req        = PIPE_VF_INDEX == 1 ? rtlh_io_req  : (flt_q_iord_req | flt_q_iowr_req);
  assign cfg_req       = PIPE_VF_INDEX == 1 ? rtlh_cfg_req : flt_q_cfg_req ;


  assign pfvf_func_num =  io_req  ? raw_io_func_num  :
                          mem_req ? raw_mem_func_num : 0;                            

  // derive the signals used for error log
  assign  flt_q_valid_ur_xtrash_wo_poisn   = (flt_q_ur_np_wo_poisn ) && (flt_q_destination == `FLT_DESTINATION_TRASH);
  assign  flt_q_valid_ur_xtrgt0_wo_poisn   = (flt_q_ur_np_wo_poisn) && (flt_q_destination == `FLT_DESTINATION_TRGT0);
  assign  flt_q_valid_ur_xtrgt1_wo_poisn   = (flt_q_ur_np_wo_poisn ) && (flt_q_destination == `FLT_DESTINATION_TRGT1) && !(radm_cfg_i.ur_ca_mask_4_trgt1); // this `define will mask out the report of UR or CA
  assign  flt_q_valid_ur_xtrash            = (flt_q_valid_ur_np   && (flt_q_destination == `FLT_DESTINATION_TRASH));
  assign  flt_q_valid_ur_xtrgt0            = (flt_q_valid_ur_np   && (flt_q_destination == `FLT_DESTINATION_TRGT0));
  assign  flt_q_valid_ur_xtrgt1            = (flt_q_valid_ur_np   && (flt_q_destination == `FLT_DESTINATION_TRGT1) && !(radm_cfg_i.ur_ca_mask_4_trgt1)); // this `define will mask out the report of UR or CA
  assign  flt_q_valid_ca_err               = flt_q_valid_ca_np ;


  // Per PCIe Base Spec: TLP Prefix Logging 6.2.4.4  -  "A Function that receives a TLP containing more End-End TLP Prefixes than are indicated by
  // the Function's Max End-End TLP Prefixes field must handle the TLP as an error and store the first 
  // overflow End-End TLP Prefix in the 1st DW of the Header Log register with the remainder of the Header Log register being undefined. "
    assign  l_radm_hdr_log                 =  |ovrflw_end_end_prfx ? {flt_q_hdr_dw3,flt_q_hdr_dw2,flt_q_hdr_dw1,ovrflw_end_end_prfx} : {flt_q_hdr_dw4,flt_q_hdr_dw3,flt_q_hdr_dw2,flt_q_hdr_dw1};


    // Identify PASID prefix received
    // ------------------------------

    // Type field is in bits 4:0 of prefix.
    always_comb begin : extract_prefix_type
      for(int i = 0; i < NPRFX; i = i + 1) begin           // Repeat for every allocated prefix slot
        flt_q_prfx_type[(5*i) +: 5]  =  chk_flt_q_prfx[(32*i) +: 5];
      end
    end

    // Determine if a prefix type is reserved. Non-reserved includes ExtTPH, PASID, Vendor Defined and MRIOV.

    always_comb  begin : detect_prefix_type
      for(int i = 0; i < NPRFX; i = i + 1) begin
        casez ({flt_q_prfx_type[5*i +: 5],flit_mode})
          6'b00000?,6'b01110?, 6'b01111?, 6'b10000?, 6'b10001?, 6'b11110?, 6'b11111? : prfx_type_rsrvd[i] = 0;
          //6'b011011,6'b00???1,6'b010??1:prfx_type_rsrvd[i] = 0;
          6'b011011:prfx_type_rsrvd[i] = 0;
          default : prfx_type_rsrvd[i] = 1;  // all other values => reserved type
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
        for(int j = 0; j < NPRFX; j = j + 1) begin
          prfx_type_msb[j] = chk_flt_q_prfx[32*j+4];
          prfx_fmt_msb[j]  = chk_flt_q_prfx[32*j+7];
          case (prfx_type_msb[j])
            1'b1     : prfx_is_end[j] = 1;    // End-End prefix is present.
            default  : prfx_is_end[j] = 0;
          endcase
          case ({prfx_fmt_msb[j], prfx_type_msb[j]})
            2'b10    : prfx_is_local[j] = 1;  // Local prefix is present.
            default  : prfx_is_local[j] = 0;
          endcase
        end
      end

      always_comb  begin : end_end_type_count
        end_end_cnt = 0;
        for(int n = 0; n < NPRFX; n = n + 1) begin
          end_end_cnt = prfx_is_end[n] ? end_end_cnt + 1 : end_end_cnt;
        end
      end

      // Report error if more than 4 End-End TLP Prefixes received in one TLP. Check
      // is performed based on the function number.

      always_comb  begin : end_2_end_max_prfxs
        end2end_max_pf = `CX_MAX_END2END_TLP_PRFXS; // @CX_NPRFX < 4 ? @CX_NPRFX : 0
        for(int i = 0; i < NF; i = i + 1) begin
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

      always_comb  begin : detect_local_after_end_end_prefix
        flt_q_prfx_local_after_end_err = 1'b0;
        for(int k = 1; k < NPRFX; k = k + 1) begin
          if (|prfx_fmt_msb && prfx_is_local[k] && prfx_is_end[k-1]) begin
            flt_q_prfx_local_after_end_err = 1'b1;
          end
        end
      end

    


    //------------------------------------------------------------------------------------------------------------------------
    //  TLP Prefix log
    //------------------------------------------------------------------------------------------------------------------------


    // First, convert TLP Prefix bus from Big Endian to Little Endian before making
    // available for TLP Prefix Log (when required).
    // Width of flt_q_prfx depends on CX_NPRFX parameter, so append zeros as required.
    always_comb  begin : pre_prefix_log
      pre_tlp_prfx_log = 0;
      //pre_tlp_prfx_log[0 +: 32*NPRFX] = chk_flt_q_prfx[0 +: 32*NPRFX];
      pre_tlp_prfx_log[32*NPRFX-1:0] = chk_flt_q_prfx[32*NPRFX-1:0];
    end

    // TLP Prefix Log only records End-End TLP Prefixes. Hence, find first
    // End-End and then capture the the next 4 DWs (to allow for one overflow
    // End-End). Assumes that only End-End, if any, can follow first End-End. If no 
    // prefix follows first or subsequent prefixes, then zeros are recorded.
    // Bit 4 of first DW is TYPE[4], and so on.
    assign  e2e_prfx_log       = e2e_prfx_log_in(pre_tlp_prfx_log);

    // A maximum of 4 End-End prefixes can be stored in the Prefix Log.
    assign l_radm_tlp_prfx_log = little_end_prfx(e2e_prfx_log);

      assign ovrflw_end_end_prfx = end2end_max == 5'h1 ? e2e_prfx_log[63:32]   :         // overflow is 2nd end to end prefix
                                   end2end_max == 5'h2 ? e2e_prfx_log[95:64]   :         // overflow is 3rd end to end prefix
                                   end2end_max == 5'h3 ? e2e_prfx_log[127:96]  :         // overflow is 4th end to end prefix
                                   end2end_max == 5'h4 ? e2e_prfx_log[159:128] :         // overflow is 5th end to end prefix
                                   32'h0;


  assign {tmp_mlf_err_ptr, tmp_mlf_err} = l_flt_q_dllp_abort       ? {`MFPTR_NO_ERR       , 1'b0} : 
                                          flt_q_rtlh_abort         ? {flt_q_rtlh_abort_ptr, 1'b1} :
                                          flt_q_invalid_tlp        ? {`MFPTR_TLP_TYP      , 1'b1} :
                                            flt_q_invalid_prfx     ? {`MFPTR_PFX          , 1'b1} :
                                                                     {`MFPTR_NO_ERR       , 1'b0} ;

  // Output registering (optional)


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

  assign error_log_pipe_en = (pipe_error_log_en | pipe_error_log_en_reg); //  to flush the ERROR pipe and set error only for a cycle.


  delay_n_w_enable
  
  #(  
      .N  (ERROR_LOG_PIPE_DELAY     ), 
      .WD (ERROR_LOG_PIPEWIDTH      )
  ) u_error_log_pipeline  (   
      .clk        (core_clk         ),
      .rst_n      (core_rst_n       ),
      .clear      (1'b0             ),
      .en         (error_log_pipe_en),
      .din        ({l_radm_hdr_log
                     ,l_radm_tlp_prfx_log
                  ,
                  l_set_radm_rcvd_req_ca,
                  l_set_radm_rcvd_req_ur, 
                  l_set_radm_ecrc_err,
                  l_set_radm_mlf_tlp_err, l_set_radm_hdr_log_valid,
                  l_set_radm_rcvd_wreq_poisoned,
                  flt_q_func_num
                  
                      ,l_set_radm_rcvd_acs_err

                    ,l_set_radm_mlf_tlp_err_ptr
                    ,l_set_outrange_req_ur
                  }),
      .dout       ({  radm_cfg_o.radm_hdr_log
                        ,radm_cfg_o.radm_tlp_prfx_log
                      ,
                      set_radm_rcvd_req_ca, 
                      set_radm_rcvd_req_ur, 
                      set_radm_ecrc_err,
                      set_radm_mlf_tlp_err, set_radm_hdr_log_valid,
                      set_radm_rcvd_wreq_poisoned,
                      flt_q_func_num_d

                           ,set_radm_rcvd_acs_err

                          ,set_radm_mlf_tlp_err_ptr
                        ,
                        set_outrange_req_ur
                  })
  );

  
    assign gen_flt_q_header_at.flt_q_hv  = 1'b0;

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
                .PROT_WD                 (FLT_NP_HDR_PROT_WIDTH),
                .PARITY_MODE             (PARITY_MODE),        // cc
                .PROT_CORRECT_EN         (PROT_CORRECT_EN),    // cc
                .TOTAL_WIDTH             (FLT_NP_HDR_WIDTH),             
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
                .din      ({flt_q_header_at[FLT_NP_HDR_WIDTH:3], 2'b00}),     // flt_p_destination is taken 0 for parity calculation to avoid any issue at the trgt1 checker.
                .din_prot ('0                 ),
                .halt_out (                   ),
                
                .valid_out(                   ),
                .dout     (                   ),
                .dout_prot(gen_flt_q_header_at.flt_hdr_prot),
                .halt_in  (1'b0               ),
                .ras_dp_err_inband_kbd_in(1'b0),
                .ras_dp_err_inband_kbd_out(   ),
                .ras_dp_err_log  ()
                ,
                .ras_dp_err_inj  (ras_dp_err_inj)
                );
      assign gen_flt_q_header_at[FLT_NP_HDR_WIDTH:1] = flt_q_header_at[FLT_NP_HDR_WIDTH:1];
    
    assign flt_q_addr_int   = extract_addr;

    assign translate_enable = ((chk_l_flt_q_header_d[`FLT_Q_DESTINATION_RANGE] == `FLT_DESTINATION_TRGT1) && !flt_q_data_o_np.flt_q_tlp_abort && !flt_q_data_o_np.flt_q_ecrc_err &&
                               (flt_q_iord_req_d ||  flt_q_iowr_req_d ||  flt_q_locked_rd_d || flt_q_memrd_req_d || flt_q_def_memwr_req_d || flt_q_atomic_op_d
                                || flt_q_cfg0_req_d || flt_q_cfg1_req_d 
                              ));

      // ATU Header valid and EoT pipeline 
      always_ff @(posedge core_clk or negedge core_rst_n)
      begin  
        if (!core_rst_n) begin
          radm_flt_atu_hv  <= #TP 0;
          radm_flt_atu_eot <= #TP 0;
        end else begin
          radm_flt_atu_hv  <= #TP hdr_dec_flt_np_in.hdr_dec_flt_hv;
          radm_flt_atu_eot <= #TP (hdr_dec_flt_np_in.hdr_dec_flt_hv | ord_flt_data_np_in.ord_flt_dv) && ord_flt_data_np_in.ord_flt_eot;
        end
      end

    assign  radm_flt_atu_out.r_rombar_out          = flt_q_rom_req_in_range ;
    assign  radm_flt_atu_out.r_addr_out            = flt_q_addr_tph[63:0] ;
    assign  radm_flt_atu_out.r_func_out            = device_is_ep ? {{(8-PF_WD){1'b0}}, raw_flt_q_func_num} : {{(8-PF_WD){1'b0}}, flt_q_func_num};
    assign  radm_flt_atu_out.r_type_out            = flt_q_type[4:0] ;
    assign  radm_flt_atu_out.r_bar_out             = flt_q_in_membar_range[2:0];
    assign  radm_flt_atu_out.r_tc_out              = flt_q_tc;
    assign  radm_flt_atu_out.r_td_out              = flt_q_hdr_dw1[23];
    assign  radm_flt_atu_out.r_attr_out            = flt_q_attr;
    assign  radm_flt_atu_out.r_at_out              = flt_q_ats;
    assign    radm_flt_atu_out.r_msgcode_out       = flt_q_msg_code;
    assign  radm_flt_atu_out.r_th_out              = flt_q_th;
    assign  radm_flt_atu_out.r_ph_out              = flt_q_ph;
    assign  radm_flt_atu_out.r_st_out              = flt_q_st;
    assign  radm_flt_atu_out.r_dw_len_out          = flt_q_dw_len;

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
    

    assign rtranslated_tlp_addr_tph = chk_l_flt_q_header_d.flt_q_th ? {rtranslated_tlp_addr[64-1:2],2'b00} : 
 (flit_mode && (|chk_l_flt_q_header_d.flt_q_ats)) ? {rtranslated_tlp_addr[64-1:2],2'b00} :
                                      (chk_l_flt_q_header_d.flt_q_ats == 2'b01) ? {rtranslated_tlp_addr[64-1:1],1'b0} :
                                      rtranslated_tlp_addr;


    assign flt_q_type_d            = chk_l_flt_q_header_d[`FLT_Q_TYPE_FO +: 5];

    assign  rtranslated_tlp_hdr_fmt = (flt_q_type_d[4:1] == 4'b0000) ?  ~(rtranslated_tlp_addr[63:32] == 32'b0) : //mem
                                      (flt_q_type_d[4:2] == 3'b011 ) ?  ~(rtranslated_tlp_addr[63:32] == 32'b0) : //Atomic
                                      (flt_q_type_d[4:2] == 3'b110 ) ?  ~(rtranslated_tlp_addr[63:32] == 32'b0) : //Def MemWr
                                      (flt_q_type_d[4:1] == 4'b0010) ?  1'b0                                    : //cfg 0 and 1
                                      (flt_q_type_d == 5'b00010)     ?  1'b0                                    : // I/O
                                      chk_l_flt_q_header_d[`FLT_Q_FMT_FO];


logic [4:0] rtranslated_tlp_type;

      assign rtranslated_tlp_type   = flt_q_type_d[4:0];

    always_comb begin
      flt_q_header_at                              = l_flt_q_header_d;
      flt_q_header_at.flt_q_hdr.flt_q_addr         = rtranslated_tlp_addr_tph[`FLT_Q_ADDR_WIDTH-1:0];
      flt_q_header_at.flt_q_hdr.flt_q_cpl_status   = (translate_enable && rtranslated_err_in_d[0]) ? `UR_CPL_STATUS : 
                                                     (translate_enable && rtranslated_err_in_d[1]) ? `CA_CPL_STATUS :  chk_l_flt_q_header_d.flt_q_cpl_status;
      flt_destination_at                           = (translate_enable && (|rtranslated_err_in_d)) ? l_flt_q_tlp_type_d[NP_TYPE] ? `FLT_DESTINATION_TRGT0 :
                                                     `FLT_DESTINATION_TRASH : chk_l_flt_q_header_d.flt_q_destination; // always send to target0
      flt_q_header_at.flt_q_hdr.flt_q_destination  = hdr_destination'(flt_destination_at); 
      flt_q_header_at_fmt                          = {chk_l_flt_q_header_d[3],rtranslated_tlp_hdr_fmt};
      flt_q_header_at.flt_q_hdr.flt_q_fmt          = hdr_fmt'(flt_q_header_at_fmt);
      flt_q_header_at.flt_q_hdr.flt_q_type         = rtranslated_tlp_type;
          // upper byte valid and upper bytes are not defined for NP TLPs
          // flt_q_header_at.radm_atu_uppr_bytes_valid = radm_atu_uppr_bytes_valid;
          flt_q_header_at.radm_atu_sloc_region    = radm_atu_sloc_region;
          flt_q_header_at.radm_atu_sloc_match     = radm_atu_sloc_match;
          flt_q_header_at.radm_atu_cbuf_err       = radm_atu_cbuf_err;
    end

     //assign flt_q_hdr_o_np  = (translate_enable) ? gen_flt_q_header_at : chk_l_flt_q_header_d;


 always_comb begin

           flt_q_hdr_o_np[1 +: ($bits(flt_np_hdr_o_s)-1)]  =  l_flt_q_header_d[1 +: ($bits(flt_np_hdr_o_s)-1)];

        if (radm_hdr_log_valid) begin
          flt_q_hdr_o_np.flt_q_hdr.flt_q_addr              =  flt_q_addr_hdr_log1[FLT_Q_ADDR_WIDTH-1:0] ;
        end else if (translate_enable) begin
          flt_q_hdr_o_np[1 +: ($bits(flt_np_hdr_o_s)-1)]   =  gen_flt_q_header_at[1 +: ($bits(flt_np_hdr_o_s)-1)];
        end else begin
          flt_q_hdr_o_np[1 +: ($bits(flt_np_hdr_o_s)-1)]   =  l_flt_q_header_d[1 +: ($bits(flt_np_hdr_o_s)-1)];
        end
 end


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
        if (!core_rst_n) begin
          for(int i = 0; i < FLT_Q_PIPE_DELAY; i = i + 1) begin 
            l_flt_q_hv_reg[i]    <= #TP 0;
            l_flt_q_dv_reg[i]    <= #TP 0;
            l_flt_q_eot_reg[i]   <= #TP 0;
                cdm_core_in_dpc_reg[i] <= #TP 0;
          end
        end else begin
          for(int i = 0; i < FLT_Q_PIPE_DELAY; i = i + 1) begin
             if(i==0) begin
               l_flt_q_hv_reg[i]    <= #TP l_flt_q_hv_int ;
               l_flt_q_dv_reg[i]    <= #TP l_flt_q_dv_int ;
               l_flt_q_eot_reg[i]   <= #TP l_flt_q_eot_int ;
               cdm_core_in_dpc_reg[i] <= #TP radm_cfg_i.cdm_core_in_dpc;

             end else begin
               l_flt_q_hv_reg[i]    <= #TP l_flt_q_hv_reg[i-1] ;
               l_flt_q_dv_reg[i]    <= #TP l_flt_q_dv_reg[i-1] ;
               l_flt_q_eot_reg[i]   <= #TP l_flt_q_eot_reg[i-1] ;
               cdm_core_in_dpc_reg[i] <= #TP cdm_core_in_dpc_reg[i-1];
             end
          end // for
        end
      end
      assign  flt_q_hdr_o_np.flt_q_hv   = l_flt_q_hv_reg[FLT_Q_PIPE_DELAY-1] ; // NP SF Update
      assign  flt_q_data_o_np.flt_q_dv  = l_flt_q_dv_reg[FLT_Q_PIPE_DELAY-1];
      assign  flt_q_data_o_np.flt_q_eot = l_flt_q_eot_reg[FLT_Q_PIPE_DELAY-1];

     assign  flt_q_tlp_abort_rc = cdm_core_in_dpc_reg[FLT_Q_PIPE_DELAY-1] ? |l_flt_q_eot_reg[FLT_Q_PIPE_DELAY-1] : int_flt_q_tlp_abort;

    end else begin : gen_flt_q_pipe_delay_eq0
      assign  flt_q_hdr_o_np.flt_q_hv   = l_flt_q_hv ; // NP SF update
      assign  flt_q_data_o_np.flt_q_dv  = l_flt_q_dv;
      assign  flt_q_data_o_np.flt_q_eot = l_flt_q_eot;
      assign  flt_q_tlp_abort_rc = radm_cfg_i.cdm_core_in_dpc ? |l_flt_q_eot : int_flt_q_tlp_abort;
    end
  endgenerate



  delay_n_w_enable
  
  #(
    .N          (FLT_Q_PIPE_DELAY ), 
    .WD         (FLT_Q_PIPEWIDTH  )
  ) u_flt_q_pipeline(
    .clk        (core_clk         ),
    .rst_n      (core_rst_n       ),
    .clear      (1'b0             ),
    .en         (flt_q_pipe_en    ),
    .din        ({
                  l_flt_q_tlp_type,
                  chk_l_flt_q_data,
                  l_flt_q_dllp_abort,
                  l_flt_q_tlp_poisoned,
                  l_flt_q_dwen,
                  1'b0,
                  l_flt_q_parerr,
                  l_flt_q_header,
                  l_flt_q_tlp_abort,
                    flt_q_iord_req,
                    flt_q_iowr_req,
                    flt_q_locked_rd,
                    flt_q_memrd_req,
                      flt_q_def_memwr_req,
                      flt_q_atomic_op,
                      flt_q_cfg0rd_req || flt_q_cfg0wr_req,
                      flt_q_cfg1rd_req || flt_q_cfg1wr_req,
                  radm_hdr_log_err_index_c,
                  radm_hdr_log_vld_all_fn_c,
                  radm_hdr_log_vld_c
                  }),
    .dout       ({
                  l_flt_q_tlp_type_d,
                  flt_q_data_o_np.flt_q_data,
                  flt_q_data_o_np.flt_q_dllp_abort,
                     flt_q_data_o_np.flt_q_tlp_poisoned,
                  flt_q_data_o_np.flt_q_dwen,
                  flt_q_data_o_np.flt_q_ecrc_err,
                  int_flt_q_parerr,
                  l_flt_q_header_d,
                  int_flt_q_tlp_abort,
                    flt_q_iord_req_d,
                    flt_q_iowr_req_d,
                    flt_q_locked_rd_d,
                    flt_q_memrd_req_d,
                      flt_q_def_memwr_req_d,
                    flt_q_atomic_op_d,
                      flt_q_cfg0_req_d,
                      flt_q_cfg1_req_d,
                  flt_q_data_o_np.radm_hdr_log_err_index,
                  flt_q_data_o_np.radm_hdr_log_vld_all_fn,
                  flt_q_data_o_np.radm_hdr_log_vld
                  })

  );



    assign l_flt_q_header_d_prot_err = 1'b0;
    assign chk_l_flt_q_header_d      = l_flt_q_header_d.flt_q_hdr;

  /////////////////////////////////////////////////////////////////////////
  // Error indications for Cdm
  /////////////////////////////////////////////////////////////////////////
                  
  assign  radm_rcvd_wreq_poisoned_int   = route_error_to_func( set_radm_rcvd_wreq_poisoned , flt_q_func_num_d);

  //assign radm_cfg_o.radm_ecrc_err                 = {NF{set_radm_ecrc_err}};
  //assign radm_cfg_o.radm_mlf_tlp_err              = {NF{set_radm_mlf_tlp_err}};
  assign radm_cfg_o.radm_ecrc_err                 = set_radm_ecrc_err;
  assign radm_cfg_o.radm_mlf_tlp_err              = set_radm_mlf_tlp_err;  
    assign radm_cfg_o.radm_mlf_tlp_err_ptr        = set_radm_mlf_tlp_err_ptr;



  always_ff @(posedge core_clk or negedge core_rst_n)
  begin: LATCH_HDR_PROCESS
    if(!core_rst_n)
    begin
      l_flt_q_data            <= #TP 0;
      l_flt_q_dwen            <= #TP 0;
      l_flt_q_ecrc_err        <= #TP 0;
      flt_q_rtlh_abort        <= #TP 0;
      flt_q_rtlh_abort_ptr    <= #TP 0;
      l_flt_q_dllp_abort      <= #TP 0;
      rtlh_dllp_err_d         <= #TP 0;
      ord_flt_p_pkt_num_d     <= #TP 0;
      l_flt_q_tlp_poisoned        <= #TP 1'b0;
      flt_q_valid_atomic_request <= #TP 0;
      flt_q_atomic_op            <= #TP 0;
      flt_q_hdr_dw1              <= #TP 0;
      flt_q_hdr_dw2              <= #TP 0;
      flt_q_hdr_dw3              <= #TP 0;
      flt_q_hdr_dw4              <= #TP 0;
      flt_q_hdr_dec_ph            <= #TP 'd0;
      flt_q_hdr_dec_nw            <= #TP 'd0;
      flt_q_hdr_ohc_err           <= #TP 'd0;
      flt_q_hdr_dec_cxlsrc        <= #TP 'd0;
      flt_q_ohc_b_st_lb       <= #TP 0;
      flt_q_hdr_dec_flt_dest_seg  <= #TP 0;
      flt_q_hdr_dec_flt_reqtr_seg <= #TP 0;
      flt_q_14Bit_tag         <= #TP 0;
      flt_q_cfg_segment_id    <= #TP 0;
      l_flt_q_log_rcvd_flds   <= #TP '0 ;
      flt_q_vc_select         <= #TP 0;
      l_flt_q_parerr          <= #TP 0;
        flt_q_prfx              <= #TP 0;
    end
    else if (latch_hdr_pipe_en)
    begin
      l_flt_q_data            <= #TP ord_flt_data_np_in.ord_flt_data;
      l_flt_q_dwen            <= #TP ord_flt_data_np_in.ord_flt_dwen;
      l_flt_q_dllp_abort      <= #TP ord_flt_data_np_in.ord_flt_dllp_err;
      rtlh_dllp_err_d         <= #TP ord_flt_data_np_in.ord_flt_dllp_err;
      ord_flt_p_pkt_num_d      <= #TP ord_flt_data_np_in.ord_flt_p_pkt_num;
      l_flt_q_tlp_poisoned        <= #TP ord_flt_data_np_in.ord_flt_poisoned;
      {flt_q_rtlh_abort_ptr, flt_q_rtlh_abort} <= #TP ord_flt_data_np_in.ord_flt_dllp_err 
       ? {`MFPTR_NO_ERR, 1'b0} :
      extrct_malfm_tlp_errsts  ? {extrct_malfm_tlp_err_ptr,1'b1} : 
       {`MFPTR_NO_ERR,1'b0} ;                                    
      l_flt_q_ecrc_err          <= #TP radm_ecrc_err_int;
      flt_q_valid_atomic_request <= #TP valid_atomic_request;
      flt_q_atomic_op            <= #TP (atomic_fetchadd || atomic_swap || atomic_cas);
      flt_q_hdr_dw1              <= #TP chk_prfxHdr_flt_hdr_np[31:0];
      flt_q_hdr_dw2              <= #TP chk_prfxHdr_flt_hdr_np[63:32];
      flt_q_hdr_dw3              <= #TP chk_prfxHdr_flt_hdr_np[95:64];
      flt_q_hdr_dw4              <= #TP chk_prfxHdr_flt_hdr_np[127:96];
      flt_q_hdr_dec_cxlsrc        <= #TP hdr_dec_flt_np_in.hdr_dec_flt_c_d_r_14bit_t[52];
      flt_q_hdr_ohc_err           <= #TP hdr_dec_flt_np_in.hdr_dec_flt_c_d_r_14bit_t[51];
      flt_q_hdr_dec_nw            <= #TP hdr_dec_flt_np_in.hdr_dec_flt_c_d_r_14bit_t[50];
      flt_q_hdr_dec_ph            <= #TP hdr_dec_flt_np_in.hdr_dec_flt_c_d_r_14bit_t[49:48];
      flt_q_ohc_b_st_lb           <= #TP hdr_dec_flt_np_in.hdr_dec_flt_c_d_r_14bit_t[47:40];
      flt_q_hdr_dec_flt_dest_seg  <= #TP hdr_dec_flt_np_in.hdr_dec_flt_c_d_r_14bit_t[31:23];
      flt_q_hdr_dec_flt_reqtr_seg <= #TP hdr_dec_flt_np_in.hdr_dec_flt_c_d_r_14bit_t[22:14];
      flt_q_cfg_segment_id    <= #TP hdr_dec_flt_np_in.hdr_dec_flt_c_d_r_14bit_t[31:23];
      flt_q_14Bit_tag         <= #TP hdr_dec_flt_np_in.hdr_dec_flt_c_d_r_14bit_t[13:0];
      l_flt_q_log_rcvd_flds   <= #TP hdr_dec_flt_np_in.log_rcvd_flds ;
      flt_q_vc_select         <= #TP q_select_from_tc(radm_cfg_i.cfg_tc_struc_vc_map, tc);
      l_flt_q_parerr          <= #TP rtlh_radm_parerr_int | l_flt_data_parerr;
        flt_q_prfx            <= #TP hdr_dec_flt_np_in.hdr_dec_flt_prfx;
    end
  end

  assign  l_flt_q_tlp_abort       = (/*flt_q_cpl_abort |*/ flt_q_rtlh_abort | flt_q_invalid_prfx
                                    ) & flt_q_unqual_eot;




 assign  l_flt_q_hv                = l_flt_q_hv_int;
 assign  l_flt_q_dv                = l_flt_q_dv_int;
 assign  l_flt_q_eot               = l_flt_q_eot_int;

   // assign valid_ats = (!(&flt_q_ats) && flt_q_memrd_req) || (!flt_q_ats[0] && (flt_q_memwr_req || valid_def_memwr_request || flt_q_locked_rd || valid_atomic_request));
   assign valid_ats = (!(&flt_q_ats) && flt_q_memrd_req) || (!flt_q_ats[0] && (valid_def_memwr_request || flt_q_locked_rd || flt_q_valid_atomic_request));
    assign flt_q_len_zero = !(|flt_q_dw_len);

      assign flt_q_rd_size_in_range   = ({flt_q_len_zero, flt_q_dw_len,2'b0} <= radm_cfg_i.cfg_remote_rd_req_bridge_size_dec);



  assign  flt_q_ur_np_wo_poisn    = (flt_q_cfg1rd_req    || flt_q_cfg1wr_req ||
                                     flt_q_cfg0rd_req    || flt_q_cfg0wr_req ||
                                     flt_q_locked_rd     ||
                                     flt_q_memrd_req     || flt_q_atomic_op  ||
                                     flt_q_def_memwr_req ||
                                     flt_q_iord_req      || flt_q_iowr_req
                                    ) && (!flt_q_valid_np);

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

  assign fm_np_rsvd  = f_tlp_is_fm_np_rsvd(mode_e'(flit_mode), tlp_hdr_pkt);

  always @(posedge core_clk or negedge core_rst_n)
  begin
    if(!core_rst_n) begin
      fm_np_rsvd_r <= #TP '0;
    end else begin
      fm_np_rsvd_r <= #TP fm_np_rsvd;
    end
  end

  assign  flt_q_valid_ur_np       = ((flt_q_cfg1rd_req    || flt_q_cfg1wr_req ||
                                     flt_q_cfg0rd_req    || flt_q_cfg0wr_req ||
                                     flt_q_locked_rd     ||
                                     flt_q_memrd_req     || flt_q_atomic_op  ||
                                     flt_q_def_memwr_req ||
                                     flt_q_iord_req      || flt_q_iowr_req
                                    ) && (!flt_q_valid_np | flt_q_poisoned_discard |  flt_q_ecrc_discard | flt_q_hdr_ohc_err )) || (fm_np_rsvd_r[1] & !tmp_mlf_err & !l_flt_q_ecrc_err);

    assign rcrb_mbar0_access_wire     = (flt_q_mem_req && cfg_rcrb_mbar0_match_int_reg  && radm_cfg_i.cxl_rcrb_enable); 
    assign rcrb_access_wire           = (flt_q_mem_req && cfg_rcrb_match_reg && radm_cfg_i.cxl_rcrb_enable); 
    assign cxl_2_0_mbar0_access_wire  = (flt_q_mem_req && cxl_2_0_mbar0_access_int_reg);  



// target_is_cdm and target_is_elbi indicate if the tlp will be routed to CDM or ELBI.
// This will later be used to compute the completion as the ELBI and CDM have different limitation of the payload size.

wire target_is_cdm , target_is_elbi;

assign target_is_cdm          =           1'b0
                                          || rcrb_mbar0_access_wire
                                          || ( rcrb_access_wire | cxl_2_0_mbar0_access_wire)
                                             ;

assign  target_is_elbi          =  ~target_is_cdm;


assign  target_ca               = ((flt_q_dw_len == 0) || ((flt_q_dw_len > CX_ELBI_NW) && target_is_elbi) 
                                  || ((flt_q_dw_len > 1) && target_is_cdm)) && (target_acquisition == `FLT_DESTINATION_TRGT0);



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

  always_ff @(posedge core_clk or negedge core_rst_n)
  begin:  MESSAGE_INTERCEPTION_PROCESS
    if (!core_rst_n)
    begin
      flt_q_pcie_good_eot                        <= #TP 1'b0;
    end
    else
    begin
      flt_q_pcie_good_eot               <= #TP ord_flt_data_np_in.ord_flt_eot && pcie_valid_tc && !(ord_flt_data_np_in.ord_flt_dllp_err | radm_ecrc_err_int | extrct_malfm_tlp_errsts );
    end
  end

  assign  radm_cfg_o.radm_rcvd_tlp_req_id = flt_q_REQID;
    assign l_flt_q_header.flt_q_hv          = 1'b0;
    
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
                .PROT_WD                 (FLT_NP_HDR_PROT_WIDTH),
                .PARITY_MODE             (PARITY_MODE),        // cc
                .PROT_CORRECT_EN         (PROT_CORRECT_EN),    // cc
                .TOTAL_WIDTH             (FLT_NP_HDR_WIDTH),             
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
                .din      ({compressed_hdr_gen_out[FLT_NP_HDR_WIDTH:3],2'b00}), // flt_p_destination is taken 0 for parity calculation to avoid any issue at the trgt1 checker.
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
   assign  l_flt_q_header[FLT_NP_HDR_WIDTH:1] = compressed_hdr_gen_out[FLT_NP_HDR_WIDTH:1]; 
  
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
      latchd_flt_q_destination    <= #TP 0;
    else if (flt_q_unqual_hv)
      latchd_flt_q_destination    <= #TP int_flt_q_destination;
  end



  logic  [`FLT_Q_PRFX_WIDTH -1:0]  chk_flt_q_prfx_temp;
  logic [`CX_RX_PRFX_PAR_WD-1:0] prfx_par;
   assign  prfx_par = 'd0;

    assign chk_flt_q_prfx_temp = chk_flt_q_prfx;


radm_tph_ctrl
 u_radm_tph_ctrl(
      .flt_q_fmt_in      (flt_q_fmt),
      .flt_q_type_in     (flt_q_type),
      .flt_q_th_in       (flt_q_th),
      .flt_q_ph_in       (flt_q_ph_int),
      .flit_mode         (flit_mode),
      .flt_q_addr_in     (flt_q_addr)
       ,
      .flt_q_ohc_b_st_lb (flt_q_ohc_b_st_lb),
      .flt_q_tag         (flt_q_TAG[7:0]),
      .flt_q_last_be_in  (flt_q_last_be),
      .flt_q_first_be_in (flt_q_first_be),
      .flt_q_ats_in      (flt_q_ats),
      .flt_q_dw_len_in   (flt_q_dw_len),
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


 assign  radm_hdr_log_err_index_c  =  radm_hdr_log_err_index(radm_hdr_log_all_err);
 assign  radm_hdr_log_vld_c        =  l_set_radm_hdr_log_valid;


///////////////////////////////////////////////////////////////////
 // This logic is to detect HDR log should  report function specific or per function 
 // //////////////////////////////////////////////////////////////
 assign  radm_hdr_log_vld_all_fn_c        =  (l_flt_q_ecrc_err && !(ide_check_failed)) | tmp_mlf_err  | ((flt_q_valid_ur_err && flt_q_outrange_ur) && !(ide_check_failed||misrouted_ide_tlp))  ;

//---------------------------------------------------------------------------------         
// compressed header generation module   
//---------------------------------------------------------------------------------

// fields that will be used in forming compressed hdr
logic rom_req_in_range_c;
logic io_req_in_range_c;
logic [PF_WD-1:0]  flt_q_func_num_c;

  assign rom_req_in_range_c  = device_is_ep ? (flt_q_rom_req_in_range & ~(flt_q_valid_ur_np  | flr_in_progress)) : (flt_q_rom_req_in_range & ~(flt_q_valid_ur_np))  ;  // TRGT0 control
  assign io_req_in_range_c   = device_is_ep ? (flt_q_io_req_in_range  & ~(flt_q_valid_ur_np |  flr_in_progress)) : (flt_q_io_req_in_range  & ~(flt_q_valid_ur_np)) ;  // TRGT0 control

  assign flt_q_func_num_c   = flt_q_func_num;                  

compressed_hdr_gen_ctl_s compressed_hdr_gen_in;
radm_tlp_hdr_s           algn_rx_tlp_hdr, flt_rx_tlp_hdr, flt_rx_tlp_hdr_out;

assign compressed_hdr_gen_in.destination        = flt_q_destination;
assign compressed_hdr_gen_in.cpl_status         = flt_q_cpl_status;
assign compressed_hdr_gen_in.func_num_c         = flt_q_func_num_c;
assign compressed_hdr_gen_in.in_membar_range    = flt_q_in_membar_range;
assign compressed_hdr_gen_in.rom_req_in_range_c = rom_req_in_range_c;
assign compressed_hdr_gen_in.io_req_in_range_c  = io_req_in_range_c;
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

// instantiation of comressed_hdr_gen module
radm_compressed_hdr_gen
 #(
  .COMPRESSED_HDR_TYPE(flt_np_hdr_o_s),
  .FC_TYPE(E_NP)
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

  // ----------------------------------------------------------------
  // functions
  // ----------------------------------------------------------------




  `ifndef SYNTHESIS
    always_comb 
    begin:  ENCODE_VALID_TYPE
      case({1'b0,flt_q_valid_ur_np,1'b0,flt_q_valid_np} )
        4'b0001:    flt_q_valid_type = `FLT_VALID_NP_TYPE;
        4'b0010:    flt_q_valid_type = `FLT_VALID_P_TYPE;
        4'b0100:    flt_q_valid_type = `FLT_VALID_UR_NP_TYPE;
        4'b1000:    flt_q_valid_type = `FLT_VALID_UR_P_TYPE;
        default:    flt_q_valid_type = 3'b100; //
      endcase //
    end


    assign  TARGET_MAP              =  ( target_acquisition == `FLT_DESTINATION_TRASH ) ? "trash"     :
                                       ( target_acquisition == `FLT_DESTINATION_TRGT0 ) ? "TRGT0"     :
                                       ( target_acquisition == `FLT_DESTINATION_TRGT1 ) ? "TRGT1"     : "bogus";

    assign  RADM_Q_DEST             =  ( compressed_hdr_gen_out.flt_q_hdr.flt_q_destination == `FLT_DESTINATION_TRASH ) ? "trash"     :
                                       ( compressed_hdr_gen_out.flt_q_hdr.flt_q_destination == `FLT_DESTINATION_TRGT0 ) ? "TRGT0"     :
                                       ( compressed_hdr_gen_out.flt_q_hdr.flt_q_destination == `FLT_DESTINATION_TRGT1 ) ? "TRGT1"     :
                                       ( compressed_hdr_gen_out.flt_q_hdr.flt_q_destination == `FLT_DESTINATION_CPL   ) ? "CPL"       : "bogus";

    assign  RADM_Q_VALID_TYPE       =  ( flt_q_valid_type  == `FLT_VALID_NP_TYPE     ) ? "val_NP"    :
                                       ( flt_q_valid_type  == `FLT_VALID_P_TYPE      ) ? "val_P"     :
                                       ( flt_q_valid_type  == `FLT_VALID_UR_NP_TYPE  ) ? "val_UR_NP" :
                                       ( flt_q_valid_type  == `FLT_VALID_UR_P_TYPE   ) ? "val_UR_P"  : "----";


    assign  RADM_Q_TLP_TYPE         =  ( l_flt_q_tlp_type == 3'b001 ) ? "P"  :
                                       ( l_flt_q_tlp_type == 3'b010 ) ? "NP" :
                                       ( l_flt_q_tlp_type == 3'b100 ) ? "CPL":
                                       ( l_flt_q_tlp_type == 3'b000 ) ? "---": "BGS";

    // `ifdef CX_RASDP_EN
    //   logic [DW-1:0] ras_data;
    //   logic [DATA_PAR_WD-1:0] ras_ecc;
    //   assign ras_data = ord_flt_data_np[DW-1:0];
    //   assign ras_ecc  = ord_flt_data_np[DW +: DATA_PAR_WD];
    // `endif // CX_RASDP_EN
                                   
    //`ifdef SNPS_ASSERT_ON
    //
    //logic check_flt_q_cpl_crs;
    //logic [4:0] cov_cpl_crs;
    //logic [2:0] cov_bins;
    //
    //// CPL with CRS status
    //assign check_flt_q_cpl_crs = (flt_q_cpl_status == `CRS_CPL_STATUS);
    //assign cov_cpl_crs = {check_flt_q_cpl_crs, flt_q_cfg0rd_req, flt_q_cfg0wr_req, flt_q_cfg1rd_req, flt_q_cfg1wr_req};
    //
    //always_comb
    //begin
    //  case(cov_cpl_crs)
    //    5'b11000  : cov_bins = 3'b000;
    //    5'b10100  : cov_bins = 3'b001;
    //    5'b10010  : cov_bins = 3'b010;
    //    5'b10001  : cov_bins = 3'b011;
    //    default   : cov_bins = 3'b100;
    //  endcase
    //end
    //
    //property p_return_cpl_crs;
    //  @(posedge core_clk) disable iff (core_rst_n !== 1'b1)
    //    (!radm_cfg_i.cfg_cfg_tlp_bypass_en && flt_q_valid_np &&l_flt_q_hv &&  (flt_q_cfg1rd_req || flt_q_cfg1wr_req || flt_q_cfg0rd_req || flt_q_cfg0wr_req) && (app_req_retry_en_tmp)) |-> check_flt_q_cpl_crs;
    //endproperty
    //`CX_ASSERTION( p_return_cpl_crs, "CPL with CRS status should be returned" )
    //
    //covergroup cg_cpl_crs @(posedge core_clk);
    //  cp_cpl_crs : coverpoint cov_bins iff(core_rst_n) {
    //    option.comment = "CPL with CRS status sent for Type0 or Type1 Cfg Requests";
    //    bins CFGRD0_CRS = {3'b000};
    //    bins CFGWR0_CRS = {3'b001};
    //    bins CFGRD1_CRS = {3'b010};
    //    bins CFGWR1_CRS = {3'b011};
    //    ignore_bins ignore = {cov_bins[2]};
    //  }
    //endgroup
    //
    //cg_cpl_crs cg_inst_cpl_crs;
    //
    ////initial begin
    ////  cg_inst_cpl_crs = new();
    ////end
    //
    //
    //`ifdef CX_DETECT_POISONED_CFGWR
    //covergroup cg_cfgwr_poisoned @(posedge core_clk);
    //    cp_cfg0wr_poisoned : coverpoint (radm_rcvd_cfg0wr_poisoned);
    //    cp_cfg1wr_poisoned : coverpoint (radm_rcvd_cfg1wr_poisoned);
    //    `ifdef CX_SRIOV_ENABLE
    //    cp_cfg0wr_poisoned_for_vf : coverpoint (radm_rcvd_cfg0wr_poisoned && radm_rcvd_cfgwr_poisoned_is_vf);
    //    cp_cfg1wr_poisoned_for_vf : coverpoint (radm_rcvd_cfg1wr_poisoned && radm_rcvd_cfgwr_poisoned_is_vf);
    //    cp_cfg0wr_poisoned_for_pf : coverpoint (radm_rcvd_cfg0wr_poisoned && !radm_rcvd_cfgwr_poisoned_is_vf);
    //    cp_cfg1wr_poisoned_for_pf : coverpoint (radm_rcvd_cfg1wr_poisoned && !radm_rcvd_cfgwr_poisoned_is_vf);
    //    `endif
    //endgroup
    //
    //cg_cfgwr_poisoned cg_cfgwr_poisoned_inst;
    //initial cg_cfgwr_poisoned_inst = new();
    //
    //`endif // CX_DETECT_POISONED_CFGWR
    //
    //
    //`endif // SNPS_ASSERT_ON

  `endif // SYNTHESIS

 
    assign cfg_tph_enable = 1'b1;
  assign              np_wr         =  (tlp_fmt_type[6:0] == `IOWR)
                                        |  (tlp_fmt_type[6:0] == `DMWR32)
                                        |  (tlp_fmt_type[6:0] == `DMWR64)
                                        |  (tlp_fmt_type[6:0] == `CFGWR1)
                                        |  (tlp_fmt_type[6:0] == `CFGWR0);

  assign              np_rd         =  (tlp_fmt_type[6:0] == `IORD)
                                        |  (tlp_fmt_type[6:0] == `MRD32)
                                        |  (tlp_fmt_type[6:0] == `MRD64)
                                        |  (tlp_fmt_type[6:0] == `MRDLK32)
                                        |  (tlp_fmt_type[6:0] == `MRDLK64)
                                        |  (tlp_fmt_type[6:0] == `CFGRD1)
                                        |  (tlp_fmt_type[6:0] == `CFGRD0);


assign              atomic_op     = (tlp_fmt_type[6:0] == `FETCHADD32)
                                  | (tlp_fmt_type[6:0] == `FETCHADD64)
                                  | (tlp_fmt_type[6:0] == `SWAP32)
                                  | (tlp_fmt_type[6:0] == `SWAP64)
                                  | (tlp_fmt_type[6:0] == `CAS32)
                                  | (tlp_fmt_type[6:0] == `CAS64);


  assign valid_type                 = ( np_rd | np_wr );
  assign fc_type                    = (atomic_op | np_rd | np_wr) ? 2'b01 : 2'b11;
  assign tlp_has_pyld               = (tlp_fmt_type[6] & !fm_np_rsvd[1]) || fm_np_rsvd[0];
  assign hdr_4dw                    = tlp_fmt_type[5];
  assign dw_len_is0                 = (tlp_dw_len == 10'b0);

  // all errors below are latched to form the malformaed error at the final
  // cycle of the current tlp due to the abort issue of the currnt tlp
  // This error can only be generated based on long payload tlps


  assign max_pyld_err = pcie_max_pyld_err(radm_cfg_i.cfg_max_payload,dw_len_is0,tlp_dw_len,tlp_has_pyld);
  //
  //// CCIX spec permits the optimized TLPs to have min length[6:0]=2, however this minimum check is not required in the CCIX spec.
  //// The result is undefined in the CCIX spec when the TLP size is less than the minumum size.
  //// This check is implemented not to break the data path control when the illegal TLPs are received.
  //assign ccix_minlen_err = ccix_opt_tlp & (opt_tlp_dw_len<10'd2);
  //`else // CX_CCIX_INTERFACE_ENABLE
  //assign max_pyld_err = pcie_max_pyld_err;
  //`endif // CX_CCIX_INTERFACE_ENABLE


  // detect the interrupt message with TC non zero err according to page 67 of rev1.0
  // detect the VC/TC errors with TC non zero err according to page 84,85 of rev1.0
  assign  tc_err                    = ~( get_tc_enable(radm_cfg_i.cfg_tc_enable,tc));
  //  `ifdef CX_CCIX_INTERFACE_ENABLE
  //                                       | get_tc_enable(cfg_ccix_tc_enable,tc)
  //  `endif // CX_CCIX_INTERFACE_ENABLE
  //    );

  assign tmp_dw_len                  = {dw_len_is0, tlp_dw_len};



    assign len_mismatch              = ord_flt_data_np_in.ord_flt_eot & ((td & tlp_has_pyld ) ? (tmp_dw_len != pyld_dwcnt) :
                                       (td )                ? (pyld_dwcnt != 11'h0)      :
                                       (tlp_has_pyld )      ? (tmp_dw_len != pyld_dwcnt) : (pyld_dwcnt != 11'h0));

  // Atomic Op length check.
  // If the length field of an Atomic Op does not match an architected
  // operand size, the request must be handled as a MLF TLP.
  // Architected operand sizes are detailed in table 2-13 of the PCIe
  // base spec rev 2.1
  // Check for a valid Atomic Op.
  
  // An Atomic Op request must have a supported operand size otherwise
  // the request should be treated as a UR.
  assign  atomic_fetchadd = ((tlp_fmt_type[6:0] == `FETCHADD32)   || (tlp_fmt_type[6:0] == `FETCHADD64  )) && flt_q_pcie_format;
  assign  atomic_swap     = ((tlp_fmt_type[6:0] == `SWAP32)       || (tlp_fmt_type[6:0] == `SWAP64  ))     && flt_q_pcie_format;
  assign  atomic_cas      = ((tlp_fmt_type[6:0] == `CAS32)        || (tlp_fmt_type[6:0] == `CAS64  ))      && flt_q_pcie_format;

  assign atomic_operand32       = (atomic_fetchadd || atomic_swap) && (tlp_dw_len == 10'h1) ||
                                  atomic_cas && (tlp_dw_len == 10'h2);
  assign atomic_operand64       = (atomic_fetchadd || atomic_swap) && (tlp_dw_len == 10'h2) ||
                                  atomic_cas && (tlp_dw_len == 10'h4);
  assign atomic_operand128      = atomic_cas && (tlp_dw_len == 10'h8);
  
  assign valid_atomic_request   = atomic_operand32  && `CX_ATOMIC_32_CPL_EN ||
                                  atomic_operand64  && `CX_ATOMIC_64_CPL_EN ||
                                  atomic_operand128 && `CX_ATOMIC_128_CAS_EN;

  // Byte enable fields are reserved for Atomic Ops, so setting field to zero.
  // See "Memory, I/O and Configuration Request Rules" in Base Spec.
  assign atomic_be_err = 1'b0;

  assign atomic_operand_err = atomic_op && !(atomic_operand32 | atomic_operand64 | atomic_operand128);

  // For AtomicOp Requests, the Address must be naturally aligned with the operand size. The
  // Completer must check for violations of this rule. If a TLP violates this rule, the TLP is a
  // Malformed TLP
  

  assign atomic_addr_align_err = (atomic_operand32  && (addr_11_dt_0[1:0] != 2'h0)) ||
                                 (atomic_operand64  && (addr_11_dt_0[2:0] != 3'h0)) ||
                                 (atomic_operand128 && (addr_11_dt_0[3:0] != 4'h0));

  assign     tph_memrd = th && ((tlp_fmt_type[6:0] == `MRD32)
                             |  (tlp_fmt_type[6:0] == `MRD64)
                             |  (tlp_fmt_type[6:0] == `MRDLK32)
                             |  (tlp_fmt_type[6:0] == `MRDLK64));


  assign     mem_rd =          ((tlp_fmt_type[6:0] == `MRD32)
                             |  (tlp_fmt_type[6:0] == `MRD64)
                             |  (tlp_fmt_type[6:0] == `MRDLK32)
                             |  (tlp_fmt_type[6:0] == `MRDLK64));


    // This block implements the optional byte enable checks according to pages 55 and 56 of spec 1.1
    // Byte enable checks will only be applied to packets with valid byte enable fields

    // We want to turn off byte enable checks for MemRd requests with the TH
    // bit set in the header as the byte enable fields are repurposed to
    // carry a steering tag value for MemRd TLP's with TLP Processing hints
    // enabled.
    // The byte enables are reserved for AtomicOp requests unless the TH bit
    // is set. However, in both cases, we don't want to check the byte
    // enables
    assign     do_check       = !atomic_op && !tph_memrd &&
                                ( np_wr || np_rd); 

    // QW Aligned = least significant 3 bits of address are 3'b000.
    // Least 2 significant bits of address are Reserved and must be ignored
    // Bit[2] of address used to check QW alignment
    assign     is_qw_aligned  = ~addr_11_dt_0[2];
    // FBE Check
    assign     fbe_error      = (do_check && ((tlp_dw_len > 1) && (fbe == 4'b0000))) ? 1'b1 : 1'b0;
    // LBE Check      
    assign     lbe_error      = (do_check && ((tlp_dw_len == 1) && (lbe != 4'b0000))) ? 1'b1 :
                                (do_check && ((tlp_dw_len > 1) && (lbe == 4'b0000))) ? 1'b1 : 1'b0;

    // Compound byte enable error signal
    assign be_error           = fbe_error || lbe_error ||  ctig_error(do_check,is_qw_aligned,
                                tlp_dw_len,first_be,last_be);
    /* `ifndef SYNTHESIS
    
    always_ff @(posedge core_clk or negedge core_rst_n)
      if (be_error & ord_flt_eot_np & !rtlh_extrct_abort & core_rst_n) begin
        $display("%t %m: Byte Enable Warning!  %0s %0s %0s [is_qw_aligned = %0b, addr = %0b DW_Len = %0d, BE = %0b_%0b %0s]",
                 $time,
                 fbe_error == 1'b1 ? "fbe_err  " : "",
                 lbe_error == 1'b1 ? "lbe_err  " : "",
                 //ctig_error == 1'b1 ? "ctig_err " : "",
                 is_qw_aligned, int_addr_11_dt_0[2:0], tlp_dw_len, lbe, fbe,
                 tlp_fmt_type == 7'b00_00000 ? "MRd32" :
                 tlp_fmt_type == 7'b01_00000 ? "MRd64" :
                 tlp_fmt_type == 7'b00_00001 ? "MRdLk32" :
                 tlp_fmt_type == 7'b01_00001 ? "MRdLk64" :
  `ifdef CX_DEF_MEM_WR_ENABLE
                 tlp_fmt_type == 7'b10_11011 ? "DMWR32" :
                 tlp_fmt_type == 7'b11_11011 ? "DMWR64" :
  `endif // CX_DEF_MEM_WR_ENABLE
                 tlp_fmt_type == 7'b00_00010 ? "IORd" :
                 tlp_fmt_type == 7'b10_00010 ? "IOWr" :
                 tlp_fmt_type == 7'b00_00100 ? "CfgRd0" :
                 tlp_fmt_type == 7'b10_00100 ? "CfgWr0" :
                 tlp_fmt_type == 7'b00_00101 ? "CfgRd1" :
                 tlp_fmt_type == 7'b10_00101 ? "CfgWr1" :
                 tlp_fmt_type == `FETCHADD32 ? "FetchAdd32" :
                 tlp_fmt_type == `FETCHADD64 ? "FetchAdd64" :
                 tlp_fmt_type == `SWAP32     ? "Swap32" :
                 tlp_fmt_type == `SWAP64     ? "Swap64" :
                 tlp_fmt_type == `CAS32      ? "CAS32" :
                 tlp_fmt_type == `CAS64      ? "CAS64" :
                 "Unk");
      end
    `endif // SYNTHESIS
    */
    // This block implements the optional address/length check according to page 62 of spec 1.1
    // "Requests must not specify an Address/Length combination which causes a Memory Space access to cross a 4-KB boundary"
    
    always_comb  begin
      addr_len_error = 1'b0;
      if (
          (tlp_fmt_type[6:0] == `DMWR32)       || (tlp_fmt_type[6:0] == `DMWR64)     ||
          (tlp_fmt_type[6:0] == `FETCHADD32)   || (tlp_fmt_type[6:0] == `FETCHADD64) ||
          (tlp_fmt_type[6:0] == `SWAP32)       || (tlp_fmt_type[6:0] == `SWAP64)     ||
          (tlp_fmt_type[6:0] == `MRD32)        || (tlp_fmt_type[6:0] == `MRD64)      ||
          (tlp_fmt_type[6:0] == `MRDLK32)      || (tlp_fmt_type[6:0] == `MRDLK64)) begin
        addr_len_error = (({1'b0, addr_11_dt_0[11:2]} + tmp_dw_len[10:0]) > 12'h400) ? 1'b1 : 1'b0;
      end
      // For Atomic CAS requests, the amount of memory accessed is half the
      // TLP DWORD length so we must take this into account for the check.
      else if ((tlp_fmt_type[6:0] == `CAS32)   || (tlp_fmt_type[6:0] == `CAS64)) begin
        addr_len_error = (({1'b0, addr_11_dt_0[11:2]} + (tmp_dw_len[10:0] >> 1)) > 12'h400) ? 1'b1 : 1'b0;
      end
    end

  
  assign {hdr_err_ptr, hdr_err} = max_pyld_err               ? {`MFPTR_TLP_MXPL, 1'b1} :
                                    tc_err                   ? {`MFPTR_TLP_TC,   1'b1} :
                                                               {`MFPTR_NO_ERR,   1'b0} ;

  assign rtlh_extrct_ecrc_len_mismatch        = 1'b0;  

  assign {extrct_malfm_tlp_err_ptr, extrct_malfm_tlp_errsts} = rtlh_extrct_abort                             ? {`MFPTR_NO_ERR,    1'b0} :
                                                               atomic_addr_align_err                         ? {`MFPTR_ATOM_ADR,  1'b1} :
                                                               atomic_operand_err                            ? {`MFPTR_ATOM_OPR,  1'b1} :
                                                               atomic_be_err                                 ? {`MFPTR_ATOM_BE ,  1'b1} :
                                                               len_mismatch                                  ? {`MFPTR_TLP_DLEN,  1'b1} :
                                                               hdr_len_mismatch                              ? {`MFPTR_TLP_HLEN,  1'b1} :
                                                               hdr_err                                       ? {hdr_err_ptr,      1'b1} :
                                                                 be_error                                    ? {`MFPTR_TLP_BE,    1'b1} :
                                                                 addr_len_error                              ? {`MFPTR_TLP_4KBND, 1'b1} :
                                                               ((fmt2 & (~flit_mode) ) | hdr_dec_flt_np_in.radm_malf_tlp_err_hdr_prfx )  ? { `MFPTR_PFX,       1'b1} :
                                                               hdr_dec_flt_np_in.radm_malf_tlp_err_hdr_flit  ? {`MFPTR_TLP_FLIT,  1'b1} :
                                                               rtlh_extrct_ecrc_len_mismatch                 ? {`MFPTR_TLP_ELEN,  1'b1} :
                                                                                                               {`MFPTR_NO_ERR,    1'b0} ;

  assign  addr64              = hdr_dw1[5];
  assign  addr_low            = addr64 ? {hdr_dw4[7:0], hdr_dw4[15:8], hdr_dw4[23:16], hdr_dw4[31:24]} :
                                         {hdr_dw3[7:0], hdr_dw3[15:8], hdr_dw3[23:16], hdr_dw3[31:24]};
  assign  addr_high           = addr64 ? {hdr_dw3[7:0], hdr_dw3[15:8], hdr_dw3[23:16], hdr_dw3[31:24]} : 32'b0;
  //assign  rtlh_radm_ant_addr  = {addr_high, addr_low};
  //assign  rtlh_radm_ant_rid   = {hdr_dw3[7:0], hdr_dw3[15:8]};

  always_comb  begin : NEXT_CRD_UPDATE
    next_incr_enable  = ord_flt_data_np_in.ord_flt_eot && !rtlh_extrct_abort && fc_type != 2'b11;
    next_fctype       = fc_type;
    // spyglass disable_block W164a
    // SMD: Identifies assignments in which the LHS width is less than the RHS width
    // SJ: This logic is designed to be modulo. next_incr_amt counters are intended to
    // wrap without preseveration of carry/borrow
    if(tlp_has_pyld) begin
      next_incr_amt   = tmp_dw_len[10:2] + |tmp_dw_len[1:0];
    end else begin
      next_incr_amt   = 0;
    end
  end
  // spyglass enable_block W164a

// Unused signal assignments   for structure - 
          assign  radm_cfg_o.radm_ptm_req             = 'd0; 
          assign  radm_cfg_o.radm_ptm_res_msg         = 'd0; 
          assign  radm_cfg_o.radm_ptm_res_d_msg       = 'd0; 
          assign  radm_cfg_o.radm_ptm_master_time     = 'd0; 
          assign  radm_cfg_o.radm_ptm_prop_delay      = 'd0; 
         assign radm_cfg_o.radm_msg_payload           = 'd0;
         //assign radm_cfg_o.radm_rcvd_req_ca           = 'd0;
         //assign radm_cfg_o.radm_rcvd_wreq_poisoned    = 'd0;
         assign  radm_cfg_o.radm_pm_asnak             = 'd0; 
         assign  radm_cfg_o.radm_pm_turnoff           = 'd0; 
         assign  radm_cfg_o.radm_msg_unlock           = 'd0; 
         assign  radm_cfg_o.radm_rcvd_cpl_poisoned ='d0;
         assign  radm_cfg_o.radm_rcvd_cpl_ur       ='d0;
         assign  radm_cfg_o.radm_rcvd_cpl_ca       ='d0;
         assign  radm_cfg_o.radm_unexp_cpl_err     ='d0;
      assign radm_cfg_o.radm_slot_pwr_limit             =  1'b0;
    assign                        radm_cfg_o.radm_inta_asserted  ='d0;
    assign                        radm_cfg_o.radm_intb_asserted  ='d0;
    assign                        radm_cfg_o.radm_intc_asserted  ='d0;
    assign                        radm_cfg_o.radm_intd_asserted  ='d0;
    assign                        radm_cfg_o.radm_inta_deasserted  ='d0;
    assign                        radm_cfg_o.radm_intb_deasserted  ='d0;
    assign                        radm_cfg_o.radm_intc_deasserted  ='d0;
    assign                        radm_cfg_o.radm_intd_deasserted  ='d0;
    assign                        radm_cfg_o.radm_err_cor      ='d0;  
    assign                        radm_cfg_o.radm_err_nf       ='d0;
    assign                        radm_cfg_o.radm_err_f        ='d0; 
  assign radm_cfg_o.radm_msg_cpu_active = 'd0;
  assign radm_cfg_o.radm_msg_obff       = 'd0;
  assign radm_cfg_o.radm_msg_idle       = 'd0;

function automatic [PF_WD:0] one_hot_decode_2_zero;
    input [RC_NF-1:0]      one_hot_target;
    reg   [PF_WD-1:0]   encoded;
    reg                 target_eq_0;
    integer             i;

    begin
      // only function 0 is supported in RC mode
      encoded = 0;
      target_eq_0 = 1'b1;
      for (int i=RC_NF-1; i>=0 ; i=i-1) begin
        if(one_hot_target[i] == 1'b1) begin
          encoded     = i;
          target_eq_0 = 1'b0;
        end
      end

      one_hot_decode_2_zero = {encoded,target_eq_0};
    end
endfunction


endmodule
