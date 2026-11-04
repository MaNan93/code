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
// ---    $DateTime: 2024/01/19 09:25:58 $
// ---    $Revision: #20 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/dbi/DWC_pcie_axi_dbi.sv#20 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"


 module DWC_pcie_axi_dbi
 #(
  parameter MAX_SLV_TAG_PW                  = 5,
  parameter DBI_SLV_BUS_ADDR_WIDTH          = 32,
  parameter VALID_DBI_ADDR_WD               = 14,
  parameter EXTRA_DBI_ADDR_BIT              = 1,
  parameter NFUNC_WD                        = 3,
  parameter NVFUNC_WD                       = 2,
  parameter SYNC_DEPTH                      = 2,
  parameter RESP_ERRBUS_WD                  = 2,
  parameter BURST_LEN_PW                    = `CC_SLV_INT_BURST_LEN_PW,
  parameter TP                              = `TP
  )
  (
  //-------------------------------------------------------------------------------------
  // Clocks and resets
  input                                              dbi_clk,
  input                                              dbi_rst_n,
  input                                              aux_clk_g,
  input                                              core_rst_n,
  //-------------------------------------------------------------------------------------
  // Configuration Register
  //-------------------------------------------------------------------------------------
  // Slave Data Bus Request Interface
  input                                              dbsif_rd,
  input                                              dbsif_wr,
  input       [MAX_SLV_TAG_PW-1:0]                   dbsif_tag,
  input       [DBI_SLV_BUS_ADDR_WIDTH-1:0]           dbsif_addr,
  input       [3:0]                                  dbsif_strb,
  input       [BURST_LEN_PW-1:0]                     dbsif_len,
  input                                              dbsif_vldrq,
  input       [31:0]                                 dbsif_data,
  output wire                                        dbi_ready,
  //-------------------------------------------------------------------------------------
  // Slave Data Bus Response Interface
  output wire                                        dbi_valid,
  output wire                                        dbi_last,
  output wire [MAX_SLV_TAG_PW-1:0]                   dbi_tag,
  output wire [RESP_ERRBUS_WD-1:0]                   dbi_resp,
  output wire [31:0]                                 dbi_data,
  input                                              sif_db_ready,
  //-------------------------------------------------------------------------------------
  // Data bus bi-directional interface
  // dbi_wr - 4'd0: read; 4'd1, 4'd2, 4'd4, 4'd8: bytes 0,1,2,3 write byte lane enables
  output wire                                        dbi_cs,
  output wire                                        dbi_cs2,
  output wire [31:0]                                 dbi_addr,
  output wire [31:0]                                 dbi_din,
  output wire [3:0]                                  dbi_wr,
  output wire [2:0]                                  dbi_bar_num,
  output wire [NFUNC_WD-1:0]                         dbi_func_num,
  output wire                                        dbi_rom_access,
  output wire                                        dbi_io_access,
  input                                              dbi_ack,
  input       [31:0]                                 dbi_dout
  );
  // -------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------
  // Valid address bits excluding the CDM/ELBI select. Scales with configuration.
  // ARI_ENABLE ? 32 : DBI_MULTI_FUNC_BAR_EN ? 21 : NFUNC == 1 ? 13 : 20
  localparam DBI_ADDR_WD             = VALID_DBI_ADDR_WD - EXTRA_DBI_ADDR_BIT;

  // Packed request interface field  positions {wr, addr, din}
  localparam RQ_INTF_WD              = 1 + 4 + DBI_ADDR_WD + 32;
  localparam RQ_INTF_VLDRQ_MSB       = RQ_INTF_WD -1 ;
  localparam RQ_INTF_VLDRQ_LSB       = RQ_INTF_VLDRQ_MSB;
  localparam RQ_INTF_WR_MSB          = RQ_INTF_VLDRQ_LSB -1;
  localparam RQ_INTF_WR_LSB          = RQ_INTF_WR_MSB -3;
  localparam RQ_INTF_ADDR_MSB        = RQ_INTF_WR_LSB -1;
  localparam RQ_INTF_ADDR_LSB        = RQ_INTF_ADDR_MSB - DBI_ADDR_WD + 1;
  localparam RQ_INTF_DATA_MSB        = RQ_INTF_ADDR_LSB -1;
  localparam RQ_INTF_DATA_LSB        = RQ_INTF_DATA_MSB -31;

  // FSM states
  localparam S_DBI_IDLE          = 3'h0;
  localparam S_WAIT_RD_RESP      = 3'h1;
  localparam S_WAIT_WR_RESP      = 3'h2;
  localparam S_DBI_READ          = 3'h3;
  localparam S_DBI_WRITE         = 3'h4;

  // Synchroniser configuration
  localparam SEND_MODE = 0;
  // Single clock cycle pulse in produces single clock cycle pulse out

  typedef struct packed {
    logic vldrq;
    logic [4-1:0] wr;
    logic [DBI_ADDR_WD-1:0] addr;
    logic [32-1:0] data;
  } reqIntf_t;

  // -------------------------------------------------------------------------------------
  // Wire/Reg
  // -------------------------------------------------------------------------------------
  // Fsm
  reg  [2:0]                               nxt_xfer_state;
  reg  [2:0]                               r_xfer_state;
  reg  [2:0]                               rr_xfer_state;

  reg  [BURST_LEN_PW -1:0]                 cnt_len;

  // Req
  reg  [DBI_ADDR_WD -1:0]                  r_dbsif_addr_remap;
  reg  [31:0]                              r_dbsif_data;
  reg  [3:0]                               r_dbsif_strb;
  reg  [BURST_LEN_PW -1:0]                 r_dbsif_len;
  wire                                     s_dbsif_vldrq;
  reg                                      r_dbsif_vldrq;
  wire [RQ_INTF_WD -1:0]                   s_dbsif_req_intf;
  wire [RQ_INTF_WD -1:0]                   s_dbi_req_intf;
  reqIntf_t                                s_dbi_req_intf_s;


  wire                                     s_dbsif_cs_hl;
  wire [3:0]                               s_dbsif_wr;

  wire                                     a2crq_cs_hl;
  reg                                      r_a2crq_cs;
  reg   [31:0]                             s_dbi_addr;

  // Rsp
  wire                                     c2arsp_valid_hl;
  reg                                      r_c2arsp_valid_hl;
  wire [31:0]                              c2arsp_data;
  wire                                     c2arsp_err;
  wire [31:0]                              s_c2arsp_data;
  wire                                     s_c2arsp_err;
  reg  [31:0]                              r_c2arsp_data;
  reg                                      r_c2arsp_err;

  reg                                      r_dbsif_wr_not_rd;

  reg  [MAX_SLV_TAG_PW -1 :0]              r_dbsif_tag;
  reg                                      r_dbi_ack;
  reg                                      rr_dbi_ack;


  wire                                     s_dbi_ack_hl;
  wire                                     s_dbi_err;

  wire                                     s_dbi_ack_err;

  reg  [31:0]                              r_dbi_dout;
  wire [31:0]                              s_dbi_dout;

  wire                                     dbi_err;


  wire                                     dbi_vldrq;

  wire                                     s_done_c2arsp;

  reg                                      r_dbi_ack_hl;
  reg                                      r_dbi_err;
  reg  [31:0]                              r_dbi_ack_dout;

  wire                                     msix_req;

  // -------------------------------------------------------------------------------------
  // Request/Response DBI FSM
  // -------------------------------------------------------------------------------------
  always @(posedge dbi_clk or negedge dbi_rst_n) begin : proc_seq_fsm
    if (!dbi_rst_n) begin
      r_xfer_state  <= #TP S_DBI_IDLE;
      rr_xfer_state <= #TP S_DBI_IDLE;
    end else begin
      r_xfer_state  <= #TP nxt_xfer_state;
      rr_xfer_state <= #TP r_xfer_state;
    end
  end

  always @(*) begin : proc_comb_fsm

    nxt_xfer_state = r_xfer_state;

    case  (r_xfer_state)

      default: // S_DBI_IDLE
        if (dbsif_rd)
          nxt_xfer_state = S_WAIT_RD_RESP;
        else if (dbsif_wr)
          nxt_xfer_state = S_WAIT_WR_RESP;
        else
          nxt_xfer_state = S_DBI_IDLE;

      S_WAIT_RD_RESP:
      // Wait for DBI response
        if (r_c2arsp_valid_hl)
          nxt_xfer_state = S_DBI_READ;

      S_WAIT_WR_RESP:
      // Wait for DBI response
        if (r_c2arsp_valid_hl)
          nxt_xfer_state = S_DBI_WRITE;

      S_DBI_WRITE:
      // Wait for Slave to accept response
        if (sif_db_ready)
          nxt_xfer_state = S_DBI_IDLE;

      S_DBI_READ:
      // Wait for Slave to accept response
        if (sif_db_ready && dbi_last)
          nxt_xfer_state = S_DBI_IDLE;

    endcase

  end

  // -------------------------------------------------------------------------------------
  // Request
  // -------------------------------------------------------------------------------------
  // Generate pulse on exit from IDLE state
  // Always accept the first request, stall next request if requests received back to back
  assign s_dbsif_cs_hl = ((r_xfer_state != S_DBI_IDLE) &&
                          (rr_xfer_state == S_DBI_IDLE));

  // Store the slave interface request signals
  always @(posedge dbi_clk or negedge dbi_rst_n) begin : proc_seq_slv_req
    if (!dbi_rst_n) begin
      r_dbsif_addr_remap <= #TP 0;
      r_dbsif_data       <= #TP 0;
      r_dbsif_strb       <= #TP 0;
      r_dbsif_len        <= #TP 0;
      r_dbsif_vldrq      <= #TP 0;
    end else if (r_xfer_state == S_DBI_IDLE) begin
      // Remap CDM/ELBI select to LSB
        r_dbsif_addr_remap <= #TP {dbsif_addr[30:21],dbsif_addr[20:1],dbsif_addr[21]};
      r_dbsif_strb       <= #TP dbsif_strb;
      r_dbsif_data       <= #TP dbsif_data;
      r_dbsif_len        <= #TP dbsif_len;
      r_dbsif_vldrq      <= #TP dbsif_vldrq;
    end
  end

  // Pass the strobes for DBI write only; set strobes to zero for DBI reads
  assign s_dbsif_wr = (r_xfer_state == S_WAIT_WR_RESP) ? r_dbsif_strb : 4'b0;

  // Accept next request when response to pending request accepted.
  assign dbi_ready = (r_xfer_state == S_DBI_IDLE);

  // Pack request info, push thru the synchroniser
  assign s_dbsif_req_intf = {
                             r_dbsif_vldrq,
                             s_dbsif_wr,
                             r_dbsif_addr_remap,
                             r_dbsif_data
                            };

  // Instantiate Slave to Core synchroniser
  DWC_pcie_ctl_bcm25
  
  #(.WIDTH       (RQ_INTF_WD)
   ,.PEND_MODE   (0)
   ,.ACK_DELAY   (1)
   ,.F_SYNC_TYPE (SYNC_DEPTH)
   ,.R_SYNC_TYPE (SYNC_DEPTH)
   ,.VERIF_EN    (1)
   ,.SEND_MODE   (SEND_MODE)
  )
  u_a2crq
  (.clk_s           (dbi_clk)
  ,.rst_s_n         (dbi_rst_n)
  ,.init_s_n        (1'b1)
  ,.send_s          (s_dbsif_cs_hl)
  ,.data_s          ({s_dbsif_req_intf })
  ,.empty_s         ()
  ,.full_s          ()
  ,.done_s          ()

  ,.clk_d           (aux_clk_g)
  ,.rst_d_n         (core_rst_n)
  ,.init_d_n        (1'b1)
  ,.data_d          ({s_dbi_req_intf })
  ,.data_avail_d    (a2crq_cs_hl)
  );

  // Hold the data bus select line, release when ack returns
  always @(posedge aux_clk_g or negedge core_rst_n) begin : dbi_cs_Proc
    if (!core_rst_n) begin
      r_a2crq_cs  <= #TP 0;
    end else begin
      if (a2crq_cs_hl) begin
        r_a2crq_cs  <= #TP 1'b1;
      end else if (dbi_ack) begin
        r_a2crq_cs  <= #TP 1'b0;
      end
    end
  end

  assign s_dbi_req_intf_s = s_dbi_req_intf;

  // Extract valid request indication
  assign dbi_vldrq = s_dbi_req_intf[RQ_INTF_VLDRQ_MSB :RQ_INTF_VLDRQ_LSB ];

  // Gate all invalid requests (length greater than 1 beat (dbi_len == 0) or size greater than 4 bytes or writes with all null strobes)
  assign dbi_cs  = (a2crq_cs_hl || r_a2crq_cs) && dbi_vldrq;
   assign dbi_cs2 = (a2crq_cs_hl || r_a2crq_cs) && dbi_vldrq && s_dbi_req_intf[RQ_INTF_ADDR_LSB + 20];


  // Extract type of request and write data
  assign dbi_wr  = s_dbi_req_intf[RQ_INTF_WR_MSB  :RQ_INTF_WR_LSB  ];
  assign dbi_din = s_dbi_req_intf[RQ_INTF_DATA_MSB:RQ_INTF_DATA_LSB];
wire is_unroll;
   assign is_unroll = s_dbi_req_intf[RQ_INTF_ADDR_LSB] && s_dbi_req_intf[RQ_INTF_ADDR_LSB+20];

  always @(*) begin : proc_comb_dbi_addr
    // Initialise
    s_dbi_addr = 32'h0;

    s_dbi_addr = is_unroll? {1'b0, s_dbi_req_intf[RQ_INTF_ADDR_LSB+30], {6{1'b0}}, s_dbi_req_intf[RQ_INTF_ADDR_LSB + 23], s_dbi_req_intf[RQ_INTF_ADDR_LSB + 22], 2'b0,  s_dbi_req_intf[RQ_INTF_ADDR_LSB +: 20]} : {{(32-12){1'b0}},s_dbi_req_intf[RQ_INTF_ADDR_LSB +:12]};
  end

 // Dword aligned address, lsb indicates request direction, cdm/elbi
 // TDISP Filter and Port Logic Memory map memory regions have precendence
 assign dbi_addr          =
                            {s_dbi_addr[31:2], 1'b0, s_dbi_addr[0]};

  assign msix_req = 1'b0;

wire dbi_elbi2;
assign dbi_elbi2 = (!msix_req) & s_dbi_req_intf[RQ_INTF_ADDR_LSB + 22] & (!s_dbi_req_intf[RQ_INTF_ADDR_LSB + 23]);

  assign dbi_rom_access   = is_unroll? 1'b0: s_dbi_req_intf[RQ_INTF_ADDR_LSB + 19];
  assign dbi_func_num     = (is_unroll & !msix_req) ? dbi_elbi2 ? s_dbi_req_intf[RQ_INTF_ADDR_LSB + 27 +: 3] : {NFUNC_WD{1'b0}}: s_dbi_req_intf[RQ_INTF_ADDR_LSB + 16 +: 3] ; //The bit30 is used to access to Unroll Registers - Shall be zero
  assign dbi_bar_num      = is_unroll ? dbi_elbi2 ? s_dbi_req_intf[RQ_INTF_ADDR_LSB + 24 +: 3] :  3'h0: s_dbi_req_intf[RQ_INTF_ADDR_LSB + 13 +: 3];
  assign dbi_io_access    = is_unroll? 1'b0: s_dbi_req_intf[RQ_INTF_ADDR_LSB + 12];


  // -------------------------------------------------------------------------------------
  // DBI response
  // -------------------------------------------------------------------------------------
  // Register the response data
  always @(posedge aux_clk_g or negedge core_rst_n) begin : proc_seq_dbrsp
    if (!core_rst_n) begin
       r_dbi_ack  <= #TP 1'b0;
       rr_dbi_ack <= #TP 1'b0;
       r_dbi_dout <= #TP 0;
    end else begin
       r_dbi_ack  <= #TP dbi_ack;
       rr_dbi_ack <= #TP r_dbi_ack;
       r_dbi_dout <= #TP dbi_dout;
    end
  end

  // Ack can be valid for 1 or 2 cycles.
  // Generate a pulse on the falling edge and push response to CDC FIFO
  assign s_dbi_ack_hl  = (!dbi_ack && r_dbi_ack)                || (!dbi_vldrq && a2crq_cs_hl);
  assign s_dbi_ack_err = !dbi_ack && r_dbi_ack && !rr_dbi_ack;
  assign s_dbi_err     = !dbi_vldrq;
  assign s_dbi_dout    = dbi_vldrq ? r_dbi_dout : 32'hFFFF;


  // Need to wait for bcm25 synchronizer to finish processing (done_s is asseerted) a completion
  // before sending a new one, otherwise we can have issues when core_clk is much slower than AXI clock
  // Completion data needs to be stored while we wait
  always @(posedge aux_clk_g or negedge core_rst_n) begin : proc_seq_dbi_resp
    if (!core_rst_n) begin
      r_dbi_ack_hl   <= #TP 1'b0;
      r_dbi_err      <= #TP 1'b0;

      r_dbi_ack_dout <= #TP 32'h0000;
    end else begin
      if(s_dbi_ack_hl)begin
        r_dbi_ack_hl   <= #TP 1'b1;
        r_dbi_err      <= #TP s_dbi_err;
        r_dbi_ack_dout <= #TP s_dbi_dout;
      end else if(s_done_c2arsp)begin
        r_dbi_ack_hl   <= #TP 1'b0;
      end
    end
  end

  // Instantiate Core to Slave synchroniser
  DWC_pcie_ctl_bcm25
  
  #(.WIDTH              (33) // If TDISP is enabled, than one more bit is for tdisp and two more bits for crs/ur erros mapping
   ,.PEND_MODE          (0)
   ,.ACK_DELAY          (1)
   ,.F_SYNC_TYPE        (SYNC_DEPTH)
   ,.R_SYNC_TYPE        (SYNC_DEPTH)
   ,.VERIF_EN           (1)
   ,.SEND_MODE          (SEND_MODE)
  )
  u_c2arsp
  (.clk_s            (aux_clk_g)
   ,.rst_s_n         (core_rst_n)
   ,.init_s_n        (1'b1)
   ,.send_s          (r_dbi_ack_hl)
   ,.data_s          ({ r_dbi_err,r_dbi_ack_dout})
   ,.empty_s         ()
   ,.full_s          ()
   ,.done_s          (s_done_c2arsp)

   ,.clk_d           (dbi_clk)
   ,.rst_d_n         (dbi_rst_n)
   ,.init_d_n        (1'b1)
   ,.data_d          ({ c2arsp_err,c2arsp_data})
   ,.data_avail_d    (c2arsp_valid_hl)
   );

  // Delay the response by one cycle before accepting next request.
  // Enables the 2 cycle ACK to complete.
  assign s_c2arsp_data = c2arsp_valid_hl  ? c2arsp_data   : r_c2arsp_data;
  assign s_c2arsp_err  = c2arsp_valid_hl  ? c2arsp_err    : r_c2arsp_err;


  always @(posedge dbi_clk or negedge dbi_rst_n) begin : dclk_dbi_ack_Proc
    if (!dbi_rst_n) begin
       r_c2arsp_valid_hl <= #TP 1'b0;
       r_c2arsp_data     <= #TP {32{1'b0}};
       r_c2arsp_err      <= #TP 1'b0;
    end else begin
       r_c2arsp_valid_hl <= #TP c2arsp_valid_hl;
       r_c2arsp_data     <= #TP s_c2arsp_data;
       r_c2arsp_err      <= #TP s_c2arsp_err;
    end
  end

  always@(posedge dbi_clk or negedge dbi_rst_n) begin
    if(!dbi_rst_n)begin
      cnt_len <= #TP {BURST_LEN_PW{1'b0}};
    end else begin
      if(!r_dbsif_wr_not_rd)begin
        if(dbi_valid && sif_db_ready)begin
          if(cnt_len < r_dbsif_len)
            cnt_len <= #TP cnt_len + {{(BURST_LEN_PW-1){1'b0}},1'b1};
          else
            cnt_len <= #TP {BURST_LEN_PW{1'b0}};
        end
      end else begin
        cnt_len <= #TP {BURST_LEN_PW{1'b0}};
      end
    end
  end

  assign dbi_valid = ((r_xfer_state == S_DBI_WRITE) | (r_xfer_state == S_DBI_READ));
  assign dbi_data  = r_dbsif_vldrq ? r_c2arsp_data : 32'hffffffff;
  assign dbi_err   = r_c2arsp_err || !r_dbsif_vldrq;


  assign dbi_last  = (r_xfer_state == S_DBI_WRITE) || ((r_xfer_state == S_DBI_READ) && (cnt_len >= r_dbsif_len));

  // Store the AXI id/tag request info, return with response
  always @(posedge dbi_clk or negedge dbi_rst_n) begin : latchd_mtag_Proc
    if (!dbi_rst_n) begin
      r_dbsif_tag       <= #TP 0;
      r_dbsif_wr_not_rd <= #TP 0;
    end else if ((dbsif_rd | dbsif_wr) && (r_xfer_state == S_DBI_IDLE)) begin
      if (dbsif_rd) begin
        r_dbsif_wr_not_rd <= #TP 1'b0;
      end else if (dbsif_wr) begin
        r_dbsif_wr_not_rd <= #TP 1'b1;
      end
      r_dbsif_tag       <= #TP dbsif_tag;
    end
  end

  assign dbi_tag = r_dbsif_tag;

  // Send read or write response
  // (dbi_resp[0]=0: Read,     dbi_resp[0]=1: Write)
  // (dbi_resp[1]=0: OK,       dbi_resp[1]=1: Error)
  // (dbi_resp[2]=0: TDISP-OK, dbi_resp[2]=1: TDISP-Error)
  // (dbi_resp[3]=0: CA,       dbi_resp[3]=1: UR)
  // (dbi_resp[4]=0: CA/UR,    dbi_resp[4]=1: CRS)
  assign dbi_resp = {
                     1'b0,
                     dbi_err, r_dbsif_wr_not_rd};

`ifndef SYNTHESIS
  wire [16*8:1] DB_FSM;

  assign DB_FSM = (r_xfer_state == S_DBI_IDLE)     ?  "IDLE"         :
                  (r_xfer_state == S_WAIT_RD_RESP) ?  "WAIT_RD_RESP" :
                  (r_xfer_state == S_WAIT_WR_RESP) ?  "WAIT_WR_RESP" :
                  (r_xfer_state == S_DBI_READ)     ?  "DBI_READ"     :
                  (r_xfer_state == S_DBI_WRITE)    ?  "DBI_WRITE"    :
                  "UNDEF";

`endif

endmodule
