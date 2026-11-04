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
// ---    $DateTime: 2022/05/05 01:39:57 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Amba/mstr_cpl_buf/DWC_pcie_amba_client_cpl_dword_algn.sv#4 $
// -------------------------------------------------------------------------
// Module Description:
//
// ---------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_amba_client_cpl_dword_algn
 #(
  // -------------------------------------------------------------------------------------
  // Parameters modified by an instantiation parameter assignment
  // -------------------------------------------------------------------------------------
  parameter HDR_INFO_WD                      = 32,
  // Segment data path width, 32,64,128,256-Bits
  parameter CC_MSTR_CPL_SEG_DATA_WD          = 128,
  // Segment data number of DWORD's
  parameter CC_MSTR_CPL_SEG_DATA_NUM_DWORDS  = 4,
  // Encoded data bus size (1024-bit=7,512-bit=6,256-bit=5,128-bit=4,64-bit=3)
  parameter CC_MSTR_CPL_SEG_DATA_SIZE_ENC    = 4,
  // -------------------------------------------------------------------------------------
  // Parameters not modified by an instantiation parameter assignment
  // -------------------------------------------------------------------------------------
  parameter TP                               = `TP
  )
 (
  // -------------------------------------------------------------------------------------
  // Clocks and resets
  // -------------------------------------------------------------------------------------
  input                                              core_clk ,
  input                                              core_rst_n,
  // -------------------------------------------------------------------------------------
  // Completion control interface
  // -------------------------------------------------------------------------------------
  input                                              mcctl_hv,
  input                                              mcctl_dv,
  input                                              mcctl_eot,
  input       [HDR_INFO_WD-1:0]                      mcctl_hdr_info,
  output wire                                        dwa_halt,
  // -------------------------------------------------------------------------------------
  // Segment buffer completion data interface
  // -------------------------------------------------------------------------------------
  input       [CC_MSTR_CPL_SEG_DATA_WD-1:0]          sbc_rdata,
  input       [CC_MSTR_CPL_SEG_DATA_NUM_DWORDS-1:0]  sbc_rdw_en,
  input                                              sbc_bad_eot,
  // -------------------------------------------------------------------------------------
  // DWORD aligned client completion interface
  // -------------------------------------------------------------------------------------
  output wire                                        dwa_dv,
  output wire [HDR_INFO_WD-1:0]                      dwa_hdr_info,
  output wire [CC_MSTR_CPL_SEG_DATA_NUM_DWORDS-1:0]  dwa_rdw_en,
  output wire [CC_MSTR_CPL_SEG_DATA_WD-1:0]          dwa_data,
  output wire                                        dwa_bad_eot,
  output wire                                        dwa_eot,
  input                                              halt
 );

  // -------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------
  localparam ST_IDLE = 2'b00;
  localparam ST_DLY_DATA = 2'b01;
  localparam ST_ALGN_DATA = 2'b10;
  localparam ST_DLY_EOT = 2'b11;

   localparam [8:0] BUS_INIT_BYTE = `CX_RAS_PARITY_MODE ? 9'b100000000 : 9'b000000000;
   localparam BYTE_WD_W_PAR = 9;
   localparam BUS_N_BYTES   = CC_MSTR_CPL_SEG_DATA_NUM_DWORDS * 4;

   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] DATA_RSHIFT1DW  = (~({CC_MSTR_CPL_SEG_DATA_WD{1'b1}} >>  BYTE_WD_W_PAR * 4)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] DATA_RSHIFT2DW  = (~({CC_MSTR_CPL_SEG_DATA_WD{1'b1}} >>  BYTE_WD_W_PAR * 8)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] DATA_RSHIFT3DW  = (~({CC_MSTR_CPL_SEG_DATA_WD{1'b1}} >>  BYTE_WD_W_PAR *12)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] DATA_RSHIFT4DW  = (~({CC_MSTR_CPL_SEG_DATA_WD{1'b1}} >>  BYTE_WD_W_PAR *16)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] DATA_RSHIFT5DW  = (~({CC_MSTR_CPL_SEG_DATA_WD{1'b1}} >>  BYTE_WD_W_PAR *20)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] DATA_RSHIFT6DW  = (~({CC_MSTR_CPL_SEG_DATA_WD{1'b1}} >>  BYTE_WD_W_PAR *24)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] DATA_RSHIFT7DW  = (~({CC_MSTR_CPL_SEG_DATA_WD{1'b1}} >>  BYTE_WD_W_PAR *28)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] DATA_RSHIFT8DW  = (~({CC_MSTR_CPL_SEG_DATA_WD{1'b1}} >>  BYTE_WD_W_PAR *32)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] DATA_RSHIFT9DW  = (~({CC_MSTR_CPL_SEG_DATA_WD{1'b1}} >>  BYTE_WD_W_PAR *36)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] DATA_RSHIFT10DW = (~({CC_MSTR_CPL_SEG_DATA_WD{1'b1}} >>  BYTE_WD_W_PAR *40)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] DATA_RSHIFT11DW = (~({CC_MSTR_CPL_SEG_DATA_WD{1'b1}} >>  BYTE_WD_W_PAR *44)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] DATA_RSHIFT12DW = (~({CC_MSTR_CPL_SEG_DATA_WD{1'b1}} >>  BYTE_WD_W_PAR *48)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] DATA_RSHIFT13DW = (~({CC_MSTR_CPL_SEG_DATA_WD{1'b1}} >>  BYTE_WD_W_PAR *52)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] DATA_RSHIFT14DW = (~({CC_MSTR_CPL_SEG_DATA_WD{1'b1}} >>  BYTE_WD_W_PAR *56)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] DATA_RSHIFT15DW = (~({CC_MSTR_CPL_SEG_DATA_WD{1'b1}} >>  BYTE_WD_W_PAR *60)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] DATA_RSHIFT16DW = (~({CC_MSTR_CPL_SEG_DATA_WD{1'b1}} >>  BYTE_WD_W_PAR *64)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] DATA_RSHIFT17DW = (~({CC_MSTR_CPL_SEG_DATA_WD{1'b1}} >>  BYTE_WD_W_PAR *68)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] DATA_RSHIFT18DW = (~({CC_MSTR_CPL_SEG_DATA_WD{1'b1}} >>  BYTE_WD_W_PAR *72)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] DATA_RSHIFT19DW = (~({CC_MSTR_CPL_SEG_DATA_WD{1'b1}} >>  BYTE_WD_W_PAR *76)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] DATA_RSHIFT20DW = (~({CC_MSTR_CPL_SEG_DATA_WD{1'b1}} >>  BYTE_WD_W_PAR *80)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] DATA_RSHIFT21DW = (~({CC_MSTR_CPL_SEG_DATA_WD{1'b1}} >>  BYTE_WD_W_PAR *84)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] DATA_RSHIFT22DW = (~({CC_MSTR_CPL_SEG_DATA_WD{1'b1}} >>  BYTE_WD_W_PAR *88)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] DATA_RSHIFT23DW = (~({CC_MSTR_CPL_SEG_DATA_WD{1'b1}} >>  BYTE_WD_W_PAR *92)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] DATA_RSHIFT24DW = (~({CC_MSTR_CPL_SEG_DATA_WD{1'b1}} >>  BYTE_WD_W_PAR *96)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] DATA_RSHIFT25DW = (~({CC_MSTR_CPL_SEG_DATA_WD{1'b1}} >>  BYTE_WD_W_PAR *100)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] DATA_RSHIFT26DW = (~({CC_MSTR_CPL_SEG_DATA_WD{1'b1}} >>  BYTE_WD_W_PAR *104)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] DATA_RSHIFT27DW = (~({CC_MSTR_CPL_SEG_DATA_WD{1'b1}} >>  BYTE_WD_W_PAR *108)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] DATA_RSHIFT28DW = (~({CC_MSTR_CPL_SEG_DATA_WD{1'b1}} >>  BYTE_WD_W_PAR *112)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] DATA_RSHIFT29DW = (~({CC_MSTR_CPL_SEG_DATA_WD{1'b1}} >>  BYTE_WD_W_PAR *116)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] DATA_RSHIFT30DW = (~({CC_MSTR_CPL_SEG_DATA_WD{1'b1}} >>  BYTE_WD_W_PAR *120)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] DATA_RSHIFT31DW = (~({CC_MSTR_CPL_SEG_DATA_WD{1'b1}} >>  BYTE_WD_W_PAR *124)) & {BUS_N_BYTES{BUS_INIT_BYTE}};
   
   localparam [CC_MSTR_CPL_SEG_DATA_WD-1:0] BUS_INIT = {BUS_N_BYTES{BUS_INIT_BYTE}};
  // -------------------------------------------------------------------------------------
  // Internal wires/regs
  // -------------------------------------------------------------------------------------
  wire [CC_MSTR_CPL_SEG_DATA_WD-1:0]                 s_sbc_rdata;
  wire [CC_MSTR_CPL_SEG_DATA_NUM_DWORDS-1:0]         s_sbc_rdw_en;

  reg  [HDR_INFO_WD-1:0]                             r_hdr_info;

  reg  [1:0]                                         s_algn_state;
  reg  [1:0]                                         r_algn_state;
  reg                                                s_dw_shift_data_sel;
  reg                                                r_dw_shift_data_sel;
  reg                                                s_dv_algnd;
  reg                                                s_eot_algnd;
  reg                                                s_left_shift_data_valid;

  reg  [CC_MSTR_CPL_SEG_DATA_SIZE_ENC-2:0]           s_rdw_cnt;
  reg  [CC_MSTR_CPL_SEG_DATA_SIZE_ENC-3:0]           s_left_shift_cnt;
  reg  [CC_MSTR_CPL_SEG_DATA_SIZE_ENC-3:0]           r_left_shift_cnt;
  reg  [CC_MSTR_CPL_SEG_DATA_SIZE_ENC-3:0]           s_right_shift_cnt;
  reg  [CC_MSTR_CPL_SEG_DATA_SIZE_ENC-3:0]           r_right_shift_cnt;
  wire [CC_MSTR_CPL_SEG_DATA_SIZE_ENC-3:0]           s_left_shift_factor;
  wire [CC_MSTR_CPL_SEG_DATA_SIZE_ENC-3:0]           s_right_shift_factor;

  reg  [CC_MSTR_CPL_SEG_DATA_WD-1:0]                 s_left_shift_data;
  reg  [CC_MSTR_CPL_SEG_DATA_NUM_DWORDS-1:0]         s_left_shift_rdw_en;
  reg  [CC_MSTR_CPL_SEG_DATA_WD-1:0]                 s_right_shift_data;
  reg  [CC_MSTR_CPL_SEG_DATA_WD-1:0]                 r_right_shift_data;
  reg  [CC_MSTR_CPL_SEG_DATA_NUM_DWORDS-1:0]         s_right_shift_rdw_en;
  reg  [CC_MSTR_CPL_SEG_DATA_NUM_DWORDS-1:0]         r_right_shift_rdw_en;

  wire [CC_MSTR_CPL_SEG_DATA_WD-1:0]                 s_right_left_shift_data;
  wire [CC_MSTR_CPL_SEG_DATA_NUM_DWORDS-1:0]         s_right_left_shift_rdw_en;
  reg  [CC_MSTR_CPL_SEG_DATA_WD-1:0]                 s_algnd_data;
  reg  [CC_MSTR_CPL_SEG_DATA_NUM_DWORDS-1:0]         s_algnd_rdw_en;

  reg                                                r_sbc_bad_eot;
  reg                                                s_bad_eot_algnd;
  // -------------------------------------------------------------------------------------
  // Internal design
  // -------------------------------------------------------------------------------------
  // Zero invalid input data. Avoids corrupting OR'ed left and right shifted data.
  assign s_sbc_rdata  = mcctl_dv ? sbc_rdata : BUS_INIT;
  assign s_sbc_rdw_en = sbc_rdw_en & {CC_MSTR_CPL_SEG_DATA_NUM_DWORDS{mcctl_dv}};

  // -------------------------------------------------------------------------------------
  // Align the header information with the aligned data
  // -------------------------------------------------------------------------------------
  always @(posedge core_clk or negedge core_rst_n) begin : proc_seq_hdr_info
    if (!core_rst_n) begin
      r_hdr_info    <= # TP {HDR_INFO_WD{1'b0}};
      r_sbc_bad_eot <= # TP 1'b0;
    end else if (!halt) begin
      r_hdr_info    <= # TP mcctl_hdr_info;
      r_sbc_bad_eot <= # TP sbc_bad_eot;
    end
  end

  // -------------------------------------------------------------------------------------
  // Data alignment FSM
  // -------------------------------------------------------------------------------------
  // FSM combinational
  always @(*) begin : proc_comb_dw_alignment_fsm
    s_algn_state            = r_algn_state;
    s_dv_algnd              = 1'b0;
    s_eot_algnd             = 1'b0;
    s_bad_eot_algnd         = 1'b0;
    s_dw_shift_data_sel     = r_dw_shift_data_sel;
    s_left_shift_data_valid = 1'b1;

    case (r_algn_state)
      ST_IDLE : begin
        // Single beat non-posted write and error Cpl TLP's are registered thru
        // the alignment block. For FSM CPL treated as a single beat CplD.
        // Before transmiting completion we check the register DW enables; if all
        // zeros then de-assert data valid.
        // Bad eot valid for Cpl and CplD completions.
        if (mcctl_dv || mcctl_hv) begin
          if (mcctl_eot) begin
            s_algn_state = ST_DLY_EOT;
          end else begin
            if (&s_sbc_rdw_en) begin
              s_algn_state = ST_DLY_DATA;
            end else begin
              s_algn_state = ST_ALGN_DATA;
              s_dw_shift_data_sel = 1'b1;
            end
          end
        end
      end
      ST_DLY_DATA : begin
        s_dv_algnd = 1'b1;
        if (mcctl_dv && mcctl_eot) begin
          s_algn_state = ST_DLY_EOT;
        end
      end
      ST_ALGN_DATA : begin
        s_dv_algnd = 1'b1;
        if (mcctl_dv) begin
          if (mcctl_eot) begin
            if (|s_right_shift_rdw_en) begin
              // Shifted DWORDS require and extra cycle to end the transfer
              s_algn_state = ST_DLY_EOT;
            end else begin
              // Shifted DWORDS previously compressed into a single beat
              s_algn_state        = ST_IDLE;
              s_dw_shift_data_sel = 1'b0;
              s_eot_algnd         = mcctl_eot;
              s_bad_eot_algnd     = sbc_bad_eot;
            end
          end
        end
      end
      ST_DLY_EOT : begin
        s_dv_algnd              = 1'b1;
        s_eot_algnd             = 1'b1;
        s_bad_eot_algnd         = r_sbc_bad_eot;
        // Force left shift data to all zeros. Avoids corruption of OR'ed left and
        // right shift data when back to back completions are received and the aligned eot
        // for the first completion is delayed.
        s_left_shift_data_valid = 1'b0;

        if (mcctl_dv || mcctl_hv) begin
          if (mcctl_eot) begin
            s_dw_shift_data_sel = 1'b0;
          end else begin
            if (&s_sbc_rdw_en) begin
              s_algn_state        = ST_DLY_DATA;
              s_dw_shift_data_sel = 1'b0;
            end else begin
              s_algn_state        = ST_ALGN_DATA;
              s_dw_shift_data_sel = 1'b1;
            end
          end
        end else begin
          s_algn_state        = ST_IDLE;
          s_dw_shift_data_sel = 1'b0;
        end
      end
      default : begin
        s_algn_state        = ST_IDLE;
        s_dv_algnd          = 1'b0;
        s_eot_algnd         = 1'b0;
        s_bad_eot_algnd     = 1'b0;
        s_dw_shift_data_sel = r_dw_shift_data_sel;
      end
    endcase
  end

  // FSM sequential
  always @(posedge core_clk or negedge core_rst_n) begin : proc_seq_dw_alignment_fsm
    if (!core_rst_n) begin
      r_dw_shift_data_sel <= # TP 1'b0;
      r_algn_state        <= # TP ST_IDLE;
    end else if (!halt) begin
      r_dw_shift_data_sel <= # TP s_dw_shift_data_sel;
      r_algn_state        <= # TP s_algn_state;
    end
  end

  // -------------------------------------------------------------------------------------
  // Left and right shift logic
  // -------------------------------------------------------------------------------------
  generate
    case (CC_MSTR_CPL_SEG_DATA_NUM_DWORDS)
      //Leda compile error if localparam/param or define used to declare item expresssion.
      //#RULE: policy ruleset COMP.sl [FAILURE] CMPVE110
      //NUM_DWORDS_64_BIT : begin
      2 : begin : GEN_NUM_DWORDS_2
        // Convert DWORD enable to number of valid DWORD's
        always @(*) begin : proc_comb_rdw_cnt_64
          // Initialise
          s_left_shift_cnt  = r_left_shift_cnt;
          s_right_shift_cnt = r_right_shift_cnt;
          s_rdw_cnt         = 2'd0;

          // Calculate left and right shift count on first beat
          if (mcctl_hv) begin
            case (s_sbc_rdw_en)
              2'b10   : s_rdw_cnt = 2'd1;
              2'b11   : s_rdw_cnt = 2'd2;
              default : s_rdw_cnt = 2'd0;
            endcase

            s_left_shift_cnt  = s_rdw_cnt[0];
            s_right_shift_cnt = (CC_MSTR_CPL_SEG_DATA_NUM_DWORDS - s_left_shift_cnt);
          end
        end


        // Calculate left and right shift factors on first and subsequent beats
        always @(posedge core_clk or negedge core_rst_n) begin : proc_seq_shift_cnt
          if (!core_rst_n) begin
            r_left_shift_cnt  <= # TP 1'd0;
            r_right_shift_cnt <= # TP 1'd0;
          end else if (!halt) begin
              r_left_shift_cnt  <= # TP s_left_shift_cnt;
              r_right_shift_cnt <= # TP s_right_shift_cnt;
          end
        end


        assign s_left_shift_factor = r_left_shift_cnt;
        assign s_right_shift_factor = mcctl_hv ? s_right_shift_cnt : r_right_shift_cnt;

        // Shift data and DWORD enables
        always @(*) begin : proc_comb_shift_data
          // Initialise
          s_left_shift_data    = {CC_MSTR_CPL_SEG_DATA_WD{1'b0}};
          s_left_shift_rdw_en  = {CC_MSTR_CPL_SEG_DATA_NUM_DWORDS{1'b0}};
          s_right_shift_data   = {CC_MSTR_CPL_SEG_DATA_WD{1'b0}};
          s_right_shift_rdw_en = {CC_MSTR_CPL_SEG_DATA_NUM_DWORDS{1'b0}};

          case (s_left_shift_factor)
           1'd0 : begin
             s_left_shift_data   = s_sbc_rdata;
             s_left_shift_rdw_en = s_sbc_rdw_en;
           end
           1'd1 : begin
             s_left_shift_data   = s_sbc_rdata << CC_MSTR_CPL_SEG_DATA_WD/2;
             s_left_shift_rdw_en = s_sbc_rdw_en << 1;
           end
           default : begin
             s_left_shift_data   = {CC_MSTR_CPL_SEG_DATA_WD{1'b0}};
             s_left_shift_rdw_en = {CC_MSTR_CPL_SEG_DATA_NUM_DWORDS{1'b0}};
           end
          endcase
          case (s_right_shift_factor)
           1'd0 : begin
             s_right_shift_data   = s_sbc_rdata;
             s_right_shift_rdw_en = s_sbc_rdw_en;
           end
           1'd1 : begin
             s_right_shift_data   = s_sbc_rdata >> CC_MSTR_CPL_SEG_DATA_WD/2 | (DATA_RSHIFT1DW & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 1;
           end
           default : begin
             s_right_shift_data   = {CC_MSTR_CPL_SEG_DATA_WD{1'b0}};
             s_right_shift_rdw_en = {CC_MSTR_CPL_SEG_DATA_NUM_DWORDS{1'b0}};
           end
         endcase
        end
      end
      //Leda compile error if localparam/param or `define used to declare item expresssion.
      //#RULE: policy ruleset COMP.sl [FAILURE] CMPVE110
      //NUM_DWORDS_128_BIT : begin
      4 : begin : GEN_NUM_DWORDS_4
        // Convert DWORD enable to number of valid DWORD's
        always @(*) begin : proc_comb_rdw_cnt_128
          s_left_shift_cnt  = r_left_shift_cnt;
          s_right_shift_cnt = r_right_shift_cnt;
          s_rdw_cnt         = 3'd0;

          if (mcctl_hv) begin
            casez (s_sbc_rdw_en)
              // Allow for wide and narrow DWORD transfers.
              // e.g. 4'b1100 (wide), 4'b0010 (narrow)
              4'b1000 : s_rdw_cnt = 3'd1;
              4'b?100 : s_rdw_cnt = 3'd2;
              4'b??10 : s_rdw_cnt = 3'd3;
              4'b1111 : s_rdw_cnt = 3'd4;
              default : s_rdw_cnt = 3'd0;
            endcase

            s_left_shift_cnt  = s_rdw_cnt[1:0];
            s_right_shift_cnt = (CC_MSTR_CPL_SEG_DATA_NUM_DWORDS - s_left_shift_cnt);
          end
        end


        // Calculate left and right shift factors
        always @(posedge core_clk or negedge core_rst_n) begin : proc_seq_shift_cnt
          if (!core_rst_n) begin
            r_left_shift_cnt  <= # TP 2'd0;
            r_right_shift_cnt <= # TP 2'd0;
          end else if (!halt) begin
            r_left_shift_cnt  <= # TP s_left_shift_cnt;
            r_right_shift_cnt <= # TP s_right_shift_cnt;
          end
        end


        assign s_left_shift_factor  = r_left_shift_cnt;
        assign s_right_shift_factor = mcctl_hv ? s_right_shift_cnt : r_right_shift_cnt;

        // Shift data and DWORD enables
        always @(*) begin : proc_comb_shift_data
          // Initialise
          s_left_shift_data    = {CC_MSTR_CPL_SEG_DATA_WD{1'b0}};
          s_left_shift_rdw_en  = {CC_MSTR_CPL_SEG_DATA_NUM_DWORDS{1'b0}};
          s_right_shift_data   = {CC_MSTR_CPL_SEG_DATA_WD{1'b0}};
          s_right_shift_rdw_en = {CC_MSTR_CPL_SEG_DATA_NUM_DWORDS{1'b0}};

          case (s_left_shift_factor)
           2'd0 : begin
             s_left_shift_data   = s_sbc_rdata;
             s_left_shift_rdw_en = s_sbc_rdw_en;
           end
           2'd1 : begin
             s_left_shift_data   = s_sbc_rdata << CC_MSTR_CPL_SEG_DATA_WD/4;
             s_left_shift_rdw_en = s_sbc_rdw_en << 1;
           end
           2'd2 : begin
             s_left_shift_data   = s_sbc_rdata << CC_MSTR_CPL_SEG_DATA_WD/2;
             s_left_shift_rdw_en = s_sbc_rdw_en << 2;
           end
           2'd3 : begin
             s_left_shift_data   = s_sbc_rdata << (3*CC_MSTR_CPL_SEG_DATA_WD)/4;
             s_left_shift_rdw_en = s_sbc_rdw_en << 3;
           end
           default : begin
             s_left_shift_data   = {CC_MSTR_CPL_SEG_DATA_WD{1'b0}};
             s_left_shift_rdw_en = {CC_MSTR_CPL_SEG_DATA_NUM_DWORDS{1'b0}};
           end
          endcase
          case (s_right_shift_factor)
           2'd0 : begin
             s_right_shift_data   = s_sbc_rdata;
             s_right_shift_rdw_en = s_sbc_rdw_en;
           end
           2'd1 : begin
             s_right_shift_data   = (s_sbc_rdata >> CC_MSTR_CPL_SEG_DATA_WD/4) | (DATA_RSHIFT1DW & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 1;
           end
           2'd2 : begin
             s_right_shift_data   = (s_sbc_rdata >> CC_MSTR_CPL_SEG_DATA_WD/2) | (DATA_RSHIFT2DW & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 2;
           end
           2'd3 : begin
             s_right_shift_data   = (s_sbc_rdata >> 3*(CC_MSTR_CPL_SEG_DATA_WD/4)) | (DATA_RSHIFT3DW & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 3;
           end
           default : begin
             s_right_shift_data   = {CC_MSTR_CPL_SEG_DATA_WD{1'b0}};
             s_right_shift_rdw_en = {CC_MSTR_CPL_SEG_DATA_NUM_DWORDS{1'b0}};
           end
         endcase
        end
      end
      //Leda compile error if localparam/param or define used to declare item expresssion.
      //#RULE: policy ruleset COMP.sl [FAILURE] CMPVE110
      //NUM_DWORDS_256_BIT : begin
      8 : begin : GEN_NUM_DWORDS_8

        always @(*) begin : proc_comb_rdw_cnt_256
          s_left_shift_cnt  = r_left_shift_cnt;
          s_right_shift_cnt = r_right_shift_cnt;
          s_rdw_cnt         = 4'd0;

          if (mcctl_hv) begin
            casez (s_sbc_rdw_en)
              // Allow for wide and narrow DWORD transfers.
              // e.g. 8'b11110000 (wide), 8'b00010000 (narrow)
              8'b10000000 : s_rdw_cnt = 4'd1;
              8'b?1000000 : s_rdw_cnt = 4'd2;
              8'b??100000 : s_rdw_cnt = 4'd3;
              8'b???10000 : s_rdw_cnt = 4'd4;
              8'b????1000 : s_rdw_cnt = 4'd5;
              8'b?????100 : s_rdw_cnt = 4'd6;
              8'b??????10 : s_rdw_cnt = 4'd7;
              8'b11111111 : s_rdw_cnt = 4'd8;
              default     : s_rdw_cnt = 4'd0;
            endcase
            s_left_shift_cnt = s_rdw_cnt[2:0];
            s_right_shift_cnt = (CC_MSTR_CPL_SEG_DATA_NUM_DWORDS - s_left_shift_cnt);
          end
        end


        // Calculate left and right shift factors
        always @(posedge core_clk or negedge core_rst_n) begin : proc_seq_shift_cnt
          if (!core_rst_n) begin
            r_left_shift_cnt  <= # TP 3'd0;
            r_right_shift_cnt <= # TP 3'd0;
          end else if (!halt) begin
            r_left_shift_cnt  <= # TP s_left_shift_cnt;
            r_right_shift_cnt <= # TP s_right_shift_cnt;
          end
        end


        assign s_left_shift_factor  = r_left_shift_cnt;
        assign s_right_shift_factor = mcctl_hv ? s_right_shift_cnt : r_right_shift_cnt;

        // Shift data and DWORD enables
        always @(*) begin : proc_comb_shift_data
          // Initialise
          s_left_shift_data    = {CC_MSTR_CPL_SEG_DATA_WD{1'b0}};
          s_left_shift_rdw_en  = {CC_MSTR_CPL_SEG_DATA_NUM_DWORDS{1'b0}};
          s_right_shift_data   = {CC_MSTR_CPL_SEG_DATA_WD{1'b0}};
          s_right_shift_rdw_en = {CC_MSTR_CPL_SEG_DATA_NUM_DWORDS{1'b0}};

          case (s_left_shift_factor)
           3'd0 : begin
             s_left_shift_data   = s_sbc_rdata;
             s_left_shift_rdw_en = s_sbc_rdw_en;
           end
           3'd1 : begin
             s_left_shift_data   = s_sbc_rdata << CC_MSTR_CPL_SEG_DATA_WD/8;
             s_left_shift_rdw_en = s_sbc_rdw_en << 1;
           end
           3'd2 : begin
             s_left_shift_data   = s_sbc_rdata << CC_MSTR_CPL_SEG_DATA_WD/4;
             s_left_shift_rdw_en = s_sbc_rdw_en << 2;
           end
           3'd3 : begin
             s_left_shift_data   = s_sbc_rdata << 3*(CC_MSTR_CPL_SEG_DATA_WD/8);
             s_left_shift_rdw_en = s_sbc_rdw_en << 3;
           end
           3'd4 : begin
             s_left_shift_data   = s_sbc_rdata << CC_MSTR_CPL_SEG_DATA_WD/2;
             s_left_shift_rdw_en = s_sbc_rdw_en << 4;
           end
           3'd5 : begin
             s_left_shift_data   = s_sbc_rdata << 5*(CC_MSTR_CPL_SEG_DATA_WD/8);
             s_left_shift_rdw_en = s_sbc_rdw_en << 5;
           end
           3'd6 : begin
             s_left_shift_data   = s_sbc_rdata << 3*(CC_MSTR_CPL_SEG_DATA_WD/4);
             s_left_shift_rdw_en = s_sbc_rdw_en << 6;
           end
           3'd7 : begin
             s_left_shift_data   = s_sbc_rdata << 7*(CC_MSTR_CPL_SEG_DATA_WD/8);
             s_left_shift_rdw_en = s_sbc_rdw_en << 7;
           end
           default : begin
             s_left_shift_data   = {CC_MSTR_CPL_SEG_DATA_WD{1'b0}};
             s_left_shift_rdw_en = {CC_MSTR_CPL_SEG_DATA_NUM_DWORDS{1'b0}};
           end
          endcase
          case (s_right_shift_factor)
           3'd0 : begin
             s_right_shift_data   = s_sbc_rdata;
             s_right_shift_rdw_en = s_sbc_rdw_en;
           end
           3'd1 : begin
             s_right_shift_data   = (s_sbc_rdata >> CC_MSTR_CPL_SEG_DATA_WD/8) | (DATA_RSHIFT1DW & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 1;
           end
           3'd2 : begin
             s_right_shift_data   = (s_sbc_rdata >> CC_MSTR_CPL_SEG_DATA_WD/4) | (DATA_RSHIFT2DW & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 2;
           end
           3'd3 : begin
             s_right_shift_data   = (s_sbc_rdata >> 3*(CC_MSTR_CPL_SEG_DATA_WD/8)) | (DATA_RSHIFT3DW & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 3;
           end
           3'd4 : begin
             s_right_shift_data   = (s_sbc_rdata >> CC_MSTR_CPL_SEG_DATA_WD/2) | (DATA_RSHIFT4DW & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 4;
           end
           3'd5 : begin
             s_right_shift_data   = (s_sbc_rdata >> 5*(CC_MSTR_CPL_SEG_DATA_WD/8)) | (DATA_RSHIFT5DW & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 5;
           end
           3'd6 : begin
             s_right_shift_data   = (s_sbc_rdata >> 3*(CC_MSTR_CPL_SEG_DATA_WD/4)) | (DATA_RSHIFT6DW & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 6;
           end
           3'd7 : begin
             s_right_shift_data   = (s_sbc_rdata >> 7*(CC_MSTR_CPL_SEG_DATA_WD/8)) | (DATA_RSHIFT7DW & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 7;
           end
           endcase
         end
       end
      //Leda compile error if localparam/param or define used to declare item expresssion.
      //#RULE: policy ruleset COMP.sl [FAILURE] CMPVE110
      //NUM_DWORDS_512_BIT : begin
      16 : begin : GEN_NUM_DWORDS_16

        always @(*) begin : proc_comb_rdw_cnt_512
          s_left_shift_cnt  = r_left_shift_cnt;
          s_right_shift_cnt = r_right_shift_cnt;
          s_rdw_cnt         = 5'd0;

          if (mcctl_hv) begin
            casez (s_sbc_rdw_en)
              // Allow for wide and narrow DWORD transfers.
              // e.g. 8'b11110000 (wide), 8'b00010000 (narrow)
              16'b1000000000000000 : s_rdw_cnt = 5'd1;
              16'b?100000000000000 : s_rdw_cnt = 5'd2;
              16'b??10000000000000 : s_rdw_cnt = 5'd3;
              16'b???1000000000000 : s_rdw_cnt = 5'd4;
              16'b????100000000000 : s_rdw_cnt = 5'd5;
              16'b?????10000000000 : s_rdw_cnt = 5'd6;
              16'b??????1000000000 : s_rdw_cnt = 5'd7;
              16'b???????100000000 : s_rdw_cnt = 5'd8;
              16'b????????10000000 : s_rdw_cnt = 5'd9;
              16'b?????????1000000 : s_rdw_cnt = 5'd10;
              16'b??????????100000 : s_rdw_cnt = 5'd11;
              16'b???????????10000 : s_rdw_cnt = 5'd12;
              16'b????????????1000 : s_rdw_cnt = 5'd13;
              16'b?????????????100 : s_rdw_cnt = 5'd14;
              16'b??????????????10 : s_rdw_cnt = 5'd15;
              16'b1111111111111111 : s_rdw_cnt = 5'd16;
              default     : s_rdw_cnt = 5'd0;
            endcase
            s_left_shift_cnt = s_rdw_cnt[3:0];
            s_right_shift_cnt = (CC_MSTR_CPL_SEG_DATA_NUM_DWORDS - s_left_shift_cnt);
          end
        end


        // Calculate left and right shift factors
        always @(posedge core_clk or negedge core_rst_n) begin : proc_seq_shift_cnt
          if (!core_rst_n) begin
            r_left_shift_cnt  <= # TP 4'd0;
            r_right_shift_cnt <= # TP 4'd0;
          end else if (!halt) begin
            r_left_shift_cnt  <= # TP s_left_shift_cnt;
            r_right_shift_cnt <= # TP s_right_shift_cnt;
          end
        end


        assign s_left_shift_factor  = r_left_shift_cnt;
        assign s_right_shift_factor = mcctl_hv ? s_right_shift_cnt : r_right_shift_cnt;

        // Shift data and DWORD enables
        always @(*) begin : proc_comb_shift_data
          // Initialise
          s_left_shift_data    = {CC_MSTR_CPL_SEG_DATA_WD{1'b0}};
          s_left_shift_rdw_en  = {CC_MSTR_CPL_SEG_DATA_NUM_DWORDS{1'b0}};
          s_right_shift_data   = {CC_MSTR_CPL_SEG_DATA_WD{1'b0}};
          s_right_shift_rdw_en = {CC_MSTR_CPL_SEG_DATA_NUM_DWORDS{1'b0}};

          case (s_left_shift_factor)
           4'd0 : begin
             s_left_shift_data   = s_sbc_rdata;
             s_left_shift_rdw_en = s_sbc_rdw_en;
           end
           4'd1 : begin
             s_left_shift_data   = s_sbc_rdata << 1*(CC_MSTR_CPL_SEG_DATA_WD/16);
             s_left_shift_rdw_en = s_sbc_rdw_en << 1;
           end
           4'd2 : begin
             s_left_shift_data   = s_sbc_rdata << 2*(CC_MSTR_CPL_SEG_DATA_WD/16);
             s_left_shift_rdw_en = s_sbc_rdw_en << 2;
           end
           4'd3 : begin
             s_left_shift_data   = s_sbc_rdata << 3*(CC_MSTR_CPL_SEG_DATA_WD/16);
             s_left_shift_rdw_en = s_sbc_rdw_en << 3;
           end
           4'd4 : begin
             s_left_shift_data   = s_sbc_rdata << 4*(CC_MSTR_CPL_SEG_DATA_WD/16);
             s_left_shift_rdw_en = s_sbc_rdw_en << 4;
           end
           4'd5 : begin
             s_left_shift_data   = s_sbc_rdata << 5*(CC_MSTR_CPL_SEG_DATA_WD/16);
             s_left_shift_rdw_en = s_sbc_rdw_en << 5;
           end
           4'd6 : begin
             s_left_shift_data   = s_sbc_rdata << 6*(CC_MSTR_CPL_SEG_DATA_WD/16);
             s_left_shift_rdw_en = s_sbc_rdw_en << 6;
           end
           4'd7 : begin
             s_left_shift_data   = s_sbc_rdata << 7*(CC_MSTR_CPL_SEG_DATA_WD/16);
             s_left_shift_rdw_en = s_sbc_rdw_en << 7;
           end
           4'd8 : begin
             s_left_shift_data   = s_sbc_rdata << 8*(CC_MSTR_CPL_SEG_DATA_WD/16);
             s_left_shift_rdw_en = s_sbc_rdw_en << 8;
           end
           4'd9 : begin
             s_left_shift_data   = s_sbc_rdata << 9*(CC_MSTR_CPL_SEG_DATA_WD/16);
             s_left_shift_rdw_en = s_sbc_rdw_en << 9;
           end
           4'd10 : begin
             s_left_shift_data   = s_sbc_rdata << 10*(CC_MSTR_CPL_SEG_DATA_WD/16);
             s_left_shift_rdw_en = s_sbc_rdw_en << 10;
           end
           4'd11 : begin
             s_left_shift_data   = s_sbc_rdata << 11*(CC_MSTR_CPL_SEG_DATA_WD/16);
             s_left_shift_rdw_en = s_sbc_rdw_en << 11;
           end
           4'd12 : begin
             s_left_shift_data   = s_sbc_rdata << 12*(CC_MSTR_CPL_SEG_DATA_WD/16);
             s_left_shift_rdw_en = s_sbc_rdw_en << 12;
           end
           4'd13 : begin
             s_left_shift_data   = s_sbc_rdata << 13*(CC_MSTR_CPL_SEG_DATA_WD/16);
             s_left_shift_rdw_en = s_sbc_rdw_en << 13;
           end
           4'd14 : begin
             s_left_shift_data   = s_sbc_rdata << 14*(CC_MSTR_CPL_SEG_DATA_WD/16);
             s_left_shift_rdw_en = s_sbc_rdw_en << 14;
           end
           4'd15 : begin
             s_left_shift_data   = s_sbc_rdata << 15*(CC_MSTR_CPL_SEG_DATA_WD/16);
             s_left_shift_rdw_en = s_sbc_rdw_en << 15;
           end
           default : begin
             s_left_shift_data   = {CC_MSTR_CPL_SEG_DATA_WD{1'b0}};
             s_left_shift_rdw_en = {CC_MSTR_CPL_SEG_DATA_NUM_DWORDS{1'b0}};
           end
          endcase
          case (s_right_shift_factor)
           4'd0  : begin
             s_right_shift_data   = s_sbc_rdata;
             s_right_shift_rdw_en = s_sbc_rdw_en;
           end
           4'd1  : begin
             s_right_shift_data   = (s_sbc_rdata >>    CC_MSTR_CPL_SEG_DATA_WD/16)   | (DATA_RSHIFT1DW  & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >>  1;
           end
           4'd2  : begin
             s_right_shift_data   = (s_sbc_rdata >>  2*(CC_MSTR_CPL_SEG_DATA_WD/16)) | (DATA_RSHIFT2DW  & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >>  2;
           end
           4'd3  : begin
             s_right_shift_data   = (s_sbc_rdata >>  3*(CC_MSTR_CPL_SEG_DATA_WD/16)) | (DATA_RSHIFT3DW  & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >>  3;
           end
           4'd4  : begin
             s_right_shift_data   = (s_sbc_rdata >>  4*(CC_MSTR_CPL_SEG_DATA_WD/16)) | (DATA_RSHIFT4DW  & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >>  4;
           end
           4'd5  : begin
             s_right_shift_data   = (s_sbc_rdata >>  5*(CC_MSTR_CPL_SEG_DATA_WD/16)) | (DATA_RSHIFT5DW  & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >>  5;
           end
           4'd6  : begin
             s_right_shift_data   = (s_sbc_rdata >>  6*(CC_MSTR_CPL_SEG_DATA_WD/16)) | (DATA_RSHIFT6DW  & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >>  6;
           end
           4'd7  : begin
             s_right_shift_data   = (s_sbc_rdata >>  7*(CC_MSTR_CPL_SEG_DATA_WD/16)) | (DATA_RSHIFT7DW  & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >>  7;
           end
           4'd8  : begin
             s_right_shift_data   = (s_sbc_rdata >>  8*(CC_MSTR_CPL_SEG_DATA_WD/16)) | (DATA_RSHIFT8DW  & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >>  8;
           end
           4'd9  : begin
             s_right_shift_data   = (s_sbc_rdata >>  9*(CC_MSTR_CPL_SEG_DATA_WD/16)) | (DATA_RSHIFT9DW  & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >>  9;
           end
           4'd10 : begin
             s_right_shift_data   = (s_sbc_rdata >> 10*(CC_MSTR_CPL_SEG_DATA_WD/16)) | (DATA_RSHIFT10DW & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 10;
           end
           4'd11 : begin
             s_right_shift_data   = (s_sbc_rdata >> 11*(CC_MSTR_CPL_SEG_DATA_WD/16)) | (DATA_RSHIFT11DW & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 11;
           end
           4'd12 : begin
             s_right_shift_data   = (s_sbc_rdata >> 12*(CC_MSTR_CPL_SEG_DATA_WD/16)) | (DATA_RSHIFT12DW & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 12;
           end
           4'd13 : begin
             s_right_shift_data   = (s_sbc_rdata >> 13*(CC_MSTR_CPL_SEG_DATA_WD/16)) | (DATA_RSHIFT13DW & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 13;
           end
           4'd14 : begin
             s_right_shift_data   = (s_sbc_rdata >> 14*(CC_MSTR_CPL_SEG_DATA_WD/16)) | (DATA_RSHIFT14DW & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 14;
           end
           4'd15 : begin
             s_right_shift_data   = (s_sbc_rdata >> 15*(CC_MSTR_CPL_SEG_DATA_WD/16)) | (DATA_RSHIFT15DW & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 15;
           end
           default : begin
             s_right_shift_data   = {CC_MSTR_CPL_SEG_DATA_WD{1'b0}};
             s_right_shift_rdw_en = {CC_MSTR_CPL_SEG_DATA_NUM_DWORDS{1'b0}};
           end
           endcase
          end
        end
      //Leda compile error if localparam/param or define used to declare item expresssion.
      //#RULE: policy ruleset COMP.sl [FAILURE] CMPVE110
      //NUM_DWORDS_1024_BIT : begin
      32 : begin : GEN_NUM_DWORDS_32

        always @(*) begin : proc_comb_rdw_cnt_1024
          s_left_shift_cnt  = r_left_shift_cnt;
          s_right_shift_cnt = r_right_shift_cnt;
          s_rdw_cnt         = 6'd0;

          if (mcctl_hv) begin
            casez (s_sbc_rdw_en)
              // Allow for wide and narrow DWORD transfers.
              // e.g. 8'b11110000 (wide), 8'b00010000 (narrow)
              32'b10000000000000000000000000000000 : s_rdw_cnt = 6'd1;
              32'b?1000000000000000000000000000000 : s_rdw_cnt = 6'd2;
              32'b??100000000000000000000000000000 : s_rdw_cnt = 6'd3;
              32'b???10000000000000000000000000000 : s_rdw_cnt = 6'd4;
              32'b????1000000000000000000000000000 : s_rdw_cnt = 6'd5;
              32'b?????100000000000000000000000000 : s_rdw_cnt = 6'd6;
              32'b??????10000000000000000000000000 : s_rdw_cnt = 6'd7;
              32'b???????1000000000000000000000000 : s_rdw_cnt = 6'd8;
              32'b????????100000000000000000000000 : s_rdw_cnt = 6'd9;
              32'b?????????10000000000000000000000 : s_rdw_cnt = 6'd10;
              32'b??????????1000000000000000000000 : s_rdw_cnt = 6'd11;
              32'b???????????100000000000000000000 : s_rdw_cnt = 6'd12;
              32'b????????????10000000000000000000 : s_rdw_cnt = 6'd13;
              32'b?????????????1000000000000000000 : s_rdw_cnt = 6'd14;
              32'b??????????????100000000000000000 : s_rdw_cnt = 6'd15;
              32'b???????????????10000000000000000 : s_rdw_cnt = 6'd16;
              32'b????????????????1000000000000000 : s_rdw_cnt = 6'd17;
              32'b?????????????????100000000000000 : s_rdw_cnt = 6'd18;
              32'b??????????????????10000000000000 : s_rdw_cnt = 6'd19;
              32'b???????????????????1000000000000 : s_rdw_cnt = 6'd20;
              32'b????????????????????100000000000 : s_rdw_cnt = 6'd21;
              32'b?????????????????????10000000000 : s_rdw_cnt = 6'd22;
              32'b??????????????????????1000000000 : s_rdw_cnt = 6'd23;
              32'b???????????????????????100000000 : s_rdw_cnt = 6'd24;
              32'b????????????????????????10000000 : s_rdw_cnt = 6'd25;
              32'b?????????????????????????1000000 : s_rdw_cnt = 6'd26;
              32'b??????????????????????????100000 : s_rdw_cnt = 6'd27;
              32'b???????????????????????????10000 : s_rdw_cnt = 6'd28;
              32'b????????????????????????????1000 : s_rdw_cnt = 6'd29;
              32'b?????????????????????????????100 : s_rdw_cnt = 6'd30;
              32'b??????????????????????????????10 : s_rdw_cnt = 6'd31;
              32'b11111111111111111111111111111111 : s_rdw_cnt = 6'd32;
              default                              : s_rdw_cnt = 6'd0;
            endcase
            s_left_shift_cnt = s_rdw_cnt[4:0];
            s_right_shift_cnt = (CC_MSTR_CPL_SEG_DATA_NUM_DWORDS - s_left_shift_cnt);
          end
        end


        // Calculate left and right shift factors
        always @(posedge core_clk or negedge core_rst_n) begin : proc_seq_shift_cnt
          if (!core_rst_n) begin
            r_left_shift_cnt  <= # TP 5'd0;
            r_right_shift_cnt <= # TP 5'd0;
          end else if (!halt) begin
            r_left_shift_cnt  <= # TP s_left_shift_cnt;
            r_right_shift_cnt <= # TP s_right_shift_cnt;
          end
        end


        assign s_left_shift_factor  = r_left_shift_cnt;
        assign s_right_shift_factor = mcctl_hv ? s_right_shift_cnt : r_right_shift_cnt;

        // Shift data and DWORD enables
        always @(*) begin : proc_comb_shift_data
          // Initialise
          s_left_shift_data    = {CC_MSTR_CPL_SEG_DATA_WD{1'b0}};
          s_left_shift_rdw_en  = {CC_MSTR_CPL_SEG_DATA_NUM_DWORDS{1'b0}};
          s_right_shift_data   = {CC_MSTR_CPL_SEG_DATA_WD{1'b0}};
          s_right_shift_rdw_en = {CC_MSTR_CPL_SEG_DATA_NUM_DWORDS{1'b0}};

          case (s_left_shift_factor)
           5'd0 : begin
             s_left_shift_data   = s_sbc_rdata;
             s_left_shift_rdw_en = s_sbc_rdw_en;
           end
           5'd1 : begin
             s_left_shift_data   = s_sbc_rdata << 1*(CC_MSTR_CPL_SEG_DATA_WD/32);
             s_left_shift_rdw_en = s_sbc_rdw_en << 1;
           end
           5'd2 : begin
             s_left_shift_data   = s_sbc_rdata << 2*(CC_MSTR_CPL_SEG_DATA_WD/32);
             s_left_shift_rdw_en = s_sbc_rdw_en << 2;
           end
           5'd3 : begin
             s_left_shift_data   = s_sbc_rdata << 3*(CC_MSTR_CPL_SEG_DATA_WD/32);
             s_left_shift_rdw_en = s_sbc_rdw_en << 3;
           end
           5'd4 : begin
             s_left_shift_data   = s_sbc_rdata << 4*(CC_MSTR_CPL_SEG_DATA_WD/32);
             s_left_shift_rdw_en = s_sbc_rdw_en << 4;
           end
           5'd5 : begin
             s_left_shift_data   = s_sbc_rdata << 5*(CC_MSTR_CPL_SEG_DATA_WD/32);
             s_left_shift_rdw_en = s_sbc_rdw_en << 5;
           end
           5'd6 : begin
             s_left_shift_data   = s_sbc_rdata << 6*(CC_MSTR_CPL_SEG_DATA_WD/32);
             s_left_shift_rdw_en = s_sbc_rdw_en << 6;
           end
           5'd7 : begin
             s_left_shift_data   = s_sbc_rdata << 7*(CC_MSTR_CPL_SEG_DATA_WD/32);
             s_left_shift_rdw_en = s_sbc_rdw_en << 7;
           end
           5'd8 : begin
             s_left_shift_data   = s_sbc_rdata << 8*(CC_MSTR_CPL_SEG_DATA_WD/32);
             s_left_shift_rdw_en = s_sbc_rdw_en << 8;
           end
           5'd9 : begin
             s_left_shift_data   = s_sbc_rdata << 9*(CC_MSTR_CPL_SEG_DATA_WD/32);
             s_left_shift_rdw_en = s_sbc_rdw_en << 9;
           end
           5'd10 : begin
             s_left_shift_data   = s_sbc_rdata << 10*(CC_MSTR_CPL_SEG_DATA_WD/32);
             s_left_shift_rdw_en = s_sbc_rdw_en << 10;
           end
           5'd11 : begin
             s_left_shift_data   = s_sbc_rdata << 11*(CC_MSTR_CPL_SEG_DATA_WD/32);
             s_left_shift_rdw_en = s_sbc_rdw_en << 11;
           end
           5'd12 : begin
             s_left_shift_data   = s_sbc_rdata << 12*(CC_MSTR_CPL_SEG_DATA_WD/32);
             s_left_shift_rdw_en = s_sbc_rdw_en << 12;
           end
           5'd13 : begin
             s_left_shift_data   = s_sbc_rdata << 13*(CC_MSTR_CPL_SEG_DATA_WD/32);
             s_left_shift_rdw_en = s_sbc_rdw_en << 13;
           end
           5'd14 : begin
             s_left_shift_data   = s_sbc_rdata << 14*(CC_MSTR_CPL_SEG_DATA_WD/32);
             s_left_shift_rdw_en = s_sbc_rdw_en << 14;
           end
           5'd15 : begin
             s_left_shift_data   = s_sbc_rdata << 15*(CC_MSTR_CPL_SEG_DATA_WD/32);
             s_left_shift_rdw_en = s_sbc_rdw_en << 15;
           end
           5'd16 : begin
             s_left_shift_data   = s_sbc_rdata << 16*(CC_MSTR_CPL_SEG_DATA_WD/32);
             s_left_shift_rdw_en = s_sbc_rdw_en << 16;
           end
           5'd17 : begin
             s_left_shift_data   = s_sbc_rdata << 17*(CC_MSTR_CPL_SEG_DATA_WD/32);
             s_left_shift_rdw_en = s_sbc_rdw_en << 17;
           end
           5'd18 : begin
             s_left_shift_data   = s_sbc_rdata << 18*(CC_MSTR_CPL_SEG_DATA_WD/32);
             s_left_shift_rdw_en = s_sbc_rdw_en << 18;
           end
           5'd19 : begin
             s_left_shift_data   = s_sbc_rdata << 19*(CC_MSTR_CPL_SEG_DATA_WD/32);
             s_left_shift_rdw_en = s_sbc_rdw_en << 19;
           end
           5'd20 : begin
             s_left_shift_data   = s_sbc_rdata << 20*(CC_MSTR_CPL_SEG_DATA_WD/32);
             s_left_shift_rdw_en = s_sbc_rdw_en << 20;
           end
           5'd21 : begin
             s_left_shift_data   = s_sbc_rdata << 21*(CC_MSTR_CPL_SEG_DATA_WD/32);
             s_left_shift_rdw_en = s_sbc_rdw_en << 21;
           end
           5'd22 : begin
             s_left_shift_data   = s_sbc_rdata << 22*(CC_MSTR_CPL_SEG_DATA_WD/32);
             s_left_shift_rdw_en = s_sbc_rdw_en << 22;
           end
           5'd23 : begin
             s_left_shift_data   = s_sbc_rdata << 23*(CC_MSTR_CPL_SEG_DATA_WD/32);
             s_left_shift_rdw_en = s_sbc_rdw_en << 23;
           end
           5'd24 : begin
             s_left_shift_data   = s_sbc_rdata << 24*(CC_MSTR_CPL_SEG_DATA_WD/32);
             s_left_shift_rdw_en = s_sbc_rdw_en << 24;
           end
           5'd25 : begin
             s_left_shift_data   = s_sbc_rdata << 25*(CC_MSTR_CPL_SEG_DATA_WD/32);
             s_left_shift_rdw_en = s_sbc_rdw_en << 25;
           end
           5'd26 : begin
             s_left_shift_data   = s_sbc_rdata << 26*(CC_MSTR_CPL_SEG_DATA_WD/32);
             s_left_shift_rdw_en = s_sbc_rdw_en << 26;
           end
           5'd27 : begin
             s_left_shift_data   = s_sbc_rdata << 27*(CC_MSTR_CPL_SEG_DATA_WD/32);
             s_left_shift_rdw_en = s_sbc_rdw_en << 27;
           end
           5'd28 : begin
             s_left_shift_data   = s_sbc_rdata << 28*(CC_MSTR_CPL_SEG_DATA_WD/32);
             s_left_shift_rdw_en = s_sbc_rdw_en << 28;
           end
           5'd29 : begin
             s_left_shift_data   = s_sbc_rdata << 29*(CC_MSTR_CPL_SEG_DATA_WD/32);
             s_left_shift_rdw_en = s_sbc_rdw_en << 29;
           end
           5'd30 : begin
             s_left_shift_data   = s_sbc_rdata << 30*(CC_MSTR_CPL_SEG_DATA_WD/32);
             s_left_shift_rdw_en = s_sbc_rdw_en << 30;
           end
           5'd31 : begin
             s_left_shift_data   = s_sbc_rdata << 31*(CC_MSTR_CPL_SEG_DATA_WD/32);
             s_left_shift_rdw_en = s_sbc_rdw_en << 31;
           end
           default : begin
             s_left_shift_data   = {CC_MSTR_CPL_SEG_DATA_WD{1'b0}};
             s_left_shift_rdw_en = {CC_MSTR_CPL_SEG_DATA_NUM_DWORDS{1'b0}};
           end
          endcase
          case (s_right_shift_factor)
           5'd0  : begin
             s_right_shift_data   = s_sbc_rdata;
             s_right_shift_rdw_en = s_sbc_rdw_en;
           end
           5'd1  : begin
             s_right_shift_data   = (s_sbc_rdata >>     CC_MSTR_CPL_SEG_DATA_WD/32)  | (DATA_RSHIFT1DW  & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >>  1;
           end
           5'd2  : begin
             s_right_shift_data   = (s_sbc_rdata >>  2*(CC_MSTR_CPL_SEG_DATA_WD/32)) | (DATA_RSHIFT2DW  & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >>  2;
           end
           5'd3  : begin
             s_right_shift_data   = (s_sbc_rdata >>  3*(CC_MSTR_CPL_SEG_DATA_WD/32)) | (DATA_RSHIFT3DW  & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >>  3;
           end
           5'd4  : begin
             s_right_shift_data   = (s_sbc_rdata >>  4*(CC_MSTR_CPL_SEG_DATA_WD/32)) | (DATA_RSHIFT4DW  & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >>  4;
           end
           5'd5  : begin
             s_right_shift_data   = (s_sbc_rdata >>  5*(CC_MSTR_CPL_SEG_DATA_WD/32)) | (DATA_RSHIFT5DW  & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >>  5;
           end
           5'd6  : begin
             s_right_shift_data   = (s_sbc_rdata >>  6*(CC_MSTR_CPL_SEG_DATA_WD/32)) | (DATA_RSHIFT6DW  & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >>  6;
           end
           5'd7  : begin
             s_right_shift_data   = (s_sbc_rdata >>  7*(CC_MSTR_CPL_SEG_DATA_WD/32)) | (DATA_RSHIFT7DW  & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >>  7;
           end
           5'd8  : begin
             s_right_shift_data   = (s_sbc_rdata >>  8*(CC_MSTR_CPL_SEG_DATA_WD/32)) | (DATA_RSHIFT8DW  & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >>  8;
           end
           5'd9  : begin
             s_right_shift_data   = (s_sbc_rdata >>  9*(CC_MSTR_CPL_SEG_DATA_WD/32)) | (DATA_RSHIFT9DW  & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >>  9;
           end
           5'd10 : begin
             s_right_shift_data   = (s_sbc_rdata >> 10*(CC_MSTR_CPL_SEG_DATA_WD/32)) | (DATA_RSHIFT10DW & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 10;
           end
           5'd11 : begin
             s_right_shift_data   = (s_sbc_rdata >> 11*(CC_MSTR_CPL_SEG_DATA_WD/32)) | (DATA_RSHIFT11DW & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 11;
           end
           5'd12 : begin
             s_right_shift_data   = (s_sbc_rdata >> 12*(CC_MSTR_CPL_SEG_DATA_WD/32)) | (DATA_RSHIFT12DW & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 12;
           end
           5'd13 : begin
             s_right_shift_data   = (s_sbc_rdata >> 13*(CC_MSTR_CPL_SEG_DATA_WD/32)) | (DATA_RSHIFT13DW & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 13;
           end
           5'd14 : begin
             s_right_shift_data   = (s_sbc_rdata >> 14*(CC_MSTR_CPL_SEG_DATA_WD/32)) | (DATA_RSHIFT14DW & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 14;
           end
           5'd15 : begin
             s_right_shift_data   = (s_sbc_rdata >> 15*(CC_MSTR_CPL_SEG_DATA_WD/32)) | (DATA_RSHIFT15DW & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 15;
           end
           5'd16  : begin
             s_right_shift_data   = (s_sbc_rdata >> 16*(CC_MSTR_CPL_SEG_DATA_WD/32)) | (DATA_RSHIFT16DW  & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 16;
           end
           5'd17  : begin
             s_right_shift_data   = (s_sbc_rdata >> 17*(CC_MSTR_CPL_SEG_DATA_WD/32)) | (DATA_RSHIFT17DW  & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 17;
           end
           5'd18 : begin
             s_right_shift_data   = (s_sbc_rdata >> 18*(CC_MSTR_CPL_SEG_DATA_WD/32)) | (DATA_RSHIFT18DW  & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 18;
           end
           5'd19 : begin
             s_right_shift_data   = (s_sbc_rdata >> 19*(CC_MSTR_CPL_SEG_DATA_WD/32)) | (DATA_RSHIFT19DW  & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 19;
           end
           5'd20 : begin
             s_right_shift_data   = (s_sbc_rdata >> 20*(CC_MSTR_CPL_SEG_DATA_WD/32)) | (DATA_RSHIFT20DW  & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 20;
           end
           5'd21 : begin
             s_right_shift_data   = (s_sbc_rdata >> 21*(CC_MSTR_CPL_SEG_DATA_WD/32)) | (DATA_RSHIFT21DW  & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 21;
           end
           5'd22 : begin
             s_right_shift_data   = (s_sbc_rdata >> 22*(CC_MSTR_CPL_SEG_DATA_WD/32)) | (DATA_RSHIFT22DW  & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 22;
           end
           5'd23 : begin
             s_right_shift_data   = (s_sbc_rdata >> 23*(CC_MSTR_CPL_SEG_DATA_WD/32)) | (DATA_RSHIFT23DW  & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 23;
           end
           5'd24 : begin
             s_right_shift_data   = (s_sbc_rdata >> 24*(CC_MSTR_CPL_SEG_DATA_WD/32)) | (DATA_RSHIFT24DW  & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 24;
           end
           5'd25 : begin
             s_right_shift_data   = (s_sbc_rdata >> 25*(CC_MSTR_CPL_SEG_DATA_WD/32)) | (DATA_RSHIFT25DW & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 25;
           end
           5'd26 : begin
             s_right_shift_data   = (s_sbc_rdata >> 26*(CC_MSTR_CPL_SEG_DATA_WD/32)) | (DATA_RSHIFT26DW & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 26;
           end
           5'd27 : begin
             s_right_shift_data   = (s_sbc_rdata >> 27*(CC_MSTR_CPL_SEG_DATA_WD/32)) | (DATA_RSHIFT27DW & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 27;
           end
           5'd28 : begin
             s_right_shift_data   = (s_sbc_rdata >> 28*(CC_MSTR_CPL_SEG_DATA_WD/32)) | (DATA_RSHIFT28DW & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 28;
           end
           5'd29 : begin
             s_right_shift_data   = (s_sbc_rdata >> 29*(CC_MSTR_CPL_SEG_DATA_WD/32)) | (DATA_RSHIFT29DW & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 29;
           end
           5'd30 : begin
             s_right_shift_data   = (s_sbc_rdata >> 30*(CC_MSTR_CPL_SEG_DATA_WD/32)) | (DATA_RSHIFT30DW & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 30;
           end
           5'd31 : begin
             s_right_shift_data   = (s_sbc_rdata >> 31*(CC_MSTR_CPL_SEG_DATA_WD/32)) | (DATA_RSHIFT31DW & {CC_MSTR_CPL_SEG_DATA_WD{mcctl_eot}});
             s_right_shift_rdw_en = s_sbc_rdw_en >> 31;
           end
           default : begin
             s_right_shift_data   = {CC_MSTR_CPL_SEG_DATA_WD{1'b0}};
             s_right_shift_rdw_en = {CC_MSTR_CPL_SEG_DATA_NUM_DWORDS{1'b0}};
           end
           endcase
          end
        end
      default : begin : GEN_NUM_DWORDS_DEFAULT
        always @(*) begin : proc_comb_default
          s_rdw_cnt            = {CC_MSTR_CPL_SEG_DATA_SIZE_ENC{1'b0}};
          s_right_shift_cnt    = {CC_MSTR_CPL_SEG_DATA_SIZE_ENC-2{1'b0}};
          r_left_shift_cnt     = {CC_MSTR_CPL_SEG_DATA_SIZE_ENC-2{1'b0}};
          r_right_shift_cnt    = {CC_MSTR_CPL_SEG_DATA_SIZE_ENC-2{1'b0}};
          s_left_shift_data    = {CC_MSTR_CPL_SEG_DATA_WD{1'b0}};
          s_left_shift_rdw_en  = {CC_MSTR_CPL_SEG_DATA_NUM_DWORDS{1'b0}};
          s_right_shift_data   = {CC_MSTR_CPL_SEG_DATA_WD{1'b0}};
          s_right_shift_rdw_en = {CC_MSTR_CPL_SEG_DATA_NUM_DWORDS{1'b0}};
        end
      end
    endcase
  endgenerate
  // -------------------------------------------------------------------------------------
  // Combine left and right shift data to give a continous burst of DWORD's
  // -------------------------------------------------------------------------------------
  // Register right shift data
  always @(posedge core_clk or negedge core_rst_n) begin : proc_seq_right_shift
    if (!core_rst_n) begin
      r_right_shift_data    <= # TP {CC_MSTR_CPL_SEG_DATA_WD{1'b0}};
      r_right_shift_rdw_en  <= # TP {CC_MSTR_CPL_SEG_DATA_NUM_DWORDS{1'b0}};
    end else if (!halt) begin
      r_right_shift_data    <= # TP s_right_shift_data;
      r_right_shift_rdw_en  <= # TP s_right_shift_rdw_en;
    end
  end

  // OR right and left shift data
  assign s_right_left_shift_data   =
         ({CC_MSTR_CPL_SEG_DATA_WD{s_left_shift_data_valid}} & s_left_shift_data) |
         r_right_shift_data;

  assign s_right_left_shift_rdw_en =
         ({CC_MSTR_CPL_SEG_DATA_NUM_DWORDS{s_left_shift_data_valid}} & s_left_shift_rdw_en) |
         r_right_shift_rdw_en;

  // Select shifted data and DWORD enables
  always @(*) begin : proc_comb_algnd_data
    // Initialise
    s_algnd_data    = BUS_INIT;
    s_algnd_rdw_en  = {CC_MSTR_CPL_SEG_DATA_NUM_DWORDS{1'b0}};

    if (s_dv_algnd) begin
      if (r_dw_shift_data_sel) begin
        s_algnd_data   = s_right_left_shift_data;
        s_algnd_rdw_en = s_right_left_shift_rdw_en;
      end else begin
        s_algnd_data   = r_right_shift_data;
        s_algnd_rdw_en = r_right_shift_rdw_en;
      end
    end
  end

  // -------------------------------------------------------------------------------------
  // Assign outputs
  // -------------------------------------------------------------------------------------
  assign dwa_dv       = s_dv_algnd & |s_algnd_rdw_en;
  assign dwa_hdr_info = r_hdr_info;
  assign dwa_eot      = s_eot_algnd;
  assign dwa_bad_eot  = s_bad_eot_algnd;
  assign dwa_data     = s_algnd_data;
  assign dwa_rdw_en   = s_algnd_rdw_en;

  assign dwa_halt     = halt;

  // -------------------------------------------------------------------------------------
  // Enumerate FSM states
  // -------------------------------------------------------------------------------------
   `ifndef SYNTHESIS
   wire [16*8:1] ALGN_FSM;
   assign ALGN_FSM = (r_algn_state == ST_IDLE)      ?  "IDLE       " :
                     (r_algn_state == ST_DLY_DATA)  ?  "DLY_DATA   " :
                     (r_algn_state == ST_ALGN_DATA) ?  "ALGN_DATA  " :
                     (r_algn_state == ST_DLY_EOT)   ?  "DLY_EOT    " :
                      "UNDEF";
   `endif // SYNTHESIS

endmodule
