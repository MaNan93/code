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
// ---    $DateTime: 2023/10/09 13:27:34 $
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/xtlh_pkt_out_if.sv#5 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
// XTLH Output Packet Interface converts the VC struct into packet interface
//
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/cx_pl_pkg.svh"
`include "Layer3/xtlh_ms_pkg.svh"

module xtlh_pkt_out_if
  import  xtlh_ms_pkg::xtlh_vc_pkt_struct;
  import  xtlh_ms_pkg::tlp_end_struct;
  import  xtlh_ms_pkg::find_first;
  import  xtlh_ms_pkg::P_N_TLP_LEN;
  import  cx_pl_pkg::P_NW;
  import  cx_pl_pkg::P_NFM_NW;
  import  cx_pl_pkg::P_DW;
    import  xtlh_ms_pkg::P_NW_PROT;
#( 
  parameter TP = `TP
) 
                        (
  input                         core_clk,
  input                         core_rst_n,
  input xtlh_vc_pkt_struct      vc_pkt_in,                             // VC Packet Structure
  output  logic [P_N_TLP_LEN-1:0][10:0]          xtlh_pkt_if_tlp_len,              // TLP Length used for STP Calculation
  output  logic [P_DW-1:0]      xtlh_pkt_if_data,                      // TLP Data
  output  logic                 xtlh_pkt_if_dv,                        // Data Valid Indication
  output  logic [P_NW-1:0]      xtlh_pkt_if_sot,                       // TLP Start Marker
  output  logic [P_NW-1:0]      xtlh_pkt_if_eot,                       // TLP End Marker
  output  tlp_end_struct        xtlh_pkt_if_tlp_end,                   // TLP end struct
  output  logic [P_NW-1:0]      xtlh_pkt_if_badeot,                    // Badeot Marker
  input                         flit_mode_en,                          // Flit Mode Enabled
  output  logic [P_NW-1:0]      xtlh_pkt_if_ep,                        // Poisoned TLP Marker
  output  logic [P_NW-1:0]      xtlh_pkt_if_ptm,
  output  logic                 xtlh_pkt_if_sot_is_first,              // Indicates SOT First in Data Path
  output  logic                 xtlh_pkt_if_badeot_or,                 // Indicates a badeot in any DW
  output  logic                 xtlh_pkt_if_first_badeot,              // Indicates badeot first
  output  logic                 xtlh_pkt_if_eot_sot,                   // Indicates EOT after SOT in the data path
  output  logic                 xtlh_pkt_if_eot_sot_eot,               // Indicates EOT followed by SOT/EOT In the data path
  output  logic                 xtlh_pkt_if_pme_to_ack,                // PME_TO_ACK Message transmitted
  input                         rstctl_core_flush_req                  // Flush Request
  ,
  input                         halt_in,                               // Halt from lower layer
  input                         cfg_rasdp_error_mode,                  // Global RASDP Error Mode
  input                         xdlh_rasdp_error_mode                  // XDLH RASDP Error Mode
      ,
      output  logic [P_NW_PROT-1:0] xtlh_pkt_if_tlp_prot,              // TLP Protection Code
      output  logic                 xtlh_pkt_if_ras_dp_err_inband_kbd // in-band ras dp err known bad data
);

logic int_drop_tlp;

// RASDP checker insertion before the merge_fm/nfm modules
xtlh_vc_pkt_struct  int_pkt_in_chk, vc_pkt_in_tmp;                     // VC Packet Structure after ras_dp checker


xtlh_vc_pipe_ms
 #(
  .N                  (1),
  .PIPE               (0),
  .CAN_STALL          (0)
  ) u_xtlh_vc_pipe_ms (
  .clk                       (core_clk),
  .rst_n                     (core_rst_n),
  .in_pkt                    (vc_pkt_in),
  .out_halt                  (),
  .out_pkt                   (int_pkt_in_chk),
  .in_halt                   (1'b0)
);

logic [P_NW-1:0]  int_first_sot;
logic [P_NW-1:0]  int_first_eot;
logic [P_NW-1:0]  int_first_badeot;
logic             int_2_eot;
logic             int_1_eot;

// RAS Error Mode Filters
// Nullify 1 SOT/EOT pair
// Trash all other TLP's
logic             rasdp_error_mode;
logic             stop_data_flow_r;
logic             sot_transmitted;
logic             eot_detected;
logic             rasdp_filter_active_r;
logic             rasdp_filter_active;
logic             halt_in_r;
logic [P_NW-1:0]  rasdp_badeot;
logic             xdlh_rasdp_error_r;

assign rasdp_error_mode = !flit_mode_en && (cfg_rasdp_error_mode || xdlh_rasdp_error_r) && int_pkt_in_chk.dv;

always @(posedge core_clk or negedge core_rst_n) begin: halt_in_r_PROC
  if (!core_rst_n) begin
    halt_in_r           <= #TP 1'b0;
    xdlh_rasdp_error_r  <= #TP '0;
  end else begin
    halt_in_r           <= #TP halt_in;
    xdlh_rasdp_error_r  <= #TP xdlh_rasdp_error_mode;
  end
end

// Stop the data flow as soon as we have a non halted cycle once the filter is
// active.
// Stop the data flow immediately regardless of halt if we are not putting
// valid data on the interface
always_ff @(posedge core_clk or negedge core_rst_n) begin: stop_data_flow_r_PROC
  if (!core_rst_n)
    stop_data_flow_r <= #TP 1'b0;
  else if ((rasdp_filter_active && !halt_in) || (rasdp_error_mode && !int_pkt_in_chk.dv))
    stop_data_flow_r <= #TP 1'b1;
  else if (!rasdp_error_mode && (!int_pkt_in_chk.dv || (|int_pkt_in_chk.eot)))
    stop_data_flow_r <= #TP 1'b0;
end

// detect when we have already transmitted the start of the packet. This
// happens if there is no sot prior to an eot and we have an eot => the start
// of the packet has been transmitted, we started so we must finish. Wait
// until halt_in_r before supressing the interface
assign sot_transmitted = int_pkt_in_chk.dv && |int_pkt_in_chk.eot && !(|filt_sot_after_eot(int_pkt_in_chk.eot, int_pkt_in_chk.sot));
// eot_detected is used to trigger gating of the interface on RAS mode entry.
// => do not gate if there is an eot which has beeen halted                  // Once the filter is active it remains active until there is an unhalted
assign eot_detected         = |int_pkt_in_chk.eot & !sot_transmitted  ;       // cycle rasdp_filter_active_r keeps it set. As soon as stop_data_flow_r is

// set rasdm_filter_active is cleared.
assign rasdp_filter_active  = (rasdp_error_mode && (eot_detected || sot_transmitted && !halt_in_r) || rasdp_filter_active_r) && !stop_data_flow_r;

// Once we begin to filter we must continue to do so until the
// stop_data_flow_r has kicked in to clear the interface. We can only clear
// the interface when it is not halted so we need to keep the filter active as
// long as we are halted.
always_ff @(posedge core_clk or negedge core_rst_n) begin: rasdp_filter_active_r_PROC
  if (!core_rst_n)
    rasdp_filter_active_r <= #TP 1'b0;
  else if (rasdp_filter_active)
    rasdp_filter_active_r <= #TP 1'b1;
  else if (!halt_in)
    rasdp_filter_active_r <= #TP 1'b0;
end

// make sure EOT is transformed in a bad eot if RASDP error mode is asserted,
// only if the TLP has been presented in this cycle (if we were halted in the
// previous cycle don't assert badeot. The packet on the interface may be
// transmitted even if halt is asserted so only nullify as we present
assign rasdp_badeot = int_pkt_in_chk.eot & {P_NW{rasdp_filter_active}};

always_comb begin : tlp_out_PROC
  vc_pkt_in_tmp = int_pkt_in_chk;
  vc_pkt_in_tmp.dv = int_pkt_in_chk.dv && !(stop_data_flow_r);
  if(rstctl_core_flush_req) begin
    vc_pkt_in_tmp.dv = '0;
    vc_pkt_in_tmp.sot = '0;
    vc_pkt_in_tmp.eot = '0;
    vc_pkt_in_tmp.data = '0;
    vc_pkt_in_tmp.tlp_prot = '0;
  end else if(stop_data_flow_r) begin
    vc_pkt_in_tmp.sot = '0;
    vc_pkt_in_tmp.eot = '0;
    vc_pkt_in_tmp.badeot = '0;
    vc_pkt_in_tmp.data = '0;
    vc_pkt_in_tmp.tlp_prot = '0;
  end else if(rasdp_filter_active) begin
    vc_pkt_in_tmp.sot = filt_sot_after_eot(int_pkt_in_chk.eot, int_pkt_in_chk.sot);
    vc_pkt_in_tmp.eot = filt_dups(int_pkt_in_chk.eot);
    vc_pkt_in_tmp.badeot = filt_dups(rasdp_badeot);
  end else
    vc_pkt_in_tmp = int_pkt_in_chk;
end : tlp_out_PROC

// If a single cycle nullified TLP is presented in non-flit mode it will be dropped
assign int_drop_tlp = !flit_mode_en && vc_pkt_in_tmp.dv && |vc_pkt_in_tmp.sot && |(vc_pkt_in_tmp.eot & vc_pkt_in_tmp.badeot);

// Connect the Packet Interface
always_comb begin : pkt_if_PROC
  int_first_sot = find_first(vc_pkt_in_tmp.sot);
  int_first_eot = find_first(vc_pkt_in_tmp.eot);
  int_first_badeot = find_first(vc_pkt_in_tmp.badeot);
  int_2_eot = !(^vc_pkt_in_tmp.eot) & (|vc_pkt_in_tmp.eot);
  int_1_eot = (^vc_pkt_in_tmp.eot) & (|vc_pkt_in_tmp.eot);
  xtlh_pkt_if_tlp_end.vc = '0;
  xtlh_pkt_if_tlp_end.eot = int_pkt_in_chk.eot;
  if(int_drop_tlp) begin
    xtlh_pkt_if_tlp_len = '0;
    xtlh_pkt_if_data = '0;
    xtlh_pkt_if_tlp_prot = '0;
    xtlh_pkt_if_ras_dp_err_inband_kbd = '0;
    xtlh_pkt_if_dv = '0;
    xtlh_pkt_if_sot = '0;
    xtlh_pkt_if_eot = '0;
    xtlh_pkt_if_badeot = '0;
    xtlh_pkt_if_ep = '0;
    xtlh_pkt_if_ptm = '0;
    // SOT occured before EOT
    xtlh_pkt_if_sot_is_first = '0;
    xtlh_pkt_if_badeot_or = '0;
    xtlh_pkt_if_first_badeot = '0;
    xtlh_pkt_if_eot_sot = '0;
    xtlh_pkt_if_eot_sot_eot = '0;
  end else begin
    xtlh_pkt_if_tlp_len = '0;
    for(int i = 0; i < $bits(vc_pkt_in_tmp.sot); i = i + 1) begin
      if(vc_pkt_in_tmp.sot[i]) begin
        if(i < P_NFM_NW)
          xtlh_pkt_if_tlp_len[0] = vc_pkt_in_tmp.tlp_len[i];
      end
    end
    xtlh_pkt_if_data = vc_pkt_in_tmp.data;
    xtlh_pkt_if_tlp_prot = vc_pkt_in_tmp.tlp_prot;
    xtlh_pkt_if_ras_dp_err_inband_kbd = vc_pkt_in_tmp.ras_dp_err_inband_kbd;
    xtlh_pkt_if_dv = vc_pkt_in_tmp.dv;
    xtlh_pkt_if_sot = vc_pkt_in_tmp.sot;
    xtlh_pkt_if_eot = vc_pkt_in_tmp.eot;
    xtlh_pkt_if_badeot = vc_pkt_in_tmp.badeot;
    xtlh_pkt_if_ep = vc_pkt_in_tmp.ep;
    xtlh_pkt_if_ptm = vc_pkt_in_tmp.ptm;
    // SOT occured before EOT
    xtlh_pkt_if_sot_is_first = (|vc_pkt_in_tmp.sot && (int_first_sot < int_first_eot)) || ((|vc_pkt_in_tmp.sot) && !(|vc_pkt_in_tmp.eot));
    xtlh_pkt_if_badeot_or = |vc_pkt_in_tmp.badeot;
    xtlh_pkt_if_first_badeot = |vc_pkt_in_tmp.badeot && (int_first_badeot < int_first_sot);
    xtlh_pkt_if_eot_sot = int_1_eot && (|vc_pkt_in_tmp.sot) && (int_first_eot < int_first_sot);
    xtlh_pkt_if_eot_sot_eot = int_2_eot && (|vc_pkt_in_tmp.sot);
  end
end : pkt_if_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin : pme_to_ack_PROC
  if(!core_rst_n)
    xtlh_pkt_if_pme_to_ack  <= #TP '0;
  else
    xtlh_pkt_if_pme_to_ack  <= #TP |vc_pkt_in_tmp.pme_to_ack;
end : pme_to_ack_PROC

function automatic [P_NW-1:0] filt_sot_after_eot;
input [P_NW-1:0] eot;
input [P_NW-1:0] sot;
reg [P_NW-1:0] new_data;
begin
  int j;
  int eot_found;
  eot_found = 0;
  new_data  = 0;  
  for (j=0; j<P_NW; j=j+1)
  begin
    if (eot_found == 0)
    begin
      new_data[j] = sot[j];
      if (eot[j] == 1)
        eot_found = 1;
      else
        eot_found = 0;
    end
    else
      new_data[j] = 0;
  end
  filt_sot_after_eot = new_data;
end
endfunction

function automatic [P_NW-1:0] filt_dups;
input [P_NW-1:0] data;
reg [P_NW-1:0] new_data;
begin
  int j;
  int first_found;
  first_found = 0;
  new_data    = 0;  
  for (j=0; j<P_NW; j=j+1)
  begin
    if (first_found == 0)
    begin
      new_data[j] = data[j];
      if (data[j] == 1)
        first_found = 1;
      else
        first_found = 0;
    end
    else
      new_data[j] = 0;
  end
  filt_dups = new_data;
end
endfunction 
endmodule
