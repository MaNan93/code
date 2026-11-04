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
// ---    $Revision: #12 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/phy_if_cpcie_shadow.sv#12 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module description:  This module contains PHY interface outputs shadowing
// logic
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module phy_if_cpcie_shadow #(
    // Parameters
    parameter INST = 0,
    parameter NL = 1,
    parameter TX_COEF_WD = 18,
    parameter RX_PSET_WD = 3,
    parameter TX_FS_WD = 6,
    parameter TX_PSET_WD = 4,
    parameter TX_CRSR_WD = 6,
    parameter RX_PRESET_WD = NL * RX_PSET_WD,
    parameter FS_WD = NL * TX_FS_WD,
    parameter LF_WD = NL * TX_FS_WD,
    parameter PSET_INDEX_WD = NL * TX_PSET_WD,
    parameter V7_DEEMPH_WD = NL * TX_CRSR_WD,
    parameter PSET_ID_WD = `PSET_ID_WD * NL,
    parameter PHY_RATE_WD = (`CX_GEN5_SPEED_VALUE == 1) ? 3 : (`CX_GEN3_SPEED_VALUE == 1) ? 2 : 1,
    parameter PHY_WIDTH_WD = `CX_PHY_WIDTH_WD,
    parameter TX_DEEMPH_WD = 2,
    parameter NL_X2 = NL * 2,
    parameter P_R_WD = `PCLK_RATE_WD
) (
    // Shadow register signals
    input                           clk,
    input                           rst_n,
    input                           hold_data,
    input                           update,
    input                           hold_perst,
    input                           update_perst
    ,
    input [31:0]                    cfg_phy_control
    ,input                          cfg_comm_clk_config
    // PHY interface signals
    ,
    input                           xmlh_sris_enable,
    input [(NL - 1) : 0]            mac_phy_txdetectrx_loopback,
    input [(NL - 1) : 0]            mac_phy_txcompliance,
    input [(NL - 1) : 0]            mac_phy_rxpolarity,
    input [(PHY_WIDTH_WD -1) : 0]   mac_phy_width,
    input                           mac_phy_serdes_arch,
    input [(PHY_WIDTH_WD -1) : 0]   mac_phy_rxwidth,
    input [(NL - 1) : 0]            serdes_pipe_rxready,
    input [(NL - 1) : 0]            serdes_pipe_turnoff_lanes,
    input [P_R_WD-1 : 0]            mac_phy_pclk_rate,
    input [(NL - 1) : 0]            mac_phy_rxstandby
    ,
    input [(PHY_RATE_WD - 1) : 0]   mac_phy_rate,
    input [(TX_DEEMPH_WD - 1) : 0]  mac_phy_txdeemph
    ,
    input [(NL - 1) : 0]            mac_phy_txdatavalid
    ,
    input [(NL*TX_COEF_WD - 1) : 0] mac_phy_smlh_coef_rtx
    ,
    input [NL*8-1:0]                mac_phy_mbus
    // Outputs
    ,
    output logic                              phy_if_cpcie_xmlh_sris_enable,
    output logic [(NL - 1) : 0]               phy_if_cpcie_shadow_txdetectrx_loopback,
    output logic [(NL - 1) : 0]               phy_if_cpcie_shadow_txcompliance,
    output logic [(NL - 1) : 0]               phy_if_cpcie_shadow_rxpolarity,
    output logic [(PHY_WIDTH_WD -1) : 0]      phy_if_cpcie_shadow_width,
    output logic                              phy_if_cpcie_shadow_serdes_arch,
    output logic [(PHY_WIDTH_WD -1) : 0]      phy_if_cpcie_shadow_rxwidth,
    output logic [(NL - 1) : 0]               pm_shadow_serdes_pipe_rxready,
    output logic [(NL - 1) : 0]               pm_shadow_serdes_pipe_turnoff_lanes,
    output logic [P_R_WD-1 : 0]               phy_if_cpcie_shadow_pclk_rate,
    output logic [(NL - 1) : 0]               phy_if_cpcie_shadow_rxstandby
    ,
    output logic [(PHY_RATE_WD - 1) : 0]      phy_if_cpcie_shadow_rate,
    output logic [(TX_DEEMPH_WD - 1) : 0]     phy_if_cpcie_shadow_txdeemph
    ,
    output logic [(NL - 1) : 0]               phy_if_cpcie_shadow_txdatavalid
    ,
    output logic [(NL*TX_COEF_WD - 1) : 0]    phy_if_cpcie_shadow_smlh_coef_rtx
    ,
    output logic [NL*8-1:0]                  phy_if_cpcie_shadow_mbus
    ,
    output logic [31:0]                      phy_if_cfg_phy_control
    ,output logic                            phy_if_cfg_comm_clk_config
);

// ----------------------------------------------------------------------------
// Net Declarations
// ----------------------------------------------------------------------------
wire    int_en_shadow_s;
wire    int_en_l2_shadow_s;

// ----------------------------------------------------------------------------
// Logic implementation
// ----------------------------------------------------------------------------
// Shadow logic is only enabled if support for power gating in L1 substates in enabled
assign int_en_shadow_s = 1'b0;

assign int_en_l2_shadow_s = 1'b0;

// ----------------------------------------------------------------------------
// Common Pipe Signals
// ----------------------------------------------------------------------------
struct packed {
  logic [NL-1:0]            txdetectrx_loopback;
  logic [NL-1:0]            txcompliance;
  logic [NL-1:0]            rxpolarity;
  logic [NL-1:0]            rxstandby;
  logic [PHY_WIDTH_WD-1:0]  width;
  logic [P_R_WD-1:0]        pclk_rate;
}  int_common_pipe_data_in_s, int_common_pipe_data_out_s;

localparam int  COMMON_PIPE_BUS_WD = $bits(int_common_pipe_data_in_s);

wire global_hold;
wire global_update;
wire global_shadow;

assign global_hold   = hold_perst   || hold_data;
assign global_update = update_perst || update;
assign global_shadow = int_en_l2_shadow_s || int_en_shadow_s;

// MUX input
always_comb begin: int_common_pipe_data_in_s_PROC
  int_common_pipe_data_in_s.txdetectrx_loopback = mac_phy_txdetectrx_loopback;
  int_common_pipe_data_in_s.txcompliance = mac_phy_txcompliance;
  int_common_pipe_data_in_s.rxpolarity = mac_phy_rxpolarity;
  int_common_pipe_data_in_s.rxstandby = mac_phy_rxstandby;
  int_common_pipe_data_in_s.width = mac_phy_width;
  int_common_pipe_data_in_s.pclk_rate = mac_phy_pclk_rate;
end: int_common_pipe_data_in_s_PROC

// Output assignment
always_comb begin: int_common_pipe_data_out_s_PROC
  phy_if_cpcie_shadow_txdetectrx_loopback = int_common_pipe_data_out_s.txdetectrx_loopback;
  phy_if_cpcie_shadow_txcompliance = int_common_pipe_data_out_s.txcompliance;
  phy_if_cpcie_shadow_rxpolarity = int_common_pipe_data_out_s.rxpolarity;
  phy_if_cpcie_shadow_rxstandby = int_common_pipe_data_out_s.rxstandby;
  phy_if_cpcie_shadow_width = int_common_pipe_data_out_s.width;
  phy_if_cpcie_shadow_pclk_rate = int_common_pipe_data_out_s.pclk_rate;
end: int_common_pipe_data_out_s_PROC

// Array of shadow register instances
// Note mac_phy_txdetectrx_loopback, mac_phy_txcompliance, and mac_phy_rxpolarity are shadowed in L1.2. This is covered by the first 3 * NL replications of int_en_shadow_s.
// Note mac_phy_rxstandby, mac_phy_width, and mac_phy_pclk_rate are being shadowed in L2 aswell as L1.2 this is to prevent a rate/width change in L2. This is covered by the NL + 2 + P_R_WD replications of shadow_width_rate_s.
shadow_reg
 #(
    .INST   (INST)
) u_common_pipe_shadow [(COMMON_PIPE_BUS_WD - 1) : 0] (
    // Inputs
    .clk            (clk),
    .rst_n          (rst_n),
    .en_shadow      (global_shadow),
    .hold_data      (global_hold),
    .update         (global_update),
    .data           (int_common_pipe_data_in_s),
    // Outputs
    .shadow_data    (int_common_pipe_data_out_s)
);


// ----------------------------------------------------------------------------
// Gen2/Gen3 Signals
// ----------------------------------------------------------------------------
struct packed {
  logic [PHY_RATE_WD-1:0]   rate;
  logic [TX_DEEMPH_WD-1:0]  txdeemph;
}  int_gen2_3_data_in_s, int_gen2_3_data_out_s;

localparam int  GEN2_3_BUS_WD = $bits(int_gen2_3_data_in_s);

// MUX input
always_comb begin: int_gen2_3_data_in_s_PROC
  int_gen2_3_data_in_s.rate = mac_phy_rate;
  int_gen2_3_data_in_s.txdeemph = mac_phy_txdeemph;
end: int_gen2_3_data_in_s_PROC

// Output assignment
always_comb begin: int_gen2_3_data_out_s_PROC
  phy_if_cpcie_shadow_rate = int_gen2_3_data_out_s.rate;
  phy_if_cpcie_shadow_txdeemph = int_gen2_3_data_out_s.txdeemph;
end: int_gen2_3_data_out_s_PROC

// Array of shadow register instances
shadow_reg
 #(
    .INST   (INST)
) u_gen2_3_shadow [(GEN2_3_BUS_WD - 1) : 0] (
    // Inputs
    .clk            (clk),
    .rst_n          (rst_n),
    .en_shadow      (global_shadow),
    .hold_data      (global_hold),
    .update         (global_update),
    .data           (int_gen2_3_data_in_s),
    // Outputs
    .shadow_data    (int_gen2_3_data_out_s)
);

// ----------------------------------------------------------------------------
// Gen3 PIPE Signals
// ----------------------------------------------------------------------------
struct packed {
  logic [NL-1:0]     txdatavalid;
  logic [NL*TX_COEF_WD-1:0] smlh_coef_rtx;
}  int_gen3_pipe_data_in_s, int_gen3_pipe_data_out_s;

localparam int  GEN3_PIPE_BUS_WD = $bits(int_gen3_pipe_data_in_s);

// MUX input
always_comb begin: int_gen3_pipe_data_in_s_PROC
  int_gen3_pipe_data_in_s.txdatavalid = mac_phy_txdatavalid;
  int_gen3_pipe_data_in_s.smlh_coef_rtx = mac_phy_smlh_coef_rtx;
end: int_gen3_pipe_data_in_s_PROC

// Output assignment
always_comb begin: int_gen3_pipe_data_out_s_PROC
  phy_if_cpcie_shadow_txdatavalid = int_gen3_pipe_data_out_s.txdatavalid;
  phy_if_cpcie_shadow_smlh_coef_rtx = int_gen3_pipe_data_out_s.smlh_coef_rtx;
end: int_gen3_pipe_data_out_s_PROC

// Array of shadow register instances
shadow_reg
 #(
    .INST   (INST)
) u_gen3_pipe_shadow [(GEN3_PIPE_BUS_WD - 1) : 0] (
    // Inputs
    .clk            (clk),
    .rst_n          (rst_n),
    .en_shadow      (global_shadow),
    .hold_data      (global_hold),
    .update         (global_update),
    .data           (int_gen3_pipe_data_in_s),
    // Outputs
    .shadow_data    (int_gen3_pipe_data_out_s)
);


// ----------------------------------------------------------------------------
// PIPE5 Signals (Hold in L2)
// ----------------------------------------------------------------------------
struct packed {
  logic                     serdes_arch;
  logic [PHY_WIDTH_WD-1:0]  rxwidth;
}  int_pipe5_holdl2_data_in_s, int_pipe5_holdl2_data_out_s;

localparam int  PIPE5_HOLDL2_BUS_WD = $bits(int_pipe5_holdl2_data_in_s);

// MUX input
always_comb begin: int_pipe5_holdl2_data_in_s_PROC
  int_pipe5_holdl2_data_in_s.serdes_arch = mac_phy_serdes_arch;
  int_pipe5_holdl2_data_in_s.rxwidth = mac_phy_rxwidth;
end: int_pipe5_holdl2_data_in_s_PROC

// Output assignment
always_comb begin: int_pipe5_holdl2_data_out_s_PROC
  phy_if_cpcie_shadow_serdes_arch = int_pipe5_holdl2_data_out_s.serdes_arch;
  phy_if_cpcie_shadow_rxwidth = int_pipe5_holdl2_data_out_s.rxwidth;
end: int_pipe5_holdl2_data_out_s_PROC

// Array of shadow register instances
shadow_reg
 #(
    .INST   (INST)
) u_pipe5_holdl2_shadow [(PIPE5_HOLDL2_BUS_WD - 1) : 0] (
    // Inputs
    .clk            (clk),
    .rst_n          (rst_n),
    .en_shadow      (global_shadow),
    .hold_data      (global_hold),
    .update         (global_update),
    .data           (int_pipe5_holdl2_data_in_s),
    // Outputs
    .shadow_data    (int_pipe5_holdl2_data_out_s)
);

// ----------------------------------------------------------------------------
// PIPE5 Signals (Not Hold in L2)
// ----------------------------------------------------------------------------
struct packed {
  logic [NL-1:0]  rxready;
  logic [NL-1:0]  turnoff_lanes;
}  int_pipe5_data_in_s, int_pipe5_data_out_s;

localparam int  PIPE5_BUS_WD = $bits(int_pipe5_data_in_s);

// MUX input
always_comb begin: int_pipe5_data_in_s_PROC
  int_pipe5_data_in_s.rxready = serdes_pipe_rxready;
  int_pipe5_data_in_s.turnoff_lanes = serdes_pipe_turnoff_lanes;
end: int_pipe5_data_in_s_PROC

// Output assignment
always_comb begin: int_pipe5_data_out_s_PROC
  pm_shadow_serdes_pipe_rxready = int_pipe5_data_out_s.rxready;
  pm_shadow_serdes_pipe_turnoff_lanes = int_pipe5_data_out_s.turnoff_lanes;
end: int_pipe5_data_out_s_PROC

// Array of shadow register instances
shadow_reg
 #(
    .INST   (INST)
) u_pipe5_shadow [(PIPE5_BUS_WD - 1) : 0] (
    // Inputs
    .clk            (clk),
    .rst_n          (rst_n),
    .en_shadow      (global_shadow),
    .hold_data      (global_hold),
    .update         (global_update),
    .data           (int_pipe5_data_in_s),
    // Outputs
    .shadow_data    (int_pipe5_data_out_s)
);


// ----------------------------------------------------------------------------
// PIPE6 Signals 
// ----------------------------------------------------------------------------
localparam int PIPE6_BUS_WD = 1;
wire [(PIPE6_BUS_WD - 1) : 0] int_pipe6_data_in_s;
wire [(PIPE6_BUS_WD - 1) : 0] int_pipe6_data_out_s;

// MUX input
assign int_pipe6_data_in_s = xmlh_sris_enable;

// Array of shadow register instances
shadow_reg
 #(
    .INST   (INST),
    .RESET_VALUE ('1)
) u_pipe6_shadow [(PIPE6_BUS_WD - 1) : 0] (
    // Inputs
    .clk            (clk),
    .rst_n          (rst_n),
    .en_shadow      (global_shadow),
    .hold_data      (global_hold),
    .update         (global_update),
    .data           (int_pipe6_data_in_s),
    // Outputs
    .shadow_data    (int_pipe6_data_out_s)
);

// Output assignment
assign phy_if_cpcie_xmlh_sris_enable = int_pipe6_data_out_s;


// ----------------------------------------------------------------------------
// Messge Bus interface signals
// ----------------------------------------------------------------------------
localparam PIPE_MSG_BUS_WD = (NL * 8);

wire [(PIPE_MSG_BUS_WD - 1) : 0]  int_regif_data_in_s;
wire [(PIPE_MSG_BUS_WD - 1) : 0]  int_regif_data_out_s;

// MUX input
assign int_regif_data_in_s = {mac_phy_mbus};

// Array of shadow register instances
shadow_reg
 #(
    .INST   (INST)
) u_regif_shadow [(PIPE_MSG_BUS_WD - 1) : 0] (
    // Inputs
    .clk            (clk),
    .rst_n          (rst_n),
    .en_shadow      (global_shadow),
    .hold_data      (global_hold),
    .update         (global_update),
    .data           (int_regif_data_in_s),
    // Outputs
    .shadow_data    (int_regif_data_out_s)
);

// Output assignment
assign {phy_if_cpcie_shadow_mbus} = int_regif_data_out_s;

// GPIO control bus for PHY
shadow_reg

 #(
    .INST               (INST),
    .WIDTH              (32),
    .EN_HOLD_BYPASS_MUX (1'b0),
    .RESET_VALUE        (`DEFAULT_PHY_CONTROL)
) u_cfg_phy_control (
    // Inputs
    .clk            (clk),
    .rst_n          (rst_n),
    .en_shadow      (global_shadow),
    .hold_data      (global_hold),
    .update         (global_update),
    .data           (cfg_phy_control),
    // Outputs
    .shadow_data    (phy_if_cfg_phy_control)
);

// Common Clock Configuration in Link Control Register
shadow_reg

 #(
    .INST   (INST)
) u_cfg_comm_clk_config (
    // Inputs
    .clk            (clk),
    .rst_n          (rst_n),
    .en_shadow      (global_shadow),
    .hold_data      (global_hold),
    .update         (global_update),
    .data           (cfg_comm_clk_config),
    // Outputs
    .shadow_data    (phy_if_cfg_comm_clk_config)
);



endmodule
