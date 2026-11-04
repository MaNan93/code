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
// ---    $Revision: #12 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/slave/DWC_pcie_axi_slv_tag_mngr.sv#12 $
// -------------------------------------------------------------------------
// ----------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
//  The main funcions are:
//
//  1. Generation of a tag per non-posted request (signal atm_np_tag)
//  2. Responsibility for the return order by providing the select signal
//     to packet composer and selecting a set of responses with a particular TAG
//     (signal atm_cpl_seg_halt)
//  3. Returns AXI ID based on response TAG (signal atm_np_id)
//  4. Look-up table between PCIe and AXI
//
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 module DWC_pcie_axi_slv_tag_mngr
 #(
  // -------------------------------------------------------------------------------------
  // Parameters modified by an instantiation parameter assignment
  // -------------------------------------------------------------------------------------
  parameter SLV_BUS_ID_WIDTH                 = 5,
  parameter SLV_BURST_LEN_PW                 = 2,
  parameter SLV_BUS_STRB_PW                  = 4,
  parameter MAX_SLV_TAG                      = 4,
  parameter MAX_SLV_TAG_PW                   = 2,
  // -------------------------------------------------------------------------------------
  // Parameters not modified by an instantiation parameter assignment
  // -------------------------------------------------------------------------------------
  parameter TP                               = `TP
  )
  (
  // -------------------------------------------------------------------------------------
  // Clocks and resets
  // -------------------------------------------------------------------------------------
  input                                              slv_aclk,
  input                                              slv_aresetn,
  // -------------------------------------------------------------------------------------
  // Tag request interface
  // -------------------------------------------------------------------------------------
  input                                              srrq_np_tag_consumed,
  input       [SLV_BUS_ID_WIDTH-1:0]                 sif_np_id,
  input       [SLV_BUS_STRB_PW-1:0]                  srrq_np_addr_low,
  input       [SLV_BURST_LEN_PW-1:0]                 sif_np_len,
  input       [2:0]                                  sif_np_size,
  input                                              srrq_np_wr,
  input                                              srrq_np_atomic,
  input      [4:0]                                   srrq_np_type,
  input      [3:0]                                   srrq_np_wrap_beat_offset,
  input                                              srrq_np_ven_id_rd,
  input                                              sif_np_dbi,
  output wire [MAX_SLV_TAG_PW-1:0]                   atm_np_tag,
  output wire                                        atm_np_tag_fifo_full,
  // -------------------------------------------------------------------------------------
  // Tag response interface
  // -------------------------------------------------------------------------------------
  input                                              srsp_np_tag_recycled,
  input       [MAX_SLV_TAG_PW-1:0]                   srsp_np_tag,
  output wire [SLV_BUS_ID_WIDTH-1:0]                 atm_np_id,
  output wire [SLV_BUS_STRB_PW-1:0]                  atm_np_addr_low,
  output wire [SLV_BURST_LEN_PW-1:0]                 atm_np_len,
  output wire [2:0]                                  atm_np_size,
  output wire                                        atm_np_wr,
  output wire                                        atm_np_atomic,
  output wire [3:0]                                  atm_np_wrap_beat_offset,
  output wire                                        atm_np_ven_id_rd,
  // -------------------------------------------------------------------------------------
  // Completion order information interface
  // -------------------------------------------------------------------------------------
  output wire                                        atm_dbi_req_halt,
  output wire [MAX_SLV_TAG-1:0]                      atm_cpl_seg_halt
  );
  // -------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------
  // {np_wr, id}
  localparam NP_ID_INFO_WD = 1 + SLV_BUS_ID_WIDTH;

  // {addr_low, len, size, np_wr, wrap_bndry, wrap_beat_offset, ven_id}
  localparam REQ_INFO_WD = { SLV_BUS_STRB_PW
                           + SLV_BURST_LEN_PW
                           + 4
                           + 1
                           + 4

                           + 1
                           };

  localparam MAX_SLV_CNT_PW = $clog2(MAX_SLV_TAG+1); // 0, ..., MAX_SLV_TAG

  // -------------------------------------------------------------------------------------
  // Wire/Reg
  // -------------------------------------------------------------------------------------
  reg  [MAX_SLV_TAG -1:0]                  s_tag_valid_vec, r_tag_valid_vec;
  reg  [MAX_SLV_TAG -1:0]                  s_tag_valid_vec_int, r_tag_valid_vec_int;
  wire                                     dummy_found_int;
  logic [MAX_SLV_CNT_PW -1:0]              s_tag_valid_cnt_int, r_tag_valid_cnt_int;
  wire                                     dummy_found;
  wire [MAX_SLV_TAG_PW -1:0]               atm_np_tag_int;

  wire [NP_ID_INFO_WD-1:0]                 s_np_req_id;                         // Internal AXI ID for a new request, also indicating if is a read or write request
  reg  [NP_ID_INFO_WD-1:0]                 s_np_rsp_id;                         // Internal AXI ID for a response to an outstanding request

  reg  [MAX_SLV_TAG-1:0]                   r_tag_fifo_valid;                    // Array indicating if an entry is valid or not (registered)
  reg  [MAX_SLV_TAG-1:0]                   s_tag_fifo_valid;                    // Array indicating if an entry is valid or not (combinational)
  reg  [MAX_SLV_TAG_PW-1:0]                r_fifo_push_ptr;                     // Pointer to the position where the next entry will be stored (registered)
  reg  [MAX_SLV_TAG_PW-1:0]                s_fifo_push_ptr;                     // Pointer to the position where the next entry will be stored (combinational)
  reg  [MAX_SLV_TAG_PW-1:0]                r_fifo_clear_ptr;                    // Pointer to the position to clear when a tag is recycled (registered)
  reg  [MAX_SLV_TAG_PW-1:0]                s_fifo_clear_ptr;                    // Pointer to the position to clear when a tag is recycled (combinational)
  reg  [MAX_SLV_TAG_PW-1:0]                s_fifo_tmp_push_ptr;                 // Actual pointer used when a new tag is consumed, this varies according to whether or not a tag is recycled at the same time

  reg  [NP_ID_INFO_WD-1:0]                 r_id_vec [MAX_SLV_TAG-1:0];          // Array storing the AXI ID for every outstanding request (registered)
  reg  [NP_ID_INFO_WD-1:0]                 s_id_vec [MAX_SLV_TAG-1:0];          // Array storing the AXI ID for every outstanding request (combinational)
  reg  [MAX_SLV_TAG_PW-1:0]                r_tag_vec[MAX_SLV_TAG-1:0];          // Array storing the tag for every outstanding request (registered)
  reg  [MAX_SLV_TAG_PW-1:0]                s_tag_vec[MAX_SLV_TAG-1:0];          // Array storing the tag for every outstanding request (combinational)
  reg  [MAX_SLV_TAG-1:0]                   r_dbi_vec;                           // Array indicating if the request stored in each entry is a DBI request or not (registered)
  reg  [MAX_SLV_TAG-1:0]                   s_dbi_vec;                           // Array indicating if the request stored in each entry is a DBI request or not (combinational)
  reg  [MAX_SLV_TAG-1:0]                   r_halts_dbi_vec;                     // Array indicating which entries are halting the DBI entry because they preceed it and have the same AXI ID (registered)
  reg  [MAX_SLV_TAG-1:0]                   s_halts_dbi_vec;                     // Array indicating which entries are halting the DBI entry because they preceed it and have the same AXI ID (combinational)
  reg  [MAX_SLV_TAG-1:0]                   s_set_halts_dbi_vec;                 // Array indicating which entries should be marked as halting the DBI entry
  reg  [MAX_SLV_TAG-1:0]                   r_halt_tag_vec;                      // Array indicating which entries are halted (registered)
  reg  [MAX_SLV_TAG-1:0]                   s_halt_tag_vec;                      // Array indicating which entries are halted (combinational)
  reg  [MAX_SLV_TAG-1:0]                   s_clear_halt_tag_vec;                // Array indicating which entries should be unhalted when the entry for a DBI request is recycled
  reg                                      s_dbi_rq_id_eq_fifo_slv_id;          // Indicates the AXI ID for a new DBI request matches the AXI ID for an outstanding non-DBI request
  reg                                      s_slv_rq_id_eq_fifo_dbi_id;          // Indicates the AXI ID for a new non-DBI request matches the AXI ID for an outstanding DBI request
  reg                                      r_dbi_pending;                       // Flag to indicate there is a DBI request pending (registered)
  reg                                      s_dbi_pending;                       // Flag to indicate there is a DBI request pending (combinational)
  reg  [MAX_SLV_TAG_PW-1:0]                r_dbi_tag;                           // Tag for pending DBI request (registered)
  reg  [MAX_SLV_TAG_PW-1:0]                s_dbi_tag;                           // Tag for pending DBI request (combinational)
  reg  [NP_ID_INFO_WD-1:0]                 r_dbi_id;                            // AXI ID for the pending DBI request (registered)
  reg  [NP_ID_INFO_WD-1:0]                 s_dbi_id;                            // AXI ID for the pending DBI request (combinational)
  wire                                     s_recycled_tag_is_dbi;               // Indicates the recycled tag is for a DBI request

  // Pointer to tag being recycled in the FIFO
  reg  [MAX_SLV_TAG_PW-1:0]                s_tag_recycled_ptr;

  reg  [MAX_SLV_TAG-1:0]                   s_atm_cpl_seg_halt;

  // Request info LUT
  wire [REQ_INFO_WD-1:0]                   s_req_info;
  reg  [REQ_INFO_WD-1:0]                   r_req_info_ary[MAX_SLV_TAG-1:0];
  wire [REQ_INFO_WD-1:0]                   s_req_info_lut;

  wire [SLV_BURST_LEN_PW-1:0]              s_sif_np_len;
  wire [2:0]                               s_sif_np_size;

  // -------------------------------------------------------------------------------------
  // Design
  // -------------------------------------------------------------------------------------
  // Order same ID non-posted write and same ID non-posted read requests
  // The non-posted ID is comprised of the read/write flag and the AXI ID.
  assign s_np_req_id = {srrq_np_wr, sif_np_id};

  // Find the next available tag
  assign {dummy_found, atm_np_tag} = fn_findrightmost(r_tag_valid_vec);

  assign {dummy_found_int, atm_np_tag_int} = fn_findrightmost(r_tag_valid_vec_int);

  always_comb foreach(s_tag_valid_vec[i]) begin
    if(srrq_np_tag_consumed && (i==atm_np_tag_int))
      s_tag_valid_vec[i] = 1'b0;
    else if(srsp_np_tag_recycled && (i == srsp_np_tag))
      s_tag_valid_vec[i] = 1'b1;
    else
      s_tag_valid_vec[i] = r_tag_valid_vec[i];
  end

  always_comb foreach(s_tag_valid_vec_int[i]) begin
    if(srrq_np_tag_consumed && (i==atm_np_tag_int))
      s_tag_valid_vec_int[i] = 1'b0;
    else if(srsp_np_tag_recycled && (i == srsp_np_tag))
      s_tag_valid_vec_int[i] = 1'b1;
    else
      s_tag_valid_vec_int[i] = r_tag_valid_vec_int[i];
  end

  // Track consumptions and restore of AXI tags
  always @(posedge slv_aclk or negedge slv_aresetn) begin : proc_seq_tag_valid_vec
    integer j;
    if (!slv_aresetn) begin
      r_tag_valid_vec     <= # TP '1;
      r_tag_valid_vec_int <= # TP '1;
    end else begin
      r_tag_valid_vec     <= # TP s_tag_valid_vec;
      r_tag_valid_vec_int <= # TP s_tag_valid_vec_int;
    end
  end

  assign s_tag_valid_cnt_int = ( srrq_np_tag_consumed & ~srsp_np_tag_recycled) ? (MAX_SLV_CNT_PW)'(r_tag_valid_cnt_int + 1'b1) :
                               (~srrq_np_tag_consumed &  srsp_np_tag_recycled) ? (MAX_SLV_CNT_PW)'(r_tag_valid_cnt_int - 1'b1) :
                                                                                                   r_tag_valid_cnt_int         ;

  always_ff @(posedge slv_aclk, negedge slv_aresetn)
    if(!slv_aresetn) r_tag_valid_cnt_int <= # TP '0;
    else             r_tag_valid_cnt_int <= # TP s_tag_valid_cnt_int;

`ifndef SYNTHESIS
`endif // SYNTHESIS

  // Check if all tags are consumed, back pressure non-posted requests
  // MAX_SLV_TAG is actually the max slave tag +1 :^)
  assign atm_np_tag_fifo_full = (r_tag_valid_cnt_int == MAX_SLV_TAG);

  always @(posedge slv_aclk or negedge slv_aresetn) begin : proc_seq_tag_id_vec

    integer j,k;

    if (!slv_aresetn) begin
      r_fifo_push_ptr  <= #TP 0;
      r_fifo_clear_ptr <= #TP 0;
      r_tag_fifo_valid <= #TP 0;
      for (j=0; j < MAX_SLV_TAG; j=j+1) begin
        r_id_vec [j]     <= #TP {(NP_ID_INFO_WD){1'b0}};
        r_tag_vec[j]     <= #TP {(MAX_SLV_TAG_PW){1'b0}};
      end
    end else begin
      r_fifo_push_ptr  <= #TP s_fifo_push_ptr;
      r_fifo_clear_ptr <= #TP s_fifo_clear_ptr;
      r_tag_fifo_valid <= #TP s_tag_fifo_valid;
      for (k=0; k < MAX_SLV_TAG; k=k+1) begin
        r_id_vec [k]     <= #TP s_id_vec [k];
        r_tag_vec[k]     <= #TP s_tag_vec[k];
      end
    end

  end


  always @(posedge slv_aclk or negedge slv_aresetn) begin : proc_seq_tag_id_vec_shared_dbi

    integer j,k;

    if (!slv_aresetn) begin
      r_halt_tag_vec   <= #TP {(MAX_SLV_TAG){1'b0}};
      r_dbi_vec        <= #TP {(MAX_SLV_TAG){1'b0}};
      r_halts_dbi_vec  <= #TP {(MAX_SLV_TAG){1'b0}};
      r_dbi_tag        <= #TP {(MAX_SLV_TAG_PW){1'b0}};
      r_dbi_id         <= #TP {(NP_ID_INFO_WD){1'b0}};
      r_dbi_pending    <= #TP 1'b0;
    end else begin
      r_halt_tag_vec   <= #TP s_halt_tag_vec;
      r_dbi_vec        <= #TP s_dbi_vec;
      r_halts_dbi_vec  <= #TP s_halts_dbi_vec;
      r_dbi_tag        <= #TP s_dbi_tag;
      r_dbi_id         <= #TP s_dbi_id;
      r_dbi_pending    <= #TP s_dbi_pending;
    end
  end

  assign s_recycled_tag_is_dbi = r_dbi_pending && (r_dbi_tag == srsp_np_tag);


  // FIFO based on r_id_vec and r_tag_vec
  always @(*) begin : proc_comb_tag_id_vec

    integer i,j,k,l,m,n,p;

    s_fifo_push_ptr      = r_fifo_push_ptr;
    s_fifo_clear_ptr     = r_fifo_clear_ptr;
    s_fifo_tmp_push_ptr  = r_fifo_push_ptr;
    s_tag_fifo_valid     = r_tag_fifo_valid;
    for (i=0; i < MAX_SLV_TAG; i=i+1) begin
      s_id_vec [i]         = r_id_vec[i];
      s_tag_vec[i]         = r_tag_vec[i];
    end
    s_halt_tag_vec       = r_halt_tag_vec;
    s_dbi_vec            = r_dbi_vec;
    s_halts_dbi_vec      = r_halts_dbi_vec;
    s_dbi_tag            = r_dbi_tag;
    s_dbi_id             = r_dbi_id;
    s_dbi_pending        = r_dbi_pending;
    s_clear_halt_tag_vec = {MAX_SLV_TAG{1'b0}};
    s_set_halts_dbi_vec  = {MAX_SLV_TAG{1'b0}};

    // FIFO push pointer management
    if(srrq_np_tag_consumed) begin                                              // if there is a new entry (tag consumed)
      if(!srsp_np_tag_recycled)begin                                            //   and nothing is removed from the FIFO (no tag recycled)
        if(r_fifo_push_ptr < (MAX_SLV_TAG-1))begin                              //     if FIFO is not full (push pointer not at its last position)
          s_fifo_push_ptr  = r_fifo_push_ptr + 1;                               //       increase push pointer, otherwise (FIFO is full) push pointer stays at last position
        end
        if(r_tag_fifo_valid[0])begin                                            //     if FIFO is not empty (valid for position 0 is set)
          s_fifo_clear_ptr = r_fifo_clear_ptr + 1;                              //       increase clear pointer, otherwise (FIFO is empty) clear pointer stays at 0
        end
      end                                                                       //   (if a entry is removed at the same time a new one is received then push and clear pointers stay at the same position)
    end else begin                                                              // else (no new entry)
      if(srsp_np_tag_recycled)begin                                             //   if an entry is removed from the FIFO (tag recycled)
        if((r_fifo_push_ptr != 0) && (!r_tag_fifo_valid[(MAX_SLV_TAG-1)]))begin //     if the push pointer is greater than 0 (not at first position) and there is no valid entry at the last position
          s_fifo_push_ptr  = r_fifo_push_ptr - 1;                               //       decrement the push pointer, otherwise (push pointer already at first position) push pointer stays at 0
        end
        if(r_fifo_clear_ptr != 0) begin                                         //     if the clear pointer is greater than 0 (not at first position)
          s_fifo_clear_ptr = r_fifo_clear_ptr - 1;                              //       decrement the clear pointer, otherwise (clear pointer already at first position) clear pointer stays at 0
        end
      end
    end

    for(l=0; l<MAX_SLV_TAG; l=l+1)begin                                         // search the existing entries
      if(   srrq_np_tag_consumed && sif_np_dbi                                  //   if there is a new entry (tag consumed) and it is a DBI request (sif_np_dbi)
         && r_tag_fifo_valid[l]                                                 //   and the current position has a valid entry
         && (r_id_vec[l]==s_np_req_id)                                          //   and the id for the current position matches the id for the new DBI request
         && !(srsp_np_tag_recycled && (r_tag_vec[l]==srsp_np_tag))) begin       //   and the tag for the current position is not being recycled
        s_set_halts_dbi_vec[l] = 1'b1;                                          //     mark the entry as halting the new DBI request
      end
    end

    if (srsp_np_tag_recycled && s_recycled_tag_is_dbi) begin                    // if an entry is removed from the FIFO (tag recycled) and the recycled tag is for a DBI request
      s_dbi_pending = 0;                                                        //   clear the DBI pending flag
      for (k=0; k<MAX_SLV_TAG; k=k+1) begin
        if(r_id_vec[k] == r_dbi_id) begin                                       //     for all the entries where the AXI matches the one in the removed entry
          s_clear_halt_tag_vec[k] = 1;                                          //       clear the halt bit
        end
      end
    end

    for (m=0; m<MAX_SLV_TAG; m=m+1) begin
      if(r_dbi_vec[m] && !(|r_halts_dbi_vec)) begin                             //         if there is a DBI entry and no other entries are halting it
        s_clear_halt_tag_vec[m] = 1;                                            //           clear the halt from the DBI entry
      end
    end


    if (srsp_np_tag_recycled) begin
      for (j=0; j < (MAX_SLV_TAG-1); j=j+1) begin                                   //   search the existing entries
        if ((j >= s_tag_recycled_ptr) && (j < r_fifo_clear_ptr)) begin          //     move all positions up by 1 from the position if the recycled tag entry to the last entry in the FIFO
        s_tag_fifo_valid[j] = r_tag_fifo_valid[j+1];
        s_id_vec        [j] = r_id_vec        [j+1];
        s_tag_vec       [j] = r_tag_vec       [j+1];
        s_halt_tag_vec  [j] = r_halt_tag_vec  [j+1] && !s_clear_halt_tag_vec[j+1];
        s_dbi_vec       [j] = r_dbi_vec       [j+1];
        s_halts_dbi_vec [j] = r_halts_dbi_vec [j+1] || s_set_halts_dbi_vec[j+1];
        end
      end
      s_tag_fifo_valid[r_fifo_clear_ptr] = 1'b0;
      s_id_vec        [r_fifo_clear_ptr] = {(NP_ID_INFO_WD){1'b0}};
      s_tag_vec       [r_fifo_clear_ptr] = {(MAX_SLV_TAG_PW){1'b0}};
      s_halt_tag_vec  [r_fifo_clear_ptr] = 1'b0;
      s_dbi_vec       [r_fifo_clear_ptr] = 1'b0;
      s_halts_dbi_vec [r_fifo_clear_ptr] = 1'b0;
      for (n=0; n < MAX_SLV_TAG; n=n+1) begin                                   //   search the existing entries
        if(n < s_tag_recycled_ptr) begin
          s_tag_fifo_valid[n] = r_tag_fifo_valid[n];
          s_id_vec        [n] = r_id_vec        [n];
          s_tag_vec       [n] = r_tag_vec       [n];
          s_halt_tag_vec  [n] = r_halt_tag_vec  [n] && !s_clear_halt_tag_vec[n];
          s_dbi_vec       [n] = r_dbi_vec       [n];
          s_halts_dbi_vec [n] = r_halts_dbi_vec [n] || s_set_halts_dbi_vec[n];
        end
      end
      end else begin
      for (p=0; p < MAX_SLV_TAG; p=p+1) begin                                   //   search the existing entries
        s_tag_fifo_valid[p] = r_tag_fifo_valid[p];
        s_id_vec        [p] = r_id_vec        [p];
        s_tag_vec       [p] = r_tag_vec       [p];
        s_halt_tag_vec  [p] = r_halt_tag_vec  [p] && !s_clear_halt_tag_vec[p];
        s_dbi_vec       [p] = r_dbi_vec       [p];
        s_halts_dbi_vec [p] = r_halts_dbi_vec [p] || s_set_halts_dbi_vec[p];
      end
    end

    if (srrq_np_tag_consumed) begin                                             // if there is a new entry (tag consumed)
      if (srsp_np_tag_recycled) begin                                           //   if an entry is removed from the FIFO (tag recycled) at the same time
        s_fifo_tmp_push_ptr  = r_fifo_clear_ptr;                                //     the actual push pointer is going to be equal to the stored clear pointer
      end else begin                                                            //   else (no entry removed from the FIFO)
        s_fifo_tmp_push_ptr  = r_fifo_push_ptr;                                 //     the actual push pointer is going to be equal to the stored push pointer
      end                                                                       //
      s_tag_fifo_valid[s_fifo_tmp_push_ptr] = 1'b1;                             //   mark the FIFO entry as valid
      s_id_vec        [s_fifo_tmp_push_ptr] = s_np_req_id;                      //   store the AXI ID
      s_tag_vec       [s_fifo_tmp_push_ptr] = atm_np_tag_int;                   //   store the consumed tag
      s_halt_tag_vec  [s_fifo_tmp_push_ptr] =    s_dbi_rq_id_eq_fifo_slv_id     //   set the halt flag if it's a DBI request with the same AXI ID as an existing wire request
                                              || s_slv_rq_id_eq_fifo_dbi_id;    //                  or if it's a wire request with the same AXI ID as an existing DBI request
      s_dbi_vec       [s_fifo_tmp_push_ptr] = sif_np_dbi;                       //   set the DBI flag if it's a DBI request
      if(sif_np_dbi) begin                                                      //   if it's a DBI request
        s_dbi_pending    = 1'b1;                                                //     set the DBI request pending flag
        s_dbi_tag        = atm_np_tag_int;                                      //     store the tag as the current DBI tag
        s_dbi_id         = s_np_req_id;                                         //     store the AXI ID as the current DBI AXI ID
      end
    end /* if (srrq_np_tag_consumed) begin */

  end

  assign atm_dbi_req_halt = |r_dbi_vec;                                         // allow only one outstanding DBI request

  always @(*) begin : proc_comb_fifo_id_tag
    integer j,h,k;

    reg [MAX_SLV_TAG-1:0]    halted_tag_dec;

    s_atm_cpl_seg_halt          = 0;
    s_dbi_rq_id_eq_fifo_slv_id  = 0;
    s_slv_rq_id_eq_fifo_dbi_id  = 0;

    for (j=0; j<MAX_SLV_TAG; j=j+1) begin

      // Check if the DBI request ID is already present in FIFO from a previous slave request
      if (r_tag_fifo_valid[j]==1'b1 && r_id_vec[j]==s_np_req_id && sif_np_dbi && !r_dbi_vec[j] && (!srsp_np_tag_recycled || (j!=s_tag_recycled_ptr)))
        s_dbi_rq_id_eq_fifo_slv_id = 1'b1;

      // Check if the slave request ID is already present in FIFO from a previous DBI request
      if (r_tag_fifo_valid[j]==1'b1 && r_id_vec[j]==s_np_req_id && !sif_np_dbi && r_dbi_vec[j] && (!srsp_np_tag_recycled || (j!=s_tag_recycled_ptr)))
        s_slv_rq_id_eq_fifo_dbi_id = 1'b1;

      // Generate the segment halt vector
      halted_tag_dec = (1'b1 << r_tag_vec[j]) &
                       {MAX_SLV_TAG{(r_tag_fifo_valid[j] &
                       r_halt_tag_vec[j])}};

      s_atm_cpl_seg_halt = s_atm_cpl_seg_halt | halted_tag_dec;
    end
  end

  assign atm_cpl_seg_halt = s_atm_cpl_seg_halt;

  // Pointer to the recycled response tag
  always @(*) begin : proc_comb_tag_rcyc_ptr

    integer j;

    s_tag_recycled_ptr = 0;

    for (j=0; j<MAX_SLV_TAG; j=j+1) begin

      // Pointer to response tag location
      if (r_tag_fifo_valid[j]==1'b1 && r_tag_vec[j]==srsp_np_tag)
        s_tag_recycled_ptr = j;
    end
  end

  // Find the AXI ID corresponding to the response tag
  always @(*) begin : proc_comb_rsp_id
    integer j,k;

    s_np_rsp_id = 0;

    for (j=0; j<MAX_SLV_TAG; j=j+1)
      if (j==s_tag_recycled_ptr)
        // Extract the ID corresponding to the response tag
        s_np_rsp_id=r_id_vec[j];

  end


  assign atm_np_id = s_np_rsp_id[NP_ID_INFO_WD-2:0];


  // -------------------------------------------------------------------------------------
  // For Atomic Compare and Swap
  // -------------------------------------------------------------------------------------
   assign s_sif_np_len = (&srrq_np_type[3:1] & ~srrq_np_type[4]) ? (sif_np_len >> 1) : sif_np_len;
   assign s_sif_np_size = (&srrq_np_type[3:1] & ~srrq_np_type[4]) ? ((sif_np_len=='d0) ? sif_np_size - 1 : sif_np_size) : sif_np_size;

  // -------------------------------------------------------------------------------------
  // Request info LUT
  // -------------------------------------------------------------------------------------
   assign s_req_info = { srrq_np_addr_low
                       , s_sif_np_len
                       , s_sif_np_size
                       , srrq_np_wr
                       , srrq_np_atomic
                       , srrq_np_wrap_beat_offset
                       , srrq_np_ven_id_rd
                       };

   always @(posedge slv_aclk or negedge slv_aresetn) begin : proc_seq_req_info_lut
     integer i,j;

     if (!slv_aresetn) begin
       for (i=0; i< MAX_SLV_TAG; i=i+1) begin
          r_req_info_ary[i] <= # TP {REQ_INFO_WD{1'b0}};
       end
     end else begin
       if (srrq_np_tag_consumed) begin
         for (i=0; i< MAX_SLV_TAG; i=i+1) begin
            if (i == atm_np_tag_int) begin
               r_req_info_ary[i] <= # TP s_req_info;
            end
         end
       end
     end
   end

   assign s_req_info_lut = r_req_info_ary[srsp_np_tag];

   assign { atm_np_addr_low
          , atm_np_len
          , atm_np_size
          , atm_np_wr
          , atm_np_atomic
          , atm_np_wrap_beat_offset
          , atm_np_ven_id_rd
          } = s_req_info_lut;

  // -------------------------------------------------------------------------------------
  // Functions
  // -------------------------------------------------------------------------------------
  // Returning rightmost bit asserted in a vector
  function automatic [MAX_SLV_TAG_PW:0] fn_findrightmost;

  input [MAX_SLV_TAG-1:0] ary;

  reg found;
  reg [MAX_SLV_TAG_PW-1:0] rightmostbit;

  integer j;

  begin

    //initialization
    found = 0;
    rightmostbit = 0;

    // loop on all AXI tag
    for (j=0; j<MAX_SLV_TAG; j=j+1)
      begin
   if (ary[j]==1'b1 & found==1'b0)
          begin
       found=1'b1;
       rightmostbit=j;
     end
      end

     // function value assignment
     fn_findrightmost = {found, rightmostbit};

  end
endfunction

endmodule
