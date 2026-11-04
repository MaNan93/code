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
// ---    $Revision: #5 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/common/DWC_pcie_bridge_llfifo_simple.sv#5 $ 
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

// Optimized version of DWC_pcie_bridge_llfifo
// 1. Removed capability for simultaneous allocation and release on the same clock cycle
// 2. Removed capability for interleaved allocation
// 2. Minimized the replication of MUXes

module DWC_pcie_bridge_llfifo_simple
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter P_NRESOURCES      = 4
  ,parameter P_NALLOCATORS     = 4
  ,parameter P_RSRC_ID_WD      = $clog2(P_NRESOURCES)
  ,parameter P_ALCT_ID_WD      = $clog2(P_NALLOCATORS)
  ,parameter P_BURST_ALCT      = 1
  ,parameter P_N_ALCT_CHAN     = 1 // Number of allocation control channels
  ,parameter P_FANOUT          = 1
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   input  logic                                          clk
  ,input  logic                                          rst_n

  ,input  logic [P_N_ALCT_CHAN -1:0] [P_FANOUT -1:0]     alct_req       // Resource allocation request
  ,input  logic [P_N_ALCT_CHAN -1:0] [P_ALCT_ID_WD -1:0] alct_alctr_id  // Allocator id
  ,input  logic [P_N_ALCT_CHAN -1:0] [P_RSRC_ID_WD -1:0] alct_rsrc_id   // Allocation resource id

  ,input  logic                                          rls_req        // Resource release request
  ,input  logic                      [P_ALCT_ID_WD -1:0] rls_alctr_id   // Allocator id
  ,input  logic                                          rls_all        // Release all resources allocated by the allocator
  ,output logic                                          rls_valid      // Resource release valid
  ,output logic                      [P_RSRC_ID_WD -1:0] rls_rsrc_id    // id of released resource
  ,output logic                                          rls_last       // Resource is last
  );

  localparam TP = `TP;

  // [Spyglass ImproperRangeIndex] Cover cases where 2**P_RSRC_ID_WD > P_NRESOURCES
  localparam L_RSRC_ID_WD_LIMITED = (P_NRESOURCES > 1) ? $clog2(P_NRESOURCES) : 1;

  localparam L_FANOUT_ALCT = 0;
  localparam L_FANOUT_RSRC = 1;

  typedef struct packed {
    logic                     valid;
    logic [P_RSRC_ID_WD -1:0] head;
    logic [P_RSRC_ID_WD -1:0] tail;
  } alctLUT_s;

  typedef struct packed {
    logic [P_RSRC_ID_WD -1:0] next_r;
  } rsrcLUT_s;

  logic [P_N_ALCT_CHAN -1:0] [1:0] s_alct_req;

  alctLUT_s [P_NALLOCATORS -1:0] r_alct, s_alct;
  rsrcLUT_s  [P_NRESOURCES -1:0] r_rsrc, s_rsrc;
  logic      [P_NRESOURCES -1:0] s_rsrc_is_new_tail;

  alctLUT_s                      s_alctr_of_rls;
  alctLUT_s [P_N_ALCT_CHAN -1:0] s_alctr_of_alct;

  logic [P_N_ALCT_CHAN -1:0]                     r_last_vld  , s_last_vld;
  logic [P_N_ALCT_CHAN -1:0] [P_RSRC_ID_WD -1:0] r_last_rsrc , s_last_rsrc;
  logic [P_N_ALCT_CHAN -1:0] [P_ALCT_ID_WD -1:0] r_last_alctr, s_last_alctr;

  logic [P_RSRC_ID_WD -1:0] s_next_rsrc_of_rls;
  logic                     s_last_of_rls;

  // [Spyglass ImproperRangeIndex] Cover cases where 2**P_RSRC_ID_WD > P_NRESOURCES
  logic [L_RSRC_ID_WD_LIMITED-1:0] w_alctr_of_rls_head;

  // Get the allocator LUT of the release channel
  assign    s_alctr_of_rls  = r_alct[rls_alctr_id];

  // Get the allocator LUT of the allocation channel
  always_comb foreach(s_alctr_of_alct[j]) s_alctr_of_alct[j] = r_alct[alct_alctr_id[j]];

  // [Spyglass ImproperRangeIndex] Cover cases where 2**P_RSRC_ID_WD > P_NRESOURCES
  assign    w_alctr_of_rls_head = s_alctr_of_rls.head[L_RSRC_ID_WD_LIMITED-1:0];

  // Get the next resource on the release channel
  assign    s_next_rsrc_of_rls = r_rsrc[w_alctr_of_rls_head].next_r;

  // Detect eot of release channel
  assign    s_last_of_rls      = s_next_rsrc_of_rls == s_alctr_of_rls.head;

  generate
    if(P_FANOUT == 2) begin : gen_fanout_2
      assign s_alct_req = alct_req;
    end else begin : gen_fanout_1
      always_comb foreach(s_alct_req[i]) s_alct_req[i] = {2{alct_req[i]}};
    end
  endgenerate

  always_ff @(posedge clk, negedge rst_n) begin : R_ALCT_PROC
    if(!rst_n) begin
      r_alct <= #TP '0;
    end else begin
      r_alct <= #TP s_alct;
    end
  end : R_ALCT_PROC

  always_ff @(posedge clk, negedge rst_n) begin : R_RSRC_PROC
    if(!rst_n) begin
      foreach(r_rsrc[i]) begin
        r_rsrc <= #TP i;
      end
    end else begin
      r_rsrc <= #TP s_rsrc;
    end
  end : R_RSRC_PROC

  // Store the last allocated (alctr, rsrc) pair per channel
  always_ff @(posedge clk, negedge rst_n) begin : R_LAST_RSRC_PROC
    if(!rst_n) begin
      foreach(r_last_vld[j]) begin
        r_last_vld  [j] <= #TP 1'b0;
        r_last_rsrc [j] <= #TP   '0;
        r_last_alctr[j] <= #TP   '0;
      end
    end else begin
      foreach(r_last_vld[j]) begin
        r_last_vld  [j] <= #TP s_last_vld  [j];
        r_last_rsrc [j] <= #TP s_last_rsrc [j];
        r_last_alctr[j] <= #TP s_last_alctr[j];
      end
    end
  end : R_LAST_RSRC_PROC

  always_comb begin : S_LAST_RSRC_PROC
    s_last_vld   = r_last_vld  ;
    s_last_rsrc  = r_last_rsrc ;
    s_last_alctr = r_last_alctr;

    // 1. Allocator channel switch:
    //    If an allocator X requests to a new channel 'k', clear any 'last' info
    //    for allocator X in any other channels
    foreach(s_alct_req[k]) begin
      foreach(s_alct_req[l]) begin
        if((k != l) && s_alct_req[k][L_FANOUT_RSRC] && (alct_alctr_id[k] == s_last_alctr[l])) begin
          s_last_vld  [l] = 1'b0;
          s_last_rsrc [l] = '0;
          s_last_alctr[l] = '0;
        end
      end
    end

    // 2. Resource channel switch:
    //    If an allocator requests a new resource X in channel 'm', clear any 'last' info
    //    with resource X in any other channels
    foreach(s_alct_req[m]) begin
      foreach(s_alct_req[n]) begin
        if((m != n) && s_alct_req[m][L_FANOUT_RSRC] && (alct_rsrc_id[m] == s_last_rsrc[n])) begin
          s_last_vld  [n] = 1'b0;
          s_last_rsrc [n] = '0;
          s_last_alctr[n] = '0;
        end
      end
    end

    // 3. If a new allocation request is made, populate the 'last' info for the channel
    foreach(s_alct_req[j]) begin
      if(s_alct_req[j][L_FANOUT_RSRC]) begin
        s_last_vld  [j] = 1'b1;
        s_last_rsrc [j] = alct_rsrc_id [j];
        s_last_alctr[j] = alct_alctr_id[j];
      end
    end
  end : S_LAST_RSRC_PROC


  generate
  if(P_BURST_ALCT) begin : gen_burstAlct_comb_procs
    // Calculate per-allocator valid and LL head
    always_comb begin : S_ALCT_PROC
      s_alct = r_alct;

      if(rls_req) begin
        s_alct[rls_alctr_id] = alctLUT_s'{
          default : '0
         ,valid   : !(s_last_of_rls && s_alctr_of_rls.valid) && (!rls_all)
         ,head    : s_next_rsrc_of_rls
        };
      end

      foreach(s_alct_req[j]) begin
        if(s_alct_req[j][L_FANOUT_ALCT]) begin
          s_alct[alct_alctr_id[j]] = alctLUT_s'{
            default : '0
           ,valid   : 1'b1
           ,head    : s_alctr_of_alct[j].valid ? s_alctr_of_alct[j].head : alct_rsrc_id[j]
          };
        end
      end
    end : S_ALCT_PROC

    // Calculate resource linked-list
    always_comb begin : S_RSRC_PROC
      s_rsrc = r_rsrc;
      s_rsrc_is_new_tail = '0;

      foreach(s_rsrc[i]) begin
        foreach(s_alct_req[j]) begin
          if(s_alct_req[j][L_FANOUT_RSRC] && i == alct_rsrc_id[j]) begin
            // next of new tail = new_tail (truncate ll)
            s_rsrc[i].next_r = i;
            s_rsrc_is_new_tail[i] = 1'b1;
          end else if(s_alct_req[j][L_FANOUT_RSRC] && r_last_vld[j] && i == r_last_rsrc[j] && (alct_alctr_id[j] == r_last_alctr[j]) && !s_rsrc_is_new_tail[i]) begin
            // next of previous tail = new_tail
            s_rsrc[i].next_r = alct_rsrc_id[j];
          end
        end
      end
    end : S_RSRC_PROC
  end else begin : gen_noBurstAlct_comb_procs
    // Calculate per-allocator valid and LL head
    always_comb begin : S_ALCT_PROC
      s_alct = r_alct;

      if(rls_req) begin
        s_alct[rls_alctr_id] = alctLUT_s'{
          valid   : !(s_last_of_rls && s_alctr_of_rls.valid) && (!rls_all)
         ,head    : s_next_rsrc_of_rls
         ,tail    : s_alctr_of_rls.tail
        };
      end

      foreach(s_alct_req[j]) begin
        if(s_alct_req[j][L_FANOUT_RSRC]) begin
          s_alct[alct_alctr_id[j]] = alctLUT_s'{
            valid   : 1'b1
           ,head    : s_alctr_of_alct[j].valid ? s_alctr_of_alct[j].head : alct_rsrc_id[j]
           ,tail    : alct_rsrc_id[j]
          };
        end
      end
    end : S_ALCT_PROC

    // Calculate resource linked-list
    always_comb begin : S_RSRC_PROC
      s_rsrc = r_rsrc;

      foreach(s_rsrc[i]) begin
        foreach(s_alct_req[j]) begin
          // next of previous tail = new_tail
          if(s_alct_req[j][L_FANOUT_RSRC] && i == s_alctr_of_alct[j].tail && s_alctr_of_alct[j].valid)
            s_rsrc[i].next_r = alct_rsrc_id[j];

          // next of new tail = new_tail (truncate ll)
          if(s_alct_req[j][L_FANOUT_RSRC] && i == alct_rsrc_id[j])
            s_rsrc[i].next_r = i;
        end
      end
    end : S_RSRC_PROC
  end
  endgenerate

  assign rls_valid   = s_alctr_of_rls.valid;
  assign rls_rsrc_id = s_alctr_of_rls.head;
  assign rls_last    = s_last_of_rls && s_alctr_of_rls.valid;

`ifndef SYNTHESIS
`endif // SYNTHESIS

endmodule : DWC_pcie_bridge_llfifo_simple
