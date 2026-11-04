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
// ---    $Revision: #9 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/serdes_arch/serdes_pipe_rx_subestore.sv#9 $
// --------------------------------------------------------------------------------------------
// --- Module Description: SerDes architecture receiver side elastic buffer sub module
// --------------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer1/serdes_arch/serdes_pipe_pkg.svh"

module serdes_pipe_rx_subestore

  import serdes_pipe_pkg::*;
#(
  parameter int  DEPTH   = 1,
  parameter int  ADDR_WD = $clog2(DEPTH),
  parameter int  DATA_WD = 1,
  parameter int  WR_WD   = 1,
  parameter int  RD_WD   = 1
) (
  // ---------- input (clk) --------------
  input logic                            clk,
  input logic                            rst_n,
  input logic [RD_WD-1:0]                rd_en,
  input logic [ADDR_WD-1:0]              rd_ptr,
  // ---------- input (rx_clk) -----------
  input logic                            rx_clk,
  input logic                            rx_rst_n,
  input logic                            buf_sync_rst,
  input logic [PHY_SYM_WD-1:0]           symbol_width_sync2rx,
  input logic [WR_WD-1:0]                wr_en,
  input logic [WR_WD-1:0][DATA_WD-1:0]   wrdata,
  // ---------- output (clk) -------------
  output logic [RD_WD-1:0][DATA_WD-1:0]  rddata
);

// --------------------------------------------------------------------------------
//  Write Pointer per byte
// --------------------------------------------------------------------------------
  logic [WR_WD-1:0][ADDR_WD-1:0]           wr_ptr_byte ;
  logic                                    load_rst_val ;
  
  // To load reset value of wr_ptr_byte. Because spyglass does not allow drive for integer "ii" to reset condition.
  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: load_rst_val_PROC
    if(!rx_rst_n) begin
      load_rst_val      <= #`TP 1'b1 ;
    end
    else begin
      load_rst_val      <= #`TP '0 ;
    end
  end

  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: wr_ptr_byte_PROC
    if(!rx_rst_n) begin
      for(int ii = 0; ii < WR_WD; ii++) begin
        wr_ptr_byte[ii] <= #`TP '0 ;
      end
    end
    else if(buf_sync_rst || load_rst_val) begin
      for(int ii = 0; ii < WR_WD; ii++) begin
        wr_ptr_byte[ii] <= #`TP ADDR_WD'( ii ) ;
      end
    end
    else begin
      for(int ii = 0; ii < WR_WD; ii++) begin
        if(wr_en[0]) begin
          if( (wr_ptr_byte[0] + symbol_width_sync2rx) == DEPTH ) begin
            wr_ptr_byte[ii] <= #`TP ADDR_WD'( ii ) ;
          end
          else begin
            wr_ptr_byte[ii] <= #`TP ADDR_WD'( wr_ptr_byte[ii] + symbol_width_sync2rx );
          end
        end
      end
    end
  end


// --------------------------------------------------------------------------------
//  Buffer write
// --------------------------------------------------------------------------------
  logic [DATA_WD-1:0]  buf_data        [0:DEPTH-1];
  logic [DATA_WD-1:0]  buf_data_concat [0:DEPTH+RD_WD-2];

  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: buf_data_PROC
    if(!rx_rst_n) begin
      for(int i = 0; i < DEPTH; i++) begin
        buf_data[i] <= #`TP '0;
      end
    end
    else if(buf_sync_rst) begin
      for(int i = 0; i < DEPTH; i++) begin
        buf_data[i] <= #`TP '0;
      end
    end
    else begin
      for(int i = 0; i < WR_WD; i++) begin
        if(wr_en[i]) begin
          buf_data[wr_ptr_byte[i]] <= #`TP wrdata[i];
        end
      end
    end
  end

  // concattenate addr [0] to [RD_WD-2] to MSB of buf_data
  always_comb begin
    for( int ii = 0 ; ii < DEPTH ; ii++ ) begin
      buf_data_concat[ii] = buf_data[ii] ;
    end
    for( int ii = 0 ; ii < RD_WD - 1 ; ii++ ) begin
      buf_data_concat[DEPTH + ii] = buf_data[ii] ;
    end
  end 


// --------------------------------------------------------------------------------
//  Buffer read with mux gating
// --------------------------------------------------------------------------------
  logic [RD_WD-1:0][DATA_WD-1:0]  mux_rddata ;

  always_comb begin
    for( int ii = 0 ; ii < RD_WD ; ii++ ) begin 
      mux_rddata[ii] = buf_data_concat[rd_ptr + ii] ;
    end
  end

  generate
    for(genvar i = 0; i < RD_WD; i++) begin: gen_serdes_pipe_rx_mux
      serdes_pipe_rx_mux
       #(
        .WIDTH(DATA_WD)
      ) u_serdes_pipe_rx_mux (
        // ------------- input -----------------
        .sel(rd_en[i]),
        .sel_0('0),
        .sel_1(mux_rddata[i]),
        // ------------- output ----------------
        .z(rddata[i])
      );
    end
  endgenerate


endmodule: serdes_pipe_rx_subestore
