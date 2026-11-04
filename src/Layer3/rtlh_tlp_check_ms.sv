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
// ---    $DateTime: 2023/12/05 11:22:43 $
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/rtlh_tlp_check_ms.sv#7 $
// -------------------------------------------------------------------------
// --- Module Description:
// ---  * Credit check
// ---    On TLP end (i.e. EOT), if the TLP is valid (i.e. not dllp_err):
// ---    - Request FC module to check for credits
// ---    - If credits are available, credit counters get updated and move the TLP on
// ---    - If credits are depleted, FC module reports the error. Credit counters are not updated.
// ---      The TLP is marked by dllp_err to istruct the RADM it must be discarded.
// ---  * RAS DES events dectection
// ---  * Truncate packets during Flush
// ---    in case a packet is still in progress when the flush request is asserted.
// ---    In this scenario we are guaranteed the remaining of that packet will never
// ---    arrive because the link is already down. Once the flush module finishes flushing, 
// ---    the core_rst module will reset the core and LTSSM will transit to DETECT_QUIET.
// ---    The fake EOT must be qualified with dllp_err because the TLP is corrupted and must be discarded.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Layer3/rtlh_pkg.svh"
`include "products/pcie_pkg.svh"

`define CX_RTLH_NO_BEHAVIOURAL_MODEL

module rtlh_tlp_check_ms
import rtlh_pkg::rtlh_qdw_extract_t;
import DWC_pcie_core_pkg::rtlh_radm_datapath_t;
import DWC_pcie_core_pkg::RX_NQDW;                 // Number of 128-bit quad-dwords received per cycle
import pcie_pkg::fc_type_e;
import pcie_pkg::E_FC_NONE;
#(
parameter   INST     = 0,                          // The uniquifying parameter for each port logic instance.
parameter   NW       = `CX_NW,                     // Number of 32-bit dwords handled by the datapath each clock.
parameter   DW       = NW*32,                      // Number of bits handled by the datapath on each clock cycle
parameter   RX_TLP   = `CX_RX_TLP,                 // Number of TLPs that can be processed in a single cycle
parameter   TP       = `TP                         // Clock to Q delay (simulator insurance)
)

                        (
// ---- inputs ---------------
input                                    core_clk,
input                                    core_rst_n,
input                                    rstctl_core_flush_req,
input   rtlh_qdw_extract_t [RX_NQDW-1:0] rtqextract,
input                                    rtqextract_fm_nullified, // The last TLP ending was Nullified by the Flit Marker (by specs credits must be consumed in FM)
input                                    rtqextract_fm_poisoned,  // The last TLP ending was Poisoned by the Flit Marker
input                      [RX_NQDW-1:0] rtfcgen_rtcheck_overfl_err, // Credit error from FC
// ---- outputs ---------------- 
output  [3*RX_NQDW-1:0]                  rtcheck_rtfcgen_vc,
output  [2*RX_NQDW-1:0]                  rtfcgen_fctype,
output  [RX_NQDW-1:0]                    rtfcgen_incr_enable,
output  [9*RX_NQDW-1:0]                  rtfcgen_incr_amt,
output  rtlh_radm_datapath_t             rtlh_radm
,
output  [RX_TLP-1:0]                     rtlh_rx_memwr_evt,       // Pulse : Rx Memory Write TLP for Ras D.E.S event counter
output  [RX_TLP-1:0]                     rtlh_rx_defmemwr_evt,    // Pulse : Rx Deferrable Memory Write TLP for Ras D.E.S event counter
output  [RX_TLP-1:0]                     rtlh_rx_memrd_evt,       // Pulse : Rx Memory Read TLP for Ras D.E.S event counter
output  [RX_TLP-1:0]                     rtlh_rx_cfgwr_evt,       // Pulse : Rx Config Write TLP for Ras D.E.S event counter
output  [RX_TLP-1:0]                     rtlh_rx_cfgrd_evt,       // Pulse : Rx Config Read TLP for Ras D.E.S event counter
output  [RX_TLP-1:0]                     rtlh_rx_iowr_evt,        // Pulse : Rx I/O Write TLP for Ras D.E.S event counter
output  [RX_TLP-1:0]                     rtlh_rx_iord_evt,        // Pulse : Rx I/O Read TLP for Ras D.E.S event counter
output  [RX_TLP-1:0]                     rtlh_rx_cplwod_evt,      // Pulse : Rx Completion without Data TLP for Ras D.E.S event counter
output  [RX_TLP-1:0]                     rtlh_rx_cplwd_evt,       // Pulse : Rx Completion with Data TLP for Ras D.E.S event counter
output  [RX_TLP-1:0]                     rtlh_rx_msg_evt,         // Pulse : Rx Message TLP for Ras D.E.S event counter
output  [RX_TLP-1:0]                     rtlh_rx_atmcop_evt,      // Pulse : Rx AtomicOp TLP for Ras D.E.S event counter
output  [RX_TLP-1:0]                     rtlh_rx_tlpwprefix_evt,  // Pulse : Rx TLP with Prefix for Ras D.E.S event counter
output  [RX_TLP*11-1:0]                  rtlh_rx_tlp_dpsize       // Receiving TLP's data payload size[DW]
);

localparam bit PARITY_MODE = `CX_RAS_PARITY_MODE;

// --------------------------------------
// Request FC to update credits consumed. 
// --------------------------------------
// In case of credits depleted, credits are not updated and rtfcgen_rtcheck_overfl_err is returned.
genvar nqdw;
generate for (nqdw=0; nqdw<RX_NQDW; nqdw=nqdw+1) begin : gen_crd_consumed_req
    assign rtcheck_rtfcgen_vc [nqdw*3+:3] = rtqextract[nqdw].hdr_vc;
    assign rtfcgen_fctype     [nqdw*2+:2] = rtqextract[nqdw].hdr_fc;
    assign rtfcgen_incr_enable[nqdw]      = rtqextract[nqdw].eot & ~rtqextract[nqdw].dllp_err & rtqextract[nqdw].hdr_fc!=E_FC_NONE;
    assign rtfcgen_incr_amt   [nqdw*9+:9] = rtqextract[nqdw].dcrd_amt; 
end
endgenerate

// Optional pipeline - FC credits check is provided 1 cycle later
localparam N_CYCLE_DELAY = 0;
localparam PIPE_FC_WD =  $size(rtlh_qdw_extract_t)*RX_NQDW +2 ;
reg fc_check_pipe_en;
rtlh_qdw_extract_t [RX_NQDW-1:0] rtqextract_d;
wire rtqextract_fm_nullified_d;
wire rtqextract_fm_poisoned_d;
delay_n_w_enable_autoreset

#(N_CYCLE_DELAY, PIPE_FC_WD) u_delay_fc_check_pipe (
  .clk    (core_clk),
  .rst_n  (core_rst_n),
  .clear  (1'b0),
  .en     (fc_check_pipe_en),
  .din    ({rtqextract , rtqextract_fm_nullified  , rtqextract_fm_poisoned}),
  .dout   ({rtqextract_d , rtqextract_fm_nullified_d, rtqextract_fm_poisoned_d})
);
always_comb begin : fc_pipe_enable_proc
    fc_check_pipe_en = 0;
    for (int i=0; i<RX_NQDW; i++) 
        fc_check_pipe_en = fc_check_pipe_en | rtqextract[i].valid;
end

reg rtlh_radm_qdw_en;
always_comb begin : enable_proc
    rtlh_radm_qdw_en = 0;
    for (int i=0; i<RX_NQDW; i++) 
        rtlh_radm_qdw_en = rtlh_radm_qdw_en | rtqextract_d[i].valid;
end

// --------------------------------------
// Truncate packets during Flush
// --------------------------------------

// Keep track of packet in progress, its Type and VC
reg       [RX_NQDW-1:0]      pkt_in_progress;
reg                          pkt_in_progress_d;
reg       [RX_NQDW-1:0][2:0] vc_in_progress;
reg                    [2:0] vc_in_progress_d;
fc_type_e [RX_NQDW-1:0]      fc_in_progress;
fc_type_e                    fc_in_progress_d;
always @(*) begin
    for(int i = 0; i< RX_NQDW; i = i + 1) begin
        pkt_in_progress[i] = rtqextract_d[i].eot ? 0 : 
                             rtqextract_d[i].sot ? 1 :
                             (i==0)? pkt_in_progress_d : pkt_in_progress[i-1];
        vc_in_progress[i]  = rtqextract_d[i].hdr_valid ? rtqextract_d[i].hdr_vc : 
                             (i==0)? vc_in_progress_d  : vc_in_progress[i-1];
        fc_in_progress[i]  = rtqextract_d[i].hdr_valid ? rtqextract_d[i].hdr_fc : 
                             (i==0)? fc_in_progress_d  : fc_in_progress[i-1];
    end
end
always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        pkt_in_progress_d <= #TP '0;
        vc_in_progress_d  <= #TP '0;
        fc_in_progress_d  <= #TP E_FC_NONE;
    end else if (rtlh_radm_qdw_en) begin
        pkt_in_progress_d <= #TP pkt_in_progress[RX_NQDW-1];
        vc_in_progress_d  <= #TP vc_in_progress[RX_NQDW-1];
        fc_in_progress_d  <= #TP fc_in_progress[RX_NQDW-1];
    end
end

// Register that the Flush was issued and keep track until reset
reg flush_completed;
always @(posedge core_clk or negedge core_rst_n) begin
    if( !core_rst_n ) flush_completed <= #TP '0;
    else              flush_completed <= #TP flush_completed | rstctl_core_flush_req;
end

// Trucation can happen only once and only when a packet is actually in progress
wire truncation_required;
assign truncation_required = rstctl_core_flush_req & pkt_in_progress_d & ~flush_completed;

// The Flush command is prepared to be executed on the next cycle
reg flush_cmd;
always @(posedge core_clk or negedge core_rst_n) begin
    if( !core_rst_n ) flush_cmd       <= #TP '0;
    else              flush_cmd       <= #TP truncation_required;
end



// --------------------------------------
// Prepare outputs.
// --------------------------------------
// In case of rtfcgen_rtcheck_overfl_err (i.e. credits depleted) the TLP is aborted with dllp_err,
// this is to indicate the Radm that credits were not updated and the TLP must be dropped.
rtlh_radm_datapath_t out_rtlh_radm_qdw;
rtlh_radm_datapath_t rtlh_radm_tmp;
generate for (nqdw=0; nqdw<RX_NQDW; nqdw=nqdw+1) begin : gen_rtlh_radm_itf
    wire truncate;
    assign truncate = (nqdw==0) & flush_cmd;
    assign out_rtlh_radm_qdw.valid    [nqdw]       = (truncate)? 1'b1                               : rtqextract_d[nqdw].valid;
    assign out_rtlh_radm_qdw.sot      [nqdw]       =                                                  rtqextract_d[nqdw].sot;
    assign out_rtlh_radm_qdw.eot      [nqdw]       = (truncate)? 1'b1                               : rtqextract_d[nqdw].eot;
    assign out_rtlh_radm_qdw.dwen     [nqdw]       = (truncate)? 4'b1                               : rtqextract_d[nqdw].dwen;
    assign out_rtlh_radm_qdw.data     [nqdw]       = (truncate)?   '0                               : rtqextract_d[nqdw].data;
    assign out_rtlh_radm_qdw.hdr      [nqdw].valid =                                                  rtqextract_d[nqdw].hdr_valid;
    assign out_rtlh_radm_qdw.hdr      [nqdw].vc    = (truncate)? vc_in_progress_d                   : rtqextract_d[nqdw].hdr_vc;
    assign out_rtlh_radm_qdw.hdr      [nqdw].fc    = (truncate)? fc_in_progress_d                   : rtqextract_d[nqdw].hdr_fc;
    assign out_rtlh_radm_qdw.dllp_err [nqdw]       = (truncate)? 1'b1                               : rtqextract_d[nqdw].dllp_err | rtfcgen_rtcheck_overfl_err[nqdw];
    assign out_rtlh_radm_qdw.data_prot[nqdw]       = (truncate)? {`CX_RAS_QDW_PROT_WD{PARITY_MODE}} : rtqextract_d[nqdw].data_prot;
end
endgenerate

assign out_rtlh_radm_qdw.pending = 1'b0; // Needed to avoid spyglass violation
assign out_rtlh_radm_qdw.fm_nullified = rtqextract_fm_nullified_d;
assign out_rtlh_radm_qdw.fm_poisoned  = rtqextract_fm_poisoned_d;

// Registered output stage, delay all signals except for rtlh_radm.pending
delay_n_w_enable_autoreset

#(1, $size(rtlh_radm_datapath_t)) u_delay_n_w_enable (
  .clk    (core_clk),
  .rst_n  (core_rst_n),
  .clear  (1'b0),
  .en     (rtlh_radm_qdw_en|flush_cmd),
  .din    (out_rtlh_radm_qdw),
  .dout   (rtlh_radm_tmp)
);                               
                                 
always_comb begin
  rtlh_radm         = rtlh_radm_tmp;
  rtlh_radm.pending = |out_rtlh_radm_qdw.valid; // pending signal is used to warn radm tlps will be ready on the next clock cycle
end

// RASDES event counters
logic [RX_TLP-1:0]    memwr_evt;
logic [RX_TLP-1:0]    defmemwr_evt;
logic [RX_TLP-1:0]    memrd_evt;
logic [RX_TLP-1:0]    cfgwr_evt;
logic [RX_TLP-1:0]    cfgrd_evt;
logic [RX_TLP-1:0]    iowr_evt;
logic [RX_TLP-1:0]    iord_evt; 
logic [RX_TLP-1:0]    cplwod_evt;
logic [RX_TLP-1:0]    cplwd_evt;
logic [RX_TLP-1:0]    msg_evt; 
logic [RX_TLP-1:0]    atmcop_evt;
logic [RX_TLP-1:0]    tlpwprefix_evt;
logic [RX_TLP*11-1:0] tlp_dpsize;
always_comb begin
  reg [$clog2(RX_TLP)-1:0] k;
  k=0;
  memwr_evt     = 0;
  defmemwr_evt  = 0;
  memrd_evt     = 0;
  cfgwr_evt     = 0;
  cfgrd_evt     = 0;
  iowr_evt      = 0;
  iord_evt      = 0; 
  cplwod_evt    = 0;
  cplwd_evt     = 0;
  msg_evt       = 0; 
  atmcop_evt    = 0;
  tlpwprefix_evt= 0;
  tlp_dpsize    = 0;
  for (int n=0; n<RX_NQDW; n = n + 1) begin
    if (rtqextract[n].eot && !rtqextract[n].dllp_err && rtqextract[n].valid) begin
      if (k<RX_TLP) begin
        memwr_evt     [k]        = (rtqextract[n].evt_type==rtlh_pkg::MEMWR);
        defmemwr_evt  [k]        = (rtqextract[n].evt_type==rtlh_pkg::DEFMEMWR); 
        memrd_evt     [k]        = (rtqextract[n].evt_type==rtlh_pkg::MEMRD);
        cfgwr_evt     [k]        = (rtqextract[n].evt_type==rtlh_pkg::CFGWR);
        cfgrd_evt     [k]        = (rtqextract[n].evt_type==rtlh_pkg::CFGRD);
        iowr_evt      [k]        = (rtqextract[n].evt_type==rtlh_pkg::IOWR);
        iord_evt      [k]        = (rtqextract[n].evt_type==rtlh_pkg::IORD);
        cplwod_evt    [k]        = (rtqextract[n].evt_type==rtlh_pkg::CPLWOD);
        cplwd_evt     [k]        = (rtqextract[n].evt_type==rtlh_pkg::CPLWD);
        msg_evt       [k]        = (rtqextract[n].evt_type==rtlh_pkg::MSG);
        atmcop_evt    [k]        = (rtqextract[n].evt_type==rtlh_pkg::ATMCOP);
        tlpwprefix_evt[k]        =  rtqextract[n].has_pfx;
        tlp_dpsize    [k*11+:11] =  rtqextract[n].dpsize;
        k = k + 1;
      end
    end
  end
end

assign rtlh_rx_memwr_evt      = memwr_evt;
assign rtlh_rx_defmemwr_evt   = defmemwr_evt;
assign rtlh_rx_memrd_evt      = memrd_evt;
assign rtlh_rx_cfgwr_evt      = cfgwr_evt;
assign rtlh_rx_cfgrd_evt      = cfgrd_evt;
assign rtlh_rx_iowr_evt       = iowr_evt;
assign rtlh_rx_iord_evt       = iord_evt;
assign rtlh_rx_cplwod_evt     = cplwod_evt;
assign rtlh_rx_cplwd_evt      = cplwd_evt;
assign rtlh_rx_msg_evt        = msg_evt;
assign rtlh_rx_atmcop_evt     = atmcop_evt;
assign rtlh_rx_tlpwprefix_evt = tlpwprefix_evt;
assign rtlh_rx_tlp_dpsize     = tlp_dpsize;

endmodule
