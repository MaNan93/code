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
// ---    $Revision: #14 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_rasdes_reg.sv#14 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains RAS D.E.S registers(Top module of RAS D.E.S registers).
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/pcie_pkg.svh"
`include "power_management/DWC_pcie_pm_pkg.svh"
 
 module cdm_rasdes_reg
   import DWC_pcie_ctl_pkg::N_XADM_IF;
   import DWC_pcie_ctl_pkg::N_XADM_P_IF;
   import DWC_pcie_ctl_pkg::N_XALI_IF;
   import DWC_pcie_ctl_pkg::N_XADM_NP_IF;
   import DWC_pcie_ctl_pkg::N_XADM_CPL_IF;
   import DWC_pcie_ctl_pkg::N_CCIX_IF;
   import DWC_pcie_ctl_pkg::NVC_WD;
  import pcie_pkg::fc_type_e;
  import DWC_pcie_pm_pkg::usp_prot_fsm_state_e;
  import DWC_pcie_pm_pkg::usp_link_fsm_state_e;
  import DWC_pcie_pm_pkg::dsp_prot_fsm_state_e;
  import DWC_pcie_pm_pkg::dsp_link_fsm_state_e;
  import DWC_pcie_pm_pkg::pm_active_l0s_fsm_e;
  import DWC_pcie_ctl_pkg::ERROR_TLP_WD;
#(
    parameter INST          = 0,                                          // The uniquifying parameter for each port logic instance.
    parameter TP            = `TP,                                        // Clock to Q delay (simulator insurance)
    parameter NL            = `CX_NL,                                     // Number of Lanes Supported
    parameter NW            = `CX_NW,                                     // Number of 32-bit dwords handled by the datapath each clock.
    parameter TX_PSET_WD    = 4,                                          // Width of Transmitter Equalization Presets
    parameter RX_PSET_WD    = 3,                                          // Width of Receiver Equalization Presets
    parameter TX_COEF_WD    = 18,                                         // Width of concatenated bus for Equalization Coefficients: {C(+1), C(0), C(-1)}
    parameter TX_FS_WD      = 6,                                          // Width of Full Swing or Low Frequency
    parameter FOMFEEDBACK_WD = 8,                                         // Width of Figure of Merit
    parameter DIRFEEDBACK_WD = `DIRFEEDBACK_WD,
    parameter RASDES_EC_RAM_DATA_WIDTH = `CX_RAS_DES_EC_RAM_DATA_WIDTH,   // Event counter RAM data width
    parameter RASDES_EC_RAM_ADDR_WIDTH = `CX_RAS_DES_EC_RAM_ADDR_WIDTH,   // Event counter RAM address data width
    parameter RASDES_EC_INFO_CM = `CX_RAS_DES_EC_INFO_CMN_BW,             // Bit width of event counter debug info(common)
    parameter RASDES_EC_INFO_PL = `CX_RAS_DES_EC_INFO_PLN_BW,             // Bit width of event counter debug info(per lane)
    parameter RASDES_TBA_RAM_DATA_WIDTH = `CX_RAS_DES_TBA_RAM_DATA_WIDTH, // Event counter RAM data width
    parameter RASDES_TBA_RAM_ADDR_WIDTH = `CX_RAS_DES_TBA_RAM_ADDR_WIDTH, // Event counter RAM address data width
    parameter RASDES_SD_INFO_CM = `CX_RAS_DES_SD_INFO_CMN_BW,             // Bit width of silicon debug info(common)
    parameter RASDES_SD_INFO_PL = `CX_RAS_DES_SD_INFO_PLN_BW,             // Bit width of silicon debug info(per lane)
    parameter RASDES_SD_INFO_PV = `CX_RAS_DES_SD_INFO_PVC_BW,             // Bit width of silicon debug info(per vc)
    parameter RASDES_TBA_INFO_CM = `CX_RAS_DES_TBA_INFO_CMN_BW,             // Bit width of Time based analysis info(common)
    parameter NF            = `CX_NFUNC,                                  // Number of Functions
    parameter NVC           = `CX_NVC,                                    // Number of virtual channels
    parameter RX_TLP        = `CX_RX_TLP,                                 // Number of TLPs that can be received in a single cycle
    parameter FX_TLP        = `CX_FX_TLP,                                 // Number of TLPs that can be processed in a single cycle after the formation block
    parameter RX_NDLLP      = `CX_RX_NDLLP,                               // Max number of DLLPs received per cycle
    parameter NUM_EOT       = `CX_NUM_EOT,                                // Max number of END/EDB per cycle  
    parameter TX_NDLLP      = `CX_TX_NDLLP,                               // Max number of DLLPs send per cycle
    parameter PHY_NB        = `CX_PHY_NB,                                 // Number of symbols (bytes) per clock cycle of PHY's PIPE interface
    parameter PHY_RXSB_WD   = `CX_PHY_RXSB_WD,                            // Width of phy_mac_rxstartblock per lane
    parameter PHY_RXSH_WD   = `CX_PHY_RXSH_WD,                            // Width of phy_mac_rxsyncheader per lane
    
    parameter  HCRD_WD   = `SCALED_FC_SUPPORTED ? 12 : 8,
    parameter  DCRD_WD   = `SCALED_FC_SUPPORTED ? 16 : 12
)

                         (
// -------------- Inputs ---------------
    input                                     aux_clk,                          // Clock
    input                                     sticky_rst_n,                     // Reset sticky registers olny
 // --- Register access signals
    input  [31:0]                             lbc_cdm_data,                     // Write Data 
    input                                     lbc_cdm_dbi,                      // DBI Access
    input  [4*NF-1:0]                         ecfg_write_pulse,                 // Write Byte Enables
    input  [NF-1:0]                           rasdes_reg_sel,                   // Register select
    input  [(64*NF)-1:0]                      rasdes_reg_id,                    // Register access ID
    input                                     dbi_ro_wr_en,                     // used to make RW registers look like RO for compliance
    input wire                                cfg_err_inj_wr_disable,           // used to disable write access to error injection enable bits from the wire
 //---- RAM I/F -----------------------
    input  [RASDES_EC_RAM_DATA_WIDTH-1:0]     cdm_ras_des_ec_ram_dataout,       // RAS DES Event counter register RAM data out
    input  [RASDES_TBA_RAM_DATA_WIDTH-1:0]    cdm_ras_des_tba_ram_dataout,      // RAS DES Time based analysis register RAM data out
 // --- Event counter signals
    input  [NL-1:0]                           rmlh_ebuf_rxoverflow,             // Pulse : Rx elastic buffer overflow error status if the corresponding lane detected a lane-based error
    input  [NL-1:0]                           rmlh_ebuf_rxunderflow,            // Pulse : Rx elastic buffer underflow error status if the corresponding lane detected a lane-based error
    input  [NL-1:0]                           rmlh_phy_rxcodeerror,             // Pulse : Rx symbol error status if the corresponding lane detected a lane-based error
    input  [NL-1:0]                           rmlh_phy_rxdisperror,             // Pulse : Rx running disparity error if the corresponding lane detected a lane-based error
    input  [NL-1:0]                           rmlh_skp_parity_err,              // Pulse : Rx skip ordered set parity error
    input  [NL-1:0]                           rmlh_sync_header_err,             // Pulse : Rx sync header undefined error
    input  [NL-1:0]                           rmlh_rxvalid_deasserted,          // Pulse : Rx burst de-assertion
    input  [NL*5-1:0]                         rmlh_deskew_ctlskp_err,           // Pulse : CS-SKP-OS error [0]data parity[1]1st retimer[2]2nd retimer[3]margin crc[4]margin parity
    input                                     rmlh_rcvd_err,                    // Pulse : Rx receiver Error
    input                                     rmlh_framing_err,                 // Pulse : Rx framing error in gen3 rate
    input                                     rmlh_framing_err_l0,              // Pulse : Rx framing error in gen3 rate when L0 state
    input                                     rmlh_deskew_alignment_err,        // Level : Rx deskew alignment error
    input  [NL-1:0]                           rmlh_rxskipadded,                 // Pulse : Rx skip added in elastic buffer
    input  [NL-1:0]                           rmlh_rxskipremoved,               // Pulse : Rx skip removed in elastic buffer
    input  [ERROR_TLP_WD:0]                   cfg_poisned_tlp,                  // Pulse : Poisoned TLP Event for Ras D.E.S event counter
    input  [ERROR_TLP_WD:0]                   cfg_ecrc_tlp_err,                 // Pulse : ECRC Error TLP Event for Ras D.E.S event counter
    input  [ERROR_TLP_WD:0]                   cfg_ur_tlp,                       // Pulse : UR Error TLP Event for Ras D.E.S event counter
    input  [ERROR_TLP_WD:0]                   cfg_ca_tlp,                       // Pulse : Completer Abort TLP Event for Ras D.E.S event counter
    input  [1:0]                              cfg_cpl_timeout,                  // Pulse : Completion Timeout Event for Ras D.E.S event counter
    input                                     smlh_eidle_inferred_in_l0,        // Level: Detect EI Infer for Ras D.E.S event counter
    input                                     smlh_rx_rcvry_req,                // Level: Rx Recovery Request for Ras D.E.S event counter
    input                                     smlh_timeout_nfts,                // Level: N_FTS Timeout for Ras D.E.S event counter
    input                                     smlh_l0_to_recovery,              // Pulse : L0 to Recovery for Ras D.E.S event counter
    input                                     smlh_l1_to_recovery,              // Pulse : L1 to Recovery for Ras D.E.S event counter
    input                                     smlh_in_l0s,                      // Level: Tx L0s Entry for Ras D.E.S event counter
    input                                     smlh_in_rl0s,                     // Level: Rx L0s Entry for Ras D.E.S event counter
    input                                     smlh_in_l0,                       // Level: L0
    input                                     smlh_ltssm_in_l0p,                // Level: L0p
    input                                     smlh_link_in_training,            // Level: Config or Recovery
    input                                     smlh_rcv_eios_when_l0s_unsprt,    // pulse: Received EIOS when L0s is not supported and not directed L1 or L2
    input                                     smlh_deskew_uncomplete_err,       // Pulse: Deskew uncompleted error for Ras D.E.S event counter
    input                                     cxl_almp_rx_repl_error,           // Pulse: (CXL only) ALMP Replication error
    input                                     cxl_vlsm_unexp_error,             // Pulse: (CXL only) unexpected ALMP error
    input                                     cxl_vlsm_lrsm_req_retrain,        // Pulse: (CXL only) NUM_RETRY reached MAX_NUM_RETRY
    input                                     pm_asnak,                         // Level: ASPM L1 reject for Ras D.E.S event counter
    input                                     smlh_in_l1,                       // Level: L1 Entry for Ras D.E.S event counter
    input  [2:0]                              l1sub_state,                      // Level: L1 sub state
    input                                     pm_in_l11,                        // Level: L1.1 Entry for Ras D.E.S event counter
    input                                     pm_in_l12,                        // Level: L1.2 Entry for Ras D.E.S event counter
    input                                     pm_in_l1_short,                   // Level: L1 short duration for Ras D.E.S event counter
    input                                     pm_in_l1_cpm,                     // Level: L1 Clock PM (L1 with REFCLK removal/PLL Off) for Ras D.E.S event counter
    input                                     pm_in_l1_abort,                   // Level: L1.2 abort for Ras D.E.S event counter
    input                                     smlh_in_l23,                      // Level: L2 Entry for Ras D.E.S event counter
    input                                     smlh_spd_change,                  // Level: Speed Change for Ras D.E.S event counter
    input                                     smlh_lwd_change,                  // Level: Link Width Change for Ras D.E.S event counter
    input  [RX_TLP-1:0]                       rdlh_bad_tlp_err_pertlp,          // Pulse : Rx Bad TLP Event per TLP for Ras D.E.S event counter
    input  [RX_TLP-1:0]                       rdlh_lcrc_tlp_err_pertlp,         // Pulse : Rx LCRC Error TLP Event per TLP for Ras D.E.S event counter
    input  [RX_TLP-1:0]                       rdlh_nulified_tlp_err_pertlp,     // Pulse : Rx Nullified TLP Event per TLP for Ras D.E.S event counter
    input  [RX_TLP-1:0]                       rdlh_duplicate_tlp_err_pertlp,    // Pulse : Rx Duplicate TLP Event per TLP for Ras D.E.S event counter
    input  [RX_NDLLP-1:0]                     rdlh_bad_dllp_err_perdllp,        // Pulse : Rx Bad DLLP Event per DLLP for Ras D.E.S event counter
    input  [RX_NDLLP-1:0]                     rdlh_rcvd_nack_perdllp,           // Pulse : Rx Nak DLLP Event per DLLP for Ras D.E.S event counter
    input  [RX_NDLLP-1:0]                     rdlh_rcvd_ack_perdllp,            // Pulse : Rx Ack DLLP Event per DLLP for Ras D.E.S event counter
    input                                     xdlh_replay_num_rlover_err,       // Pulse : Replay_Num Rollover Eventfor Ras D.E.S event counter
    input                                     xdlh_replay_timeout_err,          // Pulse : Replay Timeout for Ras D.E.S event counter
    input                                     xdlh_retry_req,                   // Pulse : Retry Event for Ras D.E.S event counter
    input                                     xdlh_nak_sent,                    // Pulse : Tx Nak DLLP Event per TLP for Ras D.E.S event counter
    input                                     xdlh_ack_sent,                    // Pulse : Tx Ack DLLP Event per TLP for Ras D.E.S event counter
    input  [TX_NDLLP-1:0]                     xdlh_update_fc_sent,              // Pulse : Tx Update-FC DLLP Event per TLP for Ras D.E.S event counter
    input  [N_XADM_IF-1:0]                    xadm_tx_nullify_evt,              // Pulse : Tx Nullified or dropped TLP for Ras D.E.S event counter
    input                                     rtlh_req_link_retrain,            // Pulse : FC Timeout Event per TLP for Ras D.E.S event counter
    input  [RX_NDLLP -1:0]                    rtlh_rcvd_ufc_perdllp,            // Pulse : Rx Update-FC DLLP Event per TLP for Ras D.E.S event counter
    input  [RX_TLP-1:0]                       rtlh_rx_memwr_evt,                // Pulse : Rx Memory Write TLP for Ras D.E.S event counter
    input  [RX_TLP-1:0]                       rtlh_rx_defmemwr_evt,             // Pulse : Rx Deferrable Memory Write TLP for Ras D.E.S event counter
    input  [RX_TLP-1:0]                       rtlh_rx_memrd_evt,                // Pulse : Rx Memory Read TLP for Ras D.E.S event counter
    input  [RX_TLP-1:0]                       rtlh_rx_cfgwr_evt,                // Pulse : Rx Config Write TLP for Ras D.E.S event counter
    input  [RX_TLP-1:0]                       rtlh_rx_cfgrd_evt,                // Pulse : Rx Config Read TLP for Ras D.E.S event counter
    input  [RX_TLP-1:0]                       rtlh_rx_iowr_evt,                 // Pulse : Rx I/O Write TLP for Ras D.E.S event counter
    input  [RX_TLP-1:0]                       rtlh_rx_iord_evt,                 // Pulse : Rx I/O Read TLP for Ras D.E.S event counter
    input  [RX_TLP-1:0]                       rtlh_rx_cplwod_evt,               // Pulse : Rx Completion without Data TLP for Ras D.E.S event counter
    input  [RX_TLP-1:0]                       rtlh_rx_cplwd_evt,                // Pulse : Rx Completion with Data TLP for Ras D.E.S event counter
    input  [RX_TLP-1:0]                       rtlh_rx_msg_evt,                  // Pulse : Rx Message TLP for Ras D.E.S event counter
    input  [RX_TLP-1:0]                       rtlh_rx_atmcop_evt,               // Pulse : Rx AtomicOp TLP for Ras D.E.S event counter
    input  [RX_TLP-1:0]                       rtlh_rx_tlpwprefix_evt,           // Pulse : Rx TLP with Prefix for Ras D.E.S event counter
    input                                     app_malformed_tlp,                // Pulse : malformed TLP status from application
    input  [RX_TLP*11-1:0]                    rtlh_rx_tlp_dpsize,               // Receiving TLP's data payload size[DW]
    input    [N_XADM_P_IF-1:0]               xtlh_tx_memwr_evt,                // Pulse : Tx Memory Write TLP Event for Ras D.E.S event counter
    input    [N_XADM_NP_IF-1:0]              xtlh_tx_defmemwr_evt,             // Pulse : Tx Deferrable Memory Write TLP Event for Ras D.E.S event counter
    input    [N_XADM_NP_IF-1:0]              xtlh_tx_memrd_evt,                // Pulse : Tx Memory Read TLP Event TLP for Ras D.E.S event counter
    input    [N_XADM_NP_IF-1:0]              xtlh_tx_cfgwr_evt,                // Pulse : Tx Config Write TLP for Ras D.E.S event counter
    input    [N_XADM_NP_IF-1:0]              xtlh_tx_cfgrd_evt,                // Pulse : Tx Config Read TLP for Ras D.E.S event counter
    input    [N_XADM_NP_IF-1:0]              xtlh_tx_iowr_evt,                 // Pulse : Tx I/O Write TLP for Ras D.E.S event counter
    input    [N_XADM_NP_IF-1:0]              xtlh_tx_iord_evt,                 // Pulse : Tx I/O Read TLP for Ras D.E.S event counter
    input    [N_XADM_CPL_IF-1:0]             xtlh_tx_cplwod_evt,               // Pulse : Tx Completion with data TLP for Ras D.E.S event counter
    input    [N_XADM_CPL_IF-1:0]             xtlh_tx_cplwd_evt,                // Pulse : Tx Completion without data TLP for Ras D.E.S event counter
    input    [N_XADM_P_IF-1:0]                xtlh_tx_msg_evt,                  // Pulse : Tx Message TLP for Ras D.E.S event counter
    input    [N_XADM_NP_IF-1:0]              xtlh_tx_atmcop_evt,               // Pulse : Tx AtomicOP TLP for Ras D.E.S event counter
    input    [N_XADM_IF-1:0]                 xtlh_tx_tlpwprefix_evt,           // Pulse : Tx TLP with Prefix for Ras D.E.S event counter
    input    [N_XADM_IF*11-1:0]               xtlh_tx_tlp_dpsize,               // Transmitting TLP data payload size[DW]
 // --- Time based Analysis signals
 // --- Error Injection signals
    input  [2:0]                              rdlh_einj0_lcrc_evt,              // Error injection 0 event flag
    input  [2:0]                              radm_einj0_ecrc_evt,              // Error injection 0 Rx ECRC TLP event
    input                                     xmlh_einj0_oscrc_evt,             // Error injection 0 CRC error event
    input  [1:0]                              xdlh_einj0_lcrc_evt,              // Error injection 0 LCRC event
    input                                     xdlh_einj0_fcrc_evt,              // Error injection 0 ECRC event
    input  [1:0]                              xdlh_einj0_dllpcrc_evt,           // Error injection 0 DLLP CRC event
    input                                     xadm_einj0_ecrc_evt,              // Error injection 0 Tx ECRC TLP event
    input  [1:0]                              ras_des_einj1_exp_sequm_evt,    
    input                                     ras_des_einj1_ack_nak_sequm_evt,
    input                                     xdlh_einj2_nak_evt,               // Error injection 2 NAK event
    input  [1:0]                              xmlh_einj3_osmsk_evt,             // Error injection 3 8b/10b K-code mask event
    input                                     rtlh_einj4_fc_evt,                // Error injection 4 FC event
    input                                     xdlh_einj5_nultlp_evt,            // Error injection 5 nullified TLP event
    input                                     xdlh_einj5_dup_evt,               // Error injection 5 Duplicate TLP event
    input [$clog2(N_XALI_IF+2)-1:0]           xaim_einj6_tlp_evt,
 // --- Silcon debug signals
    input  [(NL*8)-1:0]                       rmlh_deskew_fifo_ptr,             // Pulse : Rx deskew pointer address
    input  [6:0]                              rmlh_framing_err_ptr,             // Pulse : Rx framing error pointer in gen3 rate
    input  [NL*`CX_PHY_TXEI_WD-1:0]           mac_phy_txelec_txburst_i,         // Level : PIPE: TxElecIdle/TxBurst for Ras D.E.S Silicon Debug
    input  [NL-1:0]                           mac_phy_rxpolarity,               // Level : PIPE: RxPolarity for Ras D.E.S Silicon Debug
    input  [NL-1:0]                           phy_mac_rxelec_rxh8exit,          // Level : PIPE: RxElecIdle/RxHibern8ExitType1 for Ras D.E.S Silicon Debug
    input  [NL-1:0]                           phy_mac_rxvalid_rxburst,          // Level : PIPE: RxValid/RxBurst
    input  [(NL*PHY_NB*8)-1:0]                orig_pipe_rxdata,                 // Level: Origial PIPE RxData
    input  [(NL*PHY_NB)-1:0]                  orig_pipe_rxdatak,                // Level: Origial PIPE RxDataK
    input  [NL-1:0]                           orig_pipe_rxdatavalid,            // Level: Origial PIPE RxDataValid
    input  [(NL*3)-1:0]                       orig_pipe_rxstatus,               // pulse : Origial PIPE RxStatus
    input  [(NL*PHY_RXSB_WD)-1:0]             orig_pipe_rxstartblock,           // Level: Origial PIPE RxStartBlock
    input  [(NL*PHY_RXSH_WD)-1:0]             orig_pipe_rxsyncheader,           // Level: Origial PIPE RxSyncHeader
    input                                     orig_pipe_blockaligncontrol,      // Level: Origial PIPE BlockAlignControl
    input  [NL-1:0]                           latched_rxdetected,               // Level : PIPE: Detect Lane for Ras D.E.S Silicon Debug
    input usp_link_fsm_state_e                pm_usp_link_state,                // Level : PM Internal usp link fsm state for Ras D.E.S Silicon Debug
    input usp_prot_fsm_state_e                pm_usp_prot_state,                // Level : PM Internal usp prot fsm state for Ras D.E.S Silicon Debug
    input dsp_link_fsm_state_e                pm_dsp_link_state,                // Level : PM Internal dsp link fsm state for Ras D.E.S Silicon Debug
    input dsp_prot_fsm_state_e                pm_dsp_prot_state,                // Level : PM Internal dsp prot fsm state for Ras D.E.S Silicon Debug
    input pm_active_l0s_fsm_e                 pm_l0s_state,                     // Level : PM Internal l0s fsm state for Ras D.E.S Silicon Debug
    input                                     smlh_lane_reversed,               // Level : Lane Reversal Operation for Ras D.E.S Silicon Debug
    input                                     pm_pme_resend_flag,               // Level : PME Re-Send flag for Ras D.E.S Silicon Debug 
    input  [15:0]                             smlh_ltssm_variable,              // Level: Ltssm specific parameters for Ras D.E.S event counter
    input  [1:0]                              ltssm_powerdown,                  // Level: PIPE: Power Down for Ras D.E.S Silicon Debug
    input  [7:0]                              latched_ts_nfts,                  // Level: Latched NFTS for Ras D.E.S Silicon Debug
    input  [1:0]                              rdlh_dlcntrl_state,               // Level : DLCM state machine signal for Ras D.E.S Silicon Debug
    input                                     rdlh_vc0_initfc1_status,          // Level : VC0 Init-FC1 status for Ras D.E.S Silicon Debug
    input                                     rdlh_vc0_initfc2_status,          // Level : VC0 Init-FC2 status for Ras D.E.S Silicon Debug 
    input  [11:0]                             rdlh_xplh_curnt_rx_ack_seqnum,    // Level : Current Rx Ack Sequence number status for Ras D.E.S Silicon Debug
    input  [11:0]                             xdlh_xplh_curnt_seqnum,           // Level : Current Tx Sequence number status for Ras D.E.S Silicon Debug
    input  [(NVC*HCRD_WD)-1:0]                rtlh_fc_rcvd_ph,                  // Level : Current FC Credit Received(Posted Header) for Ras D.E.S Silicon Debug
    input  [(NVC*DCRD_WD)-1:0]                rtlh_fc_rcvd_pd,                  // Level : Current FC Credit Received(Posted Data) for Ras D.E.S Silicon Debug
    input  [(NVC*HCRD_WD)-1:0]                rtlh_fc_rcvd_nph,                 // Level : Current FC Credit Received(Non-Posted Header) for Ras D.E.S Silicon Debug
    input  [(NVC*DCRD_WD)-1:0]                rtlh_fc_rcvd_npd,                 // Level : Current FC Credit Received(Non-Posted Data) for Ras D.E.S Silicon Debug
    input  [(NVC*HCRD_WD)-1:0]                rtlh_fc_rcvd_cplh,                // Level : Current FC Credit Received(Completion Header) for Ras D.E.S Silicon Debug
    input  [(NVC*DCRD_WD)-1:0]                rtlh_fc_rcvd_cpld,                // Level : Current FC Credit Received(Completion Data) for Ras D.E.S Silicon Debug
    input  [(NVC*HCRD_WD)-1:0]                rtlh_fc_allctd_ph,                // Level : Current FC Credit Allocated(Posted Header) for Ras D.E.S Silicon Debug
    input  [(NVC*DCRD_WD)-1:0]                rtlh_fc_allctd_pd,                // Level : Current FC Credit Allocated(Posted Data) for Ras D.E.S Silicon Debug
    input  [(NVC*HCRD_WD)-1:0]                rtlh_fc_allctd_nph,               // Level : Current FC Credit Allocated(Non-Posted Header) for Ras D.E.S Silicon Debug
    input  [(NVC*DCRD_WD)-1:0]                rtlh_fc_allctd_npd,               // Level : Current FC Credit Allocated(Non-Posted Data) for Ras D.E.S Silicon Debug
    input  [(NVC*HCRD_WD)-1:0]                rtlh_fc_allctd_cplh,              // Level : Current FC Credit Allocated(Completion Header) for Ras D.E.S Silicon Debug;
    input  [(NVC*DCRD_WD)-1:0]                rtlh_fc_allctd_cpld,              // Level : Current FC Credit Allocated(Completion Data) for Ras D.E.S Silicon Debug;
    input  [(NVC*HCRD_WD)-1:0]                xadm_fc_cnsmd_ph,                 // Level : Current FC Credit Consumed(Posted Header) for Ras D.E.S Silicon Debug
    input  [(NVC*DCRD_WD)-1:0]                xadm_fc_cnsmd_pd,                 // Level : Current FC Credit Consumed(Posted Data) for Ras D.E.S Silicon Debug
    input  [(NVC*HCRD_WD)-1:0]                xadm_fc_cnsmd_nph,                // Level : Current FC Credit Consumed(Non-Posted Header) for Ras D.E.S Silicon Debug
    input  [(NVC*DCRD_WD)-1:0]                xadm_fc_cnsmd_npd,                // Level : Current FC Credit Consumed(Non-Posted Data) for Ras D.E.S Silicon Debug
    input  [(NVC*HCRD_WD)-1:0]                xadm_fc_cnsmd_cplh,               // Level : Current FC Credit Consumed(Completion Header) for Ras D.E.S Silicon Debug
    input  [(NVC*DCRD_WD)-1:0]                xadm_fc_cnsmd_cpld,               // Level : Current FC Credit Consumed(Completion Data) for Ras D.E.S Silicon Debug
    input  [(NVC*HCRD_WD)-1:0]                xadm_fc_limit_ph,                 // Level : Current FC Credit limit(Posted Header) for Ras D.E.S Silicon Debug
    input  [(NVC*DCRD_WD)-1:0]                xadm_fc_limit_pd,                 // Level : Current FC Credit limit(Posted Data) for Ras D.E.S Silicon Debug
    input  [(NVC*HCRD_WD)-1:0]                xadm_fc_limit_nph,                // Level : Current FC Credit limit(Non-Posted Header) for Ras D.E.S Silicon Debug
    input  [(NVC*DCRD_WD)-1:0]                xadm_fc_limit_npd,                // Level : Current FC Credit limit(Non-Posted Data) for Ras D.E.S Silicon Debug
    input  [(NVC*HCRD_WD)-1:0]                xadm_fc_limit_cplh,               // Level : Current FC Credit limit(Completion Header) for Ras D.E.S Silicon Debug
    input  [(NVC*DCRD_WD)-1:0]                xadm_fc_limit_cpld,               // Level : Current FC Credit limit(Completion Data) for Ras D.E.S Silicon Debug
    input  [(FX_TLP*8)-1:0]                   radm_mlf_tlp_err_ptr,             // Pulse : malformed TLP 1st error pointer (enabled by radm_mlf_tlp_err)
    input                                     init_eq_pending,                  // Level : Equalization sequence for Ras D.E.S Silicon Debug
    input  [NL*TX_FS_WD-1:0]                  mac_cdm_ras_des_fs,               // Level : Remote Device FS for Ras D.E.S Silicon Debug
    input  [NL*TX_FS_WD-1:0]                  mac_cdm_ras_des_lf,               // Level : Remote Device LF for Ras D.E.S Silicon Debug
    input  [NL*TX_COEF_WD-1:0]                mac_cdm_ras_des_coef_ltx,         // Level : Current Local Transmitter coefficient for Ras D.E.S Silicon Debug
    input  [NL*FOMFEEDBACK_WD-1:0]            phy_cdm_ras_des_fomfeedback,      // Level : Current Figure of Merit for Ras D.E.S Silicon Debug
    input  [NL*3-1:0]                         eqpa_violate_rule_123,            // Level : Rule A/B/C Violation Event Status for Ras D.E.S Silicon Debug
    input  [NL*2-1:0]                         eq_convergence_sts,               // Level : Equalization convergence information for Ras D.E.S Silicon Debug
    input  [NL*TX_COEF_WD-1:0]                mac_cdm_ras_des_coef_rtx,         // Level : Current Remote Transmitter coefficient for Ras D.E.S Silicon Debug
    input  [NL*RX_PSET_WD-1:0]                mac_cdm_ras_des_pset_lrx,         // Level : Current Local Receiver Preset for Ras D.E.S Silicon Debug
    input  [NL-1:0]                           mac_cdm_ras_des_reject_rtx,       // Level : Receive Reject Coefficient Event status for Ras D.E.S Silicon Debug
    input                                     init_eq_pending_g4,               // Level : Equalization sequence  for Ras D.E.S Silicon Debug
    input  [NL*TX_FS_WD-1:0]                  mac_cdm_ras_des_fs_g4,            // Level : Remote Device FS for Ras D.E.S Silicon Debug
    input  [NL*TX_FS_WD-1:0]                  mac_cdm_ras_des_lf_g4,            // Level : Remote Device LF for Ras D.E.S Silicon Debug
    input  [NL*TX_COEF_WD-1:0]                mac_cdm_ras_des_coef_ltx_g4,      // Level : Current Local Transmitter coefficient for Ras D.E.S Silicon Debug
    input  [NL*FOMFEEDBACK_WD-1:0]            phy_cdm_ras_des_fomfeedback_g4,   // Level : Current Figure of Merit for Ras D.E.S Silicon Debug
    input  [NL*3-1:0]                         eqpa_violate_rule_123_g4,         // Level : Rule A/B/C Violation Event Status for Ras D.E.S Silicon Debug
    input  [NL*2-1:0]                         eq_convergence_sts_g4,            // Level : Equalization convergence information for Ras D.E.S Silicon Debug
    input  [NL*TX_COEF_WD-1:0]                mac_cdm_ras_des_coef_rtx_g4,      // Level : Current Remote Transmitter coefficient for Ras D.E.S Silicon Debug
    input  [NL-1:0]                           mac_cdm_ras_des_reject_rtx_g4,    // Level : Receive Reject Coefficient Event status for Ras D.E.S Silicon Debug
    input                                     init_eq_pending_g5,               // Level : Equalization sequence  for Ras D.E.S Silicon Debug
    input  [NL*TX_FS_WD-1:0]                  mac_cdm_ras_des_fs_g5,            // Level : Remote Device FS for Ras D.E.S Silicon Debug
    input  [NL*TX_FS_WD-1:0]                  mac_cdm_ras_des_lf_g5,            // Level : Remote Device LF for Ras D.E.S Silicon Debug
    input  [NL*TX_COEF_WD-1:0]                mac_cdm_ras_des_coef_ltx_g5,      // Level : Current Local Transmitter coefficient for Ras D.E.S Silicon Debug
    input  [NL*FOMFEEDBACK_WD-1:0]            phy_cdm_ras_des_fomfeedback_g5,   // Level : Current Figure of Merit for Ras D.E.S Silicon Debug
    input  [NL*3-1:0]                         eqpa_violate_rule_123_g5,         // Level : Rule A/B/C Violation Event Status for Ras D.E.S Silicon Debug
    input  [NL*2-1:0]                         eq_convergence_sts_g5,            // Level : Equalization convergence information for Ras D.E.S Silicon Debug
    input  [NL*TX_COEF_WD-1:0]                mac_cdm_ras_des_coef_rtx_g5,      // Level : Current Remote Transmitter coefficient for Ras D.E.S Silicon Debug
    input  [NL-1:0]                           mac_cdm_ras_des_reject_rtx_g5,    // Level : Receive Reject Coefficient Event status for Ras D.E.S Silicon Debug
    input                                     init_eq_pending_g6,               // Level : Equalization sequence  for Ras D.E.S Silicon Debug
    input  [NL*TX_FS_WD-1:0]                  mac_cdm_ras_des_fs_g6,            // Level : Remote Device FS for Ras D.E.S Silicon Debug
    input  [NL*TX_FS_WD-1:0]                  mac_cdm_ras_des_lf_g6,            // Level : Remote Device LF for Ras D.E.S Silicon Debug
    input  [NL*TX_COEF_WD-1:0]                mac_cdm_ras_des_coef_ltx_g6,      // Level : Current Local Transmitter coefficient for Ras D.E.S Silicon Debug
    input  [NL*FOMFEEDBACK_WD-1:0]            phy_cdm_ras_des_fomfeedback_g6,   // Level : Current Figure of Merit for Ras D.E.S Silicon Debug
    input  [NL*3-1:0]                         eqpa_violate_rule_123_g6,         // Level : Rule A/B/C Violation Event Status for Ras D.E.S Silicon Debug
    input  [NL-1:0]                           eqpa_violate_rule_4_g6,           // Level : Rule D Violation Event Status for Ras D.E.S Silicon Debug
    input  [NL*2-1:0]                         eq_convergence_sts_g6,            // Level : Equalization convergence information for Ras D.E.S Silicon Debug
    input  [NL*TX_COEF_WD-1:0]                mac_cdm_ras_des_coef_rtx_g6,      // Level : Current Remote Transmitter coefficient for Ras D.E.S Silicon Debug
    input  [NL-1:0]                           mac_cdm_ras_des_reject_rtx_g6,    // Level : Receive Reject Coefficient Event status for Ras D.E.S Silicon Debug
 // --- Trace FIFO signals
    input  [1:0]                              rl0s_state,
    input  [2:0]                              mac_phy_rate, 
    input  [1:0]                              mac_phy_powerdown,
    input  [NL-1:0]                           mac_phy_txdetectrx_loopback,
    input  [NL-1:0]                           mac_phy_rxeqeval,
    input  [NL-1:0]                           phy_mac_phystatus, 
    input  [NL*DIRFEEDBACK_WD-1:0]            phy_mac_dirfeedback,
    input  [NL*FOMFEEDBACK_WD-1:0]            phy_mac_fomfeedback,
    input  [NL*TX_COEF_WD-1:0]                mac_phy_txdeemph,                 // tx coef for gen3 rate, tx deemphasis for gen1/2 rate
    input  [NL*16-1:0]                        smlh_rxos_type,
    input  [NL*8-1:0]                         smseq_mcs_sts,
    input  [NL*64-1:0]                        smseq_ts_debug_info,
 // --- Others
    input                                     upstream_port,                    // Device Type is upstream port
    input  [2:0]                              current_data_rate,                // 0=running at gen1 speeds, 1=running at gen2 speeds
    input  [1:0]                              app_ras_des_tba_ctrl,             // Time base analysis control
    input                                     pm_sel_aux_clk,
    input                                     aux_clk_active,
    input  [`CX_PL_AUX_CLK_FREQ_WD-1:0]       cfg_pl_aux_clk_freq,
    input                                     app_ras_des_sd_hold_ltssm,        // Silicon debug hold ltssm signal
input                                         cxl_rcrb_enable,
// -------------- Outputs ---------------
 // --- Register access signals
    output                                    rasdes_reg_ack,                   // RASDES Vendor Specific Cap Register acknowledge
    output [31:0]                             rasdes_reg_data,                  // RASDES Vendor Specific Cap Register Read Data
 //---- Debug info  -----------------------
    output reg [RASDES_EC_INFO_CM-1:0]        cdm_ras_des_ec_info_common,       // Event counter common debug info
    output [RASDES_EC_INFO_PL-1:0]            cdm_ras_des_ec_info_l0,           // Event counter lane0 debug info
    output [RASDES_EC_INFO_PL-1:0]            cdm_ras_des_ec_info_l1,           // Event counter lane1 debug info
    output [RASDES_EC_INFO_PL-1:0]            cdm_ras_des_ec_info_l2,           // Event counter lane2 debug info
    output [RASDES_EC_INFO_PL-1:0]            cdm_ras_des_ec_info_l3,           // Event counter lane3 debug info
    output [RASDES_EC_INFO_PL-1:0]            cdm_ras_des_ec_info_l4,           // Event counter lane4 debug info
    output [RASDES_EC_INFO_PL-1:0]            cdm_ras_des_ec_info_l5,           // Event counter lane5 debug info
    output [RASDES_EC_INFO_PL-1:0]            cdm_ras_des_ec_info_l6,           // Event counter lane6 debug info
    output [RASDES_EC_INFO_PL-1:0]            cdm_ras_des_ec_info_l7,           // Event counter lane7 debug info
    output reg [RASDES_SD_INFO_CM-1:0]        cdm_ras_des_sd_info_common,       // Silicon debug common debug info
    output [RASDES_SD_INFO_PL-1:0]            cdm_ras_des_sd_info_l0,           // Silicon debug lane0 debug info
    output [RASDES_SD_INFO_PL-1:0]            cdm_ras_des_sd_info_l1,           // Silicon debug lane1 debug info
    output [RASDES_SD_INFO_PL-1:0]            cdm_ras_des_sd_info_l2,           // Silicon debug lane2 debug info
    output [RASDES_SD_INFO_PL-1:0]            cdm_ras_des_sd_info_l3,           // Silicon debug lane3 debug info
    output [RASDES_SD_INFO_PL-1:0]            cdm_ras_des_sd_info_l4,           // Silicon debug lane4 debug info
    output [RASDES_SD_INFO_PL-1:0]            cdm_ras_des_sd_info_l5,           // Silicon debug lane5 debug info
    output [RASDES_SD_INFO_PL-1:0]            cdm_ras_des_sd_info_l6,           // Silicon debug lane6 debug info
    output [RASDES_SD_INFO_PL-1:0]            cdm_ras_des_sd_info_l7,           // Silicon debug lane7 debug info
    output [RASDES_SD_INFO_PV-1:0]            cdm_ras_des_sd_info_v0,           // Silicon debug vc0 debug info
    output reg [RASDES_TBA_INFO_CM-1:0]           cdm_ras_des_tba_info_common,      // Time based analysis common debug info

 //---- RAM I/F -----------------------
    output                                    cdm_ras_des_ec_ram_ena,           // RAS DES Event counter register RAM enable A
    output                                    cdm_ras_des_ec_ram_wea,           // RAS DES Event counter register RAM write enable B
    output [RASDES_EC_RAM_ADDR_WIDTH-1:0]     cdm_ras_des_ec_ram_addra,         // RAS DES Event counter register RAM address A
    output [RASDES_EC_RAM_DATA_WIDTH-1:0]     cdm_ras_des_ec_ram_datain,        // RAS DES Event counter register RAM data in
    output                                    cdm_ras_des_ec_ram_enb,           // RAS DES Event counter register RAM enable B
    output [RASDES_EC_RAM_ADDR_WIDTH-1:0]     cdm_ras_des_ec_ram_addrb,         // RAS DES Event counter register RAM address B
    output                                    cdm_ras_des_tba_ram_ena,          // RAS DES Time based analysis register RAM enable A
    output                                    cdm_ras_des_tba_ram_wea,          // RAS DES Time based analysis register RAM write enable B
    output [RASDES_TBA_RAM_ADDR_WIDTH-1:0]    cdm_ras_des_tba_ram_addra,        // RAS DES Time based analysis register RAM address A
    output [RASDES_TBA_RAM_DATA_WIDTH-1:0]    cdm_ras_des_tba_ram_datain,       // RAS DES Time based analysis register RAM data in
    output                                    cdm_ras_des_tba_ram_enb,          // RAS DES Time based analysis register RAM enable B
    output [RASDES_TBA_RAM_ADDR_WIDTH-1:0]    cdm_ras_des_tba_ram_addrb,        // RAS DES Time based analysis register RAM address B
 // --- Event counter signals
 // --- Time based Analysis signals
 // --- Error Injection signals
    output                                    cdm_ras_des_einj0_enable,         // Error injection 0 enable
    output [7:0]                              cdm_ras_des_einj0_count,          // Error injection 0 count
    output [3:0]                              cdm_ras_des_einj0_crc_type,       // Error injection 0 CRC type
    output [2:0]                              cdm_ras_des_einj0_ecrc_vc_sel,    // Error injection 0 ECRC Virtual Channel Selection
    output fc_type_e                          cdm_ras_des_einj0_ecrc_fc_sel,    // Error injection 0 ECRC Flow Control Selection
    output logic                              cdm_ras_des_einj0_ecrc_intf_sel,  // Error injection 0 ECRC Interface Selection
    output                                    cdm_ras_des_einj1_enable,         // Error injection 1 enable
    output                                    cdm_ras_des_einj1_seq_type,       // Error injection 1 seq# type
    output [12:0]                             cdm_ras_des_einj1_bad_seq,        // Error injection 1 bad seq# value
    output [7:0]                              cdm_ras_des_einj1_count,          // Error injection 1 count
    output                                    cdm_ras_des_einj2_enable,         // Error injection 2 enable
    output [1:0]                              cdm_ras_des_einj2_dllp_type,      // Error injection 2 DLLP type
    output                                    cdm_ras_des_einj3_enable,         // Error injection 3 8b/10b K-code mask enable
    output [7:0]                              cdm_ras_des_einj3_count,          // Error injection 3 8b/10b K-code mask count
    output [2:0]                              cdm_ras_des_einj3_smb_type,       // Error injection 3 8b/10b K-code mask type
    output                                    cdm_ras_des_einj4_enable,         // Error injection 4 enable
    output [2:0]                              cdm_ras_des_einj4_updfc_type,     // Error injection 4 UpdateFC type
    output [2:0]                              cdm_ras_des_einj4_vcnum,          // Error injection 4 VC number
    output [12:0]                             cdm_ras_des_einj4_badfc_value,    // Error injection 4 bad FC value
    output                                    cdm_ras_des_einj5_enable,         // Error injection 5 enable
    output [7:0]                              cdm_ras_des_einj5_count,          // Error injection 5 count
    output                                    cdm_ras_des_einj5_tlp_type,       // Error injection 5 tlp type (dup/nul)
    output                                    cdm_ras_des_einj6_enable,         // Error Injection 6 Enable
    output [31:0]                             cdm_ras_des_einj6_cmp_point_h0,   // Error Injection 6 header compare point byte0-3
    output [31:0]                             cdm_ras_des_einj6_cmp_point_h1,   // Error Injection 6 header compare point byte4-7
    output [31:0]                             cdm_ras_des_einj6_cmp_point_h2,   // Error Injection 6 header compare point byte8-11
    output [31:0]                             cdm_ras_des_einj6_cmp_point_h3,   // Error Injection 6 header compare point byte12-15
    output [31:0]                             cdm_ras_des_einj6_cmp_value_h0,   // Error Injection 6 header compare value byte0-3
    output [31:0]                             cdm_ras_des_einj6_cmp_value_h1,   // Error Injection 6 header compare value byte4-7
    output [31:0]                             cdm_ras_des_einj6_cmp_value_h2,   // Error Injection 6 header compare value byte8-11
    output [31:0]                             cdm_ras_des_einj6_cmp_value_h3,   // Error Injection 6 header compare value byte12-15
    output [31:0]                             cdm_ras_des_einj6_chg_point_h0,   // Error Injection 6 header change point byte0-3
    output [31:0]                             cdm_ras_des_einj6_chg_point_h1,   // Error Injection 6 header change point byte4-7
    output [31:0]                             cdm_ras_des_einj6_chg_point_h2,   // Error Injection 6 header change point byte8-11
    output [31:0]                             cdm_ras_des_einj6_chg_point_h3,   // Error Injection 6 header change point byte12-15
    output [31:0]                             cdm_ras_des_einj6_chg_value_h0,   // Error Injection 6 header change value byte0-3
    output [31:0]                             cdm_ras_des_einj6_chg_value_h1,   // Error Injection 6 header change value byte4-7
    output [31:0]                             cdm_ras_des_einj6_chg_value_h2,   // Error Injection 6 header change value byte8-11
    output [31:0]                             cdm_ras_des_einj6_chg_value_h3,   // Error Injection 6 header change value byte12-15
    output [7:0]                              cdm_ras_des_einj6_count,          // Error Injection 6 count
    output                                    cdm_ras_des_einj6_invt_cont,      // Error Injection 6 inversion control
    output [2:0]                              cdm_ras_des_einj6_pkt_type,       // Error Injection 6 packet type
 // --- Silcon debug signals
    output [1:0]                              cdm_ras_des_pm_entry_interval,    // Low Power Entry Interval Time for Ras D.E.S Silicon Debug
    output [1:0]                              cdm_ras_des_eidle_cnt_sel,        // Number of Transmit E-IDLE ordered set for Ras D.E.S Silicon Debug
    output                                    cdm_ras_des_ltssm_stop,           // Hold/Release LTSSM for Ras D.E.S Silicon Debug
    output                                    cdm_ras_des_recovery_req,         // Recovery Request for Ras D.E.S Silicon Debug
    output                                    cdm_ras_des_ferr_rec_dis,         // Disable Recovery state transition at Framing Error for Ras D.E.S Silicon Debug
    output                                    cdm_ras_des_direct_rcvry_idle_to_cfg, // Direct LTSSM from Recovery.Idle to Configuration for Ras D.E.S Silicon Debug
    output                                    cdm_ras_des_direct_poll_cmp_to_det, // Direct LTSSM from Polling.Compliance to Detect for Ras D.E.S Silicon Debug
    output                                    cdm_ras_des_direct_lpbk_slave_to_exit, // Direct LTSSM from Loopback(Slave) to Exit for Ras D.E.S Silicon Debug
    output                                    cdm_ras_des_force_rxdetected_en,  // Force Detect Lane Num enable for Ras D.E.S Silicon Debug
    output [15:0]                             cdm_ras_des_force_rxdetected,     // Force Detect Lane Num for Ras D.E.S Silicon Debug
    output                                    cdm_ras_des_force_linkdown_noack  // Force Link down when MAC does not receive ACK DLLP for long time
    ,
    output [1:0]                              cdm_ras_des_ext_eq_to_factor,     // Extend the eq 24/32ms timeout x2/x10
    output                                    cdm_ras_des_eq_fom_target_en,     // FOM target enable for  Ras D.E.S Silicon Debug EQ Control
    output [NL-1:0]                           cdm_ras_des_eq_force_coef_rtx_en, // Force Remote Tx Cursor Coefficient Enable for  Ras D.E.S Silicon Debug EQ Control
    output [NL-1:0]                           cdm_ras_des_eq_force_pset_lrx_en, // Force Local Rx Preset Hint Enable for  Ras D.E.S Silicon Debug EQ Control
    output [NL-1:0]                           cdm_ras_des_eq_force_coef_ltx_en, // Force local Tx Cursor Coefficient Enable for Ras D.E.S Silicon Debug EQ Control
    output [NL*TX_COEF_WD-1:0]                cdm_ras_des_eq_force_coef_ltx,    // Force Local Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
    output [NL*RX_PSET_WD-1:0]                cdm_ras_des_eq_force_pset_lrx,    // Force Local Receiver Preset Hint for Ras D.E.S Silicon Debug EQ Control
    output [NL*TX_COEF_WD-1:0]                cdm_ras_des_eq_force_coef_rtx,    // Force Remote Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
    output [NL-1:0]                           cdm_ras_des_eq_force_pset_ltx_en, // Force Local Tx Preset Enable for  Ras D.E.S Silicon Debug EQ Control
    output [NL*TX_PSET_WD-1:0]                cdm_ras_des_eq_force_usp_pset_ltx  // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control
    ,
    output [NL-1:0]                           cdm_ras_des_eq_force_coef_rtx_en_g4, // Force Remote Tx Cursor Coefficient Enable for  Ras D.E.S Silicon Debug EQ Control
    output [NL-1:0]                           cdm_ras_des_eq_force_coef_ltx_en_g4, // Force local Tx Cursor Coefficient Enable for Ras D.E.S Silicon Debug EQ Control
    output [NL*TX_COEF_WD-1:0]                cdm_ras_des_eq_force_coef_ltx_g4, // Force Local Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
    output [NL*TX_COEF_WD-1:0]                cdm_ras_des_eq_force_coef_rtx_g4, // Force Remote Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
    output [NL-1:0]                           cdm_ras_des_eq_force_pset_ltx_en_g4, // Force Local Tx Preset Enable for  Ras D.E.S Silicon Debug EQ Control
    output [NL*TX_PSET_WD-1:0]                cdm_ras_des_eq_force_usp_pset_ltx_g4  // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control
    ,
    output [NL-1:0]                           cdm_ras_des_eq_force_coef_rtx_en_g5, // Force Remote Tx Cursor Coefficient Enable for  Ras D.E.S Silicon Debug EQ Control
    output [NL-1:0]                           cdm_ras_des_eq_force_coef_ltx_en_g5, // Force local Tx Cursor Coefficient Enable for Ras D.E.S Silicon Debug EQ Control
    output [NL*TX_COEF_WD-1:0]                cdm_ras_des_eq_force_coef_ltx_g5, // Force Local Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
    output [NL*TX_COEF_WD-1:0]                cdm_ras_des_eq_force_coef_rtx_g5, // Force Remote Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
    output [NL-1:0]                           cdm_ras_des_eq_force_pset_ltx_en_g5, // Force Local Tx Preset Enable for  Ras D.E.S Silicon Debug EQ Control
    output [NL*TX_PSET_WD-1:0]                cdm_ras_des_eq_force_usp_pset_ltx_g5  // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control
    ,
    output [NL-1:0]                           cdm_ras_des_eq_force_coef_rtx_en_g6, // Force Remote Tx Cursor Coefficient Enable for  Ras D.E.S Silicon Debug EQ Control
    output [NL-1:0]                           cdm_ras_des_eq_force_coef_ltx_en_g6, // Force local Tx Cursor Coefficient Enable for Ras D.E.S Silicon Debug EQ Control
    output [NL*TX_COEF_WD-1:0]                cdm_ras_des_eq_force_coef_ltx_g6,    // Force Local Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
    output [NL*TX_COEF_WD-1:0]                cdm_ras_des_eq_force_coef_rtx_g6,    // Force Remote Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
    output [NL-1:0]                           cdm_ras_des_eq_force_pset_ltx_en_g6, // Force Local Tx Preset Enable for  Ras D.E.S Silicon Debug EQ Control
    output [NL*TX_PSET_WD-1:0]                cdm_ras_des_eq_force_usp_pset_ltx_g6 // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control
    ,
    output [FOMFEEDBACK_WD-1:0]               cdm_ras_des_eq_fom_target,        // FOM Target value for Ras D.E.S Silicon Debug EQ Control
    output [1:0]                              cdm_ras_des_eq_eval_interval      // EVAL Interval Time for Ras D.E.S Silicon Debug EQ Control
 // --- Trace FIFO signals
) ;
    wire   [31:0]                             cdm_reg_wdata;
    wire   [3:0]                              cdm_reg_write_pulse;
    wire   [63:0]                             cdm_reg_id;
    wire   [1:0]                              cdm_ec_ack;
    wire   [31:0]                             cdm_ec_rdata;
    wire   [1:0]                              cdm_ei_ack;
    wire   [31:0]                             cdm_ei_rdata;
    wire   [1:0]                              cdm_sd_ack;
    wire   [31:0]                             cdm_sd_rdata;
    wire   [1:0]                              cdm_tba_ack;
    wire   [31:0]                             cdm_tba_rdata;
    wire   [1:0]                              cdm_tf_ack;
    wire   [31:0]                             cdm_tf_rdata;
    //---- RAM I/F -----------------------
    wire   [RASDES_EC_RAM_DATA_WIDTH-1:0]     ec_ram_dataout;
    wire                                      ec_ram_ena;
    wire                                      ec_ram_wea;
    wire   [RASDES_EC_RAM_ADDR_WIDTH-1:0]     ec_ram_addra;
    wire   [RASDES_EC_RAM_DATA_WIDTH-1:0]     ec_ram_datain;
    wire                                      ec_ram_enb;
    wire   [RASDES_EC_RAM_ADDR_WIDTH-1:0]     ec_ram_addrb;
    wire   [RASDES_TBA_RAM_DATA_WIDTH-1:0]    tba_ram_dataout;
    wire                                      tba_ram_ena;
    wire                                      tba_ram_wea;
    wire   [RASDES_TBA_RAM_ADDR_WIDTH-1:0]    tba_ram_addra;
    wire   [RASDES_TBA_RAM_DATA_WIDTH-1:0]    tba_ram_datain;
    wire                                      tba_ram_enb;
    wire   [RASDES_TBA_RAM_ADDR_WIDTH-1:0]    tba_ram_addrb;

    genvar                                    ln;
    genvar                                    vc;

  parameter                                 INT_RX_TLP=4 ;
  parameter                                 INT_RX_NDLLP=8 ;

  parameter                                 XADM_NP_MAX=2;
  parameter                                 XADM_IF_MAX=6;
  parameter                                 XADM_P_MAX=2;
  parameter                                 XADM_CPL_MAX=2;
  parameter                                 CCIX_IF_MAX=2;

  struct packed {
    logic                       info_cxl_vlsm_lrsm_req_retrain_pulse;   // [191] : Pulse: (CXL only) NUM_RETRY reached MAX_NUM_RETRY (L0 to Recovery transition trigger)
    logic                       info_cxl_vlsm_unexp_error;      // [190] : Pulse: (CXL only) unexpected ALMP error (L0 to Recovery transition trigger)
    logic                       info_cxl_almp_rx_repl_error;    // [189] : Pulse: (CXL only) ALMP Replication error (L0 to Recovery transition trigger)
    logic                       smlh_deskew_uncomplete_err;     // [188] : Pulse: Deskew uncompleted error (L0 to Recovery transition trigger)
    logic                       info_rmlh_framing_err_l0;       // [187] : Pulse: Framing Error in L0 state (L0 to Recovery transition trigger)
    logic                       smlh_rcv_eios_when_l0s_unsprt;  // [186] : Pulse: Received EIOS when L0s is not supported and not directed L1 or L2. (L0 to Recovery transition trigger)
    logic   [INT_RX_TLP-1:0]    int_rtlh_rx_defmemwr_evt;       // [185:182]: Pulse: Rx Deferrable Memory Write
    logic   [XADM_NP_MAX-1:0]   int_xtlh_tx_defmemwr_evt;       // [181:180]: Pulse: Tx Deferrable Memory Write 
    logic   [INT_RX_TLP-1:0]    int_rtlh_rx_ccix_tlp_evt;       // [179:176]: Pulse: Rx CCIX TLP 
    logic   [CCIX_IF_MAX-1:0]   int_xtlh_tx_ccix_tlp_evt;       // [175:174]: Pulse: Tx CCIX TLP
    logic   [INT_RX_TLP-1:0]    int_rtlh_rx_tlpwprefix_evt;    // [173:170]: Pulse: Rx TLP with Prefix
    logic   [INT_RX_TLP-1:0]    int_rtlh_rx_atmcop_evt;        // [169:166]: Pulse: Rx Atomic
    logic   [INT_RX_TLP-1:0]    int_rtlh_rx_msg_evt;            // [165:162]: Pulse: Rx Message TLP
    logic   [INT_RX_TLP-1:0]    int_rtlh_rx_cplwd_evt;          // [161:158]: Pulse: Rx Completion w data
    logic   [INT_RX_TLP-1:0]    int_rtlh_rx_cplwod_evt;         // [157:154]: Pulse: Rx Completion wo data
    logic   [INT_RX_TLP-1:0]    int_rtlh_rx_iord_evt;           // [153:150]: Pulse: Rx IO Read
    logic   [INT_RX_TLP-1:0]    int_rtlh_rx_iowr_evt;           // [149:146]: Pulse: Rx IO Write
    logic   [INT_RX_TLP-1:0]    int_rtlh_rx_cfgrd_evt;          // [145:142]: Pulse: Rx Config Read
    logic   [INT_RX_TLP-1:0]    int_rtlh_rx_cfgwr_evt;          // [141:138]: Pulse: Rx Config Write
    logic   [INT_RX_TLP-1:0]    int_rtlh_rx_memrd_evt;          // [137:134]: Pulse: Rx Memory Read
    logic   [INT_RX_TLP-1:0]    int_rtlh_rx_memwr_evt;          // [123:130]: Pulse: Rx Memory Write
    logic   [XADM_IF_MAX-1:0]   int_xtlh_tx_tlpwprefix_evt;    // [129:124]: Pulse: Tx TLP with Prefix
    logic   [XADM_NP_MAX-1:0]   int_xtlh_tx_atmcop_evt;        // [123:122]: Pulse: Tx AtomicOP TLP
    logic   [XADM_P_MAX-1:0]    int_xtlh_tx_msg_evt;                // [121:120]: Pulse: Tx Message TLP
    logic   [XADM_CPL_MAX-1:0]  int_xtlh_tx_cplwd_evt;              // [119:118]: Pulse: Tx Completion w data
    logic   [XADM_CPL_MAX-1:0]  int_xtlh_tx_cplwod_evt;             // [117:116]: Pulse: Tx Completion wo data
    logic   [XADM_NP_MAX-1:0]   int_xtlh_tx_iord_evt;               // [115:114]: Pulse: Tx IO Read
    logic   [XADM_NP_MAX-1:0]   int_xtlh_tx_iowr_evt;               // [113:112]: Pulse: Tx IO Write
    logic   [XADM_NP_MAX-1:0]   int_xtlh_tx_cfgrd_evt;              // [111:110]: Pulse: Tx Config Read
    logic   [XADM_NP_MAX-1:0]   int_xtlh_tx_cfgwr_evt;              // [109:108]: Pulse: Tx Config Write
    logic   [XADM_NP_MAX-1:0]   int_xtlh_tx_memrd_evt;              // [107:106]: Pulse: Tx Memory Read
    logic   [XADM_P_MAX-1:0]    int_xtlh_tx_memwr_evt;              // [105:104]: Pulse: Tx Memory Write
    logic   [INT_RX_TLP-1:0]    int_rdlh_duplicate_tlp_err_pertlp; // [103:100]: Pulse: Rx Duplicate TLP
    logic   [XADM_IF_MAX-1:0]    int_xadm_tx_nullify_evt;                // [99:94]: Pulse: Tx Nullified TLP
    logic   [INT_RX_TLP-1:0]    int_rdlh_nulified_tlp_err_pertlp;   // [93:90]: Pulse: Rx Nullified TLP
    logic   [INT_RX_NDLLP-1:0]  int_rtlh_rcvd_ufc_perdllp;          // [89:82]: Pulse: Rx Update FC DLLP
    logic   [INT_RX_NDLLP-1:0]  int_rdlh_rcvd_ack_perdllp;          // [81:74]: Pulse: Rx Ack DLLP
    logic   [TX_NDLLP-1:0]      xdlh_update_fc_sent;                // [73]: Pulse: Tx Update FC DLLP
    logic                       xdlh_ack_sent;                      // [72]: Pulse: Tx Ack DLLP
    logic                       smlh_lwd_change;                    // [71]: Pulse: Link width Change
    logic                       info_smlh_spd_change;               // [70]: Pulse: Speed Change
    logic                       smlh_in_l23;                        // [69]: Level: L2 Entry
    logic                       info_pm_in_l1_abort;                // [68]: Level: L1.2 abort
    logic                       info_pm_in_l1_cpm;                  // [67]: Level: L1 Clock PM (L1 with REFCLK removal/PLL Off)
    logic                       info_pm_in_l1_short;                // [66]: Level: L1 short duration
    logic                       info_pm_in_l12;                     // [65]: Level: L1.2 Entry
    logic                       info_pm_in_l11;                     // [64]: Level: L1.1 Entry
    logic                       smlh_in_l1;                         // [63]: Level: L1 Entry
    logic                       pm_asnak;                           // [62]: Level: ASPM L1 reject
    logic                       smlh_in_rl0s;                       // [61]: Level: Rx L0s Entry
    logic                       smlh_in_l0s;                        // [60]: Level: Tx L0s Entry
    logic                       smlh_l1_to_recovery;                // [59]: Pulse: L1 to Recovery Entry
    logic                       smlh_l0_to_recovery;                // [58]: Pulse: L0 to Recovery Entry
    logic  [1:0]                cfg_cpl_timeout;                    // [57:56]: Pulse: Completion Timeout
    logic  [INT_RX_TLP-1:0]     int_cfg_ca_tlp;                     // [55:52]: Pulse: Completer Abort
    logic  [INT_RX_TLP-1:0]     int_cfg_ur_tlp;                     // [51:48]: Pulse: Unsupported Request
    logic  [INT_RX_TLP-1:0]     int_cfg_ecrc_tlp_err;               // [47:44]: Pulse: ECRC Error
    logic  [INT_RX_TLP-1:0]     int_cfg_poisned_tlp;                // [43:40]: Pulse: Poisoned TLP
    logic                       rtlh_req_link_retrain_pulse;        // [39]: Pulse: FC Timeout
    logic                       xdlh_retry_req;                     // [38]: Pulse: Retry TLP
    logic                       xdlh_nak_sent;                      // [37]: Pulse: Tx Nak DLLP
    logic  [INT_RX_NDLLP-1:0]   int_rdlh_rcvd_nack_perdllp;         // [36:29]: Pulse: Rx Nak DLLP
    logic                       xdlh_replay_timeout_err;            // [28]: Pulse: Replay Timeout
    logic                       xdlh_replay_num_rlover_err;         // [27]: Pulse: Replay_Num Rollover
    logic  [INT_RX_NDLLP-1:0]   int_rdlh_bad_dllp_err_perdllp;      // [26:19]: Pulse: BAD DLLP
    logic  [INT_RX_TLP-1:0]     int_rdlh_lcrc_tlp_err_pertlp;       // [18:15]: Pulse: LCRC Error
    logic  [INT_RX_TLP-1:0]     int_rdlh_bad_tlp_err_pertlp;        // [14:11]: Pulse: BAD TLP
    logic                       rmlh_deskew_alignment_err;          // [10]: Pulse: Deskew Error
    logic                       info_rmlh_framing_err;              // [9]: Pulse: Framing Error
    logic                       smlh_timeout_nfts;                  // [8]: Level: FTS Timeout
    logic                       smlh_rx_rcvry_req;                  // [7]: Level: Rx Recovery Request
    logic                       rmlh_rcvd_err;                      // [6]: Pulse: Receiver Error
    logic                       smlh_eidle_inferred_in_l0;          // [5]: Level: Detect EI Infer
    logic   [4:0]               info_rpa_rx_rrap_sts;               // [4]: Pulse: RRAP Address Error
                                                                    // [3]: Pulse: RRAP unexpected response
                                                                    // [2]: Pulse: RRAP Parity Error
                                                                    // [1]: Pulse: RRAP Abort
                                                                    // [0]: Pulse: RRAP Timeout
  } rasdes_ec_info_cmn_s, rasdes_ec_info_cmn;

  assign rasdes_ec_info_cmn_s.smlh_deskew_uncomplete_err = smlh_deskew_uncomplete_err;
  assign rasdes_ec_info_cmn_s.smlh_rcv_eios_when_l0s_unsprt = smlh_rcv_eios_when_l0s_unsprt;
  assign rasdes_ec_info_cmn_s.xdlh_update_fc_sent = xdlh_update_fc_sent;
  assign rasdes_ec_info_cmn_s.xdlh_ack_sent = xdlh_ack_sent;
  assign rasdes_ec_info_cmn_s.smlh_lwd_change = smlh_lwd_change;
  assign rasdes_ec_info_cmn_s.smlh_in_l23 = smlh_in_l23;
  assign rasdes_ec_info_cmn_s.smlh_in_l1 = smlh_in_l1;
  assign rasdes_ec_info_cmn_s.pm_asnak = pm_asnak;
  assign rasdes_ec_info_cmn_s.smlh_in_rl0s = smlh_in_rl0s;
  assign rasdes_ec_info_cmn_s.smlh_in_l0s = smlh_in_l0s;
  assign rasdes_ec_info_cmn_s.smlh_l1_to_recovery = smlh_l1_to_recovery;
  assign rasdes_ec_info_cmn_s.smlh_l0_to_recovery = smlh_l0_to_recovery;
  assign rasdes_ec_info_cmn_s.cfg_cpl_timeout = cfg_cpl_timeout;
  assign rasdes_ec_info_cmn_s.xdlh_retry_req = xdlh_retry_req;
  assign rasdes_ec_info_cmn_s.xdlh_nak_sent = xdlh_nak_sent;
  assign rasdes_ec_info_cmn_s.xdlh_replay_timeout_err = xdlh_replay_timeout_err;
  assign rasdes_ec_info_cmn_s.xdlh_replay_num_rlover_err = xdlh_replay_num_rlover_err;
  assign rasdes_ec_info_cmn_s.rmlh_deskew_alignment_err = rmlh_deskew_alignment_err;
  assign rasdes_ec_info_cmn_s.smlh_timeout_nfts = smlh_timeout_nfts;
  assign rasdes_ec_info_cmn_s.smlh_rx_rcvry_req = smlh_rx_rcvry_req;
  assign rasdes_ec_info_cmn_s.rmlh_rcvd_err = rmlh_rcvd_err;
  assign rasdes_ec_info_cmn_s.smlh_eidle_inferred_in_l0 = smlh_eidle_inferred_in_l0;

  delay_n
   #(
     .N   (1)
    ,.WD ($bits(rasdes_ec_info_cmn_s))
    ,.RESETVAL ('0)
  ) u_delay_n_ec_info_cmn (
    // ------------- input -----------------
     .clk   (aux_clk)
    ,.rst_n (sticky_rst_n)
    ,.clear (1'b0)
    ,.din   (rasdes_ec_info_cmn_s)
    // ------------- output ----------------
    ,.dout  (rasdes_ec_info_cmn)
  );

  // cdm_ras_des_info_common
  struct packed {
    logic                               init_eq_pending_g6;                 // [91]: Level : Equalization sequence  for Ras D.E.S Silicon Debug
    usp_prot_fsm_state_e                pm_usp_prot_state;                  // [90:87]: Level: PM Internal State (USP Protocol FSM State)
    usp_link_fsm_state_e                pm_usp_link_state;                  // [86:83]: Level: PM Internal State (DSP Link FSM State)
    pm_active_l0s_fsm_e                 pm_l0s_state;                       // [82:80]: Level: PM Internal State (L0S FSM State)
    logic                               info_orig_pipe_blockaligncontrol;   // [79]: Level: Origial PIPE BlockAlignControl
    logic                               info_init_eq_pending_g5;            // [78]: Level: Equalization sequence Gen5
    logic   [2:0]                       info_l1sub_state;                   // [77:75] Level: L1 sub state
    logic                               info_init_eq_pending_g4;            // [74]: Level: Equalization sequence Gen4
    logic                               info_init_eq_pending;               // [73]: Level: Equalization sequence Gen3
    logic  [11:0]                       xdlh_xplh_curnt_seqnum;             // [72:61]: Level: Tx TLP SEQ#
    logic  [11:0]                       rdlh_xplh_curnt_rx_ack_seqnum;      // [60:49]: Level: Rx ACK SEQ#
    logic                               rdlh_vc0_initfc2_status;            // [48]: Level: Init-FC Flag2 VC0
    logic                               rdlh_vc0_initfc1_status;            // [47]: Level: Init-FC Flag1 VC0
    logic  [1:0]                        rdlh_dlcntrl_state;                 // [46:45]: Level: DLCM
    logic  [7:0]                        latched_ts_nfts;                    // [44:37]: Level: Latched NFTS
    // 1'b0,                                                                // [36] : Reserved for Power Down[2]
    logic  [1:0]                        ltssm_powerdown;                    // [35:34]: Level: PIPE: Power Down
    logic  [15:0]                       smlh_ltssm_variable;                // [33:18]: Level: LTSSM Variable
    logic                               pm_pme_resend_flag;                 // [17]: Pulse: PME Re-Send flag
    logic                               smlh_lane_reversed;                 // [16]: Level: Lane Reversal Operation
    logic  [6:0]                        info_rmlh_framing_err_ptr;          // [15:9]: Pulse: 1st Framing Error Pointer
    // 1'b0,                                                                // [8] : Reserved for Power Down
    dsp_prot_fsm_state_e                pm_dsp_prot_state;                  // [7:4]: Level: PM Internal State (DSP Protocol FSM State)
    dsp_link_fsm_state_e                pm_dsp_link_state;                  // [3:0]: Level: PM Internal State (DSP Link FSM State)
  } rasdes_sd_info_cmn_s, rasdes_sd_info_cmn;

  assign rasdes_sd_info_cmn_s.pm_usp_prot_state = pm_usp_prot_state;
  assign rasdes_sd_info_cmn_s.pm_usp_link_state = pm_usp_link_state;
  assign rasdes_sd_info_cmn_s.pm_l0s_state      = pm_l0s_state;
  assign rasdes_sd_info_cmn_s.init_eq_pending_g6= init_eq_pending_g6;
  assign rasdes_sd_info_cmn_s.xdlh_xplh_curnt_seqnum = xdlh_xplh_curnt_seqnum;
  assign rasdes_sd_info_cmn_s.rdlh_xplh_curnt_rx_ack_seqnum = rdlh_xplh_curnt_rx_ack_seqnum;
  assign rasdes_sd_info_cmn_s.rdlh_vc0_initfc2_status = rdlh_vc0_initfc2_status;
  assign rasdes_sd_info_cmn_s.rdlh_vc0_initfc1_status = rdlh_vc0_initfc1_status;
  assign rasdes_sd_info_cmn_s.rdlh_dlcntrl_state = rdlh_dlcntrl_state;
  assign rasdes_sd_info_cmn_s.latched_ts_nfts = latched_ts_nfts;
  assign rasdes_sd_info_cmn_s.ltssm_powerdown = ltssm_powerdown;
  assign rasdes_sd_info_cmn_s.smlh_ltssm_variable = smlh_ltssm_variable;
  assign rasdes_sd_info_cmn_s.pm_pme_resend_flag = pm_pme_resend_flag;
  assign rasdes_sd_info_cmn_s.smlh_lane_reversed = smlh_lane_reversed;
  assign rasdes_sd_info_cmn_s.pm_dsp_prot_state = pm_dsp_prot_state;
  assign rasdes_sd_info_cmn_s.pm_dsp_link_state = pm_dsp_link_state;

wire [(`CX_NL - 1) : 0]          int_mac_phy_txelec_txburst;
generate for (genvar lane=0; lane<`CX_NL; lane = lane+1) begin : int_mac_phy_txelec_txburst_GEN
    assign int_mac_phy_txelec_txburst[lane] = &mac_phy_txelec_txburst_i[lane*4 +: 4];
  end
endgenerate // int_mac_phy_txelec_txburst_GEN
wire [(`CX_NL - 1) : 0]          mac_phy_txelec_txburst = int_mac_phy_txelec_txburst;

  delay_n
   #(
     .N   (1)
    ,.WD ($bits(rasdes_sd_info_cmn_s))
    ,.RESETVAL ('0)
  ) u_delay_n_sd_info_cmn (
    // ------------- input -----------------
     .clk   (aux_clk)
    ,.rst_n (sticky_rst_n)
    ,.clear (1'b0)
    ,.din   (rasdes_sd_info_cmn_s)
    // ------------- output ----------------
    ,.dout  (rasdes_sd_info_cmn)
  );

  // cdm_rasdes_sd_info_l<N>
  struct packed {
    logic   [(NL*PHY_NB)-1:0]           orig_pipe_rxdatak;                      // [N4:N3+1](N4 = N3 + PHY_NB): Level: Origial PIPE RxDataK
    logic   [(NL*PHY_NB*8)-1:0]         orig_pipe_rxdata;                       // [N3:N2+1](N3 = N2 + (PHY_NB * 8)): Level: Origial PIPE RxData
    logic   [(NL*PHY_RXSH_WD)-1:0]      info_orig_pipe_rxsyncheader;            // [N2:N1+1](N2 = N1 + PHY_RXSH_WD): Level: Origial PIPE RxSyncHeader
    logic   [(NL*PHY_RXSB_WD)-1:0]      info_orig_pipe_rxstartblock;            // [N1:N0+4](N1 = N0 + 4 + PHY_RXSB_WD): Level: Origial PIPE RxStartBlock
    logic   [NL-1:0]                    orig_pipe_rxdatavalid;                  // [N0+3]: Level: Origial PIPE RxDataValid
    logic   [(NL*3)-1:0]                orig_pipe_rxstatus;                     // [N0+2:N0](N0 = CX_GEN6_SPEED ? 268 : 205): pulse : Origial PIPE RxStatus
    logic  [NL*2-1:0]                   eq_convergence_sts_g6;                  // [267:266]:Level : Equalization convergence information for Ras D.E.S Silicon Debug
    logic  [NL-1:0]                     eqpa_violate_rule_4_g6;                 // [265]:Level : Rule D Violation Event Status for Ras D.E.S Silicon Debug
    logic  [NL*3-1:0]                   eqpa_violate_rule_123_g6;               // [264]:Level : Rule A/B/C Violation Event Status for Ras D.E.S Silicon Debug
                                                                                // [263]: Level: Rule B Violation Event Status Gen6
                                                                                // [262]: Level: Rule A Violation Event Status Gen6
    logic  [NL-1:0]                     mac_cdm_ras_des_reject_rtx_g6;          // [261]: Level : Receive Reject Coefficient Event status for Ras D.E.S Silicon Debug
    logic  [NL*FOMFEEDBACK_WD-1:0]      phy_cdm_ras_des_fomfeedback_g6;         // [260:253]: Level : Current Figure of Merit for Ras D.E.S Silicon Debug
    logic  [NL*TX_COEF_WD-1:0]          mac_cdm_ras_des_coef_ltx_g6;            // [252:250] Level : Current Local Transmitter coefficient for Ras D.E.S Silicon Debug
                                                                                // [252:250]: Level: Current Local Transmitter 2nd Pre Cursor coefficient Gen6
                                                                                // [249:246]: Level: Current Local Transmitter Pre Cursor coefficient Gen6
                                                                                // [245:240]: Level: Current Local Transmitter Cursor coefficient Gen6
                                                                                // [239:235]: Level: Current Local Transmitter Post Cursor coefficient Gen6
    logic  [NL*TX_COEF_WD-1:0]          mac_cdm_ras_des_coef_rtx_g6;            // [234:232] : Current Remote Transmitter coefficient for Ras D.E.S Silicon Debug
                                                                              // [231:228]: Level: Current Remote Transmitter Pre Cursor coefficient Gen6
                                                                              // [227:222]: Level: Current Remote Transmitter Cursor coefficient Gen6
                                                                              // [221:217]: Level: Current Remote Transmitter Post Cursor coefficient Gen6
    logic  [NL*TX_FS_WD-1:0]            mac_cdm_ras_des_lf_g6;                  // [216:211]:Level : Remote Device LF for Ras D.E.S Silicon Debug
    logic  [NL*TX_FS_WD-1:0]            mac_cdm_ras_des_fs_g6;                  // [210:205]:Level : Remote Device FS for Ras D.E.S Silicon Debug
    logic   [NL*2-1:0]                  info_eq_convergence_sts_g5;             // [204:203]: Level: Equalization convergence information Gen5
    logic   [NL*3-1:0]                  info_eqpa_violate_rule_123_g5;          // [202]: Level: Rule C Violation Event Status Gen5
                                                                                // [201]: Level: Rule B Violation Event Status Gen5
                                                                                // [200]: Level: Rule A Violation Event Status Gen5
    logic   [NL-1:0]                    info_mac_cdm_ras_des_reject_rtx_g5;     // [199]: Level: Receive Reject Coefficient Event status Gen5
    logic   [NL*FOMFEEDBACK_WD-1:0]     info_phy_cdm_ras_des_fomfeedback_g5;    // [198:191]: Level: Current Figure of Merit Gen5
    logic   [NL*TX_COEF_WD-1:0]         info_mac_cdm_ras_des_coef_ltx_g5;       // [190:185]: Level: Current Local Transmitter Pre Cursor coefficient Gen5
                                                                                // [184:179]: Level: Current Local Transmitter Cursor coefficient Gen5
                                                                                // [178:173]: Level: Current Local Transmitter Post Cursor coefficient Gen5
    logic   [NL*TX_COEF_WD-1:0]         info_mac_cdm_ras_des_coef_rtx_g5;       // [172:167]: Level: Current Remote Transmitter Pre Cursor coefficient Gen5
                                                                                // [166:161]: Level: Current Remote Transmitter Cursor coefficient Gen5
                                                                                // [160:155]: Level: Current Remote Transmitter Post Cursor coefficient Gen5
    logic   [NL*TX_FS_WD-1:0]           info_mac_cdm_ras_des_lf_g5;             // [154:149]: Level: Remote Device LF Gen5
    logic   [NL*TX_FS_WD-1:0]           info_mac_cdm_ras_des_fs_g5;             // [148:143]: Level: Remote Device FS Gen5
    logic   [NL*2-1:0]                  info_eq_convergence_sts_g4;             // [142:141]: Level: Equalization convergence information Gen4
    logic   [NL*3-1:0]                  info_eqpa_violate_rule_123_g4;          // [140]: Level: Rule C Violation Event Status Gen4
                                                                                // [139]: Level: Rule B Violation Event Status Gen4
                                                                                // [138]: Level: Rule A Violation Event Status Gen4
    logic   [NL-1:0]                    info_mac_cdm_ras_des_reject_rtx_g4;     // [137]: Level: Receive Reject Coefficient Event status Gen4
    logic   [NL*FOMFEEDBACK_WD-1:0]     info_phy_cdm_ras_des_fomfeedback_g4;    // [136:129]: Level: Current Figure of Merit Gen4
    // 3'b000,                                                                  // [128:126]: 3'b000: Reserved
    logic   [NL*TX_COEF_WD-1:0]         info_mac_cdm_ras_des_coef_ltx_g4;       // [125:120]: Level: Current Local Transmitter Pre Cursor coefficient Gen4
                                                                                // [119:114]: Level: Current Local Transmitter Cursor coefficient Gen4
                                                                                // [113:108]: Level: Current Local Transmitter Post Cursor coefficient Gen4
    logic   [NL*TX_COEF_WD-1:0]         info_mac_cdm_ras_des_coef_rtx_g4;       // [107:102]: Level: Current Remote Transmitter Pre Cursor coefficient Gen4
                                                                                // [101:96]: Level: Current Remote Transmitter Cursor coefficient Gen4
                                                                                // [95:90]: Level: Current Remote Transmitter Post Cursor coefficient Gen4
    logic   [NL*TX_FS_WD-1:0]           info_mac_cdm_ras_des_lf_g4;             // [89:84]: Level: Remote Device LF Gen4
    logic   [NL*TX_FS_WD-1:0]           info_mac_cdm_ras_des_fs_g4;             // [83:78]: Level: Remote Device FS Gen4
    logic   [NL*2-1:0]                  info_eq_convergence_sts;                // [77:76]: Level: Equalization convergence information Gen3
    logic   [NL*3-1:0]                  info_eqpa_violate_rule_123;             // [75]: Level: Rule C Violation Event Status Gen3
                                                                                // [74]: Level: Rule B Violation Event Status Gen3
                                                                                // [73]: Level: Rule A Violation Event Status Gen3
    logic   [NL-1:0]                    info_mac_cdm_ras_des_reject_rtx;        // [72]: Level: Receive Reject Coefficient Event status Gen3
    logic   [NL*FOMFEEDBACK_WD-1:0]     info_phy_cdm_ras_des_fomfeedback;       // [71:64]: Level: Current Figure of Merit Gen3
    logic   [NL*RX_PSET_WD-1:0]         info_mac_cdm_ras_des_pset_lrx;          // [63:61]: Level: Current Local Receiver Preset Hint Gen3
    logic   [NL*TX_COEF_WD-1:0]         info_mac_cdm_ras_des_coef_ltx;          // [60:55]: Level: Current Local Transmitter Pre Cursor coefficient Gen3
                                                                                // [54:49]: Level: Current Local Transmitter Cursor coefficient Gen3
                                                                                // [48:43]: Level: Current Local Transmitter Post Cursor coefficient Gen3
    logic   [NL*TX_COEF_WD-1:0]         info_mac_cdm_ras_des_coef_rtx;          // [42:37]: Level: Current Remote Transmitter Pre Cursor coefficient Gen3
                                                                                // [36:31]: Level: Current Remote Transmitter Cursor coefficient Gen3
                                                                                // [30:25]: Level: Current Remote Transmitter Post Cursor coefficient Gen3
    logic   [NL*TX_FS_WD-1:0]           info_mac_cdm_ras_des_lf;                // [24:19]: Level: Remote Device LF Gen3
    logic   [NL*TX_FS_WD-1:0]           info_mac_cdm_ras_des_fs;                // [18:13]: Level: Remote Device FS Gen3
    logic   [(NL*8)-1:0]                rmlh_deskew_fifo_ptr;                   // [12:5]: Level: Deskew Pointer
    logic   [NL-1:0]                    info_mac_phy_rxpolarity;                // [4]: Level: PIPE: RxPolarity
    logic   [NL-1:0]                    info_latched_rxdetected;                // [3]: Level: PIPE: Detect Lane
    logic   [NL-1:0]                    phy_mac_rxvalid_rxburst;                // [2]: Level: PIPE: RxValid/RxBurst
    logic   [NL-1:0]                    phy_mac_rxelec_rxh8exit;                // [1]: Level: PIPE: RxElecIdle/RxHibern8ExitType1
    logic   [NL-1:0]                    mac_phy_txelec_txburst;                 // [0]: Level: PIPE: TxElecIdle/TxBurst
  } rasdes_sd_info_l_s, rasdes_sd_info_l;

  assign rasdes_sd_info_l_s.orig_pipe_rxdatak = orig_pipe_rxdatak;
  assign rasdes_sd_info_l_s.orig_pipe_rxdata = orig_pipe_rxdata;
  assign rasdes_sd_info_l_s.orig_pipe_rxdatavalid = orig_pipe_rxdatavalid;
  assign rasdes_sd_info_l_s.orig_pipe_rxstatus = orig_pipe_rxstatus;
  assign rasdes_sd_info_l_s.eq_convergence_sts_g6 = eq_convergence_sts_g6;
  assign rasdes_sd_info_l_s.eqpa_violate_rule_4_g6 = eqpa_violate_rule_4_g6;
  assign rasdes_sd_info_l_s.eqpa_violate_rule_123_g6 = eqpa_violate_rule_123_g6;
  assign rasdes_sd_info_l_s.mac_cdm_ras_des_reject_rtx_g6 = mac_cdm_ras_des_reject_rtx_g6;
  assign rasdes_sd_info_l_s.phy_cdm_ras_des_fomfeedback_g6 = phy_cdm_ras_des_fomfeedback_g6;
  assign rasdes_sd_info_l_s.mac_cdm_ras_des_coef_ltx_g6 = mac_cdm_ras_des_coef_ltx_g6;
  assign rasdes_sd_info_l_s.mac_cdm_ras_des_coef_rtx_g6 = mac_cdm_ras_des_coef_rtx_g6;
  assign rasdes_sd_info_l_s.mac_cdm_ras_des_lf_g6 = mac_cdm_ras_des_lf_g6;
  assign rasdes_sd_info_l_s.mac_cdm_ras_des_fs_g6 = mac_cdm_ras_des_fs_g6;
  assign rasdes_sd_info_l_s.rmlh_deskew_fifo_ptr = rmlh_deskew_fifo_ptr;
  assign rasdes_sd_info_l_s.phy_mac_rxvalid_rxburst = phy_mac_rxvalid_rxburst;
  assign rasdes_sd_info_l_s.phy_mac_rxelec_rxh8exit = phy_mac_rxelec_rxh8exit;
  assign rasdes_sd_info_l_s.mac_phy_txelec_txburst = mac_phy_txelec_txburst;

  delay_n
   #(
     .N   (1)
    ,.WD ($bits(rasdes_sd_info_l_s))
    ,.RESETVAL ('0)
  ) u_delay_n_sd_info_l (
    // ------------- input -----------------
     .clk   (aux_clk)
    ,.rst_n (sticky_rst_n)
    ,.clear (1'b0)
    ,.din   (rasdes_sd_info_l_s)
    // ------------- output ----------------
    ,.dout  (rasdes_sd_info_l)
  );

  // cdm_rasdes_sd_info_v<N>
  struct packed {
    logic   [(NVC*DCRD_WD)-1:0] rtlh_fc_allctd_cpld;    // [239:228]: Level: Credit Allocated (CD) VCn
    logic   [(NVC*HCRD_WD)-1:0] rtlh_fc_allctd_cplh;    // [227:220]: Level: Credit Allocated (CH) VCn
    logic   [(NVC*DCRD_WD)-1:0] rtlh_fc_allctd_npd;     // [219:208]: Level: Credit Allocated (ND) VCn
    logic   [(NVC*HCRD_WD)-1:0] rtlh_fc_allctd_nph;     // [207:200]: Level: Credit Allocated (NH) VCn
    logic   [(NVC*DCRD_WD)-1:0] rtlh_fc_allctd_pd;      // [199:188]: Level: Credit Allocated (PD) VCn
    logic   [(NVC*HCRD_WD)-1:0] rtlh_fc_allctd_ph;      // [187:180]: Level: Credit Allocated (PH) VCn
    logic   [(NVC*DCRD_WD)-1:0] rtlh_fc_rcvd_cpld;      // [179:168]: Level: Credit Received (CD) VCn
    logic   [(NVC*HCRD_WD)-1:0] rtlh_fc_rcvd_cplh;      // [167:160]: Level: Credit Received (CH) VCn
    logic   [(NVC*DCRD_WD)-1:0] rtlh_fc_rcvd_npd;       // [159:148]: Level: Credit Received (ND) VCn
    logic   [(NVC*HCRD_WD)-1:0] rtlh_fc_rcvd_nph;       // [147:140]: Level: Credit Received (NH) VCn
    logic   [(NVC*DCRD_WD)-1:0] rtlh_fc_rcvd_pd;        // [139:128]: Level: Credit Received (PD) VCn
    logic   [(NVC*HCRD_WD)-1:0] rtlh_fc_rcvd_ph;        // [127:120]: Level: Credit Received (PH) VCn
    logic   [(NVC*DCRD_WD)-1:0] xadm_fc_limit_cpld;     // [119:108]: Level: Credit Limit (CD) VCn
    logic   [(NVC*HCRD_WD)-1:0] xadm_fc_limit_cplh;     // [107:100]: Level: Credit Limit (CH) VCn
    logic   [(NVC*DCRD_WD)-1:0] xadm_fc_limit_npd;      // [99:88]: Level: Credit Limit (ND) VCn
    logic   [(NVC*HCRD_WD)-1:0] xadm_fc_limit_nph;      // [87:80]: Level: Credit Limit (NH) VCn
    logic   [(NVC*DCRD_WD)-1:0] xadm_fc_limit_pd;       // [79:68]: Level: Credit Limit (PD) VCn
    logic   [(NVC*HCRD_WD)-1:0] xadm_fc_limit_ph;       // [67:60]: Level: Credit Limit (PH) VCn
    logic   [(NVC*DCRD_WD)-1:0] xadm_fc_cnsmd_cpld;     // [59:48]: Level: Credit Consumed (CD) VCn
    logic   [(NVC*HCRD_WD)-1:0] xadm_fc_cnsmd_cplh;     // [47:40]: Level: Credit Consumed (CH) VCn
    logic   [(NVC*DCRD_WD)-1:0] xadm_fc_cnsmd_npd;      // [39:28]: Level: Credit Consumed (ND) VCn
    logic   [(NVC*HCRD_WD)-1:0] xadm_fc_cnsmd_nph;      // [27:20]: Level: Credit Consumed (NH) VCn
    logic   [(NVC*DCRD_WD)-1:0] xadm_fc_cnsmd_pd;       // [19:8]: Level: Credit Consumed (PD) VCn
    logic   [(NVC*HCRD_WD)-1:0] xadm_fc_cnsmd_ph;       // [7:0]: Level: Credit Consumed (PH) VCn
  } rasdes_sd_info_v_s, rasdes_sd_info_v;

  assign rasdes_sd_info_v_s.rtlh_fc_allctd_cpld = rtlh_fc_allctd_cpld;
  assign rasdes_sd_info_v_s.rtlh_fc_allctd_cplh = rtlh_fc_allctd_cplh;
  assign rasdes_sd_info_v_s.rtlh_fc_allctd_npd = rtlh_fc_allctd_npd;
  assign rasdes_sd_info_v_s.rtlh_fc_allctd_nph = rtlh_fc_allctd_nph;
  assign rasdes_sd_info_v_s.rtlh_fc_allctd_pd = rtlh_fc_allctd_pd;
  assign rasdes_sd_info_v_s.rtlh_fc_allctd_ph = rtlh_fc_allctd_ph;
  assign rasdes_sd_info_v_s.rtlh_fc_rcvd_cpld = rtlh_fc_rcvd_cpld;
  assign rasdes_sd_info_v_s.rtlh_fc_rcvd_cplh = rtlh_fc_rcvd_cplh;
  assign rasdes_sd_info_v_s.rtlh_fc_rcvd_npd = rtlh_fc_rcvd_npd;
  assign rasdes_sd_info_v_s.rtlh_fc_rcvd_nph = rtlh_fc_rcvd_nph;
  assign rasdes_sd_info_v_s.rtlh_fc_rcvd_pd = rtlh_fc_rcvd_pd;
  assign rasdes_sd_info_v_s.rtlh_fc_rcvd_ph = rtlh_fc_rcvd_ph;
  assign rasdes_sd_info_v_s.xadm_fc_limit_cpld = xadm_fc_limit_cpld;
  assign rasdes_sd_info_v_s.xadm_fc_limit_cplh = xadm_fc_limit_cplh;
  assign rasdes_sd_info_v_s.xadm_fc_limit_npd = xadm_fc_limit_npd;
  assign rasdes_sd_info_v_s.xadm_fc_limit_nph = xadm_fc_limit_nph;
  assign rasdes_sd_info_v_s.xadm_fc_limit_pd = xadm_fc_limit_pd;
  assign rasdes_sd_info_v_s.xadm_fc_limit_ph = xadm_fc_limit_ph;
  assign rasdes_sd_info_v_s.xadm_fc_cnsmd_cpld = xadm_fc_cnsmd_cpld;
  assign rasdes_sd_info_v_s.xadm_fc_cnsmd_cplh = xadm_fc_cnsmd_cplh;
  assign rasdes_sd_info_v_s.xadm_fc_cnsmd_npd = xadm_fc_cnsmd_npd;
  assign rasdes_sd_info_v_s.xadm_fc_cnsmd_nph = xadm_fc_cnsmd_nph;
  assign rasdes_sd_info_v_s.xadm_fc_cnsmd_pd = xadm_fc_cnsmd_pd;
  assign rasdes_sd_info_v_s.xadm_fc_cnsmd_ph = xadm_fc_cnsmd_ph;

  delay_n
   #(
     .N   (1)
    ,.WD ($bits(rasdes_sd_info_v_s))
    ,.RESETVAL ('0)
  ) u_delay_n_sd_info_v (
    // ------------- input -----------------
     .clk   (aux_clk)
    ,.rst_n (sticky_rst_n)
    ,.clear (1'b0)
    ,.din   (rasdes_sd_info_v_s)
    // ------------- output ----------------
    ,.dout  (rasdes_sd_info_v)
  );

// ------------------------------------------------
//  instantiation of Event Counter module
// ------------------------------------------------
cdm_rasdes_cmn_reg
  #( .INST (INST))
        u_cdm_rasdes_cmn_reg (
// -------------- Inputs ---------------
    .aux_clk                                 (aux_clk),                            // input
    .sticky_rst_n                            (sticky_rst_n),                       // input
 // --- Register access signals
    .lbc_cdm_data                            (lbc_cdm_data),                       // input!  [31:0]
    .lbc_cdm_dbi                             (lbc_cdm_dbi),                        // input
    .ecfg_write_pulse                        (ecfg_write_pulse),                   // input  [3:0]
    .rasdes_reg_sel                          (rasdes_reg_sel),                     // input  [NF-1:0]
    .rasdes_reg_id                           (rasdes_reg_id),                      // input  [(64*NF)-1:0]
    .dbi_ro_wr_en                            (dbi_ro_wr_en),                       // input
 // --- Internal register access
    .cdm_ec_ack                              (cdm_ec_ack),                         // input  [1:0]
    .cdm_ec_rdata                            (cdm_ec_rdata),                       // input  [31:0]
    .cdm_ei_ack                              (cdm_ei_ack),                         // input  [1:0]
    .cdm_ei_rdata                            (cdm_ei_rdata),                       // input  [31:0]
    .cdm_sd_ack                              (cdm_sd_ack),                         // input  [1:0]
    .cdm_sd_rdata                            (cdm_sd_rdata),                       // input  [31:0]
    .cdm_tba_ack                             (cdm_tba_ack),                        // input  [1:0]
    .cdm_tba_rdata                           (cdm_tba_rdata),                      // input  [31:0]
    .cdm_tf_ack                              (cdm_tf_ack),                         // input  [1:0]
    .cdm_tf_rdata                            (cdm_tf_rdata),                       // input  [31:0]
 // --- Others
    .upstream_port                           (upstream_port),                      // input
    .cxl_rcrb_enable                         (cxl_rcrb_enable),
// -------------- Outputs ---------------
 // --- Register access signals
    .rasdes_reg_ack                          (rasdes_reg_ack),                     // output
    .rasdes_reg_data                         (rasdes_reg_data),                    // output [31:0]
 // --- Internal register access
    .cdm_reg_wdata                           (cdm_reg_wdata),                      // output [31:0]
    .cdm_reg_write_pulse                     (cdm_reg_write_pulse),                // output [3:0]
    .cdm_reg_id                              (cdm_reg_id)                          // output [63:0]
) ;

// ------------------------------------------------
//  instantiation of Event Counter module
// ------------------------------------------------
cdm_rasdes_ec_reg
  #( .INST (INST))
        u_cdm_rasdes_ec_reg (
// -------------- Inputs ---------------
    .aux_clk                                 (aux_clk) ,                           // input 
    .sticky_rst_n                            (sticky_rst_n),                       // input 
 // --- Register access signals
    .cdm_reg_wdata                           (cdm_reg_wdata),                      // input  [31:0]
    .cdm_reg_write_pulse                     (cdm_reg_write_pulse),                // input  [3:0]
    .cdm_reg_id                              (cdm_reg_id),                         // input  [63:0]
 // --- Event counter signals
    .rmlh_ebuf_rxoverflow                    (rmlh_ebuf_rxoverflow),               // input  [NL-1:0]
    .rmlh_ebuf_rxunderflow                   (rmlh_ebuf_rxunderflow),              // input  [NL-1:0]
    .rmlh_phy_rxcodeerror                    (rmlh_phy_rxcodeerror),               // input  [NL-1:0]
    .rmlh_phy_rxdisperror                    (rmlh_phy_rxdisperror),               // input  [NL-1:0]
    .rmlh_skp_parity_err                     (rmlh_skp_parity_err),                // input  [NL-1:0]
    .rmlh_sync_header_err                    (rmlh_sync_header_err),               // input  [NL-1:0]
    .rmlh_rxvalid_deasserted                 (rmlh_rxvalid_deasserted),            // input  [NL-1:0]
    .rmlh_deskew_ctlskp_err                  (rmlh_deskew_ctlskp_err),             // input  [NL*5-1:0]
    .smlh_eidle_inferred_in_l0               (smlh_eidle_inferred_in_l0),          // input
    .rmlh_rcvd_err                           (rmlh_rcvd_err),                      // input
    .smlh_rx_rcvry_req (smlh_rx_rcvry_req),
    .rmlh_framing_err                        (rmlh_framing_err),                   // input
    .rmlh_framing_err_l0                     (rmlh_framing_err_l0),                // input
    .rmlh_deskew_alignment_err               (rmlh_deskew_alignment_err),          // input
    .rmlh_rxskipadded                        (rmlh_rxskipadded),                   // input  [NL-1:0]
    .rmlh_rxskipremoved                      (rmlh_rxskipremoved),                 // input  [NL-1:0]
    .smlh_timeout_nfts                       (smlh_timeout_nfts),                  // input
    .smlh_l0_to_recovery                     (smlh_l0_to_recovery),                // input
    .smlh_l1_to_recovery                     (smlh_l1_to_recovery),                // input
    .smlh_in_l0s                             (smlh_in_l0s),                        // input
    .smlh_in_rl0s                            (smlh_in_rl0s),                       // input
    .smlh_rcv_eios_when_l0s_unsprt           (smlh_rcv_eios_when_l0s_unsprt),      // input
    .smlh_deskew_uncomplete_err              (smlh_deskew_uncomplete_err),         // input
    .cxl_almp_rx_repl_error                  (cxl_almp_rx_repl_error),             // input
    .cxl_vlsm_unexp_error                    (cxl_vlsm_unexp_error),               // input
    .cxl_vlsm_lrsm_req_retrain               (rasdes_ec_info_cmn_s.info_cxl_vlsm_lrsm_req_retrain_pulse),    // input
    .pm_asnak                                (pm_asnak),                           // input
    .smlh_in_l1                              (smlh_in_l1),                         // input
    .pm_in_l11                               (pm_in_l11),                          // input
    .pm_in_l12                               (pm_in_l12),                          // input
    .pm_in_l1_short                          (pm_in_l1_short),                     // input
    .pm_in_l1_cpm                            (pm_in_l1_cpm),                       // input
    .pm_in_l1_abort                          (pm_in_l1_abort),                     // input
    .smlh_in_l23                             (smlh_in_l23),                        // input
    .smlh_spd_change                         (smlh_spd_change),                    // input
    .smlh_lwd_change                         (smlh_lwd_change),                    // input
    .cfg_poisned_tlp                         (cfg_poisned_tlp),                    // input  [ERROR_TLP_WD:0]
    .cfg_ecrc_tlp_err                        (cfg_ecrc_tlp_err),                   // input  [ERROR_TLP_WD:0]
    .cfg_ur_tlp                              (cfg_ur_tlp),                         // input  [ERROR_TLP_WD:0]
    .cfg_ca_tlp                              (cfg_ca_tlp),                         // input  [ERROR_TLP_WD:0]
    .cfg_cpl_timeout                         (cfg_cpl_timeout),                    // input  [1:0]
    .rdlh_bad_tlp_err_pertlp                 (rdlh_bad_tlp_err_pertlp),            // input  [RX_TLP-1:0]
    .rdlh_lcrc_tlp_err_pertlp                (rdlh_lcrc_tlp_err_pertlp),           // input  [RX_TLP-1:0]
    .rdlh_nulified_tlp_err_pertlp            (rdlh_nulified_tlp_err_pertlp),       // input  [RX_TLP-1:0]
    .rdlh_duplicate_tlp_err_pertlp           (rdlh_duplicate_tlp_err_pertlp),      // input  [RX_TLP-1:0]
    .rdlh_bad_dllp_err_perdllp               (rdlh_bad_dllp_err_perdllp),          // input  [RX_NDLLP-1:0]
    .rdlh_rcvd_nack_perdllp                  (rdlh_rcvd_nack_perdllp),             // input  [RX_NDLLP-1:0]
    .rdlh_rcvd_ack_perdllp                   (rdlh_rcvd_ack_perdllp),              // input  [RX_NDLLP-1:0]
    .xdlh_replay_num_rlover_err              (xdlh_replay_num_rlover_err),         // input  
    .xdlh_replay_timeout_err                 (xdlh_replay_timeout_err),            // input  
    .xdlh_retry_req                          (xdlh_retry_req),                     // input  
    .xdlh_nak_sent                           (xdlh_nak_sent),                      // input  
    .xdlh_ack_sent                           (xdlh_ack_sent),                      // input  
    .xdlh_update_fc_sent                     (xdlh_update_fc_sent),                // input  [TX_NDLLP-1:0]
    .xadm_tx_nullify_evt                     (xadm_tx_nullify_evt),                // input  
    .rtlh_req_link_retrain                   (rtlh_req_link_retrain),              // input  
    .rtlh_rcvd_ufc_perdllp                   (rtlh_rcvd_ufc_perdllp),              // input  [RX_NDLLP -1:0]
    .rtlh_rx_memwr_evt                       (rtlh_rx_memwr_evt),                  // input  
    .rtlh_rx_defmemwr_evt                    (rtlh_rx_defmemwr_evt),               // input  
    .rtlh_rx_memrd_evt                       (rtlh_rx_memrd_evt),                  // input  
    .rtlh_rx_cfgwr_evt                       (rtlh_rx_cfgwr_evt),                  // input  
    .rtlh_rx_cfgrd_evt                       (rtlh_rx_cfgrd_evt),                  // input  
    .rtlh_rx_iowr_evt                        (rtlh_rx_iowr_evt),                   // input  
    .rtlh_rx_iord_evt                        (rtlh_rx_iord_evt),                   // input  
    .rtlh_rx_cplwod_evt                      (rtlh_rx_cplwod_evt),                 // input  
    .rtlh_rx_cplwd_evt                       (rtlh_rx_cplwd_evt),                  // input  
    .rtlh_rx_msg_evt                         (rtlh_rx_msg_evt),                    // input  
    .rtlh_rx_atmcop_evt                      (rtlh_rx_atmcop_evt),                 // input  
    .rtlh_rx_tlpwprefix_evt                  (rtlh_rx_tlpwprefix_evt),             // input  
    .xtlh_tx_memwr_evt                       (xtlh_tx_memwr_evt),                  // input  [NUM_EOT-1:0] 
    .xtlh_tx_defmemwr_evt                    (xtlh_tx_defmemwr_evt),               // input  [NUM_EOT-1:0]
    .xtlh_tx_memrd_evt                       (xtlh_tx_memrd_evt),                  // input  [NUM_EOT-1:0] 
    .xtlh_tx_cfgwr_evt                       (xtlh_tx_cfgwr_evt),                  // input  [NUM_EOT-1:0] 
    .xtlh_tx_cfgrd_evt                       (xtlh_tx_cfgrd_evt),                  // input  [NUM_EOT-1:0] 
    .xtlh_tx_iowr_evt                        (xtlh_tx_iowr_evt),                   // input  [NUM_EOT-1:0] 
    .xtlh_tx_iord_evt                        (xtlh_tx_iord_evt),                   // input  [NUM_EOT-1:0] 
    .xtlh_tx_cplwod_evt                      (xtlh_tx_cplwod_evt),                 // input  [NUM_EOT-1:0] 
    .xtlh_tx_cplwd_evt                       (xtlh_tx_cplwd_evt),                  // input  [NUM_EOT-1:0] 
    .xtlh_tx_msg_evt                         (xtlh_tx_msg_evt),                    // input  [NUM_EOT-1:0] 
    .xtlh_tx_atmcop_evt                      (xtlh_tx_atmcop_evt),                 // input  [NUM_EOT-1:0] 
    .xtlh_tx_tlpwprefix_evt                  (xtlh_tx_tlpwprefix_evt),             // input  [NUM_EOT-1:0] 
 //---- RAM I/F -----------------------
    .ec_ram_dataout                          (ec_ram_dataout),                     // input  [RASDES_RAM_DATA_WIDTH-1:0]
// -------------- Outputs ---------------
 //---- RAM I/F -----------------------
    .ec_ram_ena                              (ec_ram_ena),                         // output
    .ec_ram_wea                              (ec_ram_wea),                         // output
    .ec_ram_addra                            (ec_ram_addra),                       // output [RASDES_RAM_ADDR_WIDTH-1:0]
    .ec_ram_datain                           (ec_ram_datain),                      // output [RASDES_RAM_DATA_WIDTH-1:0]
    .ec_ram_enb                              (ec_ram_enb),                         // output 
    .ec_ram_addrb                            (ec_ram_addrb),                       // output [RASDES_RAM_ADDR_WIDTH-1:0]
 // --- Register access signals
    .cdm_ec_ack                              (cdm_ec_ack),                         // output [1:0]
    .cdm_ec_rdata                            (cdm_ec_rdata)                        // output [31:0]
 // --- Event counter signals
 );


// ------------------------------------------------
//  instantiation of Time based analysis module
// ------------------------------------------------
cdm_rasdes_tba_reg
  #( .INST (INST))
        u_cdm_rasdes_tba_reg (
// -------------- Inputs ---------------
    .aux_clk                                 (aux_clk) ,                           // input 
    .sticky_rst_n                            (sticky_rst_n),                       // input 
 // --- Register access signals
    .cdm_reg_wdata                           (cdm_reg_wdata),                      // input  [31:0]
    .cdm_reg_write_pulse                     (cdm_reg_write_pulse),                // input  [3:0]
    .cdm_reg_id                              (cdm_reg_id),                         // input  [63:0]
 // --- Time based Analysis signals
    .smlh_in_rl0s                            (smlh_in_rl0s),                       // input
    .smlh_in_l0s                             (smlh_in_l0s),                        // input
    .smlh_in_l0                              (smlh_in_l0),                         // input
    .smlh_in_l1                              (smlh_in_l1),                         // input
    .pm_in_l11                               (pm_in_l11),                          // input
    .pm_in_l12                               (pm_in_l12),                          // input
    .smlh_ltssm_in_l0p                       (smlh_ltssm_in_l0p),                  // input
    .smlh_link_in_training                   (smlh_link_in_training),              // input
    .rtlh_rx_tlp_dpsize                      (rtlh_rx_tlp_dpsize),                 // input  [RX_TLP*11-1:0]
    .xtlh_tx_tlp_dpsize                      (xtlh_tx_tlp_dpsize),                 // input  [NUM_EOT*11-1:0] 
 //---- RAM I/F -----------------------
    .tba_ram_dataout                         (tba_ram_dataout),                    // input  [RASDES_RAM_DATA_WIDTH-1:0]
 //---- The others -----------------------
    .current_data_rate                       (current_data_rate),                  // input  [1:0]
    .app_ras_des_tba_ctrl                    (app_ras_des_tba_ctrl),               // input  [1:0]
    .pm_sel_aux_clk                          (pm_sel_aux_clk),                     // input
    .aux_clk_active                          (aux_clk_active),                     // input
    .cfg_pl_aux_clk_freq                     (cfg_pl_aux_clk_freq),                // input  [PL_AUX_CLK_FREQ_WD-1:0]
// -------------- Outputs ---------------
 //---- RAM I/F -----------------------
    .tba_ram_ena                             (tba_ram_ena),                        // output
    .tba_ram_wea                             (tba_ram_wea),                        // output
    .tba_ram_addra                           (tba_ram_addra),                      // output [RASDES_RAM_ADDR_WIDTH-1:0]
    .tba_ram_datain                          (tba_ram_datain),                     // output [RASDES_RAM_DATA_WIDTH-1:0]
    .tba_ram_enb                             (tba_ram_enb),                        // output
    .tba_ram_addrb                           (tba_ram_addrb),                      // output [RASDES_RAM_ADDR_WIDTH-1:0]
 // --- Register access signals
    .cdm_tba_ack                             (cdm_tba_ack),                        // output [1:0]
    .cdm_tba_rdata                           (cdm_tba_rdata)                       // output [31:0]
 // --- Time based Analysis signals
) ;

// ------------------------------------------------
//  instantiation of Error Injection module
// ------------------------------------------------
cdm_rasdes_einj_reg
  #( .INST (INST))
        u_cdm_rasdes_einj_reg (
// -------------- Inputs ---------------
    .aux_clk                                 (aux_clk) ,                           // input 
    .sticky_rst_n                            (sticky_rst_n),                       // input 
 // --- Register access signals
    .cdm_reg_wdata                           (cdm_reg_wdata),                      // input  [31:0]
    .lbc_cdm_dbi                             (lbc_cdm_dbi),                        // input
    .cdm_reg_write_pulse                     (cdm_reg_write_pulse),                // input  [3:0]
    .cdm_reg_id                              (cdm_reg_id),                         // input  [63:0]
    .cfg_err_inj_wr_disable                  (cfg_err_inj_wr_disable),             // input
 // --- Error Injection signals
    .rdlh_einj0_lcrc_evt                     (rdlh_einj0_lcrc_evt),                // input  [2:0]
    .radm_einj0_ecrc_evt                     (radm_einj0_ecrc_evt),
    .xmlh_einj0_oscrc_evt                    (xmlh_einj0_oscrc_evt),               // input  
    .xdlh_einj0_lcrc_evt                     (xdlh_einj0_lcrc_evt),                // input  [1:0]
    .xdlh_einj0_fcrc_evt                     (xdlh_einj0_fcrc_evt),                // input  
    .xdlh_einj0_dllpcrc_evt                  (xdlh_einj0_dllpcrc_evt),             // input  [1:0]
    .xadm_einj0_ecrc_evt                     (xadm_einj0_ecrc_evt),                // input
    .ras_des_einj1_exp_sequm_evt             (ras_des_einj1_exp_sequm_evt),     
    .ras_des_einj1_ack_nak_sequm_evt         (ras_des_einj1_ack_nak_sequm_evt),  
    .xdlh_einj2_nak_evt                      (xdlh_einj2_nak_evt),                 // input  
    .xmlh_einj3_osmsk_evt                    (xmlh_einj3_osmsk_evt),               // input  [1:0]
    .rtlh_einj4_fc_evt                       (rtlh_einj4_fc_evt),                  // input  
    .xdlh_einj5_nultlp_evt                   (xdlh_einj5_nultlp_evt),              // input  
    .xdlh_einj5_dup_evt                      (xdlh_einj5_dup_evt),                 // input  
    .xaim_einj6_tlp_evt                      (xaim_einj6_tlp_evt),
// -------------- Outputs ---------------
 // --- Register access signals
    .cdm_ei_ack                              (cdm_ei_ack),                         // output [1:0]
    .cdm_ei_rdata                            (cdm_ei_rdata),                       // output [31:0]
 // --- Error Injection signals
    .cdm_ras_des_einj0_enable                (cdm_ras_des_einj0_enable),           // output
    .cdm_ras_des_einj0_count                 (cdm_ras_des_einj0_count),            // output [7:0]
    .cdm_ras_des_einj0_crc_type              (cdm_ras_des_einj0_crc_type),         // output [3:0]
    .cdm_ras_des_einj0_ecrc_vc_sel           (cdm_ras_des_einj0_ecrc_vc_sel),      // Error injection 0 ECRC Virtual Channel Selection
    .cdm_ras_des_einj0_ecrc_fc_sel           (cdm_ras_des_einj0_ecrc_fc_sel),      // Error injection 0 ECRC Flow Control Selection
    .cdm_ras_des_einj0_ecrc_intf_sel         (cdm_ras_des_einj0_ecrc_intf_sel),    // Error injection 0 ECRC Interface Selection
    .cdm_ras_des_einj1_enable                (cdm_ras_des_einj1_enable),           // output
    .cdm_ras_des_einj1_seq_type              (cdm_ras_des_einj1_seq_type),         // output
    .cdm_ras_des_einj1_bad_seq               (cdm_ras_des_einj1_bad_seq),          // output [12:0]
    .cdm_ras_des_einj1_count                 (cdm_ras_des_einj1_count),            // output [7:0]
    .cdm_ras_des_einj2_enable                (cdm_ras_des_einj2_enable),           // output
    .cdm_ras_des_einj2_dllp_type             (cdm_ras_des_einj2_dllp_type),        // output [1:0]
    .cdm_ras_des_einj3_enable                (cdm_ras_des_einj3_enable),           // output
    .cdm_ras_des_einj3_count                 (cdm_ras_des_einj3_count),            // output [7:0]
    .cdm_ras_des_einj3_smb_type              (cdm_ras_des_einj3_smb_type),         // output [2:0]
    .cdm_ras_des_einj4_enable                (cdm_ras_des_einj4_enable),           // output
    .cdm_ras_des_einj4_updfc_type            (cdm_ras_des_einj4_updfc_type),       // output [2:0]
    .cdm_ras_des_einj4_vcnum                 (cdm_ras_des_einj4_vcnum),            // output [2:0]
    .cdm_ras_des_einj4_badfc_value           (cdm_ras_des_einj4_badfc_value),      // output [12:0]
    .cdm_ras_des_einj5_enable                (cdm_ras_des_einj5_enable),           // output
    .cdm_ras_des_einj5_count                 (cdm_ras_des_einj5_count),            // output [7:0]
    .cdm_ras_des_einj5_tlp_type              (cdm_ras_des_einj5_tlp_type),         // output
    .cdm_ras_des_einj6_enable                (cdm_ras_des_einj6_enable),           // output
    .cdm_ras_des_einj6_cmp_point_h0          (cdm_ras_des_einj6_cmp_point_h0),     // output [31:0]
    .cdm_ras_des_einj6_cmp_point_h1          (cdm_ras_des_einj6_cmp_point_h1),     // output [31:0]
    .cdm_ras_des_einj6_cmp_point_h2          (cdm_ras_des_einj6_cmp_point_h2),     // output [31:0]
    .cdm_ras_des_einj6_cmp_point_h3          (cdm_ras_des_einj6_cmp_point_h3),     // output [31:0]
    .cdm_ras_des_einj6_cmp_value_h0          (cdm_ras_des_einj6_cmp_value_h0),     // output [31:0]
    .cdm_ras_des_einj6_cmp_value_h1          (cdm_ras_des_einj6_cmp_value_h1),     // output [31:0]
    .cdm_ras_des_einj6_cmp_value_h2          (cdm_ras_des_einj6_cmp_value_h2),     // output [31:0]
    .cdm_ras_des_einj6_cmp_value_h3          (cdm_ras_des_einj6_cmp_value_h3),     // output [31:0]
    .cdm_ras_des_einj6_chg_point_h0          (cdm_ras_des_einj6_chg_point_h0),     // output [31:0]
    .cdm_ras_des_einj6_chg_point_h1          (cdm_ras_des_einj6_chg_point_h1),     // output [31:0]
    .cdm_ras_des_einj6_chg_point_h2          (cdm_ras_des_einj6_chg_point_h2),     // output [31:0]
    .cdm_ras_des_einj6_chg_point_h3          (cdm_ras_des_einj6_chg_point_h3),     // output [31:0]
    .cdm_ras_des_einj6_chg_value_h0          (cdm_ras_des_einj6_chg_value_h0),     // output [31:0]
    .cdm_ras_des_einj6_chg_value_h1          (cdm_ras_des_einj6_chg_value_h1),     // output [31:0]
    .cdm_ras_des_einj6_chg_value_h2          (cdm_ras_des_einj6_chg_value_h2),     // output [31:0]
    .cdm_ras_des_einj6_chg_value_h3          (cdm_ras_des_einj6_chg_value_h3),     // output [31:0]
    .cdm_ras_des_einj6_count                 (cdm_ras_des_einj6_count),            // output [7:0]
    .cdm_ras_des_einj6_invt_cont             (cdm_ras_des_einj6_invt_cont),        // output
    .cdm_ras_des_einj6_pkt_type              (cdm_ras_des_einj6_pkt_type)          // output [2:0]
) ;

// ------------------------------------------------
//  instantiation of Silicon debug module
// ------------------------------------------------
cdm_rasdes_sd_reg
  #( 
    .INST (INST)
  ) u_cdm_rasdes_sd_reg (
// -------------- Inputs ---------------
    .aux_clk                                 (aux_clk) ,                           // input 
    .sticky_rst_n                            (sticky_rst_n),                       // input 
 // --- Register access signals
    .cdm_reg_wdata                           (cdm_reg_wdata),                      // input  [31:0]
    .cdm_reg_write_pulse                     (cdm_reg_write_pulse),                // input  [3:0]
    .cdm_reg_id                              (cdm_reg_id),                         // input  [63:0]
 // --- Silcon debug signals
    .mac_phy_txelec_txburst                  (mac_phy_txelec_txburst),             // input
    .mac_phy_rxpolarity                      (mac_phy_rxpolarity),                 // input
    .phy_mac_rxelec_rxh8exit                 (phy_mac_rxelec_rxh8exit),            // input
    .phy_mac_rxvalid_rxburst                 (phy_mac_rxvalid_rxburst),            // input
    .latched_rxdetected                      (latched_rxdetected),                 // input [NL-1:0]
    .rmlh_deskew_fifo_ptr                    (rmlh_deskew_fifo_ptr),               // input  [(NL*8)-1:0]
    .pm_usp_prot_state                       (pm_usp_prot_state),
    .pm_usp_link_state                       (pm_usp_link_state),
    .pm_dsp_prot_state                       (pm_dsp_prot_state),
    .pm_dsp_link_state                       (pm_dsp_link_state),
    .pm_l0s_state                            (pm_l0s_state),
    .rmlh_framing_err_ptr                    (rmlh_framing_err_ptr),               // input  [6:0]
    .smlh_lane_reversed                      (smlh_lane_reversed),                 // input       
    .pm_pme_resend_flag                      (pm_pme_resend_flag),                 // input       
    .smlh_ltssm_variable                     (smlh_ltssm_variable),                // input  [15:0]
    .ltssm_powerdown                         (ltssm_powerdown),                    // input  [1:0]
    .latched_ts_nfts                         (latched_ts_nfts),                    // input  [7:0]
    .rdlh_dlcntrl_state                      (rdlh_dlcntrl_state),                 // input  [1:0]
    .rdlh_vc0_initfc1_status                 (rdlh_vc0_initfc1_status),            // input 
    .rdlh_vc0_initfc2_status                 (rdlh_vc0_initfc2_status),            // input 
    .rdlh_xplh_curnt_rx_ack_seqnum           (rdlh_xplh_curnt_rx_ack_seqnum),      // input  [11:0]
    .xdlh_xplh_curnt_seqnum                  (xdlh_xplh_curnt_seqnum),             // input  [11:0]
    .app_malformed_tlp                       (app_malformed_tlp),                  // input
    .rtlh_fc_rcvd_ph                         (rtlh_fc_rcvd_ph),                    // input  [(NVC*HCRD_WD)-1:0]
    .rtlh_fc_rcvd_pd                         (rtlh_fc_rcvd_pd),                    // input  [(NVC*DCRD_WD)-1:0]
    .rtlh_fc_rcvd_nph                        (rtlh_fc_rcvd_nph),                   // input  [(NVC*HCRD_WD)-1:0]
    .rtlh_fc_rcvd_npd                        (rtlh_fc_rcvd_npd),                   // input  [(NVC*DCRD_WD)-1:0]
    .rtlh_fc_rcvd_cplh                       (rtlh_fc_rcvd_cplh),                  // input  [(NVC*HCRD_WD)-1:0]
    .rtlh_fc_rcvd_cpld                       (rtlh_fc_rcvd_cpld),                  // input  [(NVC*DCRD_WD)-1:0]
    .rtlh_fc_allctd_ph                       (rtlh_fc_allctd_ph),                  // input  [(NVC*HCRD_WD)-1:0]
    .rtlh_fc_allctd_pd                       (rtlh_fc_allctd_pd),                  // input  [(NVC*DCRD_WD)-1:0]
    .rtlh_fc_allctd_nph                      (rtlh_fc_allctd_nph),                 // input  [(NVC*HCRD_WD)-1:0]
    .rtlh_fc_allctd_npd                      (rtlh_fc_allctd_npd),                 // input  [(NVC*DCRD_WD)-1:0]
    .rtlh_fc_allctd_cplh                     (rtlh_fc_allctd_cplh),                // input  [(NVC*HCRD_WD)-1:0]
    .rtlh_fc_allctd_cpld                     (rtlh_fc_allctd_cpld),                // input  [(NVC*DCRD_WD)-1:0]
    .xadm_fc_cnsmd_ph                        (xadm_fc_cnsmd_ph),                   // input  [(NVC*HCRD_WD)-1:0]
    .xadm_fc_cnsmd_pd                        (xadm_fc_cnsmd_pd),                   // input  [(NVC*DCRD_WD)-1:0]
    .xadm_fc_cnsmd_nph                       (xadm_fc_cnsmd_nph),                  // input  [(NVC*HCRD_WD)-1:0]
    .xadm_fc_cnsmd_npd                       (xadm_fc_cnsmd_npd),                  // input  [(NVC*DCRD_WD)-1:0]
    .xadm_fc_cnsmd_cplh                      (xadm_fc_cnsmd_cplh),                 // input  [(NVC*HCRD_WD)-1:0]
    .xadm_fc_cnsmd_cpld                      (xadm_fc_cnsmd_cpld),                 // input  [(NVC*DCRD_WD)-1:0]
    .xadm_fc_limit_ph                        (xadm_fc_limit_ph),                   // input  [(NVC*HCRD_WD)-1:0]
    .xadm_fc_limit_pd                        (xadm_fc_limit_pd),                   // input  [(NVC*DCRD_WD)-1:0]
    .xadm_fc_limit_nph                       (xadm_fc_limit_nph),                  // input  [(NVC*HCRD_WD)-1:0]
    .xadm_fc_limit_npd                       (xadm_fc_limit_npd),                  // input  [(NVC*DCRD_WD)-1:0]
    .xadm_fc_limit_cplh                      (xadm_fc_limit_cplh),                 // input  [(NVC*HCRD_WD)-1:0]
    .xadm_fc_limit_cpld                      (xadm_fc_limit_cpld),                 // input  [(NVC*DCRD_WD)-1:0]
    .radm_mlf_tlp_err_ptr                    (radm_mlf_tlp_err_ptr),               // input  [(FX_TLP*8)-1:0]
    .init_eq_pending                         (init_eq_pending),                    // input
    .mac_cdm_ras_des_fs                      (mac_cdm_ras_des_fs),                 // input  [NL*TX_FS_WD-1:0]   
    .mac_cdm_ras_des_lf                      (mac_cdm_ras_des_lf),                 // input  [NL*TX_FS_WD-1:0]   
    .mac_cdm_ras_des_coef_ltx                (mac_cdm_ras_des_coef_ltx),           // input  [NL*TX_COEF_WD-1:0]
    .phy_cdm_ras_des_fomfeedback             (phy_cdm_ras_des_fomfeedback),        // input  [NL*FOMFEEDBACK_WD-1:0]
    .eqpa_violate_rule_123                   (eqpa_violate_rule_123),              // input  [NL*3-1:0]
    .eq_convergence_sts                      (eq_convergence_sts),                 // input  [NL*2-1:0]
    .mac_cdm_ras_des_coef_rtx                (mac_cdm_ras_des_coef_rtx),           // input  [NL*TX_COEF_WD-1:0]
    .mac_cdm_ras_des_pset_lrx                (mac_cdm_ras_des_pset_lrx),           // input  [NL*RX_PSET_WD-1:0]
    .mac_cdm_ras_des_reject_rtx              (mac_cdm_ras_des_reject_rtx),         // input  [NL-1:0]
    .init_eq_pending_g4                      (init_eq_pending_g4),                 // input
    .mac_cdm_ras_des_fs_g4                   (mac_cdm_ras_des_fs_g4),              // input  [NL*TX_FS_WD-1:0]   
    .mac_cdm_ras_des_lf_g4                   (mac_cdm_ras_des_lf_g4),              // input  [NL*TX_FS_WD-1:0]   
    .mac_cdm_ras_des_coef_ltx_g4             (mac_cdm_ras_des_coef_ltx_g4),        // input  [NL*TX_COEF_WD-1:0]
    .phy_cdm_ras_des_fomfeedback_g4          (phy_cdm_ras_des_fomfeedback_g4),     // input  [NL*FOMFEEDBACK_WD-1:0]
    .eqpa_violate_rule_123_g4                (eqpa_violate_rule_123_g4),           // input  [NL*3-1:0]
    .eq_convergence_sts_g4                   (eq_convergence_sts_g4),              // input  [NL*2-1:0]
    .mac_cdm_ras_des_coef_rtx_g4             (mac_cdm_ras_des_coef_rtx_g4),        // input  [NL*TX_COEF_WD-1:0]
    .mac_cdm_ras_des_reject_rtx_g4           (mac_cdm_ras_des_reject_rtx_g4),      // input  [NL-1:0]
    .init_eq_pending_g5                      (init_eq_pending_g5),                 // input
    .mac_cdm_ras_des_fs_g5                   (mac_cdm_ras_des_fs_g5),              // input  [NL*TX_FS_WD-1:0]   
    .mac_cdm_ras_des_lf_g5                   (mac_cdm_ras_des_lf_g5),              // input  [NL*TX_FS_WD-1:0]   
    .mac_cdm_ras_des_coef_ltx_g5             (mac_cdm_ras_des_coef_ltx_g5),        // input  [NL*TX_COEF_WD-1:0]
    .phy_cdm_ras_des_fomfeedback_g5          (phy_cdm_ras_des_fomfeedback_g5),     // input  [NL*FOMFEEDBACK_WD-1:0]
    .eqpa_violate_rule_123_g5                (eqpa_violate_rule_123_g5),           // input  [NL*3-1:0]
    .eq_convergence_sts_g5                   (eq_convergence_sts_g5),              // input  [NL*2-1:0]
    .mac_cdm_ras_des_coef_rtx_g5             (mac_cdm_ras_des_coef_rtx_g5),        // input  [NL*TX_COEF_WD-1:0]
    .mac_cdm_ras_des_reject_rtx_g5           (mac_cdm_ras_des_reject_rtx_g5),      // input  [NL-1:0]
    .init_eq_pending_g6                      (init_eq_pending_g6),                 // input
    .mac_cdm_ras_des_fs_g6                   (mac_cdm_ras_des_fs_g6),              // input  [NL*TX_FS_WD-1:0]   
    .mac_cdm_ras_des_lf_g6                   (mac_cdm_ras_des_lf_g6),              // input  [NL*TX_FS_WD-1:0]   
    .mac_cdm_ras_des_coef_ltx_g6             (mac_cdm_ras_des_coef_ltx_g6),        // input  [NL*TX_COEF_WD-1:0]
    .phy_cdm_ras_des_fomfeedback_g6          (phy_cdm_ras_des_fomfeedback_g6),     // input  [NL*FOMFEEDBACK_WD-1:0]
    .eqpa_violate_rule_123_g6                (eqpa_violate_rule_123_g6),           // input  [NL*3-1:0]
    .eqpa_violate_rule_4_g6                  (eqpa_violate_rule_4_g6),             // input  [NL-1:0]
    .eq_convergence_sts_g6                   (eq_convergence_sts_g6),              // input  [NL*2-1:0]
    .mac_cdm_ras_des_coef_rtx_g6             (mac_cdm_ras_des_coef_rtx_g6),        // input  [NL*TX_COEF_WD-1:0]
    .mac_cdm_ras_des_reject_rtx_g6           (mac_cdm_ras_des_reject_rtx_g6),      // input  [NL-1:0]
    .l1sub_state                             (l1sub_state),                        // input  [2:0]
    .app_ras_des_sd_hold_ltssm               (app_ras_des_sd_hold_ltssm),          // input
// -------------- Outputs ---------------
 // --- Register access signals
    .cdm_sd_ack                              (cdm_sd_ack),                         // output [1:0]
    .cdm_sd_rdata                            (cdm_sd_rdata),                       // output [31:0]
 // --- Silcon debug signals
    .cdm_ras_des_pm_entry_interval           (cdm_ras_des_pm_entry_interval),      // output [1:0] 
    .cdm_ras_des_eidle_cnt_sel               (cdm_ras_des_eidle_cnt_sel),          // output [1:0] 
    .cdm_ras_des_ltssm_stop                  (cdm_ras_des_ltssm_stop),             // output
    .cdm_ras_des_recovery_req                (cdm_ras_des_recovery_req),           // output
    .cdm_ras_des_ferr_rec_dis                (cdm_ras_des_ferr_rec_dis),           // output       
    .cdm_ras_des_direct_rcvry_idle_to_cfg    (cdm_ras_des_direct_rcvry_idle_to_cfg), // output       
    .cdm_ras_des_direct_poll_cmp_to_det      (cdm_ras_des_direct_poll_cmp_to_det), // output       
    .cdm_ras_des_direct_lpbk_slave_to_exit   (cdm_ras_des_direct_lpbk_slave_to_exit), // output       
    .cdm_ras_des_force_rxdetected_en         (cdm_ras_des_force_rxdetected_en),    // output
    .cdm_ras_des_force_rxdetected            (cdm_ras_des_force_rxdetected)        // output [15:0]
    ,
    .cdm_ras_des_force_linkdown_noack        (cdm_ras_des_force_linkdown_noack)    // output
    ,
    .cdm_ras_des_ext_eq_to_factor        (cdm_ras_des_ext_eq_to_factor),           // output [1:0]
    .cdm_ras_des_eq_fom_target_en            (cdm_ras_des_eq_fom_target_en),       // output  
    .cdm_ras_des_eq_force_coef_rtx_en        (cdm_ras_des_eq_force_coef_rtx_en),   // output [NL-1:0]
    .cdm_ras_des_eq_force_pset_lrx_en        (cdm_ras_des_eq_force_pset_lrx_en),   // output [NL-1:0]
    .cdm_ras_des_eq_force_coef_ltx_en        (cdm_ras_des_eq_force_coef_ltx_en),   // output [NL-1:0]
    .cdm_ras_des_eq_force_coef_ltx           (cdm_ras_des_eq_force_coef_ltx),      // output [NL*TX_COEF_WD-1:0]
    .cdm_ras_des_eq_force_pset_lrx           (cdm_ras_des_eq_force_pset_lrx),      // output [NL*RX_PSET_WD-1:0]
    .cdm_ras_des_eq_force_coef_rtx           (cdm_ras_des_eq_force_coef_rtx),      // output [NL*TX_COEF_WD-1:0]
    .cdm_ras_des_eq_force_pset_ltx_en        (cdm_ras_des_eq_force_pset_ltx_en),   // output [NL-1:0]
    .cdm_ras_des_eq_force_usp_pset_ltx       (cdm_ras_des_eq_force_usp_pset_ltx)   // output [NL*TX_PSET_WD-1:0]
    ,
    .cdm_ras_des_eq_force_coef_rtx_en_g4     (cdm_ras_des_eq_force_coef_rtx_en_g4), // output [NL-1:0]
    .cdm_ras_des_eq_force_coef_ltx_en_g4     (cdm_ras_des_eq_force_coef_ltx_en_g4), // output [NL-1:0]
    .cdm_ras_des_eq_force_coef_ltx_g4        (cdm_ras_des_eq_force_coef_ltx_g4),   // output [NL*TX_COEF_WD-1:0]
    .cdm_ras_des_eq_force_coef_rtx_g4        (cdm_ras_des_eq_force_coef_rtx_g4),   // output [NL*TX_COEF_WD-1:0]
    .cdm_ras_des_eq_force_pset_ltx_en_g4     (cdm_ras_des_eq_force_pset_ltx_en_g4), // output [NL-1:0]
    .cdm_ras_des_eq_force_usp_pset_ltx_g4    (cdm_ras_des_eq_force_usp_pset_ltx_g4) // output [NL*TX_PSET_WD-1:0]
    ,
    .cdm_ras_des_eq_force_coef_rtx_en_g5     (cdm_ras_des_eq_force_coef_rtx_en_g5), // output [NL-1:0]
    .cdm_ras_des_eq_force_coef_ltx_en_g5     (cdm_ras_des_eq_force_coef_ltx_en_g5), // output [NL-1:0]
    .cdm_ras_des_eq_force_coef_ltx_g5        (cdm_ras_des_eq_force_coef_ltx_g5),   // output [NL*TX_COEF_WD-1:0]
    .cdm_ras_des_eq_force_coef_rtx_g5        (cdm_ras_des_eq_force_coef_rtx_g5),   // output [NL*TX_COEF_WD-1:0]
    .cdm_ras_des_eq_force_pset_ltx_en_g5     (cdm_ras_des_eq_force_pset_ltx_en_g5), // output [NL-1:0]
    .cdm_ras_des_eq_force_usp_pset_ltx_g5    (cdm_ras_des_eq_force_usp_pset_ltx_g5) // output [NL*TX_PSET_WD-1:0]
    ,
    .cdm_ras_des_eq_force_coef_rtx_en_g6     (cdm_ras_des_eq_force_coef_rtx_en_g6), // output [NL-1:0]
    .cdm_ras_des_eq_force_coef_ltx_en_g6     (cdm_ras_des_eq_force_coef_ltx_en_g6), // output [NL-1:0]
    .cdm_ras_des_eq_force_coef_ltx_g6        (cdm_ras_des_eq_force_coef_ltx_g6),    // output [NL*TX_COEF_WD-1:0]
    .cdm_ras_des_eq_force_coef_rtx_g6        (cdm_ras_des_eq_force_coef_rtx_g6),    // output [NL*TX_COEF_WD-1:0]
    .cdm_ras_des_eq_force_pset_ltx_en_g6     (cdm_ras_des_eq_force_pset_ltx_en_g6), // output [NL-1:0]
    .cdm_ras_des_eq_force_usp_pset_ltx_g6    (cdm_ras_des_eq_force_usp_pset_ltx_g6) // output [NL*TX_PSET_WD-1:0]
    ,
    .cdm_ras_des_eq_fom_target               (cdm_ras_des_eq_fom_target),          //output [FOMFEEDBACK_WD-1:0]
    .cdm_ras_des_eq_eval_interval            (cdm_ras_des_eq_eval_interval)        //output
 // --- Trace FIFO signals
) ;

assign cdm_tf_ack   = 2'd0 ;
assign cdm_tf_rdata = 32'd0 ;

// ------------------------------------------------
//  instantiation of registers implemtented by RAM
// ------------------------------------------------
cdm_rasdes_ramif
  #( .INST (INST))
        u_cdm_rasdes_ramif (
// -------------- Inputs ---------------
    .aux_clk                                 (aux_clk),                            // input
    .sticky_rst_n                            (sticky_rst_n)                        // input
                                                           ,
    //---- Event counter -----------------------------
    //---- EC RAM I/F -----------------------
    .cdm_ras_des_ec_ram_dataout              (cdm_ras_des_ec_ram_dataout),         // input     [RASDES_EC_RAM_DATA_WIDTH-1:0]

    //---- Internal connection -----------------------
    .ec_ram_ena                              (ec_ram_ena),                         // input
    .ec_ram_wea                              (ec_ram_wea),                         // input
    .ec_ram_addra                            (ec_ram_addra),                       // input     [RASDES_EC_RAM_ADDR_WIDTH-1:0]
    .ec_ram_datain                           (ec_ram_datain),                      // input     [RASDES_EC_RAM_DATA_WIDTH-1:0]
    .ec_ram_enb                              (ec_ram_enb),                         // input
    .ec_ram_addrb                            (ec_ram_addrb)                        // input     [RASDES_EC_RAM_ADDR_WIDTH-1:0]
                                                           ,
    //---- Time based analysis -----------------------------
    //---- TB RAM I/F -----------------------
    .cdm_ras_des_tba_ram_dataout             (cdm_ras_des_tba_ram_dataout),        // input     [RASDES_TBA_RAM_DATA_WIDTH-1:0]

    //---- TB internal connection -----------------------
    .tba_ram_ena                             (tba_ram_ena),                        // input
    .tba_ram_wea                             (tba_ram_wea),                        // input
    .tba_ram_addra                           (tba_ram_addra),                      // input     [RASDES_TBA_RAM_ADDR_WIDTH-1:0]
    .tba_ram_datain                          (tba_ram_datain),                     // input     [RASDES_TBA_RAM_DATA_WIDTH-1:0]
    .tba_ram_enb                             (tba_ram_enb),                        // input
    .tba_ram_addrb                           (tba_ram_addrb)                       // input     [RASDES_TBA_RAM_ADDR_WIDTH-1:0]
// -------------- Outputs ---------------
                                                           ,
    //---- Event counter -----------------------------
    //---- EC RAM I/F -----------------------
    .cdm_ras_des_ec_ram_ena                  (cdm_ras_des_ec_ram_ena),             // output
    .cdm_ras_des_ec_ram_wea                  (cdm_ras_des_ec_ram_wea),             // output
    .cdm_ras_des_ec_ram_addra                (cdm_ras_des_ec_ram_addra),           // output    [RASDES_EC_RAM_ADDR_WIDTH-1:0]
    .cdm_ras_des_ec_ram_datain               (cdm_ras_des_ec_ram_datain),          // output    [RASDES_EC_RAM_DATA_WIDTH-1:0]
    .cdm_ras_des_ec_ram_enb                  (cdm_ras_des_ec_ram_enb),             // output
    .cdm_ras_des_ec_ram_addrb                (cdm_ras_des_ec_ram_addrb),           // output    [RASDES_EC_RAM_ADDR_WIDTH-1:0]
    //---- EC internal connection -----------------------
    .ec_ram_dataout                          (ec_ram_dataout)                      // output    [RASDES_EC_RAM_DATA_WIDTH-1:0]
// -------------- Outputs ---------------
                                                             ,
    //---- Time based analysis -----------------------------
    //---- TB RAM I/F -----------------------
    .cdm_ras_des_tba_ram_ena                 (cdm_ras_des_tba_ram_ena),            // output
    .cdm_ras_des_tba_ram_wea                 (cdm_ras_des_tba_ram_wea),            // output
    .cdm_ras_des_tba_ram_addra               (cdm_ras_des_tba_ram_addra),          // output    [RASDES_TBA_RAM_ADDR_WIDTH-1:0]
    .cdm_ras_des_tba_ram_datain              (cdm_ras_des_tba_ram_datain),         // output    [RASDES_TBA_RAM_DATA_WIDTH-1:0]
    .cdm_ras_des_tba_ram_enb                 (cdm_ras_des_tba_ram_enb),            // output
    .cdm_ras_des_tba_ram_addrb               (cdm_ras_des_tba_ram_addrb),          // output    [RASDES_TBA_RAM_ADDR_WIDTH-1:0]
    //----TB internal connection -----------------------
    .tba_ram_dataout                         (tba_ram_dataout)                     // output    [RASDES_TBA_RAM_DATA_WIDTH-1:0]
    );

  assign rasdes_ec_info_cmn_s.info_pm_in_l12 = pm_in_l12 ;
  assign rasdes_ec_info_cmn_s.info_pm_in_l11 = pm_in_l11 ;

  // ----------------------------------------------------
  //  Debug Info Event counter common
  // ----------------------------------------------------
  genvar                                    ii;

  // Switching 0 or variable
  wire                                      info_cxl_vlsm_lrsm_req_retrain ;
  wire   [NL*5-1:0]                         info_rmlh_deskew_ctlskp_err;
  wire   [NL-1:0]                           info_rmlh_sync_header_err ;
  wire   [NL-1:0]                           info_rmlh_skp_parity_err ;

  reg                                       info_cxl_vlsm_lrsm_req_retrain_d ;
  reg                                       rtlh_req_link_retrain_d ;
  

    parameter XADM_IF_WD      = N_XADM_IF;
    parameter XADM_P_IF_WD    = N_XADM_P_IF;
    parameter XADM_NP_IF_WD   = N_XADM_NP_IF;
    parameter XADM_CPL_IF_WD  = N_XADM_CPL_IF;
    parameter CCIX_IF_WD      = N_CCIX_IF;

  generate
    for (ii=0; ii<INT_RX_TLP; ii=ii+1) begin : gen_fx_tlp2rx_tlp_for
      if ( ii<=ERROR_TLP_WD ) begin : gen_fx_tlp2rx_tlp_if // [FX_TLP:0]
        assign rasdes_ec_info_cmn_s.int_cfg_poisned_tlp[ii] = cfg_poisned_tlp[ii] ;
        assign rasdes_ec_info_cmn_s.int_cfg_ecrc_tlp_err[ii] = cfg_ecrc_tlp_err[ii] ;
        assign rasdes_ec_info_cmn_s.int_cfg_ur_tlp[ii] = cfg_ur_tlp[ii] ;
        assign rasdes_ec_info_cmn_s.int_cfg_ca_tlp[ii] = cfg_ca_tlp[ii] ;
      end else begin : gen_fx_tlp2rx_tlp_else
        assign rasdes_ec_info_cmn_s.int_cfg_poisned_tlp[ii] = 1'b0 ;
        assign rasdes_ec_info_cmn_s.int_cfg_ecrc_tlp_err[ii] = 1'b0 ;
        assign rasdes_ec_info_cmn_s.int_cfg_ur_tlp[ii] = 1'b0 ;
        assign rasdes_ec_info_cmn_s.int_cfg_ca_tlp[ii] = 1'b0 ;
      end
    end

    for (ii=0; ii<INT_RX_TLP; ii=ii+1) begin : gen_rx_tlp_for
      if ( ii<RX_TLP ) begin : gen_rx_tlp_if
        assign rasdes_ec_info_cmn_s.int_rdlh_bad_tlp_err_pertlp[ii] = rdlh_bad_tlp_err_pertlp[ii] ;
        assign rasdes_ec_info_cmn_s.int_rdlh_lcrc_tlp_err_pertlp[ii] = rdlh_lcrc_tlp_err_pertlp[ii] ;
        assign rasdes_ec_info_cmn_s.int_rdlh_nulified_tlp_err_pertlp[ii] = rdlh_nulified_tlp_err_pertlp[ii] ;
        assign rasdes_ec_info_cmn_s.int_rdlh_duplicate_tlp_err_pertlp[ii] = rdlh_duplicate_tlp_err_pertlp[ii] ;
        assign rasdes_ec_info_cmn_s.int_rtlh_rx_memwr_evt[ii] = rtlh_rx_memwr_evt[ii] ;
        assign rasdes_ec_info_cmn_s.int_rtlh_rx_defmemwr_evt[ii] = rtlh_rx_defmemwr_evt[ii] ;
        assign rasdes_ec_info_cmn_s.int_rtlh_rx_memrd_evt[ii] = rtlh_rx_memrd_evt[ii] ;
        assign rasdes_ec_info_cmn_s.int_rtlh_rx_cfgwr_evt[ii] = rtlh_rx_cfgwr_evt[ii] ;
        assign rasdes_ec_info_cmn_s.int_rtlh_rx_cfgrd_evt[ii] = rtlh_rx_cfgrd_evt[ii] ;
        assign rasdes_ec_info_cmn_s.int_rtlh_rx_iowr_evt[ii] = rtlh_rx_iowr_evt[ii] ;
        assign rasdes_ec_info_cmn_s.int_rtlh_rx_iord_evt[ii] = rtlh_rx_iord_evt[ii] ;
        assign rasdes_ec_info_cmn_s.int_rtlh_rx_cplwod_evt[ii] = rtlh_rx_cplwod_evt[ii] ;
        assign rasdes_ec_info_cmn_s.int_rtlh_rx_cplwd_evt[ii] = rtlh_rx_cplwd_evt[ii] ;
        assign rasdes_ec_info_cmn_s.int_rtlh_rx_msg_evt[ii] = rtlh_rx_msg_evt[ii] ;
        assign rasdes_ec_info_cmn_s.int_rtlh_rx_atmcop_evt[ii] = rtlh_rx_atmcop_evt[ii] ;
        assign rasdes_ec_info_cmn_s.int_rtlh_rx_tlpwprefix_evt[ii] = rtlh_rx_tlpwprefix_evt[ii] ;
        assign rasdes_ec_info_cmn_s.int_rtlh_rx_ccix_tlp_evt[ii] = 1'b0 ;
      end else begin : gen_rx_tlp_else
        assign rasdes_ec_info_cmn_s.int_rdlh_bad_tlp_err_pertlp[ii] = 1'b0 ;
        assign rasdes_ec_info_cmn_s.int_rdlh_lcrc_tlp_err_pertlp[ii] = 1'b0 ;
        assign rasdes_ec_info_cmn_s.int_rdlh_nulified_tlp_err_pertlp[ii] = 1'b0 ;
        assign rasdes_ec_info_cmn_s.int_rdlh_duplicate_tlp_err_pertlp[ii] = 1'b0 ;
        assign rasdes_ec_info_cmn_s.int_rtlh_rx_memwr_evt[ii] = 1'b0 ;
        assign rasdes_ec_info_cmn_s.int_rtlh_rx_defmemwr_evt[ii] = 1'b0 ;
        assign rasdes_ec_info_cmn_s.int_rtlh_rx_memrd_evt[ii] = 1'b0 ;
        assign rasdes_ec_info_cmn_s.int_rtlh_rx_cfgwr_evt[ii] = 1'b0 ;
        assign rasdes_ec_info_cmn_s.int_rtlh_rx_cfgrd_evt[ii] = 1'b0 ;
        assign rasdes_ec_info_cmn_s.int_rtlh_rx_iowr_evt[ii] = 1'b0 ;
        assign rasdes_ec_info_cmn_s.int_rtlh_rx_iord_evt[ii] = 1'b0 ;
        assign rasdes_ec_info_cmn_s.int_rtlh_rx_cplwod_evt[ii] = 1'b0 ;
        assign rasdes_ec_info_cmn_s.int_rtlh_rx_cplwd_evt[ii] = 1'b0 ;
        assign rasdes_ec_info_cmn_s.int_rtlh_rx_msg_evt[ii] = 1'b0 ;
        assign rasdes_ec_info_cmn_s.int_rtlh_rx_atmcop_evt[ii] = 1'b0 ;
        assign rasdes_ec_info_cmn_s.int_rtlh_rx_tlpwprefix_evt[ii] = 1'b0 ;
        assign rasdes_ec_info_cmn_s.int_rtlh_rx_ccix_tlp_evt[ii] = 1'b0 ;
      end
    end

    for (ii=0; ii<INT_RX_NDLLP; ii=ii+1) begin : gen_rx_ndllp_for
      if ( ii<RX_NDLLP ) begin : gen_rx_ndllp_if
        assign rasdes_ec_info_cmn_s.int_rdlh_bad_dllp_err_perdllp[ii] = rdlh_bad_dllp_err_perdllp[ii] ;
        assign rasdes_ec_info_cmn_s.int_rdlh_rcvd_nack_perdllp[ii] = rdlh_rcvd_nack_perdllp[ii] ;
        assign rasdes_ec_info_cmn_s.int_rdlh_rcvd_ack_perdllp[ii] = rdlh_rcvd_ack_perdllp[ii] ;
        assign rasdes_ec_info_cmn_s.int_rtlh_rcvd_ufc_perdllp[ii] = rtlh_rcvd_ufc_perdllp[ii] ;
      end else begin : gen_rx_ndllp_else
        assign rasdes_ec_info_cmn_s.int_rdlh_bad_dllp_err_perdllp[ii] = 1'b0 ;
        assign rasdes_ec_info_cmn_s.int_rdlh_rcvd_nack_perdllp[ii] = 1'b0 ;
        assign rasdes_ec_info_cmn_s.int_rdlh_rcvd_ack_perdllp[ii] = 1'b0 ;
        assign rasdes_ec_info_cmn_s.int_rtlh_rcvd_ufc_perdllp[ii] = 1'b0 ;
      end
    end

    for (ii=0; ii<XADM_NP_MAX; ii=ii+1) begin : gen_num_xadm_np_for
      if ( ii<XADM_NP_IF_WD ) begin : gen_num_xadm_np_if
        assign rasdes_ec_info_cmn_s.int_xtlh_tx_defmemwr_evt[ii] = xtlh_tx_defmemwr_evt[ii];
        assign rasdes_ec_info_cmn_s.int_xtlh_tx_memrd_evt[ii] = xtlh_tx_memrd_evt[ii];
        assign rasdes_ec_info_cmn_s.int_xtlh_tx_cfgwr_evt[ii] = xtlh_tx_cfgwr_evt[ii];
        assign rasdes_ec_info_cmn_s.int_xtlh_tx_cfgrd_evt[ii] = xtlh_tx_cfgrd_evt[ii];
        assign rasdes_ec_info_cmn_s.int_xtlh_tx_iowr_evt[ii] = xtlh_tx_iowr_evt[ii];
        assign rasdes_ec_info_cmn_s.int_xtlh_tx_iord_evt[ii] = xtlh_tx_iord_evt[ii];
        assign rasdes_ec_info_cmn_s.int_xtlh_tx_atmcop_evt[ii] = xtlh_tx_atmcop_evt[ii];
      end else begin : gen_num_xadm_np_else
        assign rasdes_ec_info_cmn_s.int_xtlh_tx_defmemwr_evt[ii] = 1'b0;
        assign rasdes_ec_info_cmn_s.int_xtlh_tx_memrd_evt[ii] = 1'b0;
        assign rasdes_ec_info_cmn_s.int_xtlh_tx_cfgwr_evt[ii] = 1'b0;
        assign rasdes_ec_info_cmn_s.int_xtlh_tx_cfgrd_evt[ii] = 1'b0;
        assign rasdes_ec_info_cmn_s.int_xtlh_tx_iowr_evt[ii] = 1'b0;
        assign rasdes_ec_info_cmn_s.int_xtlh_tx_iord_evt[ii] = 1'b0;
        assign rasdes_ec_info_cmn_s.int_xtlh_tx_atmcop_evt[ii] = 1'b0;
      end
    end

    for (ii=0; ii<XADM_P_MAX; ii=ii+1) begin : gen_num_xadm_p_for
      if ( ii<XADM_P_IF_WD ) begin : gen_num_xadm_p_if
        assign rasdes_ec_info_cmn_s.int_xtlh_tx_memwr_evt[ii] = xtlh_tx_memwr_evt[ii];
        assign rasdes_ec_info_cmn_s.int_xtlh_tx_msg_evt[ii] = xtlh_tx_msg_evt[ii];
      end else begin : gen_num_xadm_p_else
        assign rasdes_ec_info_cmn_s.int_xtlh_tx_memwr_evt[ii] = 1'b0;
        assign rasdes_ec_info_cmn_s.int_xtlh_tx_msg_evt[ii] = 1'b0;
      end
    end

    for (ii=0; ii<XADM_CPL_MAX; ii=ii+1) begin : gen_num_xadm_cpl_for
      if ( ii<XADM_CPL_IF_WD ) begin : gen_num_xadm_cpl_if
        assign rasdes_ec_info_cmn_s.int_xtlh_tx_cplwod_evt[ii] = xtlh_tx_cplwod_evt[ii];
        assign rasdes_ec_info_cmn_s.int_xtlh_tx_cplwd_evt[ii] = xtlh_tx_cplwd_evt[ii];
      end else begin : gen_num_xadm_cpl_else
        assign rasdes_ec_info_cmn_s.int_xtlh_tx_cplwod_evt[ii] = 1'b0;
        assign rasdes_ec_info_cmn_s.int_xtlh_tx_cplwd_evt[ii] = 1'b0;
      end
    end

    for (ii=0; ii<XADM_IF_MAX; ii=ii+1) begin : gen_num_eot_for
      if ( ii<XADM_IF_WD ) begin : gen_num_eot_if
        assign rasdes_ec_info_cmn_s.int_xtlh_tx_tlpwprefix_evt[ii] = xtlh_tx_tlpwprefix_evt[ii];
        assign rasdes_ec_info_cmn_s.int_xadm_tx_nullify_evt[ii] = xadm_tx_nullify_evt[ii];
      end else begin : gen_num_eot_else
        assign rasdes_ec_info_cmn_s.int_xtlh_tx_tlpwprefix_evt[ii] = 1'b0;
        assign rasdes_ec_info_cmn_s.int_xadm_tx_nullify_evt[ii] = 1'b0;
      end
    end

    for (ii=0; ii<CCIX_IF_MAX; ii=ii+1) begin : gen_num_ccix_for
      if ( ii<CCIX_IF_WD ) begin : gen_num_ccix_if
        assign rasdes_ec_info_cmn_s.int_xtlh_tx_ccix_tlp_evt[ii] = 1'b0;
      end else begin : gen_num_ccix_else
        assign rasdes_ec_info_cmn_s.int_xtlh_tx_ccix_tlp_evt[ii] = 1'b0;
      end
    end
  endgenerate

/////////////////////////////////////////// 
// cdm_ras_des_ec_info_common (RTL) 
/////////////////////////////////////////// 

  assign rasdes_ec_info_cmn_s.info_smlh_spd_change = smlh_spd_change ;

  assign rasdes_ec_info_cmn_s.info_pm_in_l1_abort = pm_in_l1_abort ;
  assign rasdes_ec_info_cmn_s.info_pm_in_l1_cpm = pm_in_l1_cpm ;
  assign rasdes_ec_info_cmn_s.info_pm_in_l1_short = pm_in_l1_short ;

  assign rasdes_ec_info_cmn_s.info_rmlh_framing_err      = rmlh_framing_err ;
  assign rasdes_ec_info_cmn_s.info_rmlh_framing_err_l0   = rmlh_framing_err_l0 ;

  assign info_cxl_vlsm_lrsm_req_retrain = cxl_vlsm_lrsm_req_retrain ;
  assign rasdes_ec_info_cmn_s.info_cxl_vlsm_unexp_error      = cxl_vlsm_unexp_error ;
  assign rasdes_ec_info_cmn_s.info_cxl_almp_rx_repl_error    = cxl_almp_rx_repl_error ;


  assign rasdes_ec_info_cmn_s.info_rpa_rx_rrap_sts = 5'd0 ;

  // Syn timing
  always @ ( posedge aux_clk or negedge sticky_rst_n ) begin
    if ( !sticky_rst_n ) begin
      rtlh_req_link_retrain_d          <= #TP 1'b0 ;
      info_cxl_vlsm_lrsm_req_retrain_d <= #TP 1'b0 ;
    end else begin
      rtlh_req_link_retrain_d          <= #TP rtlh_req_link_retrain ;
      info_cxl_vlsm_lrsm_req_retrain_d <= #TP info_cxl_vlsm_lrsm_req_retrain ;
    end
  end

  // Make posedge signal
  assign rasdes_ec_info_cmn_s.rtlh_req_link_retrain_pulse          = rtlh_req_link_retrain          & ~rtlh_req_link_retrain_d ;
  assign rasdes_ec_info_cmn_s.info_cxl_vlsm_lrsm_req_retrain_pulse = info_cxl_vlsm_lrsm_req_retrain & ~info_cxl_vlsm_lrsm_req_retrain_d ;

  always @(*) begin
    cdm_ras_des_ec_info_common = {
                     rasdes_ec_info_cmn.info_cxl_vlsm_lrsm_req_retrain_pulse, // [191]    : Pulse: (CXL only) NUM_RETRY reached MAX_NUM_RETRY (L0 to Recovery transition trigger)
                     rasdes_ec_info_cmn.info_cxl_vlsm_unexp_error,         // [190]    : Pulse: (CXL only) unexpected ALMP error (L0 to Recovery transition trigger)
                     rasdes_ec_info_cmn.info_cxl_almp_rx_repl_error,       // [189]    : Pulse: (CXL only) ALMP Replication error (L0 to Recovery transition trigger)
                     rasdes_ec_info_cmn.smlh_deskew_uncomplete_err,        // [188]    : Pulse: Deskew uncompleted error (L0 to Recovery transition trigger)
                     rasdes_ec_info_cmn.info_rmlh_framing_err_l0,        // [187]    : Pulse: Framing Error in L0 state (L0 to Recovery transition trigger)
                     rasdes_ec_info_cmn.smlh_rcv_eios_when_l0s_unsprt,     // [186]    : Pulse: Received EIOS when L0s is not supported and not directed L1 or L2. (L0 to Recovery transition trigger)
                     rasdes_ec_info_cmn.int_rtlh_rx_defmemwr_evt,          // [185:182]: Pulse: Rx Deferrable Memory Write
                     rasdes_ec_info_cmn.int_xtlh_tx_defmemwr_evt,          // [181:180]: Pulse: Tx Deferrable Memory Write 
                     rasdes_ec_info_cmn.int_rtlh_rx_ccix_tlp_evt,          // [179:176]: Pulse: Rx CCIX TLP 
                     rasdes_ec_info_cmn.int_xtlh_tx_ccix_tlp_evt,          // [175:174]: Pulse: Tx CCIX TLP 
                     rasdes_ec_info_cmn.int_rtlh_rx_tlpwprefix_evt,       // [173:170]: Pulse: Rx TLP with Prefix
                     rasdes_ec_info_cmn.int_rtlh_rx_atmcop_evt,           // [169:166]: Pulse: Rx Atomic
                     rasdes_ec_info_cmn.int_rtlh_rx_msg_evt,               // [165:162]: Pulse: Rx Message TLP
                     rasdes_ec_info_cmn.int_rtlh_rx_cplwd_evt,             // [161:158]: Pulse: Rx Completion w data
                     rasdes_ec_info_cmn.int_rtlh_rx_cplwod_evt,            // [157:154]: Pulse: Rx Completion wo data
                     rasdes_ec_info_cmn.int_rtlh_rx_iord_evt,              // [153:150]: Pulse: Rx IO Read
                     rasdes_ec_info_cmn.int_rtlh_rx_iowr_evt,              // [149:146]: Pulse: Rx IO Write
                     rasdes_ec_info_cmn.int_rtlh_rx_cfgrd_evt,             // [145:142]: Pulse: Rx Config Read
                     rasdes_ec_info_cmn.int_rtlh_rx_cfgwr_evt,             // [141:138]: Pulse: Rx Config Write
                     rasdes_ec_info_cmn.int_rtlh_rx_memrd_evt,             // [137:134]: Pulse: Rx Memory Read
                     rasdes_ec_info_cmn.int_rtlh_rx_memwr_evt,             // [133:130]: Pulse: Rx Memory Write
                     rasdes_ec_info_cmn.int_xtlh_tx_tlpwprefix_evt,        // [129:124]: Pulse: Tx TLP with Prefix
                     rasdes_ec_info_cmn.int_xtlh_tx_atmcop_evt,            // [123:122]: Pulse: Tx AtomicOP TLP
                     rasdes_ec_info_cmn.int_xtlh_tx_msg_evt,               // [121:120]: Pulse: Tx Message TLP
                     rasdes_ec_info_cmn.int_xtlh_tx_cplwd_evt,             // [119:118]: Pulse: Tx Completion w data
                     rasdes_ec_info_cmn.int_xtlh_tx_cplwod_evt,            // [117:116]: Pulse: Tx Completion wo data
                     rasdes_ec_info_cmn.int_xtlh_tx_iord_evt,              // [115:114]: Pulse: Tx IO Read
                     rasdes_ec_info_cmn.int_xtlh_tx_iowr_evt,              // [113:112]: Pulse: Tx IO Write
                     rasdes_ec_info_cmn.int_xtlh_tx_cfgrd_evt,             // [111:110]: Pulse: Tx Config Read
                     rasdes_ec_info_cmn.int_xtlh_tx_cfgwr_evt,             // [109:108]: Pulse: Tx Config Write
                     rasdes_ec_info_cmn.int_xtlh_tx_memrd_evt,             // [107:106]: Pulse: Tx Memory Read
                     rasdes_ec_info_cmn.int_xtlh_tx_memwr_evt,             // [105:104]: Pulse: Tx Memory Write
                     rasdes_ec_info_cmn.int_rdlh_duplicate_tlp_err_pertlp, // [103:100]: Pulse: Rx Duplicate TLP
                     rasdes_ec_info_cmn.int_xadm_tx_nullify_evt,           // [99:94]: Pulse: Tx Nullified TLP
                     rasdes_ec_info_cmn.int_rdlh_nulified_tlp_err_pertlp,  // [93:90]: Pulse: Rx Nullified TLP
                     rasdes_ec_info_cmn.int_rtlh_rcvd_ufc_perdllp,         // [89:82]: Pulse: Rx Update FC DLLP
                     rasdes_ec_info_cmn.int_rdlh_rcvd_ack_perdllp,         // [81:74]: Pulse: Rx Ack DLLP
                     rasdes_ec_info_cmn.xdlh_update_fc_sent,               // [73]: Pulse: Tx Update FC DLLP
                     rasdes_ec_info_cmn.xdlh_ack_sent,                     // [72]: Pulse: Tx Ack DLLP
                     rasdes_ec_info_cmn.smlh_lwd_change,                   // [71]: Pulse: Link width Change
                     rasdes_ec_info_cmn.info_smlh_spd_change,              // [70]: Pulse: Speed Change
                     rasdes_ec_info_cmn.smlh_in_l23,                       // [69]: Level: L2 Entry
                     rasdes_ec_info_cmn.info_pm_in_l1_abort,               // [68]: Level: L1.2 abort
                     rasdes_ec_info_cmn.info_pm_in_l1_cpm,                 // [67]: Level: L1 Clock PM (L1 with REFCLK removal/PLL Off)
                     rasdes_ec_info_cmn.info_pm_in_l1_short,               // [66]: Level: L1 short duration
                     rasdes_ec_info_cmn.info_pm_in_l12,                    // [65]: Level: L1.2 Entry
                     rasdes_ec_info_cmn.info_pm_in_l11,                    // [64]: Level: L1.1 Entry
                     rasdes_ec_info_cmn.smlh_in_l1,                        // [63]: Level: L1 Entry
                     rasdes_ec_info_cmn.pm_asnak,                          // [62]: Level: ASPM L1 reject
                     rasdes_ec_info_cmn.smlh_in_rl0s,                      // [61]: Level: Rx L0s Entry
                     rasdes_ec_info_cmn.smlh_in_l0s,                       // [60]: Level: Tx L0s Entry
                     rasdes_ec_info_cmn.smlh_l1_to_recovery,               // [59]: Pulse: L1 to Recovery Entry
                     rasdes_ec_info_cmn.smlh_l0_to_recovery,               // [58]: Pulse: L0 to Recovery Entry
                     rasdes_ec_info_cmn.cfg_cpl_timeout,                   // [57:56]: Pulse: Completion Timeout
                     rasdes_ec_info_cmn.int_cfg_ca_tlp,                    // [55:52]: Pulse: Completer Abort
                     rasdes_ec_info_cmn.int_cfg_ur_tlp,                    // [51:48]: Pulse: Unsupported Request
                     rasdes_ec_info_cmn.int_cfg_ecrc_tlp_err,              // [47:44]: Pulse: ECRC Error
                     rasdes_ec_info_cmn.int_cfg_poisned_tlp,               // [43:40]: Pulse: Poisoned TLP
                     rasdes_ec_info_cmn.rtlh_req_link_retrain_pulse,       // [39]: Pulse: FC Timeout
                     rasdes_ec_info_cmn.xdlh_retry_req,                    // [38]: Pulse: Retry TLP
                     rasdes_ec_info_cmn.xdlh_nak_sent,                     // [37]: Pulse: Tx Nak DLLP
                     rasdes_ec_info_cmn.int_rdlh_rcvd_nack_perdllp,        // [36:29]: Pulse: Rx Nak DLLP
                     rasdes_ec_info_cmn.xdlh_replay_timeout_err,           // [28]: Pulse: Replay Timeout
                     rasdes_ec_info_cmn.xdlh_replay_num_rlover_err,        // [27]: Pulse: Replay_Num Rollover
                     rasdes_ec_info_cmn.int_rdlh_bad_dllp_err_perdllp,     // [26:19]: Pulse: BAD DLLP
                     rasdes_ec_info_cmn.int_rdlh_lcrc_tlp_err_pertlp,      // [18:15]: Pulse: LCRC Error
                     rasdes_ec_info_cmn.int_rdlh_bad_tlp_err_pertlp,       // [14:11]: Pulse: BAD TLP
                     rasdes_ec_info_cmn.rmlh_deskew_alignment_err,         // [10]: Pulse: Deskew Error
                     rasdes_ec_info_cmn.info_rmlh_framing_err,             // [9]: Pulse: Framing Error
                     rasdes_ec_info_cmn.smlh_timeout_nfts,                 // [8]: Level: FTS Timeout
                     rasdes_ec_info_cmn.smlh_rx_rcvry_req,                 // [7]: Level: Rx Recovery Request
                     rasdes_ec_info_cmn.rmlh_rcvd_err,                     // [6]: Pulse: Receiver Error
                     rasdes_ec_info_cmn.smlh_eidle_inferred_in_l0,         // [5]: Level: Detect EI Infer
                     rasdes_ec_info_cmn.info_rpa_rx_rrap_sts[4],           // [4]: Pulse: RRAP Address Error
                     rasdes_ec_info_cmn.info_rpa_rx_rrap_sts[3],           // [3]: Pulse: RRAP unexpected response
                     rasdes_ec_info_cmn.info_rpa_rx_rrap_sts[2],           // [2]: Pulse: RRAP Parity Error
                     rasdes_ec_info_cmn.info_rpa_rx_rrap_sts[1],           // [1]: Pulse: RRAP Abort
                     rasdes_ec_info_cmn.info_rpa_rx_rrap_sts[0]            // [0]: Pulse: RRAP Timeout
                     } ;
  end
/////////////////////////////////////////// 
// cdm_ras_des_ec_info_ln (RTL) 
/////////////////////////////////////////// 
  assign info_rmlh_sync_header_err = rmlh_sync_header_err ;
  assign info_rmlh_skp_parity_err = rmlh_skp_parity_err ;

  assign info_rmlh_deskew_ctlskp_err = rmlh_deskew_ctlskp_err;

  reg     [RASDES_EC_INFO_PL-1:0]    cdm_ras_des_ec_info_l[0:NL-1] ;
  reg     [RASDES_EC_INFO_PL-1:0]    pre_cdm_ras_des_ec_info_l[0:NL-1] ;
  generate
    for (ln=0; ln<NL; ln=ln+1) begin : gen_pre_cdm_ras_des_ec_info_l
      always @(*) begin
        pre_cdm_ras_des_ec_info_l[ln] = {
                     |info_rmlh_deskew_ctlskp_err[ln*5+3+:2], // [12]: Pulse: Margin CRC and Parity Error
                     info_rmlh_deskew_ctlskp_err[ln*5+2],         // [11]: Pulse: 2nd Retimer Parity Error
                     info_rmlh_deskew_ctlskp_err[ln*5+1],         // [10]: Pulse: 1st Retimer Parity Error
                     info_rmlh_deskew_ctlskp_err[ln*5],           // [9]: Pulse: CTL SKP OS Data Parity Error
                     rmlh_rxskipremoved[ln],                      // [8]: Pulse: EBUF SKP Del
                     rmlh_rxskipadded[ln],                        // [7]: Pulse: EBUF SKP Add
                     rmlh_rxvalid_deasserted[ln],                 // [6]: Pulse: Rx Valid de-assertion
                     info_rmlh_sync_header_err[ln],               // [5]: Pulse: SYNC Header Error
                     info_rmlh_skp_parity_err[ln],                // [4]: Pulse: SKP OS Parity Error
                     rmlh_phy_rxdisperror[ln],                    // [3]: Pulse: Running Disparity Error
                     rmlh_phy_rxcodeerror[ln],                    // [2]: Pulse: 8b10b Error
                     rmlh_ebuf_rxunderflow[ln],                   // [1]: Pulse: EBUF underrun
                     rmlh_ebuf_rxoverflow[ln]                     // [0]: Pulse: EBUF Overflow
                     };
      end
      // Syn timing
      always @ ( posedge aux_clk or negedge sticky_rst_n ) begin
        if ( !sticky_rst_n ) begin
          cdm_ras_des_ec_info_l[ln] <= #TP {RASDES_EC_INFO_PL{1'b0}} ;
        end else begin
          cdm_ras_des_ec_info_l[ln] <= #TP pre_cdm_ras_des_ec_info_l[ln] ;
        end
      end
    end // for
  endgenerate

  assign cdm_ras_des_ec_info_l0 = cdm_ras_des_ec_info_l[0] ;
  assign cdm_ras_des_ec_info_l1 = cdm_ras_des_ec_info_l[1] ;
  assign cdm_ras_des_ec_info_l2 = cdm_ras_des_ec_info_l[2] ;
  assign cdm_ras_des_ec_info_l3 = cdm_ras_des_ec_info_l[3] ;
  assign cdm_ras_des_ec_info_l4 = cdm_ras_des_ec_info_l[4] ;
  assign cdm_ras_des_ec_info_l5 = cdm_ras_des_ec_info_l[5] ;
  assign cdm_ras_des_ec_info_l6 = cdm_ras_des_ec_info_l[6] ;
  assign cdm_ras_des_ec_info_l7 = cdm_ras_des_ec_info_l[7] ;

/////////////////////////////////////////// 
// cdm_ras_des_sd_info_common (RTL) 
/////////////////////////////////////////// 
  // Switching 0 or variable

  assign rasdes_sd_info_cmn_s.info_init_eq_pending_g5 = init_eq_pending_g5 ;
  assign rasdes_sd_info_l_s.info_eq_convergence_sts_g5 = eq_convergence_sts_g5 ;
  assign rasdes_sd_info_l_s.info_eqpa_violate_rule_123_g5 = eqpa_violate_rule_123_g5 ;
  assign rasdes_sd_info_l_s.info_phy_cdm_ras_des_fomfeedback_g5 = phy_cdm_ras_des_fomfeedback_g5 ;
  assign rasdes_sd_info_l_s.info_mac_cdm_ras_des_coef_ltx_g5 = mac_cdm_ras_des_coef_ltx_g5 ;
  assign rasdes_sd_info_l_s.info_mac_cdm_ras_des_lf_g5 = mac_cdm_ras_des_lf_g5 ;
  assign rasdes_sd_info_l_s.info_mac_cdm_ras_des_fs_g5 = mac_cdm_ras_des_fs_g5 ;
  assign rasdes_sd_info_l_s.info_mac_cdm_ras_des_coef_rtx_g5 = mac_cdm_ras_des_coef_rtx_g5 ;
  assign rasdes_sd_info_l_s.info_mac_cdm_ras_des_reject_rtx_g5 = mac_cdm_ras_des_reject_rtx_g5 ;
  assign rasdes_sd_info_cmn_s.info_init_eq_pending_g4 = init_eq_pending_g4 ;
  assign rasdes_sd_info_l_s.info_eq_convergence_sts_g4 = eq_convergence_sts_g4 ;
  assign rasdes_sd_info_l_s.info_eqpa_violate_rule_123_g4 = eqpa_violate_rule_123_g4 ;
  assign rasdes_sd_info_l_s.info_phy_cdm_ras_des_fomfeedback_g4 = phy_cdm_ras_des_fomfeedback_g4 ;
  assign rasdes_sd_info_l_s.info_mac_cdm_ras_des_coef_ltx_g4 = mac_cdm_ras_des_coef_ltx_g4 ;
  assign rasdes_sd_info_l_s.info_mac_cdm_ras_des_lf_g4 = mac_cdm_ras_des_lf_g4 ;
  assign rasdes_sd_info_l_s.info_mac_cdm_ras_des_fs_g4 = mac_cdm_ras_des_fs_g4 ;
  assign rasdes_sd_info_l_s.info_mac_cdm_ras_des_coef_rtx_g4 = mac_cdm_ras_des_coef_rtx_g4 ;
  assign rasdes_sd_info_l_s.info_mac_cdm_ras_des_reject_rtx_g4 = mac_cdm_ras_des_reject_rtx_g4 ;
  assign rasdes_sd_info_cmn_s.info_rmlh_framing_err_ptr = rmlh_framing_err_ptr ;
  assign rasdes_sd_info_cmn_s.info_init_eq_pending = init_eq_pending ;
  assign rasdes_sd_info_l_s.info_eq_convergence_sts = eq_convergence_sts ;
  assign rasdes_sd_info_l_s.info_eqpa_violate_rule_123 = eqpa_violate_rule_123 ;
  assign rasdes_sd_info_l_s.info_phy_cdm_ras_des_fomfeedback = phy_cdm_ras_des_fomfeedback ;
  assign rasdes_sd_info_l_s.info_mac_cdm_ras_des_coef_ltx = mac_cdm_ras_des_coef_ltx ;
  assign rasdes_sd_info_l_s.info_mac_cdm_ras_des_lf = mac_cdm_ras_des_lf ;
  assign rasdes_sd_info_l_s.info_mac_cdm_ras_des_fs = mac_cdm_ras_des_fs ;
  assign rasdes_sd_info_l_s.info_mac_cdm_ras_des_coef_rtx = mac_cdm_ras_des_coef_rtx ;
  assign rasdes_sd_info_l_s.info_mac_cdm_ras_des_pset_lrx = mac_cdm_ras_des_pset_lrx ;
  assign rasdes_sd_info_l_s.info_mac_cdm_ras_des_reject_rtx = mac_cdm_ras_des_reject_rtx ;
  assign rasdes_sd_info_l_s.info_orig_pipe_rxstartblock = orig_pipe_rxstartblock ;
  assign rasdes_sd_info_l_s.info_orig_pipe_rxsyncheader = orig_pipe_rxsyncheader ;
  assign rasdes_sd_info_cmn_s.info_orig_pipe_blockaligncontrol = orig_pipe_blockaligncontrol ;
  assign rasdes_sd_info_cmn_s.info_l1sub_state = l1sub_state;


  assign rasdes_sd_info_l_s.info_mac_phy_rxpolarity = mac_phy_rxpolarity ;
  assign rasdes_sd_info_l_s.info_latched_rxdetected = latched_rxdetected ;

  always @(*) begin
    cdm_ras_des_sd_info_common = {
                  rasdes_sd_info_cmn.init_eq_pending_g6,                   // [91]: Level: Equalization sequence Gen6
                  rasdes_sd_info_cmn.pm_usp_prot_state,                    // [90:87]: Level: PM Internal State (USP Protocol FSM State)
                  rasdes_sd_info_cmn.pm_usp_link_state,                    // [86:83]: Level: PM Internal State (DSP Link FSM State)
                  rasdes_sd_info_cmn.pm_l0s_state,                         // [82:80]: Level: PM Internal State (L0S FSM State)
                  rasdes_sd_info_cmn.info_orig_pipe_blockaligncontrol,     // [79]: orig_pipe_blockaligncontrol: Level: Origial PIPE BlockAlignControl
                  rasdes_sd_info_cmn.info_init_eq_pending_g5,              // [78]: Level: Equalization sequence Gen5
                  rasdes_sd_info_cmn.info_l1sub_state,                     // [77:75] Level: L1 sub state
                  rasdes_sd_info_cmn.info_init_eq_pending_g4,              // [74]: Level: Equalization sequence Gen4
                  rasdes_sd_info_cmn.info_init_eq_pending,                 // [73]: Level: Equalization sequence Gen3
                  rasdes_sd_info_cmn.xdlh_xplh_curnt_seqnum,               // [72:61]: Level: Tx TLP SEQ#
                  rasdes_sd_info_cmn.rdlh_xplh_curnt_rx_ack_seqnum,        // [60:49]: Level: Rx ACK SEQ#
                  rasdes_sd_info_cmn.rdlh_vc0_initfc2_status,              // [48]: Level: Init-FC Flag2 VC0
                  rasdes_sd_info_cmn.rdlh_vc0_initfc1_status,              // [47]: Level: Init-FC Flag1 VC0
                  rasdes_sd_info_cmn.rdlh_dlcntrl_state,                   // [46:45]: Level: DLCM
                  rasdes_sd_info_cmn.latched_ts_nfts,                      // [44:37]: Level: Latched NFTS
                  1'b0,                                                    // [36] : Reserved for Power Down[2]
                  rasdes_sd_info_cmn.ltssm_powerdown,                      // [35:34]: Level: PIPE: Power Down
                  rasdes_sd_info_cmn.smlh_ltssm_variable,                  // [33:18]: Level: LTSSM Variable
                  rasdes_sd_info_cmn.pm_pme_resend_flag,                   // [17]: Pulse: PME Re-Send flag
                  rasdes_sd_info_cmn.smlh_lane_reversed,                   // [16]: Level: Lane Reversal Operation
                  rasdes_sd_info_cmn.info_rmlh_framing_err_ptr,            // [15:9]: Pulse: 1st Framing Error Pointer
                  1'b0,                                                    // [8] : Reserved for Power Down
                  rasdes_sd_info_cmn.pm_dsp_prot_state,                    // [7:4]: Level: PM Internal State (DSP Protocol FSM State)
                  rasdes_sd_info_cmn.pm_dsp_link_state                     // [3:0]: Level: PM Internal State (DSP Link FSM State)
                 } ;
  end

/////////////////////////////////////////// 
// cdm_ras_des_sd_info_ln (RTL) 
/////////////////////////////////////////// 
  logic   [RASDES_SD_INFO_PL-1:0]     cdm_ras_des_sd_info_l[0:NL-1] ;

  generate
   for (ln=0; ln<NL; ln=ln+1) begin : gen_cdm_ras_des_sd_info_l
     always @(*) begin
       cdm_ras_des_sd_info_l[ln] = {
                     rasdes_sd_info_l.orig_pipe_rxdatak[PHY_NB*ln +: PHY_NB],                               // [N3:N2+1](N3 = N2 + PHY_NB - 1): orig_pipe_rxdatak: Level: Origial PIPE RxDataK
                     rasdes_sd_info_l.orig_pipe_rxdata[(PHY_NB*8)*ln +: (PHY_NB*8)],                        // [N2:N1+1](N2 = N1 + (PHY_NB * 8) - 1): orig_pipe_rxdata: Level: Origial PIPE RxData
                     rasdes_sd_info_l.info_orig_pipe_rxsyncheader[PHY_RXSH_WD*ln +: PHY_RXSH_WD],           // [N1:N0+1](N1 = N0 + PHY_RXSH_WD - 1): orig_pipe_rxsyncheader: Level: Origial PIPE RxSyncHeader
                     rasdes_sd_info_l.info_orig_pipe_rxstartblock[PHY_RXSB_WD*ln +: PHY_RXSB_WD],           // [N0:209](N0 = 209 + PHY_RXSB_WD - 1): orig_pipe_rxstartblock: Level: Origial PIPE RxStartBlock
                     rasdes_sd_info_l.orig_pipe_rxdatavalid[ln +: 1],                                       // [208]: orig_pipe_rxdatavalid: Level: Origial PIPE RxDataValid
                     rasdes_sd_info_l.orig_pipe_rxstatus[3*ln +: 3],                                        // [207:205]: orig_pipe_rxstatus : pulse : Origial PIPE RxStatus
                     rasdes_sd_info_l.eq_convergence_sts_g6[2*ln +: 2],                                           // [267:266]: Level: Equalization convergence information Gen6
                     rasdes_sd_info_l.eqpa_violate_rule_4_g6[ln +: 1],                                            // [265]: Level: Rule D Violation Event Status Gen6
                     rasdes_sd_info_l.eqpa_violate_rule_123_g6[3*ln+2 +: 1],                                      // [264]: Level: Rule C Violation Event Status Gen6
                     rasdes_sd_info_l.eqpa_violate_rule_123_g6[3*ln+1 +: 1],                                      // [263]: Level: Rule B Violation Event Status Gen6
                     rasdes_sd_info_l.eqpa_violate_rule_123_g6[3*ln +: 1],                                        // [262]: Level: Rule A Violation Event Status Gen6
                     rasdes_sd_info_l.mac_cdm_ras_des_reject_rtx_g6[ln +: 1],                                     // [261]: Level: Receive Reject Coefficient Event status Gen6
                     rasdes_sd_info_l.phy_cdm_ras_des_fomfeedback_g6[FOMFEEDBACK_WD*ln +: 8],                     // [260:253]: Level: Current Figure of Merit Gen6
                     rasdes_sd_info_l.mac_cdm_ras_des_coef_ltx_g6[TX_COEF_WD*ln +: 3],                            // [252:250]: Level: Current Local Transmitter 2nd Pre Cursor coefficient Gen6
                     rasdes_sd_info_l.mac_cdm_ras_des_coef_ltx_g6[TX_COEF_WD*ln+3 +: 4],                          // [249:246]: Level: Current Local Transmitter Pre Cursor coefficient Gen6
                     rasdes_sd_info_l.mac_cdm_ras_des_coef_ltx_g6[TX_COEF_WD*ln+7 +: 6],                          // [245:240]: Level: Current Local Transmitter Cursor coefficient Gen6
                     rasdes_sd_info_l.mac_cdm_ras_des_coef_ltx_g6[TX_COEF_WD*ln+13 +: 5],                         // [239:235]: Level: Current Local Transmitter Post Cursor coefficient Gen6
                     rasdes_sd_info_l.mac_cdm_ras_des_coef_rtx_g6[TX_COEF_WD*ln +: 3],                            // [234:232]: Level: Current Remote Transmitter 2nd Pre Cursor coefficient Gen6
                     rasdes_sd_info_l.mac_cdm_ras_des_coef_rtx_g6[TX_COEF_WD*ln+3 +: 4],                          // [231:228]: Level: Current Remote Transmitter Pre Cursor coefficient Gen6
                     rasdes_sd_info_l.mac_cdm_ras_des_coef_rtx_g6[TX_COEF_WD*ln+7 +: 6],                          // [227:222]: Level: Current Remote Transmitter Cursor coefficient Gen6
                     rasdes_sd_info_l.mac_cdm_ras_des_coef_rtx_g6[TX_COEF_WD*ln+13 +: 5],                         // [221:217]: Level: Current Remote Transmitter Post Cursor coefficient Gen6
                     rasdes_sd_info_l.mac_cdm_ras_des_lf_g6[TX_FS_WD*ln +: 6],                                    // [216:211]: Level: Remote Device LF Gen6
                     rasdes_sd_info_l.mac_cdm_ras_des_fs_g6[TX_FS_WD*ln +: 6],                                    // [210:205]: Level: Remote Device FS Gen6
                     rasdes_sd_info_l.info_eq_convergence_sts_g5[2*ln +: 2],                                // [204:203]: Level: Equalization convergence information Gen5
                     rasdes_sd_info_l.info_eqpa_violate_rule_123_g5[3*ln+2 +: 1],                           // [202]: Level: Rule C Violation Event Status Gen5
                     rasdes_sd_info_l.info_eqpa_violate_rule_123_g5[3*ln+1 +: 1],                           // [201]: Level: Rule B Violation Event Status Gen5
                     rasdes_sd_info_l.info_eqpa_violate_rule_123_g5[3*ln +: 1],                             // [200]: Level: Rule A Violation Event Status Gen5
                     rasdes_sd_info_l.info_mac_cdm_ras_des_reject_rtx_g5[ln +: 1],                          // [199]: Level: Receive Reject Coefficient Event status Gen5
                     rasdes_sd_info_l.info_phy_cdm_ras_des_fomfeedback_g5[FOMFEEDBACK_WD*ln +: 8],          // [198:191]: Level: Current Figure of Merit Gen5
                     rasdes_sd_info_l.info_mac_cdm_ras_des_coef_ltx_g5[TX_COEF_WD*ln +: 6],                 // [190:185]: Level: Current Local Transmitter Pre Cursor coefficient Gen5
                     rasdes_sd_info_l.info_mac_cdm_ras_des_coef_ltx_g5[TX_COEF_WD*ln+6 +: 6],               // [184:179]: Level: Current Local Transmitter Cursor coefficient Gen5
                     rasdes_sd_info_l.info_mac_cdm_ras_des_coef_ltx_g5[TX_COEF_WD*ln+12 +: 6],              // [178:173]: Level: Current Local Transmitter Post Cursor coefficient Gen5
                     rasdes_sd_info_l.info_mac_cdm_ras_des_coef_rtx_g5[TX_COEF_WD*ln +: 6],                 // [172:167]: Level: Current Remote Transmitter Pre Cursor coefficient Gen5
                     rasdes_sd_info_l.info_mac_cdm_ras_des_coef_rtx_g5[TX_COEF_WD*ln+6 +: 6],               // [166:161]: Level: Current Remote Transmitter Cursor coefficient Gen5
                     rasdes_sd_info_l.info_mac_cdm_ras_des_coef_rtx_g5[TX_COEF_WD*ln+12 +: 6],              // [160:155]: Level: Current Remote Transmitter Post Cursor coefficient Gen5
                     rasdes_sd_info_l.info_mac_cdm_ras_des_lf_g5[TX_FS_WD*ln +: 6],                         // [154:149]: Level: Remote Device LF Gen5
                     rasdes_sd_info_l.info_mac_cdm_ras_des_fs_g5[TX_FS_WD*ln +: 6],                         // [148:143]: Level: Remote Device FS Gen5
                     rasdes_sd_info_l.info_eq_convergence_sts_g4[2*ln +: 2],                                // [142:141]: Level: Equalization convergence information Gen4
                     rasdes_sd_info_l.info_eqpa_violate_rule_123_g4[3*ln+2 +: 1],                           // [140]: Level: Rule C Violation Event Status Gen4
                     rasdes_sd_info_l.info_eqpa_violate_rule_123_g4[3*ln+1 +: 1],                           // [139]: Level: Rule B Violation Event Status Gen4
                     rasdes_sd_info_l.info_eqpa_violate_rule_123_g4[3*ln +: 1],                             // [138]: Level: Rule A Violation Event Status Gen4
                     rasdes_sd_info_l.info_mac_cdm_ras_des_reject_rtx_g4[ln +: 1],                          // [137]: Level: Receive Reject Coefficient Event status Gen4
                     rasdes_sd_info_l.info_phy_cdm_ras_des_fomfeedback_g4[FOMFEEDBACK_WD*ln +: 8],          // [136:129]: Level: Current Figure of Merit Gen4
                     3'b000,                                                                     // [128:126]: 3'b000: Reserved
                     rasdes_sd_info_l.info_mac_cdm_ras_des_coef_ltx_g4[TX_COEF_WD*ln +: 6],                 // [125:120]: Level: Current Local Transmitter Pre Cursor coefficient Gen4
                     rasdes_sd_info_l.info_mac_cdm_ras_des_coef_ltx_g4[TX_COEF_WD*ln+6 +: 6],               // [119:114]: Level: Current Local Transmitter Cursor coefficient Gen4
                     rasdes_sd_info_l.info_mac_cdm_ras_des_coef_ltx_g4[TX_COEF_WD*ln+12 +: 6],              // [113:108]: Level: Current Local Transmitter Post Cursor coefficient Gen4
                     rasdes_sd_info_l.info_mac_cdm_ras_des_coef_rtx_g4[TX_COEF_WD*ln +: 6],                 // [107:102]: Level: Current Remote Transmitter Pre Cursor coefficient Gen4
                     rasdes_sd_info_l.info_mac_cdm_ras_des_coef_rtx_g4[TX_COEF_WD*ln+6 +: 6],               // [101:96]: Level: Current Remote Transmitter Cursor coefficient Gen4
                     rasdes_sd_info_l.info_mac_cdm_ras_des_coef_rtx_g4[TX_COEF_WD*ln+12 +: 6],              // [95:90]: Level: Current Remote Transmitter Post Cursor coefficient Gen4
                     rasdes_sd_info_l.info_mac_cdm_ras_des_lf_g4[TX_FS_WD*ln +: 6],                         // [89:84]: Level: Remote Device LF Gen4
                     rasdes_sd_info_l.info_mac_cdm_ras_des_fs_g4[TX_FS_WD*ln +: 6],                         // [83:78]: Level: Remote Device FS Gen4
                     rasdes_sd_info_l.info_eq_convergence_sts[2*ln +: 2],                                   // [77:76]: Level: Equalization convergence information Gen3
                     rasdes_sd_info_l.info_eqpa_violate_rule_123[3*ln+2 +: 1],                              // [75]: Level: Rule C Violation Event Status Gen3
                     rasdes_sd_info_l.info_eqpa_violate_rule_123[3*ln+1 +: 1],                              // [74]: Level: Rule B Violation Event Status Gen3
                     rasdes_sd_info_l.info_eqpa_violate_rule_123[3*ln +: 1],                                // [73]: Level: Rule A Violation Event Status Gen3
                     rasdes_sd_info_l.info_mac_cdm_ras_des_reject_rtx[ln +: 1],                             // [72]: Level: Receive Reject Coefficient Event status Gen3
                     rasdes_sd_info_l.info_phy_cdm_ras_des_fomfeedback[FOMFEEDBACK_WD*ln +: 8],             // [71:64]: Level: Current Figure of Merit Gen3
                     rasdes_sd_info_l.info_mac_cdm_ras_des_pset_lrx[RX_PSET_WD*ln +: 3],                    // [63:61]: Level: Current Local Receiver Preset Hint Gen3
                     rasdes_sd_info_l.info_mac_cdm_ras_des_coef_ltx[TX_COEF_WD*ln +: 6],                    // [60:55]: Level: Current Local Transmitter Pre Cursor coefficient Gen3
                     rasdes_sd_info_l.info_mac_cdm_ras_des_coef_ltx[TX_COEF_WD*ln+6 +: 6],                  // [54:49]: Level: Current Local Transmitter Cursor coefficient Gen3
                     rasdes_sd_info_l.info_mac_cdm_ras_des_coef_ltx[TX_COEF_WD*ln+12 +: 6],                 // [48:43]: Level: Current Local Transmitter Post Cursor coefficient Gen3
                     rasdes_sd_info_l.info_mac_cdm_ras_des_coef_rtx[TX_COEF_WD*ln +: 6],                    // [42:37]: Level: Current Remote Transmitter Pre Cursor coefficient Gen3
                     rasdes_sd_info_l.info_mac_cdm_ras_des_coef_rtx[TX_COEF_WD*ln+6 +: 6],                  // [36:31]: Level: Current Remote Transmitter Cursor coefficient Gen3
                     rasdes_sd_info_l.info_mac_cdm_ras_des_coef_rtx[TX_COEF_WD*ln+12 +: 6],                 // [30:25]: Level: Current Remote Transmitter Post Cursor coefficient Gen3
                     rasdes_sd_info_l.info_mac_cdm_ras_des_lf[TX_FS_WD*ln +: 6],                            // [24:19]: Level: Remote Device LF Gen3
                     rasdes_sd_info_l.info_mac_cdm_ras_des_fs[TX_FS_WD*ln +: 6],                            // [18:13]: Level: Remote Device FS Gen3
                     rasdes_sd_info_l.rmlh_deskew_fifo_ptr[8*ln +: 8],                                      // [12:5]: Level: Deskew Pointer
                     rasdes_sd_info_l.info_mac_phy_rxpolarity[ln +: 1],                                     // [4]: Level: PIPE: RxPolarity
                     rasdes_sd_info_l.info_latched_rxdetected[ln +: 1],                                     // [3]: Level: PIPE: Detect Lane
                     rasdes_sd_info_l.phy_mac_rxvalid_rxburst[ln +: 1],                                     // [2]: Level: PIPE: RxValid/RxBurst
                     rasdes_sd_info_l.phy_mac_rxelec_rxh8exit[ln +: 1],                                     // [1]: Level: PIPE: RxElecIdle/RxHibern8ExitType1
                     rasdes_sd_info_l.mac_phy_txelec_txburst[ln +: 1]                                       // [0]: Level: PIPE: TxElecIdle/TxBurst
                     } ;
     end
   end // for
  endgenerate

/////////////////////////////////////////// 
// cdm_ras_des_sd_info_vn (RTL) 
/////////////////////////////////////////// 
  reg    [RASDES_SD_INFO_PV-1:0]    cdm_ras_des_sd_info_v[0:NVC-1] ;
  generate
    for (vc=0; vc<NVC; vc=vc+1) begin : gen_cdm_ras_des_sd_info_v
      always @(*) begin
        cdm_ras_des_sd_info_v[vc] = {
                     rasdes_sd_info_v.rtlh_fc_allctd_cpld[vc*DCRD_WD +: 12],    // [239:228]: Level: Credit Allocated (CD) VCn
                     rasdes_sd_info_v.rtlh_fc_allctd_cplh[vc*HCRD_WD +: 8],     // [227:220]: Level: Credit Allocated (CH) VCn 
                     rasdes_sd_info_v.rtlh_fc_allctd_npd[vc*DCRD_WD +: 12],     // [219:208]: Level: Credit Allocated (ND) VCn
                     rasdes_sd_info_v.rtlh_fc_allctd_nph[vc*HCRD_WD +: 8],      // [207:200]: Level: Credit Allocated (NH) VCn 
                     rasdes_sd_info_v.rtlh_fc_allctd_pd[vc*DCRD_WD +: 12],      // [199:188]: Level: Credit Allocated (PD) VCn
                     rasdes_sd_info_v.rtlh_fc_allctd_ph[vc*HCRD_WD +: 8],       // [187:180]: Level: Credit Allocated (PH) VCn 
                     rasdes_sd_info_v.rtlh_fc_rcvd_cpld[vc*DCRD_WD +: 12],      // [179:168]: Level: Credit Received (CD) VCn 
                     rasdes_sd_info_v.rtlh_fc_rcvd_cplh[vc*HCRD_WD +: 8],       // [167:160]: Level: Credit Received (CH) VCn  
                     rasdes_sd_info_v.rtlh_fc_rcvd_npd[vc*DCRD_WD +: 12],       // [159:148]: Level: Credit Received (ND) VCn 
                     rasdes_sd_info_v.rtlh_fc_rcvd_nph[vc*HCRD_WD +: 8],        // [147:140]: Level: Credit Received (NH) VCn  
                     rasdes_sd_info_v.rtlh_fc_rcvd_pd[vc*DCRD_WD +: 12],        // [139:128]: Level: Credit Received (PD) VCn 
                     rasdes_sd_info_v.rtlh_fc_rcvd_ph[vc*HCRD_WD +: 8],         // [127:120]: Level: Credit Received (PH) VCn  
                     rasdes_sd_info_v.xadm_fc_limit_cpld[vc*DCRD_WD +: 12],     // [119:108]: Level: Credit Limit (CD) VCn    
                     rasdes_sd_info_v.xadm_fc_limit_cplh[vc*HCRD_WD +: 8],      // [107:100]: Level: Credit Limit (CH) VCn     
                     rasdes_sd_info_v.xadm_fc_limit_npd[vc*DCRD_WD +: 12],      // [99:88]: Level: Credit Limit (ND) VCn      
                     rasdes_sd_info_v.xadm_fc_limit_nph[vc*HCRD_WD +: 8],       // [87:80]: Level: Credit Limit (NH) VCn       
                     rasdes_sd_info_v.xadm_fc_limit_pd[vc*DCRD_WD +: 12],       // [79:68]: Level: Credit Limit (PD) VCn      
                     rasdes_sd_info_v.xadm_fc_limit_ph[vc*HCRD_WD +: 8],        // [67:60]: Level: Credit Limit (PH) VCn       
                     rasdes_sd_info_v.xadm_fc_cnsmd_cpld[vc*DCRD_WD +: 12],     // [59:48]: Level: Credit Consumed (CD) VCn   
                     rasdes_sd_info_v.xadm_fc_cnsmd_cplh[vc*HCRD_WD +: 8],      // [47:40]: Level: Credit Consumed (CH) VCn    
                     rasdes_sd_info_v.xadm_fc_cnsmd_npd[vc*DCRD_WD +: 12],      // [39:28]: Level: Credit Consumed (ND) VCn   
                     rasdes_sd_info_v.xadm_fc_cnsmd_nph[vc*HCRD_WD +: 8],       // [27:20]: Level: Credit Consumed (NH) VCn    
                     rasdes_sd_info_v.xadm_fc_cnsmd_pd[vc*DCRD_WD +: 12],       // [19:8]: Level: Credit Consumed (PD) VCn    
                     rasdes_sd_info_v.xadm_fc_cnsmd_ph[vc*HCRD_WD +: 8]         // [7:0]: Level: Credit Consumed (PH) VCn      
                     } ;
      end
    end // for
  endgenerate

  assign cdm_ras_des_sd_info_l0 = cdm_ras_des_sd_info_l[0] ;
  assign cdm_ras_des_sd_info_l1 = cdm_ras_des_sd_info_l[1] ;
  assign cdm_ras_des_sd_info_l2 = cdm_ras_des_sd_info_l[2] ;
  assign cdm_ras_des_sd_info_l3 = cdm_ras_des_sd_info_l[3] ;
  assign cdm_ras_des_sd_info_l4 = cdm_ras_des_sd_info_l[4] ;
  assign cdm_ras_des_sd_info_l5 = cdm_ras_des_sd_info_l[5] ;
  assign cdm_ras_des_sd_info_l6 = cdm_ras_des_sd_info_l[6] ;
  assign cdm_ras_des_sd_info_l7 = cdm_ras_des_sd_info_l[7] ;

  assign cdm_ras_des_sd_info_v0 = cdm_ras_des_sd_info_v[0] ;


  struct packed {
    logic   smlh_ltssm_in_l0p;          // [7]: Level: L0p
    logic   smlh_link_in_training;      // [6]: Level: Config/Recovery
    logic   smlh_in_l0;                 // [2]: Level: L0 (Idle)
  } rasdes_tba_info_cmn_s, rasdes_tba_info_cmn;


  assign rasdes_tba_info_cmn_s.smlh_ltssm_in_l0p = smlh_ltssm_in_l0p;
  assign rasdes_tba_info_cmn_s.smlh_link_in_training = smlh_link_in_training;
  assign rasdes_tba_info_cmn_s.smlh_in_l0 = smlh_in_l0;

  delay_n
   #(
     .N   (1)
    ,.WD ($bits(rasdes_tba_info_cmn_s))
    ,.RESETVAL ('0)
  ) u_delay_n_tba_info_cmn (
    // ------------- input -----------------
     .clk   (aux_clk)
    ,.rst_n (sticky_rst_n)
    ,.clear (1'b0)
    ,.din   (rasdes_tba_info_cmn_s)
    // ------------- output ----------------
    ,.dout  (rasdes_tba_info_cmn)
  );

/////////////////////////////////////////// 
// cdm_ras_des_tba_info_common (RTL) 
/////////////////////////////////////////// 
  always @(*) begin
    cdm_ras_des_tba_info_common = {
                     rasdes_tba_info_cmn.smlh_ltssm_in_l0p,         // [7]: Level: L0p
                     rasdes_tba_info_cmn.smlh_link_in_training,     // [6]: Level: Config/Recovery
                     rasdes_ec_info_cmn.info_pm_in_l12,             // [5]: Level: L1.2
                     rasdes_ec_info_cmn.info_pm_in_l11,             // [4]: Level: L1.1
                     rasdes_ec_info_cmn.smlh_in_l1,                 // [3]: Level: L1
                     rasdes_tba_info_cmn.smlh_in_l0,                // [2]: Level: L0 (Idle)
                     rasdes_ec_info_cmn.smlh_in_rl0s,               // [1]: Level: Rx L0s
                     rasdes_ec_info_cmn.smlh_in_l0s                 // [0]: Level: Tx L0s
                     } ;
  end

endmodule //cdm_rasdes_reg 
