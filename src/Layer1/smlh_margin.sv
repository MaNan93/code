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
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/smlh_margin.sv#7 $
// -------------------------------------------------------------------------
// --- Module Description: Receiver Margining adapter
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module smlh_margin
#(
    parameter INST = 0,   // The uniquifying parameter for each port logic instance.
    parameter TP   = `TP, // Clock to Q delay (simulator insurance)
    parameter NL = `CX_NL, // Max number of lanes supported
    parameter NB = `CX_NB  // Number of symbols (bytes) per clock cycle
)
                   (
    // Input
    input                   core_clk,                       // Core Clock
    input                   core_rst_n,                     // Core Reset
    input   [2:0]           current_data_rate,              // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=gen3, 3=gen4
    input                   smlh_in_l0,                     // LTSSM is in L0
    input                   smlh_in_rcvryspeed_predetect,   // LTSSM is in Rcvry.Speed or Pre.Detect.Quiet
    input                   smlh_retimer_pre_detected,      // Retimer was present during the latest Config.Complete
    // Cdm                                                  
    input                   cfg_upstream_port,              // when asserted, indicates that this core function as a upstream port
    input   [(NL*16)-1:0]   cfg_margin_control,             // Margining Control [2:0] Receiver Number[5:3]Margin Type[6]Usage Molde[7]Rsvd[15:8]Margin Payload
    // Rmlh                                                 
    input                   rmlh_deskew_datastream,
    input   [(NL*16)-1:0]   rmlh_deskew_ctlskp_info,        // received control SKP OS info {4N+3,4N+2}
    input   [NL-1:0]        rmlh_deskew_ctlskp_rcvd,        // received flag of the Control SKP OS
    input   [(NL*5)-1:0]    rmlh_deskew_ctlskp_err,         // compare error status  data parity/margin crc/margin parity
                                                            // [0] parity bit in bit[7] of symbol#4N+1 
                                                            // [1] first retime data parity bit in bit[6] of symbol#4N+1
                                                            // [2] second retime data parity bit in bit[5] of symbol#4N+1 
                                                            // [3] Margin CRC bit in bits[4:0] of symbol#4N+1
                                                            // [4] margin parity bit in bit[7] of symbol#4N+2
    // Cdm Margining Parameter
    input   [5:0]           cfg_margin_num_timing_steps,       
    input   [5:0]           cfg_margin_max_timing_offset,
    input   [6:0]           cfg_margin_num_voltage_steps,
    input   [5:0]           cfg_margin_max_voltage_offset,
    input   [5:0]           cfg_margin_sample_rate_voltage,
    input   [5:0]           cfg_margin_sample_rate_timing,
    input   [4:0]           cfg_margin_maxlanes,
    input                   cfg_margin_voltage_supported,
    input                   cfg_margin_ind_left_right_timing,
    input                   cfg_margin_ind_up_down_voltage,
    input                   cfg_margin_sample_reporting_method,
    input                   cfg_margin_ind_error_sampler,
    input   [3:0]           cfg_rx_message_bus_write_buffer_depth,
    input   [NL-1:0]        power_saving_lanes_active,
    // Pipe
    input   [NL-1:0]        rpipe_margin_status ,
    input   [NL-1:0]        rpipe_margin_nak,
    input   [(NL*6)-1:0]    rpipe_margin_error_cnt ,
    input   [(NL*7)-1:0]    rpipe_margin_sampl_cnt ,
    // Xmlh 
    input                   xmtbyte_ctlskip_sent,           // Send flag of the Control SKP OS
    // Output
    // LTSSM
    output wire             smlh_margin_pipe_idle,
    // Cdm
    output  [(NL*16)-1:0]   smlh_margin_status,
    output  [NL-1:0]        smlh_margin_status_valid,
    // Pipe
    output  [(NL*3)-1:0]    smlh_margin_cmd,
    output  [(NL*7)-1:0]    smlh_margin_offset,
    output  [(NL*2)-1:0]    smlh_margin_clr_error_log,      // [0] error cnt rst, [1] sample cnt rst
    // Xmlh
    output  [(NL*16)-1:0]   smlh_ctlskp_info                // Tx parameter of the Control SKP OS
);

  wire    [NL-1:0]        smlh_margin_en;
  wire    [NL-1:0]        tmp_smlh_margin_pipe_idle;

  assign smlh_margin_pipe_idle = &tmp_smlh_margin_pipe_idle;

  smlh_margin_slv
   #(.INST(INST)) u_smlh_margin_slv [NL-1:0] (
      // Inputs
      .core_clk                           (core_clk),
      .core_rst_n                         (core_rst_n),
      .current_data_rate                  (current_data_rate),
      .smlh_in_l0                         (smlh_in_l0),
      .smlh_in_rcvryspeed_predetect       (smlh_in_rcvryspeed_predetect),
      .smlh_retimer_pre_detected          (smlh_retimer_pre_detected),
      // Cdm                              
      .cfg_upstream_port                  (cfg_upstream_port),
      .cfg_margin_control                 (cfg_margin_control[(NL*16)-1:0]),
      .cfg_margin_num_timing_steps        (cfg_margin_num_timing_steps),
      .cfg_margin_max_timing_offset       (cfg_margin_max_timing_offset),
      .cfg_margin_num_voltage_steps       (cfg_margin_num_voltage_steps),
      .cfg_margin_max_voltage_offset      (cfg_margin_max_voltage_offset),
      .cfg_margin_sample_rate_voltage     (cfg_margin_sample_rate_voltage),
      .cfg_margin_sample_rate_timing      (cfg_margin_sample_rate_timing),
      .cfg_margin_maxlanes                (cfg_margin_maxlanes),
      .cfg_margin_voltage_supported       (cfg_margin_voltage_supported),
      .cfg_margin_ind_left_right_timing   (cfg_margin_ind_left_right_timing),
      .cfg_margin_ind_up_down_voltage     (cfg_margin_ind_up_down_voltage),
      .cfg_margin_sample_reporting_method (cfg_margin_sample_reporting_method),
      .cfg_margin_ind_error_sampler       (cfg_margin_ind_error_sampler),
      .cfg_rx_message_bus_write_buffer_depth (cfg_rx_message_bus_write_buffer_depth),
      .power_saving_lanes_active          (power_saving_lanes_active[NL-1:0]),
      // Xmlh                             
      .xmtbyte_ctlskip_sent               (xmtbyte_ctlskip_sent),
      // Rmlh                             
      .rmlh_deskew_datastream             (rmlh_deskew_datastream),
      .rmlh_deskew_ctlskp_info            (rmlh_deskew_ctlskp_info[(NL*16)-1:0]),
      .rmlh_deskew_ctlskp_rcvd            (rmlh_deskew_ctlskp_rcvd[NL-1:0]),
      .rmlh_deskew_ctlskp_err             (rmlh_deskew_ctlskp_err[(NL*5)-1:0]),
      // Pipe
      .rpipe_margin_status                (rpipe_margin_status[NL-1:0]),
      .rpipe_margin_nak                   (rpipe_margin_nak[NL-1:0]),
      .rpipe_margin_error_cnt             (rpipe_margin_error_cnt[(NL*6)-1:0]),
      .rpipe_margin_sampl_cnt             (rpipe_margin_sampl_cnt[(NL*7)-1:0]),
  
      // Outputs
      // LTSSM
      .smlh_margin_pipe_idle              (tmp_smlh_margin_pipe_idle[NL-1:0]),
      // Cdm
      .smlh_margin_status                 (smlh_margin_status[(NL*16)-1:0]),
      .smlh_margin_status_valid           (smlh_margin_status_valid[NL-1:0]),
      // Xmlh
      .smlh_ctlskp_info                   (smlh_ctlskp_info[(NL*16)-1:0]),
      // Pipe
      .smlh_margin_cmd                    (smlh_margin_cmd[(NL*3)-1:0]),
      .smlh_margin_offset                 (smlh_margin_offset [(NL*7)-1:0]),
      .smlh_margin_clr_error_log          (smlh_margin_clr_error_log[(NL*2)-1:0]),
      .smlh_margin_en                     (smlh_margin_en[NL-1:0]));
    
endmodule
