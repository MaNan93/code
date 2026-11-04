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
// ---    $Revision: #16 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/phy_sva_exceptions.svh#16 $
// -----------------------------------------------------------------------------

// --------------------------------------------------------
// Disabling specific PIPE SVA failures
//
// The PIPE SVA checker which is part of VTB may flag PHY
// violations which are known or that will be fixed at a 
// later stage.
//
// The code below can be used to disable specific checks
// throughout the simulation
// --------------------------------------------------------

import uvm_pkg::*;

initial begin
  #0.2;

  `ifdef CX_PCIE_OVER_CIO_ENABLE
    // Disable Pipe SVA's for lanes 1-NL
    force `HDL_DUT_ROOT.`HDL_DUT_SUBSYS_PATH.pipe_assertions_protocol.disable_sva_perlane = {{(NL-1){1'b1}}, 1'b0}; 
    force `HDL_DUT_ROOT.`HDL_DUT_SUBSYS_PATH.pipe_assertions_datapath.disable_sva_perlane = {{(NL-1){1'b1}}, 1'b0};
  `endif
  //  disabled  due to rate change in p2
  `PIPE_SVA_PER_LANE_KILL(`HDL_DUT_ROOT.`HDL_DUT_SUBSYS_PATH, pipe_mac_sva.a_pclk_not_running_P2)

  // Disable SVAs that do not apply to the PIPE2PIPE mode
  if (interface_type == 2'b01) begin
    `SNPS_SVA_KILL(`HDL_DUT_ROOT.`HDL_DUT_SUBSYS_PATH, cpcie_clkrst_sva.ap_core_clk_ug_never_exceed_max_config_freq)
    `SNPS_SVA_KILL(`HDL_DUT_ROOT.`HDL_DUT_SUBSYS_PATH, cpcie_clkrst_sva.ap_core_clk_never_exceed_max_config_freq)
    `SNPS_SVA_KILL(`HDL_DUT_ROOT.`HDL_DUT_SUBSYS_PATH, u_pcie_core.xchecker_inst.a_xchk_phy_clk_req_n)
    `SNPS_SVA_KILL(`HDL_DUT_ROOT.`HDL_DUT_SUBSYS_PATH, pipe_assertions_protocol.a_phy_mac_pclkack_n_asserted_when_pclk_is_on)
    `SNPS_SVA_KILL(`HDL_DUT_ROOT.`HDL_DUT_SUBSYS_PATH, ptm_sva_inst.u_ptm_sva.ap_ptm_local_clock_dsp)
    `SNPS_SVA_KILL(`HDL_DUT_ROOT.`HDL_DUT_SUBSYS_PATH, cpcie_clkrst_sva.ap_core_clk_phase_aligned_pclk)
    `SNPS_SVA_KILL(`HDL_DUT_ROOT.`HDL_DUT_SUBSYS_PATH, cpcie_clkrst_sva.ap_core_clk_ug_core_clk_synchronized)
    `SNPS_SVA_KILL(`HDL_DUT_ROOT.`HDL_DUT_SUBSYS_PATH, cdm_clk_gate_chk_sva_inst.u_cdm_clk_gate_chk_sva.lbc_cdm_clk_write_high_fall)
    `SNPS_SVA_KILL(`HDL_DUT_ROOT.`HDL_DUT_SUBSYS_PATH, u_pcie_core.xchecker_inst.a_xchk_app_sris_mode)
    
    `PIPE_SVA_PER_LANE_KILL(`HDL_DUT_ROOT.`HDL_DUT_SUBSYS_PATH, pipe_mac_sva.a_pclk_maxpclk_in_sync)
    `PIPE_SVA_PER_LANE_KILL(`HDL_DUT_ROOT.`HDL_DUT_SUBSYS_PATH, pipe_mac_sva.a_maxpclkack_n_reset_value)
    `PIPE_SVA_PER_LANE_KILL(`HDL_DUT_ROOT.`HDL_DUT_SUBSYS_PATH, pipe_mac_sva.a_tx_elecidle_transmitting) 
    `PIPE_SVA_PER_LANE_KILL(`HDL_DUT_ROOT.`HDL_DUT_SUBSYS_PATH, pipe_mac_sva.a_pclk_period)
    `PIPE_SVA_PER_LANE_KILL(`HDL_DUT_ROOT.`HDL_DUT_SUBSYS_PATH, pipe_mac_sva.a_get_preset_coeffs)
    `PIPE_SVA_PER_LANE_KILL(`HDL_DUT_ROOT.`HDL_DUT_SUBSYS_PATH, pipe_mac_sva.a_phystatus_reset_value)
    `PIPE_SVA_PER_LANE_KILL(`HDL_DUT_ROOT.`HDL_DUT_SUBSYS_PATH, pipe_mac_sva.a_bare_com_when_skip_del)
    `PIPE_SVA_PER_LANE_KILL(`HDL_DUT_ROOT.`HDL_DUT_SUBSYS_PATH, pipe_mac_sva.a_phystatus_returned_after_reset_deassertion)
    `PIPE_SVA_PER_LANE_KILL(`HDL_DUT_ROOT.`HDL_DUT_SUBSYS_PATH, pipe_mac_sva.a_max_pclk_period)
  end

end

