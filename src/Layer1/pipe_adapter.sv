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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/pipe_adapter.sv#9 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// --- This module provides the pipe datapath interface/adapter
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module pipe_adapter
#(
    parameter INST = 0, // The uniquifying parameter for each port logic instance
    parameter NL = `CX_NL,
    parameter TX_COEF_WD = 18,
    parameter AW            = `CX_ANB_WD,
    parameter TP = `TP,
    parameter WIDTH_WD = `CX_PHY_WIDTH_WD,
    parameter P_R_WD = `PCLK_RATE_WD,
    parameter BAC_WD = `CX_BAC_WD  // Width of the BlockAlignControl signal
    ,
    parameter PM_SYNC_DEPTH = 2
)
(
    input                         clk,
    input                         rst_n,
    input                         aux_clk,
    input  [NL-1:0]               phy_mac_phystatus,
    input  [NL-1:0]               mac_phy_txcompliance,
    input  [1:0]                  pm_en_pulse_det,
    

    input                         cfg_elastic_buffer_mode,
    input  [2:0]                  rate,
    input  [1:0]                  powerdown,
    input  [AW-1:0]               smlh_active_nb,
    input  [5:0]                  smlh_link_mode,           // 1000 --- x8 mode, 0100 ---- x4 mode, 0010 ---- x2 mode, 0001 ---- x1 mode

    input  [NL-1:0]               rxdatavalid,
    input  [NL-1:0]               txelecidle,
    input  [NL-1:0]               g3_txdatavalid,
    input  [NL-1:0]               g12_pacing_txdatavalid,
    input  [1:0]                  g12_txdeemph,
    input  [NL*TX_COEF_WD-1:0]    g3_txdeemph,
    input  [BAC_WD-1:0]           g3_blockaligncontrol,
    
    output [NL-1:0]               pipe_rxdatavalid,
    output [NL-1:0]               pipe_txdatavalid,
    output [NL*TX_COEF_WD-1:0]    pipe_txdeemph,
    output [BAC_WD-1:0]           pipe_blockaligncontrol,
    output                        pipe_encodedecodebypass,
    output [3:0]                  pipe_powerdown,
    output logic  [WIDTH_WD-1:0]  pipe_width,
    output                        pipe_serdes_arch,
    output     [WIDTH_WD-1:0]     pipe_rxwidth,
    output logic [P_R_WD-1:0]     pipe_pclk_rate // extended to 4-bit from 3-bit for CCIX
    ,
    output [2:0]                  pipe_cclk_rate                 // rate for core_clk
    ,
    output  wire [1:0]            pipe_aux_sync_p1_ack,     // Powerdown transition to P1 acknowledge
    output  wire [1:0]            pipe_aux_sync_block       // Phystatus pulse converter busy indication in aux_clk domain
);

pipe_to_aux_sync
 #(
  .PM_SYNC_DEPTH  (PM_SYNC_DEPTH)
) u_pipe_to_aux[1:0] (
  // Inputs
  .pipe_clk                 (clk),
  .aux_clk                  (aux_clk),
  .rst_n                    (rst_n),
  .phy_mac_phystatus        (phy_mac_phystatus),
  .mac_phy_txcompliance     (mac_phy_txcompliance),
  .pm_en_pulse_det          (pm_en_pulse_det),
  // Outputs
  .pipe_aux_sync_p1_ack     (pipe_aux_sync_p1_ack),
  .pipe_aux_sync_block      (pipe_aux_sync_block)
  
);


`define DEFAULT_SUPPORT_POWER_STATE_PHY_SPECIFIC 2'b00

`define DEFAULT_SUPPORT_ENCODE_DECODE_BYPASS     1'b0

//PIPE spec says: allows the PHY to instruct the MAC to ignore the data interface for one clock cycle.
assign pipe_rxdatavalid = cfg_elastic_buffer_mode ? rxdatavalid : (rate == `GEN1_RATE || rate == `GEN2_RATE) ? {NL{1'b1}} : rxdatavalid;

//PIPE spec says: The MAC must always have TxDataValid
//asserted when TxElecIdle is asserted or deasserted.
reg [NL-1:0] txelecidle_d;
always @( posedge clk or negedge rst_n ) begin : txelecidle_d_PROC
    if ( ~rst_n )
        txelecidle_d <= #TP {NL{1'b1}};
    else
        txelecidle_d <= #TP txelecidle;
end // txelecidle_d_PROC

assign pipe_txdatavalid = (powerdown != `P0) ? {NL{1'b1}} : (rate == `GEN3_RATE || rate == `GEN4_RATE || rate == `GEN5_RATE || rate == `GEN6_RATE) ? (g3_txdatavalid | txelecidle) : (g12_pacing_txdatavalid | txelecidle);

//don't support Power State Phy Specific

//support No De-emphasis or not. SUPPORT_GEN1/GEN2_NO_DEEMPHASIS is configurable
assign pipe_txdeemph = (rate == `GEN3_RATE || rate == `GEN4_RATE || rate == `GEN5_RATE || rate == `GEN6_RATE) ? g3_txdeemph : {NL{{(TX_COEF_WD-2){1'b0}}, g12_txdeemph}};

//Tell PHY don't do Block Alignment while in L0 or LPBK_ACTIVE for slave
assign pipe_blockaligncontrol = g3_blockaligncontrol;

//don't support encode/decode bypass. PHY has to do encode/decode.
assign pipe_encodedecodebypass = `DEFAULT_SUPPORT_ENCODE_DECODE_BYPASS;


assign pipe_powerdown = ({`DEFAULT_SUPPORT_POWER_STATE_PHY_SPECIFIC, powerdown});

// PIPE Data Path Width
// 0 8 bits
// 1 16 bits
// 2 32 bits
// 3 64 bits
// 4 128 bits
// 5 256 bits
// Core uses
// 1 8 bits
// 2 16 bits
// 4 32 bits
// 8 64 bits
// 16 128 bits
// 32 256 bits

localparam PHY_GEN1_PIPE_WIDTH = $clog2( `CX_PHY_NB_GEN1 ) ;
localparam PHY_GEN2_PIPE_WIDTH = $clog2( `CX_PHY_NB_GEN2 ) ;
localparam PHY_GEN3_PIPE_WIDTH = $clog2( `CX_PHY_NB_GEN3 ) ;
localparam PHY_GEN4_PIPE_WIDTH = $clog2( `CX_PHY_NB_GEN4 ) ;
localparam PHY_GEN5_PIPE_WIDTH = $clog2( `CX_PHY_NB_GEN5 ) ;
localparam PHY_GEN6_PIPE_WIDTH = $clog2( `CX_PHY_NB_GEN6 ) ;

always_comb begin

 // PCIe
                                             pipe_width = PHY_GEN1_PIPE_WIDTH ;
 if(rate == `GEN2_RATE) pipe_width = PHY_GEN2_PIPE_WIDTH ;
 if(rate == `GEN3_RATE) pipe_width = PHY_GEN3_PIPE_WIDTH ;
 if(rate == `GEN4_RATE) pipe_width = PHY_GEN4_PIPE_WIDTH ;
 if(rate == `GEN5_RATE) pipe_width = PHY_GEN5_PIPE_WIDTH ;
 if(rate == `GEN6_RATE) pipe_width = PHY_GEN6_PIPE_WIDTH ;
end

// This signal indicates whether SerDes architecture is enabled.
assign pipe_serdes_arch = `CX_PIPE_SERDES_ARCH_VALUE;

// PIPE Receive Data Path Width
// 0 10 bits
// 1 20 bits
// 2 40 bits
// 3 80 bits
// 4 160 bits
// 5 320 bits
assign pipe_rxwidth = pipe_width;

// PIPE PCLK rate
// 0 62.5 Mhz
// 1 125 Mhz
// 2 250 Mhz
// 3 500 Mhz
// 4 1000 Mhz
// 5 2000 MHz
// 6 Reserved
// 7 Reserved
// 8 625Mhz
// 9 781.25 Mhz
// A 1250 Mhz
// B 1562.5 Mhz
// C Reserved
// D Reserved
// E Reserved
// F Reserved
// g1 : 1s(dp)->500MHz(3)    / 1s,2s(dp)->250MHz(2)  / 2s->125MHz(1)  / 4s->62.5MHz(0)
// g1 : 1s(dp)->500MHz(3)    / 1s,2s(dp)->250MHz(2)  / 2s->125MHz(1)  / 4s->62.5MHz(0)
// g2 : 1s,2s(dp)->500MHz(3) / 2s->250MHz(2)         / 4s->125MHz(1)
// g3 : 1s->1000MHz(4)       / 2s->500MHz(3)         / 4s->250MHz(2)   / 8s->125MHz(1) / 16s->62.5MHz(0)
// g4 : 1s->N/A              / 2s->1000MHz(4)        / 4s->500MHz(3)   / 8s->250MHz(2) / 16s->125MHz(1)
// g5 : 1s->N/A              / 2s->2000MHz(5)        / 4s->1000MHz(4)  / 8s->500MHz(3) / 16s->250MHz(2)
// g6 : 1s->N/A              / 2s->N/A               / 4s->2000MHz(5)  / 8s->1000MHz(4) / 16s->500MHz(3) /32s->350Mhz(2)

// Convert Clock period to PIPE PCLK Rate encoding
function automatic integer convert_pclk_rate ;
  input [15:0]  clk_period ;

  if( clk_period == 16'd16_000 ) convert_pclk_rate = 16'd0 ;    //  16ns / 62.5MHz
  if( clk_period ==  16'd8_000 ) convert_pclk_rate = 16'd1 ;    //   8ns / 125MHz
  if( clk_period ==  16'd4_000 ) convert_pclk_rate = 16'd2 ;    //   4ns / 250MHz
  if( clk_period ==  16'd2_000 ) convert_pclk_rate = 16'd3 ;    //   2ns / 500MHz
  if( clk_period ==  16'd1_000 ) convert_pclk_rate = 16'd4 ;    //   1ns /   1GHz
  if( clk_period ==    16'd500 ) convert_pclk_rate = 16'd5 ;    // 500ps /   2GHz
  if( clk_period ==    16'd250 ) convert_pclk_rate = 16'd6 ;    // 250ps /   4GHz
  if( clk_period ==    16'd125 ) convert_pclk_rate = 16'd7 ;    // 125ps /   8GHz
endfunction

localparam PHY_GEN1_PCLK_RATE = convert_pclk_rate( `CX_PHY_GEN1_CLK_PERIOD_PS ) ;
localparam PHY_GEN2_PCLK_RATE = convert_pclk_rate( `CX_PHY_GEN2_CLK_PERIOD_PS ) ;
localparam PHY_GEN3_PCLK_RATE = convert_pclk_rate( `CX_PHY_GEN3_CLK_PERIOD_PS ) ;
localparam PHY_GEN4_PCLK_RATE = convert_pclk_rate( `CX_PHY_GEN4_CLK_PERIOD_PS ) ;
localparam PHY_GEN5_PCLK_RATE = convert_pclk_rate( `CX_PHY_GEN5_CLK_PERIOD_PS ) ;
localparam PHY_GEN6_PCLK_RATE = convert_pclk_rate( `CX_PHY_GEN6_CLK_PERIOD_PS ) ;

always_comb begin

 // PCIe
                                             pipe_pclk_rate = PHY_GEN1_PCLK_RATE ;
 if(rate == `GEN2_RATE) pipe_pclk_rate = PHY_GEN2_PCLK_RATE ;
 if(rate == `GEN3_RATE) pipe_pclk_rate = PHY_GEN3_PCLK_RATE ;
 if(rate == `GEN4_RATE) pipe_pclk_rate = PHY_GEN4_PCLK_RATE ;
 if(rate == `GEN5_RATE) pipe_pclk_rate = PHY_GEN5_PCLK_RATE ;
 if(rate == `GEN6_RATE) pipe_pclk_rate = PHY_GEN6_PCLK_RATE ;

end


// CORE CLK rate (This signal is dynamically changed by active rate or active lanes.)
// Clock frequency ratio between the core_clk and core_pl_clk
// 0 Reserved
// 1 1:1
// 2 1:2
// 3 1:4
// 4 1:8
// 5 1:16
// 6 Reserved
// 7 Reserved
localparam      DW = `CX_DW;
wire [5:0]      int_active_nb;
wire [5:0]      int_smlh_link_mode;
reg  [6:0]      active_pl_nw;
wire [4:0]      int_active_pldl_ratio;               // active ratio b/w layer1 and layer2

assign int_active_nb      = {{(6-AW){1'b0}}, smlh_active_nb};
assign int_smlh_link_mode = smlh_link_mode;

always @(*)
begin
  case({int_active_nb,int_smlh_link_mode})
      12'b000010_000001 : active_pl_nw = 2;  // 2sx1
      12'b000010_000010 : active_pl_nw = 4;  // 2sx2
      12'b000010_000100 : active_pl_nw = 8;  // 2sx4
      12'b000010_001000 : active_pl_nw = 16;  // 2sx8
      12'b000100_000001 : active_pl_nw = 4;  // 4sx1
      12'b000100_000010 : active_pl_nw = 8;  // 4sx2
      12'b000100_000100 : active_pl_nw = 16;  // 4sx4
      12'b000100_001000 : active_pl_nw = 32;  // 4sx8
      12'b001000_000001 : active_pl_nw = 8;  // 8sx1
      12'b001000_000010 : active_pl_nw = 16;  // 8sx2
      12'b001000_000100 : active_pl_nw = 32;  // 8sx4
      12'b001000_001000 : active_pl_nw = 64;  // 8sx8
      default      : active_pl_nw = 0;  //
  endcase
end

assign int_active_pldl_ratio =
        (`CX_FREQ_STEP_DL_MODE==0) ?
            (pipe_pclk_rate == 0) ? 5'd2 : // ratio 1:2
                                    5'd4 : // ratio 1:4
        (DW==512) ? // 512bit
            (active_pl_nw==0 ) ? 5'd1  : // ratio 1:1
            (active_pl_nw==64) ? 5'd1  : // ratio 1:1
            (active_pl_nw==32) ? 5'd2  : // ratio 1:2
            (active_pl_nw==16) ? 5'd4  : // ratio 1:4
            (active_pl_nw==8 ) ? 5'd8  : // ratio 1:8
                                 5'd16 : // ratio 1:16
        // others
                                 5'd1 ; // ratio 1:1

assign pipe_cclk_rate =
           (int_active_pldl_ratio==5'd16) ? 5 :  // 1:16
           (int_active_pldl_ratio==5'd8)  ? 4  : // 1:8
           (int_active_pldl_ratio==5'd4)  ? 3  : // 1:4
           (int_active_pldl_ratio==5'd2)  ? 2  : // 1:2
                                            1  ; // 1:1

endmodule
