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
// ---    $Revision: #14 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/pipe_regif_sync.sv#14 $
// --------------------------------------------------------------------------------------------
// --- Module Description: Synchronizer between pipe_regif and cdm/cx_pl
// --------------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"

module pipe_regif_sync
  import DWC_pcie_core_pkg::ltssm_state_e;
  import DWC_pcie_core_pkg::S_DETECT_QUIET;
  import DWC_pcie_core_pkg::S_PRE_DETECT_QUIET;
  import DWC_pcie_core_pkg::S_RCVRY_SPEED;
  import DWC_pcie_core_pkg::S_L0;
  import DWC_pcie_core_pkg::S_L123_SEND_EIDLE;
  import DWC_pcie_core_pkg::S_L1_IDLE;
  import DWC_pcie_core_pkg::S_L2_IDLE;
  import DWC_pcie_core_pkg::S_LPBK_EXIT_TIMEOUT;
#(
  parameter  NL = `CX_NL,
  parameter  RATE_WIDTH = `CX_PHY_RATE_WD,
  parameter  TX_DEEMPH_WD = `CX_PHY_TXDEEMPH_WD,
  parameter  INST = 0
) (
// ------------ inputs ----------------
  input logic                     clk,
  input logic                     rst_n,
  input logic                     core_clk,
  input logic                     core_rst_n,
  input logic                     sticky_rst_n,
  input logic [NL-1:0]            pipe_regif_busy,
  input ltssm_state_e             smlh_ltssm_state,
  input logic [2:0]               current_data_rate,
  input logic [NL-1:0]            laneflip_no_turnoff_lanes,
  input logic [NL-1:0]            pipe_txcompliance,
  input logic [NL-1:0]            pipe_txelecidle,
  input logic [RATE_WIDTH-1:0]    pre_pipe_rate,
  input logic [3:0]               cfg_rx_msgbus_write_buffer_depth,
  input logic                     cfg_pam4_restricted_levels_requirement,
  input logic [TX_DEEMPH_WD-1:0]  pre_lpif_txdeemph,
// ------------ outputs ---------------
  output logic [2:0]              pipe_rate,
  output logic [3:0]              rx_msgbus_write_buffer_depth,
  output logic                    pam4_restricted_levels_requirement,
  output logic [(18*NL)-1:0]      lpif_txdeemph,
  output logic [NL-1:0]           lpif_txdeemph_dvalid,
  output logic                    clk_en,
  output logic                    pipe_regif_all_idle,
  output logic [NL-1:0]           lpif_mst_dvalid
);

  localparam  TP = `TP;

// --------------------------------------------------------------------------------
//  Generate pipe_regif control signal
// --------------------------------------------------------------------------------
  logic [NL-1:0]  pipe_turnoff_lanes;
  assign clk_en = 1'h1;

  always_comb begin: pipe_rate_PROC
    pipe_rate = '0;
    pipe_rate[RATE_WIDTH-1:0] = pre_pipe_rate;
  end: pipe_rate_PROC

  // Synchronize pipe_txcompliance to clock of pipe_regif.
  // Turn-off is released at Detect.Quiet and lpif_mst_dvalid is low at the state.
  always_ff @(posedge core_clk or negedge core_rst_n) begin: pipe_turnoff_lanes_PROC
    if(!core_rst_n) begin
      pipe_turnoff_lanes <= #TP '0;
    end
    else begin
      pipe_turnoff_lanes <= #TP pipe_txcompliance & pipe_txelecidle;
    end
  end: pipe_turnoff_lanes_PROC

  logic  rate_chg;
  assign rate_chg = (current_data_rate != pipe_rate);

  logic  prev_detect_quiet;

  always_ff @(posedge core_clk or negedge core_rst_n) begin: prev_detect_quiet_PROC
    if(!core_rst_n) begin
      prev_detect_quiet <= #TP 1'h0;
    end
    else if(smlh_ltssm_state == S_DETECT_QUIET || smlh_ltssm_state == S_LPBK_EXIT_TIMEOUT || smlh_ltssm_state == S_L2_IDLE) begin
      prev_detect_quiet <= #TP 1'h1;
    end
    else if(smlh_ltssm_state != S_PRE_DETECT_QUIET || rate_chg) begin
      prev_detect_quiet <= #TP 1'h0;
    end
  end: prev_detect_quiet_PROC

  always_comb begin: lpif_mst_dvalid_PROC
    lpif_mst_dvalid = '1;
    case(smlh_ltssm_state)
      S_L1_IDLE,
      S_L2_IDLE,
      S_DETECT_QUIET: lpif_mst_dvalid = '0;
      S_PRE_DETECT_QUIET: lpif_mst_dvalid = (prev_detect_quiet) ? '0 : '1;
    endcase
    if(rate_chg) begin
      lpif_mst_dvalid = '0;
    end
    for(int i = 0; i < NL; i++) begin
      if(pipe_turnoff_lanes[i]) begin
        lpif_mst_dvalid[i] = 1'h0;
      end
    end
  end: lpif_mst_dvalid_PROC

  always_comb begin: lpif_txdeemph_PROC
    for(int i = 0; i < NL; i++) begin
      lpif_txdeemph[(18*i)+:18] = {16'h0, pre_lpif_txdeemph[1:0]};
    end
    lpif_txdeemph = pre_lpif_txdeemph;
  end

  always_comb begin: lpif_txdeemph_dvalid_PROC
    lpif_txdeemph_dvalid = '1;
    for(int i = 0; i < NL; i++) begin
      if((smlh_ltssm_state == S_RCVRY_SPEED) && (current_data_rate >= `GEN3_RATE)) begin
        lpif_txdeemph_dvalid[i] = (lpif_txdeemph[(18*i)+:18] != 'h0);
      end
    end
  end: lpif_txdeemph_dvalid_PROC

  logic  rate_chg_d;
  assign pipe_regif_all_idle = !(rate_chg_d || (|pipe_regif_busy));

  // It takes 2-cycles to assert pipe_regif_busy after Legacy Pin Interface signals are changed.
  delay_n
   #(
    .N(2),
    .WD(1),
    .RESETVAL('0)
  ) u_delay_n (
    .clk(clk),
    .rst_n(rst_n),
    .clear('0),
    .din(rate_chg),
    .dout(rate_chg_d)
  );

// --------------------------------------------------------------------------------
//  Data Transfer: cdm to pipe_regif
// --------------------------------------------------------------------------------
  function automatic int  get_clk_division();
    int  ret;
    ret = 1;
    return ret;
  endfunction

  always_ff @(posedge core_clk or negedge sticky_rst_n) begin: rx_msgbus_write_buffer_depth_PROC
    if(!sticky_rst_n) begin
      rx_msgbus_write_buffer_depth <= #TP `DEFAULT_RX_MESSAGE_BUS_WRITE_BUFFER_DEPTH;
    end
    else begin
      rx_msgbus_write_buffer_depth <= #TP cfg_rx_msgbus_write_buffer_depth;
    end
  end: rx_msgbus_write_buffer_depth_PROC

  always_ff @(posedge core_clk or negedge sticky_rst_n) begin: pam4_restricted_levels_requirement_PROC
    if(!sticky_rst_n) begin
      pam4_restricted_levels_requirement <= #TP `DEFAULT_PAM4_RESTRICTED_LEVELS_REQUIREMENT;
    end
    else begin
      pam4_restricted_levels_requirement <= #TP cfg_pam4_restricted_levels_requirement;
    end
  end: pam4_restricted_levels_requirement_PROC



endmodule: pipe_regif_sync
