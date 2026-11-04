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
// ---    $Revision: #10 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/slave/DWC_pcie_axi_slv_rsp.sv#10 $
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"


 module DWC_pcie_axi_slv_rsp
import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
import DWC_pcie_ctl_pkg::MAX_RAS_PROT_CHK_N;
import DWC_pcie_ctl_pkg::RAS_DP_PROT_CHK_ID_BASE_AXI_BRIDGE;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
 #(
  parameter SLV_BUS_ID_WIDTH                 = 5,
  parameter SLV_BURST_LEN_PW                 = 4,
  parameter NFUNC_WD                         = 1,
  parameter RX_TLP_PREFIX_WD                 = 32,
  parameter MISC_INFO_TPH_WD                 = 11,
  parameter SLV_BUS_STRB_WIDTH               = 4,
  parameter SLV_BUS_STRB_PW                  = 2,
  parameter SLV_BUS_DATA_WIDTH               = 32,
  parameter SLV_NUM_OUTSTND_WR_REQ           = 32,
  parameter SLV_NUM_OUTSTND_WR_REQ_LOG2      = 5,
  parameter SLV_WRP_RSP_ROB_FIFO_DP           = `CC_SLV_WRP_RSP_ROB_FIFO_DP,
  parameter SLV_WRP_RSP_ROB_FIFO_ADDR_WD      = `CC_SLV_WRP_RSP_ROB_FIFO_ADDR_WD,
  parameter CX_RAS_PROT_RANGE                = `CX_RAS_PROT_RANGE,
  parameter CX_RAS_PARITY_MODE               = `CX_RAS_PARITY_MODE,
  parameter MAX_SLV_TAG                      = 32,
  parameter MAX_SLV_TAG_PW                   = 5,
  parameter DC_CPL_STATUS_WD                 = `DC_CPL_STATUS_WD,
  parameter TP                               = `TP
 )
 
                            (
  // -------------------------------------------------------------------------------------
  // Clocks and resets
  input                                         slv_aclk,
  input                                         slv_aresetn,
  output wire                                   srsp_ras_par_rslv_dt_pulse,
  output ras_dp_err_log_t                       srsp_rslv_dt_ras_dp_err_log,
    input  ras_dp_err_inj_t                    ras_dp_err_inj_slv_aclk,
  // -------------------------------------------------------------------------------------
  // Error response configuration interface
  input [4:0]                                   cfg_err_resp_mode,
  input [5:0]                                   cfg_err_resp_map,
  // -------------------------------------------------------------------------------------
  // AXI Write request information interface
  input                                         swrq_wr_valid_hl,
  input [SLV_BUS_ID_WIDTH-1:0]                  swrq_wr_id,
  input                                         swrq_wr_p,
  input                                         swrq_wr_np,
  input                                         swrq_wr_np_atomic,
  input                                         swrq_wr_last_null_writes,
  // -------------------------------------------------------------------------------------
  // Non-Posted response interface
  input                                         nprspf_valid,
  input [MAX_SLV_TAG_PW-1:0]                    nprspf_tag,
  input                                         nprspf_to,
  input                                         nprspf_ep,
  input [2:0]                                   nprspf_tc,
  // DBIindication in
  input                                         dbi_response,
  input                                         nprspf_ido,
  input                                         nprspf_ns,
  input                                         nprspf_ro,
  input [2:0]                                   nprspf_status,
  input                                         nprspf_cpl,
  input [7:0]                                   nprspf_cpl_segment,
  input [8:0]                                   nprspf_dst_segment,
  input [1:0] nprspf_resp,
  input [SLV_BUS_DATA_WIDTH-1:0]                nprspf_data,
  input                                         nprspf_last,
  output wire                                   srsp_np_ready,
  // -------------------------------------------------------------------------------------
  // AXI Tag Manager Response interface
  output wire                                   srsp_np_tag_recycled,
  output wire [MAX_SLV_TAG_PW-1:0]              srsp_np_tag,
  input                                         atm_np_wr,
  input [SLV_BUS_ID_WIDTH-1:0]                  atm_np_id,
  input [SLV_BUS_STRB_PW-1:0]                   atm_np_addr_low,
  input [SLV_BURST_LEN_PW-1:0]                  atm_np_len,
  input [2:0]                                   atm_np_size,
  input                                         atm_np_atomic,
  input [3:0]                                   atm_np_wrap_beat_offset,
  input                                         atm_np_ven_id_rd,
  // -------------------------------------------------------------------------------------
  // AXI Read response interface
  output wire                                   srsp_rvalid,
  output wire [SLV_BUS_ID_WIDTH-1:0]            srsp_rid,
  output wire                                   srsp_rto,
  output wire                                   srsp_rep,
  output wire [2:0]                             srsp_rtc,
  output wire                                   srsp_rido,
  output wire                                   srsp_rns,
  output wire                                   srsp_rro,
  output wire [2:0]                             srsp_rstatus,
  output wire                                   srsp_rcpl,
  output wire [7:0]                             srsp_rcpl_segment,
  output wire [8:0]                             srsp_rdst_segment,
  output wire [1:0]                             srsp_rresp,
  output wire [SLV_BUS_DATA_WIDTH-1:0]          srsp_rdata,
  output wire                                   srsp_rlast,
  input                                         rready,
  // -------------------------------------------------------------------------------------
  // Posted Response Interface
  input                                         pdcmp_p_rsp_valid_hl,
  input [SLV_BUS_ID_WIDTH-1:0]                  pdcmp_p_rsp_id,
  input [DC_CPL_STATUS_WD-1:0]                  pdcmp_p_rsp_cpl_stat,
  // -------------------------------------------------------------------------------------
  // Non Posted Atomic Response Interface
  input                                         npdcmp_np_atomic_rsp_valid_hl,
  input [SLV_BUS_ID_WIDTH-1:0]                  npdcmp_np_atomic_rsp_id,
  // -------------------------------------------------------------------------------------
  // AXI Write Response Interface
  output wire                                   srsp_bvalid_hl,
  output wire [SLV_BUS_ID_WIDTH-1:0]            srsp_bid,
  output wire [`CC_AXIJ_DMWR_VALUE +1:0]        srsp_bresp,
  output wire                                   srsp_bto,
  output wire                                   srsp_bep,
  output wire [2:0]                             srsp_btc,
  output wire                                   srsp_bns,
  output wire                                   srsp_bro,
  output wire [2:0]                             srsp_bstatus,
  output wire                                   srsp_bcpl,
  // DBI rsp info
  output wire                                   dbi_response_wr,
  output wire                                   dbi_response_rd,
  output wire [7:0]                             srsp_bcpl_segment,
  output wire [8:0]                             srsp_bdst_segment,
  // Completions Status during DPC
  input                                         cdc_core_in_dpc_i      ,
  input                                         qst_cfg_dpc_cpl_cntrl_i,
  input                                         bready
  );
  // -------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------
  // Non-Posted Read Response parameters
  localparam RD_NP_RSP_INFO_WD = { SLV_BUS_ID_WIDTH // atm_np_id
                                 + 2                // serr_np_resp
                                 + 1                // nprspf_to
                                 + 1                // nprspf_ep
                                 + 3                // nprspf_tc
                                 + 1                // nprspf_ido
                                 + 1                // nprspf_ns
                                 + 1                // nprspf_ro
                                 + 3                // nprspf_status
                                 + 1                // nprspf_cpl
                                 + SLV_BURST_LEN_PW // atm_np_len
                                 + 4                // atm_np_wrap_beat_offset
                                 + 8                // nprspf_cpl_segment,
                                 + 9                // nprspf_dst_segment,
                           };


  // {valid, data, last, addr_low, len, size }
  localparam RD_NP_RSP_CTL_WD = { 1
                                + SLV_BUS_DATA_WIDTH
                                + 1
                                + SLV_BUS_STRB_PW
                                + SLV_BURST_LEN_PW
                                + 3
                                };

  // {valid, data, last, addr_low, len, size, resp, id, to, tc, ns, ro, status,
  // cpl, func_num, prfx }
  localparam RD_NP_RSP_INTF_WD = { RD_NP_RSP_CTL_WD + RD_NP_RSP_INFO_WD };

  // Non-Posted Write Response parameters
  // {to, tc, ep, ns, ro, status, cpl, func_num, prfx, idunq }
  localparam  WR_NP_RSP_INFO_WD = { 1 + 3 + 1 + 1 + 1 + 3 + 1
                                  + 8                // nprspf_cpl_segment,
                                  + 9                // nprspf_dst_segment,
                                  };

  // {valid, resp, id}
  localparam WR_NP_RSP_CTL_WD = { 3 + `CC_AXIJ_DMWR_VALUE + SLV_BUS_ID_WIDTH };

  // {valid, resp, id, to, tc, ns, ro, status, cpl, func_num, prfx }
  localparam WR_NP_RSP_INTF_WD = { WR_NP_RSP_CTL_WD + WR_NP_RSP_INFO_WD};

  // Locate pass thru info msb
  localparam RD_NP_RSP_WRAP_INFO_MSB = RD_NP_RSP_INFO_WD - 1;
  // Wrap re-order pass thru info width
  localparam RD_NP_RSP_WRAP_INFO_WD  = RD_NP_RSP_INFO_WD - SLV_BURST_LEN_PW - 4;
  // Locate len msb
  localparam RD_NP_RSP_WRAP_INFO_LEN_MSB = RD_NP_RSP_WRAP_INFO_MSB -
                                           RD_NP_RSP_WRAP_INFO_WD;
  // Locate beat offset msb
  localparam RD_NP_RSP_WRAP_INFO_BEAT_OFFSET_MSB = RD_NP_RSP_WRAP_INFO_LEN_MSB -
                                                   SLV_BURST_LEN_PW;
  // Read Channel Pipe Delay: {valid, info, data, last }
  localparam R_CH_INTF_WD = { 1 + RD_NP_RSP_WRAP_INFO_WD + SLV_BUS_DATA_WIDTH + 1 };

  // Number of parity address blocks per 32/64 bit address
  localparam NUM_ADDR_PAR_BLOCKS  = `SLAVE_BUS_ADDR_WIDTH/CX_RAS_PROT_RANGE;
  // Number of parity data blocks for a single dword
  localparam NUM_DATA_PAR_BLOCKS  = `SLAVE_BUS_DATA_WIDTH/CX_RAS_PROT_RANGE;
  localparam RAS_DP_ERR_LOG_WD = $clog2(MAX_RAS_PROT_CHK_N);

  // -------------------------------------------------------------------------------------
  // Wire/Reg
  // -------------------------------------------------------------------------------------
  // DeMux
  wire [RD_NP_RSP_CTL_WD-1:0]                 s_nprspf_rd_ctl;
  wire [RD_NP_RSP_INFO_WD-1:0]                s_nprspf_rd_info;
  wire [RD_NP_RSP_INTF_WD-1:0]                s_nprspf_rd_intf;

  wire [WR_NP_RSP_CTL_WD-1:0]                 s_nprspf_wr_ctl;
  wire [WR_NP_RSP_INFO_WD-1:0]                s_nprspf_wr_info;
  wire [WR_NP_RSP_INTF_WD-1:0]                s_nprspf_wr_intf;

  wire [RD_NP_RSP_INTF_WD-1:0]                dmx_np_rsp_rd_intf;
  wire                                        axalgn_ready;

  wire [WR_NP_RSP_INTF_WD-1:0]                dmx_np_rsp_wr_intf;
  wire                                        wrordr_np_rsp_wr_ready;

  wire [RD_NP_RSP_INFO_WD-1:0]                s_dmx_np_rsp_rd_info;
  wire [RD_NP_RSP_CTL_WD-1:0]                 s_dmx_np_rsp_rd_ctl;
  wire                                        s_dmx_np_rsp_rd_valid;
  wire [SLV_BUS_DATA_WIDTH-1:0]               s_dmx_np_rsp_rd_data;
  wire                                        s_dmx_np_rsp_rd_last;
  wire [SLV_BUS_STRB_PW-1:0]                  s_dmx_np_rsp_rd_addr_low;
  wire [SLV_BURST_LEN_PW-1:0]                 s_dmx_np_rsp_rd_len;
  wire [2:0]                                  s_dmx_np_rsp_rd_size;

  wire [WR_NP_RSP_INFO_WD-1:0]                s_dmx_np_rsp_wr_info;
  wire [WR_NP_RSP_CTL_WD-1:0]                 s_dmx_np_rsp_wr_ctl;
  wire                                        s_dmx_np_rsp_wr_valid_hl;
  wire [`CC_AXIJ_DMWR_VALUE +1:0]             s_dmx_np_rsp_wr_resp;
  wire [SLV_BUS_ID_WIDTH-1:0]                 s_dmx_np_rsp_wr_id;

  // AXI aligner
  wire                                        axalgn_valid;
  wire [RD_NP_RSP_INFO_WD-1:0]                axalgn_info;
  wire [SLV_BUS_DATA_WIDTH-1:0]               axalgn_data;
  wire                                        axalgn_last;
  wire                                        s_axalgn_ready;
  wire                                        wprordr_ready;
  wire                                        pdly1_halt;
  wire                                        s_halt;
  wire                                        s_pdly1_ready;
  wire                                        axalgn_dbi_response;
  wire [RD_NP_RSP_WRAP_INFO_WD-1:0]           s_axalgn_info_wrp;
  wire [SLV_BURST_LEN_PW-1:0]                 s_axalgn_info_len;
  wire [3:0]                                  s_axalgn_info_wrap_beat_offset;
  wire                                        wprordr_rvalid;
  wire [RD_NP_RSP_WRAP_INFO_WD-1:0]           wprordr_info;
  wire                                        wprordr_dbi_response;
  wire [SLV_BUS_DATA_WIDTH-1:0]               wprordr_rdata;
  wire                                        wprordr_rlast;

  // R channel pipe delay
  wire [R_CH_INTF_WD :0]                      s_r_ch_intf;
  wire [R_CH_INTF_WD :0]                      pdly1_r_ch_intf;
  wire [RD_NP_RSP_WRAP_INFO_WD-1:0]           pdly1_info;

  // B Channel sideband info
  wire [WR_NP_RSP_INFO_WD-1:0]                wrordr_rsp_wr_info;

  wire [`CC_AXIJ_DMWR_VALUE +1:0]             serr_np_resp;
  wire [SLV_BUS_DATA_WIDTH-1:0]               serr_np_data;

  wire [1:0]                                  serr_p_resp;

  wire [SLV_BUS_DATA_WIDTH-1:0]               s_srsp_rdata;
  wire                                        s_srsp_valid;
  logic [RD_NP_RSP_WRAP_INFO_WD-1:0]           s_srsp_info;

  reg                                         r_nprspf_valid;
  reg   [MAX_SLV_TAG_PW-1:0]                  r_nprspf_tag;
  reg                                         r_nprspf_to;
  reg                                         r_nprspf_ep;
  reg   [2:0]                                 r_nprspf_tc;
  // DBIindication in
  reg                                         r_dbi_response;
  reg                                         rr_dbi_response;
  reg                                         r_nprspf_ido;
  reg                                         r_nprspf_ns;
  reg                                         r_nprspf_ro;
  reg   [2:0]                                 r_nprspf_status;
  reg                                         r_nprspf_cpl;
  reg   [7:0]                                 r_nprspf_cpl_segment;
  reg   [8:0]                                 r_nprspf_dst_segment;
  reg   [1 :0] r_nprspf_resp;
  reg   [SLV_BUS_DATA_WIDTH-1:0]              r_nprspf_data;
  reg                                         r_nprspf_last;
  reg  [RD_NP_RSP_INTF_WD-1:0]                r_nprspf_rd_intf;
  reg  [WR_NP_RSP_INTF_WD-1:0]                r_nprspf_wr_intf;
  reg                                         r_atm_np_wr;
  reg                                         r_atm_np_atomic;
  wire                                        s_atm_np_wr;

  // -------------------------------------------------------------------------------------
  // Design
  // -------------------------------------------------------------------------------------

  always@(posedge slv_aclk or negedge slv_aresetn) begin
    if(!slv_aresetn)begin
      r_nprspf_valid    <= #TP 1'b0;
      r_nprspf_tag      <= #TP {(MAX_SLV_TAG_PW){1'b0}};
      r_nprspf_to       <= #TP 1'b0;
      r_nprspf_ep       <= #TP 1'b0;
      r_nprspf_tc       <= #TP 3'h0;
      r_dbi_response    <= #TP 1'b0;
      rr_dbi_response   <= #TP 1'b0;
      r_nprspf_ido      <= #TP 1'b0;
      r_nprspf_ns       <= #TP 1'b0;
      r_nprspf_ro       <= #TP 1'b0;
      r_nprspf_status   <= #TP 3'h0;
      r_nprspf_cpl      <= #TP 1'b0;
      r_nprspf_cpl_segment <= #TP '0;
      r_nprspf_dst_segment <= #TP '0;
      r_nprspf_resp     <= #TP 2'h0;
      r_nprspf_data     <= #TP {(SLV_BUS_DATA_WIDTH){1'b0}};
      r_nprspf_last     <= #TP 1'b0;
      r_nprspf_wr_intf  <= #TP {WR_NP_RSP_INTF_WD{1'b0}};
      r_nprspf_rd_intf  <= #TP {RD_NP_RSP_INTF_WD{1'b0}};
      r_atm_np_wr       <= #TP 1'b0;
      r_atm_np_atomic   <= #TP 1'b0;
    end else begin
      if(srsp_np_ready)begin
        r_nprspf_valid    <= #TP nprspf_valid;
        r_nprspf_tag      <= #TP nprspf_tag;
        r_nprspf_to       <= #TP nprspf_to;
        r_nprspf_ep       <= #TP nprspf_ep;
        r_nprspf_tc       <= #TP nprspf_tc;
        r_dbi_response    <= #TP dbi_response;
        rr_dbi_response   <= #TP r_dbi_response;
        r_nprspf_ido      <= #TP nprspf_ido;
        r_nprspf_ns       <= #TP nprspf_ns;
        r_nprspf_ro       <= #TP nprspf_ro;
        r_nprspf_status   <= #TP nprspf_status;
        r_nprspf_cpl      <= #TP nprspf_cpl;
        r_nprspf_cpl_segment <= #TP nprspf_cpl_segment;
        r_nprspf_dst_segment <= #TP nprspf_dst_segment;
        r_nprspf_resp     <= #TP nprspf_resp;
        r_nprspf_data     <= #TP nprspf_data;
        r_nprspf_last     <= #TP nprspf_last;
        r_nprspf_wr_intf  <= #TP s_nprspf_wr_intf;
        r_nprspf_rd_intf  <= #TP s_nprspf_rd_intf;
        r_atm_np_wr       <= #TP atm_np_wr;
        r_atm_np_atomic   <= #TP atm_np_atomic;
      end
    end
  end
  assign srsp_np_tag = r_nprspf_tag;

  // -------------------------------------------------------------------------------------
  // Error response mapping
  // -------------------------------------------------------------------------------------
  DWC_pcie_axi_slv_err_rsp
  
  u_serr
  (
  .cfg_err_resp_mode                       (cfg_err_resp_mode)
  ,.cfg_err_resp_map                       (cfg_err_resp_map)
  ,.atm_np_ven_id_rd                       (atm_np_ven_id_rd)
  ,.nprspf_resp                            (r_nprspf_resp)
  ,.nprspf_status                          (r_nprspf_status)
  ,.nprspf_to                              (r_nprspf_to)
  ,.nprspf_data                            (r_nprspf_data)
  ,.dbi_response                           (r_dbi_response)
  ,.pdcmp_p_rsp_cpl_stat                   (pdcmp_p_rsp_cpl_stat)
  ,.serr_np_resp                           (serr_np_resp)
  ,.serr_np_data                           (serr_np_data)
  ,.serr_p_resp                            (serr_p_resp)
  );

  // -------------------------------------------------------------------------------------
  // AXI tag manager control
  // -------------------------------------------------------------------------------------
  assign srsp_np_tag_recycled = r_nprspf_valid && srsp_np_ready && r_nprspf_last;

  // -------------------------------------------------------------------------------------
  // Pack response interface signals
  // -------------------------------------------------------------------------------------
  // Build non-posted read response interface signals
  // {valid, data, last, addr_low, len, size }
  assign s_nprspf_rd_ctl = { r_nprspf_valid
                           , serr_np_data
                           , r_nprspf_last
                           , atm_np_addr_low
                           , atm_np_len
                           , atm_np_size
                           };

  // Pack sideband info signals
  // {id, resp, to, tc, ns, ro, status, cpl, wrap_beat_offset, func_num, prfx, ln, idunq}
  assign s_nprspf_rd_info = { atm_np_id           // SLV_BUS_ID_WIDTH
                            , serr_np_resp[1:0]   // 2
                            , r_nprspf_to         // 1
                            , r_nprspf_ep         // 1
                            , r_nprspf_tc         // 3
                            , r_nprspf_ido        // 1
                            , r_nprspf_ns         // 1
                            , r_nprspf_ro         // 1
                            , r_nprspf_status     // 3
                            , r_nprspf_cpl        // 1
                            , r_nprspf_cpl_segment   // 8
                            , r_nprspf_dst_segment  // 9
                            , atm_np_len       // SLV_BURST_LEN_PW
                            , atm_np_wrap_beat_offset // 4
                            };

  assign s_nprspf_rd_intf = {s_nprspf_rd_ctl, s_nprspf_rd_info};

  // Build non-posted write response interface signals
  assign s_nprspf_wr_ctl = { r_nprspf_valid
                           , atm_np_id
                           , serr_np_resp
                           };

  assign s_nprspf_wr_info = { r_nprspf_to         // 1
                            , r_nprspf_ep         // 1
                            , r_nprspf_tc         // 3
                            , r_nprspf_ns         // 1
                            , r_nprspf_ro         // 1
                            , r_nprspf_status     // 3
                            , r_nprspf_cpl        // 1
                            , r_nprspf_cpl_segment   // 8
                            , r_nprspf_dst_segment  // 9
                            };

  assign s_nprspf_wr_intf = {s_nprspf_wr_ctl, s_nprspf_wr_info};

  // -------------------------------------------------------------------------------------
  // Demux response to Read or Write response channels
  // -------------------------------------------------------------------------------------

  //
  // For atomic operations the read response data need to flow to AXI R channel. B response
  // pulse has already been scheduled/generated upon request on Client 1 interface, thus
  // demux logic must convey data into R channel and filter B-response channel.
  //
  assign s_atm_np_wr = r_atm_np_wr && !r_atm_np_atomic;

  DWC_pcie_bridge_intf_demux
  
  #(.INTF_WD_A                               (WR_NP_RSP_INTF_WD)
   ,.INTF_WD_B                               (RD_NP_RSP_INTF_WD)
  )
  u_dmx
  (
  // Serial interface
  .intf_a                                  (r_nprspf_wr_intf)
  ,.intf_b                                 (r_nprspf_rd_intf)
  ,.dmx_ready                              (srsp_np_ready)
  // Interface A (Non-Posted write response)
  ,.sel_a                                  (s_atm_np_wr)
  ,.dmx_intf_a                             (dmx_np_rsp_wr_intf)
  ,.ready_a                                (wrordr_np_rsp_wr_ready)
  // Interface B (Non-posted read response)
  ,.dmx_intf_b                             (dmx_np_rsp_rd_intf)
  ,.ready_b                                (axalgn_ready)
  );


  assign {s_dmx_np_rsp_rd_ctl, s_dmx_np_rsp_rd_info } = dmx_np_rsp_rd_intf;
  assign {s_dmx_np_rsp_wr_ctl, s_dmx_np_rsp_wr_info } = dmx_np_rsp_wr_intf;

  // -------------------------------------------------------------------------------------
  // Instantiate AXI Size Alignment block
  // -------------------------------------------------------------------------------------
  // {valid, data, last, addr_low, len, size }
  assign { s_dmx_np_rsp_rd_valid
         , s_dmx_np_rsp_rd_data
         , s_dmx_np_rsp_rd_last
         , s_dmx_np_rsp_rd_addr_low
         , s_dmx_np_rsp_rd_len
         , s_dmx_np_rsp_rd_size
         } = s_dmx_np_rsp_rd_ctl;

   DWC_pcie_dunalign
   
  #(
   .PW                                     (RD_NP_RSP_INFO_WD + 1) // INTF info + DBI resp
   ,.AXI_ADDR_OFSET_WD                      (SLV_BUS_STRB_PW)
   ,.BW                                     (SLV_BURST_LEN_PW)
   ,.SW                                     (3)
   ,.AXI_DBUS_WD                            (SLV_BUS_DATA_WIDTH)
   ,.NS                                     (SLV_BUS_STRB_WIDTH)
   ,.LS                                     (SLV_BUS_STRB_PW)
   )
   u_axalgn
   (
   .clk               (slv_aclk),
   .rst_n             (slv_aresetn),
   .init_n            (1'b1),
   // Dword aligned interface
   .data_vld_in       (s_dmx_np_rsp_rd_valid),
   .params_in         ({s_dmx_np_rsp_rd_info, rr_dbi_response}),
   .data_last_in      (s_dmx_np_rsp_rd_last),
   .addr_in           (s_dmx_np_rsp_rd_addr_low),
   .burst_len_in      (s_dmx_np_rsp_rd_len),
   .size_in           (s_dmx_np_rsp_rd_size),
   .data_in           (s_dmx_np_rsp_rd_data),
   .data_rdy_out      (axalgn_ready),
   // AXI aligned interface
   .data_vld_out      (axalgn_valid),
   .params_out        ({axalgn_info, axalgn_dbi_response}),
   .data_last_out     (axalgn_last),
   .data_out          (axalgn_data),
   .data_rdy_in       (s_axalgn_ready),
   .resp_in_progress  ()
   );
  // -------------------------------------------------------------------------------------
  // Wrap Reordering
  // -------------------------------------------------------------------------------------
  // Extract AXI aligner info
  // {id, resp, to, tc, ns, ro, status, cpl, func_num, prfx, idunq}
  assign s_axalgn_info_wrp  = axalgn_info[RD_NP_RSP_WRAP_INFO_MSB -:
                                          RD_NP_RSP_WRAP_INFO_WD];
  assign s_axalgn_info_len  = axalgn_info[RD_NP_RSP_WRAP_INFO_LEN_MSB -:
                                          SLV_BURST_LEN_PW];
  assign s_axalgn_info_wrap_beat_offset = axalgn_info[RD_NP_RSP_WRAP_INFO_BEAT_OFFSET_MSB -: 4];

  DWC_pcie_axi_slv_rsp_wrp
  
 #(
  .SLV_BUS_DATA_WIDTH                     (SLV_BUS_DATA_WIDTH)
  ,.SLV_BURST_LEN_PW                       (SLV_BURST_LEN_PW)
  ,.RD_NP_RSP_WRAP_INFO_WD                 (RD_NP_RSP_WRAP_INFO_WD+1) // dbi response info
  ,.SLV_WRP_RSP_ROB_FIFO_DP                 (SLV_WRP_RSP_ROB_FIFO_DP)
  ,.SLV_WRP_RSP_ROB_FIFO_ADDR_WD            (SLV_WRP_RSP_ROB_FIFO_ADDR_WD)
  )
  u_wprordr
  (
   .slv_aclk                               (slv_aclk)
  ,.slv_aresetn                            (slv_aresetn)
  // AXI aligned response interface
  ,.axalgn_valid                           (axalgn_valid)
  ,.axalgn_info                            ({s_axalgn_info_wrp, axalgn_dbi_response})
  ,.axalgn_info_wrap_beat_offset           (s_axalgn_info_wrap_beat_offset)
  ,.axalgn_info_len                        (s_axalgn_info_len)
  ,.axalgn_data                            (axalgn_data)
  ,.axalgn_last                            (axalgn_last)
  ,.wprordr_ready                          (wprordr_ready)
  // Wrap response interface
  ,.wprordr_rvalid                         (wprordr_rvalid)
  ,.wprordr_info                           ({wprordr_info,wprordr_dbi_response})
  ,.wprordr_rdata                          (wprordr_rdata)
  ,.wprordr_rlast                          (wprordr_rlast)
  ,.pdly1_rready                           (s_pdly1_ready)
  );

  assign s_axalgn_ready = wprordr_ready;
  assign s_srsp_rdata = wprordr_rdata;
  assign s_srsp_valid = wprordr_rvalid;

  always_comb begin: proc_comb_srspinfo
    s_srsp_info = wprordr_info;
    // Completions Status during DPC
    s_srsp_info[(RD_NP_RSP_WRAP_INFO_WD-1)-SLV_BUS_ID_WIDTH-9 -1:(RD_NP_RSP_WRAP_INFO_WD-1)-SLV_BUS_ID_WIDTH-11 -1] = (cdc_core_in_dpc_i && wprordr_info[(RD_NP_RSP_WRAP_INFO_WD-1)-SLV_BUS_ID_WIDTH-2]) ? (qst_cfg_dpc_cpl_cntrl_i ? `UR_CPL_STATUS : `CA_CPL_STATUS) : wprordr_info[(RD_NP_RSP_WRAP_INFO_WD-1)-SLV_BUS_ID_WIDTH-9 -1:(RD_NP_RSP_WRAP_INFO_WD-1)-SLV_BUS_ID_WIDTH-11 -1];
  end: proc_comb_srspinfo


  assign s_r_ch_intf  = { wprordr_rvalid
                        , s_srsp_info
                        , s_srsp_rdata
                        , wprordr_rlast && wprordr_rvalid
                        , wprordr_dbi_response
                        };

  assign s_pdly1_ready = !pdly1_halt;


   wire                                       rdata_chk_en;
   assign rdata_chk_en = s_srsp_valid & s_pdly1_ready;

  ras_dp_pipe
   #(
    .PIPELINE_TYPE             (0                              ),
    .RESETVAL                  (0                              ),
    .N_STAGES                  (0                              ),
    .CAN_STALL                 (0                              ),
    .RESET_STALL               (0                              ),
    .BUS_PROTECT_GEN_EN        (0                              ),
    .BUS_PROTECT_CHK_EN        (1                              ),
    .PROT_TYPE                 (1                              ),
    .PROT_RANGE                (CX_RAS_PROT_RANGE              ),
    .PROT_WD                   (NUM_DATA_PAR_BLOCKS            ),
    .PARITY_MODE               (CX_RAS_PARITY_MODE             ),
    .PROT_CORRECT_EN           (0                              ),
    .TOTAL_WIDTH               (`SLAVE_BUS_DATA_WIDTH          ),
    .EXCLUDE_PROT_WIDTH        (0                              ),
    .RAS_DP_PROT_CHK_ID_BASE   (`SRSP_RSLV_DT_RAS_ID           )
  ) u_rdata_chk (
    .clk                       ( slv_aclk                      ),
    .rst_n                     ( slv_aresetn                   ),
    .din                       ( fn_data_wo_par (s_srsp_rdata) ),
    .din_prot                  ( fn_prot_chkin_d(s_srsp_rdata) ),
    .dout                      ( /* Not Connected */           ),
    .dout_prot                 ( /* Not Connected */           ),
    .en                        (1'b1                           ),
    .bypass                    (1'b0                           ),
    .stall                     (1'b0                           ),
    .stallout                  ( /* Not Connected */           ),
    .valid_in                  ( rdata_chk_en                  ),
    .halt_out                  ( /* Not Connected */           ),
    .valid_out                 ( /* Not Connected */           ),
    .halt_in                   (1'b0                           ),
    .ras_dp_err_inband_kbd_in  (1'b0                           ),
    .ras_dp_err_inband_kbd_out ( /* Not Connected */           ),
    .ras_dp_err_log            ( srsp_rslv_dt_ras_dp_err_log   )
      ,
      .ras_dp_err_inj          (ras_dp_err_inj_slv_aclk)
    );

   assign srsp_ras_par_rslv_dt_pulse = srsp_rslv_dt_ras_dp_err_log.valid;
 // Instantiate Pipe Delay
  delay_1_w_stalling
  
  #(.DELAY_EN                              (1)
   ,.WD                                    (R_CH_INTF_WD+1)
   ,.CAN_STALL                             (1)
  )
  u_pdly1
  (
    .clk        (slv_aclk),
    .rst_n      (slv_aresetn),
    .clear      (1'b0),
    .din        (s_r_ch_intf),
    .stallout   (pdly1_halt),
    .dout       (pdly1_r_ch_intf),
    .stall      (s_halt)
  );

  // Assign outputs
  assign { srsp_rvalid
         , pdly1_info
         , srsp_rdata
         , srsp_rlast
         , dbi_response_rd
         } = pdly1_r_ch_intf;
  // {id, resp, to, ep, tc, ns, ro, status, cpl, func_num, prfx }
  assign { srsp_rid
         , srsp_rresp
         , srsp_rto
         , srsp_rep
         , srsp_rtc
         , srsp_rido
         , srsp_rns
         , srsp_rro
         , srsp_rstatus
         , srsp_rcpl
         , srsp_rcpl_segment
         , srsp_rdst_segment
         } = pdly1_info;

  // Pipe delay halt
  assign s_halt = srsp_rvalid && !rready;

  // -------------------------------------------------------------------------------------
  // Instantiate Write Response Re-orderer
  // -------------------------------------------------------------------------------------
  // {valid, id, resp}
  assign { s_dmx_np_rsp_wr_valid_hl
         , s_dmx_np_rsp_wr_id
         , s_dmx_np_rsp_wr_resp } = s_dmx_np_rsp_wr_ctl;

  DWC_pcie_axi_slv_wr_rsp_ordr
  
 #(.SLV_NUM_OUTSTND_WR_REQ                (SLV_NUM_OUTSTND_WR_REQ)
  ,.SLV_NUM_OUTSTND_WR_REQ_LOG2           (SLV_NUM_OUTSTND_WR_REQ_LOG2)
  ,.SLV_BUS_ID_WIDTH                      (SLV_BUS_ID_WIDTH)
  ,.WR_NP_RSP_INFO_WD                     (WR_NP_RSP_INFO_WD)
  ,.NFUNC_WD                              (NFUNC_WD)
  )
  u_wrordr
  (.slv_aclk                               (slv_aclk)
  ,.slv_aresetn                            (slv_aresetn)
  // AXI write request info
  ,.srq_wr_valid_hl                        (swrq_wr_valid_hl)
  ,.srq_wr_id                              (swrq_wr_id)
  ,.srq_wr_p                               (swrq_wr_p)
  ,.srq_wr_np                              (swrq_wr_np)
  ,.srq_wr_np_atomic                       (swrq_wr_np_atomic)
  ,.srq_wr_last_null_writes                (swrq_wr_last_null_writes)
  // De-muxed non-posted write response info
  ,.dmx_np_rsp_wr_valid_hl                 (s_dmx_np_rsp_wr_valid_hl)
  ,.dmx_np_rsp_wr_info                     (s_dmx_np_rsp_wr_info)
  ,.dmx_np_rsp_wr_id                       (s_dmx_np_rsp_wr_id)
  ,.dmx_np_rsp_wr_status                   (s_dmx_np_rsp_wr_resp)
  ,.wrordr_np_rsp_wr_ready                 (wrordr_np_rsp_wr_ready)
  // dbi indication for the np response
  ,.dbi_response                           (rr_dbi_response)
  // Decomposer posted response
  ,.pdcmp_p_rsp_valid_hl                   (pdcmp_p_rsp_valid_hl)
  ,.pdcmp_p_rsp_id                         (pdcmp_p_rsp_id)
  ,.pdcmp_p_rsp_cpl_stat                   (pdcmp_p_rsp_cpl_stat)
  ,.serr_p_resp                            (serr_p_resp)
  // Decomposer non posted response
  ,.npdcmp_np_atomic_rsp_valid_hl          (npdcmp_np_atomic_rsp_valid_hl)
  ,.npdcmp_np_atomic_rsp_id                (npdcmp_np_atomic_rsp_id)
  // AXI write response
  ,.wrordr_bvalid_hl                       (srsp_bvalid_hl)
  ,.wrordr_bid                             (srsp_bid)
  ,.wrordr_bresp                           (srsp_bresp)
  ,.wrordr_bmisc_info                      (wrordr_rsp_wr_info)
  ,.wrordr_dbi_response                    (dbi_response_wr)
  ,.bready                                 (bready)
  // Completions Status during DPC
  ,.cdc_core_in_dpc_i                      (cdc_core_in_dpc_i      )
  ,.qst_cfg_dpc_cpl_cntrl_i                (qst_cfg_dpc_cpl_cntrl_i)
  );

  // {to, ep, tc, ns, ro, status, cpl, func_num, prfx }
  assign { srsp_bto
         , srsp_bep
         , srsp_btc
         , srsp_bns
         , srsp_bro
         , srsp_bstatus
         , srsp_bcpl
         , srsp_bcpl_segment
         , srsp_bdst_segment
         } = wrordr_rsp_wr_info;

  // -------------------------------------------------------------------------------------
  // Functions
  // -------------------------------------------------------------------------------------
  function automatic [NUM_DATA_PAR_BLOCKS-1:0] fn_prot_chkin_d;
    input [SLV_BUS_DATA_WIDTH-1:0] s_data_w_par;
    integer i;
    begin
      for (i=0; i<NUM_DATA_PAR_BLOCKS; i=i+1) begin
        fn_prot_chkin_d[i] = s_data_w_par[i*CX_RAS_PROT_RANGE + i + CX_RAS_PROT_RANGE];
      end
    end
  endfunction

  function automatic [SLV_BUS_DATA_WIDTH-NUM_DATA_PAR_BLOCKS-1:0] fn_data_wo_par;
    input [SLV_BUS_DATA_WIDTH-1:0] s_data_w_par;
    integer i,j;
    begin
      for (i=0; i<NUM_DATA_PAR_BLOCKS; i=i+1)  begin // interate thru parity block size
       for (j=0; j<CX_RAS_PROT_RANGE; j=j+1)  begin // interate thru parity block size bits
          fn_data_wo_par[i*CX_RAS_PROT_RANGE +j] = s_data_w_par[i*CX_RAS_PROT_RANGE +j +i];
        end
      end
    end
  endfunction
`ifndef SYNTHESIS

`endif //  `ifndef SYNTHESIS


endmodule
