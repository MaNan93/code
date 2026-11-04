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
// ---    $Revision: #13 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/slave/DWC_pcie_axi_slv_wreq_if.sv#13 $
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"


 module DWC_pcie_axi_slv_wreq_if
 #(
  // -------------------------------------------------------------------------------------
  // Parameters modified by an instantiation parameter assignment
  // -------------------------------------------------------------------------------------
  parameter SLV_BUS_ID_WIDTH                = 5,
  parameter SLV_BUS_ADDR_WIDTH              = 32,
  parameter SLV_BURST_LEN_PW                = 2,
  parameter SLV_BUS_DATA_WIDTH              = 32,
  parameter SLV_BUS_WSTRB_WIDTH             = 4,
  parameter WR_MISC_INFO_WD                 = 20,
  parameter NFUNC_WD                        = 2,
  parameter CX_TAG_SIZE                     = `CX_TAG_SIZE,
  parameter MISC_INFO_TPH_WD                = 11,
  parameter TX_TLP_PREFIX_WD                = 32,
  // -------------------------------------------------------------------------------------
  // Parameters not modified by an instantiation parameter assignment
  // -------------------------------------------------------------------------------------
  parameter TP                              = `TP
  )
  
                                 (
  // Clocks and resets
  input                                              slv_aclk,
  input                                              slv_aresetn,
  // -------------------------------------------------------------------------------------
  // Write address channel
  input                                              awvalid,
  input       [SLV_BUS_ID_WIDTH-1:0]                 awid,
  input       [SLV_BUS_ADDR_WIDTH-1:0]               awaddr,
  input       [SLV_BURST_LEN_PW-1:0]                 awlen,
  input       [2:0]                                  awsize,
  input       [1:0]                                  awburst,
  input       [4:0]                                  awmisc_info_type,
  input                                              awmisc_info_snp,
  input                                              awmisc_info_ep,
  input                                              awmisc_info_ns,
  input                                              awmisc_info_ro,
  input       [2:0]                                  awmisc_info_tc,
  input       [7:0]                                  awmisc_info_msg_code,
  input                                              awmisc_info_db,
  input       [NFUNC_WD-1:0]                         awmisc_info_func_num,
  input                                              awmisc_info_nw,
  input       [1:0]                                  awmisc_info_ats,
  input       [TX_TLP_PREFIX_WD-1:0]                 awmisc_info_tlpprfx,
  input       [CX_TAG_SIZE-1:0]                      awmisc_info_p_tag,
  input       [MISC_INFO_TPH_WD-1:0]                 awmisc_info_tph,
  input                                              awmisc_info_atu_bypass,
  input [8:0]                                        awmisc_info_dst_segment,
  input                                              awmisc_info_ido,
  input                                              awatop_atomic_load_be,
  input                                              awburst_atomic_cas_wrap,
  input       [2:0]                                  awmisc_info_cpl_stat,
  output wire                                        awready,
  // -------------------------------------------------------------------------------------
  // Write data channel
  input                                              wvalid,
  input       [SLV_BUS_DATA_WIDTH-1:0]               wdata,
  input       [SLV_BUS_WSTRB_WIDTH-1:0]              wstrb,
  input                                              wlast,
  input                                              wmisc_info_ep,
  input                                              wmisc_info_silentDrop,
  output wire                                        wready,
  // -------------------------------------------------------------------------------------
  // Channel aligned write interface
  output wire                                        wif_valid,
  output wire [SLV_BUS_ADDR_WIDTH-1:0]               wif_addr,
  output wire [2:0]                                  wif_size,
  output wire [SLV_BURST_LEN_PW-1:0]                 wif_len,
  output wire [1:0]                                  wif_burst,
  output wire                                        wif_last,
  output wire [SLV_BUS_DATA_WIDTH-1:0]               wif_data,
  output wire [SLV_BUS_WSTRB_WIDTH-1:0]              wif_strb,
  output wire [WR_MISC_INFO_WD-1:0]                  wif_info,
  output wire [SLV_BUS_WSTRB_WIDTH-1:0]              wif_wep_strb,
  output wire [SLV_BUS_WSTRB_WIDTH-1:0]              wif_wsilentDrop_strb,
  output wire [SLV_BUS_WSTRB_WIDTH-1:0]              wif_wsilentDrop_strb_masked,
  input                                              dwalgn_ready
  );

  // -------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------
  localparam WR_MISC_INFO_DBI_VLDRQ =  NFUNC_WD
                                       + 3
                                       + TX_TLP_PREFIX_WD
                                       + CX_TAG_SIZE
                                       + MISC_INFO_TPH_WD
                                       + 1
                                       + 9
                                       + 1
                                       + 3                 // cpl_stat
                                       + 2
                                      ;
  localparam WR_MISC_INFO_DBI       =  WR_MISC_INFO_DBI_VLDRQ + 1;

  localparam WR_MISC_INFO_CAS_WRAP  =  0;


  // -------------------------------------------------------------------------------------
  // Wire/Reg
  // -------------------------------------------------------------------------------------
  reg                                      r_ready_rstval;
  // Internal ready, first aligned data/control beat accepted
  wire                                     s_ready;
  // Control info received before data
  wire                                     s_aw_pending;
  reg                                      r_aw_pending;
  // Data recieved before control
  wire                                     s_w_pending;
  reg                                      r_w_pending;

  // New serialised write request
  wire                                     write_req;

  // Aligned control/data request active
  wire                                     s_multi_beat_xfr;
  reg                                      r_multi_beat_xfr;

  // Data received before control
  wire                                     s_w_store_data;
  wire                                     s_w_store_data_hl;

  // Aligned control/data beat valid
  wire                                     s_valid;
  reg                                      r_valid;

  // Aligned control/data beat accepted
  wire                                     s_valid_accptd;
  // Aligned control beat valid
  wire                                     s_ctl_info_valid_hl;

  // Control info pending, waiting on data
  wire                                     s_aw_store_info_hl;

  // Invalid DBI request indication
  wire                                     awmisc_info_db_vldrq;

  // Packed misc info
  wire [WR_MISC_INFO_WD-1:0]               s_awmisc_info;

  // Stored interface control and info signals
  reg  [SLV_BUS_ADDR_WIDTH-1:0]            r_awaddr;
  reg  [SLV_BURST_LEN_PW-1:0]              r_awlen;
  reg  [2:0]                               r_awsize;
  reg  [1:0]                               r_awburst;
  reg  [WR_MISC_INFO_WD-1:0]               r_awmisc_info;


  // Selected control info signals
  reg  [SLV_BUS_ADDR_WIDTH-1:0]            s_mux_awaddr;
  reg  [2:0]                               s_mux_awsize;
  reg  [SLV_BURST_LEN_PW-1:0]              s_mux_awlen;
  reg  [1:0]                               s_mux_awburst;
  reg  [WR_MISC_INFO_WD-1:0]               s_mux_awmisc_info;

  // Selected data signals
  reg  [SLV_BUS_DATA_WIDTH-1:0]            s_mux_wdata;
  reg  [SLV_BUS_WSTRB_WIDTH-1:0]           s_mux_wstrb;
  reg                                      s_mux_wlast;
  reg                                      s_mux_wmisc_info_ep;
  reg                                      s_mux_wmisc_info_silentDrop;

  // Registered output control signals
  reg  [SLV_BUS_ADDR_WIDTH-1:0]            r_wif_addr;
  reg  [2:0]                               r_wif_size;
  reg  [SLV_BURST_LEN_PW-1:0]              r_wif_len;
  reg  [1:0]                               r_wif_burst;
  reg  [WR_MISC_INFO_WD-1:0]               r_wif_misc_info;

  reg  [SLV_BUS_DATA_WIDTH-1:0]            r_wdata;
  reg  [SLV_BUS_WSTRB_WIDTH-1:0]           r_wstrb;
  reg                                      r_wlast;
  reg                                      r_wmisc_info_ep;
  reg                                      r_wmisc_info_silentDrop;

  reg                                      r_wif_last;
  reg [SLV_BUS_DATA_WIDTH-1:0]             r_wif_wdata;
  reg [SLV_BUS_WSTRB_WIDTH-1:0]            r_wif_wstrb;
  reg                                      r_wif_wmisc_info_ep;
  reg                                      r_wif_wmisc_info_ep_sticky;
  wire                                     w_wif_wmisc_info_ep;
  reg                                      r_wif_wmisc_info_silentDrop;
  reg                                      r_wif_wmisc_info_silentDrop_sticky;
  wire                                     w_wif_wmisc_info_silentDrop;

  wire [3:0]                               wif_dbi_wstrb;
  wire                                     wif_dbi_vldrq;
  wire                                     wif_dbi;

  // -------------------------------------------------------------------------------------
  // Design
  // -------------------------------------------------------------------------------------
  // Ready signals
  // Forward the first serialised write data beat to the wif_* interface before
  // internally stalling the write data path.
  assign s_ready = r_ready_rstval && (dwalgn_ready || !wif_valid);
  // Stall address channel when
  // - Next control info received and current data transfer in progress or
  // - Control info pending or
  // - Serialised control/data bus stalled
  assign awready = s_ready && !r_aw_pending && !r_multi_beat_xfr;
  // Stall data channel when
  // - Data received before address or
  // - Serialised control/data bus stalled
  assign wready  = s_ready && !r_w_pending;

   // Write Request:
   // ctl info & data received or
   // data pending and ctl info received or
   // ctl info pending and data received
   assign write_req = ((awvalid && wvalid) ||
                       (r_w_pending && awvalid) ||
                       (r_aw_pending && (wvalid || r_w_pending))
                      );

  // Asserted when
  // - New serilaised address/data beat detected and
  // - for each subsequent data beat if multi-beat transfer
  // De-assert when last beat present at wif_* interface and s_ready is high
  assign s_valid = (write_req ||
                    (r_multi_beat_xfr && wvalid)) ? 1'b1 :
                                          s_ready ? 1'b0 : r_valid;

  // Serilaised data/address beat accepted
  assign s_valid_accptd = s_valid && s_ready;

  // Ctl info pending, no data received
  // If control info accepted prior to data being received
  // If data received in same cycle or data already stored then forward control info
  assign s_aw_store_info_hl = (awvalid && awready &&       // Ready de-asserted if multi-beat
                              (!wvalid && !r_w_pending) && // data not received
                              !r_aw_pending                // flag to transition from hi to lo
                             );

  // Select pending control info
  assign s_aw_pending = s_valid_accptd     ? 1'b0 :
                        s_aw_store_info_hl ? 1'b1 : r_aw_pending;

  // Store data if address not received
   assign s_w_store_data = (wvalid && wready &&
                            (!awvalid && !r_aw_pending) &&
                            !r_multi_beat_xfr
                           );

   assign s_w_pending = s_valid_accptd ? 1'b0 :
                        s_w_store_data ? 1'b1 : r_w_pending;

   assign s_w_store_data_hl = s_w_store_data && !r_w_pending;

   // Asserted when aligned address/data beat accepted but not the last.
   assign s_multi_beat_xfr = s_valid_accptd && !s_mux_wlast ? 1'b1 :
                             s_valid_accptd && s_mux_wlast  ? 1'b0 : r_multi_beat_xfr;

  always @(posedge slv_aclk or negedge slv_aresetn) begin : proc_seq_ctl
    if (!slv_aresetn) begin
      r_ready_rstval   <= # TP 1'b0;
      r_aw_pending     <= # TP 1'b0;
      r_multi_beat_xfr <= # TP 1'b0;
      r_w_pending      <= # TP 1'b0;
      r_valid          <= # TP 1'b0;
    end else begin
      r_ready_rstval   <= # TP 1'b1;
      r_aw_pending     <= # TP s_aw_pending;
      r_multi_beat_xfr <= # TP s_multi_beat_xfr;
      r_w_pending      <= # TP s_w_pending;
      r_valid          <= # TP s_valid;
    end
  end

  // DBI requests longer than 1 beat or wider than 4 bytes are invalid
  assign awmisc_info_db_vldrq = (awmisc_info_db) ? (awlen == 1'b0) && (awsize <= 3'b10) : 1'b0;

  // -------------------------------------------------------------------------------------
  // Build misc info
  // {id,type,snp,ep,ns,ro,tc,msg_code,db,func_num,nw,ats,vfunc_num,vfunc_active,
  // tlp_prfx,tph,atu_bypass,dst_segment,ido,atomic_load_be, atomic_cas_wrap, awecam_enum_err}
  assign s_awmisc_info = { awid
                         , awmisc_info_type
                         , awmisc_info_snp
                         , awmisc_info_ep
                         , awmisc_info_ns
                         , awmisc_info_ro
                         , awmisc_info_tc
                         , awmisc_info_msg_code
                         , awmisc_info_db
                         , awmisc_info_db_vldrq
                         , awmisc_info_func_num
                         , awmisc_info_nw
                         , awmisc_info_ats
                         , awmisc_info_tlpprfx
                         , awmisc_info_p_tag
                         , awmisc_info_tph
                         , awmisc_info_atu_bypass
                         , awmisc_info_dst_segment
                         , awmisc_info_ido
                         , awmisc_info_cpl_stat
                         , awatop_atomic_load_be
                         , awburst_atomic_cas_wrap
                        };

  // Latch control info if data not received
  // -----------------------------------------------------------------
  always @(posedge slv_aclk or negedge slv_aresetn) begin : proc_seq_awch_store
    if (!slv_aresetn) begin
      r_awaddr      <= # TP {SLV_BUS_ADDR_WIDTH{1'b0}};
      r_awlen       <= # TP {SLV_BURST_LEN_PW{1'b0}};
      r_awsize      <= # TP 3'b0;
      r_awburst     <= # TP 2'b0;
      r_awmisc_info <= # TP {WR_MISC_INFO_WD{1'b0}};
    end else if (s_aw_store_info_hl) begin
      r_awaddr      <= # TP awaddr;
      r_awlen       <= # TP awlen;
      r_awsize      <= # TP awsize;
      r_awburst     <= # TP awburst;
      r_awmisc_info <= # TP s_awmisc_info;
    end
  end

  // -----------------------------------------------------------------
  // If control info pending and data received then select latched
  // control info else select AW Channel interface control info
  // -----------------------------------------------------------------
  always @(*) begin : proc_comb_awch_sel
    // Initialise
    s_mux_awaddr      = awaddr;
    s_mux_awburst     = awburst;
    s_mux_awlen       = awlen;
    s_mux_awsize      = awsize;
    s_mux_awmisc_info = s_awmisc_info;

    if (s_valid && r_aw_pending) begin
      s_mux_awaddr      = r_awaddr;
      s_mux_awburst     = r_awburst;
      s_mux_awlen       = r_awlen;
      s_mux_awsize      = r_awsize;
      s_mux_awmisc_info = r_awmisc_info;
    end
  end

  // -----------------------------------------------------------------
  // Register out control info on first valid data beat.
  // -----------------------------------------------------------------
  // Register out control info on first accepted transfer
  assign s_ctl_info_valid_hl = s_valid_accptd && !r_multi_beat_xfr;

  always @(posedge slv_aclk or negedge slv_aresetn) begin : proc_seq_awch_reg
    if (!slv_aresetn) begin
      r_wif_addr      <= # TP {SLV_BUS_ADDR_WIDTH{1'b0}};
      r_wif_size      <= # TP 3'b0;
      r_wif_burst     <= # TP 2'b0;
      r_wif_len       <= # TP {SLV_BURST_LEN_PW{1'b0}};
      r_wif_misc_info <= # TP {WR_MISC_INFO_WD{1'b0}};

    end else if (s_ctl_info_valid_hl) begin
      r_wif_addr      <= # TP s_mux_awaddr;
      r_wif_size      <= # TP s_mux_awsize;
      r_wif_burst     <= # TP s_mux_awburst;
      r_wif_len       <= # TP s_mux_awlen;
      r_wif_misc_info <= # TP s_mux_awmisc_info;
    end
  end

   // -------------------------------------------------------------------------------------
   // If data recieved before control info then latch data.
   // -------------------------------------------------------------------------------------
  always @(posedge slv_aclk or negedge slv_aresetn) begin : proc_seq_wch_store
    if (!slv_aresetn) begin
      r_wdata                 <= # TP {SLV_BUS_DATA_WIDTH{1'b0}};
      r_wstrb                 <= # TP {SLV_BUS_WSTRB_WIDTH{1'b0}};
      r_wlast                 <= # TP 1'b0;
      r_wmisc_info_ep         <= # TP 1'b0;
      r_wmisc_info_silentDrop <= # TP 1'b0;
    end else if (s_w_store_data_hl) begin
      r_wdata                 <= # TP wdata;
      r_wstrb                 <= # TP wstrb;
      r_wlast                 <= # TP wlast;
      r_wmisc_info_ep         <= # TP wmisc_info_ep;
      r_wmisc_info_silentDrop <= # TP wmisc_info_silentDrop;
    end
  end

  // -------------------------------------------------------------------------------------
  // If data pending and control info received then select latched data
  // else select W Channel interface data
  // -------------------------------------------------------------------------------------
  always @(*) begin : proc_comb_wch_sel
    // Initialise
    s_mux_wdata                 = wdata;
    s_mux_wstrb                 = wstrb;
    s_mux_wlast                 = wlast;
    s_mux_wmisc_info_ep         = wmisc_info_ep;
    s_mux_wmisc_info_silentDrop = wmisc_info_silentDrop;

    if (r_w_pending && s_valid) begin
      s_mux_wdata                 = r_wdata;
      s_mux_wstrb                 = r_wstrb;
      s_mux_wlast                 = r_wlast;
      s_mux_wmisc_info_ep         = r_wmisc_info_ep;
      s_mux_wmisc_info_silentDrop = r_wmisc_info_silentDrop;
    end
  end

  // -------------------------------------------------------------------------------------
  // Register selected data per valid data beat
  // -------------------------------------------------------------------------------------
  always @(posedge slv_aclk or negedge slv_aresetn) begin : proc_seq_wch_reg
    if (!slv_aresetn) begin
      r_wif_wdata                 <= # TP {SLV_BUS_DATA_WIDTH{1'b0}};
      r_wif_wstrb                 <= # TP {SLV_BUS_WSTRB_WIDTH{1'b0}};
      r_wif_last                  <= # TP 1'b0;
      r_wif_wmisc_info_ep         <= # TP 1'b0;
      r_wif_wmisc_info_silentDrop <= # TP 1'b0;
    end else if (s_valid_accptd) begin
      r_wif_wdata                 <= # TP s_mux_wdata;
      r_wif_wstrb                 <= # TP s_mux_wstrb;
      r_wif_last                  <= # TP s_mux_wlast;
      r_wif_wmisc_info_ep         <= # TP s_mux_wmisc_info_ep;
      r_wif_wmisc_info_silentDrop <= # TP s_mux_wmisc_info_silentDrop;
    end
  end


  // -------------------------------------------------------------------------------------
  // Assign outputs
  // -------------------------------------------------------------------------------------
generate
  if (SLV_BUS_WSTRB_WIDTH ==  4) begin : gen_wstrb_4
    assign wif_dbi_wstrb = r_wif_wstrb[3:0];
  end else if (SLV_BUS_WSTRB_WIDTH == 8) begin : gen_wstrb_8
    assign wif_dbi_wstrb = (r_wif_addr[2]   == 1'h0) ? r_wif_wstrb[3:0] :
                                                       r_wif_wstrb[7:4] ;
  end else if (SLV_BUS_WSTRB_WIDTH == 16) begin  : gen_wstrb_16
    assign wif_dbi_wstrb = (r_wif_addr[3:2] == 2'h0) ? r_wif_wstrb[3:0] :
                           (r_wif_addr[3:2] == 2'h1) ? r_wif_wstrb[7:4] :
                           (r_wif_addr[3:2] == 2'h2) ? r_wif_wstrb[11:8] :
                                                       r_wif_wstrb[15:12] ;
  end else if (SLV_BUS_WSTRB_WIDTH == 32) begin : gen_wstrb_32
    assign wif_dbi_wstrb = (r_wif_addr[4:2] == 3'h0) ? r_wif_wstrb[3:0] :
                           (r_wif_addr[4:2] == 3'h1) ? r_wif_wstrb[7:4] :
                           (r_wif_addr[4:2] == 3'h2) ? r_wif_wstrb[11:8] :
                           (r_wif_addr[4:2] == 3'h3) ? r_wif_wstrb[15:12] :
                           (r_wif_addr[4:2] == 3'h4) ? r_wif_wstrb[19:16] :
                           (r_wif_addr[4:2] == 3'h5) ? r_wif_wstrb[23:20] :
                           (r_wif_addr[4:2] == 3'h6) ? r_wif_wstrb[27:24] :
                                                       r_wif_wstrb[31:28] ;
  end else if (SLV_BUS_WSTRB_WIDTH == 64) begin : gen_wstrb_64
    assign wif_dbi_wstrb = (r_wif_addr[5:2] == 4'h0) ? r_wif_wstrb[3:0] :
                           (r_wif_addr[5:2] == 4'h1) ? r_wif_wstrb[7:4] :
                           (r_wif_addr[5:2] == 4'h2) ? r_wif_wstrb[11:8] :
                           (r_wif_addr[5:2] == 4'h3) ? r_wif_wstrb[15:12] :
                           (r_wif_addr[5:2] == 4'h4) ? r_wif_wstrb[19:16] :
                           (r_wif_addr[5:2] == 4'h5) ? r_wif_wstrb[23:20] :
                           (r_wif_addr[5:2] == 4'h6) ? r_wif_wstrb[27:24] :
                           (r_wif_addr[5:2] == 4'h7) ? r_wif_wstrb[31:28] :
                           (r_wif_addr[5:2] == 4'h8) ? r_wif_wstrb[35:32] :
                           (r_wif_addr[5:2] == 4'h9) ? r_wif_wstrb[39:36] :
                           (r_wif_addr[5:2] == 4'ha) ? r_wif_wstrb[43:40] :
                           (r_wif_addr[5:2] == 4'hb) ? r_wif_wstrb[47:44] :
                           (r_wif_addr[5:2] == 4'hc) ? r_wif_wstrb[51:48] :
                           (r_wif_addr[5:2] == 4'hd) ? r_wif_wstrb[55:52] :
                           (r_wif_addr[5:2] == 4'he) ? r_wif_wstrb[59:56] :
                                                       r_wif_wstrb[63:60] ;
  end else if (SLV_BUS_WSTRB_WIDTH == 128) begin : gen_wstrb_128
    assign wif_dbi_wstrb = (r_wif_addr[6:2] == 5'h00) ? r_wif_wstrb[3:0] :
                           (r_wif_addr[6:2] == 5'h01) ? r_wif_wstrb[7:4] :
                           (r_wif_addr[6:2] == 5'h02) ? r_wif_wstrb[11:8] :
                           (r_wif_addr[6:2] == 5'h03) ? r_wif_wstrb[15:12] :
                           (r_wif_addr[6:2] == 5'h04) ? r_wif_wstrb[19:16] :
                           (r_wif_addr[6:2] == 5'h05) ? r_wif_wstrb[23:20] :
                           (r_wif_addr[6:2] == 5'h06) ? r_wif_wstrb[27:24] :
                           (r_wif_addr[6:2] == 5'h07) ? r_wif_wstrb[31:28] :
                           (r_wif_addr[6:2] == 5'h08) ? r_wif_wstrb[35:32] :
                           (r_wif_addr[6:2] == 5'h09) ? r_wif_wstrb[39:36] :
                           (r_wif_addr[6:2] == 5'h0a) ? r_wif_wstrb[43:40] :
                           (r_wif_addr[6:2] == 5'h0b) ? r_wif_wstrb[47:44] :
                           (r_wif_addr[6:2] == 5'h0c) ? r_wif_wstrb[51:48] :
                           (r_wif_addr[6:2] == 5'h0d) ? r_wif_wstrb[55:52] :
                           (r_wif_addr[6:2] == 5'h0e) ? r_wif_wstrb[59:56] :
                           (r_wif_addr[6:2] == 5'h0f) ? r_wif_wstrb[63:60] :
                           (r_wif_addr[6:2] == 5'h10) ? r_wif_wstrb[67:64] :
                           (r_wif_addr[6:2] == 5'h11) ? r_wif_wstrb[71:68] :
                           (r_wif_addr[6:2] == 5'h12) ? r_wif_wstrb[75:72] :
                           (r_wif_addr[6:2] == 5'h13) ? r_wif_wstrb[79:76] :
                           (r_wif_addr[6:2] == 5'h14) ? r_wif_wstrb[83:80] :
                           (r_wif_addr[6:2] == 5'h15) ? r_wif_wstrb[87:84] :
                           (r_wif_addr[6:2] == 5'h16) ? r_wif_wstrb[91:88] :
                           (r_wif_addr[6:2] == 5'h17) ? r_wif_wstrb[95:92] :
                           (r_wif_addr[6:2] == 5'h18) ? r_wif_wstrb[99:96] :
                           (r_wif_addr[6:2] == 5'h19) ? r_wif_wstrb[103:100] :
                           (r_wif_addr[6:2] == 5'h1a) ? r_wif_wstrb[107:104] :
                           (r_wif_addr[6:2] == 5'h1b) ? r_wif_wstrb[111:108] :
                           (r_wif_addr[6:2] == 5'h1c) ? r_wif_wstrb[115:112] :
                           (r_wif_addr[6:2] == 5'h1d) ? r_wif_wstrb[119:116] :
                           (r_wif_addr[6:2] == 5'h1e) ? r_wif_wstrb[123:120] :
                                                       r_wif_wstrb[127:124] ;
  end
endgenerate
  assign wif_dbi       = r_wif_misc_info[WR_MISC_INFO_DBI] ;
  assign wif_dbi_vldrq = r_wif_misc_info[WR_MISC_INFO_DBI_VLDRQ] && (wif_dbi_wstrb != 4'b0000);
  assign wif_valid     = !wif_dbi || wif_dbi_vldrq ? r_valid        : r_valid && r_wif_last;
  assign wif_addr      =                             r_wif_addr;
  assign wif_size      = !wif_dbi || wif_dbi_vldrq ? r_wif_size     : 3'b000;
  assign wif_len       = !wif_dbi || wif_dbi_vldrq ? r_wif_len      : {SLV_BURST_LEN_PW{1'b0}};
  assign wif_burst     = ((!r_wif_misc_info[WR_MISC_INFO_CAS_WRAP]) && (!wif_dbi || wif_dbi_vldrq)) ? r_wif_burst : 2'b01;
  assign wif_last      =                             r_wif_last;
  assign wif_data      =                             r_wif_wdata;
  assign wif_strb      = !wif_dbi || wif_dbi_vldrq ? r_wif_wstrb    : {SLV_BUS_WSTRB_WIDTH{1'b0}};
  assign wif_info      = {r_wif_misc_info[WR_MISC_INFO_WD-1:WR_MISC_INFO_DBI_VLDRQ+1],wif_dbi_vldrq,r_wif_misc_info[WR_MISC_INFO_DBI_VLDRQ-1:0]};
  assign wif_wep_strb = {SLV_BUS_WSTRB_WIDTH{w_wif_wmisc_info_ep}} & r_wif_wstrb;
  assign wif_wsilentDrop_strb = {SLV_BUS_WSTRB_WIDTH{w_wif_wmisc_info_silentDrop}};
  assign wif_wsilentDrop_strb_masked = {SLV_BUS_WSTRB_WIDTH{w_wif_wmisc_info_silentDrop}} & r_wif_wstrb;

  always @(posedge slv_aclk or negedge slv_aresetn) begin : s_wpoison_sticky_PROC
    if (!slv_aresetn) begin
      r_wif_wmisc_info_ep_sticky <= 1'b0;
    end else if(wif_last && dwalgn_ready) begin
      r_wif_wmisc_info_ep_sticky <= 1'b0;
    end else begin
      r_wif_wmisc_info_ep_sticky <= w_wif_wmisc_info_ep;
    end
  end

  assign w_wif_wmisc_info_ep = r_wif_wmisc_info_ep_sticky || ( r_wif_wmisc_info_ep && wif_valid );

  always @(posedge slv_aclk or negedge slv_aresetn) begin : s_wSilentDrop_sticky_PROC
    if (!slv_aresetn) begin
      r_wif_wmisc_info_silentDrop_sticky <= 1'b0;
    end else if(wif_last && dwalgn_ready) begin
      r_wif_wmisc_info_silentDrop_sticky <= 1'b0;
    end else begin
      r_wif_wmisc_info_silentDrop_sticky <= w_wif_wmisc_info_silentDrop;
    end
  end

  assign w_wif_wmisc_info_silentDrop = r_wif_wmisc_info_silentDrop_sticky || ( r_wif_wmisc_info_silentDrop && wif_valid );

`ifndef SYNTHESIS

`endif //  `ifndef SYNTHESIS


endmodule
