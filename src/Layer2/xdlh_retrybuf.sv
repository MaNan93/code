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
// ---    $DateTime: 2024/01/08 11:48:14 $
// ---    $Revision: #19 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_retrybuf.sv#19 $
// -------------------------------------------------------------------------
// --- Module Description: Transmit Data Link Layer Handler Retry Buffer
// -----------------------------------------------------------------------------
// --- This module handles retry buffer function for DLH
// --- 1. retry buffer is designed to keep the previous transmitted tlps
// --- for the necessary retry requirement defined in spec.
// --- 2. retry buffer releases the buffer room when there is an ack
// --- received
// --- 3. Retry buffer size is determined by RBUF_DEPTH and RBUF_WIDTH. The
// --- retry buffer size will also determine the size of the buffer that we
// --- used to store the begining of each tlp's retry buffer address.
// --- This module handles 32b, 64b, 128b, 256b and 512b datapath widths.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

 module xdlh_retrybuf
 import cx_pl_pkg::P_NW;
 import cx_pl_pkg::P_NFM_NW;
 import cx_pl_pkg::P_NFM_RBUF_WD;
 import cx_pl_pkg::NFM_DATA_PAR_WD;
 import cx_pl_pkg::NFM_DW_W_PAR;
 import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
 import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
 import  cx_pl_pkg::P_RAS_RAM_PROT_TYPE;
 import  cx_pl_pkg::P_RAS_RAM_PROT_RANGE;
 import  cx_pl_pkg::P_PARITY_MODE;
 (
    // -- inputs --
    b_xdlh_replay_num,
    b_xdlh_replay,
    b_xdlh_retrain_cnt,
    core_clk,
    core_rst_n,
    smlh_link_in_training,
    rdlh_link_up,
    replay_timer_hold,
    cfg_rasdp_error_mode,
    ras_dp_err_log,
    ras_dp_err_inj,

    tlpgen_rbuf_data,
    tlpgen_rbuf_dv,

    tlpgen_rbuf_sot_128,
    tlpgen_rbuf_eot_128,
    tlpgen_rbuf_badeot_128,
    tlpgen_rbuf_seqnum,
    tlpgen_reply_grant,
    rbuf_xdlh_tlp_len,
    tlpgen_rbuf_len,
    rbuf_halt,
    rdlh_xdlh_rcvd_nack_org,
    rdlh_xdlh_rcvd_ack_org,
    rdlh_xdlh_rcvd_acknack_seqnum,
    cdm_ras_des_force_linkdown_noack,
    cdm_ras_des_einj5_enable,
    cdm_ras_des_einj5_tlp_type,

    // -- outputs --
    rbuf_xmt_data,
    rbuf_xmt_dv,
    rbuf_xmt_done,
    rbuf_xmt_sot_128,
    rbuf_xmt_eot_128,
    rbuf_xmt_badeot_128,
    rbuf_xmt_seqnum,
    rbuf_reply_req,
    rbuf_entry_cnt,
    rbuf_pkt_cnt,
    rbuf_block_new_tlp,
    xdlh_smlh_start_link_retrain,
    xdlh_rbuf_not_empty,
    xdlh_not_expecting_ack,
    xdlh_rdlh_last_xmt_seqnum,


    // Retry buffer RAM interface
    xdlh_retryram_addr,
    xdlh_retryram_data,
    xdlh_retryram_we,
    xdlh_retryram_en,
    xdlh_retryram_halt,
    xdlh_retryram_par_chk_val,
    retryram_xdlh_data,
    retryram_xdlh_depth,
    retryram_xdlh_parerr,

// Performance changes - 2p RAM I/F
 //   xdlh_retrysotram_addr,
    xdlh_retrysotram_waddr,
    xdlh_retrysotram_raddr,
    xdlh_retrysotram_data,
    xdlh_retrysotram_en,
    xdlh_retrysotram_we,
    xdlh_retrysotram_par_chk_val,
    retrysotram_xdlh_data,
    retrysotram_xdlh_parerr,
    retrysotram_xdlh_depth,
    xdlh_retry_req
    ,
    xdlh_smlh_goto_detect
    ,
    xdlh_einj5_dup_evt
    ,
    xdlh_in_reply
);
// ===============================================================
// ----------------------- Parameters ----------------------------
// ===============================================================

parameter INST          = 0;                                // The uniquifying parameter for each port logic instance.
parameter NL            = `CX_NL;                           // Max number of lanes supported
parameter NB            = `CX_NB;                           // Number of symbols (bytes) per clock cycle
parameter NW            = (P_NW>16)? P_NFM_NW : `CX_NW;                           // Number of 32-bit dwords handled by the datapath each clock.
parameter DW            = (32*NW);                          // Width of datapath in bits.
parameter TP            = `TP;                              // Clock to Q delay (simulator insurance)

parameter RBUF_WD       = (P_NW>16) ? P_NFM_RBUF_WD : `RBUF_WIDTH;
parameter RBUF_PW       = `RBUF_PW;

parameter SOTBUF_WD     = `SOTBUF_WIDTH;                    // Stores pointer into RBUF RAM
parameter SOTBUF_PW     = `SOTBUF_L2DEPTH;                  // Indexed by sequence number (or some bits of it)

parameter DATA_PAR_WD         = NFM_DATA_PAR_WD;         // data bus parity width
parameter DW_W_PAR            = NFM_DW_W_PAR;        // Width of datapath in bits plus the parity bits.
parameter RBUF_PROT_WD        = (P_NW > 16) ? `NFM_RBUF_PROT_WD : `RBUF_PROT_WD;
parameter RBUF_CTRL_BITS_WD   = `CX_RBUF_CTRL_WD;
parameter RBUF_CTRL_PROT_WD   = `RBUF_CTRL_PROT_WD;


parameter CTRL_PROT_WD             = `RBUF_CTRL_PROT_WD;     //parity width for the control signals
parameter SOTBUF_PROT_WD           = `CX_RAS_SOTBUF_PROT_WD; //parity width for the SOTBUF
parameter RAS_PROT_TYPE            = `CX_RAS_PROT_TYPE;
parameter RAS_DATAPATH_EN          = (`CX_RASDP!=0) ? 1 : 0 ;
parameter RAS_PROT_RANGE           = `CX_RAS_PROT_RANGE;
parameter RAS_PROT_CORRECT_EN      = `CX_RAS_CORRECTION_EN;
parameter RAS_RAM_PROT_RANGE       = `CX_RAS_RAM_PROT_RANGE;
parameter RAS_PARITY_MODE          = `CX_RAS_PARITY_MODE;
parameter RAS_DP_PROT_CHK_ID_BASE_XDLH_RETRY_BUF = 0;

parameter DATA_PROT_WD        =
                                        (((RAS_DATAPATH_EN==1) && (RAS_PROT_TYPE==0) ) ? DATA_PAR_WD : 0 ) +
                                    0 ;


parameter ALL_ZERO_DATA   = {
                              `CX_RAS_ALL_0S_PROT_CODE,
                              {DW{1'b0}}
                            };
parameter ALL_ZERO_SOTBUF = {
                               `CX_RAS_ALL_0S_PROT_CODE,
                             {RBUF_PW{1'b0}}
                             };

parameter MAX_SEQNUM    = 13'd4096;

parameter S_IDLE                = 4'h0;
parameter S_REPLY_REQ           = 4'h1;
parameter S_IN_REPLY            = 4'h2;
parameter S_WAIT_N_LATENCY_RETRYRAM = 4'h3;
parameter S_DONE_PIPE           = 4'h4;
parameter S_PRE_REQ             = 4'h6;
parameter S_WAIT_LATENCY        = 4'h8;
parameter S_SET_REPLY_REQ       = 4'h9;
parameter S_WAIT_N_LATENCY_SOTRAM = 4'ha;

parameter ESOT_WD =  (NW==16) ? 5 : (NW==8) ? (NW/2) : (NW-1);

parameter RETRYRAM_REG_RETRYBUF_INPUTS     = 1; // >= 1 always
parameter RETRYSOTRAM_REG_RETRYBUF_INPUTS  = 1; // >= 1 always

// To meet timing it is possible register the retrybuf output signals to the RAMs
parameter RETRYSOTRAM_REG_RETRYBUF_OUTPUTS = `CX_RETRYSOTRAM_REGOUT; // 0,1
parameter RETRYRAM_REG_RETRYBUF_OUTPUTS    = `CX_RETRYRAM_REGOUT;    // 0,1

parameter RETRY_RAM_RD_LATENCY             = `CX_RETRY_RAM_RD_LATENCY;     // 1(default), 2  #Latency = 1 for normal RAM
parameter RETRY_SOT_RAM_RD_LATENCY         = `CX_RETRY_SOT_RAM_RD_LATENCY; // 1(default), 2  #Latency = 1 for normal RAM

parameter DFIFO_WIDTH  =  (
                         // Data signals
                        RBUF_WD +                   // retryram_xdlh_data,
                        1 +                         // retryram_xdlh_parerr,
                        1                           // xdlh_retryram_rd_d
                        + RBUF_PW
                        );

parameter PIPE2_WIDTH  =  (
                        // RETRY CTRL signals
                        1                           // xdlh_retryram_rd
                        );

parameter PIPE3_WIDTH  =  (
                         // Data signals
                        SOTBUF_WD +                 // retrysotram_xdlh_data,
                        1                           // retrysotram_xdlh_parerr,
                        );
parameter PIPE4_WIDTH  =  (
                        // SOT CTRL signals
                        1 +                         // xdlh_retrysotram_rd
                        1                           // latch_retry_start_addr
                        );

// REGOUT
parameter RETRYSOTRAM_REGOUT_WIDTH  =  (
                        SOTBUF_PW +                 // xdlh_retrysotram_waddr;          // Write Adrress to retry buffer RAM
            SOTBUF_PW +                 // xdlh_retrysotram_raddr;          // Read Adrress to retry buffer RAM
            SOTBUF_WD +                 // xdlh_retrysotram_data;            // Write data to retry buffer RAM
            1 +                         // xdlh_retrysotram_we;              // Write enable to retry buffer RAM
            1                           // xdlh_retrysotram_en;              // Read enable to retry buffer RAM
                        );

parameter RETRYRAM_REGOUT_WIDTH  =  (
                        1                           // xdlh_retryram_halt;
                        );
// END REGOUT

// ===============================================================
// ----- Inputs ---------------
// ===============================================================
xdlh_replay_num_if.master_mp    b_xdlh_replay_num;
xdlh_replay_timer_if.master_mp  b_xdlh_replay;
xdlh_retrain_cnt_if.master_mp   b_xdlh_retrain_cnt;
input                    core_clk;
input                    core_rst_n;
input                    smlh_link_in_training;
input                    rdlh_link_up;
input                    replay_timer_hold;             // Hold REPLAY_TIMER during Link retraining
input   [DW_W_PAR-1:0]   tlpgen_rbuf_data;
input                    tlpgen_rbuf_dv;

input   [NW-1:0]         tlpgen_rbuf_sot_128;
input   [NW-1:0]         tlpgen_rbuf_eot_128;
input   [NW-1:0]         tlpgen_rbuf_badeot_128;

input   [11:0]           tlpgen_rbuf_seqnum;
input                    tlpgen_reply_grant;
input                    rbuf_halt;
input                    rdlh_xdlh_rcvd_nack_org;        // RDLP pulse signal to indicate that there was a nack pkt received, and its nack sequence number driven to rdlh_xdlh_rcvd_acknack_seqnum
input                    rdlh_xdlh_rcvd_ack_org;         // RDLP pulse signal to indicate that there was a ack pkt received, and its ack sequence number driven to rdlh_xdlh_rcvd_acknack_seqnum
input   [11:0]          rdlh_xdlh_rcvd_acknack_seqnum;  // RDLP received ack or nack pkt sequence number
input                    cdm_ras_des_force_linkdown_noack;
input                    cdm_ras_des_einj5_enable ;
input                    cdm_ras_des_einj5_tlp_type ;


output [10:0]       rbuf_xdlh_tlp_len;
input  [10:0]       tlpgen_rbuf_len;


input                           cfg_rasdp_error_mode;
output ras_dp_err_log_t [1:0]   ras_dp_err_log;
input  ras_dp_err_inj_t         ras_dp_err_inj;


// a tlp has request to be transmitted. At worst case, the tlp should be scheduled out at next 4 cycles (3 for FC pkt, 1for acknack)
output  [DW_W_PAR-1:0]  rbuf_xmt_data;

output  [NW-1:0]        rbuf_xmt_sot_128;
output  [NW-1:0]        rbuf_xmt_eot_128;
output  [NW-1:0]        rbuf_xmt_badeot_128;

output                  rbuf_xmt_dv;
output                  rbuf_xmt_done;
output                  rbuf_reply_req;

output  [11:0]           rbuf_xmt_seqnum;
output  [11:0]           rbuf_pkt_cnt;
output  [RBUF_PW:0]     rbuf_entry_cnt;                 // Number of entry available
output                  rbuf_block_new_tlp;             // stop new tlp when a reply started, until a new progress has been made from ACK or NAK.
output                  xdlh_smlh_start_link_retrain;
output                   xdlh_rbuf_not_empty;
output                   xdlh_not_expecting_ack;
output  [11:0]           xdlh_rdlh_last_xmt_seqnum;


// Retry buffer RAM interfaces inputs/outputs declaration
input   [SOTBUF_WD -1:0]  retrysotram_xdlh_data;            // Data coming back from Retry buffer RAM
input   [SOTBUF_PW -1:0]  retrysotram_xdlh_depth ;
input                     retrysotram_xdlh_parerr ;
input   [RBUF_WD-1:0]     retryram_xdlh_data;               // Data coming back from Retry buffer RAM
input   [RBUF_PW-1:0]     retryram_xdlh_depth;              // Depth of retry buffer
input                     retryram_xdlh_parerr;             // retry buffer ram parity error detected
output  [RBUF_PW-1:0]     xdlh_retryram_addr;               // Adrress to retry buffer RAM
output  [RBUF_WD-1:0]     xdlh_retryram_data;               // Write data to retry buffer RAM
output                    xdlh_retryram_we;                 // Write enable to retry buffer RAM
output                    xdlh_retryram_en;                 // Read enable to retry buffer RAM
output                    xdlh_retryram_par_chk_val;        // parity check valid to retry buffer RAM
output                    xdlh_retryram_halt;

// Performance changes - 2p RAM I/F
// output  [SOTBUF_PW -1:0]  xdlh_retrysotram_addr;          // Adrress to retry buffer RAM
output  [SOTBUF_PW -1:0]  xdlh_retrysotram_waddr;          // Write Adrress to retry buffer RAM
output  [SOTBUF_PW -1:0]  xdlh_retrysotram_raddr;          // Read Adrress to retry buffer RAM
output  [SOTBUF_WD -1:0]  xdlh_retrysotram_data;            // Write data to retry buffer RAM
output                    xdlh_retrysotram_we;              // Write enable to retry buffer RAM
output                    xdlh_retrysotram_en;              // Read enable to retry buffer RAM
output                    xdlh_retrysotram_par_chk_val;     // parity check valid to retry buffer RAM
output                    xdlh_retry_req;                   // Retry Event
output                    xdlh_smlh_goto_detect;            // Force ltssm to go to detect state
output                    xdlh_einj5_dup_evt;               // Error injection 5 Duplicate TLP event
output                    xdlh_in_reply;                    // Retry FSM in the REPLY state
//
// ===============================================================
// ------------- IO declaration  ----------------
// ===============================================================
reg     [DW_W_PAR-1:0]   rbuf_xmt_data;
reg     [NW-1:0]          rbuf_xmt_sot_128;
reg     [NW-1:0]          rbuf_xmt_eot_128;
reg     [NW-1:0]          rbuf_xmt_badeot_128;
reg                      rbuf_xmt_dv;
wire                     rbuf_reply_req;
wire                     rbuf_xmt_done;
reg     [11:0]           rbuf_xmt_seqnum;
reg                      xdlh_smlh_start_link_retrain;
reg                      xdlh_rbuf_not_empty;
reg                      xdlh_not_expecting_ack;
reg                      rbuf_block_new_tlp;
wire    [11:0]           xdlh_rdlh_last_xmt_seqnum;
reg     [RBUF_PW:0]      rbuf_entry_cnt;                 // Number of entries available
reg     [11:0]           rbuf_pkt_cnt;
wire                     sotbuf_parerr;
reg                      xdlh_retry_req;
reg                      xdlh_smlh_goto_detect;
reg                      xdlh_smlh_start_link_retrain_1d;
reg     [1:0]            xdlh_smlh_start_link_retrain_cnt;

// ===============================================================
// ------------- Internal signals declaration  ----------------
// ===============================================================
//
// Now assign RAM input data
wire     [DW_W_PAR-1:0] int_data;
wire     [DW_W_PAR-1:0] retry_ram_data;
reg     [NW-1:0]        int_sot_128;
reg     [NW-1:0]        int_eot_128;
reg     [NW-1:0]        int_badeot_128;
reg     [11:0]          int_seqnum_c;
reg     [NW-1:0]        latchd_int_sot_128;
reg     [NW-1:0]        latchd_int_eot_128;
reg     [NW-1:0]        latchd_int_badeot_128;
reg      [11:0]         int_seqnum;
reg      [DW_W_PAR-1:0] latchd_int_data;
reg      [11:0]         latchd_int_seqnum;

wire                    int_halt;
reg                     dlyd_int_halt;

wire    [RBUF_WD-1:0]   rbuf_din;
wire    [RBUF_WD-1:0]   rbuf_dout;
wire    [RBUF_WD-1:0]   rbuf_dout_chk;
wire                    rbuf_parerr;

// Need to latch the retry RAM address to be able to
// report the RAM address where a protection error has been detected
reg  [RBUF_PW-1:0]                  xdlh_retryram_addr_1d;
reg  [SOTBUF_PW-1:0]                xdlh_retrysotram_raddr_1d;
wire [SOTBUF_PW-1:0]                int_xdlh_retrysotram_err_addr;
reg  [RBUF_PW-1:0]                  int_xdlh_retryram_err_addr;
wire [2:0]                          ras_stat_xdlh_retrybuf_corr;
wire [2:0]                          ras_stat_xdlh_retrybuf_uncorr;
reg  [RBUF_PW-1:0]                  retryram_datactrl_protect_checker_addr;
wire                                ras_xdlh_prot_disable;
wire                                ras_err_inj_done_rbuf;
wire                                ras_err_inj_done_sotbuf;
wire [2:0]                          rbuf_addr_err_inj_done;
wire [1:0]                          sotbuf_addr_err_inj_done;
wire                                rasdp_retryram_par_err_inj_done;

reg     [RBUF_WD-1:0]   retryram_xdlh_data_dd;
reg                     retryram_xdlh_parerr_dd;

// To report the right address when there is a failure
reg [RBUF_PW-1:0] xdlh_retryram_addr_dd[RETRY_RAM_RD_LATENCY + RETRYRAM_REG_RETRYBUF_INPUTS - 1:0];
always @(posedge core_clk or negedge core_rst_n)
  begin
    integer i;

    if (!core_rst_n) begin
       for(i = 0; i < RETRY_RAM_RD_LATENCY + RETRYRAM_REG_RETRYBUF_INPUTS; i = i + 1)
          xdlh_retryram_addr_dd[i] <= #TP 0;
    end else begin
       for(i = 0; i < RETRY_RAM_RD_LATENCY+RETRYRAM_REG_RETRYBUF_INPUTS; i = i + 1) begin
         if (xdlh_retryram_halt && 1'b0)
           xdlh_retryram_addr_dd[i] <= #TP xdlh_retryram_addr_dd[i];
         else begin
          if(i==0)
            xdlh_retryram_addr_dd[i] <= #TP xdlh_retryram_addr;
          else
            xdlh_retryram_addr_dd[i] <= #TP xdlh_retryram_addr_dd[i-1];
         end
      end // for
    end
  end

assign int_xdlh_retryram_err_addr = xdlh_retryram_addr_dd[RETRY_RAM_RD_LATENCY + RETRYRAM_REG_RETRYBUF_INPUTS - 1];//xdlh_retryram_addr_2d;


assign rbuf_dout   = retryram_xdlh_data_dd;
// assign rbuf_parerr = retryram_xdlh_parerr_dd; // NOTE: it was already commented

wire    [RBUF_PW-1:0]   rbuf_addr;
reg     [RBUF_PW-1:0]   rbuf_raddr;
reg     [RBUF_PW-1:0]   int_rbuf_waddr;
reg     [RBUF_PW-1:0]   rbuf_waddr;
reg     [RBUF_PW-1:0]   latchd_start_waddr;
reg     [RBUF_PW-1:0]   next_ackd_tlp_addr; // the rbuf addr of the first unacknowledged tlp
wire                    rbuf_we;
wire    [RBUF_PW-1:0]   rbuf_waddr_plus1;
wire    [RBUF_PW-1:0]   rbuf_raddr_plus1;
// We assume the SOTBUF buffer is a register file under normal conditions, so it is not external
wire    [SOTBUF_PW-1:0] sotbuf_addr;
wire    [SOTBUF_PW-1:0] sotbuf_raddr;
reg     [SOTBUF_PW-1:0] sotbuf_waddr;
wire    [SOTBUF_PW-1:0] sotbuf_waddr_plus1;
wire    [SOTBUF_PW-1:0] sotbuf_waddr_minus1;
wire                    sotbuf_en;
wire                    sotbuf_we;
wire    [SOTBUF_WD-1:0] sotbuf_din;
wire    [RBUF_PW-1:0]   sotbuf_dout;

reg                     latchd_int_dv;
wire                    int_dv;
reg     [11:0]          schd_ackd_seqnum;
wire    [12:0]          schd_ackd_seqnum_plus1;
reg     [11:0]          ackd_seqnum;
wire    [12:0]          ackd_seqnum_plus1;
reg     [11:0]          rbuf_last_xmt_seqnum;
wire                    block_reply_start;
wire                    latch_retry_start_addr;
reg                     latch_retry_start_addr_regout;    // DELAY(RETRYSOTRAM_REGOUT)  [latch_retry_start_addr]
wire                    latch_retry_start_addr_d;         // DELAY(RETRY_SOT_RAM_RD_LATENCY)  [latch_retry_start_addr]
reg                     latch_retry_start_addr_dd;        // DELAY(RETRY_SOT_RAM_RD_LATENCY+1)[latch_retry_start_addr]

reg                     retry_requested;
reg     [3:0]           state;
wire                    all_tlp_schd_ackd;
wire                    xdlh_in_reply;
wire                    seqnum_upd;
reg                     seqnum_upd_by_ack;
reg                     seqnum_upd_by_nak;
reg                     rdlh_xdlh_rcvd_nack_d;
reg                     rdlh_xdlh_rcvd_ack_d;
wire                    reply_req;
wire                    rbuf_reply_done;
wire                    rbuf_reply_abort;
wire    [NW-1:0]        retryram_eot_128;
reg     [NW-1:0]        retryram_sot_128;
reg                     tlpgen_reply_grant_d;
wire                    reply_grant;

wire [RBUF_CTRL_BITS_WD-1:0] rbuf_ctrlbits;

wire                    einj5_dup_en;
wire                    einj5_dup_evt;
wire                    rdlh_xdlh_rcvd_ack;
wire                    rdlh_xdlh_rcvd_nack;

reg load_start_addr;
reg next_start_addr;

wire tlpgen_sot_only;
wire tlpgen_sot_eot;
wire tlpgen_eot_2;
wire tlpgen_eot_sot;
wire tlpgen_eot_sot_eot;
wire tlpgen_no_badeot;
wire tlpgen_eot_1;
wire tlpgen_badeot;
wire tlpgen_sot;
wire tlpgen_eot;
wire tlpgen_eot_only;
wire second_badeot;
wire tlpgen_eot_is_last;
wire tlpgen_sot_is_last;
wire rbuf_sot_eot_d;
wire rbuf_eot_only;
wire rbuf_eot_sot;
wire rbuf_eot_sot_eot;
wire retryram_sot1;
wire retryram_eot_1;
wire retryram_eot_2;
wire rbuf_sot_eot;
wire rbuf_sot_only;
wire rbuf_eot;
wire no_sot_eot;
wire reply_done;

wire [DW-1:0] rbuf_mem_din;
wire [ESOT_WD-1:0] retryram_sot_enc;

reg int_dv_q;
wire first_tlp;
reg rbuf_latched_1eot;


wire  [10:0] payload_len;              // Payload Length
wire  [10:0] int_rbuf_tlp_len;
reg   [10:0] latchd_rbuf_tlp_len;
reg   [10:0] rbuf_xdlh_tlp_len;
wire  [10:0] retry_ram_tlp_len;

reg reload_start_addr;
reg reload_start_addr_q;

reg smlh_link_in_training_d;
wire smlh_link_in_training_fall; // indicates an exit from the macro state (Configuration+Recovery)
wire link_retrain_pending;

wire capture_seqnum;
reg tlpgen_eot_pending;

// ===============================================================
// Design begin
// ===============================================================

// Error injection
assign einj5_dup_en        = cdm_ras_des_einj5_enable & (cdm_ras_des_einj5_tlp_type==1'b0);
assign einj5_dup_evt       = rdlh_xdlh_rcvd_nack_org | rdlh_xdlh_rcvd_ack_org;
assign xdlh_einj5_dup_evt  = einj5_dup_en & einj5_dup_evt;
assign rdlh_xdlh_rcvd_ack  = einj5_dup_en ? 1'b0          : rdlh_xdlh_rcvd_ack_org;
assign rdlh_xdlh_rcvd_nack = einj5_dup_en ? einj5_dup_evt : rdlh_xdlh_rcvd_nack_org;

//64b block
//-----------------------------------------------------

//32b block
//-----------------------------------------------------

assign rbuf_we              = tlpgen_rbuf_dv;
assign rbuf_addr            = rbuf_we ? rbuf_waddr : rbuf_raddr;
assign rbuf_waddr_plus1     = (rbuf_waddr == retryram_xdlh_depth) ?  0 : rbuf_waddr + 1'b1;
assign rbuf_raddr_plus1     = (rbuf_raddr == retryram_xdlh_depth) ?  0 : rbuf_raddr + 1'b1;

wire [RBUF_PW-1:0] latchd_start_waddr_plus1;
assign latchd_start_waddr_plus1 = (latchd_start_waddr == retryram_xdlh_depth) ?  0 : latchd_start_waddr + 1'b1;


wire rbuf_en;
assign rbuf_en = ((state != S_IDLE)
&& (state != S_PRE_REQ) && (state != S_SET_REPLY_REQ)
&& (state != S_REPLY_REQ) && (state != S_WAIT_N_LATENCY_SOTRAM)
) | rbuf_we;

reg xdlh_retryram_rd_regout;     // RD RETRYRAM RETRY_RAM_REG_RETRY_OUTPUTS                                     DELAYED
reg xdlh_retryram_rd_d;          // RD RETRYRAM RETRY_RAM_REG_RETRY_OUTPUTS+RETRY_RAM_RD_LATENCY                DELAYED
reg xdlh_retryram_rd_dd_m1;      // RD RETRYRAM RETRY_RAM_REG_RETRY_OUTPUTS+RETRY_RAM_RD_LATENCY+N REGOUT-1     DELAYED

wire xdlh_retrysotram_rd;        // RD SOTRAM
reg  xdlh_retrysotram_rd_regout; // RD SOTRAM RETRY_SOT_RAM_REG_RETRY_OUTPUTS                                   DELAYED
reg  xdlh_retrysotram_rd_d;      // RD SOTRAM RETRY_SOT_RAM_REG_RETRY_OUTPUTS+RETRY_SOT_RAM_RD_LATENCY          DELAYED
reg  xdlh_retrysotram_rd_dd;     // RD SOTRAM RETRY_SOT_RAM_REG_RETRY_OUTPUTS+RETRY_SOT_RAM_RD_LATENCY+N REGOUT DELAYED

wire xdlh_retryram_rd;
assign xdlh_retryram_rd = rbuf_en & !rbuf_we & !rbuf_reply_done; //rbuf_reply_done = (rbuf_wadd == rbuf_radd)
assign xdlh_retryram_par_chk_val = xdlh_retryram_rd_d;
wire xdlh_retryram_par_chk_val_dd;


// To know if the retrybuf is full or empty. empty only if last_retryram_action_was_we=0
reg last_retryram_action_was_we;
always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
        last_retryram_action_was_we <= #TP 1'b1;
            end else if(xdlh_retryram_we) begin
                last_retryram_action_was_we <= #TP 1'b1;
            end else if(xdlh_retryram_rd) begin
                last_retryram_action_was_we <= #TP 1'b0;
            end else begin
                last_retryram_action_was_we <= #TP last_retryram_action_was_we;
    end
end

// ##############################################################################################################################
// BEGIN RETRYRAM REGOUT RETRYBUF OUTPUTs
// ##############################################################################################################################

wire   [RETRYRAM_REGOUT_WIDTH-1 :0]        xdlh_retryram_bus_regin;

assign xdlh_retryram_bus_regin = {
                                   dlyd_int_halt
                                 };

reg   [RETRYRAM_REGOUT_WIDTH-1 :0]        xdlh_retryram_bus;
reg xdlh_retryram_rd_ctrl;
genvar i;
generate if (RETRYRAM_REG_RETRYBUF_OUTPUTS > 0)begin : retrybufout
    reg    [RETRYRAM_REGOUT_WIDTH-1 :0]        xdlh_retryram_bus_regout[RETRYRAM_REG_RETRYBUF_OUTPUTS-1:0];
    reg [RETRYRAM_REG_RETRYBUF_OUTPUTS-1:0]    xdlh_retryram_rd_reg;

    always @(posedge core_clk or negedge core_rst_n)begin
        if(!core_rst_n)begin
            xdlh_retryram_bus_regout[0] <= #TP 0;
            xdlh_retryram_rd_reg[0] <= #TP 0;
        end else begin
            xdlh_retryram_bus_regout[0] <= #TP xdlh_retryram_bus_regin;
            xdlh_retryram_rd_reg[0] <= #TP xdlh_retryram_rd;
        end
    end

    for(i = 1; i < RETRYRAM_REG_RETRYBUF_OUTPUTS; i++)begin
        always @(posedge core_clk or negedge core_rst_n)begin
            if(!core_rst_n)begin
                xdlh_retryram_bus_regout[i] <= #TP 0;
                xdlh_retryram_rd_reg[i] <= #TP 0;
            end else begin
                xdlh_retryram_bus_regout[i] <= #TP xdlh_retryram_bus_regout[i-1];
                xdlh_retryram_rd_reg[i] <= #TP xdlh_retryram_rd_reg[i-1];
            end
        end
    end
    
    assign xdlh_retryram_bus = xdlh_retryram_bus_regout[RETRYRAM_REG_RETRYBUF_OUTPUTS-1];
    assign xdlh_retryram_rd_ctrl    = xdlh_retryram_rd_reg[RETRYRAM_REG_RETRYBUF_OUTPUTS-1];
end else begin  : retrybufout // if (RETRYRAM_REG_RETRYBUF_OUTPUTS > 0)
    assign xdlh_retryram_bus          = xdlh_retryram_bus_regin;
    assign xdlh_retryram_rd_ctrl      = xdlh_retryram_rd;
end
endgenerate

// Assign outputs to physical RAM
assign {
                        xdlh_retryram_halt
        } = xdlh_retryram_bus;


assign xdlh_retryram_addr = rbuf_addr;
assign xdlh_retryram_data = rbuf_din;
assign xdlh_retryram_we = rbuf_we;
assign xdlh_retryram_en = rbuf_en;

assign xdlh_retryram_rd_regout    = xdlh_retryram_rd_ctrl;

// ##############################################################################################################################
// END RETRYRAM REGOUT RETRYBUF OUTPUTs
// ##############################################################################################################################

//-----------------------------------------------------

// address control logic
//
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
       reload_start_addr <= #TP 1'b0;
    else reload_start_addr <= #TP  latch_retry_start_addr & seqnum_upd;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
       reload_start_addr_q <= #TP 1'b0;
    else reload_start_addr_q <= #TP  reload_start_addr;

assign reply_grant = tlpgen_reply_grant_d;

reg [RBUF_PW-1:0] rbuf_raddr_nxt;

always @ (*)
begin: rbuf_raddr_nxt_PROC
  if (latch_retry_start_addr_dd | reload_start_addr)
  // Load the rbuf_addr directly from sotbuf to prevent race condition between seqnum and rbuf address
    rbuf_raddr_nxt = sotbuf_dout;
  else if (((state == S_IN_REPLY | state == S_WAIT_N_LATENCY_RETRYRAM) & !int_halt & !rbuf_reply_done))
    rbuf_raddr_nxt = rbuf_raddr_plus1;
  else
    rbuf_raddr_nxt = rbuf_raddr;
end

reg sotbuf_we_d;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        int_rbuf_waddr      <= #TP {RBUF_PW{1'b0}};
        rbuf_raddr          <= #TP {RBUF_PW{1'b0}};
        latchd_start_waddr  <= #TP {RBUF_PW{1'b0}};
        next_ackd_tlp_addr  <= #TP {RBUF_PW{1'b0}};
        ackd_seqnum         <= #TP 12'hFFF;
        sotbuf_we_d         <= #TP 1'b1;
        tlpgen_reply_grant_d<= #TP 1'b0;
    end else begin
        sotbuf_we_d         <= #TP sotbuf_we;
        tlpgen_reply_grant_d<= #TP tlpgen_reply_grant;
        rbuf_raddr          <= #TP rbuf_raddr_nxt;

//-----------------------------------------------------
//128b, 256b, 512b block
        if (rbuf_we & (!next_start_addr & load_start_addr))
          int_rbuf_waddr   <= #TP latchd_start_waddr ;

        else if (rbuf_we & (next_start_addr & load_start_addr))
          int_rbuf_waddr   <= #TP latchd_start_waddr_plus1;

         else if (rbuf_we & ( !tlpgen_eot | (tlpgen_eot & !tlpgen_badeot)) | second_badeot)
          int_rbuf_waddr   <= #TP rbuf_waddr_plus1;

//-----------------------------------------------------

//-----------------------------------------------------

        //
        // latch the starting address of a tlp when the tlp has been
        // written into retry buffer so that we can rewind when it is
        // a poisond tlp
       if (rbuf_we & tlpgen_sot)
          latchd_start_waddr <= #TP rbuf_waddr ;

        // When update the acked sequence number and the next acked tlp
        // addre, there could be a contention with current transmission of
        // a tlp that is also update the single port SOT RAM. Therefore, we
        // need to schedule a cycle that sot RAM read output is stable
        // to take a snap shot for updating the next ackd address pointer and the ackd sequence number.
    // Note: it is important to update the next acked address together
    // with acked sequence number.
        //
        //
        // Note: sotbuf_we_d indicates that the sotram output is not capable of providing the read out results.
        //       and when seq_upd_en is not assert, it inidcates that scheduled sequence number (i.e, SOT read address) has been stable for a cycle such that the output data from RAM
        //       on sotbuf_dout has bee ready for correlating to acked sequence number.


 // Performance change
//128b, 256b, 512b block
        if ( all_tlp_schd_ackd )
            if(!tlpgen_eot_pending)  // it means rbuf is not being written, therefore can use current waddr as the best approximation of start addr for next packet
                next_ackd_tlp_addr       <= #TP  rbuf_waddr;
            else  // it means rbuf is currently being written, therefore use the latched start addr instead
                next_ackd_tlp_addr       <= #TP  latchd_start_waddr;
        else if( !all_tlp_schd_ackd && xdlh_retrysotram_rd_dd )
           next_ackd_tlp_addr       <= #TP  sotbuf_dout;
//-----------------------------------------------------

        if (!sotbuf_we_d & !seqnum_upd )
    // update the actual seqnum togather with the next acked address
           ackd_seqnum             <= #TP schd_ackd_seqnum ;
    end


// NEXTACK pointer RAM is designed to store the starting address of a tlp that
// is stored inside retrybuffer. It is address by the sequence number of
// an ack or nack dllp.
// NEXTACK buffer has the size of the max number of allowed tlp into retry buffer assuming the shortest tlp (3dword long)
// NEXTACK buffer is a circular buffer that wraps around  according to
// ackd_seqnum or last_xmt_seqnum. These seqnum mod NEXTACKBUF_DEPTH determines
// the address of the NEXTACK buffer read or write. Read address is depending
// on the ackd_seqnum. Write address is depending on last_xmt_seqnum
//
assign tlpgen_eot = |tlpgen_rbuf_eot_128;
assign tlpgen_sot = |tlpgen_rbuf_sot_128;
assign tlpgen_eot_1 =  (^tlpgen_rbuf_eot_128[NW-1:0]) ;
assign tlpgen_eot_2 = !(^tlpgen_rbuf_eot_128[NW-1:0]) & (|tlpgen_rbuf_eot_128[NW-1:0]);   // If 2 EOts, XOR is 0 and OR is 1
assign tlpgen_sot_only = |tlpgen_rbuf_sot_128 & !(|tlpgen_rbuf_eot_128);
assign tlpgen_eot_is_last = (tlpgen_rbuf_eot_128 > tlpgen_rbuf_sot_128);
assign tlpgen_sot_is_last = (tlpgen_rbuf_sot_128 > tlpgen_rbuf_eot_128);
assign tlpgen_sot_eot = (|tlpgen_rbuf_sot_128) & tlpgen_eot_1 & tlpgen_eot_is_last;
assign tlpgen_eot_sot = (|tlpgen_rbuf_sot_128) & tlpgen_eot_1 & tlpgen_sot_is_last;
assign tlpgen_eot_sot_eot = tlpgen_eot_2 & (|tlpgen_rbuf_sot_128);

// single cycle nullified tlps can only occur when xtlh_merge detects parity errors
assign second_badeot = tlpgen_eot_sot_eot & tlpgen_badeot & (tlpgen_rbuf_sot_128 < tlpgen_rbuf_badeot_128);

assign tlpgen_no_badeot = !(|tlpgen_rbuf_badeot_128);
assign tlpgen_badeot = (|tlpgen_rbuf_badeot_128);

assign tlpgen_eot_only = tlpgen_eot_1 & !tlpgen_sot;

assign sotbuf_we   = tlpgen_rbuf_dv & (tlpgen_sot_only | tlpgen_sot_eot & tlpgen_no_badeot | tlpgen_eot_sot | tlpgen_eot_sot_eot);

assign sotbuf_addr              = sotbuf_we ? sotbuf_waddr : sotbuf_raddr;


assign sotbuf_waddr_plus1       = (sotbuf_waddr == retrysotram_xdlh_depth) ? 0 : (sotbuf_waddr + 1);
assign sotbuf_waddr_minus1      = (sotbuf_waddr == {SOTBUF_PW{1'b0}}) ? retrysotram_xdlh_depth: (sotbuf_waddr - 1);


assign schd_ackd_seqnum_plus1   = {1'b0, schd_ackd_seqnum} + 1'b1;
assign sotbuf_raddr             = schd_ackd_seqnum_plus1[SOTBUF_PW-1 :0];


wire [SOTBUF_PW-1 :0] pre_sotbuf_raddr;
wire [12:0] pre_schd_ackd_seqnum_plus1;
reg  [11:0] pre_schd_ackd_seqnum;
wire pre_xdlh_retrysotram_en;

assign pre_sotbuf_raddr = pre_schd_ackd_seqnum_plus1[SOTBUF_PW-1 :0];
assign pre_schd_ackd_seqnum_plus1   = {1'b0, pre_schd_ackd_seqnum} +1'b1;

always @ (*)
begin
    if (!rdlh_link_up) begin
        pre_schd_ackd_seqnum       = 12'hFFF;
    end else if (rdlh_xdlh_rcvd_ack | rdlh_xdlh_rcvd_nack) begin
      if ( !einj5_dup_en ) begin
        pre_schd_ackd_seqnum        = rdlh_xdlh_rcvd_acknack_seqnum ;
      end else begin
        pre_schd_ackd_seqnum = schd_ackd_seqnum;
      end
    end else begin
        pre_schd_ackd_seqnum = schd_ackd_seqnum;
    end
end

logic                            sotbuf_gen_unused_stallout;
logic                            sotbuf_gen_unused_halt_out;
logic                            sotbuf_gen_unused_valid_out;
logic                            sotbuf_gen_unused_ras_dp_err_inband_kbd_out;
ras_dp_err_log_t                 sotbuf_gen_unused_ras_dp_err_log;
logic            [SOTBUF_PW-1:0] sotbuf_gen_unused_dout;

ras_dp_pipe
 #(
    .PIPELINE_TYPE           (6),
    .N_STAGES                (0),
    .CAN_STALL               (0),
    .BUS_PROTECT_GEN_EN      (1),
    .BUS_PROTECT_CHK_EN      (0),
    .PROT_TYPE               (P_RAS_RAM_PROT_TYPE),
    .PROT_RANGE              (P_RAS_RAM_PROT_RANGE),
    .PROT_WD                 (SOTBUF_PROT_WD),
    .PARITY_MODE             (P_PARITY_MODE),
    .TOTAL_WIDTH             (RBUF_PW+SOTBUF_PW),
    .EXCLUDE_PROT_WIDTH      (0),
    .ADDR_ECC_PROT_EN        (1),
    .ADDR_LOG_EN             (1),
    .ADDR_INDEX              (RBUF_PW),
    .ADDR_WD                 (SOTBUF_PW)
) u_xdlh_sotbuf_gen (
    .clk                       (core_clk),
    .rst_n                     (core_rst_n),

    .din                       ({sotbuf_waddr, rbuf_waddr}),
    .din_prot                  ('0),

    .dout                      ({sotbuf_gen_unused_dout, sotbuf_din[RBUF_PW-1:0]}),
    .dout_prot                 (sotbuf_din[SOTBUF_WD-1 : RBUF_PW]),
    
    .en                        (1'b0),
    .bypass                    (1'b0),
    .stall                     (1'b0),
    .stallout                  (sotbuf_gen_unused_stallout),
    
    .valid_in                  ('0),
    .halt_out                  (sotbuf_gen_unused_halt_out),
    
    .valid_out                 (sotbuf_gen_unused_valid_out),
    .halt_in                   (1'b0),
    .ras_dp_err_inband_kbd_in  (1'b0),
    .ras_dp_err_inband_kbd_out (sotbuf_gen_unused_ras_dp_err_inband_kbd_out),
    .ras_dp_err_log            (sotbuf_gen_unused_ras_dp_err_log)
    ,
    .ras_dp_err_inj            ('0)
);

//-----------------------------------------------------
//128b, 256b, 512b block
wire dec_sotbuf_waddr;
wire inc_sotbuf_waddr;
wire   [SOTBUF_PW-1:0] sotbuf_waddr_out;

assign  sotbuf_waddr_out =  sotbuf_waddr;

assign inc_sotbuf_waddr = tlpgen_rbuf_dv & (tlpgen_sot_only | tlpgen_sot_eot & tlpgen_no_badeot | tlpgen_eot_sot | tlpgen_eot_sot_eot & tlpgen_no_badeot);

assign dec_sotbuf_waddr = tlpgen_rbuf_dv & (tlpgen_eot_only & tlpgen_badeot & !tlpgen_sot);


// Need to redesign the retry buf din entry logic, to align TLPs when badeot is detected on incoming TLPs

reg [DW_W_PAR-1:0] tlp_start_data;
reg [NW-1:0] tlp_start_eot;
reg [NW-1:0] tlp_start_sot;
reg [DW-1:0] temp_data;
reg [DW-1:0] temp_data_in;
reg [NW-1:0] int_mem_sot;
reg [NW-1:0] int_mem_eot;
wire [NW-1:0] int_rbuf_sot;
wire [NW-1:0] rbuf_eot_in;

reg [DW_W_PAR-1:0] int_mem_din;


always @(posedge core_clk or negedge core_rst_n)
     if (!core_rst_n) begin
       tlp_start_data <= #TP ALL_ZERO_DATA;
       tlp_start_eot  <= #TP {NW{1'b0}};
       tlp_start_sot  <= #TP {NW{1'b0}};

      end
      else if (rbuf_we & tlpgen_sot)   begin
        tlp_start_data <= #TP tlpgen_rbuf_data;
        tlp_start_sot  <= #TP tlpgen_rbuf_sot_128;
        tlp_start_eot  <= #TP tlpgen_rbuf_eot_128;
      end

reg [ESOT_WD-1:0] rbuf_sot_enc;
wire [ESOT_WD-1:0] rbuf_sot_in;

always @(*)
  begin : PROC_RBUF_SOT_ENC
   integer i;
   rbuf_sot_enc = {ESOT_WD{1'b0}};
   for (i=0; i<NW; i=i+1)
       begin
        if (int_rbuf_sot[i])
          rbuf_sot_enc = i+1;
        end
   end
assign rbuf_sot_in      =    rbuf_sot_enc;

assign rbuf_mem_din     =   int_mem_din[DW-1:0];

assign int_rbuf_sot     =   int_mem_sot;
assign rbuf_eot_in      =    int_mem_eot;


// There will be no case where bad eot id followed by SOT. Simplifies the whole retrybuf re-design
always @(*)
  begin

    int_mem_din = tlpgen_rbuf_data;
    int_mem_sot = tlpgen_rbuf_sot_128;
    int_mem_eot = tlpgen_rbuf_eot_128;
    next_start_addr = 1'b0;
    rbuf_waddr = int_rbuf_waddr;
    load_start_addr = 1'b0;

    if (tlpgen_eot_only & tlpgen_badeot )   // In this case the waddr will be latchd_start_waddr,
                                            // waddr pointer will be updated to latch_start_waddr + 1
    begin
        int_mem_sot =  {NW{1'b0}};          // SOT is cleared.
        int_mem_eot = tlp_start_eot;
        int_mem_din = tlp_start_data;
        rbuf_waddr = latchd_start_waddr;
        next_start_addr = !tlp_start_sot[0]; // If bad TLP started at DW0, don't advance the start address, if TLP started not at DW0,
        load_start_addr = 1'b1;              // The start address is the next address.
    end

   else   if ( second_badeot)                // Here we need to remove the scond TLP in the entry, clear SOT and second EOT
            begin

        int_mem_din = tlpgen_rbuf_data;
        int_mem_sot = {NW{1'b0}};
        int_mem_eot = tlpgen_rbuf_eot_128 & (~tlpgen_rbuf_badeot_128); // Clear EOT when eot[i] == 1 and badeot[i] == 0
            end
   else
   begin
    int_mem_din = tlpgen_rbuf_data;
    int_mem_sot = tlpgen_rbuf_sot_128;
    int_mem_eot = tlpgen_rbuf_eot_128;
    next_start_addr = 1'b0;
    rbuf_waddr = int_rbuf_waddr;
   end

end // always

/*
`ifdef CX_TLP_PREFIX_ENABLE
`ifdef CX_GEN3_SPEED

assign rbuf_din         = {tlpgen_rbuf_len, rbuf_eot_in, rbuf_sot_in,  rbuf_mem_din};
`else  // !CX_GEN3_SPEED
assign rbuf_din         = {rbuf_eot_in, rbuf_sot_in,  rbuf_mem_din};
`endif  // CX_GEN3_SPEED
`else // !CX_TLP_PREFIX_ENABLE
assign rbuf_din         = {rbuf_eot_in, rbuf_sot_in,  rbuf_mem_din};
`endif // CX_TLP_PREFIX_ENABLE
*/

assign rbuf_ctrlbits = {
                         tlpgen_rbuf_len,
                         rbuf_eot_in,
                         rbuf_sot_in };

logic                          rbuf_gen_unused_stallout;
logic                          rbuf_gen_unused_halt_out;
logic                          rbuf_gen_unused_valid_out;
logic                          rbuf_gen_unused_ras_dp_err_inband_kbd_out;
ras_dp_err_log_t               rbuf_gen_unused_ras_dp_err_log;
logic            [RBUF_PW-1:0] rbuf_gen_unused_dout;

ras_dp_pipe
 #(
    .PIPELINE_TYPE           (6),
    .N_STAGES                (0),
    .CAN_STALL               (0),
    .BUS_PROTECT_GEN_EN      (1),
    .BUS_PROTECT_CHK_EN      (0),
    .PROT_TYPE               (P_RAS_RAM_PROT_TYPE),
    .PROT_RANGE              (P_RAS_RAM_PROT_RANGE),
    .PROT_WD                 (RBUF_PROT_WD),
    .PARITY_MODE             (P_PARITY_MODE),
    .TOTAL_WIDTH             (RBUF_CTRL_BITS_WD+DW+RBUF_PW),
    .EXCLUDE_PROT_WIDTH      (0),
    .ADDR_ECC_PROT_EN        (1),
    .ADDR_LOG_EN             (1),
    .ADDR_INDEX              (RBUF_CTRL_BITS_WD+DW),
    .ADDR_WD                 (RBUF_PW)
) u_xdlh_ctrl_par_gen (
    .clk                       (core_clk),
    .rst_n                     (core_rst_n),

    .din                       ({rbuf_waddr, rbuf_ctrlbits, int_mem_din[DW-1:0]} ),
    .din_prot                  ('0),

    .dout                      ({rbuf_gen_unused_dout, rbuf_din[0 +: RBUF_CTRL_BITS_WD+DW]}),
    .dout_prot                 (rbuf_din[RBUF_CTRL_BITS_WD+DW +: RBUF_PROT_WD]),
    
    .en                        (1'b0),
    .bypass                    (1'b0),
    .stall                     (1'b0),
    .stallout                  (rbuf_gen_unused_stallout),
    
    .valid_in                  ('0),
    .halt_out                  (rbuf_gen_unused_halt_out),
    
    .valid_out                 (rbuf_gen_unused_valid_out),
    .halt_in                   (1'b0),
    .ras_dp_err_inband_kbd_in  (1'b0),
    .ras_dp_err_inband_kbd_out (rbuf_gen_unused_ras_dp_err_inband_kbd_out),
    .ras_dp_err_log            (rbuf_gen_unused_ras_dp_err_log)
    ,
    .ras_dp_err_inj            ('0)
);

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        sotbuf_waddr    <= #TP 0;
    end else if(!rdlh_link_up) begin
        sotbuf_waddr    <= #TP 0;
    end else if (dec_sotbuf_waddr) begin
        sotbuf_waddr    <= #TP sotbuf_waddr_minus1;
    end else if (inc_sotbuf_waddr) begin
        sotbuf_waddr    <= #TP sotbuf_waddr_plus1;
    end

//
// Maintain state if an eot is pending so that we can ignore if we receive an unexpected one.
// It can happen for example after a replay when restarting the xtlh datapath, after it was
// interrupted at a point where xtlh was presenting eot_sot.
//
always @(posedge core_clk or negedge core_rst_n) begin : tlpgen_eot_pending_proc
    if(!core_rst_n) begin
        tlpgen_eot_pending <= #TP 1'b0;
    end else begin
        if(tlpgen_rbuf_dv & tlpgen_eot_is_last)
            tlpgen_eot_pending <= #TP 1'b0;
        else if(tlpgen_rbuf_dv & tlpgen_sot_is_last)
            tlpgen_eot_pending <= #TP 1'b1;
    end
end




//end of 128b/256b block
//-----------------------------------------------------
//-----------------------------------------------------

parameter S_ALL_ACKD                     = 2'h0;
parameter S_READ_SOT_ADD                 = 2'h1;
parameter S_WAIT_TO_ALL_ACKD             = 2'h2;

reg     [1:0]                   sot_state;
reg     [1:0]                   next_sot_state;

always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        sot_state       <= #TP S_ALL_ACKD;
    end else begin
        sot_state       <= #TP next_sot_state;
    end
end

reg fsm_sotram_rd_en; // Output of SOTRAM FSM

always @(*) begin : SOTRAM_RD_EN_FSM

   fsm_sotram_rd_en = 1'b0;
   case (sot_state)
        S_ALL_ACKD:        begin
                              if(all_tlp_schd_ackd)
                                 next_sot_state    =  S_ALL_ACKD;
                              else
                                 next_sot_state    =  S_READ_SOT_ADD;
                           end

        S_READ_SOT_ADD:    begin
                              next_sot_state  =  S_WAIT_TO_ALL_ACKD;
                              fsm_sotram_rd_en = 1'b1;
                           end

        // SOTRAM is ram2p and we can read at the same time that write.
        S_WAIT_TO_ALL_ACKD:begin
                              if(all_tlp_schd_ackd)
                                 next_sot_state    =  S_ALL_ACKD;
                              else begin
                                 next_sot_state    =  S_WAIT_TO_ALL_ACKD;
                                 // all_tlp_schd_ackd=(sch_ackd_seqnum==rbuf_last_xmt_seqnum) both are DELAYED(1)[rdlh_xdlh_rcvd_acknack_seqnum] then
                                 // it has to be delayed 1clk the ack/nack signals checking.
                                 if(rdlh_xdlh_rcvd_ack_d | rdlh_xdlh_rcvd_nack_d) // RD again if it's received an ACK/NACK
                                    fsm_sotram_rd_en = 1'b1;
                              end
                           end

            default:    begin
                            next_sot_state  = S_ALL_ACKD;
                        end
   endcase
end

// ##############################################################################################################################
// BEGIN RETRYSOTRAM REGOUT RETRYBUF OUTPUTs
// ##############################################################################################################################

assign xdlh_retrysotram_rd = ( ((state == S_REPLY_REQ) & (!all_tlp_schd_ackd)) | fsm_sotram_rd_en );
assign xdlh_retrysotram_par_chk_val = xdlh_retrysotram_rd_d; // xdlh_retrysotram_rd_d is RD SOTRAM (RETRY_SOT_RAM_RD_REGOUT+RETRY_SOT_RAM_RD_LATENCY) DELAYED
assign sotbuf_en = ( ((state == S_REPLY_REQ) & (!all_tlp_schd_ackd)) | fsm_sotram_rd_en );

wire   [RETRYSOTRAM_REGOUT_WIDTH-1 :0]       xdlh_retrysotram_bus_regin;

assign xdlh_retrysotram_bus_regin = {
                        sotbuf_waddr_out,
                        sotbuf_raddr,
                        sotbuf_din,
                        sotbuf_we,
                        sotbuf_en
                      };

// REGOUT RETRYSOTRAM memory OUTPUT signals
reg [RETRYSOTRAM_REGOUT_WIDTH-1 :0] xdlh_retrysotram_bus;
reg xdlh_retrysotram_rd_ctrl;
reg latch_retry_start_addr_ctrl;
generate if (RETRYSOTRAM_REG_RETRYBUF_OUTPUTS > 0)begin : sotretrybuf
    reg    [RETRYSOTRAM_REGOUT_WIDTH-1 :0]        xdlh_retrysotram_bus_regout[RETRYSOTRAM_REG_RETRYBUF_OUTPUTS-1:0];
    reg [RETRYSOTRAM_REG_RETRYBUF_OUTPUTS-1:0]    xdlh_retrysotram_rd_reg;
    reg [RETRYSOTRAM_REG_RETRYBUF_OUTPUTS-1:0]    latch_retry_start_addr_reg;

    always @(posedge core_clk or negedge core_rst_n)begin
        if(!core_rst_n)begin
            xdlh_retrysotram_bus_regout[0] <= #TP 0;
            xdlh_retrysotram_rd_reg[0]     <= #TP 0;
            latch_retry_start_addr_reg[0] <= #TP 0;
        end else begin
            xdlh_retrysotram_bus_regout[0] <= #TP xdlh_retrysotram_bus_regin;
            xdlh_retrysotram_rd_reg[0]     <= #TP xdlh_retrysotram_rd;
            latch_retry_start_addr_reg[0] <= #TP latch_retry_start_addr;
        end
    end

    for(i = 1; i < RETRYSOTRAM_REG_RETRYBUF_OUTPUTS; i++)begin
        always @(posedge core_clk or negedge core_rst_n)begin
            if(!core_rst_n)begin
                xdlh_retrysotram_bus_regout[i] <= #TP 0;
                xdlh_retrysotram_rd_reg[i]     <= #TP 0;
                latch_retry_start_addr_reg[i] <= #TP 0;
            end else begin
                xdlh_retrysotram_bus_regout[i] <= #TP xdlh_retrysotram_bus_regout[i-1];
                xdlh_retrysotram_rd_reg[i]     <= #TP xdlh_retrysotram_rd_reg[i-1];
                latch_retry_start_addr_reg[i] <= #TP latch_retry_start_addr_reg[i-1];
            end
        end
    end
    
    assign xdlh_retrysotram_bus = xdlh_retrysotram_bus_regout[RETRYSOTRAM_REG_RETRYBUF_OUTPUTS-1];
    assign xdlh_retrysotram_rd_ctrl      = xdlh_retrysotram_rd_reg[RETRYSOTRAM_REG_RETRYBUF_OUTPUTS-1];
    assign latch_retry_start_addr_ctrl   = latch_retry_start_addr_reg[RETRYSOTRAM_REG_RETRYBUF_OUTPUTS-1];
end else begin  : sotretrybuf // if (RETRYSOTRAM_REG_RETRYBUF_OUTPUTS > 0)
    assign xdlh_retrysotram_bus          = xdlh_retrysotram_bus_regin;
    assign xdlh_retrysotram_rd_ctrl      = xdlh_retrysotram_rd;
    assign latch_retry_start_addr_ctrl   = latch_retry_start_addr;
end

endgenerate


assign {
                        xdlh_retrysotram_waddr,           // Write Adrress to retry buffer RAM
                        xdlh_retrysotram_raddr,           // Read Adrress to retry buffer RAM
                        xdlh_retrysotram_data,            // Write data to retry buffer RAM
                        xdlh_retrysotram_we,              // Write enable to retry buffer RAM
                        xdlh_retrysotram_en              // Read enable to retry buffer RAM
        } = xdlh_retrysotram_bus;

       assign xdlh_retrysotram_rd_regout    = xdlh_retrysotram_rd_ctrl;
       assign latch_retry_start_addr_regout = latch_retry_start_addr_ctrl;
// ##############################################################################################################################
// END RETRYSOTRAM REGOUT RETRYBUF OUTPUTs
// ##############################################################################################################################


reg     [SOTBUF_WD-1:0]   retrysotram_xdlh_data_dd;
reg                       retrysotram_xdlh_parerr_dd;
reg                       rbuf_reply_done_dd;

wire [RBUF_PW-1:0] ras_sotram_protect_dout;
reg  [RBUF_PW-1:0] ras_sotram_protect_dout_latchd;
reg ras_sotram_protect_parerr;
reg ras_sotram_protect_parerr_latchd;
always @(posedge core_clk or negedge core_rst_n)
  begin
    if (!core_rst_n) begin
      ras_sotram_protect_dout_latchd   <= #TP 1'b0;
      ras_sotram_protect_parerr_latchd <= #TP 1'b0;
    end else if(xdlh_retrysotram_rd_dd) begin
      ras_sotram_protect_dout_latchd   <= #TP ras_sotram_protect_dout[RBUF_PW-1:0];
      ras_sotram_protect_parerr_latchd <= #TP ras_sotram_protect_parerr;
  end
  end

assign sotbuf_dout   = xdlh_retrysotram_rd_dd ? ras_sotram_protect_dout[RBUF_PW-1:0] : ras_sotram_protect_dout_latchd;
assign sotbuf_parerr = xdlh_retrysotram_rd_dd ? ras_sotram_protect_parerr            : ras_sotram_protect_parerr_latchd;

assign pre_xdlh_retrysotram_en =  ((state == S_SET_REPLY_REQ) && reply_req && tlpgen_reply_grant )|| (next_sot_state  ==  S_READ_SOT_ADD );

// ###############################################################################################
//
// Data signals are delayed N cycles RAM Latency + 1 cycle RAM REGOUT(Register output of the RAM)
// signal_name       = DELAYED(0)
// signal_name_d     = DELAYED(LATENCY)
// signal_name_dd_m1 = DELAYED(LATENCY+REGOUT-1)
// signal_name_dd    = DELAYED(LATENCY+REGOUT)
//
// ###############################################################################################

// ##############################################################################################################################
// ### TO REGISTER RETRYRAM DATA SIGNALS 1 REGOUT AND STORE in FIFO if dlyd_int_halt ###
// ##############################################################################################################################

wire   [DFIFO_WIDTH-1 :0]       pipe_in_data;
wire   [DFIFO_WIDTH-1 :0]       pipe_out_data;
wire                            uncon_pipe_halt_out;
wire                            uncon_pipe_pipe_out_data_valid;

assign pipe_in_data = {
                          int_xdlh_retryram_err_addr,
                        // Data from RETRYRAM memory
                          retryram_xdlh_data,
                          retryram_xdlh_parerr,
                          xdlh_retryram_rd_d
                      };

ram_latency_pipe
 #(
       .PIPE_WIDTH(DFIFO_WIDTH),
       .PIPE_INPUT_REG(RETRYRAM_REG_RETRYBUF_INPUTS),
       .PIPE_LATENCY(RETRY_RAM_RD_LATENCY+RETRYRAM_REG_RETRYBUF_OUTPUTS)
      )
u1_retry_pipe(
// ------ Inputs ------
    .core_clk              (core_clk),
    .core_rst_n            (core_rst_n),
    .halt_in               (dlyd_int_halt),
    .pipe_in_data_valid    (!dlyd_int_halt & (xdlh_retryram_en & !xdlh_retryram_we)),
    .pipe_in_data          (pipe_in_data),

// ------ Outputs ------
    .halt_out              (uncon_pipe_halt_out),
    .pipe_out_data_valid   (uncon_pipe_pipe_out_data_valid),
    .pipe_out_data         (pipe_out_data)
);

assign {
                        retryram_datactrl_protect_checker_addr,
                        // Data REGOUT from RETRYRAM memory
                        retryram_xdlh_data_dd,
                        retryram_xdlh_parerr_dd,
                        xdlh_retryram_par_chk_val_dd
        } = pipe_out_data;

// ##############################################################################################################################
// pipe  => To register the data output of the RETRYRAM and store it in case dlyd_int_halt is set
// pipe2 => to align xdlh_retryram_rd_regout signal with the RAM latency of the incoming data => To generate xdlh_retryram_rd_d
// pipe3 => To register the data output of the SOTRAM
// pipe4 => To align xdlh_retrysotram_rd_regout signal with the  RAM latency of the incoming data => To generate xdlh_retrysotram_par_chk_val = xdlh_retrysotram_rd_d
// ##############################################################################################################################

wire   [PIPE2_WIDTH-1 :0]       pipe2_in_retry_ctrl;
reg    [PIPE2_WIDTH-1 :0]       pipe2_out_retry_ctrl[RETRY_RAM_RD_LATENCY-1:0];
wire   [PIPE3_WIDTH-1 :0]       pipe3_in_sot_data;
reg    [PIPE3_WIDTH-1 :0]       pipe3_out_sot_data[RETRYSOTRAM_REG_RETRYBUF_INPUTS-1:0];
wire   [PIPE4_WIDTH-1 :0]       pipe4_in_sot_ctrl;
reg    [PIPE4_WIDTH-1 :0]       pipe4_out_sot_ctrl[RETRY_SOT_RAM_RD_LATENCY-1:0];

// ### TO ALIGN RETRYRAM CTRL SIGNALS N LATENCY ###
assign pipe2_in_retry_ctrl = {
                        // Retry CTRL signals
                        xdlh_retryram_rd_regout
                      };

// ### TO REGISTER SOTRAM DATA SIGNALS 1 REGOUT ###
// They are not affected for the halt because they will be latched
assign pipe3_in_sot_data = {
                        // Data from SOTRAM memory
                        retrysotram_xdlh_data,
                        retrysotram_xdlh_parerr
                      };

// ### TO ALIGN SOTRAM CTRL SIGNALS N LATENCY ###
assign pipe4_in_sot_ctrl = {
                        // SOTRAM CTRL signals
                        xdlh_retrysotram_rd_regout,
                        latch_retry_start_addr_regout
                      };

always @(posedge core_clk or negedge core_rst_n)
  begin
    integer i;

    if (!core_rst_n) begin
       for(i = 0; i < RETRY_RAM_RD_LATENCY; i = i + 1)
          pipe2_out_retry_ctrl[i] <= #TP 0;
    end else begin
       for(i = 0; i < RETRY_RAM_RD_LATENCY; i = i + 1) begin
         if(i==0)
            pipe2_out_retry_ctrl[i] <= #TP pipe2_in_retry_ctrl;
         else
            pipe2_out_retry_ctrl[i] <= #TP pipe2_out_retry_ctrl[i-1];
       end // for
    end
  end

always @(posedge core_clk or negedge core_rst_n)
  begin
    integer i;

    if (!core_rst_n) begin
       for(i = 0; i < RETRYSOTRAM_REG_RETRYBUF_INPUTS; i = i + 1)
          pipe3_out_sot_data[i] <= #TP 0;
    end else begin
       for(i = 0; i < RETRYSOTRAM_REG_RETRYBUF_INPUTS; i = i + 1) begin
         if(i==0)
            pipe3_out_sot_data[i] <= #TP pipe3_in_sot_data;
         else
            pipe3_out_sot_data[i] <= #TP pipe3_out_sot_data[i-1];
       end // for
    end
  end

always @(posedge core_clk or negedge core_rst_n)
  begin
    integer i;

    if (!core_rst_n) begin
       for(i = 0; i < RETRY_SOT_RAM_RD_LATENCY; i = i + 1)
          pipe4_out_sot_ctrl[i] <= #TP 0;
    end else begin
       for(i = 0; i < RETRY_SOT_RAM_RD_LATENCY; i = i + 1) begin
         if(i==0)
            pipe4_out_sot_ctrl[i] <= #TP pipe4_in_sot_ctrl;
      else
            pipe4_out_sot_ctrl[i] <= #TP pipe4_out_sot_ctrl[i-1];
       end // for
    end
  end

assign {
                        // Retry CTRL signals
                        xdlh_retryram_rd_d
        } = pipe2_out_retry_ctrl[RETRY_RAM_RD_LATENCY-1];

assign {
                        // Data from SOTRAM memory
                        retrysotram_xdlh_data_dd,
                        retrysotram_xdlh_parerr_dd
        } = pipe3_out_sot_data[RETRYSOTRAM_REG_RETRYBUF_INPUTS-1];

assign {
                        // SOTRAM CTRL signals
                        xdlh_retrysotram_rd_d,
                        latch_retry_start_addr_d
        } = pipe4_out_sot_ctrl[RETRY_SOT_RAM_RD_LATENCY-1];

// ### TO ALIGN CTRL SIGNALS N REGOUT ###
// In pipe4_in_sot_ctrl latch_retry_start_addr_d = DELAY(RETRY_SOT_RAM_RD_LATENCY)[latch_retry_start_addr]
// latch_retry_start_addr_dd = DELAY(RETRYSOTRAM_REG_RETRYBUF_INPUTS)[latch_retry_start_addr_d] = DELAY(RETRY_SOT_RAM_RD_LATENCY+RETRYSOTRAM_REG_RETRYBUF_INPUTS)[latch_retry_start_addr] because
// RAM is regout and Latency clk because latency
reg [RETRYSOTRAM_REG_RETRYBUF_INPUTS-1:0] xdlh_retrysotram_rd_d_nregout;
reg [RETRYSOTRAM_REG_RETRYBUF_INPUTS-1:0] latch_retry_start_addr_d_nregout;
always @(posedge core_clk or negedge core_rst_n)
  begin
    integer i;

    if (!core_rst_n) begin
      xdlh_retrysotram_rd_d_nregout     <= #TP 0;
      latch_retry_start_addr_d_nregout  <= #TP 0;
    end else begin
      for(i = 0; i < RETRYSOTRAM_REG_RETRYBUF_INPUTS; i = i + 1) begin
         if(i==0) begin
            xdlh_retrysotram_rd_d_nregout[i]     <= #TP xdlh_retrysotram_rd_d;
            latch_retry_start_addr_d_nregout[i]  <= #TP latch_retry_start_addr_d;
         end else begin
            xdlh_retrysotram_rd_d_nregout[i]     <= #TP xdlh_retrysotram_rd_d_nregout[i-1];
            latch_retry_start_addr_d_nregout[i]  <= #TP latch_retry_start_addr_d_nregout[i-1];
         end
      end // for
    end
  end

assign xdlh_retrysotram_rd_dd    = xdlh_retrysotram_rd_d_nregout[RETRYSOTRAM_REG_RETRYBUF_INPUTS-1];
assign latch_retry_start_addr_dd = latch_retry_start_addr_d_nregout[RETRYSOTRAM_REG_RETRYBUF_INPUTS-1];

// To generate xdlh_retryram_rd_dd_m1 signal the core needs to take into account dlyd_int_halt as the ram_latency_pipe does to maintain the alignement
// To generate par_chk_val it is not needed dlyd_int_halt because the RAM it is not affected for the halt.
reg [RETRYRAM_REG_RETRYBUF_OUTPUTS+RETRY_RAM_RD_LATENCY+RETRYRAM_REG_RETRYBUF_INPUTS-1:0] xdlh_retryram_rd_dlyd_pipe;
always @(posedge core_clk or negedge core_rst_n)
  begin
    integer i;

    if (!core_rst_n) begin
         xdlh_retryram_rd_dlyd_pipe <= #TP 0;
    end else begin
      if(!dlyd_int_halt) begin
        for(i = 0; i < RETRYRAM_REG_RETRYBUF_OUTPUTS+RETRY_RAM_RD_LATENCY+RETRYRAM_REG_RETRYBUF_INPUTS; i = i + 1) begin
         if(i==0) begin
            xdlh_retryram_rd_dlyd_pipe[i]  <= #TP xdlh_retryram_rd;
         end else begin
            xdlh_retryram_rd_dlyd_pipe[i]  <= #TP xdlh_retryram_rd_dlyd_pipe[i-1];
         end
        end // for
      end //if(!dlyd_...
    end
  end

assign rbuf_reply_done_dd = !xdlh_retryram_rd_dlyd_pipe[RETRYRAM_REG_RETRYBUF_OUTPUTS+RETRY_RAM_RD_LATENCY+RETRYRAM_REG_RETRYBUF_INPUTS-2];

reg xdlh_retryram_rd_dd_m1_int;
generate if (RETRYRAM_REG_RETRYBUF_OUTPUTS+RETRY_RAM_RD_LATENCY+RETRYRAM_REG_RETRYBUF_INPUTS > 1)
    begin : retrybufall
       assign xdlh_retryram_rd_dd_m1_int = xdlh_retryram_rd_dlyd_pipe[RETRYRAM_REG_RETRYBUF_OUTPUTS+RETRY_RAM_RD_LATENCY+RETRYRAM_REG_RETRYBUF_INPUTS-2];
    end else begin : retrybufall
       assign xdlh_retryram_rd_dd_m1_int = xdlh_retryram_rd;
end
endgenerate
assign xdlh_retryram_rd_dd_m1 = xdlh_retryram_rd_dd_m1_int;

reg xdlh_retrysotram_par_chk_val_dd;
reg [RETRYSOTRAM_REG_RETRYBUF_INPUTS-1:0] xdlh_retrysotram_par_chk_val_nregout;
always @(posedge core_clk or negedge core_rst_n)
  begin
    integer i;

    if (!core_rst_n) begin
       xdlh_retrysotram_par_chk_val_nregout <= #TP 0;
    end else begin
      for(i = 0; i < RETRYSOTRAM_REG_RETRYBUF_INPUTS; i = i + 1) begin
         if(i==0) begin
            xdlh_retrysotram_par_chk_val_nregout[i]     <= #TP xdlh_retrysotram_par_chk_val; // = xdlh_retrysotram_rd_d = DELAYED(LATENCY)[xdlh_retrysotram_rd]
         end else begin
            xdlh_retrysotram_par_chk_val_nregout[i]     <= #TP xdlh_retrysotram_par_chk_val_nregout[i-1];
         end
      end // for
    end
  end

assign xdlh_retrysotram_par_chk_val_dd = xdlh_retrysotram_par_chk_val_nregout[RETRYSOTRAM_REG_RETRYBUF_INPUTS-1];

// To report the right address when there is a failure
reg [SOTBUF_PW -1:0] xdlh_retrysotram_raddr_dd[RETRY_SOT_RAM_RD_LATENCY+RETRYSOTRAM_REG_RETRYBUF_INPUTS-1:0];
always @(posedge core_clk or negedge core_rst_n)
begin
    integer i;

if (!core_rst_n) begin
       for(i = 0; i < RETRY_SOT_RAM_RD_LATENCY+RETRYSOTRAM_REG_RETRYBUF_INPUTS; i = i + 1)
          xdlh_retrysotram_raddr_dd[i] <= #TP 0;
end else begin
       for(i = 0; i < RETRY_SOT_RAM_RD_LATENCY+RETRYSOTRAM_REG_RETRYBUF_INPUTS; i = i + 1) begin
         if(i==0)
            xdlh_retrysotram_raddr_dd[i] <= #TP xdlh_retrysotram_raddr;
         else
            xdlh_retrysotram_raddr_dd[i] <= #TP xdlh_retrysotram_raddr_dd[i-1];
       end // for
end
end

assign int_xdlh_retrysotram_err_addr = xdlh_retrysotram_raddr_dd[RETRY_SOT_RAM_RD_LATENCY+RETRYSOTRAM_REG_RETRYBUF_INPUTS-1]; // xdlh_retrysotram_raddr delayed N Latency + 1 reg
logic                      sotbuf_chk_unused_stallout;
logic                      sotbuf_chk_unused_halt_out;
logic                      sotbuf_chk_unused_valid_out;
logic [SOTBUF_PW-1:0]      sotbuf_chk_unused_dout;
logic [SOTBUF_PROT_WD-1:0] sotbuf_chk_unused_dout_prot;

logic                      sotbuf_chk_ras_dp_err_inband_kbd_out;
ras_dp_pipe
 #(
    .PIPELINE_TYPE           (6),
    .N_STAGES                (0),
    .CAN_STALL               (0),
    .BUS_PROTECT_GEN_EN      (0),
    .BUS_PROTECT_CHK_EN      (1),
    .PROT_TYPE               (P_RAS_RAM_PROT_TYPE),
    .PROT_RANGE              (P_RAS_RAM_PROT_RANGE),
    .PROT_WD                 (SOTBUF_PROT_WD),
    .PARITY_MODE             (P_PARITY_MODE),
    .PROT_CORRECT_EN         (1),
    .TOTAL_WIDTH             (RBUF_PW+SOTBUF_PW),
    .EXCLUDE_PROT_WIDTH      (0),
    .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE_XDLH_RETRY_BUF + 0),
    .ADDR_ECC_PROT_EN        (1),
    .ADDR_LOG_EN             (1),
    .ADDR_INDEX              (RBUF_PW),
    .ADDR_WD                 (SOTBUF_PW)
) u_retrysotram_xdlh_data_d_chk (
    .clk                       (core_clk),
    .rst_n                     (core_rst_n),

    .din                       ({int_xdlh_retrysotram_err_addr, retrysotram_xdlh_data_dd [RBUF_PW-1:0]}),
    .din_prot                  (retrysotram_xdlh_data_dd [SOTBUF_WD-1:RBUF_PW]),

    .dout                      ({sotbuf_chk_unused_dout, ras_sotram_protect_dout[RBUF_PW-1:0]}),
    .dout_prot                 (sotbuf_chk_unused_dout_prot),
    
    .en                        (1'b0),
    .bypass                    (1'b0),
    .stall                     (1'b0),
    .stallout                  (sotbuf_chk_unused_stallout),

    .valid_in                  (xdlh_retrysotram_par_chk_val_dd),
    .halt_out                  (sotbuf_chk_unused_halt_out),

    .valid_out                 (sotbuf_chk_unused_valid_out),
    .halt_in                   (1'b0),
    .ras_dp_err_inband_kbd_in  (1'b0),
    .ras_dp_err_inband_kbd_out (sotbuf_chk_ras_dp_err_inband_kbd_out),
    .ras_dp_err_log            (ras_dp_err_log[0])
    ,
    .ras_dp_err_inj            (ras_dp_err_inj)
);

// Now it is not continuous the RD of SOTRAM => it is needed to latch the last value
reg  ras_sotram_err_multpl_latchd;
always @(posedge core_clk or negedge core_rst_n) begin : ERR_LATCH
  if (!core_rst_n) begin
    ras_sotram_err_multpl_latchd <= #TP 1'b0;
  end else begin
    if(xdlh_retrysotram_par_chk_val_dd) begin
      ras_sotram_err_multpl_latchd <= #TP sotbuf_chk_ras_dp_err_inband_kbd_out;
    end
  end
end

assign err_multpl_sotbuf = xdlh_retrysotram_par_chk_val_dd ? sotbuf_chk_ras_dp_err_inband_kbd_out : ras_sotram_err_multpl_latchd;

assign ras_sotram_protect_parerr = retrysotram_xdlh_parerr_dd | (err_multpl_sotbuf && xdlh_retrysotram_par_chk_val_dd) ;



// Logic beneath is designed to handle all the sequence related vectors
wire duplicate_ack;
assign duplicate_ack       =  (rdlh_xdlh_rcvd_acknack_seqnum == schd_ackd_seqnum);

assign ackd_seqnum_plus1 = {1'b0, ackd_seqnum} + 1'b1;

//-----------------------------------------------------

// Capture on good eot only, so that we don't need to decrement on bad eot.
// The eot_sot case is treated as a special case: when restarting the xtlh datapath
// (after replay for example) do not capture if there is an eot that preceeds the sot.
assign capture_seqnum = tlpgen_rbuf_dv & tlpgen_eot & tlpgen_no_badeot & !(tlpgen_eot_sot & !tlpgen_eot_pending);

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        rbuf_last_xmt_seqnum    <= #TP 12'hFFF;
    end else if(!rdlh_link_up) begin
        rbuf_last_xmt_seqnum    <= #TP 12'hFFF;
    end else if (capture_seqnum) begin
        // Capture the sequence number as packets are transmitted
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: This logic is designed to be modulo. Sequence counters are intended to
// wrap without preseveration of carry/borrow
        rbuf_last_xmt_seqnum    <= #TP tlpgen_rbuf_seqnum + tlpgen_eot_sot_eot; // when there is a second good eot must latch the value + 1
// spyglass enable_block W164a
    end
//-----------------------------------------------------
//32b 64b block
//-----------------------------------------------------

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        schd_ackd_seqnum        <= #TP 12'hFFF;
    end else if (!rdlh_link_up) begin
        schd_ackd_seqnum        <= #TP 12'hFFF;
    end else if (rdlh_xdlh_rcvd_ack | rdlh_xdlh_rcvd_nack) begin
      if ( !einj5_dup_en )
        schd_ackd_seqnum        <= #TP  rdlh_xdlh_rcvd_acknack_seqnum;
    end

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        seqnum_upd_by_ack           <= #TP 1'b0;
        seqnum_upd_by_nak           <= #TP 1'b0;
        rdlh_xdlh_rcvd_nack_d       <= #TP 1'b0;
        rdlh_xdlh_rcvd_ack_d        <= #TP 1'b0;
    end else begin
        seqnum_upd_by_nak           <= #TP rdlh_xdlh_rcvd_nack & !duplicate_ack;
        seqnum_upd_by_ack           <= #TP rdlh_xdlh_rcvd_ack & !duplicate_ack;
        rdlh_xdlh_rcvd_nack_d       <= #TP rdlh_xdlh_rcvd_nack;
        rdlh_xdlh_rcvd_ack_d        <= #TP rdlh_xdlh_rcvd_ack;
    end
assign seqnum_upd           = seqnum_upd_by_ack | seqnum_upd_by_nak;
assign all_tlp_schd_ackd    = rbuf_last_xmt_seqnum == schd_ackd_seqnum;

// arbitration control process to control the retry and replay verse
// regular transmission

//32b block
assign reply_req = (retry_requested | b_xdlh_replay.replay_req) & !all_tlp_schd_ackd;

// ensure that we never consider a replay complete before it begins, always do
// at least one read, on the first cycle in the S_WAIT_N_LATENCY_RETRYRAM
// state
reg kickstart_reply;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        kickstart_reply <= #TP 1'b0;
    end else begin
        kickstart_reply <= #TP (state == S_WAIT_N_LATENCY_SOTRAM) && latch_retry_start_addr_dd;
    end
// we will terminate a reply by 3 conditions met:
// 1. When we have finished replay of all the tlp in retry buffer
// 2. When we have received an ack dllp that has acked all tlp in retry
// buffer
// 3. a parity error has happened during the replay.
assign rbuf_reply_done      = (rbuf_raddr == rbuf_waddr) && !last_retryram_action_was_we && !kickstart_reply;
// two conditions that cause a reply abort. One is all TLP acked and another one is the retryram_xdlh_parerr, the OR here is for instantant termination in the case of parerr asserted at the same cycle of eot.
// assign rbuf_reply_abort     = all_tlp_schd_ackd | rbuf_parerr | sotbuf_parerr;
assign rbuf_reply_abort     = all_tlp_schd_ackd;

// when replay start, the state machine leaves the idle state. The
// important thing to do at this cycle is to take a snap shot of currnt
// next acked address pointer as well as acked sequence number to start the
// replay at the right location. Due to the new ack/nack request could be
// asserted from rdlh asynchronious, there could be a boundary condition
// that the next acked address pointer is updated later than the acked
// sequence number. In order to make sure that we do not get out of synch,
// we need to block transition from idle state and delay the snapshot
// cycle.

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        state       <= #TP S_IDLE;
    end else begin
// spyglass disable_block STARC05-2.11.3.1
// SMD: Combinational and sequential parts of an FSM described in same always block
// SJ: Legacy code
        case (state)
        S_IDLE:
            if (reply_req)
               state       <= #TP S_PRE_REQ;
            else
               state       <= #TP S_IDLE;
        S_PRE_REQ:
            if (reply_req) begin
            if (!sotbuf_we)
                  state       <= #TP S_SET_REPLY_REQ;
               else
                  state       <= #TP S_PRE_REQ;
            end else
               state       <= #TP S_IDLE;

        S_SET_REPLY_REQ:
            if (reply_req) begin
              if (tlpgen_reply_grant)
               state       <= #TP S_REPLY_REQ;
            else
                  state       <= #TP S_SET_REPLY_REQ;
            end else
               state       <= #TP S_IDLE;

      //S_SOTRAM_RD
        S_REPLY_REQ: // xdlh_retrysotram_en = ((state == S_REPLY_REQ) & (!all_tlp_schd_ackd)) | sotbuf_we | fsm_sotram_rd_en ;
            // if there is a ECC error when reading from the SOT buffer we can't trust the start address
            // so the replay does not start. And never start a replay if core is in RASDP error mode
           if (sotbuf_parerr | cfg_rasdp_error_mode)
              state       <= #TP S_IDLE;
           else if (!seqnum_upd & !rbuf_reply_abort & !link_retrain_pending) begin
              // latch_retry_start_addr = !seqnum_upd & ((state == S_REPLY_REQ) & reply_grant & !rbuf_reply_abort) & !link_retrain_pending
              state                                <= #TP S_WAIT_N_LATENCY_SOTRAM;
           end else if (rbuf_reply_abort)
              state       <= #TP S_IDLE;
            else
              state       <= #TP S_REPLY_REQ;

        S_WAIT_N_LATENCY_SOTRAM:
            if (latch_retry_start_addr_dd)
              state       <= #TP S_WAIT_N_LATENCY_RETRYRAM;
            else
              state       <= #TP S_WAIT_N_LATENCY_SOTRAM;

        S_WAIT_N_LATENCY_RETRYRAM: begin
            if (xdlh_retryram_rd_dd_m1)
               state   <= #TP  S_IN_REPLY;
            else
              state       <= #TP S_WAIT_N_LATENCY_RETRYRAM;
        end

        S_IN_REPLY:
            // reply stop conditions:
            // 1. when read pointer reaches write pointer
            // 2. When all tlp have been ascked, we can abort to save some
            // bandwidth
            // Depending upon the halt condition, we need to make sure that
            // all tlps in the pipe will be transmitted to tlp gen block
            // Done state is designed to allow a cycle for the pipe to be
            // cleared up.

            if ((rbuf_reply_done_dd | rbuf_reply_abort | cfg_rasdp_error_mode ) & (|int_eot_128) & !dlyd_int_halt)
               state       <= #TP S_WAIT_LATENCY;
            else
               state       <= #TP S_IN_REPLY;

        S_WAIT_LATENCY:
            // if (!int_halt & !dlyd_int_halt) => rbuf_xmt_dv <= #TP int_dv; else if(!int_halt & dlyd_int_halt) => rbuf_xmt_dv <= #TP latchd_int_dv
            if (!rbuf_xmt_dv)
               state   <= #TP S_DONE_PIPE;
    else
               state       <= #TP S_WAIT_LATENCY;

        S_DONE_PIPE:
            //in xdlh_tlp_gen_32b int_halt = xdctrl_tlp_halt & tlp_dv; then rbuf_halt=0 always but just in case..To set rbuf_xmt_done=1 1cycle without rbuf_hat=1
            if (!rbuf_halt)
              state       <= #TP S_IDLE;
            else
               state   <= #TP S_DONE_PIPE;

        default:
               state  <= #TP S_IDLE;
        endcase
// spyglass enable_block STARC05-2.11.3.1
    end//if else

// start block a new tlp from entering the retry buffer after a reply has been started
// until a forward progress of ack has been made
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        rbuf_block_new_tlp           <= #TP 1'b0;
    else if  (rdlh_xdlh_rcvd_ack_d | seqnum_upd_by_nak | all_tlp_schd_ackd | state == S_IDLE)  // when a new ack received, we should be able to make assumption that new TLP can be progressed regardless of the seqnum progressing

        rbuf_block_new_tlp           <= #TP 1'b0;
    else if (state == S_WAIT_N_LATENCY_RETRYRAM | state == S_PRE_REQ)
        rbuf_block_new_tlp           <= #TP 1'b1;

//-----------------------------------------------------
// State outputs
assign rbuf_xmt_done = (state == S_IDLE) || (state == S_DONE_PIPE);

// This signal controls when to take a snap shot at the address that we need to start reply with
assign latch_retry_start_addr = !seqnum_upd & (state == S_REPLY_REQ) & !rbuf_reply_abort & !link_retrain_pending // !link_retrain_pending to do 1 pulse only
// if there is a protection error from SOT buffer RAM do not latch the replay address since it can't be trusted
// also prevent new start addresses from being loaded if the core is in RASDP error mode
 & (!(sotbuf_parerr | cfg_rasdp_error_mode))
;

// FSM is in the replay request state
assign xdlh_in_reply = (state != S_IDLE);

// ------------------------------------------------------------------------
// Logic beneath is designed for retry and replay functions.
// Here retry means when nack received, reply means the missing ack/nack
// for a period of time and replay timer expired
//
// retry control
// last xmt seqnum represents the transmitted highest seqnumber. It is used
// in receiver to detect whether or not a ACK/NACK DLLP contains the
// correct sequence number
// In order to identify the last transmitted highest sequence number, we
// need to make sure that this seq number is not updated by the replay or retry sequence
// number

// when rcvd seqnum wrap around 4096, then the delta between received
// seqnum and ackd_seqnum has to be greater than 2048 in order to identify
// a higher sequnce number recieved
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        retry_requested <= #TP 1'b0;
    end else begin

    // according to spec, a NAK can be ignored if a ACK received
    // afterwards with higher sequence number
    // A special function implemented here to ignore a nack that has same
    // seqnum as we transmitted
    // Note: when all tlp acked, if state has not entered into the reply,
    // the reply request will be deasserted, therefore we need to clear
    // all the requests for retry or reply.
        retry_requested <= #TP  (rdlh_xdlh_rcvd_nack_d & !all_tlp_schd_ackd) ? 1'b1
                            : ((state == S_REPLY_REQ) | all_tlp_schd_ackd | seqnum_upd_by_ack)
                                ? 1'b0 : retry_requested;
   end

// The following logic implements the replay timer
// 1. start at the eot of any TLP transmission
// 2. restart and reset the timer on each reply. Restart on the reply eot
// 3. ack received with forward progress, reset the replay timer
// 4. When replay timer expired or NACK received during non replay state, reset and hold the timer until reply with EOT
// 5. hold replay timer when LTSSM is in training
// 6. resets and hold when there is no outstanding unACKed TLPs
//
wire replay_timer_restart;

reg  cfg_rasdp_error_mode_1d;
// falling edge detection on cfg_rasdp_error_mode
wire cfg_rasdp_error_mode_fe;

always @(posedge core_clk or negedge core_rst_n)
begin: cfg_rasdp_error_mode_1d_PROC
  if (!core_rst_n)
    cfg_rasdp_error_mode_1d <= #TP 1'b0;
  else
    cfg_rasdp_error_mode_1d <= #TP cfg_rasdp_error_mode;
end

assign cfg_rasdp_error_mode_fe = (!cfg_rasdp_error_mode) & cfg_rasdp_error_mode_1d;


assign replay_timer_restart = !all_tlp_schd_ackd & (seqnum_upd_by_ack
                                                    | cfg_rasdp_error_mode_fe
                                                   ) ;

assign b_xdlh_replay.replay_timer_start = replay_timer_restart | (((b_xdlh_replay.replay_timer == 17'b0) | b_xdlh_replay.replay_timer_reset) & ((tlpgen_rbuf_dv & tlpgen_eot & (state == S_IDLE))
                                                       | ((state != S_IDLE) & |rbuf_xmt_eot_128 & !rbuf_halt)));

assign b_xdlh_replay.replay_timer_hold  = replay_timer_hold | b_xdlh_replay.replay_req;  // NACK will cause a replay request

assign b_xdlh_replay.replay_timer_reset = (reply_req & (state == S_IDLE)) | seqnum_upd_by_ack | all_tlp_schd_ackd | !rdlh_link_up;

assign b_xdlh_replay.replay_ack = ((state == S_REPLY_REQ) | all_tlp_schd_ackd);

// Replay Num Interface Drivers
assign b_xdlh_replay_num.replay_num_incr = (state == S_IDLE) & reply_req;
assign b_xdlh_replay_num.replay_num_reset = seqnum_upd;
assign b_xdlh_replay_num.replay_num_retrain_ack = smlh_link_in_training_fall;
// Request to retrain the link
assign link_retrain_pending = b_xdlh_replay_num.replay_num_retrain_req;

always @ (posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        xdlh_smlh_start_link_retrain    <= #TP 1'b0;
    else
        xdlh_smlh_start_link_retrain    <= #TP (b_xdlh_replay_num.replay_num == 2'b11) & (state == S_IDLE) & reply_req & !seqnum_upd ;

always @ (posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        smlh_link_in_training_d    <= #TP 1'b0;
    else
        smlh_link_in_training_d    <= #TP smlh_link_in_training;

assign smlh_link_in_training_fall = smlh_link_in_training_d & !smlh_link_in_training;


// misc error monitor
//wire        sotbuf_overflow_err   = (sotbuf_waddr == ackd_seqnum_plus1) & sotbuf_we;
//wire        rbuf_overflow_err     = (rbuf_waddr   == next_ackd_tlp_addr) & rbuf_we;

// -----------------------------------------------------------------------------
// output drives
assign rbuf_reply_req   = (state == S_SET_REPLY_REQ); //(state == S_REPLY_REQ); // ###

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
       rbuf_latched_1eot <= #TP 1'b0;
    else if (rbuf_eot_only & !dlyd_int_halt)
       rbuf_latched_1eot <= #TP 1'b1;
    else  if (!dlyd_int_halt)
       rbuf_latched_1eot <= #TP 1'b0;

always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        xdlh_retry_req  <= #TP 1'b0;
    end
    else begin
        xdlh_retry_req  <= #TP (state == S_IDLE) & reply_req;
    end
end


// Force Linkdown when xdlh_smlh_start_link_retrain x 3
always @ (posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        xdlh_smlh_start_link_retrain_1d <= #TP 1'b0 ;
    else
        xdlh_smlh_start_link_retrain_1d <= #TP xdlh_smlh_start_link_retrain ;

assign b_xdlh_retrain_cnt.retrain_cnt_incr = ( xdlh_smlh_start_link_retrain && !xdlh_smlh_start_link_retrain_1d );
assign b_xdlh_retrain_cnt.retrain_cnt_reset = ( seqnum_upd | xdlh_smlh_goto_detect );


always @ (posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        xdlh_smlh_goto_detect <= 1'b0 ;
    else if( cdm_ras_des_force_linkdown_noack & (b_xdlh_retrain_cnt.retrain_cnt==2'b11) & (b_xdlh_replay_num.replay_num == 2'b11) & (state == S_IDLE) & reply_req & !seqnum_upd )
        xdlh_smlh_goto_detect <= 1'b1 ;


//-----------------------------------------------------
//128b, 256b, 512b block
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        int_seqnum_c  <= #TP 12'b0;
    end else if (latch_retry_start_addr) begin
        // taking the same snap shot as rbuf_raddr being updated for the starting point of the reply
        int_seqnum_c  <= #TP schd_ackd_seqnum_plus1[11:0];
    end else if (int_dv & rbuf_sot_eot & !dlyd_int_halt) begin
        int_seqnum_c  <= #TP int_seqnum_c + 1'b1 ;
    end else if (int_dv & !first_tlp & !rbuf_latched_1eot & (rbuf_eot_sot | retryram_eot_1) & !dlyd_int_halt) begin
        int_seqnum_c  <= #TP int_seqnum_c + 1'b1 ;
    end else if (int_dv & !first_tlp & rbuf_latched_1eot & (rbuf_eot_sot_eot) & !dlyd_int_halt) begin
        int_seqnum_c  <= #TP int_seqnum_c + 1'b1 ;
    end else if (int_dv & !first_tlp & retryram_eot_2 & !dlyd_int_halt) begin
        int_seqnum_c  <= #TP int_seqnum_c + 2'b10 ;
    end else if (int_dv & first_tlp & retryram_eot_2 & !dlyd_int_halt) begin
        int_seqnum_c  <= #TP int_seqnum_c + 1'b1 ;
    end

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
       int_dv_q <= #TP 1'b0;
    else
       int_dv_q <= #TP  int_dv;

assign first_tlp =  !int_dv_q & int_dv;
assign int_seqnum = !first_tlp & !rbuf_latched_1eot & (rbuf_eot_sot | rbuf_eot_sot_eot) ? (int_seqnum_c + 1'b1) : int_seqnum_c;
//-----------------------------------------------------
//32b/64b block
//-----------------------------------------------------

assign int_halt = rbuf_halt & rbuf_xmt_dv;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        dlyd_int_halt       <= #TP 1'b0;
    end else begin
        dlyd_int_halt       <= #TP int_halt;
    end

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        latchd_int_data     <= #TP ALL_ZERO_DATA;
        latchd_int_dv       <= #TP 1'b0;
        latchd_int_sot_128      <= #TP {NW{1'b0}};
        latchd_int_eot_128      <= #TP {NW{1'b0}};
        latchd_int_badeot_128   <= #TP {NW{1'b0}};
        latchd_int_seqnum   <= #TP 12'b0;
//`ifdef CX_TLP_PREFIX_ENABLE
        latchd_rbuf_tlp_len <= #TP {11{1'b0}};
//`endif
    end else if (!dlyd_int_halt) begin
        latchd_int_data     <= #TP int_data;
        latchd_int_dv       <= #TP int_dv;
        latchd_int_sot_128      <= #TP int_dv ? int_sot_128 : {NW{1'b0}};
        latchd_int_eot_128      <= #TP int_dv ? int_eot_128 : {NW{1'b0}};
        latchd_int_badeot_128   <= #TP int_dv ? int_badeot_128 : {NW{1'b0}};
        latchd_int_seqnum   <= #TP int_seqnum;
// `ifdef CX_TLP_PREFIX_ENABLE
        latchd_rbuf_tlp_len <= #TP int_rbuf_tlp_len;
//`endif
    end

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        rbuf_xmt_data       <= #TP ALL_ZERO_DATA;
        rbuf_xmt_dv         <= #TP 1'b0;
        rbuf_xmt_sot_128    <= #TP {NW{1'b0}};
        rbuf_xmt_eot_128    <= #TP {NW{1'b0}};
        rbuf_xmt_badeot_128 <= #TP {NW{1'b0}};
        rbuf_xmt_seqnum     <= #TP 12'b0;
//`ifdef CX_TLP_PREFIX_ENABLE
        rbuf_xdlh_tlp_len  <= #TP {11{1'b0}};
//`endif
    end else if (!int_halt & dlyd_int_halt) begin
        rbuf_xmt_data       <= #TP latchd_int_data;
        rbuf_xmt_dv         <= #TP latchd_int_dv;
        rbuf_xmt_sot_128    <= #TP latchd_int_sot_128;
        rbuf_xmt_eot_128    <= #TP latchd_int_eot_128;
        rbuf_xmt_badeot_128 <= #TP latchd_int_badeot_128;
        rbuf_xmt_seqnum     <= #TP latchd_int_seqnum;
//`ifdef CX_TLP_PREFIX_ENABLE
        rbuf_xdlh_tlp_len  <= #TP latchd_rbuf_tlp_len;
//`endif
    end else if (!int_halt & !dlyd_int_halt) begin
        rbuf_xmt_data       <= #TP int_data;
        rbuf_xmt_dv         <= #TP int_dv;
        rbuf_xmt_sot_128    <= #TP int_dv ? int_sot_128 : {NW{1'b0}};
        rbuf_xmt_eot_128    <= #TP int_dv ? int_eot_128 : {NW{1'b0}};
        rbuf_xmt_badeot_128 <= #TP int_dv ? int_badeot_128 : {NW{1'b0}};
        rbuf_xmt_seqnum     <= #TP int_seqnum;
//`ifdef CX_TLP_PREFIX_ENABLE
        rbuf_xdlh_tlp_len  <= #TP int_rbuf_tlp_len;
//`endif
    end

logic                    rbuf_chk_unused_stallout;
logic                    rbuf_chk_unused_halt_out;
logic                    rbuf_chk_unused_valid_out;
logic                    rbuf_chk_unused_ras_dp_err_inband_kbd_out;
logic [RBUF_PW-1:0]      rbuf_chk_unused_dout;
logic [RBUF_PROT_WD-1:0] rbuf_chk_unused_dout_prot;

ras_dp_pipe
 #(
    .PIPELINE_TYPE           (6),
    .N_STAGES                (0),
    .CAN_STALL               (0),
    .BUS_PROTECT_GEN_EN      (0),
    .BUS_PROTECT_CHK_EN      (1),
    .PROT_TYPE               (P_RAS_RAM_PROT_TYPE),
    .PROT_RANGE              (P_RAS_RAM_PROT_RANGE),
    .PROT_WD                 (RBUF_PROT_WD),
    .PARITY_MODE             (P_PARITY_MODE),
    .PROT_CORRECT_EN         (1),
    .TOTAL_WIDTH             (RBUF_CTRL_BITS_WD+DW+RBUF_PW),
    .EXCLUDE_PROT_WIDTH      (0),
    .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE_XDLH_RETRY_BUF + 1),
    .ADDR_ECC_PROT_EN        (1),
    .ADDR_LOG_EN             (1),
    .ADDR_INDEX              (RBUF_CTRL_BITS_WD+DW),
    .ADDR_WD                 (RBUF_PW)
) u_retryram_datactrl_protect (
    .clk                       (core_clk),
    .rst_n                     (core_rst_n),

    .din                       ({retryram_datactrl_protect_checker_addr, rbuf_dout[0 +: (RBUF_CTRL_BITS_WD+DW)]}),
    .din_prot                  (rbuf_dout[(RBUF_CTRL_BITS_WD+DW) +: RBUF_PROT_WD]),

    .dout                      ({rbuf_chk_unused_dout, rbuf_dout_chk[0 +: (RBUF_CTRL_BITS_WD+DW)]}),
    .dout_prot                 (rbuf_chk_unused_dout_prot),
    
    .en                        (1'b0),
    .bypass                    (1'b0),
    .stall                     (1'b0),
    .stallout                  (rbuf_chk_unused_stallout),

    .valid_in                  (xdlh_retryram_par_chk_val_dd),
    .halt_out                  (rbuf_chk_unused_halt_out),

    .valid_out                 (rbuf_chk_unused_valid_out),
    .halt_in                   (1'b0),
    .ras_dp_err_inband_kbd_in  (1'b0),
    .ras_dp_err_inband_kbd_out (rbuf_chk_unused_ras_dp_err_inband_kbd_out),
    .ras_dp_err_log            (ras_dp_err_log[1])
    ,
    .ras_dp_err_inj            (ras_dp_err_inj)
);

logic                            rasdp_gen_unused_stallout;
logic                            rasdp_gen_unused_halt_out;
logic                            rasdp_gen_unused_valid_out;
logic                            rasdp_gen_unused_ras_dp_err_inband_kbd_out;
ras_dp_err_log_t                 rasdp_gen_unused_ras_dp_err_log;

ras_dp_pipe
 #(
    .PIPELINE_TYPE           (6),
    .N_STAGES                (0),
    .CAN_STALL               (0),
    .BUS_PROTECT_GEN_EN      (1),
    .BUS_PROTECT_CHK_EN      (0),
    .PROT_TYPE               (RAS_PROT_TYPE),
    .PROT_RANGE              (RAS_PROT_RANGE),
    .PROT_WD                 (DATA_PAR_WD),
    .PARITY_MODE             (RAS_PARITY_MODE),
    .TOTAL_WIDTH             (DW),
    .EXCLUDE_PROT_WIDTH      (0)
) u_retryram_data_par_gen (
    .clk                       (core_clk),
    .rst_n                     (core_rst_n),

    .din                       (rbuf_dout_chk[0 +: DW]),
    .din_prot                  ('0),

    .dout                      (retry_ram_data[0+:DW]),
    .dout_prot                 (retry_ram_data[DW+:DATA_PAR_WD]),
    
    .en                        (1'b0),
    .bypass                    (1'b0),
    .stall                     (1'b0),
    .stallout                  (rasdp_gen_unused_stallout),
    
    .valid_in                  ('0),
    .halt_out                  (rasdp_gen_unused_halt_out),
    
    .valid_out                 (rasdp_gen_unused_valid_out),
    .halt_in                   (1'b0),
    .ras_dp_err_inband_kbd_in  (1'b0),
    .ras_dp_err_inband_kbd_out (rasdp_gen_unused_ras_dp_err_inband_kbd_out),
    .ras_dp_err_log            (rasdp_gen_unused_ras_dp_err_log)
    ,
    .ras_dp_err_inj            ('0)
);


//-----------------------------------------------------
//-----------------------------------------------------
assign {retry_ram_tlp_len, retryram_eot_128, retryram_sot_enc} = rbuf_dout_chk[(DW+DATA_PROT_WD) +: RBUF_CTRL_BITS_WD];
//-----------------------------------------------------
//-----------------------------------------------------




//-----------------------------------------------------
//128b, 256b, 512b block
// reg det_sot_parerr;
// reg det_data_parerr;

// always @(posedge core_clk or negedge core_rst_n)
//    if (!core_rst_n)
//      det_sot_parerr <= #TP 1'b0;
//    else if ((state == S_IN_REPLY) & (rbuf_sot_only | rbuf_eot_sot) & rbuf_parerr)
//      det_sot_parerr <= #TP 1'b1;
//    else if ((state == S_IN_REPLY) & (rbuf_eot_only | rbuf_eot_sot_eot) | (state == S_IDLE))
//      det_sot_parerr <= #TP 1'b0;
//
//
// always @(posedge core_clk or negedge core_rst_n)
//    if (!core_rst_n)
//      det_data_parerr <= #TP 1'b0;
//    else if (no_sot_eot & (state == S_IN_REPLY) & rbuf_parerr)
//      det_data_parerr <= #TP 1'b1;
//    else if (rbuf_eot | (state == S_IDLE))
//      det_data_parerr <= #TP 1'b0;

always @(*)
  begin : PROC_RETRY_RAM_SOT_DEC
  integer j;
   retryram_sot_128 = {NW{1'b0}};
  for (j=1; j < NW+1; j=j+1)
    begin
      if (retryram_sot_enc == j)
         retryram_sot_128[j-1] = 1'b1;
    end
   end

reg [15:0] retryram_eot_temp;

always @(*)
  begin : EOT_TEMP
    retryram_eot_temp = 0;
    retryram_eot_temp[NW-1:0] = retryram_eot_128[NW-1:0];
  end

reg [3:0] first_rbuf_eot;
reg [3:0] second_rbuf_eot;


always @(retryram_eot_temp)
   begin
    first_rbuf_eot = 4'b0000;
    second_rbuf_eot = 4'b0000;

       case(retryram_eot_temp)
       16'b0000_0000_0000_1001: begin   first_rbuf_eot  = 4'd0 ;  second_rbuf_eot = 4'd3 ;  end
       16'b0000_0000_0001_0001: begin   first_rbuf_eot  = 4'd0 ;  second_rbuf_eot = 4'd4 ;  end
       16'b0000_0000_0010_0001: begin   first_rbuf_eot  = 4'd0 ;  second_rbuf_eot = 4'd5 ;  end
       16'b0000_0000_0100_0001: begin   first_rbuf_eot  = 4'd0 ;  second_rbuf_eot = 4'd6 ;  end
       16'b0000_0000_1000_0001: begin   first_rbuf_eot  = 4'd0 ;  second_rbuf_eot = 4'd7 ;  end
       16'b0000_0001_0000_0001: begin   first_rbuf_eot  = 4'd0 ;  second_rbuf_eot = 4'd8 ;  end
       16'b0000_0010_0000_0001: begin   first_rbuf_eot  = 4'd0 ;  second_rbuf_eot = 4'd9 ;  end
       16'b0000_0100_0000_0001: begin   first_rbuf_eot  = 4'd0 ;  second_rbuf_eot = 4'd10;  end
       16'b0000_1000_0000_0001: begin   first_rbuf_eot  = 4'd0 ;  second_rbuf_eot = 4'd11;  end
       16'b0001_0000_0000_0001: begin   first_rbuf_eot  = 4'd0 ;  second_rbuf_eot = 4'd12;  end
       16'b0010_0000_0000_0001: begin   first_rbuf_eot  = 4'd0 ;  second_rbuf_eot = 4'd13;  end
       16'b0100_0000_0000_0001: begin   first_rbuf_eot  = 4'd0 ;  second_rbuf_eot = 4'd14;  end
       16'b1000_0000_0000_0001: begin   first_rbuf_eot  = 4'd0 ;  second_rbuf_eot = 4'd15;  end

       16'b0000_0000_0001_0010: begin   first_rbuf_eot  = 4'd1 ;  second_rbuf_eot = 4'd4 ;  end
       16'b0000_0000_0010_0010: begin   first_rbuf_eot  = 4'd1 ;  second_rbuf_eot = 4'd5 ;  end
       16'b0000_0000_0100_0010: begin   first_rbuf_eot  = 4'd1 ;  second_rbuf_eot = 4'd6 ;  end
       16'b0000_0000_1000_0010: begin   first_rbuf_eot  = 4'd1 ;  second_rbuf_eot = 4'd7 ;  end
       16'b0000_0001_0000_0010: begin   first_rbuf_eot  = 4'd1 ;  second_rbuf_eot = 4'd8 ;  end
       16'b0000_0010_0000_0010: begin   first_rbuf_eot  = 4'd1 ;  second_rbuf_eot = 4'd9 ;  end
       16'b0000_0100_0000_0010: begin   first_rbuf_eot  = 4'd1 ;  second_rbuf_eot = 4'd10;  end
       16'b0000_1000_0000_0010: begin   first_rbuf_eot  = 4'd1 ;  second_rbuf_eot = 4'd11;  end
       16'b0001_0000_0000_0010: begin   first_rbuf_eot  = 4'd1 ;  second_rbuf_eot = 4'd12;  end
       16'b0010_0000_0000_0010: begin   first_rbuf_eot  = 4'd1 ;  second_rbuf_eot = 4'd13;  end
       16'b0100_0000_0000_0010: begin   first_rbuf_eot  = 4'd1 ;  second_rbuf_eot = 4'd14;  end
       16'b1000_0000_0000_0010: begin   first_rbuf_eot  = 4'd1 ;  second_rbuf_eot = 4'd15;  end

       16'b0000_0000_0010_0100: begin   first_rbuf_eot  = 4'd2 ;  second_rbuf_eot = 4'd5 ;  end
       16'b0000_0000_0100_0100: begin   first_rbuf_eot  = 4'd2 ;  second_rbuf_eot = 4'd6 ;  end
       16'b0000_0000_1000_0100: begin   first_rbuf_eot  = 4'd2 ;  second_rbuf_eot = 4'd7 ;  end
       16'b0000_0001_0000_0100: begin   first_rbuf_eot  = 4'd2 ;  second_rbuf_eot = 4'd8 ;  end
       16'b0000_0010_0000_0100: begin   first_rbuf_eot  = 4'd2 ;  second_rbuf_eot = 4'd9 ;  end
       16'b0000_0100_0000_0100: begin   first_rbuf_eot  = 4'd2 ;  second_rbuf_eot = 4'd10;  end
       16'b0000_1000_0000_0100: begin   first_rbuf_eot  = 4'd2 ;  second_rbuf_eot = 4'd11;  end
       16'b0001_0000_0000_0100: begin   first_rbuf_eot  = 4'd2 ;  second_rbuf_eot = 4'd12;  end
       16'b0010_0000_0000_0100: begin   first_rbuf_eot  = 4'd2 ;  second_rbuf_eot = 4'd13;  end
       16'b0100_0000_0000_0100: begin   first_rbuf_eot  = 4'd2 ;  second_rbuf_eot = 4'd14;  end
       16'b1000_0000_0000_0100: begin   first_rbuf_eot  = 4'd2 ;  second_rbuf_eot = 4'd15;  end

       16'b0000_0000_0100_1000: begin   first_rbuf_eot  = 4'd3 ;  second_rbuf_eot = 4'd6 ;  end
       16'b0000_0000_1000_1000: begin   first_rbuf_eot  = 4'd3 ;  second_rbuf_eot = 4'd7 ;  end
       16'b0000_0001_0000_1000: begin   first_rbuf_eot  = 4'd3 ;  second_rbuf_eot = 4'd8 ;  end
       16'b0000_0010_0000_1000: begin   first_rbuf_eot  = 4'd3 ;  second_rbuf_eot = 4'd9 ;  end
       16'b0000_0100_0000_1000: begin   first_rbuf_eot  = 4'd3 ;  second_rbuf_eot = 4'd10;  end
       16'b0000_1000_0000_1000: begin   first_rbuf_eot  = 4'd3 ;  second_rbuf_eot = 4'd11;  end
       16'b0001_0000_0000_1000: begin   first_rbuf_eot  = 4'd3 ;  second_rbuf_eot = 4'd12;  end
       16'b0010_0000_0000_1000: begin   first_rbuf_eot  = 4'd3 ;  second_rbuf_eot = 4'd13;  end
       16'b0100_0000_0000_1000: begin   first_rbuf_eot  = 4'd3 ;  second_rbuf_eot = 4'd14;  end
       16'b1000_0000_0000_1000: begin   first_rbuf_eot  = 4'd3 ;  second_rbuf_eot = 4'd15;  end

       16'b0000_0000_1001_0000: begin   first_rbuf_eot  = 4'd4 ;  second_rbuf_eot = 4'd7 ;  end
       16'b0000_0001_0001_0000: begin   first_rbuf_eot  = 4'd4 ;  second_rbuf_eot = 4'd8 ;  end
       16'b0000_0010_0001_0000: begin   first_rbuf_eot  = 4'd4 ;  second_rbuf_eot = 4'd9 ;  end
       16'b0000_0100_0001_0000: begin   first_rbuf_eot  = 4'd4 ;  second_rbuf_eot = 4'd10;  end
       16'b0000_1000_0001_0000: begin   first_rbuf_eot  = 4'd4 ;  second_rbuf_eot = 4'd11;  end
       16'b0001_0000_0001_0000: begin   first_rbuf_eot  = 4'd4 ;  second_rbuf_eot = 4'd12;  end
       16'b0010_0000_0001_0000: begin   first_rbuf_eot  = 4'd4 ;  second_rbuf_eot = 4'd13;  end
       16'b0100_0000_0001_0000: begin   first_rbuf_eot  = 4'd4 ;  second_rbuf_eot = 4'd14;  end
       16'b1000_0000_0001_0000: begin   first_rbuf_eot  = 4'd4 ;  second_rbuf_eot = 4'd15;  end

       16'b0000_0001_0010_0000: begin   first_rbuf_eot  = 4'd5 ;  second_rbuf_eot = 4'd8 ;  end
       16'b0000_0010_0010_0000: begin   first_rbuf_eot  = 4'd5 ;  second_rbuf_eot = 4'd9 ;  end
       16'b0000_0100_0010_0000: begin   first_rbuf_eot  = 4'd5 ;  second_rbuf_eot = 4'd10;  end
       16'b0000_1000_0010_0000: begin   first_rbuf_eot  = 4'd5 ;  second_rbuf_eot = 4'd11;  end
       16'b0001_0000_0010_0000: begin   first_rbuf_eot  = 4'd5 ;  second_rbuf_eot = 4'd12;  end
       16'b0010_0000_0010_0000: begin   first_rbuf_eot  = 4'd5 ;  second_rbuf_eot = 4'd13;  end
       16'b0100_0000_0010_0000: begin   first_rbuf_eot  = 4'd5 ;  second_rbuf_eot = 4'd14;  end
       16'b1000_0000_0010_0000: begin   first_rbuf_eot  = 4'd5 ;  second_rbuf_eot = 4'd15;  end

       16'b0000_0010_0100_0000: begin   first_rbuf_eot  = 4'd6 ;  second_rbuf_eot = 4'd9 ;  end
       16'b0000_0100_0100_0000: begin   first_rbuf_eot  = 4'd6 ;  second_rbuf_eot = 4'd10;  end
       16'b0000_1000_0100_0000: begin   first_rbuf_eot  = 4'd6 ;  second_rbuf_eot = 4'd11;  end
       16'b0001_0000_0100_0000: begin   first_rbuf_eot  = 4'd6 ;  second_rbuf_eot = 4'd12;  end
       16'b0010_0000_0100_0000: begin   first_rbuf_eot  = 4'd6 ;  second_rbuf_eot = 4'd13;  end
       16'b0100_0000_0100_0000: begin   first_rbuf_eot  = 4'd6 ;  second_rbuf_eot = 4'd14;  end
       16'b1000_0000_0100_0000: begin   first_rbuf_eot  = 4'd6 ;  second_rbuf_eot = 4'd15;  end

       16'b0000_0100_1000_0000: begin   first_rbuf_eot  = 4'd7 ;  second_rbuf_eot = 4'd10;  end
       16'b0000_1000_1000_0000: begin   first_rbuf_eot  = 4'd7 ;  second_rbuf_eot = 4'd11;  end
       16'b0001_0000_1000_0000: begin   first_rbuf_eot  = 4'd7 ;  second_rbuf_eot = 4'd12;  end
       16'b0010_0000_1000_0000: begin   first_rbuf_eot  = 4'd7 ;  second_rbuf_eot = 4'd13;  end
       16'b0100_0000_1000_0000: begin   first_rbuf_eot  = 4'd7 ;  second_rbuf_eot = 4'd14;  end
       16'b1000_0000_1000_0000: begin   first_rbuf_eot  = 4'd7 ;  second_rbuf_eot = 4'd15;  end

       16'b0000_1001_0000_0000: begin   first_rbuf_eot  = 4'd8 ;  second_rbuf_eot = 4'd11;  end
       16'b0001_0001_0000_0000: begin   first_rbuf_eot  = 4'd8 ;  second_rbuf_eot = 4'd12;  end
       16'b0010_0001_0000_0000: begin   first_rbuf_eot  = 4'd8 ;  second_rbuf_eot = 4'd13;  end
       16'b0100_0001_0000_0000: begin   first_rbuf_eot  = 4'd8 ;  second_rbuf_eot = 4'd14;  end
       16'b1000_0001_0000_0000: begin   first_rbuf_eot  = 4'd8 ;  second_rbuf_eot = 4'd15;  end

       16'b0001_0010_0000_0000: begin   first_rbuf_eot  = 4'd9 ;  second_rbuf_eot = 4'd12;  end
       16'b0010_0010_0000_0000: begin   first_rbuf_eot  = 4'd9 ;  second_rbuf_eot = 4'd13;  end
       16'b0100_0010_0000_0000: begin   first_rbuf_eot  = 4'd9 ;  second_rbuf_eot = 4'd14;  end
       16'b1000_0010_0000_0000: begin   first_rbuf_eot  = 4'd9 ;  second_rbuf_eot = 4'd15;  end

       16'b0010_0100_0000_0000: begin   first_rbuf_eot  = 4'd10;  second_rbuf_eot = 4'd13;  end
       16'b0100_0100_0000_0000: begin   first_rbuf_eot  = 4'd10;  second_rbuf_eot = 4'd14;  end
       16'b1000_0100_0000_0000: begin   first_rbuf_eot  = 4'd10;  second_rbuf_eot = 4'd15;  end

       16'b0100_1000_0000_0000: begin   first_rbuf_eot  = 4'd11;  second_rbuf_eot = 4'd14;  end
       16'b1000_1000_0000_0000: begin   first_rbuf_eot  = 4'd11;  second_rbuf_eot = 4'd15;  end

       16'b1001_0000_0000_0000: begin   first_rbuf_eot  = 4'd12;  second_rbuf_eot = 4'd15;  end

                       default: begin   first_rbuf_eot  = 4'd0 ;  second_rbuf_eot = 4'd0 ;  end
     endcase
   end


assign no_sot_eot = int_dv & !rbuf_eot & !retryram_sot1;

assign rbuf_sot_only = int_dv & retryram_sot1 & !(|retryram_eot_128);

assign rbuf_eot = int_dv & |retryram_eot_128;

assign retryram_sot1 = int_dv & |retryram_sot_128;

assign retryram_eot_1 =  int_dv & (^retryram_eot_128[NW-1:0]) ;

assign retryram_eot_2 = int_dv & !(^retryram_eot_128[NW-1:0]) & (|retryram_eot_128[NW-1:0]);   // If 2 EOTs, XOR is 0 and OR is 1


assign rbuf_sot_eot = int_dv & (|retryram_sot_128) & retryram_eot_1 & (retryram_sot_128 < retryram_eot_128);

assign rbuf_eot_sot = int_dv & (|retryram_sot_128) & retryram_eot_1 & (retryram_sot_128 > retryram_eot_128);


assign rbuf_eot_only = int_dv & retryram_eot_1 & ! (|retryram_sot_128);


assign rbuf_eot_sot_eot = int_dv & retryram_eot_2;

assign rbuf_sot_eot_d = (|retryram_sot_128) & (^retryram_eot_128[NW-1:0]) & (retryram_sot_128 < retryram_eot_128);

// To handle different cases of rbuf parity errors

assign reply_done = rbuf_reply_done_dd;

always @(*)
  begin : PROC_RBUF_SOT_EOT
   int_sot_128 =     retryram_sot_128;
   int_eot_128 =     retryram_eot_128;
   int_badeot_128 =  {NW{1'b0}};
  if (state == S_IN_REPLY)
     begin
//       if (rbuf_parerr | sotbuf_parerr | (rbuf_reply_abort & (|retryram_eot_128))) // Clear SOT when parerr
       if (rbuf_reply_abort & (|retryram_eot_128))
         int_sot_128 = {NW{1'b0}};
/*
        if (det_sot_parerr & (rbuf_eot_only | rbuf_eot_sot))
        int_eot_128 =   {NW{1'b0}};
*/
       if (rbuf_reply_abort & rbuf_eot_sot_eot)
         begin : PROC_CLEAR_EOT_1
           integer k;
        int_eot_128 = retryram_eot_128;
            for (k=0; k<NW; k=k+1)
            begin
        if (k == second_rbuf_eot)
            int_eot_128[k] = 1'b0;
            end
        end

       if (rbuf_reply_abort & rbuf_sot_eot)
            begin
            int_eot_128 = {NW{1'b0}};
            int_sot_128 = {NW{1'b0}};
            end

/*
       if (det_sot_parerr & !rbuf_parerr & rbuf_eot_sot_eot)
         begin : PROC_CLEAR_EOT_2
      integer m;
      int_eot_128 = retryram_eot_128;

            for (m=0; m<NW; m=m+1)
         begin
           if (m == first_rbuf_eot)
             int_eot_128[m] = 1'b0;
          end
          end
       if (!det_sot_parerr & rbuf_parerr & rbuf_eot_sot_eot)
          begin : PROC_SET_BADEOT1
        integer l;
        int_eot_128 = retryram_eot_128;
        int_badeot_128 = {NW{1'b0}};

            for (l=0; l<NW; l=l+1)
         begin
           if (l == first_rbuf_eot)
             int_badeot_128[l] = 1'b1;
           if (l == second_rbuf_eot)
             int_eot_128[l] = 1'b0;
          end
            end
       if (rbuf_parerr & rbuf_sot_eot)
             int_eot_128 =   {NW{1'b0}};

       if ( (rbuf_parerr | sotbuf_parerr) & !rbuf_sot_eot)
            begin
         int_eot_128 = {{(NW-1){1'b0}}, 1'b1};
         int_badeot_128[0] = 1'b1;
       end

       if (!det_sot_parerr & det_data_parerr & rbuf_eot_sot_eot & !rbuf_parerr)
         begin  : PROC_SET_BADEOT2
      integer n;
      int_badeot_128 = {NW{1'b0}};

            for (n=0; n<NW; n=n+1)
         begin
           if (n == first_rbuf_eot)
             int_badeot_128[n] = 1'b1;
          end
         end
*/
   end
end

 assign int_dv   = (state == S_IN_REPLY) & !(rbuf_sot_eot_d & rbuf_reply_abort) & !reload_start_addr_q;
 assign int_data = int_dv ? retry_ram_data : ALL_ZERO_DATA;

//end of 128b/256b/512b block
//-----------------------------------------------------

/*
`ifdef CX_TLP_PREFIX_ENABLE
`ifdef CX_GEN3_SPEED
assign int_rbuf_tlp_len     = int_dv ? retry_ram_tlp_len : {11{1'b0}};
`endif
`endif
*/

assign int_rbuf_tlp_len = int_dv ? retry_ram_tlp_len : {11{1'b0}};


//-----------------------------------------------------
// MISC outputs
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)  begin
        xdlh_rbuf_not_empty         <= #TP 1'b0;
        xdlh_not_expecting_ack      <= #TP 1'b0;
    end else begin
        xdlh_rbuf_not_empty             <= #TP !all_tlp_schd_ackd;
        xdlh_not_expecting_ack          <= #TP all_tlp_schd_ackd;
    end

assign xdlh_rdlh_last_xmt_seqnum  = rbuf_last_xmt_seqnum;

wire[RBUF_PW:0] rbuf_entry_cnt_comb = 
                                      (next_ackd_tlp_addr > rbuf_waddr) ?
                                      ({1'b0,next_ackd_tlp_addr} - {1'b0,rbuf_waddr}) :
                                      next_ackd_tlp_addr == rbuf_waddr && !all_tlp_schd_ackd ?  // thoughts: condition on rbuf_entry_cnt being exactly 1 in previous cycle can be added to avoid spurious transitions to 0 when all_tlp_schd_ackd deasserts
                                      1'b0 :
                                      (({1'b0,retryram_xdlh_depth} +1'b1  - {1'b0,rbuf_waddr}) +
                                       {1'b0,next_ackd_tlp_addr});

// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: This logic is designed to be modulo. Sequence counters are intended to
// wrap without preseveration of carry/borrow
wire [11:0] rbuf_pkt_cnt_comb  = 
            (rbuf_last_xmt_seqnum > schd_ackd_seqnum)
            ?  (rbuf_last_xmt_seqnum - schd_ackd_seqnum)
            : ((MAX_SEQNUM -schd_ackd_seqnum) + rbuf_last_xmt_seqnum);
// spyglass enable_block W164a

always_comb begin
    rbuf_entry_cnt = rbuf_entry_cnt_comb;
    rbuf_pkt_cnt   = rbuf_pkt_cnt_comb;
end






// few thoughts:
// making receiver to get rid of the duplicate ack/nack and latch the sequence number, then there can be quit a good gate saving.
//------------------------------------------------------------------------------



endmodule
