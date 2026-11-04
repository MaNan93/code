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
// ---    $Revision: #5 $ 
// ---    $Author: lnicola $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_req_serializer.sv#5 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_cdmregs_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_req_dataSerializer_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ctxPush_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_req_serializer
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter       type P_DATA_TYPE = dmaWrEngCtx_s
  ,parameter       type P_OVRL_TYPE = elemCtxWr_s
  ,parameter        CX_NUM_DMA_CHAN = 16
  ,parameter dmaEngType_e P_CHANNEL = E_WRITE
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_req_dataSerializer_if.master_mp b_cacheAccess
  ,DWC_pcie_edmapf_cdmregs_if.slave_mp             b_cdm
  ,DWC_pcie_edmapf_aclks_if.slave_mp               b_clk
  ,DWC_pcie_edmapf_ctxPush_if.master_mp            b_push
  ,DWC_pcie_edmapf_tlp_if.master_mp                b_rdData
  );


// SNPS_SysML_CODE_START
  localparam CC_NUM_DMA_CHAN_WIDTH  = (CX_NUM_DMA_CHAN==1) ? 1 : $clog2(CX_NUM_DMA_CHAN);
  localparam L_STAGES               = P_CHANNEL == E_WRITE ? K_DMA_WR_RR_STAGES  : K_DMA_RD_RR_STAGES;
  localparam L_STAGES_CNT_WD        = $clog2(L_STAGES+1);
  localparam LP_INTERNAL_LATENCY    = P_CHANNEL == E_WRITE ? K_DMA_WR_LL_REQ_STAGES  : K_DMA_RD_LL_REQ_STAGES;
  localparam LP_INTERNAL_LATENCY_WD = $clog2(LP_INTERNAL_LATENCY);
  localparam LP_LINKED_LISTS        = (CX_NUM_DMA_CHAN<LP_INTERNAL_LATENCY) ? CX_NUM_DMA_CHAN : LP_INTERNAL_LATENCY;
  localparam LP_LINKED_LISTS_WD     = (LP_LINKED_LISTS == 1 ) ? 1 : $clog2(LP_LINKED_LISTS);
  localparam L_STAGES_LL            = 2;
  /*
   Internal Structure to propagate data
  */
  typedef struct packed {
    P_DATA_TYPE                             data        ;
    logic                            [31:0] xferSizeCalc;
    logic                                   token;
    logic                                   last;
    logic                                   flush;
    logic                                   stop;
    logic          [LP_LINKED_LISTS_WD-1:0] position;
  } reqInternalData_s;
  /*
    Singals connected to the external interface
  */
  logic                                  [LP_LINKED_LISTS-1:0] s_llValid;
  logic                                  [LP_LINKED_LISTS-1:0] s_flush;
  logic                                  [LP_LINKED_LISTS-1:0] r_flush;
  P_DATA_TYPE                            [LP_LINKED_LISTS-1:0] s_dataIncoming;
  /*
    Processing Data
  */
  logic                                  [LP_LINKED_LISTS-1:0] r_llValid;
  logic                                  [LP_LINKED_LISTS-1:0] s_locked;
  logic                                  [LP_LINKED_LISTS-1:0] s_acceptData;
  /*
    Signals used to select the linked list and context corrects
  */
  logic                                  [LP_LINKED_LISTS-1:0] s_linkedListRequested;
  logic                                                        s_linkedListGranted;
  P_DATA_TYPE                            [LP_LINKED_LISTS-1:0] r_data;
  reqInternalData_s                      [LP_LINKED_LISTS-1:0] s_dataCtx;
  reqInternalData_s                                            s_contextToSend;
  /*
    Counting the number of descriptores are on RR arbiter
  */
  logic              [LP_LINKED_LISTS-1:0] [L_STAGES_CNT_WD:0] r_rrArbElements;
  /*
    Calculating the byte enables, transfer size and DW length
  */
  logic                                                 [3:0]  s_nxt_1st_byte_en;
  logic                                                 [3:0]  s_nxt_last_byte_en;
  logic                                                 [10:0] s_nxt_dw_len;
  logic                                                 [12:0] s_nxt_byte_len;
  /*
    Channel Weight Counter
  */
  logic                                                  [4:0] r_chWeightCntr;
  logic                                                        s_chWeightCntrEn;
  logic                                                        s_chWeightCntrRst;
  logic                                                        s_chWeightTimeout;
  /*
    Signals used to generate read transactions
  */
  logic                                                        s_requestValid;
  logic                                                        s_hv;
  /*
    Feedback signals to indicate the status of context that is being processed
  */
  logic                                  [LP_LINKED_LISTS-1:0] s_contextFinished;
  logic                                  [LP_LINKED_LISTS-1:0] s_contextNotFinished;
  P_OVRL_TYPE                            [LP_LINKED_LISTS-1:0] s_contextWriteBack;
  /*
    Signals used on Stop operations
  */
  logic                                  [LP_LINKED_LISTS-1:0] s_tokenOrStop;
  logic                                  [LP_LINKED_LISTS-1:0] s_dropReq;
  
  /*
    Connecting external interface with internal signals
  */
  always_comb begin : c_connectExternalInterface_PROC
    s_llValid      = b_cacheAccess.w_valid;
    s_dataIncoming = b_cacheAccess.w_data;
    s_flush        = b_cacheAccess.w_flush;
    s_dropReq      = b_cacheAccess.w_dropReq;
  end : c_connectExternalInterface_PROC
  
  /*
    Starting flush
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_r_flush_PROC
    if (!b_clk.w_reset_n) begin
      r_flush <= #`TP '0;
    end else begin
      foreach(r_flush[i]) begin
        //case({s_contextToSend.flush /*(r_rrArbElements[i]=='d1)*/ && s_requestValid && (LP_LINKED_LISTS_WD'(i)==s_contextToSend.position), s_flush[i] && |r_rrArbElements[i] && r_llValid[i]})
        case({(r_rrArbElements[i]=='0) && !r_llValid[i] && !s_llValid[i], s_flush[i] && (|r_rrArbElements[i] || r_llValid[i])})
          2'b01:
            begin
              r_flush[i] <= #`TP '1;
            end
          2'b10:
            begin
              r_flush[i] <= #`TP '0;
            end
        endcase
      end
    end
  end : s_r_flush_PROC
  
  /*
    Signal used to lock the linked list
  */
  always_comb begin : c_lockingLL_PROC
    foreach (s_locked[i]) begin
      s_locked[i] = r_llValid[i] || (|r_rrArbElements[i]) || r_flush[i];
    end
  end : c_lockingLL_PROC
  
  /*
    Identify if data is valid or not
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_llValid_PROC
    if (!b_clk.w_reset_n) begin
      r_llValid <= #`TP '0;
    end else begin
      foreach(r_llValid[i]) begin
        case({s_contextFinished[i] || (r_flush[i] && s_linkedListRequested[i]/*|r_rrArbElements[i]*/), s_llValid[i]})
          2'b01:
            begin
              r_llValid[i] <= #`TP '1;
            end
          2'b10:
            begin
              r_llValid[i] <= #`TP '0;
            end
        endcase
      end
    end
  end : s_llValid_PROC
  
  /*
    Indicating when data is accepted
  */
  always_comb begin : c_acceptData_PROC
    foreach (s_acceptData[i]) begin
      s_acceptData[i] = s_llValid[i] && (!r_llValid[i] || s_contextFinished[i]);
    end
  end : c_acceptData_PROC
  
  /*
    Processing data
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_dataProcess_PROC
    if (!b_clk.w_reset_n) begin
      r_data <= #`TP '0;
    end else begin
      foreach(r_data[i]) begin
        case({s_contextNotFinished[i], s_acceptData[i]})
          2'b01:
            begin
              r_data[i] <= #`TP s_dataIncoming[i];
            end
          2'b10:
            begin
              r_data[i].ctx.ovrl <= #`TP s_contextWriteBack[i];
            end
        endcase
      end
    end
  end : s_dataProcess_PROC
  
  /*
    Indicates when stop or token is being sent
  */
  always_comb begin : c_s_flagSent_PROC
    foreach(s_tokenOrStop[i]) begin
      s_tokenOrStop[i] = r_data[i].ctx.ovrl.token || b_cacheAccess.w_stop[i];
    end
  end : c_s_flagSent_PROC
  
  /*
    Preparing data to be injected into linked list scheduler
  */
  always_comb begin : c_s_dataCtx_PROC
    foreach (s_dataCtx[i]) begin
      s_dataCtx[i] = '{
                       default: '0
                      ,data: r_data[i]
                      ,xferSizeCalc: s_tokenOrStop[i] ? '0 : // In case of a token issue a null read
                                     dma_fetch_tlp_calc_size
                                     (
                                      .WRITE_CH_NOT_READ_CH(P_CHANNEL == E_WRITE),

                                      .cfg_max_payload_size(b_cdm.w_cfg_max_payload_size),
                                      .cfg_max_rd_req_size(b_cdm.w_cfg_max_rd_req_size),
                                      .cfg_remote_rd_req_bridge_size(b_cdm.w_cfg_remote_rd_req_bridge_size),

                                      .pf(r_data[i].ctx.glb.tlpSettings.d_pf),
                                      .ctrl_ch_dar_ptr({r_data[i].ctx.ovrl.ovrlData.darHigh, r_data[i].ctx.ovrl.ovrlData.darLow}),
                                      .ctrl_ch_sar_ptr({r_data[i].ctx.ovrl.ovrlData.sarHigh, r_data[i].ctx.ovrl.ovrlData.sarLow}),
                                      .ctrl_ch_xfersize(r_data[i].ctx.ovrl.ovrlData.xferSize)
                                      )
                      ,stop: b_cacheAccess.w_stop[i]
                      ,token: r_data[i].ctx.ovrl.token
                      ,last: s_contextFinished[i]
                      ,flush: r_flush[i]
                      ,position: LP_LINKED_LISTS_WD'(i)
                      };
    end
  end : c_s_dataCtx_PROC
  
  /*
    Counting number of descriptores on RR Arbiter
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_countingRrArbElements_PROC
    if (!b_clk.w_reset_n) begin
      r_rrArbElements <= #`TP '0;
    end else begin
      foreach(r_rrArbElements[i]) begin
        case({s_requestValid && (s_contextToSend.position == LP_LINKED_LISTS_WD'(i)) ,s_linkedListRequested[i]})
          2'b01:
            begin
              r_rrArbElements[i] <= #`TP r_rrArbElements[i] + 'd1;
            end
          2'b10:
            begin
              r_rrArbElements[i] <= #`TP r_rrArbElements[i] - 'd1;
            end
        endcase
      end
    end
  end : s_countingRrArbElements_PROC
  
  /*
  Roud-Robin arbitrer to decide which linked list should be granted
  */
  DWC_pcie_staged_arbiter
  
   #(
     .P_INPUTS   (LP_LINKED_LISTS  )
    ,.P_STAGES   (L_STAGES         )
    ,.P_DATATYPE (reqInternalData_s)
  ) u_rr_arb_llGranted (
      .i_clk     (b_clk.w_main_clk        )
     ,.i_rst_n   (b_clk.w_reset_n         )
     ,.i_clr_n   (1'b1                    )
     ,.i_en      (1'b1                    )
     ,.i_ready   (s_requestValid          )
     ,.i_request (r_llValid               )
     ,.i_data    (s_dataCtx               )
     ,.o_grant   (s_linkedListRequested   )
     ,.o_valid   (s_linkedListGranted     )
     ,.o_data    (s_contextToSend         )
  );
  
  /*
    Calculating the new SAR, DAR and TransferSize
  */
  always_comb begin : c_contextWriteBack_PROC
    foreach(s_contextWriteBack[i]) begin
      s_contextWriteBack[i] = f_nxtOvrlCtx(
                                           .s_prevOvrlCtx(s_dataCtx[i].data.ctx.ovrl)
                                          ,.s_nxtTlpSize(s_dataCtx[i].xferSizeCalc)
                                          );
    end
  end : c_contextWriteBack_PROC
  
  /*
    Indicating that context was completed process
  */
  always_comb begin : c_contextFinished_PROC
    foreach(s_contextFinished[i]) begin
      s_contextFinished[i] = (s_tokenOrStop[i] || (s_dataCtx[i].data.ctx.ovrl.ovrlData.xferSize <= s_dataCtx[i].xferSizeCalc)) && s_linkedListRequested[i];
    end
  end : c_contextFinished_PROC

  /*
    Indicating that context was not completed process
  */
  always_comb begin : c_contextNotFinished_PROC
    foreach(s_contextNotFinished[i]) begin
      s_contextNotFinished[i] = !s_tokenOrStop[i] && (s_dataCtx[i].data.ctx.ovrl.ovrlData.xferSize > s_dataCtx[i].xferSizeCalc) && s_linkedListRequested[i];
    end
  end : c_contextNotFinished_PROC
  
  /*
    Updating Cache
  */
  always_comb begin : c_b_cacheAccess_PROC
    b_cacheAccess.w_sent               = s_requestValid && (s_contextToSend.last || (r_flush[s_contextToSend.position] && s_contextToSend.flush/*|r_rrArbElements[s_contextToSend.position]*/));
    b_cacheAccess.w_channel            = s_contextToSend.data.channel;
    b_cacheAccess.w_token              = s_contextToSend.token;
    b_cacheAccess.w_accepted           = s_acceptData;
    b_cacheAccess.w_locked             = s_locked;
    b_cacheAccess.w_sentFlag           = s_requestValid && s_contextToSend.stop;
    b_cacheAccess.w_llErased           = s_contextToSend.position;
  end : c_b_cacheAccess_PROC
 
  /*
    Validating the request to be send
  */
  always_comb begin : c_s_requestValid_PROC
    s_requestValid = s_linkedListGranted && !b_push.w_full && !b_rdData.w_halt;
  end : c_s_requestValid_PROC
  
  /*
    Generating the header valid and end of transmission
  */
  always_comb begin : c_hvForReads_PROC
    s_hv = s_linkedListGranted && !b_push.w_full && !s_dropReq[s_contextToSend.position];
  end : c_hvForReads_PROC
  
//  /*
//    Setting the signals to reset or enable the counter
//  */
//  always_comb begin : c_chWeightCntrCtrl_PROC
//    s_chWeightCntrEn  =   (r_chWeightCntr <  s_contextToSend.glb.weight) && s_requestValid;
//    s_chWeightCntrRst = (((r_chWeightCntr == s_contextToSend.glb.weight) && s_requestValid) || s_contextFinished)/* && s_channelInQueue*/;
//  end : c_chWeightCntrCtrl_PROC
//  
//  /*
//    Channel Weight counter
//  */
//  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_chWeightCntr_PROC
//    if (!b_clk.w_reset_n) begin
//      r_chWeightCntr <= #`TP '0;
//    end else begin
//      if(s_chWeightCntrRst) begin
//        r_chWeightCntr <= #`TP '0;
//      end else if(s_chWeightCntrEn) begin
//        r_chWeightCntr <= #`TP r_chWeightCntr + 'd1;
//      end
//    end
//  end : s_chWeightCntr_PROC
//  
//  /*
//    Indication that requester should move to another channel
//  */
//  always_comb begin : c_chWeightTimeout_PROC
//    s_chWeightTimeout = ((r_chWeightCntr == s_contextToSend.glb.weight) || s_contextFinished)/* && s_channelInQueue*/;
//  end : c_chWeightTimeout_PROC
  
  /*
    Calculating the byte enables and DW length
  */
  always_comb begin : c_calcTlpFields_PROC

    {s_nxt_last_byte_en, s_nxt_1st_byte_en} = dma_byte_enables(
                                                                .addressLow(s_contextToSend.data.ctx.ovrl.ovrlData.sarLow)
                                                               ,.payloadSize(s_contextToSend.xferSizeCalc)
                                                              );

    s_nxt_byte_len = 13'(s_contextToSend.xferSizeCalc[12:0] + {10'd0, s_contextToSend.data.ctx.ovrl.ovrlData.sarLow[1:0]});

    s_nxt_dw_len = s_contextToSend.xferSizeCalc == '0 ? 11'd1 : //Zero transfer size transports 1 null DW in PCIe
                 {1'b0, s_nxt_byte_len[11:2]} +
                 {10'd0, |s_nxt_byte_len[1:0]};
    
  end : c_calcTlpFields_PROC
  
  /*
    Generating the Read TLPs
  */
  always_comb begin : c_readTlpGen_PROC
    b_rdData.w_header                           = '0;
    b_rdData.w_header.common1.attr              = '{
       default    : '0
      ,snoop      : s_contextToSend.data.ctx.glb.tlpSettings.s_sn
      ,relaxOrder : s_contextToSend.data.ctx.glb.tlpSettings.d_ro
    };
    b_rdData.w_header.common1.ln                = '0;
    b_rdData.w_header.common1.pcieTag           = '0;
    b_rdData.w_header.common1.tc                = s_contextToSend.data.ctx.glb.tlpSettings.d_tc;
    b_rdData.w_header.common1.vfunc_active      = s_contextToSend.data.ctx.glb.tlpSettings.d_vf_en;
    b_rdData.w_header.common1.vfunc_num         = s_contextToSend.data.ctx.glb.tlpSettings.d_vf[K_VFWD-2:0];
    b_rdData.w_header.common1.pfunc_num         = (s_contextToSend.data.ctx.glb.tlpSettings.d_pf[K_PFWD-1:0]);

    b_rdData.w_header.common2.addr              = {s_contextToSend.data.ctx.ovrl.ovrlData.sarHigh, s_contextToSend.data.ctx.ovrl.ovrlData.sarLow[31:2], 2'd0};
    b_rdData.w_header.common2.ats               = P_CHANNEL == E_WRITE ? '0 : s_contextToSend.data.ctx.glb.tlpSettings.d_ats;
    b_rdData.w_header.common2.cpl_bcm           = '0;
    b_rdData.w_header.common2.cpl_status        = '0;
    b_rdData.w_header.common2.dw_len            = s_nxt_dw_len[9:0];
    b_rdData.w_header.common2.fmt               = {1'b0, |s_contextToSend.data.ctx.ovrl.ovrlData.sarHigh};
    b_rdData.w_header.common2.prfx              = K_PRFXDEFAULT;
    b_rdData.w_header.common2.td                = '0;
    b_rdData.w_header.common2.tph_ph            = '0;
    b_rdData.w_header.common2.tph_st            = '0;
    b_rdData.w_header.common2.tph_th            = '0;
    b_rdData.w_header.common2.typ               = '0;
    b_rdData.w_header.common2.byte_cnt          = '0;
    b_rdData.w_header.common2.cmpltr_id         = '0;
    b_rdData.w_header.common2.first_be          = s_nxt_1st_byte_en;
    b_rdData.w_header.common2.last_be           = s_nxt_last_byte_en;
    b_rdData.w_header.common2.poisoned          = '0;

    b_rdData.w_header.common3                   = '0;

    b_rdData.w_header.common4.tlp_abort         = '0;
    b_rdData.w_header.common4.rom_in_range      = '0;
    b_rdData.w_header.common4.req_id            = '0;
    b_rdData.w_header.common4.io_req_in_range   = '0;
    b_rdData.w_header.common4.in_membar_range   = '1;
    b_rdData.w_header.common4.ecrc_err          = '0;
    b_rdData.w_header.common4.dwen              = '0;
    b_rdData.w_header.common4.dllp_abort        = '0;
    b_rdData.w_header.common4.cpl_last          = '0;

    b_rdData.w_header.radmPort.vc_num           = '0;
    b_rdData.w_header.radmPort.mem_type         = s_contextToSend.data.ctx.glb.tlpSettings.mtype;
    b_rdData.w_header.radmPort.uppr_bytes       = '0;
    b_rdData.w_header.radmPort.uppr_bytes_valid = '0;

    b_rdData.w_header.xadmPort.addr_align_en    = '0;
    b_rdData.w_header.xadmPort.bad_eot          = '0;
    b_rdData.w_header.xadmPort.atu_bypass       = '1;

    b_rdData.w_header.dma.req                   = P_CHANNEL == E_WRITE ? E_DMA_WRCH_DATA : E_DMA_RDCH_DATA;

    b_rdData.w_header.dma.channel                            = '0;
    b_rdData.w_header.dma.channel[CC_NUM_DMA_CHAN_WIDTH-1:0] = s_contextToSend.data.channel;

    b_rdData.w_header.tag                       = b_push.w_tag;
    b_rdData.w_data                             = '0;
    b_rdData.w_dv                               = '0;
    b_rdData.w_hv                               = s_hv;
    b_rdData.w_eot                              = s_hv;
    b_rdData.w_headerProt                       = '0;
  end : c_readTlpGen_PROC
  
  /*
    Storing additional data
  */
  always_comb begin : c_storingElementData_PROC
    b_push.w_push            = s_requestValid && !s_dropReq[s_contextToSend.position];
    b_push.w_data.ovrl       = s_contextToSend.data.ctx.ovrl;
    b_push.w_data.ovrl.stop  = b_cacheAccess.w_sentFlag;
    b_push.w_data.ovrl.token = s_contextToSend.stop && !s_contextToSend.data.ctx.ovrl.stop && (s_contextToSend.data.ctx.ovrl.errors inside {E_DMAERR_LL_CPL_UR, E_DMAERR_LL_CPL_CA, E_DMAERR_LL_CPL_EP, E_DMAERR_NONE}) ? '0 : s_contextToSend.data.ctx.ovrl.token;
    b_push.w_data.channel    = s_contextToSend.data.channel;
  end : c_storingElementData_PROC

  function automatic P_OVRL_TYPE f_nxtOvrlCtx(input P_OVRL_TYPE s_prevOvrlCtx, input logic [31:0] s_nxtTlpSize);
    P_OVRL_TYPE s_nxtOvrlCtx;
    logic       w_carry_a,
                w_carry_b,
                w_carry_c;

    w_carry_a    = '0;
    w_carry_b    = '0;
    w_carry_c    = '0;
    s_nxtOvrlCtx = s_prevOvrlCtx;

    {w_carry_a, s_nxtOvrlCtx.ovrlData.xferSize} = {1'b0, s_prevOvrlCtx.ovrlData.xferSize} - {1'b0, s_nxtTlpSize};
    {w_carry_b, s_nxtOvrlCtx.ovrlData.sarHigh,s_nxtOvrlCtx.ovrlData.sarLow} = {1'b0, s_prevOvrlCtx.ovrlData.sarHigh, s_prevOvrlCtx.ovrlData.sarLow} + 
                                                                  {1'b0, s_nxtTlpSize};
    {w_carry_c, s_nxtOvrlCtx.ovrlData.darHigh,s_nxtOvrlCtx.ovrlData.darLow} = {1'b0, s_prevOvrlCtx.ovrlData.darHigh, s_prevOvrlCtx.ovrlData.darLow} + 
                                                                  {1'b0, s_nxtTlpSize};

    return s_nxtOvrlCtx;
  endfunction : f_nxtOvrlCtx

// SNPS_SysML_CODE_END

endmodule
