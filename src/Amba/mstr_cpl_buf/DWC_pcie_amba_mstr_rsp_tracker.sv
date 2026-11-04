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
// ---    $DateTime: 2022/05/17 06:52:58 $
// ---    $Revision: #10 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Amba/mstr_cpl_buf/DWC_pcie_amba_mstr_rsp_tracker.sv#10 $
// -------------------------------------------------------------------------
// Module Description:
// Tracks PCIe non-posted decomposed master requests and their corresponding responses.
// Generates a flag to indicate when the last master response is expected for the
// originating PCIe non-posted request.
// Recycles the master request ID when all master responses received.
// Tracker remains synchronised in normal and error modes of operation, every master
// request receives a corresponding master response.
// ---------------------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_amba_mstr_rsp_tracker
 #(
  // -------------------------------------------------------------------------------------
  // Parameters modified by an instantiation parameter assignment
  // -------------------------------------------------------------------------------------
  parameter CC_MAX_MSTR_TAGS                 = 8,
  parameter CC_MAX_MSTR_TAG_PW               = 3,
  parameter CC_MSTR_MAX_SPLIT_PACK_PW        = 5,
  // -------------------------------------------------------------------------------------
  // Parameters not modified by an instantiation parameter assignment
  // -------------------------------------------------------------------------------------
  parameter TP                               = `TP
 )
 (
  // -------------------------------------------------------------------------------------
  // Clocks and resets
  // -------------------------------------------------------------------------------------
  input                                              mstr_aclk,
  input                                              mstr_aresetn,
  // -------------------------------------------------------------------------------------
  // Master non-posted request information interface
  // -------------------------------------------------------------------------------------
  // radmx_mreq_np_valid: Indicates inbound AMBA request information is valid.
  // radmx_mreq_np_id: Inbound master request ID, validated by radmx_mreq_np_valid.
  // radmx_mreq_np_last: Indicates the master request is the last request associated
  //                  with the inbound TLP request. Validated by radmx_mreq_np_valid.
  // radmx_mreq_np_atomic: Indicates if inbound request is an atomic operation.
  input                                              radmx_mreq_np_valid,

  input       [CC_MAX_MSTR_TAG_PW-1:0]               radmx_mreq_np_id,

  input                                              radmx_mreq_np_last,
  input                                              radmx_mreq_np_atomic,
  // -------------------------------------------------------------------------------------
  // Master response interface
  // -------------------------------------------------------------------------------------
  input                                              svalid,
  input       [CC_MAX_MSTR_TAG_PW-1:0]               sid,
  input                                              sresp_np_not_p,
  input                                              slast,
  input                                              ready,
  // -------------------------------------------------------------------------------------
  // Master response tracker interface
  // -------------------------------------------------------------------------------------
  input                                              atop_err_decrease,
  output                                             mrtrk_atomic_id,
  output                                             mrtrk_atomic_all_rsp,
  output wire [CC_MAX_MSTR_TAGS-1:0]                 mrtrk_last_pkt
 );
  // -------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------
  localparam MSTR_RSP_CMPLT_ONLY = 2'b01;
  localparam MSTR_REQ_CMPLT_ONLY = 2'b10;
  localparam MSTR_REQ_AND_RSP_CMPLT= 2'b11;

  // -------------------------------------------------------------------------------------
  // Internal wires/regs
  // -------------------------------------------------------------------------------------
  wire                                              s_mstr_rsp_cmplt;
  wire                                              s_mstr_req_cmplt;

  reg         [CC_MSTR_MAX_SPLIT_PACK_PW-1:0]       s_remaining_mrsp_cnt_ary
                                                    [CC_MAX_MSTR_TAGS-1:0];
  reg         [CC_MSTR_MAX_SPLIT_PACK_PW-1:0]       r_remaining_mrsp_cnt_ary
                                                    [CC_MAX_MSTR_TAGS-1:0];

  reg         [CC_MAX_MSTR_TAGS-1:0]                r_mreq_np_last;


  reg         [CC_MAX_MSTR_TAGS-1:0]                s_last_pkt_ary;
  logic       [1:0]                                 r_mreq_np_atomic
                                                    [CC_MAX_MSTR_TAGS-1:0];
  logic                                             s_atop_decrease;

  // -------------------------------------------------------------------------------------
  // Internal design
  // -------------------------------------------------------------------------------------
  // -------------------------------------------------------------------------------------
  // Track decomposed master responses per outstanding PCIe non-posted request
  // -------------------------------------------------------------------------------------
  // For robustness qualify the last master response data beat with the non-posted
  // indication flag.
  assign s_mstr_rsp_cmplt = svalid & sresp_np_not_p & slast & ready;
  assign s_mstr_req_cmplt = radmx_mreq_np_valid;

  always @(*) begin : proc_comb_remaining_rsp_cnt
    integer i;
    // Initialise
    for (i=0; i<CC_MAX_MSTR_TAGS; i=i+1) begin
      s_remaining_mrsp_cnt_ary[i] = r_remaining_mrsp_cnt_ary[i];
    end

    case ({s_mstr_req_cmplt, s_mstr_rsp_cmplt} )
      MSTR_REQ_AND_RSP_CMPLT : begin
        // If the ID's are not the same then increment the remaining response counter
        // associated with the master request ID, decrement the counter associated
        // with the master response ID.
        if (radmx_mreq_np_id!=sid) begin
          for (i=0; i<CC_MAX_MSTR_TAGS; i=i+1) begin

            if (i==radmx_mreq_np_id) begin
              s_remaining_mrsp_cnt_ary[i] = s_remaining_mrsp_cnt_ary[i]+1;
            end
            if (i==sid) begin
              if (|r_mreq_np_atomic[sid]) begin
                if (s_atop_decrease) begin
                  s_remaining_mrsp_cnt_ary[i] = s_remaining_mrsp_cnt_ary[i]-1;
                end
              end else begin
                s_remaining_mrsp_cnt_ary[i] = s_remaining_mrsp_cnt_ary[i]-1;
              end
            end
          end
        end
      end
      MSTR_REQ_CMPLT_ONLY : begin
        // Increment the remaining response counter associated with the
        // master request ID
        for (i=0; i<CC_MAX_MSTR_TAGS; i=i+1) begin

          if (i==radmx_mreq_np_id) begin
            s_remaining_mrsp_cnt_ary[i] = s_remaining_mrsp_cnt_ary[i]+1;
          end
        end
      end
      MSTR_RSP_CMPLT_ONLY : begin
        // Decrement the remaining response counter associated with the
        // master response ID.
        for (i=0; i<CC_MAX_MSTR_TAGS; i=i+1) begin
          if (i==sid) begin
            if (|r_mreq_np_atomic[sid]) begin
              if (s_atop_decrease) begin
                s_remaining_mrsp_cnt_ary[i] = s_remaining_mrsp_cnt_ary[i]-1;
              end
            end else begin
              s_remaining_mrsp_cnt_ary[i] = s_remaining_mrsp_cnt_ary[i]-1;
            end
          end
        end
      end
      default : begin
        for (i=0; i<CC_MAX_MSTR_TAGS; i=i+1) begin
          s_remaining_mrsp_cnt_ary[i] = r_remaining_mrsp_cnt_ary[i];
        end
      end
    endcase
  end

  always @(posedge mstr_aclk or negedge mstr_aresetn) begin : proc_seq_remaining_rsp_cnt
    integer i;
    if (!mstr_aresetn) begin
      for (i=0; i<CC_MAX_MSTR_TAGS; i=i+1) begin
        r_remaining_mrsp_cnt_ary[i] <= # TP {CC_MSTR_MAX_SPLIT_PACK_PW{1'b0}};
      end
    end else begin
      for (i=0; i<CC_MAX_MSTR_TAGS; i=i+1) begin
        r_remaining_mrsp_cnt_ary[i] <= # TP s_remaining_mrsp_cnt_ary[i];
      end
    end
  end
  // -------------------------------------------------------------------------------------
  // Generate last packet flag
  // -------------------------------------------------------------------------------------
  // Track last non-posted request issued by the inbound decomposer
  always @(posedge mstr_aclk or negedge mstr_aresetn) begin : proc_seq_mreq_np_last
    integer i;
    if (!mstr_aresetn) begin
       r_mreq_np_last <= # TP {CC_MAX_MSTR_TAGS{1'b0}};
    end else begin
      for (integer i=0; i<CC_MAX_MSTR_TAGS; i=i+1) begin
        if (s_mstr_rsp_cmplt && (i==sid) && s_last_pkt_ary[i]) begin
          if (|r_mreq_np_atomic[i]) begin
            if (s_atop_decrease) begin
              r_mreq_np_last[i] <= # TP 1'b0;
            end
          end else begin
              r_mreq_np_last[i] <= # TP 1'b0;
          end
        end else if (radmx_mreq_np_valid && radmx_mreq_np_last &&
                      (i==radmx_mreq_np_id)) begin
          r_mreq_np_last[i] <= # TP 1'b1;
        end
      end
    end
  end

  // Set last packet flag per outstanding PCIe non-posted request
  always @(*) begin : proc_comb_last_pkt
    for (integer i=0; i<CC_MAX_MSTR_TAGS; i=i+1) begin
      s_last_pkt_ary[i] = ((r_remaining_mrsp_cnt_ary[i]==1) && r_mreq_np_last[i]) || ((s_mstr_req_cmplt & s_mstr_rsp_cmplt) && i==radmx_mreq_np_id && i==sid && radmx_mreq_np_atomic);
    end
  end

  assign mrtrk_last_pkt = s_last_pkt_ary;

  // Tracks atomic IDs and Atomic responses
  // mrtrk_atomic_id is 1 when a response with an atomic ID is received
  // mrtrk_atomic_all_rsp is 1 when all responses from the B and R channel, for a certain atomic ID, have been received
  always_ff @(posedge mstr_aclk or negedge mstr_aresetn) begin : proc_seq_mreq_atop_id
    if (!mstr_aresetn) begin
      for (int i=0; i<CC_MAX_MSTR_TAGS; i=i+1) begin
        r_mreq_np_atomic[i] <= # TP 2'b0;
      end
    end else begin
      if (s_mstr_req_cmplt) begin 
        r_mreq_np_atomic[radmx_mreq_np_id] <= # TP radmx_mreq_np_atomic ? 2'b10 : 2'b00;
      end
      if (s_mstr_rsp_cmplt) begin
        if (s_atop_decrease) begin
          r_mreq_np_atomic[sid] <= # TP 2'b00;
        end else if (|r_mreq_np_atomic[sid]) begin
          r_mreq_np_atomic[sid] <= # TP r_mreq_np_atomic[sid] - 1;
        end
      end
    end
  end

  assign mrtrk_atomic_id      = (svalid & sresp_np_not_p & ready) ? |r_mreq_np_atomic[sid] : '0;
  assign mrtrk_atomic_all_rsp = (svalid & sresp_np_not_p & ready & (r_mreq_np_atomic[sid] == 2'b01));

  assign s_atop_decrease      = mrtrk_atomic_all_rsp;


`ifndef SYNTHESIS
  `endif

endmodule

