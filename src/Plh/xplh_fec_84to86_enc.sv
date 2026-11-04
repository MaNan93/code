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
// ---   $DateTime: 2023/09/27 02:27:25 $
// ---   $Revision: #2 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_fec_84to86_enc.sv#2 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// This module generates the FEC check and parity bytes for PCIe Gen6 Protocol
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"

module xplh_fec_84to86_enc
  import cx_pl_pkg::*;
#(
  parameter TP = `TP
) (
  // Inputs
  input   [7 : 0]         data_in [P_N_SYMBOLS - 1 : 0],
  // Outputs
  output  logic [7 : 0]   check_out,
  output  logic [7 : 0]   parity_out
);


// Declarations
logic [7 : 0]  s_per_byte [P_N_SYMBOLS - 1 : 0];
logic [7 : 0]  s_check_tree [P_N_SYMBOLS - 1 : 0];
logic [7 : 0]  s_parity_tree [P_N_SYMBOLS - 1 : 0];
genvar j;

// Generate the partial product and sum over each byte of data in 
always_comb begin : check_PROC
  for(int i = 0; i < P_N_SYMBOLS; i = i + 1) begin
    s_per_byte[i] = (({8{data_in[i][0]}}  & P_FEC[(8 * ((P_N_SYMBOLS)     - i)) +: 8]) ^
                    ({8{data_in[i][1]}}   & P_FEC[(8 * ((P_N_SYMBOLS + 1) - i)) +: 8]) ^
                    ({8{data_in[i][2]}}   & P_FEC[(8 * ((P_N_SYMBOLS + 2) - i)) +: 8]) ^
                    ({8{data_in[i][3]}}   & P_FEC[(8 * ((P_N_SYMBOLS + 3) - i)) +: 8]) ^
                    ({8{data_in[i][4]}}   & P_FEC[(8 * ((P_N_SYMBOLS + 4) - i)) +: 8]) ^
                    ({8{data_in[i][5]}}   & P_FEC[(8 * ((P_N_SYMBOLS + 5) - i)) +: 8]) ^
                    ({8{data_in[i][6]}}   & P_FEC[(8 * ((P_N_SYMBOLS + 6) - i)) +: 8]) ^
                    ({8{data_in[i][7]}}   & P_FEC[(8 * ((P_N_SYMBOLS + 7) - i)) +: 8]));
  end
end : check_PROC

// Add the per byte symbols to generate the FEC check byte
generate
  for(j = 0 ; j < P_N_SYMBOLS; j = j + 1)
  begin : gen_xor_tree
    if(j < 2) begin
      assign s_check_tree[j] = s_per_byte[0] ^ s_per_byte[1];
      assign s_parity_tree[j] = data_in[0] ^ data_in[1];
    end else begin
      assign s_check_tree[j] = s_check_tree[j - 1] ^ s_per_byte[j];
      assign s_parity_tree[j] = s_parity_tree[j - 1] ^ data_in[j];
    end
  end
endgenerate

assign check_out = s_check_tree[P_N_SYMBOLS - 1];
assign parity_out = s_parity_tree[P_N_SYMBOLS - 1];

endmodule
