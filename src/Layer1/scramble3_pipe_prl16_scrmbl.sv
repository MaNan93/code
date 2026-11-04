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
// ---    $Revision: #16 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/scramble3_pipe_prl16_scrmbl.sv#16 $
// -------------------------------------------------------------------------
//
// Description :pipe_prl16_scrmbl take 16-bit data and scramble it base
// on the satate of LFSR the scrambling is done in one cycle
// X^23 + X^21 + X^16 + X^8 + X^5 + X^2 + 1
//
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module scramble3_pipe_prl16_scrmbl
  #(parameter INST                        = 0,
    parameter TP                          = `TP,
    parameter NB                          = `CX_NB,
    parameter SB_WD                       = `CX_MAC_SB_WD,
    parameter SH_WD                       = `CX_MAC_SH_WD,
    parameter AW                          = `CX_ANB_WD,  
    parameter CALC_PARITY_BEFORE_SCRAMBLE = 0,
    parameter REGIN                       = 1,
    parameter REGOUT                      = 1,
    parameter LFSR_REGOUT                 = 0
  , parameter PRECODING_REGOUT            = 0
  , parameter GLAYCODING_REGOUT           = 0
  , parameter DCB_WD = (NB>=8 ? NB/8 : 1)
  )
  (
  input wire                core_clk,
  input wire                core_rst_n,
  input wire                scramble_en,
  input wire [2:0]          current_data_rate,
  input wire                gen6_compliance_sending,
  input wire                int_dataskip,
  input wire                int_txelecidle,
  input wire [SB_WD-1:0]    int_startblock,
  input wire [SH_WD-1:0]    int_syncheader,
  input wire [SB_WD-1:0]    int_ineie,
  input wire [SB_WD-1:0]    int_ints0,
  input wire [SB_WD-1:0]    int_ints1,
  input wire [SB_WD-1:0]    int_ints2,
  input wire                int_dataskip_s1,
  input wire [SB_WD-1:0]    int_ints0_s1,
  input wire [SB_WD-1:0]    int_ints1_s1,
  input wire [SB_WD-1:0]    int_ints2_s1,
  input wire [SB_WD-1:0]    int_inskp_s1,
  input wire [SB_WD-1:0]    int_insds_s1,
  input wire [SB_WD-1:0]    int_ineie_s1,
  input wire [SB_WD-1:0]    int_ineios_s1,
  input wire [1:0]          l0p_in_lfsr_info,
  input wire [22:0]         l0p_in_lfsr_value,
  input wire [SB_WD-1:0]    int_startblock_s1,
  input wire                dc_balance_disable,
  input wire [SB_WD-1:0]    lfsr_load,
  input wire [22:0]         lfsr_load_value,
  input wire [SB_WD-1:0]    lbyte_not_scrmbl,
  input wire [SB_WD-1:0]    lfsr_en,
  input wire [SB_WD-1:0]    wrd_not_scrmbl,
  input wire [(NB*8)-1:0]   in_data,
  input wire [AW-1:0]       active_nb_gen34,
  input wire                precoding_en,
//--- remove start
  output wire [22:0]        lfsr_o,
//---------- end
  output wire [4:0]         l0p_out_lfsr_info,
  output wire [22:0]        l0p_out_lfsr_value,
  output wire [DCB_WD-1:0]  out_dcb_det,
  output wire [(NB*8)-1:0]  out_data,
  output wire [22:0]        out_lfsr,
  output wire [SB_WD-1:0]   out_even_parity
  );

localparam NB_GEN5          = `CX_NB_GEN5;
localparam NB_GEN6          = (NB>=16) ? 8 : NB;
  wire       [22:0]         next_lfsr_pre_8s;
  wire       [22:0]         next_lfsr_pre_4s;
  reg        [22:0]         lfsr;
  wire       [22:0]         next_lfsr;
  wire       [(NB*8)-1:0]   y;
  // Outputs Precoding for Rx
  wire       [(NB*8)-1:0]   int_data_s2;
  wire                      int_dataskip_s2;
  wire       [SB_WD-1:0]    int_ints1_s2;
  wire       [SB_WD-1:0]    int_ints2_s2;
  wire       [SB_WD-1:0]    int_startblock_s2;
  wire       [SB_WD-1:0]    lfsr_en_s2;
  wire       [SB_WD-1:0]    lfsr_load_s2;
  wire       [SB_WD-1:0]    lbyte_not_scrmbl_s2;
  wire       [SB_WD-1:0]    wrd_not_scrmbl_s2;
  wire       [SB_WD-1:0]    int_parity_s2;
  wire       [22:0]         int_lfsr_s2;
  // Outputs Scrambler
  wire       [(NB*8)-1:0]   scr_out_data;
  wire       [(NB*8)-1:0]   int_data_s3;
  wire                      int_dataskip_s3;
  wire       [SB_WD-1:0]    int_ints1_s3;
  wire       [SB_WD-1:0]    int_ints2_s3;
  wire       [SB_WD-1:0]    int_startblock_s3;
  wire       [SB_WD-1:0]    lbyte_not_scrmbl_s3;
  wire       [SB_WD-1:0]    wrd_not_scrmbl_s3;
  wire       [SB_WD-1:0]    int_parity_s3;
  wire       [22:0]         int_lfsr_s3;
  // Outputs Precoding for TX
  wire       [(NB*8)-1:0]   int_out_data;
  wire                      int_dataskip_s4;
  wire       [SB_WD-1:0]    int_ints1_s4;
  wire       [SB_WD-1:0]    int_ints2_s4;
  wire       [SB_WD-1:0]    int_startblock_s4;
  wire       [SB_WD-1:0]    int_parity_s4;
  wire       [22:0]         int_lfsr_s4;
  wire                      current_data_rate_gen6;
  wire       [SB_WD-1:0]    int_ints0_s2;
  wire       [SB_WD-1:0]    int_ints0_s3;
  wire       [SB_WD-1:0]    int_ints0_s4;
  wire       [DCB_WD-1:0]   int_indcb_encoding_s2;
  wire       [DCB_WD-1:0]   int_indcb_encoding_s3;
  wire       [DCB_WD-1:0]   int_indcb_encoding_s4;
  wire                      gen6_num_1s_lrgr_0s;
  wire       [SB_WD-1:0]    int_inskp_s2;
  wire       [SB_WD-1:0]    int_insds_s2;
  wire       [SB_WD-1:0]    int_ineie_s2;
  wire       [SB_WD-1:0]    int_ineios_s2;
  wire       [(NB*8)-1:0]   mux_out_data_d;
  reg        [(NB*8)-1:0]   out_data_d;
  reg        [(NB*8)-1:0]   dc_balance_out_data;
  reg        [9:0]          dc_balance_count;
  reg        [6:0]          count_1s;
  reg        [6:0]          count_1s_d;
  wire       [6:0]          mux_count_1s_d;
  reg        [6:0]          count_0s;
  wire       [4:0]          int_dc_1s_s14_15;
  wire       [4:0]          dc_1s_s14_15;
  reg        [4:0]          dc_1s_s14_15_d;
  wire       [5:0]          count_nb8_1s;
  reg        [5:0]          count_nb8_1s_d;
  wire       [5:0]          mux_count_nb8_1s_d;
  reg        [5:0]          count_nb8_0s;
  wire       [6:0]          balance_1s;
  wire       [6:0]          balance_0s;
  wire       [5:0]          balance_nb8_1s;
  wire       [5:0]          balance_nb8_0s;
  wire       [9:0]          current_balance_1s;
  wire       [9:0]          current_balance_0s;
  wire       [9:0]          int_current_balance_0s;
  wire                      num_1s_lrgr_0s;
  wire                      num_nb8_1s_lrgr_0s;
  reg        [1:0]          replace_15_14;
  reg        [1:0]          latched_replace_15_14;
  wire       [1:0]          int_replace_15_14;
  reg                       dc_sym_1s;
  reg                       dc_sym_0s;
  reg                       latched_dc_sym_1s;
  reg                       latched_dc_sym_0s;
  wire                      int_dc_sym_1s;
  wire                      int_dc_sym_0s;
  wire       [AW-1:0]       mux_int_sym_count;
  wire       [AW-1:0]       int_sym_count;
  reg        [AW-1:0]       pre_sym_count;
  wire       [AW-1:0]       sym_count;
  wire       [6:0]          pam4_count_nb8_1s;
  wire       [6:0]          pam4_count_nb8_0s;
  reg        [6:0]          pam4_count_nb8_1s_d;
  reg        [6:0]          pam4_count_nb8_0s_d;
  wire       [6:0]          pam4_count_nb8_1s_s7s15;
  reg        [6:0]          pam4_count_nb8_1s_s7s15_d;
  wire       [6:0]          pam4_count_nb8_1s_dc_balance_0;
  wire       [6:0]          pam4_count_nb8_1s_dc_balance_1;
  wire       [6:0]          sel_pam4_count_nb8_1s_s7s15_d;
  wire       [6:0]          pam4_count_nb8_0s_s7s15;
  reg        [6:0]          pam4_count_nb8_0s_s7s15_d;
  wire       [6:0]          pam4_count_nb8_0s_dc_balance_0;
  wire       [6:0]          pam4_count_nb8_0s_dc_balance_1;
  wire       [6:0]          sel_pam4_count_nb8_0s_s7s15_d;
  wire       [7:0]          gen6_count_nb8_1s;
  wire       [7:0]          gen6_count_nb8_0s;
  reg        [7:0]          gen6_count_nb8_1s_d;
  reg        [7:0]          gen6_count_nb8_0s_d;
  wire       [7:0]          gen6_balance_nb8_1s;
  wire       [7:0]          gen6_balance_nb8_0s;
  reg                       gen6_dc_sym_1s;
  reg                       gen6_dc_sym_0s;
  reg                       latched_txei;
  wire                      txei_exit;
  reg                       latched_db_syncheader; //Data Block Sync Header
  wire                      db_then_eie_pulse;
  reg                       eie_to_first_ts;
  reg                       eie_to_first_ts_d;

assign current_data_rate_gen6 = (current_data_rate == `GEN6_RATE);
// Scrambler(XMLH:CALC_PARITY_BEFORE_SCRAMBLE==0)
// s1                                       s2                       s3                                      s4
//   +----------+  +-----------+  +--------+  +---------------------+  +-----------+  +---------------------+  +----------+
//   |Precoding |->|Gray Coding|->|PipeLine|->|Scrambler + PipeLine |->|Gray Coding|->|Precoding + PipeLine |->|DC balance|
//   | (Bypass) |  | (Bypass)  |  |(Bypass)|  |           (for 16s) |  |  (Gen6)   |  |            (Option) |  |          |
//   +----------+  +-----------+  +--------+  +---------------------+  +-----------+  +---------------------+  +----------+

// De-crambler(RMLH:CALC_PARITY_BEFORE_SCRAMBLE==1)
// s1                                       s2                       s3                                      s4
//   +----------+  +-----------+  +--------+  +---------------------+  +-----------+  +---------------------+  +----------+
//   |Precoding |->|Gray Coding|->|PipeLine|->|Scrambler + PipeLine |->|Gray Coding|->|Precoding + PipeLine |->|DC balance|
//   |          |  |  (Gen6)   |  |Option  |  |           (for 16s) |  | (Bypass)  |  |     (Bypass)        |  |(Bypass)  |
//   +----------+  +-----------+  +--------+  +---------------------+  +-----------+  +---------------------+  +----------+

generate if (CALC_PARITY_BEFORE_SCRAMBLE==1) begin : gen_rx_precoding_on // RMLH
  // logic below is for Precoding feature on RMLH side(Scrambler).
  // The previous bit used for precoding is set to 1b on every block boundary and gets updated by the last scrambled and precoded bit transmitted within the current block boundary.
  wire       [(NB*8)-1:0]   rx_precoding_out_data;
  wire       [(NB*8)-1:0]   gen5_rx_precoding_out_data;
  reg                       rx_precoding_bit;
  wire                      pre_lfsr_en_s2;
  assign gen5_rx_precoding_out_data = rx_precode_nb(in_data, int_startblock_s1[0], lbyte_not_scrmbl[0], wrd_not_scrmbl[0], rx_precoding_bit, precoding_en);

  always @ (posedge core_clk or negedge core_rst_n) begin : rx_precoding_bit_PROC
      if (!core_rst_n)
          rx_precoding_bit <= #TP '0;
      else begin
          if(~precoding_en || int_dataskip_s1 || ~scramble_en) begin
              rx_precoding_bit <= #TP rx_precoding_bit;
          end else begin
              rx_precoding_bit <= #TP in_data[(NB_GEN5*8-1)];
          end
      end
  end

  // For gen6, the "previous 2-bit" used for precoding is reset to 00b whenever an unscrambled Symbol is sent across.
  reg        [1:0]          gen6_rx_precoding_bit;
  wire       [(NB*8)-1:0]   gen6_rx_precoding_out_data;
  wire       [SB_WD-1:0]    pre_lfsr_load_s2;
  wire       [DCB_WD-1:0]   in_data_dcb_encoding_i;
  wire                      gen6_rx_precoding_bypass = ~precoding_en || gen6_compliance_sending || ~scramble_en;

  assign in_data_dcb_encoding_i[0] = (in_data[(NB-1)*8 +: 8]==`GEN6_DC_BALANCE_SYM_0 || in_data[(NB-1)*8 +: 8]==`GEN6_DC_BALANCE_SYM_1) && ~int_dataskip_s1;
  assign gen6_rx_precoding_out_data = gen6_rx_precode_nb(in_data, lbyte_not_scrmbl[0], wrd_not_scrmbl[0], int_ints0_s1[0], int_ints1_s1[0], int_ints2_s1[0], gen6_rx_precoding_bit, precoding_en && ~gen6_compliance_sending);

  always @ (posedge core_clk or negedge core_rst_n) begin : gen6_rx_precoding_bit_PROC
      if (!core_rst_n)
          gen6_rx_precoding_bit <= #TP '0;
      else begin
          if(int_dataskip_s1) begin
              gen6_rx_precoding_bit <= #TP gen6_rx_precoding_bit;
          end else if(gen6_rx_precoding_bypass || wrd_not_scrmbl[0]) begin
              gen6_rx_precoding_bit <= #TP '0;
          end else begin
              gen6_rx_precoding_bit <= #TP in_data[(NB*8-1) : (NB*8-2)];
          end
      end
  end

  // Gray Coding
  // All scrambled bits on a 2-bit aligned boundary are Gray Coded, when both bits are scrambled at gen6 rate.
  // TS0 Ordered Set Symbols are not Gray Coded. The input 00b, 01b, 10b, 11b becomes 00b, 01b, 11b, and 10b
  wire       [(NB*8)-1:0]   gen6_rx_graycoding_out_data;
  assign gen6_rx_graycoding_out_data = gen6_graycode_nb(1, gen6_rx_precoding_out_data, lbyte_not_scrmbl[0], wrd_not_scrmbl[0], int_ints0_s1[0], int_ints1_s1[0], int_ints2_s1[0]);
  assign rx_precoding_out_data = current_data_rate_gen6 ? gen6_rx_graycoding_out_data : gen5_rx_precoding_out_data;

  // Output registering (optional, Default=1)
  localparam RX_N_DELAY_CYLES = PRECODING_REGOUT;
  localparam RX_DATAPATH_WIDTH = (NB*8) + 1 + SB_WD*(7 + 4) + (SB_WD*1) + DCB_WD;
  localparam RX_RESET_VALUE    = {RX_DATAPATH_WIDTH{1'b0}} ; // The others = 0
  delay_n_w_enable
  
  #(RX_N_DELAY_CYLES, RX_DATAPATH_WIDTH, RX_RESET_VALUE) u_rx_delay(
      .clk        (core_clk),
      .rst_n      (core_rst_n),
      .clear      (1'b0),
      .en         (scramble_en),
      .din        ({rx_precoding_out_data, int_dataskip_s1, int_ints1_s1, int_ints2_s1, int_startblock_s1, lbyte_not_scrmbl   , wrd_not_scrmbl   ,     lfsr_load   , lfsr_en ,int_ints0_s1 ,in_data_dcb_encoding_i ,int_inskp_s1 , int_insds_s1, int_ineie_s1, int_ineios_s1}),
      .dout       ({          int_data_s2, int_dataskip_s2, int_ints1_s2, int_ints2_s2, int_startblock_s2, lbyte_not_scrmbl_s2, wrd_not_scrmbl_s2, pre_lfsr_load_s2, lfsr_en_s2 ,int_ints0_s2 ,int_indcb_encoding_s2 ,int_inskp_s2 , int_insds_s2, int_ineie_s2, int_ineios_s2})
  );
  // If REGIN==0 && CALC_PARITY_BEFORE_SCRAMBLE==1, pipeline added in scramble3_pipe_scrmbl_ctl instead of this module
  assign lfsr_load_s2        = (REGIN==0 && LFSR_REGOUT==0 && CALC_PARITY_BEFORE_SCRAMBLE==1) ? lfsr_load : pre_lfsr_load_s2;
end else begin : gen_rx_precoding_off // XMLH
  assign int_data_s2         = in_data;
  assign int_dataskip_s2     = int_dataskip_s1  ;
  assign int_ints0_s2        = int_ints0_s1;
  assign int_indcb_encoding_s2  = 0;
  assign int_ints1_s2        = int_ints1_s1     ;
  assign int_ints2_s2        = int_ints2_s1     ;
  assign int_inskp_s2        = int_inskp_s1     ;
  assign int_insds_s2        = int_insds_s1     ;
  assign int_ineie_s2        = int_ineie_s1     ;
  assign int_ineios_s2       = int_ineios_s1    ;
  assign int_startblock_s2   = int_startblock_s1;
  assign lbyte_not_scrmbl_s2 = lbyte_not_scrmbl;
  assign wrd_not_scrmbl_s2   = wrd_not_scrmbl;
  assign lfsr_load_s2        = lfsr_load;
  assign lfsr_en_s2          = lfsr_en;
end endgenerate
// Warning-[VCM-TRIMVEC] Too many vectors in condition coverage
//VCS coverage off
  // ---- main    ---------------
  // since this a parallel LFSR we have to caculate the
  // next state of each flop in LFSR based on state of
  // the orginal (X^23 + X^21 + X^16 + X^8 + X^5 + X^2 + 1)
  // when running on a 16-times faster clock

  // NOTE: LFSR does not advance for OS except for SDS which it
  // stops for the entire block. we can set lfsr_en=1'b0 for
  // the  OS which stops the LFSR
  // For other OS in which the first byte should not get scrabmeled
  // but the LFSR should advance we can use lbyte_not_scrmbl=1'b1 to
  // bypass the scrambling of the low byte of the incoming data but
  // let the LFSR advances

    // here is the next_lfsr state after 64 clock cycles (for 64-bit parallel input)
    assign  next_lfsr_pre_8s[0]  = lfsr[7]  ^ lfsr[10] ^ lfsr[0]  ^ lfsr[21] ^ lfsr[3]  ^ lfsr[9]  ^ lfsr[12] ^ lfsr[11] ^ lfsr[14] ^ lfsr[13] ^ lfsr[16] ^ lfsr[15] ^ lfsr[18] ^ lfsr[20] ^ lfsr[22] ;
    assign  next_lfsr_pre_8s[1]  = lfsr[8]  ^ lfsr[11] ^ lfsr[1]  ^ lfsr[22] ^ lfsr[4]  ^ lfsr[10] ^ lfsr[13] ^ lfsr[12] ^ lfsr[15] ^ lfsr[14] ^ lfsr[17] ^ lfsr[16] ^ lfsr[19] ^ lfsr[21] ;
    assign  next_lfsr_pre_8s[2]  = lfsr[2]  ^ lfsr[5]  ^ lfsr[17] ^ lfsr[7]  ^ lfsr[10] ^ lfsr[0]  ^ lfsr[21] ^ lfsr[3]  ;
    assign  next_lfsr_pre_8s[3]  = lfsr[3]  ^ lfsr[0]  ^ lfsr[6]  ^ lfsr[18] ^ lfsr[8]  ^ lfsr[11] ^ lfsr[1]  ^ lfsr[22] ^ lfsr[4] ;
    assign  next_lfsr_pre_8s[4]  = lfsr[4]  ^ lfsr[1]  ^ lfsr[7]  ^ lfsr[19] ^ lfsr[0]  ^ lfsr[9]  ^ lfsr[12] ^ lfsr[2]  ^ lfsr[5] ;
    assign  next_lfsr_pre_8s[5]  = lfsr[5]  ^ lfsr[2]  ^ lfsr[8]  ^ lfsr[1]  ^ lfsr[6]  ^ lfsr[7]  ^ lfsr[21] ^ lfsr[9]  ^ lfsr[12] ^ lfsr[11] ^ lfsr[14] ^ lfsr[16] ^ lfsr[15] ^ lfsr[18] ^ lfsr[22] ;
    assign  next_lfsr_pre_8s[6]  = lfsr[6]  ^ lfsr[3]  ^ lfsr[9]  ^ lfsr[2]  ^ lfsr[7]  ^ lfsr[8]  ^ lfsr[22] ^ lfsr[10] ^ lfsr[13] ^ lfsr[12] ^ lfsr[15] ^ lfsr[17] ^ lfsr[16] ^ lfsr[19] ;
    assign  next_lfsr_pre_8s[7]  = lfsr[7]  ^ lfsr[4]  ^ lfsr[10] ^ lfsr[0]  ^ lfsr[3]  ^ lfsr[8]  ^ lfsr[9]  ^ lfsr[11] ^ lfsr[14] ^ lfsr[13] ^ lfsr[16] ^ lfsr[18] ^ lfsr[17] ^ lfsr[20] ;
    assign  next_lfsr_pre_8s[8]  = lfsr[8]  ^ lfsr[5]  ^ lfsr[1]  ^ lfsr[4]  ^ lfsr[17] ^ lfsr[19] ^ lfsr[7]  ^ lfsr[3]  ^ lfsr[13] ^ lfsr[16] ^ lfsr[20] ^ lfsr[22] ;
    assign  next_lfsr_pre_8s[9]  = lfsr[9]  ^ lfsr[6]  ^ lfsr[2]  ^ lfsr[5]  ^ lfsr[18] ^ lfsr[20] ^ lfsr[0]  ^ lfsr[8]  ^ lfsr[4]  ^ lfsr[14] ^ lfsr[17] ^ lfsr[21] ;
    assign  next_lfsr_pre_8s[10] = lfsr[10] ^ lfsr[7]  ^ lfsr[3]  ^ lfsr[6]  ^ lfsr[19] ^ lfsr[21] ^ lfsr[1]  ^ lfsr[9]  ^ lfsr[5]  ^ lfsr[15] ^ lfsr[18] ^ lfsr[22] ;
    assign  next_lfsr_pre_8s[11] = lfsr[11] ^ lfsr[8]  ^ lfsr[4]  ^ lfsr[7]  ^ lfsr[20] ^ lfsr[22] ^ lfsr[2]  ^ lfsr[10] ^ lfsr[6]  ^ lfsr[16] ^ lfsr[19] ;
    assign  next_lfsr_pre_8s[12] = lfsr[12] ^ lfsr[9]  ^ lfsr[5]  ^ lfsr[8]  ^ lfsr[21] ^ lfsr[3]  ^ lfsr[11] ^ lfsr[7]  ^ lfsr[17] ^ lfsr[20] ;
    assign  next_lfsr_pre_8s[13] = lfsr[13] ^ lfsr[10] ^ lfsr[6]  ^ lfsr[9]  ^ lfsr[22] ^ lfsr[4]  ^ lfsr[12] ^ lfsr[8]  ^ lfsr[18] ^ lfsr[21] ;
    assign  next_lfsr_pre_8s[14] = lfsr[14] ^ lfsr[11] ^ lfsr[7]  ^ lfsr[10] ^ lfsr[5]  ^ lfsr[13] ^ lfsr[9]  ^ lfsr[19] ^ lfsr[22] ;
    assign  next_lfsr_pre_8s[15] = lfsr[15] ^ lfsr[12] ^ lfsr[8]  ^ lfsr[11] ^ lfsr[6]  ^ lfsr[14] ^ lfsr[10] ^ lfsr[20] ;
    assign  next_lfsr_pre_8s[16] = lfsr[10] ^ lfsr[0]  ^ lfsr[3]  ^ lfsr[14] ^ lfsr[18] ^ lfsr[20] ^ lfsr[22] ;
    assign  next_lfsr_pre_8s[17] = lfsr[11] ^ lfsr[1]  ^ lfsr[4]  ^ lfsr[15] ^ lfsr[19] ^ lfsr[21] ;
    assign  next_lfsr_pre_8s[18] = lfsr[0]  ^ lfsr[12] ^ lfsr[2]  ^ lfsr[5]  ^ lfsr[16] ^ lfsr[20] ^ lfsr[22] ;
    assign  next_lfsr_pre_8s[19] = lfsr[1]  ^ lfsr[13] ^ lfsr[3]  ^ lfsr[6]  ^ lfsr[17] ^ lfsr[21] ;
    assign  next_lfsr_pre_8s[20] = lfsr[2]  ^ lfsr[14] ^ lfsr[4]  ^ lfsr[7]  ^ lfsr[18] ^ lfsr[22] ^ lfsr[0]  ;
    assign  next_lfsr_pre_8s[21] = lfsr[5]  ^ lfsr[8]  ^ lfsr[19] ^ lfsr[1]  ^ lfsr[7]  ^ lfsr[10] ^ lfsr[21] ^ lfsr[9]  ^ lfsr[12] ^ lfsr[11] ^ lfsr[14] ^ lfsr[13] ^ lfsr[16] ^ lfsr[18] ^ lfsr[20] ^ lfsr[22] ;
    assign  next_lfsr_pre_8s[22] = lfsr[6]  ^ lfsr[9]  ^ lfsr[20] ^ lfsr[2]  ^ lfsr[8]  ^ lfsr[11] ^ lfsr[22] ^ lfsr[10] ^ lfsr[13] ^ lfsr[12] ^ lfsr[15] ^ lfsr[14] ^ lfsr[17] ^ lfsr[19] ^ lfsr[21] ;
    // here is the next_lfsr state after 32 clock cycles (for 32-bit parallel input)
    assign  next_lfsr_pre_4s[0]  = lfsr[11] ^ lfsr[14] ^ lfsr[21] ^ lfsr[2]  ^ lfsr[13] ^ lfsr[16] ^ lfsr[18] ^ lfsr[20] ^ lfsr[22] ^ lfsr[1] ^ lfsr[3] ;
    assign  next_lfsr_pre_4s[1]  = lfsr[12] ^ lfsr[15] ^ lfsr[22] ^ lfsr[3]  ^ lfsr[14] ^ lfsr[17] ^ lfsr[19] ^ lfsr[21] ^ lfsr[0]  ^ lfsr[2] ^ lfsr[4] ;
    assign  next_lfsr_pre_4s[2]  = lfsr[0]  ^ lfsr[4]  ^ lfsr[15] ^ lfsr[5]  ^ lfsr[11] ^ lfsr[14] ^ lfsr[21] ^ lfsr[2]  ;
    assign  next_lfsr_pre_4s[3]  = lfsr[1]  ^ lfsr[5]  ^ lfsr[16] ^ lfsr[6]  ^ lfsr[12] ^ lfsr[15] ^ lfsr[22] ^ lfsr[3]  ;
    assign  next_lfsr_pre_4s[4]  = lfsr[2]  ^ lfsr[6]  ^ lfsr[17] ^ lfsr[7]  ^ lfsr[13] ^ lfsr[16] ^ lfsr[0]  ^ lfsr[4]  ;
    assign  next_lfsr_pre_4s[5]  = lfsr[7]  ^ lfsr[8]  ^ lfsr[17] ^ lfsr[5]  ^ lfsr[11] ^ lfsr[21] ^ lfsr[2]  ^ lfsr[13] ^ lfsr[16] ^ lfsr[20] ^ lfsr[22] ;
    assign  next_lfsr_pre_4s[6]  = lfsr[8]  ^ lfsr[9]  ^ lfsr[18] ^ lfsr[6]  ^ lfsr[12] ^ lfsr[22] ^ lfsr[3]  ^ lfsr[14] ^ lfsr[17] ^ lfsr[21] ^ lfsr[0]  ;
    assign  next_lfsr_pre_4s[7]  = lfsr[9]  ^ lfsr[10] ^ lfsr[19] ^ lfsr[7]  ^ lfsr[13] ^ lfsr[0]  ^ lfsr[4]  ^ lfsr[15] ^ lfsr[18] ^ lfsr[22] ^ lfsr[1]  ;
    assign  next_lfsr_pre_4s[8]  = lfsr[10] ^ lfsr[8]  ^ lfsr[5]  ^ lfsr[19] ^ lfsr[0]  ^ lfsr[21] ^ lfsr[13] ^ lfsr[18] ^ lfsr[22] ^ lfsr[3]  ;
    assign  next_lfsr_pre_4s[9]  = lfsr[11] ^ lfsr[9]  ^ lfsr[6]  ^ lfsr[20] ^ lfsr[1]  ^ lfsr[22] ^ lfsr[14] ^ lfsr[19] ^ lfsr[0]  ^ lfsr[4]  ;
    assign  next_lfsr_pre_4s[10] = lfsr[12] ^ lfsr[10] ^ lfsr[7]  ^ lfsr[21] ^ lfsr[2]  ^ lfsr[15] ^ lfsr[20] ^ lfsr[1]  ^ lfsr[5]  ;
    assign  next_lfsr_pre_4s[11] = lfsr[13] ^ lfsr[11] ^ lfsr[8]  ^ lfsr[22] ^ lfsr[3]  ^ lfsr[16] ^ lfsr[21] ^ lfsr[2]  ^ lfsr[6]  ;
    assign  next_lfsr_pre_4s[12] = lfsr[14] ^ lfsr[12] ^ lfsr[9]  ^ lfsr[0]  ^ lfsr[4]  ^ lfsr[17] ^ lfsr[22] ^ lfsr[3]  ^ lfsr[7]  ;
    assign  next_lfsr_pre_4s[13] = lfsr[15] ^ lfsr[13] ^ lfsr[10] ^ lfsr[1]  ^ lfsr[5]  ^ lfsr[18] ^ lfsr[0]  ^ lfsr[4]  ^ lfsr[8]  ;
    assign  next_lfsr_pre_4s[14] = lfsr[16] ^ lfsr[14] ^ lfsr[0]  ^ lfsr[11] ^ lfsr[2]  ^ lfsr[6]  ^ lfsr[19] ^ lfsr[1]  ^ lfsr[5]  ^ lfsr[9]  ;
    assign  next_lfsr_pre_4s[15] = lfsr[17] ^ lfsr[15] ^ lfsr[1]  ^ lfsr[12] ^ lfsr[3]  ^ lfsr[7]  ^ lfsr[0]  ^ lfsr[20] ^ lfsr[2]  ^ lfsr[6]  ^ lfsr[10] ;
    assign  next_lfsr_pre_4s[16] = lfsr[4]  ^ lfsr[8]  ^ lfsr[7]  ^ lfsr[14] ^ lfsr[20] ^ lfsr[22] ;
    assign  next_lfsr_pre_4s[17] = lfsr[5]  ^ lfsr[9]  ^ lfsr[8]  ^ lfsr[15] ^ lfsr[21] ;
    assign  next_lfsr_pre_4s[18] = lfsr[6]  ^ lfsr[10] ^ lfsr[9]  ^ lfsr[16] ^ lfsr[0]  ^ lfsr[22] ;
    assign  next_lfsr_pre_4s[19] = lfsr[7]  ^ lfsr[11] ^ lfsr[10] ^ lfsr[17] ^ lfsr[1]  ^ lfsr[0]  ;
    assign  next_lfsr_pre_4s[20] = lfsr[8]  ^ lfsr[12] ^ lfsr[11] ^ lfsr[18] ^ lfsr[2]  ^ lfsr[1]  ;
    assign  next_lfsr_pre_4s[21] = lfsr[9]  ^ lfsr[12] ^ lfsr[19] ^ lfsr[0]  ^ lfsr[11] ^ lfsr[14] ^ lfsr[21] ^ lfsr[16] ^ lfsr[18] ^ lfsr[20] ^ lfsr[22] ^ lfsr[1] ;
    assign  next_lfsr_pre_4s[22] = lfsr[10] ^ lfsr[13] ^ lfsr[20] ^ lfsr[1]  ^ lfsr[12] ^ lfsr[15] ^ lfsr[22] ^ lfsr[17] ^ lfsr[19] ^ lfsr[21] ^ lfsr[0] ^ lfsr[2] ;
//VCS coverage on

    assign  next_lfsr =
                        (active_nb_gen34[3]) ? next_lfsr_pre_8s :
                        (active_nb_gen34[2]) ? next_lfsr_pre_4s :
                        0;

  // we always need to advance the LFSR unless lfsr_en=1'b0
  // and that happens for the entire SKP OS which is a mutiple
  // of words therefore LFSR should always take the next_lfsr
  // unless it is totally disabled
  always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
      lfsr <= #TP '0;
    end else if (l0p_in_lfsr_info[0]) begin // In l0p progress
        if(l0p_in_lfsr_info[1]) // load
            lfsr <= #TP l0p_in_lfsr_value;
        else if(int_dataskip_s2) // keep
            lfsr <= #TP lfsr;
        else if(int_inskp_s2) // load when skp detection
            lfsr <= #TP (int_startblock_s2) ? l0p_in_lfsr_value : lfsr;
        else if(lfsr_load_s2[0] && CALC_PARITY_BEFORE_SCRAMBLE==0) // load at last symbol in eios on only tx side
            lfsr <= #TP l0p_in_lfsr_value;
        else begin // advance nb including eieos
            lfsr <= #TP  next_lfsr;
        end
    end else if (lfsr_load_s2[0]) begin
      lfsr <= #TP lfsr_load_value;
    end else if (|lfsr_en_s2) begin
      lfsr <= #TP  next_lfsr;
    end
  end

assign l0p_out_lfsr_info = (~int_dataskip_s2 && int_startblock_s2) ? {int_ineios_s2, int_ineie_s2, int_insds_s2, lfsr_en_s2, ~lfsr_en_s2} : 0; //{eios, eieos, sdsos, advanced, load}
assign l0p_out_lfsr_value = lfsr;

//----- Remove start
  // LFSR value aligned with an input timing on scramble3_skip_align module
  localparam TMP_LFSR_N_DELAY_CYLES  = (REGOUT + LFSR_REGOUT + PRECODING_REGOUT + GLAYCODING_REGOUT);
  localparam LFSR_N_DELAY_CYLES  = (CALC_PARITY_BEFORE_SCRAMBLE==0 && TMP_LFSR_N_DELAY_CYLES>=2) ? (TMP_LFSR_N_DELAY_CYLES - 1) : 0;
  localparam LFSR_DATAPATH_WIDTH = 23;
  localparam LFSR_RESET_VALUE    = {(LFSR_DATAPATH_WIDTH){1'b0}} ;
  delay_n_w_enable
  
  #(LFSR_N_DELAY_CYLES, LFSR_DATAPATH_WIDTH, LFSR_RESET_VALUE) u_lfsr_delay(
      .clk        (core_clk),
      .rst_n      (core_rst_n),
      .clear      (1'b0),
      .en         (scramble_en),
      .din        (lfsr),
      .dout       (lfsr_o)
  );
//--------- end
// Warning-[VCM-TRIMVEC] Too many vectors in condition coverage
//VCS coverage off
    // LFSR output which should be XORed with the input data
    assign y[0]  = lfsr[22] ;
    assign y[1]  = lfsr[21] ;
    assign y[2]  = lfsr[20] ^ lfsr[22] ;
    assign y[3]  = lfsr[19] ^ lfsr[21] ;
    assign y[4]  = lfsr[18] ^ lfsr[20] ^ lfsr[22] ;
    assign y[5]  = lfsr[17] ^ lfsr[19] ^ lfsr[21] ;
    assign y[6]  = lfsr[16] ^ lfsr[18] ^ lfsr[20] ^ lfsr[22] ;
    assign y[7]  = lfsr[15] ^ lfsr[22] ^ lfsr[17] ^ lfsr[19] ^ lfsr[21] ;
    assign y[8]  = lfsr[14] ^ lfsr[21] ^ lfsr[16] ^ lfsr[18] ^ lfsr[20] ^ lfsr[22] ;
    assign y[9]  = lfsr[13] ^ lfsr[20] ^ lfsr[15] ^ lfsr[17] ^ lfsr[19] ^ lfsr[21] ;
    assign y[10] = lfsr[12] ^ lfsr[19] ^ lfsr[14] ^ lfsr[16] ^ lfsr[18] ^ lfsr[20] ^ lfsr[22] ;
    assign y[11] = lfsr[11] ^ lfsr[18] ^ lfsr[22] ^ lfsr[13] ^ lfsr[15] ^ lfsr[17] ^ lfsr[19] ^ lfsr[21] ;
    assign y[12] = lfsr[10] ^ lfsr[17] ^ lfsr[21] ^ lfsr[12] ^ lfsr[14] ^ lfsr[16] ^ lfsr[18] ^ lfsr[20] ^ lfsr[22] ;
    assign y[13] = lfsr[9]  ^ lfsr[16] ^ lfsr[20] ^ lfsr[11] ^ lfsr[13] ^ lfsr[15] ^ lfsr[17] ^ lfsr[19] ^ lfsr[21] ;
    assign y[14] = lfsr[8]  ^ lfsr[15] ^ lfsr[19] ^ lfsr[10] ^ lfsr[12] ^ lfsr[14] ^ lfsr[16] ^ lfsr[18] ^ lfsr[20] ;
    assign y[15] = lfsr[7]  ^ lfsr[14] ^ lfsr[18] ^ lfsr[9]  ^ lfsr[11] ^ lfsr[13] ^ lfsr[15] ^ lfsr[17] ^ lfsr[19] ;
    assign y[16] = lfsr[6]  ^ lfsr[13] ^ lfsr[17] ^ lfsr[8]  ^ lfsr[10] ^ lfsr[12] ^ lfsr[14] ^ lfsr[16] ^ lfsr[18] ;
    assign y[17] = lfsr[5]  ^ lfsr[12] ^ lfsr[16] ^ lfsr[7]  ^ lfsr[9]  ^ lfsr[11] ^ lfsr[13] ^ lfsr[15] ^ lfsr[17] ;
    assign y[18] = lfsr[4]  ^ lfsr[11] ^ lfsr[15] ^ lfsr[6]  ^ lfsr[8]  ^ lfsr[10] ^ lfsr[12] ^ lfsr[14] ^ lfsr[16] ;
    assign y[19] = lfsr[3]  ^ lfsr[10] ^ lfsr[14] ^ lfsr[5]  ^ lfsr[7]  ^ lfsr[9]  ^ lfsr[11] ^ lfsr[13] ^ lfsr[15] ;
    assign y[20] = lfsr[2]  ^ lfsr[22] ^ lfsr[9]  ^ lfsr[13] ^ lfsr[4]  ^ lfsr[6]  ^ lfsr[8]  ^ lfsr[10] ^ lfsr[12] ^ lfsr[14] ;
    assign y[21] = lfsr[1]  ^ lfsr[21] ^ lfsr[8]  ^ lfsr[12] ^ lfsr[3]  ^ lfsr[5]  ^ lfsr[7]  ^ lfsr[9]  ^ lfsr[11] ^ lfsr[13] ;
    assign y[22] = lfsr[0]  ^ lfsr[20] ^ lfsr[7]  ^ lfsr[11] ^ lfsr[2]  ^ lfsr[22] ^ lfsr[4]  ^ lfsr[6]  ^ lfsr[8]  ^ lfsr[10] ^ lfsr[12] ;
    assign y[23] = lfsr[19] ^ lfsr[22] ^ lfsr[6]  ^ lfsr[10] ^ lfsr[1]  ^ lfsr[21] ^ lfsr[3]  ^ lfsr[5]  ^ lfsr[7]  ^ lfsr[9]  ^ lfsr[11] ;
    assign y[24] = lfsr[18] ^ lfsr[21] ^ lfsr[5]  ^ lfsr[9]  ^ lfsr[0]  ^ lfsr[20] ^ lfsr[2]  ^ lfsr[4]  ^ lfsr[6]  ^ lfsr[8]  ^ lfsr[10] ;
    assign y[25] = lfsr[17] ^ lfsr[20] ^ lfsr[4]  ^ lfsr[8]  ^ lfsr[19] ^ lfsr[22] ^ lfsr[1]  ^ lfsr[3]  ^ lfsr[5]  ^ lfsr[7]  ^ lfsr[9] ;
    assign y[26] = lfsr[16] ^ lfsr[19] ^ lfsr[3]  ^ lfsr[7]  ^ lfsr[18] ^ lfsr[21] ^ lfsr[0]  ^ lfsr[2]  ^ lfsr[4]  ^ lfsr[6]  ^ lfsr[8] ;
    assign y[27] = lfsr[15] ^ lfsr[18] ^ lfsr[2]  ^ lfsr[6]  ^ lfsr[17] ^ lfsr[20] ^ lfsr[22] ^ lfsr[1]  ^ lfsr[3]  ^ lfsr[5]  ^ lfsr[7] ;
    assign y[28] = lfsr[14] ^ lfsr[17] ^ lfsr[1]  ^ lfsr[5]  ^ lfsr[16] ^ lfsr[19] ^ lfsr[21] ^ lfsr[0]  ^ lfsr[2]  ^ lfsr[4]  ^ lfsr[6] ;
    assign y[29] = lfsr[13] ^ lfsr[16] ^ lfsr[0]  ^ lfsr[4]  ^ lfsr[15] ^ lfsr[18] ^ lfsr[20] ^ lfsr[22] ^ lfsr[1]  ^ lfsr[3]  ^ lfsr[5] ;
    assign y[30] = lfsr[12] ^ lfsr[15] ^ lfsr[22] ^ lfsr[3]  ^ lfsr[14] ^ lfsr[17] ^ lfsr[19] ^ lfsr[21] ^ lfsr[0]  ^ lfsr[2]  ^ lfsr[4] ;
    assign y[31] = lfsr[11] ^ lfsr[14] ^ lfsr[21] ^ lfsr[2]  ^ lfsr[13] ^ lfsr[16] ^ lfsr[18] ^ lfsr[20] ^ lfsr[22] ^ lfsr[1]  ^ lfsr[3] ;
    assign y[32] = lfsr[10] ^ lfsr[13] ^ lfsr[20] ^ lfsr[1]  ^ lfsr[12] ^ lfsr[15] ^ lfsr[22] ^ lfsr[17] ^ lfsr[19] ^ lfsr[21] ^ lfsr[0]  ^ lfsr[2] ;
    assign y[33] = lfsr[9]  ^ lfsr[12] ^ lfsr[19] ^ lfsr[0]  ^ lfsr[11] ^ lfsr[14] ^ lfsr[21] ^ lfsr[16] ^ lfsr[18] ^ lfsr[20] ^ lfsr[22] ^ lfsr[1] ;
    assign y[34] = lfsr[8]  ^ lfsr[11] ^ lfsr[18] ^ lfsr[10] ^ lfsr[13] ^ lfsr[20] ^ lfsr[15] ^ lfsr[22] ^ lfsr[17] ^ lfsr[19] ^ lfsr[21] ^ lfsr[0] ;
    assign y[35] = lfsr[7]  ^ lfsr[10] ^ lfsr[17] ^ lfsr[9]  ^ lfsr[12] ^ lfsr[19] ^ lfsr[14] ^ lfsr[21] ^ lfsr[16] ^ lfsr[18] ^ lfsr[20] ^ lfsr[22] ;
    assign y[36] = lfsr[6]  ^ lfsr[9]  ^ lfsr[16] ^ lfsr[8]  ^ lfsr[11] ^ lfsr[18] ^ lfsr[13] ^ lfsr[20] ^ lfsr[15] ^ lfsr[17] ^ lfsr[19] ^ lfsr[21] ;
    assign y[37] = lfsr[5]  ^ lfsr[8]  ^ lfsr[15] ^ lfsr[7]  ^ lfsr[10] ^ lfsr[17] ^ lfsr[12] ^ lfsr[19] ^ lfsr[14] ^ lfsr[16] ^ lfsr[18] ^ lfsr[20] ^ lfsr[22] ;
    assign y[38] = lfsr[4]  ^ lfsr[7]  ^ lfsr[14] ^ lfsr[22] ^ lfsr[6]  ^ lfsr[9]  ^ lfsr[16] ^ lfsr[11] ^ lfsr[18] ^ lfsr[13] ^ lfsr[15] ^ lfsr[17] ^ lfsr[19] ^ lfsr[21] ;
    assign y[39] = lfsr[3]  ^ lfsr[6]  ^ lfsr[13] ^ lfsr[21] ^ lfsr[5]  ^ lfsr[8]  ^ lfsr[15] ^ lfsr[10] ^ lfsr[17] ^ lfsr[12] ^ lfsr[14] ^ lfsr[16] ^ lfsr[18] ^ lfsr[20] ;
    assign y[40] = lfsr[2]  ^ lfsr[5]  ^ lfsr[12] ^ lfsr[20] ^ lfsr[4]  ^ lfsr[7]  ^ lfsr[14] ^ lfsr[9]  ^ lfsr[16] ^ lfsr[11] ^ lfsr[13] ^ lfsr[15] ^ lfsr[17] ^ lfsr[19] ;
    assign y[41] = lfsr[1]  ^ lfsr[4]  ^ lfsr[11] ^ lfsr[22] ^ lfsr[19] ^ lfsr[3]  ^ lfsr[6]  ^ lfsr[13] ^ lfsr[8]  ^ lfsr[15] ^ lfsr[10] ^ lfsr[12] ^ lfsr[14] ^ lfsr[16 ]^ lfsr[18] ;
    assign y[42] = lfsr[0]  ^ lfsr[3]  ^ lfsr[10] ^ lfsr[21] ^ lfsr[18] ^ lfsr[2]  ^ lfsr[5]  ^ lfsr[12] ^ lfsr[7]  ^ lfsr[14] ^ lfsr[9]  ^ lfsr[11] ^ lfsr[13] ^ lfsr[15] ^ lfsr[17] ;
    assign y[43] = lfsr[2]  ^ lfsr[9]  ^ lfsr[20] ^ lfsr[17] ^ lfsr[1]  ^ lfsr[4]  ^ lfsr[11] ^ lfsr[6]  ^ lfsr[13] ^ lfsr[8]  ^ lfsr[10] ^ lfsr[12] ^ lfsr[14] ^ lfsr[16] ;
    assign y[44] = lfsr[1]  ^ lfsr[8]  ^ lfsr[19] ^ lfsr[16] ^ lfsr[22] ^ lfsr[0]  ^ lfsr[3]  ^ lfsr[10] ^ lfsr[5]  ^ lfsr[12] ^ lfsr[7]  ^ lfsr[9]  ^ lfsr[11] ^ lfsr[13] ^ lfsr[15] ;
    assign y[45] = lfsr[0]  ^ lfsr[7]  ^ lfsr[18] ^ lfsr[15] ^ lfsr[21] ^ lfsr[2]  ^ lfsr[9]  ^ lfsr[4]  ^ lfsr[11] ^ lfsr[6]  ^ lfsr[8]  ^ lfsr[10] ^ lfsr[12] ^ lfsr[14] ;
    assign y[46] = lfsr[6]  ^ lfsr[17] ^ lfsr[14] ^ lfsr[20] ^ lfsr[1]  ^ lfsr[8]  ^ lfsr[3]  ^ lfsr[10] ^ lfsr[5]  ^ lfsr[7]  ^ lfsr[9]  ^ lfsr[11] ^ lfsr[13] ;
    assign y[47] = lfsr[5]  ^ lfsr[16] ^ lfsr[13] ^ lfsr[19] ^ lfsr[0]  ^ lfsr[7]  ^ lfsr[2]  ^ lfsr[9]  ^ lfsr[4]  ^ lfsr[6]  ^ lfsr[8]  ^ lfsr[10] ^ lfsr[12] ;
    assign y[48] = lfsr[4]  ^ lfsr[22] ^ lfsr[15] ^ lfsr[12] ^ lfsr[18] ^ lfsr[6]  ^ lfsr[1]  ^ lfsr[8]  ^ lfsr[3]  ^ lfsr[5]  ^ lfsr[7]  ^ lfsr[9]  ^ lfsr[11] ;
    assign y[49] = lfsr[3]  ^ lfsr[21] ^ lfsr[14] ^ lfsr[11] ^ lfsr[17] ^ lfsr[5]  ^ lfsr[0]  ^ lfsr[7]  ^ lfsr[2]  ^ lfsr[4]  ^ lfsr[6]  ^ lfsr[8]  ^ lfsr[10] ;
    assign y[50] = lfsr[2]  ^ lfsr[20] ^ lfsr[13] ^ lfsr[10] ^ lfsr[16] ^ lfsr[4]  ^ lfsr[22] ^ lfsr[6]  ^ lfsr[1]  ^ lfsr[3]  ^ lfsr[5]  ^ lfsr[7]  ^ lfsr[9]  ;
    assign y[51] = lfsr[1]  ^ lfsr[19] ^ lfsr[22] ^ lfsr[12] ^ lfsr[9]  ^ lfsr[15] ^ lfsr[3]  ^ lfsr[21] ^ lfsr[5]  ^ lfsr[0]  ^ lfsr[2]  ^ lfsr[4]  ^ lfsr[6]  ^ lfsr[8] ;
    assign y[52] = lfsr[0]  ^ lfsr[18] ^ lfsr[21] ^ lfsr[11] ^ lfsr[8]  ^ lfsr[14] ^ lfsr[2]  ^ lfsr[20] ^ lfsr[4]  ^ lfsr[22] ^ lfsr[1]  ^ lfsr[3]  ^ lfsr[5]  ^ lfsr[7] ;
    assign y[53] = lfsr[17] ^ lfsr[20] ^ lfsr[10] ^ lfsr[7]  ^ lfsr[13] ^ lfsr[1]  ^ lfsr[19] ^ lfsr[22] ^ lfsr[3]  ^ lfsr[21] ^ lfsr[0]  ^ lfsr[2]  ^ lfsr[4]  ^ lfsr[6] ;
    assign y[54] = lfsr[16] ^ lfsr[19] ^ lfsr[9]  ^ lfsr[6]  ^ lfsr[12] ^ lfsr[0]  ^ lfsr[18] ^ lfsr[21] ^ lfsr[2]  ^ lfsr[20] ^ lfsr[22] ^ lfsr[1]  ^ lfsr[3]  ^ lfsr[5] ;
    assign y[55] = lfsr[15] ^ lfsr[18] ^ lfsr[8]  ^ lfsr[5]  ^ lfsr[11] ^ lfsr[17] ^ lfsr[20] ^ lfsr[1]  ^ lfsr[19] ^ lfsr[22] ^ lfsr[21] ^ lfsr[0]  ^ lfsr[2]  ^ lfsr[4] ;
    assign y[56] = lfsr[14] ^ lfsr[17] ^ lfsr[7]  ^ lfsr[4]  ^ lfsr[10] ^ lfsr[16] ^ lfsr[19] ^ lfsr[0]  ^ lfsr[18] ^ lfsr[21] ^ lfsr[20] ^ lfsr[22] ^ lfsr[1]  ^ lfsr[3] ;
    assign y[57] = lfsr[13] ^ lfsr[16] ^ lfsr[6]  ^ lfsr[3]  ^ lfsr[9]  ^ lfsr[15] ^ lfsr[18] ^ lfsr[17] ^ lfsr[20] ^ lfsr[19] ^ lfsr[22] ^ lfsr[21] ^ lfsr[0]  ^ lfsr[2] ;
    assign y[58] = lfsr[12] ^ lfsr[15] ^ lfsr[5]  ^ lfsr[2]  ^ lfsr[8]  ^ lfsr[14] ^ lfsr[17] ^ lfsr[16] ^ lfsr[19] ^ lfsr[18] ^ lfsr[21] ^ lfsr[20] ^ lfsr[1]  ;
    assign y[59] = lfsr[11] ^ lfsr[14] ^ lfsr[4]  ^ lfsr[1]  ^ lfsr[7]  ^ lfsr[13] ^ lfsr[16] ^ lfsr[15] ^ lfsr[18] ^ lfsr[17] ^ lfsr[20] ^ lfsr[19] ^ lfsr[22] ^ lfsr[0] ;
    assign y[60] = lfsr[10] ^ lfsr[13] ^ lfsr[3]  ^ lfsr[0]  ^ lfsr[6]  ^ lfsr[12] ^ lfsr[15] ^ lfsr[14] ^ lfsr[17] ^ lfsr[16] ^ lfsr[19] ^ lfsr[18] ^ lfsr[21] ;
    assign y[61] = lfsr[9]  ^ lfsr[12] ^ lfsr[2]  ^ lfsr[5]  ^ lfsr[11] ^ lfsr[14] ^ lfsr[13] ^ lfsr[16] ^ lfsr[15] ^ lfsr[18] ^ lfsr[17] ^ lfsr[20] ^ lfsr[22] ;
    assign y[62] = lfsr[8]  ^ lfsr[11] ^ lfsr[1]  ^ lfsr[22] ^ lfsr[4]  ^ lfsr[10] ^ lfsr[13] ^ lfsr[12] ^ lfsr[15] ^ lfsr[14] ^ lfsr[17] ^ lfsr[16] ^ lfsr[19] ^ lfsr[21] ;
    assign y[63] = lfsr[7]  ^ lfsr[10] ^ lfsr[0]  ^ lfsr[21] ^ lfsr[3]  ^ lfsr[9]  ^ lfsr[12] ^ lfsr[11] ^ lfsr[14] ^ lfsr[13] ^ lfsr[16] ^ lfsr[15] ^ lfsr[18] ^ lfsr[20] ^ lfsr[22] ;
//VCS coverage on

  // depending on lbyte_not_scrmbl we scramble the entire word or just
  // the hight byte of the incoming data
  // we do not scramble the data if wrd_not_scrmbl=1'b0
    wire       [(NB*8)-1:0]   pre_scr_out_data;
    assign pre_scr_out_data = int_data_s2 ^ y;

    // All even bits for TS0-OSs are bypassed
    assign scr_out_data[7:0] = (wrd_not_scrmbl_s2[0] || lbyte_not_scrmbl_s2[0]) ? int_data_s2[7:0] :
                               (int_ints0_s2[0])                                ? gen6_ts0_force_even_bit(pre_scr_out_data[7:0]):
                                                                                  pre_scr_out_data[7:0];
    wire int_active_nb_2s = |active_nb_gen34[AW-1:1];
    assign scr_out_data[15:8] = (wrd_not_scrmbl_s2[0] || !int_active_nb_2s)  ? int_data_s2[15:8] :
                                (int_ints0_s2[0])                            ? gen6_ts0_force_even_bit(pre_scr_out_data[15:8]):
                                                                               pre_scr_out_data[15:8];
    wire int_active_nb_4s = |active_nb_gen34[AW-1:2];
    assign scr_out_data[31:16] = (wrd_not_scrmbl_s2[0] || !int_active_nb_4s) ? int_data_s2[31:16] :
                                 (int_ints0_s2[0])                           ? {gen6_ts0_force_even_bit(pre_scr_out_data[31:24]), gen6_ts0_force_even_bit(pre_scr_out_data[23:16])} :
                                                                               pre_scr_out_data[31:16];
    wire int_active_nb_8s = |active_nb_gen34[AW-1:3];
    assign scr_out_data[55:32] = (wrd_not_scrmbl_s2[0] || !int_active_nb_8s)  ? int_data_s2[55:32] :
                                 (int_ints0_s2[0])                            ? {gen6_ts0_force_even_bit(pre_scr_out_data[55:48]), gen6_ts0_force_even_bit(pre_scr_out_data[47:40]), gen6_ts0_force_even_bit(pre_scr_out_data[39:32])} :
                                                                                pre_scr_out_data[55:32];

    // For TS0,1,2 Ordered Set at gen6 rate, Byte level even parity over Symbols 0-6 (or 8-14) Scarambled
    assign scr_out_data[63:56] = (wrd_not_scrmbl_s2[0] || !int_active_nb_8s)  ? int_data_s2[63:56] : 
                                 (int_ints0_s2[0])                            ? gen6_ts0_force_even_bit(pre_scr_out_data[63:56]):
                                                                                pre_scr_out_data[63:56];


generate if (CALC_PARITY_BEFORE_SCRAMBLE==0) begin : gen_tx_even_parity // XMLH
  assign int_parity_s2 = ^scr_out_data;
end else begin : gen_rx_even_parity // RMLH
  assign int_parity_s2 = ^int_data_s2;
end endgenerate
  assign int_lfsr_s2 = lfsr;

  localparam SCR_N_DELAY_CYLES = LFSR_REGOUT;
  localparam SCR_DATAPATH_WIDTH = (NB*8) + 1 + 23 + SB_WD *( 4 + 2) + (SB_WD * 1) + DCB_WD;
  localparam SCR_RESET_VALUE    = {(SCR_DATAPATH_WIDTH){1'b0}} ; // The others = 0
  delay_n_w_enable
  
  #(SCR_N_DELAY_CYLES, SCR_DATAPATH_WIDTH, SCR_RESET_VALUE) u_scr_delay(
      .clk        (core_clk),
      .rst_n      (core_rst_n),
      .clear      (1'b0),
      .en         (scramble_en),
      .din        ({scr_out_data, int_dataskip_s2, int_ints1_s2, int_ints2_s2, int_startblock_s2 , int_lfsr_s2, int_parity_s2 , lbyte_not_scrmbl_s2 , wrd_not_scrmbl_s2 , int_ints0_s2 , int_indcb_encoding_s2}),
      .dout       ({ int_data_s3, int_dataskip_s3, int_ints1_s3, int_ints2_s3, int_startblock_s3 , int_lfsr_s3, int_parity_s3 , lbyte_not_scrmbl_s3 , wrd_not_scrmbl_s3 , int_ints0_s3 , int_indcb_encoding_s3})
  );

generate if (CALC_PARITY_BEFORE_SCRAMBLE==0) begin : gen_tx_precoding_scramble_on // XMLH
  // logic below is for Precoding feature on XMLH side(Scrambler).
  // The previous bit used for precoding is set to 1b on every block boundary and gets updated by the last scrambled and precoded bit transmitted within the current block boundary.
  wire       [(NB*8)-1:0]   tx_precoding_out_data;
  wire       [(NB*8)-1:0]   gen5_tx_precoding_out_data;
  reg                       tx_precoding_bit;
  assign gen5_tx_precoding_out_data = tx_precode_nb(int_data_s3, int_startblock_s3[0], lbyte_not_scrmbl_s3[0], wrd_not_scrmbl_s3[0], tx_precoding_bit, precoding_en);

  always @ (posedge core_clk or negedge core_rst_n) begin : tx_precoding_bit_PROC
      if (!core_rst_n)
          tx_precoding_bit <= #TP '0;
      else begin
          if(~precoding_en || int_dataskip_s3) begin
              tx_precoding_bit <= #TP tx_precoding_bit;
          end else begin
              tx_precoding_bit <= #TP tx_precoding_out_data[(NB_GEN5*8-1)];
          end
      end
  end

  // Gray Coding
  // All scrambled bits on a 2-bit aligned boundary are Gray Coded, when both bits are scrambled at gen6 rate.
  // TS0 Ordered Set Symbols are not Gray Coded. The input 00b, 01b, 10b, 11b becomes 00b, 01b, 11b, and 10b
  wire       [(NB*8)-1:0]   gen6_tx_graycoding_out_data;
  assign gen6_tx_graycoding_out_data = gen6_graycode_nb(0, int_data_s3, lbyte_not_scrmbl_s3[0], (wrd_not_scrmbl_s3[0] || gen6_compliance_sending), int_ints0_s3[0], int_ints1_s3[0], int_ints2_s3[0]);

  // For gen6, the "previous 2-bit" used for precoding is reset to 00b whenever an unscrambled Symbol is sent across.
  reg        [1:0]          gen6_tx_precoding_bit;
  wire       [(NB*8)-1:0]   gen6_tx_precoding_out_data;
  wire                      gen6_tx_precoding_bypass = ~precoding_en || gen6_compliance_sending || ~scramble_en;
  assign gen6_tx_precoding_out_data = (gen6_tx_precoding_bypass || wrd_not_scrmbl_s3[0] || int_ints0_s3[0]) ? gen6_tx_graycoding_out_data : gen6_tx_precode_nb(gen6_tx_graycoding_out_data, lbyte_not_scrmbl_s3[0], gen6_tx_precoding_bit);

  always @ (posedge core_clk or negedge core_rst_n) begin : gen6_tx_precoding_bit_PROC
      if (!core_rst_n)
          gen6_tx_precoding_bit <= #TP '0;
      else begin
          if(int_dataskip_s3) begin
              gen6_tx_precoding_bit <= #TP gen6_tx_precoding_bit;
          end else if(gen6_tx_precoding_bypass || wrd_not_scrmbl_s3[0]) begin
              gen6_tx_precoding_bit <= #TP '0;
          end else begin
              gen6_tx_precoding_bit <= #TP gen6_tx_precoding_out_data[(NB*8-1) : (NB*8-2)];
          end
      end
  end

  assign tx_precoding_out_data = current_data_rate_gen6 ? gen6_tx_precoding_out_data : gen5_tx_precoding_out_data;

  // Output registering (optional, Default=1)
  localparam TX_N_DELAY_CYLES = PRECODING_REGOUT + GLAYCODING_REGOUT;
  localparam TX_DATAPATH_WIDTH = (NB*8) + 1 + SB_WD*4 + 23 + (SB_WD * 1) + DCB_WD;
  localparam TX_RESET_VALUE    = {(TX_DATAPATH_WIDTH){1'b0}} ; // The others = 0
  delay_n_w_enable
  
  #(TX_N_DELAY_CYLES, TX_DATAPATH_WIDTH, TX_RESET_VALUE) u_tx_delay(
      .clk        (core_clk),
      .rst_n      (core_rst_n),
      .clear      (1'b0),
      .en         (scramble_en),
      .din        ({tx_precoding_out_data, int_dataskip_s3, int_ints1_s3, int_ints2_s3, int_startblock_s3, int_lfsr_s3, int_parity_s3 , int_ints0_s3, int_indcb_encoding_s3}),
      .dout       ({         int_out_data, int_dataskip_s4, int_ints1_s4, int_ints2_s4, int_startblock_s4, int_lfsr_s4, int_parity_s4 , int_ints0_s4, int_indcb_encoding_s4})
  );

end else begin : gen_tx_precoding_scramble_off // RMLH
  assign int_out_data        = int_data_s3;
  assign int_dataskip_s4     = int_dataskip_s3  ;
  assign int_ints0_s4        = int_ints0_s3     ;
  assign int_indcb_encoding_s4  = int_indcb_encoding_s3;
  assign int_ints1_s4        = int_ints1_s3     ;
  assign int_ints2_s4        = int_ints2_s3     ;
  assign int_startblock_s4   = int_startblock_s3;
  assign int_parity_s4       = int_parity_s3    ;
  assign int_lfsr_s4         = int_lfsr_s3      ;
end endgenerate

// Aligned output data
  delay_n_w_enable
  
  #(REGOUT, (23+SB_WD), 0) u_tx_delay_gen7(
      .clk        (core_clk),
      .rst_n      (core_rst_n),
      .clear      (1'b0),
      .en         (scramble_en),
      .din        ({int_lfsr_s4, int_parity_s4}),
      .dout       ({out_lfsr, out_even_parity})
  );

  //logic below is for DC balance
//------- PIPE 8/16/32/64bit logic ----------------------------------------------------------------------------------------------------------------------
  //TS OS Symbol count, int_sym_count is aligned to the same cycle as int_out_data
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
generate if (REGOUT==1) begin : gen_sym_count_regout_on
  assign int_sym_count = int_dataskip_s4 ? pre_sym_count : (int_ints1_s4[0] || int_ints2_s4[0] || int_ints0_s4[0]) ? (int_startblock_s4[0] ? (active_nb_gen34 - 1) : (pre_sym_count + active_nb_gen34)) : 0;
  assign mux_int_sym_count = int_sym_count;
  assign sym_count = pre_sym_count;
end else if (CALC_PARITY_BEFORE_SCRAMBLE==0 && PRECODING_REGOUT==1) begin : gen_sym_cnt_tx_precoding_reg
  assign int_sym_count = int_dataskip_s3 ? pre_sym_count : (int_ints1_s3[0] || int_ints2_s3[0] || int_ints0_s3[0]) ? (int_startblock_s3[0] ? (active_nb_gen34 - 1) : (pre_sym_count + active_nb_gen34)) : 0;
  assign mux_int_sym_count = pre_sym_count;
  assign sym_count = pre_sym_count;
end else begin : gen_sym_count_regout_off
  assign int_sym_count = int_dataskip_s4 ? pre_sym_count : (int_ints1_s4[0] || int_ints2_s4[0] || int_ints0_s4[0]) ? (int_startblock_s4[0] ? (active_nb_gen34 - 1) : (pre_sym_count + active_nb_gen34)) : 0;
  assign mux_int_sym_count = int_sym_count;
  assign sym_count = int_sym_count;
end endgenerate
// spyglass enable_block W164a

  //sym_count to the same cycle as out_data_d
  always @ (posedge core_clk or negedge core_rst_n) begin : sym_count_PROC
      if (!core_rst_n)
          pre_sym_count <= #TP '0;
      else
          pre_sym_count <= #TP int_sym_count;
  end

  //count 1s
  //based on int_out_data, one cycle advance to the real scrambled data (out_data)
  //int_sym_count is one cycle advance to sym_count
  //doing so is to break timing path
  always @(*) begin : count_1s_PROC
      count_1s = 0
                  + number_1s(int_out_data[8+:8], int_out_data[0+:8])
                  + number_1s(int_out_data[24+:8], int_out_data[16+:8])
                  ;

      if (mux_int_sym_count==7) begin
          //add the number of 1s (dc_1s_s14_15) after DC balance adjustment for Symbol 14/15
          count_1s = 0
                  + ( |(active_nb_gen34[2:1]) ? dc_1s_s14_15 : 0 )
                  + number_1s(int_out_data[8+:8], int_out_data[0+:8])
                  + number_1s(int_out_data[24+:8], int_out_data[16+:8])
                  ;
      end else if (mux_int_sym_count==15 ) begin
         //don't add number of 1s for Sym 14/15 here as we don't know its DC balance symbol or TS identifier
         count_1s = 0
                  + (|active_nb_gen34[3:2] ? number_1s(int_out_data[8+:8], int_out_data[0+:8]) : 0)
                  ;
      end
  end

  //count 1s and 0s for 8s as Symbol 11 and Symbol 14/15 in the same cycle for 8s
  //according to DC balance algorithm, we decide to do DC balance or not at Sym 11
  assign count_nb8_1s = 0
                        ;

  assign pam4_count_nb8_1s = 0
                        + pam4_number_1s(int_out_data[8*1 +:8], int_out_data[8*0 +:8])  // symbol#0,1 or 8,9 
                        + pam4_number_1s(int_out_data[8*3 +:8], int_out_data[8*2 +:8])  // symbol#2,3 or 10,11
                        + pam4_number_1s(int_out_data[8*5 +:8], int_out_data[8*4 +:8])  // symbol#4,5 or 12,13
                        + pam4_number_1s(8'h00                , int_out_data[8*6 +:8])  // symbol#6   or 14
                        ;
  assign pam4_count_nb8_1s_s7s15 = pam4_number_1s(8'h00, int_out_data[56+:8]); // symbol#7 or 15

  assign pam4_count_nb8_0s = 0
                        + pam4_number_0s(int_out_data[8*1 +:8], int_out_data[8*0 +:8])  // symbol#0,1 or 8,9
                        + pam4_number_0s(int_out_data[8*3 +:8], int_out_data[8*2 +:8])  // symbol#2,3 or 10,11
                        + pam4_number_0s(int_out_data[8*5 +:8], int_out_data[8*4 +:8])  // symbol#4,5 or 12,13
                        + pam4_number_0s(8'hFF                , int_out_data[8*6 +:8])  // symbol#6   or 14
                        ;
  assign pam4_count_nb8_0s_s7s15 = pam4_number_0s(8'hFF, int_out_data[56+:8]); // symbol#7 or 15

  //break timing path for count_1s and count_nb8_1s
  always @ (posedge core_clk or negedge core_rst_n) begin : count_1s_d_PROC
      if (!core_rst_n)
          count_1s_d <= #TP '0;
      else
          if( scramble_en )begin
              count_1s_d <= #TP count_1s;
          end
  end

generate if (REGOUT==1) begin : gen_sel_delayed_signals
  assign mux_count_1s_d = count_1s_d;
  assign mux_count_nb8_1s_d = count_nb8_1s_d;
  assign mux_out_data_d = out_data_d;
end else begin : gen_sel_bypass_signals
  assign mux_count_1s_d = count_1s;
  assign mux_count_nb8_1s_d = count_nb8_1s;
  assign mux_out_data_d = int_out_data;
end endgenerate

  //count_nb8_1s at int_sym_count=15, then count_nb8_1s_d at sym_count=15
  always @ (posedge core_clk or negedge core_rst_n) begin : count_nb8_1s_d_PROC
      if (!core_rst_n) begin
          count_nb8_1s_d <= #TP '0;
          pam4_count_nb8_1s_d <= #TP '0;
          pam4_count_nb8_0s_d <= #TP '0;
          pam4_count_nb8_1s_s7s15_d <= #TP '0;
          pam4_count_nb8_0s_s7s15_d <= #TP '0;
      end else begin
          count_nb8_1s_d <= #TP count_nb8_1s;
          pam4_count_nb8_1s_d <= #TP pam4_count_nb8_1s;
          pam4_count_nb8_0s_d <= #TP pam4_count_nb8_0s;
          pam4_count_nb8_1s_s7s15_d <= #TP pam4_count_nb8_1s_s7s15;
          pam4_count_nb8_0s_s7s15_d <= #TP pam4_count_nb8_0s_s7s15;
      end
  end

  //logic below is one cycle delay than count_1s
  //count 0s
  //add number of 1s/0s for Sym 14/15 at sym_count = 7
  //no action for Sym 14/15 at sym_count = 15
  always @(*) begin : count_0s_PROC
      count_0s = (active_nb_gen34[0] ? 8 : active_nb_gen34[1] ? 16 : active_nb_gen34[2] ? 32 : active_nb_gen34[3] ? 64 : 0) - mux_count_1s_d;

      if ( active_nb_gen34[3] ) begin
          if ( sym_count == 15 && eie_to_first_ts_d )
              count_0s = 48 - mux_count_1s_d;
          else if (~eie_to_first_ts_d && REGOUT==0) begin
            if (sym_count == 7)
              count_0s = (64+16) - mux_count_1s_d;
            else // sym_count == 15
              count_0s = (64-16) - mux_count_1s_d;
          end
      end
      else begin
          if (sym_count == 7 && !eie_to_first_ts)
              count_0s = (active_nb_gen34[0] ? 8 : active_nb_gen34[1] ? 16 : active_nb_gen34[2] ? 32 : 0)+16 - mux_count_1s_d;
          else if (sym_count == 15)
              count_0s = (active_nb_gen34[1] ? 16 : active_nb_gen34[2] ? 32 : 0)-16 - mux_count_1s_d;
      end
  end

  always @(*) begin : count_nb8_0s_PROC
      count_nb8_0s = (active_nb_gen34[3] ? 32 : 0) - mux_count_nb8_1s_d;

      if ( sym_count == 15 && !eie_to_first_ts_d && REGOUT==1)
          count_nb8_0s = (active_nb_gen34[3] ? 48 : 0) - mux_count_nb8_1s_d;
  end

// If the running DC Balance was > +47 at the start of the TS Ordered Set, transmit 00h in Symbols 7 and 15 without scrambling.
// If the running DC Balance was <-47 at the start of the TS Ordered Set, transmit FFh in Symbols 7 and 15 without scrambling.
  assign pam4_count_nb8_1s_dc_balance_0 = pam4_number_1s(`GEN6_DC_BALANCE_SYM_0, `GEN6_DC_BALANCE_SYM_0); // DC Balance as 00h
  assign pam4_count_nb8_1s_dc_balance_1 = pam4_number_1s(`GEN6_DC_BALANCE_SYM_1, `GEN6_DC_BALANCE_SYM_1); // DC Balance as FFH
  assign pam4_count_nb8_0s_dc_balance_0 = pam4_number_0s(`GEN6_DC_BALANCE_SYM_0, `GEN6_DC_BALANCE_SYM_0); // DC Balance as 00h
  assign pam4_count_nb8_0s_dc_balance_1 = pam4_number_0s(`GEN6_DC_BALANCE_SYM_1, `GEN6_DC_BALANCE_SYM_1); // DC Balance as FFH
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
  assign sel_pam4_count_nb8_1s_s7s15_d = gen6_dc_sym_1s ? {1'b0, pam4_count_nb8_1s_dc_balance_0} : gen6_dc_sym_0s ? {1'b0, pam4_count_nb8_1s_dc_balance_1} : ({1'b0, pam4_count_nb8_1s_s7s15_d} + {1'b0, pam4_count_nb8_1s_s7s15});
  assign sel_pam4_count_nb8_0s_s7s15_d = gen6_dc_sym_1s ? {1'b0, pam4_count_nb8_0s_dc_balance_0} : gen6_dc_sym_0s ? {1'b0, pam4_count_nb8_0s_dc_balance_1} : ({1'b0, pam4_count_nb8_0s_s7s15_d} + {1'b0, pam4_count_nb8_0s_s7s15});
  assign gen6_count_nb8_1s = ({2'b00,pam4_count_nb8_1s_d} + {2'b00, pam4_count_nb8_1s} + {1'b0,sel_pam4_count_nb8_1s_s7s15_d});
  assign gen6_count_nb8_0s = ({2'b00,pam4_count_nb8_0s_d} + {2'b00, pam4_count_nb8_0s} + {1'b0,sel_pam4_count_nb8_0s_s7s15_d});
// spyglass enable_block W164a

  always @ (posedge core_clk or negedge core_rst_n) begin : count_nb8_1s_s7s15_d_PROC
      if (!core_rst_n) begin
          gen6_count_nb8_1s_d <= #TP '0;
          gen6_count_nb8_0s_d <= #TP '0;
      end else if(!current_data_rate_gen6) begin
          gen6_count_nb8_1s_d <= #TP '0;
          gen6_count_nb8_0s_d <= #TP '0;
      end else if(mux_int_sym_count==15) begin
          gen6_count_nb8_1s_d <= #TP gen6_count_nb8_1s;
          gen6_count_nb8_0s_d <= #TP gen6_count_nb8_0s;
      end
  end

  //running DC balance
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
  assign balance_1s = int_dataskip ? 0 : mux_count_1s_d - count_0s;
  assign balance_0s = int_dataskip ? 0 : count_0s   - mux_count_1s_d;
  assign balance_nb8_1s = int_dataskip ? 0 : (mux_count_nb8_1s_d - count_nb8_0s);
  assign balance_nb8_0s = int_dataskip ? 0 : (count_nb8_0s   - mux_count_nb8_1s_d);
generate if (REGOUT==1) begin : gen_gen6_balance_regout_on
  assign gen6_balance_nb8_1s = (gen6_count_nb8_1s_d - gen6_count_nb8_0s_d);
  assign gen6_balance_nb8_0s = (gen6_count_nb8_0s_d - gen6_count_nb8_1s_d);
  assign gen6_num_1s_lrgr_0s = gen6_count_nb8_1s_d > gen6_count_nb8_0s_d;
end else begin : gen_gen6_balance_regout_off // for cxl
  assign gen6_balance_nb8_1s = (gen6_count_nb8_1s - gen6_count_nb8_0s);
  assign gen6_balance_nb8_0s = (gen6_count_nb8_0s - gen6_count_nb8_1s);
  assign gen6_num_1s_lrgr_0s = gen6_count_nb8_1s > gen6_count_nb8_0s;
end endgenerate

  assign current_balance_1s     = active_nb_gen34[3] ? (dc_balance_count + balance_nb8_1s) : (dc_balance_count + balance_1s);
  assign int_current_balance_0s = active_nb_gen34[3] ? (dc_balance_count - balance_nb8_0s) : (dc_balance_count - balance_0s);
  assign current_balance_0s     = 1024 - (active_nb_gen34[3] ? (dc_balance_count - balance_nb8_0s) : (dc_balance_count - balance_0s));
// spyglass enable_block W164a

  //number of 1s bigger than 0s
  assign num_1s_lrgr_0s = mux_count_1s_d > count_0s;
  assign num_nb8_1s_lrgr_0s = mux_count_nb8_1s_d > count_nb8_0s;

  //Transmitter exiting ElecIdle
  always @ (posedge core_clk or negedge core_rst_n) begin : latched_txeidle_eie_PROC
      if (!core_rst_n)
          latched_txei <= #TP '0;
      else
          latched_txei <= #TP int_txelecidle;
  end

  assign txei_exit = latched_txei & !int_txelecidle;

  //a pulse of an EIEOS following Data Block, used to reset dc_balance counter
  always @ (posedge core_clk or negedge core_rst_n) begin : latched_db_syncheader_PROC
      if (!core_rst_n)
          latched_db_syncheader <= #TP '0;
      else begin
          if (int_startblock && (int_syncheader[1:0] == `SYNC_DATA_BLOCK))
              latched_db_syncheader <= #TP 1'b1;
          else if (int_startblock || int_txelecidle)
              latched_db_syncheader <= #TP 1'b0;
      end
  end

  assign db_then_eie_pulse = latched_db_syncheader && int_ineie[0];

  always @ (posedge core_clk or negedge core_rst_n) begin : first_dc_clear_PROC
      if (!core_rst_n) begin
          eie_to_first_ts <= #TP '0;
          eie_to_first_ts_d <= #TP '0;
      end else begin
          if (db_then_eie_pulse || txei_exit) begin
              eie_to_first_ts <= #TP 1'b1;
          end else if (sym_count==7) begin
              eie_to_first_ts <= #TP 1'b0;
          end

          eie_to_first_ts_d <= #TP eie_to_first_ts;
      end
  end

  //DC balance count.
  //saturation is 511, so need 9 bits [8:0] for adding to the balance of 1s.
  //need bit [9] for the balance 0s.
  //e.g.
  //1st cycle, 11 1s and 8 0s, we have 1s balance 3, dc_balance_count = d'3 = 10'b0000000011
  //2nd cycle, 6 1s and 15 0s, we have 0s balance 9, dc_balance_count = -d'6 = 10'b1111111010
  //if bit-9 = 0, 1s > 0s, 1s balance = dc_balance_count[8:0]
  //if bit-9 = 1, 0s > 1s, 0s balance = 1024 - dc_balance_count. So 0s saturation is 513
  //here dc_balance_count is one cycle delay
  //We need +balance_1s (-balance_0s) to get current balance
  always @ (posedge core_clk or negedge core_rst_n) begin : dc_balance_count_PROC
      if (!core_rst_n)
          dc_balance_count <= #TP '0;
      else begin
          if (db_then_eie_pulse || txei_exit) begin
              dc_balance_count <= #TP '0;
          end else if (current_data_rate_gen6) begin
            if ((int_ints0[0] || int_ints1[0] || int_ints2[0]) && sym_count==15) begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
              if (gen6_num_1s_lrgr_0s) begin
// ccx_line_begin: ; unreachable because accumulated 0's number > 1's number in received TS OS, so 1's balance cannot hit 511. But spec requires this line.
                  if (!dc_balance_count[9] && ((dc_balance_count[8:0] + gen6_balance_nb8_1s) >= 511))
                      dc_balance_count <= #TP 511;
                  else
// ccx_line_end
                      dc_balance_count <= #TP dc_balance_count + gen6_balance_nb8_1s;
              end else begin
                  if (dc_balance_count[9] && ((dc_balance_count[9:0] - gen6_balance_nb8_0s) <= 513))
                      dc_balance_count <= #TP 513;
                  else
                      dc_balance_count <= #TP dc_balance_count - gen6_balance_nb8_0s;
              end
// spyglass enable_block W164a
            end
          end else if (int_ints1 || int_ints2) begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
              if (num_1s_lrgr_0s) begin
// ccx_line_begin: ; unreachable because accumulated 0's number > 1's number in received TS OS, so 1's balance cannot hit 511. But spec requires this line.
                  if (!dc_balance_count[9] && ((dc_balance_count[8:0] + balance_1s) >= 511))
                      dc_balance_count <= #TP 511;
                  else
// ccx_line_end
                      dc_balance_count <= #TP dc_balance_count + balance_1s;
              end else begin
                  if (dc_balance_count[9] && ((dc_balance_count[9:0] - balance_0s) <= 513))
                      dc_balance_count <= #TP 513;
                  else
                      dc_balance_count <= #TP dc_balance_count - balance_0s;
              end
// spyglass enable_block W164a
          end
      end
  end

  //indicate Symbol 14/15 to be replaced with DC Symbols.
  //dependent on 1s balance and 0s balance
  always @(*) begin : int_dc_balance_out_data_PROC
      replace_15_14 = 2'b00;
      dc_sym_1s = 1'b0;
      dc_sym_0s = 1'b0;

//If the running DC Balance was > +47 at the start of the TS Ordered Set, transmit 00h in Symbols 7 and 15 without scrambling.
//If the running DC Balance was <-47 at the start of the TS Ordered Set, transmit AAh in Symbols 7 and 15 without scrambling.
      gen6_dc_sym_1s = 1'b0;
      gen6_dc_sym_0s = 1'b0;
      if (!int_dataskip && current_data_rate_gen6 && (int_ints0[0] || int_ints1[0] || int_ints2[0])) begin
          if (!dc_balance_count[9] && (dc_balance_count > 47)) begin //1s balance
              gen6_dc_sym_1s = 1'b1;
          end else if(dc_balance_count[9] && ((1024 - dc_balance_count) > 47)) begin
              gen6_dc_sym_0s = 1'b1;
          end
      end

      if (!int_dataskip && (((sym_count == 11) && !active_nb_gen34[3]) || ((sym_count == 15) && active_nb_gen34[3]))) begin
          if ((num_1s_lrgr_0s && !active_nb_gen34[3]) || (num_nb8_1s_lrgr_0s && active_nb_gen34[3])) begin //add number of 1s balance
              if (!dc_balance_count[9]) begin //1s balance
                  if (current_balance_1s > 31) begin
                      replace_15_14 = 2'b11;
                      dc_sym_1s = 1'b1;
                  end else if (current_balance_1s > 15) begin
                      replace_15_14 = 2'b10;
                      dc_sym_1s = 1'b1;
                  end
              end else if (!current_balance_1s[9]) begin //become 1s balance after adding new 1s balance
                  if (current_balance_1s > 31) begin
                      replace_15_14 = 2'b11;
                      dc_sym_1s = 1'b1;
                  end else if (current_balance_1s > 15) begin
                      replace_15_14 = 2'b10;
                      dc_sym_1s = 1'b1;
                  end
              end else begin //still 0s balance after adding new 1s balance
                  if ((1024 - current_balance_1s) > 31) begin
                      replace_15_14 = 2'b11;
                      dc_sym_0s = 1'b1;
                  end else if ((1024 - current_balance_1s) > 15) begin
                      replace_15_14 = 2'b10;
                      dc_sym_0s = 1'b1;
                  end
              end
          end else begin //subtract number of 0s balance
              if (dc_balance_count[9]) begin //0s balance
                  if (current_balance_0s > 31) begin
                      replace_15_14 = 2'b11;
                      dc_sym_0s = 1'b1;
                  end else if (current_balance_0s > 15) begin
                      replace_15_14 = 2'b10;
                      dc_sym_0s = 1'b1;
                  end
              end else if (int_current_balance_0s[9]) begin //become 0s balance after subtracting new 0s balance
                  if (current_balance_0s > 31) begin
                      replace_15_14 = 2'b11;
                      dc_sym_0s = 1'b1;
                  end else if (current_balance_0s > 15) begin
                      replace_15_14 = 2'b10;
                      dc_sym_0s = 1'b1;
                  end
              end else begin //still 1s balance after subtracting new 0s balance
                  if (int_current_balance_0s > 31) begin
                      replace_15_14 = 2'b11;
                      dc_sym_1s = 1'b1;
                  end else if (int_current_balance_0s > 15) begin
                      replace_15_14 = 2'b10;
                      dc_sym_1s = 1'b1;
                  end
              end
          end
      end
  end

  always @ (posedge core_clk or negedge core_rst_n) begin : latched_replace_PROC
      if (!core_rst_n) begin
          latched_replace_15_14 <= #TP '0;
          latched_dc_sym_1s <= #TP '0;
          latched_dc_sym_0s <= #TP '0;
      end else if (!int_dataskip && ((sym_count == 11 && !active_nb_gen34[3]) || (sym_count == 15 && active_nb_gen34[3]))) begin
          latched_replace_15_14 <= #TP replace_15_14;
          latched_dc_sym_1s <= #TP dc_sym_1s;
          latched_dc_sym_0s <= #TP dc_sym_0s;
      end else if (sym_count == 7) begin
          latched_replace_15_14 <= #TP '0;
          latched_dc_sym_1s <= #TP '0;
          latched_dc_sym_0s <= #TP '0;
      end
  end

  assign int_replace_15_14 = replace_15_14 | latched_replace_15_14;
  assign int_dc_sym_1s = dc_sym_1s | latched_dc_sym_1s;
  assign int_dc_sym_0s = dc_sym_0s | latched_dc_sym_0s;

  //replace Symbol 14/15 with DC Symbols
  always_comb begin : dc_balance_out_data_PROC
  
  if(CALC_PARITY_BEFORE_SCRAMBLE == 1) begin  // RMLH no DC balance
      dc_balance_out_data = '0;
  end
  else begin  // CALC_PARITY_BEFORE_SCRAMBLE == 0 : XMLH 
      dc_balance_out_data = mux_out_data_d;

      if (current_data_rate_gen6) begin //8s gen6
          if (!int_dataskip && ((sym_count == 7) ||(sym_count == 15))) begin
              if (gen6_dc_sym_1s)
                  dc_balance_out_data[(NB-1)*8+:8] = `GEN6_DC_BALANCE_SYM_0;
              else if(gen6_dc_sym_0s)
                  dc_balance_out_data[(NB-1)*8+:8] = `GEN6_DC_BALANCE_SYM_1;
           end
      end else begin // 4s gen3,4,5
          if (!int_dataskip && sym_count == 15) begin
               if (int_dc_sym_1s) begin
                   if (int_replace_15_14 == 2'b11)
                       dc_balance_out_data[((NB/2-2)*8)+:16] = 16'h0820;
                   else if (int_replace_15_14 == 2'b10)
                       dc_balance_out_data[((NB/2-1)*8)+:8] = 8'h08;
               end else if (int_dc_sym_0s) begin
                   if (int_replace_15_14 == 2'b11)
                       dc_balance_out_data[((NB/2-2)*8)+:16] = 16'hF7DF;
                   else if (int_replace_15_14 == 2'b10)
                       dc_balance_out_data[((NB/2-1)*8)+:8] = 8'hF7;
               end
           end
      end
  end
  end

  //count number of 1s after DC balance for Symbol 14/15
  assign int_dc_1s_s14_15 = (sym_count == 15) ? (number_1s(dc_balance_out_data[((NB/2-1)*8)+:8], dc_balance_out_data[((NB/2-2)*8)+:8])) : 0; // gen3,4,5

  always @ (posedge core_clk or negedge core_rst_n) begin : dc_1s_s14_15_d_PROC
      if (!core_rst_n)
          dc_1s_s14_15_d <= #TP '0;
      else if (sym_count == 7 || db_then_eie_pulse || txei_exit)
          dc_1s_s14_15_d <= #TP '0;
      else if (!int_dataskip && sym_count == 15)
          dc_1s_s14_15_d <= #TP int_dc_1s_s14_15;
  end

  assign dc_1s_s14_15 = dc_1s_s14_15_d;

generate if (REGOUT==1) begin : gen_regout_on
  //output data
  always @ (posedge core_clk or negedge core_rst_n) begin : out_data_d_RPOC
    if (!core_rst_n)
      out_data_d <= #TP '0;
    else
      if(scramble_en)begin
        out_data_d <= #TP int_out_data;
      end
  end

  assign out_data = dc_balance_disable ? out_data_d : dc_balance_out_data;
  reg [DCB_WD-1:0]  int_indcb_encoding_s5;
  always @ (posedge core_clk or negedge core_rst_n) begin : int_indcb_encoding_s5_RPOC
    if (!core_rst_n)
      int_indcb_encoding_s5 <= #TP '0;
    else 
      if(scramble_en)begin
        int_indcb_encoding_s5 <= #TP int_indcb_encoding_s4;
      end  
  end  
  assign out_dcb_det = int_indcb_encoding_s5;
end else begin : gen_regout_off
  assign out_data = dc_balance_disable ? int_out_data : dc_balance_out_data;
  assign out_dcb_det = int_indcb_encoding_s4;
end endgenerate


  //count 1s function
  function automatic [4:0] number_1s;
      input [7:0] data_1;
      input [7:0] data_2;
      begin
          number_1s = {1'b0, sub_number_1s(data_1)} + {1'b0, sub_number_1s(data_2)};
      end
  endfunction

  function automatic [3:0] sub_number_1s;
      input [7:0] data;
      begin
          case(data)
//            8'b0000_0000: sub_number_1s = 0 + 0;
              8'b0000_0001: sub_number_1s = 0 + 1;
              8'b0000_0010: sub_number_1s = 0 + 1;
              8'b0000_0011: sub_number_1s = 0 + 2;
              8'b0000_0100: sub_number_1s = 0 + 1;
              8'b0000_0101: sub_number_1s = 0 + 2;
              8'b0000_0110: sub_number_1s = 0 + 2;
              8'b0000_0111: sub_number_1s = 0 + 3;
              8'b0000_1000: sub_number_1s = 0 + 1;
              8'b0000_1001: sub_number_1s = 0 + 2;
              8'b0000_1010: sub_number_1s = 0 + 2;
              8'b0000_1011: sub_number_1s = 0 + 3;
              8'b0000_1100: sub_number_1s = 0 + 2;
              8'b0000_1101: sub_number_1s = 0 + 3;
              8'b0000_1110: sub_number_1s = 0 + 3;
              8'b0000_1111: sub_number_1s = 0 + 4;
              8'b0001_0000: sub_number_1s = 1 + 0;
              8'b0001_0001: sub_number_1s = 1 + 1;
              8'b0001_0010: sub_number_1s = 1 + 1;
              8'b0001_0011: sub_number_1s = 1 + 2;
              8'b0001_0100: sub_number_1s = 1 + 1;
              8'b0001_0101: sub_number_1s = 1 + 2;
              8'b0001_0110: sub_number_1s = 1 + 2;
              8'b0001_0111: sub_number_1s = 1 + 3;
              8'b0001_1000: sub_number_1s = 1 + 1;
              8'b0001_1001: sub_number_1s = 1 + 2;
              8'b0001_1010: sub_number_1s = 1 + 2;
              8'b0001_1011: sub_number_1s = 1 + 3;
              8'b0001_1100: sub_number_1s = 1 + 2;
              8'b0001_1101: sub_number_1s = 1 + 3;
              8'b0001_1110: sub_number_1s = 1 + 3;
              8'b0001_1111: sub_number_1s = 1 + 4;
              8'b0010_0000: sub_number_1s = 1 + 0;
              8'b0010_0001: sub_number_1s = 1 + 1;
              8'b0010_0010: sub_number_1s = 1 + 1;
              8'b0010_0011: sub_number_1s = 1 + 2;
              8'b0010_0100: sub_number_1s = 1 + 1;
              8'b0010_0101: sub_number_1s = 1 + 2;
              8'b0010_0110: sub_number_1s = 1 + 2;
              8'b0010_0111: sub_number_1s = 1 + 3;
              8'b0010_1000: sub_number_1s = 1 + 1;
              8'b0010_1001: sub_number_1s = 1 + 2;
              8'b0010_1010: sub_number_1s = 1 + 2;
              8'b0010_1011: sub_number_1s = 1 + 3;
              8'b0010_1100: sub_number_1s = 1 + 2;
              8'b0010_1101: sub_number_1s = 1 + 3;
              8'b0010_1110: sub_number_1s = 1 + 3;
              8'b0010_1111: sub_number_1s = 1 + 4;
              8'b0011_0000: sub_number_1s = 2 + 0;
              8'b0011_0001: sub_number_1s = 2 + 1;
              8'b0011_0010: sub_number_1s = 2 + 1;
              8'b0011_0011: sub_number_1s = 2 + 2;
              8'b0011_0100: sub_number_1s = 2 + 1;
              8'b0011_0101: sub_number_1s = 2 + 2;
              8'b0011_0110: sub_number_1s = 2 + 2;
              8'b0011_0111: sub_number_1s = 2 + 3;
              8'b0011_1000: sub_number_1s = 2 + 1;
              8'b0011_1001: sub_number_1s = 2 + 2;
              8'b0011_1010: sub_number_1s = 2 + 2;
              8'b0011_1011: sub_number_1s = 2 + 3;
              8'b0011_1100: sub_number_1s = 2 + 2;
              8'b0011_1101: sub_number_1s = 2 + 3;
              8'b0011_1110: sub_number_1s = 2 + 3;
              8'b0011_1111: sub_number_1s = 2 + 4;
              8'b0100_0000: sub_number_1s = 1 + 0;
              8'b0100_0001: sub_number_1s = 1 + 1;
              8'b0100_0010: sub_number_1s = 1 + 1;
              8'b0100_0011: sub_number_1s = 1 + 2;
              8'b0100_0100: sub_number_1s = 1 + 1;
              8'b0100_0101: sub_number_1s = 1 + 2;
              8'b0100_0110: sub_number_1s = 1 + 2;
              8'b0100_0111: sub_number_1s = 1 + 3;
              8'b0100_1000: sub_number_1s = 1 + 1;
              8'b0100_1001: sub_number_1s = 1 + 2;
              8'b0100_1010: sub_number_1s = 1 + 2;
              8'b0100_1011: sub_number_1s = 1 + 3;
              8'b0100_1100: sub_number_1s = 1 + 2;
              8'b0100_1101: sub_number_1s = 1 + 3;
              8'b0100_1110: sub_number_1s = 1 + 3;
              8'b0100_1111: sub_number_1s = 1 + 4;
              8'b0101_0000: sub_number_1s = 2 + 0;
              8'b0101_0001: sub_number_1s = 2 + 1;
              8'b0101_0010: sub_number_1s = 2 + 1;
              8'b0101_0011: sub_number_1s = 2 + 2;
              8'b0101_0100: sub_number_1s = 2 + 1;
              8'b0101_0101: sub_number_1s = 2 + 2;
              8'b0101_0110: sub_number_1s = 2 + 2;
              8'b0101_0111: sub_number_1s = 2 + 3;
              8'b0101_1000: sub_number_1s = 2 + 1;
              8'b0101_1001: sub_number_1s = 2 + 2;
              8'b0101_1010: sub_number_1s = 2 + 2;
              8'b0101_1011: sub_number_1s = 2 + 3;
              8'b0101_1100: sub_number_1s = 2 + 2;
              8'b0101_1101: sub_number_1s = 2 + 3;
              8'b0101_1110: sub_number_1s = 2 + 3;
              8'b0101_1111: sub_number_1s = 2 + 4;
              8'b0110_0000: sub_number_1s = 2 + 0;
              8'b0110_0001: sub_number_1s = 2 + 1;
              8'b0110_0010: sub_number_1s = 2 + 1;
              8'b0110_0011: sub_number_1s = 2 + 2;
              8'b0110_0100: sub_number_1s = 2 + 1;
              8'b0110_0101: sub_number_1s = 2 + 2;
              8'b0110_0110: sub_number_1s = 2 + 2;
              8'b0110_0111: sub_number_1s = 2 + 3;
              8'b0110_1000: sub_number_1s = 2 + 1;
              8'b0110_1001: sub_number_1s = 2 + 2;
              8'b0110_1010: sub_number_1s = 2 + 2;
              8'b0110_1011: sub_number_1s = 2 + 3;
              8'b0110_1100: sub_number_1s = 2 + 2;
              8'b0110_1101: sub_number_1s = 2 + 3;
              8'b0110_1110: sub_number_1s = 2 + 3;
              8'b0110_1111: sub_number_1s = 2 + 4;
              8'b0111_0000: sub_number_1s = 3 + 0;
              8'b0111_0001: sub_number_1s = 3 + 1;
              8'b0111_0010: sub_number_1s = 3 + 1;
              8'b0111_0011: sub_number_1s = 3 + 2;
              8'b0111_0100: sub_number_1s = 3 + 1;
              8'b0111_0101: sub_number_1s = 3 + 2;
              8'b0111_0110: sub_number_1s = 3 + 2;
              8'b0111_0111: sub_number_1s = 3 + 3;
              8'b0111_1000: sub_number_1s = 3 + 1;
              8'b0111_1001: sub_number_1s = 3 + 2;
              8'b0111_1010: sub_number_1s = 3 + 2;
              8'b0111_1011: sub_number_1s = 3 + 3;
              8'b0111_1100: sub_number_1s = 3 + 2;
              8'b0111_1101: sub_number_1s = 3 + 3;
              8'b0111_1110: sub_number_1s = 3 + 3;
              8'b0111_1111: sub_number_1s = 3 + 4;
              8'b1000_0000: sub_number_1s = 1 + 0;
              8'b1000_0001: sub_number_1s = 1 + 1;
              8'b1000_0010: sub_number_1s = 1 + 1;
              8'b1000_0011: sub_number_1s = 1 + 2;
              8'b1000_0100: sub_number_1s = 1 + 1;
              8'b1000_0101: sub_number_1s = 1 + 2;
              8'b1000_0110: sub_number_1s = 1 + 2;
              8'b1000_0111: sub_number_1s = 1 + 3;
              8'b1000_1000: sub_number_1s = 1 + 1;
              8'b1000_1001: sub_number_1s = 1 + 2;
              8'b1000_1010: sub_number_1s = 1 + 2;
              8'b1000_1011: sub_number_1s = 1 + 3;
              8'b1000_1100: sub_number_1s = 1 + 2;
              8'b1000_1101: sub_number_1s = 1 + 3;
              8'b1000_1110: sub_number_1s = 1 + 3;
              8'b1000_1111: sub_number_1s = 1 + 4;
              8'b1001_0000: sub_number_1s = 2 + 0;
              8'b1001_0001: sub_number_1s = 2 + 1;
              8'b1001_0010: sub_number_1s = 2 + 1;
              8'b1001_0011: sub_number_1s = 2 + 2;
              8'b1001_0100: sub_number_1s = 2 + 1;
              8'b1001_0101: sub_number_1s = 2 + 2;
              8'b1001_0110: sub_number_1s = 2 + 2;
              8'b1001_0111: sub_number_1s = 2 + 3;
              8'b1001_1000: sub_number_1s = 2 + 1;
              8'b1001_1001: sub_number_1s = 2 + 2;
              8'b1001_1010: sub_number_1s = 2 + 2;
              8'b1001_1011: sub_number_1s = 2 + 3;
              8'b1001_1100: sub_number_1s = 2 + 2;
              8'b1001_1101: sub_number_1s = 2 + 3;
              8'b1001_1110: sub_number_1s = 2 + 3;
              8'b1001_1111: sub_number_1s = 2 + 4;
              8'b1010_0000: sub_number_1s = 2 + 0;
              8'b1010_0001: sub_number_1s = 2 + 1;
              8'b1010_0010: sub_number_1s = 2 + 1;
              8'b1010_0011: sub_number_1s = 2 + 2;
              8'b1010_0100: sub_number_1s = 2 + 1;
              8'b1010_0101: sub_number_1s = 2 + 2;
              8'b1010_0110: sub_number_1s = 2 + 2;
              8'b1010_0111: sub_number_1s = 2 + 3;
              8'b1010_1000: sub_number_1s = 2 + 1;
              8'b1010_1001: sub_number_1s = 2 + 2;
              8'b1010_1010: sub_number_1s = 2 + 2;
              8'b1010_1011: sub_number_1s = 2 + 3;
              8'b1010_1100: sub_number_1s = 2 + 2;
              8'b1010_1101: sub_number_1s = 2 + 3;
              8'b1010_1110: sub_number_1s = 2 + 3;
              8'b1010_1111: sub_number_1s = 2 + 4;
              8'b1011_0000: sub_number_1s = 3 + 0;
              8'b1011_0001: sub_number_1s = 3 + 1;
              8'b1011_0010: sub_number_1s = 3 + 1;
              8'b1011_0011: sub_number_1s = 3 + 2;
              8'b1011_0100: sub_number_1s = 3 + 1;
              8'b1011_0101: sub_number_1s = 3 + 2;
              8'b1011_0110: sub_number_1s = 3 + 2;
              8'b1011_0111: sub_number_1s = 3 + 3;
              8'b1011_1000: sub_number_1s = 3 + 1;
              8'b1011_1001: sub_number_1s = 3 + 2;
              8'b1011_1010: sub_number_1s = 3 + 2;
              8'b1011_1011: sub_number_1s = 3 + 3;
              8'b1011_1100: sub_number_1s = 3 + 2;
              8'b1011_1101: sub_number_1s = 3 + 3;
              8'b1011_1110: sub_number_1s = 3 + 3;
              8'b1011_1111: sub_number_1s = 3 + 4;
              8'b1100_0000: sub_number_1s = 2 + 0;
              8'b1100_0001: sub_number_1s = 2 + 1;
              8'b1100_0010: sub_number_1s = 2 + 1;
              8'b1100_0011: sub_number_1s = 2 + 2;
              8'b1100_0100: sub_number_1s = 2 + 1;
              8'b1100_0101: sub_number_1s = 2 + 2;
              8'b1100_0110: sub_number_1s = 2 + 2;
              8'b1100_0111: sub_number_1s = 2 + 3;
              8'b1100_1000: sub_number_1s = 2 + 1;
              8'b1100_1001: sub_number_1s = 2 + 2;
              8'b1100_1010: sub_number_1s = 2 + 2;
              8'b1100_1011: sub_number_1s = 2 + 3;
              8'b1100_1100: sub_number_1s = 2 + 2;
              8'b1100_1101: sub_number_1s = 2 + 3;
              8'b1100_1110: sub_number_1s = 2 + 3;
              8'b1100_1111: sub_number_1s = 2 + 4;
              8'b1101_0000: sub_number_1s = 3 + 0;
              8'b1101_0001: sub_number_1s = 3 + 1;
              8'b1101_0010: sub_number_1s = 3 + 1;
              8'b1101_0011: sub_number_1s = 3 + 2;
              8'b1101_0100: sub_number_1s = 3 + 1;
              8'b1101_0101: sub_number_1s = 3 + 2;
              8'b1101_0110: sub_number_1s = 3 + 2;
              8'b1101_0111: sub_number_1s = 3 + 3;
              8'b1101_1000: sub_number_1s = 3 + 1;
              8'b1101_1001: sub_number_1s = 3 + 2;
              8'b1101_1010: sub_number_1s = 3 + 2;
              8'b1101_1011: sub_number_1s = 3 + 3;
              8'b1101_1100: sub_number_1s = 3 + 2;
              8'b1101_1101: sub_number_1s = 3 + 3;
              8'b1101_1110: sub_number_1s = 3 + 3;
              8'b1101_1111: sub_number_1s = 3 + 4;
              8'b1110_0000: sub_number_1s = 3 + 0;
              8'b1110_0001: sub_number_1s = 3 + 1;
              8'b1110_0010: sub_number_1s = 3 + 1;
              8'b1110_0011: sub_number_1s = 3 + 2;
              8'b1110_0100: sub_number_1s = 3 + 1;
              8'b1110_0101: sub_number_1s = 3 + 2;
              8'b1110_0110: sub_number_1s = 3 + 2;
              8'b1110_0111: sub_number_1s = 3 + 3;
              8'b1110_1000: sub_number_1s = 3 + 1;
              8'b1110_1001: sub_number_1s = 3 + 2;
              8'b1110_1010: sub_number_1s = 3 + 2;
              8'b1110_1011: sub_number_1s = 3 + 3;
              8'b1110_1100: sub_number_1s = 3 + 2;
              8'b1110_1101: sub_number_1s = 3 + 3;
              8'b1110_1110: sub_number_1s = 3 + 3;
              8'b1110_1111: sub_number_1s = 3 + 4;
              8'b1111_0000: sub_number_1s = 4 + 0;
              8'b1111_0001: sub_number_1s = 4 + 1;
              8'b1111_0010: sub_number_1s = 4 + 1;
              8'b1111_0011: sub_number_1s = 4 + 2;
              8'b1111_0100: sub_number_1s = 4 + 1;
              8'b1111_0101: sub_number_1s = 4 + 2;
              8'b1111_0110: sub_number_1s = 4 + 2;
              8'b1111_0111: sub_number_1s = 4 + 3;
              8'b1111_1000: sub_number_1s = 4 + 1;
              8'b1111_1001: sub_number_1s = 4 + 2;
              8'b1111_1010: sub_number_1s = 4 + 2;
              8'b1111_1011: sub_number_1s = 4 + 3;
              8'b1111_1100: sub_number_1s = 4 + 2;
              8'b1111_1101: sub_number_1s = 4 + 3;
              8'b1111_1110: sub_number_1s = 4 + 3;
              8'b1111_1111: sub_number_1s = 4 + 4;
              default     : sub_number_1s = 0 + 0;
          endcase
      end
  endfunction

  //Precoding  function
  function automatic [NB*8-1:0] tx_precode_nb;
      input [NB*8-1:0] data;
      input            start;
      input            lbyte_not_scrmbl;
      input            wrd_not_scrmbl;
      input            precoding_bit;
      input            precoding_en;

      integer i;
      reg  [7:0]       tmp_data_1byte;
      reg  [NB*8-1:0]  tmp_data;
      reg              bit0_precoding_bit;
      reg              bit8_precoding_bit;

      begin
         tmp_data = 0;
          // Byte0
          bit0_precoding_bit = (start) ? 1'b1 :  precoding_bit;
          for (i=0; i<8; i=i+1) begin
              if(i==0) begin
                  tmp_data_1byte[i] = (data[i] ^ bit0_precoding_bit);
              end else begin
                  tmp_data_1byte[i] = (data[i] ^ tmp_data_1byte[i-1]);
              end
          end

         tmp_data[7:0] = (lbyte_not_scrmbl) ? data[7:0] : tmp_data_1byte;
          // Byte1-NB
          bit8_precoding_bit = (lbyte_not_scrmbl & start) | tmp_data[7];
          for (i=8; i<NB_GEN5*8; i=i+1) begin
              if(i==8) begin
                  tmp_data[i] = (data[i] ^ bit8_precoding_bit);
              end else begin
                  tmp_data[i] = (data[i] ^ tmp_data[i-1]);
              end
          end
          tx_precode_nb = (wrd_not_scrmbl | ~precoding_en) ? data : tmp_data;
      end
  endfunction

  function automatic [NB*8-1:0] rx_precode_nb;
      input [NB*8-1:0] data;
      input            start;
      input            lbyte_not_scrmbl;
      input            wrd_not_scrmbl;
      input            precoding_bit;
      input            precoding_en;

      integer i;
      reg  [7:0]       tmp_data_1byte;
      reg  [NB*8-1:0]  tmp_data;
      reg              bit0_precoding_bit;
      reg              bit8_precoding_bit;

      begin
         tmp_data = 0;
          // Byte0
          bit0_precoding_bit = (start) ? 1'b1 : precoding_bit;
          for (i=0; i<8; i=i+1) begin
              if(i==0) begin
                  tmp_data_1byte[i] = (data[i] ^ bit0_precoding_bit);
              end else begin
                  tmp_data_1byte[i] = (data[i] ^ data[i-1]);
              end
          end

         tmp_data[7:0] = (lbyte_not_scrmbl) ? data[7:0] : tmp_data_1byte;
          // Byte1-NB
          bit8_precoding_bit = (lbyte_not_scrmbl & start) | data[7];
          for (i=8; i<NB_GEN5*8; i=i+1) begin
              if(i==8) begin
                  tmp_data[i] = (data[i] ^ bit8_precoding_bit);
              end else begin
                  tmp_data[i] = (data[i] ^ data[i-1]);
              end
          end
          rx_precode_nb = (wrd_not_scrmbl | ~precoding_en) ? data : tmp_data;
      end
  endfunction

  function automatic [NB_GEN6*8-1:0] gen6_tx_precode_nb;
      input [NB_GEN6*8-1:0] data;
      input            lbyte_not_scrmbl;
      input [1:0]      precoding_bit;

      reg  [(NB_GEN6*8)-1:0]     tmp_data;
      reg  [1:0]                 tmp_precoding_bit;
    
    begin
        tmp_precoding_bit = precoding_bit;
        for (int ii = 0 ; ii <(NB_GEN6*8) ; ii = ii+2) begin
            if( lbyte_not_scrmbl && ( ii < 8 ) ) begin
                tmp_data[ii +: 2] = data[ii +: 2] ;
                tmp_precoding_bit     = '0 ;
            end
            else begin
                case({data[ii +: 2],  tmp_precoding_bit})
                    // Tx Precoding Table
                    //4'b00_10, 4'b01_11, 4'b11_01, 4'b10_00: tmp_data_1byte[i+0 +: 2] = 2'b10;
                    //4'b00_11, 4'b01_00, 4'b11_10, 4'b10_01: tmp_data_1byte[i+0 +: 2] = 2'b01;
                    //4'b00_01, 4'b01_10, 4'b11_00, 4'b10_11: tmp_data_1byte[i+0 +: 2] = 2'b11;
                    //default                               : tmp_data_1byte[i+0 +: 2] = 2'b00;
                    
                    // To improvement sysntheis timing, changed RTL code.(Formal equivalent with above table.)
                      4'b00_11, 4'b10_01 , 4'b00_01, 4'b10_11: tmp_data[ii +: 2] = { ~(data[ii+1] ^ tmp_precoding_bit[1]) , (data[ii] ^ tmp_precoding_bit[0]) };
                      default                                : tmp_data[ii +: 2] = (data[ii +: 2] ^ tmp_precoding_bit) ;
                endcase
                tmp_precoding_bit = tmp_data[ii +: 2];
            end
        end
        gen6_tx_precode_nb = tmp_data ;
    end
  endfunction

  function automatic [NB_GEN6*8-1:0] gen6_rx_precode_nb;
      input [NB_GEN6*8-1:0] data;
      input            lbyte_not_scrmbl;
      input            wrd_not_scrmbl;
      input            in_ts0;
      input            in_ts1;
      input            in_ts2;
      input [1:0]      precoding_bit;
      input            precoding_en;

      integer i;
      reg  [7:0]       tmp_data_1byte;
      reg  [NB_GEN6*8-1:0]  tmp_data;
      reg  [1:0]       byte0_precoding_bit;
      reg  [1:0]       byte1_precoding_bit;

      begin
          // Byte0
          byte0_precoding_bit = precoding_bit;
          for (i=0; i<8; i=i+2) begin
              case({data[i+0 +: 2],  byte0_precoding_bit})
                4'b00_10, 4'b01_01, 4'b11_11, 4'b10_00: tmp_data_1byte[i+0 +: 2] = 2'b10;
                4'b00_11, 4'b01_10, 4'b11_00, 4'b10_01: tmp_data_1byte[i+0 +: 2] = 2'b11;
                4'b00_01, 4'b01_00, 4'b11_10, 4'b10_11: tmp_data_1byte[i+0 +: 2] = 2'b01;
                default                               : tmp_data_1byte[i+0 +: 2] = 2'b00;
              endcase
              byte0_precoding_bit = data[i+0 +: 2];
          end
         tmp_data[7:0] = (lbyte_not_scrmbl) ? data[7:0] : tmp_data_1byte;

          // Byte1-NB
          byte1_precoding_bit = (lbyte_not_scrmbl) ? 2'b00 : data[7:6];
          for (i=8; i<NB_GEN6*8; i=i+2) begin
              case({data[i+0 +: 2],  byte1_precoding_bit})
                4'b00_10, 4'b01_01, 4'b11_11, 4'b10_00: tmp_data[i+0 +: 2] = 2'b10;
                4'b00_11, 4'b01_10, 4'b11_00, 4'b10_01: tmp_data[i+0 +: 2] = 2'b11;
                4'b00_01, 4'b01_00, 4'b11_10, 4'b10_11: tmp_data[i+0 +: 2] = 2'b01;
                default                               : tmp_data[i+0 +: 2] = 2'b00;
              endcase
              byte1_precoding_bit = data[i+0 +: 2];
          end
          gen6_rx_precode_nb = (wrd_not_scrmbl | ~precoding_en | in_ts0) ? data : tmp_data;
      end
  endfunction

  function automatic [NB_GEN6*8-1:0] gen6_graycode_nb;
      input            location; //0:XMLH,1:RMLH
      input [NB_GEN6*8-1:0] data;
      input            lbyte_not_scrmbl;
      input            wrd_not_scrmbl;
      input            in_ts0;
      input            in_ts1;
      input            in_ts2;

      integer i;
      reg  [7:0]            tmp_data_1byte;
      reg  [NB_GEN6*8-1:0]  tmp_data;
      reg  [NB_GEN6*8-1:0]  tmp_data_ts0;
      reg  [NB_GEN6-1:0]    mismatch_odd_even_bit;

      begin
          // Byte0
          for (i=0; i<8; i=i+2) begin
              tmp_data_1byte[i+0] = data[i+1] ^ data[i+0];
              tmp_data_1byte[i+1] = data[i+1];
          end
          tmp_data[7:0] = (lbyte_not_scrmbl) ? data[7:0] : tmp_data_1byte;

          // Byte1-NB 
          for (i=8; i<NB_GEN6*8; i=i+2) begin
              tmp_data[i+0] = data[i+1] ^ data[i+0];
              tmp_data[i+1] = data[i+1];
          end
          // Check to mismatch odd bit and even bit in symbol#1-6,9-14
          // If the odd bit and even bit are mismatched, TS0 symbol 0/8 is changed from 33h to C0h because no OS identifier is C0h (80h not ok as EIEOS sym0 allows up to one bit mismatch)
          // TS0 symbol 0/8 not scrambled/de-scrambled
          tmp_data_ts0 = data;
          mismatch_odd_even_bit = 0;
          for (i=1; i<NB_GEN6; i=i+1) begin
              mismatch_odd_even_bit[i] = (data[8*i+7] ^ data[8*i+6]) || (data[8*i+5] ^ data[8*i+4]) || (data[8*i+3] ^ data[8*i+2]) || (data[8*i+1] ^ data[8*i+0]);
          end
          if(|mismatch_odd_even_bit) begin
              tmp_data_ts0[7:0] = 8'hC0;
          end
          gen6_graycode_nb = (wrd_not_scrmbl) ? data :
                             (in_ts0)         ? (location) ? tmp_data_ts0 : data : 
                                                tmp_data;
      end
  endfunction

  function automatic [7:0] gen6_ts0_force_even_bit;
      input [7:0] data;

      integer i;
      reg  [7:0]       tmp_data_1byte;

      // This is done by forcing the even bit 2i to be identical to the odd bit (2i+1) [where 0<=i<=3]
      begin
          for (i=0; i<8; i=i+2) begin
              tmp_data_1byte[i+0] = data[i+1];
              tmp_data_1byte[i+1] = data[i+1];
          end

          gen6_ts0_force_even_bit = tmp_data_1byte;
      end
  endfunction

  //count pam4 1s function
  function automatic [6:0] pam4_number_1s;
      input [7:0] data_1;
      input [7:0] data_2;
      reg [3:0] pam4_add_result_1;
      reg [3:0] pam4_add_result_2;
      begin
          pam4_add_result_1 = sub_pam4_number_1s(data_1);
          pam4_add_result_2 = sub_pam4_number_1s(data_2);
          pam4_number_1s = {2'b00, ({1'b0, pam4_add_result_1} + {1'b0, pam4_add_result_2})};
      end
  endfunction

  //count pam4 0s function
  function automatic [6:0] pam4_number_0s;
      input [7:0] data_1;
      input [7:0] data_2;
      reg [3:0] pam4_add_result_1;
      reg [3:0] pam4_add_result_2;
      begin
          pam4_add_result_1 = sub_pam4_number_0s(data_1);
          pam4_add_result_2 = sub_pam4_number_0s(data_2);
          pam4_number_0s = {2'b00, ({1'b0, pam4_add_result_1} + {1'b0, pam4_add_result_2})};
      end
  endfunction

  function automatic [3:0] sub_pam4_number_1s;
      input [7:0] data;
      begin
          case(data)
//            8'b00_00_00_00: sub_pam4_number_1s = 0 + 0 + 0 + 0;
              8'b00_00_00_01: sub_pam4_number_1s = 0 + 0 + 0 + 0;
              8'b00_00_00_10: sub_pam4_number_1s = 0 + 0 + 0 + 1;
              8'b00_00_00_11: sub_pam4_number_1s = 0 + 0 + 0 + 3;
              8'b00_00_01_00: sub_pam4_number_1s = 0 + 0 + 0 + 0;
              8'b00_00_01_01: sub_pam4_number_1s = 0 + 0 + 0 + 0;
              8'b00_00_01_10: sub_pam4_number_1s = 0 + 0 + 0 + 1;
              8'b00_00_01_11: sub_pam4_number_1s = 0 + 0 + 0 + 3;
              8'b00_00_10_00: sub_pam4_number_1s = 0 + 0 + 1 + 0;
              8'b00_00_10_01: sub_pam4_number_1s = 0 + 0 + 1 + 0;
              8'b00_00_10_10: sub_pam4_number_1s = 0 + 0 + 1 + 1;
              8'b00_00_10_11: sub_pam4_number_1s = 0 + 0 + 1 + 3;
              8'b00_00_11_00: sub_pam4_number_1s = 0 + 0 + 3 + 0;
              8'b00_00_11_01: sub_pam4_number_1s = 0 + 0 + 3 + 0;
              8'b00_00_11_10: sub_pam4_number_1s = 0 + 0 + 3 + 1;
              8'b00_00_11_11: sub_pam4_number_1s = 0 + 0 + 3 + 3;
              8'b00_01_00_00: sub_pam4_number_1s = 0 + 0 + 0 + 0;
              8'b00_01_00_01: sub_pam4_number_1s = 0 + 0 + 0 + 0;
              8'b00_01_00_10: sub_pam4_number_1s = 0 + 0 + 0 + 1;
              8'b00_01_00_11: sub_pam4_number_1s = 0 + 0 + 0 + 3;
              8'b00_01_01_00: sub_pam4_number_1s = 0 + 0 + 0 + 0;
              8'b00_01_01_01: sub_pam4_number_1s = 0 + 0 + 0 + 0;
              8'b00_01_01_10: sub_pam4_number_1s = 0 + 0 + 0 + 1;
              8'b00_01_01_11: sub_pam4_number_1s = 0 + 0 + 0 + 3;
              8'b00_01_10_00: sub_pam4_number_1s = 0 + 0 + 1 + 0;
              8'b00_01_10_01: sub_pam4_number_1s = 0 + 0 + 1 + 0;
              8'b00_01_10_10: sub_pam4_number_1s = 0 + 0 + 1 + 1;
              8'b00_01_10_11: sub_pam4_number_1s = 0 + 0 + 1 + 3;
              8'b00_01_11_00: sub_pam4_number_1s = 0 + 0 + 3 + 0;
              8'b00_01_11_01: sub_pam4_number_1s = 0 + 0 + 3 + 0;
              8'b00_01_11_10: sub_pam4_number_1s = 0 + 0 + 3 + 1;
              8'b00_01_11_11: sub_pam4_number_1s = 0 + 0 + 3 + 3;
              8'b00_10_00_00: sub_pam4_number_1s = 0 + 1 + 0 + 0;
              8'b00_10_00_01: sub_pam4_number_1s = 0 + 1 + 0 + 0;
              8'b00_10_00_10: sub_pam4_number_1s = 0 + 1 + 0 + 1;
              8'b00_10_00_11: sub_pam4_number_1s = 0 + 1 + 0 + 3;
              8'b00_10_01_00: sub_pam4_number_1s = 0 + 1 + 0 + 0;
              8'b00_10_01_01: sub_pam4_number_1s = 0 + 1 + 0 + 0;
              8'b00_10_01_10: sub_pam4_number_1s = 0 + 1 + 0 + 1;
              8'b00_10_01_11: sub_pam4_number_1s = 0 + 1 + 0 + 3;
              8'b00_10_10_00: sub_pam4_number_1s = 0 + 1 + 1 + 0;
              8'b00_10_10_01: sub_pam4_number_1s = 0 + 1 + 1 + 0;
              8'b00_10_10_10: sub_pam4_number_1s = 0 + 1 + 1 + 1;
              8'b00_10_10_11: sub_pam4_number_1s = 0 + 1 + 1 + 3;
              8'b00_10_11_00: sub_pam4_number_1s = 0 + 1 + 3 + 0;
              8'b00_10_11_01: sub_pam4_number_1s = 0 + 1 + 3 + 0;
              8'b00_10_11_10: sub_pam4_number_1s = 0 + 1 + 3 + 1;
              8'b00_10_11_11: sub_pam4_number_1s = 0 + 1 + 3 + 3;
              8'b00_11_00_00: sub_pam4_number_1s = 0 + 3 + 0 + 0;
              8'b00_11_00_01: sub_pam4_number_1s = 0 + 3 + 0 + 0;
              8'b00_11_00_10: sub_pam4_number_1s = 0 + 3 + 0 + 1;
              8'b00_11_00_11: sub_pam4_number_1s = 0 + 3 + 0 + 3;
              8'b00_11_01_00: sub_pam4_number_1s = 0 + 3 + 0 + 0;
              8'b00_11_01_01: sub_pam4_number_1s = 0 + 3 + 0 + 0;
              8'b00_11_01_10: sub_pam4_number_1s = 0 + 3 + 0 + 1;
              8'b00_11_01_11: sub_pam4_number_1s = 0 + 3 + 0 + 3;
              8'b00_11_10_00: sub_pam4_number_1s = 0 + 3 + 1 + 0;
              8'b00_11_10_01: sub_pam4_number_1s = 0 + 3 + 1 + 0;
              8'b00_11_10_10: sub_pam4_number_1s = 0 + 3 + 1 + 1;
              8'b00_11_10_11: sub_pam4_number_1s = 0 + 3 + 1 + 3;
              8'b00_11_11_00: sub_pam4_number_1s = 0 + 3 + 3 + 0;
              8'b00_11_11_01: sub_pam4_number_1s = 0 + 3 + 3 + 0;
              8'b00_11_11_10: sub_pam4_number_1s = 0 + 3 + 3 + 1;
              8'b00_11_11_11: sub_pam4_number_1s = 0 + 3 + 3 + 3;
              8'b01_00_00_00: sub_pam4_number_1s = 0 + 0 + 0 + 0;
              8'b01_00_00_01: sub_pam4_number_1s = 0 + 0 + 0 + 0;
              8'b01_00_00_10: sub_pam4_number_1s = 0 + 0 + 0 + 1;
              8'b01_00_00_11: sub_pam4_number_1s = 0 + 0 + 0 + 3;
              8'b01_00_01_00: sub_pam4_number_1s = 0 + 0 + 0 + 0;
              8'b01_00_01_01: sub_pam4_number_1s = 0 + 0 + 0 + 0;
              8'b01_00_01_10: sub_pam4_number_1s = 0 + 0 + 0 + 1;
              8'b01_00_01_11: sub_pam4_number_1s = 0 + 0 + 0 + 3;
              8'b01_00_10_00: sub_pam4_number_1s = 0 + 0 + 1 + 0;
              8'b01_00_10_01: sub_pam4_number_1s = 0 + 0 + 1 + 0;
              8'b01_00_10_10: sub_pam4_number_1s = 0 + 0 + 1 + 1;
              8'b01_00_10_11: sub_pam4_number_1s = 0 + 0 + 1 + 3;
              8'b01_00_11_00: sub_pam4_number_1s = 0 + 0 + 3 + 0;
              8'b01_00_11_01: sub_pam4_number_1s = 0 + 0 + 3 + 0;
              8'b01_00_11_10: sub_pam4_number_1s = 0 + 0 + 3 + 1;
              8'b01_00_11_11: sub_pam4_number_1s = 0 + 0 + 3 + 3;
              8'b01_01_00_00: sub_pam4_number_1s = 0 + 0 + 0 + 0;
              8'b01_01_00_01: sub_pam4_number_1s = 0 + 0 + 0 + 0;
              8'b01_01_00_10: sub_pam4_number_1s = 0 + 0 + 0 + 1;
              8'b01_01_00_11: sub_pam4_number_1s = 0 + 0 + 0 + 3;
              8'b01_01_01_00: sub_pam4_number_1s = 0 + 0 + 0 + 0;
              8'b01_01_01_01: sub_pam4_number_1s = 0 + 0 + 0 + 0;
              8'b01_01_01_10: sub_pam4_number_1s = 0 + 0 + 0 + 1;
              8'b01_01_01_11: sub_pam4_number_1s = 0 + 0 + 0 + 3;
              8'b01_01_10_00: sub_pam4_number_1s = 0 + 0 + 1 + 0;
              8'b01_01_10_01: sub_pam4_number_1s = 0 + 0 + 1 + 0;
              8'b01_01_10_10: sub_pam4_number_1s = 0 + 0 + 1 + 1;
              8'b01_01_10_11: sub_pam4_number_1s = 0 + 0 + 1 + 3;
              8'b01_01_11_00: sub_pam4_number_1s = 0 + 0 + 3 + 0;
              8'b01_01_11_01: sub_pam4_number_1s = 0 + 0 + 3 + 0;
              8'b01_01_11_10: sub_pam4_number_1s = 0 + 0 + 3 + 1;
              8'b01_01_11_11: sub_pam4_number_1s = 0 + 0 + 3 + 3;
              8'b01_10_00_00: sub_pam4_number_1s = 0 + 1 + 0 + 0;
              8'b01_10_00_01: sub_pam4_number_1s = 0 + 1 + 0 + 0;
              8'b01_10_00_10: sub_pam4_number_1s = 0 + 1 + 0 + 1;
              8'b01_10_00_11: sub_pam4_number_1s = 0 + 1 + 0 + 3;
              8'b01_10_01_00: sub_pam4_number_1s = 0 + 1 + 0 + 0;
              8'b01_10_01_01: sub_pam4_number_1s = 0 + 1 + 0 + 0;
              8'b01_10_01_10: sub_pam4_number_1s = 0 + 1 + 0 + 1;
              8'b01_10_01_11: sub_pam4_number_1s = 0 + 1 + 0 + 3;
              8'b01_10_10_00: sub_pam4_number_1s = 0 + 1 + 1 + 0;
              8'b01_10_10_01: sub_pam4_number_1s = 0 + 1 + 1 + 0;
              8'b01_10_10_10: sub_pam4_number_1s = 0 + 1 + 1 + 1;
              8'b01_10_10_11: sub_pam4_number_1s = 0 + 1 + 1 + 3;
              8'b01_10_11_00: sub_pam4_number_1s = 0 + 1 + 3 + 0;
              8'b01_10_11_01: sub_pam4_number_1s = 0 + 1 + 3 + 0;
              8'b01_10_11_10: sub_pam4_number_1s = 0 + 1 + 3 + 1;
              8'b01_10_11_11: sub_pam4_number_1s = 0 + 1 + 3 + 3;
              8'b01_11_00_00: sub_pam4_number_1s = 0 + 3 + 0 + 0;
              8'b01_11_00_01: sub_pam4_number_1s = 0 + 3 + 0 + 0;
              8'b01_11_00_10: sub_pam4_number_1s = 0 + 3 + 0 + 1;
              8'b01_11_00_11: sub_pam4_number_1s = 0 + 3 + 0 + 3;
              8'b01_11_01_00: sub_pam4_number_1s = 0 + 3 + 0 + 0;
              8'b01_11_01_01: sub_pam4_number_1s = 0 + 3 + 0 + 0;
              8'b01_11_01_10: sub_pam4_number_1s = 0 + 3 + 0 + 1;
              8'b01_11_01_11: sub_pam4_number_1s = 0 + 3 + 0 + 3;
              8'b01_11_10_00: sub_pam4_number_1s = 0 + 3 + 1 + 0;
              8'b01_11_10_01: sub_pam4_number_1s = 0 + 3 + 1 + 0;
              8'b01_11_10_10: sub_pam4_number_1s = 0 + 3 + 1 + 1;
              8'b01_11_10_11: sub_pam4_number_1s = 0 + 3 + 1 + 3;
              8'b01_11_11_00: sub_pam4_number_1s = 0 + 3 + 3 + 0;
              8'b01_11_11_01: sub_pam4_number_1s = 0 + 3 + 3 + 0;
              8'b01_11_11_10: sub_pam4_number_1s = 0 + 3 + 3 + 1;
              8'b01_11_11_11: sub_pam4_number_1s = 0 + 3 + 3 + 3;
              8'b10_00_00_00: sub_pam4_number_1s = 1 + 0 + 0 + 0;
              8'b10_00_00_01: sub_pam4_number_1s = 1 + 0 + 0 + 0;
              8'b10_00_00_10: sub_pam4_number_1s = 1 + 0 + 0 + 1;
              8'b10_00_00_11: sub_pam4_number_1s = 1 + 0 + 0 + 3;
              8'b10_00_01_00: sub_pam4_number_1s = 1 + 0 + 0 + 0;
              8'b10_00_01_01: sub_pam4_number_1s = 1 + 0 + 0 + 0;
              8'b10_00_01_10: sub_pam4_number_1s = 1 + 0 + 0 + 1;
              8'b10_00_01_11: sub_pam4_number_1s = 1 + 0 + 0 + 3;
              8'b10_00_10_00: sub_pam4_number_1s = 1 + 0 + 1 + 0;
              8'b10_00_10_01: sub_pam4_number_1s = 1 + 0 + 1 + 0;
              8'b10_00_10_10: sub_pam4_number_1s = 1 + 0 + 1 + 1;
              8'b10_00_10_11: sub_pam4_number_1s = 1 + 0 + 1 + 3;
              8'b10_00_11_00: sub_pam4_number_1s = 1 + 0 + 3 + 0;
              8'b10_00_11_01: sub_pam4_number_1s = 1 + 0 + 3 + 0;
              8'b10_00_11_10: sub_pam4_number_1s = 1 + 0 + 3 + 1;
              8'b10_00_11_11: sub_pam4_number_1s = 1 + 0 + 3 + 3;
              8'b10_01_00_00: sub_pam4_number_1s = 1 + 0 + 0 + 0;
              8'b10_01_00_01: sub_pam4_number_1s = 1 + 0 + 0 + 0;
              8'b10_01_00_10: sub_pam4_number_1s = 1 + 0 + 0 + 1;
              8'b10_01_00_11: sub_pam4_number_1s = 1 + 0 + 0 + 3;
              8'b10_01_01_00: sub_pam4_number_1s = 1 + 0 + 0 + 0;
              8'b10_01_01_01: sub_pam4_number_1s = 1 + 0 + 0 + 0;
              8'b10_01_01_10: sub_pam4_number_1s = 1 + 0 + 0 + 1;
              8'b10_01_01_11: sub_pam4_number_1s = 1 + 0 + 0 + 3;
              8'b10_01_10_00: sub_pam4_number_1s = 1 + 0 + 1 + 0;
              8'b10_01_10_01: sub_pam4_number_1s = 1 + 0 + 1 + 0;
              8'b10_01_10_10: sub_pam4_number_1s = 1 + 0 + 1 + 1;
              8'b10_01_10_11: sub_pam4_number_1s = 1 + 0 + 1 + 3;
              8'b10_01_11_00: sub_pam4_number_1s = 1 + 0 + 3 + 0;
              8'b10_01_11_01: sub_pam4_number_1s = 1 + 0 + 3 + 0;
              8'b10_01_11_10: sub_pam4_number_1s = 1 + 0 + 3 + 1;
              8'b10_01_11_11: sub_pam4_number_1s = 1 + 0 + 3 + 3;
              8'b10_10_00_00: sub_pam4_number_1s = 1 + 1 + 0 + 0;
              8'b10_10_00_01: sub_pam4_number_1s = 1 + 1 + 0 + 0;
              8'b10_10_00_10: sub_pam4_number_1s = 1 + 1 + 0 + 1;
              8'b10_10_00_11: sub_pam4_number_1s = 1 + 1 + 0 + 3;
              8'b10_10_01_00: sub_pam4_number_1s = 1 + 1 + 0 + 0;
              8'b10_10_01_01: sub_pam4_number_1s = 1 + 1 + 0 + 0;
              8'b10_10_01_10: sub_pam4_number_1s = 1 + 1 + 0 + 1;
              8'b10_10_01_11: sub_pam4_number_1s = 1 + 1 + 0 + 3;
              8'b10_10_10_00: sub_pam4_number_1s = 1 + 1 + 1 + 0;
              8'b10_10_10_01: sub_pam4_number_1s = 1 + 1 + 1 + 0;
              8'b10_10_10_10: sub_pam4_number_1s = 1 + 1 + 1 + 1;
              8'b10_10_10_11: sub_pam4_number_1s = 1 + 1 + 1 + 3;
              8'b10_10_11_00: sub_pam4_number_1s = 1 + 1 + 3 + 0;
              8'b10_10_11_01: sub_pam4_number_1s = 1 + 1 + 3 + 0;
              8'b10_10_11_10: sub_pam4_number_1s = 1 + 1 + 3 + 1;
              8'b10_10_11_11: sub_pam4_number_1s = 1 + 1 + 3 + 3;
              8'b10_11_00_00: sub_pam4_number_1s = 1 + 3 + 0 + 0;
              8'b10_11_00_01: sub_pam4_number_1s = 1 + 3 + 0 + 0;
              8'b10_11_00_10: sub_pam4_number_1s = 1 + 3 + 0 + 1;
              8'b10_11_00_11: sub_pam4_number_1s = 1 + 3 + 0 + 3;
              8'b10_11_01_00: sub_pam4_number_1s = 1 + 3 + 0 + 0;
              8'b10_11_01_01: sub_pam4_number_1s = 1 + 3 + 0 + 0;
              8'b10_11_01_10: sub_pam4_number_1s = 1 + 3 + 0 + 1;
              8'b10_11_01_11: sub_pam4_number_1s = 1 + 3 + 0 + 3;
              8'b10_11_10_00: sub_pam4_number_1s = 1 + 3 + 1 + 0;
              8'b10_11_10_01: sub_pam4_number_1s = 1 + 3 + 1 + 0;
              8'b10_11_10_10: sub_pam4_number_1s = 1 + 3 + 1 + 1;
              8'b10_11_10_11: sub_pam4_number_1s = 1 + 3 + 1 + 3;
              8'b10_11_11_00: sub_pam4_number_1s = 1 + 3 + 3 + 0;
              8'b10_11_11_01: sub_pam4_number_1s = 1 + 3 + 3 + 0;
              8'b10_11_11_10: sub_pam4_number_1s = 1 + 3 + 3 + 1;
              8'b10_11_11_11: sub_pam4_number_1s = 1 + 3 + 3 + 3;
              8'b11_00_00_00: sub_pam4_number_1s = 3 + 0 + 0 + 0;
              8'b11_00_00_01: sub_pam4_number_1s = 3 + 0 + 0 + 0;
              8'b11_00_00_10: sub_pam4_number_1s = 3 + 0 + 0 + 1;
              8'b11_00_00_11: sub_pam4_number_1s = 3 + 0 + 0 + 3;
              8'b11_00_01_00: sub_pam4_number_1s = 3 + 0 + 0 + 0;
              8'b11_00_01_01: sub_pam4_number_1s = 3 + 0 + 0 + 0;
              8'b11_00_01_10: sub_pam4_number_1s = 3 + 0 + 0 + 1;
              8'b11_00_01_11: sub_pam4_number_1s = 3 + 0 + 0 + 3;
              8'b11_00_10_00: sub_pam4_number_1s = 3 + 0 + 1 + 0;
              8'b11_00_10_01: sub_pam4_number_1s = 3 + 0 + 1 + 0;
              8'b11_00_10_10: sub_pam4_number_1s = 3 + 0 + 1 + 1;
              8'b11_00_10_11: sub_pam4_number_1s = 3 + 0 + 1 + 3;
              8'b11_00_11_00: sub_pam4_number_1s = 3 + 0 + 3 + 0;
              8'b11_00_11_01: sub_pam4_number_1s = 3 + 0 + 3 + 0;
              8'b11_00_11_10: sub_pam4_number_1s = 3 + 0 + 3 + 1;
              8'b11_00_11_11: sub_pam4_number_1s = 3 + 0 + 3 + 3;
              8'b11_01_00_00: sub_pam4_number_1s = 3 + 0 + 0 + 0;
              8'b11_01_00_01: sub_pam4_number_1s = 3 + 0 + 0 + 0;
              8'b11_01_00_10: sub_pam4_number_1s = 3 + 0 + 0 + 1;
              8'b11_01_00_11: sub_pam4_number_1s = 3 + 0 + 0 + 3;
              8'b11_01_01_00: sub_pam4_number_1s = 3 + 0 + 0 + 0;
              8'b11_01_01_01: sub_pam4_number_1s = 3 + 0 + 0 + 0;
              8'b11_01_01_10: sub_pam4_number_1s = 3 + 0 + 0 + 1;
              8'b11_01_01_11: sub_pam4_number_1s = 3 + 0 + 0 + 3;
              8'b11_01_10_00: sub_pam4_number_1s = 3 + 0 + 1 + 0;
              8'b11_01_10_01: sub_pam4_number_1s = 3 + 0 + 1 + 0;
              8'b11_01_10_10: sub_pam4_number_1s = 3 + 0 + 1 + 1;
              8'b11_01_10_11: sub_pam4_number_1s = 3 + 0 + 1 + 3;
              8'b11_01_11_00: sub_pam4_number_1s = 3 + 0 + 3 + 0;
              8'b11_01_11_01: sub_pam4_number_1s = 3 + 0 + 3 + 0;
              8'b11_01_11_10: sub_pam4_number_1s = 3 + 0 + 3 + 1;
              8'b11_01_11_11: sub_pam4_number_1s = 3 + 0 + 3 + 3;
              8'b11_10_00_00: sub_pam4_number_1s = 3 + 1 + 0 + 0;
              8'b11_10_00_01: sub_pam4_number_1s = 3 + 1 + 0 + 0;
              8'b11_10_00_10: sub_pam4_number_1s = 3 + 1 + 0 + 1;
              8'b11_10_00_11: sub_pam4_number_1s = 3 + 1 + 0 + 3;
              8'b11_10_01_00: sub_pam4_number_1s = 3 + 1 + 0 + 0;
              8'b11_10_01_01: sub_pam4_number_1s = 3 + 1 + 0 + 0;
              8'b11_10_01_10: sub_pam4_number_1s = 3 + 1 + 0 + 1;
              8'b11_10_01_11: sub_pam4_number_1s = 3 + 1 + 0 + 3;
              8'b11_10_10_00: sub_pam4_number_1s = 3 + 1 + 1 + 0;
              8'b11_10_10_01: sub_pam4_number_1s = 3 + 1 + 1 + 0;
              8'b11_10_10_10: sub_pam4_number_1s = 3 + 1 + 1 + 1;
              8'b11_10_10_11: sub_pam4_number_1s = 3 + 1 + 1 + 3;
              8'b11_10_11_00: sub_pam4_number_1s = 3 + 1 + 3 + 0;
              8'b11_10_11_01: sub_pam4_number_1s = 3 + 1 + 3 + 0;
              8'b11_10_11_10: sub_pam4_number_1s = 3 + 1 + 3 + 1;
              8'b11_10_11_11: sub_pam4_number_1s = 3 + 1 + 3 + 3;
              8'b11_11_00_00: sub_pam4_number_1s = 3 + 3 + 0 + 0;
              8'b11_11_00_01: sub_pam4_number_1s = 3 + 3 + 0 + 0;
              8'b11_11_00_10: sub_pam4_number_1s = 3 + 3 + 0 + 1;
              8'b11_11_00_11: sub_pam4_number_1s = 3 + 3 + 0 + 3;
              8'b11_11_01_00: sub_pam4_number_1s = 3 + 3 + 0 + 0;
              8'b11_11_01_01: sub_pam4_number_1s = 3 + 3 + 0 + 0;
              8'b11_11_01_10: sub_pam4_number_1s = 3 + 3 + 0 + 1;
              8'b11_11_01_11: sub_pam4_number_1s = 3 + 3 + 0 + 3;
              8'b11_11_10_00: sub_pam4_number_1s = 3 + 3 + 1 + 0;
              8'b11_11_10_01: sub_pam4_number_1s = 3 + 3 + 1 + 0;
              8'b11_11_10_10: sub_pam4_number_1s = 3 + 3 + 1 + 1;
              8'b11_11_10_11: sub_pam4_number_1s = 3 + 3 + 1 + 3;
              8'b11_11_11_00: sub_pam4_number_1s = 3 + 3 + 3 + 0;
              8'b11_11_11_01: sub_pam4_number_1s = 3 + 3 + 3 + 0;
              8'b11_11_11_10: sub_pam4_number_1s = 3 + 3 + 3 + 1;
              8'b11_11_11_11: sub_pam4_number_1s = 3 + 3 + 3 + 3;
              default       : sub_pam4_number_1s = 0 + 0 + 0 + 0;
          endcase
      end
  endfunction

  function automatic [3:0] sub_pam4_number_0s;
      input [7:0] data;
      begin
          case(data)
//            8'b00_00_00_00: sub_pam4_number_0s = 3 + 3 + 3 + 3;
              8'b00_00_00_01: sub_pam4_number_0s = 3 + 3 + 3 + 1;
              8'b00_00_00_10: sub_pam4_number_0s = 3 + 3 + 3 + 0;
              8'b00_00_00_11: sub_pam4_number_0s = 3 + 3 + 3 + 0;
              8'b00_00_01_00: sub_pam4_number_0s = 3 + 3 + 1 + 3;
              8'b00_00_01_01: sub_pam4_number_0s = 3 + 3 + 1 + 1;
              8'b00_00_01_10: sub_pam4_number_0s = 3 + 3 + 1 + 0;
              8'b00_00_01_11: sub_pam4_number_0s = 3 + 3 + 1 + 0;
              8'b00_00_10_00: sub_pam4_number_0s = 3 + 3 + 0 + 3;
              8'b00_00_10_01: sub_pam4_number_0s = 3 + 3 + 0 + 1;
              8'b00_00_10_10: sub_pam4_number_0s = 3 + 3 + 0 + 0;
              8'b00_00_10_11: sub_pam4_number_0s = 3 + 3 + 0 + 0;
              8'b00_00_11_00: sub_pam4_number_0s = 3 + 3 + 0 + 3;
              8'b00_00_11_01: sub_pam4_number_0s = 3 + 3 + 0 + 1;
              8'b00_00_11_10: sub_pam4_number_0s = 3 + 3 + 0 + 0;
              8'b00_00_11_11: sub_pam4_number_0s = 3 + 3 + 0 + 0;
              8'b00_01_00_00: sub_pam4_number_0s = 3 + 1 + 3 + 3;
              8'b00_01_00_01: sub_pam4_number_0s = 3 + 1 + 3 + 1;
              8'b00_01_00_10: sub_pam4_number_0s = 3 + 1 + 3 + 0;
              8'b00_01_00_11: sub_pam4_number_0s = 3 + 1 + 3 + 0;
              8'b00_01_01_00: sub_pam4_number_0s = 3 + 1 + 1 + 3;
              8'b00_01_01_01: sub_pam4_number_0s = 3 + 1 + 1 + 1;
              8'b00_01_01_10: sub_pam4_number_0s = 3 + 1 + 1 + 0;
              8'b00_01_01_11: sub_pam4_number_0s = 3 + 1 + 1 + 0;
              8'b00_01_10_00: sub_pam4_number_0s = 3 + 1 + 0 + 3;
              8'b00_01_10_01: sub_pam4_number_0s = 3 + 1 + 0 + 1;
              8'b00_01_10_10: sub_pam4_number_0s = 3 + 1 + 0 + 0;
              8'b00_01_10_11: sub_pam4_number_0s = 3 + 1 + 0 + 0;
              8'b00_01_11_00: sub_pam4_number_0s = 3 + 1 + 0 + 3;
              8'b00_01_11_01: sub_pam4_number_0s = 3 + 1 + 0 + 1;
              8'b00_01_11_10: sub_pam4_number_0s = 3 + 1 + 0 + 0;
              8'b00_01_11_11: sub_pam4_number_0s = 3 + 1 + 0 + 0;
              8'b00_10_00_00: sub_pam4_number_0s = 3 + 0 + 3 + 3;
              8'b00_10_00_01: sub_pam4_number_0s = 3 + 0 + 3 + 1;
              8'b00_10_00_10: sub_pam4_number_0s = 3 + 0 + 3 + 0;
              8'b00_10_00_11: sub_pam4_number_0s = 3 + 0 + 3 + 0;
              8'b00_10_01_00: sub_pam4_number_0s = 3 + 0 + 1 + 3;
              8'b00_10_01_01: sub_pam4_number_0s = 3 + 0 + 1 + 1;
              8'b00_10_01_10: sub_pam4_number_0s = 3 + 0 + 1 + 0;
              8'b00_10_01_11: sub_pam4_number_0s = 3 + 0 + 1 + 0;
              8'b00_10_10_00: sub_pam4_number_0s = 3 + 0 + 0 + 3;
              8'b00_10_10_01: sub_pam4_number_0s = 3 + 0 + 0 + 1;
              8'b00_10_10_10: sub_pam4_number_0s = 3 + 0 + 0 + 0;
              8'b00_10_10_11: sub_pam4_number_0s = 3 + 0 + 0 + 0;
              8'b00_10_11_00: sub_pam4_number_0s = 3 + 0 + 0 + 3;
              8'b00_10_11_01: sub_pam4_number_0s = 3 + 0 + 0 + 1;
              8'b00_10_11_10: sub_pam4_number_0s = 3 + 0 + 0 + 0;
              8'b00_10_11_11: sub_pam4_number_0s = 3 + 0 + 0 + 0;
              8'b00_11_00_00: sub_pam4_number_0s = 3 + 0 + 3 + 3;
              8'b00_11_00_01: sub_pam4_number_0s = 3 + 0 + 3 + 1;
              8'b00_11_00_10: sub_pam4_number_0s = 3 + 0 + 3 + 0;
              8'b00_11_00_11: sub_pam4_number_0s = 3 + 0 + 3 + 0;
              8'b00_11_01_00: sub_pam4_number_0s = 3 + 0 + 1 + 3;
              8'b00_11_01_01: sub_pam4_number_0s = 3 + 0 + 1 + 1;
              8'b00_11_01_10: sub_pam4_number_0s = 3 + 0 + 1 + 0;
              8'b00_11_01_11: sub_pam4_number_0s = 3 + 0 + 1 + 0;
              8'b00_11_10_00: sub_pam4_number_0s = 3 + 0 + 0 + 3;
              8'b00_11_10_01: sub_pam4_number_0s = 3 + 0 + 0 + 1;
              8'b00_11_10_10: sub_pam4_number_0s = 3 + 0 + 0 + 0;
              8'b00_11_10_11: sub_pam4_number_0s = 3 + 0 + 0 + 0;
              8'b00_11_11_00: sub_pam4_number_0s = 3 + 0 + 0 + 3;
              8'b00_11_11_01: sub_pam4_number_0s = 3 + 0 + 0 + 1;
              8'b00_11_11_10: sub_pam4_number_0s = 3 + 0 + 0 + 0;
              8'b00_11_11_11: sub_pam4_number_0s = 3 + 0 + 0 + 0;
              8'b01_00_00_00: sub_pam4_number_0s = 1 + 3 + 3 + 3;
              8'b01_00_00_01: sub_pam4_number_0s = 1 + 3 + 3 + 1;
              8'b01_00_00_10: sub_pam4_number_0s = 1 + 3 + 3 + 0;
              8'b01_00_00_11: sub_pam4_number_0s = 1 + 3 + 3 + 0;
              8'b01_00_01_00: sub_pam4_number_0s = 1 + 3 + 1 + 3;
              8'b01_00_01_01: sub_pam4_number_0s = 1 + 3 + 1 + 1;
              8'b01_00_01_10: sub_pam4_number_0s = 1 + 3 + 1 + 0;
              8'b01_00_01_11: sub_pam4_number_0s = 1 + 3 + 1 + 0;
              8'b01_00_10_00: sub_pam4_number_0s = 1 + 3 + 0 + 3;
              8'b01_00_10_01: sub_pam4_number_0s = 1 + 3 + 0 + 1;
              8'b01_00_10_10: sub_pam4_number_0s = 1 + 3 + 0 + 0;
              8'b01_00_10_11: sub_pam4_number_0s = 1 + 3 + 0 + 0;
              8'b01_00_11_00: sub_pam4_number_0s = 1 + 3 + 0 + 3;
              8'b01_00_11_01: sub_pam4_number_0s = 1 + 3 + 0 + 1;
              8'b01_00_11_10: sub_pam4_number_0s = 1 + 3 + 0 + 0;
              8'b01_00_11_11: sub_pam4_number_0s = 1 + 3 + 0 + 0;
              8'b01_01_00_00: sub_pam4_number_0s = 1 + 1 + 3 + 3;
              8'b01_01_00_01: sub_pam4_number_0s = 1 + 1 + 3 + 1;
              8'b01_01_00_10: sub_pam4_number_0s = 1 + 1 + 3 + 0;
              8'b01_01_00_11: sub_pam4_number_0s = 1 + 1 + 3 + 0;
              8'b01_01_01_00: sub_pam4_number_0s = 1 + 1 + 1 + 3;
              8'b01_01_01_01: sub_pam4_number_0s = 1 + 1 + 1 + 1;
              8'b01_01_01_10: sub_pam4_number_0s = 1 + 1 + 1 + 0;
              8'b01_01_01_11: sub_pam4_number_0s = 1 + 1 + 1 + 0;
              8'b01_01_10_00: sub_pam4_number_0s = 1 + 1 + 0 + 3;
              8'b01_01_10_01: sub_pam4_number_0s = 1 + 1 + 0 + 1;
              8'b01_01_10_10: sub_pam4_number_0s = 1 + 1 + 0 + 0;
              8'b01_01_10_11: sub_pam4_number_0s = 1 + 1 + 0 + 0;
              8'b01_01_11_00: sub_pam4_number_0s = 1 + 1 + 0 + 3;
              8'b01_01_11_01: sub_pam4_number_0s = 1 + 1 + 0 + 1;
              8'b01_01_11_10: sub_pam4_number_0s = 1 + 1 + 0 + 0;
              8'b01_01_11_11: sub_pam4_number_0s = 1 + 1 + 0 + 0;
              8'b01_10_00_00: sub_pam4_number_0s = 1 + 0 + 3 + 3;
              8'b01_10_00_01: sub_pam4_number_0s = 1 + 0 + 3 + 1;
              8'b01_10_00_10: sub_pam4_number_0s = 1 + 0 + 3 + 0;
              8'b01_10_00_11: sub_pam4_number_0s = 1 + 0 + 3 + 0;
              8'b01_10_01_00: sub_pam4_number_0s = 1 + 0 + 1 + 3;
              8'b01_10_01_01: sub_pam4_number_0s = 1 + 0 + 1 + 1;
              8'b01_10_01_10: sub_pam4_number_0s = 1 + 0 + 1 + 0;
              8'b01_10_01_11: sub_pam4_number_0s = 1 + 0 + 1 + 0;
              8'b01_10_10_00: sub_pam4_number_0s = 1 + 0 + 0 + 3;
              8'b01_10_10_01: sub_pam4_number_0s = 1 + 0 + 0 + 1;
              8'b01_10_10_10: sub_pam4_number_0s = 1 + 0 + 0 + 0;
              8'b01_10_10_11: sub_pam4_number_0s = 1 + 0 + 0 + 0;
              8'b01_10_11_00: sub_pam4_number_0s = 1 + 0 + 0 + 3;
              8'b01_10_11_01: sub_pam4_number_0s = 1 + 0 + 0 + 1;
              8'b01_10_11_10: sub_pam4_number_0s = 1 + 0 + 0 + 0;
              8'b01_10_11_11: sub_pam4_number_0s = 1 + 0 + 0 + 0;
              8'b01_11_00_00: sub_pam4_number_0s = 1 + 0 + 3 + 3;
              8'b01_11_00_01: sub_pam4_number_0s = 1 + 0 + 3 + 1;
              8'b01_11_00_10: sub_pam4_number_0s = 1 + 0 + 3 + 0;
              8'b01_11_00_11: sub_pam4_number_0s = 1 + 0 + 3 + 0;
              8'b01_11_01_00: sub_pam4_number_0s = 1 + 0 + 1 + 3;
              8'b01_11_01_01: sub_pam4_number_0s = 1 + 0 + 1 + 1;
              8'b01_11_01_10: sub_pam4_number_0s = 1 + 0 + 1 + 0;
              8'b01_11_01_11: sub_pam4_number_0s = 1 + 0 + 1 + 0;
              8'b01_11_10_00: sub_pam4_number_0s = 1 + 0 + 0 + 3;
              8'b01_11_10_01: sub_pam4_number_0s = 1 + 0 + 0 + 1;
              8'b01_11_10_10: sub_pam4_number_0s = 1 + 0 + 0 + 0;
              8'b01_11_10_11: sub_pam4_number_0s = 1 + 0 + 0 + 0;
              8'b01_11_11_00: sub_pam4_number_0s = 1 + 0 + 0 + 3;
              8'b01_11_11_01: sub_pam4_number_0s = 1 + 0 + 0 + 1;
              8'b01_11_11_10: sub_pam4_number_0s = 1 + 0 + 0 + 0;
              8'b01_11_11_11: sub_pam4_number_0s = 1 + 0 + 0 + 0;
              8'b10_00_00_00: sub_pam4_number_0s = 0 + 3 + 3 + 3;
              8'b10_00_00_01: sub_pam4_number_0s = 0 + 3 + 3 + 1;
              8'b10_00_00_10: sub_pam4_number_0s = 0 + 3 + 3 + 0;
              8'b10_00_00_11: sub_pam4_number_0s = 0 + 3 + 3 + 0;
              8'b10_00_01_00: sub_pam4_number_0s = 0 + 3 + 1 + 3;
              8'b10_00_01_01: sub_pam4_number_0s = 0 + 3 + 1 + 1;
              8'b10_00_01_10: sub_pam4_number_0s = 0 + 3 + 1 + 0;
              8'b10_00_01_11: sub_pam4_number_0s = 0 + 3 + 1 + 0;
              8'b10_00_10_00: sub_pam4_number_0s = 0 + 3 + 0 + 3;
              8'b10_00_10_01: sub_pam4_number_0s = 0 + 3 + 0 + 1;
              8'b10_00_10_10: sub_pam4_number_0s = 0 + 3 + 0 + 0;
              8'b10_00_10_11: sub_pam4_number_0s = 0 + 3 + 0 + 0;
              8'b10_00_11_00: sub_pam4_number_0s = 0 + 3 + 0 + 3;
              8'b10_00_11_01: sub_pam4_number_0s = 0 + 3 + 0 + 1;
              8'b10_00_11_10: sub_pam4_number_0s = 0 + 3 + 0 + 0;
              8'b10_00_11_11: sub_pam4_number_0s = 0 + 3 + 0 + 0;
              8'b10_01_00_00: sub_pam4_number_0s = 0 + 1 + 3 + 3;
              8'b10_01_00_01: sub_pam4_number_0s = 0 + 1 + 3 + 1;
              8'b10_01_00_10: sub_pam4_number_0s = 0 + 1 + 3 + 0;
              8'b10_01_00_11: sub_pam4_number_0s = 0 + 1 + 3 + 0;
              8'b10_01_01_00: sub_pam4_number_0s = 0 + 1 + 1 + 3;
              8'b10_01_01_01: sub_pam4_number_0s = 0 + 1 + 1 + 1;
              8'b10_01_01_10: sub_pam4_number_0s = 0 + 1 + 1 + 0;
              8'b10_01_01_11: sub_pam4_number_0s = 0 + 1 + 1 + 0;
              8'b10_01_10_00: sub_pam4_number_0s = 0 + 1 + 0 + 3;
              8'b10_01_10_01: sub_pam4_number_0s = 0 + 1 + 0 + 1;
              8'b10_01_10_10: sub_pam4_number_0s = 0 + 1 + 0 + 0;
              8'b10_01_10_11: sub_pam4_number_0s = 0 + 1 + 0 + 0;
              8'b10_01_11_00: sub_pam4_number_0s = 0 + 1 + 0 + 3;
              8'b10_01_11_01: sub_pam4_number_0s = 0 + 1 + 0 + 1;
              8'b10_01_11_10: sub_pam4_number_0s = 0 + 1 + 0 + 0;
              8'b10_01_11_11: sub_pam4_number_0s = 0 + 1 + 0 + 0;
              8'b10_10_00_00: sub_pam4_number_0s = 0 + 0 + 3 + 3;
              8'b10_10_00_01: sub_pam4_number_0s = 0 + 0 + 3 + 1;
              8'b10_10_00_10: sub_pam4_number_0s = 0 + 0 + 3 + 0;
              8'b10_10_00_11: sub_pam4_number_0s = 0 + 0 + 3 + 0;
              8'b10_10_01_00: sub_pam4_number_0s = 0 + 0 + 1 + 3;
              8'b10_10_01_01: sub_pam4_number_0s = 0 + 0 + 1 + 1;
              8'b10_10_01_10: sub_pam4_number_0s = 0 + 0 + 1 + 0;
              8'b10_10_01_11: sub_pam4_number_0s = 0 + 0 + 1 + 0;
              8'b10_10_10_00: sub_pam4_number_0s = 0 + 0 + 0 + 3;
              8'b10_10_10_01: sub_pam4_number_0s = 0 + 0 + 0 + 1;
              8'b10_10_10_10: sub_pam4_number_0s = 0 + 0 + 0 + 0;
              8'b10_10_10_11: sub_pam4_number_0s = 0 + 0 + 0 + 0;
              8'b10_10_11_00: sub_pam4_number_0s = 0 + 0 + 0 + 3;
              8'b10_10_11_01: sub_pam4_number_0s = 0 + 0 + 0 + 1;
              8'b10_10_11_10: sub_pam4_number_0s = 0 + 0 + 0 + 0;
              8'b10_10_11_11: sub_pam4_number_0s = 0 + 0 + 0 + 0;
              8'b10_11_00_00: sub_pam4_number_0s = 0 + 0 + 3 + 3;
              8'b10_11_00_01: sub_pam4_number_0s = 0 + 0 + 3 + 1;
              8'b10_11_00_10: sub_pam4_number_0s = 0 + 0 + 3 + 0;
              8'b10_11_00_11: sub_pam4_number_0s = 0 + 0 + 3 + 0;
              8'b10_11_01_00: sub_pam4_number_0s = 0 + 0 + 1 + 3;
              8'b10_11_01_01: sub_pam4_number_0s = 0 + 0 + 1 + 1;
              8'b10_11_01_10: sub_pam4_number_0s = 0 + 0 + 1 + 0;
              8'b10_11_01_11: sub_pam4_number_0s = 0 + 0 + 1 + 0;
              8'b10_11_10_00: sub_pam4_number_0s = 0 + 0 + 0 + 3;
              8'b10_11_10_01: sub_pam4_number_0s = 0 + 0 + 0 + 1;
              8'b10_11_10_10: sub_pam4_number_0s = 0 + 0 + 0 + 0;
              8'b10_11_10_11: sub_pam4_number_0s = 0 + 0 + 0 + 0;
              8'b10_11_11_00: sub_pam4_number_0s = 0 + 0 + 0 + 3;
              8'b10_11_11_01: sub_pam4_number_0s = 0 + 0 + 0 + 1;
              8'b10_11_11_10: sub_pam4_number_0s = 0 + 0 + 0 + 0;
              8'b10_11_11_11: sub_pam4_number_0s = 0 + 0 + 0 + 0;
              8'b11_00_00_00: sub_pam4_number_0s = 0 + 3 + 3 + 3;
              8'b11_00_00_01: sub_pam4_number_0s = 0 + 3 + 3 + 1;
              8'b11_00_00_10: sub_pam4_number_0s = 0 + 3 + 3 + 0;
              8'b11_00_00_11: sub_pam4_number_0s = 0 + 3 + 3 + 0;
              8'b11_00_01_00: sub_pam4_number_0s = 0 + 3 + 1 + 3;
              8'b11_00_01_01: sub_pam4_number_0s = 0 + 3 + 1 + 1;
              8'b11_00_01_10: sub_pam4_number_0s = 0 + 3 + 1 + 0;
              8'b11_00_01_11: sub_pam4_number_0s = 0 + 3 + 1 + 0;
              8'b11_00_10_00: sub_pam4_number_0s = 0 + 3 + 0 + 3;
              8'b11_00_10_01: sub_pam4_number_0s = 0 + 3 + 0 + 1;
              8'b11_00_10_10: sub_pam4_number_0s = 0 + 3 + 0 + 0;
              8'b11_00_10_11: sub_pam4_number_0s = 0 + 3 + 0 + 0;
              8'b11_00_11_00: sub_pam4_number_0s = 0 + 3 + 0 + 3;
              8'b11_00_11_01: sub_pam4_number_0s = 0 + 3 + 0 + 1;
              8'b11_00_11_10: sub_pam4_number_0s = 0 + 3 + 0 + 0;
              8'b11_00_11_11: sub_pam4_number_0s = 0 + 3 + 0 + 0;
              8'b11_01_00_00: sub_pam4_number_0s = 0 + 1 + 3 + 3;
              8'b11_01_00_01: sub_pam4_number_0s = 0 + 1 + 3 + 1;
              8'b11_01_00_10: sub_pam4_number_0s = 0 + 1 + 3 + 0;
              8'b11_01_00_11: sub_pam4_number_0s = 0 + 1 + 3 + 0;
              8'b11_01_01_00: sub_pam4_number_0s = 0 + 1 + 1 + 3;
              8'b11_01_01_01: sub_pam4_number_0s = 0 + 1 + 1 + 1;
              8'b11_01_01_10: sub_pam4_number_0s = 0 + 1 + 1 + 0;
              8'b11_01_01_11: sub_pam4_number_0s = 0 + 1 + 1 + 0;
              8'b11_01_10_00: sub_pam4_number_0s = 0 + 1 + 0 + 3;
              8'b11_01_10_01: sub_pam4_number_0s = 0 + 1 + 0 + 1;
              8'b11_01_10_10: sub_pam4_number_0s = 0 + 1 + 0 + 0;
              8'b11_01_10_11: sub_pam4_number_0s = 0 + 1 + 0 + 0;
              8'b11_01_11_00: sub_pam4_number_0s = 0 + 1 + 0 + 3;
              8'b11_01_11_01: sub_pam4_number_0s = 0 + 1 + 0 + 1;
              8'b11_01_11_10: sub_pam4_number_0s = 0 + 1 + 0 + 0;
              8'b11_01_11_11: sub_pam4_number_0s = 0 + 1 + 0 + 0;
              8'b11_10_00_00: sub_pam4_number_0s = 0 + 0 + 3 + 3;
              8'b11_10_00_01: sub_pam4_number_0s = 0 + 0 + 3 + 1;
              8'b11_10_00_10: sub_pam4_number_0s = 0 + 0 + 3 + 0;
              8'b11_10_00_11: sub_pam4_number_0s = 0 + 0 + 3 + 0;
              8'b11_10_01_00: sub_pam4_number_0s = 0 + 0 + 1 + 3;
              8'b11_10_01_01: sub_pam4_number_0s = 0 + 0 + 1 + 1;
              8'b11_10_01_10: sub_pam4_number_0s = 0 + 0 + 1 + 0;
              8'b11_10_01_11: sub_pam4_number_0s = 0 + 0 + 1 + 0;
              8'b11_10_10_00: sub_pam4_number_0s = 0 + 0 + 0 + 3;
              8'b11_10_10_01: sub_pam4_number_0s = 0 + 0 + 0 + 1;
              8'b11_10_10_10: sub_pam4_number_0s = 0 + 0 + 0 + 0;
              8'b11_10_10_11: sub_pam4_number_0s = 0 + 0 + 0 + 0;
              8'b11_10_11_00: sub_pam4_number_0s = 0 + 0 + 0 + 3;
              8'b11_10_11_01: sub_pam4_number_0s = 0 + 0 + 0 + 1;
              8'b11_10_11_10: sub_pam4_number_0s = 0 + 0 + 0 + 0;
              8'b11_10_11_11: sub_pam4_number_0s = 0 + 0 + 0 + 0;
              8'b11_11_00_00: sub_pam4_number_0s = 0 + 0 + 3 + 3;
              8'b11_11_00_01: sub_pam4_number_0s = 0 + 0 + 3 + 1;
              8'b11_11_00_10: sub_pam4_number_0s = 0 + 0 + 3 + 0;
              8'b11_11_00_11: sub_pam4_number_0s = 0 + 0 + 3 + 0;
              8'b11_11_01_00: sub_pam4_number_0s = 0 + 0 + 1 + 3;
              8'b11_11_01_01: sub_pam4_number_0s = 0 + 0 + 1 + 1;
              8'b11_11_01_10: sub_pam4_number_0s = 0 + 0 + 1 + 0;
              8'b11_11_01_11: sub_pam4_number_0s = 0 + 0 + 1 + 0;
              8'b11_11_10_00: sub_pam4_number_0s = 0 + 0 + 0 + 3;
              8'b11_11_10_01: sub_pam4_number_0s = 0 + 0 + 0 + 1;
              8'b11_11_10_10: sub_pam4_number_0s = 0 + 0 + 0 + 0;
              8'b11_11_10_11: sub_pam4_number_0s = 0 + 0 + 0 + 0;
              8'b11_11_11_00: sub_pam4_number_0s = 0 + 0 + 0 + 3;
              8'b11_11_11_01: sub_pam4_number_0s = 0 + 0 + 0 + 1;
              8'b11_11_11_10: sub_pam4_number_0s = 0 + 0 + 0 + 0;
              8'b11_11_11_11: sub_pam4_number_0s = 0 + 0 + 0 + 0;
              default       : sub_pam4_number_0s = 3 + 3 + 3 + 3; //8'b00_00_00_00
          endcase
      end
  endfunction

endmodule
