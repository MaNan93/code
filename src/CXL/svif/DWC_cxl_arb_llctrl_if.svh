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
// ---   $Revision: #4 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/svif/DWC_cxl_arb_llctrl_if.svh#4 $
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_CXL_ARB_LLCTRL_IF__SVH__
`define __GUARD__DWC_CXL_ARB_LLCTRL_IF__SVH__
interface DWC_cxl_arb_llctrl_if
  import DWC_cxl_pkg::*;
  #();

  // ARB/MUX Interface 
  logic                       s_arb_mux_flit_halt;       // Back Pressure From Arb/Mux
  logic                       s_arb_mux_flit_vld;        // Flit Valid
  logic                       s_arb_mux_flit_sof;        // Start of Flit
  logic [1:0]                 s_arb_mux_flit_eof;        // End of Flit
  logic                       s_arb_mux_flit_enf;        // End of Nullified Flit
  logic                       s_arb_mux_flit_eof_err;    // viral error at eof
  logic                       s_arb_mux_flit_pri;        // priority indication
  logic [ARBMUX_FLIT_IF_WD-1:0]  s_arb_mux_flit_data;       // Flit to ARB/MUX
  logic [ARBMUX_XPLH_IF_WD-1:0]  s_arb_mux_xplh_data;       // Flit Serializer to ARB/MUX data

  logic                       s_cxl_arb_mem_cache_valid;     // Flit valid from ARB to CXL cache/mem
  logic [ARBMUX_FLIT_WD-1:0]  s_cxl_arb_mem_cache_data;      // Flit data from ARB to CXL cache/mem
  logic [CXL_DATA_PROT_WD-1:0] s_cxl_arb_mem_cache_data_chk; // Flit protection from ARB to CXL cache/mem
  

  modport master_tx_mp(
    input   s_arb_mux_flit_halt,
    output  s_arb_mux_flit_vld,
    output  s_arb_mux_flit_sof,
    output  s_arb_mux_flit_eof,
    output  s_arb_mux_flit_enf,
    output  s_arb_mux_flit_eof_err,
    output  s_arb_mux_flit_pri,
    output  s_arb_mux_flit_data
  );

  modport slave_tx_mp(
    output  s_arb_mux_flit_halt,
    input   s_arb_mux_flit_vld,
    input   s_arb_mux_flit_sof,
    input   s_arb_mux_flit_eof,
    input   s_arb_mux_flit_enf,
    input   s_arb_mux_flit_eof_err,
    input   s_arb_mux_flit_pri,
    input   s_arb_mux_flit_data    
  );

  modport master_xplh_mp(
    input   s_arb_mux_flit_halt,
    output  s_arb_mux_flit_vld,
    output  s_arb_mux_flit_sof,
    output  s_arb_mux_flit_eof,
    output  s_arb_mux_flit_enf,
    output  s_arb_mux_flit_eof_err,
    output  s_arb_mux_flit_pri,
    output  s_arb_mux_xplh_data
  );

  modport slave_xplh_mp(
    output  s_arb_mux_flit_halt,
    input   s_arb_mux_flit_vld,
    input   s_arb_mux_flit_sof,
    input   s_arb_mux_flit_eof,
    input   s_arb_mux_flit_enf,
    input   s_arb_mux_flit_eof_err,
    input   s_arb_mux_flit_pri,
    input   s_arb_mux_xplh_data
    
  );

  modport slave_rx_mp(
    input   s_cxl_arb_mem_cache_valid,
    input   s_cxl_arb_mem_cache_data
    ,
    input   s_cxl_arb_mem_cache_data_chk
  );

  modport master_rx_mp(
    output  s_cxl_arb_mem_cache_valid,
    output  s_cxl_arb_mem_cache_data
    ,
    output  s_cxl_arb_mem_cache_data_chk
    
  );





  

endinterface : DWC_cxl_arb_llctrl_if

`endif // __GUARD__DWC_CXL_ARB_LLCTRL_IF__SVH__
