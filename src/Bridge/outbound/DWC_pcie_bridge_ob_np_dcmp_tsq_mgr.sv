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
// ---    $DateTime: 2021/10/29 02:04:56 $ 
// ---    $Revision: #2 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/outbound/DWC_pcie_bridge_ob_np_dcmp_tsq_mgr.sv#2 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Bridge/outbound/svif/DWC_pcie_bridge_ob_np_dcmp_tsq_mgr_if.svh"
`include "Bridge/outbound/svif/DWC_pcie_bridge_ob_np_dcmp_tsq_clk_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_bridge_ob_np_dcmp_tsq_mgr
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter    MAX_WIRE_TAG = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_TAG_HIGH       : `CX_MAX_TAG
  ,parameter MAX_WIRE_TAG_PW = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_TAG_HIGH_WIDTH : `CX_LUT_PTR_WIDTH
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_bridge_ob_np_dcmp_tsq_clk_if.slave_mp  b_clk
  ,DWC_pcie_bridge_ob_np_dcmp_tsq_mgr_if.master_mp b_mgr
  );


// SNPS_SysML_CODE_START
logic [MAX_WIRE_TAG_PW -1:0] s_rls_tag;
logic [2-1:0] tmgr_mode, r_tmgr_mode;
logic tmgr_empty;
logic tmgr_update_p;
logic int_en_normal;
logic int_en_vlow;

// Support for 5 bit tags
localparam MAX_WIRE_5BIT_TAG     = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_5BIT_TAG_HIGH        : (`CX_MAX_TAG        > 31   ? 31   : `CX_MAX_TAG      );
localparam MAX_WIRE_5BIT_TAG_PW  = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_5BIT_TAG_HIGH_WIDTH  : (`CX_LUT_PTR_WIDTH  > 5    ? 5    : `CX_LUT_PTR_WIDTH);

localparam MAX_WIRE_8BIT_TAG     = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_8BIT_TAG_HIGH        : (`CX_MAX_TAG        > 255  ? 255  : `CX_MAX_TAG      );
localparam MAX_WIRE_8BIT_TAG_PW  = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_8BIT_TAG_HIGH_WIDTH  : (`CX_LUT_PTR_WIDTH  > 8    ? 8    : `CX_LUT_PTR_WIDTH);

// Support for 10 bit tags
localparam MAX_WIRE_10BIT_TAG    = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_10BIT_TAG_HIGH       :  `CX_MAX_TAG;
localparam MAX_WIRE_10BIT_TAG_PW = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_10BIT_TAG_HIGH_WIDTH :  10;

  assign int_en_vlow = !b_mgr.w_cfg_ext_tag_en;

  assign int_en_normal = b_mgr.w_cfg_10b_tag_en;

assign s_rls_tag = (MAX_WIRE_TAG_PW)'(b_mgr.w_rls_tag_num);

always_comb begin : tmgr_mode_PROC
  case({int_en_vlow, int_en_normal})
    2'b00:               // 8 bit
      tmgr_mode = 2'b01; //   Low
    2'b01:               // 10 bit
      tmgr_mode = 2'b00; //   Normal
    2'b10:               // 5 bit
      tmgr_mode = 2'b10; //   VLow
    default:             // Invalid cfg
      tmgr_mode = 2'b01; //   Low
  endcase
end : tmgr_mode_PROC

always_ff @(posedge b_clk.w_slv_aclk, negedge b_clk.w_slv_aresetn) begin : tmgr_mode_r_PROC
  if(!b_clk.w_slv_aresetn) begin
    r_tmgr_mode <= #`TP '0;
  end else begin
    r_tmgr_mode <= #`TP tmgr_mode;
  end
end : tmgr_mode_r_PROC

assign tmgr_update_p = (r_tmgr_mode != tmgr_mode);

  DWC_pcie_tagMngr
   #(
    .P_MAXTAG     ( MAX_WIRE_10BIT_TAG )

  ,.P_MAXTAG_LOW  ( MAX_WIRE_8BIT_TAG  )

  ,.P_MAXTAG_VLOW ( MAX_WIRE_5BIT_TAG  )

  ,.P_TAGWD       ( MAX_WIRE_TAG_PW    )
  ) u_tmgr (
   .clk           ( b_clk.w_slv_aclk    )
  ,.rst_n         ( b_clk.w_slv_aresetn )

  ,.mode          ( tmgr_mode           )
  ,.update_p      ( tmgr_update_p       )

  ,.pop_en        ( b_mgr.w_use_tag     )
  ,.pop_tag       ( b_mgr.w_next_tag    )
  ,.pop_tag_info  ( /* NC */            )
  ,.pop_empty     ( tmgr_empty          )

  ,.push_en       ( b_mgr.w_rls_tag     )
  ,.push_tag      ( s_rls_tag           )
  ,.push_tag_info ( '0                  )
  );

  assign b_mgr.w_next_tag_valid = !tmgr_empty;
// SNPS_SysML_CODE_END

endmodule
