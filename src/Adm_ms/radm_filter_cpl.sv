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
// ---    $DateTime: 2024/01/19 09:25:58 $
// ---    $Revision: #11 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_filter_cpl.sv#11 $
// -------------------------------------------------------------------------
//// -----------------------------------------------------------------------------
//// --- Module Description:
//// -----------------------------------------------------------------------------
////  1. process and disassemble received cpl 
////  2. generate appropriate completion fields for p/np.
////  3. determine supported/unsupported requests.
////  4. provide data steering control for received tlp's (flt_q_destination)
////  5. detect tlp error conditions  and generate error signaling
////  6. provide error logging strobe/header.
////  7. Intercept decode message tlps, and signal CDM
////  9. multi-function supported
//// -----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"
`include "products/pcie_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

module radm_filter_cpl
  

//import radm_ms_pkg starts
  import radm_ms_pkg::FLT_NUM;
  import radm_ms_pkg::PKT_ORD_WD;
  import radm_ms_pkg::HW;
  import radm_ms_pkg::HW_NFT;
  import radm_ms_pkg::HW_NFT_PAR;
  import radm_ms_pkg::FILTER_CHK_CNTS;
  import radm_ms_pkg::FLT_OUT_PROT_WD;
  import radm_ms_pkg::HEW;
  import radm_ms_pkg::P_TYPE;
  import radm_ms_pkg::NP_TYPE;
  import radm_ms_pkg::CPL_TYPE;
  import radm_ms_pkg::ERROR_LOG_PIPE_DELAY;
  import radm_ms_pkg::FLT_Q_PIPE_DELAY;
  import radm_ms_pkg::hdr_destination;
  import radm_ms_pkg::hdr_fmt;
  import radm_ms_pkg::radm_cfg_i_s;
  import radm_ms_pkg::radm_cfg_tlp_o_s;
  import radm_ms_pkg::radm_ord_mgr_flt_data_s;
  import radm_ms_pkg::radm_hdr_dec_com_ohc_decx_present_s;
  import radm_ms_pkg::radm_hdr_dec_flt_s;
  import radm_ms_pkg::flt_q_dmux_o_s;
  import radm_ms_pkg::flt_cpl_lut_s;
  import radm_ms_pkg::flt_cpl_hdr_s;
  import radm_ms_pkg::FLT_CPL_HDR_WIDTH;
  import radm_ms_pkg::FLT_CPL_HDR_PROT_WIDTH;
  import radm_ms_pkg::flt_data_o_s;
  import radm_ms_pkg::flt_cpl_hdr_o_s;
  import radm_ms_pkg::route_error_to_func;
  import radm_ms_pkg::radm_hdr_log_err_index;
  import radm_ms_pkg::radm_hdr_log_rcvd_flds_s ;
  import radm_ms_pkg::get_bar_num;
  import radm_ms_pkg::pcie_max_pyld_err ;
  import radm_ms_pkg::get_tc_enable;
    import radm_ms_pkg::little_end_prfx;
  import radm_ms_pkg::e2e_prfx_log_in;
  import radm_ms_pkg::get_VC;
  import radm_ms_pkg::q_select_from_tc;
  import radm_ms_pkg::compressed_hdr_gen_ctl_s;
  import radm_ms_pkg::radm_tlp_hdr_s;
  //import radm_ms_pkg ends
  import DWC_pcie_ctl_pkg::TP;
  import DWC_pcie_ctl_pkg::NW;
  import DWC_pcie_ctl_pkg::NF;
  import DWC_pcie_ctl_pkg::NVF;    
  import DWC_pcie_ctl_pkg::PF_WD;  
  import DWC_pcie_ctl_pkg::VF_WD;  
  import DWC_pcie_ctl_pkg::VFI_WD; 
  import DWC_pcie_ctl_pkg::NVC;
  import DWC_pcie_ctl_pkg::NPRFX;
  import DWC_pcie_ctl_pkg::TAG_SIZE;
  import DWC_pcie_ctl_pkg::ATTR_WD;
  import DWC_pcie_ctl_pkg::PRFX_W_PAR;
  import DWC_pcie_ctl_pkg::RAS_PROT_RANGE;
  import DWC_pcie_ctl_pkg::RAS_PROT_TYPE;
  import DWC_pcie_ctl_pkg::RAS_PARITY_MODE;
   import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::P_REQ_TX_TYPE_WD ;
  import DWC_pcie_ctl_pkg::NP_REQ_TX_TYPE_WD;
    import DWC_pcie_ctl_pkg::ANTI_CTRL_PIPE_DELAY;
    import DWC_pcie_ctl_pkg::PRFX_PROT_WD;

  import DWC_pcie_ctl_pkg::PRFX_WIDTH;


  import DWC_pcie_core_pkg::CCIX_WD;
  import DWC_pcie_core_pkg::DATA_PAR_WD;
  import DWC_pcie_core_pkg::DW;
   //import pcie_pkg starts

  import pcie_pkg::E_CPL;
  import pcie_pkg::mode_e;
  import pcie_pkg::cpl_status_e;
  import pcie_pkg::prfx_type_e;
  import pcie_pkg::tlp_hdr_pkt_s;
  import pcie_pkg::f_tlp_is_fm_cpl_rsvd;


#(
  parameter RAS_DP_PROT_CHK_ID_BASE  = 0,
  localparam ALT_PF_WD                = NF == 1 ? 1 : $clog2(NF), // Alternative number of bits needed to address the physical functions

    localparam ERR_INJ_INDEX          = (FLT_NUM==0)? 20 : 77,
  // Segbuf parameters
  parameter PIPE_VF_INDEX             = 0 ,
  parameter PIPE_VF_INDEX_WIDTH       =  PF_WD  , // in_vf_membar_range + mem_vf_num
                                      
  parameter PIPE_CFG_WIDTH            = (6*NF) + (6*NF) + NF                          //radm_cfg_tlp_i.cfg_bar_match + radm_cfg_i.cfg_bar_is_io + radm_cfg_tlp_i.cfg_rom_match + coerce_cfg_tlp_to_trgt1
                                      ,

  // Sending and Receiving of TLP Prefixes enabled

  parameter ERROR_LOG_PIPEWIDTH       = 128
                                          + 128
                                            + 1
                                          + PF_WD                       // flt_q_func_num
                                          + 8                           // set_radm_mlf_tlp_err_ptr
                                        + 10
                                        ,

  //parameter FLT_Q_PIPEWIDTH           = DW + DATA_PAR_WD + 1 + NW + 1 + 1 + FLT_CPL_HDR_WIDTH + FLT_OUT_PROT_WD + 1 + 3 + PKT_ORD_WD,
  parameter FLT_Q_PIPEWIDTH           = DW + DATA_PAR_WD + 1 + NW + 1 + 1 +  $bits(flt_cpl_hdr_o_s)
                                        + 1 
                                         +1
                                        +5
                                        +1
                                        +1
                                        ,
  parameter N_FLT_MASK                = `CX_N_FLT_MASK,
  
  localparam FC_OPT                   = 0 ,
  localparam CDM_OPT                  = (NW==16)? 0 : 0 ,
  localparam N_CYCLE_DELAY_GLOBAL     = ((FC_OPT == 1) || (CDM_OPT == 1))? 2 : 1,


  // CTRL_register_path 
  localparam CTRL_WIDTH               = 3                                   // hv,dv,eot

) 

                        (
  // ---- inputs ---------------
  input                                                 core_clk,
  input                                                 radm_clk_ug,
  input                                                 core_rst_n,
  input                                                 flit_mode,
  // Config
  input   radm_cfg_i_s                                  radm_cfg_i,
  output  radm_cfg_tlp_o_s                              radm_cfg_o,
  output  flt_data_o_s                                  flt_q_data_o_cpl,
  output  flt_cpl_hdr_o_s                               flt_q_hdr_o_cpl,
  // output  flt_q_dmux_o_s                                flt_q_dmux_o_cpl,
  // end config
  input [15:0]                                          filt_ant_rid_cpl_in,
  input flt_cpl_lut_s                                   flt_cpl_lut_in,
  input                                                 rtlh_radm_parerr_int,
  input                                                 radm_ecrc_err,
  input                                                 malform_ecrc_err,
  input                                                 app_req_retry_en,
  input [NF-1:0]                                        app_pf_req_retry_en,

  // Raw header interface
  input   radm_tlp_hdr_s                                rx_tlp_hdr,

  input radm_ord_mgr_flt_data_s                         ord_flt_data_cpl,
  //  `ifdef CX_CCIX_INTERFACE_ENABLE
  //    input [CCIX_WD-1:0]                             hdr_dec_lt_hdr_ccix_tlp,
  //  `endif // CX_CCIX_INTERFACE_ENABLE
  input radm_hdr_dec_flt_s                              hdr_dec_flt_cpl,
  input                                                 cpl_mlf_err,
  input                                                 flt_q_cpl_last,
  input                                                 cpl_ur_err,
  input                                                 cpl_ca_err,
  input                                                 lut_filt_cpl_abort,
  input                                                 unexpected_cpl_err,

  // ---- outputs ---------------
  output logic  [TAG_SIZE-1:0]                          flt_q_rcvd_cpl_tlp_tag,
  output logic                                          cpl_tlp,
  output logic                                          flt_dwlenEq0,
  output logic                                          rtlh_radm_ecrc_err,
  output logic                                          rtlh_radm_malform_tlp_err,
  output flt_cpl_lut_s                                  flt_cpl_lut,
  output logic  [2:0]                                   cpl_status
  ,
  output ras_dp_err_log_t     [FILTER_CHK_CNTS-1:0]     ras_dp_err_log,
  input  ras_dp_err_inj_t                               ras_dp_err_inj  

);
  localparam PROT_RANGE      = `CX_RAS_PROT_RANGE;
  localparam PROT_TYPE       = `CX_RAS_PROT_TYPE;
  localparam PARITY_MODE     = `CX_RAS_PARITY_MODE;
  localparam PROT_CORRECT_EN = PROT_TYPE? 0 : `CX_RAS_CORRECTION_EN;
  localparam PRF_CHK_NO      = 0;
  localparam FLT_HDR_CHK_NO  = 0 + 1;
  // -------------------------------- Internal Signal declaration  ----------------------------
  //
  //

  logic              extrct_malfm_tlp_errsts;

  logic                                                 rtlh_radm_parerr ;
  assign                                                rtlh_radm_parerr = 'd0;
  assign rtlh_radm_malform_tlp_err  =   extrct_malfm_tlp_errsts;

logic flt_q_cpl_abort;
logic [NP_REQ_TX_TYPE_WD-1:0] l_flt_q_np_req_type;

  flt_cpl_hdr_o_s                               compressed_hdr_gen_out;
  logic force_bus_match;        /// For CPL it should be 0
  logic force_bus_match_int;    /// For CPL it should be 0
  logic [15:0] form_filt_ant_rid_d;
  assign force_bus_match ='d0;  /// For CPL it should be 0
  logic [15:0] filter_rid;

  radm_hdr_dec_flt_s                            hdr_dec_flt_cpl_in; 
  radm_ord_mgr_flt_data_s                       ord_flt_data_cpl_in;

////// ANT_ADDR
  logic [15:0]  cpl_rid;
  assign  flt_cpl_lut  = flt_cpl_lut_in; 
  assign  cpl_rid      = flt_cpl_lut_in.flt_cpl_lut_rid; 
  assign  hdr_dec_flt_cpl_in  = hdr_dec_flt_cpl;
  assign  ord_flt_data_cpl_in = ord_flt_data_cpl;

/////////////////
  
  logic                                                 cdm_core_in_dpc_reg[FLT_Q_PIPE_DELAY-1:0];
  logic                                                 radm_rcvd_cpl_poisoned_int;
  logic                                                 radm_rcvd_cpl_ur_int ;
  logic                                                 radm_rcvd_cpl_ca_int;
  logic [NF-1:0]                                        radm_hdr_log_valid_int;
  logic [HEW-1:0]                                       hdr_dw1;                    // sync with rtlh time domain
  logic [HEW-1:0]                                       hdr_dw2;
  logic [HEW-1:0]                                       hdr_dw3;
  logic [HEW-1:0]                                       hdr_dw4;
  logic [14-1:0]                                        flt_q_14Bit_tag;

  logic [7:0]                                           flt_q_hdr_dec_flt_cpltr_seg;
  logic                                                 flt_q_hdr_ohc_err;
  logic [8:0]                                           flt_q_hdr_dec_flt_dest_seg ;
  logic                                                 pcie_valid_tc;
  logic                                                 pcie_format;
  logic [2:0]                                           tlp_type;
  logic [4:0]                                           hdr_type;
  logic [1:0]                                           fmt;
  logic                                                 fmt2;
  logic                                                 flt_q_invalid_tlp;
  logic [(5*NPRFX)-1:0]                                 flt_q_prfx_type;        // Type field of received TLP Prefix.
  logic   [1:0]                                         fm_cpl_rsvd;
  logic   [1:0]                                         fm_cpl_rsvd_r;
    logic [NPRFX-1:0]                                   prfx_type_rsrvd;        // the bit of a given Prefix is set if Type field is a reserved value
    logic                                               flt_q_prfx_type_error;  // asserted if any prefix type is reserved.
      logic                                             flt_q_prfx_local_after_end_err; // asserted if a local type prefix follows an end-end type prefix
      logic                                             flt_q_prfx_end_end_max_err;      // Asserted when max End-End limit is exceeded
      logic [31:0]                                      ovrflw_end_end_prfx;             // the first overflow End-End TLP Prefix (exceeds Function's Max End-End TLP Prefixes field)
    logic                                               flt_q_invalid_prfx;
  logic                                                 flt_q_pcie_format;
  logic                                                 flt_q_pcie_valid_tc;
    logic [1:0]                                         ats;
  logic [9:0]                                           dw_len;
  logic [ATTR_WD-1:0]                                   attr;
  logic                                                 tlp_w_pyld;
  logic                                                 td;
  logic [2:0]                                           tc;
  logic [3:0]                                           first_be;
  logic [3:0]                                           last_be;
  logic                                                 dwlenEq1;
  logic                                                 cpl_bcm;
  logic                                                 flt_q_rtlh_abort;
  logic                                                 flt_q_cpl_mlf_err;
  logic                                                 flt_q_msg_mlf_err;
  logic [HEW-1:0]                                       flt_q_hdr_dw1;                  // sync with q time domain
  logic [HEW-1:0]                                       flt_q_hdr_dw2;
  logic [HEW-1:0]                                       flt_q_hdr_dw3;
  logic [HEW-1:0]                                       flt_q_hdr_dw4;
  radm_hdr_log_rcvd_flds_s                              l_flt_q_log_rcvd_flds ;

  logic [DW+DATA_PAR_WD-1:0]                            l_flt_q_data;                // flt_q  //tlp data sent to queue
  // aux bus to decouple the internal wiring from the use of RAS. If RAS is used chk_l_flt_q_data holds the 
  // value of l_flt_q_data at the output of bus_protect_chk. If RAS is not used chk_l_flt_q_data is just a 
  // feedthrough
  logic                                                 l_flt_q_dllp_abort;               // flt_q  //Recall packet (Malformed TLP, etc.)
  logic [NVC-1:0]                                       l_flt_q_dv;                       // flt_q  //1 when flt_q_data   is valid
  logic [NW-1:0]                                        l_flt_q_dwen;                     // flt_q  //DWord Enable for Data Interface.
  logic                                                 l_flt_q_ecrc_err;                 // flt_q  // -> radm_q
  logic [NVC-1:0]                                       l_flt_q_eot;                      // flt_q  //Indicate end of packet
  flt_cpl_hdr_o_s                                       l_flt_q_header;                   // flt_q  //tlp compressed header sent to queue
  flt_cpl_hdr_o_s                                       l_flt_q_header_d;                 // flt_q  //tlp compressed header sent to queue
  //logic [FLT_CPL_HDR_WIDTH+FLT_OUT_PROT_WD-1:0]             chk_l_flt_q_header_d;             // flt_q  //tlp compressed header sent to queue, output of bus_protect_chk if RAS is enabled
  flt_cpl_hdr_s                                         chk_l_flt_q_header_d;             // flt_q  //tlp compressed header sent to queue, output of bus_protect_chk if RAS is enabled

  // decouple the internal header wiring from the use of RAS. If RAS is used then chk_prfxHdr_flt_hdr is the output of
  // bus_protect_chk module. Without RAS it's just a feedthrough of hdr_dec_flt_hdr_cpl
  logic [HW_NFT+HW_NFT_PAR-1:0]                                    chk_prfxHdr_flt_hdr;           // 128-bit packet header
  logic [NVC-1:0]                                       l_flt_q_hv;                       // flt_q  //1 when l_flt_q_header is valid
  logic                                                 l_flt_q_tlp_abort;                // flt_q  //Recall packet (Malformed TLP, etc.)
  logic [2:0]                                           l_flt_q_tlp_type;                 // flt_q  //one hot signal indicating to indicate CPL TLP, valid @ l_flt_q_hv
  logic                                                 l_flt_q_parerr;
  logic                                                 int_flt_q_parerr;                 // error indication at the output of the delay module
  logic                                                 l_set_radm_rcvd_cpl_ca;
  logic                                                 l_set_radm_rcvd_cpl_ur;
  logic                                                 l_set_radm_ecrc_err;
  logic                                                 l_set_radm_hdr_log_valid;
  logic                                                 l_set_radm_mlf_tlp_err;
  logic                                                 l_set_radm_rcvd_req_ca;
  logic                                                 l_set_radm_rcvd_cpl_poisoned;
  logic                                                 l_set_radm_rcvd_req_ur;
  logic                                                 l_set_radm_rcvd_wreq_poisoned;
  logic                                                 l_set_radm_unexp_cpl_err;
  logic                                                 l_set_outrange_req_ur;
  logic [127:0]                                         l_radm_hdr_log;
  logic                                                 set_radm_rcvd_cpl_ca;
  logic                                                 set_radm_rcvd_cpl_ur;
  logic                                                 set_radm_ecrc_err;
  logic                                                 set_radm_hdr_log_valid;
  logic                                                 set_radm_mlf_tlp_err;
  logic                                                 set_radm_rcvd_req_ca;
  logic                                                 set_radm_rcvd_cpl_poisoned;
  logic                                                 set_radm_rcvd_req_ur;
  logic                                                 set_outrange_req_ur;
  logic                                                 set_radm_unexp_cpl_err;
  logic [1:0]                                           int_flt_q_destination;
  logic [1:0]                                           latchd_flt_q_destination;
  logic [1:0]                                           flt_q_destination;
  logic [ATTR_WD-1:0]                                   flt_q_attr;
  logic[2:0]                                            flt_q_tc;
  logic[TAG_SIZE-1:0]                                   flt_q_TAG;
  logic[15:0]                                           flt_q_REQID;
  logic[4:0]                                            flt_q_type;
  logic[1:0]                                            flt_q_fmt;
  logic                                                 flt_q_fmt2; // second [2] bit of FMT field used to detect reserved TLP in FLIT mode 
  logic[15:0]                                           flt_q_cplid;
  logic                                                 flt_q_cpl_w_lock;
  logic                                                 flt_q_cpl_wo_lock;
  logic                                                 flt_q_func_mismatch;
  logic                                                 flt_q_td;
  logic                                                 flt_q_td_hdr_log;
  logic                                                 flt_q_poisoned;
  logic                                                 flt_q_poisoned_err;
  logic                                                 flt_q_addr64;
  logic [3:0]                                           flt_q_first_be;
  logic [3:0]                                           flt_q_last_be;


    logic                                                 flt_q_poisoned_discard_ep;
    logic [NF-1:0]                                        target_rom_map;                   // Each bit of this vector indicates which target receives rom    transactions for that bar #
    logic                                                 latch_hdr_pipe_en_ep;
    logic                                                 l_flt_data_parerr_ep;
    logic                                                 flt_q_pipe_en_ep;
    logic                                                 flt_q_unqual_dv_ep;
    logic                                                 flt_q_unqual_hv_ep;
    logic                                                 flt_q_unqual_eot_ep;
    logic [DW+DATA_PAR_WD-1:0]                            chk_l_flt_q_data_ep;
      logic [4:0]                                         flt_q_dev_num_ep;
  
  logic [PF_WD-1:0]                                     flt_q_cfg_func_num;
  logic [PF_WD-1:0]                                     flt_q_func_num;
  logic [PF_WD-1:0]                                     flt_q_func_num_rc;
  logic [PF_WD-1:0]                                     flt_q_func_num_ep;
  logic [PF_WD-1:0]                                     raw_flt_q_func_num;
  logic [PF_WD-1:0]                                     raw_func_num_unreg;
  logic [PF_WD-1:0]                                     flt_q_func_num_d;
  logic [PF_WD-1:0]                                     pf;
  logic [PF_WD-1:0]                                     pfvf_func_num;
  assign                                                pfvf_func_num = 'd0; // for CPL it should be 0
  logic [3:0]                                           flt_q_ext_reg_num;
  logic [5:0]                                           flt_q_reg_num;
  logic [63:0]                                          flt_q_addr;
  logic [63:0]                                          flt_q_addr_int;
  logic [7:0]                                           flt_q_addr_byte0;
  logic [7:0]                                           flt_q_addr_byte1;
  logic [7:0]                                           flt_q_addr_byte2;
  logic [7:0]                                           flt_q_addr_byte3;
  logic [7:0]                                           flt_q_addr_byte4;
  logic [7:0]                                           flt_q_addr_byte5;
  logic [7:0]                                           flt_q_addr_byte6;
  logic [7:0]                                           flt_q_addr_byte7;
  logic [9:0]                                           flt_q_dw_len;
  logic [NVC-1:0]                                       flt_q_vc_select;
  logic [2:0]                                           flt_q_actual_cpl_status;
  logic [2:0]                                           flt_q_cpl_status;
  logic [2:0]                                           flt_q_cpl_status_ep;
  logic [2:0]                                           flt_q_cpl_status_rc;
  logic                                                 flt_q_cpl_bcm;
  logic [2:0]                                           flt_q_rcvd_cpl_status;
  logic                                                 flt_q_reserved_status;
  logic [15:0]                                          flt_q_cpl_reqid;
  logic [11:0]                                          flt_q_rcvd_tlp_byte_cnt;
  logic [6:0]                                           flt_q_rcvd_tlp_low_addr;
  logic                                                 flt_q_status_sc;
  logic                                                 flt_q_status_ur;
  logic                                                 flt_q_status_ca;
  logic                                                 flt_q_status_crs;
  logic                                                 radm_rcvd_req_ca_int;              // PME should not be received by endpoint device
  logic [NF-1:0]                                        radm_rcvd_req_ur_int ;             // PME should not be received by endpoint device
  logic   [NF-1:0]                                      radm_rcvd_wreq_poisoned_int  ;     // PME should not be received by endpoint device
  logic                                                 rtlh_dllp_err_d  ;
  logic  [PKT_ORD_WD-1:0]                               ord_flt_p_pkt_num_d  ;
  logic                                                 l_flt_q_tlp_poisoned;
  // CPL declarations
  logic                                                 flt_q_outrange_ur;
  logic                                                 flt_q_cpl_rcvd_ur;
  logic                                                 flt_q_cpl_rcvd_ca;
  logic                                                 l_flt_q_unexp_cpl_err;
  logic                                                 flt_q_unexp_cpl_err;
  logic                                                 pm_block_tlp;
  assign                                                pm_block_tlp='d0;           // TO DO 
  logic                                                 flr_in_progress;
  logic                                                 flr_pf_in_progress;
  logic                                                 flr_vf_in_progress;

  // Sending and Receiving of TLP Prefixes enabled
    logic [PRFX_W_PAR-1:0]                                 flt_q_prfx;             // retimed rtlh_radm_prfx
    logic [PRFX_W_PAR-1:0]                                 chk_flt_q_prfx;         // aux wire to decouple from RAS
  logic                                                 tmp_mlf_err;
  logic [7:0]                                           tmp_mlf_err_ptr;
  logic [7:0]                                           flt_q_rtlh_abort_ptr;
    logic  [7:0]                                        l_set_radm_mlf_tlp_err_ptr;
    logic [7:0]                                         set_radm_mlf_tlp_err_ptr;
  logic                                                 malform_ecrc_err_int;
  logic                                                 radm_ecrc_err_int;  
  assign                                                rtlh_radm_ecrc_err = radm_ecrc_err_int;

  logic                                                 l_flt_q_header_d_prot_err;
  logic                                                 app_req_retry_en_tmp;
  logic                                                 int_app_req_retry_en;
  logic [NF-1:0]                                        int_app_pf_req_retry_en;
  logic                                                 flt_q_mask_wreq_poisoned_reporting;
  logic                                                 flt_q_mask_cpl_poisoned_reporting;
  logic [2:0]                                           in_iobar_range;
  logic                                                 flt_q_valid_ur_wo_poisn_err;
  logic                                                 flt_q_valid_ur_err ;
      logic [4:0]                                       end2end_max;
      logic [NPRFX-1:0]                                 prfx_is_end;           // A received prefix is of type end to end 
      logic [NPRFX-1:0]                                 prfx_is_local;         // A received prefix is of type local
      logic [NPRFX-1:0]                                 prfx_type_msb;         // Type[4] bit of prefix.
      logic [NPRFX-1:0]                                 prfx_fmt_msb;          // Fmt[2] bit of prefix.
      logic [4:0]                                       end_end_cnt;
      logic [1:0]                                       end2end_max_pf;
    logic [255:0]                                       pre_tlp_prfx_log;      // This bus must have max possible width = 8 x TLP Prefixes
    logic [159:0]                                       e2e_prfx_log;          // This bus must have max possible width = 8 x TLP Prefixes
    logic [127:0]                                       l_radm_tlp_prfx_log;   // 4 DWs stored in TLP Prefix log
  logic                                                 pipe_error_log_en;
  logic                                                 pipe_error_log_en_reg;
  logic                                                 error_log_pipe_en;
  logic                                                 error_log_pipe_en_ep;
  logic                                                 error_log_pipe_en_rc;
  logic [63:0]                                          extract_addr;
  // if RAS is not used this signal is set to 0
  logic                                                 update_destination_en;
  logic [NW-1:0]                                        extrct_dwen;
  logic                                                 extrct_dv;
  logic                                                 extrct_hv;
  logic                                                 extrct_eot;
  logic                                                 extrct_dllp_err;
  logic                                                 extrct_ecrc_err;          // Indicates current packet should be dropped because of tlp(aborted)
  logic                                                 extrct_malfm_tlp_err;     // Indicates current packet should be dropped because of tlp(aborted)
                                             
  logic                                                 max_pyld_err;
  logic                                                 tc_err;
  logic                                                 cpl  ;
  logic                                                 cpld  ;
  logic                                                 hdr_4dw;
  logic                                                 tlp_has_pyld;
  logic [1:0]                                           fc_type;
  logic [7:0]                                           hdr_err_ptr;
  logic [7:0]                                           extrct_malfm_tlp_err_ptr; // Indicates the detail of malformed for RASDES
  integer                                               j;
  logic                                                 hdr_len_mismatch;
  logic [6:0]                                           tlp_fmt_type;
  assign                                                tlp_fmt_type  = {fmt,hdr_type}; 
  logic [9:0]                                           tlp_dw_len;
 assign  tlp_dw_len    = { hdr_dec_flt_cpl_in.hdr_dec_flt_hdr[17:16], hdr_dec_flt_cpl_in.hdr_dec_flt_hdr[31:24]};
  logic [11:0]                                          int_addr_11_dt_0;
  logic [11:0]                                          addr_11_dt_0;
  logic                                                 int_extrct_hv;
  logic                                                 int_extrct_dv;
  logic [10:0]                                          pyld_dwcnt;
  logic [NW-1:0]                                        tmp_dwcnt;                                        
  logic                                                 cfg_tph_enable;
  logic                                                 valid_type;
  logic                                                 cpl_crs_err;
  logic                                                 dw_len_is0;
  logic [2:0]                                           curnt_struc_vc;
  logic [10:0]                                          tmp_dw_len;
  logic                                                 len_mismatch;
    logic                                               is_qw_aligned;
    logic                                               hdr_err;
      // --- Rx TLP Event flag for Ras D.E.S event counter
      logic                                             rx_tlp_evt_enable;
    logic [NW-1:0]                                      l_tmp_dwcnt;
    logic [10:0]                                        prev_pyld_dwcnt;
    logic                                               ecrc_len_mismatch;

    logic                                               int_flt_q_tlp_abort;              // flt_q - delayed version of l_flt_q_tlp_abort
      logic [4:0]                                       flt_q_dev_num;
    logic [DW+DATA_PAR_WD-1:0]                          chk_l_flt_q_data;
    logic                                               l_flt_data_parerr;
    logic                                               flt_q_unqual_dv;
    logic                                               flt_q_unqual_hv;
    logic                                               flt_q_unqual_eot;
    logic                                               latch_hdr_pipe_en;
    logic                                               flt_q_pipe_en;
    logic                                               cpl_req_id_match;
    logic                                               enable_mask_pois_if_trgt0_destination_rc;
    logic                                               flt_q_poisoned_discard_rc;
      logic                                             flt_q_outside_mem_range;
      //logic [N_FLT_MASK-1:0]                            cfg_filter_rule_mask;           // PL reg outputs to control the selection of filter rules that are designed in radm_filter*
      logic                                             l_set_radm_rcvd_acs_err;
      logic                                             set_radm_rcvd_acs_err;
    logic [DW+DATA_PAR_WD-1:0]                          chk_l_flt_q_data_rc;
    logic [4:0]                                         flt_q_dev_num_rc;
    logic                                               flt_q_unqual_dv_rc;
    logic                                               flt_q_unqual_hv_rc;
    logic                                               flt_q_unqual_eot_rc;
    logic                                               latch_hdr_pipe_en_rc;
    logic                                               l_flt_data_parerr_rc;
    logic                                               flt_q_pipe_en_rc;
    logic                                               device_is_ep;
    logic                                               device_is_rc;
    logic                                               device_is_ep_int;
    logic                                               device_is_rc_int;
    logic      [5-1:0]                                  radm_hdr_log_err_index_c;
    logic                                               radm_hdr_log_vld_all_fn_c;
    logic                                               radm_hdr_log_vld_c ;

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

  assign radm_cfg_o.flt_cdm_pf = flt_q_func_num_d;
//// DM or EP Starts here 

    assign  flt_q_dev_num_ep             = flt_q_hdr_dw3[15:11];                         // for cfg transaction only
  
  // Used for cfg/msg/cpl only

  // Extract info from radm_cfg_tlp_i.cfg_bar_match and derive the bar number
  // (in_membar_range), the function number (raw_mem_func_num)
  // and the corresponding *bar_is_io vector.
    //


 // Following always block is not required for CPL

/*
    always_comb  begin : GET_MEM_BAR_PF_PROC
  
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
  
    always_comb  begin : GET_IO_BAR_PF_PROC
  
      in_iobar_range_unreg  = `RADM_OUTSIDE_MEMBAR;
      raw_io_func_num       = 0;
      shft_bar_is_io_unreg  = 0;
  
      for (int idx=0; idx<NF; idx=idx+1)
      beginin_membar_range_unreg
        if (|(radm_cfg_tlp_i.cfg_bar_match[(idx*6) +: 6] & radm_cfg_i.cfg_bar_is_io[idx*6 +: 6]))
          begin
            raw_io_func_num = idx;
            in_iobar_range_unreg      = get_bar_num((radm_cfg_tlp_i.cfg_bar_match[(idx*6) +: 6] & radm_cfg_i.cfg_bar_is_io[idx*6 +: 6]));
            shft_bar_is_io_unreg[5:0] = radm_cfg_i.cfg_bar_is_io[idx*6 +: 6];
          end
      end
    end
  */
  
    //
    // If PIPE_VF_INDEX==1, cfg_*match are anticipated by one cycle
    // and so are function and bar numbers.
    // We need to delay them in order to align to flt_q* domain
  

  // If a UR is due to a function specific error then the function number of the
  // targeted function is used in the Completer ID of the Completion TLP.
  // If a UR is due to a non-function specific error then the Completion is not
  // associated with a specific function within the device and the function
  // number is Reserved (i.e. the function number field of the Completer ID is
  // set to all 0s).
    assign  flt_q_func_num_ep          = flt_q_outrange_ur ? 0 : raw_flt_q_func_num;
    assign flt_q_pipe_en_ep            = radm_cfg_i.upstream_port && ((|l_flt_q_hv) || (|l_flt_q_dv)); // delay_n_w_enable should handle inside enable_delayed signal to flush the pipe
    assign  flt_q_poisoned_discard_ep  = flt_q_poisoned_err & !(radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_UR_POIS]);
    assign latch_hdr_pipe_en_ep        = radm_cfg_i.upstream_port && (ord_flt_data_cpl_in.ord_flt_dv | hdr_dec_flt_cpl_in.hdr_dec_flt_hv); 
    assign app_req_retry_en_tmp        =  int_app_req_retry_en  || ((raw_flt_q_func_num < NF) && int_app_pf_req_retry_en[raw_flt_q_func_num[ALT_PF_WD-1:0]])
 ;
    assign  flt_q_cpl_status_ep        = (((int_flt_q_destination[1:0] == `FLT_DESTINATION_TRGT0) && app_req_retry_en_tmp ) ? `CRS_CPL_STATUS:
                                            ((int_flt_q_destination[1:0] == `FLT_DESTINATION_TRGT0) && app_req_retry_en_tmp) ? `UR_CPL_STATUS   :
                                            flt_q_actual_cpl_status);

    assign chk_l_flt_q_data_ep  = l_flt_q_data;
    assign l_flt_data_parerr_ep = 1'b0;

    // CTRL_registers_path
    always_ff @(posedge core_clk or negedge core_rst_n)
    begin  
      if (!core_rst_n) begin
        flt_q_unqual_dv_ep  <= #TP 0;
        flt_q_unqual_hv_ep  <= #TP 0;
        flt_q_unqual_eot_ep <= #TP 0;
      end else if(radm_cfg_i.upstream_port) begin
        flt_q_unqual_dv_ep  <= #TP ord_flt_data_cpl_in.ord_flt_dv;
        flt_q_unqual_hv_ep  <= #TP hdr_dec_flt_cpl_in.hdr_dec_flt_hv;
        flt_q_unqual_eot_ep <= #TP ord_flt_data_cpl_in.ord_flt_eot;
      end
    end


      logic flt_q_mismatch_func_num;
      assign  flt_q_mismatch_func_num  = (flt_q_cfg_func_num   > radm_cfg_i.cfg_max_func_num);

        assign  flt_q_func_mismatch         = flt_q_mismatch_func_num;
      assign pf = flt_q_cfg_func_num;
      assign raw_func_num_unreg   = flt_q_REQID[PF_WD-1:0]; //completions

  
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
      .din        ({raw_func_num_unreg
                    }),
      .dout       ({raw_flt_q_func_num   
                   })
    );


//// DM or EP Ends here 

//// DM or RC Starts here 
  

        assign            radm_cfg_o.radm_drs_msg        = 'd0;
        assign            radm_cfg_o.radm_frs_msg        = 'd0;
        assign            radm_cfg_o.radm_frs_msg_reason = 'd0;  //req id already input above
       assign radm_cfg_o.radm_msg_ltr_latency     =  0; 
       assign radm_cfg_o.radm_msg_ltr             =  0; 

    assign flt_q_func_num_rc         = `CX_RC_FUNC_NUM;
      
    assign chk_l_flt_q_data_rc  = l_flt_q_data;
    assign l_flt_data_parerr_rc = 1'b0;
    
      assign  flt_q_cpl_tlp           = (({flt_q_fmt,flt_q_type} == `CPLLK) || ({flt_q_fmt,flt_q_type} == `CPLDLK) ||
                                         ({flt_q_fmt,flt_q_type} == `CPL)   || ({flt_q_fmt,flt_q_type} == `CPLD));
      assign  acs_src_valid           = (flt_q_cpl_tlp) ? 1: ((((flt_q_REQID[15:8] < radm_cfg_i.cfg_2ndbus_num[7:0]) || (flt_q_REQID[15:8] > radm_cfg_i.cfg_subbus_num[7:0])) ) && (radm_cfg_i.cfg_acs_validation_cap & radm_cfg_i.cfg_acs_validation_en)) ? 0 : 1;              // If acs_src_valid == 0, an ACS Violation Error is generated
      
    
    // CTRL_registers_path
    always_ff @(posedge core_clk or negedge core_rst_n)
    begin  
      if (!core_rst_n) begin
        flt_q_unqual_dv_rc  <= #TP 0;
        flt_q_unqual_hv_rc  <= #TP 0;
        flt_q_unqual_eot_rc <= #TP 0;
      end else if(!radm_cfg_i.upstream_port) begin
        flt_q_unqual_dv_rc  <= #TP ord_flt_data_cpl_in.ord_flt_dv;
        flt_q_unqual_hv_rc  <= #TP hdr_dec_flt_cpl_in.hdr_dec_flt_hv;
        flt_q_unqual_eot_rc <= #TP ord_flt_data_cpl_in.ord_flt_eot;
      end
    end

  
    assign  flt_q_cpl_status_rc = `SU_CPL_STATUS;
    assign latch_hdr_pipe_en_rc = !radm_cfg_i.upstream_port && (ord_flt_data_cpl_in.ord_flt_dv | hdr_dec_flt_cpl_in.hdr_dec_flt_hv); 
    
      assign cpl_req_id_match   = 1'b1;
    
      assign enable_mask_pois_if_trgt0_destination_rc = 1;
    
      assign  flt_q_poisoned_discard_rc  = flt_q_poisoned_err & !(radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_UR_POIS] & enable_mask_pois_if_trgt0_destination_rc) ;
    

    assign flt_q_pipe_en_rc = !radm_cfg_i.upstream_port && ((|l_flt_q_hv) || (|l_flt_q_dv)); // delay_n_w_enable should handle inside enable_delayed signal to flush the pipe

//// DM or RC Ends here 

      assign  radm_cfg_o.radm_rcvd_acs_err  = device_is_rc ? set_radm_rcvd_acs_err : 0 ;
    

    assign flt_q_dev_num      = device_is_rc ? 'd0     : flt_q_dev_num_ep;
    assign chk_l_flt_q_data   = device_is_rc ? chk_l_flt_q_data_rc  : chk_l_flt_q_data_ep;
    assign l_flt_data_parerr  = device_is_rc ? l_flt_data_parerr_rc : l_flt_data_parerr_ep;
    assign flt_q_unqual_dv    = device_is_rc ? flt_q_unqual_dv_rc   : flt_q_unqual_dv_ep;
    assign flt_q_unqual_hv    = device_is_rc ? flt_q_unqual_hv_rc   : flt_q_unqual_hv_ep; 
    assign flt_q_unqual_eot   = device_is_rc ? flt_q_unqual_eot_rc  : flt_q_unqual_eot_ep;
    assign latch_hdr_pipe_en  = device_is_rc ? latch_hdr_pipe_en_rc : latch_hdr_pipe_en_ep;
    assign flt_q_pipe_en      = device_is_rc ? flt_q_pipe_en_rc     : flt_q_pipe_en_ep;
    assign flt_q_cpl_status   = device_is_rc ? flt_q_cpl_status_rc  : flt_q_cpl_status_ep;
    assign flt_q_func_num     = device_is_rc ? flt_q_func_num_rc    : flt_q_func_num_ep;
    assign error_log_pipe_en  = device_is_ep ? error_log_pipe_en_ep : error_log_pipe_en_rc;           

  
  // SANJAY  
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

  
  assign  radm_cfg_o.int_radm_pm_pme  = 1'b0;                         // PME should not be received by endpoint device
  assign  flt_q_cpl_abort             = lut_filt_cpl_abort;              // PME should not be received by endpoint device

  assign  radm_rcvd_req_ca_int        = 1'b0;                             // PME should not be received by endpoint device
  assign  radm_rcvd_req_ur_int        = {NF{1'b0}};                             // PME should not be received by endpoint device
  assign  radm_rcvd_wreq_poisoned_int = {NF{1'b0}};                             // PME should not be received by endpoint device
  assign  radm_cfg_o.radm_pm_to_ack   = 1'b0;                            // to ack should not be received by EP



  always_ff @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n)
      int_app_req_retry_en    <= #TP 0;
    else
      int_app_req_retry_en    <= #TP app_req_retry_en;

  always_ff @(posedge core_clk or negedge core_rst_n) begin: APP_PF_REQ_RETRY
    if (!core_rst_n) begin
      int_app_pf_req_retry_en         <= #TP 0;
    end else begin
      for (int j=0; j<NF; j=j+1) begin
        int_app_pf_req_retry_en[j]    <= #TP app_pf_req_retry_en[j];
      end // for j
    end
  end
  // aux logic to indicate a protection error has been detected at the output of the delay module
  // if the delay is 0 then there is no check and hence no error
   

  assign flt_q_data_o_cpl.flt_q_parerr = int_flt_q_parerr | l_flt_q_header_d_prot_err;
  // DPP checker for header input
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
                
                .valid_in (hdr_dec_flt_cpl_in.hdr_dec_flt_hv         ),
                .din      (hdr_dec_flt_cpl_in.hdr_dec_flt_hdr[HW_NFT-1:0]),
                .din_prot (hdr_dec_flt_cpl_in.hdr_dec_flt_hdr[HW_NFT+HW_NFT_PAR-1:HW_NFT]),
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

  assign chk_prfxHdr_flt_hdr      = hdr_dec_flt_cpl_in.hdr_dec_flt_hdr;

  assign  hdr_dw1                   = chk_prfxHdr_flt_hdr[31:0];
  assign  hdr_dw2                   = chk_prfxHdr_flt_hdr[63:32];
  assign  hdr_dw3                   = chk_prfxHdr_flt_hdr[95:64];
  assign  hdr_dw4                   = chk_prfxHdr_flt_hdr[127:96];
  assign  hdr_type                  = hdr_dw1[4:0];
  assign  fmt                       = hdr_dw1[6:5];
  assign  fmt2                      = hdr_dw1[7];
    assign  attr                    = {hdr_dw1[10],hdr_dw1[21:20]};
  assign  tlp_w_pyld                = hdr_dw1[6];           // Supported PCIe format only
  assign  cpl_tlp                   = (({fmt,hdr_type} == `CPLLK) || ({fmt,hdr_type} == `CPLDLK) ||
                                      ({fmt,hdr_type} == `CPL)    || ({fmt,hdr_type} == `CPLD) || fm_cpl_rsvd[1] ) && pcie_format;

  assign  tlp_type      = ({cpl_tlp,2'b00});              //sync with rtlh time domain


  //SANJAY 
    assign  pcie_valid_tc           = 1'b1;
    assign  pcie_format             = 1'b1;

    assign  ats                     = hdr_dw1[19:18];
  assign  dw_len                    = {hdr_dw1[17:16], hdr_dw1[31:24]};   // Supported PCIe format only
  assign  radm_cfg_o.tlp_poisoned   = hdr_dw1[22] & pcie_format;
  assign  td                        = hdr_dw1[23];
  assign  tc                        = hdr_dw1[14:12];
  
  assign  first_be                  = hdr_dw2[27:24];
  assign  last_be                   = hdr_dw2[31:28];
  assign  dwlenEq1                  = (dw_len[0] & (!(|dw_len[9:1])));    // dw_len == 10'b01
  assign  radm_cfg_o.flt_dwlenEq0   = !(|dw_len);                         // dw_len == 10'b0
  assign  flt_dwlenEq0              = radm_cfg_o.flt_dwlenEq0; 
  
  assign  cpl_status                = hdr_dw2[23:21];
  
  assign  cpl_bcm                   = hdr_dw2[20];

  always_ff @(posedge core_clk or negedge core_rst_n) begin:  LATCH_TLP_TYPE_PROCESS
    if(!core_rst_n)
    begin
      l_flt_q_tlp_type          <= #TP 3'b000;          // delayed to be sync with q time domain
    end
    else
    begin
      // l_flt_q_tlp_type[CPL_TYPE]<= #TP tlp_type[CPL_TYPE];
      l_flt_q_tlp_type           <= #TP tlp_type;
    end
  end

  //
  // [ ----------------  sync with q time domain  -----------------------]
  //
    assign  flt_q_attr              = {flt_q_hdr_dw1[10],flt_q_hdr_dw1[21:20]};
    assign  flt_q_tc                = flt_q_hdr_dw1[14:12];
    assign  flt_q_TAG               = flit_mode ? flt_q_14Bit_tag  : {4'h0,flt_q_hdr_dw1[15], flt_q_hdr_dw1[11], flt_q_hdr_dw2[23:16]}; 
  assign  flt_q_REQID               = (flt_q_cpl_w_lock | flt_q_cpl_wo_lock) ? {flt_q_hdr_dw3[7:0],flt_q_hdr_dw3[15:8]} : {flt_q_hdr_dw2[7:0],flt_q_hdr_dw2[15:8]};
  assign  flt_q_dw_len              = {flt_q_hdr_dw1[17:16], flt_q_hdr_dw1[31:24]};
  assign  flt_q_type                = flt_q_hdr_dw1[4:0];
  assign  flt_q_fmt                 = flt_q_hdr_dw1[6:5];
  assign  flt_q_fmt2                = flt_q_hdr_dw1[7]; // second [2] bit of FMT field used to detect reserved TLP in FLIT mode 
  assign  flt_q_cplid               = {flt_q_hdr_dw2[7:0],flt_q_hdr_dw2[15:8]};


  assign  flt_q_cpl_w_lock          = (({flt_q_fmt,flt_q_type}  == `CPLLK)   ||  ({flt_q_fmt,flt_q_type} == `CPLDLK)) && flt_q_pcie_format;
  assign  flt_q_cpl_wo_lock         = (({flt_q_fmt,flt_q_type}  == `CPL)     ||  ({flt_q_fmt,flt_q_type} == `CPLD))   && flt_q_pcie_format;
  assign  flt_q_invalid_tlp         =  !flt_q_cpl_w_lock & !flt_q_cpl_wo_lock & !fm_cpl_rsvd_r[1];
      assign  flt_q_invalid_prfx    = flt_q_prfx_type_error | flt_q_prfx_end_end_max_err | flt_q_prfx_local_after_end_err; // Invalid prefix when prefix rules not met.

  // `ifdef CX_CCIX_INTERFACE_ENABLE
  // assign  flt_q_ccix_fmt_err      = flt_q_ccix_valid_tc
  //                                && ( (flt_q_hdr_dw0_rsvd[0]==1'b1)
  //   `ifdef CX_TLP_PREFIX_ENABLE
  //                                  || (chk_flt_q_prfx[PRFX_W_PAR-PRFX_PROT_WD-1:0]>{PRFX_W_PAR-PRFX_PROT_WD{1'b0}}) // If CCIX TLPs with prefix are received
  //   `endif // CX_TLP_PREFIX_ENABLE
  //                                   ) ;
  // `endif // CX_CCIX_INTERFACE_ENABLE

    
//  `ifdef // CX_IS_RC
//assign  flt_q_func_mismatch     = (flt_q_cfg_func_num  > NF_wire);
//  `endif // CX_IS_RC
//SANJAY  

    assign  flt_q_td_hdr_log        = flt_q_hdr_dw1[23]; // Assigned without masking
    assign  flt_q_td                = 
                                        radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_UNMASK_TD] ? flt_q_hdr_dw1[23] : 1'b0;

  assign  flt_q_poisoned            = flt_q_hdr_dw1[22];
  assign  flt_q_poisoned_err        = (flt_q_poisoned && flt_q_pcie_format) || l_flt_q_tlp_poisoned; // Poisoned error detection with EP bit set in header or Flit marker poisoned error received in Flit mode. 
  assign  flt_q_addr64              = flt_q_hdr_dw1[5] && flt_q_pcie_format;
  assign  flt_q_first_be            = flt_q_hdr_dw2[27:24];
  assign  flt_q_last_be             = flt_q_hdr_dw2[31:28];
  
  assign  flt_q_cfg_func_num        = flt_q_hdr_dw3[(PF_WD-1)+8:8];                 // for cfg transaction only
  assign  flt_q_ext_reg_num         = flt_q_hdr_dw3[19:16];                         // for cfg transaction only
  assign  flt_q_reg_num             = flt_q_hdr_dw3[31:26];                         // for cfg transaction only
  assign  flt_q_rcvd_cpl_status     = flt_q_hdr_dw2[23:21];                         // for cpl receptions only
      
  assign  flt_q_status_sc           = (flt_q_rcvd_cpl_status == `SU_CPL_STATUS);    // Successful  Completion
  assign  flt_q_status_ca           = (flt_q_rcvd_cpl_status == `CA_CPL_STATUS);    // Completion  Abort
  assign  flt_q_status_crs          = (flt_q_rcvd_cpl_status == `CRS_CPL_STATUS);   // Request Retry Status
  assign  flt_q_status_ur           = !(flt_q_status_sc || flt_q_status_ca || 
                                                           flt_q_status_crs);       // 2.3.2 Completions with a Reserved Completion
                                                                                    // Status value are treated as if the Completion
                                                                                    // Status was Unsupported Request (UR)
  assign  flt_q_reserved_status     = !(flt_q_status_sc  || flt_q_rcvd_cpl_status == `UR_CPL_STATUS  || flt_q_status_ca  || flt_q_status_crs);
    
  assign  flt_q_cpl_reqid           = {flt_q_hdr_dw3[7:0], flt_q_hdr_dw3[15:8]};
  assign  flt_q_cpl_bcm             = flt_q_hdr_dw2[20];                            // for cpl receptions only
  assign  flt_q_rcvd_tlp_byte_cnt   = {flt_q_hdr_dw2[19:16], flt_q_hdr_dw2[31:24]};
    assign  flt_q_rcvd_cpl_tlp_tag  = flit_mode ? flt_q_14Bit_tag  : {4'h0,flt_q_hdr_dw1[15], flt_q_hdr_dw1[11], flt_q_hdr_dw3[23:16]}; 
  assign  flt_q_rcvd_tlp_low_addr   = flt_q_hdr_dw3[30:24];

  assign  flt_q_addr_byte7          = (flt_q_addr64) ? flt_q_hdr_dw3[7:0]   : 8'h00;
  assign  flt_q_addr_byte6          = (flt_q_addr64) ? flt_q_hdr_dw3[15:8]  : 8'h00;
  assign  flt_q_addr_byte5          = (flt_q_addr64) ? flt_q_hdr_dw3[23:16] : 8'h00;
  assign  flt_q_addr_byte4          = (flt_q_addr64) ? flt_q_hdr_dw3[31:24] : 8'h00;
  assign  flt_q_addr_byte3          = (flt_q_addr64) ? flt_q_hdr_dw4[7:0]   : flt_q_hdr_dw3[7:0];
  assign  flt_q_addr_byte2          = (flt_q_addr64) ? flt_q_hdr_dw4[15:8]  : flt_q_hdr_dw3[15:8];
  assign  flt_q_addr_byte1          = (flt_q_addr64) ? flt_q_hdr_dw4[23:16] : flt_q_hdr_dw3[23:16];
  assign  flt_q_addr_byte0          = (flt_q_addr64) ? flt_q_hdr_dw4[31:24] : flt_q_hdr_dw3[31:24];

  assign  flt_q_addr                = flt_q_addr_int;

    
  assign  flt_q_actual_cpl_status   =   ( flr_in_progress)  ? `UR_CPL_STATUS :  `SU_CPL_STATUS;
    

    assign flt_q_pcie_valid_tc      = 1'b1;
    assign flt_q_pcie_format        = 1'b1;
  //SANJAY1 
  // ---------------------------------------------------------------------------------------------------------


  assign flt_q_mask_wreq_poisoned_reporting     = (radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_UR_POIS] & (int_flt_q_destination == `FLT_DESTINATION_TRGT1));
  assign flt_q_mask_cpl_poisoned_reporting      = radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_POIS_ERROR_REPORTING];

    assign flt_q_outrange_ur  = 1'b0;

  // -----------------------------------------------------------------------------
  // TLP destination calculation
  // -----------------------------------------------------------------------------

  assign  flt_q_valid_ur_wo_poisn_err      = (flr_in_progress & !(flt_q_cpl_w_lock | flt_q_cpl_wo_lock) );
  assign  flt_q_valid_ur_err               = (flr_in_progress & !(flt_q_cpl_w_lock | flt_q_cpl_wo_lock) ) || ( flt_q_cpl_rcvd_ur || flt_q_hdr_ohc_err );

    // Per PCIe Base Spec: TLP Prefix Logging 6.2.4.4  -  "A Function that receives a TLP containing more End-End TLP Prefixes than are indicated by
    // the Function's Max End-End TLP Prefixes field must handle the TLP as an error and store the first 
    // overflow End-End TLP Prefix in the 1st DW of the Header Log register with the remainder of the Header Log register being undefined. "
    assign  l_radm_hdr_log          =  |ovrflw_end_end_prfx ? {flt_q_hdr_dw3,flt_q_hdr_dw2,flt_q_hdr_dw1,ovrflw_end_end_prfx} : {flt_q_hdr_dw4,flt_q_hdr_dw3,flt_q_hdr_dw2,flt_q_hdr_dw1};


    // Identify PASID prefix received
    // ------------------------------

    // Type field is in bits 4:0 of prefix.
    always_comb begin : extract_prefix_type
      for(int i = 0; i < NPRFX; i = i + 1) begin           // Repeat for every allocated prefix slot
        flt_q_prfx_type[(5*i) +: 5]  =  chk_flt_q_prfx[(32*i) +: 5];
      end
    end

    // Determine if a prefix type is reserved. Non-reserved includes ExtTPH, PASID, Vendor Defined and MRIOV.

    always_comb begin : detect_prefix_type
      for(int i = 0; i < NPRFX; i = i + 1) begin
        casez ({flt_q_prfx_type[5*i +: 5],flit_mode})
          6'b00000?, 6'b01110?, 6'b01111?, 6'b10000?, 6'b10001?, 6'b11110?, 6'b11111? : prfx_type_rsrvd[i] = 0;
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
        end_end_cnt = 0;
        for(int n = 0; n < NPRFX; n = n + 1) begin
          end_end_cnt = prfx_is_end[n] ? end_end_cnt + 1 : end_end_cnt;
        end
      end

      // Report error if more than 4 End-End TLP Prefixes received in one TLP. Check
      // is performed based on the function number.
      
      always_comb begin : end_2_end_max_prfxs
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

      always_comb begin : detect_local_after_end_end_prefix
        flt_q_prfx_local_after_end_err     = 1'b0;
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


  assign {tmp_mlf_err_ptr, tmp_mlf_err} = flt_q_rtlh_abort         ? {flt_q_rtlh_abort_ptr, 1'b1} :
                                          flt_q_invalid_tlp        ? {`MFPTR_TLP_TYP      , 1'b1} :
                                          flt_q_cpl_mlf_err        ? {`MFPTR_CPL          , 1'b1} :
                                          flt_q_msg_mlf_err        ? {`MFPTR_MSG_TC0      , 1'b1} :
                                            flt_q_invalid_prfx     ? {`MFPTR_PFX          , 1'b1} :
                                                                     {`MFPTR_NO_ERR       , 1'b0} ;

  always_comb  begin: set_err_PROC
    l_set_radm_rcvd_req_ca              = 1'b0;
    l_set_radm_rcvd_cpl_poisoned        = 1'b0;
    l_set_radm_rcvd_req_ur              = 1'b0;
    l_set_radm_rcvd_wreq_poisoned       = 1'b0;
    l_set_radm_unexp_cpl_err            = 1'b0;
    l_set_radm_rcvd_cpl_ur              = 1'b0;
    l_set_radm_rcvd_cpl_ca              = 1'b0;
    l_set_radm_hdr_log_valid            = 1'b0;
    l_set_radm_ecrc_err                 = 1'b0;
    l_set_radm_mlf_tlp_err              = 1'b0;
      l_set_radm_mlf_tlp_err_ptr        = 8'd0;
    l_set_radm_rcvd_acs_err             = 1'b0;
  l_set_outrange_req_ur                 = 1'b0;
    // RTLH layer reported errors
    if (flt_q_unqual_eot && !rtlh_dllp_err_d  ) begin
      l_set_radm_ecrc_err               =  l_flt_q_ecrc_err & (!tmp_mlf_err);
      l_set_radm_mlf_tlp_err            =  tmp_mlf_err ;
        l_set_radm_mlf_tlp_err_ptr      =  tmp_mlf_err_ptr;
      l_set_radm_rcvd_cpl_poisoned      =  flt_q_poisoned_err & l_flt_q_tlp_type[CPL_TYPE] & (!l_flt_q_ecrc_err) & (!tmp_mlf_err) & (!flt_q_unexp_cpl_err) & 
                                          !flt_q_mask_cpl_poisoned_reporting;// design from spec. that poisoned is the lowest priority when only one error is allowed to reported, or not reported if the filter rule CX_FLT_MASK_POIS_ERROR_REPORTING is set
      l_set_radm_rcvd_wreq_poisoned     =  flt_q_poisoned_err & !l_flt_q_tlp_type[CPL_TYPE] & (!l_flt_q_ecrc_err) & (!tmp_mlf_err) & (!flt_q_valid_ur_wo_poisn_err)  &                             
                                          !flt_q_mask_wreq_poisoned_reporting;

      // filter detected errors for a received request
      // EP's CA generated for dwlen>1
      l_set_radm_rcvd_req_ca            =  !tmp_mlf_err & !l_flt_q_ecrc_err ;
      l_set_radm_rcvd_req_ur            =  flt_q_valid_ur_err & !tmp_mlf_err & !l_flt_q_ecrc_err
                                           ;
      l_set_outrange_req_ur             =  flt_q_outrange_ur;
      // filter detected errors for a received completion
      // remain_byte_err is inaccurate,  FIX is TBD
      l_set_radm_unexp_cpl_err          =  flt_q_unexp_cpl_err & !tmp_mlf_err ; // in lut module, unexpected error and mlf error are mutual exclusive, but low level MLF is not
      l_set_radm_rcvd_cpl_ur            =  flt_q_cpl_rcvd_ur ;  // priority assignment to keep core from reporting duplicated errors for completion is done in completion lookup module
      l_set_radm_rcvd_cpl_ca            =  flt_q_cpl_rcvd_ca ;

      // filter detected errors for a received message
      l_set_radm_hdr_log_valid          =  (l_flt_q_ecrc_err            ||
                                            tmp_mlf_err                 ||
                                            l_set_radm_rcvd_cpl_poisoned          ||
                                            flt_q_valid_ur_wo_poisn_err ||
                                            flt_q_valid_ur_err          ||
                                            flt_q_unexp_cpl_err         ||
                                            flt_q_cpl_rcvd_ur           ||
                                            flt_q_cpl_rcvd_ca
                                            );
        l_set_radm_rcvd_acs_err         =  !tmp_mlf_err & !l_flt_q_ecrc_err;
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


  assign error_log_pipe_en_ep = radm_cfg_i.upstream_port && (pipe_error_log_en | pipe_error_log_en_reg); //  to flush the ERROR pipe and set error only for a cycle.
  assign error_log_pipe_en_rc = !radm_cfg_i.upstream_port && (pipe_error_log_en | pipe_error_log_en_reg); //  to flush the ERROR pipe and set error only for a cycle.

  delay_n_w_enable
  
  #(
    .N          (ERROR_LOG_PIPE_DELAY ), 
    .WD         (ERROR_LOG_PIPEWIDTH  )
  ) u_error_log_pipeline (
    .clk        (core_clk             ),
    .rst_n      (core_rst_n           ),
    .clear      (1'b0                 ),
    .en         (error_log_pipe_en    ),
    .din        ({  l_radm_hdr_log
                    ,l_radm_tlp_prfx_log
                    ,l_set_radm_rcvd_req_ca, l_set_radm_rcvd_cpl_poisoned
                    ,l_set_radm_rcvd_req_ur 
                    ,l_set_radm_unexp_cpl_err, l_set_radm_rcvd_cpl_ur
                    ,l_set_radm_rcvd_cpl_ca, l_set_radm_ecrc_err
                    ,l_set_radm_rcvd_acs_err

                    ,l_set_radm_mlf_tlp_err, l_set_radm_hdr_log_valid
                    ,flt_q_func_num

                      ,l_set_radm_mlf_tlp_err_ptr
                      ,l_set_outrange_req_ur
                  }),
      .dout       ({  radm_cfg_o.radm_hdr_log
                      ,radm_cfg_o.radm_tlp_prfx_log
                      ,set_radm_rcvd_req_ca, set_radm_rcvd_cpl_poisoned
                      ,set_radm_rcvd_req_ur 
                      ,set_radm_unexp_cpl_err, set_radm_rcvd_cpl_ur
                      ,set_radm_rcvd_cpl_ca, set_radm_ecrc_err
                     ,set_radm_rcvd_acs_err

                      ,set_radm_mlf_tlp_err, set_radm_hdr_log_valid
                      ,flt_q_func_num_d


                      ,set_radm_mlf_tlp_err_ptr
                      ,set_outrange_req_ur
                  })
  );

  assign extract_addr = {flt_q_addr_byte7, flt_q_addr_byte6, flt_q_addr_byte5, flt_q_addr_byte4,
                         flt_q_addr_byte3, flt_q_addr_byte2, flt_q_addr_byte1, flt_q_addr_byte0};

  assign flt_q_hdr_o_cpl[1 +: ($bits(flt_cpl_hdr_o_s)-1)] = l_flt_q_header_d[1 +: ($bits(flt_cpl_hdr_o_s)-1)];
  assign flt_q_addr_int                 = extract_addr;

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
            l_flt_q_hv_reg[i]       <= #TP 0;
            l_flt_q_dv_reg[i]       <= #TP 0;
            l_flt_q_eot_reg[i]      <= #TP 0;
                cdm_core_in_dpc_reg[i] <= #TP 0;

          end
        end else begin
          for(i = 0; i < FLT_Q_PIPE_DELAY; i = i + 1) begin
            if(i==0) begin
              l_flt_q_hv_reg[i]    <= #TP l_flt_q_hv ;
              l_flt_q_dv_reg[i]    <= #TP l_flt_q_dv ;
              l_flt_q_eot_reg[i]   <= #TP l_flt_q_eot ;
                   cdm_core_in_dpc_reg[i] <= #TP radm_cfg_i.cdm_core_in_dpc;

            end else begin
              l_flt_q_hv_reg[i]    <= #TP l_flt_q_hv_reg[i-1] ;
              l_flt_q_dv_reg[i]    <= #TP l_flt_q_dv_reg[i-1] ;
              l_flt_q_eot_reg[i]   <= #TP l_flt_q_eot_reg[i-1]; 
                   cdm_core_in_dpc_reg[i] <= #TP cdm_core_in_dpc_reg[i-1];

            end
          end // for
        end
      end
      assign  flt_q_hdr_o_cpl.flt_q_hv   = l_flt_q_hv_reg[FLT_Q_PIPE_DELAY-1];
      assign  flt_q_data_o_cpl.flt_q_dv  = l_flt_q_dv_reg[FLT_Q_PIPE_DELAY-1];
      assign  flt_q_data_o_cpl.flt_q_eot = l_flt_q_eot_reg[FLT_Q_PIPE_DELAY-1];
      assign  flt_q_data_o_cpl.flt_q_tlp_abort = 
               cdm_core_in_dpc_reg[FLT_Q_PIPE_DELAY-1] ? |l_flt_q_eot_reg[FLT_Q_PIPE_DELAY-1] : 
               int_flt_q_tlp_abort;



    end else begin : gen_flt_q_pipe_delay_eq0
      assign  flt_q_hdr_o_cpl.flt_q_hv   = l_flt_q_hv;
      assign  flt_q_data_o_cpl.flt_q_dv  = l_flt_q_dv;
      assign  flt_q_data_o_cpl.flt_q_eot = l_flt_q_eot;
      assign  flt_q_data_o_cpl.flt_q_tlp_abort = 
               radm_cfg_i.cdm_core_in_dpc ? |l_flt_q_eot : 
               int_flt_q_tlp_abort;


    end
  endgenerate


  delay_n_w_enable
  
  #(
    .N          (FLT_Q_PIPE_DELAY   ), 
    .WD         (FLT_Q_PIPEWIDTH    )
  ) u_flt_q_pipeline  (
    .clk        (core_clk           ),
    .rst_n      (core_rst_n         ),
    .clear      (1'b0               ),
    .en         (flt_q_pipe_en      ),
    .din        ({
                  chk_l_flt_q_data,
                  l_flt_q_dllp_abort,
                    l_flt_q_tlp_poisoned,
                  l_flt_q_dwen,
                  1'b0,
                  l_flt_q_parerr,
                  l_flt_q_header,
                  l_flt_q_tlp_abort,
                  radm_hdr_log_err_index_c,
                  radm_hdr_log_vld_all_fn_c,
                  radm_hdr_log_vld_c
                  }),
    .dout       ({
                  flt_q_data_o_cpl.flt_q_data,
                  flt_q_data_o_cpl.flt_q_dllp_abort,
                  
                      flt_q_data_o_cpl.flt_q_tlp_poisoned,
                  flt_q_data_o_cpl.flt_q_dwen,
                  flt_q_data_o_cpl.flt_q_ecrc_err,
                  int_flt_q_parerr,
                  l_flt_q_header_d,
                  int_flt_q_tlp_abort,
                  //flt_q_data_o_cpl.flt_q_tlp_abort,
                  flt_q_data_o_cpl.radm_hdr_log_err_index,
                  flt_q_data_o_cpl.radm_hdr_log_vld_all_fn,
                  flt_q_data_o_cpl.radm_hdr_log_vld
                  })

  );


    assign l_flt_q_header_d_prot_err  = 1'b0;
    assign chk_l_flt_q_header_d       = l_flt_q_header_d.flt_q_hdr;


  /////////////////////////////////////////////////////////////////////////
  // Error indications for Cdm
  /////////////////////////////////////////////////////////////////////////
  //assign  radm_rcvd_cpl_poisoned_int             = route_error_to_func( set_radm_rcvd_cpl_poisoned  , flt_q_func_num_d);
  //assign  radm_rcvd_cpl_ur_int                   = route_error_to_func( set_radm_rcvd_cpl_ur        , flt_q_func_num_d);
  //assign  radm_rcvd_cpl_ca_int                   = route_error_to_func( set_radm_rcvd_cpl_ca        , flt_q_func_num_d);
  assign  radm_hdr_log_valid_int                 =                                                    (set_radm_ecrc_err | set_radm_mlf_tlp_err | set_outrange_req_ur | set_radm_unexp_cpl_err) ? {NF{set_radm_hdr_log_valid}} :
                                                                                                             route_error_to_func( set_radm_hdr_log_valid , flt_q_func_num_d);
  //assign radm_cfg_o.radm_ecrc_err                = {NF{set_radm_ecrc_err}};
  //assign radm_cfg_o.radm_mlf_tlp_err             = {NF{set_radm_mlf_tlp_err}};

  //
  assign  radm_rcvd_cpl_poisoned_int             = set_radm_rcvd_cpl_poisoned;
  assign  radm_rcvd_cpl_ur_int                   = set_radm_rcvd_cpl_ur      ;
  assign  radm_rcvd_cpl_ca_int                   = set_radm_rcvd_cpl_ca      ;
//  assign  radm_hdr_log_valid_int                 = `ifdef CX_IDE_ENABLE 
//                                                    (set_radm_ide_check_failed_to_report | set_radm_ide_pcrc_failed | set_radm_ide_misrouted) ? set_radm_hdr_log_valid : 
//                                                   `endif 
//                                                    (set_radm_ecrc_err | set_radm_mlf_tlp_err | set_outrange_req_ur | set_radm_unexp_cpl_err) ? set_radm_hdr_log_valid :
//                                                                                                             set_radm_hdr_log_valid;
  assign radm_cfg_o.radm_ecrc_err                = set_radm_ecrc_err;
  assign radm_cfg_o.radm_mlf_tlp_err             = set_radm_mlf_tlp_err;                                                   
    assign radm_cfg_o.radm_mlf_tlp_err_ptr       = set_radm_mlf_tlp_err_ptr;
  //assign radm_cfg_o.radm_unexp_cpl_err           = {NF{set_radm_unexp_cpl_err}};  // Non function specific error (PCIe 1.1 C16 errata)
  assign radm_cfg_o.radm_unexp_cpl_err           = set_radm_unexp_cpl_err;  // Non function specific error (PCIe 1.1 C16 errata)
    assign radm_cfg_o.radm_rcvd_req_ca           = radm_rcvd_req_ca_int;
    assign radm_cfg_o.radm_rcvd_req_ur           = radm_rcvd_req_ur_int;
    assign radm_cfg_o.radm_rcvd_cpl_poisoned     = radm_rcvd_cpl_poisoned_int;
    assign radm_cfg_o.radm_rcvd_wreq_poisoned    = radm_rcvd_wreq_poisoned_int;
    assign radm_cfg_o.radm_rcvd_cpl_ur           = radm_rcvd_cpl_ur_int;
    assign radm_cfg_o.radm_rcvd_cpl_ca           = radm_rcvd_cpl_ca_int;
    assign radm_cfg_o.radm_hdr_log_valid         = radm_hdr_log_valid_int;


  always_comb  begin:  FILTER_PROCESS   
    int_flt_q_destination           = `FLT_DESTINATION_TRASH;           // DEFAULT to trash
    if (flt_q_invalid_tlp) begin
      int_flt_q_destination         = `FLT_DESTINATION_TRASH;
    end else begin
      if  (l_flt_q_tlp_type[CPL_TYPE]) begin                              // [-------------- CPL ---------------]
         // if (flt_q_cpl_abort)
         //   int_flt_q_destination     = `FLT_DESTINATION_TRASH;           
         // else  
            int_flt_q_destination     = `FLT_DESTINATION_TRGT1;           
      end
    end
  end

  // -----------------------------------------------------------------------------
  // output drives
  // -----------------------------------------------------------------------------

  always_ff @(posedge core_clk or negedge core_rst_n) begin: LATCH_HDR_PROCESS
    if(!core_rst_n)
    begin
      l_flt_q_data                  <= #TP 0;
      l_flt_q_dwen                  <= #TP 0;
      l_flt_q_ecrc_err              <= #TP 0;
      flt_q_cpl_mlf_err             <= #TP 0;
      flt_q_msg_mlf_err             <= #TP 0;
      l_flt_q_unexp_cpl_err         <= #TP 0;
      flt_q_cpl_rcvd_ur             <= #TP 0;
      flt_q_cpl_rcvd_ca             <= #TP 0;
      flt_q_rtlh_abort              <= #TP 0;
      flt_q_rtlh_abort_ptr          <= #TP 0;
      l_flt_q_dllp_abort            <= #TP 0;
      rtlh_dllp_err_d               <= #TP 0;
      ord_flt_p_pkt_num_d            <= #TP 0;
      l_flt_q_tlp_poisoned        <= #TP 1'b0;
      flt_q_hdr_dw1                 <= #TP 0;
      flt_q_hdr_dw2                 <= #TP 0;
      flt_q_hdr_dw3                 <= #TP 0;
      flt_q_hdr_dw4                 <= #TP 0;
      flt_q_hdr_ohc_err             <= #TP 'd0;
      flt_q_hdr_dec_flt_cpltr_seg   <= #TP 'd0;
      flt_q_hdr_dec_flt_dest_seg    <= #TP 'd0;
      flt_q_14Bit_tag               <= #TP 0;
      l_flt_q_log_rcvd_flds         <= #TP '0 ;
      flt_q_vc_select               <= #TP 0;
      l_flt_q_parerr                <= #TP 0;
        flt_q_prfx                  <= #TP 0;
        l_flt_q_np_req_type       <= #TP 0;
    end
    else if (latch_hdr_pipe_en)
    begin
      l_flt_q_data                  <= #TP ord_flt_data_cpl_in.ord_flt_data;
      l_flt_q_dwen                  <= #TP ord_flt_data_cpl_in.ord_flt_dwen;
      l_flt_q_dllp_abort            <= #TP ord_flt_data_cpl_in.ord_flt_dllp_err;
      rtlh_dllp_err_d               <= #TP ord_flt_data_cpl_in.ord_flt_dllp_err;
      ord_flt_p_pkt_num_d           <= #TP ord_flt_data_cpl_in.ord_flt_p_pkt_num;
      l_flt_q_tlp_poisoned          <= #TP ord_flt_data_cpl_in.ord_flt_poisoned;
        {flt_q_rtlh_abort_ptr, flt_q_rtlh_abort}  <= #TP {extrct_malfm_tlp_err_ptr, extrct_malfm_tlp_errsts};
      l_flt_q_ecrc_err          <= #TP radm_ecrc_err_int;
      flt_q_cpl_mlf_err         <= #TP cpl_tlp & cpl_mlf_err;
      flt_q_msg_mlf_err         <= #TP 1'b0;
  
      l_flt_q_unexp_cpl_err     <= #TP (cpl_tlp & unexpected_cpl_err); // not from completion lookup table
      flt_q_cpl_rcvd_ur         <= #TP cpl_tlp & cpl_ur_err;
      flt_q_cpl_rcvd_ca         <= #TP cpl_tlp & cpl_ca_err;
      flt_q_hdr_dw1             <= #TP chk_prfxHdr_flt_hdr[31:0];
      flt_q_hdr_dw2             <= #TP chk_prfxHdr_flt_hdr[63:32];
      flt_q_hdr_dw3             <= #TP chk_prfxHdr_flt_hdr[95:64];
      flt_q_hdr_dw4             <= #TP chk_prfxHdr_flt_hdr[127:96];
      flt_q_hdr_ohc_err           <= #TP hdr_dec_flt_cpl_in.hdr_dec_flt_c_d_r_14bit_t[51];
      flt_q_hdr_dec_flt_cpltr_seg <= #TP hdr_dec_flt_cpl_in.hdr_dec_flt_c_d_r_14bit_t[39:32];
      flt_q_hdr_dec_flt_dest_seg  <= #TP hdr_dec_flt_cpl_in.hdr_dec_flt_c_d_r_14bit_t[31:23];
      flt_q_14Bit_tag           <= #TP hdr_dec_flt_cpl_in.hdr_dec_flt_c_d_r_14bit_t[13:0];
      l_flt_q_log_rcvd_flds       <= #TP hdr_dec_flt_cpl_in.log_rcvd_flds ;
      flt_q_vc_select           <= #TP q_select_from_tc(radm_cfg_i.cfg_tc_struc_vc_map, tc);
      l_flt_q_parerr            <= #TP rtlh_radm_parerr_int | l_flt_data_parerr;
      flt_q_prfx                <= #TP hdr_dec_flt_cpl_in.hdr_dec_flt_prfx;
      l_flt_q_np_req_type       <= #TP hdr_dec_flt_cpl_in.hdr_dec_np_req_type;
    end
  end

  assign  l_flt_q_tlp_abort         = (flt_q_cpl_abort | flt_q_rtlh_abort | flt_q_msg_mlf_err | flt_q_invalid_prfx
                                    ) & flt_q_unqual_eot;

  assign  l_flt_q_hv                = (flt_q_unqual_hv);
  assign  l_flt_q_dv                = (flt_q_unqual_dv);
  assign  l_flt_q_eot               = (flt_q_unqual_eot);


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

  assign fm_cpl_rsvd  = f_tlp_is_fm_cpl_rsvd(mode_e'(flit_mode), tlp_hdr_pkt);

  always @(posedge core_clk or negedge core_rst_n)
  begin
    if(!core_rst_n) begin
      fm_cpl_rsvd_r          <= #TP 2'b00;
    end else begin
      fm_cpl_rsvd_r        <= #TP fm_cpl_rsvd;
    end
  end

  // Unexpected CPL error when a completion received during pm block or CPL is not from CPL lookup table or reserved TLP received in FLIT mode 
  assign  flt_q_unexp_cpl_err       = l_flt_q_unexp_cpl_err || (l_flt_q_tlp_type[CPL_TYPE] & pm_block_tlp) ||    (fm_cpl_rsvd_r[1] & !tmp_mlf_err & !l_flt_q_ecrc_err) ;


      assign flr_pf_in_progress = 0;
      assign flr_vf_in_progress = 0;
  
  // In order to avoid dropping Messages which have the Routing Type set to, for example Broadcast,
  // we need to include only Messages with Routing ID = Route by ID;
  // so, if the TLP is a MSG TLP, only Routed by ID are affected by FLR in Progress:
  assign flr_in_progress = (flr_pf_in_progress | flr_vf_in_progress) && ((flt_q_type[4:3] != 2'b10) || (flt_q_type[2:0] == 3'b010)); 

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

  assign  radm_cfg_o.radm_rcvd_tlp_req_id = flt_q_REQID;
  
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
                .PROT_WD                 (FLT_CPL_HDR_PROT_WIDTH),
                .PARITY_MODE             (PARITY_MODE),        // cc
                .PROT_CORRECT_EN         (PROT_CORRECT_EN),    // cc
                .TOTAL_WIDTH             (FLT_CPL_HDR_WIDTH),             
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
                .din      ({compressed_hdr_gen_out[FLT_CPL_HDR_WIDTH:3] ,2'b00}),
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
    assign l_flt_q_header[FLT_CPL_HDR_WIDTH:1] = compressed_hdr_gen_out[FLT_CPL_HDR_WIDTH:1];
    assign l_flt_q_header.flt_q_hv    = 1'b0;
    

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
assign receiver_overflow = 1'b0;
    assign acs_err  = 1'b0;
  assign uncorrect_int_err = 1'b0;
  assign mc_blocked_tlp = 1'b0;
  assign atomic_op_egr_blked =  1'b0;
  assign tlp_prefix_blocked =  1'b0;
  assign poisoned_tlp_egr_blked =  1'b0;
  assign dmwr_request_egr_blked =  1'b0;
   assign ide_check_failed  = 1'b0;
   assign pcrc_check_failed = 1'b0;
   assign misrouted_ide_tlp = 1'b0;
 assign tlp_translation_egr_blked = 1'b0;


 assign  atomic_dmwr_trans_blked = atomic_op_egr_blked | dmwr_request_egr_blked | tlp_translation_egr_blked;
 assign  ur_unexp_cpl  = l_flt_q_unexp_cpl_err | flt_q_valid_ur_err;
 assign  poisoned_tlp  = poisoned_tlp_egr_blked | flt_q_poisoned_err;

assign radm_hdr_log_all_err = {poisoned_tlp_egr_blked,l_set_radm_rcvd_cpl_poisoned,pcrc_check_failed,flt_q_unexp_cpl_err, flt_q_cpl_rcvd_ca,flt_q_valid_ur_err,mc_blocked_tlp,acs_err, tlp_prefix_blocked,tlp_translation_egr_blked,dmwr_request_egr_blked, atomic_op_egr_blked,misrouted_ide_tlp,l_flt_q_ecrc_err,ide_check_failed,tmp_mlf_err,receiver_overflow, uncorrect_int_err};

 assign  radm_hdr_log_err_index_c  =  radm_hdr_log_err_index(radm_hdr_log_all_err);
 assign  radm_hdr_log_vld_c        =  l_set_radm_hdr_log_valid;

///////////////////////////////////////////////////////////////////
 // This logic is to detect HDR log should  report function specific or per function 
 // //////////////////////////////////////////////////////////////
 assign  radm_hdr_log_vld_all_fn_c        =  (l_flt_q_ecrc_err && !(ide_check_failed)) | tmp_mlf_err  | (flt_q_unexp_cpl_err && !(ide_check_failed||misrouted_ide_tlp))  ;
  


////////////////////////////////////////////////////////////////////////
 //

logic  ecrc_cpl_status; 
 
assign   ecrc_cpl_status = l_set_radm_ecrc_err && !(radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_MASK_CPL_ECRC_DISCARD ]);

//---------------------------------------------------------------------------------         
// compressed header generation module   
//---------------------------------------------------------------------------------

// fields that will be used from filter inside radm_compressed_hdr module to form compressed hdr
logic [PF_WD-1:0]  flt_q_func_num_c;
  assign flt_q_func_num_c   = flt_q_func_num;                  

compressed_hdr_gen_ctl_s compressed_hdr_gen_in;
radm_tlp_hdr_s           algn_rx_tlp_hdr, flt_rx_tlp_hdr, flt_rx_tlp_hdr_out;

assign compressed_hdr_gen_in.destination        = flt_q_destination;
assign compressed_hdr_gen_in.cpl_status         = '0;
assign compressed_hdr_gen_in.func_num_c         = flt_q_func_num_c;
assign compressed_hdr_gen_in.in_membar_range    = '0;
assign compressed_hdr_gen_in.rom_req_in_range_c = '0;
assign compressed_hdr_gen_in.io_req_in_range_c  = '0;
assign compressed_hdr_gen_in.cpl_last           = flt_q_cpl_last;
assign compressed_hdr_gen_in.np_req_type        = l_flt_q_np_req_type;
assign compressed_hdr_gen_in.hdr_log_valid      = '0;

// align input raw header with old input header interface to the filter after after ecrc extraction & address anticipation
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
  .COMPRESSED_HDR_TYPE(flt_cpl_hdr_o_s),
  .FC_TYPE(E_CPL)
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

/*  `ifdef CX_IS_DM_OR_RC
    function automatic [PF_WD:0] one_hot_decode_2_zero;
      input [NF-1:0]      one_hot_target;
      reg   [PF_WD-1:0]   encoded;
      reg                 target_eq_0;
      integer             i;
    
      begin
        // only function 0 is supported in RC mode
        encoded = 0;
        target_eq_0 = 1'b1;
        for (i=NF-1; i>=0 ; i=i-1) begin
          if(one_hot_target[i] == 1'b1) begin
            encoded     = i;
            target_eq_0 = 1'b0;
          end
        end
    
        one_hot_decode_2_zero = {encoded,target_eq_0};
      end
    endfunction
  `endif //CX_IS_DM_OR_RC
*/

/*  // Function to convert from a traffic class to a one-hot Q select
  function automatic [NVC-1:0] q_select_from_tc;
    input [23:0]    cfg_tc_struc_vc_map;  // TC to VC Structure mapping
    input [2:0]     tc;                   // Traffic class
    logic [2:0]     vc;
    logic [7:0]     full_NVC_q_select;
    begin

      case  (tc)
        3'b000:     vc = cfg_tc_struc_vc_map[ 2: 0];
        3'b001:     vc = cfg_tc_struc_vc_map[ 5: 3];
        3'b010:     vc = cfg_tc_struc_vc_map[ 8: 6];
        3'b011:     vc = cfg_tc_struc_vc_map[11: 9];
        3'b100:     vc = cfg_tc_struc_vc_map[14:12];
        3'b101:     vc = cfg_tc_struc_vc_map[17:15];
        3'b110:     vc = cfg_tc_struc_vc_map[20:18];
        3'b111:     vc = cfg_tc_struc_vc_map[23:21];
      endcase // case

      case  (vc)
        3'b000:     full_NVC_q_select  = 8'b00000001;
        3'b001:     full_NVC_q_select  = 8'b00000010;
        3'b010:     full_NVC_q_select  = 8'b00000100;
        3'b011:     full_NVC_q_select  = 8'b00001000;
        3'b100:     full_NVC_q_select  = 8'b00010000;
        3'b101:     full_NVC_q_select  = 8'b00100000;
        3'b110:     full_NVC_q_select  = 8'b01000000;
        3'b111:     full_NVC_q_select  = 8'b10000000;
      endcase // case
      q_select_from_tc = full_NVC_q_select[NVC-1:0];
    end
  endfunction // q_select_from_tc
*/

  //`ifdef SNPS_ASSERT_ON
  //`ifndef SYNTHESIS
  ////VCS coverage off
  //
  ////`CX_ASSERT_INTERFACE_PARAM(`CX_SVA_RADM, 0)
  //
  ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  //// System Verilog Assertions.
  ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  //
  //logic time0_gate_n;
  //logic sva_reset_n;
  //
  //assign sva_reset_n = time0_gate_n & core_rst_n;
  //// filter time 0 X propagation
  //initial begin
  //  time0_gate_n = 0;
  //  #1ns;
  //  time0_gate_n = 1;
  //end
  //
  //// <sva_cp name="bar_match_mutex"
  ////         category="CX_SVA_RADM"
  ////         owner="ericwitt"
  ////         status="implemented">
  ////   <sva_module> radm_filter_ep </sva_module>
  ////   <sva_short_description> Check that the bar matching is mutually exclusive </sva_short_description>
  ////   <sva_description>
  ////     Check that the bar matching is mutually exclusive
  ////   </sva_description>
  //// </sva_cp>
  //
  ////assert_zero_one_hot #( .width (6*NF),
  ////                        .msg ("Only one bit should be asserted in radm_cfg_tlp_i.cfg_bar_match at a time")
  ////                      )
  ////  a_cfg_bar_match_mutex (   .clk (sva_reset_n),
  ////                            .reset_n ((core_rst_n===1'b1)),
  ////                            .test_expr (radm_cfg_tlp_i.cfg_bar_match)
  ////                        );
  //
  //`ifdef CX_SRIOV_ENABLE
  //// <sva_cp name="vf_bar_match_mutex"
  ////         category="CX_SVA_RADM"
  ////         owner="ericwitt"
  ////         status="implemented">
  ////   <sva_module> radm_filter_ep </sva_module>
  ////   <sva_short_description> Check that the bar matching is mutually exclusive </sva_short_description>
  ////   <sva_description>
  ////     Check that the bar matching is mutually exclusive
  ////   </sva_description>
  //// </sva_cp>
  //
  //  assert_zero_one_hot #(    .width (NF*6),
  //                            .msg ("Only one bit should be asserted in radm_cfg_tlp_i.cfg_vf_bar_match at a time")
  //                        )
  //  a_cfg_vf_bar_match_mutex (.clk (sva_reset_n),
  //                            .reset_n ((core_rst_n===1'b1)),
  //                            .test_expr (radm_cfg_tlp_i.cfg_vf_bar_match)
  //                           );
  //// <sva_cp name="exclusive_bar_match"
  ////         category="CX_SVA_RADM"
  ////         owner="ericwitt"
  ////         status="implemented">
  ////   <sva_module> radm_filter_ep </sva_module>
  ////   <sva_short_description> radm_cfg_tlp_i.cfg_bar_match and radm_cfg_tlp_i.cfg_vf_bar_match shouldn't happen at the same time. </sva_short_description>
  ////   <sva_description>
  ////     radm_cfg_tlp_i.cfg_bar_match and radm_cfg_tlp_i.cfg_vf_bar_match shouldn't happen at the same time.
  ////   </sva_description>
  //// </sva_cp>
  //
  ///*
  //property p_exclusive_bar_match_ap ;
  //   @(posedge core_clk) disable iff (core_rst_n !== 1'b1) !(|(radm_cfg_tlp_i.cfg_bar_match & ~radm_cfg_i.cfg_bar_is_io) && |radm_cfg_tlp_i.cfg_vf_bar_match);
  //endproperty
  //
  //`CX_ASSERTION( p_exclusive_bar_match_ap, "radm_cfg_tlp_i.cfg_bar_match and radm_cfg_tlp_i.cfg_vf_bar_match shouldn't happen at the same time." )
  //*/
  //
  //// <sva_cp name="vfnumber_vfindex_match"
  ////         category="CX_SVA_RADM"
  ////         owner="takyamag"
  ////         status="implemented">
  ////   <sva_module> radm_filter_ep </sva_module>
  ////   <sva_short_description> VF number and VF Index is match when VF errors are detected. </sva_short_description>
  ////   <sva_description>
  ////     VF Index(radm_cfg_o.radm_vfindex) should indicates the appropriate value that are created from VF number(radm_cfg_o.radm_hdr_pf,radm_cfg_o.radm_hdr_vf) when VF errors are detected.
  ////   </sva_description>
  //// </sva_cp>
  //
  //logic [VFI_WD-1:0]    assertion_vfindex;
  //
  //pfvf_to_vfindex #(.REGOUT(0)) u_assertion_vfindex (
  //// ---- inputs ---------------
  //    .core_clk       (core_clk),
  //    .rst_n          (core_rst_n),
  //    .radm_cfg_i.pf_to_start_vfi_bus  (radm_cfg_i.pf_to_start_vfi_bus),
  //    .pf             (radm_cfg_o.radm_hdr_pf),
  //    .vf             ({1'b1,radm_cfg_o.radm_hdr_vf}),
  //// ---- outputs ---------------
  //    .vf_index       (assertion_vfindex)
  //);
  //
  //property p_vfnumber_vfindex_match_ap ;
  //   @(posedge core_clk) disable iff (core_rst_n !== 1'b1) 
  //       radm_cfg_o.radm_rcvd_req_ca_vf        | radm_cfg_o.radm_rcvd_req_ur_vf | radm_rcvd_cpl_poisoned_vf |
  //       radm_cfg_o.radm_rcvd_wreq_poisoned_vf | radm_rcvd_cpl_ur_vf | radm_rcvd_cpl_ca_vf        -> (assertion_vfindex == radm_cfg_o.radm_vfindex);
  //endproperty
  //
  //`CX_ASSERTION( p_vfnumber_vfindex_match_ap, "VF number and VF Index should match when VF errors are detected." )
  //
  //
  //property p_io_req;
  //@(posedge core_clk) disable iff (core_rst_n !== 1'b1)
  //  io_req |->(pfvf_func_num == raw_io_func_num);
  //endproperty
  //
  //`CX_ASSERTION(p_io_req, "Wrong Assignment to pfvf_func_num" ) 
  //
  //
  //`endif // CX_SRIOV_ENABLE
  //
  //
  ////VCS coverage on
  //property p_iobar_membar_overlap;
  //  @(posedge core_clk) disable iff (core_rst_n !== 1'b1)
  //  (|(radm_cfg_tlp_i.cfg_bar_match & ~radm_cfg_i.cfg_bar_is_io)) && (|(radm_cfg_tlp_i.cfg_bar_match & radm_cfg_i.cfg_bar_is_io)) && (flt_q_mem_req || flt_q_iord_req || flt_q_iowr_req);
  //endproperty
  //
  //cov_p_iobar_membar_overlap: cover property (p_iobar_membar_overlap);
  //
  //
  //
  //`ifdef CX_SRIOV_ENABLE
  //property p_iobar_vfbar_overlap;
  //  @(posedge core_clk) disable iff (core_rst_n !== 1'b1)
  //  (|radm_cfg_tlp_i.cfg_bar_match) && (|radm_cfg_tlp_i.cfg_vf_bar_match) && (flt_q_mem_req || flt_q_iord_req || flt_q_iowr_req);
  //endproperty
  //
  //cov_p_iobar_vfbar_overlap: cover property (p_iobar_vfbar_overlap);
  //
  //`endif // CX_SRIOV_ENABLE
  //
  //`endif // SYNTHESIS
  //`endif // SNPS_ASSERT_ON



  // Gen 6-COV SK : `ifndef SYNTHESIS
  // Gen 6-COV SK : //VCS coverage off
  // Gen 6-COV SK : always_ff @(posedge core_clk)
  // Gen 6-COV SK : begin
  // Gen 6-COV SK :     if (|l_flt_q_hv && radm_cfg_i.upstream_port)
  // Gen 6-COV SK :     begin
  // Gen 6-COV SK :         if (l_flt_q_tlp_type[P_TYPE] && (flt_q_destination == `FLT_DESTINATION_TRASH))
  // Gen 6-COV SK :             $display ("%t %m WARNING:  Posted transaction intended was TRASHED by RADM Filter", $time);
  // Gen 6-COV SK :         if (l_flt_q_tlp_type[CPL_TYPE] && (flt_q_destination == `FLT_DESTINATION_TRASH))
  // Gen 6-COV SK :             $display ("%t %m WARNING:  Completion transaction TRASHED by RADM Filter", $time);
  // Gen 6-COV SK :     end
  // Gen 6-COV SK : end
  // Gen 6-COV SK : logic    [8*5:0]         RADM_Q_DEST;
  // Gen 6-COV SK : logic    [8*5:0]         TARGET_MAP;
  // Gen 6-COV SK : logic    [8*9:0]         RADM_Q_VALID_TYPE;
  // Gen 6-COV SK : logic    [8*3:0]         RADM_Q_TLP_TYPE;
  // Gen 6-COV SK : 
  // Gen 6-COV SK : //  ENCODED valid type
  // Gen 6-COV SK : logic     [2:0]           flt_q_valid_type;
  // Gen 6-COV SK : always_comb(flt_q_valid_np or flt_q_valid_p or flt_q_valid_ur_np or flt_q_valid_ur_p)
  // Gen 6-COV SK : begin:  ENCODE_VALID_TYPE
  // Gen 6-COV SK :     case({flt_q_valid_ur_p,flt_q_valid_ur_np,flt_q_valid_p,flt_q_valid_np} )
  // Gen 6-COV SK :         4'b0001:    flt_q_valid_type = `FLT_VALID_NP_TYPE;
  // Gen 6-COV SK :         4'b0010:    flt_q_valid_type = `FLT_VALID_P_TYPE;
  // Gen 6-COV SK :         4'b0100:    flt_q_valid_type = `FLT_VALID_UR_NP_TYPE;
  // Gen 6-COV SK :         4'b1000:    flt_q_valid_type = `FLT_VALID_UR_P_TYPE;
  // Gen 6-COV SK :         default:    flt_q_valid_type = 3'b100; //
  // Gen 6-COV SK :     endcase //
  // Gen 6-COV SK : end
  // Gen 6-COV SK : 
  // Gen 6-COV SK : 
  // Gen 6-COV SK : assign  TARGET_MAP              =  ( target_acquisition == `FLT_DESTINATION_TRASH ) ? "trash"     :
  // Gen 6-COV SK :                                    ( target_acquisition == `FLT_DESTINATION_TRGT0 ) ? "TRGT0"     :
  // Gen 6-COV SK :                                    ( target_acquisition == `FLT_DESTINATION_TRGT1 ) ? "TRGT1"     : "bogus";
  // Gen 6-COV SK : 
  // Gen 6-COV SK : assign  RADM_Q_DEST             =  ( compressed_hdr_gen_out[ `FLT_Q_DESTINATION_RANGE ] == `FLT_DESTINATION_TRASH ) ? "trash"     :
  // Gen 6-COV SK :                                    ( compressed_hdr_gen_out[ `FLT_Q_DESTINATION_RANGE ] == `FLT_DESTINATION_TRGT0 ) ? "TRGT0"     :
  // Gen 6-COV SK :                                    ( compressed_hdr_gen_out[ `FLT_Q_DESTINATION_RANGE ] == `FLT_DESTINATION_TRGT1 ) ? "TRGT1"     :
  // Gen 6-COV SK :                                    ( compressed_hdr_gen_out[ `FLT_Q_DESTINATION_RANGE ] == `FLT_DESTINATION_CPL   ) ? "CPL"       : "bogus";
  // Gen 6-COV SK : 
  // Gen 6-COV SK : assign  RADM_Q_VALID_TYPE       =  ( flt_q_valid_type  == `FLT_VALID_NP_TYPE     ) ? "val_NP"    :
  // Gen 6-COV SK :                                    ( flt_q_valid_type  == `FLT_VALID_P_TYPE      ) ? "val_P"     :
  // Gen 6-COV SK :                                    ( flt_q_valid_type  == `FLT_VALID_UR_NP_TYPE  ) ? "val_UR_NP" :
  // Gen 6-COV SK :                                    ( flt_q_valid_type  == `FLT_VALID_UR_P_TYPE   ) ? "val_UR_P"  : "----";
  // Gen 6-COV SK : 
  // Gen 6-COV SK : 
  // Gen 6-COV SK : assign  RADM_Q_TLP_TYPE         =  ( l_flt_q_tlp_type == 3'b001 ) ? "P"  :
  // Gen 6-COV SK :                                    ( l_flt_q_tlp_type == 3'b010 ) ? "NP" :
  // Gen 6-COV SK :                                    ( l_flt_q_tlp_type == 3'b100 ) ? "CPL":
  // Gen 6-COV SK :                                    ( l_flt_q_tlp_type == 3'b000 ) ? "---": "BGS";
  // Gen 6-COV SK : //VCS coverage on
  // Gen 6-COV SK : 
  // Gen 6-COV SK :  `ifdef CX_RASDP_EN
  // Gen 6-COV SK :    logic [DW-1:0] ras_data;
  // Gen 6-COV SK :    logic [DATA_PAR_WD-1:0] ras_ecc;
  // Gen 6-COV SK :    assign ras_data = ord_flt_data_cpl[DW-1:0];
  // Gen 6-COV SK :    assign ras_ecc  = ord_flt_data_cpl[DW +: DATA_PAR_WD];
  // Gen 6-COV SK :  `endif // CX_RASDP_EN
  // Gen 6-COV SK :                                
  // Gen 6-COV SK : `ifdef SNPS_ASSERT_ON
  // Gen 6-COV SK : 
  // Gen 6-COV SK : logic check_flt_q_cpl_crs;
  // Gen 6-COV SK : logic [4:0] cov_cpl_crs;
  // Gen 6-COV SK : logic [2:0] cov_bins;
  // Gen 6-COV SK : 
  // Gen 6-COV SK : // CPL with CRS status
  // Gen 6-COV SK : assign check_flt_q_cpl_crs = (flt_q_cpl_status == `CRS_CPL_STATUS);
  // Gen 6-COV SK : assign cov_cpl_crs = {check_flt_q_cpl_crs, flt_q_cfg0rd_req, flt_q_cfg0wr_req, flt_q_cfg1rd_req, flt_q_cfg1wr_req};
  // Gen 6-COV SK : 
  // Gen 6-COV SK : always_comb
  // Gen 6-COV SK : begin
  // Gen 6-COV SK :   case(cov_cpl_crs)
  // Gen 6-COV SK :     5'b11000  : cov_bins = 3'b000;
  // Gen 6-COV SK :     5'b10100  : cov_bins = 3'b001;
  // Gen 6-COV SK :     5'b10010  : cov_bins = 3'b010;
  // Gen 6-COV SK :     5'b10001  : cov_bins = 3'b011;
  // Gen 6-COV SK :     default   : cov_bins = 3'b100;
  // Gen 6-COV SK :   endcase
  // Gen 6-COV SK : end
  // Gen 6-COV SK : 
  // Gen 6-COV SK : property p_return_cpl_crs;
  // Gen 6-COV SK :   @(posedge core_clk) disable iff (core_rst_n !== 1'b1)
  // Gen 6-COV SK :     (!radm_cfg_i.cfg_cfg_tlp_bypass_en && flt_q_valid_np &&l_flt_q_hv &&  (flt_q_cfg1rd_req || flt_q_cfg1wr_req || flt_q_cfg0rd_req || flt_q_cfg0wr_req) && (app_req_retry_en_tmp)) |-> check_flt_q_cpl_crs;
  // Gen 6-COV SK : endproperty
  // Gen 6-COV SK : `CX_ASSERTION( p_return_cpl_crs, "CPL with CRS status should be returned" )
  // Gen 6-COV SK : 
  // Gen 6-COV SK : covergroup cg_cpl_crs @(posedge core_clk);
  // Gen 6-COV SK :   cp_cpl_crs : coverpoint cov_bins iff(core_rst_n) {
  // Gen 6-COV SK :     option.comment = "CPL with CRS status sent for Type0 or Type1 Cfg Requests";
  // Gen 6-COV SK :     bins CFGRD0_CRS = {3'b000};
  // Gen 6-COV SK :     bins CFGWR0_CRS = {3'b001};
  // Gen 6-COV SK :     bins CFGRD1_CRS = {3'b010};
  // Gen 6-COV SK :     bins CFGWR1_CRS = {3'b011};
  // Gen 6-COV SK :     ignore_bins ignore = {cov_bins[2]};
  // Gen 6-COV SK :   }
  // Gen 6-COV SK : endgroup
  // Gen 6-COV SK : 
  // Gen 6-COV SK : cg_cpl_crs cg_inst_cpl_crs;
  // Gen 6-COV SK : 
  // Gen 6-COV SK : initial begin
  // Gen 6-COV SK :   cg_inst_cpl_crs = new();
  // Gen 6-COV SK : end
  // Gen 6-COV SK : 
  // Gen 6-COV SK : 
  // Gen 6-COV SK : `ifdef CX_DETECT_POISONED_CFGWR
  // Gen 6-COV SK : covergroup cg_cfgwr_poisoned @(posedge core_clk);
  // Gen 6-COV SK :     cp_cfg0wr_poisoned : coverpoint (radm_rcvd_cfg0wr_poisoned);
  // Gen 6-COV SK :     cp_cfg1wr_poisoned : coverpoint (radm_rcvd_cfg1wr_poisoned);
  // Gen 6-COV SK :     `ifdef CX_SRIOV_ENABLE
  // Gen 6-COV SK :     cp_cfg0wr_poisoned_for_vf : coverpoint (radm_rcvd_cfg0wr_poisoned && radm_rcvd_cfgwr_poisoned_is_vf);
  // Gen 6-COV SK :     cp_cfg1wr_poisoned_for_vf : coverpoint (radm_rcvd_cfg1wr_poisoned && radm_rcvd_cfgwr_poisoned_is_vf);
  // Gen 6-COV SK :     cp_cfg0wr_poisoned_for_pf : coverpoint (radm_rcvd_cfg0wr_poisoned && !radm_rcvd_cfgwr_poisoned_is_vf);
  // Gen 6-COV SK :     cp_cfg1wr_poisoned_for_pf : coverpoint (radm_rcvd_cfg1wr_poisoned && !radm_rcvd_cfgwr_poisoned_is_vf);
  // Gen 6-COV SK :     `endif
  // Gen 6-COV SK : endgroup
  // Gen 6-COV SK : 
  // Gen 6-COV SK : cg_cfgwr_poisoned cg_cfgwr_poisoned_inst;
  // Gen 6-COV SK : initial cg_cfgwr_poisoned_inst = new();
  // Gen 6-COV SK : 
  // Gen 6-COV SK : `endif // CX_DETECT_POISONED_CFGWR
  // Gen 6-COV SK : 
  // Gen 6-COV SK : 
  // Gen 6-COV SK : `endif // SNPS_ASSERT_ON
  // Gen 6-COV SK : 
  // Gen 6-COV SK : `endif // SYNTHESIS


  

    assign cfg_tph_enable = 1'b1;

    // =============== START 128/256 bit architecture header information collection =====
    // in 128/256 bit architecture, the hdr is latched until the eot cycle


    // always_comb begin
    // `ifdef CX_CCIX_INTERFACE_ENABLE
    //     if (!ccix_opt_tlp) begin
    //       opt_tlp_dw_len = {3'd0, hdr_dec_flt_hdr_cpl[30:24]};
    // `endif // CX_CCIX_INTERFACE_ENABLE
    assign int_addr_11_dt_0   = tlp_fmt_type[5] ? {hdr_dec_flt_cpl_in.hdr_dec_flt_hdr[115:112], hdr_dec_flt_cpl_in.hdr_dec_flt_hdr[127:120]}
                                            : {hdr_dec_flt_cpl_in.hdr_dec_flt_hdr[83:80], hdr_dec_flt_cpl_in.hdr_dec_flt_hdr[95:88]};

    // We strip the PH for checking purposes, regardless of whether TPH is set.
    assign addr_11_dt_0  =  {int_addr_11_dt_0[11:2],2'b00};

    always_comb begin : count_dwen
      integer i;
      l_tmp_dwcnt = 0;
      for(i = 0; i < NW; i = i + 1) begin
         if(ord_flt_data_cpl_in.ord_flt_dwen[i]) begin
             l_tmp_dwcnt = i;
         end
      end
      if(|ord_flt_data_cpl_in.ord_flt_dwen) begin
         l_tmp_dwcnt     = l_tmp_dwcnt + 1;
      end
    end
    assign tmp_dwcnt      = l_tmp_dwcnt;
    // spyglass disable_block W164a
    // SMD: Identifies assignments in which the LHS width is less than the RHS width
    // SJ: This logic is designed to be modulo. pyld_dwcnt counters are intended to
    // wrap without preseveration of carry/borrow
    always_ff @(posedge core_clk or negedge core_rst_n)
    begin
      if (!core_rst_n)
        prev_pyld_dwcnt   <= #TP 0;
      else if (ord_flt_data_cpl_in.ord_flt_eot) 
        prev_pyld_dwcnt   <= #TP 0;
      else
        prev_pyld_dwcnt   <= #TP pyld_dwcnt;
    end
 
    assign pyld_dwcnt      = (ord_flt_data_cpl_in.ord_flt_dv) ?
                              prev_pyld_dwcnt + tmp_dwcnt :
                              prev_pyld_dwcnt;
    // spyglass enable_block W164a

    assign int_extrct_hv  =  hdr_dec_flt_cpl_in.hdr_dec_flt_hv; // this signal indicates the header valid
    assign int_extrct_dv  =  ord_flt_data_cpl_in.ord_flt_dv;  // this signal indicates the data payload valid

    assign  hdr_len_mismatch = hdr_dec_flt_cpl_in.radm_malf_tlp_err_hdr || malform_ecrc_err_int;
    // =============== End 128/256 bit architecture header information collection =====


  assign              cpl           = ((tlp_fmt_type[6:0] == `CPL )
                                     | (tlp_fmt_type[6:0] == `CPLD)
                                     | (tlp_fmt_type[6:0] == `CPLLK)
                                     | (tlp_fmt_type[6:0] == `CPLDLK));

  assign              cpld          =  (tlp_fmt_type[6:0] == `CPLD) | (tlp_fmt_type[6:0] == `CPLDLK);



  assign valid_type    = ( cpl);

    // This optinal check was obsoleted in DMWr ECN dated 3 Apr 2020
    assign cpl_crs_err   = 0;

  assign fc_type       =  cpl ? 2'b10 : 2'b11;

  assign tlp_has_pyld  = (tlp_fmt_type[6] & !fm_cpl_rsvd[1]) || fm_cpl_rsvd[0];
  assign hdr_4dw       = tlp_fmt_type[5];
  assign dw_len_is0    = (tlp_dw_len == 10'b0);

  // all errors below are latched to form the malformaed error at the final
  // cycle of the current tlp due to the abort issue of the currnt tlp
  // This error can only be generated based on long payload tlps

  //`ifdef CX_CCIX_INTERFACE_ENABLE
  //always_comb  begin
  //  if (radm_cfg_i.cfg_ccix_opt_tlp_en) begin //---- CCIX Optimized TLP ----
  //    ccix_tlp_dw_len = {1'b0, opt_tlp_dw_len};
  //  end else begin                 //---- CCIX VDM1 ----
  //    if ( tlp_has_pyld ) begin
  //      ccix_tlp_dw_len = {dw_len_is0, tlp_dw_len};
  //    end else begin
  //      ccix_tlp_dw_len = 11'd0;
  //    end
  //  end
  //end
  //
  //always_comb  begin
  //  if ( cfg_ccix_length_chk_en ) begin //---- For both CCIX Optimized TLP / CCIX VDM1 ----
  //    case (radm_cfg_i.cfg_max_payload)
  //      3'b000: ccix_max_pyld_size = 11'h01F;   // 128 bytes
  //      3'b001: ccix_max_pyld_size = 11'h03F;   // 256Bytes
  //      default: ccix_max_pyld_size = 11'h07F;  // 512Bytes: 127 DW must be max size.
  //    endcase
  //  end else begin                      //---- Only for CCIX Optimized TLP ----
  //    case (radm_cfg_i.cfg_max_payload)
  //      3'b000: ccix_max_pyld_size = 11'h020;   // 128 bytes
  //      3'b001: ccix_max_pyld_size = 11'h040;   // 256Bytes
  //      default: ccix_max_pyld_size = 11'h080;  // 512Bytes: Length[6:0] doesn't exceed 512Bytes. 1KB-4KB will be redundant code if implemented.
  //    endcase
  //  end
  //end
  //
  //assign ccix_max_pyld_err = ccix_tlp_dw_len > ccix_max_pyld_size;
  //
  //always_comb  begin
  //  if ( radm_cfg_i.cfg_ccix_opt_tlp_en==1'b0 && cfg_ccix_length_chk_en==1'b0 ) begin // CCIX VDM + Standard Max Payload check
  //    max_pyld_err = pcie_max_pyld_err;
  //  end else begin // Optional Max Payload check
  //    if ( prfxHdr_flt_hdr_ccix_tlp==CCIX_VC ) begin
  //      max_pyld_err = ccix_max_pyld_err;
  //    end else begin
  //      max_pyld_err = pcie_max_pyld_err;
  //    end
  //  end
  //end
  //
  //// CCIX spec permits the optimized TLPs to have min length[6:0]=2, however this minimum check is not required in the CCIX spec.
  //// The result is undefined in the CCIX spec when the TLP size is less than the minumum size.
  //// This check is implemented not to break the data path control when the illegal TLPs are received.
  //assign ccix_minlen_err = ccix_opt_tlp & (opt_tlp_dw_len<10'd2);
  //`else // CX_CCIX_INTERFACE_ENABLE
  //assign max_pyld_err = pcie_max_pyld_err;
  //`endif // CX_CCIX_INTERFACE_ENABLE

 

  // detect the VC/TC errors with TC non zero err according to page 84,85 of rev1.0
  assign  curnt_struc_vc             = get_VC(radm_cfg_i.cfg_tc_struc_vc_map,tc);
  assign  tc_err                     = ~( get_tc_enable(radm_cfg_i.cfg_tc_enable,tc)
                                        //`ifdef CX_CCIX_INTERFACE_ENABLE
                                        // | get_tc_enable(cfg_ccix_tc_enable,tc)
                                        //`endif // CX_CCIX_INTERFACE_ENABLE
                                        );

  assign tmp_dw_len                  = {dw_len_is0, tlp_dw_len};



    assign len_mismatch              = ord_flt_data_cpl_in.ord_flt_eot & ((td & tlp_has_pyld ) ? (tmp_dw_len != pyld_dwcnt) :
                                       (td )                ? (pyld_dwcnt != 11'h0)      :
                                       (tlp_has_pyld )      ? (tmp_dw_len != pyld_dwcnt) : (pyld_dwcnt != 11'h0));


    // This block implements the optional byte enable checks according to pages 55 and 56 of spec 1.1
    // Byte enable checks will only be applied to packets with valid byte enable fields

    // Least 2 significant bits of address are Reserved and must be ignored
    // Bit[2] of address used to check QW alignment
    assign     is_qw_aligned = ~addr_11_dt_0[2];
    // FBE Check
    assign max_pyld_err           = pcie_max_pyld_err(radm_cfg_i.cfg_max_payload,dw_len_is0,tlp_dw_len,tlp_has_pyld); 
    assign {hdr_err_ptr, hdr_err} = cpl_crs_err   ? {`MFPTR_CPL_CRS,  1'b1} :
                                    max_pyld_err  ? {`MFPTR_TLP_MXPL, 1'b1} :
                                                    {`MFPTR_NO_ERR,   1'b0} ;
    // --------------- Output assignment ----------------
    assign       extrct_dwen          = ord_flt_data_cpl_in.ord_flt_dwen ;
    assign       extrct_dv            = int_extrct_dv ;
    assign       extrct_hv            = int_extrct_hv ;
    assign       extrct_eot           = ord_flt_data_cpl_in.ord_flt_eot ;
    assign       extrct_dllp_err      = flt_q_cpl_abort ;
    assign       extrct_ecrc_err      = 1'b0 ;

    assign       extrct_malfm_tlp_err = extrct_malfm_tlp_errsts & ord_flt_data_cpl_in.ord_flt_eot;
    assign       ecrc_len_mismatch    = 'd0; // TO DO : SK 
    assign      {extrct_malfm_tlp_err_ptr, extrct_malfm_tlp_errsts} = ord_flt_data_cpl_in.ord_flt_eot & (                    
                                     (hdr_len_mismatch || ord_flt_data_cpl_in.ord_flt_malformed_tlp_err)           ? {`MFPTR_TLP_HLEN,  1'b1} :
                                     len_mismatch   ? {`MFPTR_TLP_DLEN,  1'b1} : 
                                     hdr_err        ? {hdr_err_ptr,      1'b1} :
                                     ( (fmt2 & (~flit_mode) )  | hdr_dec_flt_cpl_in.radm_malf_tlp_err_hdr_prfx )      ? { `MFPTR_PFX,       1'b1} :
                                    ( hdr_dec_flt_cpl_in.radm_malf_tlp_err_hdr_flit )    ? {`MFPTR_TLP_FLIT,       1'b1} :
                                     ecrc_len_mismatch ? {`MFPTR_TLP_ELEN,  1'b1} :
                                     {`MFPTR_NO_ERR,    1'b0}) ;



    // ================== Output Drives ==================
    // Outputs are always registered except for 'anticipated' signals and FC gen outputs.
    // An additional pipeline stage can be added for one or both of the following reasons:
    //  - Ease cdm timing closure (RADM_VFINDEX_REGOUT): anticipated outputs provided 2 clock cycles in advance.
    //    Note in 512b, the Seriliazation Queue is in charge of providing the anticipated signals
    //    and this feature is not required.
    //  - Ease FC calculation (CX_RTLH_FC_CHECK_REGOUT): FC gen outputs registered
    //delay_n
    //#(.N(N_CYCLE_DELAY_GLOBAL), .WD(CTRL_WIDTH)) u_delay_ctrl (
    //    .clk        (core_clk),
    //    .rst_n      (core_rst_n),
    //    .clear      (1'b0),
    //    .din        ({extrct_hv, extrct_dv, extrct_eot
    //`ifdef CX_RTLH_SIMPLE_EXTRACT
    //  `ifdef CX_TLP_PREFIX_ENABLE
    //                  ,rtlh_extrct_pv
    //  `endif // CX_TLP_PREFIX_ENABLE
    //`endif // CX_RTLH_SIMPLE_EXTRACT
    //                }),
    //    .dout       ({hdr_dec_flt_hv_cpl, ord_flt_dv_cpl, ord_flt_eot_cpl
    //`ifdef CX_RTLH_SIMPLE_EXTRACT
    //  `ifdef CX_TLP_PREFIX_ENABLE
    //                  ,rtlh_radm_pv
    //  `endif // CX_TLP_PREFIX_ENABLE
    //`endif // CX_RTLH_SIMPLE_EXTRACT
    //                })
    //);
    //

      assign rx_tlp_evt_enable = ord_flt_data_cpl_in.ord_flt_eot & !flt_q_cpl_abort ;


    assign radm_cfg_o.radm_pm_asnak                   = 'd0;
    assign radm_cfg_o.radm_msg_unlock                 = 'd0;
    assign radm_cfg_o.radm_snoop_bus_num              = 'd0;
    assign radm_cfg_o.radm_snoop_dev_num              = 'd0;
    assign radm_cfg_o.radm_snoop_upd                  = 'd0;
    assign radm_cfg_o.radm_pm_turnoff                 = 'd0; 
    assign radm_cfg_o.radm_slot_pwr_limit               = 'd0;

      assign radm_cfg_o.cfg_segment_id                = 'd0;
  assign radm_cfg_o.radm_vendor_msg                   = 'd0;
  assign radm_cfg_o.radm_vendor_msg_type              = 'd0;


     assign radm_cfg_o.radm_ptm_req                   = 'd0; 
     assign radm_cfg_o.radm_ptm_res_msg               = 'd0; 
     assign radm_cfg_o.radm_ptm_res_d_msg             = 'd0; 
     assign radm_cfg_o.radm_ptm_master_time           = 'd0; 
     assign radm_cfg_o.radm_ptm_prop_delay            = 'd0; 
     assign radm_cfg_o.radm_msg_payload               = 'd0; 
     assign radm_cfg_o.radm_msg_idle                  = 'd0; 
     assign radm_cfg_o.radm_msg_obff                  = 'd0; 
     assign radm_cfg_o.radm_msg_cpu_active            = 'd0; 

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




endmodule
