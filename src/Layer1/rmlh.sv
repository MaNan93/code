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
// ---    $Revision: #19 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/rmlh.sv#19 $
// -------------------------------------------------------------------------
// --- Module Description: Receive MAC layer handler
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"

 
 module rmlh
 import DWC_pcie_core_pkg::ltssm_state_e;
 import DWC_pcie_core_pkg::S_DETECT_QUIET;
 import DWC_pcie_core_pkg::S_L0;
(
// ---- inputs ---------------
    pm_block_phystatus,
    core_clk,
    core_clk_ug,
    core_rst_n,
    smlh_flit_mode_enable,
    ltssm_l0p_lanes_active,
    ltssm_l0p_last_lanes_active,
    ltssm_l0p_next_link_mode,
    ltssm_in_l0p,
    ltssm_in_l0p_upsize,
    xmtbyte_l0p_link_in_training,
    xmtbyte_l0p_ts2_sent,
    l0p_sris_mode_enabled,
    cfg_deskew_disable,
    cfg_ts2_lid_deskew,
    cfg_elastic_buffer_mode,
    cfg_fast_link_mode,
    cfg_pipe_garbage_data_mode,
    latched_smlh_link_up,
    latched_flip_ctrl,
    smlh_lane_flip_ctrl,
    smlh_in_rl0s,
    smlh_link_mode,
    smlh_no_turnoff_lanes,
    smlh_lanes_active,
    power_saving_lanes_active,
    deskew_lanes_active,
    smlh_do_deskew,
    smlh_lnknum_match_dis,
    smlh_link_up,
    smlh_link_in_training,
    smlh_scrambler_disable,
    smlh_ltssm_in_pollconfig,
    ltssm_rcvr_err_rpt_en,
    ltssm_clear,
    ltssm_cxl_ll_mod,
    drift_buffer_deskew_enable,
    drift_buffer_deskew_ptr,
    ltssm_powerdown,
    ltssm_lpbk_master,
    smlh_ltssm_state_wire,
    smlh_ltssm_last,
    ltssm_in_lpbk_active,
    smlh_successful_spd_negotiation,
    smseq_loc_eies_rcvd_bus,
    smseq_ts1_rcvd_pulse_bus,
    smseq_ts2_rcvd_pulse_bus,
    smseq_loc_ts2_rcvd_bus,
    smseq_in_skp_bus,
    smseq_fts_skp_do_deskew_bus,

    phy_mac_rxdata,
    phy_mac_rxdatak,
    phy_mac_rxvalid,
    phy_mac_rxstatus,
    phy_mac_rxelecidle,
    phy_mac_phystatus,
    phy_mac_margin_status,
    phy_mac_margin_nak,
    phy_mac_margin_error_cnt,
    phy_mac_margin_sampl_cnt,
    active_nb_wire,
    rplh_rmlh_pkt_err,
    rplh_rmlh_pkt_err_ptr,
    active_nb_gen34,
    cfg_no_seed_value_change,
    cxl_mode_enable,
    rplh_cxl_corr_pid_err,
    rplh_cxl_uncorr_pid_err,
    rplh_cxl_unexp_pid_err,
    rplh_cxl_eds_err,
    mac_phy_rate,
    phy_mac_rxdatavalid,
    phy_mac_rxstartblock,
    phy_mac_rxsyncheader,
    cfg_gen3_scrambler_disable,
    cfg_gen3_dc_balance_disable,
    cfg_enter_compliance,
    smlh_ltssm_in_compliance,
    smlh_ltssm_in_rcvrylock,
    phy_mac_rxdata_osfound,
    cfg_tx_precode_req,
    cdm_ras_des_ferr_rec_dis,
    cdm_ras_des_force_rxdetected_en,
    cdm_ras_des_force_rxdetected,
    pm_current_data_rate,
    pre_mac_phy_cclk_rate,

// ---- outputs ---------------
    current_data_rate,
    current_cclk_rate,
    pm_current_data_rate_others,
    pm_current_data_rate_xmlh_xmt,
    pm_current_data_rate_xmlh_scr,
    pm_current_data_rate_rplh_pkf,
    pm_current_data_rate_smlh_sqf,
    pm_current_data_rate_smlh_lnk,
    pm_current_data_rate_smlh_eq,
    pm_current_data_rate_ltssm,
    current_powerdown,
    rpipe_rxdata,
    rpipe_rxdatak,
    rpipe_rxerror_dup,
    rpipe_rxdata_dv,
    rpipe_rxelecidle,
    rpipe_rxdetected,
    rpipe_rxdetect_done,
    rpipe_all_phystatus_asserted,
    rpipe_all_phystatus_deasserted,
    rpipe_margin_status,
    rpipe_margin_nak,
    rpipe_margin_error_cnt,
    rpipe_margin_sampl_cnt,

    rmlh_rcvd_eidle_set,
    rmlh_all_sym_locked,
    act_rmlh_rcvd_eidle_set,
    rmlh_rplh_rxdata,
    rmlh_rplh_rxdatak,
    rmlh_rplh_rxerror,
    rmlh_rplh_dv,
    rmlh_rplh_os_in_datastream,
    rmlh_rplh_search_for_tokens,
    rmlh_rplh_accept_eds_cycle,
    rmlh_rplh_expect_eds,
    rmlh_rplh_rxdata_link_width,
    rmlh_deskew_datastream_bus,
    rmlh_rplh_rcvd_idle_gen12,
    rmlh_deskew_alignment_err,
    rmlh_deskew_complete,
    rpipe_rxerror,
    rmlh_rpipe_rxoverflow,
    rmlh_rpipe_rxunderflow,
    rmlh_rpipe_rxcodeerror,
    rmlh_rpipe_rxdisperror,
    rmlh_rpipe_rxskipadded,
    rmlh_skp_parity_err,
    rmlh_sync_header_err,
    rmlh_framing_err,
    rmlh_framing_err_ptr,
    rmlh_framing_err_l0,
    rmlh_deskew_fifo_ptr,
    latched_rxdetected,
    rmlh_rxvalid_deasserted,
    rmlh_rpipe_rxskipremoved,
    rpipe_rxaligned,
    rmlh_lane_err,
    rmlh_deskew_datastream,
    rmlh_goto_recovery,
    rmlh_gen3_rcvd_4eidle_set,
    act_rmlh_gen3_rcvd_4eidle_set,
    rmlh_descrambled_rxaligned,
    rmlh_descrambled_rxdata_dv,
    rmlh_descrambled_rxdata,
    rmlh_descrambled_rxstartblock,
    rmlh_descrambled_rxdata_osfound,
    rmlh_descrambled_ints0,
    rmlh_descrambled_rxdata_dcb,
    rmlh_deskew_ds_g6,
    rmlh_deskew_fltlog_ctrl_skp_mismatch_bus,
    rmlh_deskew_fltlog_framing_err,
    rmlh_descrambled_ints1,
    rmlh_descrambled_ints2,
    rmlh_descrambled_inskp,
    rmlh_descrambled_ineie,
    rmlh_descrambled_eie_det,
    rmlh_descrambled_insds,
    rmlh_descrambled_rxdatak,
    rmlh_descrambled_rxerror,
    rmlh_descrambled_even_parity,
    rmlh_deskew_ctlskp_rcvd,
    rmlh_deskew_ctlskp_info,
    rmlh_deskew_ctlskp_err,
    rmlh_rcvd_err,
    cfg_lpbk_en,
    cfg_prbs_en,
    clear_prbs_done,
    cfg_prbs_lane_sel,
    rmlh_prbs_done,
    rmlh_prbs_fail,
    rmlh_prbs_started,
    rmlh_prbs_err_cntr,
    rmlh_prbs_unexp_fail
);
parameter INST              = 0;                        // The uniquifying parameter for each port logic instance.
parameter NL                = `CX_NL;                   // Max number of lanes supported
parameter NB                = `CX_NB;                   // Number of symbols (bytes) per clock cycle
parameter NBK               = `CX_NBK;                  // Number of symbols (bytes) per clock cycle for datak
parameter AW                = `CX_ANB_WD;               // Width of the active number of bytes
parameter NW                = `CX_PL_NW;                // Number of 32-bit dwords handled by the datapath each clock.
parameter DW                = (32*NW);                  // Width of datapath in bits.
parameter TP                = `TP;                      // Clock to Q delay (simulator insurance)
parameter L2NL              = NL==1 ? 1 : `CX_LOGBASE2(NL);   // log2 number of NL
localparam EQTS_WD          = 32;                       // content of TS Symbols 6-9
localparam PCNT_WD          = 4;                        // persistency count width
localparam RXSB_WD          = `CX_MAC_SB_WD;            //Width of phy_mac_rxstartblock per lane
localparam RXSH_WD          = `CX_MAC_SH_WD;            //Width of phy_mac_rxsyncheader per lane
localparam DCB_WD           = (NB>=8 ? NB/8 : 1);
localparam OS_WD            = `CX_MAC_SB_WD; // Number of OS width

// -----------------------------------------------------------------------------
// inputs
// -----------------------------------------------------------------------------

input                   pm_block_phystatus;             // Pm request to block detection of phystatus in rmlh_pipe
input                   core_clk;
input                   core_clk_ug;                    // An ungated version of core_clk used to track phystatus during powerdown states
input                   core_rst_n;
input                   smlh_flit_mode_enable;
input   [NL-1:0]        ltssm_l0p_lanes_active;         // LTSSM latched lanes that are active based on the link negotiation
input   [NL-1:0]        ltssm_l0p_last_lanes_active;    // LTSSM latched lanes that are active based on the link negotiation
input   [5:0]           ltssm_l0p_next_link_mode;       // 10000 -- x16, 01000 -- x8, 00100 -- x4, 00010 -- x2, 00001 -- x1
input                   ltssm_in_l0p;                   // LTSSM in l0p state
input                   ltssm_in_l0p_upsize;            // LTSSM in l0p upsize state
input                   xmtbyte_l0p_link_in_training;   // In l0p negotiation
input   [OS_WD-1:0]     xmtbyte_l0p_ts2_sent;           // Sned TS-OSs for l0p
input                   l0p_sris_mode_enabled;          // SRIS enabled or app_sris_mode=1
input                   cfg_deskew_disable;             // Disable the lane-to-lane deskew logic
input                   cfg_ts2_lid_deskew;             // do deskew at the transition from ts2 to Logic_Idle_data transition
input                   cfg_elastic_buffer_mode;        // 0 - nominal half full mode, 1 - empty mode
input                   cfg_fast_link_mode;             // for simulation
input                   cfg_pipe_garbage_data_mode;     // 0 - discard garbage data until Rxvalid is de-asserted 1: until next valid data 

// from XMLH
input                   smlh_in_rl0s;                   // ltssm is in Rx.L0s
input   [5:0]           smlh_link_mode;                 // 1000 --- x8 mode, 0100 ---- x4 mode, 0010 ---- x2 mode, 0001 ---- x1 mode
input   [NL-1:0]        smlh_no_turnoff_lanes;          // no turnoff lanes after linkup
input   [NL-1:0]        smlh_lanes_active;              // Which lanes are actively (begin) configured
input   [NL-1:0]        power_saving_lanes_active;      // lanes_active or LTSSM=config -- When LTSSM=config, all lanes are active
input   [NL-1:0]        deskew_lanes_active;            // Which lanes are actively (begin) configured, goes only to deskew logic
input                   smlh_do_deskew;                 // Indicate to the deskew block when it is valid to deskew
input                   smlh_lnknum_match_dis;          // This signal is designed to notify the rmlh block when to enable link number match checking
input                   smlh_link_up;                   // XMLH link is up when asserted.
input                   smlh_link_in_training;
input                   ltssm_rcvr_err_rpt_en;          // Enable rcvr errors, based on LTSSM state
input                   ltssm_clear;                    // clear signal from LTSSM
input   ltssm_state_e   smlh_ltssm_state_wire;          // Current state of Link Training and Status State Machine before FF for high fanout. 
input   ltssm_state_e   smlh_ltssm_last;                // Previous LTSSM State.(not 1cycle before)
input                   ltssm_in_lpbk_active;           // LTSSM is in loopback.active or loopback.exit
input   [1:0]           ltssm_cxl_ll_mod;               // {drift_buffer, common_clk} enabled
input                   drift_buffer_deskew_enable;
input   [(NL*8)-1:0]    drift_buffer_deskew_ptr;
input   [1:0]           ltssm_powerdown;                // From LTSSM indicating power down state (P0/P0s/P1). P2 State is controlled by
input                   ltssm_lpbk_master;              // Loopback master
input                   smlh_ltssm_in_pollconfig;       // this signal enables receiver to detect the polarity and invert if necessary.
input                   smlh_scrambler_disable;         // when asserted, scramble is disabled.
input                   latched_smlh_link_up;
input   [L2NL-1:0]      latched_flip_ctrl;
input   [L2NL-1:0]      smlh_lane_flip_ctrl;
input                   smlh_successful_spd_negotiation;
input   [NL*4-1:0]      smseq_loc_eies_rcvd_bus;
input   [NL-1:0]        smseq_ts1_rcvd_pulse_bus;
input   [NL-1:0]        smseq_ts2_rcvd_pulse_bus;
input   [NL*4-1:0]      smseq_loc_ts2_rcvd_bus;
input   [NL*4-1:0]      smseq_in_skp_bus;
input   [NL-1:0]        smseq_fts_skp_do_deskew_bus;

// from PIPE Phy
input   [(NL*NB*8)-1:0] phy_mac_rxdata;                 // PHY_mac* interface is designed for PIPE spec. receive interface. data contains the pkt data
input   [(NL*NB)-1:0]   phy_mac_rxdatak;                // K char indication
input   [NL-1:0]        phy_mac_rxvalid;                // PIPE receive data valid signal
input   [(NL*3)-1:0]    phy_mac_rxstatus;               // PIPE receive status
input   [NL-1:0]        phy_mac_rxelecidle;             // PIPE receive RX electrical idle signal
input   [NL-1:0]        phy_mac_phystatus;              // PIPE PHY status signal
input   [NL-1:0]        phy_mac_margin_status;
input   [NL-1:0]        phy_mac_margin_nak;
input   [(NL*6)-1:0]    phy_mac_margin_error_cnt;
input   [(NL*7)-1:0]    phy_mac_margin_sampl_cnt;
input   [AW-1:0]        active_nb_wire;                 // active number of symbols. bit0=1s, bit1=2s, bit2=4s, bit3=8s before FF for high fanout.
input                   rplh_rmlh_pkt_err;              // Framing error indication
input   [4:0]           rplh_rmlh_pkt_err_ptr;          // Framing error pointer indication
input   [AW-1:0]        active_nb_gen34;                // active number of symbols for gen34. bit0=1s, bit1=2s, bit2=4s, bit3=8s
input                   cfg_no_seed_value_change;       // no seed value change for gen3 scrambler after linkup
input                   cxl_mode_enable;                // Indicates whether the link should operate in CXL or PCIe mode
input                   rplh_cxl_corr_pid_err;          // Correctable protocol ID error
input                   rplh_cxl_uncorr_pid_err;        // Uncorrectable protocol ID error
input                   rplh_cxl_unexp_pid_err;         // Unexpected protocol ID error
input                   rplh_cxl_eds_err;               // EDS error
input   [2:0]           mac_phy_rate;                   // requested rate change from MAC to PHY
input   [NL-1:0]        phy_mac_rxdatavalid;            //Rx dataskip
input  [NL*RXSB_WD-1:0] phy_mac_rxstartblock;           //Rx startblock
input  [NL*RXSH_WD-1:0] phy_mac_rxsyncheader;           //Rx syncheader
input                   cfg_gen3_scrambler_disable;     //1-fully disable gen3 scrambler
input                   cfg_gen3_dc_balance_disable;    //1-disable DC balance function
input                   cfg_enter_compliance;           //Enter Compliance bit in LC2
input                   smlh_ltssm_in_compliance;
input                   smlh_ltssm_in_rcvrylock;
input  [NL-1:0][RXSB_WD-1:0][4:0] phy_mac_rxdata_osfound;
input                   cfg_tx_precode_req;            // Tx precoding request
input                   cdm_ras_des_ferr_rec_dis;      // Disable Recovery state transition at Framing Error
input                   cdm_ras_des_force_rxdetected_en;     // Force Detect Lane Num
input   [NL-1:0]        cdm_ras_des_force_rxdetected;        // Force Detect Lane Num
input   [2:0]           pm_current_data_rate;           // current_data_rate shadowed in pm_ctrl
input   [2:0]           pre_mac_phy_cclk_rate;

// -----------------------------------------------------------------------------
// outputs
// -----------------------------------------------------------------------------

// To the Phy
output  [(NL*NB*8)-1:0] rpipe_rxdata;
output  [(NL*NBK)-1:0]  rpipe_rxdatak;
output  [(NL*NB)-1:0]   rpipe_rxerror_dup;
output  [NL-1:0]        rpipe_rxdata_dv;                //
output  [NL-1:0]        rpipe_rxelecidle;               // RCVR rx electrical idle indication
output  [NL-1:0]        rpipe_rxdetected;               // RCVR rx detected
output                  rpipe_rxdetect_done;            // RCVR rx detection done signal designed for LTSSM to make the next transition from detect_active state
output                  rpipe_all_phystatus_asserted;   // RMLH pipe module monitors the phy_mac_phystatus for all lanes and generated this signal when all lanes are in agreement
output                  rpipe_all_phystatus_deasserted; // RMLH pipe module monitors the phy_mac_phystatus for all lanes and generated this signal when all lanes are in agreement
output  [NL-1:0]        rpipe_margin_status;
output  [NL-1:0]        rpipe_margin_nak;
output  [(NL*6)-1:0]    rpipe_margin_error_cnt;
output  [(NL*7)-1:0]    rpipe_margin_sampl_cnt;

// to XMLH
output                  rmlh_all_sym_locked;            // symbol locked on all active lanes

output                  rmlh_rcvd_eidle_set;            // receiver rcvd eidle set.
output  [NL-1:0]        act_rmlh_rcvd_eidle_set;        // receiver rcvd eidle set per lane.
output  [2:0]           current_data_rate;              // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4
output  [2:0]           current_cclk_rate;
output  [2:0]           pm_current_data_rate_others;    // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4
output  [2:0]           pm_current_data_rate_xmlh_xmt;  // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4
output  [2:0]           pm_current_data_rate_xmlh_scr;  // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4
output  [2:0]           pm_current_data_rate_rplh_pkf;  // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4
output  [2:0]           pm_current_data_rate_smlh_sqf;  // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4
output  [2:0]           pm_current_data_rate_smlh_lnk;  // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4
output  [2:0]           pm_current_data_rate_smlh_eq;   // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4
output  [2:0]           pm_current_data_rate_ltssm;     // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4


output  [1:0]           current_powerdown;              // PHY changed powerdown

// to RPLH
output  [(NL*NB*8)-1:0] rmlh_rplh_rxdata;
output  [(NL*NB)-1:0]   rmlh_rplh_rxdatak;
output  [(NL*NB)-1:0]   rmlh_rplh_rxerror;
output                  rmlh_rplh_dv;
output                  rmlh_rplh_os_in_datastream;
output                  rmlh_rplh_search_for_tokens;
output                  rmlh_rplh_accept_eds_cycle;
output                  rmlh_rplh_expect_eds;
output  [4:0]           rmlh_rplh_rxdata_link_width;
output  [NL-1:0]        rmlh_deskew_datastream_bus;     // Rx is in Data Stream
output  [1:0]           rmlh_rplh_rcvd_idle_gen12;

output                  rmlh_rcvd_err;                  // other receive errors detected (not necessary within a pkt)
output                  rmlh_deskew_alignment_err;      // Lanes fell out of alignement
output                  rmlh_deskew_complete;           // Lanes are deskewed
output  [NL-1:0]        rpipe_rxerror;                  // when asserted, RMLH indicates that the receiver has detected an rx disparity or code error
output  [NL-1:0]        rmlh_rpipe_rxoverflow;          // Indicates elastic buffer overflow error status if the corresponding lane detected a lane-based error
output  [NL-1:0]        rmlh_rpipe_rxunderflow;         // Indicates elastic buffer underflow error status if the corresponding lane detected a lane-based error
output  [NL-1:0]        rmlh_rpipe_rxcodeerror;         // Indicates symbol error status if the corresponding lane detected a lane-based error
output  [NL-1:0]        rmlh_rpipe_rxdisperror;         // Indicates running disparity error if the corresponding lane detected a lane-based error
output  [NL-1:0]        rmlh_rpipe_rxskipadded;         // Indicates skip added in elastic buffer
output  [NL-1:0]        rmlh_skp_parity_err;            // Indicates skip ordered set parity error
output  [NL-1:0]        rmlh_sync_header_err;           // Indicates sync header undefined error
output                  rmlh_framing_err;               // Indicates framing error in gen3 rate
output  [6:0]           rmlh_framing_err_ptr;           // Indicates framing error pointer in gen3 rate
output                  rmlh_framing_err_l0;            // Pulse: Rx framing error in gen3 rate when L0 state
output  [(NL*8)-1:0]    rmlh_deskew_fifo_ptr;           // Indicates rx deskew pointer address
output  [NL-1:0]        latched_rxdetected;             // Indicates the number of valid lane
output  [NL-1:0]        rmlh_rxvalid_deasserted;        // Indicates rx valid deasserted without EIOS
output  [NL-1:0]        rmlh_rpipe_rxskipremoved;       // Indicates skip removed in elastic buffer
output  [NL-1:0]        rpipe_rxaligned;                // Indicates rxvalid asserted
output  [NL-1:0]        rmlh_lane_err;                  // Indicates if the corresponding lane detected a lane-based error
output                  rmlh_deskew_datastream;         // Rx is in Data Stream
output                  rmlh_goto_recovery;             // an EIEOS is received on any configured Lane in 128b/130b encoding, move from L0 to Recovery.
output                  rmlh_gen3_rcvd_4eidle_set;      // in Loopback.Active state
output  [NL-1:0]        act_rmlh_gen3_rcvd_4eidle_set;  // in Loopback.Active state per lane
output  [NL-1:0]        rmlh_descrambled_rxaligned;     // indicates rxvalid
output  [NL -1:0]       rmlh_descrambled_rxdata_dv;
output  [(NL*NB*8)-1:0] rmlh_descrambled_rxdata;
output  [(NL*RXSB_WD)-1:0] rmlh_descrambled_rxstartblock;
output  [NL-1:0][RXSB_WD-1:0][4:0] rmlh_descrambled_rxdata_osfound;
output  [(NL*RXSB_WD)-1:0] rmlh_descrambled_ints0;
output  [(NL*DCB_WD)-1:0]  rmlh_descrambled_rxdata_dcb; // DC balacne symbol
output  [NL-1:0]           rmlh_deskew_ds_g6;           // gen6 rx in data stream
output  [NL-1:0]           rmlh_deskew_fltlog_ctrl_skp_mismatch_bus;
output                     rmlh_deskew_fltlog_framing_err;
output  [(NL*RXSB_WD)-1:0] rmlh_descrambled_ints1;
output  [(NL*RXSB_WD)-1:0] rmlh_descrambled_ints2;
output  [(NL*RXSB_WD)-1:0] rmlh_descrambled_inskp;
output  [(NL*RXSB_WD)-1:0] rmlh_descrambled_ineie;
output  [(NL*RXSB_WD)-1:0] rmlh_descrambled_eie_det;
output  [(NL*RXSB_WD)-1:0] rmlh_descrambled_insds;
output  [(NL*NBK)-1:0]  rmlh_descrambled_rxdatak;
output  [(NL*NB)-1:0]   rmlh_descrambled_rxerror;
output  [NL-1:0]        rmlh_descrambled_even_parity;    // Current rx skip even data parity from RMLH
output  [NL-1:0]        rmlh_deskew_ctlskp_rcvd;         // Received Control SKP-OS
output  [(NL*16)-1:0]   rmlh_deskew_ctlskp_info;         // Margin Control/Status within CTL-skp-os
output  [(NL*5)-1:0]    rmlh_deskew_ctlskp_err;          // CTL-SKP-OS error [0]data parity[1]1st retimer parity [2]2nd retimer parity[3]margin crc[4]margin parity
input                   cfg_lpbk_en;
input                   cfg_prbs_en;
input                   clear_prbs_done;
input   [3:0]           cfg_prbs_lane_sel;
output                  rmlh_prbs_done;                      // PRBS Loopback Done
output                  rmlh_prbs_fail;                      // PRBS Loopback comparison error occurred
output  [NL-1:0]        rmlh_prbs_started;             // PRBS Loopback started
output  [NL-1:0][7:0]           rmlh_prbs_err_cntr;             // Num of PRBS Loopback comparison error
output  [NL-1:0]                rmlh_prbs_unexp_fail;         // PRBS Unexpected error occurred

wire                    rmlh_deskew_bypass;
wire                    rmlh_deskew_rxdata_dv;
wire    [(NL*NB*8)-1:0] rmlh_deskew_rxdata;
wire    [(NL*NB)-1:0]   rmlh_deskew_rxdatak;
wire    [(NL*NB)-1:0]   rmlh_deskew_rxerror;
wire                    rmlh_deskew_alignment_err;
wire                    rmlh_deskew_complete;
wire                    rmlh_deskew_rxdata_flush_gen12;  // active high RX data flushing to pkt_finer for Gen1/2 rate
wire    [NL-1:0]        rmlh_deskew_ds_g6;               // gen6 rx in data stream

// Scramble logic
wire    [(NL*NB*8)-1:0] descrambled_rxdata;
wire    [NL -1:0]       descrambled_rxdata_dv;
wire    [NL -1:0]       descrambled_rxaligned;
wire    [(NL*NB)-1:0]   descrambled_rxdata_comma;
wire    [(NL*NB)-1:0]   descrambled_rxdata_skip;
wire    [(NL*NB)-1:0]   descrambled_rxdata_skprm;
wire    [(NL*NBK)-1:0]  descrambled_rxdatak;
wire    [(NL*NB)-1:0]   descrambled_rxerror;

wire    [NL-1:0]        rpipe_rxerror;
wire    [NL-1:0]        tmp_phy_err;
wire                    rmlh_rcvd_err;
wire  [NL-1:0]          rpipe_rxaligned;              // direct from phy_mac_rxvalid. gates: must revisit
wire                  rmlh_deskew_datastream;
wire  [(NL*RXSB_WD)-1:0] rpipe_rxstartblock;           //start block marker

wire  [(NL*RXSB_WD)-1:0] descrambled_rxstartblock;     //start block after scramble
wire  [(NL*RXSB_WD)-1:0] descrambled_rxeven_parity;    //accumulated SKP parity in Rx side
wire  [(NL*RXSB_WD)-1:0] descrambled_inskp;            //SKP indicator
wire  [NL-1:0][RXSB_WD-1:0][4:0] descrambled_rxdata_osfound;   //OS Detection flag
wire  [(NL*RXSB_WD)-1:0] descrambled_ints0;            //TS0 indicator
wire  [(NL*DCB_WD)-1:0]  descrambled_rxdata_dcb;       //DC balance symbols indicator
wire  [(NL*RXSB_WD)-1:0] descrambled_rxdata_g6_skprm;  //SKIP removed
wire  [(NL*RXSB_WD)-1:0] descrambled_rxdata_g6_skpadd; //SKIP added
wire  [(NL*RXSB_WD)-1:0] descrambled_ints1;            //TS1 indicator
wire  [(NL*RXSB_WD)-1:0] descrambled_ints2;            //TS2 indicator
wire  [(NL*RXSB_WD)-1:0] descrambled_ineie;            //EIEOS indicator
wire  [(NL*RXSB_WD)-1:0] descrambled_eie_det;          //EIEOS detected
wire  [(NL*RXSB_WD)-1:0] descrambled_insds;            //SDS indicator


wire                  rmlh_deskew_os_in_datastream; // os detected
wire                  rxpkt_error;                  // Packet Framing Error
wire                  rmlh_deskew_accept_eds_cycle; // accept EDS
wire                  rmlh_deskew_expect_eds;       // Signal to inform token_finder that EDS is expected
wire                  rmlh_deskew_search_for_tokens;// Search for tokens
wire  [4:0]           rmlh_deskew_rxdata_link_width;// Link width
wire  [6:0]           rmlh_deskew_framing_err_ptr;
wire                  rmlh_deskew_framing_err;
wire                  rmlh_framing_err;             // framing error in gen3 rate
wire  [NL-1:0]        rmlh_descrambled_rxdata_dv;
wire  [(NL*NB*8)-1:0] rmlh_descrambled_rxdata;
wire  [(NL*RXSB_WD)-1:0] rmlh_descrambled_rxstartblock;
wire  [NL-1:0][RXSB_WD-1:0][4:0] rmlh_descrambled_rxdata_osfound;
wire  [(NL*RXSB_WD)-1:0] rmlh_descrambled_ints0;
wire  [(NL*DCB_WD)-1:0]  rmlh_descrambled_rxdata_dcb;
wire  [(NL*RXSB_WD)-1:0] rmlh_descrambled_ints1;
wire  [(NL*RXSB_WD)-1:0] rmlh_descrambled_ints2;
wire  [(NL*RXSB_WD)-1:0] rmlh_descrambled_inskp;
wire  [(NL*RXSB_WD)-1:0] rmlh_descrambled_ineie;
wire  [(NL*RXSB_WD)-1:0] rmlh_descrambled_eie_det;
wire  [(NL*RXSB_WD)-1:0] rmlh_descrambled_insds;
wire  [(NL*NBK)-1:0]  rmlh_descrambled_rxdatak;
wire  [(NL*NB)-1:0]   rmlh_descrambled_rxerror;
wire  [NL-1:0]        rmlh_descrambled_rxaligned;
assign                rmlh_descrambled_rxdata_dv        = descrambled_rxdata_dv;
assign                rmlh_descrambled_rxdata           = descrambled_rxdata;
assign                rmlh_descrambled_rxstartblock     = descrambled_rxstartblock;
assign                rmlh_descrambled_rxdata_osfound   = descrambled_rxdata_osfound ;
assign                rmlh_descrambled_ints0            = descrambled_ints0;
assign                rmlh_descrambled_rxdata_dcb       = descrambled_rxdata_dcb;
assign                rmlh_descrambled_ints1            = descrambled_ints1;
assign                rmlh_descrambled_ints2            = descrambled_ints2;
assign                rmlh_descrambled_inskp            = descrambled_inskp;
assign                rmlh_descrambled_ineie            = descrambled_ineie;
assign                rmlh_descrambled_eie_det          = descrambled_eie_det;
assign                rmlh_descrambled_insds            = descrambled_insds;
assign                rmlh_descrambled_rxdatak          = descrambled_rxdatak;
assign                rmlh_descrambled_rxerror          = descrambled_rxerror;
assign                rmlh_descrambled_rxaligned        = descrambled_rxaligned;

assign                rmlh_framing_err_ptr              = rmlh_deskew_framing_err_ptr;
assign                rmlh_framing_err                  = rmlh_deskew_framing_err
                                                        | rplh_cxl_corr_pid_err   // CXL Receiver error without Recovery entry
                                                        ;

// Pipe-line of smlh_ltssm_state/active_nb for high fanout. 
// The smlh_ltssm_state_wire/active_nb_wire are a combinational signal(before FF). So, no timing change by this pipe-line.
ltssm_state_e            smlh_ltssm_state ;
reg    [AW-1:0]          active_nb ;

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

// Decoded signals from PIPE
wire    [NL-1:0]        rpipe_rxelecidle;
wire    [(NL*NB*8)-1:0] rpipe_rxdata;
wire    [(NL*NBK)-1:0]  rpipe_rxdatak;
wire    [NL-1:0]        rpipe_rxdata_dv;
wire    [NL-1:0][RXSB_WD-1:0][4:0]   rpipe_rxdata_osfound;
wire    [NL-1:0]        rpipe_rxskipadded;
wire                    rpipe_eios_eieos_det;
wire    [NL-1:0]        rpipe_rxskipremoved;
wire    [NL-1:0]        rpipe_rxcodeerror;
wire    [NL-1:0]        rpipe_rxdisperror;
wire    [NL-1:0]        rpipe_rxunderflow;
wire    [NL-1:0]        rpipe_rxoverflow;
wire    [2:0]           current_data_rate;
wire    [2:0]           pm_current_data_rate_others;
wire    [2:0]           pm_current_data_rate_xmlh_xmt;
wire    [2:0]           pm_current_data_rate_xmlh_scr;
wire    [2:0]           pm_current_data_rate_rmlh_dsk;
wire    [2:0]           pm_current_data_rate_rmlh_scr;
wire    [2:0]           pm_current_data_rate_rplh_pkf;
wire    [2:0]           pm_current_data_rate_smlh_sqf;
wire    [2:0]           pm_current_data_rate_smlh_lnk;
wire    [2:0]           pm_current_data_rate_smlh_eq;
wire    [2:0]           pm_current_data_rate_ltssm;


// Turn off disparity error when using RocketIO PHY
    assign rpipe_rxerror   = (rpipe_rxcodeerror | rpipe_rxdisperror);
assign tmp_phy_err     = (deskew_lanes_active & rpipe_rxerror);

reg rmlh_rcvd_err_d;
always @(posedge core_clk or negedge core_rst_n)
begin : latch_rmlh_rcvd_err
  if (!core_rst_n)
    rmlh_rcvd_err_d <= #TP 0;
  else
    rmlh_rcvd_err_d <= #TP 
                           rmlh_framing_err | //framing error generated in Data Stream in gen3 rate. no need of ltssm_rcvr_err_rpt_en
                           ((|tmp_phy_err) & ltssm_rcvr_err_rpt_en & (pm_current_data_rate_rmlh_dsk < `GEN3_RATE)); // only 8b10b error is required to be reported
end

assign rmlh_rcvd_err   = rmlh_rcvd_err_d;

// Reversed data buses
wire    [(NL*NB*8)-1:0] rmlh_reversed_rxdata;
wire                    rmlh_reversed_rxdata_dv;
wire    [(NL*NB)-1:0]   rmlh_reversed_rxdatak;
wire    [(NL*NB)-1:0]   rmlh_reversed_rxerror;

// PIPE only provides one error per symbol time, rest of core supports 1 per symbol. Duplicate here.
reg     [(NL*NB)-1:0]   rpipe_rxerror_dup;
always @(rpipe_rxerror)
begin : duplicate_rxerror
    integer ln, sym;
    for (ln=0; ln<NL; ln=ln+1)
        for (sym=0; sym<NB; sym=sym+1)
            rpipe_rxerror_dup[ln*NB+sym] = rpipe_rxerror[ln];
end

wire rpipe_gen3_rcvd_4eidle_set;
wire rmlh_gen3_rcvd_4eidle_set;
assign rmlh_gen3_rcvd_4eidle_set = rpipe_gen3_rcvd_4eidle_set;

wire rmlh_framing_err_l0;
assign rmlh_framing_err_l0 = rmlh_framing_err & (smlh_ltssm_state == S_L0) ;

wire rmlh_deskew_fltlog_framing_err;
assign rmlh_deskew_fltlog_framing_err = rmlh_framing_err ;


wire rpipe_all_sym_locked;
wire rmlh_all_sym_locked;
assign rmlh_all_sym_locked = rpipe_all_sym_locked;

// convert pipe inputs to our internal signals
rmlh_pipe
 #(INST) u_rmlh_pipe(
// ---- inputs ---------------
    .pm_block_phystatus             (pm_block_phystatus),
    .core_rst_n                     (core_rst_n),
    .core_clk                       (core_clk),
    .core_clk_ug                    (core_clk_ug),
    .cfg_elastic_buffer_mode        (cfg_elastic_buffer_mode),
    .cfg_pipe_garbage_data_mode     (cfg_pipe_garbage_data_mode),
    .ltssm_clear                    (ltssm_clear),
    .ltssm_powerdown                (ltssm_powerdown),
    .smlh_ltssm_state               (smlh_ltssm_state),
    .mac_phy_rate                   (mac_phy_rate),
    .phy_mac_rxdata                 (phy_mac_rxdata),
    .phy_mac_rxdatak                (phy_mac_rxdatak),
    .phy_mac_rxvalid                (phy_mac_rxvalid),
    .phy_mac_rxdatavalid            (phy_mac_rxdatavalid),
    .phy_mac_rxstartblock           (phy_mac_rxstartblock),
    .phy_mac_rxsyncheader           (phy_mac_rxsyncheader),
    .phy_mac_rxdata_osfound         (phy_mac_rxdata_osfound),
    .deskew_ds_g6                   (rmlh_deskew_ds_g6),
    .phy_mac_rxstatus               (phy_mac_rxstatus),
    .phy_mac_rxelecidle             (phy_mac_rxelecidle),
    .phy_mac_phystatus              (phy_mac_phystatus),
    .phy_mac_margin_status          (phy_mac_margin_status),
    .phy_mac_margin_nak             (phy_mac_margin_nak),
    .phy_mac_margin_error_cnt       (phy_mac_margin_error_cnt),
    .phy_mac_margin_sampl_cnt       (phy_mac_margin_sampl_cnt),
    .smlh_lanes_active              (smlh_lanes_active),
    .smlh_link_up                   (smlh_link_up),
    .smlh_no_turnoff_lanes          (smlh_no_turnoff_lanes),
    .active_nb                      (active_nb),
    .cdm_ras_des_force_rxdetected_en (cdm_ras_des_force_rxdetected_en),
    .cdm_ras_des_force_rxdetected   (cdm_ras_des_force_rxdetected),
    .pm_current_data_rate           (pm_current_data_rate),
    .pre_mac_phy_cclk_rate          (pre_mac_phy_cclk_rate),


// ---- outputs ---------------
    .current_data_rate              (current_data_rate),
    .current_cclk_rate              (current_cclk_rate),
    .current_data_rate_others       (pm_current_data_rate_others),
    .current_data_rate_xmlh_xmt     (pm_current_data_rate_xmlh_xmt),
    .current_data_rate_xmlh_scr     (pm_current_data_rate_xmlh_scr),
    .current_data_rate_rmlh_dsk     (pm_current_data_rate_rmlh_dsk),
    .current_data_rate_rmlh_scr     (pm_current_data_rate_rmlh_scr),
    .current_data_rate_rmlh_pkf     (pm_current_data_rate_rplh_pkf),
    .current_data_rate_smlh_sqf     (pm_current_data_rate_smlh_sqf),
    .current_data_rate_smlh_lnk     (pm_current_data_rate_smlh_lnk),
    .current_data_rate_smlh_eq      (pm_current_data_rate_smlh_eq),
    .current_data_rate_ltssm        (pm_current_data_rate_ltssm),
    .current_powerdown              (current_powerdown),
    .rpipe_rxdata                   (rpipe_rxdata),
    .rpipe_rxdatak                  (rpipe_rxdatak),
    .rpipe_rxdata_dv                (rpipe_rxdata_dv),
    .rpipe_rxaligned                (rpipe_rxaligned),    //gates: must revisit
    .rpipe_rxstartblock             (rpipe_rxstartblock),
    .rpipe_gen3_rcvd_4eidle_set     (rpipe_gen3_rcvd_4eidle_set),
    .act_rpipe_gen3_rcvd_4eidle_set (act_rmlh_gen3_rcvd_4eidle_set),
    .rpipe_out_rxdata_osfound       (rpipe_rxdata_osfound),
    .rpipe_rxskipadded              (rpipe_rxskipadded),
    .rpipe_rxskipremoved            (rpipe_rxskipremoved),
    .rpipe_all_sym_locked           (rpipe_all_sym_locked),
    .rpipe_rxcodeerror              (rpipe_rxcodeerror),
    .rpipe_rxdisperror              (rpipe_rxdisperror),
    .rpipe_rxunderflow              (rpipe_rxunderflow),
    .rpipe_rxoverflow               (rpipe_rxoverflow),
    .rpipe_rxelecidle               (rpipe_rxelecidle),
    .rpipe_rcvd_eidle_set           (rmlh_rcvd_eidle_set),
    .rpipe_eios_eieos_det           (rpipe_eios_eieos_det),
    .act_rpipe_rcvd_eidle_set       (act_rmlh_rcvd_eidle_set),
    .rpipe_rxdetected               (rpipe_rxdetected),
    .rpipe_rxdetect_done            (rpipe_rxdetect_done),
    .rpipe_all_phystatus_asserted   (rpipe_all_phystatus_asserted),
    .rpipe_all_phystatus_deasserted (rpipe_all_phystatus_deasserted)
    ,
    .rpipe_margin_status            (rpipe_margin_status),
    .rpipe_margin_nak               (rpipe_margin_nak),
    .rpipe_margin_error_cnt         (rpipe_margin_error_cnt),
    .rpipe_margin_sampl_cnt         (rpipe_margin_sampl_cnt)
    ,
    .latched_rxdetected             (latched_rxdetected),
    .rmlh_rxvalid_deasserted        (rmlh_rxvalid_deasserted)
); //rmlh_pipe

// Event Counter
assign rmlh_rpipe_rxoverflow     =  rpipe_rxoverflow    ;
assign rmlh_rpipe_rxunderflow    =  rpipe_rxunderflow   ;
assign rmlh_rpipe_rxcodeerror    =  rpipe_rxcodeerror   ;
assign rmlh_rpipe_rxdisperror    =  rpipe_rxdisperror   ;
assign rmlh_rpipe_rxskipadded    =  rpipe_rxskipadded   ;
assign rmlh_rpipe_rxskipremoved  =  rpipe_rxskipremoved ;

// Lane-to-Lane Deskew Logic Bypass.
assign rmlh_deskew_bypass =                            (pm_current_data_rate_rmlh_dsk == `GEN3_RATE || pm_current_data_rate_rmlh_dsk == `GEN4_RATE || pm_current_data_rate_rmlh_dsk == `GEN5_RATE || pm_current_data_rate_rmlh_dsk == `GEN6_RATE) ? 1'b0 : // Bypass not allowed at Gen3/Gen4 Rate
                            (smlh_flit_mode_enable) ? 1'b0 : // Bypass not allowed in flit mode 
                            (`CX_DESKEW_DISABLE)                                                                                 ? 1'b1 : // PHY performs Lane-to-Lane Deskew (Gen1/Gen2 Rate)
                                                                                                                     cfg_deskew_disable ; // Deskew Disable bit in Lane Skew Port Logic Register

assign rxpkt_error = rplh_rmlh_pkt_err | rplh_cxl_unexp_pid_err | rplh_cxl_uncorr_pid_err | rplh_cxl_eds_err;

rmlh_deskew
 #(INST) u_rmlh_deskew (
// ---- inputs ---------------
    .core_rst_n                       (core_rst_n),
    .core_clk                         (core_clk),
    .cfg_elastic_buffer_mode          (cfg_elastic_buffer_mode),
    .cfg_ts2_lid_deskew               (cfg_ts2_lid_deskew),
    .prbs_en_int                      (prbs_en_int),
    .rmlh_deskew_bypass               (rmlh_deskew_bypass),
    .ltssm_cxl_ll_mod                 (ltssm_cxl_ll_mod),
    .drift_buffer_deskew_enable       (drift_buffer_deskew_enable),
    .drift_buffer_deskew_ptr          (drift_buffer_deskew_ptr),
    .deskew_lanes_active              (deskew_lanes_active),
    .smlh_in_rl0s_i                   (smlh_in_rl0s),
    .smlh_do_deskew_i                 (smlh_do_deskew),
    .smseq_ts1_rcvd_pulse_bus_i       (smseq_ts1_rcvd_pulse_bus),
    .smseq_ts2_rcvd_pulse_bus_i       (smseq_ts2_rcvd_pulse_bus),
    .smseq_loc_ts2_rcvd_bus_i         (smseq_loc_ts2_rcvd_bus),
    .smseq_in_skp_bus_i               (smseq_in_skp_bus),
    .smseq_fts_skp_do_deskew_bus_i    (smseq_fts_skp_do_deskew_bus),
    .smseq_loc_eies_rcvd_bus_i        (smseq_loc_eies_rcvd_bus),
    .active_nb_wire                   (active_nb_wire),
    .rxdata_dv_i                      (descrambled_rxdata_dv),
    .rxaligned_i                      (descrambled_rxaligned),
    .rxdata_i                         (descrambled_rxdata),
    .rxdata_comma_i                   (descrambled_rxdata_comma),
    .rxdata_skip_i                    (descrambled_rxdata_skip),
    .rxdata_skprm_i                   (descrambled_rxdata_skprm),
    .rxdatak_i                        (descrambled_rxdatak),
    .rxerror_i                        (descrambled_rxerror),
    .rxdata_eie_det_i                 (descrambled_eie_det),
    .rxdata_g6_skprm_i                (descrambled_rxdata_g6_skprm),
    .rxdata_g6_skpadd_i               (descrambled_rxdata_g6_skpadd),
    .current_data_rate                (pm_current_data_rate_rmlh_dsk),
    .smlh_ltssm_state_wire            (smlh_ltssm_state_wire),
    .smlh_ltssm_last                  (smlh_ltssm_last),
    .ltssm_lpbk_master_i              (ltssm_lpbk_master),
    .cxl_mode_enable                  (cxl_mode_enable),
    .smlh_flit_mode_enable            (smlh_flit_mode_enable),
    .ltssm_l0p_lanes_active           (ltssm_l0p_lanes_active),
    .ltssm_l0p_last_lanes_active      (ltssm_l0p_last_lanes_active),
    .ltssm_l0p_next_link_mode         (ltssm_l0p_next_link_mode),
    .ltssm_in_l0p                     (ltssm_in_l0p),
    .ltssm_in_l0p_upsize              (ltssm_in_l0p_upsize),
    .xmtbyte_l0p_link_in_training     (xmtbyte_l0p_link_in_training),
    .xmtbyte_l0p_ts2_sent             (xmtbyte_l0p_ts2_sent),
    .rxstartblock_i                   (descrambled_rxstartblock),
    .rxeven_parity_i                  (descrambled_rxeven_parity),
    .rxpkt_error_i                    (rxpkt_error),
    .rxdata_osfound_i                 (descrambled_rxdata_osfound),
    .rxpkt_error_ptr_i                (rplh_rmlh_pkt_err_ptr),
    .cdm_ras_des_ferr_rec_dis         (cdm_ras_des_ferr_rec_dis),
    .rxunderflow_i                    (rpipe_rxunderflow),
    .rxoverflow_i                     (rpipe_rxoverflow),
    .rpipe_eios_eieos_det_i           (rpipe_eios_eieos_det),
// ---- outputs ---------------
    .deskew_rxdata_dv                 (rmlh_deskew_rxdata_dv),
    .deskew_rxdata                    (rmlh_deskew_rxdata),
    .deskew_rxdatak                   (rmlh_deskew_rxdatak),
    .deskew_rxerror                   (rmlh_deskew_rxerror),
    .deskew_search_for_tokens         (rmlh_deskew_search_for_tokens),     // when in S_DATA_STREAM state
    .deskew_rxdata_link_width         (rmlh_deskew_rxdata_link_width),
    .deskew_datastream_bus            (rmlh_deskew_datastream_bus),
    .deskew_datastream                (rmlh_deskew_datastream),
    .deskew_accept_eds_cycle          (rmlh_deskew_accept_eds_cycle),
    .deskew_expect_eds                (rmlh_deskew_expect_eds),
    .deskew_os_in_datastream          (rmlh_deskew_os_in_datastream),
    .deskew_lane_err_bus              (rmlh_lane_err),
    .deskew_lane_err_skp_parity_bus   (rmlh_skp_parity_err),
    .deskew_lane_err_sync_header_bus  (rmlh_sync_header_err),
    .deskew_framing_err_ptr           (rmlh_deskew_framing_err_ptr),
    .deskew_framing_err_o             (rmlh_deskew_framing_err),
    .deskew_goto_recovery             (rmlh_goto_recovery),
    .deskew_ctlskp_rcvd               (rmlh_deskew_ctlskp_rcvd),
    .deskew_ctlskp_info               (rmlh_deskew_ctlskp_info),
    .deskew_ctlskp_err                (rmlh_deskew_ctlskp_err),
    .deskew_fifo_ptr                  (rmlh_deskew_fifo_ptr),
    .deskew_rxdata_flush_gen12        (rmlh_deskew_rxdata_flush_gen12),
    .deskew_ds_g6                     (rmlh_deskew_ds_g6),
    .deskew_fltlog_ctrl_skp_mismatch_bus  (rmlh_deskew_fltlog_ctrl_skp_mismatch_bus),
    .deskew_alignment_err             (rmlh_deskew_alignment_err),
    .deskew_complete                  (rmlh_deskew_complete)
); //rmlh_deskew

// Lane Reversal Logic Bypass.
assign rmlh_reversed_rxdata_dv = rmlh_deskew_rxdata_dv;
assign rmlh_reversed_rxdata    = rmlh_deskew_rxdata;
assign rmlh_reversed_rxdatak   = rmlh_deskew_rxdatak;
assign rmlh_reversed_rxerror   = rmlh_deskew_rxerror;

logic  [NL-1:0]        wait4idle;
logic  [NL-1:0]        wait4idle_nd;
//CALC_PARITY_BEFORE_SCRAMBLE=1 denotes SKP parity calculation done before de-scrambling in Rx side
scramble
 #(.INST(INST), .RX_SIDE(1), .REGOUT(`CX_RMLH_SCRAMBLE_REGOUT), .GEN3_REGIN(`CX_RMLH_GEN3_SCRAMBLE_REGIN), .GEN3_REGOUT(`CX_RMLH_GEN3_SCRAMBLE_REGOUT), .GEN3_LFSR_REGOUT(`CX_RMLH_GEN3_SCRAMBLE_LFSR_REGOUT), .CALC_PARITY_BEFORE_SCRAMBLE(1) ,.PRECODING_REGOUT(`CX_RMLH_PRECODING_REGOUT) , .GLAYCODING_REGOUT(0)) u_scramble (
// ---- inputs ---------------
    .core_rst_n                     (core_rst_n),
    .core_clk                       (core_clk),
    .cfg_elastic_buffer_mode        (cfg_elastic_buffer_mode),
    .scrambler_disable              (smlh_scrambler_disable),
    .scrambler_disable_lanes_l0p    ({NL{1'b0}}),
    .smlh_l0p_link_mode             ({1'b0, rmlh_rplh_rxdata_link_width}),
    .l0p_sris_mode_enabled          (l0p_sris_mode_enabled),
    .data_dv                        (rpipe_rxdata_dv),
    .data                           (rpipe_rxdata),
    .datak                          (rpipe_rxdatak),
    .error                          (rpipe_rxerror_dup),
    .wait4idle                      (wait4idle),
    .data_osfound                   (rpipe_rxdata_osfound),
    .rxskipremoved                  (rpipe_rxskipremoved),
    .rxskipadded                    (rpipe_rxskipadded),
    .gen6_compliance_sending        (1'b0), // Unused on Rx Path
    .active_nb                      (active_nb),
    .aligned                        (rpipe_rxaligned),  //gates: mustt revisit
    .latched_smlh_link_up           (latched_smlh_link_up),
    .latched_flip_ctrl              (latched_flip_ctrl),
    .smlh_lane_flip_ctrl            (smlh_lane_flip_ctrl),
    .cfg_no_seed_value_change       (cfg_no_seed_value_change),
    .active_nb_gen34                (active_nb_gen34),
    .current_data_rate              (pm_current_data_rate_rmlh_scr),
    .cfg_gen3_scrambler_disable     (cfg_gen3_scrambler_disable),
    .cfg_gen3_dc_balance_disable    (1'b1),
    .smlh_link_mode                 (smlh_link_mode),
    .startblock                     (rpipe_rxstartblock),
    .skp_os_align_sts               ( '0 ),              // Unused on Rx Path
    .xmtbyte_txelecidle             ({NL{1'b0}}),
    .ltssm_in_compliance            (1'b0),              // Unused on Rx Path
    .smlh_ltssm_state               (smlh_ltssm_state),
    .cfg_precoding_enable           (cfg_tx_precode_req),
    .smlh_flit_mode_enable          (smlh_flit_mode_enable),
    .lanes_active                   (power_saving_lanes_active),
    .crnt_rate_enc                  ( '0 ),                          // Unused on Rx Path now

// ---- outputs ---------------
    .scramble_lfsr_rollover         (), // only used in transmit
    .scramble_even_parity           (descrambled_rxeven_parity),
    .scramble_startblock            (descrambled_rxstartblock),
    .scramble_data_osfound          (descrambled_rxdata_osfound),
    .scramble_ints0                 (descrambled_ints0),
    .scramble_dcb_det               (descrambled_rxdata_dcb),
    .scramble_data_g6_skprm         (descrambled_rxdata_g6_skprm),
    .scramble_data_g6_skpadd        (descrambled_rxdata_g6_skpadd),
    .scramble_ints1                 (descrambled_ints1),
    .scramble_ints2                 (descrambled_ints2),
    .scramble_inskp                 (descrambled_inskp),
    .scramble_ineie                 (descrambled_ineie),
    .scramble_eie_det               (descrambled_eie_det),
    .scramble_insds                 (descrambled_insds),
    .scramble_skp_os_align_sts      (), // only used in transmit
    .scramble_data_dv               (descrambled_rxdata_dv),
    .scramble_aligned               (descrambled_rxaligned),
    .scramble_data                  (descrambled_rxdata),
    .scramble_data_comma            (descrambled_rxdata_comma),
    .scramble_data_skip             (descrambled_rxdata_skip),
    .scramble_data_skprm            (descrambled_rxdata_skprm),
    .scramble_datak                 (descrambled_rxdatak),
    .scramble_error                 (descrambled_rxerror),
    .wait4idle_nd                   (wait4idle_nd)
); //scramble

rmlh_prbs
  u_rmlh_prbs (
   .core_clk                    (core_clk)
  ,.core_rst_n                  (core_rst_n)

  ,.current_data_rate           (current_data_rate)
  ,.smlh_ltssm_state            (smlh_ltssm_state)
  ,.smlh_lanes_active           (smlh_lanes_active)
  ,.ltssm_in_lpbk_active        (ltssm_in_lpbk_active)
  ,.ltssm_lpbk_master           (ltssm_lpbk_master)
  ,.active_nb                   (active_nb[2:0])
  ,.cfg_lpbk_en                 (cfg_lpbk_en)
  ,.cfg_prbs_en                 (cfg_prbs_en)
  ,.clear_prbs_done             (clear_prbs_done)
  ,.cfg_prbs_lane_sel           (cfg_prbs_lane_sel)
  ,.rpipe_rxdata_dv             (rpipe_rxdata_dv)
  ,.rpipe_rxdata                (rpipe_rxdata)
  ,.rpipe_rxdatak               (rpipe_rxdatak)
  ,.wait4idle_nd                (wait4idle_nd)
  ,.descrambled_rxdata_dv       (descrambled_rxdata_dv[NL-1:0])
  ,.descrambled_rxdata          (descrambled_rxdata[(NL*NB*8)-1:0])
  ,.descrambled_rxdatak         (descrambled_rxdatak[(NL*NBK)-1:0])
  ,.descrambled_rxstartblock    (descrambled_rxstartblock[(NL*RXSB_WD)-1:0])
  ,.descrambled_rxdata_osfound  (descrambled_rxdata_osfound)

  ,.rmlh_prbs_done               (rmlh_prbs_done)
  ,.rmlh_prbs_fail               (rmlh_prbs_fail)
  ,.prbs_started                 (rmlh_prbs_started)
  ,.prbs_err_cntr                (rmlh_prbs_err_cntr)
  ,.prbs_unexp_fail              (rmlh_prbs_unexp_fail)
  ,.wait4idle                    (wait4idle)
  ,.prbs_en_int                  (prbs_en_int)
);

reg [NL-1:0]                      int_rmlh_descrambled_even_parity;
always @(*) begin
  integer ln;
  for (ln=0; ln<NL; ln=ln+1) begin
      int_rmlh_descrambled_even_parity[ln] = descrambled_rxeven_parity[(ln+1)*RXSB_WD-1];
  end // for-loop
end
assign rmlh_descrambled_even_parity = int_rmlh_descrambled_even_parity;


rmlh_byte_order
 #(INST) u_rmlh_byte_order (
// ---- inputs ---------------
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .smlh_link_mode                 (smlh_link_mode),
    .deskew_lanes_active            (deskew_lanes_active),
    .active_nb                      (active_nb[3:0]),
    .rxdata_flush_gen12_in          (rmlh_deskew_rxdata_flush_gen12),
    .rxdata_dv_in                   (rmlh_reversed_rxdata_dv),
    .rxdata_in                      (rmlh_reversed_rxdata),
    .rxdatak_in                     (rmlh_reversed_rxdatak),
    .rxerror_in                     (rmlh_reversed_rxerror),
    .current_data_rate              (pm_current_data_rate_rplh_pkf),
    .search_for_tokens              (rmlh_deskew_search_for_tokens),
    .accept_eds_cycle               (rmlh_deskew_accept_eds_cycle),
    .expect_eds                     (rmlh_deskew_expect_eds),
    .os_in_datastream               (rmlh_deskew_os_in_datastream),
    .rxdata_link_width              (rmlh_deskew_rxdata_link_width),
    .smlh_flit_mode_enable          (smlh_flit_mode_enable),
// ---- outputs ---------------
    .rmlh_rplh_rxdata               (rmlh_rplh_rxdata),
    .rmlh_rplh_rxdatak              (rmlh_rplh_rxdatak),
    .rmlh_rplh_rxerror              (rmlh_rplh_rxerror),
    .rmlh_rplh_dv                   (rmlh_rplh_dv),
    .rmlh_rplh_os_in_datastream     (rmlh_rplh_os_in_datastream),
    .rmlh_rplh_search_for_tokens    (rmlh_rplh_search_for_tokens),
    .rmlh_rplh_accept_eds_cycle     (rmlh_rplh_accept_eds_cycle),
    .rmlh_rplh_expect_eds           (rmlh_rplh_expect_eds),
    .rmlh_rplh_rxdata_link_width    (rmlh_rplh_rxdata_link_width),
    .rmlh_rplh_rcvd_idle_gen12      (rmlh_rplh_rcvd_idle_gen12)
); //rmlh_byte_order



endmodule
