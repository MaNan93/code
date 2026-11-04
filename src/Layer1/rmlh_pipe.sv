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
// ---    $DateTime: 2024/01/12 11:11:14 $
// ---    $Revision: #20 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/rmlh_pipe.sv#20 $
// -------------------------------------------------------------------------
// --- Module Description: Receive MAC layer PIPE interface.
// -----------------------------------------------------------------------------

// LMD: 2 clocks in the module
// LJ: core_clk and core_clk_ug have to be introduced into the module
// leda W389 off
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"

 
 module rmlh_pipe
 import DWC_pcie_core_pkg::ltssm_state_e;
 import DWC_pcie_core_pkg::S_DETECT_QUIET;
 import DWC_pcie_core_pkg::S_DETECT_ACT;
 import DWC_pcie_core_pkg::S_POLL_ACTIVE;
 import DWC_pcie_core_pkg::S_POLL_COMPLIANCE;
 import DWC_pcie_core_pkg::S_POLL_CONFIG;
 import DWC_pcie_core_pkg::S_DETECT_WAIT;
 import DWC_pcie_core_pkg::S_CFG_LINKWD_START;
 import DWC_pcie_core_pkg::S_CFG_LINKWD_ACEPT;
 import DWC_pcie_core_pkg::S_CFG_LANENUM_WAIT;
 import DWC_pcie_core_pkg::S_CFG_LANENUM_ACEPT;
 import DWC_pcie_core_pkg::S_CFG_COMPLETE;
 import DWC_pcie_core_pkg::S_CFG_IDLE;
(
// ---- inputs ---------------
    pm_block_phystatus,
    core_rst_n,
    core_clk,
    core_clk_ug,
    cfg_elastic_buffer_mode,
    cfg_pipe_garbage_data_mode,

    smlh_ltssm_state,
    phy_mac_rxdata,
    phy_mac_rxdatak,
    phy_mac_rxvalid,
    phy_mac_rxdatavalid,
    phy_mac_rxstartblock,
    phy_mac_rxsyncheader,
    phy_mac_rxdata_osfound,
    deskew_ds_g6,
    phy_mac_rxstatus,
    phy_mac_rxelecidle,
    phy_mac_phystatus,
    phy_mac_margin_status,
    phy_mac_margin_nak,
    phy_mac_margin_error_cnt,
    phy_mac_margin_sampl_cnt,
    smlh_lanes_active,
    smlh_no_turnoff_lanes,
    smlh_link_up,
    ltssm_clear,
    ltssm_powerdown, // used for phy_mac_powerdown comparison
    mac_phy_rate,
    active_nb,
    cdm_ras_des_force_rxdetected_en,
    cdm_ras_des_force_rxdetected,
    pm_current_data_rate,
    pre_mac_phy_cclk_rate,

// ---- outputs ---------------
    current_powerdown,           // 0/1/2/3 = p0/p0s/p1/p2
    current_data_rate,           // 0/1/2 = running at gen1/2/3 speeds, goto PM block for shadowing the signal
    current_data_rate_others,    // pipeline to pm_current_data_rate
    current_data_rate_xmlh_xmt,  // pipeline to pm_current_data_rate
    current_data_rate_xmlh_scr,  // pipeline to pm_current_data_rate
    current_data_rate_rmlh_dsk,  // pipeline to pm_current_data_rate
    current_data_rate_rmlh_scr,  // pipeline to pm_current_data_rate
    current_data_rate_rmlh_pkf,  // pipeline to pm_current_data_rate
    current_data_rate_smlh_sqf,  // pipeline to pm_current_data_rate
    current_data_rate_smlh_lnk,  // pipeline to pm_current_data_rate
    current_data_rate_smlh_eq,   // pipeline to pm_current_data_rate
    current_data_rate_ltssm,     // pipeline to pm_current_data_rate
    current_cclk_rate,

    rpipe_rxdata,
    rpipe_rxdatak, // gen3: repurposed to rxsyncheader
    rpipe_rxdata_dv, // gen3: incorporates rxdatavalid
    rpipe_rxaligned,
    rpipe_rxstartblock,
    rpipe_gen3_rcvd_4eidle_set,
    act_rpipe_gen3_rcvd_4eidle_set,
    rpipe_out_rxdata_osfound,
    rpipe_all_sym_locked,
    rpipe_rxskipadded,   // unused
    rpipe_rxskipremoved, // unused
    rpipe_rxcodeerror,   // OR-ed at top level into rxerror
    rpipe_rxdisperror,   // OR-ed at top level into rxerror
    rpipe_rxunderflow,   // unused, routed to deskew block
    rpipe_rxoverflow,    // unused, routed to deskew block
    rpipe_rxelecidle,    // used by eidle_infer & ltssm
    rpipe_rcvd_eidle_set,// latched by ltssm and exported to pm_ctrl
    rpipe_eios_eieos_det, // eieos or eios detected
    act_rpipe_rcvd_eidle_set, // used by ltssm
    rpipe_rxdetected,    // used by ltssm
    rpipe_rxdetect_done, // used by ltssm
    rpipe_all_phystatus_asserted,// used by ltssm
    rpipe_all_phystatus_deasserted// used by ltssm
    ,
    rpipe_margin_status,
    rpipe_margin_nak,
    rpipe_margin_error_cnt,
    rpipe_margin_sampl_cnt
    ,
    latched_rxdetected,
    rmlh_rxvalid_deasserted
);
parameter   INST    = 0;        // The uniquifying parameter for each port logic instance.
parameter   REGOUT  = `CX_RMLH_PIPE_REGOUT;
parameter   NL      = `CX_NL;   // Max number of lanes supported
parameter   NB      = `CX_NB;   // Number of symbols (bytes) per clock cycle
parameter   NBK     = `CX_NBK;  // Number of symbols (bytes) per clock cycle for datak
parameter   AW      = `CX_ANB_WD; // Width of the active number of bytes
parameter   TP      = `TP;      // Clock to Q delay (simulator insurance)
parameter   RXSB_WD = `CX_MAC_SB_WD; //Width of phy_mac_rxstartblock per lane
parameter   RXSH_WD = `CX_MAC_SH_WD; //Width of phy_mac_rxsyncheader per lane
localparam  SYNC_DEPTH  = `CX_PCIE_SYNC_DEPTH;

input                   pm_block_phystatus; // block detection of phystatus when pm block is driving powerdown in PIPE4.3 mode
input                   core_rst_n;
input                   core_clk;
input                   core_clk_ug;                    // An ungated version of core_clk used to track phystatus during powerdown states
input                   cfg_elastic_buffer_mode;        // 0 - nominnal half full mode, 1 - nominal empty mode
input                   cfg_pipe_garbage_data_mode;     // 0 - until rxvalid=0 , 1 - until rxvalid=0 or rxstart=1 or COM symbol detection

input   ltssm_state_e   smlh_ltssm_state;

input   [(NL*NB*8)-1:0] phy_mac_rxdata;
input   [(NL*NB)-1:0]   phy_mac_rxdatak;
input   [NL-1:0]        phy_mac_rxvalid;
input   [NL-1:0]        phy_mac_rxdatavalid;
input   [NL*RXSB_WD-1:0] phy_mac_rxstartblock;
input   [NL*RXSH_WD-1:0] phy_mac_rxsyncheader;
input   [NL-1:0][RXSB_WD-1:0][4:0] phy_mac_rxdata_osfound;
input   [NL-1:0]        deskew_ds_g6;
input   [(NL*3) -1:0]   phy_mac_rxstatus;
input   [NL-1:0]        phy_mac_rxelecidle;
input   [NL-1:0]        phy_mac_phystatus;
input   [NL-1:0]        phy_mac_margin_status;
input   [NL-1:0]        phy_mac_margin_nak;
input   [(NL*6)-1:0]    phy_mac_margin_error_cnt;
input   [(NL*7)-1:0]    phy_mac_margin_sampl_cnt;
input   [NL-1:0]        smlh_lanes_active;
input   [NL-1:0]        smlh_no_turnoff_lanes;
input                   smlh_link_up;
input                   ltssm_clear;
input   [1:0]           ltssm_powerdown;        // From LTSSM indicating power down state (P0/P0s/P1).
input   [2:0]           mac_phy_rate;           // From LTSSM indicating data rate change
input   [AW-1:0]           active_nb;
input                   cdm_ras_des_force_rxdetected_en; // Force Detect Lane Num enable
input   [NL-1:0]        cdm_ras_des_force_rxdetected; // Force Detect Lane Num
input   [2:0]           pm_current_data_rate;   // Current_data_rate shadowed in pm_ctrl
input   [2:0]           pre_mac_phy_cclk_rate;

output  [1:0]           current_powerdown;            // 0/1/2/3 = p0/p0s/p1/p2
output  [2:0]           current_data_rate;            // 0/1/2 = running at gen1/2/3 speeds
output  [2:0]           current_data_rate_others;     // pipeline to pm_current_data_rate
output  [2:0]           current_data_rate_xmlh_xmt;   // pipeline to pm_current_data_rate
output  [2:0]           current_data_rate_xmlh_scr;   // pipeline to pm_current_data_rate
output  [2:0]           current_data_rate_rmlh_dsk;   // pipeline to pm_current_data_rate
output  [2:0]           current_data_rate_rmlh_scr;   // pipeline to pm_current_data_rate
output  [2:0]           current_data_rate_rmlh_pkf;   // pipeline to pm_current_data_rate
output  [2:0]           current_data_rate_smlh_sqf;   // pipeline to pm_current_data_rate
output  [2:0]           current_data_rate_smlh_lnk;   // pipeline to pm_current_data_rate
output  [2:0]           current_data_rate_smlh_eq;    // pipeline to pm_current_data_rate
output  [2:0]           current_data_rate_ltssm;      // pipeline to pm_current_data_rate
output  [2:0]              current_cclk_rate;

output  [(NL*NB*8)-1:0] rpipe_rxdata;
output  [(NL*NBK)-1:0]  rpipe_rxdatak;          //it is rxsyncheader if gen3 data rate
output  [NL-1:0]        rpipe_rxdata_dv;
output  [NL-1:0]        rpipe_rxaligned;        // squelched phy_mac_rxvalid 
output  [NL*RXSB_WD-1:0] rpipe_rxstartblock;
output                  rpipe_gen3_rcvd_4eidle_set;
output  [NL-1:0]        act_rpipe_gen3_rcvd_4eidle_set;
output  [NL-1:0][RXSB_WD-1:0][4:0]   rpipe_out_rxdata_osfound;
output                  rpipe_all_sym_locked;
output  [NL-1:0]        rpipe_rxskipadded;
output  [NL-1:0]        rpipe_rxskipremoved;
output  [NL-1:0]        rpipe_rxcodeerror;
output  [NL-1:0]        rpipe_rxdisperror;
output  [NL-1:0]        rpipe_rxunderflow;
output  [NL-1:0]        rpipe_rxoverflow;
output  [NL-1:0]        rpipe_rxelecidle;
output                  rpipe_rcvd_eidle_set;
output  [NL-1:0]        act_rpipe_rcvd_eidle_set;
output                  rpipe_eios_eieos_det;
output  [NL-1:0]        rpipe_rxdetected;
output                  rpipe_rxdetect_done;
output                  rpipe_all_phystatus_asserted;
output                  rpipe_all_phystatus_deasserted;
output  [NL-1:0]        rpipe_margin_status;
output  [NL-1:0]        rpipe_margin_nak;
output  [(NL*6)-1:0]    rpipe_margin_error_cnt;
output  [(NL*7)-1:0]    rpipe_margin_sampl_cnt;
output  [NL-1:0]        latched_rxdetected;
output  [NL-1:0]        rmlh_rxvalid_deasserted;

// When entering electrical idle, ignore data
wire    [NL-1:0]        lanes_on;
wire    [NL-1:0]        eios_eieos_det_i;
wire                    rpipe_eios_eieos_det;
wire    [NL-1:0]        squelch;
wire    [NL-1:0]        squelch_i;
wire    [NL-1:0]        set_squelch;
wire    [NL-1:0]        set_squelch_i;
wire    [NL-1:0]        squelch_act;
wire    [NL-1:0]        sq_rxvalid;
wire    [NL-1:0]        sq_rxdata_dv;
wire    [NL*NBK-1:0]    sq_rxdatak;
wire    [NL*NB-1:0]     int_rxdatak;
reg     [NL*NBK-1:0]    sq_rxsyncheader;
reg     [NL*NBK-1:0]    sq_int_rxdatak;
reg  [2:0]              current_data_rate;            //used in PM to shadow (hold) the value when main power is off
reg  [2:0]              current_cclk_rate;
reg  [2:0]              current_data_rate_others;     //used in layers other than layer1
reg  [2:0]              current_data_rate_xmlh_xmt;   //used in xmlh
reg  [2:0]              current_data_rate_xmlh_scr;   //used in xmlh
reg  [2:0]              current_data_rate_rmlh;       //used in rmlh
reg  [2:0]              current_data_rate_rmlh_dsk;   //used in rmlh
reg  [2:0]              current_data_rate_rmlh_scr;   //used in rmlh
reg  [2:0]              current_data_rate_rmlh_pkf;   //used in rmlh
reg  [2:0]              current_data_rate_smlh_sqf;   //used in smlh
reg  [2:0]              current_data_rate_smlh_lnk;   //used in smlh
reg  [2:0]              current_data_rate_smlh_eq ;   //used in smlh
reg  [2:0]              current_data_rate_ltssm;      //used in ltssm of smlh because ltssm has a lot of fan-outs
wire [(NL*NB*8)-1:0] rpipe_rxdata_o;
wire [(NL*NBK)-1:0]  rpipe_rxdatak_o;

reg  [1:0]              current_powerdown;

reg                     latched_smlh_link_up;

always @( posedge core_clk or negedge core_rst_n ) begin : latched_smlh_link_up_PROC
    if ( ~core_rst_n )
        latched_smlh_link_up <= #TP 0;
    else if ( smlh_ltssm_state == S_DETECT_QUIET )
        latched_smlh_link_up <= #TP 0;
    else if ( smlh_link_up )
        latched_smlh_link_up <= #TP 1;
end // latched_smlh_link_up_PROC

// smlh_no_turnoff_lanes is latched smlh_lanes_active when entry to linkup.
// So for ~linkup, use smlh_lanes_active
assign lanes_on = (smlh_link_up || latched_smlh_link_up) ? smlh_no_turnoff_lanes : smlh_lanes_active;

// Now create squelched version of the data
assign sq_rxvalid = ~squelch & phy_mac_rxvalid & ~({NL{current_powerdown[1]}});

assign sq_rxdata_dv = 
                       (cfg_elastic_buffer_mode ? phy_mac_rxdatavalid : phy_mac_rxdatavalid) &
                      sq_rxvalid;

assign sq_rxdatak = 
                    ((current_data_rate_rmlh == `GEN3_RATE || current_data_rate_rmlh == `GEN4_RATE || current_data_rate_rmlh == `GEN5_RATE || current_data_rate==`GEN6_RATE)) ? sq_rxsyncheader : //rxdatak used as rxsyncheader www: revisit for NB != 2
                    (dup_squelch(sq_rxvalid) & sq_int_rxdatak);

assign rpipe_eios_eieos_det = |(eios_eieos_det_i & smlh_lanes_active);

always @(*) begin : syncheader_to_datak_PROC
    integer i;
    sq_rxsyncheader  = 0;
    sq_int_rxdatak = 0;
    for (i=0; i<NL; i=i+1) begin
        sq_rxsyncheader[NBK*i +: 2] = phy_mac_rxstartblock[RXSB_WD*i] ? phy_mac_rxsyncheader[RXSH_WD*i +: 2] : 0;
        sq_int_rxdatak[NBK*i +: NB] = int_rxdatak[NB*i +: NB];
    end
end

// The non-registers
reg     [NL-1:0]        l_rxskipadded;
reg     [NL-1:0]        l_rxskipremoved;
reg     [NL-1:0]        l_rxdisperror;
reg     [NL-1:0]        l_rxcodeerror;
reg     [NL-1:0]        l_rxunderflow;
reg     [NL-1:0]        l_rxoverflow;
reg     [NL-1:0]        l_rxdetected;
reg                     rpipe_rcvd_eidle_set;
wire    [NL-1:0]        int_rpipe_rcvd_eidle_set;
wire    [NL-1:0]        int_rpipe_rcvd_eidle_set_i;
reg     [NL-1:0]        act_rpipe_rcvd_eidle_set;

wire    [NL-1:0]        rxelecidle_r;

// Output registering (optional)
parameter N_DELAY_CYLES = REGOUT ? 1 : 0;
parameter DATAPATH_WIDTH = $bits(rpipe_out_rxdata_osfound) + (NL*NB*8) + (NL*NBK) + 8*NL;
parameter RESET_VALUE = { { $bits(rpipe_out_rxdata_osfound) + (NL*NB*8) + (NL*NBK) + 7*NL{1'b0}}, {NL{1'b1}}} ; // Reset value of Rxelecidle=1, The others = 0
delay_n

#(N_DELAY_CYLES, DATAPATH_WIDTH, RESET_VALUE) u_delay(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ( {
 phy_mac_rxdata_osfound,
                    phy_mac_rxdata,sq_rxdatak,      sq_rxdata_dv,
                    l_rxskipadded, l_rxskipremoved, l_rxcodeerror,
                    l_rxoverflow,  l_rxunderflow,   l_rxdisperror, rxelecidle_r  }),
    .dout       ({
 rpipe_out_rxdata_osfound,
                    rpipe_rxdata_o,    rpipe_rxdatak_o,       rpipe_rxdata_dv,
                    rpipe_rxskipadded, rpipe_rxskipremoved, rpipe_rxcodeerror,
                    rpipe_rxoverflow,  rpipe_rxunderflow,   rpipe_rxdisperror, rpipe_rxelecidle })
);

delay_n

#(N_DELAY_CYLES, NL) u_delay_g_rxaligned(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({ sq_rxvalid }),
    .dout       ({ rpipe_rxaligned }) // rxaligned=0 is used to keep scrambler under reset
);

delay_n

#(N_DELAY_CYLES, (NL + NL*6 + NL*7)) u_delay_g4(
    .clk    (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({ phy_mac_margin_status, phy_mac_margin_error_cnt, phy_mac_margin_sampl_cnt}),
    .dout       ({ rpipe_margin_status, rpipe_margin_error_cnt, rpipe_margin_sampl_cnt}) 
);

delay_n

#(N_DELAY_CYLES, (NL)) u_delay_g4_nak(
    .clk    (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({ phy_mac_margin_nak }),
    .dout       ({ rpipe_margin_nak })
);

// Convert OSs to all correct data for 8s 
//  [0]:SKP-OS
//  [1]:SKP_END
//  [2]:EIOS
//  [3]:EIEOS
//  [4]:SDS
wire [(NL*5)-1:0]    phy_mac_rxdata_osfound_i;
reg  [(NL*5)-1:0]    rpipe_rxdata_osfound;
reg  [NL-1:0]        rpipe_rxdata_osfound_skpend_d0;
reg  [NL-1:0]        rpipe_rxdata_osfound_skpend_d1;
reg  [(NL*NB*8)-1:0] rpipe_rxdata_rep;
reg  [(NL*NBK)-1:0]  rpipe_rxdatak_rep;
reg  [8:0]           lane0_os_found_case;

assign phy_mac_rxdata_osfound_i = (RXSB_WD == 1) ? phy_mac_rxdata_osfound : '0 ;   // if RXSB_WD != 1, Data correction is excuted in freq_step. No correction is needed in this module.

always @(posedge core_clk or negedge core_rst_n)
begin : latch_os_found_PROC
    integer ln;
    if (!core_rst_n) begin
        rpipe_rxdata_osfound           <= #TP {NL{5'd0}};
        rpipe_rxdata_osfound_skpend_d1 <= #TP {NL{1'b0}};
    end else begin
        for (ln=0; ln<NL; ln=ln+1) begin
            rpipe_rxdata_osfound[ln*5 +: 5]     <= #TP (sq_rxdata_dv[ln]) ? phy_mac_rxdata_osfound_i[ln*5 +: 5] : rpipe_rxdata_osfound[ln*5 +: 5];
            rpipe_rxdata_osfound_skpend_d1[ln]  <= #TP (rpipe_rxdata_dv[ln]) ? rpipe_rxdata_osfound_skpend_d0[ln] : rpipe_rxdata_osfound_skpend_d1[ln];
        end
    end
end // latch_os_found_PROC

always @( * ) begin : g6_osfound_PROC
    integer ln;
    reg    [4:0]      lane_os_found_s0;
    reg    [4:0]      lane_os_found_s1;
    reg    [8:0]      lane_os_found_case;
    reg    [NB*8-1:0] lane_rxdata_rep;
    reg    [NBK-1:0]  lane_rxdatak_rep;
    rpipe_rxdata_rep = rpipe_rxdata_o;
    rpipe_rxdatak_rep = rpipe_rxdatak_o;
    rpipe_rxdata_osfound_skpend_d0 = 0;
    for (ln=0; ln<NL; ln=ln+1) begin
         // Set os found
         lane_os_found_s0 = phy_mac_rxdata_osfound_i[ln*5 +: 5];
         lane_os_found_s1 = rpipe_rxdata_osfound[ln*5 +: 5];
         rpipe_rxdata_osfound_skpend_d0[ln] = lane_os_found_s1[1];
         // Generate case
         lane_os_found_case[0] =  rpipe_rxstartblock[ln] & rpipe_rxdata_dv[ln] & lane_os_found_s0[0] & ~(|lane_os_found_s1); // fisrt skp os
         lane_os_found_case[1] =  rpipe_rxstartblock[ln] & rpipe_rxdata_dv[ln] & lane_os_found_s0[2] & ~(|lane_os_found_s1); // fisrt eios
         lane_os_found_case[2] =  rpipe_rxstartblock[ln] & rpipe_rxdata_dv[ln] & lane_os_found_s0[3] & ~(|lane_os_found_s1); // fisrt eieos
         lane_os_found_case[3] =  rpipe_rxstartblock[ln] & rpipe_rxdata_dv[ln] & lane_os_found_s0[4] & ~(|lane_os_found_s1); // fisrt sds os
         lane_os_found_case[4] =  lane_os_found_s1[0] & ~lane_os_found_s1[1] & ~rpipe_rxdata_osfound_skpend_d1[ln]; // second skp os
         lane_os_found_case[5] =  lane_os_found_s1[1]; // skp end
         lane_os_found_case[6] =  lane_os_found_s1[2]; // second eios
         lane_os_found_case[7] =  lane_os_found_s1[3]; // second eieos
         lane_os_found_case[8] =  lane_os_found_s1[4]; // second sdsos
         // Replace data
          casez(lane_os_found_case)
            9'b1????????,
            9'b000001??? : lane_rxdata_rep = {2{`GEN6_32B_SDS_SYM_0}}; // Byte0-7,8-15: sds-os
            9'b01??????? : lane_rxdata_rep = {`GEN6_32B_EIEOS_SYM_3, `GEN6_32B_EIEOS_SYM_2}; // Byte8-15: eie-os
            9'b0000001?? : lane_rxdata_rep = {`GEN6_32B_EIEOS_SYM_1, `GEN6_32B_EIEOS_SYM_0}; // Byte0-7: eie-os
            9'b001??????,
            9'b00000001? : lane_rxdata_rep = {2{`GEN6_32B_EIOS_SYM_0}}; // Byte0-7,8-15: ei-os
            9'b0001????? : lane_rxdata_rep = {2{`GEN6_32B_SKP_SYM_END}}; // ByteN-N+4: skp_end
            9'b00001????,
            9'b000000001 : lane_rxdata_rep = {2{`GEN6_32B_SKP_SYM_0}};  // Byte0-7: skp-os
            default      : lane_rxdata_rep = rpipe_rxdata_o[NB*8*ln +: NB*8];
          endcase
          casez(lane_os_found_case)
            9'b001??????,
            9'b00000001? : lane_rxdatak_rep = $bits(lane_rxdatak_rep)'(`SYNC_OS_BLOCK); // Byte0-7,8-15: ei-os
            default      : lane_rxdatak_rep = rpipe_rxdatak_o[NBK*ln +: NBK];
          endcase
          rpipe_rxdata_rep[NB*8*ln +: NB*8] = lane_rxdata_rep;
          rpipe_rxdatak_rep[NBK*ln +: NBK]  = lane_rxdatak_rep;
          if(ln==0) begin
              lane0_os_found_case = lane_os_found_case;
          end
    end //for
end //always
assign rpipe_rxdata = (current_data_rate==`GEN6_RATE) ? rpipe_rxdata_rep : rpipe_rxdata_o;
// To replace the Data syncheader with OS syncheader on EIOS  after 1b1b mod compliance pattern
assign rpipe_rxdatak = ((current_data_rate==`GEN6_RATE) && (smlh_ltssm_state == S_POLL_COMPLIANCE)) ? rpipe_rxdatak_rep : rpipe_rxdatak_o;


// registering for gen3 signals
// When the current_data_rate_rmlh transitions, the active timings of the sq_rxstartblock and sq_rxdatak(rxsyncheader) are differenet.
// For de-scrambler, the sq_rxstartblock should be aligned with the sq_rxdatak.
wire [NL*RXSB_WD-1:0] sq_rxstartblock; //rxstartblock is 0 during EIOS, powerdown(P1,P2), !rxvalid, !phystatus
assign sq_rxstartblock = ((current_data_rate_rmlh == `GEN3_RATE || current_data_rate_rmlh == `GEN4_RATE || current_data_rate_rmlh == `GEN5_RATE || current_data_rate==`GEN6_RATE)) ?  (dup_valid(sq_rxdata_dv) & phy_mac_rxstartblock) : {NL*RXSB_WD{1'b0}};

delay_n

#(N_DELAY_CYLES, NL*RXSB_WD) u_delay_g3(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({ sq_rxstartblock }), //rpipe_rxstartblock to 0 when phy_mac_rxvalid=0
    .dout       ({ rpipe_rxstartblock })
);

//4 eios rcvd at gen3 rate in loopback_active on any active lane
wire [NL-1:0] int_gen3_rcvd_4eidle_set;
wire rpipe_gen3_rcvd_4eidle_set;
reg rpipe_gen3_rcvd_4eidle_set_d;
reg  [NL-1:0] act_rpipe_gen3_rcvd_4eidle_set;

always @(posedge core_clk or negedge core_rst_n)
begin : latch_rpipe_gen3_rcvd_4eidle_set
  if (!core_rst_n)
    rpipe_gen3_rcvd_4eidle_set_d <= #TP '0;
  else
    rpipe_gen3_rcvd_4eidle_set_d <= #TP |(int_gen3_rcvd_4eidle_set & smlh_lanes_active);
end

assign rpipe_gen3_rcvd_4eidle_set = rpipe_gen3_rcvd_4eidle_set_d;

always @(posedge core_clk or negedge core_rst_n)
begin : latch_act_rpipe_gen3_rcvd_4eidle_set
  if (!core_rst_n)
    act_rpipe_gen3_rcvd_4eidle_set <= #TP 0;
  else
    act_rpipe_gen3_rcvd_4eidle_set <= #TP int_gen3_rcvd_4eidle_set & smlh_lanes_active;
end

wire   rpipe_all_sym_locked; //symbol locked on all active lanes
reg    rpipe_all_sym_locked_d;

always @(posedge core_clk or negedge core_rst_n)
begin : latch_all_sym_locked
  if (!core_rst_n)
    rpipe_all_sym_locked_d <= #TP '0;
  else
    rpipe_all_sym_locked_d <= #TP &((phy_mac_rxvalid & smlh_lanes_active) | ~smlh_lanes_active);
end

assign rpipe_all_sym_locked = rpipe_all_sym_locked_d;

// if the squelch module is defined, then it will synchronize phy_mac_rxelecidle.
assign  rxelecidle_r = phy_mac_rxelecidle;

reg     [NL-1:0]    rpipe_rxdetected;
reg                 rpipe_rxdetect_done;
always @(posedge core_clk or negedge core_rst_n)
begin : latch_detection_results
    integer ln;

    if (!core_rst_n) begin
        rpipe_rxdetected        <= #TP {NL{1'b0}};
    end else if (ltssm_clear) begin
        rpipe_rxdetected        <= #TP {NL{1'b0}};
    end else begin
        for (ln=0; ln<NL; ln=ln+1) begin
            if(cdm_ras_des_force_rxdetected_en) begin
                rpipe_rxdetected[ln]    <= #TP (cdm_ras_des_force_rxdetected[ln] & smlh_lanes_active[ln]) ;
            end else begin
            if (phy_mac_phystatus[ln]) begin
                rpipe_rxdetected[ln]    <= #TP l_rxdetected[ln];
            end
            end
        end
    end
end // latch_detection_results


always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        rpipe_rxdetect_done     <= #TP 1'b0;
    end else if (ltssm_clear) begin
        rpipe_rxdetect_done     <= #TP 1'b0;
    end else if(cdm_ras_des_force_rxdetected_en) begin
        if( smlh_ltssm_state==S_DETECT_ACT ) 
            rpipe_rxdetect_done     <= #TP |(cdm_ras_des_force_rxdetected & smlh_lanes_active);
    end else begin
        rpipe_rxdetect_done     <= #TP rpipe_all_phystatus_asserted;
    end

reg [NL-1:0]    rpipe_phystatus_asserted;
always @(posedge core_clk_ug or negedge core_rst_n)
begin : collect_phystatus_assertions
    integer ln;

    if (!core_rst_n) begin
        rpipe_phystatus_asserted                <= #TP {NL{1'b1}};
    end else if (ltssm_clear) begin
        rpipe_phystatus_asserted                <= #TP {NL{1'b0}};
    end else begin
        for (ln=0; ln<NL; ln=ln+1)
            if (phy_mac_phystatus[ln])
                rpipe_phystatus_asserted[ln]    <= #TP 1'b1;
    end
end // collect_phystatus_assertions

reg                     rpipe_all_phystatus_deasserted;
reg                     rpipe_all_phystatus_asserted;
always @(posedge core_clk_ug or negedge core_rst_n)
    if (!core_rst_n) begin
        rpipe_all_phystatus_asserted        <= #TP 1'b1;
        rpipe_all_phystatus_deasserted      <= #TP 1'b0;
    end else begin
        rpipe_all_phystatus_asserted        <= #TP &((lanes_on &  rpipe_phystatus_asserted) | ~lanes_on);
        rpipe_all_phystatus_deasserted      <= #TP &((lanes_on & ~phy_mac_phystatus) | ~lanes_on);
    end

reg [NL-1:0]    latched_rxdetected ;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        latched_rxdetected <= #TP 1'b0;
    end else begin
        if( smlh_ltssm_state==S_DETECT_ACT ) 
            latched_rxdetected <= #TP rpipe_rxdetected;
    end

reg  [NL*2-1:0] phy_mac_powerdown;
reg  [NL*3-1:0] phy_mac_rate;
reg  [NL-1:0]   phy_mac_powerdown_ready_bus;
reg  [NL-1:0]   phy_mac_rate_ready_bus;
wire            all_phy_mac_powerdown_ready;
wire            all_phy_mac_rate_ready;
reg             all_phy_mac_powerdown_ready_r;
reg             all_phy_mac_rate_ready_r;
wire            all_phy_mac_powerdown_ready_pulse;
wire            all_phy_mac_rate_ready_pulse;

always @(posedge core_clk_ug or negedge core_rst_n) begin : phy_mac_powerdown_rate_seq_PROC
    integer j;
    if ( ~core_rst_n ) begin
        phy_mac_powerdown             <= #TP {NL{`P1}};
        phy_mac_rate                  <= #TP 0;
        all_phy_mac_powerdown_ready_r <= #TP 0;
        all_phy_mac_rate_ready_r      <= #TP 0;
    end else begin
        // To update phy powerdown/datarate signal
        //   If phystatus signal is asserted, the signal on active lane is updated.
        //   If all ACTIVE Lanes' powerdown/datarate changes are done by PHY, the signal on all lanes including turn off lanes are updated.
        for ( j=0; j<NL; j=j+1 ) begin
            if ( phy_mac_phystatus[j] || all_phy_mac_rate_ready_pulse) begin
                phy_mac_rate[j*3 +: 3]      <= #TP mac_phy_rate;
            end
            // Set the powerdown to P1
            if ( pm_block_phystatus) begin
                phy_mac_powerdown[j*2 +: 2] <= #TP `P1;
            end else
            if ( phy_mac_phystatus[j] || all_phy_mac_powerdown_ready_pulse) begin
                phy_mac_powerdown[j*2 +: 2] <= #TP ltssm_powerdown;
            end
        end //for
        all_phy_mac_powerdown_ready_r <= #TP all_phy_mac_powerdown_ready;
        all_phy_mac_rate_ready_r      <= #TP all_phy_mac_rate_ready;
    end
end //always

always @( * ) begin : phy_mac_powerdown_rate_PROC
    integer j;
    phy_mac_powerdown_ready_bus = {NL{1'b1}};
    phy_mac_rate_ready_bus      = {NL{1'b1}};

    for ( j=0; j<NL; j=j+1 ) begin
    //if PHY acknowledged on a Lane, the Lane's powerdown/datarate change was done
        phy_mac_powerdown_ready_bus[j] = ( phy_mac_powerdown[j*2 +: 2] == ltssm_powerdown );
        phy_mac_rate_ready_bus[j]      = ( phy_mac_rate[j*3 +: 3] == mac_phy_rate );
    end //for
end //always

//when all ACTIVE Lanes' powerdown/datarate changes are done by PHY, phystatus_wait_done = 1
//powerdown and datarate changes are exclusive
assign all_phy_mac_powerdown_ready = &(phy_mac_powerdown_ready_bus | ~lanes_on);
assign all_phy_mac_rate_ready      = &(phy_mac_rate_ready_bus | ~lanes_on);
assign all_phy_mac_powerdown_ready_pulse = all_phy_mac_powerdown_ready & ~all_phy_mac_powerdown_ready_r;
assign all_phy_mac_rate_ready_pulse      = all_phy_mac_rate_ready      & ~all_phy_mac_rate_ready_r;

always @(posedge core_clk_ug or negedge core_rst_n) begin : current_powerdown_PROC
    if ( ~core_rst_n ) begin
        current_powerdown <= #TP `P1;
    end else if ( all_phy_mac_powerdown_ready ) begin
    //sync to requested powerdown to get current powerdown after all ACTIVE Lanes phystatus back
        current_powerdown <= #TP ltssm_powerdown;
    end
end //always

// current_data_rate goto PM for shadowing the value when the main power is off
always @(posedge core_clk_ug or negedge core_rst_n) begin : current_data_rate_PROC
    if ( ~core_rst_n ) begin
        current_data_rate <= #TP 0;
        current_cclk_rate <= #TP 3'h0;
    end 
    else if ( all_phy_mac_rate_ready ) begin
    //sync to requested datarate to get current data rate after all ACTIVE Lanes phystatus back
        current_data_rate <= #TP mac_phy_rate;
        current_cclk_rate <= #TP pre_mac_phy_cclk_rate;
    end
end //always


// branch pm_current_data_rate to resolve synthesis timing closure issue because of massive fan-outs
// using core_clk is ok because current_data_rate (using core_clk_ug) catches phystatus when core_clk is off
ltssm_state_e    smlh_ltssm_state_d;
always @( posedge core_clk or negedge core_rst_n ) begin : smlh_ltssm_state_d_PROC
    if ( ~core_rst_n )
        smlh_ltssm_state_d <= #TP S_DETECT_QUIET;
    else
        smlh_ltssm_state_d <= #TP smlh_ltssm_state;
end // smlh_ltssm_state_d_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : branch_pm_current_data_rate_PROC
    if ( ~core_rst_n ) begin
        current_data_rate_others     <= #TP 0;
        current_data_rate_xmlh_xmt   <= #TP 0;
        current_data_rate_xmlh_scr   <= #TP 0;
        current_data_rate_rmlh       <= #TP 0;
        current_data_rate_rmlh_dsk   <= #TP 0;
        current_data_rate_rmlh_scr   <= #TP 0;
        current_data_rate_rmlh_pkf   <= #TP 0;
        current_data_rate_smlh_sqf   <= #TP 0;
        current_data_rate_smlh_lnk   <= #TP 0;
        current_data_rate_smlh_eq    <= #TP 0;
        current_data_rate_ltssm      <= #TP 0;
    end else begin
        // add smlh_ltssm_state_d for avoiding signal merging in synthesis
        // use smlh_ltssm_state_d for avoiding smlh_ltssm_state big fan-out.
        // It is ok for smlh_ltssm_state to delay one cycle here
        // It is safe because when smlh_ltssm_state_d is in these LTSSM states, no data rate change
        current_data_rate_others     <= #TP smlh_ltssm_state_d == S_DETECT_QUIET      ? current_data_rate_others   : pm_current_data_rate;
        current_data_rate_xmlh_xmt   <= #TP smlh_ltssm_state_d == S_DETECT_ACT        ? current_data_rate_xmlh_xmt : pm_current_data_rate;
        current_data_rate_xmlh_scr   <= #TP smlh_ltssm_state_d == S_DETECT_WAIT       ? current_data_rate_xmlh_scr : pm_current_data_rate;
        current_data_rate_rmlh       <= #TP smlh_ltssm_state_d == S_POLL_ACTIVE       ? current_data_rate_rmlh     : pm_current_data_rate;
        current_data_rate_rmlh_dsk   <= #TP smlh_ltssm_state_d == S_POLL_CONFIG       ? current_data_rate_rmlh_dsk : pm_current_data_rate;
        current_data_rate_rmlh_scr   <= #TP smlh_ltssm_state_d == S_CFG_LINKWD_START  ? current_data_rate_rmlh_scr : pm_current_data_rate;
        current_data_rate_rmlh_pkf   <= #TP smlh_ltssm_state_d == S_CFG_LINKWD_ACEPT  ? current_data_rate_rmlh_pkf : pm_current_data_rate;
        current_data_rate_smlh_sqf   <= #TP smlh_ltssm_state_d == S_CFG_LANENUM_WAIT  ? current_data_rate_smlh_sqf : pm_current_data_rate;
        current_data_rate_smlh_lnk   <= #TP smlh_ltssm_state_d == S_CFG_LANENUM_ACEPT ? current_data_rate_smlh_lnk : pm_current_data_rate;
        current_data_rate_smlh_eq    <= #TP smlh_ltssm_state_d == S_CFG_COMPLETE      ? current_data_rate_smlh_eq  : pm_current_data_rate;
        current_data_rate_ltssm      <= #TP smlh_ltssm_state_d == S_CFG_IDLE          ? current_data_rate_ltssm    : pm_current_data_rate;
    end
end // branch_pm_current_data_rate_PROC

reg [NL*NB-1:0] edb_i;
always @* begin: detect_edb_PROC // detect EDB on a symbol
    integer nl, nb; //lane#, byte#
    edb_i = 0;
    for ( nl=0; nl<NL; nl=nl+1 ) begin
        for ( nb=0; nb<NB; nb=nb+1 ) begin
            edb_i[nl*NB+nb] = (phy_mac_rxdata[(nl*NB*8 + nb*8) +: 8] == 8'hFE & phy_mac_rxdatak[(nl*NB*1 + nb*1) +: 1] & phy_mac_rxvalid[nl] & phy_mac_rxdatavalid[nl] & smlh_lanes_active[nl] & nb < active_nb);
        end
    end
end // detect_edb_PROC

reg [NL-1:0] edb; // detect EDB on a lane
always @* begin : edb_PROC
integer nl; //lane#

    edb = 0;
    for ( nl=0; nl<NL; nl=nl+1 ) begin
        edb[nl] = |edb_i[nl*NB +: NB];

        if ( current_data_rate_rmlh >= `GEN3_RATE ) // decode_err EDB check is only for Gen1/2 rate
            edb[nl] = 1'b1;
    end
end // edb_PROC

reg [2:0] val;
assign squelch_act = squelch | set_squelch;

always @(*)
begin: decode_status

integer ln;

    for ( ln=0; ln<NL; ln=ln+1 ) begin
        val[0] = phy_mac_rxstatus[ln*3];
        val[1] = phy_mac_rxstatus[ln*3+1];
        val[2] = phy_mac_rxstatus[ln*3+2];

        l_rxskipadded[ln]       = (val == 3'b001) ;
        l_rxskipremoved[ln]     = (val == 3'b010) ;
        l_rxdetected[ln]        = (val == 3'b011) ;

        // Mask these errors during electrical idle
        l_rxoverflow[ln]        = (val == 3'b101) & (!squelch_act[ln] & phy_mac_rxvalid[ln] & (cfg_elastic_buffer_mode ? phy_mac_rxdatavalid[ln] : phy_mac_rxdatavalid[ln])) ;
        l_rxunderflow[ln]       = (val == 3'b110) & (!squelch_act[ln] & phy_mac_rxvalid[ln] & (cfg_elastic_buffer_mode ? phy_mac_rxdatavalid[ln] : phy_mac_rxdatavalid[ln])) ;
        l_rxcodeerror[ln]       = (val == 3'b100) & (!squelch_act[ln] & phy_mac_rxvalid[ln] & (cfg_elastic_buffer_mode ? phy_mac_rxdatavalid[ln] : phy_mac_rxdatavalid[ln])) & edb[ln]; //PIPE: decode_err = EDB & RxStatus=100b
        l_rxdisperror[ln]       = (val == 3'b111) & (!squelch_act[ln] & phy_mac_rxvalid[ln] & (cfg_elastic_buffer_mode ? phy_mac_rxdatavalid[ln] : phy_mac_rxdatavalid[ln])) ;

        // Ignore electrical idle while data is valid
        // l_rxelecidle[ln]        = (rxelecidle_r[ln] & (!rpipe_rxvalid[ln]));
    end // For each lane

end // Always

// This function duplicates the squelch bit on a per-symbol basis
function automatic [NL*NBK-1:0] dup_squelch;
    input   [NL-1:0]    squelch;        // squelch control - per lane

    integer ln, sym;
begin
    dup_squelch = {NL*NBK{1'b0}};
    for (ln=0; ln<NL; ln=ln+1)
        for (sym=0; sym<NBK; sym=sym+1)
            dup_squelch[ln*NBK+sym] = squelch[ln];
end
endfunction

function automatic [NL*RXSB_WD-1:0] dup_valid;
    input   [NL-1:0]    valid;        // valid control - per lane

    integer ln, sym;
begin
    dup_valid = {NL*RXSB_WD{1'b0}};
    for (ln=0; ln<NL; ln=ln+1)
        for (sym=0; sym<RXSB_WD; sym=sym+1)
            dup_valid[ln*RXSB_WD+sym] = valid[ln];
end
endfunction


// bring act_rpipe_rcvd_eidle_set to LTSSM for any lane receiving eidle set
always @(posedge core_clk or negedge core_rst_n)
  if (~core_rst_n)
      act_rpipe_rcvd_eidle_set <= #TP 1'b0;
  else
      act_rpipe_rcvd_eidle_set <= #TP int_rpipe_rcvd_eidle_set & smlh_lanes_active;

// for the lanes that are active, we will detect the earlest eidleOS receving
always @(posedge core_clk or negedge core_rst_n)
  if (~core_rst_n)
      rpipe_rcvd_eidle_set <= #TP 1'b0;
  else
      rpipe_rcvd_eidle_set <= #TP |(int_rpipe_rcvd_eidle_set & smlh_lanes_active);

// Array of instances, implies new synthax in tb code for forcing internal wires, for example:
// force u_squelch[1].core_clk = 1;
rmlh_pipe_squelch
 u_squelch[NL-1:0]
(
// ---------- Inputs --------
  .core_clk                 (core_clk),
  .core_clk_ug              (core_clk_ug),
  .core_rst_n               (core_rst_n),
  .cfg_elastic_buffer_mode  (cfg_elastic_buffer_mode),
  .cfg_pipe_garbage_data_mode (cfg_pipe_garbage_data_mode),
  .rxvalid                  (phy_mac_rxvalid),
  .rxdata                   (phy_mac_rxdata),
  .rxdatak                  (phy_mac_rxdatak),
  .active_nb                (active_nb),
  .disable_squelch_turnoff  (1'b0),
  .current_data_rate        (current_data_rate_rmlh),
  .smlh_ltssm_state         (smlh_ltssm_state),
  .rxdatavalid              (phy_mac_rxdatavalid),
  .mac_phy_rate             (mac_phy_rate),
  .deskew_ds_g6             (deskew_ds_g6),
  .rxstartblock             (phy_mac_rxstartblock & dup_valid(phy_mac_rxdatavalid) & dup_valid(phy_mac_rxvalid)),
  .rxsyncheader             (phy_mac_rxsyncheader), //no mask to 0 for ~rxstartblock b/c with rxstartblock in rmlh_pipe_squelch
  .rxosfound                (phy_mac_rxdata_osfound),

// ---------- Outputs --------
  .int_gen3_rcvd_4eidle_set (int_gen3_rcvd_4eidle_set),
  .sq_rxdatak               (int_rxdatak),
  .int_rpipe_rcvd_eidle_set (int_rpipe_rcvd_eidle_set_i),
  .set_squelch              (set_squelch_i),
  .eios_eieos_det           (eios_eieos_det_i),
  .squelch                  (squelch_i)
  ,
  .rmlh_rxvalid_deasserted  (rmlh_rxvalid_deasserted)
);

assign int_rpipe_rcvd_eidle_set = int_rpipe_rcvd_eidle_set_i;
assign set_squelch              = set_squelch_i;
assign squelch                  = squelch_i;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// System Verilog Assertions.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


endmodule
// leda W389 on
