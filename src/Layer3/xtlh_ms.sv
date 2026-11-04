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
// ---    $DateTime: 2024/01/25 10:42:16 $
// ---    $Revision: #19 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/xtlh_ms.sv#19 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
// XTLH Multistream Architecture
//
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "products/cx_pl_pkg.svh"
`include "Layer3/xtlh_ms_pkg.svh"

module xtlh_ms
  import  DWC_pcie_ctl_pkg::N_XADM_P_IF_VC;
  import  DWC_pcie_ctl_pkg::N_XADM_NP_IF_VC;
  import  DWC_pcie_ctl_pkg::N_XADM_CPL_IF_VC;
  import  DWC_pcie_ctl_pkg::N_XADM_CUMULATIVE_PER_VC;
  import  DWC_pcie_ctl_pkg::N_XADM_IF;
  import  DWC_pcie_ctl_pkg::NVC;
  import  DWC_pcie_ctl_pkg::N_XADM_IF_VC;
  import  DWC_pcie_ctl_pkg::N_XADM_P_IF;
  import DWC_pcie_ctl_pkg::N_XADM_P_CUMULATIVE_PER_VC;
  import  DWC_pcie_core_pkg::xtlh_pkt_t;
  import  cx_pl_pkg::CMD_NOP;
  import  cx_pl_pkg::CMD_FLUSH_XTLH;
  import  cx_pl_pkg::CMD_PYLD;
  import  DWC_pcie_ctl_pkg::ERROR_INJ_EN_WD;
  import  DWC_pcie_ctl_pkg::ERROR_INJ_MASK_WD;
  import  xtlh_ms_pkg::P_FC_MERGE_LOG_WD;
  import  cx_pl_pkg::tx_flit_struct;
  import  cx_pl_pkg::P_NVC;
  import  xtlh_ms_pkg::P_XTLH_MAX_TLP_CNT_WD;
  import  cx_pl_pkg::tx_cmd_struct;
  import  cx_pl_pkg::DW_W_PAR;
  import  cx_pl_pkg::P_DW;
  import  cx_pl_pkg::P_NW;
  import  cx_pl_pkg::P_NFM_NW;
  import  cx_pl_pkg::P_NFM_DW;
  import  cx_pl_pkg::NFM_DW_W_PAR;
  import  cx_pl_pkg::CMD_FLUSH_XAIM;
  import  xtlh_ms_pkg::P_N_TLP_LEN;
  import  xtlh_ms_pkg::xtlh_vc_pkt_struct;
  import  xtlh_ms_pkg::tlp_end_struct;
  import  xtlh_ms_pkg::P_NW_CNT_WD;
  import  xtlh_ms_pkg::P_NW_PROT;
    import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
    import DWC_pcie_ctl_pkg::RAS_DP_PROT_CHK_ID_BASE_XTLH;
      import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
#(
  parameter TP = `TP
) 
                (
  input                                                       core_clk,                   // Core Clock
  input   [6:0]                                               cfg_tx_arb_control,
  input                                                       core_rst_n,                 // Core Reset
  input                                                       spif_enable,                // SPIF Enable
  input                                                       cdm_err_inj_en,             // Error Injection Enable Signal for the capability
  input                                                       cdm_tx_err_inj_en,          // Error Injection Enable Signal for the Transmit Path
  input   xtlh_pkt_t                  [N_XADM_IF-1:0]         xadm_xtlh_pkt,              // XADM Packet Interfaces
  output  logic                       [N_XADM_IF-1:0]         xtlh_xadm_pkt_halt,         // XTLH XADM Halt
  input   tx_cmd_struct                                       xdlh_xtlh_cmd,              // Command interface
  output  logic                                               xtlh_xdlh_cmd_ack           // Command Acknowledge to XDLH
  ,
  // XTLH Flit Interface
  output  tx_flit_struct                                      xtlh_xdlh_flit,             // XTLH Flit
  input   [P_NVC-1:0]                                         xdlh_xtlh_fc_init_done      // Per VC FC init done indication
  ,
  input                                                       xdlh_xtlh_halt,             // Downstream Halt
  output  logic                                               xtlh_tlp_pending,           // TLP Pending Indication
  input                                                       rstctl_core_flush_req       // Flush Request
  ,
  input                                                       cfg_rasdp_error_mode,       // RASDP Error Mode
  input                                                       xdlh_rasdp_error_mode       // XDLH RASDP Error Mode
    ,
    output ras_dp_err_log_t                                   ras_dp_err_log
      ,
      input  ras_dp_err_inj_t                                 ras_dp_err_inj
  // XTLH Packet Interface
  ,
  output  logic                       [10:0]                  xtlh_xdlh_tlp_len           // TLP Length
  ,
  output  logic                       [NFM_DW_W_PAR-1:0]      xtlh_xdlh_data,             // TLP Data
  output  logic                                               xtlh_xdlh_dv,               // Data Valid
  output  logic                       [P_NFM_NW-1:0]          xtlh_xdlh_sot,              // Start of TLP
  output  logic                       [P_NFM_NW-1:0]          xtlh_xdlh_eot,              // End of TLP
  output  logic                       [P_NFM_NW-1:0]          xtlh_xdlh_badeot,           // Bad Eot
  output  logic                                               xtlh_xdlh_sot_is_first,     // SOT Is first
  output  logic                                               xtlh_xdlh_badeot_or,        // Indicates an EOT on any Data Word
  output  logic                                               xtlh_xdlh_first_badeot,     // Indicates the first Bad EOT
  output  logic                                               xtlh_xdlh_eot_sot,          // Indicates EOT and SOT in this cycle
  output  logic                                               xtlh_xdlh_eot_sot_eot,      // Indicates EOT, SOT and EOT in this cycle
  output  logic                                               xtlh_pm_pme_to_ack          // Indicates that a PME To Ack message has been transmitted
  ,
  output  logic                       [N_XADM_P_IF-1:0]       xtlh_xadm_posted_tlp_sent
);

// Logic Declarations
logic                                             int_vc_p_halt         [NVC-1:0];
logic                                             int_vc_np_halt        [NVC-1:0];
logic                                             int_vc_cpl_halt       [NVC-1:0];
logic                                             int_cmd_lp_req;
logic       [NVC-1:0]                             int_vc_packer_pending;
logic       [NVC-1:0]                             int_vc_packer_lp_ack;

xtlh_pkt_t                                        int_vc_p_pkt          [NVC-1:0];
xtlh_pkt_t                                        int_vc_np_pkt         [NVC-1:0];
xtlh_pkt_t                                        int_vc_cpl_pkt        [NVC-1:0];
logic                                             int_vc_p_intf         [NVC-1:0];
logic                                             int_vc_np_intf        [NVC-1:0];
logic                                             int_vc_cpl_intf       [NVC-1:0];
xtlh_vc_pkt_struct                                int_vc_pkt            [NVC-1:0];
logic                                             int_vc_merge_halt_out [NVC-1:0];
logic                                             int_vc_merge_halt_in;
xtlh_vc_pkt_struct                                int_vc_merge_pkt;
logic       [P_NW_CNT_WD - 1 : 0]                 int_vc_next_sot_cnt   [NVC-1:0];
logic       [P_NW_CNT_WD - 1 : 0]                 int_vc_merge_next_sot_cnt;
logic       [P_N_TLP_LEN-1:0][10:0]               int_tlp_len;
logic       [P_DW-1:0]                            int_data;
logic       [P_NW_PROT-1:0]                       int_tlp_prot;
logic                                             int_ras_dp_err_inband_kbd;
logic                                             int_dv;
logic       [P_NW-1:0]                            int_sot;
logic       [P_NW-1:0]                            int_eot;
logic       [P_NW-1:0]                            int_badeot;
tlp_end_struct                                    int_tlp_end;
tlp_end_struct                                    int_pkt_if_tlp_end;
logic       [P_NW-1:0]                            int_ep;
tlp_end_struct                                    int_flit_if_tlp_end;
logic                                             int_flit_if_marker_sent;
logic                                             int_flit_if_tlp_pending;
logic       [DW_W_PAR-1:0]                        int_flit_if_data;
logic                                             int_flit_if_dv;
logic       [P_NW-1:0]                            int_flit_if_sot;
logic       [P_NW-1:0]                            int_flit_if_eot;
logic       [P_NW-1:0]                            int_flit_if_badeot;
logic                                             int_flit_if_sot_is_first;
logic                                             int_flit_if_badeot_or;
logic                                             int_flit_if_first_badeot;
logic                                             int_flit_if_eot_sot;
logic                                             int_flit_if_eot_sot_eot;
logic                                             int_flit_if_halt_out;
logic                                             int_xdlh_xtlh_halt;
logic       [P_N_TLP_LEN-1:0][10:0]               int_flit_if_tlp_len;
logic       [P_NW-1:0]                            int_ptm;
logic                                             int_sot_is_first;
logic                                             int_badeot_or;
logic                                             int_first_badeot;
logic                                             int_eot_sot;
logic                                             int_eot_sot_eot;
logic                                             int_pm_pme_to_ack;

logic                                             int_flit_if_nop_ack;
logic                                             flit_mode_en;

always_ff @(posedge core_clk or negedge core_rst_n) begin : flit_mode_reg_PROC
  if(!core_rst_n)
    flit_mode_en  <= #TP 1'b0;
  else
    flit_mode_en  <= #TP xdlh_xtlh_cmd.flit_mode;
end : flit_mode_reg_PROC

localparam BLOCK_RAS_DP_PROT_CHK_N = 
                                     P_FC_MERGE_LOG_WD + 1;  
                                                                                                                            

localparam RAS_DP_PROT_CHK_ID_BASE_FC_MERGE   = RAS_DP_PROT_CHK_ID_BASE_XTLH;
localparam RAS_DP_PROT_CHK_ID_BASE_FLIT_IF    = RAS_DP_PROT_CHK_ID_BASE_FC_MERGE + P_FC_MERGE_LOG_WD;

ras_dp_err_log_t [BLOCK_RAS_DP_PROT_CHK_N-1:0] ras_dp_err_log_from_checkers;

// RAS DP ERROR LOGGING ARRAY MAPPING (less slots than theoretically possible!!!)
ras_dp_err_log_t [P_FC_MERGE_LOG_WD - 1 :0]     ras_dp_err_log_from_fc_merge;
ras_dp_err_log_t                                ras_dp_err_log_from_flit_if;

always_comb begin
    ras_dp_err_log_from_checkers = '0;
    // FC Merge Checker
    ras_dp_err_log_from_checkers[P_FC_MERGE_LOG_WD - 1 : 0] = ras_dp_err_log_from_fc_merge;
    // FLIT IF
    ras_dp_err_log_from_checkers[P_FC_MERGE_LOG_WD : P_FC_MERGE_LOG_WD] = ras_dp_err_log_from_flit_if;
    // ...
end

ras_dp_err_inj_t ras_dp_err_inj_to_checkers;

logic unused_out_ras_dp_wake_up;
ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N (BLOCK_RAS_DP_PROT_CHK_N)
) u_ras_dp_err_mgr ( 
    .clk                (core_clk),
    .rst_n              (core_rst_n),
    .out_ras_dp_wake_up (unused_out_ras_dp_wake_up),
    .in_ras_dp_err_inj  (ras_dp_err_inj),
    .out_ras_dp_err_inj (ras_dp_err_inj_to_checkers),
    .in_ras_dp_err_log  (ras_dp_err_log_from_checkers),
    .out_ras_dp_err_log (ras_dp_err_log)
);



// Low Power Entry Request SPIF may drive CMD_FLUSH_XAIM without asserting request need to generate ACK in this case also
// For SPIF dont consider the request in CMD_FLUSH_XAIM
assign int_cmd_lp_req = spif_enable ? (xdlh_xtlh_cmd.tx_cmd == CMD_FLUSH_XAIM) : (xdlh_xtlh_cmd.tx_cmd == CMD_FLUSH_XAIM) && xdlh_xtlh_cmd.req;

// ----------------------------------------------------------------------------
// Per VC instantiation of Interface MUX, VC Packer
// ----------------------------------------------------------------------------
// The XADM presents all the interfaces as an array of structs the XTLH needs to unroll
// this array and associate the interfaces with the per VC packers.
// The XTLH VC Packer modules have a fixed number of interfaces unused interfaces are tied off.
// The per VC/FC halts from the XTLH VC Packer need to be merged into an array of halts for the XADM.
generate
  for(genvar vc = 0; vc < NVC; vc++) begin : g_mux_packer_vc
    if(vc == 0) begin : g_vc0
      xtlh_mp_arb
       #(
        .N  (N_XADM_P_IF_VC[vc])
      ) u_p_mp_arb (
        .clk            (core_clk),
        .rst_n          (core_rst_n),
        .pkt_in         (xadm_xtlh_pkt[0 +: N_XADM_P_IF_VC[vc]]),
        .out_halt       (xtlh_xadm_pkt_halt[0 +: N_XADM_P_IF_VC[vc]]),
        .out_pkt        (int_vc_p_pkt[vc]),
        .out_intf       (int_vc_p_intf[vc]),
        .in_halt        (int_vc_p_halt[vc])
      );
      // NON-POSTED
      xtlh_mp_arb
       #(
        .N  (N_XADM_NP_IF_VC[vc])
      ) u_np_mp_arb (
        .clk            (core_clk),
        .rst_n          (core_rst_n),
        .pkt_in         (xadm_xtlh_pkt[0 + N_XADM_P_IF_VC[vc] +: N_XADM_NP_IF_VC[vc]]),
        .out_halt       (xtlh_xadm_pkt_halt[0 + N_XADM_P_IF_VC[vc] +: N_XADM_NP_IF_VC[vc]]),
        .out_pkt        (int_vc_np_pkt[vc]),
        .out_intf       (int_vc_np_intf[vc]),
        .in_halt        (int_vc_np_halt[vc])
      );
      // CPL
      xtlh_mp_arb
       #(
        .N  (N_XADM_CPL_IF_VC[vc])
      ) u_cpl_mp_arb (
        .clk            (core_clk),
        .rst_n          (core_rst_n),
        .pkt_in         (xadm_xtlh_pkt[0 + N_XADM_P_IF_VC[vc] + N_XADM_NP_IF_VC[vc] +:N_XADM_CPL_IF_VC[vc]]),
        .out_halt       (xtlh_xadm_pkt_halt[0 + N_XADM_P_IF_VC[vc] + N_XADM_NP_IF_VC[vc] +:N_XADM_CPL_IF_VC[vc]]),
        .out_pkt        (int_vc_cpl_pkt[vc]),
        .out_intf       (int_vc_cpl_intf[vc]),
        .in_halt        (int_vc_cpl_halt[vc])
      );
    end : g_vc0
    else begin : g_vc1
      xtlh_mp_arb
       #(
        .N  (N_XADM_P_IF_VC[vc])
      ) u_p_mp_arb (
        .clk            (core_clk),
        .rst_n          (core_rst_n),
        .pkt_in         (xadm_xtlh_pkt[N_XADM_IF_VC[vc-1] +: N_XADM_P_IF_VC[vc]]),
        .out_halt       (xtlh_xadm_pkt_halt[N_XADM_IF_VC[vc-1] +: N_XADM_P_IF_VC[vc]]),
        .out_pkt        (int_vc_p_pkt[vc]),
        .out_intf       (int_vc_p_intf[vc]),
        .in_halt        (int_vc_p_halt[vc])
      );
      // NON-POSTED
      xtlh_mp_arb
       #(
        .N  (N_XADM_NP_IF_VC[vc])
      ) u_np_mp_arb (
        .clk            (core_clk),
        .rst_n          (core_rst_n),
        .pkt_in         (xadm_xtlh_pkt[N_XADM_IF_VC[vc-1] + N_XADM_P_IF_VC[vc] +: N_XADM_NP_IF_VC[vc]]),
        .out_halt       (xtlh_xadm_pkt_halt[N_XADM_IF_VC[vc-1] + N_XADM_P_IF_VC[vc] +: N_XADM_NP_IF_VC[vc]]),
        .out_pkt        (int_vc_np_pkt[vc]),
        .out_intf       (int_vc_np_intf[vc]),
        .in_halt        (int_vc_np_halt[vc])
      );
      // CPL
      xtlh_mp_arb
       #(
        .N  (N_XADM_CPL_IF_VC[vc])
      ) u_cpl_mp_arb (
        .clk            (core_clk),
        .rst_n          (core_rst_n),
        .pkt_in         (xadm_xtlh_pkt[N_XADM_IF_VC[vc-1] + N_XADM_P_IF_VC[vc] + N_XADM_NP_IF_VC[vc] +:N_XADM_CPL_IF_VC[vc]]),
        .out_halt       (xtlh_xadm_pkt_halt[N_XADM_IF_VC[vc-1] + N_XADM_P_IF_VC[vc] + N_XADM_NP_IF_VC[vc] +:N_XADM_CPL_IF_VC[vc]]),
        .out_pkt        (int_vc_cpl_pkt[vc]),
        .out_intf       (int_vc_cpl_intf[vc]),
        .in_halt        (int_vc_cpl_halt[vc])
      );
    end : g_vc1

  // Per VC Packer
  // Merges the FC interfaces into a single per FC stream.
  // Merges the resulting per FC streams into a single per VC stream.
  xtlh_vc_packer
   #(
    .P_NUM_P_IF_VC    (N_XADM_P_IF_VC[vc]),
    .P_NUM_NP_IF_VC   (N_XADM_NP_IF_VC[vc]),
    .P_NUM_CPL_IF_VC  (N_XADM_CPL_IF_VC[vc])
    ,
    .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE_FC_MERGE)
  ) u_vc_packer (
    .core_clk                       (core_clk),
    .cfg_tx_arb_control             (cfg_tx_arb_control),
    .lp_req                         (int_cmd_lp_req),
    .xtlh_vc_packer_pending         (int_vc_packer_pending[vc]),
    .xtlh_vc_packer_lp_ack          (int_vc_packer_lp_ack[vc]),
    .p_intf                         (int_vc_p_intf[vc]),
    .np_intf                        (int_vc_np_intf[vc]),
    .cpl_intf                       (int_vc_cpl_intf[vc]),
    .core_rst_n                     (core_rst_n),
    .p_pkt_in                       (int_vc_p_pkt[vc]),
    .np_pkt_in                      (int_vc_np_pkt[vc]),
    .cpl_pkt_in                     (int_vc_cpl_pkt[vc]),
    .halt_in                        (int_vc_merge_halt_out[vc]),
    .rstctl_core_flush_req          (rstctl_core_flush_req),
    .flit_mode_en                   (flit_mode_en),
    .flit_marker_sent               (int_flit_if_marker_sent),
    .fc_init_done                   (xdlh_xtlh_fc_init_done[vc]),
    .rasdp_error_mode               (1'b0),
    .xtlh_vc_packer_cpl_halt        (int_vc_cpl_halt[vc]),
    .xtlh_vc_packer_np_halt         (int_vc_np_halt[vc]),
    .xtlh_vc_packer_p_halt          (int_vc_p_halt[vc]),
    .xtlh_vc_packer_pkt             (int_vc_pkt[vc]),
    .xtlh_vc_packer_next_sot_cnt    (int_vc_next_sot_cnt[vc])
    ,
    .xtlh_vc_packer_p_tlp_sent      (xtlh_xadm_posted_tlp_sent[N_XADM_P_CUMULATIVE_PER_VC[vc]+:N_XADM_P_IF_VC[vc]])
      ,
      .ras_dp_err_log (ras_dp_err_log_from_fc_merge)
        ,
        .ras_dp_err_inj (ras_dp_err_inj_to_checkers)
  );

  end : g_mux_packer_vc
  
endgenerate

assign xtlh_tlp_pending = (|int_vc_packer_pending) || int_flit_if_tlp_pending;

// VC Merge Module
// Performs VC arbitration
// Merge all the VC packets into a single output structure.
xtlh_vc_merge
 u_vc_merge (
  .core_clk                   (core_clk),
  .core_rst_n                 (core_rst_n),
  .halt_in                    (int_vc_merge_halt_in),
  .vc_pkt_in                  (int_vc_pkt),
  .vc_next_sot_cnt            (int_vc_next_sot_cnt),
  .xtlh_vc_merge_halt_out     (int_vc_merge_halt_out),
  .xtlh_vc_merge_pkt_out      (int_vc_merge_pkt),
  .xtlh_vc_merge_next_sot_cnt (int_vc_merge_next_sot_cnt)
);

assign xtlh_pm_pme_to_ack = flit_mode_en ? int_pm_pme_to_ack : '0;


// XTLH Packet Interface
// Converts the VC structure into a packet interface for the XDLH
// This is the XDLH Interface that is used in Non-Flit Mode
xtlh_pkt_out_if
 u_xtlh_pkt_out_if (
  .core_clk                            (core_clk),
  .core_rst_n                          (core_rst_n),
  .vc_pkt_in                           (int_vc_merge_pkt)
  ,
  .xtlh_pkt_if_tlp_len                 (int_tlp_len),
  .xtlh_pkt_if_data                    (int_data),
  .xtlh_pkt_if_dv                      (int_dv),
  .xtlh_pkt_if_sot                     (int_sot),
  .xtlh_pkt_if_eot                     (int_eot),
  .xtlh_pkt_if_badeot                  (int_badeot),
  .xtlh_pkt_if_ep                      (int_ep),
  .flit_mode_en                        (flit_mode_en),
  .xtlh_pkt_if_ptm                     (int_ptm),
  .xtlh_pkt_if_sot_is_first            (int_sot_is_first),
  .xtlh_pkt_if_badeot_or               (int_badeot_or),
  .xtlh_pkt_if_first_badeot            (int_first_badeot),
  .xtlh_pkt_if_eot_sot                 (int_eot_sot),
  .xtlh_pkt_if_eot_sot_eot             (int_eot_sot_eot),
  .xtlh_pkt_if_tlp_end                 (int_pkt_if_tlp_end),
  .xtlh_pkt_if_pme_to_ack              (int_pm_pme_to_ack),
  .rstctl_core_flush_req               (rstctl_core_flush_req)
    ,
    .cfg_rasdp_error_mode              (cfg_rasdp_error_mode),
    .xdlh_rasdp_error_mode             (xdlh_rasdp_error_mode),
    .halt_in                           (int_vc_merge_halt_in),
    .xtlh_pkt_if_tlp_prot              (int_tlp_prot),
    .xtlh_pkt_if_ras_dp_err_inband_kbd (int_ras_dp_err_inband_kbd)
);

logic int_no_spif_cmd_ack;
logic int_cmd_ack;

// Acknowledge for CMD_NOP/CMD_FLUSH_XTLH from NOP generator
// Acknowledge for CMD_PYLD when NOP acknowledge low
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    int_no_spif_cmd_ack <= #TP 1'b0;
  else begin
    if(!xdlh_xtlh_cmd.req && int_no_spif_cmd_ack)
      int_no_spif_cmd_ack <= #TP 1'b0;
    else if(xdlh_xtlh_cmd.req && (xdlh_xtlh_cmd.tx_cmd inside {CMD_NOP, CMD_FLUSH_XTLH}))
      int_no_spif_cmd_ack <= #TP int_flit_if_nop_ack ? 1'b1 : int_no_spif_cmd_ack;
    else if(xdlh_xtlh_cmd.req && (xdlh_xtlh_cmd.tx_cmd == CMD_PYLD))
      int_no_spif_cmd_ack <= #TP !int_flit_if_nop_ack ? 1'b1 : int_no_spif_cmd_ack;
  end
end

logic int_spif_cmd_ack;

// Acknowledge for CMD_NOP/CMD_FLUSH_XTLH/CMD_PYLD in SPIF mode
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    int_spif_cmd_ack <= #TP 1'b0;
  else begin
    if(!xdlh_xtlh_cmd.req && int_spif_cmd_ack)
      int_spif_cmd_ack <= #TP 1'b0;
    // When CMD_NOP or CMD_PYLD command is asserted then acknowledge the command without any preconditions
    else if(xdlh_xtlh_cmd.req && (xdlh_xtlh_cmd.tx_cmd inside {CMD_NOP, CMD_PYLD}))
      int_spif_cmd_ack <= #TP 1'b1;
    // When CMD_FLUSH_XTLH command is asserted wait for the command acknowledge from the XTLH NOP Generator as
    // there might be ongoing flit on the interface that needs to be flushed before halting the Transaction Layer
    else if(xdlh_xtlh_cmd.req && (xdlh_xtlh_cmd.tx_cmd inside {CMD_FLUSH_XTLH}))
      int_spif_cmd_ack <= #TP int_flit_if_nop_ack ? 1'b1 : int_spif_cmd_ack;
  end
end

assign int_cmd_ack = spif_enable ? int_spif_cmd_ack : int_no_spif_cmd_ack;

assign xtlh_xdlh_cmd_ack = ((&int_vc_packer_lp_ack) && !int_flit_if_tlp_pending) || int_cmd_ack;


// XTLH Flit Framing converts the packet interface into Flit Interface
xtlh_flit_if
 #(
  .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE_FLIT_IF)
) u_xtlh_flit_if (
  .core_clk                     (core_clk),
  .core_rst_n                   (core_rst_n),
  .halt_in                      (int_xdlh_xtlh_halt),
  .flit_mode_en                 (flit_mode_en),
  .next_sot_cnt                 (int_vc_merge_next_sot_cnt),
  .spif_enable                  (spif_enable),
  .cdm_err_inj_en               (cdm_err_inj_en),
  .cdm_tx_err_inj_en            (cdm_tx_err_inj_en),
  .xtlh_flit_if_flit            (xtlh_xdlh_flit),
  .xdlh_xtlh_cmd                (xdlh_xtlh_cmd),
  .rstctl_core_flush_req        (rstctl_core_flush_req),
  .pkt_if_tlp_len               (int_tlp_len),
  .pkt_if_data                  (int_data),
  .pkt_if_tlp_prot              (int_tlp_prot),
  .pkt_if_dv                    (int_dv),
  .pkt_if_sot                   (int_sot),
  .pkt_if_eot                   (int_eot),
  .pkt_if_badeot                (int_badeot),
  .pkt_if_ep                    (int_ep),
  .pkt_if_tlp_end               (int_pkt_if_tlp_end),
  .pkt_if_ptm                   (int_ptm),
  .pkt_if_ras_dp_err_inband_kbd (int_ras_dp_err_inband_kbd),
  .pkt_if_sot_is_first          (int_sot_is_first),
  .pkt_if_badeot_or             (int_badeot_or),
  .pkt_if_first_badeot          (int_first_badeot),
  .pkt_if_eot_sot               (int_eot_sot),
  .pkt_if_eot_sot_eot           (int_eot_sot_eot),
  .xtlh_flit_if_tlp_len         (int_flit_if_tlp_len),
  .xtlh_flit_if_tlp_pending     (int_flit_if_tlp_pending),
  .xtlh_flit_if_data            (int_flit_if_data),
  .xtlh_flit_if_dv              (int_flit_if_dv),
  .xtlh_flit_if_sot             (int_flit_if_sot),
  .xtlh_flit_if_eot             (int_flit_if_eot),
  .xtlh_flit_if_badeot          (int_flit_if_badeot),
  .xtlh_flit_if_sot_is_first    (int_flit_if_sot_is_first),
  .xtlh_flit_if_badeot_or       (int_flit_if_badeot_or),
  .xtlh_flit_if_first_badeot    (int_flit_if_first_badeot),
  .xtlh_flit_if_eot_sot         (int_flit_if_eot_sot),
  .xtlh_flit_if_eot_sot_eot     (int_flit_if_eot_sot_eot),
  .xtlh_flit_if_tlp_end         (int_flit_if_tlp_end),
  .xtlh_flit_if_marker_sent     (int_flit_if_marker_sent),
  .xtlh_flit_if_halt_out        (int_flit_if_halt_out),
  .xtlh_flit_if_nop_ack         (int_flit_if_nop_ack),
  .xtlh_flit_if_eot_cnt         (),
  .xtlh_flit_if_over_cnt        ()
      ,
      .ras_dp_err_inj           (ras_dp_err_inj_to_checkers)
    ,
    .ras_dp_err_log             (ras_dp_err_log_from_flit_if)
);                         

    assign xtlh_xdlh_data         = int_flit_if_data;
    assign xtlh_xdlh_dv           = int_flit_if_dv;
    assign xtlh_xdlh_sot          = int_flit_if_sot;
    assign xtlh_xdlh_eot          = int_flit_if_eot;
    assign xtlh_xdlh_badeot       = int_flit_if_badeot;
    assign xtlh_xdlh_sot_is_first = int_flit_if_sot_is_first;
    assign xtlh_xdlh_badeot_or    = int_flit_if_badeot_or;
    assign xtlh_xdlh_first_badeot = int_flit_if_first_badeot;
    assign xtlh_xdlh_eot_sot      = int_flit_if_eot_sot;
    assign xtlh_xdlh_eot_sot_eot  = int_flit_if_eot_sot_eot;
    assign xtlh_xdlh_tlp_len      = int_flit_if_tlp_len;
    assign int_xdlh_xtlh_halt     = xdlh_xtlh_halt;
    assign int_tlp_end            = int_flit_if_tlp_end;
    assign int_vc_merge_halt_in   = int_flit_if_halt_out;


endmodule
