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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DWC_pcie_generic_arbiter.sv#4 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

module DWC_pcie_generic_arbiter
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
    parameter P_INPUTS = 2
   ,parameter P_WEIGHTWD = $clog2(P_INPUTS)+1
   ,parameter P_TYPE = 2'b01
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
    input  logic                                i_clk
   ,input  logic                                i_rst_n
   ,input  logic                                i_clr_n
   ,input  logic                                i_en
   ,input  logic [P_INPUTS-1:0]                 i_request
   ,input  logic [P_INPUTS-1:0][P_WEIGHTWD-1:0] i_weight
   ,output logic                                o_granted
   ,output logic [P_INPUTS-1:0]                 o_grant
   ,output logic [P_WEIGHTWD-1:0]               o_weight
  );

  typedef enum logic [1:0] {
     E_ARB_STRICT     = 2'b00
    ,E_ARB_ROUNDROBIN = 2'b01
    ,E_ARB_WEIGHTED   = 2'b10
    ,E_ARB_RESERVED   = 2'b11
  } arbType_e;

  localparam L_INPUTS_WD = $clog2(P_INPUTS);
  generate
    if(P_INPUTS > 1) begin : GEN_ENABLE_ARBITER
      logic [P_INPUTS-1:0] s_shiftedReq;
      logic [P_INPUTS-1:0] s_shiftedGrant;

      always_comb begin : proc_strict_arbiter
        s_shiftedGrant = '0;
        foreach (s_shiftedReq[index]) begin
          if (s_shiftedReq[index]) begin
            s_shiftedGrant = '0;
            s_shiftedGrant[index] = 1'b1 ;
          end
        end
      end

      if (P_TYPE == E_ARB_ROUNDROBIN || P_TYPE == E_ARB_WEIGHTED) begin : GEN_NONSTRICT_ARBITER
        logic [L_INPUTS_WD-1:0] r_token;
        logic [L_INPUTS_WD-1:0] s_token;

        always_ff @(posedge i_clk, negedge i_rst_n) begin : proc_rr_token
          if(!i_rst_n) begin
            r_token    <= #`TP '0;
          end else begin
            if(!i_clr_n) begin
              r_token <= #`TP '0;
            end else if(o_granted) begin
              foreach (o_grant[index]) begin
                if (o_grant[index]) begin
                  r_token    <= #`TP index+1;
                end
              end
            end else begin
              r_token    <= #`TP r_token;
            end
          end
        end

        assign s_token = r_token + 1'b1;

        if (P_TYPE == E_ARB_WEIGHTED) begin : GEN_WEIGHTED_ARBITER
          logic [P_WEIGHTWD-1:0] r_weight;
          logic [P_INPUTS-1:0] r_weightMask;
          logic [P_INPUTS-1:0] s_requestMasked;
          logic [P_INPUTS-1:0] s_weightOverflow;

          always_ff @(posedge i_clk, negedge i_rst_n) begin : proc_weight
            if(!i_rst_n) begin
              r_weight     <= #`TP '0;
              r_weightMask <= #`TP '0;
            end else begin
              if(!i_clr_n) begin
                r_weight     <= #`TP '0;
                r_weightMask <= #`TP '0;
              end else if(o_granted) begin
                foreach (o_grant[index]) begin
                  if (o_grant[index]) begin
                    r_weight            <= #`TP '0;
                    r_weightMask[index] <= #`TP '0;
                  end
                end
              end else begin
                r_weight     <= #`TP r_weight;
                r_weightMask <= #`TP r_weightMask;
              end
            end
          end

          always_comb begin : proc_weightSum
            o_weight = '0;
            s_weightOverflow = '0;
            foreach (s_requestMasked[index]) begin
              if (s_requestMasked[index]) begin
                {s_weightOverflow[index],o_weight} = {1'b0,o_weight} + {1'b0,i_weight[index]};
              end
            end
          end


          assign s_requestMasked = |(i_request & ~r_weightMask) ? (i_request & ~r_weightMask) : i_request;
          assign s_shiftedReq = (s_requestMasked >> r_token) | (s_requestMasked << P_INPUTS-r_token);
        end else begin : GEN_ROUNDROBIN_ARBITER
          assign s_shiftedReq = (i_request >> r_token) | (i_request << P_INPUTS-r_token);
          assign o_weight = '0;
        end
        assign o_grant = i_en ? (s_shiftedGrant >> P_INPUTS-r_token) | (s_shiftedGrant << r_token) : '0;
      end else begin : GEN_STRICT_ARBITER
        assign s_shiftedReq = i_request;
        assign o_grant = i_en ? s_shiftedReq : '0;
        assign o_weight = '0;
      end

    end else begin : GEN_BYPASS_ARBITER
      assign o_grant = i_en ? i_request : '0;
      assign o_weight = '0;
    end
  endgenerate

  assign o_granted = i_en & |i_request;

endmodule : DWC_pcie_generic_arbiter
