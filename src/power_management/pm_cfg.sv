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
// ---    $Revision: #20 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_cfg.sv#20 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// --- This module manages the interface between the power management circuitry
// --- and the configuration space CDM.
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module pm_cfg
  // Parameters
  #(
    parameter TP = `TP,
    parameter INST = 0,
    parameter NL = `CX_NL,
    parameter NF = 1,
    parameter ASLK_CTRL_WD = (NF * 2),
    parameter NVF = 1,
    parameter BUS_NUM_WD = 1,
    parameter DEV_NUM_WD = 1,
    parameter UPD_REQ_ID_WD = 1,
    parameter L1SUB_CONTROL_WD = 1,
    parameter PL_L1SUB_CONTROL_WD = 1,
    parameter PL_AUX_CLK_FREQ_WD = 1,
    parameter PDWN_WIDTH  = 4,
    parameter P2NOBEACON_ENABLE_VAL = `CX_P2NOBEACON_ENABLE_VALUE,
    parameter [PDWN_WIDTH - 1 : 0] P2NOBEACON  = `CX_PIPE43_P2NOBEACON_ENCODING,
    parameter [PDWN_WIDTH - 1 : 0] P2          = 4'b0011,
    parameter PIPE_OPTIONAL_PCLKCHANGE_HS = `CX_PIPE_OPTIONAL_PCLKCHANGE_HS,
    parameter DEFAULT_PHY_PERST_ON_WARM_RESET = `DEFAULT_PHY_PERST_ON_WARM_RESET,
    parameter PHY_RST_TIMER_VAL = `CX_PHY_RST_TIMER,
    parameter PMA_PIPE_RST_DELAY_TIMER_VAL = `CX_PMA_PIPE_RST_DELAY_TIMER,
    parameter NFUNC_WD = 1
  )
  
                (
  // Inputs
  input                                   en_iso,
  input                                   aux_clk,                    // clock
  input                                   pwr_rst_n,                  // power on reset
  input                                   perst_n,                    // power good indication or fundamental reset request
  input                                   pm_hold,                    // Hold signal from power management circuit active in L1.2
  input                                   pm_hold_perst,                 // Hold signal from power management circuit active in L2
  input                                   pm_update,                  // Update signal from power management circuit active in L1.2
  input                                   pm_update_perst,               // Update signal from power management circuit active in L2
  input                                   pm_req_core_rst,            // Request from PM to assert core_rst 
  input [(ASLK_CTRL_WD - 1) : 0]          cfg_aslk_pmctrl,            // active state link pm control
  input                                   cfg_aspm_l1_timer_enable,   // Enable ASPM L1 timer
  input [(NF - 1) : 0]                    cfg_upd_aslk_pmctrl,        // Update ASLK register
  input [(NF - 1) : 0]                    cfg_aux_pm_en,              // AUX pm enable
  input [(NF - 1) : 0]                    cfg_pme_en,                 // PME enable
  input [7 : 0]                           cfg_pbus_num,               // Bus number
  input [4 : 0]                           cfg_pbus_dev_num,           // Device number width
  input [(NF - 1) : 0]                    cfg_upd_aux_pm_en,          // Update cfg_aux_pm_en
  input [(NF - 1) : 0]                    cfg_upd_pmcsr,              // CDM pmcsr register updated
  input [(UPD_REQ_ID_WD - 1) : 0]         cfg_upd_req_id,             // Update bus and device numbers 
  input [((5*NF) - 1) : 0]                cfg_pme_cap,                // PME capability
  input [(NF - 1) : 0]                    cfg_upd_pme_cap,            // Update PME capability
  input                                   pm_core_rst_done,           // Rising edge detect of core_rst_n
  input                                   pm_active_state,            // Active state of PMU FSM
  input [((3*NF) - 1) : 0]                cfg_pmstate,                // PM state (D-state)
  input                                   cfg_clk_pm_en,              // CLK PM EN used to allow ref_clk to PHY to be disabled
  input [(L1SUB_CONTROL_WD - 1) : 0]      cfg_l1sub_control,          // L1 substates control
  input [(PL_L1SUB_CONTROL_WD - 1) : 0]   cfg_pl_l1sub_control,       // Port logic L1 substates control
  input                                   cfg_pl_l1_exit_mode,        // L1 exit mode port logic bit
  input                                   cfg_pl_l1_clk_sel,          // L1 aux_clk source select (1 => core_clk, 0 => auxclk)
  input                                   cfg_p2nobeacon_enable,      // Enable support to P2.NoBeacon
  input wire [31:0]                       cfg_utility,                // utility register for future workaround (chicken bit)
  output wire [31:0]                      pm_cfg_utility,             // utility register is shadowed in port logic (cdm_pl_reg block)
  input                                   cfg_pipe_optional_pclkchange_hs,
  input                                   cfg_phy_perst_on_warm_reset,
  input [17:0]                            cfg_phy_rst_timer, 
  input [5:0]                             cfg_pma_phy_rst_delay_timer, 
  input [(PL_AUX_CLK_FREQ_WD - 1) : 0]    cfg_pl_aux_clk_freq,        // Aux clock frequency
  input                                   cfg_pl_gen3_zrxdc_noncompl, // Gen3 Zrx-dc noncompliance bit
  input                                   upstream_port,
  input [5:0]                             cfg_link_capable,           // PL LINK_CAPABLE register, indicate used lanes at reset


  // Outputs
  output wire [(ASLK_CTRL_WD - 1) : 0]          pm_cfg_aslk_pmctrl,             // Active state link pm control
  output wire [(NF - 1) : 0]                    pm_cfg_aux_pm_en,               // AUX pm enable
  output wire [(NF - 1) : 0]                    pm_cfg_pme_en,                  // PME enable
  output wire                                   pm_aspm_l1_timer_enable,        // Enable ASPM L1 timer
  output wire [(BUS_NUM_WD - 1) : 0]            pm_cfg_pbus_num,                // Bus number
  output wire [(DEV_NUM_WD - 1) : 0]            pm_cfg_pbus_dev_num,            // Bus number
  output wire [((5*NF) - 1) : 0]                pm_cfg_pme_cap,                 // PME capabilities
  output wire [((3*NF) - 1) : 0]                pm_cfg_pmstate,                 // PM state
  output wire                                   pm_cfg_clk_pm_en,               // CLK PM enable
  output wire [(L1SUB_CONTROL_WD - 1) : 0]      pm_cfg_l1sub_control,           // L1 substates control
  output wire [(PL_L1SUB_CONTROL_WD - 1) : 0]   pm_cfg_pl_l1sub_control,        // PL L1 substates control
  output wire                                   pm_cfg_pl_l1_exit_mode,         // PL L1 exit mode
  output wire                                   pm_cfg_pl_l1_clk_sel,           // PL L1 clock gating mode
  output wire [(PDWN_WIDTH - 1) : 0]            pm_cfg_phy_powerdown_p2_options,// Drive P2 or P2.NoBeacon
  output wire                                   pm_pipe_optional_pclkchange_hs,       // PIPE PCLK Change Optional Behaviour
  output wire                                   pm_phy_perst_on_warm_reset,     // PMC drive pm_req_phy_perst when warm reset
  output wire [(PL_AUX_CLK_FREQ_WD - 1) : 0]    pm_cfg_pl_aux_clk_freq          // Aux clock frequency
  ,
  output wire                                   pm_cfg_pl_gen3_zrxdc_noncompl  // Gen3 Zrx-dc noncompliance bit
  ,output reg                                   pm_upstream_port
  ,output wire [5:0]                            pm_link_capable
  ,output wire [17:0]                           pm_phy_rst_timer
  ,output wire [5:0]                            pm_pma_phy_rst_delay_timer
);

// ----------------------------------------------------------------------------
// Parameter Declarations
// ----------------------------------------------------------------------------
parameter   AUX_CLK_FREQ_RST_VAL = `DEFAULT_AUX_CLK_FREQ;
localparam  ASPM_L1_TIMER_ENABLE = `CX_ASPM_L1_TIMER_ENABLE_VALUE;
localparam  DOUNIT = 3'b100;
localparam  NINST = 1;

// ----------------------------------------------------------------------------
// Net Declarations
// ----------------------------------------------------------------------------
wire int_l1_or_l2_hold_s;
wire int_l1_or_l2_update_s;
wire int_hold_pmstate_s;
wire pm_upstream_port_s;



// ----------------------------------------------------------------------------
// Shadow registers that update on CDM write hold value during power gating
// Note these shadow registers are also update when the core is reset
// ----------------------------------------------------------------------------
shadow_reg

    // Parameters
    #(
        .INST               (1'b0),
        .EN_HOLD_BYPASS_MUX (1'b0),
        .RESET_VALUE        (ASPM_L1_TIMER_ENABLE),
        .WIDTH              (1'b1)
    ) u_aspm_l1_timer_enable_shadow (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (pm_hold),
    .update      (perst_n),
    .data        (cfg_aspm_l1_timer_enable),
    // Outputs
    .shadow_data (pm_aspm_l1_timer_enable)
);

genvar nf;
generate
for (nf=0; nf<NF; nf=nf+1)
begin: gen_pm_aslk_shadow
shadow_reg

    // Parameters
    #(
        .INST               (1'b0),
        .EN_HOLD_BYPASS_MUX (1'b0),
        .WIDTH              (ASLK_CTRL_WD/NF)
    ) u_aslk_pmctrl_shadow (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (pm_hold),
    .update      (pm_core_rst_done | cfg_upd_aslk_pmctrl[nf]),
    .data        (cfg_aslk_pmctrl[(nf*(ASLK_CTRL_WD/NF) + (ASLK_CTRL_WD/NF) - 1) : (nf*(ASLK_CTRL_WD/NF))]),
    // Outputs
    .shadow_data (pm_cfg_aslk_pmctrl[(nf*(ASLK_CTRL_WD/NF) + (ASLK_CTRL_WD/NF) - 1) : (nf*(ASLK_CTRL_WD/NF))])
);
end
endgenerate // gen_pm_aslk_shadow

// ----------------------------------------------------------------------------
// Registers that update on CDM access otherwise hold their value
// ----------------------------------------------------------------------------
shadow_reg

    // Parameters
    #(
        .INST               (1'b0),
        .EN_HOLD_BYPASS_MUX (1'b0)
    ) u_aux_pm_en_shadow [(NF - 1) : 0] (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (1'b0),
    .update      (cfg_upd_aux_pm_en),
    .data        (cfg_aux_pm_en),
    // Outputs
    .shadow_data (pm_cfg_aux_pm_en)
);

shadow_reg

    // Parameters
    #(
        .INST               (1'b0),
        .EN_HOLD_BYPASS_MUX (1'b0)
    ) u_pme_en_shadow [(NF - 1) : 0] (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (pm_hold),
    .update      (cfg_upd_pmcsr),
    .data        (cfg_pme_en),
    // Outputs
    .shadow_data (pm_cfg_pme_en)
);


shadow_reg

    // Parameters
    #(
        .INST               (1'b0),
        .EN_HOLD_BYPASS_MUX (1'b0),
        .DIS_SHADOW_MUX     (1'b1),
        .WIDTH              (8)
    ) u_bus_num_shadow [(NINST - 1) : 0] (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (pm_hold),
    .update      (cfg_upd_req_id),
    .data        (cfg_pbus_num),
    // Outputs
    .shadow_data (pm_cfg_pbus_num)
);

shadow_reg

    // Parameters
    #(
        .INST               (1'b0),
        .EN_HOLD_BYPASS_MUX (1'b0),
        .DIS_SHADOW_MUX     (1'b1),
        .WIDTH              (5)
    ) u_pbus_dev_num_shadow [(NINST - 1) : 0] (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (pm_hold),
    .update      (cfg_upd_req_id),
    .data        (cfg_pbus_dev_num),
    // Outputs
    .shadow_data (pm_cfg_pbus_dev_num)
);

// ----------------------------------------------------------------------------
// PME Capabilities
// ----------------------------------------------------------------------------
pm_cfg_pme

  // Parameters
  #(
    .INST     (1'b0),
    .NF       (NF),
    .NVFUNC   (NVF),
    .NFUNC_WD (NFUNC_WD)
  ) u_pm_cfg_pme (
  // Inputs
  .aux_clk            (aux_clk),
  .pwr_rst_n          (pwr_rst_n),
  .cfg_upd_pme_cap    (cfg_upd_pme_cap),
  .cfg_pme_cap        (cfg_pme_cap),
  .pm_core_rst_done   (pm_core_rst_done),
  .pm_active_state    (pm_active_state),
  // Outputs
  .pm_cfg_pme_cap     (pm_cfg_pme_cap)
);

// ----------------------------------------------------------------------------
// Registers updated before power-gating and held during power-gating
// ----------------------------------------------------------------------------
assign int_l1_or_l2_update_s = pm_update || pm_update_perst;
assign int_l1_or_l2_hold_s   = pm_hold   || pm_hold_perst;
assign int_hold_pmstate_s = !perst_n || int_l1_or_l2_hold_s 
                            ;

// ----------------------------------------------------------------------------
// phy_perst_on_warm_reset hold/update logic 
// ----------------------------------------------------------------------------

wire int_phy_perst_hold_s;   // triggers shadow reg hold 
wire int_phy_perst_update_s; // triggers shadow reg update 
reg  int_hold_phy_perst_s; 
reg  int_hold_phy_perst_r;
wire int_hold_phy_perst_on_warm_reset_pmstate_s; // i/p to shadow reg 
wire negedge_pm_req_core_rst;
reg  pm_req_core_rst_d;

assign int_phy_perst_hold_s = int_hold_pmstate_s;
assign int_phy_perst_update_s = negedge_pm_req_core_rst;

always @(int_phy_perst_hold_s or int_phy_perst_update_s or int_hold_phy_perst_r)
begin
    if(int_phy_perst_hold_s)
        int_hold_phy_perst_s = 1'b1;
    else if(int_phy_perst_update_s)
        int_hold_phy_perst_s = 1'b0;
    else
        int_hold_phy_perst_s = int_hold_phy_perst_r;
end

always @(posedge aux_clk or negedge pwr_rst_n) begin
  if(!pwr_rst_n) begin
      int_hold_phy_perst_r <= #TP 1'b0;
  end
  else begin
      int_hold_phy_perst_r <= #TP int_hold_phy_perst_s;
  end
end

assign int_hold_phy_perst_on_warm_reset_pmstate_s = int_hold_phy_perst_s;

// ----------------------------------------------------------------------------
// negedge detector logic for pm_req_core_rst 
// ----------------------------------------------------------------------------

assign negedge_pm_req_core_rst = pm_req_core_rst_d & (!pm_req_core_rst);

always @(posedge aux_clk or negedge pwr_rst_n) begin
  if (!pwr_rst_n) begin
      pm_req_core_rst_d <= #TP 0;
  end else begin
      pm_req_core_rst_d <= #TP pm_req_core_rst;
  end
end
 

shadow_reg

    // Parameters
    #(
        .INST               (1'b0),
        .WIDTH              (3*NF),
        .RESET_VALUE        ({NF{DOUNIT}})
    ) u_pmstate_shadow (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (int_hold_pmstate_s),
    .update      (perst_n),
    .data        (cfg_pmstate),
    // Outputs
    .shadow_data (pm_cfg_pmstate)
);


shadow_reg

    // Parameters
    #(
        .INST (1'b0)
    ) u_clk_pm_en_shadow (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (int_l1_or_l2_hold_s),
    .update      (perst_n),
    .data        (cfg_clk_pm_en),
    // Outputs
    .shadow_data (pm_cfg_clk_pm_en)
);

shadow_reg

    // Parameters
    #(
        .INST   (1'b0),
        .WIDTH  (L1SUB_CONTROL_WD)
    ) u_l1sub_control_shadow (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (int_l1_or_l2_hold_s),
    .update      (int_l1_or_l2_update_s),
    .data        (cfg_l1sub_control),
    // Outputs
    .shadow_data (pm_cfg_l1sub_control)
);

shadow_reg

    // Parameters
    #(
        .INST   (1'b0),
        .WIDTH  (PL_L1SUB_CONTROL_WD)
    ) u_pl_l1sub_control_shadow (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (int_l1_or_l2_hold_s),
    .update      (int_l1_or_l2_update_s),
    .data        (cfg_pl_l1sub_control),
    // Outputs
    .shadow_data (pm_cfg_pl_l1sub_control)
);

shadow_reg

    // Parameters
    #(
        .INST   (1'b0)
    ) u_pl_l1_exit_mode_shadow (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (int_l1_or_l2_hold_s),
    .update      (int_l1_or_l2_update_s),
    .data        (cfg_pl_l1_exit_mode),
    // Outputs
    .shadow_data (pm_cfg_pl_l1_exit_mode)
);

shadow_reg

    // Parameters
    #(
        .INST   (1'b0)
    ) u_pl_l1_clk_sel_shadow (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (int_l1_or_l2_hold_s),
    .update      (int_l1_or_l2_update_s),
    .data        (cfg_pl_l1_clk_sel),
    // Outputs
    .shadow_data (pm_cfg_pl_l1_clk_sel)
);

wire pm_cfg_p2nobeacon_enable;       // Enable to support P2.NoBeacon
assign pm_cfg_phy_powerdown_p2_options = pm_cfg_p2nobeacon_enable ? P2NOBEACON : P2;
shadow_reg

    // Parameters
    #(
        .INST               (1'b0),
        .RESET_VALUE        (P2NOBEACON_ENABLE_VAL)
    ) u_p2nobeacon_enable_shadow (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (int_hold_pmstate_s),
    .update      (perst_n),
    .data        (cfg_p2nobeacon_enable),
    // Outputs
    .shadow_data (pm_cfg_p2nobeacon_enable)
);

shadow_reg

    // Parameters
    #(
        .INST               (1'b0),
        .RESET_VALUE        (PIPE_OPTIONAL_PCLKCHANGE_HS)
    ) u_pipe_optional_pclkchange_hs_shadow (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (int_hold_pmstate_s),
    .update      (perst_n),
    .data        (cfg_pipe_optional_pclkchange_hs),
    // Outputs
    .shadow_data (pm_pipe_optional_pclkchange_hs)
);

shadow_reg

    // Parameters
    #(
        .INST               (1'b0),
        .RESET_VALUE        (PHY_RST_TIMER_VAL),
        .WIDTH              (18)
    ) u_phy_rst_timer_shadow (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (int_hold_pmstate_s),
    .update      (perst_n),
    .data        (cfg_phy_rst_timer),
    // Outputs
    .shadow_data (pm_phy_rst_timer)
);

shadow_reg

    // Parameters
    #(
        .INST               (1'b0),
        .RESET_VALUE        (PMA_PIPE_RST_DELAY_TIMER_VAL),
        .WIDTH              (6)
    ) u_pma_phy_rst_delay_timer_shadow (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (int_hold_pmstate_s),
    .update      (perst_n),
    .data        (cfg_pma_phy_rst_delay_timer),
    // Outputs
    .shadow_data (pm_pma_phy_rst_delay_timer)
);

shadow_reg

    // Parameters
    #(
        .INST               (1'b0),
        .RESET_VALUE        (DEFAULT_PHY_PERST_ON_WARM_RESET)
    ) u_phy_perst_on_warm_reset_shadow (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (int_hold_phy_perst_on_warm_reset_pmstate_s),
    .update      (perst_n),
    .data        (cfg_phy_perst_on_warm_reset),
    // Outputs
    .shadow_data (pm_phy_perst_on_warm_reset)
);

shadow_reg

    // Parameters
    #(
        .INST               (1'b0),
        .WIDTH              (PL_AUX_CLK_FREQ_WD),
        .RESET_VALUE        (AUX_CLK_FREQ_RST_VAL)
    ) u_pl_aux_clk_freq_shadow (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (int_l1_or_l2_hold_s),
    .update      (int_l1_or_l2_update_s),
    .data        (cfg_pl_aux_clk_freq),
    // Outputs
    .shadow_data (pm_cfg_pl_aux_clk_freq)
);

shadow_reg

    // Parameters
    #(
        .INST               (1'b0)
    ) u_pl_gen3_zrxdc_shadow (
    // Inputs
    .clk         (aux_clk),
    .rst_n       (pwr_rst_n),
    .en_shadow   (1'b1),
    .hold_data   (int_l1_or_l2_hold_s),
    .update      (int_l1_or_l2_update_s),
    .data        (cfg_pl_gen3_zrxdc_noncompl),
    // Outputs
    .shadow_data (pm_cfg_pl_gen3_zrxdc_noncompl)
);


always @(posedge aux_clk or negedge pwr_rst_n) begin
  if(!pwr_rst_n) begin
    pm_upstream_port <= #TP 1'b0;
  end else begin
    pm_upstream_port <= #TP pm_upstream_port_s;
  end
end
shadow_reg

#(.INST (INST)) u_usp_shadow_reg (
    // Inputs
    .clk            (aux_clk),
    .rst_n          (pwr_rst_n),
    .en_shadow      (1'b1),
    .hold_data      (int_hold_pmstate_s),
    .update         (perst_n),
    .data           (upstream_port),
    // Outputs
    .shadow_data    (pm_upstream_port_s)
);

shadow_reg

#(.INST (INST),
  .WIDTH (6),
  .EN_HOLD_BYPASS_MUX (1'b0),
  .RESET_VALUE        (`DEFAULT_LINK_CAPABLE)
) u_link_capable_shadow_reg (
    // Inputs
    .clk            (aux_clk),
    .rst_n          (pwr_rst_n),
    .en_shadow      (1'b1),
    .hold_data      (int_hold_pmstate_s),
    .update         (perst_n),
    .data           (cfg_link_capable),
    // Outputs
    .shadow_data    (pm_link_capable)
);

// --------------------------------------------------------------------------------
// shadow register for cfg_utility port logic register (to be used as chicken bit)
// --------------------------------------------------------------------------------
shadow_reg

#(.INST (1'b0),
  .WIDTH (32)
) u_cfg_utility_shadow_reg (
    // Inputs
    .clk            (aux_clk),
    .rst_n          (pwr_rst_n),
    .en_shadow      (1'b1),
    .hold_data      (int_hold_pmstate_s),
    .update         (perst_n),
    .data           (cfg_utility),
    // Outputs
    .shadow_data    (pm_cfg_utility)
);


// --------------------------------------------------------------------------------
// shadow register for cfg_ide_disable port logic register
// --------------------------------------------------------------------------------

endmodule
