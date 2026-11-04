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
// ---   $DateTime: 2024/01/10 14:23:51 $
// ---   $Revision: #1 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/common/DWC_pcie_arb_wrr.sv#1 $
// -------------------------------------------------------------------------
// --- Module Description: wrapper for weighted round robin arbitration
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module DWC_pcie_arb_wrr
#( parameter TP           = `TP,
   parameter NUM_CLIENTS  = 2,     
   parameter P_WIDTH      = 4
) (
    input                         core_clk,           // Core clock
    input                         core_rst_n,         // Core reset
    input  [P_WIDTH - 1 : 0]      cfg_io_arb_weight,  // CXL.io Weighted Round Robin Arbitration Weight
    input  [P_WIDTH - 1 : 0]      cfg_mc_arb_weight,  // CXL.cache and CXL.mem Weighted Round Robin Arbitration Weight
    input                         arb_enable,         // Enable arbitration
    input  [NUM_CLIENTS - 1 : 0]  arb_req,            // Arbitration Request
    output [NUM_CLIENTS - 1 : 0]  arb_gnt             // Arbitration Grant
);

logic [(NUM_CLIENTS * P_WIDTH) - 1 : 0]   cfg_weight_s;
logic [NUM_CLIENTS - 1 : 0]               wt2pri_s;   // weight converted to priority


assign cfg_weight_s = {cfg_mc_arb_weight, cfg_io_arb_weight};

// Weight to priority converter 
DWC_pcie_arb_wrr_priority
 #(
    .N               ( NUM_CLIENTS         ),
    .WT_WIDTH        ( P_WIDTH             )
) u_wt2pri (
    .core_clk        ( core_clk            ),
    .core_rst_n      ( core_rst_n          ),
    .enable          ( arb_enable          ),
    .cfg_weight      ( cfg_weight_s        ),
    .gnt_in          ( arb_gnt             ),
    .pri_out         ( wt2pri_s            )
);
  
// Instantiate arbiter
DWC_pcie_arb_wrr_arbitration
 #(
    .NUM_CLIENTS     ( NUM_CLIENTS         ),
    .P_WIDTH         ( P_WIDTH             )
) u_arbiter (
    .core_clk        ( core_clk            ),
    .core_rst_n      ( core_rst_n          ),
    .enable          ( arb_enable          ),
    .prior           ( wt2pri_s            ),
    .req_in          ( arb_req             ),
    .grant           ( arb_gnt             )
);


endmodule
