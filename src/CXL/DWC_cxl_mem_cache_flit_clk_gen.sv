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
// ---   $DateTime: 2023/12/22 07:15:34 $
// ---   $Revision: #3 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_flit_clk_gen.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Flit Clock Generator Based on the Relation between Datapath of the Phy and 
// Link Layer.
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Spif/pkg/spif_pkg.svh"

module DWC_cxl_mem_cache_flit_clk_gen
  import spif_pkg::state_enc_e;
  import spif_pkg::RESET;
  import spif_pkg::ACTIVE;
  import spif_pkg::SPIF_NBYTES;
#(
  parameter TP = `TP
)
                                       (
  // Inputs
  input                 core_clk           ,  // Core clock
  input                 core_rst_n         ,  // Core reset
  input                 cxl_mode_enable    ,  // CXL Mode Enable
  input                 cxl_pcie_flit_mode ,  // CXL 256B Flit Mode
  input  [2:0]          pl_speedmode       ,  // Physical Layer Speed Mode
  input  [5:0]          pl_linkmode        ,  // Physical Layer Link Mode
  input  [2:0]          pl_bw_ratio        ,  // Physical Layer and Link Layer Bandwidth Ratio
  input  state_enc_e    pl_state_sts       ,  // Physical Layer State Status
  input                 pl_phyinretrain    ,  // Physical Layer is in Retrain
  // Outputs                        
  output logic          flit_clk           ,  // Flit Clock
  output logic          link_layer_clk        // Link Layer Clock
);

// Local parameters
localparam SPIF_NFMBYTES = (SPIF_NBYTES > 64) ? 64 : SPIF_NBYTES;
localparam TIMER_WD      = $clog2(`CX_CXL_FLIT_CORE_WIDTH_RATIO + 1);
localparam REGOUT_EN     = 1;

// Internal declarations
logic                  link_rst;     // Link Layer clock generator reset
logic                  link_ena;     // Link Layer clock generator enable
logic                  timer_rst;    // Flit cycle counter reset
logic                  timer_ena;    // Flit cycle counter enable
logic  [TIMER_WD-1:0]  timer_trgt;   // Flit cycle counter target value

// Enable Link Layer clock generator when State Status is out of RESET
assign link_rst   = (pl_state_sts == RESET);
assign link_ena   = (pl_state_sts != RESET) && cxl_mode_enable;

// Enable Flit cycle counter only when in ACTIVE state, does not count time spent in recovery
assign timer_rst  = (pl_state_sts == RESET);
assign timer_ena  = (pl_state_sts == ACTIVE) && !pl_phyinretrain;
assign timer_trgt = cxl_pcie_flit_mode ? (256/SPIF_NBYTES) : (64/SPIF_NFMBYTES);


// -------------------------------------------------------------------------
// Link Layer Clock Generator instantiation
// -------------------------------------------------------------------------
DWC_pcie_link_clk_gen
 #(
    .TIMER_WD          ( TIMER_WD         ),
    .REGOUT_EN         ( REGOUT_EN        )
) u_link_clk_gen (
    .clk               ( core_clk         ),
    .rst_n             ( core_rst_n       ),
    .current_data_rate ( pl_speedmode     ),
    .current_cclk_rate ( pl_bw_ratio      ),
    .link_rst          ( link_rst         ),
    .link_ena          ( link_ena         ),
    .link_clk          ( link_layer_clk   ),
    .timer_rst         ( timer_rst        ),
    .timer_ena         ( timer_ena        ),
    .timer_trgt        ( timer_trgt       ),
    .timer_done        ( flit_clk         )
);
// -------------------------------------------------------------------------

endmodule
