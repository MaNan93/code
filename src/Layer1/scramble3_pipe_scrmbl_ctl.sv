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
// ---    $Revision: #15 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/scramble3_pipe_scrmbl_ctl.sv#15 $
// -------------------------------------------------------------------------
//
// Description : scramble3_pipe_scrmbl_ctl detects SKP, EIEOS, FTS, SDS, EIOS, TS1, TS2 OSs
// and disables/enables scrambler accordingly
//
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module scramble3_pipe_scrmbl_ctl 
  #(parameter INST                        = 0,
    parameter TP                          = `TP,
    parameter CALC_PARITY_BEFORE_SCRAMBLE = 0, // 0:XMLH,1:RXMLH
    parameter REGIN                       = 1,
    parameter REGOUT                      = 1,
    parameter LFSR_REGOUT                 = 0,
    parameter NB                          = `CX_NB,
    parameter SB_WD                       = `CX_MAC_SB_WD,
    parameter SH_WD                       = `CX_MAC_SH_WD,
    parameter AW                          = `CX_ANB_WD 
    ,
    parameter PRECODING_REGOUT = 0 
    ,
    parameter  GLAYCODING_REGOUT = 0
  )
  (
  input  wire                   core_clk,
  input  wire                   core_rst_n,
  input  wire                   cfg_elastic_buffer_mode,
  input  wire                   in_aligned, //gates: must revisit. initialize lfsr
  input  wire   [22:0]          init_lfsr_value,
  input  wire                   in_dataskip,
  input  wire                   scramble_en,
  input  wire   [(NB*8)-1:0]    in_data,
  input  wire [SB_WD-1:0][4:0]  in_data_osfound,
  input  wire   [SH_WD-1:0]     in_syncheader,
  input  wire   [SB_WD-1:0]     startblock,
  input  wire   [SB_WD-1:0]     skipremoved,
  input  wire   [AW-1:0]        active_nb_gen34,
  input  wire   [2:0]           current_data_rate,
  input                         gen6_compliance_sending,
  output wire   [(NB*8)-1:0]    out_data,
  output wire   [SB_WD-1:0]     lfsr_en,
  output wire   [SB_WD-1:0]     lbyte_not_scrmbl,
  output wire   [SB_WD-1:0]     wrd_not_scrmbl,
  output reg    [SB_WD-1:0]     lfsr_load,
  output reg    [22:0]          lfsr_load_value,
  output wire                   indataskip,
  output wire                   int_dataskip,

  output wire   [SB_WD-1:0]     inskp,
  output wire   [SB_WD-1:0]     ints0,
  output wire   [SB_WD-1:0]     int_ints0,
  output wire   [SB_WD-1:0]     ints1,
  output wire   [SB_WD-1:0]     int_ints1,
  output wire   [SB_WD-1:0]     ints2,
  output wire   [SB_WD-1:0]     int_ints2,
  output wire   [SB_WD-1:0]     full_ineie,
  output wire   [SB_WD-1:0]     full_eieos_detected,
  output wire   [SB_WD-1:0]     ineie,
  output wire   [SB_WD-1:0]     int_ineie,
  output wire   [SB_WD-1:0]     int_ineios,
  output wire   [SB_WD-1:0]     int_inskp,
  output wire   [SB_WD-1:0]     int_insds,
  output wire   [SB_WD-1:0]     insds
  ); 

  localparam NB_DIV_2 = NB/2;
  localparam NB_DIV_4 = NB/4;
  localparam NB_DIV_8 = NB/8;
  localparam MAX_EIE_CNT   = ((`CX_GEN3_MODE!=2 && `CX_NB_GEN3==1)) ? 16 : 15;
  localparam EIE_CNT_WIDTH = ((`CX_GEN3_MODE!=2 && `CX_NB_GEN3==1) || (NB>=16)) ?  5 : 4;
  localparam REGIN_EIOS =
                          ((REGIN==1) && (LFSR_REGOUT==0) && (REGOUT==0) && (PRECODING_REGOUT==0)) ? 0 :
                          ((REGIN==0) && (LFSR_REGOUT==0) && (REGOUT==1) && (PRECODING_REGOUT==0)) ? 0 :
                          ((REGIN==0) && (LFSR_REGOUT==0) && (REGOUT==0) && (PRECODING_REGOUT==1)) ? 0 :
                                                                                 1;
  wire [SB_WD-1:0] pre_inskp,pre_insds;
  wire [SB_WD-1:0] pre_ints0,pre_ints1,pre_ints2,pre_ineie;
  // ---- main    ---------------
  // we just look at the first byte of the incoming
  // block to detect OSs
  // here is what we need to do with scrambler and LFSR
  // for different OSs
  //
  //  OS      First Byte   Scrambeled      LFSR Advance?
  //  TS1      8'h1E       not 1st byte      Yes
  //  TS2      8'h2D       not 1st byte      Yes
  //  SKP      8'hAA       not entire blk    No
  //  EIEOS    8'h00       not entire blk    No
  //  FTS      8'h55       not entire blk    Optional
  //  SDS      8'hE1       not entire blk    Yes
  //  EIOS     8'h66       not entire blk    No
  //  for gen5, skp = 8'h99 and sds body = 8'h87
  wire match_gen3_ts1   = (in_data[7:0] == `GEN3_8B_TS1);
  wire match_gen3_ts2   = (in_data[7:0] == `GEN3_8B_TS2);
  wire match_gen3_fts   = (in_data[7:0] == `GEN3_8B_FTS);
  wire match_gen3_cmpl  = (in_data[7:0] == `GEN3_8B_CMPL);
  wire match_gen3_skp   = ( current_data_rate == `GEN5_RATE ? in_data[7:0] == `CX_GEN5_SKP_ENC : in_data[7:0] ==  `GEN3_8B_SKP);
  wire match_gen3_eios  = (in_data[7:0] == `GEN3_8B_EIOS);
  wire match_gen3_eieos = (in_data[7:0] == `GEN3_8B_EIEOS);
  wire match_gen3_sds   = (in_data[7:0] == `GEN3_8B_SDS);  // Without SKP_END(8'hE1) symbol

  wire [SB_WD-1:0]  ts1_start;
  wire [SB_WD-1:0]  ts2_start;
  wire [SB_WD-1:0]  skp_start;
  wire [SB_WD-1:0]  eieos_start;
  wire [SB_WD-1:0]  fts_start;
  wire [SB_WD-1:0]  sds_start;
  wire [SB_WD-1:0]  eios_start;
  wire [SB_WD-1:0]  cmpl_start;

  wire [SB_WD-1:0]  ts0_start;
  wire [SB_WD-1:0]  match_gen6_ts1;
  wire [SB_WD-1:0]  match_gen6_ts2;
  wire [SB_WD-1:0]  match_gen6_skp;
  wire [SB_WD-1:0]  match_gen6_eieos;
  wire [SB_WD-1:0]  match_gen6_fts;
  wire [SB_WD-1:0]  match_gen6_sds;
  wire [SB_WD-1:0]  match_gen6_eios;
  wire [SB_WD-1:0]  match_gen6_cmpl;


  reg  [1:0]        latched_in_syncheader;
  always @(posedge core_clk or negedge core_rst_n) begin : latched_in_syncheader_PROC
    if ( !core_rst_n ) begin
      latched_in_syncheader <= #TP 1;
    end else if( ~scramble_en || (current_data_rate != `GEN6_RATE))begin
      latched_in_syncheader <= #TP 1;
    end else if (~in_dataskip && startblock[0]) begin
      latched_in_syncheader <= #TP in_syncheader[1:0];
    end else begin
      latched_in_syncheader <= #TP latched_in_syncheader;
    end
  end // latched_in_syncheader_PROC


   // TS1/TS2/FTS/CPL
  // 8s, 4s
  assign ts0_start[0]        =((in_data[7:0] == `GEN6_8B_TS0) & ((startblock[0] & in_syncheader[1:0] == `GEN3_2B_OS_SYNC) || (~in_dataskip & ~startblock[0] & latched_in_syncheader== `GEN3_2B_OS_SYNC)) & (current_data_rate ==  `GEN6_RATE));
  assign match_gen6_ts1[0]   = (in_data[7:0] == `GEN6_8B_TS1) & ((startblock[0] & in_syncheader[1:0] == `GEN3_2B_OS_SYNC) || (~in_dataskip & ~startblock[0] & latched_in_syncheader== `GEN3_2B_OS_SYNC));
  assign match_gen6_ts2[0]   = (in_data[7:0] == `GEN6_8B_TS2) & ((startblock[0] & in_syncheader[1:0] == `GEN3_2B_OS_SYNC) || (~in_dataskip & ~startblock[0] & latched_in_syncheader== `GEN3_2B_OS_SYNC));
  assign match_gen6_fts[0]   = 1'b0;
  assign match_gen6_cmpl[0]  = gen6_compliance_sending        & (startblock[0] & in_syncheader[1:0] == `GEN3_2B_OS_SYNC);

   // SKP/EI/EIE/SDS
  // 8s, 4s
  assign match_gen6_skp[0]   =(( (in_data[39:0] == `GEN6_40B_SKP_SYM_0)) || skipremoved[0]) & ((startblock[0] & in_syncheader[1:0] ==  `GEN3_2B_OS_SYNC) || (CALC_PARITY_BEFORE_SCRAMBLE==1 & ~in_dataskip & ~startblock[0] & latched_in_syncheader==  `GEN3_2B_OS_SYNC));
  assign match_gen6_eios[0]  = (in_data[31:0] == `GEN6_32B_EIOS_SYM_0) & ((startblock[0] & in_syncheader[1:0] == `GEN3_2B_OS_SYNC) || (CALC_PARITY_BEFORE_SCRAMBLE==1 & ~in_dataskip & ~startblock[0] & latched_in_syncheader== `GEN3_2B_OS_SYNC));
  assign match_gen6_eieos[0] = (in_data[31:0] == `GEN6_32B_EIEOS_SYM_0) & (startblock[0] & in_syncheader[1:0] == `GEN3_2B_OS_SYNC);
  assign match_gen6_sds[0]   = (in_data[31:0] == `GEN6_32B_SDS_SYM_0)  & ((startblock[0] & in_syncheader[1:0] == `GEN3_2B_OS_SYNC) || (CALC_PARITY_BEFORE_SCRAMBLE==1 & ~in_dataskip & ~startblock[0] & latched_in_syncheader== `GEN3_2B_OS_SYNC));  // Without SKP_END(8'hE1) symbol

  assign ts1_start[0]   = (current_data_rate == `GEN6_RATE) ? match_gen6_ts1[0]   : (match_gen3_ts1 & startblock[0] & (in_syncheader[1:0] ==  `GEN3_2B_OS_SYNC));
  assign ts2_start[0]   = (current_data_rate == `GEN6_RATE) ? match_gen6_ts2[0]   : (match_gen3_ts2 & startblock[0] & (in_syncheader[1:0] ==  `GEN3_2B_OS_SYNC));
  assign skp_start[0]   = (current_data_rate == `GEN6_RATE) ? match_gen6_skp[0]   : ((match_gen3_skp || skipremoved[0]) & startblock[0] & (in_syncheader[1:0] ==  `GEN3_2B_OS_SYNC));
  assign eieos_start[0] = (current_data_rate == `GEN6_RATE) ? match_gen6_eieos[0] : (match_gen3_eieos & startblock[0] & (in_syncheader[1:0] ==  `GEN3_2B_OS_SYNC));
  assign fts_start[0]   = (current_data_rate == `GEN6_RATE) ? match_gen6_fts[0]   : (match_gen3_fts  & startblock[0] & (in_syncheader[1:0] ==  `GEN3_2B_OS_SYNC));
  assign sds_start[0]   = (current_data_rate == `GEN6_RATE) ? match_gen6_sds[0]   : (match_gen3_sds  & startblock[0] & (in_syncheader[1:0] ==  `GEN3_2B_OS_SYNC) & !skipremoved[0]);
  assign eios_start[0]  = (current_data_rate == `GEN6_RATE) ? match_gen6_eios[0]  : (match_gen3_eios & startblock[0] & (in_syncheader[1:0] ==  `GEN3_2B_OS_SYNC));
  assign cmpl_start[0]  = (current_data_rate == `GEN6_RATE) ? match_gen6_cmpl[0]  : (match_gen3_cmpl & startblock[0] & (in_syncheader[1:0] ==  `GEN3_2B_OS_SYNC));
 
  //gates: must revisit. direct from phy_mac_rxvalid
  reg  in_aligned_d;
  wire int_aligned;
  always @(posedge core_clk or negedge core_rst_n) begin : in_aligned_d_PROC
    if (!core_rst_n) begin
      in_aligned_d <= #TP '0;  
    end
    else begin //gates: must revisit for in_rxaligned
      if(scramble_en)begin
        in_aligned_d <= #TP in_aligned;
      end
    end
  end
  assign int_aligned = in_aligned & !in_aligned_d;
  
  reg [EIE_CNT_WIDTH-1:0] eie_sym_cnt;
  // we need to load the LFSR with the intial value when
  // we detect EIEOS
  wire [NB*8-1:0] eieos_data =                               (current_data_rate == `GEN6_RATE) ?
                               // {sym15, sym14, sym13, sym12, sym11, sym10, sym9, sym8} = {8'hff, 8'hff, 8'hff, 8'hff,8'hff, 8'hff, 8'hff, 8'hff}
                               // { sym7,  sym6,  sym5,  sym4,  sym3,  sym2, sym1, sym0} = {8'h00, 8'h00, 8'h00, 8'h00,8'h00, 8'h00, 8'h00, 8'h00}
                                   (eie_sym_cnt[3:0] == 4'b0111 ? {`GEN6_32B_EIEOS_SYM_3, `GEN6_32B_EIEOS_SYM_2} : {`GEN6_32B_EIEOS_SYM_1, `GEN6_32B_EIEOS_SYM_0}) :
                               (current_data_rate == `GEN5_RATE) ?
                               // {sym7,sym6, sym5, sym4} = {sym15, sym14, sym13, sym12} = {8'hff, 8'hff, 8'hff, 8'hff}
                               // {sym3,sym2, sym1, sym0} = {sym11, sym10, sym9,  sym8}  = {8'h00, 8'h00, 8'h00, 8'h00}
                                   (active_nb_gen34[3]) ? {32'hffffffff, 32'h00000000} : // 8s
                                   ((active_nb_gen34[2] && eie_sym_cnt[2:0]==3'b011) ? {{(NB*8 - 32){1'b0}},32'hffffffff} : {{(NB*8 - 32){1'b0}},32'h00000000}) : // 4s
                               // gen4 eieos format changed from 00->ff->00->ff... to 0000->ffff->0000->ffff...
                               ((current_data_rate == `GEN4_RATE) ) ? // 16GT/s eieos format for PCIe and ESM
                                    {NB_DIV_4{16'hffff, 16'h0000}} :          // for pipe 32/64/128bit
                               {NB_DIV_2{8'hff,8'h00}};
  reg  [1:0]       dskip_cnt;
  wire [SB_WD-1:0] match_eieos_data;
  wire [SB_WD-1:0] eieos_detected_i, eieos_detected_s;
  reg  [SB_WD-1:0] eieos_detected;
 
  always @(posedge core_clk or negedge core_rst_n) begin : dskip_cnt_PROC
    if (!core_rst_n) begin
      dskip_cnt <= #TP '0;
    end else if( ~scramble_en )begin
      dskip_cnt <= #TP dskip_cnt;
    end else if ( ~in_dataskip ) begin
      dskip_cnt <= #TP '0;
    end else if ( dskip_cnt < 3 ) begin
      dskip_cnt <= #TP dskip_cnt + 1;
    end
  end // dskip_cnt_PROC

  always @(posedge core_clk or negedge core_rst_n) begin : eieos_cnt_PROC
    if ( !core_rst_n ) begin
      eie_sym_cnt <= #TP '0;
    end else if( ~scramble_en )begin
      eie_sym_cnt <= #TP eie_sym_cnt;
    end else if ( (dskip_cnt==2 && in_dataskip && ~cfg_elastic_buffer_mode) || ~in_aligned ) begin
      eie_sym_cnt <= #TP '0;
    end else if ( in_dataskip ) begin
      eie_sym_cnt <= #TP eie_sym_cnt;
    end else if ( !match_eieos_data[0] || (startblock[0] && in_syncheader[1:0]!=`GEN3_2B_OS_SYNC) ) begin
      eie_sym_cnt <= #TP '0;
    end else if ( match_eieos_data[0] && startblock[0] && in_syncheader[1:0]==`GEN3_2B_OS_SYNC ) begin
      eie_sym_cnt <= #TP (active_nb_gen34-1);
    end else if ( match_eieos_data[0] && eie_sym_cnt!=0 ) begin
// ccx_line_begin: ; unreachable for TX because transmitter cannot send an EIEOS over 16 symbols.
      if ( (eie_sym_cnt + active_nb_gen34) > MAX_EIE_CNT )
          eie_sym_cnt <= #TP '0; // eieos cannot be over 16 symbols
      else
// ccx_line_end
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
          eie_sym_cnt <= #TP eie_sym_cnt + active_nb_gen34;
// spyglass enable_block W164a
    end
  end // eieos_cnt_PROC



  assign match_eieos_data[0] = (active_nb_gen34==NB) ? (in_data==eieos_data) :
                             (active_nb_gen34==NB/2) ? (in_data[(NB_DIV_2*8)-1:0]==eieos_data[(NB_DIV_2*8)-1:0]) :
                                                       (in_data[(NB_DIV_4*8)-1:0]==eieos_data[(NB_DIV_4*8)-1:0]) ;
  assign eieos_detected_i[0] = (eie_sym_cnt==MAX_EIE_CNT);
  assign eieos_detected_s[0] = eieos_detected_i[0] & ~eieos_detected[0];

  always @(posedge core_clk or negedge core_rst_n) begin : eieos_detected_d_PROC
    if (~core_rst_n) begin
      eieos_detected <= #TP '0;
    end else begin
      if(scramble_en)begin
        eieos_detected <= #TP eieos_detected_i;
      end
    end
  end //eieos_detected_d_PROC

  delay_n_w_enable
   #(REGIN + REGOUT + LFSR_REGOUT -1 + PRECODING_REGOUT + GLAYCODING_REGOUT, 2, 0) u_regout_full_eieos
  (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (scramble_en),
    .din        ({(eie_sym_cnt != 0),eieos_detected_s[0]}),
    .dout       ({full_ineie[0], full_eieos_detected[0]})
  );


  always @( * ) begin
    if (REGIN==1) begin
      lfsr_load = eieos_detected_s | {SB_WD{int_aligned}};
    end else if(PRECODING_REGOUT==1 && CALC_PARITY_BEFORE_SCRAMBLE==1) begin // delayed one clock instead of the scramble3_pipe_prl16_scrmbl module
      lfsr_load = eieos_detected_s | {SB_WD{int_aligned}};
    end else begin
      lfsr_load[0] = (((eie_sym_cnt+active_nb_gen34)==MAX_EIE_CNT) & match_eieos_data[0]) | int_aligned;
    end
    lfsr_load_value = init_lfsr_value;
  end

  // For some of the OSs we need to disable scrambler and 
  // LFSR for the entire block. we need a signal which gets
  // asserted with a set and de-asserted on the next startblock
  // this signal can be used to disable scrambler or LFSR for
  // the entire block
  reg  [SB_WD-1:0] blk_disable;
  wire [SB_WD-1:0] set_blk_disable;
  wire [SB_WD-1:0] pre_blk_disable;
  assign set_blk_disable = (skp_start | eieos_start | fts_start | eios_start | cmpl_start);
  assign pre_blk_disable = (set_blk_disable | (blk_disable & ~startblock));

  always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n)
      blk_disable <= #TP '0;
    else
      if(scramble_en)begin
        blk_disable <= #TP pre_blk_disable;
      end
  end

  // we also should not advance the LFSR once we receive 
  // dataskip becuase it is a junk data
  // the data has been staged once so far so we have to
  // stage the in_dataskip to freez the LFSR for the 
  // right data
  delay_n_w_enable
   #(REGIN, 1, 0) u_regin_int_dataskip
  (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (scramble_en),
    .din        (in_dataskip),
    .dout       (int_dataskip)
  );

  delay_n_w_enable
   #(REGIN + REGOUT + LFSR_REGOUT + PRECODING_REGOUT + GLAYCODING_REGOUT , 1, 0) u_regin_indataskip
  (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (scramble_en),
    .din        (in_dataskip),
    .dout       (indataskip)
  );

  // we do not advance the LFSR for the following OSs
  // SKP, EIEOS, FTS, EIOS. However SDS will advance it
  // we also should not advance the LFSR once we receive 
  // dataskip becuase it is a junk data
generate if (REGIN==1) begin : gen_regin_on_lfsr_en
  assign lfsr_en = ~(blk_disable | {SB_WD{int_dataskip}});
end else begin : gen_regin_off_lfsr_en
  assign lfsr_en = ~(pre_blk_disable | {SB_WD{int_dataskip}});
end endgenerate

  // we should not scramble the SDS block therefore
  // we need a signle which is high for the entire SDS
  reg  [SB_WD-1:0] sds_disable;
  wire [SB_WD-1:0] pre_sds_disable;
  assign  pre_sds_disable = (sds_start | (sds_disable & ~startblock));
  always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n)
      sds_disable <= #TP '0;
    else
      if(scramble_en)begin
        sds_disable <= #TP pre_sds_disable;
      end
  end

  // we do not scamble the entire block for the following OSs
  // SKP, EIEOS, FTS, SDS, EIOS
generate if (REGIN==1) begin : gen_regin_on_wrd_not_scrmbl
  assign wrd_not_scrmbl = blk_disable | sds_disable;
end else begin : gen_regin_off_wrd_not_scrmbl
  assign wrd_not_scrmbl = pre_blk_disable | pre_sds_disable;
end endgenerate
  
  // we just need stop scrambling of the low byte of data
  // for TS1/2. so we just need to stage the detection to
  // align it with the outgoing data and then set the lbyte_not_scrmbl
  delay_n_w_enable
   #(REGIN, SB_WD, 0) u_regin_lbyte_not_scrmbl
  (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (scramble_en),
    .din        (ts1_start | ts2_start | ts0_start),
    .dout       (lbyte_not_scrmbl)
  );
  
  // since all the control signals into scrambler are staged
  // we need to stage the data as well to be aligned with signals
  delay_n_w_enable
   #(REGIN, NB*8, 0) u_regin_data
  (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (scramble_en),
    .din        (in_data),
    .dout       (out_data)
  );

  // we need to issue begin/end and active state of each OS
  // TS0
  scramble3_pipe_scrmbl_osdetect
   #(.REGIN(REGIN), .REGOUT(REGOUT)) scramble3_pipe_scrmbl_osdetect_ts0
  (
   .core_clk(core_clk),
   .core_rst_n(core_rst_n),
   .scramble_en(scramble_en),
   .os_detect(ts0_start[0]),
   .in_startblock(startblock[0]),
   .in_aligned(in_aligned),
   .int_os_active(int_ints0[0]),
   .os_active(pre_ints0[0])
  );
  // TS1
  scramble3_pipe_scrmbl_osdetect
   #(.REGIN(REGIN), .REGOUT(REGOUT)) scramble3_pipe_scrmbl_osdetect_ts1 
  (
   .core_clk(core_clk),
   .core_rst_n(core_rst_n),
   .scramble_en(scramble_en),
   .os_detect(ts1_start[0]), 
   .in_startblock(startblock[0]),
   .in_aligned(in_aligned),
   .int_os_active(int_ints1[0]),
   .os_active(pre_ints1[0])
  );
  // ts2
  scramble3_pipe_scrmbl_osdetect
   #(.REGIN(REGIN), .REGOUT(REGOUT)) scramble3_pipe_scrmbl_osdetect_ts2 
  (
   .core_clk(core_clk),
   .core_rst_n(core_rst_n),
   .scramble_en(scramble_en),
   .os_detect(ts2_start[0]), 
   .in_startblock(startblock[0]),
   .in_aligned(in_aligned),
   .int_os_active(int_ints2[0]),
   .os_active(pre_ints2[0])
  );
  // skp
  scramble3_pipe_scrmbl_osdetect
   #(.REGIN(REGIN), .REGOUT(REGOUT)) scramble3_pipe_scrmbl_osdetect_skp 
  (
   .core_clk(core_clk),
   .core_rst_n(core_rst_n),
   .scramble_en(scramble_en),
   .os_detect(skp_start[0]), 
   .in_startblock(startblock[0]),
   .in_aligned(in_aligned),
   .int_os_active( int_inskp[0]),
   .os_active(pre_inskp[0])
  );
  // eie
  scramble3_pipe_scrmbl_osdetect
   #(.REGIN(REGIN), .REGOUT(REGOUT)) scramble3_pipe_scrmbl_osdetect_eie 
  (
   .core_clk(core_clk),
   .core_rst_n(core_rst_n),
   .scramble_en(scramble_en),
   .os_detect(eieos_start[0]), 
   .in_startblock(startblock[0]),
   .in_aligned(in_aligned),
   .int_os_active(int_ineie[0]),
   .os_active(pre_ineie[0])
  );
  // sds
  scramble3_pipe_scrmbl_osdetect
   #(.REGIN(REGIN), .REGOUT(REGOUT)) scramble3_pipe_scrmbl_osdetect_sds 
  (
   .core_clk(core_clk),
   .core_rst_n(core_rst_n),
   .scramble_en(scramble_en),
   .os_detect(sds_start[0]), 
   .in_startblock(startblock[0]),
   .in_aligned(in_aligned),
   .int_os_active( int_insds[0]),
   .os_active(pre_insds[0])
  );
  // ei
  scramble3_pipe_scrmbl_osdetect
   #(.REGIN(REGIN_EIOS), .REGOUT(REGOUT)) scramble3_pipe_scrmbl_osdetect_ei
  (
   .core_clk(core_clk),
   .core_rst_n(core_rst_n),
   .scramble_en(scramble_en),
   .os_detect(eios_start[0]),
   .in_startblock(startblock[0]),
   .in_aligned(in_aligned),
   .int_os_active(int_ineios[0]),
   .os_active()
  );

// latency adjustment
  localparam N_DELAY = LFSR_REGOUT
 + PRECODING_REGOUT
 + GLAYCODING_REGOUT
                       ;
  localparam DATAPATH_WIDTH = (5 + 1) * SB_WD;
  localparam RESET_VALUE   = {DATAPATH_WIDTH{1'b0}} ;

  delay_n_w_enable
  
  #(N_DELAY, DATAPATH_WIDTH, RESET_VALUE) u_delay(
      .clk        (core_clk),
      .rst_n      (core_rst_n),
      .clear      (1'b0),
      .en         (scramble_en),
      .din        ({ pre_ints0, pre_ints1, pre_ints2, pre_inskp, pre_ineie, pre_insds}),
      .dout       ({     ints0,     ints1,     ints2,     inskp,     ineie,     insds})
  );

endmodule
////////////////////////////////////////////////////////////////////////////// 
