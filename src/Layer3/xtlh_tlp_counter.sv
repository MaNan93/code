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
// ---    $DateTime: 2023/12/08 08:15:20 $
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/xtlh_tlp_counter.sv#7 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module counts TLP's starts received and decrements by TLP's ends transmitted 
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
module xtlh_tlp_counter #(
  parameter   P_NW_IN = 1,                          // The number of TLP starts at the input
  parameter   P_NW_OUT = 1,                         // The number of TLP ends at the output
  parameter   TP = `TP,
  parameter   P_OUTSTANDING_CNT_WD = 2, // Start Counter Width
  parameter   P_EOT_CNT_WD = $clog2(P_NW_OUT)   // End Counter Width
) 
                        (
  input                                 core_clk,
  input                                 core_rst_n,
  input                                 flush,
  input         [P_NW_IN - 1 : 0]       sot_in,               // TLP starts at the input interface
  input         [P_NW_OUT - 1 : 0]      eot_out,              // TLP ends at the output interface
  input         [P_NW_IN - 1 : 0]       halt_sot_in,          // The halt used to qualify the SOT                  
  input         [P_NW_OUT - 1 : 0]      halt_eot_out,         // The halt used to qualify the EOT
  output  logic [P_OUTSTANDING_CNT_WD - 1 : 0]  xtlh_tlp_counter_val  // TLP Counter Value
);

localparam  P_ONE = {{(P_OUTSTANDING_CNT_WD-1){1'b0}}, 1'b1};
localparam  P_ZERO = {{(P_OUTSTANDING_CNT_WD-1){1'b0}}, 1'b0};
localparam  P_E_ONE = {{P_EOT_CNT_WD{1'b0}}, 1'b1};
localparam  P_E_ZERO = {{P_EOT_CNT_WD{1'b0}}, 1'b0};

logic [P_OUTSTANDING_CNT_WD - 1 : 0]  int_sot_cnt [P_NW_IN - 1 : 0];
logic [P_OUTSTANDING_CNT_WD - 1 : 0]  int_eot_cnt [P_NW_OUT - 1 : 0];
logic [P_NW_IN - 1 : 0]   int_valid_sot_in;
logic [P_NW_OUT - 1 : 0]  int_valid_eot_out;

assign int_valid_sot_in = ~halt_sot_in & sot_in;
assign int_valid_eot_out = ~halt_eot_out & eot_out;

// Start of TLP Counter
generate
  if(P_NW_IN > 1) begin : g_sot_cnt
    always_comb begin : sot_cnt_PROC
      for(int i = 0; i < P_NW_IN; i = i + 1)
        int_sot_cnt[i] = '0;
      for(int i = 0; i < P_NW_IN; i = i + 1) begin
        if(i == 0)
          int_sot_cnt[i] = int_valid_sot_in[i] ? P_ONE : P_ZERO;
        else
          int_sot_cnt[i] = int_valid_sot_in[i] ? int_sot_cnt[i-1] + P_ONE : int_sot_cnt[i-1];
      end
    end : sot_cnt_PROC
  end else begin : g_sot_cnt
    assign int_sot_cnt[0] = int_valid_sot_in[0] ? P_ONE : P_ZERO;
  end
endgenerate

// End of TLP Counter
generate
  if(P_NW_OUT > 1) begin : g_eot_cnt
    always_comb begin : eot_cnt_PROC
      for(int i = 0; i < P_NW_OUT; i = i + 1)
        int_eot_cnt[i] = '0;
      for(int i = 0; i < P_NW_OUT; i = i + 1) begin
        if(i == 0)
          int_eot_cnt[i] = int_valid_eot_out[i] ? P_E_ONE: P_E_ZERO;
        else
          int_eot_cnt[i] = int_valid_eot_out[i] ? int_eot_cnt[i-1] + P_ONE : int_eot_cnt[i-1];
      end
    end : eot_cnt_PROC
  end else begin : g_eot_cnt
    assign int_eot_cnt[0] = int_valid_eot_out[0] ? P_ONE : P_ZERO;
  end
endgenerate

always_ff @(posedge core_clk or negedge core_rst_n) begin : tlp_cnt_PROC
  if(!core_rst_n)
    xtlh_tlp_counter_val  <= #TP '0;
  else
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: SOT must always be followed by EOT before another SOT therefor the counter must always decrement before another increment.
    xtlh_tlp_counter_val  <= #TP flush ? '0 : (xtlh_tlp_counter_val + int_sot_cnt[P_NW_IN-1] - int_eot_cnt[P_NW_OUT-1]);
// spyglass enable_block W164a
end : tlp_cnt_PROC


endmodule
