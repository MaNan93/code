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
// ---    $Revision: #15 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/smlh_seq_finder3_slv.sv#15 $
// -------------------------------------------------------------------------
// --- Module Description: Receive MAC layer Sequence Finder for gen3
// --- This module performs the receive special sequence detect as well as
// receive link in training status. This module monitors the PHY rx data to
// extract the all special ordered set defined in PCIExpress spec for gen3.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"

 
 module smlh_seq_finder3_slv
 import DWC_pcie_core_pkg::ltssm_state_e;
 import DWC_pcie_core_pkg::S_CFG_LINKWD_START;
 import DWC_pcie_core_pkg::S_RCVRY_LOCK;
 import DWC_pcie_core_pkg::S_RCVRY_RCVRCFG;
 import DWC_pcie_core_pkg::S_L0;
 import DWC_pcie_core_pkg::S_L0S;
 import DWC_pcie_core_pkg::S_L123_SEND_EIDLE;
 import DWC_pcie_core_pkg::S_RCVRY_EQ0;
 import DWC_pcie_core_pkg::S_RCVRY_EQ1;
 import DWC_pcie_core_pkg::S_RCVRY_EQ2;
 import DWC_pcie_core_pkg::S_RCVRY_EQ3;
#(
    parameter   INST              = 0,                           // The uniquifying parameter for each port logic instance.
    parameter   NB                = ((`CX_NB==32) ? `CX_NB_GEN5 : `CX_NB), // Number of symbols (bytes) per clock cycle
    parameter   NB2               = ((`CX_NB>=16) ? 16:8),       // Number of internal symbols (bytes) per clock cycle
    parameter   AW                = `CX_ANB_WD,                  // Width of the active number of bytes
    parameter   TP                = `TP,                         // Clock to Q delay (simulator insurance)
    parameter   EQTS_WD           = 32,                          // bit width of concantenation of TS symbols {9,8,7,6}
    parameter  TSFD_WD            = `CX_TS_FIELD_CONTROL_WD,     // sym7,6,5,4,3,2,1
    parameter   EQTS_HALF_WD      = ((`CX_NB>=16) ? 32:16)        // bit width of concantenation of TS symbols {9,8} or {7,6} or {9,8,7,6}
)

                             (
    input                   core_clk, 
    input                   core_rst_n, 
    input                   cfg_gen3_dc_balance_disable, 
    input                   cfg_upstream_port, 
    input                   cfg_elastic_buffer_mode,
    input                   ltssm_lane_flip_ctrl_chg_pulse,    // lane flip control update pulse
    input                   smlh_link_up, 
    input                   smlh_link_in_training, 
    input   [AW-1:0]        active_nb, 
    input   [AW-1:0]        active_nb_gen34,
    input   [2:0]           current_data_rate, 
    input   [(NB*8)-1:0]    rxdata, 
    input                   rxdata_dv, 
    input                   rxaligned,
    input                   rxstartblock, 
    input                   ints1, 
    input                   ints2, 
    input                   inskp, 
    input                   ineie, 
    input                   eie_det,
    input                   insds,
    input   [1:0]           rxsyncheader,
    input   [NB-1:0]        rxerror,
    input   [NB-1:0]        dec_rx_pad,
    input   [NB-1:0]        dec_rx_num_v,
    input   [NB-1:0]        dec_ts1_id,
    input   [NB-1:0]        dec_ts2_id,
    input   [NB-1:0]        dec_eqts,
    input   [NB-1:0]        dec_rx_rate_v,
    input                   smlh_ts_spd_chg_rcvd_clr,
    input                   ltssm_clear,                         // used to clear TS persistency count on a ltssm state transition
    input                   smlh_ltssm_in_compliance,
    input   ltssm_state_e   smlh_ltssm_state,
    input                   xmtbyte_eies_sent,
    input                   xmtbyte_skip_sent,
    input                   int_directed_speed_change,
    input                   smlh_keep_rcvrylock_lane,
    output  [TSFD_WD-1:0]   smseq_ts_info,
    output  [1:0]           smseq_ts_lanen_linkn_pad,
    output  reg [3:0]       smseq_ts_rcvd_mtx_pcnt,
    output  reg [3:0]       smseq_ts_rcvd_pcnt,
    output  reg [1:0]       smseq_ts_rcvd_cond_pcnt,             //persistency count for rcvd TS with conditions
    output                  smseq_ts_error,
    output reg [3:0]        smseq_ts_rcvd_s6s9_pcnt,             // persistency count for TS symbol {9,8,7,6}
    output reg [7:0]        smseq_error_count,                   // got from Modified Compliance Pattern
    output reg              smseq_inskip_rcv, 
    output                  smseq_ts1_rcvd, 
    output                  smseq_ts2_rcvd, 
    output reg              smseq_ts1_rcvd_pulse, 
    output reg              smseq_ts2_rcvd_pulse, 
    output                  smseq_ineies_rcv,                    // Electrical Idle Exit level signal
    output                  smseq_sds_rcvd,                      // SDS received. need it for Rx_L0s.FTS to L0 transition as per spec *29Sep09.pdf
    output  [EQTS_WD-1:0]   smseq_eqts_info                      // EQ TS content of symbols {9,8,7,6}
    ,
    output reg [7:0]        smseq_mcs_sts,
    output reg              smseq_fts_rcvd_pulse,
    output reg [63:0]       smseq_ts_debug_info
);

localparam GEN3_NB = `CX_NB_GEN3;
localparam GEN4_NB = `CX_NB_GEN4;
localparam GEN5_NB = `CX_NB_GEN5;
// IO declaration
reg                      latched_link_any_8_ts1_spd_chg_1_rcvd;
wire                     speed_change_is_1;
wire                     smlh_ltssm_in_rcvrylock;
wire                     ltssm_state_rcvry_eq;
wire                     inskp_i;
wire                     ineie_i;
wire                     eie_det_i;
reg                      inskip_rcv;
reg                      eies_rcvd_pulse;
reg                      latched_rlock_eies_rcvd;
wire                     rlock_eies_rcvd;
reg                      smlh_ltssm_in_rcvrylock_d;
reg                      ltssm_state_rcvry_eq_d;
wire                     smlh_ltssm_in_rcvrylock_enter;
wire                     ltssm_in_rcvry;
wire                     ltssm_in_cfglinkwdstart;
wire                     ltssm_in_l0;
wire                     ltssm_in_l0s;
wire                     ltssm_in_l123sendeidle;
reg                      rxdata_dv_d;
reg                      rxdata_dv_dd;
wire                     rxdatainvld_pulse;
reg                      in_ts_d;
reg   [7:0]              int_ts_sym[0:15];
reg   [7:0]              dec_ts_sym[0:15];
reg   [7:0]              pv_ts_sym[6:9]; // symbol 6-9 for Parity Valid check
reg   [7:0]              int_ts_sym_rcvd[1:9];
//wire  [7:0]              tmp_data_rate;
//wire  [7:0]              tmp_link_ctrl;
reg                      ts_link_num_is_k237;
reg                      ts_lane_num_is_k237;
reg                      ts_link_num_is_k237_i;
reg                      ts_lane_num_is_k237_i;
reg   [3:0]              sym_count;
reg                      ts_error;
reg                      ts1_rcvd;
reg                      ts2_rcvd;
reg                      sds_rcvd;
wire                     sds_rcvd_i;
reg   [3:0]              int_sym_count[0:NB2-1];
wire  [NB2-1:0]          int_in_ts;
wire                     int_ts_error;
reg   [NB2*8-1:0]        rx_data;
reg                      rx_err;
reg                      rx_dv;
wire  [NB2-1:0]          rx_bv;
reg                      rx_ts1_0;
reg                      rx_ts2_0;
reg   [NB2-1:0]          rx_pad;
reg   [NB2-1:0]          rx_num_v; //rx link/lane number valid
reg   [NB2-1:0]          ts1_id;
reg   [NB2-1:0]          ts2_id;
wire                     rx_ts_0;
wire                     ints;
wire  [NB2-1:0]          rx_lnum_v; //rx link/lane number available
reg   [NB2-1:0]          rx_rate_v; //rx data rate valid. [0] = byte 0 (1s/2s/4s) [1] = byte 4 (8s)
reg   [NB2-1:0]          eqts;      //bit[7] of Sym7 is 1'b1
wire                     dc_dis;    //disable DC balance
wire                     up;        //upstream port
wire                     pv;        //parity valid, compare XOR result of int_ts_s6s9 with bit 7 of symbol 9 in the end of correctly received TS1
reg   [NB2-1:0]          btv;       //byte valid
reg   [NB2-1:0]          int_btv;   //byte valid
wire                     int_ts_rcvd_pulse, int_ts1_rcvd_pulse, int_ts2_rcvd_pulse;
wire  [EQTS_HALF_WD-1:0] parity_info;         //bit 7 of symbol 9 is the received parity bit
reg                      parity_sym_6_7;      //parity for symbol 6/7
wire                     ltssm_in_compliance;
reg                      rxdatablock_d;
wire                     rxdatablock;
wire                     int_rxdatablock;
reg   [NB2-1:0]          sym_error;
reg                      latched_rxdata_dv;
wire  [AW-1:0]           sym_error_count;
reg                      latched_sym_updated;
wire                     xmtbyte_eieos_skip_sent;
reg   [10:1]             sym_diff_bus;
wire                     any_sym_diff;

//below signals are used for sds detection
wire [NB2*8-1:0] data64b_sds_sym_0     = {( current_data_rate == `GEN5_RATE ? {NB2-1{`CX_GEN5_SDS_BODY_ENC}} : {NB2-1{ `SDS_SYM_1}}),  `SDS_SYM_0};
wire [NB2*8-1:0] data64b_sds_sym_n     = current_data_rate == `GEN5_RATE ? {NB2{`CX_GEN5_SDS_BODY_ENC}} : {NB2{ `SDS_SYM_1}};
wire dwidth = ((current_data_rate == `GEN3_RATE && GEN3_NB == NB/2) || (current_data_rate == `GEN4_RATE && GEN4_NB == NB/2) || (current_data_rate == `GEN5_RATE && GEN5_NB == NB/2));
wire deskew_data_sds_sym_0    = dwidth ?
                                (rx_data[NB*8/2-1:0] == data64b_sds_sym_0[NB*8/2-1:0]) && insds && rx_dv && !rx_err :
                                (rx_data[NB*8-1:0] == data64b_sds_sym_0[NB*8-1:0]) && insds && rx_dv && !rx_err;
wire deskew_data_sds_sym_n    = dwidth ?
                                (rx_data[NB*8/2-1:0] == data64b_sds_sym_n[NB*8/2-1:0]) && insds && rx_dv && !rx_err :
                                (rx_data[NB*8-1:0] == data64b_sds_sym_n[NB*8-1:0]) && insds && rx_dv && !rx_err;

//
// active_nb decoder
//
assign  rx_bv = (active_nb_gen34 == 4'b0001) ? 8'b00000001 :
                (active_nb_gen34 == 4'b0010) ? 8'b00000011 :
                (active_nb_gen34 == 4'b0100) ? 8'b00001111 :
                (active_nb_gen34 == 4'b1000) ? 8'b11111111 : 8'b0000000;
//assign  rx_bv = (active_nb == 4'b0001) ? 8'b00000001 :
//                (active_nb == 4'b0010) ? 8'b00000011 :
//                (active_nb == 4'b0100) ? 8'b00001111 :
//                (active_nb == 4'b1000) ? 8'b11111111 : 8'b0000000;

always @( * ) begin : rx_8s_data_PROC
    integer i;

    rx_data = 0;
    rx_err  = 0;

    rx_dv  = rxdata_dv;
    rx_err = rxerror[0] & rxdata_dv; //rxerror[NB-1:1] duplicates rxerror[0], see rmlh.v

    for ( i=0; i<NB; i=i+1 ) begin
        rx_data[i*8 +: 8] = rxdata[i*8 +: 8];
    end
end // rx_8s_data_PROC

//
//Symbol decoder
//
//TS OS window
assign ints                    = ints1 | ints2;
assign smlh_ltssm_in_rcvrylock = (smlh_ltssm_state == S_RCVRY_LOCK);
assign ltssm_state_rcvry_eq    = (smlh_ltssm_state == S_RCVRY_EQ0 || smlh_ltssm_state == S_RCVRY_EQ1 || smlh_ltssm_state == S_RCVRY_EQ2 || smlh_ltssm_state == S_RCVRY_EQ3);
assign ltssm_in_rcvry          = (smlh_ltssm_state == S_RCVRY_LOCK || smlh_ltssm_state == S_RCVRY_RCVRCFG);
assign ltssm_in_cfglinkwdstart = (smlh_ltssm_state == S_CFG_LINKWD_START);
assign ltssm_in_l0             = (smlh_ltssm_state == S_L0);
assign ltssm_in_l0s            = (smlh_ltssm_state == S_L0S);
assign ltssm_in_l123sendeidle  = (smlh_ltssm_state == S_L123_SEND_EIDLE);
assign inskp_i                 = inskp;
assign ineie_i                 = ineie;
assign eie_det_i               = eie_det;

always@( * ) begin : signal_decoder_PROC
    integer i;

    rx_pad    = 0;
    rx_num_v  = 0;
    ts1_id    = 0;
    ts2_id    = 0;
    rx_ts1_0  = 0;
    rx_ts2_0  = 0;
    eqts      = 0;
    rx_rate_v = 0;

    rx_ts1_0 = rxstartblock & ints1; //symbol 0 of TS1
    rx_ts2_0 = rxstartblock & ints2; //symbol 0 of TS2

    for (i=0; i<NB; i=i+1) begin
        rx_pad   [i] = dec_rx_pad[i] ;
        rx_num_v [i] = dec_rx_num_v[i] ;
        ts1_id   [i] = dec_ts1_id[i] ;
        ts2_id   [i] = dec_ts2_id[i] ;
        eqts     [i] = dec_eqts[i] ;
        rx_rate_v[i] = dec_rx_rate_v[i] ;
    end
end // signal_decoder_PROC


//
// int_sym_count
//
// combinational logic of int_sym_count for each symbol.
// int_sym_count is a free running counter reset by rxstartblock.
// sym_count is reg version of int_sym_count[NB-1].
// byte 0 is always for OS recognization in gen3 frame.
// int_sym_count[0]=0, int_sym_count[1]=1, int_sym_count[2]=2, int_sym_count[3]=3, ... if rxstartblock is at the same cycle.
// if !rx_dv, no update to int_sym_count[*].
always @( * ) begin : int_sym_count_PROC
    int_sym_count[0] =            ( rxstartblock ? 0 : (rx_dv ? sym_count+1 : sym_count) );                    //byte0 always valid
    int_sym_count[1] = rx_bv[1] ? ( rxstartblock ? 1 : (rx_dv ? sym_count+2 : sym_count) ) : int_sym_count[0]; //2-s
    int_sym_count[2] = rx_bv[2] ? ( rxstartblock ? 2 : (rx_dv ? sym_count+3 : sym_count) ) : int_sym_count[1]; //4-s
    int_sym_count[3] = rx_bv[3] ? ( rxstartblock ? 3 : (rx_dv ? sym_count+4 : sym_count) ) : int_sym_count[2]; //4-s
    int_sym_count[4] = rx_bv[4] ? ( rxstartblock ? 4 : (rx_dv ? sym_count+5 : sym_count) ) : int_sym_count[3]; //8-s
    int_sym_count[5] = rx_bv[5] ? ( rxstartblock ? 5 : (rx_dv ? sym_count+6 : sym_count) ) : int_sym_count[4]; //8-s
    int_sym_count[6] = rx_bv[6] ? ( rxstartblock ? 6 : (rx_dv ? sym_count+7 : sym_count) ) : int_sym_count[5]; //8-s
    int_sym_count[7] = rx_bv[7] ? ( rxstartblock ? 7 : (rx_dv ? sym_count+8 : sym_count) ) : int_sym_count[6]; //8-s
end // int_sym_count_PROC

//
//detect TS
//
assign rx_ts_0        = rx_ts1_0 | rx_ts2_0;
assign rx_lnum_v      = rx_pad | rx_num_v; //link/lane number have to be PAD or valid number (>=0 and <=31)
assign dc_dis         = cfg_gen3_dc_balance_disable;
assign up             = cfg_upstream_port;

//eieos received in Recovery.RcvrLock.
//don't detect TS before eieos rcvd except Rcvry.Eq -> Rcvry.RcvrLock
always @(posedge core_clk or negedge core_rst_n) begin :ltssm_state_rcvry_eq_delay_PROC
    if (!core_rst_n) begin
        ltssm_state_rcvry_eq_d        <= #TP 0;
    end else begin
        ltssm_state_rcvry_eq_d        <= #TP ltssm_state_rcvry_eq;
    end
end // ltssm_state_rcvry_eq_delay_PROC

always @(posedge core_clk or negedge core_rst_n) begin : smlh_ltssm_in_rcvrylock_delay_PROC
    if (!core_rst_n) begin
        smlh_ltssm_in_rcvrylock_d <= #TP 0;
    end else begin
        smlh_ltssm_in_rcvrylock_d <= #TP smlh_ltssm_in_rcvrylock;
    end
end //smlh_ltssm_in_rcvrylock_delay_PROC

assign smlh_ltssm_in_rcvrylock_enter = smlh_ltssm_in_rcvrylock  & !smlh_ltssm_in_rcvrylock_d;

always @(posedge core_clk or negedge core_rst_n) begin : l_rlock_eies_rcvd_PROC
    if (!core_rst_n) begin
        latched_rlock_eies_rcvd <= #TP 0;
    end else begin
        // If RcvryLock entered and previous state is not an EQ state
        if ( smlh_ltssm_in_rcvrylock_enter && !ltssm_state_rcvry_eq_d)
            latched_rlock_eies_rcvd <= #TP 0;
        else if ( smlh_ltssm_in_rcvrylock ) begin
            if ( eie_det_i )
                latched_rlock_eies_rcvd <= #TP 1;
        end else begin
            latched_rlock_eies_rcvd <= #TP 1;
        end
    end
end //l_rlock_eies_rcvd_PROC

assign rlock_eies_rcvd = latched_rlock_eies_rcvd | ~smlh_ltssm_in_rcvrylock;

  localparam call_in_ts_width = 1 ;
wire  [NB2-1:0][call_in_ts_width-1:0]          pre_int_in_ts;
assign pre_int_in_ts[0] = call_in_ts(1'b1    , in_ts_d     , int_sym_count[0], rx_ts_0, rx_lnum_v[0], ts1_id[0], ts2_id[0], ints1, rx_rate_v[0], dc_dis, 1'b0, pv  , 1'b0); //byte0 is always valid
assign pre_int_in_ts[1] = call_in_ts(rx_bv[1], int_in_ts[0], int_sym_count[1], 1'b0   , rx_lnum_v[1], ts1_id[1], ts2_id[1], ints1, 1'b0        , dc_dis, up,   pv  , eqts[1]);
assign pre_int_in_ts[2] = call_in_ts(rx_bv[2], int_in_ts[1], int_sym_count[2], 1'b0   , rx_lnum_v[2], ts1_id[2], ts2_id[2], ints1, 1'b0        , dc_dis, 1'b0, pv  , 1'b0);
assign pre_int_in_ts[3] = call_in_ts(rx_bv[3], int_in_ts[2], int_sym_count[3], 1'b0   , 1'b0        , ts1_id[3], ts2_id[3], ints1, 1'b0        , dc_dis, 1'b0, pv  , eqts[3]);
assign pre_int_in_ts[4] = call_in_ts(rx_bv[4], int_in_ts[3], int_sym_count[4], 1'b0   , 1'b0        , ts1_id[4], ts2_id[4], ints1, rx_rate_v[4], 1'b0  , 1'b0, 1'b0, 1'b0);
assign pre_int_in_ts[5] = call_in_ts(rx_bv[5], int_in_ts[4], int_sym_count[5], 1'b0   , 1'b0        , ts1_id[5], ts2_id[5], ints1, 1'b0        , 1'b0  , 1'b0, 1'b0, 1'b0);
assign pre_int_in_ts[6] = call_in_ts(rx_bv[6], int_in_ts[5], int_sym_count[6], 1'b0   , 1'b0        , ts1_id[6], ts2_id[6], ints1, 1'b0        , dc_dis, 1'b0, pv  , 1'b0);
assign pre_int_in_ts[7] = call_in_ts(rx_bv[7], int_in_ts[6], int_sym_count[7], 1'b0   , 1'b0        , ts1_id[7], ts2_id[7], ints1, 1'b0        , dc_dis, 1'b0, pv  , eqts[7]);

assign int_in_ts[0] = !rx_err & ints & pre_int_in_ts[0][0];
assign int_in_ts[1] = !rx_err & ints & pre_int_in_ts[1][0];
assign int_in_ts[2] = !rx_err & ints & pre_int_in_ts[2][0];
assign int_in_ts[3] = !rx_err & ints & pre_int_in_ts[3][0];
assign int_in_ts[4] = !rx_err & ints & pre_int_in_ts[4][0];
assign int_in_ts[5] = !rx_err & ints & pre_int_in_ts[5][0];
assign int_in_ts[6] = !rx_err & ints & pre_int_in_ts[6][0];
assign int_in_ts[7] = !rx_err & ints & pre_int_in_ts[7][0];

//function to find TS OS
function automatic call_in_ts;
    input       rx_bv;          //byte valid
    input       pre_in_ts;      //previous symbol is TS's
    input [3:0] count;          //symbol count number
    input       rx_ts_0;        //current symbol is 0-symbol
    input       rx_l_num_v;     //link or lane number
    input       ts1_id;         //TS1 identifier
    input       ts2_id;         //TS2 identifier
    input       ints1;          //in TS1 window
    input       rx_rate_v;      //Rx data rate checked valid
    input       dc_dis;         //DC balance disabled
    input       up;             //Upstream port
    input       pv;             //parity valid, have a check at Sym 14/15
    input       eqts;           //8GT EQ TS2
begin
    if ( rx_bv==0 ) begin           //if byte invalid, keep previous symbol byte
        call_in_ts = pre_in_ts;
    end

    else case (count)
        4'b0000: begin
            call_in_ts = rx_ts_0;                                   //symbol 0 must be Start of TS1 or TS2
        end
        4'b0001: begin                                                  //check for Upstream port, no check downstream port (DP)
//            call_in_ts = up ? (rx_l_num_v & pre_in_ts) : pre_in_ts; //no check since 30-1-2015. USP makes sure Rx link#<=31 if gen3 support. Link number can be any value in DSP of receive side
            call_in_ts = pre_in_ts;                                 //Link number can be any value in DSP of receive side
        end
        4'b0010: begin
            call_in_ts = rx_l_num_v & pre_in_ts;                    //2nd Symbol must be PAD or valid lane number
        end
        4'b0011: begin
            call_in_ts = pre_in_ts;                                 //no check with symbol 3 as its value is 00h-ffh (N_FTS)
        end
        4'b0100: begin
            call_in_ts = rx_rate_v & pre_in_ts;                     //data rate must be 0001b, 0011b or 0111b, or gen5: 1111b
        end
        4'b0101: begin
            call_in_ts = pre_in_ts;                                 //no check with symbol 5 as its value can be anything (training control)
        end
        4'b0110: begin
            call_in_ts = pre_in_ts;                                 //symbol 6 can be any value
        end
        4'b0111: begin                                             //symbol 7 may be 8gt eq ts2 at gen3 rate if gen4 support
            if ( ints1 )begin                                          //TS1 window
                call_in_ts = pre_in_ts;
            end else begin
                call_in_ts = (ts2_id | eqts) & pre_in_ts;           //8gt eq ts2 can only be in Recovery at gen3 rate
            end
        end
        4'b1000, 4'b1001: begin                                    //symbol 8-9
            if ( ints1 )begin                                          //TS1 window
                call_in_ts = pre_in_ts;                             //no check for TS1 at gen3 rate
            end else begin                                                 //TS2 window
                call_in_ts = pre_in_ts & ts2_id;                    //have to be TS2 identifier for TS2 OS
            end
        end
        4'b1110, 4'b1111: begin                                    //Symbol 14-15
            if ( dc_dis ) begin                                    //DC balance disabled
                if ( ints1 ) begin                                     //TS1 window
                    call_in_ts = ts1_id & pv & pre_in_ts;           //have to be TS1 identifier
                end else begin                                             //TS2 window
                    call_in_ts = ts2_id & pre_in_ts;                //have to be TS2 identifier
                end
            end else begin                                         //if DC balance enabled
                if ( ints1 ) begin                                     //TS1 window
                    call_in_ts = pv & pre_in_ts;
                end else begin                                             //TS2 window
                    call_in_ts = pre_in_ts;
                end
            end
        end
        default: begin                                             //symbol 10-13
            if ( ints1 ) begin                                          //TS1 window
                call_in_ts = ts1_id & pre_in_ts;                    //have to be TS1 identifier
            end else begin                                                 //TS2 window
                call_in_ts = ts2_id & pre_in_ts;                    //have to be TS2 identifier
            end
        end
    endcase
end
endfunction

//
// TS received
//
//get TS pulse
assign int_ts1_rcvd_pulse = (int_sym_count[NB2-1]==4'b1111 & int_in_ts[NB2-1]) & ints1 & rx_dv;
assign int_ts2_rcvd_pulse = (int_sym_count[NB2-1]==4'b1111 & int_in_ts[NB2-1]) & ints2 & rx_dv;
assign int_ts_rcvd_pulse  = int_ts1_rcvd_pulse | int_ts2_rcvd_pulse;

always @(posedge core_clk or negedge core_rst_n) begin : ts12_pulse_seq_PROC
    if (!core_rst_n) begin
        smseq_ts1_rcvd_pulse  <= #TP 1'b0;
        smseq_ts2_rcvd_pulse  <= #TP 1'b0;
    end
    else begin
        smseq_ts1_rcvd_pulse  <= #TP int_ts1_rcvd_pulse & rlock_eies_rcvd;
        smseq_ts2_rcvd_pulse  <= #TP int_ts2_rcvd_pulse & rlock_eies_rcvd;
    end
end // ts12_pulse_seq_PROC

//
//ts_error
//
//error if not TS or eieos or skp or RxDataInvalid for compensation of SyncHeader or Clock Tolerance.
//or 1st TS symbol received & pre OS is TS OS & pre TS Symbols number is not 15.
//Max ~RxDataValid is two cycles within a Block.
//if rxerror (decode error) within inskp, ts_error.
assign rxdatainvld_pulse = !rx_dv & (rxdata_dv_dd | rxdata_dv_d); //DataInValid. If ~rx_dv longer than two cycles, rx_dv is not from RxDataInValid for compensation of SyncHeader or clock tolerance
assign int_ts_error  = (cfg_elastic_buffer_mode & ~rxaligned) ? 1 : (cfg_elastic_buffer_mode & ~rx_dv) ? 0 :
                       (!(&int_in_ts[NB-1:0] | ineie_i | (( !rx_err) & inskp_i) | (~cfg_elastic_buffer_mode & (in_ts_d & rxdatainvld_pulse)))
                       | ((rx_ts_0 | ineie_i | (!rx_err & inskp_i)) & in_ts_d & (sym_count != 15))); // previous TS was shorter than 16 symbols before TS, SKP, EIEOS


//
// update TS Symbol value when int_sym_count reaches the symbol number
//
always @( * ) begin : int_btv_PROC
    integer i;

    for (i=0; i<NB2; i=i+1) begin
        int_btv[i] = rx_dv & rx_bv[i];
    end
end // int_btv_PROC

always @( * ) begin : btv_PROC
    integer i;

    for (i=0; i<NB2; i=i+1) begin
        btv[i] = int_btv[i] & int_in_ts[i];
    end
end // btv_PROC

//don't use general design in order to reduce combinatorial logic.
always @( * ) begin : update_ts_sym_PROC
                     //symbol 0 can only be at byte slot 0
    dec_ts_sym[0]  = (btv[0] && int_sym_count[0]==0 ) ? rx_data[ 7: 0] : int_ts_sym[0];
                     //symbol 1 can only be at byte slot 0 or 1
    dec_ts_sym[1]  = (btv[0] && int_sym_count[0]==1 ) ? rx_data[ 7: 0] :
                     (btv[1] && int_sym_count[1]==1 ) ? rx_data[15: 8] : int_ts_sym[1];
                     //symbol 2 can only be at byte slot 0 or 2
    dec_ts_sym[2]  = (btv[0] && int_sym_count[0]==2 ) ? rx_data[ 7: 0] :
                     (btv[2] && int_sym_count[2]==2 ) ? rx_data[23:16] : int_ts_sym[2];
                     //symbol 3 can only be at byte slot 0, 1 or 3
    dec_ts_sym[3]  = (btv[0] && int_sym_count[0]==3 ) ? rx_data[ 7: 0] :
                     (btv[1] && int_sym_count[1]==3 ) ? rx_data[15: 8] :
                     (btv[3] && int_sym_count[3]==3 ) ? rx_data[31:24] : int_ts_sym[3];
                     //symbol 4 can only be at byte slot 0 or 4
    dec_ts_sym[4]  = (btv[0] && int_sym_count[0]==4 ) ? rx_data[ 7: 0] :
                     (btv[4] && int_sym_count[4]==4 ) ? rx_data[39:32] : int_ts_sym[4];
                     //symbol 5 can only be at byte slot 0, 1 or 5
    dec_ts_sym[5]  = (btv[0] && int_sym_count[0]==5 ) ? rx_data[ 7: 0] :
                     (btv[1] && int_sym_count[1]==5 ) ? rx_data[15: 8] :
                     (btv[5] && int_sym_count[5]==5 ) ? rx_data[47:40] : int_ts_sym[5];
                     //symbol 6 can only be at byte slot 0, 2 or 6
    dec_ts_sym[6]  = (btv[0] && int_sym_count[0]==6 ) ? rx_data[ 7: 0] :
                     (btv[2] && int_sym_count[2]==6 ) ? rx_data[23:16] :
                     (btv[6] && int_sym_count[6]==6 ) ? rx_data[55:48] : int_ts_sym[6];
                     //symbol 7 can only be at byte slot 0, 1 or 3 or 7
    dec_ts_sym[7]  = (btv[0] && int_sym_count[0]==7 ) ? rx_data[ 7: 0] :
                     (btv[1] && int_sym_count[1]==7 ) ? rx_data[15: 8] :
                     (btv[3] && int_sym_count[3]==7 ) ? rx_data[31:24] :
                     (btv[7] && int_sym_count[7]==7 ) ? rx_data[63:56] : int_ts_sym[7];
                     //symbol 8 can only be at byte slot 0
    dec_ts_sym[8]  = (btv[0] && int_sym_count[0]==8 ) ? rx_data[ 7: 0] : int_ts_sym[8];
                     //symbol 9 can only be at byte slot 0 or 1
    dec_ts_sym[9]  = (btv[0] && int_sym_count[0]==9 ) ? rx_data[ 7: 0] :
                     (btv[1] && int_sym_count[1]==9 ) ? rx_data[15: 8] : int_ts_sym[9];
                     //symbol 10 can only be at byte slot 0 or 2
    dec_ts_sym[10] = (btv[0] && int_sym_count[0]==10) ? rx_data[ 7: 0] :
                     (btv[2] && int_sym_count[2]==10) ? rx_data[23:16] : int_ts_sym[10];
                     //symbol 11 can only be at byte slot 0, 1 or 3
    dec_ts_sym[11] = (btv[0] && int_sym_count[0]==11) ? rx_data[ 7: 0] :
                     (btv[1] && int_sym_count[1]==11) ? rx_data[15: 8] :
                     (btv[3] && int_sym_count[3]==11) ? rx_data[31:24] : int_ts_sym[11];
                     //symbol 12 can only be at byte slot 0 or 4
    dec_ts_sym[12] = (btv[0] && int_sym_count[0]==12) ? rx_data[ 7: 0] :
                     (btv[4] && int_sym_count[4]==12) ? rx_data[39:32] : int_ts_sym[12];
                     //symbol 13 can only be at byte slot 0, 1 or 5
    dec_ts_sym[13] = (btv[0] && int_sym_count[0]==13) ? rx_data[ 7: 0] :
                     (btv[1] && int_sym_count[1]==13) ? rx_data[15: 8] :
                     (btv[5] && int_sym_count[5]==13) ? rx_data[47:40] : int_ts_sym[13];
                     //symbol 14 can only be at byte slot 0, 2 or 6
    dec_ts_sym[14] = (btv[0] && int_sym_count[0]==14) ? rx_data[ 7: 0] :
                     (btv[2] && int_sym_count[2]==14) ? rx_data[23:16] :
                     (btv[6] && int_sym_count[6]==14) ? rx_data[55:48] : int_ts_sym[14];
                     //symbol 15 can only be at byte slot 0, 1 or 3 or 7
    dec_ts_sym[15] = (btv[0] && int_sym_count[0]==15) ? rx_data[ 7: 0] :
                     (btv[1] && int_sym_count[1]==15) ? rx_data[15: 8] :
                     (btv[3] && int_sym_count[3]==15) ? rx_data[31:24] :
                     (btv[7] && int_sym_count[7]==15) ? rx_data[63:56] : int_ts_sym[15];
end // update_ts_sym_PROC

always @( * ) begin : pv_ts_sym_PROC
                    //symbol 6 can only be at byte slot 0, 2 or 6
    pv_ts_sym[6]  = (int_btv[0] && int_sym_count[0]==6 ) ? rx_data[ 7: 0] :
                    (int_btv[2] && int_sym_count[2]==6 ) ? rx_data[23:16] :
                    (int_btv[6] && int_sym_count[6]==6 ) ? rx_data[55:48] : int_ts_sym[6];
                    //symbol 7 can only be at byte slot 0, 1 or 3 or 7
    pv_ts_sym[7]  = (int_btv[0] && int_sym_count[0]==7 ) ? rx_data[ 7: 0] :
                    (int_btv[1] && int_sym_count[1]==7 ) ? rx_data[15: 8] :
                    (int_btv[3] && int_sym_count[3]==7 ) ? rx_data[31:24] :
                    (int_btv[7] && int_sym_count[7]==7 ) ? rx_data[63:56] : int_ts_sym[7];
                    //symbol 8 can only be at byte slot 0
    pv_ts_sym[8]  = (int_btv[0] && int_sym_count[0]==8 ) ? rx_data[ 7: 0] : int_ts_sym[8];
                    //symbol 9 can only be at byte slot 0 or 1
    pv_ts_sym[9]  = (int_btv[0] && int_sym_count[0]==9 ) ? rx_data[ 7: 0] :
                    (int_btv[1] && int_sym_count[1]==9 ) ? rx_data[15: 8] : int_ts_sym[9];
end // pv_ts_sym_PROC

//
//concatenation of symbols {9,8,7,6} and do parity check
//
//break timing, sym6,7 must not be at the same cycle of sym8,9
always @(posedge core_clk or negedge core_rst_n) begin : parity_bit_sym_6_7_PROC
    if (!core_rst_n) begin
        parity_sym_6_7 <= #TP 0;
    end else begin
        parity_sym_6_7 <= #TP (^{pv_ts_sym[7], pv_ts_sym[6]});
    end
end //parity_bit_sym_6_7_PROC

//use combinational pv_ts_sym* as TS is received at the same cycle when Sym 8/9 detected for 8s
//parity_info is 16 bits, so pv_ts_sym[9][7] is not in parity_info.
assign parity_info = {pv_ts_sym[9][6:0], pv_ts_sym[8], parity_sym_6_7};

//parity check
assign pv = (^parity_info == pv_ts_sym[9][7]);

//
//persistency count
//
//smseq_ts_rcvd_pcnt - special received TS matching Tx, smseq_ts_rcvd_mtx_pcnt - match Tx TS. smseq_ts_rcvd_cond_pcnt with conditions
assign xmtbyte_eieos_skip_sent = xmtbyte_eies_sent || xmtbyte_skip_sent;

always @( * ) begin : sym_diff_bus_PROC
    integer i;
    for ( i=1; i<11; i=i+1 ) begin
        sym_diff_bus[i] = (int_ts_sym[i] != dec_ts_sym[i]);
    end
end // sym_diff_bus_PROC

assign any_sym_diff = |sym_diff_bus;

always @(posedge core_clk or negedge core_rst_n) begin : latched_link_any_8_ts1_spd_chg_1_rcvd_PROC
    if ( ~core_rst_n ) begin
        latched_link_any_8_ts1_spd_chg_1_rcvd <= #TP 0;
    end else if ( ~smlh_ltssm_in_rcvrylock ) begin
        latched_link_any_8_ts1_spd_chg_1_rcvd <= #TP 0;
    end else if ( int_directed_speed_change ) begin
        latched_link_any_8_ts1_spd_chg_1_rcvd <= #TP 1;
    end
end // latched_link_any_8_ts1_spd_chg_1_rcvd_PROC

assign speed_change_is_1 = int_directed_speed_change | latched_link_any_8_ts1_spd_chg_1_rcvd;

// for gen3/4, sym10-13 are ts identifier. if not, ts_error. So only need to check sym1-10.
always @(posedge core_clk or negedge core_rst_n) begin : smseq_ts_rcvd_pcnt_PROC
    integer i;

    if ( ~core_rst_n ) begin
        smseq_ts_rcvd_pcnt      <= #TP 0;
        smseq_ts_rcvd_mtx_pcnt  <= #TP 0;
        smseq_ts_rcvd_cond_pcnt <= #TP 0;
        latched_sym_updated     <= #TP 0;
    end else if ( int_ts_error || ~rlock_eies_rcvd || smlh_keep_rcvrylock_lane ) begin //clear when a ts_error or a state transition is prohibited
        smseq_ts_rcvd_pcnt      <= #TP 0;
        smseq_ts_rcvd_mtx_pcnt  <= #TP 0;
        smseq_ts_rcvd_cond_pcnt <= #TP 0;
        latched_sym_updated     <= #TP 0;
    end else if ( ltssm_clear ) begin //clear when a state transition
        if ( int_ts_rcvd_pulse ) begin
            smseq_ts_rcvd_pcnt      <= #TP 1;
            smseq_ts_rcvd_cond_pcnt <= #TP 1;
            smseq_ts_rcvd_mtx_pcnt  <= #TP 1;
            latched_sym_updated     <= #TP 0;
        end else begin
            smseq_ts_rcvd_pcnt      <= #TP 0;
            smseq_ts_rcvd_cond_pcnt <= #TP 0;
            smseq_ts_rcvd_mtx_pcnt  <= #TP 0;
            if ( any_sym_diff )
                latched_sym_updated <= #TP 1;
        end

        if ( ltssm_lane_flip_ctrl_chg_pulse )
            smseq_ts_rcvd_mtx_pcnt <= #TP 0; // if lane flip changes, clear the count to re-start count after the flip
    end else begin
        if ( any_sym_diff ) begin //if any symbol difference
            if ( int_ts_rcvd_pulse ) begin //and at the end of a TS
                if ( speed_change_is_1 )
                    smseq_ts_rcvd_pcnt <= #TP 1;
                else
                    smseq_ts_rcvd_pcnt <= #TP 0;

                smseq_ts_rcvd_mtx_pcnt <= #TP 1; //xmtbyte_eieos_skip_sent ? 0 : 1;
                latched_sym_updated    <= #TP 0;
            end else
            begin
                latched_sym_updated    <= #TP 1; //latched until ts_rcvd at the end of the TS
//                if ( smseq_ts_rcvd_mtx_pcnt > 0 ) //when xmtbyte_eieos_skip_sent, -1 because no TS transmitted
//                    smseq_ts_rcvd_mtx_pcnt <= #TP smseq_ts_rcvd_mtx_pcnt - (xmtbyte_eieos_skip_sent ? 1 : 0);
            end
        end else if ( int_ts_rcvd_pulse ) begin //at the end of a TS
            if ( latched_sym_updated ) begin //if any symbol updated (difference)
                if ( speed_change_is_1 )
                    smseq_ts_rcvd_pcnt <= #TP 1;
                else
                    smseq_ts_rcvd_pcnt <= #TP 0;

                smseq_ts_rcvd_mtx_pcnt <= #TP 1; //xmtbyte_eieos_skip_sent ? 0 : 1;
                latched_sym_updated    <= #TP 0;
            end else begin //no difference, increment until 8
                if ( speed_change_is_1 )
                    smseq_ts_rcvd_pcnt <= #TP (smseq_ts_rcvd_pcnt < 8) ? smseq_ts_rcvd_pcnt + 1 : smseq_ts_rcvd_pcnt;
                else
                    smseq_ts_rcvd_pcnt <= #TP 0;

                smseq_ts_rcvd_mtx_pcnt <= #TP (smseq_ts_rcvd_mtx_pcnt < 8) ? smseq_ts_rcvd_mtx_pcnt + 1 : smseq_ts_rcvd_mtx_pcnt; //(smseq_ts_rcvd_mtx_pcnt < 8) && ~xmtbyte_eieos_skip_sent ? smseq_ts_rcvd_mtx_pcnt + 1 : smseq_ts_rcvd_mtx_pcnt;
                latched_sym_updated    <= #TP 0;
            end
        end //else begin // end else if
//            if ( smseq_ts_rcvd_mtx_pcnt > 0 && xmtbyte_eieos_skip_sent )
//                smseq_ts_rcvd_mtx_pcnt <= #TP smseq_ts_rcvd_mtx_pcnt - 1;
//        end // end else begin

        if ( (smlh_ltssm_in_rcvrylock || ltssm_in_cfglinkwdstart || ltssm_in_l0 || ltssm_in_l123sendeidle || ltssm_in_l0s) && int_ts_rcvd_pulse ) //for L0, if receive 2 TSs (not need persistency), ltssm move to Recovery
            smseq_ts_rcvd_cond_pcnt <= #TP (smseq_ts_rcvd_cond_pcnt < 3) ? smseq_ts_rcvd_cond_pcnt + 1 : smseq_ts_rcvd_cond_pcnt;

        if ( ltssm_lane_flip_ctrl_chg_pulse )
            smseq_ts_rcvd_mtx_pcnt <= #TP 0; // if lane flip changes, clear the count to re-start count after the flip
    end // end else begin
end // smseq_ts_rcvd_pcnt_PROC


always @( * ) begin : smseq_ts_rcvd_s6s9_pcnt_PROC
    smseq_ts_rcvd_s6s9_pcnt = smseq_ts_rcvd_mtx_pcnt; // smseq_ts_rcvd_pcnt;
end // smseq_ts_rcvd_s6s9_pcnt_PROC

//
//detect sds rcvd on all active lanes to move from L0s to L0
//
always @(posedge core_clk or negedge core_rst_n) begin : sds_detect_PROC
    if (!core_rst_n) begin
        sds_rcvd         <= #TP 0;
    end else if ( ltssm_clear || !insds ) begin
        sds_rcvd         <= #TP 0;
    end else if ( !rx_dv ) begin
        sds_rcvd <= #TP sds_rcvd;
    end else begin
        if ( deskew_data_sds_sym_0 ) begin
            sds_rcvd <= #TP 1;
        end else if ( !deskew_data_sds_sym_n || !sds_rcvd ) begin
            sds_rcvd <= #TP 0;
        end
    end
end // sds_detect_PROC
assign sds_rcvd_i = ( deskew_data_sds_sym_n & (int_sym_count[NB2-1] == 4'b1111) & sds_rcvd & rx_dv );
//
//latch TS Symbols and other signals used for the other blocks
//
always @(posedge core_clk or negedge core_rst_n) begin : latch_ts_symbol_other_signal_PROC
    integer i,j;

    if (!core_rst_n) begin
        in_ts_d              <= #TP 0;
        rxdata_dv_d          <= #TP 0;
        rxdata_dv_dd         <= #TP 0;
        sym_count            <= #TP 0;
        ts_error             <= #TP 0;
        inskip_rcv           <= #TP 0;
        ts1_rcvd             <= #TP 0;
        ts2_rcvd             <= #TP 0;
        eies_rcvd_pulse      <= #TP 0;

        for ( j=1; j<=9; j=j+1 ) begin
            int_ts_sym_rcvd[j] <= #TP 0;
        end

        for ( i=0; i<16; i=i+1 ) begin
            int_ts_sym[i]  <= #TP 0;
        end //for

    end else begin
        //if DataSkip, we have to delay one more cycle
        in_ts_d              <= #TP int_in_ts[NB-1] ? 1 : (rxdatainvld_pulse ? in_ts_d : 0); //extend to reach the first valid symbol of the next clock cycle
        sym_count            <= #TP int_sym_count[NB-1];
        rxdata_dv_d          <= #TP rx_dv;
        rxdata_dv_dd         <= #TP rxdata_dv_d;
        ts_error             <= #TP int_ts_error;
        inskip_rcv           <= #TP !rx_err & inskp_i;
        ts1_rcvd             <= #TP !(int_ts_error | (int_ts2_rcvd_pulse)) & (int_ts1_rcvd_pulse | ts1_rcvd);
        ts2_rcvd             <= #TP !(int_ts_error | (int_ts1_rcvd_pulse)) & (int_ts2_rcvd_pulse | ts2_rcvd);
        eies_rcvd_pulse      <= #TP eie_det_i;

        if ( int_ts_error ) begin
            for ( j=1; j<=9; j=j+1 ) begin
                int_ts_sym_rcvd[j] <= #TP 0;
            end
        end else if ( int_ts_rcvd_pulse ) begin // have to align to ts_rcvd_pulse
            for ( j=1; j<=9; j=j+1 ) begin
                int_ts_sym_rcvd[j] <= #TP dec_ts_sym[j];
            end
        end

        //latch TS symbol once the symbol is received
//        if ( int_ts_error ) begin
//            for ( i=0; i<16; i=i+1 ) begin
//                int_ts_sym[i]      <= #TP 0;
//            end // for
//        end else begin
            for ( i=0; i<16; i=i+1 ) begin
                int_ts_sym[i]      <= #TP dec_ts_sym[i];
            end // for
//        end

        if ( smlh_ts_spd_chg_rcvd_clr ) begin // clear latched speed_change bit after speed change
            int_ts_sym_rcvd[4][7] <= #TP 1'b0;
            int_ts_sym[4][7]      <= #TP 1'b0;
        end
    end
end // latch_ts_symbol_other_signal_PROC

//get link#/lane# = PAD
always @(posedge core_clk or negedge core_rst_n) begin : ts_link_lane_num_is_k237_PROC
    if (!core_rst_n) begin
        ts_link_num_is_k237_i  <= #TP 0;
        ts_lane_num_is_k237_i  <= #TP 0;
//    end else if ( (!smlh_link_in_training & smlh_link_up) || int_ts_error ) begin
//        ts_link_num_is_k237_i  <= #TP 0;
//        ts_lane_num_is_k237_i  <= #TP 0;
    end else begin
        ts_link_num_is_k237_i  <= #TP (rx_dv & int_sym_count[0]==1 & rx_bv[0] & int_in_ts[0]) ? (rx_data[ 7: 0] == `K237_8B) :
                                      (rx_dv & int_sym_count[1]==1 & rx_bv[1] & int_in_ts[1]) ? (rx_data[15: 8] == `K237_8B) : ts_link_num_is_k237_i;
        ts_lane_num_is_k237_i  <= #TP (rx_dv & int_sym_count[0]==2 & rx_bv[0] & int_in_ts[0]) ? (rx_data[ 7: 0] == `K237_8B) :
                                      (rx_dv & int_sym_count[2]==2 & rx_bv[2] & int_in_ts[2]) ? (rx_data[23:16] == `K237_8B) : ts_lane_num_is_k237_i;
    end
end // ts_link_lane_num_is_k237_PROC

always @(posedge core_clk or negedge core_rst_n) begin : ts_link_lane_num_is_k237_update_PROC
    if (!core_rst_n) begin
        ts_link_num_is_k237  <= #TP 0;
        ts_lane_num_is_k237  <= #TP 0;
    end else if ( int_ts_rcvd_pulse ) begin
        ts_link_num_is_k237  <= #TP ts_link_num_is_k237_i;
        ts_lane_num_is_k237  <= #TP ts_lane_num_is_k237_i;
    end
end // ts_link_lane_num_is_k237_update_PROC

// Output assignments
assign smseq_ts_info             = {int_ts_sym_rcvd[7],int_ts_sym_rcvd[6],int_ts_sym_rcvd[5],int_ts_sym_rcvd[4],int_ts_sym_rcvd[3],int_ts_sym_rcvd[2],int_ts_sym_rcvd[1]};
assign smseq_ts_lanen_linkn_pad  = {ts_lane_num_is_k237,ts_link_num_is_k237};
assign smseq_eqts_info           = {int_ts_sym_rcvd[9],int_ts_sym_rcvd[8],int_ts_sym_rcvd[7],int_ts_sym_rcvd[6]};
assign smseq_ts1_rcvd            = ts1_rcvd & rlock_eies_rcvd;
assign smseq_ts2_rcvd            = ts2_rcvd & rlock_eies_rcvd;
assign smseq_ts_error            = ts_error;
assign smseq_sds_rcvd            = sds_rcvd_i;
assign smseq_ineies_rcv          = eies_rcvd_pulse;
assign smseq_inskip_rcv          = inskip_rcv;

//
// count rxdata==0 errors in rx compliance pattern and send back thru SKP OS in modified compliance pattern
//
//data block detection
assign ltssm_in_compliance = smlh_ltssm_in_compliance;
assign int_rxdatablock = (rx_dv && rxstartblock && (rxsyncheader == `SYNC_DATA_BLOCK));

always @(posedge core_clk or negedge core_rst_n) begin : rxdatablock_delay_PROC
    if (!core_rst_n) begin
        rxdatablock_d         <= #TP 0;
    end else begin
        if (~ltssm_in_compliance)
            rxdatablock_d     <= #TP 0;
        else if (rx_dv && rxstartblock)
            rxdatablock_d     <= #TP rxsyncheader == `SYNC_DATA_BLOCK;
    end
end // rxdatablock_delay_PROC

assign rxdatablock = int_rxdatablock | (!rxstartblock & rxdatablock_d);

//error count increment
always @(*) begin : symbol_error_PROC
    sym_error = 0;
    sym_error = {
        active_nb[3] & rx_dv & rxdatablock & (rxdata[63:56] != 8'h00),
        active_nb[3] & rx_dv & rxdatablock & (rxdata[55:48] != 8'h00),
        active_nb[3] & rx_dv & rxdatablock & (rxdata[47:40] != 8'h00),
        active_nb[3] & rx_dv & rxdatablock & (rxdata[39:32] != 8'h00),
        |active_nb[3:2] & rx_dv & rxdatablock & (rxdata[31:24] != 8'h00),
        |active_nb[3:2] & rx_dv & rxdatablock & (rxdata[23:16] != 8'h00),
        |active_nb[3:1] & rx_dv & rxdatablock & (rxdata[15:8] != 8'h00),
        |active_nb & rx_dv & rxdatablock & (rxdata[7:0] != 8'h00)
                };
end // symbol_error_PROC

//have to latch rx_dv as rx_dv contains DataSkip which can make rx_dv low
//so cannot directly use rx_dv to indicate Locked
always @(posedge core_clk or negedge core_rst_n) begin : l_rxdata_dv_PROC
    if (!core_rst_n)
        latched_rxdata_dv <= #TP 0;
    else if (!ltssm_in_compliance)
        latched_rxdata_dv <= #TP 0;
    else if (rx_dv && (current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE))
        latched_rxdata_dv <= #TP 1;
end // l_rxdata_dv_PROC
assign sym_error_count = {{(AW-1){1'b0}},sym_error[0]} + {{(AW-1){1'b0}},sym_error[1]} + {{(AW-1){1'b0}},sym_error[2]} + {{(AW-1){1'b0}},sym_error[3]} +
                         {{(AW-1){1'b0}},sym_error[4]} + {{(AW-1){1'b0}},sym_error[5]} + {{(AW-1){1'b0}},sym_error[6]} + {{(AW-1){1'b0}},sym_error[7]}
                         ;
always @(posedge core_clk or negedge core_rst_n) begin : smseq_err_count_PROC
    if (!core_rst_n)
        smseq_error_count <= #TP 0;
    else if (~ltssm_in_compliance) //reset to 0 when entry to Compliance
        smseq_error_count <= #TP 0;
    //if locked (rx_dv=1), lock bit smseq_error_count[7] = 1
    else if (latched_rxdata_dv) begin
        smseq_error_count[7] <= #TP 1;

        if ((smseq_error_count[6:0] + sym_error_count) >= 127) //increments until 127 (saturation)
            smseq_error_count[6:0] <= #TP 127;
        else
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
            smseq_error_count[6:0] <= #TP smseq_error_count[6:0] + sym_error_count;
// spyglass enable_block W164a
    end
end // smseq_err_count_PROC

wire fts_header;
assign fts_header = rx_dv & (rx_data[7:0]==`FTS_SYM_0) & rxstartblock & (rxsyncheader=='b01);

always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        smseq_fts_rcvd_pulse  <= #TP 1'b0;
    end
    else begin
        smseq_fts_rcvd_pulse  <= #TP fts_header;
    end
end

wire int_rxosblock;
wire rxosblock;
reg  rxosblock_d;

assign int_rxosblock = (rx_dv && rxstartblock && (rxsyncheader == `SYNC_OS_BLOCK));

always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        rxosblock_d         <= #TP 0;
    end else begin
        if (~ltssm_in_compliance)
            rxosblock_d     <= #TP 0;
        else if (rx_dv && rxstartblock)
            rxosblock_d     <= #TP rxsyncheader == `SYNC_OS_BLOCK;
    end
end

assign rxosblock = int_rxosblock | (!rxstartblock & rxosblock_d);
// received SKP OS's error status
// PIPE8bit:
// Byte0: SKP_END_SYM - SKP_SYM_0 - ERR
//
// PIPE16bit:
// Byte0: SKP_END_SYM -> ERR
// Byte1: SKP_SYM_0   -> -
//
// PIPE32bit:
// Byte0: SKP_END_SYM
// Byte1: SKP_SYM_0
// Byte2: ERR
// Byte3: -
// 
// PIPE64bit:
// (1)
// Byte0: SKP_END_SYM
// Byte1: SKP_SYM_0
// Byte2: ERR
// Byte3: -
// 
// (2)
// Byte0-3: -
// Byte4: SKP_END_SYM
// Byte5: SKP_SYM_0
// Byte6: ERR
// Byte7: -
reg [1:0]   rx_mcs_flag;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        rx_mcs_flag <= #TP 0;
        smseq_mcs_sts <= #TP 0;
    end else if(smlh_ltssm_in_compliance && rx_dv && rxosblock) begin
        if(rx_bv[7]) begin
            if(rxdata[39:32]==`SKP_END_SYM && rxdata[47:40]==`SKP_SYM_0) begin
                smseq_mcs_sts <= #TP rxdata[55:48];
            end
        end else
        if(rx_bv[0]) begin
            if(rxdata[7:0]==`SKP_END_SYM) begin
                rx_mcs_flag[0] <= #TP 1'b1;
            end else if(rx_mcs_flag[0]) begin
                rx_mcs_flag[0] <= #TP 1'b0;
                if(rxdata[7:0]==`SKP_SYM_0) begin
                    rx_mcs_flag[1] <= #TP 1'b1;
                end
            end else  begin
                rx_mcs_flag <= #TP 0;
            end

            if(rx_mcs_flag[1]) begin
                smseq_mcs_sts <= #TP rxdata[7:0];
            end
        end
    end

// smseq_ts_debug_info - TS symbol {9,8,7,6,5,4,2,1}
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        smseq_ts_debug_info <= #TP 64'h0;
    end else if(smseq_ts1_rcvd_pulse|| smseq_ts2_rcvd_pulse) begin
        smseq_ts_debug_info <= #TP {int_ts_sym_rcvd[9],int_ts_sym_rcvd[8],int_ts_sym_rcvd[7],int_ts_sym_rcvd[6],
                                    int_ts_sym_rcvd[5],int_ts_sym_rcvd[4],int_ts_sym_rcvd[2],int_ts_sym_rcvd[1]};
    end



endmodule
