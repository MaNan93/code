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
// ---    $DateTime: 2023/09/27 02:27:25 $
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/rplh_ptm_fm_mon.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description:
// Decode DLLP bytes to check if FLit is carrying a FLit Marker with the
// PTM bit set.
// If Flit with PTM TLP is found, report timestamp to the CDM PTM modules.
// Use Port Direction (USP or DSP) to decode PTM Request or PTM Response.
//
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module rplh_ptm_fm_mon

                      (
// ---- inputs ---------------
input                        core_clk,
input                        core_rst_n,
input                        cfg_upstream_port, // Upstream port when it is high
input                        sample_flit,       // Event to sample dllp bytes
input                        flit_is_duplicate, // Duplicate FLit received
input [7:0]                  dlp0,              // DLLP Byte 0
input [7:0]                  dlp2,              // DLLP Byte 2
// ---- outputs --------------
output logic                 ptm_sot,           // Indicate to CDM to capture time
output logic                 ptm_request,       // Capture is for a PTM request
output logic                 ptm_response,      // Capture is for a PTM response
output                       ptm_duplicate      // Indicate a duplicate Flit with PTM message
);
localparam TP = `TP;                            // Clock to Q delay (simulator insurance)

logic is_ptm_flit;
logic ptm_duplicate_r;

assign ptm_duplicate = (ptm_duplicate_r || flit_is_duplicate) ? 1'b1 : 1'b0;

// Decode from the DLLP bytes if this is a flit Marker with PTM bit set
assign is_ptm_flit = ((sample_flit || flit_is_duplicate) && dlp0[7:6]==2'b01 && dlp0[4] && dlp2[4] && dlp2[7]) ? 1'b1 : 1'b0;

// Register back to CDM PTM logic time capture events for PTM
// Request and PTM response
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n) begin
    ptm_sot         <= #TP 1'b0;
    ptm_request     <= #TP 1'b0;
    ptm_response    <= #TP 1'b0;
    ptm_duplicate_r <= #TP 1'b0;
  end else begin
    ptm_sot <= #TP is_ptm_flit;
    ptm_duplicate_r <= #TP flit_is_duplicate;
    // PTM requests are transmited by USP and received by DSP
    if (is_ptm_flit && cfg_upstream_port==0) begin
      ptm_request <= #TP 1'b1;
    end else begin
      ptm_request <= #TP 1'b0;
    end
    // PTM responses are transmited by DSP and received by USP
    if (is_ptm_flit && cfg_upstream_port==1) begin
      ptm_response <= #TP 1'b1;
    end else begin
      ptm_response <= #TP 1'b0;
    end
  end
end

endmodule
