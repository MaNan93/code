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
// ---   $DateTime: 2023/09/27 02:27:25 $
// ---   $Revision: #2 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/ltssm_latency_tracker.sv#2 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// LTSSM state transition latency tracking module 
// Description: Implements LTSSM state transition laltency tracking function that controls
// the tracking FSMs based on the configurations. 
// -------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"

module ltssm_latency_tracker
  import DWC_pcie_core_pkg::pm_cdm_state_trans_track_t;
  import DWC_pcie_core_pkg::latency_tracking_status_e;
  import DWC_pcie_core_pkg::IDLE;
  import DWC_pcie_core_pkg::STARTED;
  import DWC_pcie_core_pkg::DONE;
  import DWC_pcie_core_pkg::ERROR;
  // Parameters
#(
  parameter PL_AUX_CLK_FREQ_WD = `CX_PL_AUX_CLK_FREQ_WD
) (
  // Inputs
  input  aux_clk,
  input  pwr_rst_n,
  input  pm_perst_powerdown,
  input  aux_clk_active,
  input  [2:0] current_data_rate,                              // Data rate
  input  [PL_AUX_CLK_FREQ_WD-1:0] pm_pl_aux_clk_freq,          // Aux clock frequency
  input  [4:0] cdm_pm_state_trans_tracker,                     // LTSSM state transitions to be tracked
  input  smlh_pm_state_trans1_flag,                            // Indicates the start/end of Recovery->L0 due to Framing Err 
                                                               // or Software directed while in L0
  input  smlh_pm_state_trans2_flag,                            // Indicate the start/end of L0p - Electrical idle to start of
                                                               // Data Stream on Lane on an upconfig
  input  pm_state_trans3_flag,                                 // Indicates the start/end of L1->L0 transition.
  input  pm_state_trans4_flag,                                 // Indicates the start/end of L1.1->L0 transition.
  input  pm_state_trans5_flag,                                 // Indicates the start/end of L1.2->L0 transition.
  // Outputs
  output pm_cdm_state_trans_track_t pm_cdm_state_trans_tracking //LTSSM state transition tracking status and latency
);

parameter TP = `TP;  // Clock to Q delay (simulator insurance)

/////////////////////////////////////////////////////////////////
// States definition, measurement enables
latency_tracking_status_e ltssm_tracking_status;
logic [15:0]  ltssm_latency_value;
logic ltssm_track_en, ltssm_track_start, ltssm_track_end;
logic smlh_pm_state_trans1_flag_d;
logic smlh_pm_state_trans2_flag_d;
logic pm_state_trans3_flag_d;
logic pm_state_trans4_flag_d;
logic pm_state_trans5_flag_d;
logic smlh_pm_state_trans1_start;
logic smlh_pm_state_trans1_end;
logic smlh_pm_state_trans2_start;
logic smlh_pm_state_trans2_end;
logic pm_state_trans3_start;
logic pm_state_trans3_end;
logic pm_state_trans4_start;
logic pm_state_trans4_end;
logic pm_state_trans5_start;
logic pm_state_trans5_end;


/////////////////////////////////////////////////////////////////
// LTSSM latency tracking control
//
// The following assumption must be gauranteed by CDM
// 1. Only one bit in cdm_pm_state_trans_tracker is asserted.
// 2. cdm_pm_state_trans_tracker is only enabled when "Flit Latency Measurement Enable" is 1.
// 3. Lower bits in cdm_pm_state_trans_tracker always has higher priority.

// LTSSM latency tracking is enabled when any events is required at IDLE.
assign ltssm_track_en = |cdm_pm_state_trans_tracker;

// Indicate when the specific event starts (only when the measurement for the event is enabled)
assign ltssm_track_start =    (cdm_pm_state_trans_tracker[0] && smlh_pm_state_trans1_start)
                           || (cdm_pm_state_trans_tracker[1] && smlh_pm_state_trans2_start)
                           || (cdm_pm_state_trans_tracker[2] && pm_state_trans3_start)
                           || (cdm_pm_state_trans_tracker[3] && pm_state_trans4_start)
                           || (cdm_pm_state_trans_tracker[4] && pm_state_trans5_start);

// Indicate when the specific event ends (only when the measurement for the event is enabled)
assign ltssm_track_end   =    (cdm_pm_state_trans_tracker[0] && smlh_pm_state_trans1_end)
                           || (cdm_pm_state_trans_tracker[1] && smlh_pm_state_trans2_end)
                           || (cdm_pm_state_trans_tracker[2] && pm_state_trans3_end)
                           || (cdm_pm_state_trans_tracker[3] && pm_state_trans4_end)
                           || (cdm_pm_state_trans_tracker[4] && pm_state_trans5_end);

/////////////////////////////////////////////////////////////////
// Detect the posedge (start) and negedge (end) of each event
always @(posedge aux_clk or negedge pwr_rst_n) begin : latch_state_trans_flag
  if(!pwr_rst_n) begin
    smlh_pm_state_trans1_flag_d <= #TP 'b0;
    smlh_pm_state_trans2_flag_d <= #TP 'b0;
    pm_state_trans3_flag_d      <= #TP 'b0;
    pm_state_trans4_flag_d      <= #TP 'b0;
    pm_state_trans5_flag_d      <= #TP 'b0;
  end else begin
    smlh_pm_state_trans1_flag_d <= #TP smlh_pm_state_trans1_flag;
    smlh_pm_state_trans2_flag_d <= #TP smlh_pm_state_trans2_flag;
    pm_state_trans3_flag_d      <= #TP pm_state_trans3_flag;
    pm_state_trans4_flag_d      <= #TP pm_state_trans4_flag;
    pm_state_trans5_flag_d      <= #TP pm_state_trans5_flag;
  end
end : latch_state_trans_flag

// Detect the start of each event
assign smlh_pm_state_trans1_start = smlh_pm_state_trans1_flag && !smlh_pm_state_trans1_flag_d;
assign smlh_pm_state_trans2_start = smlh_pm_state_trans2_flag && !smlh_pm_state_trans2_flag_d;
assign pm_state_trans3_start = pm_state_trans3_flag && !pm_state_trans3_flag_d;
assign pm_state_trans4_start = pm_state_trans4_flag && !pm_state_trans4_flag_d;
assign pm_state_trans5_start = pm_state_trans5_flag && !pm_state_trans5_flag_d;
// Detect the end of each event
assign smlh_pm_state_trans1_end = !smlh_pm_state_trans1_flag && smlh_pm_state_trans1_flag_d;
assign smlh_pm_state_trans2_end = !smlh_pm_state_trans2_flag && smlh_pm_state_trans2_flag_d;
assign pm_state_trans3_end = !pm_state_trans3_flag && pm_state_trans3_flag_d;
assign pm_state_trans4_end = !pm_state_trans4_flag && pm_state_trans4_flag_d;
assign pm_state_trans5_end = !pm_state_trans5_flag && pm_state_trans5_flag_d;

/////////////////////////////////////////////////////////////////
// LTSSM Latency Tracking State Machine
ltssm_latency_tracker_fsm
 
#(  
  .PL_AUX_CLK_FREQ_WD (PL_AUX_CLK_FREQ_WD)
) u_ltssm_latency_tracker_fsm (
  // Inputs
  .aux_clk                 (aux_clk),
  .pwr_rst_n               (pwr_rst_n),
  .pm_perst_powerdown      (pm_perst_powerdown), 
  .aux_clk_active          (aux_clk_active),
  .ltssm_track_en          (ltssm_track_en),
  .ltssm_start_tracing     (ltssm_track_start),
  .ltssm_end_tracing       (ltssm_track_end),
  .current_data_rate       (current_data_rate),
  .pm_pl_aux_clk_freq      (pm_pl_aux_clk_freq),
  // Outputs
  .ltssm_tracking_state    (ltssm_tracking_status),
  .ltssm_latency_value     (ltssm_latency_value)
);
/////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////
// Report Latency
always @(posedge aux_clk or negedge pwr_rst_n) begin : latency_report
  if(!pwr_rst_n) begin
     pm_cdm_state_trans_tracking.state_trans1_status <= #TP IDLE;
     pm_cdm_state_trans_tracking.state_trans2_status <= #TP IDLE;
     pm_cdm_state_trans_tracking.state_trans3_status <= #TP IDLE;
     pm_cdm_state_trans_tracking.state_trans4_status <= #TP IDLE;
     pm_cdm_state_trans_tracking.state_trans5_status <= #TP IDLE;
     pm_cdm_state_trans_tracking.state_trans_latency <= #TP 'b0;
  end else if (pm_perst_powerdown) begin
     pm_cdm_state_trans_tracking.state_trans1_status <= #TP IDLE;
     pm_cdm_state_trans_tracking.state_trans2_status <= #TP IDLE;
     pm_cdm_state_trans_tracking.state_trans3_status <= #TP IDLE;
     pm_cdm_state_trans_tracking.state_trans4_status <= #TP IDLE;
     pm_cdm_state_trans_tracking.state_trans5_status <= #TP IDLE;
     pm_cdm_state_trans_tracking.state_trans_latency <= #TP 'b0;   
  end else if (ltssm_tracking_status == ERROR) begin
    if (cdm_pm_state_trans_tracker[0]) begin
       pm_cdm_state_trans_tracking.state_trans1_status <= #TP ERROR;
    end else if (cdm_pm_state_trans_tracker[1]) begin
       pm_cdm_state_trans_tracking.state_trans2_status <= #TP ERROR;
    end else if (cdm_pm_state_trans_tracker[2]) begin
       pm_cdm_state_trans_tracking.state_trans3_status <= #TP ERROR;
    end else if (cdm_pm_state_trans_tracker[3]) begin
       pm_cdm_state_trans_tracking.state_trans4_status <= #TP ERROR;
    end else if (cdm_pm_state_trans_tracker[4]) begin
       pm_cdm_state_trans_tracking.state_trans5_status <= #TP ERROR;
    end 
     pm_cdm_state_trans_tracking.state_trans_latency <= #TP 16'hffff;
  end else if (ltssm_tracking_status == DONE) begin
    if (cdm_pm_state_trans_tracker[0]) begin
       pm_cdm_state_trans_tracking.state_trans1_status <= #TP DONE;
    end else if (cdm_pm_state_trans_tracker[1]) begin
       pm_cdm_state_trans_tracking.state_trans2_status <= #TP DONE;
    end else if (cdm_pm_state_trans_tracker[2]) begin
       pm_cdm_state_trans_tracking.state_trans3_status <= #TP DONE;
    end else if (cdm_pm_state_trans_tracker[3]) begin
       pm_cdm_state_trans_tracking.state_trans4_status <= #TP DONE;
    end else if (cdm_pm_state_trans_tracker[4]) begin
       pm_cdm_state_trans_tracking.state_trans5_status <= #TP DONE;
    end
    pm_cdm_state_trans_tracking.state_trans_latency <=  #TP ltssm_latency_value;
  end else if (ltssm_tracking_status == STARTED) begin
    if (cdm_pm_state_trans_tracker[0]) begin
       pm_cdm_state_trans_tracking.state_trans1_status <= #TP STARTED;
    end else if (cdm_pm_state_trans_tracker[1]) begin
       pm_cdm_state_trans_tracking.state_trans2_status <= #TP STARTED;
    end else if (cdm_pm_state_trans_tracker[2]) begin
       pm_cdm_state_trans_tracking.state_trans3_status <= #TP STARTED;
    end else if (cdm_pm_state_trans_tracker[3]) begin
       pm_cdm_state_trans_tracking.state_trans4_status <= #TP STARTED;
    end else if (cdm_pm_state_trans_tracker[4]) begin
       pm_cdm_state_trans_tracking.state_trans5_status <= #TP STARTED;
    end
    pm_cdm_state_trans_tracking.state_trans_latency <= #TP 'b0;
  end else begin
     pm_cdm_state_trans_tracking.state_trans1_status <= #TP IDLE;
     pm_cdm_state_trans_tracking.state_trans2_status <= #TP IDLE;
     pm_cdm_state_trans_tracking.state_trans3_status <= #TP IDLE;
     pm_cdm_state_trans_tracking.state_trans4_status <= #TP IDLE;
     pm_cdm_state_trans_tracking.state_trans5_status <= #TP IDLE;
     pm_cdm_state_trans_tracking.state_trans_latency <= #TP 'b0;
  end
end : latency_report
/////////////////////////////////////////////////////////////////

endmodule
