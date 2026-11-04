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
// ---    $Revision: #5 $ 
// ---    $Author: dnolan $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_nullCplInjection.sv#5 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_nullInjection_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_nullCplInjection
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter   P_MAXTAGS = 1024
  ,parameter    P_NUM_CH = 8
  ,parameter P_NUM_CH_WD = 3
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_aclks_if.slave_mp         b_clk
  ,DWC_pcie_edmapf_tlp_if.master_mp          b_dst
  ,DWC_pcie_edmapf_nullInjection_if.slave_mp b_nullHandler
  ,DWC_pcie_edmapf_tlp_if.slave_mp           b_src
  );

  // ##########################################################################
  //                              Local parameters                             
  // ##########################################################################

  localparam LP_MAXTAGS_WD = $clog2(P_MAXTAGS)                          ;


// SNPS_SysML_CODE_START

  localparam L_HEADERPROTWD = (($bits(xradm_s)-1)/K_RAS_PROT_RANGE+1);

  /*
    Signals used to the scheduler
  */
  enum logic {
   E_NULL   = 1'b0
  ,E_BYPASS = 1'b1
  } s_scheduler;

  xradm_s s_header;
  xradm_s s_headerOut;
  logic [L_HEADERPROTWD-1:0] s_headerProt;

  // Generator
  ras_dp_pipe
   #(
    .PIPELINE_TYPE              (0                             ), // 0: delay_n
    .RESETVAL                   (0                             ),
    .N_STAGES                   (0                             ),
    .CAN_STALL                  (0                             ),
    .RESET_STALL                (0                             ),
    .BUS_PROTECT_GEN_EN         (1                             ), // 1: Bus Protection Generator is present
    .BUS_PROTECT_CHK_EN         (0                             ), // 0: Bus Protection Checker is not present (ECC/Parity)
    .PROT_TYPE                  (1                             ), // 0=Ecc, 1=Simple Parity
    .PROT_RANGE                 (K_RAS_PROT_RANGE              ), // Number of bits to calculate parity/ECC on
    .PROT_WD                    (L_HEADERPROTWD                ), // Selects the width of the din_prot/dout_prot signals
    .PARITY_MODE                (K_RAS_PARITY_MODE             ), // selects the type of parity: 0=Even, 1=Odd
    .PROT_CORRECT_EN            (/* NC */                      ), // 0: no correction on single-errors, 1: correction on single-errors
    .TOTAL_WIDTH                ($bits(xradm_s)                ), 
    .EXCLUDE_PROT_WIDTH         (0                             ),
    .RAS_DP_PROT_CHK_ID_BASE    (/* NC */                      ), // Associates the Bus Protection Checker with a unique identifier
    .ADDR_ECC_PROT_EN           (/* NC */                      ),
    .ADDR_LOG_EN                (/* NC */                      ),
    .ADDR_INDEX                 (/* NC */                      ),
    .ADDR_WD                    (/* NC */                      )
  ) u_ras_gen (
     .clk                       ( b_clk.w_main_clk             )
    ,.rst_n                     ( b_clk.w_reset_n              )
    ,.din                       ( s_header                     )
    ,.din_prot                  ( {L_HEADERPROTWD{1'b0}}       )
    ,.dout                      ( s_headerOut                  )
    ,.dout_prot                 ( s_headerProt                 )
    ,.en                        ( 1'b1                         )
    ,.bypass                    ( 1'b0                         )
    ,.stall                     ( 1'b0                         )
    ,.stallout                  ( /* Not Connected */          )
    ,.valid_in                  ( 1'b1                         )
    ,.halt_out                  ( /* Not Connected */          )
    ,.valid_out                 ( /* Not Connected */          )
    ,.halt_in                   ( 1'b0                         )
    ,.ras_dp_err_inband_kbd_in  ( 1'b0                         )
    ,.ras_dp_err_inband_kbd_out ( /* Not Connected */          )
    ,.ras_dp_err_log            ( /* Not Connected */          )
      ,.ras_dp_err_inj          ( '0                           )
  );
  

  assign s_header = '{default: '0
                     ,tag : b_nullHandler.w_tagInj
                     ,dma : '{channel : (K_DMACHANWD)'(b_nullHandler.w_chInj), req : E_DMA_BYPASS}
                     ,common2 : '{default : '0, dw_len : 'd1} 
                     };

  /*
    Structure to inject the nulls
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_b_dst_PROC
    if (!b_clk.w_reset_n) begin
      b_dst.w_hv     <= #`TP '0;
      b_dst.w_header <= #`TP '0;
      b_dst.w_dv     <= #`TP '0;
      b_dst.w_data   <= #`TP '0;
      b_dst.w_eot    <= #`TP '0;
      b_dst.w_headerProt <= #`TP '0;
    end else if(!b_dst.w_halt) begin
      case(s_scheduler)
        E_BYPASS: begin
          b_dst.w_hv     <= #`TP b_src.w_hv    ;
          b_dst.w_header <= #`TP b_src.w_header;
          b_dst.w_dv     <= #`TP b_src.w_dv    ;
          b_dst.w_data   <= #`TP b_src.w_data  ;
          b_dst.w_eot    <= #`TP b_src.w_eot   ;
          b_dst.w_headerProt <= #`TP b_src.w_headerProt;
        end
        E_NULL: begin
          b_dst.w_hv     <= #`TP (s_scheduler == E_NULL);
          b_dst.w_dv     <= #`TP (s_scheduler == E_NULL);
          b_dst.w_data[K_COREBUSWD_WO_PROT-1:0]           <= #`TP '0;
          b_dst.w_data[K_COREBUSWD-1:K_COREBUSWD_WO_PROT] <= #`TP (K_RAS_PARITY_MODE ? '1 : '0);
          b_dst.w_eot    <= #`TP (s_scheduler == E_NULL);
          b_dst.w_headerProt <= #`TP s_headerProt;
          b_dst.w_header <= #`TP s_headerOut;
        end
      endcase
    end
  end : s_b_dst_PROC
  
  /*
    Scheduling the correct source
  */
  always_comb begin : c_scheduler_PROC
    if (!b_dst.w_halt && b_nullHandler.w_validInj && ((b_dst.w_dv && b_dst.w_eot) || (!b_dst.w_dv))) begin
      if(b_src.w_hv && ((K_DMACHANWD)'(b_src.w_header.dma.channel) == (K_DMACHANWD)'(b_nullHandler.w_chInj))) begin
        s_scheduler = E_BYPASS;
      end else begin
        s_scheduler = E_NULL;
      end
    end else begin
      s_scheduler = E_BYPASS;
    end
  end : c_scheduler_PROC
  
  /*
    Connecting the interfaces
  */
  always_comb begin : c_feedThroughHalt_PROC
    b_src.w_halt   = b_dst.w_halt || (s_scheduler == E_NULL);
  end : c_feedThroughHalt_PROC
  
  /*
    Monitor for inbound traffic
  */
  always_comb begin : c_trafficMonitor_PROC
    b_nullHandler.w_validRcvd   = b_src.w_hv && !b_dst.w_halt               ;
    b_nullHandler.w_chRcvd      = (P_NUM_CH_WD)'(b_src.w_header.dma.channel);
    b_nullHandler.w_tagRcvd     = b_src.w_header.tag                        ;
  end : c_trafficMonitor_PROC
  
  /*
    Sending the ack
  */
  always_comb begin : c_ackInjection_PROC
    b_nullHandler.w_ackInj = s_scheduler == E_NULL;
  end : c_ackInjection_PROC
  
// SNPS_SysML_CODE_END

endmodule
