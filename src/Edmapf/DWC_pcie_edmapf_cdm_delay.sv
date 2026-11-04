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
// ---    $DateTime: 2023/12/19 16:41:09 $ 
// ---    $Revision: #8 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_cdm_delay.sv#8 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_cdmregs_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_cdm_delay #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter                CX_NFUNC = `CX_NFUNC
  ,parameter CX_REMOTE_LUT_PTR_WIDTH = `CX_REMOTE_LUT_PTR_WIDTH
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_aclks_if.slave_mp    b_clk
  ,DWC_pcie_edmapf_cdmregs_if.master_mp b_dst
  ,DWC_pcie_edmapf_cdmregs_if.slave_mp  b_src
  );


// SNPS_SysML_CODE_START
  localparam LP_REMOTE_RD_REQ_BRIDGE_SIZE = `CX_MAX_MTU == 128  ? 3'h0 :
                                            `CX_MAX_MTU == 256  ? 3'h1 :
                                            `CX_MAX_MTU == 512  ? 3'h2 :
                                            `CX_MAX_MTU == 1024 ? 3'h3 :
                                            `CX_MAX_MTU == 2048 ? 3'h4 :
                                            3'h5;

  localparam DATA_DELAY_BCM36_NHS = 3;

  typedef struct packed {
    logic                               cfg_bridge_sb_init_i          ; //DEFAULT: tie off '0
    logic                               cfg_ext_tag_en                ; //DEFAULT: `DEFAULT_EXT_TAG_FIELD_SUPPORTED;
    logic                               cfg_10b_tag_en                ; //DEFAULT: `DEFAULT_10BITS_TAG_FIELD_SUPPORTED;
    logic            [(3*CX_NFUNC)-1:0] cfg_max_payload_size          ; //DEFAULT: '0
    logic            [(3*CX_NFUNC)-1:0] cfg_max_rd_req_size           ; //DEFAULT: 3'b010
    logic [CX_REMOTE_LUT_PTR_WIDTH-1:0] cfg_remote_max_bridge_tag     ; //DEFAULT: tie off `CX_REMOTE_MAX_TAG
    logic                         [2:0] cfg_remote_rd_req_bridge_size ; //DEFAULT: tie off LP_REMOTE_RD_REQ_BRIDGE_SIZE
  } cdm_s;

  cdm_s r_cdm;

  always_ff @ (posedge b_clk.w_aux_clk or negedge b_clk.w_reset_n) begin : PROC_ff_regs
    if (!b_clk.w_reset_n) begin
      r_cdm.cfg_bridge_sb_init_i          <= # `TP '0; 
      r_cdm.cfg_ext_tag_en                <= # `TP '0;
      r_cdm.cfg_10b_tag_en                <= # `TP '0;
      r_cdm.cfg_max_payload_size          <= # `TP '0;
      r_cdm.cfg_max_rd_req_size           <= # `TP 3'b010;
      r_cdm.cfg_remote_max_bridge_tag     <= # `TP `CX_REMOTE_MAX_TAG;
      r_cdm.cfg_remote_rd_req_bridge_size <= # `TP LP_REMOTE_RD_REQ_BRIDGE_SIZE;
    end else begin
      r_cdm.cfg_bridge_sb_init_i          <= # `TP b_src.w_cfg_bridge_sb_init_i          ; 
      r_cdm.cfg_ext_tag_en                <= # `TP b_src.w_cfg_ext_tag_en                ;
      r_cdm.cfg_10b_tag_en                <= # `TP b_src.w_cfg_10b_tag_en                ;
      r_cdm.cfg_max_payload_size          <= # `TP b_src.w_cfg_max_payload_size          ;
      r_cdm.cfg_max_rd_req_size           <= # `TP b_src.w_cfg_max_rd_req_size           ;
      r_cdm.cfg_remote_max_bridge_tag     <= # `TP b_src.w_cfg_remote_max_bridge_tag     ;
      r_cdm.cfg_remote_rd_req_bridge_size <= # `TP b_src.w_cfg_remote_rd_req_bridge_size ;
    end
  end

  assign b_dst.w_cfg_bridge_sb_init_i          = r_cdm.cfg_bridge_sb_init_i         ;
  assign b_dst.w_cfg_ext_tag_en                = r_cdm.cfg_ext_tag_en               ;
  assign b_dst.w_cfg_10b_tag_en                = r_cdm.cfg_10b_tag_en               ;
  assign b_dst.w_cfg_max_payload_size          = r_cdm.cfg_max_payload_size         ;
  assign b_dst.w_cfg_max_rd_req_size           = r_cdm.cfg_max_rd_req_size          ;
  assign b_dst.w_cfg_remote_max_bridge_tag     = r_cdm.cfg_remote_max_bridge_tag    ;
  assign b_dst.w_cfg_remote_rd_req_bridge_size = r_cdm.cfg_remote_rd_req_bridge_size;
// SNPS_SysML_CODE_END

endmodule
