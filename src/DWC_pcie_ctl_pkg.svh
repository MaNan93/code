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
// ---    $Revision: #9 $
// ---    $Id: //dwh/pcie_iip/main/DWC_pcie/DWC_pcie_ctl/src/DWC_pcie_ctl_pkg.svh#9 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
//
// ----------------------------------------------------------------------------

`ifndef __GUARD__DWC_PCIE_CTL_PKG__SVH__
`define __GUARD__DWC_PCIE_CTL_PKG__SVH__

`include "include/DWC_pcie_ctl_all_defs.svh"

package DWC_pcie_ctl_pkg;
    
    // -----------------------------------------------------------------------------
    // General parameters
    // -----------------------------------------------------------------------------
    localparam     TP               = `TP;
    localparam int NW               = `CX_NW;
    localparam int BUSNUM_WD        = `CX_BUSNUM_WD;
    localparam int DEVNUM_WD        = `CX_DEVNUM_WD;
    localparam int NVC              = 32'(`CX_NVC);
    localparam int NVC_WD           = `CX_NVC_LOG2;
    localparam int NPRFX            = `CX_NPRFX;
    localparam int RCB_DW           = (`CX_RCB/4);
    localparam int RCB_DW_WD        = $clog2(RCB_DW);
    localparam int TAG_SIZE         = `CX_TAG_SIZE;
    localparam int HCRD_WD          = `CX_HCRD_WD;
    localparam int DCRD_WD          = `CX_DCRD_WD;
    localparam int ATTR_WD          = `FLT_Q_ATTR_WIDTH;
    localparam int LOOKUPID_WD      = `CX_REMOTE_LOOKUPID_WD;
    localparam int RX_NDLLP         = `CX_RX_NDLLP;
    localparam int N_XADM_IF        = `N_XADM_IF;
    localparam int N_XADM_P_IF      = `N_XADM_P_IF;
    
    localparam DW  = (`CC_DEVICE_TYPE==`CC_EP) ? (`RADM_PARBITS_OUT_VALUE ? (32*`CX_NW) + `TRGT_DATA_PROT_WD : (32*`CX_NW) ) : (32*`CX_NW); // Width of datapath in bits - For ECC we export the check bits.
    localparam PRFX_W_PAR   = `CX_PRFX_W_PAR;
    localparam PRFX_DW      = `CX_PRFX_DW;
    // -----------------------------------------------------------------------------
    
    // -----------------------------------------------------------------------------
    // Functions-related parameters
    // -----------------------------------------------------------------------------
    localparam int NF     = `CX_NFUNC;
    localparam int NVF    = `CX_NVFUNC;
    localparam int PF_WD  = `CX_NFUNC_WD;
    localparam int VF_WD  = `CX_NVFUNC_WD;
    localparam int VFI_WD = `CX_NVFUNC_EWD;
    localparam int MSI_NF = `CX_MSI_NFUNC;
    localparam int SRIOV_NF =  `CX_SRIOV_NFUNC; //Number of Physical Functions for SRIOV
    // -----------------------------------------------------------------------------

    // -----------------------------------------------------------------------------
    // Functions-related parameters
    // -----------------------------------------------------------------------------
    localparam int DC_DMA_TYPE_WIDTH         = `DC_DMA_TYPE_WIDTH;
    localparam int CC_NUM_DMA_MAX_CHAN_WIDTH = `CC_NUM_DMA_MAX_CHAN_WIDTH;
    
    // -----------------------------------------------------------------------------
    // RASDP parameters
    // -----------------------------------------------------------------------------
    localparam int RAS_PROT_RANGE    = `CX_RAS_PROT_RANGE;
    localparam int RAS_PROT_TYPE     = `CX_RAS_PROT_TYPE;
    localparam int RAS_CORR_EN       = `CX_RAS_CORRECTION_EN;
    localparam int RAS_PARITY_MODE   = `CX_RAS_PARITY_MODE;
    localparam int ERROR_INJ_EN_WD   = `CX_RAS_ERROR_INJ_EN_WD;
    localparam int ERROR_INJ_MASK_WD = `CX_RAS_ERROR_INJ_MASK_WD;

    // RAS DP Error Injection
    localparam MAX_RAS_PROT_CHK_N                 = 16*1024;
    localparam RAS_DP_PROT_CHK_ID_BASE_AXI_BRIDGE =  0* 512;
    localparam RAS_DP_PROT_CHK_ID_BASE_XAIM       =  1* 512;
    localparam RAS_DP_PROT_CHK_ID_BASE_XADM       =  2* 512;
    localparam RAS_DP_PROT_CHK_ID_BASE_XTLH       =  3* 512;
    localparam RAS_DP_PROT_CHK_ID_BASE_XDLH       =  4* 512;
    localparam RAS_DP_PROT_CHK_ID_BASE_XPLH       =  5* 512;
    localparam RAS_DP_PROT_CHK_ID_BASE_RDLH       =  6* 512;
    localparam RAS_DP_PROT_CHK_ID_BASE_RTLH       =  7* 512;
    localparam RAS_DP_PROT_CHK_ID_BASE_RADM       =  8* 512;
    localparam RAS_DP_PROT_CHK_ID_BASE_CXL        = 12*512;
    localparam RAS_DP_PROT_CHK_ID_BASE_VLSM       = 14*512;
    localparam RAS_DP_PROT_CHK_ID_BASE_HDMA       = 15* 512;
    localparam RAS_DP_PROT_CHK_ID_BASE_ORDRB      = 16* 512;

    
    typedef struct packed {
        logic [`RAS_PROT_CHK_ID_WD-1:0] ras_prot_chk_id;
        logic                           valid;
    } ras_dp_err_inj_t;
    // RAS DP Error Logging Packet
    localparam MAX_SUPPORTED_WD = 2048;
    localparam RAS_ERROR_LOG_WD = 16;
    typedef struct packed {
        logic [16-1:0] log;
        logic          valid;
    } ras_dp_err_log_t;

    localparam MAX_RAS_ERR_LOG_WORD_NUM = 4;

    // word 0
    localparam RAS_ERROR_SLICE_ID_INDEX = 0;

    localparam RAS_ERROR_FORMAT_INDEX   = 13;
    localparam RAS_ERROR_FORMAT_WD      =  1;
    
    localparam RAS_ERROR_TYPE_INDEX     = 14;
    localparam RAS_ERROR_TYPE_WD        =  2;
    typedef enum logic[RAS_ERROR_TYPE_WD-1:0] {
          CORRECTABLE
        , UNCORRECTABLE
        , ERR_INJ_FAILURE
        , ERR_INJ_SUCCESSFUL
    } ras_dp_error_type_t;

    // word 1
    localparam RAS_ERROR_CHK_ID_INDEX       = 0;
    localparam RAS_ERROR_CHK_ID_WD          = $clog2(MAX_RAS_PROT_CHK_N);
    localparam RAS_ERROR_PROT_RANGE_INDEX   = RAS_ERROR_CHK_ID_WD;
    localparam RAS_ERROR_PROT_RANGE_WD      = 2;

    // word 2
    localparam RAS_RAM_ADDR_LSB_INDEX = 0;
    localparam RAS_RAM_ADDR_LSB_WD    = RAS_ERROR_LOG_WD;

    // word 3
    localparam RAS_RAM_ADDR_MSB_INDEX = 0;
    localparam RAS_RAM_ADDR_MSB_WD    = RAS_ERROR_LOG_WD;

    function automatic int calc_ecc_wd (int DATA_BITS);
        begin
            int CHK_WD;
            if (DATA_BITS > 247) begin
                CHK_WD = 10;
            end else if (DATA_BITS > 120) begin
                CHK_WD = 9;
            end else if (DATA_BITS > 57) begin
                CHK_WD = 8;
            end else if (DATA_BITS > 26) begin
                CHK_WD = 7;
            end else begin
                CHK_WD = 6;
            end
            return CHK_WD;
        end
    endfunction

    function automatic int f_verify_ecc_wd (
        input int DATA_WD,
        input int ADDR_WD,
        input int PROT_RANGE
    );
        begin
            int prot_inst = DATA_WD/PROT_RANGE;
            int remainder = DATA_WD%PROT_RANGE;

            f_verify_ecc_wd = ((prot_inst*calc_ecc_wd(PROT_RANGE+ADDR_WD)) + ((remainder==0) ? 0 : calc_ecc_wd(remainder+ADDR_WD)));
        end
    endfunction // f_verify_ecc_wd


    // -----------------------------------------------------------------------------
    // ATU parameters
    // TODO: protect with CX_INTERNAL_ATU_ENABLE
    // -----------------------------------------------------------------------------
    localparam int ATU_UPR_LMT_WD        = `CX_ATU_MAX_REGION_SIZE;                                     // Width of Upper Limit Address register
    localparam int ATU_UPR_LMT_WD_MDFD   = `CX_ATU_MAX_REGION_SIZE == 32 ? 31: `CX_ATU_MAX_REGION_SIZE; // Modified width of Upper Limit Address register
    localparam int ATU_BASE_WD           = `CX_ATU_BASE_WIDTH;
    localparam int ATU_REG_WD            = `CX_ATU_REGION_WIDTH;
    localparam int ATU_REG_LWR_WD        = 32-ATU_REG_WD;
    localparam int ATU_OUT_NREGIONS      = `CX_ATU_NUM_OUTBOUND_REGIONS;
    localparam int ATU_OUT_NREGIONS_MIN1 = `CX_ATU_OUT_NREGIONS_MIN1;
    localparam int ATU_IN_NREGIONS       = `CX_ATU_NUM_INBOUND_REGIONS;
    localparam int ATU_IN_NREGIONS_MIN1  = `CX_ATU_IN_NREGIONS_MIN1;
    // -----------------------------------------------------------------------------
    
    // -----------------------------------------------------------------------------
    // TODO: Temporary params
    // -----------------------------------------------------------------------------
    localparam int N_TRGT_CPL_IF     = 1; //Assumed to be either 1 or 2
    localparam int N_TRGT_NP_IF      = 1; //Assumed to be either 1 or 2
    // -----------------------------------------------------------------------------
    
    // -----------------------------------------------------------------------------
    // Controller-wide typedefs (enums and structs)
    // -----------------------------------------------------------------------------
    
    // -----------------------------------------------------------------------------
    

    // -----------------------------------------------------------------------------
    // Multistream Architecture
    // -----------------------------------------------------------------------------

    // XALI Prefix bus
    localparam int XALI_PRFX_PROT_WD               = `CX_PRFX_PAR_WD;
    localparam int XALI_PRFX_WO_PROT_WD            = (32*`CX_NPRFX);
    localparam int XALI_PRFX_W_PROT_WD             = XALI_PRFX_WO_PROT_WD + XALI_PRFX_PROT_WD;
    
    // XALI Compressed Header
    localparam int XALI_HDR_PROT_WD                = `CLIENT_HDR_PROT_WD;
    localparam int XALI_HDR_WO_PROT_WD             = `CLIENT_HDR_WD;
    
    // XALI Data bus
    localparam int XALI_DATA_PROT_WD               = `TRGT_DATA_PROT_WD;
    localparam int XALI_DATA_WO_PROT_WD            = 32*`CX_NW;
    localparam int XALI_DATA_W_PROT_WD             = XALI_DATA_PROT_WD + XALI_DATA_WO_PROT_WD;

    
    // Number of interfaces (XALI, CCIX, DMA, XADM, RADM)
    localparam int N_XALI_P_IF_VC               [0:7] = `N_XALI_P_IF_VC  ;
    localparam int N_XALI_NP_IF_VC              [0:7] = `N_XALI_NP_IF_VC ;
    localparam int N_XALI_CPL_IF_VC             [0:7] = `N_XALI_CPL_IF_VC;
    localparam int N_XALI_IF_VC                 [0:7] = `N_XALI_IF_VC    ;
    localparam int N_XALI_IF                          = `N_XALI_IF       ;
    localparam int N_XALI_P_IF                        = `N_XALI_P_IF     ;
    localparam int N_XALI_NP_IF                       = `N_XALI_NP_IF    ;
    localparam int N_XALI_CPL_IF                      = `N_XALI_CPL_IF   ;
    localparam int N_XALI_CUMULATIVE_PER_VC     [0:7] = `N_XALI_CUMULATIVE_PER_VC;
    
    localparam int N_CCIX_P_IF_VC               [0:7] = `N_CCIX_P_IF_VC  ;
    localparam int N_CCIX_NP_IF_VC              [0:7] = `N_CCIX_NP_IF_VC ;
    localparam int N_CCIX_CPL_IF_VC             [0:7] = `N_CCIX_CPL_IF_VC;
    localparam int N_CCIX_IF_VC                 [0:7] = `N_CCIX_IF_VC    ;
    localparam int N_CCIX_IF                          = `N_CCIX_IF       ;
    
    localparam int N_DMA_P_IF_VC                [0:7] = `N_DMA_P_IF_VC   ;
    localparam int N_DMA_NP_IF_VC               [0:7] = `N_DMA_NP_IF_VC  ;
    localparam int N_DMA_CPL_IF_VC              [0:7] = `N_DMA_CPL_IF_VC ;
    localparam int N_DMA_IF_VC                  [0:7] = `N_DMA_IF_VC     ;
    localparam int N_DMA_IF                           = `N_DMA_IF        ;
    
    localparam int N_XADM_P_IF_VC               [0:7] = `N_XADM_P_IF_VC  ;
    localparam int N_XADM_NP_IF_VC              [0:7] = `N_XADM_NP_IF_VC ;
    localparam int N_XADM_CPL_IF_VC             [0:7] = `N_XADM_CPL_IF_VC;
    localparam int N_XADM_IF_VC                 [0:7] = `N_XADM_IF_VC    ;

    localparam int N_XAIM_IF                          = `N_XALI_IF + 2   ; // XALI + MSG_GEN + LBC
    
    localparam int N_XADM_NP_IF                       = `N_XADM_NP_IF    ;
    localparam int N_XADM_CPL_IF                      = `N_XADM_CPL_IF   ;
    
    localparam int N_XADM_P_CUMULATIVE_PER_VC   [0:7] = `N_XADM_P_CUMULATIVE_PER_VC;
    localparam int N_XADM_NP_CUMULATIVE_PER_VC  [0:7] = `N_XADM_NP_CUMULATIVE_PER_VC;
    localparam int N_XADM_CPL_CUMULATIVE_PER_VC [0:7] = `N_XADM_CPL_CUMULATIVE_PER_VC;
    localparam int N_XADM_CUMULATIVE_PER_VC     [0:7] = `N_XADM_CUMULATIVE_PER_VC;
    
    localparam int RADM_HDR_SZ_VC_CPL           [0:7] = `RADM_HDR_SZ_VC_CPL;
    localparam int RADM_DATA_SZ_VC_CPL          [0:7] = `RADM_DATA_SZ_VC_CPL;
    
    // Width to represent the source transmission port of a TLP
    localparam int TX_PORT_ID_WD = `CX_TX_PORT_ID_WD;
  //  localparam int TX_PORT_ID_WD = $clog2(1+1+1 
  //          `ifdef CC_DMA_ENABLE                                +1 `endif 
  //          `ifdef CX_MULTISTREAM_ARCH_PORT_ARB_XALI_TRANSLATED +1 `endif 
  //          `ifdef CX_CCIX_INTERFACE_ENABLE                     +1 `endif);

    // Identify the source transmission port of TLP
    typedef enum logic[TX_PORT_ID_WD-1:0] {
        E_TX_PORT_ID_MSG,
        E_TX_PORT_ID_LBC,
        E_TX_PORT_ID_XALI
                                ,E_TX_PORT_ID_DMA


    } tx_port_id_e;

    // Width to represent the PR Type on the TX path
    localparam int P_REQ_TX_TYPE_WD = `CX_P_REQ_TX_TYPE_WD;
    
    // Width to represent the NPR Type on the TX path
    localparam int NP_REQ_TX_TYPE_WD = `CX_NP_REQ_TX_TYPE_WD;
    
    // Width to represent the NPR Type on the TX path
    localparam int CPL_TX_TYPE_WD = `CX_CPL_REQ_TX_TYPE_WD;
    
    // Posted Request Types that are supported on transmission
    typedef enum logic[P_REQ_TX_TYPE_WD-1:0] {
          E_P_REQ_TX_MEMWR
        , E_P_REQ_TX_MSG
    } p_req_tx_type_e;
    
    // NonPosted Request Types that are supported on transmission
    typedef enum logic[NP_REQ_TX_TYPE_WD-1:0] {
          E_NP_REQ_TX_MEMRD_NON_ATS
        , E_NP_REQ_TX_IO_WR
        , E_NP_REQ_TX_IO_RD
           ,E_NP_REQ_TX_CFG_WR, E_NP_REQ_TX_CFG_RD
            ,E_NP_REQ_TX_MEMRD_ATS
         ,E_NP_REQ_TX_ATOMIC
     ,E_NP_REQ_TX_DMWR
    } np_req_tx_type_e;
    
    // Completion Types that are supported on transmission
    typedef enum logic[CPL_TX_TYPE_WD-1:0] {
          E_CPL_TX_CPL
        , E_CPL_TX_CPLD
    } cpl_tx_type_e;
   
    // ADM Framing/Control Struct
    typedef struct packed{
        // Header
        logic                                  hv;                      // Header Valid
        // Data
        logic                                  dv;                      // Data Valid
        // General
        logic                                  eot;                     // End of TLP
        logic                                  bad_eot;                 // "Bad" End of TLP
        logic                            [2:0] order_seqnum;            // Unique Order Sequence Number
    } adm_fs_s;
 
    // XAIM XALI Header Packet
    typedef struct packed{
        logic                                  addr_align_en;
        logic [7:0]                            tlp_byte_en;
        logic [15:0]                           remote_req_id;
        logic [11:0]                           cpl_byte_cnt;
        logic [2:0]                            tlp_tc;
        logic [`FLT_Q_ATTR_WIDTH-1:0]          tlp_attr;
        logic [2:0]                            cpl_status;
        logic                                  cpl_bcm;
        logic                                  tlp_dv;
        logic                                  tlp_eot;
        logic                                  tlp_bad_eot;
        logic                                  tlp_hv;
        logic [1:0]                            tlp_fmt;
        logic [4:0]                            tlp_type;
        logic                                  tlp_td;
        logic                                  tlp_ep;
        logic [12:0]                           tlp_byte_len;
        logic [63:0]                           tlp_addr;
        logic [`CX_TAG_SIZE-1:0]               tlp_tid;
        logic [`CX_NFUNC_WD-1:0]               tlp_func_num;
        logic [1:0]                            tlp_ats;
        logic                                  tlp_nw;
        logic                                  tlp_th;
        logic [1:0]                            tlp_ph;
        logic [7:0]                            tlp_st;
        logic                                  tlp_atu_bypass;
        logic [`CX_REMOTE_LOOKUPID_WD-1:0]     cpl_lookup_id;
        //`ifdef CX_HEADER_PASS_THROUGH
        logic [8:0]                            tlp_segment;
        //`endif //CX_HEADER_PASS_THROUGH
        logic [8:0]                            tlp_dst_segment;
        logic [`DC_DMA_TYPE_WIDTH-1:0]         tlp_dma;
        logic [`CC_NUM_DMA_MAX_CHAN_WIDTH-1:0] tlp_dma_channel;
        logic                                  cpl_last;
    } xali_pkt_hdr_t;
    
    // XAIM XALI Packet
    typedef struct packed{
        logic [(32*`CX_NPRFX)-1:0]           prfx;
        xali_pkt_hdr_t                       hdr;
        logic [(32*`CX_NW)-1:0]              data;
        logic [`CX_PRFX_PAR_WD-1:0]          prfx_prot;
        logic [`CLIENT_HDR_PROT_WD-1:0]      hdr_prot;
        logic [`TRGT_DATA_PROT_WD-1:0]       data_prot;
        logic [2:0]                          order_seqnum;
        logic                                is_dma;
    } xali_pkt_t;
    // -----------------------------------------------------------------------------
    


    

    // -----------------------------------------------------------------------------
    // DMA  
    // -----------------------------------------------------------------------------
    localparam int CRGB_ADDR_WIDTH = `CC_CRGB_ADDR_WIDTH;
    localparam int CRGB_DATA_WIDTH = `CC_CRGB_DATA_WIDTH;
    localparam int CRGB_BE_WIDTH   = `CC_CRGB_BE_WIDTH;
    // -----------------------------------------------------------------------------

    // -----------------------------------------------------------------------------
    // PM M/S state signal width  
    // -----------------------------------------------------------------------------
    localparam int PM_MST_WD = `CX_PM_MST_WD; // width of pm_master_state signal
    localparam int PM_SLV_WD = `CX_PM_SLV_WD; // width of pm_slave_state signal
    // -----------------------------------------------------------------------------

    // ------------------------------------------------------------------------------------------
    //  Tx Interface Watchdog Timer
    // -----------------------------------------------------------------------------------------


    //////////////////////////////////////////////////
    /// TODO CLEAN UP
    //////////////////////////////////////////////////
    //
    localparam NW_PRFX      = `CX_NPRFX;
    localparam int NF_WD       = 32'(`CX_NFUNC_WD);                 // Number of bits in the Function Number
    localparam int HDR_PROT_WD = `CX_RAS_PCIE_EXTENDED_HDR_PROT_WD; // XADM Common Header ecc/parity protection width
    localparam DCA_WD            = `CX_LOGBASE2(NW/4+1); 
    localparam CPL_LUT_DEPTH     = `CX_CPL_LUT_DEPTH;     
                                                     // = `CX_MAX_TAG + 1 
                                                     // number of max tag that this core is configured to run
                                                     // Extra safe entry(769-1) to stay when 767<time_addr=timer[CPL_LUT_PTR_WD-1:0]<1024
                                                     // Max CPL_LUT_DEPTH=769
    localparam MSG_TLP_WD          = `CX_RADM_NFC_TRGT_INTF;
    localparam ERROR_TLP_WD          = 0 + 1;  


  // 1 pipeline stage before filter to align CDM's match
  localparam ANTI_CTRL_PIPE_DELAY = 1;

    localparam PRFX_PROT_WD = `CX_RX_PRFX_PAR_WD;  //KN
    localparam PRFX_WO_PAR  =  PRFX_W_PAR - PRFX_PROT_WD;
 

  //////////////////////////////////////
  // TODO END CLEANUP
  //////////////////////////////////////

localparam DW_W_PAR         = `TRGT_DATA_WD; // Width of datapath in bits plus the parity bits.
localparam DW_WO_PAR        = (32*`CX_NW);                                      // Width of datapath in bits.
localparam TX_HW_W_PAR      = `CX_TX_HW_W_PAR;
localparam DATA_WIDTH       = `CX_DATA_WIDTH;
localparam APP_CRD_WD       = `CX_NW_GTR_4_VALUE ? `CX_LOGBASE2(`CX_NW/4+1)*`CX_NVC : `CX_NVC;
localparam ORIG_DATA_WD     = `CX_PHY_NB * 8;
localparam PIPE_DATA_WD     = `CX_PIPE_DATA_WD;
localparam RADM_SBUF_HDRQ_ERR_ADDR_WD = `CX_RADM_SBUF_HDRQ_ERR_ADDR_WD;
localparam RASDP_BYPASS_HDR_PROT_WD_O_BASE = `CX_RASDP_BYPASS_HDR_PROT_WD_O_BASE;
localparam L2NL = `CX_L2NL;

localparam TX_COEF_WD = `CX_TX_COEF_WD; // Width of concatenated bus for Equalization Coefficients: {C(+1), C(0), C(-1)}
localparam RX_PSET_WD = `CX_RX_PSET_WD; // Width of Receiver Equalization Presets
localparam TX_PSET_WD = `CX_TX_PSET_WD; // Width of Transmitter Equalization Presets
localparam TX_FSLF_WD = `CX_TX_FSLF_WD; // Width of concatenated bus for Equalization "Low Frequency" and "Full Swing" values: {LF, FS}
localparam TX_FS_WD   = `CX_TX_FS_WD;   //Width of Full Swing or Low Frequency
localparam TX_CRSR_WD = `CX_TX_CRSR_WD; //Width of cursor
localparam FOMFEEDBACK_WD = `CX_FOMFEEDBACK_WD; // Width of Figure of Merit
typedef struct packed {
  logic          drift_buffer_enabled;
  logic [1:0]    cxl_nop_hint_info;
  logic          cxl_throttle_required;
  logic          cxl_lopt_flit_enabled;
  logic          cxl_pbr_flit_enabled;
  logic          cxl_mld_enabled;
  logic          cxl_68B_flit_vh_enabled;
  logic          sync_hdr_bypass_enabled;
  logic          cache_enabled;
  logic          mem_enabled;
  logic          io_enabled;
} ltssm_cxl_enable_t;

localparam K_DMA_RBUF_SLICE_WD = `CX_DMA_RBUF_SLICE_WD;
localparam K_DMA_RBUF_NSLICES  = `CX_DMA_RBUF_NSLICES;


    
localparam TX_TLP_PREFIX_WD   = (32*`CX_NPRFX)+ `CX_PRFX_PAR_WD;
localparam PRFX_WIDTH         = `CX_AXI_PRFX_WIDTH; 

localparam CC_OB_CCMP_NSLICES  = `CC_OB_CCMP_NSLICES;
localparam CC_OB_CCMP_SLICE_WD = `CC_OB_CCMP_SLICE_WD;

localparam TPH_ST_WD         = `CX_TPH_ST_WD;
localparam TPH_PH_WD         = `CX_TPH_PH_WD;
localparam TPH_TH_WD         = `CX_TPH_TH_WD;
localparam MISC_INFO_TPH_WD  = `CX_MISC_INFO_TPH_WD;


endpackage // DWC_pcie_ctl_pkg

`endif // __GUARD__DWC_PCIE_CTL_PKG__SVH__
