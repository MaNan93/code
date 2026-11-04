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
// ---    $Revision: #22 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_ll_fetch.sv#22 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_readyValid_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_pop_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_llFetchNtfy_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_crPopRdy_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ram2p_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ram1p_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_cdmregs_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_genericData_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_ll_fetch
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter    type P_DBMNGR_REM_TYPE = logic
  ,parameter         type P_LLRAM_TYPE = logic
  ,parameter CC_IF_CTRL_LL_RAM_LATENCY = 1
  ,parameter      CC_IF_CTRL_LL_RAM_WD = 256
  ,parameter     CC_NUM_DMA_CHAN_WIDTH = `CC_NUM_DMA_WR_CHAN_WIDTH
  ,parameter                CX_DMA_LLQ = `CX_DMA_WR_LLQ
  ,parameter           CX_NUM_DMA_CHAN = `CX_NUM_DMA_WR_CHAN
  ,parameter    dmaEngType_e P_CHANNEL = E_WRITE
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_pop_if.slave_mp          b_ChDbFifo
  ,DWC_pcie_edmapf_genericData_if.master_mp b_ChDbRemSlt
  ,DWC_pcie_edmapf_readyValid_if.slave_mp   b_PushLLCtx
  ,DWC_pcie_edmapf_genericData_if.slave_mp  b_glbCtx
  ,DWC_pcie_edmapf_llFetchNtfy_if.master_mp b_llFetchNtfy
  ,DWC_pcie_edmapf_tlp_if.master_mp         b_rd_ll
  ,DWC_pcie_edmapf_cdmregs_if.slave_mp      cdm
  ,DWC_pcie_edmapf_aclks_if.slave_mp        clk
  ,DWC_pcie_edmapf_ram1p_if.slave_mp        crgbdata
  ,DWC_pcie_edmapf_ram2p_if.master_mp       ll_ram
  ,DWC_pcie_edmapf_readyValid_if.master_mp  non_ll_push
  ,DWC_pcie_edmapf_crPopRdy_if.master_mp    popCtx
  );


// SNPS_SysML_CODE_START
  localparam CX_NFUNC = `CX_NFUNC;
  localparam LP_DMA_LLQWD = (P_CHANNEL == E_WRITE) ? K_DMA_WR_LLQWD : K_DMA_RD_LLQWD;


   typedef struct packed {
    logic               [31:0] stsh_llpHighReg     ; 
    logic               [31:0] stsh_llpLowReg      ; 
    logic               [31:0] ctx_llpHighReg      ;
    logic               [31:0] ctx_llpLowReg       ;
    logic                      ctx_pfo             ;
    logic                      ctx_ccs             ;
    logic                      ctx_Cb              ;
  } dmaCrgbData_s;
  

  typedef logic [LP_DMA_LLQWD-1:0] llNSlots_t;
 
  /*
    Creating an internal version of the interface signal
  */
  glbData_s        [CX_NUM_DMA_CHAN-1:0] s_glbCtx;
  
  /*
    Creating an internal version of the global context interface
  */
  always_comb begin : c_s_glbCtx_PROC
    s_glbCtx = b_glbCtx.w_data;
  end : c_s_glbCtx_PROC

  // Implements the multi-treaded FSM that will handle the descriptor fetch

  // This defines the FSM enumerated states for the fetching FSM
  // RD_RAM: Reading RAM takes 2*CC_IF_CTRL_LL_RAM_PLINE+1
  // RD_STALL: If two simultaneous read stall
  // WR_RAM: Writing takes CC_IF_CTRL_LL_RAM_PLINE+1 (write read sequences smaller than this value must stall)
  // WR_RAM_STALL:  if two simultaneous writes, stalls.
  typedef
    enum logic[3:0]
      { IDLE,
        RD_RAM,
        RD_STALL,
        RD_RAM_WAIT_PLINE,  // Wait for the RAM to responde (pipeline)
        RD_LL,              // Read 1 or more descriptors in one go
        RD_LL_STALL,        // Other requester is stuck by halt, wait here inline
        NLL_PUSH,           // Non linked list mode push
        NLL_PUSH_STALL,     // Non linked list mode stuck
        RD_CTX,             // context popping
        WR_RAM,
        WR_RAM_STALL,
        WR_RAM_CRGB,
        WR_RAM_CRGB_STALL,
        WR_RAM_PUSHLL,      // Pushes the context from the b_PushLLCtx interface
        WR_RAM_PUSHLL_STALL,
        PUSHLL_WAIT_LLNTFY  // Waits on b_llFetchNtfy
        } en_st_ll_fetch;

  typedef struct packed {
    en_st_ll_fetch st_ll_fetch;
    logic          dbfifo_pop;
  } ll_fetch_idle_pop_s;

  // LL Fetch main FSM
  // This FSM is multi.treaded, to overcome the RAM latency in multi-channel
  localparam ST_FETCH_CRGBDATA = (CC_IF_CTRL_LL_RAM_LATENCY+2);
  localparam ST_FETCH_POPCTX   = ST_FETCH_CRGBDATA + 1;
  localparam ST_PUSHLL_CTX     = ST_FETCH_POPCTX + 1;
  localparam L_FSM_COUNT       = ST_PUSHLL_CTX + 1;
  localparam L_FSM_COUNT_WD    = $clog2(L_FSM_COUNT);
  localparam L_ST_PUSHLL_CTX   = $clog2(ST_PUSHLL_CTX + 1);

  en_st_ll_fetch  s_st_el_fetch[0:ST_PUSHLL_CTX], r_st_el_fetch[0:ST_PUSHLL_CTX];


  //The following enumarations defines the type of the aux transaction beeing handled
  typedef enum logic[1:0]{
    DB_OPER  = 0,   //Normal DB operation
    CRGB_REQ = 1,   //CRGB_Request
    POP_CTX  = 2    //Pop context
  } en_fetch_type;

  //Auxiliary FSM signals
  typedef struct packed {
    // Drives the RAM write
    logic                                           ram_write;
    // Drives the RAM read
    logic                                           ram_read;
    // LL reads and Pushing contexts from stsh must be atomic
    logic                                           ram_read_atom;
    // Read pipeline: this is a counter
    logic [$clog2(CC_IF_CTRL_LL_RAM_LATENCY+2):0]   ram_read_pline;
    //Current Channel
    logic [CC_NUM_DMA_CHAN_WIDTH-1:0]               curr_channel;
    // The outstanding descriptors as tracked by doorbell manager
    llNSlots_t                                      dBllNslotsOuts;
    // The tentative DB manager request value
    llNSlots_t                                      dBllNslotsReq;
    // Stores the element prefetch depth value
    llNSlots_t                                      dBelPfetch;
    // Loaded channel context
    logic [LP_DMA_LLQWD-1:0]                        dBllNreads;
    P_LLRAM_TYPE                                    channel_ctx;
    // Flags that the write to the doorbell regsiter is done
    logic                                           llFetchNtfyDone;
  } st_el_fetch_aux;
  st_el_fetch_aux  s_el_fetch_aux[0:ST_PUSHLL_CTX], r_el_fetch_aux[0:ST_PUSHLL_CTX];
  st_el_fetch_aux r_el_fetch_aux_st_fetch_popctx;

  // Detects the an LL was dropped - to speed up error recovery
  logic [CX_NUM_DMA_CHAN-1:0] r_rd_ll_drop, s_rd_ll_drop;


  // ***************************************************
  // Main clock detector - detects main clk missing 
  // with respect to aux_clk
  // ***************************************************

  logic s_main_clk_detect;
  DWC_pcie_edmapf_main_clk_detect
   u_mclk_det(
     .b_clkrst          (clk)
    ,.b_main_clk_detect (s_main_clk_detect)
    );

  // ***************************************************
  // ** This arbiter gives a channel access to the RAM
  // ***************************************************
  logic                           arb_granted;
  logic                           idle_arb_enable;
  logic [L_FSM_COUNT-1:0]         idle_arb_grant;
  logic [L_FSM_COUNT_WD-1:0] nc_grant_index;

  typedef struct packed {
    logic wren;
    logic rden;
  } crgbdata_req_hold_s;

  crgbdata_req_hold_s  r_crgbdata_req_hold, s_crgbdata_req_hold;

  // When the FSM is idle, it's requesting to an arbiter autorization to exit IDLE
  logic [L_FSM_COUNT-1:0] idle_arb_req;
  always_comb begin : PROC_CB_idle_request

    logic  popctx_coll_rdwr;
    popctx_coll_rdwr = '0; //Avoids read writes collisions in the RAM
    foreach (r_st_el_fetch[j]) begin
      if ((r_st_el_fetch[j] == RD_RAM) && 
          (j !=ST_FETCH_POPCTX) && 
          (r_el_fetch_aux[j].curr_channel == popCtx.w_tag)) begin
        popctx_coll_rdwr = '1;
      end
    end

    foreach (s_st_el_fetch[i]) begin
      if (i < ST_FETCH_CRGBDATA)
        idle_arb_req[i] = (s_st_el_fetch[i] == IDLE) && (b_ChDbFifo.w_empty == '0) && s_main_clk_detect;
    end
    idle_arb_req[ST_FETCH_CRGBDATA] = |s_crgbdata_req_hold;
    idle_arb_req[ST_FETCH_POPCTX]   = popCtx.w_pop && (popctx_coll_rdwr == '0);
    idle_arb_req[ST_PUSHLL_CTX]     = b_PushLLCtx.w_valid;

  end
 
  always_ff @ (posedge clk.w_aux_clk or negedge clk.w_reset_n) begin : PROC_FF_crgbdata_req_hold
      if (!clk.w_reset_n) begin
        r_crgbdata_req_hold <= # `TP '0;
      end else begin
        r_crgbdata_req_hold <= # `TP s_crgbdata_req_hold;
      end
  end


  always_comb begin : PROC_cb_crgbdata_req_hold
    if (idle_arb_grant[ST_FETCH_CRGBDATA] || (r_st_el_fetch[ST_FETCH_CRGBDATA] != IDLE))
      s_crgbdata_req_hold = '0; //When the transaction is attended or in progress ignore further requests
    else
      s_crgbdata_req_hold = r_crgbdata_req_hold | {crgbdata.w_wren, crgbdata.w_rden};
  end

  // The Arbiter Mask is used by CRGB to stop any channel CRGB might be working on

  logic [L_FSM_COUNT-1:0]       arb_mask;
  
  logic s_arb_b2b_stop;

  // if the b_rd_ll is back-pressuring do not take any doorbell command
  // this avoids the LL RAM from beeing back-pressured by the  rd ll backpressure 
  // (this coupled with STS handler backpressure can create the conditions for a possible DMA deadlock)
  assign idle_arb_enable = s_arb_b2b_stop ? 
                           '0 : 
                           ((!b_ChDbFifo.w_empty && !b_rd_ll.w_halt) || |s_crgbdata_req_hold || popCtx.w_pop || b_PushLLCtx.w_valid);

  always_comb begin : PROC_CB_arb_mask

    // If FIFO is not empty selects a FSM to process the fifo
    logic [L_FSM_COUNT-1:0] sel0_fsm;
    logic [L_FSM_COUNT-1:0] sel_fsm;

    logic icontinue;

    icontinue = '1;

    foreach (r_st_el_fetch[i]) begin
      if ((r_st_el_fetch[i] == IDLE) && !b_ChDbFifo.w_empty && s_main_clk_detect && !b_rd_ll.w_halt) begin
        sel0_fsm[i] = 1'b1;
      end else if ((r_st_el_fetch[i] == IDLE) && (i==ST_FETCH_CRGBDATA) &&(|s_crgbdata_req_hold)) begin
        sel0_fsm[i] = 1'b1;
      end else if ((r_st_el_fetch[i] == IDLE) && (i==ST_FETCH_POPCTX) && popCtx.w_pop) begin
        sel0_fsm[i] = 1'b1;
      end else if ((r_st_el_fetch[i] == IDLE) && (i == ST_PUSHLL_CTX) && (b_PushLLCtx.w_valid)) begin
        sel0_fsm[i] = 1'b1;
      end else
        sel0_fsm[i] = '0;
    end

    // first 1 hot coded to select
    sel_fsm = '0;

    for (int j=0;j<L_FSM_COUNT;j++) begin
      if ((sel0_fsm[j] == 1'b1) && icontinue) begin
        sel_fsm[j] = 1'b1;
        icontinue = '0;
      end
    end

    //Only search on the internal FSM not the CRGB or context pop / push
    //Excluding CRGB and POP CTX access
    foreach (sel_fsm[k]) begin
      if ((crgbdata.w_addr == b_ChDbFifo.w_data.channel) &&
           crgbdata.w_lock &&
           (k != ST_FETCH_CRGBDATA) &&
           (k != ST_FETCH_POPCTX) &&
           (k != ST_PUSHLL_CTX))

        arb_mask[k] = 1'b1;

      else
        arb_mask[k] =  !sel_fsm[k];
    end
  end


  DWC_pcie_ctl_bcm55
   #(
    .N           (L_FSM_COUNT    ),  // Number of requesters
    .OUTPUT_MODE (1'b1           ),  // Registered
    .INDEX_WIDTH (L_FSM_COUNT_WD ) // Index Width
    ) u_idle_arb( 
     .clk         (clk.w_aux_clk)
    ,.rst_n       (clk.w_reset_n)
     ,.init_n      (1'b1)
    ,.enable      (idle_arb_enable)
    // SMD: Input 'x' of instance 'u_idle_arb' is undriven
    // SJ:  Spyglass is not identifying that signals are actually driven
    // spyglass disable_block W287a
    ,.request     (idle_arb_req)
    ,.mask        (arb_mask)
    ,.granted     (arb_granted)
    //spyglass enable_block W287a
    // SMD: A signal or variable is set but never read
    // SJ: These BCM outputs are not actually required - don't care
    // spyglass disable_block W528
    ,.grant_index (nc_grant_index)
    // spyglass enable_block W528
    ,.grant       (idle_arb_grant)
    );

  // When DB FIFO is almost empty do not pop back 2 back
  assign s_arb_b2b_stop = arb_granted && b_ChDbFifo.w_almEmpty;
  

  always_ff @ (posedge clk.w_aux_clk or negedge clk.w_reset_n) begin : PROC_FF_st_ll_fetch
    if (!clk.w_reset_n) begin
      foreach (r_st_el_fetch[i])
        r_st_el_fetch[i] <= #`TP IDLE;
    end else begin
      foreach (r_st_el_fetch[j])
        r_st_el_fetch[j] <= #`TP s_st_el_fetch[j];
    end
  end
 
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
  ) rd_ll (); 
 
  always_comb begin : PROC_CB_st_ll_fetch
    logic [L_FSM_COUNT-1:0]           goto_rd_stall;
    logic                             only_1_exit_idle;  // Only allow one FSM to exit IDLE at a time
    logic                             only_1_goto_rdll;  // Only allow one FSM to goto RD_LL
    logic                             only_1_goto_nll;
    logic                             go2wr_1st;         // Only allow one FSM to goto to RAM WRITE
    logic [CC_NUM_DMA_CHAN_WIDTH-1:0] rdwr_addr;         // Do not allow read/write to the same address
    logic [CX_NUM_DMA_CHAN-1:0]       db_cherr;         // Alias b_llFetchNtfy.w_db_[app|ll]err
    logic                             rdwr_addr_val;     // Do not allow read/write to the same address (valid)

    rdwr_addr = '0;
    rdwr_addr_val = '0;
   
    b_ChDbFifo.w_pop = 1'b0;
    db_cherr = b_llFetchNtfy.w_db_apperr | b_llFetchNtfy.w_db_llerr | chonehot_f(b_PushLLCtx.w_data.flush & b_PushLLCtx.w_valid, b_PushLLCtx.w_data.reqCh);

    only_1_goto_nll  = 1'b0;
    // SMD: Not all conditions are covered for the combinational logic
    //  SJ: All signals are initialized so no latch is generated 
    // spyglass disable_block AlwaysCombExhaustive-ML 
    foreach(r_st_el_fetch[j]) begin
      s_st_el_fetch[j] = r_st_el_fetch[j];
      goto_rd_stall[j] = (r_st_el_fetch[j] == RD_RAM);
      if (r_st_el_fetch[j] == NLL_PUSH && !non_ll_push.w_ready) 
        only_1_goto_nll = '1;
    end

    // Avoids same channel ram read cross talk
    // Avoids same channel write read at the same time - after RD_LL it goes to WR_RAM
    // Avoids atomicity RAM reads violations
    foreach(r_st_el_fetch[k]) begin
      foreach(r_st_el_fetch[l]) begin
        if (r_el_fetch_aux[k].curr_channel == r_el_fetch_aux[l].curr_channel && (r_st_el_fetch[k] == RD_RAM || r_st_el_fetch[k] == RD_RAM_WAIT_PLINE || r_st_el_fetch[k] == RD_LL && !rd_ll.w_halt || r_el_fetch_aux[k].ram_read_atom))
          if (k!=l)
            goto_rd_stall[l] = '1;
      end
    end

    only_1_exit_idle = 1'b0;
    only_1_goto_rdll = 1'b0;
    go2wr_1st        = 1'b0;

    foreach (r_st_el_fetch[i]) begin
      case (r_st_el_fetch[i])
        IDLE: begin

          if (only_1_exit_idle == 1'b0) begin
            {s_st_el_fetch[i], b_ChDbFifo.w_pop} =  st_el_fetch_idle_f(i, goto_rd_stall, go2wr_1st, IDLE, idle_arb_grant, r_crgbdata_req_hold, b_PushLLCtx.w_valid, b_PushLLCtx.w_data.reqCh, r_el_fetch_aux, rdwr_addr, rdwr_addr_val, s_el_fetch_aux[i].curr_channel);
          end else begin
            s_st_el_fetch[i] = IDLE;
          end

          if (s_st_el_fetch[i] == WR_RAM_CRGB)
            go2wr_1st = '1;
          // Only one FSM can exit IDLE at a time
          // if not true multiple calls to st_el_fetch_idle_f will undo the FIFO request
          if (s_st_el_fetch[i] != IDLE)
            only_1_exit_idle = 1'b1;

        end
        RD_RAM: begin
          //Wait for the data made available after the pipeline
          s_st_el_fetch[i] = RD_RAM_WAIT_PLINE;
        end
        RD_STALL: begin
          //If any of the state machines is trying to go to RD_RAM, give up
          //Note: this implicity is a strict priority arbiter
          if (|goto_rd_stall == '0) begin
            s_st_el_fetch[i] = RD_RAM;
          end else begin
            s_st_el_fetch[i] = RD_STALL;
          end
        end
        RD_RAM_WAIT_PLINE: begin
          if (r_el_fetch_aux[i].ram_read_pline == 0) begin
            if ((i != ST_FETCH_CRGBDATA) && (i != ST_FETCH_POPCTX) && (i != ST_PUSHLL_CTX)) begin
              if (s_glbCtx[r_el_fetch_aux[i].curr_channel].ll_en) begin

                if ((rd_ll.w_halt && !db_cherr[r_el_fetch_aux[i].curr_channel]) || only_1_goto_rdll)
                  s_st_el_fetch[i] = RD_LL_STALL;
                else begin
                  s_st_el_fetch[i] = RD_LL;
                  only_1_goto_rdll = '1;
                end

              end else begin
                s_st_el_fetch[i] = only_1_goto_nll ? NLL_PUSH_STALL : NLL_PUSH;
                only_1_goto_nll  = '1;
              end
            end else if (i == ST_FETCH_POPCTX)
              s_st_el_fetch[i] = RD_CTX;
            else if (i == ST_PUSHLL_CTX) begin
              s_st_el_fetch[i] = WR_RAM_PUSHLL;
            end else
              s_st_el_fetch[i] = IDLE;
          end
        end
        RD_LL: begin
          if (!rd_ll.w_halt)
            s_st_el_fetch[i] = WR_RAM;
        end
        RD_LL_STALL: begin
          if ((only_1_goto_rdll == '0) && (!rd_ll.w_halt || db_cherr[r_el_fetch_aux[i].curr_channel])) begin
            s_st_el_fetch[i] = RD_LL;
            only_1_goto_rdll = '1;
          end else begin
            s_st_el_fetch[i] = r_st_el_fetch[i];
          end
        end
        NLL_PUSH_STALL: begin
          s_st_el_fetch[i] = only_1_goto_nll ? NLL_PUSH_STALL : NLL_PUSH;
          only_1_goto_nll = '1;
        end
        NLL_PUSH: begin
          if (non_ll_push.w_ready) begin
            s_st_el_fetch[i] = WR_RAM;
          end
        end
        WR_RAM_STALL : begin
          s_st_el_fetch[i] = WR_RAM;
        end
        WR_RAM_CRGB_STALL: begin
          s_st_el_fetch[i] = WR_RAM_CRGB;
        end
        WR_RAM_PUSHLL_STALL: begin
          s_st_el_fetch[i] = WR_RAM_PUSHLL;
        end
        WR_RAM, WR_RAM_CRGB, RD_CTX: begin
          s_st_el_fetch[i] = IDLE;
        end
        WR_RAM_PUSHLL: begin
          if (i == ST_PUSHLL_CTX && !r_el_fetch_aux[i].llFetchNtfyDone)
            s_st_el_fetch[i] = PUSHLL_WAIT_LLNTFY;
          else
            s_st_el_fetch[i] = IDLE;
        end
        PUSHLL_WAIT_LLNTFY: begin
          if (r_el_fetch_aux[i].llFetchNtfyDone)
            s_st_el_fetch[i] = IDLE;
        end
        default: begin
          s_st_el_fetch[i] = IDLE;
        end
      endcase
      // only one state can be RD_RAM in a single time
      if (s_st_el_fetch[i] == RD_RAM)
        goto_rd_stall[i] = '1;

      if (go2wr_1st || (rdwr_addr_val && rdwr_addr == s_el_fetch_aux[i].curr_channel)) begin
        if (s_st_el_fetch[i] == WR_RAM       ) s_st_el_fetch[i] = WR_RAM_STALL        ;
        if (s_st_el_fetch[i] == WR_RAM_CRGB  ) s_st_el_fetch[i] = WR_RAM_CRGB_STALL   ;
        if (s_st_el_fetch[i] == WR_RAM_PUSHLL) s_st_el_fetch[i] = WR_RAM_PUSHLL_STALL ;
      end
      if (s_st_el_fetch[i] inside {WR_RAM_CRGB, WR_RAM_PUSHLL, WR_RAM}) begin
        go2wr_1st = '1;
      end
      //Detecs possible read and write colisions in the RAM
      if (s_st_el_fetch[i] inside {RD_RAM, WR_RAM_CRGB, WR_RAM_PUSHLL, WR_RAM}) begin
        rdwr_addr_val = '1;
        rdwr_addr = s_el_fetch_aux[i].curr_channel;
      end

    end
    // spyglass enable_block AlwaysCombExhaustive-ML
  end // block: PROC_CB_st_ll_fetch



  function automatic logic [CX_NUM_DMA_CHAN-1:0] chonehot_f;
    input logic                             valid;
    input logic [CC_NUM_DMA_CHAN_WIDTH-1:0] ch;
    begin
      logic [CX_NUM_DMA_CHAN-1:0] chonehot;
      chonehot = '0;
      foreach(chonehot[i]) begin
        if ((i == ch) && valid)
          chonehot[i] = 1'b1;
      end

      return chonehot;
    end
  endfunction

  function automatic ll_fetch_idle_pop_s st_el_fetch_idle_f;
    input int  i;
    input logic [L_FSM_COUNT-1:0]           goto_rd_stall;
    input logic                             goto_wr_stall;
    input en_st_ll_fetch                    curr_state;
    input logic [L_FSM_COUNT-1:0]           idle_arb_grant;
    input crgbdata_req_hold_s               crgbdata_req_hold;
    input logic                             pushllctx;
    input logic [CC_NUM_DMA_CHAN_WIDTH-1:0] pushllctx_ch;
    input st_el_fetch_aux                   el_fetch_aux[0:ST_PUSHLL_CTX];
    input logic [CC_NUM_DMA_CHAN_WIDTH-1:0] rdwr_addr;
    input logic                             rdwr_addr_val;
    input logic [CC_NUM_DMA_CHAN_WIDTH-1:0] rdwr_addr_fetch_aux;
    logic              [L_FSM_COUNT_WD-1:0] idle_arb_grant_indx;
    begin

      ll_fetch_idle_pop_s st_el_fetch_idle;
      idle_arb_grant_indx = (L_FSM_COUNT_WD)'(i);

      if ((i == ST_FETCH_CRGBDATA) && idle_arb_grant[idle_arb_grant_indx]) begin

        st_el_fetch_idle.dbfifo_pop = '0;

        if (crgbdata_req_hold.wren)
          st_el_fetch_idle.st_ll_fetch = goto_wr_stall ? WR_RAM_CRGB_STALL: WR_RAM_CRGB;
        else if (crgbdata_req_hold.rden)
          st_el_fetch_idle.st_ll_fetch = |goto_rd_stall ? RD_STALL : RD_RAM;
        else
          st_el_fetch_idle.st_ll_fetch = IDLE;

      end else if ((i == ST_FETCH_POPCTX) && idle_arb_grant[idle_arb_grant_indx]) begin

        st_el_fetch_idle.dbfifo_pop = '0;
        st_el_fetch_idle.st_ll_fetch = |goto_rd_stall ? RD_STALL : RD_RAM;

      end else if ((i == ST_PUSHLL_CTX) && idle_arb_grant[idle_arb_grant_indx]) begin

        st_el_fetch_idle.dbfifo_pop = '0;
        if (pushllctx)
          st_el_fetch_idle.st_ll_fetch = |goto_rd_stall ? RD_STALL : RD_RAM;
        else
          st_el_fetch_idle.st_ll_fetch = IDLE;

        foreach (el_fetch_aux[i]) begin
          if (el_fetch_aux[i].ram_read_atom && (el_fetch_aux[i].curr_channel == pushllctx_ch)) begin
            st_el_fetch_idle.st_ll_fetch = IDLE;
          end
        end

      end else if (idle_arb_grant[idle_arb_grant_indx]) begin

        st_el_fetch_idle.st_ll_fetch = |goto_rd_stall ? RD_STALL : RD_RAM;
        st_el_fetch_idle.dbfifo_pop = '1;

        foreach (el_fetch_aux[i]) begin
          if (el_fetch_aux[i].ram_read_atom && (el_fetch_aux[i].curr_channel == pushllctx_ch)) begin
            st_el_fetch_idle.st_ll_fetch = IDLE;
            st_el_fetch_idle.dbfifo_pop  = '0;
          end
        end 

      end else begin
        st_el_fetch_idle.st_ll_fetch = curr_state;
        st_el_fetch_idle.dbfifo_pop = '0;
      end

      // Avoids read and write collision
      if (rdwr_addr_val && (rdwr_addr == rdwr_addr_fetch_aux)) begin
        if (st_el_fetch_idle.st_ll_fetch == RD_RAM)
          st_el_fetch_idle.st_ll_fetch = RD_STALL;
        
        if (st_el_fetch_idle.st_ll_fetch == WR_RAM_CRGB)
          st_el_fetch_idle.st_ll_fetch = WR_RAM_CRGB_STALL;
        
        if (st_el_fetch_idle.st_ll_fetch== WR_RAM_PUSHLL)
          st_el_fetch_idle.st_ll_fetch = WR_RAM_PUSHLL_STALL;

        if (st_el_fetch_idle.st_ll_fetch== WR_RAM)
          st_el_fetch_idle.st_ll_fetch= WR_RAM_STALL;
      end

      return st_el_fetch_idle;
    end
  endfunction

  // **************************************
  // * Function to calculate the read size
  // * of the descriptor
  // **************************************

  function automatic logic [12:0] get_nxt_ll_size_bytes_f(
                                                          llNSlots_t next_ll_fetchq_slots
                                                          );
    begin
      logic [7:0] pf;
      logic [(3*`CX_NFUNC)-1:0] cfg_max_payload_size;          
      logic [(3*`CX_NFUNC)-1:0] cfg_max_rd_req_size;           
      logic [2:0]               cfg_remote_rd_req_bridge_size; 

      logic [12:0] max_rd_len_bytes;
      logic [12:0] max_rd_req_bytes; //Maximum read request size
      logic [12:0] max_rd_rem_bytes; //remainder, because descriptor size is not aligned with data width
      logic [12:0] next_ll_fetchq_slots_bytes;

      next_ll_fetchq_slots_bytes = next_ll_fetchq_slots * 12'd24;

      //`ifndef SYNHTESIS
      //  $display("[%t]:next_ll_fetchq_slots_bytes = %h", $time, next_ll_fetchq_slots_bytes);
      //`endif
 
      pf = '0;
      case (`CX_MAX_MTU)
        default: cfg_remote_rd_req_bridge_size = 3'b000;
        16'd256: cfg_remote_rd_req_bridge_size = 3'b001;
        16'd512: cfg_remote_rd_req_bridge_size = 3'b010;
        16'd1024:cfg_remote_rd_req_bridge_size = 3'b011;
        16'd2048:cfg_remote_rd_req_bridge_size = 3'b100;
        16'd4096:cfg_remote_rd_req_bridge_size = 3'b101;
      endcase
      cfg_max_payload_size = '0;
      cfg_max_rd_req_size  = '0;
      cfg_max_payload_size[2:0] = cfg_remote_rd_req_bridge_size;
      cfg_max_rd_req_size[2:0]  = cfg_remote_rd_req_bridge_size;

      max_rd_req_bytes = dmactrl_max_pload_calc
                         (
                           .WRITE_CH_NOT_READ_CH(1'b1), //always targeted at the bridge
                           .pf(pf),
                           .cfg_max_payload_size((3*`CX_NFUNC)'(cfg_max_payload_size)),
                           .cfg_max_rd_req_size ((3*`CX_NFUNC)'(cfg_max_rd_req_size)),
                           .cfg_remote_rd_req_bridge_size(cfg_remote_rd_req_bridge_size)
                           );
      //`ifndef SYNHTESIS
      //  $display("[%t]:max_rd_req_bytes= %h", $time, max_rd_req_bytes);
      //`endif 

      max_rd_rem_bytes = dmactrl_max_pload_calc
                         (
                           .WRITE_CH_NOT_READ_CH(1'b1), //always targeted at the bridge
                           .pf(pf),
                           .cfg_max_payload_size((3*`CX_NFUNC)'(cfg_max_payload_size)),
                           .cfg_max_rd_req_size ((3*`CX_NFUNC)'(cfg_max_rd_req_size)),
                           .cfg_remote_rd_req_bridge_size(cfg_remote_rd_req_bridge_size)
                           ) % 'd24;
      //`ifndef SYNHTESIS
      //  $display("[%t]:max_rd_rem_bytes= %h", $time, max_rd_rem_bytes);
      //`endif 
 
      max_rd_len_bytes = 13'(max_rd_req_bytes - max_rd_rem_bytes);
 
      //`ifndef SYNHTESIS
      //  $display("[%t]:max_rd_len_bytes= %h", $time, max_rd_len_bytes);
      //`endif 
 
      //Picks the minimum
      get_nxt_ll_size_bytes_f = (next_ll_fetchq_slots_bytes > max_rd_len_bytes) ?
                              max_rd_len_bytes :
                              next_ll_fetchq_slots_bytes;

      //`ifndef SYNHTESIS
      //  $display("[%t]:get_nxt_ll_size_bytes_f = %h", $time, get_nxt_ll_size_bytes_f);
      //`endif


    end
  endfunction

  // ***********************************************
  // Auxiliary fetch FSM control signals
  // ***********************************************
  dmaCrgbData_s crgb_din_ctx; // This must be translated to / from crgb_data


  assign crgbdata.w_rdone =  (r_st_el_fetch[ST_FETCH_CRGBDATA] == RD_RAM_WAIT_PLINE) &&
                             (r_el_fetch_aux[ST_FETCH_CRGBDATA].ram_read_pline == '0);


  always_ff @(posedge clk.w_aux_clk or negedge clk.w_reset_n) begin : crgbdata_wdone_PROC
    if (!clk.w_reset_n) begin
      crgbdata.w_wdone <= #`TP '0;
    end else begin
      if (r_st_el_fetch[ST_FETCH_CRGBDATA] == WR_RAM_CRGB) begin
      crgbdata.w_wdone <= #`TP '1;
      end else begin
      crgbdata.w_wdone <= #`TP '0;
      end
    end
  end

  // doorbell manager LL channels error status sticky (invalidated by app errors)
  // a doorbell evenet clears it out
  // this is used to select between ctx_llp[high|low]Reg or stsh_llp[High|Low]Reg
  logic [CX_NUM_DMA_CHAN-1:0] r_dbm_llcherr_sticky;
  always_ff @(posedge clk.w_main_clk or negedge clk.w_reset_n) begin : PROC_ff_dmb_llcherr_sticky
    if (!clk.w_reset_n) begin
      r_dbm_llcherr_sticky <= # `TP '0;
    end else begin
      foreach (r_dbm_llcherr_sticky[i]) begin
        if (((i ==b_ChDbFifo.w_data.channel) && !b_ChDbFifo.w_empty) || b_llFetchNtfy.w_db_apperr[i] || b_llFetchNtfy.w_db_llerr[i])
          r_dbm_llcherr_sticky[i] <= # `TP '0;
        else if (b_llFetchNtfy.w_db_llerr[i] && !(b_llFetchNtfy.w_db_apperr[i] || b_llFetchNtfy.w_db_llerr[i]))
          r_dbm_llcherr_sticky[i] <= # `TP '1;
      end
    end
  end

  function automatic logic [95:0] crgb_get_dout_f 
    (
      input logic [CC_NUM_DMA_CHAN_WIDTH-1:0] crgb_addr,
      input logic  [CC_IF_CTRL_LL_RAM_WD-1:0] llram_doutb,
      input logic       [CX_NUM_DMA_CHAN-1:0] db_chstRun,
      input logic       [CX_NUM_DMA_CHAN-1:0] db_llcherr_sticky
      ); 
    crgb_get_dout_f = '0;
    crgb_get_dout_f[2:0] = llram_doutb[2:0];
    if (db_llcherr_sticky[crgb_addr] || db_chstRun[crgb_addr] == '0)
      crgb_get_dout_f[66:3] = llram_doutb[66:3];
    else
      crgb_get_dout_f[66:3] = llram_doutb[130:67];
  endfunction

  assign crgbdata.w_dout = crgb_get_dout_f(
    .crgb_addr         (crgbdata.w_addr),
    .llram_doutb       (ll_ram.w_doutb),
    .db_chstRun        (b_llFetchNtfy.w_db_chstRun),
    .db_llcherr_sticky (r_dbm_llcherr_sticky)
    );


  always_comb begin : PROC_CB_crgb_din
    crgb_din_ctx.stsh_llpHighReg = crgbdata.w_din[66:35];
    crgb_din_ctx.stsh_llpLowReg  = crgbdata.w_din[34:3]; 
    crgb_din_ctx.ctx_llpHighReg  = crgbdata.w_din[66:35];
    crgb_din_ctx.ctx_llpLowReg   = crgbdata.w_din[34:3];
    crgb_din_ctx.ctx_pfo         = crgbdata.w_din[2];
    crgb_din_ctx.ctx_ccs         = crgbdata.w_din[1];
    crgb_din_ctx.ctx_Cb          = crgbdata.w_din[0];

  end

  always_comb begin : PROC_CB_el_fetch_aux
    logic tmp_carry;

    // SMD: A signal or variable is set but never read  
    // SJ:  Carry is used to make arithmetric widths match, but not used 
    // spyglass disable_block W528
    tmp_carry   = '0;
    // spyglass enable_block W528


    foreach(s_el_fetch_aux[i]) begin
      st_el_fetch_aux s_el_fetch_aux_i;
      st_el_fetch_aux r_el_fetch_aux_i;
      s_el_fetch_aux_i = r_el_fetch_aux[i];
      r_el_fetch_aux_i = r_el_fetch_aux[i];

      s_el_fetch_aux_i.ram_write = '0;
      s_el_fetch_aux_i.ram_read  = '0;

      s_el_fetch_aux_i.ram_write = (s_st_el_fetch[i] == WR_RAM) ||
                                   (s_st_el_fetch[i] == WR_RAM_CRGB) ||
                                   (s_st_el_fetch[i] == WR_RAM_PUSHLL);

      s_el_fetch_aux_i.ram_read  = (s_st_el_fetch[i] == RD_RAM);

      s_el_fetch_aux_i.ram_read_atom = r_el_fetch_aux_i.ram_read_atom;
      if (s_el_fetch_aux_i.ram_read)
        s_el_fetch_aux_i.ram_read_atom = '1;


      // CRGB and POPCTX do not need atomicity
      if (s_el_fetch_aux_i.ram_write || (i == ST_FETCH_CRGBDATA || i == ST_FETCH_POPCTX))
        s_el_fetch_aux_i.ram_read_atom = '0;

      if (i == ST_FETCH_CRGBDATA) begin
        s_el_fetch_aux_i.curr_channel = (crgbdata.w_rden || crgbdata.w_wren) ? 
                                        crgbdata.w_addr :
                                        r_el_fetch_aux_i.curr_channel;
      end else if (i == ST_FETCH_POPCTX) begin
        s_el_fetch_aux_i.curr_channel = (popCtx.w_pop && popCtx.w_ready) ? popCtx.w_tag : r_el_fetch_aux_i.curr_channel;
      end else if (i == ST_PUSHLL_CTX) begin
        s_el_fetch_aux_i.curr_channel = (b_PushLLCtx.w_valid) ? b_PushLLCtx.w_data.reqCh : r_el_fetch_aux_i.curr_channel;
      end else begin
        // Loads from doorbell manager the next channel
        s_el_fetch_aux_i.curr_channel = idle_arb_grant[i] ?
                                        b_ChDbFifo.w_data.channel :
                                        r_el_fetch_aux_i.curr_channel;

      end

      // ** Handles pipelining
      s_el_fetch_aux_i.ram_read_pline = r_el_fetch_aux_i.ram_read_pline;
      if (s_st_el_fetch[i] == RD_RAM)
        s_el_fetch_aux_i.ram_read_pline = (CC_IF_CTRL_LL_RAM_LATENCY+2);
      else if ((|r_el_fetch_aux_i.ram_read_pline)) //If not zero, decrement
        s_el_fetch_aux_i.ram_read_pline = r_el_fetch_aux_i.ram_read_pline - 1;
      // **

      // ** Handles context
      s_el_fetch_aux_i.channel_ctx = r_el_fetch_aux_i.channel_ctx;
      if (r_st_el_fetch[i] == IDLE && ((s_st_el_fetch[i] == RD_RAM) || (s_st_el_fetch[i] == RD_STALL))) begin//Initialize on a read start
        // Loads from doorbell manager the number of slots available to store descriptors
        if (s_glbCtx[s_el_fetch_aux_i.curr_channel].ll_en) begin// only used in linked list enable

          s_el_fetch_aux_i.dBllNslotsOuts    = b_ChDbFifo.w_data.llNslotsOuts;
          s_el_fetch_aux_i.dBllNslotsReq     = b_ChDbFifo.w_data.llNslotsReq;
          s_el_fetch_aux_i.dBelPfetch        = b_ChDbFifo.w_data.ElPfetch;
          s_el_fetch_aux_i.dBllNreads        = b_ChDbFifo.w_data.llNreads;

        end 

      end else if (((s_st_el_fetch[i] == NLL_PUSH) || (s_st_el_fetch[i] == NLL_PUSH_STALL) || (s_st_el_fetch[i] == RD_LL) || (s_st_el_fetch[i] == RD_LL_STALL)) && (r_st_el_fetch[i] == RD_RAM_WAIT_PLINE)) begin
        s_el_fetch_aux_i.channel_ctx = ll_ram.w_doutb;
        // these will update RAM, so do not let RAM overwrite it
        s_el_fetch_aux_i.channel_ctx.db_llNslotsOutStd    = r_el_fetch_aux_i.channel_ctx.db_llNslotsOutStd;
        s_el_fetch_aux_i.channel_ctx.db_llNslotsOutStdLst = r_el_fetch_aux_i.channel_ctx.db_llNslotsOutStdLst;
        s_el_fetch_aux_i.channel_ctx.db_llNreads          = r_el_fetch_aux_i.channel_ctx.db_llNreads;
      end else if (((s_st_el_fetch[i] == RD_CTX) || (s_st_el_fetch[i] == IDLE)) && (r_st_el_fetch[i] == RD_RAM_WAIT_PLINE)) begin
        s_el_fetch_aux_i.channel_ctx = ll_ram.w_doutb;
      end else if ((s_st_el_fetch[i] == WR_RAM) && (s_glbCtx[r_el_fetch_aux_i.curr_channel].ll_en)) begin
        // Increment the Linked List Pointer in the RAM

        //do not update LL trackers in RAM if the LL was dropped
        //do not update address if the LL was dropped
        //The number of descriptors and number of single reads (each containing one or more descriptors is updated
        if (!s_rd_ll_drop[r_el_fetch_aux_i.curr_channel]) begin
          s_el_fetch_aux_i.channel_ctx.db_llNslotsOutStd    = r_el_fetch_aux_i.dBllNslotsOuts + llNSlots_t'(get_nxt_ll_size_bytes_f(r_el_fetch_aux_i.dBllNslotsReq) / 'd24);
          s_el_fetch_aux_i.channel_ctx.db_llNreads          = r_el_fetch_aux_i.dBllNreads + 'd1;
          if (s_el_fetch_aux_i.channel_ctx.db_llNslotsOutStd  >  r_el_fetch_aux_i.dBelPfetch)
            s_el_fetch_aux_i.channel_ctx.db_llNslotsOutStdLst = '1;
          else
            s_el_fetch_aux_i.channel_ctx.db_llNslotsOutStdLst = '0;
 
          // SMD: A signal or variable is set but never read                  
          // SJ:  Carry is used to make arithmetric widths match, but not used.
          // An overflow LL memory is possible, but it's under software control
          // spyglass disable_block W528
          {tmp_carry, s_el_fetch_aux_i.channel_ctx.ctx_llpHighReg ,
            s_el_fetch_aux_i.channel_ctx.ctx_llpLowReg}
            = {1'b0, r_el_fetch_aux_i.channel_ctx.ctx_llpHighReg ,
              r_el_fetch_aux_i.channel_ctx.ctx_llpLowReg} +
            get_nxt_ll_size_bytes_f(r_el_fetch_aux_i.dBllNslotsReq);
          // spyglass enable_block W528
        end
 
      end else if (s_st_el_fetch[i] == WR_RAM_CRGB) begin

        s_el_fetch_aux_i.channel_ctx = ll_ram.w_doutb;
        s_el_fetch_aux_i.channel_ctx = P_LLRAM_TYPE'(crgb_din_ctx);

      end else if ((r_st_el_fetch[i] == RD_RAM_WAIT_PLINE) && ((s_st_el_fetch[i] == WR_RAM_PUSHLL) || (s_st_el_fetch[i] == WR_RAM_PUSHLL_STALL))) begin

        s_el_fetch_aux_i.channel_ctx = ll_ram.w_doutb;
        if (b_PushLLCtx.w_data.ctxElem.ovrl.token) begin
          //Update the stsh LL pointer if the LL is from STShanlder (token set)
          s_el_fetch_aux_i.channel_ctx.stsh_llpHighReg= b_PushLLCtx.w_data.ctxElem.ovrl.llData.elemPtrHigh;
          s_el_fetch_aux_i.channel_ctx.stsh_llpLowReg = b_PushLLCtx.w_data.ctxElem.ovrl.llData.elemPtrLow;
          // update also the ctx LL pointer when it detects a app error (non-LL error)
          if ((b_PushLLCtx.w_data.ctxElem.ovrl.errors inside {E_DMAERR_DATA_CPL_TIMEOUT ,E_DMAERR_DATA_CPL_UR, E_DMAERR_DATA_CPL_CA, E_DMAERR_DATA_CPL_EP, E_DMAERR_DATA_MWR }) || b_PushLLCtx.w_data.ctxElem.ovrl.stop) begin
            s_el_fetch_aux_i.channel_ctx.ctx_llpHighReg = b_PushLLCtx.w_data.ctxElem.ovrl.llData.elemPtrHigh;
            s_el_fetch_aux_i.channel_ctx.ctx_llpLowReg  = b_PushLLCtx.w_data.ctxElem.ovrl.llData.elemPtrLow; 
          end
        end else begin
          //Update the ctx LL pointer if the LL is from the a LL request
          s_el_fetch_aux_i.channel_ctx.ctx_llpHighReg = b_PushLLCtx.w_data.ctxElem.ovrl.llData.elemPtrHigh;
          s_el_fetch_aux_i.channel_ctx.ctx_llpLowReg  = b_PushLLCtx.w_data.ctxElem.ovrl.llData.elemPtrLow;
        end
        // only update the CCS/CB when it comes from a Linked List Processing (not STSH's token)
        // or when there's a context rollback due to an error in a transfer
        if (!b_PushLLCtx.w_data.ctxElem.ovrl.token || (b_PushLLCtx.w_data.ctxElem.ovrl.errors inside {E_DMAERR_DATA_CPL_TIMEOUT ,E_DMAERR_DATA_CPL_UR, E_DMAERR_DATA_CPL_CA, E_DMAERR_DATA_CPL_EP, E_DMAERR_DATA_MWR }) || b_PushLLCtx.w_data.ctxElem.ovrl.stop) begin 
          s_el_fetch_aux_i.channel_ctx.ctx_pfo          = b_PushLLCtx.w_data.ctxElem.ovrl.llData.pfOvrl ? '1 : r_el_fetch_aux_i.channel_ctx.ctx_pfo;
          s_el_fetch_aux_i.channel_ctx.ctx_ccs          = b_PushLLCtx.w_data.ctxElem.ovrl.llData.ccs;
          s_el_fetch_aux_i.channel_ctx.ctx_Cb           = b_PushLLCtx.w_data.ctxElem.ovrl.llData.cb;
        end

      end

      if (i != ST_PUSHLL_CTX)
        s_el_fetch_aux_i.llFetchNtfyDone = '0;
      else begin
        if (s_st_el_fetch[i] == IDLE)
          s_el_fetch_aux_i.llFetchNtfyDone = '0;
        else if ((b_llFetchNtfy.w_elPfetchReady && b_llFetchNtfy.w_elPfetchValid) || (b_PushLLCtx.w_valid != b_llFetchNtfy.w_elPfetchValid))
          s_el_fetch_aux_i.llFetchNtfyDone = '1;
        else
          s_el_fetch_aux_i.llFetchNtfyDone = r_el_fetch_aux_i.llFetchNtfyDone;
      end

      s_el_fetch_aux[i] = s_el_fetch_aux_i;

    end


  end // block: PROC_CB_el_fetch_aux

  always_ff @ (posedge clk.w_aux_clk or negedge clk.w_reset_n) begin : PROC_FF_el_fetch_aux
    if (!clk.w_reset_n) begin
      foreach(s_el_fetch_aux[i])
        r_el_fetch_aux[i] <= # `TP '0;
    end else begin
      foreach(s_el_fetch_aux[j])
        r_el_fetch_aux[j] <= # `TP s_el_fetch_aux[j];
    end
  end


  // ************************************************
  // Drives the doorbell manager el prefetch register
  // ************************************************
  always_comb begin : PROC_CB_llFetchNtfy
    // Updates the prefetch when processing a linked list pointer
    // Updates (roll back) the the prefetch when an error is detectd on data transfer
    if (b_PushLLCtx.w_data.ctxElem.ovrl.token) begin
      b_llFetchNtfy.w_elPfetchValid = b_PushLLCtx.w_valid && b_PushLLCtx.w_data.desc_valid && (|b_PushLLCtx.w_data.ctxElem.ovrl.errors || b_PushLLCtx.w_data.ctxElem.ovrl.stop) && !r_el_fetch_aux[ST_PUSHLL_CTX].llFetchNtfyDone;
    end else begin                                                                                                                                                                      
      b_llFetchNtfy.w_elPfetchValid = b_PushLLCtx.w_valid && b_PushLLCtx.w_data.desc_valid && b_PushLLCtx.w_data.ElemOvrl_LLP && !r_el_fetch_aux[ST_PUSHLL_CTX].llFetchNtfyDone; 
    end
  end

  assign b_llFetchNtfy.w_elPfetchCh    = b_PushLLCtx.w_data.reqCh;
  assign b_llFetchNtfy.w_elPfetch      = b_PushLLCtx.w_data.ctxElem.ovrl.llData.elemPf;

  logic [CX_NUM_DMA_CHAN-1:0] s_db_chsch_mask,
                              r_db_chsch_mask;
  always_comb begin : PROC_CB_chsch_mask
    s_db_chsch_mask = '0;
    foreach (s_db_chsch_mask[i]) begin
      if (i == b_PushLLCtx.w_data.reqCh && b_PushLLCtx.w_valid)
        s_db_chsch_mask[i] = '1;
    end

  end
   always_ff @ (posedge clk.w_main_clk or negedge clk.w_reset_n) begin : PROC_FF_chsch_mask
    if (!clk.w_reset_n)
      r_db_chsch_mask <= # `TP '0;
    else
      r_db_chsch_mask <= # `TP s_db_chsch_mask;
  end
 
  //If halting from interface stop the scheduler
  //if main clock is not available, stop the scheduler
  assign b_llFetchNtfy.w_db_chsch_mask = r_db_chsch_mask | 
                                         {CX_NUM_DMA_CHAN{b_rd_ll.w_halt}} |
                                         ~{CX_NUM_DMA_CHAN{s_main_clk_detect}};


  always_comb begin : PROC_CB_chstwatermark
    logic [CX_NUM_DMA_CHAN-1:0] chstWaterMark;
    foreach (chstWaterMark[i]) begin
      chstWaterMark[i] = b_PushLLCtx.w_valid && b_PushLLCtx.w_ready && 
                         b_PushLLCtx.w_data.ctxElem.ovrl.token && !b_PushLLCtx.w_data.ctxElem.ovrl.stop &&
                         |b_PushLLCtx.w_data.ctxElem.ovrl.ovrlData.watermarkEn && 
                         b_PushLLCtx.w_data.ctxElem.ovrl.ovrlData.xferSize == '0 && 
                         b_PushLLCtx.w_data.reqCh == i;
    end

    b_llFetchNtfy.w_chstWaterMark = chstWaterMark;
  end

  // **************************************
  // Drives the RAM outputs signals
  // **************************************
  // RAM: To save power retains the last address and data signals
  typedef struct packed
                 {
                   logic [CC_NUM_DMA_CHAN_WIDTH-1:0] addrb  ;
                   logic [CC_IF_CTRL_LL_RAM_WD-1:0]  dina   ;
                   logic [CC_NUM_DMA_CHAN_WIDTH-1:0] addra  ;
                 } st_ramout_regs;

  st_ramout_regs r_ramout_regs;

  always_ff @ (posedge clk.w_aux_clk or negedge clk.w_reset_n) begin : PROC_FF_ramout
    if (!clk.w_reset_n) begin
      r_ramout_regs <= #`TP '0;
    end else begin
      r_ramout_regs.addra <=  #`TP ll_ram.w_addra;
      r_ramout_regs.addrb <=  #`TP ll_ram.w_addrb;
      r_ramout_regs.dina  <=  #`TP ll_ram.w_dina;
    end
  end

  always_comb begin : PROC_cb_drive_ram_ll
    logic [CC_IF_CTRL_LL_RAM_WD:0] width_adapt;
    ll_ram.w_wea = 1'b0;
    ll_ram.w_ena = 1'b0;
    ll_ram.w_enb = 1'b0;


    //Keeps the previous value to save power
    ll_ram.w_addra = r_ramout_regs.addra;
    ll_ram.w_addrb = r_ramout_regs.addrb;
    ll_ram.w_dina  = r_ramout_regs.dina;

    foreach (r_el_fetch_aux[i]) begin
      width_adapt = r_el_fetch_aux[i].channel_ctx;
      if (r_el_fetch_aux[i].ram_write) begin
        ll_ram.w_wea = 1'b1;
        ll_ram.w_ena = 1'b1;
        ll_ram.w_addra = r_el_fetch_aux[i].curr_channel;
        ll_ram.w_dina  = r_el_fetch_aux[i].channel_ctx;
      end
      if (r_el_fetch_aux[i].ram_read) begin
        ll_ram.w_enb = 1'b1;
        ll_ram.w_addrb = r_el_fetch_aux[i].curr_channel;
      end
    end
  end




  // **************************************
  // Drive the read ll (xradm) interface
  // **************************************

  always_comb begin : PROC_comb_rd_ll
    int ptr;
    logic icontinue;
    logic s_reqValid;
    // This is the maximum size allowed to fetch a descriptor
    logic     [12:0]                rd_ll_max_size_bytes; 
    st_el_fetch_aux                 r_el_fetch_aux_ptr;
    logic     [CX_NUM_DMA_CHAN-1:0] db_cherr;// Alias b_llFetchNtfy.w_db_[app|ll]err 
    logic     [CX_NUM_DMA_CHAN-1:0] filterCh;
    glbData_s [CX_NUM_DMA_CHAN-1:0] i_glbCtx;
    logic     [L_ST_PUSHLL_CTX-1:0] ptr_indx;

    db_cherr = b_llFetchNtfy.w_db_apperr | b_llFetchNtfy.w_db_llerr | chonehot_f(b_PushLLCtx.w_data.flush & b_PushLLCtx.w_valid, b_PushLLCtx.w_data.reqCh); 

    filterCh = b_llFetchNtfy.w_chFilter;
    
    ptr = '0;
    icontinue = '1;
    foreach(r_st_el_fetch[i]) begin
      if ((r_st_el_fetch[i] == RD_LL) && icontinue) begin
        ptr = i;
        icontinue = '0;
      end
    end
    ptr_indx = (L_ST_PUSHLL_CTX)'(ptr);
    r_el_fetch_aux_ptr = r_el_fetch_aux[ptr_indx];
    i_glbCtx = b_glbCtx.w_data;
    rd_ll_max_size_bytes = get_nxt_ll_size_bytes_f(r_el_fetch_aux_ptr.dBllNslotsReq);

    rd_ll.w_header                           = '0;
    rd_ll.w_header.common1.vfunc_num         = i_glbCtx[r_el_fetch_aux_ptr.curr_channel].tlpSettings.d_vf[K_VFWD-2:0];
    rd_ll.w_header.common1.vfunc_active      = i_glbCtx[r_el_fetch_aux_ptr.curr_channel].tlpSettings.d_vf_en;
    rd_ll.w_header.common1.tc                = i_glbCtx[r_el_fetch_aux_ptr.curr_channel].tlpSettings.d_tc;
    rd_ll.w_header.common1.pfunc_num         = i_glbCtx[r_el_fetch_aux_ptr.curr_channel].tlpSettings.d_pf[K_PFWD-1:0];
    rd_ll.w_header.common1.pcieTag           = '0;
    rd_ll.w_header.common1.ln                = '0;
    rd_ll.w_header.common1.attr.idOrder      = '0;
    rd_ll.w_header.common1.attr.relaxOrder   = i_glbCtx[r_el_fetch_aux_ptr.curr_channel].tlpSettings.d_ro;
    rd_ll.w_header.common1.attr.snoop        = i_glbCtx[r_el_fetch_aux_ptr.curr_channel].tlpSettings.d_sn;

    rd_ll.w_header.common3 = '0;

    rd_ll.w_header.common4.tlp_abort         = '0;
    rd_ll.w_header.common4.rom_in_range      = '0;
    rd_ll.w_header.common4.req_id            = '0;
    rd_ll.w_header.common4.io_req_in_range   = '0;
    rd_ll.w_header.common4.in_membar_range   = '1;
    rd_ll.w_header.common4.ecrc_err          = '0;
    rd_ll.w_header.common4.dwen              = '0;
    rd_ll.w_header.common4.dllp_abort        = '0;
    rd_ll.w_header.common4.cpl_last          = '0;

    rd_ll.w_header.radmPort.uppr_bytes       = '0;
    rd_ll.w_header.radmPort.uppr_bytes_valid = '0;
    rd_ll.w_header.radmPort.mem_type         = 1'b1;
    rd_ll.w_header.radmPort.vc_num           = '0;

    rd_ll.w_header.xadmPort                  = '0;
    rd_ll.w_header.tag                       = '0;

    rd_ll.w_header.common2.typ               = '0;
    rd_ll.w_header.common2.tph_th            = '0;
    rd_ll.w_header.common2.tph_st            = '0;
    rd_ll.w_header.common2.tph_ph            = '0;
    rd_ll.w_header.common2.td                = '0;
    rd_ll.w_header.common2.prfx              = K_PRFXDEFAULT;
    rd_ll.w_header.common2.poisoned          = '0;
    rd_ll.w_header.common2.cpl_status        = '0;
    rd_ll.w_header.common2.cpl_bcm           = '0;
    rd_ll.w_header.common2.cmpltr_id         = '0;
    rd_ll.w_header.common2.byte_cnt          = '0;
    rd_ll.w_header.common2.ats               = i_glbCtx[r_el_fetch_aux_ptr.curr_channel].tlpSettings.d_ats;
    
    //Descriptors size is always multiple of 24 bytes, so first and last byte enables always on
    rd_ll.w_header.common2.dw_len            = (rd_ll_max_size_bytes[12] && (`CX_MAX_MTU == 4096)) ? 10'd0 : rd_ll_max_size_bytes[11:2];
    rd_ll.w_header.common2.first_be          = '1;
    rd_ll.w_header.common2.last_be           = '1;
    rd_ll.w_header.common2.fmt               = 2'(|r_el_fetch_aux_ptr.channel_ctx.ctx_llpHighReg);
    rd_ll.w_header.common2.addr              = {r_el_fetch_aux_ptr.channel_ctx.ctx_llpHighReg,
                                              r_el_fetch_aux_ptr.channel_ctx.ctx_llpLowReg};

    rd_ll.w_header.dma.channel                            = '0;
    rd_ll.w_header.dma.channel[CC_NUM_DMA_CHAN_WIDTH-1:0] = r_el_fetch_aux_ptr.curr_channel[CC_NUM_DMA_CHAN_WIDTH-1:0];
    rd_ll.w_header.dma.req                                = P_CHANNEL == E_WRITE ? E_DMA_WRCH_LLREAD : E_DMA_RDCH_LLREAD;
    rd_ll.w_headerProt = '0;
    // Skips the actual descriptor read on the interface when an error was detected on the data transfer
    // since the LL pointer might have already rolled back, this simplifies verification
    s_reqValid = (r_st_el_fetch[ptr_indx] == RD_LL) && !db_cherr[r_el_fetch_aux[ptr_indx].curr_channel];
    rd_ll.w_hv   = s_reqValid && !filterCh[r_el_fetch_aux[ptr_indx].curr_channel];
    rd_ll.w_eot  = s_reqValid && !filterCh[r_el_fetch_aux[ptr_indx].curr_channel];

    rd_ll.w_dv   = '0;
    rd_ll.w_data = '0;

  end


  // *******************************************************
  // Buffer stage of the rd_ll interface it has two functions
  // 1- Holds transactions when main clock is turned off
  // 2- Has three stages and matches the LL fetch depth 3
  //    This avoids FSM to get stuck on a halt confition
  //    If the FSM gets stuck access to the LL RAM is stuck
  //    and this event can create the following issues:
  //    1.STSHandler transactions to get blocked creating
  //      conditions to a deadlock
  //    2.CRGB gets blocks creating software performances
  //      issues
  // *******************************************************
    DWC_pcie_edmapf_rasdp_if b_ras();
    assign b_ras.w_ras_dp_err_inj = '0;
  DWC_pcie_edmapf_tlp_delay
   #(
     .P_DATAWD       (K_COREBUSWD                )
    ,.P_HEADERTYPE   (xradm_s                    )
    ,.P_STAGES       (E_FEED_NONE                )
    ,.P_TYPE         (E_TLP_FULL                 )
    ,.P_AUX_CLK      (1                          )
    ,.P_EXT_RAM_DEPTH(CC_IF_CTRL_LL_RAM_LATENCY-1)
  ) u_ll_delay (
     .b_clkrst ( clk             )
    ,.b_dst    ( b_rd_ll         )
    ,.b_src    ( rd_ll.slave_mp  )
    ,.b_ras    ( b_ras.master_mp )
    );  

  
  
  // *******************************************************
  // ** Drives the DB manager remaining interface
  // *******************************************************
  always_comb begin : PROC_CB_ChRbRamSlots
    int ptr;
    // This is the maximum size allowed to fetch a descriptor
    logic     [12:0]                rd_ll_max_size_bytes;
    glbData_s [CX_NUM_DMA_CHAN-1:0] i_glbCtx;
    logic     [L_ST_PUSHLL_CTX-1:0] ptr_indx;

    ptr = '0;
    // SMD: Not all conditions are covered for the combinational logic
    //  SJ: All signals are initialized so no latch is generated 
    // spyglass disable_block AlwaysCombExhaustive-ML 
    foreach (r_st_el_fetch[i]) begin
      if (r_st_el_fetch[i] == WR_RAM)
        ptr = i;
    end

    i_glbCtx = b_glbCtx.w_data;
    ptr_indx = (L_ST_PUSHLL_CTX)'(ptr);
    rd_ll_max_size_bytes = get_nxt_ll_size_bytes_f(r_el_fetch_aux[ptr_indx].dBllNslotsReq); 

    // by design only one FSM is writing to the RAM at a given time
    b_ChDbRemSlt.w_data.valid    = (r_st_el_fetch[ptr_indx] == WR_RAM);
    b_ChDbRemSlt.w_data.channel  = r_el_fetch_aux[ptr_indx].curr_channel;
    b_ChDbRemSlt.w_data.llDrop   = r_rd_ll_drop[r_el_fetch_aux[ptr_indx].curr_channel]; 
    b_ChDbRemSlt.w_data.llNslots = '0;
    // Slots are only used in linked list enable
    // on case of error dont't set outstanding 
    if (i_glbCtx[r_el_fetch_aux[ptr_indx].curr_channel].ll_en && !r_rd_ll_drop[r_el_fetch_aux[ptr_indx].curr_channel])
      b_ChDbRemSlt.w_data.llNslots = llNSlots_t'(rd_ll_max_size_bytes / 'd24);
    
    // spyglass enable_block AlwaysCombExhaustive-ML
  end

  // remembers that a LL read request was dropped
  always_ff @ (posedge clk.w_aux_clk or negedge clk.w_reset_n) begin : PROC_FF_RD_LL_DROP
    if (!clk.w_reset_n)
      r_rd_ll_drop <= #`TP '0;
    else
      r_rd_ll_drop <= #`TP s_rd_ll_drop; 
  end

  always_comb begin : PROC_CB_RD_LL_DROP

    logic [CX_NUM_DMA_CHAN-1:0] db_cherr;
    logic [CX_NUM_DMA_CHAN-1:0] filterCh;

    db_cherr = b_llFetchNtfy.w_db_apperr | b_llFetchNtfy.w_db_llerr | chonehot_f(b_PushLLCtx.w_data.flush & b_PushLLCtx.w_valid, b_PushLLCtx.w_data.reqCh);

    filterCh = b_llFetchNtfy.w_chFilter;

    s_rd_ll_drop = r_rd_ll_drop;

    foreach (r_st_el_fetch[i]) begin
      if (r_st_el_fetch[i] == WR_RAM) begin
        s_rd_ll_drop[r_el_fetch_aux[i].curr_channel] = 1'b0;
      end

      // This means that read LL was dropped, see the RD_LL driver
      if (r_st_el_fetch[i] == RD_LL && (db_cherr[r_el_fetch_aux[i].curr_channel] || filterCh[r_el_fetch_aux[i].curr_channel])) begin
        s_rd_ll_drop[r_el_fetch_aux[i].curr_channel] = 1'b1;
      end
    end    

  end


  // *******************************************************
  // ** Drives the LLQ push interface
  // *******************************************************
  always_comb begin : PROC_comb_ll_push

    // default: pick any
    non_ll_push.w_data.ctxElem            ='0;
    non_ll_push.w_valid                   ='0;
    non_ll_push.w_data.reqCh              ='0;
    non_ll_push.w_data.pushOp             =E_PUSH;
    // SMD: Not all conditions are covered for the combinational logic
    //  SJ: All signals are initialized so no latch is generated 
    // spyglass disable_block AlwaysCombExhaustive-ML 
    foreach (r_st_el_fetch[i]) begin
      st_el_fetch_aux r_el_fetch_aux_i;
      r_el_fetch_aux_i = r_el_fetch_aux[i];
      if (r_st_el_fetch[i] == NLL_PUSH) begin
        non_ll_push.w_valid                        = 1'b1;
        non_ll_push.w_data.reqCh                        = r_el_fetch_aux_i.curr_channel;
        //Non linked list mode pushes a command directly from this location, but it's always non-linked list mode
        non_ll_push.w_data.pushOp                  = E_NLL_TRIGGER;
        non_ll_push.w_data.ctxElem.ovrl.llData.ccs = r_el_fetch_aux_i.channel_ctx.ctx_ccs;
        non_ll_push.w_data.ctxElem.ovrl.llData.cb  = r_el_fetch_aux_i.channel_ctx.ctx_Cb;
      end
    end
    // spyglass enable_block AlwaysCombExhaustive-ML

  end

  // ******************************************************
  // * Drives the context pop interface that aligns
  // with the TLP
  // *****************************************************
  assign popCtx.w_valid = (r_st_el_fetch[ST_FETCH_POPCTX] == RD_CTX);

  assign r_el_fetch_aux_st_fetch_popctx = r_el_fetch_aux[ST_FETCH_POPCTX];
  assign popCtx.w_data.ctx_ccs              = r_el_fetch_aux_st_fetch_popctx.channel_ctx.ctx_ccs;
  assign popCtx.w_data.ctx_Cb               = r_el_fetch_aux_st_fetch_popctx.channel_ctx.ctx_Cb;
  assign popCtx.w_data.channel              = r_el_fetch_aux_st_fetch_popctx.curr_channel;
  assign popCtx.w_data.ctx_ll_ptr           ={r_el_fetch_aux_st_fetch_popctx.channel_ctx.ctx_llpHighReg, r_el_fetch_aux_st_fetch_popctx.channel_ctx.ctx_llpLowReg};
  assign popCtx.w_data.ctx_pfo              = r_el_fetch_aux_st_fetch_popctx.channel_ctx.ctx_pfo;
  assign popCtx.w_data.db_llNslotsOutStd    = r_el_fetch_aux_st_fetch_popctx.channel_ctx.db_llNslotsOutStd;
  assign popCtx.w_data.db_llNslotsOutStdLst = r_el_fetch_aux_st_fetch_popctx.channel_ctx.db_llNslotsOutStdLst;
  assign popCtx.w_data.db_llNreads          = r_el_fetch_aux_st_fetch_popctx.channel_ctx.db_llNreads;

  assign popCtx.w_ready = (idle_arb_grant[ST_FETCH_POPCTX] == '1) &&
                          (r_st_el_fetch[ST_FETCH_POPCTX] == IDLE);

  assign b_PushLLCtx.w_ready = r_el_fetch_aux[ST_PUSHLL_CTX].llFetchNtfyDone && ((r_st_el_fetch[ST_PUSHLL_CTX] == WR_RAM_PUSHLL) || (r_st_el_fetch[ST_PUSHLL_CTX] == PUSHLL_WAIT_LLNTFY));


// SNPS_SysML_CODE_END

endmodule
