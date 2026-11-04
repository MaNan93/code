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
// ---    $DateTime: 2023/06/30 15:54:26 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_clk_control_ms.sv#4 $
// -------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// RADM Clock Control : This module is clocked by the core clock which is
// not gated when the RADM is idle. The module monitors the requests at the inputs
// to the RADM and the internal status of the RADM receive queues and CPL LUT to
// generate an idle indication. The idle indication is registered to generate
// an enable output which may be used to gate off the RADM clock.
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"
 
module radm_clk_control_ms

  import radm_ms_pkg::CPL_LUT_DEPTH_EXTERNAL;
  import radm_ms_pkg::N_TRGT1_INTF;
  import radm_ms_pkg::port_trgt_clkg_ctrl_s;
  import DWC_pcie_ctl_pkg::TP;
  import DWC_pcie_ctl_pkg::NVC;
  import DWC_pcie_ctl_pkg::NVF;
  import DWC_pcie_ctl_pkg::NF;


  #(
   parameter RTLH_PIPE_DELAY     = 1,
   parameter FORMQ_RD_PORTS      = `CX_RADM_FORMQ_N_READ_PORT_VC,
   parameter FORM_TO_FLT_LATENCY = `CX_RADM_TRGT_FIFO_HDR_DP  // Latency from 1st SoT of formation queue to SoT out from filter module
   )
  (
  input                               radm_clk_ug,            // Ungated version of the radm_clk
  input                               core_rst_n,             // Core reset
  input                               clock_gating_en,        // Enable clock gating in the RADM
  input                               rtlh_radm_pending,      // transfer pending in the transaction layer
  input [NVC-1:0][FORMQ_RD_PORTS-1:0] form_filt_hv_p,       
  input [NVC-1:0]                     filt_form_halt_in_p,
  input [NVC-1:0][FORMQ_RD_PORTS-1:0] form_filt_hv_np,
  input [NVC-1:0]                     filt_form_halt_in_np,
  input [NVC-1:0][FORMQ_RD_PORTS-1:0] form_filt_hv_cpl,
  input [NVC-1:0]                     filt_form_halt_in_cpl,
  input [NVC-1:0][2:0]                radm_formq_not_empty,   // Indicates that the serialization queue has one or more TLP's pending
  input                               radm_cpl_lut_pending,   // CPL LUT pending flag 
  input [CPL_LUT_DEPTH_EXTERNAL-1:0]  radm_cpl_lut_valid,     // completion lookup table valid indication
  input                               radm_cpl_lut_busy,      // CPL LUT pending flag
  // TRGT Interface Signals
  input  [N_TRGT1_INTF-1:0]           radm_trgt1_intf_eot_p,
  input  [N_TRGT1_INTF-1:0]           trgt1_radm_intf_halt_p,
  input  [N_TRGT1_INTF-1:0]           radm_trgt1_intf_eot_np,
  input  [N_TRGT1_INTF-1:0]           trgt1_radm_intf_halt_np,
  input  [N_TRGT1_INTF-1:0]           radm_trgt1_intf_eot_cpl,
  input  [N_TRGT1_INTF-1:0]           trgt1_radm_intf_halt_cpl,
  input                               radm_trgt0_p,           // Pulsed when Posted TRGT0 request accepted by LBC
  input                               radm_trgt0_np,          // Pulsed when Non-Posted TRGT0 request accepted by LBC
  // Demux Clock Gating Control Signals
  input port_trgt_clkg_ctrl_s         port_trgt_clkg_ctrl,
  output logic                        radm_trgt1_p_pending,   // TRGT1 Posted Pending Info
  input                               radm_trgt0_halt,        // trgt0 packet Halt 
  // IDE idle signal is not required to generate RADM IDLE as FORMQ is already counting formQ output TLP and tracking forall TLP's received at radm output (irrespective of IDE or non-IDE) 
  input                             radm_rtlh_crd_pending,  // Credit transfer pending to RTLH
  input  logic                      hdr_log_idle,
  output logic                      radm_idle,              // Radm idle flag
  output logic                      radm_clk_en             // Enable the RADM clock
);

  // Receive path latency RTHL to Formation Queue
  localparam RTLH_QUEUE_LATENCY = 10; // Latency from TLP header decoder(2 clock) + Input of the RAM from formation queue(4 clock).                   
  localparam PST_RX_Q_LATENCY = 8; // Latency from Posted Rx queue empty to Rx queue header valid

  // Parameters used to calculated latency for the CPL LUT write path
  localparam CPL_LUT_LATENCY = 1 + `CX_RADM_CPL_LUT_PIPE_EN_VALUE + RTLH_PIPE_DELAY;

  localparam TRGT_EOT_CNT_WD = $clog2(N_TRGT1_INTF)+1;
  localparam TOTAL_NUM_FORMQ_RD_PORTS = FORMQ_RD_PORTS*NVC;
  // Log2 of the max number of TLPs possible from Rx Q to TRGT
  localparam MAX_TRGT_TLP_PEND_CNT_WD = $clog2(`CX_RADM_RXQ_TO_TRGT_DELAY) + 1;

  // ------------------------- Signal Declarations ------------------------- //
  logic                                                       int_radm_idle;
  logic                                                       int_radm_clk_en;
  logic                                                       int_radm_idle_r;
  logic                                                       int_radm_clk_en_r;
  logic                                                       rx_busy;
  logic                                                       radm_rx_idle;
  logic [N_TRGT1_INTF-1:0]                                    s_all_trgt0_p, s_all_trgt0_np, s_all_trgt_dropped_np;
  logic [TRGT_EOT_CNT_WD-1:0]                                 s_all_trgt_dropped_cnt_np;
  logic [TRGT_EOT_CNT_WD-1:0]                                 s_all_trgt0_cnt_p;
  logic [$clog2(TOTAL_NUM_FORMQ_RD_PORTS):0]                  s_all_rx_cnt_p, s_all_rx_cnt_np, s_all_rx_cnt_cpl;
  logic [TOTAL_NUM_FORMQ_RD_PORTS-1:0]                        s_all_rx_p, s_all_rx_np, s_all_rx_cpl;
  logic [N_TRGT1_INTF-1:0]                                    r_all_trgt1_eot_p, r_all_trgt1_eot_np, r_all_trgt1_eot_cpl; 
  logic [TRGT_EOT_CNT_WD-1:0]                                 s_all_trgt1_cnt_p, s_all_trgt1_cnt_np, s_all_trgt1_cnt_cpl; 
  logic [MAX_TRGT_TLP_PEND_CNT_WD-1:0]                        r_pending_cnt_trgt1_p, r_pending_cnt_trgt_np, r_pending_cnt_trgt_cpl;
  logic [MAX_TRGT_TLP_PEND_CNT_WD-1:0]                        r_pending_cnt_trgt0_p;
  logic                                                       r_trgt_pending, r_trgt1_p_pending, r_trgt1_p_idle;
  logic                                                       tpidl_trgt1_p_idle;

  // ------------------------- End of Signal Declarations ----------------- //

  // ------------------------------------------------------------------------------------
  // Extract internal TLP TRGT Info
  always_comb  begin : proc_comb_trgt_clkg_info
     // Index 0:P, Index 1:NP, Index 2:CPL
    for (int trgt=0; trgt<N_TRGT1_INTF; trgt++) begin
      s_all_trgt0_p[trgt] = port_trgt_clkg_ctrl.port_trgt_clkg_ctrl[trgt].trgt_clkg_ctrl[0].tlp_routed_to_trgt0;
      s_all_trgt_dropped_np[trgt] = port_trgt_clkg_ctrl.port_trgt_clkg_ctrl[trgt].trgt_clkg_ctrl[1].tlp_dropped;
    end
  end

 // Count dropped Non-Posted TRGT1/0 TLPs
  always_comb begin : proc_comb_all_rx_tlp_np_dropped
    s_all_trgt_dropped_cnt_np = 0;
    for (int trgt=0; trgt<N_TRGT1_INTF; trgt++) begin
      if (s_all_trgt_dropped_np[trgt]) begin
        s_all_trgt_dropped_cnt_np = s_all_trgt_dropped_cnt_np + 1;
      end
    end
  end

 // Count Posted TRGT0 TLPs
  always_comb begin : proc_comb_all_trgt0_cnt_p
    s_all_trgt0_cnt_p = 0;
    for (int trgt=0; trgt<N_TRGT1_INTF; trgt++) begin
      if (s_all_trgt0_p[trgt]) begin
        s_all_trgt0_cnt_p = s_all_trgt0_cnt_p + 1;
      end
    end
  end


  // ------------------------------------------------------------------------------------
  // Count per FC received TLPs, i.e. TLPs popped fron the Rx Queues.
  always_comb begin : proc_comb_all_rx_tlps
    // Convert array to vector
    for (int vc=0; vc<NVC; vc++) begin
      for (int rd_port=0; rd_port<FORMQ_RD_PORTS; rd_port++) begin
        s_all_rx_p[vc*FORMQ_RD_PORTS + rd_port] = form_filt_hv_p[vc][rd_port] && !filt_form_halt_in_p[vc];
        s_all_rx_np[vc*FORMQ_RD_PORTS + rd_port] = form_filt_hv_np[vc][rd_port] && !filt_form_halt_in_np[vc];
        s_all_rx_cpl[vc*FORMQ_RD_PORTS + rd_port] = form_filt_hv_cpl[vc][rd_port] && !filt_form_halt_in_cpl[vc];
      end
    end
  end

  always_comb begin : proc_comb_all_rx_cnt_tlp
    s_all_rx_cnt_p = 0;
    s_all_rx_cnt_np = 0;
    s_all_rx_cnt_cpl = 0;
    for (int rd_port=0; rd_port<TOTAL_NUM_FORMQ_RD_PORTS; rd_port++) begin
      if (s_all_rx_p[rd_port]) begin
        s_all_rx_cnt_p = s_all_rx_cnt_p + 1;
      end
      if (s_all_rx_np[rd_port]) begin
        s_all_rx_cnt_np = s_all_rx_cnt_np + 1;
      end
      if (s_all_rx_cpl[rd_port]) begin
        s_all_rx_cnt_cpl = s_all_rx_cnt_cpl + 1;
      end
    end
  end

  // ------------------------------------------------------------------------------------
  // Count per FC TLPs sent to application
  always_ff @(posedge radm_clk_ug or negedge core_rst_n) begin : proc_all_trgt_eot
    if(!core_rst_n) begin
      r_all_trgt1_eot_p <= #TP 0;
      r_all_trgt1_eot_np <= #TP 0;
      r_all_trgt1_eot_cpl <= #TP 0;
    end else begin
      for (int trgt=0; trgt<N_TRGT1_INTF; trgt++) begin
        r_all_trgt1_eot_p <= #TP radm_trgt1_intf_eot_p[trgt] && !trgt1_radm_intf_halt_p[trgt]; 
        r_all_trgt1_eot_np <= #TP radm_trgt1_intf_eot_np[trgt] && !trgt1_radm_intf_halt_np[trgt]; 
        r_all_trgt1_eot_cpl <= #TP radm_trgt1_intf_eot_cpl[trgt] && !trgt1_radm_intf_halt_cpl[trgt]; 
      end
    end
  end

  always_comb begin : proc_comb_all_trgt_cnt_tlp
    s_all_trgt1_cnt_p = 0;
    s_all_trgt1_cnt_np = 0;
    s_all_trgt1_cnt_cpl = 0;
    for (int trgt=0; trgt<N_TRGT1_INTF; trgt++) begin
      if (|r_all_trgt1_eot_p[trgt]) begin
        s_all_trgt1_cnt_p = s_all_trgt1_cnt_p + 1;
      end
      if (|r_all_trgt1_eot_np[trgt]) begin
        s_all_trgt1_cnt_np = s_all_trgt1_cnt_np + 1;
      end
      if (|r_all_trgt1_eot_cpl[trgt]) begin
        s_all_trgt1_cnt_cpl = s_all_trgt1_cnt_cpl + 1;
      end
    end
  end

  // ------------------------------------------------------------------------------------
  // Count per FC pending TLPs
  // P/CPL: All Rx TLPs are sent to TRGT1 including tlp_abort/dllp_abort TLPs.
  // P TLPs routed to TRGT0 are also sent to TRGT1 (marked with TLP abort).
  // Independent pending P TLPs trackers used to track Rx TLPs against TRGT1
  // and TLPs routed to TRGT0 by the Demux against TLPs sent to the LBC.
  // NP: All Rx TLPs are sent to TRGT1 or TRGT0 or dropped internally.  
  // A common pending TLP tracker is used to check Rx TLPs against
  // TRGT/Dropped TLPs. 
  // CPL: All Rx TLPs are sent to TRGT1 including tlp_abort/dllp_abort TLPs.
  // Pending CPL tracker used to track Rx TLPs against TRGT1.
  always_ff @(posedge radm_clk_ug or negedge core_rst_n) begin : proc_pending_cnt_trgt
    if(!core_rst_n) begin
      r_pending_cnt_trgt1_p  <= #TP 0;
      r_pending_cnt_trgt0_p  <= #TP 0;
      r_pending_cnt_trgt_np  <= #TP 0;
      r_pending_cnt_trgt_cpl <= #TP 0;
    end else begin

      // Pending Posted TRGT1 Count, Qmode = C/T
      if (|s_all_rx_p) begin
        r_pending_cnt_trgt1_p <= #TP MAX_TRGT_TLP_PEND_CNT_WD'(r_pending_cnt_trgt1_p + s_all_rx_cnt_p - s_all_trgt1_cnt_p);
      end else if (|r_all_trgt1_eot_p) begin
        r_pending_cnt_trgt1_p <= #TP MAX_TRGT_TLP_PEND_CNT_WD'(r_pending_cnt_trgt1_p - r_all_trgt1_eot_p);
      end

      // Pending Posted TRGT0 Count
      if (|s_all_trgt0_cnt_p) begin
        r_pending_cnt_trgt0_p <= #TP MAX_TRGT_TLP_PEND_CNT_WD'(r_pending_cnt_trgt0_p + s_all_trgt0_cnt_p - radm_trgt0_p);
      end else begin
        r_pending_cnt_trgt0_p <= #TP MAX_TRGT_TLP_PEND_CNT_WD'(r_pending_cnt_trgt0_p - radm_trgt0_p);
      end

      // Pending Non-Posted TRGT0/1 Count 
      if (|s_all_rx_np) begin
        r_pending_cnt_trgt_np <= #TP MAX_TRGT_TLP_PEND_CNT_WD'(r_pending_cnt_trgt_np + s_all_rx_cnt_np - s_all_trgt1_cnt_np - s_all_trgt_dropped_cnt_np - radm_trgt0_np);
      end else if (|r_all_trgt1_eot_np) begin
        r_pending_cnt_trgt_np <= #TP MAX_TRGT_TLP_PEND_CNT_WD'(r_pending_cnt_trgt_np - s_all_trgt1_cnt_np - s_all_trgt_dropped_cnt_np - radm_trgt0_np);
      end else if (|s_all_trgt_dropped_cnt_np) begin
        r_pending_cnt_trgt_np <= #TP MAX_TRGT_TLP_PEND_CNT_WD'(r_pending_cnt_trgt_np - s_all_trgt_dropped_cnt_np - radm_trgt0_np);
      end else begin
        r_pending_cnt_trgt_np <= #TP MAX_TRGT_TLP_PEND_CNT_WD'(r_pending_cnt_trgt_np - radm_trgt0_np);
      end

      // Pending Completion TRGT1 Count, Qmode=C/T/ or Bypass
      if (|s_all_rx_cpl) begin
        r_pending_cnt_trgt_cpl <= #TP MAX_TRGT_TLP_PEND_CNT_WD'(r_pending_cnt_trgt_cpl + s_all_rx_cnt_cpl - s_all_trgt1_cnt_cpl);
      end else if (|r_all_trgt1_eot_cpl) begin
        r_pending_cnt_trgt_cpl <= #TP MAX_TRGT_TLP_PEND_CNT_WD'(r_pending_cnt_trgt_cpl - r_all_trgt1_eot_cpl);
      end

    end
  end

  always_ff @(posedge radm_clk_ug or negedge core_rst_n) begin : proc_trgt1_pending
    if(!core_rst_n) begin
      r_trgt_pending  <= #TP 0;
      r_trgt1_p_pending <= #TP 0;
      r_trgt1_p_idle <= #TP 1'b1;
    end else begin
      r_trgt_pending  <= #TP |r_pending_cnt_trgt1_p || |r_pending_cnt_trgt0_p ||
                             |r_pending_cnt_trgt_np ||
                             |r_pending_cnt_trgt_cpl;

      r_trgt1_p_pending <= #TP |r_pending_cnt_trgt1_p;

      r_trgt1_p_idle <= #TP tpidl_trgt1_p_idle;
    end
  end

  // ------------------------------------------------------------------------------------
  // Debounce TRGT1 Posted pending signal
  radm_idle_detect
   #(
    .DEPTH  (PST_RX_Q_LATENCY)
    ) u_tpidl ( // TRGT1 Posted Idle Detect
    .clk        (radm_clk_ug),
    .rst_n      (core_rst_n),
    .req        (radm_formq_not_empty[0][0]), // 1: VC 0 Posted Pending
    .pending    (r_trgt1_p_pending),
    .radm_idle  (tpidl_trgt1_p_idle)
  );

// -----------------------------------------------------------------------------
// Idleness detection for the CPL LUT the LUT is busy when the CPL LUT pending flags are asserted
// -----------------------------------------------------------------------------
logic cpl_lut_busy;
logic radm_cpl_lut_idle;

assign cpl_lut_busy = (|radm_cpl_lut_valid) || radm_cpl_lut_busy; 

// Shift register for idle detection
radm_idle_detect
 #(
  .DEPTH  (CPL_LUT_LATENCY)
  ) u_cpl_lut_idle_detect (
  .clk        (radm_clk_ug),
  .rst_n      (core_rst_n),
  .req        (radm_cpl_lut_pending),
  .pending    (cpl_lut_busy),
  .radm_idle  (radm_cpl_lut_idle)
);

// Receiver busy indication if formation queue is not empty
// or if a transfer is pending on the TRGT0/TRGT1 Interfaces
assign rx_busy = (r_trgt_pending) || |radm_formq_not_empty
                 || (! hdr_log_idle)
                 || radm_rtlh_crd_pending;
  
// Shift register for idle detection
radm_idle_detect
 #(
  .DEPTH  (RTLH_QUEUE_LATENCY)
  ) u_rx_idle_detect (
  .clk        (radm_clk_ug),
  .rst_n      (core_rst_n),
  .req        (rtlh_radm_pending),
  .pending    (rx_busy),
  .radm_idle  (radm_rx_idle)
);


// RADM idle indication depends on pending TLP count, formation queue idle and CPL LUT ideal
assign int_radm_idle =                          radm_rx_idle 
 && radm_cpl_lut_idle;

assign int_radm_clk_en  = clock_gating_en ? !int_radm_idle : 1'b1;

always_ff @(posedge radm_clk_ug or negedge core_rst_n) begin : idle_PROC
  if(!core_rst_n) begin
    int_radm_clk_en_r <= #TP 1'b1;
    int_radm_idle_r   <= #TP 1'b0;
  end else begin
    int_radm_clk_en_r <= #TP int_radm_clk_en;
    int_radm_idle_r   <= #TP int_radm_idle;
  end
end : idle_PROC

// --------------------------------------------------------------------------------------
// Assign Outputs
assign radm_clk_en = int_radm_clk_en_r;
assign radm_idle   = int_radm_idle_r;
assign radm_trgt1_p_pending = !r_trgt1_p_idle;

`ifndef SYNTHESIS
`endif // !SYNTHESIS

endmodule
