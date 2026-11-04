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
// ---    $Revision: #9 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/smlh_seq_finder.sv#9 $
// -------------------------------------------------------------------------
// --- Module Description: Receive MAC Layer Handler Sequence Finder
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"

 
 module smlh_seq_finder
 import DWC_pcie_core_pkg::ltssm_state_e;
 import DWC_pcie_core_pkg::S_DETECT_QUIET;
 import DWC_pcie_core_pkg::S_DETECT_ACT;
#(
    parameter   INST              = 0,                    // The uniquifying parameter for each port logic instance.
    parameter   TP                = `TP,                  // Clock to Q delay (simulator insurance)
    parameter   NL                = `CX_NL,               // Max number of lanes supported
    parameter   NB                = `CX_NB,               // Number of symbols (bytes) per clock cycle
    parameter   AW                = `CX_ANB_WD,           // Width of the active number of bytes
    parameter  EQTS_WD            = 32,                   // concantenation of EQ TS symbols {9,8,7,6}
    parameter RXSB_WD             = `CX_MAC_SB_WD,        // Width of the start block
    parameter RXSH_WD             = `CX_MAC_SH_WD,        // Width of the sync header
    parameter   NOSB              = (NB>=16 ? NB/16 : 1),      // Number of OS blocks to be handled by the logic simultaneously; ceil(NB/16); used to size all per-TS signals

    parameter DCB_WD              = (NB>=8 ? NB/8 : 1),   // Width of the DC balance info
    parameter  TSFD_WD            = `CX_TS_FIELD_CONTROL_WD, // sym7,6,5,4,3,2,1
    parameter  G12_NB             = `CX_NB_GEN2           // Max Number of symbols (bytes) per clock cycle for Gen1/Gen2 specific modules
)

                        (
    input                    core_clk,
    input                    core_rst_n,
    input                    ltssm_lane_flip_ctrl_chg_pulse,
    input                    smlh_link_up,
    input                    smlh_link_in_training,
    input   [AW-1:0]         active_nb,
    input                    smlh_in_rl0s,                 // LTSSM is in Rx.L0s
    input   [NL-1:0]         smlh_keep_rcvrylock_lane,     // LTSSM to keep Recovery.RcvrLock
    input                    cfg_ts2_lid_deskew,           // ts2/skp/eieos -> idle do deskew
    input   [AW-1:0]         active_nb_gen34,              // active number of symbols for gen34. bit0=1s, bit1=2s, bit2=4s, bit3=8s ,bit4=16s
    input   [NL-1:0]         rxdata_dv_i,
    input   [NL-1:0]         rxaligned_i,
    input   [(NL*NB*8)-1:0]  rxdata_i,
    input   [(NL*NB)-1:0]    rxdatak_i,
    input   [(NL*NB)-1:0]    rxerror_i,
    input   [NL-1:0]         rxskipremoved_i,                // PHY removed SKP symbol aligning to COM or RxStartBlock
    input   ltssm_state_e    smlh_ltssm_state_wire,          // Current state of Link Training and Status State Machine before FF for high fanout. 
    input                    cfg_upstream_port,
    input                    cfg_elastic_buffer_mode,
    input                    cfg_polarity_mode,              // 0: polarity detection in Polling.Active 1: polarity detection in Polling.Compliance
    input   [2:0]            current_data_rate,
    input                    smlh_ts_spd_chg_rcvd_clr,
    input   [NL-1:0]         rmlh_deskew_ds_g6,
    input                    ltssm_clear,                  // used to clear TS persistency count on a ltssm state transition
    input                    ltssm_mod_ts,                 // both sides support Modified TS
    input   [NL-1:0]           descrambled_rxdata_dv,
    input   [(NL*NB*8)-1:0]    descrambled_rxdata,
    input   [(NL*RXSB_WD)-1:0] descrambled_rxstartblock,
    input   [(NL*RXSB_WD)-1:0] descrambled_ints1,
    input   [(NL*RXSB_WD)-1:0] descrambled_ints2,
    input   [(NL*RXSB_WD)-1:0] descrambled_inskp,
    input   [(NL*RXSB_WD)-1:0] descrambled_ineie,
    input   [(NL*RXSB_WD)-1:0] descrambled_eie_det,
    input   [(NL*RXSB_WD)-1:0] descrambled_insds,
    input   [NL-1:0]           descrambled_rxaligned,
    input   [(NL*RXSH_WD)-1:0] descrambled_rxsyncheader,
    input   [(NL*NB)-1:0]      descrambled_rxerror,
    input   [NL-1:0][RXSB_WD-1:0][4:0] descrambled_rxdata_osfound, // OS detection flag
    input   [(NL*DCB_WD)-1:0]  descrambled_rxdata_dcb,
    input                    smlh_ltssm_in_compliance,           
    input                    smlh_ltssm_in_rcvrylock,
    input                    ltssm_state_rcvry_eq,
    input                    cfg_enter_compliance,        // Enter Compliance bit in LC2
    input                    cfg_gen3_dc_balance_disable,
    input                    sticky_rst_n,                   // power reset
    input   [10:0]           xmtbyte_ts_pcnt,
    input                    xmtbyte_ts1_sent,
    input                    xmtbyte_skip_sent,
    input                    xmtbyte_eies_sent,
    input                    int_directed_speed_change,

    //----------------- outputs--------------------------------------------
    output  [NL*TSFD_WD-1:0] smseq_ts_info_o,               // sym7-1
    output  [NL*64-1:0]      smseq_mt_info_o,               // sym15-8
    output  [NL*2-1:0]       smseq_ts_lanen_linkn_pad_o,    // pad-lane, pad-link
    output  [NL*4-1:0]       smseq_ts_rcvd_mtx_pcnt_o,      // persistency count of matching Tx
    output  [NL*4-1:0]       smseq_ts_rcvd_pcnt_o,          // persistency count of purely rcvd TS
    output  [NL*2-1:0]       smseq_ts_rcvd_cond_pcnt_o,     // persistency count with conditions
    output  [NL-1:0]         smseq_inskip_rcv_o,
    output  [NL-1:0]         smseq_sds_rcvd_o,
    output  [NL-1:0]         smseq_ts0_rcvd_o,
    output  [NL-1:0]         smseq_ts0_rcvd_pulse_o,
    output  [NL-1:0]         smseq_ts1_rcvd_o,
    output  [NL-1:0]         smseq_ts2_rcvd_o,
    output  [NL-1:0]         smseq_ts1_rcvd_pulse_to_smlh_o,
    output  [NL-1:0]         smseq_ts2_rcvd_pulse_to_smlh_o,
    output  [NL-1:0]         smseq_ts1_rcvd_pulse_to_rmlh_o,
    output  [NL-1:0]         smseq_ts2_rcvd_pulse_to_rmlh_o,
    output  [NL-1:0]         smseq_mod_ts1_rcvd_pulse_o,
    output  [NL-1:0]         smseq_mod_ts2_rcvd_pulse_o,
    output  [NL*4-1:0]       smseq_loc_ts2_rcvd_o,
    output  [NL*4-1:0]       smseq_in_skp_o,
    output  [NL-1:0]         smseq_fts_skp_do_deskew_o,
    output  [NL-1:0]         smseq_ts_error_o,
    output  [NL-1:0]         smseq_ineies_rcv_o,            // Electrical Idle Exit OS signal
    output  [NL-1:0]         smseq_mcs_rcvd_o,              // Modified Compliance Sequence detected
    output  [NL*4-1:0]       smseq_loc_eies_rcvd_o,
    output  [NL-1:0]         smseq_invalid_os_o,            // Invalid os flag for Flit Error Logging Capability
    output  [NL-1:0]         smseq_os_corrected_o,          // OS corrected flag for Flit Error Logging Capability
    output  [NL*EQTS_WD-1:0] smseq_eqts_info_o,             // concantenation of content of TS symbols {9,8,7,6}
    output  [NL*4-1:0]       smseq_ts_rcvd_s6s9_pcnt_o,     // persistency count for all lanes
    output  [NL*8-1:0]       smseq_g3_error_count_o,        // from data block of mod compliance pattern
    output  [NL-1:0]         smseq_rcvr_pol_reverse_o
    ,
    output  [NL*8-1:0]       smseq_mcs_sts_o,
    output  [NL-1:0]         smseq_fts_rcvd_pulse_o,
    output  [NL*64-1:0]      smseq_ts_debug_info_o
);

localparam G5_NB       = (NB==32) ? `CX_NB_GEN5 : NB;
//declared signals
typedef struct packed {
    logic   [NL-1:0]         rxdata_dv;
    logic   [NL-1:0]         rxaligned;
    logic   [(NL*NB*8)-1:0]  rxdata;
    logic   [(NL*NB)-1:0]    rxdatak;
    logic   [(NL*NB)-1:0]    rxerror;
    logic   [NL-1:0]         rxskipremoved;
    } smseq_in_gen12_data_t ;

// output to smlh(smlh_link/eqctl...(Other than deskew)) (have pipe-line here.)
typedef struct packed {
    logic  [NL*TSFD_WD-1:0]    smseq_ts_info;
    logic  [NL*64-1:0]         smseq_mt_info;
    logic  [NL*2-1:0]          smseq_ts_lanen_linkn_pad;
    logic  [NL*4-1:0]          smseq_ts_rcvd_mtx_pcnt;
    logic  [NL*4-1:0]          smseq_ts_rcvd_pcnt;
    logic  [NL*2-1:0]          smseq_ts_rcvd_cond_pcnt;
    logic  [NL-1:0]            smseq_inskip_rcv;
    logic  [NL-1:0]            smseq_sds_rcvd;
    logic  [NL-1:0]            smseq_ts0_rcvd;
    logic  [NL-1:0]            smseq_ts0_rcvd_pulse;
    logic  [NL-1:0]            smseq_ts1_rcvd;
    logic  [NL-1:0]            smseq_ts2_rcvd;
    logic  [NL-1:0]            smseq_ts1_rcvd_pulse;
    logic  [NL-1:0]            smseq_ts2_rcvd_pulse;
    logic  [NL-1:0]            smseq_mod_ts1_rcvd_pulse;
    logic  [NL-1:0]            smseq_mod_ts2_rcvd_pulse;
    logic  [NL-1:0]            smseq_ts_error;
    logic  [NL-1:0]            smseq_ineies_rcv;
    logic  [NL-1:0]            smseq_mcs_rcvd;
    logic  [NL-1:0]            smseq_invalid_os;
    logic  [NL-1:0]            smseq_os_corrected;
    logic  [NL*EQTS_WD-1:0]    smseq_eqts_info;
    logic  [NL*4-1:0]          smseq_ts_rcvd_s6s9_pcnt;
    logic  [NL*8-1:0]          smseq_g3_error_count;
    logic  [NL-1:0]            smseq_rcvr_pol_reverse;
    logic  [NL*8-1:0]          smseq_mcs_sts;
    logic  [NL-1:0]            smseq_fts_rcvd_pulse;
    logic  [NL*64-1:0]         smseq_ts_debug_info;
    } smseq_out_smlh_t ;

// output to Deskew (not have pipe-line here. Because Deskew has own pipe-line.)
wire  [NL-1:0]            smseq_ts1_rcvd_pulse_to_rmlh;
wire  [NL-1:0]            smseq_ts2_rcvd_pulse_to_rmlh;
wire  [NL*4-1:0]          smseq_loc_ts2_rcvd;
wire  [NL*4-1:0]          smseq_in_skp;
wire  [NL-1:0]            smseq_fts_skp_do_deskew;
wire  [NL*4-1:0]          smseq_loc_eies_rcvd;

smseq_in_gen12_data_t     smseq_in_pre_gen12_data ;
smseq_in_gen12_data_t     smseq_in_post_gen12_data ;
smseq_out_smlh_t          smseq_out_pre_pipeline ;
smseq_out_smlh_t          smseq_out_post_pipeline ;

logic   [NL-1:0]         rxdata_dv;
logic   [NL-1:0]         rxaligned;
logic   [(NL*NB*8)-1:0]  rxdata;
logic   [(NL*NB)-1:0]    rxdatak;
logic   [(NL*NB)-1:0]    rxerror;
logic   [NL-1:0]         rxskipremoved;
ltssm_state_e            smlh_ltssm_state ;


wire  [(NL*G12_NB*8)-1:0] smseq_g12_rxdata;
wire  [(NL*G12_NB)-1:0]   smseq_g12_rxdatak;
wire  [(NL*G12_NB)-1:0]   smseq_g12_rxerror;
wire  [NL-1:0]            smseq_g12_inskip_rcv;
wire  [NL-1:0]            smseq_g12_sds_rcvd;
wire  [NL-1:0]            smseq_g12_ts1_rcvd;
wire  [NL-1:0]            smseq_g12_ts2_rcvd;
wire  [NL-1:0]            smseq_g12_ts1_rcvd_pulse;
wire  [NL-1:0]            smseq_g12_ts2_rcvd_pulse;
wire  [NL-1:0]            smseq_g12_ts_error;
wire  [(NL*8)-1:0]        smseq_g12_ts_link_num;          // 8 bit link number;
wire  [NL-1:0]            smseq_g12_ts_link_num_is_k237;  // indicates whether or not received Kchar with k237
wire  [(NL*8)-1:0]        smseq_g12_ts_lane_num;          // 8 bit lane number;
wire  [NL-1:0]            smseq_g12_ts_lane_num_is_k237;  // Indicates whether or not received Kchar with k237
wire  [(NL*8)-1:0]        smseq_g12_ts_nfts;              // 8 bits nfts number contained in training sequence
wire  [(NL*5)-1:0]        smseq_g12_ts_link_ctrl;         // 5 bits
wire  [NL-1:0]            smseq_g12_ts_speed_change;      // Requesting to change the speed of operation.
wire  [NL-1:0]            smseq_g12_ts_auto_change;       // Indicate autonomous speed change
wire  [(NL*5)-1:0]        smseq_g12_ts_data_rate;         // Bit 0 = 1, generation 1 (2.5 Gb/s) data rate supported
wire  [NL-1:0]            smseq_g12_ineies_rcv;           // Electrical Idle Exit Level signal
wire  [NL-1:0]            smseq_g12_mcs_rcvd;             // Modified Compliance Sequence detected
wire  [NL-1:0]            smseq_g3_inskip_rcv;
wire  [NL-1:0]            smseq_g3_sds_rcvd;
wire  [NL-1:0]            smseq_g3_ts1_rcvd;
wire  [NL-1:0]            smseq_g3_ts2_rcvd;
wire  [NL-1:0]            smseq_g3_ts1_rcvd_pulse;
wire  [NL-1:0]            smseq_g3_ts2_rcvd_pulse;
wire  [NL-1:0]            smseq_g3_ts_error;
wire  [(NL*8)-1:0]        smseq_g3_ts_link_num;          // 8 bit link number;
wire  [NL-1:0]            smseq_g3_ts_link_num_is_k237;  // indicates whether or not received Kchar with k237
wire  [(NL*8)-1:0]        smseq_g3_ts_lane_num;          // 8 bit lane number;
wire  [NL-1:0]            smseq_g3_ts_lane_num_is_k237;  // Indicates whether or not received Kchar with k237
wire  [(NL*8)-1:0]        smseq_g3_ts_nfts;              // 8 bits nfts number contained in training sequence
wire  [(NL*5)-1:0]        smseq_g3_ts_link_ctrl;         // 5 bits
wire  [NL-1:0]            smseq_g3_ts_speed_change;      // Requesting to change the speed of operation.
wire  [NL-1:0]            smseq_g3_ts_auto_change;       // Indicate autonomous speed change
wire  [(NL*5)-1:0]        smseq_g3_ts_data_rate;         // Bit 0 = 1, generation 1 (2.5 Gb/s) data rate supported
wire  [NL-1:0]            smseq_g3_ineies_rcv;           // Electrical Idle Exit Level signal
wire  [NL*EQTS_WD-1:0]    smseq_g3_eqts_info;
wire  [NL*EQTS_WD-1:0]    smseq_g12_eqts_info;
wire  [NL*4-1:0]          smseq_g12_ts_rcvd_s6s9_pcnt;
wire  [NL*4-1:0]          smseq_g3_ts_rcvd_s6s9_pcnt;
wire  [NL*8-1:0]          smseq_g3_error_count;
wire  [NL-1:0]            smseq_g12_8_st_ts2_s6_rcvd;
wire  [NL-1:0]            smseq_g3_8_st_ts2_s6_rcvd;
wire  [NL-1:0]            smseq_invalid_os;
wire  [NL-1:0]            smseq_os_corrected;

// Pipe-line of smlh_ltssm_state for high fanout. 
// The smlh_ltssm_state_wire is a combinational signal(before FF). So, no timing change by this pipe-line.
always @(posedge core_clk or negedge core_rst_n) begin : smlh_ltssm_state_proc
    if (!core_rst_n) begin
        smlh_ltssm_state <= #TP S_DETECT_QUIET;
    end
    else begin
        smlh_ltssm_state <= #TP smlh_ltssm_state_wire;
    end
end

// ---- piep-line for timing improvement

wire delay_en  = (smlh_ltssm_state != S_DETECT_ACT);  // just for clock gating

localparam REGOUT          = 1 ;
// Need to align to Data and flags for deskew (smseq_loc_ts2_rcvd,smseq_in_skp etc). 
// So can put pipe-line only when CX_RMLH_SCRAMBLE_REGOUT=1
// CX_RMLH_SCRAMBLE_REGOUT is not set only if PCIE_OVER_CIO (Gen1 only).
localparam REGIN_G12       = `CX_RMLH_SCRAMBLE_REGOUT ;

localparam REGOUT_WD       = $bits( smseq_out_post_pipeline  ) ;
localparam REGIN_G12_WD    = $bits( smseq_in_post_gen12_data ) ;


// ---------------------------------------
// pipe-line input (to smlh_link/eqctl)
// ---------------------------------------
delay_n_w_enable
 #(REGIN_G12 ,  REGIN_G12_WD) u_delay_g12  ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(smseq_in_pre_gen12_data), .dout(smseq_in_post_gen12_data));

always_comb begin
    smseq_in_pre_gen12_data.rxdata_dv        = rxdata_dv_i     ;
    smseq_in_pre_gen12_data.rxaligned        = rxaligned_i     ;
    smseq_in_pre_gen12_data.rxdata           = rxdata_i        ;
    smseq_in_pre_gen12_data.rxdatak          = rxdatak_i       ;
    smseq_in_pre_gen12_data.rxerror          = rxerror_i       ;
    smseq_in_pre_gen12_data.rxskipremoved    = rxskipremoved_i ;
end
always_comb begin
    rxdata_dv        = smseq_in_post_gen12_data.rxdata_dv     ;
    rxaligned        = smseq_in_post_gen12_data.rxaligned     ;
    rxdata           = smseq_in_post_gen12_data.rxdata        ;
    rxdatak          = smseq_in_post_gen12_data.rxdatak       ;
    rxerror          = smseq_in_post_gen12_data.rxerror       ;
    rxskipremoved    = smseq_in_post_gen12_data.rxskipremoved ;
end


// ---------------------------------------
// pipe-line input (to smlh_seq_finder3_slv)
// ---------------------------------------
wire   [NL-1:0]             regin_descrambled_rxdata_dv;
wire   [(NL*NB*8)-1:0]      regin_descrambled_rxdata;
wire   [(NL*RXSB_WD)-1:0]   regin_descrambled_ints1;
wire   [(NL*RXSB_WD)-1:0]   regin_descrambled_ints2;
wire   [(NL*RXSB_WD)-1:0]   regin_descrambled_ineie;
wire   [(NL*NB)-1:0]        regin_descrambled_rxerror;
wire   [(NL*RXSB_WD)-1:0]   regin_descrambled_rxstartblock;
wire   [(NL*RXSB_WD)-1:0]   regin_descrambled_inskp;
wire   [(NL*RXSB_WD)-1:0]   regin_descrambled_eie_det;
wire   [(NL*RXSB_WD)-1:0]   regin_descrambled_insds;
wire   [NL-1:0]             regin_descrambled_rxaligned;
wire   [(NL*RXSH_WD)-1:0]   regin_descrambled_rxsyncheader;
wire   [NL-1:0][RXSB_WD-1:0][4:0] regin_descrambled_rxdata_osfound;
wire   [(NL*DCB_WD)-1:0]    regin_descrambled_rxdata_dcb;



localparam REGIN_G3ABOVE          = 1;
localparam DATAPATH_WIDTH_G3ABOVE = NL*(2+7*RXSB_WD) + (NL*NB*8) + (NL*RXSH_WD) + (NL*NB) + $bits(descrambled_rxdata_osfound) + (NL*DCB_WD);

delay_n

 #(REGIN_G3ABOVE, DATAPATH_WIDTH_G3ABOVE) u_delay_data_g3above
(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        (
                  {
                    descrambled_rxdata_dv,
                    descrambled_rxdata,
                    descrambled_rxstartblock,
                    descrambled_ints1,
                    descrambled_ints2,
                    descrambled_inskp,
                    descrambled_ineie,
                    descrambled_eie_det,
                    descrambled_insds,
                    descrambled_rxsyncheader,
                    descrambled_rxaligned,
                    descrambled_rxerror,
                    descrambled_rxdata_osfound
                  , descrambled_rxdata_dcb
                  }
                ),
    .dout       (
                  {
                    regin_descrambled_rxdata_dv,
                    regin_descrambled_rxdata,
                    regin_descrambled_rxstartblock,
                    regin_descrambled_ints1,
                    regin_descrambled_ints2,
                    regin_descrambled_inskp,
                    regin_descrambled_ineie,
                    regin_descrambled_eie_det,
                    regin_descrambled_insds,
                    regin_descrambled_rxsyncheader,
                    regin_descrambled_rxaligned,
                    regin_descrambled_rxerror,
                    regin_descrambled_rxdata_osfound
                  , regin_descrambled_rxdata_dcb
                  }
                 )
);

// Preparing result of ts decoder
localparam DATAPATH_WIDTH_DEC_TS = NL*NB*6;

reg   [NL*NB-1:0]       descrambled_rx_pad;
reg   [NL*NB-1:0]       descrambled_rx_num_v;
reg   [NL*NB-1:0]       descrambled_ts1_id;
reg   [NL*NB-1:0]       descrambled_ts2_id;
reg   [NL*NB-1:0]       descrambled_eqts;
reg   [NL*NB-1:0]       descrambled_rx_rate_v;
reg   [NL*NB-1:0]       descrambled_rx_bv;
wire  [(NL*RXSB_WD)-1:0] descrambled_ints;
wire  [NL*NB-1:0]       regin_descrambled_rx_pad;
wire  [NL*NB-1:0]       regin_descrambled_rx_num_v;
wire  [NL*NB-1:0]       regin_descrambled_ts1_id;
wire  [NL*NB-1:0]       regin_descrambled_ts2_id;
wire  [NL*NB-1:0]       regin_descrambled_eqts;
wire  [NL*NB-1:0]       regin_descrambled_rx_rate_v;

assign descrambled_ints = (descrambled_ints1 | descrambled_ints2);

always@( * ) begin : signal_decoder_ts_PROC
    integer i;
    integer ln;

    descrambled_rx_bv     = 0;
    descrambled_rx_pad    = 0;
    descrambled_rx_num_v  = 0;
    descrambled_ts1_id    = 0;
    descrambled_ts2_id    = 0;
    descrambled_eqts      = 0;
    descrambled_rx_rate_v = 0;

    for (ln=0; ln<NL; ln=ln+1) begin
       descrambled_rx_bv[NB*ln +: NB] =
           (active_nb_gen34[0]) ? (NB)'( { 1{1'b1}} ) :
           (active_nb_gen34[1]) ? (NB)'( { 2{1'b1}} ) :
           (active_nb_gen34[2]) ? (NB)'( { 4{1'b1}} ) :
           (active_nb_gen34[3]) ? (NB)'( { 8{1'b1}} ) :
           {NB{1'b0}}
           ;

      for (i=0; i<NB; i=i+1) begin
        descrambled_rx_pad    [NB*ln + i] = descrambled_rxdata_dv[ln] & (descrambled_rxdata[NB*ln*8 + i*8 +: 8] == `K237_8B) & descrambled_ints[ln*RXSB_WD]  & descrambled_rx_bv[NB*ln + i]; //link/lane number PAD
        descrambled_rx_num_v  [NB*ln + i] = descrambled_rxdata_dv[ln] & (descrambled_rxdata[NB*ln*8 + i*8 +: 8] <= 8'h1f   ) & descrambled_ints[ln*RXSB_WD]  & descrambled_rx_bv[NB*ln + i]; //link/lane number <= 31
        descrambled_ts1_id    [NB*ln + i] = descrambled_rxdata_dv[ln] & (descrambled_rxdata[NB*ln*8 + i*8 +: 8] == `TS1_8B ) & descrambled_ints1[ln*RXSB_WD] & descrambled_rx_bv[NB*ln + i]; //TS1 identifier
        descrambled_ts2_id    [NB*ln + i] = descrambled_rxdata_dv[ln] & (descrambled_rxdata[NB*ln*8 + i*8 +: 8] == `TS2_8B ) & descrambled_ints2[ln*RXSB_WD] & descrambled_rx_bv[NB*ln + i]; //TS2 identifier
        descrambled_eqts      [NB*ln + i] = descrambled_rxdata_dv[ln] & ((8'b10000000 & descrambled_rxdata[NB*ln*8 + i*8 +: 8]) == 8'b10000000) & descrambled_rx_bv[NB*ln + i]; //bit[7]==1b, remove ltssm_in_rcvry to detect eqts
        descrambled_rx_rate_v [NB*ln + i] = descrambled_rxdata_dv[ln] & descrambled_rx_bv[NB*ln + i];
      end
    end
end // signal_decoder_PROC

delay_n

 #(REGIN_G3ABOVE, DATAPATH_WIDTH_DEC_TS) u_delay_dec_ts
(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        (
                  {
                    descrambled_rx_pad,
                    descrambled_rx_num_v,
                    descrambled_ts1_id,
                    descrambled_ts2_id,
                    descrambled_eqts,
                    descrambled_rx_rate_v
                  }
                ),
    .dout       (
                  {
                    regin_descrambled_rx_pad,
                    regin_descrambled_rx_num_v,
                    regin_descrambled_ts1_id,
                    regin_descrambled_ts2_id,
                    regin_descrambled_eqts,
                    regin_descrambled_rx_rate_v
                  }
                 )
);


// ---------------------------------------
// pipe-line ouput(to smlh_link/eqctl)
// ---------------------------------------
delay_n_w_enable
 #(REGOUT,  REGOUT_WD   ) u_delay0     ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(smseq_out_pre_pipeline) , .dout(smseq_out_post_pipeline));

assign smseq_ts_info_o                   = smseq_out_post_pipeline.smseq_ts_info                  ;
assign smseq_mt_info_o                   = smseq_out_post_pipeline.smseq_mt_info                  ;
assign smseq_ts_lanen_linkn_pad_o        = smseq_out_post_pipeline.smseq_ts_lanen_linkn_pad       ;
assign smseq_ts_rcvd_mtx_pcnt_o          = smseq_out_post_pipeline.smseq_ts_rcvd_mtx_pcnt         ;
assign smseq_ts_rcvd_pcnt_o              = smseq_out_post_pipeline.smseq_ts_rcvd_pcnt             ;
assign smseq_ts_rcvd_cond_pcnt_o         = smseq_out_post_pipeline.smseq_ts_rcvd_cond_pcnt        ;
assign smseq_inskip_rcv_o                = smseq_out_post_pipeline.smseq_inskip_rcv               ;
assign smseq_sds_rcvd_o                  = smseq_out_post_pipeline.smseq_sds_rcvd                 ;
assign smseq_ts0_rcvd_o                  = smseq_out_post_pipeline.smseq_ts0_rcvd                 ;
assign smseq_ts0_rcvd_pulse_o            = smseq_out_post_pipeline.smseq_ts0_rcvd_pulse           ;
assign smseq_ts1_rcvd_o                  = smseq_out_post_pipeline.smseq_ts1_rcvd                 ;
assign smseq_ts2_rcvd_o                  = smseq_out_post_pipeline.smseq_ts2_rcvd                 ;
assign smseq_ts1_rcvd_pulse_to_smlh_o    = smseq_out_post_pipeline.smseq_ts1_rcvd_pulse           ;
assign smseq_ts2_rcvd_pulse_to_smlh_o    = smseq_out_post_pipeline.smseq_ts2_rcvd_pulse           ;
assign smseq_mod_ts1_rcvd_pulse_o        = smseq_out_post_pipeline.smseq_mod_ts1_rcvd_pulse       ;
assign smseq_mod_ts2_rcvd_pulse_o        = smseq_out_post_pipeline.smseq_mod_ts2_rcvd_pulse       ;
assign smseq_ts_error_o                  = smseq_out_post_pipeline.smseq_ts_error                 ;
assign smseq_ineies_rcv_o                = smseq_out_post_pipeline.smseq_ineies_rcv               ;
assign smseq_mcs_rcvd_o                  = smseq_out_post_pipeline.smseq_mcs_rcvd                 ;
assign smseq_invalid_os_o                = smseq_out_post_pipeline.smseq_invalid_os               ;
assign smseq_os_corrected_o              = smseq_out_post_pipeline.smseq_os_corrected             ;
assign smseq_eqts_info_o                 = smseq_out_post_pipeline.smseq_eqts_info                ;
assign smseq_ts_rcvd_s6s9_pcnt_o         = smseq_out_post_pipeline.smseq_ts_rcvd_s6s9_pcnt        ;
assign smseq_g3_error_count_o            = smseq_out_post_pipeline.smseq_g3_error_count           ;
assign smseq_rcvr_pol_reverse_o          = smseq_out_post_pipeline.smseq_rcvr_pol_reverse         ;

wire  [NL-1:0]            smseq_g6_inskip_rcv;
wire  [NL-1:0]            smseq_g6_sds_rcvd;
wire  [NL-1:0]            smseq_g6_ts0_rcvd;
wire  [NL-1:0]            smseq_g6_ts1_rcvd;
wire  [NL-1:0]            smseq_g6_ts2_rcvd;
wire  [NL-1:0]            smseq_g6_ts0_rcvd_pulse;
wire  [NL-1:0]            smseq_g6_ts1_rcvd_pulse;
wire  [NL-1:0]            smseq_g6_ts2_rcvd_pulse;
wire  [NL-1:0]            smseq_g6_ts_error;
wire  [(NL*8)-1:0]        smseq_g6_ts_link_num;          // 8 bit link number;
wire  [NL-1:0]            smseq_g6_ts_link_num_is_k237;  // indicates whether or not received Kchar with k237
wire  [(NL*8)-1:0]        smseq_g6_ts_lane_num;          // 8 bit lane number;
wire  [NL-1:0]            smseq_g6_ts_lane_num_is_k237;  // Indicates whether or not received Kchar with k237
wire  [(NL*8)-1:0]        smseq_g6_ts_nfts;              // 8 bits nfts number contained in training sequence
wire  [(NL*5)-1:0]        smseq_g6_ts_link_ctrl;         // 5 bits
wire  [NL-1:0]            smseq_g6_ts_speed_change;      // Requesting to change the speed of operation.
wire  [NL-1:0]            smseq_g6_ts_auto_change;       // Indicate autonomous speed change
wire  [(NL*5)-1:0]        smseq_g6_ts_data_rate;         // Bit 0 = 1, generation 1 (2.5 Gb/s) data rate supported
wire  [NL-1:0]            smseq_g6_ineies_rcv;           // Electrical Idle Exit Level signal
logic [NL*EQTS_WD-1:0]    smseq_g6_eqts_info;
wire  [NL-1:0]            smseq_g6_8_st_ts2_s6_rcvd;
wire  [NL*8-1:0]          smseq_g6_error_count;

assign smseq_mcs_sts_o                   = smseq_out_post_pipeline.smseq_mcs_sts                  ;
assign smseq_fts_rcvd_pulse_o            = smseq_out_post_pipeline.smseq_fts_rcvd_pulse           ;
assign smseq_ts_debug_info_o             = smseq_out_post_pipeline.smseq_ts_debug_info            ;

// No pipe-line ouput(to deskew)
assign smseq_ts1_rcvd_pulse_to_rmlh_o    = smseq_out_pre_pipeline.smseq_ts1_rcvd_pulse            ;
assign smseq_ts2_rcvd_pulse_to_rmlh_o    = smseq_out_pre_pipeline.smseq_ts2_rcvd_pulse            ;
assign smseq_loc_ts2_rcvd_o              = smseq_loc_ts2_rcvd             ;
assign smseq_in_skp_o                    = smseq_in_skp                   ;
assign smseq_fts_skp_do_deskew_o         = smseq_fts_skp_do_deskew        ;
assign smseq_loc_eies_rcvd_o             = smseq_loc_eies_rcvd            ;


wire  [NL*8-1:0]          smseq_g12_mcs_sts;
wire  [NL-1:0]            smseq_g12_fts_rcvd_pulse;
wire  [NL*64-1:0]         smseq_g12_ts_debug_info;
wire  [NL*8-1:0]          smseq_g3_mcs_sts;
wire  [NL-1:0]            smseq_g3_fts_rcvd_pulse;
wire  [NL*64-1:0]         smseq_g3_ts_debug_info;

assign smseq_out_pre_pipeline.smseq_mcs_sts        = ((current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE)) ? smseq_g3_mcs_sts       : smseq_g12_mcs_sts;
assign smseq_out_pre_pipeline.smseq_ts_debug_info  = ((current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE)) ? smseq_g3_ts_debug_info       : smseq_g12_ts_debug_info;
assign smseq_out_pre_pipeline.smseq_fts_rcvd_pulse = ((current_data_rate == `GEN3_RATE) || (current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE)) ? smseq_g3_fts_rcvd_pulse : smseq_g12_fts_rcvd_pulse ;

wire  [NL*TSFD_WD-1:0]    smseq_g12_ts_info;
wire  [NL*64-1:0]         smseq_g12_mt_info;
wire  [NL*2-1:0]          smseq_g12_ts_lanen_linkn_pad;
wire  [NL*4-1:0]          smseq_g12_ts_rcvd_mtx_pcnt;
wire  [NL*4-1:0]          smseq_g12_ts_rcvd_pcnt;
wire  [NL*2-1:0]          smseq_g12_ts_rcvd_cond_pcnt;
wire  [NL*TSFD_WD-1:0]    smseq_g3_ts_info;
wire  [NL*2-1:0]          smseq_g3_ts_lanen_linkn_pad;
wire  [NL*4-1:0]          smseq_g3_ts_rcvd_mtx_pcnt;
wire  [NL*4-1:0]          smseq_g3_ts_rcvd_pcnt;
wire  [NL*2-1:0]          smseq_g3_ts_rcvd_cond_pcnt;
wire  [NL*TSFD_WD-1:0]    smseq_g6_ts_info;
wire  [NL*2-1:0]          smseq_g6_ts_lanen_linkn_pad;
wire  [NL*4-1:0]          smseq_g6_ts_rcvd_mtx_pcnt;
wire  [NL*4-1:0]          smseq_g6_ts_rcvd_pcnt;
wire  [NL*2-1:0]          smseq_g6_ts_rcvd_cond_pcnt;

assign smseq_out_pre_pipeline.smseq_ts_rcvd_pcnt       = ltssm_clear ? 0 : (current_data_rate >= `GEN6_RATE) ? smseq_g6_ts_rcvd_pcnt       : (current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE) ? smseq_g3_ts_rcvd_pcnt       : smseq_g12_ts_rcvd_pcnt;
assign smseq_out_pre_pipeline.smseq_ts_rcvd_cond_pcnt  = ltssm_clear ? 0 : (current_data_rate >= `GEN6_RATE) ? smseq_g6_ts_rcvd_cond_pcnt  : (current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE) ? smseq_g3_ts_rcvd_cond_pcnt  : smseq_g12_ts_rcvd_cond_pcnt;
assign smseq_out_pre_pipeline.smseq_ts_rcvd_mtx_pcnt   = (ltssm_clear | ltssm_lane_flip_ctrl_chg_pulse) ? 0 : (current_data_rate >= `GEN6_RATE) ? smseq_g6_ts_rcvd_mtx_pcnt   : (current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE) ? smseq_g3_ts_rcvd_mtx_pcnt   : smseq_g12_ts_rcvd_mtx_pcnt;
assign smseq_out_pre_pipeline.smseq_ts_info            = (current_data_rate >= `GEN6_RATE) ? smseq_g6_ts_info            : (current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE) ? smseq_g3_ts_info            : smseq_g12_ts_info;
assign smseq_out_pre_pipeline.smseq_mt_info            = (current_data_rate >= `GEN6_RATE) ? 0                           : (current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE) ? 0                           : smseq_g12_mt_info;
assign smseq_out_pre_pipeline.smseq_ts_lanen_linkn_pad = (current_data_rate >= `GEN6_RATE) ? smseq_g6_ts_lanen_linkn_pad : (current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE) ? smseq_g3_ts_lanen_linkn_pad : smseq_g12_ts_lanen_linkn_pad;


assign {smseq_out_pre_pipeline.smseq_inskip_rcv, smseq_out_pre_pipeline.smseq_sds_rcvd, smseq_out_pre_pipeline.smseq_ts0_rcvd, smseq_out_pre_pipeline.smseq_ts1_rcvd, smseq_out_pre_pipeline.smseq_ts2_rcvd, smseq_out_pre_pipeline.smseq_ts0_rcvd_pulse, smseq_out_pre_pipeline.smseq_ts1_rcvd_pulse, smseq_out_pre_pipeline.smseq_ts2_rcvd_pulse, smseq_out_pre_pipeline.smseq_ts_error
        ,smseq_out_pre_pipeline.smseq_ineies_rcv, smseq_out_pre_pipeline.smseq_mcs_rcvd
        } =
        (current_data_rate >= `GEN6_RATE) ?
       {smseq_g6_inskip_rcv, smseq_g6_sds_rcvd, smseq_g6_ts0_rcvd, smseq_g6_ts1_rcvd, smseq_g6_ts2_rcvd, smseq_g6_ts0_rcvd_pulse, smseq_g6_ts1_rcvd_pulse, smseq_g6_ts2_rcvd_pulse, smseq_g6_ts_error, smseq_g6_ineies_rcv, {NL{1'b0}}
        } :

        ((current_data_rate == `GEN3_RATE) || (current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE)) ?
       {smseq_g3_inskip_rcv, smseq_g3_sds_rcvd, {NL{1'b0}}, smseq_g3_ts1_rcvd, smseq_g3_ts2_rcvd, {NL{1'b0}}, smseq_g3_ts1_rcvd_pulse, smseq_g3_ts2_rcvd_pulse, smseq_g3_ts_error
        ,smseq_g3_ineies_rcv, {NL{1'b0}}
        } :

       {smseq_g12_inskip_rcv, {NL{1'b0}}, {NL{1'b0}}, smseq_g12_ts1_rcvd, smseq_g12_ts2_rcvd, {NL{1'b0}}, smseq_g12_ts1_rcvd_pulse, smseq_g12_ts2_rcvd_pulse, smseq_g12_ts_error
        ,smseq_g12_ineies_rcv, smseq_g12_mcs_rcvd
        };

assign {smseq_out_pre_pipeline.smseq_invalid_os, smseq_out_pre_pipeline.smseq_os_corrected} = (current_data_rate >= `GEN6_RATE) ? {smseq_invalid_os, smseq_os_corrected} : {{NL{1'b0}},{NL{1'b0}}};

assign smseq_out_pre_pipeline.smseq_eqts_info        = current_data_rate >= `GEN6_RATE ? smseq_g6_eqts_info :
                                  ((current_data_rate == `GEN3_RATE) || (current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE)) ? smseq_g3_eqts_info : smseq_g12_eqts_info;
assign smseq_out_pre_pipeline.smseq_ts_rcvd_s6s9_pcnt = ltssm_clear ? 0 : current_data_rate >= `GEN6_RATE ? smseq_g6_ts_rcvd_mtx_pcnt : // for gen6, smseq_g6_ts_rcvd_s6s9_pcnt = smseq_g6_ts_rcvd_mtx_pcnt
                                  ((current_data_rate == `GEN3_RATE) || (current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE)) ? smseq_g3_ts_rcvd_s6s9_pcnt : smseq_g12_ts_rcvd_s6s9_pcnt;
assign smseq_out_pre_pipeline.smseq_g3_error_count = current_data_rate >= `GEN6_RATE ? smseq_g6_error_count : smseq_g3_error_count;

reg  [(NL*G12_NB*8)-1:0] int_smseq_g12_rxdata;
reg  [(NL*G12_NB)-1:0]   int_smseq_g12_rxdatak;
reg  [(NL*G12_NB)-1:0]   int_smseq_g12_rxerror;

// Build up bus correctly for Gen1/Gen2 specific blocks
    always @(*) begin : g12_rxdata_PROC
        integer i;
        for (i=0;i<NL;i=i+1) begin
            int_smseq_g12_rxdata[(8*G12_NB*i) +: 8*G12_NB] = rxdata[(8*NB*i) +: 8*G12_NB];
            int_smseq_g12_rxdatak[(G12_NB*i) +: G12_NB] = rxdatak[(NB*i) +: G12_NB];
            int_smseq_g12_rxerror[(G12_NB*i) +: G12_NB] = rxerror[(NB*i) +: G12_NB];
        end
    end

assign smseq_g12_rxdata  = int_smseq_g12_rxdata;
assign smseq_g12_rxdatak = int_smseq_g12_rxdatak;
assign smseq_g12_rxerror = int_smseq_g12_rxerror;


smlh_seq_finder_slv
 #(.INST(INST),.NB(G12_NB)) u_smlh_seq_finder_slv[NL-1:0] (
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .ltssm_lane_flip_ctrl_chg_pulse (ltssm_lane_flip_ctrl_chg_pulse),
    .smlh_link_up                   (smlh_link_up),
    .smlh_link_in_training          (smlh_link_in_training),
    .active_nb                      (active_nb[3:0]),
    .smlh_in_rl0s                   (smlh_in_rl0s),
    .cfg_ts2_lid_deskew             (cfg_ts2_lid_deskew),
    .rxdata_dv_in                   (rxdata_dv[NL-1:0]),
    .rxaligned                      (rxaligned[NL-1:0]),
    .rxskipremoved_in               (rxskipremoved[NL-1:0]),
    .rxdata_in                      (smseq_g12_rxdata[(NL*G12_NB*8)-1:0]),
    .rxdatak_in                     (smseq_g12_rxdatak[(NL*G12_NB)-1:0]),
    .rxerror_in                     (smseq_g12_rxerror[(NL*G12_NB)-1:0]),
    .smlh_ltssm_state               (smlh_ltssm_state),
    .cfg_upstream_port              (cfg_upstream_port),
    .cfg_elastic_buffer_mode        (cfg_elastic_buffer_mode),
    .cfg_polarity_mode              (cfg_polarity_mode),
    .current_data_rate              (current_data_rate),
    .smlh_ts_spd_chg_rcvd_clr       (smlh_ts_spd_chg_rcvd_clr),
    .ltssm_clear                    (ltssm_clear),
    .ltssm_mod_ts                   (ltssm_mod_ts),
    .smlh_ltssm_in_compliance       (smlh_ltssm_in_compliance),
    .cfg_enter_compliance           (cfg_enter_compliance),
    .sticky_rst_n                   (sticky_rst_n),
    .xmtbyte_ts_pcnt                (xmtbyte_ts_pcnt),
    .xmtbyte_eies_sent              (xmtbyte_eies_sent),
    .int_directed_speed_change      (int_directed_speed_change),
    .smlh_keep_rcvrylock_lane       (smlh_keep_rcvrylock_lane[NL-1:0]),
    .smseq_ts_info                  (smseq_g12_ts_info[NL*TSFD_WD-1:0]),
    .smseq_mt_info                  (smseq_g12_mt_info[NL*64-1:0]),
    .smseq_ts_lanen_linkn_pad       (smseq_g12_ts_lanen_linkn_pad[NL*2-1:0]),
    .smseq_ts_rcvd_mtx_pcnt         (smseq_g12_ts_rcvd_mtx_pcnt[NL*4-1:0]),
    .smseq_ts_rcvd_pcnt             (smseq_g12_ts_rcvd_pcnt[NL*4-1:0]),
    .smseq_ts_rcvd_cond_pcnt        (smseq_g12_ts_rcvd_cond_pcnt[NL*2-1:0]),
    .smseq_inskip_rcv               (smseq_g12_inskip_rcv[NL-1:0]),
    .smseq_ts_error                 (smseq_g12_ts_error[NL-1:0]),
    .smseq_ts1_rcvd                 (smseq_g12_ts1_rcvd[NL-1:0]),
    .smseq_ts2_rcvd                 (smseq_g12_ts2_rcvd[NL-1:0]),
    .smseq_ts1_rcvd_pulse           (smseq_g12_ts1_rcvd_pulse[NL-1:0]),
    .smseq_ts2_rcvd_pulse           (smseq_g12_ts2_rcvd_pulse[NL-1:0]),
    .smseq_mod_ts1_rcvd_pulse       (smseq_out_pre_pipeline.smseq_mod_ts1_rcvd_pulse[NL-1:0]),
    .smseq_mod_ts2_rcvd_pulse       (smseq_out_pre_pipeline.smseq_mod_ts2_rcvd_pulse[NL-1:0]),
    .smseq_loc_ts2_rcvd             (smseq_loc_ts2_rcvd[NL*4-1:0]),
    .smseq_in_skp                   (smseq_in_skp[NL*4-1:0]),
    .smseq_fts_skp_do_deskew        (smseq_fts_skp_do_deskew[NL-1:0]),
    .smseq_ineies_rcv               (smseq_g12_ineies_rcv[NL-1:0]),
    .smseq_mcs_rcvd                 (smseq_g12_mcs_rcvd[NL-1:0]),
    .smseq_loc_eies_rcvd            (smseq_loc_eies_rcvd[NL*4-1:0]),
    .smseq_eqts_info                (smseq_g12_eqts_info[NL*EQTS_WD-1:0]),
    .smseq_ts_rcvd_s6s9_pcnt        (smseq_g12_ts_rcvd_s6s9_pcnt[NL*4-1:0]),
    .smseq_rcvr_pol_reverse         (smseq_out_pre_pipeline.smseq_rcvr_pol_reverse[NL-1:0])
    ,
    .smseq_mcs_sts                  (smseq_g12_mcs_sts[NL*8-1:0]),
    .smseq_ts_debug_info            (smseq_g12_ts_debug_info[NL*64-1:0]),
    .smseq_fts_rcvd_pulse           (smseq_g12_fts_rcvd_pulse[NL-1:0])
); //smlh_seq_finder_slv

smlh_seq_finder3_slv
 #(INST) u_smlh_seq_finder3_slv[NL-1:0] (
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .cfg_gen3_dc_balance_disable    (cfg_gen3_dc_balance_disable),
    .cfg_upstream_port              (cfg_upstream_port),
    .cfg_elastic_buffer_mode        (cfg_elastic_buffer_mode),
    .ltssm_lane_flip_ctrl_chg_pulse (ltssm_lane_flip_ctrl_chg_pulse),
    .smlh_link_up                   (smlh_link_up),
    .smlh_link_in_training          (smlh_link_in_training),
    .current_data_rate              (current_data_rate),
    .active_nb                      (active_nb),
    .active_nb_gen34                (active_nb_gen34),
    .rxdata                         (regin_descrambled_rxdata[(NL*G5_NB*8)-1:0]),
    .rxdata_dv                      (regin_descrambled_rxdata_dv[NL-1:0]),
    .rxaligned                      (regin_descrambled_rxaligned[NL-1:0]),
    .rxstartblock                   (regin_descrambled_rxstartblock[NL-1:0]),
    .ints1                          (regin_descrambled_ints1[NL-1:0]),
    .ints2                          (regin_descrambled_ints2[NL-1:0]),
    .inskp                          (regin_descrambled_inskp[NL-1:0]),
    .ineie                          (regin_descrambled_ineie[NL-1:0]),
    .eie_det                        (regin_descrambled_eie_det[NL-1:0]),
    .insds                          (regin_descrambled_insds[NL-1:0]),
    .rxsyncheader                   (regin_descrambled_rxsyncheader[NL*2-1:0]),
    .rxerror                        (regin_descrambled_rxerror[(NL*G5_NB)-1:0]),
    .dec_rx_pad                     (regin_descrambled_rx_pad[(NL*G5_NB)-1:0]),
    .dec_rx_num_v                   (regin_descrambled_rx_num_v[(NL*G5_NB)-1:0]),
    .dec_ts1_id                     (regin_descrambled_ts1_id[(NL*G5_NB)-1:0]),
    .dec_ts2_id                     (regin_descrambled_ts2_id[(NL*G5_NB)-1:0]),
    .dec_eqts                       (regin_descrambled_eqts[(NL*G5_NB)-1:0]),
    .dec_rx_rate_v                  (regin_descrambled_rx_rate_v[(NL*G5_NB)-1:0]),
    .smlh_ts_spd_chg_rcvd_clr       (smlh_ts_spd_chg_rcvd_clr),
    .ltssm_clear                    (ltssm_clear),
    .smlh_ltssm_in_compliance       (smlh_ltssm_in_compliance),
    .smlh_ltssm_state               (smlh_ltssm_state),
    .xmtbyte_eies_sent              (xmtbyte_eies_sent),
    .xmtbyte_skip_sent              (xmtbyte_skip_sent),
    .int_directed_speed_change      (int_directed_speed_change),
    .smlh_keep_rcvrylock_lane       (smlh_keep_rcvrylock_lane[NL-1:0]),

//output
    .smseq_ts_info                  (smseq_g3_ts_info[NL*TSFD_WD-1:0]),
    .smseq_ts_lanen_linkn_pad       (smseq_g3_ts_lanen_linkn_pad[NL*2-1:0]),
    .smseq_ts_rcvd_mtx_pcnt         (smseq_g3_ts_rcvd_mtx_pcnt[NL*4-1:0]),
    .smseq_ts_rcvd_pcnt             (smseq_g3_ts_rcvd_pcnt[NL*4-1:0]),
    .smseq_ts_rcvd_cond_pcnt        (smseq_g3_ts_rcvd_cond_pcnt[NL*2-1:0]),
    .smseq_ts_error                 (smseq_g3_ts_error[NL-1:0]),
    .smseq_ts_rcvd_s6s9_pcnt        (smseq_g3_ts_rcvd_s6s9_pcnt[NL*4-1:0]),
    .smseq_error_count              (smseq_g3_error_count[NL*8-1:0]),
    .smseq_inskip_rcv               (smseq_g3_inskip_rcv[NL-1:0]),
    .smseq_ts1_rcvd                 (smseq_g3_ts1_rcvd[NL-1:0]),
    .smseq_ts2_rcvd                 (smseq_g3_ts2_rcvd[NL-1:0]),
    .smseq_ts1_rcvd_pulse           (smseq_g3_ts1_rcvd_pulse[NL-1:0]),
    .smseq_ts2_rcvd_pulse           (smseq_g3_ts2_rcvd_pulse[NL-1:0]),
    .smseq_ineies_rcv               (smseq_g3_ineies_rcv[NL-1:0]),
    .smseq_sds_rcvd                 (smseq_g3_sds_rcvd[NL-1:0]),
    .smseq_eqts_info                (smseq_g3_eqts_info[NL*EQTS_WD-1:0])
    ,
    .smseq_mcs_sts                  (smseq_g3_mcs_sts[NL*8-1:0]),
    .smseq_ts_debug_info            (smseq_g3_ts_debug_info[NL*64-1:0]),
    .smseq_fts_rcvd_pulse           (smseq_g3_fts_rcvd_pulse[NL-1:0])
); //smlh_seq_finder3_slv

`define SMLH_SEQ_FINDER6_SLV smlh_seq_finder6_slv

`SMLH_SEQ_FINDER6_SLV
 #(INST) u_smlh_seq_finder6_slv[NL-1:0] (
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .cfg_upstream_port              (cfg_upstream_port),
    .cfg_elastic_buffer_mode        (cfg_elastic_buffer_mode),
    .current_data_rate              (current_data_rate),
    .ltssm_lane_flip_ctrl_chg_pulse (ltssm_lane_flip_ctrl_chg_pulse),
    .active_nb                      (active_nb),
    .active_nb_gen34                (active_nb_gen34),
    .inskp                          (regin_descrambled_inskp[(NL*RXSB_WD)-1:0]),
    .rxerror                        (regin_descrambled_rxerror[(NL*NB)-1:0]),
    .rxdata                         (regin_descrambled_rxdata[(NL*NB*8)-1:0]),
    .rxdata_dv                      (regin_descrambled_rxdata_dv[NL-1:0]),
    .rxaligned                      (regin_descrambled_rxaligned[NL-1:0]),
    .rxstartblock                   (regin_descrambled_rxstartblock[(NL*RXSB_WD)-1:0]),
    .rxsyncheader                   (regin_descrambled_rxsyncheader[(NL*RXSH_WD)-1:0]),
    .rxdata_dcb                     (regin_descrambled_rxdata_dcb[NL*DCB_WD-1:0]),
    .rmlh_deskew_ds                 (rmlh_deskew_ds_g6[NL-1:0]),
    .smlh_ts_spd_chg_rcvd_clr       (smlh_ts_spd_chg_rcvd_clr),
    .ltssm_clear                    (ltssm_clear),
    .smlh_ltssm_in_compliance       (smlh_ltssm_in_compliance),
    .smlh_ltssm_state               (smlh_ltssm_state),
    .int_directed_speed_change      (int_directed_speed_change),
    .smlh_keep_rcvrylock_lane       (smlh_keep_rcvrylock_lane[NL-1:0]),

//output
    .smseq_ts_info                  (smseq_g6_ts_info[NL*TSFD_WD-1:0]),
    .smseq_ts_lanen_linkn_pad       (smseq_g6_ts_lanen_linkn_pad[NL*2-1:0]),
    .smseq_ts_rcvd_mtx_pcnt         (smseq_g6_ts_rcvd_mtx_pcnt[NL*4-1:0]),
    .smseq_ts_rcvd_pcnt             (smseq_g6_ts_rcvd_pcnt[NL*4-1:0]),
    .smseq_ts_rcvd_cond_pcnt        (smseq_g6_ts_rcvd_cond_pcnt[NL*2-1:0]),
    .smseq_ts_error                 (smseq_g6_ts_error[NL-1:0]),
    .smseq_error_count              (smseq_g6_error_count[NL*8-1:0]),
    .smseq_inskip_rcv               (smseq_g6_inskip_rcv[NL-1:0]),
    .smseq_ts0_rcvd                 (smseq_g6_ts0_rcvd[NL-1:0]),
    .smseq_ts1_rcvd                 (smseq_g6_ts1_rcvd[NL-1:0]),
    .smseq_ts2_rcvd                 (smseq_g6_ts2_rcvd[NL-1:0]),
    .smseq_ts0_rcvd_pulse_o         (smseq_g6_ts0_rcvd_pulse[NL-1:0]),
    .smseq_ts1_rcvd_pulse_o         (smseq_g6_ts1_rcvd_pulse[NL-1:0]),
    .smseq_ts2_rcvd_pulse_o         (smseq_g6_ts2_rcvd_pulse[NL-1:0]),
    .smseq_ineies_rcv               (smseq_g6_ineies_rcv[NL-1:0]),
    .smseq_sds_rcvd                 (smseq_g6_sds_rcvd[NL-1:0]),
    .smseq_eqts_info                (smseq_g6_eqts_info[NL*EQTS_WD-1:0]),
    .smseq_invalid_os               (smseq_invalid_os[NL-1:0]),
    .smseq_os_corrected             (smseq_os_corrected[NL-1:0])

); //smlh_seq_finder6_slv

endmodule
