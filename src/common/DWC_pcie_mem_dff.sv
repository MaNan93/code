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
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DWC_pcie_mem_dff.sv#5 $
// -------------------------------------------------------------------------
// Module Description: Dual port (1 write port, 1 read port) DFF based memory.
//
// Parameters                        Valid Values
// WIDTH                             [ 1 to 256 ]
// DEPTH                             [ 2 to 256 ]
// ADDR_WIDTH                        [ 1 to 8 ]
//
// ADDR_WIDTH parameter should be set (by the parent design) to ceil( log2( DEPTH ) )
// ---------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_mem_dff
 #(
  // -------------------------------------------------------------------------------------
  // Parameters modified by an instantiation parameter assignment
  // -------------------------------------------------------------------------------------
  parameter WIDTH                            = 4,
  parameter DEPTH                            = 8,
  parameter ADDR_WIDTH                       = 3,
  // -------------------------------------------------------------------------------------
  // Parameters not modified by an instantiation parameter assignment
  // -------------------------------------------------------------------------------------
  parameter TP                               = `TP
 )
 (
 // -------------------------------------------------------------------------------------
 // Clocks and resets
 // -------------------------------------------------------------------------------------
 // clk                              Positive-edge Clock
 // rst_n                            Active Low asynchronous Reset
 input                                               clk,
 input                                               rst_n,
 // -------------------------------------------------------------------------------------
 // Memory interface
 // -------------------------------------------------------------------------------------
 // wr_n                             Active Low Write Control
 // wr_addr                          Write Address
 // wr_data                          Input Data (for writes)
 // rd_n                             Active Low Read Control
 // rd_addr                          Read Address
 // rd_data                          Output Data (from reads)
 input                        wr_n,
 input       [ADDR_WIDTH-1:0] wr_addr,
 input       [WIDTH-1:0]      wr_data,
 input                        rd_n,
 input       [ADDR_WIDTH-1:0] rd_addr,
 output wire [WIDTH-1:0]      rd_data
 );
// -------------------------------------------------------------------------------------
// Local parameters
// -------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------
// Internal wires/regs
// -------------------------------------------------------------------------------------
  reg [DEPTH-1:0][WIDTH-1:0] mem_ary;

// -------------------------------------------------------------------------------------
// Internal design
// -------------------------------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin : proc_seq_mem_array
    integer i;
    if (!rst_n) begin
      for (i=0; i<DEPTH; i=i+1) begin
         mem_ary[i] <= # TP {WIDTH{1'b0}};
      end
    end else begin
      if (!wr_n) begin
        mem_ary[wr_addr] <= # TP wr_data;
      end
    end
  end

  DWC_pcie_ctl_cdc_mux
  
   #(
     .WIDTH      ( WIDTH      ),
     .DEPTH      ( DEPTH      ),
     .ADDR_WIDTH ( ADDR_WIDTH )
    )  u_mux (
     .mem_ary ( mem_ary ),
     .rd_addr ( rd_addr ),
     .rd_n    ( rd_n    ),
     .rd_data ( rd_data )
  );

endmodule
