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
// ---    $Revision: #3 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_req_latencyManager.sv#3 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_req_dataSerializer_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_req_push_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_genericData_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_req_latencyManager
  import DWC_pcie_edmapf_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter       type P_CTX_TYPE  = fullCtxWr_s
  ,parameter       type P_DATA_TYPE = dmaWrEngCtx_s
  ,parameter      type P_OVRL_TYPE  = elemCtxWr_s
  ,parameter        CX_NUM_DMA_CHAN = 16
  ,parameter dmaEngType_e P_CHANNEL = E_WRITE
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_req_dataSerializer_if.slave_mp b_cacheAccess
  ,DWC_pcie_edmapf_genericData_if.slave_mp        b_channelRunning
  ,DWC_pcie_edmapf_aclks_if.slave_mp              b_clk
  ,DWC_pcie_edmapf_req_push_if.slave_mp           b_push
  ,DWC_pcie_edmapf_genericData_if.slave_mp        b_swStop
  );


// SNPS_SysML_CODE_START
  localparam CC_NUM_DMA_CHAN_WIDTH  = (CX_NUM_DMA_CHAN==1) ? 1 : $clog2(CX_NUM_DMA_CHAN);
  localparam LP_INTERNAL_LATENCY    = P_CHANNEL == E_WRITE ? K_DMA_WR_LLQ_REQ_LAT  : K_DMA_RD_LLQ_REQ_LAT;
  localparam LP_INTERNAL_LATENCY_WD = $clog2(LP_INTERNAL_LATENCY);
  localparam LP_LINKED_LISTS        = P_CHANNEL == E_WRITE ? K_DMA_WR_LL_REQ_STAGES  : K_DMA_RD_LL_REQ_STAGES;
  localparam LP_LINKED_LISTS_WD     = (LP_LINKED_LISTS == 1 ) ? 1 : $clog2(LP_LINKED_LISTS);
   /*
    Structure to handle with linked list
  */
  typedef struct packed {
    logic                              empty;
    logic [LP_INTERNAL_LATENCY_WD-1:0] head;
    logic [LP_INTERNAL_LATENCY_WD-1:0] tail;
  } linkedList_st;

  struct packed {
    linkedList_st [LP_LINKED_LISTS-1:0] root;
  } r_llMngr;
  
  /*
    Slots management
  */
  logic                              [LP_INTERNAL_LATENCY-1:0] r_slotsStatus;
  logic                              [LP_INTERNAL_LATENCY-1:0] s_slotRestored;
  logic                              [LP_INTERNAL_LATENCY-1:0] s_slotAccepted;
  logic                           [LP_INTERNAL_LATENCY_WD-1:0] s_slotToUse;
  /*
    Signals used to sort the linked lists
  */
  logic [LP_INTERNAL_LATENCY-1:0] [LP_INTERNAL_LATENCY_WD-1:0] r_sortedUpwards;
  logic [LP_INTERNAL_LATENCY-1:0] [LP_INTERNAL_LATENCY_WD-1:0] s_initialIndexes;
  /*
    Memory used to lead with latency
  */
  P_CTX_TYPE                         [LP_INTERNAL_LATENCY-1:0] r_memShared;
  /*
    Signal indicates which channels has context already stored
  */
  logic                                  [CX_NUM_DMA_CHAN-1:0] w_channelWorking;
  /*
    Signal to connect with b_cache interface
  */
  P_DATA_TYPE                            [LP_LINKED_LISTS-1:0] w_dataToSerialize;
  logic                                  [LP_LINKED_LISTS-1:0] w_dataAccepted;
  logic                                  [LP_LINKED_LISTS-1:0] w_locked;
  logic                                  [LP_LINKED_LISTS-1:0] w_linkedListValid;
  /*
    Storing singal to connect with external interfaces
  */
  logic                            [CC_NUM_DMA_CHAN_WIDTH-1:0] r_channelErased;
  logic                                                        r_channelErasedValid;
  logic                                                        r_channelToken;
  /*
    Stop flushing process
  */
  logic                                  [CX_NUM_DMA_CHAN-1:0] r_swStop;
  logic                                  [LP_LINKED_LISTS-1:0] s_stopLL;
  logic                                  [CX_NUM_DMA_CHAN-1:0] r_dropReq;
  logic                                  [LP_LINKED_LISTS-1:0] s_dropLLReq;
  /*
    Signals used to flush requester
  */
  logic                                  [CX_NUM_DMA_CHAN-1:0] s_flush;
  logic                                  [CX_NUM_DMA_CHAN-1:0] r_flush;
  logic                                  [CX_NUM_DMA_CHAN-1:0] s_flushDetection;
  logic                                  [LP_LINKED_LISTS-1:0] s_erasingLL;
  logic                                  [LP_LINKED_LISTS-1:0] r_flusingLL;
  logic                                  [LP_LINKED_LISTS-1:0] s_erasingSlots;
  logic                                  [CX_NUM_DMA_CHAN-1:0] s_dropingCtx;
  /*
    Signals indicates which linked list correspond to the channel comming
  */
  logic                               [LP_LINKED_LISTS_WD-1:0] s_llOfChannel;
  /*
    Mapping linked lists in channels
  */
  logic      [LP_LINKED_LISTS-1:0] [CC_NUM_DMA_CHAN_WIDTH-1:0] r_llChMap;
  /*
    Number of contexts per linked list
  */
  logic       [LP_LINKED_LISTS-1:0] [LP_INTERNAL_LATENCY_WD:0] r_dataAvailable;
  
  /*
    Finding if any linked list is assigned to the channel that is comming
  */
  generate
  if(CX_NUM_DMA_CHAN <= LP_INTERNAL_LATENCY) begin : linkedListEqualChannel_GEN
    always_comb begin : c_llOfChannelConnection_PROC
      s_llOfChannel = b_push.w_reqCh;
    end : c_llOfChannelConnection_PROC
  end else begin : linkedListChannelMap_GEN
    always_comb begin : c_llOfChannelMap_PROC
      s_llOfChannel = '0;
      if (b_push.w_push && w_channelWorking[b_push.w_reqCh]) begin
        foreach(r_llChMap[i]) begin
          if(r_llChMap[i] == b_push.w_reqCh) begin
            s_llOfChannel = (LP_INTERNAL_LATENCY_WD)'(i);
          end
        end
      end else begin
        foreach(r_llMngr.root[i]) begin
          if(r_llMngr.root[i].empty &&  !w_locked[i]) begin
            s_llOfChannel = (LP_INTERNAL_LATENCY_WD)'(i);
          end
        end
      end
    end : c_llOfChannelMap_PROC
  end
  endgenerate
  
  /*
    Mapping channel to the slots
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_slotChMap_PROC
    if (!b_clk.w_reset_n) begin
      r_llChMap <= #`TP '0;
    end else begin
      if(b_push.w_push) begin
        if(!w_channelWorking[b_push.w_reqCh]) begin
          r_llChMap[s_llOfChannel] <= #`TP b_push.w_reqCh;
        end
      end
    end
  end : s_slotChMap_PROC
  
  /*
    Indicates a SW Stop request
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_r_swStop_PROC
    if (!b_clk.w_reset_n) begin
      r_swStop <= #`TP '0;
    end else begin
      foreach(r_swStop[i])
        if(b_channelRunning.w_data[i]) begin
          if(b_swStop.w_data[i]) begin
            r_swStop [i]<= #`TP '1;
          end
        end else begin
          r_swStop [i]<= #`TP '0;
        end
    end
  end : s_r_swStop_PROC
  
  /*
    Identify which linked-list will stop
  */
  always_comb begin : c_s_stopLL_PROC
    s_stopLL = '0;
    foreach(s_stopLL[i]) begin
      if(w_channelWorking[r_llChMap[i]] && r_swStop[r_llChMap[i]]/* && !r_llMngr.root[i].empty*/) begin
        s_stopLL[i] = '1;
      end
    end
  end : c_s_stopLL_PROC
  
  /*
    Dropping requests until flush complete
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_r_dropReq_PROC
    if (!b_clk.w_reset_n) begin
      r_dropReq <= #`TP '0;
    end else begin
      foreach(r_swStop[i])
        if(b_channelRunning.w_data[i]) begin
          if(b_push.w_push && (b_push.w_reqCh == (CC_NUM_DMA_CHAN_WIDTH)'(i)) && b_push.w_ctxElem.ovrl.token && (b_push.w_ctxElem.ovrl.stop || |(b_push.w_ctxElem.ovrl.errors))) begin
            r_dropReq[i]<= #`TP '0;
          end else if(b_cacheAccess.w_sentFlag && b_cacheAccess.w_channel == CC_NUM_DMA_CHAN_WIDTH'(i)) begin
            r_dropReq[i]<= #`TP '1;
          end
        end else begin
          r_dropReq[i]<= #`TP '0;
        end
    end
  end : s_r_dropReq_PROC
  
  /*
    Identify which linked-list will drop requests
  */
  always_comb begin : c_s_dropLLReq_PROC
    s_dropLLReq = '0;
    foreach(s_dropLLReq[i]) begin
      if(w_channelWorking[r_llChMap[i]] && r_dropReq[r_llChMap[i]]/* && !r_llMngr.root[i].empty*/) begin
        s_dropLLReq[i] = '1;
      end
    end
  end : c_s_dropLLReq_PROC
  
  /*
    Creting an internal copy of the interface data
  */
  always_comb begin : c_copyInterfaceData_PROC
    s_flush        = b_push.w_flush;
    w_dataAccepted = b_cacheAccess.w_accepted;
    w_locked       = b_cacheAccess.w_locked;
  end : c_copyInterfaceData_PROC
  
  /*
    Creating a delayed version of s_flush
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_r_flush_PROC
    if (!b_clk.w_reset_n) begin
      r_flush <= #`TP '0;
    end else begin
      r_flush <= #`TP s_flush;
    end
  end : s_r_flush_PROC
  
  /*
    Detecting a flush operation
  */
  always_comb begin : c_s_flushDetection_PROC
    foreach(s_flushDetection[i]) begin
      s_flushDetection[i] = s_flush[i] && !r_flush[i];
    end
  end : c_s_flushDetection_PROC
  
  /*
    Identify which linked-list will be erased
  */
  always_comb begin : c_s_erasingLL_PROC
    s_erasingLL = '0;
    foreach(s_erasingLL[i]) begin
      if(w_channelWorking[r_llChMap[i]] && (s_flushDetection[r_llChMap[i]] || (b_cacheAccess.w_sentFlag && b_cacheAccess.w_llErased == LP_LINKED_LISTS_WD'(i)))/* && !r_llMngr.root[i].empty*/) begin
        s_erasingLL[i] = '1;
      end
    end
  end : c_s_erasingLL_PROC
  
  /*
    Flusing in progress
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_r_flusingLL_PROC
    if (!b_clk.w_reset_n) begin
      r_flusingLL <= #`TP '0;
    end else begin
      foreach(r_flusingLL[i]) begin
        case({(s_erasingLL[i] || s_dropLLReq[i]) && |r_dataAvailable[i], r_dataAvailable[i] == '0})
          2'b01:
            begin
              r_flusingLL[i] <= #`TP '0;
            end
          2'b10:
            begin
              r_flusingLL[i] <= #`TP '1;
            end
        endcase
      end
    end
  end : s_r_flusingLL_PROC
  
  /*
    Storing the incoming context
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_memShared_PROC
    if (!b_clk.w_reset_n) begin
      r_memShared <= #`TP '0;
    end else begin
      foreach(r_memShared[i]) begin
        if(b_push.w_push && (s_slotToUse == (LP_INTERNAL_LATENCY_WD)'(i))) begin
          r_memShared[i] <= #`TP b_push.w_ctxElem;
        end
      end
    end
  end : s_memShared_PROC
  
  /*
    Setting Data to the Serializer
  */
  always_comb begin : c_preparingData_PROC
    foreach(w_dataToSerialize[i]) begin
      w_dataToSerialize[i]  = '{default : '0
                               ,ctx : r_memShared[r_llMngr.root[i].head]
                               ,channel : r_llChMap[i]
                               };
    end
  end : c_preparingData_PROC
  
  /*
    Number of descriptors per linked list
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_dataAvailable_PROC
    if (!b_clk.w_reset_n) begin
      r_dataAvailable <= #`TP '0;
    end else begin
      foreach(r_dataAvailable[i]) begin
        case({(w_dataAccepted[i] | r_flusingLL[i]) && |r_dataAvailable[i], b_push.w_push && (s_llOfChannel == (LP_LINKED_LISTS_WD)'(i))})
          2'b01:
            r_dataAvailable[i] <= #`TP r_dataAvailable[i] + 'd1;
          2'b10:
            r_dataAvailable[i] <= #`TP r_dataAvailable[i] - 'd1;
        endcase
      end
    end
  end : s_dataAvailable_PROC
  
  /*
    Channel completed
  */
  always_comb begin : c_channelWorking_PROC
    w_channelWorking = '0;
    foreach (r_dataAvailable[i]) begin
      w_channelWorking[r_llChMap[i]] = |r_dataAvailable[i] | w_locked[i];
    end
  end : c_channelWorking_PROC
  
  /*
    Identify which linked-lists have context
  */
  always_comb begin : c_linkedListValid_PROC
    foreach (w_linkedListValid[i]) begin
      w_linkedListValid[i] = |r_dataAvailable[i] && !r_flusingLL[i];
    end
  end : c_linkedListValid_PROC
  
  /*
    Setting Data to the Serializer
  */
  always_comb begin : c_setDataToSerielizer_PROC
    b_cacheAccess.w_valid   = w_linkedListValid;
    b_cacheAccess.w_data    = w_dataToSerialize;
    b_cacheAccess.w_flush   = s_erasingLL;
    b_cacheAccess.w_stop    = s_stopLL;
    b_cacheAccess.w_dropReq = s_dropLLReq;
  end : c_setDataToSerielizer_PROC
  
  /*
    Calculating the initial indexes after reset
  */
  always_comb begin : c_initialIndexes_PROC
    foreach(s_initialIndexes[i]) begin
      s_initialIndexes[i] = (LP_INTERNAL_LATENCY_WD)'(i);
    end
  end : c_initialIndexes_PROC
  
  /*
    Identify which slots are being released
  */
  always_comb begin : c_slotRestored_PROC
    s_slotRestored = '0;
    foreach(w_dataAccepted[i]) begin
      if(w_dataAccepted[i] || (r_flusingLL[i] && |r_dataAvailable[i])) begin
        s_slotRestored[r_llMngr.root[i].head] = '1;
      end
    end
  end : c_slotRestored_PROC
  
  /*
    Base for slot assignment
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_slotsStatus_PROC
    if (!b_clk.w_reset_n) begin
      r_slotsStatus <= #`TP '1;
    end else begin
      foreach(r_slotsStatus[i]) begin
        case({s_slotAccepted[i], s_slotRestored[i]})
          2'b01:
            begin
              r_slotsStatus[i] <= #`TP '1;
            end
          2'b10:
            begin
              r_slotsStatus[i] <= #`TP '0;
            end
        endcase
      end
    end
  end : s_slotsStatus_PROC
  
  /*
    Managing slots available
  */
  DWC_pcie_staged_arbiter
  
   #(
     .P_INPUTS   (LP_INTERNAL_LATENCY   )
    ,.P_STAGES   (2         )
    ,.P_DATATYPE (logic [LP_INTERNAL_LATENCY_WD-1:0])
  ) u_rr_arb_slotMngr (
      .i_clk     (b_clk.w_main_clk)
     ,.i_rst_n   (b_clk.w_reset_n )
     ,.i_clr_n   (1'b1            )
     ,.i_en      (1'b1            )
     ,.i_ready   (b_push.w_push   )
     ,.i_request (r_slotsStatus   )
     ,.i_data    (s_initialIndexes)
     ,.o_grant   (s_slotAccepted  )
     ,.o_valid   ( /* NC */       )
     ,.o_data    (s_slotToUse     )
  );
  
  /*
    Managing the linked lists
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_mngrLinkedList_PROC
    if (!b_clk.w_reset_n) begin
      foreach(r_llMngr.root[i]) begin
        r_llMngr.root[i]               <= #`TP '{default: '0, empty: '1};
      end
    end else begin
      foreach(r_llMngr.root[i]) begin
        case({b_push.w_push && (s_llOfChannel == (LP_LINKED_LISTS_WD)'(i)), w_dataAccepted[i] || (r_flusingLL[i] && |r_dataAvailable[i])})
          2'b01:
            begin
              r_llMngr.root[i].head <= #`TP r_sortedUpwards[r_llMngr.root[i].head];
              if(r_llMngr.root[i].head == r_llMngr.root[i].tail) begin
                r_llMngr.root[i].empty <= #`TP '1;
                r_llMngr.root[i].tail  <= #`TP r_sortedUpwards[r_llMngr.root[i].head];
              end
            end
          2'b10:
            begin
              if(!r_llMngr.root[i].empty) begin
                r_llMngr.root[i].tail  <= #`TP s_slotToUse;
              end else begin
                r_llMngr.root[i].head  <= #`TP s_slotToUse;
                r_llMngr.root[i].tail  <= #`TP s_slotToUse;
                r_llMngr.root[i].empty <= #`TP '0;
              end
            end
          2'b11:
            begin
              if(r_llMngr.root[i].head == r_llMngr.root[i].tail) begin
                r_llMngr.root[i].head  <= #`TP s_slotToUse;
              end else begin
                r_llMngr.root[i].head  <= #`TP r_sortedUpwards[r_llMngr.root[i].head];
              end
              r_llMngr.root[i].tail    <= #`TP s_slotToUse;
            end
        endcase
      end
    end
  end : s_mngrLinkedList_PROC
  
  /*
    Managing how linked lists are connected upwards
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_sortedUpwards_PROC
    if (!b_clk.w_reset_n) begin
      r_sortedUpwards <= #`TP {s_initialIndexes[0],s_initialIndexes[LP_INTERNAL_LATENCY-1:1]};
    end else begin
      foreach (w_dataAccepted[i]) begin
        if(b_push.w_push && (s_llOfChannel == (LP_LINKED_LISTS_WD)'(i)) && !r_llMngr.root[i].empty) begin
          r_sortedUpwards[r_llMngr.root[i].tail] <= #`TP s_slotToUse;
        end
      end
    end
  end : s_sortedUpwards_PROC
  
  /*
    Storing signal connected to the external interface
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_channelErased_PROC
    if (!b_clk.w_reset_n) begin
      r_channelErased      <= #`TP '0;
      r_channelErasedValid <= #`TP '0;
      r_channelToken       <= #`TP '0;
    end else begin
      r_channelErased      <= #`TP b_cacheAccess.w_channel;
      r_channelErasedValid <= #`TP b_cacheAccess.w_sent;
      r_channelToken       <= #`TP b_cacheAccess.w_token;
    end
  end : s_channelErased_PROC
  
  /*
    Indicating that slots are being fluushed
  */
  always_comb begin : c_s_erasingSlots_PROC
    foreach(s_erasingSlots[i]) begin
      s_erasingSlots[i] = r_flusingLL[i] && |r_dataAvailable[i];
    end
  end : c_s_erasingSlots_PROC
  
  /*
    Setting which channels are flushing
  */
  always_comb begin : c_s_dropingCtx_PROC
    s_dropingCtx = '0;
    foreach(s_erasingSlots[i]) begin
      if(s_erasingSlots[i]) begin
        s_dropingCtx[r_llChMap[i]] = '1;
      end
    end
  end : c_s_dropingCtx_PROC
  
  /*
    Driving interface with fetchQ
  */
  always_comb begin : c_pushInterface_PROC
    b_push.w_channelWorking = w_channelWorking;
    b_push.w_llFull         = &w_locked;
    b_push.w_OpErase        = r_channelErasedValid; 
    b_push.w_OpEraseCh      = r_channelErased;
    b_push.w_channelToken   = r_channelToken;
    b_push.w_flusingLL      = s_erasingSlots;
    b_push.w_dropingCtx     = s_dropingCtx;
  end : c_pushInterface_PROC
  

// SNPS_SysML_CODE_END

endmodule
