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
// ---    $DateTime: 2023/04/29 12:35:01 $ 
// ---    $Revision: #6 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_nullBRespInjection.sv#6 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_wack_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_nullInjection_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_nullBRespInjection
  import DWC_pcie_tlp_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter   P_MAXTAGS = 1024
  ,parameter    P_NUM_CH = 9
  ,parameter P_NUM_CH_WD = 3
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_aclks_if.slave_mp         b_clk
  ,DWC_pcie_edmapf_wack_if.master_mp         b_dst
  ,DWC_pcie_edmapf_nullInjection_if.slave_mp b_nullHandler
  ,DWC_pcie_edmapf_wack_if.slave_mp          b_src
  );

  // ##########################################################################
  //                              Local parameters                             
  // ##########################################################################

  localparam LP_MAXTAGS_WD = $clog2(P_MAXTAGS)                          ;


// SNPS_SysML_CODE_START
  /*
    Signals used to the scheduler
  */
  enum logic {
   E_NULL   = 1'b0
  ,E_BYPASS = 1'b1
  } s_scheduler;
  
  /*
    Structure to inject the nulls
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_b_dst_PROC
    if (!b_clk.w_reset_n) begin
      b_dst.w_valid   <= #`TP '0;
      b_dst.w_channel <= #`TP '0;
      b_dst.w_tag     <= #`TP '0;
      b_dst.w_error   <= #`TP '0;
    end else if(!b_dst.w_halt) begin
      case(s_scheduler)
        E_BYPASS: begin
          b_dst.w_valid   <= #`TP b_src.w_valid  ;
          b_dst.w_channel <= #`TP b_src.w_channel;
          b_dst.w_tag     <= #`TP b_src.w_tag    ;
          b_dst.w_error   <= #`TP b_src.w_error  ;
        end
        E_NULL: begin
          b_dst.w_valid   <= #`TP (s_scheduler == E_NULL)              ;
          b_dst.w_channel <= #`TP (K_DMACHANWD)'(b_nullHandler.w_chInj);
          b_dst.w_tag     <= #`TP b_nullHandler.w_tagInj               ;
          b_dst.w_error   <= #`TP '0                                   ;
        end
      endcase
    end
  end : s_b_dst_PROC
  
  /*
    Scheduling the correct source
  */
  always_comb begin : c_scheduler_PROC
    if (!b_dst.w_halt && b_nullHandler.w_validInj && !b_dst.w_valid) begin
      if(b_src.w_valid && ((K_DMACHANWD)'(b_src.w_channel) == (K_DMACHANWD)'(b_nullHandler.w_chInj))) begin
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
    b_nullHandler.w_validRcvd   = b_src.w_valid && !b_dst.w_halt ;
    b_nullHandler.w_chRcvd      = (P_NUM_CH_WD)'(b_src.w_channel);
    b_nullHandler.w_tagRcvd     = b_src.w_tag                    ;
  end : c_trafficMonitor_PROC
  
  /*
    Sending the ack
  */
  always_comb begin : c_ackInjection_PROC
    b_nullHandler.w_ackInj = s_scheduler == E_NULL;
  end : c_ackInjection_PROC
  
// SNPS_SysML_CODE_END

endmodule
