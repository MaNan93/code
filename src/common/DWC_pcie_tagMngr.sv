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
// ---    $DateTime: 2021/10/29 02:04:56 $ 
// ---    $Revision: #4 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DWC_pcie_tagMngr.sv#4 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

module DWC_pcie_tagMngr #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter      P_MAXTAG = 767 // Max tag in Normal mode
  ,parameter  P_MAXTAG_LOW = 255 // Max tag in Low mode
  ,parameter P_MAXTAG_VLOW = 31  // Max tag in VLow mode
  ,parameter      P_MINTAG = 0   // Min tag in Normal mode
  ,parameter  P_MINTAG_LOW = 0   // Min tag in Low mode
  ,parameter P_MINTAG_VLOW = 0   // Min tag in VLow mode
  ,parameter P_START_EMPTY = 0   // [0/1]: Start with [all/no] tags available
  ,parameter       P_TAGWD = $clog2(P_MAXTAG)
  ,parameter  P_TAGINFO_EN = 0
  ,parameter  P_TAGINFO_WD = 1
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################

   input  logic                     clk
  ,input  logic                     rst_n

  ,input  logic            [2 -1:0] mode          // Mode - 2'b00: Normal, 2'b01: Low, 2'b10: VLow
  ,input  logic                     update_p      // Mode update pulse

  ,input  logic                     pop_en        // Reserve a tag
  ,output logic      [P_TAGWD -1:0] pop_tag       // Tag to reserve
  ,output logic [P_TAGINFO_WD -1:0] pop_tag_info  // Tag information (optional)
  ,output logic                     pop_empty     // No tags available

  ,input  logic                     push_en       // Return a tag
  ,input  logic      [P_TAGWD -1:0] push_tag      // Tag to return
  ,input  logic [P_TAGINFO_WD -1:0] push_tag_info // Return tag with information (optional)
  );

  `define tmgr_max3(a,b,c) (a > b) ? (a > c ? a : c) : (b > c ? b : c)

  `define tmgr_min3(a,b,c) (a < b) ? (a < c ? a : c) : (b < c ? b : c)

  localparam L_TAGMAX  = `tmgr_max3(P_MAXTAG, P_MAXTAG_LOW, P_MAXTAG_VLOW);
  localparam L_TAGMIN  = `tmgr_min3(P_MINTAG, P_MINTAG_LOW, P_MINTAG_VLOW);
  localparam LP_N_TAGS = L_TAGMAX - L_TAGMIN + 1;

  localparam LP_N_STAGES = (LP_N_TAGS <    8) ? 2 :
                           (LP_N_TAGS < 1024) ? 3 : 4;

  // tagLUT: 1 bit per tag
  typedef logic         [L_TAGMAX : L_TAGMIN]    tagLUT_t;
  // tagPtr: width of max tag
  typedef logic        [P_TAGWD -1:        0]    tagPtr_t;
  // tagPtrLUT_t: $bits(tagPtr_t) per tag
  typedef tagPtr_t      [L_TAGMAX : L_TAGMIN] tagPtrLUT_t;
  // tagInfo_t: width of tag info
  typedef logic   [P_TAGINFO_WD -1:        0]   tagInfo_t;
  // infoLUT_t: $bits(tagInfo_t) per tag
  typedef tagInfo_t     [L_TAGMAX : L_TAGMIN]   infoLUT_t;

  typedef enum logic [1:0] {
    E_NORMAL = 2'b00,
    E_LOW    = 2'b01,
    E_VLOW   = 2'b10
  } mode_e;

  typedef struct packed {
    tagPtr_t  tag;
    tagInfo_t tagInfo;
  } tagInfo_s;

  // tagInfoLUT_t: $bits(tagInfo_s) per tag
  typedef tagInfo_s [L_TAGMAX : L_TAGMIN] tagInfoLUT_t;

  localparam LP_START_VAL = {$bits(tagLUT_t){(P_START_EMPTY == 1) ? 1'b0 : 1'b1}};

  logic s_valid;
  logic s_ready;
  logic clr_n;

  tagLUT_t s_tag_avail, r_tag_avail, s_mode_tag_avail;
  tagLUT_t s_mode_mask;
  tagLUT_t s_grant_ary;

  infoLUT_t    r_push_tag_info_ary;
  tagInfoLUT_t s_tag_ptr_lut;
  tagInfo_s    s_data;

  mode_e s_mode;

  assign s_mode = (mode == 2'b00) ? E_NORMAL :
                  (mode == 2'b10) ? E_VLOW   : E_LOW;

  // Populate a LUT with tag info for each tag
  generate
  if(P_TAGINFO_EN == 1) begin : gen_r_push_tag_info_ary_FF
    always_ff @(posedge clk, negedge rst_n) begin : r_push_tag_info_ary_PROC
      if(!rst_n) begin
        r_push_tag_info_ary <= #`TP '0;
      end else begin
        foreach(r_push_tag_info_ary[i]) begin
          if(push_en && (i == push_tag)) begin
            r_push_tag_info_ary[i] <= #`TP push_tag_info;
          end else begin
            r_push_tag_info_ary[i] <= #`TP r_push_tag_info_ary[i];
          end // if
        end // foreach
      end
    end : r_push_tag_info_ary_PROC
  end else begin : gen_no_push_tag_info_ary
    assign r_push_tag_info_ary = '0;
  end
  endgenerate

  /* Populate index to tag LUT:
   * s_tag_ptr_lut[L_TAGMAX  ] = L_TAGMAX
   * s_tag_ptr_lut[L_TAGMAX-1] = L_TAGMAX-1
   * (...)
   * And append the relevant tag info
   */
  generate
  if(P_TAGINFO_EN == 1) begin
    always_comb begin : gen_tagPtrLUT_tagInfo
      foreach(s_tag_ptr_lut[i]) begin
        s_tag_ptr_lut[i] = '{
          tag    : (P_TAGWD)'(i)
         ,tagInfo: r_push_tag_info_ary[i]
        };
      end
    end : gen_tagPtrLUT_tagInfo
  end else begin
    always_comb begin : gen_tagPtrLUT_tagNoInfo
      foreach(s_tag_ptr_lut[i]) begin
        s_tag_ptr_lut[i] = '{
          default : '0
         ,tag     : (P_TAGWD)'(i)
        };
      end
    end : gen_tagPtrLUT_tagNoInfo
  end
  endgenerate

  /* Populate tag availability LUT:
   * rst or clr    -> @P_START_EMPTY[All/no] tags return to available
   * Arbiter grant -> Tag is removed from available tags
   * Tag pushed    -> Tag is returned to available tags
   */

  // (1/2) Calculate which tags will be available next clock cycle
  always_comb begin : s_tag_avail_PROC
    // Remove granted tags from the available tag LUT
    s_tag_avail = r_tag_avail ^ s_grant_ary;

    // Add pushed tags to the available tag LUT
    foreach(s_tag_avail[i]) begin
      if (i == push_tag && push_en) begin
        s_tag_avail[i] = 1'b1;
      end
    end
  end : s_tag_avail_PROC

  // (2/2) Register the available tags
  always_ff @(posedge clk, negedge rst_n) begin : r_tag_avail_PROC
    if(!rst_n) begin
      r_tag_avail <= #`TP LP_START_VAL;
    end else begin
      r_tag_avail <= #`TP update_p ? LP_START_VAL : s_tag_avail;
    end
  end : r_tag_avail_PROC

  /* Populate a bitmask which indicates which tags are available for each mode
   * s_mode_mask[i] = 1'b1 iff i inside [MODE_LOW:MODE_HIGH]
   */
  always_comb begin : s_mode_mask_PROC
    foreach(s_mode_mask[i]) begin
      s_mode_mask[i] = (s_mode == E_NORMAL) ? i inside {[P_MINTAG      : P_MAXTAG     ]} :
                       (s_mode == E_VLOW  ) ? i inside {[P_MINTAG_VLOW : P_MAXTAG_VLOW]} :
                     /*(s_mode == E_LOW   )*/ i inside {[P_MINTAG_LOW  : P_MAXTAG_LOW ]}  ;
    end
  end : s_mode_mask_PROC

  assign s_mode_tag_avail = r_tag_avail & s_mode_mask;
  assign clr_n = !update_p;

  DWC_pcie_staged_arbiter
   #(
    .P_INPUTS   ( LP_N_TAGS   )
   ,.P_STAGES   ( LP_N_STAGES )
   ,.P_DATATYPE ( tagInfo_s   )
   ,.P_WEIGHTED ( 0           )
  ) u_arb (
    .i_clk     ( clk              )
   ,.i_rst_n   ( rst_n            )
   ,.i_clr_n   ( clr_n            )
   ,.i_en      ( 1'b1             )
   ,.i_ready   ( s_ready          )
   ,.i_request ( s_mode_tag_avail )
   ,.i_data    ( s_tag_ptr_lut    )
   ,.o_grant   ( s_grant_ary      )
   ,.o_valid   ( s_valid          )
   ,.o_data    ( s_data           )
  );

  assign s_ready   = pop_en;
  assign pop_empty = (!s_valid) || update_p;
  assign pop_tag   = (P_TAGWD)'(s_data.tag);

  generate
  if(P_TAGINFO_EN == 1) begin : gen_tagInfoOut_wInfo
    assign pop_tag_info = s_data.tagInfo;
  end else begin : gen_tagInfoOut_noInfo
    assign pop_tag_info = '0;
  end
  endgenerate

`ifndef SYNTHESIS
`endif // SYNTHESIS

endmodule : DWC_pcie_tagMngr
