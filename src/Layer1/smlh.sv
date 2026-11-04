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
// ---    $Revision: #32 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/smlh.sv#32 $
// -------------------------------------------------------------------------
// --- Module Description: State MAC Layer Handler
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Spif/pkg/spif_pkg.svh"
`include "Spif/svif/spif_if.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "power_management/DWC_pcie_pm_pkg.svh"


 module smlh
 import spif_pkg::protocol_cfg_t;
 import spif_pkg::ACTIVE_L0S_PMNAK;
 import spif_pkg::IDLE_L1_1;
 import spif_pkg::L2;
 import DWC_pcie_ctl_pkg::ltssm_cxl_enable_t;
 import DWC_pcie_core_pkg::CFG_CXL_PORT_ENABLE_WD;
 import DWC_pcie_core_pkg::ltssm_state_e;
 import DWC_pcie_core_pkg::S_POLL_ACTIVE;
 import DWC_pcie_core_pkg::S_POLL_COMPLIANCE;
 import DWC_pcie_core_pkg::S_POLL_CONFIG;
 import DWC_pcie_core_pkg::S_CFG_LINKWD_START;
 import DWC_pcie_core_pkg::S_CFG_LINKWD_ACEPT;
 import DWC_pcie_core_pkg::S_CFG_LANENUM_WAIT;
 import DWC_pcie_core_pkg::S_CFG_LANENUM_ACEPT;
 import DWC_pcie_core_pkg::S_CFG_COMPLETE;
 import DWC_pcie_core_pkg::S_RCVRY_LOCK;
 import DWC_pcie_core_pkg::S_RCVRY_RCVRCFG;
 import DWC_pcie_core_pkg::S_RCVRY_EQ0;
 import DWC_pcie_core_pkg::S_RCVRY_EQ1;
 import DWC_pcie_core_pkg::S_RCVRY_EQ2;
 import DWC_pcie_core_pkg::S_RCVRY_EQ3;
 import DWC_pcie_core_pkg::S_DISABLED_ENTRY;
 import DWC_pcie_core_pkg::S_LPBK_ENTRY;
 import DWC_pcie_core_pkg::S_HOT_RESET_ENTRY;
 import DWC_pcie_core_pkg::S_HOT_RESET;
 import DWC_pcie_pm_pkg::usp_link_fsm_state_e;
 import DWC_pcie_pm_pkg::dsp_link_fsm_state_e;
 import DWC_pcie_pm_pkg::pm_protocol_to_link_struct;
 import DWC_pcie_pm_pkg::pm_link_to_protocol_struct;
#(
    parameter INST              = 0,                                       // The uniquifying parameter for each port logic instance.
    parameter EQTS_WD           = 32,                                      // Number of bits of Per Lane Equalization Information
    parameter RX_PSET_WD        = 3,                                       // Width of Receiver Equalization Presets
    parameter TX_PSET_WD        = 4,                                       // Width of Transmitter Equalization Presets
    parameter TX_FS_WD          = 6,                                       // Width of Full Swing values
    parameter TX_FSLF_WD        = 12,                                      // Width of concatenated bus for Equalization "Low Frequency" and "Full Swing" values: {LF, FS}
    parameter TX_COEF_WD        = 18,                                      // Width of concatenated bus for Equalization Coefficients: {C(+1), C(0), C(-1)}
    parameter PCNT_WD           = 4,                                       // persistency count width
    parameter DIRFEEDBACK_WD    = `DIRFEEDBACK_WD,                         // Width of Direction Change
    parameter FOMFEEDBACK_WD    = 8,                                       // Width of Figure of Merit
    parameter TSFD_WD           = `CX_TS_FIELD_CONTROL_WD,                 // Sym7,6,5,4,3,2,1
    parameter AW                = `CX_ANB_WD,                              // Width of the active number of bytes
    parameter NL                = `CX_NL,                                  // Max number of lanes supported
    parameter L2NL              = NL==1 ? 1 : `CX_LOGBASE2(NL),            // log2 number of NL
    parameter NB                = `CX_NB,                                  // Number of symbols (bytes) per clock cycle
    parameter NBK               = `CX_NBK,                                 // Number of symbols (bytes) per clock cycle for datak
    parameter PHY_TXEI_WD       = `CX_PHY_TXEI_WD,                         // PHY TxEelcidle width a lane.
    parameter PSET_ID_WD        = `PSET_ID_WD,
    parameter RXSB_WD           = `CX_MAC_SB_WD,                           // Width of the start block
    parameter RXSH_WD           = `CX_MAC_SH_WD,                           // Width of the sync header
    parameter   NOSB              = (NB>=16 ? NB/16 : 1),      // Number of OS blocks to be handled by the logic simultaneously; ceil(NB/16); used to size all per-TS signals

    parameter DCB_WD            = (NB>=8 ? NB/8 : 1),                      // Width of the DC balance info
    parameter OS_WD             = `CX_MAC_SB_WD, // Number of OS width
    parameter NW                = `CX_PL_NW,                               // Number of 32-bit dwords handled by the datapath each clock.
    parameter BAC_WD            = `CX_BAC_WD,                              // Width of the BlockAlignControl signal
    parameter TS_0_WD           = 48,
    parameter T_WD              = 25 // timer bit width
)

             (
    // -----------------------------------------------------------------------------
    // interfaces
    // -----------------------------------------------------------------------------
    spif_if.smlh_master_mp                 b_smlh_spif,            // Physical Layer to Link Layer SPIF interface
    // -----------------------------------------------------------------------------
    // inputs
    // -----------------------------------------------------------------------------
    // LTSSM timer outputs routed to the top-level for verification usage
    input  [T_WD-1:0]                      smlh_fast_time_1ms,
    input  [T_WD-1:0]                      smlh_fast_time_2ms,
    input  [T_WD-1:0]                      smlh_fast_time_3ms,
    input  [T_WD-1:0]                      smlh_fast_time_4ms,
    input  [T_WD-1:0]                      smlh_fast_time_10ms,
    input  [T_WD-1:0]                      smlh_fast_time_12ms,
    input  [T_WD-1:0]                      smlh_fast_time_24ms,
    input  [T_WD-1:0]                      smlh_fast_time_32ms,
    input  [T_WD-1:0]                      smlh_fast_time_48ms,
    input  [T_WD-1:0]                      smlh_fast_time_64ms,
    input  [T_WD-1:0]                      smlh_fast_time_100ms,
    input                                  core_clk,
    input                                  core_rst_n,
    input  [2:0]                           current_cclk_rate,
    input                                  cfg_comm_clk_config,
    input                                  xplh_smlh_req_rcvry,
    input                                  cfg_flit_mode_enable,
    input                                  cfg_pcie_cap_flit_mode_sup,
    input                                  cfg_flit_mode_dis,
    input                                  cfg_reciver_l0p_supported,
    input  [3:0]                           device_type,
    input                                  cfg_pcie_slot_clk_config,
    input  [CFG_CXL_PORT_ENABLE_WD-1:0]    cfg_cxl_port_enable,
    input  [15:0]                          cfg_cxl_port_vid,
    input                                  cfg_cxl_retimers_pre_mismatched, // cxl retimers present mismatched
    input  [1:0]                           cfg_retimers_pre_detected,   // cxl retimers present detected {retimer2,retimer1}
    input                                  vlsm_almp_rx_req,             // VLSM receives ALMP requests
    input                                  app_sris_mode,
    input                                  xmlh_sris_enable,
    input                                  pipe_regif_all_idle,
    input                                  cfg_rate_chg_mode,
    input                                  cfg_pam4_restricted_levels_requirement,
    input  [NL-1:0]                        pam4_restricted_levels_wr_ack_pending,
    input                                  cfg_ts2_lid_deskew,
    input                                  cfg_support_part_lanes_rxei_exit,
    input                                  cfg_elastic_buffer_mode,
    input                                  cfg_scramble_dis,               // cfg bit to disable scramble when asserted.
    input  [3:0]                           cfg_imp_num_lanes,
    input  [7:0]                           cfg_n_fts,                      // 8bits bus to specify the number of FTS we wish to receive for our receiver
    input                                  cfg_upstream_port,              // when asserted, indicates that this core function as a upstream port
    input                                  cfg_root_compx,                 // indicates that the current port is a root complext port
    input                                  cfg_link_dis,                   // cfg bit to disable link when asserted.
    input                                  cfg_link_retrain,               // cfg bit to force ltssm from l0 to recovery.
    input                                  cfg_lpbk_en,                    // cfg bit to enable loopback when asserted.
    input                                  cfg_mux_lpbk_lanenum,           // 0b (default): use the latched lane number as the scrambler seed; 1b: use the default lane number as the scrambler seed
    input                                  cfg_reset_assert,               // cfg bit to reset link when asserted.
    input  [7:0]                           cfg_link_num,                   // 8 bit link number
    input  [5:0]                           cfg_forced_link_state,          // 5 bits to control manually transaction into each states.
    input  [3:0]                           cfg_forced_ltssm_cmd,
    input                                  cfg_force_en,
    input                                  cfg_fast_link_mode,
    input  [1:0]                           cfg_fast_link_scaling_factor,
    input                                  cfg_l0s_supported,              // if core implemented L0s, set to 1
    input  [5:0]                           cfg_link_capable,
    input                                  cfg_ext_synch,
    input                                  cfg_gen1_ei_inference_mode,
    input  [1:0]                           cfg_select_deemph_mux_bus,
    input  [`CX_LUT_PL_WD-1:0]             cfg_lut_ctrl,
    input  [7:0]                           cfg_rxstandby_control,
    input                                  cfg_polarity_mode,
    input                                  cfg_rx_8_ts1s,
    input                                  cfg_block_local_detect_eq_problem,
    input                                  cfg_rxstandby_handshake_policy,
    input                                  cfg_por_phystatus_mode,
    input  [3:0]                           cfg_p1_entry_policy,
    input  [`CX_PL_GEN3_CONTROL_WD-1:0]    cfg_pl_gen3_control,            // Port Logic Gen3 Control Register
    input  [`CX_PL_GEN3_EQ_CONTROL_WD-1:0] cfg_pl_gen3_eq_control,         // Port Logic Gen3 EQ Control Register
    input  [`CX_DIR_CHANGE_CONTROL_WD-1:0] cfg_fdbk_dirchange_control,     // Port Logic EQ Direction Change Control Register
    // 8 GT/s Receiver Impedance ECN
    input                                  cfg_pl_gen3_zrxdc_noncompl,     // Port Logic register bit field indicating non compliance of 2.5 GT/s receiver impedance while in 8GT/s mode.
    input                                  cfg_perform_eq,                 // Directed control to perform equalization
    input  [NL*TX_PSET_WD-1:0]             cfg_lec_pset_ltx,               // Equalization Presets - input interface with Secondary PCIe Capability
    input  [NL*RX_PSET_WD-1:0]             cfg_lec_pset_lrx,
    input  [NL*TX_PSET_WD-1:0]             cfg_lec_pset_rtx,
    input  [NL*RX_PSET_WD-1:0]             cfg_lec_pset_rrx,
    input                                  cfg_ls2_eq_req,
    input  [`CX_PL_GEN4_CONTROL_WD-1:0]    cfg_pl_gen4_control,            // Port Logic Gen3 Control Register
    input  [`CX_PL_GEN4_EQ_CONTROL_WD-1:0] cfg_pl_gen4_eq_control,         // Port Logic Gen3 EQ Control Register
    input  [`CX_GEN4_DIR_CHANGE_CONTROL_WD-1:0] cfg_gen4_fdbk_dirchange_control, //Port Logic Gen3 EQ Feedback Direction Change Control Register
    input  [NL*TX_PSET_WD-1:0]             cfg_lec_g4_pset_ltx,            // Upstream Component Transmitter Preset (Not applicable to EP/SW_UP)
    input  [NL*RX_PSET_WD-1:0]             cfg_lec_g4_pset_lrx,            // Upstream Component Receiver Preset Hint (Not applicable to EP/SW_UP)
    input  [NL*TX_PSET_WD-1:0]             cfg_lec_g4_pset_rtx,            // Downstream Component Transmitter Preset (Not applicable to EP/SW_UP)
    input  [NL*RX_PSET_WD-1:0]             cfg_lec_g4_pset_rrx,            // Downstream Component Receiver Preset Hint (Not applicable to EP/SW_UP)
    input  [`CX_PL_GEN5_CONTROL_WD-1:0]    cfg_pl_gen5_control,            // Port Logic Gen3 Control Register
    input  [`CX_PL_GEN5_EQ_CONTROL_WD-1:0] cfg_pl_gen5_eq_control,         // Port Logic Gen3 EQ Control Register
    input  [`CX_GEN5_DIR_CHANGE_CONTROL_WD-1:0] cfg_gen5_fdbk_dirchange_control, //Port Logic Gen3 EQ Feedback Direction Change Control Register
    input  [`CX_GEN6_DIR_CHANGE_CONTROL_WD-1:0] cfg_gen6_fdbk_dirchange_control, //Port Logic Gen3 EQ Feedback Direction Change Control Register
    input                                  cfg_bypass_eq_enable,           // enable bypass eq
    input                                  cfg_no_eq_needed_enable,        // enable no eq needed
    input  [NL*TX_PSET_WD-1:0]             cfg_lec_g5_pset_ltx,            // Upstream Component Transmitter Preset (Not applicable to EP/SW_UP)
    input  [NL*RX_PSET_WD-1:0]             cfg_lec_g5_pset_lrx,            // Upstream Component Receiver Preset Hint (Not applicable to EP/SW_UP)
    input  [NL*TX_PSET_WD-1:0]             cfg_lec_g5_pset_rtx,            // Downstream Component Transmitter Preset (Not applicable to EP/SW_UP)
    input  [NL*RX_PSET_WD-1:0]             cfg_lec_g5_pset_rrx,            // Downstream Component Receiver Preset Hint (Not applicable to EP/SW_UP)
    input                                  cfg_tx_precode_req,             // precode request
    input                                  cfg_g6_tx_precode_req,          // gen6 precode request
    input  [`CX_PL_GEN6_CONTROL_WD-1:0]    cfg_pl_gen6_control,            // Port Logic Gen3 Control Register
    input  [`CX_PL_GEN6_EQ_CONTROL_WD-1:0] cfg_pl_gen6_eq_control,         // Port Logic Gen3 EQ Control Register
    input  [NL*TX_PSET_WD-1:0]             cfg_lec_g6_pset_ltx,            // Upstream Component Transmitter Preset (Not applicable to EP/SW_UP)
    input  [NL*RX_PSET_WD-1:0]             cfg_lec_g6_pset_lrx,            // Upstream Component Receiver Preset Hint (Not applicable to EP/SW_UP)
    input  [NL*TX_PSET_WD-1:0]             cfg_lec_g6_pset_rtx,            // Downstream Component Transmitter Preset (Not applicable to EP/SW_UP)
    input  [NL*RX_PSET_WD-1:0]             cfg_lec_g6_pset_rrx,            // Downstream Component Receiver Preset Hint (Not applicable to EP/SW_UP)
    input                                  cfg_alt_protocol_enable,        // enable alternate protocol
    input  [NL*16-1:0]                     cfg_margin_control,             // Margining Control [2:0] Receiver Number[5:3]Margin Type[6]Usage Molde[7]Rsvd[15:8]Margin Payload
    input  [5:0]                           cfg_margin_num_timing_steps,
    input  [5:0]                           cfg_margin_max_timing_offset,
    input  [6:0]                           cfg_margin_num_voltage_steps,
    input  [5:0]                           cfg_margin_max_voltage_offset,
    input  [5:0]                           cfg_margin_sample_rate_voltage,
    input  [5:0]                           cfg_margin_sample_rate_timing,
    input  [4:0]                           cfg_margin_maxlanes,
    input                                  cfg_margin_voltage_supported,
    input                                  cfg_margin_ind_left_right_timing,
    input                                  cfg_margin_ind_up_down_voltage,
    input                                  cfg_margin_sample_reporting_method,
    input                                  cfg_margin_ind_error_sampler,
    input  [3:0]                           cfg_rx_message_bus_write_buffer_depth,
    input                                  cfg_hw_autowidth_dis,           // Hardware auto width disable for upconfigure
    input  [`CX_PL_MULTILANE_CONTROL_WD-1:0] cfg_pl_multilane_control,
    input                                  rasdp_linkdown,                 // Link down request from RASDP logic
    input                                  app_init_rst,                   // application wants to init a link hot reset to downstream port
    input                                  app_ltssm_enable,               // application signal to block the LTSSM link negotion due to application's readyness.
    input                                  xdlh_smlh_start_link_retrain,
    input                                  rtlh_req_link_retrain,          // watch dog time out
    input   [1:0]                          rplh_rcvd_idle,                 // RMLH block keeps track of the number of idle received continously.  Bit 0 indicates receiver received 8 continous idle symbol, bit1 indicates 1 idle receivd
    input                                  rmlh_all_sym_locked,            // symbol locked on all active lanes
    input                                  rmlh_rcvd_eidle_set,            // when asserted, it indicates that RPLH detected electric idle set received
    input   [NL-1:0]                       act_rmlh_rcvd_eidle_set,        // when asserted, it indicates that RPLH detected electric idle set received per lane
    input                                  rmlh_deskew_alignment_err,      // Lanes fell out of alignement
    input                                  rmlh_deskew_complete,           // Lanes are deskewed
    input   [NL-1:0]                       rpipe_rxaligned,
    input                                  rmlh_deskew_datastream,
    input                                  rmlh_goto_recovery,             // an EIEOS is received on any configured Lane in 128b/130b encoding, move from L0 to Recovery.
    input                                  rmlh_gen3_rcvd_4eidle_set,      // in Loopback.Active
    input   [NL-1:0]                       act_rmlh_gen3_rcvd_4eidle_set,  // in Loopback.Active per lane
    input   [NL-1:0]                       rmlh_descrambled_rxdata_dv,
    input   [(NL*NB*8)-1:0]                rmlh_descrambled_rxdata,
    input   [(NL*RXSB_WD)-1:0]             rmlh_descrambled_rxstartblock,
    input   [(NL*RXSB_WD)-1:0]             rmlh_descrambled_ints1,
    input   [(NL*RXSB_WD)-1:0]             rmlh_descrambled_ints2,
    input   [(NL*RXSB_WD)-1:0]             rmlh_descrambled_ineie,
    input   [(NL*RXSB_WD)-1:0]             rmlh_descrambled_eie_det,
    input   [(NL*RXSB_WD)-1:0]             rmlh_descrambled_insds,
    input   [(NL*RXSB_WD)-1:0]             rmlh_descrambled_inskp,
    input   [(NL*NBK)-1:0]                 rmlh_descrambled_rxdatak,
    input   [(NL*NB)-1:0]                  rmlh_descrambled_rxerror,
    input   [NL-1:0]                       rmlh_descrambled_rxaligned,
    input   [NL-1:0][RXSB_WD-1:0][4:0]     rmlh_descrambled_rxdata_osfound,// OS detection flag
    input                                  rdlh_rcvd_dllp,                 // RDLH Received DLLP
    input   [NL-1:0]                       rmlh_deskew_ctlskp_rcvd,        // Received Command and Status SKP-OS
    input   [(NL*16)-1:0]                  rmlh_deskew_ctlskp_info,        // Margin Control/Status within CS-skp-os
    input   [(NL*5)-1:0]                   rmlh_deskew_ctlskp_err,         // CTL-SKP-OS error [0]data parity[1]1st retimer parity [2]2nd retimer parity[3]margin crc[4]margin parity
    input   [(NL*DCB_WD)-1:0]              rmlh_descrambled_rxdata_dcb,
    input   [2:0]                          pm_current_data_rate_smlh_sqf,  // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4
    input   [2:0]                          pm_current_data_rate_smlh_lnk,  // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4
    input   [2:0]                          pm_current_data_rate_smlh_eq,   // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4
    input   [2:0]                          pm_current_data_rate_ltssm,     // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4
    input   [2:0]                          pm_current_data_rate_pre,       // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4
    input   [1:0]                          current_powerdown,              // PHY changed powerdown
    input   [(NL*NB*8)-1:0]                rpipe_rxdata,
    input   [(NL*NBK)-1:0]                 rpipe_rxdatak,
    input   [(NL*NB)-1:0]                  rpipe_rxerror_dup,
    input   [NL-1:0]                       rpipe_rxdata_dv,
    input   [NL-1:0]                       rpipe_rxelecidle,
    input   [NL-1:0]                       rpipe_rxdetected,               // From rmlh_pipe block. Indicates Receiver detected
    input                                  rpipe_rxdetect_done,            // Indicates Receiver detection complete
    input                                  rpipe_all_phystatus_deasserted, // All active receivers are de-asserting phystatus
    input   [NL-1:0]                       rpipe_rxskipremoved,
    input   [NL-1:0]                       rpipe_margin_status,
    input   [NL-1:0]                       rpipe_margin_nak,
    input   [(NL*6)-1:0]                   rpipe_margin_error_cnt,
    input   [(NL*7)-1:0]                   rpipe_margin_sampl_cnt,
    input   [NL-1:0]                       power_saving_lanes_active,
    input   [NL-1:0]                       phy_mac_phystatus,
    input   [NL-1:0]                       phy_mac_rxstandbystatus_physic_lane, // (Physical Lane bit order)
    input   [NL-1:0]                       phy_mac_rxelecidle_physic_lane,      // (Physical Lane bit order)
    input   [NL-1:0]                       laneflip_lanes_active_physic_lane,   // Lane Flip-ed smlh_lanes_active (Physical Lane bit order)
    input   [NL-1:0]                       laneflip_set_rxstandby_physic_lane,  // Lane Flip-ed smlh_set_rxstandby_flip (Physical Lane bit order)
    input   [NL-1:0]                       laneflip_mac_phy_rxstandby,          // Lane Flip-ed mac_phy_rxstandby (Logical Lane bit order)
    input    [NL-1:0]                      laneflip_pipe_turnoff_physic_lane,   // Indicates PIPE Turnoff (Physical Lane bit order)
    input   [8:0]                          cfg_lane_en,                    // pre-determined number of lanes
    input                                  rplh_pkt_start,                 // Indicates a STP or SDP was received
    input   [3:0]                          cfg_compliance_de_emphasis,     // compliance de-emphasis level
    input                                  cfg_directed_speed_change,      // config bit to start speed change
    input                                  cfg_enter_compliance,           // config bit to enter the compliance state
    input                                  cfg_enter_mod_compliance,       // Directed enter modified compliance
    input   [7:0]                          cfg_gen2_n_fts,                 // number of fts's to send in gen 2 speeds
    input                                  cfg_gen2_support,               // core is enabled to run at gen 2 speeds
    input   [3:0]                          cfg_pcie_max_link_speed,        // Max link speed
    input                                  cfg_phy_txswing,                // controls mac_phy_txswing signal to the phy
    input                                  cfg_sel_de_emphasis,            // level of de emphasis
    input   [3:0]                          cfg_target_link_speed,          // Target link speed
    input   [2:0]                          cfg_transmit_margin,            // controls the value of the non-deemphasized voltage level at the Transmitter pins.
    input                                  cfg_tx_compliance_rcv,          // Sets the compliance received bit in the TS1
    input                                  sticky_rst_n,                   // Cold reset
    input                                  smlh_dl_active,                 // SPIF: Indication from the Link Layer that DLCMSM is in DL_ACTIVE state
    input  [TX_FSLF_WD-1:0]                cfg_gen3_eq_fs_lf,              // programmable FS and LF for equalization
    input  [(11*TX_COEF_WD)-1:0]           cfg_gen3_eq_coef,               // programmable FS and LF for equalization
    input  [TX_FSLF_WD-1:0]                cfg_gen4_eq_fs_lf,              // programmable FS and LF for equalization
    input  [(11*TX_COEF_WD)-1:0]           cfg_gen4_eq_coef,               // programmable FS and LF for equalization
    input  [TX_FSLF_WD-1:0]                cfg_gen5_eq_fs_lf,              // programmable FS and LF for equalization
    input  [(11*TX_COEF_WD)-1:0]           cfg_gen5_eq_coef,               // programmable FS and LF for equalization
    input  [TX_FSLF_WD-1:0]                cfg_gen6_eq_fs_lf,              // programmable FS and LF for equalization
    input  [(11*TX_COEF_WD)-1:0]           cfg_gen6_eq_coef,               // programmable FS and LF for equalization
    input                                  pm_smlh_l1_2_latched,           // 1: L1_SUB entered L1_2 substate
    input                                  pm_smlh_l1_n_latched,           // 1: L1_SUB entered L1_N substate
    input  [7:0]                           cfg_l1sub_t_common_mode,        // common mode time in us
    //gates
    input                                  xmtbyte_skip_sent,
    input    [OS_WD-1:0]                   xmtbyte_ts1_sent,
    input    [OS_WD-1:0]                   xmtbyte_ts2_sent,
    input                                  xmtbyte_idle_sent,
    input                                  xmtbyte_eidle_sent,
    input                                  xmtbyte_2_compliance_ts1_sent,
    input                                  xmbyte_flit_data_stream,
    input    [OS_WD-1:0]                   xmtbyte_l0p_ts1_sent,
    input    [OS_WD-1:0]                   xmtbyte_l0p_ts2_sent,
    input                                  xmtbyte_l0p_linkwidth_changed,
    input                                  xmtbyte_l0p_state_in_upsize,
    input                                  xmtbyte_eies_sent,
    input                                  xmtbyte_fts_sent,
    input                                  xmtbyte_cmd_is_data,
    input                                  xmtbyte_txdata_dv,
    input    [(NL*NB*8)-1:0]               xmtbyte_txdata,
    input    [(NL*NBK)-1:0]                xmtbyte_txdatak,
    input    [(NL*PHY_TXEI_WD)-1:0]        int_mac_phy_txelecidle,         // Enable Transmitter Electical Idle
    input                                  xmtbyte_txdetectrx_loopback,    // Enable receiver detect (loopback)
    input    [10:0]                        xmtbyte_ts_pcnt,                // ts sent persistency count
    input                                  xmtbyte_ts_data_diff,           // current ts data different from previous
    input                                  xmtbyte_1024_ts_sent,           // 1024 ts sent in a state without persistency
    input                                  xmtbyte_spd_chg_sent,           // speed_change bit is set in a transmitted ts
    input                                  xmtbyte_dis_link_sent,          // disable link bit set in Tx TS
    input                                  xmtbyte_loe_2_ts1_ec_00b_sent,  //
    input                                  xmtbyte_ctlskip_sent,           // Send flag of the Command and Status SKP OS
    input    [1:0]                         cdm_ras_des_pm_entry_interval,        // Low Power Entry Interval Time for Ras D.E.S Silicon Debug
    input                                  cdm_ras_des_direct_rcvry_idle_to_cfg, // Direct LTSSM from Recovery.Idle to Configuration
    input                                  cdm_ras_des_direct_poll_cmp_to_det,   // Direct LTSSM from Polling.Compliance to Detect
    input                                  cdm_ras_des_direct_lpbk_slave_to_exit,// Direct LTSSM from Loopback(Slave) to Exit
    input                                  cdm_ras_des_ltssm_stop,               // Level : Low Power Entry Interval Time for Ras D.E.S Silicon Debug
    input                                  cdm_ras_des_recovery_req,             // Puls  : Number of Transmit E-IDLE ordered set for Ras D.E.S Silicon Debug
    input                                  cdm_ras_des_force_rxdetected_en,
    input    [NL-1:0]                      cdm_ras_des_force_rxdetected,
    input    [1:0]                         cdm_ras_des_ext_eq_to_factor,         // Extend the eq 24/32ms timeout x2/x10
    input                                  cdm_ras_des_eq_fom_target_en,
    input    [NL-1:0]                      cdm_ras_des_eq_force_coef_rtx_en,
    input    [NL-1:0]                      cdm_ras_des_eq_force_pset_lrx_en,
    input    [NL-1:0]                      cdm_ras_des_eq_force_coef_ltx_en,
    input    [NL*TX_COEF_WD-1:0]           cdm_ras_des_eq_force_coef_ltx,        // Force Local Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
    input    [NL*RX_PSET_WD-1:0]           cdm_ras_des_eq_force_pset_lrx,        // Force Local Receiver Preset Hint for Ras D.E.S Silicon Debug EQ Control
    input    [NL*TX_COEF_WD-1:0]           cdm_ras_des_eq_force_coef_rtx,        // Force Remote Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
    input    [FOMFEEDBACK_WD-1:0]          cdm_ras_des_eq_fom_target,            // FOM Target value for Ras D.E.S Silicon Debug EQ Control
    input    [1:0]                         cdm_ras_des_eq_eval_interval,         // EVAL Interval Time for Ras D.E.S Silicon Debug EQ Control
    input    [NL-1:0]                      cdm_ras_des_eq_force_pset_ltx_en,
    input    [NL*TX_PSET_WD-1:0]           cdm_ras_des_eq_force_usp_pset_ltx,    // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control
    input    [NL-1:0]                      cdm_ras_des_eq_force_coef_rtx_en_g4,
    input    [NL-1:0]                      cdm_ras_des_eq_force_coef_ltx_en_g4,
    input    [NL*TX_COEF_WD-1:0]           cdm_ras_des_eq_force_coef_ltx_g4,     // Force Local Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
    input    [NL*TX_COEF_WD-1:0]           cdm_ras_des_eq_force_coef_rtx_g4,     // Force Remote Transmitter cursor coefficient for Ras DES Silicon Debug EQ Control
    input    [NL-1:0]                      cdm_ras_des_eq_force_pset_ltx_en_g4,
    input    [NL*TX_PSET_WD-1:0]           cdm_ras_des_eq_force_usp_pset_ltx_g4, // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control
    input    [NL-1:0]                      cdm_ras_des_eq_force_coef_rtx_en_g5,
    input    [NL-1:0]                      cdm_ras_des_eq_force_coef_ltx_en_g5,
    input    [NL*TX_COEF_WD-1:0]           cdm_ras_des_eq_force_coef_ltx_g5,     // Force Local Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
    input    [NL*TX_COEF_WD-1:0]           cdm_ras_des_eq_force_coef_rtx_g5,     // Force Remote Transmitter cursor coefficient for Ras DES Silicon Debug EQ Control
    input    [NL-1:0]                      cdm_ras_des_eq_force_pset_ltx_en_g5,
    input    [NL*TX_PSET_WD-1:0]           cdm_ras_des_eq_force_usp_pset_ltx_g5, // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control
    input    [NL-1:0]                      cdm_ras_des_eq_force_coef_rtx_en_g6,
    input    [NL-1:0]                      cdm_ras_des_eq_force_coef_ltx_en_g6,
    input    [NL*TX_COEF_WD-1:0]           cdm_ras_des_eq_force_coef_ltx_g6,     // Force Local Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
    input    [NL*TX_COEF_WD-1:0]           cdm_ras_des_eq_force_coef_rtx_g6,     // Force Remote Transmitter cursor coefficient for Ras DES Silicon Debug EQ Control
    input    [NL-1:0]                      cdm_ras_des_eq_force_pset_ltx_en_g6,
    input    [NL*TX_PSET_WD-1:0]           cdm_ras_des_eq_force_usp_pset_ltx_g6, // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control
    input                                  xdlh_smlh_goto_detect,
    
    input                                  xplh_xmlh_sof,
    input                                  xdlh_smlh_link_req,
    input  [4:0]                           xdlh_smlh_link_width,
    input                                  xdlh_smlh_link_initiated,
    input  [NL-1:0]                        rmlh_deskew_datastream_bus,
    input  [4:0]                           rmlh_rplh_rxdata_link_width,
    input                                  xmlh_sent_24_ts0_ec00,
    input   [NL-1:0]                       rmlh_deskew_ds_g6,

    input                                  pm_current_powerdown_p1,             // Indicate mac phy powerdown is in P1
    input                                  pm_current_powerdown_p0,             // Indicate mac phy powerdown is in P0
    // ---------------------------------------------------------------------------------------------------
    // outputs
    // ---------------------------------------------------------------------------------------------------
    output  [5:0]                          smlh_link_mode,
    output  [5:0]                          smlh_link_rxmode,
    output  [NL-1:0]                       smlh_lanes_active,
    output  [NL-1:0]                       lpbk_eq_lanes_active,
    output  [NL-1:0]                       smlh_no_turnoff_lanes,
    output                                 smlh_lnknum_match_dis,                // This signal is designed to notify the rmlh block when to enable link number match checking
    output                                 smlh_link_up,                         // when asserted, PLH link up.
    output                                 smlh_req_rst_not,                     // when asserted, LTSSM is in link down other than DISABLE,HOTRESET and LPBK state where a reset is required
    output                                 smlh_scrambler_disable,               // when asserted, scramble disabled.
    output                                 smlh_ltssm_in_pollconfig,
    output                                 smlh_training_rst_n,
    output                                 smlh_link_disable,
    output                                 smlh_link_in_training,
    output                                 smlh_bw_mgt_status,                   // Indicate that link retraining (via retrain bit) or HW autonomous link speed change has occurred
                                                                                 // without the port transitioning through DL_Down status
    output                                 smlh_link_auto_bw_status,             // Indicate that hardware has autonomously changed link speed or width, without the port transitioning through
                                                                                 // DL_Down status, for reasons other than to attempt to correct unreliable link operation.
    output  ltssm_state_e                  smlh_ltssm_next,
    output  ltssm_state_e                  smlh_ltssm_last,                      // ltssm last state
    output  [NL-1:0]                       deskew_lanes_active,
    output  [2:0]                          mac_phy_rate,                         // 1=change speed to gen2, 2=change speed to gen3
    output  [NL-1:0]                       mac_phy_rxpolarity,                   // RCVR polarity indication to MAC
    output  [NL-1:0]                       mac_phy_rxstandby,                    // Controls whether the PHY RX is active
    output  [NL-1:0]                       smlh_set_rxstandby,                   // RxStandby condtion (Bit0:NL-1 is always lane0-NL-1)
    output  [1:0]                          mac_phy_txdeemph,                     // selects transmitter de-emphasis in the PHY
    output  [2:0]                          mac_phy_txmargin,                     // selects transmitter voltage levels in the PHY
    output                                 mac_phy_txswing,                      // selects transmitter voltage swing level in the PHY
    output                                 smlh_clr_enter_compliance,            // Signal the cdm that the "Enter Compliance" bit in the "Link Control" register should be cleared
    output                                 smlh_tx_margin_rst,                   // Signal the cdm that the "Transmit Margin" field in the "Link Control 2" register should be cleared
    output                                 smlh_successful_spd_negotiation,
    output                                 smlh_core_rst_n_release_pulse,        // assign DEFAULT_GEN2_SPEED_CHANGE to cfg_directed_speed_change
    output                                 smlh_dir_spd_chg_rising_edge,         // clear cfg_directed_speed_change
    output                                 mac_phy_pam4_restricted_levels,       // The MAC to inform the PHY that the link partner is transmitting or that it will soon be transmitting TS0’s at 64 GT/s.
    output                                 smlh_dir_linkw_chg_started,           // clear cfg_directed_link_width_change
    output                                 smlh_ltssm_in_hotrst_dis_entry,
    output                                 smlh_ltssm_in_compliance,
    output                                 smlh_ltssm_in_rcvrylock,
    output                                 smlh_ltssm_in_detectquiet,
    output                                 ltssm_cmd_send_eieos_for_pset_map,    // send eieos continuously for pset-coef mapping
    output                                 ltssm_usp_eq_redo,
    output                                 smlh_ls2_eq_req,                      // Set Equalization Request bit in Link Status 2
    output [3:1]                           smlh_ls2_eq_success,                  // Equalization Successful {Phase 3, Phase 2, Phase 1}
    output                                 smlh_ls2_eq_cmpl,                     // Equalization Complete
    output                                 smlh_ls2_eq_enter,                    // Equalization Entered
    output                                 smlh_eq_pending,                      // Equalization Pending (Used to delay transmission of DLLPs)
    output                                 smlh_usp_eq_pending,                  // Equalization Pending (Used to delay transmission of DLLPs for USP)
    output                                 smlh_auto_eq_dllp_blocking,           // Equalization pending because of autonomous mechanism
    output                                 usp_g3_eq_redo_executed_int,          // USP gen3 eq redo executed interrupt
    output                                 usp_g4_eq_redo_executed_int,          // USP gen4 eq redo executed interrupt
    output                                 usp_g5_eq_redo_executed_int,          // USP gen5 eq redo executed interrupt
//    output                                 usp_g6_eq_redo_executed_int,          // USP gen6 eq redo executed interrupt
    output [NL*TX_PSET_WD-1:0]             smlh_lec_pset_ltx,                    // Equalization Presets - output interface with Secondary PCIe Capability
    output [NL*RX_PSET_WD-1:0]             smlh_lec_pset_lrx,
    output                                 smlh_ltssm_state_rcvry_eq,
    output                                 smlh_ls2_g4_eq_req,                   // Set Equalization Request bit in Link Status 2
    output [3:1]                           smlh_ls2_g4_eq_success,               // Equalization Successful {Phase 3, Phase 2, Phase 1}
    output                                 smlh_ls2_g4_eq_cmpl,                  // Equalization Complete
    output                                 smlh_ls2_g4_eq_enter,                 // Equalization Entered
    output [NL*TX_PSET_WD-1:0]             smlh_lec_g4_pset_ltx,                 // Equalization Presets - output interface with Secondary PCIe Capability
    output [NL*RX_PSET_WD-1:0]             smlh_lec_g4_pset_lrx,
    output                                 smlh_ls2_g5_eq_req,                   // Set Equalization Request bit in Link Status 2
    output [3:1]                           smlh_ls2_g5_eq_success,               // Equalization Successful {Phase 3, Phase 2, Phase 1}
    output                                 smlh_ls2_g5_eq_cmpl,                  // Equalization Complete
    output                                 smlh_ls2_g5_eq_enter,                 // Equalization Entered
    output [NL*TX_PSET_WD-1:0]             smlh_lec_g5_pset_ltx,                 // Equalization Presets - output interface with Secondary PCIe Capability
    output [NL*RX_PSET_WD-1:0]             smlh_lec_g5_pset_lrx,
    output                                 smlh_ls2_g6_eq_req,                   // Set Equalization Request bit in Link Status 2
    output [3:1]                           smlh_ls2_g6_eq_success,               // Equalization Successful {Phase 3, Phase 2, Phase 1}
    output                                 smlh_ls2_g6_eq_cmpl,                  // Equalization Complete
    output                                 smlh_ls2_g6_eq_enter,                 // Equalization Entered
    output [NL*TX_PSET_WD-1:0]             smlh_lec_g6_pset_ltx,                 // Equalization Presets - output interface with Secondary PCIe Capability
    output [NL*RX_PSET_WD-1:0]             smlh_lec_g6_pset_lrx,
    output                                 smlh_precoding6_on_latched,           // precoding on on Tx at all rate
    output [1:0]                           smlh_elbc_rcvd,                       // Enhanced Link Behavior Control
    output                                 smlh_deprecode_on,                    // deprecode on on Rx
    output                                 smlh_precoding_on,                    // precoding on on Tx 
    output                                 smlh_precoding_on_latched,            // precoding on on Tx at all rate
    output                                 smlh_noeq_needed_rcvd,                // No Equalization needed rcvd
    output                                 smlh_retimer_pre_detected,            // Retimer was present during the latest Config.Complete
    output                                 smlh_two_retimers_pre_detected,       // Two Retimer were present during the latest Config.Complete
    output   [3:0]                         ltssm_gen4_compliance_jmp,            // Gen4 compliance setting# for Jitter Measurment Pattern
    output  [1:0]                          smlh_crosslink_resolution,            // indicates the state of crosslink resolution (00b:not supported,01b:Upstream port,11b:not completed)
    output  [(NL*16)-1:0]                  smlh_margin_status,
    output  [NL-1:0]                       smlh_margin_status_valid,
    output  [(NL*3)-1:0]                   smlh_margin_cmd,
    output  [(NL*7)-1:0]                   smlh_margin_offset,
    output  [(NL*2)-1:0]                   smlh_margin_clr_error_log,
    output   [3:0]                         ltssm_gen6_compliance_tp,             // Gen6 compliance setting# for Toggle Pattern
    output                                 ltssm_dsp_g6_eq1_send_ec00,
    output  [(NL*16)-1:0]                  smlh_ctlskp_info,
    output                                 smlh_margin_ready,
    output                                 smlh_mod_ts_rcvd,                     // modified ts received
    output                                 smlh_in_l0_l0s,                       // LTSSM is in L0 or L0s state
    output  [AW-1:0]                       active_nb,                            // active number of symbols. bit0=1s, bit1=2s, bit2=4s, bit3=8s
    output  logic [AW-1:0]                 active_nb_wire,                       // active number of symbols. bit0=1s, bit1=2s, bit2=4s, bit3=8s, bit4=16s , bit5=32s before FF for high fanout
    output  [AW-1:0]                       active_nb_gen34,                      // active number of symbols for gen34. bit0=1s, bit1=2s, bit2=4s, bit3=8s
    output                                 smlh_do_deskew,                       // Indicate to the deskew block when it is valid to deskew
    output  ltssm_state_e                  smlh_ltssm_state,                     // Current state of Link Training and Status State Machine
    output  ltssm_state_e                  smlh_ltssm_state_wire,                // Current state of Link Training and Status State Machine before FF for high fanout 
    output                                 smlh_in_l0s,
    output                                 smlh_in_rl0s,
    output                                 smlh_in_l0,
    output                                 smlh_in_l1,
    output                                 smlh_in_l1_p1,
    output                                 smlh_in_l23,
    output                                 smlh_l123_eidle_timeout,
    output  [4:0]                          smlh_ts_link_ctrl,                    // received TS1 or TS2 with this Link control in training sequence
    output                                 smlh_rcvd_lane_rev,                   // 1 bit. 1 means int_lane0 rcvd int_lane8; 0 means int_lane0 rcvd int_lane0
    output  [7:0]                          smlh_ts_link_num,                     // 8 bit link number
    output                                 smlh_ts_link_num_is_k237,             // Indicates whether or not received Kchar with k237
    output  [NL-1:0]                       smlh_lanes_rcving,                    // 8bits to indicates that the lane is receiving an ordered-set that is logicly correct
    output                                 smlh_ts_rcv_err,                      // When asserted, it indicates that the TS has violation in hear beat.
    output                                 smlh_ts1_rcvd,                        // when asserted, it indicates Received TS1 on all lanes that is part of multi-lane
    output                                 smlh_ts2_rcvd,                        // when asserted, it indicates Received TS2 on all lanes that is part of multi-lane
    output                                 smlh_inskip_rcv,                      // when asserted, it indicates the receiver is receiving skips on all lane
    output                                 smlh_ts_lane_num_is_k237,             // with k237; Bit7 to Bit0 is Lane number allowed value 0-31
    output                                 latched_rcvd_eidle_set,
    output                                 ltssm_rcvr_err_rpt_en,
    output                                 ltssm_clear,                          // ltssm clear
    output  [3:0]                          ltssm_cmd,
    output  [4:0]                          l0s_state,
    output  [BAC_WD-1:0]                    smlh_blockaligncontrol,              //Tell PHY don't do Block Alignment when in L0 or LPBK_ACTIVE for slave
    input   [NL*TX_FS_WD-1:0]              phy_mac_fs,                           //Local Full Swing
    input   [NL*TX_FS_WD-1:0]              phy_mac_lf,                           //Local Low Frequency
    input   [NL*DIRFEEDBACK_WD-1:0]        phy_mac_dirfeedback,                  //Feed back Direction Change from PHY for remote partner request
    input   [NL*FOMFEEDBACK_WD-1:0]        phy_mac_fomfeedback,                  //Feed back Figure of Merit from PHY for remote partner request
    input   [NL*TX_COEF_WD-1:0]            phy_mac_local_tx_pset_coef,           //mapped coef
    input   [NL-1:0]                       phy_mac_local_tx_coef_valid,          //1 - mapped coef valid
    output  [NL*TX_COEF_WD-1:0]            smlh_eqpa_txdeemph,                   //Local transmitter coefficients {C+1, C0, C-1}
    output  [NL*RX_PSET_WD-1:0]            mac_phy_rxpresethint,                 //Local receiver preset hint
    output  [NL*TX_FS_WD-1:0]              mac_phy_fs,                           //Full Swing advertised by remote partner
    output  [NL*TX_FS_WD-1:0]              mac_phy_lf,                           //Low Frequency advertised by remote partner
    output  [NL-1:0]                       mac_phy_getlocal_pset_coef,           //1 - local preset valid
    output  [NL*PSET_ID_WD-1:0]            mac_phy_local_pset_index,             //local preset
    output  [NL-1:0]                       mac_phy_rxeqinprogress,               //Tell PHY now is in Master request Phase
    output  [NL-1:0]                       mac_phy_invalid_req,                  //The request based on FeedBack of PHY is invalid
    output  [NL-1:0]                       mac_phy_rxeqeval,                     //tell PHY to do evaluation
    output  [NL-1:0]                       mac_phy_dirchange,                    //1 - tell PHY to do DIR evaluation
    output  [NL*TX_COEF_WD-1:0]            csr_mac_phy_coef_rtx,                 //Remote Transmitter Coefficients, concatenation of {C+1, C0, C-1}
    output                                 ltssm_ts_cnt_en,
    output                                 ltssm_ts_cnt_rst,
    output  [4:0]                          ltssm_ts_data_rate,
    output  [9:0]                          ltssm_ts_data_rate_eg6,
    output  [9:0]                          latched_ts_data_rate_eg6,
    output                                 ltssm_cmd_eqts0,          // send ts0
    output                                 ltssm_ts_speed_change,
    output  [4:0]                          latched_ts_data_rate,
    output  [NL-1:0]                       smlh_mcs_rcvd,
    output  [NL*4-1:0]                     smseq_loc_eies_rcvd_bus,
    output                                 ltssm_ts_auto_change,
    output  [1:0]                          ltssm_powerdown,                      // powerdown from LTSSM to rmlh_pipe
    output  [7:0]                          ltssm_xlinknum,
    output  [NL-1:0]                       ltssm_xk237_4lannum,
    output  [NL-1:0]                       ltssm_xk237_4lnknum,
    output  [7:0]                          ltssm_ts_cntrl,                       // training sequence control
    output                                 ltssm_flit_mode_enable,               // both sides agreed
    output  [7:0]                          ltssm_flit_mode_enable_modules,       // both sides agreed
    output                                 ltssm_flit_mode_tx,                   // for TX
    output                                 ltssm_idl_hs_done,
    output                                 ltssm_cmd_compliance_ts1,             // sending two Compliance TS1 in Polling.Compliance
    output  [7:0]                          ltssm_compliance_set_num,              //compliance pattern sequence setting number for compliance_TS1
    output                                 link_usp_sris_mode,                   // recorded usp sris mode
    output                                 smlh_l0p_update,
    output  [5:0]                          smlh_l0p_next_link_mode,              // 10000 -- x16, 01000 -- x8, 00100 -- x4, 00010 -- x2, 00001 -- x1
    output  [5:0]                          smlh_l0p_link_mode,                   // 10000 -- x16, 01000 -- x8, 00100 -- x4, 00010 -- x2, 00001 -- x1
    output  [NL-1:0]                       ltssm_l0p_lanes_active,               // LTSSM latched lanes that are active based on the link negotiation
    output  [NL-1:0]                       ltssm_l0p_last_lanes_active,          // LTSSM latched lanes that are active based on the link negotiation
    output  [3:0]                          ltssm_l0p_cmd,                        // encoded command to notify transmitter of the proper action based on LTSSM states
    output                                 ltssm_l0p_cmd_4_eieos_req,            // 4 eieos request at gen6 rate
    output                                 smlh_l0p_capable,                     // l0p capable
    output                                 smlh_ltssm_in_l0p,                    // LTSSM in L0p state
    output                                 smlh_ltssm_in_l0p_upsize,             // LTSSM in L0p upsize state
    output                                 smlh_ltssm_l0p_ready,                 // LTSSM in L0p state ready
    output  [2:0]                          smlh_flit_error_link_widh,            // Flit Error Link Width
    output                                 smlh_xdlh_eios_rcvd,                  // Received eieos in flit mode
    output                                 smlh_pm_state_trans1_flag,
    output                                 smlh_pm_state_trans2_flag,
    output                                 ltssm_mod_ts,
    output                                 ltssm_ts_alt_protocol,
    output                                 ltssm_no_idle_need_sent,
    output  [55:0]                         ltssm_ts_alt_prot_info,
    output  [55:0]                         ltssm_mod_ts_data_sent,
    output  ltssm_cxl_enable_t             ltssm_cxl_enable,
    output                                 cxl_sh_bypass,                   // Sync headers are bypassed
    output                                 cxl_io_throttle_enable,          // CXL.io Throttle Required at 64GT/s
    output  [23:0]                         ltssm_cxl_mod_ts_phase1_rcvd,          // Received Modified TS Data Phase1
    output                                 ltssm_cxl_retimers_pre_mismatched,   // Set CXL_Retimers_Present_Mismatched bit
    output                                 ltssm_cxl_flexbus_phase2_mismatched, // Set FlexBusEnableBits_Phase2_Mismatch bit
    output                                 cxl_link_enable,                 // Indicates that CXL link is enabled after reaching 8GT/s
    output  protocol_cfg_t                 pl_protocol_cfg,                     // Protocol Configuration for MLH Layer
    output  [1:0]                          ltssm_cxl_ll_mod, // {driftbuffer, commonclock}
    output                                 ltssm_in_lpbk,
    output                                 ltssm_lpbk_master,
    output  [2:0]                          ltssm_eidle_cnt,                      // 4 bits, indicates how many EIOS sets to send before returning xmtbyte_eidle_sent.  0=1 EIOS, 1=2 EIOS, etc.
    output                                 ltssm_in_lpbkentry,
    output  [NL*EQTS_WD-1:0]               eqctl_eqts_info,                      // Equalization Information for Symbols 6-9 of EQ TSs and Gen3 TSs
    output  [NL*TS_0_WD-1:0]               eqctl_eqts_info_ts0,                  // Equalization Information for TS0 Symbols 1-4 of EQ TSs and Gen6 TS0s
    output                                 eqctl_g6_tx_ts0,                      // tx ts0
    output                                 link_rx_ts0_to_ts1_pulse,             // rx ts0 to ts1 transition
    output                                 ltssm_perform_eq_for_lpbk_g6,
    output                                 ltssm_in_lpbk_wo_l0,                  // Ltssm in Loopback state in Gen6 without entering L0 since leaving Detect state
    output                                 ltssm_cfg_to_lpbk_active_master_g6,   // Indicates Loopback.Active state in Gen6 when Ltssm enters Loopback state from Config state
    output  [NL-1:0]                       eqctl_mask_eieos,
    output  [NL-1:0]                       eqctl_2mask_eieos_pulse,
    output  [NL*TX_PSET_WD-1:0]            eqctl_pset_ltx,
    output  [NL*8-1:0]                     smlh_gen3_error_count,
    output  [NL-1:0]                       ltssm_lpbk_slave_lut,                 // lane under test
    output  [7:0]                          muxed_n_fts,
    output  [7:0]                          latched_ts_nfts,
    output  [NL-1:0]                       smseq_ts1_rcvd_pulse_bus,             //
    output  [NL-1:0]                       smseq_ts2_rcvd_pulse_bus,
    output  [NL*4-1:0]                     smseq_loc_ts2_rcvd_bus,               // detect ts2
    output  [NL*4-1:0]                     smseq_in_skp_bus,                     // detect skp
    output  [NL-1:0]                       smseq_fts_skp_do_deskew_bus,          // detect fts->skp
    output  [NL-1:0]                       smseq_invalid_os_bus,                   // Invalid os flag for Flit Error Logging Capability
    output  [NL-1:0]                       smseq_os_corrected_bus,                 // OS corrected flag for Flit Error Logging Capability
    output  [`CX_INFO_EI_WD-1:0]           smlh_debug_info_ei,                   // Debug bus, provides internal status information related to electrical idle, see smlh_ltssm.v for bit field descriptions
    output  [L2NL-1:0]                     smlh_lane_flip_ctrl,
    output  [L2NL-1:0]                     latched_flip_ctrl,
    output  [4:0]                          lpbk_lane_under_test,
    output  [55:0]                         mod_ts_data_rcvd,
    output  [L2NL-1:0]                     ltssm_lane_flip_ctrl,
    input                                  pm_hold_exit_l1,                       // PM Link connections with PM CTRL
    input                                  pm_link_exit_l1,                       // PM Link connections with PM CTRL
    input                                  cfg_pm_clk_pm_en,                      // PM Link connections with PM CTRL
    input                                  cfg_pl_l1_nowait_p1,                   // PM Link connections with PM CTRL
    output                                 pm_linkst_in_l0s,                      // PM Link connections with PM CTRL
    input                                  pm_link_exit_l23,                      // Signals PM Link FSM to exit from L23RDY state
    input   [2:0]                          pm_current_data_rate,
    input                                  pm_pl_wake_ack,                        // PM Controller Wakeup Acknowledge
    input                                  pm_pl_clk_req,                         // PM Controller Clock Request
    input                                  pm_pl_phyinl1,                         // PM Controller PHY in L1
    input                                  pm_pl_phyinl2,                         // PM Controller PHY in L2
    output  usp_link_fsm_state_e           pm_usp_link_state,                     // PM Link connections with PM CTRL
    output  dsp_link_fsm_state_e           pm_dsp_link_state,                     // PM Link connections with PM CTRL
    output                                 pm_smlh_l1_exit,
    output                                 pm_smlh_l23_exit,
    input   pm_protocol_to_link_struct     pm_protocol_to_link_signals,           // PM Link connections with PM Protocol
    output  pm_link_to_protocol_struct     pm_link_to_protocol_signals            // PM Link connections with PM Protocol
    ,
    input                                  splh_pm_req_l0s,                       // Packet Layer requests PM Link FSM to enter L0s
    input                                  splh_pm_req_l1,                        // Packet Layer requests PM Link FSM to enter L1
    input                                  splh_pm_req_l2                         // Packet Layer requests PM Link FSM to enter L2
    ,
    output                                 smlh_eidle_inferred_in_l0,
    output                                 smlh_rx_rcvry_req,
    output                                 smlh_timeout_nfts,
    output                                 smlh_l0_to_recovery,
    output                                 smlh_l1_to_recovery,
    output                                 smlh_rcv_eios_when_l0s_unsprt,
    output                                 smlh_deskew_uncomplete_err,
    output                                 smlh_spd_change,
    output  [NL*8-1:0]                     smseq_mcs_sts,
    output                                 smlh_lwd_change,
    output  [15:0]                         smlh_ltssm_variable,
    output  [NL*16-1:0]                    smlh_rxos_type,
    output  [NL*64-1:0]                    smseq_ts_debug_info
    ,
    output                                 init_eq_pending 
    ,
    output  [NL*TX_FS_WD-1:0]              mac_cdm_ras_des_fs,
    output  [NL*TX_FS_WD-1:0]              mac_cdm_ras_des_lf,
    output  [NL*TX_COEF_WD-1:0]            mac_cdm_ras_des_coef_ltx,
    output  [NL*FOMFEEDBACK_WD-1:0]        phy_cdm_ras_des_fomfeedback,
    output  [NL*3-1:0]                     eqpa_violate_rule_123,
    output  [NL*2-1:0]                     eq_convergence_sts,
    output  [NL*TX_COEF_WD-1:0]            mac_cdm_ras_des_coef_rtx,
    output  [NL*RX_PSET_WD-1:0]            mac_cdm_ras_des_pset_lrx,
    output  [NL-1:0]                       mac_cdm_ras_des_reject_rtx
    ,
    output                                 init_eq_pending_g4 
    ,
    output  [NL*TX_FS_WD-1:0]              mac_cdm_ras_des_fs_g4,
    output  [NL*TX_FS_WD-1:0]              mac_cdm_ras_des_lf_g4,
    output  [NL*TX_COEF_WD-1:0]            mac_cdm_ras_des_coef_ltx_g4,
    output  [NL*FOMFEEDBACK_WD-1:0]        phy_cdm_ras_des_fomfeedback_g4,
    output  [NL*3-1:0]                     eqpa_violate_rule_123_g4,
    output  [NL*2-1:0]                     eq_convergence_sts_g4,
    output  [NL*TX_COEF_WD-1:0]            mac_cdm_ras_des_coef_rtx_g4,
    output  [NL-1:0]                       mac_cdm_ras_des_reject_rtx_g4
    ,
    output                                 init_eq_pending_g5 
    ,
    output  [NL*TX_FS_WD-1:0]              mac_cdm_ras_des_fs_g5,
    output  [NL*TX_FS_WD-1:0]              mac_cdm_ras_des_lf_g5,
    output  [NL*TX_COEF_WD-1:0]            mac_cdm_ras_des_coef_ltx_g5,
    output  [NL*FOMFEEDBACK_WD-1:0]        phy_cdm_ras_des_fomfeedback_g5,
    output  [NL*3-1:0]                     eqpa_violate_rule_123_g5,
    output  [NL*2-1:0]                     eq_convergence_sts_g5,
    output  [NL*TX_COEF_WD-1:0]            mac_cdm_ras_des_coef_rtx_g5,
    output  [NL-1:0]                       mac_cdm_ras_des_reject_rtx_g5
    ,
    output                                 init_eq_pending_g6 
    ,
    output  [NL*TX_FS_WD-1:0]              mac_cdm_ras_des_fs_g6,
    output  [NL*TX_FS_WD-1:0]              mac_cdm_ras_des_lf_g6,
    output  [NL*TX_COEF_WD-1:0]            mac_cdm_ras_des_coef_ltx_g6,
    output  [NL*FOMFEEDBACK_WD-1:0]        phy_cdm_ras_des_fomfeedback_g6,
    output  [NL*3-1:0]                     eqpa_violate_rule_123_g6,
    output  [NL-1:0]                       eqpa_violate_rule_4_g6,
    output  [NL*2-1:0]                     eq_convergence_sts_g6,
    output  [NL*TX_COEF_WD-1:0]            mac_cdm_ras_des_coef_rtx_g6,
    output  [NL-1:0]                       mac_cdm_ras_des_reject_rtx_g6
);

// ---------------------------------------------------------------------------------------------------
// internal signals
// ---------------------------------------------------------------------------------------------------
wire                          pm_smlh_entry_to_l0s;
wire                          pm_smlh_l0s_exit;
wire                          pm_smlh_entry_to_l1;
wire                          pm_smlh_entry_to_l2;
wire                          pm_smlh_prepare4_l123;
wire                          pm_smlh_dllp_hs;
localparam N_DELAY_GEN5_FPGA = 0;
wire                          smlh_in_l0_s;
wire                          ltssm_mod_ts_rx;
wire    [NL-1:0]              smseq_mod_ts1_rcvd_pulse_bus; // modified ts1
wire    [NL-1:0]              smseq_mod_ts2_rcvd_pulse_bus; // modified ts2
wire    [NL-1:0]              int_lpbk_slave_lut;
wire    [2:0]                 current_data_rate = pm_current_data_rate_smlh_lnk;
assign                        ltssm_lpbk_slave_lut = {NL{current_data_rate == `GEN5_RATE | current_data_rate == `GEN6_RATE}} & int_lpbk_slave_lut;
wire    [NL-1:0]              link_imp_lanes;
wire    [5:0]                 link_next_link_mode;            // intermediate active lane number
wire    [NL-1:0]              link_lanes_rcving;
wire    [1:0]                 link_latched_flitm_support;
wire                          link_latched_modts_support;
wire                          link_latched_mdfts_support;
wire                          link_latched_skipeq_enable;
wire                          link_latched_live_all_8_ts1_plinkn_planen_compl_rcv_0_rcvd;
wire                          link_latched_live_all_8_ts1_plinkn_planen_lpbk1_rcvd;
wire                          link_latched_live_all_8_ts2_plinkn_planen_rcvd;
wire                          link_latched_live_all_8_ts_plinkn_planen_rcvd;
wire     [NL-1:0]             link_latched_live_any_8_ts_plinkn_planen_rcvd_bus;
wire                          link_latched_live_any_8_ts_plinkn_planen_rcvd;
wire                          link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_0_rcvd;
wire                          link_latched_live_any_8_ts1_plinkn_planen_lpbk1_rcvd;
wire                          link_latched_live_any_8_ts2_plinkn_planen_rcvd;
wire                          link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd;
wire                          link_xmlh_1024_ts1_sent_after_any_1_ts_rcvd;
wire                          link_xmlh_16_ts2_sent_after_1_ts2_rcvd;
wire                          link_xmlh_16_ts2_sent_after_1_ts2_rcvd_noeies;
wire                          link_xmlh_16_ts1_sent;
wire                          link_latched_live_all_2_ts1_dis1_rcvd;
wire                          link_latched_live_all_2_ts1_lpbk1_rcvd;
wire     [NL-1:0]             link_latched_live_all_2_ts1_lpbk1_ebth1_rcvd;
wire     [NL-1:0]             link_latched_live_all_2_ts1_lpbk1_tmcp1_rcvd;
wire                          link_latched_live_any_2_ts1_apn_rcvd;
wire     [55:0]               link_latched_live_any_2_ts1_apn_sym14_8_rcvd;
wire                          link_latched_live_any_2_ts2_apn_rcvd;
wire     [NL*56-1:0]          link_latched_live_all_8_ts2_apn_sym14_8_rcvd;
wire                          link_latched_live_all_2_ts2_apn_rcvd;
wire     [NL*56-1:0]          link_latched_live_all_2_ts2_apn_sym14_8_rcvd;
wire                          ltssm_ap_success;
assign                        mod_ts_data_rcvd = ltssm_ap_success ? link_latched_live_all_8_ts2_apn_sym14_8_rcvd[55:0] : 56'h0;
wire                          link_latched_all_2_ts1_lpbk1_compl_rcv_1_rcvd;
wire                          link_any_2_ts1_linknmtx_planen_rcvd;
wire                          link_any_1_ts1_plinkn_planen_first_rcvd_2_ts1_linknmtx_planen_same_lane_rcvd;
wire                          link_any_2_ts1_dis1_rcvd;
wire                          link_latched_live_all_2_ts1_linkn_planen_rcvd;
wire                          link_any_2_ts1_linkn_planen_rcvd;
wire                          link_lane0_2_ts1_linkn_planen_rcvd;
wire                          link_lane0_2_ts1_linknmtx_rcvd;
wire                          link_lane0_2_ts1_linknmtx_lanen_rcvd;
wire                          link_latched_live_all_2_ts1_linknmtx_rcvd;
wire                          link_latched_live_all_2_ts1_linknmtx_lanen_rcvd;
wire                          link_latched_live_all_2_ts1_plinkn_planen_rcvd;
wire                          link_latched_live_lane0_2_ts1_lanen0_rcvd;
wire                          link_latched_live_all_2_ts1_linknmtx_lanenmtx_rcvd;
wire                          link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd;
wire                          link_latched_live_any_2_ts1_lanendiff_linkn_rcvd;
wire                          link_any_2_ts2_rcvd;
wire                          link_latched_live_all_2_ts2_linknmtx_lanenmtx_rcvd;
wire                          link_latched_live_all_8_ts1_linknmtx_lanenmtx_rcvd;
wire                          link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd;
wire                          link_latched_live_all_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd;
wire                          link_latched_live_all_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd;
wire                          link_latched_live_all_8_ts_linknmtx_lanenmtx_rcvd;
wire                          link_latched_live_all_8_ts2_linknmtx_lanenmtx_spd_chg_0_rcvd;
wire                          link_latched_live_all_8_ts2_linknmtx_lanenmtx_g1_rate_rcvd;
wire                          link_any_2_ts1_rcvd;
wire                          link_latched_live_any_8_ts2_linknmtx_lanenmtx_dis_link_rcvd;
wire                          link_latched_live_any_8_ts2_linknmtx_lanenmtx_hot_reset_rcvd;
wire                          link_latched_live_any_8_ts2_linknmtx_lanenmtx_loopback_rcvd;
wire                          link_latched_live_any_8_ts1_spd_chg_0_rcvd_after_ts2_rcvd;
wire                          link_latched_live_any_8_ts2_spd_chg_0_rcvd;
wire                          link_latched_live_any_8_ts2_spd_chg_0_plinkn_rcvd;
wire                          link_latched_live_all_8_ts1_linknmtx_lanenmtx_l0p_rcvd;
wire                          link_latched_live_all_8_ts2_linknmtx_lanenmtx_l0p_rcvd;
wire                          link_any_exact_2_ts_l0p_rcvd;
wire                          link_xmlh_l0p_16_ts2_sent_after_1_ts2_rcvd;
wire                          link_xmlh_l0p_16_ts1_sent;
wire                          link_latched_live_all_ts1_spd_chg_0_rcvd;
wire                          link_latched_live_any_ts2_rcvd;
wire                          link_any_8_ts1_spd_chg_1_rcvd;
wire    [4:0]                 link_any_8_ts_spd_chg_1_data_rate;
wire                          int_directed_speed_change;
wire                          link_latched_live_all_ts1_not_ec_00b_rcvd;
wire                          link_latched_live_all_ts1_ec_00b_rcvd;
wire                          link_latched_live_all_ts1_ec_00b_spd_chg_same_as_dir_spd_chg_rcvd;
wire                          link_latched_live_all_spd_chg_rcvd_same_as_dir_spd_chg;
wire                          link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd;
wire                          link_any_8_ts_linknmtx_lanenmtx_rcvd;
wire                          link_any_8_ts_linknmtx_lanenmtx_auto_chg_rcvd;
wire                          link_ln0_8_ts2_linknmtx_lanenmtx_rcvd;
wire                          link_ln0_8_ts2_linknmtx_lanenmtx_auto_chg_rcvd;
wire                          link_ln0_2_ts1_linknmtx_lanenmtx_auto_chg_rcvd;
wire                          link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_gtr_g1_rate_rcvd;
wire                          link_latched_live_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd;
wire                          link_latched_live_any_1_ts_linknmtx_lanenmtx_rcvd;
wire                          link_latched_live_any_1_ts_linknmtx_lanenmtx_g1_rate_rcvd;
wire                          link_latched_live_any_8_std_ts2_spd_chg_1_rcvd;
wire                          link_latched_live_all_8_eq_ts2_spd_chg_1_rcvd;
wire                          link_latched_live_all_8_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd;
wire                          link_any_8_eq_ts2_spd_chg_1_rcvd;
wire                          link_any_8_8gteq_ts2_spd_chg_1_rcvd;
wire                          link_any_8_16gteq_ts2_spd_chg_1_rcvd;
wire                          link_any_8_32gteq_ts2_spd_chg_1_rcvd;
wire                          link_pc6_rcvd;
wire                          link_pc_rcvd;
wire                          link_latched_live_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd;
wire                          link_latched_live_any_8_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd;
wire                          smlh_link_up_falling_edge;
wire                          link_xmlh_32_ts2_spd_chg_1_sent;
wire                          link_xmlh_128_ts2_spd_chg_1_sent;
wire                          link_xmlh_16_ts2_sent_after_1_ts1_rcvd;
wire                          link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_rcvd;
wire                          link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd;
wire                          link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_g1_rate_rcvd;
wire                          link_any_2_ts1_hotreset1_rcvd;
wire                          link_any_2_ts1_linknmtx_lanenmtx_hotreset1_rcvd;
wire                          link_any_2_ts1_planen_rcvd;
wire                          link_any_2_ts1_lpbk1_rcvd;
wire                          link_imp_2_ts1_lpbk1_rcvd;
wire                          link_latched_any_2_ts1_lpbk1_compl_rcv_1_rcvd;
wire                          link_any_2_ts_rcvd;
wire                          link_1_ts_rcvd;
wire                          link_any_1_ts_rcvd;
wire                          link_any_1_ts2_rcvd;
wire                          link_any_exact_1_ts_rcvd;
wire                          link_any_exact_2_ts_rcvd;
wire                          link_any_exact_4_ts_rcvd;
wire                          link_any_exact_5_ts_rcvd;
wire                          link_latched_live_all_2_ts1_rcvd;
wire    [4:0]                 link_latched_ts_data_rate;
wire    [4:0]                 link_latched_ts_data_rate_ever;
wire                          link_latched_ts_spd_chg;
wire    [4:0]                 link_ts_data_rate;
wire                          link_ts_spd_chg;
wire    [4:0]                 link_lpbk_ts_data_rate;
wire    [4:0]                 link_latched_lpbk_ts_data_rate;
wire                          link_lpbk_ts_deemphasis;
wire    [7:0]                 link_ts_nfts;
wire                          link_latched_live_all_ts_scrmb_dis;
wire                          link_any_8_ts_auto_chg;
wire    [7:0]                 link_any_2_ts1_link_num;
wire    [NL-1:0]              link_mode_lanes_active;
wire    [NL-1:0]              link_2_ts1_plinkn_planen_rcvd_upconf;
wire                          link_any_ts2_rcvd;
wire                          link_latched_ts_retimer_pre;
wire                          link_latched_ts_two_retimers_pre;
wire                          link_latched_poll_config_ts_retimer_pre;
wire                          link_latched_poll_config_ts_two_retimers_pre;
wire                          ltssm_clear_eqctl;
wire                          ltssm_clear_seq;
wire                          ltssm_clear_link;
wire    [NL-1:0]              pre_link_imp_lanes;
wire    [5:0]                 pre_link_next_link_mode;            // intermediate active lane number
wire    [NL-1:0]              pre_link_lanes_rcving;
wire    [1:0]                 pre_link_latched_flitm_support;
wire                          pre_link_usp_sris_mode;
wire                          pre_link_latched_modts_support;
wire                          pre_link_latched_skipeq_enable;
wire                          pre_link_latched_live_all_8_ts1_plinkn_planen_compl_rcv_0_rcvd;
wire                          pre_link_latched_live_all_8_ts1_plinkn_planen_lpbk1_rcvd;
wire                          pre_link_latched_live_all_8_ts2_plinkn_planen_rcvd;
wire                          pre_link_latched_live_all_8_ts_plinkn_planen_rcvd;
wire     [NL-1:0]             pre_link_latched_live_any_8_ts_plinkn_planen_rcvd_bus;
wire                          pre_link_latched_live_any_8_ts_plinkn_planen_rcvd;
wire                          pre_link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_0_rcvd;
wire                          pre_link_latched_live_any_8_ts1_plinkn_planen_lpbk1_rcvd;
wire                          pre_link_latched_live_any_8_ts2_plinkn_planen_rcvd;
wire                          pre_link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd;
wire                          pre_link_xmlh_1024_ts1_sent_after_any_1_ts_rcvd;
wire                          pre_link_xmlh_16_ts2_sent_after_1_ts2_rcvd;
wire                          pre_link_xmlh_16_ts2_sent_after_1_ts2_rcvd_noeies;
wire                          pre_link_xmlh_16_ts1_sent;
wire                          pre_link_latched_live_all_2_ts1_dis1_rcvd;
wire                          pre_link_latched_live_all_2_ts1_lpbk1_rcvd;
wire     [NL-1:0]             pre_link_latched_live_all_2_ts1_lpbk1_ebth1_rcvd;
wire     [NL-1:0]             pre_link_latched_live_all_2_ts1_lpbk1_tmcp1_rcvd;
wire                          pre_link_latched_live_any_2_ts1_apn_rcvd;
wire     [55:0]               pre_link_latched_live_any_2_ts1_apn_sym14_8_rcvd;
wire                          pre_link_latched_live_any_2_ts2_apn_rcvd;
wire     [NL*56-1:0]          pre_link_latched_live_all_8_ts2_apn_sym14_8_rcvd;
wire                          pre_link_latched_live_all_2_ts2_apn_rcvd;
wire     [NL*56-1:0]          pre_link_latched_live_all_2_ts2_apn_sym14_8_rcvd;
wire                          pre_link_latched_all_2_ts1_lpbk1_compl_rcv_1_rcvd;
wire                          pre_link_any_2_ts1_linknmtx_planen_rcvd;
wire                          pre_link_any_1_ts1_plinkn_planen_first_rcvd_2_ts1_linknmtx_planen_same_lane_rcvd;
wire                          pre_link_any_2_ts1_dis1_rcvd;
wire                          pre_link_latched_live_all_2_ts1_linkn_planen_rcvd;
wire                          pre_link_any_2_ts1_linkn_planen_rcvd;
wire                          pre_link_lane0_2_ts1_linkn_planen_rcvd;
wire                          pre_link_lane0_2_ts1_linknmtx_rcvd;
wire                          pre_link_lane0_2_ts1_linknmtx_lanen_rcvd;
wire                          pre_link_latched_live_all_2_ts1_linknmtx_rcvd;
wire                          pre_link_latched_live_all_2_ts1_linknmtx_lanen_rcvd;
wire                          pre_link_latched_live_all_2_ts1_plinkn_planen_rcvd;
wire                          pre_link_latched_live_lane0_2_ts1_lanen0_rcvd;
wire                          pre_link_latched_live_all_2_ts1_linknmtx_lanenmtx_rcvd;
wire                          pre_link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd;
wire                          pre_link_latched_live_any_2_ts1_lanendiff_linkn_rcvd;
wire                          pre_link_any_2_ts2_rcvd;
wire                          pre_link_latched_live_all_2_ts2_linknmtx_lanenmtx_rcvd;
wire                          pre_link_latched_live_all_8_ts1_linknmtx_lanenmtx_rcvd;
wire                          pre_link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd;
wire                          pre_link_latched_live_all_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd;
wire                          pre_link_latched_live_all_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd;
wire                          pre_link_latched_live_all_8_ts_linknmtx_lanenmtx_rcvd;
wire                          pre_link_latched_live_all_8_ts2_linknmtx_lanenmtx_spd_chg_0_rcvd;
wire                          pre_link_latched_live_all_8_ts2_linknmtx_lanenmtx_g1_rate_rcvd;
wire                          pre_link_any_2_ts1_rcvd;
wire                          pre_link_latched_live_any_8_ts2_linknmtx_lanenmtx_dis_link_rcvd;
wire                          pre_link_latched_live_any_8_ts2_linknmtx_lanenmtx_hot_reset_rcvd;
wire                          pre_link_latched_live_any_8_ts2_linknmtx_lanenmtx_loopback_rcvd;
wire                          pre_link_latched_live_any_8_ts1_spd_chg_0_rcvd_after_ts2_rcvd;
wire                          pre_link_latched_live_any_8_ts2_spd_chg_0_rcvd;
wire                          pre_link_latched_live_any_8_ts2_spd_chg_0_plinkn_rcvd;
wire                          pre_link_latched_live_all_8_ts1_linknmtx_lanenmtx_l0p_rcvd;
wire                          pre_link_latched_live_all_8_ts2_linknmtx_lanenmtx_l0p_rcvd;
wire                          pre_link_any_exact_2_ts_l0p_rcvd;
wire                          pre_link_xmlh_l0p_16_ts2_sent_after_1_ts2_rcvd;
wire                          pre_link_xmlh_l0p_16_ts1_sent;
wire                          pre_link_latched_live_all_ts1_spd_chg_0_rcvd;
wire                          pre_link_latched_live_any_ts2_rcvd;
wire                          pre_link_any_8_ts1_spd_chg_1_rcvd;
wire    [4:0]                 pre_link_any_8_ts_spd_chg_1_data_rate;
wire                          pre_int_directed_speed_change;
wire                          pre_link_latched_live_all_ts1_not_ec_00b_rcvd;
wire                          pre_link_latched_live_all_ts1_ec_00b_rcvd;
wire                          pre_link_latched_live_all_ts1_ec_00b_spd_chg_same_as_dir_spd_chg_rcvd;
wire                          pre_link_latched_live_all_spd_chg_rcvd_same_as_dir_spd_chg;
wire                          pre_link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd;
wire                          pre_link_any_8_ts_linknmtx_lanenmtx_rcvd;
wire                          pre_link_any_8_ts_linknmtx_lanenmtx_auto_chg_rcvd;
wire                          pre_link_ln0_8_ts2_linknmtx_lanenmtx_rcvd;
wire                          pre_link_ln0_8_ts2_linknmtx_lanenmtx_auto_chg_rcvd;
wire                          pre_link_ln0_2_ts1_linknmtx_lanenmtx_auto_chg_rcvd;
wire                          pre_link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_gtr_g1_rate_rcvd;
wire                          pre_link_latched_live_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd;
wire                          pre_link_latched_live_any_1_ts_linknmtx_lanenmtx_rcvd;
wire                          pre_link_latched_live_any_1_ts_linknmtx_lanenmtx_g1_rate_rcvd;
wire                          pre_link_latched_live_any_8_std_ts2_spd_chg_1_rcvd;
wire                          pre_link_latched_live_all_8_eq_ts2_spd_chg_1_rcvd;
wire                          pre_link_latched_live_all_8_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd;
wire                          pre_link_any_8_eq_ts2_spd_chg_1_rcvd;
wire                          pre_link_any_8_8gteq_ts2_spd_chg_1_rcvd;
wire                          pre_link_any_8_16gteq_ts2_spd_chg_1_rcvd;
wire                          pre_link_any_8_32gteq_ts2_spd_chg_1_rcvd;
wire                          pre_link_pc6_rcvd;
wire                          pre_link_pc_rcvd;
wire                          pre_link_latched_live_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd;
wire                          pre_link_latched_live_any_8_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd;
wire                          pre_link_xmlh_32_ts2_spd_chg_1_sent;
wire                          pre_link_xmlh_128_ts2_spd_chg_1_sent;
wire                          pre_link_xmlh_16_ts2_sent_after_1_ts1_rcvd;
wire                          pre_link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_rcvd;
wire                          pre_link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd;
wire                          pre_link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_g1_rate_rcvd;
wire                          pre_link_any_2_ts1_hotreset1_rcvd;
wire                          pre_link_any_2_ts1_linknmtx_lanenmtx_hotreset1_rcvd;
wire                          pre_link_any_2_ts1_planen_rcvd;
wire                          pre_link_any_2_ts1_lpbk1_rcvd;
wire                          pre_link_imp_2_ts1_lpbk1_rcvd;
wire                          pre_link_latched_any_2_ts1_lpbk1_compl_rcv_1_rcvd;
wire                          pre_link_any_2_ts_rcvd;
wire                          pre_link_1_ts_rcvd;
wire                          pre_link_any_1_ts_rcvd;
wire                          pre_link_any_1_ts2_rcvd;
wire                          pre_link_any_exact_1_ts_rcvd;
wire                          pre_link_any_exact_2_ts_rcvd;
wire                          pre_link_any_exact_4_ts_rcvd;
wire                          pre_link_any_exact_5_ts_rcvd;
wire                          pre_link_latched_live_all_2_ts1_rcvd;
wire    [4:0]                 pre_link_latched_ts_data_rate;
wire    [4:0]                 pre_link_latched_ts_data_rate_ever;
wire                          pre_link_latched_ts_spd_chg;
wire    [4:0]                 pre_link_ts_data_rate;
wire                          pre_link_ts_spd_chg;
wire    [4:0]                 pre_link_lpbk_ts_data_rate;
wire    [4:0]                 pre_link_latched_lpbk_ts_data_rate;
wire                          pre_link_lpbk_ts_deemphasis;
wire    [7:0]                 pre_link_ts_nfts;
wire                          pre_link_latched_live_all_ts_scrmb_dis;
wire                          pre_link_any_8_ts_auto_chg;
wire    [7:0]                 pre_link_any_2_ts1_link_num;
wire    [NL-1:0]              pre_link_mode_lanes_active;
wire    [NL-1:0]              pre_link_2_ts1_plinkn_planen_rcvd_upconf;
wire                          pre_link_any_ts2_rcvd;
wire                          pre_link_latched_ts_retimer_pre;
wire                          pre_link_latched_ts_two_retimers_pre;
wire                          pre_link_latched_poll_config_ts_retimer_pre;
wire                          pre_link_latched_poll_config_ts_two_retimers_pre;
//--------
wire    [NL*4-1:0]            smseq_ts_rcvd_pcnt_bus;          // persistency count
wire    [NL*2-1:0]            smseq_ts_rcvd_cond_pcnt_bus;     // persistency count with conditions
wire    [NL*4-1:0]            smseq_ts_rcvd_mtx_pcnt_bus;      // persistency match Tx count
wire                          ltssm_directed_speed_change;
wire    [NL*TSFD_WD-1:0]      smseq_ts_info_bus;
wire    [NL*64-1:0]           smseq_mt_info_bus;
wire    [NL*2-1:0]            smseq_ts_lanen_linkn_pad_bus;
wire    [NL-1:0]              smlh_inskip_rcv_bus;
wire                          ltssm_lpbk_entry_send_ts1;
ltssm_state_e                 ltssm_last;
wire    [NL-1:0]              ltssm_lanes_active;
wire                          lpbk_eq;
wire                          lpbk_eq_n_lut_pset;
wire                          ltssm_in_pollconfig;
wire                          ltssm_state_is_rcvrylock;
wire                          lpbk_master;
wire    [7:0]                 current_n_fts;
wire    [NL-1:0]              smseq_ts0_rcvd_bus;
wire    [NL-1:0]              smseq_ts1_rcvd_bus;
wire    [NL-1:0]              eqctl_rev_smlh_ts0_rcvd_bus;
wire    [NL-1:0]              eqctl_rev_smlh_ts1_rcvd_bus;
wire    [NL-1:0]              eqctl_rev_rxdata_dv;
wire    [NL-1:0]              smseq_ts2_rcvd_bus;
wire    [NL-1:0]              smseq_ts1_rcvd_pulse_bus_to_smlh;
wire    [NL-1:0]              smseq_ts2_rcvd_pulse_bus_to_smlh;
wire    [NL-1:0]              eqctl_rev_smlh_ts2_rcvd_bus;
wire                          smlh_all_lannum_match;          // 1, all lane match
wire                          smlh_eidle_inferred;
wire    [NL-1:0]              smlh_keep_rcvrylock_lane;
wire    [NL-1:0]              smseq_fts_rcvd_pulse;
wire                          ltssm_timeout10ms;
wire    [7:0]                 smlh_ts_nfts;                   // 8 bits nfts number contained in training sequence
wire    [(NL*8)-1:0]          smlh_ts_link_num_bus;           // 8 bit link number per lane
wire    [NL-1:0]              smlh_ts_rcvd_pulse_bus;         // ts0/ts1/ts2 received by receiver
wire    [NL-1:0]              smlh_sds_rcvd;                  // sds received by receiver
wire                          smlh_anylan_rcvd_atleast_1ts;   // any lane received at least 1 ts
wire                          smlh_2_lane_num_match;          // received 2 consecutive TSs with the same Lane #
wire    [NL-1:0]              smseq_sds_rcvd_bus;
wire    [NL-1:0]              smseq_ts_error_bus;
wire    [(NL*8)-1:0]          smseq_ts_link_num_bus;
wire    [(NL*8)-1:0]          smseq_ts_lane_num_bus;           // 8 bit lane nubmer (per lane)
wire    [NL-1:0]              smseq_ts_link_num_is_k237_bus;   // link number was K237
wire    [NL-1:0]              smseq_ts_lane_num_is_k237_bus;   // lane number was K237
wire    [(NL*8)-1:0]          smseq_ts_nfts_bus;               // 8 bits per lane
wire    [(NL*5)-1:0]          smseq_ts_link_ctrl_bus;          // 5 bits per lane
wire    [NL*4-1:0]            smseq_st_ts_rcvd_s6_pcnt;        // persistency count of Sym6
wire    [NL*4-1:0]            smseq_ts_rcvd_s6_pcnt;           // persistency count of Sym6
wire    [NL-1:0]              smseq_ineies_rcv_bus;
wire    [NL-1:0]              smseq_mcs_rcvd;
wire    [4:0]                 smlh_ts_data_rate;              // Bit 0 = 1, generation 1 (2.5 Gb/s) data rate supported
wire                          smlh_ts_speed_change;           // detected a speed change in the TS's
wire                          smlh_ts_auto_change;            // RMLH indicates receiver received TS ordered set with the autonomous change bit set
                                                              // Bit 1 = 1, generation 2 (5   Gb/s) data rate supported.
wire                          smlh_all_lanid_identical;       // 1, all lanes have identical data_rate/auto_chg identifiers
wire    [(NL*5)-1:0]          smseq_ts_data_rate_bus;
wire    [NL-1:0]              smseq_ts_speed_change_bus;
wire    [NL-1:0]              smseq_ts_auto_change_bus;
wire                          smlh_ts_spd_chg_rcvd_clr;
wire    [NL-1:0]              smseq_inskip_rcv_bus;
wire                          ltssm_in_hotrst_dis_entry;
wire                          ltssm_lane_flip_ctrl_chg_pulse;
wire    [NL*TS_0_WD-1:0]      eqctl_rev_eqctl_eqts_info_ts0;   // Equalization Information for Symbols 1-4 of EQ TSs and Gen6 TS0s
wire                          ltssm_captured_ts_data_rate_g6;
wire                          ltssm_perform_eq_for_lpbk;
wire                          ltssm_g6_not_cfg_hotr;
wire                          ltssm_g6_not_cfg_hotr_rcvrcfg;
wire                          ltssm_g6_not_rcvridle;
wire    [NL*EQTS_WD-1:0]      eqctl_rev_eqctl_eqts_info;       // Equalization Information for Symbols 6-9 of EQ TSs and Gen3 TSs
wire    [NL*EQTS_WD-1:0]      smseq_eqts_info;                 // concatenation of symbols {9,8,7,6} in current TS
wire    [NL*EQTS_WD-1:0]      eqctl_rev_smlh_eqts_info;        // concatenation of symbols {9,8,7,6} in current TS
wire    [NL*PCNT_WD-1:0]      smseq_ts_rcvd_s6s9_pcnt;         // persistency count on symbols 6-9
wire    [NL*PCNT_WD-1:0]      eqctl_rev_smlh_ts_rcvd_s6s9_pcnt;// persistency count on symbols 6-9
wire    [NL-1:0]              smseq_8_st_ts2_s6_rcvd;          // 8 consecutive standard TS2 rcvd with identical sym 6
wire    [NL*8-1:0]            smseq_g3_error_count;
wire    [4:0]                 ltssm_timer_24ms_cnt;
wire                          ltssm_in_rcvrylock;
wire                          ltssm_in_detectquiet;
wire                          ltssm_in_compliance;
wire    [3:0]                 ltssm_gen3_compliance_tx_pset;
wire                          ltssm_gen3_compliance_tx_pset_v;
wire                          ltssm_captured_ts_data_rate_g3;
wire                          ltssm_captured_ts_data_rate_g5;
wire                          auto_eq_phase_flag;
wire                          soft_eq_phase_flag;
wire                          redo_eq_phase_flag;
wire                          ltssm_cmd_eqts;                  // Indicates current LTSSM command requires an EQ TS
wire                          ltssm_cmd_8geqts;                // sending 8GT EQ TS2 in Gen3 Speed
wire                          ltssm_cmd_16geqts;               // sending 16GT EQ TS2 in Gen4 Speed
wire                          ltssm_cmd_32geqts;               // sending 32GT EQ TS2 in Gen5 Speed
wire                          ltssm_noeq_nd;                   // no eq needed
wire    [1:0]                 ltssm_cmd_eqts_gen12;            // Indicates current LTSSM command requires an EQ TS from gen12 to gen5 because of skip eq
wire                          ltssm_precode_request;           // precode request
wire                          ltssm_cmd_eqredo;                // sending TS1 with Equalization Redo(TS1 Symbol6[7]=1) in Gen3 Speed
wire    [3:0]                 ltssm_start_equalization;        // bit i set: start equalization from phase "i", www: i=0 only supported for now
wire                          eqctl_8eqts1_rcvd;
wire                          eqctl_8eqts2_rcvd;
wire                          eqctl_any_8eqts1_rcvd;
wire                          eqctl_any_8eqts2_rcvd;
wire                          ltssm_eq_exit;
wire                          eqctl_8g4eqts1_rcvd;
wire                          eqctl_8g4eqts2_rcvd;
wire                          eqctl_any_8g4eqts1_rcvd;
wire                          eqctl_any_8g4eqts2_rcvd;
wire                          eqctl_2ects1_retimer_eq_ext0_rcvd; // 2 TS1 w/ Retimer Equalization Extend @Gen4 rate all lane in eq master
wire                          eqctl_8g5eqts1_rcvd;
wire                          eqctl_8g5eqts2_rcvd;
wire                          eqctl_any_8g5eqts1_rcvd;
wire                          eqctl_any_8g5eqts2_rcvd;
wire                          eqctl_precode_request;
wire                          eqctl_precode6_request;
wire                          eqctl_8g6eqts1_rcvd;
wire                          eqctl_8g6eqts2_rcvd;
wire                          eqctl_any_8g6eqts1_rcvd;
wire                          eqctl_any_8g6eqts2_rcvd;
wire    [3:0]                 eqctl_2ects1_rcvd;
wire    [3:0]                 eqctl_8ects1_rcvd;
wire                          eqctl_eq_req_ltx;
wire                          eqctl_eq_req_rtx;
wire                          eqctl_eq_done_wo_err;
wire                          eqctl_eq_done_w_err;
wire                          eqctl_ftune_rtx_done;            // fine tuning of remote transmitter done, eq.Phase2 (DC) or eq.Phase3(UC)

wire                          pre_eqctl_8eqts1_rcvd;
wire                          pre_eqctl_8eqts2_rcvd;
wire                          pre_eqctl_any_8eqts1_rcvd;
wire                          pre_eqctl_any_8eqts2_rcvd;
wire                          pre_eqctl_8g4eqts1_rcvd;
wire                          pre_eqctl_8g4eqts2_rcvd;
wire                          pre_eqctl_any_8g4eqts1_rcvd;
wire                          pre_eqctl_any_8g4eqts2_rcvd;
wire                          pre_eqctl_8g5eqts1_rcvd;
wire                          pre_eqctl_8g5eqts2_rcvd;
wire                          pre_eqctl_any_8g5eqts1_rcvd;
wire                          pre_eqctl_any_8g5eqts2_rcvd;
wire                          pre_eqctl_8g6eqts1_rcvd;
wire                          pre_eqctl_8g6eqts2_rcvd;
wire                          pre_eqctl_any_8g6eqts1_rcvd;
wire                          pre_eqctl_any_8g6eqts2_rcvd;
wire                          pre_eqctl_2ects1_retimer_eq_ext0_rcvd; // 2 TS1 w/ Retimer Equalization Extend @Gen4 rate all lane in eq master
wire    [3:0]                 pre_eqctl_2ects1_rcvd;
wire    [3:0]                 pre_eqctl_8ects1_rcvd;
wire                          pre_eqctl_eq_req_ltx;
wire                          pre_eqctl_eq_req_rtx;
wire                          pre_eqctl_eq_done_wo_err;
wire                          pre_eqctl_eq_done_w_err;
wire                          pre_eqctl_ftune_rtx_done;            // fine tuning of remote transmitter done, eq.Phase2 (DC) or eq.Phase3(UC)

wire  [NL*EQTS_WD-1:0]        reg_eqctl_eqts_info;                 // Equalization Information for Symbols 6-9 of EQ TSs and Gen3 TSs
wire  [NL*TS_0_WD-1:0]        reg_eqctl_eqts_info_ts0;             // Equalization Information for Symbols 1-4 of EQ TS0s and Gen6 TS0s
wire  [NL-1:0]                pre_eqctl_mask_eieos;
wire  [NL-1:0]                pre_eqctl_2mask_eieos_pulse;
wire  [NL*TX_PSET_WD-1:0]     pre_eqctl_pset_ltx;

wire    [NL*TX_PSET_WD-1:0]   mac_phy_pset_rtx;
wire    [NL*TX_PSET_WD-1:0]   eqpa_rev_mac_phy_pset_rtx;
wire    [NL*RX_PSET_WD-1:0]   mac_phy_pset_lrx;
wire    [NL*RX_PSET_WD-1:0]   eqpa_rev_mac_phy_pset_lrx;
wire    [NL*TX_FSLF_WD-1:0]   mac_phy_fslf_rtx;
wire    [NL*TX_FSLF_WD-1:0]   eqpa_rev_mac_phy_fslf_rtx;
wire    [NL-1:0]              mac_phy_fslf_rtx_valid;
wire    [NL-1:0]              eqpa_rev_mac_phy_fslf_rtx_valid;
wire                          mac_phy_use_pset;
wire    [NL-1:0]              mac_phy_use_pset_bus;
wire    [NL-1:0]              eqpa_rev_mac_phy_use_pset_bus;
wire                          mac_phy_ftune_ltx;
wire    [NL-1:0]              mac_phy_lpbk_ftune_ltx;
wire    [NL-1:0]              eqpa_rev_mac_phy_lpbk_ftune_ltx;
wire    [NL*TX_COEF_WD-1:0]   mac_phy_coef_ltx;
wire    [NL*TX_COEF_WD-1:0]   eqpa_rev_mac_phy_coef_ltx;
wire    [NL-1:0]              mac_phy_pset_ltx_upd;
wire    [NL-1:0]              eqpa_rev_mac_phy_pset_ltx_upd;
wire    [NL-1:0]              mac_phy_coef_ltx_upd;
wire    [NL-1:0]              eqpa_rev_mac_phy_coef_ltx_upd;
wire    [NL-1:0]              mac_phy_timeout_rtx;
wire    [NL*TX_PSET_WD-1:0]   mac_phy_pset_ltx;
wire    [NL*TX_PSET_WD-1:0]   eqpa_rev_mac_phy_pset_ltx;
wire                          mac_phy_ftune_rtx;
wire    [NL-1:0]              mac_phy_reject_rtx;
wire    [NL-1:0]              eqpa_rev_mac_phy_reject_rtx;
wire    [NL-1:0]              mac_phy_accept_rtx;
wire    [NL-1:0]              eqpa_rev_mac_phy_accept_rtx;
wire    [NL*TX_COEF_WD-1:0]   mac_phy_coef_rtx;
wire    [NL*TX_COEF_WD-1:0]   eqpa_rev_mac_phy_coef_rtx;
wire    [NL-1:0]              phy_mac_accept_ltx;
wire    [NL-1:0]              eqpa_rev_phy_mac_accept_ltx;
wire    [NL-1:0]              phy_mac_reject_ltx;
wire    [NL-1:0]              eqpa_rev_phy_mac_reject_ltx;
wire    [NL-1:0]              phy_mac_fslf_ltx_valid;
wire    [NL-1:0]              eqpa_rev_phy_mac_fslf_ltx_valid;
wire    [NL*TX_FSLF_WD-1:0]   phy_mac_fslf_ltx;
wire    [NL*TX_FSLF_WD-1:0]   eqpa_rev_phy_mac_fslf_ltx;
wire    [NL*TX_COEF_WD-1:0]   phy_mac_coef_ltx;
wire    [NL*TX_COEF_WD-1:0]   eqpa_rev_phy_mac_coef_ltx;
wire    [NL*TX_PSET_WD-1:0]   phy_mac_pset_rtx;
wire    [NL*TX_PSET_WD-1:0]   eqpa_rev_phy_mac_pset_rtx;
wire    [NL*TX_COEF_WD-1:0]   phy_mac_coef_rtx;
wire    [NL*TX_COEF_WD-1:0]   eqpa_rev_phy_mac_coef_rtx;
wire    [NL-1:0]              phy_mac_ftune_rtx_done;
wire    [NL-1:0]              eqpa_rev_phy_mac_ftune_rtx_done;
wire    [NL-1:0]              phy_mac_ftune_rtx_optimal;
wire    [NL-1:0]              eqpa_rev_phy_mac_ftune_rtx_optimal;
wire    [NL-1:0]              phy_mac_coef_rtx_upd;
wire    [NL-1:0]              eqpa_rev_phy_mac_coef_rtx_upd;
wire    [NL-1:0]              phy_mac_pset_rtx_upd;
wire    [NL-1:0]              eqpa_rev_phy_mac_pset_rtx_upd;
// map individual bits of the port logic gen3 control register
wire [3:0]  cfg_gen3_eq_feedback_mode                = cfg_pl_gen3_eq_control[3:0];
wire        cfg_gen3_eq_p23_exit_mode                = cfg_pl_gen3_eq_control[4];
wire        cfg_gen3_eq_p23_eval_timeout_2ms_disable = cfg_pl_gen3_eq_control[5];
wire [15:0] cfg_gen3_eq_pset_req_vector              = cfg_pl_gen3_eq_control[21:6];
wire        cfg_gen3_eq_fom_include_init_eval        = cfg_pl_gen3_eq_control[22];
wire        cfg_gen3_eq_pset_req_as_coef             = cfg_pl_gen3_eq_control[23];
wire        cfg_gen3_lower_rate_eq_redo_enable       = cfg_pl_gen3_eq_control[25];
wire [2:0]  cfg_gen3_eq_req_num                      = cfg_pl_gen3_eq_control[28:26];
wire        cfg_gen3_support_finite_eq_req           = cfg_pl_gen3_eq_control[29];
wire        cfg_gen3_eq_p23_eval_2ms_extend          = cfg_pl_gen3_eq_control[30]; 
wire [3:0]  cfg_gen4_eq_feedback_mode                = cfg_pl_gen4_eq_control[3:0];
wire        cfg_gen4_eq_p23_exit_mode                = cfg_pl_gen4_eq_control[4];
wire        cfg_gen4_eq_p23_eval_timeout_2ms_disable = cfg_pl_gen4_eq_control[5];
wire [15:0] cfg_gen4_eq_pset_req_vector              = cfg_pl_gen4_eq_control[21:6];
wire        cfg_gen4_eq_fom_include_init_eval        = cfg_pl_gen4_eq_control[22];
wire        cfg_gen4_eq_pset_req_as_coef             = cfg_pl_gen4_eq_control[23];
wire        cfg_gen4_eq_p23_eval_2ms_extend          = cfg_pl_gen4_eq_control[25]; 
wire [3:0]  cfg_gen5_eq_feedback_mode                = cfg_pl_gen5_eq_control[3:0];
wire        cfg_gen5_eq_p23_exit_mode                = cfg_pl_gen5_eq_control[4];
wire        cfg_gen5_eq_p23_eval_timeout_2ms_disable = cfg_pl_gen5_eq_control[5];
wire [15:0] cfg_gen5_eq_pset_req_vector              = cfg_pl_gen5_eq_control[21:6];
wire        cfg_gen5_eq_fom_include_init_eval        = cfg_pl_gen5_eq_control[22];
wire        cfg_gen5_eq_pset_req_as_coef             = cfg_pl_gen5_eq_control[23];
wire        cfg_gen5_eq_p23_eval_2ms_extend          = cfg_pl_gen5_eq_control[25]; 
wire [3:0]  cfg_gen6_eq_feedback_mode                = cfg_pl_gen6_eq_control[3:0];
wire        cfg_gen6_eq_p23_exit_mode                = cfg_pl_gen6_eq_control[4];
wire        cfg_gen6_eq_p23_eval_timeout_2ms_disable = cfg_pl_gen6_eq_control[5];
wire [15:0] cfg_gen6_eq_pset_req_vector              = cfg_pl_gen6_eq_control[21:6];
wire        cfg_gen6_eq_fom_include_init_eval        = cfg_pl_gen6_eq_control[22];
wire        cfg_gen6_eq_pset_req_as_coef             = cfg_pl_gen6_eq_control[23];
wire        cfg_gen6_eq_p23_eval_2ms_extend          = cfg_pl_gen6_eq_control[25]; 
wire [NL-1:0] eq_lanes_active = lpbk_eq ? lpbk_eq_lanes_active : ltssm_lanes_active;
wire        eqpa_ftune_rtx_optimal;
wire        int_eqpa_ftune_rtx_optimal;
wire        eqpa_fs_out_of_range;
wire        int_eqpa_fs_out_of_range;
wire        eqpa_use_pset_query_done;
wire        int_eqpa_use_pset_coef_map_done;
wire        ltssm_timeout24ms;
wire        eqpa_wait_rei_state;

assign int_eqpa_ftune_rtx_optimal      = eqpa_ftune_rtx_optimal;
assign int_eqpa_use_pset_coef_map_done = eqpa_use_pset_query_done;
assign int_eqpa_fs_out_of_range        = eqpa_fs_out_of_range;

wire [4:0]  cfg_gen3_eq_dcm_t_min_phase23            = cfg_fdbk_dirchange_control[4:0];
wire [4:0]  cfg_gen3_eq_dcm_n_evals                  = cfg_fdbk_dirchange_control[9:5];
wire [3:0]  cfg_gen3_eq_dcm_max_precursor_delta      = cfg_fdbk_dirchange_control[13:10];
wire [3:0]  cfg_gen3_eq_dcm_max_postcursor_delta     = cfg_fdbk_dirchange_control[17:14];
wire [4:0]  cfg_gen4_eq_dcm_t_min_phase23            = cfg_gen4_fdbk_dirchange_control[4:0];
wire [4:0]  cfg_gen4_eq_dcm_n_evals                  = cfg_gen4_fdbk_dirchange_control[9:5];
wire [3:0]  cfg_gen4_eq_dcm_max_precursor_delta      = cfg_gen4_fdbk_dirchange_control[13:10];
wire [3:0]  cfg_gen4_eq_dcm_max_postcursor_delta     = cfg_gen4_fdbk_dirchange_control[17:14];
wire [4:0]  cfg_gen5_eq_dcm_t_min_phase23            = cfg_gen5_fdbk_dirchange_control[4:0];
wire [4:0]  cfg_gen5_eq_dcm_n_evals                  = cfg_gen5_fdbk_dirchange_control[9:5];
wire [3:0]  cfg_gen5_eq_dcm_max_precursor_delta      = cfg_gen5_fdbk_dirchange_control[13:10];
wire [3:0]  cfg_gen5_eq_dcm_max_postcursor_delta     = cfg_gen5_fdbk_dirchange_control[17:14];
wire [4:0]  cfg_gen6_eq_dcm_t_min_phase23            = cfg_gen6_fdbk_dirchange_control[4:0];
wire [4:0]  cfg_gen6_eq_dcm_n_evals                  = cfg_gen6_fdbk_dirchange_control[9:5];
wire [3:0]  cfg_gen6_eq_dcm_max_precursor2_delta     = cfg_gen6_fdbk_dirchange_control[13:10];
wire [3:0]  cfg_gen6_eq_dcm_max_precursor_delta      = cfg_gen6_fdbk_dirchange_control[17:14];
wire [3:0]  cfg_gen6_eq_dcm_max_postcursor_delta     = cfg_gen6_fdbk_dirchange_control[21:18];
wire        cfg_gen3_eq_map_mode_prog                = cfg_pl_gen3_control[10];
wire        cfg_gen3_eq_phase23_rxeq_regardless_rxts = cfg_pl_gen3_control[9];
wire        cfg_gen3_eq_invreq_eval_diff_disable     = cfg_pl_gen3_control[8];
wire        cfg_gen3_dc_balance_disable              = cfg_pl_gen3_control[7];
wire        cfg_gen3_dllp_xmt_delay_disable          = cfg_pl_gen3_control[6];
wire        cfg_gen3_eq_disable                      = cfg_pl_gen3_control[5]; // jd66
wire        cfg_gen3_eq_phase01_rxeq_enable          = cfg_pl_gen3_control[4];
wire        cfg_gen3_eq_req_disable                  = cfg_pl_gen3_control[3];
wire        cfg_gen3_req_rst_eiec_disable            = cfg_pl_gen3_control[2];
wire        cfg_gen3_eq_phase23_disable              = cfg_pl_gen3_control[1];
wire        cfg_gen3_scrambler_disable               = cfg_pl_gen3_control[0]; // not used in smlh (used in xmlh/rmlh)
assign      smlh_ltssm_in_compliance                 = ltssm_in_compliance;
assign      smlh_ltssm_in_rcvrylock                  = ltssm_in_rcvrylock;
assign      smlh_ltssm_in_detectquiet                = ltssm_in_detectquiet;
assign      mac_phy_use_pset                         = eqpa_rev_mac_phy_use_pset_bus[0];
assign      pre_eqctl_pset_ltx                       = mac_phy_pset_ltx;
assign      smlh_gen3_error_count                    = smseq_g3_error_count;
wire        cfg_gen5_eq_phase23_rxeq_regardless_rxts = cfg_pl_gen5_control[4];
wire        cfg_gen5_usp_send_8gt_eq_ts2_disable     = cfg_pl_gen5_control[3];
wire        cfg_gen5_auto_eq_disable                 = cfg_pl_gen5_control[2];
wire        cfg_gen6_eq_phase23_rxeq_regardless_rxts = cfg_pl_gen6_control[4];
wire        cfg_gen6_usp_send_8gt_eq_ts2_disable     = cfg_pl_gen6_control[3];
wire        cfg_gen6_auto_eq_disable                 = cfg_pl_gen6_control[2];
wire        cfg_gen4_eq_phase23_rxeq_regardless_rxts = cfg_pl_gen4_control[4];
wire        cfg_gen4_usp_send_8gt_eq_ts2_disable     = cfg_pl_gen4_control[3];
wire        cfg_gen4_auto_eq_disable                 = cfg_pl_gen4_control[2];
wire        cfg_gen4_eq_phase01_rxeq_enable          = cfg_pl_gen4_control[1];
wire        cfg_gen4_eq_phase23_disable              = cfg_pl_gen4_control[0];
wire        cfg_gen5_eq_phase01_rxeq_enable          = cfg_pl_gen5_control[1];
wire        cfg_gen5_eq_phase23_disable              = cfg_pl_gen5_control[0];
wire        cfg_gen6_eq_phase01_rxeq_enable          = cfg_pl_gen6_control[1];
wire        cfg_gen6_eq_phase23_disable              = cfg_pl_gen6_control[0];
wire [5:0]  cfg_target_link_width                    = cfg_pl_multilane_control[5:0];
wire        cfg_directed_link_width_change           = cfg_pl_multilane_control[6];
wire        cfg_upconfigure_support                  = cfg_pl_multilane_control[7];
wire        cfg_reliability_link_width_change_enable = cfg_pl_multilane_control[8];

wire        cfg_gen3_eq_req_send_consecutive_eieos_for_pset_map = (current_data_rate == `GEN6_RATE) ? cfg_pl_gen6_eq_control[24] :
 (current_data_rate == `GEN5_RATE) ? cfg_pl_gen5_eq_control[24] :
                                                                                       (current_data_rate == `GEN4_RATE) ? cfg_pl_gen4_eq_control[24] : (current_data_rate == `GEN3_RATE) ? cfg_pl_gen3_eq_control[24] : 0;
wire        cfg_gen34_eq_phase23_rxeq_regardless_rxts           = (current_data_rate == `GEN6_RATE) ? cfg_gen6_eq_phase23_rxeq_regardless_rxts :
 (current_data_rate == `GEN5_RATE) ? cfg_gen5_eq_phase23_rxeq_regardless_rxts :
                                                                                       (current_data_rate == `GEN4_RATE) ? cfg_gen4_eq_phase23_rxeq_regardless_rxts : (current_data_rate == `GEN3_RATE) ? cfg_gen3_eq_phase23_rxeq_regardless_rxts : 0;

assign      ltssm_lpbk_master                        = lpbk_master;

assign      muxed_n_fts                              = current_n_fts;
assign      smlh_mcs_rcvd                            = smseq_mcs_rcvd;
assign      smlh_ltssm_in_pollconfig                 = ltssm_in_pollconfig;
assign      smlh_lanes_active                        = ltssm_lanes_active;
assign      ltssm_state_is_rcvrylock                 = (smlh_ltssm_state == S_RCVRY_LOCK);
assign      smlh_inskip_rcv                          = smlh_inskip_rcv_bus[0];
assign      int_directed_speed_change                = (link_any_8_ts1_spd_chg_1_rcvd & ~ltssm_clear_link) | ltssm_directed_speed_change;

wire   eqpa_timeout_1us_after_request;
wire   eqpa_v7_timeout_1us_after_request;
wire   eqpa_fom_rxeq_redardless_rxts;
wire   all_pset_coef_map_done;
assign all_pset_coef_map_done = &(~smlh_lanes_active | phy_mac_fslf_ltx_valid);
wire   smlh_margin_pipe_idle;
wire   smlh_in_rcvryspeed_predetect;

assign smlh_ltssm_in_hotrst_dis_entry = ltssm_in_hotrst_dis_entry;


assign smlh_ltssm_last = ltssm_last;

wire [55:0] ltssm_ts_alt_prot_info_i;
wire [55:0] ltssm_mod_ts_data_sent_i;
assign ltssm_ts_alt_prot_info = ltssm_ts_alt_prot_info_i;
assign ltssm_mod_ts_data_sent = ltssm_mod_ts_data_sent_i;

wire  [NL-1:0]     rxeqeval_rcvrlock;

wire  [NL-1:0]     tmp_mac_phy_rxeqeval;
assign mac_phy_rxeqeval = tmp_mac_phy_rxeqeval | rxeqeval_rcvrlock;

wire   cxl_mode_enable;              // Link is negotiated in CXL alternate protocol mode

wire       smlh_linkmode_req;        // LTSSM L0p Link Width Change Request
wire       smlh_linkmode_loc;        // LTSSM L0p Local (Link Initiated) Request
wire [4:0] smlh_linkmode;            // LTSSM L0p Requested Link Width

wire int_pm_smlh_entry_to_l0s;
wire int_pm_smlh_entry_to_l1;
wire int_pm_smlh_entry_to_l2;

assign int_pm_smlh_entry_to_l0s = pm_smlh_entry_to_l0s && (pl_protocol_cfg.spif_enable ? b_smlh_spif.s_lp_stall_ack : 1'b1);
assign int_pm_smlh_entry_to_l1  = pm_smlh_entry_to_l1 && (pl_protocol_cfg.spif_enable ? b_smlh_spif.s_lp_stall_ack : 1'b1);
assign int_pm_smlh_entry_to_l2  = pm_smlh_entry_to_l2 && (pl_protocol_cfg.spif_enable ? b_smlh_spif.s_lp_stall_ack : 1'b1);
// ----------------------------------------------------------------------------
// SMLH SPIF Interface Instantiation
// ----------------------------------------------------------------------------
wire       spif_smlh_req_retrain;        // Link Layer request to LTSSM to transition to Recovery on SPIF Interface
wire       spif_smlh_req_reset;          // Link Layer request to LTSSM to reset the link on SPIF Interface
wire       spif_smlh_req_linkerror;      // Link Layer request to LTSSM to bring the Link Down
wire       rx_smlh_in_l0;                // Early indication of LTSSM in L0 (receive path is active)
                                         // LTSSM is in R.Idle or Cfg.Idle the RX gets 4 NULL flits and may start receiving packets while TX is still transmitting 8 NULL flits
wire [6:0] cxl_prot_enable_s;            // {MLD, LOPT, PBR, VH, CACHE, MEM, IO}

// Gating VH bit with flit_mode_enable as there is an issue in LTSSM setting VH Support with 256B flit mode!!!
assign cxl_prot_enable_s = {ltssm_cxl_enable.cxl_mld_enabled, ltssm_cxl_enable.cxl_lopt_flit_enabled, ltssm_cxl_enable.cxl_pbr_flit_enabled, ltssm_cxl_enable.cxl_68B_flit_vh_enabled && !ltssm_flit_mode_enable, ltssm_cxl_enable.cache_enabled, ltssm_cxl_enable.mem_enabled, ltssm_cxl_enable.io_enabled};

smlh_spif
 u_smlh_spif (
  // Interfaces
    .b_smlh_spif                    ( b_smlh_spif               ),
  // Inputs
    .core_clk                       ( core_clk                  ),
    .core_rst_n                     ( core_rst_n                ),
    .device_type                    ( device_type               ),
    .cfg_no_eq_needed_enable        ( cfg_no_eq_needed_enable   ),
    .pm_smlh_entry_to_l0s           ( pm_smlh_entry_to_l0s      ),
    .pm_smlh_entry_to_l1            ( pm_smlh_entry_to_l1       ),
    .pm_smlh_entry_to_l2            ( pm_smlh_entry_to_l2       ),
    .smlh_data_rate                 ( pm_current_data_rate      ),
    .smlh_cclk_rate                 ( current_cclk_rate         ),
    .smlh_link_mode                 ( smlh_link_rxmode          ),
    .smlh_l0p_link_mode             ( smlh_l0p_link_mode        ),
    .smlh_ltssm_in_l0p              ( smlh_ltssm_in_l0p         ),
    .smlh_ltssm_l0p_ready           ( smlh_ltssm_l0p_ready      ),
    .smlh_link_eios_rcvd            ( smlh_xdlh_eios_rcvd       ),
    .smlh_link_tsos_rcvd            ( |smlh_ts_rcvd_pulse_bus   ),
    .smlh_ltssm_state               ( smlh_ltssm_state          ),
    .smlh_req_rst_not               ( smlh_req_rst_not          ),
    .smlh_link_up                   ( smlh_link_up              ),
    .smlh_in_l0                     ( smlh_in_l0_s              ),
    .smlh_rx_in_l0                  ( rx_smlh_in_l0             ),
    .smlh_in_l1                     ( smlh_in_l1                ),
    .smlh_in_l2                     ( smlh_in_l23               ),
    .smlh_in_retrain                ( smlh_link_in_training     ),
    .smlh_in_txl0s                  ( smlh_in_l0s               ),
    .smlh_in_rxl0s                  ( smlh_in_rl0s              ),
    .smlh_lpbk_master               ( ltssm_lpbk_master         ),
    .smlh_idle_hs_done              ( ltssm_idl_hs_done         ),
    .smlh_flit_mode_enable          ( ltssm_flit_mode_enable    ),
    .cxl_link_enable                ( cxl_link_enable           ),
    .cxl_prot_enable                ( cxl_prot_enable_s         ),
    .rasdp_linkdown                 ( rasdp_linkdown            ),
    .pm_pl_wake_ack                 ( pm_pl_wake_ack            ),
    .pm_pl_clk_req                  ( pm_pl_clk_req             ),
    .pm_pl_phyinl1                  ( pm_pl_phyinl1             ),
    .pm_pl_phyinl2                  ( pm_pl_phyinl2             ),
    .sdlh_linkmode_req              ( xdlh_smlh_link_req        ),
    .sdlh_linkmode_loc              ( xdlh_smlh_link_initiated  ),
    .sdlh_linkmode                  ( xdlh_smlh_link_width      ),
  // Outputs
    .pl_protocol_cfg                ( pl_protocol_cfg           ),
    .spif_smlh_in_l0                ( smlh_in_l0                ),
    .smlh_linkmode_req              ( smlh_linkmode_req         ),
    .smlh_linkmode_loc              ( smlh_linkmode_loc         ),
    .smlh_linkmode                  ( smlh_linkmode             ),
    .smlh_req_retrain               ( spif_smlh_req_retrain     ),
    .smlh_req_reset                 ( spif_smlh_req_reset       ),
    .smlh_req_linkerror             ( spif_smlh_req_linkerror   )
);
// ----------------------------------------------------------------------------

// -----------------------------------------------------------------------
// PM Link FSM
// -----------------------------------------------------------------------
pm_link_fsm
 u_pm_link_fsm
(
  .core_clk                     (core_clk                      ),
  .core_rst_n                   (core_rst_n                    ),
  .upstream_port                (cfg_upstream_port             ),
  .cfg_pl_l1_nowait_p1          (cfg_pl_l1_nowait_p1           ),
  .cfg_pm_clk_pm_en             (cfg_pm_clk_pm_en              ),
  .smlh_link_up                 (smlh_link_up                  ),
  .smlh_in_l0                   (smlh_in_l0                    ),
  .smlh_in_l0s                  (smlh_in_l0s                   ),
  .smlh_in_rl0s                 (smlh_in_rl0s                  ),
  .smlh_in_l0_l0s               (smlh_in_l0_l0s                ),
  .smlh_in_l1                   (smlh_in_l1                    ),
  .smlh_in_l1_p1                (smlh_in_l1_p1                 ),
  .smlh_in_l23                  (smlh_in_l23                   ),
  .smlh_link_in_training        (smlh_link_in_training         ),
  .smlh_cal_req_no_clk_gate     (1'b0                          ),
  .smlh_l123_eidle_timeout      (smlh_l123_eidle_timeout       ),
  .latched_rcvd_eidle_set       (latched_rcvd_eidle_set        ),
  .ltssm_txelecidle             (int_mac_phy_txelecidle        ),
  .pm_hold_exit_l1              (pm_hold_exit_l1               ),
  .pm_link_exit_l1              (pm_link_exit_l1               ),
  .pl_protocol_cfg              (pl_protocol_cfg               ),
  .pl_state_sts                 (b_smlh_spif.s_pl_state_sts    ),
  .splh_pm_req_l0s              (splh_pm_req_l0s               ),
  .splh_pm_req_l1               (splh_pm_req_l1                ),
  .splh_pm_req_l2               (splh_pm_req_l2                ),
  .pm_smlh_entry_to_l1          (pm_smlh_entry_to_l1           ),
  .pm_smlh_l1_exit              (pm_smlh_l1_exit               ),
  .pm_smlh_l23_exit             (pm_smlh_l23_exit              ),
  .pm_smlh_entry_to_l2          (pm_smlh_entry_to_l2           ),
  .pm_smlh_prepare4_l123        (pm_smlh_prepare4_l123         ),
  .pm_smlh_entry_to_l0s         (pm_smlh_entry_to_l0s          ),
  .pm_smlh_l0s_exit             (pm_smlh_l0s_exit              ),
  .pm_smlh_dllp_hs              (pm_smlh_dllp_hs               ),
  .pm_linkst_in_l0s             (pm_linkst_in_l0s              ),
  .pm_link_exit_l23             (pm_link_exit_l23              ),
  .pm_usp_link_state            (pm_usp_link_state             ),
  .pm_dsp_link_state            (pm_dsp_link_state             ),
  .pm_protocol_to_link_signals  (pm_protocol_to_link_signals   ),
  .pm_link_to_protocol_signals  (pm_link_to_protocol_signals   ) 
);

//LTSSM
smlh_ltssm

#(INST) u_smlh_ltssm (
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .cfg_comm_clk_config            (cfg_comm_clk_config),
    .xplh_smlh_req_rcvry            (xplh_smlh_req_rcvry),
    .cfg_flit_mode_enable           (cfg_flit_mode_enable),
    .cfg_pcie_cap_flit_mode_sup     (cfg_pcie_cap_flit_mode_sup),
    .cfg_flit_mode_dis              (cfg_flit_mode_dis),
    .xplh_xmlh_sof                  (xplh_xmlh_sof),
    .cfg_reciver_l0p_supported      (cfg_reciver_l0p_supported),
    .xdlh_smlh_link_req             (smlh_linkmode_req),
    .xdlh_smlh_link_width           (smlh_linkmode),
    .xdlh_smlh_link_initiated       (smlh_linkmode_loc),
    .rmlh_deskew_datastream_bus     (rmlh_deskew_datastream_bus),
    .rmlh_rplh_rxdata_link_width    (rmlh_rplh_rxdata_link_width),
    .spif_smlh_req_retrain          (spif_smlh_req_retrain),
    .spif_smlh_req_reset            (spif_smlh_req_reset),
    .cfg_pcie_slot_clk_config       (cfg_pcie_slot_clk_config),
    .cfg_cxl_port_enable_i          (cfg_cxl_port_enable),
    .cfg_cxl_port_vid               (cfg_cxl_port_vid),
    .cfg_cxl_retimers_pre_mismatched (cfg_cxl_retimers_pre_mismatched),
    .cfg_retimers_pre_detected      (cfg_retimers_pre_detected),
    .vlsm_almp_rx_req               (vlsm_almp_rx_req),
    .app_sris_mode                  (app_sris_mode),
    .xmlh_sris_enable               (xmlh_sris_enable),
    .pipe_regif_all_idle            (pipe_regif_all_idle),
    .cfg_rate_chg_mode              (cfg_rate_chg_mode),
    .cfg_pam4_restricted_levels_requirement (cfg_pam4_restricted_levels_requirement),
    .pam4_restricted_levels_wr_ack_pending (pam4_restricted_levels_wr_ack_pending),
    .cfg_ts2_lid_deskew             (cfg_ts2_lid_deskew),
    .cfg_support_part_lanes_rxei_exit (cfg_support_part_lanes_rxei_exit),
    .cfg_upstream_port              (cfg_upstream_port),
    .cfg_root_compx                 (cfg_root_compx),
    .cfg_n_fts                      (cfg_n_fts),
    .cfg_scrmb_dis                  (cfg_scramble_dis),
    .cfg_link_dis                   (cfg_link_dis),
    .cfg_select_deemph_mux_bus      (cfg_select_deemph_mux_bus),
    .cfg_lpbk_en                    (cfg_lpbk_en),
    .cfg_mux_lpbk_lanenum           (cfg_mux_lpbk_lanenum),
    .cfg_reset_assert               (cfg_reset_assert),
    .cfg_link_num                   (cfg_link_num),
    .cfg_forced_ltssm               (cfg_forced_link_state),
    .cfg_forced_ltssm_cmd           (cfg_forced_ltssm_cmd),

    .cfg_force_en                   (cfg_force_en),
    .cfg_fast_link_mode             (cfg_fast_link_mode),
    .cfg_l0s_supported              (cfg_l0s_supported),
    .cfg_link_capable               (cfg_link_capable),
    .cfg_ext_synch                  (cfg_ext_synch),
    .cfg_rxstandby_handshake_policy (cfg_rxstandby_handshake_policy),
    .cfg_por_phystatus_mode         (cfg_por_phystatus_mode),
    .cfg_p1_entry_policy            (cfg_p1_entry_policy),
    .cfg_gointo_cfg_state           (cdm_ras_des_direct_rcvry_idle_to_cfg),
    .cfg_link_retrain               (cfg_link_retrain),
    .cfg_pl_gen3_zrxdc_noncompl     (cfg_pl_gen3_zrxdc_noncompl),
    .cfg_gen3_eq_req_send_consecutive_eieos_for_pset_map (cfg_gen3_eq_req_send_consecutive_eieos_for_pset_map),
    .all_pset_coef_map_done         (all_pset_coef_map_done),
    .smlh_req_linkerror             (spif_smlh_req_linkerror),
    .app_init_rst                   (app_init_rst),
    .app_ltssm_enable               (app_ltssm_enable),

    // inputs from pm module
    .pm_smlh_entry_to_l0s           (int_pm_smlh_entry_to_l0s),
    .pm_smlh_entry_to_l1            (int_pm_smlh_entry_to_l1),
    .pm_smlh_entry_to_l2            (int_pm_smlh_entry_to_l2),
    .pm_smlh_prepare4_l123          (pm_smlh_prepare4_l123),
    .pm_smlh_dllp_hs                (pm_smlh_dllp_hs),
    .pm_smlh_l0s_exit               (pm_smlh_l0s_exit),
    .pm_smlh_l1_exit                (pm_smlh_l1_exit),
    .pm_smlh_l23_exit               (pm_smlh_l23_exit),

    .link_imp_lanes                                                               (link_imp_lanes),
    .link_next_link_mode                                                          (link_next_link_mode),
    .link_lanes_rcving                                                            (link_lanes_rcving),
    .link_latched_live_all_8_ts1_plinkn_planen_compl_rcv_0_rcvd                   (link_latched_live_all_8_ts1_plinkn_planen_compl_rcv_0_rcvd),
    .link_latched_live_all_8_ts1_plinkn_planen_lpbk1_rcvd                         (link_latched_live_all_8_ts1_plinkn_planen_lpbk1_rcvd),
    .link_latched_live_all_8_ts2_plinkn_planen_rcvd                               (link_latched_live_all_8_ts2_plinkn_planen_rcvd),
    .link_latched_live_all_8_ts_plinkn_planen_rcvd                                (link_latched_live_all_8_ts_plinkn_planen_rcvd),
    .link_latched_live_any_8_ts_plinkn_planen_rcvd                                (link_latched_live_any_8_ts_plinkn_planen_rcvd),
    .link_latched_live_any_8_ts_plinkn_planen_rcvd_bus                            (link_latched_live_any_8_ts_plinkn_planen_rcvd_bus),
    .link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_0_rcvd                   (link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_0_rcvd),
    .link_latched_live_any_8_ts1_plinkn_planen_lpbk1_rcvd                         (link_latched_live_any_8_ts1_plinkn_planen_lpbk1_rcvd),
    .link_latched_live_any_8_ts2_plinkn_planen_rcvd                               (link_latched_live_any_8_ts2_plinkn_planen_rcvd),
    .link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd             (link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd),
    .link_xmlh_1024_ts1_sent_after_any_1_ts_rcvd                                  (link_xmlh_1024_ts1_sent_after_any_1_ts_rcvd),
    .link_xmlh_16_ts2_sent_after_1_ts2_rcvd                                       (link_xmlh_16_ts2_sent_after_1_ts2_rcvd),
    .link_xmlh_16_ts2_sent_after_1_ts2_rcvd_noeies                                (link_xmlh_16_ts2_sent_after_1_ts2_rcvd_noeies),
    .link_xmlh_16_ts1_sent                                                        (link_xmlh_16_ts1_sent),
    .link_latched_live_all_2_ts1_dis1_rcvd                                        (link_latched_live_all_2_ts1_dis1_rcvd),
    .link_latched_live_all_2_ts1_lpbk1_rcvd                                       (link_latched_live_all_2_ts1_lpbk1_rcvd),
    .link_latched_live_all_2_ts1_lpbk1_ebth1_rcvd                                 (link_latched_live_all_2_ts1_lpbk1_ebth1_rcvd),
    .link_latched_live_all_2_ts1_lpbk1_tmcp1_rcvd                                 (link_latched_live_all_2_ts1_lpbk1_tmcp1_rcvd),
    .link_latched_live_any_2_ts1_apn_rcvd                                         (link_latched_live_any_2_ts1_apn_rcvd),
    .link_latched_live_any_2_ts1_apn_sym14_8_rcvd                                 (link_latched_live_any_2_ts1_apn_sym14_8_rcvd),
    .link_latched_live_any_2_ts2_apn_rcvd                                         (link_latched_live_any_2_ts2_apn_rcvd),
    .link_latched_live_all_8_ts2_apn_sym14_8_rcvd                                 (link_latched_live_all_8_ts2_apn_sym14_8_rcvd),
    .link_latched_live_all_2_ts2_apn_rcvd                                         (link_latched_live_all_2_ts2_apn_rcvd),
    .link_latched_live_all_2_ts2_apn_sym14_8_rcvd                                 (link_latched_live_all_2_ts2_apn_sym14_8_rcvd),
    .link_latched_all_2_ts1_lpbk1_compl_rcv_1_rcvd                                (link_latched_all_2_ts1_lpbk1_compl_rcv_1_rcvd),
    .link_any_2_ts1_linknmtx_planen_rcvd                                          (link_any_2_ts1_linknmtx_planen_rcvd),
    .link_any_1_ts1_plinkn_planen_first_rcvd_2_ts1_linknmtx_planen_same_lane_rcvd (link_any_1_ts1_plinkn_planen_first_rcvd_2_ts1_linknmtx_planen_same_lane_rcvd),
    .link_any_2_ts1_dis1_rcvd                                                     (link_any_2_ts1_dis1_rcvd),
    .link_latched_live_all_2_ts1_linkn_planen_rcvd                                (link_latched_live_all_2_ts1_linkn_planen_rcvd),
    .link_any_2_ts1_linkn_planen_rcvd                                             (link_any_2_ts1_linkn_planen_rcvd),
    .link_lane0_2_ts1_linkn_planen_rcvd                                           (link_lane0_2_ts1_linkn_planen_rcvd),
    .link_lane0_2_ts1_linknmtx_rcvd                                               (link_lane0_2_ts1_linknmtx_rcvd),
    .link_lane0_2_ts1_linknmtx_lanen_rcvd                                         (link_lane0_2_ts1_linknmtx_lanen_rcvd),
    .link_latched_live_all_2_ts1_linknmtx_rcvd                                    (link_latched_live_all_2_ts1_linknmtx_rcvd),
    .link_latched_live_all_2_ts1_linknmtx_lanen_rcvd                              (link_latched_live_all_2_ts1_linknmtx_lanen_rcvd),
    .link_latched_live_all_2_ts1_plinkn_planen_rcvd                               (link_latched_live_all_2_ts1_plinkn_planen_rcvd),
    .link_latched_live_lane0_2_ts1_lanen0_rcvd                                    (link_latched_live_lane0_2_ts1_lanen0_rcvd),
    .link_latched_live_all_2_ts1_linknmtx_lanenmtx_rcvd                           (link_latched_live_all_2_ts1_linknmtx_lanenmtx_rcvd),
    .link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd                  (link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd),
    .link_latched_live_any_2_ts1_lanendiff_linkn_rcvd                             (link_latched_live_any_2_ts1_lanendiff_linkn_rcvd),
    .link_any_2_ts2_rcvd                                                          (link_any_2_ts2_rcvd),
    .link_latched_live_all_2_ts2_linknmtx_lanenmtx_rcvd                           (link_latched_live_all_2_ts2_linknmtx_lanenmtx_rcvd),
    .link_latched_live_all_8_ts1_linknmtx_lanenmtx_rcvd                           (link_latched_live_all_8_ts1_linknmtx_lanenmtx_rcvd),
    .link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd                           (link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd),
    .link_latched_live_all_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd               (link_latched_live_all_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd),
    .link_latched_live_all_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd               (link_latched_live_all_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd),
    .link_latched_live_all_8_ts_linknmtx_lanenmtx_rcvd                            (link_latched_live_all_8_ts_linknmtx_lanenmtx_rcvd),
    .link_latched_live_all_8_ts2_linknmtx_lanenmtx_spd_chg_0_rcvd                 (link_latched_live_all_8_ts2_linknmtx_lanenmtx_spd_chg_0_rcvd),
    .link_latched_live_all_8_ts2_linknmtx_lanenmtx_g1_rate_rcvd                   (link_latched_live_all_8_ts2_linknmtx_lanenmtx_g1_rate_rcvd),
    .link_any_2_ts1_rcvd                                                          (link_any_2_ts1_rcvd),
    .link_latched_live_any_8_ts2_linknmtx_lanenmtx_dis_link_rcvd                  (link_latched_live_any_8_ts2_linknmtx_lanenmtx_dis_link_rcvd),
    .link_latched_live_any_8_ts2_linknmtx_lanenmtx_hot_reset_rcvd                 (link_latched_live_any_8_ts2_linknmtx_lanenmtx_hot_reset_rcvd),
    .link_latched_live_any_8_ts2_linknmtx_lanenmtx_loopback_rcvd                  (link_latched_live_any_8_ts2_linknmtx_lanenmtx_loopback_rcvd),
    .link_latched_live_any_8_ts1_spd_chg_0_rcvd_after_ts2_rcvd                    (link_latched_live_any_8_ts1_spd_chg_0_rcvd_after_ts2_rcvd),
    .link_latched_live_any_8_ts2_spd_chg_0_rcvd                                   (link_latched_live_any_8_ts2_spd_chg_0_rcvd),
    .link_latched_live_any_8_ts2_spd_chg_0_plinkn_rcvd                            (link_latched_live_any_8_ts2_spd_chg_0_plinkn_rcvd),
    .link_latched_live_all_8_ts1_linknmtx_lanenmtx_l0p_rcvd                       (link_latched_live_all_8_ts1_linknmtx_lanenmtx_l0p_rcvd),
    .link_latched_live_all_8_ts2_linknmtx_lanenmtx_l0p_rcvd                       (link_latched_live_all_8_ts2_linknmtx_lanenmtx_l0p_rcvd),
    .link_any_exact_2_ts_l0p_rcvd                                                 (link_any_exact_2_ts_l0p_rcvd),
    .link_xmlh_l0p_16_ts2_sent_after_1_ts2_rcvd                                   (link_xmlh_l0p_16_ts2_sent_after_1_ts2_rcvd),
    .link_xmlh_l0p_16_ts1_sent                                                    (link_xmlh_l0p_16_ts1_sent),
    .link_latched_live_all_ts1_spd_chg_0_rcvd                                     (link_latched_live_all_ts1_spd_chg_0_rcvd),
    .link_latched_live_any_ts2_rcvd                                               (link_latched_live_any_ts2_rcvd),
    .link_any_8_ts1_spd_chg_1_rcvd                                                (link_any_8_ts1_spd_chg_1_rcvd),
    .link_any_8_ts_spd_chg_1_data_rate                                            (link_any_8_ts_spd_chg_1_data_rate),
    .link_latched_live_all_ts1_not_ec_00b_rcvd                                    (link_latched_live_all_ts1_not_ec_00b_rcvd),
    .link_latched_live_all_ts1_ec_00b_rcvd                                        (link_latched_live_all_ts1_ec_00b_rcvd),
    .link_latched_live_all_ts1_ec_00b_spd_chg_same_as_dir_spd_chg_rcvd            (link_latched_live_all_ts1_ec_00b_spd_chg_same_as_dir_spd_chg_rcvd),
    .link_latched_live_all_spd_chg_rcvd_same_as_dir_spd_chg                       (link_latched_live_all_spd_chg_rcvd_same_as_dir_spd_chg),
    .link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd                  (link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd),
    .link_any_8_ts_linknmtx_lanenmtx_rcvd                                         (link_any_8_ts_linknmtx_lanenmtx_rcvd),
    .link_any_8_ts_linknmtx_lanenmtx_auto_chg_rcvd                                (link_any_8_ts_linknmtx_lanenmtx_auto_chg_rcvd),
    .link_ln0_8_ts2_linknmtx_lanenmtx_rcvd                                        (link_ln0_8_ts2_linknmtx_lanenmtx_rcvd),
    .link_ln0_8_ts2_linknmtx_lanenmtx_auto_chg_rcvd                               (link_ln0_8_ts2_linknmtx_lanenmtx_auto_chg_rcvd),
    .link_ln0_2_ts1_linknmtx_lanenmtx_auto_chg_rcvd                               (link_ln0_2_ts1_linknmtx_lanenmtx_auto_chg_rcvd),
    .link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_gtr_g1_rate_rcvd      (link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_gtr_g1_rate_rcvd),
    .link_latched_live_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd                  (link_latched_live_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd),
    .link_latched_live_any_1_ts_linknmtx_lanenmtx_rcvd                            (link_latched_live_any_1_ts_linknmtx_lanenmtx_rcvd),
    .link_latched_live_any_1_ts_linknmtx_lanenmtx_g1_rate_rcvd                    (link_latched_live_any_1_ts_linknmtx_lanenmtx_g1_rate_rcvd),
    .link_latched_live_any_8_std_ts2_spd_chg_1_rcvd                               (link_latched_live_any_8_std_ts2_spd_chg_1_rcvd),
    .link_latched_live_all_8_eq_ts2_spd_chg_1_rcvd                                (link_latched_live_all_8_eq_ts2_spd_chg_1_rcvd),
    .link_latched_live_all_8_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd                    (link_latched_live_all_8_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd),
    .link_any_8_eq_ts2_spd_chg_1_rcvd                                             (link_any_8_eq_ts2_spd_chg_1_rcvd),
    .link_any_8_8gteq_ts2_spd_chg_1_rcvd                                          (link_any_8_8gteq_ts2_spd_chg_1_rcvd),
    .link_any_8_16gteq_ts2_spd_chg_1_rcvd                                         (link_any_8_16gteq_ts2_spd_chg_1_rcvd),
    .link_any_8_32gteq_ts2_spd_chg_1_rcvd                                         (link_any_8_32gteq_ts2_spd_chg_1_rcvd),
    .link_pc6_rcvd                                                                (link_pc6_rcvd),
    .link_pc_rcvd                                                                 (link_pc_rcvd),
    .link_latched_live_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd                   (link_latched_live_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd),
    .link_latched_live_any_8_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd                    (link_latched_live_any_8_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd),
    .link_xmlh_32_ts2_spd_chg_1_sent                                              (link_xmlh_32_ts2_spd_chg_1_sent),
    .link_xmlh_128_ts2_spd_chg_1_sent                                             (link_xmlh_128_ts2_spd_chg_1_sent),
    .link_xmlh_16_ts2_sent_after_1_ts1_rcvd                                       (link_xmlh_16_ts2_sent_after_1_ts1_rcvd),
    .link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_rcvd                    (link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_rcvd),
    .link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd          (link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd),
    .link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_g1_rate_rcvd            (link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_g1_rate_rcvd),
    .link_any_2_ts1_hotreset1_rcvd                                                (link_any_2_ts1_hotreset1_rcvd),
    .link_any_2_ts1_linknmtx_lanenmtx_hotreset1_rcvd                              (link_any_2_ts1_linknmtx_lanenmtx_hotreset1_rcvd),
    .link_any_2_ts1_planen_rcvd                                                   (link_any_2_ts1_planen_rcvd),
    .link_any_2_ts1_lpbk1_rcvd                                                    (link_any_2_ts1_lpbk1_rcvd),
    .link_imp_2_ts1_lpbk1_rcvd                                                    (link_imp_2_ts1_lpbk1_rcvd),
    .link_latched_any_2_ts1_lpbk1_compl_rcv_1_rcvd                                (link_latched_any_2_ts1_lpbk1_compl_rcv_1_rcvd),
    .link_any_2_ts_rcvd                                                           (link_any_2_ts_rcvd),
    .link_1_ts_rcvd                                                               (link_1_ts_rcvd),
    .link_any_1_ts_rcvd                                                           (link_any_1_ts_rcvd),
    .link_any_1_ts2_rcvd                                                          (link_any_1_ts2_rcvd),
    .link_any_exact_1_ts_rcvd                                                     (link_any_exact_1_ts_rcvd),
    .link_any_exact_2_ts_rcvd                                                     (link_any_exact_2_ts_rcvd),
    .link_any_exact_4_ts_rcvd                                                     (link_any_exact_4_ts_rcvd),
    .link_any_exact_5_ts_rcvd                                                     (link_any_exact_5_ts_rcvd),
    .link_latched_live_all_2_ts1_rcvd                                             (link_latched_live_all_2_ts1_rcvd),
    .link_latched_ts_data_rate                                                    (link_latched_ts_data_rate),
    .link_latched_ts_data_rate_ever                                               (link_latched_ts_data_rate_ever),
    .link_latched_ts_spd_chg                                                      (link_latched_ts_spd_chg),
    .link_ts_data_rate                                                            (link_ts_data_rate),
    .link_ts_spd_chg                                                              (link_ts_spd_chg),
    .link_lpbk_ts_data_rate                                                       (link_lpbk_ts_data_rate),
    .link_latched_lpbk_ts_data_rate                                               (link_latched_lpbk_ts_data_rate),
    .link_lpbk_ts_deemphasis                                                      (link_lpbk_ts_deemphasis),
    .link_ts_nfts                                                                 (link_ts_nfts),
    .link_latched_live_all_ts_scrmb_dis                                           (link_latched_live_all_ts_scrmb_dis),
    .link_any_8_ts_auto_chg                                                       (link_any_8_ts_auto_chg),
    .link_latched_flitm_support                                                   (link_latched_flitm_support),
    .link_usp_sris_mode                                                           (link_usp_sris_mode),
    .link_latched_modts_support                                                   (link_latched_modts_support),
    .link_latched_skipeq_enable                                                   (link_latched_skipeq_enable),
    .link_any_2_ts1_link_num                                                      (link_any_2_ts1_link_num),
    .link_2_ts1_plinkn_planen_rcvd_upconf                                         (link_2_ts1_plinkn_planen_rcvd_upconf),
    .link_latched_ts_retimer_pre                                                  (link_latched_ts_retimer_pre),
    .link_latched_ts_two_retimers_pre                                             (link_latched_ts_two_retimers_pre),
    .link_latched_poll_config_ts_retimer_pre                                      (link_latched_poll_config_ts_retimer_pre),
    .link_latched_poll_config_ts_two_retimers_pre                                 (link_latched_poll_config_ts_two_retimers_pre),

    .xmtbyte_loe_2_ts1_ec_00b_sent                                                (xmtbyte_loe_2_ts1_ec_00b_sent),
    .xmtbyte_ts_pcnt                                                              (xmtbyte_ts_pcnt),
    .xmtbyte_1024_ts_sent                                                         (xmtbyte_1024_ts_sent),
    .xmtbyte_dis_link_sent                                                        (xmtbyte_dis_link_sent),

    .smlh_lanes_rcving              (smlh_lanes_rcving),
    .smlh_eidle_inferred            (smlh_eidle_inferred),
    .smlh_inskip_rcv                (smlh_inskip_rcv_bus),
    .smlh_ts_rcvd_pulse_bus         (smlh_ts_rcvd_pulse_bus),
    .smlh_sds_rcvd                  (smlh_sds_rcvd),
    .rplh_rcvd_idle                 (rplh_rcvd_idle),
    .rmlh_all_sym_locked            (rmlh_all_sym_locked),
    .rmlh_rcvd_eidle_set            (rmlh_rcvd_eidle_set),
    .act_rmlh_rcvd_eidle_set        (act_rmlh_rcvd_eidle_set),
    .rmlh_deskew_alignment_err      (rmlh_deskew_alignment_err),
    .rmlh_deskew_complete           (rmlh_deskew_complete),
    .rpipe_rxaligned                (rpipe_rxaligned),
    .rmlh_deskew_datastream         (rmlh_deskew_datastream),
    .rmlh_goto_recovery             (rmlh_goto_recovery),
    .rmlh_gen3_rcvd_4eidle_set      (rmlh_gen3_rcvd_4eidle_set),
    .act_rmlh_gen3_rcvd_4eidle_set  (act_rmlh_gen3_rcvd_4eidle_set),
    .rdlh_rcvd_dllp                 (rdlh_rcvd_dllp),
    .xdlh_smlh_goto_detect          (xdlh_smlh_goto_detect),
    .xdlh_smlh_start_link_retrain   (xdlh_smlh_start_link_retrain),
    .rtlh_req_link_retrain          (rtlh_req_link_retrain),
    .xmtbyte_ts1_sent               (xmtbyte_ts1_sent),
    .xmtbyte_ts2_sent               (xmtbyte_ts2_sent),
    .xmtbyte_idle_sent              (xmtbyte_idle_sent),
    .xmtbyte_eidle_sent             (xmtbyte_eidle_sent),
    .xmtbyte_2_compliance_ts1_sent  (xmtbyte_2_compliance_ts1_sent),
    .xmbyte_flit_data_stream        (xmbyte_flit_data_stream),
    .xmtbyte_l0p_linkwidth_changed  (xmtbyte_l0p_linkwidth_changed),
    .xmtbyte_l0p_state_in_upsize    (xmtbyte_l0p_state_in_upsize),
    .xmtbyte_eies_sent              (xmtbyte_eies_sent),
    .xmtbyte_fts_sent               (xmtbyte_fts_sent),
    .xmtbyte_skip_sent              (xmtbyte_skip_sent),
    .xmtbyte_cmd_is_data            (xmtbyte_cmd_is_data),

    .current_data_rate              (pm_current_data_rate_ltssm),
    .current_data_rate_pre          (pm_current_data_rate_pre),
    .current_powerdown              (current_powerdown),
    .phy_mac_rxelecidle             (rpipe_rxelecidle),
    .phy_mac_rxdetected             (rpipe_rxdetected),
    .phy_mac_rxdetect_done          (rpipe_rxdetect_done),
    .xmtbyte_txdetectrx_loopback    (xmtbyte_txdetectrx_loopback),
    .all_phystatus_deasserted       (rpipe_all_phystatus_deasserted),
    .phy_mac_rxstandbystatus_physic_lane (phy_mac_rxstandbystatus_physic_lane),
    .phy_mac_rxelecidle_physic_lane      (phy_mac_rxelecidle_physic_lane),
    .laneflip_lanes_active_physic_lane   (laneflip_lanes_active_physic_lane),
    .laneflip_set_rxstandby_physic_lane  (laneflip_set_rxstandby_physic_lane),
    .laneflip_mac_phy_rxstandby          (laneflip_mac_phy_rxstandby),
    .laneflip_pipe_turnoff_physic_lane   (laneflip_pipe_turnoff_physic_lane),
    .cfg_lane_en                    (cfg_lane_en),
    .rplh_pkt_start                 (rplh_pkt_start),
    .cfg_rxstandby_control          (cfg_rxstandby_control),
    .cfg_lut_ctrl                   (cfg_lut_ctrl),

    .cfg_compliance_de_emphasis     (cfg_compliance_de_emphasis),
    .cfg_directed_speed_change      (cfg_directed_speed_change),
    .cfg_enter_compliance           (cfg_enter_compliance),
    .cfg_enter_mod_compliance       (cfg_enter_mod_compliance),
    .cfg_gen2_n_fts                 (cfg_gen2_n_fts),
    .cfg_gen2_support               (cfg_gen2_support),
    .cfg_pcie_max_link_speed        (cfg_pcie_max_link_speed),
    .cfg_phy_txswing                (cfg_phy_txswing),
    .cfg_sel_de_emphasis            (cfg_sel_de_emphasis),
    .cfg_target_link_speed          (cfg_target_link_speed),
    .cfg_transmit_margin            (cfg_transmit_margin),
    .cfg_tx_compliance_rcv          (cfg_tx_compliance_rcv),
    .sticky_rst_n                   (sticky_rst_n),
    .eqctl_8eqts1_rcvd              (eqctl_8eqts1_rcvd),
    .eqctl_8eqts2_rcvd              (eqctl_8eqts2_rcvd),
    .eqctl_any_8eqts1_rcvd          (eqctl_any_8eqts1_rcvd),
    .eqctl_any_8eqts2_rcvd          (eqctl_any_8eqts2_rcvd),
    .eqctl_8g4eqts1_rcvd            (eqctl_8g4eqts1_rcvd),
    .eqctl_8g4eqts2_rcvd            (eqctl_8g4eqts2_rcvd),
    .eqctl_any_8g4eqts1_rcvd        (eqctl_any_8g4eqts1_rcvd),
    .eqctl_any_8g4eqts2_rcvd        (eqctl_any_8g4eqts2_rcvd),
    .eqctl_2ects1_retimer_eq_ext0_rcvd (eqctl_2ects1_retimer_eq_ext0_rcvd),
    .eqctl_8g5eqts1_rcvd            (eqctl_8g5eqts1_rcvd),
    .eqctl_8g5eqts2_rcvd            (eqctl_8g5eqts2_rcvd),
    .eqctl_any_8g5eqts1_rcvd        (eqctl_any_8g5eqts1_rcvd),
    .eqctl_any_8g5eqts2_rcvd        (eqctl_any_8g5eqts2_rcvd),
    .eqctl_precode_request          (eqctl_precode_request),
    .eqctl_precode6_request         (eqctl_precode6_request),
    .eqctl_8g6eqts1_rcvd            (eqctl_8g6eqts1_rcvd),
    .eqctl_8g6eqts2_rcvd            (eqctl_8g6eqts2_rcvd),
    .eqctl_any_8g6eqts1_rcvd        (eqctl_any_8g6eqts1_rcvd),
    .eqctl_any_8g6eqts2_rcvd        (eqctl_any_8g6eqts2_rcvd),
    .eqctl_2ects1_rcvd              (eqctl_2ects1_rcvd),
    .eqctl_8ects1_rcvd              (eqctl_8ects1_rcvd),
    .eqctl_ftune_rtx_done           (eqctl_ftune_rtx_done),
    .eqctl_eq_req_ltx               (eqctl_eq_req_ltx),
    .eqctl_eq_req_rtx               (eqctl_eq_req_rtx),
    .eqctl_eq_done_wo_err           (pre_eqctl_eq_done_wo_err),
    .eqctl_eq_done_w_err            (pre_eqctl_eq_done_w_err),
    .cfg_gen3_eq_phase01_rxeq_enable(cfg_gen3_eq_phase01_rxeq_enable),
    .cfg_gen3_eq_phase23_disable    (cfg_gen3_eq_phase23_disable),
    .cfg_gen3_eq_disable            (cfg_gen3_eq_disable),
    .cfg_gen3_dllp_xmt_delay_disable(cfg_gen3_dllp_xmt_delay_disable),
    .cfg_gen3_lower_rate_eq_redo_enable(cfg_gen3_lower_rate_eq_redo_enable),
    .cfg_perform_eq                 (cfg_perform_eq),
    .eqpa_ftune_rtx_optimal         (int_eqpa_ftune_rtx_optimal),
    .eqpa_use_pset_coef_map_done    (int_eqpa_use_pset_coef_map_done),
    .eqpa_fs_out_of_range           (int_eqpa_fs_out_of_range),
    .cfg_gen3_eq_p23_exit_mode      (cfg_gen3_eq_p23_exit_mode),
    .cfg_gen4_eq_phase01_rxeq_enable(cfg_gen4_eq_phase01_rxeq_enable),
    .cfg_gen4_eq_phase23_disable    (cfg_gen4_eq_phase23_disable),
    .cfg_gen4_auto_eq_disable       (cfg_gen4_auto_eq_disable),
    .cfg_gen4_usp_send_8gt_eq_ts2_disable(cfg_gen4_usp_send_8gt_eq_ts2_disable),
    .cfg_gen4_eq_p23_exit_mode      (cfg_gen4_eq_p23_exit_mode),
    .cfg_gen5_eq_phase01_rxeq_enable(cfg_gen5_eq_phase01_rxeq_enable),
    .cfg_gen5_eq_phase23_disable    (cfg_gen5_eq_phase23_disable),
    .cfg_gen6_eq_phase01_rxeq_enable(cfg_gen6_eq_phase01_rxeq_enable),
    .cfg_gen6_eq_phase23_disable    (cfg_gen6_eq_phase23_disable),
    .cfg_gen5_auto_eq_disable       (cfg_gen5_auto_eq_disable),
    .cfg_gen6_auto_eq_disable       (cfg_gen6_auto_eq_disable),
    .cfg_gen5_usp_send_8gt_eq_ts2_disable(cfg_gen5_usp_send_8gt_eq_ts2_disable),
    .cfg_gen6_usp_send_8gt_eq_ts2_disable(cfg_gen6_usp_send_8gt_eq_ts2_disable),
    .cfg_gen6_eq_p23_exit_mode      (cfg_gen6_eq_p23_exit_mode),
    .cfg_g6_tx_precode_req          (cfg_g6_tx_precode_req),
    .cfg_gen5_eq_p23_exit_mode      (cfg_gen5_eq_p23_exit_mode),
    .cfg_bypass_eq_enable           (cfg_bypass_eq_enable),
    .cfg_no_eq_needed_enable        (cfg_no_eq_needed_enable),
    .cfg_tx_precode_req             (cfg_tx_precode_req),
    .cfg_alt_protocol_enable        (cfg_alt_protocol_enable),
    .cfg_hw_autowidth_dis           (cfg_hw_autowidth_dis),
    .cfg_target_link_width          (cfg_target_link_width),
    .cfg_directed_link_width_change (cfg_directed_link_width_change),
    .cfg_upconfigure_support        (cfg_upconfigure_support),
    .cfg_reliability_link_width_change_enable(cfg_reliability_link_width_change_enable),
    .int_mac_phy_txelecidle         (int_mac_phy_txelecidle),
    .smlh_dl_active                 (smlh_dl_active),
    .pm_smlh_l1_2_latched           (pm_smlh_l1_2_latched),
    .pm_smlh_l1_n_latched           (pm_smlh_l1_n_latched),
    .cfg_l1sub_t_common_mode        (cfg_l1sub_t_common_mode),
    .phy_mac_phystatus              (phy_mac_phystatus),
    .cdm_ras_des_pm_entry_interval  (cdm_ras_des_pm_entry_interval),
    .cdm_ras_des_direct_poll_cmp_to_det (cdm_ras_des_direct_poll_cmp_to_det),
    .cdm_ras_des_direct_lpbk_slave_to_exit (cdm_ras_des_direct_lpbk_slave_to_exit),
    .cdm_ras_des_ltssm_stop         (cdm_ras_des_ltssm_stop),
    .cdm_ras_des_recovery_req       (cdm_ras_des_recovery_req),
    .cdm_ras_des_force_rxdetected_en (cdm_ras_des_force_rxdetected_en),
    .cdm_ras_des_force_rxdetected    (cdm_ras_des_force_rxdetected),
    .cdm_ras_des_ext_eq_to_factor   (cdm_ras_des_ext_eq_to_factor),
    .smlh_margin_pipe_idle          (smlh_margin_pipe_idle),
    .xmlh_sent_24_ts0_ec00          (xmlh_sent_24_ts0_ec00),
    .pm_current_powerdown_p1        (pm_current_powerdown_p1),
    .pm_current_powerdown_p0        (pm_current_powerdown_p0),
// ---------------------------------outputs ------------------------
    .ltssm_lpbk_entry_send_ts1      (ltssm_lpbk_entry_send_ts1),
    .ltssm_directed_speed_change    (ltssm_directed_speed_change),
    .ltssm_cmd                      (ltssm_cmd),
    .ltssm_cmd_eqts                 (ltssm_cmd_eqts),
    .ltssm_cmd_8geqts               (ltssm_cmd_8geqts),
    .ltssm_cmd_16geqts              (ltssm_cmd_16geqts),
    .ltssm_cmd_32geqts              (ltssm_cmd_32geqts),
    .ltssm_cmd_eqts0                (ltssm_cmd_eqts0),
    .ltssm_precoding6_on_latched    (smlh_precoding6_on_latched),
    .ltssm_dsp_g6_eq1_send_ec00     (ltssm_dsp_g6_eq1_send_ec00),
    .ltssm_noeq_nd                  (ltssm_noeq_nd),
    .ltssm_cmd_eqts_gen12           (ltssm_cmd_eqts_gen12),
    .ltssm_precode_request          (ltssm_precode_request),
    .ltssm_precoding_on             (smlh_precoding_on),
    .ltssm_deprecoding_on           (smlh_deprecode_on),
    .ltssm_precoding_on_latched     (smlh_precoding_on_latched),
    .ltssm_mod_ts_rcvd              ( ),
    .smlh_noeq_needed_rcvd          (smlh_noeq_needed_rcvd),
    .ltssm_cmd_eqredo               (ltssm_cmd_eqredo),
    .ltssm_start_equalization       (ltssm_start_equalization),
    .smlh_link_up_falling_edge      (smlh_link_up_falling_edge),
    .ltssm_ts_cnt_en                (ltssm_ts_cnt_en),
    .ltssm_ts_cnt_rst               (ltssm_ts_cnt_rst),
    .ltssm_in_pollconfig            (ltssm_in_pollconfig),
    .smlh_link_up                   (smlh_link_up),
    .smlh_req_rst_not               (smlh_req_rst_not),
    .smlh_scrambler_disable         (smlh_scrambler_disable),
    .smlh_training_rst_n            (smlh_training_rst_n),
    .smlh_link_disable              (smlh_link_disable),
    .clear_o                        (ltssm_clear),
    .clear_eqctl                    (ltssm_clear_eqctl),
    .clear_seq                      (ltssm_clear_seq),
    .clear_link                     (ltssm_clear_link),
    .ltssm_rcvr_err_rpt_en          (ltssm_rcvr_err_rpt_en),
    .ltssm_xlinknum                 (ltssm_xlinknum),
    .ltssm_xk237_4lannum            (ltssm_xk237_4lannum),
    .ltssm_xk237_4lnknum            (ltssm_xk237_4lnknum),
    .ltssm_ts_cntrl                 (ltssm_ts_cntrl),
    .ltssm_flit_mode_enable_w_lpbk  (ltssm_flit_mode_enable), // both sides agreed
    .ltssm_flit_mode_enable_modules (ltssm_flit_mode_enable_modules), // both sides agreed
    .ltssm_flit_mode_tx             (ltssm_flit_mode_tx),        // for TX
    .ltssm_idl_hs_done              (ltssm_idl_hs_done),
    .ltssm_cmd_compliance_ts1       (ltssm_cmd_compliance_ts1),
    .ltssm_compliance_set_num       (ltssm_compliance_set_num),
    .smlh_l0p_update                (smlh_l0p_update),
    .smlh_l0p_next_link_mode        (smlh_l0p_next_link_mode),
    .smlh_l0p_link_mode             (smlh_l0p_link_mode),
    .ltssm_l0p_lanes_active         (ltssm_l0p_lanes_active),
    .ltssm_l0p_last_lanes_active    (ltssm_l0p_last_lanes_active),
    .ltssm_l0p_cmd                  (ltssm_l0p_cmd),
    .ltssm_l0p_cmd_4_eieos_req      (ltssm_l0p_cmd_4_eieos_req),
    .smlh_l0p_capable               (smlh_l0p_capable),
    .smlh_ltssm_in_l0p              (smlh_ltssm_in_l0p),
    .smlh_ltssm_in_l0p_upsize       (smlh_ltssm_in_l0p_upsize),
    .smlh_ltssm_l0p_ready           (smlh_ltssm_l0p_ready),
    .smlh_flit_error_link_widh      (smlh_flit_error_link_widh),
    .smlh_xdlh_eios_rcvd            (smlh_xdlh_eios_rcvd),
    .smlh_pm_state_trans1_flag      (smlh_pm_state_trans1_flag),
    .smlh_pm_state_trans2_flag      (smlh_pm_state_trans2_flag),
    .ltssm_mod_ts                   (ltssm_mod_ts),
    .ltssm_mod_ts_rx                (ltssm_mod_ts_rx),
    .ltssm_ts_alt_protocol          (ltssm_ts_alt_protocol),
    .ltssm_no_idle_need_sent        (ltssm_no_idle_need_sent),
    .ltssm_ts_alt_prot_info         (ltssm_ts_alt_prot_info_i),
    .ltssm_mod_ts_data_sent         (ltssm_mod_ts_data_sent_i),
    .ltssm_cxl_enable               (ltssm_cxl_enable),
    .cxl_sh_bypass                  (cxl_sh_bypass),
    .cxl_io_throttle_enable         (cxl_io_throttle_enable),
    .ltssm_cxl_mod_ts_phase1_rcvd   (ltssm_cxl_mod_ts_phase1_rcvd),
    .ltssm_cxl_retimers_pre_mismatched (ltssm_cxl_retimers_pre_mismatched),
    .ltssm_cxl_flexbus_phase2_mismatched (ltssm_cxl_flexbus_phase2_mismatched),
    .cxl_mode_enable                (cxl_mode_enable),
    .cxl_link_enable                (cxl_link_enable),
    .ltssm_cxl_ll_mod               (ltssm_cxl_ll_mod),
    .ltssm_ap_success               (ltssm_ap_success),
    .ltssm_lanes_active             (ltssm_lanes_active),
    .lpbk_eq_lanes_active           (lpbk_eq_lanes_active),
    .lpbk_eq                        (lpbk_eq),
    .lpbk_eq_n_lut_pset             (lpbk_eq_n_lut_pset),
    .smlh_no_turnoff_lanes          (smlh_no_turnoff_lanes),
    .lpbk_master                    (lpbk_master),
    .deskew_lanes_active            (deskew_lanes_active),
    .smlh_lnknum_match_dis          (smlh_lnknum_match_dis),
    .smlh_ltssm_state               (smlh_ltssm_state),
    .smlh_ltssm_state_wire          (smlh_ltssm_state_wire),
    .ltssm_next                     (smlh_ltssm_next),
    .ltssm_last                     (ltssm_last),
    .ltssm_powerdown                (ltssm_powerdown),
    .smlh_in_l0                     (smlh_in_l0_s),
    .rx_smlh_in_l0                  (rx_smlh_in_l0),
    .smlh_in_l0s                    (smlh_in_l0s),
    .smlh_in_rl0s                   (smlh_in_rl0s),
    .smlh_in_l1                     (smlh_in_l1),
    .smlh_in_l1_p1                  (smlh_in_l1_p1),
    .smlh_in_l23                    (smlh_in_l23),
    .smlh_l123_eidle_timeout        (smlh_l123_eidle_timeout),
    .smlh_pm_latched_eidle_set      (latched_rcvd_eidle_set),
    .ltssm_in_lpbk                  (ltssm_in_lpbk),
    .ltssm_in_training              (smlh_link_in_training),
    .ltssm_eidle_cnt                (ltssm_eidle_cnt),
    .l0s_state                      (l0s_state),
    .smlh_bw_mgt_status             (smlh_bw_mgt_status),
    .smlh_link_auto_bw_status       (smlh_link_auto_bw_status),
    .smlh_link_mode                 (smlh_link_mode),
    .smlh_link_rxmode               (smlh_link_rxmode),
    .latched_ts_nfts                (latched_ts_nfts),
    .smlh_do_deskew                 (smlh_do_deskew),
    .mac_phy_rate                   (mac_phy_rate),
    .mac_phy_rxstandby              (mac_phy_rxstandby),
    .smlh_set_rxstandby             (smlh_set_rxstandby),
    .ltssm_ts_data_rate             (ltssm_ts_data_rate),
    .ltssm_ts_data_rate_eg6         (ltssm_ts_data_rate_eg6),
    .latched_ts_data_rate_eg6       (latched_ts_data_rate_eg6),
    .ltssm_g6_not_cfg_hotr          (ltssm_g6_not_cfg_hotr),
    .ltssm_g6_not_cfg_hotr_rcvrcfg  (ltssm_g6_not_cfg_hotr_rcvrcfg),
    .ltssm_g6_not_rcvridle          (ltssm_g6_not_rcvridle),
    .ltssm_core_rst_n_release_pulse (smlh_core_rst_n_release_pulse),
    .ltssm_dir_spd_chg_rising_edge  (smlh_dir_spd_chg_rising_edge),
    .ltssm_ts_speed_change          (ltssm_ts_speed_change),
    .mac_phy_txdeemph               (mac_phy_txdeemph),
    .mac_phy_txmargin               (mac_phy_txmargin),
    .mac_phy_txswing                (mac_phy_txswing),
    .smlh_clr_enter_compliance      (smlh_clr_enter_compliance),
    .smlh_tx_margin_rst             (smlh_tx_margin_rst),
    .smlh_successful_spd_negotiation(smlh_successful_spd_negotiation),
    .ltssm_ts_spd_chg_rcvd_clr      (smlh_ts_spd_chg_rcvd_clr),
    .mac_phy_pam4_restricted_levels (mac_phy_pam4_restricted_levels),
    .rxeqeval_rcvrlock              (rxeqeval_rcvrlock),
    .ltssm_ts_auto_change           (ltssm_ts_auto_change),
    .smlh_dir_linkw_chg_started     (smlh_dir_linkw_chg_started),
    .current_n_fts                  (current_n_fts),
    .auto_eq_phase_flag             (auto_eq_phase_flag),
    .soft_eq_phase_flag             (soft_eq_phase_flag),
    .redo_eq_phase_flag             (redo_eq_phase_flag),
    .smlh_eq_pending                (smlh_eq_pending),
    .smlh_usp_eq_pending            (smlh_usp_eq_pending),
    .smlh_auto_eq_dllp_blocking     (smlh_auto_eq_dllp_blocking),
    .usp_g3_eq_redo_executed_int    (usp_g3_eq_redo_executed_int),     // USP gen3 eq redo executed interrupt
    .usp_g4_eq_redo_executed_int    (usp_g4_eq_redo_executed_int),     // USP gen4 eq redo executed interrupt
    .usp_g5_eq_redo_executed_int    (usp_g5_eq_redo_executed_int),     // USP gen5 eq redo executed interrupt
//    .usp_g6_eq_redo_executed_int    (usp_g6_eq_redo_executed_int),     // USP gen6 eq redo executed interrupt
    .ltssm_captured_ts_data_rate_g6 (ltssm_captured_ts_data_rate_g6),
    .ltssm_perform_eq_for_lpbk_g6   (ltssm_perform_eq_for_lpbk_g6),
    .ltssm_in_lpbk_wo_l0            (ltssm_in_lpbk_wo_l0),
    .ltssm_cfg_to_lpbk_active_master_g6 (ltssm_cfg_to_lpbk_active_master_g6),
    .ltssm_perform_eq_for_lpbk      (ltssm_perform_eq_for_lpbk),
    .smlh_in_l0_l0s                 (smlh_in_l0_l0s),
    .latched_ts_data_rate           (latched_ts_data_rate),
    .active_nb                      (active_nb),
    .active_nb_wire                 (active_nb_wire),
    .active_nb_gen34                (active_nb_gen34),
    .ltssm_gen3_compliance_tx_pset  (ltssm_gen3_compliance_tx_pset),
    .ltssm_gen3_compliance_tx_pset_v(ltssm_gen3_compliance_tx_pset_v),
    .ltssm_in_lpbkentry             (ltssm_in_lpbkentry),
    .ltssm_in_compliance            (ltssm_in_compliance),
    .ltssm_in_rcvrylock             (ltssm_in_rcvrylock),
    .ltssm_in_detectquiet           (ltssm_in_detectquiet),
    .ltssm_cmd_send_eieos_for_pset_map (ltssm_cmd_send_eieos_for_pset_map),
    .ltssm_usp_eq_redo              (ltssm_usp_eq_redo),
    .ltssm_blockaligncontrol        (smlh_blockaligncontrol),
    .ltssm_timeout24ms              (ltssm_timeout24ms),
    .ltssm_timer_24ms_cnt           (ltssm_timer_24ms_cnt),
    .ltssm_state_rcvry_eq           (smlh_ltssm_state_rcvry_eq),
    .ltssm_captured_ts_data_rate_g3 (ltssm_captured_ts_data_rate_g3),
    .ltssm_captured_ts_data_rate_g5 (ltssm_captured_ts_data_rate_g5),
    .smlh_retimer_pre_detected      (smlh_retimer_pre_detected),
    .smlh_two_retimers_pre_detected (smlh_two_retimers_pre_detected),
    .ltssm_gen4_compliance_jmp      (ltssm_gen4_compliance_jmp),
    .ltssm_gen6_compliance_tp       (ltssm_gen6_compliance_tp),
    .smlh_crosslink_resolution      (smlh_crosslink_resolution),
    .ltssm_lanes_active_d           (int_lpbk_slave_lut),        //lane under test for lpbk slave
    .ltssm_in_hotrst_dis_entry      (ltssm_in_hotrst_dis_entry),
    .smlh_keep_rcvrylock_lane       (smlh_keep_rcvrylock_lane),
    .smlh_debug_info_ei             (smlh_debug_info_ei),
    .smlh_lane_flip_ctrl            (smlh_lane_flip_ctrl),
    .latched_flip_ctrl              (latched_flip_ctrl),
    .lpbk_lane_under_test           (lpbk_lane_under_test),
    .ltssm_lane_flip_ctrl_chg_pulse (ltssm_lane_flip_ctrl_chg_pulse),
    .ltssm_lane_flip_ctrl           (ltssm_lane_flip_ctrl)
    ,
    .ltssm_timeout10ms              (ltssm_timeout10ms),
    .smlh_rx_rcvry_req              (smlh_rx_rcvry_req),
    .smlh_timeout_nfts              (smlh_timeout_nfts),
    .smlh_l0_to_recovery            (smlh_l0_to_recovery),
    .smlh_l1_to_recovery            (smlh_l1_to_recovery),
    .smlh_rcv_eios_when_l0s_unsprt  (smlh_rcv_eios_when_l0s_unsprt),
    .smlh_deskew_uncomplete_err     (smlh_deskew_uncomplete_err),
    .smlh_spd_change                (smlh_spd_change),
    .smlh_lwd_change                (smlh_lwd_change),
    .smlh_ltssm_variable            (smlh_ltssm_variable)
    ,
    .init_eq_pending                (init_eq_pending)
    ,
    .init_eq_pending_g4             (init_eq_pending_g4)
    ,
    .init_eq_pending_g5             (init_eq_pending_g5)
    ,
    .init_eq_pending_g6             (init_eq_pending_g6)
    ,
    .fast_time_1ms                  (smlh_fast_time_1ms),
    .fast_time_2ms                  (smlh_fast_time_2ms),
    .fast_time_3ms                  (smlh_fast_time_3ms),
    .fast_time_10ms                 (smlh_fast_time_10ms),
    .fast_time_12ms                 (smlh_fast_time_12ms),
    .fast_time_24ms                 (smlh_fast_time_24ms),
    .fast_time_32ms                 (smlh_fast_time_32ms),
    .fast_time_48ms                 (smlh_fast_time_48ms),
    .fast_time_64ms                 (smlh_fast_time_64ms),
    .fast_time_100ms                (smlh_fast_time_100ms)
    ,
    .smlh_in_rcvryspeed_predetect   (smlh_in_rcvryspeed_predetect)
); //smlh_ltssm

assign eqctl_rev_rxdata_dv              = rpipe_rxaligned;
assign eqctl_rev_smlh_eqts_info         = smseq_eqts_info;
assign eqctl_rev_smlh_ts0_rcvd_bus      = smseq_ts0_rcvd_bus;
assign eqctl_rev_smlh_ts1_rcvd_bus      = smseq_ts1_rcvd_bus;
assign eqctl_rev_smlh_ts2_rcvd_bus      = smseq_ts2_rcvd_bus;
assign eqctl_rev_smlh_ts_rcvd_s6s9_pcnt = smseq_ts_rcvd_s6s9_pcnt;

reg cfg_upstream_port_d;

always @(posedge core_clk or negedge core_rst_n) begin: cfg_upstream_port_d_PROC
  if (!core_rst_n) begin
    cfg_upstream_port_d <= #`TP 0;
  end else begin
    cfg_upstream_port_d <= #`TP cfg_upstream_port;
  end
end // cfg_upstream_port_d_PROC

assign csr_mac_phy_coef_rtx = ((cfg_upstream_port_d && smlh_ltssm_state == S_RCVRY_EQ2) || (~cfg_upstream_port_d && smlh_ltssm_state == S_RCVRY_EQ3)) ? mac_phy_coef_rtx : 0;

smlh_eqctl

#(INST) u_smlh_eqctl (
// ---- inputs ---------------
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .cfg_upstream_port              (cfg_upstream_port),
    .cfg_gen3_eq_req_send_consecutive_eieos_for_pset_map (cfg_gen3_eq_req_send_consecutive_eieos_for_pset_map),
    .cfg_gen34_eq_phase23_rxeq_regardless_rxts (cfg_gen34_eq_phase23_rxeq_regardless_rxts),
    .cfg_gen3_lower_rate_eq_redo_enable(cfg_gen3_lower_rate_eq_redo_enable),
    .cfg_block_local_detect_eq_problem  (cfg_block_local_detect_eq_problem),
    .cfg_gen3_eq_req_num            (cfg_gen3_eq_req_num),
    .cfg_gen3_support_finite_eq_req (cfg_gen3_support_finite_eq_req),
    .rxdata_dv                      (eqctl_rev_rxdata_dv),
    .rmlh_descrambled_eie_det       (rmlh_descrambled_eie_det),
    .smlh_eqts_info                 (eqctl_rev_smlh_eqts_info),
    .smlh_ts0_rcvd_bus              (eqctl_rev_smlh_ts0_rcvd_bus),
    .ltssm_dsp_g6_eq1_send_ec00     (ltssm_dsp_g6_eq1_send_ec00),
    .smlh_ts1_rcvd_bus              (eqctl_rev_smlh_ts1_rcvd_bus),
    .smlh_ts2_rcvd_bus              (eqctl_rev_smlh_ts2_rcvd_bus),
    .smlh_ts_rcvd_s6s9_pcnt         (eqctl_rev_smlh_ts_rcvd_s6s9_pcnt),
    .smlh_ts_info                   (smseq_ts_info_bus),
    .smlh_ltssm_state_wire          (smlh_ltssm_state_wire),
    .ltssm_lpbk_master              (ltssm_lpbk_master),
    .ltssm_state_last               (ltssm_last),
    .ltssm_cmd                      (ltssm_cmd),
    .ltssm_cmd_eqts                 (ltssm_cmd_eqts),
    .ltssm_cmd_send_eieos_for_pset_map (ltssm_cmd_send_eieos_for_pset_map),
    .ltssm_cmd_8geqts               (ltssm_cmd_8geqts),
    .ltssm_cmd_eqredo               (ltssm_cmd_eqredo),
    .smlh_link_up_falling_edge      (smlh_link_up_falling_edge),
    .ltssm_cmd_16geqts              (ltssm_cmd_16geqts),
    .ltssm_cmd_32geqts              (ltssm_cmd_32geqts),
    .ltssm_noeq_nd                  (ltssm_noeq_nd),
    .ltssm_cmd_eqts_gen12           (ltssm_cmd_eqts_gen12),
    .ltssm_precode_request          (ltssm_precode_request),
    .ltssm_precoding_on             (smlh_precoding_on),
    .ltssm_current_data_rate        (pm_current_data_rate_smlh_eq),
    .ltssm_captured_ts_data_rate_g3 (ltssm_captured_ts_data_rate_g3),
    .ltssm_captured_ts_data_rate_g5 (ltssm_captured_ts_data_rate_g5),
    .mac_phy_txswing                (mac_phy_txswing),
    .ltssm_start_equalization       (ltssm_start_equalization),
    .ltssm_lanes_active             (eq_lanes_active),
    .ltssm_quie_gua                 (1'b1), // www: to be connected to cpl_pending
    .ltssm_gen3_compliance_tx_pset  (ltssm_gen3_compliance_tx_pset),
    .ltssm_gen3_compliance_tx_pset_v(ltssm_gen3_compliance_tx_pset_v),
    .ltssm_clear                    (ltssm_clear_eqctl),
    .auto_eq_phase_flag             (auto_eq_phase_flag),
    .soft_eq_phase_flag             (soft_eq_phase_flag),
    .redo_eq_phase_flag             (redo_eq_phase_flag),
    .ltssm_ts_data_rate             (ltssm_ts_data_rate),
    .ltssm_ts_data_rate_eg6         (ltssm_ts_data_rate_eg6),
    .latched_ts_data_rate_eg6       (latched_ts_data_rate_eg6),
    .ltssm_captured_ts_data_rate_g6 (ltssm_captured_ts_data_rate_g6),
    .ltssm_perform_eq_for_lpbk      (ltssm_perform_eq_for_lpbk),
    .cfg_target_link_speed          (cfg_target_link_speed),
    .cfg_lec_pset_ltx               (cfg_lec_pset_ltx),
    .cfg_lec_pset_lrx               (cfg_lec_pset_lrx),
    .cfg_lec_pset_rtx               (cfg_lec_pset_rtx),
    .cfg_lec_pset_rrx               (cfg_lec_pset_rrx),
    .cfg_lec_g4_pset_ltx            (cfg_lec_g4_pset_ltx),
    .cfg_lec_g4_pset_lrx            (cfg_lec_g4_pset_lrx),
    .cfg_lec_g4_pset_rtx            (cfg_lec_g4_pset_rtx),
    .cfg_lec_g4_pset_rrx            (cfg_lec_g4_pset_rrx),
    .cfg_lec_g5_pset_ltx            (cfg_lec_g5_pset_ltx),
    .cfg_lec_g5_pset_lrx            (cfg_lec_g5_pset_lrx),
    .cfg_lec_g5_pset_rtx            (cfg_lec_g5_pset_rtx),
    .cfg_lec_g5_pset_rrx            (cfg_lec_g5_pset_rrx),
    .cfg_lec_g6_pset_ltx            (cfg_lec_g6_pset_ltx),
    .cfg_lec_g6_pset_lrx            (cfg_lec_g6_pset_lrx),
    .cfg_lec_g6_pset_rtx            (cfg_lec_g6_pset_rtx),
    .cfg_lec_g6_pset_rrx            (cfg_lec_g6_pset_rrx),
    .cfg_gen3_eq_disable            (cfg_gen3_eq_disable),
    .cfg_gen3_eq_req_disable        (cfg_gen3_eq_req_disable),
    .cfg_gen3_req_rst_eiec_disable  (cfg_gen3_req_rst_eiec_disable),
    .cfg_ls2_eq_req                 (cfg_ls2_eq_req),
    .cfg_gen3_eq_p23_exit_mode      (cfg_gen3_eq_p23_exit_mode),
    .cfg_gen4_eq_p23_exit_mode      (cfg_gen4_eq_p23_exit_mode),
    .cfg_gen5_eq_p23_exit_mode      (cfg_gen5_eq_p23_exit_mode),
    .cfg_gen6_eq_p23_exit_mode      (cfg_gen6_eq_p23_exit_mode),
    .eqpa_ftune_rtx_optimal         (eqpa_ftune_rtx_optimal),
    .eqpa_timeout_1us_after_request (eqpa_timeout_1us_after_request),
    .eqpa_fom_rxeq_redardless_rxts  (eqpa_fom_rxeq_redardless_rxts),
    .eqpa_wait_rei_state            (eqpa_wait_rei_state),
    .mac_phy_rxeqeval               (tmp_mac_phy_rxeqeval),
    .phy_mac_eq_req                 ({NL{1'b0}}), // www: to be connected to pinout
    .phy_mac_fslf_ltx               (eqpa_rev_phy_mac_fslf_ltx),
    .phy_mac_coef_ltx               (eqpa_rev_phy_mac_coef_ltx),
    .phy_mac_reject_ltx             (eqpa_rev_phy_mac_reject_ltx),
    .phy_mac_accept_ltx             (eqpa_rev_phy_mac_accept_ltx),
    .phy_mac_pset_rtx               (eqpa_rev_phy_mac_pset_rtx),
    .phy_mac_coef_rtx               (eqpa_rev_phy_mac_coef_rtx),
    .phy_mac_ftune_rtx_done         (eqpa_rev_phy_mac_ftune_rtx_done),
    .phy_mac_fslf_ltx_valid         (eqpa_rev_phy_mac_fslf_ltx_valid),
    .phy_mac_pset_rtx_upd           (eqpa_rev_phy_mac_pset_rtx_upd),
    .phy_mac_coef_rtx_upd           (eqpa_rev_phy_mac_coef_rtx_upd),
    .phy_mac_ftune_rtx_optimal      (phy_mac_ftune_rtx_optimal),
    .cdm_ras_des_eq_force_pset_ltx_en (cdm_ras_des_eq_force_pset_ltx_en),
    .cdm_ras_des_eq_force_usp_pset_ltx (cdm_ras_des_eq_force_usp_pset_ltx),
    .cdm_ras_des_eq_force_pset_ltx_en_g4 (cdm_ras_des_eq_force_pset_ltx_en_g4),
    .cdm_ras_des_eq_force_usp_pset_ltx_g4 (cdm_ras_des_eq_force_usp_pset_ltx_g4) ,
    .cdm_ras_des_eq_force_pset_ltx_en_g5 (cdm_ras_des_eq_force_pset_ltx_en_g5),
    .cdm_ras_des_eq_force_usp_pset_ltx_g5 (cdm_ras_des_eq_force_usp_pset_ltx_g5) ,
    .cdm_ras_des_eq_force_pset_ltx_en_g6 (cdm_ras_des_eq_force_pset_ltx_en_g6),
    .cdm_ras_des_eq_force_usp_pset_ltx_g6 (cdm_ras_des_eq_force_usp_pset_ltx_g6) ,
// ---- outputs ---------------
    .mac_phy_pset_ltx               (mac_phy_pset_ltx),
    .mac_phy_pset_lrx               (mac_phy_pset_lrx),
    .mac_phy_coef_ltx               (mac_phy_coef_ltx),
    .mac_phy_fslf_rtx               (mac_phy_fslf_rtx),
    .mac_phy_pset_rtx               (mac_phy_pset_rtx),
    .mac_phy_coef_rtx               (mac_phy_coef_rtx),
    .mac_phy_reject_rtx             (mac_phy_reject_rtx),
    .mac_phy_accept_rtx             (mac_phy_accept_rtx),
    .mac_phy_timeout_rtx            (mac_phy_timeout_rtx),
    .mac_phy_ftune_rtx              (mac_phy_ftune_rtx),
    .mac_phy_ftune_ltx              (mac_phy_ftune_ltx),
    .mac_phy_lpbk_ftune_ltx         (mac_phy_lpbk_ftune_ltx),
    .mac_phy_use_pset               (mac_phy_use_pset_bus),
    .mac_phy_fslf_rtx_valid         (mac_phy_fslf_rtx_valid),
    .mac_phy_pset_ltx_upd           (mac_phy_pset_ltx_upd),
    .mac_phy_coef_ltx_upd           (mac_phy_coef_ltx_upd),
    .eqctl_8eqts1_rcvd              (pre_eqctl_8eqts1_rcvd),
    .eqctl_8eqts2_rcvd              (pre_eqctl_8eqts2_rcvd),
    .eqctl_any_8eqts1_rcvd          (pre_eqctl_any_8eqts1_rcvd),
    .eqctl_any_8eqts2_rcvd          (pre_eqctl_any_8eqts2_rcvd),
    .ltssm_state_equalization_any_exit (ltssm_eq_exit),
    .eqctl_8g4eqts1_rcvd            (pre_eqctl_8g4eqts1_rcvd),
    .eqctl_8g4eqts2_rcvd            (pre_eqctl_8g4eqts2_rcvd),
    .eqctl_any_8g4eqts1_rcvd        (pre_eqctl_any_8g4eqts1_rcvd),
    .eqctl_any_8g4eqts2_rcvd        (pre_eqctl_any_8g4eqts2_rcvd),
    .eqctl_2ects1_retimer_eq_ext0_rcvd (pre_eqctl_2ects1_retimer_eq_ext0_rcvd),
    .eqctl_8g5eqts1_rcvd            (pre_eqctl_8g5eqts1_rcvd),
    .eqctl_8g5eqts2_rcvd            (pre_eqctl_8g5eqts2_rcvd),
    .eqctl_any_8g5eqts1_rcvd        (pre_eqctl_any_8g5eqts1_rcvd),
    .eqctl_any_8g5eqts2_rcvd        (pre_eqctl_any_8g5eqts2_rcvd),
    .eqctl_precode_request          (eqctl_precode_request),   //used to get Rx de-precoding on
    .eqctl_precode6_request         (eqctl_precode6_request),   //used to get Rx de-precoding on
    .eqctl_8g6eqts1_rcvd            (pre_eqctl_8g6eqts1_rcvd),
    .eqctl_8g6eqts2_rcvd            (pre_eqctl_8g6eqts2_rcvd),
    .eqctl_any_8g6eqts1_rcvd        (pre_eqctl_any_8g6eqts1_rcvd),
    .eqctl_any_8g6eqts2_rcvd        (pre_eqctl_any_8g6eqts2_rcvd),
    .eqctl_2ects1_rcvd              (pre_eqctl_2ects1_rcvd),
    .eqctl_8ects1_rcvd              (pre_eqctl_8ects1_rcvd),
    .eqctl_ftune_rtx_done           (pre_eqctl_ftune_rtx_done),
    .eqctl_eq_req_ltx               (pre_eqctl_eq_req_ltx),
    .eqctl_eq_req_rtx               (pre_eqctl_eq_req_rtx),
    .eqctl_eq_done_wo_err           (pre_eqctl_eq_done_wo_err),
    .eqctl_eq_done_w_err            (pre_eqctl_eq_done_w_err),
    .eqctl_link_retrain             (), // www: to be connected to ltssm
    .eqctl_link_retrain_g4          (), // www: to be connected to ltssm
    .eqctl_link_retrain_g5          (), // www: to be connected to ltssm
    .eqctl_link_retrain_g6          (), // www: to be connected to ltssm
    .eqctl_eqts_info                (eqctl_eqts_info),
    .eqctl_eqts_info_ts0            (eqctl_eqts_info_ts0), // concatenation of {s6, s5, s4, s3, s2, s1} for tx TS0
    .eqctl_g6_tx_ts0                (eqctl_g6_tx_ts0), // tx ts0
    .eqctl_mask_eieos               (pre_eqctl_mask_eieos),
    .eqctl_2mask_eieos_pulse        (pre_eqctl_2mask_eieos_pulse),
    .sta_lec_pset_ltx               (smlh_lec_pset_ltx),
    .sta_lec_pset_lrx               (smlh_lec_pset_lrx),
    .set_ls2_eq_req                 (smlh_ls2_eq_req),
    .sta_ls2_eq_success             (smlh_ls2_eq_success[3:1]),
    .sta_ls2_eq_enter               (smlh_ls2_eq_enter),
    .sta_ls2_eq_cmpl                (smlh_ls2_eq_cmpl)
    ,
    .sta_lec_g4_pset_ltx            (smlh_lec_g4_pset_ltx),
    .sta_lec_g4_pset_lrx            (smlh_lec_g4_pset_lrx),
    .set_ls2_g4_eq_req              (smlh_ls2_g4_eq_req),
    .sta_ls2_g4_eq_success          (smlh_ls2_g4_eq_success[3:1]),
    .sta_ls2_g4_eq_enter            (smlh_ls2_g4_eq_enter),
    .sta_ls2_g4_eq_cmpl             (smlh_ls2_g4_eq_cmpl)
    ,
    .sta_lec_g5_pset_ltx            (smlh_lec_g5_pset_ltx),
    .sta_lec_g5_pset_lrx            (smlh_lec_g5_pset_lrx),
    .set_ls2_g5_eq_req              (smlh_ls2_g5_eq_req),
    .sta_ls2_g5_eq_success          (smlh_ls2_g5_eq_success[3:1]),
    .sta_ls2_g5_eq_enter            (smlh_ls2_g5_eq_enter),
    .sta_ls2_g5_eq_cmpl             (smlh_ls2_g5_eq_cmpl)
    ,
    .sta_lec_g6_pset_ltx            (smlh_lec_g6_pset_ltx),
    .sta_lec_g6_pset_lrx            (smlh_lec_g6_pset_lrx),
    .set_ls2_g6_eq_req              (smlh_ls2_g6_eq_req),
    .sta_ls2_g6_eq_success          (smlh_ls2_g6_eq_success[3:1]),
    .sta_ls2_g6_eq_enter            (smlh_ls2_g6_eq_enter),
    .sta_ls2_g6_eq_cmpl             (smlh_ls2_g6_eq_cmpl)
); //smlh_eqctl

localparam DATAPATH_WIDTH_GEN5_FPGA_EQCTL =
                                           7 + NL*2 + NL*TX_PSET_WD + NL*EQTS_WD + 4*2
                                         + 2
                                         + 4
                                         + 4
                                         + 4 + NL*TS_0_WD
                                         + 1
                                           ;
delay_n

 #(N_DELAY_GEN5_FPGA, DATAPATH_WIDTH_GEN5_FPGA_EQCTL) u_delay_gen5_eqctl
(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({
                  ~ltssm_clear_eqctl && pre_eqctl_8eqts1_rcvd,
                  ~ltssm_clear_eqctl && pre_eqctl_8eqts2_rcvd,
                  ~ltssm_clear_eqctl && pre_eqctl_any_8eqts1_rcvd,
                  ~ltssm_clear_eqctl && pre_eqctl_any_8eqts2_rcvd,
                  ~ltssm_clear_eqctl && pre_eqctl_8g4eqts1_rcvd,
                  ~ltssm_clear_eqctl && pre_eqctl_8g4eqts2_rcvd,
                  ~ltssm_clear_eqctl && pre_eqctl_any_8g4eqts1_rcvd,
                  ~ltssm_clear_eqctl && pre_eqctl_any_8g4eqts2_rcvd,
                  ~ltssm_clear_eqctl && pre_eqctl_8g5eqts1_rcvd,
                  ~ltssm_clear_eqctl && pre_eqctl_8g5eqts2_rcvd,
                  ~ltssm_clear_eqctl && pre_eqctl_any_8g5eqts1_rcvd,
                  ~ltssm_clear_eqctl && pre_eqctl_any_8g5eqts2_rcvd,
                  ~ltssm_clear_eqctl && pre_eqctl_8g6eqts1_rcvd,
                  ~ltssm_clear_eqctl && pre_eqctl_8g6eqts2_rcvd,
                  ~ltssm_clear_eqctl && pre_eqctl_any_8g6eqts1_rcvd,
                  ~ltssm_clear_eqctl && pre_eqctl_any_8g6eqts2_rcvd,
                  pre_eqctl_2ects1_retimer_eq_ext0_rcvd,
                  {4{~ltssm_clear_eqctl}} & pre_eqctl_2ects1_rcvd,
                  {4{~ltssm_clear_eqctl}} & pre_eqctl_8ects1_rcvd,
                  pre_eqctl_eq_req_ltx,
                  pre_eqctl_eq_req_rtx,
                  pre_eqctl_eq_done_wo_err,
                  pre_eqctl_eq_done_w_err,
                  pre_eqctl_ftune_rtx_done,
                  eqctl_eqts_info,
                  eqctl_eqts_info_ts0,
                  pre_eqctl_mask_eieos,
                  pre_eqctl_2mask_eieos_pulse,
                  pre_eqctl_pset_ltx
                  }),
    .dout       ({
                      eqctl_8eqts1_rcvd,
                      eqctl_8eqts2_rcvd,
                      eqctl_any_8eqts1_rcvd,
                      eqctl_any_8eqts2_rcvd,
                      eqctl_8g4eqts1_rcvd,
                      eqctl_8g4eqts2_rcvd,
                      eqctl_any_8g4eqts1_rcvd,
                      eqctl_any_8g4eqts2_rcvd,
                      eqctl_8g5eqts1_rcvd,
                      eqctl_8g5eqts2_rcvd,
                      eqctl_any_8g5eqts1_rcvd,
                      eqctl_any_8g5eqts2_rcvd,
                      eqctl_8g6eqts1_rcvd,
                      eqctl_8g6eqts2_rcvd,
                      eqctl_any_8g6eqts1_rcvd,
                      eqctl_any_8g6eqts2_rcvd,
                      eqctl_2ects1_retimer_eq_ext0_rcvd,
                      eqctl_2ects1_rcvd,
                      eqctl_8ects1_rcvd,
                      eqctl_eq_req_ltx,
                      eqctl_eq_req_rtx,
                      eqctl_eq_done_wo_err,
                      eqctl_eq_done_w_err,
                      eqctl_ftune_rtx_done,
                      reg_eqctl_eqts_info,
                      reg_eqctl_eqts_info_ts0,
                      eqctl_mask_eieos,
                      eqctl_2mask_eieos_pulse,
                      eqctl_pset_ltx
                })
);

assign eqctl_rev_eqctl_eqts_info          = reg_eqctl_eqts_info;
assign eqctl_rev_eqctl_eqts_info_ts0      = reg_eqctl_eqts_info_ts0;
assign eqpa_rev_mac_phy_use_pset_bus      = mac_phy_use_pset_bus;
assign eqpa_rev_mac_phy_pset_ltx          = mac_phy_pset_ltx;
assign eqpa_rev_mac_phy_pset_lrx          = mac_phy_pset_lrx;
assign eqpa_rev_mac_phy_fslf_rtx          = mac_phy_fslf_rtx;
assign eqpa_rev_mac_phy_fslf_rtx_valid    = mac_phy_fslf_rtx_valid;
assign eqpa_rev_phy_mac_fslf_ltx_valid    = phy_mac_fslf_ltx_valid;
assign eqpa_rev_phy_mac_fslf_ltx          = phy_mac_fslf_ltx;
assign eqpa_rev_phy_mac_coef_ltx          = phy_mac_coef_ltx;
assign eqpa_rev_mac_phy_lpbk_ftune_ltx    = mac_phy_lpbk_ftune_ltx;
assign eqpa_rev_mac_phy_coef_ltx          = mac_phy_coef_ltx;
assign eqpa_rev_mac_phy_pset_ltx_upd      = mac_phy_pset_ltx_upd;
assign eqpa_rev_mac_phy_coef_ltx_upd      = mac_phy_coef_ltx_upd;
assign eqpa_rev_phy_mac_accept_ltx        = phy_mac_accept_ltx;
assign eqpa_rev_phy_mac_reject_ltx        = phy_mac_reject_ltx;
assign eqpa_rev_mac_phy_reject_rtx        = mac_phy_reject_rtx;
assign eqpa_rev_mac_phy_accept_rtx        = mac_phy_accept_rtx;
assign eqpa_rev_mac_phy_coef_rtx          = mac_phy_coef_rtx;
assign eqpa_rev_mac_phy_pset_rtx          = mac_phy_pset_rtx;
assign eqpa_rev_phy_mac_pset_rtx          = phy_mac_pset_rtx;
assign eqpa_rev_phy_mac_coef_rtx          = phy_mac_coef_rtx;
assign eqpa_rev_phy_mac_ftune_rtx_done    = phy_mac_ftune_rtx_done;
assign eqpa_rev_phy_mac_ftune_rtx_optimal = phy_mac_ftune_rtx_optimal;
assign eqpa_rev_phy_mac_coef_rtx_upd      = phy_mac_coef_rtx_upd;
assign eqpa_rev_phy_mac_pset_rtx_upd      = phy_mac_pset_rtx_upd;

smlh_eqpa

#(INST) u_smlh_eqpa (
    .core_clk                                 (core_clk),
    .core_rst_n                               (core_rst_n),
    .sticky_rst_n                             (sticky_rst_n),
//CDM i/f
    //input
    .ltssm_eq_exit                            (ltssm_eq_exit),
    .lpbk_eq_lanes_active                     (lpbk_eq_lanes_active),
    .cfg_fast_link_mode                       (cfg_fast_link_mode),
    .cfg_fast_link_scaling_factor             (cfg_fast_link_scaling_factor),
    .cfg_gen3_eq_feedback_mode                (cfg_gen3_eq_feedback_mode),
    .cfg_gen3_eq_pset_req_vector              (cfg_gen3_eq_pset_req_vector),
    .cfg_gen3_eq_pset_req_as_coef             (cfg_gen3_eq_pset_req_as_coef),
    .cfg_gen3_eq_fom_include_init_eval        (cfg_gen3_eq_fom_include_init_eval),
    .cfg_gen3_eq_p23_eval_timeout_2ms_disable (cfg_gen3_eq_p23_eval_timeout_2ms_disable),
    .cfg_gen3_eq_p23_eval_2ms_extend          (cfg_gen3_eq_p23_eval_2ms_extend),
    .cfg_gen3_eq_invreq_eval_diff_disable     (cfg_gen3_eq_invreq_eval_diff_disable),
    .cfg_gen34_eq_phase23_rxeq_regardless_rxts (cfg_gen34_eq_phase23_rxeq_regardless_rxts),
    .cfg_gen3_eq_p23_exit_mode                (cfg_gen3_eq_p23_exit_mode),
    .cfg_gen4_eq_p23_exit_mode                (cfg_gen4_eq_p23_exit_mode),
    .cfg_gen4_eq_feedback_mode                (cfg_gen4_eq_feedback_mode),
    .cfg_gen4_eq_pset_req_vector              (cfg_gen4_eq_pset_req_vector),
    .cfg_gen4_eq_pset_req_as_coef             (cfg_gen4_eq_pset_req_as_coef),
    .cfg_gen4_eq_fom_include_init_eval        (cfg_gen4_eq_fom_include_init_eval),
    .cfg_gen4_eq_p23_eval_timeout_2ms_disable (cfg_gen4_eq_p23_eval_timeout_2ms_disable),
    .cfg_gen4_eq_p23_eval_2ms_extend          (cfg_gen4_eq_p23_eval_2ms_extend),
    .cfg_gen5_eq_p23_exit_mode                (cfg_gen5_eq_p23_exit_mode),
    .cfg_gen5_eq_feedback_mode                (cfg_gen5_eq_feedback_mode),
    .cfg_gen5_eq_pset_req_vector              (cfg_gen5_eq_pset_req_vector),
    .cfg_gen5_eq_pset_req_as_coef             (cfg_gen5_eq_pset_req_as_coef),
    .cfg_gen5_eq_fom_include_init_eval        (cfg_gen5_eq_fom_include_init_eval),
    .cfg_gen5_eq_p23_eval_timeout_2ms_disable (cfg_gen5_eq_p23_eval_timeout_2ms_disable),
    .cfg_gen5_eq_p23_eval_2ms_extend          (cfg_gen5_eq_p23_eval_2ms_extend),
    .cfg_gen6_eq_p23_exit_mode                (cfg_gen6_eq_p23_exit_mode),
    .cfg_gen6_eq_feedback_mode                (cfg_gen6_eq_feedback_mode),
    .cfg_gen6_eq_pset_req_vector              (cfg_gen6_eq_pset_req_vector),
    .cfg_gen6_eq_pset_req_as_coef             (cfg_gen6_eq_pset_req_as_coef),
    .cfg_gen6_eq_fom_include_init_eval        (cfg_gen6_eq_fom_include_init_eval),
    .cfg_gen6_eq_p23_eval_timeout_2ms_disable (cfg_gen6_eq_p23_eval_timeout_2ms_disable),
    .cfg_gen6_eq_p23_eval_2ms_extend          (cfg_gen6_eq_p23_eval_2ms_extend),
    .cfg_gen3_eq_dcm_t_min_phase23            (cfg_gen3_eq_dcm_t_min_phase23),
    .cfg_gen3_eq_dcm_n_evals                  (cfg_gen3_eq_dcm_n_evals),
    .cfg_gen3_eq_dcm_max_precursor_delta      (cfg_gen3_eq_dcm_max_precursor_delta),
    .cfg_gen3_eq_dcm_max_postcursor_delta     (cfg_gen3_eq_dcm_max_postcursor_delta),
    .cfg_gen4_eq_dcm_t_min_phase23            (cfg_gen4_eq_dcm_t_min_phase23),
    .cfg_gen4_eq_dcm_n_evals                  (cfg_gen4_eq_dcm_n_evals),
    .cfg_gen4_eq_dcm_max_precursor_delta      (cfg_gen4_eq_dcm_max_precursor_delta),
    .cfg_gen4_eq_dcm_max_postcursor_delta     (cfg_gen4_eq_dcm_max_postcursor_delta),
    .cfg_gen5_eq_dcm_t_min_phase23            (cfg_gen5_eq_dcm_t_min_phase23),
    .cfg_gen5_eq_dcm_n_evals                  (cfg_gen5_eq_dcm_n_evals),
    .cfg_gen5_eq_dcm_max_precursor_delta      (cfg_gen5_eq_dcm_max_precursor_delta),
    .cfg_gen5_eq_dcm_max_postcursor_delta     (cfg_gen5_eq_dcm_max_postcursor_delta),
    .cfg_gen6_eq_dcm_t_min_phase23            (cfg_gen6_eq_dcm_t_min_phase23),
    .cfg_gen6_eq_dcm_n_evals                  (cfg_gen6_eq_dcm_n_evals),
    .cfg_gen6_eq_dcm_max_precursor2_delta     (cfg_gen6_eq_dcm_max_precursor2_delta),
    .cfg_gen6_eq_dcm_max_precursor_delta      (cfg_gen6_eq_dcm_max_precursor_delta),
    .cfg_gen6_eq_dcm_max_postcursor_delta     (cfg_gen6_eq_dcm_max_postcursor_delta),
    .cfg_gen3_eq_map_mode_prog                (cfg_gen3_eq_map_mode_prog),
    .cfg_gen3_eq_fs_lf                        (cfg_gen3_eq_fs_lf),
    .cfg_gen3_eq_coef                         (cfg_gen3_eq_coef),
    .cfg_gen4_eq_fs_lf                        (cfg_gen4_eq_fs_lf),
    .cfg_gen4_eq_coef                         (cfg_gen4_eq_coef),
    .cfg_gen5_eq_fs_lf                        (cfg_gen5_eq_fs_lf),
    .cfg_gen5_eq_coef                         (cfg_gen5_eq_coef),
    .cfg_gen6_eq_fs_lf                        (cfg_gen6_eq_fs_lf),
    .cfg_gen6_eq_coef                         (cfg_gen6_eq_coef),

    .cfg_gen3_req_rst_eiec_disable            (cfg_gen3_req_rst_eiec_disable),
    .eqctl_eqts_info                          (eqctl_rev_eqctl_eqts_info),
    .eqctl_eqts_info_ts0                      (eqctl_rev_eqctl_eqts_info_ts0),

//coef req for FOM interface

//ltssm i/f
    //input
    .ltssm_timeout24ms              (ltssm_timeout24ms), //gates: from LTSSM
    .ltssm_lanes_active             (eq_lanes_active),
    .smlh_ltssm_state_wire          (smlh_ltssm_state_wire),
    .ltssm_lpbk_master              (ltssm_lpbk_master),
    .lpbk_eq_n_lut_pset             (lpbk_eq_n_lut_pset),
    .ltssm_timer_24ms_cnt           (ltssm_timer_24ms_cnt),
    .ltssm_noeq_nd                  (ltssm_noeq_nd),
    .current_data_rate              (pm_current_data_rate_smlh_eq),
    .mac_phy_rate                   (mac_phy_rate),
    .mac_phy_txswing                (mac_phy_txswing),
    .eqpa_ftune_rtx_optimal         (eqpa_ftune_rtx_optimal),
    .eqpa_fs_out_of_range           (eqpa_fs_out_of_range),
    .eqpa_use_pset_query_done       (eqpa_use_pset_query_done),
    .eqpa_timeout_1us_after_request (eqpa_timeout_1us_after_request),
    .eqpa_fom_rxeq_redardless_rxts  (eqpa_fom_rxeq_redardless_rxts),
    .eqpa_wait_rei_state            (eqpa_wait_rei_state),
// eqctl i/f - use_pset - Phase-1/0/1
    //input
    .mac_phy_use_pset               (eqpa_rev_mac_phy_use_pset_bus),
    .mac_phy_pset_ltx               (eqpa_rev_mac_phy_pset_ltx),
    .mac_phy_pset_lrx               (eqpa_rev_mac_phy_pset_lrx),
    .mac_phy_fslf_rtx               (eqpa_rev_mac_phy_fslf_rtx),
    .mac_phy_fslf_rtx_valid         (eqpa_rev_mac_phy_fslf_rtx_valid),
    //output
    .phy_mac_fslf_ltx_valid         (phy_mac_fslf_ltx_valid),
    .phy_mac_fslf_ltx               (phy_mac_fslf_ltx),
    .phy_mac_coef_ltx               (phy_mac_coef_ltx),

//pipe i/f
    //input
    .phy_mac_fs                     (phy_mac_fs),
    .phy_mac_lf                     (phy_mac_lf),
    //output
    .eqpa_txdeemph                  (smlh_eqpa_txdeemph),
    .mac_phy_rxpresethint           (mac_phy_rxpresethint),
    .mac_phy_fs                     (mac_phy_fs),
    .mac_phy_lf                     (mac_phy_lf),

//eqctl i/f - ftune_ltx - Phase2/3 as a Slave
    //input
    .mac_phy_ftune_ltx              (mac_phy_ftune_ltx),
    .mac_phy_lpbk_ftune_ltx         (eqpa_rev_mac_phy_lpbk_ftune_ltx),
    .mac_phy_coef_ltx               (eqpa_rev_mac_phy_coef_ltx),
    .mac_phy_pset_ltx_upd           (eqpa_rev_mac_phy_pset_ltx_upd),
    .mac_phy_coef_ltx_upd           (eqpa_rev_mac_phy_coef_ltx_upd),
    //output
    .phy_mac_accept_ltx             (phy_mac_accept_ltx),
    .phy_mac_reject_ltx             (phy_mac_reject_ltx),

//eqctl i/f - ftune_rtx - Phase2/3 as a Master
    //input
    .mac_phy_ftune_rtx              (mac_phy_ftune_rtx),
    .mac_phy_reject_rtx             (eqpa_rev_mac_phy_reject_rtx),
    .mac_phy_accept_rtx             (eqpa_rev_mac_phy_accept_rtx),
    .mac_phy_coef_rtx               (eqpa_rev_mac_phy_coef_rtx),
    .mac_phy_pset_rtx               (eqpa_rev_mac_phy_pset_rtx),
    //output
    .phy_mac_pset_rtx               (phy_mac_pset_rtx),
    .phy_mac_coef_rtx               (phy_mac_coef_rtx),
    .phy_mac_ftune_rtx_done         (phy_mac_ftune_rtx_done),
    .phy_mac_ftune_rtx_optimal      (phy_mac_ftune_rtx_optimal),
    .phy_mac_coef_rtx_upd           (phy_mac_coef_rtx_upd),
    .phy_mac_pset_rtx_upd           (phy_mac_pset_rtx_upd),

// pipe i/f
    //input
    .phy_mac_phystatus              (phy_mac_phystatus),
    .phy_mac_dirfeedback            (phy_mac_dirfeedback),
    .phy_mac_fomfeedback            (phy_mac_fomfeedback),
    .phy_mac_local_tx_pset_coef     (phy_mac_local_tx_pset_coef),
    .phy_mac_local_tx_coef_valid    (phy_mac_local_tx_coef_valid),
    //output
    .mac_phy_getlocal_pset_coef     (mac_phy_getlocal_pset_coef),
    .mac_phy_local_pset_index       (mac_phy_local_pset_index),
    .mac_phy_rxeqinprogress         (mac_phy_rxeqinprogress),
    .mac_phy_invalid_req            (mac_phy_invalid_req),
    .mac_phy_rxeqeval               (tmp_mac_phy_rxeqeval),
    .mac_phy_dirchange              (mac_phy_dirchange)
    ,
    // inputs
    .ltssm_timeout10ms              (ltssm_timeout10ms),
    .cdm_ras_des_eq_fom_target_en   (cdm_ras_des_eq_fom_target_en),
    .cdm_ras_des_eq_force_coef_rtx_en (cdm_ras_des_eq_force_coef_rtx_en),
    .cdm_ras_des_eq_force_pset_lrx_en (cdm_ras_des_eq_force_pset_lrx_en),
    .cdm_ras_des_eq_force_coef_ltx_en (cdm_ras_des_eq_force_coef_ltx_en),
    .cdm_ras_des_eq_force_coef_ltx  (cdm_ras_des_eq_force_coef_ltx),
    .cdm_ras_des_eq_force_pset_lrx  (cdm_ras_des_eq_force_pset_lrx),
    .cdm_ras_des_eq_force_coef_rtx  (cdm_ras_des_eq_force_coef_rtx),
    .cdm_ras_des_eq_fom_target      (cdm_ras_des_eq_fom_target),
    .cdm_ras_des_eq_eval_interval   (cdm_ras_des_eq_eval_interval),
    .cdm_ras_des_eq_force_coef_rtx_en_g4 (cdm_ras_des_eq_force_coef_rtx_en_g4),
    .cdm_ras_des_eq_force_coef_ltx_en_g4 (cdm_ras_des_eq_force_coef_ltx_en_g4),
    .cdm_ras_des_eq_force_coef_ltx_g4 (cdm_ras_des_eq_force_coef_ltx_g4),
    .cdm_ras_des_eq_force_coef_rtx_g4 (cdm_ras_des_eq_force_coef_rtx_g4),
    .cdm_ras_des_eq_force_coef_rtx_en_g5 (cdm_ras_des_eq_force_coef_rtx_en_g5),
    .cdm_ras_des_eq_force_coef_ltx_en_g5 (cdm_ras_des_eq_force_coef_ltx_en_g5),
    .cdm_ras_des_eq_force_coef_ltx_g5 (cdm_ras_des_eq_force_coef_ltx_g5),
    .cdm_ras_des_eq_force_coef_rtx_g5 (cdm_ras_des_eq_force_coef_rtx_g5),
    .cdm_ras_des_eq_force_coef_rtx_en_g6 (cdm_ras_des_eq_force_coef_rtx_en_g6),
    .cdm_ras_des_eq_force_coef_ltx_en_g6 (cdm_ras_des_eq_force_coef_ltx_en_g6),
    .cdm_ras_des_eq_force_coef_ltx_g6 (cdm_ras_des_eq_force_coef_ltx_g6),
    .cdm_ras_des_eq_force_coef_rtx_g6 (cdm_ras_des_eq_force_coef_rtx_g6),
    // outputs
    .mac_cdm_ras_des_fs             (mac_cdm_ras_des_fs),
    .mac_cdm_ras_des_lf             (mac_cdm_ras_des_lf),
    .mac_cdm_ras_des_coef_ltx       (mac_cdm_ras_des_coef_ltx),
    .mac_cdm_ras_des_pset_lrx       (mac_cdm_ras_des_pset_lrx),
    .mac_cdm_ras_des_coef_rtx       (mac_cdm_ras_des_coef_rtx),
    .mac_cdm_ras_des_reject_rtx     (mac_cdm_ras_des_reject_rtx),
    .phy_cdm_ras_des_fomfeedback    (phy_cdm_ras_des_fomfeedback),
    .eqpa_violate_rule_123          (eqpa_violate_rule_123),
    .eq_convergence_sts             (eq_convergence_sts)
    ,
    .mac_cdm_ras_des_fs_g4          (mac_cdm_ras_des_fs_g4),
    .mac_cdm_ras_des_lf_g4          (mac_cdm_ras_des_lf_g4),
    .mac_cdm_ras_des_coef_ltx_g4    (mac_cdm_ras_des_coef_ltx_g4),
    .mac_cdm_ras_des_coef_rtx_g4    (mac_cdm_ras_des_coef_rtx_g4),
    .mac_cdm_ras_des_reject_rtx_g4  (mac_cdm_ras_des_reject_rtx_g4),
    .phy_cdm_ras_des_fomfeedback_g4 (phy_cdm_ras_des_fomfeedback_g4),
    .eqpa_violate_rule_123_g4       (eqpa_violate_rule_123_g4),
    .eq_convergence_sts_g4          (eq_convergence_sts_g4)
    ,
    .mac_cdm_ras_des_fs_g5          (mac_cdm_ras_des_fs_g5),
    .mac_cdm_ras_des_lf_g5          (mac_cdm_ras_des_lf_g5),
    .mac_cdm_ras_des_coef_ltx_g5    (mac_cdm_ras_des_coef_ltx_g5),
    .mac_cdm_ras_des_coef_rtx_g5    (mac_cdm_ras_des_coef_rtx_g5),
    .mac_cdm_ras_des_reject_rtx_g5  (mac_cdm_ras_des_reject_rtx_g5),
    .phy_cdm_ras_des_fomfeedback_g5 (phy_cdm_ras_des_fomfeedback_g5),
    .eqpa_violate_rule_123_g5       (eqpa_violate_rule_123_g5),
    .eq_convergence_sts_g5          (eq_convergence_sts_g5)
    ,
    .mac_cdm_ras_des_fs_g6          (mac_cdm_ras_des_fs_g6),
    .mac_cdm_ras_des_lf_g6          (mac_cdm_ras_des_lf_g6),
    .mac_cdm_ras_des_coef_ltx_g6    (mac_cdm_ras_des_coef_ltx_g6),
    .mac_cdm_ras_des_coef_rtx_g6    (mac_cdm_ras_des_coef_rtx_g6),
    .mac_cdm_ras_des_reject_rtx_g6  (mac_cdm_ras_des_reject_rtx_g6),
    .phy_cdm_ras_des_fomfeedback_g6 (phy_cdm_ras_des_fomfeedback_g6),
    .eqpa_violate_rule_123_g6       (eqpa_violate_rule_123_g6),
    .eqpa_violate_rule_4_g6         (eqpa_violate_rule_4_g6),
    .eq_convergence_sts_g6          (eq_convergence_sts_g6)
 ); //smlh_eqpa

// Layer1 Sequence Finder
reg     [(NL*RXSH_WD)-1:0]  rmlh_descrambled_rxsyncheader ;

always @(*) begin : extract_synchdr_PROC
    integer i;
    if (current_data_rate == `GEN1_RATE || current_data_rate == `GEN2_RATE)
        rmlh_descrambled_rxsyncheader = 0;
    else begin
        for(i=0; i<NL; i=i+1)
            rmlh_descrambled_rxsyncheader[RXSH_WD*i +: RXSH_WD] = rmlh_descrambled_rxdatak[NBK*i +: RXSH_WD];
    end
end

wire    [(NL*NB)-1:0]  tmp_rpipe_rxdatak;
assign tmp_rpipe_rxdatak = rpipe_rxdatak;

// DSP moves to Cfg.Lanenum.wait and starts sending MOD TS while USP remains in Cfg.Linkwidth.Accept and may receive MOD TS. Gen5 Spec Errata
wire ltssm_mod_ts_rx_i = cfg_upstream_port ? ltssm_mod_ts_rx : ltssm_mod_ts;
wire [NL-1:0] smseq_ts0_rcvd_pulse_bus;

smlh_seq_finder

#(INST) u_smlh_seq_finder (
// ---- inputs ---------------
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .ltssm_lane_flip_ctrl_chg_pulse (ltssm_lane_flip_ctrl_chg_pulse),
    .smlh_link_up                   (smlh_link_up),
    .smlh_link_in_training          (smlh_link_in_training),
    .active_nb                      (active_nb),
    .smlh_in_rl0s                   (smlh_in_rl0s),
    .smlh_keep_rcvrylock_lane       (smlh_keep_rcvrylock_lane),
    .cfg_ts2_lid_deskew             (cfg_ts2_lid_deskew),
    .active_nb_gen34                (active_nb_gen34),
    .rxdata_dv_i                    (rpipe_rxdata_dv),
    .rxdata_i                       (rpipe_rxdata),
    .rxdatak_i                      (tmp_rpipe_rxdatak),
    .rxerror_i                      (rpipe_rxerror_dup),
    .rxskipremoved_i                (rpipe_rxskipremoved),
    .rxaligned_i                    (rpipe_rxaligned),
    .cfg_upstream_port              (cfg_upstream_port),
    .cfg_elastic_buffer_mode        (cfg_elastic_buffer_mode),
    .cfg_polarity_mode              (cfg_polarity_mode),
    .smlh_ltssm_state_wire          (smlh_ltssm_state_wire),
    .current_data_rate              (pm_current_data_rate_smlh_sqf),
    .smlh_ts_spd_chg_rcvd_clr       (smlh_ts_spd_chg_rcvd_clr),
    .rmlh_deskew_ds_g6              (rmlh_deskew_ds_g6),
    .ltssm_clear                    (ltssm_clear_seq),
    .ltssm_mod_ts                   (ltssm_mod_ts_rx_i),
    .descrambled_rxdata_dv          (rmlh_descrambled_rxdata_dv),
    .descrambled_rxdata             (rmlh_descrambled_rxdata),
    .descrambled_rxstartblock       (rmlh_descrambled_rxstartblock),
    .descrambled_ints1              (rmlh_descrambled_ints1),
    .descrambled_ints2              (rmlh_descrambled_ints2),
    .descrambled_inskp              (rmlh_descrambled_inskp),
    .descrambled_ineie              (rmlh_descrambled_ineie),
    .descrambled_eie_det            (rmlh_descrambled_eie_det),
    .descrambled_insds              (rmlh_descrambled_insds),
    .descrambled_rxsyncheader       (rmlh_descrambled_rxsyncheader),
    .descrambled_rxerror            (rmlh_descrambled_rxerror),
    .descrambled_rxaligned          (rmlh_descrambled_rxaligned),
    .descrambled_rxdata_osfound     (rmlh_descrambled_rxdata_osfound),
    .descrambled_rxdata_dcb         (rmlh_descrambled_rxdata_dcb),
    .smlh_ltssm_in_compliance       (smlh_ltssm_in_compliance),
    .smlh_ltssm_in_rcvrylock        (smlh_ltssm_in_rcvrylock),
    .ltssm_state_rcvry_eq           (smlh_ltssm_state_rcvry_eq),
    .cfg_enter_compliance           (cfg_enter_compliance),
    .cfg_gen3_dc_balance_disable    (cfg_gen3_dc_balance_disable),
    .sticky_rst_n                   (sticky_rst_n),
    .xmtbyte_ts_pcnt                (xmtbyte_ts_pcnt),
    .xmtbyte_ts1_sent               (|xmtbyte_ts1_sent),
    .xmtbyte_skip_sent              (xmtbyte_skip_sent),
    .xmtbyte_eies_sent              (xmtbyte_eies_sent),
    .int_directed_speed_change      (int_directed_speed_change),

// ---- outputs ---------------
    .smseq_ts_info_o                (smseq_ts_info_bus),
    .smseq_mt_info_o                (smseq_mt_info_bus),
    .smseq_ts_lanen_linkn_pad_o     (smseq_ts_lanen_linkn_pad_bus),
    .smseq_ts_rcvd_pcnt_o           (smseq_ts_rcvd_pcnt_bus),
    .smseq_ts_rcvd_cond_pcnt_o      (smseq_ts_rcvd_cond_pcnt_bus),
    .smseq_ts_rcvd_mtx_pcnt_o       (smseq_ts_rcvd_mtx_pcnt_bus),
    .smseq_ts_error_o               (smseq_ts_error_bus),
    .smseq_inskip_rcv_o             (smseq_inskip_rcv_bus),
    .smseq_sds_rcvd_o               (smseq_sds_rcvd_bus),
    .smseq_ts0_rcvd_o               (smseq_ts0_rcvd_bus),
    .smseq_ts0_rcvd_pulse_o         (smseq_ts0_rcvd_pulse_bus),
    .smseq_ts1_rcvd_o               (smseq_ts1_rcvd_bus),
    .smseq_ts2_rcvd_o               (smseq_ts2_rcvd_bus),
    .smseq_ts1_rcvd_pulse_to_smlh_o (smseq_ts1_rcvd_pulse_bus_to_smlh),
    .smseq_ts2_rcvd_pulse_to_smlh_o (smseq_ts2_rcvd_pulse_bus_to_smlh),
    .smseq_ts1_rcvd_pulse_to_rmlh_o (smseq_ts1_rcvd_pulse_bus),
    .smseq_ts2_rcvd_pulse_to_rmlh_o (smseq_ts2_rcvd_pulse_bus),
    .smseq_mod_ts1_rcvd_pulse_o     (smseq_mod_ts1_rcvd_pulse_bus),
    .smseq_mod_ts2_rcvd_pulse_o     (smseq_mod_ts2_rcvd_pulse_bus),
    .smseq_loc_ts2_rcvd_o           (smseq_loc_ts2_rcvd_bus),
    .smseq_in_skp_o                 (smseq_in_skp_bus),
    .smseq_fts_skp_do_deskew_o      (smseq_fts_skp_do_deskew_bus),
    .smseq_ineies_rcv_o             (smseq_ineies_rcv_bus),
    .smseq_mcs_rcvd_o               (smseq_mcs_rcvd),
    .smseq_loc_eies_rcvd_o          (smseq_loc_eies_rcvd_bus),
    .smseq_invalid_os_o             (smseq_invalid_os_bus),
    .smseq_os_corrected_o           (smseq_os_corrected_bus),
    .smseq_eqts_info_o              (smseq_eqts_info),
    .smseq_ts_rcvd_s6s9_pcnt_o      (smseq_ts_rcvd_s6s9_pcnt),
    .smseq_g3_error_count_o         (smseq_g3_error_count),
    .smseq_rcvr_pol_reverse_o       (mac_phy_rxpolarity)
    ,
    .smseq_mcs_sts_o                (smseq_mcs_sts),
    .smseq_fts_rcvd_pulse_o         (smseq_fts_rcvd_pulse),
    .smseq_ts_debug_info_o          (smseq_ts_debug_info)
); //smlh_seq_finder

//Layer1 Link
smlh_link
 #(INST) u_smlh_link(
// ---- inputs ---------------
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .sticky_rst_n                   (sticky_rst_n),
    .lpbk_eq_lanes_active           (lpbk_eq_lanes_active),
    .smlh_lanes_active_i            (smlh_lanes_active),
    .smlh_link_mode_i               (smlh_link_mode),
    .ltssm_clear                    (ltssm_clear_link),
    .ltssm_mod_ts                   (ltssm_mod_ts_rx),
    .ltssm_lane_flip_ctrl_chg_pulse (ltssm_lane_flip_ctrl_chg_pulse),
    .ltssm_ts_data_rate             (ltssm_ts_data_rate),
    .ltssm_ts_data_rate_eg6         (ltssm_ts_data_rate_eg6),
    .latched_ts_data_rate_eg6       (latched_ts_data_rate_eg6),
    .ltssm_g6_not_cfg_hotr          (ltssm_g6_not_cfg_hotr),
    .ltssm_g6_not_cfg_hotr_rcvrcfg  (ltssm_g6_not_cfg_hotr_rcvrcfg),
    .ltssm_g6_not_rcvridle          (ltssm_g6_not_rcvridle),
    .cfg_support_part_lanes_rxei_exit (cfg_support_part_lanes_rxei_exit),
    .cfg_fast_link_mode             (cfg_fast_link_mode),
    .cfg_upstream_port              (cfg_upstream_port),
    .cfg_imp_num_lanes              (cfg_imp_num_lanes),
    .cfg_rx_8_ts1s                  (cfg_rx_8_ts1s),
    .current_data_rate              (pm_current_data_rate_smlh_lnk),
    .smlh_ltssm_state_wire          (smlh_ltssm_state_wire),
    .smlh_link_up_falling_edge      (smlh_link_up_falling_edge),
    .smlh_link_up                   (smlh_link_up),
    .ltssm_xlinknum                 (ltssm_xlinknum),
    .ltssm_xk237_4lnknum            (ltssm_xk237_4lnknum),
    .ltssm_xk237_4lannum            (ltssm_xk237_4lannum),
    .ltssm_lpbk_entry_send_ts1      (ltssm_lpbk_entry_send_ts1),
    .ltssm_lpbk_master              (ltssm_lpbk_master),
    .ltssm_directed_speed_change    (ltssm_directed_speed_change),
    .xmtbyte_eies_sent              (xmtbyte_eies_sent),
    .smseq_ts_info_bus              (smseq_ts_info_bus),
    .smseq_mt_info_bus              (smseq_mt_info_bus),
    .smseq_ts_lanen_linkn_pad_bus   (smseq_ts_lanen_linkn_pad_bus),
    .smseq_ts_rcvd_pcnt_bus         (smseq_ts_rcvd_pcnt_bus),
    .smseq_ts_rcvd_cond_pcnt_bus    (smseq_ts_rcvd_cond_pcnt_bus),
    .smseq_ts_rcvd_mtx_pcnt_bus     (smseq_ts_rcvd_mtx_pcnt_bus),
    .xmtbyte_ts_pcnt                (xmtbyte_ts_pcnt),
    .xmtbyte_ts_data_diff           (xmtbyte_ts_data_diff),
    .xmtbyte_spd_chg_sent           (xmtbyte_spd_chg_sent),
    .xmtbyte_ts1_sent               (xmtbyte_ts1_sent),
    .xmtbyte_ts2_sent               (xmtbyte_ts2_sent),
    .xmtbyte_l0p_ts1_sent           (xmtbyte_l0p_ts1_sent),
    .xmtbyte_l0p_ts2_sent           (xmtbyte_l0p_ts2_sent),
    .smlh_l0p_lanes_active          (ltssm_l0p_lanes_active),
    .smlh_l0p_last_lanes_active     (ltssm_l0p_last_lanes_active),
    .smseq_ts_error_bus             (smseq_ts_error_bus),
    .smseq_inskip_rcv_bus           (smseq_inskip_rcv_bus),
    .smseq_sds_rcvd_bus             (smseq_sds_rcvd_bus),
    .smseq_ts0_rcvd_bus             (smseq_ts0_rcvd_bus),
    .smseq_ts0_rcvd_pulse_bus       (smseq_ts0_rcvd_pulse_bus),
    .smseq_ts1_rcvd_bus             (smseq_ts1_rcvd_bus),
    .smseq_ts2_rcvd_bus             (smseq_ts2_rcvd_bus),
    .smseq_ts1_rcvd_pulse_bus       (smseq_ts1_rcvd_pulse_bus_to_smlh),
    .smseq_ts2_rcvd_pulse_bus       (smseq_ts2_rcvd_pulse_bus_to_smlh),
    .smseq_mod_ts1_rcvd_pulse_bus   (smseq_mod_ts1_rcvd_pulse_bus),
    .smseq_mod_ts2_rcvd_pulse_bus   (smseq_mod_ts2_rcvd_pulse_bus),
    .active_nb                      (active_nb),

// ---- outputs ---------------
    .link_imp_lanes                                                               (pre_link_imp_lanes),
    .link_next_link_mode                                                          (pre_link_next_link_mode),
    .link_lanes_rcving                                                            (pre_link_lanes_rcving),
    .link_latched_live_all_8_ts1_plinkn_planen_compl_rcv_0_rcvd                   (pre_link_latched_live_all_8_ts1_plinkn_planen_compl_rcv_0_rcvd),
    .link_latched_live_all_8_ts1_plinkn_planen_lpbk1_rcvd                         (pre_link_latched_live_all_8_ts1_plinkn_planen_lpbk1_rcvd),
    .link_latched_live_all_8_ts2_plinkn_planen_rcvd                               (pre_link_latched_live_all_8_ts2_plinkn_planen_rcvd),
    .link_latched_live_all_8_ts_plinkn_planen_rcvd                                (pre_link_latched_live_all_8_ts_plinkn_planen_rcvd),
    .link_latched_live_any_8_ts_plinkn_planen_rcvd                                (pre_link_latched_live_any_8_ts_plinkn_planen_rcvd),
    .link_latched_live_any_8_ts_plinkn_planen_rcvd_bus                            (pre_link_latched_live_any_8_ts_plinkn_planen_rcvd_bus),
    .link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_0_rcvd                   (pre_link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_0_rcvd),
    .link_latched_live_any_8_ts1_plinkn_planen_lpbk1_rcvd                         (pre_link_latched_live_any_8_ts1_plinkn_planen_lpbk1_rcvd),
    .link_latched_live_any_8_ts2_plinkn_planen_rcvd                               (pre_link_latched_live_any_8_ts2_plinkn_planen_rcvd),
    .link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd             (pre_link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd),
    .link_xmlh_1024_ts1_sent_after_any_1_ts_rcvd                                  (pre_link_xmlh_1024_ts1_sent_after_any_1_ts_rcvd),
    .link_xmlh_16_ts2_sent_after_1_ts2_rcvd                                       (pre_link_xmlh_16_ts2_sent_after_1_ts2_rcvd),
    .link_xmlh_16_ts2_sent_after_1_ts2_rcvd_noeies                                (pre_link_xmlh_16_ts2_sent_after_1_ts2_rcvd_noeies),
    .link_xmlh_16_ts1_sent                                                        (pre_link_xmlh_16_ts1_sent),
    .link_latched_live_all_2_ts1_dis1_rcvd                                        (pre_link_latched_live_all_2_ts1_dis1_rcvd),
    .link_latched_live_all_2_ts1_lpbk1_rcvd                                       (pre_link_latched_live_all_2_ts1_lpbk1_rcvd),
    .link_latched_live_all_2_ts1_lpbk1_ebth1_rcvd                                 (pre_link_latched_live_all_2_ts1_lpbk1_ebth1_rcvd),
    .link_latched_live_all_2_ts1_lpbk1_tmcp1_rcvd                                 (pre_link_latched_live_all_2_ts1_lpbk1_tmcp1_rcvd),
    .link_latched_live_any_2_ts1_apn_rcvd                                         (pre_link_latched_live_any_2_ts1_apn_rcvd),
    .link_latched_live_any_2_ts1_apn_sym14_8_rcvd                                 (pre_link_latched_live_any_2_ts1_apn_sym14_8_rcvd),
    .link_latched_live_any_2_ts2_apn_rcvd                                         (pre_link_latched_live_any_2_ts2_apn_rcvd),
    .link_latched_live_all_8_ts2_apn_sym14_8_rcvd                                 (pre_link_latched_live_all_8_ts2_apn_sym14_8_rcvd),
    .link_latched_live_all_2_ts2_apn_rcvd                                         (pre_link_latched_live_all_2_ts2_apn_rcvd),
    .link_latched_live_all_2_ts2_apn_sym14_8_rcvd                                 (pre_link_latched_live_all_2_ts2_apn_sym14_8_rcvd),
    .link_latched_all_2_ts1_lpbk1_compl_rcv_1_rcvd                                (pre_link_latched_all_2_ts1_lpbk1_compl_rcv_1_rcvd),
    .link_any_2_ts1_linknmtx_planen_rcvd                                          (pre_link_any_2_ts1_linknmtx_planen_rcvd),
    .link_any_1_ts1_plinkn_planen_first_rcvd_2_ts1_linknmtx_planen_same_lane_rcvd (pre_link_any_1_ts1_plinkn_planen_first_rcvd_2_ts1_linknmtx_planen_same_lane_rcvd),
    .link_any_2_ts1_dis1_rcvd                                                     (pre_link_any_2_ts1_dis1_rcvd),
    .link_latched_live_all_2_ts1_linkn_planen_rcvd                                (pre_link_latched_live_all_2_ts1_linkn_planen_rcvd),
    .link_any_2_ts1_linkn_planen_rcvd                                             (pre_link_any_2_ts1_linkn_planen_rcvd),
    .link_lane0_2_ts1_linkn_planen_rcvd                                           (pre_link_lane0_2_ts1_linkn_planen_rcvd),
    .link_lane0_2_ts1_linknmtx_rcvd                                               (pre_link_lane0_2_ts1_linknmtx_rcvd),
    .link_lane0_2_ts1_linknmtx_lanen_rcvd                                         (pre_link_lane0_2_ts1_linknmtx_lanen_rcvd),
    .link_latched_live_all_2_ts1_linknmtx_rcvd                                    (pre_link_latched_live_all_2_ts1_linknmtx_rcvd),
    .link_latched_live_all_2_ts1_linknmtx_lanen_rcvd                              (pre_link_latched_live_all_2_ts1_linknmtx_lanen_rcvd),
    .link_latched_live_all_2_ts1_plinkn_planen_rcvd                               (pre_link_latched_live_all_2_ts1_plinkn_planen_rcvd),
    .link_latched_live_lane0_2_ts1_lanen0_rcvd                                    (pre_link_latched_live_lane0_2_ts1_lanen0_rcvd),
    .link_latched_live_all_2_ts1_linknmtx_lanenmtx_rcvd                           (pre_link_latched_live_all_2_ts1_linknmtx_lanenmtx_rcvd),
    .link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd                  (pre_link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd),
    .link_latched_live_any_2_ts1_lanendiff_linkn_rcvd                             (pre_link_latched_live_any_2_ts1_lanendiff_linkn_rcvd),
    .link_any_2_ts2_rcvd                                                          (pre_link_any_2_ts2_rcvd),
    .link_latched_live_all_2_ts2_linknmtx_lanenmtx_rcvd                           (pre_link_latched_live_all_2_ts2_linknmtx_lanenmtx_rcvd),
    .link_latched_live_all_8_ts1_linknmtx_lanenmtx_rcvd                           (pre_link_latched_live_all_8_ts1_linknmtx_lanenmtx_rcvd),
    .link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd                           (pre_link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd),
    .link_latched_live_all_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd               (pre_link_latched_live_all_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd),
    .link_latched_live_all_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd               (pre_link_latched_live_all_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd),
    .link_latched_live_all_8_ts_linknmtx_lanenmtx_rcvd                            (pre_link_latched_live_all_8_ts_linknmtx_lanenmtx_rcvd),
    .link_latched_live_all_8_ts2_linknmtx_lanenmtx_spd_chg_0_rcvd                 (pre_link_latched_live_all_8_ts2_linknmtx_lanenmtx_spd_chg_0_rcvd),
    .link_latched_live_all_8_ts2_linknmtx_lanenmtx_g1_rate_rcvd                   (pre_link_latched_live_all_8_ts2_linknmtx_lanenmtx_g1_rate_rcvd),
    .link_any_2_ts1_rcvd                                                          (pre_link_any_2_ts1_rcvd),
    .link_latched_live_any_8_ts2_linknmtx_lanenmtx_dis_link_rcvd                  (pre_link_latched_live_any_8_ts2_linknmtx_lanenmtx_dis_link_rcvd),
    .link_latched_live_any_8_ts2_linknmtx_lanenmtx_hot_reset_rcvd                 (pre_link_latched_live_any_8_ts2_linknmtx_lanenmtx_hot_reset_rcvd),
    .link_latched_live_any_8_ts2_linknmtx_lanenmtx_loopback_rcvd                  (pre_link_latched_live_any_8_ts2_linknmtx_lanenmtx_loopback_rcvd),
    .link_latched_live_any_8_ts1_spd_chg_0_rcvd_after_ts2_rcvd                    (pre_link_latched_live_any_8_ts1_spd_chg_0_rcvd_after_ts2_rcvd),
    .link_latched_live_any_8_ts2_spd_chg_0_rcvd                                   (pre_link_latched_live_any_8_ts2_spd_chg_0_rcvd),
    .link_latched_live_any_8_ts2_spd_chg_0_plinkn_rcvd                            (pre_link_latched_live_any_8_ts2_spd_chg_0_plinkn_rcvd),
    .link_latched_live_all_8_ts1_linknmtx_lanenmtx_l0p_rcvd                       (pre_link_latched_live_all_8_ts1_linknmtx_lanenmtx_l0p_rcvd),
    .link_latched_live_all_8_ts2_linknmtx_lanenmtx_l0p_rcvd                       (pre_link_latched_live_all_8_ts2_linknmtx_lanenmtx_l0p_rcvd),
    .link_any_exact_2_ts_l0p_rcvd                                                 (pre_link_any_exact_2_ts_l0p_rcvd),
    .link_xmlh_l0p_16_ts2_sent_after_1_ts2_rcvd                                   (pre_link_xmlh_l0p_16_ts2_sent_after_1_ts2_rcvd),
    .link_xmlh_l0p_16_ts1_sent                                                    (pre_link_xmlh_l0p_16_ts1_sent),
    .link_latched_live_all_ts1_spd_chg_0_rcvd                                     (pre_link_latched_live_all_ts1_spd_chg_0_rcvd),
    .link_latched_live_any_ts2_rcvd                                               (pre_link_latched_live_any_ts2_rcvd),
    .link_any_8_ts1_spd_chg_1_rcvd                                                (pre_link_any_8_ts1_spd_chg_1_rcvd),
    .link_any_8_ts_spd_chg_1_data_rate                                            (pre_link_any_8_ts_spd_chg_1_data_rate),
    .link_latched_live_all_ts1_not_ec_00b_rcvd                                    (pre_link_latched_live_all_ts1_not_ec_00b_rcvd),
    .link_latched_live_all_ts1_ec_00b_rcvd                                        (pre_link_latched_live_all_ts1_ec_00b_rcvd),
    .link_latched_live_all_ts1_ec_00b_spd_chg_same_as_dir_spd_chg_rcvd            (pre_link_latched_live_all_ts1_ec_00b_spd_chg_same_as_dir_spd_chg_rcvd),
    .link_latched_live_all_spd_chg_rcvd_same_as_dir_spd_chg                       (pre_link_latched_live_all_spd_chg_rcvd_same_as_dir_spd_chg),
    .link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd                  (pre_link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd),
    .link_any_8_ts_linknmtx_lanenmtx_rcvd                                         (pre_link_any_8_ts_linknmtx_lanenmtx_rcvd),
    .link_any_8_ts_linknmtx_lanenmtx_auto_chg_rcvd                                (pre_link_any_8_ts_linknmtx_lanenmtx_auto_chg_rcvd),
    .link_ln0_8_ts2_linknmtx_lanenmtx_rcvd                                        (pre_link_ln0_8_ts2_linknmtx_lanenmtx_rcvd),
    .link_ln0_8_ts2_linknmtx_lanenmtx_auto_chg_rcvd                               (pre_link_ln0_8_ts2_linknmtx_lanenmtx_auto_chg_rcvd),
    .link_ln0_2_ts1_linknmtx_lanenmtx_auto_chg_rcvd                               (pre_link_ln0_2_ts1_linknmtx_lanenmtx_auto_chg_rcvd),
    .link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_gtr_g1_rate_rcvd      (pre_link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_gtr_g1_rate_rcvd),
    .link_latched_live_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd                  (pre_link_latched_live_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd),
    .link_latched_live_any_1_ts_linknmtx_lanenmtx_rcvd                            (pre_link_latched_live_any_1_ts_linknmtx_lanenmtx_rcvd),
    .link_latched_live_any_1_ts_linknmtx_lanenmtx_g1_rate_rcvd                    (pre_link_latched_live_any_1_ts_linknmtx_lanenmtx_g1_rate_rcvd),
    .link_latched_live_any_8_std_ts2_spd_chg_1_rcvd                               (pre_link_latched_live_any_8_std_ts2_spd_chg_1_rcvd),
    .link_latched_live_all_8_eq_ts2_spd_chg_1_rcvd                                (pre_link_latched_live_all_8_eq_ts2_spd_chg_1_rcvd),
    .link_latched_live_all_8_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd                    (pre_link_latched_live_all_8_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd),
    .link_any_8_eq_ts2_spd_chg_1_rcvd                                             (pre_link_any_8_eq_ts2_spd_chg_1_rcvd),
    .link_any_8_8gteq_ts2_spd_chg_1_rcvd                                          (pre_link_any_8_8gteq_ts2_spd_chg_1_rcvd),
    .link_any_8_16gteq_ts2_spd_chg_1_rcvd                                         (pre_link_any_8_16gteq_ts2_spd_chg_1_rcvd),
    .link_any_8_32gteq_ts2_spd_chg_1_rcvd                                         (pre_link_any_8_32gteq_ts2_spd_chg_1_rcvd),
    .link_rx_ts0_to_ts1_pulse                                                     (link_rx_ts0_to_ts1_pulse),
    .link_latched_live_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd                   (pre_link_latched_live_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd),
    .link_latched_live_any_8_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd                    (pre_link_latched_live_any_8_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd),
    .link_xmlh_32_ts2_spd_chg_1_sent                                              (pre_link_xmlh_32_ts2_spd_chg_1_sent),
    .link_xmlh_128_ts2_spd_chg_1_sent                                             (pre_link_xmlh_128_ts2_spd_chg_1_sent),
    .link_xmlh_16_ts2_sent_after_1_ts1_rcvd                                       (pre_link_xmlh_16_ts2_sent_after_1_ts1_rcvd),
    .link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_rcvd                    (pre_link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_rcvd),
    .link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd          (pre_link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd),
    .link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_g1_rate_rcvd            (pre_link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_g1_rate_rcvd),
    .link_any_2_ts1_hotreset1_rcvd                                                (pre_link_any_2_ts1_hotreset1_rcvd),
    .link_any_2_ts1_linknmtx_lanenmtx_hotreset1_rcvd                              (pre_link_any_2_ts1_linknmtx_lanenmtx_hotreset1_rcvd),
    .link_any_2_ts1_planen_rcvd                                                   (pre_link_any_2_ts1_planen_rcvd),
    .link_any_2_ts1_lpbk1_rcvd                                                    (pre_link_any_2_ts1_lpbk1_rcvd),
    .link_imp_2_ts1_lpbk1_rcvd                                                    (pre_link_imp_2_ts1_lpbk1_rcvd),
    .link_latched_any_2_ts1_lpbk1_compl_rcv_1_rcvd                                (pre_link_latched_any_2_ts1_lpbk1_compl_rcv_1_rcvd),
    .link_any_2_ts_rcvd                                                           (pre_link_any_2_ts_rcvd),
    .link_1_ts_rcvd                                                               (pre_link_1_ts_rcvd),
    .link_any_1_ts_rcvd                                                           (pre_link_any_1_ts_rcvd),
    .link_any_1_ts2_rcvd                                                          (pre_link_any_1_ts2_rcvd),
    .link_any_exact_1_ts_rcvd                                                     (pre_link_any_exact_1_ts_rcvd),
    .link_any_exact_2_ts_rcvd                                                     (pre_link_any_exact_2_ts_rcvd),
    .link_any_exact_4_ts_rcvd                                                     (pre_link_any_exact_4_ts_rcvd),
    .link_any_exact_5_ts_rcvd                                                     (pre_link_any_exact_5_ts_rcvd),
    .link_latched_live_all_2_ts1_rcvd                                             (pre_link_latched_live_all_2_ts1_rcvd),
    .link_latched_ts_data_rate                                                    (pre_link_latched_ts_data_rate),
    .link_latched_ts_data_rate_ever                                               (pre_link_latched_ts_data_rate_ever),
    .link_latched_ts_spd_chg                                                      (pre_link_latched_ts_spd_chg),
    .link_ts_data_rate                                                            (pre_link_ts_data_rate),
    .link_ts_spd_chg                                                              (pre_link_ts_spd_chg),
    .link_lpbk_ts_data_rate                                                       (pre_link_lpbk_ts_data_rate),
    .link_latched_lpbk_ts_data_rate                                               (pre_link_latched_lpbk_ts_data_rate),
    .link_lpbk_ts_deemphasis                                                      (pre_link_lpbk_ts_deemphasis),
    .link_ts_nfts                                                                 (pre_link_ts_nfts),
    .link_latched_live_all_ts_scrmb_dis                                           (pre_link_latched_live_all_ts_scrmb_dis),
    .link_any_8_ts_auto_chg                                                       (pre_link_any_8_ts_auto_chg),
    .link_latched_mdfts_support                                                   (smlh_mod_ts_rcvd),
    .link_elbc_rcvd                                                               (smlh_elbc_rcvd),
    .link_pc_rcvd                                                                 (pre_link_pc_rcvd),
    .link_pc6_rcvd                                                                (pre_link_pc6_rcvd),
    .link_latched_flitm_support                                                   (pre_link_latched_flitm_support),
    .link_usp_sris_mode                                                           (pre_link_usp_sris_mode),
    .link_latched_modts_support                                                   (pre_link_latched_modts_support),
    .link_latched_skipeq_enable                                                   (pre_link_latched_skipeq_enable),
    .link_any_2_ts1_link_num                                                      (pre_link_any_2_ts1_link_num),
    .link_mode_lanes_active                                                       (pre_link_mode_lanes_active),
    .link_2_ts1_plinkn_planen_rcvd_upconf                                         (pre_link_2_ts1_plinkn_planen_rcvd_upconf),
    .link_any_ts2_rcvd                                                            (pre_link_any_ts2_rcvd),
    .link_latched_ts_retimer_pre                                                  (pre_link_latched_ts_retimer_pre),
    .link_latched_ts_two_retimers_pre                                             (pre_link_latched_ts_two_retimers_pre),
    .link_latched_poll_config_ts_retimer_pre                                      (pre_link_latched_poll_config_ts_retimer_pre),
    .link_latched_poll_config_ts_two_retimers_pre                                 (pre_link_latched_poll_config_ts_two_retimers_pre),
//--------
    .smlh_ts_link_ctrl              (smlh_ts_link_ctrl),        //for debug
    .smlh_rcvd_lane_rev             (smlh_rcvd_lane_rev),       //for debug
    .smlh_ts_link_num               (smlh_ts_link_num),         //for debug
    .smlh_ts_link_num_is_k237       (smlh_ts_link_num_is_k237), //for debug
    .smlh_ts_rcv_err                (smlh_ts_rcv_err),          //for debug
    .smlh_ts1_rcvd                  (smlh_ts1_rcvd),            //for debug
    .smlh_ts2_rcvd                  (smlh_ts2_rcvd),            //for debug
    .smlh_ts_lane_num_is_k237       (smlh_ts_lane_num_is_k237), //for debug
//--------

    .smlh_lanes_rcving              (smlh_lanes_rcving),
    .smlh_inskip_rcv                (smlh_inskip_rcv_bus),
    .smlh_ts_rcvd_pulse_bus         (smlh_ts_rcvd_pulse_bus),
    .smlh_sds_rcvd                  (smlh_sds_rcvd)
); //smlh_link

    assign  link_imp_lanes                                                      =   pre_link_imp_lanes ;
    assign  link_next_link_mode                                                 =   pre_link_next_link_mode ;
    assign  link_lanes_rcving                                                   =   pre_link_lanes_rcving;
    assign  link_latched_live_all_8_ts1_plinkn_planen_compl_rcv_0_rcvd          =   pre_link_latched_live_all_8_ts1_plinkn_planen_compl_rcv_0_rcvd ;
    assign  link_latched_live_all_8_ts1_plinkn_planen_lpbk1_rcvd                =   pre_link_latched_live_all_8_ts1_plinkn_planen_lpbk1_rcvd ;
    assign  link_latched_live_all_8_ts2_plinkn_planen_rcvd                      =   pre_link_latched_live_all_8_ts2_plinkn_planen_rcvd ;
    assign  link_latched_live_all_8_ts_plinkn_planen_rcvd                       =   pre_link_latched_live_all_8_ts_plinkn_planen_rcvd ;
    assign  link_latched_live_any_8_ts_plinkn_planen_rcvd                       =   pre_link_latched_live_any_8_ts_plinkn_planen_rcvd ;
    assign  link_latched_live_any_8_ts_plinkn_planen_rcvd_bus                   =   pre_link_latched_live_any_8_ts_plinkn_planen_rcvd_bus ;
    assign  link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_0_rcvd          =   pre_link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_0_rcvd ;
    assign  link_latched_live_any_8_ts1_plinkn_planen_lpbk1_rcvd                =   pre_link_latched_live_any_8_ts1_plinkn_planen_lpbk1_rcvd ;
    assign  link_latched_live_any_8_ts2_plinkn_planen_rcvd                      =   pre_link_latched_live_any_8_ts2_plinkn_planen_rcvd ;
    assign  link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd    =   pre_link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd ;
    assign  link_xmlh_1024_ts1_sent_after_any_1_ts_rcvd                         =   pre_link_xmlh_1024_ts1_sent_after_any_1_ts_rcvd ;
    assign  link_xmlh_16_ts2_sent_after_1_ts2_rcvd                              =   pre_link_xmlh_16_ts2_sent_after_1_ts2_rcvd ;
    assign  link_xmlh_16_ts2_sent_after_1_ts2_rcvd_noeies                       =   pre_link_xmlh_16_ts2_sent_after_1_ts2_rcvd_noeies ;
    assign  link_xmlh_16_ts1_sent                                               =   pre_link_xmlh_16_ts1_sent ;
    assign  link_latched_live_all_2_ts1_dis1_rcvd                               =   pre_link_latched_live_all_2_ts1_dis1_rcvd ;
    assign  link_latched_live_all_2_ts1_lpbk1_rcvd                              =   pre_link_latched_live_all_2_ts1_lpbk1_rcvd ;
    assign  link_latched_live_all_2_ts1_lpbk1_ebth1_rcvd                        =   pre_link_latched_live_all_2_ts1_lpbk1_ebth1_rcvd ;
    assign  link_latched_live_all_2_ts1_lpbk1_tmcp1_rcvd                        =   pre_link_latched_live_all_2_ts1_lpbk1_tmcp1_rcvd ;
    assign  link_latched_live_any_2_ts1_apn_rcvd                                =   pre_link_latched_live_any_2_ts1_apn_rcvd;
    assign  link_latched_live_any_2_ts1_apn_sym14_8_rcvd                        =   pre_link_latched_live_any_2_ts1_apn_sym14_8_rcvd;
    assign  link_latched_live_any_2_ts2_apn_rcvd                                =   pre_link_latched_live_any_2_ts2_apn_rcvd;
    assign  link_latched_live_all_8_ts2_apn_sym14_8_rcvd                        =   pre_link_latched_live_all_8_ts2_apn_sym14_8_rcvd;
    assign  link_latched_live_all_2_ts2_apn_rcvd                                =   pre_link_latched_live_all_2_ts2_apn_rcvd;
    assign  link_latched_live_all_2_ts2_apn_sym14_8_rcvd                        =   pre_link_latched_live_all_2_ts2_apn_sym14_8_rcvd;
    assign  link_latched_all_2_ts1_lpbk1_compl_rcv_1_rcvd                       =   pre_link_latched_all_2_ts1_lpbk1_compl_rcv_1_rcvd ;
    assign  link_any_2_ts1_linknmtx_planen_rcvd                                 =   pre_link_any_2_ts1_linknmtx_planen_rcvd ;
    assign  link_any_1_ts1_plinkn_planen_first_rcvd_2_ts1_linknmtx_planen_same_lane_rcvd    =   pre_link_any_1_ts1_plinkn_planen_first_rcvd_2_ts1_linknmtx_planen_same_lane_rcvd ;
    assign  link_any_2_ts1_dis1_rcvd                                            =   pre_link_any_2_ts1_dis1_rcvd ;
    assign  link_latched_live_all_2_ts1_linkn_planen_rcvd                       =   pre_link_latched_live_all_2_ts1_linkn_planen_rcvd ;
    assign  link_any_2_ts1_linkn_planen_rcvd                                    =   pre_link_any_2_ts1_linkn_planen_rcvd ;
    assign  link_lane0_2_ts1_linkn_planen_rcvd                                  =   pre_link_lane0_2_ts1_linkn_planen_rcvd ;
    assign  link_lane0_2_ts1_linknmtx_rcvd                                      =   pre_link_lane0_2_ts1_linknmtx_rcvd ;
    assign  link_lane0_2_ts1_linknmtx_lanen_rcvd                                =   pre_link_lane0_2_ts1_linknmtx_lanen_rcvd ;
    assign  link_latched_live_all_2_ts1_linknmtx_rcvd                           =   pre_link_latched_live_all_2_ts1_linknmtx_rcvd ;
    assign  link_latched_live_all_2_ts1_linknmtx_lanen_rcvd                     =   pre_link_latched_live_all_2_ts1_linknmtx_lanen_rcvd ;
    assign  link_latched_live_all_2_ts1_plinkn_planen_rcvd                      =   pre_link_latched_live_all_2_ts1_plinkn_planen_rcvd ;
    assign  link_latched_live_lane0_2_ts1_lanen0_rcvd                           =   pre_link_latched_live_lane0_2_ts1_lanen0_rcvd ;
    assign  link_latched_live_all_2_ts1_linknmtx_lanenmtx_rcvd                  =   pre_link_latched_live_all_2_ts1_linknmtx_lanenmtx_rcvd ;
    assign  link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd         =   pre_link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd ;
    assign  link_latched_live_any_2_ts1_lanendiff_linkn_rcvd                    =   pre_link_latched_live_any_2_ts1_lanendiff_linkn_rcvd ;
    assign  link_any_2_ts2_rcvd                                                 =   pre_link_any_2_ts2_rcvd ;
    assign  link_latched_live_all_2_ts2_linknmtx_lanenmtx_rcvd                  =   pre_link_latched_live_all_2_ts2_linknmtx_lanenmtx_rcvd ;
    assign  link_latched_live_all_8_ts1_linknmtx_lanenmtx_rcvd                  =   pre_link_latched_live_all_8_ts1_linknmtx_lanenmtx_rcvd ;
    assign  link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd                  =   pre_link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd ;
    assign  link_latched_live_all_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd      =   pre_link_latched_live_all_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd ;
    assign  link_latched_live_all_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd      =   pre_link_latched_live_all_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd ;
    assign  link_latched_live_all_8_ts_linknmtx_lanenmtx_rcvd                   =   pre_link_latched_live_all_8_ts_linknmtx_lanenmtx_rcvd ;
    assign  link_latched_live_all_8_ts2_linknmtx_lanenmtx_spd_chg_0_rcvd        =   pre_link_latched_live_all_8_ts2_linknmtx_lanenmtx_spd_chg_0_rcvd ;
    assign  link_latched_live_all_8_ts2_linknmtx_lanenmtx_g1_rate_rcvd          =   pre_link_latched_live_all_8_ts2_linknmtx_lanenmtx_g1_rate_rcvd ;
    assign  link_any_2_ts1_rcvd                                                 =   pre_link_any_2_ts1_rcvd;
    assign  link_latched_live_any_8_ts2_linknmtx_lanenmtx_dis_link_rcvd         =   pre_link_latched_live_any_8_ts2_linknmtx_lanenmtx_dis_link_rcvd;
    assign  link_latched_live_any_8_ts2_linknmtx_lanenmtx_hot_reset_rcvd        =   pre_link_latched_live_any_8_ts2_linknmtx_lanenmtx_hot_reset_rcvd;
    assign  link_latched_live_any_8_ts2_linknmtx_lanenmtx_loopback_rcvd         =   pre_link_latched_live_any_8_ts2_linknmtx_lanenmtx_loopback_rcvd;
    assign  link_latched_live_any_8_ts1_spd_chg_0_rcvd_after_ts2_rcvd           =   pre_link_latched_live_any_8_ts1_spd_chg_0_rcvd_after_ts2_rcvd;
    assign  link_latched_live_any_8_ts2_spd_chg_0_rcvd                          =   pre_link_latched_live_any_8_ts2_spd_chg_0_rcvd;
    assign  link_latched_live_any_8_ts2_spd_chg_0_plinkn_rcvd                   =   pre_link_latched_live_any_8_ts2_spd_chg_0_plinkn_rcvd;
    assign  link_latched_live_all_8_ts1_linknmtx_lanenmtx_l0p_rcvd              =   pre_link_latched_live_all_8_ts1_linknmtx_lanenmtx_l0p_rcvd;
    assign  link_latched_live_all_8_ts2_linknmtx_lanenmtx_l0p_rcvd              =   pre_link_latched_live_all_8_ts2_linknmtx_lanenmtx_l0p_rcvd;
    assign  link_any_exact_2_ts_l0p_rcvd                                        =   pre_link_any_exact_2_ts_l0p_rcvd;
    assign  link_xmlh_l0p_16_ts2_sent_after_1_ts2_rcvd                          =   pre_link_xmlh_l0p_16_ts2_sent_after_1_ts2_rcvd;
    assign  link_xmlh_l0p_16_ts1_sent                                           =   pre_link_xmlh_l0p_16_ts1_sent;
    assign  link_latched_live_all_ts1_spd_chg_0_rcvd                            =   pre_link_latched_live_all_ts1_spd_chg_0_rcvd ;
    assign  link_latched_live_any_ts2_rcvd                                      =   pre_link_latched_live_any_ts2_rcvd ;
    assign  link_any_8_ts1_spd_chg_1_rcvd                                       =   pre_link_any_8_ts1_spd_chg_1_rcvd ;
    assign  link_any_8_ts_spd_chg_1_data_rate                                   =   pre_link_any_8_ts_spd_chg_1_data_rate ;
    assign  link_latched_live_all_ts1_not_ec_00b_rcvd                           =   pre_link_latched_live_all_ts1_not_ec_00b_rcvd ;
    assign  link_latched_live_all_ts1_ec_00b_rcvd                               =   pre_link_latched_live_all_ts1_ec_00b_rcvd ;
    assign  link_latched_live_all_ts1_ec_00b_spd_chg_same_as_dir_spd_chg_rcvd   =   pre_link_latched_live_all_ts1_ec_00b_spd_chg_same_as_dir_spd_chg_rcvd ;
    assign  link_latched_live_all_spd_chg_rcvd_same_as_dir_spd_chg              =   pre_link_latched_live_all_spd_chg_rcvd_same_as_dir_spd_chg ;
    assign  link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd         =   pre_link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd ;
    assign  link_any_8_ts_linknmtx_lanenmtx_rcvd                                =   pre_link_any_8_ts_linknmtx_lanenmtx_rcvd ;
    assign  link_any_8_ts_linknmtx_lanenmtx_auto_chg_rcvd                       =   pre_link_any_8_ts_linknmtx_lanenmtx_auto_chg_rcvd ;
    assign  link_ln0_8_ts2_linknmtx_lanenmtx_rcvd                               =   pre_link_ln0_8_ts2_linknmtx_lanenmtx_rcvd ;
    assign  link_ln0_8_ts2_linknmtx_lanenmtx_auto_chg_rcvd                      =   pre_link_ln0_8_ts2_linknmtx_lanenmtx_auto_chg_rcvd ;
    assign  link_ln0_2_ts1_linknmtx_lanenmtx_auto_chg_rcvd                      =   pre_link_ln0_2_ts1_linknmtx_lanenmtx_auto_chg_rcvd ;
    assign  link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_gtr_g1_rate_rcvd =   pre_link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_gtr_g1_rate_rcvd ;
    assign  link_latched_live_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd         =   pre_link_latched_live_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd ;
    assign  link_latched_live_any_1_ts_linknmtx_lanenmtx_rcvd                   =   pre_link_latched_live_any_1_ts_linknmtx_lanenmtx_rcvd ;
    assign  link_latched_live_any_1_ts_linknmtx_lanenmtx_g1_rate_rcvd           =   pre_link_latched_live_any_1_ts_linknmtx_lanenmtx_g1_rate_rcvd ;
    assign  link_latched_live_any_8_std_ts2_spd_chg_1_rcvd                      =   pre_link_latched_live_any_8_std_ts2_spd_chg_1_rcvd ;
    assign  link_latched_live_all_8_eq_ts2_spd_chg_1_rcvd                       =   pre_link_latched_live_all_8_eq_ts2_spd_chg_1_rcvd ;
    assign  link_latched_live_all_8_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd           =   pre_link_latched_live_all_8_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd ;
    assign  link_any_8_eq_ts2_spd_chg_1_rcvd                                    =   pre_link_any_8_eq_ts2_spd_chg_1_rcvd ;
    assign  link_any_8_8gteq_ts2_spd_chg_1_rcvd                                 =   pre_link_any_8_8gteq_ts2_spd_chg_1_rcvd ;
    assign  link_any_8_16gteq_ts2_spd_chg_1_rcvd                                =   pre_link_any_8_16gteq_ts2_spd_chg_1_rcvd ;
    assign  link_any_8_32gteq_ts2_spd_chg_1_rcvd                                =   pre_link_any_8_32gteq_ts2_spd_chg_1_rcvd ;
    assign  link_pc6_rcvd                                                       =   pre_link_pc6_rcvd;
    assign  link_pc_rcvd                                                        =   pre_link_pc_rcvd;
    assign  link_latched_live_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd          =   pre_link_latched_live_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd ;
    assign  link_latched_live_any_8_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd           =   pre_link_latched_live_any_8_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd ;
    assign  link_xmlh_32_ts2_spd_chg_1_sent                                     =   pre_link_xmlh_32_ts2_spd_chg_1_sent ;
    assign  link_xmlh_128_ts2_spd_chg_1_sent                                    =   pre_link_xmlh_128_ts2_spd_chg_1_sent ;
    assign  link_xmlh_16_ts2_sent_after_1_ts1_rcvd                              =   pre_link_xmlh_16_ts2_sent_after_1_ts1_rcvd ;
    assign  link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_rcvd           =   pre_link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_rcvd ;
    assign  link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd  =  pre_link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd ;
    assign  link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_g1_rate_rcvd   =   pre_link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_g1_rate_rcvd ;
    assign  link_any_2_ts1_hotreset1_rcvd                                       =   pre_link_any_2_ts1_hotreset1_rcvd ;
    assign  link_any_2_ts1_linknmtx_lanenmtx_hotreset1_rcvd                     =   pre_link_any_2_ts1_linknmtx_lanenmtx_hotreset1_rcvd ;
    assign  link_any_2_ts1_planen_rcvd                                          =   pre_link_any_2_ts1_planen_rcvd ;
    assign  link_any_2_ts1_lpbk1_rcvd                                           =   pre_link_any_2_ts1_lpbk1_rcvd ;
    assign  link_imp_2_ts1_lpbk1_rcvd                                           =   pre_link_imp_2_ts1_lpbk1_rcvd ;
    assign  link_latched_any_2_ts1_lpbk1_compl_rcv_1_rcvd                       =   pre_link_latched_any_2_ts1_lpbk1_compl_rcv_1_rcvd ;
    assign  link_any_2_ts_rcvd                                                  =   pre_link_any_2_ts_rcvd ;
    assign  link_1_ts_rcvd                                                      =   pre_link_1_ts_rcvd ;
    assign  link_any_1_ts_rcvd                                                  =   pre_link_any_1_ts_rcvd ;
    assign  link_any_1_ts2_rcvd                                                 =   pre_link_any_1_ts2_rcvd ;
    assign  link_any_exact_1_ts_rcvd                                            =   pre_link_any_exact_1_ts_rcvd ;
    assign  link_any_exact_2_ts_rcvd                                            =   pre_link_any_exact_2_ts_rcvd ;
    assign  link_any_exact_4_ts_rcvd                                            =   pre_link_any_exact_4_ts_rcvd ;
    assign  link_any_exact_5_ts_rcvd                                            =   pre_link_any_exact_5_ts_rcvd ;
    assign  link_latched_live_all_2_ts1_rcvd                                    =   pre_link_latched_live_all_2_ts1_rcvd ;
    assign  link_latched_ts_data_rate                                           =   pre_link_latched_ts_data_rate ;
    assign  link_latched_ts_data_rate_ever                                      =   pre_link_latched_ts_data_rate_ever ;
    assign  link_latched_ts_spd_chg                                             =   pre_link_latched_ts_spd_chg ;
    assign  link_ts_data_rate                                                   =   pre_link_ts_data_rate ;
    assign  link_ts_spd_chg                                                     =   pre_link_ts_spd_chg ;
    assign  link_lpbk_ts_data_rate                                              =   pre_link_lpbk_ts_data_rate ;
    assign  link_latched_lpbk_ts_data_rate                                      =   pre_link_latched_lpbk_ts_data_rate ;
    assign  link_lpbk_ts_deemphasis                                             =   pre_link_lpbk_ts_deemphasis ;
    assign  link_ts_nfts                                                        =   pre_link_ts_nfts ;
    assign  link_latched_live_all_ts_scrmb_dis                                  =   pre_link_latched_live_all_ts_scrmb_dis ;
    assign  link_any_8_ts_auto_chg                                              =   pre_link_any_8_ts_auto_chg ;
    assign  link_latched_flitm_support                                          =   pre_link_latched_flitm_support ;
    assign  link_usp_sris_mode                                                  =   pre_link_usp_sris_mode ;
    assign  link_latched_modts_support                                          =   pre_link_latched_modts_support ;
    assign  link_latched_skipeq_enable                                          =   pre_link_latched_skipeq_enable ;
    assign  link_any_2_ts1_link_num                                             =   pre_link_any_2_ts1_link_num ;
    assign  link_mode_lanes_active                                              =   pre_link_mode_lanes_active ;
    assign  link_2_ts1_plinkn_planen_rcvd_upconf                                =   pre_link_2_ts1_plinkn_planen_rcvd_upconf ;
    assign  link_any_ts2_rcvd                                                   =   pre_link_any_ts2_rcvd ;
    assign  link_latched_ts_retimer_pre                                         =   pre_link_latched_ts_retimer_pre ;
    assign  link_latched_ts_two_retimers_pre                                    =   pre_link_latched_ts_two_retimers_pre ;
    assign  link_latched_poll_config_ts_retimer_pre                             =   pre_link_latched_poll_config_ts_retimer_pre ;
    assign  link_latched_poll_config_ts_two_retimers_pre                        =   pre_link_latched_poll_config_ts_two_retimers_pre ;

//Layer1 electrical Idle Inference
smlh_eidle_infer
 #(INST) u_smlh_eidle_infer(
// ---- inputs ---------------
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),

    .current_data_rate              (pm_current_data_rate_smlh_lnk),

    .smlh_lanes_active              (smlh_lanes_active),
    .smlh_ltssm_state               (smlh_ltssm_state),
    .smlh_l0p_lanes_active          (ltssm_l0p_lanes_active),
    .smlh_ltssm_in_l0p              (smlh_ltssm_in_l0p),
    .smlh_successful_spd_negotiation(smlh_successful_spd_negotiation),

    .smseq_ineies_rcv               (smseq_ineies_rcv_bus),
    .smseq_inskip_rcv               (smseq_inskip_rcv_bus),
    .smseq_ts1_rcvd_pulse           (smseq_ts1_rcvd_pulse_bus_to_smlh),
    .smseq_ts2_rcvd_pulse           (smseq_ts2_rcvd_pulse_bus_to_smlh),

    .rpipe_rxdata_dv                (rpipe_rxdata_dv),
    .rpipe_rxelecidle               (rpipe_rxelecidle),
    .cfg_fast_link_mode             (cfg_fast_link_mode),
    .cfg_gen1_ei_inference_mode     (cfg_gen1_ei_inference_mode),
    .fast_time_4ms                  (smlh_fast_time_4ms[24:0]),

// ---- outputs ---------------
    .smlh_eidle_inferred            (smlh_eidle_inferred)
); //smlh_eidle_infer

wire [NL-1:0] power_saving_lanes_active_p0;
wire [NL*16-1:0] tmp_cfg_margin_control;
assign power_saving_lanes_active_p0 = (current_powerdown==`P0) ? power_saving_lanes_active : {NL{1'b0}};

// Improving synthesis timing closure to add register pipeline between u_cdm and u_smlh_margin
localparam DATAPATH_WIDTH_GEN5_FPGA_MARGIN = NL*16;
delay_n

 #(N_DELAY_GEN5_FPGA, DATAPATH_WIDTH_GEN5_FPGA_MARGIN) u_delay_gen5_margin
(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        (cfg_margin_control),
    .dout       (tmp_cfg_margin_control)
);

smlh_margin
 #(.INST(INST)) u_smlh_margin(
    // ---- inputs ---------------
    .core_clk                           (core_clk),
    .core_rst_n                         (core_rst_n),
    .current_data_rate                  (pm_current_data_rate_smlh_lnk[2:0]),
    .smlh_in_l0                         (smlh_in_l0),
    .smlh_in_rcvryspeed_predetect       (smlh_in_rcvryspeed_predetect),
    .smlh_retimer_pre_detected          (smlh_retimer_pre_detected),
    // Cdm
    .cfg_upstream_port                  (cfg_upstream_port),
    .cfg_margin_control                 (tmp_cfg_margin_control[(NL*16)-1:0]),
    .cfg_margin_num_timing_steps        (cfg_margin_num_timing_steps[5:0]),
    .cfg_margin_max_timing_offset       (cfg_margin_max_timing_offset[5:0]),
    .cfg_margin_num_voltage_steps       (cfg_margin_num_voltage_steps[6:0]),
    .cfg_margin_max_voltage_offset      (cfg_margin_max_voltage_offset[5:0]),
    .cfg_margin_sample_rate_voltage     (cfg_margin_sample_rate_voltage[5:0]),
    .cfg_margin_sample_rate_timing      (cfg_margin_sample_rate_timing[5:0]),
    .cfg_margin_maxlanes                (cfg_margin_maxlanes[4:0]),
    .cfg_margin_voltage_supported       (cfg_margin_voltage_supported),
    .cfg_margin_ind_left_right_timing   (cfg_margin_ind_left_right_timing),
    .cfg_margin_ind_up_down_voltage     (cfg_margin_ind_up_down_voltage),
    .cfg_margin_sample_reporting_method (cfg_margin_sample_reporting_method),
    .cfg_margin_ind_error_sampler       (cfg_margin_ind_error_sampler),
    .cfg_rx_message_bus_write_buffer_depth (cfg_rx_message_bus_write_buffer_depth),
    .power_saving_lanes_active          (power_saving_lanes_active_p0 [NL-1:0]),
    // Xmlh
    .xmtbyte_ctlskip_sent               (xmtbyte_ctlskip_sent),
    // Rmlh
    .rmlh_deskew_datastream             (rmlh_deskew_datastream),
    .rmlh_deskew_ctlskp_info            (rmlh_deskew_ctlskp_info[(NL*16)-1:0]),
    .rmlh_deskew_ctlskp_rcvd            (rmlh_deskew_ctlskp_rcvd[NL-1:0]),
    .rmlh_deskew_ctlskp_err             (rmlh_deskew_ctlskp_err[(NL*5)-1:0]),
    // Pipe
    .rpipe_margin_status                (rpipe_margin_status[NL-1:0]),
    .rpipe_margin_nak                   (rpipe_margin_nak[NL-1:0]),
    .rpipe_margin_error_cnt             (rpipe_margin_error_cnt[(NL*6)-1:0]),
    .rpipe_margin_sampl_cnt             (rpipe_margin_sampl_cnt[(NL*7)-1:0]),
    // ---- outputs ---------------
    // LTSSM
    .smlh_margin_pipe_idle              (smlh_margin_pipe_idle),
    // Cdm
    .smlh_margin_status                 (smlh_margin_status[(NL*16)-1:0]),
    .smlh_margin_status_valid           (smlh_margin_status_valid[NL-1:0]),
    // Pipe
    .smlh_margin_cmd                    (smlh_margin_cmd[(NL*3)-1:0]),
    .smlh_margin_offset                 (smlh_margin_offset[(NL*7)-1:0]),
    .smlh_margin_clr_error_log          (smlh_margin_clr_error_log[(NL*2)-1:0]),
    // Xmlh
    .smlh_ctlskp_info                   (smlh_ctlskp_info[(NL*16)-1:0])); //smlh_margin

// Indicates when the Margining feature is ready to accept margining commands
assign smlh_margin_ready = (((pm_current_data_rate_smlh_lnk >= `GEN4_RATE) 
                            ) && smlh_in_l0);


    assign smlh_eidle_inferred_in_l0 = smlh_debug_info_ei[12];

    // [1:0]                          rplh_rcvd_idle,                 // Track of the number of idle received continously.  Bit 0 indicates receiver received 8 continous idle symbol, bit1 indicates 1 idle receivd
    // [NL-1:0]                       smseq_ts1_rcvd_pulse_bus_to_smlh,             //
    // [NL-1:0]                       smseq_ts2_rcvd_pulse_bus_to_smlh,
    // [NL-1:0]                       smseq_fts_rcvd_pulse;
    // [NL-1:0]                       act_rmlh_rcvd_eidle_set,        // when asserted, it indicates that RPLH detected electric idle set received per lane
    localparam      RCVD_IDL   = 4'h0;
    localparam      RCVD_TS1   = 4'h1;
    localparam      RCVD_TS2   = 4'h2;
    localparam      RCVD_FTS   = 4'h3;
    localparam      RCVD_EI    = 4'h4;
    reg [3:0]    int_rxos_type   [NL-1:0];
    reg [3:0]    int_rxos_type_d [NL-1:0];
    reg [11:0]   int_rxos_count  [NL-1:0];
    reg [NL-1:0] incr_rxos_count;


    
    always @(posedge core_clk or negedge core_rst_n) begin
        integer lnum;
        if (!core_rst_n) begin
            for(lnum=0;lnum<NL;lnum=lnum+1) begin
                int_rxos_type[lnum] <= #`TP RCVD_IDL;
                int_rxos_type_d[lnum] <= #`TP RCVD_IDL;
            end
        end else begin
            for(lnum=0;lnum<NL;lnum=lnum+1) begin
                if(smseq_ts1_rcvd_pulse_bus_to_smlh[lnum])
                    int_rxos_type[lnum] <= #`TP RCVD_TS1;
                else if(smseq_ts2_rcvd_pulse_bus_to_smlh[lnum])
                    int_rxos_type[lnum] <= #`TP RCVD_TS2;
                else if(smseq_fts_rcvd_pulse[lnum])
                    int_rxos_type[lnum] <= #`TP RCVD_FTS;
                else if(act_rmlh_rcvd_eidle_set[lnum])
                    int_rxos_type[lnum] <= #`TP RCVD_EI;
                else if(rplh_rcvd_idle[1])
                    int_rxos_type[lnum] <= #`TP RCVD_IDL;

                int_rxos_type_d[lnum] <= #`TP int_rxos_type[lnum];
            end
        end
    end

    always @(*) begin
        integer lnum;
        for(lnum=0;lnum<NL;lnum=lnum+1) begin
            incr_rxos_count[lnum] = (int_rxos_count[lnum] < 11'h7FF) &
                         ((smseq_ts1_rcvd_pulse_bus_to_smlh[lnum] & (int_rxos_type[lnum]==RCVD_TS1)) |
                          (smseq_ts2_rcvd_pulse_bus_to_smlh[lnum] & (int_rxos_type[lnum]==RCVD_TS2)) |
                          (act_rmlh_rcvd_eidle_set [lnum]         & (int_rxos_type[lnum]==RCVD_EI )) |
                          (smseq_fts_rcvd_pulse[lnum]             & (int_rxos_type[lnum]==RCVD_FTS)) |
                          (rplh_rcvd_idle[1]                      & (int_rxos_type[lnum]==RCVD_IDL)));
        end
    end

    always @(posedge core_clk or negedge core_rst_n) begin
        integer lnum;
        if (!core_rst_n) begin
            for(lnum=0;lnum<NL;lnum=lnum+1) begin
                int_rxos_count[lnum] <= #`TP 0;
            end
        end else begin
            for(lnum=0;lnum<NL;lnum=lnum+1) begin
                if(int_rxos_type[lnum]!=int_rxos_type_d[lnum]) begin
                // OS type changed
                    int_rxos_count[lnum] <= #`TP 1;
                end else if(incr_rxos_count[lnum]) begin
                // incrment
                    int_rxos_count[lnum] <= #`TP int_rxos_count[lnum] + 1;
                end
            end
        end
    end

    generate
        genvar ii;
        for(ii=0;ii<NL;ii=ii+1) begin : smlh_rxos_type_PROC
            assign smlh_rxos_type[(ii+1)*16-1:ii*16] = {int_rxos_type[ii], int_rxos_count[ii]};
        end
    endgenerate


endmodule

