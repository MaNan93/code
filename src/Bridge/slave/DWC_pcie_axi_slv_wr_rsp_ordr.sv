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

//------------------------------------------------------------------------------
// RCS information:
//   $DateTime: 2023/12/22 07:15:34 $
//   $Revision: #14 $
//   $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/slave/DWC_pcie_axi_slv_wr_rsp_ordr.sv#14 $
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// Module Description:
//------------------------------------------------------------------------------
// The main funcions are:
//
// Outbound write responses ordering
//
//------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"


 module DWC_pcie_axi_slv_wr_rsp_ordr #(
  parameter SLV_NUM_OUTSTND_WR_REQ      = 16, // Max number of outstanding AXI writes
  parameter SLV_NUM_OUTSTND_WR_REQ_LOG2 = 4 , // SLV_NUM_OUTSTND_WR_REQ port width
  parameter SLV_BUS_ID_WIDTH            = 5 , // Slave Bus ID width
  parameter WR_NP_RSP_INFO_WD           = 12, // Misc info port width
  parameter NFUNC_WD                    = 2 , // Width of function number signal
  parameter DC_CPL_STATUS_WD            = `DC_CPL_STATUS_WD, // Completion status width
  parameter TP                          = `TP // Clock to Q delay
  )
  
                                     (
   input                               slv_aclk
  ,input                               slv_aresetn
  // ---------------------------------------------------------------------------
  // Write request I/F
  // ---------------------------------------------------------------------------
  ,input                               srq_wr_valid_hl
  ,input        [SLV_BUS_ID_WIDTH-1:0] srq_wr_id
  ,input                               srq_wr_p
  ,input                               srq_wr_np
  ,input                               srq_wr_np_atomic
  ,input                               srq_wr_last_null_writes
  // ---------------------------------------------------------------------------
  // Non posted write response I/F
  // ---------------------------------------------------------------------------
  ,input                               dmx_np_rsp_wr_valid_hl
  ,input        [SLV_BUS_ID_WIDTH-1:0] dmx_np_rsp_wr_id
  ,input    [`CC_AXIJ_DMWR_VALUE +1:0] dmx_np_rsp_wr_status
  ,input       [WR_NP_RSP_INFO_WD-1:0] dmx_np_rsp_wr_info
  ,output wire                         wrordr_np_rsp_wr_ready
  ,input                               dbi_response
  // ---------------------------------------------------------------------------
  // Posted write response I/F
  // ---------------------------------------------------------------------------
  ,input                               pdcmp_p_rsp_valid_hl
  ,input        [SLV_BUS_ID_WIDTH-1:0] pdcmp_p_rsp_id
  ,input        [DC_CPL_STATUS_WD-1:0] pdcmp_p_rsp_cpl_stat
  ,input                         [1:0] serr_p_resp
  // ---------------------------------------------------------------------------
  // Non posted atomic write response I/F
  // ---------------------------------------------------------------------------
  ,input                               npdcmp_np_atomic_rsp_valid_hl
  ,input        [SLV_BUS_ID_WIDTH-1:0] npdcmp_np_atomic_rsp_id
  // ---------------------------------------------------------------------------
  // Write response I/F
  // ---------------------------------------------------------------------------
  ,output wire                         wrordr_bvalid_hl
  ,output wire  [SLV_BUS_ID_WIDTH-1:0] wrordr_bid
  ,output wire [`CC_AXIJ_DMWR_VALUE +1:0] wrordr_bresp
  ,output wire [WR_NP_RSP_INFO_WD-1:0] wrordr_bmisc_info
  ,output wire                         wrordr_dbi_response
  ,input                               bready
  // Completions Status during DPC
  ,input                               cdc_core_in_dpc_i
  ,input                               qst_cfg_dpc_cpl_cntrl_i
  );



  // ---------------------------------------------------------------------------
  //Signals
  // ---------------------------------------------------------------------------
  reg             [SLV_BUS_ID_WIDTH-1:0] r_lut_id        [SLV_NUM_OUTSTND_WR_REQ-1:0];//LUT to store the IDs
  reg             [SLV_BUS_ID_WIDTH-1:0] s_lut_id        [SLV_NUM_OUTSTND_WR_REQ-1:0];
  reg                              [1:0] r_lut_bresp     [SLV_NUM_OUTSTND_WR_REQ-1:0];//LUT to store the IDs
  reg                              [1:0] s_lut_bresp     [SLV_NUM_OUTSTND_WR_REQ-1:0];
  reg             [DC_CPL_STATUS_WD-1:0] r_lut_cpl_stat  [SLV_NUM_OUTSTND_WR_REQ-1:0];//LUT to store the IDs
  reg             [DC_CPL_STATUS_WD-1:0] s_lut_cpl_stat  [SLV_NUM_OUTSTND_WR_REQ-1:0];
  reg  [SLV_NUM_OUTSTND_WR_REQ_LOG2-1:0] r_lut_push_cnt                              ;
  reg  [SLV_NUM_OUTSTND_WR_REQ_LOG2-1:0] s_lut_push_cnt                              ;
  reg       [SLV_NUM_OUTSTND_WR_REQ-1:0] r_wr_act_vec                                ;//Write active
  reg       [SLV_NUM_OUTSTND_WR_REQ-1:0] s_wr_act_vec                                ;
  reg       [SLV_NUM_OUTSTND_WR_REQ-1:0] r_post_pnd_vec                              ;//Posted write pending
  reg       [SLV_NUM_OUTSTND_WR_REQ-1:0] s_post_pnd_vec                              ;
  reg       [SLV_NUM_OUTSTND_WR_REQ-1:0] r_npost_pnd_vec                             ;//Non-Posted write pending
  reg       [SLV_NUM_OUTSTND_WR_REQ-1:0] s_npost_pnd_vec                             ;
  reg       [SLV_NUM_OUTSTND_WR_REQ-1:0] s_npost_atomic_pnd_vec                      ;
  reg       [SLV_NUM_OUTSTND_WR_REQ-1:0] r_npost_atomic_pnd_vec                      ;//Non-Posted atomic write pending
  reg       [SLV_NUM_OUTSTND_WR_REQ-1:0] s_wr_rsp_type_vec                           ;//Write response type
  reg       [SLV_NUM_OUTSTND_WR_REQ-1:0] r_wr_rsp_type_vec                           ;
  reg       [SLV_NUM_OUTSTND_WR_REQ-1:0] r_halt_id_vec                               ;//Halt ID pop flag
  reg       [SLV_NUM_OUTSTND_WR_REQ-1:0] s_halt_id_vec                               ;
  reg       [SLV_NUM_OUTSTND_WR_REQ-1:0] r_halt_tnull_vec                            ;//Wait for trailing nulls to end flag
  reg       [SLV_NUM_OUTSTND_WR_REQ-1:0] s_halt_tnull_vec                            ;
  reg  [SLV_NUM_OUTSTND_WR_REQ_LOG2-1:0] r_lut_push_cnt_indx                         ;
  reg                                    s_same_id_in_lut                            ;
  reg                                    s_lut_id_recycled                           ;
  reg  [SLV_NUM_OUTSTND_WR_REQ_LOG2-1:0] s_lut_id_recycled_ptr                       ;
  reg                                    s_rsp_id_valid_hl                           ;
  reg                                    r_wrordr_bvalid_hl                          ;
  reg                                    s_wrordr_bvalid_hl                          ;
  reg             [SLV_BUS_ID_WIDTH-1:0] r_wrordr_bid                                ;
  reg             [SLV_BUS_ID_WIDTH-1:0] s_wrordr_bid                                ;
  reg                                    s_wrordr_np_rsp_wr_ready                    ;
  reg                                    r_wrordr_np_rsp_wr_ready                    ;
  reg                              [1:0] s_wrordr_p_bresp                            ;
  reg                              [1:0] r_wrordr_p_bresp                            ;
  reg             [DC_CPL_STATUS_WD-1:0] s_wrordr_p_cpl_stat                         ;
  reg             [DC_CPL_STATUS_WD-1:0] r_wrordr_p_cpl_stat                         ;
  reg         [`CC_AXIJ_DMWR_VALUE +1:0] s_wrordr_bresp                              ;
  reg         [`CC_AXIJ_DMWR_VALUE +1:0] r_wrordr_bresp                              ;
  wire           [WR_NP_RSP_INFO_WD-1:0] s_wrordr_p_bmisc_info                       ;
  reg            [WR_NP_RSP_INFO_WD-1:0] s_wrordr_bmisc_info                         ;
  reg            [WR_NP_RSP_INFO_WD-1:0] r_wrordr_bmisc_info                         ;
  reg                                    s_wrordr_dbi_response                       ;
  reg                                    r_wrordr_dbi_response                       ;
  reg                                    s_dbi_response                              ;
  reg                                    r_dbi_response                              ;
  reg         [`CC_AXIJ_DMWR_VALUE +1:0] s_bresp                                     ;
  reg         [`CC_AXIJ_DMWR_VALUE +1:0] r_bresp                                     ;
  reg            [WR_NP_RSP_INFO_WD-1:0] s_bmisc_info                                ;
  reg            [WR_NP_RSP_INFO_WD-1:0] r_bmisc_info                                ;
  reg                                    s_wr_rsp_type                               ;
  reg                                    r_wr_rsp_type                               ;
  reg                                    s_np_cpl_pnd                                ;
  reg                                    r_np_cpl_pnd                                ;

  reg [SLV_NUM_OUTSTND_WR_REQ-1:0]      s_released_rsp_vec;
  reg [SLV_NUM_OUTSTND_WR_REQ_LOG2-1:0] s_released_rsp_index;
  reg                                   s_released_rsp_valid;
  reg [SLV_NUM_OUTSTND_WR_REQ-1:0]      s_unhalted_rsp_vec;
  reg [SLV_NUM_OUTSTND_WR_REQ_LOG2-1:0] s_unhalted_rsp_index;
  reg                                   s_unhalted_rsp_valid;
  reg [SLV_NUM_OUTSTND_WR_REQ-1:0]      s_cleared_pend_p_rsp_vec;
  reg [SLV_NUM_OUTSTND_WR_REQ_LOG2-1:0] s_cleared_pend_p_rsp_index;
  reg                                   s_cleared_pend_p_rsp_valid;
  reg [SLV_NUM_OUTSTND_WR_REQ-1:0]      s_cleared_pend_np_rsp_vec;
  reg [SLV_NUM_OUTSTND_WR_REQ_LOG2-1:0] s_cleared_pend_np_rsp_index;
  reg                                   s_cleared_pend_np_rsp_valid;
  reg [SLV_NUM_OUTSTND_WR_REQ-1:0]      s_cleared_pend_atop_rsp_vec;
  reg [SLV_NUM_OUTSTND_WR_REQ_LOG2-1:0] s_cleared_pend_atop_rsp_index;
  reg                                   s_cleared_pend_atop_rsp_valid;

  reg                                   r_pdcmp_p_rsp_valid_hl;
  reg            [SLV_BUS_ID_WIDTH-1:0] r_pdcmp_p_rsp_id;
  reg            [DC_CPL_STATUS_WD-1:0] r_pdcmp_p_rsp_cpl_stat;
  reg                             [1:0] r_serr_p_resp;


  // ---------------------------------------------------------------------------
  // Design
  // ---------------------------------------------------------------------------

  always @(posedge slv_aclk or negedge slv_aresetn) begin : proc_seq_r_pdcmp_p_if
    if(!slv_aresetn) begin
      r_pdcmp_p_rsp_valid_hl <= #TP '0;
      r_pdcmp_p_rsp_id       <= #TP '0;
      r_pdcmp_p_rsp_cpl_stat <= #TP '0;
      r_serr_p_resp          <= #TP '0;
    end else begin
      r_pdcmp_p_rsp_valid_hl <= #TP pdcmp_p_rsp_valid_hl;
      r_pdcmp_p_rsp_id       <= #TP pdcmp_p_rsp_id;
      r_pdcmp_p_rsp_cpl_stat <= #TP pdcmp_p_rsp_cpl_stat;
      r_serr_p_resp          <= #TP serr_p_resp;
    end
  end

  // ---------------------------------------------------------------------------
  // Write response for AMBA interface
  // ---------------------------------------------------------------------------
  always @(*) begin : proc_comb_bvalid
    s_wrordr_bvalid_hl = r_wrordr_bvalid_hl;

    if (r_wrordr_bvalid_hl && bready && !s_lut_id_recycled)
      s_wrordr_bvalid_hl = 1'b0;
    else
      if (s_lut_id_recycled)
      s_wrordr_bvalid_hl = 1'b1;
  end

  // ---------------------------------------------------------------------------
  // Respecting type of transaction NP/P and load bresp and misc info correctly
  // ---------------------------------------------------------------------------
  always @(*) begin : proc_comb_bresp
    if(s_wr_rsp_type) begin
      s_wrordr_bresp      = r_bresp;
    end
    else begin
      s_wrordr_bresp      =  s_wrordr_p_bresp;
    end
  end

  assign s_wrordr_p_bmisc_info =     { 1'h0
                                     , 1'h0
                                     , 3'h0
                                     , 1'h0
                                     , 1'h0
                                     , s_wrordr_p_cpl_stat
                                     , 1'h0
                                     , 8'h00 // Replace with info from core
                                     , 9'h000
                                     };

  always @(*) begin : proc_comb_bmiscinfo
    if(s_wr_rsp_type) begin
      s_wrordr_bmisc_info = r_bmisc_info;
      // Completions Status during DPC
      s_wrordr_bmisc_info[(WR_NP_RSP_INFO_WD-1)-7:(WR_NP_RSP_INFO_WD-1)-9]  = (cdc_core_in_dpc_i && r_bmisc_info[WR_NP_RSP_INFO_WD-1] ? (qst_cfg_dpc_cpl_cntrl_i ? `UR_CPL_STATUS : `CA_CPL_STATUS) : r_bmisc_info[(WR_NP_RSP_INFO_WD-1)-7:(WR_NP_RSP_INFO_WD-1)-9]);
      s_wrordr_dbi_response = r_dbi_response;
    end
    else begin
      s_wrordr_bmisc_info = s_wrordr_p_bmisc_info;
      // Completions Status during DPC
      s_wrordr_bmisc_info[(WR_NP_RSP_INFO_WD-1)-7:(WR_NP_RSP_INFO_WD-1)-9]  = (cdc_core_in_dpc_i && s_wrordr_p_bmisc_info[WR_NP_RSP_INFO_WD-1] ? (qst_cfg_dpc_cpl_cntrl_i ? `UR_CPL_STATUS : `CA_CPL_STATUS) : s_wrordr_p_bmisc_info[(WR_NP_RSP_INFO_WD-1)-7:(WR_NP_RSP_INFO_WD-1)-9]);
      s_wrordr_dbi_response = 1'b0;
    end
  end

  // ---------------------------------------------------------------------------
  // ID recycled - completion received from posted or non-posted write
  // Generate the pointer in te LUT that corresponds to the recycle ID
  // ---------------------------------------------------------------------------
  always @(*) begin : proc_comb_recycle_id
    integer j;

    s_lut_id_recycled     = 1'b0;
    s_lut_id_recycled_ptr = {SLV_NUM_OUTSTND_WR_REQ_LOG2{1'b0}};
    s_wr_rsp_type         = r_wr_rsp_type;
    s_wrordr_bid          = r_wrordr_bid;
    s_wrordr_p_bresp      = r_wrordr_bresp[1:0];
    s_wrordr_p_cpl_stat   = r_wrordr_p_cpl_stat;

    s_released_rsp_vec    = '0;  
    s_released_rsp_index  = '0;  
    s_released_rsp_valid  = '0;  

    for (j=0; j<SLV_NUM_OUTSTND_WR_REQ; j=j+1)
      if (r_wr_act_vec[j] && (!r_post_pnd_vec[j]) && (!r_npost_pnd_vec[j]) && (!r_npost_atomic_pnd_vec[j]) && (!r_halt_id_vec[j]) && (!r_halt_tnull_vec[j]))
        s_released_rsp_vec[j] = 1;

    s_released_rsp_valid = |s_released_rsp_vec;
    s_released_rsp_index = binsearch(s_released_rsp_vec);

    if ((!r_wrordr_bvalid_hl || (r_wrordr_bvalid_hl && bready)) && s_released_rsp_valid) begin
      s_released_rsp_index  = binsearch(s_released_rsp_vec);
      s_lut_id_recycled     = 1'b1;
      s_lut_id_recycled_ptr =                   s_released_rsp_index ;
      s_wrordr_bid          = r_lut_id         [s_released_rsp_index];
      s_wrordr_p_bresp      = r_lut_bresp      [s_released_rsp_index];
      s_wrordr_p_cpl_stat   = r_lut_cpl_stat   [s_released_rsp_index];
      s_wr_rsp_type         = r_wr_rsp_type_vec[s_released_rsp_index];
    end
  end

  // ---------------------------------------------------------------------------
  // Write Order based on a LUT
  // ---------------------------------------------------------------------------
  always @(*) begin : proc_comb_lut_recycle
    integer i,j,k,l,m,n;
    reg  [SLV_NUM_OUTSTND_WR_REQ_LOG2-1:0] s_lut_push_cnt_m1;

    for (i=0; i<SLV_NUM_OUTSTND_WR_REQ;i=i+1) begin
      s_lut_id[i]           = r_lut_id[i];
      s_lut_bresp[i]        = r_lut_bresp[i];
      s_lut_cpl_stat[i]     = r_lut_cpl_stat[i];
    end
    s_lut_push_cnt          = r_lut_push_cnt;
    s_wr_act_vec            = r_wr_act_vec;
    s_post_pnd_vec          = r_post_pnd_vec;
    s_npost_pnd_vec         = r_npost_pnd_vec;
    s_npost_atomic_pnd_vec  = r_npost_atomic_pnd_vec;
    s_halt_id_vec           = r_halt_id_vec;
    s_halt_tnull_vec        = r_halt_tnull_vec;
    s_wr_rsp_type_vec       = r_wr_rsp_type_vec;
    s_bresp                 = r_bresp;
    s_bmisc_info            = r_bmisc_info;
    s_np_cpl_pnd            = r_np_cpl_pnd;
    s_dbi_response          = r_dbi_response;
    s_lut_push_cnt_m1       = r_lut_push_cnt-1;
    // -------------------------------------------------------------------------
    // Handle recycled ID first
    // -------------------------------------------------------------------------
    if (s_lut_id_recycled) begin
      // Shift down the positions above lut recycled pointer
      for (j=0; j<SLV_NUM_OUTSTND_WR_REQ; j=j+1) begin
        if ((j>=s_lut_id_recycled_ptr) && (j < (SLV_NUM_OUTSTND_WR_REQ-1))) begin 
          s_lut_id              [j] = r_lut_id              [j+1];
          s_lut_bresp           [j] = r_lut_bresp           [j+1];
          s_lut_cpl_stat        [j] = r_lut_cpl_stat        [j+1];
          s_wr_act_vec          [j] = r_wr_act_vec          [j+1];
          s_post_pnd_vec        [j] = r_post_pnd_vec        [j+1];
          s_npost_pnd_vec       [j] = r_npost_pnd_vec       [j+1];
          s_npost_atomic_pnd_vec[j] = r_npost_atomic_pnd_vec[j+1];
          s_halt_id_vec         [j] = r_halt_id_vec         [j+1];
          s_halt_tnull_vec      [j] = r_halt_tnull_vec      [j+1];
          s_wr_rsp_type_vec     [j] = r_wr_rsp_type_vec     [j+1];
        end
      end
      // Update push counter
      if(r_wr_act_vec[SLV_NUM_OUTSTND_WR_REQ-1])
        s_lut_push_cnt    = r_lut_push_cnt;
      else
        s_lut_push_cnt    = r_lut_push_cnt-1;
      //Clear position where last entry was previously stored 
      s_wr_act_vec [s_lut_push_cnt] = 0;
    end

    // -------------------------------------------------------------------------
    // New slave request write issued - store ID in the LUT
    // -------------------------------------------------------------------------
    if (srq_wr_valid_hl) begin
      // store new request at s_lut_push_cnt
      s_lut_id              [s_lut_push_cnt] = srq_wr_id;                  // Pushing AXI ID into LUT
      s_lut_bresp           [s_lut_push_cnt] = 2'b00;                      // Resetting BRESP in LUT
      s_lut_cpl_stat        [s_lut_push_cnt] = {(DC_CPL_STATUS_WD){1'b0}}; // Resetting CPL STATUS in LUT
      s_wr_act_vec          [s_lut_push_cnt] = 1'b1;
      s_post_pnd_vec        [s_lut_push_cnt] = srq_wr_p;
      s_npost_pnd_vec       [s_lut_push_cnt] = srq_wr_np;
      s_npost_atomic_pnd_vec[s_lut_push_cnt] = srq_wr_np_atomic;
      s_halt_id_vec         [s_lut_push_cnt] = s_same_id_in_lut;
      s_halt_tnull_vec      [s_lut_push_cnt] = ~srq_wr_last_null_writes;
      if (srq_wr_p)
        s_wr_rsp_type_vec   [s_lut_push_cnt] = 1'b0;
      else if (srq_wr_np_atomic)
        s_wr_rsp_type_vec   [s_lut_push_cnt] = 1'b0;
      else
        s_wr_rsp_type_vec   [s_lut_push_cnt] = 1'b1;
      // if not at the last entry in the lut, increment s_lut_push_cnt
      if(s_lut_push_cnt <(SLV_NUM_OUTSTND_WR_REQ-1))
        s_lut_push_cnt    = s_lut_push_cnt + {{(SLV_NUM_OUTSTND_WR_REQ_LOG2-1){1'b0}}, 1'b1};
    end

    // -------------------------------------------------------------------------
    // Clear halt bit - LUT can have more than one entry with the same ID
    // -------------------------------------------------------------------------
    s_unhalted_rsp_vec   = '0;  
    s_unhalted_rsp_index = '0;  
    s_unhalted_rsp_valid = '0;  

    for (k=0; k<SLV_NUM_OUTSTND_WR_REQ; k=k+1)
      if (s_wr_act_vec[k] && (s_lut_id[k] == s_wrordr_bid) && s_halt_id_vec[k])
        s_unhalted_rsp_vec[k] = 1;  

    s_unhalted_rsp_valid = |s_unhalted_rsp_vec;  
    s_unhalted_rsp_index = binsearch(s_unhalted_rsp_vec);

    if (s_lut_id_recycled && s_unhalted_rsp_valid)
      s_halt_id_vec[s_unhalted_rsp_index] = 1'b0;

  // ---------------------------------------------------------------------------
  // When a write request has trailing null beats the request is issued on the 
  // wire without waiting for wlast, but the response can only be returned after
  // wlast; the srq_wr_last_null_writes asserts when wlast is received.
  // We are going to use this signal to set a flag per request to indicate if
  // response can be returned or not
  // ---------------------------------------------------------------------------
    // clear tnull_halt bit from last request written into LUT when deassertion of srq_wr_last_null_writes is detected
    
    s_lut_push_cnt_m1 = s_lut_push_cnt-1;

    if(srq_wr_last_null_writes)begin
      if(s_wr_act_vec[SLV_NUM_OUTSTND_WR_REQ-1]) // if LUT is full
        s_halt_tnull_vec[SLV_NUM_OUTSTND_WR_REQ-1] = 1'b0;
      else if (s_lut_push_cnt > 0) // if LUT not empty
        s_halt_tnull_vec[s_lut_push_cnt_m1] = 1'b0;
    end

    // -------------------------------------------------------------------------
    // Clear Pending Write Responses
    // Posted write response valid - completion received
    // -------------------------------------------------------------------------
    s_cleared_pend_p_rsp_vec   = '0;  
    s_cleared_pend_p_rsp_index = '0;  
    s_cleared_pend_p_rsp_valid = '0;  

    for (l=0; l<SLV_NUM_OUTSTND_WR_REQ; l=l+1) 
      if (r_pdcmp_p_rsp_valid_hl && s_wr_act_vec[l] && (s_lut_id[l] == r_pdcmp_p_rsp_id) && s_post_pnd_vec[l])
        s_cleared_pend_p_rsp_vec[l] = 1;

    s_cleared_pend_p_rsp_valid = |s_cleared_pend_p_rsp_vec;
    s_cleared_pend_p_rsp_index = binsearch(s_cleared_pend_p_rsp_vec);

    if (r_pdcmp_p_rsp_valid_hl && s_cleared_pend_p_rsp_valid) begin
      s_post_pnd_vec[s_cleared_pend_p_rsp_index] = 1'b0;
      s_lut_bresp   [s_cleared_pend_p_rsp_index] = r_serr_p_resp;
      s_lut_cpl_stat[s_cleared_pend_p_rsp_index] = r_pdcmp_p_rsp_cpl_stat;
      end

    // -------------------------------------------------------------------------
    // Non-Posted write response valid - completion received
    // -------------------------------------------------------------------------
    if (r_wrordr_bvalid_hl && bready && r_np_cpl_pnd && r_wr_rsp_type)
      s_np_cpl_pnd = 1'b0;

    s_cleared_pend_np_rsp_vec   = '0;  
    s_cleared_pend_np_rsp_index = '0;  
    s_cleared_pend_np_rsp_valid = '0;  

    for (m=0; m<SLV_NUM_OUTSTND_WR_REQ; m=m+1)
      if (dmx_np_rsp_wr_valid_hl && s_wr_act_vec[m] && (s_lut_id[m] == dmx_np_rsp_wr_id) && s_npost_pnd_vec[m])
        s_cleared_pend_np_rsp_vec[m] = 1;

    s_cleared_pend_np_rsp_valid = |s_cleared_pend_np_rsp_vec;
    s_cleared_pend_np_rsp_index = binsearch(s_cleared_pend_np_rsp_vec);

    if (dmx_np_rsp_wr_valid_hl && r_wrordr_np_rsp_wr_ready && s_cleared_pend_np_rsp_valid) begin
      s_npost_pnd_vec[s_cleared_pend_np_rsp_index] = 1'b0;
      s_bresp            = dmx_np_rsp_wr_status;
      s_bmisc_info       = dmx_np_rsp_wr_info;
      s_np_cpl_pnd       = 1'b1;
      s_dbi_response     = dbi_response;
    end

    // -------------------------------------------------------------------------
    // Clear Pending Write Responses
    // Non Posted atomic write response valid
    // -------------------------------------------------------------------------
    s_cleared_pend_atop_rsp_vec   = '0;  
    s_cleared_pend_atop_rsp_index = '0;  
    s_cleared_pend_atop_rsp_valid = '0;  

    for (n=0; n<SLV_NUM_OUTSTND_WR_REQ; n=n+1)
      if (npdcmp_np_atomic_rsp_valid_hl && s_wr_act_vec[n] && (s_lut_id[n] == npdcmp_np_atomic_rsp_id) && s_npost_atomic_pnd_vec[n])
        s_cleared_pend_atop_rsp_vec[n] = 1;  

    s_cleared_pend_atop_rsp_valid = |s_cleared_pend_atop_rsp_vec;
    s_cleared_pend_atop_rsp_index = binsearch(s_cleared_pend_atop_rsp_vec);

    if (npdcmp_np_atomic_rsp_valid_hl && s_cleared_pend_atop_rsp_valid)
          s_npost_atomic_pnd_vec[s_cleared_pend_atop_rsp_index] = 1'b0;


  end

  // ---------------------------------------------------------------------------
  // Registering the write order manager based un the LUT
  // ---------------------------------------------------------------------------
  always @(posedge slv_aclk or negedge slv_aresetn) begin : proc_seq_lut_recycle
    integer i,j;
    if (!slv_aresetn) begin
      for (i=0; i<SLV_NUM_OUTSTND_WR_REQ;i=i+1) begin
        r_lut_id[i]       <= # TP {SLV_BUS_ID_WIDTH{1'b0}};
        r_lut_bresp[i]    <= # TP 2'b00;
        r_lut_cpl_stat[i] <= # TP {DC_CPL_STATUS_WD{1'b0}};
      end
      r_lut_push_cnt         <= # TP {SLV_NUM_OUTSTND_WR_REQ_LOG2{1'b0}};
      r_wr_act_vec           <= # TP {SLV_NUM_OUTSTND_WR_REQ{1'b0}};
      r_post_pnd_vec         <= # TP {SLV_NUM_OUTSTND_WR_REQ{1'b0}};
      r_npost_pnd_vec        <= # TP {SLV_NUM_OUTSTND_WR_REQ{1'b0}};
      r_npost_atomic_pnd_vec <= # TP {SLV_NUM_OUTSTND_WR_REQ{1'b0}};
      r_halt_id_vec          <= # TP {SLV_NUM_OUTSTND_WR_REQ{1'b0}};
      r_halt_tnull_vec       <= # TP {SLV_NUM_OUTSTND_WR_REQ{1'b0}};
      r_wr_rsp_type_vec      <= # TP {SLV_NUM_OUTSTND_WR_REQ{1'b0}};
      r_wr_rsp_type          <= # TP 1'b0;
    end
    else begin
      for (j=0; j<SLV_NUM_OUTSTND_WR_REQ;j=j+1) begin
        r_lut_id[j]       <= # TP s_lut_id[j];
        r_lut_bresp[j]    <= # TP s_lut_bresp[j];
        r_lut_cpl_stat[j] <= # TP s_lut_cpl_stat[j];
      end
      r_lut_push_cnt         <= # TP s_lut_push_cnt;
      r_wr_act_vec           <= # TP s_wr_act_vec;
      r_post_pnd_vec         <= # TP s_post_pnd_vec;
      r_npost_pnd_vec        <= # TP s_npost_pnd_vec;
      r_npost_atomic_pnd_vec <= # TP s_npost_atomic_pnd_vec;
      r_halt_id_vec          <= # TP s_halt_id_vec;
      r_halt_tnull_vec       <= # TP s_halt_tnull_vec;
      r_wr_rsp_type_vec      <= # TP s_wr_rsp_type_vec;
      r_wr_rsp_type          <= # TP s_wr_rsp_type;
    end
  end

  // ---------------------------------------------------------------------------
  // Generate a signal to tell if the new ID is already in the LUT
  // ---------------------------------------------------------------------------
  always @(*) begin : proc_comb_det_same_id
    integer j;
    s_same_id_in_lut = 1'b0;

    // Loop on all the IDs stored in the LUT
    for (j=0; j<SLV_NUM_OUTSTND_WR_REQ; j=j+1) begin
      if (r_wr_act_vec[j] && (r_lut_id[j] == srq_wr_id))
        s_same_id_in_lut = 1'b1;
    end
  end

  // ---------------------------------------------------------------------------
  // Handler Non-Posted interface
  // ---------------------------------------------------------------------------
  always @(*) begin : proc_comb_recycle_rsp_intf
    integer j;
    s_wrordr_np_rsp_wr_ready = 1'b1;

    for (j=0; j<SLV_NUM_OUTSTND_WR_REQ; j=j+1) begin
      if ((r_wr_act_vec[j] &&  !r_npost_pnd_vec[j] && !r_post_pnd_vec[j] && !r_npost_atomic_pnd_vec[j] && !r_halt_id_vec[j]) || (s_np_cpl_pnd))
        s_wrordr_np_rsp_wr_ready = 1'b0;
    end
  end

  // ---------------------------------------------------------------------------
  // Write response order interface registering
  // ---------------------------------------------------------------------------
  always @(posedge slv_aclk or negedge slv_aresetn) begin : proc_seq_out_rsp_intf
    if (!slv_aresetn) begin
      r_wrordr_np_rsp_wr_ready <= # TP 1'b0;
      r_bresp                  <= # TP '0;
      r_bmisc_info             <= # TP {WR_NP_RSP_INFO_WD{1'b0}};
      r_wrordr_bvalid_hl       <= # TP 1'b0;
      r_wrordr_bid             <= # TP {SLV_BUS_ID_WIDTH{1'b0}};
      r_wrordr_p_bresp         <= # TP 2'b00;
      r_wrordr_p_cpl_stat      <= # TP {DC_CPL_STATUS_WD{1'b0}};
      r_np_cpl_pnd             <= # TP 0;
      r_wrordr_bmisc_info      <= # TP {WR_NP_RSP_INFO_WD{1'b0}};
      r_wrordr_bresp           <= # TP '0;
      r_dbi_response           <= # TP 1'b0;
      r_wrordr_dbi_response    <= # TP 1'b0;
    end
    else begin
      r_wrordr_np_rsp_wr_ready <= # TP s_wrordr_np_rsp_wr_ready;
      r_bresp                  <= # TP s_bresp     ;
      r_bmisc_info             <= # TP s_bmisc_info;
      r_wrordr_bvalid_hl       <= # TP s_wrordr_bvalid_hl;
      r_wrordr_bid             <= # TP s_wrordr_bid;
      r_wrordr_p_bresp         <= # TP s_wrordr_p_bresp;
      r_wrordr_p_cpl_stat      <= # TP s_wrordr_p_cpl_stat;
      r_np_cpl_pnd             <= # TP s_np_cpl_pnd;
      r_wrordr_bmisc_info      <= # TP s_wrordr_bmisc_info;
      r_wrordr_bresp           <= # TP s_wrordr_bresp;
      r_dbi_response           <= # TP s_dbi_response;
      r_wrordr_dbi_response    <= # TP s_wrordr_dbi_response;
    end
  end

  //Output interface
  assign wrordr_bvalid_hl       = r_wrordr_bvalid_hl;
  assign wrordr_bid             = r_wrordr_bid;
  assign wrordr_bresp           = r_wrordr_bresp;
  assign wrordr_bmisc_info      = r_wrordr_bmisc_info;
  assign wrordr_np_rsp_wr_ready = r_wrordr_np_rsp_wr_ready;
  assign wrordr_dbi_response    = r_wrordr_dbi_response;

  
   function automatic [SLV_NUM_OUTSTND_WR_REQ_LOG2-1:0] binsearch;
      input [SLV_NUM_OUTSTND_WR_REQ-1:0] array_i;

      //This function is able to handle up to 1024 tags, internally it's fixed to 1024.
      //Un-used logic is tied to 0's, since it detects the first 1 in the LUT

      reg [1023:0]        array_int;
      
      //Search net matrix
      reg [1023:0]        matrix_0_search;
      reg [511:0]         matrix_1_search;
      reg [255:0]         matrix_2_search;
      reg [127:0]         matrix_3_search;
      reg [63:0]          matrix_4_search;
      reg [31:0]          matrix_5_search;
      reg [15:0]          matrix_6_search;
      reg [7:0]           matrix_7_search;
      reg [3:0]           matrix_8_search;
      reg [1:0]           matrix_9_search;

      //Mux selection for the search matrix
      reg [9:0]           mux_sel;      

      begin : func_binsearch
         array_int = {1024{1'b0}};
         array_int[SLV_NUM_OUTSTND_WR_REQ-1: 0] = array_i[SLV_NUM_OUTSTND_WR_REQ-1: 0];

         matrix_0_search[1023:0] = array_int;

         mux_sel[9] = !(|matrix_0_search[511:0]);
         matrix_1_search[511:0] = mux_sel[9] ? matrix_0_search[1023:512] : matrix_0_search[511:0];
         
         mux_sel[8] = !(|matrix_1_search[255:0]);
         matrix_2_search[255:0] = mux_sel[8] ? matrix_1_search[511:256] : matrix_1_search[255:0];
         
         mux_sel[7] = !(|matrix_2_search[127:0]);
         matrix_3_search[127:0] = mux_sel[7] ? matrix_2_search[255:128] : matrix_2_search[127:0];
         
         mux_sel[6] = !(|matrix_3_search[63:0]);
         matrix_4_search[63:0]  = mux_sel[6] ? matrix_3_search[127:64]  : matrix_3_search[63:0];
         
         mux_sel[5] = !(|matrix_4_search[31:0]);
         matrix_5_search[31:0]  = mux_sel[5] ? matrix_4_search[63:32]   : matrix_4_search[31:0];
         
         mux_sel[4] = !(|matrix_5_search[15:0]);
         matrix_6_search[15:0]  = mux_sel[4] ? matrix_5_search[31:16]   : matrix_5_search[15:0];
         
         mux_sel[3] = !(|matrix_6_search[7:0]);
         matrix_7_search[7:0]   = mux_sel[3] ? matrix_6_search[15:8]    : matrix_6_search[7:0];
         
         mux_sel[2] = !(|matrix_7_search[3:0]);
         matrix_8_search[3:0]   = mux_sel[2] ? matrix_7_search[7:4]     : matrix_7_search[3:0];
         
         mux_sel[1] = !(|matrix_8_search[1:0]);
         matrix_9_search[1:0]   = mux_sel[1] ? matrix_8_search[3:2]     : matrix_8_search[1:0];
         
         mux_sel[0] = !matrix_9_search[0];

         binsearch[SLV_NUM_OUTSTND_WR_REQ_LOG2-1:0] = mux_sel[SLV_NUM_OUTSTND_WR_REQ_LOG2-1:0];
         
      end 
      
   endfunction



  `ifndef SYNTHESIS
  // ---------------------------------------------------------------------------
  //Enumnerate internal signal states
  // ---------------------------------------------------------------------------
  `endif // SYNTHESIS


endmodule
