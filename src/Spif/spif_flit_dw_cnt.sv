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
// ---   $DateTime: 2023/12/22 07:15:34 $
// ---   $Revision: #3 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Spif/spif_flit_dw_cnt.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Data Word counter to identify SOF/EOF cycles in the flit 
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module spif_flit_dw_cnt
#(
    parameter TP              = `TP
) 
                       (
    // Inputs
    input               core_clk,           // Core clock
    input               core_rst_n,         // Core reset
    input               pcie_flit_mode,     // CXL 256B Flit Mode
    input               rst_flit_alignment, // Reset flit alignment
    input               dw_cnt_ena,         // Flit valid cycle
    output logic        dw_cnt_idle,        // Flit first flit cycle
    output logic        dw_cnt_busy,        // Flit is in progress
    output logic        dw_cnt_last,        // Flit last payload cycle
    output logic        dw_cnt_done         // Flit last flit cycle
);

// Local parameters
localparam DW_RATIO              = `CX_FLIT_CORE_WIDTH_RATIO;
localparam DW_RATIO_LOG2         = $clog2(DW_RATIO);
localparam DW_68B_RATIO          = ((DW_RATIO_LOG2-2) <= 0) ? 1 : (DW_RATIO/4);

// Local declarations
logic  [DW_RATIO_LOG2-1:0]  dw_cnt; // DW Counter

// Set DW counter busy flag when counter is greater than 0
assign dw_cnt_busy = |dw_cnt;
// Set DW counter idle flag when counter is equal to 0
assign dw_cnt_idle = !dw_cnt_busy;
// Set DW counter last cycle flag when counter reaches all 1's
assign dw_cnt_done = pcie_flit_mode ? (&dw_cnt) : (dw_cnt == (DW_68B_RATIO-1));
// Set DW counter last payload cycle when PCIe flit is split across 128-bit boundary
// otherwise assert with the last cycle
assign dw_cnt_last = dw_cnt_done;

// DW Counter: increments when data is valid and CXL.io datapath is not halted on the ARB/MUX interface.
// Always needs to complete once started to count.
always @(posedge core_clk or negedge core_rst_n) begin
    if ( !core_rst_n ) begin
        dw_cnt <= #TP '0;
    end
    else if (rst_flit_alignment && !pcie_flit_mode) begin
        dw_cnt <= #TP '0;
    end
    else if (dw_cnt_ena) begin
        dw_cnt <= #TP dw_cnt_done ? '0 : (dw_cnt + 'd1);
    end
end

endmodule
