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
// ---    $DateTime: 2024/01/27 12:39:15 $
// ---    $Revision: #2 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DWC_pcie_ctl_sync_reset.sv#2 $
// -------------------------------------------------------------------------
// Description: reset synchronizer with output test mux
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module DWC_pcie_ctl_sync_reset #(
  parameter SYNC_DEPTH   = `CX_PCIE_SYNC_DEPTH // number of registers in the synchronizer
) ( 
    input  clk,
    input  rst_n, // asynchronous reset input, active low
    input  test_mode, // test mode, active high

    output sync_rst_n // synchronized reset output, active low
);

localparam DATA_DELAY_BCM36_NHS = 3;  // Type of random delay to be added to signal in simulation by bcm36_nhs

logic qst_test_mode;

// Synchronize reset signal in the AMBA Domain
DWC_pcie_ctl_bcm40
 #(
  .F_SYNC_TYPE (SYNC_DEPTH)
) u_sync(
  .clk_d       (clk          ),
  .rst_s_n     (rst_n        ),
  .test        (qst_test_mode),
  .test_rst_n  (rst_n        ),
  .rst_d_n     (sync_rst_n    )
);

// For Synthesis, consider test_mode signal as false path in the Destination Domain
DWC_pcie_ctl_bcm36_nhs
 #(
  .WIDTH      (1'b1                ),
  .DATA_DELAY (DATA_DELAY_BCM36_NHS)
) u_bcm36_nhs_test_mode(
`ifndef SYNTHESIS
  .clk_d      (clk                 ),
  .rst_d_n    (sync_rst_n          ),
`endif // SYNTHESIS
  .data_s     (test_mode           ),
  .data_d     (qst_test_mode       )
);


endmodule // DWC_pcie_ctl_sync_reset
