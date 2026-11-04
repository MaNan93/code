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
// --- RCS information:
// ---  $DateTime: 2023/12/22 07:15:34 $
// ---  $Revision: #2 $
// ---  $Id: //dwh/pcie_iip/main/fairbanks/design/Spif/spif_protocol_dec.sv#2 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// SPIF Protocol Decoder
//
// This module samples and decodes pl_protocol and pl_protocol_fmt
// to be used on the given hierarchy level
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Spif/pkg/spif_pkg.svh"

module spif_protocol_dec
  import spif_pkg::*;                                          // Import SPIF package
#(
  parameter  TP            = `TP
) 
                          (
  // Inputs
  input                                core_clk,
  input                                core_rst_n,
  input                                pl_protocol_vld,        // Physical Layer Protocol Valid
  input  protocol_type_e               pl_protocol,            // Physical Layer Protocol Type
  input  protocol_fmt_e                pl_protocol_fmt,        // Physical Layer Protocol Flit Format
  // Outputs
  output protocol_cfg_t                pl_protocol_cfg         // Protocol Configuration Structure
);

protocol_cfg_t  pl_protocol_cfg_nxt;

always_comb begin
    // Initialize structure
    pl_protocol_cfg_nxt                    = '{default: '0};

    // Decode negotiated protocol and flit format
    pl_protocol_cfg_nxt.pcie_mode_enable   = (pl_protocol     inside {PCIE_MODE});
    pl_protocol_cfg_nxt.cxl_mode_enable    = (pl_protocol     inside {CXL_MODE1, CXL_MODE2, CXL_MODE3, CXL_MODE4, CXL_MODE5});
    pl_protocol_cfg_nxt.cxl_mem_enable     = (pl_protocol     inside {CXL_MODE3, CXL_MODE4, CXL_MODE5});
    pl_protocol_cfg_nxt.cxl_cache_enable   = (pl_protocol     inside {CXL_MODE2, CXL_MODE3});
    pl_protocol_cfg_nxt.pcie_nfm_mode      = (pl_protocol_fmt inside {FMT_NONE_FLIT});
    pl_protocol_cfg_nxt.pcie_flit_mode     = (pl_protocol_fmt inside {FMT_PCIE_FLIT, FMT_CXL_256B, FMT_CXL_LOPT, FMT_CXL_PBR});
    pl_protocol_cfg_nxt.cxl_vh_enable      = (pl_protocol_fmt inside {FMT_CXL_68BVH});
    pl_protocol_cfg_nxt.cxl_pcie_flit_mode = (pl_protocol_fmt inside {FMT_CXL_256B, FMT_CXL_LOPT, FMT_CXL_PBR});
    pl_protocol_cfg_nxt.spif_enable        = 1'b0        || pl_protocol_cfg_nxt.cxl_mode_enable
  || pl_protocol_cfg_nxt.pcie_flit_mode
   || pl_protocol_cfg_nxt.pcie_mode_enable ;
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        pl_protocol_cfg <= #TP '{default: '0};
    end else if (pl_protocol_vld) begin
        pl_protocol_cfg <= #TP pl_protocol_cfg_nxt;
    end
end
// -------------------------------------------------------------------------------------

endmodule
