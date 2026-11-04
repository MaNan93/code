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
// --- RCS information:
// ---   $DateTime: 2023/12/22 07:15:34 $
// ---   $Revision: #1 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_tx_tl_ram.sv#1 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// CXL Transmitter Transaction Layer Internal Data RAMs
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

module DWC_cxl_mem_cache_tx_tl_ram
    import DWC_cxl_pkg::*;
#(
    parameter TP = `TP
 )(
    // -------------------------------------------------------------------------------------
    // Clock and Reset
    // -------------------------------------------------------------------------------------
    DWC_cxl_clk_rst_if.slave_mp              b_clk                 // Clock and Reset interface
    // -------------------------------------------------------------------------------------
    // CXL Transmitter RAM Interfaces
    // -------------------------------------------------------------------------------------
    , DWC_cxl_ram2p_if.slave_chdata_mp       b_cxl_slv_hd_data_ram // CXL HD DATA RAM Interface
    , DWC_cxl_ram2p_if.slave_chdata_mp       b_cxl_slv_ms_data_ram // CXL MS DATA RAM Interface
);

  DWC_pcie_ctl_bcm57
   #(
    .MEM_MODE                         ( 0                 ),
    .DATA_WIDTH                       ( HD_DATAW          ),
    .DEPTH                            ( HD_DATA_RAM_DEPTH ),
    .ADDR_WIDTH                       ( HD_DATA_RAM_ADDRW )
  ) 
  u_hd_data_ram (
    .clk                              ( b_clk.s_cxl_clk                     ),
    .rst_n                            ( b_clk.s_cxl_rst_n                   ),
    .wr_n                             ( ~b_cxl_slv_hd_data_ram.s_ram_we     ),
    .wr_addr                          ( b_cxl_slv_hd_data_ram.s_ram_wr_addr ),
    .data_in                          ( b_cxl_slv_hd_data_ram.s_ram_wdata   ),
    .rd_addr                          ( b_cxl_slv_hd_data_ram.s_ram_rd_addr ),
    .data_out                         ( b_cxl_slv_hd_data_ram.s_ram_rdata   )
  );

  DWC_pcie_ctl_bcm57
   #(
    .MEM_MODE                         ( 0                 ),
    .DATA_WIDTH                       ( MS_DATAW          ),
    .DEPTH                            ( MS_DATA_RAM_DEPTH ),
    .ADDR_WIDTH                       ( MS_DATA_RAM_ADDRW )
  ) 
  u_ms_data_ram (
    .clk                              ( b_clk.s_cxl_clk                     ),
    .rst_n                            ( b_clk.s_cxl_rst_n                   ),
    .wr_n                             ( ~b_cxl_slv_ms_data_ram.s_ram_we     ),
    .wr_addr                          ( b_cxl_slv_ms_data_ram.s_ram_wr_addr ),
    .data_in                          ( b_cxl_slv_ms_data_ram.s_ram_wdata   ),
    .rd_addr                          ( b_cxl_slv_ms_data_ram.s_ram_rd_addr ),
    .data_out                         ( b_cxl_slv_ms_data_ram.s_ram_rdata   )
  );

endmodule : DWC_cxl_mem_cache_tx_tl_ram
