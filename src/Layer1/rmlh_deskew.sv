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
// ---    $DateTime: 2024/01/19 09:25:58 $
// ---    $Revision: #20 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/rmlh_deskew.sv#20 $
// -------------------------------------------------------------------------
// --- Module Description: Receive MAC layer handler deskew logic.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"

 
 module rmlh_deskew
 import DWC_pcie_core_pkg::ltssm_state_e;
 import DWC_pcie_core_pkg::S_PRE_DETECT_QUIET;
 import DWC_pcie_core_pkg::S_DETECT_QUIET;
 import DWC_pcie_core_pkg::S_DETECT_ACT;
 import DWC_pcie_core_pkg::S_DETECT_WAIT;
 import DWC_pcie_core_pkg::S_CFG_LINKWD_START;
 import DWC_pcie_core_pkg::S_CFG_LINKWD_ACEPT;
 import DWC_pcie_core_pkg::S_CFG_LANENUM_ACEPT;
 import DWC_pcie_core_pkg::S_CFG_LANENUM_WAIT;
 import DWC_pcie_core_pkg::S_CFG_COMPLETE;
 import DWC_pcie_core_pkg::S_CFG_IDLE;
 import DWC_pcie_core_pkg::S_RCVRY_LOCK;
 import DWC_pcie_core_pkg::S_RCVRY_RCVRCFG;
 import DWC_pcie_core_pkg::S_RCVRY_IDLE;
 import DWC_pcie_core_pkg::S_L0;
 import DWC_pcie_core_pkg::S_L1_IDLE;
 import DWC_pcie_core_pkg::S_L2_IDLE;
 import DWC_pcie_core_pkg::S_L0S;
 import DWC_pcie_core_pkg::S_LPBK_ACTIVE;
 import DWC_pcie_core_pkg::S_LPBK_EXIT;
(
// ---- inputs ---------------
    core_rst_n,
    core_clk,
    cfg_elastic_buffer_mode,
    cfg_ts2_lid_deskew,
    prbs_en_int,
    rmlh_deskew_bypass,
    ltssm_cxl_ll_mod,
    drift_buffer_deskew_enable,
    drift_buffer_deskew_ptr,
    deskew_lanes_active,
    smlh_in_rl0s_i,
    smlh_do_deskew_i,
    smseq_ts1_rcvd_pulse_bus_i,
    smseq_ts2_rcvd_pulse_bus_i,
    smseq_loc_ts2_rcvd_bus_i,
    smseq_in_skp_bus_i,
    smseq_fts_skp_do_deskew_bus_i,
    smseq_loc_eies_rcvd_bus_i,
    active_nb_wire,
    rxdata_dv_i,
    rxaligned_i,
    rxdata_i,
    rxdata_comma_i,
    rxdata_skip_i,
    rxdata_skprm_i,
    rxdatak_i,
    rxerror_i,
    rxdata_eie_det_i,
    rxdata_g6_skprm_i,
    rxdata_g6_skpadd_i,
    rxunderflow_i,
    rxoverflow_i,
    current_data_rate,
    smlh_ltssm_state_wire,
    smlh_ltssm_last,
    cxl_mode_enable,
    ltssm_lpbk_master_i,
    smlh_flit_mode_enable,
    ltssm_l0p_lanes_active,
    ltssm_l0p_last_lanes_active,
    ltssm_l0p_next_link_mode,
    ltssm_in_l0p,
    ltssm_in_l0p_upsize,
    xmtbyte_l0p_link_in_training,
    xmtbyte_l0p_ts2_sent,
    rxstartblock_i,
    rxeven_parity_i,
    rxpkt_error_i,
    rxdata_osfound_i,
    rxpkt_error_ptr_i,
    cdm_ras_des_ferr_rec_dis,
    rpipe_eios_eieos_det_i,
// ---- outputs ---------------
    deskew_rxdata_dv,
    deskew_rxdata,
    deskew_rxdatak,
    deskew_rxerror,
    deskew_search_for_tokens,     // when in S_DATA_STREAM state
    deskew_rxdata_link_width,
    deskew_datastream_bus,
    deskew_datastream,
    deskew_accept_eds_cycle,
    deskew_expect_eds,
    deskew_os_in_datastream,
    deskew_lane_err_bus,
    deskew_lane_err_skp_parity_bus,
    deskew_lane_err_sync_header_bus,
    deskew_framing_err_ptr,
    deskew_framing_err_o,
    deskew_goto_recovery,
    deskew_ctlskp_rcvd,
    deskew_ctlskp_info,
    deskew_ctlskp_err,
    deskew_fifo_ptr,
    deskew_rxdata_flush_gen12,
    deskew_ds_g6,
    deskew_fltlog_ctrl_skp_mismatch_bus,
    deskew_alignment_err,
    deskew_complete
);

parameter INST          = 0;                    // The uniquifying parameter for each port logic instance.
parameter NL            = `CX_NL;               // Max number of lanes supported
parameter NB            = `CX_NB;               // Number of symbols (bytes) per clock cycle
parameter NBK           = `CX_NBK;              // Number of symbols (bytes) per clock cycle for datak
parameter AW            = `CX_ANB_WD;           // Width of the active number of bytes
parameter TP            = `TP;                  // Clock to Q delay (simulator insurance)
parameter REGIN         =  `CX_RMLH_DESKEW_REGIN; // PIPELine Option for Deskew inputs
localparam SB_WD        = `CX_MAC_SB_WD;
localparam SH_WD        = `CX_MAC_SH_WD;
localparam OS_WD        = `CX_MAC_SB_WD; // Number of OS width

input                   core_rst_n;
input                   core_clk;
input                   cfg_elastic_buffer_mode;
input                   cfg_ts2_lid_deskew;
input                   prbs_en_int;
input                   rmlh_deskew_bypass;
input   [1:0]           ltssm_cxl_ll_mod;        // {drift_buffer, common_clk} enabled
input                   drift_buffer_deskew_enable;
input   [(NL*8)-1:0]    drift_buffer_deskew_ptr;
input   [NL-1:0]        deskew_lanes_active;
input                   smlh_in_rl0s_i;
input                   smlh_do_deskew_i;
input   [NL-1:0]        smseq_ts1_rcvd_pulse_bus_i;
input   [NL-1:0]        smseq_ts2_rcvd_pulse_bus_i;
input   [NL*4-1:0]      smseq_loc_ts2_rcvd_bus_i;
input   [NL*4-1:0]      smseq_in_skp_bus_i;
input   [NL-1:0]        smseq_fts_skp_do_deskew_bus_i;
input   [NL*4-1:0]      smseq_loc_eies_rcvd_bus_i;
input   [AW-1:0]        active_nb_wire;
input   [NL-1:0]        rxdata_dv_i;
input   [NL-1:0]        rxaligned_i;
input   [(NL*NB*8)-1:0] rxdata_i;
input   [(NL*NB)-1:0]   rxdata_comma_i;
input   [(NL*NB)-1:0]   rxdata_skip_i;
input   [(NL*NB)-1:0]   rxdata_skprm_i;
input   [(NL*NBK)-1:0]  rxdatak_i;
input   [(NL*NB)-1:0]   rxerror_i;
input   [NL*SB_WD-1:0]  rxdata_eie_det_i;
input   [NL*SB_WD-1:0]  rxdata_g6_skprm_i;
input   [NL*SB_WD-1:0]  rxdata_g6_skpadd_i;
input   [NL-1:0]        rxunderflow_i;
input   [NL-1:0]        rxoverflow_i;
input   [2:0]           current_data_rate;
input   ltssm_state_e   smlh_ltssm_state_wire;
input   ltssm_state_e   smlh_ltssm_last;
input                   cxl_mode_enable;
input                   ltssm_lpbk_master_i;
input                   smlh_flit_mode_enable;
input   [5:0]           ltssm_l0p_next_link_mode;                 // 1000 --- x8 mode, 0100 ---- x4 mode, 0010 ---- x2 mode, 0001 ---- x1 mode
input   [NL-1:0]        ltssm_l0p_lanes_active; // LTSSM latched lanes that are active based on the link negotiation
input   [NL-1:0]        ltssm_l0p_last_lanes_active; // LTSSM latched lanes that are active based on the link negotiation
input                   ltssm_in_l0p;
input                   ltssm_in_l0p_upsize;
input                   xmtbyte_l0p_link_in_training;   // In l0p negotiation
input   [OS_WD-1:0]     xmtbyte_l0p_ts2_sent;           // Sned TS-OSs for l0p
input   [NL*SB_WD-1:0]  rxstartblock_i;
input   [NL*SB_WD-1:0]  rxeven_parity_i;      //accumulated SKP even parity
input                   rxpkt_error_i;        //Packet Framing Error
input   [NL-1:0][SB_WD-1:0][4:0] rxdata_osfound_i;
input   [4:0]           rxpkt_error_ptr_i;    //Packet Framing Error Pointer
input                   cdm_ras_des_ferr_rec_dis;  // Disable Recovery state transition at Framing Error
input                   rpipe_eios_eieos_det_i;

output                  deskew_rxdata_dv;
output  [(NL*NB*8)-1:0] deskew_rxdata;
output  [(NL*NB)-1:0]   deskew_rxdatak;
output  [(NL*NB)-1:0]   deskew_rxerror;
output                  deskew_search_for_tokens;     // when in S_DATA_STREAM state
output  [4:0]           deskew_rxdata_link_width;     // link width
output  [NL-1:0]        deskew_datastream_bus;
output                  deskew_datastream;
output                  deskew_accept_eds_cycle;
output                  deskew_expect_eds;
output                  deskew_os_in_datastream;
output  [NL-1:0]        deskew_lane_err_bus;      //Lane Error Status
output  [NL-1:0]        deskew_lane_err_skp_parity_bus;   //Lane Error Status(skp parity)
output  [NL-1:0]        deskew_lane_err_sync_header_bus;  //Lane Error Status(undefined sync header)
output  [6:0]           deskew_framing_err_ptr;   //framing error pointer for gen3 rate
output                  deskew_framing_err_o;     //framing error for gen3 rate
output                  deskew_goto_recovery;     //all active lanes received EIEOS at same time while exiting Data Stream at gen3 rate
output  [NL-1:0]        deskew_ctlskp_rcvd;       // Received enhanced SKP-OS
output  [(NL*16)-1:0]   deskew_ctlskp_info;       // RxMargin Status within the enhanced skp-os
output  [(NL*5)-1:0]    deskew_ctlskp_err;        // CTL-SKP-OS error [0]data parity[1]1st retimer parity [2]2nd retimer parity[3]margin crc[4]margin parity
output  [(NL*8)-1:0]    deskew_fifo_ptr;          // deskw fifo pointer address
output                  deskew_rxdata_flush_gen12; // active high RX data flushing signal to pkt_finder at Gen1/2 rate
output  [NL-1:0]        deskew_ds_g6; // gen6 data stream
output  [NL-1:0]        deskew_fltlog_ctrl_skp_mismatch_bus;
output                  deskew_alignment_err;
output                  deskew_complete;


// Pipeline option for timing closure
wire    [2:0]           current_data_rate;
wire                    deskew_bypass;
wire                    deskew_bypass_i;
wire                    smlh_in_rl0s;
wire                    smlh_do_deskew_o;
wire    [NL-1:0]        smseq_ts1_rcvd_pulse_bus;
wire    [NL-1:0]        smseq_ts2_rcvd_pulse_bus;
wire    [NL*4-1:0]      smseq_loc_ts2_rcvd_bus;
wire    [NL*4-1:0]      smseq_in_skp_bus;
wire    [NL-1:0]        smseq_fts_skp_do_deskew_bus;
wire    [NL*4-1:0]      smseq_loc_eies_rcvd_bus;
wire    [NL-1:0]        rxdata_dv;
wire    [NL-1:0]        rxaligned;
wire    [(NL*NB*8)-1:0] rxdata;
wire    [(NL*NB)-1:0]   rxdata_comma;
wire    [(NL*NB)-1:0]   rxdata_skip;
wire    [(NL*NB)-1:0]   rxdata_skprm;
wire    [(NL*NBK)-1:0]  rxdatak;
wire    [(NL*NB)-1:0]   rxerror;
wire    [NL-1:0]        rxunderflow;
wire    [NL-1:0]        rxoverflow;
reg     [AW-1:0]        active_nb ;
ltssm_state_e           smlh_ltssm_state_i;
ltssm_state_e           smlh_ltssm_state;
wire                    ltssm_lpbk_master;
wire                    deskew_search_for_tokens;     // when in S_DATA_STREAM state
wire    [NL-1:0]        deskew_framing_err_bus;  //indicate framing error for gen3 rate
wire                    deskew_framing_err;      //framing error triggers receiver error in gen3 rate as per spec
logic                   deskew_framing_err_o;    //framing error triggers receiver error in gen3 rate as per spec
wire    [NL-1:0]        deskew_lane_err_bus_i;      //Lane Error Status
wire    [NL-1:0]        deskew_sds_rcvd_bus;
wire    [NL-1:0]        deskew_ei_rcvd_bus;
wire                    eie_rcvd_all;
wire    [NL*SB_WD-1:0]  rxstartblock;
wire    [NL*SB_WD-1:0]  rxeven_parity;      //accumulated SKP even parity
wire                    rxpkt_error;        //Packet Framing Error
wire [NL-1:0][SB_WD-1:0][4:0] rxdata_osfound;
wire    [NL*SB_WD-1:0]  rxdata_eie_det;
wire    [NL*SB_WD-1:0]  rxdata_g6_skprm;
wire    [NL*SB_WD-1:0]  rxdata_g6_skpadd;
wire                    skp_error_g6;
wire    [NL-1:0]        deskew_framing_err_g6_bus;
wire    [(NL*3)-1:0]    deskew_skp_os_len_g6_bus;
reg     [NL-1:0]        g6_skp_os_len_err_bus;
reg     [4:0]           latched_deskew_rxdata_link_width;    // link width
wire    [NL*3-1:0]      deskew_rd_state_bus;
reg     [NL-1:0]        deskew_flit_lane_err_bus;
reg     [NL-1:0]        latched_deskew_flit_lane_err_bus;
reg                     latched_rxpkt_error;
reg     [NL-1:0]        deskew_ei_rcvd_bus_d;
wire    [NL-1:0]        deskew_latched_l0p_ei_rcvd_bus;      // Latched eios detection in dta stream
reg     [NL-1:0]        deskew_latched_l0p_ei_rcvd_bus_d;    // Latched eios detection in dta stream
wire    [NL-1:0]        l0p_skp_data_rcving_any_bus;
wire    [NL-1:0]        l0p_g12_realign_en_bus;
wire    [4:0]           rxpkt_error_ptr;    //Packet Framing Error Pointer



// Pipe-line of smlh_ltssm_state/active_nb for high fanout. 
// The smlh_ltssm_state_wire/active_nb_wire are a combinational signal(before FF). So, no timing change by this pipe-line.
always @(posedge core_clk or negedge core_rst_n) begin : smlh_ltssm_state_i_proc
    if (!core_rst_n) begin
        smlh_ltssm_state_i <= #TP S_DETECT_QUIET;
        active_nb          <= #TP `CX_NB;
    end
    else begin
        smlh_ltssm_state_i <= #TP smlh_ltssm_state_wire;
        active_nb          <= #TP active_nb_wire;
    end
end

wire delay_en  = (smlh_ltssm_state_i != S_DETECT_QUIET) & (smlh_ltssm_state_i != S_DETECT_ACT);

// for easing timing (always available)
logic [5:0] smlh_ltssm_state_lgc_o;
assign smlh_ltssm_state = ltssm_state_e'(smlh_ltssm_state_lgc_o); // static cast for conversion to enum type
delay_n_w_enable
 #(    1,       1) u_delay_deskew_bypass  ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en),  .din(deskew_bypass_i),               .dout(deskew_bypass));

delay_n_w_enable
 #(REGIN,       1) u_delay0  ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(smlh_in_rl0s_i),                .dout(smlh_in_rl0s));
delay_n_w_enable
 #(REGIN,       1) u_delay1  ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(smlh_do_deskew_i),              .dout(smlh_do_deskew_o));
delay_n_w_enable
 #(REGIN,      NL) u_delay2  ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(smseq_ts1_rcvd_pulse_bus_i),    .dout(smseq_ts1_rcvd_pulse_bus));
delay_n_w_enable
 #(REGIN,      NL) u_delay3  ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(smseq_ts2_rcvd_pulse_bus_i),    .dout(smseq_ts2_rcvd_pulse_bus));
delay_n_w_enable
 #(REGIN,    NL*4) u_delay4  ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(smseq_loc_ts2_rcvd_bus_i),      .dout(smseq_loc_ts2_rcvd_bus));
delay_n_w_enable
 #(REGIN,    NL*4) u_delay5  ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(smseq_in_skp_bus_i),            .dout(smseq_in_skp_bus));
delay_n_w_enable
 #(REGIN,      NL) u_delay6  ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(smseq_fts_skp_do_deskew_bus_i), .dout(smseq_fts_skp_do_deskew_bus));
delay_n_w_enable
 #(REGIN,      1) u_delay61 ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(rpipe_eios_eieos_det_i),        .dout(rpipe_eios_eieos_det));
delay_n_w_enable
 #(REGIN,    NL*4) u_delay7  ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(smseq_loc_eies_rcvd_bus_i),     .dout(smseq_loc_eies_rcvd_bus));
delay_n_w_enable
 #(REGIN,      NL) u_delay8  ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(rxdata_dv_i),         .dout(rxdata_dv));
delay_n_w_enable
 #(REGIN,      NL) u_delay9  ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(rxaligned_i),         .dout(rxaligned));
delay_n_w_enable
 #(REGIN, NL*NB*8) u_delay10 ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(rxdata_i),            .dout(rxdata));
delay_n_w_enable
 #(REGIN,   NL*NB) u_delay11 ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(rxdata_comma_i),      .dout(rxdata_comma));
delay_n_w_enable
 #(REGIN,   NL*NB) u_delay12 ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(rxdata_skip_i),       .dout(rxdata_skip));
delay_n_w_enable
 #(REGIN,   NL*NB) u_delay13 ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(rxdata_skprm_i),      .dout(rxdata_skprm));
delay_n_w_enable
 #(REGIN,  NL*NBK) u_delay14 ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(rxdatak_i),           .dout(rxdatak));
delay_n_w_enable
 #(REGIN,   NL*NB) u_delay15 ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(rxerror_i),           .dout(rxerror));
delay_n_w_enable
 #(REGIN,      NL) u_delay16 ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(rxunderflow_i),       .dout(rxunderflow));
delay_n_w_enable
 #(REGIN,      NL) u_delay17 ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(rxoverflow_i),        .dout(rxoverflow));
delay_n_w_enable
 #(REGIN,       6) u_delay18 ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(smlh_ltssm_state_i),  .dout(smlh_ltssm_state_lgc_o));
delay_n_w_enable
 #(REGIN,       1) u_delay19 ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(ltssm_lpbk_master_i), .dout(ltssm_lpbk_master));
delay_n_w_enable
 #(REGIN, NL*SB_WD) u_delay20 ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(rxstartblock_i),      .dout(rxstartblock));
delay_n_w_enable
 #(REGIN, NL*SB_WD) u_delay21 ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(rxeven_parity_i),     .dout(rxeven_parity));
delay_n_w_enable
 #(REGIN,        1) u_delay22 ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(rxpkt_error_i),       .dout(rxpkt_error));
delay_n_w_enable
 #(REGIN, NL*SB_WD*5) u_delay27 ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(rxdata_osfound_i),    .dout(rxdata_osfound));
delay_n_w_enable
 #(REGIN,       5) u_delay23 ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(rxpkt_error_ptr_i),   .dout(rxpkt_error_ptr));
delay_n_w_enable
 #(REGIN, NL*SB_WD) u_delay24 ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(rxdata_g6_skprm_i),  .dout(rxdata_g6_skprm));
delay_n_w_enable
 #(REGIN, NL*SB_WD) u_delay25 ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(rxdata_g6_skpadd_i), .dout(rxdata_g6_skpadd));
delay_n_w_enable
 #(REGIN, NL*SB_WD) u_delay26 ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(rxdata_eie_det_i),   .dout(rxdata_eie_det));

// Output internal version
wire                    deskew_alignmenterror_i;
wire                    deskew_alignmenterror_dnew_i;
reg                     int_deskew_alignmenterror;
reg                     deskew_complete_i;
wire                    deskew_rxdata_dv_i;
wire                    deskew_rxdata_dv_flit;
wire    [(NL*NB*8)-1:0] deskew_rxdata_i;
wire    [(NL*NB)-1:0]   deskew_rxdatak_i;
wire    [(NL*NB)-1:0]   deskew_rxerror_i;
wire                    slv_do_deskew;
wire    [NL-1:0]        deskew_datastream_bus;
wire                    deskew_datastream;
wire                    deskew_goto_recovery_i;
reg                     g3_any_framerror;
reg                     g3_any_framerror_i;



// Output assignment
// deskew is not bypassed when data rate is GEN3_RATE
wire   cxl_drift_buffer_deskew_enabled = drift_buffer_deskew_enable && ltssm_cxl_ll_mod[1]; // if drift buffer enabled, no deskew required for cxl gen3/4/5 rates to reduce latency

reg     [NL-1:0]        lanes_active;  // registered version of deskew_lanes_active for timing reasons
// do_deskew control for CXL drift buffer and auto lane flip
logic                   smlh_do_deskew_alf;
logic                   smlh_do_deskew;

// Deskew clear for auto lane flip
localparam CNT_WD = `CX_LOGBASE2(`CX_DESKEW_DEPTH + 1);
wire                    deskew_clr_alf_en;
reg  [CNT_WD-1:0]       deskew_clr_alf_cnt;
reg                     deskew_skp_latched;
reg                     deskew_clr_alf;

assign deskew_clr_alf_en = ~cfg_ts2_lid_deskew && (smlh_ltssm_state_i inside {S_CFG_LINKWD_START, S_CFG_LINKWD_ACEPT, S_CFG_LANENUM_ACEPT, S_CFG_LANENUM_WAIT}) && (current_data_rate==`GEN1_RATE || current_data_rate==`GEN2_RATE);
always @(posedge core_clk or negedge core_rst_n) begin : deskew_clr_alf_PROC
    if(~core_rst_n) begin
        deskew_clr_alf_cnt <= #TP 0;
        deskew_skp_latched <= #TP 0;
        deskew_clr_alf     <= #TP 0;
    end
    else begin
        if(deskew_clr_alf_en) begin
            if(~smlh_do_deskew_o) begin //Start
                deskew_clr_alf_cnt <= #TP 1;
                deskew_skp_latched <= #TP |rxdata_skip_i;
                deskew_clr_alf     <= #TP 0;
            end else if(|deskew_clr_alf_cnt) begin
                if(|rxdata_skip) begin //Reset
                    deskew_clr_alf_cnt <= #TP 1;
                    deskew_skp_latched <= #TP 1;
                    deskew_clr_alf     <= #TP 0;
                end else if(deskew_clr_alf)  begin //End
                    deskew_clr_alf_cnt <= #TP 0;
                    deskew_skp_latched <= #TP 0;
                    deskew_clr_alf     <= #TP 0;
                end else begin
                    deskew_clr_alf_cnt <= #TP deskew_clr_alf_cnt + 1;
                    deskew_skp_latched <= #TP deskew_skp_latched;
                    deskew_clr_alf     <= #TP deskew_skp_latched && deskew_clr_alf_cnt==`CX_DESKEW_DEPTH;
                end
            end else begin
                deskew_clr_alf_cnt <= #TP 0;
                deskew_skp_latched <= #TP 0;
                deskew_clr_alf     <= #TP 0;
            end
        end else begin
            deskew_clr_alf_cnt <= #TP 0;
            deskew_skp_latched <= #TP 0;
            deskew_clr_alf     <= #TP 0;
        end
    end
end
assign smlh_do_deskew_alf = smlh_do_deskew_o && ~deskew_clr_alf;

logic                   rxaligned_any;
logic                   rxaligned_any_d;
logic                   rxaligned_any_not_neg;
logic                   rxaligned_any_not_neg_d;
assign rxaligned_any = |rxaligned;
assign rxaligned_any_not_neg = rxaligned_any || !rxaligned_any_d; // Deasserted at negedge of rxaligned_any
always @(posedge core_clk or negedge core_rst_n) begin : rxaligned_any_d_PROC
    if(~core_rst_n) begin
        rxaligned_any_d <= #TP 0;
        rxaligned_any_not_neg_d <= #TP 0;
    end else begin
        rxaligned_any_d <= #TP rxaligned_any;
        rxaligned_any_not_neg_d <= #TP rxaligned_any_not_neg;
    end
end

always_comb begin: smlh_do_deskew_PROC
  if (cxl_drift_buffer_deskew_enabled) begin
    // Deassert do_deskew when all rxvalid is deasserted
    smlh_do_deskew = rxaligned_any_not_neg_d;
  end else begin
    smlh_do_deskew = smlh_do_deskew_alf;
  end
end

logic [(NL*8)-1:0]  pre_deskew_fifo_ptr, tmp_deskew_fifo_ptr;
assign deskew_fifo_ptr = tmp_deskew_fifo_ptr;

always_comb begin: tmp_deskew_fifo_ptr_PROC
  tmp_deskew_fifo_ptr = pre_deskew_fifo_ptr;
  if(cxl_drift_buffer_deskew_enabled) begin
    tmp_deskew_fifo_ptr = drift_buffer_deskew_ptr;
  end
end

wire   deskew_bypass_s = ~( !rmlh_deskew_bypass || (current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE || current_data_rate == `GEN6_RATE) ) | cxl_drift_buffer_deskew_enabled; // bypass only for Gen1/2 rate pcie mode

reg deskew_bypass_d; // safe to delay one cycle for timing closure resolution because deskew takes effect long time later after current_data_rate updates
always @( posedge core_clk or negedge core_rst_n ) begin : deskew_bypass_d_PROC
    if ( ~core_rst_n )
        deskew_bypass_d <= #TP 0;
    else
        deskew_bypass_d <= #TP deskew_bypass_s;
end // deskew_bypass_d_PROC

assign deskew_bypass_i = deskew_bypass_d;
assign deskew_lane_err_bus = deskew_lane_err_bus_i 
            | ({NL{deskew_framing_err && smlh_flit_mode_enable}} & (
                (latched_rxpkt_error)               ? 0 :
                (|latched_deskew_flit_lane_err_bus) ? latched_deskew_flit_lane_err_bus : 
                (skp_error_g6) ? (lanes_active & (deskew_framing_err_g6_bus | g6_skp_os_len_err_bus)) :
                deskew_framing_err_bus
               ))
           ;

assign deskew_alignment_err    = deskew_alignmenterror_i;
assign deskew_complete         = deskew_complete_i;
assign deskew_rxdata_dv        = deskew_rxdata_dv_i;
assign deskew_rxdata           = deskew_rxdata_i;
assign deskew_rxdatak          = deskew_rxdatak_i;
assign deskew_rxerror          = deskew_rxerror_i;
assign deskew_goto_recovery    = deskew_goto_recovery_i;

// Internal regs and wires
wire    [NL-1:0]        deskew_rxdata_dv_bus;
wire    [NL-1:0]        deskew_overflow;            // Deskew logic is overflowing (indicates an error)
wire    [NL-1:0]        deskew_see_idl_os;          // EIOS detected
reg                     any_deskew_see_idl_os;      // A EIOS detected on any active lane
wire    [NL-1:0]        deskew_skp_alignment_err;
wire    [NL-1:0]        deskew_ds_g12;              // in data stream
wire                    deskew_rxdata_flush_gen12;  // active high data flushing signal for pkt_finder at Gen1/2 rate
reg                     deskew_rxdata_flush_gen12_d;// active high data flushing signal for pkt_finder at Gen1/2 rate
wire    [NL-1:0]        deskew_enable;              // deskew takes effect
wire                    deskew_enable_all;
reg                     deskew_rxdata_dv_d;         // latch and clear version to deskew_rxdata_dv
wire                    unload;
wire    [NL-1:0]        deskew_goto_recovery_bus_i;
wire                    framing_err;             //framing error triggers receiver error in gen3 rate as per spec
reg                     framing_err_d;           //framing error triggers receiver error in gen3 rate as per spec

assign                  framing_err = |(deskew_framing_err_bus & lanes_active);

always @(posedge core_clk or negedge core_rst_n) begin : framing_err_d_PROC
    if(~core_rst_n) begin
        framing_err_d         <= #TP '0;
        deskew_framing_err_o  <= #TP '0;
    end
    else begin
        framing_err_d         <= #TP framing_err;
        deskew_framing_err_o  <= #TP deskew_framing_err;
    end
end

assign                  deskew_framing_err = (framing_err & ~framing_err_d);
assign                  deskew_datastream  = &(~lanes_active | deskew_datastream_bus | deskew_latched_l0p_ei_rcvd_bus | deskew_latched_l0p_ei_rcvd_bus_d);

logic [6:0]      deskew_framing_err_ptr ;
wire  [NL*7-1:0] deskew_framing_err_ptr_bus; //framing error pointer in gen3 rate as per spec

always @(posedge core_clk or negedge core_rst_n) begin : deskew_framing_err_ptr_d_PROC
    if(~core_rst_n) begin
        deskew_framing_err_ptr  <= #TP '0 ;
    end
    else begin
        deskew_framing_err_ptr <= #TP (deskew_framing_err_bus[0] & lanes_active[ 0] & ~framing_err_d) ? deskew_framing_err_ptr_bus[ 0*7 +: 7] :
                                      (deskew_framing_err_bus[1] & lanes_active[ 1] & ~framing_err_d) ? deskew_framing_err_ptr_bus[ 1*7 +: 7] :
                                      (deskew_framing_err_bus[2] & lanes_active[ 2] & ~framing_err_d) ? deskew_framing_err_ptr_bus[ 2*7 +: 7] :
                                      (deskew_framing_err_bus[3] & lanes_active[ 3] & ~framing_err_d) ? deskew_framing_err_ptr_bus[ 3*7 +: 7] :
                                      (deskew_framing_err_bus[4] & lanes_active[ 4] & ~framing_err_d) ? deskew_framing_err_ptr_bus[ 4*7 +: 7] :
                                      (deskew_framing_err_bus[5] & lanes_active[ 5] & ~framing_err_d) ? deskew_framing_err_ptr_bus[ 5*7 +: 7] :
                                      (deskew_framing_err_bus[6] & lanes_active[ 6] & ~framing_err_d) ? deskew_framing_err_ptr_bus[ 6*7 +: 7] :
                                      (deskew_framing_err_bus[7] & lanes_active[ 7] & ~framing_err_d) ? deskew_framing_err_ptr_bus[ 7*7 +: 7] :
                                       8'h00;
    end
end


//Gen3 spec: an EIEOS is received on any configured Lane in 128b/130b encoding, move from L0 to Recovery.
//cannot get all lanes rcvd EIEOS at the end of Block at same time as RxDataValid can be anywhere within a Block.
//if all active lanes received EIEOS not at the same time, it is a framing error.
assign                  deskew_goto_recovery_i = ~cxl_drift_buffer_deskew_enabled & deskew_bypass ? 0 : |(lanes_active & deskew_goto_recovery_bus_i); // no goto_recovery if deskew_bypass for Gen1/2 rate
   wire [NB-4-1:0]      useless_vec0;  //no use, for spyglass
   wire [NB-4-1:0]      useless_vec1;  //no use, for spyglass
   wire [NB-4-1:0]      useless_vec2;  //no use, for spyglass
   wire [NB-4-1:0]      useless_vec3;  //no use, for spyglass
   wire [NB-4-1:0]      useless_vec4;  //no use, for spyglass
   wire [NB-4-1:0]      useless_vec5;  //no use, for spyglass
   wire [NB-4-1:0]      useless_vec6;  //no use, for spyglass
   wire [NB-4-1:0]      useless_vec7;  //no use, for spyglass
   wire [NB-4-1:0]      useless_vec8;  //no use, for spyglass
   wire [NB-4-1:0]      useless_vec9;  //no use, for spyglass
   wire [NB-4-1:0]      useless_vec10;  //no use, for spyglass
   wire [NB-4-1:0]      useless_vec11;  //no use, for spyglass
   wire [NB-4-1:0]      useless_vec12;  //no use, for spyglass
   wire [NB-4-1:0]      useless_vec13;  //no use, for spyglass
   wire [NB-4-1:0]      useless_vec14;  //no use, for spyglass
   wire [NB-4-1:0]      useless_vec15;  //no use, for spyglass
   wire [NL-1:0]        skp_vec3;  // collection of lanes, SKP symbol on byte lane 3
   wire [NL-1:0]        skp_vec2;  // collection of lanes, SKP symbol on byte lane 2
   wire [NL-1:0]        skp_vec3_active;  // only active lanes
   wire [NL-1:0]        skp_vec2_active;  // only active lanes
   wire [NL-1:0]        skp_vec1;  // collection of lanes, SKP symbol on byte lane 1
   wire [NL-1:0]        skp_vec1_active;  // only active lanes
   wire [NL-1:0]        skp_vec0;  // collection of lanes, SKP symbol on byte lane 0
   wire [NL-1:0]        skp_vec0_active;  // only active lanes

   wire [NB-1:0]        valid_skp_n;

   // if one lane has a SKP symbol on a particular byte lane, then all active
   // lanes should have a SKP symbol on the same byte lane
assign valid_skp_n = {
                      {NB-4{1'b0}},
                      |skp_vec3_active ^ &skp_vec3_active,
                      |skp_vec2_active ^ &skp_vec2_active,
                      |skp_vec1_active ^ &skp_vec1_active,
                      |skp_vec0_active ^ &skp_vec0_active
                      };

assign skp_vec3_active =  // clear non-active lanes
                          skp_vec3 & lanes_active
                          // make non-active lanes have same value as lane 0, lane 0 must always be active
                        | {NL{skp_vec3[0]}} & ~lanes_active;

assign skp_vec2_active =  // clear non-active lanes
                          skp_vec2 & lanes_active
                          // make non-active lanes have same value as lane 0, lane 0 must always be active
                        | {NL{skp_vec2[0]}} & ~lanes_active;

assign skp_vec1_active =  // clear non-active lanes
                          skp_vec1 & lanes_active
                          // make non-active lanes have same value as lane 0, lane 0 must always be active
                        | {NL{skp_vec1[0]}} & ~lanes_active;

assign skp_vec0_active =  // clear non-active lanes
                          skp_vec0 & lanes_active
                          // make non-active lanes have same value as lane 0, lane 0 must always be active
                        | {NL{skp_vec0[0]}} & ~lanes_active;

assign                  deskew_rxdata_dv_flit   = &(~lanes_active | deskew_rxdata_dv_bus | deskew_latched_l0p_ei_rcvd_bus)
                                                  & lanes_active[0];  // at reset lanes_active==0, need to make sure that at least one lane is active
assign                  deskew_rxdata_dv_i      = (smlh_flit_mode_enable && smlh_ltssm_state == S_LPBK_ACTIVE && ~ltssm_lpbk_master) ? 1'b0 : (current_data_rate < `GEN3_RATE && smlh_flit_mode_enable) ? (deskew_search_for_tokens & deskew_rxdata_dv_flit) : deskew_rxdata_dv_flit;

assign                  unload                  =  deskew_rxdata_dv_flit;

assign                  deskew_enable_all       = &(~deskew_lanes_active | deskew_enable);

always @( posedge core_clk or negedge core_rst_n ) begin : deskew_rxdata_dv_d_PROC
    if ( ~core_rst_n ) begin
        deskew_rxdata_dv_d <= #TP 0;
    end else if ( ~deskew_enable_all ) begin
        deskew_rxdata_dv_d <= #TP 0;
    end else if ( deskew_rxdata_dv ) begin
        deskew_rxdata_dv_d <= #TP 1;
    end
end // deskew_rxdata_dv_d_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : deskew_rxdata_flush_gen12_d_PROC
    if ( ~core_rst_n ) begin
        deskew_rxdata_flush_gen12_d <= #TP 0;
    end else begin
        deskew_rxdata_flush_gen12_d <= #TP deskew_rxdata_flush_gen12;
    end
end // deskew_rxdata_flush_gen12_d_PROC

assign deskew_rxdata_flush_gen12 = smlh_flit_mode_enable ? 1'b0 : (
                                   (current_data_rate==`GEN1_RATE || current_data_rate==`GEN2_RATE) & // flushing only for Gen1/2
                                   ~(smlh_ltssm_state == S_DETECT_QUIET || smlh_ltssm_state == S_DETECT_ACT || smlh_ltssm_state == S_DETECT_WAIT) & // no flushing in Detect states
                                   // if deskew_lanes_active changes, keep previous deskew_rxdata_flush_gen12. Then at next cycle smlh_do_deskew will resets deskew_enable and deskew_rxdata_dv.
                                   // if lanes receives SKP OS and deskew_rxdata_dv=1 and deskew_enable_all=1 during the clock (deskew_lanes_active != lanes_active), needs to disable deskew_rxdata_flush_gen12.
                                   // at the next clock deskew_enable_all will be 0 because deskew gets reset from (deskew_lanes_active != lanes_active), i.e. smlh_do_deskew = 0.
                                   ( (deskew_lanes_active != lanes_active) ? (deskew_rxdata_flush_gen12_d & ~deskew_rxdata_dv) : // ~deskew_rxdata_dv to avoid deskew_rxdata_flush_gen12=1 and deskew_rxdata_dv=1.
                                   ((~deskew_enable_all) ? 1'b1 : // flushing immediately if any active lanes deskew_enable=0
                                                           ~(deskew_rxdata_dv | deskew_rxdata_dv_d) // no flushing if deskew_rxdata_dv = 1
                                   ) )
                                   );

always @(posedge core_clk or negedge core_rst_n) begin : g3_alignerror_Pnew_ltssm_PROC
    if(~core_rst_n)
        g3_any_framerror <= #TP 0;
    else begin
        if ( smlh_ltssm_state == S_RCVRY_LOCK || smlh_ltssm_state == S_CFG_LINKWD_START || current_data_rate == `GEN1_RATE || current_data_rate == `GEN2_RATE ) begin
            g3_any_framerror <= #TP 0;
        end else if ( (current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE || current_data_rate == `GEN6_RATE) && deskew_complete_i && |(deskew_framing_err_bus & lanes_active) &&
                      (smlh_ltssm_state == S_RCVRY_RCVRCFG || smlh_ltssm_state == S_RCVRY_IDLE || smlh_ltssm_state == S_CFG_COMPLETE || smlh_ltssm_state == S_CFG_IDLE || smlh_ltssm_state == S_L0 || ((smlh_ltssm_state == S_L0S) && ~smlh_in_rl0s)) 
                      ) begin
            g3_any_framerror <= #TP 1;
        end
    end
end

always @(posedge core_clk or negedge core_rst_n) begin : g3_alignerror_Pnew_ltssm_i_PROC
    if(~core_rst_n)
        g3_any_framerror_i <= #TP 0;
    else begin
        if ( (current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE || current_data_rate == `GEN6_RATE) ) begin
            if (deskew_complete_i & |(deskew_framing_err_bus & lanes_active))
                g3_any_framerror_i <= #TP 1;
            else if (~|(deskew_framing_err_bus & lanes_active))
                g3_any_framerror_i <= #TP 0;
        end else
            g3_any_framerror_i <= #TP 0;
    end
end
// Check the continuous de-assertion period of the deskew_rxdata_dv signal at 8b/10b encoding.
// If the de-assertion period is over 8 (normal case) or 16 (re-alignment case for l0p), DUT trats it as an alignment error due to flit lost.
wire         g12_flit_alignment_err;
reg    [3:0] g12_flit_alignment_err_cnt;
always @(posedge core_clk or negedge core_rst_n) begin : g12_flit_alignment_err__PROC
    if(~core_rst_n)
        g12_flit_alignment_err_cnt <= #TP 0;
    else begin
        if ( (current_data_rate == `GEN1_RATE || current_data_rate == `GEN2_RATE) && deskew_complete_i && smlh_flit_mode_enable && deskew_search_for_tokens && ~deskew_rxdata_dv) begin
            g12_flit_alignment_err_cnt <= #TP (g12_flit_alignment_err_cnt + 1);
        end else
            g12_flit_alignment_err_cnt <= #TP 0;
    end
end
assign g12_flit_alignment_err = (deskew_rxdata_dv || ~deskew_search_for_tokens) ? 0: 
             (l0p_g12_realign_en_bus[0]) ? g12_flit_alignment_err_cnt==15 : 
 
 (active_nb[1] && deskew_rxdata_link_width[0])   ? g12_flit_alignment_err_cnt>=11 :
                                                                            g12_flit_alignment_err_cnt>=7;

always @(posedge core_clk or negedge core_rst_n)
    if(~core_rst_n)
        int_deskew_alignmenterror <= #TP 1'b0;
    else
        int_deskew_alignmenterror <= #TP
                                      //for gen3 rate, deskew done by alignment to SDS OS
                                      ( current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE || current_data_rate == `GEN6_RATE) ?   (deskew_complete_i & |(deskew_overflow & lanes_active)) :
                                        ( deskew_rxdata_dv_flit & |valid_skp_n & (&(~lanes_active | deskew_ds_g12)))
                                      | g12_flit_alignment_err
                                      | (deskew_complete_i  & |(deskew_skp_alignment_err & lanes_active) )
                                      | (deskew_complete_i  & |(deskew_overflow & lanes_active));

assign deskew_alignmenterror_i = ~cxl_drift_buffer_deskew_enabled & deskew_bypass ? 0 : // no alignment error if bypass deskew for Gen1/2 rate
                                 int_deskew_alignmenterror
                                 | g3_any_framerror
                                 & !cdm_ras_des_ferr_rec_dis
                                 ;
assign deskew_alignmenterror_dnew_i = ~cxl_drift_buffer_deskew_enabled & deskew_bypass ? 0 : // no alignment error if bypass deskew for Gen1/2 rate
                                      int_deskew_alignmenterror 
                                      | g3_any_framerror_i 
                                      & !cdm_ras_des_ferr_rec_dis
 ;

always @(posedge core_clk or negedge core_rst_n) begin : any_deskew_see_idl_os_PROC
    if (~core_rst_n)
        any_deskew_see_idl_os <= #TP 0;
    else
        any_deskew_see_idl_os <= #TP ( |( deskew_see_idl_os & lanes_active) );
end

always @(posedge core_clk or negedge core_rst_n)
    if(~core_rst_n)
      deskew_complete_i <= #TP 1'b0;
    else if ( ~cxl_drift_buffer_deskew_enabled & deskew_bypass )
      deskew_complete_i <= #TP 1'b1; // always deskew complete if bypass deskew for Gen1/2 rate
    else if (  deskew_alignmenterror_dnew_i
             | ~smlh_do_deskew
             | (any_deskew_see_idl_os
                & ((current_data_rate != `GEN3_RATE && current_data_rate != `GEN4_RATE && current_data_rate != `GEN5_RATE && current_data_rate != `GEN6_RATE))
               ) )
      deskew_complete_i <= #TP 1'b0;
    else if (deskew_rxdata_dv_flit)
      deskew_complete_i <= #TP 1'b1;  // we are only complete on the deskew if there is
                                      //  no alignment error and we are being told to do_deskew

assign slv_do_deskew = 
                       (current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE || current_data_rate == `GEN6_RATE) ? (~deskew_alignmenterror_dnew_i & smlh_do_deskew) : //deskew_see_idl_os done in S_EI_OS state in deskew3_rd_slv for gen3 rate
                       (~deskew_alignmenterror_i & smlh_do_deskew & ~any_deskew_see_idl_os);

wire [(NL*NB)-1:0] deskew_skp_i;

wire sft_rising_edge, sft_falling_edge; // sft = search_for_tokens
wire [NL-1:0] deskew_search_for_tokens_bus_i;
reg  deskew_search_for_tokens_d;
assign deskew_search_for_tokens = (smlh_flit_mode_enable && smlh_ltssm_state == S_LPBK_ACTIVE && ~ltssm_lpbk_master) ? 1'b0 : (current_data_rate >= `GEN3_RATE) ? |(deskew_search_for_tokens_bus_i & lanes_active) : &(deskew_search_for_tokens_bus_i | ~deskew_lanes_active);
always @( posedge core_clk or negedge core_rst_n ) begin : deskew_search_for_tokens_d_PROC
    if ( ~core_rst_n )
        deskew_search_for_tokens_d <= #TP 0;
    else
        deskew_search_for_tokens_d <= #TP deskew_search_for_tokens;
end // deskew_search_for_tokens_d_PROC
assign sft_rising_edge = deskew_search_for_tokens & ~deskew_search_for_tokens_d;
assign sft_falling_edge = ~deskew_search_for_tokens & deskew_search_for_tokens_d;

always @(posedge core_clk or negedge core_rst_n) begin : latched_deskew_rxdata_link_width_PROC
    if(~core_rst_n) begin
        latched_deskew_rxdata_link_width <= #TP 1;
    end else begin
        latched_deskew_rxdata_link_width <= #TP (deskew_rxdata_dv_flit || ~deskew_search_for_tokens) ?  deskew_rxdata_link_width : latched_deskew_rxdata_link_width;
    end
end

assign deskew_rxdata_link_width = f_link_width((lanes_active & ~deskew_latched_l0p_ei_rcvd_bus), latched_deskew_rxdata_link_width);

//Making link width
function automatic [4:0] f_link_width;
      input [NL-1:0] lanes_active;
      input [4:0]    latched_link_width;
      reg   [15:0]   pre_lanes_active;
      begin
          pre_lanes_active = { {16 - NL{1'b0}}, lanes_active};

          case(pre_lanes_active)
              16'h00ff : f_link_width = 5'b01000; // x8
              16'h000f : f_link_width = 5'b00100; // x4
              16'h0003 : f_link_width = 5'b00010; // x2
              16'h0001 : f_link_width = 5'b00001; // x1
              default  : f_link_width = latched_link_width;
          endcase
      end
endfunction
wire [NL-1:0] deskew_skp_rcvd_bus;
wire [NL-1:0] deskew_eie_rcvd_bus;
wire [NL-1:0] deskew_accept_eds_cycle_bus_i;
wire [NL-1:0] deskew_expect_eds_bus_i;
wire [NL-1:0] deskew_empty_bus_i;
wire [NL-1:0] deskew_os_in_datastream_bus_i;
wire          deskew_accept_eds_cycle;
wire          deskew_os_in_datastream;
wire sds_rcvd_all = &(~lanes_active | deskew_sds_rcvd_bus | ((~deskew_latched_l0p_ei_rcvd_bus | ~ltssm_l0p_lanes_active) & {NL{|deskew_latched_l0p_ei_rcvd_bus & |deskew_sds_rcvd_bus}}));
wire skp_rcvd_all = &(~lanes_active | deskew_skp_rcvd_bus);
wire ei_rcvd_all  = &(~lanes_active | deskew_ei_rcvd_bus);
assign eie_rcvd_all = &(~lanes_active | deskew_eie_rcvd_bus | deskew_latched_l0p_ei_rcvd_bus);
wire unempty_all  = (smlh_flit_mode_enable && (current_data_rate >= `GEN3_RATE) && deskew_skp_rcvd_bus[0] && (|deskew_ei_rcvd_bus[NL-1:1] || |deskew_ei_rcvd_bus_d[NL-1:1] || l0p_skp_data_rcving_any_bus[0])) ? 1'b0 :
                    &(~lanes_active | ~deskew_empty_bus_i | deskew_latched_l0p_ei_rcvd_bus); //all lanes buffers are not empty

wire          skp_ei_rcvd_all;
wire [NL-1:0] l0p_ei_rcvd_all;
wire          l0p_arrow_skp_ei_rcvd;
wire          l0p_ei_rcvd_any;
wire          l0p_skp_rcvd_any;
wire [NL-1:0] l0p_g12_realign_point_done_bus;
wire [NL-1:0] deskew_l0p_skp_data_rcving_bus;
wire [NL-1:0] deskew_l0p_skp_rcving_full_bus;
wire [NL-1:0] deskew_l0p_g12_skp_data_rcvd_bus;
wire [NL-1:0] deskew_l0p_skp_ts_rcving_bus;
wire [NL-1:0] l0p_g3_realign_en_bus;
wire [NL-1:0] l0p_realign_point_done_bus;
wire [NL-1:0] l0p_eios_det_en_bus;

assign l0p_ei_rcvd_all = deskew_ei_rcvd_bus | deskew_latched_l0p_ei_rcvd_bus;
assign l0p_arrow_skp_ei_rcvd =
                 (lanes_active[4]) ? (( deskew_skp_rcvd_bus[  0]  && &l0p_ei_rcvd_all[ 7:1])     //x1
                                   || (&deskew_skp_rcvd_bus[1:0]  && &l0p_ei_rcvd_all[ 7:2])     //x2
                                   || (&deskew_skp_rcvd_bus[3:0]  && &l0p_ei_rcvd_all[ 7:4])     //x4
                                   || (&deskew_skp_rcvd_bus[7:0]  || &l0p_ei_rcvd_all[ 7:0])) :  //x8
                 (lanes_active[2]) ? (( deskew_skp_rcvd_bus[  0]  && &l0p_ei_rcvd_all[ 3:1])     //x1
                                   || (&deskew_skp_rcvd_bus[1:0]  && &l0p_ei_rcvd_all[ 3:2])     //x2
                                   || (&deskew_skp_rcvd_bus[3:0]  || &l0p_ei_rcvd_all[ 3:0])) :  //x4
                 (lanes_active[1]) ? (( deskew_skp_rcvd_bus[  0]  &&  l0p_ei_rcvd_all[   1])     //x1
                                   || (&deskew_skp_rcvd_bus[1:0]  || &l0p_ei_rcvd_all[ 1:0])) :  //x2
                                      ( deskew_skp_rcvd_bus[0]    ||  l0p_ei_rcvd_all[0] );
assign skp_ei_rcvd_all = l0p_arrow_skp_ei_rcvd;
assign l0p_ei_rcvd_any = l0p_arrow_skp_ei_rcvd & |deskew_ei_rcvd_bus;
assign l0p_skp_rcvd_any = |(deskew_skp_rcvd_bus & ltssm_l0p_last_lanes_active);

always @(posedge core_clk or negedge core_rst_n) begin : deskew_latched_l0p_ei_rcvd_bus_d_PROC
    if(~core_rst_n) begin
        deskew_ei_rcvd_bus_d              <= #TP 0;
        deskew_latched_l0p_ei_rcvd_bus_d  <= #TP 0;
    end else begin
        deskew_ei_rcvd_bus_d              <= #TP deskew_ei_rcvd_bus;
        deskew_latched_l0p_ei_rcvd_bus_d  <= #TP deskew_latched_l0p_ei_rcvd_bus;
    end
end


// Set the window flag for l0p upsizing. If SKP-OS is receiving, the flag is set after a period of maximum depth is passed. 
// This flag is cleared when L0p upsize done (ltssm_l0p_next_link_mode[4:0]==deskew_rxdata_link_width).
reg  l0p_realign_en_window;
reg  [`CX_DESKEW_ADDR_WIDTH-1:0] l0p_realign_skp_cnt;
always @(posedge core_clk or negedge core_rst_n) begin : l0p_realign_en_window_PROC
    if(~core_rst_n) begin
        l0p_realign_en_window            <= #TP 0;
        l0p_realign_skp_cnt              <= #TP 0;
    end else begin
        if(ltssm_l0p_next_link_mode[4:0]==deskew_rxdata_link_width || ~slv_do_deskew || ~ltssm_in_l0p || ~(smlh_ltssm_state == S_RCVRY_LOCK || smlh_ltssm_state == S_L0)) begin
            l0p_realign_en_window            <= #TP 0;
            l0p_realign_skp_cnt              <= #TP 0;
        end else begin
            l0p_realign_en_window            <= #TP (ltssm_in_l0p_upsize && l0p_realign_skp_cnt==0 && rxdata_skip==0) ? 1'b1 : l0p_realign_en_window;
            l0p_realign_skp_cnt              <= #TP (|rxdata_skip && ~l0p_realign_en_window) ? 1 : (|l0p_realign_skp_cnt && l0p_realign_skp_cnt!= `CX_DESKEW_DEPTH) ? l0p_realign_skp_cnt + 1 : 0;
        end
    end
end

// Make the window flags for gen1-2 or gen3-6 per lanes
assign l0p_g12_realign_en_bus = ((current_data_rate <  `GEN3_RATE) && l0p_realign_en_window) ? ltssm_l0p_lanes_active : 0;
assign l0p_g3_realign_en_bus  = ((current_data_rate >= `GEN3_RATE) && l0p_realign_en_window) ? ltssm_l0p_lanes_active : 0;
assign l0p_skp_data_rcving_any_bus = |deskew_l0p_skp_data_rcving_bus ? ltssm_l0p_lanes_active : 0;
assign l0p_eios_det_en_bus = {{NL-1{1'b1}},1'b0};

// Make the flag that SKP-OS is received on all active lanes
wire [NL-1:0] sel_deskew_l0p_skp_data_rcvd_bus;
assign sel_deskew_l0p_skp_data_rcvd_bus = (current_data_rate < `GEN3_RATE) ? deskew_l0p_g12_skp_data_rcvd_bus : deskew_skp_rcvd_bus;
assign l0p_realign_point_done_bus = (l0p_realign_en_window &&
                                  ((sel_deskew_l0p_skp_data_rcvd_bus == ltssm_l0p_lanes_active) // flit are received on all active lanes
                              || (((deskew_l0p_skp_data_rcving_bus|deskew_l0p_skp_ts_rcving_bus)== ltssm_l0p_lanes_active) && |deskew_l0p_skp_ts_rcving_bus) // TS-OS are received on activated lanes
                              ||  (|deskew_l0p_skp_rcving_full_bus))) ? ltssm_l0p_lanes_active : 0; // the waiting period is reached the maximum cycles.

// Receivers of a multi-Lane Link report an error for any Lane that caused the Framing Error in the Lane Error Status register.
localparam S_NO_DESKEW    = 3'd0;
localparam S_WAIT_FOR_SDS = 3'd1;
localparam S_DATA_STREAM  = 3'd2;
localparam S_SKP_OS       = 3'd3;
localparam S_EI_OS        = 3'd4;
localparam S_EIE_OS       = 3'd5;
localparam S_FRAMING_ERR  = 3'd6;

always_comb begin : check_deskew_rd_state_PROC
    integer i;
    begin
        deskew_flit_lane_err_bus = 0;
        if(smlh_flit_mode_enable) begin
            for (i=1; i<NL; i=i+1) begin
                // check lane#N against lane#0
                deskew_flit_lane_err_bus[i] = lanes_active[i] && (deskew_rd_state_bus[i*3 +: 3] != deskew_rd_state_bus[0 +: 3]) && ~deskew_latched_l0p_ei_rcvd_bus[i];
            end
        end
    end
end // check_deskew_rd_state_PROC

always @(posedge core_clk or negedge core_rst_n) begin : latched_deskew_flit_lane_err_bus_PROC
    if(~core_rst_n) begin
        latched_deskew_flit_lane_err_bus <= #TP 0;
        latched_rxpkt_error              <= #TP 0;
    end else begin
        if((current_data_rate >= `GEN3_RATE) && smlh_flit_mode_enable) begin
            if(deskew_rd_state_bus[0 +: 3]==S_FRAMING_ERR) begin // keep
                latched_deskew_flit_lane_err_bus <= #TP latched_deskew_flit_lane_err_bus;
                latched_rxpkt_error              <= #TP latched_rxpkt_error;
            end else if(deskew_rd_state_bus[0 +: 3]==S_NO_DESKEW || deskew_rd_state_bus[0 +: 3]==S_WAIT_FOR_SDS) begin // clear
                latched_deskew_flit_lane_err_bus <= #TP 0;
                latched_rxpkt_error              <= #TP 0;
            end else begin // set
                latched_deskew_flit_lane_err_bus <= #TP deskew_flit_lane_err_bus;
                latched_rxpkt_error              <= #TP rxpkt_error | latched_rxpkt_error;
            end
        end else begin
            latched_deskew_flit_lane_err_bus <= #TP 0;
            latched_rxpkt_error              <= #TP 0;
        end
    end
end
always_comb begin : check_skp_os_length__PROC
    integer i;
    begin
        g6_skp_os_len_err_bus = 0; 
        if(!(smlh_ltssm_state inside {S_LPBK_ACTIVE, S_LPBK_EXIT})) begin
            for (i=1; i<NL; i=i+1) begin
                g6_skp_os_len_err_bus[i] = (deskew_skp_os_len_g6_bus[i*3 +: 3] != deskew_skp_os_len_g6_bus[0 +: 3]) && ((deskew_rd_state_bus[i*3 +: 3] == S_DATA_STREAM) || (deskew_rd_state_bus[i*3 +: 3] == S_SKP_OS) || (deskew_rd_state_bus[i*3 +: 3] == S_FRAMING_ERR));
            end
        end
    end
end // check_skp_os_length__PROC
assign skp_error_g6 = |(lanes_active & (deskew_framing_err_g6_bus | g6_skp_os_len_err_bus)) && (current_data_rate == `GEN6_RATE);

//assume all Lanes are aligned after deskew. So need OR gate
assign deskew_accept_eds_cycle  = |(deskew_accept_eds_cycle_bus_i & lanes_active);
assign deskew_expect_eds        = |(deskew_expect_eds_bus_i & lanes_active);

// STAR 9000466011: fix for IT#2227
// search_for_tokens_bus_i is asserted at the same time, but may deassert at different times depending on skew.
// search_for_tokens=0 is used in pkt_finder to set rxdata3_dv=1, needed to flush the pipeline in token_finder3.
// Therefore here we need to use OR logic instead of AND logic, to allow rxdata_dv=0 cycles to propagate into 
// rxdata3_dv=0 cycles in token finder for the cases where search_for_tokens_bus_i is deasserted at different 
// times, otherwise (IT#2227) the eds_rcvd information in token finder would be generated misaligned (anticipated) 
// with respect to the eds_exp information, with the result of spurious eds errors.
assign deskew_os_in_datastream  = |(deskew_os_in_datastream_bus_i & lanes_active);


wire [NL-1:0] smseq_ts1_rcvd_pulse_bus_int = smseq_ts1_rcvd_pulse_bus[NL-1:0];
wire [NL-1:0] smseq_ts2_rcvd_pulse_bus_int = smseq_ts2_rcvd_pulse_bus[NL-1:0];
wire [(NL*NB)-1:0]        rxdata_comma_int = rxdata_comma[(NL*NB)-1:0];
wire [NL*4-1:0] smseq_loc_ts2_rcvd_bus_int = smseq_loc_ts2_rcvd_bus[NL*4-1:0];
wire [NL*4-1:0] smseq_loc_eies_rcvd_bus_int= smseq_loc_eies_rcvd_bus[NL*4-1:0];

rmlh_deskew_slv
 #(INST) u_rmlh_deskew_slv[NL-1:0] //  per lane array of instances
(
// ---- inputs ---------------
    .core_rst_n                   (core_rst_n),
    .core_clk                     (core_clk),
    .cfg_elastic_buffer_mode      (cfg_elastic_buffer_mode),
    .cxl_drift_buffer_deskew_enabled (cxl_drift_buffer_deskew_enabled),
    .cfg_ts2_lid_deskew           (cfg_ts2_lid_deskew),
    .prbs_en_int                  (prbs_en_int),
    .delay_en                     (delay_en),
    .active_nb                    (active_nb),

    .slv_do_deskew                (slv_do_deskew),
    .smseq_ts1_rcvd_pulse         (smseq_ts1_rcvd_pulse_bus_int[NL-1:0]),
    .smseq_ts2_rcvd_pulse         (smseq_ts2_rcvd_pulse_bus_int[NL-1:0]),
    .smseq_loc_ts2_rcvd           (smseq_loc_ts2_rcvd_bus_int[NL*4-1:0]),
    .smseq_in_skp                 (smseq_in_skp_bus[NL*4-1:0]),
    .smseq_fts_skp_do_deskew      (smseq_fts_skp_do_deskew_bus[NL-1:0]),
    .smseq_loc_eies_rcvd          (smseq_loc_eies_rcvd_bus_int[NL*4-1:0]),
    .rxdata_dv                    (rxdata_dv[NL-1:0]),
    .rxaligned                    (rxaligned[NL-1:0]),
    .rxdata                       (rxdata[(NL*NB*8)-1:0]),
    .rxdata_comma                 (rxdata_comma_int[(NL*NB)-1:0]),
    .rxdata_skip                  (rxdata_skip[(NL*NB)-1:0]),
    .rxdata_skprm                 (rxdata_skprm[(NL*NB)-1:0]),
    .rxdatak_i                    (rxdatak[(NL*NBK)-1:0]),
    .rxerror                      (rxerror[(NL*NB)-1:0]),
    .rxdata_eie_det               (rxdata_eie_det[(NL*SB_WD)-1:0]),
    .rxdata_g6_skprm              (rxdata_g6_skprm[(NL*SB_WD)-1:0]),
    .rxdata_g6_skpadd             (rxdata_g6_skpadd[(NL*SB_WD)-1:0]),
    .current_data_rate            (current_data_rate[2:0]),
    .smlh_ltssm_state             (smlh_ltssm_state),
    .cxl_mode_enable_i            (cxl_mode_enable),
    .smlh_in_rl0s                 (smlh_in_rl0s),
    .ltssm_lpbk_master            (ltssm_lpbk_master),
    .smlh_flit_mode_enable        (smlh_flit_mode_enable),
    .sft_falling_edge             (sft_falling_edge),
    .rxstartblock                 (rxstartblock[NL*SB_WD-1:0]),
    .rxeven_parity                (rxeven_parity[NL*SB_WD-1:0]),
    .rxdata_osfound               (rxdata_osfound),
    .sds_rcvd_all                 (sds_rcvd_all),
    .skp_rcvd_all                 (skp_rcvd_all),
    .ei_rcvd_all                  (ei_rcvd_all),
    .eie_rcvd_all                 (eie_rcvd_all),
    .skp_ei_rcvd_all              (skp_ei_rcvd_all),
    .unempty_all                  (unempty_all),
    .rxpkt_error                  (rxpkt_error),
    .skp_error_g6                 (skp_error_g6),
    .lanes_active                 (lanes_active[NL-1:0]),
    .l0p_lanes_active             (ltssm_l0p_lanes_active[NL-1:0]),
    .l0p_last_lanes_active        (ltssm_l0p_last_lanes_active[NL-1:0]),
    .l0p_realign_point_done       (l0p_realign_point_done_bus[NL-1:0]),
    .l0p_g12_realign_en           (l0p_g12_realign_en_bus[NL-1:0]),
    .l0p_skp_data_rcving_any      (l0p_skp_data_rcving_any_bus[NL-1:0]),
    .l0p_g3_realign_en            (l0p_g3_realign_en_bus[NL-1:0]),
    .l0p_ei_rcvd_any              (l0p_ei_rcvd_any),
    .l0p_skp_rcvd_any             (l0p_skp_rcvd_any),
    .l0p_eios_det_en              (l0p_eios_det_en_bus[NL-1:0]),
    .ltssm_in_l0p                 (ltssm_in_l0p),
    .rxpkt_error_ptr              (rxpkt_error_ptr),
    .cdm_ras_des_ferr_rec_dis     (cdm_ras_des_ferr_rec_dis),
    .unload                       (unload),
    .deskew_bypass_i              (deskew_bypass_i),
    .rpipe_eios_eieos_det         (rpipe_eios_eieos_det),
// ---- outputs ---------------
    .deskew_rxdata_dv             (deskew_rxdata_dv_bus), // www: putting [NL-1:0] causes simulator to badly initialize bus and later cause X's
    .deskew_rxdata                (deskew_rxdata_i[(NL*NB*8)-1:0]),
    .deskew_rxdatak               (deskew_rxdatak_i[(NL*NB)-1:0]),
    .deskew_rxerror               (deskew_rxerror_i[(NL*NB)-1:0]),
    .deskew_overflow              (deskew_overflow[NL-1:0]),
    .deskew_skp                   (deskew_skp_i[(NL*NB)-1:0]),
    .deskew_search_for_tokens     (deskew_search_for_tokens_bus_i[NL-1:0]), // internal vector
    .deskew_rd_state              (deskew_rd_state_bus[NL*3-1:0]),
    .deskew_datastream            (deskew_datastream_bus),
    .deskew_framing_err           (deskew_framing_err_bus[NL-1:0]),
    .deskew_goto_recovery         (deskew_goto_recovery_bus_i[NL-1:0]), //internal vector
    .deskew_sds_rcvd              (deskew_sds_rcvd_bus[NL-1:0]),
    .deskew_skp_rcvd              (deskew_skp_rcvd_bus[NL-1:0]),
    .deskew_ei_rcvd               (deskew_ei_rcvd_bus[NL-1:0]),
    .deskew_eie_rcvd              (deskew_eie_rcvd_bus[NL-1:0]),
    .deskew_os_in_datastream      (deskew_os_in_datastream_bus_i[NL-1:0]),  // internal vector
    .deskew_expect_eds            (deskew_expect_eds_bus_i[NL-1:0]),  // internal vector
    .deskew_accept_eds_cycle      (deskew_accept_eds_cycle_bus_i[NL-1:0]),  // internal vector
    .deskew_lane_err              (deskew_lane_err_bus_i[NL-1:0]),
    .deskew_framing_err_ptr       (deskew_framing_err_ptr_bus[NL*7-1:0]),
    .deskew_lane_err_skp_parity   (deskew_lane_err_skp_parity_bus[NL-1:0]),
    .deskew_lane_err_sync_header  (deskew_lane_err_sync_header_bus[NL-1:0]),
    .deskew_empty                 (deskew_empty_bus_i[NL-1:0]), //internal bus
    .deskew_ctlskp_rcvd           (deskew_ctlskp_rcvd[NL-1:0]),
    .deskew_ctlskp_info           (deskew_ctlskp_info[(NL*16-1):0]),
    .deskew_ctlskp_err            (deskew_ctlskp_err[(NL*5)-1:0]),
    .deskew_framing_err_g6        (deskew_framing_err_g6_bus[NL-1:0]),
    .deskew_skp_os_len_g6         (deskew_skp_os_len_g6_bus[(NL*3)-1:0]),
    .deskew_g6_data_stream        (deskew_ds_g6[NL-1:0]),
    .deskew_fltlog_ctrl_skp_mismatch  (deskew_fltlog_ctrl_skp_mismatch_bus[NL-1:0]),
    .deskew_latched_l0p_ei_rcvd   (deskew_latched_l0p_ei_rcvd_bus[NL-1:0]),
    .deskew_l0p_g12_skp_data_rcvd (deskew_l0p_g12_skp_data_rcvd_bus[NL-1:0]),
    .deskew_l0p_skp_ts_rcving     (deskew_l0p_skp_ts_rcving_bus[NL-1:0]),
    .deskew_l0p_skp_data_rcving   (deskew_l0p_skp_data_rcving_bus[NL-1:0]),
    .deskew_l0p_skp_rcving_full   (deskew_l0p_skp_rcving_full_bus[NL-1:0]),
    .deskew_fifo_ptr              (pre_deskew_fifo_ptr[(NL*8)-1:0]),
    .deskew_see_idl_os            (deskew_see_idl_os[NL-1:0]),
    .deskew_enable                (deskew_enable[NL-1:0]),
    .deskew_ds_g12                (deskew_ds_g12[NL-1:0]),
    .deskew_skp_alignment_err     (deskew_skp_alignment_err[NL-1:0])
);

   assign  {
            useless_vec0,
            skp_vec3[0], skp_vec2[0],
            skp_vec1[0],
            skp_vec0[0]} = deskew_skp_i[(0*NB)+NB-1:(0*NB)];

   assign  {
            useless_vec1,
            skp_vec3[1], skp_vec2[1],
            skp_vec1[1],
            skp_vec0[1]} = deskew_skp_i[(1*NB)+NB-1:(1*NB)];

   assign  {
            useless_vec2,
            skp_vec3[2], skp_vec2[2],
            skp_vec1[2],
            skp_vec0[2]} = deskew_skp_i[(2*NB)+NB-1:(2*NB)];

   assign  {
            useless_vec3,
            skp_vec3[3], skp_vec2[3],
            skp_vec1[3],
            skp_vec0[3]} = deskew_skp_i[(3*NB)+NB-1:(3*NB)];

   assign  {
            useless_vec4,
            skp_vec3[4], skp_vec2[4],
            skp_vec1[4],
            skp_vec0[4]} = deskew_skp_i[(4*NB)+NB-1:(4*NB)];

   assign  {
            useless_vec5,
            skp_vec3[5], skp_vec2[5],
            skp_vec1[5],
            skp_vec0[5]} = deskew_skp_i[(5*NB)+NB-1:(5*NB)];


   assign  {
            useless_vec6,
            skp_vec3[6], skp_vec2[6],
            skp_vec1[6],
            skp_vec0[6]} = deskew_skp_i[(6*NB)+NB-1:(6*NB)];

   assign  {
            useless_vec7,
            skp_vec3[7], skp_vec2[7],
            skp_vec1[7],
            skp_vec0[7]} = deskew_skp_i[(7*NB)+NB-1:(7*NB)];



// Register the active lanes to help with timing.
always @(posedge core_clk or negedge core_rst_n)
    if(~core_rst_n)
        lanes_active <= #TP {NL{1'b0}};
    else
        lanes_active <= #TP deskew_lanes_active;

// ASSERTIONS!
//
// want to see a COM on some lanes, with smlh_do_deskew low
// then within 5 clocks I want to see COM on the other lanes with smlh_do_deskew high
//    this should result in an overflow on the later lanes, thereby reseting the rmlh_deskew_slv logic
//
// deskew_rxdata_dv should not be asserted when deskew_complete is low

// COVERAGE!
//
//  BFM transitions tx to electrical idle w/o sending an EIOS (and skew changes)
//
//  want to see an alignment error (deskew_alignmenterror)
//

/* -----\/----- EXCLUDED -----\/-----
property p_comma0 ;
  @(posedge core_clk) rxdata_dv && rxdatak[0] && (rxdata[7:0]==`COMMA_8B);
endproperty

property p_comma1 ;
  @(posedge core_clk) rxdata_dv && rxdatak[1] && (rxdata[15:8]==`COMMA_8B);
endproperty

property p_comma2 ;
  @(posedge core_clk) rxdata_dv && rxdatak[2] && (rxdata[23:16]==`COMMA_8B);
endproperty

property p_comma3 ;
  @(posedge core_clk) rxdata_dv && rxdatak[3] && (rxdata[31:24]==`COMMA_8B);
endproperty

  c_comma0 : cover property (p_comma0);

property p_comma0_no_do_deskew ;
   @(posedge core_clk) rxdata_dv && rxdatak[0] && (rxdata[7:0]==`COMMA_8B) && ~smlh_do_deskew ;
endproperty

property p_comma3_do_deskew ;
   @(posedge core_clk) rxdata_dv && rxdatak[3] && (rxdata[31:24]==`COMMA_8B) && smlh_do_deskew ;
endproperty

property p_this_is_it ;
   @(posedge core_clk) (rxdata_dv && rxdatak[0] && (rxdata[7:0]==`COMMA_8B) && ~smlh_do_deskew) |-> ##[1:5] (rxdata_dv && rxdatak[3] && (rxdata[31:24]==`COMMA_8B) && smlh_do_deskew) ;
endproperty

  c_comma0_no_do_deskew : cover property (p_comma0_no_do_deskew);
  c_comma3_do_deskew    : cover property (p_comma3_do_deskew);
  c_this_is_it : cover property (p_this_is_it);
 -----/\----- EXCLUDED -----/\----- */


endmodule
