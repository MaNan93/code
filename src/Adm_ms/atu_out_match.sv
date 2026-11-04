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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/atu_out_match.sv#3 $
// -------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
`include "DWC_pcie_ctl_pkg.svh"
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Adm_ms/xaim_ms_pkg.svh"
module atu_out_match
import DWC_pcie_core_pkg::*;
import DWC_pcie_ctl_pkg::*;

                    (
    input  logic                 clk,
    input  logic                 rst_n,
    input  cdm_atu_out_cfg_t     cdm_atu_out_cfg,
    input                        dma,
    input                        atu_bypass,
    input  [63:0]                addr,
    output atu_pkt_t             atu_pkt
);

generate if(ATU_OUT_NREGIONS==0)begin : g_0_regions
    assign atu_pkt = '0;
end else begin : g_regions
    
    logic [ATU_OUT_NREGIONS_MIN1-1:0] upper_match;
    
    
    always_comb begin
        atu_pkt = '0;
        for(int i = 0; i < ATU_OUT_NREGIONS_MIN1; i++)begin
            
            if(cdm_atu_out_cfg.incr_rgn_size[i])
                upper_match[i] = (ATU_UPR_LMT_WD==32) ? 1'b1 : addr[32+ATU_UPR_LMT_WD_MDFD +: 32-ATU_UPR_LMT_WD_MDFD] == cdm_atu_out_cfg.upr_base[i][ATU_UPR_LMT_WD_MDFD+:32-ATU_UPR_LMT_WD_MDFD];
            else
                upper_match[i] = addr[32+:32] == cdm_atu_out_cfg.upr_base[i];
            
            atu_pkt.match[i] = !atu_bypass && cdm_atu_out_cfg.en[i] && cdm_atu_out_cfg.invert[i] ^
                    (upper_match[i] && (
                    cdm_atu_out_cfg.incr_rgn_size[i] ? (
                        addr[31+ATU_UPR_LMT_WD-:ATU_REG_WD+ATU_UPR_LMT_WD] >= {cdm_atu_out_cfg.upr_base[i][0+:ATU_UPR_LMT_WD], cdm_atu_out_cfg.base[i]} &&
                        addr[31+ATU_UPR_LMT_WD-:ATU_REG_WD+ATU_UPR_LMT_WD] <= {cdm_atu_out_cfg.uppr_limit[i], cdm_atu_out_cfg.limit[i]}
                    ) :
                    (
                        addr[31-:ATU_REG_WD] >= {cdm_atu_out_cfg.base[i]} &&
                        addr[31-:ATU_REG_WD] <= {cdm_atu_out_cfg.limit[i]}
                    ))
                    )
                    && !(cdm_atu_out_cfg.dma_bypass[i] && dma)
                    ;
            if(cdm_atu_out_cfg.incr_rgn_size[i])
                atu_pkt.offset[i][31+ATU_UPR_LMT_WD-:ATU_REG_WD+ATU_UPR_LMT_WD] = (ATU_REG_WD+ATU_UPR_LMT_WD)'(addr[31+ATU_UPR_LMT_WD-:ATU_REG_WD+ATU_UPR_LMT_WD] - {cdm_atu_out_cfg.upr_base[i][0+:ATU_UPR_LMT_WD], cdm_atu_out_cfg.base[i]});
            else
                atu_pkt.offset[i][31-:ATU_REG_WD] = (ATU_REG_WD)'(addr[31-:ATU_REG_WD] - cdm_atu_out_cfg.base[i]);
            
            atu_pkt.offset[i][0 +: 32-ATU_REG_WD] = addr[0 +: 32-ATU_REG_WD];
            
            atu_pkt.offset_plus_lwr_trgt_for_incr_rgn_size[i] =  (ATU_REG_WD+ATU_UPR_LMT_WD)'({cdm_atu_out_cfg.upr_trgt[i][0+:ATU_UPR_LMT_WD], cdm_atu_out_cfg.lwr_trgt[i][0+:ATU_REG_WD]} + 
                                                                       {atu_pkt.offset[i][32+:ATU_UPR_LMT_WD], atu_pkt.offset[i][31-:ATU_REG_WD]});
            
            atu_pkt.offset_plus_lwr_trgt[i] = (ATU_REG_WD)'(cdm_atu_out_cfg.lwr_trgt[i] + atu_pkt.offset[i][31-:ATU_REG_WD]);
        end
    end
    
end endgenerate

endmodule
