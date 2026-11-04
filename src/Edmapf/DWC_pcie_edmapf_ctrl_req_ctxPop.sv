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
// ---    $Revision: #2 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_req_ctxPop.sv#2 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_llq_pop_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_req_push_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_req_ctxPop
  import DWC_pcie_edmapf_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter       type P_OVRL_TYPE = elemCtxWr_s
  ,parameter             CX_DMA_LLQ = `CX_DMA_WR_LLQ
  ,parameter        CX_NUM_DMA_CHAN = 16
  ,parameter dmaEngType_e P_CHANNEL = E_WRITE
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_aclks_if.slave_mp     b_clk
  ,DWC_pcie_edmapf_llq_pop_if.slave_mp   b_pop
  ,DWC_pcie_edmapf_req_push_if.master_mp b_push
  );


// SNPS_SysML_CODE_START
  localparam LP_LLQ_RAM_DP          = CX_NUM_DMA_CHAN*CX_DMA_LLQ;
  localparam LP_LLQ_RAM_DP_WD       = (LP_LLQ_RAM_DP == 1) ? 1 : $clog2(LP_LLQ_RAM_DP);
  localparam CC_NUM_DMA_CHAN_WIDTH  = (CX_NUM_DMA_CHAN==1) ? 1 : $clog2(CX_NUM_DMA_CHAN);
  localparam L_STAGES               = P_CHANNEL == E_WRITE ? K_DMA_WR_RR_STAGES  : K_DMA_RD_RR_STAGES;
  localparam LP_INTERNAL_LATENCY    = P_CHANNEL == E_WRITE ? K_DMA_WR_LLQ_REQ_LAT  : K_DMA_RD_LLQ_REQ_LAT;
  localparam LP_INTERNAL_LATENCY_WD = $clog2(LP_INTERNAL_LATENCY);
  localparam LP_LINKED_LISTS        = P_CHANNEL == E_WRITE ? K_DMA_WR_LL_REQ_STAGES  : K_DMA_RD_LL_REQ_STAGES;
  localparam L_STAGES_LL            = 2;
  /*
    Slots available counter
  */
  logic                             [LP_INTERNAL_LATENCY_WD:0] r_fetchesAvailable;
  logic                             [LP_INTERNAL_LATENCY_WD:0] s_restoringSlots;
  logic                                  [LP_LINKED_LISTS-1:0] s_llFlushing;
  logic                                  [CX_NUM_DMA_CHAN-1:0] s_dropingCtx;
  /*
    Signals for fetching scheduler
  */
  logic                                                        r_granted;
  logic                            [CC_NUM_DMA_CHAN_WIDTH-1:0] r_chGranted;
  logic                                  [CX_NUM_DMA_CHAN-1:0] s_chAvailable;
  logic                                  [CX_NUM_DMA_CHAN-1:0] s_chRequesting;
  logic                                  [CX_NUM_DMA_CHAN-1:0] s_chGranted;
  logic                                  [CX_NUM_DMA_CHAN-1:0] s_chPending;
  logic                                  [CX_NUM_DMA_CHAN-1:0] s_chPriority;
  logic       [CX_NUM_DMA_CHAN-1:0] [LP_INTERNAL_LATENCY_WD:0] r_chFetchedCnt;
  logic       [CX_NUM_DMA_CHAN-1:0] [LP_INTERNAL_LATENCY_WD:0] s_chFetchedCnt;
  logic       [CX_NUM_DMA_CHAN-1:0] [LP_INTERNAL_LATENCY_WD:0] r_fetchesOutstanding;
  logic                                  [CX_NUM_DMA_CHAN-1:0] s_chFetched;
  logic      [CX_NUM_DMA_CHAN-1:0] [CC_NUM_DMA_CHAN_WIDTH-1:0] s_dataIn;
  logic                                  [CX_NUM_DMA_CHAN-1:0] s_filterFetching_n;
  /*
    Signals to control the fetching counter
  */
  logic                                  [CX_NUM_DMA_CHAN-1:0] s_OpFetchReady;
  logic                                                        s_fetchingCtx;
  logic                                                        s_restrict;
  logic                                                        s_fetchingValid;
  logic                                                        s_slotErased;
  logic                                                        s_poisonedData;
  /*
    Signal indicates which channels has context already stored
  */
  logic                                  [CX_NUM_DMA_CHAN-1:0] s_channelWorking;
  logic       [CX_NUM_DMA_CHAN-1:0] [LP_INTERNAL_LATENCY_WD:0] r_channelCtxStored;
  /*
    Identify which channel has an error
  */
  logic                                  [CX_NUM_DMA_CHAN-1:0] s_error;
  /*
    Signal to indicate that a context was received correctly
  */
  logic                                                        s_rightContextReceived;
  
  /*
  Roud-Robin arbitrer to decide which channel should be fetched
  */
  DWC_pcie_staged_arbiter
  
   #(
     .P_INPUTS   (CX_NUM_DMA_CHAN                  )
    ,.P_STAGES   (L_STAGES                         )
    ,.P_DATATYPE (logic [CC_NUM_DMA_CHAN_WIDTH-1:0])
   ) u_rr_arb_chFetch (
      .i_clk     (b_clk.w_main_clk)
     ,.i_rst_n   (b_clk.w_reset_n )
     ,.i_clr_n   (1'b1            )
     ,.i_en      (1'b1            )
     ,.i_ready   (s_restrict      )
     ,.i_request (s_chRequesting  )
     ,.i_data    (s_dataIn        )
     ,.o_grant   (s_chGranted     )
     ,.o_valid   (r_granted       )
     ,.o_data    (r_chGranted     )
   );
  
  /*
   Stop fetching during flush process
  */
  always_comb begin : c_s_filterFetching_n_PROC
    foreach(s_filterFetching_n[i]) begin
      s_filterFetching_n[i] = !(s_error[i] && s_channelWorking[i]);
    end
  end : c_s_filterFetching_n_PROC
  
  /*
    Defining which channels have conditions to be prefetched
  */
  always_comb begin : c_chRequesting_PROC
    s_chRequesting = ((|s_chPending) ? s_chPending : ((|s_chPriority) ? s_chPriority : s_chAvailable)) & s_filterFetching_n;
  end : c_chRequesting_PROC

  /*
    Infering channels that are not in requester or requested already
  */
  always_comb begin : c_chPending_PROC
    s_chPending = ~s_channelWorking & ~s_chFetched & s_chAvailable;
  end : c_chPending_PROC
    
  /*
    Indicating which channel was already fetched
  */
  always_comb begin : c_chFetchedBit_PROC
    foreach(s_chFetched[i]) begin
      s_chFetched[i] = (r_fetchesOutstanding[i] != '0) || (r_chFetchedCnt[i] != '0);
    end
  end : c_chFetchedBit_PROC
  
  /*
    Infering channels that are not in requester
  */
  always_comb begin : c_chPriority_PROC
    s_chPriority = ~s_channelWorking & s_chAvailable;
  end : c_chPriority_PROC
  
  /*
    Finding Channel with contexts available to fetch
  */
  always_comb begin : c_s_chAvailable_PROC
    foreach(s_chAvailable[i]) begin
      s_chAvailable[i] = b_pop.w_slotsWithData[i] > ((LP_LLQ_RAM_DP_WD+1)'(r_chFetchedCnt[i]));
      //s_chAvailable[i] = |b_pop.w_slotsWithData[i];
    end
  end : c_s_chAvailable_PROC
  
  /*
    Storing the couter of fetches per channel
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_chFetchedCnt_PROC
    if (!b_clk.w_reset_n) begin
      r_chFetchedCnt <= #`TP '0;
    end else begin
      r_chFetchedCnt <= #`TP s_chFetchedCnt;
    end
  end : s_chFetchedCnt_PROC
  
  /*
    Counting the number of fetches per channels
  */
  always_comb begin : c_chFetchedCnt_PROC
    foreach(s_chFetchedCnt[i]) begin
      case({(s_slotErased && (b_push.w_OpEraseCh == CC_NUM_DMA_CHAN_WIDTH'(i))), (s_poisonedData && (b_pop.w_fetchDoneCh == CC_NUM_DMA_CHAN_WIDTH'(i))), s_chGranted[i]})
        3'b001:
          s_chFetchedCnt[i] = r_chFetchedCnt[i] + 'd1 - s_dropingCtx[i];
        3'b010,
        3'b100,
        3'b111:
          s_chFetchedCnt[i] = r_chFetchedCnt[i] - 'd1 - s_dropingCtx[i];
        3'b110:
          s_chFetchedCnt[i] = r_chFetchedCnt[i] - 'd2 - s_dropingCtx[i];
        default:
          s_chFetchedCnt[i] = r_chFetchedCnt[i] - s_dropingCtx[i];
      endcase
    end
  end : c_chFetchedCnt_PROC
  
  /*
    Counting number of contexts per channel stored
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_channelCtxStored_PROC
    if (!b_clk.w_reset_n) begin
      r_channelCtxStored <= #`TP '0;
    end else begin
      foreach(r_channelCtxStored[i]) begin
        case({s_slotErased && (b_push.w_OpEraseCh == CC_NUM_DMA_CHAN_WIDTH'(i)), b_push.w_push && (b_push.w_reqCh == CC_NUM_DMA_CHAN_WIDTH'(i))})
          2'b01:
            begin
              r_channelCtxStored[i] <= #`TP r_channelCtxStored[i] + 'd1;
            end
          2'b10:
            begin
              r_channelCtxStored[i] <= #`TP r_channelCtxStored[i] - 'd1;
            end
        endcase
      end
    end
  end : s_channelCtxStored_PROC
  
  /*
    Counting the number fo slots flushed
  */
  always_comb begin : c_s_restoringSlots_PROC
    s_restoringSlots = '0;
    foreach(s_llFlushing[i]) begin
      if(s_llFlushing[i]) begin
        s_restoringSlots = s_restoringSlots + 'd1;
      end
    end
  end : c_s_restoringSlots_PROC
  
  /*
    Counting the number of fetches generated to not fetch more than slots available
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_fetchesAvailable_PROC
    if (!b_clk.w_reset_n) begin
      r_fetchesAvailable <= #`TP LP_INTERNAL_LATENCY;
    end else begin
      case({s_poisonedData, s_slotErased, s_fetchingValid})
        3'b001:
          begin
            r_fetchesAvailable <= #`TP (LP_INTERNAL_LATENCY_WD+1)'(r_fetchesAvailable - 'd1 + s_restoringSlots);
          end
        3'b010:
          begin
            r_fetchesAvailable <= #`TP (LP_INTERNAL_LATENCY_WD+1)'(r_fetchesAvailable + 'd1 + s_restoringSlots);
          end
        3'b100:
          begin
            r_fetchesAvailable <= #`TP (LP_INTERNAL_LATENCY_WD+1)'(r_fetchesAvailable + 'd1 + s_restoringSlots);
          end
        3'b110:
          begin
            r_fetchesAvailable <= #`TP (LP_INTERNAL_LATENCY_WD+1)'(r_fetchesAvailable + 'd2 + s_restoringSlots);
          end
        3'b111:
          begin
            r_fetchesAvailable <= #`TP (LP_INTERNAL_LATENCY_WD+1)'(r_fetchesAvailable + 'd1 + s_restoringSlots);
          end
        default:
          begin
            r_fetchesAvailable <= #`TP (LP_INTERNAL_LATENCY_WD+1)'(r_fetchesAvailable + s_restoringSlots);
          end
      endcase
    end
  end : s_fetchesAvailable_PROC
  
  /*
    Restrict fetching based on ready and if linked lists are available
  */
  always_comb begin : c_restrictFetch_PROC
    s_restrict = (r_fetchesAvailable != '0) && s_OpFetchReady[b_pop.w_OpFetchCh] && (!b_push.w_llFull | s_channelWorking[b_pop.w_OpFetchCh]) && s_filterFetching_n[b_pop.w_OpFetchCh];
  end : c_restrictFetch_PROC
  
  /*
    Generating the control signals to start fetching
  */
  always_comb begin : c_fetchingCtx_PROC
    s_fetchingCtx  = r_granted && s_restrict;
  end : c_fetchingCtx_PROC
  
  /*
    Generating the control signals for fetching counter
  */
  always_comb begin : c_fetchingCntCtrlSignals_PROC
    s_fetchingValid = b_pop.w_OpFetch && s_OpFetchReady[b_pop.w_OpFetchCh];
    s_slotErased    = b_push.w_OpErase;
    s_poisonedData  = b_pop.w_fetchDone  && (b_pop.w_fetchPoisoned || (s_error[b_pop.w_fetchDoneCh] && !(b_pop.w_FetchCtxElem.ovrl.token)));
  end : c_fetchingCntCtrlSignals_PROC
  
  /*
     Preparing data to be injected into scheduler
  */
  always_comb begin : c_dataIn_PROC
    foreach(s_dataIn[i]) begin
      s_dataIn[i] = CC_NUM_DMA_CHAN_WIDTH'(i);
    end
  end : c_dataIn_PROC
 
  /*
    Fetching the channel scheduled
  */
  always_comb begin : c_channelFetch_PROC
    b_pop.w_OpFetchCh = r_chGranted;
    b_pop.w_OpFetch   = s_fetchingCtx;
  end : c_channelFetch_PROC
  
  /*
    Creating an internal image of fetch ready
  */
  always_comb begin : c_OpFetchReady_PROC
    s_OpFetchReady = b_pop.w_OpFetchReady;
  end : c_OpFetchReady_PROC
  
  /*
    Counting outstanding fetches
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_fetchesOutstanding_PROC
    if (!b_clk.w_reset_n) begin
      r_fetchesOutstanding <= #`TP '0;
    end else begin
      foreach(r_fetchesOutstanding[i]) begin
        case({(b_pop.w_fetchDone && (b_pop.w_fetchDoneCh == CC_NUM_DMA_CHAN_WIDTH'(i))), (b_pop.w_OpFetch && (b_pop.w_OpFetchCh == CC_NUM_DMA_CHAN_WIDTH'(i)) && s_OpFetchReady[b_pop.w_OpFetchCh])})
          2'b01:
            r_fetchesOutstanding[i] <= #`TP r_fetchesOutstanding[i] + 'd1;
          2'b10:
            r_fetchesOutstanding[i] <= #`TP r_fetchesOutstanding[i] - 'd1;
        endcase
      end
    end
  end : s_fetchesOutstanding_PROC
  
  
  /*
    Creating internal copies
  */
  always_comb begin : c_s_error_PROC
    s_error          = b_pop.w_error;
    s_channelWorking = b_push.w_channelWorking;
    s_llFlushing     = b_push.w_flusingLL;
    s_dropingCtx     = b_push.w_dropingCtx;
  end : c_s_error_PROC
  
  /*
    Driving the feedback signals to fetchQ
  */
  always_comb begin : c_fetchQueueFeedbackSignals_PROC
    //b_pop.w_OpErase       = b_push.w_OpErase  && (!s_error[b_push.w_OpEraseCh] || (s_error[b_push.w_OpEraseCh] && (b_push.w_channelToken)));
    //b_pop.w_OpEraseCh     = b_push.w_OpEraseCh;
    b_pop.w_OpErase       = b_pop.w_fetchDone && !b_pop.w_fetchPoisoned && (!s_error[b_pop.w_fetchDoneCh] || (s_error[b_pop.w_fetchDoneCh] && (b_pop.w_FetchCtxElem.ovrl.token)));
    b_pop.w_OpEraseCh     = b_pop.w_fetchDoneCh;
    b_pop.w_rollback      = '0;
    b_pop.w_rollbackCh    = '0;
    b_pop.w_OpUpdate      = '0;
    b_pop.w_OpUpdateCh    = '0;
    b_pop.w_UpdateCtxElem = '0;
  end : c_fetchQueueFeedbackSignals_PROC
  
  /*
    Setting data to the latency manager
  */
  always_comb begin : c_setPushInterface_PROC
    b_push.w_push           = b_pop.w_fetchDone && !b_pop.w_fetchPoisoned && (!s_error[b_pop.w_fetchDoneCh] || (s_error[b_pop.w_fetchDoneCh] && (b_pop.w_FetchCtxElem.ovrl.token)));
    b_push.w_reqCh          = b_pop.w_fetchDoneCh;
    b_push.w_ctxElem        = b_pop.w_FetchCtxElem;
    b_push.w_flush          = b_pop.w_error;
  end : c_setPushInterface_PROC
  
      

// SNPS_SysML_CODE_END

endmodule
