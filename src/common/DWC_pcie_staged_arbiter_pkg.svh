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

// -----------------------------------------------------------------------------
// --- RCS information:
// ---   $DateTime: 2023/12/22 07:15:34 $
// ---   $Author: lnicola $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/common/DWC_pcie_staged_arbiter_pkg.svh#1 $
// -----------------------------------------------------------------------------

`ifndef __GUARD__DWC_PCIE_STAGED_ARBITER_PKG__SVH__
`define __GUARD__DWC_PCIE_STAGED_ARBITER_PKG__SVH__

// -----------------------------------------------------------------------------
// --- Package Description: Staged Arbiter Functions Package 
// --- The staged arbiter generates an m-ary geometric tree with each node corresponding to with corrections to a generic arbiter, with corrections to better
// --- dimension it to the number of required inputs.
// --- 
// --- The tree's last stage has one node. To get the previous stages' (s-1) number of nodes, we multiply the number of nodes of the current stage (s) by a
// --- branching factor (n_(s-1) = n_s * branching_factor). To try to better match the number of arbiters on the last stage, the branching factor can be
// --- decremented by one for the first few stages (hereby called reduced stages). Even so, on stage 0 (the input stage), the number of inputs can not match the
// --- number of inputs of the staged arbiter. Therefore, the first nodes of the stage 0 can be decreased for matching the inputs (see overshoot).
// --- 
// --- If the number of stages is not correctly set (the number of inputs being less than 2**(stages)), there needs to be some stages where some nodes have 1
// --- input and 1 output. In this case, the overshoot is corrected at the first stage after these "useless" stages.
// -----------------------------------------------------------------------------
package DWC_pcie_staged_arbiter_pkg;

  // Calculates the number of reduced stages.
  // Reduced stages are stages in which the arbiters have a number of inputs less than the the branching factor.
  //
  // It is calculated by finding the last reduced_stages value where the number of inputs of the last stage is larger than the number of inputs of the staged
  // arbiter.
  function automatic int f_reduced_stages
    (
      int stages
     ,int inputs
     ,int branching_factor
    );

    int reduced_stages = stages;

    while (reduced_stages > 0 && (branching_factor-1) ** reduced_stages * (branching_factor) ** (stages-reduced_stages) < inputs) begin
      reduced_stages--;
    end

    return reduced_stages;
  endfunction : f_reduced_stages

  // Calculates the input overshoot, i.e., the number of extra inputs on the last stage, even after considering the the reduced stages.
  function automatic int f_overshoot
    (
      int stages
     ,int inputs
     ,int reduced_stages
     ,int branching_factor
    );

    return (branching_factor-1) ** reduced_stages * branching_factor ** (stages - reduced_stages) - inputs;
  endfunction : f_overshoot

  // Determines the compensation stage, i.e., stage in which the overshoot is corrected. The stages before the correction stage have arbiters with 1 input and
  // one output and 1 output.
  function automatic int f_compensation_stage
    (
      int stages
     ,int inputs
    );

    int comp_stage = stages - $clog2(inputs);
    return comp_stage > 0 ? comp_stage : 0;
  endfunction : f_compensation_stage

  // Determines the number of nodes (generic arbiters) at each stage. There can't be more nodes in a stage than inputs. This happens when the number of stages
  // is not correctly adjusted to the number of inputs -- inputs < 2**stages.
  function automatic int f_num_nodes
    (
      int stage
     ,int stages
     ,int inputs
     ,int reduced_stages
     ,int branching_factor
    );

    int num_nodes;

    if (stage < (reduced_stages - 1)) begin
      num_nodes = (branching_factor ** (stages - reduced_stages)) * ((branching_factor - 1) ** (reduced_stages - stage - 1));
    end else begin
      num_nodes = branching_factor ** (stages - stage - 1);
    end

    return num_nodes > inputs ? inputs : num_nodes;
  endfunction : f_num_nodes

  // Determines the number of nodes (generic arbiters) before the specified stage. This could be calculated by the geometric sum, but it gets trickier due to
  // the 1-input 1-output stages.
  function automatic int f_num_nodes_before
    (
      int stage
     ,int stages
     ,int inputs
     ,int reduced_stages
     ,int branching_factor
    );

    int num_nodes_before = 0;

    for (int i = 0; i < stage; i++) begin
      num_nodes_before = int'(num_nodes_before + f_num_nodes(i, stages, inputs, reduced_stages, branching_factor));
    end

    return num_nodes_before;
  endfunction : f_num_nodes_before

  // Determines the number of inputs for a given arbiter at a given stage.
  function automatic int f_arb_inputs
    (
      int stage
     ,int arb
     ,int overshoot
     ,int reduced_stages
     ,int branching_factor
     ,int comp_stage
    );

    int arb_inputs = branching_factor;

    if (stage == comp_stage && arb < overshoot) begin
      arb_inputs--;
    end

    if (stage < reduced_stages) begin
      arb_inputs--;
    end

    return arb_inputs > 0 ? arb_inputs : 1;
  endfunction : f_arb_inputs

  // Determines the input pointer of a given arbiter at a given stage. The pointer is the index of the input in an one-dimensional array with all generic 
  // arbiter inputs.
  function automatic int f_arb_inptr
    (
      int stage
     ,int arb
     ,int overshoot
     ,int reduced_stages
     ,int branching_factor
     ,int nodes_before
     ,int comp_stage
     ,int arb_comp_count
     ,int arb_reduced_count
    );

    if (reduced_stages > 0) begin
      if (stage < comp_stage) begin
        return int'(nodes_before + arb);
      end else if (stage == comp_stage && reduced_stages > 0) begin
        if (arb < overshoot) begin
          return arb_comp_count + (branching_factor > 2 ? branching_factor - 2 : 1) * arb;
        end else begin
          return arb_comp_count + (branching_factor > 2 ? branching_factor - 1 : 2) * arb - overshoot;
        end 
      end else if (stage < reduced_stages) begin
        return arb_comp_count + (branching_factor - 1) * (nodes_before - arb_comp_count + arb) - overshoot;
      end else begin
        return arb_comp_count + (branching_factor - 1) * arb_reduced_count - overshoot
               + branching_factor * (nodes_before - arb_reduced_count - arb_comp_count + arb);
      end
    end else begin
      if (stage == 0 && arb < overshoot) begin
        return arb * (branching_factor-1);
      end else begin
        return int'((nodes_before + arb) * branching_factor - overshoot);
      end
    end
  endfunction : f_arb_inptr

endpackage : DWC_pcie_staged_arbiter_pkg

`endif //__GUARD__DWC_PCIE_STAGED_ARBITER_PKG__SVH__
