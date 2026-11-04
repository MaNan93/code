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
// ---    $Revision: #23 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/xmlh.sv#23 $
// -------------------------------------------------------------------------
// --- Module Description: Transmit MAC Layer Handler
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Layer1/xmlh_pkg.svh"
`include "Layer2/svif/tx_lp_if.svh"
`include "products/cx_pl_pkg.svh"
`include "Spif/pkg/spif_pkg.svh"


 module xmlh
  import xmlh_pkg::data_rate_enc_t;
  import xmlh_pkg::P_SKP_REPLACE_IDLE;
  import xmlh_pkg::OSFLG_WD;
  import xmlh_pkg::NUM_OS_GEN;
  import cx_pl_pkg::tx_cmd_struct;
  import spif_pkg::protocol_cfg_t;
  import DWC_pcie_core_pkg::ltssm_state_e;
  import DWC_pcie_core_pkg::S_DETECT_QUIET;
  import DWC_pcie_core_pkg::S_POLL_COMPLIANCE;
  import DWC_pcie_core_pkg::S_CFG_LINKWD_START;
  import DWC_pcie_core_pkg::S_CFG_IDLE;
  import DWC_pcie_core_pkg::S_RCVRY_IDLE;
  import DWC_pcie_core_pkg::S_LPBK_EXIT_TIMEOUT;
  import DWC_pcie_core_pkg::cfg_os_einj_ctrl_1_t;
  import DWC_pcie_core_pkg::cfg_os_einj_ctrl_2_t;
  import DWC_pcie_core_pkg::cfg_os_einj_status_t;
  import DWC_pcie_core_pkg::xmlh_einj_in_os_t;
#(
parameter INST              = 0,                                     // The uniquifying parameter for each port logic instance.
parameter TP                = `TP,                                   // Clock to Q delay (simulator insurance)

parameter EQTS_WD           = 32,                                    // Number of bits of Per Lane Equalization Information
parameter RX_PSET_WD        = 3,                                     // Width of Receiver Equalization Presets
parameter TX_PSET_WD        = 4,                                     // Width of Transmitter Equalization Presets
parameter TX_FS_WD          = 6,                                     // Width of Full Swing values
parameter TX_FSLF_WD        = 12,                                    // Width of concatenated bus for Equalization "Low Frequency" and "Full Swing" values: {LF, FS}
parameter TX_COEF_WD        = 18,                                    // Width of concatenated bus for Equalization Coefficients: {C(+1), C(0), C(-1)}
parameter PCNT_WD           = 4,                                     // persistency count width
parameter DIRFEEDBACK_WD    = `DIRFEEDBACK_WD,                       // Width of Direction Change
parameter FOMFEEDBACK_WD    = 8,                                     // Width of Figure of Merit
parameter AW                = `CX_ANB_WD,                            // Width of the active number of bytes
parameter NL                = `CX_NL,                                // Max number of lanes supported
parameter NB                = `CX_NB,                                // Number of symbols (bytes) per clock cycle
parameter NBK               = `CX_NBK,                               // Number of symbols (bytes) per clock cycle for datak
parameter PHY_TXSB_WD       = `CX_PHY_TXSB_WD,                       // Width of the start block
parameter PHY_TXSH_WD       = `CX_PHY_TXSH_WD,                       // Width of the sync header
parameter MAC_TXSB_WD       = `CX_MAC_SB_WD,                         // Width of the start block
parameter MAC_TXSH_WD       = `CX_MAC_SH_WD,                         // Width of the sync header
parameter OS_WD             = `CX_MAC_SB_WD, // Number of OS width
parameter NW                = `CX_PL_NW,                             // Number of 32-bit dwords handled by the datapath each clock.
parameter TS_0_WD           = 48,                                    // TS0 info
parameter L2NL              = NL==1 ? 1 : `CX_LOGBASE2(NL)           // log2 number of NL
)

              (
// Interface Ports
tx_lp_if.slave_mp           b_xplh_xmlh_sp,                 // Link Layer to Physical Layer transmit slave modport
// inputs
input                                pm_xmlh_lp_req,            // PM Request to xtlh_cmd_if to enter low power
output logic                         xmlh_cmd_if_lp_ack, 
input                                ltssm_idl_hs_done,
input                                core_clk,
input                                core_rst_n,
input                                app_sris_mode,                  // application signal to enable the SRIS mode
input                                cxl_sh_bypass,                  // SyncHeader_Bypass
input                                cxl_mode_enable,                // Indicates whether the link should operate in CXL or PCIe mode
input                                sticky_rst_n,
input                                cfg_flit_sris_clocking,
input                                cfg_comm_clk_config,
input                                latched_smlh_link_up,
input                                smlh_link_up,
input   [L2NL-1:0]                   latched_flip_ctrl,
input   [L2NL-1:0]                   smlh_lane_flip_ctrl,
input   [NL-1:0]                     ltssm_lpbk_slave_lut,           // lane under test
input   [7:0]                        muxed_n_fts,                    // 8bits bus to specify the number of FTS we wish to receive for our receiver
input   [5:0]                        cfg_link_capable,               // It is application specific. It needs to be decided by application at implementation
                                                                     // time. It indicates the x1, x2, x4 capability of a port. This is an output of
                                                                     // PCIE spec. required config register.
input                                cfg_fast_link_mode,             //
input  [10:0]                        cfg_skip_interval,              // the number of symbol times between skip requests
input                                cfg_ext_synch,
input                                cfg_mod_ts,                     // modified TS format
input                                cfg_upstream_port,              // 1: DC - downstream component, 0: UC - upstream component
input   [`CX_PL_GEN3_CONTROL_WD-1:0] cfg_pl_gen3_control,            // Port Logic Gen3 Control Register
input                                cfg_no_seed_value_change,       // No gen3 scrambler seed value change after linkup
input   [NL*16-1:0]                  cfg_margin_control,             // Margining Control [2:0] Receiver Number[5:3]Margin Type[6]Usage Molde[7]Rsvd[15:8]Margin Payload
input   [NL*16-1:0]                  smlh_ctlskp_info,               // Margining Status  [2:0] Receiver Number[5:3]Margin Type[6]Usage Molde[7]Rsvd[15:8]Margin Payload
input   [NL*8-1:0]                   smlh_gen3_error_count,          // per lane version of gen3 error count
input                                smlh_ltssm_in_compliance,
input   [NL*EQTS_WD-1:0]             eqctl_eqts_info,                // Equalization Information for Symbols 6-9 of EQ TSs and Gen3 TSs
input   [NL*TS_0_WD-1:0]             eqctl_eqts_info_ts0,
input                                eqctl_g6_tx_ts0,
input                                link_rx_ts0_to_ts1_pulse,
input   [NL-1:0]                     eqctl_mask_eieos,
input   [NL-1:0]                     eqctl_2mask_eieos_pulse,
input                                ltssm_in_lpbkentry,
input                                ltssm_cmd_send_eieos_for_pset_map, // send eieos continuously for pset-coef mapping
input                                ltssm_usp_eq_redo,              // eq redo for usp
input   [NL*TX_PSET_WD-1:0]          eqctl_pset_ltx,
input   [(NL*3)-1:0]                 smlh_margin_cmd,
input   [(NL*7)-1:0]                 smlh_margin_offset,
input   [(NL*2)-1:0]                 smlh_margin_clr_error_log,
input   [2:0]                        current_data_rate_xmt,          // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4
input   [2:0]                        current_data_rate_scr,          // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4
input   [AW-1:0]                     active_nb_wire,                 // active number of symbols. bit0=1s, bit1=2s, bit2=4s, bit3=8s , bit4=16s before FF for high fanout. 
input   [AW-1:0]                     active_nb_gen34,                // active number of symbols for gen34. bit0=1s, bit1=2s, bit2=4s, bit3=8s , bit4=16s
input   [NL-1:0]                     phy_mac_phystatus,
input                                cfg_compliance_sos,             // Send skips during compliance
input   [NL-1:0]                     smlh_mcs_rcvd,                  // detected Modified Compliance Sequence
input   [NL-1:0]                     rpipe_rxerror,                  // when asserted, RMLH indicates that the receiver has detected an rx disparity or code error
input                                ltssm_ts_cnt_en,
input                                ltssm_ts_cnt_rst,
input                                ltssm_ts_speed_change,
input   [4:0]                        ltssm_ts_data_rate,
input   [4:0]                        latched_ts_data_rate,
input   [9:0]                        ltssm_ts_data_rate_eg6,
input   [9:0]                        latched_ts_data_rate_eg6,
input                                ltssm_dsp_g6_eq1_send_ec00,     // = 1, dsp xmlh starts to send 24 ts0s with ec = 00b in eq1
input                                ltssm_ts_auto_change,
input   [7:0]                        ltssm_xlinknum,
input   [NL-1:0]                     ltssm_xk237_4lannum,
input   [NL-1:0]                     ltssm_xk237_4lnknum,
input   [7:0]                        ltssm_ts_cntrl,                 // training sequence control
input                                smlh_in_l0,                    // Take eq pending into account for FLit mode transition to sequence number handshake
input                                xplh_xmlh_cmd_ack,             // XPLH XMLH Command Acknowledge
output  tx_cmd_struct                xmlh_xplh_cmd,                 // XMLH XPLH Command
output  wire                         xmlh_fm_pending,
input                                ltssm_flit_mode_enable,
input                                ltssm_flit_mode_tx,
input                                smlh_usp_sris_mode,
input                                ltssm_cmd_compliance_ts1,
input   [7:0]                        ltssm_compliance_set_num,
input                                xfsh_xmlh_buf_empty,
output                               xplh_xmlh_sof,
output                               xmtbyte_2_compliance_ts1_sent,
output                               xmtbyte_sris_mode_enabled,
output  wire                         xmlh_xfsh_last_flit,
output                               xmbyte_flit_data_stream,
input                                smlh_l0p_update,
input  [5:0]                         smlh_l0p_next_link_mode, // 10000 -- x16, 01000 -- x8, 00100 -- x4, 00010 -- x2, 00001 -- x1
input  [5:0]                         smlh_l0p_link_mode,     // 10000 -- x16, 01000 -- x8, 00100 -- x4, 00010 -- x2, 00001 -- x1
input  [NL-1:0]                      ltssm_l0p_lanes_active, // LTSSM latched lanes that are active based on the link negotiation
input  [NL-1:0]                      ltssm_l0p_last_lanes_active, // LTSSM latched lanes that are active based on the link negotiation
input  [3:0]                         ltssm_l0p_cmd,          // encoded command to notify transmitter of the proper action based on LTSSM states
input                                ltssm_l0p_cmd_4_eieos_req, //4 eieos request at gen6 rate
output                               xmtbyte_l0p_eidle_sent,
output  [OS_WD-1:0]                  xmtbyte_l0p_ts1_sent,
output  [OS_WD-1:0]                  xmtbyte_l0p_ts2_sent,
output                               xmtbyte_l0p_linkwidth_changed,
output                               xmtbyte_l0p_link_in_training,
output                               xmtbyte_l0p_sris_mode_enabled,
output                               xmtbyte_l0p_state_in_upsize,
input                                ltssm_mod_ts,                   // Tx modified TS OS
input                                ltssm_ts_alt_protocol,          // Alternate Protocol
input                                ltssm_no_idle_need_sent,        // No idle need sent
input   [55:0]                       ltssm_ts_alt_prot_info,         // sym14-8 for AP
input   [3:0]                        ltssm_eidle_cnt,
input                                ltssm_clear,
input   [3:0]                        ltssm_cmd,
input   [1:0]                        ltssm_powerdown,                // powerdown from LTSSM to rmlh_pipe
input                                ltssm_lpbk_master,              // 
input                                ltssm_in_lpbk,
input                                ltssm_in_lpbk_active,
input   [7:0]                        latched_ts_nfts,
input   [5:0]                        smlh_link_mode,
input   [NL-1:0]                     smlh_lanes_active,
input   [NL-1:0]                     lpbk_eq_lanes_active,
input   [NL-1:0]                     power_saving_lanes_active,
input   [NL-1:0]                     smlh_no_turnoff_lanes,
input   ltssm_state_e                smlh_ltssm_state_wire,
input   ltssm_state_e                smlh_ltssm_next,
input   ltssm_state_e                smlh_ltssm_last,
input                                smlh_scrambler_disable,         // when asserted, scramble disabled.
input   [3:0]                        ltssm_gen4_compliance_jmp,       // Gen4 compliance setting# for Jitter Measurment Pattern
input   [3:0]                        ltssm_gen6_compliance_tp,        // Gen6 compliance setting# for Toggle Pattern
input                                smlh_tx_precoding_on,            // Precoding on for gen5
input                                ltssm_cmd_eqts0,
input   [1:0]                        cdm_ras_des_eidle_cnt_sel,           // Number of Transmit E-IDLE ordered set for Ras D.E.S Silicon Debug
input                                cdm_ras_des_einj0_enable,       // Error injection0 - CRC error enable
input   [3:0]                        cdm_ras_des_einj0_crc_type,     // Error injection0 - CRC error type
input                                cdm_ras_des_einj3_enable,       // Error injection3 - 8b/10b K-code mask enable
input   [7:0]                        cdm_ras_des_einj3_count,        // Error injection3 - 8b/10b K-code mask count
input   [2:0]                        cdm_ras_des_einj3_smb_type,     // Error injection3 - 8b/10b K-code mask type
input                                cfg_lpbk_en,
input                                cfg_prbs_en,
input                                cfg_flit_err_inj_latency,
input  cfg_os_einj_ctrl_1_t          cfg_os_einj_ctrl_1,
input  cfg_os_einj_ctrl_2_t          cfg_os_einj_ctrl_2,
output cfg_os_einj_status_t          xmlh_tx_os_einj_status,

input  protocol_cfg_t                xmlh_protocol_cfg,      // Protocol Configuration for XMLH Layer
input                                splh_cmd_if_pmreq_ack,  // SPLH Command Interface PM Entry Acknowledge to XMLH
input                                splh_cmd_if_stall_ack,  // SPLH Command Interface Stall Acknowledge to XMLH
input                                splh_cmd_if_pending,    // SPLH Command Interface Packet Pending Indication to XMLH

// outputs
output                               xmtbyte_sris_enable,            // PIPE Interface SRISEnable
output                               xmtbyte_stp_start,              // a pulse to indicate stp starts
output  [10:0]                       xmtbyte_ts_pcnt,                // transmit ts persistency count
output                               xmtbyte_ts_data_diff,           // current ts data different from previous
output                               xmtbyte_1024_ts_sent,
output                               xmtbyte_spd_chg_sent,           // transmit ts with speed_change bit set
output                               xmtbyte_dis_link_sent,          // transmit TS with disable_link bit set
output                               xmtbyte_loe_2_ts1_ec_00b_sent,  // less or equal 2 ts1s sent with EC==00b
output                               xmlh_cmd_is_data,               // xmtbyte state machine is waiting for packet start or packet end
output [NL-1:0]                      xmlh_scramble_even_parity,      // Current tx skip even data parity from XMLH
output  [(NL*NB*8)-1:0]              mac_phy_txdata,                 // 2 bytes parallel transmit data
output  [(NL*NB)-1:0]                mac_phy_txdatak,                // Indicates K characters
output  [NL-1:0]                     mac_phy_txdatavalid,            // Instruct the PHY to ignore bytes on the data interface
output  [(NL*PHY_TXSB_WD)-1:0]       mac_phy_txstartblock,           // Indicates the starting symbol for a 130b block
output  [(NL*PHY_TXSH_WD)-1:0]       mac_phy_txsyncheader,           // Indicates the sync header for a 130b block
output  [NL-1:0]                     mac_phy_txdetectrx_loopback,    // Enable receiver detect (loopback)
output  [NL-1:0]                     mac_phy_txelecidle,             // Enable Transmitter Electical Idle
output  [NL-1:0]                     mac_phy_txcompliance,           // Set negative running disparity (for compliance pattern)
output [(NL*3)-1:0]                  mac_phy_margin_cmd,
output [(NL*7)-1:0]                  mac_phy_margin_offset,
output [(NL*2)-1:0]                  mac_phy_margin_clr_error_log,
output                               xmtbyte_skip_sent,
output                               xmtbyte_skip_insert,
output                               xmtbyte_ctlskip_sent,
output                               xmtbyte_sent_24_ts0_ec00,
output [OS_WD-1:0]                   xmtbyte_ts1_sent,
output [OS_WD-1:0]                   xmtbyte_ts2_sent,
output                               xmtbyte_idle_sent,
output                               xmtbyte_eidle_sent,
output                               xmtbyte_eies_sent,
output                               xmtbyte_fts_sent,
output                               xmtbyte_txdata_dv,
output [(NL*NB*8)-1:0]               xmtbyte_txdata,
output [(NL*NBK)-1:0]                xmtbyte_txdatak,
output [NL-1:0]                      xmtbyte_txelecidle,
output                               xmtbyte_txdetectrx_loopback,
output [NL-1:0][PHY_TXSB_WD-1:0][OSFLG_WD-1:0] xpipe_txdata_osfound,
output  [1:0]                        xpipe_powerdown                 // Set PHY to P0/P0s/P1 (PME will set P2)
                                                                     // without the port transitioning through DL_Down status
                                                                     // DL_Down status, for reasons other than to attempt to correct unreliable link operation.
,
output                               xmlh_einj0_oscrc_evt,           // Error injection0 - CRC error event
output [1:0]                         xmlh_einj3_osmsk_evt            // Error injection3 - 8b/10b K-code mask event
);


// internal signals
ltssm_state_e                                    smlh_ltssm_state ;
data_rate_enc_t                                  crnt_rate_enc ;                               // current data rate shortcut.
reg    [AW-1:0]                                  active_nb ;
wire                                             cpcie_xmtbyte_stp_start;
wire    [10:0]                                   cpcie_xmtbyte_ts_pcnt;
wire                                             cpcie_xmtbyte_ts_data_diff;
wire                                             cpcie_xmtbyte_1024_ts_sent;
wire                                             cpcie_xmtbyte_spd_chg_sent;
wire                                             cpcie_xmtbyte_dis_link_sent;
wire                                             cpcie_xmtbyte_loe_2_ts1_ec_00b_sent;
wire    [(NL*NB*8)-1:0]                          xmtbyte_txdata_org;
wire                                             xmtbyte_txdata_dv_org;
wire    [(NL*NBK)-1:0]                           xmtbyte_txdatak_org;              // Error inserted txdatak
wire    [(NL*MAC_TXSB_WD)-1:0]                   xmtbyte_txstartblock_org;
wire    [NL-1:0][MAC_TXSB_WD-1:0][OSFLG_WD-1:0]  xmtbyte_ossending;
wire    [NL-1:0][MAC_TXSB_WD-1:0][OSFLG_WD-1:0]  xmtbyte_ossending_org;
logic   [NL-1:0][2:0]                            xmtbyte_skp_os_align_sts_org;
wire    [NL-1:0]                                 xmtbyte_txelecidle_org;
wire    [NL-1:0]                                 xmtbyte_txelecidle_scramble_org;
wire                                             xmtbyte_txdetectrx_loopback_org;
wire    [NL-1:0]                                 xmtbyte_txcompliance_org;   
wire    [NL-1:0]                                 pm_xmlh_scramble_even_parity_int;
wire                                             xmtbyte_link_in_training_org;
wire                                             xmtbyte_link_in_training;
wire    [NL-1:0]                                 xmtbyte_txcompliance;             // Set negative running disparity (for compliance pattern)
wire    [NL-1:0]                                 xpipe_phystatus;                  // PIPE phy status signal
wire    [NL-1:0]                                 scramble_data_dv;
wire    [(NL*NB*8)-1:0]                          scramble_data;
wire    [(NL*NBK)-1:0]                           scramble_datak;
wire    [NL*MAC_TXSB_WD-1:0]                     scramble_inskp;                   //SKP indicator
wire    [NL-1:0][2:0]                            scramble_skp_os_align_sts;        // Indicates current sending Data have LFSR/Parity field of SKP OS
wire    [NL*MAC_TXSB_WD-1:0]                     scramble_ints1;                   //TS1 indicator
wire    [NL*MAC_TXSB_WD-1:0]                     scramble_ints2;                   //TS2 indicator
wire    [NL*MAC_TXSB_WD-1:0]                     scramble_ints0;                   //TS1 indicator
wire                                             xmtbyte_gen6_compliance_sending;
wire    [(NL*NB)-1:0]                            scramble_error;
wire    [(NL*NB*8)-1:0]                          scramble_data_org;
wire    [(NL*NB*8)-1:0]                          reversed_data;
wire    [(NL*NBK)-1:0]                           reversed_datak;
wire    [(NL*NB)-1:0]                            reversed_error;

wire    [(NL*MAC_TXSB_WD)-1:0]                   scramble_startblock;
wire    [NL-1:0][MAC_TXSB_WD-1:0][OSFLG_WD-1:0]  scramble_data_osfound;
wire    [NL-1:0]                                 scramble_lfsr_rollover;           // LFSR value matches seed. Used for inserting EIEOS in xmlh_byte_xmt after a sequence of 65536 uninterrupted TS1s
wire    [(NL*MAC_TXSB_WD)-1:0]                   scramble_even_parity;             // Data Even Parity from Scrambler. Used for SKP OS in xmlh_byte_xmt
reg     [NL-1:0]                                 int_scramble_even_parity;         // Data Even Parity from Scrambler. Used for SKP OS in xmlh_byte_xmt
wire    [(NL*MAC_TXSB_WD)-1:0]                   xmtbyte_txstartblock;
wire    [NL-1:0][2:0]                            xmtbyte_skp_os_align_sts;         // Indicates current sending Data have LFSR/Parity field of SKP OS
wire                                             xmtbyte_ltssm_in_compliance;
wire                                             ltssm_in_rcvry_cfg_idle;
wire                                             ltssm_in_rcvry_cfg_idle_g3;
wire                                             xmtbyte_g5_lpbk_deassert;

// map individual bits of the port logic gen3 control register
wire cfg_gen3_dc_balance_disable   = cfg_pl_gen3_control[7];
wire cfg_gen3_scrambler_disable    = cfg_pl_gen3_control[0];
// This signal uses to send a control skip-os 
assign ltssm_in_rcvry_cfg_idle = (smlh_ltssm_state==S_RCVRY_IDLE && ~ltssm_no_idle_need_sent) || (smlh_ltssm_state==S_CFG_IDLE);
assign ltssm_in_rcvry_cfg_idle_g3 = (current_data_rate_xmt == `GEN3_RATE) & ((smlh_ltssm_state==S_RCVRY_IDLE && ~ltssm_no_idle_need_sent) || (smlh_ltssm_state==S_CFG_IDLE));

// This block takes care of the muxing of special order set and dllp/tlp
// data from xdlh module
// For core clock running at 125Mhz, this block also takes care of symbol
// aligning so that it transmits to pipe interface two symbols per clock
wire                    xmtbyte_pat_fts_sent;
wire                    xmtbyte_pat_eidle_start_sent;
wire                    cpcie_xmtbyte_txdata_dv;
wire    [(NL*NB*8)-1:0] cpcie_xmtbyte_txdata;
wire    [(NL*NBK)-1:0]  cpcie_xmtbyte_txdatak;
wire    [(NL*MAC_TXSB_WD)-1:0] cpcie_xmtbyte_txstartblock;
wire                    cpcie_xmtbyte_ltssm_in_compliance;
wire    [OS_WD-1:0]     cpcie_xmtbyte_ts1_sent;
wire    [OS_WD-1:0]     cpcie_xmtbyte_ts2_sent;
wire                    cpcie_xmtbyte_fts_sent;
wire                    cpcie_xmtbyte_idle_sent;
wire                    cpcie_xmtbyte_eidle_sent;
wire                    cpcie_xmtbyte_eies_sent;
wire                    cpcie_xmtbyte_skip_sent;
wire                    cpcie_xmtbyte_ctlskip_sent;
wire                    cpcie_xmtbyte_pat_fts_sent;
wire                    cpcie_xmtbyte_pat_eidle_start_sent;
wire                    xmlh_rst_flit_alignment;
wire                    cpcie_xmlh_xdlh_halt;
wire                    cpcie_xmlh_skip_pending;
wire                    cpcie_xmtbyte_link_in_training;
wire    [NL-1:0]        cpcie_xmtbyte_txelecidle;             // Enable Transmitter Electical Idle
wire                    cpcie_xmtbyte_txdetectrx_loopback;    // Enable receiver detect (loopback)
wire    [NL-1:0]        cpcie_xmtbyte_txcompliance;           // Set negative running disparity (for compliance pattern)
wire                    cpcie_xmtbyte_cmd_is_data;

ltssm_state_e           xmtbyte_latched_loadpat_ltssmstate;
xmlh_einj_in_os_t       xmtbyte_einj_in_os;

wire                    xmtbyte_cmd_is_data;

wire    [(NL*NB*8)-1:0]                         g6_reversed_data;
wire    [(NL*NBK)-1:0]                          g6_reversed_datak;
wire    [NL-1:0]                                g6_scramble_data_dv;
wire    [(NL*PHY_TXSB_WD)-1:0]                  g6_scramble_startblock;
wire    [NL-1:0][PHY_TXSB_WD-1:0][OSFLG_WD-1:0] g6_scramble_data_osfound;
wire    [NL-1:0]                                g6_xmtbyte_txelecidle;

// Pipe-line of smlh_ltssm_state/active_nb for high fanout. 
// The smlh_ltssm_state_wire/active_nb_wire are a combinational signal(before FF). So, no timing change by this pipe-line.
always @(posedge core_clk or negedge core_rst_n) begin : smlh_ltssm_state_proc
    if (!core_rst_n) begin
        smlh_ltssm_state <= #TP S_DETECT_QUIET;
        active_nb        <= #TP `CX_NB;
    end
    else begin
        smlh_ltssm_state <= #TP smlh_ltssm_state_wire;
        active_nb        <= #TP active_nb_wire;
    end
end

//--------------------------------------
// xmlh_byte_xmt Selector
//--------------------------------------

 assign xmtbyte_stp_start            = cpcie_xmtbyte_stp_start;

 assign xmtbyte_ts_pcnt              = cpcie_xmtbyte_ts_pcnt;
 assign xmtbyte_ts_data_diff         = cpcie_xmtbyte_ts_data_diff;

   assign xmtbyte_dis_link_sent        = cpcie_xmtbyte_dis_link_sent;
   assign xmtbyte_ts1_sent             = cpcie_xmtbyte_ts1_sent;
   assign xmtbyte_ts2_sent             = cpcie_xmtbyte_ts2_sent;
   assign xmtbyte_eidle_sent           = cpcie_xmtbyte_eidle_sent;
   assign xmtbyte_txelecidle_org       = cpcie_xmtbyte_txelecidle;
   assign xmtbyte_cmd_is_data          = cpcie_xmtbyte_cmd_is_data;
   assign xmtbyte_1024_ts_sent         = cpcie_xmtbyte_1024_ts_sent; 
   assign xmtbyte_spd_chg_sent         = cpcie_xmtbyte_spd_chg_sent;
   assign xmtbyte_fts_sent             = cpcie_xmtbyte_fts_sent;
   assign xmtbyte_idle_sent            = cpcie_xmtbyte_idle_sent;
   assign xmtbyte_skip_sent            = cpcie_xmtbyte_skip_sent;
 assign xmtbyte_loe_2_ts1_ec_00b_sent= cpcie_xmtbyte_loe_2_ts1_ec_00b_sent;
 assign xmtbyte_txdata_dv_org        = cpcie_xmtbyte_txdata_dv;
 assign xmtbyte_txdata_org           = cpcie_xmtbyte_txdata;
 assign xmtbyte_txdatak_org          = cpcie_xmtbyte_txdatak;
 assign xmtbyte_txstartblock_org     = cpcie_xmtbyte_txstartblock;
 assign xmtbyte_ltssm_in_compliance  = cpcie_xmtbyte_ltssm_in_compliance;
 assign xmtbyte_eies_sent            = cpcie_xmtbyte_eies_sent;
 assign xmtbyte_ctlskip_sent         = cpcie_xmtbyte_ctlskip_sent;
 assign xmtbyte_pat_fts_sent         = cpcie_xmtbyte_pat_fts_sent;
 assign xmtbyte_pat_eidle_start_sent = cpcie_xmtbyte_pat_eidle_start_sent;
 assign xmtbyte_link_in_training_org = cpcie_xmtbyte_link_in_training;
 assign xmtbyte_txdetectrx_loopback_org  = cpcie_xmtbyte_txdetectrx_loopback;
 assign xmtbyte_txcompliance_org     = cpcie_xmtbyte_txcompliance;


assign xmlh_cmd_is_data              = xmtbyte_cmd_is_data;
assign b_xplh_xmlh_sp.cmd_is_data    = xmtbyte_cmd_is_data;
assign b_xplh_xmlh_sp.skip_pending   = cpcie_xmlh_skip_pending;
assign b_xplh_xmlh_sp.halt_in        = cpcie_xmlh_xdlh_halt;


logic  int_xmlh_fm_enable;
logic  int_xmlh_cmd_if_lp_ack;
logic  int_xmlh_fm_flush_ack;
logic  int_xmlh_fm_pending;

// Mux between SPLH and XMLH Command Interfaces
assign xmlh_cmd_if_lp_ack = xmlh_protocol_cfg.spif_enable ? splh_cmd_if_pmreq_ack : int_xmlh_cmd_if_lp_ack;
assign xmlh_fm_flush_ack  = xmlh_protocol_cfg.spif_enable ? splh_cmd_if_stall_ack : int_xmlh_fm_flush_ack;
assign xmlh_fm_pending    = xmlh_protocol_cfg.spif_enable ? splh_cmd_if_pending   : int_xmlh_fm_pending;

assign int_xmlh_fm_enable = xmlh_protocol_cfg.pcie_flit_mode;

//--------------------------------------
// Instance of XMLH Command Interface for FLIT Mode
//--------------------------------------
xmlh_cmd_if
 u_xmlh_cmd_if(
  // -------------------------------------------------------------------------------------
  // Clock and Reset
  // -------------------------------------------------------------------------------------
  .core_clk                 (core_clk),
  .core_rst_n               (core_rst_n),
  // -------------------------------------------------------------------------------------
  // SMLH Interface 
  // -------------------------------------------------------------------------------------
  .smlh_link_up             (smlh_link_up),
  .smlh_ltssm_state         (smlh_ltssm_state),
  .smlh_flit_mode_enable    (int_xmlh_fm_enable),
  .xmlh_cmd_if_flush_ack    (int_xmlh_fm_flush_ack),
  .ltssm_idl_hs_done        (ltssm_idl_hs_done),
  .lpbk_master              (ltssm_lpbk_master),
  .smlh_in_l0               (smlh_in_l0),
  // -------------------------------------------------------------------------------------
  // XPLH Interface 
  // -------------------------------------------------------------------------------------
  .xplh_xmlh_cmd_ack        (xplh_xmlh_cmd_ack),
  .xmlh_cmd_if_cmd          (xmlh_xplh_cmd),
  // -------------------------------------------------------------------------------------
  // PM Interface 
  // -------------------------------------------------------------------------------------
  .pm_xmlh_lp_req           (pm_xmlh_lp_req),
  .xmlh_cmd_if_lp_ack       (int_xmlh_cmd_if_lp_ack),
  // -------------------------------------------------------------------------------------
  // XMLH Interface 
  // -------------------------------------------------------------------------------------
  .xmlh_cmd_if_pending      (int_xmlh_fm_pending)
);



//--------------------------------------
// Instance of xmlh_byte_xmt for PCIe
//--------------------------------------
xmlh_byte_xmt_top

#(INST) u_xmlh_byte_xmt(
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .app_sris_mode_i                (app_sris_mode),
    .ltssm_cxl_sh_bypass            (cxl_sh_bypass),
    .cxl_mode_enable                (cxl_mode_enable),
    .sticky_rst_n                   (sticky_rst_n),
    .cfg_flit_sris_clocking         (cfg_flit_sris_clocking),
    .cfg_comm_clk_config            (cfg_comm_clk_config),
    .ltssm_ts_speed_change          (ltssm_ts_speed_change),
    .ltssm_ts_data_rate             (ltssm_ts_data_rate),
    .smlh_mcs_rcvd                  (smlh_mcs_rcvd),
    .rpipe_rxerror                  (rpipe_rxerror),
    .cfg_compliance_sos             (cfg_compliance_sos),
    .latched_ts_data_rate           (latched_ts_data_rate),
    .ltssm_ts_data_rate_eg6         (ltssm_ts_data_rate_eg6),
    .latched_ts_data_rate_eg6       (latched_ts_data_rate_eg6),
    .ltssm_dsp_g6_eq1_send_ec00     (ltssm_dsp_g6_eq1_send_ec00),
    .ltssm_clear                    (ltssm_clear),
    .cfg_fast_link_mode             (cfg_fast_link_mode),
    .smlh_ltssm_state               (smlh_ltssm_state),
    .smlh_ltssm_last                (smlh_ltssm_last),
    .cfg_upstream_port              (cfg_upstream_port),
    .scramble_lfsr_rollover         (scramble_lfsr_rollover),
    .eqctl_eqts_info                (eqctl_eqts_info),
    .eqctl_eqts_info_ts0            (eqctl_eqts_info_ts0),
    .eqctl_g6_tx_ts0                (eqctl_g6_tx_ts0),
    .link_rx_ts0_to_ts1_pulse       (link_rx_ts0_to_ts1_pulse),
    .eqctl_mask_eieos               (eqctl_mask_eieos),
    .eqctl_2mask_eieos_pulse        (eqctl_2mask_eieos_pulse),
    .smlh_gen3_error_count_i        (smlh_gen3_error_count),
    .eqctl_pset_ltx                 (eqctl_pset_ltx),
    .cfg_margin_control             (cfg_margin_control),
    .smlh_ctlskp_info               (smlh_ctlskp_info),
    .ltssm_in_rcvry_cfg_idle        (ltssm_in_rcvry_cfg_idle),
    .ltssm_in_rcvry_cfg_idle_g3     (ltssm_in_rcvry_cfg_idle_g3),
    .current_data_rate              (current_data_rate_xmt),
    .ltssm_eidle_cnt                (ltssm_eidle_cnt[2:0]),
    .lpbk_master                    (ltssm_lpbk_master),
    .active_nb                      (active_nb),
    .cfg_mod_ts                     (cfg_mod_ts),
    .ltssm_lpbk_slave_lut           (ltssm_lpbk_slave_lut),
    .ltssm_flit_mode_enable         (ltssm_flit_mode_enable),
    .ltssm_flit_mode                (ltssm_flit_mode_tx),
    .smlh_link_up                   (smlh_link_up),
    .smlh_usp_sris_mode             (smlh_usp_sris_mode),
    .xmlh_fm_flush_ack              (xmlh_fm_flush_ack),
    .xmlh_cmd_if_lp_ack             (xmlh_cmd_if_lp_ack),
    .xmlh_fm_pending                (xmlh_fm_pending),
    .xfsh_xmlh_buf_empty            (xfsh_xmlh_buf_empty),
    .ltssm_cmd_compliance_ts1       (ltssm_cmd_compliance_ts1),
    .ltssm_compliance_set_num       (ltssm_compliance_set_num),
    .cfg_n_fts                      (muxed_n_fts),
    .cfg_ext_synch                  (cfg_ext_synch),
    .cfg_skip_interval              (cfg_skip_interval),
    .smlh_link_mode                 (smlh_link_mode),
    .ltssm_cmd_i                    (ltssm_cmd),
    .ltssm_ts_cnt_en_i              (ltssm_ts_cnt_en),
    .ltssm_ts_cnt_rst               (ltssm_ts_cnt_rst),
    .ltssm_xlinknum                 (ltssm_xlinknum),
    .ltssm_xk237_4lannum            (ltssm_xk237_4lannum),
    .ltssm_xk237_4lnknum            (ltssm_xk237_4lnknum),
    .ltssm_ts_cntrl                 (ltssm_ts_cntrl),
    .ltssm_mod_ts                   (ltssm_mod_ts),
    .ltssm_ts_alt_protocol          (ltssm_ts_alt_protocol),
    .ltssm_ts_alt_prot_info         (ltssm_ts_alt_prot_info),
    .ltssm_ts_auto_change           (ltssm_ts_auto_change),
    .latched_ts_nfts                (latched_ts_nfts),
    .xdlh_xmlh_eof                  (b_xplh_xmlh_sp.eof[1]),
    .xdlh_xmlh_sof                  (b_xplh_xmlh_sp.sof),
    .xdlh_xmlh_stp_i                (b_xplh_xmlh_sp.stp),
    .xdlh_xmlh_sdp_i                (b_xplh_xmlh_sp.sdp),
    .xdlh_xmlh_eot_i                (b_xplh_xmlh_sp.eot),
    .next_xdlh_xmlh_eot_i           (b_xplh_xmlh_sp.next_eot),
    .next_xdlh_xmlh_stp_i           (b_xplh_xmlh_sp.next_stp),    
    .next_xdlh_xmlh_sdp_i           (b_xplh_xmlh_sp.next_sdp),    
    .xdlh_xmlh_pad_i                (b_xplh_xmlh_sp.pad),
    .xdlh_xmlh_data_i               (b_xplh_xmlh_sp.data_out),
    .xdlh_xmlh_pkt_pending_i        (b_xplh_xmlh_sp.pkt_pending),
    .ltssm_in_lpbkentry             (ltssm_in_lpbkentry),
    .ltssm_cmd_send_eieos_for_pset_map (ltssm_cmd_send_eieos_for_pset_map),
    .ltssm_usp_eq_redo              (ltssm_usp_eq_redo),
    .ltssm_in_compliance            (smlh_ltssm_state==S_POLL_COMPLIANCE),
    .ltssm_in_lpbk                  (ltssm_in_lpbk),
    .ltssm_lanes_active             (smlh_lanes_active),
    .lpbk_eq_lanes_active           (lpbk_eq_lanes_active),
    .ltssm_in_lpbk_active           (ltssm_in_lpbk_active),
    .cfg_lpbk_en                    (cfg_lpbk_en),
    .cfg_prbs_en                    (cfg_prbs_en),
    .ltssm_gen4_compliance_jmp      (ltssm_gen4_compliance_jmp),
    .ltssm_gen6_compliance_tp       (ltssm_gen6_compliance_tp),
    .cdm_ras_des_eidle_cnt_sel      (cdm_ras_des_eidle_cnt_sel),
    .smlh_no_turnoff_lanes          (smlh_no_turnoff_lanes),
    .xdlh_xmlh_pid                  (b_xplh_xmlh_sp.pid),
    .smlh_l0p_update                (smlh_l0p_update),
    .smlh_l0p_link_mode             (smlh_l0p_next_link_mode),
    .ltssm_l0p_lanes_active         (ltssm_l0p_lanes_active),
    .ltssm_l0p_cmd                  (ltssm_l0p_cmd),
    .ltssm_l0p_cmd_4_eieos_req      (ltssm_l0p_cmd_4_eieos_req),
// ---------------------------------outputs ------------------------
    .xmtbyte_stp_start              (cpcie_xmtbyte_stp_start),
    .xmtbyte_ts_pcnt                (cpcie_xmtbyte_ts_pcnt),
    .xmtbyte_ts_data_diff           (cpcie_xmtbyte_ts_data_diff),
    .xmtbyte_1024_ts_sent           (cpcie_xmtbyte_1024_ts_sent),
    .xmtbyte_spd_chg_sent           (cpcie_xmtbyte_spd_chg_sent),
    .xmtbyte_dis_link_sent          (cpcie_xmtbyte_dis_link_sent),
    .xmtbyte_loe_2_ts1_ec_00b_sent  (cpcie_xmtbyte_loe_2_ts1_ec_00b_sent),
    .xmtbyte_txdata_dv              (cpcie_xmtbyte_txdata_dv),
    .xmtbyte_txdata                 (cpcie_xmtbyte_txdata),
    .xmtbyte_txdatak                (cpcie_xmtbyte_txdatak),
    .xmtbyte_ossending              (xmtbyte_ossending_org),
    .xmtbyte_txstartblock           (cpcie_xmtbyte_txstartblock),
    .xmtbyte_skp_os_align_sts       (xmtbyte_skp_os_align_sts_org),
    .xmtbyte_ltssm_in_compliance    (cpcie_xmtbyte_ltssm_in_compliance),
    .xmtbyte_ts1_sent               (cpcie_xmtbyte_ts1_sent),
    .xmtbyte_ts2_sent               (cpcie_xmtbyte_ts2_sent),
    .xmtbyte_fts_sent               (cpcie_xmtbyte_fts_sent),
    .xmtbyte_idle_sent              (cpcie_xmtbyte_idle_sent),
    .xmtbyte_eidle_sent             (cpcie_xmtbyte_eidle_sent),
    .xmtbyte_eies_sent              (cpcie_xmtbyte_eies_sent),
    .xmtbyte_skip_sent_o            (cpcie_xmtbyte_skip_sent),
    .xmtbyte_skip_insert            (xmtbyte_skip_insert),
    .xmtbyte_ctlskip_sent           (cpcie_xmtbyte_ctlskip_sent),
    .xmtbyte_sent_24_ts0_ec00       (xmtbyte_sent_24_ts0_ec00),
    .xmtbyte_gen6_compliance_sending (xmtbyte_gen6_compliance_sending),
    .xmtbyte_pat_fts_sent           (cpcie_xmtbyte_pat_fts_sent),
    .xmtbyte_pat_eidle_start_sent   (cpcie_xmtbyte_pat_eidle_start_sent),
    .xmtbyte_xdlh_halt_o            (cpcie_xmlh_xdlh_halt),
    .xmlh_skip_pending              (cpcie_xmlh_skip_pending),
    .xmtbyte_cmd_is_data            (cpcie_xmtbyte_cmd_is_data),
    .xplh_xmlh_sof                  (xplh_xmlh_sof),              // start of flit
    .xmtbyte_2_compliance_ts1_sent  (xmtbyte_2_compliance_ts1_sent),
    .xmtbyte_sris_mode_enabled      (xmtbyte_sris_mode_enabled),
    .xmlh_xfsh_last_flit            (xmlh_xfsh_last_flit),
    .xmbyte_flit_data_stream        (xmbyte_flit_data_stream),
    .xmtbyte_l0p_eidle_sent         (xmtbyte_l0p_eidle_sent),
    .xmtbyte_l0p_ts1_sent           (xmtbyte_l0p_ts1_sent),
    .xmtbyte_l0p_ts2_sent           (xmtbyte_l0p_ts2_sent),
    .xmtbyte_l0p_linkwidth_changed  (xmtbyte_l0p_linkwidth_changed),
    .xmtbyte_l0p_link_in_training   (xmtbyte_l0p_link_in_training),
    .xmtbyte_l0p_sris_mode_enabled  (xmtbyte_l0p_sris_mode_enabled),
    .xmtbyte_l0p_state_in_upsize    (xmtbyte_l0p_state_in_upsize),
    .ltssm_cmd_eqts0                (ltssm_cmd_eqts0),
    .xmtbyte_sris_enable            (xmtbyte_sris_enable),
    .xmtbyte_link_in_training       (cpcie_xmtbyte_link_in_training),
    .xmtbyte_txelecidle             (cpcie_xmtbyte_txelecidle),
    .xmtbyte_g5_lpbk_deassert       (xmtbyte_g5_lpbk_deassert),
    .xmtbyte_txdetectrx_loopback    (cpcie_xmtbyte_txdetectrx_loopback),
    .xmlh_rst_flit_alignment        (xmlh_rst_flit_alignment),
    .xmtbyte_latched_loadpat_ltssmstate (xmtbyte_latched_loadpat_ltssmstate),
    .xmtbyte_einj_in_os             (xmtbyte_einj_in_os),
    .xmtbyte_txcompliance           (cpcie_xmtbyte_txcompliance),
    .crnt_rate                      (crnt_rate_enc)
); // xmlh_byte_xmt

assign b_xplh_xmlh_sp.rst_flit_alignment = xmlh_rst_flit_alignment;

logic [(NL*NBK)-1:0] xmteinj_input_txdatak;

logic [(NL*NBK)-1:0] smb_einj_ouput_txdatak;

xmlh_smb_einj
 u_xmlh_smb_einj (
// ---- inputs ---------------
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .active_nb                      (active_nb),
    .current_data_rate              (current_data_rate_scr),
    .xmtbyte_ts1_sent               (|cpcie_xmtbyte_ts1_sent),
    .xmtbyte_ts2_sent               (|cpcie_xmtbyte_ts2_sent),
    .xmtbyte_pat_fts_sent           (cpcie_xmtbyte_pat_fts_sent),
    .xmtbyte_pat_eidle_start_sent   (cpcie_xmtbyte_pat_eidle_start_sent),
    .xmtbyte_skip_sent              (cpcie_xmtbyte_skip_sent),
    .xmtbyte_txstartblock           (xmtbyte_txstartblock_org[0]),
    .xmtbyte_txdata_dv              (xmtbyte_txdata_dv_org),
    .xmtbyte_txdata                 (xmtbyte_txdata_org),
    .xmtbyte_txdatak_org            (xmtbyte_txdatak_org),
    .cdm_ras_des_einj3_enable       (cdm_ras_des_einj3_enable),
    .cdm_ras_des_einj3_count        (cdm_ras_des_einj3_count),
    .cdm_ras_des_einj3_smb_type     (cdm_ras_des_einj3_smb_type),
// ---- outputs ---------------
    .xmtbyte_txdatak                (smb_einj_ouput_txdatak), // EINJ data should not be connected to LTSSM.
    .xmlh_einj3_osmsk_evt           (xmlh_einj3_osmsk_evt)
); // xmlh_smb_einj

assign xmteinj_input_txdatak = smb_einj_ouput_txdatak;

// xmlh_os_einj inputs
logic [(NL*NB*8)-1:0]                          xmteinj_input_txdata;
logic                                          xmteinj_input_txdata_dv;
logic [(NL*MAC_TXSB_WD)-1:0]                   xmteinj_input_txstartblock;
logic [NL-1:0][MAC_TXSB_WD-1:0][OSFLG_WD-1:0]  xmteinj_input_ossending;
logic [NL-1:0][2:0]                            xmteinj_input_skp_os_align_sts;
logic [NL-1:0]                                 xmteinj_input_txelecidle;
logic [NL-1:0]                                 xmteinj_input_txelecidle_scramble;
logic [NL-1:0]                                 xmteinj_input_pm_xmlh_scramble_even_parity;
logic                                          xmteinj_input_txdetectrx_loopback;
logic [NL-1:0]                                 xmteinj_input_txcompliance;
logic                                          xmteinj_input_link_in_training;
// xmlh_os_einj outputs
logic [(NL*NB*8)-1:0]                          xmteinj_txdata;
logic                                          xmteinj_txdata_dv;
logic [(NL*NBK)-1:0]                           xmteinj_txdatak;
logic [(NL*MAC_TXSB_WD)-1:0]                   xmteinj_txstartblock;
logic [NL-1:0][MAC_TXSB_WD-1:0][OSFLG_WD-1:0]  xmteinj_ossending;
logic [NL-1:0][2:0]                            xmteinj_skp_os_align_sts;
logic [NL-1:0]                                 xmteinj_txelecidle;
logic [NL-1:0]                                 xmteinj_txelecidle_scramble;
logic [NL-1:0]                                 xmteinj_pm_xmlh_scramble_even_parity;
logic                                          xmteinj_txdetectrx_loopback;
logic [NL-1:0]                                 xmteinj_txcompliance;
logic                                          xmteinj_link_in_training;

always_comb begin: xmlh_os_einj_inputs_PROC
  xmteinj_input_txdata                       = xmtbyte_txdata_org;
  xmteinj_input_txdata_dv                    = xmtbyte_txdata_dv_org;
  // xmteinj_input_txdatak                   = smb_einj_ouput_txdatak; //connected in ifdef CX_RAS_DES_EINJ_ENABLE
  xmteinj_input_txelecidle                   = xmtbyte_txelecidle_org;
  xmteinj_input_ossending                    = xmtbyte_ossending_org ;
  xmteinj_input_txstartblock                 = '0;
  xmteinj_input_txstartblock                 = xmtbyte_txstartblock_org;

  for(int ii = 0 ; ii < NL ; ii++ ) begin
      xmteinj_input_skp_os_align_sts[ii]     = P_SKP_REPLACE_IDLE;
  end
  xmteinj_input_skp_os_align_sts             = xmtbyte_skp_os_align_sts_org;

  xmteinj_input_txelecidle_scramble          = '0;

  xmteinj_input_pm_xmlh_scramble_even_parity = '0;

  xmteinj_input_txdetectrx_loopback          = xmtbyte_txdetectrx_loopback_org ;
  xmteinj_input_txcompliance                 = xmtbyte_txcompliance_org ;
  xmteinj_input_link_in_training             = xmtbyte_link_in_training_org;
end // xmlh_os_einj_inputs_PROC

xmlh_os_einj
 #(
    .INST(INST)
) u_xmlh_os_einj (
// ---- inputs ---------------
    .core_clk                            (core_clk),
    .core_rst_n                          (core_rst_n),
    .smlh_lanes_active                   (smlh_lanes_active),
    .current_data_rate                   (current_data_rate_scr),
    .active_nb                           (active_nb),
    .ltssm_flit_mode                     (ltssm_flit_mode_tx),
    .smlh_ltssm_state                    (smlh_ltssm_state),
    .cfg_flit_err_inj_latency            (cfg_flit_err_inj_latency),
    .cfg_os_einj_ctrl_1                  (cfg_os_einj_ctrl_1),
    .cfg_os_einj_ctrl_2                  (cfg_os_einj_ctrl_2),
    .xmtbyte_latched_loadpat_ltssmstate  (xmtbyte_latched_loadpat_ltssmstate),
    .xmtbyte_einj_in_os                  (xmtbyte_einj_in_os),
    .xmtbyte_txdata                      (xmteinj_input_txdata),
    .xmtbyte_txdata_dv                   (xmteinj_input_txdata_dv),
    .xmtbyte_txdatak                     (xmteinj_input_txdatak),
    .xmtbyte_ossending                   (xmteinj_input_ossending),
    .xmtbyte_txstartblock                (xmteinj_input_txstartblock),
    .xmtbyte_skp_os_align_sts            (xmteinj_input_skp_os_align_sts),
    .xmtbyte_txelecidle                  (xmteinj_input_txelecidle),
    .xmtbyte_txelecidle_scramble         (xmteinj_input_txelecidle_scramble),
    .pm_xmlh_scramble_even_parity        (xmteinj_input_pm_xmlh_scramble_even_parity),
    .xmtbyte_txdetectrx_loopback         (xmteinj_input_txdetectrx_loopback),
    .xmtbyte_txcompliance                (xmteinj_input_txcompliance),
    .xmtbyte_link_in_training            (xmteinj_input_link_in_training),
// ---- outputs ---------------
    .xmlh_tx_os_einj_status              (xmlh_tx_os_einj_status),
    .xmteinj_txdata                      (xmteinj_txdata),
    .xmteinj_txdata_dv                   (xmteinj_txdata_dv),
    .xmteinj_txdatak                     (xmteinj_txdatak),
    .xmteinj_ossending                   (xmteinj_ossending),
    .xmteinj_txstartblock                (xmteinj_txstartblock),
    .xmteinj_skp_os_align_sts            (xmteinj_skp_os_align_sts),
    .xmteinj_txelecidle                  (xmteinj_txelecidle),
    .xmteinj_txelecidle_scramble         (xmteinj_txelecidle_scramble),
    .xmteinj_pm_xmlh_scramble_even_parity(xmteinj_pm_xmlh_scramble_even_parity),
    .xmteinj_txdetectrx_loopback         (xmteinj_txdetectrx_loopback),
    .xmteinj_txcompliance                (xmteinj_txcompliance),
    .xmteinj_link_in_training            (xmteinj_link_in_training)
);

// Connect to scrambler input signals
assign xmtbyte_txdata                   = xmteinj_txdata;
assign xmtbyte_txdata_dv                = xmteinj_txdata_dv;
assign xmtbyte_txdatak                  = xmteinj_txdatak;
assign xmtbyte_ossending                = xmteinj_ossending ;
assign xmtbyte_txstartblock             = xmteinj_txstartblock;
assign xmtbyte_skp_os_align_sts         = xmteinj_skp_os_align_sts;
assign xmtbyte_txelecidle               = xmteinj_txelecidle;
assign xmtbyte_txdetectrx_loopback      = xmteinj_txdetectrx_loopback;
assign xmtbyte_txcompliance             = xmteinj_txcompliance;
assign xmtbyte_link_in_training         = xmteinj_link_in_training;


// Scramble logic
wire [NL-1:0] scrambler_disable_lanes_l0p;
assign scrambler_disable_lanes_l0p = (xmtbyte_l0p_link_in_training) ?  (ltssm_l0p_lanes_active & ~ltssm_l0p_last_lanes_active) : 0; 

//CALC_PARITY_BEFORE_SCRAMBLE=0 denotes SKP parity calculation done after scrambling in Tx side
scramble
 #(.INST(INST), .RX_SIDE(0), .REGOUT(`CX_XMLH_SCRAMBLE_REGOUT), .GEN3_REGIN(`CX_XMLH_GEN3_SCRAMBLE_REGIN), .GEN3_REGOUT(`CX_XMLH_GEN3_SCRAMBLE_REGOUT), .GEN3_LFSR_REGOUT(`CX_XMLH_GEN3_SCRAMBLE_LFSR_REGOUT), .CALC_PARITY_BEFORE_SCRAMBLE(0) , .PRECODING_REGOUT(`CX_XMLH_PRECODING_REGOUT) , .GLAYCODING_REGOUT(`CX_XMLH_GLAYCODING_REGOUT)) u_scramble (
// ---- inputs ---------------
    .core_rst_n                     (core_rst_n),
    .core_clk                       (core_clk),
    .cfg_elastic_buffer_mode        (1'b0),
    .scrambler_disable              (smlh_scrambler_disable | xmtbyte_link_in_training),
    .scrambler_disable_lanes_l0p    (scrambler_disable_lanes_l0p),
    .smlh_l0p_link_mode             (smlh_l0p_link_mode),
    .l0p_sris_mode_enabled          (xmtbyte_l0p_sris_mode_enabled),
    .data_dv                        ({NL{xmtbyte_txdata_dv}}),
    .data                           (xmtbyte_txdata),
    .datak                          (xmtbyte_txdatak),
    .error                          ({NL*NB{1'b0}}),
    .wait4idle                      ({NL{1'b0}}),    // Not used in xmlh side
    .rxskipremoved                  ({NL*MAC_TXSB_WD{1'b0}}),
    .data_osfound                   (xmtbyte_ossending),
    .rxskipadded                    ({NL*MAC_TXSB_WD{1'b0}}),
    .gen6_compliance_sending        (xmtbyte_gen6_compliance_sending),
    .active_nb                      (active_nb),
    .aligned                        ({NL{1'b1}}), //gates: must revisit for first EIEOS occuring in core
    .latched_smlh_link_up           (latched_smlh_link_up),
    .latched_flip_ctrl              (latched_flip_ctrl),
    .smlh_lane_flip_ctrl            (smlh_lane_flip_ctrl),
    .cfg_no_seed_value_change       (cfg_no_seed_value_change),
    .active_nb_gen34                (active_nb_gen34),
    .xmtbyte_txelecidle             (xmtbyte_txelecidle),
    .current_data_rate              (current_data_rate_scr),
    .cfg_gen3_scrambler_disable     (cfg_gen3_scrambler_disable),
    .cfg_gen3_dc_balance_disable    (cfg_gen3_dc_balance_disable),
    .smlh_link_mode                 (smlh_link_mode),
    .startblock                     (xmtbyte_txstartblock),
    .skp_os_align_sts               (xmtbyte_skp_os_align_sts),
    .ltssm_in_compliance            (xmtbyte_ltssm_in_compliance),
    .smlh_ltssm_state               (smlh_ltssm_state),
    .cfg_precoding_enable           (smlh_tx_precoding_on),
    .smlh_flit_mode_enable          (ltssm_flit_mode_enable),
    .lanes_active                   (power_saving_lanes_active),
    .crnt_rate_enc                  (crnt_rate_enc),

// ---- outputs ---------------
    .scramble_lfsr_rollover         (scramble_lfsr_rollover),
    .scramble_even_parity           (scramble_even_parity),
    .scramble_startblock            (scramble_startblock),
    .scramble_data_osfound          (scramble_data_osfound),
    .scramble_dcb_det               (),
    .scramble_data_g6_skprm         (),
    .scramble_data_g6_skpadd        (),
    .scramble_ints0                 (scramble_ints0),
    .scramble_ints1                 (scramble_ints1),
    .scramble_ints2                 (scramble_ints2),
    .scramble_inskp                 (scramble_inskp),
    .scramble_skp_os_align_sts      (scramble_skp_os_align_sts),
    .scramble_ineie                 (),
    .scramble_eie_det               (),
    .scramble_insds                 (),
    .scramble_data_dv               (scramble_data_dv),
    .scramble_data                  (scramble_data_org),
    .scramble_aligned               (),
    .scramble_data_comma            (),
    .scramble_data_skip             (),
    .scramble_data_skprm            (),
    .scramble_datak                 (scramble_datak),
    .scramble_error                 (scramble_error),
    .wait4idle_nd                   ()   // Can be open, since not used in xmlh
); // scramble

xmlh_crc_einj
 u_xmlh_crc_einj (
// ---- inputs ---------------
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .active_nb                      (active_nb),
    .current_data_rate              (current_data_rate_scr),
    .smlh_ltssm_state               (smlh_ltssm_state),
    .ltssm_flit_mode                (ltssm_flit_mode_tx),
    .scramble_startblock            (scramble_startblock),
    .scramble_ints0                 (scramble_ints0),
    .scramble_ints1                 (scramble_ints1),
    .scramble_ints2                 (scramble_ints2),
    .scramble_inskp                 (scramble_inskp),
    .scramble_skp_os_align_sts      (scramble_skp_os_align_sts),
    .scramble_data_dv               (scramble_data_dv),
    .scramble_data_org              (scramble_data_org),
    .scramble_datak                 (scramble_datak),
    .cdm_ras_des_einj0_enable       (cdm_ras_des_einj0_enable),
    .cdm_ras_des_einj0_crc_type     (cdm_ras_des_einj0_crc_type),
// ---- outputs ---------------
    .scramble_data                  (scramble_data),
    .xmlh_einj0_oscrc_evt           (xmlh_einj0_oscrc_evt)
); // xmlh_crc_einj

assign reversed_data  = scramble_data;
assign reversed_datak = scramble_datak;
assign reversed_error = scramble_error;
always @(*) begin
  integer ln;
  for (ln=0; ln<NL; ln=ln+1) begin
      int_scramble_even_parity[ln] = scramble_even_parity[(ln+1)*MAC_TXSB_WD -1];
  end // for-loop
end
assign xmlh_scramble_even_parity = int_scramble_even_parity;

assign g6_xmtbyte_txelecidle      = xmtbyte_txelecidle;
assign g6_scramble_data_dv        = scramble_data_dv;
assign g6_scramble_startblock     = scramble_startblock;
assign g6_reversed_data           = reversed_data;
assign g6_reversed_datak          = reversed_datak;
assign g6_scramble_data_osfound   = scramble_data_osfound;

//Tx pipe
wire ltssm_in_lpbk_exit_timeout = smlh_ltssm_state == S_LPBK_EXIT_TIMEOUT;
xmlh_pipe

#(INST) u_xmlh_pipe(
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .current_data_rate              (current_data_rate_scr),
    .cfg_link_capable               (cfg_link_capable),
    .txdata                         (g6_reversed_data),
    .txdatak                        (g6_reversed_datak),
    .txdata_dv                      (g6_scramble_data_dv),
    .txstartblock                   (g6_scramble_startblock),
    .txdata_osfound                 (g6_scramble_data_osfound),
    .txerror                        (reversed_error),
    .txdetectrx_loopback            (xmtbyte_txdetectrx_loopback),
    .txelecidle                     (g6_xmtbyte_txelecidle),
    .tx_g5_lpbk_deassert            (xmtbyte_g5_lpbk_deassert),
    .txcompliance                   (xmtbyte_txcompliance),
    .margin_cmd                     (smlh_margin_cmd),
    .margin_offset                  (smlh_margin_offset),
    .margin_clr_error_log           (smlh_margin_clr_error_log),
    .ltssm_lpbk_slave_lut           (ltssm_lpbk_slave_lut),
    .ltssm_in_lpbk_exit_timeout     (ltssm_in_lpbk_exit_timeout),
    .ltssm_in_lpbk                  (ltssm_in_lpbk),
    .ltssm_powerdown                (ltssm_powerdown),
    .phy_mac_phystatus              (phy_mac_phystatus),

    .xpipe_txdata                   (mac_phy_txdata),
    .xpipe_txdatak                  (mac_phy_txdatak),
    .xpipe_txdatavalid              (mac_phy_txdatavalid),
    .xpipe_txstartblock             (mac_phy_txstartblock),
    .xpipe_txsyncheader             (mac_phy_txsyncheader),
    .xpipe_txdetectrx_loopback      (mac_phy_txdetectrx_loopback),
    .xpipe_txelecidle               (mac_phy_txelecidle),
    .xpipe_txcompliance             (mac_phy_txcompliance),
    .xpipe_margin_cmd               (mac_phy_margin_cmd),
    .xpipe_margin_offset            (mac_phy_margin_offset),
    .xpipe_margin_clr_error_log     (mac_phy_margin_clr_error_log),
    .xpipe_txdata_osfound           (xpipe_txdata_osfound),
    .xpipe_powerdown                (xpipe_powerdown),
    .xpipe_phystatus                (xpipe_phystatus)
); // xmlh_pipe


endmodule
