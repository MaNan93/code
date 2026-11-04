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
// ---    $Revision: #22 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_fetchQ_virtualMemCtrl.sv#22 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_llq_memWr_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_llq_crgbWr_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_llq_crgbRd_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_llq_popInternal_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ram2p_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_genericData_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_fetchQ_virtualMemCtrl
  import DWC_pcie_edmapf_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter type P_ERROR_TYPE = dmaErrors_e
  ,parameter  type P_OVRL_TYPE = elemCtxWr_s
  ,parameter   CC_NUM_DMA_CHAN = `CC_NUM_DMA_WR_CHAN
  ,parameter        CX_DMA_LLQ = `CX_DMA_WR_LLQ
  ,parameter        P_PIPELINE = 1
  ,parameter      P_RAM_REG_IF = 1
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_ram2p_if.master_mp           b_ovrlRam
  ,DWC_pcie_edmapf_llq_crgbRd_if.slave_mp       crgbRd
  ,DWC_pcie_edmapf_llq_crgbWr_if.slave_mp       crgbWr
  ,DWC_pcie_edmapf_aclks_if.slave_mp            ctrl
  ,DWC_pcie_edmapf_genericData_if.slave_mp      glbCtx
  ,DWC_pcie_edmapf_llq_popInternal_if.master_mp read
  ,DWC_pcie_edmapf_llq_memWr_if.slave_mp        write
  );


// SNPS_SysML_CODE_START
  /*
     Local paramaters used internally
  */
  localparam           LP_LLQ_RAM_DP         = CC_NUM_DMA_CHAN*CX_DMA_LLQ;
  localparam           LP_LLQ_RAM_DP_WD      = (LP_LLQ_RAM_DP == 1) ? 1 : $clog2(LP_LLQ_RAM_DP);
  localparam           LP_NUM_DMA_CHAN_WD    = (CC_NUM_DMA_CHAN==1) ? 1 : $clog2(CC_NUM_DMA_CHAN);
  localparam integer      LP_REG_DELAY_DENOM = 1000;
  localparam integer      LP_REG_DELAY_TIME  = `TP * LP_REG_DELAY_DENOM;
  localparam            LP_LATENCY_DAMPER_WD = LP_NUM_DMA_CHAN_WD + 4 + $bits(P_ERROR_TYPE);
  localparam            LP_LATENCY_DAMPER_DP = P_PIPELINE + 2*P_RAM_REG_IF +1;
  localparam       LP_LATENCY_DAMPER_ADDR_WD = $clog2(LP_LATENCY_DAMPER_DP);
  /*
    Internal structure to pass data through latency fifo
  */
  typedef struct packed {
    logic [LP_NUM_DMA_CHAN_WD-1:0] channel;
    P_ERROR_TYPE                   errors;
    logic                          token;
    logic                          stop;
    logic                          externalReq;
    logic                          poison;
  } st_latData_int;
  /*
    Signals to pass dataq through latency fifo
  */
  st_latData_int                                     s_latData;
  st_latData_int                                     r_latData;
  /*
     FIFO control signals
  */
  logic   [CC_NUM_DMA_CHAN-1:0] [LP_LLQ_RAM_DP_WD:0] r_fifoDepth;
  logic   [CC_NUM_DMA_CHAN-1:0] [LP_LLQ_RAM_DP_WD:0] r_fifoHead;
  logic   [CC_NUM_DMA_CHAN-1:0] [LP_LLQ_RAM_DP_WD:0] r_fetchCounter;
  logic [CC_NUM_DMA_CHAN-1:0] [LP_LLQ_RAM_DP_WD-1:0] s_fetchPointer;
  logic   [CC_NUM_DMA_CHAN-1:0] [LP_LLQ_RAM_DP_WD:0] s_fifoHeadNext;
  logic   [CC_NUM_DMA_CHAN-1:0] [LP_LLQ_RAM_DP_WD:0] s_fifoHeadNextPlusOne;
  logic   [CC_NUM_DMA_CHAN-1:0] [LP_LLQ_RAM_DP_WD:0] s_fetchPointerPlusCounter;
  logic     [CC_NUM_DMA_CHAN:0] [LP_LLQ_RAM_DP_WD:0] s_fifoHeadStarting;
  logic   [CC_NUM_DMA_CHAN-1:0] [LP_LLQ_RAM_DP_WD:0] s_fifoHeadLimite;
  logic   [CC_NUM_DMA_CHAN-1:0] [LP_LLQ_RAM_DP_WD:0] s_fifoTail;
  logic   [CC_NUM_DMA_CHAN-1:0] [LP_LLQ_RAM_DP_WD:0] s_fifoHeadPlusDepth;
  /*
     Reports the number of slots available per channel
  */
  logic   [CC_NUM_DMA_CHAN-1:0] [LP_LLQ_RAM_DP_WD:0] s_slotsAvailable;
  /*
    Errors LUT
  */
  P_ERROR_TYPE                 [CC_NUM_DMA_CHAN-1:0] r_errorsLUT;
  logic                        [CC_NUM_DMA_CHAN-1:0] s_errorsLUT;
  P_ERROR_TYPE                                       s_errors;
  /*
    Token LUT
  */
  logic                        [CC_NUM_DMA_CHAN-1:0] r_tokenLUT;
  logic                                              s_token;
  /*
    Token LUT
  */
  logic                        [CC_NUM_DMA_CHAN-1:0] r_stopLUT;
  logic                                              s_stop;
  /*
    Signals used to deconde the Write address
  */
  logic                       [LP_LLQ_RAM_DP_WD-1:0] r_addressTarget;
  logic                       [LP_LLQ_RAM_DP_WD-1:0] s_addressTarget;
  /*
     Labels which define the arbiter status
  */
  enum logic [1:0] {
    E_IDLE     = 2'b00, 
    E_CRGB     = 2'b10, 
    E_EXTERNAL = 2'b01
                   } s_grantedWr, r_grantedWr, s_grantedRd, r_grantedRd;
  /*
     Mux signals
  */
  fetchQ_s                               r_muxOvrlRamData;
  logic         [LP_NUM_DMA_CHAN_WD-1:0] r_muxOvrlRamCh;
  fetchOpMode_s                          r_muxOvrlRamOpMode;
  logic         [LP_NUM_DMA_CHAN_WD-1:0] r_muxRdCh;
  logic         [LP_NUM_DMA_CHAN_WD-1:0] s_popAddress;
  logic                                  s_extFetch;
  /*
     FIFO control signals that control the ack signals
  */
  logic                                  s_pop, s_push;
  /*
     Registers used to generate prefetch depth update
  */
  logic             [LP_LLQ_RAM_DP_WD:0] r_glbPfDepthRaw;
  logic             [LP_LLQ_RAM_DP_WD:0] r_glbPfDepth;
  logic                                  s_glbPfDepth_set;
  /*
     Signals to be used in the assertions
  */
  logic                                  s_error;
  /*
     The signal which disabling updates from the requester
  */
  logic            [CC_NUM_DMA_CHAN-1:0] r_updateDisabler_n;
  logic                                  s_erase;
  logic                                  s_rollback;
  logic                                  s_wrRAM;
  /*
     Locking the fetch pointer in case of errors
  */
  logic            [CC_NUM_DMA_CHAN-1:0] r_fetchDisabler;
  /*
     Signals used to preserve the request from CRGB
  */
  logic                                  s_crgbRdReq;
  logic                                  r_crgbRdReq;
  logic                                  s_crgbWrReq;
  logic                                  r_crgbWrReq;
  /*
    Error injected with conflicts with read generates a poison
  */
  logic                                  s_poison;
  logic                                  r_emptyPoison;
  /*
     Signal used to prevent collision between reading and writing on RAM access
  */
  logic                                  s_rdWrCollision;
  /*
     Signal created to split the data received from RAM in separated fields
  */
  fetchQ_s                               s_ramDataReceived;
  /*
    Signals used to workaround Spyglass issues
  */
  logic            [CC_NUM_DMA_CHAN-1:0] s_counterUpdate;
  logic            [CC_NUM_DMA_CHAN-1:0] s_fifoEmpty;
  logic            [CC_NUM_DMA_CHAN-1:0] s_fifoHeadAccess;
  /*
    Creating an internal version of the interface signal
  */
  glbData_s        [CC_NUM_DMA_CHAN-1:0] s_glbCtx;
  
  /*
    Creating an internal version of the global context interface
  */
  always_comb begin : c_s_glbCtx_PROC
    s_glbCtx = glbCtx.w_data;
  end : c_s_glbCtx_PROC
  
  /*
    Calculating prefetch depth update signal
    For now, only the channel 0 is used
  */
  always_ff @(posedge ctrl.w_aux_clk, negedge ctrl.w_reset_n) begin : s_glbPfDepthRaw_PROC
    if (!ctrl.w_reset_n) begin
      r_glbPfDepthRaw <= #`TP '0;
    end else begin
      r_glbPfDepthRaw <= #`TP (LP_LLQ_RAM_DP_WD+1)'(s_glbCtx[0].pf_depth + 1'b1);
    end
  end : s_glbPfDepthRaw_PROC
  
  /*
    Generating the flag to start the pointers calculation
  */
  always_comb begin : c_glbPfDepth_PROC
    s_glbPfDepth_set = |(r_glbPfDepthRaw ^ r_glbPfDepth);
  end : c_glbPfDepth_PROC

  /*
    Register prefetch depth to prevent generate set signal
  */
  always_ff @(posedge ctrl.w_aux_clk, negedge ctrl.w_reset_n) begin : s_glbPfDepth_PROC
    if (!ctrl.w_reset_n) begin
      r_glbPfDepth   <= #`TP 0;
    end else begin
      if (s_glbPfDepth_set) begin
        r_glbPfDepth <= #`TP r_glbPfDepthRaw;
      end else begin
        r_glbPfDepth <= #`TP r_glbPfDepth;
      end
    end
  end : s_glbPfDepth_PROC
  
  /*
    Calculating the number of slots available
  */
  always_comb begin : c_calcSlotsAvailable_PROC
    foreach(s_slotsAvailable[i]) begin
      s_slotsAvailable[i] = (LP_LLQ_RAM_DP_WD+1)'(r_glbPfDepth - r_fifoDepth[i]);
    end
  end : c_calcSlotsAvailable_PROC
  
  /*
     Reporting the number of free slots and max prefetch size
  */
  always_comb begin : c_reportingFreeSlotsAvailableAndMaxPreFetch_PROC
    write.w_fifoDepth = s_slotsAvailable;
    write.w_fifoInit  = r_glbPfDepth;
  end : c_reportingFreeSlotsAvailableAndMaxPreFetch_PROC
  
  /*
    Acknowledgment from the depth counter which was updated
  */
  always_ff @(posedge ctrl.w_aux_clk, negedge ctrl.w_reset_n) begin : s_depthCounterAck_PROC
    if (!ctrl.w_reset_n) begin
      foreach(s_counterUpdate[i])
        s_counterUpdate[i] <= #`TP '0;
    end else begin
      foreach(s_counterUpdate[i])
        if((write.w_reqCh==i) && (s_grantedWr == E_EXTERNAL) && (write.w_opMode.counter == E_CNT_INC) && !write.w_ovrlHalt)
          s_counterUpdate[i] <= #`TP '1;
        else
          s_counterUpdate[i] <= #`TP '0;
    end
  end :  s_depthCounterAck_PROC
  
  /*
    Wiring the acknowledgment from the depth counter which was updated to the exterior
  */
  always_comb begin : c_wiringDepthCounterAck_PROC
    write.w_counterUpdated = s_counterUpdate;
  end : c_wiringDepthCounterAck_PROC
  
  /*
    Calculating the starting address of the FIFO
  */
  always_comb begin : c_s_fifoHeadStartingCalc_PROC
    foreach (s_fifoHeadStarting[i])
      s_fifoHeadStarting[i] = (LP_LLQ_RAM_DP_WD+1)'(i*r_glbPfDepth);
  end : c_s_fifoHeadStartingCalc_PROC
  
  /*
    Calculating the limite of the fifo indexing
  */
  always_comb begin : c_fifoHeadLimite_PROC
    s_fifoHeadLimite = s_fifoHeadStarting[CC_NUM_DMA_CHAN:1];
  end : c_fifoHeadLimite_PROC
  
  /*
    Calculating the potencial next head pointer
  */
  always_comb begin : c_fifoHeadPotencialNext_PROC
    foreach (s_fifoHeadNextPlusOne[i])
      s_fifoHeadNextPlusOne[i] = r_fifoHead[i] + 'b1;
  end : c_fifoHeadPotencialNext_PROC
  
  /*
     Initializion the start address of each FIFO (channel)
  */
  always_comb begin : c_calcNextAddressFifo_PROC
  foreach(r_fifoHead[i])
    if(s_fifoHeadNextPlusOne[i] == s_fifoHeadLimite[i])
      s_fifoHeadNext[i] = s_fifoHeadStarting[i];
    else
      s_fifoHeadNext[i] = s_fifoHeadNextPlusOne[i];
  end : c_calcNextAddressFifo_PROC

  /*
     Managing the Head of each FIFO (channel)
  */
  always_ff @(posedge ctrl.w_aux_clk, negedge ctrl.w_reset_n) begin : s_settingHeadFifo_PROC
    if (!ctrl.w_reset_n) begin
      foreach(r_fifoHead[i])
        r_fifoHead[i] <= #`TP (LP_LLQ_RAM_DP_WD+1)'(i*CX_DMA_LLQ);
    end else if (s_glbPfDepth_set) begin
      foreach(r_fifoHead[i])
        r_fifoHead[i] <= #`TP (LP_LLQ_RAM_DP_WD+1)'(i*r_glbPfDepthRaw);
    end else if (s_erase && ((r_fifoDepth[read.w_OpEraseCh] != 'b1) || ((r_fifoDepth[read.w_OpEraseCh] == 'b1) && (s_grantedWr == E_EXTERNAL) && (write.w_reqCh == read.w_OpEraseCh)))) begin
      r_fifoHead[read.w_OpEraseCh] <= #`TP s_fifoHeadNext[read.w_OpEraseCh];
    end
  end : s_settingHeadFifo_PROC

  /*
    Calculating potential pointer address of the next fetch
  */
  always_comb begin : c_fifoPointerPlusFetchCounter_PROC
    foreach(s_fetchPointerPlusCounter[i])
      if (r_fetchCounter[i] > '0) begin
        s_fetchPointerPlusCounter[i] = (LP_LLQ_RAM_DP_WD+1)'(r_fifoHead[i] + r_fetchCounter[i] - 'd1);
      end else begin
        s_fetchPointerPlusCounter[i] = (LP_LLQ_RAM_DP_WD+1)'(r_fifoHead[i] + r_fetchCounter[i]);
      end
  end : c_fifoPointerPlusFetchCounter_PROC
  
  /*
    Calculating next Fetch address 
  */
  always_comb begin : c_addressFetchCalc_PROC
    foreach (s_fetchPointer[i])
      if (s_fetchPointerPlusCounter[i] >= s_fifoHeadLimite[i])
        s_fetchPointer[i] = (LP_LLQ_RAM_DP_WD)'(s_fetchPointerPlusCounter[i] - r_glbPfDepth);
      else
        s_fetchPointer[i] = (LP_LLQ_RAM_DP_WD)'(s_fetchPointerPlusCounter[i]);
   end : c_addressFetchCalc_PROC
  
  /*
    Process which identify that an error raised and the fetch needs to be disabled
  */
  always_ff @(posedge ctrl.w_aux_clk, negedge ctrl.w_reset_n) begin : s_fetchDisabler_n_PROC
    if (!ctrl.w_reset_n) begin
      r_fetchDisabler                    <= #`TP '0;
    end else begin
      case({(write.w_opMode.counter == E_CNT_SET), (write.w_opMode.counter == E_CNT_RESET)})
        2'b01:
          r_fetchDisabler[write.w_reqCh] <= #`TP '1;
        2'b10:
          r_fetchDisabler[write.w_reqCh] <= #`TP '0;
      endcase
    end
  end : s_fetchDisabler_n_PROC
  
  /*
     Managing the Push Pointer of each FIFO (channel)
  */
  always_ff @(posedge ctrl.w_aux_clk, negedge ctrl.w_reset_n) begin : s_settingPushPointer_PROC
    if (!ctrl.w_reset_n) begin
      foreach(r_fetchCounter[i]) begin
        r_fetchCounter[i]         <= #`TP '0;
      end
    end else if (s_glbPfDepth_set) begin
      foreach(r_fetchCounter[i]) begin
        r_fetchCounter[i]         <= #`TP '0;
      end
    end else begin
      foreach(r_fetchCounter[i])
        if(((s_grantedWr == E_EXTERNAL) && !write.w_ovrlHalt && (write.w_opMode.errors == E_ERR_SET) && (write.w_reqCh == (LP_NUM_DMA_CHAN_WD'(i)))) || (r_fetchDisabler[i])) begin
          r_fetchCounter[i]       <= #`TP '0;
        end else begin
          case ({((s_grantedRd == E_EXTERNAL) && (read.w_OpFetchCh == (LP_NUM_DMA_CHAN_WD'(i))) && !s_fifoEmpty[read.w_OpFetchCh]), ((s_rollback) && (read.w_rollbackCh == (LP_NUM_DMA_CHAN_WD'(i)))), ((s_erase) && (read.w_OpEraseCh == (LP_NUM_DMA_CHAN_WD'(i))))})
            3'b001:
              begin
                r_fetchCounter[i] <= #`TP r_fetchCounter[i] - 'd1;
              end
            3'b010:
              begin
                r_fetchCounter[i] <= #`TP r_fetchCounter[i] - 'd1;
              end
            3'b100:
              begin
                r_fetchCounter[i] <= #`TP r_fetchCounter[i] + 'd1;
              end
          endcase
        end
    end
  end : s_settingPushPointer_PROC

  /*
     Managing the Depth of each FIFO (channel)
  */
  always_ff @(posedge ctrl.w_aux_clk, negedge ctrl.w_reset_n) begin : s_settingDepthFifo_PROC
    if (!ctrl.w_reset_n) begin
      foreach(r_fifoDepth[i])
        r_fifoDepth[i] <= #`TP '0;
    end else if (s_glbPfDepth_set) begin
      foreach(r_fifoDepth[i])
        r_fifoDepth[i] <= #`TP '0;
    end else begin
      case({s_erase, (s_grantedWr == E_EXTERNAL) && !write.w_ovrlHalt})
        2'b01:
          case(write.w_opMode.counter)
            E_CNT_RESET:
              r_fifoDepth[write.w_reqCh] <= #`TP '0;
            E_CNT_SET:
              r_fifoDepth[write.w_reqCh] <= #`TP 'd1;
            E_CNT_INC:
              r_fifoDepth[write.w_reqCh] <= #`TP r_fifoDepth[write.w_reqCh] + 'd1;
          endcase
        2'b10:
          r_fifoDepth[read.w_OpEraseCh] <= #`TP r_fifoDepth[read.w_OpEraseCh] - 'd1;
        2'b11:
          if(read.w_OpEraseCh != write.w_reqCh) begin
            r_fifoDepth[read.w_OpEraseCh] <= #`TP r_fifoDepth[read.w_OpEraseCh] - 'd1;
            case(write.w_opMode.counter)
              E_CNT_RESET:
                r_fifoDepth[write.w_reqCh] <= #`TP '0;
              E_CNT_SET:
                r_fifoDepth[write.w_reqCh] <= #`TP 'd1;
              E_CNT_INC:
                r_fifoDepth[write.w_reqCh] <= #`TP r_fifoDepth[write.w_reqCh] + 'd1;
            endcase
          end else begin
            case(write.w_opMode.counter)
              E_CNT_RESET:
                r_fifoDepth[write.w_reqCh] <= #`TP '0;
              E_CNT_SET:
                r_fifoDepth[write.w_reqCh] <= #`TP 'd1;
            endcase
          end
      endcase
    end
  end : s_settingDepthFifo_PROC

  /*
     CRGB write indication
  */
  always_comb begin : c_crgbWrReq_PROC
    s_crgbWrReq = crgbWr.w_ovrlReq || r_crgbWrReq;
  end : c_crgbWrReq_PROC
  
  /*
     Stiking the CRGB Write request
  */
  always_ff @(posedge ctrl.w_aux_clk, negedge ctrl.w_reset_n) begin : s_crgbWrReqSticky_PROC
    if (!ctrl.w_reset_n) begin
      r_crgbWrReq <= #`TP '0;
    end else if (crgbWr.w_ovrlReq && ((s_grantedWr != E_CRGB) || s_rdWrCollision)) begin
      r_crgbWrReq <= #`TP '1;
    end else if((s_grantedWr == E_CRGB) && !s_rdWrCollision) begin
      r_crgbWrReq <= #`TP '0;
    end
  end : s_crgbWrReqSticky_PROC
  
  /*
     Arbiter which managing the Overlay RAM write requests
  */
  always_comb begin : c_arbiterOvrlWr_PROC
    s_grantedWr[0] = (write.w_ovrlReq && !s_crgbWrReq && !r_grantedWr[1]) || (write.w_ovrlReq && !r_grantedWr[0]);
    s_grantedWr[1] = (s_crgbWrReq && !write.w_ovrlReq && !r_grantedWr[0]) || (s_crgbWrReq && r_grantedWr[0] && !r_grantedWr[1]);
  end : c_arbiterOvrlWr_PROC

  /*
     Returning a pulse validating the access to the Wr Ovrl arbiter
  */
  always_comb begin : c_ackWrReqOvrl_PROC
    write.w_ovrlHalt = (s_grantedWr == E_CRGB) || s_rdWrCollision;
    crgbWr.w_ackOvrl = (s_grantedWr == E_CRGB) && !s_rdWrCollision;
  end : c_ackWrReqOvrl_PROC

  /*
     Multiplexing the sources based on arbiter decision to Wr Ovrl RAM
  */
  always_ff @(posedge ctrl.w_aux_clk, negedge ctrl.w_reset_n) begin : s_MuxOvrlRamWrites_PROC
    if (!ctrl.w_reset_n) begin
      r_grantedWr        <= #`TP E_IDLE;
      r_muxOvrlRamCh     <= #`TP '0;
      r_muxOvrlRamData   <= #`TP '0;
      r_muxOvrlRamOpMode <= #`TP '{target: E_TRGT_NONE, counter: E_CNT_NONE, errors: E_ERR_NONE, token: E_TOKEN_NONE, stop: E_STOP_NONE};
    end else begin
      if(!s_rdWrCollision) begin
        r_grantedWr        <= #`TP s_grantedWr;
        case (s_grantedWr)
          E_IDLE : begin
            r_muxOvrlRamCh     <= #`TP '0;
            r_muxOvrlRamData   <= #`TP '0;
            r_muxOvrlRamOpMode <= #`TP '{target: E_TRGT_NONE, counter: E_CNT_NONE, errors: E_ERR_NONE, token: E_TOKEN_NONE, stop: E_STOP_NONE};
          end
          E_EXTERNAL : begin
            r_muxOvrlRamCh     <= #`TP write.w_reqCh;
            r_muxOvrlRamData   <= #`TP '{ovrlData: write.w_ovrl.ovrlData, llData: write.w_ovrl.llData};
            r_muxOvrlRamOpMode <= #`TP write.w_opMode;
          end
          E_CRGB : begin
            r_muxOvrlRamCh     <= #`TP crgbWr.w_reqCh;
            r_muxOvrlRamData   <= #`TP crgbWr.w_ovrl;
            r_muxOvrlRamOpMode <= #`TP crgbWr.w_opMode;
          end
        endcase
      end
    end
  end : s_MuxOvrlRamWrites_PROC
  
  /*
    Calculating potential tail address of the FIFOs
  */
  always_comb begin : c_fifoHeadPlusDepth_PROC
    foreach(s_fifoHeadPlusDepth[i])
      s_fifoHeadPlusDepth[i] = (LP_LLQ_RAM_DP_WD+1)'(r_fifoHead[i] + r_fifoDepth[i]);
  end : c_fifoHeadPlusDepth_PROC
  
  /*
    Calculating FIFO Tail 
  */
  always_comb begin : c_FifoTailCalc_PROC
    foreach (s_fifoTail[i])
      if (s_fifoHeadPlusDepth[i] >= s_fifoHeadLimite[i])
        s_fifoTail[i] = (LP_LLQ_RAM_DP_WD+1)'(s_fifoHeadPlusDepth[i] - r_glbPfDepth);
      else
        s_fifoTail[i] = s_fifoHeadPlusDepth[i];
   end : c_FifoTailCalc_PROC
  
  /*
    Setting the write address depending of the external source
  */
  always_comb begin : c_calcAddressForExternalWriteAccess_PROC
    case (write.w_opMode.target)
      E_TRGT_TAIL:
        s_addressTarget = (LP_LLQ_RAM_DP_WD)'(s_fifoTail[write.w_reqCh]);
      E_TRGT_HEAD,
      E_TRGT_NONE:
        s_addressTarget = (LP_LLQ_RAM_DP_WD)'(r_fifoHead[write.w_reqCh]);
      default:
        s_addressTarget = (LP_LLQ_RAM_DP_WD)'(r_fifoHead[write.w_reqCh]);
    endcase
  end : c_calcAddressForExternalWriteAccess_PROC
  
  /*
     Validating the source type
  */
  always_ff @(posedge ctrl.w_aux_clk, negedge ctrl.w_reset_n) begin : s_settingWrAdressOvrlRam_PROC
    if (!ctrl.w_reset_n) begin
      r_addressTarget <= #`TP '0;
    end else begin
      if(!s_rdWrCollision) begin
        case (s_grantedWr)
          E_EXTERNAL:
            r_addressTarget <= #`TP s_addressTarget;
          E_CRGB:
            r_addressTarget <= #`TP (LP_LLQ_RAM_DP_WD)'(r_fifoHead[crgbWr.w_reqCh]);
        endcase
      end
    end
  end : s_settingWrAdressOvrlRam_PROC
  
  /*
    Set the RAM write enable pin
  */
  always_comb begin : c_wrEnRAM_PROC
    case(r_muxOvrlRamOpMode.target)
      E_TRGT_HEAD: begin
        if((r_muxOvrlRamOpMode.counter == E_CNT_NONE) && (r_muxOvrlRamOpMode.errors == E_ERR_NONE) && (r_muxOvrlRamOpMode.token == E_TOKEN_NONE))
          s_wrRAM = r_updateDisabler_n[r_muxOvrlRamCh];
        else
          s_wrRAM = '1;
      end
      E_TRGT_TAIL: begin
        s_wrRAM = '1;
      end
      default: begin
        s_wrRAM = '0;
      end
    endcase
  end : c_wrEnRAM_PROC
  
  /*
     Driving the signals to write in Overlay RAM
  */
  always_ff @(posedge ctrl.w_aux_clk, negedge ctrl.w_reset_n) begin : s_settingOverlayData_PROC
    if (!ctrl.w_reset_n) begin
      b_ovrlRam.w_ena   <= #`TP '0;
      b_ovrlRam.w_wea   <= #`TP '0;
      b_ovrlRam.w_dina  <= #`TP '0;
      b_ovrlRam.w_addra <= #`TP '0;
    end else if (r_grantedWr != E_IDLE)  begin
      b_ovrlRam.w_ena   <= #`TP s_wrRAM && !s_rdWrCollision;
      b_ovrlRam.w_wea   <= #`TP s_wrRAM && !s_rdWrCollision;
      b_ovrlRam.w_dina  <= #`TP r_muxOvrlRamData;
      b_ovrlRam.w_addra <= #`TP r_addressTarget;
    end else begin
      b_ovrlRam.w_ena   <= #`TP '0;
      b_ovrlRam.w_wea   <= #`TP '0;
      b_ovrlRam.w_dina  <= #`TP '0;
      b_ovrlRam.w_addra <= #`TP '0;
    end
  end : s_settingOverlayData_PROC
  
  /*
    Storing the erros based in the command received
  */
  always_ff @(posedge ctrl.w_aux_clk, negedge ctrl.w_reset_n) begin : s_errorsLUT_PROC
    if (!ctrl.w_reset_n) begin
      foreach (r_errorsLUT[i])
        r_errorsLUT[i] <= #`TP E_DMAERR_NONE;
    end else if ((s_grantedWr == E_EXTERNAL) && !write.w_ovrlHalt) begin
      if (write.w_opMode.errors == E_ERR_SET)
        r_errorsLUT[write.w_reqCh] <= #`TP write.w_ovrl.errors;
      else if (write.w_opMode.errors == E_ERR_RESET)
        r_errorsLUT[write.w_reqCh] <= #`TP E_DMAERR_NONE;
    end
  end : s_errorsLUT_PROC
  
  /*
    Storing the token based in the command received
  */
  always_ff @(posedge ctrl.w_aux_clk, negedge ctrl.w_reset_n) begin : s_tokenLUT_PROC
    if (!ctrl.w_reset_n) begin
      foreach (r_tokenLUT[i])
        r_tokenLUT[i] <= #`TP '0;
    end else if ((s_grantedWr == E_EXTERNAL) && !write.w_ovrlHalt) begin
      if (write.w_opMode.token == E_TOKEN_SET)
        r_tokenLUT[write.w_reqCh] <= #`TP '1;
      else if (write.w_opMode.token == E_TOKEN_RESET)
        r_tokenLUT[write.w_reqCh] <= #`TP '0;
    end
  end : s_tokenLUT_PROC
  
  /*
    Storing the stop based in the command received
  */
  always_ff @(posedge ctrl.w_aux_clk, negedge ctrl.w_reset_n) begin : s_stopLUT_PROC
    if (!ctrl.w_reset_n) begin
      foreach (r_stopLUT[i])
        r_stopLUT[i] <= #`TP '0;
    end else if ((s_grantedWr == E_EXTERNAL) && !write.w_ovrlHalt) begin
      if (write.w_opMode.stop == E_STOP_SET)
        r_stopLUT[write.w_reqCh] <= #`TP write.w_ovrl.stop;
      else if (write.w_opMode.stop == E_STOP_RESET)
        r_stopLUT[write.w_reqCh] <= #`TP '0;
    end
  end : s_stopLUT_PROC
  
  /*
    Poisoning the read by over-fetch
  */
  always_ff @(posedge ctrl.w_aux_clk, negedge ctrl.w_reset_n) begin : s_emptyPoison_PROC
    if (!ctrl.w_reset_n) begin
      r_emptyPoison <= #`TP '0;
    end else begin
      r_emptyPoison <= #`TP s_fifoEmpty[read.w_OpFetchCh];
    end
  end : s_emptyPoison_PROC
  
  /*
    Detecting reading colision when errors are being set
  */
  always_comb begin : c_generatingPoison_PROC
    if ((r_grantedRd == E_EXTERNAL) && (((r_muxOvrlRamCh == r_muxRdCh) && (r_grantedWr == E_EXTERNAL) && (r_muxOvrlRamOpMode.errors == E_ERR_SET)) || (r_emptyPoison))) begin
      s_poison = '1;
    end else begin
      s_poison = '0;
    end
  end : c_generatingPoison_PROC
  
  /*
    Detecting reading and writing access for the same address
  */
  always_comb begin : c_readingWritingCollisionRAMAccess_PROC
    if (r_grantedWr != E_IDLE) begin
      if ((r_grantedRd == E_CRGB) && ((LP_LLQ_RAM_DP_WD+1)'(r_addressTarget) == r_fifoHead[r_muxRdCh])) begin
        s_rdWrCollision = '1;
      end else if ((r_grantedRd == E_EXTERNAL) && (r_addressTarget == s_fetchPointer[r_muxRdCh])) begin
        s_rdWrCollision = '1;
      end else begin
        s_rdWrCollision = '0;
      end
    end else begin
      s_rdWrCollision = '0;
    end
  end : c_readingWritingCollisionRAMAccess_PROC
  
  /*
     CRGB read indication
  */
  always_comb begin : c_crgbRdReq_PROC
    s_crgbRdReq = crgbRd.w_en || r_crgbRdReq;
  end : c_crgbRdReq_PROC
  
  /*
     Stiking the CRGB Read request
  */
  always_ff @(posedge ctrl.w_aux_clk, negedge ctrl.w_reset_n) begin : s_crgbRdReqSticky_PROC
    if (!ctrl.w_reset_n) begin
      r_crgbRdReq <= #`TP '0;
    end else if (read.w_OpFetch && crgbRd.w_en) begin
      r_crgbRdReq <= #`TP '1;
    end else begin
      r_crgbRdReq <= #`TP '0;
    end
  end : s_crgbRdReqSticky_PROC
  
  /*
     Arbiter which managing the reading requests to the RAMs
  */
  always_comb begin : c_arbiterRd_PROC
    s_grantedRd[0] = (read.w_OpFetch && !s_crgbRdReq && !r_grantedRd[1]) || (read.w_OpFetch && !r_grantedRd[0]);
    s_grantedRd[1] = (s_crgbRdReq && !read.w_OpFetch && !r_grantedRd[0]) || (s_crgbRdReq && r_grantedRd[0] && !r_grantedRd[1]);
  end : c_arbiterRd_PROC

  /*
     Multiplexing the sources based on arbiter decision to Rd Ovrl RAM
  */
  always_ff @(posedge ctrl.w_aux_clk, negedge ctrl.w_reset_n) begin : s_MuxRamReads_PROC
    if (!ctrl.w_reset_n) begin
      r_grantedRd <= #`TP E_IDLE;
      r_muxRdCh  <= #`TP '0;
    end else begin
      r_grantedRd <= #`TP s_grantedRd;
      case (s_grantedRd)
        E_IDLE : begin
          r_muxRdCh  <= #`TP '0;
        end
        E_EXTERNAL : begin
          r_muxRdCh  <= #`TP read.w_OpFetchCh;
        end
        E_CRGB : begin
          r_muxRdCh  <= #`TP crgbRd.w_reqCh;
        end
      endcase
    end
  end : s_MuxRamReads_PROC

  /*
     Driving the signal to initiate the reading process of Overlay RAM
  */
  always_ff @(posedge ctrl.w_aux_clk, negedge ctrl.w_reset_n) begin : s_settingReadProcOverlayInfo_PROC
    if (!ctrl.w_reset_n) begin
      b_ovrlRam.w_enb   <= #`TP '0;
      b_ovrlRam.w_addrb <= #`TP '0;
    end else if (r_grantedRd == E_EXTERNAL)  begin
      b_ovrlRam.w_enb   <= #`TP 'b1;
      b_ovrlRam.w_addrb <= #`TP s_fetchPointer[r_muxRdCh];
    end else if (r_grantedRd == E_CRGB)  begin
      b_ovrlRam.w_enb   <= #`TP 'b1;
      b_ovrlRam.w_addrb <= #`TP (LP_LLQ_RAM_DP_WD)'(r_fifoHead[r_muxRdCh]);
    end else begin
      b_ovrlRam.w_enb   <= #`TP '0;
      b_ovrlRam.w_addrb <= #`TP '0;
    end
  end : s_settingReadProcOverlayInfo_PROC

  /*
     Generating the signals to control the FIFO
  */
  always_comb begin : c_FifoCtrlSignals_PROC
   s_pop  = b_ovrlRam.w_validb;
   s_push = (r_grantedRd != E_IDLE);
  end : c_FifoCtrlSignals_PROC

  /*
     Concatenating the signals sent to latency fifo
  */
  always_comb begin : c_latencyDataFifoIn_PROC
    s_latData = st_latData_int'{
                  externalReq : (r_grantedRd == E_EXTERNAL)
                 ,channel     : r_muxRdCh
                 ,errors      : r_errorsLUT[r_muxRdCh]
                 ,token       : r_tokenLUT[r_muxRdCh]
                 ,stop        : r_stopLUT[r_muxRdCh]
                 ,poison      : s_poison
                 };
  end : c_latencyDataFifoIn_PROC

  /*
     FIFO to damp the latency in the reading accesses
  */
  DWC_pcie_ctl_bcm65_td
  
   #( 
     .WIDTH          ( LP_LATENCY_DAMPER_WD      )
    ,.DEPTH          ( LP_LATENCY_DAMPER_DP      )
    ,.AE_LEVEL       ( 1                         )
    ,.AF_LEVEL       ( 1                         )
    ,.ERR_MODE       ( 2                         )
    ,.RST_MODE       ( 0                         )
    ,.ADDR_WIDTH     ( LP_LATENCY_DAMPER_ADDR_WD )
    ,.REG_DELAY_TIME ( LP_REG_DELAY_TIME         )
    ,.REG_DELAY_DENOM( LP_REG_DELAY_DENOM        )
  ) u_fifo (
     .clk         ( ctrl.w_aux_clk )
    ,.rst_n       ( ctrl.w_reset_n )
    ,.init_n      ( 1'b1           )
    ,.push_req_n  ( !s_push        )
    ,.pop_req_n   ( !s_pop         )
    ,.diag_n      ( 1'b0           )
    ,.data_in     ( s_latData      )
  // SMD: Output port to an instance is not connected
  // SJ:  These ports are not used.
  // spyglass disable_block W287b
    ,.empty       (    /* NC */    )
    ,.almost_empty(    /* NC */    )
    ,.half_full   (    /* NC */    )
    ,.almost_full (    /* NC */    )
    ,.full        (    /* NC */    )
  // spyglass enable_block W287b
  // SMD: A signal or variable is set but never read.
  // SJ:  Variables used in the assertions
  // spyglass disable_block W528
    ,.error       ( s_error        )
  // spyglass enable_block W528
    ,.data_out    ( r_latData      )
    );
  
  /*
     Ungroup signals extracted from latency Fifo
  */
  always_comb begin : c_latencyDataFifoOut_PROC
    s_extFetch   = r_latData.externalReq;
    s_popAddress = r_latData.channel;
    s_errors     = r_latData.errors;
    s_token      = r_latData.token;
    s_stop       = r_latData.stop;
  end : c_latencyDataFifoOut_PROC
  
  /*
    Assigning the data received from RAM in a proper structure 
  */
  always_comb begin : c_fildsSeparationRAM_PROC
    if(((LP_LLQ_RAM_DP_WD+1)'(r_fifoHead[s_popAddress]) < (LP_LLQ_RAM_DP_WD+1)'(LP_LLQ_RAM_DP)) && ((LP_LLQ_RAM_DP_WD+1)'(s_fifoHeadLimite[s_popAddress]) <= (LP_LLQ_RAM_DP_WD+1)'(LP_LLQ_RAM_DP))) begin
      s_ramDataReceived = b_ovrlRam.w_doutb;
    end else begin
      s_ramDataReceived = '0;
    end
  end : c_fildsSeparationRAM_PROC
  
  /*
     Demuxing the data received from RAMs to the correct interface (pop or crgb)
  */
  always_ff @(posedge ctrl.w_aux_clk, negedge ctrl.w_reset_n) begin : s_deMuxRAMsData_PROC
    if (!ctrl.w_reset_n) begin
      crgbRd.w_ack             <= #`TP '0;
      crgbRd.w_glb             <= #`TP '0;
      crgbRd.w_ovrl            <= #`TP '0;
      read.w_fetchDone         <= #`TP '0;
      read.w_fetchDoneCh       <= #`TP '0;
      read.w_fetchPoisoned     <= #`TP '0;
      read.w_FetchCtxElem.glb  <= #`TP '0;
      read.w_FetchCtxElem.ovrl <= #`TP '0;
    end else if (s_extFetch && s_pop)  begin
      crgbRd.w_ack             <= #`TP '0;
      crgbRd.w_glb             <= #`TP '0;
      crgbRd.w_ovrl            <= #`TP '0;
      read.w_fetchDone         <= #`TP 'b1;
      read.w_fetchDoneCh       <= #`TP s_popAddress;
      read.w_fetchPoisoned     <= #`TP r_latData.poison;
      read.w_FetchCtxElem.glb  <= #`TP s_glbCtx[s_popAddress];
      read.w_FetchCtxElem.ovrl <= #`TP '{token: s_token, stop: s_stop, errors: s_errors, llData: s_ramDataReceived.llData, ovrlData: s_ramDataReceived.ovrlData};
    end else if (!s_extFetch && s_pop)  begin
      crgbRd.w_ack             <= #`TP 'b1;
      crgbRd.w_glb             <= #`TP s_glbCtx[s_popAddress];
      crgbRd.w_ovrl            <= #`TP '{llData: '0, ovrlData: s_ramDataReceived.ovrlData};
      read.w_fetchDone         <= #`TP '0;
      read.w_fetchDoneCh       <= #`TP '0;
      read.w_fetchPoisoned     <= #`TP '0;
      read.w_FetchCtxElem.glb  <= #`TP '0;
      read.w_FetchCtxElem.ovrl <= #`TP '0;
    end else begin
      crgbRd.w_ack             <= #`TP '0;
      crgbRd.w_glb             <= #`TP '0;
      crgbRd.w_ovrl            <= #`TP '0;
      read.w_fetchDone         <= #`TP '0;
      read.w_fetchDoneCh       <= #`TP '0;
      read.w_fetchPoisoned     <= #`TP '0;
      read.w_FetchCtxElem.glb  <= #`TP '0;
      read.w_FetchCtxElem.ovrl <= #`TP '0;
    end
  end : s_deMuxRAMsData_PROC

  /*
     Generating almost empty signal
  */
  always_comb begin : c_almostEmptySignal_PROC
    foreach(s_fifoEmpty[i]) begin
      s_fifoEmpty[i] = r_fifoDepth[i] <= r_fetchCounter[i];
    end
  end : c_almostEmptySignal_PROC
  
  /*
    Verify if a channel got an error
  */
  always_comb begin : c_errorsArray_PROC
    foreach(s_errorsLUT[i])
      s_errorsLUT[i] = (r_errorsLUT[i] != E_DMAERR_NONE);
  end : c_errorsArray_PROC
  
  /*
     Connecting the empty signals to the pop interface and generating a ready for the pop request
  */
  always_comb begin : c_readIfConnections_PROC
    read.w_slotsWithData= r_fifoDepth;
    read.w_OpFetchReady = !(s_grantedRd == E_CRGB)/* && !s_rdWrCollision*/;
    read.w_error        = s_errorsLUT | r_stopLUT;
  end : c_readIfConnections_PROC
  
  /*
     Identifying a token's push and disabling updates from the requester
  */
  always_ff @(posedge ctrl.w_aux_clk, negedge ctrl.w_reset_n) begin : s_detectingErrorToken_PROC
    if (!ctrl.w_reset_n) begin
      r_updateDisabler_n                         <= #`TP '1;
    end else if (s_grantedWr == E_EXTERNAL) begin
      case({(write.w_opMode.errors == E_ERR_SET), (write.w_opMode.errors == E_ERR_RESET)})
        2'b01:
          begin
            r_updateDisabler_n[write.w_reqCh]    <= #`TP '1;
          end
        2'b10:
          begin
            r_updateDisabler_n[write.w_reqCh]    <= #`TP '0;
          end
      endcase
    end
  end : s_detectingErrorToken_PROC
  
  /*
     If the fetchQ has received an error from Status Handler, the requests of requester related to update and erase would be ignored
  */
  always_comb begin : c_disablingRequesterAccessAfterErrorInj_PROC
    s_erase    = read.w_OpErase && (!((s_grantedWr == E_EXTERNAL) && (write.w_opMode.errors == E_ERR_SET) && (write.w_reqCh == read.w_OpEraseCh))) && (r_fifoDepth[read.w_OpEraseCh] != '0);
    s_rollback = read.w_rollback && (r_updateDisabler_n[read.w_rollbackCh] && !((s_grantedWr == E_EXTERNAL) && (write.w_opMode.errors == E_ERR_SET) && (write.w_reqCh == read.w_rollbackCh))) && (r_fetchCounter[read.w_rollbackCh] != '0);
  end : c_disablingRequesterAccessAfterErrorInj_PROC
  
  /*
     Generating an indication that head access was performed into the FIFO
  */
  always_ff @(posedge ctrl.w_aux_clk, negedge ctrl.w_reset_n) begin : s_headAccess_PROC
    if (!ctrl.w_reset_n) begin
      s_fifoHeadAccess <= #`TP '0;
    end else begin
      foreach(s_fifoHeadAccess[i])
        if(((LP_NUM_DMA_CHAN_WD'(i) == write.w_reqCh) && (s_grantedWr == E_EXTERNAL) && (write.w_opMode.target == E_TRGT_HEAD) && !write.w_ovrlHalt))
          s_fifoHeadAccess[i] <= #`TP '1;
        else
          s_fifoHeadAccess[i] <= #`TP '0;
    end
  end : s_headAccess_PROC
  
  /*
     Connecting the head access indication to the external interface
  */
  always_comb begin : c_readIfHeadAccess_PROC
    read.w_headAccess = s_fifoHeadAccess;
  end : c_readIfHeadAccess_PROC
  
// SNPS_SysML_CODE_END

endmodule
