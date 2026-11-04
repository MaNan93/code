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
// ---    $DateTime: 2024/01/12 11:11:14 $ 
// ---    $Revision: #17 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_ll_hub.sv#17 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_llq_push_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_readyValid_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_llq_fslots_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ChRegfile_DB_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_HubDbOp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_genericData_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_rvOpData_if.svh"
// SNPS_SysML_CODE_START
`include "Edmapf/svif/DWC_pcie_edmapf_rvData_if.svh"
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_ll_hub
  import DWC_pcie_edmapf_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter type P_CTXPIPE_TYPE = logic
  ,parameter     type P_CTX_TYPE = logic
  ,parameter       type P_OPTYPE = llPushOp_e
  ,parameter     CX_NUM_DMA_CHAN = `CX_NUM_DMA_WR_CHAN
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_ChRegfile_DB_if.master_mp b_ChStop
  ,DWC_pcie_edmapf_genericData_if.master_mp  b_HubDbErr
  ,DWC_pcie_edmapf_readyValid_if.master_mp   b_PushLLCtx
  ,DWC_pcie_edmapf_aclks_if.slave_mp         b_clk
  ,DWC_pcie_edmapf_HubDbOp_if.master_mp      b_llHubNtfy
  ,DWC_pcie_edmapf_readyValid_if.slave_mp    b_ll_push
  ,DWC_pcie_edmapf_readyValid_if.slave_mp    b_non_ll_push
  ,DWC_pcie_edmapf_llq_push_if.master_mp     b_opush
  ,DWC_pcie_edmapf_llq_fslots_if.slave_mp    b_slotsReport
  ,DWC_pcie_edmapf_rvOpData_if.slave_mp      b_token_push
  );


// SNPS_SysML_CODE_START
  localparam integer LP_NUM_DMA_CHAN_WD = (CX_NUM_DMA_CHAN==1) ? 1: $clog2(CX_NUM_DMA_CHAN);

  typedef struct packed {
    P_CTX_TYPE                     ctxElem;
    llPushOp_e                     pushOp;
    logic [LP_NUM_DMA_CHAN_WD-1:0] reqCh;
  } llq_push_s;


  DWC_pcie_edmapf_llq_push_if #(
     .CC_NUM_DMA_CHAN_WIDTH(LP_NUM_DMA_CHAN_WD)
    ,.P_CTX_TYPE           (P_CTX_TYPE)
  ) opush (); 
 

  DWC_pcie_edmapf_readyValid_if #(
    .P_DATATYPE(llq_push_s)
  ) rv_opush (); 


  DWC_pcie_edmapf_readyValid_if #(
    .P_DATATYPE(llq_push_s)
  ) rv_b_opush (); 
 
  bool_e s_tcb;
  bool_e s_llp;

  typedef struct packed {
    logic [2:0] osel    ; // output arbiter selection
    logic [2:0] ireq    ; // input request 
    logic       ireq_en ; // input  enable
    logic       ogrant  ; // output arbiter granted
  } arb_fq_s;  // fetch queue arbiter

  arb_fq_s arb_fq;
 
  typedef struct packed {
    logic [1:0] osel    ; // output arbiter selection
    logic [1:0] ireq    ; // input request 
    logic       ireq_en ; // input  enable
    logic       ogrant  ; // output arbiter granted
  } arb_llctx_s;  // LL context arbiter 

  arb_llctx_s arb_llctx;


  // *************************************************************************
  // Queues Status Handler's reporting into a FetchQ queue and LL fetch Queue
  // *************************************************************************
  localparam integer LP_REG_DELAY_DENOM  = 1000;
  localparam integer LP_REG_DELAY_TIME   = `TP * LP_REG_DELAY_DENOM;
  localparam integer LP_FDEPTH           = 2;
  localparam integer LP_FDEPTH_LOG2      = $clog2(LP_FDEPTH);
  localparam integer LP_FWIDTH           = $bits(P_CTXPIPE_TYPE);
  localparam integer LP_FQWIDTH          = LP_FWIDTH + $bits(P_OPTYPE);

  logic nc_LLalmost_empty, nc_FQalmost_empty;
  logic nc_LLhalf_full   , nc_FQhalf_full   ;
  logic nc_LLalmost_full , nc_FQalmost_full ;
  logic LLfull           , FQfull           ;
  logic LLempty          , FQempty          ;
  logic LLpop_req_n      , FQpop_req_n      ;
  logic nc_LLerror       , nc_FQerror       ;           
  logic LLpush_req_n     , FQpush_req_n     ;


  DWC_pcie_edmapf_rvData_if #(
     .P_DATATYPE(P_CTXPIPE_TYPE)
                    )         ll_token_push ();   

  DWC_pcie_edmapf_rvOpData_if #(
     .P_DATATYPE(P_CTXPIPE_TYPE)
    ,.P_OPTYPE  (P_OPTYPE)
                    )         fq_stsh_push ();   
 
  DWC_pcie_ctl_bcm65_td
   #(
    .WIDTH          (LP_FWIDTH         ),
    .DEPTH          (LP_FDEPTH         ),
    .AE_LEVEL       (1                 ),
    .AF_LEVEL       (1                 ),
    .ERR_MODE       (2                 ),
    .RST_MODE       (0                 ),
    .ADDR_WIDTH     (LP_FDEPTH_LOG2    ),
    .REG_DELAY_TIME (LP_REG_DELAY_TIME ),
    .REG_DELAY_DENOM(LP_REG_DELAY_DENOM)
  )u_fifo_ll (
    .clk         (b_clk.w_main_clk     ),
    .rst_n       (b_clk.w_reset_n      ),
    .init_n      (1'b1                 ),
    .push_req_n  (LLpush_req_n         ),
    .pop_req_n   (LLpop_req_n          ),
      .diag_n      (1'b0               ),
    .data_in     (b_token_push.w_data),
    .empty       (LLempty),
    // SMD: A signal or variable is set but never read  
    // SJ:  BCM output signals not required by the logic
    // spyglass disable_block W528
    .almost_empty(nc_LLalmost_empty    ),
    .half_full   (nc_LLhalf_full       ),
    .almost_full (nc_LLalmost_full     ),
    .error       (nc_LLerror           ),
    // spyglass enable_block W528
    .full        (LLfull),
    .data_out    (ll_token_push.w_data  )
  );      

  DWC_pcie_ctl_bcm65_td
   #(
    .WIDTH          (LP_FQWIDTH        ),
    .DEPTH          (LP_FDEPTH         ),
    .AE_LEVEL       (1                 ),
    .AF_LEVEL       (1                 ),
    .ERR_MODE       (2                 ),
    .RST_MODE       (0                 ),
    .ADDR_WIDTH     (LP_FDEPTH_LOG2    ),
    .REG_DELAY_TIME (LP_REG_DELAY_TIME ),
    .REG_DELAY_DENOM(LP_REG_DELAY_DENOM)
  )u_fifo_fq (
    .clk         (b_clk.w_main_clk     ),
    .rst_n       (b_clk.w_reset_n      ),
    .init_n      (1'b1                 ),
    .push_req_n  (FQpush_req_n         ),
    .pop_req_n   (FQpop_req_n          ),
      .diag_n      (1'b0               ),
    .data_in     ({b_token_push.w_validOp, b_token_push.w_data}),
    .empty       (FQempty              ),
    // SMD: A signal or variable is set but never read  
    // SJ:  BCM output signals not required by the logic
    // spyglass disable_block W528
    .almost_empty(nc_FQalmost_empty    ),
    .half_full   (nc_FQhalf_full       ),
    .almost_full (nc_FQalmost_full     ),
    .error       (nc_FQerror           ),
    // spyglass enable_block W528
    .full        (FQfull),
    .data_out    ({fq_stsh_push.w_validOp, fq_stsh_push.w_data})
  );      
  assign b_token_push.w_ready = !FQfull && !LLfull;
  assign LLpush_req_n =  !(b_token_push.w_ready && b_token_push.w_valid);
  assign FQpush_req_n  =  !(b_token_push.w_ready && b_token_push.w_valid && (b_token_push.w_validOp != E_STSH_LL));

  // When the stshandler pushes in a token with errors in LL, do not push to LL RAM,
  // this was already rolled back when the descriptor was received
  assign ll_token_push.w_valid = !LLempty;
  assign fq_stsh_push.w_valid = !FQempty;
  assign LLpop_req_n = !(ll_token_push.w_valid && ll_token_push.w_ready) || LLempty;
  assign FQpop_req_n = !(fq_stsh_push.w_valid && fq_stsh_push.w_ready);
 

  // *************************************************************************
  //  FetchQ arbiter
  // *************************************************************************
  // End of transfer token is received on b_token_push from Doorbell Manager
  // that also drives the token to LL Ctrl. The LL Ctrl issues a NULL RD
  // request whereas LL HUB writes the token imediately into the FetchQ
  // through opush interface. Thus, opush is being competed by ll_push,
  // non_ll_push and b_token_push. ll_push, non_ll_push request are arbitered
  // by a round-robin algorith whereas b_token_push is strict priority to
  // guarantee that the responses to NULL RD are not processed before the
  // token.
  // *************************************************************************

  logic  route_ll_push2PushLLCtx;
  assign arb_fq.ireq_en =  fq_stsh_push.w_valid || &{b_ll_push.w_valid,!route_ll_push2PushLLCtx} || b_non_ll_push.w_valid;
  assign arb_fq.ireq    = {fq_stsh_push.w_valid,   &{b_ll_push.w_valid,!route_ll_push2PushLLCtx},   b_non_ll_push.w_valid};

   DWC_pcie_ctl_bcm55
    #(
     .N           ( 3             ) // Source count
    ,.OUTPUT_MODE ( 0             ) // Registered outputs
    ,.INDEX_WIDTH ( 2             ) // $clog2(N)
   )
   u_fq_arb(
     .clk         ( b_clk.w_main_clk)
    ,.rst_n       ( b_clk.w_reset_n )
    ,.init_n      ( 1'b1            )
    ,.mask        ( 3'b000          )
    ,.enable      ( arb_fq.ireq_en  )
    ,.request     ( arb_fq.ireq     )
    ,.grant       ( arb_fq.osel     )
    ,.granted     ( arb_fq.ogrant   )
    // SMD: Output port to an instance is not connected
    // SJ:  These ports are not used.
    // spyglass disable_block W287b
    ,.grant_index ( /* NC */        )
    // spyglass enable_block W287b
  );


   // *************************************************************************
   //  Context LL  arbiter (LL RAM)
   // *************************************************************************
   logic [CX_NUM_DMA_CHAN-1:0] r_ll_flush, s_ll_flush, r_llp_flush, s_llp_flush, r_db_error_flush, s_db_error_flush, s_db_stop;
   assign s_db_stop = b_llHubNtfy.w_db_stop;
   assign route_ll_push2PushLLCtx = (b_ll_push.w_valid && (r_ll_flush[b_ll_push.w_data.reqCh] || b_ll_push.w_data.flush || b_ll_push.w_data.ElemOvrl_LLP) && b_ll_push.w_data.last) && !r_db_error_flush[b_ll_push.w_data.reqCh] && !r_llp_flush[b_ll_push.w_data.reqCh] && !s_db_stop[b_ll_push.w_data.reqCh];

   logic  route_token2PushLLCtx;
   // See description in "ll_token_push.w_ready driver"
   assign route_token2PushLLCtx = ll_token_push.w_valid && ll_token_push.w_data.ctx.glb.ll_en && |{ll_token_push.w_data.ctx.ovrl.ovrlData.watermarkEn, ll_token_push.w_data.ctx.ovrl.errors, ll_token_push.w_data.ctx.ovrl.stop};

   assign arb_llctx.ireq_en = route_ll_push2PushLLCtx || route_token2PushLLCtx; 
   assign arb_llctx.ireq    = {route_ll_push2PushLLCtx, route_token2PushLLCtx};

   DWC_pcie_ctl_bcm55
    #(
     .N           ( 2             ) // Source count
    ,.OUTPUT_MODE ( 0             ) // Registered outputs
    ,.INDEX_WIDTH ( 2             ) // $clog2(N)
   )
   u_llctx_arb(
     .clk         ( b_clk.w_main_clk )
    ,.rst_n       ( b_clk.w_reset_n  )
    ,.init_n      ( 1'b1             )
    ,.mask        ( 2'b00            )
    ,.enable      ( arb_llctx.ireq_en)
    ,.request     ( arb_llctx.ireq   )
    ,.grant       ( arb_llctx.osel   )
    ,.granted     ( arb_llctx.ogrant )
    // SMD: Output port to an instance is not connected
    // SJ:  These ports are not used.
    // spyglass disable_block W287b
    ,.grant_index ( /* NC */         )
    // spyglass enable_block W287b
  );

 // *************************************************************************
  // LL Descriptor fetch flush on the following conditions
  // 1- cb != CCS and not LLP pointer
  // 2- Linked list pointer
  //     When the outstanding descriptors reaches zero DB MNGR clears flush
  // 3- Linked list returned with an error
  // 4- Status Handler returns an error
  // *************************************************************************

  always_ff @ (posedge b_clk.w_main_clk or negedge b_clk.w_reset_n) begin : PROC_FF_ll_flush
    if (!b_clk.w_reset_n) begin
      r_ll_flush       <= # `TP '0;
      r_llp_flush      <= # `TP '0;
      r_db_error_flush <= # `TP '0;
    end else begin
      r_ll_flush       <= # `TP s_ll_flush;
      r_llp_flush      <= # `TP s_llp_flush;
      r_db_error_flush <= # `TP s_db_error_flush;
    end
  end

  always_comb begin : PROC_CB_ll_flush
    s_ll_flush = r_ll_flush;

    foreach (s_ll_flush[i]) begin
      if (b_ll_push.w_valid && (i == b_ll_push.w_data.reqCh) && b_ll_push.w_data.flush)
        s_ll_flush[i] = '1;
      if (opush.w_push && (opush.w_pushOp == E_ERR_TOKEN) && (opush.w_reqCh==i) && opush.w_pushRdy) 
        s_ll_flush[i] = '1;
      //if (b_llHubNtfy.w_db_stop[i])
      //  s_ll_flush[i] = '1;
      if (b_llHubNtfy.w_llDescFlushClr[i])
        s_ll_flush[i] = '0;
    end
  end

  //When flushing just push into LL ram once
  always_comb begin : PROC_CB_llp_flush
    s_llp_flush = r_llp_flush;

    foreach (s_llp_flush[i]) begin
      //note: the LL pushes are always not tokens, flushing LP only happens from LL processing
      if (b_PushLLCtx.w_valid && b_PushLLCtx.w_ready && !b_PushLLCtx.w_data.ctxElem.ovrl.token && (b_PushLLCtx.w_data.reqCh == i) && (r_ll_flush[i] || b_PushLLCtx.w_data.flush))
        s_llp_flush[i] = '1;
      if (b_llHubNtfy.w_llDescFlushClr[i])
        s_llp_flush[i] = '0; 
    end
  end

  always_comb begin : PROC_CB_APP_ERR_FLUSH
    s_db_error_flush = r_db_error_flush;
    foreach(s_db_error_flush[i]) begin
      if (!arb_llctx.osel[1] && b_llHubNtfy.w_db_err[i]) begin
        s_db_error_flush[i] = '1;
      end else if (b_ChStop.w_stop && |b_ChStop.w_halt_llerr && (b_ChStop.w_channel_num == i)) begin
        //this branch is an early indication of b_llHubNtfy.w_db_err, 
        //and happens just in time for the next arbiter's decision slot
        s_db_error_flush[i] = '1; 
      end else if (!b_llHubNtfy.w_db_err[i])
        s_db_error_flush[i] = '0;
    end
  end


  always_comb begin
    logic [CX_NUM_DMA_CHAN-1:0] s_slotsEmpty;
    logic [LP_NUM_DMA_CHAN_WD-1:0] s_channel;

    s_slotsEmpty = b_slotsReport.w_slotsEmpty;
    s_channel    = fq_stsh_push.w_data.channel; 

    case (arb_fq.osel)
      3'b001: begin
        opush.w_push = arb_fq.ogrant;
      end
      3'b010: begin
        opush.w_push = (r_db_error_flush[b_ll_push.w_data.reqCh] || r_ll_flush[b_ll_push.w_data.reqCh] || !b_ll_push.w_data.desc_valid || b_ll_push.w_data.flush || b_ll_push.w_data.ElemOvrl_LLP) ? '0 : arb_fq.ogrant;
      end
      default: begin
        // By the time EOT_TOKEN surfaces from the queue, a new descriptor might have
        // been received, so this token must be discarded
        // account with the output pipeline
        opush.w_push = (((s_slotsEmpty[s_channel] == '0) || (rv_b_opush.w_valid && (s_channel == rv_b_opush.w_data.reqCh))) &&  
                        (fq_stsh_push.w_validOp == E_EOT_TOKEN) && !fq_stsh_push.w_data.ctx.ovrl.stop) ? '0 : arb_fq.ogrant;
      end
    endcase
  end
 
  
  // *************************************************************************
  // Notifies the doorbell manager that one more descriptor was pushed into
  // the queues
  // ************************************************************************
  // Insert at pipeline here to break a long timming path

  logic                          r_PushNtfyValid;
  logic [LP_NUM_DMA_CHAN_WD-1:0] r_PushNtfyChannel;
  logic                          r_LLNtfyValid;
  logic                          r_LLNtfyLst;
  logic [LP_NUM_DMA_CHAN_WD-1:0] r_LLNtfyChannel;
  logic                          r_LLNtfyNonLL;

  always_ff @ (posedge b_clk.w_main_clk or negedge b_clk.w_reset_n) begin : PROC_FF_RegPushNtyVld
    if (!b_clk.w_reset_n) begin
      r_PushNtfyValid  <= # `TP '0;  
      r_PushNtfyChannel<= # `TP '0;
      r_LLNtfyValid    <= # `TP '0;
      r_LLNtfyLst      <= # `TP '0;
      r_LLNtfyChannel  <= # `TP '0;
      r_LLNtfyNonLL    <= # `TP '0; 
    end else begin
      // Don't notify tokens, because it's the last transaction no expected STShandler response
      r_PushNtfyValid  <= # `TP opush.w_push && opush.w_pushRdy && !(opush.w_ctxElem.ovrl.token || (opush.w_pushOp == E_TRIG_TOKEN) || (opush.w_pushOp == E_LL_ERR) || (opush.w_pushOp == E_LL_END)); 
      r_PushNtfyChannel<= # `TP opush.w_reqCh;
      r_LLNtfyValid    <= # `TP (b_ll_push.w_valid && b_ll_push.w_ready) || (b_non_ll_push.w_valid && b_non_ll_push.w_ready);
      r_LLNtfyLst      <= # `TP (b_ll_push.w_valid && b_ll_push.w_ready) && b_ll_push.w_data.last;
      r_LLNtfyChannel  <= # `TP (b_non_ll_push.w_valid && b_non_ll_push.w_ready) ? b_non_ll_push.w_data.reqCh : b_ll_push.w_data.reqCh; 
      r_LLNtfyNonLL    <= # `TP b_non_ll_push.w_valid && b_non_ll_push.w_ready;                        
    end
  end
  
  assign b_llHubNtfy.w_PushNtfyValid   = r_PushNtfyValid;
  assign b_llHubNtfy.w_PushNtfyChannel = r_PushNtfyChannel;
  assign b_llHubNtfy.w_LLNtfyValid     = r_LLNtfyValid  ;
  assign b_llHubNtfy.w_LLNtfyLst       = r_LLNtfyLst    ;
  assign b_llHubNtfy.w_LLNtfyChannel   = r_LLNtfyChannel;
  assign b_llHubNtfy.w_LLNtfyNonLL     = r_LLNtfyNonLL  ; 
  
  // *************************************************************************
  // Passes on the fetchQ number of available slots
  // *************************************************************************
  assign b_llHubNtfy.w_slotsAvailable = b_slotsReport.w_slotsAvailable;
  assign b_llHubNtfy.w_slotsEmpty     = b_slotsReport.w_slotsEmpty;
  // *************************************************************************
  // Passes the indication that hub is flushing descriptors
  // *************************************************************************
  assign b_llHubNtfy.w_llDescFlush = r_ll_flush;
  // *************************************************************************
  // A LL is in flight, masks the channel schduling in doorbell manager
  // *************************************************************************
  logic [CX_NUM_DMA_CHAN-1:0] s_db_chsch_mask,
                              r_db_chsch_mask;
  always_comb begin : PROC_CB_chsch_mask
    s_db_chsch_mask = '0;
    foreach (s_db_chsch_mask[i]) begin
      if (i == b_llHubNtfy.w_PushNtfyChannel && b_llHubNtfy.w_PushNtfyValid)
        s_db_chsch_mask[i] = '1;
      if (i == b_llHubNtfy.w_LLNtfyChannel && b_llHubNtfy.w_LLNtfyValid)
        s_db_chsch_mask[i] = '1;
      if (i == b_PushLLCtx.w_data.reqCh && b_PushLLCtx.w_valid)
        s_db_chsch_mask[i] = '1;
    end
  end
  always_ff @ (posedge b_clk.w_main_clk or negedge b_clk.w_reset_n) begin : PROC_FF_chsch_mask
    if (!b_clk.w_reset_n)
      r_db_chsch_mask <= # `TP '0;
    else
      r_db_chsch_mask <= # `TP s_db_chsch_mask;
  end
 
  assign b_llHubNtfy.w_db_chsch_mask = r_db_chsch_mask | r_ll_flush;

  logic [CX_NUM_DMA_CHAN-1:0] s_chStop;
  always_comb begin 
    s_chStop = '0;
    if(b_ll_push.w_valid && b_ll_push.w_ready)
      s_chStop[b_ll_push.w_data.reqCh] = b_ll_push.w_data.stop;
  end
  assign b_llHubNtfy.w_chStop = s_chStop;

  //Passes on doorbell error notification
  assign b_HubDbErr.w_data = b_llHubNtfy.w_db_err | b_llHubNtfy.w_db_stop | r_ll_flush;

  always_comb begin : PROC_CB_opush

    case (arb_fq.osel)
      3'b001: begin // Non-Linked List mode
         opush.w_ctxElem                    = b_non_ll_push.w_data.ctxElem;
         opush.w_reqCh                      = b_non_ll_push.w_data.reqCh;
         opush.w_pushOp                     = b_non_ll_push.w_data.pushOp;
      end
      3'b010: begin  // Linked List mode
         opush.w_ctxElem                    = b_ll_push.w_data.ctxElem;
         // Element prefetch is stored in FF inside the doorbell manager
         opush.w_ctxElem.ovrl.llData.elemPf = b_llHubNtfy.w_dbElPfetch[b_ll_push.w_data.reqCh];
         opush.w_reqCh                      = b_ll_push.w_data.reqCh;
         opush.w_pushOp                     = b_ll_push.w_data.pushOp;
      end
      default: begin  // STSH Notifications
         opush.w_ctxElem                    = fq_stsh_push.w_data.ctx;
         opush.w_reqCh                      = fq_stsh_push.w_data.channel;
         opush.w_pushOp                     = fq_stsh_push.w_validOp;  // Change this code when errors are supported
      end

    endcase

  end : PROC_CB_opush

  // *************************************************************************
  // Output register before delivering to fetchQ
  // *************************************************************************
 
  assign rv_opush.w_data.ctxElem = opush.w_ctxElem;
  assign rv_opush.w_valid        = opush.w_push;
  assign rv_opush.w_data.pushOp  = opush.w_pushOp;
  assign opush.w_pushRdy         = rv_opush.w_ready;
  assign rv_opush.w_data.reqCh   = opush.w_reqCh;

  DWC_pcie_edmapf_rslice_dly
   #(
   .P_DATATYPE(llq_push_s)
  ) u_rdly (
   .b_clkrst ( b_clk                )
  ,.b_dst    ( rv_b_opush.master_mp )
  ,.b_src    ( rv_opush.slave_mp    )
  );
 
  assign b_opush.w_ctxElem = rv_b_opush.w_data.ctxElem;
  assign b_opush.w_push    = rv_b_opush.w_valid;
  assign b_opush.w_pushOp  = rv_b_opush.w_data.pushOp;
  assign rv_b_opush.w_ready= b_opush.w_pushRdy;
  assign b_opush.w_reqCh   = rv_b_opush.w_data.reqCh;

  // *************************************************************************
  assign b_non_ll_push.w_ready = (arb_fq.osel[0]) & opush.w_pushRdy;


  // On a flush scenario, trashes everything except the last
  // note: when the flush starts only pushes the last beat to LL RAM
  // note2: when doorbell trigger token is asserted force ready to flush the 
  //       descriptor without sending it to LL RAM
  always_comb begin
    b_ll_push.w_ready = (s_ll_flush[b_ll_push.w_data.reqCh] && !b_ll_push.w_data.last) ||
                      (arb_llctx.osel[1]  && b_PushLLCtx.w_ready) ||
                      (r_db_error_flush[b_ll_push.w_data.reqCh]) ||
                      (arb_fq.osel[1] & opush.w_pushRdy);

    //This avoids contention on b_ChStop
    if (b_non_ll_push.w_ready)
      b_ll_push.w_ready = '0;
  end

 
  always_comb begin 
    logic [CX_NUM_DMA_CHAN-1:0] s_slotsEmpty;

    foreach (s_slotsEmpty[i])
      s_slotsEmpty[i] = b_slotsReport.w_slotsEmpty[i];

    // if the EOT token is to be discarded also pop out from the queue
    fq_stsh_push.w_ready = (arb_fq.osel[2] & opush.w_pushRdy) || 
                           ((s_slotsEmpty[fq_stsh_push.w_data.channel] == '0) && (fq_stsh_push.w_validOp == E_EOT_TOKEN) && !fq_stsh_push.w_data.ctx.ovrl.stop);
  end


  // *************************************************************************
  // Pushes data back to LL RAM. Two sources:
  // 1- From the status handler, when a transfer ends in error and LL mode
  // 2- From the LL completion, when the descriptor is a linked list pointer
  //    When doorbell manager is in trigger token mode after an error, the 
  //    descriptor is trashed because the LL RAM already rolled back and so 
  //    this push would corrupt it
  //  - refer to arbiter u_llctx_arb  
  // *************************************************************************

  assign b_PushLLCtx.w_valid =  arb_llctx.ogrant/* && !b_llHubNtfy.w_db_stop[b_ll_push.w_data.reqCh]*/;

  assign b_PushLLCtx.w_data.last       = '0;


  // non-ll mode tokens are not pushed into LLRAM so thery are immediatly consumemed
  // only tokens with watermark interrupts or errors are pushed into ll RAM
  assign ll_token_push.w_ready = (arb_llctx.osel[0]) && b_PushLLCtx.w_ready || !(ll_token_push.w_data.ctx.glb.ll_en && |{ll_token_push.w_data.ctx.ovrl.ovrlData.watermarkEn, ll_token_push.w_data.ctx.ovrl.errors, ll_token_push.w_data.ctx.ovrl.stop});

  assign b_PushLLCtx.w_data.pushOp       = E_PUSH;
  assign b_PushLLCtx.w_data.ElemOvrl_LLP = b_ll_push.w_data.ElemOvrl_LLP;
  assign b_PushLLCtx.w_data.ElemOvrl_TCB = b_ll_push.w_data.ElemOvrl_TCB;
  assign s_llp = b_ll_push.w_data.ElemOvrl_LLP;
  assign s_tcb = b_ll_push.w_data.ElemOvrl_TCB;

  always_comb begin : PROC_CB_pushLLCtx
    b_PushLLCtx.w_data.ctxElem = '0;
    b_PushLLCtx.w_data.flush   = '0;
    b_PushLLCtx.w_data.stop    = '0;
    case (arb_llctx.osel)
      2'b10: begin  // Linked List mode
        b_PushLLCtx.w_data.reqCh                             = b_ll_push.w_data.reqCh;
        // refer to DWC_pcie_edmapf_ctrl_ll_cpl to see how his is calculated when the descriptor is not valid 
        {b_PushLLCtx.w_data.ctxElem.ovrl.llData.elemPtrHigh, 
         b_PushLLCtx.w_data.ctxElem.ovrl.llData.elemPtrLow}  = {b_ll_push.w_data.ctxElem.ovrl.llData.elemPtrHigh, b_ll_push.w_data.ctxElem.ovrl.llData.elemPtrLow};

        b_PushLLCtx.w_data.ctxElem.ovrl.llData.ccs           =  b_ll_push.w_data.ctxElem.ovrl.llData.ccs;
        if ( b_ll_push.w_data.desc_valid)
          if (s_llp == E_TRUE)
            if (s_tcb == E_TRUE)
              b_PushLLCtx.w_data.ctxElem.ovrl.llData.ccs     = ~b_ll_push.w_data.ctxElem.ovrl.llData.ccs;

        b_PushLLCtx.w_data.ctxElem.ovrl.llData.cb            = b_ll_push.w_data.ctxElem.ovrl.llData.cb;
        b_PushLLCtx.w_data.ctxElem.ovrl.llData.pfOvrl        = b_ll_push.w_data.ctxElem.ovrl.llData.pfOvrl;
        b_PushLLCtx.w_data.ctxElem.ovrl.llData.elemPf        = b_ll_push.w_data.ctxElem.ovrl.llData.elemPf;
        b_PushLLCtx.w_data.desc_valid                        = b_ll_push.w_data.desc_valid;
        b_PushLLCtx.w_data.flush                             = b_ll_push.w_data.flush;
        b_PushLLCtx.w_data.ctxElem.ovrl.errors               = b_ll_push.w_data.ctxElem.ovrl.errors;
        b_PushLLCtx.w_data.ctxElem.ovrl.token                = '0;
      end
      default: begin  // STSH Notifications
        b_PushLLCtx.w_data.reqCh                             = ll_token_push.w_data.channel;
        {b_PushLLCtx.w_data.ctxElem.ovrl.llData.elemPtrHigh, 
          b_PushLLCtx.w_data.ctxElem.ovrl.llData.elemPtrLow} = {ll_token_push.w_data.ctx.ovrl.llData.elemPtrHigh, ll_token_push.w_data.ctx.ovrl.llData.elemPtrLow};
        b_PushLLCtx.w_data.ctxElem.ovrl.llData.ccs           = ll_token_push.w_data.ctx.ovrl.llData.ccs;
        b_PushLLCtx.w_data.ctxElem.ovrl.llData.elemPf        = ll_token_push.w_data.ctx.ovrl.llData.elemPf;
        b_PushLLCtx.w_data.ctxElem.ovrl.llData.cb            = ll_token_push.w_data.ctx.ovrl.llData.cb;
        b_PushLLCtx.w_data.desc_valid                        = '1;
        b_PushLLCtx.w_data.ctxElem.ovrl.errors               = ll_token_push.w_data.ctx.ovrl.errors;
        b_PushLLCtx.w_data.ctxElem.ovrl.ovrlData.watermarkEn = ll_token_push.w_data.ctx.ovrl.ovrlData.watermarkEn;
        b_PushLLCtx.w_data.ctxElem.ovrl.ovrlData.xferSize    = ll_token_push.w_data.ctx.ovrl.ovrlData.xferSize;
        b_PushLLCtx.w_data.ctxElem.ovrl.token                = '1;
        b_PushLLCtx.w_data.ctxElem.ovrl.stop                 = ll_token_push.w_data.ctx.ovrl.stop;
        b_PushLLCtx.w_data.stop                              = ll_token_push.w_data.ctx.ovrl.stop;
      end

    endcase
  end
  // *************************************************************************



  // *************************************************************************
  // Non linked mode gets the doorbell cleared directly by the LL fetcher
  // Linked list mode trigegrs a doorbell stop on the following conditions
  // - End of list detection
  // - Error is detected on a descriptor completion
  // *************************************************************************
  always_comb begin : PROC_CB_ChStop
    b_ChStop.w_channel_num = opush.w_reqCh;
    b_ChStop.w_start      = '0;
    b_ChStop.w_halt_llerr = E_DMAERR_NONE;
    b_ChStop.w_stop       = '0;

    if ((b_ll_push.w_valid) && (!b_ll_push.w_data.desc_valid) && b_ll_push.w_ready && b_ll_push.w_data.last) begin
      b_ChStop.w_stop        = 1'b1;
      b_ChStop.w_halt_llerr  = b_ll_push.w_data.ctxElem.ovrl.errors;
      b_ChStop.w_channel_num = b_ll_push.w_data.reqCh;
    end

  end
  // *************************************************************************


// SNPS_SysML_CODE_END

endmodule
