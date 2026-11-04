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

// ----------------------------------------------------------------------------------------------------
// --- RCS information:
// ---   $DateTime: 2023/06/26 08:32:07 $
// ---   $Revision: #1 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_tx_dl_rasdp_wr_ms.sv#1 $
// ----------------------------------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------------------------------
// CXL Link layer RASDP Wrapper Module for Multistream Architecture
// ----------------------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

module DWC_cxl_mem_cache_tx_dl_rasdp_wr_ms
  import DWC_cxl_pkg::*;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::RAS_DP_PROT_CHK_ID_BASE_CXL;
#(
    parameter TP = `TP
 )
                                            (
//input
         input                                           core_clk                    // Core clock
        ,input                                           core_rst_n                  // Core Reset
        ,input                                           cxl_pcie_flit_mode          // CXL Flit Mode (0-68B Flit Mode / 1-256B Flit Mode)



// Packer RAS DP Generation
        ,input  [CXL_DATA_WD-1 : 0]                      cxl_packer_flit_data_i       // Packer Flit Data        
        ,output [CXL_DATA_PROT_WD-1 : 0]                 cxl_flit_if_data_chk         // Flit Interface - Flit Data for ARB/MUX ECC Protection

// LLCTRL RAS DP Generation
        ,input  [127:0]                                  cxl_llctrl_flit              // LLCTRL FLIT Data
        ,output [CXL_DATA_PROT_WD-1:0]                   cxl_llctrl_flit_chk          // LLCTRL Flit Protection

// IDE Secure IF RAS Checking

    
);

//Mux between cxs and packer flit chk bits
  logic [CXL_DATA_PROT_WD-1 : 0]    cxl_packer_flit_chk;      // CXL IDE TX Plain IF - Flit Data Protection
  logic [CXL_DATA_PROT_WD-1 : 0]    mux_cxl_packer_flit_chk;  // CXL IDE TX Plain IF - Flit Data Protection


assign mux_cxl_packer_flit_chk    = cxl_packer_flit_chk    ;

//Mux between IDE chk bits and either (cxs or unpacker) chk bits
assign cxl_flit_if_data_chk = mux_cxl_packer_flit_chk    ;

// -------------------------------------------------------------------------------------
// Packer Flits-RAS-GEN
// -------------------------------------------------------------------------------------
ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                          ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                          ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 1                          ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                          ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( CX_CXL_PROT_TYPE           ), // Protection type
    .PROT_RANGE              ( CX_CXL_PROT_RANGE          ), // Protection range
    .TOTAL_WIDTH             ( CXL_DATA_WD                ), // Data width
    .PROT_WD                 ( CXL_DATA_PROT_WD           ), // Protection code width
    .PARITY_MODE             ( CX_CXL_PARITY_MODE         ), // Parity mode
    .PROT_CORRECT_EN         ( 0                          ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                          )  // Checker ID: N/A
) u_ras_dp_pipe_pack (
    .clk                      ( core_clk                             ),
    .rst_n                    ( core_rst_n                           ),
    .din                      ( cxl_packer_flit_data_i               ),
    .din_prot                 ( {CXL_DATA_PROT_WD{1'b0}}             ),
    .dout                     ( /*Unused*/                           ),
    .dout_prot                ( cxl_packer_flit_chk                  ),
    .en                       ( '0                                   ),
    .bypass                   ( '0                                   ),
    .stall                    ( '0                                   ),
    .stallout                 ( /* Unused */                         ),
    .valid_in                 ( '0                                   ),
    .halt_out                 ( /* Unused */                         ),
    .valid_out                ( /* Unused */                         ),
    .halt_in                  ( '0                                   ),
    .ras_dp_err_inband_kbd_in ( '0                                   ),
    .ras_dp_err_inband_kbd_out( /* Unused */                         ),
    .ras_dp_err_log           ( /* Unused */                         ) 
    ,
    .ras_dp_err_inj           ( '0                                   )
);

// -------------------------------------------------------------------------------------
// Generate ECC Protection - (LLCTRL Flits)
// -------------------------------------------------------------------------------------
ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                       ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( CX_CXL_PROT_TYPE        ), // Protection type
    .PROT_RANGE              ( CX_CXL_PROT_RANGE       ), // Protection range
    .TOTAL_WIDTH             ( CXL_DATA_WD             ), // Data width
    .PROT_WD                 ( CXL_DATA_PROT_WD        ), // Protection code width
    .PARITY_MODE             ( CX_CXL_PARITY_MODE      ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_ras_dp_pipe_llctrl (
    .clk                      ( core_clk                                       ),
    .rst_n                    ( core_rst_n                                     ),
    .din                      ( {{CXL_DATA_WD-128{1'b0}}, cxl_llctrl_flit}     ),
    .din_prot                 ( '0                                             ),
    .dout                     ( /* Unused */                                   ),
    .dout_prot                ( cxl_llctrl_flit_chk                            ),
    .en                       ( '0                                             ),
    .bypass                   ( '0                                             ),
    .stall                    ( '0                                             ),
    .stallout                 ( /* Unused */                                   ),
    .valid_in                 ( '0                                             ),
    .halt_out                 ( /* Unused */                                   ),
    .valid_out                ( /* Unused */                                   ),
    .halt_in                  ( '0                                             ),
    .ras_dp_err_inband_kbd_in ( '0                                             ),
    .ras_dp_err_inband_kbd_out( /* Unused */                                   ),
    .ras_dp_err_log           ( /* Unused */                                   )
    ,
    .ras_dp_err_inj           ( '0                                             )
);



endmodule
