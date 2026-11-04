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
// ---    $DateTime: 2023/09/27 02:27:25 $
// ---    $Revision: #12 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/xmlh_pipe.sv#12 $
// -------------------------------------------------------------------------
// --- Module Description: Transmit MAC layer PIPE interface.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer1/xmlh_pkg.svh"


 module xmlh_pipe
  import xmlh_pkg::OSFLG_WD;
 (
    core_clk,
    core_rst_n,
    current_data_rate,
    cfg_link_capable,

    txdata,
    txdatak,
    txdata_dv,
    txstartblock,
    txdata_osfound,
    txerror,
    txdetectrx_loopback,
    txelecidle,
    tx_g5_lpbk_deassert,
    txcompliance,
    margin_cmd,
    margin_offset,
    margin_clr_error_log,
    ltssm_lpbk_slave_lut,
    ltssm_in_lpbk_exit_timeout,
    ltssm_in_lpbk,
    ltssm_powerdown,

    phy_mac_phystatus,

    xpipe_txdata,
    xpipe_txdatak,
    xpipe_txdatavalid,
    xpipe_txstartblock,
    xpipe_txsyncheader,
    xpipe_txdetectrx_loopback,
    xpipe_txelecidle,
    xpipe_txcompliance,
    xpipe_margin_cmd,
    xpipe_margin_offset,
    xpipe_margin_clr_error_log,
    xpipe_txdata_osfound,
    xpipe_powerdown,

    xpipe_phystatus
);
parameter   INST    = 0;        // The uniquifying parameter for each port logic instance. Should be 1st parameter.
parameter   REGOUT  = `CX_XMLH_PIPE_REGOUT; // Optional output registration
parameter   NL      = `CX_NL;   // Max number of lanes supported
parameter   NB      = `CX_NB;   // Number of symbols (bytes) per clock cycle
parameter   NBK     = `CX_NBK;  // Number of symbols (bytes) per clock cycle for datak
parameter   TP      = `TP;      // Clock to Q delay (simulator insurance)
parameter   SB_WD   = `CX_PHY_TXSB_WD; // Number of bits of per txstartblock
parameter   SH_WD   = `CX_PHY_TXSH_WD; // Number of bits of per txsyncheader

input                   core_rst_n;
input                   core_clk;
input   [2:0]           current_data_rate;  // 2'b00=running at gen1 speeds, 2'b01=running at gen2 speeds, 2'b10=running at gen3 speeds, 2'b11=running at gen4 speeds
input   [5:0]           cfg_link_capable;   // It is application specific. It needs to be decided by application at implementation
                                            // time. It indicates the x1, x2, x4 capability of a port. This is an output of
                                            // PCIE spec. required config register.

// From transmit MAC
input   [(NL*NB*8)-1:0] txdata;             // 2 bytes parallel transmit data
input   [(NL*NBK)-1:0]  txdatak;            // Indicates K characters
input   [NL-1:0]        txdata_dv;          // Data Valid, Instruct the PHY to ignore bytes on the data interface
input   [(NL*SB_WD)-1:0] txstartblock;       // Indicates the starting symbol for a 130b block
input   [NL-1:0][SB_WD-1:0][OSFLG_WD-1:0] txdata_osfound;  // Sending OS Flag
input   [(NL*NB)-1:0]   txerror;            // Indicates Error generation
input                   txdetectrx_loopback;// Enable receiver detect (loopback)
input   [NL-1:0]        txelecidle;         // Enable Transmitter Electical Idle
input                   tx_g5_lpbk_deassert;// deassert loopback signal in LPBK_EXIT_TIMEOUT at gen5 rate
input   [NL-1:0]        txcompliance;       // Set negative running disparity (for compliance pattern)
input   [(NL*3)-1:0]    margin_cmd;
input   [(NL*7)-1:0]    margin_offset;
input   [(NL*2)-1:0]    margin_clr_error_log;
input   [NL-1:0]        ltssm_lpbk_slave_lut; // lane under test for lpbk slave
input                   ltssm_in_lpbk_exit_timeout;
input                   ltssm_in_lpbk;      // lpbk_active || (lpbk_exit & lpbk_slave)
input   [1:0]           ltssm_powerdown;    // Ltssm powerdown (based on LTSSM state)

// From PIPE phy
input   [NL-1:0]        phy_mac_phystatus;
// To PIPE phy
output  [(NL*NB*8)-1:0] xpipe_txdata;
output  [(NL*NB)-1:0]   xpipe_txdatak;
output  [NL-1:0]        xpipe_txdatavalid;
output  [(NL*SB_WD)-1:0] xpipe_txstartblock;
output  [(NL*SH_WD)-1:0] xpipe_txsyncheader;
output  [NL-1:0]        xpipe_txdetectrx_loopback;
output  [NL-1:0]        xpipe_txelecidle;
output  [NL-1:0]        xpipe_txcompliance;
output  [(NL*3)-1:0]    xpipe_margin_cmd;
output  [(NL*7)-1:0]    xpipe_margin_offset;
output  [(NL*2)-1:0]    xpipe_margin_clr_error_log;
output  [NL-1:0][SB_WD-1:0][OSFLG_WD-1:0] xpipe_txdata_osfound ;
output  [1:0]           xpipe_powerdown;    // 2 bit power state P0/P0s/P1/P2

//
output  [NL-1:0]        xpipe_phystatus;

// Output registering (optional)
wire    [NL-1:0]        xpipe_txdetectrx_loopback;

reg     [(NL*SH_WD)-1:0] txsyncheader;

always @(*) begin : extract_synchdr_PROC
    integer i;
    if (!((current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE || current_data_rate == `GEN6_RATE)))
        txsyncheader = {(SH_WD*NL){1'b0}};
    else begin
        for(i=0; i<NL; i=i+1)
            txsyncheader[SH_WD*i +: SH_WD] = txdatak[NBK*i +: SH_WD];
    end
end

// Extract txdatak
reg     [(NL*NB)-1:0]  int_txdatak;
assign int_txdatak = txdatak;

parameter N_DELAY_CYLES     = REGOUT ? 1 : 0;
parameter DATAPATH_WIDTH    = (NL*NB*8)               // data
                            + (NL*NB)                 // datak
                            + NL                      // compliance
                            + (NL*3)                  // margin_cmd
                            + (NL*7)                  // margin_offset
                            + (NL*2)                  // margin_clr_error_log
                            + NL                      // dataskip
                            + (NL*SB_WD)              // startblock
                            + (NL*SH_WD)              // syncheader
                            + $bits( txdata_osfound ) // txdata_osfound
                            + NL                      // mac_phystatus
                            + NL                      // detectrx_loopback
                            + NL                      // txelecidle
                            + 2;                      // powerdown

// We need to clear this signal quickly
reg             txdetectrx_loopback_d;
reg [NL-1:0]    int_xpipe_txdetectrx_loopback;
wire [1:0]      xpipe_powerdown;
wire [1:0]      int_xpipe_powerdown;
wire [NL-1:0]   ltssm_lpbk_slave_lut_i = |ltssm_lpbk_slave_lut ? ltssm_lpbk_slave_lut : {NL{1'b1}}; // only one lane active in ltssm_lpbk_slave_lut if effect

//         NDEL,          WD,            RESET_VAL                     phystatus, txeidle, powerdown
delay_n

#(N_DELAY_CYLES, DATAPATH_WIDTH,  {{DATAPATH_WIDTH-(NL+NL+3){1'b0}}, 1'b1, {NL{1'b0}}, {NL{1'b1}}, 2'b10}) u0_delay(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({  txdata,    int_txdatak, txcompliance,
                    margin_cmd,
                    margin_offset,
                    margin_clr_error_log,
                    txdata_dv, txstartblock, txsyncheader, txdata_osfound ,
                    phy_mac_phystatus, (int_xpipe_txdetectrx_loopback & ltssm_lpbk_slave_lut_i), txelecidle, ltssm_powerdown }), // ltssm_lpbk_slave_lut to get the lane under test for gen5 lpbk.active slave
    .dout       ({  xpipe_txdata,      xpipe_txdatak,  xpipe_txcompliance,
                    xpipe_margin_cmd,
                    xpipe_margin_offset,
                    xpipe_margin_clr_error_log,
                    xpipe_txdatavalid, xpipe_txstartblock, xpipe_txsyncheader, xpipe_txdata_osfound ,
                    xpipe_phystatus, xpipe_txdetectrx_loopback, xpipe_txelecidle, int_xpipe_powerdown})
);

// delay powerdown by one cycle to align with the extra cycle the GEN3/4 scrambler takes
// delay powerdown by one more extra cycle to align with the extra cycle the GEN3/4 byte_transmitter (xmlh_byte_xmt) takes for CX_NB = 8
reg  [1:0] int_xpipe_powerdown_d;
reg  [1:0] int_xpipe_powerdown_dd;
always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
      int_xpipe_powerdown_d <= #TP `P1;
      int_xpipe_powerdown_dd <= #TP `P1;
    end else begin
      int_xpipe_powerdown_d <= #TP int_xpipe_powerdown;
      int_xpipe_powerdown_dd <= #TP int_xpipe_powerdown_d;
    end
end
assign xpipe_powerdown = (current_data_rate >= `GEN3_RATE) ? ((NB >= 8) ? int_xpipe_powerdown_dd : int_xpipe_powerdown_d) : int_xpipe_powerdown;

wire [NL-1:0] lane_en;
assign lane_en[0] = 1'b1;
assign lane_en[1] = cfg_link_capable[1];
assign lane_en[3:2] = cfg_link_capable[2] ? 2'b11 : 2'b00;
assign lane_en[7:4] = cfg_link_capable[3] ? 4'b1111 : 4'b0000;


wire    txdetectrx_rise;
assign txdetectrx_rise = (txdetectrx_loopback & !txdetectrx_loopback_d);
wire   g5_lpbk_exit_timeout = ltssm_in_lpbk_exit_timeout & (current_data_rate >= `GEN5_RATE);
wire   g5_lpbk              = ltssm_in_lpbk & (current_data_rate >= `GEN5_RATE);
always @(posedge core_clk or negedge core_rst_n)
begin : drive_txdetectrx_loopback
    integer ln;

    if (!core_rst_n) begin
        int_xpipe_txdetectrx_loopback   <= #TP 0;
        txdetectrx_loopback_d           <= #TP 0;
    end else begin
        for (ln=0; ln<NL; ln=ln+1)
            int_xpipe_txdetectrx_loopback[ln] <= #TP (!lane_en[ln])                                     ? 1'b0 : // always 0 when downsized by cfg_link_capable
 g5_lpbk ? (txdetectrx_rise  ? 1'b1 : int_xpipe_txdetectrx_loopback[ln]) : // 1 if txdetectrx_loopback rising at gen5 rate, i.e. lpbk slave in lpbk.active || lpbk.exit
 g5_lpbk_exit_timeout ? (tx_g5_lpbk_deassert  ? 1'b0 : int_xpipe_txdetectrx_loopback[ln]) : // always 0 when in LPBK_EXIT_TIMEOUT at txelecidle rising at gen5 rate
                                                     txdetectrx_rise                                    ? 1'b1 :
                                                     (!txelecidle[0] & !txdetectrx_loopback_d)          ? 1'b0 : // Loopback
                                                     (phy_mac_phystatus[ln] && ltssm_powerdown==2'b10)  ? 1'b0 : // Knock down quickly for RxDetect
                                                     int_xpipe_txdetectrx_loopback[ln];
        txdetectrx_loopback_d       <= #TP txdetectrx_loopback;
    end
end

endmodule
