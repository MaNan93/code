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
// ---    $Revision: #19 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/include/cxpl_defs.svh#19 $
// -------------------------------------------------------------------------
// --- Module Description:
// ---
// --- This file contains CX-PL implementation-specific defines
// ---
// -----------------------------------------------------------------------------

`ifndef __GUARD__CXPL_DEFS__SVH__
`define __GUARD__CXPL_DEFS__SVH__

    // This constant can be used to pad at the start of packets.
    `define CRC_PASSTHRU 32'h6DD90A9D

    `define TBTP 0.25 // Testbench Clock to Q output delay (simulator safety)

    //
    // Define three technology speeds for configuring core options (additional pipeline stages)
    //
    `define CX_QMODE_STORE_N_FWD        0
    `define CX_QMODE_CUT_THROUGH        1
    `define CX_QMODE_BYPASS             2


    // Now, define parameters that are derived user configuration
    //

    `define CX_UNUSED_RESPONSE          32'b0    // Value device responds with on reads to unused addresses

    // XDLH
    `define ACK_TIMER_WIDTH             14
    `define FC_UPD_FREQ                 12'hEA6 // Flow Control update freq      (30 us)

    // Our L0s exit time in symbol times (if there are other factors beyond NFTS+1SKP, add them into CX_RBUF_ADJUST)
    `define CX_RX_L0S_ADJUST    ((`CX_NFTS+1)*8'd4)
    `define CX_TXL0S_ADJUST     16'd64   // TBD - What is the best estimate for partner's TX L0s Exit time

    //
    // Technology specific parameters
    //


    // LTSSM States
    `define S_DETECT_QUIET              6'h00
    `define S_DETECT_ACT                6'h01
    `define S_POLL_ACTIVE               6'h02
    `define S_POLL_COMPLIANCE           6'h03
    `define S_POLL_CONFIG               6'h04
    `define S_PRE_DETECT_QUIET          6'h05
    `define S_DETECT_WAIT               6'h06
    `define S_CFG_LINKWD_START          6'h07
    `define S_CFG_LINKWD_ACEPT          6'h08
    `define S_CFG_LANENUM_WAIT          6'h09
    `define S_CFG_LANENUM_ACEPT         6'h0A
    `define S_CFG_COMPLETE              6'h0B
    `define S_CFG_IDLE                  6'h0C
    `define S_RCVRY_LOCK                6'h0D
    `define S_RCVRY_SPEED               6'h0E
    `define S_RCVRY_RCVRCFG             6'h0F
    `define S_RCVRY_IDLE                6'h10
    `define S_RCVRY_EQ0                 6'h20
    `define S_RCVRY_EQ1                 6'h21
    `define S_RCVRY_EQ2                 6'h22
    `define S_RCVRY_EQ3                 6'h23
    `define S_L0                        6'h11
    `define S_L0S                       6'h12
    `define S_L123_SEND_EIDLE           6'h13
    `define S_L1_IDLE                   6'h14
    `define S_L2_IDLE                   6'h15
    `define S_L2_WAKE                   6'h16
    `define S_DISABLED_ENTRY            6'h17
    `define S_DISABLED_IDLE             6'h18
    `define S_DISABLED                  6'h19
    `define S_LPBK_ENTRY                6'h1A
    `define S_LPBK_ACTIVE               6'h1B
    `define S_LPBK_EXIT                 6'h1C
    `define S_LPBK_EXIT_TIMEOUT         6'h1D
    `define S_HOT_RESET_ENTRY           6'h1E
    `define S_HOT_RESET                 6'h1F

    // MPCIE
    `define S_CFG_START                 6'h27
    `define S_CFG_SOFTWARE              6'h30
    `define S_CFG_UPDATE                6'h28
    `define S_CFG_CONFIRM               6'h29
    `define S_CFG_EXIT_TO_DETECT        6'h2A
    `define S_RCVRY_ENTRY               6'h24
    `define S_RCVRY_RECONFIG            6'h25
    `define S_RCVRY_COMPLETE            6'h2F
    `define S_RCVRY_EXIT_TO_DETECT      6'h26
    `define S_L1_ENTRY                  6'h2B
    `define S_L1_EXIT                   6'h2C
    `define S_L2_ENTRY                  6'h2D
    `define S_MPTST                     6'h2E

    // Data Link Layer states
    `define S_DL_INACTIVE               2'b00
    `define S_DL_FC_INIT                2'b01
    `define S_DL_FEATURE                2'b10
    `define S_DL_ACTIVE                 2'b11


    // PHY TX command
    `define SEND_IDLE                   4'h1
    `define SEND_EIDLE                  4'h2
    `define XMT_IN_EIDLE                4'h3
    `define SEND_RCVR_DETECT_SEQ        4'h5
    `define SEND_TS1                    4'h6
    `define SEND_TS2                    4'h7
    `define COMPLIANCE_PATTERN          4'h8
    `define SEND_SDS                    4'h9
    `define SEND_BEACON                 4'ha
    `define SEND_N_FTS                  4'hb
    `define NORM                        4'hc
    `define SEND_SKP                    4'hd
    `define MOD_COMPL_PATTERN           4'h4
    `define SEND_EIES                   4'he
    `define SEND_EIES_SYM               4'hf

     //Gen5 SKP and SDS encoding
    `define CX_GEN5_SKP_ENC             8'h99
    `define CX_GEN5_SDS_BODY_ENC        8'h87

     //Gen6 SKP and SDS encoding
    `define CX_GEN6_SDS_BODY_ENC        8'h87

     // Required command for Adapter
    `define RPA_CMD_PHY_INITIAL         3'b000
    `define RPA_CMD_EXIT_H8ALL          3'b001
    `define RPA_CMD_ENTRY_BURST         3'b010
    `define RPA_CMD_EXIT_BURST          3'b011
    `define RPA_CMD_ENTRY_H8RX          3'b100
    `define RPA_CMD_ENTRY_H8TX          3'b101

    // Gen1, 1 UI=0.4ns; Gen2, 1 UI=0.2ns; Gen3, 1 UI=0.125ns, Gen4, 1 UI=0.0625, Gen5, 1 UI=0.03125ns.
    // ESM Rate0 8GT, 1 UI=0.125ns; ESM Rate0 16GT, 1 UI=0.0625ns; ESM Rate1 20GT, 1 UI=0.05ns; ESM Rate1 25GT, 1 UI=0.04ns
    // For DF Gen4/EsmRate0/EsmRate1, all are the same as CX_TIME_GEN3_DF_*UI. E.g. CX_TIME_ESM1_25GT_DF_1280UI = 1280 x 0.04ns = 51.2ns = 51.2ns / 0.32ns(per core_clk) = 160 clocks for `CX_FREQ_VALUE == 0
    // Because EsmRate0 and EsmRate1 are only for DF configurations, so no change to UI is needed for current_data_rate == `Gen3/4 rates corresponding to EsmRate0/1
    // Convert time values to clock cycle
    // Note there are ALWAYS 20UI per cycle in 2s and 10UI per cycle in 1s for Gen1 rate
    // for Gen2 rate, 20UI vs 1s, 40UI vs 2s, 80 UI vs 4s
    // for 128/130 encoding, 8UI per cycle in 1s (have to consider 8GT/s data rate)
    // so for Gen3, 32UI  vs 1s, 64UI  vs 2s, 128UI vs 4s
    //    for Gen4, 64UI  vs 1s, 128UI vs 2s, 256UI vs 4s
    //    for Gen5, 128UI vs 1s, 256UI vs 2s, 512UI vs 4s
    //
    //  CX_FREQ         |  CX_PL_FREQ_VALUE |CX_PL_FREQ_MULTIPLIER| Sness (for Dynamic Width)
    //                  |                   |                     |    Gen1 Gen2 Gen3 Gen4
    //  3 (FREQ_62_5)   |      2            |       4             |     4    8    16   32   (N/A)
    //  2 (FREQ_125)    |      1            |       2             |     2    4    8    16   (N/A to Gen4)
    //  1 (FREQ_250)    |      0            |       1             |     1    2    4    8
    //

    `define     CX_TIME_GEN1_1280UI     (`CX_NB_GEN1==1)? 25'd128 : (`CX_NB_GEN1==2)? 25'd64 : 25'd32  // 1280 x 400ps = 512ns
    `define     CX_TIME_GEN2_1280UI     (`CX_NB_GEN2==1)? 25'd128 : (`CX_NB_GEN2==2)? 25'd64 : 25'd32  // 1280 x 200ps = 256ns
    `define     CX_TIME_GEN3_1280UI     (`CX_NB_GEN3==1)? 25'd160 : (`CX_NB_GEN3==2)? 25'd80 : (`CX_NB_GEN3==4)? 25'd40 : (`CX_NB_GEN3==8)? 25'd20 : 25'd10 // 1280 x 125ps   = 160ns
    `define     CX_TIME_GEN4_1280UI     (`CX_NB_GEN4==2)?  25'd80 : (`CX_NB_GEN4==4)? 25'd40 : (`CX_NB_GEN4==8)? 25'd20 : 25'd10  // 1280 x 62.5ps  =  80ns
    `define     CX_TIME_GEN5_1280UI     (`CX_NB_GEN5==2)?  25'd80 : (`CX_NB_GEN5==4)? 25'd40 : (`CX_NB_GEN5==8)? 25'd20 : 25'd10  // 1280 x 31.25ps =  40ns
    `define     CX_TIME_GEN6_1280UI     (`CX_NB_GEN6==2)?  25'd80 : (`CX_NB_GEN6==4)? 25'd40 : (`CX_NB_GEN6==8)? 25'd20 : (`CX_NB_GEN6==16)? 25'd10 : 25'd5  // 1280 x 15.625ps =  20ns

    `define     CX_TIME_GEN1_2000UI     (`CX_NB_GEN1==1)? 25'd200 : (`CX_NB_GEN1==2)? 25'd100 : 25'd50  // 2000 x 400ps = 800ns
    `define     CX_TIME_GEN2_2000UI     (`CX_NB_GEN2==1)? 25'd200 : (`CX_NB_GEN2==2)? 25'd100 : 25'd50  // 2000 x 200ps = 400ns
    `define     CX_TIME_GEN3_2000UI     (`CX_NB_GEN3==1)? 25'd250 : (`CX_NB_GEN3==2)? 25'd125 : (`CX_NB_GEN3==4)? 25'd63 : (`CX_NB_GEN3==8)? 25'd32 : 25'd16 // 2000 x 125ps   = 250ns
    `define     CX_TIME_GEN4_2000UI     (`CX_NB_GEN4==2)? 25'd125 : (`CX_NB_GEN4==4)?  25'd63 : (`CX_NB_GEN4==8)? 25'd32 : 25'd16  // 2000 x 62.5ps =  125ns
    `define     CX_TIME_GEN5_2000UI     (`CX_NB_GEN5==2)? 25'd125 : (`CX_NB_GEN5==4)?  25'd63 : (`CX_NB_GEN5==8)? 25'd32 : 25'd16  // 2000 x 31.25ps =  62.5ns
    `define     CX_TIME_GEN6_2000UI     (`CX_NB_GEN6==2)? 25'd125 : (`CX_NB_GEN6==4)?  25'd63 : (`CX_NB_GEN6==8)? 25'd32 : (`CX_NB_GEN6==16)? 25'd16 : 25'd8  // 2000 x 15.625ps =  31.25ns

    `define     CX_TIME_GEN1_16000UI     (`CX_NB_GEN1==1)? 25'd1600 : (`CX_NB_GEN1==2)?  25'd800 : 25'd400  // 16000 x 400ps = 6400ns
    `define     CX_TIME_GEN2_16000UI     (`CX_NB_GEN2==1)? 25'd1600 : (`CX_NB_GEN2==2)?  25'd800 : 25'd400  // 16000 x 200ps = 3200ns
    `define     CX_TIME_GEN3_16000UI     (`CX_NB_GEN3==1)? 25'd2000 : (`CX_NB_GEN3==2)? 25'd1000 : (`CX_NB_GEN3==4)? 25'd500 : (`CX_NB_GEN3==8)? 25'd250 :25'd125 // 16000 x 125ps   = 2000ns
    `define     CX_TIME_GEN4_16000UI     (`CX_NB_GEN4==2)? 25'd1000 : (`CX_NB_GEN4==4)?  25'd500 : (`CX_NB_GEN4==8)? 25'd250 : 25'd125  // 16000 x 62.5ps =  1000ns
    `define     CX_TIME_GEN5_16000UI     (`CX_NB_GEN5==2)? 25'd1000 : (`CX_NB_GEN5==4)?  25'd500 : (`CX_NB_GEN5==8)? 25'd250 : 25'd125  // 16000 x 31.25ps =  500ns
    `define     CX_TIME_GEN6_16000UI     (`CX_NB_GEN6==2)? 25'd1000 : (`CX_NB_GEN6==4)?  25'd500 : (`CX_NB_GEN6==8)? 25'd250 : (`CX_NB_GEN6==16)? 25'd125 : 25'd63  // 16000 x 15.625ps =  250ns

    `define     CX_TIME_GEN1_4680UI     (`CX_NB_GEN1==1)? 25'd468 : (`CX_NB_GEN1==2)? 25'd234 : 25'd117  // 4680 x 400ps = 1872ns
    `define     CX_TIME_GEN2_4680UI     (`CX_NB_GEN2==1)? 25'd468 : (`CX_NB_GEN2==2)? 25'd234 : 25'd117  // 4680 x 200ps =  936ns
    `define     CX_TIME_GEN3_4680UI     (`CX_NB_GEN3==1)? 25'd585 : (`CX_NB_GEN3==2)? 25'd293 : (`CX_NB_GEN3==4)? 25'd147 : (`CX_NB_GEN3==8)? 25'd74 : 25'd37 // 4680 x 125ps   = 585ns
    `define     CX_TIME_GEN4_4680UI     (`CX_NB_GEN4==2)? 25'd293 : (`CX_NB_GEN4==4)? 25'd147 : (`CX_NB_GEN4==8)?  25'd74 : 25'd37  // 4680 x 62.5ps  = 292.5ns
    `define     CX_TIME_GEN5_4680UI     (`CX_NB_GEN5==2)? 25'd293 : (`CX_NB_GEN5==4)? 25'd147 : (`CX_NB_GEN5==8)?  25'd74 : 25'd37  // 4680 x 31.25ps = 146.25ns
    `define     CX_TIME_GEN6_4680UI     (`CX_NB_GEN6==2)? 25'd293 : (`CX_NB_GEN6==4)? 25'd147 : (`CX_NB_GEN6==8)?  25'd74 : (`CX_NB_GEN6==16)?  25'd37 : 25'd19  // 4680 x 15.625ps = 73.125ns

    `define     CX_TIME_20NS            (4'd8  / `CX_PL_FREQ_MULTIPLIER)        // 8 x 4ns (1s) = 32ns; (8/2) x 8ns (2s) = 32ns; (8/4) x 16ns (4s) = 32ns. don't use 5.
    `define     CX_TIME_40NS            (25'd12 / `CX_PL_FREQ_MULTIPLIER)        // changed from 10 to 12 for CX_FREQ_MULTIPLIER = 4
    `define     CX_TIME_200NS           (25'd5 * `CX_TIME_40NS)
    `define     CX_TIME_800NS           (25'd20 * `CX_TIME_40NS)

    `define     CX_TIME_1US             (25'h100 / `CX_PL_FREQ_MULTIPLIER)       // TBD: Use binary values (~6% bigger than decimal)
    `define     CX_TIME_6US             (6'd6  * `CX_TIME_1US)
    `define     CX_TIME_10US            (6'd10 * `CX_TIME_1US)
    `define     CX_TIME_16US            (6'd16 * `CX_TIME_1US)
    `define     CX_TIME_50US            (6'd50 * `CX_TIME_1US)
    `define     CX_TIME_100US           (7'd100* `CX_TIME_1US)
    `define     CX_TIME_128US           (8'd128* `CX_TIME_1US) - 1'b1
    `define     CX_TIME_200US           (8'd200* `CX_TIME_1US)
    `define     CX_TIME_500US           (9'd500* `CX_TIME_1US)

    `define     CX_TIME_1MS             (25'h40000 / `CX_PL_FREQ_MULTIPLIER)    // TBD: Use binary values (~6% bigger than decimal)
    `define     CX_TIME_2MS             (6'd2  * `CX_TIME_1MS)
    `define     CX_TIME_3MS             (6'd3  * `CX_TIME_1MS)
    `define     CX_TIME_4MS             (6'd4  * `CX_TIME_1MS)
    `define     CX_TIME_5MS             (6'd5  * `CX_TIME_1MS)
    `define     CX_TIME_8MS             (6'd8  * `CX_TIME_1MS)
    `define     CX_TIME_10MS            (6'd10 * `CX_TIME_1MS)
    `define     CX_TIME_12MS            (6'd12 * `CX_TIME_1MS)
    `define     CX_TIME_16MS            (6'd16 * `CX_TIME_1MS)
    `define     CX_TIME_24MS            (6'd24 * `CX_TIME_1MS)
    `define     CX_TIME_32MS            (6'd32 * `CX_TIME_1MS)
    `define     CX_TIME_48MS            (6'd48 * `CX_TIME_1MS)
    `define     CX_TIME_50MS            (7'd50 * `CX_TIME_1MS)
    `define     CX_TIME_58MS            (7'd58 * `CX_TIME_1MS)
    `define     CX_TIME_64MS            (7'd64 * `CX_TIME_1MS)
    `define     CX_TIME_96MS            (7'd96 * `CX_TIME_1MS)
    `define     CX_TIME_100MS           (7'd100 * `CX_TIME_1MS)
    `define     CX_TIME_108MS           (10'd108 * `CX_TIME_1MS)
    `define     CX_TIME_200MS           (10'd200 * `CX_TIME_1MS)
    `define     CX_TIME_208MS           (10'd208 * `CX_TIME_1MS)
    `define     CX_TIME_400MS           (10'd400 * `CX_TIME_1MS)
    `define     CX_TIME_408MS           (10'd408 * `CX_TIME_1MS)
    `define     CX_TIME_600MS           (10'd600 * `CX_TIME_1MS)
    `define     CX_TIME_608MS           (10'd608 * `CX_TIME_1MS)

    // For SVA with skip interval 
    `define     CX_NB_CLK_GEN1         ( 2500 / `CX_NB_GEN1)
    `define     CX_NB_CLK_GEN2         ( 5000 / `CX_NB_GEN2)
    `define     CX_NB_CLK_GEN3         (10000 / `CX_NB_GEN3)
    `define     CX_NB_CLK_GEN4         (20000 / `CX_NB_GEN4)
    `define     CX_NB_CLK_GEN5         (40000 / `CX_NB_GEN5)
    `define     CX_NB_CLK_GEN6         (80000 / `CX_NB_GEN6)
    `define     CX_TIME_GEN1_DF        1
    `define     CX_TIME_GEN2_DF        (`CX_NB_CLK_GEN2 / `CX_NB_CLK_GEN1)
    `define     CX_TIME_GEN3_DF        (`CX_NB_CLK_GEN3 / `CX_NB_CLK_GEN1)
    `define     CX_TIME_GEN4_DF        (`CX_NB_CLK_GEN4 / `CX_NB_CLK_GEN1)
    `define     CX_TIME_GEN5_DF        (`CX_NB_CLK_GEN5 / `CX_NB_CLK_GEN1)
    `define     CX_TIME_GEN6_DF        (`CX_NB_CLK_GEN6 / `CX_NB_CLK_GEN1)
    // For timer
    `define     CX_TIME_GEN1_DW         ((`CX_NB / `CX_NB_GEN1) * `CX_MAC_GEN1_DT_RATE)
    `define     CX_TIME_GEN2_DW         ((`CX_NB / `CX_NB_GEN2) * `CX_MAC_GEN2_DT_RATE)
    `define     CX_TIME_GEN3_DW         ((`CX_NB / `CX_NB_GEN3) * `CX_MAC_GEN3_DT_RATE)
    `define     CX_TIME_GEN4_DW         ((`CX_NB / `CX_NB_GEN4) * `CX_MAC_GEN4_DT_RATE)
    `define     CX_TIME_GEN5_DW         ((`CX_NB / `CX_NB_GEN5) * `CX_MAC_GEN5_DT_RATE)
    `define     CX_TIME_GEN6_DW         ((`CX_NB / `CX_NB_GEN6) * `CX_MAC_GEN6_DT_RATE)

    // --------------------------------------------------------
    // C-PCIe LTSSM timeouts in fast link mode
    // --------------------------------------------------------
    // Define a short millisecond to speed simulation
    `define     CX_FAST_TIME_1MS        (25'h100 / `CX_PL_FREQ_MULTIPLIER) // ~ 1us      
    `define     CX_FAST_TIME_2MS        (6'd2    * `CX_FAST_TIME_1MS)   // ~ 2us
    `define     CX_FAST_TIME_3MS        (6'd3    * `CX_FAST_TIME_1MS)   // ~ 3us
    `define     CX_FAST_TIME_4MS        (6'd4    * `CX_FAST_TIME_1MS)   // ~ 4us
    `define     CX_FAST_TIME_5MS        (6'd5    * `CX_FAST_TIME_1MS)   // ~ 5us
    `define     CX_FAST_TIME_8MS        (6'd8    * `CX_FAST_TIME_1MS)   // ~ 8us
    `define     CX_FAST_TIME_10MS       (6'd10   * `CX_FAST_TIME_1MS)   // ~ 10us
    `define     CX_FAST_TIME_12MS       (6'd12   * `CX_FAST_TIME_1MS)   // etc.
    `define     CX_FAST_TIME_16MS       (6'd16   * `CX_FAST_TIME_1MS)   // etc.
    `define     CX_FAST_TIME_24MS       (6'd24   * `CX_FAST_TIME_1MS)
    `define     CX_FAST_TIME_32MS       (6'd32   * `CX_FAST_TIME_1MS)
    `define     CX_FAST_TIME_48MS       (6'd48   * `CX_FAST_TIME_1MS)
    `define     CX_FAST_TIME_50MS       (6'd50   * `CX_FAST_TIME_1MS)
    `define     CX_FAST_TIME_58MS       (6'd58   * `CX_FAST_TIME_1MS)
    `define     CX_FAST_TIME_64MS       (7'd64   * `CX_FAST_TIME_1MS)
    `define     CX_FAST_TIME_96MS       (7'd96   * `CX_FAST_TIME_1MS)
    `define     CX_FAST_TIME_100MS      (7'd100  * `CX_FAST_TIME_1MS)
    `define     CX_FAST_TIME_108MS      (10'd108  * `CX_FAST_TIME_1MS)
    `define     CX_FAST_TIME_200MS      (10'd200  * `CX_FAST_TIME_1MS)
    `define     CX_FAST_TIME_208MS      (10'd208  * `CX_FAST_TIME_1MS)
    `define     CX_FAST_TIME_400MS      (10'd400  * `CX_FAST_TIME_1MS)
    `define     CX_FAST_TIME_408MS      (10'd408  * `CX_FAST_TIME_1MS)
    `define     CX_FAST_TIME_600MS      (10'd600  * `CX_FAST_TIME_1MS)
    `define     CX_FAST_TIME_608MS      (10'd608  * `CX_FAST_TIME_1MS)

    // Set values for gen3 rate
    `define     CX_TIME_GEN3_131US      ((`CX_NB_GEN3 == 1) ? 17'h1FFFF  : (`CX_NB_GEN3 == 2) ? 17'hFFFF  : (`CX_NB_GEN3 == 4) ? 17'h7FFF  : (`CX_NB_GEN3 == 8) ? 17'h3FFF  : (`CX_NB_GEN3 == 16) ? 17'h1FFF  : 17'hFFF)
    `define     CX_TIME_GEN3_2MS        ((`CX_NB_GEN3 == 1) ? 22'h1EA000 : (`CX_NB_GEN3 == 2) ? 22'hF5000 : (`CX_NB_GEN3 == 4) ? 22'h7A800 : (`CX_NB_GEN3 == 8) ? 22'h3D400 : (`CX_NB_GEN3 == 16) ? 22'h1EA00 : 22'hF500)
    `define     CX_FAST_TIME_GEN3_2MS   ((`CX_NB_GEN3 == 1) ? 21'h800    : (`CX_NB_GEN3 == 2) ? 21'h400   : (`CX_NB_GEN3 == 4) ? 21'h200   : (`CX_NB_GEN3 == 8) ? 21'h100   : (`CX_NB_GEN3 == 16) ? 21'h80    : 21'h40)
    `define     CX_TIME_GEN3_1US        ((`CX_NB_GEN3 == 1) ? 11'h400    : (`CX_NB_GEN3 == 2) ? 11'h200   : (`CX_NB_GEN3 == 4) ? 11'h100   : (`CX_NB_GEN3 == 8) ? 11'h80    : (`CX_NB_GEN3 == 16) ? 11'h40    : 11'h20)
    `define     CX_TIME_GEN3_500NS      ((`CX_NB_GEN3 == 1) ? 10'h28A    : (`CX_NB_GEN3 == 2) ? 10'h145   : (`CX_NB_GEN3 == 4) ? 10'hA2    : (`CX_NB_GEN3 == 8) ? 10'h51    : (`CX_NB_GEN3 == 16) ? 10'h28    : 10'h14)

    `define     CX_TIME_GEN4_131US      (((`CX_MAX_PCIE_SPEED >= 4) && (`CX_NB_GEN3 == `CX_NB_GEN4)) ? (17'd2 * `CX_TIME_GEN3_131US   ) : `CX_TIME_GEN3_131US   )
    `define     CX_TIME_GEN4_2MS        (((`CX_MAX_PCIE_SPEED >= 4) && (`CX_NB_GEN3 == `CX_NB_GEN4)) ? (21'd2 * `CX_TIME_GEN3_2MS     ) : `CX_TIME_GEN3_2MS     )
    `define     CX_FAST_TIME_GEN4_2MS   (((`CX_MAX_PCIE_SPEED >= 4) && (`CX_NB_GEN3 == `CX_NB_GEN4)) ? (21'd2 * `CX_FAST_TIME_GEN3_2MS) : `CX_FAST_TIME_GEN3_2MS)
    `define     CX_TIME_GEN4_1US        (((`CX_MAX_PCIE_SPEED >= 4) && (`CX_NB_GEN3 == `CX_NB_GEN4)) ? (11'd2 * `CX_TIME_GEN3_1US     ) : `CX_TIME_GEN3_1US     )
    `define     CX_TIME_GEN4_500NS      (((`CX_MAX_PCIE_SPEED >= 4) && (`CX_NB_GEN3 == `CX_NB_GEN4)) ? ( 9'd2 * `CX_TIME_GEN3_500NS   ) : `CX_TIME_GEN3_500NS   )

    `define     CX_TIME_GEN5_131US      (((`CX_MAX_PCIE_SPEED >= 5) && (`CX_NB_GEN4 == `CX_NB_GEN5)) ? (17'd2 * `CX_TIME_GEN4_131US   ) : `CX_TIME_GEN4_131US    )
    `define     CX_TIME_GEN5_2MS        (((`CX_MAX_PCIE_SPEED >= 5) && (`CX_NB_GEN4 == `CX_NB_GEN5)) ? (21'd2 * `CX_TIME_GEN4_2MS     ) : `CX_TIME_GEN4_2MS      )
    `define     CX_FAST_TIME_GEN5_2MS   (((`CX_MAX_PCIE_SPEED >= 5) && (`CX_NB_GEN4 == `CX_NB_GEN5)) ? (21'd2 * `CX_FAST_TIME_GEN4_2MS) : `CX_FAST_TIME_GEN4_2MS )
    `define     CX_TIME_GEN5_1US        (((`CX_MAX_PCIE_SPEED >= 5) && (`CX_NB_GEN4 == `CX_NB_GEN5)) ? (11'd2 * `CX_TIME_GEN4_1US     ) : `CX_TIME_GEN4_1US      )
    `define     CX_TIME_GEN5_500NS      (((`CX_MAX_PCIE_SPEED >= 5) && (`CX_NB_GEN4 == `CX_NB_GEN5)) ? ( 9'd2 * `CX_TIME_GEN4_500NS   ) : `CX_TIME_GEN4_500NS    )

    `define     CX_TIME_GEN6_131US      (((`CX_MAX_PCIE_SPEED >= 6) && (`CX_NB_GEN5 == `CX_NB_GEN6)) ? (17'd2 * `CX_TIME_GEN5_131US   ) : `CX_TIME_GEN5_131US    )
    `define     CX_TIME_GEN6_2MS        (((`CX_MAX_PCIE_SPEED >= 6) && (`CX_NB_GEN5 == `CX_NB_GEN6)) ? (21'd2 * `CX_TIME_GEN5_2MS     ) : `CX_TIME_GEN5_2MS      )
    `define     CX_FAST_TIME_GEN6_2MS   (((`CX_MAX_PCIE_SPEED >= 6) && (`CX_NB_GEN5 == `CX_NB_GEN6)) ? (21'd2 * `CX_FAST_TIME_GEN5_2MS) : `CX_FAST_TIME_GEN5_2MS )
    `define     CX_TIME_GEN6_1US        (((`CX_MAX_PCIE_SPEED >= 6) && (`CX_NB_GEN5 == `CX_NB_GEN6)) ? (11'd2 * `CX_TIME_GEN5_1US     ) : `CX_TIME_GEN5_1US      )
    `define     CX_TIME_GEN6_500NS      (((`CX_MAX_PCIE_SPEED >= 6) && (`CX_NB_GEN5 == `CX_NB_GEN6)) ? ( 9'd2 * `CX_TIME_GEN5_500NS   ) : `CX_TIME_GEN5_500NS    )

    `define     CX_TIME_GEN3_ESM0_8GT_131US       `CX_TIME_GEN3_131US
    `define     CX_TIME_GEN3_ESM0_16GT_131US      `CX_TIME_GEN4_131US
    `define     CX_TIME_GEN3_ESM0_8GT_2MS         `CX_TIME_GEN3_2MS
    `define     CX_TIME_GEN3_ESM0_16GT_2MS        `CX_TIME_GEN4_2MS
    `define     CX_FAST_TIME_GEN3_ESM0_8GT_2MS    `CX_FAST_TIME_GEN3_2MS
    `define     CX_FAST_TIME_GEN3_ESM0_16GT_2MS   `CX_FAST_TIME_GEN4_2MS
    `define     CX_TIME_GEN3_ESM0_8GT_1US         `CX_TIME_GEN3_1US
    `define     CX_TIME_GEN3_ESM0_16GT_1US        `CX_TIME_GEN4_1US
    `define     CX_TIME_GEN3_ESM0_8GT_500NS       `CX_TIME_GEN3_500NS
    `define     CX_TIME_GEN3_ESM0_16GT_500NS      `CX_TIME_GEN4_500NS

    `define     CX_TIME_GEN4_ESM1_20GT_131US      ((`CX_NB_GEN4 == 2) ? 22'h27FAF   : (`CX_NB_GEN4 == 4) ? 22'h13FD7  : (`CX_NB_GEN4 == 8) ? 22'h9FEB   : (`CX_NB_GEN4 == 16) ? 22'h4FF5  : 22'h27FA) // 1 symbol = (1/20)x8 = 0.4ns, 2s = 0.8ns / clock
    `define     CX_TIME_GEN4_ESM1_25GT_131US      ((`CX_NB_GEN4 == 2) ? 22'h31F9F   : (`CX_NB_GEN4 == 4) ? 22'h18FCF  : (`CX_NB_GEN4 == 8) ? 22'hC7E7   : (`CX_NB_GEN4 == 16) ? 22'h63F3  : 22'h31F9) // 1 symbol = (1/25)x8 = 0.32ns, 2s = 0.64ns / clock
    `define     CX_TIME_GEN4_ESM1_20GT_2MS        ((`CX_NB_GEN4 == 2) ? 22'h2625AF  : (`CX_NB_GEN4 == 4) ? 22'h1312D7 : (`CX_NB_GEN4 == 8) ? 22'h9896B  : (`CX_NB_GEN4 == 16) ? 22'h4C4B5 : 22'h2625A)
    `define     CX_TIME_GEN4_ESM1_25GT_2MS        ((`CX_NB_GEN4 == 2) ? 22'h2FAF0F  : (`CX_NB_GEN4 == 4) ? 22'h17D787 : (`CX_NB_GEN4 == 8) ? 22'hBEBC3  : (`CX_NB_GEN4 == 16) ? 25'h5F5E1 : 22'h2FAF0)
    `define     CX_FAST_TIME_GEN4_ESM1_20GT_2MS   ((`CX_NB_GEN4 == 2) ? 22'h9D0     : (`CX_NB_GEN4 == 4) ? 22'h4E8    : (`CX_NB_GEN4 == 8) ? 22'h274    : (`CX_NB_GEN4 == 16) ? 22'h13A    : 22'h9D)
    `define     CX_FAST_TIME_GEN4_ESM1_25GT_2MS   ((`CX_NB_GEN4 == 2) ? 22'hC40     : (`CX_NB_GEN4 == 4) ? 22'h620    : (`CX_NB_GEN4 == 8) ? 22'h310    : (`CX_NB_GEN4 == 16) ? 22'h188    : 22'hC4)
    `define     CX_TIME_GEN4_ESM1_20GT_1US        `CX_FAST_TIME_GEN4_ESM1_20GT_2MS / 2
    `define     CX_TIME_GEN4_ESM1_25GT_1US        `CX_FAST_TIME_GEN4_ESM1_25GT_2MS / 2
    `define     CX_TIME_GEN4_ESM1_20GT_500NS      `CX_TIME_GEN4_ESM1_20GT_1US / 2
    `define     CX_TIME_GEN4_ESM1_25GT_500NS      `CX_TIME_GEN4_ESM1_25GT_1US / 2

    // TLP VECTOR POSITION
    `define     CX_ECRC_ERR_POS        0
    `define     CX_MALF_ERR_POS        1
    `define     CX_CPL_POIS_ERR_POS    2
    `define     CX_WRREQ_POIS__ERR_POS 3

    // Core S-ness
    `define     CX_1S                   4'b0001
    `define     CX_2S                   4'b0010
    `define     CX_4S                   4'b0100
    `define     CX_8S                   4'b1000
    `define     CX_16S                  4'b0000
    `define     CX_32S                  4'b0000

    `define     CX_MAC_SB_WD 1
    `define     CX_MAC_SH_WD 2

    // Number of symbols (bytes) per clock cycle for datak
    `define     CX_NBK                   ((`CX_NB == 1) ? 2 : `CX_NB)

    // one hot encoding bit positions for OS flag signal
    `define OSFLG_SKP_BIT        0
    `define OSFLG_SKPEND_BIT     1
    `define OSFLG_EI_BIT         2
    `define OSFLG_EIE_BIT        3
    `define OSFLG_SDS_BIT        4

    // Assertion and message support
    `define MSGMAX                      300
    `define VECTORMAX                   1024
    `define SEVERITY_FATAL              4'h0
    `define SEVERITY_ERROR              4'h1
    `define SEVERITY_WARN               4'h2
    `define SEVERITY_NOTE               4'h3
    `define SEVERITY_DEBUG              4'h4

    // Filter Rule mask size (max: 48)
    `define CX_N_FLT_MASK               6'd30

    `define CX_GEN3_MIN_TLP_LEN         11'h5           // Minimum TLP Length is 5 DW.
                                                        // STP Token  = 1 DW
                                                        // TLP Header = 3 DW (min)
                                                        // LCRC       = 1 DW

    // Token Finder States
    `define TKF_S_IDL                   9'b000000001    // Idle
    `define TKF_S_EDS                   9'b000000010    // End of Data Stream
    `define TKF_S_EDB                   9'b000000100    // End of Bad TLP
    `define TKF_S_DDP                   9'b000001000    // Data DLLP
    `define TKF_S_END                   9'b000010000    // End of TLP
    `define TKF_S_SDP                   9'b000100000    // Start DLLP
    `define TKF_S_STP                   9'b001000000    // Start TLP
    `define TKF_S_DTP                   9'b010000000    // Data TLP
    `define TKF_S_aEDB                  9'b100000000    // Anticipated End of TLP
    `define TKF_S_NDV                   9'b000000000    // No data valid

    // one hot encoding bit positions
    `define TKF_S_IDL_BIT               0
    `define TKF_S_EDS_BIT               1
    `define TKF_S_EDB_BIT               2
    `define TKF_S_DDP_BIT               3
    `define TKF_S_END_BIT               4
    `define TKF_S_SDP_BIT               5
    `define TKF_S_STP_BIT               6
    `define TKF_S_DTP_BIT               7
    `define TKF_S_aEDB_BIT              8

    `ifndef SYNTHESIS
    // Debugging support

    `define CX_STDIN                    0
    `define CX_STDOUT                   1
    `define CX_STDERR                   2

    `define CX_DEBUG_LEVEL              9               // Debug verbosity 0-9 (9 is most verbose)
    `define CX_DEBUG_FILE               "stdout"        // Control what file debug is printed to

    `define CX_ASSERT                                   // Control assertions
    `define CX_ASSERT_LEVEL             9               // Control what assertions are printed (0-9)
    `define CX_ASSERT_FILE              "stdout"        // Control what file assertions are printed to

    `define CX_COVER_LEVEL              9               // Control what coverage results are printed (0-9)
    `define CX_COVER_FILE               "stdout"        // Control what file results are printed to

    `define CX_MONITOR_LEVEL            9               // Control what monitors are active (0-9)
    `define CX_MONITOR_FILE             "stdout"        // Control what file monitors are printed to

    `endif // SYNTHESIS

    // -------------------------------------------------
    // Beneath are the parameters used to allow customer to program a FC watch dog timer expiration value.
    // This is a prescaled timer. the minimum base timer is 8 us.
    // so default is set to 30*8us = 240us +, - 8 us. The spec. limit is 200 us (-0%, +50%).

    `define CX_SCALED_WDOG_TIMER_EXP_VALUE  5'b11110   // scaled watch dog timer expiration value
    `define CX_SCALED_WDOG_TIMER_PTR_WD     5          // scaled watch dog timer pointer width defined in cxpl_defs.vh
    // -------------------------------------------------

   `define CX_RADM_DIAG_STATUS_BUS_WD   ((`CX_NHQ*(17 + (`CX_NW *32) + `CX_NW + 128)) + ((`CX_NHQ == 2) ? 1 : 0))
   `define CX_XADM_DIAG_STATUS_BUS_WD   (((`CX_NCLIENTS + 2) * 3) + ((`CX_NCLIENTS + 2) * `CX_NVC))
   `define CX_CDM_DIAG_STATUS_BUS_WD    (3 + 3 + 32 + 32 +`CX_NFUNC +4 + `CX_NFUNC + (9*`CX_NFUNC) + `CX_NVC + 9 + `CX_DEVNUM_WD + `CX_BUSNUM_WD)
   `define CX_PM_DIAG_STATUS_BUS_WD     (`CX_NVC + `CX_NVC + 4 + 3)
   `define CX_RTLH_DIAG_STATUS_BUS_WD   15 * `CX_RX_TLP
   `define CX_PHY_LOG_DIAG_STATUS_BUS_WD 1 + 1 + 1 + 1 + 1 + 1 \
                                       + 1 + 1 + 2 + 1 + `CX_NL + `CX_NW \
                                       + `CX_NW + `CX_NW + `CX_NW + `CX_NW + 1 + `CX_NW + (32*`CX_NW)
   `define CX_CXPL_DIAG_STATUS_BUS_WD `CX_PHY_LOG_DIAG_STATUS_BUS_WD \
                                    + `CX_NW + `CX_NW + 1 \
                                    + 1 + 1 + 1 \
                                    + 1 + 1 + 12 + 1 \
                                    + 1 + 1 + 12 \
                                    + `CX_NW + `CX_NW + `CX_NW + `TRGT_DATA_PROT_WD+(32*`CX_NW) + 1 + 1 + 1 \
                                    + `CX_XTLH_XDLH_CTL_WD + `CX_XTLH_XDLH_CTL_WD + `CX_XTLH_XDLH_CTL_WD \
                                    + (32*`CX_NW) + 1 + `CX_RTLH_DIAG_STATUS_BUS_WD
    //   rmlh_inskip_rcv, rmlh_ts_rcv_err, rmlh_ts1_rcvd, rmlh_ts2_rcvd, rmlh_ts_lane_num_is_k237, rmlh_deskew_alignment_err,
    // + rmlh_ts_link_num_is_k237, rmlh_rcvd_lane_rev, rplh_rcvd_idle, rmlh_rcvd_eidle_set, rmlh_lanes_rcving, rplh_rdlh_nak,
    // + rplh_rdlh_dllp_start, rplh_rdlh_tlp_start, rplh_rdlh_pkt_end, rplh_rdlh_pkt_edb, rplh_rdlh_pkt_dv, rplh_rdlh_pkt_err,rplh_rdlh_pkt_data
    // + rdlh_rtlh_tlp_sot, rdlh_rtlh_tlp_eot, rdlh_rtlh_tlp_dv,
    // + xdlh_xmlh_start_link_retrain, rtlh_req_link_retrain, cfg_link_retrain,
    // + rdlh_xdlh_rcvd_nack, rdlh_xdlh_rcvd_ack, rdlh_xdlh_rcvd_acknack_seqnum, rdlh_xdlh_req2send_ack,
    // + rdlh_xdlh_req2send_ack_due2dup, rdlh_xdlh_req2send_nack, rdlh_xdlh_req_acknack_seqnum,
    // + xdlh_xmlh_eot, xdlh_xmlh_stp, xdlh_xmlh_sdp, xdlh_xmlh_data, xmlh_xdlh_halt, lcrc_err_asserted, ecrc_err_asserted,
    // + xtlh_xdlh_sot, xtlh_xdlh_eot, xtlh_xdlh_badeot,
    // + xtlh_xdlh_data, xdlh_xtlh_halt, rtlh_diag_status

    //
    //
    //
    //**********************************
    // IMPORTANT PLEASE READ THIS NOTE
    //**********************************
    //
    //
    // IF you change anything that changes CX_DIAG_STATUS_BUS_WD then ........
    //
    // The description for diag_status_bus MUST be updated in pkg_script/cC_plugin/DatabookToolBox.tcl
    //
    // This description is a LIVE description. Any omissions will impact the live IP-XACT code.
    // 


   `define CX_DIAG_STATUS_BUS_WD   (`CX_RADM_DIAG_STATUS_BUS_WD + `CX_XADM_DIAG_STATUS_BUS_WD + `CX_CDM_DIAG_STATUS_BUS_WD + `CX_PM_DIAG_STATUS_BUS_WD + `CX_CXPL_DIAG_STATUS_BUS_WD)




   `define CX_CXPL_DIAG_CONTROL_BUS_WD  2  // 1 for ECRC, 1 for LCRC
   `define CX_DIAG_CONTROL_BUS_WD       (`CX_CXPL_DIAG_CONTROL_BUS_WD + 1)  // 1 for fast link mode


    //
    // number of bits to create a variable in range 0..n-1
    //
    //  n            | `CX_LOGBASE2(n)
    // --------------|-----------------------------------------------
    //  1..2         | 1
    //  3..4         | 2
    //  5..8         | 3
    //  9..16        | 4
    //  17..32       | 5
    //  33..64       | 6
    //  65..128      | 7
    //  129..256     | 8
    //  257..512     | 9
    //  513..1024    | 10
    //  1025..2048   | 11
    //  2049..4096   | 12
    //  4097..8192   | 13
    //  8193..16384  | 14
    //  16385..32768 | 15
    //  32769...     | 16
    //
    `define CX_LOGBASE2(n) (((n)>32768) ? 16 : (((n)>16384) ? 15 : (((n)>8192) ? 14 : (((n)>4096) ? 13 : (((n)>2048) ? 12 : (((n)>1024) ? 11 : (((n)>512) ? 10 : (((n)>256) ? 9 : (((n)>128) ? 8 : (((n)>64) ? 7 : (((n)>32) ? 6 : (((n)>16) ? 5 : (((n)>8) ? 4 : (((n)>4) ? 3 : (((n)>2) ? 2 : (((n)>1) ? 1 : 1))))))))))))))))

   // rmlh_pkt_finder Range Defines
   // Upper DWORD of Datapath consists of
   // 1s = 4 bytes = {`BYTE3, `BYTE2, `BYTE1, `BYTE0}
   // 2s = 2 words = {`WORD1, `WORD0}
   `define BYTE3 DW_MAX - 1  : DW_MAX - 8
   `define BYTE2 DW_MAX - 9  : DW_MAX - 16
   `define BYTE1 DW_MAX - 17 : DW_MAX - 24
   `define BYTE0 DW_MAX - 25 : DW_MAX - 32
   `define WORD1 DW_MAX - 1  : DW_MAX - 16
   `define WORD0 DW_MAX - 17 : DW_MAX - 32
   `define CX_PL_GEN3_CONTROL_WD        11  // number of bits in the control bus coming out of the Port Logic Gen3 Control Register
   `define CX_PL_GEN3_EQ_CONTROL_WD     31 // number of bits in the control bus coming out of the Port Logic Gen3 EQ Control Register
   `define CX_PL_GEN4_CONTROL_WD        5  // number of bits in the control bus coming out of the Port Logic Gen3 Control Register
   `define CX_PL_GEN5_CONTROL_WD        5  // number of bits in the control bus coming out of the Port Logic Gen5 Control Register
   `define CX_PL_GEN6_CONTROL_WD        5  // number of bits in the control bus coming out of the Port Logic Gen6 Control Register
   `define CX_PL_GEN4_EQ_CONTROL_WD     26 // number of bits in the control bus coming out of the Port Logic Gen4 EQ Control Register
   `define CX_PL_GEN5_EQ_CONTROL_WD     26 // number of bits in the control bus coming out of the Port Logic Gen5 EQ Control Register
   `define CX_PL_GEN6_EQ_CONTROL_WD     26 // number of bits in the control bus coming out of the Port Logic Gen6 EQ Control Register
   `define CX_DIR_CHANGE_CONTROL_WD     18 // number of bits in the control bus coming out of the Port Logic Gen3 Direction Change Control Register
   `define CX_GEN4_DIR_CHANGE_CONTROL_WD 18 // number of bits in the control bus coming out of the Port Logic Gen4 Direction Change Control Register
   `define CX_GEN5_DIR_CHANGE_CONTROL_WD 18 // number of bits in the control bus coming out of the Port Logic Gen5 Direction Change Control Register
   `define CX_GEN6_DIR_CHANGE_CONTROL_WD 22 // number of bits in the control bus coming out of the Port Logic Gen6 Direction Change Control Register
   `define CX_PL_MULTILANE_CONTROL_WD    9  // number of bits in the control bus coming out of the Multi Lane Control Register
   `define CX_L1SUB_CONTROL_WD          24 // number of bits in the control bus coming out of the L1 Substates Ext Capability Register
   `define CX_L1SUB_CONTROL_T_COMM_MODE_RANGE   23:16 // t_common_mode bit field
   `define CX_L1SUB_CONTROL_PCIPM_TRGT_L1SUB_RANGE    15:14 // PCIPM target L1 substate bit field
   `define CX_L1SUB_CONTROL_ASPM_TRGT_L1SUB_RANGE    13:12 // ASPM target L1 substate bit field
   `define CX_L1SUB_CONTROL_T_POWER_ON_RANGE    11:0 // t_power_on range
   `define CX_PL_L1SUB_CONTROL_WD       14 // number of bits in the control bus coming out of the L1 Substates Register in Port Logic
   `define CX_PL_AUX_CLK_FREQ_WD        10
   `define CX_INFO_EI_WD                16
   `define CX_PASID_CONTROL_WD           3 // number of bits in the control bus coming out of the L1 Substates Ext Capability Register
   `define CX_TS_FIELD_CONTROL_WD       56 // number of bits in the control bus coming out of the TS field, {sym7,6,5,4,3,2,1}
   `define CX_CCIX_D2_WD                11 // number of bits in the control bus coming out of CCIX Draft2 spec
   `define CX_LUT_PL_WD                  8 // number of bits in the control bus coming out of Port Logic for the Lane Under test

   // macros used to select the appropriate operation mode in the various instances of the lcrc block
   `define CX_RDLH 0
   `define CX_RTLH 1
   `define CX_XTLH 2
   `define CX_XDLH 3

    `define ECC_ZERO_VALUE 0


       `define CX_PL_L0P_ENABLE
       // temp
       // `define FEC_DEBUG_DISABLE
      `define CX_BAC_WD `CX_NL   // Width of BclokAlignControl signal

    `define CX_PIPE5_SUPPORT_OR_CX_FLIT_MODE_ENABLE

`endif // __GUARD__CXPL_DEFS__SVH__
