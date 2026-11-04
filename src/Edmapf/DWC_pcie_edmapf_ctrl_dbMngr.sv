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
// ---    $DateTime: 2023/12/22 07:15:34 $ 
// ---    $Revision: #19 $ 
// ---    $Author: lnicola $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_dbMngr.sv#19 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_HubDbOp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_pop_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_llFetchNtfy_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ChRegfile_DB_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_crgb_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_dbNtfy_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_rvData_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_genericData_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_rvOpData_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_dbMngr
  import DWC_pcie_edmapf_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter type P_DBMNGR_ELPFETCH_TYPE = DbMngrWrElPfetch_t
  ,parameter      type P_DBMNGR_REM_TYPE = DbMngrRemWrEng_s
  ,parameter          type P_DBMNGR_TYPE = DbMngrWrEng_s
  ,parameter   CC_IF_CTRL_LL_RAM_LATENCY = 1
  ,parameter        CC_IF_CTRL_LL_RAM_WD = 1
  ,parameter       CC_NUM_DMA_CHAN_WIDTH = 4
  ,parameter                  CX_DMA_LLQ = 1
  ,parameter             CX_NUM_DMA_CHAN = 16
  ,parameter      dmaEngType_e P_CHANNEL = E_WRITE
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_pop_if.master_mp         b_ChDbFifo
  ,DWC_pcie_edmapf_genericData_if.slave_mp  b_ChDbRemSlt
  ,DWC_pcie_edmapf_ChRegfile_DB_if.slave_mp b_ChStop
  ,DWC_pcie_edmapf_aclks_if.slave_mp        b_clk
  ,DWC_pcie_edmapf_crgb_if.slave_mp         b_crgb
  ,DWC_pcie_edmapf_genericData_if.slave_mp  b_ctxGlb
  ,DWC_pcie_edmapf_dbNtfy_if.master_mp      b_doorbellPulse
  ,DWC_pcie_edmapf_genericData_if.slave_mp  b_hwStop_active
  ,DWC_pcie_edmapf_llFetchNtfy_if.slave_mp  b_llFetchNtfy
  ,DWC_pcie_edmapf_HubDbOp_if.slave_mp      b_llHubNtfy
  ,DWC_pcie_edmapf_rvData_if.slave_mp       b_stsh2ctx_update
  ,DWC_pcie_edmapf_genericData_if.master_mp b_swStop
  ,DWC_pcie_edmapf_rvOpData_if.master_mp    b_token_push
  ,DWC_pcie_edmapf_genericData_if.master_mp b_swStopPulse
  );


// SNPS_SysML_CODE_START
   localparam LP_CRGB_ADDR_WIDTH = `CC_CRGB_ADDR_WIDTH;
   localparam LP_LLQ_RAM_DP_WD   = $clog2(CX_NUM_DMA_CHAN*CX_DMA_LLQ+1);

   // BCM TP delay
   localparam integer LP_REG_DELAY_DENOM  = 1000;
   localparam integer LP_REG_DELAY_TIME   = `TP * LP_REG_DELAY_DENOM;
 
   typedef struct packed {
    logic                          dbstate;          //Tracks the channels that are dorbelled
    logic [LP_LLQ_RAM_DP_WD-1:0]   llNslotsOutStd;   //Tracks the number of descriptors outstanding up to the prefetch depth boundary
    logic [LP_LLQ_RAM_DP_WD-1:0]   llNslotsOutStdApp;//Tracks the number of descriptors outstanding on the app side(single read can have more than one descriptor at a time)
    logic [LP_LLQ_RAM_DP_WD-1:0]   llNreads;         //Tracks the number of read descriptors up to the prefetch depth boundary
    logic [LP_LLQ_RAM_DP_WD-1:0]   llNreadsApp;      //Tracks the number of read descriptors
    logic                          dbFifoOutStd;     //Tracks that dbFIFO has requested more descriptors and soon will be added to llNslotsOutStd
    logic                          lastPfetch;       //CTRL_LL has reached maximum outstanding descriptors 
    logic [LP_LLQ_RAM_DP_WD:0]     fqOutStd;         //Tracks the number of pushed jobs into the fetchQ. When it
                                                     //reaches the maximum is stops requesting new descriptors
    logic                          trigger_token;    //Triggers the token generation to handle the end of transfer
    dmaErrors_e                    ll_err;           //remembers to inject an error with the trigger token
    logic                          app_err;
    logic                          stop;
   } db_state_s;

   db_state_s [CX_NUM_DMA_CHAN-1:0] r_db_state, s_db_state;

   /*
     Creating a copy from external interfaces
   */
  glbData_s        [CX_NUM_DMA_CHAN-1:0] s_ctxGlb;
    
   /*
     Creating an internal version of the global context interface
   */
   always_comb begin : c_s_glbCtx_PROC
     s_ctxGlb = b_ctxGlb.w_data;
   end : c_s_glbCtx_PROC
  
   // ##########################################################################   
   // CRGB to register file convertion. The register width is 32-bits
   // ##########################################################################
   

   DWC_pcie_edmapf_ram1p_if #(
                       .WD(32) // Single CRGB DW
                       ,.PW(LP_CRGB_ADDR_WIDTH-10)
                       ) b_crgbdata_0();


   DWC_pcie_edmapf_ram1p_if #(
                       .WD(32) // Single CRGB DW
                       ,.PW(LP_CRGB_ADDR_WIDTH-10)
                       ) b_crgbdata_1();


   DWC_pcie_edmapf_ChRegfile_DB_if #(
                              .CC_NUM_DMA_CHAN_WIDTH(CC_NUM_DMA_CHAN_WIDTH)
                              ) b_ChStartStop();

   // Returns a MDA structure containning the element prefetch

   DWC_pcie_edmapf_genericData_if #(.P_DATATYPE(P_DBMNGR_ELPFETCH_TYPE)) b_ChElPfetch();
   P_DBMNGR_ELPFETCH_TYPE s_ChElPfetch;
   
   assign s_ChElPfetch = b_ChElPfetch.w_data;

   DWC_pcie_edmapf_crgb
    
     #(
        .P_CHANNEL            (P_CHANNEL             )
       ,.P_RAM                (E_HDMAREGZONE_DBMNGR  )
       ,.P_RAM_DATA_WD        (32                    )
       ,.P_RAM_ADDR_WD        (LP_CRGB_ADDR_WIDTH -10)
       
       ) u1_crgb
       (
         .b_clk  (b_clk     )
        ,.b_crgb (b_crgb    )
        ,.b_ram  (b_crgbdata_0.master_mp)
        );
   DWC_pcie_edmapf_ram1p_delay
    #(
    .PW(LP_CRGB_ADDR_WIDTH -10)
   ,.WD(32)
   ) u_ramp (
    .b_clk         ( b_clk                    )
   ,.b_iram        ( b_crgbdata_0.slave_mp  )
   ,.b_oram        ( b_crgbdata_1.master_mp )
   );


   // ##########################################################################   
   // Dooberll Manager Register file implementation
   // ##########################################################################
  
   DWC_pcie_edmapf_llFetchNtfy_if #(
     .CC_NUM_DMA_CHAN_WIDTH(CC_NUM_DMA_CHAN_WIDTH)
    ,.CC_NUM_DMA_CHAN      (CX_NUM_DMA_CHAN)
   ) b_llFetchNtfyDbreg();

  /*
    Hold the Stop Doorbell pulse when core_clk is not available
  */
  logic r_hold_stop_db;
  logic r_stop_db_pulse;
  always_ff @ (posedge b_clk.w_aux_clk or negedge b_clk.w_reset_n) begin : PROC_FF_hold_stop_db
    if (!b_clk.w_reset_n) begin
        r_hold_stop_db  <= # `TP '0;
    end else begin 
      foreach (r_db_state[i]) begin
        if ((b_ChStartStop.w_stop && CC_NUM_DMA_CHAN_WIDTH'(i) == b_ChStartStop.w_channel_num && !b_hwStop_active.w_data[i]) && r_db_state[i].dbstate) begin
          r_hold_stop_db <= # `TP '1;
        end else if (r_stop_db_pulse) begin  
          r_hold_stop_db <= # `TP '0;
        end
      end  
    end      
  end // block: PROC_FF_hold_stop_db
  
  /*
    Generate Stop Doorbell pulse when core_clk is on
  */  
  always_ff @ (posedge b_clk.w_main_clk or negedge b_clk.w_reset_n) begin : PROC_FF_stop_db
    if (!b_clk.w_reset_n) begin 
      r_stop_db_pulse  <= # `TP '0;
    end else begin 
      if (b_ChStartStop.w_stop || r_hold_stop_db) begin 
        r_stop_db_pulse <= # `TP '1;
      end else begin   
        r_stop_db_pulse <= # `TP '0;
      end
    end         
  end // block: PROC_FF_stop_db 
  
  /*
    Detecting a Stop indication to the LL Hub to flush the pending transactions
  */
  logic [CX_NUM_DMA_CHAN-1:0] r_db_stop;
  always_ff @(posedge b_clk.w_aux_clk, negedge b_clk.w_reset_n) begin : s_db_stop_PROC
    if (!b_clk.w_reset_n) begin
      r_db_stop <= #`TP '0;
    end else begin
      foreach (r_db_stop[i])
      //if ((b_ChStartStop.w_stop && CC_NUM_DMA_CHAN_WIDTH'(i) == b_ChStartStop.w_channel_num) || (b_llHubNtfy.w_chStop[i])) begin
      if (b_llHubNtfy.w_chStop[i]) begin
        r_db_stop[i] <= #`TP '1;
      end else if (b_llHubNtfy.w_llDescFlushClr[i]) begin
        r_db_stop[i] <= #`TP '0;
      end
    end
  end : s_db_stop_PROC

  /*
    Sending the Software Stop indication to the LL Hub to flush the pending transactions
  */
  logic [CX_NUM_DMA_CHAN-1:0] r_sw_stop;
  always_ff @(posedge b_clk.w_aux_clk, negedge b_clk.w_reset_n) begin : s_sw_stop_PROC
    if (!b_clk.w_reset_n) begin
      r_sw_stop <= #`TP '0;
    end else begin
      foreach (r_sw_stop[i])
      if (r_stop_db_pulse && CC_NUM_DMA_CHAN_WIDTH'(i) == b_ChStartStop.w_channel_num && !b_hwStop_active.w_data[i]) begin
        r_sw_stop[i] <= #`TP '1;
      end else if (b_llHubNtfy.w_llDescFlushClr[i]) begin
        r_sw_stop[i] <= #`TP '0;
      end
    end
  end : s_sw_stop_PROC
  
  /*
    Expanding serial SW Stop indication into parallel
  */
  logic [CX_NUM_DMA_CHAN-1:0] s_sw_stop;
  always_comb begin : c_s_sw_stop_PROC
    foreach(s_sw_stop[i]) begin
      if(r_sw_stop[i] && (((|{r_db_state[i].fqOutStd, r_db_state[i].llNreadsApp}) && s_ctxGlb[i].ll_en) || !s_ctxGlb[i].ll_en)) begin
        s_sw_stop[i] = '1;
      end else begin
        s_sw_stop[i] = '0;
      end
    end
  end : c_s_sw_stop_PROC

  /*
    Expanding serial SW Stop pulse into parallel
  */
  logic [CX_NUM_DMA_CHAN-1:0] s_sw_stop_pulse;
  always_comb begin : c_s_sw_stop_pulse_PROC
    foreach(s_sw_stop_pulse[i]) begin
      if (b_ChStartStop.w_stop && CC_NUM_DMA_CHAN_WIDTH'(i) == b_ChStartStop.w_channel_num) begin
        s_sw_stop_pulse[i] = '1;
      end else begin
        s_sw_stop_pulse[i] = '0;
      end
    end
  end : c_s_sw_stop_pulse_PROC
  

  assign b_llFetchNtfy.w_chFilter = r_db_stop | r_sw_stop;
  assign b_llHubNtfy.w_db_stop = /*r_db_stop |*/ r_sw_stop;
  assign b_swStop.w_data = s_sw_stop; //r_sw_stop;
  assign b_swStopPulse.w_data = s_sw_stop_pulse;

  assign b_llFetchNtfyDbreg.w_elPfetch      = b_llFetchNtfy.w_elPfetch;
  assign b_llFetchNtfyDbreg.w_elPfetchCh    = b_llFetchNtfy.w_elPfetchCh;
  assign b_llFetchNtfyDbreg.w_elPfetchValid = b_llFetchNtfy.w_elPfetchValid;
  assign b_llFetchNtfyDbreg.w_db_chsch_mask = b_llFetchNtfy.w_db_chsch_mask;
  assign b_llFetchNtfyDbreg.w_chstWaterMark = b_llFetchNtfy.w_chstWaterMark;

  assign b_llFetchNtfy.w_elPfetchReady      = b_llFetchNtfyDbreg.w_elPfetchReady;
  generate
    genvar gv;
    for (gv=0;gv<CX_NUM_DMA_CHAN;gv++) begin
      assign b_llFetchNtfy.w_db_chstRun[gv]  = b_doorbellPulse.w_chstRun[gv];
      assign b_llFetchNtfy.w_db_llerr[gv]    = |r_db_state[gv].ll_err;
      assign b_llFetchNtfy.w_db_apperr[gv]   = r_db_state[gv].app_err;
    end
  endgenerate

  assign b_doorbellPulse.w_chstWaterMark = b_llFetchNtfy.w_chstWaterMark;

   DWC_pcie_edmapf_ctrl_dbreg
   
     #(
       .P_CHANNEL              (P_CHANNEL             )
       ,.CC_NUM_DMA_CHAN_WIDTH (CC_NUM_DMA_CHAN_WIDTH )
       ,.CX_NUM_DMA_CHAN       (CX_NUM_DMA_CHAN       )
       ,.P_DBMNGR_ELPFETCH_TYPE(P_DBMNGR_ELPFETCH_TYPE)
       ) u1_reg
       (
        .b_clk            (b_clk                      )
        ,.b_crgbdata      (b_crgbdata_1.slave_mp      )
        ,.b_ChStartStop   (b_ChStartStop.master_mp    )
        ,.b_ChElPfetch    (b_ChElPfetch.master_mp     )
        ,.b_llFetchNtfy   (b_llFetchNtfyDbreg.slave_mp)
        );



   assign b_llHubNtfy.w_dbElPfetch = b_ChElPfetch.w_data;

   //##########################################################################   
   // DMA XFER penfing set when the channel is doorbelled and cleared when
   // status handler finishes the transfer Finish a transfer has the following
   // meaning:
   // 
   // - Doorbell gets cleared (end of list detected or a single descriptor
   // is pushed)
   // 
   // - the Status handler update corresponds to the last descriptor, using an
   // outstanding descriptor counting. So this means that each time a descriptor
   // is pushed into the queue, there's one more outstanding descriptor. Each
   // time sts handler reports back there's one less outstanding descriptor
   //##########################################################################
 
  assign b_doorbellPulse.w_channel = b_ChStartStop.w_channel_num;
  assign b_doorbellPulse.w_valid   = b_ChStartStop.w_start &&  
    f_dbfilter(
      .ll_en       (s_ctxGlb[b_ChStartStop.w_channel_num].ll_en)
      ,.chNum      (b_ChStartStop.w_channel_num)
      ,.xferPendAry(b_doorbellPulse.w_xferPend)
      ,.ll_err     (|r_db_state[b_ChStartStop.w_channel_num].ll_err)
      ,.app_err    (r_db_state[b_ChStartStop.w_channel_num].app_err)
      ,.fqOutStd   (r_db_state[b_ChStartStop.w_channel_num].fqOutStd)
      ); 

  // **************************************************************************
  // Interfaces status handler's b_stsh2ctx_update
  // b_token_push <- b_stsh2ctx_update
  // 
  // Its type is DWC_pcie_edmapf_rvData_if (P_CTXPIPE_TYPE)
  //
  // If CTXPIPE_TYPE is received to drive an error, it clears the doorbell and 
  // passes down to FETCHQ module
  //
  // If CTXPIPE_TYPE is received and doorbell state is on, CTXPIPE_TYPE is 
  // ignored. If doorbell is still on, we will receive a descriptor with either
  //   1- A new data / LLP descriptor
  //   2- A descriptor with an error
  //   3- An end of list detection (CB!=CCS), that will pass down the pipe
  //
  // **************************************************************************

  logic s_filterStshCtx;
  logic [CX_NUM_DMA_CHAN-1:0] s_fqOutStd_inc;
  logic [CX_NUM_DMA_CHAN-1:0] s_fqOutStd_dec;
 
  assign s_filterStshCtx = (
    ((r_db_state[b_stsh2ctx_update.w_data.channel].fqOutStd > {{CC_NUM_DMA_CHAN_WIDTH-1{1'b0}}, 1'b1}) || 
      s_fqOutStd_inc[b_stsh2ctx_update.w_data.channel]) && 
    (!(|b_stsh2ctx_update.w_data.ctx.ovrl.errors)) && !b_stsh2ctx_update.w_data.ctx.ovrl.stop
    ); 

  assign b_stsh2ctx_update.w_ready = (b_token_push.w_ready || !b_token_push.w_valid);

  always_comb begin  : PROC_Cb_token_push
    logic ibreak;
    ibreak = '0;
    if ((!s_filterStshCtx) && b_stsh2ctx_update.w_valid) begin
      b_token_push.w_valid   = '1;

      if (|b_stsh2ctx_update.w_data.ctx.ovrl.errors || b_stsh2ctx_update.w_data.ctx.ovrl.stop)
        b_token_push.w_validOp = E_ERR_TOKEN;
      else
        b_token_push.w_validOp = E_EOT_TOKEN;

      b_token_push.w_data = b_stsh2ctx_update.w_data;
    end else if (b_stsh2ctx_update.w_valid) begin
      b_token_push.w_valid   = |b_stsh2ctx_update.w_data.ctx.ovrl.ovrlData.watermarkEn;
      b_token_push.w_data    = b_stsh2ctx_update.w_data;
      b_token_push.w_validOp = E_STSH_LL; // passes on the token to be consumed by LL RAM
    end else begin
      // This logic injects the end of list token
      b_token_push.w_valid   = '0;
      b_token_push.w_validOp= E_EOT_TOKEN;
      b_token_push.w_data = b_stsh2ctx_update.w_data;
      foreach (r_db_state[i]) begin
        if (!ibreak) begin
          if (r_db_state[i].trigger_token ) begin
            if (r_db_state[i].dbstate == '0)
              b_token_push.w_valid = (r_db_state[i].fqOutStd == '0) && ({r_db_state[i].dbFifoOutStd,r_db_state[i].llNslotsOutStd} == '0);
            else
              b_token_push.w_valid = '0;
            if (b_token_push.w_valid)
              ibreak = '1; // break the loop

            if ( |r_db_state[i].ll_err && !r_db_state[i].app_err && !r_db_state[i].stop)
              b_token_push.w_validOp     =  E_LL_ERR;
            else if (r_db_state[i].app_err || r_db_state[i].stop)
              b_token_push.w_validOp     = E_TRIG_TOKEN;
            else
              b_token_push.w_validOp     = E_LL_END;
            //synthesize the data
            b_token_push.w_data        = '0;
            b_token_push.w_data.channel= CC_NUM_DMA_CHAN_WIDTH'(i);
            b_token_push.w_data.ctx.ovrl.errors = r_db_state[i].ll_err;
            b_token_push.w_data.ctx.ovrl.token = '1;
          end
        end
      end

    end
  end

  always_ff @ (posedge b_clk.w_aux_clk or negedge b_clk.w_reset_n) begin : PROC_FF_db_state_auxc
    if (!b_clk.w_reset_n) begin
      foreach(r_db_state[i]) begin
        r_db_state[i].dbstate           <= # `TP '0;
        r_db_state[i].llNslotsOutStd    <= # `TP '0;
        r_db_state[i].llNslotsOutStdApp <= # `TP '0;
        r_db_state[i].llNreads          <= # `TP '0;
        r_db_state[i].llNreadsApp       <= # `TP '0;
        r_db_state[i].dbFifoOutStd      <= # `TP '0;
        r_db_state[i].lastPfetch        <= # `TP '0;
      end
    end else begin
      foreach(r_db_state[j]) begin
        r_db_state[j].dbstate           <= # `TP s_db_state[j].dbstate;
        r_db_state[j].llNslotsOutStd    <= # `TP s_db_state[j].llNslotsOutStd;
        r_db_state[j].llNslotsOutStdApp <= # `TP s_db_state[j].llNslotsOutStdApp;
        r_db_state[j].llNreads          <= # `TP s_db_state[j].llNreads      ;
        r_db_state[j].llNreadsApp       <= # `TP s_db_state[j].llNreadsApp   ;
        r_db_state[j].dbFifoOutStd      <= # `TP s_db_state[j].dbFifoOutStd  ;
        r_db_state[j].lastPfetch        <= # `TP s_db_state[j].lastPfetch    ;
      end
    end      
  end // block: PROC_FF_db_state_auxc

  always_ff @ (posedge b_clk.w_main_clk or negedge b_clk.w_reset_n) begin : PROC_FF_db_state_mainc
    if (!b_clk.w_reset_n) begin
      foreach (r_db_state[i]) begin
        r_db_state[i].fqOutStd       <= # `TP '0;
        r_db_state[i].trigger_token  <= # `TP '0;
        r_db_state[i].ll_err         <= # `TP E_DMAERR_NONE;
        r_db_state[i].app_err        <= # `TP '0;
        r_db_state[i].stop           <= # `TP '0;
      end
    end else begin
      foreach(r_db_state[j]) begin
        r_db_state[j].fqOutStd       <= # `TP s_db_state[j].fqOutStd      ;
        r_db_state[j].trigger_token  <= # `TP s_db_state[j].trigger_token ;
        r_db_state[j].ll_err         <= # `TP s_db_state[j].ll_err        ;
        r_db_state[j].app_err        <= # `TP s_db_state[j].app_err       ;
        r_db_state[j].stop           <= # `TP s_db_state[j].stop          ;
      end
    end      
  end // block: PROC_FF_db_state_mainc
 

  always_comb begin : PROC_CB_db_state

    logic s_dbfilter;
    logic s_ll_en;
    
    s_dbfilter =  1'b0;
    s_ll_en    =  s_ctxGlb[b_ChStartStop.w_channel_num].ll_en;

    for (int i=0; i<CX_NUM_DMA_CHAN; i++) begin
      s_dbfilter = f_dbfilter(
                               .ll_en      (s_ll_en)
                              ,.chNum      (b_ChStartStop.w_channel_num)
                              ,.xferPendAry(b_doorbellPulse.w_xferPend)
                              ,.ll_err     (|r_db_state[i].ll_err)
                              ,.app_err    (r_db_state[i].app_err)
                              ,.fqOutStd   (r_db_state[i].fqOutStd)
                              ); 
      if ((b_ChStartStop.w_channel_num == CC_NUM_DMA_CHAN_WIDTH'(i)) && b_ChStartStop.w_start && s_dbfilter)
        s_db_state[i].dbstate = 1'b1;
      else if ((b_ChStartStop.w_channel_num == CC_NUM_DMA_CHAN_WIDTH'(i)) && r_stop_db_pulse && s_ctxGlb[i].ll_en)
        s_db_state[i].dbstate = 1'b0; //got a software command to stop
      else if ((b_ChStop.w_channel_num == CC_NUM_DMA_CHAN_WIDTH'(i)) && (b_ChStop.w_stop || |b_ChStop.w_halt_llerr))
        s_db_state[i].dbstate = 1'b0; //Stop indication from ctrl_ll
      else if ((b_stsh2ctx_update.w_data.channel==i) && b_stsh2ctx_update.w_valid && |b_stsh2ctx_update.w_data.ctx.ovrl.errors) 
        s_db_state[i].dbstate = 1'b0; // got a stshandler token with an error
      else if ((b_ChDbRemSlt.w_data.channel == CC_NUM_DMA_CHAN_WIDTH'(i)) && b_ChDbRemSlt.w_data.valid && b_ChDbRemSlt.w_data.llNslots == '0)
        s_db_state[i].dbstate = 1'b0; // Non linked list mode, clears doorbell immediatly
      else
        s_db_state[i].dbstate = r_db_state[i].dbstate; 
    end

  end // block: PROC_CB_db_state

  // Doorbell at any time feature filter
  // If not linked list do not accept while the previous doorbell is still working
  // In case of error ignore any re-doorbell attempt
  // If end of list was already detected ignore re-doorbell attempt
  function automatic logic f_dbfilter(
     logic                             ll_en
    ,logic [CC_NUM_DMA_CHAN_WIDTH-1:0] chNum
    ,logic [CX_NUM_DMA_CHAN-1:0]       xferPendAry
    ,logic                             ll_err
    ,logic                             app_err
    ,logic [LP_LLQ_RAM_DP_WD:0]        fqOutStd
    );

    logic s_dbfilter;
    logic xferPend;

    s_dbfilter = '1;

    xferPend = xferPendAry[chNum];

    if (!ll_en && xferPend)
      s_dbfilter = '0;
    if (ll_err || app_err)
      s_dbfilter = '0;
    if ((fqOutStd == '0) && xferPend)
      s_dbfilter = '0;

    return s_dbfilter;
  endfunction

  // Informs LL HUB that doorbell manager is in trigger token state
  always_comb begin : PROC_CB_llhub_dbtrigtok
    logic [CX_NUM_DMA_CHAN-1:0] s_db_err;
    for (int i=0;i<CX_NUM_DMA_CHAN;i++)
      s_db_err[i] = r_db_state[i].app_err || (|r_db_state[i].ll_err); 

    b_llHubNtfy.w_db_err = s_db_err; 
  end

  always_comb begin : PROC_CB_token
    foreach (r_db_state[i]) begin
      s_db_state[i].trigger_token = r_db_state[i].trigger_token;
      s_db_state[i].ll_err        = r_db_state[i].ll_err;
      s_db_state[i].app_err       = r_db_state[i].app_err;
      s_db_state[i].stop          = r_db_state[i].stop;

      // SMD: Not all conditions are covered for the combinational logic
      //  SJ: All signals are initialized so no latch is generated 
      // spyglass disable_block AlwaysCombExhaustive-ML      
      if (s_db_state[i].dbstate)
        if ((b_ChStartStop.w_channel_num == CC_NUM_DMA_CHAN_WIDTH'(i)) && b_ChStartStop.w_start)
          s_db_state[i].trigger_token = 1'b0; //Doorbell at any time, cancel end of list on a re-doorbell acception

      if ({r_db_state[i].dbFifoOutStd,r_db_state[i].llNslotsOutStdApp} == '0)
        if ((b_token_push.w_data.channel == CC_NUM_DMA_CHAN_WIDTH'(i)) && b_token_push.w_ready && b_token_push.w_valid)
          if ((b_token_push.w_validOp == E_ERR_TOKEN) || ((b_token_push.w_validOp == E_EOT_TOKEN)))
            s_db_state[i].trigger_token = 1'b1; // Schedules a trigger on transfer end scenarios (so LL must be idle)

      //Previous condition do not trigger because a command is pending in LL fetch, however if the command ends with a
      //descriptor drop the token has to be triggered
      if (b_ChDbRemSlt.w_data.valid && b_ChDbRemSlt.w_data.channel == i && b_ChDbRemSlt.w_data.llDrop)
        s_db_state[i].trigger_token = 1'b1;

      if ((r_db_state[i].llNslotsOutStd != '0) && (s_db_state[i].llNslotsOutStd == '0) && (s_db_state[i].dbstate == '0))
        s_db_state[i].trigger_token = 1'b1; // Schedules a trigger token on end of list scenarios

      if ((r_db_state[i].llNslotsOutStd == '0) && (s_db_state[i].llNslotsOutStd == '0) && r_stop_db_pulse && (CC_NUM_DMA_CHAN_WIDTH'(i) == b_ChStartStop.w_channel_num) && (s_db_state[i].dbstate == '0) && (r_db_state[i].dbstate == '1))
        s_db_state[i].trigger_token = 1'b1; // Schedules a trigger stop
      if (r_db_state[i].dbstate || r_sw_stop[i]) begin
        if (b_ChStop.w_channel_num == CC_NUM_DMA_CHAN_WIDTH'(i) && b_ChStop.w_stop && |b_ChStop.w_halt_llerr && r_db_state[i].ll_err == E_DMAERR_NONE) begin
          s_db_state[i].trigger_token = 1'b1;
          s_db_state[i].ll_err        = b_ChStop.w_halt_llerr;
        end
      end
      
      if (b_token_push.w_valid && b_token_push.w_ready && (b_token_push.w_data.channel == CC_NUM_DMA_CHAN_WIDTH'(i)) && 
          ((b_token_push.w_validOp == E_TRIG_TOKEN) || (b_token_push.w_validOp == E_LL_ERR) || (b_token_push.w_validOp == E_LL_END))) begin
        s_db_state[i].trigger_token = 1'b0;
        s_db_state[i].ll_err  = E_DMAERR_NONE;
        s_db_state[i].app_err = 1'b0;
      end
      if (b_stsh2ctx_update.w_valid && b_stsh2ctx_update.w_ready && (|b_stsh2ctx_update.w_data.ctx.ovrl.errors) && (b_stsh2ctx_update.w_data.channel==i)) begin
        s_db_state[i].ll_err = E_DMAERR_NONE; //Errors from stshandler invalidate LL errors
        s_db_state[i].app_err = 1'b1;//but sets app error
      end
        
      if (b_token_push.w_valid && b_token_push.w_ready && (b_token_push.w_data.channel == CC_NUM_DMA_CHAN_WIDTH'(i)) && 
          ((b_token_push.w_validOp == E_TRIG_TOKEN) || (b_token_push.w_validOp == E_LL_ERR) || (b_token_push.w_validOp == E_LL_END))) begin
        s_db_state[i].stop = 1'b0;
      end
      if (b_stsh2ctx_update.w_valid && b_stsh2ctx_update.w_ready && b_stsh2ctx_update.w_data.ctx.ovrl.stop && (b_stsh2ctx_update.w_data.channel==i)) begin
        s_db_state[i].stop = 1'b1;//set stop bit
      end
      
      // spyglass enable_block AlwaysCombExhaustive-ML
    end
  end


  //**************************************************************************   
  // ** Implements a queue of doorbell channels to process 
  //**************************************************************************


  // The LL RAM has a write and a read latency.  A single thread controlling will
  // not be able to issue back2bck descriptor requests. This is not critical
  // in single channel, because typically we have a queue of space and
  // a single read has several descriptors. But when we have many channels
  // (more than the latency time to fetch the descriptors) the queue is 
  // reduced to one descriptor at a time. On this scenario it's critical to
  // be able to fetch back2back in order not to loose performance.
  // So for this later scenario, several channels must be using the RAM in
  // a pipelined fashion, without any IDLE states in the RAM access.

  // This means that the fetch FSM will be multi-threaded, up to the pipeline
  // of the RAM

  // The channels that are in  doorbell state are serialized into the number
  // sequence and queue into this multi-treaded fetch FSM

  // Pointers of the pushed and pop channels to avoid having the same channel 
  // pushed more than once into the queue. This would corrupt the multi-treaded
  // FSM
  typedef struct packed {
    logic [CC_NUM_DMA_CHAN_WIDTH-1:0] push;
    logic                             tog; // Detects activity to load into fifo
  } st_db_state_ptr;

  st_db_state_ptr s_db_state_ptr, r_db_state_ptr;
  localparam DB_STATE_PTR_1 = {{CC_NUM_DMA_CHAN_WIDTH-1{1'b0}},1'b1};

  // Function to determine the next channel to though at the queue
  function automatic logic[CC_NUM_DMA_CHAN_WIDTH-1:0] get_next_db_channel_ptr
    (
     db_state_s [CX_NUM_DMA_CHAN-1:0]  db_state,
     logic [CX_NUM_DMA_CHAN-1:0]       db_mask,
     //One bit per channel indicating that LL fetchQ is full
     //so at this time this channel can't be scheduled
     logic [CX_NUM_DMA_CHAN-1:0]       fetchq_not_full,
     //Pointer to the channel in doobell arrays
     logic [CC_NUM_DMA_CHAN_WIDTH-1:0] db_ptr 
     );

    logic [CX_NUM_DMA_CHAN-1:0]        db_valid;
    logic [CC_NUM_DMA_CHAN_WIDTH-1:0]  curr_ptr;

    logic                              dbvalid_higher_than_ptr;
    logic [CX_NUM_DMA_CHAN-1:0]        i_db_state;

    logic icontinue;

    icontinue = '1;

    foreach (db_state[i])
      i_db_state[i] = db_state[i].dbstate & !db_state[i].fqOutStd[LP_LLQ_RAM_DP_WD-int'(1)] && !db_mask[i];
    
    db_valid  = i_db_state & fetchq_not_full;
    curr_ptr = db_ptr;

    dbvalid_higher_than_ptr = '0;        
    for (int j = 0; j< CX_NUM_DMA_CHAN;j++) begin
      if (db_valid[j] && (j>db_ptr)) begin
        dbvalid_higher_than_ptr = '1;        
      end
    end
    

    for (int k=0; k<CX_NUM_DMA_CHAN; k++) begin
      if (dbvalid_higher_than_ptr) begin
        if (db_valid[k] && (k>db_ptr) && icontinue) begin
          curr_ptr = k;
          icontinue = '0;
        end
      end else if (db_valid[k] && icontinue) begin
        curr_ptr = k;
        icontinue = '0;
      end
    end
      
    if (db_valid == '0)
      curr_ptr = '0;

    get_next_db_channel_ptr = curr_ptr;

  endfunction
  

  // Struct to organize the DB_fifo related signals ins and outs
  typedef struct packed {
    logic        push_req_n;
    logic        pop_req_n;
    P_DBMNGR_TYPE data; // Channel and available slots number 
  } st_db_fifo_ins;
  
  typedef struct                      packed {
    P_DBMNGR_TYPE data; // Channel and available slots number 
    logic         full;
    logic         empty;
    logic         almEmpty;
    logic         error;
  } st_db_fifo_outs;

  st_db_fifo_ins  db_fifo_ins;
  st_db_fifo_outs db_fifo_outs;

  
  // PROC_CB_db_state_ptr determines the next channel to be processed by the linked list
  // fetch FSM by crawling over the Doorbell Array
  always_ff @ (posedge b_clk.w_main_clk or negedge b_clk.w_reset_n) begin : PROC_FF_db_state_ptr
    if (!b_clk.w_reset_n) begin
      r_db_state_ptr <= # `TP '0;      
    end else begin
      r_db_state_ptr <= #`TP s_db_state_ptr;
    end
  end

 //Picks the next channel and consults the fetchQ with how many channels are available
  logic [CC_NUM_DMA_CHAN_WIDTH-1:0] r_nxt_ch2ptr, s_nxt_ch2ptr;
  logic [CX_NUM_DMA_CHAN-1:0] fetchq_not_full;

  always_comb begin : PROC_CB_fetchq_not_full
    logic [CX_NUM_DMA_CHAN-1:0] ll_en;

    foreach(ll_en[j])
      ll_en[j] = s_ctxGlb[j].ll_en;

    foreach (fetchq_not_full[i]) begin
      if (ll_en[i])
        fetchq_not_full[i] = (b_llHubNtfy.w_slotsAvailable[i] >= 32'(b_ChElPfetch.w_data[i]+1) && !(r_db_state[i].lastPfetch || r_db_state[i].dbFifoOutStd));
      else // Non-linked list just need 1 slot available
        fetchq_not_full[i] = (b_llHubNtfy.w_slotsAvailable[i] >= 32'(1) && !(r_db_state[i].lastPfetch || r_db_state[i].dbFifoOutStd));
    end
  end

  assign s_nxt_ch2ptr = get_next_db_channel_ptr(
                                                .db_state        (r_db_state),
                                                .db_mask         (b_llHubNtfy.w_db_chsch_mask | b_llFetchNtfy.w_db_chsch_mask),
                                                .fetchq_not_full (fetchq_not_full),
                                                .db_ptr          (r_db_state_ptr.push)
                                                );

  always_ff @ (posedge b_clk.w_main_clk or negedge b_clk.w_reset_n) begin
      if (!b_clk.w_reset_n) begin
        r_nxt_ch2ptr <= # `TP '0;
      end else begin
        r_nxt_ch2ptr <= # `TP s_nxt_ch2ptr;
      end
  end
  
  logic s_schedule_desc; // Schedule a descriptor

  always_comb begin : PROC_schedule_desc
    logic [CX_NUM_DMA_CHAN-1:0][LP_LLQ_RAM_DP_WD-1:0] slotsAvailable;
    logic [CX_NUM_DMA_CHAN-1:0]  chEnable;
    logic [CX_NUM_DMA_CHAN-1:0]  ll_en;
    logic [LP_LLQ_RAM_DP_WD-1:0] ChElPfetch;
    logic [CX_NUM_DMA_CHAN-1:0]  db_chsch_mask;
    logic [LP_LLQ_RAM_DP_WD-1:0] remain_req_slots;
    logic                        remain_req_slots_cry;
    logic [LP_LLQ_RAM_DP_WD:0]   s_upperLimit;

    db_chsch_mask =  b_llHubNtfy.w_db_chsch_mask | b_llFetchNtfy.w_db_chsch_mask;

    ChElPfetch = s_ChElPfetch[r_nxt_ch2ptr]+ 1;
    {remain_req_slots_cry, remain_req_slots} = {1'b0, ChElPfetch} - {1'b0, r_db_state[r_nxt_ch2ptr].llNslotsOutStd};
 
    foreach(ll_en[j])
      ll_en[j] = s_ctxGlb[j].ll_en; 

    chEnable = b_doorbellPulse.w_chEn;

    foreach (slotsAvailable[i])
      slotsAvailable[i] = b_llHubNtfy.w_slotsAvailable[i];

    // Conditions to schedule a descriptor:
    // - A channel is in doorbell state and we are loading the next channel into our processing pointer
    // - A channel is in doorbell state and we have space in the fetchQ
    // - A channel is in doorbell state and it's not masked
    s_schedule_desc = 1'b0;
    if (slotsAvailable[r_nxt_ch2ptr][LP_LLQ_RAM_DP_WD-1:0] != '0) 
      if (r_db_state[r_nxt_ch2ptr].dbstate)
        if (!r_db_state[r_nxt_ch2ptr].fqOutStd[LP_LLQ_RAM_DP_WD])
          if (!(r_db_state[r_nxt_ch2ptr].lastPfetch || r_db_state[r_nxt_ch2ptr].dbFifoOutStd))
            s_schedule_desc = 1'b1;
    if (db_fifo_outs.full)
      s_schedule_desc = 1'b0; //Full must wait on the FIFO

    s_upperLimit = 1 << LP_LLQ_RAM_DP_WD;
    if (s_upperLimit - r_db_state[r_nxt_ch2ptr].fqOutStd - r_db_state[r_nxt_ch2ptr].llNslotsOutStdApp <= {1'b0, remain_req_slots})
      s_schedule_desc = 1'b0; // Avoid to overflow the fqOutStd

    if (remain_req_slots > slotsAvailable[r_nxt_ch2ptr][LP_LLQ_RAM_DP_WD-1:0]) begin
      if (ll_en[r_nxt_ch2ptr])
        s_schedule_desc = 1'b0; // Don't have enough buffer for the programmed prefetch size
    end

    if (db_chsch_mask[r_nxt_ch2ptr])
      s_schedule_desc = 1'b0;

    if (chEnable[r_nxt_ch2ptr] == 1'b0) begin
      s_schedule_desc = 1'b0; //Channel enable is off, do not schedule it
    end

  end

  // between the descriptor scheduling and descriptor fetching there's some latency
  // dbFifoOutStd is used together with llNslotsOutStd to track outstanding descriptors
  always_comb begin : PROC_CB_DB_FIFO_OUTS
    foreach (r_db_state[i]) begin
      s_db_state[i].dbFifoOutStd = r_db_state[i].dbFifoOutStd;

      //note: ChDbRemSlt asserts in linked list mode when it issues an LL read
      //      ChDbRemSlt asserts in non-linked mode when it pushes into the fetchQ
      if ((b_ChDbRemSlt.w_data.channel == CC_NUM_DMA_CHAN_WIDTH'(i)) && (b_ChDbRemSlt.w_data.valid))
        s_db_state[i].dbFifoOutStd = '0;

      if (s_schedule_desc && (r_nxt_ch2ptr == CC_NUM_DMA_CHAN_WIDTH'(i)))
        s_db_state[i].dbFifoOutStd = '1;
    end
  end

  always_comb begin : PROC_CB_LLNREADS
    logic [CX_NUM_DMA_CHAN-1:0] s_dec_llreads;
    logic [CX_NUM_DMA_CHAN-1:0] s_inc_llreads;

    s_dec_llreads = '0;
    s_inc_llreads = '0;

    foreach (r_db_state[i]) begin
    
      s_dec_llreads[i] = b_llHubNtfy.w_LLNtfyValid && (b_llHubNtfy.w_LLNtfyChannel == CC_NUM_DMA_CHAN_WIDTH'(i)) && b_llHubNtfy.w_LLNtfyLst;
      s_inc_llreads[i] = (i == b_ChDbRemSlt.w_data.channel) && b_ChDbRemSlt.w_data.valid && (b_ChDbRemSlt.w_data.llNslots!='0);

      case ({s_inc_llreads[i], s_dec_llreads[i]})
        2'b10: begin
          s_db_state[i].llNreadsApp = (r_db_state[i].llNreadsApp != '1) ? r_db_state[i].llNreadsApp + 'd1 : '1;
          s_db_state[i].llNreads    = (r_db_state[i].llNreads    != '1) ? r_db_state[i].llNreads    + 'd1 : '1;
        end
        2'b01: begin
          s_db_state[i].llNreadsApp = (r_db_state[i].llNreadsApp != '0) ? r_db_state[i].llNreadsApp - 'd1 : '0;
          s_db_state[i].llNreads    = r_db_state[i].llNreads;
        end
        2'b11: begin
          s_db_state[i].llNreadsApp = r_db_state[i].llNreadsApp;
          s_db_state[i].llNreads    = (r_db_state[i].llNreads    != '1) ? r_db_state[i].llNreads    + 'd1 : '1;
        end
        default: begin
          s_db_state[i].llNreadsApp = r_db_state[i].llNreadsApp;
          s_db_state[i].llNreads    = r_db_state[i].llNreads;
        end
      endcase

      // Resets the outstanding llNreads when no more app transactions and hit the last prefetch
      if (s_db_state[i].llNreadsApp == '0 && (r_db_state[i].lastPfetch || !r_db_state[i].dbstate) && !r_db_state[i].dbFifoOutStd)
        s_db_state[i].llNreads = '0;

      // Resets the outstanding llNreads when errors and it did not finished the fetching round
      if (r_db_state[i].llNreadsApp == '0  && |{r_db_state[i].ll_err, r_db_state[i].app_err})
        s_db_state[i].llNreads = '0;
    end
  end

  always_comb begin : PROC_CB_db_state_ptr
    logic s_dec_desc;      // Decrement the outstanding descriptor tracker
    logic s_rst_desc;      // Reset descriptor
    // SMD:A signal or variable is set but never read 
    // SJ: carry is to have the arithmetic expression matched, but it's no used 
    // spyglass disable_block W528
    logic s_carry;         
    //spyglass enable_block W528
    logic [CX_NUM_DMA_CHAN-1:0] [LP_LLQ_RAM_DP_WD-1:0] slotsAvailable;

    s_db_state_ptr = r_db_state_ptr;
    s_carry = '0;

    foreach (slotsAvailable[k])
      slotsAvailable[k] = b_llHubNtfy.w_slotsAvailable[k];
 

    // Decrements the outstanding tracker
    // - the underflow condition should not happen
    s_dec_desc = (b_llHubNtfy.w_LLNtfyValid&& (r_db_state[b_llHubNtfy.w_LLNtfyChannel].llNslotsOutStdApp != 'd0));
    s_rst_desc = b_llHubNtfy.w_LLNtfyNonLL;
   
    if ( s_schedule_desc ) begin
      s_db_state_ptr.push = r_nxt_ch2ptr;
    end

    if (s_schedule_desc) begin
      s_db_state_ptr.tog = ~r_db_state_ptr.tog;
    end else begin
      s_db_state_ptr.tog = r_db_state_ptr.tog;
    end

   
    foreach (r_db_state[j]) begin
      s_db_state[j].llNslotsOutStdApp = r_db_state[j].llNslotsOutStdApp;
      s_db_state[j].llNslotsOutStd    = r_db_state[j].llNslotsOutStd   ;
    end

    // The outstanting tracker is decremented when the descriptor data in pushed into the queue
    // it gets incremented when the LL_FETCH reads a descriptor
    foreach (r_db_state[i]) begin
      // When there're errors the several descriptor read returns without data
      // To avoid waiting for llNslots that will never returnm this will
      // clear it on that scenario
      if (r_db_state[i].llNreadsApp == '0  && |{r_db_state[i].ll_err, r_db_state[i].app_err}) begin
        s_db_state[i].llNslotsOutStdApp = '0;
        s_db_state[i].llNslotsOutStd    = '0;
      end 
      
      if ((i == b_ChDbRemSlt.w_data.channel) && b_ChDbRemSlt.w_data.valid && !s_dec_desc)begin
        // SMD: A signal or variable is set but never read                          
        // SJ:  carry is to have the arithmetic expression matched, but it's no used
        // spyglass disable_block W528
        {s_carry, s_db_state[i].llNslotsOutStdApp} = {1'b0, r_db_state[i].llNslotsOutStdApp} + {1'b0, b_ChDbRemSlt.w_data.llNslots};
        {s_carry, s_db_state[i].llNslotsOutStd   } = {1'b0, r_db_state[i].llNslotsOutStd   } + {1'b0, b_ChDbRemSlt.w_data.llNslots};

      end else if ((i == b_llHubNtfy.w_LLNtfyChannel) && !b_ChDbRemSlt.w_data.valid && s_dec_desc) begin

        s_db_state[i].llNslotsOutStdApp -= 'd1;
        if (s_rst_desc) begin
          s_db_state[i].llNslotsOutStdApp = '0;
          s_db_state[i].llNslotsOutStd    = '0;
        end

      end else if(b_ChDbRemSlt.w_data.valid && s_dec_desc) begin  

        if ( (i == b_llHubNtfy.w_LLNtfyChannel) && (i == b_ChDbRemSlt.w_data.channel) ) begin
        
          {s_carry, s_db_state[i].llNslotsOutStdApp} = {1'b0, r_db_state[i].llNslotsOutStdApp} + {1'b0, b_ChDbRemSlt.w_data.llNslots} - 'd1; 
          {s_carry, s_db_state[i].llNslotsOutStd   } = {1'b0, r_db_state[i].llNslotsOutStd   } + {1'b0, b_ChDbRemSlt.w_data.llNslots}; 
          if (s_rst_desc) begin
            s_db_state[i].llNslotsOutStdApp = slotsAvailable[r_nxt_ch2ptr][LP_LLQ_RAM_DP_WD-1:0];
            s_db_state[i].llNslotsOutStd    = slotsAvailable[r_nxt_ch2ptr][LP_LLQ_RAM_DP_WD-1:0];
          end
        end else if (i == b_llHubNtfy.w_LLNtfyChannel) begin

          s_db_state[i].llNslotsOutStdApp -= 'd1; 
          if (s_rst_desc) begin
            s_db_state[i].llNslotsOutStdApp = '0;
            s_db_state[i].llNslotsOutStd    = '0;
          end
        end else if ((i == b_ChDbRemSlt.w_data.channel) ) begin
          
          {s_carry, s_db_state[i].llNslotsOutStdApp} = {1'b0, r_db_state[i].llNslotsOutStdApp}+{1'b0, b_ChDbRemSlt.w_data.llNslots};
          {s_carry, s_db_state[i].llNslotsOutStd   } = {1'b0, r_db_state[i].llNslotsOutStd   }+{1'b0, b_ChDbRemSlt.w_data.llNslots};

        //spyglass enable_block W528
        end
      end

      // Resets the outstanding slots when no more app transactions and hit the last prefetch after LL fetch submission
      if (s_db_state[i].llNreadsApp == '0  && (r_db_state[i].lastPfetch || !r_db_state[i].dbstate) && !r_db_state[i].dbFifoOutStd)
        s_db_state[i].llNslotsOutStdApp = '0;

      if (s_db_state[i].llNslotsOutStdApp == '0 && (r_db_state[i].lastPfetch || !r_db_state[i].dbstate) && !r_db_state[i].dbFifoOutStd)
        s_db_state[i].llNslotsOutStd = '0;

    end
  end

  always_comb begin : PROC_lastPfetch

    // When lastPfetch, stops pushing channels into LL Fetcher
    foreach (r_db_state[k]) begin

      if (s_schedule_desc && (r_nxt_ch2ptr == k)) begin
        s_db_state[k].lastPfetch = '0;
      end else if ((b_ChDbRemSlt.w_data.channel == k) && b_ChDbRemSlt.w_data.valid) begin
        s_db_state[k].lastPfetch = LP_LLQ_RAM_DP_WD'(r_db_state[k].llNslotsOutStd + b_ChDbRemSlt.w_data.llNslots) > b_ChElPfetch.w_data[k];
      end else if (r_db_state[k].llNslotsOutStd != '0 && s_db_state[k].llNslotsOutStd == '0) begin
        s_db_state[k].lastPfetch = '0; // Resumes in LL mode when outstanding is zero
      end else begin
        s_db_state[k].lastPfetch =  r_db_state[k].lastPfetch;
      end

    end 

  end

  always_comb begin : PROC_CB_fqOutSts

    s_fqOutStd_inc = '0;
    s_fqOutStd_dec = '0;

    foreach (r_db_state[i]) begin
      
      if (i == b_llHubNtfy.w_PushNtfyChannel)
        s_fqOutStd_inc[i] =  b_llHubNtfy.w_PushNtfyValid;

      if (i == b_stsh2ctx_update.w_data.channel) 
        s_fqOutStd_dec[i] = b_stsh2ctx_update.w_valid && b_stsh2ctx_update.w_ready;

      case ({r_db_state[i].app_err || r_db_state[i].stop, s_fqOutStd_inc[i], s_fqOutStd_dec[i]})
        default: begin
          s_db_state[i].fqOutStd = r_db_state[i].fqOutStd;
        end
        3'b001: begin // Decrement
          s_db_state[i].fqOutStd = r_db_state[i].fqOutStd != '0 ?  r_db_state[i].fqOutStd - 1 :  r_db_state[i].fqOutStd;
        end
        3'b010: begin
          s_db_state[i].fqOutStd = r_db_state[i].fqOutStd != '1 ?  r_db_state[i].fqOutStd + 1 :  r_db_state[i].fqOutStd;
        end
        3'b100, 3'b101, 3'b110, 3'b111: begin
          //The error token flushes descriptors in the fetchq, so the outstanding counter must be cleared
          s_db_state[i].fqOutStd = '0;
        end
      endcase
    end

  end

  


  //Passes the channel number and doorbells if enabled
  always_comb begin : PROC_CB_db_fifo_ins
    logic bcarry; //bad carry
    
    db_fifo_ins.data.channel               = s_db_state_ptr.push;
    db_fifo_ins.data.llNslotsOuts          = s_db_state[s_db_state_ptr.push].llNslotsOutStd;
    db_fifo_ins.data.llNslotsOutsLst       = s_db_state[s_db_state_ptr.push].lastPfetch;
    db_fifo_ins.data.llNreads              = s_db_state[s_db_state_ptr.push].llNreads;
    db_fifo_ins.push_req_n                 = (r_db_state_ptr.tog == s_db_state_ptr.tog);   
    {bcarry, db_fifo_ins.data.llNslotsReq} = ({1'b0, s_ChElPfetch[s_db_state_ptr.push]} + 1) - 
                                             {1'b0, r_db_state[s_db_state_ptr.push].llNslotsOutStd};
    db_fifo_ins.data.ElPfetch              = s_ChElPfetch[s_db_state_ptr.push];

      `ifndef SYNTHESIS
    //VCS coverage off
        assert((bcarry !== '1) || db_fifo_ins.push_req_n);
    //VCS coverage on
      `endif
    
  end
  
  // Queue of channels ready to be processed
  logic nc_half_full;
  logic nc_almost_full;

  assign db_fifo_ins.pop_req_n = !b_ChDbFifo.w_pop;
  DWC_pcie_ctl_bcm65_td
  
    #(
      .WIDTH          ($bits(P_DBMNGR_TYPE)),
      .DEPTH          (CC_IF_CTRL_LL_RAM_LATENCY+2),
      .AE_LEVEL       (1),
      .AF_LEVEL       (1),
      .ERR_MODE       (0),
      .RST_MODE       (0), 
      .ADDR_WIDTH     ($clog2(CC_IF_CTRL_LL_RAM_LATENCY+2)),
      .REG_DELAY_TIME (LP_REG_DELAY_TIME),
      .REG_DELAY_DENOM(LP_REG_DELAY_DENOM)
      ) u_db_fifo
      ( 
        .clk         (b_clk.w_aux_clk), 
        .rst_n       (b_clk.w_reset_n), 
        .init_n      (1'b1),
        .push_req_n  (db_fifo_ins.push_req_n), 
        .pop_req_n   (db_fifo_ins.pop_req_n), 
        .diag_n      (1'b1),
        .data_in     (db_fifo_ins.data), 
        .empty       (db_fifo_outs.empty), 
        .almost_empty(db_fifo_outs.almEmpty),
        // SMD: A signal or variable is set but never read                          
        // SJ:  BCM output signals not required by the logic
        // spyglass disable_block W528
        .half_full   (nc_half_full),
        .almost_full (nc_almost_full),
        .error       (db_fifo_outs.error),
        // spyglass enable_block W528
        .full        (db_fifo_outs.full),
        .data_out    (db_fifo_outs.data) 
        );
  
  assign b_ChDbFifo.w_empty    = db_fifo_outs.empty;
  assign b_ChDbFifo.w_error    = db_fifo_outs.error;
  assign b_ChDbFifo.w_data     = db_fifo_outs.data;
  assign b_ChDbFifo.w_almEmpty = db_fifo_outs.almEmpty;


  // *************************************************************************
  // Descriptor flush clear on the LL HUB when the outstanding is zero
  // *************************************************************************
  always_comb begin : PROC_CB_flushclr
    logic [LP_LLQ_RAM_DP_WD:0] s_llOuts[0:CX_NUM_DMA_CHAN-1];
    logic [CX_NUM_DMA_CHAN-1:0] s_llDescFlushClr;

    for (int i=0;i<CX_NUM_DMA_CHAN;i++)
      s_llOuts[i] = {r_db_state[i].dbFifoOutStd,r_db_state[i].llNslotsOutStd};

    for (int i=0;i<CX_NUM_DMA_CHAN;i++)
      s_llDescFlushClr[i] = (s_llOuts[i] == '0); 

    b_llHubNtfy.w_llDescFlushClr = s_llDescFlushClr;

  end
  // *************************************************************************
 
  
// SNPS_SysML_CODE_END

endmodule
