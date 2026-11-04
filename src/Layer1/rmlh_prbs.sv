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
// ---    $DateTime: 2023/12/22 07:15:34 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/rmlh_prbs.sv#4 $
// -------------------------------------------------------------------------
// --- Module Description: PRBS comparison
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"

 module rmlh_prbs 
import DWC_pcie_core_pkg::ltssm_state_e;
import DWC_pcie_core_pkg::S_DETECT_QUIET;
import DWC_pcie_core_pkg::S_LPBK_ACTIVE;
import DWC_pcie_core_pkg::S_LPBK_EXIT_TIMEOUT;
#(
   parameter    TP      = `TP      // Clock to Q delay (simulator insurance)
  ,parameter    NB      = `CX_NB   // Number of symbols (bytes) per clock cycle
  ,parameter    NBK     = `CX_NBK  // Number of symbols (bytes) per clock cycle for datak
  ,parameter    NL      = `CX_NL   // Max number of lanes supported
  ,parameter    AW      = `CX_ANB_WD               // Width of the active number of bytes


  ,parameter   RXSB_WD = `CX_MAC_SB_WD            //Width of phy_mac_rxstartblock per lane
  ,parameter   SH_WD   = `CX_MAC_SH_WD

)
(
// ---- inputs ---------------
   input                    core_clk
  ,input                    core_rst_n

  ,input    [2:0]           current_data_rate
  ,input    ltssm_state_e   smlh_ltssm_state
  ,input    [NL-1:0]        smlh_lanes_active              // Which lanes are actively (begin) configured
  ,input                    ltssm_in_lpbk_active
  ,input                    ltssm_lpbk_master
  ,input   [2:0]         active_nb                      // active number of symbols. bit0=1s, bit1=2s, bit2=4s, bit3=8s

  ,input                         cfg_lpbk_en
  ,input                         cfg_prbs_en
  ,input                         clear_prbs_done
  ,input  [3:0]                  cfg_prbs_lane_sel
  ,input  [NL-1:0]               rpipe_rxdata_dv
  ,input  [(NL*NB*8)-1:0]        rpipe_rxdata
  ,input  [(NL*NBK)-1:0]         rpipe_rxdatak
  ,input  [NL-1:0]               wait4idle_nd
  ,input  [NL-1:0]               descrambled_rxdata_dv
  ,input  [(NL*NB*8)-1:0]        descrambled_rxdata
  ,input  [(NL*NBK)-1:0]         descrambled_rxdatak
  ,input  [(NL*RXSB_WD)-1:0]     descrambled_rxstartblock
  ,input  [NL-1:0][RXSB_WD-1:0][4:0] descrambled_rxdata_osfound

  ,output  logic               rmlh_prbs_done
  ,output  logic               rmlh_prbs_fail
  ,output  logic   [NL-1:0]        prbs_started
  ,output  logic   [NL-1:0][7:0]   prbs_err_cntr
  ,output  logic   [NL-1:0]        prbs_unexp_fail
  ,output  logic   [NL-1:0]    wait4idle
  ,output  logic               prbs_en_int
);

logic [3:0] lane_sel_tmp;
assign lane_sel_tmp = (cfg_prbs_lane_sel<=NL)? cfg_prbs_lane_sel : 4'h0;

logic       ltssm_in_lpbk_active_d;
logic       ltssm_in_lpbk_active_pos;
logic       lpbk_active;
logic       in_loopback;    // ltssm is in S_LPBK_ACTIVE or S_LPBK_EXIT_TIMEOUT

assign lpbk_active = (smlh_ltssm_state == S_LPBK_ACTIVE);
assign in_loopback = ltssm_in_lpbk_active | (smlh_ltssm_state == S_LPBK_EXIT_TIMEOUT);

always_ff @(posedge core_clk, negedge core_rst_n) begin
  if( !core_rst_n )begin
    ltssm_in_lpbk_active_d <= #TP 4'h0;
  end else begin
    ltssm_in_lpbk_active_d <= #TP ltssm_in_lpbk_active;
  end
end

assign ltssm_in_lpbk_active_pos = ltssm_in_lpbk_active && !ltssm_in_lpbk_active_d;
assign ltssm_in_lpbk_active_neg = !ltssm_in_lpbk_active && ltssm_in_lpbk_active_d;

ltssm_state_e     smlh_ltssm_state_ff;

always_ff @(posedge core_clk, negedge core_rst_n) begin
  if( !core_rst_n )begin
    smlh_ltssm_state_ff <= #TP S_DETECT_QUIET;
  end else begin
    smlh_ltssm_state_ff <= #TP smlh_ltssm_state;
  end
end

logic   pre_prbs_en_int;
logic   lpbk_en_int;

always_ff @(posedge core_clk, negedge core_rst_n) begin
  if( !core_rst_n )begin
    lpbk_en_int <= #TP 1'b0;
  end else begin
    if( cfg_lpbk_en && ltssm_lpbk_master )begin
      lpbk_en_int <= #TP 1'b1;
    end else if( rmlh_prbs_done || (!cfg_lpbk_en && !in_loopback) )begin
      lpbk_en_int <= #TP 1'b0;
    end
  end
end

always_ff @(posedge core_clk, negedge core_rst_n) begin
  if( !core_rst_n )begin
    pre_prbs_en_int <= #TP 1'b0;
  end else begin
    if( cfg_prbs_en && ltssm_lpbk_master )begin
      pre_prbs_en_int <= #TP 1'b1;
    end else if( rmlh_prbs_done )begin
      pre_prbs_en_int <= #TP 1'b0;
    end
  end
end

assign prbs_en_int = pre_prbs_en_int && lpbk_en_int;

always_ff @(posedge core_clk, negedge core_rst_n) begin
  if( !core_rst_n )begin
    rmlh_prbs_done <= #TP 1'b0;
  end else begin
    if( clear_prbs_done || ltssm_in_lpbk_active_pos )begin
      rmlh_prbs_done <= #TP 1'b0;
    end else if( pre_prbs_en_int && (smlh_ltssm_state != S_LPBK_EXIT_TIMEOUT) && (smlh_ltssm_state_ff == S_LPBK_EXIT_TIMEOUT) )begin
      rmlh_prbs_done <= #TP 1'b1;
    end
  end
end

always_ff @(posedge core_clk, negedge core_rst_n) begin
  if( !core_rst_n )begin
    rmlh_prbs_fail <= #TP 1'b0;
  end else begin
    if( clear_prbs_done || ltssm_in_lpbk_active_pos )begin
      rmlh_prbs_fail <= #TP 1'b0;
    end else if( (prbs_err_cntr != 0) || (|prbs_unexp_fail) )begin
      rmlh_prbs_fail <= #TP 1'b1;
    end
  end
end


rmlh_prbs_cmp
  u_rmlh_prbs_cmp[NL-1:0] (
   .core_clk                    (core_clk)
  ,.core_rst_n                  (core_rst_n)

  ,.current_data_rate           (current_data_rate)
  ,.smlh_lanes_active           (smlh_lanes_active[NL-1:0])
  ,.ltssm_in_lpbk_active        (ltssm_in_lpbk_active)
  ,.ltssm_in_lpbk_active_pos    (ltssm_in_lpbk_active_pos)
  ,.ltssm_in_lpbk_active_neg    (ltssm_in_lpbk_active_neg)
  ,.active_nb                   (active_nb)
  ,.lpbk_active                 (lpbk_active)
  ,.in_loopback                 (in_loopback)
  ,.ltssm_lpbk_master           (ltssm_lpbk_master)
  ,.prbs_en_int                 (prbs_en_int)
  ,.clear_prbs_done             (clear_prbs_done)
  ,.rpipe_rxdata_dv             (rpipe_rxdata_dv[NL-1:0])
  ,.rpipe_rxdata                (rpipe_rxdata[(NL*NB*8)-1:0])
  ,.rpipe_rxdatak               (rpipe_rxdatak[(NL*NBK)-1:0])
  ,.wait4idle_nd                (wait4idle_nd[NL-1:0])
  ,.descrambled_rxdata_dv       (descrambled_rxdata_dv[NL-1:0])
  ,.descrambled_rxdata          (descrambled_rxdata[(NL*NB*8)-1:0])
  ,.descrambled_rxdatak         (descrambled_rxdatak[(NL*NBK)-1:0])
  ,.descrambled_rxstartblock    (descrambled_rxstartblock[(NL*RXSB_WD)-1:0])
  ,.descrambled_rxdata_osfound  (descrambled_rxdata_osfound)

  ,.prbs_err_cntr             (prbs_err_cntr[NL-1:0])
  ,.prbs_started          (prbs_started[NL-1:0])
  ,.prbs_unexp_fail      (prbs_unexp_fail[NL-1:0])
  ,.wait4idle                    (wait4idle[NL-1:0])
);

endmodule
