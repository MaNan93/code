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
// ---    $DateTime: 2022/04/14 09:36:50 $
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/include/pipe_defines.svh#5 $
// -------------------------------------------------------------------------

`ifndef __GUARD__PIPE_DEFINES__SVH__
`define __GUARD__PIPE_DEFINES__SVH__

// the clock to Q delay of flops
// should be ignored during sysnthesis
  `define CK_Q # 0.1 
// here are the data streams that are bit-reveresed received from PHY (Gen3) 
 `define EIEOS_START 18'b10_00000000_11111111
 `define REVERS_SKP_START_16BIT  16'b10_01010101_010101
 `define REVERS_SKP_16BIT  16'b0101_0101_0101_0101
 `define REVERS_E1_8BIT 8'h87

// K Codes
 `define KCODE_8B_COM 8'hBC // K28.5
 `define KCODE_8B_FTS 8'h3C // K28.1
 `define KCODE_8B_SDP 8'h5C // K28.2
 `define KCODE_8B_IDL 8'h7C //
 `define KCODE_8B_PAD 8'hF7 //
 `define KCODE_8B_STP 8'hFB //
 `define KCODE_8B_END 8'hFD //
 `define KCODE_8B_EDB 8'hFE //
 `define KCODE_8B_SKP 8'h1C // K28.0
 `define KCODE_8B_EIE 8'hFC // K28.7

 `define KCODE_10B_COM 10'h0FA // K28.5
 `define KCODE_10B_FTS 10'h0F9 // K28.1
 `define KCODE_10B_SDP 10'h0F5 // K28.2
 `define KCODE_10B_IDL 10'h0F3 // K28.3
 `define KCODE_10B_SKP 10'h0F4 // K28.0
 `define KCODE_10B_END 10'h2E8 // K29.7

// Gen3 syncheaders
 `define GEN3_2B_DATA_SYNC 2'b10
 `define GEN3_2B_OS_SYNC   2'b01
 `define GEN3_2B_DUM_SYNC   2'b11
 `define GEN3_2B_BODY_SYNC   2'b00
// Gen3 first byte of OSs 
 `define GEN3_8B_SKP       8'hAA
 `define GEN3_8B_TS1       8'h1E
 `define GEN3_8B_TS2       8'h2D
 `define GEN3_8B_EIEOS     8'h00
 `define GEN3_8B_EIOS      8'h66
 `define GEN3_8B_FTS       8'h55
 `define GEN3_8B_SDS       8'hE1
 `define GEN3_8B_CMPL      8'hFF
     
// OS SYMBOL for gen6
 `define GEN6_8B_TS0           8'h33
 `define GEN6_8B_TS1           8'h1B
 `define GEN6_8B_TS2           8'h39
 `define GEN6_8B_FTS           8'h55
 `define GEN6_8B_SDS           8'hB1
 `define GEN6_8B_CMPL          8'hFF
 `define GEN6_DC_BALANCE_SYM_0 8'h00
 `define GEN6_DC_BALANCE_SYM_1 8'hFF
 `define GEN6_32B_EIOS_SYM_0   32'hF00FF00F
 `define GEN6_40B_SKP_SYM_0    40'hF00FF00FF0
 `define GEN6_32B_SKP_SYM_0    32'h0FF00FF0
 `define GEN6_32B_SKP_SYM_END  32'hF000F0FF
 `define GEN6_32B_SKP_SYM_TS0  32'hF0F0F0F0
 `define GEN6_32B_EIEOS_SYM_0  32'h00000000
 `define GEN6_32B_EIEOS_SYM_1  32'h00000000
 `define GEN6_32B_EIEOS_SYM_2  32'hFFFFFFFF
 `define GEN6_32B_EIEOS_SYM_3  32'hFFFFFFFF
 `define GEN6_32B_SDS_SYM_0    32'hC6C6C6B1
 `define GEN6_32B_FTS_SYM_0    32'hC74E4755
 
// Powerdown values
//
 `define PIPE_P0  2'b00
 `define PIPE_P0S 2'b01
 `define PIPE_P1  2'b10
 `define PIPE_P2  2'b11

// RxStatus codes
//
 `define PIPE_RXSTAT_DATA_OK   3'b000
 `define PIPE_RXSTAT_SKP_ADD   3'b001
 `define PIPE_RXSTAT_SKP_REM   3'b010
 `define PIPE_RXSTAT_RX_DET    3'b011
 `define PIPE_RXSTAT_8B10B_ERR 3'b100
 `define PIPE_RXSTAT_BUF_OFLOW 3'b101
 `define PIPE_RXSTAT_BUF_UFLOW 3'b110
 `define PIPE_RXSTAT_DISP_ERR  3'b111

 // Encodings for LOS filter settings
 //
 `define UP8_RX_LOS_FILT_NONE  2'b00
 `define UP8_RX_LOS_FILT_PCIE1 2'b01
 `define UP8_RX_LOS_FILT_PCIE2 2'b10
 `define UP8_RX_LOS_FILT_XAUI  2'b11

  

`endif // __GUARD__PIPE_DEFINES__SVH__
