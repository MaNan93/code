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
// ---    $Revision: #14 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/scramble.sv#14 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// -- PCI-E scrambler - Top-level
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Layer1/xmlh_pkg.svh"

 
 module scramble
 import DWC_pcie_core_pkg::ltssm_state_e;
 import DWC_pcie_core_pkg::S_RCVRY_SPEED;
 import xmlh_pkg::data_rate_enc_t;
 (
// ---- inputs ---------------
    core_rst_n,
    core_clk,
    cfg_elastic_buffer_mode,
    scrambler_disable,
    scrambler_disable_lanes_l0p,
    smlh_l0p_link_mode,
    l0p_sris_mode_enabled,
    data_dv,
    data,
    datak,
    error,
    wait4idle,
    rxskipremoved,
    data_osfound, 
    rxskipadded,
    gen6_compliance_sending,
    active_nb,
    aligned,
    latched_smlh_link_up,
    latched_flip_ctrl,
    smlh_lane_flip_ctrl,
    cfg_no_seed_value_change,
    active_nb_gen34,
    xmtbyte_txelecidle,
    current_data_rate,
    smlh_link_mode,
    cfg_gen3_scrambler_disable,
    cfg_gen3_dc_balance_disable,
    startblock,
    skp_os_align_sts,
    ltssm_in_compliance,
    smlh_ltssm_state,
    cfg_precoding_enable,
    smlh_flit_mode_enable,
    lanes_active,
    crnt_rate_enc,

// ---- outputs ---------------
    scramble_lfsr_rollover,
    scramble_startblock,
    scramble_even_parity,
    scramble_inskp,
    scramble_skp_os_align_sts,
    scramble_data_osfound,
    scramble_ints0,
    scramble_dcb_det,
    scramble_data_g6_skprm,
    scramble_data_g6_skpadd,
    scramble_ints1,
    scramble_ints2,
    scramble_ineie,
    scramble_eie_det,
    scramble_insds,
    scramble_data_dv,
    scramble_aligned,
    scramble_data,
    scramble_data_comma,
    scramble_data_skip,
    scramble_data_skprm,
    scramble_datak,
    scramble_error,
    wait4idle_nd
);
parameter   INST                          = 0;         // The uniquifying parameter for each port logic instance.
parameter   RX_SIDE                       = 1;         // Tx:0 / Rx:1
parameter   REGOUT                        = 1;         // Optional output registering
parameter   GEN3_REGIN                    = 1;         // Optional input registering for 128b/130b encoding
parameter   GEN3_REGOUT                   = 1;         // Optional output registering for 128b/130b encoding
parameter   GEN3_LFSR_REGOUT              = 0;         // Optional output registering for LFSR
parameter   PRECODING_REGOUT              = 1;         // Optional output registering for precoding
parameter   GLAYCODING_REGOUT             = 0;         // Optional output registering for graycoding
parameter   DCB_WD                        = (`CX_NB>=8 ? `CX_NB/8 : 1); // Number of DC balance bits
parameter   CALC_PARITY_BEFORE_SCRAMBLE   = 0;         // Select parity of scrambler input data or scrambler output data
parameter   NL                            = `CX_NL;    // Max number of lanes supported
parameter   NB                            = `CX_NB;    // Number of symbols (bytes) per clock cycle
parameter   NBK                           = `CX_NBK;   // Number of symbols (bytes) per clock cycle for datak
parameter   AW                            = `CX_ANB_WD;// Width of the active number of bytes
parameter   L2NL                          = NL==1 ? 1 : `CX_LOGBASE2(NL);
parameter   SB_WD                         = `CX_MAC_SB_WD;  // Number of bits of per txstartblock  
parameter   SH_WD                         = `CX_MAC_SH_WD;  // Number of bits of per txsyncheader

input                   core_rst_n;
input                   core_clk;
input                   cfg_elastic_buffer_mode;
input                   scrambler_disable;  // This will always affect 2 bytes when in 2S mode (NB=2)
input   [NL-1:0]        scrambler_disable_lanes_l0p; // DIsable TS-OS for l0p in gen1 and gen2
input   [5:0]           smlh_l0p_link_mode;          // 10000 -- x16, 01000 -- x8, 00100 -- x4, 00010 -- x2, 00001 -- x1
input                   l0p_sris_mode_enabled;       // SRIS enabled or app_sris_mode=1
input   [NL-1:0]        data_dv;            // data bytes are valid
input   [(NL*NB*8)-1:0] data;               // data bytes
input   [(NL*NBK)-1:0]  datak;              // K character indication for each byte
input   [(NL*NB)-1:0]   error;              // error indication for each byte
input   [NL-1:0]        wait4idle;          // For PRBS loopback, to meet the delayed cycle in this module
input   [NL*SB_WD-1:0]  rxskipremoved;      // skip symbol removed flag
input   [NL-1:0][SB_WD-1:0][4:0]   data_osfound;       // OS detection flag
input   [NL*SB_WD-1:0]  rxskipadded;        // skip symbol add flag
input                   gen6_compliance_sending; // Compliance pattern is sending at gen6 rate
input   [AW-1:0]        active_nb;
input   [NL-1:0]        aligned;                      //gates: must revisit
input                   latched_smlh_link_up;
input   [L2NL-1:0]      latched_flip_ctrl;   //latch smlh_lane_flip_ctrl at the rising edge of smlh_link_up
input   [L2NL-1:0]      smlh_lane_flip_ctrl;
input                   cfg_no_seed_value_change;     //1: no seed value change for Gen3 scrambler after linkup
input   [AW-1:0]        active_nb_gen34;
input   [NL-1:0]        xmtbyte_txelecidle;           //transmit eidle
input   [2:0]           current_data_rate;            //0-gen1, 1-gen2, 2-gen3, 3-gen4  
input   [5:0]           smlh_link_mode;               //1-x1, 2-x2, 4-x4, 8-x8, 16-x16
input                   cfg_gen3_scrambler_disable;   //1-fully disable gen3 scrambler
input                   cfg_gen3_dc_balance_disable;  //1-disable DC balance function
input   [(SB_WD*NL)-1:0] startblock;           //start block marker
input  [NL-1:0][2:0]     skp_os_align_sts  ;  // Indicates current sending Data have LFSR/Parity field of SKP OS
input                   ltssm_in_compliance; // LTSSM is in Polling.Compliance
input   ltssm_state_e   smlh_ltssm_state;
input                   cfg_precoding_enable;
input                   smlh_flit_mode_enable;
input    [NL-1:0]       lanes_active;
input  data_rate_enc_t  crnt_rate_enc;                 // current data rate shortcut.

output  [NL-1:0]        scramble_lfsr_rollover;    //lfsr matches the seed, used to insert EIEOS after a sequence of 65536 uninterrupted TS1s sent during equalization when the reset EIEOS count is set
output  [NL*SB_WD-1:0]  scramble_startblock;       //start block after scramble
output  [NL*SB_WD-1:0]  scramble_even_parity;      //even parity bit for scrambled data
output  [NL*SB_WD-1:0]  scramble_inskp;            //SKP indicator
output  [NL-1:0][2:0]   scramble_skp_os_align_sts; // Indicates current sending Data have LFSR/Parity field of SKP OS
output  [NL-1:0][SB_WD-1:0][4:0]   scramble_data_osfound;     // OS detection flag
output  [NL*SB_WD-1:0]  scramble_ints0;            //TS0 indicator
output  [NL*DCB_WD-1:0] scramble_dcb_det;          //DC balance symbol detect
output  [NL*SB_WD-1:0]  scramble_data_g6_skprm;    //SKP removed
output  [NL*SB_WD-1:0]  scramble_data_g6_skpadd;   //SKP added
output  [NL*SB_WD-1:0]  scramble_ints1;            //TS1 indicator
output  [NL*SB_WD-1:0]  scramble_ints2;            //TS2 indicator
output  [NL*SB_WD-1:0]  scramble_ineie;            //EIEOS indicator
output  [NL*SB_WD-1:0]  scramble_eie_det;          //EIEOS detected
output  [NL*SB_WD-1:0]  scramble_insds;            //SDS indicator
output  [NL-1:0]        scramble_data_dv;   // data bytes are valid
output  [NL-1:0]        scramble_aligned;   // data bytes are valid
output  [(NL*NB*8)-1:0] scramble_data;      // data bytes
output  [(NL*NB)-1:0]   scramble_data_comma; // comma character indication for each byte
output  [(NL*NB)-1:0]   scramble_data_skip; // skip character indication for each byte
output  [(NL*NB)-1:0]   scramble_data_skprm; // skp symbol removed aligned with the lower COM
output  [(NL*NBK)-1:0]  scramble_datak;     // K character indication for each byte
output  [(NL*NB)-1:0]   scramble_error;     // error indication for each byte
output  [NL-1:0]        wait4idle_nd;       // For PRBS loopback, n cycle delayed wait4idle

localparam TP     = `TP;
localparam NL_MAX = 16; // max possible value of NL
wire    [NL-1:0]         scramble_g3_data_dv;
wire    [NL-1:0]         scramble_g3_aligned;
wire    [NL*SB_WD-1:0]   scramble_skprm;
wire    [(NL*NB*8)-1:0]  scramble_g3_data;
wire    [(NL*NBK)-1:0]   scramble_g3_datak;
wire    [(NL*NB)-1:0]    scramble_g3_data_comma = 0;
wire    [(NL*NB)-1:0]    scramble_g3_data_skip = dup_vector(scramble_inskp); 
wire    [(NL*NB)-1:0]    scramble_g3_data_skprm = dup_vector(scramble_skprm); 
wire    [(NL*NB)-1:0]    scramble_g3_error;
wire    [(NL*3)-1:0]     lfsr_seed_sel;
wire    [(NL_MAX*3)-1:0] no_rev_seed_sel;
reg     [(NL_MAX*3)-1:0] rev_seed_sel;
wire    [NL*SB_WD-1:0]   scramble_even_parity;
wire    [NL-1:0]         scramble_g12_data_dv;
wire    [NL-1:0]         scramble_g12_aligned;
wire    [(NL*NB*8)-1:0]  scramble_g12_data;
wire    [(NL*NB)-1:0]    scramble_g12_data_comma;
wire    [(NL*NB)-1:0]    scramble_g12_data_skip;
wire    [(NL*NB)-1:0]    scramble_g12_data_skprm;
wire    [(NL*NBK)-1:0]   scramble_g12_datak;
wire    [(NL*NB)-1:0]    scramble_g12_error;

wire    [(NL*4)-1:0]     l0p_datastream_info_bus;  // {eios detection, advance 1 block, inital, data stream}
wire    [(NL*2)-1:0]     l0p_active_lfsr_info_bus; // {advance 8 block, advance 1 block}

assign { scramble_data_dv, scramble_aligned, scramble_datak, scramble_data, scramble_data_comma, scramble_data_skip, scramble_data_skprm, scramble_error} = 
 (current_data_rate >= `GEN3_RATE) ?                        
                            { scramble_g3_data_dv, scramble_g3_aligned, scramble_g3_datak, scramble_g3_data, scramble_g3_data_comma, scramble_g3_data_skip, scramble_g3_data_skprm, scramble_g3_error} :
                            { scramble_g12_data_dv, scramble_g12_aligned, scramble_g12_datak, scramble_g12_data, scramble_g12_data_comma, scramble_g12_data_skip, scramble_g12_data_skprm, scramble_g12_error};

// Generate Gen1/2 or Gen3/4 scrambler enable


reg     [NL-1:0]               g12_scramble_en;      // scramble enable when data rate is Gen1/2

reg      [NL-1:0]               g12_data_dv;            // data bytes are valid when data rate is Gen1/2
reg      [(NL*NB*8)-1:0] g12_data;             // data when data rate is Gen1/2
reg      [(NL*NBK)-1:0]    g12_datak;
wire                                current_g12_data_rate;         // 1:data rate is Gen1 or Gen2
wire                                current_g34_data_rate;         // 1:data rate is Gen3 or Gen4
reg     [NL-1:0]               g34_scramble_en;      // scramble enable when data rate is Gen3/4

reg     [NL-1:0]              g34_data_dv;            // input for scramble : data bytes are valid when 
reg     [(NL*NB*8)-1:0] g34_data;             // input for scramble : data when data rate is 
reg      [(NL*NBK)-1:0]   g34_datak;

assign current_g12_data_rate = (current_data_rate == `GEN1_RATE || current_data_rate == `GEN2_RATE);
assign current_g34_data_rate = (current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE || current_data_rate == `GEN6_RATE) ;
wire    ltssm_in_rcvryspeed;
assign  ltssm_in_rcvryspeed = (smlh_ltssm_state==S_RCVRY_SPEED);
wire    l0p_eieos_rcvd_ln0;
assign  l0p_eieos_rcvd_ln0 = l0p_datastream_info_bus[3];
wire                           current_g5_data_rate;         // 1:data rate is Gen5 or higher
wire                           precoding_enable;
assign current_g5_data_rate = ((current_data_rate == `GEN5_RATE) || (current_data_rate == `GEN6_RATE)) ;
assign precoding_enable =  current_g5_data_rate & cfg_precoding_enable;

integer                     lane_num;

// The txdatavalid signal is de-asserted before the txelecidle signal is asserted when exiting Loopback.Entry.
// The active lane signal is changed during last OS and the scrambler module is turned off. This logic is to avoid the issue.
wire   [NL-1:0] lanes_active_i = lanes_active | (~xmtbyte_txelecidle & {NL{RX_SIDE==0}});

always@* begin
        g12_scramble_en = {NL{current_g12_data_rate}} & lanes_active_i;
        g34_scramble_en = {NL{current_g34_data_rate}} & lanes_active_i;
        g12_data_dv = (current_g12_data_rate)? data_dv : 0;
        g12_data=(current_g12_data_rate)? data : 0;
        g12_datak=(current_g12_data_rate)? datak : 0;
        g34_data_dv = (current_g34_data_rate)?data_dv :0;
        g34_data=(current_g34_data_rate)? data : 0;
        g34_datak=(current_g34_data_rate)? datak : 0;
end

// up to here : Generate Gen1/2 or Gen3/4 scrambler enable

// gen1/gen2 scrambler
scramble_slv
 #(INST, RX_SIDE, REGOUT) u_scramble_slv[NL-1:0] (
// ---- inputs ---------------
    .core_rst_n                 (core_rst_n),
    .core_clk                   (core_clk),
    .scrambler_disable          (({NL{scrambler_disable}} | scrambler_disable_lanes_l0p)),
    .scramble_en                (g12_scramble_en),
    .data_dv                    (g12_data_dv[NL-1:0]),
    .data                       (g12_data[(NL*NB*8)-1:0]),
    .datak                      (g12_datak[(NL*NBK)-1:0]),
    .error                      (error[(NL*NB)-1:0]),
    .wait4idle                  (wait4idle[NL-1:0]),
    .skipremoved                (rxskipremoved[NL-1:0]),
    .active_nb                  (active_nb[3:0]),
    .aligned                    (aligned[NL-1:0]),
    .smlh_flit_mode_enable      (smlh_flit_mode_enable),

// ---- outputs ---------------
    .scramble_data_dv           (scramble_g12_data_dv[NL-1:0]),
    .scramble_aligned           (scramble_g12_aligned[NL-1:0]),
    .scramble_data              (scramble_g12_data[(NL*NB*8)-1:0]),
    .scramble_data_comma        (scramble_g12_data_comma[(NL*NB)-1:0]),
    .scramble_data_skip         (scramble_g12_data_skip[(NL*NB)-1:0]),
    .scramble_data_skprm        (scramble_g12_data_skprm[(NL*NB)-1:0]),
    .scramble_datak             (scramble_g12_datak[(NL*NBK)-1:0]),
    .scramble_error             (scramble_g12_error[(NL*NB)-1:0]),
    .wait4idle_nd               (wait4idle_nd[NL-1:0])
);

// gen3 scrambler
scramble3_slv
 #(.INST(INST), .RX_SIDE(RX_SIDE) , .REGIN(GEN3_REGIN), .REGOUT(GEN3_REGOUT), .CALC_PARITY_BEFORE_SCRAMBLE(CALC_PARITY_BEFORE_SCRAMBLE), .LFSR_REGOUT(GEN3_LFSR_REGOUT), .AW(AW) , .PRECODING_REGOUT(PRECODING_REGOUT) , .GLAYCODING_REGOUT(GLAYCODING_REGOUT)) u_scramble3_slv[NL-1:0] (
// ---- inputs ---------------
    .core_clk                   (core_clk),
    .core_rst_n                 (core_rst_n),
    .crnt_rate_enc              (crnt_rate_enc),
    .cfg_elastic_buffer_mode    (cfg_elastic_buffer_mode),
    .scrambler_disable          (cfg_gen3_scrambler_disable),
    .dc_balance_disable         (cfg_gen3_dc_balance_disable),
    .scramble_en                (g34_scramble_en),
    .data_dv                    (g34_data_dv[NL-1:0]),
    .data                       (g34_data[(NL*NB*8)-1:0]),
    .startblock                 (startblock[(NL*SB_WD)-1:0]),
    .skp_os_align_sts_logic     (skp_os_align_sts),
    .datak                      (g34_datak[(NL*NBK)-1:0]), // www: must be revisited for NB != 2
    .lfsr_sel                   (lfsr_seed_sel[(NL*3)-1:0]),
    .aligned                    (aligned[NL-1:0]), //gates: must revisit. direct from phy_mac_rxvalid
    .txelecidle                 (xmtbyte_txelecidle[NL-1:0]),
    .error                      (error[(NL*NB)-1:0]),
    .data_osfound               (data_osfound), 
    .skipremoved                (rxskipremoved[NL*SB_WD-1:0]),
    .active_nb_gen34            (active_nb_gen34),
    .ltssm_in_compliance        (ltssm_in_compliance),
    .current_data_rate          (current_data_rate),
    .ltssm_in_rcvryspeed        (ltssm_in_rcvryspeed),
    .precoding_enable           (precoding_enable),
    .gen6_compliance_sending    (gen6_compliance_sending),
    .smlh_flit_mode_enable      (smlh_flit_mode_enable),
    .l0p_eieos_rcvd_ln0         (l0p_eieos_rcvd_ln0),
    .l0p_active_lfsr_info       (l0p_active_lfsr_info_bus[NL*2-1:0]),

// ---- outputs ---------------
    .scramble_error             (scramble_g3_error[(NL*NB)-1:0]),
    .scramble_data_dv           (scramble_g3_data_dv[NL-1:0]),
    .scramble_data              (scramble_g3_data[(NL*NB*8)-1:0]),
    .scramble_startblock        (scramble_startblock[(NL*SB_WD)-1:0]),
    .scramble_datak             (scramble_g3_datak[(NL*NBK)-1:0]), // www: must be revisited for NB != 2
    .scramble_even_parity       (scramble_even_parity[NL*SB_WD-1:0]),
    .scramble_lfsr_rollover     (scramble_lfsr_rollover[NL-1:0]),
    .scramble_skprm             (scramble_skprm),
    .scramble_inskp             (scramble_inskp),
    .scramble_skp_os_align_sts  (scramble_skp_os_align_sts),
    .scramble_data_osfound      (scramble_data_osfound),
    .scramble_ints0             (scramble_ints0),
    .scramble_dcb_det           (scramble_dcb_det),
    .scramble_ints1             (scramble_ints1),
    .scramble_ints2             (scramble_ints2),
    .scramble_ineie             (scramble_ineie),
    .scramble_eie_det           (scramble_eie_det),
    .scramble_aligned           (scramble_g3_aligned),
    .scramble_insds             (scramble_insds)
    ,
    .l0p_datastream_info        (l0p_datastream_info_bus[NL*4-1:0])
);

  localparam N_DELAY_SKP_WIDTH = NL*SB_WD*2;
  localparam N_DELAY_SKP_CYCLE = (CALC_PARITY_BEFORE_SCRAMBLE==1) ? GEN3_REGIN + GEN3_REGOUT + PRECODING_REGOUT + GLAYCODING_REGOUT : // RMLH
                                                                    0; // XMLH
  delay_n_w_enable
  
  #(N_DELAY_SKP_CYCLE, N_DELAY_SKP_WIDTH, 0) u_skip_status_delay(
      .clk        (core_clk),
      .rst_n      (core_rst_n),
      .clear      (1'b0),
      .en         (current_data_rate == `GEN6_RATE),
      .din        ({rxskipremoved, rxskipadded}),
      .dout       ({scramble_data_g6_skprm, scramble_data_g6_skpadd})
  );
// LFSR on inactive lanes must be aligned with LFSR on active lanes.
reg     [9:0]            l0p_skp_interval;
reg     [9:0]            l0p_block_cnt;
reg     [1:0]            l0p_advance_en; //[1] advance 8block [0] advance 1 block

generate if (CALC_PARITY_BEFORE_SCRAMBLE==1) begin : gen_l0p_active_rmlh // RMLH
// SKP interval
    always @( * ) begin : l0p_skp_interval_PROC
        if(l0p_sris_mode_enabled) begin
            if(current_data_rate == `GEN6_RATE) begin //1b1b encoding
                case (smlh_l0p_link_mode[4:0])
                    5'b01000 : l0p_skp_interval = 74; // x8
                    5'b00100 : l0p_skp_interval = 72; // x4
                    5'b00010 : l0p_skp_interval = 72; // x2
                    default  : l0p_skp_interval = 64; // x1
                endcase
            end else begin //128b/130b encoding
                case (smlh_l0p_link_mode[4:0])
                    5'b01000 : l0p_skp_interval = 36; // x8
                    5'b00100 : l0p_skp_interval = 36; // x4
                    5'b00010 : l0p_skp_interval = 32; // x2
                    default  : l0p_skp_interval = 32; // x1
                endcase
            end
        end else
        begin
            if(current_data_rate == `GEN6_RATE) begin //1b1b encoding
                case (smlh_l0p_link_mode[4:0])
                    5'b01000 : l0p_skp_interval = 748; // x8
                    5'b00100 : l0p_skp_interval = 748; // x4
                    5'b00010 : l0p_skp_interval = 744; // x2
                    default  : l0p_skp_interval = 736; // x1
                endcase
            end else begin //128b/130b encoding
                case (smlh_l0p_link_mode[4:0])
                    5'b01000 : l0p_skp_interval = 374; // x8
                    5'b00100 : l0p_skp_interval = 372; // x4
                    5'b00010 : l0p_skp_interval = 368; // x2
                    default  : l0p_skp_interval = 368; // x1
                endcase
            end
        end
    end
// block counter for skp interval
    always @( posedge core_clk or negedge core_rst_n ) begin : l0p_block_cnt_PROC
        if ( ~core_rst_n ) begin
            l0p_block_cnt  <= #TP '0;
            l0p_advance_en <= #TP '0;
        end else if(l0p_datastream_info_bus[0]) begin // In data stream
            if(l0p_datastream_info_bus[1]) begin // Reset
                l0p_block_cnt  <= #TP '0;
                l0p_advance_en <= #TP '0;
            end else if(l0p_datastream_info_bus[2]) begin // Advance 1block
                l0p_block_cnt  <= #TP l0p_block_cnt + 1;
                if((l0p_block_cnt < 8-2) || (l0p_block_cnt > l0p_skp_interval-8-1)) begin // for lane skew when skpos is received
                    l0p_advance_en <= #TP 2'b00;
                end else if((l0p_block_cnt==8-2) || (l0p_block_cnt== l0p_skp_interval-8-1)) begin
                    l0p_advance_en <= #TP 2'b10;
                end else begin
                    l0p_advance_en <= #TP 2'b01;
                end
            end
        end else begin
            l0p_block_cnt  <= #TP '0;
            l0p_advance_en <= #TP '0;
        end
    end // l0p_block_cnt_PROC
    assign l0p_active_lfsr_info_bus = {{NL-1{(l0p_advance_en[1] && l0p_datastream_info_bus[2]),(l0p_advance_en[0] && l0p_datastream_info_bus[2])}}, 2'b00};
end else begin : gen_l0p_active_xmlh // XMLH
    assign l0p_active_lfsr_info_bus = {{NL-1{1'b0, (l0p_datastream_info_bus[2] && l0p_datastream_info_bus[0])}}, 2'b00};
end endgenerate

//get lfsr seed-lane number with no lane-reversed
assign no_rev_seed_sel = {3'h7,3'h6,3'h5,3'h4,3'h3,3'h2,3'h1,3'h0,3'h7,3'h6,3'h5,3'h4,3'h3,3'h2,3'h1,3'h0};

wire [NL*3-1:0] phy_lane_seed_sel;   // the flipped seed_sel on physical lane
reg  [NL*3-1:0] phy_lane_seed_sel_r; // the flipped seed_sel on physical lane
wire [NL*3-1:0] mac_lane_seed_sel;   // the flipped seed_sel on logical lane
// reverse/flip the seed_sel to physical lanes. so use Tx signals mux "lane_flip_mux #( 0, ..."
lane_flip_mux
 #( 0, NL, 3) u_lane_flip_mux_1 ( .flipped_data(phy_lane_seed_sel),   .lut(5'h0), .flip_ctrl(latched_flip_ctrl), .data(no_rev_seed_sel[NL*3-1:0]) );

always @( posedge core_clk or negedge core_rst_n ) begin : phy_lane_seed_sel_r_PROC
    if ( ~core_rst_n )
        phy_lane_seed_sel_r <= #TP '0;
    else
        phy_lane_seed_sel_r <= #TP phy_lane_seed_sel;
end // phy_lane_seed_sel_r_PROC

// then flip/reverse the physical lane's seed sel to logical lanes. So use Rx signals mux "lane_flip_mux #( 1, ..."
lane_flip_mux
 #( 1, NL, 3) u_lane_flip_mux_2 ( .flipped_data(mac_lane_seed_sel), .lut(5'h0), .flip_ctrl(smlh_lane_flip_ctrl), .data(phy_lane_seed_sel_r) );

//get lfsr seed-lane number with lane reversed
//no_rev_seed_sel is aligned to Logical Lane number which can change when the link width narrowed and lane flip/reversal
//cfg_no_seed_value_change        "lfsr_seed_sel description"
//          0                      = no_rev_seed_sel, seed value can change on the physical lane
//          1                      = mac_lane_seed_sel, seed value does not change on the physical lane even if the lane flip/reversal/broken and link width change/re-configuring
assign lfsr_seed_sel[(NL*3)-1:0] = cfg_no_seed_value_change && latched_smlh_link_up ? mac_lane_seed_sel : no_rev_seed_sel[(NL*3)-1:0];

// plagiarize from rmlh_pipe: duplicates the bits transforming [NL-1] into [NL*NB-1:0]
function automatic [NL*NB-1:0] dup_vector;
    input   [NL*SB_WD-1:0]    vector;

    integer ln, sym;
begin
    dup_vector = {NL*NB{1'b0}};
    for (ln=0; ln<NL; ln=ln+1)
        for (sym=0; sym<NB; sym=sym+1) begin
            dup_vector[ln*NB+sym] = vector[ln*SB_WD];
        end
end
endfunction



endmodule
