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
// ---    $Revision: #9 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_fetchQ_push.sv#9 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_llq_push_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_llq_fslots_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_llq_memWr_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_llq_popUpdate_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_fetchQ_push
  import DWC_pcie_edmapf_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter type P_OVRL_TYPE = elemCtxWr_s
  ,parameter  CC_NUM_DMA_CHAN = `CC_NUM_DMA_WR_CHAN
  ,parameter       CX_DMA_LLQ = `CX_DMA_WR_LLQ
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_aclks_if.slave_mp          ctrl
  ,DWC_pcie_edmapf_llq_popUpdate_if.master_mp pop
  ,DWC_pcie_edmapf_llq_push_if.slave_mp       push
  ,DWC_pcie_edmapf_llq_fslots_if.master_mp    slotsReport
  ,DWC_pcie_edmapf_llq_memWr_if.master_mp     write
  );

  // ##########################################################################
  //                              Local parameters                             
  // ##########################################################################

  localparam P_LLQ_RAM_DP_WD         = $clog2(CC_NUM_DMA_CHAN*CX_DMA_LLQ+1)                                 ;
  localparam P_OUTSTANDINGCOUNTER_WD = (P_LLQ_RAM_DP_WD > 2) ? 3 : P_LLQ_RAM_DP_WD                          ;


// SNPS_SysML_CODE_START
  /*
    Calculating the number of bits need to represent the channel number
  */
  localparam LP_NUM_DMA_CHAN_WD = CC_NUM_DMA_CHAN > 1 ? $clog2(CC_NUM_DMA_CHAN) : 1;
  /*
    Defining the data to be pipelined
  */
  typedef struct packed {
    P_OVRL_TYPE                    ctx;
    logic [LP_NUM_DMA_CHAN_WD-1:0] ch;
    fetchOpMode_s                  opMode;
  } intData_st;
  /*
    The structure was created to eliminate the dependency between valid and ready on the interfaces
  */
  struct packed {
    logic      valid;
    intData_st data;
  } r_head, s_head, r_tail, s_tail;
  /*
     Labels which define the arbiter status
  */
  enum logic [1:0] {
    E_FSM_IDLE       = 2'b00, 
    E_FSM_POP_UPDATE = 2'b10, 
    E_FSM_PUSH       = 2'b01
                   } s_granted, r_granted;
  
  /*
    Internal wires
  */
  P_OVRL_TYPE                    r_ctx;
  logic [LP_NUM_DMA_CHAN_WD-1:0] r_ch;
  fetchOpMode_s                  r_opMode;
  logic                          r_valid;
  logic                          s_halt;
  /*
    Signals used to store all signals in the connection between the interfaces
  */
  logic                          s_headUpdate;
  logic                          s_headValid;
  logic                          s_tailUpdate;
  logic                          s_tailValid;
  logic                          s_tailClean;
  /*
    The counter of outstanding traffic
  */
  logic [CC_NUM_DMA_CHAN-1:0][P_OUTSTANDINGCOUNTER_WD-1:0] r_outstandingTrafficCounter, s_outstandingTrafficCounter;
  /*
    Decoding signal for the command received
  */
  fetchOpMode_s                                            s_commandDecoded;
  /*
    Signals used to workaround Spyglass issues
  */
  logic                              [CC_NUM_DMA_CHAN-1:0] s_slotsEmpty;
  logic         [CC_NUM_DMA_CHAN-1:0][P_LLQ_RAM_DP_WD-1:0] s_slotsAvailable;
  /*
     Arbiter which managing the traffic to the core of fetchQ
  */
  always_comb begin : c_writeArbiter_PROC
    if (s_halt) begin
      s_granted = r_granted;
    end else begin
      s_granted[0] = (push.w_push && !pop.w_OpUpdate && !r_granted[1]) || (push.w_push && !r_granted[0]);
      s_granted[1] = (pop.w_OpUpdate && !push.w_push && !r_granted[0]) || (pop.w_OpUpdate && r_granted[0] && !r_granted[1]);
    end
  end : c_writeArbiter_PROC

  /*
     Recording the decision of arbiter
  */
  always_ff @(posedge ctrl.w_main_clk, negedge ctrl.w_reset_n) begin : s_storingArbiterDecision_PROC
    if (!ctrl.w_reset_n) begin
      r_granted <= #`TP E_FSM_IDLE;
    end else if(!s_halt) begin
      r_granted <= #`TP s_granted;
    end
  end : s_storingArbiterDecision_PROC
  
  /*
    Decoding the command received from LL controller
  */
  always_comb begin : c_decodingCommandReceived_PROC
    s_commandDecoded = f_settingOpMode(push.w_pushOp);
  end : c_decodingCommandReceived_PROC
  
  /*
     Multiplexing the sources based on arbiter decision to the write interface
  */
  always_ff @(posedge ctrl.w_main_clk, negedge ctrl.w_reset_n) begin : s_MuxOvrlSignalsToTheWriteInterface_PROC
    if (!ctrl.w_reset_n) begin
      r_valid  <= #`TP '0;
      r_ctx    <= #`TP '0;
      r_ch     <= #`TP '0;
      r_opMode <= #`TP '{target: E_TRGT_NONE, counter: E_CNT_NONE, errors: E_ERR_RESET, token: E_TOKEN_RESET, stop: E_STOP_RESET};
    end else begin
      if(!s_halt)
        case (s_granted)
          E_FSM_IDLE : begin
            r_valid  <= #`TP '0;
            r_ctx    <= #`TP '0;
            r_ch     <= #`TP '0;
            r_opMode <= #`TP '{target: E_TRGT_NONE, counter: E_CNT_NONE, errors: E_ERR_NONE, token: E_TOKEN_NONE, stop: E_STOP_NONE};
          end
          E_FSM_POP_UPDATE : begin
            r_valid  <= #`TP '1;
            r_ctx    <= #`TP pop.w_UpdateCtxElem;
            r_ch     <= #`TP pop.w_OpUpdateCh;
            r_opMode <= #`TP '{target: E_TRGT_HEAD, counter: E_CNT_NONE, errors: E_ERR_NONE, token: E_TOKEN_NONE, stop: E_STOP_NONE};
          end
          E_FSM_PUSH : begin
            r_valid  <= #`TP '1;
            r_ctx    <= #`TP push.w_ctxElem.ovrl;
            r_ch     <= #`TP push.w_reqCh;
            r_opMode <= #`TP s_commandDecoded;
          end
        endcase
    end
  end : s_MuxOvrlSignalsToTheWriteInterface_PROC

  /*
     Feedback signals for each interface
  */
  always_comb begin : c_feedbackSignalsForEachInterface_PROC
    pop.w_UpdateRdy           = (s_granted != E_FSM_PUSH) && !s_halt;
    push.w_pushRdy            = (s_granted != E_FSM_POP_UPDATE) && !s_halt;
  end : c_feedbackSignalsForEachInterface_PROC
  
  /*
    Calculation the next value of outstanding traffic counter
  */
  always_comb begin : c_outstandingTrafficCounterNext_PROC
    foreach(s_outstandingTrafficCounter[i])
      if(write.w_counterUpdated[i]) begin
        if((s_commandDecoded.counter == E_CNT_INC) && (push.w_reqCh == i) && (s_granted == E_FSM_PUSH) && !s_halt) begin
          s_outstandingTrafficCounter[i] = r_outstandingTrafficCounter[i];
        end else begin
          s_outstandingTrafficCounter[i] = r_outstandingTrafficCounter[i] -'b1;
        end
      end else begin
        if((s_commandDecoded.counter == E_CNT_INC) && (push.w_reqCh == i) && (s_granted == E_FSM_PUSH) && !s_halt) begin
          s_outstandingTrafficCounter[i] = r_outstandingTrafficCounter[i] +'b1;
        end else begin
          s_outstandingTrafficCounter[i] = r_outstandingTrafficCounter[i];
        end
      end
  end : c_outstandingTrafficCounterNext_PROC
  
  /*
    Outstanding traffic counter
  */
  always_ff @(posedge ctrl.w_main_clk, negedge ctrl.w_reset_n) begin : s_outstandingTrafficCounterUpdate_PROC
    if (!ctrl.w_reset_n) begin
      foreach(r_outstandingTrafficCounter[i])
        r_outstandingTrafficCounter[i] <= #`TP '0;
    end else begin
      foreach(r_outstandingTrafficCounter[i])
        r_outstandingTrafficCounter[i] <= #`TP s_outstandingTrafficCounter[i];
    end
  end : s_outstandingTrafficCounterUpdate_PROC
  
  /*
     Reporting the number of available slots for each channel
  */
  always_ff @(posedge ctrl.w_main_clk, negedge ctrl.w_reset_n) begin : s_freeSlotsInfo_PROC
    if (!ctrl.w_reset_n) begin
      s_slotsAvailable      <= #`TP '0;
    end else begin
      foreach(s_slotsAvailable[i]) begin
        s_slotsAvailable[i] <= #`TP (P_LLQ_RAM_DP_WD)'(write.w_fifoDepth[i] - s_outstandingTrafficCounter[i]);
      end
    end
  end

  /*
  *  Reporting if each slot channel is empty
  */

  always_ff @(posedge ctrl.w_main_clk, negedge ctrl.w_reset_n) begin : s_emptySlotsInfo_PROC
     if (!ctrl.w_reset_n) begin
      foreach(s_slotsEmpty[i])
        s_slotsEmpty[i] <= #`TP '1;
    end else begin
      foreach(s_slotsEmpty[i])
        s_slotsEmpty[i] <= # `TP (s_outstandingTrafficCounter[i] == '0) && (write.w_fifoDepth[i] == write.w_fifoInit);
    end 
  end : s_emptySlotsInfo_PROC
  
  /*
    Connecting the internal signals to the interface
  */
  always_comb begin : c_slotsAvailableIfConnections_PROC
    slotsReport.w_slotsEmpty     = s_slotsEmpty;
    slotsReport.w_slotsAvailable = s_slotsAvailable;
  end : c_slotsAvailableIfConnections_PROC
  
  /*
    Driving write interface
  */
  always_comb begin : c_writeInterfaceDriver_PROC
    write.w_ovrlReq = r_head.valid;
    write.w_ovrl    = r_head.data.ctx;
    write.w_reqCh   = r_head.data.ch;
    write.w_opMode  = r_head.data.opMode;
    s_halt          = s_tailValid;
  end : c_writeInterfaceDriver_PROC
  
  /*
    Indication that head has valid data
  */
  always_comb begin : c_headValid_PROC
    s_headValid  = r_head.valid;
  end : c_headValid_PROC
  
  /*
    Generating the signal to enable the first storing bank
  */
  always_comb begin : c_headUpdate_PROC
    s_headUpdate = !(s_headValid && write.w_ovrlHalt);
  end : c_headUpdate_PROC
  
  /*
    Managing the data to be stored into the head
  */
  always_comb begin : c_firstStoringBank_PROC
    if (s_headUpdate) begin
      if (!s_tailValid) begin
        s_head.data.ctx    = r_ctx;
        s_head.data.ch     = r_ch;
        s_head.data.opMode = r_opMode;
        s_head.valid       = r_valid;
      end else begin
        s_head = r_tail;
      end
    end else begin
      s_head = r_head;
    end
  end : c_firstStoringBank_PROC

  /*
    First storing bank
  */
  always_ff @(posedge ctrl.w_main_clk, negedge ctrl.w_reset_n) begin : s_firstStoringBank_PROC
    if (!ctrl.w_reset_n) begin
      r_head <= #`TP '0;
    end else begin
      r_head <= #`TP s_head;
    end
  end : s_firstStoringBank_PROC
  
  /*
    Generating the indication that tail can be updated
  */
  always_comb begin : c_tailUpdate_PROC
    s_tailUpdate  = s_headValid && (s_tailValid || write.w_ovrlHalt) && (!s_tailValid || !write.w_ovrlHalt);
  end : c_tailUpdate_PROC
  
  /*
    Indication if tail has valid data
  */
  always_comb begin : c_tailValid_PROC
    s_tailValid   = r_tail.valid;
  end : c_tailValid_PROC
  
  /*
    Generating the signal which will reset the tail
  */
  always_comb begin : c_tailClean_PROC
    s_tailClean   = !write.w_ovrlHalt;
  end : c_tailClean_PROC
  
  /*
    Managing the data to be stored into the tail
  */
  always_comb begin : c_secondStoringBank_PROC
    if (s_tailClean) begin
      s_tail = '0;
    end else if (s_tailUpdate) begin
      s_tail.data.ctx    = r_ctx;
      s_tail.data.ch     = r_ch;
      s_tail.data.opMode = r_opMode;
      s_tail.valid  = r_valid;
    end else begin
      s_tail = r_tail;
    end
  end : c_secondStoringBank_PROC

  /*
    Second storing bank
  */
  always_ff @(posedge ctrl.w_main_clk, negedge ctrl.w_reset_n) begin : s_secondStoringBank_PROC
    if (!ctrl.w_reset_n) begin
      r_tail <= #`TP '0;
    end else begin
      r_tail <= #`TP s_tail;
    end
  end : s_secondStoringBank_PROC

  /*
     Translating the commands received from LL controller to the operations modes of the fetchQ
  */
  function automatic fetchOpMode_s f_settingOpMode(llPushOp_e llOpMode);
  fetchOpMode_s s_returnValue;
  case (llOpMode)
    E_NLL_TRIGGER:
      s_returnValue = '{target: E_TRGT_NONE, counter: E_CNT_SET  , errors: E_ERR_RESET, token: E_TOKEN_RESET, stop: E_STOP_RESET};
    E_PUSH       :
      s_returnValue = '{target: E_TRGT_TAIL, counter: E_CNT_INC  , errors: E_ERR_RESET, token: E_TOKEN_RESET, stop: E_STOP_RESET};
    E_EOT_TOKEN  :
      s_returnValue = '{target: E_TRGT_TAIL, counter: E_CNT_NONE , errors: E_ERR_RESET, token: E_TOKEN_SET  , stop: E_STOP_SET  }; 
    E_TRIG_TOKEN :
      s_returnValue = '{target: E_TRGT_NONE, counter: E_CNT_SET  , errors: E_ERR_NONE , token: E_TOKEN_SET  , stop: E_STOP_NONE }; 
    E_LL_END     :
      s_returnValue = '{target: E_TRGT_NONE, counter: E_CNT_SET  , errors: E_ERR_RESET, token: E_TOKEN_SET  , stop: E_STOP_NONE }; 
    E_LL_ERR     :
      s_returnValue = '{target: E_TRGT_NONE, counter: E_CNT_SET  , errors: E_ERR_SET  , token: E_TOKEN_SET  , stop: E_STOP_RESET}; 
    E_ERR_TOKEN  :
      s_returnValue = '{target: E_TRGT_HEAD, counter: E_CNT_RESET, errors: E_ERR_SET  , token: E_TOKEN_SET  , stop: E_STOP_SET  }; 
    default:
      s_returnValue = '{target: E_TRGT_NONE, counter: E_CNT_NONE , errors: E_ERR_NONE , token: E_TOKEN_NONE , stop: E_STOP_NONE };
  endcase
  return s_returnValue;
  endfunction


// SNPS_SysML_CODE_END

endmodule
