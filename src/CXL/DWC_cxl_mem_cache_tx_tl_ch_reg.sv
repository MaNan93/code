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

// -------------------------------------------------------------------------------------
// --- RCS information:
// ---   $DateTime: 2024/01/19 09:25:58 $
// ---   $Revision: #1 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_tx_tl_ch_reg.sv#1 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// CXL Transaction Layer Message Channel Pipeline Register
// 
// Parameters:
// ===========
//  CXL_CHMSG_DATA: This is to differentiate between data channels and message channels
//    - when set to 1, 
//        - the input port "cxl_tl_chmsg_vld_i" is used to validate the input data "cxl_tl_chmsg_i"
//        - the output port "cxl_ll_chmsg_vld_o" indicates valid output data "cxl_ll_chmsg_o"
//    - when set to 0,
//        - the valid bit (index 0) of each message is used to indicate valid message
//        - the input port "cxl_tl_chmsg_vld_i" is ignored and can be tied to any value
//        - the output port "cxl_ll_chmsg_vld_o" is not driven
//
//  CXL_CHMSG_VLD_NUM: This is to define the number of valid data channels, such that:
//    - only the first CXL_CHMSG_VLD_NUM data entries can be fetched at maximum per clock cycle
//    - the first CXL_CHMSG_NUM entries of Transaction Layer data buffer can be peeked at
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module DWC_cxl_mem_cache_tx_tl_ch_reg #(
    parameter TP = `TP,
    parameter CXL_CHMSG_DATA      = 0,
    parameter CXL_CHMSG_REG       = 0,
    parameter CXL_CHMSG_NUM       = 4,
    parameter CXL_CHMSG_VLD_NUM   = CXL_CHMSG_NUM,
    parameter CXL_CHMSG_WIDTH     = 79
) (
    // Clock and Reset
    input                                            core_clk,                            // Core clock
    input                                            core_rst_n,                          // Core active low asynchronous reset
    input  [CXL_CHMSG_NUM-1:0][CXL_CHMSG_WIDTH-1:0]  cxl_tl_chmsg_i,                      // Channel Interface Input Data
    input  [CXL_CHMSG_VLD_NUM-1:0]                   cxl_tl_chmsg_vld_i,                  // Channel Interface Input Valid
    input  [CXL_CHMSG_VLD_NUM-1:0]                   cxl_ll_chmsg_halt_i,                 // Link Layer Channel Interface Halts

    output logic [CXL_CHMSG_WIDTH-1:0]               cxl_ll_chmsg_o [0:CXL_CHMSG_NUM-1],  // Link Layer Channel Interface Data
    output logic [CXL_CHMSG_VLD_NUM-1:0]             cxl_ll_chmsg_vld_o,                  // Link Layer Channel Interface valid
    output logic [CXL_CHMSG_VLD_NUM-1:0]             cxl_tl_chmsg_halt_o                  // Channel Interface Halts
);

// Parameters
localparam CXL_CHMSG_VLD      = 0;
localparam CXL_CHMSG_NUM_LOG2 = $clog2(CXL_CHMSG_NUM);

// Declarations
logic [CXL_CHMSG_NUM-1:0][CXL_CHMSG_WIDTH-1:0]   cxl_ll_chmsg_r, cxl_ll_chmsg_nxt; // Link Layer Channel Output Register
logic [CXL_CHMSG_NUM-1:0]                        cxl_tl_chmsg_vld_s;               // Channel Interface Halts
logic [CXL_CHMSG_NUM_LOG2:0]                     cxl_ll_chmsg_halt_num_s;          // Number of channels halted at Link Layer 
logic [CXL_CHMSG_NUM-1:0]                        cxl_ll_chmsg_vld_r;               // Link Layer Channel Output Register
logic [CXL_CHMSG_NUM-1:0]                        cxl_ll_chmsg_vld_nxt;             // Link Layer Channel Output Register
logic [CXL_CHMSG_NUM-1:0][CXL_CHMSG_WIDTH-1:0]   cxl_ll_chmsg_r_shifted;           // Output Register shifted by number of fetched slots
logic [CXL_CHMSG_NUM-1:0][CXL_CHMSG_WIDTH-1:0]   cxl_tl_chmsg_i_shifted;           // Input Channel Interface shifted by number of busy slots
logic [CXL_CHMSG_NUM-1:0]                        cxl_tl_chmsg_vld_int;             // Channel Interface Halts
logic [CXL_CHMSG_NUM-1:0]                        cxl_ll_chmsg_halt_int;            // Channel Interface Halts
logic [CXL_CHMSG_NUM-1:0]                        cxl_tl_chmsg_halt_int;            // Channel Interface Halts
logic [CXL_CHMSG_NUM_LOG2:0]                     cxl_ll_chmsg_free_slot_s;         // Number of free slots in chmsg_r

// Zero/One padding to align valid/halt width with the shift register width
assign cxl_tl_chmsg_vld_int  = {{(CXL_CHMSG_NUM-CXL_CHMSG_VLD_NUM){1'b0}},cxl_tl_chmsg_vld_i};
assign cxl_ll_chmsg_halt_int = {{(CXL_CHMSG_NUM-CXL_CHMSG_VLD_NUM){1'b1}},cxl_ll_chmsg_halt_i};

always_comb begin
  // Data Output
  for (int i = 0; i < CXL_CHMSG_NUM; i++) begin
    cxl_ll_chmsg_o[i] = CXL_CHMSG_REG ? cxl_ll_chmsg_r[i] : cxl_tl_chmsg_i[i];
  end

  // Valid and Halt Output (Truncate MSBs to align datawidth)
  for (int i = 0; i < CXL_CHMSG_VLD_NUM; i++) begin
    cxl_ll_chmsg_vld_o[i] = CXL_CHMSG_REG ? cxl_ll_chmsg_vld_r[i] : cxl_tl_chmsg_vld_int[i];
    cxl_tl_chmsg_halt_o[i] = cxl_tl_chmsg_halt_int[i];
  end
end

// If CXL_CHMSG_DATA = 1, use the valid input port. Otherwise, use the valid bit of the CXL message
always_comb begin
    for (int i = 0; i < CXL_CHMSG_NUM; i++) begin
        cxl_tl_chmsg_vld_s[i] = (CXL_CHMSG_DATA) ? cxl_ll_chmsg_vld_r[i] : cxl_ll_chmsg_r[i][CXL_CHMSG_VLD];
    end
end

always_comb begin
    // Count the number of slots that are fetched by Link Layer (valid message/data with halt de-asserted)
    cxl_ll_chmsg_free_slot_s = cntMsgHalt(~cxl_ll_chmsg_halt_int & cxl_tl_chmsg_vld_s);
    // Count the number of busy slots (remaining valid messages/data that aren't fetched by Link Layer)
    cxl_ll_chmsg_halt_num_s  = cntMsgHalt(cxl_ll_chmsg_halt_int & cxl_tl_chmsg_vld_s);

    // Shift by the amount of slots that are fetched by link layer
    cxl_ll_chmsg_r_shifted = (cxl_ll_chmsg_r >> (cxl_ll_chmsg_free_slot_s  * CXL_CHMSG_WIDTH));
    // Shift Inputs by the amount of busy slots to fetch messages/data in the available slots
    cxl_tl_chmsg_i_shifted = (cxl_tl_chmsg_i << (cxl_ll_chmsg_halt_num_s * CXL_CHMSG_WIDTH));

    // Update the shift register (for data and valid) to: 
    // 1. Shift by the amount of fetched slots
    // 2. Load new TL messages/data in the remaining available slots
    for (int i=0; i < CXL_CHMSG_NUM; i++) begin
      if (i < cxl_ll_chmsg_halt_num_s) begin
        cxl_ll_chmsg_nxt[i] = cxl_ll_chmsg_r_shifted[i];
      end else begin
        cxl_ll_chmsg_nxt[i] = cxl_tl_chmsg_i_shifted[i];
      end
    end
    
    cxl_ll_chmsg_vld_nxt = (cxl_ll_chmsg_vld_r >> (cxl_ll_chmsg_free_slot_s)) |
                           (cxl_tl_chmsg_vld_int << (cxl_ll_chmsg_halt_num_s));

    // Generate halt vector to TL, such that the number of halts corresponds to the number of busy slots
    cxl_tl_chmsg_halt_int = CXL_CHMSG_REG ? ({CXL_CHMSG_NUM{1'b1}} << (CXL_CHMSG_NUM - cxl_ll_chmsg_halt_num_s)) : cxl_ll_chmsg_halt_int;
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        cxl_ll_chmsg_r      <= #TP '0;
        cxl_ll_chmsg_vld_r  <= #TP '0;
    end
    else begin
        cxl_ll_chmsg_r      <= #TP cxl_ll_chmsg_nxt;
        cxl_ll_chmsg_vld_r  <= #TP cxl_ll_chmsg_vld_nxt;
    end
end
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
function automatic [CXL_CHMSG_NUM_LOG2:0] cntMsgHalt;
    input   [CXL_CHMSG_NUM-1:0] halt;
    reg     [CXL_CHMSG_NUM_LOG2:0]  result;

    integer i;
begin
    result = '0;

    for (i = 0; i < CXL_CHMSG_NUM; i++)
        if (halt[i]) result = result + 1;

    cntMsgHalt = result;
end
endfunction
// -------------------------------------------------------------------------------------

endmodule : DWC_cxl_mem_cache_tx_tl_ch_reg
