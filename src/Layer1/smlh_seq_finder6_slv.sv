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
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/smlh_seq_finder6_slv.sv#5 $
// -------------------------------------------------------------------------
// --- Module Description: Receive MAC layer Sequence Finder for gen6
// --- This module performs the receive special sequence detect as well as
// receive link in training status. This module monitors the PHY rx data to
// extract the all special ordered set defined in PCIExpress spec for gen6.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"


 module smlh_seq_finder6_slv
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
    parameter   NB                = `CX_NB,                      // Number of symbols (bytes) per clock cycle
    parameter   NB2               = ((`CX_NB>=16) ? 16:8),       // Number of internal symbols (bytes) per clock cycle
    parameter   SYM               = ((`CX_NB>=32) ? 32:16),      // Number of OS symbols
    parameter   AW                = `CX_ANB_WD,                  // Width of the active number of bytes
    parameter   RXSB_WD           = `CX_MAC_SB_WD,               // Width of the start block
    parameter   RXSH_WD           = `CX_MAC_SH_WD,               // Width of the sync header
    parameter   DCB_WD            = (NB>=8 ? NB/8 : 1),          // Width of the DC balance info
    parameter   TP                = `TP,                         // Clock to Q delay (simulator insurance)
    parameter   EQTS_WD           = 32,                          // bit width of concantenation of TS symbols {9,8,7,6}
    parameter   TSFD_WD           = `CX_TS_FIELD_CONTROL_WD,     // sym7,6,5,4,3,2,1
    parameter   EQTS_HALF_WD      = ((`CX_NB==16) ? 32:16)       // bit width of concantenation of TS symbols {9,8} or {7,6} or {9,8,7,6}
)

                             (
    input                   core_clk,
    input                   core_rst_n,
    input                   cfg_upstream_port,
    input                   cfg_elastic_buffer_mode,
    input                   ltssm_lane_flip_ctrl_chg_pulse,     // lane flip control update pulse
    input   [AW-1:0]        active_nb,
    input   [AW-1:0]        active_nb_gen34,
    input   [2:0]           current_data_rate,
    input   [(NB*8)-1:0]    rxdata,
    input                   rxdata_dv,
    input                   rxaligned,
    input   [RXSB_WD-1:0]   rxstartblock,
    input   [RXSB_WD-1:0]   inskp,
    input   [RXSH_WD-1:0]   rxsyncheader,
    input   [NB-1:0]        rxerror,
    input   [DCB_WD-1:0]    rxdata_dcb,
    input                   rmlh_deskew_ds,
    input                   smlh_ts_spd_chg_rcvd_clr,
    input                   ltssm_clear,                         // used to clear TS persistency count on a ltssm state transition
    input                   smlh_ltssm_in_compliance,
    input   ltssm_state_e   smlh_ltssm_state,
    input                   int_directed_speed_change,
    input                   smlh_keep_rcvrylock_lane,
    output  [TSFD_WD-1:0]   smseq_ts_info,
    output  [1:0]           smseq_ts_lanen_linkn_pad,
    output  reg [3:0]       smseq_ts_rcvd_mtx_pcnt,
    output  reg [3:0]       smseq_ts_rcvd_pcnt,
    output  reg [1:0]       smseq_ts_rcvd_cond_pcnt,             //persistency count for rcvd TS with conditions
    output                  smseq_ts_error,
    output reg [7:0]        smseq_error_count,                   // got from Modified Compliance Pattern
    output reg              smseq_inskip_rcv,
    output                  smseq_ts0_rcvd,
    output                  smseq_ts1_rcvd,
    output                  smseq_ts2_rcvd,
    output                  smseq_ts0_rcvd_pulse_o,
    output                  smseq_ts1_rcvd_pulse_o,
    output                  smseq_ts2_rcvd_pulse_o,
    output                  smseq_ineies_rcv,                   // Electrical Idle Exit level signal
    output                  smseq_sds_rcvd,                     // SDS received. need it for Rx_L0s.FTS to L0 transition as per spec *29Sep09.pdf
    output                  smseq_invalid_os,                   // Invalid os flag for Flit Error Logging Capability
    output                  smseq_os_corrected,                 // OS corrected flag for Flit Error Logging Capability
    output  [EQTS_WD-1:0]   smseq_eqts_info                      // EQ TS content of symbols {9,8,7,6}
);

localparam IDLE = 2'b00;
localparam VALD = 2'b01; //valid ts/eieos/skp
localparam NRDV = 2'b10; //~RxDataValid
localparam ERRR = 2'b11; //TS Error

localparam B0_8 = ((`CX_NB>=32) ? 4 : 2);

// IO declaration
reg  [3:0]               ts_rcvd_mtx_pcnt;
reg  [3:0]               ts_rcvd_pcnt;
reg  [1:0]               ts_rcvd_cond_pcnt;             //persistency count for rcvd TS with conditions
reg                      priority_shf_sel;
reg                      latched_link_any_8_ts1_spd_chg_1_rcvd;
wire                     speed_change_is_1;
wire                     smlh_ltssm_in_rcvrylock;
wire                     ltssm_state_rcvry_eq;
wire [RXSB_WD-1:0]       inskp_i;
wire [RXSB_WD-1:0]       ineie_i;
wire [RXSB_WD*2-1:0]     ineie_1_2_part;
wire [RXSB_WD-1:0]       eie_det_i;
reg  [RXSB_WD-1:0]       inskip_rcv;
reg  [RXSB_WD-1:0]       eies_rcvd_pulse;
reg  [RXSB_WD-1:0]       smseq_ts0_rcvd_pulse;
reg  [RXSB_WD-1:0]       smseq_ts1_rcvd_pulse;
reg  [RXSB_WD-1:0]       smseq_ts2_rcvd_pulse;
reg                      latched_rlock_eies_rcvd;
wire                     rlock_eies_rcvd;
reg                      smlh_ltssm_in_rcvrylock_d;
reg                      ltssm_state_rcvry_eq_d;
wire                     smlh_ltssm_in_rcvrylock_enter;
wire                     ltssm_in_cfglinkwdstart;
wire                     ltssm_in_l0;
wire                     ltssm_in_l0s;
wire                     ltssm_in_l123sendeidle;
reg                      rxdata_dv_d;
reg                      rxdata_dv_dd;
wire                     rxdatainvld_pulse;
reg                      in_ts_d;
reg                      in_sds_d;
reg                      in_ts0_d;
reg   [7:0]              int_ts_sym[0:SYM-1];
reg   [7:0]              pre_ts_sym[0:SYM-1];
reg   [7:0]              dec_ts_sym[0:SYM-1];
reg   [7:0]              int_ts_sym_rcvd[1:12]; // array[6:0] = Sym6-1, array[12:7] = Sym14-9
reg   [7:0]              in6_ts_sym_rcvd[1:12]; // array[6:0] = Sym6-1, array[12:7] = Sym14-9
reg   [RXSB_WD-1:0]      ts_link_num_is_k237_1;
reg   [RXSB_WD-1:0]      ts_lane_num_is_k237_1;
reg   [RXSB_WD-1:0]      ts_link_num_is_k237_2;
reg   [RXSB_WD-1:0]      ts_lane_num_is_k237_2;
reg   [RXSB_WD-1:0]      ts_link_num_is_k237_i1;
reg   [RXSB_WD-1:0]      ts_lane_num_is_k237_i1;
reg   [RXSB_WD-1:0]      ts_link_num_is_k237_i2;
reg   [RXSB_WD-1:0]      ts_lane_num_is_k237_i2;
reg   [3:0]              sym_count;
reg                      ts_error;
reg  [RXSB_WD-1:0]       ts0_rcvd;
reg  [RXSB_WD-1:0]       ts1_rcvd;
reg  [RXSB_WD-1:0]       ts2_rcvd;
wire                     sds_rcvd_i;
reg   [7:0]              ts_ep[0:NB-1];   // even parity from previous clock for ts
reg   [7:0]              in_ts_ep;
reg   [3:0]              int_sym_count[0:NB-1];
wire  [NB-1:0]           int_in_ts0;
wire  [NB-1:0]           int_in_ts;
wire  [NB-1:0]           int_in_sds;
wire                     int_ts_error;
reg   [1:0]              ts_err_state, next_ts_err_state;
reg                      latched_os_rcvd;
reg   [NB*8-1:0]         rx_data;
reg   [RXSB_WD-1:0]      rx_err;
reg                      rx_dv;
wire  [NB-1:0]           rx_bv;
reg   [NB-1:0]           rx_ts0_0;
reg   [NB-1:0]           rx_ts1_0;
reg   [NB-1:0]           rx_ts2_0;
reg   [NB-1:0]           e0;        //Even bit 0
reg   [NB-1:0]           rc;        //Received Dc balance
reg   [NB-1:0]           r0;        //Received Dc balance for TS0
reg   [NB-1:0]           ep;        //Even Parity
wire  [RXSB_WD-1:0]      rxosblock;
reg   [RXSB_WD-1:0]      rx_ts0;
reg   [RXSB_WD-1:0]      rx_ts1;
reg   [RXSB_WD-1:0]      rx_ts2;
reg   [NB-1:0]           rx_sds_id;
reg   [NB-1:0]           sds_bd; //sds body
wire  [NB-1:0]           rx_ts_0;
wire  [RXSB_WD-1:0]      ints;
reg   [NB-1:0]           btv;       //byte valid
reg   [NB-1:0]           int_btv;   //byte valid

wire  [RXSB_WD-1:0]      int_rxosblock;
reg   [SYM-1:0]          eieos_byte_rcvd;
reg   [B0_8-1:0]         eieos_byte_0_8; // 0: sym0 for 1st OS, 1: sym8 for 1st OS, 2: sym0 for 2nd OS, 3: sym8 for 2nd OS
reg   [B0_8-1:0]         eieos_byte_0_8_i; // 0: sym0 for 1st OS, 1: sym8 for 1st OS, 2: sym0 for 2nd OS, 3: sym8 for 2nd OS
reg   [B0_8-1:0]         eieos_byte_0_8_d; // 0: sym0 for 1st OS, 1: sym8 for 1st OS, 2: sym0 for 2nd OS, 3: sym8 for 2nd OS
reg   [SYM-1:0]          eieos_byte_rcvd_i;
reg   [SYM-1:0]          eieos_byte_rcvd_d;
wire  [SYM-1:0]          eieos_ab_rcvd;
wire  [RXSB_WD-1:0]      eieos_rcvd_ge_5;
reg   [SYM-1:0]          skp_byte_rcvd;
reg                      skp_1end_rcvd;
reg   [SYM-1:0]          skp_byte_rcvd_i;
reg   [SYM-1:0]          skp_byte_rcvd_d;
wire  [SYM-1:0]          skp_ab_rcvd;
wire                     skp_rcvd_ge_5;
wire                     skp_rcvd;
wire  [RXSB_WD-1:0]      fhf_ts0_rcvd_pulse, fhf_ts1_rcvd_pulse, fhf_ts2_rcvd_pulse, fhf_ts_rcvd_pulse, fhf_ts_s0_rcvd_pulse;
wire  [RXSB_WD-1:0]      shf_ts0_rcvd_pulse, shf_ts1_rcvd_pulse, shf_ts2_rcvd_pulse, shf_ts_rcvd_pulse, shf_ts_s0_rcvd_pulse;
wire  [RXSB_WD-1:0]      shf_ts_dcb_rcvd_pulse;
wire                     fhf_ts_rcvd_d;
reg                      fhf_ts0_rcvd_d, fhf_ts1_rcvd_d, fhf_ts2_rcvd_d;
wire  [RXSB_WD-1:0]      int_ts_rcvd_pulse, int_ts0_rcvd_pulse, int_ts1_rcvd_pulse, int_ts2_rcvd_pulse;
wire  [RXSB_WD-1:0]      ts_corrected, ts0_corrected, ts1_corrected, ts2_corrected;
wire                     ltssm_in_compliance;
reg                      rxdatablock_d;
wire  [RXSB_WD-1:0]      rxdatablock;
wire  [RXSB_WD-1:0]      int_rxdatablock;
reg   [NB-1:0]           sym_error;
reg                      latched_rxdata_dv;
reg   [AW-1:0]           sym_error_count;
reg   [7:0]              all_sym_bus_1_1; //sym7-0 match pre-sym7-0
reg   [7:0]              all_sym_bus_1_2; //sym7-0 match pre-sym15-8
reg   [7:0]              all_sym_bus_2_1; //sym15-8 match pre-sym7-0
reg   [7:0]              all_sym_bus_2_2; //sym15-8 match pre-sym15-8
reg   [RXSB_WD-1:0]      all_sym_match_1_1; //sym7-0 match pre-sym7-0
reg   [RXSB_WD-1:0]      all_sym_match_1_2; //sym7-0 match pre-sym15-8
reg   [RXSB_WD-1:0]      all_sym_match_2_1; //sym15-8 match pre-sym7-0
reg   [RXSB_WD-1:0]      all_sym_match_2_2; //sym15-8 match pre-sym15-8
reg   [RXSB_WD-1:0]      all_sym_match_1_1_d; //sym7-0 match pre-sym7-0
reg   [RXSB_WD-1:0]      all_sym_match_1_2_d; //sym7-0 match pre-sym15-8
reg   [RXSB_WD-1:0]      all_sym_match_2_1_d; //sym15-8 match pre-sym7-0
reg   [RXSB_WD-1:0]      all_sym_match_2_2_d; //sym15-8 match pre-sym15-8
reg   [DCB_WD-1:0]       fhf_rxdata_dcb_d;
reg   [(NB*8)-1:0]       fhf_rxdata_d;

wire inskp_i_or = |inskp_i;
wire ineie_i_or = |ineie_i;
wire in_no_ts   = inskp_i_or | ineie_i_or;

//below signals are used for sds detection
reg  [2:0]   sds_good_even_set;
reg  [3:0]   sds_good_set_cnt;

// active_nb decoder
assign  rx_bv = (active_nb_gen34 == 4'b0001) ? 8'b00000001 :
                (active_nb_gen34 == 4'b0010) ? 8'b00000011 :
                (active_nb_gen34 == 4'b0100) ? 8'b00001111 :
                (active_nb_gen34 == 4'b1000) ? 8'b11111111 : 8'b0000000;

// match 8s/16s
always @( * ) begin : rx_8s_data_PROC
    integer i;

    rx_data = 0;
    rx_err  = 0;

    rx_dv  = rxdata_dv;
    rx_err[0] = rxerror[0] & rxdata_dv; //rxerror[NB-1:1] duplicates rxerror[0], see rmlh.v

    for ( i=0; i<NB2; i=i+1 ) begin
        rx_data[i*8 +: 8] = rxdata[i*8 +: 8];
    end
end // rx_8s_data_PROC

//TS OS window
assign ints                    = rx_ts1 | rx_ts2;

//LTSSM state
assign smlh_ltssm_in_rcvrylock = (smlh_ltssm_state == S_RCVRY_LOCK);
assign ltssm_state_rcvry_eq    = (smlh_ltssm_state == S_RCVRY_EQ0 || smlh_ltssm_state == S_RCVRY_EQ1 || smlh_ltssm_state == S_RCVRY_EQ2 || smlh_ltssm_state == S_RCVRY_EQ3);
assign ltssm_in_cfglinkwdstart = (smlh_ltssm_state == S_CFG_LINKWD_START);
assign ltssm_in_l0             = (smlh_ltssm_state == S_L0);
assign ltssm_in_l0s            = (smlh_ltssm_state == S_L0S);
assign ltssm_in_l123sendeidle  = (smlh_ltssm_state == S_L123_SEND_EIDLE);
// detect SKP OS kept until the next RxStartBlock
assign inskp_i[0]              = inskp[0] | skp_rcvd; // inskp from de-scrambler (PHY may remove all SKP symbols)
// at least 5 consecutive bytes in an 8 byte boundary and all 8 bytes in the other 8 byte boundary match the corresponding bytes of an EIEOS
assign ineie_1_2_part[0]       = (&eieos_ab_rcvd[4:0]  | &eieos_ab_rcvd[5:1]  | &eieos_ab_rcvd[6:2]   | &eieos_ab_rcvd[7:3]);
assign ineie_1_2_part[1]       = (&eieos_ab_rcvd[12:8] | &eieos_ab_rcvd[13:9] | &eieos_ab_rcvd[14:10] | &eieos_ab_rcvd[15:11]);
assign eieos_rcvd_ge_5[0]      = ((eieos_ab_rcvd[0] + eieos_ab_rcvd[1] + eieos_ab_rcvd[2] + eieos_ab_rcvd[3] + eieos_ab_rcvd[4] + eieos_ab_rcvd[5] + eieos_ab_rcvd[6] + eieos_ab_rcvd[7]) >= 5);
assign ineie_i[0]              = rxosblock[0] & (rmlh_deskew_ds ? eieos_rcvd_ge_5[0] : ((eieos_byte_0_8_i[0] | eieos_byte_0_8_i[1]) & ineie_1_2_part[0] & ineie_1_2_part[1]));
assign eie_det_i               = ineie_i;

//Symbol decoder
always@( * ) begin : signal_decoder_PROC
    integer i;

    rx_sds_id = 0;
    sds_bd    = 0;
    rx_ts0_0  = 0;
    rx_ts1_0  = 0;
    rx_ts2_0  = 0;
    e0        = 0;
    rc        = 0;
    r0        = 0;
    ep        = 0;

    for (i=0; i<NB2; i=i+1) begin
        rx_ts0_0 [i] = rx_dv & (rx_data[i*8 +: 8] == `TS0_G6_SYM_0) & rxosblock[0] & rx_bv[i]; //symbol 0 of TS0
        rx_ts1_0 [i] = rx_dv & (rx_data[i*8 +: 8] == `TS1_G6_SYM_0) & rxosblock[0] & rx_bv[i]; //symbol 0 of TS1
        rx_ts2_0 [i] = rx_dv & (rx_data[i*8 +: 8] == `TS2_G6_SYM_0) & rxosblock[0] & rx_bv[i]; //symbol 0 of TS2
        e0       [i] = 1'b1;
        ep       [i] = rx_dv & (rx_data[i*8 +: 8] == ts_ep[i]) & rxosblock[0] & rx_bv[i]; //Even Parity match
        rx_sds_id[i] = rx_dv & (rx_data[i*8 +: 8] == `SDS_G6_S0) & rx_bv[i] & rxosblock[0]; //symbol 0/4/8/12 of sds
        sds_bd   [i] = rx_dv & (rx_data[i*8 +: 8] == `SDS_G6_S1) & rx_bv[i] & rxosblock[0]; //sds body
    end
// /symbol 7/15, Received Dc balance for TS0/1/2
        rc       [8*0+7] = rx_dv & rx_bv[8*0+7] & rxdata_dcb[0]; //TS1/2
        r0       [8*0+7] = rx_dv & rx_bv[8*0+7] & rxdata_dcb[0]; //TS0

end // signal_decoder_PROC


// int_sym_count
// combinational logic of int_sym_count for each symbol.
// int_sym_count is a free running counter reset by rxstartblock.
// sym_count is reg version of int_sym_count[NB-1].
// byte 0 is always for OS recognization in gen6 frame.
// int_sym_count[0]=0, int_sym_count[1]=1, int_sym_count[2]=2, int_sym_count[3]=3, ... if rxstartblock is at the same cycle.
// if !rx_dv, no update to int_sym_count[*].
always @( * ) begin : int_sym_count_PROC
    int_sym_count[0] =            ( rxstartblock[0] ? 0 : (rx_dv ? sym_count+1 : sym_count) );                    //byte0 always valid
    int_sym_count[1] = rx_bv[1] ? ( rxstartblock[0] ? 1 : (rx_dv ? sym_count+2 : sym_count) ) : int_sym_count[0]; //2-s
    int_sym_count[2] = rx_bv[2] ? ( rxstartblock[0] ? 2 : (rx_dv ? sym_count+3 : sym_count) ) : int_sym_count[1]; //4-s
    int_sym_count[3] = rx_bv[3] ? ( rxstartblock[0] ? 3 : (rx_dv ? sym_count+4 : sym_count) ) : int_sym_count[2]; //4-s
    int_sym_count[4] = rx_bv[4] ? ( rxstartblock[0] ? 4 : (rx_dv ? sym_count+5 : sym_count) ) : int_sym_count[3]; //8-s
    int_sym_count[5] = rx_bv[5] ? ( rxstartblock[0] ? 5 : (rx_dv ? sym_count+6 : sym_count) ) : int_sym_count[4]; //8-s
    int_sym_count[6] = rx_bv[6] ? ( rxstartblock[0] ? 6 : (rx_dv ? sym_count+7 : sym_count) ) : int_sym_count[5]; //8-s
    int_sym_count[7] = rx_bv[7] ? ( rxstartblock[0] ? 7 : (rx_dv ? sym_count+8 : sym_count) ) : int_sym_count[6]; //8-s
end // int_sym_count_PROC

//detect TS
assign rx_ts_0        = rx_ts1_0 | rx_ts2_0;

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
            if ( |eie_det_i )
                latched_rlock_eies_rcvd <= #TP 1;
        end else begin
            latched_rlock_eies_rcvd <= #TP 1;
        end
    end
end //l_rlock_eies_rcvd_PROC

assign rlock_eies_rcvd = latched_rlock_eies_rcvd | ~smlh_ltssm_in_rcvrylock;

// record rx data symbol = eieos and detect eieos
// eieos_byte_0_8: either Symbol 0 or Symbol 8 of the Block matches the corresponding byte of an EIEOS . A Receiver is permitted to ignore up to one bit mismatch for this comparison
always @* begin : eieos_byte_rcvd_PROC
    integer i;
    eieos_byte_rcvd = 0;
    eieos_byte_0_8  = 0;

    for ( i=0; i<NB2; i=i+1 ) begin
        if ( sym_count == 7 ) begin // 2nd clock
            if ( rx_data[i*8 +: 8] == `EIEOS_G6_S8 && rx_dv && ~rx_err[0] )
                eieos_byte_rcvd[i] = 1'b1;
            // check sym 8 more than 6 1s
            eieos_byte_0_8[1] = ((rx_data[0*8+0] + rx_data[0*8+1] + rx_data[0*8+2] + rx_data[0*8+3] + rx_data[0*8+4] + rx_data[0*8+5] + rx_data[0*8+6] + rx_data[0*8+7]) >= 7) & rx_dv & ~rx_err[0];
        end else begin
            if ( rx_data[i*8 +: 8] == `EIEOS_G6_S0 && rx_dv && ~rx_err[0] )
                eieos_byte_rcvd[i] = 1'b1;
            // check sym 0 more than 6 0s
            eieos_byte_0_8[0] = ((rx_data[0*8+0] + rx_data[0*8+1] + rx_data[0*8+2] + rx_data[0*8+3] + rx_data[0*8+4] + rx_data[0*8+5] + rx_data[0*8+6] + rx_data[0*8+7]) <= 1) & rx_dv & ~rx_err[0];
        end
    end
end // eieos_byte_rcvd_PROC

// filling the 16 EIEOS bytes
always @* begin : eieos_byte_rcvd_i_PROC
    eieos_byte_rcvd_i = eieos_byte_rcvd_d;
    eieos_byte_0_8_i  = eieos_byte_0_8_d;

    if ( sym_count == 7 && rx_dv && ~rx_err[0] ) begin // 2nd clock
        eieos_byte_rcvd_i[8 +: 8]  = eieos_byte_rcvd_d[0 +: 8]; //8 bits <- left shift 8 bits
        eieos_byte_rcvd_i[0 +: 8]  = eieos_byte_rcvd[0 +: 8];
        eieos_byte_0_8_i[1]        = eieos_byte_0_8[1]; // sym 8
    end
   if ( int_rxosblock[0] ) begin // 1st clock
        eieos_byte_rcvd_i = eieos_byte_rcvd;
        eieos_byte_0_8_i[0] = eieos_byte_0_8[0]; // sym 0
        eieos_byte_0_8_i[1] = 0;                 // clear sym 8 at the 1st clock
   end

end // eieos_byte_rcvd_i_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : eieos_byte_rcvd_d_PROC
    if ( ~core_rst_n ) begin
        eieos_byte_rcvd_d <= #TP 0;
        eieos_byte_0_8_d  <= #TP 0;
    end else begin
        eieos_byte_rcvd_d <= #TP eieos_byte_rcvd_i;
        eieos_byte_0_8_d  <= #TP eieos_byte_0_8_i;
    end
end // eieos_byte_rcvd_d_PROC

// 16 eieos syms aligned at sym_count = 15
assign eieos_ab_rcvd[15:0] = int_sym_count[NB2-1]==4'b1111 ? eieos_byte_rcvd_i[15:0] : 16'h0;

// record rx data symbol = SKP for skp os.
always @* begin : skp_byte_rcvd_PROC
    integer i;
    skp_byte_rcvd = 0;

    for ( i=0; i<NB2; i=i+2 ) begin
        if ( rx_data[i*8 +: 8] == `SKP_G6_S0 && rx_dv && ~rx_err[0] )
            skp_byte_rcvd[i] = 1'b1;

        if ( rx_data[(i+1)*8 +: 8] == `SKP_G6_S1 && rx_dv && ~rx_err[0] )
            skp_byte_rcvd[i+1] = 1'b1;

    end
end // skp_byte_rcvd_PROC

// record rx data symbol = SKP_END for skp os.
always @* begin : skp_1end_rcvd_PROC
    skp_1end_rcvd = 0;

    if ( rx_data[0*8 +: 8] == `SKPEND_G6_S0 && rx_dv && ~rx_err[0] ) // only need to detect the 1st symbol of SKP_END
        skp_1end_rcvd = 1'b1;
end // skp_1end_rcvd_PROC

// filling the 16 skp bytes
always @* begin : skp_byte_rcvd_i_PROC
    skp_byte_rcvd_i = skp_byte_rcvd_d;

    if ( sym_count == 7 && rx_dv && ~rx_err[0] ) begin // 2nd clock
        skp_byte_rcvd_i[8 +: 8]  = skp_byte_rcvd_d[0 +: 8]; //8 bits <- left shift 8 bits
        skp_byte_rcvd_i[0 +: 8]  = skp_byte_rcvd[0 +: 8];
    end
    if ( int_rxosblock[0] )
        skp_byte_rcvd_i = skp_byte_rcvd;
end // skp_byte_rcvd_i_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : skp_byte_rcvd_d_PROC
    if ( ~core_rst_n ) begin
        skp_byte_rcvd_d <= #TP 0;
    end else begin
        skp_byte_rcvd_d <= #TP skp_byte_rcvd_i;
    end
end // skp_byte_rcvd_d_PROC

// 16 skp syms aligned
assign skp_ab_rcvd = skp_byte_rcvd_i;

// A SKP OS is considered to begin under the following conditions: (i) any 5 or more aligned bytes of the first 8 bytes of a Block match a SKP, and
//                                                                 (ii) either the first byte or the 8th byte of the Block matches either a SKP or a SKP_END
// during or at the end of data stream, no need to check sym0 or sym8
assign skp_rcvd_ge_5 = rxosblock[0] & (rmlh_deskew_ds ? 1'b1 : (skp_ab_rcvd[0] | skp_ab_rcvd[8] | skp_1end_rcvd)) & (sym_count == 7) & // 2nd clock for 8s
                       ((skp_ab_rcvd[0] + skp_ab_rcvd[1] + skp_ab_rcvd[2] + skp_ab_rcvd[3] + skp_ab_rcvd[4] + skp_ab_rcvd[5] + skp_ab_rcvd[6] + skp_ab_rcvd[7]) >= 5);
assign skp_rcvd      = skp_rcvd_ge_5;

// detect TS1/2
assign int_in_ts[0] = !rx_err[0] & ints[0] & call_in_ts(1'b1    , in_ts_d     , int_sym_count[0], rx_ts_0[0], 1'b0 , 1'b0 ); //byte0 is always valid
assign int_in_ts[1] = !rx_err[0] & ints[0] & call_in_ts(rx_bv[1], int_in_ts[0], int_sym_count[1], 1'b0      , 1'b0 , 1'b0 );
assign int_in_ts[2] = !rx_err[0] & ints[0] & call_in_ts(rx_bv[2], int_in_ts[1], int_sym_count[2], 1'b0      , 1'b0 , 1'b0 );
assign int_in_ts[3] = !rx_err[0] & ints[0] & call_in_ts(rx_bv[3], int_in_ts[2], int_sym_count[3], 1'b0      , rc[3], ep[3]); //4s
assign int_in_ts[4] = !rx_err[0] & ints[0] & call_in_ts(rx_bv[4], int_in_ts[3], int_sym_count[4], 1'b0      , 1'b0 , 1'b0 );
assign int_in_ts[5] = !rx_err[0] & ints[0] & call_in_ts(rx_bv[5], int_in_ts[4], int_sym_count[5], 1'b0      , 1'b0 , 1'b0 );
assign int_in_ts[6] = !rx_err[0] & ints[0] & call_in_ts(rx_bv[6], int_in_ts[5], int_sym_count[6], 1'b0      , 1'b0 , 1'b0 );
assign int_in_ts[7] = !rx_err[0] & ints[0] & call_in_ts(rx_bv[7], int_in_ts[6], int_sym_count[7], 1'b0      , rc[7], ep[7]); //8s



//function to find TS1/2 OS
function automatic call_in_ts;
    input       rx_bv;          //byte valid
    input       pre_in_ts;      //previous symbol is TS's
    input [3:0] count;          //symbol count number
    input       rx_ts_0;        //current symbol is 0-symbol
    input       rc;             //Received Dc balance
    input       ep;             //Even Parity
begin
    if ( rx_bv==0 )             //if byte invalid, keep previous symbol byte
        call_in_ts = pre_in_ts;

    else case (count)
        4'b0000, 4'b1000:
            call_in_ts = rx_ts_0;                                   //symbol 0 must be Start of TS1 or TS2
        4'b0001, 4'b1001:
            call_in_ts = pre_in_ts;                                 //Link number or eq byte 0 can be any value
        4'b0010, 4'b1010:
            call_in_ts = pre_in_ts;                                 //2nd Symbol lane number (or eq byte 1 can be any value)
        4'b0011, 4'b1011:
            call_in_ts = pre_in_ts;                                 //eq byte 2 can be any value
        4'b0100, 4'b1100:
            call_in_ts = pre_in_ts;                                 //eq byte 3 can be any value
        4'b0101, 4'b1101:
            call_in_ts = pre_in_ts;                                 //data rate
        4'b0110, 4'b1110:
            call_in_ts = pre_in_ts;                                 //symbol 6 can be any value = training control
        default: begin                                              //symbol 7/15
            if ( rc )                                               //Received Dc balance
                call_in_ts = 1'b0;
            else
                call_in_ts = ep & pre_in_ts;                        //have to be Even Parity match
        end
    endcase
end
endfunction // call_in_ts

// detect TS0
assign int_in_ts0[0] = !rx_err[0] & rx_ts0[0] & call_in_ts0(1'b1    , in_ts0_d     , int_sym_count[0], rx_ts0_0[0], 1'b0 , 1'b0 , e0[0]); //byte0 is always valid
assign int_in_ts0[1] = !rx_err[0] & rx_ts0[0] & call_in_ts0(rx_bv[1], int_in_ts0[0], int_sym_count[1], 1'b0       , 1'b0 , 1'b0 , e0[1]);
assign int_in_ts0[2] = !rx_err[0] & rx_ts0[0] & call_in_ts0(rx_bv[2], int_in_ts0[1], int_sym_count[2], 1'b0       , 1'b0 , 1'b0 , e0[2]);
assign int_in_ts0[3] = !rx_err[0] & rx_ts0[0] & call_in_ts0(rx_bv[3], int_in_ts0[2], int_sym_count[3], 1'b0       , r0[3], ep[3], e0[3]); //4s
assign int_in_ts0[4] = !rx_err[0] & rx_ts0[0] & call_in_ts0(rx_bv[4], int_in_ts0[3], int_sym_count[4], 1'b0       , 1'b0 , 1'b0 , e0[4]);
assign int_in_ts0[5] = !rx_err[0] & rx_ts0[0] & call_in_ts0(rx_bv[5], int_in_ts0[4], int_sym_count[5], 1'b0       , 1'b0 , 1'b0 , e0[5]);
assign int_in_ts0[6] = !rx_err[0] & rx_ts0[0] & call_in_ts0(rx_bv[6], int_in_ts0[5], int_sym_count[6], 1'b0       , 1'b0 , 1'b0 , e0[6]);
assign int_in_ts0[7] = !rx_err[0] & rx_ts0[0] & call_in_ts0(rx_bv[7], int_in_ts0[6], int_sym_count[7], 1'b0       , r0[7], ep[7], e0[7]); //8s

//function to find TS0 OS
function automatic call_in_ts0;
    input       rx_bv;          //byte valid
    input       pre_in_ts;      //previous symbol is TS's
    input [3:0] count;          //symbol count number
    input       rx_ts0_0;       //current symbol is 0-symbol
    input       r0;             //Received Dc balance for TS0
    input       ep;             //Even Parity
    input       e0;             //symbol 1-6 even bit = 0b
begin
    if ( rx_bv==0 )             //if byte invalid, keep previous symbol byte
        call_in_ts0 = pre_in_ts;

    else case (count)
        4'b0000, 4'b1000:
            call_in_ts0 = rx_ts0_0;                                  //symbol 0 must be Start of TS1 or TS2
        4'b0001, 4'b1001:
            call_in_ts0 = e0 & pre_in_ts;                            //Link number or eq byte 0 can be any value
        4'b0010, 4'b1010:
            call_in_ts0 = e0 & pre_in_ts;                            //2nd Symbol lane number (or eq byte 1 can be any value)
        4'b0011, 4'b1011:
            call_in_ts0 = e0 & pre_in_ts;                            //eq byte 2 can be any value
        4'b0100, 4'b1100:
            call_in_ts0 = e0 & pre_in_ts;                            //eq byte 3 can be any value
        4'b0101, 4'b1101:
            call_in_ts0 = e0 & pre_in_ts;                            //data rate
        4'b0110, 4'b1110:
            call_in_ts0 = e0 & pre_in_ts;                            //symbol 6 can be any value = training control
        default: begin                                               //symbol 7/15
            if ( r0 )                                                //Received Dc balance, no check, jd6
                call_in_ts0 = 1'b0;
            else
                call_in_ts0 = e0 & ep & pre_in_ts;                   //have to be Even Parity match
        end
    endcase
end
endfunction // call_in_ts0

// ts for Call Even Parity for sym7/15
assign ts_ep[0]  = {8{(!rx_err[0] & rx_dv)}} & call_in_ep(1'b1    , in_ts_ep, int_sym_count[0], rx_data[7:0]  );
assign ts_ep[1]  = {8{(!rx_err[0] & rx_dv)}} & call_in_ep(rx_bv[1], ts_ep[0], int_sym_count[1], rx_data[15:8] );
assign ts_ep[2]  = {8{(!rx_err[0] & rx_dv)}} & call_in_ep(rx_bv[2], ts_ep[1], int_sym_count[2], rx_data[23:16]);
assign ts_ep[3]  = {8{(!rx_err[0] & rx_dv)}} & call_in_ep(rx_bv[3], ts_ep[2], int_sym_count[3], rx_data[31:24]);
assign ts_ep[4]  = {8{(!rx_err[0] & rx_dv)}} & call_in_ep(rx_bv[4], ts_ep[3], int_sym_count[4], rx_data[39:32]);
assign ts_ep[5]  = {8{(!rx_err[0] & rx_dv)}} & call_in_ep(rx_bv[5], ts_ep[4], int_sym_count[5], rx_data[47:40]);
assign ts_ep[6]  = {8{(!rx_err[0] & rx_dv)}} & call_in_ep(rx_bv[6], ts_ep[5], int_sym_count[6], rx_data[55:48]);
assign ts_ep[7]  = {8{(!rx_err[0] & rx_dv)}} & call_in_ep(rx_bv[7], ts_ep[6], int_sym_count[7], rx_data[63:56]);


// TS for Even Parity
function automatic [7:0] call_in_ep;
    input       rx_bv;   // byte valid on the symbol
    input [7:0] pre_e_p; // previous even parity
    input [3:0] count;   // sym count on the byte
    input [7:0] rx_data; // current clock rx_data
begin
    if ( ~rx_bv )
        call_in_ep = pre_e_p;

    else case (count)
        4'b0000, 4'b1000:
            call_in_ep = rx_data;         //sym0/8, initial data
        4'b1111, 4'b0111:
            call_in_ep = pre_e_p;         //sym7/15, keep sym6/14 value
        default:                          //sym14-4, bit-wise even parity
            call_in_ep = pre_e_p^rx_data;
    endcase
end
endfunction // call_in_ep

// 1st half TS received, get TS pulse
assign fhf_ts0_rcvd_pulse[0] = (int_sym_count[NB2-1]==4'b0111 & int_in_ts0[NB2-1]) & rx_ts0[0] & rx_dv; //1st half TS0 rcvd
assign fhf_ts1_rcvd_pulse[0] = (int_sym_count[NB2-1]==4'b0111 & int_in_ts[NB2-1] ) & rx_ts1[0] & rx_dv; //1st half TS1 rcvd
assign fhf_ts2_rcvd_pulse[0] = (int_sym_count[NB2-1]==4'b0111 & int_in_ts[NB2-1] ) & rx_ts2[0] & rx_dv; //1st half TS2 rcvd
assign fhf_ts_s0_rcvd_pulse[0]  = int_sym_count[NB2-1]==4'b0111 && (rx_ts0_0[0] || rx_ts1_0[0] || rx_ts2_0[0]) & rx_dv; //1st half TS  rcvd
assign fhf_ts_rcvd_pulse     = (fhf_ts0_rcvd_pulse | fhf_ts1_rcvd_pulse | fhf_ts2_rcvd_pulse); //1st half TS  rcvd

// 2nd half TS received, get TS pulse
// 2nd half TS identifier (sym8) may match SKP OS sym8 value (RX SKP OS length vary), exclude the case by using ~smseq_inskip_rcv or ~inskp_i[0]
assign shf_ts0_rcvd_pulse[0] = int_sym_count[NB2-1]==4'b1111 & (int_in_ts0[NB2-1] | shf_ts_dcb_rcvd_pulse[0]) & rx_ts0[0] & rx_dv & ~smseq_inskip_rcv; //2nd half TS0 rcvd
assign shf_ts1_rcvd_pulse[0] = int_sym_count[NB2-1]==4'b1111 & (int_in_ts[NB2-1]  | shf_ts_dcb_rcvd_pulse[0]) & rx_ts1[0] & rx_dv & ~smseq_inskip_rcv; //2nd half TS1 rcvd
assign shf_ts2_rcvd_pulse[0] = int_sym_count[NB2-1]==4'b1111 & (int_in_ts[NB2-1]  | shf_ts_dcb_rcvd_pulse[0]) & rx_ts2[0] & rx_dv & ~smseq_inskip_rcv; //2nd half TS2 rcvd
assign shf_ts_dcb_rcvd_pulse[0] = fhf_rxdata_dcb_d[0] && rxdata_dcb[0] && fhf_rxdata_d[((NB2-1)*8)-1:0]==rxdata[((NB2-1)*8)-1:0]; //2nd half TS with DC balance symbol rcvd
assign shf_ts_s0_rcvd_pulse[0]  = int_sym_count[NB2-1]==4'b1111 && (rx_ts0_0[0] || rx_ts1_0[0] || rx_ts2_0[0]) & rx_dv; //1st half TS  rcvd
assign shf_ts_rcvd_pulse  = (shf_ts0_rcvd_pulse | shf_ts1_rcvd_pulse | shf_ts2_rcvd_pulse);       //2nd half TS  rcvd
assign fhf_ts_rcvd_d      = (fhf_ts0_rcvd_d | fhf_ts1_rcvd_d | fhf_ts2_rcvd_d);

always @( posedge core_clk or negedge core_rst_n ) begin : fhf_ts1_rcvd_d_PROC
    if ( ~core_rst_n ) begin
        fhf_ts0_rcvd_d <= #TP 0;
        fhf_ts1_rcvd_d <= #TP 0;
        fhf_ts2_rcvd_d <= #TP 0;
        fhf_rxdata_dcb_d <= #TP 0;
        fhf_rxdata_d     <= #TP 0;
    end else if ( int_sym_count[NB2-1]==4'b1111 && rx_dv) begin
        fhf_ts0_rcvd_d <= #TP 0;
        fhf_ts1_rcvd_d <= #TP 0;
        fhf_ts2_rcvd_d <= #TP 0;
        fhf_rxdata_dcb_d <= #TP 0;
        fhf_rxdata_d     <= #TP 0;
    end else begin
        if ( fhf_ts0_rcvd_pulse[0] )
            fhf_ts0_rcvd_d <= #TP 1'b1;

        if ( fhf_ts1_rcvd_pulse[0] )
            fhf_ts1_rcvd_d <= #TP 1'b1;

        if ( fhf_ts2_rcvd_pulse[0] )
            fhf_ts2_rcvd_d <= #TP 1'b1;

        if(int_sym_count[NB2-1]==7 && rx_dv) begin
            fhf_rxdata_dcb_d <= #TP rxdata_dcb;
            fhf_rxdata_d     <= #TP rxdata;
        end
    end
end // fhf_ts1_rcvd_d_PROC

assign int_ts0_rcvd_pulse[0] = (int_sym_count[NB2-1]==4'b1111 & (shf_ts0_rcvd_pulse[0] | fhf_ts0_rcvd_d)) & rx_ts0[0] & rx_dv & rlock_eies_rcvd;
assign int_ts1_rcvd_pulse[0] = (int_sym_count[NB2-1]==4'b1111 & (shf_ts1_rcvd_pulse[0] | fhf_ts1_rcvd_d)) & rx_ts1[0] & rx_dv & rlock_eies_rcvd;
assign int_ts2_rcvd_pulse[0] = (int_sym_count[NB2-1]==4'b1111 & (shf_ts2_rcvd_pulse[0] | fhf_ts2_rcvd_d)) & rx_ts2[0] & rx_dv & rlock_eies_rcvd;
assign int_ts_rcvd_pulse  = (int_ts1_rcvd_pulse | int_ts2_rcvd_pulse | int_ts0_rcvd_pulse);

always @(posedge core_clk or negedge core_rst_n) begin : ts12_pulse_seq_PROC
    if (!core_rst_n) begin
        smseq_ts0_rcvd_pulse  <= #TP 0;
        smseq_ts1_rcvd_pulse  <= #TP 0;
        smseq_ts2_rcvd_pulse  <= #TP 0;
    end
    else begin
        smseq_ts0_rcvd_pulse  <= #TP int_ts0_rcvd_pulse & {RXSB_WD{rlock_eies_rcvd}};
        smseq_ts1_rcvd_pulse  <= #TP int_ts1_rcvd_pulse & {RXSB_WD{rlock_eies_rcvd}};
        smseq_ts2_rcvd_pulse  <= #TP int_ts2_rcvd_pulse & {RXSB_WD{rlock_eies_rcvd}};
    end
end // ts12_pulse_seq_PROC

//ts_error
//error if not TS or eieos or skp or RxDataInvalid for compensation of SyncHeader or Clock Tolerance.
//or 1st TS symbol received & pre OS is TS OS & pre TS Symbols number is not 15.
//Max ~RxDataValid is two cycles within a Block.
//if rxerror (decode error) within inskp, ts_error.
assign rxdatainvld_pulse = !rx_dv & (rxdata_dv_dd | rxdata_dv_d); //DataInValid. If ~rx_dv longer than two cycles, rx_dv is not from RxDataInValid for compensation of SyncHeader or clock tolerance
assign int_ts_error  = (cfg_elastic_buffer_mode & ~rxaligned) ? 1 : (cfg_elastic_buffer_mode & ~rx_dv) ? 0 : (next_ts_err_state == ERRR);

logic in_datablock;
always @(posedge core_clk or negedge core_rst_n) begin : in_datablock_PROC
    if(!core_rst_n) begin
        in_datablock <= #TP '0;
    end 
    else if (rx_dv && rxstartblock) begin
        in_datablock <= #TP rxsyncheader == `SYNC_DATA_BLOCK;
    end
end // in_datablock_PROC
assign smseq_invalid_os = rlock_eies_rcvd & ~rmlh_deskew_ds & ~in_datablock & rxdata_dv_d & (((sym_count == 15) & ~(smseq_ts0_rcvd_pulse_o | smseq_ts1_rcvd_pulse_o | smseq_ts2_rcvd_pulse_o | smseq_ineies_rcv | smseq_sds_rcvd | smseq_inskip_rcv)));

// generate ts_error
always @( posedge core_clk or negedge core_rst_n ) begin : latched_os_rcvd_PROC
    if ( ~core_rst_n )
        latched_os_rcvd <= #TP 0;
    else if ( rx_dv && |rxstartblock )
        latched_os_rcvd <= #TP 0;
    else if ( |inskp_i || |int_ts_rcvd_pulse || |ineie_i ) // if prior os detected, skp length variable
        latched_os_rcvd <= #TP 1;
end // latched_os_rcvd_PROC

always @* begin : next_ts_err_state_PROC
    next_ts_err_state = ts_err_state;

    case ( ts_err_state )
        IDLE: begin
            if ( |int_ts_rcvd_pulse )
                next_ts_err_state = VALD;
        end // IDLE

        VALD: begin
            if ( |smseq_ts0_rcvd_pulse || |smseq_ts1_rcvd_pulse || |smseq_ts2_rcvd_pulse || |eies_rcvd_pulse ) begin
                if ( ~rx_dv ) // RxDataValid = 0
                    next_ts_err_state = NRDV;
                else if ( |rxstartblock ) // sym_count == 15 && rxstartblock == 1
                    next_ts_err_state = VALD;
                else
                    next_ts_err_state = ERRR;
            end

            if ( rx_dv && |rxstartblock && ~latched_os_rcvd ) // prior is not an OS
                next_ts_err_state = ERRR;

            // if SKP OS complete at clock N, the rxstartblock = 1 at clock N+1 with sym_count != 15. use the one clock delay skip signal inskip_rcv
            if ( ((|inskp_i) || (|inskip_rcv)) ? 1'b0 : (|rxstartblock && sym_count != 15) ) // an OS < 16 symbols except skp variable length
                next_ts_err_state = ERRR;

            if ( rxstartblock[0] && ~rxosblock[0] )
                next_ts_err_state = ERRR;
        end // VALD

        NRDV: begin
            if ( rx_dv ) begin
                if ( rxstartblock[0] && rxosblock[0] )
                    next_ts_err_state = VALD;
                else
                    next_ts_err_state = ERRR;
            end else if (!rxaligned) begin
                    next_ts_err_state = ERRR;
            end
        end // NRDV

        default: begin // ERRR
            next_ts_err_state = IDLE;
        end // ERRR
    endcase
end // next_ts_err_state_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : ts_err_state_PROC
    if ( ~core_rst_n )
        ts_err_state <= #TP IDLE;
    else
        ts_err_state <= #TP next_ts_err_state;
end // ts_err_state_PROC


// update TS Symbol value when int_sym_count reaches the symbol number
always @( * ) begin : int_btv_PROC
    integer i;

    for (i=0; i<NB; i=i+1) begin
        int_btv[i] = rx_dv & rx_bv[i];
    end
end // int_btv_PROC

always @( * ) begin : btv_PROC
    integer i;

    for (i=0; i<NB; i=i+1) begin
        btv[i] = int_btv[i] & (int_in_ts[i] | int_in_ts0[i]);
    end
end // btv_PROC

//don't use general design in order to reduce combinatorial logic.
always @( * ) begin : update_ts_sym_PROC
                     //symbol 0 can only be at byte slot 0
    dec_ts_sym[0]  = (btv[0] && int_sym_count[0]==0 ) ? rx_data[ 7: 0] : int_ts_sym[0];
                     //symbol 1 can only be at byte slot 1
    dec_ts_sym[1]  = (btv[1] && int_sym_count[1]==1 ) ? rx_data[15: 8] : int_ts_sym[1];
                     //symbol 2 can only be at byte slot 2
    dec_ts_sym[2]  = (btv[2] && int_sym_count[2]==2 ) ? rx_data[23:16] : int_ts_sym[2];
                     //symbol 3 can only be at byte slot 3
    dec_ts_sym[3]  = (btv[3] && int_sym_count[3]==3 ) ? rx_data[31:24] : int_ts_sym[3];
                     //symbol 4 can only be at byte slot 0 or 4
    dec_ts_sym[4]  = (btv[0] && int_sym_count[0]==4 ) ? rx_data[ 7: 0] :
                     (btv[4] && int_sym_count[4]==4 ) ? rx_data[39:32] : int_ts_sym[4];
                     //symbol 5 can only be at byte slot 1 or 5
    dec_ts_sym[5]  = (btv[1] && int_sym_count[1]==5 ) ? rx_data[15: 8] :
                     (btv[5] && int_sym_count[5]==5 ) ? rx_data[47:40] : int_ts_sym[5];
                     //symbol 6 can only be at byte slot 2 or 6
    dec_ts_sym[6]  = (btv[2] && int_sym_count[2]==6 ) ? rx_data[23:16] :
                     (btv[6] && int_sym_count[6]==6 ) ? rx_data[55:48] : int_ts_sym[6];
                     //symbol 7 can only be at byte slot 3 or 7
    dec_ts_sym[7]  = (btv[3] && int_sym_count[3]==7 ) ? rx_data[31:24] :
                     (btv[7] && int_sym_count[7]==7 ) ? rx_data[63:56] : int_ts_sym[7];
                     //symbol 8 can only be at byte slot 0
    dec_ts_sym[8]  = (btv[0] && int_sym_count[0]==8 ) ? rx_data[ 7: 0] : int_ts_sym[8];
                     //symbol 9 can only be at byte slot 1
    dec_ts_sym[9]  = (btv[1] && int_sym_count[1]==9 ) ? rx_data[15: 8] : int_ts_sym[9];
                     //symbol 10 can only be at byte slot 0 or 2
    dec_ts_sym[10] = (btv[2] && int_sym_count[2]==10) ? rx_data[23:16] : int_ts_sym[10];
                     //symbol 11 can only be at byte slot 0, 1 or 3
    dec_ts_sym[11] = (btv[3] && int_sym_count[3]==11) ? rx_data[31:24] : int_ts_sym[11];
                     //symbol 12 can only be at byte slot 0 or 4
    dec_ts_sym[12] = (btv[0] && int_sym_count[0]==12) ? rx_data[ 7: 0] :
                     (btv[4] && int_sym_count[4]==12) ? rx_data[39:32] : int_ts_sym[12];
                     //symbol 13 can only be at byte slot 1 or 5
    dec_ts_sym[13] = (btv[1] && int_sym_count[1]==13) ? rx_data[15: 8] :
                     (btv[5] && int_sym_count[5]==13) ? rx_data[47:40] : int_ts_sym[13];
                     //symbol 14 can only be at byte slot 2 or 6
    dec_ts_sym[14] = (btv[2] && int_sym_count[2]==14) ? rx_data[23:16] :
                     (btv[6] && int_sym_count[6]==14) ? rx_data[55:48] : int_ts_sym[14];
                     //symbol 15 can only be at byte slot 3 or 7
    dec_ts_sym[15] = (btv[3] && int_sym_count[3]==15) ? rx_data[31:24] :
                     (btv[7] && int_sym_count[7]==15) ? rx_data[63:56] : int_ts_sym[15];
end // update_ts_sym_PROC

// persistency count
// smseq_ts_rcvd_pcnt - special received TS matching Tx, smseq_ts_rcvd_mtx_pcnt - match Tx TS. smseq_ts_rcvd_cond_pcnt with conditions

reg [1:0]   int_ts_sym_valid;
reg [1:0]   pre_ts_sym_valid;

always @( * ) begin : sym_match_PROC
    integer i;

    all_sym_bus_1_1   = 0;
    all_sym_bus_1_2   = 0;
    all_sym_bus_2_1   = 0;
    all_sym_bus_2_2   = 0;
    all_sym_match_1_1 = 0;
    all_sym_match_1_2 = 0;
    all_sym_match_2_1 = 0;
    all_sym_match_2_2 = 0;


    if ( int_sym_count[NB2-1] == 7 ) begin
        for ( i=0; i<8; i=i+1 )
            all_sym_bus_1_1[i] = (pre_ts_sym[i]   == rx_data[i*8 +: 8] & pre_ts_sym_valid[0] & fhf_ts_rcvd_pulse[0]); //current sym7-0 match pre sym7-0

        for ( i=0; i<8; i=i+1 )
            all_sym_bus_1_2[i] = (pre_ts_sym[i+8] == rx_data[i*8 +: 8] & pre_ts_sym_valid[1] & fhf_ts_rcvd_pulse[0]); //current sym7-0 match pre sym15-8
    end
    // Ignore Symbol 7/15 because (bit 7 in all_sym_bus_*) Even Parity value can sometimes be the same as a DC Balance pattern (00h or AAh)
    all_sym_match_1_1 = &all_sym_bus_1_1[6:0] & rx_dv;
    all_sym_match_1_2 = &all_sym_bus_1_2[6:0] & rx_dv;

    if ( int_sym_count[NB2-1] == 15 ) begin
        for ( i=0; i<8; i=i+1 )
            all_sym_bus_2_1[i] = (pre_ts_sym[i]   == rx_data[i*8 +: 8] & pre_ts_sym_valid[0] & shf_ts_rcvd_pulse[0]); //current sym15-8 match pre sym7-0

        for ( i=0; i<8; i=i+1 )
            all_sym_bus_2_2[i] = (pre_ts_sym[i+8] == rx_data[i*8 +: 8] & pre_ts_sym_valid[1] & shf_ts_rcvd_pulse[0]); //current sym15-8 match pre sym15-8
    end
    // Ignore Symbol 7/15 because (bit 7 in all_sym_bus_*) Even Parity value can sometimes be the same as a DC Balance pattern (00h or AAh)
    all_sym_match_2_1 = &all_sym_bus_2_1[6:0] & rx_dv;
    all_sym_match_2_2 = &all_sym_bus_2_2[6:0] & rx_dv;


end // sym_match_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : all_sym_match_d_PROC
    if ( ~core_rst_n ) begin
        all_sym_match_1_1_d <= #TP 0;
        all_sym_match_2_1_d <= #TP 0;
        all_sym_match_1_2_d <= #TP 0;
        all_sym_match_2_2_d <= #TP 0;
    end else if ( int_ts_error || ~rlock_eies_rcvd ) begin
        all_sym_match_1_1_d <= #TP 0;
        all_sym_match_2_1_d <= #TP 0;
        all_sym_match_1_2_d <= #TP 0;
        all_sym_match_2_2_d <= #TP 0;
    end else begin
        if ( int_sym_count[NB2-1] == 7 && rx_dv ) begin
            all_sym_match_1_1_d <= #TP all_sym_match_1_1;
            all_sym_match_1_2_d <= #TP all_sym_match_1_2;
        end
        if ( int_sym_count[NB2-1] == 15 && rx_dv ) begin
            all_sym_match_2_1_d <= #TP all_sym_match_2_1;
            all_sym_match_2_2_d <= #TP all_sym_match_2_2;
        end
    end
end // all_sym_match_d_PROC

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

// for gen6, all symbols for the current sym7-0 must match previous sym7-0 or sym15-8
// for gen6, all symbols for the current sym15-8 must match previous sym7-0 or sym15-8
// keep two counts for the First HalF and Second HalF ( fhf_*_pcnt or shf_*_pcnt )
always @(posedge core_clk or negedge core_rst_n) begin : ts_rcvd_pcnt_PROC
    if ( ~core_rst_n ) begin
        priority_shf_sel    <= #TP 0;
        ts_rcvd_pcnt        <= #TP 0;
        ts_rcvd_mtx_pcnt    <= #TP 0;
        ts_rcvd_cond_pcnt   <= #TP 0;
    end else if ( int_ts_error || ~rlock_eies_rcvd || ~rxaligned || smlh_keep_rcvrylock_lane ) begin //clear when a ts_error happnens or a state transition is prohibited
        priority_shf_sel    <= #TP 0;
        ts_rcvd_pcnt        <= #TP 0;
        ts_rcvd_mtx_pcnt    <= #TP 0;
        ts_rcvd_cond_pcnt   <= #TP 0;
    end else if ( ltssm_clear ) begin //clear when a state transition
        if ( |int_ts_rcvd_pulse) begin
            priority_shf_sel    <= #TP |shf_ts_rcvd_pulse;
            ts_rcvd_pcnt        <= #TP 1;
            ts_rcvd_cond_pcnt   <= #TP 1;
            ts_rcvd_mtx_pcnt    <= #TP 1;
        end else begin
            priority_shf_sel    <= #TP 0;
            ts_rcvd_pcnt        <= #TP 0;
            ts_rcvd_cond_pcnt   <= #TP 0;
            ts_rcvd_mtx_pcnt    <= #TP 0;
        end

        if ( ltssm_lane_flip_ctrl_chg_pulse ) 
            ts_rcvd_mtx_pcnt <= #TP 0; // if lane flip changes, clear the count to re-start count after the flip
    end else begin
        if ( int_sym_count[NB2-1] == 15 ) begin // last symbol
            if ( |int_ts_rcvd_pulse) begin
                if ( |all_sym_match_2_1 || |all_sym_match_2_2 || |all_sym_match_1_1_d || |all_sym_match_1_2_d) begin // all cuurent second 8s match pre sym7-0 or sym15-8
                    if ( speed_change_is_1 )
                        ts_rcvd_pcnt <= #TP (ts_rcvd_pcnt < 8) ? ts_rcvd_pcnt + 1 : ts_rcvd_pcnt;
                    else begin
                        ts_rcvd_pcnt <= #TP 0;
                    end

                    priority_shf_sel <= #TP |shf_ts_rcvd_pulse;
                    ts_rcvd_mtx_pcnt <= #TP (ts_rcvd_mtx_pcnt < 8) ? ts_rcvd_mtx_pcnt + 1 : ts_rcvd_mtx_pcnt;
                end else begin // rcvd but not match any
                    if ( speed_change_is_1 )
                        ts_rcvd_pcnt <= #TP 1;
                    else begin
                        ts_rcvd_pcnt <= #TP 0;
                    end

                    priority_shf_sel <= #TP |shf_ts_rcvd_pulse;
                    ts_rcvd_mtx_pcnt <= #TP 1;
                end
            end else if ( rx_dv && (~ineie_i[0] && ~inskp_i[0])) begin // when sym_count == 15, if no ts/eieos/skp, then reset counts
                priority_shf_sel <= #TP 0;
                ts_rcvd_mtx_pcnt <= #TP 0;
                ts_rcvd_pcnt     <= #TP 0;
            end
        end // last symbol

        if ( (smlh_ltssm_in_rcvrylock || ltssm_in_cfglinkwdstart || ltssm_in_l0 || ltssm_in_l123sendeidle || ltssm_in_l0s) && |int_ts_rcvd_pulse) //for L0, if receive 2 TSs (not need persistency), ltssm move to Recovery
            ts_rcvd_cond_pcnt <= #TP (ts_rcvd_cond_pcnt < 3) ? ts_rcvd_cond_pcnt + 1 : ts_rcvd_cond_pcnt;

        if ( ltssm_lane_flip_ctrl_chg_pulse ) begin
            ts_rcvd_mtx_pcnt     <= #TP 0; // if lane flip changes, clear the count to re-start count after the flip
        end
    end // end else begin
end // ts_rcvd_pcnt_PROC

assign ts0_corrected[0] = int_ts0_rcvd_pulse[0] & ~(shf_ts0_rcvd_pulse[0] & (fhf_ts0_rcvd_pulse[0] | fhf_ts0_rcvd_d) ) & ~shf_ts_dcb_rcvd_pulse[0] ;
assign ts1_corrected[0] = int_ts1_rcvd_pulse[0] & ~(shf_ts1_rcvd_pulse[0] & (fhf_ts1_rcvd_pulse[0] | fhf_ts1_rcvd_d) ) & ~shf_ts_dcb_rcvd_pulse[0] ;
assign ts2_corrected[0] = int_ts2_rcvd_pulse[0] & ~(shf_ts2_rcvd_pulse[0] & (fhf_ts2_rcvd_pulse[0] | fhf_ts2_rcvd_d) ) & ~shf_ts_dcb_rcvd_pulse[0] ;

assign ts_corrected = ts0_corrected | ts1_corrected | ts2_corrected ;
assign smseq_os_corrected = |ts_corrected ;

// if int_ts_error, reset pcnt to 0 immediately
always @( * ) begin : clear_pcnt_PROC
    smseq_ts_rcvd_pcnt      = int_ts_error ? 0 :  ts_rcvd_pcnt;
    smseq_ts_rcvd_mtx_pcnt  = int_ts_error ? 0 :  ts_rcvd_mtx_pcnt;
    smseq_ts_rcvd_cond_pcnt = int_ts_error ? 0 :  ts_rcvd_cond_pcnt;
end // clear_pcnt_PROC

//detect sds: four good B1_C6_C6_C6 (4B) sets && at least two of which are in an even 4 byte aligned position (i.e. bytes 0-3, 8-11)
assign int_in_sds[0]  = !rx_err[0] & rxaligned & call_in_sds(1'b1    , 1'b0         , int_sym_count[0], rx_sds_id[0],  1'b0);
assign int_in_sds[1]  = !rx_err[0] & rxaligned & call_in_sds(rx_bv[1], int_in_sds[0], int_sym_count[1], 1'b0         , sds_bd[1]);
assign int_in_sds[2]  = !rx_err[0] & rxaligned & call_in_sds(rx_bv[2], int_in_sds[1], int_sym_count[2], 1'b0         , sds_bd[2]);
assign int_in_sds[3]  = !rx_err[0] & rxaligned & call_in_sds(rx_bv[3], int_in_sds[2], int_sym_count[3], 1'b0         , sds_bd[3]);
assign int_in_sds[4]  = !rx_err[0] & rxaligned & call_in_sds(rx_bv[4], int_in_sds[3], int_sym_count[4], rx_sds_id[4],  1'b0);
assign int_in_sds[5]  = !rx_err[0] & rxaligned & call_in_sds(rx_bv[5], int_in_sds[4], int_sym_count[5], 1'b0         , sds_bd[5]);
assign int_in_sds[6]  = !rx_err[0] & rxaligned & call_in_sds(rx_bv[6], int_in_sds[5], int_sym_count[6], 1'b0         , sds_bd[6]);
assign int_in_sds[7]  = !rx_err[0] & rxaligned & call_in_sds(rx_bv[7], int_in_sds[6], int_sym_count[7], 1'b0         , sds_bd[7]);

//function to find sds OS
function automatic call_in_sds;
    input       rx_bv;          //byte valid
    input       pre_in_ts;      //previous symbol is sds's
    input [3:0] count;          //symbol count number
    input       rx_sds_id;      //current symbol is sds id
    input       sds_bd;         //sds identifier
begin
    if ( rx_bv==0 )             //if byte invalid, keep previous symbol byte
        call_in_sds = pre_in_ts;

    else case (count)
        4'b0000, 4'b0100, 4'b1000, 4'b1100:
            call_in_sds = rx_sds_id;                                   //symbol 0/4/8/12 must be sds id
        default:
            call_in_sds = pre_in_ts & sds_bd;                          //sym1/2/3, sds body
    endcase
end
endfunction

always @(posedge core_clk or negedge core_rst_n) begin : sds_detect_PROC
    if (!core_rst_n) begin
        sds_good_set_cnt  <= #TP 0;
        sds_good_even_set <= #TP 0;
    end else if ( ~rxaligned || (|inskp_i) || (|rx_err) || (|int_ts_rcvd_pulse) || (|eie_det_i) ) begin // two Rx SDSs must be back-to-back
        sds_good_set_cnt  <= #TP 0;
        sds_good_even_set <= #TP 0;
    end else begin
        if (((sds_good_set_cnt + int_in_sds[3] + int_in_sds[7] ) >= 7 )
           ) begin
            sds_good_set_cnt <= #TP 7;
        end else begin
            sds_good_set_cnt <= #TP {1'b0,sds_good_set_cnt[2:0]} + int_in_sds[3] + int_in_sds[7];
        end

        if (((sds_good_even_set + int_in_sds[3]) >= 3)
           ) begin
            sds_good_even_set <= #TP 3;
        end else begin
            sds_good_even_set <= #TP {1'b0,sds_good_even_set[1:0]} + int_in_sds[3];
        end
    end
end // sds_detect_PROC

assign sds_rcvd_i = (sds_good_set_cnt >= 4) & (sds_good_even_set >= 2); // ( >= 4 good sets ) && ( >= 2 even good sets )

//latch TS Symbols and other signals used for the other blocks
always @(posedge core_clk or negedge core_rst_n) begin : latch_ts_symbol_other_signal_PROC
    integer i,j;

    if (!core_rst_n) begin
        in_ts0_d             <= #TP 0;
        in_ts_d              <= #TP 0;
        in_sds_d             <= #TP 0;
        in_ts_ep             <= #TP 0;
        rxdata_dv_d          <= #TP 0;
        rxdata_dv_dd         <= #TP 0;
        sym_count            <= #TP 0;
        ts_error             <= #TP 0;
        inskip_rcv           <= #TP 0;
        ts0_rcvd             <= #TP 0;
        ts1_rcvd             <= #TP 0;
        ts2_rcvd             <= #TP 0;
        eies_rcvd_pulse      <= #TP 0;

        for ( j=1; j<=12; j=j+1 ) begin
            in6_ts_sym_rcvd[j] <= #TP 0;
        end

        for ( i=0; i<SYM; i=i+1 ) begin
            int_ts_sym[i]  <= #TP 0;
            pre_ts_sym[i]  <= #TP 0;
        end //for
        int_ts_sym_valid[1:0]  <= #TP '0;
        pre_ts_sym_valid[1:0]  <= #TP '0;

    end else begin
        //if DataSkip, we have to delay one more cycle
        in_ts0_d             <= #TP int_in_ts0[NB2-1] ? 1 :  (rxdatainvld_pulse ? in_ts0_d : 0); //extend to reach the first valid symbol of the next clock cycle
        in_ts_d              <= #TP int_in_ts[NB2-1] ? 1  :  (rxdatainvld_pulse ? in_ts_d :  0); //extend to reach the first valid symbol of the next clock cycle
        in_sds_d             <= #TP int_in_sds[NB2-1] ? 1 : (rxdatainvld_pulse ? in_sds_d :  0); //extend to reach the first valid symbol of the next clock cycle
        in_ts_ep             <= #TP rxdatainvld_pulse ? in_ts_ep : ts_ep[NB2-1];
        sym_count            <= #TP int_sym_count[NB2-1];
        rxdata_dv_d          <= #TP rx_dv;
        rxdata_dv_dd         <= #TP rxdata_dv_d;
        ts_error             <= #TP int_ts_error;
        inskip_rcv           <= #TP ~rx_err & inskp_i;
        ts0_rcvd             <= #TP ~({RXSB_WD{int_ts_error}} | (int_ts2_rcvd_pulse | int_ts1_rcvd_pulse)) & (int_ts0_rcvd_pulse | ts0_rcvd);
        ts1_rcvd             <= #TP ~({RXSB_WD{int_ts_error}} | (int_ts2_rcvd_pulse | int_ts0_rcvd_pulse)) & (int_ts1_rcvd_pulse | ts1_rcvd);
        ts2_rcvd             <= #TP ~({RXSB_WD{int_ts_error}} | (int_ts1_rcvd_pulse | int_ts0_rcvd_pulse)) & (int_ts2_rcvd_pulse | ts2_rcvd);
        eies_rcvd_pulse      <= #TP eie_det_i;

        if ( int_ts_error ) begin
            for ( j=1; j<=12; j=j+1 ) begin
            end
        end else if ( fhf_ts_rcvd_pulse[0] ) begin // have to align to fhf_ts_rcvd_pulse, sym6-1
            for ( j=1; j<=6; j=j+1 ) begin
                in6_ts_sym_rcvd[j] <= #TP dec_ts_sym[j];
            end
        end else if ( shf_ts_rcvd_pulse[0] ) begin // have to align to shf_ts_rcvd_pulse, sym14-9
            for ( j=7; j<=12; j=j+1 ) begin
                in6_ts_sym_rcvd[j] <= #TP dec_ts_sym[j+2];
            end
        end

        if ( int_ts_error ) begin
            for ( j=1; j<=12; j=j+1 ) begin
                in6_ts_sym_rcvd[j] <= #TP 0;
            end
        end else if ( fhf_ts_rcvd_pulse[0] ) begin // have to align to fhf_ts_rcvd_pulse, sym6-1
            for ( j=1; j<=6; j=j+1 ) begin
                in6_ts_sym_rcvd[j] <= #TP dec_ts_sym[j];
            end
        end else if ( shf_ts_rcvd_pulse[0] ) begin // have to align to shf_ts_rcvd_pulse, sym14-9
            for ( j=7; j<=12; j=j+1 ) begin
                in6_ts_sym_rcvd[j] <= #TP dec_ts_sym[j+2];
            end
        end

        //latch TS symbol once the symbol is received
        if ( int_sym_count[NB-1] == 7 && |fhf_ts_s0_rcvd_pulse ) begin
            for ( i=0; i<8; i=i+1 ) begin
                int_ts_sym[i]      <= #TP rx_data[i*8 +: 8];
            end // for
            int_ts_sym_valid[0]    <= #TP fhf_ts_rcvd_pulse[0]; // this pulse is high only if it is a valid TS half
        end
        if ( int_sym_count[NB-1] == 15 ) begin
            for ( i=0; i<8; i=i+1 ) begin
                // store previous clock's in the end of TS
                pre_ts_sym[i]      <= #TP int_ts_sym[i];
            end // for
            pre_ts_sym_valid[0]    <= #TP int_ts_sym_valid[0];
        end
        if ( int_sym_count[NB-1] == 15 && |shf_ts_s0_rcvd_pulse ) begin
            for ( i=0; i<8; i=i+1 ) begin
                int_ts_sym[i+8]    <= #TP rx_data[i*8 +: 8];
                // store sym8-15 in the end of TS
                pre_ts_sym[i+8]    <= #TP rx_data[i*8 +: 8];
            end // for
            int_ts_sym_valid[1]    <= #TP shf_ts_rcvd_pulse[0]; // this pulse is high only if it is a valid TS half
            pre_ts_sym_valid[1]    <= #TP shf_ts_rcvd_pulse[0];
        end

        if ( smlh_ts_spd_chg_rcvd_clr ) begin // clear latched speed_change bit after speed change
            in6_ts_sym_rcvd[5][7]  <= #TP 1'b0;
            int_ts_sym[5][7]       <= #TP 1'b0;
            pre_ts_sym[5][7]       <= #TP 1'b0;
            in6_ts_sym_rcvd[12][7] <= #TP 1'b0; // sym13[7]
            int_ts_sym[13][7]      <= #TP 1'b0;
            pre_ts_sym[13][7]      <= #TP 1'b0;
        end
    end
end // latch_ts_symbol_other_signal_PROC

// align ts0 Sym1-5 fields into ts1 to simplify the implementation so that processing ts0 fileds is the same as ts1 in the other modules
// First HalF
wire  [RXSB_WD-1:0] fhf_ts0_ec_01b;
wire  [RXSB_WD-1:0] fhf_ts0_ec_00b;
wire  [RXSB_WD-1:0] fhf_ts0_ec_10b;
wire  [RXSB_WD-1:0] fhf_ts0_ec_11b;
wire  [RXSB_WD-1:0] fhf_ts0_init_coef_window;
wire  [RXSB_WD-1:0] fhf_ts0_ec_00_01b;
wire  [RXSB_WD-1:0] fhf_ts0_ec_10b_use_pset_1;
wire  [RXSB_WD-1:0] fhf_ts0_ec_10b_use_pset_0;
wire  [1:0]         fhf_ts0_ec[0:RXSB_WD-1];
wire  [RXSB_WD-1:0] fhf_ts0_rst_eieos;
wire  [RXSB_WD-1:0] fhf_ts0_use_pset;
wire  [5:0]         fhf_ts0_fs[0:RXSB_WD-1];
wire  [3:0]         fhf_ts0_c_m1[0:RXSB_WD-1];
wire  [5:0]         fhf_ts0_lf[0:RXSB_WD-1];
wire  [4:0]         fhf_ts0_c_p1[0:RXSB_WD-1];
wire  [2:0]         fhf_ts0_c_m2[0:RXSB_WD-1];
wire  [5:0]         fhf_ts0_c_0[0:RXSB_WD-1];
wire  [RXSB_WD-1:0] fhf_ts0_rt_eq_ext; // retimer eq extend
wire  [3:0]         fhf_ts0_tx_pset[0:RXSB_WD-1];
assign fhf_ts0_ec_01b[0] = {in6_ts_sym_rcvd[1][3], in6_ts_sym_rcvd[1][1]} == 2'b01;
assign fhf_ts0_ec_00b[0] = {in6_ts_sym_rcvd[1][3], in6_ts_sym_rcvd[1][1]} == 2'b00;
assign fhf_ts0_ec_10b[0] = {in6_ts_sym_rcvd[1][3], in6_ts_sym_rcvd[1][1]} == 2'b10;
assign fhf_ts0_ec_11b[0] = {in6_ts_sym_rcvd[1][3], in6_ts_sym_rcvd[1][1]} == 2'b11;
// usp detects ts0 in eq1 when ec = 10b or dsp in eq2 when ec = 11b. doing so is for eq master to receive coef as its initial fine tuning coef
assign fhf_ts0_init_coef_window[0] = (cfg_upstream_port & smlh_ltssm_state == S_RCVRY_EQ1 & fhf_ts0_ec_10b[0]) | (~cfg_upstream_port & smlh_ltssm_state == S_RCVRY_EQ2 & fhf_ts0_ec_11b[0]);
assign fhf_ts0_ec_00_01b[0] = fhf_ts0_ec_01b[0] | fhf_ts0_ec_00b[0];
assign fhf_ts0_ec_10b_use_pset_1[0] = (fhf_ts0_ec_10b[0] &  in6_ts_sym_rcvd[1][7]);
assign fhf_ts0_ec_10b_use_pset_0[0] = (fhf_ts0_ec_10b[0] & ~in6_ts_sym_rcvd[1][7]) | fhf_ts0_init_coef_window[0];
assign fhf_ts0_ec[0]         = {in6_ts_sym_rcvd[1][3], in6_ts_sym_rcvd[1][1]};
assign fhf_ts0_rst_eieos[0]  = in6_ts_sym_rcvd[1][5];
assign fhf_ts0_use_pset[0]   = in6_ts_sym_rcvd[1][7];
assign fhf_ts0_fs[0]         = fhf_ts0_ec_00_01b[0]         ? {in6_ts_sym_rcvd[3][3], in6_ts_sym_rcvd[3][1], in6_ts_sym_rcvd[2][7], in6_ts_sym_rcvd[2][5], in6_ts_sym_rcvd[2][3], in6_ts_sym_rcvd[2][1]} : 0;
assign fhf_ts0_c_m1[0]       = fhf_ts0_ec_10b_use_pset_0[0] ? {in6_ts_sym_rcvd[2][7], in6_ts_sym_rcvd[2][5], in6_ts_sym_rcvd[2][3], in6_ts_sym_rcvd[2][1]} : 0;
assign fhf_ts0_lf[0]         = fhf_ts0_ec_00_01b[0]         ? {in6_ts_sym_rcvd[4][7], in6_ts_sym_rcvd[4][5], in6_ts_sym_rcvd[4][3], in6_ts_sym_rcvd[4][1], in6_ts_sym_rcvd[3][7], in6_ts_sym_rcvd[3][5]} : 0;
assign fhf_ts0_c_p1[0]       = fhf_ts0_ec_10b_use_pset_0[0] ? {in6_ts_sym_rcvd[4][1], in6_ts_sym_rcvd[3][7], in6_ts_sym_rcvd[3][5], in6_ts_sym_rcvd[3][3], in6_ts_sym_rcvd[3][1]} : 0;
assign fhf_ts0_c_m2[0]       = fhf_ts0_ec_10b_use_pset_0[0] ? {in6_ts_sym_rcvd[4][7], in6_ts_sym_rcvd[4][5], in6_ts_sym_rcvd[4][3]} : 0;
assign fhf_ts0_c_0[0]        = fhf_ts0_ec_10b_use_pset_0[0] ? {in6_ts_sym_rcvd[6][3], in6_ts_sym_rcvd[6][1], in6_ts_sym_rcvd[5][7], in6_ts_sym_rcvd[5][5], in6_ts_sym_rcvd[5][3], in6_ts_sym_rcvd[5][1]} : 0;
assign fhf_ts0_rt_eq_ext[0]  = in6_ts_sym_rcvd[6][5];
assign fhf_ts0_tx_pset[0]    = (fhf_ts0_ec_00_01b[0] || fhf_ts0_ec_10b_use_pset_1[0]) ? {in6_ts_sym_rcvd[5][7], in6_ts_sym_rcvd[5][5], in6_ts_sym_rcvd[5][3], in6_ts_sym_rcvd[5][1]} : 0;
// Second HalF
wire  [RXSB_WD-1:0] shf_ts0_ec_01b;
wire  [RXSB_WD-1:0] shf_ts0_ec_00b;
wire  [RXSB_WD-1:0] shf_ts0_ec_10b;
wire  [RXSB_WD-1:0] shf_ts0_ec_11b;
wire  [RXSB_WD-1:0] shf_ts0_init_coef_window;
wire  [RXSB_WD-1:0] shf_ts0_ec_00_01b;
wire  [RXSB_WD-1:0] shf_ts0_ec_10b_use_pset_1;
wire  [RXSB_WD-1:0] shf_ts0_ec_10b_use_pset_0;
wire  [1:0]         shf_ts0_ec[0:RXSB_WD-1];
wire  [RXSB_WD-1:0] shf_ts0_rst_eieos;
wire  [RXSB_WD-1:0] shf_ts0_use_pset;
wire  [5:0]         shf_ts0_fs[0:RXSB_WD-1];
wire  [3:0]         shf_ts0_c_m1[0:RXSB_WD-1];
wire  [5:0]         shf_ts0_lf[0:RXSB_WD-1];
wire  [4:0]         shf_ts0_c_p1[0:RXSB_WD-1];
wire  [2:0]         shf_ts0_c_m2[0:RXSB_WD-1];
wire  [5:0]         shf_ts0_c_0[0:RXSB_WD-1];
wire  [RXSB_WD-1:0] shf_ts0_rt_eq_ext;
wire  [3:0]         shf_ts0_tx_pset[0:RXSB_WD-1];
assign shf_ts0_ec_01b[0] = {in6_ts_sym_rcvd[7][3], in6_ts_sym_rcvd[7][1]} == 2'b01;
assign shf_ts0_ec_00b[0] = {in6_ts_sym_rcvd[7][3], in6_ts_sym_rcvd[7][1]} == 2'b00;
assign shf_ts0_ec_10b[0] = {in6_ts_sym_rcvd[7][3], in6_ts_sym_rcvd[7][1]} == 2'b10;
assign shf_ts0_ec_11b[0] = {in6_ts_sym_rcvd[7][3], in6_ts_sym_rcvd[7][1]} == 2'b11;
assign shf_ts0_init_coef_window[0] = (cfg_upstream_port & smlh_ltssm_state == S_RCVRY_EQ1 & shf_ts0_ec_10b[0]) | (~cfg_upstream_port & smlh_ltssm_state == S_RCVRY_EQ2 & shf_ts0_ec_11b[0]);
assign shf_ts0_ec_00_01b[0] = shf_ts0_ec_01b[0] | shf_ts0_ec_00b[0];
assign shf_ts0_ec_10b_use_pset_1[0] = (shf_ts0_ec_10b[0] &  in6_ts_sym_rcvd[7][7]);
assign shf_ts0_ec_10b_use_pset_0[0] = (shf_ts0_ec_10b[0] & ~in6_ts_sym_rcvd[7][7]) | shf_ts0_init_coef_window[0];
assign shf_ts0_ec[0]         = {in6_ts_sym_rcvd[7][3], in6_ts_sym_rcvd[7][1]};
assign shf_ts0_rst_eieos[0]  = in6_ts_sym_rcvd[7][5];
assign shf_ts0_use_pset[0]   = in6_ts_sym_rcvd[7][7];
assign shf_ts0_fs[0]         = shf_ts0_ec_00_01b[0]         ? {in6_ts_sym_rcvd[9][3],  in6_ts_sym_rcvd[9][1],  in6_ts_sym_rcvd[8][7],  in6_ts_sym_rcvd[8][5],  in6_ts_sym_rcvd[8][3],   in6_ts_sym_rcvd[8][1]} : 0;
assign shf_ts0_c_m1[0]       = shf_ts0_ec_10b_use_pset_0[0] ? {in6_ts_sym_rcvd[8][7],  in6_ts_sym_rcvd[8][5],  in6_ts_sym_rcvd[8][3],  in6_ts_sym_rcvd[8][1]} : 0;
assign shf_ts0_lf[0]         = shf_ts0_ec_00_01b[0]         ? {in6_ts_sym_rcvd[10][7], in6_ts_sym_rcvd[10][5], in6_ts_sym_rcvd[10][3], in6_ts_sym_rcvd[10][1], in6_ts_sym_rcvd[9][7],   in6_ts_sym_rcvd[9][5]} : 0;
assign shf_ts0_c_p1[0]       = shf_ts0_ec_10b_use_pset_0[0] ? {in6_ts_sym_rcvd[10][1], in6_ts_sym_rcvd[9][7],  in6_ts_sym_rcvd[9][5],  in6_ts_sym_rcvd[9][3],  in6_ts_sym_rcvd[9][1]} : 0;
assign shf_ts0_c_m2[0]       = shf_ts0_ec_10b_use_pset_0[0] ? {in6_ts_sym_rcvd[10][7], in6_ts_sym_rcvd[10][5], in6_ts_sym_rcvd[10][3]} : 0;
assign shf_ts0_c_0[0]        = shf_ts0_ec_10b_use_pset_0[0] ? {in6_ts_sym_rcvd[12][3], in6_ts_sym_rcvd[12][1], in6_ts_sym_rcvd[11][7], in6_ts_sym_rcvd[11][5],  in6_ts_sym_rcvd[11][3], in6_ts_sym_rcvd[11][1]} : 0;
assign shf_ts0_rt_eq_ext[0]  = in6_ts_sym_rcvd[12][5];
assign shf_ts0_tx_pset[0]    = (shf_ts0_ec_00_01b[0] || shf_ts0_ec_10b_use_pset_1[0]) ? {in6_ts_sym_rcvd[11][7], in6_ts_sym_rcvd[11][5], in6_ts_sym_rcvd[11][3], in6_ts_sym_rcvd[11][1]} : 0;

wire [RXSB_WD-1:0] ts0_rcvd_i = ~({RXSB_WD{int_ts_error}} | (ts2_rcvd | ts1_rcvd)) & ts0_rcvd;

reg [7:0] int_ts_sym_rcvd_d[1:6];
//align fhf_ts_sym with pcnt 
always @(posedge core_clk or negedge core_rst_n) begin : int_ts_sym_rcvd_d_PROC
  integer j;
  if(!core_rst_n)begin
    for (j=1; j<=6; j=j+1 ) begin
      int_ts_sym_rcvd_d[j] <= #TP 0;
    end
  end else begin
    if( int_sym_count[NB2-1]==15 )
        for (j=1; j<=6; j=j+1 ) begin
          int_ts_sym_rcvd_d[j] <= #TP int_ts_sym_rcvd[j];
        end
  end
end
always @* begin : int_ts_sym_rcvd_PROC
    integer i;
    integer tmp_i;

    for ( i=1; i<=12; i=i+1 ) begin // if int_ts_error, reset the int_ts_sym_rcvd to 0 immediately
        tmp_i = (i>6) ? i-6-1 : i-1;
        int_ts_sym_rcvd[i] = int_ts_error ? 0 : in6_ts_sym_rcvd[i];
    end

    if ( ts0_rcvd_i[0] ) begin // if ts0, mapping in6_ts_sym_rcvd (TS0) to int_ts_sym_rcvd (TS1)
        // ts1_sym1 = {use_pset, tx_pset[3:0], reset_eieos, ec[1:0]
        // ts1_sym8
        int_ts_sym_rcvd[1]  = {fhf_ts0_use_pset[0], fhf_ts0_tx_pset[0], fhf_ts0_rst_eieos[0], fhf_ts0_ec[0]};
        int_ts_sym_rcvd[7]  = {shf_ts0_use_pset[0], shf_ts0_tx_pset[0], shf_ts0_rst_eieos[0], shf_ts0_ec[0]};

        // ts1_sym2 = ts0_ec_00_01b ? FS : C0
        int_ts_sym_rcvd[2]  = fhf_ts0_ec_00_01b[0] ? {fhf_ts0_rt_eq_ext[0], in6_ts_sym_rcvd[2][6], fhf_ts0_fs[0]} : {fhf_ts0_rt_eq_ext[0], in6_ts_sym_rcvd[2][6], fhf_ts0_c_0[0]};
        int_ts_sym_rcvd[8]  = shf_ts0_ec_00_01b[0] ? {shf_ts0_rt_eq_ext[0], in6_ts_sym_rcvd[8][6], shf_ts0_fs[0]} : {shf_ts0_rt_eq_ext[0], in6_ts_sym_rcvd[8][6], shf_ts0_c_0[0]};

        // ts1_sym3 = ts0_ec_00_01b ? {reject, Reserved, LF} : {reject, C-2[2:0], C-1[3:0]}
        int_ts_sym_rcvd[3]  = fhf_ts0_ec_00_01b[0] ? {in6_ts_sym_rcvd[3][7], in6_ts_sym_rcvd[3][6], fhf_ts0_lf[0]} : {in6_ts_sym_rcvd[3][7], fhf_ts0_c_m2[0], fhf_ts0_c_m1[0]};
        int_ts_sym_rcvd[9]  = shf_ts0_ec_00_01b[0] ? {in6_ts_sym_rcvd[9][7], in6_ts_sym_rcvd[9][6], shf_ts0_lf[0]} : {in6_ts_sym_rcvd[9][7], shf_ts0_c_m2[0], shf_ts0_c_m1[0]};

        // ts1_sym4 = C+1
        int_ts_sym_rcvd[4]  = {in6_ts_sym_rcvd[4][7],  in6_ts_sym_rcvd[4][6],  in6_ts_sym_rcvd[4][5],  fhf_ts0_c_p1[0]};
        int_ts_sym_rcvd[10] = {in6_ts_sym_rcvd[10][7], in6_ts_sym_rcvd[10][6], in6_ts_sym_rcvd[10][5], shf_ts0_c_p1[0]};
    end
end // int_ts_sym_rcvd_PROC

//get link#/lane# = PAD
always @(posedge core_clk or negedge core_rst_n) begin : ts_link_lane_num_is_k237_PROC
    if (!core_rst_n) begin
        ts_link_num_is_k237_i1  <= #TP 0;
        ts_lane_num_is_k237_i1  <= #TP 0;
        ts_link_num_is_k237_i2  <= #TP 0;
        ts_lane_num_is_k237_i2  <= #TP 0;
    end else begin
        ts_link_num_is_k237_i1  <= #TP (rx_dv & int_sym_count[1]==1  & rx_bv[1] & int_in_ts[1]) ? (rx_data[1*8 +: 8] == `K237_8B) : ts_link_num_is_k237_i1;
        ts_lane_num_is_k237_i1  <= #TP (rx_dv & int_sym_count[2]==2  & rx_bv[2] & int_in_ts[2]) ? (rx_data[2*8 +: 8] == `K237_8B) : ts_lane_num_is_k237_i1;
        ts_link_num_is_k237_i2  <= #TP (rx_dv & int_sym_count[1]==9  & rx_bv[1] & int_in_ts[1]) ? (rx_data[1*8 +: 8] == `K237_8B) : ts_link_num_is_k237_i2;
        ts_lane_num_is_k237_i2  <= #TP (rx_dv & int_sym_count[2]==10 & rx_bv[2] & int_in_ts[2]) ? (rx_data[2*8 +: 8] == `K237_8B) : ts_lane_num_is_k237_i2;
    end
end // ts_link_lane_num_is_k237_PROC

always @(posedge core_clk or negedge core_rst_n) begin : ts_link_lane_num_is_k237_update_PROC
    if (!core_rst_n) begin
        ts_link_num_is_k237_1 <= #TP 0;
        ts_lane_num_is_k237_1 <= #TP 0;
        ts_link_num_is_k237_2 <= #TP 0;
        ts_lane_num_is_k237_2 <= #TP 0;
    end else begin
        if ( fhf_ts_rcvd_pulse[0] ) begin //first half
            ts_link_num_is_k237_1[0] <= #TP ts_link_num_is_k237_i1[0];
            ts_lane_num_is_k237_1[0] <= #TP ts_lane_num_is_k237_i1[0];
        end

        if ( shf_ts_rcvd_pulse[0] ) begin //second half
            ts_link_num_is_k237_2[0] <= #TP ts_link_num_is_k237_i2[0];
            ts_lane_num_is_k237_2[0] <= #TP ts_lane_num_is_k237_i2[0];
        end
    end
end // ts_link_lane_num_is_k237_update_PROC

reg  ts_link_num_is_k237_1_0_d;
reg  ts_lane_num_is_k237_1_0_d;

//align fhf_ts_sym with pcnt 
always @(posedge core_clk or negedge core_rst_n) begin : ts_link_lane_num_is_k237_update_fhf_delay_PROC
  if(!core_rst_n)begin
    ts_link_num_is_k237_1_0_d <= #TP 0;
    ts_lane_num_is_k237_1_0_d <= #TP 0;
  end else begin
    if( int_sym_count[NB2-1]==15 ) begin
      ts_link_num_is_k237_1_0_d <= #TP ts_link_num_is_k237_1[0];
      ts_lane_num_is_k237_1_0_d <= #TP ts_lane_num_is_k237_1[0];
    end
  end
end

// Output assignments
assign smseq_ts_info               = ~priority_shf_sel ? {8'h0,int_ts_sym_rcvd_d[6] ,int_ts_sym_rcvd_d[5] ,int_ts_sym_rcvd_d[4] ,int_ts_sym_rcvd_d[3],int_ts_sym_rcvd_d[2],int_ts_sym_rcvd_d[1]} :
                                                         {8'h0,int_ts_sym_rcvd[12],int_ts_sym_rcvd[11],int_ts_sym_rcvd[10],int_ts_sym_rcvd[9],int_ts_sym_rcvd[8],int_ts_sym_rcvd[7]} ;
assign smseq_ts_lanen_linkn_pad    = ~priority_shf_sel ? {ts_lane_num_is_k237_1_0_d,ts_link_num_is_k237_1_0_d} :
                                                         {ts_lane_num_is_k237_2[0],ts_link_num_is_k237_2[0]};
assign smseq_eqts_info             = ~priority_shf_sel ? {int_ts_sym_rcvd_d[4] ,int_ts_sym_rcvd_d[3],int_ts_sym_rcvd_d[2],int_ts_sym_rcvd_d[1]} :
                                                         {int_ts_sym_rcvd[10],int_ts_sym_rcvd[9],int_ts_sym_rcvd[8],int_ts_sym_rcvd[7]} ;
assign smseq_ts0_rcvd            = |(ts0_rcvd & {RXSB_WD{rlock_eies_rcvd}});
assign smseq_ts1_rcvd            = |(ts1_rcvd & {RXSB_WD{rlock_eies_rcvd}});
assign smseq_ts2_rcvd            = |(ts2_rcvd & {RXSB_WD{rlock_eies_rcvd}});
assign smseq_ts_error            = |ts_error;
assign smseq_sds_rcvd            = sds_rcvd_i;
assign smseq_ineies_rcv          = |eies_rcvd_pulse;
assign smseq_inskip_rcv          = |inskip_rcv;
assign smseq_ts0_rcvd_pulse_o    = |smseq_ts0_rcvd_pulse;
assign smseq_ts1_rcvd_pulse_o    = |smseq_ts1_rcvd_pulse;
assign smseq_ts2_rcvd_pulse_o    = |smseq_ts2_rcvd_pulse;

// detect OS Block
wire [RXSB_WD-1:0] int_rx_ts0;
wire [RXSB_WD-1:0] int_rx_ts1;
wire [RXSB_WD-1:0] int_rx_ts2;
reg  rxosblock_d;
reg  rx_ts0_d;
reg  rx_ts1_d;
reg  rx_ts2_d;

assign int_rxosblock[0] = (~rx_err[0] & rx_dv & rxstartblock[0] & (rxsyncheader[1:0] == `SYNC_OS_BLOCK));
assign int_rx_ts0[0]    = rx_ts0_0[0] & (int_sym_count[0] == 0 | int_sym_count[0] == 8);
assign int_rx_ts1[0]    = rx_ts1_0[0] & (int_sym_count[0] == 0 | int_sym_count[0] == 8);
assign int_rx_ts2[0]    = rx_ts2_0[0] & (int_sym_count[0] == 0 | int_sym_count[0] == 8);

always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        rxosblock_d         <= #TP 0;
        rx_ts0_d            <= #TP 0;
        rx_ts1_d            <= #TP 0;
        rx_ts2_d            <= #TP 0;
    end else begin
        if ( int_rxosblock[0] )
            rxosblock_d <= #TP 1'b1;
        else if ( rxstartblock[0] )
            rxosblock_d <= #TP 1'b0;

        if ( int_rx_ts0[0] )
            rx_ts0_d    <= #TP 1'b1;
        else if ( rxstartblock[0] )
            rx_ts0_d    <= #TP 1'b0;

        if ( int_rx_ts1[0] )
            rx_ts1_d    <= #TP 1'b1;
        else if ( rxstartblock[0] )
            rx_ts1_d    <= #TP 1'b0;

        if ( int_rx_ts2[0] )
            rx_ts2_d    <= #TP 1'b1;
        else if ( rxstartblock[0] )
            rx_ts2_d    <= #TP 1'b0;
    end
end

assign rxosblock[0] = int_rxosblock[0] | (!rxstartblock[0] & rxosblock_d);
assign rx_ts0[0]    = (int_rx_ts0[0] | rx_ts0_d) & rxosblock[0];
assign rx_ts1[0]    = (int_rx_ts1[0] | rx_ts1_d) & rxosblock[0];
assign rx_ts2[0]    = (int_rx_ts2[0] | rx_ts2_d) & rxosblock[0];

assign ltssm_in_compliance = smlh_ltssm_in_compliance;
assign int_rxdatablock[0] = (rx_dv && rxstartblock[0] && (rxsyncheader[1:0] == `SYNC_DATA_BLOCK));

always @(posedge core_clk or negedge core_rst_n) begin : rxdatablock_delay_PROC
    if(!core_rst_n) begin
        rxdatablock_d         <= #TP '0;
    end 
    else begin
        if(~ltssm_in_compliance) begin
            rxdatablock_d     <= #TP '0;
        end
        else if (rx_dv && rxstartblock) begin
            rxdatablock_d     <= #TP rxsyncheader == `SYNC_DATA_BLOCK;
        end
    end
end // rxdatablock_delay_PROC

assign rxdatablock = int_rxdatablock | (!rxstartblock & rxdatablock_d);

always_comb begin : symbol_error_PROC
    sym_error = '0;
    for(int i = 0; i < NB; i++) begin
        if(i < active_nb) begin
            if(i < 16) begin
                sym_error[i] = rx_dv & rxdatablock[0] & (rxdata[8*i +: 8] != 8'h00);
            end
        end
    end
end

//have to latch rx_dv as rx_dv contains DataSkip which can make rx_dv low
//so cannot directly use rx_dv to indicate Locked
always @(posedge core_clk or negedge core_rst_n) begin : latched_rxdata_dv_PROC
    if (!core_rst_n) begin
        latched_rxdata_dv <= #TP 0;
    end
    else if (!ltssm_in_compliance) begin
        latched_rxdata_dv <= #TP 0;
    end
    else if (rx_dv && (current_data_rate == `GEN6_RATE)) begin
        latched_rxdata_dv <= #TP 1;
    end
end // latched_rxdata_dv_PROC

always_comb begin : symbol_error_count_PROC
    sym_error_count = '0;
    for(int i = 0; i < NB; i++) begin
        if(i < active_nb) begin
            if(sym_error[i]) begin
              sym_error_count = $bits(sym_error_count)'(sym_error_count + 1);
            end
        end
    end
end

always @(posedge core_clk or negedge core_rst_n) begin : smseq_error_count_PROC
    if(!core_rst_n) begin
        smseq_error_count <= #TP '0;
    end
    else if(~ltssm_in_compliance) begin//reset to 0 when entry to Compliance
        smseq_error_count <= #TP '0;
    end
    //if locked (rx_dv=1), lock bit smseq_error_count[7] = 1
    else if(latched_rxdata_dv) begin
        smseq_error_count[7] <= #TP 1;
        //increments until 127 (saturation)
        if((smseq_error_count[6:0] + sym_error_count) >= 127) begin
            smseq_error_count[6:0] <= #TP 127;
        end
        else begin
            smseq_error_count[6:0] <= #TP $bits(smseq_error_count[6:0])'(smseq_error_count[6:0] + sym_error_count);
        end
    end
end // smseq_err_count_PROC


endmodule
