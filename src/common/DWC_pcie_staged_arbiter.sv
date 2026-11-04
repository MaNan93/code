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
// ---    $Author: lnicola $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DWC_pcie_staged_arbiter.sv#10 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

`include "common/DWC_pcie_staged_arbiter_pkg.svh"

module DWC_pcie_staged_arbiter
import DWC_pcie_staged_arbiter_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
    parameter      P_INPUTS = 7
   ,parameter      P_STAGES = 3
   ,parameter type P_DATATYPE = logic
   ,parameter      P_WEIGHTED = 1
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
    input  logic                        i_clk
   ,input  logic                        i_rst_n
   ,input  logic                        i_clr_n
   ,input  logic                        i_en
   ,input  logic                        i_ready
   ,input  logic      [P_INPUTS-1:0]    i_request
   ,input  P_DATATYPE [P_INPUTS-1:0]    i_data
   ,output logic      [P_INPUTS-1:0]    o_grant
   ,output logic                        o_valid
   ,output P_DATATYPE                   o_data
  );

  localparam L_INPUTS_WD         = P_INPUTS > 1 ? $clog2(P_INPUTS) : 1;

  localparam L_BRANCHING_FACTOR  = $ceil(P_INPUTS ** (1.0 / P_STAGES));

  localparam L_REDUCED_STAGES    = f_reduced_stages(P_STAGES, P_INPUTS, L_BRANCHING_FACTOR);
  localparam L_OVERSHOOT         = f_overshoot(P_STAGES, P_INPUTS, L_REDUCED_STAGES, L_BRANCHING_FACTOR);

  localparam L_COMP_STAGE        = f_compensation_stage(P_STAGES, P_INPUTS);
  localparam L_ARB_COMP_COUNT    = L_COMP_STAGE * P_INPUTS;
  localparam L_ARB_REDUCED_COUNT = f_num_nodes_before(L_REDUCED_STAGES, P_STAGES, P_INPUTS, L_REDUCED_STAGES, L_BRANCHING_FACTOR) - L_ARB_COMP_COUNT;
  localparam L_ARB_COUNT         = f_num_nodes_before(P_STAGES, P_STAGES, P_INPUTS, L_REDUCED_STAGES, L_BRANCHING_FACTOR);

  localparam L_ARB_IN_WIRES      = P_INPUTS + L_ARB_COUNT - 1;
  localparam L_ARB_OUT_WIRES     = L_ARB_COUNT;

  logic      [L_ARB_IN_WIRES-1:0]                  w_arbiterInputs        ;
  logic      [L_ARB_IN_WIRES-1:0]                  w_arbiterGrantedInputs ;
  logic      [L_ARB_OUT_WIRES-1:0]                 w_arbiterOutputs       ;
  logic      [L_ARB_OUT_WIRES-1:0]                 w_arbiterRequestReady  ;
  P_DATATYPE [L_ARB_IN_WIRES-1:0]                  w_arbiterInputsData    ;
  P_DATATYPE [L_ARB_OUT_WIRES-1:0]                 w_arbiterOutputsData   ;
  logic      [L_ARB_IN_WIRES-1:0]  [L_INPUTS_WD:0] w_arbiterInputsWeight  ;
  logic      [L_ARB_OUT_WIRES-1:0] [L_INPUTS_WD:0] w_arbiterOutputsWeight ;
  logic                            [L_INPUTS_WD:0] s_outputWeights        ;

  genvar stage,arb;
  generate
    for (stage = 0; stage < P_STAGES; stage += 1) begin : pipelineStage_GEN
      localparam L_NUM_NODES    = f_num_nodes(stage, P_STAGES, P_INPUTS, L_REDUCED_STAGES, L_BRANCHING_FACTOR);
      localparam L_NODES_BEFORE = f_num_nodes_before(stage, P_STAGES, P_INPUTS, L_REDUCED_STAGES, L_BRANCHING_FACTOR);

      for (arb = 0; arb < L_NUM_NODES; arb += 1) begin : arbiterArray_GEN
        localparam L_ARB_INPUTS = f_arb_inputs(stage, arb, L_OVERSHOOT, L_REDUCED_STAGES, L_BRANCHING_FACTOR, L_COMP_STAGE);
        localparam L_ARB_INPTR  = f_arb_inptr(stage, arb, L_OVERSHOOT, L_REDUCED_STAGES, L_BRANCHING_FACTOR, L_NODES_BEFORE, L_COMP_STAGE, L_ARB_COMP_COUNT,
                                              L_ARB_REDUCED_COUNT);
        localparam L_ARB_OUTPTR = L_NODES_BEFORE + arb;

        logic w_requestEn;
        logic [L_ARB_INPUTS-1:0] w_request;
        // SMD: Not all bits of a bus are set
        // SJ : The signal is clearly set a couple of line below by w_arbiterInputsWeight signal
        // spyglass disable_block W497
        logic [L_ARB_INPUTS-1:0][L_INPUTS_WD:0] w_weightIn;
        // spyglass enable_block W497
        P_DATATYPE [L_ARB_INPUTS-1:0] w_requestData;
        logic w_granted;
        logic [L_ARB_INPUTS-1:0] w_grant;
        P_DATATYPE s_grantedData;
        P_DATATYPE r_grantedData;
        logic r_granted;
        logic [L_INPUTS_WD:0] w_weightOut;
        logic [L_INPUTS_WD:0] r_weight;

        DWC_pcie_generic_arbiter
         #(
           .P_INPUTS   (L_ARB_INPUTS)
          ,.P_WEIGHTWD (L_INPUTS_WD+1)
          ,.P_TYPE     (2'b10) // WEIGHTED
        ) u_rordr_arb(
           .i_clk     (i_clk      )
          ,.i_rst_n   (i_rst_n    )
          ,.i_clr_n   (i_clr_n    )
          ,.i_en      (w_requestEn)
          ,.i_request (w_request  )
          ,.i_weight  (w_weightIn )
          ,.o_granted (w_granted  )
          ,.o_grant   (w_grant    )
          ,.o_weight  (w_weightOut)
          );
        
        always_ff @(posedge i_clk, negedge i_rst_n) begin : grantedReg_PROC
          if (!i_rst_n) begin
            r_granted     <= #`TP '0;
            r_grantedData <= #`TP '0;
            r_weight      <= #`TP '0;
          end else begin
            if(!i_clr_n) begin
              r_granted     <= #`TP '0;
              r_grantedData <= #`TP '0;
              r_weight      <= #`TP '0;
            end else if (w_requestEn) begin
              r_granted     <= #`TP w_granted;
              r_grantedData <= #`TP s_grantedData;
              r_weight      <= #`TP w_weightOut;
            end
          end
        end
        
        always_comb begin : grantedDataMux_PROC
          int i;
          s_grantedData = '0;
          for (i=0; i<L_ARB_INPUTS; i+=1) begin
            if (w_grant[i]) begin
              s_grantedData = w_requestData[i];
            end
          end
        end
        

        assign w_requestEn = (!r_granted || w_arbiterRequestReady[L_ARB_OUTPTR]) && i_en;
        assign w_request = w_arbiterInputs[L_ARB_INPTR +: L_ARB_INPUTS];
        assign w_requestData = w_arbiterInputsData[L_ARB_INPTR +: L_ARB_INPUTS];
        assign w_weightIn = (P_WEIGHTED == 1) ? w_arbiterInputsWeight[L_ARB_INPTR +: L_ARB_INPUTS] : {L_ARB_INPUTS{(L_INPUTS_WD+1)'(1)}};
        assign w_arbiterGrantedInputs[L_ARB_INPTR +: L_ARB_INPUTS] = w_grant;
        assign w_arbiterOutputs[L_ARB_OUTPTR] = r_granted;
        assign w_arbiterOutputsData[L_ARB_OUTPTR] = r_grantedData;
        assign w_arbiterOutputsWeight[L_ARB_OUTPTR] = r_weight;
      end
    end
  endgenerate

  assign {o_valid, w_arbiterInputs} = {w_arbiterOutputs, i_request};
  assign {o_data, w_arbiterInputsData} = {w_arbiterOutputsData, i_data};
  assign {s_outputWeights, w_arbiterInputsWeight} = {w_arbiterOutputsWeight, {P_INPUTS{(L_INPUTS_WD+1)'(1)}}};
  assign {w_arbiterRequestReady, o_grant} = {i_ready, w_arbiterGrantedInputs};

endmodule : DWC_pcie_staged_arbiter
