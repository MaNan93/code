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
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/products/cx_top.sv#8 $
// -------------------------------------------------------------------------
// --- Module Description: PCI-Express Core (Layers 1,2, and 3)
// -----------------------------------------------------------------------------
// --- This module contains the complete CX-TOP Port logic. Including Mac portion
// --- of the physical layer, the DataLink layer, and Transation layer.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer2/svif/tx_lp_if.svh"
`include "Spif/pkg/spif_pkg.svh"
`include "Spif/svif/spif_if.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
`include "products/cx_pl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "power_management/DWC_pcie_pm_pkg.svh"

module cx_top
import DWC_pcie_core_pkg::ltssm_state_e;
import DWC_pcie_core_pkg::S_DETECT_QUIET;
import DWC_pcie_core_pkg::S_RCVRY_IDLE;
import DWC_pcie_core_pkg::S_L0;
import DWC_pcie_core_pkg::S_L0S;
import DWC_pcie_core_pkg::rtlh_radm_datapath_t;
import DWC_pcie_pm_pkg::USP_LINK_RST;
import DWC_pcie_pm_pkg::DSP_LINK_RST;
import cx_pl_pkg::rbuf_struct;
import cx_pl_pkg::dllp_struct;
import cx_pl_pkg::tx_cmd_struct;
import cx_pl_pkg::NFM_DW_W_PAR;
import cx_pl_pkg::P_NFM_RBUF_WD;
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
import DWC_pcie_core_pkg::rtlh_rfc_t;
import DWC_pcie_core_pkg::xtlh_pkt_t;
import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
import spif_pkg::link_adm_if_t;
import spif_pkg::state_enc_e;
import spif_pkg::protocol_cfg_t;
import spif_pkg::RESET;
import spif_pkg::IDLE_L1_1;
import spif_pkg::L2;
import spif_pkg::ACTIVE;
import spif_pkg::ACTIVE_L0S_PMNAK;
import DWC_pcie_ctl_pkg::PIPE_DATA_WD;
import DWC_pcie_ctl_pkg::ORIG_DATA_WD;
import DWC_cxl_pkg::vlsm_debug_t;
import DWC_pcie_ctl_pkg::ltssm_cxl_enable_t;
import DWC_pcie_core_pkg::CFG_CXL_PORT_ENABLE_WD;
import DWC_pcie_pm_pkg::usp_link_fsm_state_e;
import DWC_pcie_pm_pkg::dsp_link_fsm_state_e;
import DWC_pcie_pm_pkg::usp_prot_fsm_state_e;
import DWC_pcie_pm_pkg::dsp_prot_fsm_state_e;
import DWC_pcie_pm_pkg::pm_active_l0s_fsm_e;
import DWC_pcie_pm_pkg::pm_protocol_to_link_struct;
import DWC_pcie_pm_pkg::pm_link_to_protocol_struct;
#(
parameter INST         = 0,                                       // The uniquifying parameter for each port logic instance.
parameter DCAW         = `CX_LOGBASE2(`CX_NW/4+1),           // Number of bits needed to represent the maximum number                                                            // of Data CA returned from the radm (512:3, 256:2, 128 or below:1)
parameter TX_HW_W_PAR  = 128 + `CX_RAS_PCIE_HDR_PROT_WD
)

             (
input                       cfg_p2p_track_cpl_to,
input  [6:0]                cfg_tx_arb_control,
input                       cfg_flit_mode_enable,
input                       cfg_pcie_cap_flit_mode_sup,
input                       cfg_flit_mode_dis,
input                       cfg_flit_sris_clocking,
input  [2:0]                cfg_local_l0p_exit_latency, // unused
input                       cfg_reciver_l0p_supported,
input                       cfg_comm_clk_config,
input                       cfg_l0p_enable,                  // L0p Enable
input                       cfg_l0p_autowidth_dis,           // Hardware Autonomous Width Disable bit in the Link Control register (bit[9])
input                       cfg_l0p_priority,                // Port Logic register bit to set L0p.Priority bit in DLLP
input  [2:0]                cfg_l0p_linkmode,                // Target Link Width in Device Control 3 Register (bit[6:4])
input                       cfg_l0p_linkmode_req,            // Link Width change request asserted on the write access to Device Control 3 Register
input  [5:0]                cfg_l0p_max_link_width,          // TOVEREMOVED: Maximum supported Link Width
input  [5:0]                cfg_l0p_neg_link_width,          // TOVEREMOVED: Negotiated Link Width
input                       cfg_pcie_l0p_disable,            // PCIe/CXL.io: Disable dynamic L0p
input                       cfg_pcie_l0p_request,            // PCIe/CXL.io: L0p Request bit
input                       cfg_pcie_l0p_priority,           // PCIe/CXL.io: L0p Priority bit
input  [2:0]                cfg_pcie_l0p_linkmode,           // PCIe/CXL.io: L0p Target Link Width
output logic                app_dynamic_l0p_enable,          // Application Interface signal indicates that Dynamic L0p is enabled
output logic                app_dynamic_l0p_rejected,        // Application Interface signal indicates that L0p request is NAK-ed
input                       pm_block_phystatus,             // block phystatus detection in rmlh_pipe while pipe 4.3 gasket drives powerdown
output                      pm_prot_req_l2,     // PM Protocol FSM requests Link Layer to enter L2
output  logic [3:0]         vlsm_mc_state,                   // vLSM.cachemem Link State
output  logic [3:0]         vlsm_io_state,                   // vLSM.io Link State
// CXL SPIF Interfaces
spif_if.master_mp           b_cxl_vlsm_spif,                 // CXL.cachemem to vLSM SPIF Interface
// CXL Configuration Interface
input  [CFG_CXL_PORT_ENABLE_WD-1:0] cfg_cxl_port_enable,     // CXL port enables
input   [15:0]              cfg_cxl_port_vid,                // cxl dvsec vendor id
input                       cfg_cxl_retimers_pre_mismatched, // cxl retimers present mismatched
input   [1:0]               cfg_retimers_pre_detected,       // cxl retimers present detected {retimer2,retimer1}
input                       cfg_pcie_slot_clk_config,        // connect to the same ref clock
input                       cfg_vlsm_force_active,           // Force VLSM State to ACTIVE
input                       cfg_vlsm_pm_enable,              // Enable Low Power mode Entry handshake
input  [3:0]                cfg_cxl_io_arb_weight,           // CXL.io Weighted Round Robin Arbitration Weight
input  [3:0]                cfg_cxl_mc_arb_weight,           // CXL.cache and CXL.mem Weighted Round Robin Arbitration Weight
input                       cfg_pm_timeout_enable,           // ARB/MUX PM Timeout Control Register - PM Timeout Enable
input  [1:0]                cfg_pm_timeout_value,            // ARB/MUX PM Timeout Control Register - PM Timeout Value
output logic                cfg_pm_timeout_error,            // ARB/MUX Uncorrectable Error Status Register - PM Timeout Error
input                       vlsm_io_tx_pm_nak,               // vLSM.io transmit Status(Active.PMNAK) ALMP
input                       vlsm_mc_tx_pm_nak,               // vLSM.mc transmit Status(Active.PMNAK) ALMP
output                      vlsm_io_rx_pm_nak,               // vLSM.io received Status(Active.PMNAK) ALMP
output                      vlsm_mc_rx_pm_nak,               // vLSM.mc received Status(Active.PMNAK) ALMP
output                      vlsm_io_rx_pm_req,               // vLSM.io PM Request ALMP received
output                      vlsm_mc_rx_pm_req,               // vLSM.mc PM Request ALMP received
output                      vlsm_io_pm_timeout,              // vLSM.io PM Request ALMP timeout
output                      vlsm_mc_pm_timeout,              // vLSM.mc PM Request ALMP timeout
output                     vlsm_ltssm_enable,                // Enable core_rst_n assertion
output vlsm_debug_t        vlsm_debug_info,                  // VLSM Debug Information

input   [2:0]               pm_current_data_rate,           // current_data_rate shadowed in pm_ctrl
input                       core_clk,                       // Core clock
input                       core_rst_n,                     // When asserted, reset the core except for the PMC domain.
input                       app_init_rst,                   // N/A for end-point, used by downstream port of switch,
input                       core_clk_ug,                    // An ungated version of core_clk used to track phystatus during powerdown states
input                       pipe_msgbus_rst_n,
input                       pm_rstctl_core_flush_req,
input                       rstctl_core_flush_req,
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
input                       cfg_rasdp_linkdown_en,          // Enable Link Down on RASDP uncorrectable error
input                       cfg_rasdp_error_mode_en,
input                       rasdp_linkdown,
input                       cfg_rasdp_error_mode,
input [6:0]                 ras_prot_t_disable,
input [6:0]                 ras_prot_r_disable,
output rtlh_rfc_t           rtlh_rfc,                       // Received FC update: Update Transmit credit information

    // RTLI Interface
input   [DCAW*`CX_NVC-1:0]      radm_rtlh_ph_ca,                // Credit allocated (posted header)
input   [DCAW*`CX_NVC-1:0]      radm_rtlh_pd_ca,                // Credit allocated (posted data)
input   [DCAW*`CX_NVC-1:0]      radm_rtlh_nph_ca,               // Credit allocated (non-posted header)
input   [DCAW*`CX_NVC-1:0]      radm_rtlh_npd_ca,               // Credit allocated (non-posted data)
input   [DCAW*`CX_NVC-1:0]      radm_rtlh_cplh_ca,              // Credit allocated (completion header)
input   [DCAW*`CX_NVC-1:0]      radm_rtlh_cpld_ca,              // Credit allocated (completion data)

output  rtlh_radm_datapath_t    rtlh_radm,

    // CDM and CXPL Interface (CCI)
output logic                    rmlh_rcvd_err,                  // PHY receiving error reported from pipe interface
input                           dl_feature_en,                  // Indicates Data Link Features supported
input                           cfg_remote_feature_ack,         // Indicates remote Data Link Features handshake completed
input  [22:0]                   cfg_local_feature_support,      // Local Feature (Including local scaled flow control) Support
input                           cfg_dlink_feature_valid,        // Has received a Data Link Feature DLLP after the Link entered L0
input                           fc_scaled_en,
input  [(`CX_NVC*2)-1:0]        hdr_scale_p,                    // The HdrScale field contains the scaling factor for headers of the indicated type
input  [(`CX_NVC*2)-1:0]        hdr_scale_np,                   // The HdrScale field contains the scaling factor for headers of the indicated type
input  [(`CX_NVC*2)-1:0]        hdr_scale_cpl,                  // The HdrScale field contains the scaling factor for headers of the indicated type
input  [(`CX_NVC*2)-1:0]        data_scale_p,                   // The DataScale field contains the scaling factor for payload data of the indicated type
input  [(`CX_NVC*2)-1:0]        data_scale_np,                  // The DataScale field contains the scaling factor for payload data of the indicated type
input  [(`CX_NVC*2)-1:0]        data_scale_cpl,                 // The DataScale field contains the scaling factor for payload data of the indicated type
output logic [5:0]              smlh_autoneg_link_width,        // negotiated link width
output logic [5:0]              rplh_link_rxmode,               // 6 bit link width, 10000 = x16, 1000 = x8, 100 = x4, 10 = x2, 1 = x1
output logic [3:0]              smlh_autoneg_link_sp,           // negotiated link speed
output logic                    smlh_link_training_in_prog,     // link training in progress
output logic                    smlh_link_up,                   // LTSSM link up
output                          latched_flit_mode_enable,
output logic                    smlh_flit_mode_enable,
output logic                    smlh_l0p_capable,               // l0p capable
output logic                    xmlh_sris_enable,               // PIPE Interface SRISEnable
output logic                    smlh_req_rst_not,               // when asserted, LTSSM is in link down other than DISABLE,HOTRESET and LPBK state where a reset is required  
output logic                    rdlh_bad_tlp_err,               // Data link layer receive bad TLP error                                                                       
output logic                    rdlh_bad_dllp_err,              // Data link layer receive bad DLLP error                                                                      
output logic [1:0]              rdlh_rtlh_link_state,           // Data link layer state machine output                                                                        
output logic                    dl_prot_err,                    // Data link layer protocol error                                                                              
output logic                    xdlh_xplh_replay_timeout,       // Transmit replay timeout from XDLH or XPLH                                                                   
output logic                    xdlh_xplh_replay_num_rlover_err,// Transmit replay number rollover from XDLH or XPLH                                                           
output logic                    xdlh_retrybuf_not_empty,        // Data link layer retry buffer not empty                                                                      
output logic [`CX_NVC-1:0]      rtlh_fc_init_status,            // FC init status. This signal indicates that FC control state machine
                                                                // is in FC init.
output logic [`CX_NVC-1:0]           rtlh_crd_not_rtn,               // Flow Control credit not returned
input   xtlh_pkt_t  [`N_XADM_IF-1:0]   xadm_xtlh_pkt,          // XADM Packet Interfaces
output logic        [`N_XADM_IF-1:0]   xtlh_xadm_pkt_halt,     // XTLH XADM Packet Halts
output logic        [`N_XADM_P_IF-1:0] xtlh_xadm_posted_tlp_sent,
input                       cfg_endpoint,                   // Endpoint device when it is high
input                       cfg_upstream_port,              // Upstream port when it is high
input                       cfg_root_compx,                 // Root complex port
input                       cfg_dll_lnk_en,                 // Data link layer link enabled when it is asserted. This is a debug
                                                            // feature. Default is 1. It enables data link control and management
                                                            // state machine.
input   [7:0]               cfg_ack_freq,                   // ACK frequency. It is the number of ACK that is allowed to coalesce when
                                                            // timer is not expired. Default is 1 which will enable ACK on every TLP received.
input   [15:0]              cfg_ack_latency_timer,          // ACK latency timer. Default value is expected to be chosen from table 3-5
                                                            // of Specification1.0a based on different application.
input   [16:0]              cfg_replay_timer_value,         // Replay Timer value.  Default value is expected to be chosen from table 3-4
                                                            // of Specification1.0a based on different application.
input   [12:0]              cfg_fc_latency_value,           // FC update latency timer value
input   [31:0]              cfg_other_msg_payload,          // Other MSG payload, for test equipment purpose. It is a way to allow a DLLP
                                                            // message being sent by CORE.
input                       cfg_other_msg_request,          // Other MSG request, for test equipment purpose. Control signal for the request.
input   [31:0]              cfg_corrupt_crc_pattern,        // Corrupted CRC pattern, for test equipment purpose. It carries corruption pattern.
input                       cfg_flow_control_disable,       // Disable flow control. This disables the flow control DLLP generation. It is
                                                            // for test/debug purpose. Default should be 0.
input                       cfg_acknack_disable,            // ACK/NACK disable. For test/debug purpose. Default is 0.
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
input   [2:0]               cfg_max_payload,                // MTU size. It is chosen by application. Default is 001 for 256Bytes.
input   [2:0]               cfg_max_payload_rx,             // In flit mode, The max payload -also known as "RX_MPS_limit"- has the value from the 'max_payload_size_supported' field.
input   [7:0]               cfg_tc_enable,                  // Supported highest TC. Report error if received tc number is higher than this.
                                                            // Default is at 7. All TC traffic is supported.
input   [`CX_NVC-1:0]       cfg_vc_enable,                  // Per VC enable
input   [3*`CX_NVC-1:0]     cfg_vc_struc_vc_id_map,         // Virtual channel structure to virtual channel ID map.
input   [23:0]              cfg_vc_id_vc_struc_map,         // vc id to structure id map
input   [23:0]              cfg_tc_struc_vc_map,            // Index by TC, returns VC
input                       cfg_reset_assert,               // Initiates a hot reset.
input                       cfg_link_retrain,               // Initiates link retraining.
input                       cfg_fc_wdog_disable,            // disable watch dog timer in FC for some debug purpose
input   [(`CX_NVC*8)-1:0]   cfg_fc_credit_ph,               // Posted header wire to control the FC initial value for FC credit advertisement
input   [(`CX_NVC*8)-1:0]   cfg_fc_credit_nph,              // Nonposted header wire to control the FC initial value for FC credit advertisement
input   [(`CX_NVC*8)-1:0]   cfg_fc_credit_cplh,             // Completion header Wire to control the FC initial value for FC credit advertisement
input   [(`CX_NVC*12)-1:0]  cfg_fc_credit_pd,               // Posted data wire to control the FC initial value for FC credit advertisement
input   [(`CX_NVC*12)-1:0]  cfg_fc_credit_npd,              // Nonposted data wire to control the FC initial value for FC credit advertisement
input   [(`CX_NVC*12)-1:0]  cfg_fc_credit_cpld,             // Completion data wire to control the FC initial value for FC credit advertisement
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
input [3:0]                            device_type,
input   [(2*`CX_NFUNC)-1:0]            cfg_max_end2end_tlp_prfxs,      // the maximum number of End-End TLP Prefixes supported, DBI writeable.
input                                  dpc_fatal_err_gate,             // DPC trigger gating for fatal error message
input                                  dpc_nonfatal_err_gate,          // DPC trigger gating for non-fatal error message
    // PMC and CXPL Interface (CPI)
output logic                xdlh_nodllp_pending,            // XDLH has no dllp pending. It is a signal for PMC (power management module).
output logic                xdlh_xmt_pme_ack,               // XDLH sends acknowledgement to the requester (PMC) block to indicate a completion

                                                            // of a PME DLLP sent.
output logic                xdlh_not_expecting_ack,         // Transmitter has received all its ACKs for all transmitted TLPs. It is a signal
                                                            // for PMC.
output logic                rdlh_link_up,                   // Data link layer is link up.
output logic                rdlh_link_down,                 // Data link layer is link down.
output logic                xtlh_tlp_pending,               // XTLH has TLP pending to be sent.
input                       xadm_all_type_infinite,         // XADM FC book keeping block indicates that remote link advertised all FC credits to infinite.
output logic                smlh_in_l0,                     // LTSSM in l0
output logic                smlh_in_l0s,                    // LTSSM Transmitter in l0s
output logic                smlh_in_rl0s,                   // LTSSM Receiver in rL0s
output logic                smlh_in_l1,                     // LTSSM  in L1
output logic                smlh_in_l23,                    // LTSSM in L23
output logic [`CX_NL-1:0]   rmlh_descrambled_even_parity,   // Current rx skip even data parity from RMLH
output logic [`CX_NL-1:0]   xmlh_scramble_even_parity,      // Current tx skip even data parity from XMLH
output logic                pm_smlh_l1_exit,                // PMC directs LTSSM L1 EXIT
output logic                pm_smlh_l23_exit,               // PMC directs LTSSM L23 EXIT
input                       pm_xtlh_block_tlp,              // PMC directs XTLH to block TLP
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
input                                   cfg_g6_tx_precode_req,             // GEN6 Transmitted Precode Request
input   [`CX_GEN6_DIR_CHANGE_CONTROL_WD-1:0] cfg_gen6_fdbk_dirchange_control, //Port Logic Gen3 EQ Feedback Direction Change Control Register
input   [`CX_NL*`CX_RX_PSET_WD-1:0] cfg_lec_g6_pset_lrx,            // Upstream Component Receiver Preset Hint (Not applicable to EP/SW_UP)
input   [`CX_NL*`CX_RX_PSET_WD-1:0] cfg_lec_g6_pset_rrx,            // Downstream Component Receiver Preset Hint (Not applicable to EP/SW_UP)
input                                     cfg_alt_protocol_enable,        // enable alternate protocol
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
output logic [1:0]  cdm_ras_des_einj0_ack,
input   [1:0]       cdm_ras_des_einj0_req, // bit0 for inverting LSB of LCRC, bit 1 for inverting of LSB of ECRC
    // Retry Buffer Interface (RBI)
input                                 cfg_tx_throttling,          // Tx Throttling Control Bit
output logic [`RBUF_PW -1:0]     xdlh_retryram_raddr,             // Adrress to retry buffer RAM
output logic [`RBUF_PW -1:0]     xdlh_retryram_waddr,             // Adrress to retry buffer RAM
output logic [`RBUF_WIDTH -1:0]  xdlh_retryram_data,             // Write data to retry buffer RAM
output logic                     xdlh_retryram_we,               // Write enable to retry buffer RAM
output logic                     xdlh_retryram_en,               // Read enable to retry buffer RAM
output logic                     xdlh_retryram_par_chk_val,      // parity check is valid
input   [`RBUF_WIDTH -1:0]       retryram_xdlh_data,             // Data coming back from Retry buffer RAM
input   [`RBUF_PW -1:0]          retryram_xdlh_depth,            // How big is the external retry buffer
input                            retryram_xdlh_parerr,           // retry buffer ram parity error detected


// Performance changes - 2p RAM I/F
output logic [`SOTBUF_L2DEPTH -1:0] xdlh_retrysotram_waddr,          // Write Adrress to retry buffer RAM
output logic [`SOTBUF_L2DEPTH -1:0] xdlh_retrysotram_raddr,          // Read Adrress to retry buffer RAM
output logic [`SOTBUF_WIDTH -1:0]   xdlh_retrysotram_data,          // Write data to retry buffer RAM
output logic                        xdlh_retrysotram_we,            // Write enable to retry buffer RAM
output logic                        xdlh_retrysotram_en,            // Read enable to retry buffer RAM
output logic                        xdlh_retrysotram_par_chk_val,   // parity check is valid
input   [`SOTBUF_WIDTH -1:0]        retrysotram_xdlh_data,          // Data coming back from Retry buffer RAM
input   [`SOTBUF_L2DEPTH -1:0]      retrysotram_xdlh_depth,
input                               retrysotram_xdlh_parerr,
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
output         ltssm_cxl_enable_t    ltssm_cxl_enable,
input                                cfg_drift_buffer_deskew_enable,
output logic                         cxl_link_enable,             // Indicates that CXL link is enabled after reaching 8GT/s
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
output logic   [7:0]                      rtfcgen_ph_diff,
output logic [ `CX_RAS_RDLH_COUNTERS-1:0] ras_stat_rdlh_corr,
output logic [ `CX_RAS_RTLH_COUNTERS-1:0] ras_stat_rtlh_corr,
output logic [ `CX_RAS_RDLH_COUNTERS-1:0] ras_stat_rdlh_uncorr,
output logic [ `CX_RAS_RTLH_COUNTERS-1:0] ras_stat_rtlh_uncorr,
input  [`CX_RAS_ERROR_INJ_EN_WD  -1:0]    ras_err_inj_en_array,
input  [`CX_RAS_ERROR_INJ_MASK_WD-1:0]    ras_err_inj_mask,
output logic                              ras_err_inj_done,
output logic                         rtlh_overfl_err,                // Indicates receiver overflow (credit based)
output logic   [`CX_L2NL-1:0]        smlh_lane_flip_ctrl,
output logic                         retry_flit,                          // Puls : Retry Event
input                              pm_current_powerdown_p1,               // Indicate mac phy powerdown is in P1
input                              pm_current_powerdown_p0,               // Indicate mac phy powerdown is in P0
input [(`CX_PHY_PDOWN_WD - 1) : 0] pm_int_phy_powerdown,
input [`CX_L2NL - 1 : 0]           pm_rx_lane_flip_en,
input [`CX_L2NL - 1 : 0]           pm_tx_lane_flip_en,
input [`CX_L2NL - 1 : 0]           pm_rx_pol_lane_flip_ctrl,
input                              tx_lane_flip_en,
input                          cfg_pm_clk_pm_en,               // PM Link connections with PM CTRL
input                          software_entr_l1,               // PM Link connections with PM CTRL
input                          software_entr_l23,              // PM Link connections with PM CTRL
input                          pm_aspm_l0s_en,                 // PME Controller indicates to the PM Protocol FSM that L0s ASPM is enabled
input                          pm_aspm_l1_en,                  // PME Controller indicates to the PM Protocol FSM that L1 ASPM is enabled
input                          cfg_pl_l1_nowait_p1,            // PM Link connections with PM CTRL
output                         pm_linkst_in_l0s,               // PM Link connections with PM CTRL
input                          pm_hold_exit_l1,                // PM Link connections with PM CTRL
input                          pm_link_exit_l1,                // PM Link connections with PM CTRL
input                          pm_link_exit_l23,               // Signals PM Link FSM to exit from L23RDY state
input                          pm_pl_wake_ack,                 // PM Controller Wakeup Acknowledge
input                          pm_pl_clk_req,                  // PM Controller Clock Request
input                          pm_pl_phyinl1,                  // PM Controller PHY in L1
input                          pm_pl_phyinl2,                  // PM Controller PHY in L2
output  usp_link_fsm_state_e   pm_usp_link_state,              // PM Link connections with PM CTRL
output  dsp_link_fsm_state_e   pm_dsp_link_state,              // PM Link connections with PM CTRL
input                          lbc_active,                     // PM Link connections with LBC
input                          pm_wake_req_exit_l0s,           // PM Protocol connections
input                          xadm_tlp_pending,               // XADM has no TLP pending in its datapath 
input                          xaim_tlp_pending,               // XAIM has TLP Pending
input                          msg_gen_asnak_grt,              // PM Protocol connections
input                          pm_l2_entry_flag,               // PM Protocol connections
input  [2:0]                   l0s_entr_latency_timer,         // PM Protocol connections
input  [2:0]                   l1_entr_latency_timer,          // PM Protocol connections
input                          pm_l1_entr_wo_rl0s,             // PM Protocol connections
input                          pm_aspm_l1_timer_enable,        // PM Protocol connections
input  [`CX_NVC-1:0]           xtlh_had_enough_credit,         // PM Protocol connections
input  [`CX_NVC-1:0]           xadm_no_fc_credit,              // PM Protocol connections
input                          radm_pm_asnak,                  // PM Protocol connections
input                          app_req_entr_l1,                // PM Protocol connections
input                          radm_trgt0_pending,             // PM Protocol connections
input                          pm_wake_any_if_pending,         // PM Protocol connections
input                          app_xfer_pending,               // PM Protocol connections
input    [3:0]                 cfg_dsp_pcipm_l1_enter_delay,   // PM Protocol connections
output  link_adm_if_t          pcie_link_adm_if,               // SPIF: PCIe Link Layer to ADM Interface
input                          lp_pcie_l1_exit,                // SPIF: Request to PCIe/CXL.io Link Layer to change requested from IDLE_L1_1 to ACTIVE and initiate L1 exit
input                          lp_pcie_clk_ack,                // SPIF: PCIe/CXL.io Link Layer acknowledges LogPHY request to remove the clock gating
input                          lp_pcie_wake_req,               // SPIF: PCIe/CXL.io Link Layer requests LogPHY to remove the clock gating
output                         pl_pcie_wake_ack,               // SPIF: LogPHY acknowledges lp_wake_req to PCIe/CXL.io Link Layer
output                         pl_pcie_clk_req,                // SPIF: LogPHY requests PCIe/CXL.io Link Layer to remove the clock gating
output                         pl_pcie_phyinl1,                // SPIF: LogPHY indication on PCIe/CXL.io SPIF interface that PHY is in L1 state
output                         pl_pcie_phyinl2,                // SPIF: LogPHY indication on PCIe/CXL.io SPIF interface that PHY is in L2 state
output                         pl_pcie_state_l1,               // SPIF: pl_state_sts is in IDLE_L1_1 on PCIe/CXL.io SPIF interface
output                         pl_pcie_state_l2,               // SPIF: pl_state_sts is in L2 on PCIe/CXL.io SPIF interface
output                         pl_pcie_state_active,           // SPIF: pl_state_sts is in ACTIVE or ACTIVE_L0S_PMNAK on PCIe/CXL.io SPIF interface
output                         pl_pcie_link_up,                // SPIF: pl_link_up on PCIe/CXL.io SPIF interface
output                         pl_cxl_wake_ack,               // SPIF: LogPHY acknowledges lp_wake_req to CXL.cachemem Link Layer
output                         pl_cxl_clk_req,                // SPIF: LogPHY requests CXL.cachemem Link Layer to remove the clock gating
output                         pl_cxl_phyinl1,                // SPIF: LogPHY indication on CXL.cachemem SPIF interface that PHY is in L1 state
output                         pl_cxl_phyinl2,                // SPIF: LogPHY indication on CXL.cachemem SPIF interface that PHY is in L2 state
output                         pl_cxl_state_l1,               // SPIF: pl_state_sts is in IDLE_L1_1 on CXL.cachemem SPIF interface
output                         pl_cxl_state_l2,               // SPIF: pl_state_sts is in L2 on CXL.cachemem SPIF interface
output                         pl_cxl_mode_enable,            // SPIF: SPLH Configuration - CXL Mode Enable bit
output  logic                  pm_xmt_asnak,                   // PM Protocol connections
output  logic                  pm_block_all_tlp,               // PM Protocol connections
output  logic                  pm_l1_aspm_entr,                // PM Protocol connections
output  logic                  pm_xdlh_enter_l23,              // PM Protocol connections
output  logic                  pm_l1_entry_started,            // PM Protocol connections
output  logic                  pm_l1_in_progress,              // PM Protocol connections
output  logic                  pm_aspm_l1_enter_ready,         // PM Protocol connections
output  logic                  latch_as_entr_l1,               // PM Protocol connections
output  logic                  pm_prot_idle_flag,              // PM Protocol connections
output  logic                  lp_sdb_l1sub_aspm,              // PM Protocol connections
output  logic                  lp_sdb_l1sub_pcipm,             // PM Protocol connections
output  usp_prot_fsm_state_e   pm_usp_prot_state,              // PM Protocol connections with CDM
output  dsp_prot_fsm_state_e   pm_dsp_prot_state,              // PM Protocol connections with CDM
output  pm_active_l0s_fsm_e    pm_l0s_state,                   // PM Protocol connections with CDM
input   [1:0]           cdm_ras_des_pm_entry_interval,         // Low Power Entry Interval Time for Ras D.E.S Silicon Debug
input   [1:0]           cdm_ras_des_eidle_cnt_sel,             // Number of Transmit E-IDLE ordered set for Ras D.E.S Silicon Debug
input                   cdm_ras_des_ltssm_stop,                // Level : Low Power Entry Interval Time for Ras D.E.S Silicon Debug
input                   cdm_ras_des_recovery_req,              // Level : Number of Transmit E-IDLE ordered set for Ras D.E.S Silicon Debug
input                   cdm_ras_des_ferr_rec_dis,              // Disable Recovery state transition at Framing Error for Ras D.E.S Silicon Debug
input                   cdm_ras_des_direct_rcvry_idle_to_cfg,  // Direct LTSSM from Recovery.Idle to Configuration for Ras D.E.S Silicon Debug
input                   cdm_ras_des_direct_poll_cmp_to_det,    // Direct LTSSM from Polling.Compliance to Detect for Ras D.E.S Silicon Debug
input                   cdm_ras_des_direct_lpbk_slave_to_exit, // Direct LTSSM from Loopback(Slave) to Exit for Ras D.E.S Silicon Debug
input                   cdm_ras_des_force_rxdetected_en,       // Force Detect Lane Num enable for Ras D.E.S Silicon Debug
input                   cdm_ras_des_force_linkdown_noack,      // Level : Force Link down when MAC does not receive ACK DLLP for long time
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
input                   cdm_ras_des_einj1_enable ,             // Error injection 1 enable
input                   cdm_ras_des_einj1_seq_type ,           // Error injection 1 seq# type
input   [12:0]          cdm_ras_des_einj1_bad_seq ,            // Error injection 1 bad seq# value
input   [7:0]           cdm_ras_des_einj1_count ,              // Error injection 1 count
input                   cdm_ras_des_einj2_enable,              // Error injection 2 enable
input   [1:0]           cdm_ras_des_einj2_dllp_type,           // Error injection 2 DLLP type
input                   cdm_ras_des_einj3_enable,              // Error injection 3 8b/10b K-code mask enable
input   [7:0]           cdm_ras_des_einj3_count,               // Error injection 3 8b/10b K-code mask count
input   [2:0]           cdm_ras_des_einj3_smb_type,            // Error injection 3 8b/10b K-code mask type
input                   cdm_ras_des_einj4_enable,              // Error injection 4 enable
input   [2:0]           cdm_ras_des_einj4_updfc_type,          // Error injection 4 UpdateFC type
input   [2:0]           cdm_ras_des_einj4_vcnum,               // Error injection 4 VC number
input   [12:0]          cdm_ras_des_einj4_badfc_value,         // Error injection 4 bad FC value
input                   cdm_ras_des_einj5_enable ,             // Error injection 5 enable
input   [7:0]           cdm_ras_des_einj5_count ,              // Error injection 5 count
input                   cdm_ras_des_einj5_tlp_type ,           // Error injection 5 tlp type (dup/nul)
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
output logic [1:0]                   rl0s_state,                     // Level : RxL0s state
output logic [`CX_RX_TLP-1:0]        rdlh_bad_tlp_err_pertlp,        // Puls : Rx Bad TLP Event per TLP for Ras D.E.S event counter
output logic [`CX_RX_TLP-1:0]        rdlh_lcrc_tlp_err_pertlp,       // Puls : Rx LCRC Error TLP Event per TLP for Ras D.E.S event counter
output logic [`CX_RX_TLP-1:0]        rdlh_nulified_tlp_err_pertlp,   // Puls : Rx Nullified TLP Event per TLP for Ras D.E.S event counter
output logic [`CX_RX_TLP-1:0]        rdlh_duplicate_tlp_err_pertlp,  // Puls : Rx Duplicate TLP Event per TLP for Ras D.E.S event counter
output logic [`CX_RX_NDLLP-1:0]      rdlh_bad_dllp_err_perdllp,      // Puls : Rx Bad DLLP Event per DLLP for Ras D.E.S event counter
output logic [`CX_RX_NDLLP-1:0]      rdlh_rcvd_ack_perdllp,          // Puls : Rx Ack DLLP Event per DLLP for Ras D.E.S event counter
output logic [`CX_RX_NDLLP-1:0]      rcvd_nack_perdllp,              // Puls : Rx Nak DLLP Event per DLLP for Ras D.E.S event counter
output logic [`CX_TX_NDLLP-1:0]      xdlh_update_fc_sent,            // Puls : Tx Update-FC DLLP Event per TLP for Ras D.E.S event counter
output logic                         nak_sent,                       // Puls : Tx Nak DLLP Event per TLP for Ras D.E.S event counter
output logic                         ack_sent,                       // Puls : Tx Ack DLLP Event per TLP for Ras D.E.S
output logic                         rtlh_req_link_retrain,          // Puls : FC Timeout Event per TLP for Ras D.E.S event counter
output logic [`CX_RX_NDLLP -1:0]     rtlh_rcvd_ufc_perdllp ,         // Puls : Rx Update-FC DLLP Event per TLP for Ras D.E.S event counter
output logic [`CX_RX_TLP-1:0]        rtlh_rx_memwr_evt,              // Puls : Rx Memory Write TLP for Ras D.E.S event counter
output logic [`CX_RX_TLP-1:0]        rtlh_rx_defmemwr_evt,           // Puls : Rx Deferrable Memory Write TLP for Ras D.E.S event counter
output logic [`CX_RX_TLP-1:0]        rtlh_rx_memrd_evt,              // Puls : Rx Memory Read TLP for Ras D.E.S event counter
output logic [`CX_RX_TLP-1:0]        rtlh_rx_cfgwr_evt,              // Puls : Rx Config Write TLP for Ras D.E.S event counter
output logic [`CX_RX_TLP-1:0]        rtlh_rx_cfgrd_evt,              // Puls : Rx Config Read TLP for Ras D.E.S event counter
output logic [`CX_RX_TLP-1:0]        rtlh_rx_iowr_evt,               // Puls : Rx I/O Write TLP for Ras D.E.S event counter
output logic [`CX_RX_TLP-1:0]        rtlh_rx_iord_evt,               // Puls : Rx I/O Read TLP for Ras D.E.S event counter
output logic [`CX_RX_TLP-1:0]        rtlh_rx_cplwod_evt,             // Puls : Rx Completion without Data TLP for Ras D.E.S event counter
output logic [`CX_RX_TLP-1:0]        rtlh_rx_cplwd_evt,              // Puls : Rx Completion with Data TLP for Ras D.E.S event counter
output logic [`CX_RX_TLP-1:0]        rtlh_rx_msg_evt,                // Puls : Rx Message TLP for Ras D.E.S event counter
output logic [`CX_RX_TLP-1:0]        rtlh_rx_atmcop_evt,             // Puls : Rx AtomicOp TLP for Ras D.E.S event counter
output logic [`CX_RX_TLP*11-1:0]     rtlh_rx_tlp_dpsize,             // Receiving TLP's data payload size[DW]
output logic [`CX_RX_TLP-1:0]        rtlh_rx_tlpwprefix_evt,         // Puls : Rx TLP with Prefix for Ras D.E.S event counter
output logic [`CX_NL-1:0]    latched_rxdetected,             // Level : PIPE: Detect Lane for Ras D.E.S Silicon Debug
output logic [`CX_NL-1:0]    rpipe_rxelecidle,               // RMLH pipe module output to SMLH
output logic                             rdlh_vc0_initfc1_status,           // Level : VC0 Init-FC1 status for Ras D.E.S Silicon Debug
output logic                             rdlh_vc0_initfc2_status,           // Level : VC0 Init-FC2 status for Ras D.E.S Silicon Debug 
output logic [11:0]                      rdlh_xplh_curnt_rx_ack_seqnum,     // Level : Current Rx Ack Sequence number status for Ras D.E.S Silicon Debug
output logic [11:0]                      xdlh_xplh_curnt_seqnum,            // Level : Current Tx Sequence number status for Ras D.E.S Silicon Debug
output logic [(`CX_NVC*`CX_HCRD_WD)-1:0] rtlh_fc_rcvd_ph,                   // Level : Current FC Credit Received(Posted Header) for Ras D.E.S Silicon Debug
output logic [(`CX_NVC*`CX_DCRD_WD)-1:0] rtlh_fc_rcvd_pd,                   // Level : Current FC Credit Received(Posted Data) for Ras D.E.S Silicon Debug
output logic [(`CX_NVC*`CX_HCRD_WD)-1:0] rtlh_fc_rcvd_nph,                  // Level : Current FC Credit Received(Non-Posted Header) for Ras D.E.S Silicon Debug
output logic [(`CX_NVC*`CX_DCRD_WD)-1:0] rtlh_fc_rcvd_npd,                  // Level : Current FC Credit Received(Non-Posted Data) for Ras D.E.S Silicon Debug
output logic [(`CX_NVC*`CX_HCRD_WD)-1:0] rtlh_fc_rcvd_cplh,                 // Level : Current FC Credit Received(Completion Header) for Ras D.E.S Silicon Debug
output logic [(`CX_NVC*`CX_DCRD_WD)-1:0] rtlh_fc_rcvd_cpld,                 // Level : Current FC Credit Received(Completion Data) for Ras D.E.S Silicon Debug
output logic [(`CX_NVC*`CX_HCRD_WD)-1:0] rtlh_fc_allctd_ph,                 // Level : Current FC Credit Allocated(Posted Header) for Ras D.E.S Silicon Debug
output logic [(`CX_NVC*`CX_DCRD_WD)-1:0] rtlh_fc_allctd_pd,                 // Level : Current FC Credit Allocated(Posted Data) for Ras D.E.S Silicon Debug
output logic [(`CX_NVC*`CX_HCRD_WD)-1:0] rtlh_fc_allctd_nph,                // Level : Current FC Credit Allocated(Non-Posted Header) for Ras D.E.S Silicon Debug
output logic [(`CX_NVC*`CX_DCRD_WD)-1:0] rtlh_fc_allctd_npd,                // Level : Current FC Credit Allocated(Non-Posted Data) for Ras D.E.S Silicon Debug
output logic [(`CX_NVC*`CX_HCRD_WD)-1:0] rtlh_fc_allctd_cplh,               // Level : Current FC Credit Allocated(Completion Header) for Ras D.E.S Silicon Debug,
output logic [(`CX_NVC*`CX_DCRD_WD)-1:0] rtlh_fc_allctd_cpld,               // Level : Current FC Credit Allocated(Completion Data) for Ras D.E.S Silicon Debug,
output logic [2:0]           rdlh_einj0_lcrc_evt,                   // Error injection 0 event flag
output logic                 xmlh_einj0_oscrc_evt,                  // Error injection 0 CRC error event
output logic [1:0]           xdlh_einj0_lcrc_evt,                   // Error injection 0 LCRC event
output logic                 xdlh_einj0_fcrc_evt,                   // Error injection 0 ECRC event
output logic [1:0]           xdlh_einj0_dllpcrc_evt,                // Error injection 0 DLLP CRC event
output logic [1:0]           ras_des_einj1_exp_sequm_evt, 
output logic                 ras_des_einj1_ack_nak_sequm_evt,
output logic                 xdlh_einj2_nak_evt,                    // Error injection 2 NAK event
output logic [1:0]           xmlh_einj3_osmsk_evt,                  // Error injection 3 8b/10b K-code mask event
output logic                 rtlh_einj4_fc_evt,                     // Error injection 4 FC event
output logic                 xdlh_einj5_nultlp_evt,                 // Error injection 5 nullified TLP event
output logic                 xdlh_einj5_dup_evt,                    // Error injection 5 Duplicate TLP event
    // Radm Formation Queue Overflow Prevention Mechanism 
output logic                xdlh_ptm_sot,
output logic                xdlh_ptm_multi_cycle,
output logic                xdlh_ptm_request,
output logic                xdlh_ptm_response,
output logic                xdlh_rbuf_replaying,
output logic                rdlh_ptm_sot,
output logic                rdlh_ptm_multi_cycle,
output logic                rdlh_ptm_request,
output logic                rdlh_ptm_response,
output logic                rdlh_duplicate_tlp,

output logic                rdlh_rcvd_dl_feature,           // Feature DLLP Received
output logic [31:0]         rcvd_dl_feature_content,        // Feature DLLP content

output ras_dp_err_log_t      ras_dp_err_log_xtlh,
output ras_dp_err_log_t      ras_dp_err_log_xdlh,
output ras_dp_err_log_t      xplh_ras_dp_err_log,
output ras_dp_err_log_t      vlsm_ras_dp_err_log,
input  ras_dp_err_inj_t      ras_dp_err_inj,
output logic            smlh_ltssm_in_l0p,                   // Level: L0p
input                                    pm_aux_clk,
input [1:0]                              pm_en_pulse_det,
output logic [1:0]                       pipe_aux_sync_p1_ack,
output logic [1:0]                       pipe_aux_sync_block,

output logic                             mac_phy_cfg_cxl_port_drift_buffer_enabled,
output logic                             mac_phy_ltssm_link_synchdr_bypass_enabled,
input [`CX_NL-1:0]                       sqlchd_rxelecidle,
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
output  logic                   smlh_link_in_training,  // Level: Ltssm is in Config or Recovery
output  logic                   rmlh_prbs_done,         // Finished PBRS Loopback
output  logic                   rmlh_prbs_fail,         // PRBS Comparison error occurred
output  logic [`CX_NL-1:0]      rmlh_prbs_started,      // PRBS started status
output  logic [`CX_NL-1:0][7:0] rmlh_prbs_err_cntr,     // PRBS comparison error counter
output  logic [`CX_NL-1:0]      rmlh_prbs_unexp_fail,   // PRBS unexpeced error occurred
spif_if.cfgi_master_mp                   b_cfgi_lbc,

input             cfg_prbs_en,                    // PRBS Loopback Enable. Need to be set before being set cfg_lpbk_en
input             clear_prbs_done,                // Clear PRBS Status regisers
input       [3:0] cfg_prbs_lane_sel               // PRBS lane select for status registers

);

localparam N_DELAY_GEN5_FPGA        = 0;

localparam EQTS_WD        = 32;                       // Number of bits of Per Lane Equalization Information
localparam   CNT_WIDTH    = 3;
localparam   TS_0_WD      = 48;
localparam   RBUF_WD_NFM  = (`CX_NW>16) ? P_NFM_RBUF_WD : `RBUF_WIDTH;
localparam   DW_WO_PAR    = (32*`CX_NW);                        // Width of datapath in bits.
localparam   OS_WD        = `CX_MAC_SB_WD; // Number of OS width
localparam   NW_NFM       = (`CX_NW > 16) ? 16 : `CX_NW;            // Number of 32-bit dwords handled by the datapath each clock in Non-Flit Mode.
localparam   DCB_WD       = (`CX_NB>=8 ? `CX_NB/8 : 1);             // Number of bits of per rxdata_dcb
localparam CTL_WD = (`CX_NW >= 16) ? 16 : `CX_XTLH_XDLH_CTL_WD; // (`CX_NW == 2)? 1 : @CX_NW

// Interface Declarations
tx_lp_if b_xdlh_xplh();                     // XDLH -> XPLH Transmit Interface
xplh_sideband_struct xplh_sideband;         // struct of xplh signals that are part of xplh/xmlh interface before entering xplh freq_step module 

rbuf_struct                 xplh_retry_ram_if;
  // Retry buffer Interface Struct
rbuf_struct xdlh_retryram_if;

pm_protocol_to_link_struct  pm_protocol_to_link_signals;  // PM Link connections with PM Protocol
pm_link_to_protocol_struct  pm_link_to_protocol_signals;  // PM Link connections with PM Protocol
dllp_struct         pm_xdlh_dllp_req;
dllp_struct         xplh_pm_dllp_ack;
logic                smlh_in_l0_l0s;                 // LTSSM Transmitter in L0 or L0s,
logic                smlh_l123_eidle_timeout;        // LTSSM 2ms Timer timed out while waiting for EIDLE
logic                latched_rcvd_eidle_set;         // That we have received an EIOS
logic                 xmlh_cmd_if_lp_ack;       // Acknowledge from xtlh_cmd_if to PM indicating entering flush state
logic                 pm_xmlh_lp_req;           // PM Request to xtlh_cmd_if to enter low power
logic                 xdlh_no_acknak_dllp_pending;    // XDLH has no ACK/NAK dllp pending. It is a signal for PMC (power management module).
logic                 int_no_acknak_dllp_pending;

logic                 xplh_flit_count_en;
logic [CNT_WIDTH-1:0] xplh_flit_count;
logic [RBUF_WD_NFM-1:0]            retrymux_xdlh_data;              // Data coming back from Retry buffer RAM
logic [`RBUF_PW -1:0]              retrymux_xdlh_depth;             // How big is the external retry buffer
logic                              retrymux_xdlh_parerr;            // retry buffer ram parity error detected
logic                   int_xdlh_xmt_pme_ack;

tx_cmd_struct         xmlh_xplh_cmd;
tx_cmd_struct         xplh_xdlh_cmd;      // Command from SDLH (CXL)/XPLH (PCIe) to XDLH
logic                 xdlh_xplh_cmd_ack; // Command Complete Acknowledge from XDLH to SDLH (CXL)/XPLH (PCIe)
logic  [11:0]               rdlh_curnt_rx_ack_seqnum;  // Level : Current Rx Ack Sequence number status for Ras D.E.S Silicon Debug
logic                       xplh_acknak_pend;
xplh_sideband_rasdes_fm     xplh_rasdes_fm;             // Xplh sideband rasdes will be connected to cx_pl_fm
logic  [P_TX_SEQNUM_WD-1:0] xplh_rx_ack_seqnum;        // Level : Current Rx Ack Sequence number status for Ras D.E.S Silicon Debug
logic  [P_TX_SEQNUM_WD-1:0] xplh_tx_seqnum_value;           // Level : Current Tx Sequence number status for Ras D.E.S Silicon Debug
logic [`RBUF_WIDTH -1:0]  retrymux_xplh_data;             // Data coming back from Retry buffer RAM
logic                 xplh_xdlh_dllp_halt;
fm_dllp_struct        xdlh_xplh_dllp_out;

logic                 xtlh_pm_pme_to_ack;

logic [7:0] smlh_flit_mode_enable_modules;  // both sides agreed to support flit mode per modules [0] rmlh [1] rplh [2] rdlh [3] xfsh/rfsh [4] xmlh [5] xdlh [6] xplh [7] xtlh

rplh_xplh_fm_retry_t        rplh_xplh_fm_retry;              // RPLH to XPLH Flit Mode Retry Interface
wire    [31:0]              rplh_rdlh_fm_dllp_data;          // DLLP data extracted from DL bytes
wire                        rplh_rdlh_fm_dllp_valid;         // Valid DLLP data
wire                        rplh_rdlh_fm_dllp_opt_fc_up;     // DLLP is an Optimized FC update
// XDLH -> XMLH
logic                       xdlh_smlh_link_req;
logic  [4:0]                xdlh_smlh_link_width;
wire                        xdlh_smlh_link_initiated;
//  SMLH -> XDLH
wire                        smlh_ltssm_l0p_ready;
wire                        smlh_xdlh_eios_rcvd;             // Received eieos in flit mode
// SMLH -> XMLH
wire   [5:0]                smlh_l0p_link_mode;      // 10000 -- x16, 01000 -- x8, 00100 -- x4, 00010 -- x2, 00001 -- x1

// From RDLH
wire   [`CX_RX_NDLLP-1:0]   rdlh_rcvd_nack_perdllp;        // Puls : Rx Nak DLLP Event per DLLP for Ras D.E.S event counter

wire    [`CX_NW-1:0]        rplh_rdlh_dllp_start;           // indicate the dword location of SDPor STP
wire    [`CX_NW-1:0]        rplh_rdlh_tlp_start;
wire    [`CX_NW-1:0]        rplh_rdlh_tlp_idl;              // indicates the dword is empty and can be discarded, due to flit overhead it is possible that there are 5 empty dws in the middle of a tlp
wire    [`CX_NW-1:0]        rplh_rdlh_tlp_pfx;              // indicates the dword location of prefixes
wire                        rplh_rdlh_fm_nullified;         // The last TLP ending was Nullified by the Flit Marker
wire                        rplh_rdlh_fm_poisoned;          // The last TLP ending was Poisoned by the Flit Marker
wire                        rplh_rdlh_pkt_dv;
wire    [`CX_NW-1:0]        rplh_rdlh_pkt_end;              // indicate the dword location of END or EBD
wire    [`CX_NW-1:0]        rplh_rdlh_pkt_edb;
wire    [`TRGT_DATA_WD-1:0] rplh_rdlh_pkt_data;
wire    [`CX_NW-1:0]        rplh_rdlh_pkt_err;              // EOP/SOP error in frame

wire    [`CX_NW-1:0]        rplh_rdlh_nak;                  // NAK indication

// From XDLH
wire                        xdlh_smlh_start_link_retrain;
wire                        int_xdlh_smlh_start_link_retrain;
wire    [5:0]               smlh_link_mode;                 // 6 bit link width; 10000 = x16, 1000 = x8, 100 = x4, 10 = x2, 1 = x1
wire    [5:0]               smlh_link_rxmode;               // 6 bit link width; 10000 = x16, 1000 = x8, 100 = x4, 10 = x2, 1 = x1
wire                        smlh_eq_pending;                // Equalization Pending
wire                        smlh_usp_eq_pending;

wire    [11:0]              xdlh_curnt_seqnum;

logic                       xplh_ptm_retry_flit;
wire                        xplh_ptm_sot;
wire                        xplh_ptm_request;
wire                        xplh_ptm_response;

spif_if    b_sdlh_splh_spif();     // SDLH to SPLH SPIF Interface, connects Layer2 to PLH Layer
spif_if    b_vlsm_splh_spif();     // VLSM to SPLH SPIF Interface, connects ARB/MUX to PLH Layer
spif_if    b_sdlh_vlsm_spif();     // SDLH to VLSM SPIF Interface, connects Layer2 to ARB/MUX
spif_if    b_vlsm_cxl_spif();      // VLSM to CXL SPIF Interface, connects ARB/MUX to CXL.cachemem Controller       
spif_if    b_splh_vlsm_spif();     // SPLH to VLSM SPIF Interface, connects PLH Layer to ARB/MUX

protocol_cfg_t               splh_protocol_cfg;  // Protocol Configuration for PLH Layer
protocol_cfg_t               sdlh_protocol_cfg;  // Protocol Configuration for DLH Layer

logic                        pm_block_tlp_ack;   // SDLH Command Interface PM BLOCK_TLP Acknowledge


wire                         rdlh_prot_err;

  logic                     xplh_nak_ignore_link_err;
  wire                      rplh_flit_dl_prot_err;

assign dl_prot_err = rdlh_prot_err || xplh_nak_ignore_link_err || rplh_flit_dl_prot_err ;

wire                        rdlh_rcvd_dllp;

wire                        rplh_ptm_sot;
wire                        rplh_ptm_request;
wire                        rplh_ptm_response;
wire                        rplh_ptm_duplicate;

wire                        xdlh_replay_num_rlover_err;
wire                        xdlh_smlh_enter_recovery; 

assign xdlh_replay_num_rlover_err      = int_xdlh_smlh_start_link_retrain;
assign xdlh_smlh_start_link_retrain    = int_xdlh_smlh_start_link_retrain || xdlh_smlh_enter_recovery; 

wire                        xdlh_replay_timeout_err;   //output from xdlh 
wire                        xmtbyte_stp_start;

logic                       xplh_pending;               // XPLH Pending Signal generated from XPLH tracker


wire lcrc_err_asserted;
wire ecrc_err_asserted;
wire lcrc_err_en_int;
wire ecrc_err_en_int;
  assign cdm_ras_des_einj0_ack     = {ecrc_err_asserted, lcrc_err_asserted};  // TLP Layer
  assign lcrc_err_en_int = cdm_ras_des_einj0_req[0];
  assign ecrc_err_en_int = cdm_ras_des_einj0_req[1];

wire   xdlh_smlh_goto_detect;


//================================================================================================================//
//=================================
//RASDES-FM Internal Wires
logic int_upd_fc_sent;                             // Update FC sent FM
//RASDES-NFM Internal Wires
logic xdlh_retry_req;                             //Retry Req
logic int_xdlh_nak_sent;                         // Nak sent 
logic int_xdlh_ack_sent;                        // Ack  sent 
logic [`CX_TX_NDLLP-1:0] int_xdlh_update_fc_sent;  // Update FC sent NFM
logic                xdlh_ras_des_einj1_ack_nak_sequm_evt;
logic [1:0]          xdlh_ras_des_einj1_exp_sequm_evt; 
logic                xdlh_ras_des_einj2_enable;
logic [1:0]          xdlh_ras_des_einj2_dllp_type;
logic                xdlh_ras_des_einj1_enable;               
logic                xdlh_ras_des_einj1_seq_type;             
logic [12:0]         xdlh_ras_des_einj1_bad_seq;              
logic [7:0]          xdlh_ras_des_einj1_count; 
logic                xplh_ras_des_einj2_enable;
logic [1:0]          xplh_ras_des_einj2_dllp_type;
logic                xplh_ras_des_einj1_enable;               
logic                xplh_ras_des_einj1_seq_type;             
logic [12:0]         xplh_ras_des_einj1_bad_seq;              
logic [7:0]          xplh_ras_des_einj1_count;
logic [1:0]          xplh_ras_des_einj1_exp_sequm_evt;
logic                xplh_ras_des_einj1_ack_nak_sequm_evt;
//=================================

assign xdlh_no_acknak_dllp_pending = latched_flit_mode_enable ? !xplh_acknak_pend : int_no_acknak_dllp_pending;

cx_phy_logical

#(INST) u_cx_phy_logical (
  .xplh_pm_dllp_ack                  (xplh_pm_dllp_ack),
  .xmlh_cmd_if_lp_ack                (xmlh_cmd_if_lp_ack),
  .xmlh_xplh_cmd                     (xmlh_xplh_cmd),
  .pm_xmlh_lp_req                    (pm_xmlh_lp_req),
  .cfg_flit_mode_enable              (cfg_flit_mode_enable),
  .cfg_pcie_cap_flit_mode_sup        (cfg_pcie_cap_flit_mode_sup),
  .cfg_flit_mode_dis                 (cfg_flit_mode_dis),
  .cfg_flit_sris_clocking            (cfg_flit_sris_clocking),
  .cfg_reciver_l0p_supported         (cfg_reciver_l0p_supported),
  .cfg_comm_clk_config               (cfg_comm_clk_config),
  .pm_block_phystatus                (pm_block_phystatus),
  .splh_protocol_cfg                 (splh_protocol_cfg),
  .pm_block_tlp_ack                  (pm_block_tlp_ack),
  .b_splh_spif                       ( b_splh_vlsm_spif.master_mp ), // For CXL connect SPLH to VLSM via SPIF interface
  .cfg_cxl_port_enable               (cfg_cxl_port_enable),
  .cfg_cxl_port_vid                  (cfg_cxl_port_vid),
  .cfg_cxl_retimers_pre_mismatched   (cfg_cxl_retimers_pre_mismatched),
  .cfg_retimers_pre_detected         (cfg_retimers_pre_detected),
  .cfg_pcie_slot_clk_config          (cfg_pcie_slot_clk_config),
  .pm_current_data_rate              (pm_current_data_rate),
  .core_clk                          (core_clk),
  .core_rst_n                        (core_rst_n),
  .app_init_rst                      (app_init_rst),
  .core_clk_ug                       (core_clk_ug),
  .pipe_msgbus_rst_n                 (pipe_msgbus_rst_n),
  .app_sris_mode                     (app_sris_mode),
  .app_ltssm_enable                  (app_ltssm_enable),
  .smlh_training_rst_n               (smlh_training_rst_n),
  .smlh_ltssm_state                  (smlh_ltssm_state),
  .smlh_ltssm_state_o                (smlh_ltssm_state_o),
  .cxpl_debug_info                   (cxpl_debug_info),
  .cxpl_debug_info_ei                (cxpl_debug_info_ei),
  .cfg_rasdp_linkdown_en             (cfg_rasdp_linkdown_en),
  .rasdp_linkdown                    (rasdp_linkdown),
  .rmlh_rcvd_err                     (rmlh_rcvd_err),
  .smlh_autoneg_link_width           (smlh_autoneg_link_width),
  .b_xdlh_xplh_sp                    (b_xdlh_xplh.slave_mp),
  .xplh_sideband                     (xplh_sideband),
  .rplh_link_rxmode                  (rplh_link_rxmode),
  .rplh_flit_dl_prot_err             (rplh_flit_dl_prot_err),
  .xplh_nak_ignore_link_err          (xplh_nak_ignore_link_err),
  .xplh_pending                      (xplh_pending),
  .xplh_xdlh_dllp_halt               (xplh_xdlh_dllp_halt),
  .xplh_retry_ram_if                 (xplh_retry_ram_if),
  .xdlh_xplh_dllp_out                (xdlh_xplh_dllp_out),
  .xplh_rasdes_fm                    (xplh_rasdes_fm),
  .xplh_rx_ack_seqnum                (xplh_rx_ack_seqnum),
  .xplh_tx_seqnum_value              (xplh_tx_seqnum_value),
  .cdm_ras_des_force_linkdown_noack  (cdm_ras_des_force_linkdown_noack),
  .xplh_ras_des_einj1_enable         (xplh_ras_des_einj1_enable),
  .xplh_ras_des_einj1_seq_type       (xplh_ras_des_einj1_seq_type),
  .xplh_ras_des_einj1_bad_seq        (xplh_ras_des_einj1_bad_seq),
  .xplh_ras_des_einj1_count          (xplh_ras_des_einj1_count),
  .xplh_ras_des_einj1_exp_sequm_evt  (xplh_ras_des_einj1_exp_sequm_evt),
  .xplh_ras_des_einj1_ack_nak_sequm_evt  (xplh_ras_des_einj1_ack_nak_sequm_evt),
  .xplh_ras_des_einj2_enable         (xplh_ras_des_einj2_enable),
  .xplh_ras_des_einj2_dllp_type      (xplh_ras_des_einj2_dllp_type),
  .xplh_ptm_sot                      (xplh_ptm_sot),
  .xplh_ptm_request                  (xplh_ptm_request),
  .xplh_ptm_response                 (xplh_ptm_response),
  .rplh_ptm_sot                      (rplh_ptm_sot),
  .rplh_ptm_request                  (rplh_ptm_request),
  .rplh_ptm_response                 (rplh_ptm_response),
  .rplh_ptm_duplicate                (rplh_ptm_duplicate),
  .retrymux_xplh_data                (retrymux_xplh_data),
  .xplh_acknak_pend                  (xplh_acknak_pend),
  .xmtbyte_stp_start                 (xmtbyte_stp_start),
  .xplh_flit_count_en                (xplh_flit_count_en),
  .xplh_flit_count                   (xplh_flit_count),
  .xplh_xdlh_cmd                     (xplh_xdlh_cmd),
  .xdlh_xplh_cmd_ack                 (xdlh_xplh_cmd_ack),
  .smlh_autoneg_link_sp              (smlh_autoneg_link_sp),
  .smlh_link_training_in_prog        (smlh_link_training_in_prog),
  .rplh_xplh_fm_retry                (rplh_xplh_fm_retry),
  .smlh_flit_mode_enable             (smlh_flit_mode_enable),
  .smlh_flit_mode_enable_modules     (smlh_flit_mode_enable_modules),
  .smlh_ltssm_l0p_ready              (smlh_ltssm_l0p_ready),
  .smlh_l0p_link_mode                (smlh_l0p_link_mode),
  .smlh_l0p_capable                  (smlh_l0p_capable),
  .smlh_xdlh_eios_rcvd               (smlh_xdlh_eios_rcvd),
  .xdlh_smlh_link_initiated          (xdlh_smlh_link_initiated),
  .xdlh_smlh_link_width              (xdlh_smlh_link_width),
  .xdlh_smlh_link_req                (xdlh_smlh_link_req),
  .xdlh_smlh_goto_detect             (xdlh_smlh_goto_detect),
  .xdlh_smlh_start_link_retrain      (xdlh_smlh_start_link_retrain),
  .xmlh_sris_enable                  (xmlh_sris_enable),
  .smlh_req_rst_not                  (smlh_req_rst_not),
  .rdlh_rtlh_link_state              (rdlh_rtlh_link_state),
  .rdlh_rcvd_dllp                    (rdlh_rcvd_dllp),
  .rplh_rdlh_dllp_start              (rplh_rdlh_dllp_start),
  .rplh_rdlh_tlp_start               (rplh_rdlh_tlp_start),
  .rplh_rdlh_nak                     (rplh_rdlh_nak),
  .rplh_rdlh_tlp_idl                 (rplh_rdlh_tlp_idl),
  .rplh_rdlh_tlp_pfx                 (rplh_rdlh_tlp_pfx),
  .rplh_rdlh_fm_nullified            (rplh_rdlh_fm_nullified),
  .rplh_rdlh_fm_poisoned             (rplh_rdlh_fm_poisoned),
  .rplh_rdlh_fm_dllp_data            (rplh_rdlh_fm_dllp_data),
  .rplh_rdlh_fm_dllp_valid           (rplh_rdlh_fm_dllp_valid),
  .rplh_rdlh_fm_dllp_opt_fc_up       (rplh_rdlh_fm_dllp_opt_fc_up),
  .rplh_rdlh_pkt_dv                  (rplh_rdlh_pkt_dv),
  .rplh_rdlh_pkt_end                 (rplh_rdlh_pkt_end),
  .rplh_rdlh_pkt_edb                 (rplh_rdlh_pkt_edb),
  .rplh_rdlh_pkt_data                (rplh_rdlh_pkt_data),
  .rplh_rdlh_pkt_err                 (rplh_rdlh_pkt_err),
  .cfg_upstream_port                 (cfg_upstream_port),
  .cfg_root_compx                    (cfg_root_compx),
  .cfg_acknack_disable               (cfg_acknack_disable),
  .cfg_scramble_dis                  (cfg_scramble_dis),
  .cfg_n_fts                         (cfg_n_fts),
  .cfg_link_dis                      (cfg_link_dis),
  .cfg_lpbk_en                       (cfg_lpbk_en),
  .cfg_link_num                      (cfg_link_num),
  .cfg_ts2_lid_deskew                (cfg_ts2_lid_deskew),
  .cfg_support_part_lanes_rxei_exit  (cfg_support_part_lanes_rxei_exit),
  .cfg_forced_link_state             (cfg_forced_link_state),
  .cfg_forced_ltssm_cmd              (cfg_forced_ltssm_cmd),
  .cfg_force_en                      (cfg_force_en),
  .cfg_fast_link_mode                (cfg_fast_link_mode),
  .cfg_fast_link_scaling_factor      (cfg_fast_link_scaling_factor),
  .cfg_l0s_supported                 (cfg_l0s_supported),
  .cfg_elastic_buffer_mode           (cfg_elastic_buffer_mode),
  .cfg_link_capable                  (cfg_link_capable),
  .cfg_lane_skew                     (cfg_lane_skew),
  .cfg_deskew_disable                (cfg_deskew_disable),
  .cfg_imp_num_lanes                 (cfg_imp_num_lanes),
  .cfg_skip_interval                 (cfg_skip_interval),
  .cfg_ext_synch                     (cfg_ext_synch),
  .cfg_hw_autowidth_dis              (cfg_hw_autowidth_dis),
  .cfg_reset_assert                  (cfg_reset_assert),
  .cfg_link_retrain                  (cfg_link_retrain),
  .cfg_margin_num_timing_steps       (cfg_margin_num_timing_steps),
  .cfg_margin_max_timing_offset      (cfg_margin_max_timing_offset),
  .cfg_margin_num_voltage_steps      (cfg_margin_num_voltage_steps),
  .cfg_margin_max_voltage_offset     (cfg_margin_max_voltage_offset),
  .cfg_margin_sample_rate_voltage    (cfg_margin_sample_rate_voltage),
  .cfg_margin_sample_rate_timing     (cfg_margin_sample_rate_timing),
  .cfg_margin_maxlanes               (cfg_margin_maxlanes),
  .cfg_margin_voltage_supported      (cfg_margin_voltage_supported),
  .cfg_margin_ind_left_right_timing  (cfg_margin_ind_left_right_timing),
  .cfg_margin_ind_up_down_voltage    (cfg_margin_ind_up_down_voltage),
  .cfg_margin_sample_reporting_method  (cfg_margin_sample_reporting_method),
  .cfg_margin_ind_error_sampler      (cfg_margin_ind_error_sampler),
  .cfg_rx_message_bus_write_buffer_depth   (cfg_rx_message_bus_write_buffer_depth),
  .cfg_pipe_garbage_data_mode              (cfg_pipe_garbage_data_mode),
  .cfg_pam4_restricted_levels_requirement  (cfg_pam4_restricted_levels_requirement),
  .device_type                       (device_type),
  .smlh_link_rxmode                  (smlh_link_rxmode),
  .smlh_link_mode                    (smlh_link_mode),
  .smlh_link_up                      (smlh_link_up),
  .smlh_in_l0                        (smlh_in_l0),
  .smlh_in_l0s                       (smlh_in_l0s),
  .smlh_in_l0_l0s                    (smlh_in_l0_l0s),
  .smlh_in_rl0s                      (smlh_in_rl0s),
  .smlh_in_l1                        (smlh_in_l1),
  .smlh_in_l23                       (smlh_in_l23),
  .smlh_l123_eidle_timeout           (smlh_l123_eidle_timeout),
  .latched_rcvd_eidle_set            (latched_rcvd_eidle_set),
  .rmlh_descrambled_even_parity      (rmlh_descrambled_even_parity),
  .xmlh_scramble_even_parity         (xmlh_scramble_even_parity),
  .pm_xdlh_dllp_req                  (pm_xdlh_dllp_req),
  .cfg_lane_en                       (cfg_lane_en),
  .cfg_gen1_ei_inference_mode        (cfg_gen1_ei_inference_mode),
  .cfg_select_deemph_mux_bus         (cfg_select_deemph_mux_bus),
  .cfg_lut_ctrl                      (cfg_lut_ctrl),
  .cfg_rxstandby_control             (cfg_rxstandby_control),
  .smlh_bw_mgt_status                (smlh_bw_mgt_status),
  .smlh_link_auto_bw_status          (smlh_link_auto_bw_status),
  .current_data_rate                 (current_data_rate),
  .pm_current_data_rate_others       (pm_current_data_rate_others),
  .cfg_pl_gen3_control               (cfg_pl_gen3_control),
  .cfg_pl_gen3_eq_control            (cfg_pl_gen3_eq_control),
  .cfg_fdbk_dirchange_control        (cfg_fdbk_dirchange_control),
  .cfg_pl_gen3_zrxdc_noncompl        (cfg_pl_gen3_zrxdc_noncompl),
  .cfg_no_seed_value_change          (cfg_no_seed_value_change),
  .cfg_perform_eq                    (cfg_perform_eq),
  .cfg_ls2_eq_req                    (cfg_ls2_eq_req),
  .cfg_pl_gen4_control               (cfg_pl_gen4_control),
  .cfg_pl_gen4_eq_control            (cfg_pl_gen4_eq_control),
  .cfg_gen4_fdbk_dirchange_control   (cfg_gen4_fdbk_dirchange_control),
  .cfg_lec_g4_pset_lrx               (cfg_lec_g4_pset_lrx),
  .cfg_lec_g4_pset_rrx               (cfg_lec_g4_pset_rrx),
  .cfg_pl_gen5_control               (cfg_pl_gen5_control),
  .cfg_pl_gen5_eq_control            (cfg_pl_gen5_eq_control),
  .cfg_gen5_fdbk_dirchange_control   (cfg_gen5_fdbk_dirchange_control),
  .cfg_bypass_eq_enable              (cfg_bypass_eq_enable),
  .cfg_no_eq_needed_enable           (cfg_no_eq_needed_enable),
  .cfg_tx_precode_req                (cfg_tx_precode_req),
  .cfg_lec_g5_pset_lrx               (cfg_lec_g5_pset_lrx),
  .cfg_lec_g5_pset_rrx               (cfg_lec_g5_pset_rrx),
  .cfg_pl_gen6_control               (cfg_pl_gen6_control),
  .cfg_pl_gen6_eq_control            (cfg_pl_gen6_eq_control),
  .cfg_g6_tx_precode_req             (cfg_g6_tx_precode_req),
  .cfg_gen6_fdbk_dirchange_control   (cfg_gen6_fdbk_dirchange_control),
  .cfg_lec_g6_pset_lrx               (cfg_lec_g6_pset_lrx),
  .cfg_lec_g6_pset_rrx               (cfg_lec_g6_pset_rrx),
  .cfg_alt_protocol_enable           (cfg_alt_protocol_enable),
  .cfg_pl_multilane_control          (cfg_pl_multilane_control),
  .sticky_rst_n                      (sticky_rst_n),
  .cfg_gen2_support                  (cfg_gen2_support),
  .cfg_pcie_max_link_speed           (cfg_pcie_max_link_speed),
  .cfg_gen2_n_fts                    (cfg_gen2_n_fts),
  .cfg_target_link_speed             (cfg_target_link_speed),
  .cfg_enter_compliance              (cfg_enter_compliance),
  .cfg_sel_de_emphasis               (cfg_sel_de_emphasis),
  .cfg_transmit_margin               (cfg_transmit_margin),
  .cfg_enter_mod_compliance          (cfg_enter_mod_compliance),
  .cfg_compliance_sos                (cfg_compliance_sos),
  .cfg_compliance_de_emphasis        (cfg_compliance_de_emphasis),
  .cfg_directed_speed_change         (cfg_directed_speed_change),
  .cfg_phy_txswing                   (cfg_phy_txswing),
  .cfg_tx_compliance_rcv             (cfg_tx_compliance_rcv),
  .smlh_clr_enter_compliance         (smlh_clr_enter_compliance),
  .smlh_tx_margin_rst                (smlh_tx_margin_rst),
  .smlh_core_rst_n_release_pulse     (smlh_core_rst_n_release_pulse),
  .smlh_dir_spd_chg_rising_edge      (smlh_dir_spd_chg_rising_edge),
  .smlh_dir_linkw_chg_started        (smlh_dir_linkw_chg_started),
  .smlh_ltssm_in_hotrst_dis_entry    (smlh_ltssm_in_hotrst_dis_entry),
  .usp_g3_eq_redo_executed_int       (usp_g3_eq_redo_executed_int),
  .usp_g4_eq_redo_executed_int       (usp_g4_eq_redo_executed_int),
  .usp_g5_eq_redo_executed_int       (usp_g5_eq_redo_executed_int),
  .smlh_ls2_eq_req                   (smlh_ls2_eq_req),
  .smlh_ls2_eq_success               (smlh_ls2_eq_success),
  .smlh_ls2_eq_cmpl                  (smlh_ls2_eq_cmpl),
  .smlh_ls2_eq_enter                 (smlh_ls2_eq_enter),
  .smlh_ltssm_in_detectquiet         (smlh_ltssm_in_detectquiet),
  .smlh_ltssm_state_rcvry_eq         (smlh_ltssm_state_rcvry_eq),
  .smlh_ls2_g4_eq_req                (smlh_ls2_g4_eq_req),
  .smlh_ls2_g4_eq_success            (smlh_ls2_g4_eq_success),
  .smlh_ls2_g4_eq_cmpl               (smlh_ls2_g4_eq_cmpl),
  .smlh_ls2_g4_eq_enter              (smlh_ls2_g4_eq_enter),
  .smlh_lec_g4_pset_lrx              (smlh_lec_g4_pset_lrx),
  .smlh_ls2_g5_eq_req                (smlh_ls2_g5_eq_req),
  .smlh_ls2_g5_eq_success            (smlh_ls2_g5_eq_success),
  .smlh_ls2_g5_eq_cmpl               (smlh_ls2_g5_eq_cmpl),
  .smlh_ls2_g5_eq_enter              (smlh_ls2_g5_eq_enter),
  .smlh_lec_g5_pset_lrx              (smlh_lec_g5_pset_lrx),
  .smlh_elbc_rcvd                    (smlh_elbc_rcvd),
  .smlh_tx_precoding_on              (smlh_tx_precoding_on),
  .smlh_noeq_needed_rcvd             (smlh_noeq_needed_rcvd),
  .smlh_ls2_g6_eq_req                (smlh_ls2_g6_eq_req),
  .smlh_ls2_g6_eq_success            (smlh_ls2_g6_eq_success),
  .smlh_ls2_g6_eq_cmpl               (smlh_ls2_g6_eq_cmpl),
  .smlh_ls2_g6_eq_enter              (smlh_ls2_g6_eq_enter),
  .smlh_lec_g6_pset_lrx              (smlh_lec_g6_pset_lrx),
  .smlh_g6_tx_precoding_on           (smlh_g6_tx_precoding_on),
  .smlh_retimer_pre_detected         (smlh_retimer_pre_detected),
  .smlh_two_retimers_pre_detected    (smlh_two_retimers_pre_detected),
  .smlh_crosslink_resolution         (smlh_crosslink_resolution),
  .smlh_margin_ready                 (smlh_margin_ready),
  .smlh_mod_ts_rcvd                  (smlh_mod_ts_rcvd),
  .mod_ts_data_rcvd                  (mod_ts_data_rcvd),
  .mod_ts_data_sent                  (mod_ts_data_sent),
  .pm_smlh_l1_2_latched              (pm_smlh_l1_2_latched),
  .pm_smlh_l1_n_latched              (pm_smlh_l1_n_latched),
  .cfg_l1sub_t_common_mode           (cfg_l1sub_t_common_mode),
  .smlh_eq_pending                   (smlh_eq_pending),
  .smlh_usp_eq_pending               (smlh_usp_eq_pending),
  .phy_mac_dirfeedback               (phy_mac_dirfeedback),
  .phy_mac_fomfeedback               (phy_mac_fomfeedback),
  .mac_phy_powerdown                 (mac_phy_powerdown),
  .phy_mac_phystatus                 (phy_mac_phystatus),
  .pipe_rx_clk                       (pipe_rx_clk),
  .pipe_rx_rst_n                     (pipe_rx_rst_n),
  .phy_mac_rxdata                    (phy_mac_rxdata),
  .phy_mac_rxvalid                   (phy_mac_rxvalid),
  .phy_mac_rxstatus                  (phy_mac_rxstatus),
  .phy_mac_rxstandbystatus           (phy_mac_rxstandbystatus),
  .mac_phy_txcompliance              (mac_phy_txcompliance),
  .mac_phy_width                     (mac_phy_width),
  .mac_phy_rate                      (mac_phy_rate),
  .phy_mac_messagebus                (phy_mac_messagebus),
  .esm_current_rate                  (esm_current_rate),
  .ltssm_cxl_enable                  (ltssm_cxl_enable),
  .cfg_drift_buffer_deskew_enable    (cfg_drift_buffer_deskew_enable),
  .cxl_link_enable                   (cxl_link_enable),
  .rplh_cxl_corr_pid_err             (rplh_cxl_corr_pid_err),
  .rplh_cxl_uncorr_pid_err           (rplh_cxl_uncorr_pid_err),
  .rplh_cxl_unexp_pid_err            (rplh_cxl_unexp_pid_err),
  .ltssm_cxl_mod_ts_phase1_rcvd      (ltssm_cxl_mod_ts_phase1_rcvd),
  .ltssm_cxl_retimers_pre_mismatched  (ltssm_cxl_retimers_pre_mismatched),
  .ltssm_cxl_flexbus_phase2_mismatched  (ltssm_cxl_flexbus_phase2_mismatched),
  .rplh_cdm_flit_logging_interface   (rplh_cdm_flit_logging_interface),
  .rmlh_cdm_flit_logging_interface   (rmlh_cdm_flit_logging_interface),
  .smlh_cdm_flit_logging_interface   (smlh_cdm_flit_logging_interface),
  .cfg_tx_throttling                 (cfg_tx_throttling),
  .cfg_flit_err_inj_latency          (cfg_flit_err_inj_latency),
  .cfg_os_einj_ctrl_1                (cfg_os_einj_ctrl_1),
  .cfg_os_einj_ctrl_2                (cfg_os_einj_ctrl_2),
  .xmlh_tx_os_einj_status            (xmlh_tx_os_einj_status),
  .cdm_plh_flit_err_inj_interface    (cdm_plh_flit_err_inj_interface),
  .plh_cdm_flit_err_inj_status       (plh_cdm_flit_err_inj_status),
  .cdm_xplh_flit_response_type       (cdm_xplh_flit_response_type),
  .cdm_xplh_flit_type_measured       (cdm_xplh_flit_type_measured),
  .cdm_xplh_flit_track_mode          (cdm_xplh_flit_track_mode),
  .xplh_cdm_flit_latency_tracking    (xplh_cdm_flit_latency_tracking),
  .smlh_pm_state_trans1_flag         (smlh_pm_state_trans1_flag),
  .smlh_pm_state_trans2_flag         (smlh_pm_state_trans2_flag),
  .cfg_gen3_eq_fs_lf                 (cfg_gen3_eq_fs_lf),
  .cfg_gen3_eq_coef                  (cfg_gen3_eq_coef),
  .cfg_gen4_eq_fs_lf                 (cfg_gen4_eq_fs_lf),
  .cfg_gen4_eq_coef                  (cfg_gen4_eq_coef),
  .cfg_gen5_eq_fs_lf                 (cfg_gen5_eq_fs_lf),
  .cfg_gen5_eq_coef                  (cfg_gen5_eq_coef),
  .cfg_gen6_eq_fs_lf                 (cfg_gen6_eq_fs_lf),
  .cfg_gen6_eq_coef                  (cfg_gen6_eq_coef),
  .smlh_lane_flip_ctrl               (smlh_lane_flip_ctrl),
  .pm_current_powerdown_p1           (pm_current_powerdown_p1),
  .pm_current_powerdown_p0           (pm_current_powerdown_p0),
  .pm_int_phy_powerdown              (pm_int_phy_powerdown),
  .pm_rx_lane_flip_en                (pm_rx_lane_flip_en),
  .pm_tx_lane_flip_en                (pm_tx_lane_flip_en),
  .pm_rx_pol_lane_flip_ctrl          (pm_rx_pol_lane_flip_ctrl),
  .tx_lane_flip_en                   (tx_lane_flip_en),
  .cfg_pm_clk_pm_en                  (cfg_pm_clk_pm_en),
  .cfg_pl_l1_nowait_p1               (cfg_pl_l1_nowait_p1),
  .pm_linkst_in_l0s                  (pm_linkst_in_l0s),
  .pm_smlh_l1_exit                   (pm_smlh_l1_exit),
  .pm_smlh_l23_exit                  (pm_smlh_l23_exit),
  .pm_hold_exit_l1                   (pm_hold_exit_l1),
  .pm_link_exit_l1                   (pm_link_exit_l1),
  .pm_link_exit_l23                  (pm_link_exit_l23),
  .pm_pl_wake_ack                    (pm_pl_wake_ack),
  .pm_pl_clk_req                     (pm_pl_clk_req),
  .pm_pl_phyinl1                     (pm_pl_phyinl1),
  .pm_pl_phyinl2                     (pm_pl_phyinl2),
  .pm_usp_link_state                 (pm_usp_link_state),
  .pm_dsp_link_state                 (pm_dsp_link_state),
  .pm_protocol_to_link_signals       (pm_protocol_to_link_signals),
  .pm_link_to_protocol_signals       (pm_link_to_protocol_signals),
  .cdm_ras_des_pm_entry_interval     (cdm_ras_des_pm_entry_interval),
  .cdm_ras_des_eidle_cnt_sel         (cdm_ras_des_eidle_cnt_sel),
  .cdm_ras_des_ltssm_stop            (cdm_ras_des_ltssm_stop),
  .cdm_ras_des_recovery_req          (cdm_ras_des_recovery_req),
  .cdm_ras_des_ferr_rec_dis          (cdm_ras_des_ferr_rec_dis),
  .cdm_ras_des_direct_rcvry_idle_to_cfg    (cdm_ras_des_direct_rcvry_idle_to_cfg),
  .cdm_ras_des_direct_poll_cmp_to_det      (cdm_ras_des_direct_poll_cmp_to_det),
  .cdm_ras_des_direct_lpbk_slave_to_exit   (cdm_ras_des_direct_lpbk_slave_to_exit),
  .cdm_ras_des_force_rxdetected_en         (cdm_ras_des_force_rxdetected_en),
  .cdm_ras_des_ext_eq_to_factor      (cdm_ras_des_ext_eq_to_factor),
  .cdm_ras_des_eq_fom_target_en      (cdm_ras_des_eq_fom_target_en),
  .cdm_ras_des_eq_force_coef_rtx_en  (cdm_ras_des_eq_force_coef_rtx_en),
  .cdm_ras_des_eq_force_pset_lrx_en  (cdm_ras_des_eq_force_pset_lrx_en),
  .cdm_ras_des_eq_force_coef_ltx_en  (cdm_ras_des_eq_force_coef_ltx_en),
  .cdm_ras_des_eq_force_coef_ltx     (cdm_ras_des_eq_force_coef_ltx),
  .cdm_ras_des_eq_force_pset_lrx     (cdm_ras_des_eq_force_pset_lrx),
  .cdm_ras_des_eq_force_coef_rtx     (cdm_ras_des_eq_force_coef_rtx),
  .cdm_ras_des_eq_force_pset_ltx_en  (cdm_ras_des_eq_force_pset_ltx_en),
  .cdm_ras_des_eq_force_usp_pset_ltx (cdm_ras_des_eq_force_usp_pset_ltx),
  .cdm_ras_des_eq_force_coef_rtx_en_g4   (cdm_ras_des_eq_force_coef_rtx_en_g4),
  .cdm_ras_des_eq_force_coef_ltx_en_g4   (cdm_ras_des_eq_force_coef_ltx_en_g4),
  .cdm_ras_des_eq_force_coef_ltx_g4      (cdm_ras_des_eq_force_coef_ltx_g4),
  .cdm_ras_des_eq_force_coef_rtx_g4      (cdm_ras_des_eq_force_coef_rtx_g4),
  .cdm_ras_des_eq_force_pset_ltx_en_g4   (cdm_ras_des_eq_force_pset_ltx_en_g4),
  .cdm_ras_des_eq_force_usp_pset_ltx_g4  (cdm_ras_des_eq_force_usp_pset_ltx_g4),
  .cdm_ras_des_eq_force_coef_rtx_en_g5   (cdm_ras_des_eq_force_coef_rtx_en_g5),
  .cdm_ras_des_eq_force_coef_ltx_en_g5   (cdm_ras_des_eq_force_coef_ltx_en_g5),
  .cdm_ras_des_eq_force_coef_ltx_g5      (cdm_ras_des_eq_force_coef_ltx_g5),
  .cdm_ras_des_eq_force_coef_rtx_g5      (cdm_ras_des_eq_force_coef_rtx_g5),
  .cdm_ras_des_eq_force_pset_ltx_en_g5   (cdm_ras_des_eq_force_pset_ltx_en_g5),
  .cdm_ras_des_eq_force_usp_pset_ltx_g5  (cdm_ras_des_eq_force_usp_pset_ltx_g5),
  .cdm_ras_des_eq_force_coef_rtx_en_g6   (cdm_ras_des_eq_force_coef_rtx_en_g6),
  .cdm_ras_des_eq_force_coef_ltx_en_g6   (cdm_ras_des_eq_force_coef_ltx_en_g6),
  .cdm_ras_des_eq_force_coef_ltx_g6      (cdm_ras_des_eq_force_coef_ltx_g6),
  .cdm_ras_des_eq_force_coef_rtx_g6      (cdm_ras_des_eq_force_coef_rtx_g6),
  .cdm_ras_des_eq_force_pset_ltx_en_g6   (cdm_ras_des_eq_force_pset_ltx_en_g6),
  .cdm_ras_des_eq_force_usp_pset_ltx_g6  (cdm_ras_des_eq_force_usp_pset_ltx_g6),
  .cdm_ras_des_eq_fom_target         (cdm_ras_des_eq_fom_target),
  .cdm_ras_des_eq_eval_interval      (cdm_ras_des_eq_eval_interval),
  .cdm_ras_des_einj0_enable          (cdm_ras_des_einj0_enable),
  .cdm_ras_des_einj0_crc_type        (cdm_ras_des_einj0_crc_type),
  .cdm_ras_des_einj0_count           (cdm_ras_des_einj0_count),
  .cdm_ras_des_einj3_enable          (cdm_ras_des_einj3_enable),
  .cdm_ras_des_einj3_count           (cdm_ras_des_einj3_count),
  .cdm_ras_des_einj3_smb_type        (cdm_ras_des_einj3_smb_type),
  .rmlh_rpipe_rxoverflow             (rmlh_rpipe_rxoverflow),
  .rmlh_rpipe_rxunderflow            (rmlh_rpipe_rxunderflow),
  .rmlh_rpipe_rxcodeerror            (rmlh_rpipe_rxcodeerror),
  .rmlh_rpipe_rxdisperror            (rmlh_rpipe_rxdisperror),
  .rmlh_rpipe_rxskipadded            (rmlh_rpipe_rxskipadded),
  .rmlh_rpipe_rxskipremoved          (rmlh_rpipe_rxskipremoved),
  .rmlh_skp_parity_err               (rmlh_skp_parity_err),
  .rmlh_sync_header_err              (rmlh_sync_header_err),
  .rmlh_framing_err                  (rmlh_framing_err),
  .rmlh_framing_err_ptr              (rmlh_framing_err_ptr),
  .rmlh_framing_err_l0               (rmlh_framing_err_l0),
  .rmlh_deskew_alignment_err         (rmlh_deskew_alignment_err),
  .rmlh_deskew_fifo_ptr              (rmlh_deskew_fifo_ptr),
  .rmlh_rxvalid_deasserted           (rmlh_rxvalid_deasserted),
  .smlh_eidle_inferred_in_l0         (smlh_eidle_inferred_in_l0),
  .smlh_rx_rcvry_req                 (smlh_rx_rcvry_req),
  .smlh_timeout_nfts                 (smlh_timeout_nfts),
  .smlh_l0_to_recovery               (smlh_l0_to_recovery),
  .smlh_l1_to_recovery               (smlh_l1_to_recovery),
  .smlh_rcv_eios_when_l0s_unsprt     (smlh_rcv_eios_when_l0s_unsprt),
  .smlh_deskew_uncomplete_err        (smlh_deskew_uncomplete_err),
  .smlh_spd_change                   (smlh_spd_change),
  .smseq_mcs_sts                     (smseq_mcs_sts),
  .smlh_lwd_change                   (smlh_lwd_change),
  .smlh_ltssm_variable               (smlh_ltssm_variable),
  .smseq_ts_debug_info               (smseq_ts_debug_info),
  .smlh_rxos_type                    (smlh_rxos_type),
  .int_ltssm_powerdown               (int_ltssm_powerdown),
  .latched_ts_nfts                   (latched_ts_nfts),
  .init_eq_pending                   (init_eq_pending),
  .mac_cdm_ras_des_fs                (mac_cdm_ras_des_fs),
  .mac_cdm_ras_des_lf                (mac_cdm_ras_des_lf),
  .mac_cdm_ras_des_coef_ltx          (mac_cdm_ras_des_coef_ltx),
  .phy_cdm_ras_des_fomfeedback       (phy_cdm_ras_des_fomfeedback),
  .eqpa_violate_rule_123             (eqpa_violate_rule_123),
  .eq_convergence_sts                (eq_convergence_sts),
  .mac_cdm_ras_des_coef_rtx          (mac_cdm_ras_des_coef_rtx),
  .mac_cdm_ras_des_pset_lrx          (mac_cdm_ras_des_pset_lrx),
  .mac_cdm_ras_des_reject_rtx        (mac_cdm_ras_des_reject_rtx),
  .init_eq_pending_g4                (init_eq_pending_g4),
  .mac_cdm_ras_des_fs_g4             (mac_cdm_ras_des_fs_g4),
  .mac_cdm_ras_des_lf_g4             (mac_cdm_ras_des_lf_g4),
  .mac_cdm_ras_des_coef_ltx_g4       (mac_cdm_ras_des_coef_ltx_g4),
  .phy_cdm_ras_des_fomfeedback_g4    (phy_cdm_ras_des_fomfeedback_g4),
  .eqpa_violate_rule_123_g4          (eqpa_violate_rule_123_g4),
  .eq_convergence_sts_g4             (eq_convergence_sts_g4),
  .mac_cdm_ras_des_coef_rtx_g4       (mac_cdm_ras_des_coef_rtx_g4),
  .mac_cdm_ras_des_reject_rtx_g4     (mac_cdm_ras_des_reject_rtx_g4),
  .init_eq_pending_g5                (init_eq_pending_g5),
  .mac_cdm_ras_des_fs_g5             (mac_cdm_ras_des_fs_g5),
  .mac_cdm_ras_des_lf_g5             (mac_cdm_ras_des_lf_g5),
  .mac_cdm_ras_des_coef_ltx_g5       (mac_cdm_ras_des_coef_ltx_g5),
  .phy_cdm_ras_des_fomfeedback_g5    (phy_cdm_ras_des_fomfeedback_g5),
  .eqpa_violate_rule_123_g5          (eqpa_violate_rule_123_g5),
  .eq_convergence_sts_g5             (eq_convergence_sts_g5),
  .mac_cdm_ras_des_coef_rtx_g5       (mac_cdm_ras_des_coef_rtx_g5),
  .mac_cdm_ras_des_reject_rtx_g5     (mac_cdm_ras_des_reject_rtx_g5),
  .init_eq_pending_g6                (init_eq_pending_g6),
  .mac_cdm_ras_des_fs_g6             (mac_cdm_ras_des_fs_g6),
  .mac_cdm_ras_des_lf_g6             (mac_cdm_ras_des_lf_g6),
  .mac_cdm_ras_des_coef_ltx_g6       (mac_cdm_ras_des_coef_ltx_g6),
  .phy_cdm_ras_des_fomfeedback_g6    (phy_cdm_ras_des_fomfeedback_g6),
  .eqpa_violate_rule_123_g6          (eqpa_violate_rule_123_g6),
  .eqpa_violate_rule_4_g6            (eqpa_violate_rule_4_g6),
  .eq_convergence_sts_g6             (eq_convergence_sts_g6),
  .mac_cdm_ras_des_coef_rtx_g6       (mac_cdm_ras_des_coef_rtx_g6),
  .mac_cdm_ras_des_reject_rtx_g6     (mac_cdm_ras_des_reject_rtx_g6),
  .rl0s_state                        (rl0s_state),
  .latched_rxdetected                (latched_rxdetected),
  .rpipe_rxelecidle                  (rpipe_rxelecidle),
  .xmlh_einj0_oscrc_evt              (xmlh_einj0_oscrc_evt),
  .xmlh_einj3_osmsk_evt              (xmlh_einj3_osmsk_evt),
  .rtlh_req_link_retrain             (rtlh_req_link_retrain),
  .xplh_ras_dp_err_log               (xplh_ras_dp_err_log),
  .ras_dp_err_inj                    (ras_dp_err_inj),
  .smlh_ltssm_in_l0p                 (smlh_ltssm_in_l0p),

  .pm_aux_clk                        (pm_aux_clk),
  .pm_en_pulse_det                   (pm_en_pulse_det),
  .sqlchd_rxelecidle                 (sqlchd_rxelecidle),
  .pipe_aux_sync_p1_ack              (pipe_aux_sync_p1_ack),
  .pipe_aux_sync_block               (pipe_aux_sync_block),

  .mac_phy_ltssm_link_synchdr_bypass_enabled  (mac_phy_ltssm_link_synchdr_bypass_enabled),
  .mac_phy_cfg_cxl_port_drift_buffer_enabled  (mac_phy_cfg_cxl_port_drift_buffer_enabled),
  .serdes_pipe_turnoff_lanes                  (serdes_pipe_turnoff_lanes),
  .pre_mac_phy_powerdown                      (pre_mac_phy_powerdown),
  .int_mac_phy_txelecidle                     (int_mac_phy_txelecidle),
  .pre_mac_phy_txdata                         (pre_mac_phy_txdata),
  .pre_mac_phy_txdetectrx_loopback            (pre_mac_phy_txdetectrx_loopback),
  .glue_mac_phy_txcompliance                  (glue_mac_phy_txcompliance),
  .pre_mac_phy_rxpolarity                     (pre_mac_phy_rxpolarity),
  .tmp_mac_phy_rxpolarity                     (tmp_mac_phy_rxpolarity),
  .tmp_int_mac_phy_rate                       (tmp_int_mac_phy_rate),
  .tmp_mac_phy_txdeemph_0                     (tmp_mac_phy_txdeemph_0),
  .pre_mac_phy_width                          (pre_mac_phy_width),
  .pre_mac_phy_serdes_arch                    (pre_mac_phy_serdes_arch),
  .pre_mac_phy_rxwidth                        (pre_mac_phy_rxwidth),
  .pre_serdes_pipe_rxready                    (pre_serdes_pipe_rxready),
  .pre_mac_phy_pclk_rate                      (pre_mac_phy_pclk_rate),
  .pre_mac_phy_rxstandby                      (pre_mac_phy_rxstandby),
  .pre_mac_phy_rate                           (pre_mac_phy_rate),
  .pre_mac_phy_txdeemph                       (pre_mac_phy_txdeemph),
  .pre_mac_phy_txdatavalid                    (pre_mac_phy_txdatavalid),
  .pre_mac_phy_rxeqeval                       (pre_mac_phy_rxeqeval),
  .pre_mac_phy_dirchange                      (pre_mac_phy_dirchange),
  .pre_mac_phy_smlh_coef_rtx                  (pre_mac_phy_smlh_coef_rtx),
  .pre_mac_phy_blockaligncontrol_o            (pre_mac_phy_blockaligncontrol_o),
  .pre_mac_phy_mbus                           (pre_mac_phy_mbus),
  .cfg_pipe_loopback                          (cfg_pipe_loopback),
  .cfg_rxstatus_lane                          (cfg_rxstatus_lane),
  .cfg_rxstatus_value                         (cfg_rxstatus_value),
  .cfg_lpbk_rxvalid                           (cfg_lpbk_rxvalid),
  .int_cfg_lec_pset_ltx                       (int_cfg_lec_pset_ltx),
  .int_cfg_lec_pset_lrx                       (int_cfg_lec_pset_lrx),
  .int_cfg_lec_pset_rtx                       (int_cfg_lec_pset_rtx),
  .int_cfg_lec_pset_rrx                       (int_cfg_lec_pset_rrx),
  .int_cfg_lec_g4_pset_ltx                    (int_cfg_lec_g4_pset_ltx),
  .int_cfg_lec_g4_pset_rtx                    (int_cfg_lec_g4_pset_rtx),
  .int_cfg_lec_g5_pset_ltx                    (int_cfg_lec_g5_pset_ltx),
  .int_cfg_lec_g5_pset_rtx                    (int_cfg_lec_g5_pset_rtx),
  .int_cfg_lec_g6_pset_ltx                    (int_cfg_lec_g6_pset_ltx),
  .int_cfg_lec_g6_pset_rtx                    (int_cfg_lec_g6_pset_rtx),
  .int_cfg_margin_control                     (int_cfg_margin_control),
  .int_cdm_ras_des_force_rxdetected           (int_cdm_ras_des_force_rxdetected),
  .int_smlh_margin_status_valid               (int_smlh_margin_status_valid),
  .int_smlh_margin_status                     (int_smlh_margin_status),
  .int_rmlh_deskew_ctlskp_err                 (int_rmlh_deskew_ctlskp_err),
  .int_rmlh_lane_err                          (int_rmlh_lane_err),
  .int_smlh_lec_pset_ltx                      (int_smlh_lec_pset_ltx),
  .int_smlh_lec_pset_lrx                      (int_smlh_lec_pset_lrx),
  .int_smlh_lec_g4_pset_ltx                   (int_smlh_lec_g4_pset_ltx),
  .int_smlh_lec_g5_pset_ltx                   (int_smlh_lec_g5_pset_ltx),
  .int_smlh_lec_g6_pset_ltx                   (int_smlh_lec_g6_pset_ltx),
  .orig_pipe_rxdata                           (orig_pipe_rxdata),
  .orig_pipe_rxdatak                          (orig_pipe_rxdatak),
  .orig_pipe_rxvalid                          (orig_pipe_rxvalid),
  .orig_pipe_rxdatavalid                      (orig_pipe_rxdatavalid),
  .orig_pipe_rxstatus                         (orig_pipe_rxstatus),
  .orig_pipe_rxstartblock                     (orig_pipe_rxstartblock),
  .orig_pipe_rxsyncheader                     (orig_pipe_rxsyncheader),
  .phy_mac_phystatus_int                      (phy_mac_phystatus_int),
  .smlh_link_in_training                      (smlh_link_in_training),
  .rmlh_prbs_done                             (rmlh_prbs_done),
  .rmlh_prbs_fail                             (rmlh_prbs_fail),
  .rmlh_prbs_started                          (rmlh_prbs_started),
  .rmlh_prbs_err_cntr                         (rmlh_prbs_err_cntr),
  .rmlh_prbs_unexp_fail                       (rmlh_prbs_unexp_fail),
  .cfg_prbs_en                                (cfg_prbs_en),
  .clear_prbs_done                            (clear_prbs_done),
  .cfg_prbs_lane_sel                          (cfg_prbs_lane_sel)
); // u_cx_phy_logical


// Pipeline register on SPIF interface to the Packet Layer or ARB/MUX
spif_pipeline_reg
 u_sdlh_pipeline_reg (
    .b_spif_mp             ( b_sdlh_splh_spif.master_mp  )
    ,.b_spif_sp            ( b_sdlh_vlsm_spif.slave_mp   )  // For CXL connect SDLH to VSLM via SPIF interface
); // u_spif_pipeline_reg


rbuf_struct retrymux_if;

// Retry Buffer Interface MUX
retrymux
 u_rbuf_mux (
  .core_clk             (core_clk),
  .core_rst_n           (core_rst_n),
  // ----------------------------------------------------------------------------
  // Inputs from the Retry RAM
  // ----------------------------------------------------------------------------
  .retryram_data        (retryram_xdlh_data),
  .retryram_depth       (retryram_xdlh_depth),
  .retryram_parerr      (retryram_xdlh_parerr),
  // ----------------------------------------------------------------------------
  // Outputs to the Retry RAM
  // ----------------------------------------------------------------------------
  .retrymux_if          (retrymux_if),
  // ----------------------------------------------------------------------------
  // XDLH Interface
  // ----------------------------------------------------------------------------
  .xdlh_retry_if        (xdlh_retryram_if),
  .retrymux_xdlh_data   (retrymux_xdlh_data),
  .retrymux_xdlh_depth  (retrymux_xdlh_depth),  // unused
  .retrymux_xdlh_parerr (retrymux_xdlh_parerr), // unused
  // ----------------------------------------------------------------------------
  // XPLH Interface
  // ----------------------------------------------------------------------------
  .xplh_retry_if        (xplh_retry_ram_if),
  .retrymux_xplh_data   (retrymux_xplh_data),
  // ----------------------------------------------------------------------------
  // Command Interface
  // ----------------------------------------------------------------------------
  .xplh_xdlh_cmd        (xplh_xdlh_cmd)
); // u_rbuf_mux

assign xdlh_retryram_raddr  = retrymux_if.retryram_raddr;
assign xdlh_retryram_waddr  = retrymux_if.retryram_waddr;
assign xdlh_retryram_data   = retrymux_if.retryram_data;
assign xdlh_retryram_we     = retrymux_if.retryram_we;
assign xdlh_retryram_en     = retrymux_if.retryram_en;

//------------------------------------------------------------------
logic                xdlh_update_fc_sent_s;
logic                ack_sent_s;
logic                nak_sent_s;
logic [`CX_RX_NDLLP-1:0] rcvd_nack_perdllp_s;
logic                rplh_nack_flit;
logic [11:0]         rdlh_xplh_curnt_rx_ack_seqnum_s;
logic [11:0]         xdlh_xplh_curnt_seqnum_s;
logic [1:0]          cx_pl_ras_des_einj1_exp_sequm_evt;
logic                cx_pl_ras_des_einj1_ack_nak_sequm_evt;

logic                cx_pl_xdlh_ras_des_einj2_enable;
logic [1:0]          cx_pl_xdlh_ras_des_einj2_dllp_type;
logic                cx_pl_xdlh_ras_des_einj1_enable;               
logic                cx_pl_xdlh_ras_des_einj1_seq_type;             
logic [12:0]         cx_pl_xdlh_ras_des_einj1_bad_seq;              
logic [7:0]          cx_pl_xdlh_ras_des_einj1_count; 
logic                cx_pl_xplh_ras_des_einj2_enable;
logic [1:0]          cx_pl_xplh_ras_des_einj2_dllp_type;
logic                cx_pl_xplh_ras_des_einj1_enable;               
logic                cx_pl_xplh_ras_des_einj1_seq_type;             
logic [12:0]         cx_pl_xplh_ras_des_einj1_bad_seq;              
logic [7:0]          cx_pl_xplh_ras_des_einj1_count;    
logic                xdlh_xplh_replay_timeout_s;
logic                xdlh_xplh_replay_num_rlover_err_s;
logic                retry_flit_s;
logic                xtlh_xdlh_flit_sof;

// Flit Mode MUX
cx_pl_fm_mux
 u_cx_pl_fm_mux(
  .core_clk                     (core_clk),
  .core_rst_n                   (core_rst_n),
  .xdlh_pm_pme_to_ack           (int_xdlh_xmt_pme_ack),
  .xtlh_pm_pme_to_ack           (xtlh_pm_pme_to_ack),
  .xtlh_sof                     (xtlh_xdlh_flit_sof),
  .xmlh_xplh_cmd                (xmlh_xplh_cmd),
  .cx_pl_pm_pme_to_ack          (xdlh_xmt_pme_ack),
 .xdlh_update_fc_fm             (int_upd_fc_sent),
 .xdlh_replay_timeout           (xdlh_replay_timeout_err),                
 .xdlh_replay_num_rlover_err    (xdlh_replay_num_rlover_err),
 .xdlh_retry_req                (xdlh_retry_req),
 .xdlh_update_fc_nfm            (int_xdlh_update_fc_sent),
 .xdlh_nak_sent                 (int_xdlh_nak_sent),
 .xdlh_ack_sent                 (int_xdlh_ack_sent), 
 .rdlh_nak                      (rdlh_rcvd_nack_perdllp),
 .rdlh_curnt_rx_ack_seqnum      (rdlh_curnt_rx_ack_seqnum),
 .xdlh_curnt_seqnum             (xdlh_curnt_seqnum),

 .cdm_ras_des_einj1_enable      (cdm_ras_des_einj1_enable),                    
 .cdm_ras_des_einj1_seq_type    (cdm_ras_des_einj1_seq_type),                 
 .cdm_ras_des_einj1_bad_seq     (cdm_ras_des_einj1_bad_seq),                 
 .cdm_ras_des_einj1_count       (cdm_ras_des_einj1_count),                    
 .cdm_ras_des_einj2_enable      (cdm_ras_des_einj2_enable),                    
 .cdm_ras_des_einj2_dllp_type   (cdm_ras_des_einj2_dllp_type),                                     

 .xplh_ras_des_einj1_exp_sequm_evt    (xplh_ras_des_einj1_exp_sequm_evt),
 .xplh_ras_des_einj1_ack_nak_sequm_evt(xplh_ras_des_einj1_ack_nak_sequm_evt),
 .xdlh_ras_des_einj1_ack_nak_sequm_evt(xdlh_ras_des_einj1_ack_nak_sequm_evt),
 .xdlh_ras_des_einj1_exp_sequm_evt    (xdlh_ras_des_einj1_exp_sequm_evt),

 .cx_pl_xdlh_ras_des_einj1_enable     (cx_pl_xdlh_ras_des_einj1_enable),                
 .cx_pl_xdlh_ras_des_einj1_seq_type   (cx_pl_xdlh_ras_des_einj1_seq_type),             
 .cx_pl_xdlh_ras_des_einj1_bad_seq    (cx_pl_xdlh_ras_des_einj1_bad_seq),              
 .cx_pl_xdlh_ras_des_einj1_count      (cx_pl_xdlh_ras_des_einj1_count),                 
 .cx_pl_xdlh_ras_des_einj2_enable     (cx_pl_xdlh_ras_des_einj2_enable),                
 .cx_pl_xdlh_ras_des_einj2_dllp_type  (cx_pl_xdlh_ras_des_einj2_dllp_type),                           

 .cx_pl_xplh_ras_des_einj1_enable     (cx_pl_xplh_ras_des_einj1_enable),             
 .cx_pl_xplh_ras_des_einj1_seq_type   (cx_pl_xplh_ras_des_einj1_seq_type),          
 .cx_pl_xplh_ras_des_einj1_bad_seq    (cx_pl_xplh_ras_des_einj1_bad_seq),            
 .cx_pl_xplh_ras_des_einj1_count      (cx_pl_xplh_ras_des_einj1_count),              
 .cx_pl_xplh_ras_des_einj2_enable     (cx_pl_xplh_ras_des_einj2_enable),            
 .cx_pl_xplh_ras_des_einj2_dllp_type  (cx_pl_xplh_ras_des_einj2_dllp_type),  

 .ras_des_einj1_exp_sequm_evt         (cx_pl_ras_des_einj1_exp_sequm_evt), 
 .ras_des_einj1_ack_nak_sequm_evt     (cx_pl_ras_des_einj1_ack_nak_sequm_evt),
 .xplh_rasdes                   (xplh_rasdes_fm),
 .rplh_xplh_fm_retry            (rplh_xplh_fm_retry),
 .xplh_rx_ack_seqnum            (xplh_rx_ack_seqnum),
 .xplh_tx_seqnum_value          (xplh_tx_seqnum_value),
  
 //---------------------------------------------------------
 //  Outputs
 //----------------------------------------------------------
 .cx_pl_rasdes_update_fc                  (xdlh_update_fc_sent_s),
 .cx_pl_rasdes_sent_ack                   (ack_sent_s),
 .cx_pl_rasdes_sent_nak                   (nak_sent_s),
 .cx_pl_rasdes_rdlh_rplh_nak              (rcvd_nack_perdllp_s),
 .cx_pl_rasdes_rplh_nack_flit             (rplh_nack_flit),
 .cx_pl_rasdes_rx_ack_seqnum              (rdlh_xplh_curnt_rx_ack_seqnum_s),
 .cx_pl_rasdes_tx_seqnum                  (xdlh_xplh_curnt_seqnum_s),
 .cx_pl_rasdes_replay_timeout             (xdlh_xplh_replay_timeout_s),           
 .cx_pl_rasdes_replay_num_rlover_err      (xdlh_xplh_replay_num_rlover_err_s),    
 .cx_pl_rasdes_retry_flit                 (retry_flit_s)
 ,.cx_pl_ptm_retry_flit                   (xplh_ptm_retry_flit)
); // u_cx_pl_fm_mux

assign xdlh_update_fc_sent             = xdlh_update_fc_sent_s;
assign ack_sent                        = ack_sent_s;
assign nak_sent                        = nak_sent_s;
assign rcvd_nack_perdllp               = rcvd_nack_perdllp_s;
assign rdlh_xplh_curnt_rx_ack_seqnum   = rdlh_xplh_curnt_rx_ack_seqnum_s;
assign xdlh_xplh_curnt_seqnum          = xdlh_xplh_curnt_seqnum_s; 
assign xdlh_xplh_replay_timeout        = xdlh_xplh_replay_timeout_s;
assign xdlh_xplh_replay_num_rlover_err = xdlh_xplh_replay_num_rlover_err_s;
assign retry_flit                      = retry_flit_s;

assign ras_des_einj1_exp_sequm_evt     = cx_pl_ras_des_einj1_exp_sequm_evt;
assign ras_des_einj1_ack_nak_sequm_evt = cx_pl_ras_des_einj1_ack_nak_sequm_evt; 
assign xdlh_ras_des_einj2_enable       = cx_pl_xdlh_ras_des_einj2_enable;
assign xdlh_ras_des_einj2_dllp_type    = cx_pl_xdlh_ras_des_einj2_dllp_type;
assign xdlh_ras_des_einj1_enable       = cx_pl_xdlh_ras_des_einj1_enable;               
assign xdlh_ras_des_einj1_seq_type     = cx_pl_xdlh_ras_des_einj1_seq_type;             
assign xdlh_ras_des_einj1_bad_seq      = cx_pl_xdlh_ras_des_einj1_bad_seq;              
assign xdlh_ras_des_einj1_count        = cx_pl_xdlh_ras_des_einj1_count; 
assign xplh_ras_des_einj2_enable       = cx_pl_xplh_ras_des_einj2_enable;
assign xplh_ras_des_einj2_dllp_type    = cx_pl_xplh_ras_des_einj2_dllp_type;
assign xplh_ras_des_einj1_enable       = cx_pl_xplh_ras_des_einj1_enable;               
assign xplh_ras_des_einj1_seq_type     = cx_pl_xplh_ras_des_einj1_seq_type;             
assign xplh_ras_des_einj1_bad_seq      = cx_pl_xplh_ras_des_einj1_bad_seq;              
assign xplh_ras_des_einj1_count        = cx_pl_xplh_ras_des_einj1_count; 


// PM Controller interface with Link Layer(s)
logic  int_pcie_state_active;
assign int_pcie_state_active = (b_sdlh_splh_spif.s_pl_state_sts inside {ACTIVE, ACTIVE_L0S_PMNAK}) && !b_sdlh_splh_spif.s_pl_phyinretrain;

assign pl_pcie_wake_ack      = b_sdlh_splh_spif.s_pl_wake_ack;
assign pl_pcie_clk_req       = b_sdlh_splh_spif.s_pl_clk_req;
assign pl_pcie_phyinl1       = b_sdlh_splh_spif.s_pl_phyinl1;
assign pl_pcie_phyinl2       = b_sdlh_splh_spif.s_pl_phyinl2;
assign pl_pcie_state_l1      = sdlh_protocol_cfg.spif_enable ? (b_sdlh_splh_spif.s_pl_state_sts == IDLE_L1_1) : pm_link_to_protocol_signals.pm_linkst_in_l1;
assign pl_pcie_state_l2      = sdlh_protocol_cfg.spif_enable ? (b_sdlh_splh_spif.s_pl_state_sts == L2       ) : pm_link_to_protocol_signals.pm_linkst_in_l2;
assign pl_pcie_state_active  = sdlh_protocol_cfg.spif_enable ? int_pcie_state_active                          : (smlh_ltssm_state inside {S_L0, S_L0S});
assign pl_pcie_link_up       = sdlh_protocol_cfg.spif_enable ? b_sdlh_splh_spif.s_pl_link_up                  : smlh_link_up;
assign pl_cxl_wake_ack       = b_cxl_vlsm_spif.s_pl_wake_ack;
assign pl_cxl_clk_req        = b_cxl_vlsm_spif.s_pl_clk_req;
assign pl_cxl_phyinl1        = b_cxl_vlsm_spif.s_pl_phyinl1;
assign pl_cxl_phyinl2        = b_cxl_vlsm_spif.s_pl_phyinl2;
assign pl_cxl_state_l1       = (b_cxl_vlsm_spif.s_pl_state_sts == IDLE_L1_1);
assign pl_cxl_state_l2       = (b_cxl_vlsm_spif.s_pl_state_sts == L2       );
assign pl_cxl_mode_enable    = splh_protocol_cfg.cxl_mode_enable;

// Pipeline register on SPIF interface to the ARB/MUX
spif_pipeline_reg
 u_cxl_pipeline_reg (
    .b_spif_mp             ( b_cxl_vlsm_spif             )
    ,.b_spif_sp            ( b_vlsm_cxl_spif.slave_mp    )
);

// Pipeline register on SPIF interface to the ARB/MUX
spif_pipeline_reg
 u_vlsm_pipeline_reg (
    .b_spif_mp             ( b_vlsm_splh_spif.master_mp  )
    ,.b_spif_sp            ( b_splh_vlsm_spif.slave_mp   )
);

// --------------------------------------------------------------------------------------
// CXL VLSM Instantiation
// --------------------------------------------------------------------------------------
assign vlsm_mc_state         = b_vlsm_cxl_spif.s_pl_state_sts;
assign vlsm_io_state         = b_sdlh_vlsm_spif.s_pl_state_sts;

cx_arbmux
 u_cx_arbmux (
    .b_vlsm_llctrl_mc              ( b_vlsm_cxl_spif.master_mp              ),
    .b_vlsm_llctrl_io              ( b_sdlh_vlsm_spif.master_mp             ),
    .b_vlsm_splh_spif              ( b_vlsm_splh_spif.slave_mp              ),
    .core_clk                      ( core_clk                               ),
    .core_rst_n                    ( core_rst_n                             ),
    // Configuration Interface
    .cfg_pm_timeout_enable         ( cfg_pm_timeout_enable                  ),
    .cfg_pm_timeout_value          ( cfg_pm_timeout_value                   ),
    .cfg_pm_timeout_error          ( cfg_pm_timeout_error                   ),
    .cfg_vlsm_force_active         ( cfg_vlsm_force_active                  ),
    .cfg_vlsm_pm_enable            ( cfg_vlsm_pm_enable                     ),
    .cfg_cxl_io_arb_weight         ( cfg_cxl_io_arb_weight                  ),
    .cfg_cxl_mc_arb_weight         ( cfg_cxl_mc_arb_weight                  ),
    // Power Management Application Interface
    .vlsm_io_tx_pm_nak             ( vlsm_io_tx_pm_nak                      ),
    .vlsm_mc_tx_pm_nak             ( vlsm_mc_tx_pm_nak                      ),
    .vlsm_io_rx_pm_nak             ( vlsm_io_rx_pm_nak                      ),
    .vlsm_mc_rx_pm_nak             ( vlsm_mc_rx_pm_nak                      ),
    .vlsm_io_rx_pm_req             ( vlsm_io_rx_pm_req                      ),
    .vlsm_mc_rx_pm_req             ( vlsm_mc_rx_pm_req                      ),
    .vlsm_io_pm_timeout            ( vlsm_io_pm_timeout                     ),
    .vlsm_mc_pm_timeout            ( vlsm_mc_pm_timeout                     ),
    .ras_dp_err_inj                ( ras_dp_err_inj                         ),
    .vlsm_rasdp_err_log            ( vlsm_ras_dp_err_log                    ),
    .vlsm_ltssm_enable             ( vlsm_ltssm_enable                      ),
    .vlsm_debug_info               ( vlsm_debug_info                        )
); // u_cx_arbmux


// ----------------------------------------------------------------------------
// PCIe/CXL.io Link Layer instantiation
// ----------------------------------------------------------------------------
cx_lp

#(INST) u_cx_lp (
// ----------------------------------------------------------------------------
// Interfaces
// ----------------------------------------------------------------------------
    .b_sdlh_splh_spif                   ( b_sdlh_splh_spif.slave_mp            ), // For PCIe connect CX_LP to CX_PL via SPIF interface
    .b_cfgi_lbc                         ( b_cfgi_lbc                           ),
    .b_xdlh_xplh                        ( b_xdlh_xplh.master_mp                ),
// ----------------------------------------------------------------------------
// Clock and Reset
// ----------------------------------------------------------------------------
    .core_clk                           ( core_clk                             ),
    .core_rst_n                         ( core_rst_n                           ),
// ----------------------------------------------------------------------------
// Top-Level Interface
// ----------------------------------------------------------------------------
    .device_type                        ( device_type                          ),
    .pm_rstctl_core_flush_req           ( pm_rstctl_core_flush_req             ),
    .rstctl_core_flush_req              ( rstctl_core_flush_req                ),
// ----------------------------------------------------------------------------
// Configuration Interface
// ----------------------------------------------------------------------------
    .cfg_tx_arb_control                 ( cfg_tx_arb_control                   ),
    .cfg_endpoint                       ( cfg_endpoint                         ),
    .cfg_upstream_port                  ( cfg_upstream_port                    ),
    .cfg_root_compx                     ( cfg_root_compx                       ),
    .cfg_dll_lnk_en                     ( cfg_dll_lnk_en                       ),
    .cfg_ack_freq                       ( cfg_ack_freq                         ),
    .cfg_ack_latency_timer              ( cfg_ack_latency_timer                ),
    .cfg_replay_timer_value             ( cfg_replay_timer_value               ),
    .cfg_fc_latency_value               ( cfg_fc_latency_value                 ),
    .cfg_other_msg_payload              ( cfg_other_msg_payload                ),
    .cfg_other_msg_request              ( cfg_other_msg_request                ),
    .cfg_corrupt_crc_pattern            ( cfg_corrupt_crc_pattern              ),
    .cfg_flow_control_disable           ( cfg_flow_control_disable             ),
    .cfg_acknack_disable                ( cfg_acknack_disable                  ),
    .cfg_ext_synch                      ( cfg_ext_synch                        ),
    .cfg_max_payload                    ( cfg_max_payload                      ),
    .cfg_max_payload_rx                 ( cfg_max_payload_rx                   ),
    .cfg_tc_enable                      ( cfg_tc_enable                        ),
    .cfg_vc_enable                      ( cfg_vc_enable                        ),
    .cfg_vc_struc_vc_id_map             ( cfg_vc_struc_vc_id_map               ),
    .cfg_vc_id_vc_struc_map             ( cfg_vc_id_vc_struc_map               ),
    .cfg_tc_struc_vc_map                ( cfg_tc_struc_vc_map                  ),
    .cfg_fc_wdog_disable                ( cfg_fc_wdog_disable                  ),
    .cfg_fc_credit_ph                   ( cfg_fc_credit_ph                     ),
    .cfg_fc_credit_nph                  ( cfg_fc_credit_nph                    ),
    .cfg_fc_credit_cplh                 ( cfg_fc_credit_cplh                   ),
    .cfg_fc_credit_pd                   ( cfg_fc_credit_pd                     ),
    .cfg_fc_credit_npd                  ( cfg_fc_credit_npd                    ),
    .cfg_fc_credit_cpld                 ( cfg_fc_credit_cpld                   ),
    .dl_feature_en                      ( dl_feature_en                        ),
    .cfg_remote_feature_ack             ( cfg_remote_feature_ack               ),
    .cfg_local_feature_support          ( cfg_local_feature_support            ),
    .cfg_dlink_feature_valid            ( cfg_dlink_feature_valid              ),
    .fc_scaled_en                       ( fc_scaled_en                         ),
    .hdr_scale_p                        ( hdr_scale_p                          ),
    .hdr_scale_np                       ( hdr_scale_np                         ),
    .hdr_scale_cpl                      ( hdr_scale_cpl                        ),
    .data_scale_p                       ( data_scale_p                         ),
    .data_scale_np                      ( data_scale_np                        ),
    .data_scale_cpl                     ( data_scale_cpl                       ),
    .cfg_max_end2end_tlp_prfxs          ( cfg_max_end2end_tlp_prfxs            ),
    .dpc_fatal_err_gate                 ( dpc_fatal_err_gate                   ),
    .dpc_nonfatal_err_gate              ( dpc_nonfatal_err_gate                ),
    .cfg_p2p_track_cpl_to               ( cfg_p2p_track_cpl_to                 ),
    .cfg_l0p_enable                     ( cfg_l0p_enable                       ),
    .cfg_l0p_autowidth_dis              ( cfg_l0p_autowidth_dis                ),
    .cfg_l0p_priority                   ( cfg_l0p_priority                     ),
    .cfg_l0p_linkmode                   ( cfg_l0p_linkmode                     ),
    .cfg_l0p_linkmode_req               ( cfg_l0p_linkmode_req                 ),
    .cfg_l0p_max_link_width             ( cfg_l0p_max_link_width               ),
    .cfg_l0p_neg_link_width             ( cfg_l0p_neg_link_width               ),
    .cfg_pcie_l0p_disable               ( cfg_pcie_l0p_disable                 ),
    .cfg_pcie_l0p_request               ( cfg_pcie_l0p_request                 ),
    .cfg_pcie_l0p_priority              ( cfg_pcie_l0p_priority                ),
    .cfg_pcie_l0p_linkmode              ( cfg_pcie_l0p_linkmode                ),
    .app_dynamic_l0p_enable             ( app_dynamic_l0p_enable               ),
    .app_dynamic_l0p_rejected           ( app_dynamic_l0p_rejected             ),
    .cdm_err_inj_en                     ( cdm_plh_flit_err_inj_interface.cfg_flit_err_inj_en     ),
    .cdm_tx_err_inj_en                  ( cdm_plh_flit_err_inj_interface.cfg_inj_err_tx_flit_ind ),
// ----------------------------------------------------------------------------
// RAS-DES Interface (Inputs)
// ----------------------------------------------------------------------------
    .cdm_ras_des_force_linkdown_noack   ( cdm_ras_des_force_linkdown_noack     ),
    .cdm_ras_des_einj0_enable           ( cdm_ras_des_einj0_enable             ),
    .cdm_ras_des_einj0_crc_type         ( cdm_ras_des_einj0_crc_type           ),
    .cdm_ras_des_einj0_count            ( cdm_ras_des_einj0_count              ),
    .cdm_ras_des_einj1_enable           ( xdlh_ras_des_einj1_enable            ),
    .cdm_ras_des_einj1_seq_type         ( xdlh_ras_des_einj1_seq_type          ),
    .cdm_ras_des_einj1_bad_seq          ( xdlh_ras_des_einj1_bad_seq           ),
    .cdm_ras_des_einj1_count            ( xdlh_ras_des_einj1_count             ),
    .cdm_ras_des_einj2_enable           ( xdlh_ras_des_einj2_enable            ),
    .cdm_ras_des_einj2_dllp_type        ( xdlh_ras_des_einj2_dllp_type         ),
    .cdm_ras_des_einj4_enable           ( cdm_ras_des_einj4_enable             ),
    .cdm_ras_des_einj4_updfc_type       ( cdm_ras_des_einj4_updfc_type         ),
    .cdm_ras_des_einj4_vcnum            ( cdm_ras_des_einj4_vcnum              ),
    .cdm_ras_des_einj4_badfc_value      ( cdm_ras_des_einj4_badfc_value        ),
    .cdm_ras_des_einj5_enable           ( cdm_ras_des_einj5_enable             ),
    .cdm_ras_des_einj5_count            ( cdm_ras_des_einj5_count              ),
    .cdm_ras_des_einj5_tlp_type         ( cdm_ras_des_einj5_tlp_type           ),
// ----------------------------------------------------------------------------
// RAS Interface
// ----------------------------------------------------------------------------
    .cfg_rasdp_linkdown_en              ( cfg_rasdp_linkdown_en                ),
    .cfg_rasdp_error_mode_en            ( cfg_rasdp_error_mode_en              ),
    .cfg_rasdp_error_mode               ( cfg_rasdp_error_mode                 ),
    .ras_prot_t_disable                 ( ras_prot_t_disable                   ),
    .ras_prot_r_disable                 ( ras_prot_r_disable                   ),
    .ras_err_inj_en_array               ( ras_err_inj_en_array                 ),
    .ras_err_inj_mask                   ( ras_err_inj_mask                     ),
    .ras_dp_err_inj                     ( ras_dp_err_inj                       ),
// ----------------------------------------------------------------------------
// CRC Error Injection Interface (Inputs)
// ----------------------------------------------------------------------------
    .lcrc_err_en                        ( lcrc_err_en_int                      ),
    .ecrc_err_en                        ( ecrc_err_en_int                      ),
// ----------------------------------------------------------------------------
// PM Controller Interface
// ----------------------------------------------------------------------------
    .pm_cfg_retrain_req                 ( cfg_link_retrain                     ),
    .pm_app_init_rst                    ( app_init_rst                         ),
    .sdlh_protocol_cfg                  ( sdlh_protocol_cfg                    ),
    .pcie_link_adm_if                   ( pcie_link_adm_if                     ),
    .pm_xdlh_dllp_req                   ( pm_xdlh_dllp_req                     ),
    .pm_xtlh_block_tlp                  ( pm_xtlh_block_tlp                    ),
    .pm_xmlh_lp_req                     ( pm_xmlh_lp_req                       ),
    .xdlh_not_expecting_ack             ( xdlh_not_expecting_ack               ),
    .xdlh_nodllp_pending                ( xdlh_nodllp_pending                  ),
    .xdlh_no_acknak_dllp_pending        ( int_no_acknak_dllp_pending           ),
    .xdlh_no_acknak_dllp_pending_s      ( xdlh_no_acknak_dllp_pending          ),
    .xdlh_xmt_pme_ack                   ( int_xdlh_xmt_pme_ack                 ),
    .xtlh_pm_pme_to_ack                 ( xtlh_pm_pme_to_ack                   ),
// ----------------------------------------------------------------------------
// RX Application Layer Interface (to/from RADM)
// ----------------------------------------------------------------------------
    .radm_rtlh_ph_ca                    ( radm_rtlh_ph_ca                      ),
    .radm_rtlh_pd_ca                    ( radm_rtlh_pd_ca                      ),
    .radm_rtlh_nph_ca                   ( radm_rtlh_nph_ca                     ),
    .radm_rtlh_npd_ca                   ( radm_rtlh_npd_ca                     ),
    .radm_rtlh_cplh_ca                  ( radm_rtlh_cplh_ca                    ),
    .radm_rtlh_cpld_ca                  ( radm_rtlh_cpld_ca                    ),
    .rtlh_radm                          ( rtlh_radm                            ),
// ----------------------------------------------------------------------------
// TX Application Layer Interface (to/from XADM)
// ----------------------------------------------------------------------------
    .xadm_all_type_infinite             ( xadm_all_type_infinite               ),
    .xadm_xtlh_pkt                      ( xadm_xtlh_pkt                        ),
    .xtlh_xadm_pkt_halt                 ( xtlh_xadm_pkt_halt                   ),
    .xtlh_xadm_posted_tlp_sent          ( xtlh_xadm_posted_tlp_sent            ),

// ----------------------------------------------------------------------------
// Native Link Layer to Packet Layer Interface (to be removed after SPIF adoption)
// ----------------------------------------------------------------------------
    .pm_prot_req_l2                     ( pm_prot_req_l2                       ),
    .pm_block_tlp_ack                   ( pm_block_tlp_ack                     ),
    .smlh_flit_mode_enable              ( smlh_flit_mode_enable                ),
    .smlh_flit_mode_enable_modules      ( smlh_flit_mode_enable_modules        ),
    .smlh_link_mode                     ( smlh_link_mode                       ),
    .smlh_link_rxmode                   ( smlh_link_rxmode                     ),
    .smlh_link_up                       ( smlh_link_up                         ),
    .smlh_in_l0                         ( smlh_in_l0                           ),
    .smlh_in_l0s                        ( smlh_in_l0s                          ),
    .smlh_in_rl0s                       ( smlh_in_rl0s                         ),
    .smlh_in_l1                         ( smlh_in_l1                           ),
    .smlh_link_in_training              ( smlh_link_in_training                ),
    .smlh_in_l23                        ( smlh_in_l23                          ),
    .smlh_l123_eidle_timeout            ( smlh_l123_eidle_timeout              ),
    .latched_rcvd_eidle_set             ( latched_rcvd_eidle_set               ),
    .smlh_eq_pending                    ( smlh_eq_pending                      ),
    .smlh_usp_eq_pending                ( smlh_usp_eq_pending                  ),
    .smlh_l0p_capable                   ( smlh_l0p_capable                     ),
    .smlh_l0p_link_mode                 ( smlh_l0p_link_mode                   ),
    .smlh_ltssm_l0p_ready               ( smlh_ltssm_l0p_ready                 ),
    .smlh_xdlh_eios_rcvd                ( smlh_xdlh_eios_rcvd                  ),
    .xdlh_smlh_link_req                 ( xdlh_smlh_link_req                   ),
    .xdlh_smlh_link_width               ( xdlh_smlh_link_width                 ),
    .xdlh_smlh_link_initiated           ( xdlh_smlh_link_initiated             ),
    .xdlh_smlh_enter_recovery           ( xdlh_smlh_enter_recovery             ),
    .pm_current_data_rate_others        ( pm_current_data_rate_others          ),
    .xmlh_xplh_halt                     ( xplh_sideband.halt_in                  ),
    .xplh_xmlh_eot                      ( xplh_sideband.eot[NW_NFM-1:0]          ),
    .xdlh_smlh_start_link_retrain       ( int_xdlh_smlh_start_link_retrain       ),
    .rtlh_req_link_retrain              ( rtlh_req_link_retrain                ),
    .rplh_rdlh_dllp_start               ( rplh_rdlh_dllp_start                 ),
    .rplh_rdlh_tlp_start                ( rplh_rdlh_tlp_start                  ),
    .rplh_rdlh_pkt_end                  ( rplh_rdlh_pkt_end                    ),
    .rplh_rdlh_pkt_edb                  ( rplh_rdlh_pkt_edb                    ),
    .rplh_rdlh_pkt_data                 ( rplh_rdlh_pkt_data                   ),
    .rplh_rdlh_pkt_dv                   ( rplh_rdlh_pkt_dv                     ),
    .rplh_rdlh_pkt_err                  ( rplh_rdlh_pkt_err                    ),
    .rplh_rdlh_nak                      ( rplh_rdlh_nak                        ),
    .rplh_rdlh_tlp_idl                  ( rplh_rdlh_tlp_idl                    ),
    .rplh_rdlh_tlp_pfx                  ( rplh_rdlh_tlp_pfx                    ),
    .rplh_rdlh_fm_nullified             ( rplh_rdlh_fm_nullified               ),
    .rplh_rdlh_fm_poisoned              ( rplh_rdlh_fm_poisoned                ),
    .rplh_rdlh_fm_dllp_data             ( rplh_rdlh_fm_dllp_data               ),
    .rplh_rdlh_fm_dllp_valid            ( rplh_rdlh_fm_dllp_valid              ),
    .rplh_rdlh_fm_dllp_opt_fc_up        ( rplh_rdlh_fm_dllp_opt_fc_up          ),
    .rplh_ptm_sot                       ( rplh_ptm_sot                         ),
    .rplh_ptm_request                   ( rplh_ptm_request                     ),
    .rplh_ptm_response                  ( rplh_ptm_response                    ),
    .rplh_ptm_duplicate                 ( rplh_ptm_duplicate                   ),
    .xplh_ptm_sot                       ( xplh_ptm_sot                         ),
    .xplh_ptm_request                   ( xplh_ptm_request                     ),
    .xplh_ptm_response                  ( xplh_ptm_response                    ),
    .xplh_ptm_retry_flit                ( xplh_ptm_retry_flit                  ),
    .xmtbyte_stp_start                  ( xmtbyte_stp_start                    ),
    .xplh_ras_des_einj2_enable          ( xplh_ras_des_einj2_enable            ),
    .xplh_ras_des_einj2_dllp_type       ( xplh_ras_des_einj2_dllp_type         ),
    .xplh_xdlh_cmd                      ( xplh_xdlh_cmd                        ),
    .xdlh_xplh_cmd_ack                  ( xdlh_xplh_cmd_ack                    ),
    .xplh_flit_count                    ( xplh_flit_count                      ),
    .xplh_flit_count_en                 ( xplh_flit_count_en                   ),
    .xplh_xdlh_dllp_halt                ( xplh_xdlh_dllp_halt                  ),
    .xdlh_xplh_dllp_out                 ( xdlh_xplh_dllp_out                   ),
    .xdlh_update_fc_fm                  ( int_upd_fc_sent                      ),
    .xtlh_xdlh_fm_sof                   ( xtlh_xdlh_flit_sof                   ),
    .xplh_pm_dllp_ack                   ( xplh_pm_dllp_ack                     ),
    .pm_wake_req_exit_l0s               ( pm_wake_req_exit_l0s                 ),
    .xadm_tlp_pending                   ( xadm_tlp_pending                     ),
    .xaim_tlp_pending                   ( xaim_tlp_pending                     ),
    .xplh_pending                       ( xplh_pending                         ),
    .msg_gen_asnak_grt                  ( msg_gen_asnak_grt                    ),
    .pm_l2_entry_flag                   ( pm_l2_entry_flag                     ),
    .l0s_entr_latency_timer             ( l0s_entr_latency_timer               ),
    .l1_entr_latency_timer              ( l1_entr_latency_timer                ),
    .pm_l1_entr_wo_rl0s                 ( pm_l1_entr_wo_rl0s                   ),
    .pm_aspm_l1_timer_enable            ( pm_aspm_l1_timer_enable              ),
    .xtlh_had_enough_credit             ( xtlh_had_enough_credit               ),
    .xadm_no_fc_credit                  ( xadm_no_fc_credit                    ),
    .radm_pm_asnak                      ( radm_pm_asnak                        ),
    .app_req_entr_l1                    ( app_req_entr_l1                      ),
    .radm_trgt0_pending                 ( radm_trgt0_pending                   ),
    .lbc_active                         ( lbc_active                           ),
    .pm_wake_any_if_pending             ( pm_wake_any_if_pending               ),
    .app_xfer_pending                   ( app_xfer_pending                     ),
    .cfg_dsp_pcipm_l1_enter_delay       ( cfg_dsp_pcipm_l1_enter_delay         ),
    .xmlh_cmd_if_lp_ack                 ( xmlh_cmd_if_lp_ack                   ),
    .software_entr_l1                   ( software_entr_l1                     ),
    .software_entr_l23                  ( software_entr_l23                    ),
    .pm_aspm_l0s_en                     ( pm_aspm_l0s_en                       ),
    .pm_aspm_l1_en                      ( pm_aspm_l1_en                        ),
    .lp_pcie_l1_exit                    ( lp_pcie_l1_exit                      ),
    .lp_pcie_clk_ack                    ( lp_pcie_clk_ack                      ),
    .lp_pcie_wake_req                   ( lp_pcie_wake_req                     ),
    .pm_link_to_protocol_signals        ( pm_link_to_protocol_signals          ),
    .pm_protocol_to_link_signals        ( pm_protocol_to_link_signals          ),
    .pm_xmt_asnak                       ( pm_xmt_asnak                         ),
    .pm_block_all_tlp                   ( pm_block_all_tlp                     ),
    .pm_l1_aspm_entr                    ( pm_l1_aspm_entr                      ),
    .pm_xdlh_enter_l23                  ( pm_xdlh_enter_l23                    ),
    .pm_l1_entry_started                ( pm_l1_entry_started                  ),
    .pm_l1_in_progress                  ( pm_l1_in_progress                    ),
    .pm_aspm_l1_enter_ready             ( pm_aspm_l1_enter_ready               ),
    .pm_usp_prot_state                  ( pm_usp_prot_state                    ),
    .pm_dsp_prot_state                  ( pm_dsp_prot_state                    ),
    .pm_l0s_state                       ( pm_l0s_state                         ),
    .latch_as_entr_l1                   ( latch_as_entr_l1                     ),
    .pm_prot_idle_flag                  ( pm_prot_idle_flag                    ),
    .lp_sdb_l1sub_aspm                  ( lp_sdb_l1sub_aspm                    ),
    .lp_sdb_l1sub_pcipm                 ( lp_sdb_l1sub_pcipm                   ),
    .xdlh_ptm_sot                       ( xdlh_ptm_sot                         ),
    .xdlh_ptm_multi_cycle               ( xdlh_ptm_multi_cycle                 ),
    .xdlh_ptm_request                   ( xdlh_ptm_request                     ),
    .xdlh_ptm_response                  ( xdlh_ptm_response                    ),
    .xdlh_rbuf_replaying                ( xdlh_rbuf_replaying                  ),
    .rdlh_ptm_sot                       ( rdlh_ptm_sot                         ),
    .rdlh_ptm_multi_cycle               ( rdlh_ptm_multi_cycle                 ),
    .rdlh_ptm_request                   ( rdlh_ptm_request                     ),
    .rdlh_ptm_response                  ( rdlh_ptm_response                    ),
    .rdlh_duplicate_tlp                 ( rdlh_duplicate_tlp                   ),
    .rdlh_rtlh_tlp_sot                  (                                      ), // unused
    .rdlh_rcvd_dllp                     ( rdlh_rcvd_dllp                       ),
// ----------------------------------------------------------------------------
// ADM Adaptor/CDM/Top-Level
// ----------------------------------------------------------------------------
    .rtfcgen_ph_diff                    ( rtfcgen_ph_diff                      ),
    .rtlh_overfl_err                    ( rtlh_overfl_err                      ),
    .rtlh_rfc                           ( rtlh_rfc                             ),
    .rtlh_parerr                        (                                      ), // unused
    .rtlh_fc_init_status                ( rtlh_fc_init_status                  ),
    .rtlh_crd_not_rtn                   ( rtlh_crd_not_rtn                     ),
    .rdlh_rcvd_dl_feature               ( rdlh_rcvd_dl_feature                 ),
    .rcvd_dl_feature_content            ( rcvd_dl_feature_content              ),
    .rdlh_bad_tlp_err                   ( rdlh_bad_tlp_err                     ),
    .rdlh_bad_dllp_err                  ( rdlh_bad_dllp_err                    ),
    .rdlh_rtlh_link_state               ( rdlh_rtlh_link_state                 ),
    .rdlh_prot_err                      ( rdlh_prot_err                        ),
    .rdlh_link_up                       ( rdlh_link_up                         ),
    .rdlh_link_down                     ( rdlh_link_down                       ),
    .xdlh_retry_req                     ( xdlh_retry_req                       ),
    .xdlh_replay_timeout_err            ( xdlh_replay_timeout_err              ),
    .xdlh_replay_timer_value            (                                      ), // unused
    .xdlh_retrybuf_not_empty            ( xdlh_retrybuf_not_empty              ),
    .xdlh_rbuf_pkt_cnt                  (                                      ), // unused
    .xtlh_tlp_pending                   ( xtlh_tlp_pending                     ),
    .xtlh_data_parerr                   (                                      ), // unused
    .latched_flit_mode_enable           ( latched_flit_mode_enable             ),
// ----------------------------------------------------------------------------
// RAS-DES Interface (Outputs)
// ----------------------------------------------------------------------------
    .xdlh_nak_sent                      ( int_xdlh_nak_sent                    ),
    .xdlh_ack_sent                      ( int_xdlh_ack_sent                    ),
    .xdlh_update_fc_sent                ( int_xdlh_update_fc_sent              ),
    .xdlh_smlh_goto_detect              ( xdlh_smlh_goto_detect                ),
    .rtlh_rcvd_ufc_perdllp              ( rtlh_rcvd_ufc_perdllp                ),
    .rtlh_rx_memwr_evt                  ( rtlh_rx_memwr_evt                    ),
    .rtlh_rx_defmemwr_evt               ( rtlh_rx_defmemwr_evt                 ),
    .rtlh_rx_memrd_evt                  ( rtlh_rx_memrd_evt                    ),
    .rtlh_rx_cfgwr_evt                  ( rtlh_rx_cfgwr_evt                    ),
    .rtlh_rx_cfgrd_evt                  ( rtlh_rx_cfgrd_evt                    ),
    .rtlh_rx_iowr_evt                   ( rtlh_rx_iowr_evt                     ),
    .rtlh_rx_iord_evt                   ( rtlh_rx_iord_evt                     ),
    .rtlh_rx_cplwod_evt                 ( rtlh_rx_cplwod_evt                   ),
    .rtlh_rx_cplwd_evt                  ( rtlh_rx_cplwd_evt                    ),
    .rtlh_rx_msg_evt                    ( rtlh_rx_msg_evt                      ),
    .rtlh_rx_atmcop_evt                 ( rtlh_rx_atmcop_evt                   ),
    .rtlh_rx_tlpwprefix_evt             ( rtlh_rx_tlpwprefix_evt               ),
    .rtlh_rx_tlp_dpsize                 ( rtlh_rx_tlp_dpsize                   ),
    .rdlh_bad_tlp_err_pertlp            ( rdlh_bad_tlp_err_pertlp              ),
    .rdlh_lcrc_tlp_err_pertlp           ( rdlh_lcrc_tlp_err_pertlp             ),
    .rdlh_nulified_tlp_err_pertlp       ( rdlh_nulified_tlp_err_pertlp         ),
    .rdlh_duplicate_tlp_err_pertlp      ( rdlh_duplicate_tlp_err_pertlp        ),
    .rdlh_bad_dllp_err_perdllp          ( rdlh_bad_dllp_err_perdllp            ),
    .rdlh_rcvd_nack_perdllp             ( rdlh_rcvd_nack_perdllp               ),
    .rdlh_rcvd_ack_perdllp              ( rdlh_rcvd_ack_perdllp                ),
    .rdlh_vc0_initfc1_status            ( rdlh_vc0_initfc1_status              ),
    .rdlh_vc0_initfc2_status            ( rdlh_vc0_initfc2_status              ),
    .rdlh_curnt_rx_ack_seqnum           ( rdlh_curnt_rx_ack_seqnum             ),
    .xdlh_curnt_seqnum                  ( xdlh_curnt_seqnum                    ),
    .rtlh_fc_rcvd_ph                    ( rtlh_fc_rcvd_ph                      ),
    .rtlh_fc_rcvd_pd                    ( rtlh_fc_rcvd_pd                      ),
    .rtlh_fc_rcvd_nph                   ( rtlh_fc_rcvd_nph                     ),
    .rtlh_fc_rcvd_npd                   ( rtlh_fc_rcvd_npd                     ),
    .rtlh_fc_rcvd_cplh                  ( rtlh_fc_rcvd_cplh                    ),
    .rtlh_fc_rcvd_cpld                  ( rtlh_fc_rcvd_cpld                    ),
    .rtlh_fc_allctd_ph                  ( rtlh_fc_allctd_ph                    ),
    .rtlh_fc_allctd_pd                  ( rtlh_fc_allctd_pd                    ),
    .rtlh_fc_allctd_nph                 ( rtlh_fc_allctd_nph                   ),
    .rtlh_fc_allctd_npd                 ( rtlh_fc_allctd_npd                   ),
    .rtlh_fc_allctd_cplh                ( rtlh_fc_allctd_cplh                  ),
    .rtlh_fc_allctd_cpld                ( rtlh_fc_allctd_cpld                  ),
    .rdlh_einj0_lcrc_evt                ( rdlh_einj0_lcrc_evt                  ),
    .xdlh_einj0_lcrc_evt                ( xdlh_einj0_lcrc_evt                  ),
    .xdlh_einj0_fcrc_evt                ( xdlh_einj0_fcrc_evt                  ),
    .xdlh_einj0_dllpcrc_evt             ( xdlh_einj0_dllpcrc_evt               ),
    .xdlh_ras_des_einj1_exp_sequm_evt     ( xdlh_ras_des_einj1_exp_sequm_evt     ), 
    .xdlh_ras_des_einj1_ack_nak_sequm_evt ( xdlh_ras_des_einj1_ack_nak_sequm_evt ),
    .xdlh_einj2_nak_evt                 ( xdlh_einj2_nak_evt                   ),
    .rtlh_einj4_fc_evt                  ( rtlh_einj4_fc_evt                    ),
    .xdlh_einj5_nultlp_evt              ( xdlh_einj5_nultlp_evt                ),
    .xdlh_einj5_dup_evt                 ( xdlh_einj5_dup_evt                   ),
// ----------------------------------------------------------------------------
// RAS Interface (Outputs)
// ----------------------------------------------------------------------------
    .ras_stat_rdlh_corr                 ( ras_stat_rdlh_corr                   ),
    .ras_stat_rdlh_uncorr               ( ras_stat_rdlh_uncorr                 ),
    .ras_stat_rtlh_corr                 ( ras_stat_rtlh_corr                   ),
    .ras_stat_rtlh_uncorr               ( ras_stat_rtlh_uncorr                 ),
    .ras_err_inj_done                   ( ras_err_inj_done                     ),
    .ras_dp_err_log_xtlh                ( ras_dp_err_log_xtlh                  ),
    .ras_dp_err_log_xdlh                ( ras_dp_err_log_xdlh                  ),
// ----------------------------------------------------------------------------
// CRC Error Injection Interface (Outputs)
// ----------------------------------------------------------------------------
    .lcrc_err_asserted                  ( lcrc_err_asserted                    ),
    .ecrc_err_asserted                  ( ecrc_err_asserted                    ),
// ----------------------------------------------------------------------------
// Retry Buffer RAM Interface
// ----------------------------------------------------------------------------
    .retryram_xdlh_data                 ( retrymux_xdlh_data                   ),
    .retryram_xdlh_depth                ( retrymux_xdlh_depth                  ),
    .retryram_xdlh_parerr               ( retrymux_xdlh_parerr                 ),
    .xdlh_retryram_if                   ( xdlh_retryram_if                     ),
    .xdlh_retryram_par_chk_val          ( xdlh_retryram_par_chk_val            ),
    .xdlh_retryram_halt                 (                                      ), // unused
    .xdlh_retrysotram_waddr             ( xdlh_retrysotram_waddr               ),
    .xdlh_retrysotram_raddr             ( xdlh_retrysotram_raddr               ),
    .xdlh_retrysotram_data              ( xdlh_retrysotram_data                ),
    .xdlh_retrysotram_en                ( xdlh_retrysotram_en                  ),
    .xdlh_retrysotram_we                ( xdlh_retrysotram_we                  ),
    .xdlh_retrysotram_par_chk_val       ( xdlh_retrysotram_par_chk_val         ),
    .retrysotram_xdlh_data              ( retrysotram_xdlh_data                ),
    .retrysotram_xdlh_parerr            ( retrysotram_xdlh_parerr              ),
    .retrysotram_xdlh_depth             ( retrysotram_xdlh_depth               )
); // cx_lp
// ----------------------------------------------------------------------------



`ifndef SYNTHESIS
`endif // SYNTHESIS
endmodule
