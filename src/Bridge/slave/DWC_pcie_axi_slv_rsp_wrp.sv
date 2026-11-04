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
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/slave/DWC_pcie_axi_slv_rsp_wrp.sv#6 $
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_axi_slv_rsp_wrp
   #(
   parameter SLV_BUS_DATA_WIDTH            = 128,
   parameter SLV_BURST_LEN_PW              = 2,
   parameter RD_NP_RSP_WRAP_INFO_WD        = 11,
   parameter SLV_WRP_RSP_ROB_FIFO_DP        = `CC_SLV_WRP_RSP_ROB_FIFO_DP,
   parameter SLV_WRP_RSP_ROB_FIFO_ADDR_WD   = `CC_SLV_WRP_RSP_ROB_FIFO_ADDR_WD,
   parameter TP                            = `TP
   )
   (
   input                                              slv_aclk,
   input                                              slv_aresetn,
   // -------------------------------------------------------------------------------------
   // AXI aligned response interface
   input                                              axalgn_valid,
   input       [RD_NP_RSP_WRAP_INFO_WD-1:0]           axalgn_info,
   input       [3:0]                                  axalgn_info_wrap_beat_offset,
   input       [SLV_BURST_LEN_PW-1:0]                 axalgn_info_len,
   input       [SLV_BUS_DATA_WIDTH-1:0]               axalgn_data,
   input                                              axalgn_last,
   output wire                                        wprordr_ready,
   // -------------------------------------------------------------------------------------
   // Wrap response interface
   output wire                                        wprordr_rvalid,
   output wire [RD_NP_RSP_WRAP_INFO_WD-1:0]           wprordr_info,
   output wire [SLV_BUS_DATA_WIDTH-1:0]               wprordr_rdata,
   output wire                                        wprordr_rlast,
   input                                              pdly1_rready
   );

   // -------------------------------------------------------------------------------------
   // Local parameters

   // {info, offset, len}
   localparam SLV_WRP_RSP_HDB_WD = RD_NP_RSP_WRAP_INFO_WD + 4 + SLV_BURST_LEN_PW;
   localparam SLV_WRP_RSP_HDB_DP = `CC_SLV_WRP_RSP_HDB_DP;
   localparam SLV_WRP_RSP_HDB_ADDR_WD = `CC_SLV_WRP_RSP_HDB_ADDR_WD;
   localparam SLV_WRP_RSP_NUM_OUTSTD_WD = `CC_SLV_WRP_RSP_NUM_OUTSTD_WD;

   // Read Response Channel FSM's
   localparam S_RD_SOT = 2'b01;
   localparam S_RD_LOAD = 2'b00;
   localparam S_RD_BYPASS = 2'b10;
   localparam S_RD_WAIT = 2'b11;

   localparam S_WR_IDLE = 1'b0;
   localparam S_WR_OFFLOAD = 1'b1;

   // BCM64 transport delay parameters
   localparam integer REG_DELAY_DENOM = 1000;
   localparam integer REG_DELAY_TIME  = `TP * REG_DELAY_DENOM;


  // -------------------------------------------------------------------------------------
  // RAM / FIFO Controller Signals
   wire [SLV_BUS_DATA_WIDTH-1:0]          wrporb_sfifo_pop_data;
   wire                                     wrporb_sfifo_f;
   wire                                     wrporb_sfifo_e;
   wire                                     wrporhb_full;

   // -------------------------------------------------------------------------------------
   // FSM states
   reg  [1:0]                               r_rd_wrap_st;
   reg  [1:0]                               s_rd_wrap_st;
   reg                                      r_wr_wrap_st;
   reg                                      s_wr_wrap_st;

   // -------------------------------------------------------------------------------------
   // Counters
   reg  [3:0]                               r_rd_wrap_beat_cnt;
   reg  [3:0]                               s_rd_wrap_beat_cnt;
   reg  [SLV_BURST_LEN_PW-1:0]              s_wr_beat_cnt;
   reg  [SLV_BURST_LEN_PW-1:0]              r_wr_beat_cnt;
   reg  [SLV_WRP_RSP_NUM_OUTSTD_WD-1:0]     s_outstanding_cnt;
   reg  [SLV_WRP_RSP_NUM_OUTSTD_WD-1:0]     r_outstanding_cnt;

   // -------------------------------------------------------------------------------------
   // FIFO interface signals
   wire                                     data_push;
   reg                                      data_pop;
   wire                                     data_push_n;
   wire [SLV_WRP_RSP_HDB_WD-1:0]            hd_data;
   wire [SLV_WRP_RSP_HDB_WD-1:0]            hd_data_out;
   wire                                     hd_pop;
   wire                                     hd_pop_n;
   wire                                     hd_push;
   wire                                     hd_push_n;
   wire                                     hd_empty;

   reg                                      s_data_pop_en;
   reg                                      r_data_pop_en;
   wire                                     s_hd_push_en;
   reg                                      r_hd_push_en;

   // -------------------------------------------------------------------------------------
   // Control signals
   wire                                     s_rd_accept;
   wire                                     s_rd_is_wrap;
   reg                                      r_rd_is_wrap;
   wire                                     s_rd_wrap_beat;
   wire                                     s_wr_accept;
   wire                                     s_wr_accept_nobp;
   wire                                     s_wr_is_wrap;
   reg                                      s_rd_wrap_in_progress;
   reg                                      r_rd_wrap_in_progress;
   reg                                      s_wr_wrap_in_progress;
   reg                                      r_wr_wrap_in_progress;
   reg                                      s_rordr_active;
   reg                                      r_rordr_active;
   wire                                     ss_rordr_active;
   wire                                     s_wr_start;
   wire                                     s_wr_last_beat;
   wire                                     s_rd_data_bypass;
   reg                                      r_min_xact;
   wire                                     s_hd_min_full;
   wire                                     s_hd_pop_ready;
   wire                                     s_resp_src_sel;

   wire [3:0]                               s_wr_offset;
   reg  [3:0]                               r_wr_offset;
   wire [SLV_BURST_LEN_PW-1:0]              s_wr_len;
   reg  [SLV_BURST_LEN_PW-1:0]              r_wr_len;

   // -------------------------------------------------------------------------------------
   // Output drivers
   reg                                      s_rready;
   wire                                     s_rvalid;
   reg                                      r_rvalid;
   reg  [SLV_BUS_DATA_WIDTH-1:0]            s_rdata;
   reg                                      r_rlast;
   reg  [RD_NP_RSP_WRAP_INFO_WD-1:0]        r_wprordr_info;
   reg  [SLV_BUS_DATA_WIDTH-1:0]            r_wrporb_sfifo_pop_data;



   assign s_rd_accept = s_rready && axalgn_valid;

   assign s_rd_is_wrap = axalgn_info_wrap_beat_offset > 4'd0;

   assign s_rd_wrap_beat = s_rd_is_wrap && s_rd_accept;

   always @(posedge slv_aclk or negedge slv_aresetn)
   begin : proc_seq_r_rd_is_wrap
      if (!slv_aresetn)
         r_rd_is_wrap <= #TP 1'b0;
      else
         r_rd_is_wrap <= #TP s_rd_is_wrap;
   end

   // WRAP response beat counter
   always @(*)
   begin : proc_comb_rd_wrap_beat_cnt
      if (s_rd_wrap_beat) begin
         if (axalgn_last)
            s_rd_wrap_beat_cnt = 4'd0;
         else
            s_rd_wrap_beat_cnt = r_rd_wrap_beat_cnt + 1;
      end else begin
         s_rd_wrap_beat_cnt = r_rd_wrap_beat_cnt;
      end
   end


   always @(posedge slv_aclk or negedge slv_aresetn)
   begin : proc_seq_rd_wrap_beat_cnt
      if (!slv_aresetn)
         r_rd_wrap_beat_cnt <= #TP 4'd0;
      else
         r_rd_wrap_beat_cnt <= #TP s_rd_wrap_beat_cnt;
   end


   // PUSH State Machine
   //
   // S_RD_SOT
   //   The system is either waiting for a new data beat from the composer or it is processing the
   //   first response data beat. The FSM starts processing data as the first data beat of a wrap
   //   response is received. At this point the FSM will fall into S_RD_BYPASS state if only one beat
   //   needs to be pushed into data fifo. However if the read data ofset is greater than one, the
   //   FSM will jump to S_RD_LOAD state to enable buffering data in the fifo. Also, when there are
   //   outstanding data in the fifo to transmit and a data for a new INCR response is received
   //   this data will also be loaded into the fifo.
   //
   // S_RD_LOAD
   //   Data is being pushed into the fifo. It can happen either when data is received in advance
   //   as a consequence of request address alignment (at this point the FSM will fall in S_RD_BYPASS
   //   after all data beats read in advance are received) or when there are still outstanding data
   //   in the fifo from previous requests that has not been processed yet.
   //
   // S_RD_BYPASS
   //   The received data from the composer is being driven directly into the AXI slave port. This
   //   will only happen for WRAP responses.
   //
   // S_RD_WAIT
   //   Wait cycle introduced to break timing. This happens when an INCR response of minimum length
   //   (1 beat) is received and the system is still popping data from fifo. At this point the
   //   newly data received will be also pushed into data fifo and new header data will be pushed
   //   into header queue as well.
   always @(*)
   begin : proc_comb_rd_fsm
      case (r_rd_wrap_st)
         S_RD_SOT:
         begin
            if (s_rd_wrap_beat) begin
               if (axalgn_info_wrap_beat_offset==4'd1)
                  s_rd_wrap_st = S_RD_BYPASS;
               else
                  s_rd_wrap_st = S_RD_LOAD;
            end else if (s_rd_accept && r_rordr_active) begin
               if (axalgn_last)
                  s_rd_wrap_st = S_RD_WAIT;
               else
                  s_rd_wrap_st = S_RD_LOAD;
            end else
               s_rd_wrap_st = S_RD_SOT;
         end

         S_RD_WAIT:
         begin
            s_rd_wrap_st = S_RD_SOT;
         end

         S_RD_BYPASS:
         begin
            if (s_rd_accept && axalgn_last)
               s_rd_wrap_st = S_RD_SOT;
            else
               s_rd_wrap_st = S_RD_BYPASS;
         end

         S_RD_LOAD:
         begin
            // Only goes to Bypass when there no pipelined data for previous tranfers
            if (s_rd_wrap_beat && (axalgn_info_wrap_beat_offset==(r_rd_wrap_beat_cnt+1)))
               s_rd_wrap_st = S_RD_BYPASS;
            else if (s_rd_accept && axalgn_last)
               s_rd_wrap_st = S_RD_SOT;
            else
               s_rd_wrap_st = S_RD_LOAD;
         end

         default:
         begin
            s_rd_wrap_st = S_RD_SOT;
         end
      endcase
   end

   always @(posedge slv_aclk or negedge slv_aresetn)
   begin : proc_seq_rd_fsm
      if (!slv_aresetn)
         r_rd_wrap_st <= #TP S_RD_SOT;
      else
         r_rd_wrap_st <= #TP s_rd_wrap_st;
   end


   // Push transaction context to the header fifo as a new response arrives in from axalgn interface
   assign hd_push = (r_rd_wrap_st==S_RD_SOT) && (s_rd_wrap_st!=S_RD_SOT);

   assign hd_push_n  = ~hd_push;

   // Data is pushed into the fifo when a valid beat arrives in from axalgn interface and the push
   // fsm is in S_RD_LOAD mode OR it is the first beat of a wrap response (at least one beat offset)
   // OR even if the current data beat is the first beat of an INCR response but pop fsm is still
   // driving data from older responses
   assign data_push = s_rd_accept && (
                        (r_rd_wrap_st==S_RD_LOAD) ||
                        ((r_rd_wrap_st==S_RD_SOT) && ((s_rd_wrap_st!=S_RD_SOT) || (r_outstanding_cnt>0)))
                      );

   assign data_push_n  = ~data_push;


   // Signal when a wrap data is being processed
   always @(*)
   begin : proc_comb_rd_wrap_in_progress
      s_rd_wrap_in_progress = r_rd_wrap_in_progress;
      if (s_rd_wrap_beat) begin
         if (axalgn_last)
            s_rd_wrap_in_progress = 1'b0;
         else
            s_rd_wrap_in_progress = 1'b1;
      end
   end

   always @(posedge slv_aclk or negedge slv_aresetn)
   begin : proc_seq_rd_wrap_in_progress
      if (!slv_aresetn)
         r_rd_wrap_in_progress <= #TP 1'b0;
      else
         r_rd_wrap_in_progress <= #TP s_rd_wrap_in_progress;
   end


   // POP State Machine
   //
   // S_WR_IDLE
   //   The system is not driving any data to axi slave interface. It jumps to S_WR_OFFLOAD state
   //   when either there are at least one complete transaction buffered in the fifo ready to
   //   transmit transations in is just one transaction first wrap
   //
   // S_WR_OFFLOAD
   //   Data is being driven into axi bus. The state machine will jump back to S_WR_IDLE when
   //   either the last beat of the current transfer is driven and there is no more data pending
   //   to transmit OR the header fifo gets empty after last data beat is accepted.
   always @(*)
   begin : proc_comb_wr_fsm

      case (r_wr_wrap_st)
         S_WR_IDLE:
         begin
            if (r_outstanding_cnt>1)
               s_wr_wrap_st = S_WR_OFFLOAD;
            else if ((r_outstanding_cnt==1) && (!s_rd_wrap_in_progress))
               s_wr_wrap_st = S_WR_OFFLOAD;
            else
               s_wr_wrap_st = S_WR_IDLE;
         end

         S_WR_OFFLOAD:
         begin
            if ((s_outstanding_cnt==0) && s_wr_accept_nobp)
               s_wr_wrap_st = S_WR_IDLE;
            else if ((r_wr_beat_cnt==0) && hd_empty && s_wr_accept_nobp)
               s_wr_wrap_st = S_WR_IDLE;
            else
               s_wr_wrap_st = S_WR_OFFLOAD;
         end

         default:
         begin
            s_wr_wrap_st = S_WR_IDLE;
         end
      endcase
   end


   always @(posedge slv_aclk or negedge slv_aresetn)
   begin : proc_seq_wr_fsm
      if (!slv_aresetn)
         r_wr_wrap_st <= #TP S_WR_IDLE;
      else
         r_wr_wrap_st <= #TP s_wr_wrap_st;
   end


   // Pop fsm will start operating
   assign s_wr_start = (r_wr_wrap_st==S_WR_IDLE) && (s_wr_wrap_st==S_WR_OFFLOAD);


   // Fifo pop enable signal. Pop requests should be disabled when either the pop fsm is idle or
   // when it is bypassing data from axalgn interface directly to axi slave port.
   always @(*)
   begin : proc_comb_data_pop_en

      s_data_pop_en = r_data_pop_en;

      if (wrporb_sfifo_e) begin
         s_data_pop_en = 1'b0;
      end else if (s_wr_start) begin
         s_data_pop_en = 1'b1;
      end else if (s_wr_wrap_st==S_WR_IDLE) begin
            s_data_pop_en = 1'b0;
      end else if (s_wr_wrap_in_progress) begin
         if (({{8-SLV_BURST_LEN_PW{1'b0}}, s_wr_len}-{{8-SLV_BURST_LEN_PW{1'b0}}, s_wr_beat_cnt}) > ({{8-SLV_BURST_LEN_PW{1'b0}}, s_wr_len}-{{4{1'b0}}, s_wr_offset}))
            s_data_pop_en = 1'b1;
         else
            s_data_pop_en = 1'b0;
      end else if (s_wr_wrap_st==S_WR_OFFLOAD) begin
         s_data_pop_en = 1'b1;
      end

   end

   always @(posedge slv_aclk or negedge slv_aresetn)
   begin : proc_seq_data_pop_en
      if (!slv_aresetn)
         r_data_pop_en <= #TP 1'b0;
      else
         r_data_pop_en <= #TP s_data_pop_en;
   end


   // Data pop signal. When pop requests are enabled, the request will only occur as the first data
   // beat becomes available to read, that is, the pop fsm leaves from idle state OR the current
   // data on the bus is accepted by the axi master. Since data becomes avialable 1 cycle after the
   // request, one need to assert pop signal in advance.
   always @(*)
   begin : proc_comb_data_pop
      data_pop = 1'b0;
      if (!s_data_pop_en)
         data_pop = 1'b0;
      else if (!s_rvalid || s_wr_accept || s_wr_start)
         data_pop = 1'b1;
   end


   // Header pop control. Transaction context is initially fetched from header fifo when the pop
   // fsm leaves from idle state. The following requests occur anytime the last beat is set to axi
   // salve port and there are more transaction on the queue.
   assign s_hd_pop_ready = s_wr_accept_nobp && (s_wr_wrap_st==S_WR_OFFLOAD) && (r_wr_beat_cnt==0);

   assign hd_pop = s_wr_start || s_hd_pop_ready;

   assign hd_pop_n = ~hd_pop;


   // Fetch the beat offset of the transfer being driven to AMBA bus.
   assign s_wr_offset = (hd_pop) ? hd_data_out[SLV_BURST_LEN_PW +: 4] : r_wr_offset;

   always @(posedge slv_aclk or negedge slv_aresetn)
   begin : proc_seq_pop_wr_offset
      if (!slv_aresetn)
         r_wr_offset <= #TP 4'd0;
      else begin
         r_wr_offset <= #TP s_wr_offset;
      end
   end


   // Fetch the length of the transfer being driven to AMBA bus.
   assign s_wr_len = (hd_pop) ? hd_data_out[0 +: SLV_BURST_LEN_PW] : r_wr_len;

   always @(posedge slv_aclk or negedge slv_aresetn)
   begin : proc_seq_pop_wr_len
      if (!slv_aresetn)
         r_wr_len <= #TP {SLV_BURST_LEN_PW{1'b0}};
      else begin
         r_wr_len <= #TP s_wr_len;
      end
   end


   // Beat counter of the AXI response. The counter is initialized when the transaction header
   // context is fetched from the header fifo and updated anytime the beat is accepted on the amba
   // bus. The initial value of the counter may vary depending on wether the transfer is of wrap
   // type or not. If it is a wrap, then some data beats will be bypassed from axalgn interface
   // to axi slave port so the initial counter value needs to discount the number of beats read
   // in advance. Otherwise, for incr responses, the counter will be loaded with the transfer
   // length value.
   always @(*)
   begin : proc_comb_wr_beat_cnt
      s_wr_beat_cnt = r_wr_beat_cnt;
      if (hd_pop) begin
         if (r_rd_is_wrap && s_wr_start)
            s_wr_beat_cnt = axalgn_info_wrap_beat_offset - 1;
         else
            s_wr_beat_cnt = s_wr_len;
      end else if ((s_wr_wrap_st==S_WR_OFFLOAD) && s_wr_accept)
         s_wr_beat_cnt = r_wr_beat_cnt - 1 ;

   end

   always @(posedge slv_aclk or negedge slv_aresetn)
   begin : proc_seq_wr_beat_cnt
      if (!slv_aresetn)
         r_wr_beat_cnt <= #TP {SLV_BURST_LEN_PW{1'b0}};
      else
         r_wr_beat_cnt <= #TP s_wr_beat_cnt;
   end


   // Header push enable. Since the header fifo may support less transactions than the worst case
   // scenario one need to prevent new transfers from being loaded into the queues.  Worst case
   // scenario happens when a wrap response with maximum offset arrives in (16 beat in which 15 are
   // received in advance) immediately followed by several incr responses with minimum length
   // (1 beat). In this case, while the pop fsm is popping data to complete the wrap response, the
   // header fifo gets loaded with context data of subsequent incr transactions. If header fifo
   // becomes full the header push enable deasserts right after the last data beat is loaded.
   always @(posedge slv_aclk or negedge slv_aresetn)
   begin : proc_seq_hd_push_en
      if (!slv_aresetn)
         r_hd_push_en <= #TP 1'b1;
      else begin
         if (wrporhb_full && s_rd_accept && axalgn_last)
            r_hd_push_en <= #TP 1'b0;
         else
            r_hd_push_en <= #TP s_hd_push_en;
      end
   end

   // Detect incr transaction with minimum length (1 beat)
   always @(posedge slv_aclk or negedge slv_aresetn)
   begin : proc_seq_min_xact
      if (!slv_aresetn)
         r_min_xact <= #TP 1'b0;
      else begin
         if (s_rd_accept && (axalgn_info_len==0))
            r_min_xact <= #TP 1'b1;
         else
            r_min_xact <= #TP 1'b0;
      end
   end

   // Signal header fifo full caused by a response to a minimum length transaction
   assign s_hd_min_full = wrporhb_full && r_min_xact;

   // Disable push requests when the header fifo gets full and the current transaction has already
   // been pushed (r_hd_push_en is low). When the current transaction being pushed is of minimum
   // length (1 beat) the fifo full flag will only assert one cycle later and push request should
   // also be blocked. When header fifo becomes with available space again the enable signal
   // asserts to allow more push requests.
   assign s_hd_push_en = (r_hd_push_en || (!wrporhb_full)) && (!s_hd_min_full);


   // Data is being bypassed from axalgn interface directly to the axi slave port
   assign s_rd_data_bypass = r_rd_wrap_st==S_RD_BYPASS;


   // Ready signal to control the data throughoutput from axalgn inteface
   always @(*)
   begin : proc_comb_rready

      if (r_rd_wrap_st==S_RD_WAIT) begin
         s_rready = 1'b0;
      end else if (r_wr_wrap_st==S_WR_IDLE) begin
         s_rready = pdly1_rready;
      // When in S_RD_BYPASS mode one can be generating traffic for outstansing tranfers (ready
      // shall deassert) or simply bypassing data from the axalgn interface to the axi slave port
      end else if (s_rd_data_bypass) begin
         if (r_wr_wrap_in_progress && (r_outstanding_cnt==1))
            s_rready = pdly1_rready;
         else
            s_rready = 1'b0;
      end else if (r_rordr_active) begin
         if (!wrporb_sfifo_f && s_hd_push_en)
            s_rready = 1'b1;
         else
            s_rready = 1'b0;
      end else begin
         s_rready = pdly1_rready;
      end
   end

   assign wprordr_ready  = s_rready;


   // Signal when either push fsm or pop fsm are busy
   always @(*)
   begin : proc_comb_rord_active
      s_rordr_active = r_rordr_active;
      if ((r_rd_wrap_st==S_RD_SOT) && (s_rd_wrap_st!=S_RD_SOT))
         s_rordr_active = 1'b1;
      else if ((r_wr_wrap_st==S_WR_OFFLOAD) && (s_wr_wrap_st==S_WR_IDLE))
         s_rordr_active = 1'b0;
   end

   always @(posedge slv_aclk or negedge slv_aresetn)
   begin : proc_seq_rord_active
      if (!slv_aresetn)
         r_rordr_active <= 1'b0;
      else
         r_rordr_active <= s_rordr_active;
   end

   assign ss_rordr_active = s_rordr_active || r_rordr_active;


   // Input source selector. Signal when data and valid signals shall be generated by the wrap
   // block or signals from axalgn shall be used instead, which happenas dugring bypass and idle.
   assign s_resp_src_sel  = ss_rordr_active && ((!s_rd_data_bypass) || (r_outstanding_cnt>1));


   // Valid signal asserts after data is popped from fifo and deasserts when when it is been
   // accepted on slave port and no other beat ready to transmist (othewise the previous condition
   // would be satisfied)
   always @(posedge slv_aclk or negedge slv_aresetn)
   begin : proc_seq_valid
      if (!slv_aresetn)
         r_rvalid <= #TP 1'b0;
      else begin
         if (data_pop) begin
            r_rvalid <= #TP 1'b1;
         end else if (s_wr_accept_nobp) begin
            r_rvalid <= #TP 1'b0;
         end
      end
   end

   assign s_rvalid = (s_resp_src_sel) ? r_rvalid : axalgn_valid;

   assign s_wr_accept = pdly1_rready && s_rvalid;

   // write accept signal when fsm is not bypassing data from axalgn interface. This signal uses
   // registered rvalid to prevent assynchronous feedback loops
   assign s_wr_accept_nobp = pdly1_rready && r_rvalid;

   assign wprordr_rvalid = s_rvalid;


   always @(*)
   begin : proc_comb_rdata
      s_rdata = axalgn_data;
      if (s_resp_src_sel) begin
         s_rdata = r_wrporb_sfifo_pop_data;
      end
   end

   assign wprordr_rdata  = s_rdata;


   // wprordr_rlast asserts when the last data beat is drinven into the output
   // and remains asserted until it has been acepted by the slave
   always @(posedge slv_aclk or negedge slv_aresetn)
   begin : proc_seq_rlast
      if (!slv_aresetn)
         r_rlast <= #TP 1'b0;
      else
      begin
         if ((s_wr_wrap_st==S_WR_OFFLOAD) && (s_wr_beat_cnt==0))
            r_rlast <= #TP 1'b1;
         else if (s_wr_accept)
            r_rlast <= #TP 1'b0;
      end
   end

   assign wprordr_rlast = (ss_rordr_active) ? r_rlast : axalgn_last;


   // Drive info bus aligned with data
   always @(posedge slv_aclk or negedge slv_aresetn)
   begin : proc_seq_wprordr_info
      if (!slv_aresetn)
         r_wprordr_info <= #TP {RD_NP_RSP_WRAP_INFO_WD{1'b0}};
      else
      begin
         if ((r_wr_wrap_st==S_WR_OFFLOAD) || (s_wr_wrap_st==S_WR_OFFLOAD)) begin
            if (hd_pop) begin
               r_wprordr_info <= #TP hd_data_out[SLV_WRP_RSP_HDB_WD-1 -: RD_NP_RSP_WRAP_INFO_WD];
            end
         end else begin
            r_wprordr_info <= #TP axalgn_info;
         end
      end
   end

   assign wprordr_info = (r_wr_wrap_st==S_WR_OFFLOAD) ? r_wprordr_info : axalgn_info;


   // Signal last data beat acceptance
   assign s_wr_last_beat = (r_wr_wrap_st==S_WR_OFFLOAD) && s_wr_accept_nobp && (r_wr_beat_cnt==0);


   // Counts the number of outstanding transfers not completely trasmited yet. The counter is
   // incremented when a new transfer is received from axalgn interface and decermented when the
   // last data beat for the transfer is accepted on the amba bus by the master.
   always @(*)
   begin : proc_comb_outstanding_cnt
      s_outstanding_cnt = r_outstanding_cnt;
      if (hd_push && ((!s_wr_last_beat) || (r_outstanding_cnt==0)))
         s_outstanding_cnt = r_outstanding_cnt + 1;
      else if ((!hd_push) && (s_wr_last_beat))
         s_outstanding_cnt = r_outstanding_cnt - 1;
   end


   always @(posedge slv_aclk or negedge slv_aresetn)
   begin : proc_seq_outstanding_cnt
      if (!slv_aresetn)
         r_outstanding_cnt <= #TP {SLV_WRP_RSP_NUM_OUTSTD_WD{1'b0}};
      else
         r_outstanding_cnt <= #TP s_outstanding_cnt;
   end

   // Signal when a wrap response is being processed
   assign s_wr_is_wrap = s_wr_offset > 4'd0;

   // Signal when a wrap response is being driven into axi interface
   always @(*)
   begin : proc_comb_wr_wrap_in_progress
      s_wr_wrap_in_progress = r_wr_wrap_in_progress;
      if (hd_pop && s_wr_is_wrap)
         s_wr_wrap_in_progress = 1'b1;
      else if (wprordr_rlast)
         s_wr_wrap_in_progress = 1'b0;
   end

   always @(posedge slv_aclk or negedge slv_aresetn)
   begin : proc_seq_wr_wrap_in_progress
      if (!slv_aresetn)
         r_wr_wrap_in_progress <= #TP 1'b0;
      else
         r_wr_wrap_in_progress <= #TP s_wr_wrap_in_progress;
   end




   DWC_pcie_ctl_bcm64_td
   
   #(.WIDTH                            (SLV_BUS_DATA_WIDTH)
   ,.DEPTH                             (SLV_WRP_RSP_ROB_FIFO_DP)
   ,.ERR_MODE                          (0)
   ,.RST_MODE                          (0)
   ,.ADDR_WIDTH                        (SLV_WRP_RSP_ROB_FIFO_ADDR_WD)
   ,.REG_DELAY_TIME                    (REG_DELAY_TIME)
   ,.REG_DELAY_DENOM                   (REG_DELAY_DENOM)
   )
   u_wrporb
   (.clk                               (slv_aclk)
   ,.rst_n                             (slv_aresetn)
   ,.init_n                            (1'b1)
   ,.push_req_n                        (data_push_n)
   ,.pop_req_n                         (!data_pop)
   ,.diag_n                            (1'b1)
   ,.ae_level                          ({SLV_WRP_RSP_ROB_FIFO_ADDR_WD{1'b1}})
   ,.af_thresh                         ({SLV_WRP_RSP_ROB_FIFO_ADDR_WD{1'b0}})
   ,.data_in                           (axalgn_data)
   ,.empty                             (wrporb_sfifo_e)
   ,.almost_empty                      ()
   ,.full                              (wrporb_sfifo_f)
   ,.half_full                         ()
   ,.almost_full                       ()
   ,.error                             ()
   ,.data_out                          (wrporb_sfifo_pop_data)
   );

   reg   r_data_pop; 
   always @(posedge slv_aclk or negedge slv_aresetn) begin :proc_seq_rpop_req
      if (!slv_aresetn)
         r_data_pop <= #TP 1'b0;
      else
         r_data_pop <= #TP ~data_pop;
   end

   always @(posedge slv_aclk or negedge slv_aresetn) begin :proc_seq_r_sfifo_pop_data
      if (!slv_aresetn)
         r_wrporb_sfifo_pop_data <= {SLV_BUS_DATA_WIDTH{1'b0}};
      else begin
        if (data_pop)
          r_wrporb_sfifo_pop_data <= wrporb_sfifo_pop_data;
      end
   end

   assign hd_data = {axalgn_info,axalgn_info_wrap_beat_offset,axalgn_info_len};

   DWC_pcie_ctl_bcm64_td
   
   #(.WIDTH                            (SLV_WRP_RSP_HDB_WD)
   ,.DEPTH                             (SLV_WRP_RSP_HDB_DP)
   ,.ERR_MODE                          (0)
   ,.RST_MODE                          (0)
   ,.ADDR_WIDTH                        (SLV_WRP_RSP_HDB_ADDR_WD)
   ,.REG_DELAY_TIME                    (REG_DELAY_TIME)
   ,.REG_DELAY_DENOM                   (REG_DELAY_DENOM)
   )
   u_wrporhb
   (.clk                               (slv_aclk)
   ,.rst_n                             (slv_aresetn)
   ,.init_n                            (1'b1)
   ,.push_req_n                        (hd_push_n)
   ,.pop_req_n                         (hd_pop_n)
   ,.diag_n                            (1'b1)
   ,.ae_level                          ({SLV_WRP_RSP_HDB_ADDR_WD{1'b1}})
   ,.af_thresh                         ({SLV_WRP_RSP_HDB_ADDR_WD{1'b0}})
   ,.data_in                           (hd_data)
   ,.empty                             (hd_empty)
   ,.almost_empty                      ()
   ,.full                              (wrporhb_full)
   ,.half_full                         ()
   ,.almost_full                       ()
   ,.error                             ()
   ,.data_out                          (hd_data_out)
   );


endmodule
