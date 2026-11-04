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
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/products/cx_phy_logical.sv#6 $
// -------------------------------------------------------------------------
// --- Module Description: PCI-Express PHY Logical Core (Layer 1)
// -----------------------------------------------------------------------------
// --- This module contains the complete PHY Logical Core.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer2/svif/tx_lp_if.svh"
`include "Spif/svif/spif_if.svh"
`include "Spif/pkg/spif_pkg.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
`include "products/cx_pl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "power_management/DWC_pcie_pm_pkg.svh"


module cx_phy_logical
import DWC_pcie_core_pkg::ltssm_state_e;
import DWC_pcie_core_pkg::S_DETECT_QUIET;
import DWC_pcie_core_pkg::S_DETECT_ACT;
import DWC_pcie_core_pkg::S_POLL_COMPLIANCE;
import DWC_pcie_core_pkg::S_PRE_DETECT_QUIET;
import DWC_pcie_core_pkg::S_CFG_LINKWD_START;
import DWC_pcie_core_pkg::S_CFG_LINKWD_ACEPT;
import DWC_pcie_core_pkg::S_CFG_LANENUM_WAIT;
import DWC_pcie_core_pkg::S_CFG_LANENUM_ACEPT;
import DWC_pcie_core_pkg::S_CFG_COMPLETE;
import DWC_pcie_core_pkg::S_CFG_IDLE;
import DWC_pcie_core_pkg::S_RCVRY_LOCK;
import DWC_pcie_core_pkg::S_RCVRY_RCVRCFG;
import DWC_pcie_core_pkg::S_RCVRY_IDLE;
import DWC_pcie_core_pkg::S_L0;
import DWC_pcie_core_pkg::S_L0S;
import DWC_pcie_core_pkg::S_L123_SEND_EIDLE;
import DWC_pcie_core_pkg::S_L2_IDLE;
import DWC_pcie_core_pkg::S_L2_WAKE;
import DWC_pcie_core_pkg::S_DISABLED_IDLE;
import DWC_pcie_core_pkg::S_DISABLED;
import DWC_pcie_core_pkg::S_LPBK_ENTRY;
import DWC_pcie_core_pkg::S_LPBK_ACTIVE;
import DWC_pcie_core_pkg::S_LPBK_EXIT;
import DWC_pcie_core_pkg::S_LPBK_EXIT_TIMEOUT;
import DWC_pcie_core_pkg::S_RCVRY_EQ0;
import DWC_pcie_core_pkg::S_RCVRY_EQ1;
import DWC_pcie_core_pkg::S_RCVRY_EQ2;
import DWC_pcie_core_pkg::S_RCVRY_EQ3;
import cx_pl_pkg::rbuf_struct;
import cx_pl_pkg::PM_ENTER_L1;
import cx_pl_pkg::dllp_struct;
import cx_pl_pkg::tx_cmd_struct;
import cx_pl_pkg::xplh_sideband_struct;
import cx_pl_pkg::xplh_sideband_rasdes_fm;
import cx_pl_pkg::rplh_xplh_fm_retry_t;
import cx_pl_pkg::fm_dllp_struct;
import cx_pl_pkg::P_TX_SEQNUM_WD;
import DWC_pcie_core_pkg::rplh_flit_logging_interface_struct;
import DWC_pcie_core_pkg::rmlh_flit_logging_interface_struct;
import DWC_pcie_core_pkg::smlh_flit_logging_interface_struct;
import DWC_pcie_core_pkg::xplh_cdm_flit_latency_track_t;
import DWC_pcie_core_pkg::flit_err_inj_interface_struct;
import DWC_pcie_core_pkg::flit_err_inj_status_struct;
import DWC_pcie_core_pkg::cfg_os_einj_ctrl_1_t;
import DWC_pcie_core_pkg::cfg_os_einj_ctrl_2_t;
import DWC_pcie_core_pkg::cfg_os_einj_status_t;
import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
import DWC_pcie_ctl_pkg::ORIG_DATA_WD;
import DWC_pcie_ctl_pkg::PIPE_DATA_WD;
import spif_pkg::state_enc_e;
import spif_pkg::protocol_cfg_t;
import DWC_pcie_ctl_pkg::ltssm_cxl_enable_t;
import DWC_pcie_core_pkg::CFG_CXL_PORT_ENABLE_WD;
import DWC_pcie_pm_pkg::usp_link_fsm_state_e;
import DWC_pcie_pm_pkg::dsp_link_fsm_state_e;
import DWC_pcie_pm_pkg::pm_protocol_to_link_struct;
import DWC_pcie_pm_pkg::pm_link_to_protocol_struct;
#(
parameter INST         = 0,                                       // The uniquifying parameter for each port logic instance.
parameter CNT_WIDTH    = 3
)

                     (
output   dllp_struct        xplh_pm_dllp_ack,
output logic                xmlh_cmd_if_lp_ack,       // Acknowledge from xtlh_cmd_if to PM indicating entering flush state
output tx_cmd_struct        xmlh_xplh_cmd,            // Command Bus Interface
input                       pm_xmlh_lp_req,           // PM Request to xtlh_cmd_if to enter low power
input                       cfg_flit_mode_enable,
input                       cfg_pcie_cap_flit_mode_sup,
input                       cfg_flit_mode_dis,
input                       cfg_flit_sris_clocking,
input                       cfg_reciver_l0p_supported,
input                       cfg_comm_clk_config,
input                       pm_block_phystatus,             // block phystatus detection in rmlh_pipe while pipe 4.3 gasket drives powerdown
output  protocol_cfg_t      splh_protocol_cfg, // SPIF Protocol Configuration to PLH hierarchy
input                       pm_block_tlp_ack,  // SDLH Command Interface PM BLOCK_TLP Acknowledge
spif_if.master_mp           b_splh_spif,     // SPLH to VLSM SPIF Interface, connects PLH Layer to ARB/MUX
input [CFG_CXL_PORT_ENABLE_WD-1:0]cfg_cxl_port_enable,           // CXL port enables
input   [15:0]                    cfg_cxl_port_vid,              // cxl dvsec vendor id
input                             cfg_cxl_retimers_pre_mismatched, // cxl retimers present mismatched
input   [1:0]                     cfg_retimers_pre_detected,     // cxl retimers present detected {retimer2,retimer1}
input                             cfg_pcie_slot_clk_config,      // connect to the same ref clock

input   [2:0]               pm_current_data_rate,           // current_data_rate shadowed in pm_ctrl
input                       core_clk,                       // Core clock
input                       core_rst_n,                     // When asserted, reset the core except for the PMC domain.
input                       app_init_rst,                   // N/A for end-point, used by downstream port of switch,
input                       core_clk_ug,                    // An ungated version of core_clk used to track phystatus during powerdown states
input                       pipe_msgbus_rst_n,
input                       app_sris_mode,                  // application signal to enable the SRIS mode
input                       app_ltssm_enable,               // application signal to enable the LTSSM , if it is not enable, then LTSSM will be in DETECT QUIET
output logic                smlh_training_rst_n,            // Hot reset from upstream component, routed to core_rst_n
output  ltssm_state_e       smlh_ltssm_state,               // Current LTSSM state. Intended to be used as debug information
output  ltssm_state_e       smlh_ltssm_state_o,             // Current LTSSM state core_clk domain version
output logic [63:0]         cxpl_debug_info,                // Debug bus provides internal status information
                                                            // cxpl_debug_info[63]    = smlh_scrambler_disable
                                                            // cxpl_debug_info[62]    = smlh_link_disable
                                                            // cxcp_debug_info[61]    = smlh_link_in_training
                                                            // cxpl_debug_info[60]    = smlh_ltssm_in_pollconfig
                                                            // cxpl_debug_info[59]    = smlh_training_rst_n
                                                            // cxpl_debug_info[58:55] = 4'b0
                                                            // cxpl_debug_info[54]    = mac_phy_txdetectrx_loopback[0]
                                                            // cxpl_debug_info[53]    = mac_phy_txelecidle[0]
                                                            // cxpl_debug_info[52]    = mac_phy_txcompliance[0]
                                                            // cxpl_debug_info[51]    = app_init_rst
                                                            // cxpl_debug_info[50:48] = 3'b0
                                                            // cxpl_debug_info[47:40] = smlh_ts_link_num
                                                            // cxpl_debug_info[39:38] = 2'b0
                                                            // cxpl_debug_info[37]    = xmtbyte_skip_sent
                                                            // cxpl_debug_info[36]    = smlh_link_up
                                                            // cxpl_debug_info[35]    = smlh_inskip_rcv
                                                            // cxpl_debug_info[34]    = smlh_ts1_rcvd
                                                            // cxpl_debug_info[33]    = smlh_ts2_rcvd,
                                                            // cxpl_debug_info[32]    = smlh_rcvd_lane_rev
                                                            // cxpl_debug_info[31:28] = smlh_ts_link_ctrl
                                                            // cxpl_debug_info[27]    = smlh_ts_lane_num_is_k237
                                                            // cxpl_debug_info[26]    = smlh_ts_link_num_is_k237
                                                            // cxpl_debug_info[25]    = rplh_rcvd_idle[0]
                                                            // cxpl_debug_info[24]    = rplh_rcvd_idle[1]
                                                            // cxpl_debug_info[23:8]  = mac_phy_txdata
                                                            // cxpl_debug_info[7:6]   = mac_phy_txdatak
                                                            // cxpl_debug_info[5:0]   = smlh_ltssm_state
output logic [`CX_INFO_EI_WD-1:0] cxpl_debug_info_ei,       // Debug bus, provides internal status information related to electrical idle
                                                            // See smlh_ltssm.v for bit field descriptions

input                           cfg_rasdp_linkdown_en,          // Enable Link Down on RASDP uncorrectable error
input                           rasdp_linkdown,

output                          rmlh_rcvd_err,                  // PHY receiving error reported from pipe interface
output logic [5:0]              smlh_autoneg_link_width,        // negotiated link width
tx_lp_if.slave_mp               b_xdlh_xplh_sp,                 // Link Layer Transmit Slave  Port XDLH->XPLH
output xplh_sideband_struct     xplh_sideband,                  // struct of signals that are part of xplh/xmlh interface before entering xplh freq_step module and used in cx_pl
output logic [5:0]              rplh_link_rxmode,               // 6 bit link width, 10000 = x16, 1000 = x8, 100 = x4, 10 = x2, 1 = x1
output logic                    rplh_flit_dl_prot_err,
output logic                    xplh_nak_ignore_link_err,
output logic                    xplh_pending,                   // XPLH Pending Signal generated from XPLH tracker
output logic                    xplh_xdlh_dllp_halt,
output rbuf_struct              xplh_retry_ram_if,
input  fm_dllp_struct           xdlh_xplh_dllp_out,
output xplh_sideband_rasdes_fm  xplh_rasdes_fm,                 // Xplh sideband rasdes will be connected to cx_pl_fm
output logic  [P_TX_SEQNUM_WD-1:0] xplh_rx_ack_seqnum,          // Level : Current Rx Ack Sequence number status for Ras D.E.S Silicon Debug
output logic  [P_TX_SEQNUM_WD-1:0] xplh_tx_seqnum_value,        // Level : Current Tx Sequence number status for Ras D.E.S Silicon Debug
input cdm_ras_des_force_linkdown_noack,                         // Force Link down when MAC does not receive ACK DLLP for long time
input                           xplh_ras_des_einj1_enable,
input                           xplh_ras_des_einj1_seq_type,
input [12:0]                    xplh_ras_des_einj1_bad_seq,
input [7:0]                     xplh_ras_des_einj1_count,
output logic [1:0]              xplh_ras_des_einj1_exp_sequm_evt,
output logic                    xplh_ras_des_einj1_ack_nak_sequm_evt,
input                           xplh_ras_des_einj2_enable,
input [1:0]                     xplh_ras_des_einj2_dllp_type,
output logic                    xplh_ptm_sot,
output logic                    xplh_ptm_request,
output logic                    xplh_ptm_response,
output logic                    rplh_ptm_sot,
output logic                    rplh_ptm_request,
output logic                    rplh_ptm_response,
output logic                    rplh_ptm_duplicate,
input [`RBUF_WIDTH -1:0]        retrymux_xplh_data,             // Data coming back from Retry buffer RAM
output logic                    xplh_acknak_pend,
output logic                    xmtbyte_stp_start,
input                           xplh_flit_count_en,
output logic [CNT_WIDTH-1:0]    xplh_flit_count,
output tx_cmd_struct            xplh_xdlh_cmd,      // Command from SDLH (CXL)/XPLH (PCIe) to XDLH
input                           xdlh_xplh_cmd_ack, // Command Complete Acknowledge from XDLH to SDLH (CXL)/XPLH (PCIe)
output logic [3:0]              smlh_autoneg_link_sp,           // negotiated link speed
output logic                    smlh_link_training_in_prog,     // link training in progress
output rplh_xplh_fm_retry_t     rplh_xplh_fm_retry,             // RPLH XPLH FM Retry 
output logic                    smlh_flit_mode_enable,
output logic [7:0]              smlh_flit_mode_enable_modules,  // both sides agreed
output logic                    smlh_ltssm_l0p_ready,
output logic [5:0]              smlh_l0p_link_mode,             // 10000 -- x16, 01000 -- x8, 00100 -- x4, 00010 -- x2, 00001 -- x1
output logic                    smlh_l0p_capable,               // l0p capable
output logic                    smlh_xdlh_eios_rcvd,            // Received eieos in flit mode
input                           xdlh_smlh_link_initiated,
input  [4:0]                    xdlh_smlh_link_width,
input                           xdlh_smlh_link_req,
input                           xdlh_smlh_goto_detect,
input                           xdlh_smlh_start_link_retrain,
output logic                    xmlh_sris_enable,               // PIPE Interface SRISEnable
output logic                    smlh_req_rst_not,               // when asserted, LTSSM is in link down other than DISABLE,HOTRESET and LPBK state where a reset is required  

input   [1:0]                     rdlh_rtlh_link_state,           // TOBEREMOVED: Data link layer state machine output
input                             rdlh_rcvd_dllp,                 // Indicates that RDLH received DLLP
output logic  [`CX_NW-1:0]        rplh_rdlh_dllp_start,           // indicate the dword location of SDPor STP
output logic  [`CX_NW-1:0]        rplh_rdlh_tlp_start,
output logic  [`CX_NW-1:0]        rplh_rdlh_nak,                  // NAK indication
output logic  [`CX_NW-1:0]        rplh_rdlh_tlp_idl,              // indicates the dword is empty and can be discarded, due to flit overhead it is possible that there are 5 empty dws in the middle of a tlp
output logic  [`CX_NW-1:0]        rplh_rdlh_tlp_pfx,              // indicates the dword location of prefixes
output logic                      rplh_rdlh_fm_nullified,         // The last TLP ending was Nullified by the Flit Marker
output logic                      rplh_rdlh_fm_poisoned,          // The last TLP ending was Poisoned by the Flit Marker
output logic  [31:0]              rplh_rdlh_fm_dllp_data,          // DLLP data extracted from DL bytes
output logic                      rplh_rdlh_fm_dllp_valid,         // Valid DLLP data
output logic                      rplh_rdlh_fm_dllp_opt_fc_up,     // DLLP is an Optimized FC update
output logic                      rplh_rdlh_pkt_dv,
output logic  [`CX_NW-1:0]        rplh_rdlh_pkt_end,              // indicate the dword location of END or EBD
output logic  [`CX_NW-1:0]        rplh_rdlh_pkt_edb,
output logic  [`TRGT_DATA_WD-1:0] rplh_rdlh_pkt_data,
output logic  [`CX_NW-1:0]        rplh_rdlh_pkt_err,              // EOP/SOP error in frame

input                       cfg_upstream_port,              // Upstream port when it is high
input                       cfg_root_compx,                 // Root complex port
input                       cfg_acknack_disable,            // ACK/NACK disable. For test/debug purpose. Default is 0.
input                       cfg_tx_throttling,              // Tx Throttling Control Bit
input                       cfg_scramble_dis,               // SCRAMBLER disable. For test/debug purpose. Default is 0.
input   [7:0]               cfg_n_fts,                      // Number of Fast training sequences. It is based on PHY implementation. Application
                                                            // should carefully choose this value.
input                       cfg_link_dis,                   // Link disable bit. This is used for downstream port that wants to start link
                                                            // disable transition. Software should set a bit in config space and then start
                                                            // link retraining. Default should be set to 0.
input                       cfg_lpbk_en,                    // Loop-back is enabled. This is used for a component in either side of link that
                                                            // wants to transition into loopback. Software should set a bit in config space
                                                            // and then start link retraining. Default should be set to 0.
input   [7:0]               cfg_link_num,                   // Link number (0 to 255), advertised to link partner if core is a downstream
                                                            // port. Default should be set to 0.
input                       cfg_ts2_lid_deskew,             // do deskew at the ts2->Logic_Idle_Data transition
input                       cfg_support_part_lanes_rxei_exit, // Polling.Active -> Polling.Config based on part of pre lanes rxei exit
input   [5:0]               cfg_forced_link_state,          // Move the link state to this value indicated. This is for testing purpose.
                                                            // Default should be set to 0.
input   [3:0]               cfg_forced_ltssm_cmd,
input                       cfg_force_en,                   // Force enable has to be a pulse signal generated from cfg block, when software
                                                            // writes. This is for testing purpose. Default should be set to 0.
input                       cfg_fast_link_mode,             // Fast link mode for simulation. This default value is 0 when core is placed in product.
input   [1:0]               cfg_fast_link_scaling_factor,   // Fast link timer scaling factor
input                       cfg_l0s_supported,              // if core implemented L0s, it is 1
input                       cfg_elastic_buffer_mode,        // 0 - nominal half full elastic buffer mode, 1 - empty mode
input   [5:0]               cfg_link_capable,               // It is application specific. It needs to be decided by application at implementation
                                                            // time. It indicates the x1, x2, x4 capability of a port. This is an output of
                                                            // PCIE spec. required config register.
input   [22:0]              cfg_lane_skew,                  // Transmit lane skew control (optional) for test equipment. Default should be 0.
input                       cfg_deskew_disable,             // Disable the automatic deskew function.
input   [3:0]               cfg_imp_num_lanes,              // implementation-specific number of lanes
input   [10:0]              cfg_skip_interval,              // Skip interval. It is recommended to follow spec to be in between 1180 to 1538 symbol
                                                            // times. Application should choose a value depended upon the 2s or 1s application.
                                                            // The default value for 1s setup is set to 0x500, 2s setup is 0x280.
input                       cfg_ext_synch,                  // Extended synch. This is only asserted if PHY is desired to have it. Otherwise,
                                                            // default is 0.
input                       cfg_hw_autowidth_dis,           // Hardware auto width disable for upconfigure
input                       cfg_reset_assert,               // Initiates a hot reset.
input                       cfg_link_retrain,               // Initiates link retraining.
input   [5:0]               cfg_margin_num_timing_steps,
input   [5:0]               cfg_margin_max_timing_offset,
input   [6:0]               cfg_margin_num_voltage_steps,
input   [5:0]               cfg_margin_max_voltage_offset,
input   [5:0]               cfg_margin_sample_rate_voltage,
input   [5:0]               cfg_margin_sample_rate_timing,
input   [4:0]               cfg_margin_maxlanes,
input                       cfg_margin_voltage_supported,
input                       cfg_margin_ind_left_right_timing,
input                       cfg_margin_ind_up_down_voltage,
input                       cfg_margin_sample_reporting_method,
input                       cfg_margin_ind_error_sampler,
input   [3:0]               cfg_rx_message_bus_write_buffer_depth,
input                       cfg_pipe_garbage_data_mode,
input                       cfg_pam4_restricted_levels_requirement,
input [3:0]                 device_type,
output logic [5:0]          smlh_link_rxmode,
output logic [5:0]          smlh_link_mode,                 // 1000 --- x8 mode, 0100 ---- x4 mode, 0010 ---- x2 mode, 0001 ---- x1 mode
output logic                smlh_link_up,                   // LTSSM link up
output logic                smlh_in_l0,                     // LTSSM in l0
output logic                smlh_in_l0s,                    // LTSSM Transmitter in l0s
output logic                smlh_in_l0_l0s,                 // LTSSM Transmitter in L0 or L0s,
output logic                smlh_in_rl0s,                   // LTSSM Receiver in rL0s
output logic                smlh_in_l1,                     // LTSSM  in L1
output logic                smlh_in_l23,                    // LTSSM in L23
output logic                smlh_l123_eidle_timeout,        // LTSSM 2ms Timer timed out while waiting for EIDLE
output logic                latched_rcvd_eidle_set,         // That we have received an EIOS
output logic [`CX_NL-1:0]   rmlh_descrambled_even_parity,   // Current rx skip even data parity from RMLH
output logic [`CX_NL-1:0]   xmlh_scramble_even_parity,      // Current tx skip even data parity from XMLH
input   dllp_struct         pm_xdlh_dllp_req,
input   [8:0]               cfg_lane_en,                    // pre-determined number of lanes
input                       cfg_gen1_ei_inference_mode,     // EI inference mode for Gen1. default 0 - using rxelecidle==1, 1 - using rxvalid==0
input   [1:0]               cfg_select_deemph_mux_bus,      // sel deemphasis {bit, var}
input   [`CX_LUT_PL_WD-1:0] cfg_lut_ctrl,                   // lane under test + gen5 control
input   [7:0]               cfg_rxstandby_control,          // Rxstandby Control
output logic                smlh_bw_mgt_status,             // Indicate that link retraining (via retrain bit) or HW autonomous link speed change has occurred
                                                            // without the port transitioning through DL_Down status
output logic                smlh_link_auto_bw_status,       // Indicate that hardware has autonomously changed link speed or width, without the port transitioning through
                                                            // DL_Down status, for reasons other than to attempt to correct unreliable link operation.
output logic [2:0]          current_data_rate,              // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=running at gen3 data rate, 3=running at gen4 data rate
output logic [2:0]                      pm_current_data_rate_others,    // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=running at gen3 data rate, 3=running at gen4 data rate
input   [`CX_PL_GEN3_CONTROL_WD-1:0]    cfg_pl_gen3_control,      // Port Logic Gen3 Control Register
input   [`CX_PL_GEN3_EQ_CONTROL_WD-1:0] cfg_pl_gen3_eq_control,   // Port Logic Gen3 EQ Control Register
input   [`CX_DIR_CHANGE_CONTROL_WD-1:0] cfg_fdbk_dirchange_control, //Port Logic EQ Direction Change Control Register
// 8 GT/s Receiver Impedance ECN:
input                                   cfg_pl_gen3_zrxdc_noncompl,     // Port Logic register bit field indicating non compliance of 2.5 GT/s receiver impedance while in 8GT/s mode.
input                                   cfg_no_seed_value_change,       // No Gen3 scrambler seed value change after linkup
input                                   cfg_perform_eq,                 // Directed control to perform equalization
input                                   cfg_ls2_eq_req,
input   [`CX_PL_GEN4_CONTROL_WD-1:0]    cfg_pl_gen4_control,    // Port Logic Gen3 Control Register
input   [`CX_PL_GEN4_EQ_CONTROL_WD-1:0] cfg_pl_gen4_eq_control, // Port Logic Gen3 EQ Control Register
input   [`CX_GEN4_DIR_CHANGE_CONTROL_WD-1:0] cfg_gen4_fdbk_dirchange_control, //Port Logic Gen3 EQ Feedback Direction Change Control Register
input   [`CX_NL*`CX_RX_PSET_WD-1:0]     cfg_lec_g4_pset_lrx,            // Upstream Component Receiver Preset Hint (Not applicable to EP/SW_UP)
input   [`CX_NL*`CX_RX_PSET_WD-1:0]     cfg_lec_g4_pset_rrx,            // Downstream Component Receiver Preset Hint (Not applicable to EP/SW_UP)
input   [`CX_PL_GEN5_CONTROL_WD-1:0]    cfg_pl_gen5_control,    // Port Logic Gen3 Control Register
input   [`CX_PL_GEN5_EQ_CONTROL_WD-1:0] cfg_pl_gen5_eq_control, // Port Logic Gen3 EQ Control Register
input   [`CX_GEN5_DIR_CHANGE_CONTROL_WD-1:0] cfg_gen5_fdbk_dirchange_control, //Port Logic Gen3 EQ Feedback Direction Change Control Register
input                               cfg_bypass_eq_enable,           // enable bypass eq
input                               cfg_no_eq_needed_enable,        // enable No Eq Needed
input                               cfg_tx_precode_req,             // Transmitted Precode Request
input   [`CX_NL*`CX_RX_PSET_WD-1:0] cfg_lec_g5_pset_lrx,            // Upstream Component Receiver Preset Hint (Not applicable to EP/SW_UP)
input   [`CX_NL*`CX_RX_PSET_WD-1:0] cfg_lec_g5_pset_rrx,            // Downstream Component Receiver Preset Hint (Not applicable to EP/SW_UP)
input   [`CX_PL_GEN6_CONTROL_WD-1:0]    cfg_pl_gen6_control,    // Port Logic Gen3 Control Register
input   [`CX_PL_GEN6_EQ_CONTROL_WD-1:0] cfg_pl_gen6_eq_control, // Port Logic Gen3 EQ Control Register
input                               cfg_g6_tx_precode_req,             // GEN6 Transmitted Precode Request
input   [`CX_GEN6_DIR_CHANGE_CONTROL_WD-1:0] cfg_gen6_fdbk_dirchange_control, //Port Logic Gen3 EQ Feedback Direction Change Control Register
input   [`CX_NL*`CX_RX_PSET_WD-1:0] cfg_lec_g6_pset_lrx,            // Upstream Component Receiver Preset Hint (Not applicable to EP/SW_UP)
input   [`CX_NL*`CX_RX_PSET_WD-1:0] cfg_lec_g6_pset_rrx,            // Downstream Component Receiver Preset Hint (Not applicable to EP/SW_UP)
input                               cfg_alt_protocol_enable,        // enable alternate protocol
input   [`CX_PL_MULTILANE_CONTROL_WD-1:0] cfg_pl_multilane_control,

input                       sticky_rst_n,                   // Cold reset
input                       cfg_gen2_support,               // core is enabled to run at gen 2 speeds
input   [3:0]               cfg_pcie_max_link_speed,        // Max link speed
input   [7:0]               cfg_gen2_n_fts,                 // number of fts's to send in gen 2 speeds
input   [3:0]               cfg_target_link_speed,          // Target link speed
input                       cfg_enter_compliance,           // Directed enter compliance
input                       cfg_sel_de_emphasis,            // level of de emphasis
input   [2:0]               cfg_transmit_margin,            // controls the value of the non-deemphasized voltage level at the Transmitter pins.
input                       cfg_enter_mod_compliance,       // Directed enter modified compliance
input                       cfg_compliance_sos,             // Send skips during compliance
input   [3:0]               cfg_compliance_de_emphasis,     // compliance de-emphasis level
input                       cfg_directed_speed_change,      // config bit to start speed change
input                       cfg_phy_txswing,                // controls mac_phy_txswing signal to the phy
input                       cfg_tx_compliance_rcv,          // Sets the compliance received bit in the TS1
output logic                smlh_clr_enter_compliance,      // Signal the cdm that the "Enter Compliance" bit in the "Link Control" register should be cleared
output logic                smlh_tx_margin_rst,             // Signal the cdm that the "Transmit Margin" field in the "Link Control 2" register should be cleared
output logic                smlh_core_rst_n_release_pulse,  // assign DEFAULT_GEN2_SPEED_CHANGE to cfg_directed_speed_change
output logic                smlh_dir_spd_chg_rising_edge,   // clear cfg_directed_speed_change
output logic                smlh_dir_linkw_chg_started,     // clear cfg_directed_link_width_change
output logic                smlh_ltssm_in_hotrst_dis_entry,
output logic                usp_g3_eq_redo_executed_int,    // USP gen3 eq redo executed interrupt
output logic                usp_g4_eq_redo_executed_int,    // USP gen4 eq redo executed interrupt
output logic                usp_g5_eq_redo_executed_int,    // USP gen5 eq redo executed interrupt
output logic                smlh_ls2_eq_req,                // Equalization Request
output logic [3:1]          smlh_ls2_eq_success,            // Equalization Successful {Phase 3, Phase 2, Phase 1}
output logic                smlh_ls2_eq_cmpl,               // Equalization Complete
output logic                smlh_ls2_eq_enter,              // Equalization Entered
output logic                smlh_ltssm_in_detectquiet,
output logic                smlh_ltssm_state_rcvry_eq,
output logic                smlh_ls2_g4_eq_req,             // g4 Equalization request
output logic [3:1]          smlh_ls2_g4_eq_success,         // g4 Equalization Successful {Phase 3, Phase 2, Phase 1}
output logic                smlh_ls2_g4_eq_cmpl,            // g4 Equalization Complete
output logic                smlh_ls2_g4_eq_enter,           // g4 Equalization Entered
output logic [`CX_NL*`CX_RX_PSET_WD-1:0]  smlh_lec_g4_pset_lrx,   // g4 Latest Receiver Preset requested from Upstream Component (Not applicable to RC/SW_DW)
output logic                smlh_ls2_g5_eq_req,             // g5 Equalization request
output logic [3:1]          smlh_ls2_g5_eq_success,         // g5 Equalization Successful {Phase 3, Phase 2, Phase 1}
output logic                smlh_ls2_g5_eq_cmpl,            // g5 Equalization Complete
output logic                smlh_ls2_g5_eq_enter,           // g5 Equalization Entered
output logic [`CX_NL*`CX_RX_PSET_WD-1:0]  smlh_lec_g5_pset_lrx,   // g5 Latest Receiver Preset requested from Upstream Component (Not applicable to RC/SW_DW)
output logic [1:0]          smlh_elbc_rcvd,                 // enhanced link behavior control
output logic                smlh_tx_precoding_on,           // Transmitter precoding on
output logic                smlh_noeq_needed_rcvd,          // No EQ Needed Received
output logic                smlh_ls2_g6_eq_req,             // g6 Equalization request
output logic [3:1]          smlh_ls2_g6_eq_success,         // g6 Equalization Successful {Phase 3, Phase 2, Phase 1}
output logic                smlh_ls2_g6_eq_cmpl,            // g6 Equalization Complete
output logic                smlh_ls2_g6_eq_enter,           // g6 Equalization Entered
output logic [`CX_NL*`CX_RX_PSET_WD-1:0]  smlh_lec_g6_pset_lrx,   // g6 Latest Receiver Preset requested from Upstream Component (Not applicable to RC/SW_DW)
output logic                smlh_g6_tx_precoding_on,        // g6 Transmitter precoding on
output logic                smlh_retimer_pre_detected,      // Retimer was present during the latest Config.Complete
output logic                smlh_two_retimers_pre_detected, // Two Retimer were present during the latest Config.Complete
output logic [1:0]          smlh_crosslink_resolution,      // indicates the state of crosslink resolution (00b:not supported,01b:Upstream port,11b:not completed)
output logic                smlh_margin_ready,
output logic                smlh_mod_ts_rcvd,               // modified ts received
output logic [55:0]         mod_ts_data_rcvd,               // mod ts data rcvd
output logic [55:0]         mod_ts_data_sent,               // mod ts data transmitted


input                   pm_smlh_l1_2_latched,
input                   pm_smlh_l1_n_latched,
input   [7:0]           cfg_l1sub_t_common_mode,


output logic                     smlh_eq_pending,                // Equalization Pending
output logic                     smlh_usp_eq_pending,

output logic   [`CX_NL*`DIRFEEDBACK_WD-1:0]     phy_mac_dirfeedback,
output logic   [`CX_NL*`CX_FOMFEEDBACK_WD-1:0]  phy_mac_fomfeedback,
input  [(`CX_PHY_PDOWN_WD - 1) : 0] mac_phy_powerdown,
input   [`CX_NL-1:0]                phy_mac_phystatus,
input   [`CX_NL-1:0]                pipe_rx_clk,
input   [`CX_NL-1:0]                pipe_rx_rst_n,
    input   [(PIPE_DATA_WD - 1):0]      phy_mac_rxdata,
input   [`CX_NL-1:0]                phy_mac_rxvalid,
input   [(`CX_NL*3)-1:0]            phy_mac_rxstatus,
input   [`CX_NL-1:0]                phy_mac_rxstandbystatus,
input  [`CX_NL-1:0]                 mac_phy_txcompliance,
input  [`CX_PHY_WIDTH_WD-1:0]       mac_phy_width,
input  [`CX_PHY_RATE_WD-1:0]        mac_phy_rate,
input   [`CX_NL*8-1:0]              phy_mac_messagebus,

output logic   [6:0]                 esm_current_rate,
output ltssm_cxl_enable_t            ltssm_cxl_enable,
input                                cfg_drift_buffer_deskew_enable,
output logic                         cxl_link_enable,              // Indicates whether the link should operate in CXL or PCIe mode
output logic                         rplh_cxl_corr_pid_err,      // Correctable protocol ID error
output logic                         rplh_cxl_uncorr_pid_err,    // Uncorrectable protocol ID error
output logic                         rplh_cxl_unexp_pid_err,     // Unexpected protocol ID error
output logic [23:0]                  ltssm_cxl_mod_ts_phase1_rcvd,    // Received Modified TS Data Phase1
output logic                         ltssm_cxl_retimers_pre_mismatched,   // Set CXL_Retimers_Present_Mismatched bit
output logic                         ltssm_cxl_flexbus_phase2_mismatched, // Set FlexBusEnableBits_Phase2_Mismatch bit

output rplh_flit_logging_interface_struct rplh_cdm_flit_logging_interface,    // flit logging capability interface signals from RPLH          
output rmlh_flit_logging_interface_struct rmlh_cdm_flit_logging_interface,    // flit logging capability interface signals from RMLH  
output smlh_flit_logging_interface_struct smlh_cdm_flit_logging_interface,    // flit logging capability interface signals from SMLH  

input                                cfg_flit_err_inj_latency,
input  cfg_os_einj_ctrl_1_t          cfg_os_einj_ctrl_1,
input  cfg_os_einj_ctrl_2_t          cfg_os_einj_ctrl_2,
output cfg_os_einj_status_t          xmlh_tx_os_einj_status,
input  flit_err_inj_interface_struct cdm_plh_flit_err_inj_interface,   // Flit Error Injection Interface
output flit_err_inj_status_struct    plh_cdm_flit_err_inj_status,      // Flit Error Injection Status
  
input   [2:0]                         cdm_xplh_flit_response_type,
input   [1:0]                         cdm_xplh_flit_type_measured,
input                                 cdm_xplh_flit_track_mode,
output xplh_cdm_flit_latency_track_t  xplh_cdm_flit_latency_tracking,
output logic                          smlh_pm_state_trans1_flag,
output logic                          smlh_pm_state_trans2_flag,

input          [`CX_TX_FSLF_WD-1:0]      cfg_gen3_eq_fs_lf,            // programmable FS and LF for equalization
input          [(11*`CX_TX_COEF_WD)-1:0] cfg_gen3_eq_coef,             // programmable preset to coefficients mapping for equalization
input          [`CX_TX_FSLF_WD-1:0]      cfg_gen4_eq_fs_lf,            // programmable FS and LF for equalization
input          [(11*`CX_TX_COEF_WD)-1:0] cfg_gen4_eq_coef,             // programmable preset to coefficients mapping for equalization
input          [`CX_TX_FSLF_WD-1:0]      cfg_gen5_eq_fs_lf,            // programmable FS and LF for equalization
input          [(11*`CX_TX_COEF_WD)-1:0] cfg_gen5_eq_coef,             // programmable preset to coefficients mapping for equalization
input          [`CX_TX_FSLF_WD-1:0]      cfg_gen6_eq_fs_lf,            // programmable FS and LF for equalization
input          [(11*`CX_TX_COEF_WD)-1:0] cfg_gen6_eq_coef,             // programmable preset to coefficients mapping for equalization
output logic   [`CX_L2NL-1:0]        smlh_lane_flip_ctrl,
input                              pm_current_powerdown_p1,               // Indicate mac phy powerdown is in P1
input                              pm_current_powerdown_p0,               // Indicate mac phy powerdown is in P0
input [(`CX_PHY_PDOWN_WD - 1) : 0] pm_int_phy_powerdown,
input [`CX_L2NL - 1 : 0]           pm_rx_lane_flip_en,
input [`CX_L2NL - 1 : 0]           pm_tx_lane_flip_en,
input [`CX_L2NL - 1 : 0]           pm_rx_pol_lane_flip_ctrl,
input                              tx_lane_flip_en,
input                                  pm_hold_exit_l1,                       // PM Link connections with PM CTRL
input                                  pm_link_exit_l1,                       // PM Link connections with PM CTRL
input                                  cfg_pm_clk_pm_en,                      // PM Link connections with PM CTRL
input                                  cfg_pl_l1_nowait_p1,                   // PM Link connections with PM CTRL
output                                 pm_linkst_in_l0s,                      // PM Link connections with PM CTRL
input                                  pm_link_exit_l23,                      // Signals PM Link FSM to exit from L23RDY state
input                                  pm_pl_wake_ack,                        // PM Controller Wakeup Acknowledge
input                                  pm_pl_clk_req,                         // PM Controller Clock Request
input                                  pm_pl_phyinl1,                         // PM Controller PHY in L1
input                                  pm_pl_phyinl2,                         // PM Controller PHY in L2
output  usp_link_fsm_state_e           pm_usp_link_state,                     // PM Link connections with PM CTRL
output  dsp_link_fsm_state_e           pm_dsp_link_state,                     // PM Link connections with PM CTRL
output                                 pm_smlh_l1_exit,
output                                 pm_smlh_l23_exit,
input   pm_protocol_to_link_struct     pm_protocol_to_link_signals,           // PM Link connections with PM Protocol
output  pm_link_to_protocol_struct     pm_link_to_protocol_signals,           // PM Link connections with PM Protocol
input   [1:0]           cdm_ras_des_pm_entry_interval,         // Low Power Entry Interval Time for Ras D.E.S Silicon Debug
input   [1:0]           cdm_ras_des_eidle_cnt_sel,             // Number of Transmit E-IDLE ordered set for Ras D.E.S Silicon Debug
input                   cdm_ras_des_ltssm_stop,                // Level : Low Power Entry Interval Time for Ras D.E.S Silicon Debug
input                   cdm_ras_des_recovery_req,              // Level : Number of Transmit E-IDLE ordered set for Ras D.E.S Silicon Debug
input                   cdm_ras_des_ferr_rec_dis,              // Disable Recovery state transition at Framing Error for Ras D.E.S Silicon Debug
input                   cdm_ras_des_direct_rcvry_idle_to_cfg,  // Direct LTSSM from Recovery.Idle to Configuration for Ras D.E.S Silicon Debug
input                   cdm_ras_des_direct_poll_cmp_to_det,    // Direct LTSSM from Polling.Compliance to Detect for Ras D.E.S Silicon Debug
input                   cdm_ras_des_direct_lpbk_slave_to_exit, // Direct LTSSM from Loopback(Slave) to Exit for Ras D.E.S Silicon Debug
input                   cdm_ras_des_force_rxdetected_en,       // Force Detect Lane Num enable for Ras D.E.S Silicon Debug
input   [1:0]           cdm_ras_des_ext_eq_to_factor,          // Extend the eq 24/32ms timeout x2/x10
input                               cdm_ras_des_eq_fom_target_en,      // Figure of Merit target enable
input   [`CX_NL-1:0]                cdm_ras_des_eq_force_coef_rtx_en,  // Force Remote Tx Coefficient enable
input   [`CX_NL-1:0]                cdm_ras_des_eq_force_pset_lrx_en,  // Force Local Rx Preset Hint enable
input   [`CX_NL-1:0]                cdm_ras_des_eq_force_coef_ltx_en,  // Force Local Tx Coefficient enable
input   [`CX_NL*`CX_TX_COEF_WD-1:0] cdm_ras_des_eq_force_coef_ltx,     // Force Local Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
input   [`CX_NL*`CX_RX_PSET_WD-1:0] cdm_ras_des_eq_force_pset_lrx,        // Force Local Receiver Preset Hint for Ras D.E.S Silicon Debug EQ Control
input   [`CX_NL*`CX_TX_COEF_WD-1:0] cdm_ras_des_eq_force_coef_rtx,        // Force Remote Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
input   [`CX_NL-1:0]                cdm_ras_des_eq_force_pset_ltx_en,  // Force Local Tx Preset enable
input   [`CX_NL*`CX_TX_PSET_WD-1:0] cdm_ras_des_eq_force_usp_pset_ltx, // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control
input   [`CX_NL-1:0]                cdm_ras_des_eq_force_coef_rtx_en_g4, // Force Remote Tx Coefficient enable
input   [`CX_NL-1:0]                cdm_ras_des_eq_force_coef_ltx_en_g4, // Force Local Tx Coefficient enable
input   [`CX_NL*`CX_TX_COEF_WD-1:0] cdm_ras_des_eq_force_coef_ltx_g4,  // Force Local Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
input   [`CX_NL*`CX_TX_COEF_WD-1:0] cdm_ras_des_eq_force_coef_rtx_g4,  // Force Remote Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
input   [`CX_NL-1:0]                cdm_ras_des_eq_force_pset_ltx_en_g4, // Force Local Tx Preset enable
input   [`CX_NL*`CX_TX_PSET_WD-1:0] cdm_ras_des_eq_force_usp_pset_ltx_g4, // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control
input   [`CX_NL-1:0]                cdm_ras_des_eq_force_coef_rtx_en_g5, // Force Remote Tx Coefficient enable
input   [`CX_NL-1:0]                cdm_ras_des_eq_force_coef_ltx_en_g5, // Force Local Tx Coefficient enable
input   [`CX_NL*`CX_TX_COEF_WD-1:0] cdm_ras_des_eq_force_coef_ltx_g5,  // Force Local Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
input   [`CX_NL*`CX_TX_COEF_WD-1:0] cdm_ras_des_eq_force_coef_rtx_g5,  // Force Remote Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
input   [`CX_NL-1:0]                cdm_ras_des_eq_force_pset_ltx_en_g5, // Force Local Tx Preset enable
input   [`CX_NL*`CX_TX_PSET_WD-1:0] cdm_ras_des_eq_force_usp_pset_ltx_g5, // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control
input   [`CX_NL-1:0]                cdm_ras_des_eq_force_coef_rtx_en_g6, // Force Remote Tx Coefficient enable
input   [`CX_NL-1:0]                cdm_ras_des_eq_force_coef_ltx_en_g6, // Force Local Tx Coefficient enable
input   [`CX_NL*`CX_TX_COEF_WD-1:0] cdm_ras_des_eq_force_coef_ltx_g6,  // Force Local Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
input   [`CX_NL*`CX_TX_COEF_WD-1:0] cdm_ras_des_eq_force_coef_rtx_g6,  // Force Remote Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
input   [`CX_NL-1:0]                cdm_ras_des_eq_force_pset_ltx_en_g6, // Force Local Tx Preset enable
input   [`CX_NL*`CX_TX_PSET_WD-1:0] cdm_ras_des_eq_force_usp_pset_ltx_g6, // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control
input   [`CX_FOMFEEDBACK_WD-1:0]    cdm_ras_des_eq_fom_target,        // FOM Target value for Ras D.E.S Silicon Debug EQ Control
input   [1:0]                       cdm_ras_des_eq_eval_interval,          // EVAL Interval Time for Ras D.E.S Silicon Debug EQ Control
  
input                   cdm_ras_des_einj0_enable,              // Error injection 0 enable
input   [3:0]           cdm_ras_des_einj0_crc_type,            // Error injection 0 CRC type
input   [7:0]           cdm_ras_des_einj0_count,               // Error injection 0 count
input                   cdm_ras_des_einj3_enable,              // Error injection 3 8b/10b K-code mask enable
input   [7:0]           cdm_ras_des_einj3_count,               // Error injection 3 8b/10b K-code mask count
input   [2:0]           cdm_ras_des_einj3_smb_type,            // Error injection 3 8b/10b K-code mask type
output logic [`CX_NL-1:0]        rmlh_rpipe_rxoverflow,                 // Pulse: Rx elastic buffer overflow error status if the corresponding lane detected a lane-based error
output logic [`CX_NL-1:0]        rmlh_rpipe_rxunderflow,                // Pulse: Rx elastic buffer underflow error status if the corresponding lane detected a lane-based error
output logic [`CX_NL-1:0]        rmlh_rpipe_rxcodeerror,                // Pulse: Rx symbol error status if the corresponding lane detected a lane-based error
output logic [`CX_NL-1:0]        rmlh_rpipe_rxdisperror,                // Pulse: Rx running disparity error if the corresponding lane detected a lane-based error
output logic [`CX_NL-1:0]        rmlh_rpipe_rxskipadded,                // Pulse: Rx skip added in elastic buffer
output logic [`CX_NL-1:0]        rmlh_rpipe_rxskipremoved,              // Pulse: Rx skip removed in elastic buffer
output logic [`CX_NL-1:0]        rmlh_skp_parity_err,                   // Pulse: Rx skip ordered set parity error
output logic [`CX_NL-1:0]        rmlh_sync_header_err,                  // Pulse: Rx sync header undefined error
output logic                     rmlh_framing_err,                      // Pulse: Rx framing error in gen3 rate
output logic [6:0]               rmlh_framing_err_ptr,                  // Pulse: Rx framing error pointer in gen3 rate
output logic                     rmlh_framing_err_l0,                   // Pulse: Rx framing error in gen3 rate when L0 state
output logic                     rmlh_deskew_alignment_err,             // Level: Rx deskew alignment error
output logic [(`CX_NL*8)-1:0]    rmlh_deskew_fifo_ptr,                  // Pulse: Rx deskew pointer address
output logic [`CX_NL-1:0]        rmlh_rxvalid_deasserted,               // Pulse: Rx valid deasserted without EIOS
output logic                     smlh_eidle_inferred_in_l0,             // Level: Detect EI Infer
output logic                     smlh_rx_rcvry_req,                     // Level: Rx Recovery Request
output logic                     smlh_timeout_nfts,                     // Level: N_FTS Timeout
output logic                     smlh_l0_to_recovery,                   // Pulse: L0 to Recovery
output logic                     smlh_l1_to_recovery,                   // Pulse: L1 to Recovery
output logic                     smlh_rcv_eios_when_l0s_unsprt,         // pulse: Received EIOS when L0s is not supported and not directed L1 or L2 for Ras D.E.S event counter
output logic                     smlh_deskew_uncomplete_err,            // Pulse: Deskew uncompleted error
output logic                     smlh_spd_change,                       // Level: Speed Change
output logic [`CX_NL*8-1:0]      smseq_mcs_sts,                         // Level: Modified compliance ERR symbol for Ras D.E.S trace FIFO
output logic                     smlh_lwd_change,                // Level: Link Width Change
output logic [15:0]              smlh_ltssm_variable,            // Level: Ltssm specific parameters
output logic [`CX_NL*64-1:0]     smseq_ts_debug_info,            // Level: TS parameter for Ras D.E.S trace FIFO
output logic [`CX_NL*16-1:0]     smlh_rxos_type,                 // Level : Rx OS type/count
output logic [1:0]               int_ltssm_powerdown,            // Level: PIPE: Power Down for Ras D.E.S Silicon Debug
output logic [7:0]               latched_ts_nfts,                // Level: Latched NFTS for Ras D.E.S Silicon Debug
output logic                     init_eq_pending,                // Level : Equalization sequence for Ras D.E.S Silicon Debug
output logic [`CX_NL*`CX_TX_FS_WD-1:0]       mac_cdm_ras_des_fs,            // Level : Remote Device FS for Ras D.E.S Silicon Debug
output logic [`CX_NL*`CX_TX_FS_WD-1:0]       mac_cdm_ras_des_lf,            // Level : Remote Device LF for Ras D.E.S Silicon Debug
output logic [`CX_NL*`CX_TX_COEF_WD-1:0]     mac_cdm_ras_des_coef_ltx,      // Level : Current Local Transmitter coefficient for Ras D.E.S Silicon Debug
output logic [`CX_NL*`CX_FOMFEEDBACK_WD-1:0] phy_cdm_ras_des_fomfeedback,   // Level : Current Figure of Merit for Ras D.E.S Silicon Debug
output logic [`CX_NL*3-1:0]                  eqpa_violate_rule_123,         // Level : Rule A/B/C Violation Event Status for Ras D.E.S Silicon Debug
output logic [`CX_NL*2-1:0]                  eq_convergence_sts,            // Level : Equalization convergence information for Ras D.E.S Silicon Debug
output logic [`CX_NL*`CX_TX_COEF_WD-1:0]     mac_cdm_ras_des_coef_rtx,      // Level : Current Remote Transmitter coefficient for Ras D.E.S Silicon Debug
output logic [`CX_NL*`CX_RX_PSET_WD-1:0]     mac_cdm_ras_des_pset_lrx,      // Level : Current Local Receiver Preset for Ras D.E.S Silicon Debug
output logic [`CX_NL-1:0]                    mac_cdm_ras_des_reject_rtx,    // Level : Receive Reject Coefficient Event status for Ras D.E.S Silicon Debug
output logic                                 init_eq_pending_g4,            // Level : Equalization sequence  for Ras D.E.S Silicon Debug
output logic [`CX_NL*`CX_TX_FS_WD-1:0]       mac_cdm_ras_des_fs_g4,         // Level : Remote Device FS for Ras D.E.S Silicon Debug
output logic [`CX_NL*`CX_TX_FS_WD-1:0]       mac_cdm_ras_des_lf_g4,         // Level : Remote Device LF for Ras D.E.S Silicon Debug
output logic [`CX_NL*`CX_TX_COEF_WD-1:0]     mac_cdm_ras_des_coef_ltx_g4,   // Level : Current Local Transmitter coefficient for Ras D.E.S Silicon Debug
output logic [`CX_NL*`CX_FOMFEEDBACK_WD-1:0] phy_cdm_ras_des_fomfeedback_g4,// Level : Current Figure of Merit for Ras D.E.S Silicon Debug
output logic [`CX_NL*3-1:0]                  eqpa_violate_rule_123_g4,      // Level : Rule A/B/C Violation Event Status for Ras D.E.S Silicon Debug
output logic [`CX_NL*2-1:0]                  eq_convergence_sts_g4,         // Level : Equalization convergence information for Ras D.E.S Silicon Debug
output logic [`CX_NL*`CX_TX_COEF_WD-1:0]     mac_cdm_ras_des_coef_rtx_g4,   // Level : Current Remote Transmitter coefficient for Ras D.E.S Silicon Debug
output logic [`CX_NL-1:0]                    mac_cdm_ras_des_reject_rtx_g4, // Level : Receive Reject Coefficient Event status for Ras D.E.S Silicon Debug
output logic                                 init_eq_pending_g5,            // Level : Equalization sequence  for Ras D.E.S Silicon Debug
output logic [`CX_NL*`CX_TX_FS_WD-1:0]       mac_cdm_ras_des_fs_g5,         // Level : Remote Device FS for Ras D.E.S Silicon Debug
output logic [`CX_NL*`CX_TX_FS_WD-1:0]       mac_cdm_ras_des_lf_g5,         // Level : Remote Device LF for Ras D.E.S Silicon Debug
output logic [`CX_NL*`CX_TX_COEF_WD-1:0]     mac_cdm_ras_des_coef_ltx_g5,   // Level : Current Local Transmitter coefficient for Ras D.E.S Silicon Debug
output logic [`CX_NL*`CX_FOMFEEDBACK_WD-1:0] phy_cdm_ras_des_fomfeedback_g5,// Level : Current Figure of Merit for Ras D.E.S Silicon Debug
output logic [`CX_NL*3-1:0]                  eqpa_violate_rule_123_g5,      // Level : Rule A/B/C Violation Event Status for Ras D.E.S Silicon Debug
output logic [`CX_NL*2-1:0]                  eq_convergence_sts_g5,         // Level : Equalization convergence information for Ras D.E.S Silicon Debug
output logic [`CX_NL*`CX_TX_COEF_WD-1:0]     mac_cdm_ras_des_coef_rtx_g5,   // Level : Current Remote Transmitter coefficient for Ras D.E.S Silicon Debug
output logic [`CX_NL-1:0]                    mac_cdm_ras_des_reject_rtx_g5, // Level : Receive Reject Coefficient Event status for Ras D.E.S Silicon Debug
output logic                                 init_eq_pending_g6,            // Level : Equalization sequence  for Ras D.E.S Silicon Debug
output logic [`CX_NL*`CX_TX_FS_WD-1:0]       mac_cdm_ras_des_fs_g6,         // Level : Remote Device FS for Ras D.E.S Silicon Debug
output logic [`CX_NL*`CX_TX_FS_WD-1:0]       mac_cdm_ras_des_lf_g6,         // Level : Remote Device LF for Ras D.E.S Silicon Debug
output logic [`CX_NL*`CX_TX_COEF_WD-1:0]     mac_cdm_ras_des_coef_ltx_g6,   // Level : Current Local Transmitter coefficient for Ras D.E.S Silicon Debug
output logic [`CX_NL*`CX_FOMFEEDBACK_WD-1:0] phy_cdm_ras_des_fomfeedback_g6,// Level : Current Figure of Merit for Ras D.E.S Silicon Debug
output logic [`CX_NL*3-1:0]                  eqpa_violate_rule_123_g6,      // Level : Rule A/B/C Violation Event Status for Ras D.E.S Silicon Debug
output logic [`CX_NL-1:0]                    eqpa_violate_rule_4_g6,        // Level : Rule D Violation Event Status for Ras D.E.S Silicon Debug
output logic [`CX_NL*2-1:0]                  eq_convergence_sts_g6,         // Level : Equalization convergence information for Ras D.E.S Silicon Debug
output logic [`CX_NL*`CX_TX_COEF_WD-1:0]     mac_cdm_ras_des_coef_rtx_g6,   // Level : Current Remote Transmitter coefficient for Ras D.E.S Silicon Debug
output logic [`CX_NL-1:0]                    mac_cdm_ras_des_reject_rtx_g6, // Level : Receive Reject Coefficient Event status for Ras D.E.S Silicon Debug
output logic [1:0]           rl0s_state,                     // Level : RxL0s state
output logic [`CX_NL-1:0]    latched_rxdetected,             // Level : PIPE: Detect Lane for Ras D.E.S Silicon Debug
output logic [`CX_NL-1:0]    rpipe_rxelecidle,               // RMLH pipe module output to SMLH
output logic                 xmlh_einj0_oscrc_evt,           // Error injection 0 CRC error event
output logic [1:0]           xmlh_einj3_osmsk_evt,           // Error injection 3 8b/10b K-code mask event
input                        rtlh_req_link_retrain,          // Puls : FC Timeout Event per TLP for Ras D.E.S event counter
output ras_dp_err_log_t      xplh_ras_dp_err_log,
input  ras_dp_err_inj_t      ras_dp_err_inj,
output logic                             smlh_ltssm_in_l0p,                   // Level: L0p

input                                    pm_aux_clk,
input [1:0]                              pm_en_pulse_det,
input [`CX_NL-1:0]                       sqlchd_rxelecidle,
output logic [1:0]                       pipe_aux_sync_p1_ack,
output logic [1:0]                       pipe_aux_sync_block,

output logic                             mac_phy_cfg_cxl_port_drift_buffer_enabled,
output logic                             mac_phy_ltssm_link_synchdr_bypass_enabled,
output logic [`CX_NL-1:0]                serdes_pipe_turnoff_lanes,
output logic [(`CX_PHY_PDOWN_WD - 1) :0] pre_mac_phy_powerdown,
output logic [`CX_NL*`CX_PHY_TXEI_WD-1:0]int_mac_phy_txelecidle,
output logic [(PIPE_DATA_WD - 1):0]      pre_mac_phy_txdata,
output logic [`CX_NL-1:0]                pre_mac_phy_txdetectrx_loopback,
output logic [`CX_NL-1:0]                glue_mac_phy_txcompliance,
output logic [`CX_NL-1:0]                pre_mac_phy_rxpolarity,
output logic [`CX_NL-1:0]                tmp_mac_phy_rxpolarity,
output logic [2:0]                       tmp_int_mac_phy_rate,
output logic                             tmp_mac_phy_txdeemph_0,
output logic [(`CX_PHY_WIDTH_WD -1):0]   pre_mac_phy_width,
output logic                             pre_mac_phy_serdes_arch,
output logic [(`CX_PHY_WIDTH_WD -1):0]   pre_mac_phy_rxwidth,
output logic [`CX_NL-1:0]                pre_serdes_pipe_rxready,
output logic [`PCLK_RATE_WD-1:0]         pre_mac_phy_pclk_rate,
output logic [`CX_NL-1:0]                pre_mac_phy_rxstandby,
output logic [`CX_PHY_RATE_WD-1:0]       pre_mac_phy_rate,
output logic [`CX_PHY_TXDEEMPH_WD-1:0]   pre_mac_phy_txdeemph,
output logic [`CX_NL-1:0]                pre_mac_phy_txdatavalid,

output logic [`CX_NL-1:0]                pre_mac_phy_rxeqeval,
output logic [`CX_NL-1:0]                pre_mac_phy_dirchange,
output logic [`CX_NL*`CX_TX_COEF_WD-1:0] pre_mac_phy_smlh_coef_rtx,
output logic [`CX_BAC_WD-1:0]            pre_mac_phy_blockaligncontrol_o,

output logic [`CX_NL*8-1:0]              pre_mac_phy_mbus,
input                                cfg_pipe_loopback,
input    [5:0]                       cfg_rxstatus_lane,         // Lane to inject rxstatus value(bit6 = all lanes)
input    [2:0]                       cfg_rxstatus_value,        // rxstatus value to inject
input    [`CX_NL-1:0]                cfg_lpbk_rxvalid,          // rxvalid value to use during loopback
input    [`CX_NL*`CX_TX_PSET_WD-1:0]   int_cfg_lec_pset_ltx,
input    [`CX_NL*`CX_RX_PSET_WD-1:0]   int_cfg_lec_pset_lrx,
input    [`CX_NL*`CX_TX_PSET_WD-1:0]   int_cfg_lec_pset_rtx,
input    [`CX_NL*`CX_RX_PSET_WD-1:0]   int_cfg_lec_pset_rrx,
input    [`CX_NL*`CX_TX_PSET_WD-1:0]   int_cfg_lec_g4_pset_ltx,
input    [`CX_NL*`CX_TX_PSET_WD-1:0]   int_cfg_lec_g4_pset_rtx,
input    [`CX_NL*`CX_TX_PSET_WD-1:0]   int_cfg_lec_g5_pset_ltx,
input    [`CX_NL*`CX_TX_PSET_WD-1:0]   int_cfg_lec_g5_pset_rtx,
input    [`CX_NL*`CX_TX_PSET_WD-1:0]   int_cfg_lec_g6_pset_ltx,
input    [`CX_NL*`CX_TX_PSET_WD-1:0]   int_cfg_lec_g6_pset_rtx,
input  [`CX_NL*16-1:0]                 int_cfg_margin_control,
input   [`CX_NL-1:0]                   int_cdm_ras_des_force_rxdetected,        // Level : Force Detect Lane Num for Ras D.E.S Silicon Debug
output logic [`CX_NL-1:0]                  int_smlh_margin_status_valid,
output logic [`CX_NL*16-1:0]               int_smlh_margin_status,
output logic [`CX_NL*5-1:0]                int_rmlh_deskew_ctlskp_err,
output logic [`CX_NL-1:0]                  int_rmlh_lane_err,
output logic [`CX_NL*`CX_TX_PSET_WD-1:0]   int_smlh_lec_pset_ltx,
output logic [`CX_NL*`CX_RX_PSET_WD-1:0]   int_smlh_lec_pset_lrx,
output logic [`CX_NL*`CX_TX_PSET_WD-1:0]   int_smlh_lec_g4_pset_ltx,
output logic [`CX_NL*`CX_TX_PSET_WD-1:0]   int_smlh_lec_g5_pset_ltx,
output logic [`CX_NL*`CX_TX_PSET_WD-1:0]   int_smlh_lec_g6_pset_ltx,
output logic    [(`CX_NL*ORIG_DATA_WD)-1:0]     orig_pipe_rxdata,
output logic    [(`CX_NL*`CX_PHY_NB)-1:0]       orig_pipe_rxdatak,
output logic    [`CX_NL-1:0]                    orig_pipe_rxvalid,
output logic    [`CX_NL-1:0]                    orig_pipe_rxdatavalid,
output logic    [(`CX_NL*3)-1:0]                orig_pipe_rxstatus,
output logic    [(`CX_NL*`CX_PHY_RXSB_WD)-1:0]  orig_pipe_rxstartblock,
output logic    [(`CX_NL*`CX_PHY_RXSH_WD)-1:0]  orig_pipe_rxsyncheader,
output logic [`CX_NL-1:0]                       phy_mac_phystatus_int,
output  logic                    smlh_link_in_training,  // Level: Ltssm is in Config or Recovery
output  logic                    rmlh_prbs_done,         // Finished PBRS Loopback
output  logic                    rmlh_prbs_fail,         // PRBS Comparison error occurred
output  logic [`CX_NL-1:0]       rmlh_prbs_started,      // PRBS started status
output  logic [`CX_NL-1:0][7:0]  rmlh_prbs_err_cntr,     // PRBS comparison error counter
output  logic [`CX_NL-1:0]       rmlh_prbs_unexp_fail,   // PRBS unexpeced error occurred
input               cfg_prbs_en,                  // PRBS Loopback Enable. Need to be set before being set cfg_lpbk_en
input               clear_prbs_done,              // Clear PRBS Status regisers
input       [3:0]   cfg_prbs_lane_sel             // PRBS lane select for status registers
);

localparam N_DELAY_GEN5_FPGA        = 0;
localparam EQTS_WD        = 32;                       // Number of bits of Per Lane Equalization Information
localparam   TS_0_WD      = 48;
localparam   DW_WO_PAR    = (32*`CX_NW);                        // Width of datapath in bits.
localparam   OS_WD        = `CX_MAC_SB_WD; // Number of OS width
localparam   NW_NFM       = (`CX_NW > 16) ? 16 : `CX_NW;            // Number of 32-bit dwords handled by the datapath each clock in Non-Flit Mode.
localparam   DCB_WD       = (`CX_NB>=8 ? `CX_NB/8 : 1);             // Number of bits of per rxdata_dcb
localparam CTL_WD = (`CX_NW >= 16) ? 16 : `CX_XTLH_XDLH_CTL_WD; // (`CX_NW == 2)? 1 : @CX_NW

genvar lane;  // used to instantiate per-lane logic

// Interface Declarations
  tx_lp_if b_xplh_xmlh();                   // XPLH -> XMLH Transmit Interface

// ======================================================================================
// ======================================================================================
logic                    xmlh_sris_mode_enabled;         // SRIS_Mode_Enabled variable
logic  xplh_req_link_down;
wire                          ltssm_all_detect_quiet;
logic   [`CX_L2NL-1:0]        ltssm_lane_flip_ctrl;
logic                         rmlh_rcvd_eidle_set;            // An EIDLE SET has been received.
logic ltssm_cfg_to_lpbk_active_master_g6;

logic [(`CX_NL*8)-1:0]      drift_buffer_deskew_ptr;

wire [`CX_NL*`CX_TX_COEF_WD-1:0]     phy_mac_local_tx_pset_coef;
wire [`CX_NL*`CX_TX_FS_WD-1:0]       phy_mac_localfs;
wire [`CX_NL*`CX_TX_FS_WD-1:0]       phy_mac_locallf;
wire [`CX_NL-1:0]                    phy_mac_local_tx_coef_valid;
wire                              lut_en;                         // lut enable
wire    [5:0]                     lut_ctrl;                       // {cfg_force_lane_flip, lut_en, lut}
wire                              cfg_force_lane_flip, cfg_lpbk_slave_tx_g5_mod_cmpl_ptrn, cfg_do_g5_lpbk_eq, cfg_mod_ts;
wire    [3:0]                     cfg_lane_under_test;

wire   [(`CX_NL*`CX_NB*8)-1:0] in_cxpl_phy_mac_rxdata;
wire   [(`CX_NL*`CX_NB)-1:0]   in_cxpl_phy_mac_rxdatak;
wire   [`CX_NL-1:0]            in_cxpl_phy_mac_rxvalid;
wire   [(`CX_NL*3)-1:0]        in_cxpl_phy_mac_rxstatus;
wire   [`CX_NL-1:0]            in_cxpl_phy_mac_rxelecidle;
wire   [`CX_NL-1:0]            in_cxpl_phy_mac_phystatus;

wire   [`CX_NL-1:0]            tmp_phy_mac_margin_status;
wire   [`CX_NL*6-1:0]          tmp_phy_mac_margin_error_cnt;
wire   [`CX_NL*7-1:0]          tmp_phy_mac_margin_sampl_cnt;
wire  [`CX_NL-1:0]                      phy_mac_margin_status;
wire  [`CX_NL-1:0]                      phy_mac_margin_nak;
wire  [`CX_NL*6-1:0]                    phy_mac_margin_error_cnt;
wire  [`CX_NL*7-1:0]                    phy_mac_margin_sampl_cnt;
wire [`CX_NL-1:0]       laneflip_lanes_active;
wire [`CX_NL-1:0]       laneflip_set_rxstandby;
wire [`CX_NL-1:0]       laneflip_mac_phy_rxstandby;
wire [`CX_NL*`CX_MAC_SB_WD-1:0]      tmp_phy_mac_rxstartblock;
wire [`CX_NL*`CX_MAC_SH_WD-1:0]      tmp_phy_mac_rxsyncheader;
wire [`CX_NL*`CX_TX_PSET_WD-1:0]     tmp_cfg_lec_pset_ltx;
wire [`CX_NL*`CX_RX_PSET_WD-1:0]     tmp_cfg_lec_pset_lrx;
wire [`CX_NL*`CX_TX_PSET_WD-1:0]     tmp_cfg_lec_pset_rtx;
wire [`CX_NL*`CX_RX_PSET_WD-1:0]     tmp_cfg_lec_pset_rrx;
wire [`CX_NL-1:0][`CX_PHY_TXSB_WD-1:0][4:0] tmp_txdata_osfound;
wire [`CX_NL-1:0][`CX_PHY_TXSB_WD-1:0][4:0] txdata_osfound;
wire [`CX_NL-1:0][`CX_MAC_SB_WD-1:0][4:0]   int_rxdata_osfound;
wire [`CX_NL-1:0][`CX_MAC_SB_WD-1:0][4:0]   tmp_rxdata_osfound;

wire  [`CX_NL*`CX_TX_FS_WD-1:0]        tmp_phy_mac_fs;
wire  [`CX_NL*`CX_TX_FS_WD-1:0]        tmp_phy_mac_lf;
wire  [`CX_NL*`DIRFEEDBACK_WD-1:0]     tmp_phy_mac_dirfeedback;
wire  [`CX_NL*`CX_FOMFEEDBACK_WD-1:0]  tmp_phy_mac_fomfeedback;
wire  [`CX_NL*`CX_TX_COEF_WD-1:0]      tmp_phy_mac_local_tx_pset_coef;
wire  [`CX_NL-1:0]                     tmp_phy_mac_local_tx_coef_valid;


// lane_flip
wire [`CX_NL-1:0]                 int_phy_mac_rxstandbystatus;
wire [(`CX_NL*`CX_NB*8)-1:0]      int_phy_mac_rxdata;
wire [`CX_NL*`CX_NB-1 :0]         int_phy_mac_rxdatak;
wire [`CX_NL-1:0]                 int_phy_mac_rxdatavalid;
wire [`CX_NL-1:0]                 tmp_phy_mac_rxstandbystatus;
wire [(`CX_NL*`CX_NB*8)-1:0]      tmp_phy_mac_rxdata;
wire [`CX_NL*`CX_NB-1 :0]         tmp_phy_mac_rxdatak;
wire [`CX_NL-1:0]                 tmp_phy_mac_rxdatavalid;
wire [(`CX_NL*`CX_MAC_SB_WD)-1:0] int_phy_mac_rxstartblock;
wire [(`CX_NL*`CX_MAC_SH_WD)-1:0] int_phy_mac_rxsyncheader;
wire [`CX_NL-1:0][`CX_PHY_TXSB_WD-1:0][4:0] int_txdata_osfound;
wire [`CX_NL*`CX_TX_FS_WD-1:0]        int_phy_mac_fs;
wire [`CX_NL*`CX_TX_FS_WD-1:0]        int_phy_mac_lf;
wire [`CX_NL*`DIRFEEDBACK_WD-1:0]     int_phy_mac_dirfeedback;
wire [`CX_NL*`CX_FOMFEEDBACK_WD-1:0]  int_phy_mac_fomfeedback;
wire [`CX_NL*`CX_TX_COEF_WD-1:0]      int_phy_mac_local_tx_pset_coef;
wire [`CX_NL-1:0]                     int_phy_mac_local_tx_coef_valid;
wire  [`CX_NL-1:0]                    int_phy_mac_margin_status;
wire  [`CX_NL-1:0]                    int_phy_mac_margin_nak;
wire  [`CX_NL-1:0]                    tmp_phy_mac_margin_nak;
wire  [`CX_NL*6-1:0]                  int_phy_mac_margin_error_cnt;
wire  [`CX_NL*7-1:0]                  int_phy_mac_margin_sampl_cnt;
wire    [`CX_NL-1:0]                  int_phy_mac_rxvalid;
wire    [`CX_NL-1:0]                  int_phy_mac_rxelecidle;
wire    [(`CX_NL*3)-1:0]              int_phy_mac_rxstatus;           // Encoders receiver status and error codes for the received
wire    [`CX_NL-1:0]                  int_phy_mac_phystatus;          // Used to communicate completion of several PHY functions
wire    [`CX_NL-1:0]                  tmp_phy_mac_rxvalid;
wire    [`CX_NL-1:0]                  tmp_phy_mac_rxelecidle;
wire    [(`CX_NL*3)-1:0]              tmp_phy_mac_rxstatus;           // Encoders receiver status and error codes for the received
wire    [`CX_NL-1:0]                  tmp_phy_mac_phystatus;          // Used to communicate completion of several PHY functions
wire    [`CX_NL-1:0]                  tmp_cdm_ras_des_force_rxdetected;         // Level : Force Detect Lane Num for Ras D.E.S Silicon Debug
wire    [`CX_NL*`CX_TX_PSET_WD-1:0]   tmp_cfg_lec_g4_pset_ltx;
wire    [`CX_NL*`CX_TX_PSET_WD-1:0]   tmp_cfg_lec_g4_pset_rtx;
wire    [`CX_NL*`CX_TX_PSET_WD-1:0]   tmp_cfg_lec_g5_pset_ltx;
wire    [`CX_NL*`CX_TX_PSET_WD-1:0]   tmp_cfg_lec_g5_pset_rtx;
wire    [`CX_NL*`CX_TX_PSET_WD-1:0]   tmp_cfg_lec_g6_pset_ltx;
wire    [`CX_NL*`CX_TX_PSET_WD-1:0]   tmp_cfg_lec_g6_pset_rtx;
wire  [`CX_NL*16-1:0]                 tmp_cfg_margin_control;
wire    [`CX_NL-1:0]                  int_os_corrected;
wire    [`CX_NL-1:0]                  int_pam4_restricted_levels_wr_ack_pending;
wire    [`CX_NL-1:0]                  tmp_os_corrected;
wire    [`CX_NL-1:0]                  tmp_pam4_restricted_levels_wr_ack_pending;
wire    [`CX_NL-1:0]                  laneflip_no_turnoff_lanes;


wire    [`CX_NL-1:0]                  tmp_mac_phy_rxstandby;
wire [1:0]                            tmp_xmlh_powerdown;
wire    [`CX_NL-1:0]                  int_mac_phy_rxstandby;
wire [1:0]                            int_xmlh_powerdown;
logic [1:0]                           ltssm_powerdown;
logic [1:0]                           tmp_ltssm_powerdown;
assign tmp_ltssm_powerdown            = ltssm_powerdown;
wire    [1:0]                         tmp_mac_phy_txdeemph;           // selects transmitter de-emphasis in the PHY
assign tmp_mac_phy_txdeemph_0 = tmp_mac_phy_txdeemph[0];
wire    [2:0]                         tmp_mac_phy_txmargin;           // selects transmitter voltage levels in the PHY
wire                                  tmp_mac_phy_txswing;            // selects transmitter voltage swing level in the PHY
wire    [1:0]                         int_mac_phy_txdeemph;           // selects transmitter de-emphasis in the PHY
wire    [2:0]                         int_mac_phy_txmargin;           // selects transmitter voltage levels in the PHY
wire                                  int_mac_phy_txswing;            // selects transmitter voltage swing level in the PHY
wire    [`CX_NL*2-1:0]                mac_phy_txdeemph_bus;           // selects transmitter de-emphasis in the PHY
wire    [`CX_NL*3-1:0]                mac_phy_txmargin_bus;           // selects transmitter voltage levels in the PHY
wire    [`CX_NL-1:0]                  mac_phy_txswing_bus;            // selects transmitter voltage swing level in the PHY
wire                                  tmp_mac_phy_pam4_restricted_levels; // The MAC to inform the PHY that the link partner is transmitting or that it will soon be transmitting TS0 at 64 GT/s.
wire                                  int_mac_phy_pam4_restricted_levels; // The MAC to inform the PHY that the link partner is transmitting or that it will soon be transmitting TS0 at 64 GT/s.
wire    [`CX_NL-1:0]                  mac_phy_pam4_restricted_levels_bus; // The MAC to inform the PHY that the link partner is transmitting or that it will soon be transmitting TS0 at 64 GT/s.
wire    [(`CX_NL*`CX_NB*8)-1:0]       tmp_mac_phy_txdata;
wire    [(`CX_NL*`CX_NB)-1:0]         tmp_mac_phy_txdatak;
wire [2:0]                            int_mac_phy_rate;
wire    [(`CX_NL*`CX_NB*8)-1:0]       int_mac_phy_txdata;
wire    [(`CX_NL*`CX_NB)-1:0]         int_mac_phy_txdatak;
wire    [`CX_NL-1:0]                  tmp_mac_phy_txdatavalid;
wire    [(`CX_NL*`CX_PHY_TXSB_WD)-1:0]tmp_mac_phy_txstartblock;
wire    [(`CX_NL*`CX_PHY_TXSH_WD)-1:0]tmp_mac_phy_txsyncheader;
wire    [`CX_NL-1:0]                  int_mac_phy_txdatavalid;
wire    [(`CX_NL*`CX_PHY_TXSB_WD)-1:0]int_mac_phy_txstartblock;
wire    [(`CX_NL*`CX_PHY_TXSH_WD)-1:0]int_mac_phy_txsyncheader;
wire [`CX_NL*`CX_RX_PSET_WD-1:0]      tmp_mac_phy_rxpresethint;
wire [`CX_NL*`CX_TX_FS_WD-1:0]        tmp_mac_phy_fs;
wire [`CX_NL*`CX_TX_FS_WD-1:0]        tmp_mac_phy_lf;
wire [`CX_NL-1:0]                     tmp_mac_phy_rxeqinprogress;
wire [`CX_NL-1:0]                     tmp_mac_phy_invalid_req;
wire [`CX_NL-1:0]                     tmp_mac_phy_rxeqeval;
wire [`CX_NL-1:0]                     tmp_mac_phy_dirchange;
wire [`CX_PHY_TXDEEMPH_WD-1:0]        tmp_smlh_eqpa_txdeemph;         // local coefficients from eqpa block
wire [`CX_NL*`PSET_ID_WD-1:0]         tmp_mac_phy_local_pset_index;
wire [`CX_NL*`CX_TX_COEF_WD-1:0]      tmp_mac_phy_smlh_coef_rtx;
wire [`CX_NL-1:0]                     tmp_mac_phy_getlocal_pset_coef;
wire [`CX_NL*`CX_RX_PSET_WD-1:0]      int_mac_phy_rxpresethint;
wire [`CX_NL*`CX_TX_FS_WD-1:0]        int_mac_phy_fs;
wire [`CX_NL*`CX_TX_FS_WD-1:0]        int_mac_phy_lf;
wire [`CX_NL-1:0]                     int_mac_phy_rxeqinprogress;
wire [`CX_NL-1:0]                     int_mac_phy_invalid_req;
wire [`CX_NL-1:0]                     int_mac_phy_rxeqeval;
wire [`CX_NL-1:0]                     int_mac_phy_dirchange;
wire [`CX_PHY_TXDEEMPH_WD-1:0]        int_smlh_eqpa_txdeemph;         // local coefficients from eqpa block
wire [`CX_PHY_TXDEEMPH_WD-1:0]        int_smlh_eqpa_txdeemph_i;       // local coefficients from eqpa block
wire [`CX_NL*`PSET_ID_WD-1:0]         int_mac_phy_local_pset_index;
wire [`CX_NL*`CX_TX_COEF_WD-1:0]      int_mac_phy_smlh_coef_rtx;
wire [`CX_NL-1:0]                     int_mac_phy_getlocal_pset_coef;
wire [`CX_PHY_TXDEEMPH_WD-1:0]        smlh_eqpa_txdeemph;             // local coefficients from eqpa block
wire    [`CX_NL-1:0]                  tmp_rmlh_lane_err;
wire    [`CX_NL*`CX_TX_PSET_WD-1:0]   tmp_smlh_lec_pset_ltx;
wire    [`CX_NL*`CX_RX_PSET_WD-1:0]   tmp_smlh_lec_pset_lrx;
wire    [`CX_NL*`CX_TX_PSET_WD-1:0]   tmp_smlh_lec_g4_pset_ltx;
wire    [`CX_NL*`CX_TX_PSET_WD-1:0]   tmp_smlh_lec_g5_pset_ltx;
wire    [`CX_NL*`CX_TX_PSET_WD-1:0]   tmp_smlh_lec_g6_pset_ltx;
wire  [`CX_NL*3-1:0]                  tmp_mac_phy_margin_cmd;
wire  [`CX_NL*7-1:0]                  tmp_mac_phy_margin_offset;
wire  [`CX_NL*2-1:0]                  tmp_mac_phy_margin_clr_error_log;
wire  [`CX_NL-1:0]                    tmp_smlh_margin_status_valid;
wire  [`CX_NL*16-1:0]                 tmp_smlh_margin_status;
wire  [`CX_NL*5-1:0]                  tmp_rmlh_deskew_ctlskp_err;
wire  [`CX_NL*3-1:0]                  int_mac_phy_margin_cmd;
wire  [`CX_NL*7-1:0]                  int_mac_phy_margin_offset;
wire  [`CX_NL*2-1:0]                  int_mac_phy_margin_clr_error_log;
wire    [`CX_NL-1:0]                  tmp_mac_phy_txdetectrx_loopback;// Enable receiver detection sequence.  SerDes transmits
wire    [`CX_NL-1:0]                  tmp_ltssm_txelecidle;
wire    [`CX_NL-1:0]                  tmp_mac_phy_txcompliance;
wire    [`CX_NL-1:0]                  int_mac_phy_txdetectrx_loopback;// Enable receiver detection sequence.  SerDes transmits
logic   [`CX_NL-1:0]                  int_ltssm_txelecidle;
logic   [`CX_NL-1:0]                  int_ltssm_txelecidle_i;
logic   [`CX_NL-1:0]                  int_mac_phy_txcompliance;
wire    [`CX_NL-1:0]                  int_mac_phy_rxpolarity;

wire    [`CX_BAC_WD-1:0]                smlh_blockaligncontrol;         // Tell phy don't do block alignment while in L0 or LPBK_ACTIVE for slave
wire    [`CX_NL-1:0]                    smlh_blockaligncontrol_bus;     // Tell phy don't do block alignment while in L0 or LPBK_ACTIVE for slave
wire    [`CX_BAC_WD-1:0]                int_smlh_blockaligncontrol;

wire    [`CX_NL-1:0]                  smlh_lanes_active;              // active lanes
wire    [`CX_NL-1:0]                  deskew_lanes_active;            // Which lanes are actively configured (or being configured). It is used for Drift buffer deskew in SerDes module
wire    [`CX_NL-1:0]                  laneflip_deskew_lanes_active;
wire    [`CX_NL-1:0]                  smlh_set_rxstandby;

wire    [`CX_NL-1:0]                  int_mac_phy_txcompliance_i;
reg     [`CX_NL-1:0]                  int_mac_phy_txcompliance_r;


// pipe_adapter
wire    [2:0]                         tmp_mac_phy_rate;               // 1=change speed to gen2, 2-gen3, 0-gen1, internal use
wire    [`CX_NL*3-1:0]                tmp_mac_phy_rate_bus;           // 1=change speed to gen2, 2-gen3, 0-gen1, internal use

wire [`CX_NL-1:0]          core_int_pipe_smlh_blockaligncontrol;
wire [1:0]                 core_int_mac_phy_txdeemph;
wire [`CX_NL-1:0]          mac_phy_txdatavalid_i;
wire [`CX_NL-1:0]          mac_phy_pipe_txdatavalid_i;

wire [`CX_NL-1:0]                 adapted_pipe_phy_mac_rxdatavalid;
wire [`CX_NL-1:0]                 adapted_pipe_mac_phy_txdatavalid;
wire [`CX_PHY_TXDEEMPH_WD-1:0]    adapted_pipe_mac_phy_txdeemph;
wire [`CX_BAC_WD-1:0]             adapted_pipe_mac_phy_blockaligncontrol;
wire                              adapted_pipe_mac_phy_encodedecodebypass;
wire [(`CX_PHY_PDOWN_WD - 1) : 0] adapted_pipe_mac_phy_powerdown;
wire    [`CX_PHY_WIDTH_WD-1:0]    adapted_pipe_mac_phy_width;
wire                              adapted_pipe_mac_phy_serdes_arch;
wire    [`CX_PHY_WIDTH_WD-1:0]    adapted_pipe_mac_phy_rxwidth;
wire    [`PCLK_RATE_WD-1:0]       adapted_pipe_mac_phy_pclk_rate;
wire    [2:0]                     adapted_pipe_mac_phy_cclk_rate;
wire    [2:0]                     current_cclk_rate;


// serdes_pipe
  wire    [`CX_NL-1:0]                    ltssm_l0p_lanes_active;         // LTSSM latched lanes that are active based on the link negotiation

  wire [`CX_NL*3-1:0] phy_mac_rxstatus_int;
  assign phy_mac_phystatus_int   = phy_mac_phystatus;
  assign phy_mac_rxstatus_int    = phy_mac_rxstatus;
  
wire    [(`CX_NL*`CX_PHY_NB*8)-1:0]         fstep_mac_phy_txdata;
wire    [`CX_NL-1:0]                        fstep_mac_phy_txelecidle;
wire    [`CX_NL-1:0]                        fstep_mac_phy_txdetectrx_loopback;
wire    [`CX_NL-1:0]                    serdes_pipe_txdatavalid;
logic [`CX_NL-1:0][`CX_PHY_RXSB_WD-1:0][4:0] orig_pipe_rxdata_osfound; // {SDS,EIEOS,EIOS,SKP END,SKP} 
wire    [`CX_NL-1:0]                    orig_pipe_os_corrected;  // EIOS, EIEOS, SDS, SKP
wire    [PIPE_DATA_WD-1:0]              serdes_pipe_txdata;
wire    [(`CX_NL*`CX_PHY_TXEI_WD)-1:0]  serdes_pipe_txelecidle;
wire    [`CX_NL-1:0]                    serdes_pipe_txdetectrx_loopback;

// pipe_test_mux


// pipe_loopback
logic [8*`CX_PHY_NB*`CX_NL-1:0]     lpbk_rxdata;
logic [`CX_PHY_NB*`CX_NL-1:0]       lpbk_rxdatak;
logic [`CX_NL-1:0]                  lpbk_rxvalid;
logic [`CX_NL*3-1:0]                lpbk_rxstatus;
logic [`CX_NL-1:0]                  lpbk_phystatus;
logic [`CX_NL-1:0]                  lpbk_rxelecidle;
logic [4:0]                         lpbk_lane_under_test;
logic [`CX_NL-1:0]                  lpbk_rxdatavalid;
logic [`CX_NL-1:0]                  lpbk_rxdatavalid_i;
logic [`CX_NL*`CX_PHY_RXSB_WD-1:0]  lpbk_rxstartblock;
logic [`CX_NL*`CX_PHY_RXSH_WD-1:0]  lpbk_rxsyncheader;
logic [`CX_NL-1:0][`CX_PHY_RXSB_WD-1:0][4:0]  lpbk_osfound; // {SDS,EIEOS,EIOS,SKP END,SKP}


wire                          pre_mac_phy_blockaligncontrol;
wire                          pre_mac_phy_pam4_restricted_levels;
logic [`CX_NL-1:0]            pam4_restricted_levels_wr_ack_pending;
wire [`CX_NL*`CX_RX_PSET_WD-1:0]  pre_mac_phy_rxpresethint;
wire    [(`CX_NL*`CX_PHY_TXSB_WD)-1:0]  pre_mac_phy_txstartblock;
wire    [(`CX_NL*`CX_PHY_TXSH_WD)-1:0]  pre_mac_phy_txsyncheader;
wire    [(`CX_NL*`CX_PHY_NB)-1:0]       pre_mac_phy_txdatak;
wire [2:0]                    pre_mac_phy_txmargin;
wire                          pre_mac_phy_txswing;
wire    [`CX_NL-1:0]                    pre_mac_phy_txcompliance;
wire  [`CX_NL*3-1:0]                    pre_mac_phy_margin_cmd;
wire  [`CX_NL*7-1:0]                    pre_mac_phy_margin_offset;
wire  [`CX_NL*2-1:0]                    pre_mac_phy_margin_clr_error_log;



wire [`CX_NL*`CX_TX_FS_WD-1:0]    pre_mac_phy_fs;
wire [`CX_NL*`CX_TX_FS_WD-1:0]    pre_mac_phy_lf;
wire [`CX_NL*`PSET_ID_WD-1:0]     pre_mac_phy_local_pset_index;
wire [`CX_NL-1:0]                 pre_mac_phy_getlocal_pset_coef;
wire [`CX_NL-1:0]                 pre_mac_phy_rxeqinprogress;
wire [`CX_NL-1:0]                 pre_mac_phy_invalid_req;
wire                              pre_mac_phy_encodedecodebypass;
logic      pipe_regif_all_idle;

// PIPE51 obsolete signals
logic [`CX_NL-1:0]  regif_phystatus, tmp_regif_phystatus;
always_comb begin
regif_phystatus = lpbk_phystatus;
  regif_phystatus = tmp_regif_phystatus;
end

wire    [`CX_NL-1:0]                    int_pipe_turnoff = int_ltssm_txelecidle & int_mac_phy_txcompliance;


// polarity[`CX_NL-1:0] needs to flip when in gen3 & in Polling.Compliance & cfg_enter_compliance=1 only for the flipped lanes after Detect state
// because polarity[`CX_NL-1:0] has been latched using sticky_rst_n when smlh_link_up = 1 and polarity occurs in Polling state before Configuration and after Detect state
wire gen3_enter_compliance_i;
wire gen3_enter_compliance;
reg  gen3_enter_compliance_r;
assign gen3_enter_compliance_i = (smlh_ltssm_state == S_POLL_COMPLIANCE && ((current_data_rate == `GEN3_RATE) || (current_data_rate == `GEN4_RATE) || (current_data_rate == `GEN5_RATE) || current_data_rate == `GEN6_RATE) && cfg_enter_compliance);

always @( posedge core_clk or negedge core_rst_n ) begin : gen3_enter_compliance_r_PROC
    if ( ~core_rst_n )
        gen3_enter_compliance_r <= #`TP 0;
    else
        gen3_enter_compliance_r <= #`TP gen3_enter_compliance_i;
end // gen3_enter_compliance_r_PROC

assign gen3_enter_compliance = gen3_enter_compliance_i | gen3_enter_compliance_r;
wire [`CX_L2NL - 1 : 0] pm_rx_pol_lane_flip_ctrl_i;
assign pm_rx_pol_lane_flip_ctrl_i = gen3_enter_compliance ? ( ltssm_lane_flip_ctrl | (`CX_L2NL==1 ? tx_lane_flip_en : {tx_lane_flip_en, {(`CX_L2NL-1){1'b0}}}) ) : pm_rx_pol_lane_flip_ctrl;

assign {cfg_force_lane_flip, cfg_lane_under_test, cfg_lpbk_slave_tx_g5_mod_cmpl_ptrn, cfg_do_g5_lpbk_eq, cfg_mod_ts} = cfg_lut_ctrl;
wire   ltssm_master_lpbk_active_after_g5_lpbk_eq = lpbk_lane_under_test[4]; // loopback master in Gen5 Loopback.Active following Loopback EQ
assign lut_en   = cfg_force_lane_flip ? 1'b1 : ltssm_master_lpbk_active_after_g5_lpbk_eq ? 1'b1 : 1'b0;
assign lut_ctrl = {cfg_force_lane_flip, lut_en, cfg_lane_under_test};

reg [`CX_PHY_TXDEEMPH_WD-1:0] latched_int_smlh_eqpa_txdeemph;
ltssm_state_e          ltssm_state_d;
reg                    lpbk_after_lpbk_eq;
wire                   ltssm_perform_eq_for_lpbk_g6;
wire                   lpbk_after_lpbk_eq_i = ((current_data_rate < `GEN6_RATE) && ltssm_perform_eq_for_lpbk_g6) ? 1'b0 : (ltssm_state_d == S_RCVRY_EQ0 || ltssm_state_d == S_RCVRY_EQ1 || ltssm_state_d == S_RCVRY_EQ2 || ltssm_state_d == S_RCVRY_EQ3) && (smlh_ltssm_state == S_LPBK_ENTRY);

always @( posedge core_clk or negedge core_rst_n ) begin : latched_int_smlh_eqpa_txdeemph_PROC
    if ( ~core_rst_n ) begin
        latched_int_smlh_eqpa_txdeemph <= #`TP 0;
        ltssm_state_d            <= #`TP S_DETECT_QUIET;
        lpbk_after_lpbk_eq       <= #`TP 0;
    end else begin
        if ( smlh_ltssm_state == S_RCVRY_EQ0 || smlh_ltssm_state == S_RCVRY_EQ1 || smlh_ltssm_state == S_RCVRY_EQ2 || smlh_ltssm_state == S_RCVRY_EQ3 )
            latched_int_smlh_eqpa_txdeemph <= #`TP int_smlh_eqpa_txdeemph_i;

        ltssm_state_d            <= #`TP smlh_ltssm_state;

        if ( (current_data_rate < `GEN5_RATE) || (ltssm_state_d == S_LPBK_ENTRY && (smlh_ltssm_state == S_RCVRY_EQ0 || smlh_ltssm_state == S_RCVRY_EQ1)) ) // clear when entry to Loopback EQ
            lpbk_after_lpbk_eq   <= #`TP 0;
        else if ( lpbk_after_lpbk_eq_i )
            lpbk_after_lpbk_eq   <= #`TP 1;
    end
end // latched_int_smlh_eqpa_txdeemph_PROC

     // after Loopback EQ, the TxDeemphasis (coefficients) must not change
     assign int_smlh_eqpa_txdeemph = (lpbk_after_lpbk_eq_i || lpbk_after_lpbk_eq) ? latched_int_smlh_eqpa_txdeemph : int_smlh_eqpa_txdeemph_i;

// ======================================================================================
// ======================================================================================

logic                splh_pm_req_l0s;    // Packet Layer requests PM Link FSM to enter L0s
logic                splh_pm_req_l1;     // Packet Layer requests PM Link FSM to enter L1
logic                splh_pm_req_l2;     // Packet Layer requests PM Link FSM to enter L2
 logic                  xplh_xmlh_sof;

tx_cmd_struct         splh_xplh_cmd;      // Command from SPLH (CXL)/XMLH (PCIe) to XPLH
logic                 xplh_xmlh_cmd_ack;
logic                 xplh_splh_cmd_ack; // Command Complete Acknowledge from XPLH to SPLH (CXL)/XMLH (PCIe)
logic                 xmlh_fm_pending;
logic                 xmlh_xfsh_last_flit;

logic xmbyte_flit_data_stream;

logic [1:0] xplh_cdm_flit_err_inj_status;
logic [1:0] rplh_cdm_flit_err_inj_status;

logic xplh_smlh_req_rcvry; // XPLH requests the LTSSM to go to recovery
logic smlh_idl_hs_done;       // rcvd 8 idle flits in R.Idle or C.Idle states, cleared when deskew gets reset (~smlh_do_deskew) from ltssm
logic ltssm_cmd_compliance_ts1;    // sending two Compliance TS1 in Polling.Compliance
logic [7:0] ltssm_compliance_set_num;    //sequence setting number for sending Compliance TS1 in Polling.Compliance
logic ltssm_flit_mode_tx;        // for TX
logic smlh_usp_sris_mode;

// SMLH -> XMLH
wire                        smlh_l0p_update;
wire   [5:0]                smlh_l0p_next_link_mode; // 10000 -- x16, 01000 -- x8, 00100 -- x4, 00010 -- x2, 00001 -- x1
wire   [`CX_NL-1:0]         ltssm_l0p_last_lanes_active;  // LTSSM latched lanes that are active based on the link negotiation
wire   [3:0]                ltssm_l0p_cmd;           // encoded command to notify transmitter of the proper action based on LTSSM states
wire                        ltssm_l0p_cmd_4_eieos_req; //4 eieos request at gen6 rate
// XMLH -> SMLH/RMLH
wire                        xmtbyte_l0p_eidle_sent;
wire   [OS_WD-1:0]          xmtbyte_l0p_ts1_sent;
wire   [OS_WD-1:0]          xmtbyte_l0p_ts2_sent;
wire                        xmtbyte_l0p_linkwidth_changed;
wire                        xmtbyte_l0p_link_in_training;
// XMLH -> RMLH
wire                        xmtbyte_l0p_sris_mode_enabled;
// XMLH -> SMLH
wire                        xmtbyte_l0p_state_in_upsize;

// From RMLH
wire                        smlh_inskip_rcv;                // when asserted, RPLH is in skip receiving
wire                        smlh_ts_rcv_err;                // When asserted, it indicates that the TS has violation in hear beat.
wire                        smlh_ts1_rcvd;                  // when asserted, RPLH rcvd TS1
wire                        smlh_ts2_rcvd;                  // when asserted, RPLH rcvd TS2
wire    [4:0]               smlh_ts_link_ctrl;              // 5 bits
wire                        smlh_ts_lane_num_is_k237;
wire    [7:0]               smlh_ts_link_num;               // 8 bit link number
wire                        smlh_ts_link_num_is_k237;       // Indicates whether or not received Kchar with k237
wire                        smlh_rcvd_lane_rev;
wire    [`CX_NL-1:0]        smlh_lanes_rcving;
wire    [1:0]               rplh_rcvd_idle;                 // Track of the number of idle received continously.  Bit 0 indicates receiver received 8 continous idle symbol, bit1 indicates 1 idle receivd
wire    [`CX_NL-1:0]        act_rmlh_rcvd_eidle_set;        // receiver rcvd eidle set per lane.
wire                        rmlh_all_sym_locked;            // symbol locked on all active lanes

wire  [`CX_NL-1:0]          rpipe_rxaligned;                // indicates rxvalid with squelch
wire                        rmlh_deskew_datastream;         // Rx in Data Stream
wire  [`CX_NL*8-1:0]        smlh_gen3_error_count;          // per lane version of gen3 error count
wire  [`CX_NL-1:0]          rmlh_descrambled_rxaligned;
wire                        rmlh_gen3_rcvd_4eidle_set;      // in Loopback.Active
wire    [`CX_NL-1:0]        act_rmlh_gen3_rcvd_4eidle_set;  // in Loopback.Active per lane
wire                        rmlh_goto_recovery;             // all active lanes received EIEOS at same time at gen3 rate while exiting Data Stream
wire    [`CX_NL-1:0]        rmlh_deskew_datastream_bus;     // Rx in Data Stream
wire                        smlh_ltssm_in_l0p_upsize;
wire                        rplh_rmlh_pkt_err;              // Framing error
wire                        s_rplh_rmlh_pkt_err;
wire    [4:0]               rplh_rmlh_pkt_err_ptr;          // Framing error pointer indication

wire    [`CX_NL-1:0]        rpipe_rxdetected;               // RMLH pipe module output to SMLH
wire                        rpipe_rxdetect_done;            // RMLH pipe module output to SMLH
wire                        rpipe_all_phystatus_deasserted;

wire    [(`CX_NL*`CX_NB*8)-1:0] rpipe_rxdata;
wire    [(`CX_NL*`CX_NBK)-1:0]  rpipe_rxdatak;
wire    [(`CX_NL*`CX_NB)-1:0]   rpipe_rxerror_dup;
wire    [`CX_NL-1:0]            rpipe_rxdata_dv;                // RMLH pipe module output to SMLH

wire    [`CX_NL-1:0]        lpbk_eq_lanes_active;
wire    [`CX_NL-1:0]        smlh_txlanes_active;            // Which lanes are actively configured (TX SIDE)
wire    [`CX_NL-1:0]        smlh_rxlanes_active;            // Which lanes are actively configured (RX SIDE)
wire                        smlh_lnknum_match_dis;          // This signal is designed to notify the rmlh block when to enable link number match checking
wire                        smlh_ltssm_in_pollconfig;       // this signal enables receiver to detect the polarity and invert if necessary.
wire    [`CX_NL-1:0]        smlh_no_turnoff_lanes;          // upconfigure lanes
wire                        smlh_scrambler_disable;         // when asserted, scramble disabled.
wire                        xmlh_cmd_is_data;               // xmtbyte state machine is waiting for packet start or packet end
wire                        smlh_link_disable;
wire    [5:0]               smlh_link_txmode;               // 6 bit link width; 10000 = x16, 1000 = x8, 100 = x4, 10 = x2, 1 = x1
wire                        cpcie_smlh_usp_eq_pending;      // Equalization Pending
assign smlh_usp_eq_pending = cpcie_smlh_usp_eq_pending;


spif_if    b_smlh_spif();          // SMLH SPIF Interface
spif_if    b_xplh_spif();          // XPLH SPIF Interface
spif_if    b_rplh_spif();          // RPLH SPIF Interface

protocol_cfg_t  smlh_protocol_cfg; // SPIF Protocol Configuration for MLH Layer

logic      splh_cmd_if_pmreq_ack;  // SPLH Command Interface PM Entry Acknowledge to XMLH
logic      splh_cmd_if_stall_ack;  // SPLH Command Interface Stall Acknowledge to XMLH
logic      splh_cmd_if_pending;    // SPLH Command Interface Packet Pending Indication to XMLH

logic      xplh_linkerror;         // XPLH Link Error indication

logic      int_xmlh_cmd_if_lp_ack; // XMLH Command Interface LP Ackownledge
wire   cxl_io_throttle_enable;  // Enable CXL.io throttling in 256B Flit Mode

wire    [2:0]               pm_current_data_rate_others_int;
wire    [2:0]               pm_current_data_rate_others_o;
wire    [2:0]               pm_current_data_rate_xmlh_xmt;
wire    [2:0]               pm_current_data_rate_xmlh_scr;
wire    [2:0]               pm_current_data_rate_rplh_pkf;
wire    [2:0]               pm_current_data_rate_smlh_sqf;
wire    [2:0]               pm_current_data_rate_smlh_lnk;
wire    [2:0]               pm_current_data_rate_smlh_eq;
wire    [2:0]               pm_current_data_rate_ltssm;
wire    [1:0]               current_powerdown;
ltssm_state_e               smlh_ltssm_state_wire;
wire   smlh_precoding6_on_latched;
assign smlh_g6_tx_precoding_on           = smlh_precoding6_on_latched; //GEN6_TODO
assign smlh_autoneg_link_width           = (smlh_ltssm_in_l0p) ? smlh_l0p_link_mode : smlh_link_mode;
assign smlh_autoneg_link_sp              = pm_current_data_rate == `GEN6_RATE ? `GEN6_LINK_SP :
                                           (pm_current_data_rate == `GEN5_RATE) ? `GEN5_LINK_SP : (pm_current_data_rate == `GEN4_RATE) ? `GEN4_LINK_SP : (pm_current_data_rate == `GEN3_RATE ) ? `GEN3_LINK_SP  : ((pm_current_data_rate == `GEN2_RATE) ? `GEN2_LINK_SP : `GEN1_LINK_SP);

assign smlh_link_training_in_prog        = smlh_link_in_training;

// active number of symbols. bit0=1s, bit1=2s, bit2=4s, bit3=8s , bit4=16s
wire [`CX_ANB_WD-1:0] active_nb;
wire [`CX_ANB_WD-1:0] active_nb_wire;
wire [`CX_ANB_WD-1:0] active_nb_gen34;
wire       smlh_do_deskew;

// link training state machine detects a violation of the rules which is an option checker
// Rules to detect the violation of the SDP, STP and END location of multi-lane port, and etc, is another optional checker
// Therefore two of the errors below are wired to zero. Not support at the moment
wire                        rmlh_deskew_complete;
wire    [`CX_NL-1:0]        rpipe_rxerror;                  // when asserted, RMLH indicates that the receiver has detected an rx disparity or code error
wire    [`CX_NL-1:0]        smlh_mcs_rcvd;

wire                                smlh_ltssm_in_compliance;
wire                                smlh_ltssm_in_rcvrylock;

wire   [`CX_NL*EQTS_WD-1:0]         eqctl_eqts_info;
wire   [`CX_NL*TS_0_WD-1:0]         eqctl_eqts_info_ts0;
wire                                eqctl_g6_tx_ts0;
wire                                link_rx_ts0_to_ts1_pulse;
wire   [`CX_NL-1:0]                 eqctl_mask_eieos;
wire   [`CX_NL-1:0]                 eqctl_2mask_eieos_pulse;
wire   [`CX_NL*`CX_TX_PSET_WD-1:0]  eqctl_pset_ltx;
wire   [`CX_NL-1:0]                 rmlh_descrambled_rxdata_dv;
wire   [(`CX_NL*`CX_NB*8)-1:0]      rmlh_descrambled_rxdata;
wire   [(`CX_NL*`CX_MAC_SB_WD)-1:0] rmlh_descrambled_rxstartblock;
wire   [`CX_NL-1:0][`CX_MAC_SB_WD-1:0][4:0] rmlh_descrambled_rxdata_osfound;
wire   [`CX_NL*DCB_WD-1:0]          rmlh_descrambled_rxdata_dcb;
wire   [`CX_NL-1:0]                 rmlh_deskew_ds_g6;
wire   [(`CX_NL*`CX_MAC_SB_WD)-1:0] rmlh_descrambled_ints1;
wire   [(`CX_NL*`CX_MAC_SB_WD)-1:0] rmlh_descrambled_ints2;
wire   [(`CX_NL*`CX_MAC_SB_WD)-1:0] rmlh_descrambled_inskp;
wire   [(`CX_NL*`CX_MAC_SB_WD)-1:0] rmlh_descrambled_ineie;
wire   [(`CX_NL*`CX_MAC_SB_WD)-1:0] rmlh_descrambled_eie_det;
wire   [(`CX_NL*`CX_MAC_SB_WD)-1:0] rmlh_descrambled_insds;
wire   [(`CX_NL*`CX_NBK)-1:0]       rmlh_descrambled_rxdatak;
wire   [(`CX_NL*`CX_NB)-1:0]        rmlh_descrambled_rxerror;
wire   [`CX_NL-1:0]                 rmlh_deskew_ctlskp_rcvd;
wire   [(`CX_NL*16)-1:0]            rmlh_deskew_ctlskp_info;
wire   [(`CX_NL*16)-1:0]            smlh_ctlskp_info;
wire   [(`CX_NL*3)-1:0]             smlh_margin_cmd;
wire   [(`CX_NL*7)-1:0]             smlh_margin_offset;
wire   [(`CX_NL*2)-1:0]             smlh_margin_clr_error_log;
wire                                ltssm_dsp_g6_eq1_send_ec00;
wire                                xmlh_sent_24_ts0_ec00;


wire                        xmtbyte_skip_sent;
wire                        xmtbyte_ctlskip_sent;
wire                        smlh_successful_spd_negotiation;
wire    [`CX_NL*4-1:0]      smseq_loc_eies_rcvd_bus;
wire    [`CX_NL*4-1:0]      smseq_loc_ts2_rcvd_bus;
wire    [`CX_NL*4-1:0]      smseq_in_skp_bus;
wire    [`CX_NL-1:0]        smseq_fts_skp_do_deskew_bus;

logic                       clear_prbs_done_pl;

wire                        ltssm_rcvr_err_rpt_en;
wire    [3:0]               ltssm_eidle_cnt;                // 3 bits, indicates how many EIOS sets to send before returning xmtbyte_eidle_sent.  0=1 EIOS, 1=2 EIOS, etc.
wire                        ltssm_lpbk_master;

wire    [OS_WD-1:0]         xmtbyte_ts1_sent;
wire    [OS_WD-1:0]         xmtbyte_ts2_sent;
wire                        xmtbyte_idle_sent;
wire                        xmtbyte_eidle_sent;
wire                        xmtbyte_2_compliance_ts1_sent;

wire    [10:0]              xmtbyte_ts_pcnt;
wire                        xmtbyte_ts_data_diff;
wire                        xmtbyte_1024_ts_sent;
wire                        xmtbyte_spd_chg_sent;
wire                        xmtbyte_dis_link_sent;
wire                        xmtbyte_loe_2_ts1_ec_00b_sent;

wire                        ltssm_ts_cnt_en;
wire                        xmtbyte_eies_sent;
wire                        ltssm_ts_speed_change;
wire   [4:0]                ltssm_ts_data_rate;
wire   [4:0]                latched_ts_data_rate;
wire   [9:0]                ltssm_ts_data_rate_eg6;
wire   [9:0]                latched_ts_data_rate_eg6;
wire                        ltssm_cmd_eqts0;
wire                        ltssm_ts_cnt_rst;
wire                        ltssm_ts_auto_change;
wire   [7:0]                ltssm_xlinknum;
wire   [`CX_NL-1:0]         ltssm_xk237_4lannum;
wire   [`CX_NL-1:0]         ltssm_xk237_4lnknum;
wire   [7:0]                ltssm_ts_cntrl;
wire                        ltssm_mod_ts;
wire                        ltssm_in_lpbkentry;
wire                        ltssm_cmd_send_eieos_for_pset_map;
wire                        ltssm_usp_eq_redo;
wire                        ltssm_in_lpbk;
wire                        xmtbyte_fts_sent;
wire                        xmtbyte_txdata_dv;
wire   [(`CX_NL*`CX_NB*8)-1:0] xmtbyte_txdata;
wire   [(`CX_NL*`CX_NBK)-1:0]  xmtbyte_txdatak;
wire   [`CX_NL-1:0]         xmtbyte_txelecidle;
wire                        xmtbyte_txdetectrx_loopback;
ltssm_state_e               smlh_ltssm_next;
ltssm_state_e               smlh_ltssm_last;
wire   [7:0]                muxed_n_fts;
wire   [3:0]                ltssm_cmd;
wire [3:0]                  ltssm_gen4_compliance_jmp;
wire [3:0]                  ltssm_gen6_compliance_tp;

// From rmlh to rplh
wire  [(`CX_NL*`CX_NB*8)-1:0]rmlh_rplh_rxdata;
wire  [(`CX_NL*`CX_NB)-1:0]  rmlh_rplh_rxdatak;
wire  [(`CX_NL*`CX_NB)-1:0]  rmlh_rplh_rxerror;
wire                         rmlh_rplh_dv;
wire                         rmlh_rplh_os_in_datastream;
wire                         rmlh_rplh_search_for_tokens;
wire                         rmlh_rplh_accept_eds_cycle;
wire                         rmlh_rplh_expect_eds;
wire  [4:0]                  rmlh_rplh_rxdata_link_width;
wire  [1:0]                  rmlh_rplh_rcvd_idle_gen12;

// The following signals are used of freq_step b/w layer1 and layer2
wire                         pl_rmlh_rcvd_err;
wire                         pl_rmlh_deskew_alignment_err;
wire    [`CX_NL-1:0]         pl_rmlh_lane_err;              // Indicates if the corresponding lane detected a lane-based error
wire   [`CX_NL*5-1:0]        pl_rmlh_deskew_ctlskp_err;
wire    [`CX_NL-1:0]         pl_rmlh_rpipe_rxoverflow;  
wire    [`CX_NL-1:0]         pl_rmlh_rpipe_rxunderflow; 
wire    [`CX_NL-1:0]         pl_rmlh_rpipe_rxcodeerror; 
wire    [`CX_NL-1:0]         pl_rmlh_rpipe_rxdisperror; 
wire    [`CX_NL-1:0]         pl_rmlh_rpipe_rxskipadded; 
wire    [`CX_NL-1:0]         pl_rmlh_skp_parity_err;    
wire    [`CX_NL-1:0]         pl_rmlh_sync_header_err;   
wire                         pl_rmlh_framing_err;       
wire    [6:0]                pl_rmlh_framing_err_ptr;   
wire                         pl_rmlh_framing_err_l0;
wire                         pl_pm_block_phystatus;


wire [`CX_L2NL-1:0]        latched_flip_ctrl;

wire                       info_txelec_txburst ;
wire                       info_txcomp_rxburst ;
wire   [7:0]               info_link_number ;
wire                       info_inskip_rcv ;
wire                       info_ts1_rcvd ;
wire                       info_ts2_rcvd ;
wire                       info_rcvd_lane_rev ;
wire   [3:0]               info_ts_link_ctrl ;
wire                       info_ts_lane_num_is_k237 ;
wire                       info_ts_link_num_is_k237 ;
wire   [15:0]              info_tx_data_symbol ;
wire   [1:0]               info_tx_datak_ctrl ;

wire   [`CX_NL-1:0]            rpipe_margin_status ;
wire   [`CX_NL-1:0]            rpipe_margin_nak ;
wire   [(`CX_NL*6)-1:0]        rpipe_margin_error_cnt ;
wire   [(`CX_NL*7)-1:0]        rpipe_margin_sampl_cnt ;

assign info_txelec_txburst       = tmp_ltssm_txelecidle[0] ;
assign info_txcomp_rxburst       = tmp_mac_phy_txcompliance[0] ;
assign info_link_number          = smlh_ts_link_num ;
assign info_inskip_rcv           = smlh_inskip_rcv ;
assign info_ts1_rcvd             = smlh_ts1_rcvd ;
assign info_ts2_rcvd             = smlh_ts2_rcvd ;
assign info_rcvd_lane_rev        = smlh_rcvd_lane_rev ;
assign info_ts_link_ctrl         = smlh_ts_link_ctrl[3:0] ;
assign info_ts_lane_num_is_k237  = smlh_ts_lane_num_is_k237 ;
assign info_ts_link_num_is_k237  = smlh_ts_link_num_is_k237 ;
assign info_tx_data_symbol       = tmp_mac_phy_txdata[15:0] ;
assign info_tx_datak_ctrl        = tmp_mac_phy_txdatak[1:0] ;


// status that used to help link negotiation
wire    [63:0]              pre_cxpl_debug_info;
assign pre_cxpl_debug_info = {
    smlh_scrambler_disable,     // 31
    smlh_link_disable,          // 30
    smlh_link_in_training,      // 29
    smlh_ltssm_in_pollconfig,   // 28
    smlh_training_rst_n,        // 27
    1'b0,                       // 26
    2'b0,                       // 25:24
    1'b0,                       // 23
    tmp_mac_phy_txdetectrx_loopback[0],// 22
    info_txelec_txburst,        // 21
    info_txcomp_rxburst,        // 20
    app_init_rst,               // 19
    1'b0,                       // 18
    2'b0,                       // 17:16
    info_link_number,           // 15:8
    2'b0,                       // 7:6
    xmtbyte_skip_sent,          // 5
    smlh_link_up,               // 4
    info_inskip_rcv,            // 3
    info_ts1_rcvd,              // 2
    info_ts2_rcvd,              // 1
    info_rcvd_lane_rev,         // 0
    info_ts_link_ctrl[3:0],     // 31:28
    info_ts_lane_num_is_k237,   // 27
    info_ts_link_num_is_k237,   // 26
    rplh_rcvd_idle[0],          // 25
    rplh_rcvd_idle[1],          // 24
    info_tx_data_symbol,        // 23:8
    info_tx_datak_ctrl,         // 7:6
    smlh_ltssm_state            // 5:0
};


assign cxpl_debug_info = pre_cxpl_debug_info;

// This signal is used to by the ltssm to reset idle_to_rlock flag
wire                        rplh_pkt_start;
assign  rplh_pkt_start      = |rplh_rdlh_dllp_start || |rplh_rdlh_tlp_start;


wire    [5:0]               cpcie_smlh_link_mode;
wire    [5:0]               cpcie_smlh_link_rxmode;
wire    [`CX_NL-1:0]        cpcie_smlh_lanes_active;
wire    [`CX_NL-1:0]        cpcie_smlh_no_turnoff_lanes;
wire                        cpcie_smlh_lnknum_match_dis;
wire                        cpcie_smlh_link_up;
wire                        cpcie_smlh_link_up_o;
wire                        cpcie_smlh_req_rst_not;
wire                        cpcie_smlh_req_rst_not_o;
wire                        cpcie_smlh_scrambler_disable;
wire                        cpcie_smlh_ltssm_in_pollconfig;
wire                        cpcie_smlh_training_rst_n;
wire                        cpcie_smlh_link_disable;
wire                        cpcie_smlh_link_in_training;
wire                        cpcie_smlh_bw_mgt_status;
wire                        cpcie_smlh_link_auto_bw_status;
ltssm_state_e               cpcie_smlh_ltssm_next;
wire    [`CX_NL-1:0]        cpcie_deskew_lanes_active;
wire    [`CX_NL-1:0]        cpcie_mac_phy_txdetectrx_loopback;
wire    [`CX_NL-1:0]        cpcie_mac_phy_txcompliance;
wire    [2:0]               cpcie_mac_phy_rate;
wire    [`CX_NL-1:0]        cpcie_mac_phy_rxpolarity;
wire    [`CX_NL-1:0]        cpcie_mac_phy_rxstandby;
wire    [`CX_NL-1:0]        cpcie_smlh_set_rxstandby;
wire    [1:0]               cpcie_mac_phy_txdeemph;
wire    [2:0]               cpcie_mac_phy_txmargin;
wire                        cpcie_mac_phy_txswing;
wire                        cpcie_smlh_clr_enter_compliance;
wire                        cpcie_smlh_tx_margin_rst;
wire                        cpcie_smlh_successful_spd_negotiation;
wire                        cpcie_smlh_core_rst_n_release_pulse;
wire                        cpcie_smlh_dir_spd_chg_rising_edge;
wire    [`CX_NL-1:0]        cpcie_smlh_mcs_rcvd;
wire    [`CX_NL*4-1:0]      cpcie_smseq_loc_eies_rcvd_bus;
wire                        cpcie_mac_phy_pam4_restricted_levels;
wire                        cpcie_smlh_dir_linkw_chg_started;
wire                        cpcie_smlh_ltssm_in_hotrst_dis_entry;
wire    [`CX_NL-1:0]        cpcie_smseq_ts1_rcvd_pulse_bus;
wire    [`CX_NL-1:0]        cpcie_smseq_ts2_rcvd_pulse_bus;
wire    [`CX_NL*4-1:0]      cpcie_smseq_loc_ts2_rcvd_bus;
wire    [`CX_NL*4-1:0]      cpcie_smseq_in_skp_bus;
wire    [`CX_NL-1:0]        cpcie_smseq_fts_skp_do_deskew_bus;
wire                        cpcie_smlh_ltssm_in_compliance;
wire                        cpcie_smlh_ltssm_in_rcvrylock;
wire                        cpcie_smlh_ltssm_in_detectquiet;
wire                        cpcie_ltssm_cmd_send_eieos_for_pset_map;
wire                        cpcie_ltssm_usp_eq_redo;
wire                        cpcie_smlh_ls2_eq_req;
wire   [3:1]                cpcie_smlh_ls2_eq_success;
wire                        cpcie_smlh_ls2_eq_cmpl;
wire                        cpcie_smlh_ls2_eq_enter;
wire                        cpcie_smlh_eq_pending;
wire                        cpcie_smlh_auto_eq_dllp_blocking;
wire   [`CX_NL*`CX_TX_PSET_WD-1:0]  cpcie_smlh_lec_pset_ltx;
wire   [`CX_NL*`CX_RX_PSET_WD-1:0]  cpcie_smlh_lec_pset_lrx;
wire                        cpcie_smlh_ltssm_state_rcvry_eq;
wire                        cpcie_smlh_ltssm_state_rcvry_eq_o;
wire    [`CX_NL*8-1:0]      cpcie_smlh_gen3_error_count;

wire                        cpcie_smlh_ls2_g4_eq_req;
wire    [3:1]               cpcie_smlh_ls2_g4_eq_success;
wire                        cpcie_smlh_ls2_g4_eq_cmpl;
wire                        cpcie_smlh_ls2_g4_eq_enter;
wire    [`CX_NL*`CX_TX_PSET_WD-1:0] cpcie_smlh_lec_g4_pset_ltx;
wire    [`CX_NL*`CX_RX_PSET_WD-1:0] cpcie_smlh_lec_g4_pset_lrx;
wire                        cpcie_smlh_retimer_pre_detected;
wire                        cpcie_smlh_ls2_g5_eq_req;
wire    [3:1]               cpcie_smlh_ls2_g5_eq_success;
wire                        cpcie_smlh_ls2_g5_eq_cmpl;
wire                        cpcie_smlh_ls2_g5_eq_enter;
wire    [`CX_NL*`CX_TX_PSET_WD-1:0] cpcie_smlh_lec_g5_pset_ltx;
wire    [`CX_NL*`CX_RX_PSET_WD-1:0] cpcie_smlh_lec_g5_pset_lrx;
wire                        smlh_deprecode_on;
wire                        smlh_precoding_on;
wire                        smlh_precoding_on_latched;
wire    [`CX_ANB_WD-1:0]    cpcie_active_nb;
wire    [`CX_ANB_WD-1:0]    cpcie_active_nb_gen34;
wire                        cpcie_smlh_do_deskew;
ltssm_state_e               cpcie_smlh_ltssm_state;
wire                        cpcie_smlh_in_l0s;
wire                        cpcie_smlh_in_rl0s;
wire                        cpcie_smlh_in_l0;
wire                        cpcie_smlh_in_l1;
wire                        cpcie_smlh_in_l1_p1;
wire                        cpcie_smlh_in_l23;
wire                        cpcie_smlh_l123_eidle_timeout;
wire    [4:0]               cpcie_smlh_ts_link_ctrl;
wire                        cpcie_smlh_rcvd_lane_rev;
wire    [7:0]               cpcie_smlh_ts_link_num;
wire                        cpcie_smlh_ts_link_num_is_k237;
wire    [`CX_NL-1:0]        cpcie_smlh_lanes_rcving;
wire                        cpcie_smlh_ts_rcv_err;
wire                        cpcie_smlh_ts1_rcvd;
wire                        cpcie_smlh_ts2_rcvd;
wire                        cpcie_smlh_inskip_rcv;
wire                        cpcie_smlh_ts_lane_num_is_k237;
wire                        cpcie_latched_rcvd_eidle_set;
wire                        cpcie_ltssm_rcvr_err_rpt_en;
wire                        cpcie_ltssm_clear;
wire    [3:0]               cpcie_ltssm_cmd;
wire    [`CX_NL*`CX_TX_COEF_WD-1:0] cpcie_smlh_eqpa_txdeemph;
wire    [`CX_BAC_WD-1:0]            cpcie_smlh_blockaligncontrol;
wire    [`CX_NL*`CX_RX_PSET_WD-1:0] cpcie_mac_phy_rxpresethint;
wire    [`CX_NL*`CX_TX_FS_WD-1:0]   cpcie_mac_phy_fs;
wire    [`CX_NL*`CX_TX_FS_WD-1:0]   cpcie_mac_phy_lf;
wire    [`CX_NL-1:0]                cpcie_mac_phy_getlocal_pset_coef;
wire    [`CX_NL*`PSET_ID_WD-1:0]    cpcie_mac_phy_local_pset_index;
wire    [`CX_NL-1:0]                cpcie_mac_phy_rxeqinprogress;
wire    [`CX_NL-1:0]                cpcie_mac_phy_invalid_req;
wire    [`CX_NL-1:0]                cpcie_mac_phy_rxeqeval;
wire    [`CX_NL-1:0]                cpcie_mac_phy_dirchange;
wire    [`CX_NL*`CX_TX_COEF_WD-1:0] cpcie_mac_phy_smlh_coef_rtx;
wire    [1:0]               cpcie_ltssm_powerdown;
wire                        cpcie_ltssm_lpbk_master;
wire                        cpcie_ltssm_ts_cnt_en;
wire                        cpcie_ltssm_ts_cnt_rst;
wire    [4:0]               cpcie_ltssm_ts_data_rate;
wire                        cpcie_ltssm_ts_speed_change;
wire    [4:0]               cpcie_latched_ts_data_rate;
wire   [9:0]                cpcie_ltssm_ts_data_rate_eg6;
wire   [9:0]                cpcie_latched_ts_data_rate_eg6;
wire                        cpcie_ltssm_ts_auto_change;
wire    [7:0]               cpcie_ltssm_xlinknum;
wire    [`CX_NL-1:0]        cpcie_ltssm_xk237_4lannum;
wire    [`CX_NL-1:0]        cpcie_ltssm_xk237_4lnknum;
wire    [7:0]               cpcie_ltssm_ts_cntrl;
wire                        cpcie_ltssm_ts_alt_protocol;
wire                        cpcie_ltssm_no_idle_need_sent;
wire    [55:0]              cpcie_ltssm_ts_alt_prot_info;
wire    [55:0]              ltssm_mod_ts_data_sent;
assign                      mod_ts_data_sent = ltssm_mod_ts_data_sent;
ltssm_cxl_enable_t          cpcie_ltssm_cxl_enable;
assign                      ltssm_cxl_enable = cpcie_ltssm_cxl_enable;
wire    [23:0]              cpcie_ltssm_cxl_mod_ts_phase1_rcvd;
wire                        cpcie_ltssm_cxl_retimers_pre_mismatched;
wire                        cpcie_ltssm_cxl_flexbus_phase2_mismatched;
wire                        cpcie_ltssm_in_lpbk;
wire    [2:0]               cpcie_ltssm_eidle_cnt;
assign ltssm_cxl_mod_ts_phase1_rcvd = cpcie_ltssm_cxl_mod_ts_phase1_rcvd;
assign ltssm_cxl_retimers_pre_mismatched = cpcie_ltssm_cxl_retimers_pre_mismatched;
assign ltssm_cxl_flexbus_phase2_mismatched = cpcie_ltssm_cxl_flexbus_phase2_mismatched;
wire                        cpcie_ltssm_in_lpbkentry;
wire    [`CX_NL*EQTS_WD-1:0]cpcie_eqctl_eqts_info;
wire    [`CX_NL-1:0]        cpcie_eqctl_mask_eieos;
wire    [`CX_NL-1:0]        cpcie_eqctl_2mask_eieos_pulse;
wire    [`CX_NL*`CX_TX_PSET_WD-1:0] cpcie_eqctl_pset_ltx;
wire    [`CX_NL-1:0]        ltssm_lpbk_slave_lut;
wire    [7:0]               cpcie_muxed_n_fts;
wire    [7:0]               cpcie_latched_ts_nfts;
wire    [`CX_INFO_EI_WD-1:0]cpcie_cxpl_debug_info_ei;
wire    [`CX_L2NL-1:0]      cpcie_smlh_lane_flip_ctrl;
wire    [`CX_L2NL-1:0]      cpcie_ltssm_lane_flip_ctrl;

logic                       ltssm_in_lpbk_wo_l0;            // Ltssm in Loopback state in Gen6 without entering L0 since leaving Detect state

wire                        ltssm_clear;
wire    [4:0]               cpcie_l0s_state;
wire                        cpcie_smlh_eidle_inferred_in_l0;
wire                        cpcie_smlh_rx_rcvry_req;
wire                        cpcie_smlh_timeout_nfts;
wire                        cpcie_smlh_l0_to_recovery;
wire                        cpcie_smlh_l1_to_recovery;
wire                        cpcie_smlh_rcv_eios_when_l0s_unsprt;
wire                        cpcie_smlh_deskew_uncomplete_err;
wire                        cpcie_smlh_spd_change;
wire    [`CX_NL*8-1:0]      cpcie_smseq_mcs_sts;
wire                        cpcie_smlh_lwd_change;
wire    [15:0]              cpcie_smlh_ltssm_variable;
wire    [`CX_NL*64-1:0]     cpcie_smseq_ts_debug_info;
wire    [`CX_NL*16-1:0]     cpcie_smlh_rxos_type;
wire                        cpcie_init_eq_pending;
wire    [`CX_NL*`CX_TX_FS_WD-1:0]   cpcie_mac_cdm_ras_des_fs;
wire    [`CX_NL*`CX_TX_FS_WD-1:0]   cpcie_mac_cdm_ras_des_lf;
wire    [`CX_NL*`CX_TX_COEF_WD-1:0] cpcie_mac_cdm_ras_des_coef_ltx;
wire    [`CX_NL*`CX_FOMFEEDBACK_WD-1:0] cpcie_phy_cdm_ras_des_fomfeedback;
wire    [`CX_NL*3-1:0]              cpcie_eqpa_violate_rule_123;
wire    [`CX_NL*2-1:0]              cpcie_eq_convergence_sts;
wire    [`CX_NL*`CX_TX_COEF_WD-1:0] cpcie_mac_cdm_ras_des_coef_rtx;
wire    [`CX_NL*`CX_RX_PSET_WD-1:0] cpcie_mac_cdm_ras_des_pset_lrx;
wire    [`CX_NL-1:0]                cpcie_mac_cdm_ras_des_reject_rtx;
wire                                cpcie_init_eq_pending_g4;
wire    [`CX_NL*`CX_TX_FS_WD-1:0]   cpcie_mac_cdm_ras_des_fs_g4;
wire    [`CX_NL*`CX_TX_FS_WD-1:0]   cpcie_mac_cdm_ras_des_lf_g4;
wire    [`CX_NL*`CX_TX_COEF_WD-1:0] cpcie_mac_cdm_ras_des_coef_ltx_g4;
wire    [`CX_NL*`CX_FOMFEEDBACK_WD-1:0] cpcie_phy_cdm_ras_des_fomfeedback_g4;
wire    [`CX_NL*3-1:0]              cpcie_eqpa_violate_rule_123_g4;
wire    [`CX_NL*2-1:0]              cpcie_eq_convergence_sts_g4;
wire    [`CX_NL*`CX_TX_COEF_WD-1:0] cpcie_mac_cdm_ras_des_coef_rtx_g4;
wire    [`CX_NL-1:0]                cpcie_mac_cdm_ras_des_reject_rtx_g4;
wire                                cpcie_init_eq_pending_g5;
wire    [`CX_NL*`CX_TX_FS_WD-1:0]   cpcie_mac_cdm_ras_des_fs_g5;
wire    [`CX_NL*`CX_TX_FS_WD-1:0]   cpcie_mac_cdm_ras_des_lf_g5;
wire    [`CX_NL*`CX_TX_COEF_WD-1:0] cpcie_mac_cdm_ras_des_coef_ltx_g5;
wire    [`CX_NL*`CX_FOMFEEDBACK_WD-1:0] cpcie_phy_cdm_ras_des_fomfeedback_g5;
wire    [`CX_NL*3-1:0]              cpcie_eqpa_violate_rule_123_g5;
wire    [`CX_NL*2-1:0]              cpcie_eq_convergence_sts_g5;
wire    [`CX_NL*`CX_TX_COEF_WD-1:0] cpcie_mac_cdm_ras_des_coef_rtx_g5;
wire    [`CX_NL-1:0]                cpcie_mac_cdm_ras_des_reject_rtx_g5;
wire                                cpcie_init_eq_pending_g6;
wire    [`CX_NL*`CX_TX_FS_WD-1:0]   cpcie_mac_cdm_ras_des_fs_g6;
wire    [`CX_NL*`CX_TX_FS_WD-1:0]   cpcie_mac_cdm_ras_des_lf_g6;
wire    [`CX_NL*`CX_TX_COEF_WD-1:0] cpcie_mac_cdm_ras_des_coef_ltx_g6;
wire    [`CX_NL*`CX_FOMFEEDBACK_WD-1:0] cpcie_phy_cdm_ras_des_fomfeedback_g6;
wire    [`CX_NL*3-1:0]              cpcie_eqpa_violate_rule_123_g6;
wire    [`CX_NL-1:0]                cpcie_eqpa_violate_rule_4_g6;
wire    [`CX_NL*2-1:0]              cpcie_eq_convergence_sts_g6;
wire    [`CX_NL*`CX_TX_COEF_WD-1:0] cpcie_mac_cdm_ras_des_coef_rtx_g6;
wire    [`CX_NL-1:0]                cpcie_mac_cdm_ras_des_reject_rtx_g6;
wire                        xdlh_smlh_goto_detect_i;
wire    [4:0]               l0s_state;
wire                        cfg_polarity_mode;
wire                        cfg_rx_8_ts1s;
wire                        cfg_mux_lpbk_lanenum;
wire                        cfg_rate_chg_mode;
wire                        cfg_block_local_detect_eq_problem;
wire                        cfg_rxstandby_handshake_policy;
wire    [3:0]               cfg_p1_entry_policy;
wire                        cfg_por_phystatus_mode;
assign cfg_polarity_mode                 = cfg_lane_skew[1];
assign cfg_rx_8_ts1s                     = cfg_lane_skew[2];
assign cfg_mux_lpbk_lanenum              = cfg_lane_skew[5];
assign cfg_rate_chg_mode                 = cfg_lane_skew[7];
assign cfg_block_local_detect_eq_problem = cfg_lane_skew[8];

wire    [`CX_NL-1:0]        pl_rmlh_rpipe_rxskipremoved;
wire                        pl_smlh_clr_enter_compliance;     
wire                        pl_smlh_core_rst_n_release_pulse; 
wire                        pl_smlh_dir_spd_chg_rising_edge;  
wire                        pl_smlh_tx_margin_rst;            
wire                        pl_smlh_dir_linkw_chg_started;
wire                        pl_smlh_bw_mgt_status;
wire                        pl_smlh_link_auto_bw_status;
wire                        pl_smlh_timeout_nfts;
wire                        pl_smlh_l0_to_recovery;
wire                        pl_smlh_l1_to_recovery;
wire                        pl_smlh_rcv_eios_when_l0s_unsprt;
wire                        pl_smlh_deskew_uncomplete_err;
wire                        pl_smlh_lwd_change;
wire                        pl_smlh_spd_change;
 // from XMLH to CDM
wire                        pl_cdm_ras_des_einj0_enable;       // Error injection0 - CRC error enable
wire    [3:0]               pl_cdm_ras_des_einj0_crc_type;     // Error injection0 - CRC error type
wire                        pl_xmlh_einj0_oscrc_evt;           // Error injection0 - CRC error event
wire                        pl_cdm_ras_des_einj3_enable;      // Error injection3 - 8b/10b K-code mask enable
wire    [7:0]               pl_cdm_ras_des_einj3_count;       // Error injection3 - 8b/10b K-code mask count
wire    [2:0]               pl_cdm_ras_des_einj3_smb_type;    // Error injection3 - 8b/10b K-code mask type
wire    [1:0]               pl_xmlh_einj3_osmsk_evt;           // Error injection3 - 8b/10b K-code mask event
wire    [`CX_NL-1:0]        pl_smseq_ts1_rcvd_pulse_bus;
wire    [`CX_NL-1:0]        pl_smseq_ts2_rcvd_pulse_bus;
wire    [(`CX_NL*16)-1:0]   pl_smlh_margin_status;
wire    [`CX_NL-1:0]        pl_smlh_margin_status_valid;
logic   [`CX_NL-1:0]        rmlh_deskew_fltlog_ctrl_skp_mismatch_bus;
logic                       rmlh_deskew_fltlog_framing_err;
logic   [`CX_NL-1:0]        smseq_invalid_os_bus;
logic   [`CX_NL-1:0]        smseq_os_corrected_bus;
logic   [`CX_NL-1:0]        pl_int_os_corrected_bus;
logic   [`CX_NL-1:0]        pl_smseq_invalid_os_bus;
logic   [`CX_NL-1:0]        pl_smseq_os_corrected_bus;
logic   [`CX_NL-1:0]        pl_rmlh_deskew_fltlog_ctrl_skp_mismatch_bus;
logic                       pl_rmlh_deskew_fltlog_framing_err;

assign esm_current_rate = {6'b000000, 1'b1}; // {25gt, 20gt, 16gt, 8gt, 5gt, 2.5gt, non-esm}

// GEN1_LINK_SP must be supported at least
wire [3:0] max_link_speed;
wire [3:0] target_link_speed;
assign max_link_speed                = cfg_pcie_max_link_speed;
assign target_link_speed             = cfg_target_link_speed;

// must & with cfg_pcie_max_link_speed according to the ccix spec 2
wire [3:0] cfg_pcie_max_link_speed_i = max_link_speed;
// must & with cfg_target_link_speed according to the ccix spec 2. Then cfg_target_link_speed can drive speed change after initial esm rate linkup
wire [3:0] cfg_target_link_speed_i   = ( target_link_speed);

/*
wire [3:0] cfg_pcie_max_link_speed_i = `ifdef CX_CCIX_ESM_SUPPORT cfg_esm_mode_supt   ? (|esm_max_speed[6:5]    ? `GEN4_LINK_SP : |esm_max_speed[4:3]    ? `GEN3_LINK_SP : esm_max_speed[2]    ? `GEN2_LINK_SP : `GEN1_LINK_SP) : `endif cfg_pcie_max_link_speed;
wire [3:0] cfg_target_link_speed_i   = `ifdef CX_CCIX_ESM_SUPPORT smlh_initial_esm_linkup ? cfg_target_link_speed :  // drive speed change by cfg_target_link_speed after initial successful esm rate linkup
                                                                  cfg_ccix_esm_enable ? (|esm_target_speed[7:5] ? `GEN4_LINK_SP : |esm_target_speed[4:3] ? `GEN3_LINK_SP : esm_target_speed[2] ? `GEN2_LINK_SP : `GEN1_LINK_SP) : `endif cfg_target_link_speed;
*/

assign cfg_rxstandby_handshake_policy    = cfg_lane_skew[3];
assign cfg_por_phystatus_mode            = cfg_lane_skew[6];
assign cfg_p1_entry_policy               = cfg_lane_skew[12:9];
wire       cfg_link_retrain_i = cfg_link_retrain;
wire       cfg_perform_eq_i = cfg_perform_eq;

assign smlh_tx_precoding_on = smlh_precoding_on_latched;

reg latched_smlh_link_up;
always @( posedge core_clk or negedge core_rst_n ) begin : latched_smlh_link_up_PROC
    if ( ~core_rst_n )
        latched_smlh_link_up <= #`TP 1'b0;
    else if ( smlh_ltssm_state == S_DETECT_QUIET )
        latched_smlh_link_up <= #`TP 1'b0;
    else if ( ~(smlh_ltssm_state == S_LPBK_ENTRY || smlh_ltssm_state == S_LPBK_ACTIVE || smlh_ltssm_state == S_LPBK_EXIT || smlh_ltssm_state == S_LPBK_EXIT_TIMEOUT) && smlh_link_up )
        latched_smlh_link_up <= #`TP 1'b1;
end // latched_smlh_link_up_PROC

//--------------------------------------
// smlh Selector
//--------------------------------------

assign smlh_link_mode              = cpcie_smlh_link_mode;
assign smlh_link_txmode            = cpcie_smlh_link_mode;
assign smlh_link_rxmode            = cpcie_smlh_link_rxmode;
assign smlh_lanes_active           = cpcie_smlh_lanes_active;
assign smlh_txlanes_active         = cpcie_smlh_lanes_active;
assign smlh_rxlanes_active         = cpcie_smlh_lanes_active;
assign smlh_no_turnoff_lanes       = cpcie_smlh_no_turnoff_lanes;
assign smlh_lnknum_match_dis       = cpcie_smlh_lnknum_match_dis;
assign smlh_link_up                = cpcie_smlh_link_up_o;
assign smlh_req_rst_not            = cpcie_smlh_req_rst_not_o;
assign smlh_scrambler_disable      = cpcie_smlh_scrambler_disable;
assign smlh_ltssm_in_pollconfig    = cpcie_smlh_ltssm_in_pollconfig;
assign smlh_training_rst_n         = cpcie_smlh_training_rst_n;
assign smlh_link_disable           = cpcie_smlh_link_disable;
assign smlh_link_in_training       = cpcie_smlh_link_in_training;
assign pl_smlh_bw_mgt_status       = cpcie_smlh_bw_mgt_status;
assign pl_smlh_link_auto_bw_status = cpcie_smlh_link_auto_bw_status;
assign smlh_ltssm_next             = cpcie_smlh_ltssm_next;
assign deskew_lanes_active         = cpcie_deskew_lanes_active;
assign tmp_mac_phy_txdetectrx_loopback = cpcie_mac_phy_txdetectrx_loopback;
assign tmp_mac_phy_txcompliance        = cpcie_mac_phy_txcompliance;
assign tmp_int_mac_phy_rate            = cpcie_mac_phy_rate;
assign tmp_mac_phy_rxpolarity          = cpcie_mac_phy_rxpolarity;
assign tmp_mac_phy_rxstandby           = cpcie_mac_phy_rxstandby;
assign smlh_set_rxstandby              = cpcie_smlh_set_rxstandby;
assign tmp_mac_phy_txdeemph            = cpcie_mac_phy_txdeemph;
assign tmp_mac_phy_txmargin            = cpcie_mac_phy_txmargin;
assign tmp_mac_phy_txswing             = cpcie_mac_phy_txswing;
assign pl_smlh_clr_enter_compliance   = cpcie_smlh_clr_enter_compliance;
assign pl_smlh_tx_margin_rst          = cpcie_smlh_tx_margin_rst;
assign smlh_successful_spd_negotiation = cpcie_smlh_successful_spd_negotiation;
assign pl_smlh_core_rst_n_release_pulse = cpcie_smlh_core_rst_n_release_pulse;
assign pl_smlh_dir_spd_chg_rising_edge = cpcie_smlh_dir_spd_chg_rising_edge;
assign smlh_mcs_rcvd               = cpcie_smlh_mcs_rcvd;
assign smseq_loc_eies_rcvd_bus     = cpcie_smseq_loc_eies_rcvd_bus;
assign tmp_mac_phy_pam4_restricted_levels = cpcie_mac_phy_pam4_restricted_levels;
assign pl_smlh_dir_linkw_chg_started  = cpcie_smlh_dir_linkw_chg_started;
assign smlh_ltssm_in_hotrst_dis_entry = cpcie_smlh_ltssm_in_hotrst_dis_entry;
assign pl_smseq_ts1_rcvd_pulse_bus = cpcie_smseq_ts1_rcvd_pulse_bus;
assign pl_smseq_ts2_rcvd_pulse_bus = cpcie_smseq_ts2_rcvd_pulse_bus;
assign smseq_loc_ts2_rcvd_bus      = cpcie_smseq_loc_ts2_rcvd_bus;
assign smseq_in_skp_bus            = cpcie_smseq_in_skp_bus;
assign smseq_fts_skp_do_deskew_bus = cpcie_smseq_fts_skp_do_deskew_bus;
assign smlh_ltssm_in_compliance    = cpcie_smlh_ltssm_in_compliance;
assign smlh_ltssm_in_rcvrylock     = cpcie_smlh_ltssm_in_rcvrylock;
assign smlh_ltssm_in_detectquiet   = cpcie_smlh_ltssm_in_detectquiet;
assign ltssm_cmd_send_eieos_for_pset_map = cpcie_ltssm_cmd_send_eieos_for_pset_map;
assign ltssm_usp_eq_redo           = cpcie_ltssm_usp_eq_redo;
assign smlh_ls2_eq_req             = cpcie_smlh_ls2_eq_req;
assign smlh_ls2_eq_success         = cpcie_smlh_ls2_eq_success;
assign smlh_ls2_eq_cmpl            = cpcie_smlh_ls2_eq_cmpl;
assign smlh_ls2_eq_enter           = cpcie_smlh_ls2_eq_enter;
assign smlh_eq_pending             = cpcie_smlh_eq_pending;
wire smlh_auto_eq_dllp_blocking;     // Equalization Pending because of autonomous mechanism
assign smlh_auto_eq_dllp_blocking  = cpcie_smlh_auto_eq_dllp_blocking;
assign tmp_smlh_lec_pset_ltx           = cpcie_smlh_lec_pset_ltx;
assign tmp_smlh_lec_pset_lrx           = cpcie_smlh_lec_pset_lrx;
assign smlh_ltssm_state_rcvry_eq   = cpcie_smlh_ltssm_state_rcvry_eq_o;
assign smlh_gen3_error_count       = cpcie_smlh_gen3_error_count;
assign pm_current_data_rate_others = pm_current_data_rate_others_o;
assign smlh_ls2_g4_eq_req          = cpcie_smlh_ls2_g4_eq_req;
assign smlh_ls2_g4_eq_success      = cpcie_smlh_ls2_g4_eq_success;
assign smlh_ls2_g4_eq_cmpl         = cpcie_smlh_ls2_g4_eq_cmpl;
assign smlh_ls2_g4_eq_enter        = cpcie_smlh_ls2_g4_eq_enter;
assign tmp_smlh_lec_g4_pset_ltx        = cpcie_smlh_lec_g4_pset_ltx;
assign smlh_lec_g4_pset_lrx        = cpcie_smlh_lec_g4_pset_lrx;
assign smlh_retimer_pre_detected   = cpcie_smlh_retimer_pre_detected;
assign smlh_ls2_g5_eq_req          = cpcie_smlh_ls2_g5_eq_req;
assign smlh_ls2_g5_eq_success      = cpcie_smlh_ls2_g5_eq_success;
assign smlh_ls2_g5_eq_cmpl         = cpcie_smlh_ls2_g5_eq_cmpl;
assign smlh_ls2_g5_eq_enter        = cpcie_smlh_ls2_g5_eq_enter;
assign tmp_smlh_lec_g5_pset_ltx        = cpcie_smlh_lec_g5_pset_ltx;
assign smlh_lec_g5_pset_lrx        = cpcie_smlh_lec_g5_pset_lrx;
assign active_nb                   = cpcie_active_nb;
assign active_nb_gen34             = cpcie_active_nb_gen34;
assign smlh_do_deskew              = cpcie_smlh_do_deskew;
assign smlh_ltssm_state            = cpcie_smlh_ltssm_state;
assign smlh_in_l0s                 = cpcie_smlh_in_l0s;
assign smlh_in_rl0s                = cpcie_smlh_in_rl0s;
assign smlh_in_l0                  = cpcie_smlh_in_l0;
assign smlh_in_l1                  = cpcie_smlh_in_l1;
assign smlh_in_l23                 = cpcie_smlh_in_l23;
assign smlh_l123_eidle_timeout     = cpcie_smlh_l123_eidle_timeout;
assign smlh_ts_link_ctrl           = cpcie_smlh_ts_link_ctrl;
assign smlh_rcvd_lane_rev          = cpcie_smlh_rcvd_lane_rev;
assign smlh_ts_link_num            = cpcie_smlh_ts_link_num;
assign smlh_ts_link_num_is_k237    = cpcie_smlh_ts_link_num_is_k237;
assign smlh_lanes_rcving           = cpcie_smlh_lanes_rcving;
assign smlh_ts_rcv_err             = cpcie_smlh_ts_rcv_err;
assign smlh_ts1_rcvd               = cpcie_smlh_ts1_rcvd;
assign smlh_ts2_rcvd               = cpcie_smlh_ts2_rcvd;
assign smlh_inskip_rcv             = cpcie_smlh_inskip_rcv;
assign smlh_ts_lane_num_is_k237    = cpcie_smlh_ts_lane_num_is_k237;
assign latched_rcvd_eidle_set      = cpcie_latched_rcvd_eidle_set;
assign ltssm_rcvr_err_rpt_en       = cpcie_ltssm_rcvr_err_rpt_en;
assign ltssm_clear                 = cpcie_ltssm_clear;
assign ltssm_cmd                   = cpcie_ltssm_cmd;
assign tmp_smlh_eqpa_txdeemph          = cpcie_smlh_eqpa_txdeemph;
assign smlh_blockaligncontrol          = cpcie_smlh_blockaligncontrol;
assign tmp_mac_phy_rxpresethint        = cpcie_mac_phy_rxpresethint;
assign tmp_mac_phy_fs                  = cpcie_mac_phy_fs;
assign tmp_mac_phy_lf                  = cpcie_mac_phy_lf;
assign tmp_mac_phy_getlocal_pset_coef  = cpcie_mac_phy_getlocal_pset_coef;
assign tmp_mac_phy_local_pset_index    = cpcie_mac_phy_local_pset_index;
assign tmp_mac_phy_rxeqinprogress      = cpcie_mac_phy_rxeqinprogress;
assign tmp_mac_phy_invalid_req         = cpcie_mac_phy_invalid_req;
assign tmp_mac_phy_rxeqeval            = cpcie_mac_phy_rxeqeval;
assign tmp_mac_phy_dirchange           = cpcie_mac_phy_dirchange;
assign tmp_mac_phy_smlh_coef_rtx       = cpcie_mac_phy_smlh_coef_rtx;
assign ltssm_powerdown             = cpcie_ltssm_powerdown;
assign ltssm_lpbk_master           = cpcie_ltssm_lpbk_master;
assign ltssm_ts_cnt_en             = cpcie_ltssm_ts_cnt_en;
assign ltssm_ts_cnt_rst            = cpcie_ltssm_ts_cnt_rst;
assign ltssm_ts_data_rate          = cpcie_ltssm_ts_data_rate;
assign ltssm_ts_data_rate_eg6      = cpcie_ltssm_ts_data_rate_eg6;
assign latched_ts_data_rate_eg6    = cpcie_latched_ts_data_rate_eg6;
assign ltssm_ts_speed_change       = cpcie_ltssm_ts_speed_change;
assign latched_ts_data_rate        = cpcie_latched_ts_data_rate;
assign ltssm_ts_auto_change        = cpcie_ltssm_ts_auto_change;
assign ltssm_xlinknum              = cpcie_ltssm_xlinknum;
assign ltssm_xk237_4lannum         = cpcie_ltssm_xk237_4lannum;
assign ltssm_xk237_4lnknum         = cpcie_ltssm_xk237_4lnknum;
assign ltssm_ts_cntrl              = cpcie_ltssm_ts_cntrl;
assign ltssm_in_lpbk               = cpcie_ltssm_in_lpbk;
assign ltssm_eidle_cnt             = {1'b0, cpcie_ltssm_eidle_cnt};
assign ltssm_in_lpbkentry          = cpcie_ltssm_in_lpbkentry;
assign eqctl_eqts_info             = cpcie_eqctl_eqts_info;
assign eqctl_mask_eieos            = cpcie_eqctl_mask_eieos;
assign eqctl_2mask_eieos_pulse     = cpcie_eqctl_2mask_eieos_pulse;
assign eqctl_pset_ltx              = cpcie_eqctl_pset_ltx;
assign muxed_n_fts                 = cpcie_muxed_n_fts;
assign latched_ts_nfts             = cpcie_latched_ts_nfts;
assign cxpl_debug_info_ei          = cpcie_cxpl_debug_info_ei;
assign smlh_lane_flip_ctrl         = cpcie_smlh_lane_flip_ctrl;
assign ltssm_lane_flip_ctrl        = cpcie_ltssm_lane_flip_ctrl;
assign l0s_state                   = cpcie_l0s_state;
assign smlh_eidle_inferred_in_l0   = cpcie_smlh_eidle_inferred_in_l0;
assign smlh_rx_rcvry_req           = cpcie_smlh_rx_rcvry_req;
assign pl_smlh_timeout_nfts        = cpcie_smlh_timeout_nfts;
assign pl_smlh_l0_to_recovery      = cpcie_smlh_l0_to_recovery;
assign pl_smlh_l1_to_recovery      = cpcie_smlh_l1_to_recovery;
assign pl_smlh_rcv_eios_when_l0s_unsprt = cpcie_smlh_rcv_eios_when_l0s_unsprt;
assign pl_smlh_deskew_uncomplete_err    = cpcie_smlh_deskew_uncomplete_err;
assign pl_smlh_spd_change          = cpcie_smlh_spd_change;
assign smseq_mcs_sts               = cpcie_smseq_mcs_sts;
assign pl_smlh_lwd_change          = cpcie_smlh_lwd_change;
assign smlh_ltssm_variable         = cpcie_smlh_ltssm_variable;
assign smseq_ts_debug_info         = cpcie_smseq_ts_debug_info;
assign smlh_rxos_type              = cpcie_smlh_rxos_type;
assign init_eq_pending             = cpcie_init_eq_pending;
assign mac_cdm_ras_des_fs          = cpcie_mac_cdm_ras_des_fs;
assign mac_cdm_ras_des_lf          = cpcie_mac_cdm_ras_des_lf;
assign mac_cdm_ras_des_coef_ltx    = cpcie_mac_cdm_ras_des_coef_ltx;
assign phy_cdm_ras_des_fomfeedback = cpcie_phy_cdm_ras_des_fomfeedback;
assign eqpa_violate_rule_123       = cpcie_eqpa_violate_rule_123;
assign eq_convergence_sts          = cpcie_eq_convergence_sts;
assign mac_cdm_ras_des_coef_rtx    = cpcie_mac_cdm_ras_des_coef_rtx;
assign mac_cdm_ras_des_pset_lrx    = cpcie_mac_cdm_ras_des_pset_lrx;
assign mac_cdm_ras_des_reject_rtx  = cpcie_mac_cdm_ras_des_reject_rtx;
assign init_eq_pending_g4          = cpcie_init_eq_pending_g4;
assign mac_cdm_ras_des_fs_g4       = cpcie_mac_cdm_ras_des_fs_g4;
assign mac_cdm_ras_des_lf_g4       = cpcie_mac_cdm_ras_des_lf_g4;
assign mac_cdm_ras_des_coef_ltx_g4 = cpcie_mac_cdm_ras_des_coef_ltx_g4;
assign phy_cdm_ras_des_fomfeedback_g4 = cpcie_phy_cdm_ras_des_fomfeedback_g4;
assign eqpa_violate_rule_123_g4    = cpcie_eqpa_violate_rule_123_g4;
assign eq_convergence_sts_g4       = cpcie_eq_convergence_sts_g4;
assign mac_cdm_ras_des_coef_rtx_g4 = cpcie_mac_cdm_ras_des_coef_rtx_g4;
assign mac_cdm_ras_des_reject_rtx_g4 = cpcie_mac_cdm_ras_des_reject_rtx_g4;
assign init_eq_pending_g5          = cpcie_init_eq_pending_g5;
assign mac_cdm_ras_des_fs_g5       = cpcie_mac_cdm_ras_des_fs_g5;
assign mac_cdm_ras_des_lf_g5       = cpcie_mac_cdm_ras_des_lf_g5;
assign mac_cdm_ras_des_coef_ltx_g5 = cpcie_mac_cdm_ras_des_coef_ltx_g5;
assign phy_cdm_ras_des_fomfeedback_g5 = cpcie_phy_cdm_ras_des_fomfeedback_g5;
assign eqpa_violate_rule_123_g5    = cpcie_eqpa_violate_rule_123_g5;
assign eq_convergence_sts_g5       = cpcie_eq_convergence_sts_g5;
assign mac_cdm_ras_des_coef_rtx_g5 = cpcie_mac_cdm_ras_des_coef_rtx_g5;
assign mac_cdm_ras_des_reject_rtx_g5 = cpcie_mac_cdm_ras_des_reject_rtx_g5;
assign init_eq_pending_g6          = cpcie_init_eq_pending_g6;
assign mac_cdm_ras_des_fs_g6       = cpcie_mac_cdm_ras_des_fs_g6;
assign mac_cdm_ras_des_lf_g6       = cpcie_mac_cdm_ras_des_lf_g6;
assign mac_cdm_ras_des_coef_ltx_g6 = cpcie_mac_cdm_ras_des_coef_ltx_g6;
assign phy_cdm_ras_des_fomfeedback_g6 = cpcie_phy_cdm_ras_des_fomfeedback_g6;
assign eqpa_violate_rule_123_g6    = cpcie_eqpa_violate_rule_123_g6;
assign eqpa_violate_rule_4_g6      = cpcie_eqpa_violate_rule_4_g6;
assign eq_convergence_sts_g6       = cpcie_eq_convergence_sts_g6;
assign mac_cdm_ras_des_coef_rtx_g6 = cpcie_mac_cdm_ras_des_coef_rtx_g6;
assign mac_cdm_ras_des_reject_rtx_g6 = cpcie_mac_cdm_ras_des_reject_rtx_g6;


assign rl0s_state                  = l0s_state[1:0];
assign xdlh_smlh_goto_detect_i = xdlh_smlh_goto_detect || xplh_req_link_down ;

// For Layer1 power saving and clock gating(STAR#9000936068)
wire                   ltssm_in_config;
wire   [`CX_NL-1:0]        power_saving_txlanes_active;
wire   [`CX_NL-1:0]        power_saving_rxlanes_active;
assign ltssm_in_config = (smlh_ltssm_state==S_CFG_LINKWD_START) || 
                         (smlh_ltssm_state==S_CFG_LINKWD_ACEPT) ||
                         (smlh_ltssm_state==S_CFG_LANENUM_WAIT) ||
                         (smlh_ltssm_state==S_CFG_LANENUM_ACEPT) ||
                         (smlh_ltssm_state==S_CFG_COMPLETE) ||
                         (smlh_ltssm_state==S_CFG_IDLE);

  // When LTSSM in config state, all lanes have to be active  for upconfigure.
assign power_saving_txlanes_active = smlh_txlanes_active | {`CX_NL{ltssm_in_config}};
assign power_saving_rxlanes_active = smlh_rxlanes_active | {`CX_NL{ltssm_in_config}};
// END(STAR#9000936068)

assign pl_int_os_corrected_bus = tmp_os_corrected | pl_smseq_os_corrected_bus;

always @ (posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
        rmlh_cdm_flit_logging_interface.rmlh_mismatch_SKP_OS      <= #`TP '0;
        rmlh_cdm_flit_logging_interface.rmlh_framing_error        <= #`TP '0;
        smlh_cdm_flit_logging_interface.smlh_invalid_ordered_set  <= #`TP '0;
        smlh_cdm_flit_logging_interface.smlh_corr_ordered_set     <= #`TP '0;
    end 
    else if( ~smlh_flit_mode_enable_modules[0] ) begin
        rmlh_cdm_flit_logging_interface.rmlh_mismatch_SKP_OS      <= #`TP '0;
        rmlh_cdm_flit_logging_interface.rmlh_framing_error        <= #`TP '0;
        smlh_cdm_flit_logging_interface.smlh_invalid_ordered_set  <= #`TP '0;
        smlh_cdm_flit_logging_interface.smlh_corr_ordered_set     <= #`TP '0;
    end
    else begin
        rmlh_cdm_flit_logging_interface.rmlh_mismatch_SKP_OS      <= #`TP $bits(rmlh_cdm_flit_logging_interface.rmlh_mismatch_SKP_OS)'( smlh_lanes_active & rmlh_deskew_fltlog_ctrl_skp_mismatch_bus ) ;
        rmlh_cdm_flit_logging_interface.rmlh_framing_error        <= #`TP rmlh_deskew_fltlog_framing_err ;
        smlh_cdm_flit_logging_interface.smlh_corr_ordered_set     <= #`TP |(smlh_lanes_active & smseq_os_corrected_bus) ;
    end
end



// LTSSM timers routed to the top-level for verification usage
localparam T_WD = 25; // timer bit width
wire    [T_WD-1:0]              smlh_freq_multiplier;
wire    [T_WD-1:0]              smlh_fast_time_1ms;
wire    [T_WD-1:0]              smlh_fast_time_2ms;
wire    [T_WD-1:0]              smlh_fast_time_3ms;
wire    [T_WD-1:0]              smlh_fast_time_4ms;
wire    [T_WD-1:0]              smlh_fast_time_10ms;
wire    [T_WD-1:0]              smlh_fast_time_12ms;
wire    [T_WD-1:0]              smlh_fast_time_24ms;
wire    [T_WD-1:0]              smlh_fast_time_32ms;
wire    [T_WD-1:0]              smlh_fast_time_48ms;
wire    [T_WD-1:0]              smlh_fast_time_64ms;
wire    [T_WD-1:0]              smlh_fast_time_100ms;

// spyglass disable_block W486
// SMD: Reports shift overflow operations
// SJ: Maximum value of CX_FAST_TIME_xxx is 21'h800. Overflow does not occur even if the value is shifted by 6 bits.
// de-reference LTSSM timeouts in fast link mode from cxpl_defs.vh
assign smlh_freq_multiplier = `CX_PL_FREQ_MULTIPLIER;
// Note: In ltssm_in_config state on USP for MAC=16s PHY=4s configs, 1ms is not enough to correctly decide Link width in simulation.
assign smlh_fast_time_1ms   = (cfg_fast_link_scaling_factor==2'b00) ? (ltssm_in_config || (smlh_ltssm_state == S_LPBK_ENTRY)) ? ((`CX_FAST_TIME_1MS << 1)) :  `CX_FAST_TIME_1MS :
                              (cfg_fast_link_scaling_factor==2'b01) ? (`CX_FAST_TIME_1MS << 2) :
                              (cfg_fast_link_scaling_factor==2'b10) ? (`CX_FAST_TIME_1MS << 4) :
                                                                      (`CX_FAST_TIME_1MS << 6) ;
// Note: In config state, 1us is not enough to correctly decide Link width in simulation.
assign smlh_fast_time_2ms   = (cfg_fast_link_scaling_factor==2'b00) ? (ltssm_in_config || (smlh_ltssm_state == S_LPBK_ENTRY) || smlh_ltssm_state == S_L123_SEND_EIDLE) ? (`CX_FAST_TIME_2MS << 1) : `CX_FAST_TIME_2MS :
                              (cfg_fast_link_scaling_factor==2'b01) ? (`CX_FAST_TIME_2MS << 2) :
                              (cfg_fast_link_scaling_factor==2'b10) ? (`CX_FAST_TIME_2MS << 4) :
                                                                      (`CX_FAST_TIME_2MS << 6) ;
// Note: Generic PHY could take more than 2us for PHYSTATUS response for P1/P2 entry. Internal LTSSM timeout (2ms) in S_L123_SEND_EIDLE should be more than that.
// Note: In config state, 1us is not enough to correctly decide Link width in simulation. Need to extend 2ms timer as well.
assign smlh_fast_time_3ms   = (cfg_fast_link_scaling_factor==2'b00) ? (ltssm_in_config) ? (`CX_FAST_TIME_3MS << 1) : `CX_FAST_TIME_3MS :
                              (cfg_fast_link_scaling_factor==2'b01) ? (`CX_FAST_TIME_3MS << 2) :
                              (cfg_fast_link_scaling_factor==2'b10) ? (`CX_FAST_TIME_3MS << 4) :
                                                                      (`CX_FAST_TIME_3MS << 6) ;
// Note: In config state, 1us is not enough to correctly decide Link width in simulation. Need to extend 3ms timer as well.
assign smlh_fast_time_4ms   = (cfg_fast_link_scaling_factor==2'b00) ? `CX_FAST_TIME_4MS :
                              (cfg_fast_link_scaling_factor==2'b01) ? (`CX_FAST_TIME_4MS << 2) :
                              (cfg_fast_link_scaling_factor==2'b10) ? (`CX_FAST_TIME_4MS << 4) :
                                                                      (`CX_FAST_TIME_4MS << 6) ;
assign smlh_fast_time_10ms  = (cfg_fast_link_scaling_factor==2'b00) ? `CX_FAST_TIME_10MS :
                              (cfg_fast_link_scaling_factor==2'b01) ? (`CX_FAST_TIME_10MS << 2) :
                              (cfg_fast_link_scaling_factor==2'b10) ? (`CX_FAST_TIME_10MS << 4) :
                                                                      (`CX_FAST_TIME_10MS << 6) ;
assign smlh_fast_time_12ms  = (cfg_fast_link_scaling_factor==2'b00) ? `CX_FAST_TIME_12MS :
                              (cfg_fast_link_scaling_factor==2'b01) ? (`CX_FAST_TIME_12MS << 2) :
                              (cfg_fast_link_scaling_factor==2'b10) ? (`CX_FAST_TIME_12MS << 4) :
                                                                      (`CX_FAST_TIME_12MS << 6) ;
assign smlh_fast_time_24ms  = (cfg_fast_link_scaling_factor==2'b00) ? `CX_FAST_TIME_24MS :
                              (cfg_fast_link_scaling_factor==2'b01) ? (`CX_FAST_TIME_24MS << 2) :
                              (cfg_fast_link_scaling_factor==2'b10) ? (`CX_FAST_TIME_24MS << 4) :
                                                                      (`CX_FAST_TIME_24MS << 6) ;
assign smlh_fast_time_32ms  = (cfg_fast_link_scaling_factor==2'b00) ? `CX_FAST_TIME_32MS :
                              (cfg_fast_link_scaling_factor==2'b01) ? (`CX_FAST_TIME_32MS << 2) :
                              (cfg_fast_link_scaling_factor==2'b10) ? (`CX_FAST_TIME_32MS << 4) :
                                                                      (`CX_FAST_TIME_32MS << 6) ;
assign smlh_fast_time_48ms  = (cfg_fast_link_scaling_factor==2'b00) ? `CX_FAST_TIME_48MS :
                              (cfg_fast_link_scaling_factor==2'b01) ? (`CX_FAST_TIME_48MS << 2) :
                              (cfg_fast_link_scaling_factor==2'b10) ? (`CX_FAST_TIME_48MS << 4) :
                                                                      (`CX_FAST_TIME_48MS << 6) ;
assign smlh_fast_time_64ms  = (cfg_fast_link_scaling_factor==2'b00) ? `CX_FAST_TIME_64MS :
                              (cfg_fast_link_scaling_factor==2'b01) ? (`CX_FAST_TIME_64MS << 2) :
                              (cfg_fast_link_scaling_factor==2'b10) ? (`CX_FAST_TIME_64MS << 4) :
                                                                      (`CX_FAST_TIME_64MS << 6) ;
assign smlh_fast_time_100ms = (cfg_fast_link_scaling_factor==2'b00) ? `CX_FAST_TIME_100MS :
                              (cfg_fast_link_scaling_factor==2'b01) ? (`CX_FAST_TIME_100MS << 2) :
                              (cfg_fast_link_scaling_factor==2'b10) ? (`CX_FAST_TIME_100MS << 4) :
                                                                      (`CX_FAST_TIME_100MS << 6) ;
// spyglass enable_block W486



//================================================================================================================//

assign xmlh_cmd_if_lp_ack = smlh_protocol_cfg.spif_enable ? pm_block_tlp_ack : int_xmlh_cmd_if_lp_ack;

// ----------------------------------------------------------------------------
// Packet Layer State Management (SPLH) instantiation
// ----------------------------------------------------------------------------
splh
 u_splh (
    .b_smlh_spif           ( b_smlh_spif.smlh_slave_mp  ),
    .b_xplh_spif           ( b_xplh_spif.xplh_slave_mp  ),
    .b_rplh_spif           ( b_rplh_spif.rplh_slave_mp  ),
    .b_splh_spif           ( b_splh_spif                ),
    .core_clk              ( core_clk                   ),
    .core_rst_n            ( core_rst_n                 ),
    .xplh_linkerror        ( xplh_linkerror             ),
    .xplh_splh_cmd_ack     ( xplh_splh_cmd_ack          ), // Command Complete Acknowledge from XPLH to SPLH
    .splh_xplh_cmd         ( splh_xplh_cmd              ), // Command from SPLH to XPLH
    .xplh_xmlh_cmd_ack     ( xplh_xmlh_cmd_ack          ), // Command Complete Acknowledge from XPLH to XMLH
    .xmlh_xplh_cmd         ( xmlh_xplh_cmd              ), // Command from XMLH to XPLH
    .splh_cmd_if_pmreq_ack ( splh_cmd_if_pmreq_ack      ),
    .splh_cmd_if_stall_ack ( splh_cmd_if_stall_ack      ),
    .splh_cmd_if_pending   ( splh_cmd_if_pending        ),
    .splh_pm_req_l0s       ( splh_pm_req_l0s            ),
    .splh_pm_req_l1        ( splh_pm_req_l1             ),
    .splh_pm_req_l2        ( splh_pm_req_l2             ),
    .pl_protocol_cfg       ( splh_protocol_cfg          )
);

wire rplh_cxl_eds_err;

 wire                        ltssm_in_lpbk_active;
 // When LTSSM in lpbk_active or lpbk_exit state, all lanes in freq_step have to be active for latency b/w ltssm and freq_step.
 assign ltssm_in_lpbk_active = (smlh_ltssm_state==S_LPBK_ACTIVE) || (smlh_ltssm_state==S_LPBK_EXIT);

wire [1:0]           ltssm_cxl_ll_mod;            // low latency mode {driftbuffer, commonclock}
wire                 cfg_elastic_buffer_mode_i;

assign s_rplh_rmlh_pkt_err = rplh_rmlh_pkt_err;
assign cfg_elastic_buffer_mode_i  = cfg_elastic_buffer_mode;


// Layer 1 Receive
rmlh

#(INST) u_rmlh(
    .pm_block_phystatus                 (pl_pm_block_phystatus),
    .core_clk                           (core_clk),
    .core_clk_ug                        (core_clk_ug),
    .core_rst_n                         (core_rst_n),
    .cfg_deskew_disable                 (cfg_deskew_disable),
    .cfg_ts2_lid_deskew                 (cfg_ts2_lid_deskew),
    .cfg_fast_link_mode                 (cfg_fast_link_mode),
    .cfg_elastic_buffer_mode            (cfg_elastic_buffer_mode_i),
    .cfg_pipe_garbage_data_mode         (cfg_pipe_garbage_data_mode),
    .latched_smlh_link_up               (latched_smlh_link_up),
    .smlh_in_rl0s                       (smlh_in_rl0s),
    .latched_flip_ctrl                  (latched_flip_ctrl),
    .smlh_lane_flip_ctrl                (cpcie_ltssm_lane_flip_ctrl),
    .smlh_flit_mode_enable              (smlh_flit_mode_enable_modules[0]),
    .ltssm_l0p_lanes_active             (ltssm_l0p_lanes_active),
    .ltssm_l0p_last_lanes_active        (ltssm_l0p_last_lanes_active),
    .ltssm_l0p_next_link_mode           (smlh_l0p_next_link_mode),
    .ltssm_in_l0p                       (smlh_ltssm_in_l0p),
    .ltssm_in_l0p_upsize                (smlh_ltssm_in_l0p_upsize),
    .xmtbyte_l0p_link_in_training       (xmtbyte_l0p_link_in_training),
    .xmtbyte_l0p_ts2_sent               (xmtbyte_l0p_ts2_sent),
    .l0p_sris_mode_enabled              (xmtbyte_l0p_sris_mode_enabled),
    .smlh_link_mode                     (smlh_link_rxmode),
    .smlh_no_turnoff_lanes              (smlh_no_turnoff_lanes),
    .smlh_lanes_active                  (smlh_lanes_active),
    .power_saving_lanes_active          (power_saving_rxlanes_active),
    .deskew_lanes_active                (deskew_lanes_active),
    .smlh_do_deskew                     (smlh_do_deskew),
    .smlh_lnknum_match_dis              (smlh_lnknum_match_dis),
    .smlh_link_up                       (smlh_link_up),
    .smlh_link_in_training              (smlh_link_in_training),
    .smlh_scrambler_disable             (smlh_scrambler_disable),
    .smlh_ltssm_in_pollconfig           (smlh_ltssm_in_pollconfig),
    .smlh_ltssm_state_wire              (smlh_ltssm_state_wire),
    .smlh_ltssm_last                    (smlh_ltssm_last),
    .ltssm_in_lpbk_active               (ltssm_in_lpbk_active),
    .smlh_successful_spd_negotiation    (smlh_successful_spd_negotiation),
    .smseq_loc_eies_rcvd_bus            (smseq_loc_eies_rcvd_bus),
    .smseq_ts1_rcvd_pulse_bus           (pl_smseq_ts1_rcvd_pulse_bus),
    .smseq_ts2_rcvd_pulse_bus           (pl_smseq_ts2_rcvd_pulse_bus),
    .smseq_loc_ts2_rcvd_bus             (smseq_loc_ts2_rcvd_bus),
    .smseq_in_skp_bus                   (smseq_in_skp_bus),
    .smseq_fts_skp_do_deskew_bus        (smseq_fts_skp_do_deskew_bus),
    .ltssm_rcvr_err_rpt_en              (ltssm_rcvr_err_rpt_en),
    .ltssm_powerdown                    (ltssm_powerdown),
    .ltssm_cxl_ll_mod                   (ltssm_cxl_ll_mod),
    .drift_buffer_deskew_enable         (cfg_drift_buffer_deskew_enable),
    .drift_buffer_deskew_ptr            (drift_buffer_deskew_ptr),
    .ltssm_lpbk_master                  (ltssm_lpbk_master),

    .phy_mac_rxdata                     (in_cxpl_phy_mac_rxdata),
    .phy_mac_rxdatak                    (in_cxpl_phy_mac_rxdatak),
    .phy_mac_rxvalid                    (in_cxpl_phy_mac_rxvalid),
    .phy_mac_rxstatus                   (in_cxpl_phy_mac_rxstatus),
    .phy_mac_rxelecidle                 (in_cxpl_phy_mac_rxelecidle),
    .phy_mac_phystatus                  (in_cxpl_phy_mac_phystatus),
    .phy_mac_margin_status              (tmp_phy_mac_margin_status),
    .phy_mac_margin_nak                 (tmp_phy_mac_margin_nak),
    .phy_mac_margin_error_cnt           (tmp_phy_mac_margin_error_cnt),
    .phy_mac_margin_sampl_cnt           (tmp_phy_mac_margin_sampl_cnt),
    .ltssm_clear                        (ltssm_clear),
    .active_nb_wire                     (active_nb_wire),
    .rplh_rmlh_pkt_err                  (s_rplh_rmlh_pkt_err),
    .rplh_rmlh_pkt_err_ptr              (rplh_rmlh_pkt_err_ptr),
    .active_nb_gen34                    (active_nb_gen34),
    .cfg_no_seed_value_change           (cfg_no_seed_value_change),
    .cxl_mode_enable                    (cxl_link_enable),
    .rplh_cxl_corr_pid_err              (rplh_cxl_corr_pid_err),
    .rplh_cxl_uncorr_pid_err            (rplh_cxl_uncorr_pid_err),
    .rplh_cxl_unexp_pid_err             (rplh_cxl_unexp_pid_err),
    .rplh_cxl_eds_err                   (rplh_cxl_eds_err),
    .mac_phy_rate                       (tmp_int_mac_phy_rate),
    .phy_mac_rxdatavalid                (tmp_phy_mac_rxdatavalid),
    .phy_mac_rxstartblock               (tmp_phy_mac_rxstartblock),
    .phy_mac_rxsyncheader               (tmp_phy_mac_rxsyncheader),
    .cfg_gen3_scrambler_disable         (cfg_pl_gen3_control[0]),
    .cfg_gen3_dc_balance_disable        (cfg_pl_gen3_control[7]),
    .cfg_enter_compliance               (cfg_enter_compliance),
    .smlh_ltssm_in_compliance           (smlh_ltssm_in_compliance),
    .smlh_ltssm_in_rcvrylock            (smlh_ltssm_in_rcvrylock),
    .phy_mac_rxdata_osfound             (tmp_rxdata_osfound),
    .cfg_tx_precode_req                 (smlh_deprecode_on),
    .cdm_ras_des_ferr_rec_dis           (cdm_ras_des_ferr_rec_dis),
    .cdm_ras_des_force_rxdetected_en    (cdm_ras_des_force_rxdetected_en),
    .cdm_ras_des_force_rxdetected       (tmp_cdm_ras_des_force_rxdetected),
    .pm_current_data_rate               (pm_current_data_rate),
    .pre_mac_phy_cclk_rate              (adapted_pipe_mac_phy_cclk_rate),

// ---- outputs ---------------
    .current_data_rate                  (current_data_rate),
    .current_cclk_rate                  (current_cclk_rate),
    .pm_current_data_rate_others        (pm_current_data_rate_others_int),
    .pm_current_data_rate_xmlh_xmt      (pm_current_data_rate_xmlh_xmt),
    .pm_current_data_rate_xmlh_scr      (pm_current_data_rate_xmlh_scr),
    .pm_current_data_rate_rplh_pkf      (pm_current_data_rate_rplh_pkf),
    .pm_current_data_rate_smlh_sqf      (pm_current_data_rate_smlh_sqf),
    .pm_current_data_rate_smlh_lnk      (pm_current_data_rate_smlh_lnk),
    .pm_current_data_rate_smlh_eq       (pm_current_data_rate_smlh_eq),
    .pm_current_data_rate_ltssm         (pm_current_data_rate_ltssm),
    .current_powerdown                  (current_powerdown),
    .rpipe_rxdata                       (rpipe_rxdata),
    .rpipe_rxdatak                      (rpipe_rxdatak),
    .rpipe_rxerror_dup                  (rpipe_rxerror_dup),
    .rpipe_rxdata_dv                    (rpipe_rxdata_dv),
    .rpipe_rxelecidle                   (rpipe_rxelecidle),
    .rpipe_rxdetected                   (rpipe_rxdetected),
    .rpipe_rxdetect_done                (rpipe_rxdetect_done),
    .rpipe_all_phystatus_asserted       (), // unused
    .rpipe_all_phystatus_deasserted     (rpipe_all_phystatus_deasserted),
    .rpipe_margin_status                (rpipe_margin_status),
    .rpipe_margin_nak                   (rpipe_margin_nak),
    .rpipe_margin_error_cnt             (rpipe_margin_error_cnt),
    .rpipe_margin_sampl_cnt             (rpipe_margin_sampl_cnt),

    .rmlh_rcvd_eidle_set                (rmlh_rcvd_eidle_set),
    .rmlh_all_sym_locked                (rmlh_all_sym_locked),
    .act_rmlh_rcvd_eidle_set            (act_rmlh_rcvd_eidle_set),
    .rmlh_rplh_rxdata                   (rmlh_rplh_rxdata),
    .rmlh_rplh_rxdatak                  (rmlh_rplh_rxdatak),
    .rmlh_rplh_rxerror                  (rmlh_rplh_rxerror),
    .rmlh_rplh_dv                       (rmlh_rplh_dv),
    .rmlh_rplh_os_in_datastream         (rmlh_rplh_os_in_datastream),
    .rmlh_rplh_search_for_tokens        (rmlh_rplh_search_for_tokens),
    .rmlh_rplh_accept_eds_cycle         (rmlh_rplh_accept_eds_cycle),
    .rmlh_rplh_expect_eds               (rmlh_rplh_expect_eds),
    .rmlh_rplh_rxdata_link_width        (rmlh_rplh_rxdata_link_width),
    .rmlh_deskew_datastream_bus         (rmlh_deskew_datastream_bus),
    .rmlh_rplh_rcvd_idle_gen12          (rmlh_rplh_rcvd_idle_gen12),

    .rmlh_deskew_alignment_err          (pl_rmlh_deskew_alignment_err),
    .rmlh_deskew_complete               (rmlh_deskew_complete),
    .rpipe_rxerror                      (rpipe_rxerror),
    .rmlh_rpipe_rxoverflow               (pl_rmlh_rpipe_rxoverflow),
    .rmlh_rpipe_rxunderflow              (pl_rmlh_rpipe_rxunderflow),
    .rmlh_rpipe_rxcodeerror              (pl_rmlh_rpipe_rxcodeerror),
    .rmlh_rpipe_rxdisperror              (pl_rmlh_rpipe_rxdisperror),
    .rmlh_rpipe_rxskipadded              (pl_rmlh_rpipe_rxskipadded),
    .rmlh_skp_parity_err                 (pl_rmlh_skp_parity_err),
    .rmlh_sync_header_err                (pl_rmlh_sync_header_err),
    .rmlh_framing_err                    (pl_rmlh_framing_err),
    .rmlh_framing_err_ptr                (pl_rmlh_framing_err_ptr),
    .rmlh_framing_err_l0                 (pl_rmlh_framing_err_l0),
    .rmlh_deskew_fifo_ptr                (rmlh_deskew_fifo_ptr),
    .latched_rxdetected                  (latched_rxdetected),
    .rmlh_rxvalid_deasserted             (rmlh_rxvalid_deasserted),
    .rmlh_rpipe_rxskipremoved            (pl_rmlh_rpipe_rxskipremoved),
    .rpipe_rxaligned                    (rpipe_rxaligned),
    .rmlh_lane_err                      (pl_rmlh_lane_err),
    .rmlh_deskew_datastream             (rmlh_deskew_datastream),
    .rmlh_gen3_rcvd_4eidle_set          (rmlh_gen3_rcvd_4eidle_set),
    .act_rmlh_gen3_rcvd_4eidle_set      (act_rmlh_gen3_rcvd_4eidle_set),
    .rmlh_goto_recovery                 (rmlh_goto_recovery),
    .rmlh_descrambled_rxdata_dv         (rmlh_descrambled_rxdata_dv),
    .rmlh_descrambled_rxdata            (rmlh_descrambled_rxdata),
    .rmlh_descrambled_rxstartblock      (rmlh_descrambled_rxstartblock),
    .rmlh_descrambled_rxdata_osfound    (rmlh_descrambled_rxdata_osfound),
    .rmlh_descrambled_ints0             (),     // unused
    .rmlh_descrambled_rxdata_dcb        (rmlh_descrambled_rxdata_dcb),
    .rmlh_deskew_ds_g6                  (rmlh_deskew_ds_g6),
    .rmlh_deskew_fltlog_ctrl_skp_mismatch_bus (pl_rmlh_deskew_fltlog_ctrl_skp_mismatch_bus),
    .rmlh_deskew_fltlog_framing_err     (pl_rmlh_deskew_fltlog_framing_err),
    .rmlh_descrambled_ints1             (rmlh_descrambled_ints1),
    .rmlh_descrambled_ints2             (rmlh_descrambled_ints2),
    .rmlh_descrambled_inskp             (rmlh_descrambled_inskp),
    .rmlh_descrambled_ineie             (rmlh_descrambled_ineie),
    .rmlh_descrambled_eie_det           (rmlh_descrambled_eie_det),
    .rmlh_descrambled_insds             (rmlh_descrambled_insds),
    .rmlh_descrambled_rxdatak           (rmlh_descrambled_rxdatak),
    .rmlh_descrambled_rxerror           (rmlh_descrambled_rxerror),
    .rmlh_descrambled_even_parity       (rmlh_descrambled_even_parity),
    .rmlh_deskew_ctlskp_rcvd            (rmlh_deskew_ctlskp_rcvd),
    .rmlh_deskew_ctlskp_info            (rmlh_deskew_ctlskp_info),
    .rmlh_deskew_ctlskp_err             (pl_rmlh_deskew_ctlskp_err),
    .rmlh_descrambled_rxaligned         (rmlh_descrambled_rxaligned),
    .rmlh_rcvd_err                      (pl_rmlh_rcvd_err),
    .cfg_lpbk_en                        (cfg_lpbk_en),
    .cfg_prbs_en                        (cfg_prbs_en),
    .clear_prbs_done                    (clear_prbs_done_pl),
    .cfg_prbs_lane_sel                  (cfg_prbs_lane_sel),
    .rmlh_prbs_done                     (rmlh_prbs_done),
    .rmlh_prbs_fail                     (rmlh_prbs_fail),
    .rmlh_prbs_started                  (rmlh_prbs_started),
    .rmlh_prbs_err_cntr                 (rmlh_prbs_err_cntr),
    .rmlh_prbs_unexp_fail               (rmlh_prbs_unexp_fail)
); //rmlh

assign rplh_link_rxmode = {1'b0, rmlh_rplh_rxdata_link_width}; // for l0p, link width is changed dynamically in a data stream.
wire rplh_cxl_pl_rcvd_flit;

wire cxl_sh_bypass;

wire   smlh_block_dl_init;
wire   smlh_dl_active;
assign smlh_block_dl_init = smlh_protocol_cfg.spif_enable ? b_smlh_spif.s_pl_block_dl_init : (rdlh_rtlh_link_state ==  `S_DL_INACTIVE);
assign smlh_dl_active     = smlh_protocol_cfg.spif_enable ? b_smlh_spif.s_lp_dl_active     : (rdlh_rtlh_link_state ==  `S_DL_ACTIVE  );

// Plh Receive
rplh
 #(INST) u_rplh(
// ---- interfaces -----------
    .b_rplh_spif                      (b_rplh_spif.rplh_master_mp),
// ---- inputs ---------------
    .core_clk                         (core_clk),
    .core_rst_n                       (core_rst_n),
    .smlh_link_mode                   (rplh_link_rxmode),
    .active_nb_wire                   (active_nb_wire),
    .rmlh_rplh_rcvd_idle_gen12        (rmlh_rplh_rcvd_idle_gen12),
    .active_nb_gen34                  (active_nb_gen34),
    .rxdata_dv                        (rmlh_rplh_dv),
    .rxdata                           (rmlh_rplh_rxdata),
    .rxdatak                          (rmlh_rplh_rxdatak),
    .rxerror                          (rmlh_rplh_rxerror),
    .current_data_rate                (pm_current_data_rate_rplh_pkf),
    .vlsm_pl_link_up                  (b_smlh_spif.s_pl_link_up),
    .cxl_sh_bypass                    (cxl_sh_bypass),
    .os_in_datastream                 (rmlh_rplh_os_in_datastream),
    .search_for_tokens                (rmlh_rplh_search_for_tokens),
    .accept_eds_cycle                 (rmlh_rplh_accept_eds_cycle),
    .expect_eds                       (rmlh_rplh_expect_eds),
    .rplh_protocol_cfg                (splh_protocol_cfg),
    .smlh_flit_mode_enable            (smlh_flit_mode_enable_modules[1]),
    .smlh_ltssm_state_wire            (smlh_ltssm_state_wire),
    .smlh_block_dl_init               (smlh_block_dl_init),
      .cfg_upstream_port              (cfg_upstream_port),
      .cfg_acknack_disable            (cfg_acknack_disable),
      .cdm_ras_des_einj2_enable       (xplh_ras_des_einj2_enable),
      .cdm_ras_des_einj2_dllp_type    (xplh_ras_des_einj2_dllp_type),
    .cdm_plh_flit_err_inj_interface   (cdm_plh_flit_err_inj_interface),
// ---- outputs ---------------
    .rplh_rdlh_pkt_dv                 (rplh_rdlh_pkt_dv),
    .rplh_rdlh_pkt_data               (rplh_rdlh_pkt_data),
    .rplh_rdlh_dllp_start             (rplh_rdlh_dllp_start),
    .rplh_rdlh_tlp_start              (rplh_rdlh_tlp_start),
    .rplh_rdlh_pkt_end                (rplh_rdlh_pkt_end),
    .rplh_rdlh_pkt_edb                (rplh_rdlh_pkt_edb),
    .rplh_rdlh_nak                    (rplh_rdlh_nak),
    .rplh_rdlh_pkt_err                (rplh_rdlh_pkt_err),
    .rplh_rmlh_pkt_err                (rplh_rmlh_pkt_err),
    .rplh_rmlh_pkt_err_ptr            (rplh_rmlh_pkt_err_ptr),
    .rplh_rdlh_tlp_idl                (rplh_rdlh_tlp_idl),
    .rplh_rdlh_tlp_pfx                (rplh_rdlh_tlp_pfx),
    .rplh_rdlh_fm_poisoned            (rplh_rdlh_fm_poisoned),
    .rplh_rdlh_fm_nullified           (rplh_rdlh_fm_nullified),
    .rplh_flit_dl_prot_err            (rplh_flit_dl_prot_err),
    .rplh_cdm_flit_logging_interface  (rplh_cdm_flit_logging_interface),
      .rplh_ptm_sot                   (rplh_ptm_sot),
      .rplh_ptm_request               (rplh_ptm_request),
      .rplh_ptm_response              (rplh_ptm_response),
      .rplh_ptm_duplicate             (rplh_ptm_duplicate),
    .rplh_cxl_corr_pid_err            (rplh_cxl_corr_pid_err),
    .rplh_cxl_uncorr_pid_err          (rplh_cxl_uncorr_pid_err),
    .rplh_cxl_unexp_pid_err           (rplh_cxl_unexp_pid_err),
    .rplh_cxl_eds_err                 (rplh_cxl_eds_err),
    .rplh_cxl_pl_rcvd_flit            (rplh_cxl_pl_rcvd_flit),
    .rplh_xplh_fm_retry               (rplh_xplh_fm_retry),
    .rplh_rdlh_fm_dllp_data           (rplh_rdlh_fm_dllp_data),
    .rplh_rdlh_fm_dllp_valid          (rplh_rdlh_fm_dllp_valid),
    .rplh_rdlh_fm_dllp_opt_fc_up      (rplh_rdlh_fm_dllp_opt_fc_up),
    .rplh_cdm_flit_err_inj_status     (rplh_cdm_flit_err_inj_status),
    .rplh_rcvd_idle                   (rplh_rcvd_idle)
); //rplh

//RX RBUF INTERFACE

//FLIT ERROR INJECTION STATUS OUTPUT
assign plh_cdm_flit_err_inj_status.cfg_tx_inj_sts = xplh_cdm_flit_err_inj_status;
assign plh_cdm_flit_err_inj_status.cfg_rx_inj_sts = rplh_cdm_flit_err_inj_status;

// Layer 1 State


assign smlh_ltssm_state_o                = smlh_ltssm_state;
assign cpcie_smlh_link_up_o              = cpcie_smlh_link_up;
assign cpcie_smlh_req_rst_not_o          = cpcie_smlh_req_rst_not;
assign cpcie_smlh_ltssm_state_rcvry_eq_o = cpcie_smlh_ltssm_state_rcvry_eq;
assign pm_current_data_rate_others_o     = pm_current_data_rate_others_int;
  // rmlh -> cdm
assign rmlh_rcvd_err               = pl_rmlh_rcvd_err;
assign rmlh_deskew_alignment_err   = pl_rmlh_deskew_alignment_err;
assign rmlh_rpipe_rxskipremoved    = pl_rmlh_rpipe_rxskipremoved;
assign tmp_rmlh_lane_err               = pl_rmlh_lane_err;

  // smlh -> cdm
assign smlh_clr_enter_compliance     = pl_smlh_clr_enter_compliance    ;    
assign smlh_core_rst_n_release_pulse = pl_smlh_core_rst_n_release_pulse;
assign smlh_dir_spd_chg_rising_edge  = pl_smlh_dir_spd_chg_rising_edge ; 
assign smlh_tx_margin_rst            = pl_smlh_tx_margin_rst           ;           
assign smlh_dir_linkw_chg_started     = pl_smlh_dir_linkw_chg_started;
assign smlh_bw_mgt_status             = pl_smlh_bw_mgt_status;
assign smlh_link_auto_bw_status       = pl_smlh_link_auto_bw_status;
assign smlh_timeout_nfts   = pl_smlh_timeout_nfts   ;
assign smlh_l0_to_recovery = pl_smlh_l0_to_recovery ;
assign smlh_l1_to_recovery = pl_smlh_l1_to_recovery ;
assign smlh_rcv_eios_when_l0s_unsprt  = pl_smlh_rcv_eios_when_l0s_unsprt ;
assign smlh_deskew_uncomplete_err     = pl_smlh_deskew_uncomplete_err ;
assign smlh_lwd_change     = pl_smlh_lwd_change     ;
assign smlh_spd_change     = pl_smlh_spd_change;
assign xmlh_einj0_oscrc_evt = pl_xmlh_einj0_oscrc_evt;
assign xmlh_einj3_osmsk_evt = pl_xmlh_einj3_osmsk_evt;
assign pl_cdm_ras_des_einj0_enable   =  cdm_ras_des_einj0_enable  ;
assign pl_cdm_ras_des_einj0_crc_type =  cdm_ras_des_einj0_crc_type;
assign pl_cdm_ras_des_einj3_enable   = cdm_ras_des_einj3_enable  ;
assign pl_cdm_ras_des_einj3_count    = cdm_ras_des_einj3_count   ;
assign pl_cdm_ras_des_einj3_smb_type = cdm_ras_des_einj3_smb_type;
assign clear_prbs_done_pl            = clear_prbs_done;
assign tmp_smlh_margin_status        = pl_smlh_margin_status      ;
assign tmp_smlh_margin_status_valid  = pl_smlh_margin_status_valid;
  // rmlh -> rmlh
assign tmp_rmlh_deskew_ctlskp_err    = pl_rmlh_deskew_ctlskp_err;
assign rmlh_deskew_fltlog_ctrl_skp_mismatch_bus = pl_rmlh_deskew_fltlog_ctrl_skp_mismatch_bus;
assign rmlh_deskew_fltlog_framing_err           = pl_rmlh_deskew_fltlog_framing_err;
assign smseq_invalid_os_bus   = pl_smseq_invalid_os_bus;
assign smseq_os_corrected_bus = pl_int_os_corrected_bus;
assign rmlh_rpipe_rxoverflow      = pl_rmlh_rpipe_rxoverflow ;
assign rmlh_rpipe_rxunderflow     = pl_rmlh_rpipe_rxunderflow;
assign rmlh_rpipe_rxcodeerror     = pl_rmlh_rpipe_rxcodeerror;
assign rmlh_rpipe_rxdisperror     = pl_rmlh_rpipe_rxdisperror;
assign rmlh_rpipe_rxskipadded     = pl_rmlh_rpipe_rxskipadded;
assign rmlh_skp_parity_err        = pl_rmlh_skp_parity_err   ;
assign rmlh_sync_header_err       = pl_rmlh_sync_header_err  ;
assign rmlh_framing_err           = pl_rmlh_framing_err      ;
assign rmlh_framing_err_ptr       = pl_rmlh_framing_err_ptr  ;
assign rmlh_framing_err_l0        = pl_rmlh_framing_err_l0   ;

  // PM -> rmlh
assign pl_pm_block_phystatus     = pm_block_phystatus;


// esm_current_rate[4] = 16gt/s with cfg_lec_g4_pset_ltx used in ESM Gen3 rate, else 8gt/s with cfg_lec_pset_ltx. The same for cfg_lec_pset_lrx.
// esm_target_speed_int[4] = 16gt/s with cfg_lec_g4_pset_rtx used in ESM Gen3 rate, else 8gt/s with cfg_lec_pset_rtx. The same for cfg_lec_pset_rrx.
wire [`CX_TX_PSET_WD*`CX_NL-1:0] cfg_lec_pset_ltx_i;
wire [`CX_TX_PSET_WD*`CX_NL-1:0] cfg_lec_pset_rtx_i;
wire [`CX_NL*`CX_RX_PSET_WD-1:0] cfg_lec_pset_lrx_i;
wire [`CX_NL*`CX_RX_PSET_WD-1:0] cfg_lec_pset_rrx_i;

assign cfg_lec_pset_ltx_i = tmp_cfg_lec_pset_ltx;
assign cfg_lec_pset_rtx_i = tmp_cfg_lec_pset_rtx;
assign cfg_lec_pset_lrx_i = tmp_cfg_lec_pset_lrx;
assign cfg_lec_pset_rrx_i = tmp_cfg_lec_pset_rrx;
// esm_current_rate[6] = 25gt/s, esm_current_rate[5] = 20gt/s, else legacy PCIe Gen4 rate with cfg_lec_g4_pset_ltx
// esm_target_speed_int[7] = 25gt/s, esm_target_speed_int[6] = 20gt/s, else legacy PCIe Gen4 rate with cfg_lec_g4_pset_rtx. rrx for 20/25GT/s is 0
wire [`CX_TX_PSET_WD*`CX_NL-1:0] cfg_lec_g4_pset_ltx_i;
wire [`CX_TX_PSET_WD*`CX_NL-1:0] cfg_lec_g4_pset_rtx_i;
wire [`CX_NL*`CX_RX_PSET_WD-1:0] cfg_lec_g4_pset_lrx_i;
wire [`CX_NL*`CX_RX_PSET_WD-1:0] cfg_lec_g4_pset_rrx_i;

assign cfg_lec_g4_pset_ltx_i = tmp_cfg_lec_g4_pset_ltx;
assign cfg_lec_g4_pset_rtx_i = tmp_cfg_lec_g4_pset_rtx;
assign cfg_lec_g4_pset_lrx_i = cfg_lec_g4_pset_lrx;
assign cfg_lec_g4_pset_rrx_i = cfg_lec_g4_pset_rrx;

//--------------------------------------
// Instance of smlh for PCIe
//--------------------------------------


smlh

#(INST) u_smlh(
    .b_smlh_spif                        (b_smlh_spif.smlh_master_mp),
    .core_clk                           (core_clk),
    .core_rst_n                         (core_rst_n),
    .current_cclk_rate                  (current_cclk_rate),
    .cfg_comm_clk_config                (cfg_comm_clk_config),
    .cfg_flit_mode_enable               (cfg_flit_mode_enable),
    .cfg_pcie_cap_flit_mode_sup         (cfg_pcie_cap_flit_mode_sup),
    .cfg_flit_mode_dis                  (cfg_flit_mode_dis),
    .cfg_reciver_l0p_supported          (cfg_reciver_l0p_supported),
    .xplh_smlh_req_rcvry                (xplh_smlh_req_rcvry),
    .device_type                        (device_type),
    .cfg_pcie_slot_clk_config           (cfg_pcie_slot_clk_config),
    .cfg_cxl_port_enable                (cfg_cxl_port_enable),
    .cfg_cxl_port_vid                   (cfg_cxl_port_vid),
    .cfg_cxl_retimers_pre_mismatched    (cfg_cxl_retimers_pre_mismatched),
    .cfg_retimers_pre_detected          (cfg_retimers_pre_detected),
    .vlsm_almp_rx_req                   (rplh_cxl_pl_rcvd_flit),
    .app_sris_mode                      (app_sris_mode),
    .xmlh_sris_enable                   (xmlh_sris_enable),
    .pipe_regif_all_idle                (pipe_regif_all_idle),
    .cfg_rate_chg_mode                  (cfg_rate_chg_mode),
    .cfg_pam4_restricted_levels_requirement (cfg_pam4_restricted_levels_requirement),
    .pam4_restricted_levels_wr_ack_pending  (tmp_pam4_restricted_levels_wr_ack_pending),
    .cfg_ts2_lid_deskew                 (cfg_ts2_lid_deskew),
    .cfg_support_part_lanes_rxei_exit   (cfg_support_part_lanes_rxei_exit),
    .cfg_scramble_dis                   (cfg_scramble_dis),
    .cfg_imp_num_lanes                  (cfg_imp_num_lanes),
    .cfg_n_fts                          (cfg_n_fts),
    .cfg_upstream_port                  (cfg_upstream_port),
    .cfg_root_compx                     (cfg_root_compx),
    .cfg_link_dis                       (cfg_link_dis),
    .cfg_link_retrain                   (cfg_link_retrain_i),
    .cfg_lpbk_en                        (cfg_lpbk_en),
    .cfg_mux_lpbk_lanenum               (cfg_mux_lpbk_lanenum),
    .cfg_reset_assert                   (cfg_reset_assert),
    .cfg_link_num                       (cfg_link_num),
    .cfg_forced_link_state              (cfg_forced_link_state),
    .cfg_forced_ltssm_cmd               (cfg_forced_ltssm_cmd),
    .cfg_force_en                       (cfg_force_en),
    .cfg_elastic_buffer_mode            (cfg_elastic_buffer_mode_i),
    .cfg_fast_link_mode                 (cfg_fast_link_mode),
    .cfg_fast_link_scaling_factor       (cfg_fast_link_scaling_factor),
    .cfg_l0s_supported                  (cfg_l0s_supported),
    .cfg_link_capable                   (cfg_link_capable),
    .cfg_ext_synch                      (cfg_ext_synch),
    .cfg_gen1_ei_inference_mode         (cfg_gen1_ei_inference_mode),
    .cfg_select_deemph_mux_bus          (cfg_select_deemph_mux_bus),
    .cfg_lut_ctrl                       (cfg_lut_ctrl),
    .cfg_rxstandby_control              (cfg_rxstandby_control),
    .cfg_polarity_mode                  (cfg_polarity_mode),
    .cfg_rx_8_ts1s                      (cfg_rx_8_ts1s),
    .cfg_block_local_detect_eq_problem  (cfg_block_local_detect_eq_problem),
    .cfg_rxstandby_handshake_policy     (cfg_rxstandby_handshake_policy),
    .cfg_por_phystatus_mode             (cfg_por_phystatus_mode),
    .cfg_p1_entry_policy                (cfg_p1_entry_policy),
    .cfg_pl_gen3_control                (cfg_pl_gen3_control),
    .cfg_pl_gen3_eq_control             (cfg_pl_gen3_eq_control),
    .cfg_fdbk_dirchange_control         (cfg_fdbk_dirchange_control),
    // 8 GT/s Receiver Impedance ECN
    .cfg_pl_gen3_zrxdc_noncompl         (cfg_pl_gen3_zrxdc_noncompl),
    .cfg_perform_eq                     (cfg_perform_eq_i),
    .cfg_lec_pset_ltx                   (cfg_lec_pset_ltx_i),
    .cfg_lec_pset_lrx                   (cfg_lec_pset_lrx_i),
    .cfg_lec_pset_rtx                   (cfg_lec_pset_rtx_i),
    .cfg_lec_pset_rrx                   (cfg_lec_pset_rrx_i),
    .cfg_ls2_eq_req                     (cfg_ls2_eq_req),
    .cfg_pl_gen4_control                (cfg_pl_gen4_control),
    .cfg_pl_gen4_eq_control             (cfg_pl_gen4_eq_control),
    .cfg_gen4_fdbk_dirchange_control    (cfg_gen4_fdbk_dirchange_control),
    .cfg_lec_g4_pset_ltx                (cfg_lec_g4_pset_ltx_i),
    .cfg_lec_g4_pset_lrx                (cfg_lec_g4_pset_lrx_i),
    .cfg_lec_g4_pset_rtx                (cfg_lec_g4_pset_rtx_i),
    .cfg_lec_g4_pset_rrx                (cfg_lec_g4_pset_rrx_i),
    .cfg_pl_gen5_control                (cfg_pl_gen5_control),
    .cfg_pl_gen5_eq_control             (cfg_pl_gen5_eq_control),
    .cfg_gen5_fdbk_dirchange_control    (cfg_gen5_fdbk_dirchange_control),
    .cfg_bypass_eq_enable               (cfg_bypass_eq_enable),
    .cfg_no_eq_needed_enable            (cfg_no_eq_needed_enable), //haha
//    .cfg_no_eq_needed_enable            (1'b0), //(cfg_no_eq_needed_enable), //haha
    .cfg_lec_g5_pset_ltx                (tmp_cfg_lec_g5_pset_ltx),
    .cfg_lec_g5_pset_lrx                (cfg_lec_g5_pset_lrx),
    .cfg_lec_g5_pset_rtx                (tmp_cfg_lec_g5_pset_rtx),
    .cfg_lec_g5_pset_rrx                (cfg_lec_g5_pset_rrx),
    .cfg_tx_precode_req                 (cfg_tx_precode_req),
    .cfg_g6_tx_precode_req              (cfg_g6_tx_precode_req),
    .cfg_pl_gen6_control                (cfg_pl_gen6_control),
    .cfg_pl_gen6_eq_control             (cfg_pl_gen6_eq_control),
    .cfg_gen6_fdbk_dirchange_control    (cfg_gen6_fdbk_dirchange_control),
    .cfg_lec_g6_pset_ltx                (tmp_cfg_lec_g6_pset_ltx),
    .cfg_lec_g6_pset_lrx                (cfg_lec_g6_pset_lrx),
    .cfg_lec_g6_pset_rtx                (tmp_cfg_lec_g6_pset_rtx),
    .cfg_lec_g6_pset_rrx                (cfg_lec_g6_pset_rrx),
    .cfg_alt_protocol_enable            (cfg_alt_protocol_enable),
    .cfg_margin_control                 (tmp_cfg_margin_control),
    .cfg_margin_num_timing_steps        (cfg_margin_num_timing_steps),
    .cfg_margin_max_timing_offset       (cfg_margin_max_timing_offset),
    .cfg_margin_num_voltage_steps       (cfg_margin_num_voltage_steps),
    .cfg_margin_max_voltage_offset      (cfg_margin_max_voltage_offset),
    .cfg_margin_sample_rate_voltage     (cfg_margin_sample_rate_voltage),
    .cfg_margin_sample_rate_timing      (cfg_margin_sample_rate_timing),
    .cfg_margin_maxlanes                (cfg_margin_maxlanes),
    .cfg_margin_voltage_supported       (cfg_margin_voltage_supported),
    .cfg_margin_ind_left_right_timing   (cfg_margin_ind_left_right_timing),
    .cfg_margin_ind_up_down_voltage     (cfg_margin_ind_up_down_voltage),
    .cfg_margin_sample_reporting_method (cfg_margin_sample_reporting_method),
    .cfg_margin_ind_error_sampler       (cfg_margin_ind_error_sampler),
    .cfg_rx_message_bus_write_buffer_depth (cfg_rx_message_bus_write_buffer_depth),
    .cfg_hw_autowidth_dis               (cfg_hw_autowidth_dis),
    .cfg_pl_multilane_control           (cfg_pl_multilane_control),
    .rasdp_linkdown                     (rasdp_linkdown),
    .app_init_rst                       (app_init_rst),
    .app_ltssm_enable                   (app_ltssm_enable),
    .xdlh_smlh_goto_detect              (xdlh_smlh_goto_detect_i),
    .xplh_xmlh_sof                      (xplh_xmlh_sof),
    .xdlh_smlh_link_req                 (xdlh_smlh_link_req),
    .xdlh_smlh_link_width               (xdlh_smlh_link_width),
    .xdlh_smlh_link_initiated           (xdlh_smlh_link_initiated),
    .rmlh_deskew_datastream_bus         (rmlh_deskew_datastream_bus),
    .rmlh_rplh_rxdata_link_width        (rmlh_rplh_rxdata_link_width),
    .xdlh_smlh_start_link_retrain       (xdlh_smlh_start_link_retrain),
    .rtlh_req_link_retrain              (rtlh_req_link_retrain),
    .rplh_rcvd_idle                     (rplh_rcvd_idle),
    .rmlh_all_sym_locked                (rmlh_all_sym_locked),
    .rmlh_rcvd_eidle_set                (rmlh_rcvd_eidle_set),
    .act_rmlh_rcvd_eidle_set            (act_rmlh_rcvd_eidle_set),
    .rmlh_deskew_alignment_err          (pl_rmlh_deskew_alignment_err),
    .rmlh_deskew_complete               (rmlh_deskew_complete),
    .rpipe_rxaligned                    (rpipe_rxaligned),
    .rmlh_deskew_datastream             (rmlh_deskew_datastream),
    .rmlh_goto_recovery                 (rmlh_goto_recovery),
    .rmlh_gen3_rcvd_4eidle_set          (rmlh_gen3_rcvd_4eidle_set),
    .act_rmlh_gen3_rcvd_4eidle_set      (act_rmlh_gen3_rcvd_4eidle_set),
    .rmlh_descrambled_rxdata_dv         (rmlh_descrambled_rxdata_dv),
    .rmlh_descrambled_rxstartblock      (rmlh_descrambled_rxstartblock),
    .rmlh_descrambled_rxdata            (rmlh_descrambled_rxdata),
    .rmlh_descrambled_ints1             (rmlh_descrambled_ints1),
    .rmlh_descrambled_ints2             (rmlh_descrambled_ints2),
    .rmlh_descrambled_inskp             (rmlh_descrambled_inskp),
    .rmlh_descrambled_ineie             (rmlh_descrambled_ineie),
    .rmlh_descrambled_eie_det           (rmlh_descrambled_eie_det),
    .rmlh_descrambled_insds             (rmlh_descrambled_insds),
    .rmlh_descrambled_rxdatak           (rmlh_descrambled_rxdatak),
    .rmlh_descrambled_rxerror           (rmlh_descrambled_rxerror),
    .rmlh_descrambled_rxaligned         (rmlh_descrambled_rxaligned),
    .rmlh_descrambled_rxdata_osfound    (rmlh_descrambled_rxdata_osfound),
    .rdlh_rcvd_dllp                     (rdlh_rcvd_dllp),
    .rmlh_deskew_ctlskp_rcvd            (rmlh_deskew_ctlskp_rcvd),
    .rmlh_deskew_ctlskp_info            (rmlh_deskew_ctlskp_info),
    .rmlh_deskew_ctlskp_err             (pl_rmlh_deskew_ctlskp_err),
    .rmlh_descrambled_rxdata_dcb        (rmlh_descrambled_rxdata_dcb),
    .pm_current_data_rate_smlh_sqf      (pm_current_data_rate_smlh_sqf),
    .pm_current_data_rate_smlh_lnk      (pm_current_data_rate_smlh_lnk),
    .pm_current_data_rate_smlh_eq       (pm_current_data_rate_smlh_eq),
    .pm_current_data_rate_ltssm         (pm_current_data_rate_ltssm),
    .pm_current_data_rate_pre           (pm_current_data_rate),
    .current_powerdown                  (current_powerdown),
    .rpipe_rxdata                       (rpipe_rxdata),
    .rpipe_rxdatak                      (rpipe_rxdatak),
    .rpipe_rxerror_dup                  (rpipe_rxerror_dup),
    .rpipe_rxdata_dv                    (rpipe_rxdata_dv),
    .rpipe_rxelecidle                   (rpipe_rxelecidle),
    .rpipe_rxdetected                   (rpipe_rxdetected),
    .rpipe_rxdetect_done                (rpipe_rxdetect_done),
    .rpipe_all_phystatus_deasserted     (rpipe_all_phystatus_deasserted),
    .rpipe_rxskipremoved                (pl_rmlh_rpipe_rxskipremoved),
    .rpipe_margin_status                (rpipe_margin_status),
    .rpipe_margin_nak                   (rpipe_margin_nak),
    .rpipe_margin_error_cnt             (rpipe_margin_error_cnt),
    .rpipe_margin_sampl_cnt             (rpipe_margin_sampl_cnt),
    .power_saving_lanes_active          (power_saving_txlanes_active),
    .phy_mac_phystatus                  (in_cxpl_phy_mac_phystatus),
    .phy_mac_rxstandbystatus_physic_lane (tmp_phy_mac_rxstandbystatus),
    .phy_mac_rxelecidle_physic_lane     (sqlchd_rxelecidle),
    .laneflip_lanes_active_physic_lane  (laneflip_lanes_active),
    .laneflip_set_rxstandby_physic_lane (laneflip_set_rxstandby),
    .laneflip_mac_phy_rxstandby         (laneflip_mac_phy_rxstandby),
    .laneflip_pipe_turnoff_physic_lane  (int_pipe_turnoff),
    .cfg_lane_en                        (cfg_lane_en),
    .rplh_pkt_start                     (rplh_pkt_start),
    .cfg_compliance_de_emphasis         (cfg_compliance_de_emphasis),
    .cfg_directed_speed_change          (cfg_directed_speed_change),
    .cfg_enter_compliance               (cfg_enter_compliance),
    .cfg_enter_mod_compliance           (cfg_enter_mod_compliance),
    .cfg_gen2_n_fts                     (cfg_gen2_n_fts),
    .cfg_gen2_support                   (cfg_gen2_support),
    .cfg_pcie_max_link_speed            (cfg_pcie_max_link_speed_i),
    .cfg_phy_txswing                    (cfg_phy_txswing),
    .cfg_sel_de_emphasis                (cfg_sel_de_emphasis),
    .cfg_target_link_speed              (cfg_target_link_speed_i), //haha
    .cfg_transmit_margin                (cfg_transmit_margin),
    .cfg_tx_compliance_rcv              (cfg_tx_compliance_rcv),
    .sticky_rst_n                       (sticky_rst_n),
    .smlh_dl_active                     (smlh_dl_active),
    .cfg_gen3_eq_fs_lf                  (cfg_gen3_eq_fs_lf),
    .cfg_gen3_eq_coef                   (cfg_gen3_eq_coef),
    .cfg_gen4_eq_fs_lf                  (cfg_gen4_eq_fs_lf),
    .cfg_gen4_eq_coef                   (cfg_gen4_eq_coef),
    .cfg_gen5_eq_fs_lf                  (cfg_gen5_eq_fs_lf),
    .cfg_gen5_eq_coef                   (cfg_gen5_eq_coef),
    .cfg_gen6_eq_fs_lf                  (cfg_gen6_eq_fs_lf),
    .cfg_gen6_eq_coef                   (cfg_gen6_eq_coef),
    .pm_smlh_l1_2_latched               (pm_smlh_l1_2_latched),
    .pm_smlh_l1_n_latched               (pm_smlh_l1_n_latched),
    .cfg_l1sub_t_common_mode            (cfg_l1sub_t_common_mode),
    //gates
    .xmlh_sent_24_ts0_ec00              (xmlh_sent_24_ts0_ec00),
    .rmlh_deskew_ds_g6                  (rmlh_deskew_ds_g6),
    .pm_current_powerdown_p1            ( pm_current_powerdown_p1 ),
    .pm_current_powerdown_p0            ( pm_current_powerdown_p0 ),
// ---------- Outputs --------
    .xmtbyte_ts_pcnt                    (xmtbyte_ts_pcnt),
    .xmtbyte_ts_data_diff               (xmtbyte_ts_data_diff),
    .xmtbyte_1024_ts_sent               (xmtbyte_1024_ts_sent),
    .xmtbyte_spd_chg_sent               (xmtbyte_spd_chg_sent),
    .xmtbyte_dis_link_sent              (xmtbyte_dis_link_sent),
    .xmtbyte_loe_2_ts1_ec_00b_sent      (xmtbyte_loe_2_ts1_ec_00b_sent),
    .xmtbyte_ctlskip_sent               (xmtbyte_ctlskip_sent),
    .xmtbyte_skip_sent                  (xmtbyte_skip_sent),
    .xmtbyte_ts1_sent                   (xmtbyte_ts1_sent),
    .xmtbyte_ts2_sent                   (xmtbyte_ts2_sent),
    .xmtbyte_idle_sent                  (xmtbyte_idle_sent),
    .xmtbyte_eidle_sent                 (xmtbyte_eidle_sent),
    .xmtbyte_2_compliance_ts1_sent      (xmtbyte_2_compliance_ts1_sent),
    .xmbyte_flit_data_stream            (xmbyte_flit_data_stream),
    .xmtbyte_l0p_ts1_sent               (xmtbyte_l0p_ts1_sent),
    .xmtbyte_l0p_ts2_sent               (xmtbyte_l0p_ts2_sent),
    .xmtbyte_l0p_linkwidth_changed      (xmtbyte_l0p_linkwidth_changed),
    .xmtbyte_l0p_state_in_upsize        (xmtbyte_l0p_state_in_upsize),
    .xmtbyte_eies_sent                  (xmtbyte_eies_sent),
    .xmtbyte_fts_sent                   (xmtbyte_fts_sent),
    .xmtbyte_cmd_is_data                (xmlh_cmd_is_data),
    .xmtbyte_txdata_dv                  (xmtbyte_txdata_dv),
    .xmtbyte_txdata                     (xmtbyte_txdata),
    .xmtbyte_txdatak                    (xmtbyte_txdatak),
    .int_mac_phy_txelecidle             (int_mac_phy_txelecidle),
    .xmtbyte_txdetectrx_loopback        (xmtbyte_txdetectrx_loopback),
    .cdm_ras_des_pm_entry_interval      (cdm_ras_des_pm_entry_interval),
    .cdm_ras_des_direct_rcvry_idle_to_cfg (cdm_ras_des_direct_rcvry_idle_to_cfg),
    .cdm_ras_des_direct_poll_cmp_to_det (cdm_ras_des_direct_poll_cmp_to_det),
    .cdm_ras_des_direct_lpbk_slave_to_exit (cdm_ras_des_direct_lpbk_slave_to_exit),
    .cdm_ras_des_ltssm_stop             (cdm_ras_des_ltssm_stop),
    .cdm_ras_des_recovery_req           (cdm_ras_des_recovery_req),
    .cdm_ras_des_force_rxdetected_en    (cdm_ras_des_force_rxdetected_en),
    .cdm_ras_des_force_rxdetected       (tmp_cdm_ras_des_force_rxdetected[`CX_NL-1:0]),
    .cdm_ras_des_ext_eq_to_factor       (cdm_ras_des_ext_eq_to_factor),
    .cdm_ras_des_eq_fom_target_en       (cdm_ras_des_eq_fom_target_en),
    .cdm_ras_des_eq_force_coef_rtx_en   (cdm_ras_des_eq_force_coef_rtx_en),
    .cdm_ras_des_eq_force_pset_lrx_en   (cdm_ras_des_eq_force_pset_lrx_en),
    .cdm_ras_des_eq_force_coef_ltx_en   (cdm_ras_des_eq_force_coef_ltx_en),
    .cdm_ras_des_eq_force_coef_ltx      (cdm_ras_des_eq_force_coef_ltx),
    .cdm_ras_des_eq_force_pset_lrx      (cdm_ras_des_eq_force_pset_lrx),
    .cdm_ras_des_eq_force_coef_rtx      (cdm_ras_des_eq_force_coef_rtx),
    .cdm_ras_des_eq_force_pset_ltx_en   (cdm_ras_des_eq_force_pset_ltx_en),
    .cdm_ras_des_eq_force_usp_pset_ltx  (cdm_ras_des_eq_force_usp_pset_ltx),
    .cdm_ras_des_eq_force_coef_rtx_en_g4 (cdm_ras_des_eq_force_coef_rtx_en_g4),
    .cdm_ras_des_eq_force_coef_ltx_en_g4 (cdm_ras_des_eq_force_coef_ltx_en_g4),
    .cdm_ras_des_eq_force_coef_ltx_g4   (cdm_ras_des_eq_force_coef_ltx_g4),
    .cdm_ras_des_eq_force_coef_rtx_g4   (cdm_ras_des_eq_force_coef_rtx_g4),
    .cdm_ras_des_eq_force_pset_ltx_en_g4 (cdm_ras_des_eq_force_pset_ltx_en_g4),
    .cdm_ras_des_eq_force_usp_pset_ltx_g4 (cdm_ras_des_eq_force_usp_pset_ltx_g4),
    .cdm_ras_des_eq_force_coef_rtx_en_g5 (cdm_ras_des_eq_force_coef_rtx_en_g5),
    .cdm_ras_des_eq_force_coef_ltx_en_g5 (cdm_ras_des_eq_force_coef_ltx_en_g5),
    .cdm_ras_des_eq_force_coef_ltx_g5   (cdm_ras_des_eq_force_coef_ltx_g5),
    .cdm_ras_des_eq_force_coef_rtx_g5   (cdm_ras_des_eq_force_coef_rtx_g5),
    .cdm_ras_des_eq_force_pset_ltx_en_g5 (cdm_ras_des_eq_force_pset_ltx_en_g5),
    .cdm_ras_des_eq_force_usp_pset_ltx_g5 (cdm_ras_des_eq_force_usp_pset_ltx_g5),
    .cdm_ras_des_eq_force_coef_rtx_en_g6 (cdm_ras_des_eq_force_coef_rtx_en_g6),
    .cdm_ras_des_eq_force_coef_ltx_en_g6 (cdm_ras_des_eq_force_coef_ltx_en_g6),
    .cdm_ras_des_eq_force_coef_ltx_g6   (cdm_ras_des_eq_force_coef_ltx_g6),
    .cdm_ras_des_eq_force_coef_rtx_g6   (cdm_ras_des_eq_force_coef_rtx_g6),
    .cdm_ras_des_eq_force_pset_ltx_en_g6 (cdm_ras_des_eq_force_pset_ltx_en_g6),
    .cdm_ras_des_eq_force_usp_pset_ltx_g6 (cdm_ras_des_eq_force_usp_pset_ltx_g6),
    .cdm_ras_des_eq_fom_target          (cdm_ras_des_eq_fom_target),
    .cdm_ras_des_eq_eval_interval       (cdm_ras_des_eq_eval_interval),

    // outputs
    .smlh_link_mode                     (cpcie_smlh_link_mode),
    .smlh_link_rxmode                   (cpcie_smlh_link_rxmode),
    .smlh_lanes_active                  (cpcie_smlh_lanes_active),
    .lpbk_eq_lanes_active               (lpbk_eq_lanes_active),
    .smlh_no_turnoff_lanes              (cpcie_smlh_no_turnoff_lanes),
    .smlh_lnknum_match_dis              (cpcie_smlh_lnknum_match_dis),
    .smlh_link_up                       (cpcie_smlh_link_up),
    .smlh_req_rst_not                   (cpcie_smlh_req_rst_not),
    .smlh_scrambler_disable             (cpcie_smlh_scrambler_disable),
    .smlh_ltssm_in_pollconfig           (cpcie_smlh_ltssm_in_pollconfig),
    .smlh_training_rst_n                (cpcie_smlh_training_rst_n),
    .smlh_link_disable                  (cpcie_smlh_link_disable),
    .smlh_link_in_training              (cpcie_smlh_link_in_training),
    .smlh_bw_mgt_status                 (cpcie_smlh_bw_mgt_status),
    .smlh_link_auto_bw_status           (cpcie_smlh_link_auto_bw_status),
    .smlh_ltssm_next                    (cpcie_smlh_ltssm_next),
    .smlh_ltssm_last                    (smlh_ltssm_last),
    .deskew_lanes_active                (cpcie_deskew_lanes_active),
    .mac_phy_rate                       (cpcie_mac_phy_rate),
    .mac_phy_rxpolarity                 (cpcie_mac_phy_rxpolarity),
    .mac_phy_rxstandby                  (cpcie_mac_phy_rxstandby),
    .smlh_set_rxstandby                 (cpcie_smlh_set_rxstandby),
    .mac_phy_txdeemph                   (cpcie_mac_phy_txdeemph),
    .mac_phy_txmargin                   (cpcie_mac_phy_txmargin),
    .mac_phy_txswing                    (cpcie_mac_phy_txswing),
    .smlh_clr_enter_compliance          (cpcie_smlh_clr_enter_compliance),
    .smlh_tx_margin_rst                 (cpcie_smlh_tx_margin_rst),
    .smlh_successful_spd_negotiation    (cpcie_smlh_successful_spd_negotiation),
    .smlh_core_rst_n_release_pulse      (cpcie_smlh_core_rst_n_release_pulse),
    .smlh_dir_spd_chg_rising_edge       (cpcie_smlh_dir_spd_chg_rising_edge),
    .smlh_mcs_rcvd                      (cpcie_smlh_mcs_rcvd),
    .smseq_loc_eies_rcvd_bus            (cpcie_smseq_loc_eies_rcvd_bus),
    .mac_phy_pam4_restricted_levels     (cpcie_mac_phy_pam4_restricted_levels),
    .smlh_dir_linkw_chg_started         (cpcie_smlh_dir_linkw_chg_started),
    .smlh_ltssm_in_hotrst_dis_entry     (cpcie_smlh_ltssm_in_hotrst_dis_entry),
    .smseq_ts1_rcvd_pulse_bus           (cpcie_smseq_ts1_rcvd_pulse_bus),
    .smseq_ts2_rcvd_pulse_bus           (cpcie_smseq_ts2_rcvd_pulse_bus),
    .smseq_loc_ts2_rcvd_bus             (cpcie_smseq_loc_ts2_rcvd_bus),
    .smseq_in_skp_bus                   (cpcie_smseq_in_skp_bus),
    .smseq_fts_skp_do_deskew_bus        (cpcie_smseq_fts_skp_do_deskew_bus),
    .smlh_ltssm_in_compliance           (cpcie_smlh_ltssm_in_compliance),
    .smlh_ltssm_in_rcvrylock            (cpcie_smlh_ltssm_in_rcvrylock),
    .smlh_ltssm_in_detectquiet          (cpcie_smlh_ltssm_in_detectquiet),
    .ltssm_cmd_send_eieos_for_pset_map  (cpcie_ltssm_cmd_send_eieos_for_pset_map),
    .ltssm_usp_eq_redo                  (cpcie_ltssm_usp_eq_redo),
    .smlh_ls2_eq_req                    (cpcie_smlh_ls2_eq_req),
    .smlh_ls2_eq_success                (cpcie_smlh_ls2_eq_success),
    .smlh_ls2_eq_cmpl                   (cpcie_smlh_ls2_eq_cmpl),
    .smlh_ls2_eq_enter                  (cpcie_smlh_ls2_eq_enter),
    .smlh_eq_pending                    (cpcie_smlh_eq_pending),
    .smlh_usp_eq_pending                (cpcie_smlh_usp_eq_pending),
    .smlh_auto_eq_dllp_blocking         (cpcie_smlh_auto_eq_dllp_blocking),
    .usp_g3_eq_redo_executed_int        (usp_g3_eq_redo_executed_int),     // USP gen3 eq redo executed interrupt
    .usp_g4_eq_redo_executed_int        (usp_g4_eq_redo_executed_int),     // USP gen4 eq redo executed interrupt
    .usp_g5_eq_redo_executed_int        (usp_g5_eq_redo_executed_int),     // USP gen5 eq redo executed interrupt
    .smlh_lec_pset_ltx                  (cpcie_smlh_lec_pset_ltx),
    .smlh_lec_pset_lrx                  (cpcie_smlh_lec_pset_lrx),
    .smlh_ltssm_state_rcvry_eq          (cpcie_smlh_ltssm_state_rcvry_eq),
    .smlh_gen3_error_count              (cpcie_smlh_gen3_error_count),
    .smlh_ls2_g4_eq_req                 (cpcie_smlh_ls2_g4_eq_req),
    .smlh_ls2_g4_eq_success             (cpcie_smlh_ls2_g4_eq_success),
    .smlh_ls2_g4_eq_cmpl                (cpcie_smlh_ls2_g4_eq_cmpl),
    .smlh_ls2_g4_eq_enter               (cpcie_smlh_ls2_g4_eq_enter),
    .smlh_lec_g4_pset_ltx               (cpcie_smlh_lec_g4_pset_ltx),
    .smlh_lec_g4_pset_lrx               (cpcie_smlh_lec_g4_pset_lrx),
    .smlh_ls2_g5_eq_req                 (cpcie_smlh_ls2_g5_eq_req),
    .smlh_ls2_g5_eq_success             (cpcie_smlh_ls2_g5_eq_success),
    .smlh_ls2_g5_eq_cmpl                (cpcie_smlh_ls2_g5_eq_cmpl),
    .smlh_ls2_g5_eq_enter               (cpcie_smlh_ls2_g5_eq_enter),
    .smlh_lec_g5_pset_ltx               (cpcie_smlh_lec_g5_pset_ltx),
    .smlh_lec_g5_pset_lrx               (cpcie_smlh_lec_g5_pset_lrx),
    .smlh_elbc_rcvd                     (smlh_elbc_rcvd),
    .smlh_deprecode_on                  (smlh_deprecode_on),
    .smlh_precoding_on                  (smlh_precoding_on),
    .smlh_precoding_on_latched          (smlh_precoding_on_latched),
    .smlh_noeq_needed_rcvd              (smlh_noeq_needed_rcvd),
    .smlh_ls2_g6_eq_req                 (smlh_ls2_g6_eq_req),
    .smlh_ls2_g6_eq_success             (smlh_ls2_g6_eq_success),
    .smlh_ls2_g6_eq_cmpl                (smlh_ls2_g6_eq_cmpl),
    .smlh_ls2_g6_eq_enter               (smlh_ls2_g6_eq_enter),
    .smlh_lec_g6_pset_ltx               (tmp_smlh_lec_g6_pset_ltx),
    .smlh_lec_g6_pset_lrx               (smlh_lec_g6_pset_lrx),
    .smlh_precoding6_on_latched         (smlh_precoding6_on_latched),
    .ltssm_dsp_g6_eq1_send_ec00         (ltssm_dsp_g6_eq1_send_ec00),
    .smlh_retimer_pre_detected          (cpcie_smlh_retimer_pre_detected),
    .smlh_two_retimers_pre_detected     (smlh_two_retimers_pre_detected),
    .ltssm_gen4_compliance_jmp          (ltssm_gen4_compliance_jmp),
    .ltssm_gen6_compliance_tp           (ltssm_gen6_compliance_tp),
    .smlh_crosslink_resolution          (smlh_crosslink_resolution),
    .smlh_margin_status                 (pl_smlh_margin_status),
    .smlh_margin_status_valid           (pl_smlh_margin_status_valid),
    .smlh_margin_cmd                    (smlh_margin_cmd),
    .smlh_margin_offset                 (smlh_margin_offset),
    .smlh_margin_clr_error_log          (smlh_margin_clr_error_log),
    .smlh_ctlskp_info                   (smlh_ctlskp_info),
    .smlh_margin_ready                  (smlh_margin_ready),
    .smlh_mod_ts_rcvd                   (smlh_mod_ts_rcvd),
    .mod_ts_data_rcvd                   (mod_ts_data_rcvd),
    .smlh_in_l0_l0s                     (smlh_in_l0_l0s),
    .active_nb                          (cpcie_active_nb),
    .active_nb_wire                     (active_nb_wire),
    .active_nb_gen34                    (cpcie_active_nb_gen34),
    .smlh_do_deskew                     (cpcie_smlh_do_deskew),
    .smlh_ltssm_state                   (cpcie_smlh_ltssm_state),
    .smlh_ltssm_state_wire              (smlh_ltssm_state_wire),
    .smlh_in_l0s                        (cpcie_smlh_in_l0s),
    .smlh_in_rl0s                       (cpcie_smlh_in_rl0s),
    .smlh_in_l0                         (cpcie_smlh_in_l0),
    .smlh_in_l1                         (cpcie_smlh_in_l1),
    .smlh_in_l1_p1                      (cpcie_smlh_in_l1_p1),
    .smlh_in_l23                        (cpcie_smlh_in_l23),
    .smlh_l123_eidle_timeout            (cpcie_smlh_l123_eidle_timeout),
    .smlh_ts_link_ctrl                  (cpcie_smlh_ts_link_ctrl),
    .smlh_rcvd_lane_rev                 (cpcie_smlh_rcvd_lane_rev),
    .smlh_ts_link_num                   (cpcie_smlh_ts_link_num),
    .smlh_ts_link_num_is_k237           (cpcie_smlh_ts_link_num_is_k237),
    .smlh_lanes_rcving                  (cpcie_smlh_lanes_rcving),
    .smlh_ts_rcv_err                    (cpcie_smlh_ts_rcv_err),
    .smlh_ts1_rcvd                      (cpcie_smlh_ts1_rcvd),
    .smlh_ts2_rcvd                      (cpcie_smlh_ts2_rcvd),
    .smlh_inskip_rcv                    (cpcie_smlh_inskip_rcv),
    .smlh_ts_lane_num_is_k237           (cpcie_smlh_ts_lane_num_is_k237),
    .latched_rcvd_eidle_set             (cpcie_latched_rcvd_eidle_set),
    .ltssm_rcvr_err_rpt_en              (cpcie_ltssm_rcvr_err_rpt_en),
    .ltssm_clear                        (cpcie_ltssm_clear),
    .ltssm_cmd                          (cpcie_ltssm_cmd),
    .l0s_state                          (cpcie_l0s_state),
    .phy_mac_fs                       (tmp_phy_mac_fs),
    .phy_mac_lf                       (tmp_phy_mac_lf),
    .phy_mac_dirfeedback              (tmp_phy_mac_dirfeedback),
    .phy_mac_fomfeedback              (tmp_phy_mac_fomfeedback),
    .phy_mac_local_tx_pset_coef       (tmp_phy_mac_local_tx_pset_coef),
    .phy_mac_local_tx_coef_valid      (tmp_phy_mac_local_tx_coef_valid),
    .smlh_eqpa_txdeemph                 (cpcie_smlh_eqpa_txdeemph),
    .smlh_blockaligncontrol             (cpcie_smlh_blockaligncontrol),
    .mac_phy_rxpresethint               (cpcie_mac_phy_rxpresethint),
    .mac_phy_fs                         (cpcie_mac_phy_fs),
    .mac_phy_lf                         (cpcie_mac_phy_lf),
    .mac_phy_getlocal_pset_coef         (cpcie_mac_phy_getlocal_pset_coef),
    .mac_phy_local_pset_index           (cpcie_mac_phy_local_pset_index),
    .mac_phy_rxeqinprogress             (cpcie_mac_phy_rxeqinprogress),
    .mac_phy_invalid_req                (cpcie_mac_phy_invalid_req),
    .mac_phy_rxeqeval                   (cpcie_mac_phy_rxeqeval),
    .mac_phy_dirchange                  (cpcie_mac_phy_dirchange),
    .csr_mac_phy_coef_rtx               (cpcie_mac_phy_smlh_coef_rtx),
    .ltssm_powerdown                    (cpcie_ltssm_powerdown),
    .ltssm_lpbk_master                  (cpcie_ltssm_lpbk_master),
    .ltssm_ts_cnt_en                    (cpcie_ltssm_ts_cnt_en),
    .ltssm_ts_cnt_rst                   (cpcie_ltssm_ts_cnt_rst),
    .ltssm_ts_data_rate                 (cpcie_ltssm_ts_data_rate),
    .ltssm_ts_data_rate_eg6             (cpcie_ltssm_ts_data_rate_eg6),
    .latched_ts_data_rate_eg6           (cpcie_latched_ts_data_rate_eg6),
    .ltssm_cmd_eqts0                    (ltssm_cmd_eqts0),
    .ltssm_ts_speed_change              (cpcie_ltssm_ts_speed_change),
    .latched_ts_data_rate               (cpcie_latched_ts_data_rate),
    .ltssm_ts_auto_change               (cpcie_ltssm_ts_auto_change),
    .ltssm_xlinknum                     (cpcie_ltssm_xlinknum),
    .ltssm_xk237_4lannum                (cpcie_ltssm_xk237_4lannum),
    .ltssm_xk237_4lnknum                (cpcie_ltssm_xk237_4lnknum),
    .ltssm_ts_cntrl                     (cpcie_ltssm_ts_cntrl),
    .ltssm_flit_mode_enable             (smlh_flit_mode_enable),                // both sides agreed
    .ltssm_flit_mode_enable_modules     (smlh_flit_mode_enable_modules),        // both sides agreed
    .ltssm_flit_mode_tx                 (ltssm_flit_mode_tx),                   // for TX
    .ltssm_idl_hs_done                  (smlh_idl_hs_done),                     // received 8 idle flits in R.Idle or C.Idle states
    .ltssm_cmd_compliance_ts1           (ltssm_cmd_compliance_ts1),             // sending two Compliance TS1 in Polling.Compliance
    .ltssm_compliance_set_num           (ltssm_compliance_set_num),             // sequence setting number for compliance TS1
    .link_usp_sris_mode                 (smlh_usp_sris_mode),                   // usp recorded sris mode
    .smlh_l0p_update                    (smlh_l0p_update),
    .smlh_l0p_next_link_mode            (smlh_l0p_next_link_mode),
    .smlh_l0p_link_mode                 (smlh_l0p_link_mode),
    .ltssm_l0p_lanes_active             (ltssm_l0p_lanes_active),
    .ltssm_l0p_last_lanes_active        (ltssm_l0p_last_lanes_active),
    .ltssm_l0p_cmd                      (ltssm_l0p_cmd),
    .ltssm_l0p_cmd_4_eieos_req          (ltssm_l0p_cmd_4_eieos_req),
    .smlh_l0p_capable                   (smlh_l0p_capable),
    .smlh_ltssm_in_l0p                  (smlh_ltssm_in_l0p),
    .smlh_ltssm_in_l0p_upsize           (smlh_ltssm_in_l0p_upsize),
    .smlh_ltssm_l0p_ready               (smlh_ltssm_l0p_ready),
    .smlh_flit_error_link_widh          (), // unused
    .smlh_xdlh_eios_rcvd                (smlh_xdlh_eios_rcvd),
    .smlh_pm_state_trans1_flag          (smlh_pm_state_trans1_flag),
    .smlh_pm_state_trans2_flag          (smlh_pm_state_trans2_flag),
    .ltssm_mod_ts                       (ltssm_mod_ts),
    .ltssm_ts_alt_protocol              (cpcie_ltssm_ts_alt_protocol),
    .ltssm_no_idle_need_sent            (cpcie_ltssm_no_idle_need_sent),
    .ltssm_ts_alt_prot_info             (cpcie_ltssm_ts_alt_prot_info),
    .ltssm_mod_ts_data_sent             (ltssm_mod_ts_data_sent),
    .cxl_link_enable                    (cxl_link_enable),
    .pl_protocol_cfg                    (smlh_protocol_cfg),
    .ltssm_cxl_enable                   (cpcie_ltssm_cxl_enable), 
    .cxl_sh_bypass                      (cxl_sh_bypass),
    .cxl_io_throttle_enable             (cxl_io_throttle_enable),
    .ltssm_cxl_mod_ts_phase1_rcvd       (cpcie_ltssm_cxl_mod_ts_phase1_rcvd),
    .ltssm_cxl_retimers_pre_mismatched  (cpcie_ltssm_cxl_retimers_pre_mismatched),
    .ltssm_cxl_flexbus_phase2_mismatched (cpcie_ltssm_cxl_flexbus_phase2_mismatched),
    .ltssm_cxl_ll_mod                   (ltssm_cxl_ll_mod),
    .ltssm_in_lpbk                      (cpcie_ltssm_in_lpbk),
    .ltssm_eidle_cnt                    (cpcie_ltssm_eidle_cnt),
    .ltssm_in_lpbkentry                 (cpcie_ltssm_in_lpbkentry),
    .eqctl_eqts_info                    (cpcie_eqctl_eqts_info),
    .eqctl_eqts_info_ts0                (eqctl_eqts_info_ts0),
    .eqctl_g6_tx_ts0                    (eqctl_g6_tx_ts0),
    .link_rx_ts0_to_ts1_pulse           (link_rx_ts0_to_ts1_pulse),
    .ltssm_perform_eq_for_lpbk_g6       (ltssm_perform_eq_for_lpbk_g6),
    .ltssm_in_lpbk_wo_l0                (ltssm_in_lpbk_wo_l0),
    .ltssm_cfg_to_lpbk_active_master_g6 (ltssm_cfg_to_lpbk_active_master_g6),
    .eqctl_mask_eieos                   (cpcie_eqctl_mask_eieos),
    .eqctl_2mask_eieos_pulse            (cpcie_eqctl_2mask_eieos_pulse),
    .eqctl_pset_ltx                     (cpcie_eqctl_pset_ltx),
    .ltssm_lpbk_slave_lut               (ltssm_lpbk_slave_lut),
    .muxed_n_fts                        (cpcie_muxed_n_fts),
    .latched_ts_nfts                    (cpcie_latched_ts_nfts),
    .smseq_invalid_os_bus               (pl_smseq_invalid_os_bus),
    .smseq_os_corrected_bus             (pl_smseq_os_corrected_bus),
    .smlh_debug_info_ei                 (cpcie_cxpl_debug_info_ei),
    .smlh_lane_flip_ctrl                (cpcie_smlh_lane_flip_ctrl),
    .latched_flip_ctrl                  (latched_flip_ctrl),
    .lpbk_lane_under_test               (lpbk_lane_under_test),
    .ltssm_lane_flip_ctrl               (cpcie_ltssm_lane_flip_ctrl),
    .pm_hold_exit_l1                    (pm_hold_exit_l1),
    .pm_link_exit_l1                    (pm_link_exit_l1),
    .cfg_pm_clk_pm_en                   (cfg_pm_clk_pm_en),
    .cfg_pl_l1_nowait_p1                (cfg_pl_l1_nowait_p1),
    .pm_linkst_in_l0s                   (pm_linkst_in_l0s),
    .pm_link_exit_l23                   (pm_link_exit_l23),
    .pm_current_data_rate               (pm_current_data_rate_others),
    .pm_pl_wake_ack                     (pm_pl_wake_ack),
    .pm_pl_clk_req                      (pm_pl_clk_req),
    .pm_pl_phyinl1                      (pm_pl_phyinl1),
    .pm_pl_phyinl2                      (pm_pl_phyinl2),
    .pm_usp_link_state                  (pm_usp_link_state),
    .pm_dsp_link_state                  (pm_dsp_link_state),
    .pm_smlh_l1_exit                    (pm_smlh_l1_exit),
    .pm_smlh_l23_exit                   (pm_smlh_l23_exit),
    .pm_protocol_to_link_signals        (pm_protocol_to_link_signals),
    .pm_link_to_protocol_signals        (pm_link_to_protocol_signals)
    ,
    .splh_pm_req_l0s                    (splh_pm_req_l0s),
    .splh_pm_req_l1                     (splh_pm_req_l1),
    .splh_pm_req_l2                     (splh_pm_req_l2)
    ,
    .smlh_eidle_inferred_in_l0          (cpcie_smlh_eidle_inferred_in_l0),
    .smlh_rx_rcvry_req                  (cpcie_smlh_rx_rcvry_req),
    .smlh_timeout_nfts                  (cpcie_smlh_timeout_nfts),
    .smlh_l0_to_recovery                (cpcie_smlh_l0_to_recovery),
    .smlh_l1_to_recovery                (cpcie_smlh_l1_to_recovery),
    .smlh_rcv_eios_when_l0s_unsprt      (cpcie_smlh_rcv_eios_when_l0s_unsprt),
    .smlh_deskew_uncomplete_err         (cpcie_smlh_deskew_uncomplete_err),
    .smlh_spd_change                    (cpcie_smlh_spd_change),
    .smseq_mcs_sts                      (cpcie_smseq_mcs_sts),
    .smlh_lwd_change                    (cpcie_smlh_lwd_change),
    .smlh_ltssm_variable                (cpcie_smlh_ltssm_variable),
    .smseq_ts_debug_info                (cpcie_smseq_ts_debug_info),
    .smlh_rxos_type                     (cpcie_smlh_rxos_type)
    ,
    .init_eq_pending                    (cpcie_init_eq_pending) 
    ,
    .mac_cdm_ras_des_fs                 (cpcie_mac_cdm_ras_des_fs),
    .mac_cdm_ras_des_lf                 (cpcie_mac_cdm_ras_des_lf),
    .mac_cdm_ras_des_coef_ltx           (cpcie_mac_cdm_ras_des_coef_ltx),
    .phy_cdm_ras_des_fomfeedback        (cpcie_phy_cdm_ras_des_fomfeedback),
    .eqpa_violate_rule_123              (cpcie_eqpa_violate_rule_123),
    .eq_convergence_sts                 (cpcie_eq_convergence_sts),
    .mac_cdm_ras_des_coef_rtx           (cpcie_mac_cdm_ras_des_coef_rtx),
    .mac_cdm_ras_des_pset_lrx           (cpcie_mac_cdm_ras_des_pset_lrx),
    .mac_cdm_ras_des_reject_rtx         (cpcie_mac_cdm_ras_des_reject_rtx)
    ,
    .init_eq_pending_g4                 (cpcie_init_eq_pending_g4) 
    ,
    .mac_cdm_ras_des_fs_g4              (cpcie_mac_cdm_ras_des_fs_g4),
    .mac_cdm_ras_des_lf_g4              (cpcie_mac_cdm_ras_des_lf_g4),
    .mac_cdm_ras_des_coef_ltx_g4        (cpcie_mac_cdm_ras_des_coef_ltx_g4),
    .phy_cdm_ras_des_fomfeedback_g4     (cpcie_phy_cdm_ras_des_fomfeedback_g4),
    .eqpa_violate_rule_123_g4           (cpcie_eqpa_violate_rule_123_g4),
    .eq_convergence_sts_g4              (cpcie_eq_convergence_sts_g4),
    .mac_cdm_ras_des_coef_rtx_g4        (cpcie_mac_cdm_ras_des_coef_rtx_g4),
    .mac_cdm_ras_des_reject_rtx_g4      (cpcie_mac_cdm_ras_des_reject_rtx_g4)
    ,
    .init_eq_pending_g5                 (cpcie_init_eq_pending_g5) 
    ,
    .mac_cdm_ras_des_fs_g5              (cpcie_mac_cdm_ras_des_fs_g5),
    .mac_cdm_ras_des_lf_g5              (cpcie_mac_cdm_ras_des_lf_g5),
    .mac_cdm_ras_des_coef_ltx_g5        (cpcie_mac_cdm_ras_des_coef_ltx_g5),
    .phy_cdm_ras_des_fomfeedback_g5     (cpcie_phy_cdm_ras_des_fomfeedback_g5),
    .eqpa_violate_rule_123_g5           (cpcie_eqpa_violate_rule_123_g5),
    .eq_convergence_sts_g5              (cpcie_eq_convergence_sts_g5),
    .mac_cdm_ras_des_coef_rtx_g5        (cpcie_mac_cdm_ras_des_coef_rtx_g5),
    .mac_cdm_ras_des_reject_rtx_g5      (cpcie_mac_cdm_ras_des_reject_rtx_g5)
    ,
    .init_eq_pending_g6                 (cpcie_init_eq_pending_g6) 
    ,
    .mac_cdm_ras_des_fs_g6              (cpcie_mac_cdm_ras_des_fs_g6),
    .mac_cdm_ras_des_lf_g6              (cpcie_mac_cdm_ras_des_lf_g6),
    .mac_cdm_ras_des_coef_ltx_g6        (cpcie_mac_cdm_ras_des_coef_ltx_g6),
    .phy_cdm_ras_des_fomfeedback_g6     (cpcie_phy_cdm_ras_des_fomfeedback_g6),
    .eqpa_violate_rule_123_g6           (cpcie_eqpa_violate_rule_123_g6),
    .eqpa_violate_rule_4_g6             (cpcie_eqpa_violate_rule_4_g6),
    .eq_convergence_sts_g6              (cpcie_eq_convergence_sts_g6),
    .mac_cdm_ras_des_coef_rtx_g6        (cpcie_mac_cdm_ras_des_coef_rtx_g6),
    .mac_cdm_ras_des_reject_rtx_g6      (cpcie_mac_cdm_ras_des_reject_rtx_g6)
    ,
    .smlh_fast_time_1ms                 (smlh_fast_time_1ms),
    .smlh_fast_time_2ms                 (smlh_fast_time_2ms),
    .smlh_fast_time_3ms                 (smlh_fast_time_3ms),
    .smlh_fast_time_4ms                 (smlh_fast_time_4ms),
    .smlh_fast_time_10ms                (smlh_fast_time_10ms),
    .smlh_fast_time_12ms                (smlh_fast_time_12ms),
    .smlh_fast_time_24ms                (smlh_fast_time_24ms),
    .smlh_fast_time_32ms                (smlh_fast_time_32ms),
    .smlh_fast_time_48ms                (smlh_fast_time_48ms),
    .smlh_fast_time_64ms                (smlh_fast_time_64ms),
    .smlh_fast_time_100ms               (smlh_fast_time_100ms)
); //smlh


// Layer 1 Transmit
wire unlinkup_mod_ts = cfg_lut_ctrl[0] & ~smlh_link_up & (pm_current_data_rate_others < `GEN3_RATE) & (smlh_ltssm_state == S_CFG_LANENUM_WAIT || smlh_ltssm_state == S_CFG_LANENUM_ACEPT || smlh_ltssm_state == S_CFG_COMPLETE); // TX mod_ts only in ~linkup & Gen1/2 rate
xmlh

#(INST) u_xmlh(
    .pm_xmlh_lp_req                     (pm_xmlh_lp_req),              
    .xmlh_cmd_if_lp_ack                 (int_xmlh_cmd_if_lp_ack), 
    .ltssm_idl_hs_done                  (smlh_idl_hs_done),                     // received 8 idle flits in R.Idle or C.Idle states
    .core_clk                           (core_clk),
    .core_rst_n                         (core_rst_n),
    .b_xplh_xmlh_sp                     (b_xplh_xmlh.slave_mp),
    .cxl_sh_bypass                      (cxl_sh_bypass),
    .cxl_mode_enable                    (cxl_link_enable),
    .app_sris_mode                      (app_sris_mode),
    .sticky_rst_n                       (sticky_rst_n),
    .cfg_flit_sris_clocking             (cfg_flit_sris_clocking),
    .cfg_comm_clk_config                (cfg_comm_clk_config),
    .latched_smlh_link_up               (latched_smlh_link_up),
    .smlh_link_up                       (smlh_link_up),
    .latched_flip_ctrl                  (latched_flip_ctrl),
    .smlh_lane_flip_ctrl                (cpcie_ltssm_lane_flip_ctrl),
    .ltssm_lpbk_slave_lut               (ltssm_lpbk_slave_lut),
    .muxed_n_fts                        (muxed_n_fts),
    .cfg_link_capable                   (cfg_link_capable),
    .cfg_fast_link_mode                 (cfg_fast_link_mode),
    .cfg_skip_interval                  (cfg_skip_interval),
    .cfg_ext_synch                      (cfg_ext_synch),
    .cfg_mod_ts                         (unlinkup_mod_ts),
    .cfg_upstream_port                  (cfg_upstream_port),
    .cfg_no_seed_value_change           (cfg_no_seed_value_change),
    .cfg_pl_gen3_control                (cfg_pl_gen3_control),
    .cfg_margin_control                 (tmp_cfg_margin_control),
    .smlh_ctlskp_info                   (smlh_ctlskp_info),
    .smlh_gen3_error_count              (smlh_gen3_error_count),
    .smlh_ltssm_in_compliance           (smlh_ltssm_in_compliance),
    .eqctl_eqts_info                    (eqctl_eqts_info),
    .eqctl_eqts_info_ts0                (eqctl_eqts_info_ts0),
    .eqctl_g6_tx_ts0                    (eqctl_g6_tx_ts0),
    .link_rx_ts0_to_ts1_pulse           (link_rx_ts0_to_ts1_pulse),
    .eqctl_mask_eieos                   (eqctl_mask_eieos),
    .eqctl_2mask_eieos_pulse            (eqctl_2mask_eieos_pulse),
    .eqctl_pset_ltx                     (eqctl_pset_ltx),
    .ltssm_in_lpbkentry                 (ltssm_in_lpbkentry),
    .ltssm_cmd_send_eieos_for_pset_map  (ltssm_cmd_send_eieos_for_pset_map),
    .ltssm_usp_eq_redo                  (ltssm_usp_eq_redo),
    .smlh_margin_cmd                    (smlh_margin_cmd),
    .smlh_margin_offset                 (smlh_margin_offset),
    .smlh_margin_clr_error_log          (smlh_margin_clr_error_log),
    .ltssm_dsp_g6_eq1_send_ec00         (ltssm_dsp_g6_eq1_send_ec00),
    .current_data_rate_xmt              (pm_current_data_rate_xmlh_xmt),
    .current_data_rate_scr              (pm_current_data_rate_xmlh_scr),
    .active_nb_wire                     (active_nb_wire),
    .active_nb_gen34                    (active_nb_gen34),
    .phy_mac_phystatus                  (in_cxpl_phy_mac_phystatus),
    .cfg_compliance_sos                 (cfg_compliance_sos),
    .smlh_mcs_rcvd                      (smlh_mcs_rcvd),
    .rpipe_rxerror                      (rpipe_rxerror),
    .ltssm_ts_cnt_en                    (ltssm_ts_cnt_en),
    .ltssm_ts_cnt_rst                   (ltssm_ts_cnt_rst),
    .ltssm_ts_speed_change              (ltssm_ts_speed_change),
    .ltssm_ts_data_rate                 (ltssm_ts_data_rate),
    .latched_ts_data_rate               (latched_ts_data_rate),
    .ltssm_ts_data_rate_eg6             (ltssm_ts_data_rate_eg6),
    .latched_ts_data_rate_eg6           (latched_ts_data_rate_eg6),
    .ltssm_cmd_eqts0                    (ltssm_cmd_eqts0),
    .ltssm_ts_auto_change               (ltssm_ts_auto_change),
    .ltssm_xlinknum                     (ltssm_xlinknum),
    .ltssm_xk237_4lannum                (ltssm_xk237_4lannum),
    .ltssm_xk237_4lnknum                (ltssm_xk237_4lnknum),
    .ltssm_ts_cntrl                     (ltssm_ts_cntrl),
    .smlh_in_l0                         (smlh_in_l0),
    .xmlh_xplh_cmd                      (xmlh_xplh_cmd),
    .xplh_xmlh_cmd_ack                  (xplh_xmlh_cmd_ack),
    .xfsh_xmlh_buf_empty                (1'b1),
    .ltssm_flit_mode_enable             (smlh_flit_mode_enable_modules[4]),
    .ltssm_flit_mode_tx                 (ltssm_flit_mode_tx),
    .smlh_usp_sris_mode                 (smlh_usp_sris_mode),
    .ltssm_cmd_compliance_ts1           (ltssm_cmd_compliance_ts1),
    .ltssm_compliance_set_num           (ltssm_compliance_set_num),
    .xplh_xmlh_sof                      (xplh_xmlh_sof),
    .xmtbyte_2_compliance_ts1_sent      (xmtbyte_2_compliance_ts1_sent),
    .xmtbyte_sris_mode_enabled          (xmlh_sris_mode_enabled),
    .xmlh_fm_pending                    (xmlh_fm_pending),
    .xmlh_xfsh_last_flit                (xmlh_xfsh_last_flit),
    .xmbyte_flit_data_stream            (xmbyte_flit_data_stream),
    .smlh_l0p_update                    (smlh_l0p_update),
    .smlh_l0p_next_link_mode            (smlh_l0p_next_link_mode),
    .smlh_l0p_link_mode                 (smlh_l0p_link_mode),
    .ltssm_l0p_lanes_active             (ltssm_l0p_lanes_active),
    .ltssm_l0p_last_lanes_active        (ltssm_l0p_last_lanes_active),
    .ltssm_l0p_cmd                      (ltssm_l0p_cmd),
    .ltssm_l0p_cmd_4_eieos_req          (ltssm_l0p_cmd_4_eieos_req),
    .xmtbyte_l0p_eidle_sent             (xmtbyte_l0p_eidle_sent),
    .xmtbyte_l0p_ts1_sent               (xmtbyte_l0p_ts1_sent),
    .xmtbyte_l0p_ts2_sent               (xmtbyte_l0p_ts2_sent),
    .xmtbyte_l0p_linkwidth_changed      (xmtbyte_l0p_linkwidth_changed),
    .xmtbyte_l0p_link_in_training       (xmtbyte_l0p_link_in_training),
    .xmtbyte_l0p_sris_mode_enabled      (xmtbyte_l0p_sris_mode_enabled),
    .xmtbyte_l0p_state_in_upsize        (xmtbyte_l0p_state_in_upsize),
    .ltssm_mod_ts                       (ltssm_mod_ts),
    .ltssm_ts_alt_protocol              (cpcie_ltssm_ts_alt_protocol),
    .ltssm_no_idle_need_sent            (cpcie_ltssm_no_idle_need_sent),
    .ltssm_ts_alt_prot_info             (cpcie_ltssm_ts_alt_prot_info),
    .ltssm_eidle_cnt                    (ltssm_eidle_cnt),
    .ltssm_clear                        (ltssm_clear),
    .ltssm_cmd                          (ltssm_cmd),
    .ltssm_powerdown                    (ltssm_powerdown),
    .ltssm_lpbk_master                  (ltssm_lpbk_master),
    .ltssm_in_lpbk                      (ltssm_in_lpbk),
    .ltssm_in_lpbk_active               (ltssm_in_lpbk_active),
    .latched_ts_nfts                    (latched_ts_nfts),
    .smlh_link_mode                     (smlh_link_mode),
    .smlh_lanes_active                  (smlh_lanes_active),
    .lpbk_eq_lanes_active               (lpbk_eq_lanes_active),
    .power_saving_lanes_active          (power_saving_txlanes_active),
    .smlh_no_turnoff_lanes              (smlh_no_turnoff_lanes),
    .smlh_ltssm_state_wire              (smlh_ltssm_state_wire),
    .smlh_ltssm_next                    (smlh_ltssm_next),
    .smlh_ltssm_last                    (smlh_ltssm_last),
    .smlh_scrambler_disable             (smlh_scrambler_disable),
    .ltssm_gen4_compliance_jmp          (ltssm_gen4_compliance_jmp),
    .ltssm_gen6_compliance_tp           (ltssm_gen6_compliance_tp),
    .smlh_tx_precoding_on               (smlh_precoding_on),
    .cdm_ras_des_eidle_cnt_sel          (cdm_ras_des_eidle_cnt_sel),
    .cdm_ras_des_einj0_enable           (pl_cdm_ras_des_einj0_enable),
    .cdm_ras_des_einj0_crc_type         (pl_cdm_ras_des_einj0_crc_type),
    .cdm_ras_des_einj3_enable           (pl_cdm_ras_des_einj3_enable),
    .cdm_ras_des_einj3_count            (pl_cdm_ras_des_einj3_count),
    .cdm_ras_des_einj3_smb_type         (pl_cdm_ras_des_einj3_smb_type),
    .cfg_flit_err_inj_latency           (cfg_flit_err_inj_latency),
    .cfg_os_einj_ctrl_1                 (cfg_os_einj_ctrl_1),
    .cfg_os_einj_ctrl_2                 (cfg_os_einj_ctrl_2),
    .xmlh_tx_os_einj_status             (xmlh_tx_os_einj_status),
    .xmlh_protocol_cfg                  (smlh_protocol_cfg    ),
    .splh_cmd_if_pmreq_ack              (splh_cmd_if_pmreq_ack),
    .splh_cmd_if_stall_ack              (splh_cmd_if_stall_ack),
    .splh_cmd_if_pending                (splh_cmd_if_pending  ),
    .cfg_lpbk_en                        (cfg_lpbk_en),
    .cfg_prbs_en                        (cfg_prbs_en),
// ---- outputs ---------------
    .xmtbyte_sris_enable                (xmlh_sris_enable),
    .xmtbyte_stp_start                  (xmtbyte_stp_start),

    .xmtbyte_ts_pcnt                    (xmtbyte_ts_pcnt),
    .xmtbyte_ts_data_diff               (xmtbyte_ts_data_diff),
    .xmtbyte_1024_ts_sent               (xmtbyte_1024_ts_sent),
    .xmtbyte_spd_chg_sent               (xmtbyte_spd_chg_sent),
    .xmtbyte_dis_link_sent              (xmtbyte_dis_link_sent),
    .xmtbyte_loe_2_ts1_ec_00b_sent      (xmtbyte_loe_2_ts1_ec_00b_sent),
    .xmlh_cmd_is_data                   (xmlh_cmd_is_data),
    .xmlh_scramble_even_parity          (xmlh_scramble_even_parity),
    .mac_phy_txdata                     (tmp_mac_phy_txdata),
    .mac_phy_txdatak                    (tmp_mac_phy_txdatak),
    .mac_phy_txdatavalid                (tmp_mac_phy_txdatavalid),
    .mac_phy_txstartblock               (tmp_mac_phy_txstartblock),
    .mac_phy_txsyncheader               (tmp_mac_phy_txsyncheader),
    .mac_phy_txdetectrx_loopback        (cpcie_mac_phy_txdetectrx_loopback),
    .mac_phy_txelecidle                 (tmp_ltssm_txelecidle),
    .mac_phy_txcompliance               (cpcie_mac_phy_txcompliance),
    .mac_phy_margin_cmd                 (tmp_mac_phy_margin_cmd),
    .mac_phy_margin_offset              (tmp_mac_phy_margin_offset),
    .mac_phy_margin_clr_error_log       (tmp_mac_phy_margin_clr_error_log),
    .xmtbyte_skip_sent                  (xmtbyte_skip_sent),
    .xmtbyte_skip_insert                (), // unused
    .xmtbyte_ctlskip_sent               (xmtbyte_ctlskip_sent),
    .xmtbyte_sent_24_ts0_ec00           (xmlh_sent_24_ts0_ec00),
    .xmtbyte_ts1_sent                   (xmtbyte_ts1_sent),
    .xmtbyte_ts2_sent                   (xmtbyte_ts2_sent),
    .xmtbyte_idle_sent                  (xmtbyte_idle_sent),
    .xmtbyte_eidle_sent                 (xmtbyte_eidle_sent),
    .xmtbyte_eies_sent                  (xmtbyte_eies_sent),
    .xmtbyte_fts_sent                   (xmtbyte_fts_sent),
    .xmtbyte_txdata_dv                  (xmtbyte_txdata_dv),
    .xmtbyte_txdata                     (xmtbyte_txdata),
    .xmtbyte_txdatak                    (xmtbyte_txdatak),
    .xmtbyte_txelecidle                 (xmtbyte_txelecidle),
    .xmtbyte_txdetectrx_loopback        (xmtbyte_txdetectrx_loopback),
    .xpipe_txdata_osfound               (tmp_txdata_osfound),
    .xpipe_powerdown                    (tmp_xmlh_powerdown)
    ,
    .xmlh_einj0_oscrc_evt               (pl_xmlh_einj0_oscrc_evt),
    .xmlh_einj3_osmsk_evt               (pl_xmlh_einj3_osmsk_evt) 
); //xmlh


// Layer2 Physical Layer Packet Interface
xplh
 u_xplh (
  .b_xplh_spif                ( b_xplh_spif.xplh_master_mp    ),
  .xplh_protocol_cfg          ( splh_protocol_cfg             ),
  .xplh_stall_req             ( b_smlh_spif.s_pl_stall_req    ),
  .xplh_stall_ack             ( b_smlh_spif.s_lp_stall_ack    ),
  .xplh_linkerror             ( xplh_linkerror                ),
  .xplh_link_mode             ( b_smlh_spif.s_pl_linkmode     ),
  .cfg_rasdp_linkdown_en      ( cfg_rasdp_linkdown_en         ),
  .xplh_pm_dllp_ack           (xplh_pm_dllp_ack),
  .pm_xdlh_dllp_req           (pm_xdlh_dllp_req),
  .cfg_upstream_port          (cfg_upstream_port),
  .xplh_nak_ignore_link_err   (xplh_nak_ignore_link_err),
  .en_tx_throttling               (cfg_tx_throttling),
  .current_data_rate          (current_data_rate),
  .mac_phy_rate               (tmp_int_mac_phy_rate),
  .xplh_flit_count            (xplh_flit_count),
  .xplh_flit_count_en         (xplh_flit_count_en),
  .core_clk                   (core_clk),
  .core_rst_n                 (core_rst_n)
  ,
  .b_xplh_xmlh_mp             (b_xplh_xmlh.master_mp)
  ,  
  .b_xdlh_xplh_sp             (b_xdlh_xplh_sp),
  .xplh_sideband              (xplh_sideband)
  // CXL Configuration Interface with LTSSM
  ,.cxl_io_throttle_enable    ( cxl_io_throttle_enable        )
  ,.xplh_payload_enable       ( smlh_in_l0                    )
  ,
  .xplh_xdlh_cmd              (xplh_xdlh_cmd),
  .xdlh_xplh_cmd_ack          (xdlh_xplh_cmd_ack),
  .xmlh_xplh_cmd              (splh_xplh_cmd),
  .xplh_xmlh_cmd_ack          (xplh_splh_cmd_ack)
  //
  //RAS-DES
  ,
  .cdm_ras_des_einj1_enable             (xplh_ras_des_einj1_enable),
  .cdm_ras_des_einj1_seq_type           (xplh_ras_des_einj1_seq_type),
  .cdm_ras_des_einj1_bad_seq            (xplh_ras_des_einj1_bad_seq),
  .cdm_ras_des_einj1_count              (xplh_ras_des_einj1_count),
  .xplh_ras_des_einj1_exp_sequm_evt     (xplh_ras_des_einj1_exp_sequm_evt),     
  .xplh_ras_des_einj1_ack_nak_sequm_evt (xplh_ras_des_einj1_ack_nak_sequm_evt)
   ,
  .xmlh_stp_start             (xmtbyte_stp_start),
  .xplh_ptm_sot               (xplh_ptm_sot),
  .xplh_ptm_request           (xplh_ptm_request),
  .xplh_ptm_response          (xplh_ptm_response),
  .retryram_data              (retrymux_xplh_data),
  .xplh_rasdes_fm             (xplh_rasdes_fm),
  .xplh_rx_ack_seqnum         (xplh_rx_ack_seqnum),
  .xplh_tx_seqnum_value       (xplh_tx_seqnum_value),
  .cdm_ras_des_force_linkdown_noack (cdm_ras_des_force_linkdown_noack),
  .xplh_req_link_down         (xplh_req_link_down),
  .xplh_retry_ram_if          (xplh_retry_ram_if),
  .xplh_smlh_req_rcvry        (xplh_smlh_req_rcvry),
  .rplh_xplh_fm_retry         (rplh_xplh_fm_retry),
  .xplh_xdlh_dllp_halt        (xplh_xdlh_dllp_halt),
  .xdlh_xplh_fm_dllp          (xdlh_xplh_dllp_out),
  .xplh_pending               (xplh_pending)
  ,
  .xplh_ras_dp_err_log        (xplh_ras_dp_err_log)
  ,
  .ras_dp_err_inj             (ras_dp_err_inj)
  ,
  .xplh_acknak_pend           (xplh_acknak_pend),
  .link_width                 (smlh_autoneg_link_width)
    ,  
  .cdm_xplh_flit_response_type     (cdm_xplh_flit_response_type),
  .cdm_xplh_flit_type_measured     (cdm_xplh_flit_type_measured),
  .cdm_xplh_flit_track_mode        (cdm_xplh_flit_track_mode),
  .xplh_cdm_flit_latency_tracking  (xplh_cdm_flit_latency_tracking)
  ,
  .cdm_plh_flit_err_inj_interface  (cdm_plh_flit_err_inj_interface),
  .xplh_cdm_flit_err_inj_status    (xplh_cdm_flit_err_inj_status)
); // u_xplh


// ======================================================================================
// ======================================================================================
//
// muxes added for enabling lane flip functions
//
lane_flip
 #(
  .L2NL (`CX_L2NL)
) u_lane_flip (
    // ------------------ Inputs - Controls ------------------
    .core_clk                                       (core_clk),
    .core_clk_ug                                    (core_clk_ug),
    .core_rst_n                                     (core_rst_n),
    .lane_under_test_i                              (lut_ctrl),
    .pm_rx_lane_flip_en_i                           (pm_rx_lane_flip_en),
    .pm_tx_lane_flip_en_i                           (pm_tx_lane_flip_en),
    .pm_rx_pol_lane_flip_ctrl_i                     (pm_rx_pol_lane_flip_ctrl_i),

    // ------------------ Inputs - Rx Muxes ------------------
    .int_phy_mac_rxstandbystatus_i                  (int_phy_mac_rxstandbystatus),
    .int_phy_mac_rxdata_i                           (int_phy_mac_rxdata),
    .int_phy_mac_rxdatak_i                          (int_phy_mac_rxdatak),
    .int_phy_mac_rxdatavalid_i                      (int_phy_mac_rxdatavalid),
    .int_phy_mac_rxstartblock_i                     (int_phy_mac_rxstartblock),
    .int_phy_mac_rxsyncheader_i                     (int_phy_mac_rxsyncheader),
    .int_phy_mac_fs_i                               (int_phy_mac_fs),
    .int_phy_mac_lf_i                               (int_phy_mac_lf),
    .int_phy_mac_dirfeedback_i                      (int_phy_mac_dirfeedback),
    .int_phy_mac_fomfeedback_i                      (int_phy_mac_fomfeedback),
    .int_phy_mac_local_tx_coef_valid_i          (int_phy_mac_local_tx_coef_valid),
    .int_phy_mac_local_tx_pset_coef_i           (int_phy_mac_local_tx_pset_coef),
    .int_phy_mac_margin_status_i                (int_phy_mac_margin_status),
    .int_phy_mac_margin_nak_i                   (int_phy_mac_margin_nak),
    .int_phy_mac_margin_error_cnt_i             (int_phy_mac_margin_error_cnt),
    .int_phy_mac_margin_sampl_cnt_i             (int_phy_mac_margin_sampl_cnt),
    .int_phy_mac_rxvalid_i                      (int_phy_mac_rxvalid),
    .int_phy_mac_rxelecidle_i                   (int_phy_mac_rxelecidle),
    .int_phy_mac_rxstatus_i                     (int_phy_mac_rxstatus),
    .int_phy_mac_phystatus_i                    (int_phy_mac_phystatus),
    .int_cdm_ras_des_force_rxdetected_i             (int_cdm_ras_des_force_rxdetected),
    .int_cfg_lec_pset_ltx_i                         (int_cfg_lec_pset_ltx),
    .int_cfg_lec_pset_lrx_i                         (int_cfg_lec_pset_lrx),
    .int_cfg_lec_pset_rtx_i                         (int_cfg_lec_pset_rtx),
    .int_cfg_lec_pset_rrx_i                         (int_cfg_lec_pset_rrx),
    .int_cfg_lec_g4_pset_ltx_i                      (int_cfg_lec_g4_pset_ltx),
    .int_cfg_lec_g4_pset_rtx_i                      (int_cfg_lec_g4_pset_rtx),
    .int_cfg_lec_g5_pset_ltx_i                      (int_cfg_lec_g5_pset_ltx),
    .int_cfg_lec_g5_pset_rtx_i                      (int_cfg_lec_g5_pset_rtx),
    .int_cfg_lec_g6_pset_ltx_i                      (int_cfg_lec_g6_pset_ltx),
    .int_cfg_lec_g6_pset_rtx_i                      (int_cfg_lec_g6_pset_rtx),
    .int_cfg_margin_control_i                       (int_cfg_margin_control),
    .int_rxdata_osfound_i                           (int_rxdata_osfound),
    .int_os_corrected_i                             (int_os_corrected),
    .int_pam4_restricted_levels_wr_ack_pending_i    (int_pam4_restricted_levels_wr_ack_pending),
    .smlh_no_turnoff_lanes                          (smlh_no_turnoff_lanes),

    // ------------------ Outputs - Rx Muxes ------------------
    .tmp_phy_mac_rxstandbystatus                    (tmp_phy_mac_rxstandbystatus),
    .tmp_phy_mac_rxdata                             (tmp_phy_mac_rxdata),
    .tmp_phy_mac_rxdatak                            (tmp_phy_mac_rxdatak),
    .tmp_phy_mac_rxdatavalid                        (tmp_phy_mac_rxdatavalid),
    .tmp_phy_mac_rxstartblock                       (tmp_phy_mac_rxstartblock),
    .tmp_phy_mac_rxsyncheader                       (tmp_phy_mac_rxsyncheader),
    .tmp_phy_mac_fs                                 (tmp_phy_mac_fs),
    .tmp_phy_mac_lf                                 (tmp_phy_mac_lf),
    .tmp_phy_mac_dirfeedback                        (tmp_phy_mac_dirfeedback),
    .tmp_phy_mac_fomfeedback                        (tmp_phy_mac_fomfeedback),
    .tmp_phy_mac_local_tx_coef_valid            (tmp_phy_mac_local_tx_coef_valid),
    .tmp_phy_mac_local_tx_pset_coef             (tmp_phy_mac_local_tx_pset_coef),
    .tmp_phy_mac_margin_status                  (tmp_phy_mac_margin_status),
    .tmp_phy_mac_margin_nak                     (tmp_phy_mac_margin_nak),
    .tmp_phy_mac_margin_error_cnt               (tmp_phy_mac_margin_error_cnt),
    .tmp_phy_mac_margin_sampl_cnt               (tmp_phy_mac_margin_sampl_cnt),
    .tmp_phy_mac_rxvalid                        (tmp_phy_mac_rxvalid),
    .tmp_phy_mac_rxelecidle                     (tmp_phy_mac_rxelecidle),
    .tmp_phy_mac_rxstatus                       (tmp_phy_mac_rxstatus),
    .tmp_phy_mac_phystatus                      (tmp_phy_mac_phystatus),
    .tmp_cdm_ras_des_force_rxdetected           (tmp_cdm_ras_des_force_rxdetected),
    .tmp_cfg_lec_pset_ltx                           (tmp_cfg_lec_pset_ltx),
    .tmp_cfg_lec_pset_lrx                           (tmp_cfg_lec_pset_lrx),
    .tmp_cfg_lec_pset_rtx                           (tmp_cfg_lec_pset_rtx),
    .tmp_cfg_lec_pset_rrx                           (tmp_cfg_lec_pset_rrx),
    .tmp_cfg_lec_g4_pset_ltx                        (tmp_cfg_lec_g4_pset_ltx),
    .tmp_cfg_lec_g4_pset_rtx                        (tmp_cfg_lec_g4_pset_rtx),
    .tmp_cfg_lec_g5_pset_ltx                        (tmp_cfg_lec_g5_pset_ltx),
    .tmp_cfg_lec_g5_pset_rtx                        (tmp_cfg_lec_g5_pset_rtx),
    .tmp_cfg_lec_g6_pset_ltx                        (tmp_cfg_lec_g6_pset_ltx),
    .tmp_cfg_lec_g6_pset_rtx                        (tmp_cfg_lec_g6_pset_rtx),
    .tmp_cfg_margin_control                         (tmp_cfg_margin_control),
    .tmp_rxdata_osfound                             (tmp_rxdata_osfound),
    .tmp_os_corrected                               (tmp_os_corrected),
    .tmp_pam4_restricted_levels_wr_ack_pending      (tmp_pam4_restricted_levels_wr_ack_pending),
    .laneflip_no_turnoff_lanes_o                    (laneflip_no_turnoff_lanes),

    // ------------------ Inputs - Tx Muxes ------------------
    .tmp_mac_phy_rxstandby                          (tmp_mac_phy_rxstandby),
    .tmp_xmlh_powerdown                             (tmp_xmlh_powerdown),
    .tmp_ltssm_powerdown                            (tmp_ltssm_powerdown),
    .tmp_mac_phy_txdeemph                           (tmp_mac_phy_txdeemph),
    .tmp_mac_phy_txmargin                           (tmp_mac_phy_txmargin),
    .tmp_mac_phy_txswing                            (tmp_mac_phy_txswing),
    .tmp_mac_phy_pam4_restricted_levels             (tmp_mac_phy_pam4_restricted_levels),
    .tmp_int_mac_phy_rate                           (tmp_int_mac_phy_rate),
    .tmp_mac_phy_txdata                             (tmp_mac_phy_txdata),
    .tmp_mac_phy_txdatak                            (tmp_mac_phy_txdatak),
    .tmp_mac_phy_txdatavalid                        (tmp_mac_phy_txdatavalid),
    .tmp_mac_phy_txstartblock                       (tmp_mac_phy_txstartblock),
    .tmp_mac_phy_txsyncheader                       (tmp_mac_phy_txsyncheader),
    .tmp_txdata_osfound                             (tmp_txdata_osfound),
    .tmp_mac_phy_rxpresethint                       (tmp_mac_phy_rxpresethint),
    .tmp_mac_phy_fs                                 (tmp_mac_phy_fs),
    .tmp_mac_phy_lf                                 (tmp_mac_phy_lf),
    .tmp_mac_phy_rxeqinprogress                     (tmp_mac_phy_rxeqinprogress),
    .tmp_mac_phy_invalid_req                        (tmp_mac_phy_invalid_req),
    .tmp_mac_phy_rxeqeval                           (tmp_mac_phy_rxeqeval),
    .tmp_mac_phy_dirchange                          (tmp_mac_phy_dirchange),
    .tmp_smlh_eqpa_txdeemph                         (tmp_smlh_eqpa_txdeemph),
    .tmp_mac_phy_local_pset_index                   (tmp_mac_phy_local_pset_index),
    .tmp_mac_phy_coef_rtx                           (tmp_mac_phy_smlh_coef_rtx),
    .tmp_mac_phy_getlocal_pset_coef                 (tmp_mac_phy_getlocal_pset_coef),
    .tmp_rmlh_lane_err                              (tmp_rmlh_lane_err),
    .tmp_smlh_lec_pset_ltx                          (tmp_smlh_lec_pset_ltx),
    .tmp_smlh_lec_pset_lrx                          (tmp_smlh_lec_pset_lrx),
    .tmp_smlh_lec_g4_pset_ltx                       (tmp_smlh_lec_g4_pset_ltx),
    .tmp_smlh_lec_g5_pset_ltx                       (tmp_smlh_lec_g5_pset_ltx),
    .tmp_smlh_lec_g6_pset_ltx                       (tmp_smlh_lec_g6_pset_ltx),
    .tmp_mac_phy_margin_cmd                         (tmp_mac_phy_margin_cmd),
    .tmp_mac_phy_margin_offset                      (tmp_mac_phy_margin_offset),
    .tmp_mac_phy_margin_clr_error_log               (tmp_mac_phy_margin_clr_error_log),
    .tmp_smlh_margin_status_valid                   (tmp_smlh_margin_status_valid),
    .tmp_smlh_margin_status                         (tmp_smlh_margin_status),
    .tmp_rmlh_deskew_ctlskp_err                     (tmp_rmlh_deskew_ctlskp_err),
    .tmp_mac_phy_txdetectrx_loopback                (tmp_mac_phy_txdetectrx_loopback),
    .tmp_ltssm_txelecidle                           (tmp_ltssm_txelecidle),
    .tmp_mac_phy_txcompliance                       (tmp_mac_phy_txcompliance),
    .tmp_mac_phy_rxpolarity                         (tmp_mac_phy_rxpolarity),
    .smlh_lanes_active                              (smlh_lanes_active),
    .smlh_blockaligncontrol                         (smlh_blockaligncontrol),
    .deskew_lanes_active                            (deskew_lanes_active),
    .smlh_set_rxstandby                             (smlh_set_rxstandby),


    // ------------------ Outputs - Tx Muxes ------------------
    .int_mac_phy_rxstandby_o                        (int_mac_phy_rxstandby),
    .int_xmlh_powerdown_o                           (int_xmlh_powerdown),
    .int_ltssm_powerdown_o                          (int_ltssm_powerdown),
    .int_mac_phy_txdeemph_o                         (int_mac_phy_txdeemph),
    .int_mac_phy_txmargin_o                         (int_mac_phy_txmargin),
    .int_mac_phy_txswing_o                          (int_mac_phy_txswing),
    .int_mac_phy_pam4_restricted_levels_o           (int_mac_phy_pam4_restricted_levels),
    .int_mac_phy_rate_o                             (int_mac_phy_rate),
    .int_mac_phy_txdata_o                           (int_mac_phy_txdata),
    .int_mac_phy_txdatak_o                          (int_mac_phy_txdatak),
    .int_mac_phy_txdatavalid_o                      (int_mac_phy_txdatavalid),
    .int_mac_phy_txstartblock_o                     (int_mac_phy_txstartblock),
    .int_mac_phy_txsyncheader_o                     (int_mac_phy_txsyncheader),
    .int_txdata_osfound_o                           (int_txdata_osfound),
    .int_mac_phy_rxpresethint_o                     (int_mac_phy_rxpresethint),
    .int_mac_phy_fs_o                               (int_mac_phy_fs),
    .int_mac_phy_lf_o                               (int_mac_phy_lf),
    .int_mac_phy_rxeqinprogress_o                   (int_mac_phy_rxeqinprogress),
    .int_mac_phy_invalid_req_o                      (int_mac_phy_invalid_req),
    .int_mac_phy_rxeqeval_o                         (int_mac_phy_rxeqeval),
    .int_mac_phy_dirchange_o                        (int_mac_phy_dirchange),
    .int_smlh_eqpa_txdeemph_o                       (int_smlh_eqpa_txdeemph_i),
    .int_mac_phy_local_pset_index_o                 (int_mac_phy_local_pset_index),
    .int_mac_phy_coef_rtx_o                         (int_mac_phy_smlh_coef_rtx),
    .int_mac_phy_getlocal_pset_coef_o               (int_mac_phy_getlocal_pset_coef),
    .int_rmlh_lane_err_o                            (int_rmlh_lane_err),
    .int_smlh_lec_pset_ltx_o                        (int_smlh_lec_pset_ltx),
    .int_smlh_lec_pset_lrx_o                        (int_smlh_lec_pset_lrx),
    .int_smlh_lec_g4_pset_ltx_o                     (int_smlh_lec_g4_pset_ltx),
    .int_smlh_lec_g5_pset_ltx_o                     (int_smlh_lec_g5_pset_ltx),
    .int_smlh_lec_g6_pset_ltx_o                     (int_smlh_lec_g6_pset_ltx),
    .int_mac_phy_margin_cmd_o                       (int_mac_phy_margin_cmd),
    .int_mac_phy_margin_offset_o                    (int_mac_phy_margin_offset),
    .int_mac_phy_margin_clr_error_log_o             (int_mac_phy_margin_clr_error_log),
    .int_smlh_margin_status_valid_o                 (int_smlh_margin_status_valid),
    .int_smlh_margin_status_o                       (int_smlh_margin_status),
    .int_rmlh_deskew_ctlskp_err_o                   (int_rmlh_deskew_ctlskp_err),
    .int_mac_phy_txdetectrx_loopback_o              (int_mac_phy_txdetectrx_loopback),
    .int_ltssm_txelecidle_o                         (int_ltssm_txelecidle_i),
    .int_mac_phy_txcompliance_o                     (int_mac_phy_txcompliance_i),
    .int_mac_phy_rxpolarity_o                       (int_mac_phy_rxpolarity)
    ,
    .laneflip_lanes_active_o                        (laneflip_lanes_active),
    .laneflip_mac_phy_rxstandby_o                   (laneflip_mac_phy_rxstandby),
    .laneflip_smlh_blockaligncontrol_o              (int_smlh_blockaligncontrol),
    .laneflip_deskew_lanes_active_o                 (laneflip_deskew_lanes_active),
    .laneflip_set_rxstandby_o                       (laneflip_set_rxstandby)
); // u_lane_flip

reg  ltssm_master_lpbk_active_after_g5_lpbk_eq_r;
wire ltssm_master_lpbk_active_after_g5_lpbk_eq_i;
always @( posedge core_clk or negedge core_rst_n ) begin : int_mac_phy_txcompliance_r_PROC
    if ( ~core_rst_n )
        int_mac_phy_txcompliance_r <= #`TP 0;
    else if ( ~ltssm_master_lpbk_active_after_g5_lpbk_eq_i )
        int_mac_phy_txcompliance_r <= #`TP int_mac_phy_txcompliance_i;
end // int_mac_phy_txcompliance_r_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : ltssm_master_lpbk_active_after_g5_lpbk_eq_r_PROC
    if ( ~core_rst_n )
        ltssm_master_lpbk_active_after_g5_lpbk_eq_r <= #`TP 0;
    else
        ltssm_master_lpbk_active_after_g5_lpbk_eq_r <= #`TP ltssm_master_lpbk_active_after_g5_lpbk_eq;
end // ltssm_master_lpbk_active_after_g5_lpbk_eq_r_PROC

assign ltssm_master_lpbk_active_after_g5_lpbk_eq_i = ltssm_master_lpbk_active_after_g5_lpbk_eq_r | ltssm_master_lpbk_active_after_g5_lpbk_eq;

always @* begin : force_lane_flip_PROC
    integer ij;

    int_ltssm_txelecidle = {`CX_NL{1'b1}};
    int_mac_phy_txcompliance = {`CX_NL{1'b0}};

    if ( cfg_force_lane_flip || ltssm_master_lpbk_active_after_g5_lpbk_eq_i ) begin // force not cfg_lane_under_test lanes turned off if cfg_force_lane_flip = 1'b1
        for (ij=0; ij<`CX_NL; ij=ij+1) begin
            if ( ij == cfg_lane_under_test ) begin
                int_ltssm_txelecidle[ij] = int_ltssm_txelecidle_i[ij];
                int_mac_phy_txcompliance[ij] = int_mac_phy_txcompliance_i[ij];
            end else begin
                int_ltssm_txelecidle[ij] = 1'b1;

                if ( cfg_force_lane_flip ) begin
                    int_mac_phy_txcompliance[ij] = 1'b1;
                end else begin // ltssm_master_lpbk_active_after_g5_lpbk_eq_i = 1
                    int_mac_phy_txcompliance[ij] = int_mac_phy_txcompliance_r[ij];
                end
            end
        end
    end 
    else if(ltssm_cfg_to_lpbk_active_master_g6) begin
        for (ij=0; ij<`CX_NL; ij=ij+1) begin
            if ( laneflip_lanes_active[ij] ) begin
                int_ltssm_txelecidle[ij] = int_ltssm_txelecidle_i[ij];
    end else begin
                int_ltssm_txelecidle[ij] = 1'b1;
            end
        end
        int_mac_phy_txcompliance = int_mac_phy_txcompliance_i;
    end
    else begin
        int_ltssm_txelecidle = int_ltssm_txelecidle_i;
        int_mac_phy_txcompliance = int_mac_phy_txcompliance_i;
    end
end // force_lane_flip_PROC

 assign in_cxpl_phy_mac_rxdata              = tmp_phy_mac_rxdata;
 assign in_cxpl_phy_mac_rxdatak             = tmp_phy_mac_rxdatak;
 assign in_cxpl_phy_mac_rxvalid             = tmp_phy_mac_rxvalid;
 assign in_cxpl_phy_mac_rxelecidle          = tmp_phy_mac_rxelecidle;
 assign in_cxpl_phy_mac_rxstatus            = tmp_phy_mac_rxstatus;
 assign in_cxpl_phy_mac_phystatus           = tmp_phy_mac_phystatus;


//instance of pipe_adapter
pipe_adapter

#(
   .INST(INST),
   .NL(`CX_NL)
   ,
   .PM_SYNC_DEPTH(`CX_PCIE_SYNC_DEPTH)
) u_pipe_adapter (
    //inputs
    .clk                       (core_clk_ug),
    .rst_n                     (core_rst_n),
      .phy_mac_phystatus              (phy_mac_phystatus_int),

    .aux_clk                   (pm_aux_clk),
    .mac_phy_txcompliance      (mac_phy_txcompliance),
    .pm_en_pulse_det           (pm_en_pulse_det),
    .cfg_elastic_buffer_mode   (cfg_elastic_buffer_mode_i),
    .rate                      (tmp_mac_phy_rate),
    .powerdown                 (int_xmlh_powerdown),
    .smlh_active_nb            (active_nb),
    .smlh_link_mode            (smlh_link_mode),
    .txelecidle                (fstep_mac_phy_txelecidle),
    .rxdatavalid               (lpbk_rxdatavalid),
    .g3_txdatavalid            (mac_phy_txdatavalid_i),
    .g12_pacing_txdatavalid    (mac_phy_pipe_txdatavalid_i),
    .g12_txdeemph              (core_int_mac_phy_txdeemph),
    .g3_txdeemph               (smlh_eqpa_txdeemph),
    .g3_blockaligncontrol      (core_int_pipe_smlh_blockaligncontrol[`CX_BAC_WD-1:0]),

    //outputs
    .pipe_rxdatavalid          (adapted_pipe_phy_mac_rxdatavalid),
    .pipe_txdatavalid          (adapted_pipe_mac_phy_txdatavalid),
    .pipe_txdeemph             (adapted_pipe_mac_phy_txdeemph),
    .pipe_blockaligncontrol    (adapted_pipe_mac_phy_blockaligncontrol),
    .pipe_encodedecodebypass   (adapted_pipe_mac_phy_encodedecodebypass),
    .pipe_powerdown            (adapted_pipe_mac_phy_powerdown),
    .pipe_width                (adapted_pipe_mac_phy_width),
    .pipe_serdes_arch          (adapted_pipe_mac_phy_serdes_arch),
    .pipe_rxwidth              (adapted_pipe_mac_phy_rxwidth),
    .pipe_pclk_rate            (adapted_pipe_mac_phy_pclk_rate)
    ,
    .pipe_cclk_rate            (adapted_pipe_mac_phy_cclk_rate)
    ,
    .pipe_aux_sync_p1_ack      (pipe_aux_sync_p1_ack),
    .pipe_aux_sync_block       (pipe_aux_sync_block)
); //pipe_adapter

// drive core outputs using adapted signals
assign pre_mac_phy_txdatavalid = serdes_pipe_txdatavalid;
assign lpbk_rxdatavalid_i = adapted_pipe_phy_mac_rxdatavalid;

wire sris_mode_enabled;
assign sris_mode_enabled = app_sris_mode | xmlh_sris_mode_enabled;

assign        mac_phy_cfg_cxl_port_drift_buffer_enabled = ltssm_cxl_ll_mod[1];
assign        mac_phy_ltssm_link_synchdr_bypass_enabled = cxl_sh_bypass & ~(smlh_ltssm_state == S_LPBK_ENTRY | smlh_ltssm_state == S_LPBK_ACTIVE | smlh_ltssm_state == S_LPBK_EXIT | smlh_ltssm_state == S_LPBK_EXIT_TIMEOUT);

serdes_pipe
 #(
    .NL(`CX_NL),
    .INST(INST)
) u_serdes_pipe (
// ------------ inputs ----------------
    .clk(core_clk_ug),
    .rst_n(core_rst_n),
    .rx_clk(pipe_rx_clk),
    .rx_rst_n(pipe_rx_rst_n),
    .sync_hdr_bypass_en(mac_phy_ltssm_link_synchdr_bypass_enabled),
    .drift_buffer_en(mac_phy_cfg_cxl_port_drift_buffer_enabled),
    .lanes_active(laneflip_deskew_lanes_active),
    .drift_buffer_low_ptr_en(cfg_lane_skew[14]),
    .drift_buffer_deskew_enable(cfg_drift_buffer_deskew_enable),
    .ltssm_in_lpbk_wo_l0(ltssm_in_lpbk_wo_l0),
    .ltssm_lanes_active(ltssm_l0p_lanes_active),
    .ltssm_state(smlh_ltssm_state),
    .pipe_rate(mac_phy_rate),
    .pipe_width(mac_phy_width),
    .pipe_srisen(sris_mode_enabled),
    .flit_mode_enable(smlh_flit_mode_enable),
    .serdes_pipe_rxdata(phy_mac_rxdata),
    .serdes_pipe_rxvalid(phy_mac_rxvalid),
    .serdes_pipe_rxstatus(phy_mac_rxstatus_int),
    .orig_pipe_txdata(fstep_mac_phy_txdata),
    .orig_pipe_txdatak(pre_mac_phy_txdatak),
    .orig_pipe_txelecidle(fstep_mac_phy_txelecidle),
    .orig_pipe_txcompliance(glue_mac_phy_txcompliance),
    .orig_pipe_txdetectrx_loopback(fstep_mac_phy_txdetectrx_loopback),
    .orig_pipe_txdatavalid(adapted_pipe_mac_phy_txdatavalid),
    .orig_pipe_txstartblock(pre_mac_phy_txstartblock),
    .orig_pipe_txsyncheader(pre_mac_phy_txsyncheader),
    .orig_pipe_blockaligncontrol(pre_mac_phy_blockaligncontrol_o),
    .orig_pipe_rxpolarity(pre_mac_phy_rxpolarity),
    .orig_pipe_elasticbuffermode(cfg_elastic_buffer_mode),
// ------------ outputs ----------------
    .orig_pipe_rxdata(orig_pipe_rxdata),
    .orig_pipe_rxdatak(orig_pipe_rxdatak),
    .orig_pipe_rxvalid(orig_pipe_rxvalid),
    .orig_pipe_rxdatavalid(orig_pipe_rxdatavalid),
    .orig_pipe_rxstatus(orig_pipe_rxstatus),
    .serdes_pipe_txdatavalid(serdes_pipe_txdatavalid),
    .orig_pipe_rxstartblock(orig_pipe_rxstartblock),
    .orig_pipe_rxsyncheader(orig_pipe_rxsyncheader),
    .orig_pipe_os_found(orig_pipe_rxdata_osfound),
    .orig_pipe_os_corrected(orig_pipe_os_corrected),
    .drift_buffer_deskew_ptr(drift_buffer_deskew_ptr),
    .serdes_pipe_txdata(serdes_pipe_txdata),
    .serdes_pipe_txelecidle(serdes_pipe_txelecidle),
    .serdes_pipe_txdetectrx_loopback(serdes_pipe_txdetectrx_loopback),
    .serdes_pipe_rxready(pre_serdes_pipe_rxready)
); // u_serdes_pipe


assign pre_mac_phy_txdata = serdes_pipe_txdata;
assign int_mac_phy_txelecidle = serdes_pipe_txelecidle;
assign serdes_pipe_turnoff_lanes = fstep_mac_phy_txelecidle & glue_mac_phy_txcompliance;
assign pre_mac_phy_txdetectrx_loopback = serdes_pipe_txdetectrx_loopback;

// Assemble the PIPE control signals into a single bus to pass in/out of
// pipe_loopback module
struct packed {
  logic [`CX_NL-1:0]              elecidle;
  logic [`CX_NL-1:0]              datavalid;
  logic [`CX_NL*`CX_PHY_RXSB_WD-1:0]  startblock;
  logic [`CX_NL*`CX_PHY_RXSH_WD-1:0]  syncheader;
}  rxctrl, txctrl, lpbk_ctrl;

localparam int  CTRL_WIDTH = $bits(rxctrl);
// 1: rxelecidle
// 4: startblock, datavalid, syncheader(2 bits)


// Pack Normal mode receive control signals
always_comb begin: rxctrl_PROC
  rxctrl.elecidle = sqlchd_rxelecidle;
  rxctrl.datavalid = orig_pipe_rxdatavalid;
  rxctrl.startblock = orig_pipe_rxstartblock;
  rxctrl.syncheader = orig_pipe_rxsyncheader;
end: rxctrl_PROC

// Pack loopback mode transmit control signals
always_comb begin: txctrl_PROC
  txctrl.elecidle = fstep_mac_phy_txelecidle;

  txctrl.datavalid = adapted_pipe_mac_phy_txdatavalid;

  txctrl.startblock = pre_mac_phy_txstartblock;
  txctrl.syncheader = pre_mac_phy_txsyncheader;
end: txctrl_PROC

// Unpack the loopback rx control signals
always_comb begin: lpbk_ctrl_PROC
  lpbk_rxelecidle = lpbk_ctrl.elecidle;
  lpbk_rxdatavalid = lpbk_ctrl.datavalid;
  lpbk_rxstartblock = lpbk_ctrl.startblock;
  lpbk_rxsyncheader = lpbk_ctrl.syncheader;
end: lpbk_ctrl_PROC

pipe_loopback

#(
    .INST (0), // uniquifying parameter for each port logic instance
    .NL (`CX_NL),
    .PHY_NB (`CX_PHY_NB),
    .CTRL_WIDTH (CTRL_WIDTH),// Control mux width varies with gen3 pipe i/f
    .PDWN_WIDTH (`CX_PHY_PDOWN_WD),// Width of powerdown input
    .RATE_WIDTH (`CX_PHY_RATE_WD) // Width of powerdown input
) u_pipe_loopback
(
    .clk                            (core_clk_ug),
    .rst_n                          (core_rst_n),

    // Control Inputs
    .cfg_pipe_loopback              (cfg_pipe_loopback),
    .cfg_rxstatus_lane              (cfg_rxstatus_lane),
    .cfg_rxstatus_value             (cfg_rxstatus_value),
    .cfg_lpbk_rxvalid               (cfg_lpbk_rxvalid),
    .ext_pipe_loopback              (1'b0),     // May be connected to test pin
    .mac_phy_rate                   (int_mac_phy_rate),

    // PIPE RX Inputs
    .rxdata                         (orig_pipe_rxdata),
    .rxdatak                        (orig_pipe_rxdatak),
    .rxvalid                        (orig_pipe_rxvalid),
    .rxctrl                         (rxctrl),
    .rxstatus                       (orig_pipe_rxstatus),
    .rxdata_osfound                 (orig_pipe_rxdata_osfound),
    .phystatus                      (phy_mac_phystatus_int),

    // PIPE TX Inputs
    .txdata                         (fstep_mac_phy_txdata),
    .txdatak                        (pre_mac_phy_txdatak),
    .txctrl                         (txctrl),
    .txdetectrx_loopback            (fstep_mac_phy_txdetectrx_loopback),
    .txdata_osfound                 (txdata_osfound),
    .powerdown                      (pm_int_phy_powerdown),
    .rate                           (pre_mac_phy_rate),

    // PIPE Outputs
    .lpbk_rxdata                    (lpbk_rxdata),
    .lpbk_rxdatak                   (lpbk_rxdatak),
    .lpbk_rxvalid                   (lpbk_rxvalid),
    .lpbk_ctrl                      (lpbk_ctrl),
    .lpbk_rxstatus                  (lpbk_rxstatus),
    .lpbk_osfound                   (lpbk_osfound),
    .lpbk_phystatus                 (lpbk_phystatus)
); // u_pipe_loopback

//
// Note: Not all features applied to end-point application
//
 assign mac_phy_pipe_txdatavalid_i = int_mac_phy_txdatavalid;
 assign int_phy_mac_rxdata = {{((`CX_NL*`CX_NB*8)-(8*`CX_PHY_NB*`CX_NL)){1'b0}},lpbk_rxdata};
 assign int_phy_mac_rxdatak = {{((`CX_NL*`CX_NB)-(`CX_PHY_NB*`CX_NL)){1'b0}},lpbk_rxdatak};
 assign int_phy_mac_rxvalid = lpbk_rxvalid;
 assign int_phy_mac_rxstatus = lpbk_rxstatus;
 assign int_phy_mac_rxelecidle = lpbk_rxelecidle;
 assign int_phy_mac_phystatus = regif_phystatus;
 assign int_phy_mac_rxstandbystatus = phy_mac_rxstandbystatus;
 assign int_phy_mac_rxdatavalid = lpbk_rxdatavalid_i;
 assign int_phy_mac_rxstartblock = lpbk_rxstartblock;
 assign int_phy_mac_rxsyncheader = lpbk_rxsyncheader;
 assign int_phy_mac_fs = phy_mac_localfs;
 assign int_phy_mac_lf = phy_mac_locallf;
 assign int_phy_mac_dirfeedback = phy_mac_dirfeedback;
 assign int_phy_mac_fomfeedback = phy_mac_fomfeedback;
 assign int_phy_mac_local_tx_pset_coef = phy_mac_local_tx_pset_coef;
 assign int_phy_mac_local_tx_coef_valid = phy_mac_local_tx_coef_valid;
assign int_phy_mac_margin_status    = phy_mac_margin_status   ;
assign int_phy_mac_margin_nak       = phy_mac_margin_nak;
assign int_phy_mac_margin_error_cnt = phy_mac_margin_error_cnt;
assign int_phy_mac_margin_sampl_cnt = phy_mac_margin_sampl_cnt;
assign int_rxdata_osfound          = lpbk_osfound;
assign int_os_corrected            = orig_pipe_os_corrected;
assign int_pam4_restricted_levels_wr_ack_pending = pam4_restricted_levels_wr_ack_pending;
 assign fstep_mac_phy_txdetectrx_loopback = int_mac_phy_txdetectrx_loopback;

 assign fstep_mac_phy_txdata = int_mac_phy_txdata;
 assign pre_mac_phy_txdatak = int_mac_phy_txdatak;
 assign mac_phy_txdatavalid_i = int_mac_phy_txdatavalid;
 assign pre_mac_phy_txstartblock = int_mac_phy_txstartblock;
 assign pre_mac_phy_txsyncheader = int_mac_phy_txsyncheader;
 assign txdata_osfound           = int_txdata_osfound;
 assign pre_mac_phy_rxpresethint = int_mac_phy_rxpresethint;
 assign pre_mac_phy_fs = int_mac_phy_fs;
 assign pre_mac_phy_lf = int_mac_phy_lf;
 assign smlh_eqpa_txdeemph = int_smlh_eqpa_txdeemph;
 assign pre_mac_phy_rxeqinprogress = int_mac_phy_rxeqinprogress;
 assign pre_mac_phy_invalid_req = int_mac_phy_invalid_req;
 assign pre_mac_phy_rxeqeval = int_mac_phy_rxeqeval;
 assign pre_mac_phy_dirchange = int_mac_phy_dirchange;
 assign pre_mac_phy_local_pset_index = int_mac_phy_local_pset_index;
 assign pre_mac_phy_smlh_coef_rtx = int_mac_phy_smlh_coef_rtx;
 assign pre_mac_phy_getlocal_pset_coef = int_mac_phy_getlocal_pset_coef;
 assign smlh_blockaligncontrol_bus = int_smlh_blockaligncontrol;
 assign pre_mac_phy_margin_cmd    = int_mac_phy_margin_cmd;
 assign pre_mac_phy_margin_offset = int_mac_phy_margin_offset;
 assign pre_mac_phy_margin_clr_error_log = int_mac_phy_margin_clr_error_log;
 assign pre_mac_phy_txcompliance = int_mac_phy_txcompliance;
 assign pre_mac_phy_rxpolarity = int_mac_phy_rxpolarity;
 assign pre_mac_phy_rxstandby = int_mac_phy_rxstandby;
 assign fstep_mac_phy_txelecidle = int_ltssm_txelecidle;
 assign tmp_mac_phy_rate_bus = {`CX_NL{int_mac_phy_rate}};
 assign mac_phy_txdeemph_bus = {`CX_NL{int_mac_phy_txdeemph}};
 assign mac_phy_txmargin_bus = {`CX_NL{int_mac_phy_txmargin}};
 assign mac_phy_txswing_bus  = {`CX_NL{int_mac_phy_txswing}};
 assign mac_phy_pam4_restricted_levels_bus = {`CX_NL{int_mac_phy_pam4_restricted_levels}};

 assign tmp_mac_phy_rate = tmp_mac_phy_rate_bus[2:0];
 assign pre_mac_phy_width = adapted_pipe_mac_phy_width;
 assign pre_mac_phy_serdes_arch = adapted_pipe_mac_phy_serdes_arch;
 assign pre_mac_phy_rxwidth = adapted_pipe_mac_phy_rxwidth;
 assign pre_mac_phy_pclk_rate = adapted_pipe_mac_phy_pclk_rate;
 assign pre_mac_phy_powerdown = adapted_pipe_mac_phy_powerdown;
 assign core_int_mac_phy_txdeemph = mac_phy_txdeemph_bus[1:0];

 assign pre_mac_phy_txdeemph = adapted_pipe_mac_phy_txdeemph;
 assign pre_mac_phy_encodedecodebypass = adapted_pipe_mac_phy_encodedecodebypass;

 assign core_int_pipe_smlh_blockaligncontrol = smlh_blockaligncontrol_bus;
 assign pre_mac_phy_blockaligncontrol_o = adapted_pipe_mac_phy_blockaligncontrol;
 assign pre_mac_phy_blockaligncontrol = pre_mac_phy_blockaligncontrol_o[0];

 assign pre_mac_phy_txmargin = mac_phy_txmargin_bus[2:0];
 assign pre_mac_phy_txswing  = mac_phy_txswing_bus[0];

 assign pre_mac_phy_pam4_restricted_levels = mac_phy_pam4_restricted_levels_bus[0];

 assign pre_mac_phy_rate = tmp_mac_phy_rate[2:0];

logic                pipe_regif_clk_en;
logic [2:0]          pipe_regif_pipe_rate;
logic [`CX_NL-1:0]       pipe_regif_busy;
logic [`CX_NL-1:0]       pipe_regif_lpif_mst_dvalid;
logic [3:0]          pipe_regif_rx_message_bus_write_buffer_depth;
logic                pipe_regif_pam4_restricted_levels_requirement;
logic [(18*`CX_NL)-1:0]  pipe_regif_lpif_txdeemph;
logic [`CX_NL-1:0]       pipe_regif_lpif_txdeemph_dvalid;

  pipe_regif_sync
   #(
    .NL(`CX_NL),
    .RATE_WIDTH(`CX_PHY_RATE_WD),
    .TX_DEEMPH_WD(`CX_PHY_TXDEEMPH_WD),
    .INST(INST)
  ) u_pipe_regif_sync (
  // ------------ inputs ----------------
    .clk(core_clk_ug),
    .rst_n(core_rst_n),
    .core_clk(core_clk),
    .core_rst_n(core_rst_n),
    .sticky_rst_n(sticky_rst_n),
    .pipe_regif_busy(pipe_regif_busy),
    .smlh_ltssm_state(smlh_ltssm_state),
    .current_data_rate(current_data_rate),
    .laneflip_no_turnoff_lanes(laneflip_no_turnoff_lanes),
    .pipe_txcompliance(glue_mac_phy_txcompliance),
    .pipe_txelecidle(fstep_mac_phy_txelecidle),
    .pre_pipe_rate(mac_phy_rate),
    .cfg_rx_msgbus_write_buffer_depth(cfg_rx_message_bus_write_buffer_depth),
    .cfg_pam4_restricted_levels_requirement(cfg_pam4_restricted_levels_requirement),
    .pre_lpif_txdeemph(pre_mac_phy_txdeemph),
  // ------------ outputs ----------------
    .pipe_rate(pipe_regif_pipe_rate),
    .rx_msgbus_write_buffer_depth(pipe_regif_rx_message_bus_write_buffer_depth),
    .pam4_restricted_levels_requirement(pipe_regif_pam4_restricted_levels_requirement),
    .lpif_txdeemph(pipe_regif_lpif_txdeemph),
    .lpif_txdeemph_dvalid(pipe_regif_lpif_txdeemph_dvalid),
    .clk_en(pipe_regif_clk_en),
    .pipe_regif_all_idle(pipe_regif_all_idle),
    .lpif_mst_dvalid(pipe_regif_lpif_mst_dvalid)
  ); // u_pipe_regif_sync

// PIPE register interface controller
generate
  for(genvar i = 0; i < `CX_NL; i++) begin: gen_pipe_regif
    pipe_regif
     #(
      .TX_COEF_WD(`CX_TX_COEF_WD),
      .TX_FS_WD(`CX_TX_FS_WD),
      .PSET_ID_WD(`PSET_ID_WD),
      .FOMFEEDBACK_WD(`CX_FOMFEEDBACK_WD),
      .DIRFEEDBACK_WD(`DIRFEEDBACK_WD),
      .INST(INST)
    ) u_pipe_regif (
    // ------------ inputs ----------------
      .clk(core_clk_ug),
      .rst_n(pipe_msgbus_rst_n),
      .clk_en(pipe_regif_clk_en),
      .lpif_mst_dvalid(pipe_regif_lpif_mst_dvalid[i]),
      .rx_msgbus_write_buffer_depth(pipe_regif_rx_message_bus_write_buffer_depth),
      .pam4_restricted_levels_requirement(pipe_regif_pam4_restricted_levels_requirement),
      .lpif_txdeemph(pipe_regif_lpif_txdeemph[(18*i)+:18]),
      .lpif_txdeemph_dvalid(pipe_regif_lpif_txdeemph_dvalid[i]),
      .lpif_txmargin(pre_mac_phy_txmargin),
      .lpif_txswing(pre_mac_phy_txswing),
      .pipe_phystatus(lpbk_phystatus[i]),
      .pipe_rate(pipe_regif_pipe_rate),
      .lpif_fs(pre_mac_phy_fs[(`CX_TX_FS_WD*i)+:`CX_TX_FS_WD]),
      .lpif_lf(pre_mac_phy_lf[(`CX_TX_FS_WD*i)+:`CX_TX_FS_WD]),
      .lpif_local_pset_index(pre_mac_phy_local_pset_index[(`PSET_ID_WD*i)+:`PSET_ID_WD]),
      .lpif_getlocal_pset_coef(pre_mac_phy_getlocal_pset_coef[i]),
      .lpif_rxeqinprogress(pre_mac_phy_rxeqinprogress[i]),
      .lpif_invalid_req(pre_mac_phy_invalid_req[i]),
      .lpif_rxeqeval(pre_mac_phy_rxeqeval[i]),
      .lpif_margin_cmd(pre_mac_phy_margin_cmd[(3*i)+:3]),
      .lpif_margin_offset(pre_mac_phy_margin_offset[(7*i)+:7]),
      .lpif_margin_cnt_rst(pre_mac_phy_margin_clr_error_log[(2*i)+:2]),
      .pam4_restricted_levels(pre_mac_phy_pam4_restricted_levels),
  `ifndef SYNTHESIS
      .rate_chg(pipe_regif_pipe_rate != current_data_rate),
  `endif // SYNTHESIS
      .pipe_p2m_msgbus(phy_mac_messagebus[(8*i)+:8]),
  // ------------ outputs ---------------
      .lpif_phystatus(tmp_regif_phystatus[i]),
      .lpif_localfs(phy_mac_localfs[(`CX_TX_FS_WD*i)+:`CX_TX_FS_WD]),
      .lpif_locallf(phy_mac_locallf[(`CX_TX_FS_WD*i)+:`CX_TX_FS_WD]),
      .lpif_local_tx_coef_valid(phy_mac_local_tx_coef_valid[i]),
      .lpif_local_tx_pset_coef(phy_mac_local_tx_pset_coef[(`CX_TX_COEF_WD*i)+:`CX_TX_COEF_WD]),
      .lpif_fomfeedback(phy_mac_fomfeedback[(`CX_FOMFEEDBACK_WD*i)+:`CX_FOMFEEDBACK_WD]),
      .lpif_dirfeedback(phy_mac_dirfeedback[(`DIRFEEDBACK_WD*i)+:`DIRFEEDBACK_WD]),
      .lpif_margin_status(phy_mac_margin_status[i]),
      .lpif_margin_nak(phy_mac_margin_nak[i]),
      .lpif_margin_sample_cnt(phy_mac_margin_sampl_cnt[(7*i)+:7]),
      .lpif_margin_error_cnt(phy_mac_margin_error_cnt[(6*i)+:6]),
      .pam4_restricted_levels_wr_ack_pending(pam4_restricted_levels_wr_ack_pending[i]),
      .pipe_regif_busy(pipe_regif_busy[i]),
      .pipe_m2p_msgbus(pre_mac_phy_mbus[(8*i)+:8])
    ); // u_pipe_regif
  end
endgenerate



reg     [`CX_NL-1:0]                latched_mac_phy_txcompliance;
always @( posedge core_clk or negedge core_rst_n ) begin : latched_mac_phy_txcompliance2_PROC
    if ( ~core_rst_n )
        latched_mac_phy_txcompliance <= #`TP 0;
    else if ( ~ltssm_all_detect_quiet )
        latched_mac_phy_txcompliance <= #`TP pre_mac_phy_txcompliance & fstep_mac_phy_txelecidle; //latch/keep pre_mac_phy_txcompliance when entry to S_DETECT_QUIET or S_PRE_DETECT_QUIET
end // latched_mac_phy_txcompliance2_PROC

ltssm_state_e        ltssm_d;
always @( posedge core_clk or negedge core_rst_n ) begin : ltssm_d_PROC
    if ( ~core_rst_n )
        ltssm_d <= #`TP S_DETECT_QUIET;
    else
        ltssm_d <= #`TP smlh_ltssm_state;
end // ltssm_d_PROC

wire dis_to_pre_detect_pulse;
assign dis_to_pre_detect_pulse = (smlh_ltssm_state == S_PRE_DETECT_QUIET && ltssm_d == S_DISABLED);

reg latched_dis_to_pre_detect;
always @( posedge core_clk or negedge core_rst_n ) begin : latched_dis_to_pre_detect_PROC
    if ( ~core_rst_n )
        latched_dis_to_pre_detect <= #`TP 0;
    else if ( smlh_ltssm_state == S_DETECT_QUIET )
        latched_dis_to_pre_detect <= #`TP 0;
    else if ( dis_to_pre_detect_pulse )
        latched_dis_to_pre_detect <= #`TP 1;
end // latched_dis_to_pre_detect_PROC

wire pre_detect_from_disabled;
assign pre_detect_from_disabled = (smlh_ltssm_state == S_PRE_DETECT_QUIET && (latched_dis_to_pre_detect | dis_to_pre_detect_pulse));

assign ltssm_all_detect_quiet = (smlh_ltssm_state == S_DETECT_QUIET || smlh_ltssm_state == S_PRE_DETECT_QUIET) && ~pre_detect_from_disabled;
wire   ltssm_in_L2            = (smlh_ltssm_state == S_L2_IDLE || smlh_ltssm_state == S_L2_WAKE);

// from a glue logic based on pre_mac_phy_txcompliance to avoid pipe spec violation
always @( * ) begin : glue_mac_phy_txcompliance_PROC
    glue_mac_phy_txcompliance = 0;

    if ( (ltssm_all_detect_quiet || ltssm_in_L2) && mac_phy_powerdown == 4'b0010 ) // powerdown = P1 & in Detect.Quiet state or S_PRE_DETECT_QUIET or L2
        glue_mac_phy_txcompliance = 0;
    else if ( ltssm_all_detect_quiet )
        glue_mac_phy_txcompliance = latched_mac_phy_txcompliance; // else, keep unchanged on entry to S_DETECT_QUIET during S_DETECT_QUIET or S_PRE_DETECT_QUIET
    else
        glue_mac_phy_txcompliance = pre_mac_phy_txcompliance; // else, keep pre_mac_phy_txcompliance
end // glue_mac_phy_txcompliance_PROC



`ifndef SYNTHESIS
`endif // SYNTHESIS
endmodule
