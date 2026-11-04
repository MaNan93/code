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

// -------------------------------------------------------------------------------------
// ---  RCS information:
// ---    $DateTime: 2023/07/13 01:59:50 $
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/outbound/DWC_pcie_axi_ob_rsp_formation_ctl.sv#5 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_axi_ob_rsp_formation_ctl
  #(
  parameter SLV_MAX_RD_SIZE_PW             = 5,
  parameter SLV_MTU_PW                     = 7,
  parameter NPRSPF_TLP_NUM_STRBS           = 1,
  parameter TP                             = `TP
  )
  (
  input                                              slv_aclk,
  input                                              slv_aresetn,
  // -------------------------------------------------------------------------------------
  // Composed completion interface
  input                                              cmp_cpl_hv,
  input                                              cmp_cpl_dv,
  input                                              cmp_cpl_eot,
  input       [SLV_MAX_RD_SIZE_PW-1:0]               cmp_cpl_byte_len,
  input                                              cmp_cpl_to,
  input       [2:0]                                  cmp_cpl_status,
  output wire                                        ctl_halt,
  // -------------------------------------------------------------------------------------
  // AXI Slave response interface
  output wire                                        ctl_valid,
  output wire                                        ctl_last,
  input                                              ready
  );
  // -------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------
  localparam ST_IDLE               = 2'd0;
  localparam ST_ERR_RSP_MULTI_BEAT = 2'd1;
  localparam ST_OKAY_MULTI_BEAT    = 2'd2;
  localparam ST_ERR_RSP_MULTI_BEAT_EOT_ALIGN = 2'd3;

  localparam NUM_BYTES_PER_BEAT = NPRSPF_TLP_NUM_STRBS;

  // -------------------------------------------------------------------------------------
  // Internal wire/reg
  // -------------------------------------------------------------------------------------
  wire                                     s_ur, s_ca, s_cpl_err;
  reg                                      s_valid, s_last, s_halt;
  reg  [SLV_MTU_PW-1:0]                    s_max_byte_cnt, r_max_byte_cnt;
  reg  [1:0]                               s_slv_resp_fsm, r_slv_resp_fsm;


  // -------------------------------------------------------------------------------------
  // Design
  // -------------------------------------------------------------------------------------
  // The composer sends single beat error response TLP's to the response
  // formation block. The AXI Slave protocol requires the requested number
  // of data transfers to be performed even if an error is reported.
  // The burst byte counter tracks the number of bytes returned to the slave.
  // When the number of composed bytes is less than or equal to the data width
  // aligned number of bytes the transfer is terminated.
  // The slave expects packed data width transfers aligned to the data width boundary.

  // The AXI Slave response FSM tracks errored and non-errored slave responses as
  // completions are received from the composer.

  // Detect errored completion status
  assign s_ca    = (cmp_cpl_status==`CA_CPL_STATUS);
  assign s_ur    = (cmp_cpl_status==`UR_CPL_STATUS);
  assign s_cpl_err = cmp_cpl_to || s_ca || s_ur;

  // Slave FSM combinational
  always @(*) begin : proc_comb_slv_rsp_fsm
    // Initialse
    s_slv_resp_fsm = r_slv_resp_fsm;
    s_max_byte_cnt = r_max_byte_cnt;
    s_valid        = 1'b0;
    s_last         = 1'b0;
    s_halt         = !ready;

    if (ready) begin
      case (r_slv_resp_fsm)
        ST_IDLE : begin
          if (cmp_cpl_hv) begin
            s_valid = cmp_cpl_hv;
            if (s_cpl_err) begin
              // Check if multi-beat error response required
              if (cmp_cpl_byte_len>NUM_BYTES_PER_BEAT) begin
                s_slv_resp_fsm = ST_ERR_RSP_MULTI_BEAT;
                s_max_byte_cnt = r_max_byte_cnt + NUM_BYTES_PER_BEAT;
                s_halt         = 1'b1;
              end else
                s_last  = cmp_cpl_eot;
            end else begin
              // Check if multi-beat ok response required
              if (!cmp_cpl_eot) begin
                s_slv_resp_fsm = ST_OKAY_MULTI_BEAT;
              end else begin
                s_last = cmp_cpl_eot;
              end
            end
          end
        end
        ST_ERR_RSP_MULTI_BEAT : begin
          s_valid = 1'b1;
          if (cmp_cpl_byte_len<=r_max_byte_cnt) begin
            if(cmp_cpl_eot) begin
              s_slv_resp_fsm = ST_IDLE;
              s_max_byte_cnt = NUM_BYTES_PER_BEAT;
              s_last         = 1'b1;
              s_halt         = 1'b0;
            end else begin
              s_slv_resp_fsm = ST_ERR_RSP_MULTI_BEAT_EOT_ALIGN;
              s_valid        = 1'b0;
              s_halt         = 1'b0;
            end
          end else begin
            s_halt         = 1'b1;
            s_max_byte_cnt = r_max_byte_cnt + NUM_BYTES_PER_BEAT;
          end
        end

        ST_ERR_RSP_MULTI_BEAT_EOT_ALIGN : begin
          s_halt = 1'b0;
          if(cmp_cpl_eot) begin
            s_valid        = 1'b1;
            s_slv_resp_fsm = ST_IDLE;
            s_max_byte_cnt = NUM_BYTES_PER_BEAT;
            s_last         = 1'b1;
          end
        end
        ST_OKAY_MULTI_BEAT : begin
          s_valid = cmp_cpl_dv;
          if (cmp_cpl_eot) begin
            s_slv_resp_fsm = ST_IDLE;
            s_last         = cmp_cpl_eot;
          end
        end
      endcase
    end
 end

  // Slave FSM sequential
  always @(posedge slv_aclk or negedge slv_aresetn) begin : proc_seq_slv_rsp_fsm
    if (!slv_aresetn) begin
     r_slv_resp_fsm <= # TP ST_IDLE;
     r_max_byte_cnt <= # TP NUM_BYTES_PER_BEAT;
    end else if (ready) begin
     r_slv_resp_fsm <= # TP s_slv_resp_fsm;
     r_max_byte_cnt <= # TP s_max_byte_cnt;
    end
  end


  // -------------------------------------------------------------------------------------
  // Assign outputs
  assign ctl_valid = s_valid;
  assign ctl_last  = s_last;
  assign ctl_halt  = s_halt;

`ifndef SYNTHESIS
  // -------------------------------------------------------------------------------------
  // Enumerate FSM
  wire [16*8:1] RSP_FSM;

  assign RSP_FSM = (r_slv_resp_fsm==ST_IDLE)               ? "IDLE"    :
                   (r_slv_resp_fsm==ST_ERR_RSP_MULTI_BEAT) ? "ERR_RSP" :
                   (r_slv_resp_fsm==ST_OKAY_MULTI_BEAT)    ? "OK_RSP"  :
                   "UNDEF";

`endif

endmodule
