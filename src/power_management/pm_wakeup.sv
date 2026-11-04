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
// ---    $DateTime: 2024/01/12 11:11:14 $
// ---    $Revision: #17 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_wakeup.sv#17 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// --- This module contains the logic to generate wakeup conditions from
// --- L1 link state and power gating state
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "power_management/DWC_pcie_pm_pkg.svh"
 
 module pm_wakeup
    // Parameters
    #( 
    parameter TP = `TP,
    parameter INST = 0,
    parameter NF = 1,
    parameter NVC = 1,
    parameter CPL_LUT_DEPTH = 1,
    parameter PM_SYNC_DEPTH  = 2,
    parameter NVC_XALI_EXP  = `CX_NVC_XALI_EXPANSION
    )
    
                     (
    // Inputs
    input                 aux_clk, // clock
    input                 pwr_rst_n, // power on reset
    input                 slv_awvalid, // AXI slave valid
    input                 slv_arvalid, // AXI slave valid
    input                 slv_wvalid, // AXI slave valid
    input [NVC_XALI_EXP-1:0] client0_tlp_hv, // client header valid
    input [NVC_XALI_EXP-1:0] client1_tlp_hv, // client header valid
    input [NVC_XALI_EXP-1:0] client2_tlp_hv, // client header valid
    input                 app_obff_idle_msg_req, // OBFF message request
    input                 app_obff_obff_msg_req, // OBFF message request
    input                 app_obff_cpu_active_msg_req, // OBFF message request
    input                 brdg_slv_xfer_pending, // AXI Slave transfer pending
    input                 edma_xfer_pending, // DMA pending indication
    input                 lti_xfer_pending, //LTIM pending indication
    input                 local_msi_xfer_pending, //Local MSI pending indication
    input                 pm_radm_idle_n, // RADM not idle indication 
    input                 lbc_active, // LBC is processing a non-posted request
    input                 pm_trgt_cpl_lut_empty_n, // TX path CPL LUT is not empty
    input                 cxl_cache_slv_req, // CXL.cache Slave Init request
    input                 cxl_mem_slv_req,   // CXL.mem Slave Init request
    input                 app_xfer_pending, // application transfer pending
    input                 ptm_updating, //PTM Update is in progress
    input                 upstream_port, // indicates device is USP
    input                 switch_device,  // indicate that it is a switch device; 0 indicate that it is a EP/RC/bridge device
    input                 cfg_link_dis, // link disable
    input                 cfg_link_retrain, // link retrain
    input                 cfg_lpbk_en, // loopback enabled
    input                 cfg_2nd_reset, // hot reset request
    input                 cfg_plreg_reset, // hot reset request
    input                 cfg_directed_speed_change, // directed speed change
    input                 cfg_directed_width_change, // directed up/down configure
    input                 ven_msg_req, // vendor Message request
    input                 ven_msi_req, // vendor MSI request
    input                 app_init_rst, // application requests hot reset
    input                 app_ltr_msg_req, // application requests LTR message
    input                 app_unlock_msg, // application requests unlock message
    input                 msg_gen_unlock_grant, // Unlock message is granted
    input                 smlh_link_up, // Link is up
    input                 pm_req_iso_vmain_to_vaux, // Isolation enabled
    input                 pm_l1_in_progress, // L1 negotiation in progress
    input                 brdg_dbi_xfer_pending, // dbi transfer pending in bridge
    input                 pm_aspm_l1_timer_enable,  // L1 timer enable/disable
    input                 clkreq_in_n, // Status of the CLKREQ# bidirectional CMOS board-level signal, used for remotely initiated exit from L1 substates
    input                 pm_en_aux_clk_g, // aux clock enable for CDM
    input                 msg_gen_hv,
    input                 lbc_cpl_hv,
    input                 app_req_exit_l1,        // Application: Provide a capability for applications to request PM state to exit L1 when ASPM L1 is enabled.
    input                 one_dwsp_exit_l1,       // Application: One of the downstream ports exits L1
    input                 latch_as_entr_l1,       // PM Protocol FSM indication of ASPM enter L1
    input                 software_entr_l23,      // PME Controller instructs PM Protocol FSM to go into L23
    input                 pm_pme_exit_l1,         // PME Controller requests L1 exit
    input                 pm_wake_l2_exit,        // PME Controller L2 exit wakeup request
    input                 xdlh_not_expecting_ack, // XDLH is not expecting ACK
    // Outputs
    output                pm_wake_req,            // PM Active Controller: Request from the Protocol Layer to remove clock gating from the internal logic of the LogPHY.
    output                lp_pcie_l1_exit,        // SPIF: Request to PCIe/CXL.io Link Layer to change requested from IDLE_L1_1 to ACTIVE and initiate L1 exit
    output                lp_pcie_wake_req,       // SPIF: PCIe/CXL.io Link Layer requests LogPHY to remove the clock gating
    input                 pl_pcie_wake_ack,       // SPIF: LogPHY acknowledges lp_wake_req to PCIe/CXL.io Link Layer
    input                 pl_pcie_state_l1,       // SPIF: pl_state_sts is in IDLE_L1_1 on PCIe/CXL.io SPIF interface
    input                 pl_pcie_state_l2,       // SPIF: pl_state_sts is in L2 on PCIe/CXL.io SPIF interface
    output                lp_cxl_l1_exit,         // SPIF: Request to CXL.cachemem Link Layer to change requested from IDLE_L1_1 to ACTIVE and initiate L1 exit
    output                lp_cxl_wake_req,        // SPIF: CXL.cachemem Link Layer requests LogPHY to remove the clock gating
    input                 pl_cxl_wake_ack,        // SPIF: LogPHY acknowledges lp_wake_req to CXL.cachemem Link Layer
    input                 pl_cxl_state_l1,        // SPIF: pl_state_sts is in IDLE_L1_1 on CXL.cachemem SPIF interface
    input                 pl_cxl_state_l2,        // SPIF: pl_state_sts is in L2 on CXL.cachemem SPIF interface
    output                pm_wake_init_rst, // latched version of app_init_rst
    output reg            pm_wake_unlock_msg_req, // latched version of app_unlock_msg
    output                pm_wake_l1_pg_exit, // request l1 power gating wakeup
    output                pm_wake_l1_pg_ack, // power gating can proceed    
    output                pm_wake_any_if_pending, // xfer pendig wakeup from L1 from any internal app
    output                pm_wake_dbi_pending, // DBI transfer pending indication
    output reg            pm_wake_block_pg // Block power gating transition in L1 due to pending transfer or LTSSM sequence
    ,
    output                pm_clkreq_in_n // Synchronized clkreq_in_n
    ,
    output                pm_cxl_cache_slv_req // Synchronized CXL.cache Slave Init request
    ,
    output                pm_cxl_mem_slv_req // Synchronized CXL.mem Slave Init request
    ,
    output reg            pm_smlh_link_retrain, // request to LTSSM to do link retrain
    output reg            pm_wake_req_exit_l0s  // tlp pending to be sent at the XADM interface so exit L0S
);

// ----------------------------------------------------------------------------
// Parameter Declarations
// ----------------------------------------------------------------------------
localparam          SYNC_WIDTH  = 1;
localparam          RST_VAL     = 0;

// ----------------------------------------------------------------------------
// Net Declarations
// ----------------------------------------------------------------------------
wire                    int_sync_slv_awvalid_s;
wire                    int_sync_slv_arvalid_s;
wire                    int_sync_slv_wvalid_s;
wire                    int_sync_dbi_arvalid_s;
wire                    int_sync_dbi_awvalid_s;
wire                    int_sync_dbi_wvalid_s;
wire                    int_dbi_exit_s;
wire                    int_slv_exit_s;
wire                    int_dbi_or_slv_exit_s;
wire                    int_brdg_pg_exit_s;
wire                    int_l1_pg_exit_native_s;
wire                    int_l1_exit_native_s;
wire                    int_req_exit_l0s_s; // tlp pending to be sent so exit L0S
wire                    int_init_rst_s;
wire                    int_link_down_s;
wire                    int_unlock_msg_req_s;
wire                    int_msg_req_s;
wire                    int_cfg_exit_s;
wire                    int_msg_exit_s;
wire                    int_dsp_init_rst_s;
wire                    int_set_block_pg_s;
wire                    int_block_pg_s;
wire                    int_cfg_speed_chg_re_s;
wire                    int_cfg_speed_flag_s;
wire                    int_link_retrain_s;
wire                    int_smlh_link_retrain_s;
wire                    pm_wake_l1_exit;     // PCIe+CXL L1 exit conditions
wire                    pm_wake_pcie_l1;     // PCIe/CXL.io L1 exit conditions
wire                    pm_pcie_l1_exit;
wire                    int_pcie_wake_req;
reg                     int_pcie_wake_req_r;
wire                    pm_wake_cxl_l1;      // CXL.cachemem L1 exit conditions
wire                    int_cxl_wake_req;
reg                     int_cxl_wake_req_r;

// ----------------------------------------------------------------------------
// Reg Declarations
// ----------------------------------------------------------------------------
reg                 int_dbi_or_slv_exit_r;
reg                 int_cfg_exit_r;
reg                 int_msg_exit_r;
reg                 int_init_rst_r;
reg                 int_ltr_msg_req_r;
reg                 int_cfg_dir_speed_chg_r;
reg                 int_cfg_speed_flag_r;
reg                 int_link_retrain_r;

// ----------------------------------------------------------------------------
// BCM synchronizers
// ----------------------------------------------------------------------------
 
// Array of synchronizer instances one for each signal
DWC_pcie_ctl_bcm41

#(
    .WIDTH (SYNC_WIDTH),
    .RST_VAL (RST_VAL),
    .F_SYNC_TYPE (PM_SYNC_DEPTH)
) u_axi_slv_sync[2:0] (
    .clk_d      (aux_clk),
    .rst_d_n    (pwr_rst_n),
    .data_s     ({slv_awvalid, slv_arvalid, slv_wvalid}),
    .data_d     ({int_sync_slv_awvalid_s, int_sync_slv_arvalid_s, int_sync_slv_wvalid_s})
);


assign int_sync_dbi_awvalid_s = 1'b0;
assign int_sync_dbi_arvalid_s = 1'b0;
assign int_sync_dbi_wvalid_s = 1'b0;

assign int_dbi_exit_s = (int_sync_dbi_awvalid_s || int_sync_dbi_arvalid_s || int_sync_dbi_wvalid_s);
assign int_slv_exit_s = (int_sync_slv_awvalid_s || int_sync_slv_arvalid_s || int_sync_slv_wvalid_s);
assign int_dbi_or_slv_exit_s = int_dbi_exit_s || int_slv_exit_s;

// trigger exit from L0S if any of the interfaces header valids are active
// this is necessary for L0S since the core_clk is running in L0S and so any
// of the interfaces to the XADM could become pending
assign int_req_exit_l0s_s = |client0_tlp_hv
                            || |client1_tlp_hv
                            || |client2_tlp_hv
                            || msg_gen_hv
                            || lbc_cpl_hv;

always @(posedge aux_clk or negedge pwr_rst_n)
begin
  if(!pwr_rst_n) begin
    int_dbi_or_slv_exit_r <= #TP 1'b0;
    pm_wake_req_exit_l0s  <= #TP 1'b0;
  end else begin
    int_dbi_or_slv_exit_r <= #TP int_dbi_or_slv_exit_s;
    pm_wake_req_exit_l0s  <= #TP int_req_exit_l0s_s;
  end
end

assign int_brdg_pg_exit_s = int_dbi_or_slv_exit_r && int_dbi_or_slv_exit_s;


wire  sync_clkreq_in_n;
reg   int_sync_clkreq_in_n;

assign pm_clkreq_in_n = int_sync_clkreq_in_n;

// treat as asynchronous signals pclkack and clkreq_in_n
// treat as asynchronous signals clkreq_in_n
DWC_pcie_ctl_bcm41

#(
    .WIDTH (SYNC_WIDTH),
    .RST_VAL (RST_VAL),
    .F_SYNC_TYPE (PM_SYNC_DEPTH)
) u_sync (
    .clk_d    (aux_clk),
    .rst_d_n  (pwr_rst_n),
    .data_s   (clkreq_in_n),
    .data_d   (sync_clkreq_in_n)
);

always @(posedge aux_clk or negedge pwr_rst_n) begin : clkreq_in_n_PROC
  if(!pwr_rst_n)
    int_sync_clkreq_in_n <= #TP 1'b0;
  else
    int_sync_clkreq_in_n <= #TP sync_clkreq_in_n;
end : clkreq_in_n_PROC


wire sync_cxl_cache_slv_req;
reg int_sync_cxl_cache_slv_req_r;

// Synchronized CXL Slave Initialization Request signal for vLSM
assign pm_cxl_cache_slv_req = int_sync_cxl_cache_slv_req_r;

// cxl_cache_slv_req should be treated by the receiver as an asynchronous signal and run
// through appropriate synchronization logic to avoid metastability before use.
// Array of synchronizer instances one for each signal
DWC_pcie_ctl_bcm41

#(
    .WIDTH (SYNC_WIDTH),
    .RST_VAL (RST_VAL),
    .F_SYNC_TYPE (PM_SYNC_DEPTH)
) u_cxl_cache_slv_req_sync (
    .clk_d      (aux_clk),
    .rst_d_n    (pwr_rst_n),
    .data_s     (cxl_cache_slv_req),
    .data_d     (sync_cxl_cache_slv_req)
);

always @(posedge aux_clk or negedge pwr_rst_n)
begin
  if(!pwr_rst_n)
    int_sync_cxl_cache_slv_req_r <= #TP 1'b0;
  else
    int_sync_cxl_cache_slv_req_r <= #TP sync_cxl_cache_slv_req;
end
wire sync_cxl_mem_slv_req;
reg int_sync_cxl_mem_slv_req_r;

// Synchronized CXL Slave Initialization Request signal for vLSM
assign pm_cxl_mem_slv_req = int_sync_cxl_mem_slv_req_r;

// cxl_mem_slv_req should be treated by the receiver as an asynchronous signal and run
// through appropriate synchronization logic to avoid metastability before use.
// Array of synchronizer instances one for each signal
DWC_pcie_ctl_bcm41

#(
    .WIDTH (SYNC_WIDTH),
    .RST_VAL (RST_VAL),
    .F_SYNC_TYPE (PM_SYNC_DEPTH)
) u_cxl_mem_slv_req_sync (
    .clk_d      (aux_clk),
    .rst_d_n    (pwr_rst_n),
    .data_s     (cxl_mem_slv_req),
    .data_d     (sync_cxl_mem_slv_req)
);

always @(posedge aux_clk or negedge pwr_rst_n)
begin
  if(!pwr_rst_n)
    int_sync_cxl_mem_slv_req_r <= #TP 1'b0;
  else
    int_sync_cxl_mem_slv_req_r <= #TP sync_cxl_mem_slv_req;
end

assign int_l1_exit_native_s =  1'b0 
                             || app_obff_idle_msg_req || app_obff_obff_msg_req || app_obff_cpu_active_msg_req
                          ;

assign int_l1_pg_exit_native_s =   int_l1_exit_native_s
; // !DBI_4SLAVE_POPULATED

assign pm_wake_dbi_pending = brdg_dbi_xfer_pending
; // !DBI_4SLAVE_POPULATED


// If app_init_rst is toggled during L1 by the application we latch it and provide
// pm_wake_init_rst to the LTSSM until the link down
assign int_dsp_init_rst_s = app_init_rst && pm_l1_in_progress;
// link is down when isolation has been removed and LTSSM has transitioned to hot reset
assign int_link_down_s = !pm_req_iso_vmain_to_vaux && !smlh_link_up;
assign int_init_rst_s = (int_link_down_s ? 1'b0 : (int_dsp_init_rst_s ? 1'b1 : int_init_rst_r));
// pm_init_rst will either be the normal app_init_rst pulse or driven by
// the latched version during L1
assign pm_wake_init_rst = app_init_rst || int_init_rst_r;

// app_unlock_msg_req is toggled by the application we latch it and provide
// pm_wake_unlock_msg_req to the LTSSM until msg_gen grants the LTR message
assign int_unlock_msg_req_s = (msg_gen_unlock_grant ? 1'b0 : (app_unlock_msg ? 1'b1 : pm_wake_unlock_msg_req));
// vendor message or msi message request
assign int_msg_req_s = ven_msg_req || ven_msi_req 
                                          ;

// For directed speed change a rising edge detect is performed since the
// default value of this bit can be 1. If the rising edge is detected
// during L1 entry a flag is set and only cleared when L1 entry is no
// longer in progress.
assign int_cfg_speed_chg_re_s = !int_cfg_dir_speed_chg_r && cfg_directed_speed_change && pm_l1_in_progress;
assign int_cfg_speed_flag_s = (int_cfg_speed_chg_re_s ? 1'b1 : (!pm_l1_in_progress ? 1'b0 : int_cfg_speed_flag_r));

// create the link retrain flag to trigger L1 exit
assign int_link_retrain_s = ((pm_l1_in_progress && cfg_link_retrain) ? 1'b1 : (!pm_l1_in_progress ? 1'b0 : int_link_retrain_r));
assign int_smlh_link_retrain_s = int_link_retrain_r ? 1'b1 : cfg_link_retrain;

// Configuration access that cause L1 exit
assign int_cfg_exit_s = ((!upstream_port && (cfg_link_dis || int_link_retrain_r || cfg_2nd_reset || cfg_plreg_reset))
                        || (cfg_lpbk_en || int_cfg_speed_flag_s || cfg_directed_width_change));
assign int_msg_exit_s = int_msg_req_s || msg_gen_hv || lbc_cpl_hv;


always @(posedge aux_clk or negedge pwr_rst_n)
begin : l1_exit_PROC
  if(!pwr_rst_n)
  begin
    int_init_rst_r                  <= #TP 1'b0;
    int_ltr_msg_req_r               <= #TP 1'b0;
    pm_wake_unlock_msg_req          <= #TP 1'b0;
    int_cfg_exit_r                  <= #TP 1'b0;
    int_msg_exit_r                  <= #TP 1'b0;
    pm_wake_block_pg                <= #TP 1'b0;
    int_cfg_dir_speed_chg_r         <= #TP 1'b0;
    int_cfg_speed_flag_r            <= #TP 1'b0;
    int_link_retrain_r              <= #TP 1'b0;
    pm_smlh_link_retrain            <= #TP 1'b0;
  end
  else
  begin
    int_init_rst_r                  <= #TP int_init_rst_s;
    int_ltr_msg_req_r               <= #TP app_ltr_msg_req;
    pm_wake_unlock_msg_req          <= #TP int_unlock_msg_req_s;
    int_cfg_exit_r                  <= #TP int_cfg_exit_s;
    int_msg_exit_r                  <= #TP int_msg_exit_s;
    pm_wake_block_pg                <= #TP int_block_pg_s;
    int_cfg_dir_speed_chg_r         <= #TP cfg_directed_speed_change;
    int_cfg_speed_flag_r            <= #TP int_cfg_speed_flag_s;
    int_link_retrain_r              <= #TP int_link_retrain_s;
    pm_smlh_link_retrain            <= #TP int_smlh_link_retrain_s;
  end
end : l1_exit_PROC



wire int_core_edma_bridge_pending;
assign int_core_edma_bridge_pending = (pm_trgt_cpl_lut_empty_n || edma_xfer_pending || lti_xfer_pending || local_msi_xfer_pending || brdg_slv_xfer_pending || pm_radm_idle_n || lbc_active);

assign pm_wake_l1_pg_exit = int_l1_pg_exit_native_s || int_brdg_pg_exit_s || app_xfer_pending;
assign pm_wake_l1_pg_ack = !(int_l1_pg_exit_native_s || int_core_edma_bridge_pending || app_xfer_pending);

// information that at least one of the internal app has something  to transmit 
assign pm_wake_any_if_pending = int_core_edma_bridge_pending || int_l1_exit_native_s || ptm_updating;

assign pm_wake_pcie_l1 = int_init_rst_r || int_ltr_msg_req_r || pm_wake_unlock_msg_req || int_cfg_exit_r || int_msg_exit_r
                         ;

assign pm_wake_cxl_l1  = 1'b0
                         || int_sync_cxl_cache_slv_req_r
                         || int_sync_cxl_mem_slv_req_r
                         ;

assign pm_wake_l1_exit = pm_wake_pcie_l1 || pm_wake_cxl_l1 ;

// Prevent power-gating until L1 exit is complete
assign int_set_block_pg_s = int_init_rst_s || app_ltr_msg_req || int_unlock_msg_req_s || int_cfg_exit_s || int_msg_exit_s;
assign int_block_pg_s = (int_set_block_pg_s ? 1'b1 : (!(pl_pcie_state_l1 || pl_cxl_state_l1) ? 1'b0 : pm_wake_block_pg));

// TBD: get rid off latch_as_entr_l1, use software_entr_l1 from PME Controller
assign pm_pcie_l1_exit  =    software_entr_l23                         // When in L1 and PM turnoff fencing is done.  L2 Entry is requested when in L1 then exit L1->L0->L2
                          || pm_pme_exit_l1                            // Wakeup request exits L1, asserted when EP application wants to sends PME VDM message
                          || app_req_exit_l1                           // Application request to exit L1
                          || pm_wake_any_if_pending                    // Client interface pending indication
                          || app_xfer_pending                          // Application Transfer pending flag
                          || (!xdlh_not_expecting_ack)                 // When there is stuff in retry buffer, we will start again because L1 is not intended to have stuff left in retry buffer
                          || (upstream_port && switch_device && one_dwsp_exit_l1 && latch_as_entr_l1)  // when ASPM enter L1 and down stream port is in exit of L1
                          || pm_wake_pcie_l1;                          // PCIe/CXL L1 exit conditions


assign pm_wake_req      = lp_pcie_wake_req || lp_cxl_wake_req;

// ----------------------------------------------------------------------------
// SPIF PCIe/CXL.io L1 exit and Wake Request/Acknowledge handshake
// ----------------------------------------------------------------------------
assign lp_pcie_l1_exit  = pm_pcie_l1_exit;

assign lp_pcie_wake_req  = (int_pcie_wake_req && !pl_pcie_wake_ack) || int_pcie_wake_req_r;

assign int_pcie_wake_req =    (lp_pcie_l1_exit && pl_pcie_state_l1)     // PCIe/CXL.io  L1 exit protocol requests which trigger a change on lp_state_req
                           || (pm_wake_l2_exit && pl_pcie_state_l2);    // L2 exit wakeup event

// Latched internal WakeUp request
always @(posedge aux_clk or negedge pwr_rst_n) begin
    if (!pwr_rst_n)
        int_pcie_wake_req_r <=  #TP 1'b0;
    // After receiving pm_wake_ack wait for status change to release pm_wake_req.
    // This is required to prevent back-to-back request/acknowledges.
    else if (pl_pcie_wake_ack && !(pl_pcie_state_l1 || pl_pcie_state_l2))
        int_pcie_wake_req_r <=  #TP 1'b0;
    else if (lp_pcie_wake_req)
        int_pcie_wake_req_r <=  #TP 1'b1;
end
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// SPIF CXL.cachemem L1 exit and Wake Request/Acknowledge handshake
// ----------------------------------------------------------------------------
assign lp_cxl_l1_exit   = pm_wake_cxl_l1;

assign lp_cxl_wake_req  = (int_cxl_wake_req && !pl_cxl_wake_ack) || int_cxl_wake_req_r;

assign int_cxl_wake_req =    (lp_cxl_l1_exit  && pl_cxl_state_l1)     // CXL.cachemem L1 exit protocol requests which trigger a change on lp_state_req
                          || (pm_wake_l2_exit && pl_cxl_state_l2);    // L2 exit wakeup event

// Latched internal WakeUp request
always @(posedge aux_clk or negedge pwr_rst_n) begin
    if (!pwr_rst_n)
        int_cxl_wake_req_r <=  #TP 1'b0;
    // After receiving pm_wake_ack wait for status change to release pm_wake_req.
    // This is required to prevent back-to-back request/acknowledges.
    else if (pl_cxl_wake_ack && !(pl_cxl_state_l1 || pl_cxl_state_l2))
        int_cxl_wake_req_r <=  #TP 1'b0;
    else if (lp_cxl_wake_req)
        int_cxl_wake_req_r <=  #TP 1'b1;
end
// ----------------------------------------------------------------------------


endmodule
