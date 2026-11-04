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
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/rplh_crc_check.sv#2 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Recalculate the CRC over the data and check against the receveid value
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"

module rplh_crc_check
  import cx_pl_pkg::P_FLIT_WD;
  import cx_pl_pkg::P_COEF0;
#(
  parameter   TP  = `TP,
  parameter   [(P_FLIT_WD * 8) - 1 : 0] P_COEF = P_COEF0, 
  parameter   P_DIN_WD = P_FLIT_WD - (14*8),  // Flit width less the FEC and CRC
  parameter   P_DIN_BYTES = P_DIN_WD / 8      // CRC Data in Bytes
) (
  // Inputs
  input [P_DIN_WD - 1 : 0]  data_in,    // Data
  input [7 : 0]             crc_in,     // Received CRC
  // Outputs
  output logic              crc_error   // CRC Error
);

logic [7 : 0] s_per_byte_calc [P_DIN_BYTES - 1 : 0];
logic [7 : 0] s_per_byte_tree [P_DIN_BYTES - 1 : 0];
logic [7 : 0] s_crc_out;
genvar j;

logic [7:0] coef[7:0];

// CRC Calculation
always_comb begin : crc_PROC
  for(int i = 0; i < P_DIN_BYTES; i = i + 1) begin
    // Index the coefficient lookup table
    coef[0] = P_COEF[(64 * i) +: 8]; 
    coef[1] = P_COEF[(64 * i) + 8 +: 8]; 
    coef[2] = P_COEF[(64 * i) + 16 +: 8]; 
    coef[3] = P_COEF[(64 * i) + 24 +: 8]; 
    coef[4] = P_COEF[(64 * i) + 32 +: 8]; 
    coef[5] = P_COEF[(64 * i) + 40 +: 8]; 
    coef[6] = P_COEF[(64 * i) + 48 +: 8]; 
    coef[7] = P_COEF[(64 * i) + 56 +: 8]; 
    // CRC calculation per byte of the data
    s_per_byte_calc[i] =  (({8{data_in[8 * i]}}       & coef[0]) ^
                          ({8{data_in[(8 * i) + 1]}}  & coef[1]) ^
                          ({8{data_in[(8 * i) + 2]}}  & coef[2]) ^
                          ({8{data_in[(8 * i) + 3]}}  & coef[3]) ^
                          ({8{data_in[(8 * i) + 4]}}  & coef[4]) ^
                          ({8{data_in[(8 * i) + 5]}}  & coef[5]) ^
                          ({8{data_in[(8 * i) + 6]}}  & coef[6]) ^
                          ({8{data_in[(8 * i) + 7]}}  & coef[7]));
  end
end : crc_PROC

// Add the per byte symbols to generate the CRC check byte
generate
  for(j = 0 ; j < P_DIN_BYTES; j = j + 1)
  begin : gen_xor_tree
    if(j < 2) begin
      assign s_per_byte_tree[j] = s_per_byte_calc[0] ^ s_per_byte_calc[1];
    end else begin
      assign s_per_byte_tree[j] = s_per_byte_tree[j - 1] ^ s_per_byte_calc[j];
    end
  end
endgenerate

assign s_crc_out = s_per_byte_tree[P_DIN_BYTES - 1];

assign crc_error = !(s_crc_out == crc_in);

endmodule
