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
// ---   $Revision: #5 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/products/cx_pl_fm_mux.sv#5 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
//  CX_PL Flit Mode MUX 
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"

module cx_pl_fm_mux
  import cx_pl_pkg::tx_cmd_struct;
  import cx_pl_pkg::xplh_sideband_rasdes_fm;
  import cx_pl_pkg::rplh_xplh_fm_retry_t;
  import cx_pl_pkg::fm_retry_t;
  import cx_pl_pkg::replay_cmd_t;
  import cx_pl_pkg::NAK_11;
  import cx_pl_pkg::NAK_10;
  import cx_pl_pkg::P_TX_SEQNUM_WD;

#(
  parameter   NW                = `CX_NW,           // Number of 32-bit dwords handled        
  parameter   RX_NDLLP          = `CX_RX_NDLLP,     // Max number of DLLPs received per cycle
  parameter   TP                = `TP
) (
  input                          core_clk,
  input                          core_rst_n,
  // ----------------------------------------------------------------------------
  // Inputs from XDLH 
  // ----------------------------------------------------------------------------
  input                          xdlh_pm_pme_to_ack,                     // XDLH Transmitted PME_TO_ACK message 
  input                          xdlh_update_fc_fm,                      // Update FC sent FM
  // ----------------------------------------------------------------------------
  // Inputs from XTLH 
  // ----------------------------------------------------------------------------
  input                           xtlh_pm_pme_to_ack,                   // XTLH Transmitted PME_TO_ACK message 
  input                           xtlh_sof,                             // XTLH to XDLH Start of Flit
  // ----------------------------------------------------------------------------
  // Command Interface
  // ----------------------------------------------------------------------------
  input                           tx_cmd_struct xmlh_xplh_cmd,          // Command Bus Interface
  // ----------------------------------------------------------------------------
  // XDLH-NFM
  //-----------------------------------------------------------------------------
  input                           xdlh_replay_timeout,                 // Data Link Layer Transmit Replay Timeout
  input                           xdlh_replay_num_rlover_err,          // Data Link Layer Transmit Replay Number Rollover
  input                           xdlh_update_fc_nfm,                  // Update FC sent NFM      
  input                           xdlh_nak_sent,                       // Nak sent FM 
  input                           xdlh_ack_sent,                       // Ack sent FM
  input   [RX_NDLLP-1:0]          rdlh_nak,                            // RDLH Nak FM 
  input   [11:0]                  xdlh_curnt_seqnum,                   // Level : Current Tx Sequence number status for Ras D.E.S Silicon Debug
  input                           cdm_ras_des_einj1_enable,            // Error injection 1 enable
  input                           cdm_ras_des_einj1_seq_type,          // Error injection 1 seq# type
  input   [12:0]                  cdm_ras_des_einj1_bad_seq,           // Error injection 1 bad seq# value
  input   [7:0]                   cdm_ras_des_einj1_count,             // Error injection 1 count
  input                           cdm_ras_des_einj2_enable,            // Error injection 2 enable
  input   [1:0]                   cdm_ras_des_einj2_dllp_type,         // Error injection 2 DLLP type

  input   [1:0]                   xplh_ras_des_einj1_exp_sequm_evt,
  input                           xplh_ras_des_einj1_ack_nak_sequm_evt,
  input   [1:0]                   xdlh_ras_des_einj1_exp_sequm_evt,
  input                           xdlh_ras_des_einj1_ack_nak_sequm_evt,             

  output  logic                   cx_pl_xdlh_ras_des_einj1_enable,     // Error injection 1 enable
  output  logic                   cx_pl_xdlh_ras_des_einj1_seq_type,   // Error injection 1 seq# type
  output  logic   [12:0]          cx_pl_xdlh_ras_des_einj1_bad_seq,    // Error injection 1 bad seq# value
  output  logic   [7:0]           cx_pl_xdlh_ras_des_einj1_count,      // Error injection 1 count
  output  logic                   cx_pl_xdlh_ras_des_einj2_enable,     // Error injection 2 enable
  output  logic   [1:0]           cx_pl_xdlh_ras_des_einj2_dllp_type,  // Error injection 2 DLLP type

  output  logic                   cx_pl_xplh_ras_des_einj1_enable,     // Error injection 1 enable
  output  logic                   cx_pl_xplh_ras_des_einj1_seq_type,   // Error injection 1 seq# type
  output  logic   [12:0]          cx_pl_xplh_ras_des_einj1_bad_seq,    // Error injection 1 bad seq# value
  output  logic   [7:0]           cx_pl_xplh_ras_des_einj1_count,      // Error injection 1 count
  output  logic                   cx_pl_xplh_ras_des_einj2_enable,     // Error injection 2 enable
  output  logic   [1:0]           cx_pl_xplh_ras_des_einj2_dllp_type,  // Error injection 2 DLLP type

  output  logic   [1:0]           ras_des_einj1_exp_sequm_evt,
  output  logic                   ras_des_einj1_ack_nak_sequm_evt,
        
  input                           xdlh_retry_req,                      //Retry Request 
  //-------------------------------------------------------
  // XPLH
  //-------------------------------------------------------
  input  xplh_sideband_rasdes_fm  xplh_rasdes,                        // XPLH Rasdes FM signals 
   input [P_TX_SEQNUM_WD-1:0]     xplh_rx_ack_seqnum,                 // Level : Current Rx Ack Sequence number status for Ras D.E.S Silicon Debug
   input [P_TX_SEQNUM_WD-1:0]     xplh_tx_seqnum_value,                     // Level : Current Tx Sequence number status for Ras D.E.S Silicon Debug
  //-------------------------------------------------------
  // RPLH
  //-------------------------------------------------------
  input  rplh_xplh_fm_retry_t     rplh_xplh_fm_retry,                 // RPH XPLH FM Retry 
  //-------------------------------------------------------
  // RDLH
  //-------------------------------------------------------
  input   [11:0]                  rdlh_curnt_rx_ack_seqnum,           // Level : Current Rx Ack Sequence number status for Ras D.E.S Silicon Debug     
  //-----------------------------------------------------------------------------
  // Outputs
  // ----------------------------------------------------------------------------
  output  logic                   cx_pl_pm_pme_to_ack,                // PME_TO_Ack indication
  output   logic                  cx_pl_rasdes_update_fc,             // Transmit update FC from XDLH in NFM and  FM
  output   logic                  cx_pl_rasdes_sent_ack,              // Transmit ACK from XDLH in NFM and from XPLH in FM
  output   logic                  cx_pl_rasdes_sent_nak,              // Transmit NAK from XDLH in NFM and from XPLH in FM
  output   logic [RX_NDLLP-1:0]   cx_pl_rasdes_rdlh_rplh_nak,         // Transmit NAK from RDLH in NFM and from RPLH in FM
   output  logic                  cx_pl_rasdes_rplh_nack_flit,        //RPLH Nak indication
   output  logic [11:0]           cx_pl_rasdes_rx_ack_seqnum,         // Transmit RX seqnum from RDLH in NFM and from XPLH in FM
   output  logic [11:0]           cx_pl_rasdes_tx_seqnum,             // Transmit TX seqnum from XDLH in NFM and from XPLH in FM
  output   logic                  cx_pl_rasdes_replay_timeout,        //Transmit Replay Timeout from XDLH in NFM and from XPLH in FM
  output   logic                  cx_pl_rasdes_replay_num_rlover_err, // Transmit Replay Number Rollover from XDLH in NFM and from XPLH in FM
  output   logic                  cx_pl_rasdes_retry_flit
  ,output  logic                  cx_pl_ptm_retry_flit
);

// ----------------------------------------------------------------------------
// Logic Declarations
// ----------------------------------------------------------------------------
logic int_flit_mode_r;
xplh_sideband_rasdes_fm    int_xplh_rasdes;
logic                      int_xdlh_update_fc_fm;
logic                      int_xtlh_sof;
logic                      xplh_retry_replay_timeout_d;
logic                      xplh_retry_replay_num_rollover_d;
logic                      xplh_retry_flit_d;
logic                      int_xdlh_update_fc_fm_d;
rplh_xplh_fm_retry_t       int_rplh_xplh_fm_retry;
logic [P_TX_SEQNUM_WD-1:0] int_xplh_rx_ack_seqnum;
logic [P_TX_SEQNUM_WD-1:0] int_xplh_tx_seqnum;

always_ff @(posedge core_clk or negedge core_rst_n) begin : fm_cmd_PROC
  if(!core_rst_n)
    int_flit_mode_r <= #TP '0;
  else
    int_flit_mode_r <= #TP xmlh_xplh_cmd.flit_mode;
end : fm_cmd_PROC

// Flit Mode MUX
always_comb begin : fm_mux_PROC
  if(int_flit_mode_r) begin
    cx_pl_pm_pme_to_ack = xtlh_pm_pme_to_ack;
  end else begin
    cx_pl_pm_pme_to_ack = xdlh_pm_pme_to_ack;
  end
end : fm_mux_PROC

// Register the outputs 
delay_n_w_enable
 
#(.N(1'b1), .WD($size(xplh_sideband_rasdes_fm))) 
 u_delay_w_enable_xplh (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (int_flit_mode_r),
    .din        (xplh_rasdes),
    .dout       (int_xplh_rasdes)
);
delay_n_w_enable
 
#(.N(1'b1), .WD($bits(xdlh_update_fc_fm))) 
 u_delay_w_enable_xdlh (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (int_flit_mode_r),
    .din        (xdlh_update_fc_fm),
    .dout       (int_xdlh_update_fc_fm)
);
delay_n_w_enable
 
#(.N(1'b1), .WD(1'b1)) 
 u_delay_w_enable_xtlh (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (int_flit_mode_r),
    .din        (xtlh_sof),
    .dout       (int_xtlh_sof)
);

delay_n_w_enable
 
#(.N(1'b1), .WD($bits(rplh_xplh_fm_retry))) 
 u_delay_w_enable_rplh (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (int_flit_mode_r),
    .din        (rplh_xplh_fm_retry),
    .dout       (int_rplh_xplh_fm_retry)
);
delay_n_w_enable
 
#(.N(1'b1), .WD($bits(xplh_rx_ack_seqnum))) 
 u_delay_w_enable_rplh_seqnum (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (int_flit_mode_r),
    .din        (xplh_rx_ack_seqnum),
    .dout       (int_xplh_rx_ack_seqnum)
);
delay_n_w_enable
 
#(.N(1'b1), .WD($bits(xplh_tx_seqnum_value))) 
 u_delay_w_enable_xplh_seqnum (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (int_flit_mode_r),
    .din        (xplh_tx_seqnum_value),
    .dout       (int_xplh_tx_seqnum)
);

//Nack indication per flit for rasdes
assign cx_pl_rasdes_rplh_nack_flit  = int_rplh_xplh_fm_retry.received.cmd inside {NAK_10,NAK_11} && (int_rplh_xplh_fm_retry.valid);

// Registered version to use for a pulse to CDM for error reporting
always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
        int_xdlh_update_fc_fm_d          <= #TP 1'b0;
        xplh_retry_replay_timeout_d      <= #TP 1'b0;
        xplh_retry_replay_num_rollover_d <= #TP 1'b0;
        xplh_retry_flit_d                <= #TP 1'b0;
        
    end else begin
        int_xdlh_update_fc_fm_d          <= #TP int_xdlh_update_fc_fm;
        xplh_retry_replay_timeout_d      <= #TP int_xplh_rasdes.xplh_retry_replay_timeout;
        xplh_retry_replay_num_rollover_d <= #TP int_xplh_rasdes.xplh_retry_replay_num_rollover;
        xplh_retry_flit_d                <= #TP int_xplh_rasdes.xplh_retry_flit;  
    end
end
// Muxing RASDES Signals according to the mode whether it is NFM or FM 
always_comb begin
cx_pl_rasdes_update_fc             = 1'b0;
cx_pl_rasdes_sent_ack              = 1'b0;
cx_pl_rasdes_sent_nak              = 1'b0;
cx_pl_rasdes_rdlh_rplh_nak         = '0;
cx_pl_rasdes_rx_ack_seqnum         = '0;
cx_pl_rasdes_tx_seqnum             = '0;
cx_pl_rasdes_retry_flit            = 1'b0;
cx_pl_xdlh_ras_des_einj1_enable    = '0;
cx_pl_xdlh_ras_des_einj1_seq_type  = '0;
cx_pl_xdlh_ras_des_einj1_bad_seq   = '0;
cx_pl_xdlh_ras_des_einj1_count     = '0;
cx_pl_xdlh_ras_des_einj2_enable    = '0;
cx_pl_xdlh_ras_des_einj2_dllp_type = '0;
cx_pl_xplh_ras_des_einj1_enable    = '0;
cx_pl_xplh_ras_des_einj1_seq_type  = '0;
cx_pl_xplh_ras_des_einj1_bad_seq   = '0;
cx_pl_xplh_ras_des_einj1_count     = '0;
cx_pl_xplh_ras_des_einj2_enable    = '0;
cx_pl_xplh_ras_des_einj2_dllp_type = '0;

ras_des_einj1_exp_sequm_evt        = '0;
ras_des_einj1_ack_nak_sequm_evt    = '0;

cx_pl_rasdes_replay_timeout        = 1'b0;
cx_pl_rasdes_replay_num_rlover_err = 1'b0;
cx_pl_rasdes_retry_flit            = 1'b0;
cx_pl_ptm_retry_flit               = 1'b0;

 if (xmlh_xplh_cmd.flit_mode) begin
      cx_pl_rasdes_update_fc             = int_xdlh_update_fc_fm & (!int_xdlh_update_fc_fm_d | int_xtlh_sof);
      cx_pl_rasdes_sent_ack              = int_xplh_rasdes.xplh_sent_ack;
      cx_pl_rasdes_sent_nak              = int_xplh_rasdes.xplh_sent_nak;
      cx_pl_rasdes_rdlh_rplh_nak         = {{RX_NDLLP-1{1'b0}},cx_pl_rasdes_rplh_nack_flit};
      cx_pl_rasdes_rx_ack_seqnum         = {2'b00,int_xplh_rx_ack_seqnum};
      cx_pl_rasdes_tx_seqnum             = {2'b00,int_xplh_tx_seqnum};
      cx_pl_xdlh_ras_des_einj1_enable    = '0;
      cx_pl_xdlh_ras_des_einj1_seq_type  = '0;
      cx_pl_xdlh_ras_des_einj1_bad_seq   = '0;
      cx_pl_xdlh_ras_des_einj1_count     = '0;
      cx_pl_xdlh_ras_des_einj2_enable    = '0;
      cx_pl_xdlh_ras_des_einj2_dllp_type = '0;

      cx_pl_xplh_ras_des_einj1_enable    = cdm_ras_des_einj1_enable;
      cx_pl_xplh_ras_des_einj1_seq_type  = cdm_ras_des_einj1_seq_type;
      cx_pl_xplh_ras_des_einj1_bad_seq   = cdm_ras_des_einj1_bad_seq;
      cx_pl_xplh_ras_des_einj1_count     = cdm_ras_des_einj1_count;
      cx_pl_xplh_ras_des_einj2_enable    = cdm_ras_des_einj2_enable;
      cx_pl_xplh_ras_des_einj2_dllp_type = cdm_ras_des_einj2_dllp_type;

      ras_des_einj1_exp_sequm_evt        = xplh_ras_des_einj1_exp_sequm_evt;
      ras_des_einj1_ack_nak_sequm_evt    = xplh_ras_des_einj1_ack_nak_sequm_evt;
   
      cx_pl_rasdes_replay_timeout        = int_xplh_rasdes.xplh_retry_replay_timeout & !xplh_retry_replay_timeout_d;           
      cx_pl_rasdes_replay_num_rlover_err = int_xplh_rasdes.xplh_retry_replay_num_rollover & !xplh_retry_replay_num_rollover_d;    
      cx_pl_rasdes_retry_flit            = int_xplh_rasdes.xplh_retry_flit & !xplh_retry_flit_d;
      cx_pl_ptm_retry_flit               = int_xplh_rasdes.xplh_retry_flit ;
 end else begin 
      cx_pl_rasdes_update_fc             = xdlh_update_fc_nfm;
      cx_pl_rasdes_sent_ack              = xdlh_ack_sent;
      cx_pl_rasdes_sent_nak              = xdlh_nak_sent;
      cx_pl_rasdes_rdlh_rplh_nak         = rdlh_nak;
      cx_pl_rasdes_rx_ack_seqnum         = rdlh_curnt_rx_ack_seqnum;
      cx_pl_rasdes_tx_seqnum             = xdlh_curnt_seqnum;
      cx_pl_xplh_ras_des_einj1_enable    = '0;
      cx_pl_xplh_ras_des_einj1_seq_type  = '0;
      cx_pl_xplh_ras_des_einj1_bad_seq   = '0;
      cx_pl_xplh_ras_des_einj1_count     = '0;
      cx_pl_xplh_ras_des_einj2_enable    = '0;
      cx_pl_xplh_ras_des_einj2_dllp_type = '0;

      cx_pl_xdlh_ras_des_einj1_enable    = cdm_ras_des_einj1_enable;
      cx_pl_xdlh_ras_des_einj1_seq_type  = cdm_ras_des_einj1_seq_type;
      cx_pl_xdlh_ras_des_einj1_bad_seq   = cdm_ras_des_einj1_bad_seq;
      cx_pl_xdlh_ras_des_einj1_count     = cdm_ras_des_einj1_count;
      cx_pl_xdlh_ras_des_einj2_enable    = cdm_ras_des_einj2_enable;
      cx_pl_xdlh_ras_des_einj2_dllp_type = cdm_ras_des_einj2_dllp_type;

      ras_des_einj1_exp_sequm_evt        = xdlh_ras_des_einj1_exp_sequm_evt;
      ras_des_einj1_ack_nak_sequm_evt    = xdlh_ras_des_einj1_ack_nak_sequm_evt;

      cx_pl_rasdes_replay_timeout        = xdlh_replay_timeout;           
      cx_pl_rasdes_replay_num_rlover_err = xdlh_replay_num_rlover_err;    
      cx_pl_rasdes_retry_flit            = xdlh_retry_req;
      cx_pl_ptm_retry_flit               = '0;
 end 
end

endmodule
