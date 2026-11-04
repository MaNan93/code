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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/products/DWC_pcie_core_pkg.svh#9 $
// -------------------------------------------------------------------------

`ifndef __GUARD__DWC_PCIE_CORE_PKG__SVH__
`define __GUARD__DWC_PCIE_CORE_PKG__SVH__

`include "DWC_pcie_ctl_pkg.svh"
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/pcie_pkg.svh"

// -----------------------------------------------------------------------------
// --- Package Description: Package containing common variables and functions for DWC_pcie_core
// -----------------------------------------------------------------------------
package DWC_pcie_core_pkg;
    
//    `ifdef CX_INTERNAL_ATU_ENABLE
    import DWC_pcie_ctl_pkg::ATU_REG_LWR_WD;
//    `endif // CX_INTERNAL_ATU_ENABLE
    import DWC_pcie_ctl_pkg::N_TRGT_CPL_IF;
    import DWC_pcie_ctl_pkg::tx_port_id_e;
    import DWC_pcie_ctl_pkg::p_req_tx_type_e;
    import DWC_pcie_ctl_pkg::np_req_tx_type_e;
    import DWC_pcie_ctl_pkg::cpl_tx_type_e;
    import pcie_pkg::fc_type_e;
    import pcie_pkg::E_P;
    import pcie_pkg::E_NP;
    import pcie_pkg::E_CPL;
    import pcie_pkg::E_FC_NONE;
    import pcie_pkg::fm_tkn_t;
    
    // -----------------------------------------------------------------------------
    // Global params and typedefs  
    // -----------------------------------------------------------------------------
    
    // LTSSM States
    typedef enum logic [5:0] {
      S_DETECT_QUIET      = 6'h00,
      S_DETECT_ACT        = 6'h01,
      S_POLL_ACTIVE       = 6'h02,
      S_POLL_COMPLIANCE   = 6'h03,
      S_POLL_CONFIG       = 6'h04,
      S_PRE_DETECT_QUIET  = 6'h05,
      S_DETECT_WAIT       = 6'h06,
      S_CFG_LINKWD_START  = 6'h07,
      S_CFG_LINKWD_ACEPT  = 6'h08,
      S_CFG_LANENUM_WAIT  = 6'h09,
      S_CFG_LANENUM_ACEPT = 6'h0A,
      S_CFG_COMPLETE      = 6'h0B,
      S_CFG_IDLE          = 6'h0C,
      S_RCVRY_LOCK        = 6'h0D,
      S_RCVRY_SPEED       = 6'h0E,
      S_RCVRY_RCVRCFG     = 6'h0F,
      S_RCVRY_IDLE        = 6'h10,
      S_L0                = 6'h11,
      S_L0S               = 6'h12,
      S_L123_SEND_EIDLE   = 6'h13,
      S_L1_IDLE           = 6'h14,
      S_L2_IDLE           = 6'h15,
      S_L2_WAKE           = 6'h16,
      S_DISABLED_ENTRY    = 6'h17,
      S_DISABLED_IDLE     = 6'h18,
      S_DISABLED          = 6'h19,
      S_LPBK_ENTRY        = 6'h1A,
      S_LPBK_ACTIVE       = 6'h1B,
      S_LPBK_EXIT         = 6'h1C,
      S_LPBK_EXIT_TIMEOUT = 6'h1D,
      S_HOT_RESET_ENTRY   = 6'h1E,
      S_HOT_RESET         = 6'h1F,
      S_RCVRY_EQ0         = 6'h20,
      S_RCVRY_EQ1         = 6'h21,
      S_RCVRY_EQ2         = 6'h22,
      S_RCVRY_EQ3         = 6'h23
    } ltssm_state_e;

    // RTLH Received FC struct
    typedef struct packed{
        logic [`CX_RX_NDLLP-1:0]       upd;              // Update Transmit credit information
        logic [`CX_RX_NDLLP-1:0][31:0] data;             // 32bits FC update data
        logic                      upd_is_optimized; // The received update is Optimized (value is data[0][31:0])
    } rtlh_rfc_t;

    // Order structure
    typedef struct packed {
      logic         push;
      logic [127:0] push_header;
      logic [2:0]   push_fmt;
      logic [4:0]   push_type;
      logic         push_ro;
      logic         push_ido;
      logic [15:0]  push_rid;
      logic [2:0]   push_segnum;
      logic         push_tlp_flowthrough;
      logic         push_dllp_abort;
      logic         push_nullified;
      logic         push_eot;
    } tlp_order_t;    

    // -----------------------------------------------------------------------------

    // -----------------------------------------------------------------------------
    // Parameter Declarations
    // -----------------------------------------------------------------------------
    localparam NXQDW                = (`CX_NW==16) ? 2*(`CX_NW / 4) : 0; // Number of 128-bit qdwords extracted in rtlh_tlp_extract
    localparam QDW_PROT_WD          = `CX_RAS_QDW_PROT_WD;
    localparam QDW_W_PROT           = 128 + QDW_PROT_WD;         // Generic qdword width including parity bits
    localparam CCIX_WD              = `CX_CCIX_RX_WD;
    localparam DATA_PAR_WD          = `TRGT_DATA_PROT_WD;
    localparam DW                   = (`CC_DEVICE_TYPE==`CC_EP) ? (`RADM_PARBITS_OUT_VALUE ? (32*`CX_NW) + DATA_PAR_WD : (32*`CX_NW) ) : (32*`CX_NW); // Width of datapath in bits - For ECC we export the check bits.
    localparam RAS_PCIE_HDR_PROT_WD = `CX_RAS_PCIE_HDR_PROT_WD;
    localparam RX_TLP               = `CX_RX_TLP;                // Number of TLPs that can be received in a single cycle
    localparam PRFX_WD              = 32*`CX_NPRFX;              // width of TLP prefix support in bits
    localparam PRFX_W_PAR_RX        = RX_TLP*(PRFX_WD + `CX_RX_PRFX_PAR_WD);
    //----- ERROR STATUS REGISTER -----//
    //----- Data Link Layer Errors ----//
    localparam [4:0] DATALINK_PROTOCOL_ERR     = 5'd4  ;
    localparam [4:0] SURPRISE_DOWN_ERR         = 5'd5  ;
    localparam [4:0] FLOW_CONTROL_PROTOCOL_ERR = 5'd13 ;
    localparam [4:0] COMPLETION_TIMEOUT        = 5'd14 ;
    //---- Transaction Layer Errors ---//
    localparam [4:0] UNCORR_INT_ERR            = 5'd22 ;
    localparam [4:0] RECEIVER_OVRFLW           = 5'd17 ;
    localparam [4:0] MALFORMED_TLP             = 5'd18 ;
    localparam [4:0] IDE_CHK_FAILED            = 5'd28 ;
    localparam [4:0] ECRC_CHK_FAILED           = 5'd19 ;
    localparam [4:0] MISROUTED_IDE_TLP         = 5'd29 ;
    localparam [4:0] ATOMIC_OP_EGRSS           = 5'd24 ;
    localparam [4:0] DMWR_REQUEST_EGRSS_BLOCKD = 5'd27 ;
    localparam [4:0] TLP_TRANS_EGRSS_BLOCKD    = 5'd31 ;
    localparam [4:0] TLP_PRFX_BLOCKD           = 5'd25 ;
    localparam [4:0] ACS_VIOLATION             = 5'd21 ;
    localparam [4:0] MC_BLOCKD_TLP             = 5'd23 ;
    localparam [4:0] UNSUPP_REQUEST            = 5'd20 ;
    localparam [4:0] COMPLETER_ABORT           = 5'd15 ;
    localparam [4:0] UNEXP_COMPLETION          = 5'd16 ;
    localparam [4:0] PCRC_CHECK_FAILED         = 5'd30 ;
    localparam [4:0] POISONED_TLP_RECEIVED     = 5'd12 ;
    localparam [4:0] POISONED_TLP_EGRSS_BLOCKD = 5'd26 ; 

    // Raw token struct used in rplh_fm_pkt_finder and submodules
    typedef struct packed {
        fm_tkn_t     tkn;     // Raw token: NOP_TKN, PFX_TKN or HDR_TKN
        logic [4:0]  eot_flt; // Number of Flits left in order to reach the end of the TLP
        logic [2:0]  eot_dec; // Number of 256b Decoder instances left in order to reach the end of the TLP
        logic [7:0]  eot_pos; // Position of the eot within the final 256b Decoder
    } fm_raw_tkn_t;



    // -----------------------------------------------------------------------------
    // Multistream arch params and typedefs
    // -----------------------------------------------------------------------------
    
    // ADM Prefix Bus for Multistream Arch
    localparam int ADM_PRFX_NW                            = `CX_NPRFX_XADM; // In case of non-IDE, must use one extra prefix to compensate for FM Local Prefix

    // ADM Prefix/Hdr Bus for Multistream Arch
    localparam int ADM_PRFX_HDR_PROT_WD                   = `CX_HDW_PROT;
    localparam int ADM_PRFX_HDR_NW                        = `CX_HDW;
    
    // ADM Data Bus for Multistream Arch
    localparam int ADM_DATA_PROT_WD                       = `TRGT_DATA_PROT_WD;
    localparam int ADM_DATA_WO_PROT_WD                    = `CX_NW*32;
    localparam int ADM_DATA_W_PROT_WD                     = ADM_DATA_WO_PROT_WD + ADM_DATA_PROT_WD;
    
    // ADM Merged Prefix/Hdr/Data bus for Multistream Arch (No ECRC/PCRC/MAC)
    localparam int ADM_PRFX_HDR_DATA_NO_INTEGRITY_PROT_WD = `CX_HDW_NW_PROT;
    localparam int ADM_PRFX_HDR_DATA_NO_INTEGRITY_NW      = `CX_HDW_NW;
    
    // ADM Merged Prefix/Hdr/Data bus for Multistream Arch
    localparam int ADM_PRFX_HDR_DATA_PROT_WD              = `CX_NDW_PROT;
    localparam int ADM_PRFX_HDR_DATA_NW                   = `CX_NDW;
    
    // Compressed Header for MsgGen/LBC
    localparam int LBC_MSG_HDR_PROT_WD                    = `CX_RAS_PCIE_EXTENDED_HDR_PROT_WD;
    localparam int LBC_MSG_HDR_WO_PROT_WD                 = `ST_HDR;
    localparam int LBC_MSG_HDR_W_PROT_WD                  = LBC_MSG_HDR_WO_PROT_WD                                                                                   + LBC_MSG_HDR_PROT_WD
                                                                                   ;
 
    localparam     RX_NQDW                   = (`CX_NW==32) ? 14 : (`CX_NW==16)? 7 : (`CX_NW==8)? 4 : 2; // Number of 128-bit quad-dwords received per cycle
    localparam     QDW_DW                    = 128 ;
    localparam     QDW_PAR                   = 0 + 16 ;
    
    // XADM to RADM CPL LUT to inform for transmission of NPR
    typedef struct packed{
        logic            [`N_XADM_NP_IF-1:0]               valid;       // Separate transmitted TLP done signal for each fragments.
        logic            [`N_XADM_NP_IF-1:0][12-1:0]       len_bytes;   // transmitted TLP length in bytes
        logic            [`N_XADM_NP_IF-1:0][2:0]          attr;        // transmitted TLP attributes
        logic            [`N_XADM_NP_IF-1:0][6:0]          low_addr;    // transmitted TLP lower address (full). Replacing the first_be
        logic            [`N_XADM_NP_IF-1:0][3-1:0]        tc;          // transmitted TLP tc
        logic            [`N_XADM_NP_IF-1:0][16-1:0]       req_id;      // interface id, it is designed to identify which Client interface the completion belongs to.
        logic            [`N_XADM_NP_IF-1:0][`CX_TAG_SIZE-1:0] tag;         // transmitted TLP tag
        np_req_tx_type_e [`N_XADM_NP_IF-1:0]               np_req_type; // An enumeration encoding the type of the tlp
        logic            [`N_XADM_NP_IF -1:0]              cpl_trgt_interface_no;
    } xadm_radm_tx_npr_t;
    
    // XADM to CDM PCI errors
    typedef struct packed{
        logic [`CX_NFUNC-1:0][`N_XADM_IF-1:0]     cpl_ca;
        logic [`CX_NFUNC-1:0][`N_XADM_IF-1:0]     cpl_ur;
        logic [`CX_NFUNC-1:0][`N_XADM_IF-1:0]     cpl_poisoned;
        logic [`CX_NFUNC-1:0][`N_XADM_IF-1:0]     wreq_poisoned;
    } xadm_xmt_pci_errors_t;

    // RADM to XADM to inform for reception of CPL from TRGT1
    typedef struct packed{
        logic            [N_TRGT_CPL_IF-1:0]             good_eot;      // !tlp_abort && !dllp_abort && eot && !halt
        logic            [N_TRGT_CPL_IF-1:0]             is_last;       // cpl_last
        logic            [N_TRGT_CPL_IF-1:0]             is_cpl;        // fmt/hdr
        logic            [N_TRGT_CPL_IF-1:0]             is_cpld;       // fmt/hdr
        logic            [N_TRGT_CPL_IF-1:0]             is_successful; // cpl status
        logic            [N_TRGT_CPL_IF-1:0][`CX_NVC_LOG2-1:0] vc;            // tc_to_vc
        logic            [N_TRGT_CPL_IF-1:0][11:0]       byte_cnt;      // ByteCnt can come from CPL itself. Not reliable for ATS Transl Cpl, but not used in that case. Used only for Unsuccesful CPL
        logic            [N_TRGT_CPL_IF-1:0][6:0]        low_addr;      // LowAddr can come from CPL itself. Not reliable for ATS Transl Cpl, but not used in that case. Reserved for Atomic Cpl, but not used in that case.
        np_req_tx_type_e [N_TRGT_CPL_IF-1:0]             np_req_type;   // Type of the NPR
        logic            [N_TRGT_CPL_IF-1:0][9:0]        dw_len;        // dw_len
    }radm_xadm_rcvd_cpl_t;
    
    // RADM to XADM to inform for timeout of NPR in RADM CPL LUT
    typedef struct packed{
        logic              valid;
        logic [`CX_NVC_LOG2-1:0] vc;
        logic [7-1:0]      low_addr;
        logic [12-1:0]     byte_cnt;
        np_req_tx_type_e   np_req_type;
    }radm_xadm_timeout_npr_t;

    typedef struct packed {
        logic [9:0]        len_dw;
        logic [8:0]        requester_segment;
        logic              used_ded_credit;
        logic              ep;
        logic              td;
        logic [`CX_NVC_LOG2-1:0] vc;
        logic [`CX_NFUNC_WD-1:0]  func_num;
        logic [6:0]        low_addr;
        logic              is_atomic_cas;
        p_req_tx_type_e    p_req_type;
        np_req_tx_type_e   np_req_type;
        cpl_tx_type_e      cpl_type;
        logic              has_payload;
        logic              msg_is_ptm;
        logic              msg_is_pme_to_ack;
        logic              msg_is_ltr;
    }xali_xadm_pkt_support_t;
    
    // XAIM/XADM Packet interface
    typedef struct packed{
        // XAIM/XADM Main interface signals
        logic                             hv;
        logic                             dv;
        logic                             eot;
        logic                             bad_eot;
        logic [ADM_PRFX_HDR_NW-1:0][31:0] prfx_hdr;
        logic [`CX_NW-1:0][31:0]     data;
        logic [ADM_PRFX_HDR_DATA_NO_INTEGRITY_PROT_WD-1:0]  tlp_prot;           
        logic                                               ras_dp_err_inband_kbd;
        logic [ADM_PRFX_NW-1:0]           prfx_dwen;
        logic [ADM_PRFX_HDR_NW-1:0]       hdr_dwen;
        logic [`CX_NW-1:0]                    data_dwen;
        logic [2:0]                       order_seqnum;
        tx_port_id_e                      origin_port;

        // IDE Signals

        // Signals calculated by XAIM and carried on into XADM
        xali_xadm_pkt_support_t           support;

        // Signals calculated internally by XADM to ease timing throughout pipelines
        logic [31:0]                      ecrc;
    } xadm_pkt_t;
    
    // XADM to XTLH Packet
    typedef struct packed{
        logic [ADM_PRFX_HDR_DATA_NW-1:0][31:0] data; // contains Prfx+Hdr+Data
        logic [ADM_PRFX_HDR_DATA_NW-1:0]       dwen;
        logic [ADM_PRFX_NW:0]                  soh; // Account for FM Local Prefix
        logic [ADM_PRFX_HDR_NW:0]              sod;  // Start of Data indication inside data bus
        logic                                  sot;
        logic                                  dv;
        logic                                  eot;
        logic                                  badeot;
        logic                                  pme_to_ack;  // Indicates that a PME_TO_Ack message is being sent
        logic [ADM_PRFX_HDR_DATA_PROT_WD-1:0]  tlp_prot;
        logic                                  ras_dp_err_inband_kbd;
        logic                                  ep;
        logic                                  dcrdt;
        logic [2:0]                            seqnum;
 
        logic                                  is_from_msg_gen;
        logic                                  is_from_lbc;
        logic                                  is_from_dma;
        logic                                  td;       
        // The TLP ending is a PTM TLP
        logic                                  ptm;
        logic [`CX_NVC_LOG2-1:0]                     vc;
    } xtlh_pkt_t;

    // XADM RASDES TLP Trace
    typedef struct packed{
        // Posted RAS DES Event Counter events
        logic [`N_XADM_P_IF-1:0]      xadm_tx_memwr_evt;
        logic [`N_XADM_P_IF-1:0]      xadm_tx_msg_evt;
        // Non-Posted RAS DES Event Counter events
        logic [`N_XADM_NP_IF-1:0]     xadm_tx_memrd_evt;
        logic [`N_XADM_NP_IF-1:0]     xadm_tx_defmemwr_evt;
        logic [`N_XADM_NP_IF-1:0]     xadm_tx_cfgwr_evt;
        logic [`N_XADM_NP_IF-1:0]     xadm_tx_cfgrd_evt;
        logic [`N_XADM_NP_IF-1:0]     xadm_tx_iowr_evt;
        logic [`N_XADM_NP_IF-1:0]     xadm_tx_iord_evt;
        logic [`N_XADM_NP_IF-1:0]     xadm_tx_atmcop_evt;
        // Completion RAS DES Event Counter events
        logic [`N_XADM_CPL_IF-1:0]    xadm_tx_cplwod_evt;
        logic [`N_XADM_CPL_IF-1:0]    xadm_tx_cplwd_evt;
        logic [`N_XADM_IF-1:0]        xadm_tx_tlpwprefix_evt;
        logic [`N_XADM_IF*11-1:0]     xadm_tx_tlp_dpsize;
        logic [`N_XADM_IF-1:0]        xadm_tx_null_evt;
    } xadm_rasdes_tlp_trace_t;
    
    // -----------------------------------------------------------------------------

//    `ifdef CX_INTERNAL_ATU_ENABLE
    // -----------------------------------------------------------------------------
    // ATU (Multistream) params and typedefs
    // -----------------------------------------------------------------------------

    typedef struct packed{
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0][4:0]                tlp_type;
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0][2:0]                tc;
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                     td;
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0][`FLT_Q_ATTR_WIDTH-1:0]        attr;
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0][1:0]                at;
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0][`CX_NFUNC_WD-1:0]          func_num;
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                     func_bypass;
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                     snp;
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                     dma_bypass;
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                     inhibit_pyld;
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                     hdr_substitute_en;
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                     tag_substitute_en;
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0][`CX_TAG_SIZE-1:0]       tag;
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0][7:0]                msg_code;
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                     th;
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0][1:0]                ph;
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0][7:0]                st;
        // Mode Settings
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                     shift;
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                     invert;
        // Region Enable
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                     en;
        // Base, Limit and Target Registers
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0][`CX_ATU_REGION_WIDTH-1:0]     base;
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0][`CX_ATU_BASE_WIDTH-1:0]    upr_base;
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0][`CX_ATU_REGION_WIDTH-1:0]     limit;
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0][`CX_ATU_MAX_REGION_SIZE-1:0] uppr_limit;
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0][`CX_ATU_REGION_WIDTH-1:0]     lwr_trgt;
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0][`CX_ATU_BASE_WIDTH-1:0]    upr_trgt;
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0][ATU_REG_LWR_WD-1:0] lwr_trgt_lwr;
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                     incr_rgn_size;   // Maximum region size control bit
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                     hdr_flds_bypass; // TLP Header fields bypass control bit
    } cdm_atu_out_cfg_t;

    typedef struct packed{
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0][31+`CX_ATU_MAX_REGION_SIZE:0]           offset;
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0][`CX_ATU_REGION_WIDTH-1:0]                offset_plus_lwr_trgt;
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0][`CX_ATU_MAX_REGION_SIZE+`CX_ATU_REGION_WIDTH-1:0] offset_plus_lwr_trgt_for_incr_rgn_size;
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                                match;
        logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0][15:0]                          rid_from_cfg;
    } atu_pkt_t;

    //------------------------------------------------------------------------------
//    `endif // CX_INTERNAL_ATU_ENABLE
    
    //------------------------------------------------------------------------------
    
    //----------------- Header Log Struct --------------------
    typedef struct packed {
      logic [32*`CX_MAX_HDR_LOG_SZ-1:0]       hdr_prfx          ;
      logic                                   valid_pf          ; // logs in case only physical function is active without an active virtual function
      logic [`CX_NFUNC_WD-1:0]                pf                ;
      logic                                    flit_mode         ;
      logic [$clog2(`CX_MAX_HDR_LOG_SZ+1)-1:0]hdr_size          ;
      logic [4:0]                              err_idx           ;
      logic                                    f_spec_err        ;
      fc_type_e                                fc                ;

  } radm_hdr_log_s   ;

    

    

     // CX_PL/CDM Flit logging capability interface
     typedef struct packed {
       logic  rplh_valid_flit;
       logic  rplh_flit_fec_uncorr_error;
       logic  rplh_flit_crc_uncorr_error;
       logic  rplh_flit_unrecognized_flit;
       logic  [2:0][7:0] rplh_flit_prot_synd_parity;
       logic  [2:0][7:0] rplh_flit_prot_synd_check;
       logic  rplh_flit_fec_corr_error;
       logic  [15:0][3:0] rplh_flit_fec_corr_even_bit_error;
       logic  [15:0][3:0] rplh_flit_fec_corr_odd_bit_error;
     } rplh_flit_logging_interface_struct;
     
     typedef struct packed {
       logic  [15:0] rmlh_mismatch_SKP_OS;
       logic  rmlh_framing_error;
     } rmlh_flit_logging_interface_struct;
     
     typedef struct packed {
       logic  smlh_invalid_ordered_set;
       logic  smlh_corr_ordered_set;
     } smlh_flit_logging_interface_struct;

     typedef enum logic [1:0] {
       IDLE,
       STARTED,
       DONE,
       ERROR
     } latency_tracking_status_e;
     
     typedef struct packed {
       latency_tracking_status_e       flit_latency_status;
       logic [15:0]                    flit_latency_value;
     } xplh_cdm_flit_latency_track_t;
     
     typedef struct packed {
       latency_tracking_status_e  state_trans1_status;
       latency_tracking_status_e  state_trans2_status;
       latency_tracking_status_e  state_trans3_status;
       latency_tracking_status_e  state_trans4_status;
       latency_tracking_status_e  state_trans5_status;
       logic [15:0]               state_trans_latency;
     } pm_cdm_state_trans_track_t;


     typedef enum logic [1:0] {
       FEC_CORR_OR_UNCORR          = 2'b00,
       FEC_CORR_ROTATE_1_GROUP     = 2'b01,
       FEC_CORR_3_GROUPS           = 2'b10,
       FEC_UNCORR                  = 2'b11
     } curr_inj_err_type_e;

     typedef enum logic [2:0] {
       ANY_TYPE                    = 3'b000,
       ANY_NON_IDLE                = 3'b001,
       PAYLOAD_ONLY                = 3'b010,
       NOP_ONLY                    = 3'b011,
       IDLE_ONLY                   = 3'b100,
       PAYLOAD_THEN_SAME_SEQ_NUM   = 3'b101,
       PAYLOAD_THEN_SEQ_NUM_PLUS_1 = 3'b110,
       RSV_111                     = 3'b111
     } flit_type_inj_e;

     typedef enum logic [1:0] {
       NOT_INJ_ANY_ERR_YET         = 2'b00,
       AT_LEAST_1_ERR_INJ          = 2'b01,
       ERR_INJ_DONE                = 2'b10,
       ERR_INJ_ERR_CASE            = 2'b11
     } inj_sts_e;

     typedef struct packed {
       logic         cfg_flit_err_inj_en               ;
       logic         cfg_inj_err_tx_flit_ind           ;
       logic         cfg_inj_err_rx_flit_ind           ;
       logic  [12:0] cfg_flit_err_inj_en_data_rate     ;
       logic  [7:0]  cfg_inj_err_spacing               ;
       logic  [2:0]  cfg_consec_err_inj                ;
       logic  [1:0]  cfg_curr_inj_err_type             ;
       logic  [6:0]  cfg_flit_err_off                  ;
       logic  [7:0]  cfg_err_mag                       ;
       logic  [4:0]  cfg_inj_err_num                   ;
       logic  [2:0]  cfg_flit_type_inj                 ;
       logic         cfg_err_inj_extnd_cap_en          ;
     } flit_err_inj_interface_struct;

     typedef struct packed {
       logic  [1:0]  cfg_tx_inj_sts                    ;
       logic  [1:0]  cfg_rx_inj_sts                    ;
     } flit_err_inj_status_struct;

     typedef struct packed {
       logic         cfg_ordr_set_err_inj_en           ;
       logic         cfg_inj_err_tx_ordr_set_ind       ;
       logic         cfg_inj_err_rx_ordr_set_ind       ;
       logic  [4:0]  cfg_ordr_set_inj_err_num          ;
       logic  [7:0]  cfg_ordr_set_inj_err_spacing      ;
       logic         cfg_inj_err_ts0_os                ;
       logic         cfg_inj_err_ts1_os                ;
       logic         cfg_inj_err_ts2_os                ;
       logic         cfg_inj_err_skp_os                ;
       logic         cfg_inj_err_eieos_os              ;
       logic         cfg_inj_err_eios_os               ;
       logic         cfg_inj_err_sds_os                ;
       logic         cfg_inj_err_poll_st               ;
       logic         cfg_inj_err_cfg_st                ;
       logic         cfg_inj_err_l0_st                 ;
       logic         cfg_inj_err_non_eq_recov_st       ;
       logic         cfg_inj_err_recov_eq_ph_1_0       ;
       logic         cfg_inj_err_recov_eq_ph_2         ;
       logic         cfg_inj_err_recov_eq_ph_3         ;
       logic  [15:0] cfg_err_inj_bytes                 ;
       logic  [15:0] cfg_err_inj_lane_num              ;
       logic         cfg_err_inj_extnd_cap_en          ;
     } os_err_inj_interface_struct;

     typedef struct packed {
       logic  [1:0]   cfg_ordr_set_inj_sts_ts0                     ;
       logic  [1:0]   cfg_ordr_set_inj_sts_ts1                     ;
       logic  [1:0]   cfg_ordr_set_inj_sts_ts2                     ;
       logic  [1:0]   cfg_ordr_set_inj_sts_skp                     ;
       logic  [1:0]   cfg_ordr_set_inj_sts_eieos                   ;
       logic  [1:0]   cfg_ordr_set_inj_sts_eios                    ;
       logic  [1:0]   cfg_ordr_set_inj_sts_sds                     ;
       logic  [1:0]   cfg_ordr_set_inj_sts_poll                    ;
       logic  [1:0]   cfg_ordr_set_inj_sts_cfg                     ;
       logic  [1:0]   cfg_ordr_set_inj_sts_l0                      ;
       logic  [1:0]   cfg_ordr_set_inj_sts_non_eq_recov            ;
       logic  [1:0]   cfg_ordr_set_inj_sts_recov_eq_ph_1_0         ;
       logic  [1:0]   cfg_ordr_set_inj_sts_recov_eq_ph_2           ;
       logic  [1:0]   cfg_ordr_set_inj_sts_recov_eq_ph_3           ;
     } os_err_inj_status_struct;

     // PCIe6 Spec 7.8.13.6 Ordered Set Error Injection Control 1 Register
     typedef struct packed {
       logic       os_error_injection_en;
       logic       tx_os_error_injection_en;
       logic       rx_os_error_injection_en;
       logic [4:0] number_of_errors_injected;
       logic [7:0] spacing_between_errors;
       logic       inject_error_on_ts0;
       logic       inject_error_on_ts1;
       logic       inject_error_on_ts2;
       logic       inject_error_on_skp;
       logic       inject_error_on_eie;
       logic       inject_error_on_eid;
       logic       inject_error_on_sds;
       logic       inject_error_in_polling;
       logic       inject_error_in_cfg;
       logic       inject_error_in_l0;
       logic       inject_error_in_rvcry_noneq;
       logic       inject_error_in_rcvry_eq_ph_0_1;
       logic       inject_error_in_rcvry_eq_ph_2;
       logic       inject_error_in_rcvry_eq_ph_3;
     } cfg_os_einj_ctrl_1_t;

     // PCIe6 Spec 7.8.13.7 Ordered Set Error Injection Control 2 Register
     typedef struct packed {
       logic [15:0] error_injection_bytes;
       logic [15:0] error_injection_lanes;
     } cfg_os_einj_ctrl_2_t;

     // PCIe6 Spec 7.8.13.8 Ordered Set Error Tx Injection Status Register
     // PCIe6 Spec 7.8.13.9 Ordered Set Error Rx Injection Status Register
     typedef struct packed {
       logic [1:0] ts0;
       logic [1:0] ts1;
       logic [1:0] ts2;
       logic [1:0] skp;
       logic [1:0] eie;
       logic [1:0] eid;
       logic [1:0] sds;
       logic [1:0] polling;
       logic [1:0] cfg;
       logic [1:0] l0;
       logic [1:0] rvcry_noneq;
       logic [1:0] rcvry_eq_ph_0_1;
       logic [1:0] rcvry_eq_ph_2;
       logic [1:0] rcvry_eq_ph_3;
     } cfg_os_einj_status_t;
     
     // xmlh_byte_xmt uses this struct to tell xmlh_os_einj which OS is correspondingly present in xmtbyte_txdata
     typedef struct packed {
       logic in_ts0;
       logic in_ts1;
       logic in_ts2;
       logic in_skp;
       logic in_eie;
       logic in_eid;
       logic in_sds;
     } xmlh_einj_in_os_t;

  // rtlh-radm interface. This struct contains the rtlh-radm interface for Multistream, ARC_512 and non-ARC_512 Architectures
  typedef struct packed {
      logic     [RX_NQDW-1:0]                           valid;                // Valid qDW
      logic     [RX_NQDW-1:0]                           sot;                  // TLP starting on this qDW
      logic     [RX_NQDW-1:0]                           eot;                  // TLP ending on this qDW
      logic     [RX_NQDW-1:0][3:0]                      dwen;                 // DWord enabled
      logic     [RX_NQDW-1:0][127:0]                    data;                 // Data payload (i.e. TLP prefix, header and data)
      logic     [RX_NQDW-1:0][QDW_PROT_WD-1:0]          data_prot;            // TLP protection bits
      struct packed {
          logic                                         valid;                // The current qDW contains the 1st DW Header
          logic [2:0]                                   vc;                   // VC specified in the Header
          fc_type_e                                     fc;                   // TLP type
      }         [RX_NQDW-1:0]                           hdr;
      logic     [RX_NQDW-1:0]                           dllp_err;
      logic                                             fm_nullified;         // The last TLP ending was Nullified by the Flit Marker
      logic                                             fm_poisoned;          // The last TLP ending was Poisoned by the Flit Marker
      logic                                             pending;              // Transaction Layer has a TLP pending, this signal is only valid on the clock-cycle before 
                                                                              // rtlh provides a TLP to radm. This signal is used to make sure the radm is ready to accept
                                                                              // TLPs
  } rtlh_radm_datapath_t;

  // rtlh-radm interface. This struct contains the rtlh-radm interface for Multistream, ARC_512 and non-ARC_512 Architectures
  typedef struct packed {
    logic  [RX_NQDW-1:0][2:0]     fmt;
    logic  [RX_NQDW-1:0][4:0]     tlp_type;
    logic  [RX_NQDW-1:0][31:0]    header_dw1;
    logic  [RX_NQDW-1:0][1:0]     fc;
    logic  [RX_NQDW-1:0][2:0]     vc;
    logic  [RX_NQDW-1:0]          valid;
    logic  [RX_NQDW-1:0]          dllp_err;
    logic  [RX_NQDW-1:0]          nullified;
    logic  [RX_NQDW-1:0]          eot;
  } radm_tb_tlp_ordering_t;


`ifndef SYNTHESIS
`endif

localparam LBC_MSG_HDR_WD   = `ST_HDR
                               + `CX_RAS_PCIE_EXTENDED_HDR_PROT_WD
                              ;


  localparam ADDR_PAR_CALC_WIDTH_NO_ZERO = (`ADDR_BUS_PAR_CALC_WIDTH==0) ? 1 : `ADDR_BUS_PAR_CALC_WIDTH;
  localparam CORE_ADDR_PAR_WD   = (`ADDR_BUS_PAR_CALC_WIDTH==0) ? 0 : (`FLT_Q_ADDR_WIDTH / ADDR_PAR_CALC_WIDTH_NO_ZERO); // the width of the parity bits on the address bus
 

localparam TX_FS_WD         = 6;
localparam TX_COEF_WD       = 3*TX_FS_WD;

function automatic violate_rules_tx_coef (input [TX_COEF_WD-1:0] coef, input [TX_FS_WD-1:0] fs, input [TX_FS_WD-1:0] lf);

//pre_cursor, cursor and post_cursor range is from 0 to 63

    reg [TX_FS_WD-1:0] pre_cursor;
    reg [TX_FS_WD-1:0] cursor;
    reg [TX_FS_WD-1:0] post_cursor;
    reg [TX_FS_WD+1:0] sum_3_cursors;
    reg [TX_FS_WD:0]   sum_pre_post_cursors;
    reg       violate_rule_1; // |C-1| <= Floor (FS/4)
    reg       violate_rule_2; // |C-1|+C0+|C+1| = FS
    reg       violate_rule_3; // C0 -|C-1|-|C+1| >= LF
    reg [TX_FS_WD-1:0] tmp_cursor;

    begin
        violate_rules_tx_coef = 1;

        pre_cursor           = coef[TX_FS_WD-1:0];
        cursor               = coef[2*TX_FS_WD-1:TX_FS_WD];
        post_cursor          = coef[TX_COEF_WD-1:2*TX_FS_WD];
        sum_3_cursors        = ({2'b00,pre_cursor} + {2'b00,cursor} + {2'b00,post_cursor});
        sum_pre_post_cursors = ({1'b0,pre_cursor} + {1'b0,post_cursor});

        violate_rule_1 = ( pre_cursor > (fs >> 2) );
        violate_rule_2 = ( sum_3_cursors != {2'b00,fs} );
        //if cursor < (pre_pre_cursor + post_cursor), violate_rule_3 is true
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
        tmp_cursor = (cursor - pre_cursor - post_cursor); // to avoid spyglass warning
// spyglass enable_block W164a
        violate_rule_3 = ( ({1'b0,cursor} < sum_pre_post_cursors) ? 1 : (tmp_cursor < lf) );

        violate_rules_tx_coef = ( violate_rule_1 || violate_rule_2 || violate_rule_3 );
    end
endfunction //violate_rules_tx_coef

// Rules for local transmitter coefficients at gen6 rate.
// If violate any of the three Rules, violate_rules_tx_coef_g6 = 1
function automatic violate_rules_tx_coef_g6 (input [TX_COEF_WD-1:0] coef, input [TX_FS_WD-1:0] fs, input [TX_FS_WD-1:0] lf);

//2nd pre_cursor, pre_cursor, cursor and post_cursor range is from 0 to 63

    reg [2:0] pre_cursor_2;
    reg [3:0] pre_cursor;
    reg [5:0] cursor;
    reg [4:0] post_cursor;
    reg [TX_FS_WD+1:0] sum_4_cursors;
    reg [TX_FS_WD:0]   sum_pre_post_cursors;
    reg [TX_FS_WD:0]   sum_crsr_pre_2_cursors; // C0 + |C-2|
    reg       violate_rule_1; // |C-1| <= Floor (FS/4)
    reg       violate_rule_2; // |C-2| + |C-1| + C0 + |C+1| = FS
    reg       violate_rule_3; // C0 + |C-2| - |C-1| - |C+1| >= LF
    reg       violate_rule_4; // |C-2| <= Floor (FS/8)
    reg [TX_FS_WD-1:0] tmp_cursor;
    reg [TX_FS_WD-1:0] fs_div_3;

    begin
        violate_rules_tx_coef_g6 = 1;

        pre_cursor_2         = coef[2:0];
        pre_cursor           = coef[6:3];
        cursor               = coef[12:7];
        post_cursor          = coef[17:13];
        fs_div_3             = {1'b0, fs_d3(fs)};

        sum_4_cursors          = ({5'b0,pre_cursor_2} + {4'b0,pre_cursor} + {2'b0,cursor} + {3'b0,post_cursor});
        sum_pre_post_cursors   = ({3'b0,pre_cursor} + {2'b0,post_cursor});
        sum_crsr_pre_2_cursors = ({1'b0,cursor} + {4'b0,pre_cursor_2});

        violate_rule_1 = ( {2'b0, pre_cursor} > (fs >> 2) );
        violate_rule_2 = ( sum_4_cursors != {2'b00,fs} );
        //if pre_cursor_2 + cursor < (pre_cursor + post_cursor), violate_rule_3 is true
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, 
        tmp_cursor = (pre_cursor_2 + cursor - pre_cursor - post_cursor); // to avoid spyglass warning
// spyglass enable_block W164a
        violate_rule_3 = ( (sum_crsr_pre_2_cursors < sum_pre_post_cursors) ? 1 : (tmp_cursor < lf) );
        violate_rule_4 = ( {3'b0, pre_cursor_2} > (fs >> 3) );

        violate_rules_tx_coef_g6 = ( violate_rule_1 | violate_rule_2 | violate_rule_3 | violate_rule_4 );
    end
endfunction //violate_rules_tx_coef_g6

//don't use operator "/" as it has more complex logic as well as Leda errors
function automatic [4:0] fs_d3 (input [5:0] fs); // 11 < FS <= 63 according to PCIe Base Spec
    begin
        fs_d3 = 0;
        case ( fs )

            //note: fs_d3 = ceiling (fs/3)
            10,11,12: fs_d3 = 4;
            13,14,15: fs_d3 = 5;
            16,17,18: fs_d3 = 6;
            19,20,21: fs_d3 = 7;
            22,23,24: fs_d3 = 8;
            25,26,27: fs_d3 = 9;
            28,29,30: fs_d3 = 10;
            31,32,33: fs_d3 = 11;
            34,35,36: fs_d3 = 12;
            37,38,39: fs_d3 = 13;
            40,41,42: fs_d3 = 14;
            43,44,45: fs_d3 = 15;
            46,47,48: fs_d3 = 16;
            49,50,51: fs_d3 = 17;
            52,53,54: fs_d3 = 18;
            55,56,57: fs_d3 = 19;
            58,59,60: fs_d3 = 20;
            61,62,63: fs_d3 = 21;
            default : fs_d3 = 0;
        endcase //case ( fs )
    end
endfunction //function [4:0] fs_d3


localparam CFG_CXL_PORT_ENABLE_WD = 22; // Width of internal signal cfg_cxl_port_enable

localparam OS_MON_NONE    = 6'd0;
localparam OS_MON_EIEOS   = 6'd1;
localparam OS_MON_EIOS    = 6'd2;
localparam OS_MON_SKP     = 6'd3;
localparam OS_MON_CTL_SKP = 6'd4;
localparam OS_MON_FTS     = 6'd5;
localparam OS_MON_CP      = 6'd6;
localparam OS_MON_ICP     = 6'd7;    // 8b10b Inverted Compliance pattern(only RX)
localparam OS_MON_MCP     = 6'd8;
localparam OS_MON_IMCP    = 6'd9;   // 8b10b Inverted Modified Compliance pattern(only RX)
localparam OS_MON_SDS     = 6'd10;
// Reverved 11-15
localparam OS_MON_TS1     = 6'd16;
localparam OS_MON_TS1I    = 6'd17;   // 8b10b Inverted TS1(only RX)
localparam OS_MON_TS1Q    = 6'd18;
localparam OS_MON_TS1R    = 6'd19;   // 128b130b or 1b1b TS1 with patiry error(only RX)
localparam OS_MON_TS1M    = 6'd20;   // 8b10b Modified TS1
localparam OS_MON_TS1MR   = 6'd21;   // 8b10b Modified TS1 with parity error
// Reserved 22-23
localparam OS_MON_TS2     = 6'd24;   // 
localparam OS_MON_TS2I    = 6'd25;  // 8b10b Inverted TS2
localparam OS_MON_TS2Q    = 6'd26;
localparam OS_MON_TS2M    = 6'd27;
localparam OS_MON_TS2MR   = 6'd28;  // 8b10b Modified TS2 with parity error(only RX)
localparam OS_MON_TS0     = 6'd29;
// Reserved 30-63

endpackage // DWC_pcie_core_pkg

`endif // __GUARD__DWC_PCIE_CORE_PKG__SVH__

