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
// ---    $Revision: #18 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_ms_pkg.svh#18 $
// -------------------------------------------------------------------------
// ----------------------------------------------------------------------------
// --- Module Description:
//This module is to add  - 
//1. Functions used in the RADM modules 
//2. Defined structures used for interface signals 
//3. Defined Local Paramters used in the RADM
// ----------------------------------------------------------------------------

`ifndef __GUARD__RADM_MS_PKG__SVH__
`define __GUARD__RADM_MS_PKG__SVH__

`include "DWC_pcie_ctl_pkg.svh"
`include "products/pcie_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

package radm_ms_pkg;
  import DWC_pcie_ctl_pkg::NW;
  import DWC_pcie_ctl_pkg::DW;
  import DWC_pcie_ctl_pkg::NVC;
  import DWC_pcie_ctl_pkg::NF;
  import DWC_pcie_ctl_pkg::VF_WD;
  import DWC_pcie_ctl_pkg::PF_WD;
  import DWC_pcie_ctl_pkg::VFI_WD;
  import DWC_pcie_ctl_pkg::NP_REQ_TX_TYPE_WD;
  import DWC_pcie_ctl_pkg::ATTR_WD;
  import DWC_pcie_ctl_pkg::ATU_REG_WD;
  import DWC_pcie_ctl_pkg::ATU_BASE_WD;
  import DWC_pcie_ctl_pkg::ATU_UPR_LMT_WD;
  import DWC_pcie_ctl_pkg::TAG_SIZE;
  import DWC_pcie_ctl_pkg::NVF;
  import DWC_pcie_ctl_pkg::BUSNUM_WD;
  import DWC_pcie_ctl_pkg::DEVNUM_WD;
  import DWC_pcie_ctl_pkg::DCA_WD;
  import DWC_pcie_ctl_pkg::CPL_LUT_DEPTH;
  import DWC_pcie_ctl_pkg::MSG_TLP_WD;
  import DWC_pcie_ctl_pkg::N_XADM_NP_IF;
  import DWC_pcie_ctl_pkg::ERROR_TLP_WD;
  import DWC_pcie_ctl_pkg::ERROR_INJ_MASK_WD;
  import DWC_pcie_ctl_pkg::ERROR_INJ_EN_WD;
  import DWC_pcie_ctl_pkg::RAS_PROT_RANGE;
  import DWC_pcie_core_pkg::UNCORR_INT_ERR;
  import DWC_pcie_core_pkg::RECEIVER_OVRFLW;
  import DWC_pcie_core_pkg::MALFORMED_TLP;
  import DWC_pcie_core_pkg::IDE_CHK_FAILED;
  import DWC_pcie_core_pkg::ECRC_CHK_FAILED;
  import DWC_pcie_core_pkg::MISROUTED_IDE_TLP;
  import DWC_pcie_core_pkg::ATOMIC_OP_EGRSS;
  import DWC_pcie_core_pkg::DMWR_REQUEST_EGRSS_BLOCKD;
  import DWC_pcie_core_pkg::TLP_TRANS_EGRSS_BLOCKD;
  import DWC_pcie_core_pkg::TLP_PRFX_BLOCKD;
  import DWC_pcie_core_pkg::ACS_VIOLATION;
  import DWC_pcie_core_pkg::MC_BLOCKD_TLP;
  import DWC_pcie_core_pkg::UNSUPP_REQUEST;
  import DWC_pcie_core_pkg::COMPLETER_ABORT;
  import DWC_pcie_core_pkg::UNEXP_COMPLETION;
  import DWC_pcie_core_pkg::PCRC_CHECK_FAILED;
  import DWC_pcie_core_pkg::POISONED_TLP_RECEIVED;
  import DWC_pcie_core_pkg::POISONED_TLP_EGRSS_BLOCKD;
  import DWC_pcie_core_pkg::QDW_DW;
  import DWC_pcie_core_pkg::QDW_PAR;

  //////////////////////////////////////////////////
  /// TODO CLEANUP
  //////////////////////////////////////////////////
  //
  localparam     DATA_PROT_WD = `TRGT_DATA_PROT_WD; // TODO get rid od at least one of these two localparam
  localparam int DATA_PAR_WD  = `TRGT_DATA_PROT_WD;                // data bus parity width
  localparam     INT_NVF      = `CX_INTERNAL_NVFUNC;               // Number of Internal virtual functions

  //////////////////// RADM localparamS ////////////////////////////
  // Formation queue localparams
  localparam NQW              = `CX_RADM_FORMQ_NQW;
  localparam RADM_HDR_PROT_WD = 0 + 60;
  localparam HDRQDW_SIZE      = 4;
  localparam DATAQDW_SIZE     = (NW==32) ? 8 : (NW==16)? 4 : (NW==8)? 2 : 1;
  localparam NQW_R            = `CX_RADM_FORMQ_N_READ_PORT_VC*HDRQDW_SIZE + DATAQDW_SIZE;


  // CPL LUT localparams
  localparam N_XADM_RADM_TX_NPR_IF = N_XADM_NP_IF;

  localparam N_RADM_CPL_TLP          = NVC*`CX_RADM_FORMQ_N_READ_PORT_VC;      // Number of CPL TLPs that can be processed in a single cycle after the formation block
  localparam CPL_LUT_DEPTH_EXTERNAL  = `CX_MAX_TAG + 1 ;
  localparam CPL_LUT_DEPTH_INTERNAL  = `CX_MAX_TAG + 1 
                                        ;      
  localparam CPL_LUT_PTR_WD          = `CX_LUT_PTR_WIDTH;        // Number of bits needed to index completion table
  localparam CPL_LUT_FRAG_DEPTH      = `CX_FRAG_TAG
         ;             // TAG per fragment
  localparam CPL_LUT_FRAG_PTR_WD     = `CX_LOGBASE2(CPL_LUT_FRAG_DEPTH);   // NUmber of bits needed to index the fragment entries.
  localparam NFRAG                   = `CX_N_FRAGMENT;           // Number of fragments to store NP TLP attributes.
  localparam FRAGI_WD                = `CX_LOGBASE2(NFRAG);      // bits required to present the number of fragments.   
  
  localparam FUNC_NUM_INDEX          = PF_WD;                 // 2:0 for function number in the lut
  localparam BYTECNT_INDEX           = FUNC_NUM_INDEX;         // Normal PF only than value of this localparam is 3 only.     

  localparam TC_INDEX                = 3 + BYTECNT_INDEX;        
  localparam ATTR_INDEX              = 3 + TC_INDEX;
  localparam CPL_TRGT_INDEX          = 1 + ATTR_INDEX;
  localparam NP_REQ_TYPE_INDEX       = NP_REQ_TX_TYPE_WD + CPL_TRGT_INDEX; //NP_REQ_TYPE_WD + ATTR_INDEX,
  localparam E_14BIT_TAG_INDEX       = 1 + NP_REQ_TYPE_INDEX;   
  localparam E_10BIT_TAG_INDEX       = 1 + NP_REQ_TYPE_INDEX;   
  localparam CPL_ENTRY_WIDTH         = 1 + NP_REQ_TYPE_INDEX; 
 
  // ## CPL_LUT2 ##
  localparam LOW_ADDR_WD2            = 7;
  localparam BYTECNT_WD2             = 12;
  localparam BYTECNT_INDEX2          = LOW_ADDR_WD2;
  localparam CPL_ENTRY_WIDTH2        = LOW_ADDR_WD2 + BYTECNT_WD2;
  localparam N_FLT_MASK              = `CX_N_FLT_MASK;           // Filter rules mask sie 
  localparam PM_CPL_TIMER_WD         = `CX_PM_CPL_TIMER_WD;
  localparam RADM_FILTER_TO_LUT_PIPE = 1;                        // Pipeline stage is present by defualt with all the config with new updates.
  localparam RTLH_RADM_RID_WD        = 16;                       // Requester ID size.
  localparam TIMEOUT_GRANULARITY     = `CX_TIMEOUT_GRANULARITY;  // Width of timeout value (granularity) 
  localparam FLT_NUM                 = 0;
  localparam LOW_ADDR_INDEX2         = 0;
  // Completion timer value scaled down by dividing the granularity. Min > CPL_LUT_PTR_WD
  localparam CPL_TIMEOUT_VALUE_INT   = `CX_CPL_BASE_TIMER_VALUE;
  localparam CPL_TIMEOUT_VALUE1      = `CX_CPL_BASE_TIMER_VALUE1;
  localparam CPL_TIMEOUT_VALUE2      = `CX_CPL_BASE_TIMER_VALUE2;
  localparam CPL_TIMEOUT_VALUE3      = `CX_CPL_BASE_TIMER_VALUE3;
  localparam CPL_TIMEOUT_VALUE4      = `CX_CPL_BASE_TIMER_VALUE4;
  localparam CPL_TIMEOUT_VALUE5      = `CX_CPL_BASE_TIMER_VALUE5;
  localparam CPL_TIMEOUT_VALUE6      = `CX_CPL_BASE_TIMER_VALUE6;
  localparam CPL_TIMEOUT_VALUE7      = `CX_CPL_BASE_TIMER_VALUE7;
  localparam CPL_TIMER_TW            = `CX_CPL_BASE_TIMER_TW;    // timer width of the timeout value
  localparam CPL_BASE_TIMER_VALUE_US = `CX_CPL_BASE_TIMER_VALUE_US; // the cpl base timer period expressed in microseconds
   
  localparam RADM_CPL_LUT_PIPE_EN    = `CX_RADM_CPL_LUT_PIPE_EN_VALUE; 
  localparam RADM_ANT_PIPE_WD  = 16;     

  localparam TRGT1_ADDR_WD       = `FLT_Q_ADDR_WIDTH;
  localparam PKT_ORD_WD          = `CX_RADM_PKT_ORD_WD;
  localparam NHW                 = 15;  
  localparam HW                  = 32*NHW;
  localparam HW_NFT              = 128;
  localparam HW_NFT_PAR          = 0 + HW_NFT/RAS_PROT_RANGE ;

  localparam ST_WD               = 8; //(STEERING TAG WIDTH)
  localparam PASID_WD            = 0; 
  // ATU Regions 
  localparam ATU_IN_REGIONS      = `CX_ATU_NUM_INBOUND_REGIONS;
  localparam ATU_IN_MIN1         = ATU_IN_REGIONS > 0 ? ATU_IN_REGIONS : 1;
  
  localparam FLT_HDR_WIDTH       =  
                                     1 +   // td for hdr_logging
                                     1 + // FMT[2] bit addition 
                                     NP_REQ_TX_TYPE_WD + TRGT1_ADDR_WD + PKT_ORD_WD +
                                     1 + $clog2(ATU_IN_MIN1) + 1 + 1 + //CX_ATU_SLOC_CBUF
                                     9 +  // $bits(radm_hdr_log_rcvd_flds_s) 
                                     ST_WD + 8 + 9 + 9 +                                     2 + 8 +
                                     1 + 
                                     1 +
 // CX_CCIX_INTERFACE_ENABLE
 // CX_RX_HEADER_RSVD_ENABLE 
                                    `FLT_Q_LSTDW_BE_WIDTH + `FLT_Q_CPL_LAST_WIDTH +
                                    //`ifdef CX_IS_SW
                                    //`else
 `FLT_Q_AT_WIDTH +  // ATS_RX_ENABLE
                                    //`endif  // CX_IS_SW    
                                    `FLT_Q_EP_WIDTH +
                                    // `ifdef CX_IS_SW
                                    //`else
 `FLT_Q_TH_WIDTH + // CX_TPH_ENABLE
                                    //`endif  // CX_IS_SW
                                    `FLT_Q_TD_WIDTH + `FLT_Q_CPL_LOWER_ADDR_WIDTH + `FLT_Q_BCM_WIDTH +
                                    `FLT_Q_CMPLTR_ID_WIDTH + `FLT_Q_BYTE_CNT_WIDTH + `FLT_Q_ADDR_WIDTH +
                                    `FLT_Q_FRSTDW_BE_WIDTH + `FLT_Q_IO_REQ_IN_RANGE_WIDTH +
 `FLT_Q_ROM_IN_RANGE_WIDTH + // FLT_Q_ROM_IN_RANGE_RANGE
                                    //`ifdef CX_IS_SW
                                    //`else
 `FLT_Q_IN_MEMBAR_RANGE_WIDTH + // FLT_Q_IN_MEMBAR_RANGE_RANGE
                                    //`endif  // CX_IS_SW
                                    `FLT_Q_DW_LENGTH_WIDTH +
 `FLT_Q_PRFX_WIDTH + // CX_TLP_PREFIX_ENABLE
                                    //`ifdef CX_IS_SW
                                    //`else
 // CX_SRIOV_ENABLE
                                    //`endif  // CX_IS_SW
                                    `FLT_Q_CPL_STATUS_WIDTH + `FLT_Q_FUNC_NMBR_WIDTH + `FLT_Q_TAG_WIDTH + `FLT_Q_REQID_WIDTH +
                                    //`ifdef CX_IS_SW
                                    //`else
  // CX_LN_ENABLE
                                    //`endif  // CX_IS_SW
                                    `FLT_Q_ATTR_WIDTH + `FLT_Q_TC_WIDTH + 5 + 2 + 2; 

  localparam EXTRA_BITS          = FLT_HDR_WIDTH % RAS_PROT_RANGE;
  localparam EXTRA_PROT_BITS     = (EXTRA_BITS>0) ? 1'b1 : 1'b0;  
  localparam FLT_HDR_PROT_WIDTH  = 0 + FLT_HDR_WIDTH/RAS_PROT_RANGE + EXTRA_PROT_BITS;

///////////////////////////
                                     
  localparam FLT_Q_DMUX_WIDTH =   PKT_ORD_WD + 3 +DW+DATA_PAR_WD + 1 + 1 + 1 +NW + 1+1+1+1 
      +  PASID_WD
      +  FLT_HDR_WIDTH;                        
                                     
/////////////////////////////

  localparam FILTER_CHK_CNTS                 = 1 + 1 ;  
  localparam HDR_DEC_CHK_CNTS                = 1;
  localparam ATU_CHK_CNTS                    = 0 + 2 +  `CX_IATU_LATENCY_RADM; 
  localparam TRGT1_CHK_CNTS                  = 0 + 1; 
  localparam FILTER_DEMUX_TRGT1_P_CHK_CNTS   = HDR_DEC_CHK_CNTS + FILTER_CHK_CNTS + ATU_CHK_CNTS + TRGT1_CHK_CNTS;
  localparam FILTER_DEMUX_TRGT1_NP_CHK_CNTS  = HDR_DEC_CHK_CNTS + FILTER_CHK_CNTS + ATU_CHK_CNTS + TRGT1_CHK_CNTS;
  localparam FILTER_DEMUX_TRGT1_CPL_CHK_CNTS = HDR_DEC_CHK_CNTS + FILTER_CHK_CNTS + TRGT1_CHK_CNTS;
  localparam FILTER_DEMUX_TRGT1_CKH_CNTS     = FILTER_DEMUX_TRGT1_P_CHK_CNTS + FILTER_DEMUX_TRGT1_NP_CHK_CNTS + FILTER_DEMUX_TRGT1_CPL_CHK_CNTS;

  localparam N_TRGT1_INTF        = `CX_RADM_NFC_TRGT_INTF;
  localparam FX_TLP              = `CX_RADM_NFC_TRGT_INTF*3;
  localparam TRGT_DATA_WD        = `TRGT_DATA_WD;
  localparam TRGT_DATA_PROT_WD   = `TRGT_DATA_PROT_WD;
  localparam TRGT_HDR_WD         = `TRGT_HDR_WD;
  localparam CX_MAX_HDR_LOG_SZ   = `CX_MAX_HDR_LOG_SZ ;
  localparam TRGT1_HDR_WD        = `CX_RASDP_TRGT1_HDR_WD;
  localparam TRGT1_GEN_PROT_WD   = `CX_RASDP_TRGT1_HDR_PROT_WD;
  localparam DWW                 = 32;
  localparam FLT_OUT_PROT_WD     = `CX_FLT_OUT_PROT_WD;
  //radm_trgt1_ctrl_ms param ends

  //radm_filter_P_ms starts
  localparam CX_NFUNC_WD           = `CX_NFUNC_WD;        // Number of bits needed to address the physical functions 
  localparam HEW                   = 32;                   // Header element width
  localparam P_TYPE                = 0;
  localparam NP_TYPE               = 1;
  localparam CPL_TYPE              = 2;
  localparam RAS_PROT_CORRECT_EN   = `CX_RAS_CORRECTION_EN;
  localparam RAS_STAT_WD           = `CX_RAS_STAT_FILTER_EP_WD;

  localparam L2N_INTFC             = 1;                    // Number of bits for application interface ID
  localparam FLT_Q_ADDR_WIDTH      = `FLT_Q_ADDR_WIDTH;
  localparam CX_ELBI_NW            = `CX_LBC_NW;   // number of DWs which can be accepted on ELBI; corresponds to max allowable Length field to which the ELBI is limited.
  localparam PRFX_WD               = 32*`CX_NPRFX;            // width of TLP prefix support in bits
  localparam PRFX_WD_PAR           = 0 + PRFX_WD/RAS_PROT_RANGE ;
  localparam ERROR_LOG_PIPE_DELAY  = `CX_ERROR_LOG_REGOUT;
  localparam RID_PIPE_DELAY        = `CX_RID_DELAY;
  localparam RADM_ATU_CPIPE_EN     = ATU_IN_REGIONS > 0 ? 1 : 0; // Parameter to enable iATU Central Pipeline
localparam FLT_Q_PIPE_DELAY      = 1 + RADM_ATU_CPIPE_EN +  `CX_IATU_LATENCY_RADM ; 
  //radm_filter_P_ms ends

  //radm_hdr_dec_P_ms starts
  localparam HWP                   = 32*NHW + RADM_HDR_PROT_WD;//`ifdef CX_TLP_PREFIX_ENABLE + PRFX_W_PAR `endif;
  //radm_hdr_dec_P_ms ends

  localparam SNOOP_VPD_WD          = `CX_SNOOP_VPD_WD;  //KN
  localparam TRGT_SGMT_WD          = 0;  
  localparam PASID_TRGT_SGMT_WD    =  PASID_WD +TRGT_SGMT_WD;
  localparam D_P_FIFO_DEPTH         =  `CX_RADM_TRGT_FIFO_P_DATA_DP;
  localparam D_NP_FIFO_DEPTH        =  `CX_RADM_TRGT_FIFO_NP_DATA_DP;
  localparam D_CPL_FIFO_DEPTH       =  `CX_RADM_TRGT_FIFO_CPL_DATA_DP;
  localparam H_FIFO_DEPTH           =  `CX_RADM_TRGT_FIFO_HDR_DP;
  localparam H_ADDR_WIDTH           =  $clog2(H_FIFO_DEPTH);
  localparam D_P_ADDR_WIDTH         =  $clog2(D_P_FIFO_DEPTH);
  localparam D_NP_ADDR_WIDTH        =  $clog2(D_NP_FIFO_DEPTH);
  localparam D_CPL_ADDR_WIDTH       =  $clog2(D_CPL_FIFO_DEPTH);

  localparam PRE_REGISTER          = 1;
  //localparam POST_REGISTER         = `CX_FLT_Q_REGOUT >= 2;
  localparam POST_REGISTER         = 0;   // TO DO : ms_cfg
  localparam ATU_PRE_RADM_Q        = 1;
// ATU_IN_MIN1 is to ensure the ports are at least 1 bit wide even when no
// regions are defined. Lint tools like that
  localparam PASID_CNTRL_WD        = `CX_PASID_CONTROL_WD;
  localparam NVF_PASID_CNTRL_WD    = INT_NVF*PASID_CNTRL_WD;
  localparam DW_LEN_WD             = `FLT_Q_DW_LENGTH_WIDTH;

  localparam RAS_DATAPATH_EN       = (`CX_RASDP!=0) ? 1 : 0 ;
  localparam NO_OF_TRGT0_INTF      = 2*N_TRGT1_INTF;
  // {nullified, pois, tlp_abort, parerr, ecrc_err, dllp_abort, eot, dwen, data, dv}
  localparam INT_DWIDTH            = DW+ DATA_PAR_WD+NW+1+1+1+1+1+1 
                                     + 1 // pois

                                     + 1 // last_tlp_had_dllp_err
                                     ; 
  localparam INT_HWIDTH            = FLT_HDR_WIDTH + FLT_HDR_PROT_WIDTH + 3 + 1; // 3 :- 3 bits are added to pass additional sideband cpl_status information from pkt_store module to TRGT0 control logic. 1 bit signal is to pass HV information in this vector. 
  
  localparam INT_HDW               = INT_HWIDTH +INT_DWIDTH;
  localparam TLP_FMT_WD            = 3;

  localparam XTLH_WRITE_TO_LUT_DELAY = 1; // `ifdef CPL_LUT_VFINDEX_REGOUT + 1 `endif;


  //////////////////////////////////////
  // TODO END CLEANUP
  //////////////////////////////////////

  //this struct is the enumeration of the destination field of the TLP header
  typedef enum logic   [  1 : 0    ] {
      TRASH           =        2'b00,
      TRGT0           =        2'b01,
      TRGT1           =        2'b10,
      CPL             =        2'b11
    } hdr_destination;

  //this struct is the enumeration of the FMT field of the TLP header
  typedef enum logic   [  1 : 0    ] {
      NODATA_3DW      =        2'b00,
      NODATA_4DW      =        2'b01,
      DATA_3DW        =        2'b10,
      DATA_4DW        =        2'b11
    } hdr_fmt;
  
typedef struct packed {
    logic               ohc_dec_a_present;
    logic               ohc_dec_b_present;
    logic               ohc_dec_c_present;
  } radm_hdr_dec_com_ohc_decx_present_s;
// This struct is made to collect all needed info from hdr_dec till hdr_log
typedef struct packed {
  radm_hdr_dec_com_ohc_decx_present_s ohc_decx_present ;
  logic [2:0]                         ts_field         ;
  logic [1:0]                         ohc_uppr_43      ;
  logic                               hv_1             ;
} radm_hdr_log_rcvd_flds_s ;

// this struct contains signals needed for the compressed hdr generation
typedef struct packed {
  logic  [1:0]                        destination;
  // side-band signals
  logic  [2:0]                        cpl_status;
  logic  [PF_WD-1:0]                  func_num_c;
  logic  [2:0]                        in_membar_range;
  logic                               rom_req_in_range_c;
  logic                               io_req_in_range_c;
  logic                               cpl_last;
  logic  [NP_REQ_TX_TYPE_WD-1:0]      np_req_type;
  logic                               hdr_log_valid; // temperory for the current compressed hdr usage inside filter
} compressed_hdr_gen_ctl_s;

  //this struct is the different header fields decoded in the filter module from incoming header
  //This is the common struct for P, NP and CPL header format
  //


  typedef struct packed {

    logic                                                    flt_q_td_hdr_log ;
    logic                                                    flt_q_fmt2; // second [2] bit of FMT field used to detect reserved TLP in FLIT mode   
    logic     [FLT_HDR_PROT_WIDTH-1:0]                       flt_hdr_prot;
    logic [NP_REQ_TX_TYPE_WD-1:0]                            lut_np_req_type;
    logic [TRGT1_ADDR_WD-1:0]                                flt_q_hdr_uppr_bytes;
    logic [PKT_ORD_WD-1:0]                                   flt_pkt_num;
     logic                                                     radm_atu_uppr_bytes_valid;
        logic [$clog2(ATU_IN_MIN1)-1:0]                        radm_atu_sloc_region;
        logic                                                  radm_atu_sloc_match;
        logic                                                  radm_atu_cbuf_err;
      logic                                                     flt_q_nw;
      logic                                                     flt_q_cxlsrc;
      logic       [1:0]                                         flt_q_ph;
      logic       [7:0]                                         flt_q_st;
      radm_hdr_log_rcvd_flds_s                                  log_rcvd_flds ; 
      logic     [ST_WD -1 :0]                                   flt_q_ohc_b_st_lb; 
      logic     [7:0]                                           hdr_dec_flt_cpltr_seg; 
      logic     [8:0]                                           hdr_dec_flt_dest_seg; 
      logic     [8:0]                                           hdr_dec_flt_reqtr_seg; 
    logic       [ `FLT_Q_LSTDW_BE_WIDTH -1     : 0           ]  flt_q_last_be;            // TRGT1 and cpl_gen control (Last Byte Enable)      
    logic       [ `FLT_Q_CPL_LAST_WIDTH -1     : 0           ]  flt_q_cpl_last;           // CPL Control                 

    //`ifdef CX_IS_SW
    //`else
        logic   [ `FLT_Q_AT_WIDTH -1           : 0           ]  flt_q_ats;                // Provides support of PCI-SIG ATS specification
    //`endif  // CX_IS_SW
     
    logic       [ `FLT_Q_EP_WIDTH -1           : 0           ]  flt_q_poisoned;           // CPL TLP EP
      
    //`ifdef CX_IS_SW
    //`else
        logic   [ `FLT_Q_TH_WIDTH -1           : 0           ]  flt_q_th;                 // CPL TLP TH (Processing Hints)
    //`endif  // CX_IS_SW

    logic       [ `FLT_Q_TD_WIDTH -1           : 0           ]  flt_q_td;                 // CPL TLP TD (Digest)
    logic       [ `FLT_Q_CPL_LOWER_ADDR_WIDTH-1: 0           ]  flt_q_cpl_lower_addr;     // CPL TLP LOWER ADDR 
    logic       [ `FLT_Q_BCM_WIDTH -1          : 0           ]  flt_q_cpl_bcm;            // CPL TLP BCM (Byte Count Modified)               
    logic       [ `FLT_Q_CMPLTR_ID_WIDTH -1    : 0           ]  flt_q_cplid;              // CPL TLP Completer ID                  
    logic       [ `FLT_Q_BYTE_CNT_WIDTH -1     : 0           ]  flt_q_byte_cnt;           // CPL Byte Count         
    logic       [ `FLT_Q_ADDR_WIDTH -1         : 0           ]  flt_q_addr;               // completion hdr &  TRGT0 control
    logic       [ `FLT_Q_FRSTDW_BE_WIDTH -1    : 0           ]  flt_q_first_be;           // completion hdr &  TRGT0 control            
    logic       [`FLT_Q_IO_REQ_IN_RANGE_WIDTH-1: 0           ]  flt_q_io_req_in_range;    // TLP Header field IO_REQ_IN_RANGE
      logic     [ `FLT_Q_ROM_IN_RANGE_WIDTH -1 : 0           ]  flt_q_rom_req_in_range;   // TLP Header field ROM_IN_RANGE
    //`ifdef CX_IS_SW
    //`else
        logic   [ `FLT_Q_IN_MEMBAR_RANGE_WIDTH -1: 0         ]  flt_q_in_membar_range;    // TLP Header field IN_MEMBAR_RANGE
    //`endif  // CX_IS_SW

    logic       [ `FLT_Q_DW_LENGTH_WIDTH -1    : 0           ]  flt_q_dw_len;             // CPL Data Payload Size            
      logic     [ `FLT_Q_PRFX_WIDTH -1         : 0           ]  flt_q_prfx;               // Prefix (Including parity)

    //`ifdef CX_IS_SW
    //`else
    //`ifdef EP_INTERFACE_ACTIVATED     // for ep/dm mode only
    //`endif // EP_INTERFACE_ACTIVATED
    //`endif  // CX_IS_SW

    logic   [ `FLT_Q_CPL_STATUS_WIDTH -1   : 0            ]  flt_q_cpl_status;         // Status Of The Completion   
    logic   [ `FLT_Q_FUNC_NMBR_WIDTH -1    : 0            ]  flt_q_func_nmbr;          // Physical Function Number
    logic   [ `FLT_Q_TAG_WIDTH -1          : 0            ]  flt_q_TAG;                // CPL TLP TAG
    logic   [ `FLT_Q_REQID_WIDTH -1        : 0            ]  flt_q_REQID;              // CPL TLP Requester ID             

    //`ifdef CX_IS_SW
    //`else
    //`endif  // CX_IS_SW
        
    logic   [ `FLT_Q_ATTR_WIDTH  -1        : 0            ]  flt_q_attr;               // CPL TLP ATTR (Attributes)                     
    logic   [ `FLT_Q_TC_WIDTH    -1        : 0            ]  flt_q_tc;                 // CPL TLP TC (Traffic Class)             
    logic   [ 5  -1                       : 0             ]  flt_q_type;               // TLP TYPE            
    hdr_fmt                                                  flt_q_fmt;                // TLP Format                
    hdr_destination                                          flt_q_destination;        // TLP Destination
  } flt_hdr_s ;

// TRGT0 interface HDR
  typedef struct packed {

      radm_hdr_log_rcvd_flds_s                                  log_rcvd_flds ; 
      logic     [7:0]                                           hdr_dec_flt_cpltr_seg; 
      logic     [8:0]                                           hdr_dec_flt_dest_seg; 
      logic     [8:0]                                           hdr_dec_flt_reqtr_seg; 
    
    logic       [ `FLT_Q_LSTDW_BE_WIDTH -1     : 0           ]  flt_q_last_be;            // TRGT1 and cpl_gen control (Last Byte Enable)      
    logic       [ `FLT_Q_CPL_LAST_WIDTH -1     : 0           ]  flt_q_cpl_last;           // CPL Control   
    //`ifdef CX_IS_SW
    //`else
        logic   [ `FLT_Q_AT_WIDTH -1           : 0           ]  flt_q_ats;                // Provides support of PCI-SIG ATS specification
    //`endif  // CX_IS_SW
     
    logic       [ `FLT_Q_EP_WIDTH -1           : 0           ]  flt_q_poisoned;           // CPL TLP EP
      
    //`ifdef CX_IS_SW
    //`else
        logic   [ `FLT_Q_TH_WIDTH -1           : 0           ]  flt_q_th;                 // CPL TLP TH (Processing Hints)
    //`endif  // CX_IS_SW

    logic       [ `FLT_Q_TD_WIDTH -1           : 0           ]  flt_q_td;                 // CPL TLP TD (Digest)
    logic       [ `FLT_Q_ADDR_WIDTH -1         : 0           ]  flt_q_addr;               // completion hdr &  TRGT0 control
    logic       [ `FLT_Q_FRSTDW_BE_WIDTH -1    : 0           ]  flt_q_first_be;           // completion hdr &  TRGT0 control            
    logic       [`FLT_Q_IO_REQ_IN_RANGE_WIDTH-1: 0           ]  flt_q_io_req_in_range;    // TLP Header field IO_REQ_IN_RANGE
      logic     [ `FLT_Q_ROM_IN_RANGE_WIDTH -1 : 0           ]  flt_q_rom_req_in_range;   // TLP Header field ROM_IN_RANGE
    //`ifdef CX_IS_SW
    //`else
        logic   [ `FLT_Q_IN_MEMBAR_RANGE_WIDTH -1: 0         ]  flt_q_in_membar_range;    // TLP Header field IN_MEMBAR_RANGE
    //`endif  // CX_IS_SW

    logic       [ `FLT_Q_DW_LENGTH_WIDTH -1    : 0           ]  flt_q_dw_len;             // CPL Data Payload Size            
      logic     [ `FLT_Q_PRFX_WIDTH -1         : 0           ]  flt_q_prfx;               // Prefix (Including parity)

    //`ifdef CX_IS_SW
    //`else
    //`ifdef EP_INTERFACE_ACTIVATED     // for ep/dm mode only
    //`endif // EP_INTERFACE_ACTIVATED
    //`endif  // CX_IS_SW

    logic   [ `FLT_Q_CPL_STATUS_WIDTH -1   : 0            ]  flt_q_cpl_status;         // Status Of The Completion   
    logic   [ `FLT_Q_FUNC_NMBR_WIDTH -1    : 0            ]  flt_q_func_nmbr;          // Physical Function Number
    logic   [ `FLT_Q_TAG_WIDTH -1          : 0            ]  flt_q_TAG;                // CPL TLP TAG
    logic   [ `FLT_Q_REQID_WIDTH -1        : 0            ]  flt_q_REQID;              // CPL TLP Requester ID             

    //`ifdef CX_IS_SW
    //`else
    //`endif  // CX_IS_SW
        
    logic   [ `FLT_Q_ATTR_WIDTH  -1        : 0            ]  flt_q_attr;               // CPL TLP ATTR (Attributes)                     
    logic   [ `FLT_Q_TC_WIDTH    -1        : 0            ]  flt_q_tc;                 // CPL TLP TC (Traffic Class)             
    logic   [ 5  -1                       : 0             ]  flt_q_type;               // TLP TYPE            
    hdr_fmt                                                  flt_q_fmt;                // TLP Format                
    hdr_destination                                          flt_q_destination;        // TLP Destination         

  } trgt0_hdr_s ;

  // config struct declaration for ATU
  //this struct is defined to get configuration inputs from CDM module to ATU block 
  //This is th common struct for P, NP ATU configuration inputs 
  // ATU
  typedef struct packed {

    logic     [5*ATU_IN_MIN1 -1:0]                atu_reg_in_type;
    logic     [3*ATU_IN_MIN1 -1:0]                atu_reg_in_tc;
    logic     [ATU_IN_MIN1 -1:0]                  atu_reg_in_td;
    logic     [ATTR_WD*ATU_IN_MIN1 -1:0]          atu_reg_in_attr;
     logic     [2*ATU_IN_MIN1 -1:0]               atu_reg_in_at;  
    logic     [PF_WD*ATU_IN_MIN1 -1:0]            atu_reg_in_func_num;
    logic     [8*ATU_IN_MIN1 -1:0]                atu_reg_in_msg_code;
      logic     [ATU_IN_MIN1-1:0]                 atu_reg_in_th;
      logic     [2*ATU_IN_MIN1-1:0]               atu_reg_in_ph;
      logic     [8*ATU_IN_MIN1-1:0]               atu_reg_in_st;
    logic     [3*ATU_IN_MIN1 -1:0]                atu_reg_in_bar_num;
    // Inbound field match enables  
    logic     [ATU_IN_MIN1 -1:0]                  atu_reg_in_tc_match_en;
    logic     [ATU_IN_MIN1 -1:0]                  atu_reg_in_td_match_en;
    logic     [ATU_IN_MIN1 -1:0]                  atu_reg_in_attr_match_en;
      logic     [ATU_IN_MIN1 -1:0]                atu_reg_in_at_match_en;
    logic     [ATU_IN_MIN1 -1:0]                  atu_reg_in_func_match_en;
    logic     [ATU_IN_MIN1 -1:0]                  atu_reg_in_msgcode_match_en;
      logic     [ATU_IN_MIN1 -1:0]                atu_reg_in_th_match_en;
      logic     [ATU_IN_MIN1 -1:0]                atu_reg_in_ph_match_en;
      logic     [ATU_IN_MIN1 -1:0]                atu_reg_in_st_match_en;
    logic    [ATU_IN_MIN1 -1:0]                   atu_reg_in_single_addr_loc_en; // Enable to translate to a single address locaton only
    logic    [ATU_IN_MIN1 -1:0]                   atu_reg_in_msg_type_match_mode; // Mode enable to match any Msg Type
    // Response and mode settings 
    logic     [2*ATU_IN_MIN1 -1:0]                atu_reg_in_rsp_code;
    logic     [ATU_IN_MIN1 -1:0]                  atu_reg_in_fuzzy;
    logic     [ATU_IN_MIN1 -1:0]                  atu_reg_in_shift;
    logic     [ATU_IN_MIN1 -1:0]                  atu_reg_in_invert;
    logic     [ATU_IN_MIN1 -1:0]                  atu_reg_in_bar_match;
    // Region Enable
    logic     [ATU_IN_MIN1 -1:0]                  atu_reg_in_en;
    // Base, Limit and Target Registers 
    logic     [ATU_REG_WD*ATU_IN_MIN1 -1:0]       atu_reg_in_base;
    logic     [ATU_BASE_WD*ATU_IN_MIN1 -1:0]      atu_reg_in_upr_base;
    logic     [ATU_REG_WD*ATU_IN_MIN1 -1:0]       atu_reg_in_limit;
      logic     [4*ATU_IN_MIN1 -1:0]              atu_reg_in_cbuf_incr;
      logic     [ATU_IN_MIN1 -1:0]                atu_reg_in_cbuf_restart;
      logic                                       radm_outq_pkt_eot;
    
      logic     [ATU_UPR_LMT_WD*ATU_IN_MIN1 -1:0] atu_reg_in_uppr_limit;
    logic     [ATU_REG_WD*ATU_IN_MIN1 -1:0]       atu_reg_in_lwr_trgt;
    logic     [ATU_BASE_WD*ATU_IN_MIN1 -1:0]      atu_reg_in_upr_trgt;
    logic     [ATU_IN_MIN1-1:0]                   atu_reg_in_incr_rgn_size;    
    logic                                         halt_in;              
    logic [(64*NF)-1:0]                           cfg_bar0_mask;
    logic [(32*NF)-1:0]                           cfg_bar1_mask;
    logic [(64*NF)-1:0]                           cfg_bar2_mask;
    logic [(32*NF)-1:0]                           cfg_bar3_mask;
    logic [(64*NF)-1:0]                           cfg_bar4_mask;
    logic [(32*NF)-1:0]                           cfg_bar5_mask;
    logic [(32*NF)-1:0]                           cfg_rom_mask;
  } radm_cfg_atu_s;


  // RADM filter to ATU interface 
  // this struct is defined interface signals going from RADM filter modules to ATU block
  // This is th common struct for P, NP ATU 
  typedef struct packed {
      logic [63:0]                                 r_addr_out;
      logic [7:0]                                  r_func_out;
      logic [4:0]                                  r_type_out;
      logic [2:0]                                  r_bar_out;
      logic                                        r_rombar_out;
      logic [2:0]                                  r_tc_out;
      logic                                        r_td_out;
      logic [ATTR_WD-1:0]                          r_attr_out;
         logic [1:0]                                r_at_out;
       logic [7:0]                                  r_msgcode_out;
         logic r_th_out;
         logic [1:0]                                r_ph_out;
         logic [7:0]                                r_st_out;
    logic  [DW_LEN_WD-1:0]                          r_dw_len_out;
  } radm_flt_atu_s;


// localparam  RADM_FLT_ATU_SIZE       = $bits(radm_flt_atu_s);
// localparam  EXTRA_RADM_FLT_ATU_BITS = RADM_FLT_ATU_SIZE % RAS_PROT_RANGE ;
// localparam  EXTRA_RADM_FLT_ATU_PROT_BITS   = (EXTRA_RADM_FLT_ATU_BITS>0) ? 1'b1 : 1'b0;  
// localparam  RADM_FLT_ATU_PROT_WD = (RADM_FLT_ATU_SIZE/RAS_PROT_RANGE) + EXTRA_RADM_FLT_ATU_PROT_BITS ;

  
  typedef struct packed {
    logic                                         tlp_xlate;   
    logic  [ATU_IN_MIN1-1:0]                      atu_reg_match;
    logic  [ATU_IN_MIN1-1:0]                      sloc_match;
    logic  [ATU_IN_MIN1-1:0]                      cbuf_err;
    logic  [63:0]                                 addr_out;
    logic  [ATU_IN_MIN1-1:0][1:0]                 translated_err;
    logic  [63:0]                                 atu_bar_mask;
  } radm_atu_cpipe_s;

  typedef struct packed {
    logic                                         radm_atu_uppr_bytes_valid_int;   
    logic [63 : 0]                                radm_atu_translated_addr_int;
    logic [1:0]                                   radm_atu_translated_err_int;
    logic [$clog2(ATU_IN_MIN1)-1:0]               radm_atu_sloc_region_int;
    logic                                         radm_atu_sloc_match_int;
    logic                                         radm_atu_cbuf_err_int;
  } radm_atu_opipe_s;




localparam ATU_IPIPE_PROT_WD = ($bits(radm_flt_atu_s) / `CX_RAS_PROT_RANGE) + (($bits(radm_flt_atu_s) % `CX_RAS_PROT_RANGE) != 0);
localparam ATU_CPIPE_PROT_WD = ($bits(radm_atu_cpipe_s) / `CX_RAS_PROT_RANGE) + (($bits(radm_atu_cpipe_s) % `CX_RAS_PROT_RANGE) != 0);
localparam ATU_OPIPE_PROT_WD = ($bits(radm_atu_opipe_s) / `CX_RAS_PROT_RANGE) + (($bits(radm_atu_opipe_s) % `CX_RAS_PROT_RANGE) != 0);

 
  

  typedef struct packed {
    logic [1:0] radm_outq_pkt_fmt;
    logic [4:0] radm_outq_pkt_type;
    logic [2:0] radm_outq_pkt_tc;
    logic [ `FLT_Q_ATTR_WIDTH  -1 : 0 ] radm_outq_pkt_attr;
    logic [ `FLT_Q_DW_LENGTH_WIDTH -1  : 0] radm_outq_pkt_dw_len;
    logic [TAG_SIZE-1:0] radm_outq_pkt_tag;
    logic [ `FLT_Q_FUNC_NMBR_WIDTH -1 : 0] radm_outq_pkt_func_num;
    logic [7:0] radm_outq_pkt_msgcode;
    logic [ `FLT_Q_TD_WIDTH -1: 0] radm_outq_pkt_td;
    logic [ `FLT_Q_ROM_IN_RANGE_WIDTH -1:0] radm_outq_pkt_rom_in_range;
    logic [ `FLT_Q_IN_MEMBAR_RANGE_WIDTH -1: 0 ] radm_outq_pkt_in_membar_range;
    logic [ `FLT_Q_AT_WIDTH -1 : 0] radm_outq_pkt_ats;
    logic [1:0] radm_outq_pkt_ph;
    logic [7:0] radm_outq_pkt_st;
    logic [63:0] radm_atu_addr_in;
 } radm_outq_pkt_atu_s;

  // Config inputs from CDM to Filter modules
  // this struct has defined configuration interface signals from CDM to RADM filters
  // This is the common struct for P, NP and CPL (CDM to Filters)

  typedef struct packed {
    // Configurations 
    logic         [NF-1:0]                                  cfg_ecrc_chk_en;            // ECRC Check enables
    logic         [NF*6-1:0]                                cfg_bar_is_io;
    logic         [(24)-1:0]                                cfg_tc_struc_vc_map; 
    logic         [7:0]                                     cfg_tc_enable; 
    logic         [N_FLT_MASK-1:0]                          cfg_filter_rule_mask; 
    logic                                                   cfg_rcb_128; 
    logic         [PF_WD-1:0]                               cfg_max_func_num;
    logic         [3-1:0]                                   cfg_max_payload; 
    logic                                                   cfg_upstream_port;  
    logic                                                   cfg_root_compx;  
    logic                                                   cfg_endpoint;     
      logic                                                 cfg_obff_en; 
    logic         [NF-1:0]                                  pm_radm_block_tlp; 
     
      logic       [6:0]                                     ras_radm_prot_disable; 
        logic     [ERROR_INJ_EN_WD  -1:0]                   ras_err_inj_en_array; 
        logic     [ERROR_INJ_MASK_WD-1:0]                   ras_err_inj_mask; 
       logic      [(2*NF)-1:0]                              cfg_max_end2end_tlp_prfxs; 
    logic                                                   default_target; 
    logic                                                   ur_ca_mask_4_trgt1; 
    logic       [2-1:0]                                     cfg_target_above_config_limit; 
    logic                                                   cfg_cfg_tlp_bypass_en; 
    logic                                                   upstream_port; 
    logic       [(6*NF)-1:0]                                target_mem_map; 
    logic       [NF-1:0]                                    target_rom_map; 

    logic         [BUSNUM_WD-1:0]                           cfg_pbus_num; 
    logic         [DEVNUM_WD-1:0]                           cfg_pbus_dev_num; 

      logic                                                 cfg_ptm_enable; 

      logic       [`CX_REMOTE_RD_REQ_SIZE_PW-1:0]           cfg_remote_rd_req_bridge_size_dec;

          logic               cfg_ltr_m_en;
         logic                   cfg_p2p_err_rpt_ctrl; 
         logic                   cdm_core_in_dpc;
         logic                   dpc_fatal_err_gate;         // DPC trigger gating for fatal error message 
         logic                   dpc_nonfatal_err_gate; 
         logic  [7:0]     cfg_2ndbus_num;
         logic  [7:0]     cfg_subbus_num; 
      logic                   cfg_acs_validation_cap;
      logic                   cfg_acs_at_blocking_cap;
      logic                   cfg_acs_up_forward_cap;
      logic                   cfg_acs_validation_en;
      logic                   cfg_acs_at_blocking_en;
      logic                   cfg_acs_up_forward_en;
      logic   [3:0]           device_type;
      logic                   cxl_rcrb_enable;                   // RCRB is enabled
      logic                   cfg_cxl_alt_bme;                   // Alternate Bus Master Enable
      logic   [7:0]           cfg_cxl_alt_bus_base;              // Alternate Memory Base
      logic   [7:0]           cfg_cxl_alt_bus_limit;             // Alternate Memory Limit
  }  radm_cfg_i_s;

  // Address decoding inputs from CDM to Filter modules
  // this struct has defined  to get inputs from CDM after address decoding logic inside CDM
  typedef struct packed {
    // Configurations 
    logic         [(FX_TLP-N_TRGT1_INTF)*NF-1:0]                           cfg_io_match;       
      logic         [(FX_TLP-N_TRGT1_INTF)*NF-1:0]                         cfg_config_above_match; 
    logic         [((FX_TLP-N_TRGT1_INTF)*6*NF)-1:0]                       cfg_bar_match;    
    logic         [(FX_TLP-N_TRGT1_INTF)*NF-1:0]                           cfg_rom_match;   
      logic       [(FX_TLP-N_TRGT1_INTF)*NF-1:0]                           cfg_mem_match;
      logic       [(FX_TLP-N_TRGT1_INTF)*NF-1:0]                           cfg_prefmem_match;

    //logic       [(FX_TLP-N_TRGT1_INTF)-1:0]                                vendor_msg_id_match;  //// Not found 
      logic       [(FX_TLP-N_TRGT1_INTF)-1:0]                              cfg_rcrb_match;             // indication that tlp is within the RCRB region
      logic       [NF-1:0][(FX_TLP-N_TRGT1_INTF)-1:0]                      cfg_cxl_mbar0_match;        // indication that tlp is within the CXL Component Registers Memory Range
      logic               [(FX_TLP-N_TRGT1_INTF)-1:0]                      cxl_2_0_mbar0_access_int;   // indication that tlp is within the CXL Component Registers Memory Range in CDM
      logic       [((FX_TLP-N_TRGT1_INTF)*NF)-1:0]                         cfg_cxl_alt_prefmem_match;  // indication that tlp is within Prefetchable Alternate Memory Range
      logic       [((FX_TLP-N_TRGT1_INTF)*NF)-1:0]                         cfg_cxl_alt_mem_match;      // indication that tlp is within Alternate Memory Range
      logic       [(FX_TLP-N_TRGT1_INTF)-1:0]                              cfg_rcrb_mbar0_match;       // indication that tlp is within the RCRB MEMBAR0 region
      logic       [(FX_TLP-N_TRGT1_INTF)-1:0]                              cfg_rcrb_mbar0_match_int;   // indication that tlp is within the RCRB MEMBAR0 region in CDM 
  }  radm_cfg_ntlp_ntrgt_i_s;

  typedef struct packed {
    // Configurations 
    logic         [2*NF-1:0]                                cfg_io_match;       
      logic         [2*NF-1:0]                              cfg_config_above_match; 
    logic         [(2*NF*6)-1:0]                            cfg_bar_match;    
    logic         [2*NF-1:0]                                cfg_rom_match;   
      logic       [2*NF-1:0]                                cfg_mem_match;
      logic       [2*NF-1:0]                                cfg_prefmem_match;
    //logic       [2-1:0]                                     vendor_msg_id_match;  //// Not found 
      logic       [1:0]                                     cfg_rcrb_match;                    // indication that tlp is within the RCRB region
      logic       [NF-1:0][1:0]                             cfg_cxl_mbar0_match;               // indication that tlp is within the CXL Component Registers Memory Range
      logic               [1:0]                             cxl_2_0_mbar0_access_int;          // indication that tlp is within the CXL Component Registers Memory Range in CDM
      logic       [2*NF-1:0]                                cfg_cxl_alt_prefmem_match;  // indication that tlp is within Prefetchable Alternate Memory Range
      logic       [2*NF-1:0]                                cfg_cxl_alt_mem_match;      // indication that tlp is within Alternate Memory Range
      logic       [1:0]                                     cfg_rcrb_mbar0_match;              // indication that tlp is within the RCRB MEMBAR0 region 
      logic       [1:0]                                     cfg_rcrb_mbar0_match_int;          // indication that tlp is within RCRB MEMBAR0 in CDM
  }  radm_cfg_ntlp_i_s;

  // Address decoding inputs from CDM to Filter modules
  // this struct has defined to get inputs from CDM after remap_per_tlp_to_per_func logic in the radm_filter_dmux_trgt1 module.
  typedef struct packed {
    // Configurations 
    logic         [2*NF-1:0]                                cfg_io_match;       
      logic         [2*NF-1:0]                              cfg_config_above_match; 
    logic         [(2*NF*6)-1:0]                            cfg_bar_match;    
    logic         [2*NF-1:0]                                cfg_rom_match;   
      logic       [2*NF-1:0]                                cfg_mem_match;
      logic       [2*NF-1:0]                                cfg_prefmem_match;
    //logic       [2-1:0]                                     vendor_msg_id_match;  //// Not found 
      logic       [1:0]                                     cfg_rcrb_match;                    // indication that tlp is within the RCRB region
      logic       [1:0][NF-1:0]                             cfg_cxl_mbar0_match;               // indication that tlp is within the CXL Component Registers Memory Range
      logic       [1:0]                                     cxl_2_0_mbar0_access_int;          // indication that tlp is within the CXL Component Registers Memory Range in CDM
      logic       [2*NF-1:0]                                cfg_cxl_alt_prefmem_match;  // indication that tlp is within Prefetchable Alternate Memory Range
      logic       [2*NF-1:0]                                cfg_cxl_alt_mem_match;      // indication that tlp is within Alternate Memory Range
      logic       [1:0]                                     cfg_rcrb_mbar0_match;              // indication that tlp is within the RCRB MEMBAR0 region 
      logic       [1:0]                                     cfg_rcrb_mbar0_match_int;          // indication that tlp is within RCRB MEMBAR0 in CDM
  }  radm_cfg_ntlp_nf_s;

  // Address decoding inputs from CDM to Filter modules
  // this struct has defined  to get inputs from CDM after address decoding logic inside CDM
  typedef struct packed {
    // Configurations 
    logic         [NF-1:0]                                  cfg_io_match;       
      logic         [NF-1:0]                                cfg_config_above_match; 
    logic         [(6*NF)-1:0]                              cfg_bar_match;    
    logic         [NF-1:0]                                  cfg_rom_match;   
      logic [NF-1:0]                                        cfg_mem_match;
      logic [NF-1:0]                                        cfg_prefmem_match;
//    logic                                                   vendor_msg_id_match;  //// Not found 
      logic                                                 cfg_rcrb_match;             // indication that tlp is within the RCRB region
      logic       [NF-1:0]                                  cfg_cxl_mbar0_match;        // indication that tlp is within the CXL Component Registers Memory Range
      logic                                                 cxl_2_0_mbar0_access_int;   // indication that tlp is within the CXL Component Registers Memory Range in CDM
      logic       [NF-1:0]                                  cfg_cxl_alt_prefmem_match;  // indication that tlp is within Prefetchable Alternate Memory Range
      logic       [NF-1:0]                                  cfg_cxl_alt_mem_match;      // indication that tlp is within Alternate Memory Range
      logic                                                 cfg_rcrb_mbar0_match;              // indication that tlp is within the RCRB MEMBAR0 region 
      logic                                                 cfg_rcrb_mbar0_match_int;          // indication that tlp is within RCRB MEMBAR0 in CDM
  }  radm_cfg_tlp_i_s;
    

  //  Signals from RADM filters to CDM module 
  // this struct has defined  to sends signals from RADM filters to CDM module to update status
  // errors. prefixes and logs in the respective registers in the CDM block
  typedef struct packed {
    // Configurations 
       logic        [FX_TLP-1:0]                    radm_ptm_req; 
       logic        [FX_TLP-1:0]                    radm_ptm_res_msg; 
       logic        [FX_TLP-1:0]                    radm_ptm_res_d_msg; 
       logic        [FX_TLP*64-1:0]                 radm_ptm_master_time; 
       logic        [FX_TLP*32-1:0]                 radm_ptm_prop_delay; 
     //logic          [FX_TLP*64-1:0]               flt_cdm_addr; 
     logic          [FX_TLP*PF_WD-1:0]              flt_cdm_pf; 
     logic          [FX_TLP-1:0]                    radm_ecrc_err; 
     logic          [FX_TLP-1:0]                    radm_mlf_tlp_err; 
       logic        [FX_TLP*8-1:0]                  radm_mlf_tlp_err_ptr; 
     logic          [FX_TLP*NF-1:0]                 radm_rcvd_wreq_poisoned; 
     logic          [FX_TLP*NF-1:0]                 radm_rcvd_req_ur; 
     logic          [FX_TLP-1:0]                    radm_rcvd_req_ca; 
     logic          [FX_TLP*NF-1:0]                 radm_hdr_log_valid; 
     logic          [FX_TLP*128-1:0]                radm_hdr_log; 
       logic        [FX_TLP*128-1:0]                radm_tlp_prfx_log; 


    
     logic          [FX_TLP*64-1:0]                 radm_msg_payload; 
     logic          [FX_TLP-1:0]                    radm_pm_to_ack; 
       logic          [FX_TLP-1:0]                    radm_slot_pwr_limit;
       logic          [FX_TLP-1:0]                  radm_pm_turnoff; 
       logic          [FX_TLP-1:0]                  radm_pm_asnak; 
       logic          [FX_TLP-1:0]                  radm_msg_unlock; 
     logic          [FX_TLP-1:0]                    radm_vendor_msg; 
     logic          [FX_TLP-1:0]                    radm_vendor_msg_type;
       logic        [FX_TLP-1:0]                    radm_msg_idle; 
       logic        [FX_TLP-1:0]                    radm_msg_obff; 
       logic        [FX_TLP-1:0]                    radm_msg_cpu_active; 
     logic [FX_TLP*16-1:0]                          radm_rcvd_tlp_req_id; 
     logic          [FX_TLP-1:0]                   flt_dwlenEq0; 
     logic          [FX_TLP-1:0]                   tlp_poisoned; 
     logic          [FX_TLP*8-1:0]                 radm_snoop_bus_num; 
     logic          [FX_TLP*5-1:0]                 radm_snoop_dev_num; 
     logic          [SNOOP_VPD_WD -1:0]            radm_snoop_upd;
     logic          [FX_TLP*9-1:0]                          cfg_segment_id;

     logic        [FX_TLP-1:0]                  radm_rcvd_cpl_poisoned;
     logic        [FX_TLP-1:0]                  radm_rcvd_cpl_ur;
     logic        [FX_TLP-1:0]                  radm_rcvd_cpl_ca;
     logic        [FX_TLP-1:0]                  radm_unexp_cpl_err;

     logic   [FX_TLP-1:0] int_radm_pm_pme      ;
     logic   [FX_TLP-1:0] radm_inta_asserted      ;
     logic   [FX_TLP-1:0] radm_intb_asserted      ;
     logic   [FX_TLP-1:0] radm_intc_asserted      ;
     logic   [FX_TLP-1:0] radm_intd_asserted      ;
     logic   [FX_TLP-1:0] radm_inta_deasserted    ;
     logic   [FX_TLP-1:0] radm_intb_deasserted    ;
     logic   [FX_TLP-1:0] radm_intc_deasserted    ;
     logic   [FX_TLP-1:0] radm_intd_deasserted    ;
     logic   [FX_TLP-1:0] radm_err_cor;
     logic   [FX_TLP-1:0] radm_err_nf;
     logic   [FX_TLP-1:0] radm_err_f;
     logic [FX_TLP-1:0] radm_drs_msg   ;
     logic [FX_TLP-1:0] radm_frs_msg   ;
     logic [FX_TLP*4-1:0]  radm_frs_msg_reason;
     logic  [FX_TLP-1:0]             radm_msg_ltr;            
     logic  [FX_TLP*32-1:0]          radm_msg_ltr_latency;    

  logic [FX_TLP-1:0] radm_rcvd_acs_err;

    // configurations end 
  }  radm_cfg_ntlp_ntrgt_o_s;


  // config output
  // Signals from RADM filters to CDM module 
  // this struct has defined  to sends signals from RADM filters to CDM module to update status
  // errors. prefixes and logs in the respective registers in the CDM block
  typedef struct packed {
    // Configurations 
       logic        [3-1:0]                    radm_ptm_req; 
       logic        [3-1:0]                    radm_ptm_res_msg; 
       logic        [3-1:0]                    radm_ptm_res_d_msg; 
       logic        [3*64-1:0]                 radm_ptm_master_time; 
       logic        [3*32-1:0]                 radm_ptm_prop_delay; 
     //logic          [3*64-1:0]                 flt_cdm_addr; 
     logic          [3*PF_WD-1:0]              flt_cdm_pf;
     logic          [3-1:0]                    radm_ecrc_err; 
     logic          [3-1:0]                    radm_mlf_tlp_err; 
       logic        [3*8-1:0]                  radm_mlf_tlp_err_ptr; 
     logic          [3*NF-1:0]                 radm_rcvd_wreq_poisoned; 
     logic          [3*NF-1:0]                 radm_rcvd_req_ur; 
     logic          [3-1:0]                    radm_rcvd_req_ca; 
     logic          [3*NF-1:0]                 radm_hdr_log_valid; 
     logic          [3*128-1:0]                radm_hdr_log; 
       logic        [3*128-1:0]                radm_tlp_prfx_log; 



     logic          [3*64-1:0]                 radm_msg_payload; 
       logic          [3-1:0]                  radm_slot_pwr_limit; 
       logic          [3-1:0]                  radm_pm_asnak; 
       logic          [3-1:0]                  radm_pm_turnoff; 
       logic          [3-1:0]                  radm_msg_unlock; 
     logic          [3-1:0]                    radm_pm_to_ack; 
     logic          [3-1:0]                    radm_vendor_msg; 
     logic          [3-1:0]                    radm_vendor_msg_type; 
       logic        [3-1:0]                    radm_msg_idle; 
       logic        [3-1:0]                    radm_msg_obff; 
       logic        [3-1:0]                    radm_msg_cpu_active; 
     logic [3*16-1:0]                          radm_rcvd_tlp_req_id; 
     logic          [3-1:0]                   flt_dwlenEq0; 
     logic          [3-1:0]                   tlp_poisoned; 
     logic          [3*8-1:0]                 radm_snoop_bus_num; 
     logic          [3*5-1:0]                 radm_snoop_dev_num; 
     logic          [SNOOP_VPD_WD -1:0]       radm_snoop_upd;
     logic          [3*9-1:0]                          cfg_segment_id;
     logic        [3-1:0]                  radm_rcvd_cpl_poisoned;
     logic        [3-1:0]                  radm_rcvd_cpl_ur;
     logic        [3-1:0]                  radm_rcvd_cpl_ca;
     logic        [3-1:0]                  radm_unexp_cpl_err;

     logic   [3-1:0] int_radm_pm_pme      ;
     logic   [3-1:0] radm_inta_asserted      ;
     logic   [3-1:0] radm_intb_asserted      ;
     logic   [3-1:0] radm_intc_asserted      ;
     logic   [3-1:0] radm_intd_asserted      ;
     logic   [3-1:0] radm_inta_deasserted    ;
     logic   [3-1:0] radm_intb_deasserted    ;
     logic   [3-1:0] radm_intc_deasserted    ;
     logic   [3-1:0] radm_intd_deasserted    ;
     //logic   [3-1:0] cfg_p2p_err_rpt_ctrl;
     logic   [3-1:0] radm_err_cor;
     logic   [3-1:0] radm_err_nf;
     logic   [3-1:0] radm_err_f;
     logic [3-1:0] radm_drs_msg   ;
     logic [3-1:0] radm_frs_msg   ;
     logic [3*4-1:0]  radm_frs_msg_reason;
     logic  [3-1:0]             radm_msg_ltr;            
     logic  [3*32-1:0]          radm_msg_ltr_latency;    

  logic [3-1:0] radm_rcvd_acs_err;

    // configurations end 
  }  radm_cfg_ntlp_o_s;

  // Signals from RADM filters to CDM module 
  // this struct has defined  to sends signals from RADM filters to CDM module to update status
  // errors. prefixes and logs in the respective registers in the CDM block
  typedef struct packed {
    // Configurations 
       logic                                                radm_ptm_req; 
       logic                                                radm_ptm_res_msg; 
       logic                                                radm_ptm_res_d_msg; 
       logic        [64-1:0]                                radm_ptm_master_time; 
       logic        [32-1:0]                                radm_ptm_prop_delay; 
     //logic          [64-1:0]                                flt_cdm_addr; 
     logic          [PF_WD-1:0]                             flt_cdm_pf;
     logic                                                  radm_ecrc_err; 
     logic                                                  radm_mlf_tlp_err; 
       logic        [8-1:0]                                 radm_mlf_tlp_err_ptr; 
     logic          [NF-1:0]                                radm_rcvd_wreq_poisoned; 
     logic          [NF-1:0]                                radm_rcvd_req_ur; 
     logic                                                  radm_rcvd_req_ca; 
     logic          [NF-1:0]                                radm_hdr_log_valid; 
     logic          [128-1:0]                               radm_hdr_log; 
       logic        [128-1:0]                               radm_tlp_prfx_log; 



     logic          [64-1:0]                                radm_msg_payload; 
       logic                                                radm_slot_pwr_limit; 
       logic                                                radm_pm_asnak; 
       logic                                                radm_pm_turnoff; 
       logic                                                radm_msg_unlock; 
     logic                                                  radm_pm_to_ack; 
     logic                                                  radm_vendor_msg; 
     logic                                                  radm_vendor_msg_type; 
       logic                                                radm_msg_idle; 
       logic                                                radm_msg_obff; 
       logic                                                radm_msg_cpu_active; 
     logic [16-1:0]                                         radm_rcvd_tlp_req_id; 
     logic                                                  flt_dwlenEq0; 
     logic                                                  tlp_poisoned; 
     logic          [8-1:0]                                 radm_snoop_bus_num; 
     logic          [5-1:0]                                 radm_snoop_dev_num; 
     logic          [SNOOP_VPD_WD -1:0]                     radm_snoop_upd;
     logic          [8:0]                          cfg_segment_id;
     logic                                          radm_rcvd_cpl_poisoned;
     logic                                          radm_rcvd_cpl_ur;
     logic                                          radm_rcvd_cpl_ca;
     logic                                          radm_unexp_cpl_err;
        logic   int_radm_pm_pme      ;
        logic   radm_inta_asserted      ;
        logic   radm_intb_asserted      ;
        logic   radm_intc_asserted      ;
        logic   radm_intd_asserted      ;
        logic   radm_inta_deasserted    ;
        logic   radm_intb_deasserted    ;
        logic   radm_intc_deasserted    ;
        logic   radm_intd_deasserted    ;
    // logic cfg_p2p_err_rpt_ctrl;
        logic radm_err_cor;
        logic radm_err_nf;
        logic radm_err_f;
        logic  radm_drs_msg   ;
        logic  radm_frs_msg   ;
        logic [4-1:0] radm_frs_msg_reason;
        logic           radm_msg_ltr;            
        logic [31:0]    radm_msg_ltr_latency;    

  logic radm_rcvd_acs_err;

    // configurations end 
  }  radm_cfg_tlp_o_s;

//  Following struct is for HDR and DATA FIFO read information to calculate credits in the order manager to generate halt back to FormQ
  typedef struct packed {
    logic                      data_fifo_rd;
    logic                      hdr_fifo_rd;
  } trgt_fifo_rd_grnt_s;


  typedef struct packed {
    trgt_fifo_rd_grnt_s [2:0]     trgt_grnt_trgt1;
  } trgt_grnt_trgt1_s;

  typedef struct packed {
    trgt_grnt_trgt1_s [N_TRGT1_INTF-1:0]  trgt_grnt_trgt1_top;
  } trgt_grnt_top_s;


 typedef struct packed {
     logic                            ord_flt_dv;            // Output Data Valid
     logic   [(DW+DATA_PROT_WD)-1:0]  ord_flt_data;          // Output Data
     logic                            ord_flt_eot;           // Output End of TLP
     logic   [NW-1:0]                 ord_flt_dwen;          // Output Data Bus DW Enable
     logic                            ord_flt_dllp_err;      // Output Data Link Layer Error
     logic   [PKT_ORD_WD-1:0]         ord_flt_p_pkt_num;    
     logic                            ord_flt_poisoned;
     logic                            ord_flt_malformed_tlp_err;
 } radm_ord_mgr_flt_data_s;





  // this struct has defined  for interface between header decoder to Filter modules
  typedef struct packed {
      logic [PRFX_WD+PRFX_WD_PAR-1:0]         hdr_dec_flt_prfx;
      logic [22:0]                hdr_dec_flt_pasid_er_pmr_pv;
      logic                       radm_malf_tlp_err_hdr;
      logic                       radm_malf_tlp_err_hdr_prfx;
      logic                       radm_malf_tlp_err_hdr_flit;
      logic   [NHW-1:0]           hdr_dec_flt_prfx_dwen;
    logic [HW_NFT+HW_NFT_PAR - 1 :0]         hdr_dec_flt_hdr;
    logic                         hdr_dec_flt_hdr_dwen;
    logic                         hdr_dec_flt_hv;
      logic [52 : 0]              hdr_dec_flt_c_d_r_14bit_t;
      radm_hdr_log_rcvd_flds_s    log_rcvd_flds ; 
    logic [NP_REQ_TX_TYPE_WD-1:0] hdr_dec_np_req_type;
  } radm_hdr_dec_flt_s;

  // this struct has defined  for interface forrr CPL TLP
  typedef struct packed {
    logic [14-1:0]       tlp_tag_14bit_in;
    logic [TAG_SIZE-1:0] tlp_tag;
    logic [4:0]          tlp_type;
    logic                tlp_has_pyld;
    logic [11:0]         tlp_cpl_byte_count;
    logic [4:0]          tlp_cpl_la_addr;
    logic [7:0]          tlp_msg_code;
    logic [15:0]         tlp_rid;
    logic [15:0]         tlp_cpl_id;
    logic [15:0]         tlp_cpl_dest_id;
    logic [63:0]         tlp_addr;
  } radm_hdr_dec_com_tlp_s;

  // Following struct has defined for E2E prefix signal declaration, e2e prefix decoding related signals
  typedef struct packed {
    logic [31:0]        ohc_e1_dw0;
    logic [31:0]        ohc_e2_dw0;
    logic [31:0]        ohc_e2_dw1;
    logic [31:0]        ohc_e4_dw0;
    logic [31:0]        ohc_e4_dw1;
    logic [31:0]        ohc_e4_dw2;
    logic [31:0]        ohc_e4_dw3;
  } radm_hdr_dec_com_ohc_dw_s;

  typedef struct packed {
    logic               ohc_e1_present;
    logic               ohc_e2_present;
    logic               ohc_e4_present;
  } radm_hdr_dec_com_ohc_ex_present_s;

  
      
  // Following struct has defined for data and header interface signals between filters to demux/VC arbiter module 
  typedef struct packed {
    logic [2:0]                     cpl_status_trgt0; // sideband cpl_status to trgt0 to align with HV while sending it to TRGT0. This is specific to store and forward mode and only propagated to TRGT0 to return completion"
    logic                           flt_q_tlp_poisoned;
    logic                           radm_hdr_log_vld;
    logic                           radm_hdr_log_vld_all_fn;
    logic [5-1:0]                   radm_hdr_log_err_index;
    logic [DW+DATA_PAR_WD-1:0]      flt_q_data;
    logic                           flt_q_hv;
    logic                           flt_q_dv;
    logic                           flt_q_eot;
    logic [NW-1:0]                  flt_q_dwen;
    logic                           flt_q_tlp_abort;
    logic                           flt_q_dllp_abort;
    logic                           flt_q_ecrc_err;
    logic                           flt_q_parerr;
    flt_hdr_s                       flt_q_header;
  } flt_q_dmux_o_s;


  typedef struct packed {
    logic [PKT_ORD_WD-1:0]          flt_pkt_num;

    flt_hdr_s                       flt_q_header;

  } fifo_hdr_dmux_o_s;

  typedef struct packed {
    logic [NW-1:0]                  flt_q_dwen;
    logic [DW+DATA_PAR_WD-1:0]      flt_q_data;

  } fifo_data_dmux_o_s;


// Inputs to Header log module when APP_VEC_TLP_INTF defined.
  typedef struct packed {
    logic                           hlog_vld;
    logic                           hlog_all_fns;
    logic [4:0]                     hlog_err_index;                           
    logic [`CX_NPRFX-1:0][31:0]     hlog_tlp_prfx; // (FM: Local, NFM: Local/E2E)
    logic [`CX_RX_HDW_MS-1:0][31:0] hlog_tlp_hdr;  // (FM: Hdr/OHC, NFM: Hdr)  
    logic [`CX_RX_HDW_MS-1:0]       hlog_tlp_hdr_dwen;
    logic                           hlog_cdm_err_advisory;
//`ifdef CX_IDE_ENABLE
//    logic                           phe_encrypted_be;
 //   logic [3:0]                     phe_encrypted_addr_size;
//`endif // CX_IDE_ENABLE
  } pktstr_hlog_s;


// All Filter inputs in STRUCT
  typedef struct packed {
      logic    rtlh_flt_parerr;
      radm_hdr_dec_flt_s        flt_in_hdr;
      radm_ord_mgr_flt_data_s   flt_in_data;
  } flt_in_s;

  typedef struct packed {
      logic [15:0]         flt_cpl_lut_rid;
      logic                flt_cpl_lut_dllp_err;
      logic                flt_cpl_lut_eot;
      logic [127:0]        flt_cpl_lut_hdr;
      logic                flt_cpl_lut_hv;
      logic [TAG_SIZE-1:0] flt_cpl_lut_tag;
      logic [4-1:0]        flt_cpl_lut_uppr_4bit_tag;
  } flt_cpl_lut_s;

typedef struct packed {
  logic [NF-1:0]            cfg_ecrc_chk_en;            // ECRC Check enables
  logic [2:0]               flit_mode_en;
  logic [2:0]               current_data_rate;
  logic [3:0]               device_type;
  logic                     cfg_upstream_port;
  logic                     cfg_root_compx;
  logic                     cfg_endpoint;
  logic [N_FLT_MASK-1:0]    cfg_filter_rule_mask;
  logic [DEVNUM_WD -1:0]    cfg_pbus_dev_num;
  logic [BUSNUM_WD -1:0]    cfg_pbus_num;
  logic [7:0]               cfg_tc_enable;
  logic [PF_WD-1:0]         cfg_max_func_num;
  logic [2:0]               cfg_max_payload;
  logic [23:0]              cfg_tc_struc_vc_map;
  logic [(4*NF)-1:0]        cfg_cpl_timeout_range;
  logic [(NF-1):0]          cfg_cpl_timeout_disable;
} radm_qstatic_s;
  
localparam CX_HDR_LOG_P_FIFO_DP   = `CX_HDR_LOG_P_FIFO_DP   ;
localparam CX_HDR_LOG_CPL_FIFO_DP = `CX_HDR_LOG_CPL_FIFO_DP ;
localparam CX_HDR_LOG_NP_FIFO_DP  = `CX_HDR_LOG_NP_FIFO_DP  ;

// This struct is the different header fields decoded in the filter module from incoming header
// This is specific struct for P header format (Only Posted relevant fields are stored inside FIFO)
typedef struct packed {
  logic                                                flt_q_td_hdr_log ;
  logic                                                flt_q_fmt2; // second [2] bit of FMT field used to detect reserved TLP in FLIT mode   
  logic [TRGT1_ADDR_WD-1:0]                            flt_q_hdr_uppr_bytes;  
  logic [PKT_ORD_WD-1:0]                               flt_pkt_num;
    logic                                                radm_atu_uppr_bytes_valid;
   //`ifdef CX_ATU_SLOC_CBUF
   //   logic [$clog2(ATU_IN_MIN1)-1:0]                    radm_atu_sloc_region;
   //   logic                                              radm_atu_sloc_match;
   //   logic                                              radm_atu_cbuf_err;
   //`endif //CX_ATU_SLOC_CBUF
  //`ifdef ATS_RX_ENABLE
  //  logic                                                flt_q_nw;
  //`ifdef CX_CXL_ENABLE
  //  logic                                                flt_q_cxlsrc;
  //`endif
  //`endif
    logic [1:0]                                          flt_q_ph;
    logic [7:0]                                          flt_q_st;
    // logic [ST_WD -1 :0]                                  flt_q_ohc_b_st_lb; 
    // logic [7:0]                                          hdr_dec_flt_cpltr_seg; 
    logic [8:0]                                          hdr_dec_flt_dest_seg; 
    logic [8:0]                                          hdr_dec_flt_reqtr_seg; 
  //`ifdef CX_CCIX_INTERFACE_ENABLE
  //  logic [`FLT_Q_CCIX_WIDTH-1:0]                        flt_q_ccix;               // Indicate the VC on which the TLP has been received (0=PCIe_VC, 1=CCIX_VC)                 
  //`endif // CX_CCIX_INTERFACE_ENABLE
  logic [`FLT_Q_LSTDW_BE_WIDTH-1:0]                      flt_q_last_be;            // TRGT1 and cpl_gen control (Last Byte Enable)      
  // logic [`FLT_Q_CPL_LAST_WIDTH-1:0]                      flt_q_cpl_last;           // CPL Control                 
    logic [`FLT_Q_AT_WIDTH-1:0]                          flt_q_ats;                // Provides support of PCI-SIG ATS specification
  logic [`FLT_Q_EP_WIDTH-1:0]                            flt_q_poisoned;           // CPL TLP EP
    logic [`FLT_Q_TH_WIDTH-1:0]                          flt_q_th;                 // CPL TLP TH (Processing Hints)
  logic [`FLT_Q_TD_WIDTH-1:0]                            flt_q_td;                 // CPL TLP TD (Digest)
  // logic [`FLT_Q_CPL_LOWER_ADDR_WIDTH-1:0]                flt_q_cpl_lower_addr;     // CPL TLP LOWER ADDR 
  // logic [`FLT_Q_BCM_WIDTH-1:0]                           flt_q_cpl_bcm;            // CPL TLP BCM (Byte Count Modified)               
  // logic [`FLT_Q_CMPLTR_ID_WIDTH-1:0]                     flt_q_cplid;              // CPL TLP Completer ID                  
  // logic [`FLT_Q_BYTE_CNT_WIDTH-1:0]                      flt_q_byte_cnt;           // CPL Byte Count         
  logic [`FLT_Q_ADDR_WIDTH-1:0]                          flt_q_addr;               // completion hdr &  TRGT0 control
  logic [`FLT_Q_FRSTDW_BE_WIDTH-1:0]                     flt_q_first_be;           // completion hdr &  TRGT0 control            
  // logic [`FLT_Q_IO_REQ_IN_RANGE_WIDTH-1:0]               flt_q_io_req_in_range;    // TLP Header field IO_REQ_IN_RANGE
    logic [`FLT_Q_ROM_IN_RANGE_WIDTH-1:0]                flt_q_rom_req_in_range;   // TLP Header field ROM_IN_RANGE
    logic [`FLT_Q_IN_MEMBAR_RANGE_WIDTH-1:0]             flt_q_in_membar_range;    // TLP Header field IN_MEMBAR_RANGE
  logic [`FLT_Q_DW_LENGTH_WIDTH-1:0]                     flt_q_dw_len;             // CPL Data Payload Size            
  //`ifdef CX_TLP_PREFIX_ENABLE  
  //  logic [`FLT_Q_PRFX_WIDTH-1:0]                        flt_q_prfx;               // Prefix (Including parity)
  //`endif // CX_TLP_PREFIX_ENABLE
  logic [`FLT_Q_CPL_STATUS_WIDTH-1:0]                    flt_q_cpl_status;         // Status Of The Completion   
  logic [`FLT_Q_FUNC_NMBR_WIDTH-1:0]                     flt_q_func_nmbr;          // Physical Function Number
  logic [`FLT_Q_TAG_WIDTH-1:0]                           flt_q_TAG;                // CPL TLP TAG
  logic [`FLT_Q_REQID_WIDTH-1:0]                         flt_q_REQID;              // CPL TLP Requester ID             
  logic [`FLT_Q_ATTR_WIDTH-1:0]                          flt_q_attr;               // CPL TLP ATTR (Attributes)                     
  logic [`FLT_Q_TC_WIDTH-1:0]                            flt_q_tc;                 // CPL TLP TC (Traffic Class)             
  logic [5-1:0]                                          flt_q_type;               // TLP TYPE            
  hdr_fmt                                                flt_q_fmt;                // TLP Format                
  hdr_destination                                        flt_q_destination;        // TLP Destination  
} flt_p_hdr_s ;


// This struct is the different header fields decoded in the filter module from incoming header
// This is specific struct for NP header format (Only Non-Posted relevant fields are stored inside FIFO)
typedef struct packed {
    logic                                                flt_q_td_hdr_log ;
    logic                                                flt_q_fmt2; // second [2] bit of FMT field used to detect reserved TLP in FLIT mode   
    logic [PKT_ORD_WD-1:0]                               flt_pkt_num;
    // logic [TRGT1_ADDR_WD-1:0]                            flt_q_hdr_uppr_bytes;
  //`ifdef CX_ATU_CTRL_EN
  //  // logic                                                radm_atu_uppr_bytes_valid;
  // `ifdef CX_ATU_SLOC_CBUF
  //    logic [$clog2(ATU_IN_MIN1)-1:0]                    radm_atu_sloc_region;
  //    logic                                              radm_atu_sloc_match;
  //    logic                                              radm_atu_cbuf_err;
  //  `endif //CX_ATU_SLOC_CBUF
  //`endif // CX_ATU_CTRL_EN
    logic                                                flt_q_nw;
    logic                                                flt_q_cxlsrc;
    logic [1:0]                                          flt_q_ph;
    logic [7:0]                                          flt_q_st;
    // logic [ST_WD -1 :0]                                  flt_q_ohc_b_st_lb; 
    // logic [7:0]                                          hdr_dec_flt_cpltr_seg; 
    logic [8:0]                                          hdr_dec_flt_dest_seg; 
    logic [8:0]                                          hdr_dec_flt_reqtr_seg; 
  //`ifdef CX_CCIX_INTERFACE_ENABLE
  //  logic [`FLT_Q_CCIX_WIDTH-1:0]                        flt_q_ccix;               // Indicate the VC on which the TLP has been received (0=PCIe_VC, 1=CCIX_VC)                 
  //`endif // CX_CCIX_INTERFACE_ENABLE
  logic [`FLT_Q_LSTDW_BE_WIDTH-1:0]                      flt_q_last_be;            // TRGT1 and cpl_gen control (Last Byte Enable)      
  // logic [`FLT_Q_CPL_LAST_WIDTH-1:0]                      flt_q_cpl_last;           // CPL Control                 
    logic [`FLT_Q_AT_WIDTH-1:0]                          flt_q_ats;                // Provides support of PCI-SIG ATS specification
  logic [`FLT_Q_EP_WIDTH-1:0]                            flt_q_poisoned;           // CPL TLP EP
    logic [`FLT_Q_TH_WIDTH-1:0]                          flt_q_th;                 // CPL TLP TH (Processing Hints)
  logic [`FLT_Q_TD_WIDTH-1:0]                            flt_q_td;                 // CPL TLP TD (Digest)
  // logic [`FLT_Q_CPL_LOWER_ADDR_WIDTH-1:0]                flt_q_cpl_lower_addr;     // CPL TLP LOWER ADDR 
  // logic [`FLT_Q_BCM_WIDTH-1:0]                           flt_q_cpl_bcm;            // CPL TLP BCM (Byte Count Modified)               
  // logic [`FLT_Q_CMPLTR_ID_WIDTH-1:0]                     flt_q_cplid;              // CPL TLP Completer ID                  
  // logic [`FLT_Q_BYTE_CNT_WIDTH-1:0]                      flt_q_byte_cnt;           // CPL Byte Count         
  logic [`FLT_Q_ADDR_WIDTH-1:0]                          flt_q_addr;               // completion hdr &  TRGT0 control
  logic [`FLT_Q_FRSTDW_BE_WIDTH-1:0]                     flt_q_first_be;           // completion hdr &  TRGT0 control            
  logic [`FLT_Q_IO_REQ_IN_RANGE_WIDTH-1:0]               flt_q_io_req_in_range;    // TLP Header field IO_REQ_IN_RANGE
    logic [`FLT_Q_ROM_IN_RANGE_WIDTH-1:0]                flt_q_rom_req_in_range;   // TLP Header field ROM_IN_RANGE
    logic [`FLT_Q_IN_MEMBAR_RANGE_WIDTH-1:0]             flt_q_in_membar_range;    // TLP Header field IN_MEMBAR_RANGE
  logic [`FLT_Q_DW_LENGTH_WIDTH-1:0]                     flt_q_dw_len;             // CPL Data Payload Size            
  //`ifdef CX_TLP_PREFIX_ENABLE  
  //  logic [`FLT_Q_PRFX_WIDTH-1:0]                        flt_q_prfx;               // Prefix (Including parity)
  //`endif // CX_TLP_PREFIX_ENABLE
  logic [`FLT_Q_CPL_STATUS_WIDTH-1:0]                    flt_q_cpl_status;         // Status Of The Completion   
  logic [`FLT_Q_FUNC_NMBR_WIDTH-1:0]                     flt_q_func_nmbr;          // Physical Function Number
  logic [`FLT_Q_TAG_WIDTH-1:0]                           flt_q_TAG;                // CPL TLP TAG
  logic [`FLT_Q_REQID_WIDTH-1:0]                         flt_q_REQID;              // CPL TLP Requester ID             
  logic [`FLT_Q_ATTR_WIDTH-1:0]                          flt_q_attr;               // CPL TLP ATTR (Attributes)                     
  logic [`FLT_Q_TC_WIDTH-1:0]                            flt_q_tc;                 // CPL TLP TC (Traffic Class)             
  logic [5-1:0]                                          flt_q_type;               // TLP TYPE            
  hdr_fmt                                                flt_q_fmt;                // TLP Format                
  hdr_destination                                        flt_q_destination;        // TLP Destination  
} flt_np_hdr_s ;

// This struct is the different header fields decoded in the filter module from incoming header
// This is specific struct for CPL header format (Only completion relevant fields are stored inside FIFO)
typedef struct packed {
    logic                                                flt_q_td_hdr_log ;
    logic                                                flt_q_fmt2; // second [2] bit of FMT field used to detect reserved TLP in FLIT mode   
    logic [PKT_ORD_WD-1:0]                               flt_pkt_num;
    // logic [TRGT1_ADDR_WD-1:0]                            flt_q_hdr_uppr_bytes;
  // `ifdef CX_ATU_CTRL_EN
  //  logic                                                radm_atu_uppr_bytes_valid;
  //  `ifdef CX_ATU_SLOC_CBUF
  //     logic [$clog2(ATU_IN_MIN1)-1:0]                    radm_atu_sloc_region;
  //     logic                                              radm_atu_sloc_match;
  //     logic                                              radm_atu_cbuf_err;
  //   `endif //CX_ATU_SLOC_CBUF
  // `endif // CX_ATU_CTRL_EN
  // `ifdef ATS_RX_ENABLE
  //   logic                                                flt_q_nw;
  // `endif
  // `ifdef CX_TPH_ENABLE
  //   logic [1:0]                                          flt_q_ph;
  //   logic [7:0]                                          flt_q_st;
  // `endif
   //  logic [ST_WD -1 :0]                                  flt_q_ohc_b_st_lb; 
    logic [7:0]                                          hdr_dec_flt_cpltr_seg; 
    logic [8:0]                                          hdr_dec_flt_dest_seg; 
    // logic [8:0]                                          hdr_dec_flt_reqtr_seg; 
  // `ifdef CX_CCIX_INTERFACE_ENABLE
  //   logic [`FLT_Q_CCIX_WIDTH-1:0]                        flt_q_ccix;               // Indicate the VC on which the TLP has been received (0=PCIe_VC, 1=CCIX_VC)                 
  // `endif // CX_CCIX_INTERFACE_ENABLE
  // logic [`FLT_Q_LSTDW_BE_WIDTH-1:0]                      flt_q_last_be;            // TRGT1 and cpl_gen control (Last Byte Enable)      
  logic [`FLT_Q_CPL_LAST_WIDTH-1:0]                      flt_q_cpl_last;           // CPL Control                 
  // `ifdef ATS_RX_ENABLE                    
  //   logic [`FLT_Q_AT_WIDTH-1:0]                          flt_q_ats;                // Provides support of PCI-SIG ATS specification
  // `endif  // ATS_RX_ENABLE
  logic [`FLT_Q_EP_WIDTH-1:0]                            flt_q_poisoned;           // CPL TLP EP
  // `ifdef CX_TPH_ENABLE
  //   logic [`FLT_Q_TH_WIDTH-1:0]                          flt_q_th;                 // CPL TLP TH (Processing Hints)
  // `endif // CX_TPH_ENABLE
  logic [`FLT_Q_TD_WIDTH-1:0]                            flt_q_td;                 // CPL TLP TD (Digest)
  logic [`FLT_Q_CPL_LOWER_ADDR_WIDTH-1:0]                flt_q_cpl_lower_addr;     // CPL TLP LOWER ADDR 
  logic [`FLT_Q_BCM_WIDTH-1:0]                           flt_q_cpl_bcm;            // CPL TLP BCM (Byte Count Modified)               
  logic [`FLT_Q_CMPLTR_ID_WIDTH-1:0]                     flt_q_cplid;              // CPL TLP Completer ID                  
  logic [`FLT_Q_BYTE_CNT_WIDTH-1:0]                      flt_q_byte_cnt;           // CPL Byte Count         
  // logic [`FLT_Q_ADDR_WIDTH-1:0]                          flt_q_addr;               // completion hdr &  TRGT0 control
  // logic [`FLT_Q_FRSTDW_BE_WIDTH-1:0]                     flt_q_first_be;           // completion hdr &  TRGT0 control            
  // logic [`FLT_Q_IO_REQ_IN_RANGE_WIDTH-1:0]               flt_q_io_req_in_range;    // TLP Header field IO_REQ_IN_RANGE
  // `ifdef FLT_Q_ROM_IN_RANGE_RANGE
  //   logic [`FLT_Q_ROM_IN_RANGE_WIDTH-1:0]                flt_q_rom_req_in_range;   // TLP Header field ROM_IN_RANGE
  // `endif // FLT_Q_ROM_IN_RANGE_RANGE
  // `ifdef FLT_Q_IN_MEMBAR_RANGE_RANGE
  //   logic [`FLT_Q_IN_MEMBAR_RANGE_WIDTH-1:0]             flt_q_in_membar_range;    // TLP Header field IN_MEMBAR_RANGE
  // `endif // FLT_Q_IN_MEMBAR_RANGE_RANGE
  logic [`FLT_Q_DW_LENGTH_WIDTH-1:0]                     flt_q_dw_len;             // CPL Data Payload Size            
  //`ifdef CX_TLP_PREFIX_ENABLE  
  //  logic [`FLT_Q_PRFX_WIDTH-1:0]                        flt_q_prfx;               // Prefix (Including parity)
  //`endif // CX_TLP_PREFIX_ENABLE
  logic [`FLT_Q_CPL_STATUS_WIDTH-1:0]                    flt_q_cpl_status;         // Status Of The Completion   
  logic [`FLT_Q_FUNC_NMBR_WIDTH-1:0]                     flt_q_func_nmbr;          // Physical Function Number
  logic [`FLT_Q_TAG_WIDTH-1:0]                           flt_q_TAG;                // CPL TLP TAG
  logic [`FLT_Q_REQID_WIDTH-1:0]                         flt_q_REQID;              // CPL TLP Requester ID             
  logic [`FLT_Q_ATTR_WIDTH-1:0]                          flt_q_attr;               // CPL TLP ATTR (Attributes)                     
  logic [`FLT_Q_TC_WIDTH-1:0]                            flt_q_tc;                 // CPL TLP TC (Traffic Class)             
  logic [5-1:0]                                          flt_q_type;               // TLP TYPE            
  hdr_fmt                                                flt_q_fmt;                // TLP Format                
  hdr_destination                                        flt_q_destination;        // TLP Destination  
} flt_cpl_hdr_s ;

  localparam FLT_P_HDR_WIDTH        = $bits(flt_p_hdr_s)
                                        + $bits(radm_hdr_log_rcvd_flds_s)
 
 
 + $clog2(ATU_IN_MIN1) + 1 + 1 
 + `FLT_Q_PRFX_WIDTH;
  
  localparam FLT_NP_HDR_WIDTH       = $bits(flt_np_hdr_s)
                                        + $bits(radm_hdr_log_rcvd_flds_s)
 
 
 + $clog2(ATU_IN_MIN1) + 1 + 1 
 + `FLT_Q_PRFX_WIDTH;

  localparam FLT_CPL_HDR_WIDTH      = $bits(flt_cpl_hdr_s) + NP_REQ_TX_TYPE_WD
                                        + $bits(radm_hdr_log_rcvd_flds_s)
 
 
 + `FLT_Q_PRFX_WIDTH;

  localparam FLT_P_HDR_PROT_WIDTH   = (FLT_P_HDR_WIDTH / `CX_RAS_PROT_RANGE) + ((FLT_P_HDR_WIDTH % `CX_RAS_PROT_RANGE) != 0);
  localparam FLT_NP_HDR_PROT_WIDTH  = (FLT_NP_HDR_WIDTH / `CX_RAS_PROT_RANGE) + ((FLT_NP_HDR_WIDTH % `CX_RAS_PROT_RANGE) != 0);
  localparam FLT_CPL_HDR_PROT_WIDTH = (FLT_CPL_HDR_WIDTH / `CX_RAS_PROT_RANGE) + ((FLT_CPL_HDR_WIDTH % `CX_RAS_PROT_RANGE) != 0);

  localparam RADM_CRD_WD = $clog2( ((`CX_MAX_MTU/4 + 1 +NW-1) / NW) +1); // MAX MTU in Dwords. +1:ECRC. +3:IDE_MAC is 4 and no ECRC allowed. "+NW-1" accounts for division round down.

// Credits returned from radm_pkt_adj module to radm_credit_mgr module in case the TLP passed to the storage module is shorter than expected
typedef struct packed {
  logic                   valid;
  logic [RADM_CRD_WD-1:0] amount;
} radm_crd_restore_s;

// Following struct has defined for data interface signals from filters to storage module 
typedef struct packed {
  logic                           flt_q_tlp_poisoned;
  logic                           radm_hdr_log_vld;
  logic                           radm_hdr_log_vld_all_fn;
  logic [5-1:0]                   radm_hdr_log_err_index;
  logic [DW+DATA_PAR_WD-1:0]      flt_q_data;
  logic                           flt_q_dv;
  logic                           flt_q_eot;
  logic [NW-1:0]                  flt_q_dwen;
  logic                           flt_q_tlp_abort;
  logic                           flt_q_dllp_abort;
  logic                           flt_q_ecrc_err;
  logic                           flt_q_parerr; 
} flt_data_o_s;

// Following struct has defined for NP header interface signals from filters to storage module 
typedef struct packed {
  logic [FLT_NP_HDR_PROT_WIDTH-1:0]                      flt_hdr_prot;
  radm_hdr_log_rcvd_flds_s                               log_rcvd_flds ;
      logic [$clog2(ATU_IN_MIN1)-1:0]                    radm_atu_sloc_region;
      logic                                              radm_atu_sloc_match;
      logic                                              radm_atu_cbuf_err;
    logic [`FLT_Q_PRFX_WIDTH-1:0]                        flt_q_prfx;               // Prefix (Including parity)
    flt_np_hdr_s                                           flt_q_hdr;
    logic                                                  flt_q_hv;
} flt_np_hdr_o_s;

// Following struct has defined for P header interface signals from filters to storage module 
typedef struct packed {
  logic [FLT_P_HDR_PROT_WIDTH-1:0]                       flt_hdr_prot;
  radm_hdr_log_rcvd_flds_s                               log_rcvd_flds ;
      logic [$clog2(ATU_IN_MIN1)-1:0]                    radm_atu_sloc_region;
      logic                                              radm_atu_sloc_match;
      logic                                              radm_atu_cbuf_err;
    logic [`FLT_Q_PRFX_WIDTH-1:0]                        flt_q_prfx;               // Prefix (Including parity)
    flt_p_hdr_s                                            flt_q_hdr;
    logic                                                  flt_q_hv;
} flt_p_hdr_o_s;

// Following struct has defined for CPL header interface signals from filters to storage module 
typedef struct packed {
  logic [FLT_CPL_HDR_PROT_WIDTH-1:0]                     flt_hdr_prot;
  radm_hdr_log_rcvd_flds_s                               log_rcvd_flds ;
  logic [NP_REQ_TX_TYPE_WD-1:0]                          lut_np_req_type;
    logic [`FLT_Q_PRFX_WIDTH-1:0]                        flt_q_prfx;              
    flt_cpl_hdr_s                                          flt_q_hdr;
    logic                                                  flt_q_hv;
} flt_cpl_hdr_o_s;

typedef struct packed {
  logic [DW+DATA_PAR_WD-1:0]                             flt_q_data;
  logic                                                  flt_q_dv;
  logic                                                  flt_q_eot;
  logic [NW-1:0]                                         flt_q_dwen;
  logic                                                  flt_q_tlp_abort;
  logic                                                  flt_q_dllp_abort;
  logic                                                  flt_q_ecrc_err;
  logic                                                  flt_q_poisoned;
  logic [`CX_RASDP_TRGT1_P_HDR_PROT_WD-1:0]                       flt_hdr_prot;
      logic [ATU_IN_MIN1-1:0]                            radm_atu_sloc_match;
      logic [ATU_IN_MIN1-1:0]                            radm_atu_cbuf_err;
  logic [`FLT_Q_PRFX_WIDTH-1:0]                          flt_q_prfx;              
  logic                                                  flt_q_hv;
  logic  [7:0]                                           radm_trgt1_msgcode;
 // `ifdef CX_SRIOV_ENABLE                                                                   
 // logic                                                  flt_q_vfunc_active;             
 // logic  [VF_WD-2:0]                                     flt_q_vfunc_num;               
 // `endif // CX_SRIOV_ENABLE  
  flt_p_hdr_s                                            flt_q_hdr;
  logic                                                  log_halt;
} trgt1_p_out_s;   

typedef struct packed {
  logic [DW+DATA_PAR_WD-1:0]                             flt_q_data;
  logic                                                  flt_q_dv;
  logic                                                  flt_q_eot;
  logic [NW-1:0]                                         flt_q_dwen;
  logic                                                  flt_q_tlp_abort;
  logic                                                  flt_q_dllp_abort;
  logic                                                  flt_q_ecrc_err;  
  logic                                                  flt_q_poisoned;
  logic [`CX_RASDP_TRGT1_NP_HDR_PROT_WD-1:0]                      flt_hdr_prot;
      logic [ATU_IN_MIN1-1:0]                            radm_atu_sloc_match;
      logic [ATU_IN_MIN1-1:0]                            radm_atu_cbuf_err;
  logic [`FLT_Q_PRFX_WIDTH-1:0]                          flt_q_prfx;              
  logic                                                  flt_q_hv;
  logic  [7:0]                                           radm_trgt1_msgcode;
//  `ifdef CX_SRIOV_ENABLE                                                                   
//  logic                                                  flt_q_vfunc_active;             
//  logic  [VF_WD-2:0]                                     flt_q_vfunc_num;               
//  `endif // CX_SRIOV_ENABLE  
  flt_np_hdr_s                                           flt_q_hdr;
  logic                                                  log_halt;
} trgt1_np_out_s; 

typedef struct packed {
  logic [DW+DATA_PAR_WD-1:0]                             flt_q_data;
  logic                                                  flt_q_dv;
  logic                                                  flt_q_eot;
  logic [NW-1:0]                                         flt_q_dwen;
  logic                                                  flt_q_tlp_abort;
  logic                                                  flt_q_dllp_abort;
  logic                                                  flt_q_ecrc_err;  
  logic                                                  flt_q_poisoned;                        
  //logic [FLT_CPL_HDR_PROT_WIDTH-1:0]                     flt_hdr_prot;
  logic [`CX_RASDP_TRGT1_CPL_HDR_PROT_WD-1:0]            flt_hdr_prot;
  logic [`FLT_Q_PRFX_WIDTH-1:0]                          flt_q_prfx;              
  logic                                                  flt_q_hv;

  flt_cpl_hdr_s                                          flt_q_hdr;
  logic                                                  log_halt;
} trgt1_cpl_out_s; 

// Common RTRGT1 Vectored Interface Signals
typedef struct packed {
    logic                                  rtrgt1_tlp_fm_format;
    logic                                   rtrgt1_tlp_hv;
    logic [4:0]                             rtrgt1_tlp_soh;
    logic [`CX_APP_VEC_NUM_HDR_DW-1:0]      rtrgt1_tlp_hwen;
    logic [(`CX_APP_VEC_NUM_HDR_DW*32)-1:0] rtrgt1_tlp_hdr;
    logic [(`CX_APP_VEC_NUM_HDR_DW*4)-1:0]  rtrgt1_tlp_hdr_prot;
    logic                                   rtrgt1_tlp_dv;
    logic [`CX_NW-1:0]                      rtrgt1_tlp_dwen;
    logic [(32*`CX_NW)-1:0]                 rtrgt1_tlp_data;
    logic [(4*`CX_NW)-1:0]                  rtrgt1_tlp_data_prot;
    logic                                   rtrgt1_tlp_eot;
    logic                                   rtrgt1_tlp_nullified;
    logic                                   rtrgt1_tlp_poisoned;
    logic                                   rtrgt1_tlp_ecrc_err;
    logic                                   rtrgt1_tlp_abort;
    logic                                   rtrgt1_tlp_dlp_abort;
    logic [`CX_RADM_PKT_ORD_WD-1:0]         rtrgt1_tlp_porder;
  } rtrgt1_tlp_out_s; 

// Demux Clock Gating Control Signals
typedef struct packed {
  logic                               tlp_dropped;
  logic                               tlp_routed_to_trgt0;
} dmux_clkg_ctrl_s; 

typedef struct packed {
  dmux_clkg_ctrl_s [2:0]              trgt_clkg_ctrl; // [CPL,NP,P]
} trgt_clkg_ctrl_s;

typedef struct packed {
  trgt_clkg_ctrl_s [N_TRGT1_INTF-1:0] port_trgt_clkg_ctrl;
} port_trgt_clkg_ctrl_s;

// TRGT Interface Widths
  localparam TRGT1_P_OUT_WD        = $bits(trgt1_p_out_s);
  localparam TRGT1_NP_OUT_WD       = $bits(trgt1_np_out_s);
  localparam TRGT1_CPL_OUT_WD      = $bits(trgt1_cpl_out_s);
  localparam TRGT1_P_HDR_WD        = $bits(flt_p_hdr_s) ;
  localparam TRGT1_NP_HDR_WD       = $bits(flt_np_hdr_s) ;
  localparam TRGT1_CPL_HDR_WD      = $bits(flt_cpl_hdr_s) ;  
  localparam TRGT1_P_RHDR_WD       = $bits(flt_p_hdr_s) ; // flt_q_hdr width + flt_q_vfunc_num width + flt_q_vfunc_active width
  localparam TRGT1_NP_RHDR_WD      = $bits(flt_np_hdr_s) ;
  localparam TRGT1_CPL_RHDR_WD     = $bits(flt_cpl_hdr_s) ;
  localparam TRGT1_P_HDR_PROT_WD   = ((TRGT1_P_RHDR_WD-2) / `CX_RAS_PROT_RANGE) + (((TRGT1_P_RHDR_WD-2) % `CX_RAS_PROT_RANGE) != 0);
  localparam TRGT1_NP_HDR_PROT_WD  = ((TRGT1_NP_RHDR_WD-2) / `CX_RAS_PROT_RANGE) + (((TRGT1_NP_RHDR_WD-2) % `CX_RAS_PROT_RANGE) != 0);
  localparam TRGT1_CPL_HDR_PROT_WD = ((TRGT1_CPL_RHDR_WD-2) / `CX_RAS_PROT_RANGE) + (((TRGT1_CPL_RHDR_WD-2) % `CX_RAS_PROT_RANGE) != 0);
 
// RADM TRGT1 P/NP/CPL Debug Signals.
// Debug signals assigned per set of P/NP/CPL TRGT1 interfaces.
// The bit positions are fixed regardless of the configured number of physical functions. 
typedef struct packed {
  logic [2:0]               radm_cpl_ur;
  logic [2:0]               radm_cpl_uc;
  logic [2:0]               radm_cpl_pois;
  logic [2:0]               radm_cpl_ca;
  logic [2:0]               radm_wreq_pois;
  logic [2:0]               radm_req_ca;
  logic [2:0]               radm_req_ur;
  logic [2:0]               radm_mlf_err;
  logic [2:0]               radm_ecrc_err;
  logic [(3*($clog2(`CX_ABSOLUTE_MAX_NFUNC)))-1:0] radm_pf;
} ras_des_dbg_ntrgt_ntlp_s;

localparam RADM_RAS_DES_ERR_INFO_WD = `CX_RADM_RAS_DES_ERR_INFO_WD;



  // Common TLP Header struct used across the RADM
  typedef struct packed {
    logic                           hv;          // Header Valid
    logic     [`CX_NPRFX-1:0][31:0] prfx;        // Prefix 
    logic [`CX_RX_HDW_MS-1:0][31:0] header;      // Header
    logic [`CX_RX_HDW_MS-1:0]       header_dwen; // Header DW Enable
    logic [RADM_HDR_PROT_WD-1:0]    prot;        // Header Protection
    logic [HWP-1:0]                 hdr;         // Header
    logic [NHW-1:0]                 dwen;        // Header DW Enable
    logic [PKT_ORD_WD-1:0]          p_pkt_num;   // P TLP packet number 
  } radm_tlp_hdr_s;

  // Common TLP Data struct used across the RADM
  typedef struct packed {
    logic                           dv;        // Data Valid
    logic [NW-1:0]                  dwen;      // Data DW Valid
    logic [DW+DATA_PAR_WD-1:0]      data;      // Data
//  logic [NW-1:0][31:0]            data;      // Data
//  logic [DATA_PAR_WD-1:0]         prot;      // Data Protection
  }
  radm_tlp_data_s;

  // Common TLP Control bits struct used across the RADM
  typedef struct packed {
    logic                           eot;         // End of TLP
    logic                           dllp_err;    // TLP with dllp error
    logic                           tlp_err;     // Malformed TLP error
    logic                           fm_poisoned; // Poisoned TLP (Flit Marker indication)
  }
  radm_tlp_ctl_s;

  // Common TLP struct used across the RADM
  typedef struct packed {
    radm_tlp_hdr_s   hdr; 
    radm_tlp_data_s  data;
    radm_tlp_ctl_s   ctl;
  }
  radm_tlp_s;

  // RADM Formation output struct
  typedef struct packed {
    radm_tlp_s                        tlp;               // Common TLP struct
    logic [QDW_DW+QDW_PAR-1:0]        mac_data;          // mac data interface
    logic [2:0]                       mac_size;          // mac data interface dw size.  
    logic [10:0]                      hdr_data_length;   // Data Length
    logic                             q_not_empty;       // Formation Queue not empty
  } radm_form_s;

  // RADM Formation output struct
  typedef struct packed {
    radm_tlp_s                        tlp;               // Common TLP struct
    logic [31:0]                      ecrc_data;
    logic                             ecrc_enable;
  } radm_outq_tlp_s;


  // RADM Received TLP struct, from OutQ/IDE, to filter
  // When IDE is not supported, radm_rx_tlp_s is simply an alias of radm_outq_tlp_s
  typedef radm_outq_tlp_s radm_rx_tlp_s;


  // -----------------------------------------------------------------------------
  //  Function Declarations
  // -----------------------------------------------------------------------------

  // Calculate RADM credits required for the current TLP.
  // RADM credits differ from FC credits and are completely unrelated. 
  // RADM credits account for number of cycles (beats) required to complete the TLP.
  // The granularity is in cycles (NW) and always account for the worst case: +1 ECRC dword (or +4 MAC dwords in case IDE is supported).
  function automatic [RADM_CRD_WD-1:0] calc_radm_crd;
    input [10:0] tlp_data_length;        // TLP Data length in dwords
    input        is_np;                  // Set to 1 if you want to truncate up to CX_MAX_MTU_NP instead of using CX_MAX_MTU
    begin
      reg [10:0]            max_data_length;    // Maximum packet length in dwords
      reg [10:0]            data_length_adj;    // TLP data length adjusted
      reg [RADM_CRD_WD-1:0] data_length_beats;  // Number of integer cycles required to complete the TLP
      reg [$clog2(NW)-1:0]  data_length_modulo; // checking modulo with input length. 
      reg [RADM_CRD_WD-1:0] crd_required;       // Amount of RADM credits required for the new TLP starting.
      max_data_length    = (is_np)? `CX_MAX_MTU_NP/4 : `CX_MAX_MTU/4;
      data_length_adj    = (tlp_data_length>max_data_length)? max_data_length : tlp_data_length;  // Truncate to MTU - TODO Future enhancement, this cam be optimized for timing !!!
      data_length_adj    = data_length_adj + 11'd1 ;           // Account for trailer dwors (regardless they are actually present).
      data_length_beats  = data_length_adj/NW;
      data_length_modulo = data_length_adj%NW;
      calc_radm_crd      = data_length_beats + (data_length_modulo == 0 ? 1'b0 : 1'b1);
    end
  endfunction

  function automatic [10:0] calc_tlp_data_len;
    input [7:0] f_type;       // type   field extracted from the 1st DW Header ({fmt,type} in NFM)
    input [9:0] f_len;        // length field extracted from the 1st DW Header
    input       flit_mode_en;
    begin
      pcie_pkg::decoded_tlp_type_s dec_type;
      dec_type = pcie_pkg::f_decode_tlp_type(f_type, flit_mode_en);
      calc_tlp_data_len = (dec_type.payload)? (f_len==10'h0)? 11'd1024 : {1'b0,f_len} : 11'b0;
    end
  endfunction
  // -----------------------------------------------------------------------------
  //  Below are all FUNCTION declarations which are sued in multiple filter modules
  // -----------------------------------------------------------------------------
  // FILTERS //
    
  function automatic [1:0] flt_q_byte_addr_in;
    input  [3:0] flt_q_first_be; 
    begin
      casez(flt_q_first_be)
        4'b0000:     flt_q_byte_addr_in = 2'b00;
        4'b???1:     flt_q_byte_addr_in = 2'b00;
        4'b??10:     flt_q_byte_addr_in = 2'b01;
        4'b?100:     flt_q_byte_addr_in = 2'b10;
        4'b1000:     flt_q_byte_addr_in = 2'b11;
        default:     flt_q_byte_addr_in = 2'b00;

      endcase // casez(flt_q_first_be)
    end
  endfunction

  function automatic [NF-1:0] route_error_to_func;
    input               set_error_signal;
    input [PF_WD-1:0]   function_dest;
    begin
      route_error_to_func                   = 0;
      if (function_dest  < NF)
        route_error_to_func[function_dest]  = set_error_signal;
      else // function_dest >= NF
        route_error_to_func                 = {NF{set_error_signal}};
    end
  endfunction

  function automatic get_pm_block;
      input [NF-1:0]      pm_radm_block_tlp;
      input [PF_WD-1:0]   tlp_func_num;
      integer        func;
      begin
        get_pm_block      = 1'b1;
        for (func=0; func<NF; func=func+1) begin
          if (tlp_func_num==func)
            get_pm_block  = pm_radm_block_tlp[func];
        end
      end
  endfunction

  function automatic [4:0] radm_hdr_log_err_index;
      input [17:0]      radm_hdr_log_all_err;

    casez (radm_hdr_log_all_err)
      18'b?????????????????1:radm_hdr_log_err_index=UNCORR_INT_ERR;
      18'b????????????????10:radm_hdr_log_err_index=RECEIVER_OVRFLW;
      18'b???????????????100:radm_hdr_log_err_index=MALFORMED_TLP;
      18'b??????????????1000:radm_hdr_log_err_index=IDE_CHK_FAILED;
      18'b?????????????10000:radm_hdr_log_err_index=ECRC_CHK_FAILED;
      18'b????????????100000:radm_hdr_log_err_index=MISROUTED_IDE_TLP;
      18'b???????????1000000:radm_hdr_log_err_index=ATOMIC_OP_EGRSS;
      18'b??????????10000000:radm_hdr_log_err_index=DMWR_REQUEST_EGRSS_BLOCKD;
      18'b?????????100000000:radm_hdr_log_err_index=TLP_TRANS_EGRSS_BLOCKD;
      18'b????????1000000000:radm_hdr_log_err_index=TLP_PRFX_BLOCKD;
      18'b???????10000000000:radm_hdr_log_err_index=ACS_VIOLATION;
      18'b??????100000000000:radm_hdr_log_err_index=MC_BLOCKD_TLP;
      18'b?????1000000000000:radm_hdr_log_err_index=UNSUPP_REQUEST;
      18'b????10000000000000:radm_hdr_log_err_index=COMPLETER_ABORT;
      18'b???100000000000000:radm_hdr_log_err_index=UNEXP_COMPLETION;
      18'b??1000000000000000:radm_hdr_log_err_index=PCRC_CHECK_FAILED;
      18'b?10000000000000000:radm_hdr_log_err_index=POISONED_TLP_RECEIVED;
      18'b100000000000000000:radm_hdr_log_err_index=POISONED_TLP_RECEIVED;
      default:radm_hdr_log_err_index=5'd0;
    endcase
  endfunction


  // Get a bar number from the one hot bar match
  function automatic [2:0] get_bar_num;
  input [5:0] bar;
  begin
    casez  (bar)
      6'b000000 : get_bar_num = `RADM_OUTSIDE_MEMBAR;
      6'b?????1 : get_bar_num = 3'd0;
      6'b????10 : get_bar_num = 3'd1;
      6'b???100 : get_bar_num = 3'd2;
      6'b??1000 : get_bar_num = 3'd3;
      6'b?10000 : get_bar_num = 3'd4;
      6'b100000 : get_bar_num = 3'd5;
      default   : get_bar_num = `RADM_OUTSIDE_MEMBAR;
    endcase
  end
  endfunction



  function automatic  pcie_max_pyld_err ;
    input [2:0]   cfg_max_payload; 
    input         dw_len_is0;
    input [9:0]   tlp_dw_len ;
    input         tlp_has_pyld;

    begin
      case (cfg_max_payload)
        3'b000: pcie_max_pyld_err      = ({dw_len_is0, tlp_dw_len} > 11'h020) & tlp_has_pyld; // 128 bytes
        3'b001: pcie_max_pyld_err      = ({dw_len_is0, tlp_dw_len} > 11'h040) & tlp_has_pyld ; // 256Bytes
        3'b010: pcie_max_pyld_err      = ({dw_len_is0, tlp_dw_len} > 11'h080) & tlp_has_pyld ; // 512Bytes
        3'b011: pcie_max_pyld_err      = ({dw_len_is0, tlp_dw_len} > 11'h100) & tlp_has_pyld ; // 1KBytes
        3'b100: pcie_max_pyld_err      = ({dw_len_is0, tlp_dw_len} > 11'h200) & tlp_has_pyld ; // 2KBytes
        3'b101: pcie_max_pyld_err      = 1'b0 ; // 4KBytes
        // not spec supported payload size
        //VCS coverage off
        3'b110: pcie_max_pyld_err      = 1'b0;
        3'b111: pcie_max_pyld_err      = 1'b0;
        default: pcie_max_pyld_err     = 1'b0;
        //VCS coverage on
      endcase
   end
  endfunction
   

  function automatic  ctig_error;
    input           do_check; 
    input           is_qw_aligned;
    input  [9:0]    tlp_dw_len;
    input  [3:0]    first_be;
    input  [3:0]    last_be;
          ctig_error = 1'b0;
    if (do_check) 
    begin
      case (tlp_dw_len)
        10'h001:
          // Non-Contiguous BE Check & Contiguous BE Check
          // Nothing to do here since all combinations are legal and FBE/LBE Checks are also running.
          ctig_error = 1'b0;
        10'h002:
          // Address is QWord aligned
          // Non-Contiguous BE Check
          // Nothing to do here since all combinations are legal and FBE/LBE Checks are also running.
          //
          // else Address is not QWord aligned
          if (!is_qw_aligned) begin // Address is not QWord aligned
            // Contiguous BE Check
            case ({last_be, first_be})
              8'b1111_1111,
              8'b1111_1110,
              8'b1111_1100,
              8'b1111_1000,
              8'b0111_1111,
              8'b0111_1110,
              8'b0111_1100,
              8'b0111_1000,
              8'b0011_1111,
              8'b0011_1110,
              8'b0011_1100,
              8'b0011_1000,
              8'b0001_1111,
              8'b0001_1110,
              8'b0001_1100,
              8'b0001_1000:
                ctig_error = 1'b0;
              default:
                ctig_error = 1'b1;
            endcase
          end
          default:
            // Contiguous BE Check (for 3 DW and larger requests)
          case ({last_be,first_be})
            8'b1111_1111,
            8'b1111_1110,
            8'b1111_1100,
            8'b1111_1000,
            8'b0111_1111,
            8'b0111_1110,
            8'b0111_1100,
            8'b0111_1000,
            8'b0011_1111,
            8'b0011_1110,
            8'b0011_1100,
            8'b0011_1000,
            8'b0001_1111,
            8'b0001_1110,
            8'b0001_1100,
            8'b0001_1000:
              ctig_error = 1'b0;
            default:
              ctig_error = 1'b1;
          endcase
      endcase
    end

  endfunction

  function automatic get_tc_enable;
    input [7:0]   cfg_tc_enable;
    input [2:0]   tc;
    begin
      case (tc)
        3'b000: get_tc_enable   = cfg_tc_enable[0];
        3'b001: get_tc_enable   = cfg_tc_enable[1];
        3'b010: get_tc_enable   = cfg_tc_enable[2];
        3'b011: get_tc_enable   = cfg_tc_enable[3];
        3'b100: get_tc_enable   = cfg_tc_enable[4];
        3'b101: get_tc_enable   = cfg_tc_enable[5];
        3'b110: get_tc_enable   = cfg_tc_enable[6];
        3'b111: get_tc_enable   = cfg_tc_enable[7];
        default: get_tc_enable  = 1'b0;
      endcase
    end
  endfunction

function automatic [32*CX_MAX_HDR_LOG_SZ-1:0] little_end_hdr_prfx;
      input  [32*CX_MAX_HDR_LOG_SZ-1:0]  hdr_prfx_log;
      integer                                 i;
      integer                                 j;
      for(i = 0; i < CX_MAX_HDR_LOG_SZ; i = i + 1) begin     // Repeat for every allocated HDR_PRFX DW
         for(j = 0; j < 4; j = j + 1) begin                       // 4 bytes per DW
            little_end_hdr_prfx[(8*j)+(32*i) +: 8]  =  hdr_prfx_log[32*(i+1)-8*(j+1) +: 8];
         end
      end
  endfunction

    function automatic [127:0] little_end_prfx;
      input  [159:0]  e2e_prfx_log;
      integer         i;
      integer         j;
      for(i = 0; i < 4; i = i + 1) begin              // Repeat for every allocated prefix slot
         for(j = 0; j < 4; j = j + 1) begin           // 4 bytes per Prefix
            little_end_prfx[(8*j)+(32*i) +: 8]  =  e2e_prfx_log[32*(i+1)-8*(j+1) +: 8];
         end
      end
    endfunction

function automatic [63:0] little_end_addr;
  input  [63:0]  addr;
  integer         i;
  integer         j;
  for(i = 0; i < 2; i = i + 1) begin              // Repeat for 2 DWs
      for(j = 0; j < 4; j = j + 1) begin          // 4 bytes per DW
        little_end_addr[(8*j)+(32*i) +: 8]  =  addr[32*(i+1)-8*(j+1) +: 8];
      end
  end
endfunction

function automatic [63:0] f_tlp_addr_tph;
  input tlp_th;
  input [63:0] tlp_addr;
  input flit_mode;
  input [1:0] tlp_at;
  begin
    f_tlp_addr_tph[63:0] = (tlp_th) ? {tlp_addr[63:2],2'b00} :
 (flit_mode && (|tlp_at)) ? {tlp_addr[63:2],2'b00} :
                                  (tlp_at == 2'b01) ? {tlp_addr[63:1],1'b0} : tlp_addr[63:0];
  end
endfunction


  function automatic int_mlf_msg_in_ep;
    input       pcie_format;
    input [2:0] tc; 
    input [7:0] msg_code;
    begin
      int_mlf_msg_in_ep = pcie_format && tc != 0 && (
      ((msg_code == `PM_ACTIVE_STATE_NAK)) ||
      ((msg_code == `PME_TURN_OFF)       ) ||
      ((msg_code == `UNLOCK)             ) ||
      ((msg_code == `OBFF)               ) ||
      ((msg_code == `SET_SLOT_PWR_LIMIT) )
       ||
      ((msg_code == `PTM_RES_TYPE)       )
       ||
      ((msg_code == `PRG_RES_TYPE)       )
      ) ||
     ((msg_code == `ASSERT_INTA)        ) ||
      ((msg_code == `ASSERT_INTB)        ) ||
      ((msg_code == `ASSERT_INTC)        ) ||
      ((msg_code == `ASSERT_INTD)        ) ||
      ((msg_code == `DEASSERT_INTA)      ) ||
      ((msg_code == `DEASSERT_INTB)      ) ||
      ((msg_code == `DEASSERT_INTC)      ) ||
      ((msg_code == `DEASSERT_INTD))       ||      
      ((msg_code == `PME_TO_ACK))          ||      
        ((msg_code == `PM_PME));      

    end
  endfunction


  function automatic int_mlf_msg_in_rc;
    input       pcie_format;
    input [2:0] tc; 
    input [7:0] msg_code;
    begin

    int_mlf_msg_in_rc = pcie_format && tc != 0 && (
    ((msg_code == `PM_ACTIVE_STATE_NAK)) ||
    ((msg_code == `PM_PME)             ) ||
    ((msg_code == `PME_TO_ACK)         ) ||
    ((msg_code ==`LTR_MSG_CODE)        ) ||
    ((msg_code == `PTM_REQ_TYPE)       ) ||
    ((msg_code == `PRS_REQ_TYPE)      ) ||
    ((msg_code == `ASSERT_INTA)        ) ||
    ((msg_code == `ASSERT_INTB)        ) ||
    ((msg_code == `ASSERT_INTC)        ) ||
    ((msg_code == `ASSERT_INTD)        ) ||
    ((msg_code == `DEASSERT_INTA)      ) ||
    ((msg_code == `DEASSERT_INTB)      ) ||
    ((msg_code == `DEASSERT_INTC)      ) ||
    ((msg_code == `DEASSERT_INTD)      ) ||
    ((msg_code == `ERR_COR)            ) ||
    ((msg_code == `ERR_NF)             ) ||
    ((msg_code == `ERR_F)              )
);
    end
  endfunction

  function automatic [159:0] e2e_prfx_log_in;
    input [255:0] pre_tlp_prfx_log;
    begin
      e2e_prfx_log_in  = pre_tlp_prfx_log[4] ? pre_tlp_prfx_log[159:0] :
                         pre_tlp_prfx_log[36] ? pre_tlp_prfx_log[191:32] :
                         pre_tlp_prfx_log[68] ? pre_tlp_prfx_log[223:64] :
                         pre_tlp_prfx_log[100] ? pre_tlp_prfx_log[255:96] :
                         pre_tlp_prfx_log[132] ? {32'h0, pre_tlp_prfx_log[255:128]} :
                         pre_tlp_prfx_log[164] ? {64'h0, pre_tlp_prfx_log[255:160]} :
                         pre_tlp_prfx_log[196] ? {96'h0, pre_tlp_prfx_log[255:192]} :
                         pre_tlp_prfx_log[228] ? {128'h0, pre_tlp_prfx_log[255:224]} :
                         160'h0;
    end
  endfunction


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



  function automatic [2:0]  get_VC;
    input [23:0] tc_vc_map;
    input [2:0] tc;
    begin
      case (tc)
        3'b000: get_VC = tc_vc_map[2:0];
        3'b001: get_VC = tc_vc_map[5:3];
        3'b010: get_VC = tc_vc_map[8:6];
        3'b011: get_VC = tc_vc_map[11:9];
        3'b100: get_VC = tc_vc_map[14:12];
        3'b101: get_VC = tc_vc_map[17:15];
        3'b110: get_VC = tc_vc_map[20:18];
        3'b111: get_VC = tc_vc_map[23:21];
      endcase
    end
    //    for (bit=0; bit<3; bit=bit+1) get_VC[bit]    = tc_vc_map[(tc*3)+bit];
  endfunction

  // Function to convert from a traffic class to a one-hot Q select
  function automatic [NVC-1:0] q_select_from_tc;
    input [23:0]  cfg_tc_struc_vc_map;  // TC to VC Structure mapping
    input [2:0]   tc;                   // Traffic class
    logic [2:0]   vc;
    logic [7:0]   full_NVC_q_select;
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



// Function to convert common header to P type header
function automatic [$bits(flt_p_hdr_o_s)-2:0] conv_hdr_to_p_type;
    input flt_hdr_s           flt_q_hdr;
    input [`FLT_Q_ADDR_WIDTH-1:0]  radm_trgt1_addr_int_r;
    input                          flt_q_poisoned_in;
    flt_p_hdr_o_s             flt_q_hdr_p;
  begin
    flt_q_hdr_p = {$bits(flt_p_hdr_o_s){1'b0}};
    
    flt_q_hdr_p.flt_hdr_prot = flt_q_hdr.flt_hdr_prot[FLT_P_HDR_PROT_WIDTH-1:0];
    
        flt_q_hdr_p.radm_atu_sloc_region = flt_q_hdr.radm_atu_sloc_region; 
        flt_q_hdr_p.radm_atu_sloc_match  = flt_q_hdr.radm_atu_sloc_match; 
        flt_q_hdr_p.radm_atu_cbuf_err    = flt_q_hdr.radm_atu_cbuf_err; 
    
 flt_q_hdr_p.flt_q_prfx = flt_q_hdr.flt_q_prfx; // CX_TLP_PREFIX_ENABLE
    flt_q_hdr_p.log_rcvd_flds        = flt_q_hdr.log_rcvd_flds ;

    flt_q_hdr_p.flt_q_hdr = { flt_q_hdr.flt_q_td_hdr_log, flt_q_hdr.flt_q_fmt2,flt_q_hdr.flt_q_hdr_uppr_bytes,flt_q_hdr.flt_pkt_num,
  // CX_IDE_ENABLE_NO_PASSTHROUGH
 flt_q_hdr.radm_atu_uppr_bytes_valid, // CX_ATU_CTRL_EN
 flt_q_hdr.flt_q_ph, flt_q_hdr.flt_q_st,
 flt_q_hdr.hdr_dec_flt_dest_seg, flt_q_hdr.hdr_dec_flt_reqtr_seg,
                              flt_q_hdr.flt_q_last_be, flt_q_hdr.flt_q_ats,  // ATS_RX_ENABLE
                              flt_q_poisoned_in, flt_q_hdr.flt_q_th, // CX_TPH_ENABLE
                              flt_q_hdr.flt_q_td, radm_trgt1_addr_int_r, flt_q_hdr.flt_q_first_be, 
 flt_q_hdr.flt_q_rom_req_in_range, // FLT_Q_ROM_IN_RANGE_RANGE
 flt_q_hdr.flt_q_in_membar_range, // FLT_Q_IN_MEMBAR_RANGE_RANGE
                              flt_q_hdr.flt_q_dw_len, // CX_SRIOV_ENABLE
                              flt_q_hdr.flt_q_cpl_status, flt_q_hdr.flt_q_func_nmbr, flt_q_hdr.flt_q_TAG, flt_q_hdr.flt_q_REQID, 
  // CX_LN_ENABLE
                              flt_q_hdr.flt_q_attr, flt_q_hdr.flt_q_tc, flt_q_hdr.flt_q_type, flt_q_hdr.flt_q_fmt, flt_q_hdr.flt_q_destination };


    conv_hdr_to_p_type = flt_q_hdr_p[$bits(flt_p_hdr_o_s)-1:1];
  end
endfunction

// Function to convert common header to NP type header
function automatic [$bits(flt_np_hdr_o_s)-2:0] conv_hdr_to_np_type;
    input flt_hdr_s           flt_q_hdr;
    input [`FLT_Q_ADDR_WIDTH-1:0]  radm_trgt1_addr_int_r;
    input                          flt_q_poisoned_in;
    flt_np_hdr_o_s            flt_q_hdr_np;
  begin
    flt_q_hdr_np = {$bits(flt_np_hdr_o_s){1'b0}};
    
    flt_q_hdr_np.flt_hdr_prot = flt_q_hdr.flt_hdr_prot[FLT_NP_HDR_PROT_WIDTH-1:0];
    
        flt_q_hdr_np.radm_atu_sloc_region = flt_q_hdr.radm_atu_sloc_region; 
        flt_q_hdr_np.radm_atu_sloc_match  = flt_q_hdr.radm_atu_sloc_match; 
        flt_q_hdr_np.radm_atu_cbuf_err    = flt_q_hdr.radm_atu_cbuf_err; 
    
 flt_q_hdr_np.flt_q_prfx = flt_q_hdr.flt_q_prfx; // CX_TLP_PREFIX_ENABLE
      flt_q_hdr_np.log_rcvd_flds        = flt_q_hdr.log_rcvd_flds ;

      flt_q_hdr_np.flt_q_hdr = { flt_q_hdr.flt_q_td_hdr_log, flt_q_hdr.flt_q_fmt2,flt_q_hdr.flt_pkt_num,  // CX_IDE_ENABLE_NO_PASSTHROUGH
 flt_q_hdr.flt_q_nw, flt_q_hdr.flt_q_cxlsrc,
 flt_q_hdr.flt_q_ph, flt_q_hdr.flt_q_st,
 flt_q_hdr.hdr_dec_flt_dest_seg, flt_q_hdr.hdr_dec_flt_reqtr_seg,
                                 flt_q_hdr.flt_q_last_be, flt_q_hdr.flt_q_ats,  // ATS_RX_ENABLE
                                 flt_q_poisoned_in, flt_q_hdr.flt_q_th, // CX_TPH_ENABLE
                                 flt_q_hdr.flt_q_td, radm_trgt1_addr_int_r, flt_q_hdr.flt_q_first_be, flt_q_hdr.flt_q_io_req_in_range,   
 flt_q_hdr.flt_q_rom_req_in_range, // FLT_Q_ROM_IN_RANGE_RANGE
 flt_q_hdr.flt_q_in_membar_range, // FLT_Q_IN_MEMBAR_RANGE_RANGE
                                 flt_q_hdr.flt_q_dw_len, // CX_SRIOV_ENABLE
                                 flt_q_hdr.flt_q_cpl_status, flt_q_hdr.flt_q_func_nmbr, flt_q_hdr.flt_q_TAG, flt_q_hdr.flt_q_REQID, 
  // CX_LN_ENABLE
                                 flt_q_hdr.flt_q_attr, flt_q_hdr.flt_q_tc, flt_q_hdr.flt_q_type, flt_q_hdr.flt_q_fmt, flt_q_hdr.flt_q_destination };

    conv_hdr_to_np_type = flt_q_hdr_np[$bits(flt_np_hdr_o_s)-1:1];
  end
endfunction

// Function to convert common header to CPL type header
function automatic [$bits(flt_cpl_hdr_o_s)-2:0] conv_hdr_to_cpl_type;
    input flt_hdr_s           flt_q_hdr;
    input                     flt_q_poisoned_in;
    flt_cpl_hdr_o_s           flt_q_hdr_cpl;
  begin
    flt_q_hdr_cpl = {$bits(flt_cpl_hdr_o_s){1'b0}};
    
    flt_q_hdr_cpl.flt_hdr_prot = flt_q_hdr.flt_hdr_prot[FLT_CPL_HDR_PROT_WIDTH-1:0];
    
 flt_q_hdr_cpl.flt_q_prfx = flt_q_hdr.flt_q_prfx; // CX_TLP_PREFIX_ENABLE
    
    flt_q_hdr_cpl.lut_np_req_type        =  flt_q_hdr.lut_np_req_type;
      flt_q_hdr_cpl.log_rcvd_flds        = flt_q_hdr.log_rcvd_flds ;

      flt_q_hdr_cpl.flt_q_hdr =   { flt_q_hdr.flt_q_td_hdr_log, flt_q_hdr.flt_q_fmt2,flt_q_hdr.flt_pkt_num,  // CX_IDE_ENABLE_NO_PASSTHROUGH
 flt_q_hdr.hdr_dec_flt_cpltr_seg, flt_q_hdr.hdr_dec_flt_dest_seg,
                                    flt_q_hdr.flt_q_cpl_last, flt_q_poisoned_in, flt_q_hdr.flt_q_td, flt_q_hdr.flt_q_cpl_lower_addr, flt_q_hdr.flt_q_cpl_bcm, 
                                    flt_q_hdr.flt_q_cplid, flt_q_hdr.flt_q_byte_cnt, 
                                    flt_q_hdr.flt_q_dw_len, 
 // CX_SRIOV_ENABLE
                                    flt_q_hdr.flt_q_cpl_status, flt_q_hdr.flt_q_func_nmbr, flt_q_hdr.flt_q_TAG, flt_q_hdr.flt_q_REQID, 
  // CX_LN_ENABLE
                                    flt_q_hdr.flt_q_attr, flt_q_hdr.flt_q_tc, flt_q_hdr.flt_q_type, flt_q_hdr.flt_q_fmt, flt_q_hdr.flt_q_destination };
 
    conv_hdr_to_cpl_type = flt_q_hdr_cpl[$bits(flt_cpl_hdr_o_s)-1:1];
  end
endfunction


// Function to convert NP type header to common header
function automatic [$bits(flt_hdr_s)-1:0] conv_hdr_from_np_type;
    input flt_np_hdr_o_s      flt_q_hdr_np;
    flt_hdr_s                 flt_q_hdr;
  begin
    flt_q_hdr = {$bits(flt_hdr_s){1'b0}};
    flt_q_hdr.flt_q_td_hdr_log         = flt_q_hdr_np.flt_q_hdr.flt_q_td_hdr_log ;
    flt_q_hdr.flt_q_fmt2               = flt_q_hdr_np.flt_q_hdr.flt_q_fmt2; 
    flt_q_hdr.flt_hdr_prot[FLT_NP_HDR_PROT_WIDTH-1:0] = flt_q_hdr_np.flt_hdr_prot; 
    flt_q_hdr.flt_pkt_num               = flt_q_hdr_np.flt_q_hdr.flt_pkt_num; 
    flt_q_hdr.radm_atu_sloc_region      = flt_q_hdr_np.radm_atu_sloc_region; 
    flt_q_hdr.radm_atu_sloc_match       = flt_q_hdr_np.radm_atu_sloc_match; 
    flt_q_hdr.radm_atu_cbuf_err         = flt_q_hdr_np.radm_atu_cbuf_err; 
    flt_q_hdr.flt_q_nw                  = flt_q_hdr_np.flt_q_hdr.flt_q_nw; 
    flt_q_hdr.flt_q_cxlsrc              = flt_q_hdr_np.flt_q_hdr.flt_q_cxlsrc; 
    flt_q_hdr.flt_q_ph                  = flt_q_hdr_np.flt_q_hdr.flt_q_ph; 
    flt_q_hdr.flt_q_st                  = flt_q_hdr_np.flt_q_hdr.flt_q_st; 
    flt_q_hdr.hdr_dec_flt_dest_seg      = flt_q_hdr_np.flt_q_hdr.hdr_dec_flt_dest_seg; 
    flt_q_hdr.hdr_dec_flt_reqtr_seg     = flt_q_hdr_np.flt_q_hdr.hdr_dec_flt_reqtr_seg;
    flt_q_hdr.log_rcvd_flds             = flt_q_hdr_np.log_rcvd_flds ; 
    flt_q_hdr.flt_q_last_be             = flt_q_hdr_np.flt_q_hdr.flt_q_last_be; 
    flt_q_hdr.flt_q_ats                 = flt_q_hdr_np.flt_q_hdr.flt_q_ats; 
    flt_q_hdr.flt_q_poisoned            = flt_q_hdr_np.flt_q_hdr.flt_q_poisoned; 
    flt_q_hdr.flt_q_th                  = flt_q_hdr_np.flt_q_hdr.flt_q_th; 
    flt_q_hdr.flt_q_td                  = flt_q_hdr_np.flt_q_hdr.flt_q_td; 
    flt_q_hdr.flt_q_addr                = flt_q_hdr_np.flt_q_hdr.flt_q_addr; 
    flt_q_hdr.flt_q_first_be            = flt_q_hdr_np.flt_q_hdr.flt_q_first_be; 
    flt_q_hdr.flt_q_io_req_in_range     = flt_q_hdr_np.flt_q_hdr.flt_q_io_req_in_range;
    flt_q_hdr.flt_q_rom_req_in_range    = flt_q_hdr_np.flt_q_hdr.flt_q_rom_req_in_range; 
    flt_q_hdr.flt_q_in_membar_range     = flt_q_hdr_np.flt_q_hdr.flt_q_in_membar_range; 
    flt_q_hdr.flt_q_dw_len              = flt_q_hdr_np.flt_q_hdr.flt_q_dw_len; 
    flt_q_hdr.flt_q_prfx                = flt_q_hdr_np.flt_q_prfx; 
    flt_q_hdr.flt_q_cpl_status          = flt_q_hdr_np.flt_q_hdr.flt_q_cpl_status; 
    flt_q_hdr.flt_q_func_nmbr           = flt_q_hdr_np.flt_q_hdr.flt_q_func_nmbr; 
    flt_q_hdr.flt_q_TAG                 = flt_q_hdr_np.flt_q_hdr.flt_q_TAG; 
    flt_q_hdr.flt_q_REQID               = flt_q_hdr_np.flt_q_hdr.flt_q_REQID; 
    flt_q_hdr.flt_q_attr                = flt_q_hdr_np.flt_q_hdr.flt_q_attr; 
    flt_q_hdr.flt_q_tc                  = flt_q_hdr_np.flt_q_hdr.flt_q_tc; 
    flt_q_hdr.flt_q_type                = flt_q_hdr_np.flt_q_hdr.flt_q_type; 
    flt_q_hdr.flt_q_fmt                 = flt_q_hdr_np.flt_q_hdr.flt_q_fmt; 
    flt_q_hdr.flt_q_destination         = flt_q_hdr_np.flt_q_hdr.flt_q_destination;
 
    conv_hdr_from_np_type               = flt_q_hdr;
  end
endfunction

// Function to convert P type header to common header
function automatic [$bits(flt_hdr_s)-1:0] conv_hdr_from_p_type;
    input flt_p_hdr_o_s       flt_q_hdr_p;
    flt_hdr_s                 flt_q_hdr;
  begin
    flt_q_hdr = {$bits(flt_hdr_s){1'b0}};
    flt_q_hdr.flt_q_td_hdr_log         = flt_q_hdr_p.flt_q_hdr.flt_q_td_hdr_log;
    flt_q_hdr.flt_q_fmt2               = flt_q_hdr_p.flt_q_hdr.flt_q_fmt2; 
    flt_q_hdr.flt_hdr_prot[FLT_P_HDR_PROT_WIDTH-1:0] = flt_q_hdr_p.flt_hdr_prot; 
    flt_q_hdr.flt_pkt_num               = flt_q_hdr_p.flt_q_hdr.flt_pkt_num; 
    flt_q_hdr.flt_q_hdr_uppr_bytes      = flt_q_hdr_p.flt_q_hdr.flt_q_hdr_uppr_bytes;
    flt_q_hdr.radm_atu_uppr_bytes_valid = flt_q_hdr_p.flt_q_hdr.radm_atu_uppr_bytes_valid;
    flt_q_hdr.radm_atu_sloc_region      = flt_q_hdr_p.radm_atu_sloc_region; 
    flt_q_hdr.radm_atu_sloc_match       = flt_q_hdr_p.radm_atu_sloc_match; 
    flt_q_hdr.radm_atu_cbuf_err         = flt_q_hdr_p.radm_atu_cbuf_err; 
    flt_q_hdr.flt_q_ph                  = flt_q_hdr_p.flt_q_hdr.flt_q_ph; 
    flt_q_hdr.flt_q_st                  = flt_q_hdr_p.flt_q_hdr.flt_q_st; 
    flt_q_hdr.hdr_dec_flt_dest_seg      = flt_q_hdr_p.flt_q_hdr.hdr_dec_flt_dest_seg; 
    flt_q_hdr.hdr_dec_flt_reqtr_seg     = flt_q_hdr_p.flt_q_hdr.hdr_dec_flt_reqtr_seg;
    flt_q_hdr.log_rcvd_flds             = flt_q_hdr_p.log_rcvd_flds ;  
    flt_q_hdr.flt_q_last_be             = flt_q_hdr_p.flt_q_hdr.flt_q_last_be; 
    flt_q_hdr.flt_q_ats                 = flt_q_hdr_p.flt_q_hdr.flt_q_ats; 
    flt_q_hdr.flt_q_poisoned            = flt_q_hdr_p.flt_q_hdr.flt_q_poisoned; 
    flt_q_hdr.flt_q_th                  = flt_q_hdr_p.flt_q_hdr.flt_q_th; 
    flt_q_hdr.flt_q_td                  = flt_q_hdr_p.flt_q_hdr.flt_q_td; 
    flt_q_hdr.flt_q_addr                = flt_q_hdr_p.flt_q_hdr.flt_q_addr; 
    flt_q_hdr.flt_q_first_be            = flt_q_hdr_p.flt_q_hdr.flt_q_first_be; 
    flt_q_hdr.flt_q_rom_req_in_range    = flt_q_hdr_p.flt_q_hdr.flt_q_rom_req_in_range; 
    flt_q_hdr.flt_q_in_membar_range     = flt_q_hdr_p.flt_q_hdr.flt_q_in_membar_range; 
    flt_q_hdr.flt_q_dw_len              = flt_q_hdr_p.flt_q_hdr.flt_q_dw_len; 
    flt_q_hdr.flt_q_prfx                = flt_q_hdr_p.flt_q_prfx; 
    flt_q_hdr.flt_q_cpl_status          = flt_q_hdr_p.flt_q_hdr.flt_q_cpl_status; 
    flt_q_hdr.flt_q_func_nmbr           = flt_q_hdr_p.flt_q_hdr.flt_q_func_nmbr; 
    flt_q_hdr.flt_q_TAG                 = flt_q_hdr_p.flt_q_hdr.flt_q_TAG; 
    flt_q_hdr.flt_q_REQID               = flt_q_hdr_p.flt_q_hdr.flt_q_REQID; 
    flt_q_hdr.flt_q_attr                = flt_q_hdr_p.flt_q_hdr.flt_q_attr; 
    flt_q_hdr.flt_q_tc                  = flt_q_hdr_p.flt_q_hdr.flt_q_tc; 
    flt_q_hdr.flt_q_type                = flt_q_hdr_p.flt_q_hdr.flt_q_type; 
    flt_q_hdr.flt_q_fmt                 = flt_q_hdr_p.flt_q_hdr.flt_q_fmt; 
    flt_q_hdr.flt_q_destination         = flt_q_hdr_p.flt_q_hdr.flt_q_destination;
 
    conv_hdr_from_p_type                = flt_q_hdr;
  end
endfunction

// Function to convert CPL type header to common header
function automatic [($bits(flt_hdr_s))-1:0] conv_hdr_from_cpl_type;
    input flt_cpl_hdr_o_s     flt_q_hdr_cpl;
    flt_hdr_s                 flt_q_hdr;
  begin
    flt_q_hdr = {$bits(flt_hdr_s){1'b0}};
    flt_q_hdr.flt_q_td_hdr_log         = flt_q_hdr_cpl.flt_q_hdr.flt_q_td_hdr_log ;
    flt_q_hdr.flt_q_fmt2               = flt_q_hdr_cpl.flt_q_hdr.flt_q_fmt2; 
    flt_q_hdr.flt_hdr_prot[FLT_CPL_HDR_PROT_WIDTH-1:0] = flt_q_hdr_cpl.flt_hdr_prot; 
    flt_q_hdr.lut_np_req_type           = flt_q_hdr_cpl.lut_np_req_type;
    flt_q_hdr.flt_pkt_num               = flt_q_hdr_cpl.flt_q_hdr.flt_pkt_num; 
    flt_q_hdr.hdr_dec_flt_dest_seg      = flt_q_hdr_cpl.flt_q_hdr.hdr_dec_flt_dest_seg; 
    flt_q_hdr.hdr_dec_flt_cpltr_seg     = flt_q_hdr_cpl.flt_q_hdr.hdr_dec_flt_cpltr_seg;
    flt_q_hdr.log_rcvd_flds             = flt_q_hdr_cpl.log_rcvd_flds ;  
    flt_q_hdr.flt_q_cpl_last            = flt_q_hdr_cpl.flt_q_hdr.flt_q_cpl_last; 
    flt_q_hdr.flt_q_poisoned            = flt_q_hdr_cpl.flt_q_hdr.flt_q_poisoned; 
    flt_q_hdr.flt_q_td                  = flt_q_hdr_cpl.flt_q_hdr.flt_q_td; 
    flt_q_hdr.flt_q_cpl_lower_addr      = flt_q_hdr_cpl.flt_q_hdr.flt_q_cpl_lower_addr; 
    flt_q_hdr.flt_q_cpl_bcm             = flt_q_hdr_cpl.flt_q_hdr.flt_q_cpl_bcm; 
    flt_q_hdr.flt_q_cplid               = flt_q_hdr_cpl.flt_q_hdr.flt_q_cplid; 
    flt_q_hdr.flt_q_byte_cnt            = flt_q_hdr_cpl.flt_q_hdr.flt_q_byte_cnt;
    flt_q_hdr.flt_q_dw_len              = flt_q_hdr_cpl.flt_q_hdr.flt_q_dw_len; 
    flt_q_hdr.flt_q_prfx                = flt_q_hdr_cpl.flt_q_prfx; 
    flt_q_hdr.flt_q_cpl_status          = flt_q_hdr_cpl.flt_q_hdr.flt_q_cpl_status; 
    flt_q_hdr.flt_q_func_nmbr           = flt_q_hdr_cpl.flt_q_hdr.flt_q_func_nmbr; 
    flt_q_hdr.flt_q_TAG                 = flt_q_hdr_cpl.flt_q_hdr.flt_q_TAG; 
    flt_q_hdr.flt_q_REQID               = flt_q_hdr_cpl.flt_q_hdr.flt_q_REQID; 
    flt_q_hdr.flt_q_attr                = flt_q_hdr_cpl.flt_q_hdr.flt_q_attr; 
    flt_q_hdr.flt_q_tc                  = flt_q_hdr_cpl.flt_q_hdr.flt_q_tc; 
    flt_q_hdr.flt_q_type                = flt_q_hdr_cpl.flt_q_hdr.flt_q_type; 
    flt_q_hdr.flt_q_fmt                 = flt_q_hdr_cpl.flt_q_hdr.flt_q_fmt; 
    flt_q_hdr.flt_q_destination         = flt_q_hdr_cpl.flt_q_hdr.flt_q_destination;
 
    conv_hdr_from_cpl_type              = flt_q_hdr;
    
  end
endfunction

endpackage
//
`endif //__GUARD__RADM_MS_PKG__SVH__

