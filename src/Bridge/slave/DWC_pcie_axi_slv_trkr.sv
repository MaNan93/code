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

//-------------------------------------------------------------------------
//---  RCS information:
//---    $DateTime: 2021/10/29 02:04:56 $
//---    $Revision: #6 $
//---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/slave/DWC_pcie_axi_slv_trkr.sv#6 $
//-------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"


 module DWC_pcie_axi_slv_trkr
 #(
   parameter SLV_NUM_OUTSTND_WR_REQ           = 32,
   parameter SLV_NUM_OUTSTND_WR_REQ_LOG2      = 5,
   parameter MAX_SLV_TAG_PW                   = 5,
   parameter TP                               = `TP
  )
  (
  // Clocks and resets
  input                                    slv_aclk,
  input                                    slv_aclk_ug,
  input                                    slv_aresetn,
  // Flush control interface
  input                                    flshctl_sif_flush_req,
  output wire                              strkr_flush_ack,
  // AXI Write address channel
  input                                    slv_awvalid,
  input [5:0]                              slv_awatop,
  output wire                              strkr_awready,
  // Tracker write address channel
  output wire                              strkr_awvalid,
  input                                    swrq_awready,
  // AXI Write data channel
  input                                    slv_wvalid,
  input                                    slv_wlast,
  output wire                              slv_wready,
  // Tracker write data channel
  output wire                              strkr_wvalid,
  output wire                              strkr_wlast,
  input                                    swrq_wready,
  // AXI Write response interface
  input                                    slv_bvalid,
  input                                    slv_bready,
  // AXI Read request interface
  input                                    slv_arvalid,
  input                                    slv_arready,
  // AXI Read response interface
  input                                    slv_rvalid,
  input                                    slv_rlast,
  input                                    slv_rready,
  // AXI shared DBI access notification (AR & AW)
  input                                    slv_ar_db,
  input                                    slv_aw_db,
 // dbi response valid (wr)
  input                                    dbi_wr_rsp,
  // dbi response valid (rd)
  input                                    dbi_rd_rsp,
  // Slave dbi transaction pending
  output wire                              strkr_xfer_pending_db,

  // Power Management Interface (Powr Down)
  // Slave non- dbi transaction pending
  output wire                              strkr_xfer_pending

  );
  // -------------------------------------------------------------------------------------
  // Local parameter
  // -------------------------------------------------------------------------------------
  // Write Data Channel FSM
  localparam S_WR_IDLE       = 1'b0;
  localparam S_WR_MULTI_BEAT = 1'b1;

  // To avoid the counter overflowing we need to consider the requests in the AR Ch pipeline
  // stage and the recycling of the AXI tag before the response is sent on the Slave.
  // Considering the worse case where MAX_SLV_TAG=2 the counter can increment to 4.
  // To be safe the counter width is set to 3 bits.
  // Also, when wrap re-ordering buffer is on the path the transfers may be pipelined in
  // the fifo (up to CC_SLV_WRP_RSP_ROB_FIFO_DP). Thus, the counter width should increment
  // to accommodate this.
  localparam NP_PENDING_CNTR_WIDTH = MAX_SLV_TAG_PW
                                     + `CC_SLV_WRP_RSP_ROB_FIFO_ADDR_WD - 2
                                     + 2;

  // -------------------------------------------------------------------------------------
  // Wire/Reg
  // -------------------------------------------------------------------------------------
  wire                                     s_rsp_hl;
  wire                                     s_w_rsp_hl;
  wire                                     s_aw_req_hl;
  reg  [SLV_NUM_OUTSTND_WR_REQ_LOG2:0]     r_aw_rsp_pending_cnt;
  wire                                     s_aw_req_stall;

  reg                                      s_wr_fsm;
  reg                                      r_wr_fsm;
  reg                                      s_w_req_hl;
  reg  [SLV_NUM_OUTSTND_WR_REQ_LOG2:0]     r_w_rsp_pending_cnt;
  reg                                      s_w_beat_in_pipeline;
  reg                                      s_no_ar_aw_pending;
  wire                                     s_wr_xfer_pending;
  wire                                     s_rsp_hl_db;
  wire                                     s_aw_req_hl_db;
  reg  [SLV_NUM_OUTSTND_WR_REQ_LOG2:0]     r_aw_rsp_pending_cnt_db;
  wire                                     s_wr_xfer_pending_db;
  wire                                     s_flush_wr_ch_xfer_done;
  reg                                      r_flush_wr_ch_xfer_done;
  reg                                      rr_flush_wr_ch_xfer_done;
  wire                                     s_flush_stop_wr_ch;
  reg                                      r_flush_ack;

  wire                                     s_r_rsp_hl;
  wire                                     s_r_req_hl;
  reg  [NP_PENDING_CNTR_WIDTH-1:0]         r_rd_rsp_pending_cnt;
  wire                                     s_rd_xfer_pending;
  wire                                     s_r_rsp_hl_db;
  wire                                     s_r_req_hl_db;
  reg  [NP_PENDING_CNTR_WIDTH-1:0]         r_rd_rsp_pending_cnt_db;
  wire                                     s_rd_xfer_pending_db;

  reg                                      r_xfer_pending;
  reg                                      r_xfer_pending_db;
  wire                                     s_aw_req_atomic;
  // -------------------------------------------------------------------------------------
  // Design
  // -------------------------------------------------------------------------------------
  // -------------------------------------------------------------------------------------
  // AW Channel tracker (DBI txns not tracked)
  // -------------------------------------------------------------------------------------
  assign s_rsp_hl    = (dbi_wr_rsp)? 1'b0 : slv_bvalid & slv_bready;
  assign s_aw_req_hl = slv_aw_db ? 1'b0 : slv_awvalid & strkr_awready; // dbi requests are not considered pending
  always @(posedge slv_aclk or negedge slv_aresetn) begin : proc_seq_trkr_aw_ch
    if (!slv_aresetn) begin
      r_aw_rsp_pending_cnt <= # TP {SLV_NUM_OUTSTND_WR_REQ_LOG2+1{1'b0}};
    end else begin
      case({s_rsp_hl,s_aw_req_hl})
        2'b01        : r_aw_rsp_pending_cnt <= # TP r_aw_rsp_pending_cnt + 1;
        2'b10        : r_aw_rsp_pending_cnt <= # TP r_aw_rsp_pending_cnt - 1;
        2'b00, 2'b11 : r_aw_rsp_pending_cnt <= # TP r_aw_rsp_pending_cnt;
      endcase
    end
  end


  // -------------------------------------------------------------------------------------
  // AW Channel tracker (Only DBI)
  // -------------------------------------------------------------------------------------
  assign s_rsp_hl_db    = (dbi_wr_rsp) ? slv_bvalid & slv_bready : 1'b0;
  assign s_aw_req_hl_db = slv_aw_db ?  slv_awvalid & strkr_awready : 1'b0 ;

  always @(posedge slv_aclk or negedge slv_aresetn) begin : proc_seq_trkr_aw_ch_db
    if (!slv_aresetn) begin
      r_aw_rsp_pending_cnt_db <= # TP {SLV_NUM_OUTSTND_WR_REQ_LOG2+1{1'b0}};
    end else begin
      case({s_rsp_hl_db,s_aw_req_hl_db})
        2'b01        : r_aw_rsp_pending_cnt_db <= # TP r_aw_rsp_pending_cnt_db + 1;
        2'b10        : r_aw_rsp_pending_cnt_db <= # TP r_aw_rsp_pending_cnt_db - 1;
        2'b00, 2'b11 : r_aw_rsp_pending_cnt_db <= # TP r_aw_rsp_pending_cnt_db;
      endcase
    end
  end

  assign s_wr_xfer_pending_db = s_aw_req_hl_db || (|r_aw_rsp_pending_cnt_db) ;


 // -------------------------------------------------------------------------------------
  // W Channel tracker (Common for both DBI and non-DBI)
  // -------------------------------------------------------------------------------------
  // Write FSM: Detect first valid data beat
  always @(*) begin : proc_comb_wr_fsm
    // Initialise
    s_wr_fsm   = r_wr_fsm;
    s_w_req_hl = 1'b0;

    if (slv_wready) begin
      case (r_wr_fsm)
        S_WR_IDLE : begin
          s_w_req_hl = slv_wvalid;
          if (slv_wvalid && !slv_wlast) begin
            s_wr_fsm = S_WR_MULTI_BEAT;
          end
        end
        S_WR_MULTI_BEAT : begin
          s_w_req_hl = 1'b0;
          if (slv_wvalid && slv_wlast) begin
            s_wr_fsm = S_WR_IDLE;
          end
        end
      endcase
    end
  end

  always @(posedge slv_aclk or negedge slv_aresetn) begin : proc_seq_wr_fsm
    if (!slv_aresetn) begin
     r_wr_fsm <= # TP S_WR_IDLE;
    end else if (slv_wready) begin
     r_wr_fsm <= # TP s_wr_fsm;
    end
  end

  always @(posedge slv_aclk or negedge slv_aresetn) begin : proc_seq_trkr_w_ch
    if (!slv_aresetn) begin
      r_w_rsp_pending_cnt <= # TP {SLV_NUM_OUTSTND_WR_REQ_LOG2+1{1'b0}};
    end else begin
      case({s_w_rsp_hl,s_w_req_hl})
        2'b01        : r_w_rsp_pending_cnt <= # TP r_w_rsp_pending_cnt + 1;
        2'b10        : r_w_rsp_pending_cnt <= # TP r_w_rsp_pending_cnt - 1;
        2'b00, 2'b11 : r_w_rsp_pending_cnt <= # TP r_w_rsp_pending_cnt;
      endcase
    end
  end
  // This means that there are write transactions that havent been completed
  // s_w_beat_in_pipeline && s_no_ar_aw_pending means there is a data beat in W accepted and is in pipeline, while
  // the relevant control info has not been received on AW yet
  assign s_w_beat_in_pipeline = (s_w_req_hl || (|r_w_rsp_pending_cnt));

  assign s_no_ar_aw_pending = !s_wr_xfer_pending && !s_wr_xfer_pending_db && !s_rd_xfer_pending && !s_rd_xfer_pending_db;
  assign s_w_rsp_hl         = s_rsp_hl || s_rsp_hl_db;

  assign s_wr_xfer_pending = s_aw_req_hl || |r_aw_rsp_pending_cnt ;

  // Flush control
  // The flush request signal, flshctl_sif_flush_req, is asserted async to the write
  // channel and is used in conjunction with the write channel pending status signal,
  // s_wr_xfer_pending, to de-assert the ready signals at the write address/data
  // channel interfaces.
  // To avoid a combinational path from the AXI Slave Valid signals to their correponding
  // Ready signals and to account for the one cycle of uncertainty between the flush
  // request and the pending status signal, s_flush_wr_ch_xfer_done, is registered and filtered.
  // before gating the ready signals.

  assign s_flush_wr_ch_xfer_done = flshctl_sif_flush_req && !s_wr_xfer_pending && !s_wr_xfer_pending_db && !s_w_beat_in_pipeline;

  always @(posedge slv_aclk_ug or negedge slv_aresetn) begin : proc_seq_wr_ch_xfer_done
    if (!slv_aresetn) begin
      r_flush_wr_ch_xfer_done  <= # TP 1'b1;
      rr_flush_wr_ch_xfer_done <= # TP 1'b1;
    end else begin
      if (s_flush_wr_ch_xfer_done) begin
        r_flush_wr_ch_xfer_done  <= # TP 1'b1;
        rr_flush_wr_ch_xfer_done <= # TP r_flush_wr_ch_xfer_done;
      end else begin
        r_flush_wr_ch_xfer_done  <= # TP 1'b0;
        rr_flush_wr_ch_xfer_done <= # TP 1'b0;
      end
    end
  end

  // Stall address/data channels, mask internal awvalid
  // Stop accepting requests if max number of outstanding writes is reached or
  // flush request asserted & all pending transfers done and no accepted data in pipeline
  // power down request succeeds, meaning no transfers pending and no accepted data in pipeline
  assign s_flush_stop_wr_ch = r_flush_wr_ch_xfer_done && rr_flush_wr_ch_xfer_done;
  assign s_aw_req_stall = ((r_aw_rsp_pending_cnt + r_aw_rsp_pending_cnt_db)==SLV_NUM_OUTSTND_WR_REQ)
                          || s_flush_stop_wr_ch;

  assign strkr_awready = s_aw_req_stall ? 1'b0 : swrq_awready;
  assign strkr_awvalid = s_aw_req_stall ? 1'b0 : slv_awvalid;

  assign s_w_req_stall = s_flush_stop_wr_ch;
  assign strkr_wvalid = s_w_req_stall ? 1'b0 : slv_wvalid;
  assign strkr_wlast  = s_w_req_stall ? 1'b0 : slv_wlast;
  assign slv_wready   = s_w_req_stall ? 1'b0 : swrq_wready;

  // -------------------------------------------------------------------------------------
  // R Channel tracker  - (does not track DBI transactions)
  // -------------------------------------------------------------------------------------
  assign s_r_rsp_hl = (dbi_rd_rsp) ? 1'b0 : slv_rvalid && slv_rlast && slv_rready;
  assign s_r_req_hl = slv_ar_db ? 1'b0 : slv_arvalid && slv_arready; // dbi requests not considered pending
  // AXI Atomic operations also has a response on R-Channel
  assign s_aw_req_atomic = slv_awvalid && strkr_awready && ((slv_awatop == `AXI_ATOP_LOAD_LE) || (slv_awatop == `AXI_ATOP_LOAD_BE) || (slv_awatop == `AXI_ATOP_SWAP) || (slv_awatop == `AXI_ATOP_CAS));
  always @(posedge slv_aclk or negedge slv_aresetn) begin : proc_seq_trkr_r_ch
    if (!slv_aresetn) begin
      r_rd_rsp_pending_cnt <= # TP {NP_PENDING_CNTR_WIDTH{1'b0}};
    end else begin
      case({s_r_req_hl,s_aw_req_atomic, s_r_rsp_hl})
        3'b100, 3'b111, 3'b010 : r_rd_rsp_pending_cnt <= # TP r_rd_rsp_pending_cnt + 1;
        3'b110                 : r_rd_rsp_pending_cnt <= # TP r_rd_rsp_pending_cnt + 2;
        3'b001                 : r_rd_rsp_pending_cnt <= # TP r_rd_rsp_pending_cnt - 1;
        3'b000,3'b101, 3'b011  : r_rd_rsp_pending_cnt <= # TP r_rd_rsp_pending_cnt;
      endcase
    end
  end

  assign s_rd_xfer_pending = s_r_req_hl || |r_rd_rsp_pending_cnt;

 
  // -------------------------------------------------------------------------------------
  // R Channel tracker  - (only DBI transactions)
  // -------------------------------------------------------------------------------------

  assign s_r_rsp_hl_db = (dbi_rd_rsp) ?  slv_rvalid && slv_rlast && slv_rready : 1'b0;
  assign s_r_req_hl_db = slv_ar_db ?  slv_arvalid && slv_arready : 1'b0;

  always @(posedge slv_aclk or negedge slv_aresetn) begin : proc_seq_trkr_r_ch_db
    if (!slv_aresetn) begin
      r_rd_rsp_pending_cnt_db <= # TP {NP_PENDING_CNTR_WIDTH{1'b0}};
    end else begin
      if (s_r_req_hl_db && !s_r_rsp_hl_db) begin
        r_rd_rsp_pending_cnt_db <= # TP r_rd_rsp_pending_cnt_db + 1;
      end else if (!s_r_req_hl_db && s_r_rsp_hl_db) begin
        r_rd_rsp_pending_cnt_db <= # TP r_rd_rsp_pending_cnt_db - 1;
      end
    end
  end

  assign s_rd_xfer_pending_db = s_r_req_hl_db || |r_rd_rsp_pending_cnt_db;


  // -------------------------------------------------------------------------------------
  // AXI Slave DBI Read/Write Pending
  // -------------------------------------------------------------------------------------
  // The signal is used to prevent Power gating and to bring back the Power (L1.2 to L1.1)
  // asserted when dbi transfers pending
  // asserted when data in Wchannel accepted before AW and no other slave transfers pending untill relevant AW is asserted to prevent flush /powerdown
  // Register pending signal before synchronising to aux_clk.
  always @(posedge slv_aclk or negedge slv_aresetn) begin : proc_seq_xfer_pending_db
    if (!slv_aresetn) begin
      r_xfer_pending_db <= # TP 1'b0;
    end else begin
      r_xfer_pending_db <= # TP s_wr_xfer_pending_db || s_rd_xfer_pending_db ||(s_w_beat_in_pipeline && s_no_ar_aw_pending);
    end
  end

  assign strkr_xfer_pending_db = r_xfer_pending_db;
  // -------------------------------------------------------------------------------------
  // AXI Slave Read/Write Pending (excluding DBI)
  // -------------------------------------------------------------------------------------
  // The signal is used to control gating of the core clock.
  // The slave clock is always present.
  // Register pending signal before synchronising to aux_clk.
  always @(posedge slv_aclk or negedge slv_aresetn) begin : proc_seq_xfer_pending
    if (!slv_aresetn) begin
      r_xfer_pending <= # TP 1'b0;
    end else begin
      r_xfer_pending <= # TP s_wr_xfer_pending || s_rd_xfer_pending;
    end
  end

  assign strkr_xfer_pending = r_xfer_pending;

  // -------------------------------------------------------------------------------------
  // AXI Slave Read/Write Flush Ack
  // -------------------------------------------------------------------------------------
  // Register the ack before synchronising to the core clock. Clocked with ungated slave clock. This is to give flush ack when slave is idle
  always @(posedge slv_aclk_ug or negedge slv_aresetn) begin : proc_seq_flush_ack
    if (!slv_aresetn) begin
      r_flush_ack <= # TP 1'b0;
    end else begin
      r_flush_ack <= # TP s_flush_stop_wr_ch && !s_rd_xfer_pending && !s_rd_xfer_pending_db;
    end
  end

  assign strkr_flush_ack = r_flush_ack;
endmodule
