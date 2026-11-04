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
// ---    $Revision: #10 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_stsh_monitor.sv#10 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_wack_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_chanNotify_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ctxPop_haltable_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_cdmregs_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_rvData_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_stsh_monitor
  import DWC_pcie_edmapf_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter        type P_CTX_TYPE = dmaRdEngCtx_s
  ,parameter       type P_PIPE_TYPE = stshPipeRd_s
  ,parameter                   P_BA = 0
  ,parameter                 P_CHAN = 16
  ,parameter              P_POP_LAT = 3
  ,parameter dmaEngType_e P_CHANNEL = E_WRITE
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_cdmregs_if.slave_mp         b_cdm
  ,DWC_pcie_edmapf_aclks_if.slave_mp           b_clk
  ,DWC_pcie_edmapf_ctxPop_haltable_if.slave_mp b_ctxPop
  ,DWC_pcie_edmapf_rvData_if.master_mp         b_ctxPush
  ,DWC_pcie_edmapf_chanNotify_if.slave_mp      b_doorbell
  ,DWC_pcie_edmapf_rvData_if.master_mp         b_out
  ,DWC_pcie_edmapf_wack_if.slave_mp            b_wack
  );

  // ##########################################################################
  //                              Local parameters                             
  // ##########################################################################

  localparam L_CHANWD = (P_CHAN == 1) ? 1 : $clog2(P_CHAN)                          ;


// SNPS_SysML_CODE_START
  
  typedef struct packed {
    P_PIPE_TYPE data;
    logic       valid;
  } pipe_s;

  typedef struct packed {
    P_CTX_TYPE data;
    logic      valid;
  } context_s;

  typedef struct packed {
    logic flushBit;
  } statusLut_s;

  typedef struct packed {
    logic [31:0]      xferSize       ;
    logic [63:0]      sar            ;
    logic [63:0]      dar            ;
  } tlpData_s ;

  logic     s_ctxMerged_ready       ;
  logic     s_ctxUpdated_ready      ;
  logic     s_ctxFiltered_ready     ;
  logic     s_ctxTokenized_ready    ;
  logic     s_pipeTransformed_ready ;
  logic     w_xferSizeCalcHalt      ;
  logic     w_xferSizeCalcValid     ;
  tlpData_s w_xferSizeCalcData      ;

  // SMD: Not all bits of a bus are set.
  // SJ:  All bits are properly set.
  // spyglass disable_block W497
  struct packed {
    statusLut_s [P_CHAN-1:0] statusLut      ;
    context_s                ctxMerged      ;
    context_s                ctxUpdated     ;
    context_s                ctxFiltered    ;
    context_s                ctxTokenized   ;
    pipe_s                   pipeTransformed;
  } r,s;
  // spyglass enable_block W497

  /*
  * r register.
  */
  always_ff @(posedge b_clk.w_aux_clk, negedge b_clk.w_reset_n) begin : r_PROC
    if (!b_clk.w_reset_n) begin
      r <= #`TP 0;
    end else begin
      r <= #`TP s;
    end
  end : r_PROC

  function automatic P_CTX_TYPE f_ctxMerge(input P_CTX_TYPE ctx, input logic error);
    f_ctxMerge = ctx;
  // SMD: Reports hierarchical references that are not synthesizable.
  // SJ:  The Spyglass cannot identify the type propagated by the parameter. It's a tool issue.
  // spyglass disable_block W239
    //f_ctxMerge.ctx.ovrl.errors.commonErr.app_err |= error;
    if (error) begin
      f_ctxMerge.ctx.ovrl.errors = E_DMAERR_DATA_MWR;
    end else begin
      f_ctxMerge.ctx.ovrl.errors = ctx.ctx.ovrl.errors;
    end
  // spyglass enable_block W239
  return f_ctxMerge;
  endfunction

  function automatic P_CTX_TYPE f_ctxUpdate(input P_CTX_TYPE ctx, input tlpData_s updated);
  // SMD: Reports hierarchical references that are not synthesizable.
  // SJ:  The Spyglass cannot identify the type propagated by the parameter. It's a tool issue.
  // spyglass disable_block W239
    f_ctxUpdate = ctx;
    if ((ctx.ctx.ovrl.ovrlData.xferSize != '0) && !(|ctx.ctx.ovrl.errors) && !ctx.ctx.ovrl.stop) begin
      f_ctxUpdate.ctx.ovrl.ovrlData.xferSize = updated.xferSize;
      {f_ctxUpdate.ctx.ovrl.ovrlData.sarHigh,f_ctxUpdate.ctx.ovrl.ovrlData.sarLow} = updated.sar;
      {f_ctxUpdate.ctx.ovrl.ovrlData.darHigh,f_ctxUpdate.ctx.ovrl.ovrlData.darLow} = updated.dar;
    end
  // spyglass enable_block W239
    return f_ctxUpdate;
  endfunction

  function automatic logic f_ctxFilterValid(input P_CTX_TYPE ctx, input statusLut_s [P_CHAN-1:0] statusLut);
    logic tokenBit ;
    logic stopBit  ;
    logic flushBit ;
    logic llErrBit ;
  // SMD: Reports hierarchical references that are not synthesizable.
  // SJ:  The Spyglass cannot identify the type propagated by the parameter. It's a tool issue.
  // spyglass disable_block W239
    tokenBit = ctx.ctx.ovrl.token;
    stopBit  = ctx.ctx.ovrl.stop;
    flushBit = statusLut[ctx.channel].flushBit;
    llErrBit = ctx.ctx.ovrl.errors inside {E_DMAERR_LL_CPL_UR, E_DMAERR_LL_CPL_CA, E_DMAERR_LL_CPL_EP};
  // spyglass enable_block W239
    f_ctxFilterValid = tokenBit && !(llErrBit && !stopBit) || !flushBit;
    return f_ctxFilterValid;
  endfunction

  function automatic P_CTX_TYPE f_ctxTokenize(input P_CTX_TYPE ctx);
    f_ctxTokenize = ctx;
  // SMD: Reports hierarchical references that are not synthesizable.
  // SJ:  The Spyglass cannot identify the type propagated by the parameter. It's a tool issue.
  // spyglass disable_block W239
    f_ctxTokenize.ctx.ovrl.token = '1;
  // spyglass enable_block W239
    return f_ctxTokenize;
  endfunction

  function automatic logic f_ctxTokenizeValid(input P_CTX_TYPE ctx);
    f_ctxTokenizeValid = '0;
  // SMD: Reports hierarchical references that are not synthesizable.
  // SJ:  The Spyglass cannot identify the type propagated by the parameter. It's a tool issue.
  // spyglass disable_block W239
    if (!ctx.ctx.ovrl.token) begin
      if (|ctx.ctx.ovrl.errors) begin
        f_ctxTokenizeValid = '1;
      end
      if (ctx.ctx.ovrl.stop) begin
        f_ctxTokenizeValid = '1;
      end
      if (ctx.ctx.ovrl.ovrlData.xferSize == '0) begin
        f_ctxTokenizeValid = '1;
      end
    end
  // spyglass enable_block W239
    return f_ctxTokenizeValid;
  endfunction

  function automatic P_PIPE_TYPE f_ctxTransform(input P_CTX_TYPE ctx);
    f_ctxTransform = '0;
  // SMD: Reports hierarchical references that are not synthesizable.
  // SJ:  The Spyglass cannot identify the type propagated by the parameter. It's a tool issue.
  // spyglass disable_block W239
    f_ctxTransform.channel = ctx.channel;
    f_ctxTransform.globalCtx = ctx.ctx.glb;
    f_ctxTransform.watermarkEn = ctx.ctx.ovrl.ovrlData.watermarkEn;
    f_ctxTransform.interrupts.errors = ctx.ctx.ovrl.errors;
    f_ctxTransform.interrupts.chStatus = E_CS_RUNNING;
    if (ctx.ctx.ovrl.token) begin
      if (|ctx.ctx.ovrl.errors) begin
        f_ctxTransform.interrupts.pins.abort = '1;
        f_ctxTransform.interrupts.chStatus = E_CS_ABORTED;
      end else begin
        f_ctxTransform.interrupts.pins.stop = '1;
        f_ctxTransform.interrupts.chStatus = E_CS_STOPED;
      end
    end else if (ctx.ctx.glb.ll_en) begin
      f_ctxTransform.interrupts.pins.watermark = (ctx.ctx.ovrl.ovrlData.xferSize == '0);
    end
  // spyglass enable_block W239
    return f_ctxTransform;
  endfunction

  function automatic logic f_ctxTransformValid(input P_CTX_TYPE ctx);
    f_ctxTransformValid = '0;
  // SMD: Reports hierarchical references that are not synthesizable.
  // SJ:  The Spyglass cannot identify the type propagated by the parameter. It's a tool issue.
  // spyglass disable_block W239
    if (ctx.ctx.ovrl.token) begin
        f_ctxTransformValid = '1;// ABORT or STOP
    end else if (ctx.ctx.glb.ll_en) begin
      if ((ctx.ctx.ovrl.ovrlData.xferSize == '0) && !ctx.ctx.ovrl.stop) begin
        f_ctxTransformValid = '1;// WATERMARK
      end
    end
  // spyglass enable_block W239
    return f_ctxTransformValid;
  endfunction
  
  logic      s_wrespFifo_push_req_n ;
  logic      s_wrespFifo_pop_req_n  ;
  logic      s_wrespFifo_data_in    ;
  logic      w_wrespFifo_full       ;
  logic      w_wrespFifo_data_out   ;

  logic      s_delayFifo_push_req_n ;
  logic      s_delayFifo_pop_req_n  ;
  P_CTX_TYPE s_delayFifo_data_in    ;
  P_CTX_TYPE w_delayFifo_data_out   ;

  localparam integer LP_REG_DELAY_DENOM  = 1000;
  localparam integer LP_REG_DELAY_TIME   = `TP * LP_REG_DELAY_DENOM;

 DWC_pcie_ctl_bcm65_td
   #( //Synchronous (Single Clock) FIFO with Static Flags
     .WIDTH           ( 1                      )
    ,.DEPTH           ( P_POP_LAT              )//cloakroom + damper latency
    ,.AE_LEVEL        ( 1                      )//do not care about this
    ,.AF_LEVEL        ( 1                      )//do not care about this
    ,.ERR_MODE        ( 2                      )//underflow/overflow latched checking
    ,.RST_MODE        ( 0                      )//asynchronous reset excluding memory
    ,.ADDR_WIDTH      ( $clog2(P_POP_LAT)      )//$clog2(DEPTH)
    ,.REG_DELAY_TIME  ( LP_REG_DELAY_TIME      )
    ,.REG_DELAY_DENOM ( LP_REG_DELAY_DENOM     )
  )
  u_wrespFifo(
     .clk             ( b_clk.w_main_clk       )
    ,.rst_n           ( b_clk.w_reset_n        )
    ,.init_n          ( 1'b1                   )
    ,.push_req_n      ( s_wrespFifo_push_req_n )
    ,.pop_req_n       ( s_wrespFifo_pop_req_n  )
    ,.data_in         ( s_wrespFifo_data_in    )
    ,.full            ( w_wrespFifo_full       )
    ,.data_out        ( w_wrespFifo_data_out   )
    ,.diag_n          ( 1'b0                   )
    // SMD: Output port to an instance is not connected
    // SJ:  These ports are not used.
    // spyglass disable_block W287b
    ,.empty           ( /* NC */               )
    ,.almost_empty    ( /* NC */               )
    ,.half_full       ( /* NC */               )
    ,.almost_full     ( /* NC */               )
    ,.error           ( /* NC */               )
    // spyglass enable_block W287b
    );


  assign s_wrespFifo_push_req_n = b_wack.w_halt || !b_wack.w_valid;
  assign s_wrespFifo_pop_req_n  = b_ctxPop.w_halt || !b_ctxPop.w_valid;
  assign s_wrespFifo_data_in    = b_wack.w_error;
  
  localparam L_XFERSIZECALC_LAT = 3;

  DWC_pcie_ctl_bcm65_td
    #( //Synchronous (Single Clock) FIFO with Static Flags
     .WIDTH           ( $bits(P_CTX_TYPE)          )
    ,.DEPTH           ( L_XFERSIZECALC_LAT         )
    ,.AE_LEVEL        ( 1                          )
    ,.AF_LEVEL        ( 1                          )
    ,.ERR_MODE        ( 2                          )
    ,.RST_MODE        ( 0                          )
    ,.ADDR_WIDTH      ( $clog2(L_XFERSIZECALC_LAT) )
    ,.REG_DELAY_TIME  ( LP_REG_DELAY_TIME          )
    ,.REG_DELAY_DENOM ( LP_REG_DELAY_DENOM         )
    )
    u_delayFifo(
       .clk           ( b_clk.w_main_clk           )
      ,.rst_n         ( b_clk.w_reset_n            )
      ,.init_n        ( 1'b1                       )
      ,.push_req_n    ( s_delayFifo_push_req_n     )
      ,.pop_req_n     ( s_delayFifo_pop_req_n      )
      ,.data_in       ( s_delayFifo_data_in        )
      ,.data_out      ( w_delayFifo_data_out       )
        ,.diag_n      ( 1'b0                       )
      // SMD: Output port to an instance is not connected
      // SJ:  These ports are not used.
      // spyglass disable_block W287b
      ,.almost_empty  ( /* NC */                   )
      ,.half_full     ( /* NC */                   )
      ,.almost_full   ( /* NC */                   )
      ,.error         ( /* NC */                   )
      ,.full          ( /* NC */                   )
      ,.empty         ( /* NC */                   )
      // spyglass enable_block W287b
      );


  assign s_delayFifo_push_req_n = !r.ctxMerged.valid || w_xferSizeCalcHalt;
  assign s_delayFifo_pop_req_n  = !(w_xferSizeCalcValid && s_ctxUpdated_ready);
  assign s_delayFifo_data_in    = r.ctxMerged.data;

  assign b_ctxPop.w_halt = !s_ctxMerged_ready ;
  assign b_ctxPop.w_pop  = !s_wrespFifo_push_req_n;
  assign b_ctxPop.w_tag  = b_wack.w_tag;
  assign b_wack.w_halt   = w_wrespFifo_full;

  assign s_ctxMerged_ready = !r.ctxMerged.valid || !w_xferSizeCalcHalt;
  always_comb begin : ctxMerged_PROC
    if (s_ctxMerged_ready) begin
      s.ctxMerged.data  = f_ctxMerge(b_ctxPop.w_data, w_wrespFifo_data_out);
      s.ctxMerged.valid = b_ctxPop.w_valid;
    end else begin
      s.ctxMerged = r.ctxMerged;
    end
  end

  assign s_ctxUpdated_ready = !r.ctxUpdated.valid || s_ctxFiltered_ready;
  always_comb begin : ctxUpdated_PROC
    if (s_ctxUpdated_ready) begin
      s.ctxUpdated.data  = f_ctxUpdate(w_delayFifo_data_out, w_xferSizeCalcData);
      s.ctxUpdated.valid = w_xferSizeCalcValid ; 
    end else begin
      s.ctxUpdated = r.ctxUpdated;
    end
  end

  assign s_ctxFiltered_ready = !r.ctxFiltered.valid || (s_ctxTokenized_ready && s_pipeTransformed_ready);
  always_comb begin : ctxFiltered_PROC
    if (s_ctxFiltered_ready) begin
      s.ctxFiltered.data  = r.ctxUpdated.data;
      s.ctxFiltered.valid = r.ctxUpdated.valid && f_ctxFilterValid(r.ctxUpdated.data,r.statusLut);
    end else begin
      s.ctxFiltered = r.ctxFiltered;
    end
  end

  assign s_ctxTokenized_ready = !r.ctxTokenized.valid || b_ctxPush.w_ready;
  always_comb begin : ctxTokenized_PROC
    if (s_ctxTokenized_ready) begin
      s.ctxTokenized.data  = f_ctxTokenize(r.ctxFiltered.data);
      s.ctxTokenized.valid = r.ctxFiltered.valid && f_ctxTokenizeValid(r.ctxFiltered.data) && s_pipeTransformed_ready;
    end else begin
      s.ctxTokenized = r.ctxTokenized;
    end
  end

  assign s_pipeTransformed_ready = !r.pipeTransformed.valid || b_out.w_ready;
  always_comb begin : ctxTransformed_PROC
    if (s_pipeTransformed_ready) begin
      s.pipeTransformed.data  = f_ctxTransform(r.ctxFiltered.data);
      s.pipeTransformed.valid = r.ctxFiltered.valid && f_ctxTransformValid(r.ctxFiltered.data) && s_ctxTokenized_ready;
    end else begin
      s.pipeTransformed = r.pipeTransformed;
    end
  end

  DWC_pcie_edmapf_tlpFetchSize
   #(
     .P_CHANNEL    ( P_CHANNEL                                                                              )
    ) u_xferSizeCalc(
       .b_cdm      ( b_cdm                                                                                  )
      ,.b_clk      ( b_clk                                                                                  )
      ,.i_reqValid ( r.ctxMerged.valid                                                                      )
      ,.i_reqPF    ( r.ctxMerged.data.ctx.glb.tlpSettings.d_pf                                              )
      ,.i_reqSize  ( r.ctxMerged.data.ctx.ovrl.ovrlData.xferSize                                            )
      ,.i_reqSAR   ( {r.ctxMerged.data.ctx.ovrl.ovrlData.sarHigh,r.ctxMerged.data.ctx.ovrl.ovrlData.sarLow} )
      ,.i_reqDAR   ( {r.ctxMerged.data.ctx.ovrl.ovrlData.darHigh,r.ctxMerged.data.ctx.ovrl.ovrlData.darLow} )
      ,.o_reqHalt  ( w_xferSizeCalcHalt                                                                     )
      ,.i_tlpHalt  ( !s_ctxUpdated_ready                                                                    )
      ,.o_tlpValid ( w_xferSizeCalcValid                                                                    )
      ,.o_tlpSize  ( w_xferSizeCalcData.xferSize                                                            )
      ,.o_tlpSAR   ( w_xferSizeCalcData.sar                                                                 )
      ,.o_tlpDAR   ( w_xferSizeCalcData.dar                                                                 )
      );


  always_comb begin : statusLut_PROC
    int i;
    s.statusLut = r.statusLut;
    for (i = 0; i < (P_CHAN-1-0+1); i += 1) begin 
      if (s_ctxFiltered_ready && r.ctxUpdated.valid && r.ctxUpdated.data.channel == i) begin
        if (r.ctxUpdated.data.ctx.ovrl.token) begin
          s.statusLut[i].flushBit = '0;
        end else if (|r.ctxUpdated.data.ctx.ovrl.errors) begin
          s.statusLut[i].flushBit = '1;
        end 
      end
    end
  end

  assign b_ctxPush.w_valid = r.ctxTokenized.valid ;
  assign b_ctxPush.w_data = r.ctxTokenized.data;

  assign b_out.w_valid = r.pipeTransformed.valid ;
  assign b_out.w_data = r.pipeTransformed.data;
 

// SNPS_SysML_CODE_END

endmodule
