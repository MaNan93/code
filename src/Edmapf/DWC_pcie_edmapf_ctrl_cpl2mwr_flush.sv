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
// ---    $Revision: #7 $ 
// ---    $Author: dnolan $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_cpl2mwr_flush.sv#7 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_cpl2mwr_flush
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  import DWC_pcie_tlp_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter                 P_CHAN = 8
  ,parameter dmaEngType_e P_CHANNEL = E_WRITE
  ,parameter     RAS_DP_PROT_CHK_ID = 0
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_aclks_if.slave_mp  b_clk
  ,DWC_pcie_edmapf_tlp_if.slave_mp    b_in
  ,DWC_pcie_edmapf_tlp_if.master_mp   b_out
  ,DWC_pcie_edmapf_rasdp_if.master_mp b_ras
  );


// SNPS_SysML_CODE_START
  
  localparam L_CHANWD = (P_CHAN == 1) ? 1 : $clog2(P_CHAN);

  typedef enum logic [1:0] {
    E_TLP_FEED
   ,E_TLP_FLUSH
   ,E_TLP_NULL
  } tlpAction_e;

  logic   [P_CHAN-1:0]        r_flushBit  ;
  logic   [P_CHAN-1:0]        s_flushBit  ;

  logic [L_CHANWD-1:0]        s_channel   ;
  logic                       s_isNull    ;
  logic                       s_isToken   ;
  logic                       s_isCplErr  ;

  tlpAction_e                 r_tlpAction ;
  tlpAction_e                 s_tlpAction ;

  logic [3:0]                 s_first_be;
  logic [3:0]                 s_last_be;  
  logic [3:0]                 r_last_be;
  logic [31:0]                s_first_be_mask;
  logic [31:0]                s_last_be_mask;
  logic [K_COREBUSPROTWD-1:0] s_data_prot;

  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : r_flushBit_PROC
    if (!b_clk.w_reset_n) begin
      r_flushBit <= #`TP '0;
    end else begin
      r_flushBit <= #`TP s_flushBit;
    end
  end

  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : r_tlpAction_PROC
    if (!b_clk.w_reset_n) begin
      r_tlpAction <= #`TP E_TLP_FEED;
    end else begin
      r_tlpAction <= #`TP s_tlpAction;
    end
  end

  assign s_channel = b_in.w_header.ctx.channel             ;
  assign s_isNull  = b_in.w_header.header ==? K_NULLHEADER ;
  assign s_isToken = b_in.w_header.ctx.ctx.ovrl.token      ;

  //generate
  //  if (P_CHANNEL == E_READ) begin
  //    assign s_isCplErr = |b_in.w_header.ctx.ctx.ovrl.errors.rdErr            ;
  //  end else begin
  //    assign s_isCplErr = b_in.w_header.ctx.ctx.ovrl.errors.commonErr.app_err ;
  //  end
  //endgenerate
  assign s_isCplErr = b_in.w_header.ctx.ctx.ovrl.errors inside {E_DMAERR_DATA_CPL_UR, E_DMAERR_DATA_CPL_CA, E_DMAERR_DATA_CPL_TIMEOUT, E_DMAERR_DATA_CPL_EP};

  always_comb begin : s_flushBit_PROC
    foreach (s_flushBit[i]) begin
      if (b_in.w_hv && !b_in.w_halt && (s_channel == i)) begin
        if (!r_flushBit[i] && s_isCplErr && !s_isNull) begin
          s_flushBit[i] = 1'b1;
        end else if (r_flushBit[i] && s_isToken && s_isNull) begin
          s_flushBit[i] = 1'b0;
        end else begin
          s_flushBit[i] = r_flushBit[i];
        end
      end else begin
        s_flushBit[i] = r_flushBit[i];
      end
    end
  end

  always_comb begin : s_tlpAction_PROC
    if (b_in.w_hv) begin
      if (r_flushBit[s_channel] && !s_isToken) begin
        s_tlpAction = E_TLP_FLUSH;
      end else if (!r_flushBit[s_channel] && s_isCplErr && !s_isNull) begin
        s_tlpAction = E_TLP_NULL;
      end else begin
        s_tlpAction = E_TLP_FEED;
      end
    end else if (!b_in.w_dv) begin
      s_tlpAction = E_TLP_FEED;
    end else begin
      s_tlpAction = r_tlpAction;
    end
  end

  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : r_last_be_PROC
    if (!b_clk.w_reset_n) begin
      r_last_be <= #`TP '0;
    end else if (b_in.w_hv && !b_in.w_halt) begin
      r_last_be <= #`TP b_in.w_header.header.common2.last_be;
    end
  end  
  
  assign s_first_be      = b_in.w_header.header.common2.first_be;
  assign s_last_be       = b_in.w_hv ? b_in.w_header.header.common2.last_be : r_last_be;  
  assign s_first_be_mask = { {8{s_first_be[3]}}, {8{s_first_be[2]}}, {8{s_first_be[1]}}, {8{s_first_be[0]}} };  
  assign s_last_be_mask  = { {8{s_last_be[3]}}, {8{s_last_be[2]}}, {8{s_last_be[1]}}, {8{s_last_be[0]}} };

  always_comb begin : b_out_PROC
    case (s_tlpAction)
      E_TLP_FLUSH: begin
        b_out.w_hv                             = '0               ;
        b_out.w_dv                             = '0               ;
        b_out.w_eot                            = '0               ;
        b_out.w_data                           = '0               ;
        b_out.w_header                         = '0               ;
        b_out.w_headerProt                     = '0               ;
      end
      E_TLP_NULL: begin
        b_out.w_hv                             = b_in.w_hv        ;
        b_out.w_dv                             = b_in.w_hv        ; // This is not a typo, dv must be set for null mwr/cpl
        b_out.w_eot                            = b_in.w_hv        ; // Single cycle TLP
        b_out.w_data                           = b_in.w_data      ;
        b_out.w_data[31:0]                         = '0           ;
        b_out.w_data[K_COREBUSWD_WO_PROT-1:K_COREBUSWD_WO_PROT-32] = '0;
        b_out.w_data[K_COREBUSWD-1        :K_COREBUSWD_WO_PROT]    = s_data_prot;
        b_out.w_header                         = b_in.w_header    ;
        b_out.w_header.header.common2.first_be = '0               ;
        b_out.w_header.header.common2.last_be  = '0               ;
        b_out.w_header.header.common2.dw_len   = 10'b00_0000_0001 ;
        b_out.w_headerProt                     = b_in.w_headerProt;
      end
      default: begin // E_TLP_FEED
        b_out.w_hv                             = b_in.w_hv        ;
        b_out.w_dv                             = b_in.w_dv        ;
        b_out.w_eot                            = b_in.w_eot       ;
        b_out.w_data                           = b_in.w_data      ;
        if (b_in.w_hv && !b_in.w_halt) begin
          b_out.w_data[31:0]                   = b_in.w_data[31:0] & s_first_be_mask;
        end
        if (b_in.w_eot && !b_in.w_halt) begin 
          b_out.w_data[K_COREBUSWD_WO_PROT-1:K_COREBUSWD_WO_PROT-32] = b_in.w_data[K_COREBUSWD_WO_PROT-1:K_COREBUSWD_WO_PROT-32] & s_last_be_mask;
        end 
        b_out.w_data[K_COREBUSWD-1:K_COREBUSWD_WO_PROT] = s_data_prot;
        b_out.w_header                         = b_in.w_header    ;
        b_out.w_headerProt                     = b_in.w_headerProt;
      end
    endcase
  end

  always_comb begin : b_in_PROC
    case (s_tlpAction)
      E_TLP_FLUSH: begin
        b_in.w_halt = '0;
      end
      E_TLP_NULL: begin
        b_in.w_halt = b_out.w_halt && b_in.w_hv;
      end
      default: begin // E_TLP_FEED
        b_in.w_halt = b_out.w_halt;
      end
    endcase
  end
  
      
      // DATA Parity Checker
      ras_dp_pipe
       #(
        .PIPELINE_TYPE             (0                             ),
        .RESETVAL                  (0                             ),
        .N_STAGES                  (0                             ),
        .CAN_STALL                 (0                             ),
        .RESET_STALL               (0                             ),
        .BUS_PROTECT_GEN_EN        (0                             ),
        .BUS_PROTECT_CHK_EN        (1                             ),
        .PROT_TYPE                 (1                             ), //0: ECC, 1: Parity
        .PROT_RANGE                (K_RAS_PROT_RANGE              ),
        .PROT_WD                   (K_COREBUSPROTWD               ),
        .PARITY_MODE               (K_RAS_PARITY_MODE             ),
        .PROT_CORRECT_EN           (0                             ),
        .TOTAL_WIDTH               (K_COREBUSWD_WO_PROT           ),
        .EXCLUDE_PROT_WIDTH        (0                             ),
        .RAS_DP_PROT_CHK_ID_BASE   (RAS_DP_PROT_CHK_ID            )
      ) u_chk_flush_in_data (
        .clk                       ( b_clk.w_aux_clk                                )
       ,.rst_n                     ( b_clk.w_reset_n                                )
       ,.din                       ( b_in.w_data[K_COREBUSWD_WO_PROT-1:0]           )
       ,.din_prot                  ( b_in.w_data[K_COREBUSWD-1:K_COREBUSWD_WO_PROT] )
       ,.dout                      ( /* Not Connected */                            )
       ,.dout_prot                 ( /* Not Connected */                            )
       ,.en                        ( 1'b1                                           )
       ,.bypass                    ( 1'b0                                           )
       ,.stall                     ( 1'b0                                           )
       ,.stallout                  ( /* Not Connected */                            )
       ,.valid_in                  ( b_in.w_dv                                      )
       ,.halt_out                  ( /* Not Connected */                            )
       ,.valid_out                 ( /* Not Connected */                            )
       ,.halt_in                   ( 1'b0                                           )
       ,.ras_dp_err_inband_kbd_in  ( 1'b0                                           )
       ,.ras_dp_err_inband_kbd_out ( /* Not Connected */                            )
       ,.ras_dp_err_log            ( b_ras.w_ras_dp_err_log                         )
         ,.ras_dp_err_inj          ( b_ras.w_ras_dp_err_inj                         ) 
       );
      
      // DATA Parity Generator
      ras_dp_pipe
       #(
        .PIPELINE_TYPE             (0                             ),
        .RESETVAL                  (0                             ),
        .N_STAGES                  (0                             ),
        .CAN_STALL                 (0                             ),
        .RESET_STALL               (0                             ),
        .BUS_PROTECT_GEN_EN        (1                             ),
        .BUS_PROTECT_CHK_EN        (0                             ),
        .PROT_TYPE                 (1                             ), //0: ECC, 1: Parity
        .PROT_RANGE                (K_RAS_PROT_RANGE              ),
        .PROT_WD                   (K_COREBUSPROTWD               ),
        .PARITY_MODE               (K_RAS_PARITY_MODE             ),
        .PROT_CORRECT_EN           (0                             ),
        .TOTAL_WIDTH               (K_COREBUSWD_WO_PROT           ),
        .EXCLUDE_PROT_WIDTH        (0                             ),
        .RAS_DP_PROT_CHK_ID_BASE   (/* not connected */           )
      ) u_gen_flush_out_data (
        .clk                       ( b_clk.w_aux_clk                       )
       ,.rst_n                     ( b_clk.w_reset_n                       )
       ,.din                       ( b_out.w_data[K_COREBUSWD_WO_PROT-1:0] )
       ,.din_prot                  ( {K_COREBUSPROTWD{1'b0}}               )
       ,.dout                      ( /* not connected */                   )
       ,.dout_prot                 ( s_data_prot                           )
       ,.en                        (1'b1                                   )
       ,.bypass                    (1'b0                                   )
       ,.stall                     (1'b0                                   )
       ,.stallout                  ( /* not connected */                   )
       ,.valid_in                  ( b_out.w_dv                            )
       ,.halt_out                  ( /* not connected */                   )
       ,.valid_out                 ( /* not connected */                   )
       ,.halt_in                   (1'b0                                   )
       ,.ras_dp_err_inband_kbd_in  (1'b0                                   )
       ,.ras_dp_err_inband_kbd_out ( /* not connected */                   )
       ,.ras_dp_err_log            ( /* not connected */                   )
       ,.ras_dp_err_inj            ( '0                                    )
        );
      
      


// SNPS_SysML_CODE_END

endmodule
