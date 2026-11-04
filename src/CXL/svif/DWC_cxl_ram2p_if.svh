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
// ---   $DateTime: 2023/06/26 08:32:07 $
// ---   $Revision: #3 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/svif/DWC_cxl_ram2p_if.svh#3 $
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_CXL_RAM2P_IF__SVH__
`define __GUARD__DWC_CXL_RAM2P_IF__SVH__

interface DWC_cxl_ram2p_if #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 2
);

  // RAM Interface
  logic                           s_ram_rd;                // RAM Read Enable
  logic [ADDR_WIDTH-1:0]          s_ram_rd_addr;           // RAM Read Address
  logic [DATA_WIDTH-1:0]          s_ram_rdata;             // RAM Read Data
  logic                           s_ram_we;                // RAM Write Enable
  logic [ADDR_WIDTH-1:0]          s_ram_wr_addr;           // RAM Write Address
  logic [DATA_WIDTH-1:0]          s_ram_wdata;             // RAM Write Data
  logic                           s_ram_rd_addr_par;       // RAM Read Address Parity
  logic                           s_ram_wr_addr_par;       // RAM Write Addres Parity

  modport master_mp(
    input   s_ram_rdata,
    output  s_ram_rd,
    output  s_ram_rd_addr,
    output  s_ram_we,
    output  s_ram_wr_addr,
    output  s_ram_wdata
    ,
    output  s_ram_rd_addr_par,
    output  s_ram_wr_addr_par
  );

  modport slave_mp(
    output  s_ram_rdata,
    input   s_ram_rd,
    input   s_ram_rd_addr,
    input   s_ram_we,
    input   s_ram_wr_addr,
    input   s_ram_wdata
    ,
    input   s_ram_rd_addr_par,
    input   s_ram_wr_addr_par
  );
  
  modport slave_chdata_mp(
    output  s_ram_rdata,
    input   s_ram_rd,
    input   s_ram_rd_addr,
    input   s_ram_we,
    input   s_ram_wr_addr,
    input   s_ram_wdata
  );

endinterface : DWC_cxl_ram2p_if

`endif // __GUARD__DWC_CXL_RAM2P_IF__SVH__
