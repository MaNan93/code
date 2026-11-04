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
// ---    $Revision: #13 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/scramble3_pipe_gen3_scrmbl.sv#13 $
// -------------------------------------------------------------------------
//
// Description :pipe_gen3_scrmbl scrambles the 16-bit incoming data and advances
// the LFSR according to the received OS (OSs are not scambled)
// it also pass some extra signals that need to be in sync with the data
//
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer1/xmlh_pkg.svh"

 
 module scramble3_pipe_gen3_scrmbl
 import xmlh_pkg::skp_replace_t;
 import xmlh_pkg::SKP_REPLACE_IDLE;
 import xmlh_pkg::data_rate_enc_t;
  #(parameter INST                        = 0,
    parameter TP                          = `TP,
    parameter REGIN                       = 1,
    parameter REGOUT                      = 1,
    parameter LFSR_REGOUT                 = 0,
    parameter NB                          = `CX_NB,
    parameter SB_WD                       = `CX_MAC_SB_WD,
    parameter SH_WD                       = `CX_MAC_SH_WD,
    parameter SIG_WIDTH                   = 4,
    parameter AW                          = `CX_ANB_WD,
    parameter CALC_PARITY_BEFORE_SCRAMBLE = 0
    ,
    parameter  PRECODING_REGOUT = 0
    ,
    parameter  GLAYCODING_REGOUT = 0,
    parameter  DCB_WD = (NB>=8 ? NB/8 : 1)
   )
  (
  input   wire                 core_clk,
  input   wire                 core_rst_n,
  input   wire                 cfg_elastic_buffer_mode,
  input   wire                 scrmbl_disable,  
  input   wire                 dc_balance_disable,
  input   wire                 scramble_en,
  input   wire                 in_dataskip,
  input   wire [(NB*8)-1:0]    in_data,
  input   wire [SB_WD-1:0]     in_startblock,
  input   wire [SH_WD-1:0]     in_syncheader,
  input   skp_replace_t        in_skp_os_align_sts,
  input   wire [SB_WD-1:0]     in_skipremoved,
  input   wire [2:0]           lfsr_sel,
  input   wire [SIG_WIDTH-1:0] in_extra_sig,
  input   wire                 aligned,
  input   wire                 txelecidle,
  input   wire [AW-1:0]        active_nb_gen34,
  input   wire [SB_WD-1:0][4:0] in_data_osfound,
  input   wire [1:0]           l0p_in_lfsr_info,
  input   wire [22:0]          l0p_in_lfsr_value,
  input   wire [2:0]           current_data_rate,
  input                        precoding_en,
  input                        gen6_compliance_sending,
  output  wire [(NB*8)-1:0]    out_data,
  output  wire [SB_WD-1:0]     out_even_parity,
  output  wire [22:0]          out_lfsr,
  output  wire [SB_WD-1:0]     out_startblock,
  output  wire [SH_WD-1:0]     out_syncheader,
  output  skp_replace_t        out_skp_os_align_sts,
  output  wire [SIG_WIDTH-1:0] out_extra_sig,
  output  wire [SB_WD-1:0][4:0] out_data_osfound,
  output  wire [DCB_WD-1:0]    out_dcb_det,
  
  output  reg  [22:0]          init_lfsr_value,
  output  reg  [22:0]          roll_lfsr_value, // lfsr value on symbol 0 of 65536-th block - used to detect (approx) rollover point when ts1 are sent uninterrupted
  output  wire [SB_WD-1:0]     out_int_startblock,
  output  wire [SH_WD-1:0]     out_int_syncheader,
  output  wire [SB_WD-1:0]     out_int_eios,
  output  wire [22:0]          lfsr_value, // remove
  output  wire [SB_WD-1:0]     inskp,
  output  wire [SB_WD-1:0]     ints0,
  output  wire [SB_WD-1:0]     ints1,
  output  wire [SB_WD-1:0]     ints2,
  output  wire [SB_WD-1:0]     full_ineie,
  output  wire [SB_WD-1:0]     full_eieos_detected,
  output  wire [SB_WD-1:0]     insds
  ,
  output  wire [4:0]           l0p_out_lfsr_info,
  output  wire [22:0]          l0p_out_lfsr_value
  ); 
  // ---- main    ---------------
  // when scrmbl_disable=1'b1 data gets staged but does not get 
  // scrambled and just passes through scrambler with one stage 
  // delay
  
  // we detect the OSs with in pipe_scrmbl_ctl and generate
  // the right enable signals for the scrambler
  wire [(NB*8)-1:0]            ctl_data;
  wire [SB_WD-1:0]             ctl_lfsr_en;
  wire [SB_WD-1:0]             ctl_lbyte_not_scrmbl;
  wire [SB_WD-1:0]             ctl_wrd_not_scrmbl;
  wire [SB_WD-1:0]             ctl_lfsr_load;
  wire [SB_WD-1:0]             ctl_int_ineie;
  wire [SB_WD-1:0]             ctl_int_ineios_s1;
  wire [SB_WD-1:0]             ineie;
  wire [SB_WD-1:0]             ctl_int_ints0;
  wire [DCB_WD-1:0]            scrm_out_dcb_det;
  wire [SB_WD-1:0]             ctl_int_ints1;
  wire [SB_WD-1:0]             ctl_int_ints2;
  wire                         ctl_int_dataskip;
  wire [SB_WD-1:0]             ctl_int_inskp;
  wire [SB_WD-1:0]             ctl_int_insds;
  wire                         indataskip;
  wire [22:0]                  ctl_lfsr_load_value;
  wire [(NB*8)-1:0]            scrm_out_data;
  wire [22:0]                  scrm_out_lfsr;
  wire [SB_WD-1:0]             scrm_out_even_parity;

// Add a pipeline for improving timings
  localparam N_DELAY_CYCLE = REGIN + REGOUT + LFSR_REGOUT
 + PRECODING_REGOUT
 + GLAYCODING_REGOUT
                       ;

  reg  [SB_WD*N_DELAY_CYCLE-1:0]             in_startblock_dly;
  wire [SB_WD-1:0]                           pre_in_startblock_dly0;
  reg  [SH_WD*N_DELAY_CYCLE-1:0]             in_syncheader_dly;
  reg  [SIG_WIDTH*N_DELAY_CYCLE-1:0]         in_extra_sig_dly;
  skp_replace_t                              in_skp_os_align_sts_dly [N_DELAY_CYCLE-1:0] ;
  logic [N_DELAY_CYCLE-1:0][SB_WD-1:0][4:0]  in_data_osfound_dly ;

  // here is the controler

  // we have to set the lfsr_reset_value base on the lane number
  // which is coming from top
  always @* begin
    casez (lfsr_sel)
      3'd1    : begin init_lfsr_value = 23'h0607BB; roll_lfsr_value = 23'h38c280; end
      3'd2    : begin init_lfsr_value = 23'h1EC760; roll_lfsr_value = 23'h7984f1; end
      3'd3    : begin init_lfsr_value = 23'h18C0DB; roll_lfsr_value = 23'h414671; end
      3'd4    : begin init_lfsr_value = 23'h010F12; roll_lfsr_value = 23'h2ce903; end
      3'd5    : begin init_lfsr_value = 23'h19CFC9; roll_lfsr_value = 23'h6daf72; end
      3'd6    : begin init_lfsr_value = 23'h0277CE; roll_lfsr_value = 23'h21dc53; end
      3'd7    : begin init_lfsr_value = 23'h1BB807; roll_lfsr_value = 23'h4c7321; end
      default : begin init_lfsr_value = 23'h1DBFBC; roll_lfsr_value = 23'h74b1a1; end // 3'd0
    endcase
  end

  scramble3_pipe_scrmbl_ctl
   #(.INST(INST) , .CALC_PARITY_BEFORE_SCRAMBLE(CALC_PARITY_BEFORE_SCRAMBLE), .REGIN(REGIN) , .REGOUT(REGOUT) , .LFSR_REGOUT(LFSR_REGOUT) , .PRECODING_REGOUT(PRECODING_REGOUT) , .GLAYCODING_REGOUT(GLAYCODING_REGOUT)) scramble3_pipe_scrmbl_ctl_u0
  (
    .core_clk(core_clk),
    .core_rst_n(core_rst_n),
    .cfg_elastic_buffer_mode(cfg_elastic_buffer_mode),
    .in_aligned(aligned),
    .init_lfsr_value(init_lfsr_value),
    .in_dataskip(in_dataskip),
    .scramble_en(scramble_en),
    .in_data(in_data),
    .in_data_osfound(in_data_osfound),
    .out_data(ctl_data),
    .in_syncheader(in_syncheader),
    .startblock(in_startblock),
    .skipremoved(in_skipremoved),
    .active_nb_gen34(active_nb_gen34),
    .current_data_rate(current_data_rate),
    .gen6_compliance_sending (gen6_compliance_sending),
    .lfsr_en(ctl_lfsr_en),
    .lbyte_not_scrmbl(ctl_lbyte_not_scrmbl),
    .wrd_not_scrmbl(ctl_wrd_not_scrmbl),
    .lfsr_load(ctl_lfsr_load),
    .lfsr_load_value(ctl_lfsr_load_value),
    .inskp(inskp),
    .indataskip(indataskip),
    .int_dataskip(ctl_int_dataskip),
    .ints0(ints0),
    .int_ints0(ctl_int_ints0),
    .ints1(ints1),
    .int_ints1(ctl_int_ints1),
    .ints2(ints2),
    .int_ints2(ctl_int_ints2),
    .full_ineie(full_ineie),
    .full_eieos_detected(full_eieos_detected),
    .ineie(ineie),
    .int_ineie(ctl_int_ineie),
    .int_ineios(ctl_int_ineios_s1),
    .int_inskp(ctl_int_inskp),
    .int_insds(ctl_int_insds),
    .insds(insds)
   ); 

 // here is the scrambler
 // once scrmbl_disable=1'b1, we continue advance the LFSR (required for
 // Equalization) but we do not scramble the word so we should set
 // lfsr_en =1'b1 and wrd_not_scrmbl=1'b1
  scramble3_pipe_prl16_scrmbl
   #(.INST(INST),
                                .CALC_PARITY_BEFORE_SCRAMBLE(CALC_PARITY_BEFORE_SCRAMBLE),
                                .REGIN(REGIN),
                                .REGOUT(REGOUT),
                                .LFSR_REGOUT(LFSR_REGOUT)
                                ,
                                .PRECODING_REGOUT(PRECODING_REGOUT) 
                                ,
                                .GLAYCODING_REGOUT(GLAYCODING_REGOUT)
                               ) scramble3_pipe_prl16_scrmbl_u0
  (
    .core_clk(core_clk),
    .core_rst_n(core_rst_n),
    .scramble_en(scramble_en),
    .current_data_rate(current_data_rate),
    .gen6_compliance_sending(gen6_compliance_sending),
    .int_dataskip(indataskip),
    .int_txelecidle(txelecidle),
    .int_startblock(in_startblock_dly[SB_WD*(N_DELAY_CYCLE-1) +: SB_WD]),
    .int_syncheader(in_syncheader_dly[SH_WD*(N_DELAY_CYCLE-1) +: SH_WD]),
    .int_ineie(ineie),
    .int_ints0(ints0),
    .int_ints1(ints1),
    .int_ints2(ints2),

    .int_dataskip_s1(ctl_int_dataskip),
    .int_ints0_s1(ctl_int_ints0),
    .int_ints1_s1(ctl_int_ints1),
    .int_ints2_s1(ctl_int_ints2),
    .int_inskp_s1(ctl_int_inskp),
    .int_insds_s1(ctl_int_insds),
    .int_ineie_s1(ctl_int_ineie),
    .int_ineios_s1(ctl_int_ineios_s1),
    .l0p_in_lfsr_info(l0p_in_lfsr_info),
    .l0p_in_lfsr_value(l0p_in_lfsr_value),
    .int_startblock_s1(pre_in_startblock_dly0),
    .dc_balance_disable(dc_balance_disable),
    .lfsr_load(ctl_lfsr_load),
    .lfsr_load_value(ctl_lfsr_load_value),
    .lbyte_not_scrmbl(ctl_lbyte_not_scrmbl),
    .lfsr_en(ctl_lfsr_en),
    .wrd_not_scrmbl(ctl_wrd_not_scrmbl | {SB_WD{scrmbl_disable}}),  
    .in_data(ctl_data),
    .active_nb_gen34(active_nb_gen34),
    .precoding_en(precoding_en),
//-- remove start
    .lfsr_o(lfsr_value),
//------ end
    .l0p_out_lfsr_info(l0p_out_lfsr_info),
    .l0p_out_lfsr_value(l0p_out_lfsr_value),
    .out_dcb_det(scrm_out_dcb_det),
    .out_data(scrm_out_data),
    .out_lfsr(scrm_out_lfsr),
    .out_even_parity(scrm_out_even_parity)
  ); 
 
 // controler and scrambler delay the data by two clock
 // cycles therefore we need to delay all the coresponding 
 // signals by two cycles
generate if (N_DELAY_CYCLE>1) begin : gen_delay_2 
  always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
      in_startblock_dly <= #TP '0;
      in_syncheader_dly <= #TP '0;
      in_extra_sig_dly  <= #TP '0;
      for( int ii = 0 ; ii < N_DELAY_CYCLE ; ii++ ) begin
        in_skp_os_align_sts_dly[ii] <= #TP SKP_REPLACE_IDLE ;
        in_data_osfound_dly[ii]     <= #TP '0 ;
      end
    end
    else begin
      if(scramble_en)begin 
        in_startblock_dly <= #TP {in_startblock_dly[SB_WD*(N_DELAY_CYCLE-1)-1:0],in_startblock};
        in_syncheader_dly <= #TP {in_syncheader_dly[SH_WD*(N_DELAY_CYCLE-1)-1:0],in_syncheader};
        in_extra_sig_dly  <= #TP {in_extra_sig_dly[SIG_WIDTH*(N_DELAY_CYCLE-1)-1:0],in_extra_sig};
        for( int ii = 0 ; ii < N_DELAY_CYCLE ; ii++ ) begin
          if( ii == 0 ) begin
                in_skp_os_align_sts_dly[ii] <= #TP in_skp_os_align_sts ;
                in_data_osfound_dly[ii]     <= #TP in_data_osfound ;
          end
          else begin
                in_skp_os_align_sts_dly[ii] <= #TP in_skp_os_align_sts_dly[ii-1] ;
                in_data_osfound_dly[ii]     <= #TP in_data_osfound_dly[ii-1] ;
          end
        end
      end else begin
        in_startblock_dly <= #TP '0;
        in_syncheader_dly <= #TP '0;
        in_extra_sig_dly  <= #TP '0;
        for( int ii = 0 ; ii < N_DELAY_CYCLE ; ii++ ) begin
          in_skp_os_align_sts_dly[ii] <= #TP SKP_REPLACE_IDLE ;
          in_data_osfound_dly[ii]     <= #TP '0 ;
        end
      end
    end
  end

  delay_n_w_enable
  
  #((N_DELAY_CYCLE-2), SB_WD, 1'b0) u_eios_delay(
      .clk        (core_clk),
      .rst_n      (core_rst_n),
      .clear      (1'b0),
      .en         (scramble_en),
      .din        (ctl_int_ineios_s1),
      .dout       (out_int_eios)
  );
 assign out_int_syncheader = in_syncheader_dly[SH_WD*(N_DELAY_CYCLE-2) +: SH_WD] ;


 // data and signals to the output
 assign out_int_startblock = in_startblock_dly[SB_WD*(N_DELAY_CYCLE-2) +: SB_WD] ; //combine with inskp to get skp_end
 assign out_startblock = in_startblock_dly[SB_WD*(N_DELAY_CYCLE-1) +: SB_WD];
 assign out_syncheader = in_syncheader_dly[SH_WD*(N_DELAY_CYCLE-1) +: SH_WD];
 assign out_skp_os_align_sts = in_skp_os_align_sts_dly[N_DELAY_CYCLE-1] ;
 assign out_data_osfound     = in_data_osfound_dly[N_DELAY_CYCLE-1] ;
 assign out_extra_sig  = in_extra_sig_dly[SIG_WIDTH*(N_DELAY_CYCLE-1) +: SIG_WIDTH] ;
 assign pre_in_startblock_dly0 = (REGIN==0) ? in_startblock : in_startblock_dly[SB_WD-1:0];

end else begin : gen_delay_1

  always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
      in_startblock_dly           <= #TP '0;
      in_syncheader_dly           <= #TP '0;
      in_extra_sig_dly            <= #TP '0;
      in_skp_os_align_sts_dly[0]  <= #TP SKP_REPLACE_IDLE ;
      in_data_osfound_dly[0]      <= #TP '0 ;
    end
    else begin
      if(scramble_en)begin
        in_startblock_dly           <= #TP in_startblock;
        in_syncheader_dly           <= #TP in_syncheader;
        in_extra_sig_dly            <= #TP in_extra_sig;
        in_skp_os_align_sts_dly[0]  <= #TP in_skp_os_align_sts ;
        in_data_osfound_dly[0]      <= #TP in_data_osfound ;
      end else begin
        in_startblock_dly           <= #TP '0;
        in_syncheader_dly           <= #TP '0;
        in_extra_sig_dly            <= #TP '0;
        in_skp_os_align_sts_dly[0]  <= #TP SKP_REPLACE_IDLE ;
        in_data_osfound_dly[0]      <= #TP '0 ;
      end
    end
  end

 assign out_int_eios       = ctl_int_ineios_s1;
 assign out_int_syncheader = in_syncheader;

 assign out_int_startblock = in_startblock;
 assign out_startblock = in_startblock_dly[SB_WD*(N_DELAY_CYCLE-1) +: SB_WD];
 assign out_syncheader = in_syncheader_dly[SH_WD*(N_DELAY_CYCLE-1) +: SH_WD];
 assign out_skp_os_align_sts = in_skp_os_align_sts_dly[0] ;
 assign out_data_osfound     = in_data_osfound_dly[0] ;
 assign out_extra_sig  = in_extra_sig_dly[SIG_WIDTH*(N_DELAY_CYCLE-1) +: SIG_WIDTH] ;
 assign pre_in_startblock_dly0 = (REGIN==1 && REGOUT==0) ? in_startblock_dly[SB_WD*(N_DELAY_CYCLE-1) +: SB_WD] : in_startblock;

end endgenerate

 assign out_data        = scrm_out_data;
 assign out_even_parity = scrm_out_even_parity;
 assign out_lfsr        = scrm_out_lfsr;
 assign out_dcb_det = scrm_out_dcb_det;

endmodule
////////////////////////////////////////////////////////////////////////////// 
