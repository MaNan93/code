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
// ---   $Revision: #2 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_rbuf_ras_ms.sv#2 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Multi-Stream Architecture RAS Protection for Retry Buffer
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

module DWC_cxl_mem_cache_rbuf_ras_ms
  import DWC_cxl_pkg::*;
  import DWC_pcie_ctl_pkg::RAS_DP_PROT_CHK_ID_BASE_CXL;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
#(
  parameter TP = `TP
)(
  input                                 core_clk                  ,
  input                                 core_rst_n                ,
  input                                 cxl_rbuf_flit_valid       , // RBUF RAM Read Data Valid
  input                                 cxl_llctrl_rbuf_halt      , // Halt to the retry buffer
  input [RBUF_ADD_WD - 1 : 0]           rbuf_addr                 , // RBUF RAM Address
  input [CX_CXL_20_DW  - 1 : 0]         rbuf_wdata                , // RBUF RAM Write Data
  input [RBUF_DATA_WD - 1  : 0]         rbuf_rdata                , // RBUF RAM Read Data
  input ras_dp_err_inj_t                ras_dp_err_inj            ,
  output ras_dp_err_log_t               ras_dp_err_log            , // Error Logs from RASDP instances
  output[CXL_RBUF_RAS_UNCORR_NUM-1:0]   ras_dp_uncorr_err         , // RASDP Errors to trigger Viral
  output [RBUF_ADD_WD - 1 : 0]          rbuf_addr_protgen         , // RBUF RAM Protected Address
  output                                rbuf_addr_par             , // RBUF RAM Address Parity
  output [RBUF_DATA_WD - 1 : 0]         rbuf_wdata_protgen        , // RBUF RAM Protected Write Data
  output [CX_CXL_20_DW - 1 : 0]         rbuf_rdata_protgen          // RBUF RAM Protected Read Data
);

// RASDP Checker Instances IDs
localparam CXL_TX_RBUF_RAM_RDATA_RAS_ID  = RAS_DP_PROT_CHK_ID_BASE_CXL + CXL_TX_RBUF_RAM_RDATA_RAS_ID_INDEX;

logic [RBUF_ADD_WD -1 :0]               rbuf_addr_prot_in_s;        // RBUF RAM Address before bus protect gen
logic [RBUF_ADD_WD-1:0]                 rbuf_addr_protchk_s;        // RBUF RAM Address after bus protect chk
logic [CX_CXL_20_DW-1:0]                rbuf_wdata_protchk_s;       // RBUF RAM Write Data after bus protect chk
logic [CX_CXL_20_DW-1:0]                rbuf_rdata_protchk_s;       // RBUF RAM Read Data after bus protect chk
logic [CX_CXL_20_DW-1:0]                rbuf_wdata_protgen_s;       // RBUF RAM Write Data after bus protect gen
logic [CX_CXL_20_DW-1:0]                rbuf_rdata_protgen_s;       // RBUF RAM Read Data after bus protect gen
logic [RBUF_DATA_PROT_WD-1:0]           rbuf_wdata_chk_protgen_s;   // RBUF RAM Write Data Protection after bus protect gen
logic [RBUF_DATA_PROT_WD-1:0]           rbuf_rdata_chk_protgen_s;   // RBUF RAM Read Data Protection after bus protect gen
logic                                   rbuf_rdata_ras_chk_valid_in;

assign rbuf_wdata_protgen = {rbuf_wdata_chk_protgen_s,rbuf_wdata_protgen_s};

assign rbuf_rdata_protgen_s     = rbuf_rdata[CX_CXL_20_DW-1:0];
assign rbuf_rdata_chk_protgen_s = rbuf_rdata[CX_CXL_20_DW+RBUF_DATA_PROT_WD-1:CX_CXL_20_DW];


// -------------------------------------------------------------------------------------
// RAM Address Parity Generator
// -------------------------------------------------------------------------------------
// ensure address and parity is only generated with the actual true width at the pcie_ctrl ports, locally 8bit addressing is always used
assign rbuf_addr_prot_in_s = { {(8-CXL_RBUF_WD){1'b0}}, rbuf_addr[CXL_RBUF_WD-1:0] };
ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                              ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                              ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 1                              ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                              ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( 1                              ), // Protection type
    .PROT_RANGE              ( RBUF_ADD_WD                    ), // Protection range
    .TOTAL_WIDTH             ( RBUF_ADD_WD                    ), // Data width
    .PROT_WD                 ( 1                              ), // Protection code width
    .PARITY_MODE             ( CXL_RAS_PARITY_MODE            ), // Parity mode
    .PROT_CORRECT_EN         ( 0                              ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                              )  // Checker ID: N/A
) u_rbuf_addr_ras_gen (
    .clk                      ( core_clk                                    ),
    .rst_n                    ( core_rst_n                                  ),
    .din                      ( rbuf_addr_prot_in_s                         ),
    .din_prot                 ( '0                                          ),
    .dout                     ( rbuf_addr_protgen                           ),
    .dout_prot                ( rbuf_addr_par                               ),
    .en                       ( '0                                          ),
    .bypass                   ( '0                                          ),
    .stall                    ( '0                                          ),
    .stallout                 ( /* Unused */                                ),
    .valid_in                 ( '0                                          ),
    .halt_out                 ( /* Unused */                                ),
    .valid_out                ( /* Unused */                                ),
    .halt_in                  ( '0                                          ),
    .ras_dp_err_inband_kbd_in ( '0                                          ),
    .ras_dp_err_inband_kbd_out( /* Unused */                                ),
    .ras_dp_err_log           ( /* Unused */                                ) 
    ,
    .ras_dp_err_inj           ( '0                                          )
);

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                              ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                              ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 1                              ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                              ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( CX_CXL_RAM_PROT_TYPE           ), // Protection type
    .PROT_RANGE              ( CX_CXL_RAM_PROT_RANGE          ), // Protection range
    .TOTAL_WIDTH             ( CX_CXL_20_DW                   ), // Data + Addr width
    .PROT_WD                 ( RBUF_DATA_PROT_WD              ), // Protection code width
    .PARITY_MODE             ( CX_CXL_RAM_PARITY_MODE         ), // Parity mode
    .PROT_CORRECT_EN         ( 0                              ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                              )  // Checker ID: N/A
) u_rbuf_wdata_ras_dp_pipe_gen (
    .clk                      ( core_clk                                    ),
    .rst_n                    ( core_rst_n                                  ),
    .din                      ( rbuf_wdata                                  ),
    .din_prot                 ( '0                                          ),
    .dout                     ( rbuf_wdata_protgen_s                        ),
    .dout_prot                ( rbuf_wdata_chk_protgen_s                    ),
    .en                       ( '0                                          ),
    .bypass                   ( '0                                          ),
    .stall                    ( '0                                          ),
    .stallout                 ( /* Unused */                                ),
    .valid_in                 ( '0                                          ),
    .halt_out                 ( /* Unused */                                ),
    .valid_out                ( /* Unused */                                ),
    .halt_in                  ( '0                                          ),
    .ras_dp_err_inband_kbd_in ( '0                                          ),
    .ras_dp_err_inband_kbd_out( /* Unused */                                ),
    .ras_dp_err_log           ( /* Unused */                                ) 
    ,
    .ras_dp_err_inj           ( '0                                          )
);

// -------------------------------------------------------------------------------------
// Check RAM Protection
// -------------------------------------------------------------------------------------
assign rbuf_rdata_ras_chk_valid_in = cxl_rbuf_flit_valid & !cxl_llctrl_rbuf_halt;

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                              ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                              ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 0                              ), // Bus Protect Genenator is not enabled
    .BUS_PROTECT_CHK_EN      ( 1                              ), // Bus Protect Checker is enabled
    .PROT_TYPE               ( CX_CXL_RAM_PROT_TYPE           ), // Protection type
    .PROT_RANGE              ( CX_CXL_RAM_PROT_RANGE          ), // Protection range
    .TOTAL_WIDTH             ( CX_CXL_20_DW                   ), // Data width
    .PROT_WD                 ( RBUF_DATA_PROT_WD              ), // Protection code width
    .PARITY_MODE             ( CX_CXL_RAM_PARITY_MODE         ), // Parity mode
    .PROT_CORRECT_EN         ( 1                              ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( CXL_TX_RBUF_RAM_RDATA_RAS_ID   )  // Checker instance ID
) u_rbuf_rdata_ras_chk (
    .clk                      ( core_clk                                    ),
    .rst_n                    ( core_rst_n                                  ),
    .din                      ( rbuf_rdata_protgen_s                        ),
    .din_prot                 ( rbuf_rdata_chk_protgen_s                    ),
    .dout                     ( rbuf_rdata_protgen                          ),
    .dout_prot                (                       ),
    .en                       ( 1'b1                                        ),
    .bypass                   ( '0                                          ),
    .stall                    ( '0                                          ),
    .stallout                 ( /* Unused */                                ),
    .valid_in                 ( rbuf_rdata_ras_chk_valid_in                 ),
    .halt_out                 ( /* Unused */                                ),
    .valid_out                ( /* Unused */                                ),
    .halt_in                  ( '0                                          ),
    .ras_dp_err_inband_kbd_in ( '0                                          ),
    .ras_dp_err_inband_kbd_out( ras_dp_uncorr_err                           ),
    .ras_dp_err_log           ( ras_dp_err_log                              ) 
    ,
    .ras_dp_err_inj           ( ras_dp_err_inj                              )
);

endmodule
