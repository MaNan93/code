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
// ---    $DateTime: 2021/10/29 02:04:56 $ 
// ---    $Revision: #5 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_nullFilter.sv#5 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_nullInjection_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_nullFilter
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
   DWC_pcie_edmapf_aclks_if.slave_mp          b_clk
  ,DWC_pcie_edmapf_tlp_if.master_mp           b_dst
  ,DWC_pcie_edmapf_nullInjection_if.master_mp b_nullHandler
  ,DWC_pcie_edmapf_tlp_if.slave_mp            b_src
  );

  // ##########################################################################
  //                              Local parameters                             
  // ##########################################################################

  localparam LP_MAXTAGS_WD = $clog2(P_MAXTAGS)                          ;


// SNPS_SysML_CODE_START
  typedef struct packed {
    logic [LP_MAXTAGS_WD-1:0] tag;
    logic   [P_NUM_CH_WD-1:0] channel;
  } data_st;
  /*
    LUTs used to store the tags of both the latest valid transaction and null sent by each channel
  */
  logic [P_NUM_CH-1:0] [LP_MAXTAGS_WD-1:0] r_lastTag;
  logic [P_NUM_CH-1:0] [LP_MAXTAGS_WD-1:0] r_nullTag;
  /*
    LUTs used to indicate if the tag is valid or not
  */
  logic                     [P_NUM_CH-1:0] r_validLastTag;
  logic                     [P_NUM_CH-1:0] r_validNullTag;
  /*
    Indication which channels will be granted
  */
  logic                     [P_NUM_CH-1:0] s_chGranted;
  /*
    Null detection
  */
  logic                                    s_nullDetection;
  /*
    Channel selected to inject the Null
  */
  logic                  [P_NUM_CH_WD-1:0] s_chIndexSelected;
  /*
    Signals used to schedule the channels
  */
  data_st [P_NUM_CH-1:0]                   s_dataIn;
  data_st                                  s_dataOut;

  /*
    Connecting the interfaces
  */
  always_comb begin : c_connectingInterfaces_PROC
    b_dst.w_hv         = b_src.w_hv && !s_nullDetection;
    b_dst.w_header     = b_src.w_header;
    b_dst.w_headerProt = b_src.w_headerProt;
    b_dst.w_dv         = b_src.w_dv && !s_nullDetection;
    b_dst.w_data       = b_src.w_data;
    b_dst.w_eot        = b_src.w_eot && !s_nullDetection;
    b_src.w_halt       = b_dst.w_halt;
  end : c_connectingInterfaces_PROC
  
  /*
    Detecting if a null is being transmitted
  */
  always_comb begin : c_nullDetection_PROC
    s_nullDetection = b_src.w_header.common2.first_be == '0;
  end : c_nullDetection_PROC
  
  /*
    Storing the tag in the correct LUT
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_storingTag_PROC
    if (!b_clk.w_reset_n) begin
      r_lastTag <= #`TP '0;
      r_nullTag <= #`TP '0;
    end else if (b_src.w_hv && !b_dst.w_halt) begin
      if(s_nullDetection) begin
        r_nullTag[b_src.w_header.dma.channel[P_NUM_CH_WD-1:0]] <= #`TP b_src.w_header.tag;
      end else begin
        r_lastTag[b_src.w_header.dma.channel[P_NUM_CH_WD-1:0]] <= #`TP b_src.w_header.tag;
      end
    end
  end : s_storingTag_PROC
  
  /*
    Handling outbound transactions
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_outboundTransactions_PROC
    if (!b_clk.w_reset_n) begin
      r_validLastTag <= #`TP '0;
    end else begin
      case({b_nullHandler.w_validRcvd, (b_src.w_hv && !b_dst.w_halt)})
        2'b01: begin
          if(b_src.w_header.common2.first_be != '0) begin
            r_validLastTag[b_src.w_header.dma.channel[P_NUM_CH_WD-1:0]]   <= #`TP '1;
          end
        end
        2'b10: begin
          if(r_lastTag[b_nullHandler.w_chRcvd] == b_nullHandler.w_tagRcvd) begin
            r_validLastTag[b_nullHandler.w_chRcvd]       <= #`TP '0;
          end
        end
        2'b11: begin
          if((K_DMACHANWD)'(b_src.w_header.dma.channel) == (K_DMACHANWD)'(b_nullHandler.w_chRcvd)) begin
            if(b_src.w_header.common2.first_be != '0) begin
              r_validLastTag[b_src.w_header.dma.channel[P_NUM_CH_WD-1:0]] <= #`TP '1;
            end else if(r_lastTag[b_nullHandler.w_chRcvd] == b_nullHandler.w_tagRcvd) begin
              r_validLastTag[b_nullHandler.w_chRcvd]     <= #`TP '0;
            end
          end else begin
            if(b_src.w_header.common2.first_be != '0) begin
              r_validLastTag[b_src.w_header.dma.channel[P_NUM_CH_WD-1:0]] <= #`TP '1;
            end
            if(r_lastTag[b_nullHandler.w_chRcvd] == b_nullHandler.w_tagRcvd) begin
              r_validLastTag[b_nullHandler.w_chRcvd]     <= #`TP '0;
            end
          end
        end
      endcase
    end
  end : s_outboundTransactions_PROC
  
  /*
    Handling null transactions
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_nullTransactions_PROC
    if (!b_clk.w_reset_n) begin
      r_validNullTag <= #`TP '0;
    end else begin
      for (int i=0;i<P_NUM_CH;i++) begin
        if(b_src.w_hv && !b_dst.w_halt && (b_src.w_header.common2.first_be == '0) && ((K_DMACHANWD)'(i) == b_src.w_header.dma.channel)) begin
          r_validNullTag[i] <= #`TP '1;
        end else begin
          r_validNullTag[i] <= #`TP r_validNullTag[i] && !s_chGranted[i];
        end
      end
    end
  end : s_nullTransactions_PROC
  
  /*
    Preparing data to be injected into scheduler
  */
  always_comb begin : c_dataInjectedIntoScheduler_PROC
    foreach(s_dataIn[i]) begin
      s_dataIn[i].tag     = r_nullTag[i];
      s_dataIn[i].channel = (P_NUM_CH_WD)'(i);
    end
  end : c_dataInjectedIntoScheduler_PROC
  
  /*
  Roud-Robin arbitrer to decide which null will be injected next
  */
  DWC_pcie_staged_arbiter
   #(
     .P_INPUTS   (P_NUM_CH)
    ,.P_STAGES   (3       )
    ,.P_DATATYPE (data_st )
  ) u_rr_arb_nullInj (
     .i_clk     (b_clk.w_main_clk                  )
    ,.i_rst_n   (b_clk.w_reset_n                   )
    ,.i_clr_n   (1'b1                              )
    ,.i_en      (1'b1                              )
    ,.i_ready   (b_nullHandler.w_ackInj            )
    ,.i_request ((~r_validLastTag) & r_validNullTag)
    ,.i_data    (s_dataIn                          )
    ,.o_grant   (s_chGranted                       )
    ,.o_valid   (b_nullHandler.w_validInj          )
    ,.o_data    (s_dataOut                         )
    );

  /*
    Sending the channel of the null to the module which will inject the null transaction
  */
  always_comb begin : c_injectingNullCh_PROC
    b_nullHandler.w_chInj  = s_dataOut.channel;
  end : c_injectingNullCh_PROC

  /*
    Sending the tag of the null to the module which will inject the null transaction
  */
  always_comb begin : c_injectingNullTag_PROC
    b_nullHandler.w_tagInj = s_dataOut.tag;
  end : c_injectingNullTag_PROC

// SNPS_SysML_CODE_END

endmodule
