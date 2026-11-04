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
// ---    $Revision: #35 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/phy_tb_backdoor.svh#35 $
// -------------------------------------------------------------------------
// Description: Backdoor access for the PCIe IIP TB when simulating with the
// generic PHY.
// -----------------------------------------------------------------------------

// --------------------------------------------------------
// Force receiver detection result in the PHY
// --------------------------------------------------------
always @( rxpresent ) begin: force_rxdetect_proc
  $display("%m %t : Forcing receiver detection in Generic PHY with mask %0b", $time, rxpresent);
`ifdef CX_NL_GTR_8
  force u_phy.u_phy_vmain_top.u_pma.genpma[15].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[15];
  force u_phy.u_phy_vmain_top.u_pma.genpma[14].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[14];
  force u_phy.u_phy_vmain_top.u_pma.genpma[13].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[13];
  force u_phy.u_phy_vmain_top.u_pma.genpma[12].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[12];
  force u_phy.u_phy_vmain_top.u_pma.genpma[11].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[11];
  force u_phy.u_phy_vmain_top.u_pma.genpma[10].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[10];
  force u_phy.u_phy_vmain_top.u_pma.genpma[ 9].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[ 9];
  force u_phy.u_phy_vmain_top.u_pma.genpma[ 8].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[ 8];
`endif // CX_NL_GTR_8

`ifdef CX_NL_GTR_4
  force u_phy.u_phy_vmain_top.u_pma.genpma[ 7].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[ 7];
  force u_phy.u_phy_vmain_top.u_pma.genpma[ 6].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[ 6];
  force u_phy.u_phy_vmain_top.u_pma.genpma[ 5].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[ 5];
  force u_phy.u_phy_vmain_top.u_pma.genpma[ 4].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[ 4];
`endif // CX_NL_GTR_4

`ifdef CX_NL_GTR_2
  force u_phy.u_phy_vmain_top.u_pma.genpma[ 3].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[ 3];
  force u_phy.u_phy_vmain_top.u_pma.genpma[ 2].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[ 2];
`endif // CX_NL_GTR_2

`ifdef CX_NL_GTR_1
  force u_phy.u_phy_vmain_top.u_pma.genpma[ 1].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[ 1];
`endif // CX_NL_GTR_1
  force u_phy.u_phy_vmain_top.u_pma.genpma[ 0].u_serdes_lane.u_xphy_ser.sim_rcvr_present = rxpresent[ 0];

end


// Generic Phy Control Interface instance is always required for the UTB
// testbench and must be in both the DUT and VDUT devices.
// Other TBs only require this instance in the DUT device
`ifdef UTB
  `define CREATE_PHY_TB_CTRL
`else
  `ifndef DEVICE_IS_VDUT
    `define CREATE_PHY_TB_CTRL
  `endif
`endif

`ifdef CREATE_PHY_TB_CTRL
  // Generic Phy Control Interface
  phy_tb_ctl
  #(.NL(NL),
    .VPT_NUM(`CX_PHY_NUM_MACROS),
    .TX_COEF_WD(TX_COEF_WD),
    .TX_SINGLE_COEF_WD(TX_SINGLE_COEF_WD),
    .DIRFEEDBACK_WD(DIRFEEDBACK_WD),
    .FOMFEEDBACK_WD(FOMFEEDBACK_WD),
    .TX_FS_WD(FS_LF_WD)
   ) u_phy_tb_ctl (
    .pclk                           (u_phy.u_phy_vmain_top.int_pclk[0]),
    .phy_rst_n                      (u_phy.phy_rst_n),
    .phy_reg_clk_g                  (u_phy.phy_reg_clk_g),
    .set_eq_feedback_delay          (u_phy.u_phy_vmain_top.set_eq_feedback_delay), 
    .eq_feedback_delay              (u_phy.u_phy_vmain_top.eq_feedback_delay), 
    .set_eq_dirfeedback             (u_phy.u_phy_vmain_top.set_eq_dirfeedback),
    .eq_dirfeedback_value           (u_phy.u_phy_vmain_top.eq_dirfeedback_value),   
    .set_eq_fomfeedback             (u_phy.u_phy_vmain_top.set_eq_fomfeedback),
    .eq_fomfeedback_value           (u_phy.u_phy_vmain_top.eq_fomfeedback_value),
    .set_localfs_g3                 (u_phy.u_phy_vmain_top.set_localfs_g3),
    .localfs_value_g3               (u_phy.u_phy_vmain_top.localfs_value_g3),
    .set_localfs_g4                 (u_phy.u_phy_vmain_top.set_localfs_g4),
    .localfs_value_g4               (u_phy.u_phy_vmain_top.localfs_value_g4),
    .set_localfs_g5                 (u_phy.u_phy_vmain_top.set_localfs_g5),
    .localfs_value_g5               (u_phy.u_phy_vmain_top.localfs_value_g5),
    .set_localfs_g6                 (u_phy.u_phy_vmain_top.set_localfs_g6),
    .localfs_value_g6               (u_phy.u_phy_vmain_top.localfs_value_g6),
    .set_locallf_g3                 (u_phy.u_phy_vmain_top.set_locallf_g3),
    .locallf_value_g3               (u_phy.u_phy_vmain_top.locallf_value_g3),
    .set_locallf_g4                 (u_phy.u_phy_vmain_top.set_locallf_g4),
    .locallf_value_g4               (u_phy.u_phy_vmain_top.locallf_value_g4),
    .set_locallf_g5                 (u_phy.u_phy_vmain_top.set_locallf_g5),
    .locallf_value_g5               (u_phy.u_phy_vmain_top.locallf_value_g5),
    .set_locallf_g6                 (u_phy.u_phy_vmain_top.set_locallf_g6),
    .locallf_value_g6               (u_phy.u_phy_vmain_top.locallf_value_g6),
    .set_local_tx_pset_coef_delay   (u_phy.u_phy_vmain_top.set_local_tx_pset_coef_delay),
    .local_tx_pset_coef_delay       (u_phy.u_phy_vmain_top.local_tx_pset_coef_delay),
    .set_local_tx_pset_coef         (u_phy.u_phy_vmain_top.set_local_tx_pset_coef),
    .local_tx_pset_cplus1_value     (u_phy.u_phy_vmain_top.local_tx_pset_cplus1_value),
    .local_tx_pset_czero_value      (u_phy.u_phy_vmain_top.local_tx_pset_czero_value),    
    .local_tx_pset_cminus1_value    (u_phy.u_phy_vmain_top.local_tx_pset_cminus1_value),    
    .local_tx_pset_cminus2_value    (u_phy.u_phy_vmain_top.local_tx_pset_cminus2_value),    
    .set_rxadaption                 (u_phy.u_phy_vmain_top.set_rxadaption ),
    .rate_random_phystatus_en       (u_phy.rate_random_phystatus_en),
    .powerdown_random_phystatus_en  (u_phy.powerdown_random_phystatus_en),
    .syncheader_random_en           (u_phy.syncheader_random_en),
    .disable_skp_addrm_en           (u_phy.disable_skp_addrm_en),
    .p1_phystatus_time_load_en      (u_phy.p1_phystatus_time_load_en),
    .p1_phystatus_time              (u_phy.p1_phystatus_time),    
    .p2_phystatus_rise_random_en      (u_phy.p2_phystatus_rise_random_en),
    .p2_random_phystatus_rise_load_en (u_phy.p2_random_phystatus_rise_load_en),
    .p2_random_phystatus_rise_value   (u_phy.p2_random_phystatus_rise_value),
    .p2_phystatus_fall_random_en      (u_phy.p2_phystatus_fall_random_en),
    .p2_random_phystatus_fall_load_en (u_phy.p2_random_phystatus_fall_load_en),
    .p2_random_phystatus_fall_value   (u_phy.p2_random_phystatus_fall_value),  
    .pclkack_off_time_load_en       (u_phy.pclkack_off_time_load_en),
    .pclkack_off_time               (u_phy.pclkack_off_time),
    .pclkack_on_time_load_en        (u_phy.pclkack_on_time_load_en),
    .pclkack_on_time                (u_phy.pclkack_on_time),    
    .phy_cr_respond_time            (u_phy.phy_cr_respond_time),        
    .phy_cr_rd_data_load_en         (u_phy.phy_cr_rd_data_load_en), 
    .phy_cr_rd_data_return_value    (u_phy.phy_cr_rd_data_return_value),
    // For RxDataValid with Elastic Buffer Mode=1
    .rxdatavalid_shift_en           (u_phy.rxdatavalid_shift_en),
    .fixed_rxdatavalid_shift_cycle  (u_phy.fixed_rxdatavalid_shift_cycle),
    .P1X_to_P1_exit_mode            (u_phy.P1X_to_P1_exit_mode),
    .cdr_fast_lock                  (u_phy.cdr_fast_lock),
    // For Margining at Receiver
    .random_margin_status_en        (u_phy.random_margin_status_en),
    .fixed_margin_status_thr        (u_phy.fixed_margin_status_thr),
    .set_p2m_messagebus             (u_phy.u_phy_vmain_top.set_p2m_messagebus),
    .p2m_messagebus_command_value   (u_phy.u_phy_vmain_top.p2m_messagebus_command_value),
    .set_m2p_messagebus             (u_phy.u_phy_vmain_top.set_m2p_messagebus),
    .m2p_messagebus_command_value   (u_phy.u_phy_vmain_top.m2p_messagebus_command_value),
    .VoltageSupported               (u_phy.u_phy_vmain_top.VoltageSupported),
    .IndErrorSampler                (u_phy.u_phy_vmain_top.IndErrorSampler),
    .MaxVoltageOffset               (u_phy.u_phy_vmain_top.MaxVoltageOffset),
    .MaxTimingOffset                (u_phy.u_phy_vmain_top.MaxTimingOffset),    
    .UnsupportedVoltageOffset       (u_phy.u_phy_vmain_top.UnsupportedVoltageOffset ),        
    .SampleReportingMethod          (u_phy.u_phy_vmain_top.SampleReportingMethod),
    .margin_error_cnt_mode          (u_phy.u_phy_vmain_top.margin_error_cnt_mode),
    .margin_cycle_for_an_error      (u_phy.u_phy_vmain_top.margin_cycle_for_an_error),
    .margin_bit_error_rate_factor   (u_phy.u_phy_vmain_top.margin_bit_error_rate_factor),
    .set_margin_cnt                 (u_phy.u_phy_vmain_top.set_margin_cnt),
    .margin_sampl_cnt_to_set        (u_phy.u_phy_vmain_top.margin_sampl_cnt_to_set),
    .margin_error_cnt_to_set        (u_phy.u_phy_vmain_top.margin_error_cnt_to_set),
    // For CCIX ESM Calibration
    .random_calibrt_complete_en     (u_phy.u_phy_vmain_top.random_calibrt_complete_en),
    .fixed_calibrt_complete_thr     (u_phy.u_phy_vmain_top.fixed_calibrt_complete_thr),
    .calibration_complete_en        (u_phy.u_phy_vmain_top.calibration_complete_en),
    // For LowPinCount
    .update_localfslf_mode          (u_phy.u_phy_vmain_top.update_localfslf_mode),
    .pclk_per_ps                    ( )
  );
  `ifdef DWC_GPHY_IDEAL
    initial  u_phy_tb_ctl.set_ideal_mode(1'b1);
  `endif
`else
  // provide default drivers for these control signals
  initial begin
    force u_phy.u_phy_vmain_top.set_eq_feedback_delay = 1'b0; 
    force u_phy.u_phy_vmain_top.set_eq_dirfeedback    = 1'b0;
    force u_phy.u_phy_vmain_top.set_eq_fomfeedback    = 1'b0;
    force u_phy.u_phy_vmain_top.set_localfs_g3        = 1'b0;
    force u_phy.u_phy_vmain_top.set_localfs_g4        = 1'b0;
    force u_phy.u_phy_vmain_top.set_localfs_g5        = 1'b0;
    force u_phy.u_phy_vmain_top.set_localfs_g6        = 1'b0;
    force u_phy.u_phy_vmain_top.set_locallf_g3        = 1'b0;
    force u_phy.u_phy_vmain_top.set_locallf_g4        = 1'b0;
    force u_phy.u_phy_vmain_top.set_locallf_g5        = 1'b0;
    force u_phy.u_phy_vmain_top.set_locallf_g6        = 1'b0;
    force u_phy.u_phy_vmain_top.set_local_tx_pset_coef_delay = 1'b0;
    force u_phy.u_phy_vmain_top.set_local_tx_pset_coef       = 1'b0;  
    force u_phy.rate_random_phystatus_en      = 1'b1;
    force u_phy.powerdown_random_phystatus_en = 1'b1;
    force u_phy.syncheader_random_en          = 1'b1;
    force u_phy.disable_skp_addrm_en          = 1'b0;
    force u_phy.p1_phystatus_time_load_en     = 1'b0;
    force u_phy.p1_phystatus_time             = 13'b0;    
    force u_phy.p2_phystatus_rise_random_en         = 1'b1;  
    force u_phy.p2_random_phystatus_rise_load_en    = 1'b0;
    force u_phy.p2_random_phystatus_rise_value      = 13'b0;
    force u_phy.p2_phystatus_fall_random_en         = 1'b1; 
    force u_phy.p2_random_phystatus_fall_load_en    = 1'b0;
    force u_phy.p2_random_phystatus_fall_value      = 13'b0;      
    force u_phy.pclkack_off_time_load_en      = 1'b0;
    force u_phy.pclkack_off_time              = 31'b0;
    force u_phy.pclkack_on_time_load_en       = 1'b0;
    force u_phy.pclkack_on_time               = 31'b0;
    force u_phy.rxdatavalid_shift_en          = 1'b0;
    force u_phy.fixed_rxdatavalid_shift_cycle = 4'h0;
    force u_phy.random_margin_status_en       = 1'b1;
    force u_phy.fixed_margin_status_thr       = 8'h08;
    force u_phy.random_calibrt_complete_en    = 1'b1;
    force u_phy.fixed_calibrt_complete_thr    = 8'h08;
    force u_phy.phy_cr_respond_time           = 16'h5555;       
    force u_phy.phy_cr_rd_data_load_en        = 1'b0; 
    force u_phy.phy_cr_rd_data_return_value   = 16'b0;
    force u_phy.P1X_to_P1_exit_mode           = 1'b0; 
    force u_phy.cdr_fast_lock                 = 1'b0; 
    force u_phy.calibration_complete_en           = 1'b1;
    force u_phy.u_phy_vmain_top.set_p2m_messagebus = 1'b0;
    force u_phy.u_phy_vmain_top.set_m2p_messagebus = 1'b0;
    force u_phy.u_phy_vmain_top.update_localfslf_mode = '1;
  end
`endif // CREATE_PHY_TB_CTRL
