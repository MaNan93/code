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
// ---    $DateTime: 2023/04/29 12:35:01 $
// ---    $Revision: #12 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Amba/mstr_cpl_buf/DWC_pcie_amba_mstr_cpl_formation.sv#12 $
// -------------------------------------------------------------------------
// Module Description:
//
// ---------------------------------------------------------------------------------------
// ---------------------------------------------------------------------------------------
// Macro's
// ---------------------------------------------------------------------------------------
// RESP[0]                   __________________
// RESP[1]                   _________________ |
// WR_NOT_RD                 ________________ ||
// NP_NOT_P                  _______________ |||
//                                          ||||
`define H_P                              4'b0???
`define H_NP_OKAY                        4'b1?00
`define H_NP_RD_ERROR_TO_CA              4'b1001
`define H_NP_WR_ERROR_TO_CA              4'b1101

`define X_P                              4'b0???
`define X_NP_OKAY                        4'b1?00
`define X_NP_RD_SLVERR_TO_CA             4'b1010
`define X_NP_RD_DECERR_TO_CA             4'b1011
`define X_NP_WR_SLVERR_TO_CA             4'b1110
`define X_NP_WR_DECERR_TO_CA             4'b1111

`include "include/DWC_pcie_ctl_all_defs.svh"


 module DWC_pcie_amba_mstr_cpl_formation
 #(
  // -------------------------------------------------------------------------------------
  // Parameters modified by an instantiation parameter assignment
  // -------------------------------------------------------------------------------------
  parameter AXI_ENABLED                      = 1,
  parameter CC_MAX_MSTR_TAGS                 = 8,
  parameter CC_MAX_MSTR_TAG_PW               = 3,
  parameter CX_REMOTE_MAX_TAGS               = 8,
  parameter CX_REMOTE_MAX_TAGS_WD            = 3,
  parameter CC_MSTR_CPL_SEG_DATA_WD          = 32,
  parameter CC_MSTR_CPL_SEG_DATA_NUM_DWORDS  = 1,
  parameter CC_MSTR_CPL_SEG_DATA_NUM_BYTES   = 4,
  parameter CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2 = 16,
  parameter CC_MSTR_RSP_DATA_WD              = 64,
  parameter CC_MSTR_CPL_DATA_WD              = 128,
  parameter NP_REQ_ACTIVE_IDS_VEC            = 24,
  parameter NP_REQ_START_LOW_ADDR_VEC        = 32,
  // -------------------------------------------------------------------------------------
  // Parameters not modified by an instantiation parameter assignment
  // -------------------------------------------------------------------------------------
  parameter TP                               = `TP
 )
 
                                         (
  // -------------------------------------------------------------------------------------
  // Clocks and resets
  // -------------------------------------------------------------------------------------
  // core_clk: PCIe core clock
  // core_rst_n: Active low PCIe core reset
  input                                              core_clk,
  input                                              core_rst_n,
  // -------------------------------------------------------------------------------------
  // Flush interface
  input                                              rstctl_mstr_flush_req,
  // -------------------------------------------------------------------------------------
  // Master non-posted request information interface
  // -------------------------------------------------------------------------------------
  // radmx_mreq_np_valid: Indicates inbound AMBA request information is valid.
  // radmx_mreq_np_id: Inbound master request ID, validated by radmx_mreq_np_valid.
  // radmx_ireq_np_lookup_id: Inbound non-posted request lookup ID
  //                          (TRGT CPL LUT always populated).
  input                                              radmx_mreq_np_valid,
  input       [CC_MAX_MSTR_TAG_PW-1:0]               radmx_mreq_np_id,
  input                                              radmx_ireq_np_ncbe,
  input       [CX_REMOTE_MAX_TAGS_WD-1:0]            radmx_ireq_np_lookup_id,
  input       [`DC_MCB_MAX_CPL_NUM_BYTES_WD-2:0]     radmx_ireq_np_4kb_start_addr,
  // -------------------------------------------------------------------------------------
  // Master response active info interface
  // -------------------------------------------------------------------------------------
  // -------------------------------------------------------------------------------------
  // Master response interface
  // -------------------------------------------------------------------------------------
  // svalid: Master response packet data valid
  // sid: Master response packet ID, updated when svalid asserted.
  // byte_en: Master response packet byte enables
  // sdata: Master response packet data
  // sresp_status: Master response packet status
  // smisc_info_cpl_stat: Master completion status selection Misc Info
  // sresp_wr_not_rd: Write(1) or Read master response (0) indication
  // sresp_np_not_p: Non-posted(1) or Posted(0) mster response indication
  // smisc_info_ep: Active high poisoned data beat indication
  // smisc_info_tc: Traffic Class data beat indication
  // smisc_info_bad_eot: Active high bad eot indication, valid on any beat
  // slast: Master response packet, last beat indication
  // mcf_ready: Master response packet halt
  input                                              svalid,
  input       [CC_MAX_MSTR_TAG_PW-1:0]               sid,
  input       [CC_MSTR_CPL_SEG_DATA_NUM_BYTES-1:0]   sbyte_en,
  input       [CC_MSTR_CPL_SEG_DATA_WD-1:0]          sdata,
  input       [`DC_SRESP_WD-1:0]                     sresp_status,
  input       [`DC_CPL_STATUS_WD-1:0]                smisc_info_cpl_stat,
  input                                              sresp_wr_not_rd,
  input                                              sresp_np_not_p,
  input                                              smisc_info_ep,
  input       [`DC_TC_WD-1:0]                        smisc_info_tc,
  input                                              smisc_info_bad_eot,
  input                                              slast,
  output wire                                        mcf_ready,
  // -------------------------------------------------------------------------------------
  // Master response tracker interface
  // -------------------------------------------------------------------------------------
  input       [CC_MAX_MSTR_TAGS-1:0]                 mrtrk_last_pkt,
  input                                              mrtrk_atomic_id,
  input                                              mrtrk_atomic_all_rsp,
  // -------------------------------------------------------------------------------------
  // PCIe master completion interface
  // -------------------------------------------------------------------------------------
  // mcf_hv: Master completion header valid
  // mcf_dv: Master completion data valid
  // mcf_eot: Master completion end of transfer
  // mcf_ep: Master completion poisoned data indication
  // mcf_bad_eot: Master completion bad eot indication
  // mcf_tc: Master completion Traffic Class data indication
  // mcf_dwen: Master completion data word enable
  // mcf_data: Master completion data
  // mcf_error: Master completion error indication
  // mcctl_halt: Master completion halt, active high.
  output wire                                        mcf_hv,
  output wire                                        mcf_dv,
  output wire [CX_REMOTE_MAX_TAGS_WD-1:0]            mcf_wr_seg_num,
  output wire [CC_MSTR_CPL_SEG_DATA_NUM_DWORDS-1:0]  mcf_dw_en,
  output wire [CC_MSTR_CPL_SEG_DATA_WD-1:0]          mcf_data,
  output wire                                        mcf_ep,
  output wire [`DC_TC_WD-1:0]                        mcf_tc,
  output wire                                        mcf_bad_eot,
  output wire [`DC_CPL_STATUS_WD-1:0]                mcf_status,
  output wire                                        mcf_error,
  output wire                                        mcf_last_pkt_beat,
  output wire                                        mcf_eot,
  output                                             mcf_atop_wr_rsp,
  output                                             mcf_atop_cpl_queue,
  input                                              mcctl_halt
 );
  // -------------------------------------------------------------------------------------
  // Local parameter
  // -------------------------------------------------------------------------------------
  localparam SRESP_INFO_WD = 4; // {np_not_p, wr_not_rd, status}

  // Define FSM states
  localparam ST_RSP_IDLE = 1'b0;
  localparam ST_RESP_MULTI_BEAT = 1'b1;

  // -------------------------------------------------------------------------------------
  // Internal wire/reg
  // -------------------------------------------------------------------------------------

  reg  [CX_REMOTE_MAX_TAGS_WD-1:0]                  r_wr_seg_num_ary
                                                    [CC_MAX_MSTR_TAGS-1:0];
  logic [CX_REMOTE_MAX_TAGS_WD-1:0]                 s_wr_seg_num, r_wr_seg_num;

  reg  [CX_REMOTE_MAX_TAGS-1:0]                     s_np_req_active;

  reg  [CX_REMOTE_MAX_TAGS-1:0]                     r_np_req_active;

  reg  [CC_MAX_MSTR_TAG_PW-1:0]                     s_np_req_id_ary
                                                    [CX_REMOTE_MAX_TAGS-1:0];
  reg  [CC_MAX_MSTR_TAG_PW-1:0]                     r_np_req_id_ary
                                                    [CX_REMOTE_MAX_TAGS-1:0];
  reg  [NP_REQ_ACTIVE_IDS_VEC-1:0]                  s_np_req_id_vec;

  reg  [CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2-1:0]    s_np_req_start_low_addr_ary
                                                    [CX_REMOTE_MAX_TAGS-1:0];
  reg  [CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2-1:0]    r_np_req_start_low_addr_ary
                                                    [CX_REMOTE_MAX_TAGS-1:0];
  reg  [NP_REQ_START_LOW_ADDR_VEC-1:0]              s_np_req_start_low_addr_vec;

  wire [CX_REMOTE_MAX_TAGS-1:0]                     mcf_np_req_active;
  wire [NP_REQ_ACTIVE_IDS_VEC-1:0]                  mcf_np_req_id;
  wire [NP_REQ_START_LOW_ADDR_VEC-1:0]              mcf_np_req_start_low_addr;

  // AHB: CC_MAX_MSTR_TAGS = 2
  // AXI: CC_MAX_MSTR_TAGS = 2 4 8 16 32 64 128 256
  wire [SRESP_INFO_WD-1:0] s_sresp_info;
  reg  [`DC_CPL_STATUS_WD-1:0] s_cpl_status;
  reg s_cpl_ca;
  reg s_cpl_ur;
  reg s_resp_posted;
  // Define FSM per response ID
  reg [CX_REMOTE_MAX_TAGS-1:0]               s_resp2cpl_fsm_ary;
  reg [CX_REMOTE_MAX_TAGS-1:0]               r_resp2cpl_fsm_ary;

  wire slast_pkt_beat;

  reg s_cpl_hv;
  reg s_cpl_dv;
  reg s_cpl_eot;
  reg s_cpl_last_pkt_beat;
  reg s_ready;

  wire                                       s_smisc_info_ep;
  wire                                       s_smisc_info_bad_eot;
  reg [`DC_CPL_STATUS_WD-1:0]                r_cpl_status_ary
                                             [CX_REMOTE_MAX_TAGS-1:0];
  reg [CX_REMOTE_MAX_TAGS-1:0]               r_cpl_error_ary;
  reg [CX_REMOTE_MAX_TAGS-1:0]               r_smisc_info_ep_ary;
  reg [CX_REMOTE_MAX_TAGS-1:0]               r_smisc_info_bad_eot_ary;
  reg [CX_REMOTE_MAX_TAGS-1:0]               r_first_cpl_ca_det_ary;
  reg [CX_REMOTE_MAX_TAGS-1:0]               r_first_cpl_ur_det_ary;
  reg [CX_REMOTE_MAX_TAGS-1:0]               r_first_cpl_mrs_det_ary;
  reg [CX_REMOTE_MAX_TAGS-1:0]               r_first_ep_det_ary;
  reg [CX_REMOTE_MAX_TAGS-1:0]               r_first_bad_eot_det_ary;

  wire                                       s_svalid;

  wire [CC_MSTR_CPL_SEG_DATA_NUM_BYTES-1:0]  s_sbyte_en;

  wire [`DC_SRESP_WD-1:0]                    s_sresp_status;

  logic [CX_REMOTE_MAX_TAGS-1:0][CC_MAX_MSTR_TAG_PW-1:0]                  s_np_req_id_vec_sliced             ;
  logic [CX_REMOTE_MAX_TAGS-1:0][CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2-1:0] s_np_req_start_low_addr_vec_sliced ;
  logic                                      s_atop_wr_rsp;

  // -------------------------------------------------------------------------------------
  // Internal design
  // -------------------------------------------------------------------------------------

  // -------------------------------------------------------------------------------------
  // Write Segment Information
  // -------------------------------------------------------------------------------------
  // Allow of different AMBA and RTRGT1 lookup ID's.
  // The AMBA ID is mapped to the lookup ID.
  // The lookup ID points the write data segment, i.e. the lookup ID indicates the
  // write segment number.
  always @(posedge core_clk or negedge core_rst_n) begin : proc_seq_wr_seg_num_ary
    integer i;
    if (!core_rst_n) begin
      for (i=0; i<CC_MAX_MSTR_TAGS; i=i+1) begin
        r_wr_seg_num_ary[i] <= # TP {CX_REMOTE_MAX_TAGS_WD{1'b0}};
      end
    end else begin
      for (i=0; i<CC_MAX_MSTR_TAGS; i=i+1) begin
       if (radmx_mreq_np_valid && (i==radmx_mreq_np_id)) begin
         r_wr_seg_num_ary[i] <= # TP radmx_ireq_np_lookup_id;
       end
      end
    end
  end

  // Extract write segment number
  assign s_wr_seg_num = r_wr_seg_num_ary[sid];

  // -------------------------------------------------------------------------------------
  // Generate active PCIe non-posted transaction flag
  // Used to enable the per segment master response up converter.
  // Static flag, synchronisation to AMBA clock domain not required.
  // -------------------------------------------------------------------------------------
  generate
    if (CC_MSTR_RSP_DATA_WD < CC_MSTR_CPL_DATA_WD) begin : gen_np_req_active_info
      always @(*) begin : proc_comb_np_req_active
      integer i;
        // Initialise
        s_np_req_active = r_np_req_active;
        for (i=0; i<CX_REMOTE_MAX_TAGS; i=i+1) begin
           s_np_req_id_ary[i] = r_np_req_id_ary[i];
           s_np_req_start_low_addr_ary[i] = r_np_req_start_low_addr_ary[i];
        end

        for (i=0; i<CX_REMOTE_MAX_TAGS; i=i+1) begin
          // Clear active PCIe non-posted request
          if (mrtrk_last_pkt[sid] && svalid && slast && sresp_np_not_p && (i==s_wr_seg_num)) begin
            if (mrtrk_atomic_id) begin
              if (mcf_atop_cpl_queue) begin
                s_np_req_active[i] = 1'b0;
              end
            end else begin
              s_np_req_active[i] = 1'b0;
            end
          end
          // Set active PCIe non-posted request flag when ID popped from
          // master free ID pool.
          if (radmx_mreq_np_valid && (i==radmx_ireq_np_lookup_id)) begin
            s_np_req_active[i] = 1'b1;
            // Set active non-posted ID
            s_np_req_id_ary[i] = radmx_mreq_np_id;

            if (radmx_ireq_np_ncbe) begin
              // If NCBE transfer then expect the first byte in the upper master response
              // data byte position
              s_np_req_start_low_addr_ary[i] = {CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2{1'b1}};
            end else begin
              s_np_req_start_low_addr_ary[i] =
                radmx_ireq_np_4kb_start_addr[CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2-1:0];
            end
          end
        end
      end

      always @(posedge core_clk or negedge core_rst_n) begin : proc_seq_np_req_active_info
        integer i;
        if (!core_rst_n) begin
          r_np_req_active <= # TP {CX_REMOTE_MAX_TAGS{1'b0}};
          for (i=0; i<CX_REMOTE_MAX_TAGS; i=i+1) begin
             r_np_req_id_ary[i] <= # TP {CC_MAX_MSTR_TAG_PW{1'b0}};
             r_np_req_start_low_addr_ary[i] <= # TP {CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2{1'b0}};
          end
        end else begin
          r_np_req_active <= # TP s_np_req_active;
          for (i=0; i<CX_REMOTE_MAX_TAGS; i=i+1) begin
             r_np_req_id_ary[i] <= # TP s_np_req_id_ary[i];
             r_np_req_start_low_addr_ary[i] <= # TP s_np_req_start_low_addr_ary[i];
          end
        end
      end

      assign s_np_req_id_vec = s_np_req_id_vec_sliced ;
      assign s_np_req_start_low_addr_vec = s_np_req_start_low_addr_vec_sliced ;

      // Build vector of active ID's and low start addresses
      always_comb begin : proc_comb_np_req_id_vec
        foreach (s_np_req_id_vec_sliced[i]) begin
          s_np_req_id_vec_sliced[i] = r_np_req_id_ary[i];
        end
      end
      always_comb begin : proc_comb_np_req_start_low_addr_vec
        foreach (s_np_req_start_low_addr_vec_sliced[i]) begin
          s_np_req_start_low_addr_vec_sliced[i] = r_np_req_start_low_addr_ary[i];
        end
      end

      assign mcf_np_req_active = r_np_req_active;
      assign mcf_np_req_id = s_np_req_id_vec;
      assign mcf_np_req_start_low_addr = s_np_req_start_low_addr_vec;

    end
  endgenerate


  // -------------------------------------------------------------------------------------
  // Translate master response status to PCIe response status
  // -------------------------------------------------------------------------------------
  generate
    if (AXI_ENABLED) begin : GEN_AXI
      // If flush request asserted then sink outstanding responses and return an error completion.
      assign s_sresp_status = rstctl_mstr_flush_req ? 2'b10 : sresp_status;
      assign s_sresp_info = {sresp_np_not_p,
                             sresp_wr_not_rd,
                             s_sresp_status};

      always @(*) begin : proc_comb_axi_to_pcie_resp_map
        integer i;
        // Initialise
        s_resp_posted = 1'b0;
        s_cpl_ca      = 1'b0;
        s_cpl_ur      = 1'b0;
        s_cpl_status = `SU_CPL_STATUS;
        // Map AXI response to PCIe CPL status
        casez (s_sresp_info)
          `X_NP_OKAY : begin
            s_cpl_status = smisc_info_cpl_stat;
            s_cpl_ca     = smisc_info_cpl_stat == `CA_CPL_STATUS;
            s_cpl_ur     = smisc_info_cpl_stat == `UR_CPL_STATUS;
/*
            case(smisc_info_cpl_stat)
              2'b00: begin
                s_cpl_status = `SU_CPL_STATUS;
              end
              2'b01: begin
                s_cpl_status = `CA_CPL_STATUS;
                s_cpl_ca     = 1'b1;
              end
              2'b10: begin
                s_cpl_status = `UR_CPL_STATUS;
                s_cpl_ur     = 1'b1;
              end
              default: begin
                s_cpl_status = `SU_CPL_STATUS;
              end
            endcase
*/
          end
          `X_P : begin
                s_cpl_status = `SU_CPL_STATUS; // pass through
            s_resp_posted = 1'b1; // set posted completion flag
          end
          `X_NP_RD_SLVERR_TO_CA, `X_NP_RD_DECERR_TO_CA,
          `X_NP_WR_SLVERR_TO_CA, `X_NP_WR_DECERR_TO_CA : begin
            s_cpl_status = `CA_CPL_STATUS;
            s_cpl_ca     = 1'b1;
          end
        endcase
      end
    end
  endgenerate
  // -------------------------------------------------------------------------------------
  // Master Response to PCIe protocol conversion FSM
  // -------------------------------------------------------------------------------------
  // FSM combinational

  assign slast_pkt_beat = mrtrk_last_pkt[sid];

  always @(*) begin : proc_comb_resp2cpl_fsm
    // Initialise
    s_cpl_hv = 1'b0;
    s_cpl_dv = 1'b0;
    s_cpl_eot = 1'b0;
    s_cpl_last_pkt_beat = 1'b0;
    s_resp2cpl_fsm_ary = r_resp2cpl_fsm_ary;
    s_atop_wr_rsp = 1'b0;

    case (r_resp2cpl_fsm_ary[s_wr_seg_num])
      ST_RSP_IDLE : begin
        if (!mcctl_halt) begin // Drive outputs to default values when halted
          if (!s_resp_posted) begin // Discard posted response packets
            s_cpl_hv = svalid;
            s_cpl_dv = svalid;
            s_atop_wr_rsp = (mrtrk_atomic_id && sresp_wr_not_rd);
            if (svalid && slast) begin
              s_cpl_eot = 1'b1;
              s_cpl_last_pkt_beat = slast_pkt_beat;
            end
            // Detect multi-beat response
            if (svalid && !slast) begin
              s_resp2cpl_fsm_ary[s_wr_seg_num] = ST_RESP_MULTI_BEAT;
            end
          end
        end
      end
      ST_RESP_MULTI_BEAT : begin
        if (!mcctl_halt) begin
          if (!s_resp_posted) begin // Discard posted response packet
            s_cpl_dv = svalid;
            s_atop_wr_rsp = (mrtrk_atomic_id && sresp_wr_not_rd);
            if (svalid && slast) begin
              s_resp2cpl_fsm_ary[s_wr_seg_num] = ST_RSP_IDLE;
              s_cpl_eot = 1'b1;
              if (slast_pkt_beat) begin
                s_cpl_last_pkt_beat = 1'b1;
              end
            end
          end
        end
      end
    endcase
  end

  // FSM sequential
  always @(posedge core_clk or negedge core_rst_n) begin : proc_seq_resp2cpl_fsm
    if (!core_rst_n) begin
      r_resp2cpl_fsm_ary <= # TP {CX_REMOTE_MAX_TAGS{1'b0}};
    end else begin
      if (!mcctl_halt) begin
        r_resp2cpl_fsm_ary <= # TP s_resp2cpl_fsm_ary;
      end
    end
  end

  // -------------------------------------------------------------------------------------
  // If the following master response error status signals are asserted then hold
  // the mapped PCIe error completion response until the last master response data beat:
  // - master response interface error status
  // - master poisoned error status
  // - master bad eot error status
  // -------------------------------------------------------------------------------------
  // For robustness qualify sideband signals with non-posted transaction flag.
  assign s_smisc_info_ep      = smisc_info_ep & sresp_np_not_p;
  assign s_smisc_info_bad_eot = smisc_info_bad_eot & sresp_np_not_p;

  always @(posedge core_clk or negedge core_rst_n) begin : proc_seq_hold_error_info
    integer i;
    if (!core_rst_n) begin
      r_cpl_error_ary                          <= # TP {CX_REMOTE_MAX_TAGS{1'b0}};
      for (i=0; i<CX_REMOTE_MAX_TAGS; i=i+1) begin
        r_cpl_status_ary[i]                    <= # TP `SU_CPL_STATUS;
      end
      r_first_cpl_ca_det_ary                   <= # TP {CX_REMOTE_MAX_TAGS{1'b0}};
      r_first_cpl_ur_det_ary                   <= # TP {CX_REMOTE_MAX_TAGS{1'b0}};
      r_first_cpl_mrs_det_ary                  <= # TP {CX_REMOTE_MAX_TAGS{1'b0}};
      r_smisc_info_ep_ary                      <= # TP {CX_REMOTE_MAX_TAGS{1'b0}};
      r_first_ep_det_ary                       <= # TP {CX_REMOTE_MAX_TAGS{1'b0}};
      r_smisc_info_bad_eot_ary                 <= # TP {CX_REMOTE_MAX_TAGS{1'b0}};
      r_first_bad_eot_det_ary                  <= # TP {CX_REMOTE_MAX_TAGS{1'b0}};
    end else if (s_cpl_last_pkt_beat) begin
      r_cpl_error_ary[s_wr_seg_num]            <= # TP 1'b0;
      r_cpl_status_ary[s_wr_seg_num]           <= # TP `SU_CPL_STATUS;
      r_first_cpl_ca_det_ary[s_wr_seg_num]     <= # TP 1'b0;
      r_first_cpl_ur_det_ary[s_wr_seg_num]     <= # TP 1'b0;
      r_first_cpl_mrs_det_ary[s_wr_seg_num]    <= # TP 1'b0;
      r_smisc_info_ep_ary[s_wr_seg_num]        <= # TP 1'b0;
      r_first_ep_det_ary[s_wr_seg_num]         <= # TP 1'b0;
      r_smisc_info_bad_eot_ary[s_wr_seg_num]   <= # TP 1'b0;
      r_first_bad_eot_det_ary[s_wr_seg_num]    <= # TP 1'b0;
    end else begin
      if (!r_first_cpl_ca_det_ary[s_wr_seg_num] && !r_first_cpl_ur_det_ary[s_wr_seg_num] && svalid && (s_cpl_ca) ) begin
        r_cpl_error_ary[s_wr_seg_num]          <= # TP s_cpl_ca;
        r_cpl_status_ary[s_wr_seg_num]         <= # TP s_cpl_status;
        r_first_cpl_ca_det_ary[s_wr_seg_num]   <= # TP 1'b1;
      end
      if (!r_first_cpl_ca_det_ary[s_wr_seg_num] && !r_first_cpl_ur_det_ary[s_wr_seg_num] && svalid && (s_cpl_ur) ) begin
        r_cpl_error_ary[s_wr_seg_num]          <= # TP s_cpl_ur;
        r_cpl_status_ary[s_wr_seg_num]         <= # TP s_cpl_status;
        r_first_cpl_ur_det_ary[s_wr_seg_num]   <= # TP 1'b1;
      end
      if (!r_first_cpl_ca_det_ary[s_wr_seg_num] && !r_first_cpl_ur_det_ary[s_wr_seg_num] && svalid && (s_cpl_status == `CRS_CPL_STATUS)) begin
        r_cpl_status_ary[s_wr_seg_num]         <= # TP s_cpl_status;
        r_first_cpl_mrs_det_ary[s_wr_seg_num]  <= # TP 1'b1;
      end
      if (!r_first_ep_det_ary[s_wr_seg_num] && svalid && s_smisc_info_ep) begin
        r_smisc_info_ep_ary[s_wr_seg_num]      <= # TP s_smisc_info_ep;
        r_first_ep_det_ary[s_wr_seg_num]       <= # TP 1'b1;
      end
      // ccx_line_cond_begin: ; REDUNDANT: mstr_misc_info_bad_eot is a reserved field (tied low)
      if (!r_first_bad_eot_det_ary[s_wr_seg_num] && svalid && s_smisc_info_bad_eot) begin
        r_smisc_info_bad_eot_ary[s_wr_seg_num] <= # TP s_smisc_info_bad_eot;
        r_first_bad_eot_det_ary[s_wr_seg_num]  <= # TP 1'b1;
      end
      // ccx_line_cond_end
    end
  end

  assign mcf_atop_cpl_queue = (!svalid)              ? '1 :
                              (!mrtrk_atomic_id)     ? '1 :
                              (mrtrk_atomic_all_rsp) ? '1 : '0;

  // -------------------------------------------------------------------------------------
  // Assign outputs
  // -------------------------------------------------------------------------------------
  // Master completion interface
  assign mcf_hv            = sresp_wr_not_rd ? s_cpl_last_pkt_beat : s_cpl_hv;
  assign mcf_dv            = sresp_wr_not_rd ? s_cpl_last_pkt_beat : s_cpl_dv;

  assign s_svalid = svalid && (!sresp_wr_not_rd || s_cpl_last_pkt_beat);

  // Update the master completion segment number only when hv is asserted.
  always @(posedge core_clk or negedge core_rst_n) begin : proc_seq_sid
    if (!core_rst_n) begin
      r_wr_seg_num <= # TP 0;
    end else if (s_svalid)  begin
      r_wr_seg_num <= # TP s_wr_seg_num;
    end
  end
  assign mcf_wr_seg_num = s_svalid ? s_wr_seg_num : r_wr_seg_num;

  // For decomposed master responses transfers the error status can change from SLVERR to DECERR.
  // For robustness only the first error condition is translated and transmitted over the wire.
  assign mcf_status        = (r_first_cpl_ca_det_ary[s_wr_seg_num] || r_first_cpl_ur_det_ary[s_wr_seg_num] || (r_first_cpl_mrs_det_ary[s_wr_seg_num] && !s_cpl_ca && !s_cpl_ur)) ? r_cpl_status_ary[s_wr_seg_num] : s_cpl_status;
  assign mcf_ep            = s_smisc_info_ep | r_smisc_info_ep_ary[s_wr_seg_num];
  assign mcf_tc            = smisc_info_tc;

  // For robustness set byte enables to all zeros for a non-posted write master response
  assign s_sbyte_en        = (sresp_np_not_p & sresp_wr_not_rd) ?
                                {CC_MSTR_CPL_SEG_DATA_NUM_BYTES{1'b0}} :
                                sbyte_en;
  assign mcf_dw_en         = fn_calc_dw_en(s_sbyte_en);

  assign mcf_data          = sdata;
  assign mcf_last_pkt_beat = s_cpl_last_pkt_beat;
  assign mcf_eot           = sresp_wr_not_rd ? s_cpl_last_pkt_beat : s_cpl_eot;
  assign mcf_bad_eot       = s_smisc_info_bad_eot | r_smisc_info_bad_eot_ary[s_wr_seg_num];
  // Convert master response byte enables to DWORD enables
  assign mcf_error         = s_cpl_ur | s_cpl_ca | r_cpl_error_ary[s_wr_seg_num];
  // Flush posted responses
  assign mcf_ready         = s_resp_posted   ? 1'b1 :
                             sresp_wr_not_rd ? ~mcctl_halt || ~slast_pkt_beat :
                                               ~mcctl_halt ;

  // Atomic B channel response flag
  assign mcf_atop_wr_rsp   = s_atop_wr_rsp;

  // -------------------------------------------------------------------------------------
  // Functions
  // -------------------------------------------------------------------------------------
  // Data width depends on data conversion ratio. If master response data width greater
  // than or equal to the PCIe core data width then data width equal master response
  // data width else PCIe core data width.

  function automatic [CC_MSTR_CPL_SEG_DATA_NUM_DWORDS-1:0] fn_calc_dw_en;
    input [CC_MSTR_CPL_SEG_DATA_NUM_DWORDS-1:0][3:0] byte_lane_enables;
    begin
      foreach (fn_calc_dw_en[i]) begin
        fn_calc_dw_en[i] = |byte_lane_enables[i];
      end
    end
  endfunction

  // -------------------------------------------------------------------------------------
  // Enumerate FSM states
  // -------------------------------------------------------------------------------------
   `ifndef SYNTHESIS
   //VCS coverage off
   wire [16*8:1] MCF_FSM;
   assign MCF_FSM = (r_resp2cpl_fsm_ary[s_wr_seg_num] == ST_RSP_IDLE)        ? "RSP_IDLE       " :
                    (r_resp2cpl_fsm_ary[s_wr_seg_num] == ST_RESP_MULTI_BEAT) ? "RESP_MULTI_BEAT" :
                    "UNDEF";
   //VCS coverage on
   `endif

endmodule
