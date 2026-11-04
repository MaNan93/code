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
// ---    $Revision: #11 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/lane_flip.sv#11 $
// -------------------------------------------------------------------------
// --- Module Description: 
// --- Container module for all the mux logic for flipping the lanes.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"


 module lane_flip #(
    parameter REGIN = `CX_LANEFLIP_RX_REGIN,
    parameter REGOUT = `CX_LANEFLIP_TX_REGOUT,
    parameter NL = `CX_NL,
    parameter L2NL = NL==1 ? 1 : `CX_LOGBASE2(NL),  // log2 number of NL
    parameter NB = `CX_NB,
    parameter TXSB_WD = `CX_PHY_TXSB_WD,
    parameter TXSH_WD = `CX_PHY_TXSH_WD,
    parameter RXSB_WD = `CX_MAC_SB_WD,
    parameter RXSH_WD = `CX_MAC_SH_WD,
    parameter TX_FS_WD   = 6,
    parameter DIRFEEDBACK_WD = `DIRFEEDBACK_WD,
    parameter FOMFEEDBACK_WD = 8,
    parameter TX_COEF_WD = 18,
    parameter RX_PSET_WD = 3,
    parameter TX_PSET_WD = 4
    ,
    parameter PSET_ID_WD = `PSET_ID_WD
)
(
    // ------------------ Inputs - Controls ------------------   
    input                           core_clk,
    input                           core_clk_ug,
    input                           core_rst_n,
    input  [5:0]                    lane_under_test_i,                 //{cfg_force_lane_flip, enable lane under test, the lane_under_test[3:0]}
    input  [L2NL-1:0]               pm_rx_lane_flip_en_i, 
    input  [L2NL-1:0]               pm_tx_lane_flip_en_i,
    input  [L2NL-1:0]               pm_rx_pol_lane_flip_ctrl_i,

    // ------------------ Inputs - Rx Muxes ------------------   
    input  [NL-1:0]                 int_phy_mac_rxstandbystatus_i,
    input  [(NL*NB*8)-1:0]          int_phy_mac_rxdata_i,
    input  [NL*NB-1 :0]             int_phy_mac_rxdatak_i,
    input  [NL-1:0]                 int_phy_mac_rxdatavalid_i,
    input  [(NL*RXSB_WD)-1:0]       int_phy_mac_rxstartblock_i,
    input  [(NL*RXSH_WD)-1:0]       int_phy_mac_rxsyncheader_i,
    input  [NL*TX_FS_WD-1:0]        int_phy_mac_fs_i,
    input  [NL*TX_FS_WD-1:0]        int_phy_mac_lf_i,
    input  [NL*DIRFEEDBACK_WD-1:0]  int_phy_mac_dirfeedback_i,
    input  [NL*FOMFEEDBACK_WD-1:0]  int_phy_mac_fomfeedback_i,
    input  [NL-1:0]                 int_phy_mac_local_tx_coef_valid_i,
    input  [NL*TX_COEF_WD-1:0]      int_phy_mac_local_tx_pset_coef_i,
    input  [NL-1:0]                 int_phy_mac_margin_status_i,
    input  [NL-1:0]                 int_phy_mac_margin_nak_i,
    input  [NL*6-1:0]               int_phy_mac_margin_error_cnt_i,
    input  [NL*7-1:0]               int_phy_mac_margin_sampl_cnt_i,
    input  [NL-1:0]                 int_phy_mac_rxvalid_i,
    input  [NL-1:0]                 int_phy_mac_rxelecidle_i,
    input  [(NL*3)-1:0]             int_phy_mac_rxstatus_i,
    input  [NL-1:0]                 int_phy_mac_phystatus_i,
    input  [NL-1:0]                 int_cdm_ras_des_force_rxdetected_i,
    input  [NL*TX_PSET_WD-1:0]      int_cfg_lec_pset_ltx_i,
    input  [NL*RX_PSET_WD-1:0]      int_cfg_lec_pset_lrx_i,
    input  [NL*TX_PSET_WD-1:0]      int_cfg_lec_pset_rtx_i,
    input  [NL*RX_PSET_WD-1:0]      int_cfg_lec_pset_rrx_i,
    input  [NL*TX_PSET_WD-1:0]      int_cfg_lec_g4_pset_ltx_i,
    input  [NL*TX_PSET_WD-1:0]      int_cfg_lec_g4_pset_rtx_i,
    input  [NL*TX_PSET_WD-1:0]      int_cfg_lec_g5_pset_ltx_i,
    input  [NL*TX_PSET_WD-1:0]      int_cfg_lec_g5_pset_rtx_i,
    input  [NL*TX_PSET_WD-1:0]      int_cfg_lec_g6_pset_ltx_i,
    input  [NL*TX_PSET_WD-1:0]      int_cfg_lec_g6_pset_rtx_i,
    input  [NL*16-1:0]              int_cfg_margin_control_i,
    input  [NL*RXSB_WD*5-1:0]       int_rxdata_osfound_i,
    input  [NL-1:0]                 int_os_corrected_i,
    input  [NL-1:0]                 int_pam4_restricted_levels_wr_ack_pending_i,
    input  [NL-1:0]                 smlh_no_turnoff_lanes,

    // ------------------ Outputs - Rx Muxes ------------------  
    output [NL-1:0]                 tmp_phy_mac_rxstandbystatus,
    output [(NL*NB*8)-1:0]          tmp_phy_mac_rxdata,
    output [NL*NB-1 :0]             tmp_phy_mac_rxdatak,
    output [NL-1:0]                 tmp_phy_mac_rxdatavalid,
    output [(NL*RXSB_WD)-1:0]       tmp_phy_mac_rxstartblock,
    output [(NL*RXSH_WD)-1:0]       tmp_phy_mac_rxsyncheader,
    output [NL*TX_FS_WD-1:0]        tmp_phy_mac_fs,
    output [NL*TX_FS_WD-1:0]        tmp_phy_mac_lf,
    output [NL*DIRFEEDBACK_WD-1:0]  tmp_phy_mac_dirfeedback,
    output [NL*FOMFEEDBACK_WD-1:0]  tmp_phy_mac_fomfeedback,
    output [NL-1:0]                 tmp_phy_mac_local_tx_coef_valid,
    output [NL*TX_COEF_WD-1:0]      tmp_phy_mac_local_tx_pset_coef,
    output [NL-1:0]                 tmp_phy_mac_margin_status,
    output [NL-1:0]                 tmp_phy_mac_margin_nak,
    output [NL*6-1:0]               tmp_phy_mac_margin_error_cnt,
    output [NL*7-1:0]               tmp_phy_mac_margin_sampl_cnt,
    output [NL-1:0]                 tmp_phy_mac_rxvalid,
    output [NL-1:0]                 tmp_phy_mac_rxelecidle,
    output [(NL*3)-1:0]             tmp_phy_mac_rxstatus,
    output [NL-1:0]                 tmp_phy_mac_phystatus,
    output [NL-1:0]                 tmp_cdm_ras_des_force_rxdetected,
    output [NL*TX_PSET_WD-1:0]      tmp_cfg_lec_pset_ltx,
    output [NL*RX_PSET_WD-1:0]      tmp_cfg_lec_pset_lrx,
    output [NL*TX_PSET_WD-1:0]      tmp_cfg_lec_pset_rtx,
    output [NL*RX_PSET_WD-1:0]      tmp_cfg_lec_pset_rrx,
    output [NL*TX_PSET_WD-1:0]      tmp_cfg_lec_g4_pset_ltx,
    output [NL*TX_PSET_WD-1:0]      tmp_cfg_lec_g4_pset_rtx,
    output [NL*TX_PSET_WD-1:0]      tmp_cfg_lec_g5_pset_ltx,
    output [NL*TX_PSET_WD-1:0]      tmp_cfg_lec_g5_pset_rtx,
    output [NL*TX_PSET_WD-1:0]      tmp_cfg_lec_g6_pset_ltx,
    output [NL*TX_PSET_WD-1:0]      tmp_cfg_lec_g6_pset_rtx,
    output  [NL*16-1:0]             tmp_cfg_margin_control,
    output [NL*RXSB_WD*5-1:0]       tmp_rxdata_osfound,
    output [NL-1:0]                 tmp_os_corrected,
    output [NL-1:0]                 tmp_pam4_restricted_levels_wr_ack_pending,
    output [NL-1:0]                 laneflip_no_turnoff_lanes_o,

    // ------------------ Inputs - Tx Muxes ------------------   
    input [NL-1:0]                  tmp_mac_phy_rxstandby,
    input [1:0]                     tmp_xmlh_powerdown,
    input [1:0]                     tmp_ltssm_powerdown,
    input [1:0]                     tmp_mac_phy_txdeemph,
    input [2:0]                     tmp_mac_phy_txmargin,
    input                           tmp_mac_phy_txswing,
    input                           tmp_mac_phy_pam4_restricted_levels,
    input [2:0]                     tmp_int_mac_phy_rate,
    input  [(NL*NB*8)-1:0]          tmp_mac_phy_txdata,
    input  [(NL*NB)-1:0]            tmp_mac_phy_txdatak,
    input  [NL-1:0]                 tmp_mac_phy_txdatavalid,
    input  [(NL*TXSB_WD)-1:0]       tmp_mac_phy_txstartblock,
    input  [(NL*TXSH_WD)-1:0]       tmp_mac_phy_txsyncheader,
    input  [NL*TXSB_WD*5-1:0]       tmp_txdata_osfound,
    input  [NL*RX_PSET_WD-1:0]      tmp_mac_phy_rxpresethint,
    input  [NL*TX_FS_WD-1:0]        tmp_mac_phy_fs,
    input  [NL*TX_FS_WD-1:0]        tmp_mac_phy_lf,
    input  [NL-1:0]                 tmp_mac_phy_rxeqinprogress,
    input  [NL-1:0]                 tmp_mac_phy_invalid_req,
    input  [NL-1:0]                 tmp_mac_phy_rxeqeval,
    input  [NL-1:0]                 tmp_mac_phy_dirchange,
    input  [NL*TX_COEF_WD-1:0]      tmp_smlh_eqpa_txdeemph,         // local coefficients from eqpa block
    input  [NL*PSET_ID_WD-1:0]      tmp_mac_phy_local_pset_index,
    input  [NL-1:0]                 tmp_mac_phy_getlocal_pset_coef,
    input  [NL*TX_COEF_WD-1:0]      tmp_mac_phy_coef_rtx,
    input  [NL-1:0]                 tmp_rmlh_lane_err,
    input  [NL*TX_PSET_WD-1:0]      tmp_smlh_lec_pset_ltx,
    input  [NL*RX_PSET_WD-1:0]      tmp_smlh_lec_pset_lrx,
    input  [NL*TX_PSET_WD-1:0]      tmp_smlh_lec_g4_pset_ltx,
    input  [NL*TX_PSET_WD-1:0]      tmp_smlh_lec_g5_pset_ltx,
    input  [NL*TX_PSET_WD-1:0]      tmp_smlh_lec_g6_pset_ltx,
    input  [NL*3-1:0]               tmp_mac_phy_margin_cmd,
    input  [NL*7-1:0]               tmp_mac_phy_margin_offset,
    input  [NL*2-1:0]               tmp_mac_phy_margin_clr_error_log,
    input  [NL-1:0]                 tmp_smlh_margin_status_valid,
    input  [NL*16-1:0]              tmp_smlh_margin_status,
    input  [NL*5-1:0]               tmp_rmlh_deskew_ctlskp_err,
    input  [NL-1:0]                 tmp_mac_phy_txdetectrx_loopback,// Enable receiver detection sequence.  SerDes transmits
    input  [NL-1:0]                 tmp_ltssm_txelecidle,
    input  [NL-1:0]                 tmp_mac_phy_txcompliance,
    input  [NL-1:0]                 tmp_mac_phy_rxpolarity,
    input  [NL-1:0]                 smlh_lanes_active,
    input  [NL-1:0]                 smlh_blockaligncontrol,
    input  [NL-1:0]                 deskew_lanes_active,
    input  [NL-1:0]                 smlh_set_rxstandby,             // Bit0:NL-1 is always lane0-NL-1

    // ------------------ Outputs - Tx Muxes ------------------  
    output [NL-1:0]                 int_mac_phy_rxstandby_o,
    output [1:0]                    int_xmlh_powerdown_o,
    output [1:0]                    int_ltssm_powerdown_o,
    output [1:0]                    int_mac_phy_txdeemph_o,
    output [2:0]                    int_mac_phy_txmargin_o,
    output                          int_mac_phy_txswing_o,
    output                          int_mac_phy_pam4_restricted_levels_o,
    output [2:0]                    int_mac_phy_rate_o,
    output [(NL*NB*8)-1:0]          int_mac_phy_txdata_o,
    output [(NL*NB)-1:0]            int_mac_phy_txdatak_o,
    output [NL-1:0]                 int_mac_phy_txdatavalid_o,
    output [(NL*TXSB_WD)-1:0]       int_mac_phy_txstartblock_o,
    output [(NL*TXSH_WD)-1:0]       int_mac_phy_txsyncheader_o,
    output [NL*TXSB_WD*5-1:0]       int_txdata_osfound_o,
    output [NL*RX_PSET_WD-1:0]      int_mac_phy_rxpresethint_o,
    output [NL*TX_FS_WD-1:0]        int_mac_phy_fs_o,
    output [NL*TX_FS_WD-1:0]        int_mac_phy_lf_o,
    output [NL-1:0]                 int_mac_phy_rxeqinprogress_o,
    output [NL-1:0]                 int_mac_phy_invalid_req_o,
    output [NL-1:0]                 int_mac_phy_rxeqeval_o,
    output [NL-1:0]                 int_mac_phy_dirchange_o,
    output [NL*TX_COEF_WD-1:0]      int_smlh_eqpa_txdeemph_o,         // local coefficients from eqpa block
    output [NL*PSET_ID_WD-1:0]      int_mac_phy_local_pset_index_o,
    output [NL-1:0]                 int_mac_phy_getlocal_pset_coef_o,
    output [NL*TX_COEF_WD-1:0]      int_mac_phy_coef_rtx_o,
    output [NL-1:0]                 int_rmlh_lane_err_o,
    output [NL*TX_PSET_WD-1:0]      int_smlh_lec_pset_ltx_o,
    output [NL*RX_PSET_WD-1:0]      int_smlh_lec_pset_lrx_o,
    output [NL*TX_PSET_WD-1:0]      int_smlh_lec_g4_pset_ltx_o,
    output [NL*TX_PSET_WD-1:0]      int_smlh_lec_g5_pset_ltx_o,
    output [NL*TX_PSET_WD-1:0]      int_smlh_lec_g6_pset_ltx_o,
    output [NL*3-1:0]               int_mac_phy_margin_cmd_o,
    output [NL*7-1:0]               int_mac_phy_margin_offset_o,
    output [NL*2-1:0]               int_mac_phy_margin_clr_error_log_o,
    output [NL-1:0]                 int_smlh_margin_status_valid_o,
    output [NL*16-1:0]              int_smlh_margin_status_o,
    output [NL*5-1:0]               int_rmlh_deskew_ctlskp_err_o,
    output [NL-1:0]                 int_mac_phy_txdetectrx_loopback_o,// Enable receiver detection sequence.  SerDes transmits
    output [NL-1:0]                 int_ltssm_txelecidle_o,
    output [NL-1:0]                 int_mac_phy_txcompliance_o,
    output [NL-1:0]                 int_mac_phy_rxpolarity_o
    ,
    output [NL-1:0]                 laneflip_lanes_active_o,          // lane assignment aligned with PIPE
    output [NL-1:0]                 laneflip_mac_phy_rxstandby_o,     // Bit0:NL-1 is always lane0-NL-1
    output  [NL-1:0]                laneflip_smlh_blockaligncontrol_o,
    output  [NL-1:0]                laneflip_deskew_lanes_active_o,
    output [NL-1:0]                 laneflip_set_rxstandby_o          // Bits are flipped by switching lane-reversal/non-lane-reversal
);

// ================================================================================
//logic below is for register pipeline at the inputs of Lane Flip block from PHY
localparam RXBW = NL+NL*NB*8+NL*NB+NL+NL+NL*3 +NL*RXSB_WD+NL*RXSH_WD+NL*TX_PSET_WD*2+NL*RX_PSET_WD*2
 +NL*TX_FS_WD+NL*TX_FS_WD+NL*DIRFEEDBACK_WD+NL*FOMFEEDBACK_WD+NL+NL*TX_COEF_WD
 +NL
 +NL*TX_PSET_WD*2 +NL*TX_PSET_WD*2
                                             +NL+NL*6+NL*7
 +NL // CX_PIPE_MSGBUS_SUPPORT
                                             +NL*16
                                             +$bits(int_rxdata_osfound_i)
                                             +NL*TX_PSET_WD*2 +NL
                                             +NL
                                           ;

wire [L2NL-1:0]               pm_rx_lane_flip_en; 
wire [L2NL-1:0]               pm_tx_lane_flip_en;
wire [L2NL-1:0]               pm_rx_pol_lane_flip_ctrl;

wire [NL-1:0]                 int_phy_mac_rxstandbystatus;
wire [(NL*NB*8)-1:0]          int_phy_mac_rxdata;
wire [NL*NB-1 :0]             int_phy_mac_rxdatak;
wire [NL-1:0]                 int_phy_mac_rxdatavalid;
wire [(NL*RXSB_WD)-1:0]       int_phy_mac_rxstartblock;
wire [(NL*RXSH_WD)-1:0]       int_phy_mac_rxsyncheader;
wire [NL*TX_FS_WD-1:0]        int_phy_mac_fs;
wire [NL*TX_FS_WD-1:0]        int_phy_mac_lf;
wire [NL*DIRFEEDBACK_WD-1:0]  int_phy_mac_dirfeedback;
wire [NL*FOMFEEDBACK_WD-1:0]  int_phy_mac_fomfeedback;
wire [NL-1:0]                 int_phy_mac_local_tx_coef_valid;
wire [NL*TX_COEF_WD-1:0]      int_phy_mac_local_tx_pset_coef;
wire [NL-1:0]                 int_phy_mac_margin_status;
wire [NL-1:0]                 int_phy_mac_margin_nak;
wire [NL*6-1:0]               int_phy_mac_margin_error_cnt;
wire [NL*7-1:0]               int_phy_mac_margin_sampl_cnt;
wire [NL-1:0]                 int_phy_mac_rxvalid;
wire [NL-1:0]                 int_phy_mac_rxelecidle;
wire [(NL*3)-1:0]             int_phy_mac_rxstatus;
wire [NL-1:0]                 int_phy_mac_phystatus;
wire [NL-1:0]                 int_cdm_ras_des_force_rxdetected;
wire [NL*TX_PSET_WD-1:0]      int_cfg_lec_pset_ltx;
wire [NL*RX_PSET_WD-1:0]      int_cfg_lec_pset_lrx;
wire [NL*TX_PSET_WD-1:0]      int_cfg_lec_pset_rtx;
wire [NL*RX_PSET_WD-1:0]      int_cfg_lec_pset_rrx;
wire [NL*TX_PSET_WD-1:0]      int_cfg_lec_g4_pset_ltx;
wire [NL*TX_PSET_WD-1:0]      int_cfg_lec_g4_pset_rtx;
wire [NL*TX_PSET_WD-1:0]      int_cfg_lec_g5_pset_ltx;
wire [NL*TX_PSET_WD-1:0]      int_cfg_lec_g5_pset_rtx;
wire [NL*TX_PSET_WD-1:0]      int_cfg_lec_g6_pset_ltx;
wire [NL*TX_PSET_WD-1:0]      int_cfg_lec_g6_pset_rtx;
wire [NL*16-1:0]              int_cfg_margin_control;
wire [4:0] lane_under_test = lane_under_test_i[4:0];
wire [4:0] pol_lane_under_test = {lane_under_test_i[5], lane_under_test_i[3:0]};
wire [NL*RXSB_WD*5-1:0]       int_rxdata_osfound;
wire [NL-1:0]                 int_os_corrected;
wire [NL-1:0]                 int_pam4_restricted_levels_wr_ack_pending;

reg [RXBW-1:0] rx_vec_r;
reg [NL-1:0] int_phy_mac_phystatus_r;
wire [RXBW-1:0] rx_vec_i = { int_phy_mac_rxstandbystatus_i, int_phy_mac_rxdata_i, int_phy_mac_rxdatak_i, int_phy_mac_rxdatavalid_i,
 int_phy_mac_rxstartblock_i, int_phy_mac_rxsyncheader_i, int_cfg_lec_pset_ltx_i, int_cfg_lec_pset_lrx_i, int_cfg_lec_pset_rtx_i, int_cfg_lec_pset_rrx_i, 
 int_phy_mac_fs_i, int_phy_mac_lf_i, int_phy_mac_dirfeedback_i, int_phy_mac_fomfeedback_i, int_phy_mac_local_tx_coef_valid_i, int_phy_mac_local_tx_pset_coef_i,
                             int_phy_mac_rxvalid_i, int_phy_mac_rxstatus_i
 ,int_cdm_ras_des_force_rxdetected_i 
 , int_cfg_lec_g4_pset_ltx_i, int_cfg_lec_g4_pset_rtx_i , int_cfg_lec_g5_pset_ltx_i, int_cfg_lec_g5_pset_rtx_i , int_cfg_lec_g6_pset_ltx_i, int_cfg_lec_g6_pset_rtx_i
                             , int_phy_mac_margin_status_i, int_phy_mac_margin_error_cnt_i, int_phy_mac_margin_sampl_cnt_i
 , int_phy_mac_margin_nak_i // CX_PIPE_MSGBUS_SUPPORT
                             , int_cfg_margin_control_i
                             , int_rxdata_osfound_i
                             , int_os_corrected_i
                             , int_pam4_restricted_levels_wr_ack_pending_i
                            };

always @( posedge core_clk or negedge core_rst_n ) begin : rx_vec_r_PROC
    if ( ~core_rst_n )
        rx_vec_r <= #`TP 0;
    else
        rx_vec_r <= #`TP rx_vec_i;
end // rx_vec_r_PROC

assign { int_phy_mac_rxstandbystatus, int_phy_mac_rxdata, int_phy_mac_rxdatak, int_phy_mac_rxdatavalid,
 int_phy_mac_rxstartblock, int_phy_mac_rxsyncheader, int_cfg_lec_pset_ltx, int_cfg_lec_pset_lrx, int_cfg_lec_pset_rtx, int_cfg_lec_pset_rrx,
 int_phy_mac_fs, int_phy_mac_lf, int_phy_mac_dirfeedback, int_phy_mac_fomfeedback, int_phy_mac_local_tx_coef_valid, int_phy_mac_local_tx_pset_coef,
         int_phy_mac_rxvalid, int_phy_mac_rxstatus
 ,int_cdm_ras_des_force_rxdetected 
 , int_cfg_lec_g4_pset_ltx, int_cfg_lec_g4_pset_rtx , int_cfg_lec_g5_pset_ltx, int_cfg_lec_g5_pset_rtx , int_cfg_lec_g6_pset_ltx, int_cfg_lec_g6_pset_rtx
           , int_phy_mac_margin_status, int_phy_mac_margin_error_cnt, int_phy_mac_margin_sampl_cnt
 , int_phy_mac_margin_nak // CX_PIPE_MSGBUS_SUPPORT
         , int_cfg_margin_control
         , int_rxdata_osfound
         , int_os_corrected
         , int_pam4_restricted_levels_wr_ack_pending
        } = REGIN ? rx_vec_r : rx_vec_i;
assign tmp_phy_mac_rxstandbystatus = int_phy_mac_rxstandbystatus; //no lane flip

always @( posedge core_clk_ug or negedge core_rst_n ) begin : int_phy_mac_phystatus_PROC //use core_clk_ug
    if ( ~core_rst_n )
        int_phy_mac_phystatus_r <= #`TP {NL{1'b1}};
    else
        int_phy_mac_phystatus_r <= #`TP int_phy_mac_phystatus_i;
end // int_phy_mac_phystatus_PROC

assign int_phy_mac_phystatus = REGIN ? int_phy_mac_phystatus_r : int_phy_mac_phystatus_i;
assign int_phy_mac_rxelecidle = int_phy_mac_rxelecidle_i; //no pipeline to phy_mac_rxelecidle
//end of RX pipeline

//logic below is for register pipeline at the outputs of Lane Flip block to PHY
localparam TXBW =   NL*NB*8+NL*NB+3*NL +NL*(2+TXSB_WD+TXSH_WD+TX_PSET_WD+RX_PSET_WD)  // 2(txdatavalid,lane_error)
                                                            +$bits(int_txdata_osfound_o)
 +NL*RX_PSET_WD+NL*TX_FS_WD+NL*TX_FS_WD+5*NL+2*NL*TX_COEF_WD+NL*PSET_ID_WD
 +2*NL // CX_NL_GTR_1
 +NL*TX_PSET_WD +NL*TX_PSET_WD
                                         +NL*3+NL*7+NL*2
                                         + NL*(1+16+5)
                                         + NL*TX_PSET_WD // + int_smlh_lec_g6_pset_ltx
                                       ;
wire [NL-1:0]                 int_mac_phy_rxstandby;
wire [1:0]                    int_xmlh_powerdown;
wire [1:0]                    int_ltssm_powerdown;
wire [2:0]                    int_mac_phy_rate;
wire [1:0]                    int_mac_phy_txdeemph;
wire [2:0]                    int_mac_phy_txmargin;
wire                          int_mac_phy_txswing;
wire                          int_mac_phy_pam4_restricted_levels;
wire [(NL*NB*8)-1:0]          int_mac_phy_txdata;
wire [(NL*NB)-1:0]            int_mac_phy_txdatak;
wire [NL-1:0]                 int_mac_phy_txdatavalid;
wire [(NL*TXSB_WD)-1:0]       int_mac_phy_txstartblock;
wire [(NL*TXSH_WD)-1:0]       int_mac_phy_txsyncheader;
wire [NL*TXSB_WD*5-1:0]       int_txdata_osfound;
wire [NL*RX_PSET_WD-1:0]      int_mac_phy_rxpresethint;
wire [NL*TX_FS_WD-1:0]        int_mac_phy_fs;
wire [NL*TX_FS_WD-1:0]        int_mac_phy_lf;
wire [NL-1:0]                 int_mac_phy_rxeqinprogress;
wire [NL-1:0]                 int_mac_phy_invalid_req;
wire [NL-1:0]                 int_mac_phy_rxeqeval;
wire [NL-1:0]                 int_mac_phy_dirchange;
wire [NL*TX_COEF_WD-1:0]      int_smlh_eqpa_txdeemph;         // local coefficients from eqpa block
wire [NL*PSET_ID_WD-1:0]      int_mac_phy_local_pset_index;
wire [NL-1:0]                 int_mac_phy_getlocal_pset_coef;
wire [NL*TX_COEF_WD-1:0]      int_mac_phy_coef_rtx;
wire [NL-1:0]                 int_rmlh_lane_err;
wire [NL*TX_PSET_WD-1:0]      int_smlh_lec_pset_ltx;
wire [NL*RX_PSET_WD-1:0]      int_smlh_lec_pset_lrx;
wire [NL*TX_PSET_WD-1:0]      int_smlh_lec_g4_pset_ltx;
wire [NL*TX_PSET_WD-1:0]      int_smlh_lec_g5_pset_ltx;
wire [NL*TX_PSET_WD-1:0]      int_smlh_lec_g6_pset_ltx;
wire [NL*3-1:0]               int_mac_phy_margin_cmd;
wire [NL*7-1:0]               int_mac_phy_margin_offset;
wire [NL*2-1:0]               int_mac_phy_margin_clr_error_log;
wire [NL-1:0]                 int_smlh_margin_status_valid;
wire [NL*16-1:0]              int_smlh_margin_status;
wire [NL*5-1:0]               int_rmlh_deskew_ctlskp_err;
wire [NL-1:0]                 int_mac_phy_txdetectrx_loopback;// Enable receiver detection sequence.  SerDes transmits
wire [NL-1:0]                 int_ltssm_txelecidle;
wire [NL-1:0]                 int_mac_phy_txcompliance;
wire [NL-1:0]                 int_mac_phy_rxpolarity;
wire [NL-1:0]                 laneflip_lanes_active;
wire [NL-1:0]                 laneflip_mac_phy_rxstandby;
wire [NL-1:0]                 laneflip_smlh_blockaligncontrol;
wire [NL-1:0]                 laneflip_deskew_lanes_active;
wire [NL-1:0]                 laneflip_set_rxstandby;
wire [NL-1:0]                 laneflip_no_turnoff_lanes;

assign int_mac_phy_rxstandby = tmp_mac_phy_rxstandby; //no lane flip
assign int_xmlh_powerdown = tmp_xmlh_powerdown;
assign int_ltssm_powerdown = tmp_ltssm_powerdown;
assign int_mac_phy_rate = tmp_int_mac_phy_rate;
assign int_mac_phy_txdeemph = tmp_mac_phy_txdeemph;
assign int_mac_phy_txmargin = tmp_mac_phy_txmargin;
assign int_mac_phy_txswing  = tmp_mac_phy_txswing;
assign int_mac_phy_pam4_restricted_levels = tmp_mac_phy_pam4_restricted_levels;
wire [TXBW-1:0] tx_vec_o = { int_mac_phy_txdata, int_mac_phy_txdatak,
 int_mac_phy_txdatavalid, int_mac_phy_txstartblock, int_mac_phy_txsyncheader, int_txdata_osfound , int_rmlh_lane_err, int_smlh_lec_pset_ltx, int_smlh_lec_pset_lrx,
 int_mac_phy_rxpresethint, int_mac_phy_fs, int_mac_phy_lf, int_mac_phy_rxeqinprogress, int_mac_phy_invalid_req, int_mac_phy_rxeqeval, int_mac_phy_dirchange, int_smlh_eqpa_txdeemph, int_mac_phy_local_pset_index, int_mac_phy_getlocal_pset_coef, int_mac_phy_coef_rtx,
                             int_mac_phy_txdetectrx_loopback, int_mac_phy_txcompliance, int_mac_phy_rxpolarity
 , laneflip_set_rxstandby, laneflip_mac_phy_rxstandby
                             , int_smlh_lec_g4_pset_ltx , int_smlh_lec_g5_pset_ltx , int_smlh_lec_g6_pset_ltx
                             , int_mac_phy_margin_cmd, int_mac_phy_margin_offset, int_mac_phy_margin_clr_error_log
                             , int_smlh_margin_status_valid, int_smlh_margin_status, int_rmlh_deskew_ctlskp_err
                           };

reg [TXBW-1:0] tx_vec_r;
always @( posedge core_clk or negedge core_rst_n ) begin : tx_vec_r_PROC
    if ( ~core_rst_n )
        tx_vec_r <= #`TP 0;
    else
        tx_vec_r <= #`TP tx_vec_o;
end // tx_vec_r_PROC

reg [1:0] int_ltssm_powerdown_r, int_xmlh_powerdown_r;
always @( posedge core_clk or negedge core_rst_n ) begin : powerdown_PROC //reset powerdown to P1
    if ( ~core_rst_n ) begin
        int_ltssm_powerdown_r <= #`TP `P1;
        int_xmlh_powerdown_r  <= #`TP `P1;
    end else begin
        int_ltssm_powerdown_r <= #`TP int_ltssm_powerdown;
        int_xmlh_powerdown_r  <= #`TP int_xmlh_powerdown;
    end
end // powerdown_PROC

// If CX_FREQ_STEP_EN is enabled, the int_mac_phy_rate_o should be active after L1 substate to release a clock gating logic in freq_step.
reg [2:0] int_mac_phy_rate_r;
reg [1:0] int_mac_phy_txdeemph_r;
reg [2:0] int_mac_phy_txmargin_r;
reg       int_mac_phy_txswing_r;
always @( posedge core_clk    or negedge core_rst_n ) begin : int_mac_phy_rate_r_PROC //use core_clk
    if ( ~core_rst_n ) begin
        int_mac_phy_rate_r <= #`TP 0;
    end else begin
        int_mac_phy_rate_r <= #`TP int_mac_phy_rate;
    end
end // int_mac_phy_rate_r_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : int_mac_phy_txdeemph_margin_swing_r_PROC
    if ( ~core_rst_n ) begin
        int_mac_phy_txdeemph_r <= #`TP 2'b01;
        int_mac_phy_txmargin_r <= #`TP 0;
        int_mac_phy_txswing_r  <= #`TP 0;
    end else begin
        int_mac_phy_txdeemph_r <= #`TP int_mac_phy_txdeemph;
        int_mac_phy_txmargin_r <= #`TP int_mac_phy_txmargin;
        int_mac_phy_txswing_r  <= #`TP int_mac_phy_txswing;
    end
end // int_mac_phy_txdeemph_margin_swing_r_PROC

reg int_mac_phy_pam4_restricted_levels_r;
always @( posedge core_clk or negedge core_rst_n ) begin : int_mac_phy_pam4_restricted_levels_r_PROC
    if ( ~core_rst_n ) begin
        int_mac_phy_pam4_restricted_levels_r <= #`TP 1'b0;
    end else begin
        int_mac_phy_pam4_restricted_levels_r <= #`TP int_mac_phy_pam4_restricted_levels;
    end
end // int_mac_phy_pam4_restricted_levels_r_PROC

reg [NL-1:0] int_ltssm_txelecidle_r;
reg [NL-1:0] int_mac_phy_rxstandby_r;
always @( posedge core_clk or negedge core_rst_n ) begin : int_ltssm_txelecidle_r_PROC //reset txelecidle to 1, rxstandby to CX_RXSTANDBY_DEFAULT
    if ( ~core_rst_n ) begin
        int_ltssm_txelecidle_r  <= #`TP {NL{1'b1}};
        int_mac_phy_rxstandby_r <= #`TP {NL{`CX_RXSTANDBY_DEFAULT}};
    end else begin
        int_ltssm_txelecidle_r  <= #`TP int_ltssm_txelecidle;
        int_mac_phy_rxstandby_r <= #`TP int_mac_phy_rxstandby;
    end
end // int_ltssm_txelecidle_r_PROC

reg [L2NL-1:0] pm_tx_lane_flip_en_r;

always @( posedge core_clk or negedge core_rst_n ) begin : pm_tx_lane_flip_en_r_PROC
    if ( ~core_rst_n ) begin
        pm_tx_lane_flip_en_r <= #`TP {L2NL{1'b0}};
    end else begin
        pm_tx_lane_flip_en_r <= #`TP pm_tx_lane_flip_en;
    end
end // pm_tx_lane_flip_en_r_PROC

reg [NL-1:0] laneflip_lanes_active_r;
always @( posedge core_clk or negedge core_rst_n ) begin : laneflip_lanes_active_r_PROC //reset laneflip_lanes_active  to 1
    if ( ~core_rst_n ) begin
        laneflip_lanes_active_r <= #`TP {NL{1'b1}};
    end else begin
        laneflip_lanes_active_r <= #`TP laneflip_lanes_active;
    end
end // laneflip_lanes_active_r_PROC

reg [NL-1:0] laneflip_smlh_blockaligncontrol_r;
always @( posedge core_clk or negedge core_rst_n ) begin : laneflip_smlh_blockaligncontrol_r_PROC //reset laneflip_smlh_blockaligncontrol  to 0
    if ( ~core_rst_n ) begin
        laneflip_smlh_blockaligncontrol_r <= #`TP {NL{1'b0}};
    end else begin
        laneflip_smlh_blockaligncontrol_r <= #`TP laneflip_smlh_blockaligncontrol;
    end
end // laneflip_smlh_blockaligncontrol_r_PROC
reg [NL-1:0] laneflip_deskew_lanes_active_r;
always @( posedge core_clk or negedge core_rst_n ) begin : laneflip_deskew_lanes_active_r_PROC //reset laneflip_deskew_lanes_active  to 1
    if ( ~core_rst_n ) begin
        laneflip_deskew_lanes_active_r <= #`TP {NL{1'b1}};
    end else begin
        laneflip_deskew_lanes_active_r <= #`TP laneflip_deskew_lanes_active;
    end
end // laneflip_deskew_lanes_active_r_PROC
reg [NL-1:0] laneflip_no_turnoff_lanes_r;
always @( posedge core_clk or negedge core_rst_n ) begin : laneflip_no_turnoff_lanes_r_PROC //reset laneflip_lanes_active  to 1
    if ( ~core_rst_n ) begin
        laneflip_no_turnoff_lanes_r <= #`TP {NL{1'b1}};
    end else begin
        laneflip_no_turnoff_lanes_r <= #`TP laneflip_no_turnoff_lanes;
    end
end // laneflip_no_turnoff_lanes_r_PROC

assign int_mac_phy_rate_o = REGOUT ? int_mac_phy_rate_r : int_mac_phy_rate;
assign int_mac_phy_txdeemph_o = REGOUT ? int_mac_phy_txdeemph_r : int_mac_phy_txdeemph;
assign int_mac_phy_txmargin_o = REGOUT ? int_mac_phy_txmargin_r : int_mac_phy_txmargin;
assign int_mac_phy_txswing_o  = REGOUT ? int_mac_phy_txswing_r  : int_mac_phy_txswing;
assign int_mac_phy_pam4_restricted_levels_o = REGOUT ? int_mac_phy_pam4_restricted_levels_r : int_mac_phy_pam4_restricted_levels;
assign int_ltssm_powerdown_o = REGOUT ? int_ltssm_powerdown_r : int_ltssm_powerdown;
assign int_xmlh_powerdown_o  = REGOUT ? int_xmlh_powerdown_r  : int_xmlh_powerdown;
assign int_ltssm_txelecidle_o = REGOUT ? int_ltssm_txelecidle_r : int_ltssm_txelecidle;
assign int_mac_phy_rxstandby_o = REGOUT ? int_mac_phy_rxstandby_r : int_mac_phy_rxstandby;
assign laneflip_lanes_active_o = REGOUT ? laneflip_lanes_active_r : laneflip_lanes_active;
assign laneflip_smlh_blockaligncontrol_o = REGOUT ? laneflip_smlh_blockaligncontrol_r : laneflip_smlh_blockaligncontrol;
assign laneflip_deskew_lanes_active_o = REGOUT ? laneflip_deskew_lanes_active_r : laneflip_deskew_lanes_active;
assign laneflip_no_turnoff_lanes_o = REGOUT ? laneflip_no_turnoff_lanes_r : laneflip_no_turnoff_lanes;

assign { int_mac_phy_txdata_o, int_mac_phy_txdatak_o,
 int_mac_phy_txdatavalid_o, int_mac_phy_txstartblock_o, int_mac_phy_txsyncheader_o, int_txdata_osfound_o, int_rmlh_lane_err_o, int_smlh_lec_pset_ltx_o, int_smlh_lec_pset_lrx_o,
 int_mac_phy_rxpresethint_o, int_mac_phy_fs_o, int_mac_phy_lf_o, int_mac_phy_rxeqinprogress_o, int_mac_phy_invalid_req_o, int_mac_phy_rxeqeval_o, int_mac_phy_dirchange_o, int_smlh_eqpa_txdeemph_o, int_mac_phy_local_pset_index_o, int_mac_phy_getlocal_pset_coef_o, int_mac_phy_coef_rtx_o,
                             int_mac_phy_txdetectrx_loopback_o, int_mac_phy_txcompliance_o, int_mac_phy_rxpolarity_o
 , laneflip_set_rxstandby_o, laneflip_mac_phy_rxstandby_o
                             , int_smlh_lec_g4_pset_ltx_o , int_smlh_lec_g5_pset_ltx_o , int_smlh_lec_g6_pset_ltx_o
                             , int_mac_phy_margin_cmd_o, int_mac_phy_margin_offset_o, int_mac_phy_margin_clr_error_log_o
                             , int_smlh_margin_status_valid_o, int_smlh_margin_status_o, int_rmlh_deskew_ctlskp_err_o
                            } = REGOUT ? tx_vec_r : tx_vec_o;
//end of TX pipeline
// =========================================================================================

// muxes added for enabling lane flip functions
// in lane_flip_mux instance, first parameter value is 1 - Rx signal flip, 0 - Tx signal flip
// for easing timing
 delay_n
  #( 1, L2NL) u_delay_rx_lane_flip_en ( .clk (core_clk), .rst_n (core_rst_n), .clear (1'b0), .din (pm_rx_lane_flip_en_i),       .dout (pm_rx_lane_flip_en)       ) ;
 delay_n
  #( 1, L2NL) u_delay_tx_lane_flip_en ( .clk (core_clk), .rst_n (core_rst_n), .clear (1'b0), .din (pm_tx_lane_flip_en_i),       .dout (pm_tx_lane_flip_en)       ) ;
 delay_n
  #( 1, L2NL) u_delay_pol_lane_flip_en( .clk (core_clk), .rst_n (core_rst_n), .clear (1'b0), .din (pm_rx_pol_lane_flip_ctrl_i), .dout (pm_rx_pol_lane_flip_ctrl) ) ;

 lane_flip_mux
  #( 1, NL,NB*8) u_rx_lane_flip_mux_0 (.flipped_data(tmp_phy_mac_rxdata),  .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_phy_mac_rxdata));
 lane_flip_mux
  #( 1, NL,NB) u_rx_lane_flip_mux_1 (.flipped_data(tmp_phy_mac_rxdatak),  .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_phy_mac_rxdatak));
 lane_flip_mux
  #( 1, NL,1) u_rx_lane_flip_mux_2 (.flipped_data(tmp_phy_mac_rxdatavalid), .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_phy_mac_rxdatavalid));
 lane_flip_mux
  #( 1, NL,RXSB_WD) u_rx_lane_flip_mux_3 (.flipped_data(tmp_phy_mac_rxstartblock), .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_phy_mac_rxstartblock));
 lane_flip_mux
  #( 1, NL,RXSH_WD) u_rx_lane_flip_mux_4 (.flipped_data(tmp_phy_mac_rxsyncheader), .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_phy_mac_rxsyncheader));
 lane_flip_mux
  #( 1, NL,6) u_rx_lane_flip_mux_5 (.flipped_data(tmp_phy_mac_fs),   .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_phy_mac_fs));
 lane_flip_mux
  #( 1, NL,6) u_rx_lane_flip_mux_6 (.flipped_data(tmp_phy_mac_lf),   .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_phy_mac_lf));
 lane_flip_mux
  #( 1, NL,DIRFEEDBACK_WD) u_rx_lane_flip_mux_7 (.flipped_data(tmp_phy_mac_dirfeedback), .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_phy_mac_dirfeedback));
 lane_flip_mux
  #( 1, NL,8) u_rx_lane_flip_mux_8 (.flipped_data(tmp_phy_mac_fomfeedback), .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_phy_mac_fomfeedback));
 lane_flip_mux
  #( 1, NL,1) u_rx_lane_flip_mux_9 (.flipped_data(tmp_phy_mac_local_tx_coef_valid),.lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_phy_mac_local_tx_coef_valid));
 lane_flip_mux
  #( 1, NL,18) u_rx_lane_flip_mux_10 (.flipped_data(tmp_phy_mac_local_tx_pset_coef), .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_phy_mac_local_tx_pset_coef));
 lane_flip_mux
  #( 1, NL,1) u_rx_lane_flip_mux_19 (.flipped_data(tmp_phy_mac_rxvalid),  .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_phy_mac_rxvalid));
 lane_flip_mux
  #( 1, NL,1) u_rx_lane_flip_mux_20 (.flipped_data(tmp_phy_mac_rxelecidle),  .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_phy_mac_rxelecidle));
 lane_flip_mux
  #( 1, NL,3) u_rx_lane_flip_mux_21 (.flipped_data(tmp_phy_mac_rxstatus),  .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_phy_mac_rxstatus));
 lane_flip_mux
  #( 1, NL,1) u_rx_lane_flip_mux_22 (.flipped_data(tmp_phy_mac_phystatus),  .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_phy_mac_phystatus));
 lane_flip_mux
  #( 1, NL,1) u_rx_lane_flip_mux_23 (.flipped_data(tmp_cdm_ras_des_force_rxdetected),  .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_cdm_ras_des_force_rxdetected));
 lane_flip_mux
  #( 1, NL,1) u_rx_lane_flip_mux_24 (.flipped_data(tmp_phy_mac_margin_status   ),  .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_phy_mac_margin_status   ));
 lane_flip_mux
  #( 1, NL,1) u_rx_lane_flip_mux_25 (.flipped_data(tmp_phy_mac_margin_nak     ),  .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_phy_mac_margin_nak      ));
 lane_flip_mux
  #( 1, NL,6) u_rx_lane_flip_mux_26 (.flipped_data(tmp_phy_mac_margin_error_cnt),  .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_phy_mac_margin_error_cnt));
 lane_flip_mux
  #( 1, NL,7) u_rx_lane_flip_mux_27 (.flipped_data(tmp_phy_mac_margin_sampl_cnt),  .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_phy_mac_margin_sampl_cnt));
 lane_flip_mux
  #( 1, NL,TX_PSET_WD) u_rx_lane_flip_mux_28 (.flipped_data(tmp_cfg_lec_pset_ltx),  .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_cfg_lec_pset_ltx));
 lane_flip_mux
  #( 1, NL,RX_PSET_WD) u_rx_lane_flip_mux_29 (.flipped_data(tmp_cfg_lec_pset_lrx),  .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_cfg_lec_pset_lrx));
 lane_flip_mux
  #( 1, NL,TX_PSET_WD) u_rx_lane_flip_mux_30 (.flipped_data(tmp_cfg_lec_pset_rtx),  .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_cfg_lec_pset_rtx));
 lane_flip_mux
  #( 1, NL,RX_PSET_WD) u_rx_lane_flip_mux_31 (.flipped_data(tmp_cfg_lec_pset_rrx),  .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_cfg_lec_pset_rrx));
 lane_flip_mux
  #( 1, NL,TX_PSET_WD) u_rx_lane_flip_mux_32 (.flipped_data(tmp_cfg_lec_g4_pset_ltx),  .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_cfg_lec_g4_pset_ltx));
 lane_flip_mux
  #( 1, NL,TX_PSET_WD) u_rx_lane_flip_mux_33 (.flipped_data(tmp_cfg_lec_g4_pset_rtx),  .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_cfg_lec_g4_pset_rtx));
 lane_flip_mux
  #( 1, NL,TX_PSET_WD) u_rx_lane_flip_mux_532 (.flipped_data(tmp_cfg_lec_g5_pset_ltx),  .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_cfg_lec_g5_pset_ltx));
 lane_flip_mux
  #( 1, NL,TX_PSET_WD) u_rx_lane_flip_mux_533 (.flipped_data(tmp_cfg_lec_g5_pset_rtx),  .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_cfg_lec_g5_pset_rtx));
 lane_flip_mux
  #( 1, NL,TX_PSET_WD) u_rx_lane_flip_mux_632 (.flipped_data(tmp_cfg_lec_g6_pset_ltx),  .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_cfg_lec_g6_pset_ltx));
 lane_flip_mux
  #( 1, NL,TX_PSET_WD) u_rx_lane_flip_mux_633 (.flipped_data(tmp_cfg_lec_g6_pset_rtx),  .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_cfg_lec_g6_pset_rtx));
 lane_flip_mux
  #( 1, NL,16) u_rx_lane_flip_mux_34 (.flipped_data(tmp_cfg_margin_control),  .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_cfg_margin_control));
 lane_flip_mux
  #( 1, NL,1) u_rx_lane_flip_mux_35 (.flipped_data(laneflip_no_turnoff_lanes),  .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(smlh_no_turnoff_lanes));
 lane_flip_mux
  #( 1, NL,RXSB_WD*5) u_rx_lane_flip_mux_40 (.flipped_data(tmp_rxdata_osfound),  .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_rxdata_osfound));
 lane_flip_mux
  #( 1, NL,1) u_rx_lane_flip_mux_41 (.flipped_data(tmp_os_corrected),  .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_os_corrected));
 lane_flip_mux
  #( 1, NL,1) u_rx_lane_flip_mux_42 (.flipped_data(tmp_pam4_restricted_levels_wr_ack_pending),  .lut(lane_under_test), .flip_ctrl(pm_rx_lane_flip_en), .data(int_pam4_restricted_levels_wr_ack_pending));

 lane_flip_mux
  #( 0, NL,NB*8) u_tx_lane_flip_mux_0 (.flipped_data(int_mac_phy_txdata),  .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_mac_phy_txdata));
 lane_flip_mux
  #( 0, NL,NB) u_tx_lane_flip_mux_1 (.flipped_data(int_mac_phy_txdatak),  .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_mac_phy_txdatak));
 lane_flip_mux
  #( 0, NL,1) u_tx_lane_flip_mux_2 (.flipped_data(int_mac_phy_txdatavalid), .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_mac_phy_txdatavalid));
 lane_flip_mux
  #( 0, NL,TXSB_WD) u_tx_lane_flip_mux_3 (.flipped_data(int_mac_phy_txstartblock), .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_mac_phy_txstartblock));
 lane_flip_mux
  #( 0, NL,TXSH_WD) u_tx_lane_flip_mux_4 (.flipped_data(int_mac_phy_txsyncheader), .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_mac_phy_txsyncheader));
 lane_flip_mux
  #( 0, NL,3) u_tx_lane_flip_mux_5 (.flipped_data(int_mac_phy_rxpresethint), .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_mac_phy_rxpresethint));
 lane_flip_mux
  #( 0, NL,6) u_tx_lane_flip_mux_6 (.flipped_data(int_mac_phy_fs),   .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_mac_phy_fs));
 lane_flip_mux
  #( 0, NL,6) u_tx_lane_flip_mux_7 (.flipped_data(int_mac_phy_lf),   .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_mac_phy_lf));
 lane_flip_mux
  #( 0, NL,1) u_tx_lane_flip_mux_8 (.flipped_data(int_mac_phy_rxeqinprogress), .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_mac_phy_rxeqinprogress));
 lane_flip_mux
  #( 0, NL,1) u_tx_lane_flip_mux_9 (.flipped_data(int_mac_phy_invalid_req), .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_mac_phy_invalid_req));
 lane_flip_mux
  #( 0, NL,1) u_tx_lane_flip_mux_10 (.flipped_data(int_mac_phy_rxeqeval),  .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_mac_phy_rxeqeval));
 lane_flip_mux
  #( 0, NL,1) u_tx_lane_flip_mux_10a (.flipped_data(int_mac_phy_dirchange),  .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_mac_phy_dirchange));
 lane_flip_mux
  #( 0, NL,18) u_tx_lane_flip_mux_11 (.flipped_data(int_smlh_eqpa_txdeemph),  .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_smlh_eqpa_txdeemph));
 lane_flip_mux
  #( 0, NL,PSET_ID_WD) u_tx_lane_flip_mux_12 (.flipped_data(int_mac_phy_local_pset_index), .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_mac_phy_local_pset_index));
 lane_flip_mux
  #( 0, NL,1) u_tx_lane_flip_mux_13 (.flipped_data(int_mac_phy_getlocal_pset_coef), .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_mac_phy_getlocal_pset_coef));
 lane_flip_mux
  #( 0, NL,TX_COEF_WD) u_tx_lane_flip_mux_47 (.flipped_data(int_mac_phy_coef_rtx), .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en_r), .data(tmp_mac_phy_coef_rtx));
 lane_flip_mux
  #( 0, NL,1) u_tx_lane_flip_mux_40 (.flipped_data(int_rmlh_lane_err), .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_rmlh_lane_err));
 lane_flip_mux
  #( 0, NL,TX_PSET_WD) u_tx_lane_flip_mux_41 (.flipped_data(int_smlh_lec_pset_ltx), .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_smlh_lec_pset_ltx));
 lane_flip_mux
  #( 0, NL,RX_PSET_WD) u_tx_lane_flip_mux_42 (.flipped_data(int_smlh_lec_pset_lrx), .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_smlh_lec_pset_lrx));
 lane_flip_mux
  #( 0, NL,1) u_tx_lane_flip_mux_23 (.flipped_data(int_mac_phy_txdetectrx_loopback),.lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_mac_phy_txdetectrx_loopback));
 lane_flip_mux
  #( 0, NL,1) u_tx_lane_flip_mux_24 (.flipped_data(int_ltssm_txelecidle),  .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_ltssm_txelecidle));
 lane_flip_mux
  #( 0, NL,1) u_tx_lane_flip_mux_25 (.flipped_data(int_mac_phy_txcompliance), .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_mac_phy_txcompliance));
 lane_flip_mux
  #( 0, NL,1) u_tx_lane_flip_mux_26 (.flipped_data(int_mac_phy_rxpolarity),  .lut(pol_lane_under_test), .flip_ctrl(pm_rx_pol_lane_flip_ctrl), .data(tmp_mac_phy_rxpolarity));
 lane_flip_mux
  #( 0, NL,1) u_tx_lane_flip_mux_27 (.flipped_data(laneflip_lanes_active),  .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(smlh_lanes_active));
 lane_flip_mux
  #( 0, NL,1) u_tx_lane_flip_mux_28 (.flipped_data(laneflip_set_rxstandby),  .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(smlh_set_rxstandby));
 lane_flip_mux
  #( 0, NL,1) u_tx_lane_flip_mux_28a (.flipped_data(laneflip_mac_phy_rxstandby),  .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(int_mac_phy_rxstandby));
 lane_flip_mux
  #( 0, NL,1) u_tx_lane_flip_mux_32b (.flipped_data(laneflip_smlh_blockaligncontrol), .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(smlh_blockaligncontrol));
 lane_flip_mux
  #( 0, NL,1) u_tx_lane_flip_mux_32 (.flipped_data(laneflip_deskew_lanes_active),  .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(deskew_lanes_active));
 lane_flip_mux
  #( 0, NL,TX_PSET_WD) u_tx_lane_flip_mux_43 (.flipped_data(int_smlh_lec_g4_pset_ltx), .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_smlh_lec_g4_pset_ltx));
 lane_flip_mux
  #( 0, NL,TX_PSET_WD) u_tx_lane_flip_mux_543 (.flipped_data(int_smlh_lec_g5_pset_ltx), .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_smlh_lec_g5_pset_ltx));
 lane_flip_mux
  #( 0, NL,TX_PSET_WD) u_tx_lane_flip_mux_643 (.flipped_data(int_smlh_lec_g6_pset_ltx), .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_smlh_lec_g6_pset_ltx));
 lane_flip_mux
  #( 0, NL,3) u_tx_lane_flip_mux_29 (.flipped_data(int_mac_phy_margin_cmd          ),  .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_mac_phy_margin_cmd          ));
 lane_flip_mux
  #( 0, NL,7) u_tx_lane_flip_mux_30 (.flipped_data(int_mac_phy_margin_offset       ),  .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_mac_phy_margin_offset       ));
 lane_flip_mux
  #( 0, NL,2) u_tx_lane_flip_mux_31 (.flipped_data(int_mac_phy_margin_clr_error_log),  .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_mac_phy_margin_clr_error_log));
 lane_flip_mux
  #( 0, NL,1)  u_tx_lane_flip_mux_44 (.flipped_data(int_smlh_margin_status_valid),  .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_smlh_margin_status_valid));
 lane_flip_mux
  #( 0, NL,16) u_tx_lane_flip_mux_45 (.flipped_data(int_smlh_margin_status      ),  .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_smlh_margin_status      ));
 lane_flip_mux
  #( 0, NL,5)  u_tx_lane_flip_mux_46 (.flipped_data(int_rmlh_deskew_ctlskp_err  ),  .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_rmlh_deskew_ctlskp_err  ));
 lane_flip_mux
  #( 0, NL,(TXSB_WD*5)) u_tx_lane_flip_mux_48 (.flipped_data(int_txdata_osfound), .lut(lane_under_test), .flip_ctrl(pm_tx_lane_flip_en), .data(tmp_txdata_osfound));

endmodule
