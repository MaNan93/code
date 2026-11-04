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


// --- Module Description:
// ----------------------------------------------------------------------------
// --- This module takes care of flipping the bits going to a checker for error
// injection. An outer loop takes care of single bit injection, while an inner
// loop takes care of double bit injection.
// ----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"

module bus_protect_chk_err_inj
#(
    parameter PROT_TYPE           = 0,
    parameter PROT_WD             = 16,
    parameter DATA_WD             = 128,
    parameter ERR_INJ_INDEX_WIDTH = 72
)   
(
    input  logic [ERR_INJ_INDEX_WIDTH-1:0] err_inj_bit_index_0_oh,
    input  logic [ERR_INJ_INDEX_WIDTH-1:0] err_inj_bit_index_1_oh,
    input  logic [PROT_WD-1:0]             chkin,  
    input  logic [DATA_WD-1:0]             datain, 
    output logic [PROT_WD-1:0]             chkout, 
    output logic [DATA_WD-1:0]             dataout
    `ifndef SYNTHESIS
    `ifdef SNPS_TB_INTERFACE
    ,
    input  logic                           error_inj_fault_en
    `endif // SNPS_TB_INTERFACE                       
    `endif // SYNTHESIS                               
);

logic [DATA_WD+PROT_WD-1:0] vector_to_corrupt, corrupted_vector;
assign vector_to_corrupt = {chkin, datain};

// bit flip
always_comb begin
    for (int bit_index = 0; bit_index < (DATA_WD+PROT_WD); bit_index++) begin
        if (err_inj_bit_index_0_oh[bit_index] || err_inj_bit_index_1_oh[bit_index]) begin
            corrupted_vector[bit_index] = !vector_to_corrupt[bit_index];
        end else begin
            corrupted_vector[bit_index] =  vector_to_corrupt[bit_index];
        end
    end
end

`ifndef SYNTHESIS
`ifdef SNPS_TB_INTERFACE
assign dataout = error_inj_fault_en? datain : corrupted_vector[0+:DATA_WD];
assign chkout  = error_inj_fault_en? chkin  : corrupted_vector[DATA_WD+:PROT_WD];
`else // !SNPS_TB_INTERFACE
assign dataout = corrupted_vector[0+:DATA_WD];
assign chkout  = corrupted_vector[DATA_WD+:PROT_WD];
`endif // SNPS_TB_INTERFACE
`else // !  SYNTHESIS                     
assign dataout = corrupted_vector[0+:DATA_WD];
assign chkout  = corrupted_vector[DATA_WD+:PROT_WD];
`endif // SYNTHESIS                               

endmodule

// Revision: $Id: //dwh/pcie_iip/main/fairbanks/design/common/bus_protect_chk_err_inj.sv#3 $
