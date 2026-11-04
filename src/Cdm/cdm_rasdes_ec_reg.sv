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
// ---    $Revision: #12 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_rasdes_ec_reg.sv#12 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains RAS D.E.S Event Counter registers.
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

 
 module cdm_rasdes_ec_reg 
   import DWC_pcie_ctl_pkg::N_XADM_IF;
   import DWC_pcie_ctl_pkg::N_XADM_P_IF;
   import DWC_pcie_ctl_pkg::N_XADM_NP_IF;
   import DWC_pcie_ctl_pkg::N_XADM_CPL_IF;
   import DWC_pcie_ctl_pkg::N_CCIX_IF;
   import DWC_pcie_ctl_pkg::ERROR_TLP_WD;
#(
  parameter INST                  = 0,                              // The uniquifying parameter for each port logic instance.
  parameter TP                    = `TP,                            // Clock to Q delay (simulator insurance)
  parameter NW                    = `CX_NW,                         // Number of 32-bit dwords handled by the datapath each clock.
  parameter NL                    = `CX_NL,                         // Number of Lanes Supported
  parameter RX_TLP                = `CX_RX_TLP,                     // Number of TLPs that can be processed in a single cycle
  parameter FX_TLP                = `CX_FX_TLP,                     // Number of TLPs that can be processed in a single cycle after the formation block
  parameter RX_NDLLP              = `CX_RX_NDLLP,                   // Max number of DLLPs received per cycle
  parameter NUM_EOT               = `CX_NUM_EOT,                    // Max number of END/EDB per cycle
  parameter TX_NDLLP              = `CX_TX_NDLLP,                   // Max number of DLLPs send per cycle
  parameter RASDES_RAM_DATA_WIDTH = `CX_RAS_DES_EC_RAM_DATA_WIDTH,  // RAM data width
  parameter RASDES_RAM_ADDR_WIDTH = `CX_RAS_DES_EC_RAM_ADDR_WIDTH   // RAM address data width
)
                            (
// -------------- Inputs ---------------
  input                                   aux_clk,                             // Clock
  input                                   sticky_rst_n,                        // Reset sticky registers only
  // --- Register access signals
  input       [31:0]                      cdm_reg_wdata,                       // Write Data
  input       [3:0]                       cdm_reg_write_pulse,                 // Write Byte Enables
  input       [63:0]                      cdm_reg_id,                          // Register access ID
  // --- Event counter signals
  input       [NL-1:0]                    rmlh_ebuf_rxoverflow,                // Pulse : Rx elastic buffer overflow error status if the corresponding lane detected a lane-based error
  input       [NL-1:0]                    rmlh_ebuf_rxunderflow,               // Pulse : Rx elastic buffer underflow error status if the corresponding lane detected a lane-based error
  input       [NL-1:0]                    rmlh_phy_rxcodeerror,                // Pulse : Rx symbol error status if the corresponding lane detected a lane-based error
  input       [NL-1:0]                    rmlh_phy_rxdisperror,                // Pulse : Rx running disparity error if the corresponding lane detected a lane-based error
  input       [NL-1:0]                    rmlh_skp_parity_err,                 // Pulse : Rx skip ordered set parity error
  input       [NL-1:0]                    rmlh_sync_header_err,                // Pulse : Rx sync header undefined error
  input       [NL-1:0]                    rmlh_rxvalid_deasserted,             // Pulse : Rx burst de-assertion
  input       [NL*5-1:0]                  rmlh_deskew_ctlskp_err,              // Pulse : CS-SKP-OS error [0]data parity[1]1st retimer[2]2nd retimer[3]margin crc[4]margin parity
  input                                   rmlh_rcvd_err,                       // Pulse : Rx receiver Error
  input                                   rmlh_framing_err,                    // Pulse : Rx framing error in gen3 rate
  input                                   rmlh_framing_err_l0,                 // Pulse : Rx framing error in gen3 rate when L0 state
  input                                   rmlh_deskew_alignment_err,           // Level : Rx deskew alignment error
  input       [NL-1:0]                    rmlh_rxskipadded,                    // Pulse : Rx skip added in elastic buffer
  input       [NL-1:0]                    rmlh_rxskipremoved,                  // Pulse : Rx skip removed in elastic buffer
  input       [ERROR_TLP_WD:0]            cfg_poisned_tlp,                     // Pulse : Poisoned TLP Event for Ras D.E.S event counter
  input       [ERROR_TLP_WD:0]            cfg_ecrc_tlp_err,                    // Pulse : ECRC Error TLP Event for Ras D.E.S event counter
  input       [ERROR_TLP_WD:0]            cfg_ur_tlp,                          // Pulse : UR Error TLP Event for Ras D.E.S event counter
  input       [ERROR_TLP_WD:0]            cfg_ca_tlp,                          // Pulse : Completer Abort TLP Event for Ras D.E.S event counter
  input       [1:0]                       cfg_cpl_timeout,                     // Pulse : Completion Timeout Event for Ras D.E.S event counter
  input                                   smlh_eidle_inferred_in_l0,           // Level: Detect EI Infer for Ras D.E.S event counter
  input                                   smlh_rx_rcvry_req,                   // Level: Rx Recovery Request for Ras D.E.S event counter
  input                                   smlh_timeout_nfts,                   // Level: N_FTS Timeout for Ras D.E.S event counter
  input                                   smlh_l0_to_recovery,                 // Pulse : L0 to Recovery for Ras D.E.S event counter
  input                                   smlh_l1_to_recovery,                 // Pulse : L1 to Recovery for Ras D.E.S event counter
  input                                   smlh_in_l0s,                         // Level: Tx L0s Entry for Ras D.E.S event counter
  input                                   smlh_in_rl0s,                        // Level: Rx L0s Entry for Ras D.E.S event counter
  input                                   smlh_rcv_eios_when_l0s_unsprt,       // pulse: Received EIOS when L0s is not supported and not directed L1 or L2
  input                                   smlh_deskew_uncomplete_err,          // Pulse: Deskew uncompleted error for Ras D.E.S event counter
  input                                   cxl_almp_rx_repl_error,              // Pulse: (CXL only) ALMP Replication error
  input                                   cxl_vlsm_unexp_error,                // Pulse: (CXL only) unexpected ALMP error
  input                                   cxl_vlsm_lrsm_req_retrain,           // Pulse: (CXL only) NUM_RETRY reached MAX_NUM_RETRY
  input                                   pm_asnak,                            // Level: ASPM L1 reject for Ras D.E.S event counter
  input                                   smlh_in_l1,                          // Level: L1 Entry for Ras D.E.S event counter
  input                                   pm_in_l11,                           // Level: L1.1 Entry for Ras D.E.S event counter
  input                                   pm_in_l12,                           // Level: L1.2 Entry for Ras D.E.S event counter
  input                                   pm_in_l1_short,                      // Level: L1 short duration for Ras D.E.S event counter
  input                                   pm_in_l1_cpm,                        // Level: L1 Clock PM (L1 with REFCLK removal/PLL Off) for Ras D.E.S event counter
  input                                   pm_in_l1_abort,                      // Level: L1.2 abort for Ras D.E.S event counter
  input                                   smlh_in_l23,                         // Level: L2 Entry for Ras D.E.S event counter
  input                                   smlh_spd_change,                     // Level: Speed Change for Ras D.E.S event counter
  input                                   smlh_lwd_change,                     // Level: Link Width Change for Ras D.E.S event counter
  input       [RX_TLP-1:0]                rdlh_bad_tlp_err_pertlp,             // Pulse : Rx Bad TLP Event per TLP for Ras D.E.S event counter
  input       [RX_TLP-1:0]                rdlh_lcrc_tlp_err_pertlp,            // Pulse : Rx LCRC Error TLP Event per TLP for Ras D.E.S event counter
  input       [RX_TLP-1:0]                rdlh_nulified_tlp_err_pertlp,        // Pulse : Rx Nullified TLP Event per TLP for Ras D.E.S event counter
  input       [RX_TLP-1:0]                rdlh_duplicate_tlp_err_pertlp,       // Pulse : Rx Duplicate TLP Event per TLP for Ras D.E.S event counter
  input       [RX_NDLLP-1:0]              rdlh_bad_dllp_err_perdllp,           // Pulse : Rx Bad DLLP Event per DLLP for Ras D.E.S event counter
  input       [RX_NDLLP-1:0]              rdlh_rcvd_nack_perdllp,              // Pulse : Rx Nak DLLP Event per DLLP for Ras D.E.S event counter
  input       [RX_NDLLP-1:0]              rdlh_rcvd_ack_perdllp,               // Pulse : Rx Ack DLLP Event per DLLP for Ras D.E.S event counter
  input                                   xdlh_replay_num_rlover_err,          // Pulse : Replay_Num Rollover Eventfor Ras D.E.S event counter
  input                                   xdlh_replay_timeout_err,             // Pulse : Replay Timeout for Ras D.E.S event counter
  input                                   xdlh_retry_req,                      // Pulse : Retry TLP Event for Ras D.E.S event counter
  input                                   xdlh_nak_sent,                       // Pulse : Tx Nak DLLP Event per TLP for Ras D.E.S event counter
  input                                   xdlh_ack_sent,                       // Pulse : Tx Ack DLLP Event per TLP for Ras D.E.S event counter
  input       [TX_NDLLP-1:0]              xdlh_update_fc_sent,                 // Pulse : Tx Update-FC DLLP Event per TLP for Ras D.E.S event counter
  input       [N_XADM_IF-1:0]             xadm_tx_nullify_evt,                 // Pulse : Tx Nullified TLP Event for Ras D.E.S event counter
  input                                   rtlh_req_link_retrain,               // Pulse : FC Timeout Event per TLP for Ras D.E.S event counter
  input       [RX_NDLLP-1:0]              rtlh_rcvd_ufc_perdllp,               // Pulse : Rx Update-FC DLLP Event per TLP for Ras D.E.S event counter
  input       [RX_TLP-1:0]                rtlh_rx_memwr_evt,                   // Pulse : Rx Memory Write TLP for Ras D.E.S event counter
  input       [RX_TLP-1:0]                rtlh_rx_defmemwr_evt,                // Pulse : Rx Deferrable Memory Write TLP for Ras D.E.S event counter
  input       [RX_TLP-1:0]                rtlh_rx_memrd_evt,                   // Pulse : Rx Memory Read TLP for Ras D.E.S event counter
  input       [RX_TLP-1:0]                rtlh_rx_cfgwr_evt,                   // Pulse : Rx Config Write TLP for Ras D.E.S event counter
  input       [RX_TLP-1:0]                rtlh_rx_cfgrd_evt,                   // Pulse : Rx Config Read TLP for Ras D.E.S event counter
  input       [RX_TLP-1:0]                rtlh_rx_iowr_evt,                    // Pulse : Rx I/O Write TLP for Ras D.E.S event counter
  input       [RX_TLP-1:0]                rtlh_rx_iord_evt,                    // Pulse : Rx I/O Read TLP for Ras D.E.S event counter
  input       [RX_TLP-1:0]                rtlh_rx_cplwod_evt,                  // Pulse : Rx Completion without Data TLP for Ras D.E.S event counter
  input       [RX_TLP-1:0]                rtlh_rx_cplwd_evt,                   // Pulse : Rx Completion with Data TLP for Ras D.E.S event counter
  input       [RX_TLP-1:0]                rtlh_rx_msg_evt,                     // Pulse : Rx Message TLP for Ras D.E.S event counter
  input       [RX_TLP-1:0]                rtlh_rx_atmcop_evt,                  // Pulse : Rx AtomicOp TLP for Ras D.E.S event counter
  input       [RX_TLP-1:0]                rtlh_rx_tlpwprefix_evt,              // Pulse : Rx TLP with Prefix for Ras D.E.S event counter  
  input       [N_XADM_P_IF-1:0]           xtlh_tx_memwr_evt,                   // Pulse : Tx Memory Write TLP Event for Ras D.E.S event counter
  input       [N_XADM_NP_IF-1:0]         xtlh_tx_defmemwr_evt,                // Pulse : Tx Deferrable Memory Write TLP Event for Ras D.E.S event counter
  input       [N_XADM_NP_IF-1:0]         xtlh_tx_memrd_evt,                   // Pulse : Tx Memory Read TLP Event TLP for Ras D.E.S event counter
  input       [N_XADM_NP_IF-1:0]         xtlh_tx_cfgwr_evt,                   // Pulse : Tx Config Write TLP for Ras D.E.S event counter
  input       [N_XADM_NP_IF-1:0]         xtlh_tx_cfgrd_evt,                   // Pulse : Tx Config Read TLP for Ras D.E.S event counter
  input       [N_XADM_NP_IF-1:0]         xtlh_tx_iowr_evt,                    // Pulse : Tx I/O Write TLP for Ras D.E.S event counter
  input       [N_XADM_NP_IF-1:0]         xtlh_tx_iord_evt,                    // Pulse : Tx I/O Read TLP for Ras D.E.S event counter
  input       [N_XADM_CPL_IF-1:0]        xtlh_tx_cplwod_evt,                  // Pulse : Tx Completion with data TLP for Ras D.E.S event counter
  input       [N_XADM_CPL_IF-1:0]        xtlh_tx_cplwd_evt,                   // Pulse : Tx Completion without data TLP for Ras D.E.S event counter
  input       [N_XADM_P_IF-1:0]           xtlh_tx_msg_evt,                     // Pulse : Tx Message TLP for Ras D.E.S event counter
  input       [N_XADM_NP_IF-1:0]         xtlh_tx_atmcop_evt,                  // Pulse : Tx AtomicOP TLP for Ras D.E.S event counter
  input       [N_XADM_IF-1:0]            xtlh_tx_tlpwprefix_evt,              // Pulse : Tx TLP with Prefix for Ras D.E.S event counter
  //---- RAM I/F -----------------------
  input       [RASDES_RAM_DATA_WIDTH-1:0] ec_ram_dataout,
// -------------- Outputs ---------------
  //---- RAM I/F -----------------------
  output                                  ec_ram_ena,
  output                                  ec_ram_wea,
  output      [RASDES_RAM_ADDR_WIDTH-1:0] ec_ram_addra,
  output      [RASDES_RAM_DATA_WIDTH-1:0] ec_ram_datain,
  output                                  ec_ram_enb,
  output      [RASDES_RAM_ADDR_WIDTH-1:0] ec_ram_addrb,
  // --- Register access signals
  output  reg [1:0]                       cdm_ec_ack,                          // Register Response Status
  output  reg [31:0]                      cdm_ec_rdata                         // Register Read Data
);

//--------------------------------------------------------
//  General parameters
//--------------------------------------------------------
  localparam  [0:0] NEXT_PHASE_ENABLED    = 1'b0;
  localparam  [0:0] GEN2_ENABLED          =                1'b1;
  localparam  [0:0] GEN3_ENABLED          =                1'b1;
  localparam  [0:0] GEN4_ENABLED          =                1'b1;
  localparam  [0:0] L1_SS_ENABLED         = 1'b1 ;
  localparam  [0:0] MPCIE_ENABLED         = 1'b0 ;
  localparam  [0:0] CCIX_INTERFACE_ENABLE = 1'b0;
  localparam  [0:0] DEF_MEM_WR_ENABLE     =         1'b1;
  localparam  [0:0] EC_RAM_ENABLED        =     1'b1;
  localparam  [0:0] CXL_ENABLED           =                1'b1;

  localparam        RASDES_RAM_DEPTH    = `CX_RAS_DES_EC_RAM_DEPTH;

  localparam  [2:0] EN_PER_OFF          = 3'b001;
  localparam  [2:0] EN_PER_ON           = 3'b011;
  localparam  [2:0] EN_ALL_OFF          = 3'b101;
  localparam  [2:0] EN_ALL_ON           = 3'b111;
  localparam  [1:0] CLR_PER             = 2'b01;
  localparam  [1:0] CLR_ALL             = 2'b11;
  localparam        EVENT_TYPE_PULSE    = 1'b0; // Count-up the cycles of event_signal==1
  localparam        EVENT_TYPE_LEVEL    = 1'b1; // Count-up the cycles of posedge

//--------------------------------------------------------
//  Parameters for event counter
//--------------------------------------------------------
  localparam        EC_TOTAL_GROUP_NUM  = 9 ;
  
  localparam        G0_EC_CNT_WIDTH     = `CX_RAS_DES_EC_G0_BW;
  localparam        G1_EC_CNT_WIDTH     = `CX_RAS_DES_EC_G1_BW;
  localparam        G2_EC_CNT_WIDTH     = `CX_RAS_DES_EC_G2_BW;
  localparam        G3_EC_CNT_WIDTH     = `CX_RAS_DES_EC_G3_BW;
  localparam        G4_EC_CNT_WIDTH     = `CX_RAS_DES_EC_G4_BW;
  localparam        G5_EC_CNT_WIDTH     = `CX_RAS_DES_EC_G5_BW;
  localparam        G6_EC_CNT_WIDTH     = `CX_RAS_DES_EC_G6_BW;
  localparam        G7_EC_CNT_WIDTH     = `CX_RAS_DES_EC_G7_BW;
  localparam        G8_EC_CNT_WIDTH     = `CX_RAS_DES_EC_G8_BW;

  localparam        G0_EVENT_NUM        = 11;
  localparam        G1_EVENT_NUM        = 14;
  localparam        G2_EVENT_NUM        = 8;
  localparam        G3_EVENT_NUM        = 6;
  localparam        G4_EVENT_NUM        = 2;
  localparam        G5_EVENT_NUM        = 14;
  localparam        G6_EVENT_NUM        = 7;
  localparam        G7_EVENT_NUM        = 26;
  localparam        G8_EVENT_NUM        = 3;

  localparam        G0_TOTAL_EVENT_NUM  = NL * G0_EVENT_NUM;
  localparam        G1_TOTAL_EVENT_NUM  =      G1_EVENT_NUM;
  localparam        G2_TOTAL_EVENT_NUM  =      G2_EVENT_NUM;
  localparam        G3_TOTAL_EVENT_NUM  =      G3_EVENT_NUM;
  localparam        G4_TOTAL_EVENT_NUM  = NL * G4_EVENT_NUM;
  localparam        G5_TOTAL_EVENT_NUM  =      G5_EVENT_NUM;
  localparam        G6_TOTAL_EVENT_NUM  =      G6_EVENT_NUM;
  localparam        G7_TOTAL_EVENT_NUM  =      G7_EVENT_NUM;
  localparam        G8_TOTAL_EVENT_NUM  =      G8_EVENT_NUM;

  localparam        TOTAL_EVENT_NUM     = G0_TOTAL_EVENT_NUM + G1_TOTAL_EVENT_NUM
                                        + G2_TOTAL_EVENT_NUM + G3_TOTAL_EVENT_NUM
                                        + G4_TOTAL_EVENT_NUM + G5_TOTAL_EVENT_NUM
                                        + G6_TOTAL_EVENT_NUM + G7_TOTAL_EVENT_NUM
                                        + G8_TOTAL_EVENT_NUM;

  localparam        G0_START_INDEX      = 0;
  localparam        G1_START_INDEX      = G0_START_INDEX + G0_TOTAL_EVENT_NUM;
  localparam        G2_START_INDEX      = G1_START_INDEX + G1_TOTAL_EVENT_NUM;
  localparam        G3_START_INDEX      = G2_START_INDEX + G2_TOTAL_EVENT_NUM;
  localparam        G4_START_INDEX      = G3_START_INDEX + G3_TOTAL_EVENT_NUM;
  localparam        G5_START_INDEX      = G4_START_INDEX + G4_TOTAL_EVENT_NUM;
  localparam        G6_START_INDEX      = G5_START_INDEX + G5_TOTAL_EVENT_NUM;
  localparam        G7_START_INDEX      = G6_START_INDEX + G6_TOTAL_EVENT_NUM;
  localparam        G8_START_INDEX      = G7_START_INDEX + G7_TOTAL_EVENT_NUM;

  localparam        G0_EVENT_EXISTENCE_PADDING_LEN = 256 - G0_TOTAL_EVENT_NUM;
  localparam        G0_EVENT_EXISTENCE  = {{G0_EVENT_EXISTENCE_PADDING_LEN{1'b0}}, {NL{ // NL
    GEN4_ENABLED,   // |rmlh_deskew_ctlskp_err[4:3]
    GEN4_ENABLED,   // rmlh_deskew_ctlskp_err[2]
    GEN4_ENABLED,   // rmlh_deskew_ctlskp_err[1]
    GEN4_ENABLED,   // rmlh_deskew_ctlskp_err[0]
    1'b1,           // rmlh_rxvalid_deasserted
    GEN3_ENABLED,   // rmlh_sync_header_err
    GEN3_ENABLED,   // rmlh_skp_parity_err
    1'b1,           // rmlh_phy_rxdisperror
    1'b1,           // rmlh_phy_rxcodeerror
    1'b1,           // rmlh_ebuf_rxunderflow
    1'b1            // rmlh_ebuf_rxoverflow
  }}};
  
  localparam        G1_EVENT_EXISTENCE_PADDING_LEN = 256 - G1_TOTAL_EVENT_NUM;
  localparam        G1_EVENT_EXISTENCE  = {{G1_EVENT_EXISTENCE_PADDING_LEN{1'b0}}, {
    1'b1,                                                 // smlh_deskew_uncomplete_err
    GEN3_ENABLED,                                         // rmlh_framing_err_l0
    1'b1,                                                 // smlh_rcv_eios_when_l0s_unsprt
    1'b1,                                                 // rmlh_deskew_alignment_err
    GEN3_ENABLED,                                         // rmlh_framing_err
    1'b1,                                                 // smlh_timeout_nfts
    1'b1,                                                 // smlh_rx_rcvry_req
    1'b1,                                                 // rmlh_rcvd_err
    1'b1,                                                 // smlh_eidle_inferred_in_l0
    (NEXT_PHASE_ENABLED && MPCIE_ENABLED) ? 1'b1 : 1'b0,  // rpa_rx_rrap_sts[4]
    (NEXT_PHASE_ENABLED && MPCIE_ENABLED) ? 1'b1 : 1'b0,  // rpa_rx_rrap_sts[3]
    (NEXT_PHASE_ENABLED && MPCIE_ENABLED) ? 1'b1 : 1'b0,  // rpa_rx_rrap_sts[2]
    (NEXT_PHASE_ENABLED && MPCIE_ENABLED) ? 1'b1 : 1'b0,  // rpa_rx_rrap_sts[1]
    (NEXT_PHASE_ENABLED && MPCIE_ENABLED) ? 1'b1 : 1'b0   // rpa_rx_rrap_sts[0]
  }};
  localparam        G2_EVENT_EXISTENCE_PADDING_LEN  = 256 - G2_TOTAL_EVENT_NUM;
  localparam        G2_EVENT_EXISTENCE  = {{G2_EVENT_EXISTENCE_PADDING_LEN{1'b0}}, {
    1'b1, // xdlh_retry_req
    1'b1, // xdlh_nak_sent
    1'b1, // rdlh_rcvd_nack_perdllp
    1'b1, // xdlh_replay_timeout_err
    1'b1, // xdlh_replay_num_rlover_err
    1'b1, // rdlh_bad_dllp_err_perdllp
    1'b1, // rdlh_lcrc_tlp_err_pertlp
    1'b1  // rdlh_bad_tlp_err_pertlp
  }};
  localparam        G3_EVENT_EXISTENCE_PADDING_LEN  = 256 - G3_TOTAL_EVENT_NUM;
  localparam        G3_EVENT_EXISTENCE  = {{G3_EVENT_EXISTENCE_PADDING_LEN{1'b0}}, {
    1'b1, // cfg_cpl_timeout
    1'b1, // cfg_ca_tlp
    1'b1, // cfg_ur_tlp
    1'b1, // cfg_ecrc_tlp_err
    1'b1, // cfg_poisned_tlp
    1'b1  // rtlh_req_link_retrain
  }};
  localparam        G4_EVENT_EXISTENCE_PADDING_LEN  = 256 - G4_TOTAL_EVENT_NUM;
  localparam        G4_EVENT_EXISTENCE  = {{G4_EVENT_EXISTENCE_PADDING_LEN{1'b0}}, {NL{ // NL
    1'b1, // rmlh_rxskipremoved
    1'b1  // rmlh_rxskipadded
  }}};
  localparam        G5_EVENT_EXISTENCE_PADDING_LEN  = 256 - G5_TOTAL_EVENT_NUM;
  localparam        G5_EVENT_EXISTENCE  = {{G5_EVENT_EXISTENCE_PADDING_LEN{1'b0}}, {
    1'b1,           // smlh_lwd_change
    GEN2_ENABLED,   // smlh_spd_change
    1'b1,           // smlh_in_l23
    L1_SS_ENABLED,  // pm_in_l1_abort
    L1_SS_ENABLED,  // pm_in_l1_short
    L1_SS_ENABLED,  // pm_in_l12
    L1_SS_ENABLED,  // pm_in_l11
    L1_SS_ENABLED,  // pm_in_l1_cpm
    1'b1,           // smlh_in_l1
    1'b1,           // pm_asnak
    1'b1,           // smlh_in_rl0s
    1'b1,           // smlh_in_l0s
    1'b1,           // smlh_l1_to_recovery
    1'b1            // smlh_l0_to_recovery
  }};
  localparam        G6_EVENT_EXISTENCE_PADDING_LEN  = 256 - G6_TOTAL_EVENT_NUM;
  localparam        G6_EVENT_EXISTENCE  = {{G6_EVENT_EXISTENCE_PADDING_LEN{1'b0}}, {
    1'b1, // rdlh_duplicate_tlp_err_pertlp
    1'b1, // xtlh_xadm_restore_enable / xadm_tx_nullify_evt
    1'b1, // rdlh_nulified_tlp_err_pertlp
    1'b1, // rtlh_rcvd_ufc_perdllp
    1'b1, // rdlh_rcvd_ack_perdllp
    1'b1, // xdlh_update_fc_sent
    1'b1  // xdlh_ack_sent
  }};
  localparam        G7_EVENT_EXISTENCE_PADDING_LEN  = 256 - G7_TOTAL_EVENT_NUM;
  localparam        G7_EVENT_EXISTENCE  = {{G7_EVENT_EXISTENCE_PADDING_LEN{1'b0}}, {
    DEF_MEM_WR_ENABLE,     // rtlh_rx_defmemwr_evt
    DEF_MEM_WR_ENABLE,     // xtlh_tx_defmemwr_evt
    CCIX_INTERFACE_ENABLE, // rtlh_rx_ccix_tlp_evt
    CCIX_INTERFACE_ENABLE, // xtlh_tx_ccix_tlp_evt
    1'b1,                  // rtlh_rx_tlpwprefix_evt
    1'b1,                  // rtlh_rx_atmcop_evt
    1'b1,                  // rtlh_rx_msg_evt
    1'b1,                  // rtlh_rx_cplwd_evt
    1'b1,                  // rtlh_rx_cplwod_evt
    1'b1,                  // rtlh_rx_iord_evt
    1'b1,                  // rtlh_rx_iowr_evt
    1'b1,                  // rtlh_rx_cfgrd_evt
    1'b1,                  // rtlh_rx_cfgwr_evt
    1'b1,                  // rtlh_rx_memrd_evt
    1'b1,                  // rtlh_rx_memwr_evt
    1'b1,                  // xtlh_tx_tlpwprefix_evt
    1'b1,                  // xtlh_tx_atmcop_evt
    1'b1,                  // xtlh_tx_msg_evt
    1'b1,                  // xtlh_tx_cplwd_evt
    1'b1,                  // xtlh_tx_cplwod_evt
    1'b1,                  // xtlh_tx_iord_evt
    1'b1,                  // xtlh_tx_iowr_evt
    1'b1,                  // xtlh_tx_cfgrd_evt
    1'b1,                  // xtlh_tx_cfgwr_evt
    1'b1,                  // xtlh_tx_memrd_evt
    1'b1                   // xtlh_tx_memwr_evt
  }};
  localparam        G8_EVENT_EXISTENCE_PADDING_LEN  = 256 - G8_TOTAL_EVENT_NUM;
  localparam        G8_EVENT_EXISTENCE  = {{G8_EVENT_EXISTENCE_PADDING_LEN{1'b0}}, {
    CXL_ENABLED,           // cxl_almp_rx_repl_error
    CXL_ENABLED,           // cxl_vlsm_unexp_error
    CXL_ENABLED            // cxl_vlsm_lrsm_req_retrain
  }};

  localparam        G0_ACTUAL_EVENT_NUM = count_ones(G0_EVENT_EXISTENCE[G0_EVENT_NUM-1:0], G0_EVENT_NUM);
  localparam        G1_ACTUAL_EVENT_NUM = count_ones(G1_EVENT_EXISTENCE[G1_EVENT_NUM-1:0], G1_EVENT_NUM);
  localparam        G2_ACTUAL_EVENT_NUM = count_ones(G2_EVENT_EXISTENCE[G2_EVENT_NUM-1:0], G2_EVENT_NUM);
  localparam        G3_ACTUAL_EVENT_NUM = count_ones(G3_EVENT_EXISTENCE[G3_EVENT_NUM-1:0], G3_EVENT_NUM);
  localparam        G4_ACTUAL_EVENT_NUM = count_ones(G4_EVENT_EXISTENCE[G4_EVENT_NUM-1:0], G4_EVENT_NUM);
  localparam        G5_ACTUAL_EVENT_NUM = count_ones(G5_EVENT_EXISTENCE[G5_EVENT_NUM-1:0], G5_EVENT_NUM);
  localparam        G6_ACTUAL_EVENT_NUM = count_ones(G6_EVENT_EXISTENCE[G6_EVENT_NUM-1:0], G6_EVENT_NUM);
  localparam        G7_ACTUAL_EVENT_NUM = count_ones(G7_EVENT_EXISTENCE[G7_EVENT_NUM-1:0], G7_EVENT_NUM);
  localparam        G8_ACTUAL_EVENT_NUM = count_ones(G8_EVENT_EXISTENCE[G8_EVENT_NUM-1:0], G8_EVENT_NUM);

  localparam        MAX_REG_CNT_WIDTH   = 16;
  localparam        G0_RAM_ENABLE       = (G0_EC_CNT_WIDTH > MAX_REG_CNT_WIDTH) ? 1'b1 : 1'b0;
  localparam        G1_RAM_ENABLE       = (G1_EC_CNT_WIDTH > MAX_REG_CNT_WIDTH) ? 1'b1 : 1'b0;
  localparam        G2_RAM_ENABLE       = (G2_EC_CNT_WIDTH > MAX_REG_CNT_WIDTH) ? 1'b1 : 1'b0;
  localparam        G3_RAM_ENABLE       = (G3_EC_CNT_WIDTH > MAX_REG_CNT_WIDTH) ? 1'b1 : 1'b0;
  localparam        G4_RAM_ENABLE       = (G4_EC_CNT_WIDTH > MAX_REG_CNT_WIDTH) ? 1'b1 : 1'b0;
  localparam        G5_RAM_ENABLE       = (G5_EC_CNT_WIDTH > MAX_REG_CNT_WIDTH) ? 1'b1 : 1'b0;
  localparam        G6_RAM_ENABLE       = (G6_EC_CNT_WIDTH > MAX_REG_CNT_WIDTH) ? 1'b1 : 1'b0;
  localparam        G7_RAM_ENABLE       = (G7_EC_CNT_WIDTH > MAX_REG_CNT_WIDTH) ? 1'b1 : 1'b0;
  localparam        G8_RAM_ENABLE       = (G8_EC_CNT_WIDTH > MAX_REG_CNT_WIDTH) ? 1'b1 : 1'b0;

  localparam        G0_RAM_START_INDEX  = 0;
  localparam        G1_RAM_START_INDEX  = G0_RAM_START_INDEX + NL * ((G0_RAM_ENABLE) ? G0_ACTUAL_EVENT_NUM : 0);
  localparam        G2_RAM_START_INDEX  = G1_RAM_START_INDEX +      ((G1_RAM_ENABLE) ? G1_ACTUAL_EVENT_NUM : 0);
  localparam        G3_RAM_START_INDEX  = G2_RAM_START_INDEX +      ((G2_RAM_ENABLE) ? G2_ACTUAL_EVENT_NUM : 0);
  localparam        G4_RAM_START_INDEX  = G3_RAM_START_INDEX +      ((G3_RAM_ENABLE) ? G3_ACTUAL_EVENT_NUM : 0);
  localparam        G5_RAM_START_INDEX  = G4_RAM_START_INDEX + NL * ((G4_RAM_ENABLE) ? G4_ACTUAL_EVENT_NUM : 0);
  localparam        G6_RAM_START_INDEX  = G5_RAM_START_INDEX +      ((G5_RAM_ENABLE) ? G5_ACTUAL_EVENT_NUM : 0);
  localparam        G7_RAM_START_INDEX  = G6_RAM_START_INDEX +      ((G6_RAM_ENABLE) ? G6_ACTUAL_EVENT_NUM : 0);
  localparam        G8_RAM_START_INDEX  = G7_RAM_START_INDEX +      ((G7_RAM_ENABLE) ? G7_ACTUAL_EVENT_NUM : 0);

  localparam        TOTAL_RAM_COUNTER_NUM   = NL * ((G0_RAM_ENABLE) ? G0_ACTUAL_EVENT_NUM : 0)
                                            +      ((G1_RAM_ENABLE) ? G1_ACTUAL_EVENT_NUM : 0)
                                            +      ((G2_RAM_ENABLE) ? G2_ACTUAL_EVENT_NUM : 0)
                                            +      ((G3_RAM_ENABLE) ? G3_ACTUAL_EVENT_NUM : 0)
                                            + NL * ((G4_RAM_ENABLE) ? G4_ACTUAL_EVENT_NUM : 0)
                                            +      ((G5_RAM_ENABLE) ? G5_ACTUAL_EVENT_NUM : 0)
                                            +      ((G6_RAM_ENABLE) ? G6_ACTUAL_EVENT_NUM : 0)
                                            +      ((G7_RAM_ENABLE) ? G7_ACTUAL_EVENT_NUM : 0)
                                            +      ((G8_RAM_ENABLE) ? G8_ACTUAL_EVENT_NUM : 0);

//--------------------------------------------------------
//  General functions
//--------------------------------------------------------
  function automatic [31:0] count_ones(
    input [31:0]  v,
    input integer width
  );
    reg [31:0]  temp;
  begin
    temp        = v & ((33'd1 << width) - 1);
    temp        = ((temp & 32'h5555_5555)) + ((temp >>  1) & 32'h5555_5555);
    temp        = ((temp & 32'h3333_3333)) + ((temp >>  2) & 32'h3333_3333);
    temp        = ((temp & 32'h0F0F_0F0F)) + ((temp >>  4) & 32'h0F0F_0F0F);
    temp        = ((temp & 32'h00FF_00FF)) + ((temp >>  8) & 32'h00FF_00FF);
    temp        = ((temp & 32'h0000_FFFF)) + ((temp >> 16) & 32'h0000_FFFF);
    count_ones  = temp;
  end
  endfunction

  function automatic [31:0] get_event_num(input [3:0] event_group);
  begin
    case (event_group)
      0:  get_event_num = G0_EVENT_NUM;
      1:  get_event_num = G1_EVENT_NUM;
      2:  get_event_num = G2_EVENT_NUM;
      3:  get_event_num = G3_EVENT_NUM;
      4:  get_event_num = G4_EVENT_NUM;
      5:  get_event_num = G5_EVENT_NUM;
      6:  get_event_num = G6_EVENT_NUM;
      7:  get_event_num = G7_EVENT_NUM;
      8:  get_event_num = G8_EVENT_NUM;
      default : get_event_num = 0;
    endcase
  end
  endfunction

  function automatic [31:0] get_total_event_num(input [3:0] event_group);
  begin
    case (event_group)
      0:  get_total_event_num = G0_TOTAL_EVENT_NUM;
      1:  get_total_event_num = G1_TOTAL_EVENT_NUM;
      2:  get_total_event_num = G2_TOTAL_EVENT_NUM;
      3:  get_total_event_num = G3_TOTAL_EVENT_NUM;
      4:  get_total_event_num = G4_TOTAL_EVENT_NUM;
      5:  get_total_event_num = G5_TOTAL_EVENT_NUM;
      6:  get_total_event_num = G6_TOTAL_EVENT_NUM;
      7:  get_total_event_num = G7_TOTAL_EVENT_NUM;
      8:  get_total_event_num = G8_TOTAL_EVENT_NUM;
      default : get_total_event_num = 0;
    endcase
  end
  endfunction

  function automatic [31:0] get_counter_width(input [3:0] event_group);
  begin
    case (event_group)
      0:  get_counter_width = G0_EC_CNT_WIDTH;
      1:  get_counter_width = G1_EC_CNT_WIDTH;
      2:  get_counter_width = G2_EC_CNT_WIDTH;
      3:  get_counter_width = G3_EC_CNT_WIDTH;
      4:  get_counter_width = G4_EC_CNT_WIDTH;
      5:  get_counter_width = G5_EC_CNT_WIDTH;
      6:  get_counter_width = G6_EC_CNT_WIDTH;
      7:  get_counter_width = G7_EC_CNT_WIDTH;
      8:  get_counter_width = G8_EC_CNT_WIDTH;
      default : get_counter_width = 0;
    endcase
  end
  endfunction

  function automatic [31:0] get_event_index(input [3:0] event_group, input [7:0] event_index);
  begin
    case (event_group)
      0:  get_event_index = G0_START_INDEX + event_index;
      1:  get_event_index = G1_START_INDEX + event_index;
      2:  get_event_index = G2_START_INDEX + event_index;
      3:  get_event_index = G3_START_INDEX + event_index;
      4:  get_event_index = G4_START_INDEX + event_index;
      5:  get_event_index = G5_START_INDEX + event_index;
      6:  get_event_index = G6_START_INDEX + event_index;
      7:  get_event_index = G7_START_INDEX + event_index;
      8:  get_event_index = G8_START_INDEX + event_index;
      default : get_event_index = 0;
    endcase
  end
  endfunction

  function automatic check_event_existence(input [3:0] event_group, input [7:0] event_index);
  begin
    case (event_group)
      0:  check_event_existence  = G0_EVENT_EXISTENCE[event_index];
      1:  check_event_existence  = G1_EVENT_EXISTENCE[event_index];
      2:  check_event_existence  = G2_EVENT_EXISTENCE[event_index];
      3:  check_event_existence  = G3_EVENT_EXISTENCE[event_index];
      4:  check_event_existence  = G4_EVENT_EXISTENCE[event_index];
      5:  check_event_existence  = G5_EVENT_EXISTENCE[event_index];
      6:  check_event_existence  = G6_EVENT_EXISTENCE[event_index];
      7:  check_event_existence  = G7_EVENT_EXISTENCE[event_index];
      8:  check_event_existence  = G8_EVENT_EXISTENCE[event_index];
      default : check_event_existence = 0;
    endcase
  end
  endfunction

  parameter XADM_IF_WD      = N_XADM_IF;
  parameter XADM_P_IF_WD    = N_XADM_P_IF;
  parameter XADM_NP_IF_WD   = N_XADM_NP_IF;
  parameter XADM_CPL_IF_WD  = N_XADM_CPL_IF;
  parameter CCIX_IF_WD      = N_CCIX_IF;
  function automatic [31:0] get_event_width(input [3:0] event_group, input [7:0] event_index);
  begin
    get_event_width = 0;
    case (1)
      // Group2
      ((event_group == 2) && (event_index == 2)),
      ((event_group == 2) && (event_index == 5)): begin
        get_event_width = RX_NDLLP;
      end
      ((event_group == 2) && (event_index == 0)),
      ((event_group == 2) && (event_index == 1)): begin
        get_event_width = RX_TLP;
      end
      // Group3
      ((event_group == 3) && (event_index == 1)),
      ((event_group == 3) && (event_index == 2)),
      ((event_group == 3) && (event_index == 3)),
      ((event_group == 3) && (event_index == 4)): begin
        get_event_width = ERROR_TLP_WD + 1;
      end
      ((event_group == 3) && (event_index == 5)): begin
        get_event_width = 2;
      end
      // Group6
      ((event_group == 6) && (event_index == 1)),
      ((event_group == 6) && (event_index == 2)),
      ((event_group == 6) && (event_index == 3)): begin
        get_event_width = RX_NDLLP;
      end
      ((event_group == 6) && (event_index == 4)),
      ((event_group == 6) && (event_index == 6)): begin
        get_event_width = RX_TLP;
      end
      ((event_group == 6) && (event_index == 5)): begin
        get_event_width = XADM_IF_WD;
      end
      // Group7
      ((event_group == 7) && ((event_index == 0) || (event_index == 8)) ): begin
        get_event_width = XADM_P_IF_WD;
      end
      ((event_group == 7) && (event_index >= 1) && (event_index <= 5)),
      ((event_group == 7) && (event_index == 9) ): begin
        get_event_width = XADM_NP_IF_WD;
      end
      ((event_group == 7) && ((event_index == 6) || (event_index == 7)) ): begin
        get_event_width = XADM_CPL_IF_WD;
      end
      ((event_group == 7) && (event_index == 10)): begin
        get_event_width = XADM_IF_WD;
      end
      ((event_group == 7) && (event_index >= 11) && (event_index <= 21)),
      ((event_group == 7) && (event_index == 23)): begin
        get_event_width = RX_TLP;
      end
      // The others
      default: begin
        get_event_width = 1;
      end
    endcase
  end
  endfunction

  function automatic get_event_type(input [3:0] f_group, input [7:0] event_index);
  begin
    if (
      ((f_group == 1) && ((event_index == 5) || (event_index == 7 ) || (event_index == 8) || (event_index == 10) )) ||
      ((f_group == 5) && ((event_index >= 2) && (event_index <= 13)                      ))
    ) begin
      get_event_type  = EVENT_TYPE_LEVEL;
    end else begin
      get_event_type  = EVENT_TYPE_PULSE;
    end
  end
  endfunction

  function automatic get_ram_enable(input [3:0] event_group);
  begin
    case (event_group)
      0:  get_ram_enable  = G0_RAM_ENABLE;
      1:  get_ram_enable  = G1_RAM_ENABLE;
      2:  get_ram_enable  = G2_RAM_ENABLE;
      3:  get_ram_enable  = G3_RAM_ENABLE;
      4:  get_ram_enable  = G4_RAM_ENABLE;
      5:  get_ram_enable  = G5_RAM_ENABLE;
      6:  get_ram_enable  = G6_RAM_ENABLE;
      7:  get_ram_enable  = G7_RAM_ENABLE;
      8:  get_ram_enable  = G8_RAM_ENABLE;
      default : get_ram_enable  = 0;
    endcase
  end
  endfunction

  function automatic [31:0] get_ram_index(input [3:0] event_group, input [7:0] event_index);
    reg [31:0]  event_existence;
    reg [31:0]  int_event_index;
    reg [31:0]  event_num;
    reg [31:0]  actual_event_num;
    reg [31:0]  ram_group_offset;
  begin
    case (event_group)
      0: begin
        event_existence   = G0_EVENT_EXISTENCE[G0_EVENT_NUM-1:0];
        event_num         = G0_EVENT_NUM;
        actual_event_num  = G0_ACTUAL_EVENT_NUM;
        ram_group_offset  = G0_RAM_START_INDEX;
      end
      1: begin
        event_existence   = G1_EVENT_EXISTENCE[G1_EVENT_NUM-1:0];
        event_num         = G1_EVENT_NUM;
        actual_event_num  = 0;
        ram_group_offset  = G1_RAM_START_INDEX;
      end
      2: begin
        event_existence   = G2_EVENT_EXISTENCE[G2_EVENT_NUM-1:0];
        event_num         = G2_EVENT_NUM;
        actual_event_num  = 0;
        ram_group_offset  = G2_RAM_START_INDEX;
      end
      3: begin
        event_existence   = G3_EVENT_EXISTENCE[G3_EVENT_NUM-1:0];
        event_num         = G3_EVENT_NUM;
        actual_event_num  = 0;
        ram_group_offset  = G3_RAM_START_INDEX;
      end
      4: begin
        event_existence   = G4_EVENT_EXISTENCE[G4_EVENT_NUM-1:0];
        event_num         = G4_EVENT_NUM;
        actual_event_num  = G4_ACTUAL_EVENT_NUM;
        ram_group_offset  = G4_RAM_START_INDEX;
      end
      5: begin
        event_existence   = G5_EVENT_EXISTENCE[G5_EVENT_NUM-1:0];
        event_num         = G5_EVENT_NUM;
        actual_event_num  = 0;
        ram_group_offset  = G5_RAM_START_INDEX;
      end
      6: begin
        event_existence   = G6_EVENT_EXISTENCE[G6_EVENT_NUM-1:0];
        event_num         = G6_EVENT_NUM;
        actual_event_num  = 0;
        ram_group_offset  = G6_RAM_START_INDEX;
      end
      7: begin
        event_existence   = G7_EVENT_EXISTENCE[G7_EVENT_NUM-1:0];
        event_num         = G7_EVENT_NUM;
        actual_event_num  = 0;
        ram_group_offset  = G7_RAM_START_INDEX;
      end
      8: begin
        event_existence   = G8_EVENT_EXISTENCE[G8_EVENT_NUM-1:0];
        event_num         = G8_EVENT_NUM;
        actual_event_num  = 0;
        ram_group_offset  = G8_RAM_START_INDEX;
      end
      default : begin
        event_existence   = 0;
        event_num         = 0;
        actual_event_num  = 0;
        ram_group_offset  = 0;
      end
    endcase
    int_event_index = {24'd0, event_index}; // Converted for lint

    //              [group offset]     [lane offset]                                + event
    get_ram_index = 32'(ram_group_offset + actual_event_num * (int_event_index / event_num) + count_ones(event_existence, int_event_index % event_num));
  end
  endfunction

//---------------------------------------------------
//  Signal definisions
//---------------------------------------------------
  genvar  g_i;
  genvar  g_j;
  genvar  g_group;
  genvar  g_event;

  // CMD read data
  wire  [7:0]                               int_reg_0x08, int_reg_0x09, int_reg_0x0A, int_reg_0x0B;  // Read Data Address 0x08-0x0B
  wire  [7:0]                               int_reg_0x0C, int_reg_0x0D, int_reg_0x0E, int_reg_0x0F;  // Read Data Address 0x0C-0x0F

  // Register values
  // `RAS_DES_PTR + 08h
  reg   [1:0]                               int_reg_cnt_clr;  // Event counter clear [1:0]
  reg   [2:0]                               int_reg_cnt_en;   // Event counter enable [4:2]
  reg                                       int_reg_cnt_sts;  // Event counter status [7]
  reg   [3:0]                               int_reg_lane_sel; // Event counter lane select [11:8]
  reg   [11:0]                              int_reg_data_sel; // Event counter data select [27:16]
  reg                                       int_cnt_control;  // Indicates that the enable or clear have been written.
  wire  [7:0]                               int_reg_sel_evtnum;
  wire  [3:0]                               int_reg_sel_grp;
  wire                                      int_selected_ec_enable;
  // `RAS_DES_PTR + 0Ch
  reg   [31:0]                              int_reg_ec_data;
  wire  [31:0]                              int_selected_ec_data;

  // Event counters
  reg   [TOTAL_EVENT_NUM-1:0]               ec_event_select;
  wire                                      ec_all_on;
  wire                                      ec_all_off;
  wire                                      ec_clear_all;
  reg   [31:0]                              ec_event[0:TOTAL_EVENT_NUM-1];
  reg                                       ec_reg_counter_enable[0:TOTAL_EVENT_NUM-1];
  reg                                       ec_counter_enable[0:TOTAL_EVENT_NUM-1];
  reg                                       ec_clear_reg_counter[0:TOTAL_EVENT_NUM-1];
  reg                                       ec_clear_counter[0:TOTAL_EVENT_NUM-1];
  reg   [31:0]                              ec_event_count[0:TOTAL_EVENT_NUM-1];

  // RAM access
  reg                                       ec_ram_event_select[0:TOTAL_RAM_COUNTER_NUM-1];
  reg   [TOTAL_RAM_COUNTER_NUM-1:0]         ec_ram_enable;
  reg   [TOTAL_RAM_COUNTER_NUM-1:0]         ec_ram_clear;
  reg   [32*TOTAL_RAM_COUNTER_NUM-1:0]      ec_ram_temp_count;
  wire                                      ec_ram_active;
  wire  [TOTAL_RAM_COUNTER_NUM-1:0]         ec_ram_add_status;
  wire                                      ec_ram_actreq;
  wire                                      ec_ram_reg_access;
  wire                                      ec_ram_req_read;
  reg                                       ec_ram_req_read_1z;
  reg                                       ec_ram_reg_req;
  wire  [8:0]                               ec_ram_reg_selected_index;
  reg   [8:0]                               ec_ram_reg_index;
  wire                                      ec_ram_reg_ack;
  wire  [31:0]                              ec_ram_reg_data;

  //  Dummy Signals
  wire  [4:0]                               rpa_rx_rrap_sts;

// -----------------------------------------------------------------------------
//  CDM read access control
// -----------------------------------------------------------------------------
// spyglass disable_block STARC05-2.11.3.1
// SMD: Combinational and sequential parts of an FSM described in same always block
// SJ: This signal is not used inside this module. This is the interface signal of this module. The sequential signal is unnecessary.
  always @(posedge aux_clk or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
      cdm_ec_ack  <= #TP 2'b00;
    end else begin
      case (cdm_ec_ack)
        2'b00: begin
          if (cdm_reg_id[2] || cdm_reg_id[3]) begin
            cdm_ec_ack  <= #TP 2'b01;
          end
        end
        2'b01: begin
          if ((!ec_ram_reg_access) || (ec_ram_reg_access && ec_ram_reg_ack)) begin
            cdm_ec_ack  <= #TP 2'b10;
          end
        end
        2'b10: begin
          cdm_ec_ack  <= #TP 2'b00;
        end
        default: begin
          cdm_ec_ack  <= #TP 2'b00;
        end
      endcase
    end
  end
// spyglass enable_block STARC05-2.11.3.1

  always @(*) begin : read_data_PROC
    unique case (1'b1)
      cdm_reg_id[2]: cdm_ec_rdata = {int_reg_0x0B, int_reg_0x0A, int_reg_0x09, int_reg_0x08};
      cdm_reg_id[3]: cdm_ec_rdata = {int_reg_0x0F, int_reg_0x0E, int_reg_0x0D, int_reg_0x0C};
      default      : cdm_ec_rdata = `PCIE_UNUSED_RESPONSE;
    endcase
  end

// -----------------------------------------------------------------------------
// cdm_reg_id       - 2
// PCIE Offset      - `RAS_DES_PTR + 08h
// length           - 4 byte
// Cfig register    - int_reg_0x0B, int_reg_0x0A, int_reg_0x09, int_reg_0x08
// register         - Event counter clear [1:0] : WO
//                  - Event counter enable [4:2] : WO
//                  - Event counter status [7] : RO
//                  - Event counter lane select [11:8] : RW
//                  - Event counter data select [27:16] : RW
// -----------------------------------------------------------------------------
  assign  {int_reg_0x0B, int_reg_0x0A, int_reg_0x09, int_reg_0x08}  = {
    4'h0,             // [31:28]
    int_reg_data_sel, // [27:16]
    4'h0,             // [15:12]
    int_reg_lane_sel, // [11:8]
    int_reg_cnt_sts,  // [7]
    7'h00             // [6:0]
  };

  always @(posedge aux_clk or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
      int_cnt_control   <= #TP 1'b0;
      int_reg_cnt_clr   <= #TP 2'b00;
      int_reg_cnt_en    <= #TP 3'b000;
      int_reg_lane_sel  <= #TP 4'h0;
      int_reg_data_sel  <= #TP 12'h000;
    end else begin
      int_cnt_control         <= #TP (cdm_reg_id[2] && cdm_reg_write_pulse[0]) ? 1'b1                 : 1'b0;
      int_reg_cnt_clr         <= #TP (cdm_reg_id[2] && cdm_reg_write_pulse[0]) ? cdm_reg_wdata[1:0]   : int_reg_cnt_clr;
      int_reg_cnt_en          <= #TP (cdm_reg_id[2] && cdm_reg_write_pulse[0]) ? cdm_reg_wdata[4:2]   : int_reg_cnt_en;
      int_reg_lane_sel        <= #TP (cdm_reg_id[2] && cdm_reg_write_pulse[1]) ? cdm_reg_wdata[11:8]  : int_reg_lane_sel;
      int_reg_data_sel[7:0]   <= #TP (cdm_reg_id[2] && cdm_reg_write_pulse[2]) ? cdm_reg_wdata[23:16] : int_reg_data_sel[7:0];
      int_reg_data_sel[11:8]  <= #TP (cdm_reg_id[2] && cdm_reg_write_pulse[3]) ? cdm_reg_wdata[27:24] : int_reg_data_sel[11:8];
    end
  end

  assign  int_reg_sel_evtnum  = int_reg_data_sel[7:0];
  assign  int_reg_sel_grp     = int_reg_data_sel[11:8];

  // Event counter status
  always @(posedge aux_clk or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
      int_reg_cnt_sts <= #TP 1'b0;
    end else begin
      int_reg_cnt_sts <= #TP int_selected_ec_enable;
    end
  end

  // Enable bit selector (ec_event_select is one-hot signal.)
  // assign  int_selected_ec_enable = ec_event_select[0] & ec_counter_enable[0]:
  //                                | ec_event_select[1] & ec_counter_enable[1]:
  //                                :
  wire  [TOTAL_EVENT_NUM-1:0] temp_selected_ec_enable;
  assign  int_selected_ec_enable  = |temp_selected_ec_enable;
  generate
    for (g_i = 0;g_i < TOTAL_EVENT_NUM;g_i = g_i + 1) begin : gen_selected_ec_enable
      assign  temp_selected_ec_enable[g_i]  = ec_event_select[g_i] & ec_counter_enable[g_i];
    end
  endgenerate

// -----------------------------------------------------------------------------
// cdm_reg_id       - 3
// PCIE Offset      - `RAS_DES_PTR + 0Ch
// length           - 4 byte
// Cfig register    - int_reg_0x0F, int_reg_0x0E, int_reg_0x0D, int_reg_0x0C
// register         - Event counter data [31:0] : RO
// -----------------------------------------------------------------------------
  assign  {int_reg_0x0F, int_reg_0x0E, int_reg_0x0D, int_reg_0x0C}  = int_reg_ec_data; // Event counter data [31:0]

  always @(posedge aux_clk or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
      int_reg_ec_data <= #TP 32'd0;
    end else if (ec_ram_reg_access) begin
      int_reg_ec_data <= #TP ec_ram_reg_data;
    end else begin
      int_reg_ec_data <= #TP int_selected_ec_data;
    end
  end

  // Reg counter selector (ec_event_select is one-hot signal.)
  // assign  int_selected_ec_data = {32{ec_event_select[0]}} & ec_event_count[0]:
  //                              | {32{ec_event_select[1]}} & ec_event_count[1]:
  //                              :
  generate
  for (g_i = 0;g_i < 32;g_i = g_i + 1) begin : gen_selected_ec_data_max
    wire  [TOTAL_EVENT_NUM-1:0] temp_selected_ec_data;
    assign  int_selected_ec_data[g_i] = |temp_selected_ec_data;
    for (g_j = 0;g_j < TOTAL_EVENT_NUM;g_j = g_j + 1) begin : gen_selected_ec_data_total
      assign  temp_selected_ec_data[g_j]  = ec_event_select[g_j] & ec_event_count[g_j][g_i];
    end
  end
  endgenerate

//--------------------------------------------------------
//  Event counter clear/enable signal control
//--------------------------------------------------------
  assign  ec_all_on     = (int_cnt_control && (int_reg_cnt_en  == EN_ALL_ON )) ? 1'b1 : 1'b0;
  assign  ec_all_off    = (int_cnt_control && (int_reg_cnt_en  == EN_ALL_OFF)) ? 1'b1 : 1'b0;
  assign  ec_clear_all  = (int_cnt_control && (int_reg_cnt_clr == CLR_ALL   )) ? 1'b1 : 1'b0;

  generate
  for (g_group = 0;g_group < EC_TOTAL_GROUP_NUM;g_group = g_group + 1) begin : event_control_group
    for (g_event = 0;g_event < get_total_event_num(g_group);g_event = g_event + 1) begin : event_control_event
      if (check_event_existence(g_group, g_event)) begin : event_control_event_existence
        wire  int_on;
        wire  int_off;
        wire  int_clear;
        reg   ec_enable;

        if ((g_group == 0) || (g_group == 4)) begin : event_control_event_if_g0_g4
          //  Per lane event
          always @ ( * ) begin
            ec_event_select[get_event_index(g_group, g_event)]  = (
              (int_reg_sel_grp    ==  g_group                          ) && // group#
              (int_reg_sel_evtnum == (g_event % get_event_num(g_group))) && // Event#
              (int_reg_lane_sel   == (g_event / get_event_num(g_group)))    // Lane#
            ) ? 1'b1 : 1'b0;
          end
        end else begin : event_control_event_existence_else_g0_g4
          always @ ( * ) begin
            ec_event_select[get_event_index(g_group, g_event)]  = (
              (int_reg_sel_grp    == g_group) &&  // group#
              (int_reg_sel_evtnum == g_event)     // Event#
            ) ? 1'b1 : 1'b0;
          end
        end

        assign  int_on    = (int_cnt_control && ec_event_select[get_event_index(g_group, g_event)] && (int_reg_cnt_en  == EN_PER_ON )) ? 1'b1 : 1'b0;
        assign  int_off   = (int_cnt_control && ec_event_select[get_event_index(g_group, g_event)] && (int_reg_cnt_en  == EN_PER_OFF)) ? 1'b1 : 1'b0;
        assign  int_clear = (int_cnt_control && ec_event_select[get_event_index(g_group, g_event)] && (int_reg_cnt_clr == CLR_PER   )) ? 1'b1 : 1'b0;

        always @(posedge aux_clk or negedge sticky_rst_n) begin
          if (!sticky_rst_n) begin
            ec_enable <= #TP `DEFAULT_EC_ENABLE;
          end else if (int_on || ec_all_on) begin
            ec_enable <= #TP 1'b1;
          end else if (int_off || ec_all_off) begin
            ec_enable <= #TP 1'b0;
          end else begin
            ec_enable <= #TP ec_enable;
          end
        end

        always @ ( * ) begin
          ec_counter_enable[get_event_index(g_group, g_event)]  = ec_enable;
          ec_clear_counter[get_event_index(g_group, g_event)]   = int_clear;
          if (get_ram_enable(g_group)) begin
            ec_reg_counter_enable[get_event_index(g_group, g_event)]  = ec_enable & ec_ram_active;
            ec_clear_reg_counter[get_event_index(g_group, g_event)]   = int_clear | ec_ram_add_status[get_ram_index(g_group, g_event)];
          end else begin
            ec_reg_counter_enable[get_event_index(g_group, g_event)]  = ec_enable;
            ec_clear_reg_counter[get_event_index(g_group, g_event)]   = int_clear;
          end
        end
      end else begin : event_control_event_existence_no
        wire  const_zero = 1'b0;
        always @ ( * ) begin
          ec_event_select[get_event_index(g_group, g_event)]        = const_zero;
          ec_counter_enable[get_event_index(g_group, g_event)]      = const_zero;
          ec_clear_counter[get_event_index(g_group, g_event)]       = const_zero;
          ec_reg_counter_enable[get_event_index(g_group, g_event)]  = const_zero;
          ec_clear_reg_counter[get_event_index(g_group, g_event)]   = const_zero;
        end
      end
    end
  end
  endgenerate

//--------------------------------------------------------
//  Event connection
//--------------------------------------------------------
  //  Group0
  generate
  for (g_event = 0;g_event < G0_TOTAL_EVENT_NUM;g_event = g_event + 1) begin : gen_ec_event_g0
    case (g_event % G0_EVENT_NUM)
      0: begin : gen_ec_event_g0_case0
        //  Rx Elastic Buffer Over Flow Event counter (event number:0)
        always @ ( * ) begin
          ec_event[get_event_index(0, g_event)]         = {31'd0, rmlh_ebuf_rxoverflow[g_event / G0_EVENT_NUM]};
        end
      end
      1: begin : gen_ec_event_g0_case1
        //  Rx Elastic Buffer Under Flow Event counter (event number:1)
        always @ ( * ) begin
          ec_event[get_event_index(0, g_event)]         = {31'd0, rmlh_ebuf_rxunderflow[g_event / G0_EVENT_NUM]};
        end
      end
      2: begin : gen_ec_event_g0_case2
        //  Rx 8b10b Error Event counter (event number:2)
        always @ ( * ) begin
          ec_event[get_event_index(0, g_event)]         = {31'd0, rmlh_phy_rxcodeerror[g_event / G0_EVENT_NUM]};
        end
      end
      3: begin : gen_ec_event_g0_case3
        //  Rx Running Disparity Error Event counter (event number:3)
        always @ ( * ) begin
          ec_event[get_event_index(0, g_event)]         = {31'd0, rmlh_phy_rxdisperror[g_event / G0_EVENT_NUM]};
        end
      end
      4: begin : gen_ec_event_g0_case4
        //  Rx SKP OS Parity Error Event counter (event number:4)
        always @ ( * ) begin
          ec_event[get_event_index(0, g_event)]         = {31'd0 , rmlh_skp_parity_err[g_event / G0_EVENT_NUM]};
        end
      end
      5: begin : gen_ec_event_g0_case5
        //  Rx SYNC Header Error Event counter (event number:5)
        always @ ( * ) begin
          ec_event[get_event_index(0, g_event)]         = {31'd0 , rmlh_sync_header_err[g_event / G0_EVENT_NUM]};
        end
      end
      6: begin : gen_ec_event_g0_case6
        //  Rx Valid de-assertion Event counter (event number:6)
        always @ ( * ) begin
          ec_event[get_event_index(0, g_event)]         = {31'd0, rmlh_rxvalid_deasserted[g_event / G0_EVENT_NUM]};
        end
      end
      7: begin : gen_ec_event_g0_case7
        //  Rx CTl SKP OS Data Parity Error Event counter (event number:7)
        always @ ( * ) begin
          ec_event[get_event_index(0, g_event)]         = {31'd0 , rmlh_deskew_ctlskp_err[(g_event / G0_EVENT_NUM)*5]};
        end
      end
      8: begin : gen_ec_event_g0_case8
        //  Rx CTl SKP OS 1st Retimer Parity Error Event counter (event number:8)
        always @ ( * ) begin
          ec_event[get_event_index(0, g_event)]         = {31'd0 , rmlh_deskew_ctlskp_err[(g_event / G0_EVENT_NUM)*5+1]};
        end
      end
      9: begin : gen_ec_event_g0_case9
        //  Rx CTl SKP OS 2nd Retimer Parity Error Event counter (event number:9)
        always @ ( * ) begin
          ec_event[get_event_index(0, g_event)]         = {31'd0 , rmlh_deskew_ctlskp_err[(g_event / G0_EVENT_NUM)*5+2]};
        end
      end
      10: begin : gen_ec_event_g0_case10
        //  Rx CTl SKP OS Margin CRC and Parity Error Event counter (event number:10)
        always @ ( * ) begin
          ec_event[get_event_index(0, g_event)]         = {31'd0 , |rmlh_deskew_ctlskp_err[(g_event / G0_EVENT_NUM)*5+3+:2]};
        end
      end
      default : begin : gen_ec_event_g0_case_default
        wire  const_zero = 1'b0;
        always @ ( * ) begin
          ec_event[get_event_index(0, g_event)]         = {32{const_zero}};
        end
      end
    endcase
  end
  endgenerate

  //  Group1
  always @ ( * ) begin
    //  RRAP Timeout (event number:0)
    ec_event[get_event_index(1, 0)]         = {31'd0 , 1'b0 };
    //  RRAP abort (event number:1)
    ec_event[get_event_index(1, 1)]         = {31'd0 , 1'b0 };
    //  RRAP parity error (event number:2)
    ec_event[get_event_index(1, 2)]         = {31'd0 , 1'b0 };
    //  RRAP unexpected response (event number:3)
    ec_event[get_event_index(1, 3)]         = {31'd0 , 1'b0 };
    //  RRAP address error (event number:4)
    ec_event[get_event_index(1, 4)]         = {31'd0 , 1'b0 };
    //  Detect EI Infer (event number:5)
    ec_event[get_event_index(1, 5)]         = {31'd0, smlh_eidle_inferred_in_l0};
    //  Rx Receiver Error Event counter (event number:6)
    ec_event[get_event_index(1, 6)]         = {31'd0, rmlh_rcvd_err};
    //  Rx Recovery Request (event number:7)
    ec_event[get_event_index(1, 7)]         = {31'd0, smlh_rx_rcvry_req};
    // N_FTS Timeout (event number:8)
    ec_event[get_event_index(1, 8)]         = {31'd0, smlh_timeout_nfts};
    //  Rx Receiver Error Event counter (event number:9)
    ec_event[get_event_index(1, 9)]         = {31'd0 , rmlh_framing_err};
    //  Deskew Alignment Error Event counter (event number:10)
    ec_event[get_event_index(1, 10)]        = {31'd0, rmlh_deskew_alignment_err};
    //  Received EIOS when L0s is not supported and not directed L1 or L2 (event number:11)
    ec_event[get_event_index(1, 11)]        = {31'd0, smlh_rcv_eios_when_l0s_unsprt};
    //  Framing Error in L0 state (event number:12)
    ec_event[get_event_index(1, 12)]        = {31'd0 , rmlh_framing_err_l0};
    //  Deskew uncompleted error (event number:12)
    ec_event[get_event_index(1, 13)]        = {31'd0, smlh_deskew_uncomplete_err};
  end

  //  Group2
  always @ ( * ) begin
    //  Bad TLP Event counter (event number:0)
    ec_event[get_event_index(2, 0)]         = {{32-RX_TLP{1'b0}}, rdlh_bad_tlp_err_pertlp};
    //  LCRC Error Event counter (event number:1)
    ec_event[get_event_index(2, 1)]         = {{32-RX_TLP{1'b0}}, rdlh_lcrc_tlp_err_pertlp};
    //  BAD DLLP Event counter (event number:2)
    ec_event[get_event_index(2, 2)]         = {{32-RX_NDLLP{1'b0}}, rdlh_bad_dllp_err_perdllp};
    //  Replay_Num Rollover Event counter (event number:3)
    ec_event[get_event_index(2, 3)]         = {31'd0, xdlh_replay_num_rlover_err};
    //  Replay Timeout Event counter (event number:4)
    ec_event[get_event_index(2, 4)]         = {31'd0, xdlh_replay_timeout_err};
    //  Rx Nak DLLP Event counter (event number:5)
    ec_event[get_event_index(2, 5)]         = {{32-RX_NDLLP{1'b0}}, rdlh_rcvd_nack_perdllp};
    //  Tx Nak DLLP Event counter (event number:6)
    ec_event[get_event_index(2, 6)]         = {31'd0, xdlh_nak_sent};
    //  Retry TLP Event counter (event number:7)
    ec_event[get_event_index(2, 7)]         = {31'd0, xdlh_retry_req};
  end

  //  Group3
  always @ ( * ) begin
    //  FC Timeout Event counter (event number:0)
    ec_event[get_event_index(3, 0)]         = {31'd0, rtlh_req_link_retrain};
    //  Poisoned TLP Event counter (event number:1)
    ec_event[get_event_index(3, 1)]         = {{32-ERROR_TLP_WD-1{1'b0}}, cfg_poisned_tlp};
    //  ECRC Error Event counter (event number:2)
    ec_event[get_event_index(3, 2)]         = {{32-ERROR_TLP_WD-1{1'b0}}, cfg_ecrc_tlp_err};
    //  Unsupported Request Event counter (event number:3)
    ec_event[get_event_index(3, 3)]         = {{32-ERROR_TLP_WD-1{1'b0}}, cfg_ur_tlp};
    //  Completer Abort Event counter (event number:4)
    ec_event[get_event_index(3, 4)]         = {{32-ERROR_TLP_WD-1{1'b0}}, cfg_ca_tlp};
    //  Completion Timeout Event counter (event number:5)
    ec_event[get_event_index(3, 5)]         = {{32-2{1'b0}}, cfg_cpl_timeout};
  end

  //  Group4
  generate
  for (g_event = 0;g_event < G4_TOTAL_EVENT_NUM;g_event = g_event + 1) begin : gen_ec_event_g4
    case (g_event % G4_EVENT_NUM)
      0: begin : gen_ec_event_g4_case0
        //  Rx elastic buffer skip addition Event counter (event number:0)
        always @ ( * ) begin
          ec_event[get_event_index(4, g_event)]         = {31'd0, rmlh_rxskipadded[g_event/G4_EVENT_NUM]};
        end
      end
      1: begin : gen_ec_event_g4_case0
        //  Rx elastic buffer skip deletion Event counter (event number:1)
        always @ ( * ) begin
          ec_event[get_event_index(4, g_event)]         = {31'd0, rmlh_rxskipremoved[g_event/G4_EVENT_NUM]};
        end
      end
      default : begin : gen_ec_event_g4_case_default
        wire  const_zero = 1'b0;
        always @ ( * ) begin
          ec_event[get_event_index(4, g_event)]         = {32{const_zero}};
        end
      end
    endcase
  end
  endgenerate

  //  Group5
  always @ ( * ) begin
    // L0 to Recovery Entry (event number:0)
    ec_event[get_event_index(5, 0)]         = {31'd0, smlh_l0_to_recovery};
    // L1 to Recovery Entry (event number:1)
    ec_event[get_event_index(5, 1)]         = {31'd0, smlh_l1_to_recovery};
    // Tx L0s Entry (event number:2)
    ec_event[get_event_index(5, 2)]         = {31'd0, smlh_in_l0s};
    // Rx L0s Entry (event number:3)
    ec_event[get_event_index(5, 3)]         = {31'd0, smlh_in_rl0s};
    // ASPM L1 reject (event number:4)
    ec_event[get_event_index(5, 4)]         = {31'd0, pm_asnak};
    // L1 Entry (event number:5)
    ec_event[get_event_index(5, 5)]         = {31'd0, smlh_in_l1};
    // L1 CPM (event number:6)
    ec_event[get_event_index(5, 6)]         = {31'd0 , pm_in_l1_cpm };
    // L1.1 Entry (event number:7)
    ec_event[get_event_index(5, 7)]         = {31'd0 , pm_in_l11 };
    // L1.2 Entry (event number:8)
    ec_event[get_event_index(5, 8)]         = {31'd0 , pm_in_l12 };
    // L1 short duration (event number:9)
    ec_event[get_event_index(5, 9)]         = {31'd0 , pm_in_l1_short };
    // L1.2 abort (event number:10)
    ec_event[get_event_index(5, 10)]        = {31'd0 , pm_in_l1_abort };
    // L2 Entry (event number:11)
    ec_event[get_event_index(5, 11)]        = {31'd0, smlh_in_l23};
    // Speed Change (event number:12)
    ec_event[get_event_index(5, 12)]        = {31'd0 , smlh_spd_change};
    // Link width Change (event number:13)
    ec_event[get_event_index(5, 13)]        = {31'd0, smlh_lwd_change};
  end

  //  Group6
  always @ ( * ) begin
    //  Tx Ack DLLP Event counter (event number:0)
    ec_event[get_event_index(6, 0)]         = {31'd0, xdlh_ack_sent};
    //  Tx Update FC DLLP Event counter (event number:1)
    ec_event[get_event_index(6, 1)]         = {{32-TX_NDLLP{1'b0}}, xdlh_update_fc_sent};
    //  Rx Ack DLLP Event counter (event number:2)
    ec_event[get_event_index(6, 2)]         = {{32-RX_NDLLP{1'b0}}, rdlh_rcvd_ack_perdllp};
    //  Rx Update FC DLLP Event counter (event number:3)
    ec_event[get_event_index(6, 3)]         = {{32-RX_NDLLP{1'b0}}, rtlh_rcvd_ufc_perdllp};
    //  Rx Nullified TLP Event counter (event number:4)
    ec_event[get_event_index(6, 4)]         = {{32-RX_TLP{1'b0}}, rdlh_nulified_tlp_err_pertlp};
    //  Tx Nullified TLP Event counter (event number:5)
    ec_event[get_event_index(6, 5)]         = {{32-N_XADM_IF{1'b0}}, xadm_tx_nullify_evt};
    //  Rx Duplicate TLP Event counter (event number:6)
    ec_event[get_event_index(6, 6)]         = {{32-RX_TLP{1'b0}}, rdlh_duplicate_tlp_err_pertlp};
  end

  //  Group7
  always @ ( * ) begin
    //  Tx Memory Write Event counter (event number:0)
    ec_event[get_event_index(7, 0)]         = {{32-XADM_P_IF_WD{1'b0}}, xtlh_tx_memwr_evt};
    //  Tx Memory Read Event counter (event number:1)
    ec_event[get_event_index(7, 1)]         = {{32-XADM_NP_IF_WD{1'b0}}, xtlh_tx_memrd_evt};
    //  Tx Config Write Event counter (event number:2)
    ec_event[get_event_index(7, 2)]         = {{32-XADM_NP_IF_WD{1'b0}}, xtlh_tx_cfgwr_evt};
    //  Tx Config Read Event counter (event number:3)
    ec_event[get_event_index(7, 3)]         = {{32-XADM_NP_IF_WD{1'b0}}, xtlh_tx_cfgrd_evt};
    //  Tx IO Write Event counter (event number:4)
    ec_event[get_event_index(7, 4)]         = {{32-XADM_NP_IF_WD{1'b0}}, xtlh_tx_iowr_evt};
    //  Tx IO Read Event counter (event number:5)
    ec_event[get_event_index(7, 5)]         = {{32-XADM_NP_IF_WD{1'b0}}, xtlh_tx_iord_evt};
    //  Tx Completion wo data Event counter (event number:6)
    ec_event[get_event_index(7, 6)]         = {{32-XADM_CPL_IF_WD{1'b0}}, xtlh_tx_cplwod_evt};
    //  Tx Completion w data Event counter (event number:7)
    ec_event[get_event_index(7, 7)]         = {{32-XADM_CPL_IF_WD{1'b0}}, xtlh_tx_cplwd_evt};
    //  Tx Message TLP Event counter (event number:8)
    ec_event[get_event_index(7, 8)]         = {{32-XADM_P_IF_WD{1'b0}}, xtlh_tx_msg_evt};
    //  Tx Atomic Event counter (event number:9)
    ec_event[get_event_index(7, 9)]         = {{32-XADM_NP_IF_WD{1'b0}}, xtlh_tx_atmcop_evt};
    //  Tx TLP with Prefix Event counter (event number:10)
    ec_event[get_event_index(7, 10)]        = {{32-XADM_IF_WD{1'b0}}, xtlh_tx_tlpwprefix_evt};
    //  Rx Memory Write Event counter (event number:11)
    ec_event[get_event_index(7, 11)]        = {{32-RX_TLP{1'b0}}, rtlh_rx_memwr_evt};
    //  Rx Memory Read Event counter (event number:12)
    ec_event[get_event_index(7, 12)]        = {{32-RX_TLP{1'b0}}, rtlh_rx_memrd_evt};
    //  Rx Config Write Event counter (event number:13)
    ec_event[get_event_index(7, 13)]        = {{32-RX_TLP{1'b0}}, rtlh_rx_cfgwr_evt};
    //  Rx Config Read Event counter (event number:14)
    ec_event[get_event_index(7, 14)]        = {{32-RX_TLP{1'b0}}, rtlh_rx_cfgrd_evt};
    //  Rx IO Write Event counter (event number:15)
    ec_event[get_event_index(7, 15)]        = {{32-RX_TLP{1'b0}}, rtlh_rx_iowr_evt};
    //  Rx IO Read Event counter (event number:16)
    ec_event[get_event_index(7, 16)]        = {{32-RX_TLP{1'b0}}, rtlh_rx_iord_evt};
    //  Rx Completion wo data Event counter (event number:17)
    ec_event[get_event_index(7, 17)]        = {{32-RX_TLP{1'b0}}, rtlh_rx_cplwod_evt};
    //  Rx Completion w data Event counter (event number:18)
    ec_event[get_event_index(7, 18)]        = {{32-RX_TLP{1'b0}}, rtlh_rx_cplwd_evt};
    //  Rx Message TLP Event counter (event number:19)
    ec_event[get_event_index(7, 19)]        = {{32-RX_TLP{1'b0}}, rtlh_rx_msg_evt};
    //  Rx Atomic Event counter (event number:20)
    ec_event[get_event_index(7, 20)]        = {{32-RX_TLP{1'b0}}, rtlh_rx_atmcop_evt};
    //  Rx TLP with Prefix Event counter (event number:21)
    ec_event[get_event_index(7, 21)]        = {{32-RX_TLP{1'b0}}, rtlh_rx_tlpwprefix_evt};
    //  Tx CCIX TLP Event counter (event number:22)
    ec_event[get_event_index(7, 22)]        = {{32-CCIX_IF_WD{1'b0}} ,{CCIX_IF_WD{1'b0}}};
    //  Rx CCIX TLP Event counter (event number:23)
    ec_event[get_event_index(7, 23)]        = {{32-RX_TLP{1'b0}} ,{RX_TLP{1'b0}}};
    //  Tx Deferrable Memory Write Event counter (event number:24)
    ec_event[get_event_index(7, 24)]        = {{32-XADM_NP_IF_WD{1'b0}}     , xtlh_tx_defmemwr_evt};
    //  Rx Deferrable Memory Write Event counter (event number:25)
    ec_event[get_event_index(7, 25)]        = {{32-RX_TLP{1'b0}}     , rtlh_rx_defmemwr_evt};
  end

  //  Group8
  always @ ( * ) begin
    //  Tx Memory Write Event counter (event number:0)
    ec_event[get_event_index(8, 0)]         = {31'd0 , cxl_almp_rx_repl_error};
    //  Tx Memory Read Event counter (event number:1)
    ec_event[get_event_index(8, 1)]         = {31'd0 , cxl_vlsm_unexp_error};
    //  Tx Config Write Event counter (event number:2)
    ec_event[get_event_index(8, 2)]         = {31'd0 , cxl_vlsm_lrsm_req_retrain};
  end

  //  Dummy event connections
  assign  rpa_rx_rrap_sts = 5'b00000;

//--------------------------------------------------------
//  Event counter instantiation
//--------------------------------------------------------
  generate
  for (g_group = 0;g_group < EC_TOTAL_GROUP_NUM;g_group = g_group + 1) begin : ec_counter_group
    for (g_event = 0;g_event < get_total_event_num(g_group);g_event = g_event + 1) begin : ec_counter_event
      if (check_event_existence(g_group, g_event)) begin : ec_counter_if
        wire  [31:0] ec_cnt_out;
        cdm_rasdes_ecnt
         #(
          .INST         (INST                               ),
          .EVT_WDTH     (get_event_width(g_group, g_event)  ),
          .RAM_ENABLE   (get_ram_enable(g_group)            ),
          .RAM_DEPTH    (RASDES_RAM_DEPTH                   ),
          .FF_CNT_WDTH  (get_counter_width(g_group)         )
        ) u_cdm_rasdes_ec (
          .aux_clk      (aux_clk                                                  ),  // input
          .sticky_rst_n (sticky_rst_n                                             ),  // input
          .ec_type      (get_event_type(g_group, g_event)                         ),  // input
          .ec_en        (ec_reg_counter_enable[get_event_index(g_group, g_event)] ),  // input
          .ec_clr       (ec_clear_reg_counter[get_event_index(g_group, g_event)]  ),  // input
          .ec_clr_all   (ec_clear_all                                             ),  // input
          .ec_evt       (ec_event[get_event_index(g_group, g_event)]              ),  // input [31:0]
          .ec_cnt       (ec_cnt_out                                               )   // output [31:0]
        );

        always @ ( * ) begin : ec_counter_if_cnt
          ec_event_count[get_event_index(g_group, g_event)] = ec_cnt_out;
        end

        if (get_ram_enable(g_group)) begin : ec_counter_if_en
          always @ ( * ) begin
            ec_ram_event_select[get_ram_index(g_group, g_event)]       = ec_event_select[get_event_index(g_group, g_event)];
            ec_ram_enable[get_ram_index(g_group, g_event)]             = ec_counter_enable[get_event_index(g_group, g_event)];
            ec_ram_clear[get_ram_index(g_group, g_event)]              = ec_clear_counter[get_event_index(g_group, g_event)];
            ec_ram_temp_count[32*get_ram_index(g_group, g_event)+:32]  = ec_event_count[get_event_index(g_group, g_event)];
          end
        end
      end else begin : ec_counter_if_no
        wire  const_zero = 1'b0;
        always @ ( * ) begin
          ec_event_count[get_event_index(g_group, g_event)] = {32{const_zero}};
        end
      end
    end
  end
  endgenerate

// -----------------------------------------------------------------------------
//  RAM access control
// -----------------------------------------------------------------------------
  assign  ec_ram_actreq                                   = |ec_ram_enable;
  assign  ec_ram_req_read                                 = (ec_ram_reg_access && (cdm_reg_write_pulse == 4'h0)) ? 1'b1 : 1'b0;
  assign  ec_ram_reg_access                               = (|ec_event_select && cdm_reg_id[3] && (   // if ec_event_select==0, the selected event is not implemented.
    ((int_reg_sel_grp == 4'd0) && G0_RAM_ENABLE) ||
    ((int_reg_sel_grp == 4'd1) && G1_RAM_ENABLE) ||
    ((int_reg_sel_grp == 4'd2) && G2_RAM_ENABLE) ||
    ((int_reg_sel_grp == 4'd3) && G3_RAM_ENABLE) ||
    ((int_reg_sel_grp == 4'd4) && G4_RAM_ENABLE) ||
    ((int_reg_sel_grp == 4'd5) && G5_RAM_ENABLE) ||
    ((int_reg_sel_grp == 4'd6) && G6_RAM_ENABLE) ||
    ((int_reg_sel_grp == 4'd7) && G7_RAM_ENABLE) ||
    ((int_reg_sel_grp == 4'd8) && G8_RAM_ENABLE)
  )) ? 1'b1 : 1'b0;

  generate
  for (g_i = 0;g_i < 9;g_i = g_i + 1) begin : gen_ram_index_grp
    wire    [TOTAL_RAM_COUNTER_NUM-1:0] temp_ram_index;
    assign  ec_ram_reg_selected_index[g_i]  = |temp_ram_index;
    for (g_j = 0;g_j < TOTAL_RAM_COUNTER_NUM;g_j = g_j + 1) begin : gen_ram_index_total_ram
      assign  temp_ram_index[g_j] = ec_ram_event_select[g_j] & g_j[g_i];
    end
  end
  endgenerate

  always @(posedge aux_clk or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
      ec_ram_reg_req    <= #TP 1'b0;
      ec_ram_reg_index  <= #TP 8'd0;
    end else if (ec_ram_req_read && (!ec_ram_req_read_1z)) begin
      ec_ram_reg_req    <= #TP 1'b1;
      ec_ram_reg_index  <= #TP ec_ram_reg_selected_index;
    end else if ( ec_ram_reg_ack ) begin
      ec_ram_reg_req    <= #TP 1'b0;
    end
  end

  always @(posedge aux_clk or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
      ec_ram_req_read_1z  <= #TP 1'b0;
    end else begin
      ec_ram_req_read_1z  <= #TP ec_ram_req_read;
    end
  end

  generate
  if (EC_RAM_ENABLED) begin : gen_cdm_rasdes_ec_ramcont
    cdm_rasdes_ec_ramcont
     #(
      .INST                 (INST                       ),
      .NUMEVT               (TOTAL_RAM_COUNTER_NUM      ),
      .RASDES_RAM_DATA_WIDTH(RASDES_RAM_DATA_WIDTH      ),
      .RASDES_RAM_ADDR_WIDTH(RASDES_RAM_ADDR_WIDTH      )
    ) u_cdm_rasdes_ec_ramcont (
    // -------------- Inputs ---------------
      .aux_clk            (aux_clk            ),  // input
      .sticky_rst_n       (sticky_rst_n       ),  // input
      // -------------- counter enable ---------------
      .ec_ram_actreq      (ec_ram_actreq      ),  // input
      .ec_cnt_bus         (ec_ram_temp_count  ),  // input  [32*NUMEVT-1:0]
      // -------------- clear control ---------------
      .ec_clr_bus         (ec_ram_clear       ),  // input [NUMEVT-1:0]
      .ec_clr_all         (ec_clear_all       ),  // input
      //---- RAM I/F -----------------------
      .ec_ram_dataout     (ec_ram_dataout     ),  // input  [RASDES_RAM_DATA_WIDTH-1:0]
      //---- Register read/write access
      .reg_req            (ec_ram_reg_req     ),  // input
      .reg_index          (ec_ram_reg_index   ),  // input  [8:0]
    // -------------- Outputs ---------------
      //---- RAM I/F -----------------------
      .ec_ram_ena         (ec_ram_ena         ),  // output
      .ec_ram_wea         (ec_ram_wea         ),  // output
      .ec_ram_addra       (ec_ram_addra       ),  // output [RASDES_RAM_ADDR_WIDTH-1:0]
      .ec_ram_datain      (ec_ram_datain      ),  // output [RASDES_RAM_DATA_WIDTH-1:0]
      .ec_ram_enb         (ec_ram_enb         ),  // output
      .ec_ram_addrb       (ec_ram_addrb       ),  // output [RASDES_RAM_ADDR_WIDTH-1:0]
      //---- Temp counter control ----
      .ec_ram_active      (ec_ram_active      ),  // output
      .ec_ram_add_status  (ec_ram_add_status  ),  // output [NUMEVT-1:0]
      //---- Register read/write access ----
      .reg_ack            (ec_ram_reg_ack     ),  // output
      .reg_rdata          (ec_ram_reg_data    )   // output [31:0]
    );
  end else begin : gen_cdm_rasdes_ec_ramcont_else
    assign  ec_ram_ena        = 1'b0;
    assign  ec_ram_wea        = 1'b0;
    assign  ec_ram_addra      = {RASDES_RAM_ADDR_WIDTH{1'b0}};
    assign  ec_ram_datain     = {RASDES_RAM_DATA_WIDTH{1'b0}};
    assign  ec_ram_enb        = 1'b0;
    assign  ec_ram_addrb      = {RASDES_RAM_ADDR_WIDTH{1'b0}};
    assign  ec_ram_active     = 1'b0;
    assign  ec_ram_add_status = {TOTAL_RAM_COUNTER_NUM{1'b0}};
    assign  ec_ram_reg_ack    = 1'b0;
    assign  ec_ram_reg_data   = 32'h0000_0000;
  end
  endgenerate

`ifndef SYNTHESIS
//VCS coverage off
// RTL debug
  wire      [TOTAL_EVENT_NUM-1:0]       int_ec_reg_clr_array;
  wire      [TOTAL_EVENT_NUM-1:0]       int_ec_reg_en_array;
  wire      [TOTAL_EVENT_NUM*32-1:0]    int_ec_cnt_array;

  generate
    for (g_group = 0;g_group < EC_TOTAL_GROUP_NUM;g_group = g_group + 1) begin : debug_ec_counter_group
      for (g_event = 0;g_event < get_total_event_num(g_group);g_event = g_event + 1) begin : debug_ec_counter_event
        assign int_ec_reg_clr_array[get_event_index(g_group, g_event)] = ec_clear_reg_counter[get_event_index(g_group, g_event)];
        assign int_ec_reg_en_array[get_event_index(g_group, g_event)] = ec_reg_counter_enable[get_event_index(g_group, g_event)];
        assign int_ec_cnt_array[32*get_event_index(g_group, g_event) +: 32] = ec_event_count[get_event_index(g_group, g_event)];
      end
    end
  endgenerate

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RAM Address Monitor
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
typedef enum {
  // Group0
  MARGIN_CRC_PARITY_ERROR,
  SND_RETIMER_PARITY_ERROR,
  FST_RETIMER_PARITY_ERROR,
  CTL_SKP_PARITY_ERROR,
  RXVALID_DEASSERTED,
  SYNC_HEADER_ERR,
  SKP_PARITY_ERR,
  PHY_RXDISPERROR,
  PHY_RXCODEERROR,
  EBUF_RXUNDERFLOW,
  EBUF_RXOVERFLOW,
  // Group1
  DESKEW_ALIGNMENT_ERR,
  FRAMING_ERR,
  TIMEOUT_NFTS,
  RX_RCVRY_REQ,
  RCVD_ERR,
  EIDLE_INFERRED_IN_L0,
  RX_RRAP_STS4,
  RX_RRAP_STS3,
  RX_RRAP_STS2,
  RX_RRAP_STS1,
  RX_RRAP_STS0,
  FRAMING_ERR_L0,
  DESKEW_UNCMPL_ERR,
  RCV_EIOS_L0S_UNSPRT,
  // Group2
  RETRY_REQ,
  NAK_SENT,
  RCVD_NACK_PERDLLP,
  REPLAY_TIMEOUT_ERR,
  REPLAY_NUM_RLOVER_ERR,
  BAD_DLLP_ERR_PERDLLP,
  LCRC_TLP_ERR_PERTLP,
  BAD_TLP_ERR_PERTLP,
  // Group3
  CPL_TIMEOUT,
  CA_TLP,
  UR_TLP,
  ECRC_TLP_ERR,
  POISNED_TLP,
  REQ_LINK_RETRAIN,
  // Group4
  RXSKIPREMOVED,
  RXSKIPADDED,
  // Group5
  L0_REC,
  L1_REC,
  TL0S,
  RL0S,
  REJECT_L1,
  L1,
  L1_CPM,
  L11,
  L12,
  L1_SHORT,
  L1_ABORT,
  L23,
  SPD_CHG,
  LWD_CHG,
  // Group6
  TX_ACK_DLLP,
  TX_UPFC_DLLP,
  RX_ACK_DLLP,
  RX_UPFC_DLLP,
  RX_NLFIED_TLP,
  TX_NLFIED_TLP,
  RX_DUPLICATE_TLP,
  // Group7
  TX_MEMWR_TLP,
  TX_MEMRD_TLP,
  TX_CFGWR_TLP,
  TX_CFGRD_TLP,
  TX_IOWR_TLP,
  TX_IORD_TLP,
  TX_CPLWOD_TLP,
  TX_CPLWD_TLP,
  TX_MSG_TLP,
  TX_ATMCOP_TLP,
  TX_WPREFIX_TLP,
  RX_MEMWR_TLP,
  RX_MEMRD_TLP,
  RX_CFGWR_TLP,
  RX_CFGRD_TLP,
  RX_IOWR_TLP,
  RX_IORD_TLP,
  RX_CPLWOD_TLP,
  RX_CPLWD_TLP,
  RX_MSG_TLP,
  RX_ATMCOP_TLP,
  RX_WPREFIX_TLP,
  TX_CCIX_TLP,
  RX_CCIX_TLP,
  // Group8
  CXL_ALMP_REP_ERR,
  CXL_UNEXP_ALMP,
  CXL_REACHED_MAX_RETRY,
  UNKNOWN
} RAS_DES_RAM_INDEX_NAME;

function automatic RAS_DES_RAM_INDEX_NAME ramindex2name ( input bit [31:0] f_index ) ;
  case(f_index)
      get_ram_index (0, 0) : ramindex2name = EBUF_RXOVERFLOW;
      get_ram_index (0, 1) : ramindex2name = EBUF_RXUNDERFLOW;
      get_ram_index (0, 3) : ramindex2name = PHY_RXDISPERROR;
      get_ram_index (0, 2) : ramindex2name = PHY_RXCODEERROR;
      get_ram_index (0, 6) : ramindex2name = RXVALID_DEASSERTED;
      get_ram_index (1, 5) : ramindex2name = EIDLE_INFERRED_IN_L0;
      get_ram_index (1, 6) : ramindex2name = RCVD_ERR;
      get_ram_index (1, 7) : ramindex2name = RX_RCVRY_REQ;
      get_ram_index (1, 8) : ramindex2name = TIMEOUT_NFTS;
      get_ram_index (1,10) : ramindex2name = DESKEW_ALIGNMENT_ERR;
      get_ram_index (1,11) : ramindex2name = RCV_EIOS_L0S_UNSPRT;
      get_ram_index (1,13) : ramindex2name = DESKEW_UNCMPL_ERR;
      get_ram_index (2, 0) : ramindex2name = BAD_TLP_ERR_PERTLP;
      get_ram_index (2, 1) : ramindex2name = LCRC_TLP_ERR_PERTLP;
      get_ram_index (2, 2) : ramindex2name = BAD_DLLP_ERR_PERDLLP;
      get_ram_index (2, 3) : ramindex2name = REPLAY_NUM_RLOVER_ERR;
      get_ram_index (2, 4) : ramindex2name = REPLAY_TIMEOUT_ERR;
      get_ram_index (2, 5) : ramindex2name = RCVD_NACK_PERDLLP;
      get_ram_index (2, 6) : ramindex2name = NAK_SENT;
      get_ram_index (2, 7) : ramindex2name = RETRY_REQ;
      get_ram_index (3, 0) : ramindex2name = REQ_LINK_RETRAIN;
      get_ram_index (3, 1) : ramindex2name = POISNED_TLP;
      get_ram_index (3, 2) : ramindex2name = ECRC_TLP_ERR;
      get_ram_index (3, 3) : ramindex2name = UR_TLP;
      get_ram_index (3, 4) : ramindex2name = CA_TLP;
      get_ram_index (3, 5) : ramindex2name = CPL_TIMEOUT;
      get_ram_index (4, 0) : ramindex2name = RXSKIPADDED;
      get_ram_index (4, 1) : ramindex2name = RXSKIPREMOVED;
      get_ram_index (5, 0) : ramindex2name = L0_REC;
      get_ram_index (5, 1) : ramindex2name = L1_REC;
      get_ram_index (5, 2) : ramindex2name = TL0S;
      get_ram_index (5, 3) : ramindex2name = RL0S;
      get_ram_index (5, 4) : ramindex2name = REJECT_L1;
      get_ram_index (5, 5) : ramindex2name = L1;
      get_ram_index (5, 6) : ramindex2name = L1_CPM;
      get_ram_index (5, 7) : ramindex2name = L11;
      get_ram_index (5, 8) : ramindex2name = L12;
      get_ram_index (5, 9) : ramindex2name = L1_SHORT;
      get_ram_index (5,10) : ramindex2name = L1_ABORT;
      get_ram_index (5,11) : ramindex2name = L23;
      get_ram_index (5,12) : ramindex2name = SPD_CHG;
      get_ram_index (5,13) : ramindex2name = LWD_CHG;
      get_ram_index (6, 0) : ramindex2name = TX_ACK_DLLP;
      get_ram_index (6, 1) : ramindex2name = TX_UPFC_DLLP;
      get_ram_index (6, 2) : ramindex2name = RX_ACK_DLLP;
      get_ram_index (6, 3) : ramindex2name = RX_UPFC_DLLP;
      get_ram_index (6, 4) : ramindex2name = RX_NLFIED_TLP;
      get_ram_index (6, 5) : ramindex2name = TX_NLFIED_TLP;
      get_ram_index (6, 6) : ramindex2name = RX_DUPLICATE_TLP;
      get_ram_index (7, 0) : ramindex2name = TX_MEMWR_TLP;
      get_ram_index (7, 1) : ramindex2name = TX_MEMRD_TLP;
      get_ram_index (7, 2) : ramindex2name = TX_CFGWR_TLP;
      get_ram_index (7, 3) : ramindex2name = TX_CFGRD_TLP;
      get_ram_index (7, 4) : ramindex2name = TX_IOWR_TLP;
      get_ram_index (7, 5) : ramindex2name = TX_IORD_TLP;
      get_ram_index (7, 6) : ramindex2name = TX_CPLWOD_TLP;
      get_ram_index (7, 7) : ramindex2name = TX_CPLWD_TLP;
      get_ram_index (7, 8) : ramindex2name = TX_MSG_TLP;
      get_ram_index (7, 9) : ramindex2name = TX_ATMCOP_TLP;
      get_ram_index (7,10) : ramindex2name = TX_WPREFIX_TLP;
      get_ram_index (7,11) : ramindex2name = RX_MEMWR_TLP;
      get_ram_index (7,12) : ramindex2name = RX_MEMRD_TLP;
      get_ram_index (7,13) : ramindex2name = RX_CFGWR_TLP;
      get_ram_index (7,14) : ramindex2name = RX_CFGRD_TLP;
      get_ram_index (7,15) : ramindex2name = RX_IOWR_TLP;
      get_ram_index (7,16) : ramindex2name = RX_IORD_TLP;
      get_ram_index (7,17) : ramindex2name = RX_CPLWOD_TLP;
      get_ram_index (7,18) : ramindex2name = RX_CPLWD_TLP;
      get_ram_index (7,19) : ramindex2name = RX_MSG_TLP;
      get_ram_index (7,20) : ramindex2name = RX_ATMCOP_TLP;
      get_ram_index (7,21) : ramindex2name = RX_WPREFIX_TLP;
      get_ram_index (8, 0) : ramindex2name = CXL_ALMP_REP_ERR;
      get_ram_index (8, 1) : ramindex2name = CXL_UNEXP_ALMP;
      get_ram_index (8, 2) : ramindex2name = CXL_REACHED_MAX_RETRY;
      default              : ramindex2name = UNKNOWN;
  endcase
endfunction

RAS_DES_RAM_INDEX_NAME RAM_A_LDATA_INDEX;
always @(*)
  RAM_A_LDATA_INDEX <= #TP ramindex2name ({ec_ram_addra, 1'b0});

RAS_DES_RAM_INDEX_NAME RAM_A_HDATA_INDEX;
always @(*)
  RAM_A_HDATA_INDEX <= #TP ramindex2name ({ec_ram_addra, 1'b1});

RAS_DES_RAM_INDEX_NAME RAM_B_LDATA_INDEX;
always @(*)
  RAM_B_LDATA_INDEX <= #TP ramindex2name ({ec_ram_addrb, 1'b0});

RAS_DES_RAM_INDEX_NAME RAM_B_HDATA_INDEX;
always @(*)
  RAM_B_HDATA_INDEX <= #TP ramindex2name ({ec_ram_addrb, 1'b1});

generate
for (g_group = 0;g_group < EC_TOTAL_GROUP_NUM;g_group = g_group + 1) begin : name_ec_grp
  for (g_event = 0;g_event < get_total_event_num(g_group);g_event = g_event + 1) begin : name_ec_evt
    if (check_event_existence(g_group, g_event)) begin : name_ec_if
      RAS_DES_RAM_INDEX_NAME EC_NAME;
      wire [3:0]  info_grpnum = g_group;
      wire [7:0]  info_evtnum = g_event % get_event_num(g_group);
      wire [7:0]  info_ln     = g_event / get_event_num(g_group);

      always @(*) begin
        case({info_grpnum, info_evtnum})
          // Group0
          {4'd0, 8'd0} : EC_NAME = EBUF_RXOVERFLOW;
          {4'd0, 8'd1} : EC_NAME = EBUF_RXUNDERFLOW;
          {4'd0, 8'd2} : EC_NAME = PHY_RXCODEERROR;
          {4'd0, 8'd3} : EC_NAME = PHY_RXDISPERROR;
          {4'd0, 8'd4} : EC_NAME = SKP_PARITY_ERR;
          {4'd0, 8'd5} : EC_NAME = SYNC_HEADER_ERR;
          {4'd0, 8'd6} : EC_NAME = RXVALID_DEASSERTED;
          // Group1
          {4'd1, 8'd0} : EC_NAME = RX_RRAP_STS0;
          {4'd1, 8'd1} : EC_NAME = RX_RRAP_STS1;
          {4'd1, 8'd2} : EC_NAME = RX_RRAP_STS2;
          {4'd1, 8'd3} : EC_NAME = RX_RRAP_STS3;
          {4'd1, 8'd4} : EC_NAME = RX_RRAP_STS4;
          {4'd1, 8'd5} : EC_NAME = EIDLE_INFERRED_IN_L0;
          {4'd1, 8'd6} : EC_NAME = RCVD_ERR;
          {4'd1, 8'd7} : EC_NAME = RX_RCVRY_REQ;
          {4'd1, 8'd8} : EC_NAME = TIMEOUT_NFTS;
          {4'd1, 8'd9} : EC_NAME = FRAMING_ERR;
          {4'd1, 8'd10}: EC_NAME = DESKEW_ALIGNMENT_ERR;
          {4'd1, 8'd11}: EC_NAME = RCV_EIOS_L0S_UNSPRT;
          {4'd1, 8'd12}: EC_NAME = FRAMING_ERR_L0;
          {4'd1, 8'd13}: EC_NAME = DESKEW_UNCMPL_ERR;
          // Group2
          {4'd2, 8'd0} : EC_NAME = BAD_TLP_ERR_PERTLP;
          {4'd2, 8'd1} : EC_NAME = LCRC_TLP_ERR_PERTLP;
          {4'd2, 8'd2} : EC_NAME = BAD_DLLP_ERR_PERDLLP;
          {4'd2, 8'd3} : EC_NAME = REPLAY_NUM_RLOVER_ERR;
          {4'd2, 8'd7} : EC_NAME = RETRY_REQ;
          {4'd2, 8'd4} : EC_NAME = REPLAY_TIMEOUT_ERR;
          {4'd2, 8'd5} : EC_NAME = RCVD_NACK_PERDLLP;
          {4'd2, 8'd6} : EC_NAME = NAK_SENT;
          // Group3
          {4'd3, 8'd0} : EC_NAME = REQ_LINK_RETRAIN;
          {4'd3, 8'd1} : EC_NAME = POISNED_TLP;
          {4'd3, 8'd2} : EC_NAME = ECRC_TLP_ERR;
          {4'd3, 8'd3} : EC_NAME = UR_TLP;
          {4'd3, 8'd4} : EC_NAME = CA_TLP;
          {4'd3, 8'd5} : EC_NAME = CPL_TIMEOUT;
          // Group4
          {4'd4, 8'd0} : EC_NAME = RXSKIPADDED;
          {4'd4, 8'd1} : EC_NAME = RXSKIPREMOVED;
          // Group5
          {4'd5, 8'd0} : EC_NAME = L0_REC;
          {4'd5, 8'd1} : EC_NAME = L1_REC;
          {4'd5, 8'd2} : EC_NAME = TL0S;
          {4'd5, 8'd3} : EC_NAME = RL0S;
          {4'd5, 8'd4} : EC_NAME = REJECT_L1;
          {4'd5, 8'd5} : EC_NAME = L1;
          {4'd5, 8'd6} : EC_NAME = L1_CPM;
          {4'd5, 8'd7} : EC_NAME = L11;
          {4'd5, 8'd8} : EC_NAME = L12;
          {4'd5, 8'd9} : EC_NAME = L1_SHORT;
          {4'd5, 8'd10}: EC_NAME = L1_ABORT;
          {4'd5, 8'd11}: EC_NAME = L23;
          {4'd5, 8'd12}: EC_NAME = SPD_CHG;
          {4'd5, 8'd13}: EC_NAME = LWD_CHG;
          // Group6
          {4'd6, 8'd0} : EC_NAME = TX_ACK_DLLP;
          {4'd6, 8'd1} : EC_NAME = TX_UPFC_DLLP;
          {4'd6, 8'd2} : EC_NAME = RX_ACK_DLLP;
          {4'd6, 8'd3} : EC_NAME = RX_UPFC_DLLP;
          {4'd6, 8'd4} : EC_NAME = RX_NLFIED_TLP;
          {4'd6, 8'd5} : EC_NAME = TX_NLFIED_TLP;
          {4'd6, 8'd6} : EC_NAME = RX_DUPLICATE_TLP;
          // Group7
          {4'd7, 8'd0} : EC_NAME = TX_MEMWR_TLP;
          {4'd7, 8'd1} : EC_NAME = TX_MEMRD_TLP;
          {4'd7, 8'd2} : EC_NAME = TX_CFGWR_TLP;
          {4'd7, 8'd3} : EC_NAME = TX_CFGRD_TLP;
          {4'd7, 8'd4} : EC_NAME = TX_IOWR_TLP;
          {4'd7, 8'd5} : EC_NAME = TX_IORD_TLP;
          {4'd7, 8'd6} : EC_NAME = TX_CPLWOD_TLP;
          {4'd7, 8'd7} : EC_NAME = TX_CPLWD_TLP;
          {4'd7, 8'd8} : EC_NAME = TX_MSG_TLP;
          {4'd7, 8'd9} : EC_NAME = TX_ATMCOP_TLP;
          {4'd7, 8'd10}: EC_NAME = TX_WPREFIX_TLP;
          {4'd7, 8'd11}: EC_NAME = RX_MEMWR_TLP;
          {4'd7, 8'd12}: EC_NAME = RX_MEMRD_TLP;
          {4'd7, 8'd13}: EC_NAME = RX_CFGWR_TLP;
          {4'd7, 8'd14}: EC_NAME = RX_CFGRD_TLP;
          {4'd7, 8'd15}: EC_NAME = RX_IOWR_TLP;
          {4'd7, 8'd16}: EC_NAME = RX_IORD_TLP;
          {4'd7, 8'd17}: EC_NAME = RX_CPLWOD_TLP;
          {4'd7, 8'd18}: EC_NAME = RX_CPLWD_TLP;
          {4'd7, 8'd19}: EC_NAME = RX_MSG_TLP;
          {4'd7, 8'd20}: EC_NAME = RX_ATMCOP_TLP;
          {4'd7, 8'd21}: EC_NAME = RX_WPREFIX_TLP;
          {4'd7, 8'd22}: EC_NAME = TX_CCIX_TLP;
          {4'd7, 8'd23}: EC_NAME = RX_CCIX_TLP;
          // Group8
          {4'd8, 8'd0} : EC_NAME = CXL_ALMP_REP_ERR;
          {4'd8, 8'd1} : EC_NAME = CXL_UNEXP_ALMP;
          {4'd8, 8'd2} : EC_NAME = CXL_REACHED_MAX_RETRY;
          default      : EC_NAME = UNKNOWN;
        endcase
      end

      if ( get_ram_enable (g_group) ) begin
        wire [31:0] info_ram_index = get_ram_index(g_group, g_event);
        wire        w_type   = ec_counter_group[g_group].ec_counter_event[g_event].ec_counter_if.u_cdm_rasdes_ec.ec_type;
        wire        w_en     = ec_counter_group[g_group].ec_counter_event[g_event].ec_counter_if.u_cdm_rasdes_ec.ec_en;
        wire        w_clr    = ec_counter_group[g_group].ec_counter_event[g_event].ec_counter_if.u_cdm_rasdes_ec.ec_clr;
        wire        w_clr_all= ec_counter_group[g_group].ec_counter_event[g_event].ec_counter_if.u_cdm_rasdes_ec.ec_clr_all;
        wire [31:0] w_evt    = ec_counter_group[g_group].ec_counter_event[g_event].ec_counter_if.u_cdm_rasdes_ec.ec_evt;
        reg  [31:0] ram_cnt;

        always @(posedge aux_clk or negedge sticky_rst_n) begin
          if (!sticky_rst_n) begin
              ram_cnt <= #TP 0;
          end else if( ec_ram_ena && ec_ram_wea ) begin
                   if( {ec_ram_addra, 1'b0}==get_ram_index(g_group, g_event) ) ram_cnt <= #TP ec_ram_datain[31:0];
              else if( {ec_ram_addra, 1'b1}==get_ram_index(g_group, g_event) ) ram_cnt <= #TP ec_ram_datain[63:32];
          end
        end
      end else begin
        wire        w_type   = ec_counter_group[g_group].ec_counter_event[g_event].ec_counter_if.u_cdm_rasdes_ec.ec_type;
        wire        w_en     = ec_counter_group[g_group].ec_counter_event[g_event].ec_counter_if.u_cdm_rasdes_ec.ec_en;
        wire        w_clr    = ec_counter_group[g_group].ec_counter_event[g_event].ec_counter_if.u_cdm_rasdes_ec.ec_clr;
        wire        w_clr_all= ec_counter_group[g_group].ec_counter_event[g_event].ec_counter_if.u_cdm_rasdes_ec.ec_clr_all;
        wire [31:0] w_evt    = ec_counter_group[g_group].ec_counter_event[g_event].ec_counter_if.u_cdm_rasdes_ec.ec_evt;
        wire [31:0] w_cnt    = ec_counter_group[g_group].ec_counter_event[g_event].ec_counter_if.u_cdm_rasdes_ec.ec_cnt;
      end
    end
  end
end
endgenerate
//VCS coverage on
`endif //SYNTHESIS

endmodule //cdm_rasdes_ec_reg
