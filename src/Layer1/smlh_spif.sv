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
// --- RCS information:
// ---  $DateTime: 2024/02/19 04:20:14 $
// ---  $Revision: #7 $
// ---  $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/smlh_spif.sv#7 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Physical Layer SPIF Interface
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"
// SPIF Interface
`include "Spif/pkg/spif_pkg.svh"
`include "Spif/svif/spif_if.svh"

module smlh_spif
  import DWC_pcie_core_pkg::ltssm_state_e;
  import DWC_pcie_core_pkg::S_DETECT_QUIET;
  import DWC_pcie_core_pkg::S_POLL_ACTIVE;
  import DWC_pcie_core_pkg::S_POLL_CONFIG;
  import DWC_pcie_core_pkg::S_PRE_DETECT_QUIET;
  import DWC_pcie_core_pkg::S_CFG_LINKWD_START;
  import DWC_pcie_core_pkg::S_CFG_COMPLETE;
  import DWC_pcie_core_pkg::S_CFG_IDLE;
  import DWC_pcie_core_pkg::S_RCVRY_LOCK;
  import DWC_pcie_core_pkg::S_RCVRY_RCVRCFG;
  import DWC_pcie_core_pkg::S_RCVRY_SPEED;
  import DWC_pcie_core_pkg::S_L0;
  import DWC_pcie_core_pkg::S_L0S;
  import DWC_pcie_core_pkg::S_L1_IDLE;
  import DWC_pcie_core_pkg::S_L2_IDLE;
  import DWC_pcie_core_pkg::S_DISABLED_ENTRY;
  import DWC_pcie_core_pkg::S_DISABLED;
  import DWC_pcie_core_pkg::S_LPBK_ENTRY;
  import DWC_pcie_core_pkg::S_LPBK_ACTIVE;
  import DWC_pcie_core_pkg::S_LPBK_EXIT;
  import DWC_pcie_core_pkg::S_HOT_RESET_ENTRY;
  import DWC_pcie_core_pkg::S_HOT_RESET;
  import spif_pkg::*;                                          // Import SPIF package
#(
  parameter  TP            = `TP
) 
                  (
  // Interfaces
  spif_if.smlh_master_mp               b_smlh_spif,            // Physical Layer to Link Layer SPIF interface
  // Inputs
  input                                core_clk,               // Core clock
  input                                core_rst_n,             // Core reset
  input  [3:0]                         device_type,            // Device Type
  input                                cfg_no_eq_needed_enable,// Enable no equalization needed feature
  input                                pm_smlh_entry_to_l0s,   // PM requests LTSSM to enter L0S
  input                                pm_smlh_entry_to_l1,    // PM requests LTSSM to enter L1
  input                                pm_smlh_entry_to_l2,    // PM requests LTSSM to enter L2
  input  [2:0]                         smlh_data_rate,         // Current Link Speed: 0 - Gen1, 1 - Gen2, 2 - Gen3, etc.
  input  [2:0]                         smlh_cclk_rate,         // Current clock ratio
  input  [5:0]                         smlh_link_mode,         // LTSSM Link Mode
  input  [5:0]                         smlh_l0p_link_mode,     // LTSSM L0p Link Mode
  input                                smlh_ltssm_in_l0p,      // LTSSM is in L0p
  input                                smlh_ltssm_l0p_ready,   // LTSSM is ready for L0p request
  input                                smlh_link_eios_rcvd,    // LTSSM received EIOSQ Ordered Set on a link
  input                                smlh_link_tsos_rcvd,    // LTSSM received TS Ordered Set on a link
  input  ltssm_state_e                 smlh_ltssm_state,       // LTSSM State
  input                                smlh_req_rst_not,       // LTSSM is in Link Down
  input                                smlh_link_up,           // PLH link up
  input                                smlh_in_l0,             // LTSSM is in L0 state after initial link training is complete
  input                                smlh_rx_in_l0,          // LTSSM RX path is in L0
  input                                smlh_in_l1,             // LTSSM is in L1
  input                                smlh_in_l2,             // LTSSM is in L2
  input                                smlh_in_retrain,        // LTSSM is in RETRAIN
  input                                smlh_in_txl0s,          // LTSSM in transmit L0s state
  input                                smlh_in_rxl0s,          // LTSSM in receive L0s state
  input                                smlh_lpbk_master,       // LTSSM is loopback master
  input                                smlh_idle_hs_done,      // LTSSM indication that IDLE Handshake Complete
  input                                smlh_flit_mode_enable,  // Link is negotiated in PCIe Flit mode
  input                                cxl_link_enable,        // CXL link is enabled
  input  [6:0]                         cxl_prot_enable,        // Negotiated Protocol Enable bits
  input                                rasdp_linkdown,         // Link down request from RASDP logic
  input                                pm_pl_wake_ack,         // PM Controller Wakeup Acknowledge
  input                                pm_pl_clk_req,          // PM Controller Clock Request
  input                                pm_pl_phyinl1,          // PM Controller PHY in L1
  input                                pm_pl_phyinl2,          // PM Controller PHY in L2
  input                                sdlh_linkmode_req,      // SDLH L0p Link Mode Change Request
  input                                sdlh_linkmode_loc,      // SDLH L0p Local (Link Initiated) Request
  input  [4:0]                         sdlh_linkmode,          // SDLH L0p Requested Link Mode
  // Outputs
  output  protocol_cfg_t               pl_protocol_cfg,        // Protocol Configuration for PLH Layer
  output                               spif_smlh_in_l0,        // LTSSM is in L0 gated with CXL link enabled
  output logic                         smlh_linkmode_req,      // L0p Link Mode Change Request
  output logic                         smlh_linkmode_loc,      // L0p Link Mode Local (Link Initiated) Request
  output logic [4:0]                   smlh_linkmode,          // L0p Requested Link Mode
  output                               smlh_req_retrain,       // Request LTSSM to go into recovery
  output                               smlh_req_reset,         // Request LTSSM to go into link reset
  output                               smlh_req_linkerror      // Request LTSSM to go into PRE_DETECT_QUIET state
);

state_enc_e      pl_state_sts_r, pl_state_sts_nxt;
logic            pl_block_dl_init_r, pl_block_dl_init_nxt;
logic            pl_stall_req_r, pl_stall_req_nxt;
logic            pl_rx_active_req_r, pl_rx_active_req_nxt;
logic            pl_link_down_ena_r, pl_link_down_ena_nxt;
logic            pl_phyinretrain_r, pl_phyinretrain_nxt;
logic            smlh_link_error_s;
logic            smlh_lpbk_active_s;                     // Indicates that Looback Lead is in Loopback.Active state
logic            smlh_lpbk_exit_r , smlh_lpbk_exit_nxt ; // Latch when LTSSM enter Looback.Exit state to gate LINKERROR indication
logic            pl_inband_pres_r , pl_inband_pres_nxt ;
logic            pl_protocol_vld_r, pl_protocol_vld_nxt;
protocol_type_e  pl_protocol_r    , pl_protocol_nxt    ;
protocol_fmt_e   pl_protocol_fmt_r, pl_protocol_fmt_nxt;
logic            cfg_complete_r   , cfg_complete_nxt   ;
logic            smlh_retrain_enable;                  // Enables exposing LTSSM transitions to Recovery to Link Layer
logic            smlh_exp_rcvry_r, smlh_exp_rcvry_nxt; // LogPHY expose recovery to Link Layer (vLSM)
logic            pl_cxl_enabled_r, pl_cxl_enabled_nxt; // This flag is set after initial link training is complete in CXL mode
logic            cxl_link_enable_r;                    // Latch CXL link enable flag until core_rst_n
logic            cxl_link_enable_s;
logic            pl_device_mode;
logic            pl_device_mode_r, pl_device_mode_s;
logic [5:0]      smlh_link_mode_r, smlh_link_mode_s;   // Link Mode indication from LTSSM on SPIF Interface
logic            rx_deactivated_chk;                   // Checks that RX datapath is de-activated
logic            smlh_in_retrain_s;                    // smlh_in_retrain && !smlh_rx_in_l0

assign cxl_link_enable_s  = cxl_link_enable ? 1'b1 : cxl_link_enable_r;
// If CXL mode was negotiated and LTSSM transitions to L0 state while CXL link is not up then request a link retrain.
// This is required when no equalization is enabled to retrain from Gen1 directly to the target speed after the recovery.
assign smlh_req_retrain   = (b_smlh_spif.s_lp_state_req == RETRAIN) || (cfg_no_eq_needed_enable && smlh_in_l0 && !spif_smlh_in_l0);
assign smlh_req_reset     = b_smlh_spif.s_lp_state_req == LINKRESET;
assign smlh_req_linkerror = pl_protocol_cfg.spif_enable ? b_smlh_spif.s_lp_linkerror : (1'b0 || rasdp_linkdown);
// In CXL mode if CXL link is not enabled, i.e. LTSSM failed to reach 8GT/s, gate smlh_in_l0 indication to upper layers
assign spif_smlh_in_l0    = smlh_in_l0 && (pl_protocol_cfg.cxl_mode_enable ? cxl_link_enable_s : 1'b1);
// In CXL 68B flit mode, do not expose LTSSM transition to L0 and Recovery until the link is trained to the target speed
// Transition to RETRAIN is only possible from ACTIVE state or sub-states and from L1 state.
assign smlh_retrain_enable = (pl_state_sts_r inside {ACTIVE, ACTIVE_L0S_PMNAK, IDLE_L1_1}) && (pl_protocol_cfg.cxl_mode_enable ? ( pl_protocol_cfg.cxl_pcie_flit_mode ? cxl_link_enable_s : pl_cxl_enabled_r) : pl_protocol_cfg.pcie_mode_enable);
assign smlh_lpbk_active_s = (smlh_ltssm_state == S_LPBK_ACTIVE) && smlh_lpbk_master;
assign smlh_link_mode_s   = smlh_ltssm_in_l0p ? (smlh_ltssm_l0p_ready ? smlh_l0p_link_mode : smlh_link_mode_r) : smlh_link_mode;

// In CXL mode indicate pl_link_up only after reaching Gen3 speed
assign b_smlh_spif.s_pl_link_up       = smlh_link_up && (pl_protocol_cfg.cxl_mode_enable ? cxl_link_enable_s : pl_protocol_cfg.pcie_mode_enable);
assign b_smlh_spif.s_pl_link_down     = pl_link_down_ena_r && !smlh_req_rst_not && (pl_protocol_cfg.cxl_mode_enable ? cxl_link_enable_s : (pl_protocol_cfg.spif_enable  && pl_protocol_cfg.pcie_mode_enable)) ;
assign b_smlh_spif.s_pl_rx_active_req = pl_rx_active_req_r || pl_rx_active_req_nxt; // Assert early with the next signal not to drop received flits
assign b_smlh_spif.s_pl_stall_req     = pl_stall_req_r;
assign b_smlh_spif.s_pl_block_dl_init = pl_block_dl_init_r;
assign b_smlh_spif.s_pl_protocol_vld  = pl_protocol_vld_r;
assign b_smlh_spif.s_pl_protocol      = pl_protocol_r;
assign b_smlh_spif.s_pl_protocol_fmt  = pl_protocol_fmt_r;
assign b_smlh_spif.s_pl_inband_pres   = pl_inband_pres_r;
assign b_smlh_spif.s_pl_device_port   = pl_device_mode;
assign b_smlh_spif.s_pl_phyinl1       = pm_pl_phyinl1;
assign b_smlh_spif.s_pl_phyinl2       = pm_pl_phyinl2;
assign b_smlh_spif.s_pl_phyinrxl0s    = smlh_in_rxl0s;
// For PCIe asserted when RX enters recovery (TS OS received), pl_state_sts indicates when TX enter recovery
// For CXL asserted with pl_state_sts only after an exit from RESET state otherwise follows PCIe behaviour
assign b_smlh_spif.s_pl_phyinretrain  = (pl_protocol_cfg.cxl_mode_enable && (pl_state_sts_r != RESET)) ? (pl_state_sts_r == RETRAIN) : pl_phyinretrain_r;
assign b_smlh_spif.s_pl_phyrcvdeiosq  = smlh_link_eios_rcvd;
assign b_smlh_spif.s_pl_speedmode     = smlh_data_rate;
assign b_smlh_spif.s_pl_linkmode      = smlh_link_mode_s;
assign b_smlh_spif.s_pl_bw_ratio      = smlh_cclk_rate;
assign b_smlh_spif.s_pl_wake_ack      = pm_pl_wake_ack;
assign b_smlh_spif.s_pl_clk_req       = pm_pl_clk_req;

// ----------------------------------------------------------------------------
// Device Type decoding
// ----------------------------------------------------------------------------
assign pl_device_mode_s = (device_type == `PCIE_RC);

delay_n
 #(
    .N        (1),
    .WD       (1)
) u_delay_device_mode (
    .clk      (core_clk),
    .rst_n    (core_rst_n),
    .clear    (1'b0),
    .din      ({pl_device_mode_s}),
    .dout     ({pl_device_mode_r})
);

// Quasi static registers
DWC_pcie_ctl_bcm36_nhs
 #(
    .WIDTH    (1)
) u_bcm36_nhs_device_mode (
  `ifndef SYNTHESIS
    .clk_d    (core_clk),
    .rst_d_n  (core_rst_n),
  `endif // SYNTHESIS
    .data_s   ({pl_device_mode_r}),
    .data_d   ({pl_device_mode  })
);
// ----------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Protocol Decoder Instantiation to be used on the hierarchy level
// -------------------------------------------------------------------------------------
spif_protocol_dec
 u_spif_protocol (
    // Inputs
    .core_clk              ( core_clk                      ),
    .core_rst_n            ( core_rst_n                    ),
    .pl_protocol_vld       ( b_smlh_spif.s_pl_protocol_vld ),
    .pl_protocol           ( b_smlh_spif.s_pl_protocol     ),
    .pl_protocol_fmt       ( b_smlh_spif.s_pl_protocol_fmt ),
    // Outputs
    .pl_protocol_cfg       ( pl_protocol_cfg               )
);
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// In-band presence detect indication from logPHY. It is asserted according to rules
// outlined in PCIe BaseSpec, when logPhy enter Polling.Configuration
// -------------------------------------------------------------------------------------
always_comb begin
    // Set on entry to Polling.Configuration
    if (smlh_ltssm_state == S_POLL_CONFIG)
        pl_inband_pres_nxt = 1'b1;
    // Reset on transition to Detect
    else if ((smlh_ltssm_state == S_DETECT_QUIET) || (smlh_ltssm_state == S_PRE_DETECT_QUIET))
        pl_inband_pres_nxt = 1'b0;
    else
        pl_inband_pres_nxt = pl_inband_pres_r;
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Negotiated Protocol and Flit Format
// -------------------------------------------------------------------------------------
always_comb begin
    if (smlh_ltssm_state == S_DETECT_QUIET)
        cfg_complete_nxt = 1'b0;
    else if ((smlh_ltssm_state == S_CFG_IDLE) && !cfg_complete_r)
        cfg_complete_nxt = 1'b1;
    else if ((smlh_ltssm_state == S_LPBK_ENTRY) && !cfg_complete_r)
        cfg_complete_nxt = 1'b1;
    else
        cfg_complete_nxt = cfg_complete_r;
end

always_comb begin
    if (cfg_complete_r)
        pl_protocol_vld_nxt = 1'b1;
    else if (smlh_ltssm_state == S_DETECT_QUIET)
        pl_protocol_vld_nxt = 1'b0;
    else
        pl_protocol_vld_nxt = pl_protocol_vld_r;
end

always_comb begin
    if (cfg_complete_r) begin
        // {MLD, CACHE, MEM, IO}
        casez ({cxl_prot_enable[6], cxl_prot_enable[2:0]})
            4'b?_001 : pl_protocol_nxt = CXL_MODE1; // CXL.1 [Single protocol, i.e. CXL.io]
            4'b?_101 : pl_protocol_nxt = CXL_MODE2; // CXL.2 [Multi-protocol, Type 1 device]
            4'b?_111 : pl_protocol_nxt = CXL_MODE3; // CXL.3 [Multi-protocol, Type 2 device]
            4'b0_011 : pl_protocol_nxt = CXL_MODE4; // CXL.4 [Multi-protocol, Type 3 SLD device]
            4'b1_011 : pl_protocol_nxt = CXL_MODE5; // CXL.5 [Multi-protocol, Type 3 MLD device]
            default  : pl_protocol_nxt = PCIE_MODE; // PCIe
        endcase
    end
    else pl_protocol_nxt = pl_protocol_r;
end

always_comb begin
    if (cfg_complete_r) begin
        case ({cxl_prot_enable[0], smlh_flit_mode_enable, cxl_prot_enable[5:3]})
            5'b01000: pl_protocol_fmt_nxt = FMT_PCIE_FLIT ; // PCIe 256B Flit Mode
            5'b10000: pl_protocol_fmt_nxt = FMT_CXL_68B   ; // CXL1.1 68B Flit Mode
            5'b10001: pl_protocol_fmt_nxt = FMT_CXL_68BVH ; // CXL2.0 68B Flit Mode
            5'b11000: pl_protocol_fmt_nxt = FMT_CXL_256B  ; // CXL3.0 256B Standard Flit Mode (HBR)
            5'b11100: pl_protocol_fmt_nxt = FMT_CXL_LOPT  ; // CXL3.0 256B Latency Optimized Flit Mode
            5'b11010: pl_protocol_fmt_nxt = FMT_CXL_PBR   ; // CXL3.0 256B Standard Flit Mode (PBR)
            default : pl_protocol_fmt_nxt = FMT_NONE_FLIT ; // PCIe none-Flit Mode
        endcase
    end
    else pl_protocol_fmt_nxt = pl_protocol_fmt_r;
end
// -------------------------------------------------------------------------------------

// LTSSM States Mapping
assign b_smlh_spif.s_pl_state_sts = pl_state_sts_r;

// Skip RX de-activation check on transition to L0s
assign rx_deactivated_chk = ((smlh_ltssm_state == S_L0S) && smlh_in_txl0s) ? 1'b1 : (!b_smlh_spif.s_pl_rx_active_req && !b_smlh_spif.s_lp_rx_active_sts);

// Indicate link error when LTSSM moves to PRE_DETECT_QUIET while SPIF is in RESET, ACTIVE, RETRAIN, or IDLE_L1_1 state
// Wait for smlh_req_rst_not to be asserted in CFG_IDLE state to enable LINKERROR state transition
assign smlh_link_error_s = (smlh_ltssm_state == S_PRE_DETECT_QUIET) && smlh_req_rst_not && !smlh_lpbk_exit_r && (b_smlh_spif.s_pl_state_sts inside {RESET, ACTIVE, RETRAIN, IDLE_L1_1});

always_comb begin
    if (smlh_link_error_s) begin
        pl_state_sts_nxt =  LINKERROR;
    end
    // As long as SPIF transitions are restricted to CXL mode then handle LINKERROR to RESET transition outside of the case statement
    else if ((pl_state_sts_r == LINKERROR) && (smlh_ltssm_state == S_DETECT_QUIET)) begin
        pl_state_sts_nxt = RESET;
    end
    // A state transition on pl_state_sts from ACTIVE to any other state must only occur on 
    // clocks in which both pl_stall_req and lp_stall_ack are both asserted (except LINKERROR).
    else if (pl_protocol_cfg.spif_enable && ((pl_state_sts_r == ACTIVE) ? (b_smlh_spif.s_pl_stall_req && b_smlh_spif.s_lp_stall_ack && rx_deactivated_chk) : 1'b1)) begin
        // LTSSM State Mapping
        case (smlh_ltssm_state)
            S_DETECT_QUIET     : pl_state_sts_nxt = RESET          ;
            S_POLL_ACTIVE      : pl_state_sts_nxt = RESET          ;
            S_POLL_CONFIG      : pl_state_sts_nxt = RESET          ; // Reset if Configuration was entered from Polling
            S_CFG_LINKWD_START,
            S_RCVRY_SPEED,
            S_RCVRY_RCVRCFG    : if (smlh_retrain_enable) pl_state_sts_nxt = RETRAIN; // Retrain if Configuration was entered from Recovery
                                                                                      // Do not expose recovery to vLSM during initial link training
                                 else                     pl_state_sts_nxt = pl_state_sts_r;
            S_L0               : if (b_smlh_spif.s_lp_state_req == ACTIVE) pl_state_sts_nxt =  ACTIVE; // Function of statereq=ACTIVE and LTSSM in L0
                                 else                                      pl_state_sts_nxt = pl_state_sts_r;
            S_L0S              : if (smlh_in_txl0s) pl_state_sts_nxt = ACTIVE_L0S_PMNAK; // TxL0s is a substate of ACTIVE
                                 else               pl_state_sts_nxt = pl_state_sts_r;
            S_L1_IDLE          : pl_state_sts_nxt = IDLE_L1_1      ;
            S_L2_IDLE          : pl_state_sts_nxt = L2             ;
            S_DISABLED         : pl_state_sts_nxt = DISABLED       ;
            S_HOT_RESET        : pl_state_sts_nxt = LINKRESET      ;
            S_LPBK_ENTRY       : pl_state_sts_nxt = RESET          ; // On Loopback.Entry change interface state to RESET state
            S_LPBK_ACTIVE      : if ((b_smlh_spif.s_lp_state_req == ACTIVE) && smlh_lpbk_active_s) pl_state_sts_nxt =  ACTIVE; // Function of statereq=ACTIVE and LTSSM in Loopback.Active
                                 else                                                              pl_state_sts_nxt = pl_state_sts_r;
            S_LPBK_EXIT        : pl_state_sts_nxt = RESET          ; // On Loopback.Exit change interface state to RESET state
            default            : pl_state_sts_nxt = pl_state_sts_r ;
        endcase
    end
    else pl_state_sts_nxt = pl_state_sts_r;
end

always_comb begin
    // If Link Layer requests PM entry then initiate stall_req/ack handshake
    if (/*b_smlh_spif.s_lp_state_req inside {IDLE_L1_1, L2}*/pm_smlh_entry_to_l1 || pm_smlh_entry_to_l2 || pm_smlh_entry_to_l0s)
       pl_stall_req_nxt = !b_smlh_spif.s_lp_stall_ack ? 1'b1 : pl_stall_req_r;
    // If LTSSM transitions to Link Recovery, Link Disable, Link Reset or it is on transition to Reset state then initiate stall_req/ack handshake
    else if (smlh_ltssm_state inside {S_PRE_DETECT_QUIET, S_DETECT_QUIET, S_RCVRY_LOCK, S_HOT_RESET_ENTRY, S_DISABLED_ENTRY, S_LPBK_EXIT})
       pl_stall_req_nxt = !b_smlh_spif.s_lp_stall_ack ? 1'b1 : pl_stall_req_r;
    // For CXL, Physical Layer must keep pl_stall_req asserted until it is ready to transition to
    // final ACTIVE state for link operation. It may go through several ACTIVE-RETRAIN-ACTIVE arcs
    // while pl_stall_req is asserted
    else if (pl_protocol_cfg.spif_enable && ( smlh_lpbk_active_s ? smlh_idle_hs_done : spif_smlh_in_l0))
       pl_stall_req_nxt =  b_smlh_spif.s_lp_stall_ack ? 1'b0 : pl_stall_req_r;
    else
       pl_stall_req_nxt = pl_stall_req_r;
end

always_comb begin
    // SPIF-BLOCK-RULE3: A falling edge on pl_block_dl_init shall only occur after initial link training 
    // when pl_state_sts is ACTIVE and lp_rx_active_sts is asserted
    if ((b_smlh_spif.s_pl_state_sts == ACTIVE) && b_smlh_spif.s_lp_rx_active_sts)
        pl_block_dl_init_nxt = 1'b0;
    // SPIF-BLOCK-RULE2: A rising edge on pl_block_dl_init shall only occur 
    // when lp_dl_active is de-asserted and pl_state_sts is RESET
    else if ((b_smlh_spif.s_pl_state_sts == RESET) && !b_smlh_spif.s_lp_dl_active)
        pl_block_dl_init_nxt = 1'b1;
    else
        pl_block_dl_init_nxt = pl_block_dl_init_r;
end

always_comb begin
    if (pl_protocol_cfg.spif_enable && b_smlh_spif.s_pl_link_up && (smlh_rx_in_l0 || smlh_lpbk_active_s))
        pl_rx_active_req_nxt = !b_smlh_spif.s_lp_rx_active_sts ? 1'b1 : pl_rx_active_req_r;
    else if (pl_rx_active_req_r && (!smlh_rx_in_l0 || (smlh_ltssm_state == S_LPBK_EXIT)))
        pl_rx_active_req_nxt =  b_smlh_spif.s_lp_rx_active_sts ? 1'b0 : pl_rx_active_req_r;
    else
        pl_rx_active_req_nxt = pl_rx_active_req_r;
end

always_comb begin
    // Set CXL mode enable flag on SMLH link up if CXL is enabled
    if (cxl_link_enable_s && (smlh_in_l0 || (b_smlh_spif.s_lp_state_req == RETRAIN)))
        pl_cxl_enabled_nxt = 1'b1;
    // Reset CXL mode enable flag on transition to RESET state
    else if ((pl_state_sts_r != RESET) && (pl_state_sts_nxt == RESET))
        pl_cxl_enabled_nxt = 1'b0;
    else
        pl_cxl_enabled_nxt = pl_cxl_enabled_r;
end

always_comb begin
    // Reset Loopback exit flag when LTSSM reaches S_DETECT_QUIET state
    if (smlh_ltssm_state == S_DETECT_QUIET)
        smlh_lpbk_exit_nxt = 1'b0;
    // Latch when LTSSM enters Looback.Exit state to gate LINKERROR indication on
    // the following LTSSM transition to S_PRE_DETECT_QUIET state during exit from Loobmack mode
    else if (smlh_ltssm_state == S_LPBK_EXIT)
        smlh_lpbk_exit_nxt = 1'b1;
    else
        smlh_lpbk_exit_nxt = smlh_lpbk_exit_r;
end

always_comb begin
    // Wait for risign edge of smlh_req_rst_not to enable link down event detection
    if (smlh_req_rst_not)
        pl_link_down_ena_nxt = 1'b1;
    else
        pl_link_down_ena_nxt = pl_link_down_ena_r;
end

assign smlh_in_retrain_s = smlh_in_retrain && !smlh_rx_in_l0;

always_comb begin
    // TBD: cannot use smlh_link_tsos_rcvd at the moment as the verification is still based on LTSSM state
    // Temporary using (smlh_ltssm_state != S_RCVRY_LOCK) until the verification updates
    if (/*smlh_link_tsos_rcvd && */(smlh_ltssm_state != S_RCVRY_LOCK) && smlh_in_retrain_s)
        pl_phyinretrain_nxt = pl_protocol_cfg.cxl_mode_enable ? smlh_exp_rcvry_r : 1'b1;
    else if (!smlh_in_retrain_s)
        pl_phyinretrain_nxt = 1'b0;
    else
        pl_phyinretrain_nxt = pl_phyinretrain_r;
end

always_comb begin
    if (!b_smlh_spif.s_pl_link_up)
        smlh_exp_rcvry_nxt = 1'b0;
    else if ((pl_state_sts_r == RESET) && spif_smlh_in_l0)
        smlh_exp_rcvry_nxt = 1'b1;
    else
        smlh_exp_rcvry_nxt = smlh_exp_rcvry_r;
end

// -------------------------------------------------------------------------------------
// L0p Interface to LTSSM
// -------------------------------------------------------------------------------------
logic lp_linkmode_req_s;
logic lp_linkmode_req_r;

// Request L0p Link Mode change request if Link Layer requested Link Mode is different
// from the current LogPHY Link Mode and LTSSM is ready for L0p request.
assign lp_linkmode_req_s = (b_smlh_spif.s_lp_linkmode != b_smlh_spif.s_pl_linkmode) && smlh_ltssm_l0p_ready && !pl_protocol_cfg.cxl_mode_enable;

always_comb begin
    if (!pl_protocol_cfg.spif_enable) begin
        smlh_linkmode_req = sdlh_linkmode_req;
        smlh_linkmode_loc = sdlh_linkmode_loc;
        smlh_linkmode     = sdlh_linkmode;
    end else if (lp_linkmode_req_s && !lp_linkmode_req_r) begin
        // Pulse to preserve current interface to LTSSM
        smlh_linkmode_req = 1'b1;
        smlh_linkmode_loc = !b_smlh_spif.s_lp_linkmode_rmt;
        smlh_linkmode     =  b_smlh_spif.s_lp_linkmode[4:0];
    end else begin
        smlh_linkmode_req = '0;
        smlh_linkmode_loc = '0;
        smlh_linkmode     = '0;
    end
end
// -------------------------------------------------------------------------------------

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
        pl_state_sts_r     <= # TP RESET;
        pl_block_dl_init_r <= # TP 1'b0;
        pl_stall_req_r     <= # TP 1'b0;
        pl_rx_active_req_r <= # TP 1'b0;
        pl_inband_pres_r   <= # TP 1'b0;
        pl_protocol_vld_r  <= # TP 1'b0;
        pl_protocol_r      <= # TP PCIE_MODE;
        pl_protocol_fmt_r  <= # TP FMT_NONE_FLIT;
        pl_link_down_ena_r <= # TP 1'b0;
        pl_phyinretrain_r  <= # TP 1'b0;
        cfg_complete_r     <= # TP 1'b0;
        smlh_link_mode_r   <= # TP 6'd0;
        smlh_lpbk_exit_r   <= # TP 1'b0;
        smlh_exp_rcvry_r   <= # TP 1'b0;
        pl_cxl_enabled_r   <= # TP 1'b0;
        cxl_link_enable_r  <= # TP 1'b0;
        lp_linkmode_req_r  <= # TP 1'b0;
    end else begin
        pl_state_sts_r     <= # TP pl_state_sts_nxt;
        pl_block_dl_init_r <= # TP pl_block_dl_init_nxt;
        pl_stall_req_r     <= # TP pl_stall_req_nxt;
        pl_rx_active_req_r <= # TP pl_rx_active_req_nxt;
        pl_inband_pres_r   <= # TP pl_inband_pres_nxt;
        pl_protocol_vld_r  <= # TP pl_protocol_vld_nxt;
        pl_protocol_r      <= # TP pl_protocol_nxt;
        pl_protocol_fmt_r  <= # TP pl_protocol_fmt_nxt;
        pl_link_down_ena_r <= # TP pl_link_down_ena_nxt;
        pl_phyinretrain_r  <= # TP pl_phyinretrain_nxt;
        cfg_complete_r     <= # TP cfg_complete_nxt;
        smlh_link_mode_r   <= # TP smlh_link_mode_s;
        smlh_lpbk_exit_r   <= # TP smlh_lpbk_exit_nxt;
        smlh_exp_rcvry_r   <= # TP smlh_exp_rcvry_nxt;
        pl_cxl_enabled_r   <= # TP pl_cxl_enabled_nxt;
        cxl_link_enable_r  <= # TP cxl_link_enable_s;
        lp_linkmode_req_r  <= # TP lp_linkmode_req_s;
    end
end


endmodule
