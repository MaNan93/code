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
// ---   $Revision: #1 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_rx_tl_ras_ms.sv#1 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

module DWC_cxl_mem_cache_rx_tl_ras_ms
  import DWC_cxl_pkg::*;
#(
    parameter TP = `TP
) (
     DWC_cxl_clk_rst_if.slave_mp                                   b_clk
    ,input  [(HREQ_DRSP_NUM-1):0][(HREQ_DRSP_RX_RAM_ADDRW-1) : 0]  hreq_drsp_ram_waddr_i
    ,input  [(HREQ_DRSP_NUM-1):0][(HREQ_DRSP_RX_RAM_ADDRW-1) : 0]  hreq_drsp_ram_raddr_i
    ,input  [(HRSP_DREQ_NUM-1):0][(HRSP_DREQ_RX_RAM_ADDRW-1) : 0]  hrsp_dreq_ram_waddr_i
    ,input  [(HRSP_DREQ_NUM-1):0][(HRSP_DREQ_RX_RAM_ADDRW-1) : 0]  hrsp_dreq_ram_raddr_i
    ,input  [HD_DDATA_NUM-1:0] [(HD_DATA_RX_RAM_ADDRW-1)   : 0]    hd_data_ram_waddr_i
    ,input  [HD_DDATA_NUM-1:0] [(HD_DATA_RX_RAM_ADDRW-1)   : 0]    hd_data_ram_raddr_i
    ,output [HREQ_DRSP_NUM-1:0][(HREQ_DRSP_RX_RAM_ADDRW-1):0]      hreq_drsp_ram_waddr_o 
    ,output [HREQ_DRSP_NUM-1:0]                                    hreq_drsp_ram_waddr_par_o
    ,output [HREQ_DRSP_NUM-1:0][(HREQ_DRSP_RX_RAM_ADDRW-1):0]      hreq_drsp_ram_raddr_o 
    ,output [HREQ_DRSP_NUM-1:0]                                    hreq_drsp_ram_raddr_par_o
    ,output [HRSP_DREQ_NUM-1:0][(HRSP_DREQ_RX_RAM_ADDRW-1):0]      hrsp_dreq_ram_waddr_o 
    ,output [HRSP_DREQ_NUM-1:0]                                    hrsp_dreq_ram_waddr_par_o
    ,output [HRSP_DREQ_NUM-1:0]                                    hrsp_dreq_ram_raddr_par_o
    ,output [HRSP_DREQ_NUM-1:0][(HRSP_DREQ_RX_RAM_ADDRW-1):0]      hrsp_dreq_ram_raddr_o 
    ,output [HD_DDATA_NUM-1:0][(HD_DATA_RX_RAM_ADDRW-1)   : 0]     hd_data_ram_waddr_o 
    ,output [HD_DDATA_NUM-1:0]                                     hd_data_ram_waddr_par_o
    ,output [HD_DDATA_NUM-1:0][(HD_DATA_RX_RAM_ADDRW-1)   : 0]     hd_data_ram_raddr_o 
    ,output [HD_DDATA_NUM-1:0]                                     hd_data_ram_raddr_par_o

    ,input  [(MS_SM_NDR_NUM-1):0][(MS_NDR_RX_RAM_ADDRW-1) : 0]     ms_ndr_ram_waddr_i
    ,input  [(MS_SM_NDR_NUM-1):0][(MS_NDR_RX_RAM_ADDRW-1) : 0]     ms_ndr_ram_raddr_i
    ,input  [MS_SM_DDATA_NUM-1:0][(MS_DATA_RX_RAM_ADDRW-1): 0]     ms_data_ram_waddr_i
    ,input  [MS_SM_DDATA_NUM-1:0][(MS_DATA_RX_RAM_ADDRW-1): 0]     ms_data_ram_raddr_i
    ,output [MS_SM_NDR_NUM-1:0][(MS_NDR_RX_RAM_ADDRW-1):0]         ms_ndr_ram_waddr_o 
    ,output [MS_SM_NDR_NUM-1:0]                                    ms_ndr_ram_waddr_par_o
    ,output [MS_SM_NDR_NUM-1:0][(MS_NDR_RX_RAM_ADDRW-1):0]         ms_ndr_ram_raddr_o 
    ,output [MS_SM_NDR_NUM-1:0]                                    ms_ndr_ram_raddr_par_o
    ,output [MS_SM_DDATA_NUM-1:0][(MS_DATA_RX_RAM_ADDRW-1): 0]     ms_data_ram_waddr_o 
    ,output [MS_SM_DDATA_NUM-1:0]                                  ms_data_ram_waddr_par_o
    ,output [MS_SM_DDATA_NUM-1:0][(MS_DATA_RX_RAM_ADDRW-1): 0]     ms_data_ram_raddr_o 
    ,output [MS_SM_DDATA_NUM-1:0]                                  ms_data_ram_raddr_par_o
    ,input [(MS_BI_NUM-1):0][(MS_BI_RX_RAM_ADDRW-1)  : 0]          ms_bi_ram_waddr_i
    ,input [(MS_BI_NUM-1):0][(MS_BI_RX_RAM_ADDRW-1)  : 0]          ms_bi_ram_raddr_i
    ,output [MS_BI_NUM-1:0][(MS_BI_RX_RAM_ADDRW-1):0]              mrsp_ssnp_bi_ram_waddr_o
    ,output [MS_BI_NUM-1:0]                                        mrsp_ssnp_bi_ram_waddr_par_o
    ,output [MS_BI_NUM-1:0][(MS_BI_RX_RAM_ADDRW-1):0]              mrsp_ssnp_bi_ram_raddr_o 
    ,output [MS_BI_NUM-1:0]                                        mrsp_ssnp_bi_ram_raddr_par_o

);

// -------------------------------------------------------------------------------------
// RAM Cache Address Parity Generator
// -------------------------------------------------------------------------------------
ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                       ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( 1                       ), // Protection type
    .PROT_RANGE              ( HREQ_DRSP_RX_RAM_ADDRW  ), // Protection range
    .TOTAL_WIDTH             ( HREQ_DRSP_RX_RAM_ADDRW  ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( 1                       ), // Protection code width
    .PARITY_MODE             ( CX_CXL_PARITY_MODE      ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_hreq_drsp_ram_waddr_ras_dp_pipe [HREQ_DRSP_NUM-1:0](
    .clk                       ( b_clk.s_core_clk                                  ),
    .rst_n                     ( b_clk.s_core_rst_n                                ),
    .din                       ( hreq_drsp_ram_waddr_i                             ),
    .din_prot                  ( '0                                                ),
    .dout                      ( hreq_drsp_ram_waddr_o                             ),
    .dout_prot                 ( hreq_drsp_ram_waddr_par_o                         ),
    .en                        ( 1'b0                                              ),
    .bypass                    ( 1'b0                                              ),
    .stall                     ( 1'b0                                              ),
    .stallout                  ( /* Unused */                                      ),
    .valid_in                  ( 1'b0                                              ),
    .halt_out                  ( /* Unused */                                      ),
    .valid_out                 ( /* Unused */                                      ),
    .halt_in                   ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_out ( /* Unused */                                      ),
    .ras_dp_err_log            ( /* Unused */                                      )
    ,
    .ras_dp_err_inj            ( {HREQ_DRSP_NUM{15'b0}}                            )
);

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                       ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( 1                       ), // Protection type
    .PROT_RANGE              ( HRSP_DREQ_RX_RAM_ADDRW  ), // Protection range
    .TOTAL_WIDTH             ( HRSP_DREQ_RX_RAM_ADDRW  ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( 1                       ), // Protection code width
    .PARITY_MODE             ( CX_CXL_PARITY_MODE      ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_hrsp_dreq_ram_waddr_ras_dp_pipe [HRSP_DREQ_NUM-1:0](
    .clk                       ( b_clk.s_core_clk                                  ),
    .rst_n                     ( b_clk.s_core_rst_n                                ),
    .din                       ( hrsp_dreq_ram_waddr_i                             ),
    .din_prot                  ( '0                                                ),
    .dout                      ( hrsp_dreq_ram_waddr_o                             ),
    .dout_prot                 ( hrsp_dreq_ram_waddr_par_o                         ),
    .en                        ( 1'b0                                              ),
    .bypass                    ( 1'b0                                              ),
    .stall                     ( 1'b0                                              ),
    .stallout                  ( /* Unused */                                      ),
    .valid_in                  ( 1'b0                                              ),
    .halt_out                  ( /* Unused */                                      ),
    .valid_out                 ( /* Unused */                                      ),
    .halt_in                   ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_out ( /* Unused */                                      ),
    .ras_dp_err_log            ( /* Unused */                                      )
    ,
    .ras_dp_err_inj            ( {HRSP_DREQ_NUM{15'b0}}                            )
);

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                       ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( 1                       ), // Protection type
    .PROT_RANGE              ( HD_DATA_RX_RAM_ADDRW    ), // Protection range
    .TOTAL_WIDTH             ( HD_DATA_RX_RAM_ADDRW    ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( 1                       ), // Protection code width
    .PARITY_MODE             ( CX_CXL_PARITY_MODE      ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_hd_data_ram_waddr_ras_dp_pipe [HD_DDATA_NUM-1:0] (
    .clk                       ( b_clk.s_core_clk                                  ),
    .rst_n                     ( b_clk.s_core_rst_n                                ),
    .din                       ( hd_data_ram_waddr_i                               ),
    .din_prot                  ( '0                                                ),
    .dout                      ( hd_data_ram_waddr_o                               ),
    .dout_prot                 ( hd_data_ram_waddr_par_o                           ),
    .en                        ( 1'b0                                              ),
    .bypass                    ( 1'b0                                              ),
    .stall                     ( 1'b0                                              ),
    .stallout                  ( /* Unused */                                      ),
    .valid_in                  ( 1'b0                                              ),
    .halt_out                  ( /* Unused */                                      ),
    .valid_out                 ( /* Unused */                                      ),
    .halt_in                   ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_out ( /* Unused */                                      ),
    .ras_dp_err_log            ( /* Unused */                                      )
    ,
    .ras_dp_err_inj            ( {HD_DDATA_NUM{15'b0}}                             )
);

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                       ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( 1                       ), // Protection type
    .PROT_RANGE              ( HREQ_DRSP_RX_RAM_ADDRW  ), // Protection range
    .TOTAL_WIDTH             ( HREQ_DRSP_RX_RAM_ADDRW  ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( 1                       ), // Protection code width
    .PARITY_MODE             ( CX_CXL_PARITY_MODE      ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_hreq_drsp_ram_raddr_ras_dp_pipe [HREQ_DRSP_NUM-1:0](
    .clk                       ( b_clk.s_core_clk                                  ),
    .rst_n                     ( b_clk.s_core_rst_n                                ),
    .din                       ( hreq_drsp_ram_raddr_i                             ),
    .din_prot                  ( '0                                                ),
    .dout                      ( hreq_drsp_ram_raddr_o                             ),
    .dout_prot                 ( hreq_drsp_ram_raddr_par_o                         ),
    .en                        ( 1'b0                                              ),
    .bypass                    ( 1'b0                                              ),
    .stall                     ( 1'b0                                              ),
    .stallout                  ( /* Unused */                                      ),
    .valid_in                  ( 1'b0                                              ),
    .halt_out                  ( /* Unused */                                      ),
    .valid_out                 ( /* Unused */                                      ),
    .halt_in                   ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_out ( /* Unused */                                      ),
    .ras_dp_err_log            ( /* Unused */                                      )
    ,
    .ras_dp_err_inj            ( {HREQ_DRSP_NUM{15'b0}}                            )
);

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                       ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( 1                       ), // Protection type
    .PROT_RANGE              ( HRSP_DREQ_RX_RAM_ADDRW  ), // Protection range
    .TOTAL_WIDTH             ( HRSP_DREQ_RX_RAM_ADDRW  ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( 1                       ), // Protection code width
    .PARITY_MODE             ( CX_CXL_PARITY_MODE      ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_hrsp_dreq_ram_raddr_ras_dp_pipe [HRSP_DREQ_NUM-1:0](
    .clk                       ( b_clk.s_core_clk                                  ),
    .rst_n                     ( b_clk.s_core_rst_n                                ),
    .din                       ( hrsp_dreq_ram_raddr_i                             ),
    .din_prot                  ( '0                                                ),
    .dout                      ( hrsp_dreq_ram_raddr_o                             ),
    .dout_prot                 ( hrsp_dreq_ram_raddr_par_o                         ),
    .en                        ( 1'b0                                              ),
    .bypass                    ( 1'b0                                              ),
    .stall                     ( 1'b0                                              ),
    .stallout                  ( /* Unused */                                      ),
    .valid_in                  ( 1'b0                                              ),
    .halt_out                  ( /* Unused */                                      ),
    .valid_out                 ( /* Unused */                                      ),
    .halt_in                   ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_out ( /* Unused */                                      ),
    .ras_dp_err_log            ( /* Unused */                                      )
    ,
    .ras_dp_err_inj            ( {HRSP_DREQ_NUM{15'b0}}                            )
);

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                       ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( 1                       ), // Protection type
    .PROT_RANGE              ( HD_DATA_RX_RAM_ADDRW    ), // Protection range
    .TOTAL_WIDTH             ( HD_DATA_RX_RAM_ADDRW    ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( 1                       ), // Protection code width
    .PARITY_MODE             ( CX_CXL_PARITY_MODE      ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_hd_data_ram_raddr_ras_dp_pipe [HD_DDATA_NUM-1:0] (
    .clk                       ( b_clk.s_core_clk                                  ),
    .rst_n                     ( b_clk.s_core_rst_n                                ),
    .din                       ( hd_data_ram_raddr_i                               ),
    .din_prot                  ( '0                                                ),
    .dout                      ( hd_data_ram_raddr_o                               ),
    .dout_prot                 ( hd_data_ram_raddr_par_o                           ),
    .en                        ( 1'b0                                              ),
    .bypass                    ( 1'b0                                              ),
    .stall                     ( 1'b0                                              ),
    .stallout                  ( /* Unused */                                      ),
    .valid_in                  ( 1'b0                                              ),
    .halt_out                  ( /* Unused */                                      ),
    .valid_out                 ( /* Unused */                                      ),
    .halt_in                   ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_out ( /* Unused */                                      ),
    .ras_dp_err_log            ( /* Unused */                                      )
    ,
    .ras_dp_err_inj            ( {HD_DDATA_NUM{15'b0}}                              )
);

// -------------------------------------------------------------------------------------
// RAM Mem Address Parity Generator
// -------------------------------------------------------------------------------------
ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                       ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( 1                       ), // Protection type
    .PROT_RANGE              ( MS_NDR_RX_RAM_ADDRW     ), // Protection range
    .TOTAL_WIDTH             ( MS_NDR_RX_RAM_ADDRW     ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( 1                       ), // Protection code width
    .PARITY_MODE             ( CX_CXL_PARITY_MODE      ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_ms_ndr_ram_waddr_ras_dp_pipe [MS_SM_NDR_NUM-1:0](
    .clk                       ( b_clk.s_core_clk                                  ),
    .rst_n                     ( b_clk.s_core_rst_n                                ),
    .din                       ( ms_ndr_ram_waddr_i                                ),
    .din_prot                  ( '0                                                ),
    .dout                      ( ms_ndr_ram_waddr_o                                ),
    .dout_prot                 ( ms_ndr_ram_waddr_par_o                            ),
    .en                        ( 1'b0                                              ),
    .bypass                    ( 1'b0                                              ),
    .stall                     ( 1'b0                                              ),
    .stallout                  ( /* Unused */                                      ),
    .valid_in                  ( 1'b0                                              ),
    .halt_out                  ( /* Unused */                                      ),
    .valid_out                 ( /* Unused */                                      ),
    .halt_in                   ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_out ( /* Unused */                                      ),
    .ras_dp_err_log            ( /* Unused */                                      )
    ,
    .ras_dp_err_inj            ( {MS_SM_NDR_NUM{15'b0}}                            )
);

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                       ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( 1                       ), // Protection type
    .PROT_RANGE              ( MS_DATA_RX_RAM_ADDRW    ), // Protection range
    .TOTAL_WIDTH             ( MS_DATA_RX_RAM_ADDRW    ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( 1                       ), // Protection code width
    .PARITY_MODE             ( CX_CXL_PARITY_MODE      ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_ms_data_ram_waddr_ras_dp_pipe [MS_SM_DDATA_NUM-1:0] (
    .clk                       ( b_clk.s_core_clk                                  ),
    .rst_n                     ( b_clk.s_core_rst_n                                ),
    .din                       ( ms_data_ram_waddr_i                               ),
    .din_prot                  ( '0                                                ),
    .dout                      ( ms_data_ram_waddr_o                               ),
    .dout_prot                 ( ms_data_ram_waddr_par_o                           ),
    .en                        ( 1'b0                                              ),
    .bypass                    ( 1'b0                                              ),
    .stall                     ( 1'b0                                              ),
    .stallout                  ( /* Unused */                                      ),
    .valid_in                  ( 1'b0                                              ),
    .halt_out                  ( /* Unused */                                      ),
    .valid_out                 ( /* Unused */                                      ),
    .halt_in                   ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_out ( /* Unused */                                      ),
    .ras_dp_err_log            ( /* Unused */                                      )
    ,
    .ras_dp_err_inj            ( {MS_SM_DDATA_NUM{15'b0}}                                                 )
);

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                       ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( 1                       ), // Protection type
    .PROT_RANGE              ( MS_NDR_RX_RAM_ADDRW     ), // Protection range
    .TOTAL_WIDTH             ( MS_NDR_RX_RAM_ADDRW     ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( 1                       ), // Protection code width
    .PARITY_MODE             ( CX_CXL_PARITY_MODE      ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_ms_ndr_ram_raddr_ras_dp_pipe [MS_SM_NDR_NUM-1:0](
    .clk                       ( b_clk.s_core_clk                                  ),
    .rst_n                     ( b_clk.s_core_rst_n                                ),
    .din                       ( ms_ndr_ram_raddr_i                                ),
    .din_prot                  ( '0                                                ),
    .dout                      ( ms_ndr_ram_raddr_o                                ),
    .dout_prot                 ( ms_ndr_ram_raddr_par_o                            ),
    .en                        ( 1'b0                                              ),
    .bypass                    ( 1'b0                                              ),
    .stall                     ( 1'b0                                              ),
    .stallout                  ( /* Unused */                                      ),
    .valid_in                  ( 1'b0                                              ),
    .halt_out                  ( /* Unused */                                      ),
    .valid_out                 ( /* Unused */                                      ),
    .halt_in                   ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_out ( /* Unused */                                      ),
    .ras_dp_err_log            ( /* Unused */                                      )
    ,
    .ras_dp_err_inj            ( {MS_SM_NDR_NUM{15'b0}}                            )
);

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                       ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( 1                       ), // Protection type
    .PROT_RANGE              ( MS_DATA_RX_RAM_ADDRW    ), // Protection range
    .TOTAL_WIDTH             ( MS_DATA_RX_RAM_ADDRW    ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( 1                       ), // Protection code width
    .PARITY_MODE             ( CX_CXL_PARITY_MODE      ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_ms_data_ram_raddr_ras_dp_pipe [MS_SM_DDATA_NUM-1:0] (
    .clk                       ( b_clk.s_core_clk                                  ),
    .rst_n                     ( b_clk.s_core_rst_n                                ),
    .din                       ( ms_data_ram_raddr_i                               ),
    .din_prot                  ( '0                                                ),
    .dout                      ( ms_data_ram_raddr_o                               ),
    .dout_prot                 ( ms_data_ram_raddr_par_o                           ),
    .en                        ( 1'b0                                              ),
    .bypass                    ( 1'b0                                              ),
    .stall                     ( 1'b0                                              ),
    .stallout                  ( /* Unused */                                      ),
    .valid_in                  ( 1'b0                                              ),
    .halt_out                  ( /* Unused */                                      ),
    .valid_out                 ( /* Unused */                                      ),
    .halt_in                   ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_out ( /* Unused */                                      ),
    .ras_dp_err_log            ( /* Unused */                                      )
    ,
    .ras_dp_err_inj            ( {MS_SM_DDATA_NUM{15'b0}}                         )
);

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                       ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( 1                       ), // Protection type
    .PROT_RANGE              ( MS_BI_RX_RAM_ADDRW      ), // Protection range
    .TOTAL_WIDTH             ( MS_BI_RX_RAM_ADDRW      ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( 1                       ), // Protection code width
    .PARITY_MODE             ( CX_CXL_PARITY_MODE      ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_ms_bi_ram_waddr_ras_dp_pipe [MS_BI_NUM-1:0](
    .clk                       ( b_clk.s_core_clk                                  ),
    .rst_n                     ( b_clk.s_core_rst_n                                ),
    .din                       ( ms_bi_ram_waddr_i                                 ),
    .din_prot                  ( '0                                                ),
    .dout                      ( mrsp_ssnp_bi_ram_waddr_o                          ),
    .dout_prot                 ( mrsp_ssnp_bi_ram_waddr_par_o                      ),
    .en                        ( 1'b0                                              ),
    .bypass                    ( 1'b0                                              ),
    .stall                     ( 1'b0                                              ),
    .stallout                  ( /* Unused */                                      ),
    .valid_in                  ( 1'b0                                              ),
    .halt_out                  ( /* Unused */                                      ),
    .valid_out                 ( /* Unused */                                      ),
    .halt_in                   ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_out ( /* Unused */                                      ),
    .ras_dp_err_log            ( /* Unused */                                      )
    ,
    .ras_dp_err_inj            ( {MS_BI_NUM{15'b0}}                                )
);

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                       ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( 1                       ), // Protection type
    .PROT_RANGE              ( MS_BI_RX_RAM_ADDRW      ), // Protection range
    .TOTAL_WIDTH             ( MS_BI_RX_RAM_ADDRW      ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( 1                       ), // Protection code width
    .PARITY_MODE             ( CX_CXL_PARITY_MODE      ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_ms_bi_ram_raddr_ras_dp_pipe [MS_BI_NUM-1:0](
    .clk                       ( b_clk.s_core_clk                                  ),
    .rst_n                     ( b_clk.s_core_rst_n                                ),
    .din                       ( ms_bi_ram_raddr_i                                 ),
    .din_prot                  ( '0                                                ),
    .dout                      ( mrsp_ssnp_bi_ram_raddr_o                          ),
    .dout_prot                 ( mrsp_ssnp_bi_ram_raddr_par_o                      ),
    .en                        ( 1'b0                                              ),
    .bypass                    ( 1'b0                                              ),
    .stall                     ( 1'b0                                              ),
    .stallout                  ( /* Unused */                                      ),
    .valid_in                  ( 1'b0                                              ),
    .halt_out                  ( /* Unused */                                      ),
    .valid_out                 ( /* Unused */                                      ),
    .halt_in                   ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_out ( /* Unused */                                      ),
    .ras_dp_err_log            ( /* Unused */                                      )
    ,
    .ras_dp_err_inj            ( {MS_BI_NUM{15'b0}}                                )
);


endmodule : DWC_cxl_mem_cache_rx_tl_ras_ms
