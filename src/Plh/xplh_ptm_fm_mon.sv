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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_ptm_fm_mon.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description:
// Search Flits in the Tx datapath (XPLH Layer) for Flit Marker with
// the PTM bit set.
// If Flit with PTM TLP is found, report timestamp to the CDM PTM modules.
// Tx Datapath must wait for the Flit to be transmitted by the xmlh_byte_xmt
// before reporting time-stamp.
// Use Port Direction (USP or DSP) to decode PTM Request or PTM Response.
//
// EOF Signal:
//  128:
//    - 2'b00: no eof close
//    - 2'b01: cycle prior to eof
//    - 2'b10: last cycle of flit (eof)
//  256 and above
//    - 2'b00: no eof close
//    - 2'b11: last cycle of flit (eof)
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"

module xplh_ptm_fm_mon
  import  cx_pl_pkg::P_DW;
  import  cx_pl_pkg::P_DLP0_END;
  import  cx_pl_pkg::P_DLP2_END;

                        (
// ---- inputs ---------------
input                        core_clk,
input                        core_rst_n,
input                        cfg_upstream_port,  // Upstream port when it is high
input                        cxl_mode_enable,    // CXL Mode Enable
input                        sample_marker,      // Event to samle flit marker
input                        sample_flit,        // Event to sample flit data bus
input                        report_timestamp,   // Event to report PTM time stamp
input [P_DW-1:0]             flit_data,          // Data carrying the flit
// ---- outputs --------------
output logic                 ptm_sot,            // Indicate to CDM to capture time
output logic                 ptm_request,        // capture request time
output logic                 ptm_response        // capture response time
);

localparam TP = `TP;  // Clock to Q delay (simulator insurance)

logic [7:0] dlp0;     // DLLP Byte 0
logic [7:0] dlp2;     // DLLP Byte 2
logic is_ptm_flit;    // Flit is carrying PTM Marker
logic is_ptm_flit_r;
logic int_report_t;
logic flit_marker_r;

// Grab the DLP0 and DLP2 Bytes from the Flit when sample_flit is active
assign dlp0 = (sample_flit) ? flit_data[P_DLP0_END -: 8] : 8'b0;
assign dlp2 = (sample_flit) ? flit_data[P_DLP2_END -: 8] : 8'b0;
// Decode from the DLLP bytes to check if the PTM Flit Marker bit is set
assign is_ptm_flit = (( cxl_mode_enable ? flit_marker_r : (dlp0[7:6]==2'b01 && dlp0[4])) && dlp2[4] && dlp2[7]) ? 1'b1 : 1'b0;

// -------------------------------------------------------------------
// Track the Flit in XPLH, to check if PTM Flit Marker bit is set
// Report time, when xmlh_byte_transmit has send the EOF of the Flit.
// -------------------------------------------------------------------

// latch the PTM flit status for the duration of the flit
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    is_ptm_flit_r <= #TP 1'b0;
  else if (sample_flit)
    is_ptm_flit_r <= #TP is_ptm_flit;
  else
    is_ptm_flit_r <= #TP is_ptm_flit_r;
end
assign int_report_t = (report_timestamp && is_ptm_flit_r) ? 1'b1 : 1'b0;

// Register back to CDM PTM requester/responder, time capture events for PTM
// Requests and PTM responses observed by this module.
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n) begin
    ptm_sot      <= #TP 1'b0;
    ptm_request  <= #TP 1'b0;
    ptm_response <= #TP 1'b0;
  end else begin
    ptm_sot <= #TP int_report_t;
    // PTM requests are transmited by USP and received by DSP
    if (int_report_t && cfg_upstream_port==1) begin
      ptm_request <= #TP 1'b1;
    end else begin
      ptm_request <= #TP 1'b0;
    end
    // PTM responses are transmited by DSP and received by USP
    if (int_report_t && cfg_upstream_port==0) begin
      ptm_response <= #TP 1'b1;
    end else begin
      ptm_response <= #TP 1'b0;
    end
  end
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    flit_marker_r <= #TP 1'b0;
  else if (cxl_mode_enable && sample_marker)
    flit_marker_r <= #TP ((flit_data[7:6] == 2'b01) && flit_data[4]);
  else
    flit_marker_r <= #TP flit_marker_r;
end

endmodule
