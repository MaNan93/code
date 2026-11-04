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
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/scramble3_parity.sv#8 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// -- This module calculates the even parity of the 128-bit Data Payloads in a
// -- given lane of all Data Blocks since the last SKP Ordered Set or SDS 
// -- Ordered Set.
// -- If CALC_PARITY_BEFORE_SCRAMBLE == 0, the scrambler output data is used for
// -- the parity calculation.
// -- This allows the parity of transmitted scrambled data to be calculated.
// -- If CALC_PARITY_BEFORE_SCRAMBLE == 1, the scrambler input  data is used for
// -- the parity calculation.
// -- This allows the parity of recevied scrambled data to be calculated.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module scramble3_parity
  #(parameter INST  = 0,
    parameter TP    = `TP,
    parameter NB    = `CX_NB,
    parameter SB_WD = `CX_MAC_SB_WD,
    parameter SH_WD = `CX_MAC_SH_WD,
    parameter AW    = `CX_ANB_WD
   )
  (
  input                  core_clk,
  input                  core_rst_n,
  input      [SB_WD-1:0] scramble_startblock,
  input                  scramble_data_dv,
  input                  scramble_aligned,
  input      [SB_WD-1:0] scramble_current_parity,
  input     [(NB*8)-1:0] scramble_data_out,
  input [SB_WD-1:0][4:0] scramble_data_osfound_out,
  input      [SB_WD-1:0] scramble_inskp,
  input      [SB_WD-1:0] scramble_insds,
  input                  scramble_en,
  input         [AW-1:0] active_nb_gen34,
  input            [2:0] current_data_rate,
  input                  ltssm_in_rcvryspeed,
  input      [SH_WD-1:0] scramble_int_syncheader,
  input      [SB_WD-1:0] scramble_int_eios,
  input                  txelecidle,
  input                  smlh_flit_mode_enable,
  output     [SB_WD-1:0] scramble_ctlskp_end_sym_o,
  output reg [SB_WD-1:0] scramble_even_parity
  );

  wire  [SB_WD-1:0]      current_data_parity;
  wire  [SB_WD-1:0]      int_scramble_inskp_end;
  wire  [SB_WD-1:0]      scramble_inskp_end;

  wire  [SB_WD-1:0]      scramble_ctlskp_end_sym;
  wire  [SB_WD-1:0]      ctlskp_end_sym;
  wire  [SB_WD-1:0]      int_scramble_inctlskp_end;
  reg   [SB_WD-1:0]      scramble_ctlskp_end_latch;
  reg   [SH_WD-1:0]      scramble_syncheader_latch;
  reg                    scramble_eios_latch;
  reg   [1:0]            scramble_eios_latch_d;
  wire  [SB_WD-1:0]      gen6_ctlskp_end_sym;
  wire                   pre_gen6_ctlskp_end_sym;
  wire                   gen3_mode;
  wire                   gen45_mode;
  wire                   gen6_mode;
  wire                   stdskp_mode;
  wire                   ctlskp_mode;

  // Set current mode
  wire gen3_flit_mode = (current_data_rate == `GEN3_RATE) && smlh_flit_mode_enable;
  assign gen3_mode      = current_data_rate == `GEN3_RATE && ~smlh_flit_mode_enable;
  assign gen45_mode     = current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE;
  assign gen6_mode      = current_data_rate == `GEN6_RATE;
  assign stdskp_mode    = gen3_mode;
  assign ctlskp_mode    = gen45_mode || gen6_mode || gen3_flit_mode;

  // Set current parity
  assign current_data_parity = scramble_current_parity;

  //to mark SKP OS end
  assign int_scramble_inskp_end[0] = scramble_inskp[0] && scramble_startblock[0];

  // Even Data Parity is initialized based on the following rules.
  // Gen3:
  //   - A SDS Ordered Set is transmitted/received.
  //   - After a standard SKP Ordered Set is transmitted/received.
  // Gen4/Gen5:
  //   - A LTSSM is in Recovery.Speed.
  //   - A SDS Ordered Set is transmitted/received.
  //   - After a Control SKP Ordered Set is transmitted/received.
  //   - After a standard SKP Ordered Set is NOT transmitted/received.

  assign ctlskp_end_sym[0] =
                    (active_nb_gen34[2]) ? (scramble_data_out[ 7: 0]==`SKP_END_CTL_SYM) : // 4s
                    (active_nb_gen34[3]) ? (scramble_data_out[39:32]==`SKP_END_CTL_SYM) : // 8s
                      1'b0;

// for SKP-OS format in gen6, 
// Symbol number   Value
// (0,2,4,6)x N    F0h
// (1,3,5,7)x N    0Fh
// 24-27,28-31     F000_F0FFh  (SYP_END pattern)
// 32-39           See PHY Payload

  wire                   pre_gen6_ctlskp_end_4s;
  reg                    pre_gen6_ctlskp_end_4s_d;
  reg                    gen6_ctlskp_end_sym_d;
  reg                    gen6_ctlskp_end_sym_latch;
  assign pre_gen6_ctlskp_end_4s   = 1'b0;
  assign pre_gen6_ctlskp_end_sym  = scramble_data_dv && scramble_inskp[0] && (scramble_data_out[63:0]=={2{`GEN6_32B_SKP_SYM_END}});
 
  always @(posedge core_clk or negedge core_rst_n) begin
    if ( !core_rst_n ) begin
        gen6_ctlskp_end_sym_latch <= #TP 1'b0;
        pre_gen6_ctlskp_end_4s_d  <= #TP 1'b0;
    end else begin
        if( current_data_rate == `GEN6_RATE) begin
            if(~scramble_data_dv) begin
                gen6_ctlskp_end_sym_latch <= #TP gen6_ctlskp_end_sym_latch;
                pre_gen6_ctlskp_end_4s_d  <= #TP pre_gen6_ctlskp_end_4s_d;
            end else if(|scramble_inskp) begin
                gen6_ctlskp_end_sym_latch <= #TP pre_gen6_ctlskp_end_sym || gen6_ctlskp_end_sym_latch;
                pre_gen6_ctlskp_end_4s_d  <= #TP pre_gen6_ctlskp_end_4s;
            end else begin
                gen6_ctlskp_end_sym_latch <= #TP 1'b0;
                pre_gen6_ctlskp_end_4s_d  <= #TP 1'b0;
            end
        end else begin
            gen6_ctlskp_end_sym_latch <= #TP 1'b0;
            pre_gen6_ctlskp_end_4s_d  <= #TP 1'b0;
        end
    end
  end

  assign gen6_ctlskp_end_sym[0] = scramble_data_dv && scramble_inskp[0] && gen6_ctlskp_end_sym_latch;

  assign scramble_ctlskp_end_sym[0] = (ctlskp_end_sym[0] && scramble_data_dv && scramble_inskp[0] && (gen45_mode || gen3_flit_mode))
                                              ||  (gen6_ctlskp_end_sym[0] && gen6_mode)
                                                                         ;


  // latched flag for invalid cycle or 2s
  always @(posedge core_clk or negedge core_rst_n)
  begin : data_ctlskp_latch_proc
      if (!core_rst_n) begin
          scramble_ctlskp_end_latch <= #TP {SB_WD{1'b0}};
      end else begin
          if(scramble_startblock[0]) begin
            scramble_ctlskp_end_latch <= #TP {SB_WD{1'b0}};
          end
          else if(|scramble_ctlskp_end_sym) begin
            scramble_ctlskp_end_latch <= #TP scramble_ctlskp_end_sym;
          end
          else begin
            scramble_ctlskp_end_latch <= #TP scramble_ctlskp_end_latch;
          end
      end
  end

  // latched syncheader
  always @(posedge core_clk or negedge core_rst_n)
  begin : scramble_syncheader_latch_proc
      if (!core_rst_n) begin
          scramble_syncheader_latch <= #TP {SB_WD{`SYNC_OS_BLOCK}};
          scramble_eios_latch       <= #TP 1'b0;
      end else begin
          if(~ctlskp_mode) begin //gen1/2 or gen3_nonflit
            scramble_syncheader_latch <= #TP {SB_WD{`SYNC_OS_BLOCK}};
            scramble_eios_latch       <= #TP 1'b0;
          end else if ( ltssm_in_rcvryspeed ) begin
            scramble_syncheader_latch <= #TP {SB_WD{`SYNC_OS_BLOCK}};
          end else begin
            if(|scramble_startblock) begin
              scramble_syncheader_latch <= #TP scramble_int_syncheader;
              scramble_eios_latch       <= #TP |scramble_int_eios;
            end
            else begin
              scramble_syncheader_latch <= #TP scramble_syncheader_latch;
              scramble_eios_latch       <= #TP scramble_eios_latch;
            end
          end
      end
  end

// Delay scramble_eios_latch signal
  always @(posedge core_clk or negedge core_rst_n)
  begin : scramble_syncheader_latch_d_proc
      if (!core_rst_n) begin
          scramble_eios_latch_d <= #TP 0;
      end else begin
          scramble_eios_latch_d <= #TP {scramble_eios_latch_d[0], scramble_eios_latch};
      end
  end

  assign int_scramble_inctlskp_end[0] = scramble_startblock[0] && (scramble_ctlskp_end_sym[0] || scramble_ctlskp_end_latch[0]);
  assign scramble_inskp_end = (ctlskp_mode) ? int_scramble_inctlskp_end : int_scramble_inskp_end;

  // Accummulate Even Parity of the Payload of Data Blocks
  // Parity value is reset at the end of a SDS or SKP OS.
  // Parity value is held during SKP OS or !scramble_data_dv.
  // Otherwise, parity of current data is EXORed with accummulated parity
  // value.
  always @(posedge core_clk or negedge core_rst_n)
  begin : scramble_even_parity_proc
      if (!core_rst_n)
            scramble_even_parity    <= #TP 1'b0;
      else begin
        if(ctlskp_mode && ltssm_in_rcvryspeed)
            scramble_even_parity    <= #TP 1'b0;
        else if(ctlskp_mode && (scramble_eios_latch || txelecidle || |scramble_eios_latch_d))
            scramble_even_parity    <= #TP scramble_even_parity;
        else
        if(~scramble_en)
            scramble_even_parity    <= #TP scramble_even_parity;
        else if (scramble_insds[0] || scramble_inskp_end[0] || !scramble_aligned)
            scramble_even_parity    <= #TP 1'b0;
        else if (scramble_inskp[0] || !scramble_data_dv)
            scramble_even_parity[0]    <= #TP scramble_even_parity;
        else if(ctlskp_mode && scramble_syncheader_latch==`SYNC_OS_BLOCK)
            scramble_even_parity    <= #TP scramble_even_parity;
        else
            scramble_even_parity    <= #TP scramble_even_parity ^ current_data_parity[0];
      end
  end
  assign scramble_ctlskp_end_sym_o = scramble_ctlskp_end_sym;

endmodule // scramble3_parity
