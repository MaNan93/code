
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


`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module rasdp_error_mode_control #(
    parameter CORR_ERROR_WD   = 2,
    parameter UNCORR_2BITECC_ERROR_WD = 2,
    parameter UNCORR_ERROR_WD = 2
    )
    (
    input  wire                       core_clk,
    input  wire                       non_sticky_rst_n,
    input  wire                       sticky_rst_n,
    input  wire                       cfg_rasdp_error_mode_en,
    input  wire                       cfg_rasdp_linkdown_en,
    input  wire                       ras_clear_nullification_flag,
    input  wire                       rasdp_err_uncorr,
    input  wire                       rasdp_err_corr,
    input  wire                       trigger_fatal_error,
    output wire                       cfg_rasdp_error_mode,
    output reg                        rasdp_linkdown,
    output wire                       rasdp_int_uncorr_error,
    output reg                        rasdp_int_corr_error
    );

parameter TP   = `TP;                              // Clock to Q delay (simulator insurance)

reg  cfg_rasdp_error_mode_reg;
reg  cfg_rasdp_error_mode_sticky_reg;
reg  cfg_rasdp_error_mode_1d;
wire error_pulse;
wire cfg_rasdp_error_mode_req;

// falling edge indicator for cfg_rasdp_error_mode
wire cfg_rasdp_error_mode_fe;
// indicates at least one corrected error was detected, or there is a pending indication
wire error_corr;

// request link down condition
wire linkdown_req;

assign linkdown_req   = (cfg_rasdp_error_mode_reg==1'b0) && (error_pulse & cfg_rasdp_error_mode_en);

assign error_corr     = |{rasdp_err_corr};

//assign rasdp_linkdown = cfg_rasdp_linkdown_en & linkdown_req;
always @(posedge core_clk or negedge non_sticky_rst_n)
 begin: rasdp_linkdown_PROC
   if (!non_sticky_rst_n)
    rasdp_linkdown <= #TP 1'b0;
  else begin
    if (cfg_rasdp_linkdown_en & linkdown_req)
     rasdp_linkdown <= #TP 1'b1;
    else
     rasdp_linkdown <= #TP 1'b0;
  end
 end

// Register internal corrected errors to facilitate timing closure
always @(posedge core_clk or negedge non_sticky_rst_n)
  begin: rasdp_int_corr_error_PROC
    if (!non_sticky_rst_n)
      rasdp_int_corr_error <= #TP 1'd0;
    else if (rasdp_int_corr_error)
      rasdp_int_corr_error <= #TP 1'b0;
    else if (error_corr)
      rasdp_int_corr_error <= #TP 1'b1;
  end

// Report internal uncorrectable errors only when the nullification process is cleared
assign rasdp_int_uncorr_error   = cfg_rasdp_error_mode_fe;

assign  error_pulse             = |{rasdp_err_uncorr} || trigger_fatal_error;

//error mode request
assign  cfg_rasdp_error_mode_req = error_pulse & cfg_rasdp_error_mode_en;

assign  cfg_rasdp_error_mode_fe = (cfg_rasdp_error_mode_sticky_reg == 1'b0) && (cfg_rasdp_error_mode_1d==1'b1);

//the error flags coming to this block have been registerd in cdm, otherwise there is very high fanin and will fail timing/routing
//The request condition is or'd with the error mode output so that there is no added latency that could cause an error packet not being nullified in time.
assign cfg_rasdp_error_mode = cfg_rasdp_error_mode_reg || cfg_rasdp_error_mode_req;

always @(posedge core_clk or negedge non_sticky_rst_n)
  begin: cfg_rasdp_error_mode_PROC
    if (!non_sticky_rst_n)
      cfg_rasdp_error_mode_reg <= #TP 1'd0;
    else if (error_pulse & cfg_rasdp_error_mode_en)
      cfg_rasdp_error_mode_reg <= #TP 1'b1;
    else if (ras_clear_nullification_flag)
      cfg_rasdp_error_mode_reg <= #TP 1'd0;
  end

// Sticky register to hold the RASDP error mode status after link down
always @(posedge core_clk or negedge sticky_rst_n)
  begin: cfg_rasdp_error_mode_sticky_PROC
    if (!sticky_rst_n)
      cfg_rasdp_error_mode_sticky_reg <= #TP 1'd0;
    else if (error_pulse & cfg_rasdp_error_mode_en)
      cfg_rasdp_error_mode_sticky_reg <= #TP 1'b1;
    else if (ras_clear_nullification_flag)
      cfg_rasdp_error_mode_sticky_reg <= #TP 1'd0;
  end

always @(posedge core_clk or negedge sticky_rst_n)
  begin: cfg_rasdp_error_mode_1d_PROC
    if (!sticky_rst_n)
      cfg_rasdp_error_mode_1d <= #TP 1'd0;
    else
      cfg_rasdp_error_mode_1d <= #TP cfg_rasdp_error_mode_sticky_reg;
  end


endmodule

// Revision: $Id: //dwh/pcie_iip/main/fairbanks/design/common/rasdp_error_mode_control.sv#8 $

