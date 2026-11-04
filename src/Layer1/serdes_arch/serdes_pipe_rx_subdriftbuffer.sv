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
// ---    $DateTime: 2023/09/27 02:27:25 $
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/serdes_arch/serdes_pipe_rx_subdriftbuffer.sv#5 $
// --------------------------------------------------------------------------------------------
// --- Module Description: SerDes architecture receiver side drift buffer sub module
// --------------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer1/serdes_arch/serdes_pipe_pkg.svh"

module serdes_pipe_rx_subdriftbuffer

  import serdes_pipe_pkg::*;
#(
  parameter int  DEPTH   = 1,
  parameter int  ADDR_WD = $clog2(DEPTH),
  parameter int  DATA_WD = 1
) (
  // ---------- input (clk) --------------
  input logic                 clk,
  input logic                 rst_n,
  input logic                 rd_en,
  input logic [ADDR_WD-1:0]   rd_ptr,
  // ---------- input (rx_clk) -----------
  input logic                 rx_clk,
  input logic                 rx_rst_n,
  input logic                 rx_sync_rst,
  input logic                 wr_en,
  input logic [ADDR_WD-1:0]   wr_ptr,
  input logic [DATA_WD-1:0]   wr_data,
  // ---------- output (clk) -------------
  output logic [DATA_WD-1:0]  rd_data
);

// --------------------------------------------------------------------------------
//  Buffer write
// --------------------------------------------------------------------------------
  logic [DATA_WD-1:0]  buf_data [0:DEPTH-1];

  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: buf_data_PROC
    if(!rx_rst_n) begin
      for(int i = 0; i < DEPTH; i++) begin
        buf_data[i] <= #`TP '0;
      end
    end
    else if(rx_sync_rst) begin
      for(int i = 0; i < DEPTH; i++) begin
        buf_data[i] <= #`TP '0;
      end
    end
    else if(wr_en) begin
      buf_data[wr_ptr] <= #`TP wr_data;
    end
  end

// --------------------------------------------------------------------------------
//  Buffer read with mux gating
// --------------------------------------------------------------------------------
  serdes_pipe_rx_mux
   #(
    .WIDTH(DATA_WD)
  ) u_serdes_pipe_rx_mux (
    // ------------- input -----------------
    .sel(rd_en),
    .sel_0('0),
    .sel_1(buf_data[rd_ptr]),
    // ------------- output ----------------
    .z(rd_data)
  );


endmodule: serdes_pipe_rx_subdriftbuffer
