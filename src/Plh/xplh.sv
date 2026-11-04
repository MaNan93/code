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
// ---   $DateTime: 2023/12/22 07:15:34 $
// ---   $Revision: #16 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh.sv#16 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Transmit Link Layer Packet Generation.
// This module manages the interface between the Link Layers and the Physical Layer.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer2/svif/tx_lp_if.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/cx_pl_pkg.svh"
`include "Plh/xplh_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Spif/pkg/spif_pkg.svh"
`include "Spif/svif/spif_if.svh"

module xplh
  import cx_pl_pkg::dllp_struct;
  import cx_pl_pkg::xplh_sideband_struct;
  import DWC_pcie_ctl_pkg::*;
  import cx_pl_pkg::P_NW;
  import cx_pl_pkg::P_DW;
  import cx_pl_pkg::PM_ENTER_L1;
  import cx_pl_pkg::PM_ENTER_L23;
  import cx_pl_pkg::PM_REQUEST_ACK;
  import cx_pl_pkg::PM_ACTIVE_STATE_REQUEST_L1;
  import cx_pl_pkg::NOP_DLLP;
  import cx_pl_pkg::NOP2_DLLP;
  import cx_pl_pkg::NOP;
  import cx_pl_pkg::tx_cmd_struct;
  import cx_pl_pkg::rplh_xplh_fm_retry_t;
  import cx_pl_pkg::replay_cmd_t;
  import cx_pl_pkg::fm_dllp_struct;
  import cx_pl_pkg::dllp_type_e;
  import cx_pl_pkg::rbuf_struct;
  import cx_pl_pkg::tx_flit_struct;
  import cx_pl_pkg::P_RBUF_WD;
  import cx_pl_pkg::P_MAX_SEQNUM;
  import cx_pl_pkg::P_TX_SEQNUM_WD;
  import cx_pl_pkg::CMD_IDLE;
  import cx_pl_pkg::CMD_RESET;
  import cx_pl_pkg::CMD_NOP;
  import cx_pl_pkg::CMD_PYLD;
  import cx_pl_pkg::REPLAY_00;
  import cx_pl_pkg::xplh_sideband_rasdes_fm;
  import  DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import  DWC_pcie_ctl_pkg::RAS_DP_PROT_CHK_ID_BASE_XPLH;
  import  DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  import DWC_pcie_core_pkg::xplh_cdm_flit_latency_track_t;
  import xplh_pkg::IDLE_OR_NOP;
  import DWC_pcie_core_pkg::flit_err_inj_interface_struct;
  import DWC_pcie_core_pkg::curr_inj_err_type_e;
  import DWC_pcie_core_pkg::flit_type_inj_e;
  import DWC_pcie_core_pkg::inj_sts_e;
  import spif_pkg::protocol_cfg_t;
  import spif_pkg::SPIF_LP_NVLD;
  import spif_pkg::SPIF_NBYTES;
  import spif_pkg::SPIF_NCRC;
  import spif_pkg::SPIF_NWORDS;
  import spif_pkg::stream_id_e;
  import spif_pkg::SID_CXL_IO;
#(
  parameter INST   = 0
) 
             (
  // Interfaces
  spif_if.xplh_master_mp      b_xplh_spif,                // XPLH SPIF interface
  tx_lp_if.slave_mp           b_xdlh_xplh_sp,             // Link Layer Transmit Slave  Port XDLH->XPLH
  tx_lp_if.master_mp          b_xplh_xmlh_mp,             // Link Layer Transmit Master Port XPLH->XMLH
  // Inputs
  input                       core_clk,
  input                       core_rst_n,
  input [2:0]                 current_data_rate,          // 2'b00=running at gen1 speeds, 2'b01=running at gen2 speeds, 2'b10=running at gen3 speeds, 2'b11=running at gen4 speeds
  input [5:0]                 xplh_link_mode,             // Current Link Width
  input [2:0]                 mac_phy_rate,               // 2'b00=running at gen1 speeds, 2'b01=running at gen2 speeds, 2'b10=running at gen3 speeds, 2'b11=running at gen4 speeds
  input   logic               cfg_upstream_port,          // Upstream port when it is high
  input   dllp_struct         pm_xdlh_dllp_req,           // PM DLLP request
  // -------------------------------------------------------------------------------------
  // CXL Configuration Interface with LTSSM
  // -------------------------------------------------------------------------------------

  input                            cxl_io_throttle_enable, // CXL.io Throttle Required at 64GT/s
  input                            xplh_payload_enable   , // Enable payload flits from Link Layers
  input                            cfg_rasdp_linkdown_en , // Enable Link Down on RASDP uncorrectable error
  input        protocol_cfg_t      xplh_protocol_cfg     , // Protocol Configuration for PLH Layer
  input                            xplh_stall_req        , // Stall request on SPIF interface
  input                            xplh_stall_ack        , // Stall acknowledge on SPIF interface
  output                           xplh_linkerror        , // XPLH Link Error indication
  output    dllp_struct               xplh_pm_dllp_ack
  ,
  output  logic                       xplh_nak_ignore_link_err, // Data Link Protocol error
  input   [5 : 0]                     link_width                // Link width
  // -------------------------------------------------------------------------------------
  // Command Interface
  // -------------------------------------------------------------------------------------
  ,
  output  tx_cmd_struct       xplh_xdlh_cmd,              // XPLH Commands
  input                       xdlh_xplh_cmd_ack,          // XDLH Command Acknowledge
  input   tx_cmd_struct       xmlh_xplh_cmd,              // XMLH Commands
  output  logic               xplh_xmlh_cmd_ack           // XPLH Command Acknowledge
  ,
  input                       en_tx_throttling,
  // -------------------------------------------------------------------------------------
  // PTM Signals
  // -------------------------------------------------------------------------------------
  input   logic               xmlh_stp_start,             // XMLH byte transmit has sent EOF for flit
  output  logic               xplh_ptm_sot,               // indicate to PTM logic PTM Flit is observed
  output  logic               xplh_ptm_request,           // observed PTM request
  output  logic               xplh_ptm_response,          // observed PTM response
  // -------------------------------------------------------------------------------------
  // XPLH Pending Signal
  // -------------------------------------------------------------------------------------
  output  logic                      xplh_pending,               // XPLH Pending Signal generated from XPLH tracker
  output  xplh_sideband_rasdes_fm    xplh_rasdes_fm,             // XPLH Rasdes FM signals 
  output  logic [P_TX_SEQNUM_WD-1:0] xplh_rx_ack_seqnum,         // Level : Current Rx Ack Sequence number status for Ras D.E.S Silicon Debug
  output  logic [P_TX_SEQNUM_WD-1:0] xplh_tx_seqnum_value,       // Level : Current Tx Sequence number status for Ras D.E.S Silicon Debug
  input   cdm_ras_des_force_linkdown_noack,                      // RASDES Noack Linkdown Featue Enable from the CDM 
  output  logic xplh_req_link_down,                              // Request to LTSSM to go to detect
  // -------------------------------------------------------------------------------------
  // L0P flit counter
  // -------------------------------------------------------------------------------------
  output  logic [2:0]         xplh_flit_count,            // Flit Counter for use in L0P DLLP generation
  input                       xplh_flit_count_en,         // Enable Flit Counter for L0P DLLP generation
  //--------------------------------------------------------------------------------------
  // RAS-DES Interface
  //--------------------------------------------------------------------------------------
  input                               cdm_ras_des_einj1_enable,
  input                               cdm_ras_des_einj1_seq_type,
  input  [12: 0]                      cdm_ras_des_einj1_bad_seq,
  input  [7 : 0]                      cdm_ras_des_einj1_count,
  output [1 : 0]                      xplh_ras_des_einj1_exp_sequm_evt,     // Pluse to indicate error injection event occurred in explict sequence number
  output                              xplh_ras_des_einj1_ack_nak_sequm_evt, // Pluse to indicate error injection event occurred in ACK/NAK sequence number 
  // -------------------------------------------------------------------------------------
  // Layer 1 Interface
  // -------------------------------------------------------------------------------------
  output  logic               xplh_smlh_req_rcvry,          // XPLH Requests the LTSSM to transition to Recovery
  // -------------------------------------------------------------------------------------
  // RPLH Interface
  // -------------------------------------------------------------------------------------
  input  rplh_xplh_fm_retry_t rplh_xplh_fm_retry,           // RPLH to XPLH Flit Mode Retry Interface
  // -------------------------------------------------------------------------------------
  // XDLH Interface
  // -------------------------------------------------------------------------------------
  input   fm_dllp_struct      xdlh_xplh_fm_dllp,          // Flit Mode DLLP Input
  output  logic               xplh_xdlh_dllp_halt,        // DLLP Halt
  // -------------------------------------------------------------------------------------
  // Retry Buffer Interface
  // -------------------------------------------------------------------------------------
  input   [P_RBUF_WD - 1 : 0] retryram_data,                // Retry RAM Read Data
  output  rbuf_struct         xplh_retry_ram_if             // Retry Buffer Interface Struct
  ,
  output  ras_dp_err_log_t    xplh_ras_dp_err_log           // RASDP Error Logging
  ,
  input   ras_dp_err_inj_t    ras_dp_err_inj                  // RASDP Error Injection
  ,output logic               xplh_acknak_pend              // ACK/NAK Pending to transmit
  ,
  input  [2 : 0]                        cdm_xplh_flit_response_type,
  input  [1 : 0]                        cdm_xplh_flit_type_measured,
  input                                 cdm_xplh_flit_track_mode,
  output xplh_cdm_flit_latency_track_t  xplh_cdm_flit_latency_tracking
  ,
  input  flit_err_inj_interface_struct  cdm_plh_flit_err_inj_interface,
  output logic [1 : 0]                  xplh_cdm_flit_err_inj_status
  // -------------------------------------------------------------------------------------
  // XPLH Frequency Step Signals
  // -------------------------------------------------------------------------------------
  ,output xplh_sideband_struct  xplh_sideband               // struct of signals that are part of xplh/xmlh interface before entering xplh freq_step module and used in cx_pl

);

localparam P_XPLH_MAX_OUTSTANDING = 1 
;

// MUX CXL with PCIe data path
tx_lp_if              b_xdlh_xplh_mux(); // ARB/MUX->XPLH Interface
tx_lp_if              b_fs_xplh_xmlh();  // Interface passing through the optional frequency step

tx_flit_struct int_xdlh_xplh_flit;
tx_flit_struct int_retry_flit_in;
tx_flit_struct int_nop_gen_flit_out;
logic          int_nop_gen_halt;
logic          xplh_replay_buf_almost_full;
logic          int_rbuf_almost_full;
localparam RAS_DP_PROT_CHK_ID_BASE_RETRY    = RAS_DP_PROT_CHK_ID_BASE_XPLH + 0;
localparam RAS_DP_PROT_CHK_ID_BASE_PROT     = RAS_DP_PROT_CHK_ID_BASE_RETRY + 2;
tx_cmd_struct               int_xplh_control_cmd;
logic                       int_retrybuf_idle;
logic [1:0]                 int_expl_seq_cnt;
logic                       xplh_control_halt;
logic                       xplh_retry_halt;
logic                       xplh_nop_gen_halt;
logic                       int_xplh_retry_halt; // Halt on XPLH Retry inputs
tx_flit_struct              int_xplh_retry_flit; // Flit on XPLH Retry inputs
tx_flit_struct              xplh_retry_flit;
tx_flit_struct              xplh_control_flit;
tx_flit_struct              xplh_flit_prot_flit;
tx_flit_struct              xplh_idle_gen_flit;
tx_flit_struct              xplh_flit_out;
logic                       xplh_halt_in;
logic [P_TX_SEQNUM_WD-1:0]  int_tx_seqnum_sof;
logic [P_TX_SEQNUM_WD-1:0]  int_tx_seqnum_sof_r;
logic                       link_nop_flit_valid_r;
logic                       phy_nop_flit_valid_r;
logic                       xplh_replay_00_valid;
logic                       xplh_idle_gen_valid;
tx_flit_struct              xplh_err_inj_flit;
logic                       xplh_err_inj_halt;
inj_sts_e                   xplh_err_inj_sts_e;
logic                       xplh_flit_prot_halt;
replay_cmd_t                xplh_retry_replay_cmd;
logic [9:0]                 xplh_retry_rcvd_seqnum;
logic                       xplh_control_normal;
fm_dllp_struct              int_xdlh_xplh_fm_dllp;          // Flit Mode DLLP Input
logic                       int_xplh_ctrl_sent_nak;                 // Nak sent FM 
logic                       int_xplh_ctrl_sent_ack;                // Ack sent FM
logic                       int_xplh_replay_timeout;              // Replay timeout FM
logic                       int_xplh_retry_replay_num_rollover;  // Replay number rollover FM
logic                       xplh_idle_gen_halt;  
logic                       int_grant_dllp;
logic                       xplh_control_cmd_ack;
logic                       xplh_flit_prot_cmd_ack;
logic                       int_xmlh_cmd_ack;
logic                       int_crc_sof;
logic                       xplh_idle_gen_ack;
logic [P_TX_SEQNUM_WD-1:0]  int_tx_seqnum; // Transmitter Sequence Number
logic [P_TX_SEQNUM_WD-1:0]  int_next_tx_seqnum; // Next Transmitter Sequence Number
logic [P_TX_SEQNUM_WD-1:0]  int_nop_expl_seqnum; // Transmitter Sequence Number for explicit sequence number NOP Flit
logic [2:0]                 int_tx_nak_cnt; // Consecutive Nak Counter
logic                       int_tx_nak_cnt_incr;
logic                       int_req_rcvry;
logic                       int_retry_req_rcvry;
logic                       int_control_req_rcvry;
logic [P_TX_SEQNUM_WD-1:0]  int_retry_replay_seqnum;
ras_dp_err_log_t [1:0]      int_retry_ras_dp_err_log;
ras_dp_err_log_t            int_prot_ras_dp_err_log;
logic                       cxl_viral_crc_marker_eof;    // check marker for crc corruption flit0 and viral control flit
logic                       xplh_spif_nfm_mode;          // PCIe non-Flit mode is enabled over SPIF Interface
logic                       xplh_spif_flit_mode;         // Flit mode is enabled over SPIF Interface
logic                       xplh_nop_gen_ack;            // NOP Generator Command Acknowledge
logic                       xplh_nop_phy_flit;           // NOP flit on the interface is Physical Layer NOP - do not allow DLLP insertion
logic                       xplh_nop_phy_eof;            // ative NOP flit EOF accepted at xplh control.
logic                       xplh_rasdp_error;            // XPLH RASDP Uncorrectable Error from the last checker in the datapath before CRC
dllp_struct                 int_pm_dllp_ack;
dllp_struct                 int_det_pm_dllp_ack;

assign xplh_linkerror      = 1'b0 || (cfg_rasdp_linkdown_en && xplh_rasdp_error) ;
assign xplh_spif_flit_mode = xplh_protocol_cfg.pcie_flit_mode && xplh_protocol_cfg.spif_enable;
assign xplh_spif_nfm_mode = xplh_protocol_cfg.pcie_nfm_mode && xplh_protocol_cfg.spif_enable;

// -------------------------------------------------------------------------------------
// SPIF MUX - multiplexes between Native PCIe datapath (XDLH-2-XPLH interface) and SPIF interface
// -------------------------------------------------------------------------------------
xplh_spif_mux
 u_spif_mux (
    // Interfaces
    .b_xdlh_xplh_sp        ( b_xdlh_xplh_sp                       ),
    .b_xplh_xmlh_mp        ( b_xdlh_xplh_mux.master_mp            ),
    // Inputs
    .core_clk              ( core_clk                             ),
    .core_rst_n            ( core_rst_n                           ),
    .spif_enable           ( xplh_protocol_cfg.spif_enable        ),
    .pcie_flit_mode        ( xplh_spif_flit_mode                  ),
    .pcie_nfm_mode         ( xplh_spif_nfm_mode                   ),
    .cxl_mode_enable       ( xplh_protocol_cfg.cxl_mode_enable    ),
    .xplh_payload_enable   ( xplh_payload_enable                  ),
    .xplh_link_mode        ( xplh_link_mode                       ),
    .xplh_stall_ack        ( xplh_stall_ack                       ),
    .vlsm_lp_stream        ( b_xplh_spif.s_lp_stream              ),
    .vlsm_lp_irdy          ( b_xplh_spif.s_lp_irdy                ),
    .vlsm_lp_valid         ( b_xplh_spif.s_lp_valid               ),
    .vlsm_lp_data          ( b_xplh_spif.s_lp_data                ),
    .vlsm_lp_crc_valid     ( b_xplh_spif.s_lp_crc_valid           ),
    .vlsm_lp_crc_data      ( b_xplh_spif.s_lp_crc_data            ),
    .vlsm_lp_dlp_start     ( b_xplh_spif.s_lp_dlp_start           ),
    .vlsm_lp_dlp_end       ( b_xplh_spif.s_lp_dlp_end             ),
    .vlsm_lp_tlp_start     ( b_xplh_spif.s_lp_tlp_start           ),
    .vlsm_lp_tlp_end       ( b_xplh_spif.s_lp_tlp_end             ),
    .vlsm_lp_nop_flit      ( b_xplh_spif.s_lp_nop_flit            ),
    .vlsm_lp_data_chk      ( b_xplh_spif.s_lp_data_chk            ),
    .vlsm_lp_rasdp_error   ( b_xplh_spif.s_lp_rasdp_error         ),
    // Outputs
    .vlsm_pl_skip_trdy     ( b_xplh_spif.s_pl_skip_trdy           ),
    .vlsm_pl_trdy          ( b_xplh_spif.s_pl_trdy                )
);
// -------------------------------------------------------------------------------------

assign int_xdlh_xplh_fm_dllp        = xplh_protocol_cfg.spif_enable? ( xplh_nop_phy_flit ? fm_dllp_struct'{opt_upd_fc: 1'b0, pyld: 24'd0, dllp_type: NOP2_DLLP} : 
                                                                                           fm_dllp_struct'{opt_upd_fc: b_xplh_spif.s_lp_dllp_ofc, pyld: b_xplh_spif.s_lp_dllp_data[31:8], dllp_type: dllp_type_e'(b_xplh_spif.s_lp_dllp_data[7:0])} ) : 
                                                                       xdlh_xplh_fm_dllp;
assign xplh_nop_phy_eof             = xplh_nop_phy_flit && int_xplh_retry_flit.eof[1] && !xplh_control_halt;

// -------------------------------------------------------------------------------------
// Physical Layer NOP Generator
// -------------------------------------------------------------------------------------
xplh_phy_nop_gen
 u_xplh_phy_nop_gen (
  // Inputs
  .core_clk               (core_clk),
  .core_rst_n             (core_rst_n),
  .flit_mode_enable       (xplh_spif_flit_mode),
  .cxl_io_throttle_enable (cxl_io_throttle_enable),
  .xplh_control_cmd       (int_xplh_control_cmd),
  .xplh_retry_flit        (xplh_retry_flit),
  .xplh_nop_gen_halt      (xplh_control_halt),
  // Outputs
  .xplh_nop_gen_ack       (xplh_nop_gen_ack),
  .xplh_nop_phy_flit      (xplh_nop_phy_flit),
  .xplh_nop_gen_flit      (int_xplh_retry_flit),
  .xplh_retry_halt_out    (int_xplh_retry_halt)
);
// -------------------------------------------------------------------------------------


tx_cmd_struct int_xplh_cmd_r;

// Register the command bus 
delay_n
 #(
  .N  (1),
  .WD ($bits(xmlh_xplh_cmd))
) u_xmlh_cmd_reg (
  .clk    (core_clk),
  .rst_n  (core_rst_n),
  .clear  (1'b0),
  .din    (xmlh_xplh_cmd),
  .dout   (int_xplh_cmd_r)
);


//-------------------------
//assign xplh rasdes struct 
assign xplh_rasdes_fm.xplh_retry_replay_timeout =      int_xplh_replay_timeout;
assign xplh_rasdes_fm.xplh_retry_replay_num_rollover = int_xplh_retry_replay_num_rollover;
assign xplh_rasdes_fm.xplh_sent_ack =                  int_xplh_ctrl_sent_ack;
assign xplh_rasdes_fm.xplh_sent_nak =                  int_xplh_ctrl_sent_nak;
assign xplh_rasdes_fm.xplh_retry_flit =                int_xplh_retry_flit.retry_flit;
assign xplh_rx_ack_seqnum                            = rplh_xplh_fm_retry.received.seqnum;
assign xplh_tx_seqnum_value                          = int_tx_seqnum;
//--------------------------

//----------------------------------------------
//--------- XPLH Pending Tracker ---------------
//----------------------------------------------
logic           xplh_pending_tracker;
logic           int_rbuf_empty;
logic           int_rbuf_empty_retry;
logic           int_rbuf_nak_11;
logic           xplh_tracker_entry_event;
logic           xplh_tracker_exit_event;
logic           xplh_blk_pending;
logic           int_cmd_reset;

assign xplh_tracker_entry_event = b_xdlh_xplh_mux.eof[1] && !b_xdlh_xplh_mux.enf && !b_xdlh_xplh_mux.halt_in;
assign xplh_tracker_exit_event  = b_fs_xplh_xmlh.eof[1]  && !b_fs_xplh_xmlh.enf  && !xplh_flit_out.retry_flit && !b_fs_xplh_xmlh.halt_in;
assign xplh_blk_pending         = !int_rbuf_empty;

logic int_cmd_reset_r;

// Reset the pipelines and wait for flit incoming
always_comb begin : cmd_reset_PROC
  if(int_cmd_reset_r && ( xplh_protocol_cfg.spif_enable ? ((xmlh_xplh_cmd.tx_cmd != CMD_RESET) && int_xplh_retry_flit.sof) : int_retry_flit_in.sof))
    int_cmd_reset = 1'b0; 
  else if(xmlh_xplh_cmd.tx_cmd == CMD_RESET)
    int_cmd_reset = 1'b1;
  else
    int_cmd_reset = int_cmd_reset_r;
end : cmd_reset_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    int_cmd_reset_r <= #TP '0;
  else
    int_cmd_reset_r <= #TP int_cmd_reset;
end

pending_tracker
 #(
  .CNT_WIDTH        (2)

) u_xplh_tracker (
  // -------------------------------------------------------------------------------------
  // Clock and Reset
  // -------------------------------------------------------------------------------------
  .core_clk                      (core_clk),
  .core_rst_n                    (core_rst_n),
  // -------------------------------------------------------------------------------------
  // Inputs
  // -------------------------------------------------------------------------------------
  .clear                         (int_cmd_reset),
  .entry_event                   (xplh_tracker_entry_event),
  .exit_event                    (xplh_tracker_exit_event),
  .blk_pending                   (xplh_blk_pending),
  // -------------------------------------------------------------------------------------
  // Outputs
  // -------------------------------------------------------------------------------------
  .pending                       (xplh_pending)
);

//--------------------------------------
//--------- End of XPLH Tracker --------
//--------------------------------------

always_comb begin : flit_in_mux_PROC
  if(xmlh_xplh_cmd.flit_mode) begin
    int_retry_flit_in.sof                    = b_xdlh_xplh_mux.sof;
    int_retry_flit_in.eof                    = b_xdlh_xplh_mux.eof;
    int_retry_flit_in.enf                    = b_xdlh_xplh_mux.enf;
    int_retry_flit_in.data_valid             = b_xdlh_xplh_mux.data_valid;
    int_retry_flit_in.data                   = b_xdlh_xplh_mux.data_out;
    int_retry_flit_in.retry_flit             = 1'b0; 
    int_retry_flit_in.expl_flit              = 1'b0; 
    int_retry_flit_in.tlp_dv                 = b_xdlh_xplh_mux.flit_tlp_dv;
    int_retry_flit_in.flit_type_s            = b_xdlh_xplh_mux.flit_type_s;
    int_retry_flit_in.flit_prot              = b_xdlh_xplh_mux.flit_prot; 
    int_retry_flit_in.ras_dp_err_inband_kbd  = b_xdlh_xplh_mux.ras_dp_err_inband_kbd;
  end else begin
    int_retry_flit_in = '0;
  end
end : flit_in_mux_PROC

xplh_nop_gen
 u_xplh_nop_gen (
  .core_clk           (core_clk),
  .core_rst_n         (core_rst_n),
  .flit_in            (int_retry_flit_in),
  .req_nop            (int_rbuf_almost_full),
  .halt_in            (xplh_retry_halt),
  .xplh_nop_gen_flit  (int_nop_gen_flit_out),
  .xplh_nop_gen_halt  (int_nop_gen_halt)
);

assign int_rbuf_almost_full = xplh_protocol_cfg.spif_enable ? 1'b0 : xplh_replay_buf_almost_full;
assign int_xdlh_xplh_flit = xplh_protocol_cfg.spif_enable ? int_retry_flit_in : int_nop_gen_flit_out;
assign xplh_nop_gen_halt = xplh_protocol_cfg.spif_enable ? xplh_retry_halt : int_nop_gen_halt;

ras_dp_err_log_t [2:0] ras_dp_err_log_from_checkers;
assign ras_dp_err_log_from_checkers = {int_prot_ras_dp_err_log, int_retry_ras_dp_err_log};

ras_dp_err_inj_t ras_dp_err_inj_to_checkers;

logic unused_out_ras_dp_wake_up;
ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N         (3),
    .CAN_RECEIVE_LONG_ERR_LOG_FORMAT (1)
) u_ras_dp_err_mgr (
    .clk                (core_clk),
    .rst_n              (core_rst_n),
    .out_ras_dp_wake_up (unused_out_ras_dp_wake_up),
    .in_ras_dp_err_inj  (ras_dp_err_inj),
    .out_ras_dp_err_inj (ras_dp_err_inj_to_checkers),
    .in_ras_dp_err_log  (ras_dp_err_log_from_checkers),
    .out_ras_dp_err_log (xplh_ras_dp_err_log)
);

xplh_retry
 #(
  .RAS_DP_PROT_CHK_ID_BASE  (RAS_DP_PROT_CHK_ID_BASE_RETRY)
) u_xplh_retry (
  // -------------------------------------------------------------------------------------
  // Clock and Reset
  // -------------------------------------------------------------------------------------
  .core_clk                       (core_clk),
  .core_rst_n                     (core_rst_n),
  .spif_enable                    (xplh_protocol_cfg.spif_enable),
  .xplh_nop_phy_eof               (xplh_nop_phy_eof),
  .xplh_stall_req                 (xplh_stall_req),
  .xplh_stall_ack                 (xplh_stall_ack),
  .cxl_mode_enable                (xplh_protocol_cfg.cxl_mode_enable),
  .cxl_viral_err                  (b_xplh_spif.s_lp_corrupt_crc),
  .cxl_viral_crc_marker_eof       (cxl_viral_crc_marker_eof),
  .link_width                     (link_width),
  // -------------------------------------------------------------------------------------
  // RPLH Interface
  // -------------------------------------------------------------------------------------
  .rplh_req_replay_cmd            (rplh_xplh_fm_retry.requested.cmd),
  .rplh_req_seqnum                (rplh_xplh_fm_retry.requested.seqnum),
  .rplh_req_acknak_valid          (rplh_xplh_fm_retry.valid),
  .rplh_rcvd_replay_cmd           (rplh_xplh_fm_retry.received.cmd),
  .rplh_rcvd_seqnum               (rplh_xplh_fm_retry.received.seqnum),
  .rplh_rcvd_acknak_valid         (rplh_xplh_fm_retry.valid),
  // -------------------------------------------------------------------------------------
  // XPLH Control Interface
  // -------------------------------------------------------------------------------------
  .xplh_retry_replay_cmd          (xplh_retry_replay_cmd),
  .xplh_retry_rcvd_seqnum         (xplh_retry_rcvd_seqnum),
  .xplh_tx_nak_cnt                (int_tx_nak_cnt),
  .xplh_tx_nak_cnt_incr           (int_tx_nak_cnt_incr),
  .xplh_retry_req_rcvry           (int_retry_req_rcvry),
  .xplh_retry_replay_num_rollover (int_xplh_retry_replay_num_rollover),
  .xplh_retry_replay_seqnum       (int_retry_replay_seqnum),
  .expl_seq_cnt                   (int_expl_seq_cnt),
  .xplh_retry_almost_full         (xplh_replay_buf_almost_full),
  .xplh_control_normal            (xplh_control_normal),
  .xplh_nak_ignore_link_err       (xplh_nak_ignore_link_err),
  .en_tx_throttling               (en_tx_throttling),
  .cdm_ras_des_force_linkdown_noack(cdm_ras_des_force_linkdown_noack),
  .xplh_retrain_req_link_down      (xplh_req_link_down),
  // -------------------------------------------------------------------------------------
  // Command Bus Interface
  // -------------------------------------------------------------------------------------
  .xmlh_xplh_cmd                  (xmlh_xplh_cmd),
  .xplh_xdlh_cmd                  (xplh_xdlh_cmd),
  // -------------------------------------------------------------------------------------
  // Flit Interface
  // -------------------------------------------------------------------------------------
  .xdlh_xplh_flit                 (int_xdlh_xplh_flit),
  .xplh_retry_halt_out            (xplh_retry_halt),
  .halt_in                        (int_xplh_retry_halt),
  .xplh_retry_flit                (xplh_retry_flit),
  .tx_seqnum                      (int_next_tx_seqnum),
  .xplh_retry_idle                (int_retrybuf_idle),
  // -------------------------------------------------------------------------------------
  // Retry Buffer Empty signal for XPLH Pending signal
  // -------------------------------------------------------------------------------------
  .xplh_retry_rbuf_empty          (int_rbuf_empty),
  .xplh_retry_rbuf_empty_retry    (int_rbuf_empty_retry),
  .xplh_retry_nak_11              (int_rbuf_nak_11),
  .xplh_retry_replay_timeout      (int_xplh_replay_timeout),
  // -------------------------------------------------------------------------------------
  // Retry RAM Interface
  // -------------------------------------------------------------------------------------
  .retryram_data                  (retryram_data),
  .xplh_retry_ram_if              (xplh_retry_ram_if),
  .current_data_rate              (current_data_rate)
  ,
  .xplh_retry_ras_dp_err_log      (int_retry_ras_dp_err_log)
  ,
  .ras_dp_err_inj                 (ras_dp_err_inj_to_checkers)
);

// -------------------------------------------------------------------------------------
// Transmitter Sequence Number
// -------------------------------------------------------------------------------------
xplh_tx_seqnum
 u_tx_seqnum (
  // Inputs
  .core_clk             (core_clk),
  .core_rst_n           (core_rst_n),
  .eof                  (int_xplh_retry_flit.eof),
  .enf                  (int_xplh_retry_flit.enf),
  .clear                (int_cmd_reset),
  .sent_nak_11          (int_rbuf_nak_11),
  .cxl_mode_enable      (xplh_protocol_cfg.cxl_mode_enable),
  .sof                  (int_xplh_retry_flit.sof),
  .retry_flit           (int_xplh_retry_flit.retry_flit),
  .halt_in              (xplh_control_halt),
  .tx_replay_seqnum     (int_retry_replay_seqnum),
  // Outputs
  .tx_seqnum            (int_tx_seqnum),
  .tx_seqnum_sof        (int_tx_seqnum_sof),
  .nop_expl_seqnum      (int_nop_expl_seqnum),
  .next_tx_flit_seqnum  (int_next_tx_seqnum)
);

// -------------------------------------------------------------------------------------
// Control Module for Flit Mode
// -------------------------------------------------------------------------------------
xplh_control
 u_xplh_control (
  .core_clk                     (core_clk),
  .core_rst_n                   (core_rst_n),
  .clear_pipe                   (int_cmd_reset),
  .rcvd_expl_seq_num            (rplh_xplh_fm_retry.rcvd_expl_seq_num),
  .nop_expl_seqnum              (int_nop_expl_seqnum),
  .xdlh_xplh_flit               (int_xplh_retry_flit),
  .xplh_control_halt            (xplh_control_halt),
  .xplh_control_flit            (xplh_control_flit),
  .xmlh_xplh_halt               (xplh_flit_prot_halt),
  .xplh_idle_gen_ack            (xplh_idle_gen_ack),
  .tx_seqnum                    (int_tx_seqnum),
  .xplh_pipe_cmd_ack            (xplh_flit_prot_cmd_ack),
  .grant_dllp                   (int_grant_dllp),
  .xmlh_xplh_cmd                (xmlh_xplh_cmd),
  .xplh_control_cmd_ack         (xplh_control_cmd_ack),
  .xplh_control_xmlh_cmd_ack    (int_xmlh_cmd_ack),
  .xplh_control_cmd             (int_xplh_control_cmd),
  .xdlh_xplh_cmd_ack            (xdlh_xplh_cmd_ack),
  .xplh_control_req_rcvry       (int_control_req_rcvry),
  .xdlh_xplh_fm_dllp            (int_xdlh_xplh_fm_dllp),
  .xplh_control_dllp_halt       (xplh_xdlh_dllp_halt),
  .current_data_rate            (current_data_rate),
  .cxl_mode_enable              (xplh_protocol_cfg.cxl_mode_enable),
  .cxl_viral_eof                (cxl_viral_crc_marker_eof),
  .xplh_nop_phy_flit            (xplh_nop_phy_flit),
  .xplh_nop_gen_ack             (xplh_nop_gen_ack),
  .xplh_spif_enable             (xplh_protocol_cfg.spif_enable),
  .xplh_spif_dllp_trdy          (b_xplh_spif.s_pl_dllp_trdy),
//RAS-DES
  .cdm_ras_des_einj1_enable             (cdm_ras_des_einj1_enable),
  .cdm_ras_des_einj1_seq_type           (cdm_ras_des_einj1_seq_type),
  .cdm_ras_des_einj1_bad_seq            (cdm_ras_des_einj1_bad_seq),
  .cdm_ras_des_einj1_count              (cdm_ras_des_einj1_count),
  .xplh_ras_des_einj1_exp_sequm_evt     (xplh_ras_des_einj1_exp_sequm_evt),     
  .xplh_ras_des_einj1_ack_nak_sequm_evt (xplh_ras_des_einj1_ack_nak_sequm_evt),
//
  .xplh_lrsm_replay_cmd         (xplh_retry_replay_cmd),
  .xplh_lrsm_seqnum             (xplh_retry_rcvd_seqnum),
  .xplh_control_sent_ack        (int_xplh_ctrl_sent_ack),
  .xplh_control_sent_nak        (int_xplh_ctrl_sent_nak),
  .xplh_control_tx_nak_cnt      (int_tx_nak_cnt),
  .xplh_control_tx_nak_cnt_incr (int_tx_nak_cnt_incr),
  .retrybuf_idle                (int_retrybuf_idle),
  .retrybuf_empty_retry         (int_rbuf_empty_retry),
  .xplh_control_expl_seq_cnt    (int_expl_seq_cnt),
  .replay_timeout               (int_xplh_replay_timeout),
  .xplh_control_normal          (xplh_control_normal)
    ,
  .ras_dp_err_inj               (ras_dp_err_inj_to_checkers)
  ,
  .xplh_control_flit_count      (xplh_flit_count),
  .xplh_flit_count_en           (xplh_flit_count_en)
  ,
  .xplh_control_acknak_pend     (xplh_acknak_pend)
  ,
  .xplh_control_replay_00_valid (xplh_replay_00_valid)
);

xplh_flit_prot
 #(
  .RAS_DP_PROT_CHK_ID_BASE  (RAS_DP_PROT_CHK_ID_BASE_PROT)
) u_xplh_flit_prot (
  // Inputs
  .core_clk                       (core_clk),
  .core_rst_n                     (core_rst_n),
  .clear                          (int_cmd_reset),
  .cxl_mode_enable                (xplh_protocol_cfg.cxl_mode_enable),
  .halt_in                        (xplh_idle_gen_halt),
  .flit_in                        (xplh_control_flit),
  .cmd_ack                        (xplh_control_cmd_ack),
  // Outputs
  .xplh_flit_prot_halt            (xplh_flit_prot_halt),
  .xplh_flit_prot_flit            (xplh_flit_prot_flit),
  .xplh_flit_prot_cmd_ack         (xplh_flit_prot_cmd_ack),
  .xplh_flit_prot_crc_sof         (int_crc_sof)
  ,
  .xplh_rasdp_error               (xplh_rasdp_error)
  ,
  .xplh_flit_prot_ras_dp_err_log  (int_prot_ras_dp_err_log)
  ,
  .ras_dp_err_inj                 (ras_dp_err_inj_to_checkers)
);

assign int_req_rcvry = int_retry_req_rcvry || int_control_req_rcvry;

// Register the request to enter recovery
delay_n
 #(
  .N  (1)
) u_req_rcvry_reg (
  .clk    (core_clk),
  .rst_n  (core_rst_n),
  .clear  (1'b0),
  .din    (int_req_rcvry),
  .dout   (xplh_smlh_req_rcvry)
);

// IDLE Flit Generator
xplh_idle_gen
 u_xplh_idle_gen (
  // -------------------------------------------------------------------------------------
  // Clock and Reset
  // -------------------------------------------------------------------------------------
  .core_clk                 (core_clk),
  .core_rst_n               (core_rst_n),
  // -------------------------------------------------------------------------------------
  // XPLH Interface
  // -------------------------------------------------------------------------------------
  .xplh_flit                (xplh_flit_prot_flit),
  .xplh_crc_sof             (int_crc_sof),
  // -------------------------------------------------------------------------------------
  // Command Interface
  // -------------------------------------------------------------------------------------
  .xmlh_xplh_cmd            (xmlh_xplh_cmd),
  .halt_in                  (xplh_halt_in),
  // -------------------------------------------------------------------------------------
  // Flit Interface
  // -------------------------------------------------------------------------------------
  .xplh_idle_gen_flit       (xplh_idle_gen_flit),
  .xplh_idle_gen_halt       (xplh_idle_gen_halt),
  .xplh_idle_gen_ack        (xplh_idle_gen_ack),
  .xplh_idle_gen_grant_dllp (int_grant_dllp)
  ,
  .xplh_idle_gen_valid      (xplh_idle_gen_valid)
);

// ----------------------------------------------------------------------------------------------------
// -------------------------------- XPLH Flit Error Injection -----------------------------------------
// ----------------------------------------------------------------------------------------------------
xplh_err_inj
 u_xplh_err_inj (
  // --------------------------------------------------------------------------------------------------
  // Clock and Reset
  // --------------------------------------------------------------------------------------------------
  .core_clk              (core_clk),
  .core_rst_n            (core_rst_n),
  // --------------------------------------------------------------------------------------------------
  // XPLH Interface Inputs
  // --------------------------------------------------------------------------------------------------
  .current_data_rate     (current_data_rate),
  .flit_in               (xplh_idle_gen_flit),
  .halt_in               (b_fs_xplh_xmlh.halt_in),
  .spif_enable           (xplh_protocol_cfg.spif_enable),
  .cxl_mode_enable       (xplh_protocol_cfg.cxl_mode_enable),
  .link_nop_flit_valid   (link_nop_flit_valid_r),
  .phy_nop_flit_valid    (phy_nop_flit_valid_r),
  .idle_flit_valid       (xplh_idle_gen_valid),
  .replay_00_valid       (xplh_replay_00_valid),
  .tx_seqnum             (int_tx_seqnum_sof_r),
  // --------------------------------------------------------------------------------------------------
  // CDM Error Injection Configured Signals Inputs
  // --------------------------------------------------------------------------------------------------
  .err_inj_en            (cdm_plh_flit_err_inj_interface.cfg_flit_err_inj_en),
  .err_inj_tx_en         (cdm_plh_flit_err_inj_interface.cfg_inj_err_tx_flit_ind),
  .err_inj_num           (cdm_plh_flit_err_inj_interface.cfg_inj_err_num),
  .err_inj_data_rate     (cdm_plh_flit_err_inj_interface.cfg_flit_err_inj_en_data_rate),
  .err_inj_flit_type     (flit_type_inj_e'(cdm_plh_flit_err_inj_interface.cfg_flit_type_inj)),
  .err_inj_cons_error    (cdm_plh_flit_err_inj_interface.cfg_consec_err_inj),
  .err_inj_spacing       (cdm_plh_flit_err_inj_interface.cfg_inj_err_spacing),
  .err_inj_error_type    (curr_inj_err_type_e'(cdm_plh_flit_err_inj_interface.cfg_curr_inj_err_type)),
  .err_inj_error_offst   (cdm_plh_flit_err_inj_interface.cfg_flit_err_off),
  .err_inj_error_mag     (cdm_plh_flit_err_inj_interface.cfg_err_mag),
  // --------------------------------------------------------------------------------------------------
  // Flit Interface Outputs
  // --------------------------------------------------------------------------------------------------
  .xplh_err_inj_flit     (xplh_err_inj_flit),
  .xplh_err_inj_halt     (xplh_err_inj_halt),
  .xplh_err_inj_sts      (xplh_err_inj_sts_e)
);

assign xplh_flit_out = xplh_err_inj_flit;
assign xplh_halt_in  = xplh_err_inj_halt;
assign xplh_cdm_flit_err_inj_status = inj_sts_e'(xplh_err_inj_sts_e);

// Register TX Sequence Number with 3 cycles delay to be aligned with the entering flit to the error injection module
delay_n_w_stalling
 #(
  .N          (3),
  .WD         ($bits(int_tx_seqnum_sof)),
  .CAN_STALL  (0)
) u_xplh_tx_seqnum_sof_pipe (
  .clk        (core_clk),
  .rst_n      (core_rst_n),
  .stall      (xplh_idle_gen_halt),
  .clear      (1'b0),
  .din        ({int_tx_seqnum_sof}),
  .dout       ({int_tx_seqnum_sof_r}),
  .stallout   ()
);

// Register NOP flit indicators with 3 cycles delay to be aligned with the entering flit to the error injection module
delay_n_w_stalling
 #(
  .N          (3),
  .WD         ($bits(b_xplh_spif.s_lp_nop_flit) + $bits(xplh_nop_phy_flit)),
  .CAN_STALL  (0)
) u_xplh_nop_flit_valids_pipe (
  .clk        (core_clk),
  .rst_n      (core_rst_n),
  .stall      (xplh_idle_gen_halt),
  .clear      (1'b0),
  .din        ({b_xplh_spif.s_lp_nop_flit, xplh_nop_phy_flit}),
  .dout       ({link_nop_flit_valid_r, phy_nop_flit_valid_r}),
  .stallout   ()
);

//----------------------------------------------
//------- XPLH Flit Latency tracker-------------
//----------------------------------------------
xplh_flit_tracker
 u_xplh_flit_tracker (
 .core_clk(core_clk),
 .core_rst_n(core_rst_n),
 .cdm_xplh_flit_response_type(cdm_xplh_flit_response_type),
 .cdm_xplh_flit_type_measured(cdm_xplh_flit_type_measured),
 .cdm_xplh_flit_track_mode(cdm_xplh_flit_track_mode),
 .cxl_mode_enable(xplh_protocol_cfg.cxl_mode_enable),
 .xplh_flit_sof(b_fs_xplh_xmlh.sof),
 .xplh_flit_eof(b_fs_xplh_xmlh.eof),
 .xplh_flit_data(b_fs_xplh_xmlh.data_out),
 .halt_in(b_fs_xplh_xmlh.halt_in),
 .xplh_flit_seq_number(int_tx_seqnum),
 .rplh_xplh_fm_retry(rplh_xplh_fm_retry),
 .current_data_rate(current_data_rate),
 .mac_phy_rate(mac_phy_rate),
 .flit_latency_tracking(xplh_cdm_flit_latency_tracking)
 );
//----------------------------------------------
//------ End of XPLH Flit Latency tracker-------
//----------------------------------------------

  // Add PTM Monitor to check for PTM bit in Flit Marker
  xplh_ptm_fm_mon
   u_xplh_ptm_fm_mon (
     .core_clk           (core_clk)
    ,.core_rst_n         (core_rst_n)
    ,.cfg_upstream_port  (cfg_upstream_port)
    ,.cxl_mode_enable    (xplh_protocol_cfg.cxl_mode_enable)
    ,.sample_marker      (~b_fs_xplh_xmlh.halt_in & xplh_flit_out.sof & xplh_flit_out.data_valid)
    ,.sample_flit        (~b_fs_xplh_xmlh.halt_in & xplh_flit_out.eof[0] & xplh_flit_out.data_valid)
    ,.report_timestamp   (xmlh_stp_start)
    ,.flit_data          (xplh_flit_out.data)
    // Outputs
    ,.ptm_sot            (xplh_ptm_sot)
    ,.ptm_request        (xplh_ptm_request)
    ,.ptm_response       (xplh_ptm_response)
  );

// Flit Mode MUX
always_comb begin : fm_mux_PROC
  b_fs_xplh_xmlh.flit_prot              = '0; 
  b_fs_xplh_xmlh.ras_dp_err_inband_kbd  = '0;
  b_fs_xplh_xmlh.flit_tlp_dv  = '0;
  if(xmlh_xplh_cmd.flit_mode) begin
    // XMLH Command Interface (direct connection between XMLH and XDLH)
    xplh_xmlh_cmd_ack            = xplh_idle_gen_ack || int_xmlh_cmd_ack;
    xplh_xdlh_cmd                = int_xplh_control_cmd;
    // ARB/MUX to XMLH Interface connections
    b_fs_xplh_xmlh.stp           = {P_NW{1'b0}};
    b_fs_xplh_xmlh.sdp           = {P_NW{1'b0}};
    b_fs_xplh_xmlh.eot           = {P_NW{1'b0}};
    b_fs_xplh_xmlh.pad           = {P_NW{1'b0}};
    b_fs_xplh_xmlh.next_eot      = {P_NW{1'b0}};
    b_fs_xplh_xmlh.next_stp      = {P_NW{1'b0}};
    b_fs_xplh_xmlh.next_sdp      = {P_NW{1'b0}};
    b_fs_xplh_xmlh.data_out      = xplh_flit_out.data;
    b_fs_xplh_xmlh.data_valid    = xplh_flit_out.data_valid;
    b_fs_xplh_xmlh.sof           = xplh_flit_out.sof;
    b_fs_xplh_xmlh.eof           = xplh_flit_out.eof;
    b_fs_xplh_xmlh.enf           = xplh_flit_out.enf;
    b_fs_xplh_xmlh.flit_type_s   = xplh_flit_out.flit_type_s;
    b_fs_xplh_xmlh.pid           = {P_NW{1'b0}};
    b_fs_xplh_xmlh.pkt_pending   = 1'b0;
    // XMLH to ARB/MUX Interface connections
    b_xdlh_xplh_mux.halt_in      = xplh_nop_gen_halt;
    b_xdlh_xplh_mux.rst_flit_alignment = b_fs_xplh_xmlh.rst_flit_alignment;
    b_xdlh_xplh_mux.skip_pending = 1'b0;
    b_xdlh_xplh_mux.cmd_is_data  = 1'b0;
  end else begin
    // XMLH Command Interface (direct connection between XMLH and XDLH)
    xplh_xmlh_cmd_ack            = (xplh_spif_nfm_mode || xplh_protocol_cfg.cxl_mode_enable) ? 1'b1 : xdlh_xplh_cmd_ack;
    xplh_xdlh_cmd                = int_xplh_cmd_r;
    // ARB/MUX to XMLH Interface connections
    b_fs_xplh_xmlh.data_valid    = 1'b0; // Data Valid Indication not used in XMLH
    b_fs_xplh_xmlh.data_out      = b_xdlh_xplh_mux.data_out;
    b_fs_xplh_xmlh.stp           = b_xdlh_xplh_mux.stp;
    b_fs_xplh_xmlh.sdp           = b_xdlh_xplh_mux.sdp;
    b_fs_xplh_xmlh.eot           = b_xdlh_xplh_mux.eot;
    b_fs_xplh_xmlh.pad           = b_xdlh_xplh_mux.pad;
    b_fs_xplh_xmlh.next_eot      = b_xdlh_xplh_mux.next_eot;
    b_fs_xplh_xmlh.next_stp      = b_xdlh_xplh_mux.next_stp;
    b_fs_xplh_xmlh.next_sdp      = b_xdlh_xplh_mux.next_sdp;
    b_fs_xplh_xmlh.sof           = '0;
    b_fs_xplh_xmlh.eof           = '0;
    b_fs_xplh_xmlh.enf           = '0;
    b_fs_xplh_xmlh.flit_type_s.err_inj_en  = '0;
    b_fs_xplh_xmlh.flit_type_s.flit_type   = NOP;
    b_fs_xplh_xmlh.pid           = b_xdlh_xplh_mux.pid;
    b_fs_xplh_xmlh.pkt_pending   = b_xdlh_xplh_mux.pkt_pending;
    // XMLH to ARB/MUX Interface connections
    b_xdlh_xplh_mux.halt_in      = b_fs_xplh_xmlh.halt_in;
    b_xdlh_xplh_mux.rst_flit_alignment = b_fs_xplh_xmlh.rst_flit_alignment;
    b_xdlh_xplh_mux.skip_pending = b_fs_xplh_xmlh.skip_pending;
    b_xdlh_xplh_mux.cmd_is_data  = b_fs_xplh_xmlh.cmd_is_data;
  end
end : fm_mux_PROC

//==============================================================================//


// -------------------------------------------------------------------------------------
//DLLP Detector For PM DLLPs
// -------------------------------------------------------------------------------------
logic  [NW-1:0] pm_dllp_decoder_sdp ;
logic  [NW-1:0] pm_dllp_decoder_eot ;
logic  [DW-1:0] pm_dllp_decoder_data;
logic           pm_dllp_decoder_halt;

// In PCIe mode drive DLLP decoder from XDLH-2-XPLH interface
// In CXL mode drive DLLP Decoder inputs from LPIF interface
assign pm_dllp_decoder_sdp  = xplh_protocol_cfg.spif_enable ? b_xplh_spif.s_lp_dlp_start : b_xdlh_xplh_sp.sdp;
assign pm_dllp_decoder_eot  = xplh_protocol_cfg.spif_enable ? b_xplh_spif.s_lp_tlp_end   : b_xdlh_xplh_sp.eot;
assign pm_dllp_decoder_data = xplh_protocol_cfg.spif_enable ? b_xplh_spif.s_lp_data      : b_xdlh_xplh_sp.data_out;
assign pm_dllp_decoder_halt = xplh_protocol_cfg.spif_enable ? !b_xplh_spif.s_pl_trdy     : b_xdlh_xplh_sp.halt_in;

xplh_pm_dllp_decoder
 
  // Parameters
  #(
    . DW (P_DW),
    . INST (0),
    . DLLP_WD (8)
  )
  u_det_pm_dllp (
//Inputs
    .clk                (core_clk),                
    .rst_n              (core_rst_n),
    .cfg_upstream_port  (cfg_upstream_port),
    .halt               (pm_dllp_decoder_halt),
    .data               (pm_dllp_decoder_data),
    .sdp                (pm_dllp_decoder_sdp),
    .eot                (pm_dllp_decoder_eot),
    .current_data_rate  (current_data_rate),
    .flit_halt          (b_fs_xplh_xmlh.halt_in),
    .flit_data          (b_fs_xplh_xmlh.data_out),
    .flit_mode_en       (xmlh_xplh_cmd.flit_mode),
    .eof                (b_fs_xplh_xmlh.eof),
    .sof                (b_fs_xplh_xmlh.sof),
//Outputs
    .xplh_pm_dllp_ack   (int_det_pm_dllp_ack)
);
// -------------------------------------------------------------------------------------

// DLLP Acknowledges to the PM Block are gated by their corresponding requests
always_comb begin : pm_dllp_ack_PROC
  int_pm_dllp_ack = '0;
  if(pm_xdlh_dllp_req.valid) begin
    if(!cfg_upstream_port && (pm_xdlh_dllp_req.dllp_type == PM_REQUEST_ACK)) begin
      int_pm_dllp_ack.valid = (int_det_pm_dllp_ack.valid && (int_det_pm_dllp_ack.dllp_type == PM_REQUEST_ACK));
      int_pm_dllp_ack.dllp_type = int_pm_dllp_ack.valid ? PM_REQUEST_ACK : NOP2_DLLP;
    end else if(cfg_upstream_port && (pm_xdlh_dllp_req.dllp_type == PM_ENTER_L1)) begin
      int_pm_dllp_ack.valid = (int_det_pm_dllp_ack.valid && (int_det_pm_dllp_ack.dllp_type == PM_ENTER_L1));
      int_pm_dllp_ack.dllp_type = int_pm_dllp_ack.valid ? PM_ENTER_L1 : NOP2_DLLP;
    end else if(cfg_upstream_port && (pm_xdlh_dllp_req.dllp_type == PM_ENTER_L23)) begin
      int_pm_dllp_ack.valid = (int_det_pm_dllp_ack.valid && (int_det_pm_dllp_ack.dllp_type == PM_ENTER_L23));
      int_pm_dllp_ack.dllp_type = int_pm_dllp_ack.valid ? PM_ENTER_L23 : NOP2_DLLP;
    end else if(cfg_upstream_port && (pm_xdlh_dllp_req.dllp_type == PM_ACTIVE_STATE_REQUEST_L1)) begin
      int_pm_dllp_ack.valid = (int_det_pm_dllp_ack.valid && (int_det_pm_dllp_ack.dllp_type == PM_ACTIVE_STATE_REQUEST_L1));
      int_pm_dllp_ack.dllp_type = int_pm_dllp_ack.valid ? PM_ACTIVE_STATE_REQUEST_L1 : NOP2_DLLP; 
    end else if(pm_xdlh_dllp_req.dllp_type == NOP_DLLP) begin
      int_pm_dllp_ack.valid = (int_det_pm_dllp_ack.valid && (int_det_pm_dllp_ack.dllp_type == NOP_DLLP));
      int_pm_dllp_ack.dllp_type = int_pm_dllp_ack.valid ? NOP_DLLP: NOP2_DLLP;
    end else
      int_pm_dllp_ack = '0;
  end
end : pm_dllp_ack_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    xplh_pm_dllp_ack  <= #TP '0;
  else
    xplh_pm_dllp_ack  <= #TP int_pm_dllp_ack;
end

// XPLH_XMLH Interface connected directly to FS_XPLH_XMLH if CX_FREQ_STEP_DL_EN is not enabled and xplh_freq_step is not there
assign b_xplh_xmlh_mp.data_valid   = b_fs_xplh_xmlh.data_valid;
assign b_xplh_xmlh_mp.data_out     = b_fs_xplh_xmlh.data_out;
assign b_xplh_xmlh_mp.stp          = b_fs_xplh_xmlh.stp;
assign b_xplh_xmlh_mp.sdp          = b_fs_xplh_xmlh.sdp;
assign b_xplh_xmlh_mp.eot          = b_fs_xplh_xmlh.eot;
assign b_xplh_xmlh_mp.pad          = b_fs_xplh_xmlh.pad;
assign b_xplh_xmlh_mp.next_stp     = b_fs_xplh_xmlh.next_stp;
assign b_xplh_xmlh_mp.next_eot     = b_fs_xplh_xmlh.next_eot;
assign b_xplh_xmlh_mp.next_sdp     = b_fs_xplh_xmlh.next_sdp;
assign b_xplh_xmlh_mp.pid          = b_fs_xplh_xmlh.pid;
assign b_xplh_xmlh_mp.pkt_pending  = b_fs_xplh_xmlh.pkt_pending;
assign b_xplh_xmlh_mp.sof          = b_fs_xplh_xmlh.sof;
assign b_xplh_xmlh_mp.eof          = b_fs_xplh_xmlh.eof;
assign b_xplh_xmlh_mp.enf          = b_fs_xplh_xmlh.enf;
assign b_xplh_xmlh_mp.flit_tlp_dv  = b_fs_xplh_xmlh.flit_tlp_dv;
assign b_xplh_xmlh_mp.flit_type_s  = b_fs_xplh_xmlh.flit_type_s;
assign b_xplh_xmlh_mp.flit_prot    = b_fs_xplh_xmlh.flit_prot;
assign b_xplh_xmlh_mp.ras_dp_err_inband_kbd = b_fs_xplh_xmlh.ras_dp_err_inband_kbd;
assign b_fs_xplh_xmlh.halt_in            = b_xplh_xmlh_mp.halt_in;
assign b_fs_xplh_xmlh.rst_flit_alignment = b_xplh_xmlh_mp.rst_flit_alignment;
assign b_fs_xplh_xmlh.skip_pending       = b_xplh_xmlh_mp.skip_pending;
assign b_fs_xplh_xmlh.cmd_is_data        = b_xplh_xmlh_mp.cmd_is_data;


// struct of xplh signals that are part of xplh/xmlh interface before entering xplh freq_step module and used in cx_pl
assign xplh_sideband.data_out        = b_fs_xplh_xmlh.data_out;
assign xplh_sideband.halt_in         = b_fs_xplh_xmlh.halt_in;
assign xplh_sideband.stp             = b_fs_xplh_xmlh.stp;
assign xplh_sideband.eot             = b_fs_xplh_xmlh.eot;
assign xplh_sideband.sdp             = b_fs_xplh_xmlh.sdp;
assign xplh_sideband.pad             = b_fs_xplh_xmlh.pad;
assign xplh_sideband.next_stp        = b_fs_xplh_xmlh.next_stp;
assign xplh_sideband.next_eot        = b_fs_xplh_xmlh.next_eot;
assign xplh_sideband.next_sdp        = b_fs_xplh_xmlh.next_sdp;
assign xplh_sideband.sof             = b_fs_xplh_xmlh.sof;
assign xplh_sideband.eof             = b_fs_xplh_xmlh.eof;
assign xplh_sideband.enf             = b_fs_xplh_xmlh.enf;


endmodule
