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
// ---    $DateTime: 2023/04/29 12:35:01 $ 
// ---    $Revision: #3 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/outbound/DWC_pcie_bridge_ob_np_dcmp_tsq.sv#3 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Bridge/outbound/svif/DWC_pcie_bridge_ob_np_dcmp_tsq_pkto_if.svh"
`include "Bridge/outbound/svif/DWC_pcie_bridge_ob_np_dcmp_tst_wtrls_if.svh"
`include "Bridge/outbound/svif/DWC_pcie_bridge_ob_np_dcmp_tst_wtasg_if.svh"
`include "Bridge/outbound/svif/DWC_pcie_bridge_ob_np_dcmp_tsq_pkti_if.svh"
`include "Bridge/outbound/svif/DWC_pcie_bridge_ob_np_dcmp_tsq_clk_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_bridge_ob_np_dcmp_tsq
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter type P_PKT_TYPE = logic
  ,parameter type P_APPTAG_PTR_TYPE = logic
  ,parameter type P_BYTE_LEN_TYPE = logic
  ,parameter MAX_WIRE_TAG = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_TAG_HIGH       : `CX_MAX_TAG
  ,parameter MAX_WIRE_TAG_PW = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_TAG_HIGH_WIDTH : `CX_LUT_PTR_WIDTH
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_bridge_ob_np_dcmp_tsq_clk_if.slave_mp    b_clk
  ,DWC_pcie_bridge_ob_np_dcmp_tsq_pkti_if.slave_mp   b_inq
  ,DWC_pcie_bridge_ob_np_dcmp_tst_wtasg_if.master_mp b_slv_wt_assigned
  ,DWC_pcie_bridge_ob_np_dcmp_tst_wtrls_if.slave_mp  b_slv_wt_released
  ,DWC_pcie_bridge_ob_np_dcmp_tsq_pkto_if.master_mp  b_tagq

  ,input  logic [              MAX_WIRE_TAG_PW -1:0] rdr_lookup_wiretag
  ,input  logic                                      rdr_pop_wiretag
  );

  // ##########################################################################
  //                               Wiring Declaration                          
  // ##########################################################################

  DWC_pcie_bridge_ob_np_dcmp_tsq_mgr_if #(.MAX_WIRE_TAG_PW(MAX_WIRE_TAG_PW)) b_mgr();

  // ##########################################################################
  //                              Instances Declaration                        
  // ##########################################################################

  DWC_pcie_bridge_ob_np_dcmp_tsq_mgr
   #(
   .MAX_WIRE_TAG   (MAX_WIRE_TAG)
  ,.MAX_WIRE_TAG_PW(MAX_WIRE_TAG_PW)
  ) u_mgr (
   .b_clk ( b_clk           )
  ,.b_mgr ( b_mgr.master_mp )
  );

// SNPS_SysML_CODE_START
  // ##########################################################################
  //                               Assign
  // ##########################################################################
  assign b_inq.w_pkt_halt = b_tagq.w_pkt_halt || (!b_mgr.w_next_tag_valid);

  assign b_slv_wt_assigned.w_new_wiretag_valid = b_mgr.w_use_tag    ;
  assign b_slv_wt_assigned.w_new_apptag        = b_tagq.w_pkt.in_tag;
  assign b_slv_wt_assigned.w_new_wiretag       = b_mgr.w_next_tag   ;

  assign b_mgr.w_cfg_ext_tag_en = b_inq.w_cfg_ext_tag_en              ;
  assign b_mgr.w_cfg_10b_tag_en = b_inq.w_cfg_10b_tag_en              ;

  logic                        r_rdr_pop_wiretag;
  logic [MAX_WIRE_TAG_PW -1:0] r_rdr_lookup_wiretag;

  always_ff @(posedge b_clk.w_slv_aclk, negedge b_clk.w_slv_aresetn) begin : r_rdr_pop_regPROC
    if(!b_clk.w_slv_aresetn) begin
      r_rdr_pop_wiretag    <= #`TP '0;
      r_rdr_lookup_wiretag <= #`TP '0;
    end else begin
      r_rdr_pop_wiretag    <= #`TP rdr_pop_wiretag;
      r_rdr_lookup_wiretag <= #`TP rdr_lookup_wiretag;
    end
  end : r_rdr_pop_regPROC

  assign b_mgr.w_rls_tag        = r_rdr_pop_wiretag ;
  assign b_mgr.w_rls_tag_num    = r_rdr_lookup_wiretag;

  assign b_mgr.w_use_tag        = b_inq.w_pkt.hv && b_mgr.w_next_tag_valid && (!b_tagq.w_pkt_halt);

  assign b_tagq.w_pkt = b_inq.w_pkt;

`ifndef SYNTHESIS
`endif
// SNPS_SysML_CODE_END

endmodule
