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
// ---    $Revision: #4 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/outbound/DWC_pcie_bridge_ob_np_dcmp_tst.sv#4 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Bridge/outbound/svif/DWC_pcie_bridge_ob_np_dcmp_tst_clk_if.svh"
`include "Bridge/outbound/svif/DWC_pcie_bridge_ob_np_dcmp_tst_llo_if.svh"
`include "Bridge/outbound/svif/DWC_pcie_bridge_ob_np_dcmp_tst_wtrls_if.svh"
`include "Bridge/outbound/svif/DWC_pcie_bridge_ob_np_dcmp_tst_wtasg_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_bridge_ob_np_dcmp_tst
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter            CC_MAX_SLV_TAG = `CC_MAX_SLV_TAG
  ,parameter         CC_MAX_SLV_TAG_PW = `CC_MAX_SLV_TAG_PW
  ,parameter              MAX_WIRE_TAG = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_TAG_HIGH       : `CX_MAX_TAG
  ,parameter           MAX_WIRE_TAG_PW = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_TAG_HIGH_WIDTH : `CX_LUT_PTR_WIDTH
  ,parameter                        TP = `TP
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_bridge_ob_np_dcmp_tst_clk_if.slave_mp    b_clk
  ,DWC_pcie_bridge_ob_np_dcmp_tst_llo_if.master_mp   b_slv_rd_ll
  ,DWC_pcie_bridge_ob_np_dcmp_tst_wtrls_if.master_mp b_slv_tag_released
  ,DWC_pcie_bridge_ob_np_dcmp_tst_wtasg_if.slave_mp  b_slv_wt_assigned
  );

  // ##########################################################################
  //                              Instances Declaration                        
  // ##########################################################################

  localparam L_WD_RSRC    = MAX_WIRE_TAG_PW;
  localparam L_WD_ALCT    = CC_MAX_SLV_TAG_PW;
  localparam L_BURST_ALCT = 1
                            // Enable tail tracking when DMWr and Slave Wrap enabled - there can be request interleaving
                            - 1
                            ;
  localparam L_FANOUT = 1 +1;

  logic [L_FANOUT  -1:0] w_new_wiretag_valid;
  logic [L_WD_ALCT -1:0] w_new_apptag;
  logic [L_WD_RSRC -1:0] w_new_wiretag;

  logic                  r_new_wiretag_valid;
  logic                  r_new_wiretag_valid_int;
  logic [L_WD_ALCT -1:0] r_new_apptag;
  logic [L_WD_RSRC -1:0] r_new_wiretag;

  always_ff @(posedge b_clk.w_slv_aclk, negedge b_clk.w_slv_aresetn)
    if(!b_clk.w_slv_aresetn) begin
      r_new_wiretag_valid <= #`TP 1'b0;
      r_new_wiretag_valid_int <= #`TP 1'b0;
      r_new_apptag        <= #`TP '0;
      r_new_wiretag       <= #`TP '0;
    end else begin
      r_new_wiretag_valid <= #`TP b_slv_wt_assigned.w_new_wiretag_valid;
      r_new_wiretag_valid_int <= #`TP b_slv_wt_assigned.w_new_wiretag_valid;
      r_new_apptag        <= #`TP b_slv_wt_assigned.w_new_apptag;
      r_new_wiretag       <= #`TP b_slv_wt_assigned.w_new_wiretag;
    end

  assign w_new_wiretag_valid = { r_new_wiretag_valid_int, r_new_wiretag_valid};
  assign w_new_apptag        = r_new_apptag;
  assign w_new_wiretag       = r_new_wiretag;

  DWC_pcie_bridge_llfifo_simple
   #(
  .P_NRESOURCES   ( MAX_WIRE_TAG + 1          )
 ,.P_NALLOCATORS  ( CC_MAX_SLV_TAG            )
 ,.P_RSRC_ID_WD   ( L_WD_RSRC                 )
 ,.P_ALCT_ID_WD   ( L_WD_ALCT                 )
 ,.P_BURST_ALCT   ( L_BURST_ALCT              )
 ,.P_FANOUT       ( 2                         )
) u_sll (
  .clk                 ( b_clk.w_slv_aclk                 )
 ,.rst_n               ( b_clk.w_slv_aresetn              )

 ,.alct_req            ( w_new_wiretag_valid              )
 ,.alct_alctr_id       ( w_new_apptag                     )
 ,.alct_rsrc_id        ( w_new_wiretag                    )

 ,.rls_req             ( b_slv_rd_ll.w_pop_wiretag        )
 ,.rls_alctr_id        ( b_slv_rd_ll.w_apptag             )
 ,.rls_all             ( 1'b0                             )
 ,.rls_valid           ( /* NC */                         )
 ,.rls_rsrc_id         ( b_slv_rd_ll.w_wiretag            )
 ,.rls_last            ( b_slv_rd_ll.w_wiretag_is_last    )
);

// SNPS_SysML_CODE_START
  assign b_slv_tag_released.w_released_valid   = b_slv_rd_ll.w_pop_wiretag;
  assign b_slv_tag_released.w_released_wiretag = b_slv_rd_ll.w_wiretag    ;

`ifndef SYNTHESIS
`endif
// SNPS_SysML_CODE_END

endmodule
