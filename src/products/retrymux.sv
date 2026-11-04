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
// --- RCS information:
// ---   $DateTime: 2023/12/22 07:15:34 $
// ---   $Revision: #5 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/products/retrymux.sv#5 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
//  Retry RAM MUX
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"

module retrymux
  import cx_pl_pkg::tx_cmd_struct;
  import cx_pl_pkg::rbuf_struct;
  import cx_pl_pkg::P_RBUF_WD;
  import cx_pl_pkg::P_RBUF_PW;
  import cx_pl_pkg::P_NFM_RBUF_WD;
#(
  parameter TP = `TP
) (
  input                               core_clk,
  input                               core_rst_n,
  // ----------------------------------------------------------------------------
  // Inputs from the Retry RAM
  // ----------------------------------------------------------------------------
  input   [P_RBUF_WD -1:0]            retryram_data,        // Data coming back from Retry buffer RAM
  input   [P_RBUF_PW -1:0]            retryram_depth,       // How big is the external retry buffer
  input                               retryram_parerr,      // retry buffer ram parity error detected
  // ----------------------------------------------------------------------------
  // Outputs to the Retry RAM
  // ----------------------------------------------------------------------------
  output  rbuf_struct                 retrymux_if,          // Muxed Retry RAM Interface
  // ----------------------------------------------------------------------------
  // XDLH Interface
  // ----------------------------------------------------------------------------
  input   rbuf_struct                 xdlh_retry_if,        // Retry Buffer Interface from XDLH
  output  logic [P_NFM_RBUF_WD -1:0]  retrymux_xdlh_data,   // Data coming back from Retry buffer RAM
  output  logic                       retrymux_xdlh_parerr, // retry buffer ram parity error detected
  output  logic [P_RBUF_PW -1:0]      retrymux_xdlh_depth,  // How big is the external retry buffer
  // ----------------------------------------------------------------------------
  // XPLH Interface
  // ----------------------------------------------------------------------------
  input   rbuf_struct                 xplh_retry_if,        // Retry Buffer Interface from XDLH 
  output  logic [P_RBUF_WD -1:0]      retrymux_xplh_data,   // Data coming back from Retry buffer RAM
  // ----------------------------------------------------------------------------
  // Command Interface
  // ----------------------------------------------------------------------------
  input   tx_cmd_struct               xplh_xdlh_cmd         // Command Bus Interface
);

// ----------------------------------------------------------------------------
// Logic Declarations
// ----------------------------------------------------------------------------
rbuf_struct int_retry_if_s;

logic       int_flit_mode_s;
logic       int_flit_mode_r;

// ----------------------------------------------------------------------------
// Local Param Declarations
// ----------------------------------------------------------------------------
// Write Data
localparam P_WR_DATA_PIPE_WD = $bits(int_retry_if_s.retryram_data);
// Write Address + Read Address + Write Enable + Enable
localparam P_ADDR_PIPE_WD = 2 * $bits(int_retry_if_s.retryram_raddr) + 2;

assign int_flit_mode_s = xplh_xdlh_cmd.flit_mode;

// Register the Flit Mode Control Signal
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    int_flit_mode_r <= #TP '0;
  else
    int_flit_mode_r <= #TP int_flit_mode_s;
end

// In Flit Mode Connect the XPLH to the Retry RAM
// In non-Flit Mode Connect the XDLH to the Retry RAM
always_comb begin : fm_mux_PROC
  int_retry_if_s = '0;
  retrymux_xdlh_parerr = 1'b0;
  retrymux_xdlh_depth = retryram_depth;
  retrymux_xplh_data = retryram_data;
  retrymux_xdlh_data = retryram_data[P_NFM_RBUF_WD-1:0];
  if(int_flit_mode_r) begin
    int_retry_if_s = xplh_retry_if;
  end else begin
    retrymux_xdlh_parerr = retryram_parerr;
    int_retry_if_s = xdlh_retry_if;
  end
end : fm_mux_PROC

// Pipeline the Write Data
delay_n_w_enable

#(1, P_WR_DATA_PIPE_WD) u_rbuf_write_pipe (
  .clk    (core_clk),
  .rst_n  (core_rst_n),
  .clear  (1'b0),
  .en     (int_retry_if_s.retryram_we),
  .din    (int_retry_if_s.retryram_data),
  .dout   (retrymux_if.retryram_data)
);

// Pipeline the address and enables
delay_n_w_enable

#(1, P_ADDR_PIPE_WD) u_rbuf_addr_pipe (
  .clk    (core_clk),
  .rst_n  (core_rst_n),
  .clear  (1'b0),
  .en     (int_retry_if_s.retryram_we || int_retry_if_s.retryram_en),
  .din    ({int_retry_if_s.retryram_raddr, int_retry_if_s.retryram_waddr, int_retry_if_s.retryram_we, int_retry_if_s.retryram_en}),
  .dout   ({retrymux_if.retryram_raddr, retrymux_if.retryram_waddr, retrymux_if.retryram_we, retrymux_if.retryram_en})
);


endmodule
