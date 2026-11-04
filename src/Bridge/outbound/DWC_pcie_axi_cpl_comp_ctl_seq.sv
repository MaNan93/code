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
// ---    $Revision: #10 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/outbound/DWC_pcie_axi_cpl_comp_ctl_seq.sv#10 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// This module is designed to compose all responses that are belonged to the same request.
// A request can be split into several request based on the address boundary requirement,
// max payload of a transfer, etc. Each splited request can have several responses associated
// with because of PCIe split response feature. Therefore, a request can have multiple responses.
//
// The module is used in both transmit and receive directions of AXI bridge.
// Transmit Direction: When an AXI master issue a read request and its burst size is larger than
// PCIe MTU, then the AXI request will be split into few requests before these requests are transmited
// onto PCIe wire. A DWC_pcie_axi_cpl_comp_ctl will be placed to compose all responses received from PCIe wire.

// Receive Direction: When PCIe port recieved a read request and its burst size is larger than AXI MTU,
// then the request will be split into few AXI master transfers. An DWC_pcie_axi_cpl_comp_ctl will be placed to compose
// all responses received from AXI slave's responses.

// Composer are optional for both transmit and recieve direction. This is depended on customer's configuration.

//  The major features:
//  1. Using segment buffer to store all completion received according to application request ID (not the completion ID)
//     The number of segment = the number of max master read requests allowed in AXI system
//  2. All requests are served in order by allowing only the responses being read out of segment buffer i
//     for a request with a particular ID
//  2. A sub module trn_id_trn.v is loaded in this module to support ID and its attributes lookup.
//  3. trn_id_lut.v identifes whther or not all completions returned and provide some information that are associated to
//     a particular request. The infor involves length, read or write type.
//  4. Read of the segment buffer can be back-pressured when receiver of this completion data is not ready
//  5. Completions that are not expected will be dropped and an error will be reported.
//  6. Arbitration of the composed completion to be read is performed in this block. When it is not halted, the highest request ID gets to go first.
//     Once the arbitration decision has been made, it is required for reciver of the completion to take a full completion that is composed
//     Otherwise, the composed completion of higher priority channel can be blocked. This is designed for out of order services
//  7. If error happened during the recomposing of the completion, then the error status is notified to receiver of the completion
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
module DWC_pcie_axi_cpl_comp_ctl_seq (

// ----- Inputs  -----
    clk,
    rst_n,
    composed_seg,
    composed_seg_num,
    composed_seg_pseq,
    composed_seg_hold_preq,
    consumed_seg,
    last_tag_consumed,
    consumed_axi_id,
    consumed_out_tag,
    last_presp_rpseq_per_vc,
    trgt1_p_xfer_pend_per_vc,

// ----- Outputs -----

    active_tag,
    active_tag_valid

);

// =====================================================================================================================
// ---------------------- Parameters ------------------------
// =====================================================================================================================
parameter  TP                              = `TP;                         // Clock to Q delay
localparam MAX_OUT_TAG_PW                  = `CC_MAX_SLV_TAG_PW;          // pointer of MAX_OUT_TAG
localparam MAX_OUT_TAG                     = `CC_MAX_SLV_TAG;             // Number of MAX TAG that PKTs go out with
localparam SLV_ID_WD                       = `CC_SLV_BUS_ID_WIDTH+1;
localparam CC_AMBA_TLP_SEQ_WD              = `CC_AMBA_TLP_SEQ_WD;
localparam HALF_MAX_OUT_TAG                = MAX_OUT_TAG/2;
localparam HALF_MAX_OUT_TAG_PW             = MAX_OUT_TAG_PW-1;
localparam CX_NVC                          = `CX_NVC;
localparam CX_NVC_LOG2                     = `CX_NVC_LOG2;
localparam CC_ORDRB_NIDO                   = `CC_ORDRB_NIDO;
localparam CC_ORDRB_NIDO_WD                = `CC_ORDRB_NIDO_WD;
localparam HIERSEARCH_1ST_STAGE_SECTION_DP = ((`CC_MAX_SLV_TAG)>(`CC_AXI_HIERSEARCH_1ST_STAGE_SECTION_DP)) ? (`CC_AXI_HIERSEARCH_1ST_STAGE_SECTION_DP) : (`CC_MAX_SLV_TAG);
localparam HIERSEARCH_SECTION_NUM          = (`CC_MAX_SLV_TAG) / HIERSEARCH_1ST_STAGE_SECTION_DP;
localparam HIERSEARCH_1ST_STAGE_INDEX_WD   = (HIERSEARCH_1ST_STAGE_SECTION_DP>1) ? $clog2(HIERSEARCH_1ST_STAGE_SECTION_DP) : 1;
localparam HIERSEARCH_2ND_STAGE_SECTION_DP = HIERSEARCH_SECTION_NUM;
localparam HIERSEARCH_2ND_STAGE_INDEX_WD   = (HIERSEARCH_2ND_STAGE_SECTION_DP>1) ? $clog2(HIERSEARCH_2ND_STAGE_SECTION_DP) : 1;
localparam L_N_EXPLICIT_FANOUT             = 3; // Always use explicit fanout wiring widths

typedef struct packed {
  logic  [     MAX_OUT_TAG_PW-1:0] tag;
  logic                            valid;
  logic  [ CC_AMBA_TLP_SEQ_WD-1:0] pseq;
  logic                            hold_preq;
  logic                            hold_axi;
  logic  [     MAX_OUT_TAG_PW-1:0] hold_tag;
} cmp_seg_s;

typedef struct packed {
  logic  [          SLV_ID_WD-1:0] mid;
  logic  [     MAX_OUT_TAG_PW-1:0] tag;
  logic                            valid;
  logic                            halt;
} slv_req_s;

// =====================================================================================================================
// ---------------------- inputs ------------------
// =====================================================================================================================
input                                     clk;                    // clock
input                                     rst_n;                  // reset
input                                     composed_seg;
input   [MAX_OUT_TAG_PW-1:0]              composed_seg_num;
input   [CC_AMBA_TLP_SEQ_WD -1:0]         composed_seg_pseq;
input                                     composed_seg_hold_preq;
input   [L_N_EXPLICIT_FANOUT -1:0]        consumed_seg;
input                                     last_tag_consumed;      // Valid signal for the following signals
input   [SLV_ID_WD -1:0]                  consumed_axi_id;        // Original request AXI ID
input   [MAX_OUT_TAG_PW -1:0]             consumed_out_tag;       // Application generated tag
input   [CC_AMBA_TLP_SEQ_WD-1:0]          last_presp_rpseq_per_vc [CX_NVC-1:0];
input  [CX_NVC-1:0]                       trgt1_p_xfer_pend_per_vc;

// =====================================================================================================================
// ---------------------- outputs ------------------
// =====================================================================================================================
output  [MAX_OUT_TAG_PW -1:0]             active_tag;
output                                    active_tag_valid;

// =====================================================================================================================
// ---------------------- IO signal declarations ------------------------
// =====================================================================================================================
logic   [MAX_OUT_TAG_PW -1:0]             active_tag;
logic                                     active_tag_valid;

// =====================================================================================================================
// ---------------------- Internal signal declarations ------------------------
// =====================================================================================================================
wire    [MAX_OUT_TAG_PW -1:0]             s_active_tag;
wire                                      s_active_tag_valid;
wire    [MAX_OUT_TAG_PW -1:0]             s_active_tag_index;
wire    [L_N_EXPLICIT_FANOUT -1:0]        s_consumed_seg;

reg                                       r_last_tag_consumed;
reg     [SLV_ID_WD -1:0]                  r_consumed_axi_id;
reg     [MAX_OUT_TAG_PW -1:0]             r_consumed_out_tag;

slv_req_s [MAX_OUT_TAG-1:0]      slv_req_lut;
slv_req_s [MAX_OUT_TAG-1:0] next_slv_req_lut;
slv_req_s                    new_slv_req;

// =====================================================================================================================
// Signal declaration for outstanding (not scheduled) completions queue

reg [MAX_OUT_TAG   -1:0] app_tag_add;
reg [MAX_OUT_TAG   -1:0] app_tag_remove;
reg [MAX_OUT_TAG   -1:0] app_tag_shift_up;
reg [MAX_OUT_TAG   -1:0] app_tag_shift_down;
reg [MAX_OUT_TAG   -1:0] app_tag_clear_halt;
reg [MAX_OUT_TAG_PW-1:0] app_tag_cleared_halt_tag;
reg [MAX_OUT_TAG   -1:0] app_tag_set_halt;
reg [MAX_OUT_TAG   -1:0] stored_mid_gt_consumed_axi_id;
reg [MAX_OUT_TAG   -1:0] stored_mid_gt_released_mid;
reg [SLV_ID_WD     -1:0] s_released_mid;

logic                      composed_seg_hold_axi;
logic [MAX_OUT_TAG_PW-1:0] composed_seg_hold_tag;

logic   [MAX_OUT_TAG_PW -1:0]     r_released_tag;
logic                             r_released_tag_valid;

logic   [MAX_OUT_TAG_PW -1:0]     r_active_tag;
logic                             r_active_tag_consumed;

logic                             r_composed_seg;
logic   [MAX_OUT_TAG_PW-1:0]      r_composed_seg_num;
logic   [CC_AMBA_TLP_SEQ_WD -1:0] r_composed_seg_pseq;
logic                             r_composed_seg_hold_preq;

logic                             s_composed_seg_hold_axi;
logic   [MAX_OUT_TAG_PW-1:0]      s_composed_seg_hold_tag;

logic                             s_composed_seg;
logic   [MAX_OUT_TAG_PW-1:0]      s_composed_seg_num;
logic   [CC_AMBA_TLP_SEQ_WD -1:0] s_composed_seg_pseq;
logic                             s_composed_seg_hold_preq;

// =====================================================================================================================
// Signal declaration for composed completions queue

reg  [     MAX_OUT_TAG_PW-1:0]      cmp_seg_queue_wr_ptr;
reg  [     MAX_OUT_TAG_PW-1:0] next_cmp_seg_queue_wr_ptr;

cmp_seg_s     [MAX_OUT_TAG-1:0]       cmp_seg_queue;
cmp_seg_s     [MAX_OUT_TAG-1:0]  next_cmp_seg_queue;
cmp_seg_s                         new_cmp_seg;

// =====================================================================================================================
// Signal declaration for hierarchical mux search
logic [               MAX_OUT_TAG_PW-1:0]   hiermux_1st_stage_hold_tag_out   [HIERSEARCH_SECTION_NUM-1:0];
logic [       HIERSEARCH_SECTION_NUM-1:0]   hiermux_1st_stage_hold_axi_out;
logic [               MAX_OUT_TAG_PW-1:0] r_hiermux_1st_stage_hold_tag_out   [HIERSEARCH_SECTION_NUM-1:0];
logic [       HIERSEARCH_SECTION_NUM-1:0] r_hiermux_1st_stage_hold_axi_out;

// =====================================================================================================================
// Signal declaration for staged binary search
logic [                  MAX_OUT_TAG-1:0] s_cmp_seg_queue_valid;
logic [               MAX_OUT_TAG_PW-1:0] s_cmp_seg_queue_tag   [MAX_OUT_TAG-1:0];

logic [       HIERSEARCH_SECTION_NUM-1:0] binsearch_1st_stage_valid_out;
logic [HIERSEARCH_1ST_STAGE_INDEX_WD-1:0] binsearch_1st_stage_index_out [HIERSEARCH_SECTION_NUM-1:0];
logic [               MAX_OUT_TAG_PW-1:0] binsearch_1st_stage_tag_out   [HIERSEARCH_SECTION_NUM-1:0];
logic                                     binsearch_2nd_stage_valid_out;
logic [HIERSEARCH_2ND_STAGE_INDEX_WD-1:0] binsearch_2nd_stage_index_out;
logic [               MAX_OUT_TAG_PW-1:0] binsearch_2nd_stage_tag_out;
logic                                     active_tag_1stage_search_valid;
logic [               MAX_OUT_TAG_PW-1:0] active_tag_1stage_search_index;
logic [               MAX_OUT_TAG_PW-1:0] active_tag_1stage_search_tag;
logic                                     active_tag_2stage_search_valid;
logic [               MAX_OUT_TAG_PW-1:0] active_tag_2stage_search_index;
logic [               MAX_OUT_TAG_PW-1:0] active_tag_2stage_search_tag;

logic [       HIERSEARCH_SECTION_NUM-1:0] r_binsearch_1st_stage_valid_out;
logic [HIERSEARCH_1ST_STAGE_INDEX_WD-1:0] r_binsearch_1st_stage_index_out [HIERSEARCH_SECTION_NUM-1:0];
logic [               MAX_OUT_TAG_PW-1:0] r_binsearch_1st_stage_tag_out   [HIERSEARCH_SECTION_NUM-1:0];
logic                                     active_tag_2stage_search_mask;


always @(posedge clk or negedge rst_n) begin : SEQ_R_CONSUMED_TAG_PROC
  if (!rst_n) begin
    r_last_tag_consumed <= #TP 1'b0;
    r_consumed_axi_id   <= #TP {(SLV_ID_WD){1'b0}};
    r_consumed_out_tag  <= #TP {(MAX_OUT_TAG_PW){1'b0}};
  end else begin
    r_last_tag_consumed <= #TP last_tag_consumed;
    r_consumed_axi_id   <= #TP consumed_axi_id;
    r_consumed_out_tag  <= #TP consumed_out_tag;
  end
end

always_comb begin : COMB_NEW_SLV_REQ_PROC
  new_slv_req.mid   = r_consumed_axi_id;
  new_slv_req.tag   = r_consumed_out_tag;
  new_slv_req.valid = '1;
  new_slv_req.halt  = '0;
end

// Pipeline stage between cmp_seg_queue and slv_req_lut
always_ff @(posedge clk, negedge rst_n) begin: SEQ_R_ACTIVE_TAG_PROC
  if (!rst_n) begin
    r_active_tag_consumed <= #TP '0;
    r_active_tag          <= #TP '0;
  end else begin
    r_active_tag_consumed <= #TP s_active_tag_valid && s_consumed_seg[0];
    r_active_tag          <= #TP s_active_tag;
  end
end: SEQ_R_ACTIVE_TAG_PROC

// =====================================================================================================================
// Outstanding completions look up table, used to store:
// - the ID of the original AXI request
// - the individual app tag assigned to every AXI request
// - the status of each individual request (halted or not)
//
// This Look-Up Table is required to ensure the ordering of responses with the same AXI ID; the requests are ordered per
// AXI ID first and in chronological order second. In other words the request at the top of the table is the oldest one
// for the lowest AXI ID in the table; the last one is the newest request with the highest AXI ID in the table.
// The LUT is neither a FIFO nor a stack; entries can be removed from the middle of the table, when that happens all the
// entries from that point downwards need to be shifted up; entries can be added at any point in the table, when that
// happens all the existing entries from that point downwards need to be shifted down by one position.
// New entries are written into the LUT when r_last_tag_consumed is asserted
// Existing entries are removed from the LUT when composed_seg is asserted 

// =====================================================================================================================
// App tag look up table entries where the AXI ID is greater than the AXI ID for a new request; this is a straight
// comparison of the AXI ID of the new request with the value of the AXI ID in every LUT entry

always @(*) begin : COMB_STORED_MID_GT_CONSUMED_AXI_ID_PROC

  integer i;

  stored_mid_gt_consumed_axi_id = {MAX_OUT_TAG{1'b0}};
  
  for(i=0; i < MAX_OUT_TAG; i=i+1)
    if(r_last_tag_consumed && (slv_req_lut[i].mid>r_consumed_axi_id) && (slv_req_lut[i].valid==1))
      stored_mid_gt_consumed_axi_id[i] = 1;

end

// =====================================================================================================================
// App tag look up table entries where the AXI ID is greater or equal to the AXI ID for a scheduled completion; this is
// a straight comparison of the AXI ID of the scheduled completion with the AXI ID value in every LUT entry

always @(*) begin : COMB_RELEASED_MID_PROC

  integer i;
  
  s_released_mid = {SLV_ID_WD{1'b0}};

  for(i=0; i < MAX_OUT_TAG; i=i+1)
    if(r_active_tag_consumed && (slv_req_lut[i].tag==r_active_tag) && (slv_req_lut[i].valid==1))
      s_released_mid = slv_req_lut[i].mid;

end

always @(*) begin : COMB_STORED_MID_GT_RELEASED_MID_PROC

  integer i;

  stored_mid_gt_released_mid = {MAX_OUT_TAG{1'b0}};
  
  for(i=0; i < MAX_OUT_TAG; i=i+1)
    if(r_active_tag_consumed && (slv_req_lut[i].mid>=s_released_mid) && (slv_req_lut[i].valid==1))
      stored_mid_gt_released_mid[i] = 1;

end

// =====================================================================================================================
// Scheduled completion position in the outstanding completions look up table; this is determined by comparing the 
// tag of a scheduled request with the tag of every entry in the outstanding completions look up table

always @(*) begin : COMB_APP_TAG_REMOVE_PROC

  integer i;

  app_tag_remove       = {MAX_OUT_TAG{1'b0}};

  for(i=0; i < MAX_OUT_TAG; i=i+1) begin
    if(i < (MAX_OUT_TAG-1)) begin
      if(r_active_tag_consumed && slv_req_lut[i].valid && !r_last_tag_consumed && !slv_req_lut[i+1].valid )
        app_tag_remove[i] = 1;
    end else begin
      if(r_active_tag_consumed && slv_req_lut[i].valid && !r_last_tag_consumed )
        app_tag_remove[i] = 1;
    end
  end

end

// =====================================================================================================================
// Outstanding completions look up table position where the current request is going to be stored; this is the first
// position where the stored AXI ID is greater than the AXI ID of the new request
// If the 

always @(*) begin : COMB_APP_TAG_ADD_PROC

  integer i;

  app_tag_add      = {MAX_OUT_TAG{1'b0}};
  app_tag_set_halt = {MAX_OUT_TAG{1'b0}};
  
  if((r_last_tag_consumed && !slv_req_lut[0].valid) ||                                                                  // if a new request is received and the look up table is empty or 
      stored_mid_gt_consumed_axi_id[0]) begin                                                                           // the AXI ID at the first position is greater than the AXI ID for the new request
    app_tag_add[0] = 1;                                                                                                 //   the new request is inserted at position 0
  end                                                                                                                   //   and the halt is not set
                                                                                                                        //
  for(i=0; i < (MAX_OUT_TAG-1); i=i+1)                                                                                  //
    if(  r_last_tag_consumed &&                                                                                         // if a new request is received (tag consumed) and
       ((!slv_req_lut[i+1].valid && slv_req_lut[i].valid && !stored_mid_gt_consumed_axi_id[i]) ||                       // we are at the last valid entry and the AXI ID is not greater than the AXI ID for the new request or  
        (stored_mid_gt_consumed_axi_id[i+1] && !stored_mid_gt_consumed_axi_id[i]))) begin                               // the AXI ID at the current position is not greater than the AXI for the new request but the AXI ID for the next position is
      if(stored_mid_gt_released_mid[i]) begin                                                                           //   if the AXI at the current position is greater than the scheduled AXI ID the entry at this position is being shifted up so 
        app_tag_add[i] = 1;                                                                                             //     the new request is inserted at the current position
        if((slv_req_lut[i].mid==r_consumed_axi_id) &&                                                                   //     if the AXI ID for the new request is the same as the one at this position and 
           (slv_req_lut[i].tag != r_active_tag))                                                                        //     the entry at this position is not the scheduled one
          app_tag_set_halt[i]=1;                                                                                        //       set the halt flag for the new entry
      end else begin                                                                                                    //   else (no scheduled entry or its AXI ID is greater than the one at the current position) 
        app_tag_add[i+1] = 1;                                                                                           //     the new request is inserted at the following position
        if(slv_req_lut[i].mid==r_consumed_axi_id)                                                                       //     if the AXI ID for the new request is the same as the one for the entry in this position
          app_tag_set_halt[i+1]=1;                                                                                      //       set the halt flag for the new entry
      end                                                                                                               //
    end                                                                                                                 //

end

// =====================================================================================================================
// App tag look up table entries that need to be shifted down; these are all the entries where the AXI ID is greater
// than the AXI ID for a new request and smaller than the AXI ID for a recycled tag

always @(*) begin : COMB_APP_TAG_SHIFT_DOWN_PROC

  integer i;

  app_tag_shift_down = {MAX_OUT_TAG{1'b0}};

  for(i=0; i < MAX_OUT_TAG; i=i+1)
    if(stored_mid_gt_consumed_axi_id[i] && !stored_mid_gt_released_mid[i])
      app_tag_shift_down[i] = 1;

end

// =====================================================================================================================
// App tag look up table entries that need to be shifted down; these are all the entries where the AXI ID is greater or 
// equal to the AXI ID for a recycled tag (except for the recycled tag entry) and smaller or equal to the AXI ID for a
// new request

always @(*) begin : COMP_APP_TAG_SHIFT_UP_PROC

  integer i;

  app_tag_shift_up = {MAX_OUT_TAG{1'b0}};

  for(i=0; i < MAX_OUT_TAG; i=i+1)
    if(!stored_mid_gt_consumed_axi_id[i] && stored_mid_gt_released_mid[i] && (slv_req_lut[i].tag != r_active_tag))
      app_tag_shift_up[i] = 1;

end

always @(*) begin

  integer i;

  app_tag_clear_halt       = '0;
  app_tag_cleared_halt_tag = '0;

  for(i=1; i < MAX_OUT_TAG; i=i+1) begin
    if(r_active_tag_consumed && (slv_req_lut[i].mid==slv_req_lut[i-1].mid) && (slv_req_lut[i-1].tag == r_active_tag) && slv_req_lut[i].valid) begin
      app_tag_clear_halt[i]    = 1;
      app_tag_cleared_halt_tag = slv_req_lut[i].tag;
    end
  end
end

always_comb begin : COMB_SLV_REQ_LUT_PROC

  integer i;

  next_slv_req_lut = slv_req_lut;

  if (app_tag_add[0]) begin
    next_slv_req_lut[0]       = new_slv_req;
  end else if (app_tag_remove[0]) begin
    next_slv_req_lut[0]       = '0;          
  end else if (app_tag_shift_up[1]) begin
    next_slv_req_lut[0]       = slv_req_lut[1];
    next_slv_req_lut[0].halt  = '0;
  end

  for( i=1; i < MAX_OUT_TAG ; i=i+1) begin

    if( i < (MAX_OUT_TAG-1) ) begin

      if (app_tag_add[i]) begin
        next_slv_req_lut[i]       = new_slv_req;
        next_slv_req_lut[i].halt  = app_tag_set_halt[i];
      end

      else if (app_tag_shift_up[i+1]) begin
        next_slv_req_lut[i]       = slv_req_lut[i+1];
        next_slv_req_lut[i].halt  = slv_req_lut[i+1].halt && !app_tag_clear_halt[i+1];
      end else if (app_tag_shift_up[i] && (!slv_req_lut[i+1].valid || (i == (MAX_OUT_TAG-1))))
        next_slv_req_lut[i]       = '0;          

      else if (app_tag_shift_down[i-1])
        next_slv_req_lut[i]       = slv_req_lut[i-1];

      else if (app_tag_clear_halt[i])
        next_slv_req_lut[i].halt  = '0;

      else if (app_tag_remove[i])
        next_slv_req_lut[i]       = '0;          

    end else begin

      if (app_tag_add[i]) begin
        next_slv_req_lut[i]       = new_slv_req;
        next_slv_req_lut[i].halt  = app_tag_set_halt[i];
      end

      else if (app_tag_shift_up[i])
        next_slv_req_lut[i]       = '0;          

      else if (app_tag_shift_down[i-1])
        next_slv_req_lut[i]       = slv_req_lut[i-1];

      else if (app_tag_clear_halt[i])
        next_slv_req_lut[i].halt  = '0;

      else if (app_tag_remove[i])
        next_slv_req_lut[i]       = '0;          

    end

  end

end

always_ff @(posedge clk, negedge rst_n) begin: SEQ_SLV_REQ_LUT_PROC
  if (!rst_n) begin
    slv_req_lut <= #TP '0;
  end else begin
    slv_req_lut <= #TP next_slv_req_lut;
  end
end

// Outstanding completions list
// =====================================================================================================================

generate

  if (HIERSEARCH_SECTION_NUM==1) begin : GEN_AXI_COMPOSED_SEG_HOLD_AXI_STAGE_SEARCH

    always_comb begin: COMB_COMPOSED_SEG_HOLD_ONE_STAGE_SEARCH_PROC

      integer i;

      composed_seg_hold_axi = '0;
      composed_seg_hold_tag = '0;

      for (i=0; i < MAX_OUT_TAG; i=i+1 )
        if((slv_req_lut[i].tag == composed_seg_num) && slv_req_lut[i].valid && slv_req_lut[i].halt) begin
          composed_seg_hold_axi = 1'b1;
          composed_seg_hold_tag =  (i==0) ? '0 : slv_req_lut[i-1].tag;
        end

    end

    assign s_composed_seg           = composed_seg;
    assign s_composed_seg_num       = composed_seg_num;
    assign s_composed_seg_pseq      = composed_seg_pseq;
    assign s_composed_seg_hold_preq = composed_seg_hold_preq;
    assign s_composed_seg_hold_axi  = composed_seg_hold_axi;
    assign s_composed_seg_hold_tag  = composed_seg_hold_tag;

  end else begin : GEN_AXI_COMPOSED_SEG_HOLD_TWO_STAGE_SEARCH

    always_comb begin: COMB_HIERMUX_1ST_STAGE_SEARCH_PROC

      integer i,j,k;

      for(i=0;i<HIERSEARCH_SECTION_NUM;i=i+1) begin 
        hiermux_1st_stage_hold_axi_out[i] = '0;
        hiermux_1st_stage_hold_tag_out[i] = '0;
      end

      for(j=0;j<HIERSEARCH_SECTION_NUM;j=j+1) begin 
        for(k=0;k<HIERSEARCH_1ST_STAGE_SECTION_DP;k=k+1) begin 
          if((slv_req_lut[j*HIERSEARCH_1ST_STAGE_SECTION_DP+k].tag == composed_seg_num) && slv_req_lut[j*HIERSEARCH_1ST_STAGE_SECTION_DP+k].valid && slv_req_lut[j*HIERSEARCH_1ST_STAGE_SECTION_DP+k].halt)begin
            hiermux_1st_stage_hold_axi_out[j] = 1'b1;
            hiermux_1st_stage_hold_tag_out[j] = (j==0 && k==0) ? '0 : slv_req_lut[j*HIERSEARCH_1ST_STAGE_SECTION_DP+k-1].tag;
          end
        end
      end

    end:COMB_HIERMUX_1ST_STAGE_SEARCH_PROC

    always_ff @(posedge clk, negedge rst_n) begin: SEQ_R_HIERMUX_1ST_STAGE_SEARCH_PROC

      integer i,j;

      if (!rst_n) begin
        for(i=0;i<HIERSEARCH_SECTION_NUM;i=i+1) begin 
          r_hiermux_1st_stage_hold_tag_out[i] <= #TP '0;
          r_hiermux_1st_stage_hold_axi_out[i] <= #TP '0;
        end
      end else begin
        for(j=0;j<HIERSEARCH_SECTION_NUM;j=j+1) begin 
          r_hiermux_1st_stage_hold_tag_out[j] <= #TP hiermux_1st_stage_hold_tag_out[j];
          r_hiermux_1st_stage_hold_axi_out[j] <= #TP hiermux_1st_stage_hold_axi_out[j];
        end
      end
    end: SEQ_R_HIERMUX_1ST_STAGE_SEARCH_PROC

    // Delaying composed_seg information by one clock cycle to align with hierarchical mux output
    always_ff @(posedge clk, negedge rst_n) begin: SEQ_R_COMPOSED_SEG_PROC
      if (!rst_n) begin
        r_composed_seg           <= #TP '0;
        r_composed_seg_num       <= #TP '0;
        r_composed_seg_pseq      <= #TP '0;
        r_composed_seg_hold_preq <= #TP '0;
      end else begin
        r_composed_seg           <= #TP composed_seg;
        r_composed_seg_num       <= #TP composed_seg_num;
        r_composed_seg_pseq      <= #TP composed_seg_pseq;
        r_composed_seg_hold_preq <= #TP composed_seg_hold_preq;
      end
    end: SEQ_R_COMPOSED_SEG_PROC

    // Delaying released tag information by one clock cycle to align with hierarchical mux output
    always_ff @(posedge clk, negedge rst_n) begin: SEQ_R_RELEASED_TAG_PROC
      if (!rst_n) begin
        r_released_tag_valid <= #TP '0;
        r_released_tag       <= #TP '0;
      end else begin
        r_released_tag_valid <= #TP r_active_tag_consumed;
        r_released_tag       <= #TP r_active_tag;
      end
    end: SEQ_R_RELEASED_TAG_PROC

    always_comb begin: COMB_S_COMPOSED_SEG_HOLD_AXI_PROC

      integer i;

      s_composed_seg_hold_axi = '0;
      s_composed_seg_hold_tag = '0;
      
      for(i=0;i<HIERSEARCH_SECTION_NUM;i=i+1)begin 
        if(r_hiermux_1st_stage_hold_axi_out[i] &&
           !(r_active_tag_consumed && (r_active_tag   == r_hiermux_1st_stage_hold_tag_out[i])) &&
           !(r_released_tag_valid  && (r_released_tag == r_hiermux_1st_stage_hold_tag_out[i]))
          )begin
          s_composed_seg_hold_axi = r_hiermux_1st_stage_hold_axi_out[i];
          s_composed_seg_hold_tag = r_hiermux_1st_stage_hold_tag_out[i];
        end
      end

    end: COMB_S_COMPOSED_SEG_HOLD_AXI_PROC

    assign s_composed_seg           = r_composed_seg;
    assign s_composed_seg_num       = r_composed_seg_num;
    assign s_composed_seg_pseq      = r_composed_seg_pseq;
    assign s_composed_seg_hold_preq = r_composed_seg_hold_preq;

  end

endgenerate


// =====================================================================================================================
// When a segment is composed we write P ordering information into the composed segment queue
// AXI ID ordering information is retrieved from the outstanding completions lookup table

always_comb begin : COMB_NEW_CMP_SEG_PROC
  new_cmp_seg.valid     = '1;
  new_cmp_seg.tag       = s_composed_seg_num;
  new_cmp_seg.pseq      = s_composed_seg_pseq;
  new_cmp_seg.hold_preq = s_composed_seg_hold_preq;
  new_cmp_seg.hold_axi  = s_composed_seg_hold_axi;
  new_cmp_seg.hold_tag  = s_composed_seg_hold_tag;
end

// =====================================================================================================================
// Composed completions queue
// This queue stores the completions that have been fully composed; completions can be halted by older inbound P 
// requests or previous slave requests with same AXI that haven't completed yet
// The completions are written into this queue as they become available and are read as they become unhalted


always @(*) begin: COMB_CMP_SEG_QUEUE_PROC

  integer i,j,k,l;

  reg [CC_AMBA_TLP_SEQ_WD-1:0] tmp_pkt_pseq;
  reg [CC_AMBA_TLP_SEQ_WD-1:0] tmp_last_presp_per_vc;
  reg                          tmp_range_reversal_vc;
  reg [CC_AMBA_TLP_SEQ_WD-1:0] tmp_p_pseq_upper_lim_vc;
  reg [CC_AMBA_TLP_SEQ_WD-1:0] tmp_p_pseq_lower_lim_vc;
  reg [CC_AMBA_TLP_SEQ_WD-1:0] tmp_pkt_pseq_vc;
  reg                          tmp_cpl_rlsd_per_vc;
  reg                          tmp_p_xfer_pend_per_vc;

  next_cmp_seg_queue_wr_ptr                           = cmp_seg_queue_wr_ptr;
  next_cmp_seg_queue                                  = cmp_seg_queue;

  if(s_consumed_seg[0]) begin                                                    // If a segment has been consumed
    for ( j=0; j < (MAX_OUT_TAG-1); j=j+1)                                       //
      if ( (j >= s_active_tag_index ) && (j < cmp_seg_queue_wr_ptr) ) begin      //
        next_cmp_seg_queue[j]                         = cmp_seg_queue[j+1];      //   move all subsequent segments up the queue
      end
  end

  if (s_consumed_seg[1]) begin                                                   // If a segment has been consumed
    if (s_composed_seg) begin                                                    //   if a new segment is composed at the same time 
      next_cmp_seg_queue[cmp_seg_queue_wr_ptr]        = new_cmp_seg;             //   write it into the LUT at the same last position as before (cmp_seg_queue_wr_ptr)
    end else begin                                                               //   else clear the entry at cmp_seg_queue_wr_ptr
      next_cmp_seg_queue[cmp_seg_queue_wr_ptr]        = '0;                      //
      if (cmp_seg_queue_wr_ptr > 0)                                              //   and if cmp_seg_queue_wr_ptr is bigger than 0 
        next_cmp_seg_queue_wr_ptr                     = cmp_seg_queue_wr_ptr -1; //     decrement it
    end                                                                          //
  end

  if (~s_consumed_seg[2]) begin                                                  // If no segment consumed
    if (s_composed_seg) begin                                                    //   if a new segment is composed
      if((cmp_seg_queue_wr_ptr == 0) && (cmp_seg_queue[0].valid == 0)) begin     //     if the FIFO is empty do not increment push pointer and write the new segment into position 0
        next_cmp_seg_queue_wr_ptr                     = cmp_seg_queue_wr_ptr;    //       do not increment the write pointer, write to position 0
      end else begin                                                             //     else (the FIFO is not empty) increment the push pointer and write the new segment into that position
        next_cmp_seg_queue_wr_ptr                     = cmp_seg_queue_wr_ptr+1;  //       increment the write pointer
      end                                                                        //
        next_cmp_seg_queue[next_cmp_seg_queue_wr_ptr] = new_cmp_seg;             //     write into the position indicated by previously calculated push pointer
    end                                                                          //
  end                                                                            //

  for ( k=0; k < MAX_OUT_TAG ; k=k+1) begin

    tmp_pkt_pseq            = next_cmp_seg_queue[k].pseq;

    tmp_last_presp_per_vc   = last_presp_rpseq_per_vc[0];
    tmp_p_xfer_pend_per_vc  = trgt1_p_xfer_pend_per_vc[0];
 
    // check if MSB values need to be reversed before comparison can be made
    tmp_range_reversal_vc   = ( tmp_last_presp_per_vc[CC_AMBA_TLP_SEQ_WD-1] == 0 );

    // calculate the upper and lower comparison range limits based on whether or not MSB reversal is required
    tmp_p_pseq_upper_lim_vc = tmp_range_reversal_vc ? {!tmp_last_presp_per_vc[CC_AMBA_TLP_SEQ_WD-1],tmp_last_presp_per_vc[CC_AMBA_TLP_SEQ_WD-2:0]} : tmp_last_presp_per_vc;
    tmp_p_pseq_lower_lim_vc = tmp_range_reversal_vc ? tmp_last_presp_per_vc : {!tmp_last_presp_per_vc[CC_AMBA_TLP_SEQ_WD-1],tmp_last_presp_per_vc[CC_AMBA_TLP_SEQ_WD-2:0]};

    // update the sequence number depending on whether or not MSB reversal is required
    tmp_pkt_pseq_vc         = tmp_range_reversal_vc ? {!tmp_pkt_pseq        [CC_AMBA_TLP_SEQ_WD-1],tmp_pkt_pseq        [CC_AMBA_TLP_SEQ_WD-2:0]} : tmp_pkt_pseq;

    tmp_cpl_rlsd_per_vc     = ( ( ( tmp_pkt_pseq_vc       <= tmp_p_pseq_upper_lim_vc ) && 
                                  ( tmp_pkt_pseq_vc       >  tmp_p_pseq_lower_lim_vc )    ) ||
                                  !tmp_p_xfer_pend_per_vc                                      )
;

    if(next_cmp_seg_queue[k].valid && (tmp_cpl_rlsd_per_vc ))
      next_cmp_seg_queue[k].hold_preq = 1'b0;
  end


  
  for ( l=0; l < MAX_OUT_TAG; l=l+1) begin
    if((s_active_tag_valid && s_consumed_seg[1]) && (next_cmp_seg_queue[l].hold_tag == s_active_tag) || 
       (r_active_tag_consumed                  ) && (next_cmp_seg_queue[l].hold_tag == r_active_tag) )
      next_cmp_seg_queue[l].hold_axi = 1'b0;
  end
  
   
end

always_ff @(posedge clk, negedge rst_n) begin: SEQ_CMP_SEG_QUEUE_PROC
  if (!rst_n) begin
    cmp_seg_queue_wr_ptr <= #TP '0;
    cmp_seg_queue        <= #TP '0;
  end else begin
    cmp_seg_queue_wr_ptr <= #TP next_cmp_seg_queue_wr_ptr;
    cmp_seg_queue        <= #TP next_cmp_seg_queue;
  end
end

// Scheduled composed completions FIFO
// =====================================================================================================================


// =====================================================================================================================
// Multi-stage binary search

always_comb begin : COMP_S_CMP_SEQ_QUEUE_TAG_PROC

  integer i;
  
  for ( i=0; i < MAX_OUT_TAG; i=i+1) begin
    s_cmp_seg_queue_valid[i] = cmp_seg_queue[i].valid && !cmp_seg_queue[i].hold_preq && !cmp_seg_queue[i].hold_axi;
    s_cmp_seg_queue_tag  [i] = cmp_seg_queue[i].tag;
  end
  
end

generate

  genvar gi;

  for (gi=0; gi<HIERSEARCH_SECTION_NUM; gi=gi+1) begin : GEN_BINSEARCH_ARRAY

    DWC_pcie_bridge_binsearch
    
     #(
       .ARRAY_DP  (HIERSEARCH_1ST_STAGE_SECTION_DP),
       .ARRAY_WD  (MAX_OUT_TAG_PW                 ),
       .INDEX_WD  (HIERSEARCH_1ST_STAGE_INDEX_WD  )
      ) u_binsearch_1st_stage (
       .valid_in    (s_cmp_seg_queue_valid[(gi+1)*HIERSEARCH_1ST_STAGE_SECTION_DP-1:gi*HIERSEARCH_1ST_STAGE_SECTION_DP]),
       .array_in    (s_cmp_seg_queue_tag  [(gi+1)*HIERSEARCH_1ST_STAGE_SECTION_DP-1:gi*HIERSEARCH_1ST_STAGE_SECTION_DP]),
       .valid_out   (binsearch_1st_stage_valid_out[gi]                                                                 ),
       .index_out   (binsearch_1st_stage_index_out[gi]                                                                 ),
       .element_out (binsearch_1st_stage_tag_out[gi]                                                                   )
      );

  end

  if (HIERSEARCH_SECTION_NUM>1) begin : GEN_MULTI_SECTION_HIER_SEARCH // multiple binary search sections so two stage search

    // Register the output of the 1st stage binary search instances
    always_ff @(posedge clk, negedge rst_n) begin

      integer i,j;
      
      if(!rst_n)begin
        for(i=0;i<HIERSEARCH_SECTION_NUM;i=i+1) begin
          r_binsearch_1st_stage_index_out[i] <= #TP '0;
          r_binsearch_1st_stage_tag_out[i]   <= #TP '0;
        end
        r_binsearch_1st_stage_valid_out <= #TP '0;
      end else begin
        for(j=0;j<HIERSEARCH_SECTION_NUM;j=j+1) begin
          if(j==0)begin
            r_binsearch_1st_stage_index_out[j] <= #TP '0;
            r_binsearch_1st_stage_tag_out[j]   <= #TP '0;
          end else begin
            r_binsearch_1st_stage_index_out[j] <= #TP binsearch_1st_stage_index_out[j];
            r_binsearch_1st_stage_tag_out[j]   <= #TP binsearch_1st_stage_tag_out[j];
          end
        end
        r_binsearch_1st_stage_valid_out <= #TP {binsearch_1st_stage_valid_out[HIERSEARCH_SECTION_NUM-1:1],1'b0};
      end
    end

    // Implement second stage binary search; the first section of the first stage is not an input 
    // to the second stage because it implements a single stage search by itself
    DWC_pcie_bridge_binsearch
    
     #(
       .ARRAY_DP  (HIERSEARCH_2ND_STAGE_SECTION_DP),
       .ARRAY_WD  (MAX_OUT_TAG_PW                 ),
       .INDEX_WD  (HIERSEARCH_2ND_STAGE_INDEX_WD  )
      ) u_binsearch_2nd_stage (
       .valid_in    ( r_binsearch_1st_stage_valid_out ),
       .array_in    ( r_binsearch_1st_stage_tag_out   ),
       .index_out   (   binsearch_2nd_stage_index_out ),
       .valid_out   (   binsearch_2nd_stage_valid_out ),
       .element_out (   binsearch_2nd_stage_tag_out   )
      );

    // Check if we have a valid entry on the single stage search (the first binary search instance of the first stage array)
    assign active_tag_1stage_search_valid = binsearch_1st_stage_valid_out[0];
    assign active_tag_1stage_search_index = {{(HIERSEARCH_2ND_STAGE_INDEX_WD){1'b0}},binsearch_1st_stage_index_out[0]};
    assign active_tag_1stage_search_tag   = binsearch_1st_stage_tag_out[0];

    // Check if we have a valid entry on the two stage search
    assign active_tag_2stage_search_valid =  binsearch_2nd_stage_valid_out;
    assign active_tag_2stage_search_index = {binsearch_2nd_stage_index_out,r_binsearch_1st_stage_index_out[binsearch_2nd_stage_index_out]};
    assign active_tag_2stage_search_tag   =  binsearch_2nd_stage_tag_out;

    // Single stage search result takes priority over two stage search
    assign s_active_tag_valid = active_tag_1stage_search_valid || (active_tag_2stage_search_valid && !active_tag_2stage_search_mask);
    assign s_active_tag_index = s_active_tag_valid ? ( active_tag_1stage_search_valid ? active_tag_1stage_search_index : active_tag_2stage_search_index) : '0;
    assign s_active_tag       = s_active_tag_valid ? ( active_tag_1stage_search_valid ? active_tag_1stage_search_tag   : active_tag_2stage_search_tag  ) : '0;

    // Two stage search result needs to be masked for one clock cycle after an entry is taken from the queue
    always_ff @(posedge clk, negedge rst_n) begin : SEQ_ACTIVE_TAG_2STAGE_SEARCH_MASK_PROC
      if (!rst_n)
        active_tag_2stage_search_mask <= #TP 1'b0;
      else
        active_tag_2stage_search_mask <= #TP s_active_tag_valid && s_consumed_seg[2];
    end 

  end else begin : GEN_SINGLE_SECTION_SEARCH // Only one binary search section so single stage search

    assign s_active_tag_valid = binsearch_1st_stage_valid_out[0];
    assign s_active_tag_index = s_active_tag_valid ? binsearch_1st_stage_index_out[0] : '0;
    assign s_active_tag       = s_active_tag_valid ? binsearch_1st_stage_tag_out[0]   : '0;

  end
endgenerate

always_ff @(posedge clk, negedge rst_n) begin: SEQ_ACTIVE_TAG_PROC
  if (!rst_n) begin
    active_tag       <= # TP '0;
    active_tag_valid <= # TP '0;
  end else begin
    if(!active_tag_valid || consumed_seg[0])begin
      active_tag       <= # TP s_active_tag;
      active_tag_valid <= # TP s_active_tag_valid;
    end
  end
end



assign s_consumed_seg = {L_N_EXPLICIT_FANOUT{s_active_tag_valid}} & (~{L_N_EXPLICIT_FANOUT{active_tag_valid}} | consumed_seg);

endmodule

