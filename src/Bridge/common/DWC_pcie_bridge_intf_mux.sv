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
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/common/DWC_pcie_bridge_intf_mux.sv#3 $
// -------------------------------------------------------------------------
// ----------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_bridge_intf_mux
 #(
  parameter INTF_WD                 = 5,
  parameter MULTI_BEAT              = 0,
  parameter TP                      = `TP
  )
  (
  input                                              clk,
  input                                              rst_n,
  // -------------------------------------------------------------------------------------
  // Interface A
  input                                              valid_a,
  input                                              last_a,
  input       [INTF_WD-1:0]                          intf_a,
  output wire                                        ready_a,
  // -------------------------------------------------------------------------------------
  // Interface B
  input                                              valid_b,
  input                                              last_b,
  input       [INTF_WD-1:0]                          intf_b,
  output wire                                        ready_b,
  // -------------------------------------------------------------------------------------
  // Muxed Interface
  output wire                                        mux_valid_a,
  output wire                                        mux_valid_b,
  output wire                                        mux_last,
  output wire [INTF_WD-1:0]                          mux_intf,
  input                                              ready
  );
  // -------------------------------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------------------------------
  localparam S_IDLE   = 2'b00;
  localparam S_INTF_A = 2'b01;
  localparam S_INTF_B = 2'b10;
  // -------------------------------------------------------------------------------------
  // Wire/Reg
  // -------------------------------------------------------------------------------------
  reg                                      s_mux_valid_a;
  reg                                      s_mux_valid_b;
  reg                                      s_ready_a;
  reg                                      s_ready_b;
  reg                                      s_sel_b;
  reg  [1:0]                               s_arb_fsm; 
  reg  [1:0]                               r_arb_fsm; 
  reg                                      r_xfer_pending_b;
  // -------------------------------------------------------------------------------------
  // Design 
  // -------------------------------------------------------------------------------------
  generate
    if (MULTI_BEAT) begin : gen_mux_multi_beat
      // Arbiter
      // Give priority to interface A
      always @(*) begin : proc_comb_arb_multi_beat
        // Initialise
        s_mux_valid_a = valid_a;
        s_mux_valid_b = valid_b;
        s_ready_a     = ready;
        s_ready_b     = ready;
        s_sel_b       = 1'b0;
        s_arb_fsm     = r_arb_fsm;

        case (r_arb_fsm)
          S_IDLE : begin
            if (valid_a && !r_xfer_pending_b) begin 
              s_mux_valid_a = valid_a;
              s_mux_valid_b = 1'b0;
              s_ready_b     = 1'b0;
              if (!last_a) begin
                s_arb_fsm = S_INTF_A; 
              end
            end else if (valid_b) begin
              s_mux_valid_b = valid_b;
              s_mux_valid_a = 1'b0;
              s_ready_a     = 1'b0;
              s_sel_b       = 1'b1;
              if (!last_b) begin
                s_arb_fsm = S_INTF_B; 
              end
            end
          end
          S_INTF_A : begin
            s_mux_valid_a = valid_a;
            s_mux_valid_b = 1'b0;
            s_ready_b     = 1'b0;
            if (last_a) begin
              s_arb_fsm = S_IDLE; 
            end
          end
          S_INTF_B : begin
            s_mux_valid_b = valid_b;
            s_mux_valid_a = 1'b0;
            s_ready_a     = 1'b0;
            s_sel_b       = 1'b1;
            if (last_b) begin
               s_arb_fsm = S_IDLE; 
            end
          end
          default : begin
            s_mux_valid_a = valid_a;
            s_mux_valid_b = valid_b;
            s_ready_a     = ready;
            s_ready_b     = ready;
            s_sel_b       = 1'b0;
            s_arb_fsm     = r_arb_fsm;
          end
        endcase
      end

      always @(posedge clk or negedge rst_n) begin : proc_seq_arb_multi_beat
        if (!rst_n) begin
          r_arb_fsm <= # TP S_IDLE;
        end else if (ready) begin
          r_arb_fsm <= # TP s_arb_fsm;
        end  
      end

    end else begin : gen_not_mux_multi_beat

    // Arbiter
    // Give priority to interface a
      always @(*) begin : proc_comb_arb_single_beat
        s_mux_valid_a = valid_a;
        s_mux_valid_b = valid_b;
        s_ready_a     = ready;
        s_ready_b     = ready;
        s_sel_b       = 1'b0;

        if (valid_a && !r_xfer_pending_b) begin 
          s_mux_valid_a = valid_a;
          s_mux_valid_b = 1'b0;
          s_ready_b     = 1'b0;
        end else if (valid_b) begin
          s_mux_valid_b = valid_b;
          s_sel_b       = 1'b1;
          s_mux_valid_a = 1'b0;
          s_ready_a     = 1'b0;
        end
      end

    end
  endgenerate

  // -------------------------------------------------------------------------------------
  // Detect if transfer b in progress, i.e. valid asserted but not accepted.
  // Used flag to block transfer a until b completes.
  // Using a flag versus polling the ready input avoids combinational loops
  // if the next stage gates the ready with mux_valid_*. 
  always @(posedge clk or negedge rst_n) begin : proc_seq_xfer_pending_b
    if (!rst_n) begin
      r_xfer_pending_b <= # TP 1'b0;
    end else begin
      if (s_mux_valid_b && !ready) begin
        r_xfer_pending_b <= # TP 1'b1; // ccx_line: u_axi_bridge.u_sif.u_srrq.u_npmux; REDUNDANT: downstream module (NP decomposer) is sized to take all NP requests the slave accepts so ready is never deasserted
      end else begin
        r_xfer_pending_b <= # TP 1'b0;
      end
    end  
  end

  // -------------------------------------------------------------------------------------
  // Assign outputs
  assign mux_valid_a = s_mux_valid_a;
  assign mux_valid_b = s_mux_valid_b;
  assign mux_last    = s_sel_b ? last_b : last_a;
  assign mux_intf    = s_sel_b ? intf_b : intf_a;
  assign ready_a     = s_ready_a;
  assign ready_b     = s_ready_b;

`ifndef SYNTHESIS
  wire [16*8:1] ARB_INTF_FSM;
  generate
    if (MULTI_BEAT) begin : gen_mux_fsm_states

      assign ARB_INTF_FSM = (r_arb_fsm==S_IDLE)   ? "IDLE"   :
                            (r_arb_fsm==S_INTF_A) ? "INTF_A" :                        
                            (r_arb_fsm==S_INTF_B) ? "INTF_B" :                        
                            "UNDEF";
    end
  endgenerate

`endif

endmodule
