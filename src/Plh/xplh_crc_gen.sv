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
// ---   $Revision: #3 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_crc_gen.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Count DW presented on the data path and move the index into the CRC coefficient
// to the correct location for each DW. Calculate the CRC using the values from the
// Lookup Table of coefficients.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"

module xplh_crc_gen
  import cx_pl_pkg::P_FLIT_WD;
  import cx_pl_pkg::P_FLIT_DW_CNT_WD;
  import cx_pl_pkg::P_DW;
  import cx_pl_pkg::P_COEF0;
#(
  parameter   TP  = `TP,
  parameter   [(P_FLIT_WD * 8) - 1 : 0] P_COEF = P_COEF0
) (
  // Inputs
  input   [P_FLIT_DW_CNT_WD - 1 : 0]  dw_cnt,   // Data width counter
  input   [P_DW - 1 : 0]              data_in,  // Data
  // Outputs
  output  [7 : 0]                     crc_out   // CRC output
);

localparam  P_DW_BYTES  = P_DW / 8;

logic [7 : 0] s_per_byte_calc [P_DW_BYTES - 1 : 0];
logic [7 : 0] s_per_byte_tree [P_DW_BYTES - 1 : 0];
genvar j;

logic [7:0] int_coef_array [P_DW-1:0];

// Create the coefficient array
always_comb begin : coef_array_PROC
  for(int i = 0; i < P_DW; i = i + 1) begin
    if(dw_cnt == 1) begin
      int_coef_array[i] = P_COEF[(1*P_DW*8) + (8*i) +: 8];
    end else if(dw_cnt == 2) begin
      int_coef_array[i] = P_COEF[(2*P_DW*8) + (8*i) +: 8];
    end else if(dw_cnt == 3) begin
      int_coef_array[i] = P_COEF[(3*P_DW*8) + (8*i) +: 8];
    end else begin
      int_coef_array[i] = P_COEF[(8*i) +: 8];
    end
  end
end : coef_array_PROC

// CRC Calculation
always_comb begin : crc_PROC
  for(int i = 0; i < P_DW_BYTES; i = i + 1) begin
    // CRC calculation per byte of the data
    s_per_byte_calc[i] =  (({8{data_in[8 * i]}}       & int_coef_array[0+(i*8)]) ^
                          ({8{data_in[(8 * i) + 1]}}  & int_coef_array[1+(i*8)]) ^
                          ({8{data_in[(8 * i) + 2]}}  & int_coef_array[2+(i*8)]) ^
                          ({8{data_in[(8 * i) + 3]}}  & int_coef_array[3+(i*8)]) ^
                          ({8{data_in[(8 * i) + 4]}}  & int_coef_array[4+(i*8)]) ^
                          ({8{data_in[(8 * i) + 5]}}  & int_coef_array[5+(i*8)]) ^
                          ({8{data_in[(8 * i) + 6]}}  & int_coef_array[6+(i*8)]) ^
                          ({8{data_in[(8 * i) + 7]}}  & int_coef_array[7+(i*8)]));
  end
end : crc_PROC

// Add the per byte symbols to generate the CRC check byte
generate
  for(j = 0 ; j < P_DW_BYTES; j = j + 1)
  begin : gen_xor_tree
    if(j < 2) begin
      assign s_per_byte_tree[j] = s_per_byte_calc[0] ^ s_per_byte_calc[1];
    end else begin
      assign s_per_byte_tree[j] = s_per_byte_tree[j - 1] ^ s_per_byte_calc[j];
    end
  end
endgenerate

assign crc_out = s_per_byte_tree[P_DW_BYTES - 1];

endmodule
