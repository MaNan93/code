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
// ---    $DateTime: 2023/09/27 02:27:25 $
// ---    $Revision: #41 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/compile.f#41 $
// -------------------------------------------------------------------------

/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/DWC_pcie_ctl_cc_constants.svh
+define+PHY_TB_CTL_PATH=u_phy_tb_ctl


// workaround as GPHY does not meet 128ns timing for returning the pset coef msg bus
+define+SVA_POSTED_WR_TO_TX_CONTROL5_TOL_NS=500



-y /home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic
+incdir+/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_cc_constants.svh
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_defs.svh
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_pkg.svh
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_bcm43.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_bcm44.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_timer.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_pipe_gasket.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_pll.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_ser.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_deser.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_los_lane.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_los.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_pma_lane.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_pma.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_10b8bdec.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_8b10benc.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_elasbuf.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_cdet.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_pipe2phy.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_lpbk.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_sdm_1s_lane.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_sdm_1s.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_pcs_lane.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_pcs.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_blockalign.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_pmu.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_eq_bfm.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_viewport_bfm.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_margin_bfm.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_reg.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_reg_sub.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_regbus_master.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_regbus_slave.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_regbus_cont.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_regbus_arb.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_pipe_aggr.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy_vmain_top.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/Phy/generic/DWC_pcie_gphy.v
/home/jjt/pcie_gen6_cxl_proj/pcie_gen6_cxl/src/DWC_pcie_ctl-undef.v
