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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Amba/DWC_pcie_amba_pdly.sv#3 $
// -------------------------------------------------------------------------
// Module Description:
//
// ---------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_amba_pdly
 #(
  // -------------------------------------------------------------------------------------
  // Parameters modified by an instantiation parameter assignment
  // -------------------------------------------------------------------------------------
  parameter INTERFACE_DW                       = 32,
  // -------------------------------------------------------------------------------------
  // Parameters not modified by an instantiation parameter assignment
  // -------------------------------------------------------------------------------------
  parameter TP                                 = `TP
 )
 (
  // -------------------------------------------------------------------------------------
  // Clocks and resets
  // -------------------------------------------------------------------------------------
  input                                              clk,
  input                                              rst_n,
  // -------------------------------------------------------------------------------------
  // Input Interface
  // -------------------------------------------------------------------------------------
  input       [INTERFACE_DW-1:0]                     interface_bus,
  output wire                                        pdly_halt,
  // -------------------------------------------------------------------------------------
  // Output Interface
  // -------------------------------------------------------------------------------------
  input                                              interface_bus_valid,
  output wire [INTERFACE_DW-1:0]                     pdly_interface_bus,
  input                                              halt
 );
  // -------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------
  // -------------------------------------------------------------------------------------
  // Internal wires/regs
  // -------------------------------------------------------------------------------------
  wire                                               s_halt;
  reg                                                r_halt;
  wire                                               s_halt_redge;
  wire                                               s_halt_fedge;
  reg  [INTERFACE_DW-1:0]                            r_interface_bus;
  reg  [INTERFACE_DW-1:0]                            rr_interface_bus;

  // -------------------------------------------------------------------------------------
  // Internal design
  // -------------------------------------------------------------------------------------
  // Qualify the halt signal with the delayed interface bus data valid signal.
  // Allows the input interface bus to fill the single stage pipeline.
  assign s_halt = halt & interface_bus_valid;

  // Delay halt by one cycle
  always @(posedge clk or negedge rst_n) begin : proc_seq_halt
    if (!rst_n) begin
      r_halt <= # TP 1'b0;
    end else begin
      r_halt <= # TP s_halt;
    end
  end

  // Detect halt rising and falling edges
  assign s_halt_redge = s_halt && !r_halt;
  assign s_halt_fedge = !s_halt && r_halt;

  // Register the input interface bus on halt rising edge
  always @(posedge clk or negedge rst_n) begin : proc_seq_r_interface_bus
    if (!rst_n) begin
      r_interface_bus <= # TP {INTERFACE_DW{1'b0}};
    end else if (s_halt_redge) begin
      r_interface_bus <= # TP interface_bus;
    end
  end

  // Mux input interface bus beats to output interface bus depending on the
  // assertion and de-asertion of the halt signal.
  always @(posedge clk or negedge rst_n) begin : proc_seq_rr_interface_bus
    if (!rst_n) begin
      rr_interface_bus <= # TP {INTERFACE_DW{1'b0}};
    end else if (s_halt_fedge) begin
    // Input halt signal de-asserted, output stored interface bus beat on the next cycle
      rr_interface_bus <= # TP r_interface_bus;
    end else if (!s_halt && !r_halt) begin
    // Register thru interface data when halt signals de-asserted otherwise hold data
      rr_interface_bus <= # TP interface_bus;
    end
  end

  // -------------------------------------------------------------------------------------
  // Assign outputs
  // -------------------------------------------------------------------------------------
  assign pdly_halt = r_halt;
  assign pdly_interface_bus = rr_interface_bus;

endmodule
