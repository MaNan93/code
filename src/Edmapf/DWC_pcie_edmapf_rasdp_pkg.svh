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
// ---    $Revision: #6 $ 
// ---    $Author: dnolan $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh#6 $ 
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_PCIE_EDMAPF_RASDP_PKG__SVH__
`define __GUARD__DWC_PCIE_EDMAPF_RASDP_PKG__SVH__

// SNPS_SysML_CODE_START
`define RAS_HDMA_WR_LL_RAM_ADDR_PTR      0
`define RAS_HDMA_WR_LL_RAM_ADDR_PTR_WD   `CC_IF_WRCTRL_LL_RAM_PW
`define RAS_HDMA_WR_LL_RAM_DATA_PTR      0
`define RAS_HDMA_WR_LL_RAM_DATA_PTR_WD   `CC_IF_WRCTRL_LL_RAM_WD

`define RAS_HDMA_WR_LLQ_RAM_ADDR_PTR     0
`define RAS_HDMA_WR_LLQ_RAM_ADDR_PTR_WD  `CC_IF_WRCTX_LLQ_OVERLAY_RAM_PW
`define RAS_HDMA_WR_LLQ_RAM_DATA_PTR     0
`define RAS_HDMA_WR_LLQ_RAM_DATA_PTR_WD  `CC_IF_WRCTX_LLQ_OVERLAY_RAM_WD

`define RAS_HDMA_WR_C2W_RAM_ADDR_PTR     0
`define RAS_HDMA_WR_C2W_RAM_ADDR_PTR_WD  `CC_IF_WR_CTXC2W_RAM_PW
`define RAS_HDMA_WR_C2W_RAM_DATA_PTR     0
`define RAS_HDMA_WR_C2W_RAM_DATA_PTR_WD  `CC_IF_WR_CTXC2W_RAM_WD

`define RAS_HDMA_WR_STSH_RAM_ADDR_PTR    0
`define RAS_HDMA_WR_STSH_RAM_ADDR_PTR_WD `CC_IF_WR_CTXSTSH_RAM_PW
`define RAS_HDMA_WR_STSH_RAM_DATA_PTR    0
`define RAS_HDMA_WR_STSH_RAM_DATA_PTR_WD `CC_IF_WR_CTXSTSH_RAM_WD

`define RAS_HDMA_WR_MSI_RAM_ADDR_PTR     0
`define RAS_HDMA_WR_MSI_RAM_ADDR_PTR_WD  `CC_IF_WR_MSI_RAM_PW
`define RAS_HDMA_WR_MSI_RAM_DATA_PTR     0
`define RAS_HDMA_WR_MSI_RAM_DATA_PTR_WD  `CC_IF_WR_MSI_RAM_WD

`define RAS_HDMA_RD_LL_RAM_ADDR_PTR      0
`define RAS_HDMA_RD_LL_RAM_ADDR_PTR_WD   `CC_IF_RDCTRL_LL_RAM_PW
`define RAS_HDMA_RD_LL_RAM_DATA_PTR      0
`define RAS_HDMA_RD_LL_RAM_DATA_PTR_WD   `CC_IF_RDCTRL_LL_RAM_WD

`define RAS_HDMA_RD_LLQ_RAM_ADDR_PTR     0
`define RAS_HDMA_RD_LLQ_RAM_ADDR_PTR_WD  `CC_IF_RDCTX_LLQ_OVERLAY_RAM_PW
`define RAS_HDMA_RD_LLQ_RAM_DATA_PTR     0
`define RAS_HDMA_RD_LLQ_RAM_DATA_PTR_WD  `CC_IF_RDCTX_LLQ_OVERLAY_RAM_WD

`define RAS_HDMA_RD_C2W_RAM_ADDR_PTR     0
`define RAS_HDMA_RD_C2W_RAM_ADDR_PTR_WD  `CC_IF_RD_CTXC2W_RAM_PW
`define RAS_HDMA_RD_C2W_RAM_DATA_PTR     0
`define RAS_HDMA_RD_C2W_RAM_DATA_PTR_WD  `CC_IF_RD_CTXC2W_RAM_WD

`define RAS_HDMA_RD_STSH_RAM_ADDR_PTR    0
`define RAS_HDMA_RD_STSH_RAM_ADDR_PTR_WD `CC_IF_RD_CTXSTSH_RAM_PW
`define RAS_HDMA_RD_STSH_RAM_DATA_PTR    0
`define RAS_HDMA_RD_STSH_RAM_DATA_PTR_WD `CC_IF_RD_CTXSTSH_RAM_WD

`define RAS_HDMA_RD_MSI_RAM_ADDR_PTR     0
`define RAS_HDMA_RD_MSI_RAM_ADDR_PTR_WD  `CC_IF_RD_MSI_RAM_PW
`define RAS_HDMA_RD_MSI_RAM_DATA_PTR     0
`define RAS_HDMA_RD_MSI_RAM_DATA_PTR_WD  `CC_IF_RD_MSI_RAM_WD

`define RAS_HDMA_RDBUF_RAM_ADDR_PTR      0
`define RAS_HDMA_RDBUF_RAM_ADDR_PTR_WD   `CC_DMA_SEG_BUF_NW_ADDR_WIDTH
`define RAS_HDMA_RDBUF_RAM_DATA_PTR      0
`define RAS_HDMA_RDBUF_RAM_DATA_PTR_WD   `CX_DMA_RBUF_SLICE_WD
// SNPS_SysML_CODE_END

`include "DWC_pcie_ctl_pkg.svh"

package DWC_pcie_edmapf_rasdp_pkg;

  import DWC_pcie_ctl_pkg::RAS_DP_PROT_CHK_ID_BASE_HDMA;

// SNPS_SysML_CODE_START
  localparam K_RAS_PROT_RANGE = `CX_RAS_PROT_RANGE;
  localparam K_RAS_RAM_PROT_RANGE = `CX_RAS_RAM_PROT_RANGE;
  localparam K_RAS_PARITY_MODE = `CX_RAS_PARITY_MODE;
  localparam K_RAS_MAXADDRWD  = 32;
// SNPS_SysML_CODE_END

  // ##########################################################################
  //                          RAS_DP_PROT_CHK_ID_BASE                               
  // ##########################################################################
    localparam RAS_CHK_ID_CPL2MWR_RD       = RAS_DP_PROT_CHK_ID_BASE_HDMA + 1;
    localparam RAS_CHK_ID_CPL2MWR_WR       = RAS_DP_PROT_CHK_ID_BASE_HDMA + 2;
    localparam RAS_CHK_ID_CPL2MWR_BA_RD    = RAS_DP_PROT_CHK_ID_BASE_HDMA + 3;
    localparam RAS_CHK_ID_CPL2MWR_BA_WR    = RAS_DP_PROT_CHK_ID_BASE_HDMA + 4;
    localparam RAS_CHK_ID_CPL2MWR_MWR_RD   = RAS_DP_PROT_CHK_ID_BASE_HDMA + 5;
    localparam RAS_CHK_ID_CPL2MWR_MWR_WR   = RAS_DP_PROT_CHK_ID_BASE_HDMA + 6;
    localparam RAS_CHK_ID_RDBUF_TRGT       = RAS_DP_PROT_CHK_ID_BASE_HDMA + 7;
    localparam RAS_CHK_ID_CPL_RDLL         = RAS_DP_PROT_CHK_ID_BASE_HDMA + 8;
    localparam RAS_CHK_ID_CPL_WRLL         = RAS_DP_PROT_CHK_ID_BASE_HDMA + 9;
    localparam RAS_CHK_ID_CPL_RDLL_DATA    = RAS_DP_PROT_CHK_ID_BASE_HDMA + 10;
    localparam RAS_CHK_ID_CPL_WRLL_DATA    = RAS_DP_PROT_CHK_ID_BASE_HDMA + 11;

    localparam RAS_CHK_ID_RAM_WR_LL        = RAS_DP_PROT_CHK_ID_BASE_HDMA + 12;   
    localparam RAS_CHK_ID_RAM_WR_LLQ       = RAS_DP_PROT_CHK_ID_BASE_HDMA + 13;    
    localparam RAS_CHK_ID_RAM_WR_C2WLUT    = RAS_DP_PROT_CHK_ID_BASE_HDMA + 14;    
    localparam RAS_CHK_ID_RAM_WR_STSHLUT   = RAS_DP_PROT_CHK_ID_BASE_HDMA + 15;    
    localparam RAS_CHK_ID_RAM_WR_MSI       = RAS_DP_PROT_CHK_ID_BASE_HDMA + 16;    
    localparam RAS_CHK_ID_RAM_RD_LL        = RAS_DP_PROT_CHK_ID_BASE_HDMA + 17;    
    localparam RAS_CHK_ID_RAM_RD_LLQ       = RAS_DP_PROT_CHK_ID_BASE_HDMA + 18;    
    localparam RAS_CHK_ID_RAM_RD_C2WLUT    = RAS_DP_PROT_CHK_ID_BASE_HDMA + 19;    
    localparam RAS_CHK_ID_RAM_RD_STSHLUT   = RAS_DP_PROT_CHK_ID_BASE_HDMA + 20;    
    localparam RAS_CHK_ID_RAM_RD_MSI       = RAS_DP_PROT_CHK_ID_BASE_HDMA + 21;     
    localparam RAS_CHK_ID_RAM_RDBUF        = RAS_DP_PROT_CHK_ID_BASE_HDMA + 22;
    localparam RAS_CHK_ID_RAM_RDBUF_1      = RAS_DP_PROT_CHK_ID_BASE_HDMA + 23;

    localparam RAS_CHK_ID_TRGT_P           = RAS_DP_PROT_CHK_ID_BASE_HDMA + 24;
    localparam RAS_CHK_ID_TRGT_NP          = RAS_DP_PROT_CHK_ID_BASE_HDMA + 25;
    localparam RAS_CHK_ID_TRGT_CPL         = RAS_DP_PROT_CHK_ID_BASE_HDMA + 26;
    localparam RAS_CHK_ID_CLIENT_P         = RAS_DP_PROT_CHK_ID_BASE_HDMA + 27;
    localparam RAS_CHK_ID_CLIENT_NP        = RAS_DP_PROT_CHK_ID_BASE_HDMA + 28;
    localparam RAS_CHK_ID_CLIENT_CPL       = RAS_DP_PROT_CHK_ID_BASE_HDMA + 29;
    localparam RAS_CHK_ID_CPL2MWR_FLUSH_RD = RAS_DP_PROT_CHK_ID_BASE_HDMA + 30;
    localparam RAS_CHK_ID_CPL2MWR_FLUSH_WR = RAS_DP_PROT_CHK_ID_BASE_HDMA + 31;
    localparam RAS_CHK_ID_APP_TRGT_P       = RAS_DP_PROT_CHK_ID_BASE_HDMA + 32;
    localparam RAS_CHK_ID_APP_TRGT_NP      = RAS_DP_PROT_CHK_ID_BASE_HDMA + 33;
    localparam RAS_CHK_ID_APP_TRGT_CPL     = RAS_DP_PROT_CHK_ID_BASE_HDMA + 34;
    localparam RAS_CHK_ID_CORE_CLIENT_P    = RAS_DP_PROT_CHK_ID_BASE_HDMA + 35;
    localparam RAS_CHK_ID_CORE_CLIENT_NP   = RAS_DP_PROT_CHK_ID_BASE_HDMA + 36;
    localparam RAS_CHK_ID_CORE_CLIENT_CPL  = RAS_DP_PROT_CHK_ID_BASE_HDMA + 37;
    localparam RAS_CHK_ID_TAGGER_TRGT_NP   = RAS_DP_PROT_CHK_ID_BASE_HDMA + 38;
    localparam RAS_CHK_ID_APP_CLIENT_CPL   = RAS_DP_PROT_CHK_ID_BASE_HDMA + 39;
  
  // ##########################################################################
  //                                Enumerations                               
  // ##########################################################################
  typedef enum logic [5:0] {
     E_RAS_WRAPPER_CLIENT0     = 0
    ,E_RAS_WRAPPER_CLIENT1     = 1
    ,E_RAS_WRAPPER_TRGT        = 2
    ,E_RAS_WRAPPER_BYPASS      = 3
    ,E_RAS_ARBITER_CLIENT0_IN  = 4
    ,E_RAS_ARBITER_CLIENT0_OUT = 5
    ,E_RAS_ARBITER_CLIENT1     = 6
    ,E_RAS_ARBITER_TRGT        = 7
    ,E_RAS_ARBITER_BYPASS      = 8
    ,E_RAS_REMAPPER_TRGT       = 9
    ,E_RAS_RDBUF_TRGT          = 10
    ,E_RAS_RDBUF_BYPASS        = 11
    ,E_RAS_RDBUF_DATA          = 12
    ,E_RAS_CPL_RDLL            = 13
    ,E_RAS_CPL_WRLL            = 14
    ,E_RAS_CPL_RDLL_DATA       = 15
    ,E_RAS_CPL_WRLL_DATA       = 16
    ,E_RAS_CPL2MWR_RD          = 17
    ,E_RAS_CPL2MWR_WR          = 18
    ,E_RAS_CPL2MWR_BA_RD       = 19
    ,E_RAS_CPL2MWR_BA_WR       = 20
    ,E_RAS_CPL2MWR_MWR_RD      = 21
    ,E_RAS_CPL2MWR_MWR_WR      = 22
    ,E_RAS_RAM_WR_LL           = 23
    ,E_RAS_RAM_WR_LLQ          = 24
    ,E_RAS_RAM_WR_C2WLUT       = 25
    ,E_RAS_RAM_WR_STSHLUT      = 26
    ,E_RAS_RAM_WR_MSI          = 27
    ,E_RAS_RAM_RD_LL           = 28
    ,E_RAS_RAM_RD_LLQ          = 29
    ,E_RAS_RAM_RD_C2WLUT       = 30
    ,E_RAS_RAM_RD_STSHLUT      = 31
    ,E_RAS_RAM_RD_MSI          = 32
    ,E_RAS_RAM_RDBUF           = 33
    ,E_RAS_TOTAL               = 34
  } ras_e;

  // ##########################################################################
  //                          Data Structures/Unions                           
  // ##########################################################################
  typedef struct packed {
    logic  ram_rdbuf          ;
    logic  ram_rd_msi         ;
    logic  ram_rd_stshlut     ;
    logic  ram_rd_c2wlut      ;
    logic  ram_rd_llq         ;
    logic  ram_rd_ll          ;
    logic  ram_wr_msi         ;
    logic  ram_wr_stshlut     ;
    logic  ram_wr_c2wlut      ;
    logic  ram_wr_llq         ;
    logic  ram_wr_ll          ;
    logic  cpl2mwr_mwr_wr     ;
    logic  cpl2mwr_mwr_rd     ;
    logic  cpl2mwr_ba_wr      ;
    logic  cpl2mwr_ba_rd      ;
    logic  cpl2mwr_wr         ;
    logic  cpl2mwr_rd         ;
    logic  cpl_wrll_data      ;
    logic  cpl_rdll_data      ;
    logic  cpl_wrll           ;
    logic  cpl_rdll           ;
    logic  rdbuf_data         ;
    logic  rdbuf_bypass       ;
    logic  rdbuf_trgt         ;
    logic  remapper_trgt      ;
    logic  arbiter_bypass     ;
    logic  arbiter_trgt       ;
    logic  arbiter_client1    ;
    logic  arbiter_client0_out;
    logic  arbiter_client0_in ;
    logic  wrapper_bypass     ;
    logic  wrapper_trgt       ;
    logic  wrapper_client1    ;
    logic  wrapper_client0    ;
  } ras_s;

  typedef union packed {
    ras_s                   structure;
    logic [E_RAS_TOTAL-1:0] bitmap   ;
  } ras_u;

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

endpackage

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

`endif // __GUARD__DWC_PCIE_EDMAPF_RASDP_PKG__SVH__

