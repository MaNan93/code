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
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/serdes_arch/serdes_pipe_rx_mux.sv#4 $
// --------------------------------------------------------------------------------------------
// --- Module Description: SerDes architecture receiver side multiplexer module
// --------------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer1/serdes_arch/serdes_pipe_pkg.svh"

module serdes_pipe_rx_mux

  import serdes_pipe_pkg::*;
#(
  parameter int  WIDTH = 1
) (
  // ------------- input -----------------
  input logic               sel,
  input logic [WIDTH-1:0]   sel_0,
  input logic [WIDTH-1:0]   sel_1,
  // ------------- output ----------------
  output logic [WIDTH-1:0]  z
);

  generate
    for(genvar i = 0; i < WIDTH; i++) begin: gen_mux
      assign z[i] = sel ? sel_1[i] : sel_0[i];
    end
  endgenerate

endmodule: serdes_pipe_rx_mux
