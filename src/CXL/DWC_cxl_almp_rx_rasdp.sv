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
// ---   $Revision: #4 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_almp_rx_rasdp.sv#4 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// CXL ALMP RX RASDP checker 
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

module DWC_cxl_almp_rx_rasdp
  import  DWC_cxl_pkg::*;
  import  DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import  DWC_pcie_ctl_pkg::RAS_DP_PROT_CHK_ID_BASE_VLSM;
  import  DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
#(
    parameter TP = `TP
) (

  input                            core_clk,
  input                            core_rst_n,
  input   ras_dp_err_inj_t         ras_dp_err_inj,
  input                            rmlh_cxl_almp_dv_i,
  input   [31:0]                   rmlh_cxl_almp_data_i,
  input   [ 3:0]                   rmlh_cxl_almp_data_chk_i,
  output                           rmlh_cxl_almp_dv_o,
  output  [31:0]                   rmlh_cxl_almp_data_o,
  output                           rx_almp_rasdp_err,
  output ras_dp_err_log_t          rx_almp_rasdp_err_log
);

localparam P_BUS_PROTECT_CHK_EN = 1;
logic        rx_almp_rasdp_err_s ;
logic [31:0] rmlh_cxl_almp_data_s;
logic        rmlh_cxl_almp_dv_s  ;

ras_dp_pipe
 #(
  .PIPELINE_TYPE              ( 0                            ),   // No pipeline only checker instance
  .N_STAGES                   ( 0                            ),   // No pipeline delay from module
  .CAN_STALL                  ( 0                            ),   // No stalling
  .BUS_PROTECT_GEN_EN         ( 0                            ),   // No generator
  .BUS_PROTECT_CHK_EN         ( P_BUS_PROTECT_CHK_EN         ),   // Checker enabled
  .PROT_TYPE                  ( CX_CXL_PROT_TYPE             ),   // Parity check enabled
  .PROT_RANGE                 ( CX_CXL_PROT_RANGE            ),   //
  .PROT_WD                    ( 4                            ),   //  
  .PARITY_MODE                ( CX_CXL_PARITY_MODE           ),    // Parity mode set
  .PROT_CORRECT_EN            ( 0                            ),   // No correction
  .TOTAL_WIDTH                ( 32                           ),  
  .RAS_DP_PROT_CHK_ID_BASE    ( RAS_DP_PROT_CHK_ID_BASE_VLSM )
) u_rx_almp_data_chk (
  .clk                        ( core_clk                 ),
  .rst_n                      ( core_rst_n               ),
  .en                         ( 1'b1                     ),
  .bypass                     ( 1'b0                     ),
  .stall                      ( 1'b0                     ),
  .stallout                   (                          ),
  .valid_in                   ( rmlh_cxl_almp_dv_i       ),
  .din                        ( rmlh_cxl_almp_data_i     ),
  .din_prot                   ( rmlh_cxl_almp_data_chk_i ),
  .halt_out                   (                          ),  
  .valid_out                  ( rmlh_cxl_almp_dv_s       ),
  .dout                       ( rmlh_cxl_almp_data_s     ),
  .dout_prot                  (                          ),  
  .halt_in                    ( 1'b0                     ),
  .ras_dp_err_inband_kbd_in   ( 1'b0                     ),
  .ras_dp_err_inband_kbd_out  ( rx_almp_rasdp_err_s      ),
  .ras_dp_err_log             ( rx_almp_rasdp_err_log    )
  ,
  .ras_dp_err_inj             ( ras_dp_err_inj           )
);

delay_n
 #(
    .N     ( 1          ),
    .WD    ( 1 + 32 + 1 )
) u_rx_almp_data_regin (
  .clk   ( core_clk                 ),
  .rst_n ( core_rst_n               ),
  .clear ( 1'b0                     ),
  .din   ( {rx_almp_rasdp_err_s ,
            rmlh_cxl_almp_data_s,
            rmlh_cxl_almp_dv_s   }  ),
  .dout  ( {rx_almp_rasdp_err   ,
            rmlh_cxl_almp_data_o,
            rmlh_cxl_almp_dv_o   }  )
);
endmodule
