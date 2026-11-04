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
// ---    $Revision: #7 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_fetchQ_pop.sv#7 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_llq_pop_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_llq_popInternal_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_llq_popUpdate_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_fetchQ_pop
  import DWC_pcie_edmapf_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter CC_NUM_DMA_CHAN = `CC_NUM_DMA_WR_CHAN
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_aclks_if.slave_mp           ctrl
  ,DWC_pcie_edmapf_llq_pop_if.master_mp        pop
  ,DWC_pcie_edmapf_llq_popInternal_if.slave_mp popInt
  ,DWC_pcie_edmapf_llq_popUpdate_if.slave_mp   popUp
  );


// SNPS_SysML_CODE_START
  /*
    Local parameters
  */
  localparam LP_NUM_DMA_CHAN_WD = CC_NUM_DMA_CHAN > 1 ? $clog2(CC_NUM_DMA_CHAN) : 1;
  /*
    The structure was created to eliminate the dependency between valid and ready on the interfaces
  */
  struct packed {
    logic                          valid;
    logic [LP_NUM_DMA_CHAN_WD-1:0] data;
  } r_head, s_head, r_tail, s_tail;
  /*
    Signals used to store all signals in the connection between the interfaces
  */
  logic                       s_headUpdate;
  logic                       s_headValid;
  logic                       s_tailUpdate;
  logic                       s_tailValid;
  logic                       s_tailClean;
  /*
     Internal back pressure signal declaration
  */
  logic [CC_NUM_DMA_CHAN-1:0] s_backPressurePopUp;
  logic [CC_NUM_DMA_CHAN-1:0] r_backPressurePopUp;
  
  /*
    Connections between different interfaces
  */
  always_comb begin : c_interfacesConnections_PROC
    pop.w_UpdateRdy       = !popUp.w_OpUpdate;
    popInt.w_OpErase      = pop.w_OpErase;
    popInt.w_OpEraseCh    = pop.w_OpEraseCh;
    popInt.w_rollbackCh   = pop.w_rollbackCh;
    popInt.w_rollback     = pop.w_rollback;
    popInt.w_OpFetch      = r_head.valid;
    pop.w_OpFetchReady    = {CC_NUM_DMA_CHAN{!s_tailValid}} & ~r_backPressurePopUp;
    popInt.w_OpFetchCh    = r_head.data;
    pop.w_slotsWithData   = popInt.w_slotsWithData;
    pop.w_fetchDone       = popInt.w_fetchDone;
    pop.w_fetchDoneCh     = popInt.w_fetchDoneCh;
    pop.w_fetchPoisoned   = popInt.w_fetchPoisoned;
    pop.w_FetchCtxElem    = popInt.w_FetchCtxElem;
    pop.w_error           = popInt.w_error;
  end : c_interfacesConnections_PROC
  
  /*
    Monitoring the popUp access creating a back pressure the pop interface
  */
  always_comb begin : c_backPressurePopUp_PROC
    foreach(r_backPressurePopUp[i])
      case({popInt.w_headAccess[i], ((LP_NUM_DMA_CHAN_WD'(i) == pop.w_OpUpdateCh) && pop.w_OpUpdate && (popInt.w_slotsWithData[i] == '0))})
        2'b01:
          s_backPressurePopUp[i] = '1;
        2'b10:
          s_backPressurePopUp[i] = '0;
        default:
          s_backPressurePopUp[i] = r_backPressurePopUp[i];
      endcase
  end : c_backPressurePopUp_PROC
  
  /*
    Registering the back pressure signal
  */
  always_ff @(posedge ctrl.w_main_clk, negedge ctrl.w_reset_n) begin : s_backPressurePopUp_PROC
    if (!ctrl.w_reset_n) begin
      r_backPressurePopUp <= #`TP '0;
    end else begin
      r_backPressurePopUp <= #`TP s_backPressurePopUp;
    end
  end : s_backPressurePopUp_PROC
  
  /*
    Storing the Update interface
  */
  always_ff @(posedge ctrl.w_main_clk, negedge ctrl.w_reset_n) begin : s_storingInterface_PROC
    if (!ctrl.w_reset_n) begin
      popUp.w_OpUpdateCh    <= #`TP '0;
      popUp.w_OpUpdate      <= #`TP '0;
      popUp.w_UpdateCtxElem <= #`TP '0;
    end else if(popUp.w_UpdateRdy || (!popUp.w_UpdateRdy && !popUp.w_OpUpdate)) begin
      popUp.w_OpUpdateCh    <= #`TP pop.w_OpUpdateCh;
      popUp.w_OpUpdate      <= #`TP pop.w_OpUpdate;
      popUp.w_UpdateCtxElem <= #`TP pop.w_UpdateCtxElem;
    end
  end : s_storingInterface_PROC

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
    s_headUpdate = !s_headValid || popInt.w_OpFetchReady;
  end : c_headUpdate_PROC
  
  /*
    Managing the data to be stored into the head
  */
  always_comb begin : c_firstStoringBank_PROC
    if (s_headUpdate) begin
      if (!s_tailValid) begin
        s_head.data   = pop.w_OpFetchCh;
        s_head.valid  = pop.w_OpFetch && !(r_backPressurePopUp[pop.w_OpFetchCh]);
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
    s_tailUpdate  = s_headValid && (s_tailValid || !popInt.w_OpFetchReady) && (!s_tailValid || popInt.w_OpFetchReady);
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
    s_tailClean   = popInt.w_OpFetchReady;
  end : c_tailClean_PROC
  
  /*
    Managing the data to be stored into the tail
  */
  always_comb begin : c_secondStoringBank_PROC
    if (s_tailClean) begin
      s_tail = '0;
    end else if (s_tailUpdate) begin
      s_tail.data   = pop.w_OpFetchCh;
      s_tail.valid  = pop.w_OpFetch && !(r_backPressurePopUp[pop.w_OpFetchCh]);
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

// SNPS_SysML_CODE_END

endmodule
