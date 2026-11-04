
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

//
// Description : DWC_pcie_ctl_bcm03.v Verilog module for DWC_pcie_ctl
//
// DesignWare IP ID: 78e22443
//
////////////////////////////////////////////////////////////////////////////////


module DWC_pcie_ctl_bcm03 (
    enable,
    data_in,
    data_out
    );

// spyglass disable_block W146
// SMD: Explicit named association is recommended in instance references
// SJ: Current release uses ordered list for parameters, the design is checked and verified without errors

parameter integer WIDTH        = 1;  // RANGE 1 to 1024
parameter integer FORCE_VAL    = 0;  // RANGE 0 to 1
parameter integer EN_SENSE     = 1;  // RANGE 0 to 1


input                   enable;      // bus force input control
input  [WIDTH-1:0]      data_in;    // data input bus
output [WIDTH-1:0]      data_out;   // data output bus

wire [WIDTH-1:0] enable_int;

generate
  if (EN_SENSE == 0) begin : GEN_ES0
    assign enable_int = {WIDTH{enable}};
  end else begin : GEN_ES1
    assign enable_int = {WIDTH{~enable}};
  end
endgenerate

generate
  if (FORCE_VAL == 0) begin : GEN_FV0
    DWC_pcie_ctl_bcm00_and
     #(WIDTH) U_AND (.a(data_in), .b(enable_int), .z(data_out));
  end else begin : GEN_FV1
    DWC_pcie_ctl_bcm00_or
     #(WIDTH) U_OR (.a(data_in), .b(~enable_int), .z(data_out));
  end
endgenerate

// spyglass enable_block W146
endmodule
