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
// ---    $Revision: #14 $ 
// ---    $Author: dnolan $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_ll_cpl.sv#14 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_rasdp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_readyValid_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_genericData_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_ll_cpl
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter        type P_CTX_TYPE = logic
  ,parameter  type P_POPCTX_LL_TYPE = logic
  ,parameter  CC_NUM_DMA_CHAN_WIDTH = `CC_NUM_DMA_WR_CHAN_WIDTH
  ,parameter             CX_DMA_LLQ = 4
  ,parameter        CX_NUM_DMA_CHAN = `CC_NUM_DMA_WR_CHAN
  ,parameter dmaEngType_e P_CHANNEL = E_WRITE
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_genericData_if.slave_mp b_HubDbErr
  ,DWC_pcie_edmapf_aclks_if.slave_mp       clk
  ,DWC_pcie_edmapf_tlp_if.slave_mp         cpl_ll
  ,DWC_pcie_edmapf_genericData_if.slave_mp ctx
  ,DWC_pcie_edmapf_readyValid_if.master_mp ll_push
  ,DWC_pcie_edmapf_rasdp_if.master_mp      b_ras
  );


// SNPS_SysML_CODE_START
  localparam       L_DATAWD_NP       = `PCIE_CORE_DATA_BUS_WD                                            ;
  localparam       L_DATAPROTWD      = K_COREBUSWD-L_DATAWD_NP                                           ;
  localparam ras_e L_RAS_CHK_PTR     = (P_CHANNEL == E_WRITE) ? E_RAS_CPL_WRLL_DATA : E_RAS_CPL_RDLL_DATA;
  localparam RAS_DP_PROT_CHK_ID = (P_CHANNEL == E_WRITE) ? RAS_CHK_ID_CPL_WRLL_DATA : RAS_CHK_ID_CPL_RDLL_DATA;

  localparam dma_req_type_e LP_DMA_REQ_LL = P_CHANNEL == E_WRITE ? E_DMA_WRCH_LLREAD : E_DMA_RDCH_LLREAD;
  localparam LP_LLBURST_WD                = $clog2((CX_NUM_DMA_CHAN * CX_DMA_LLQ)+1);
  // For performance reasons CPLQ must be able to hold at least two complete descriptors
  localparam LP_CPLQ_NW = `CX_NW < 8 ? 8 : `CX_NW;

  // Encapsulates the chnum / error information into the CPLQ header
  typedef struct packed {
    logic [CC_NUM_DMA_CHAN_WIDTH-1:0] chnum;
    dmaErrors_e                       err;
  } cplq_hdr_st;
 

  typedef struct packed {
    cplq_hdr_st                       hdr     ;
    logic     [9:0]                   dw_cnt  ; 
    logic                             hv      ;
    logic                             dv      ;
    logic                             eot     ;
    logic [K_COREBUSWD-1:0]           data    ;
  } cpl_ll_s;
  cpl_ll_s r_cpl_ll, s_cpl_ll;

  logic  s1_cpl_ll_halt;


  // **********************************************************
  // * Input register
  // **********************************************************



  always_ff @ (posedge clk.w_main_clk or negedge clk.w_reset_n) begin : PROC_FF_rcpl
    if (!clk.w_reset_n) begin
      r_cpl_ll  <= #`TP '0;
    end else begin
      if (!cpl_ll.w_halt)
        r_cpl_ll  <= #`TP  s_cpl_ll; 
    end
  end

  always_comb begin : PROC_CB_halt_gen
    if (cpl_ll.w_hv || cpl_ll.w_dv) begin
      cpl_ll.w_halt = s1_cpl_ll_halt;
    end else if (r_cpl_ll.hv || r_cpl_ll.dv) begin
      cpl_ll.w_halt = s1_cpl_ll_halt;         
    end else begin
      cpl_ll.w_halt = 1'b0; //If the register is empty accept
    end
  end

  // **************************************************************************
  // Tracks the ammount of bytes alread pushed
  // **************************************************************************
  always_comb begin : PROC_CB_dwen_gen
    s_cpl_ll.hv                                   = cpl_ll.w_hv;
    s_cpl_ll.dv                                   = cpl_ll.w_dv;
    s_cpl_ll.eot                                  = cpl_ll.w_eot;
    s_cpl_ll.data                                 = cpl_ll.w_data;

    case (cpl_ll.w_header.common2.cpl_status)
      E_CPL_STATUS_UR: 
        s_cpl_ll.hdr.err = E_DMAERR_LL_CPL_UR;
      E_CPL_STATUS_CA:
        s_cpl_ll.hdr.err = E_DMAERR_LL_CPL_CA;
      default: 
        s_cpl_ll.hdr.err = cpl_ll.w_header.common2.poisoned ? E_DMAERR_LL_CPL_EP : E_DMAERR_NONE;
    endcase

    s_cpl_ll.hdr.chnum                            = '0;
    s_cpl_ll.hdr.chnum[CC_NUM_DMA_CHAN_WIDTH-1:0] = cpl_ll.w_header.dma.channel[CC_NUM_DMA_CHAN_WIDTH-1:0];
    s_cpl_ll.dw_cnt                               = r_cpl_ll.dw_cnt;

    if (!cpl_ll.w_halt && cpl_ll.w_hv)
      //note: if !dv we are handling an error, so force a dummy single descriptor on payload
      //this will allow subsequent precessing element to do "business as usual"
      s_cpl_ll.dw_cnt = cpl_ll.w_dv ? cpl_ll.w_header.common2.dw_len : 'd6;
    else if (!cpl_ll.w_halt) begin

      s_cpl_ll.dw_cnt = (r_cpl_ll.dw_cnt > `CX_NW ) ? 
        r_cpl_ll.dw_cnt - `CX_NW :
        '0;

    end
  end
  // **************************************************************************
  // Write data management logic
  // **************************************************************************
  logic s_cplq_wr;
  logic s_cplq_wr_err;
  logic s_cplq_wr_last;
  logic[$clog2(2*LP_CPLQ_NW):0]wr_dw_free;
  logic [LP_CPLQ_NW-1:0] s_wr_en;

  always_comb begin : PROC_CB_wen
    s_wr_en = '0;
    if (r_cpl_ll.dw_cnt >= `CX_NW)
      s_wr_en[`CX_NW-1:0] = '1;
    else begin
      for (int i = 0;i < `CX_NW;i++) begin
        if (i < r_cpl_ll.dw_cnt)
          s_wr_en[i] = '1;
        else
          s_wr_en[i] = '0;
      end
    end
  end

  assign s_cplq_wr      = (r_cpl_ll.hv || r_cpl_ll.dv)  && !cpl_ll.w_halt;
  assign s_cplq_wr_err  = |r_cpl_ll.hdr.err && !r_cpl_ll.dv; //do not consider poison
  assign s_cplq_wr_last = r_cpl_ll.eot && !cpl_ll.w_halt;

  logic Ffull               ;
  always_comb begin : PROC_CB_halt
    logic[$clog2(2*LP_CPLQ_NW):0] iwordCnt;

    iwordCnt = '0;
    iwordCnt[$clog2(LP_CPLQ_NW):0] =  TlpCountDWRD_f(s_wr_en[`CX_NW-1:0]);
    // Halts CPL if the buffer in CPLQ runs out of space or ctx fifo gets full
    s1_cpl_ll_halt =  (wr_dw_free < iwordCnt) || Ffull;
  end

  typedef struct packed {
    logic                             empty;
    logic                             pop;
    logic [(6*32)-1:0]                data;
    cplq_hdr_st                       hdr;
    logic                             last;
  } cplq_pop_st;

  cplq_pop_st cplq_pop;

  logic [LP_CPLQ_NW*32-1:0] s_wr_data;
  always_comb begin : PROC_wr_data
    s_wr_data = '0;
    s_wr_data[`CX_NW*32-1:0] = r_cpl_ll.data[`CX_NW*32-1:0];
  end


  DWC_pcie_edmapf_ctrl_ll_cplq
   
  #(
    .P_WDATA_WD   (LP_CPLQ_NW * 32      ),
    .P_WEN_WD     (LP_CPLQ_NW           ),
    .P_CH_WD      (CC_NUM_DMA_CHAN_WIDTH),
    .P_HDR_TYPE   (cplq_hdr_st          )
  ) u_ll_cplq (
    .b_clk        (clk)
    ,.b_wr_dw_free(wr_dw_free      )
    ,.b_wr        (s_cplq_wr       )
    ,.b_wr_last   (s_cplq_wr_last  )
    ,.b_wr_err    (s_cplq_wr_err   )
    ,.b_wr_en     (s_wr_en         )
    ,.b_wr_data   (s_wr_data       )
    ,.b_wr_hdr    (r_cpl_ll.hdr    )
    ,.b_pop_empty (cplq_pop.empty  )
    ,.b_pop       (cplq_pop.pop    )
    ,.b_pop_data  (cplq_pop.data   )
    ,.b_pop_hdr   (cplq_pop.hdr    )
    ,.b_pop_last  (cplq_pop.last   )
    );

  // --------------------------------------------------------------------------
  // Queues the context to make sure it gets queued with the descriptors
  // unloaded from the CPLQ module
  // --------------------------------------------------------------------------
  localparam integer LP_REG_DELAY_DENOM  = 1000;
  localparam integer LP_REG_DELAY_TIME   = `TP * LP_REG_DELAY_DENOM;
  localparam integer LP_FDEPTH           = 4;
  localparam integer LP_FDEPTH_LOG2      = $clog2(LP_FDEPTH);
  localparam integer LP_FWIDTH           = $bits(P_POPCTX_LL_TYPE);

  logic Fpush_req_n         ;
  logic Fpop_req_n          ;
  logic nc_Fempty           ;
  P_POPCTX_LL_TYPE Fctx_data;
  logic nc_Falmost_empty    ;
  logic nc_Fhalf_full       ;
  logic nc_Falmost_full     ;
  logic nc_Ferror           ;

  assign Fpush_req_n =  !(!cpl_ll.w_halt && cpl_ll.w_hv);
  assign Fpop_req_n  = !(cplq_pop.pop && cplq_pop.last);

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
  )u_fifo_ctx (
    .clk         (clk.w_main_clk       ),
    .rst_n       (clk.w_reset_n        ),
    .init_n      (1'b1                 ),
    .push_req_n  (Fpush_req_n          ),
    .pop_req_n   (Fpop_req_n           ),
    .data_in     (ctx.w_data           ),
    .data_out    (Fctx_data            ),
    .full        (Ffull             ),
    // SMD: A signal or variable is set but never read  
    // SJ:  BCM output signals not required by the logic
    // spyglass disable_block W528
    .empty       (nc_Fempty            ),
    .almost_empty(nc_Falmost_empty     ),
    .half_full   (nc_Fhalf_full        ),
    .almost_full (nc_Falmost_full      ),
    .error       (nc_Ferror            ),
    // spyglass enable_block W528
     .diag_n      (1'b0                )
  );               


  // --------------------------------------------------------------------------
  // Multi CPL beat and flush tracker
  // --------------------------------------------------------------------------
  typedef struct packed {
    logic                     flush;
    logic [LP_LLBURST_WD-1:0] llNslot;
    logic [LP_LLBURST_WD-1:0] llNreads;
    logic                     clr;
    logic                     db_err;
  } cpl_ll_tracker_st;

  cpl_ll_tracker_st [CX_NUM_DMA_CHAN-1:0] s_cpl_ll_tracker, r_cpl_ll_tracker;

  always_ff @ (posedge clk.w_main_clk or negedge clk.w_reset_n) begin : PROC_FF_cpl_ll_tracker
    if (!clk.w_reset_n) begin
      foreach (r_cpl_ll_tracker[i])
        r_cpl_ll_tracker[i] <= #`TP '0;
    end else begin
      foreach (r_cpl_ll_tracker[j])
        r_cpl_ll_tracker[j] <= #`TP s_cpl_ll_tracker[j];
    end
  end


  // --------------------------------------------------------------------------
  // Detects descriptor flush - this helps calculate the LL pointer rollback
  // Value
  // --------------------------------------------------------------------------
  typedef struct packed {
    logic                     flush;
    logic                     stop;
    // records the last good known data beat before flush
    logic [(6*32)-1:0]        data;
    cplq_hdr_st               hdr;
  } ll_flush_st;
  
  ll_flush_st s_ll_flush, r_ll_flush;
  always_ff @ (posedge clk.w_main_clk or negedge clk.w_reset_n) begin : PROC_FF_flush
    if (!clk.w_reset_n)
      r_ll_flush <= # `TP '0;
    else
      r_ll_flush <= # `TP s_ll_flush;
  end

  function automatic logic desc_valid_f(input logic[2:0] lldata, input logic ctx_ccs);
    //compares the descriptor cb with ccs
    //data[2]  = LLP
    //data[1]  = TCB
    //data[0]  = CB
    desc_valid_f = (!lldata[2] &&               ctx_ccs == lldata[0]) ||
                   ( lldata[2] && !lldata[1] && ctx_ccs == lldata[0]) ||
                   ( lldata[2] &&  lldata[1] && ctx_ccs != lldata[0]);
 
  endfunction 

  always_comb begin : PROC_CB_flush
    logic back2back_flush;
    logic start_flush;
    logic end_flush;
    logic desc_valid;

    back2back_flush = '0;
    start_flush     = '0;
    end_flush       = '0;

    desc_valid = desc_valid_f(cplq_pop.data[2:0], Fctx_data.ctx_ccs); 

    s_ll_flush = r_ll_flush;

    s_ll_flush.stop = !cplq_pop.empty && !desc_valid;
    // Descriptor is not valid any more in this burst's beat and subsequents
    // compares the CCS with CB (bit 0 of the descriptor)
    if (!cplq_pop.empty && !desc_valid)
      start_flush = '1;

    // Jump, subsequent beats in the burst are not valid
    // cplq_pop.data[2] contains the LLP from context
    if (!cplq_pop.empty && cplq_pop.pop && cplq_pop.data[2] && !cplq_pop.last)
      start_flush = '1;

    // An error was detected in the LL
    if (!cplq_pop.empty && cplq_pop.pop && |cplq_pop.hdr.err)
      start_flush = '1;

    //End of burst, clear
    if (ll_push.w_valid && ll_push.w_ready && ll_push.w_data.last)
      end_flush = '1;

    if (!cplq_pop.empty && r_cpl_ll_tracker[cplq_pop.hdr.chnum].flush)
      start_flush = '1;

    back2back_flush = (r_ll_flush.flush && (cplq_pop.hdr.chnum != ll_push.w_data.reqCh)) && start_flush;

    if (start_flush)
      s_ll_flush.flush = '1;
    else if (end_flush)
      s_ll_flush.flush = '0;

    if (!r_ll_flush.flush || back2back_flush) begin
      // after flush is detected clplq_pop.data must be maintained
      // back to back flushes are possible
      s_ll_flush.data  = cplq_pop.data;
      s_ll_flush.hdr   = cplq_pop.hdr;
    end
  end

  always_comb begin : PROC_CB_cpl_ll_tracker_flush
    foreach (r_cpl_ll_tracker[i]) begin
      logic db_err_clr;
      db_err_clr = r_cpl_ll_tracker[i].db_err && !b_HubDbErr.w_data[i];

      s_cpl_ll_tracker[i].db_err = b_HubDbErr.w_data[i];

      s_cpl_ll_tracker[i].clr = r_cpl_ll_tracker[i].clr;

      if (ll_push.w_ready && ll_push.w_valid && (ll_push.w_data.reqCh == i))
        s_cpl_ll_tracker[i].clr = '0;
 
      // on the last LL (determined by context's last or doorbell event (error / ll flush)
      // turns off multi CPL flush
      if ((cplq_pop.hdr.chnum == i) && cplq_pop.last && (Fctx_data.db_llNreads == s_cpl_ll_tracker[i].llNreads) && !cplq_pop.empty && (Fctx_data.db_llNslotsOutStdLst || b_HubDbErr.w_data[i]))
        s_cpl_ll_tracker[i].clr= '1; 
 
      if (s_ll_flush.hdr.chnum == i) begin
        // turns on multi CPL flush if not the last in the burst
        s_cpl_ll_tracker[i].flush = ((Fctx_data.db_llNreads != s_cpl_ll_tracker[i].llNreads) && s_ll_flush.flush) || r_cpl_ll_tracker[i].flush;
      end else begin
        s_cpl_ll_tracker[i].flush = r_cpl_ll_tracker[i].flush;
      end

      if (r_cpl_ll_tracker[i].clr || db_err_clr)
        s_cpl_ll_tracker[i].flush = '0;
 
    end
  end

  always_comb begin : PROC_CB_cpl_ll_tracker_lln
    foreach (r_cpl_ll_tracker[i]) begin
      logic db_err_clr;
      db_err_clr = r_cpl_ll_tracker[i].db_err && !b_HubDbErr.w_data[i];

      s_cpl_ll_tracker[i].llNslot = r_cpl_ll_tracker[i].llNslot; 
      s_cpl_ll_tracker[i].llNreads= r_cpl_ll_tracker[i].llNreads;

      if ((cplq_pop.hdr.chnum == i ) && cplq_pop.pop && !cplq_pop.empty) begin
        if (!s_ll_flush.flush)
          s_cpl_ll_tracker[i].llNslot = r_cpl_ll_tracker[i].llNslot + 'd1;
        if (cplq_pop.last)
          s_cpl_ll_tracker[i].llNreads= r_cpl_ll_tracker[i].llNreads + 'd1;
      end

      if(r_cpl_ll_tracker[i].clr || db_err_clr) begin
        s_cpl_ll_tracker[i].llNslot = '0;
        s_cpl_ll_tracker[i].llNreads = '0;
      end
    end
  end

  typedef struct packed {
    bool_e                                 ElemOvrl_LLP ;
    bool_e                                 ElemOvrl_TCB ;
    P_CTX_TYPE                             ctxElem      ;
    logic                                  push         ;
    llPushOp_e                             pushOp       ;
    logic      [CC_NUM_DMA_CHAN_WIDTH-1:0] reqCh        ;
    logic                                  last         ;
    logic                                  flush        ; 
    logic                                  desc_valid   ;
    logic                                  stop         ;
  } ll_push_st;

  ll_push_st s_ll_push, r_ll_push;
  logic s_ll_pushRdy;


  // --------------------------------------------------------------------------
  // Handles the output descriptor pushing
  // --------------------------------------------------------------------------
  always_comb begin : PROC_CB_ll_push_ctx
    logic [(6*32)-1:0] lldata;
    cplq_hdr_st        llhdr;
    logic              desc_valid;

    lldata = s_ll_flush.flush ? s_ll_flush.data : cplq_pop.data;
    llhdr  = s_ll_flush.flush ? s_ll_flush.hdr  : cplq_pop.hdr;

    desc_valid = desc_valid_f(lldata[2:0], Fctx_data.ctx_ccs) && !(|llhdr.err); 

    s_ll_push = r_ll_push;

    s_ll_push.desc_valid = desc_valid;
    // I'm pushing after a descriptor completion so LLEN is enabled
    s_ll_push.pushOp                          = E_PUSH;
    // I'm pushing the descriptor I got from the CPL
    s_ll_push.ctxElem.ovrl.ovrlData           = ovrlData_s'({lldata[3], lldata[4], lldata[191:32]});

    // At this interface, the following signals are don't care
    // - Some are implemented in the lower layer
    // - Others are not used by the layers bellow
    s_ll_push.ctxElem.glb                     = '0;

    s_ll_push.ctxElem.ovrl.token              = '0;
    s_ll_push.ctxElem.ovrl.llData.ccs         = Fctx_data.ctx_ccs;
    s_ll_push.ctxElem.ovrl.llData.elemPf      = !desc_valid ? '0 : {2'b00, lldata[21:17]};
    s_ll_push.ctxElem.ovrl.llData.pfOvrl      = !desc_valid ? bool_e'(Fctx_data.ctx_pfo) : bool_e'(lldata[1]);
    //HDMA in practice never writes into cycle bit, while pushing descriptors into FetchQ. In order to read the correct cycle bit in the end, it must be set equal to CCS in the 
    //initial programming
    s_ll_push.ctxElem.ovrl.llData.cb          = !desc_valid ? Fctx_data.ctx_ccs : lldata[0];
    if (desc_valid && lldata[2] && ( ((lldata[0] == Fctx_data.ctx_ccs) && !lldata[1]) ||  ((lldata[0] != Fctx_data.ctx_ccs) && lldata[1])  ) ) begin // Linked list pointer and descriptor is valid, if not valid keep LL ptr value
      {s_ll_push.ctxElem.ovrl.llData.elemPtrHigh,
        s_ll_push.ctxElem.ovrl.llData.elemPtrLow} = lldata[127:64];
    end else begin
      {s_ll_push.ctxElem.ovrl.llData.elemPtrHigh,
        s_ll_push.ctxElem.ovrl.llData.elemPtrLow} = Fctx_data.ctx_ll_ptr - ('d24*Fctx_data.db_llNslotsOutStd - 'd24*r_cpl_ll_tracker[cplq_pop.hdr.chnum].llNslot);
    end

    // Carries on the error detected to the linked list descriptor
    s_ll_push.ctxElem.ovrl.errors = llhdr.err;

    //If pushing a descriptor the linked list is enabled
    s_ll_push.ctxElem.glb.ll_en = '1;

    s_ll_push.ElemOvrl_LLP = bool_e'(lldata[2]);
    s_ll_push.ElemOvrl_TCB = bool_e'(lldata[1]);
 
    s_ll_push.reqCh = cplq_pop.hdr.chnum;
    s_ll_push.push  = !cplq_pop.empty;
    s_ll_push.last  = cplq_pop.last;
    // If flushing I must still flag this to the hub, so all the LL requests are accounted in the 
    // the doobell manager module
    s_ll_push.flush = s_ll_flush.flush;
    s_ll_push.stop  = s_ll_flush.stop;
  end

  assign s_ll_pushRdy      = ll_push.w_ready || !r_ll_push.push;
  assign cplq_pop.pop      = !cplq_pop.empty && s_ll_pushRdy; 

  always_ff @(posedge clk.w_main_clk or negedge clk.w_reset_n) begin : PROC_FF_ll_push_ctx  
    if (!clk.w_reset_n) begin
      r_ll_push <= # `TP '0;
    end else begin
      if (s_ll_pushRdy)
        r_ll_push <= # `TP s_ll_push;
    end
  end

  assign ll_push.w_data.ElemOvrl_LLP = r_ll_push.ElemOvrl_LLP;
  assign ll_push.w_data.ElemOvrl_TCB = r_ll_push.ElemOvrl_TCB;
  assign ll_push.w_data.ctxElem      = r_ll_push.ctxElem     ;
  assign ll_push.w_valid             = r_ll_push.push        ;
  assign ll_push.w_data.pushOp       = r_ll_push.pushOp      ;
  assign ll_push.w_data.reqCh        = r_ll_push.reqCh       ;
  assign ll_push.w_data.last         = r_ll_push.last        ;
  assign ll_push.w_data.flush        = r_ll_push.flush       ;
  assign ll_push.w_data.desc_valid   = r_ll_push.desc_valid  ;


  assign ll_push.w_data.stop         =  r_ll_push.stop;

   // Checker
   ras_dp_pipe
    #(
     .PIPELINE_TYPE              (0                             ), // 0: delay_n
     .RESETVAL                   (0                             ),
     .N_STAGES                   (0                             ),
     .CAN_STALL                  (0                             ),
     .RESET_STALL                (0                             ),
     .BUS_PROTECT_GEN_EN         (0                             ), // 1: Bus Protection Generator is present
     .BUS_PROTECT_CHK_EN         (1                             ), // 0: Bus Protection Checker is not present (ECC/Parity)
     .PROT_TYPE                  (1                             ), // 0=Ecc, 1=Simple Parity
     .PROT_RANGE                 (K_RAS_PROT_RANGE              ), // Number of bits to calculate parity/ECC on
     .PROT_WD                    (L_DATAPROTWD                  ), // Selects the width of the din_prot/dout_prot signals
     .PARITY_MODE                (K_RAS_PARITY_MODE             ), // selects the type of parity: 0=Even, 1=Odd
     .PROT_CORRECT_EN            (0                             ), // 0: no correction on single-errors, 1: correction on single-errors
     .TOTAL_WIDTH                (L_DATAWD_NP                   ), 
     .EXCLUDE_PROT_WIDTH         (0                             ),
     .RAS_DP_PROT_CHK_ID_BASE    (RAS_DP_PROT_CHK_ID            ), // Associates the Bus Protection Checker with a unique identifier
     .ADDR_ECC_PROT_EN           (/* NC */                      ),
     .ADDR_LOG_EN                (/* NC */                      ),
     .ADDR_INDEX                 (/* NC */                      ),
     .ADDR_WD                    (/* NC */                      )
   ) u_ras_chk (
      .clk                       ( clk.w_main_clk                           )
     ,.rst_n                     ( clk.w_reset_n                            )
     ,.din                       ( cpl_ll.w_data[L_DATAWD_NP-1:0]           )
     ,.din_prot                  ( cpl_ll.w_data[K_COREBUSWD-1:L_DATAWD_NP] )
     ,.dout                      ( /* Not Connected */                      )
     ,.dout_prot                 ( /* Not Connected */                      )
     ,.en                        ( 1'b1                                     )
     ,.bypass                    ( 1'b0                                     )
     ,.stall                     ( 1'b0                                     )
     ,.stallout                  ( /* Not Connected */                      )
     ,.valid_in                  ( cpl_ll.w_dv                              )
     ,.halt_out                  ( /* Not Connected */                      )
     ,.valid_out                 ( /* Not Connected */                      )
     ,.halt_in                   ( 1'b0                                     )
     ,.ras_dp_err_inband_kbd_in  ( 1'b0                                     )
     ,.ras_dp_err_inband_kbd_out ( /* Not Connected */                      )
     ,.ras_dp_err_log            ( b_ras.w_ras_dp_err_log                   )
       ,.ras_dp_err_inj          ( b_ras.w_ras_dp_err_inj                   ) 
   );


// SNPS_SysML_CODE_END

endmodule
