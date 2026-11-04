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
// ---    $Revision: #12 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_rasdes_tba_reg.sv#12 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains RAS D.E.S Time based analysis registers.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"

 module cdm_rasdes_tba_reg
   import DWC_pcie_ctl_pkg::N_XADM_IF;
   import DWC_pcie_ctl_pkg::N_XADM_P_IF;
   import DWC_pcie_ctl_pkg::N_XADM_NP_IF;
   import DWC_pcie_ctl_pkg::N_XADM_CPL_IF;
   import DWC_pcie_ctl_pkg::N_CCIX_IF;
#(
    parameter INST                  = 0,                               // The uniquifying parameter for each port logic instance.
    parameter TP                    = `TP,                             // Clock to Q delay (simulator insurance)
    parameter NW                    = `CX_NW,                          // Number of 32-bit dwords handled by the datapath each clock.
    parameter RX_TLP                = `CX_RX_TLP,                      // Number of TLPs that can be processed in a single cycle
    parameter NUM_EOT               = `CX_NUM_EOT,                     // Max number of END/EDB per cycle
    parameter RASDES_RAM_DATA_WIDTH = `CX_RAS_DES_TBA_RAM_DATA_WIDTH,  // RAM data width
    parameter RASDES_RAM_ADDR_WIDTH = `CX_RAS_DES_TBA_RAM_ADDR_WIDTH   // RAM address data width
)
(
// -------------- Inputs ---------------
    input                              aux_clk,                             // Clock
    input                              sticky_rst_n,                        // Reset sticky registers only
 // --- Register access signals
    input  [31:0]                      cdm_reg_wdata,                       // Write Data 
    input  [3:0]                       cdm_reg_write_pulse,                 // Write Byte Enables
    input  [63:0]                      cdm_reg_id,                          // Register access ID
 // --- Time based Analysis signals
    input                              smlh_in_rl0s,                        // Level: Rx L0s 
    input                              smlh_in_l0s,                         // Level: Tx L0s 
    input                              smlh_in_l0,                          // Level: L0
    input                              smlh_in_l1,                          // Level: L1     
    input                              pm_in_l11,                           // Level: L1.1   
    input                              pm_in_l12,                           // Level: L1.2   
    input                              smlh_ltssm_in_l0p,                   // Level: L0p
    input                              smlh_link_in_training,               // Level: Config/Recovery
    input  [RX_TLP*11-1:0]             rtlh_rx_tlp_dpsize,                  // Receiving TLP's data payload size[DW]
    input  [N_XADM_IF*11-1:0]            xtlh_tx_tlp_dpsize,                  // Transmitting TLP data payload size[DW]
 //---- RAM I/F -----------------------
    input  [RASDES_RAM_DATA_WIDTH-1:0] tba_ram_dataout,
 //---- The others -----------------------
    input  [2:0]                       current_data_rate,                   // 0:Gen1(Gear1), 1:Gen2(Gear2), 2:Gen3(Gear3), 3:Gen4
    input  [1:0]                       app_ras_des_tba_ctrl,                // Time base analysis control (00:No actions / 01:Start / 10:End / 11:Reserved)
    input                              pm_sel_aux_clk,
    input                              aux_clk_active,
    input  [`CX_PL_AUX_CLK_FREQ_WD-1:0] cfg_pl_aux_clk_freq,
// -------------- Outputs ---------------
 //---- RAM I/F -----------------------
    output                             tba_ram_ena,
    output                             tba_ram_wea,
    output [RASDES_RAM_ADDR_WIDTH-1:0] tba_ram_addra,
    output [RASDES_RAM_DATA_WIDTH-1:0] tba_ram_datain,
    output                             tba_ram_enb,
    output [RASDES_RAM_ADDR_WIDTH-1:0] tba_ram_addrb,
 // --- Register access signals
    output reg [1:0]                   cdm_tba_ack,                         // Acknowledge from Timebase analysis module
    output reg [31:0]                  cdm_tba_rdata                        // Read Data 
) ;

//---------------------------------------------------
//  Common
//---------------------------------------------------
    localparam                         NL                          = `CX_NL;
    localparam reg [17:0]              FREQ_MULTIPLIER             = `CX_FREQ_MULTIPLIER;             // Frequency of operation
    localparam reg [17:0]              TBA_TIME_CPCIE_1MS          = `TIME_CPCIE_1MS ;
    localparam                         MAX_DATA_RATE_MB            = (`CX_MAX_PCIE_SPEED == 6) ? 8192 :
                                                                     (`CX_MAX_PCIE_SPEED == 5) ? 4096 : // MB/s = GT/s * 1024 / 8bit
                                                                     (`CX_MAX_PCIE_SPEED == 4) ? 2048 :
                                                                     (`CX_MAX_PCIE_SPEED == 3) ? 1024 :
                                                                     (`CX_MAX_PCIE_SPEED == 2) ? 640  :
                                                                                                 320  ;

    localparam                         TBA_DATA_WIDTH_TMP         = (`CX_MAX_PCIE_SPEED > 2) ? $clog2(MAX_DATA_RATE_MB) + 2*$clog2(1024) + $clog2(NL*4*128/130/4): // MB/s * 1024 * 1024 * Lane * 4sec * 128b130b encodeing / 4 Bytes
                                                                                               $clog2(MAX_DATA_RATE_MB) + 2*$clog2(1024) + $clog2(NL*4*8/10/4);    // MB/s * 1024 * 1024 * Lane * 4sec * 8b10b encodeing / 4 Bytes
    localparam                         TBA_DATA_RATE_COUNT_WIDTH  = (TBA_DATA_WIDTH_TMP > 34) ? TBA_DATA_WIDTH_TMP: 34; 

    reg    [TBA_DATA_RATE_COUNT_WIDTH-1:0]  rxdata_cnt ;
    reg    [TBA_DATA_RATE_COUNT_WIDTH-1:0]  txdata_cnt ;
    logic  [31:0]                      unit_freq_time ;
    reg                                reg_req ;
    reg    [7:0]                       reg_index ;

    wire   [7:0]                       int_reg_0x10, int_reg_0x11, int_reg_0x12, int_reg_0x13 ;  // Read Data Address 0x10-0x13
    wire   [7:0]                       int_reg_0x14, int_reg_0x15, int_reg_0x16, int_reg_0x17 ;  // Read Data Address 0x14-0x17
    wire   [7:0]                       int_reg_0x18, int_reg_0x19, int_reg_0x1a, int_reg_0x1b ;  // Read Data Address 0x18-0x1b

    wire   [RASDES_RAM_DATA_WIDTH/2-1:0]   reg_rdata ;
    wire                                   reg_ack ;

    wire   [7:0]                           rx_dpsize_valid ;
    wire   [7:0]                           tx_dpsize_valid ;
    wire   [10:0]                          rx_dpsize[0:7] ;
    wire   [TBA_DATA_RATE_COUNT_WIDTH:0]   rx_dpsize_sum ;
    wire   [10:0]                          tx_dpsize[0:7] ;
    wire   [TBA_DATA_RATE_COUNT_WIDTH:0]   tx_dpsize_sum ;
    genvar                             ii;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 4
// PCIE Offset      - `RAS_DES_PTR + 10h
// length           - 4 byte
// Cfig register    - int_reg_0x13, int_reg_0x12, int_reg_0x11, int_reg_0x10
// register         - Timer start [0] : RW
//                  - Time based duration select [15:8] : RW
//                  - Time based report select [31:24] : RW
// -----------------------------------------------------------------------------
    reg                                int_reg_timer_en ;                 // Timer start [0]
    reg    [7:0]                       int_reg_duration_sel ;             // Time based duration select [15:8] 
    reg    [7:0]                       int_reg_report_sel;                // Time based report select [31:24]
    wire                               int_reg_timer_en_pos ;             // Posedge of Timer start [0]
    wire                               int_reg_timer_en_neg ;             // Negedge of Timer start [0]

    // Time control
    reg                                tba_time_timeup ;

    reg    [19:0]                      tba_4us_cnt ;
    wire                               tba_time_4us_timeup ;

    logic  [17:0]                      cmn_time_4us_duration ;
    wire                               cmn_time_en_4us ;
    reg    [17:0]                      cmn_time_cnt ;

    wire   [12:0]                      aux_time_4us ;
    reg                                aux_time_en_4us ;
    reg    [9:0]                       aux_time_cnt ;

    assign int_reg_timer_en_pos = (cdm_reg_id[4] & cdm_reg_write_pulse[0] &  cdm_reg_wdata[0]) // Start/Restart
                                | (!int_reg_timer_en & app_ras_des_tba_ctrl==2'b01); // Start
    assign int_reg_timer_en_neg = (cdm_reg_id[4] & cdm_reg_write_pulse[0] & ~cdm_reg_wdata[0]) // End
                                | (int_reg_timer_en & tba_time_timeup)
                                | (app_ras_des_tba_ctrl==2'b10); // End

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            int_reg_timer_en <= #TP 1'b0 ;
        end else begin
            if ( int_reg_timer_en_pos ) begin
                int_reg_timer_en <= #TP 1'b1 ;
            end else if ( int_reg_timer_en_neg ) begin
                int_reg_timer_en <= #TP 1'b0 ;
            end
        end
    end

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            int_reg_duration_sel <= #TP 8'd1 ;
            int_reg_report_sel   <= #TP 8'd0 ;
        end else begin
            int_reg_duration_sel <= #TP (cdm_reg_id[4] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[15:8]  : int_reg_duration_sel ;
            int_reg_report_sel   <= #TP (cdm_reg_id[4] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[31:24] : int_reg_report_sel ;
        end
    end

    assign {int_reg_0x13,int_reg_0x12,int_reg_0x11,int_reg_0x10} = { int_reg_report_sel            // [31:24]
                                                                   , 8'd0                          // [23:16]
                                                                   , int_reg_duration_sel          // [15:8]
                                                                   , 7'd0                          // [7:1]
                                                                   , int_reg_timer_en              // [0]
                                                                   } ;

//---------------------------------------------------
//  Create time unit
//--------------------------------------------------
    localparam                                 EVT_TYP_PULSE = 1'b0 ; // Count-up the cycles of event_signal==1
    localparam                                 MAX_RAM_INDX = 256; // Max number of RAM counter that can be implemented
    localparam                                 TBA_EVT_TOTAL = 15;             // Total number of events implemented in TBA
    localparam  MAX_SPEED       = `CX_MAX_PCIE_SPEED;
    localparam  MAX_CLK_FREQ_PS = (MAX_SPEED == 6) ? `CX_MAC_GEN6_CLK_PERIOD_PS
                                : (MAX_SPEED == 5) ? `CX_MAC_GEN5_CLK_PERIOD_PS
                                : (MAX_SPEED == 4) ? `CX_MAC_GEN4_CLK_PERIOD_PS
                                : (MAX_SPEED == 3) ? `CX_MAC_GEN3_CLK_PERIOD_PS
                                : (MAX_SPEED == 2) ? `CX_MAC_GEN2_CLK_PERIOD_PS
                                                   : `CX_MAC_GEN1_CLK_PERIOD_PS ;
    localparam  FSTEP_DL_RATIO  = `CX_FREQ_MULTIPLIER / `CX_PL_FREQ_MULTIPLIER ;
    localparam  GEN6_EVT_WDTH   = `CX_MAC_GEN6_CLK_PERIOD_PS / MAX_CLK_FREQ_PS ;
    localparam  GEN5_EVT_WDTH   = `CX_MAC_GEN5_CLK_PERIOD_PS / MAX_CLK_FREQ_PS ;
    localparam  GEN4_EVT_WDTH   = `CX_MAC_GEN4_CLK_PERIOD_PS / MAX_CLK_FREQ_PS ;
    localparam  GEN3_EVT_WDTH   = `CX_MAC_GEN3_CLK_PERIOD_PS / MAX_CLK_FREQ_PS ;
    localparam  GEN2_EVT_WDTH   = `CX_MAC_GEN2_CLK_PERIOD_PS / MAX_CLK_FREQ_PS ;
    localparam  GEN1_EVT_WDTH   = `CX_MAC_GEN1_CLK_PERIOD_PS / MAX_CLK_FREQ_PS ;

    always_comb begin
        unit_freq_time = MAX_CLK_FREQ_PS * FSTEP_DL_RATIO ;
        cmn_time_4us_duration = (4*(TBA_TIME_CPCIE_1MS+1)/1000)-1 ;
    end


wire            timer2;
DWC_pcie_tim_gen
 #(
  .CLEAR_CNTR_TO_1 (1)
)
u_gen_timer2
(
     .clk               (aux_clk)
    ,.rst_n             (sticky_rst_n)
    ,.current_data_rate (current_data_rate)
    ,.clr_cntr          (int_reg_timer_en_pos)  // cleaer counter for timing gen

    ,.cnt_up_en         (timer2)                // timer count-up
);

//---------------------------------------------------
//  Timer control
//---------------------------------------------------

  //common clk 4us timer
   always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cmn_time_cnt <= #TP 18'd0 ;
        end else begin
            if ( int_reg_timer_en_pos ) begin
               cmn_time_cnt <= #TP 18'd0 ;
            end else if ( int_reg_timer_en && (~aux_clk_active && ~pm_sel_aux_clk)) begin
                if ( cmn_time_en_4us ) begin
                    cmn_time_cnt <= #TP 18'd0 ;
                end else begin
                    cmn_time_cnt <= #TP cmn_time_cnt + (timer2 ? 1'b1 : 1'b0) ;
                end
            end
        end
    end 

    assign cmn_time_en_4us = (cmn_time_cnt==cmn_time_4us_duration) & timer2 ;

   //aux_clk 4us timer
    assign aux_time_4us = (cfg_pl_aux_clk_freq==0) ? 4096 : {1'b0, cfg_pl_aux_clk_freq ,2'b0} ; // 0 is treated as 1024*4

    always @(posedge aux_clk or negedge sticky_rst_n) begin : aux_clk_en_1us_PROC
        if (!sticky_rst_n) begin
            aux_time_cnt <= #TP 0;
            aux_time_en_4us <= #TP 0;
        end else begin
            if ( int_reg_timer_en_pos ) begin
              aux_time_cnt <= #TP 18'd0 ;
            end else if ( int_reg_timer_en && (aux_clk_active && pm_sel_aux_clk)) begin
                if (aux_time_cnt >= (aux_time_4us - 1)) begin
                  aux_time_cnt <= #TP 0;
                  aux_time_en_4us <= #TP 1;
                end else begin
                    aux_time_cnt <= #TP aux_time_cnt + 1;
                    aux_time_en_4us <= #TP 0;
                end
            end
        end
    end

    // 4us counter
    assign tba_time_4us_timeup = (aux_clk_active) ? aux_time_en_4us : cmn_time_en_4us;

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            tba_4us_cnt <= #TP 12'd0 ;
        end else begin
            if ( int_reg_timer_en_pos ) begin
                tba_4us_cnt <= #TP 12'd0 ;
            end else if ( int_reg_timer_en ) begin
                if ( tba_time_4us_timeup ) begin
                    tba_4us_cnt <= #TP tba_4us_cnt + 12'd1;
                end
            end
        end
    end

    always @ ( * ) begin
        case ( int_reg_duration_sel )
            8'd1    : tba_time_timeup = tba_time_4us_timeup & (tba_4us_cnt==20'd249) ;     //   1 ms
            8'd2    : tba_time_timeup = tba_time_4us_timeup & (tba_4us_cnt==20'd2499) ;    //  10 ms
            8'd3    : tba_time_timeup = tba_time_4us_timeup & (tba_4us_cnt==20'd24999) ;   // 100 ms
            8'd4    : tba_time_timeup = tba_time_4us_timeup & (tba_4us_cnt==20'd249999) ;  //   1 s
            8'd5    : tba_time_timeup = tba_time_4us_timeup & (tba_4us_cnt==20'd499999) ;  //   2 s
            8'd6    : tba_time_timeup = tba_time_4us_timeup & (tba_4us_cnt==20'd999999) ;  //   4 s
            8'hff   : tba_time_timeup = tba_time_4us_timeup & (tba_4us_cnt==20'd0) ;       //   4 us
            default : tba_time_timeup = 1'b0 ;                                             // manual control
        endcase
    end

// -----------------------------------------------------------------------------
// cdm_reg_id       - 5
// PCIE Offset      - `RAS_DES_PTR + 14h
// length           - 4 byte
// Cfig register    - int_reg_0x17, int_reg_0x16, int_reg_0x15, int_reg_0x14
// register         - Time based analysis data [31:0] : RO
// -----------------------------------------------------------------------------
    wire  [63:0]                        int_reg_rdata;
    wire  [63:0]                        int_txdata_cnt;
    wire  [63:0]                        int_rxdata_cnt;
    reg   [31:0]                        int_tba_data_l_b ;
    reg   [31:0]                        int_tba_data_l ;
    reg                                 int_reg_read_ram_l ;

    assign int_reg_rdata = {{64-RASDES_RAM_DATA_WIDTH/2{1'b0}}, reg_rdata[RASDES_RAM_DATA_WIDTH/2-1:0]};
    assign int_txdata_cnt= {{64-(TBA_DATA_RATE_COUNT_WIDTH-2){1'b0}}, txdata_cnt[TBA_DATA_RATE_COUNT_WIDTH-1:2]};
    assign int_rxdata_cnt= {{64-(TBA_DATA_RATE_COUNT_WIDTH-2){1'b0}}, rxdata_cnt[TBA_DATA_RATE_COUNT_WIDTH-1:2]};

    always @(*) begin
        case ( int_reg_report_sel )
            8'h00   : begin
                int_tba_data_l_b = unit_freq_time ;                     // Unit time
                int_reg_read_ram_l = 1'b0 ;
            end
            8'h10   : begin
                int_tba_data_l_b = 32'b0 ;
                int_reg_read_ram_l = 1'b0 ;
            end
            8'h20   : begin
                int_tba_data_l_b = int_txdata_cnt[31:0] ;     // Tx data rate
                int_reg_read_ram_l = 1'b0 ;
            end
            8'h21   : begin
                int_tba_data_l_b = int_rxdata_cnt[31:0] ;     // Rx data rate
                int_reg_read_ram_l = 1'b0 ;
            end
            8'h22   : begin
                int_tba_data_l_b = 32'b0 ;
                int_reg_read_ram_l = 1'b0 ;
            end
            8'h23   : begin
                int_tba_data_l_b = 32'b0 ;
                int_reg_read_ram_l = 1'b0 ;
            end
            default : begin
                int_tba_data_l_b = int_reg_rdata[31:0] ;            // Access to RAM
                int_reg_read_ram_l = cdm_reg_id[5] ;
            end
        endcase
    end

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            int_tba_data_l <= #TP 32'd0 ;
        end else begin
            int_tba_data_l <= #TP int_tba_data_l_b ;
        end
    end

    assign {int_reg_0x17,int_reg_0x16,int_reg_0x15,int_reg_0x14} = int_tba_data_l ; // [31:0]

// -----------------------------------------------------------------------------
// cdm_reg_id       - 6
// PCIE Offset      - `RAS_DES_PTR + 18h
// length           - 4 byte
// Cfig register    - int_reg_0x17h8, int_reg_0x19, int_reg_0x1a, int_reg_0x1b
// register         - Time based analysis data [63:32] : RO
// -----------------------------------------------------------------------------
    reg   [31:0]                        int_tba_data_h_b ;
    reg   [31:0]                        int_tba_data_h ;
    reg                                 int_reg_read_ram_h ;

    always @(*) begin
        case ( int_reg_report_sel )
            8'h00   : begin
                int_tba_data_h_b = 32'b0 ;       // Unit time
                int_reg_read_ram_h = 1'b0;
            end
            8'h20   : begin
                int_tba_data_h_b = int_txdata_cnt[63:32] ;     // Tx data rate
                int_reg_read_ram_h = 1'b0;
            end
            8'h21   : begin
                int_tba_data_h_b = int_rxdata_cnt[63:32] ;     // Rx data rate
                int_reg_read_ram_h = 1'b0;
            end
            8'h22   : begin
                int_tba_data_h_b = 32'b0 ;
                int_reg_read_ram_h = 1'b0;
            end
            8'h23   : begin
                int_tba_data_h_b = 32'b0 ;
                int_reg_read_ram_h = 1'b0;
            end
            default : begin
                int_tba_data_h_b = int_reg_rdata[63:32] ;// Access to RAM
                int_reg_read_ram_h = cdm_reg_id[6] ;
            end
        endcase
    end

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            int_tba_data_h <= #TP 32'd0 ;
        end else begin
            int_tba_data_h <= #TP int_tba_data_h_b ;
        end
    end

    assign {int_reg_0x1b,int_reg_0x1a,int_reg_0x19,int_reg_0x18} = int_tba_data_h ; // [31:0]

// =============================================================================
// FF counter
// =============================================================================
    parameter XADM_IF_WD     = N_XADM_IF;
    parameter CCIX_IF_WD     = N_CCIX_IF;
    generate
      // Create valid signal of each rtlh_rx_tlp_dpsize
      for (ii=0; ii<8; ii=ii+1) begin : gen_rx_dpsize_valid_for
        if ( ii<RX_TLP ) begin : gen_rx_dpsize_valid_if
          assign rx_dpsize_valid[ii] = |rtlh_rx_tlp_dpsize[11*ii +: 11] ;
        end else begin : gen_rx_dpsize_valid_else
          assign rx_dpsize_valid[ii] = 1'd0 ;
        end
      end

      // Create valid signal of each xtlh_tx_tlp_dpsize
      for (ii=0; ii<8; ii=ii+1) begin : gen_tx_dpsize_valid_else
        if ( ii<XADM_IF_WD ) begin : gen_rx_dpsize_valid_if
          assign tx_dpsize_valid[ii] = |xtlh_tx_tlp_dpsize[11*ii +: 11] ;
        end else begin : gen_rx_dpsize_valid_else
          assign tx_dpsize_valid[ii] = 1'd0 ;
        end
      end

      for (ii=0; ii<8 ; ii=ii+1) begin : gen_rx_tlp_dpsize_for
        if ( ii<RX_TLP ) begin : gen_rx_tlp_dpsize_if
          assign rx_dpsize[ii] = rx_dpsize_valid[ii] ? rtlh_rx_tlp_dpsize[11*ii +: 11] : 11'd0 ;
        end else begin : gen_rx_tlp_dpsize_else
          assign rx_dpsize[ii] = 11'd0 ;
        end
      end

      for (ii=0; ii<8 ; ii=ii+1) begin : gen_tx_tlp_dpsize_for
        if ( ii<XADM_IF_WD ) begin : gen_rx_tlp_dpsize_if
          assign tx_dpsize[ii] = tx_dpsize_valid[ii] ? xtlh_tx_tlp_dpsize[11*ii +: 11] : 11'd0 ;
        end else begin : gen_rx_tlp_dpsize_else
          assign tx_dpsize[ii] = 11'd0 ;
        end
      end


    endgenerate

    assign rx_dpsize_sum = {1'b0,  rxdata_cnt}
                         + {{(TBA_DATA_RATE_COUNT_WIDTH+1)-11{1'b0}}, rx_dpsize[0]}
                         + {{(TBA_DATA_RATE_COUNT_WIDTH+1)-11{1'b0}}, rx_dpsize[1]}
                         + {{(TBA_DATA_RATE_COUNT_WIDTH+1)-11{1'b0}}, rx_dpsize[2]}
                         + {{(TBA_DATA_RATE_COUNT_WIDTH+1)-11{1'b0}}, rx_dpsize[3]}
                         + {{(TBA_DATA_RATE_COUNT_WIDTH+1)-11{1'b0}}, rx_dpsize[4]}
                         + {{(TBA_DATA_RATE_COUNT_WIDTH+1)-11{1'b0}}, rx_dpsize[5]}
                         + {{(TBA_DATA_RATE_COUNT_WIDTH+1)-11{1'b0}}, rx_dpsize[6]}
                         + {{(TBA_DATA_RATE_COUNT_WIDTH+1)-11{1'b0}}, rx_dpsize[7]}
                         ;

    assign tx_dpsize_sum = {1'b0,  txdata_cnt}
                         + {{(TBA_DATA_RATE_COUNT_WIDTH+1)-11{1'b0}}, tx_dpsize[0]}
                         + {{(TBA_DATA_RATE_COUNT_WIDTH+1)-11{1'b0}}, tx_dpsize[1]}
                         + {{(TBA_DATA_RATE_COUNT_WIDTH+1)-11{1'b0}}, tx_dpsize[2]}
                         + {{(TBA_DATA_RATE_COUNT_WIDTH+1)-11{1'b0}}, tx_dpsize[3]}
                         + {{(TBA_DATA_RATE_COUNT_WIDTH+1)-11{1'b0}}, tx_dpsize[4]}
                         + {{(TBA_DATA_RATE_COUNT_WIDTH+1)-11{1'b0}}, tx_dpsize[5]}
                         + {{(TBA_DATA_RATE_COUNT_WIDTH+1)-11{1'b0}}, tx_dpsize[6]}
                         + {{(TBA_DATA_RATE_COUNT_WIDTH+1)-11{1'b0}}, tx_dpsize[7]}
                         ;


    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            rxdata_cnt <= #TP {TBA_DATA_RATE_COUNT_WIDTH{1'b0}} ;
        end else begin
            if ( int_reg_timer_en_pos ) begin
                rxdata_cnt <= #TP {TBA_DATA_RATE_COUNT_WIDTH{1'b0}} ;
            end else if ( int_reg_timer_en ) begin
                if ( rx_dpsize_sum[TBA_DATA_RATE_COUNT_WIDTH] ) begin
                    rxdata_cnt <= #TP {TBA_DATA_RATE_COUNT_WIDTH{1'b1}} ;
                end else begin
                    rxdata_cnt <= #TP rx_dpsize_sum[TBA_DATA_RATE_COUNT_WIDTH-1:0] ;
                end
            end
        end
    end

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            txdata_cnt <= #TP {TBA_DATA_RATE_COUNT_WIDTH{1'b0}} ;
        end else begin
            if ( int_reg_timer_en_pos ) begin
                txdata_cnt <= #TP {TBA_DATA_RATE_COUNT_WIDTH{1'b0}} ;
            end else if ( int_reg_timer_en ) begin
                if ( tx_dpsize_sum[TBA_DATA_RATE_COUNT_WIDTH] ) begin
                    txdata_cnt <= #TP {TBA_DATA_RATE_COUNT_WIDTH{1'b1}} ;
                end else begin
                    txdata_cnt <= #TP tx_dpsize_sum[TBA_DATA_RATE_COUNT_WIDTH-1:0] ;
                end
            end
        end
    end


// =============================================================================
// RAM counter
// =============================================================================

    function automatic [15:0] f_ec_evt ;
        input [2:0] rate ;
        input       smlh_in ;
        input [6:0] esm_rate ;
        reg   [15:0] ec_evt_esm;
        reg   [15:0] ec_evt;
        reg   [15:0] ec_evt_default;
        reg   [2:0] rate;
  

        // To match a result for formality tool
        ec_evt_default[0]    = smlh_in;
        ec_evt_default[1]    = (MAX_SPEED>=5) ? 1'b0        :    smlh_in;
        ec_evt_default[3:2]  = (MAX_SPEED>=4) ? 2'b00       : {2{smlh_in}};
        ec_evt_default[7:4]  = (MAX_SPEED>=3) ? 4'b0000     : {4{smlh_in}};
        ec_evt_default[15:8] = (MAX_SPEED>=2) ? 8'b00000000 : {8{smlh_in}};

        if(esm_rate[6])begin
          ec_evt_esm = {12'b0,{4{smlh_in}}};
        end
        else if(esm_rate[5])begin
          ec_evt_esm = {11'b0,{5{smlh_in}}};
        end         
        else if(esm_rate[4])begin
          ec_evt_esm = (GEN4_EVT_WDTH==16) ? {16{smlh_in}} : {{16-GEN4_EVT_WDTH{1'b0}},{GEN4_EVT_WDTH{smlh_in}}};
        end
        else if(esm_rate[3])begin
          ec_evt_esm = (GEN3_EVT_WDTH==16) ? {16{smlh_in}} : {{16-GEN3_EVT_WDTH{1'b0}},{GEN3_EVT_WDTH{smlh_in}}};
        end
        else if(esm_rate[2])begin
          ec_evt_esm = (GEN2_EVT_WDTH==16) ? {16{smlh_in}} : {{16-GEN2_EVT_WDTH{1'b0}},{GEN2_EVT_WDTH{smlh_in}}};
        end
        else if(esm_rate[1])begin
          ec_evt_esm = (GEN1_EVT_WDTH==16) ? {16{smlh_in}} : {{16-GEN1_EVT_WDTH{1'b0}},{GEN1_EVT_WDTH{smlh_in}}};
        end
        else begin
          ec_evt_esm = 16'b0;
        end
        case(rate)
            `GEN6_RATE : ec_evt = (GEN6_EVT_WDTH==16) ? {16{smlh_in}} : {{16-GEN6_EVT_WDTH{1'b0}},{GEN6_EVT_WDTH{smlh_in}}};
            `GEN5_RATE : ec_evt = (GEN5_EVT_WDTH==16) ? {16{smlh_in}} : {{16-GEN5_EVT_WDTH{1'b0}},{GEN5_EVT_WDTH{smlh_in}}};
            `GEN4_RATE : ec_evt = (GEN4_EVT_WDTH==16) ? {16{smlh_in}} : {{16-GEN4_EVT_WDTH{1'b0}},{GEN4_EVT_WDTH{smlh_in}}};
            `GEN3_RATE : ec_evt = (GEN3_EVT_WDTH==16) ? {16{smlh_in}} : {{16-GEN3_EVT_WDTH{1'b0}},{GEN3_EVT_WDTH{smlh_in}}};
            `GEN2_RATE : ec_evt = (GEN2_EVT_WDTH==16) ? {16{smlh_in}} : {{16-GEN2_EVT_WDTH{1'b0}},{GEN2_EVT_WDTH{smlh_in}}};
            `GEN1_RATE : ec_evt = (GEN1_EVT_WDTH==16) ? {16{smlh_in}} : {{16-GEN1_EVT_WDTH{1'b0}},{GEN1_EVT_WDTH{smlh_in}}};
            default    : ec_evt = ec_evt_default;
        endcase
        f_ec_evt =  (|esm_rate[6:1]) ? ec_evt_esm:  ec_evt;
    endfunction

    wire                                       ec_cnt_enable;
    wire                                       ec_ram_active;
    wire   [MAX_RAM_INDX-1:0]                  ec_ram_add_status;
    wire                                       ec_clr_all ;

    wire   [31:0]                              ec_evt[0:TBA_EVT_TOTAL-1] ;
    wire   [TBA_EVT_TOTAL-1:0]                 ec_type ;
    wire   [TBA_EVT_TOTAL-1:0]                 ec_en ;
    wire   [TBA_EVT_TOTAL-1:0]                 ec_clr ;
    wire   [TBA_EVT_TOTAL-1:0]                 ec_ram_add ;
    wire   [31:0]                              ec_cnt[0:TBA_EVT_TOTAL-1] ;

    wire   [MAX_RAM_INDX-1:0]                  ec_en_array ;
    wire   [31:0]                              ec_cnt_array[0:MAX_RAM_INDX-1] ;

    // To activate the counters implemented in RAM, it takes 1 clock after ec_en_bus=1 (Please find ec_ram_active). It is better to set ec_en_bus at the cycle before the posedge of int_reg_timer_en.
    assign ec_cnt_enable = int_reg_timer_en;

    // ------------------------------------------------
    // Tx L0s
    // ------------------------------------------------
    localparam [7:0] RAMIDX_TXL0S  = 8'd0 ;
    assign ec_type[0]       = EVT_TYP_PULSE ;                                               
    assign ec_en[0]         = ec_cnt_enable;                                                
    assign ec_clr[0]        = ec_ram_add[0];                                                
    assign ec_ram_add[0]    = ec_ram_add_status[RAMIDX_TXL0S];                              
    assign ec_evt[0][31:16]  = 16'd0 ;                                 
    assign ec_evt[0][15:0]   = f_ec_evt(current_data_rate, smlh_in_l0s, 7'd0);

    // ------------------------------------------------
    // Rx L0s
    // ------------------------------------------------
    localparam [7:0] RAMIDX_RXL0S  = RAMIDX_TXL0S + 8'd1 ;
    assign ec_type[1]       = EVT_TYP_PULSE ;                                               
    assign ec_en[1]         = ec_cnt_enable;                                                
    assign ec_clr[1]        = ec_ram_add[1];                                                
    assign ec_ram_add[1]    = ec_ram_add_status[RAMIDX_RXL0S];                              
    assign ec_evt[1][31:16]  = 16'd0 ;
    assign ec_evt[1][15:0]   = f_ec_evt(current_data_rate, smlh_in_rl0s, 7'd0);

    // ------------------------------------------------
    // L0
    // ------------------------------------------------
    localparam [7:0] RAMIDX_L0  = RAMIDX_RXL0S + 8'd1 ;
    assign ec_type[2]       = EVT_TYP_PULSE ;
    assign ec_en[2]         = ec_cnt_enable;
    assign ec_clr[2]        = ec_ram_add[2];
    assign ec_ram_add[2]    = ec_ram_add_status[RAMIDX_L0];
    assign ec_evt[2][31:16]  = 16'd0 ;
    assign ec_evt[2][15:0]   = f_ec_evt(current_data_rate, smlh_in_l0, 7'd0);

    // ------------------------------------------------
    // L1
    // ------------------------------------------------
    localparam [7:0] RAMIDX_L1  = RAMIDX_L0 + 8'd1 ;
    assign ec_type[3]       = EVT_TYP_PULSE ;                                               
    assign ec_en[3]         = ec_cnt_enable;                                                
    assign ec_clr[3]        = ec_ram_add[3];                                                
    assign ec_ram_add[3]    = ec_ram_add_status[RAMIDX_L1];                                 
    assign ec_evt[3][31:16]  = 16'd0 ;
    assign ec_evt[3][15:0]   = f_ec_evt(current_data_rate, (~pm_sel_aux_clk & ~aux_clk_active & smlh_in_l1), 7'd0);

    // ------------------------------------------------
    // L1.1
    // ------------------------------------------------
    localparam [7:0] RAMIDX_L11  = RAMIDX_L1 + 8'd1 ;
    assign ec_type[4]       = EVT_TYP_PULSE ;                                               
    assign ec_en[4]         = ec_cnt_enable;                                                
    assign ec_clr[4]        = ec_ram_add[4];                                                
    assign ec_ram_add[4]    = ec_ram_add_status[RAMIDX_L11];                                
    assign ec_evt[4]        = {31'd0, pm_in_l11} ;                                          

    // ------------------------------------------------
    // L1.2
    // ------------------------------------------------
    localparam [7:0] RAMIDX_L12  = RAMIDX_L11 + 8'd1 ;
    assign ec_type[5]       = EVT_TYP_PULSE ;                                               
    assign ec_en[5]         = ec_cnt_enable;                                                
    assign ec_clr[5]        = ec_ram_add[5];                                                
    assign ec_ram_add[5]    = ec_ram_add_status[RAMIDX_L12];                                
    assign ec_evt[5]        = {31'd0, pm_in_l12} ;                                          

    // ------------------------------------------------
    // Configuration/Recovery
    // ------------------------------------------------
    localparam [7:0] RAMIDX_CFG_RCVRY = RAMIDX_L12 + 8'd1 ;
    assign ec_type[6]       = EVT_TYP_PULSE ;                                               
    assign ec_en[6]         = ec_cnt_enable;                                                
    assign ec_clr[6]        = ec_ram_add[6];                                                
    assign ec_ram_add[6]    = ec_ram_add_status[RAMIDX_CFG_RCVRY];                          
    assign ec_evt[6][31:16]  = 16'd0 ;
    assign ec_evt[6][15:0]   = f_ec_evt(current_data_rate, smlh_link_in_training, 7'd0);

    // ------------------------------------------------
    // Tx L0s and Rx L0s or L0p
    // ------------------------------------------------
    localparam [7:0] RAMIDX_TXL0S_RXL0S_OR_L0P  = RAMIDX_CFG_RCVRY + 8'd1 ;
    assign ec_type[7]       = EVT_TYP_PULSE ;                                               
    assign ec_en[7]         = ec_cnt_enable;                                                
    assign ec_clr[7]        = ec_ram_add[7];                                                
    assign ec_ram_add[7]    = ec_ram_add_status[RAMIDX_TXL0S_RXL0S_OR_L0P];                        
    assign ec_evt[7][31:16]  = 16'd0 ;
    assign ec_evt[7][15:0]   = f_ec_evt(current_data_rate, (smlh_in_rl0s & smlh_in_l0s) | smlh_ltssm_in_l0p, 7'd0);

    // ------------------------------------------------
    // L1 AUX
    // ------------------------------------------------
    localparam [7:0] RAMIDX_L1_AUX  = RAMIDX_TXL0S_RXL0S_OR_L0P + 8'd1 ;
    assign ec_type[8]       = EVT_TYP_PULSE ;                                               
    assign ec_en[8]         = ec_cnt_enable;                                                
    assign ec_clr[8]        = ec_ram_add[8];                                                
    assign ec_ram_add[8]    = ec_ram_add_status[RAMIDX_L1_AUX];                             
    assign ec_evt[8]        = {31'd0, (pm_sel_aux_clk & aux_clk_active & smlh_in_l1)} ;

    // ------------------------------------------------
    // Tx L0s (CCIX ESM rate)
    // ------------------------------------------------
    localparam [7:0] RAMIDX_TXL0S_ESM = RAMIDX_L1_AUX;
    assign ec_type[9]       = EVT_TYP_PULSE ;
    assign ec_en[9]         = ec_cnt_enable;
    assign ec_clr[9]        = ec_ram_add[9];
    assign ec_ram_add[9]    = ec_ram_add_status[RAMIDX_TXL0S_ESM];
    assign ec_evt[9][31:16]  = 16'd0 ;
    assign ec_evt[9][15:0]   = 16'd0;

    // ------------------------------------------------
    // Rx L0s (CCIX ESM rate)
    // ------------------------------------------------
    localparam [7:0] RAMIDX_RXL0S_ESM  = RAMIDX_TXL0S_ESM;
    assign ec_type[10]       = EVT_TYP_PULSE ;                                               
    assign ec_en[10]         = ec_cnt_enable;                                                
    assign ec_clr[10]        = ec_ram_add[10];                                                
    assign ec_ram_add[10]    = ec_ram_add_status[RAMIDX_RXL0S_ESM];                          
    assign ec_evt[10][31:16]  = 16'd0 ;
    assign ec_evt[10][15:0]   = 16'd0;


    // ------------------------------------------------
    // L0 (CCIX ESM rate)
    // ------------------------------------------------
    localparam [7:0] RAMIDX_L0_ESM  = RAMIDX_RXL0S_ESM;
    assign ec_type[11]       = EVT_TYP_PULSE ;                                               
    assign ec_en[11]         = ec_cnt_enable;                                                
    assign ec_clr[11]        = ec_ram_add[11];                                               
    assign ec_ram_add[11]    = ec_ram_add_status[RAMIDX_L0_ESM];                             
    assign ec_evt[11][31:16]  = 16'd0 ;
    assign ec_evt[11][15:0]   = 16'd0;


    // ------------------------------------------------
    // L1 (CCIX ESM rate)
    // ------------------------------------------------
    localparam [7:0] RAMIDX_L1_ESM  = RAMIDX_L0_ESM;
    assign ec_type[12]       = EVT_TYP_PULSE ;                                               
    assign ec_en[12]         = ec_cnt_enable;                                                
    assign ec_clr[12]        = ec_ram_add[12];                                               
    assign ec_ram_add[12]    = ec_ram_add_status[RAMIDX_L1_ESM];
    assign ec_evt[12][31:16]  = 16'd0 ;
    assign ec_evt[12][15:0]   = 16'd0;

    // ------------------------------------------------
    // Configuration/Recovery (CCIX ESM rate)
    // ------------------------------------------------
    localparam [7:0] RAMIDX_CFG_RCVRY_ESM = RAMIDX_L1_ESM;
    assign ec_type[13]       = EVT_TYP_PULSE ;                                           
    assign ec_en[13]         = ec_cnt_enable;                                            
    assign ec_clr[13]        = ec_ram_add[13];                                            
    assign ec_ram_add[13]    = ec_ram_add_status[RAMIDX_CFG_RCVRY_ESM];
    assign ec_evt[13][31:16]  = 16'd0 ;
    assign ec_evt[13][15:0]   = 16'd0;

    // ------------------------------------------------
    // Tx L0s and Rx L0s (CCIX ESM rate)
    // ------------------------------------------------
    localparam [7:0] RAMIDX_TXL0S_RXL0S_OR_L0P_ESM  = RAMIDX_CFG_RCVRY_ESM;
    assign ec_type[14]       = EVT_TYP_PULSE ;                                           
    assign ec_en[14]         = ec_cnt_enable;                                            
    assign ec_clr[14]        = ec_ram_add[14];                                            
    assign ec_ram_add[14]    = ec_ram_add_status[RAMIDX_TXL0S_RXL0S_OR_L0P_ESM];
    assign ec_evt[14][31:16]  = 16'd0 ;
    assign ec_evt[14][15:0]   = 16'd0;

    function automatic [31:0] f_evt_width ;
        input [7:0] tba_evt_num ;
        case ( tba_evt_num )
            8'd0  : f_evt_width = 32'd16 ;   // smlh_in_l0s
            8'd1  : f_evt_width = 32'd16 ;   // smlh_in_rl0s
            8'd2  : f_evt_width = 32'd16 ;   // smlh_in_l0
            8'd3  : f_evt_width = 32'd16 ;   // smlh_in_l1
            8'd7  : f_evt_width = 32'd16 ;   //
            8'd4  : f_evt_width =  32'd1 ;  // pm_in_l11
            8'd5  : f_evt_width =  32'd1 ;  // pm_in_l12
            8'd6  : f_evt_width =  32'd16 ;  // smlh_link_in_training
            8'd8  : f_evt_width =  32'd1 ;  //
            default : f_evt_width = 32'd0 ;
        endcase
    endfunction

    // ------------------------------------------------
    // RAM instance
    // ------------------------------------------------
    localparam                                 NUMEVT = RAMIDX_TXL0S_RXL0S_OR_L0P_ESM + 8'd1 ; // (edit) Type final RAMIDX
    wire   [NUMEVT-1:0]                        ec_clr_bus ;   // Event counter clear bus
    wire   [32*NUMEVT-1:0]                     ec_cnt_bus ;   // Event counter bus
    wire                                       ec_ram_actreq; // Ram Activation request

    assign ec_clr_all = int_reg_timer_en_pos ;

    assign {ec_en_array[RAMIDX_TXL0S],       ec_cnt_array[RAMIDX_TXL0S]}       = {ec_en[0],  ec_cnt[0]};
    assign {ec_en_array[RAMIDX_RXL0S],       ec_cnt_array[RAMIDX_RXL0S]}       = {ec_en[1],  ec_cnt[1]};
    assign {ec_en_array[RAMIDX_L0],          ec_cnt_array[RAMIDX_L0]}          = {ec_en[2],  ec_cnt[2]};
    assign {ec_en_array[RAMIDX_L1],          ec_cnt_array[RAMIDX_L1]}          = {ec_en[3],  ec_cnt[3]};
    assign {ec_en_array[RAMIDX_L11],         ec_cnt_array[RAMIDX_L11]}         = {ec_en[4],  ec_cnt[4]};
    assign {ec_en_array[RAMIDX_L12],         ec_cnt_array[RAMIDX_L12]}         = {ec_en[5],  ec_cnt[5]};
    assign {ec_en_array[RAMIDX_CFG_RCVRY],   ec_cnt_array[RAMIDX_CFG_RCVRY]}   = {ec_en[6],  ec_cnt[6]};
    assign {ec_en_array[RAMIDX_TXL0S_RXL0S_OR_L0P], ec_cnt_array[RAMIDX_TXL0S_RXL0S_OR_L0P]} = {ec_en[7],  ec_cnt[7]};
    assign {ec_en_array[RAMIDX_L1_AUX],      ec_cnt_array[RAMIDX_L1_AUX]}      = {ec_en[8],  ec_cnt[8]};

    // Set extra bits of array signals to 0
    generate
      for (ii=NUMEVT; ii<MAX_RAM_INDX; ii=ii+1) begin : gen_ec_en_array
        assign ec_en_array[ii] = 1'b0 ;
        assign ec_cnt_array[ii] = 32'd0 ;
      end
    endgenerate

    generate
      for (ii=0; ii<TBA_EVT_TOTAL; ii=ii+1) begin : gen_ecnt_evt
        if ( f_evt_width(ii)>32'd0 ) begin : gen_ecnt_evt_width_if
          cdm_rasdes_ecnt
            #( .INST(INST), .EVT_WDTH(f_evt_width(ii)), .RAM_ENABLE(1'b1), .RAM_DEPTH(`CX_RAS_DES_TBA_RAM_DEPTH))
            u_cdm_rasdes_ecnt (
              .aux_clk                                 (aux_clk),             // input
              .sticky_rst_n                            (sticky_rst_n),        // input
              .ec_type                                 (ec_type[ii]),         // input
              .ec_en                                   (ec_en[ii]),           // input
              .ec_clr                                  (ec_clr[ii]),          // input
              .ec_clr_all                              (ec_clr_all),          // input
              .ec_evt                                  (ec_evt[ii]),          // input [31:0]
              .ec_cnt                                  (ec_cnt[ii])           // output [31:0]
          ) ;
        end else begin : gen_ecnt_evt_width_else
          assign ec_cnt[ii] = {32{1'b0}};
        end
      end
    endgenerate

    // Create bus signals from array to connect them with ram controller
    generate
    for (ii=0; ii<NUMEVT; ii=ii+1) begin : gen_ec_ram_bus
      assign ec_clr_bus[1*ii +: 1] = 1'b0 ;
      assign ec_cnt_bus[32*ii +: 32] = ec_cnt_array[ii] ;
    end
    endgenerate

    assign ec_ram_actreq = int_reg_timer_en_pos | int_reg_timer_en;

    // RAM controller
    cdm_rasdes_ec_ramcont
     #(
        .INST (INST),
        .NUMEVT (NUMEVT),
        .RASDES_RAM_DATA_WIDTH (RASDES_RAM_DATA_WIDTH),
        .RASDES_RAM_ADDR_WIDTH (RASDES_RAM_ADDR_WIDTH)
        ) u_cdm_rasdes_ec_ramcont (
// -------------- Inputs ---------------
        .aux_clk                                   (aux_clk),                                   // input
        .sticky_rst_n                              (sticky_rst_n),                              // input
    // -------------- counter enable ---------------
        .ec_ram_actreq                             (ec_ram_actreq),                             // input  [NUMEVT-1:0]
        .ec_cnt_bus                                (ec_cnt_bus),                                // input  [32*NUMEVT-1:0]
    // -------------- clear control ---------------
        .ec_clr_bus                                (ec_clr_bus),                                // input  [NUMEVT-1:0]
        .ec_clr_all                                (ec_clr_all),                                // input
    //---- RAM I/F -----------------------
        .ec_ram_dataout                            (tba_ram_dataout),                           // input  [RASDES_RAM_DATA_WIDTH-1:0]
    //---- Register read/write access
        .reg_req                                   (reg_req),                                   // input
        .reg_index                                 ((9)'(reg_index)),                           // input  [8:0]
// -------------- Outputs ---------------
    //---- RAM I/F -----------------------
        .ec_ram_ena                                (tba_ram_ena),                               // output
        .ec_ram_wea                                (tba_ram_wea),                               // output
        .ec_ram_addra                              (tba_ram_addra),                             // output [RASDES_RAM_ADDR_WIDTH-1:0]
        .ec_ram_datain                             (tba_ram_datain),                            // output [RASDES_RAM_DATA_WIDTH-1:0]
        .ec_ram_enb                                (tba_ram_enb),                               // output
        .ec_ram_addrb                              (tba_ram_addrb),                             // output [RASDES_RAM_ADDR_WIDTH-1:0]
    //---- Temp counter control ----
        .ec_ram_active                             (ec_ram_active),                             // output
        .ec_ram_add_status                         (ec_ram_add_status[NUMEVT-1:0]),             // output [NUMEVT-1:0]
    //---- Register read/write access ----
        .reg_ack                                   (reg_ack),                                   // output
        .reg_rdata                                 (reg_rdata)                                  // output [31:0]
        ) ;

   assign ec_ram_add_status[MAX_RAM_INDX-1:NUMEVT] = {MAX_RAM_INDX-NUMEVT{1'b0}}; // unconnected

    function automatic [7:0] tba_ram_index (input [7:0] report_sel) ;
        case ( report_sel )
            8'h01   : tba_ram_index = RAMIDX_TXL0S ;
            8'h02   : tba_ram_index = RAMIDX_RXL0S ;
            8'h03   : tba_ram_index = RAMIDX_L0 ;
            8'h04   : tba_ram_index = RAMIDX_L1 ;
            8'h05   : tba_ram_index = RAMIDX_L11 ;
            8'h06   : tba_ram_index = RAMIDX_L12 ;            
            8'h07   : tba_ram_index = RAMIDX_CFG_RCVRY ;
            8'h08   : tba_ram_index = RAMIDX_TXL0S_RXL0S_OR_L0P ;
            8'h09   : tba_ram_index = RAMIDX_L1_AUX ;
            default : tba_ram_index = 8'hFF ;  // Access to reserved space
        endcase
    endfunction

    // ------------------------------------------------
    // RAM Read/Write control
    // ------------------------------------------------
    wire int_reg_read_ram ;
    reg  int_reg_read_ram_1d ;

    assign int_reg_read_ram = (int_reg_read_ram_l || int_reg_read_ram_h) ;

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            int_reg_read_ram_1d <= #TP 1'b0 ;
        end else begin
            int_reg_read_ram_1d <= #TP int_reg_read_ram ;
        end
    end

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            reg_req     <= #TP 1'b0 ;
            reg_index   <= #TP 8'h00 ;
        end else begin
            if ( int_reg_read_ram && !int_reg_read_ram_1d ) begin
                reg_req     <= #TP 1'b1 ;
                reg_index   <= #TP tba_ram_index(int_reg_report_sel) ;
            end else if ( reg_ack ) begin
                reg_req     <= #TP 1'b0 ;
            end
        end
    end

// =============================================================================
// Register Read Operation
// =============================================================================
    wire                               resp_scheduled ;

// spyglass disable_block STARC05-2.11.3.1
// SMD: Combinational and sequential parts of an FSM described in same always block
// SJ: This signal is not used inside this module. This is the interface signal of this module. The sequential signal is unnecessary.
    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_tba_ack <= #TP 2'b00 ;
        end else begin
            case ( cdm_tba_ack )
                2'b00 : begin
                    if ( resp_scheduled ) begin
                        cdm_tba_ack <= #TP 2'b01 ;
                    end
                end
                2'b01 : begin
                    if ( int_reg_read_ram ) begin
                        if ( reg_ack ) cdm_tba_ack <= #TP 2'b10 ;
                    end else begin
                        cdm_tba_ack <= #TP 2'b10 ;
                    end
                end
                2'b10 : begin
                    cdm_tba_ack <= #TP 2'b00 ;
                end
                default : cdm_tba_ack <= #TP 2'b00 ;
            endcase
        end
    end
// spyglass enable_block STARC05-2.11.3.1

    assign resp_scheduled = |cdm_reg_id[6:4] ;

    always @(*) begin : read_data_PROC
        unique case (1'b1)
            cdm_reg_id[4]  : cdm_tba_rdata = {int_reg_0x13, int_reg_0x12, int_reg_0x11, int_reg_0x10};
            cdm_reg_id[5]  : cdm_tba_rdata = {int_reg_0x17, int_reg_0x16, int_reg_0x15, int_reg_0x14};
            cdm_reg_id[6]  : cdm_tba_rdata = {int_reg_0x1b, int_reg_0x1a, int_reg_0x19, int_reg_0x18};
            default        : cdm_tba_rdata = `PCIE_UNUSED_RESPONSE;
        endcase
    end

endmodule //cdm_rasdes_tba_reg 
