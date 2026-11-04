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
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/xaim_pipe_w_order_ms.sv#4 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
//
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Adm_ms/xaim_ms_pkg.svh"
`include "products/pcie_pkg.svh"

module xaim_pipe_w_order_ms
import DWC_pcie_ctl_pkg::*;
import DWC_pcie_core_pkg::*;
import xaim_ms_pkg::*;
import pcie_pkg::*;
#(
  parameter BUS_PROTECT_CHK_EN            = 1,
  parameter BUS_PROTECT_GEN_EN_PRFX       = 0,
  parameter BUS_PROTECT_CHK_EN_PRFX       = BUS_PROTECT_CHK_EN,
  parameter BUS_PROTECT_GEN_EN_HDR        = 1,
  parameter BUS_PROTECT_CHK_EN_HDR        = BUS_PROTECT_CHK_EN,
  parameter BUS_PROTECT_GEN_EN_DATA       = 0,
  parameter BUS_PROTECT_CHK_EN_DATA       = BUS_PROTECT_CHK_EN,
  parameter RAS_DP_PROT_CHK_ID_BASE       = 0,
  parameter tx_port_id_e PORT_E           = E_TX_PORT_ID_XALI,
  parameter N                             = 2,
  parameter PIPE                          = 1,
  parameter CAN_STALL                     = 1,
  parameter PREV_STAGE_CAN_HALT           = 1
)
(
  input  logic                    clk,
  input  logic                    rst_n,
  input  mode_e                   mode,
  output ras_dp_err_log_t [N-1:0] [2:0] ras_dp_err_log,
  input  ras_dp_err_inj_t         ras_dp_err_inj,
  input  xaim_pkt_t       [N-1:0] in_pkt,
  output logic            [N-1:0] out_halt,
  input  logic            [N-1:0] in_prev_stage_halt,
  output xaim_pkt_t       [N-1:0] out_pkt,
  input  logic            [N-1:0] in_halt
);
localparam CAN_MASK = (N>1 && PIPE==1); // masking is possible if we have 2 interfaces and the pipe is really a pipe
localparam int CAN_BADEOT = 1 -1; // no bad_eot for AMBA

// Logic Defines
xaim_pkt_t [N-1:0] ordered_in_pkt;
logic      [N-1:0] ordered_out_halt;
logic      [N-1:0] mask_input;
xaim_pkt_t [N-1:0] ordered_out_pkt;
logic      [N-1:0] ordered_in_halt;
logic      [N-1:0] mask_output;

///////////////////////////////////////////
// Re-order input packet if required
///////////////////////////////////////////
generate
    if(CAN_MASK==0)begin : g_n_1_or_pipe0_input
    assign mask_input    = '0;
  end else begin : g_n_2_or_pipe_in
    assign mask_input[0] = in_pkt[0].fs.hv && (in_pkt[1].fs.hv || in_pkt[1].fs.dv) && (in_pkt[0].fs.order_seqnum==(in_pkt[1].fs.order_seqnum + 3'd1)) && (ordered_out_halt[1] || !in_pkt[1].fs.eot);
    assign mask_input[1] = in_pkt[1].fs.hv && (in_pkt[0].fs.hv || in_pkt[0].fs.dv) && (in_pkt[1].fs.order_seqnum==(in_pkt[0].fs.order_seqnum + 3'd1)) && (ordered_out_halt[0] || !in_pkt[0].fs.eot);
  end
endgenerate

always_comb begin
    for(int i = 0; i < N; i++)begin
        ordered_in_pkt[i]                = in_pkt[i];
        ordered_in_pkt[i].fs.hv          = in_pkt[i].fs.hv      && (CAN_MASK==0 || !mask_input[i]) && (PREV_STAGE_CAN_HALT==0 || !in_prev_stage_halt[i]);
        ordered_in_pkt[i].fs.dv          = in_pkt[i].fs.dv      && (CAN_MASK==0 || !mask_input[i]) && (PREV_STAGE_CAN_HALT==0 || !in_prev_stage_halt[i]);
        ordered_in_pkt[i].fs.eot         = in_pkt[i].fs.eot     && (CAN_MASK==0 || !mask_input[i]) && (PREV_STAGE_CAN_HALT==0 || !in_prev_stage_halt[i]);
        ordered_in_pkt[i].fs.bad_eot     = in_pkt[i].fs.bad_eot && (CAN_MASK==0 || !mask_input[i]) && (PREV_STAGE_CAN_HALT==0 || !in_prev_stage_halt[i]);
        out_halt[i]                      = ordered_out_halt[i] || mask_input[i];
    end
end

///////////////////////////////////////////
// Instantiate xaim_pipe_ms
///////////////////////////////////////////
xaim_pipe_ms
 #(
  .BUS_PROTECT_GEN_EN_PRFX ( BUS_PROTECT_GEN_EN_PRFX ),
  .BUS_PROTECT_CHK_EN_PRFX ( BUS_PROTECT_CHK_EN_PRFX ),
  .BUS_PROTECT_GEN_EN_HDR  ( BUS_PROTECT_GEN_EN_HDR  ),
  .BUS_PROTECT_CHK_EN_HDR  ( BUS_PROTECT_CHK_EN_HDR  ),
  .BUS_PROTECT_GEN_EN_DATA ( BUS_PROTECT_GEN_EN_DATA ),
  .BUS_PROTECT_CHK_EN_DATA ( BUS_PROTECT_CHK_EN_DATA ),
  .RAS_DP_PROT_CHK_ID_BASE ( RAS_DP_PROT_CHK_ID_BASE ),
  .PORT_E                  ( PORT_E                  ),
  .N                       ( N                       ),
  .PIPE                    ( PIPE                    ),
  .CAN_STALL               ( CAN_STALL               )
) u_xaim_pipe_ms (
  .clk,
  .rst_n,
  .ras_dp_err_log          ( ras_dp_err_log          ),
  .ras_dp_err_inj          ( ras_dp_err_inj          ),
  .i_xaim_pkt              ( ordered_in_pkt          ),
  .o_xaim_halt             ( ordered_out_halt        ),
  .o_xaim_pkt              ( ordered_out_pkt         ),
  .i_xaim_halt             ( ordered_in_halt         )
);

///////////////////////////////////////////
// Re-order output packet if required
///////////////////////////////////////////
generate
  // Only one packet or two pkts but without delay, nothing to worry about
  if(CAN_MASK==0)begin : g_n_1_or_pipe0_output
    assign mask_output = '0;
  end else begin : g_n_2_or_pipe_out
    assign mask_output[0] = ordered_out_pkt[0].fs.hv && (ordered_out_pkt[1].fs.hv || ordered_out_pkt[1].fs.dv) && ((ordered_out_pkt[0].fs.order_seqnum==(ordered_out_pkt[1].fs.order_seqnum + 3'd2)) || ((ordered_out_pkt[0].fs.order_seqnum==(ordered_out_pkt[1].fs.order_seqnum + 3'd1)) && !ordered_out_pkt[1].fs.eot));
    assign mask_output[1] = ordered_out_pkt[1].fs.hv && (ordered_out_pkt[0].fs.hv || ordered_out_pkt[0].fs.dv) && ((ordered_out_pkt[1].fs.order_seqnum==(ordered_out_pkt[0].fs.order_seqnum + 3'd2)) || ((ordered_out_pkt[1].fs.order_seqnum==(ordered_out_pkt[0].fs.order_seqnum + 3'd1)) && !ordered_out_pkt[0].fs.eot));
  end
endgenerate

always_comb begin
  for(int i = 0; i < N; i++)begin
    out_pkt[i]                = ordered_out_pkt[i];
    out_pkt[i].fs.hv          = ordered_out_pkt[i].fs.hv      && (CAN_MASK==0 || !mask_output[i]);
    out_pkt[i].fs.dv          = ordered_out_pkt[i].fs.dv      && (CAN_MASK==0 || !mask_output[i]);
    out_pkt[i].fs.eot         = ordered_out_pkt[i].fs.eot     && (CAN_MASK==0 || !mask_output[i]);
    out_pkt[i].fs.bad_eot     = ordered_out_pkt[i].fs.bad_eot && (CAN_MASK==0 || !mask_output[i]);
    ordered_in_halt[i]        = (in_halt[i] || (CAN_MASK==1 && mask_output[i]));//  && (ordered_out_pkt[i].fs.hv || ordered_out_pkt[i].fs.dv); // removed because xaim_pipe_ms uses a pipeline=pipe_w_hs where the halt is not just the registered version of the halt_in, but is validated by the pipeline containing stuff
    //`ifndef SYNTHESIS  // On the output of every pipeline, decode tlp
    //out_pkt[i].tlp_hdr_decode = f_tlp_hdr_decode(mode, ordered_out_pkt[i].tlp_hdr_pkt);
    //`endif // SYNTHESIS
  end
end



endmodule

