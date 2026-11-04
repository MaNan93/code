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
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/slave/DWC_pcie_axi_slv_atu.sv#3 $
// -------------------------------------------------------------------------
// Module description:
// ---------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_axi_slv_atu
 #(
  parameter ATU_OUT_REGIONS                  = 2,
  parameter ATU_BASE_WD                      = 32,
  parameter ATU_REG_WD                       = 16,
  parameter ATU_OUT_MIN1                     = 2,
  parameter SLAVE_BUS_ADDR_WIDTH             = 32,
  parameter NFUNC_WD                         = 3,
  parameter ATU_UPR_LMT_WD                   = 8        // Width of Upper Limit Address register
 )
 
                             (
  // -------------------------------------------------------------------------------------
  // ATU configuration interface
  input       [(ATU_BASE_WD*ATU_OUT_MIN1)-1:0]       atu_reg_out_upr_base,
  input       [ATU_OUT_MIN1-1:0]                     atu_reg_out_en,
  input       [5*ATU_OUT_MIN1-1:0]                   atu_reg_out_type,
  input       [(ATU_REG_WD*ATU_OUT_MIN1)-1:0]        atu_reg_out_base,
  input       [(ATU_REG_WD*ATU_OUT_MIN1)-1:0]        atu_reg_out_limit,
  input       [ATU_UPR_LMT_WD*ATU_OUT_MIN1-1:0]      atu_reg_out_uppr_limit,
  input       [ATU_OUT_MIN1-1:0]                     atu_reg_out_incr_rgn_size,    // Maximum region size control bit
  input       [ATU_OUT_MIN1-1:0]                     atu_reg_out_invert,
  input       [(NFUNC_WD*ATU_OUT_MIN1)-1:0]          atu_reg_out_func_num,
  input       [ATU_OUT_MIN1-1:0]                     atu_reg_out_func_bypass,
  input       [ATU_OUT_MIN1-1:0]                     atu_reg_out_snp,
  // -------------------------------------------------------------------------------------
  // ATU control interface
  input                                              atu_write,
  input                                              atu_bypass,
  input       [4:0]                                  type_info,
  input       [NFUNC_WD-1:0]                         func_num,
  input                                              snp,
  input       [SLAVE_BUS_ADDR_WIDTH-1:0]             addr,
  // -------------------------------------------------------------------------------------
  // Translation interface
  output wire [4:0]                                  satu_type,
  output wire [NFUNC_WD-1:0]                         satu_func_num,
  output wire                                        satu_snp
  );
  // -------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------
  localparam ADDR64 = SLAVE_BUS_ADDR_WIDTH > 32;
  localparam ATU_UPR_LMT_WD_MDFD =  ATU_UPR_LMT_WD == 32 ? 31: ATU_UPR_LMT_WD;        // Modified width of Upper Limit Address register
  localparam ATU_UPR_LMT_WD_ADR64 = ADDR64 == 1 ? ATU_UPR_LMT_WD : 0;

  // -------------------------------------------------------------------------------------
  // Wire/Reg
  // -------------------------------------------------------------------------------------
  reg                                                s_atu_upper_match;
  reg                                                s_atu_match;
  reg  [4:0]                                         s_satu_type;
  reg  [NFUNC_WD-1:0]                                s_satu_func_num;
  reg                                                s_satu_snp;

  // -------------------------------------------------------------------------------------
  // Design
  // -------------------------------------------------------------------------------------
  // Translation performed based on priority decode of matching regions
  always @(*) begin : proc_comb_region_priority_decode
    integer i;
    // Assign default value
    s_atu_match     = 0;
    s_satu_type     = type_info;
    s_satu_func_num = func_num;
    s_satu_snp      = snp;

    // Loop down so region 0 will have highest priority
    for (i=ATU_OUT_REGIONS-1; i >=0; i=i- 1) begin
      // Detect when Address matches Region
      if (atu_reg_out_incr_rgn_size[i]) begin     // Increased max region size
         s_atu_upper_match = ADDR64 && (ATU_UPR_LMT_WD!=32) ? addr[(SLAVE_BUS_ADDR_WIDTH-32)+ATU_UPR_LMT_WD_MDFD +: 32-ATU_UPR_LMT_WD_MDFD] ==
             atu_reg_out_upr_base[(ATU_BASE_WD*i)+ATU_UPR_LMT_WD_MDFD +: ATU_BASE_WD-ATU_UPR_LMT_WD_MDFD] : 1'b1;
      end else begin                          // Max region size = 4GB.
         s_atu_upper_match = ADDR64 ? addr[SLAVE_BUS_ADDR_WIDTH-32 +: ATU_BASE_WD] ==
                                    atu_reg_out_upr_base[ATU_BASE_WD*i +: ATU_BASE_WD]
                                    : 1'b1;
      end

      // Compare address to base and limit to find out if we are in the
      // range. Invert bit changes the check to outside the range.
      // Do not match if type is completion
      if (atu_reg_out_incr_rgn_size[i] && ADDR64) begin     // Increased max region size
         s_atu_match = !atu_bypass && atu_reg_out_en[i] && atu_reg_out_invert[i] ^
             (s_atu_upper_match && addr[31+ATU_UPR_LMT_WD -: ATU_REG_WD+ATU_UPR_LMT_WD] >=
             {atu_reg_out_upr_base[ATU_BASE_WD*i +: ATU_UPR_LMT_WD], atu_reg_out_base[ATU_REG_WD*i +: ATU_REG_WD]} &&
             addr[31+ATU_UPR_LMT_WD -: ATU_REG_WD+ATU_UPR_LMT_WD] <=
             {atu_reg_out_uppr_limit[ATU_UPR_LMT_WD*i +: ATU_UPR_LMT_WD], atu_reg_out_limit[ATU_REG_WD*i +: ATU_REG_WD]}); 
      end else begin                          // 4 GB max region size
         s_atu_match = !atu_bypass &&
                     atu_reg_out_en[i] &&
                     atu_reg_out_invert[i] ^
                     (s_atu_upper_match && addr[31 -: ATU_REG_WD] >= 
                                         atu_reg_out_base[ATU_REG_WD*i +: ATU_REG_WD] &&
                     addr[31 -: ATU_REG_WD] <=
                     atu_reg_out_limit[ATU_REG_WD*i +: ATU_REG_WD]);
      end

      // Perform translation
      if (s_atu_match) begin
        s_satu_type[4:0]     = atu_reg_out_type[5*i +: 5];
        s_satu_snp           = atu_reg_out_snp[i];
        // If writing to a MRdLk region to do not translate
        // the type, pass thru as a MWr.
        // Note: memory write lock TLP type is not valid type.
        if (atu_write && atu_reg_out_type[5*i +: 5] == 5'b00001) begin
          s_satu_type[0] = 1'b0;
        end
        // Set the function number for the lowest matching region
        if (!atu_reg_out_func_bypass[i]) begin
          s_satu_func_num = atu_reg_out_func_num[NFUNC_WD*i +: NFUNC_WD];
        end else begin
          s_satu_func_num = func_num;
        end
      end
    end
  end

  // -------------------------------------------------------------------------------------
  // Assign outputs
  // -------------------------------------------------------------------------------------
  assign satu_type     = s_satu_type;
  assign satu_func_num = s_satu_func_num;
  assign satu_snp      = s_satu_snp;

endmodule
