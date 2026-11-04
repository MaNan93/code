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
// ---   $DateTime: 2023/12/22 07:15:34 $
// ---   $Revision: #2 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_rx_dl_rasdp_wr_ms.sv#2 $
// ----------------------------------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------------------------------
// CXL Link Layer RASDP Wrapper Module for Multistream Architecture
// ----------------------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

module DWC_cxl_mem_cache_rx_dl_rasdp_wr_ms
  import DWC_cxl_pkg::*;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::RAS_DP_PROT_CHK_ID_BASE_CXL;
#(
    parameter TP = `TP
 )
                                            (
  
     input                                                           core_clk                           // Core clock 
    ,input                                                           core_rst_n                         // Core Reset
    ,input                                                           cxl_pcie_flit_mode                 // CXL Flit Mode (0-68B Flit Mode / 1-256B Flit Mode)
    ,input                                                           cxl_rx_llctrl_flit_ctrl_en         // RX LLCTRL Control Flit Valid
    ,input                                                           cxl_rx_llctrl_flit_prot_en         // RX LLCTRL Protocol Flit Valid
    ,input ras_dp_err_inj_t                                          ras_dp_err_inj                     // RASDP Error Injection control

 //  MultiStream Architecture RASDP Checker
    ,input         [CXL_DATA_WD-1:0]                                 cxl_flit_data_i                     //  Rx Protocol Flit Data
    ,input                                                           cxl_flit_valid_i                    //  RX Unpacker Protocol Flit Valid   
    ,output        [CXL_DATA_WD-1:0]                                 cxl_flit_data_256B_o                //  Protocol Flit Data after RAS checker
    ,output        [CXL_DATA_WD-1:0]                                 cxl_flit_data_68B_o                 //  Protocol Flit Data after Ras checker (68B - IDE enabled)
    ,output ras_dp_err_log_t                                         ras_dp_err_log_unpack               //  RASDP Error Log
    ,output                                                          ras_dp_uncorr_err_unpack            //  RASDP Uncorrectable Error to triger Viral
    ,output                                                          ras_dp_uncorr_err_unpack_latched    //  RASDP Uncorrectable Error to triger Viral (Latched)

 // RASDP Checker For Rxlink_ctrl

    ,input         [LLCTRL_FLIT_WD-1:0]                              cxl_rx_llctrl_flit_data             // RX LLCTRL Flit Data
    ,output        [LLCTRL_FLIT_WD-1:0]                              cxl_rx_llctrl_flit_data_o           // RX LLCTRL Flit Data after RASDP check (256B mode)
    ,output ras_dp_err_log_t [1:0]                                   ras_dp_err_log_ctrl                 // RASDP Error Log
    ,output         [CXL_RXLINK_CTRL_RAS_UNCORR_NUM-1:0]             ras_dp_uncorr_err_ctrl              // RASDP Uncorrectable Error to trigger Viral

    ,input         [CXL_DATA_WD-1:0]                                 cxl_rx_crc_flit_data                // CXL Flit Data  after CRC check
    ,input                                                           cxl_rx_crc_flit_valid               // CXL Flit Valid after CRC check
    ,output        [CXL_DATA_WD-1:0]                                 cxl_rx_crc_flit_data_o              // CXL Flit Data after CRC check and after RASDP check (256B mode)
    ,input         [CXL_DATA_PROT_WD-1:0]                            cxl_arb_mem_cache_data_chk          // ARB/MUX CXL Flit Data Protection


  // IDE Secure Interface RAS DP Generation
   
    ,output         [CXL_DATA_PROT_WD-1:0]                           cxl_rx_unpack_flit_data_chk         // RX Unpacker Flit Data RASDP Protection
 
 
); 


// RAS ID For unpacker
localparam CXL_RX_UNPACKER_RAS_ID = RAS_DP_PROT_CHK_ID_BASE_CXL + CXL_RX_UNPACKER_RAS_ID_INDEX;
// RAS ID For Rxlink_ctrl
localparam CXL_RX_LINK_CTRL_RAS_ID = RAS_DP_PROT_CHK_ID_BASE_CXL + CXL_RX_LINK_CTRL_RAS_ID_INDEX; 

// -------------------------------------------------
//  MultiStream Architecture RASDP Checker For Rxlink_ctrl
// -------------------------------------------------
// Local wires and regs
logic                                  cxl_rx_llctrl_flit_data_rasdp_valid;
logic [LLCTRL_FLIT_WD-1:0]             cxl_rx_llctrl_flit_rasdp_data;      // RX LLCTRL Flit Data after RASDP check
logic [LLCTRL_FLIT_CHK_SIZE-1:0]       cxl_rx_llctrl_flit_data_chk ;       // RX LLCTRL Flit Data
logic [CXL_DATA_PROT_WD-1:0]           cxl_llctrl_flit_data_rasdp_chk;     // CXL IDE Disable Mux Output - Flit Data RASDP Protection

// Bypass ras checker for 68B mode
assign cxl_rx_llctrl_flit_data_rasdp_valid = (cxl_pcie_flit_mode) ? (cxl_rx_llctrl_flit_ctrl_en | cxl_rx_llctrl_flit_prot_en) : 0;
assign cxl_rx_llctrl_flit_data_o           = (cxl_pcie_flit_mode) ? cxl_rx_llctrl_flit_rasdp_data : cxl_rx_llctrl_flit_data;

assign cxl_llctrl_flit_data_rasdp_chk = cxl_arb_mem_cache_data_chk;
assign cxl_rx_llctrl_flit_data_chk = cxl_llctrl_flit_data_rasdp_chk[LLCTRL_FLIT_CHK_SIZE-1:0];

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                       ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 0                       ), // Bus Protect Genenator is not enabled
    .BUS_PROTECT_CHK_EN      ( 1                       ), // Bus Protect Checker is enabled
    .PROT_TYPE               ( CX_CXL_PROT_TYPE        ), // Protection type
    .PROT_RANGE              ( CX_CXL_PROT_RANGE       ), // Protection range
    .TOTAL_WIDTH             ( LLCTRL_FLIT_WD          ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( LLCTRL_FLIT_CHK_SIZE    ), // Protection code width
    .PARITY_MODE             ( CX_CXL_PARITY_MODE      ), // Parity mode
    .PROT_CORRECT_EN         ( 1                       ), // Correction is enabled
    .RAS_DP_PROT_CHK_ID_BASE ( CXL_RX_LINK_CTRL_RAS_ID )  // Checker instance ID
) u_cxl_rx_llctrl_flit_data_ras_chk (
    .clk                       ( core_clk                               ),
    .rst_n                     ( core_rst_n                             ),
    .din                       ( cxl_rx_llctrl_flit_data                ),
    .din_prot                  ( cxl_rx_llctrl_flit_data_chk            ),
    .dout                      ( cxl_rx_llctrl_flit_rasdp_data          ),
    .dout_prot                 ( /* Unused */                           ),
    .en                        ( 1'b1                                   ),
    .bypass                    ( 1'b0                                   ),
    .stall                     ( 1'b0                                   ),
    .stallout                  ( /* Unused */                           ),
    .valid_in                  ( cxl_rx_llctrl_flit_data_rasdp_valid    ),
    .halt_out                  ( /* Unused */                           ),
    .valid_out                 ( /* Unused */                           ),
    .halt_in                   ( 1'b0                                   ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                   ),
    .ras_dp_err_inband_kbd_out ( ras_dp_uncorr_err_ctrl[0]              ),
    .ras_dp_err_log            ( ras_dp_err_log_ctrl[0]                 )
    ,
    .ras_dp_err_inj            ( ras_dp_err_inj                         )
);

logic                                  cxl_rx_crc_flit_data_rasdp_valid;
logic [CXL_DATA_WD-1:0]                cxl_rx_crc_flit_rasdp_data;         // CXL Flit Data after CRC check and after RASDP check

assign cxl_rx_crc_flit_data_rasdp_valid    = (cxl_pcie_flit_mode) ? cxl_rx_crc_flit_valid : 0;
assign cxl_rx_crc_flit_data_o              = (cxl_pcie_flit_mode) ? cxl_rx_crc_flit_rasdp_data : cxl_rx_crc_flit_data;

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                           ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                           ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 0                           ), // Bus Protect Genenator is not enabled
    .BUS_PROTECT_CHK_EN      ( 1                           ), // Bus Protect Checker is enabled
    .PROT_TYPE               ( CX_CXL_PROT_TYPE            ), // Protection type
    .PROT_RANGE              ( CX_CXL_PROT_RANGE           ), // Protection range
    .TOTAL_WIDTH             ( CXL_DATA_WD                 ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( CXL_DATA_PROT_WD            ), // Protection code width
    .PARITY_MODE             ( CX_CXL_PARITY_MODE          ), // Parity mode
    .PROT_CORRECT_EN         ( 1                           ), // Correction is enabled
    .RAS_DP_PROT_CHK_ID_BASE ( CXL_RX_LINK_CTRL_RAS_ID + 1 )  // Checker instance ID
) u_cxl_rx_crc_flit_data_ras_chk (
    .clk                       ( core_clk                               ),
    .rst_n                     ( core_rst_n                             ),
    .din                       ( cxl_rx_crc_flit_data                   ),
    .din_prot                  ( cxl_arb_mem_cache_data_chk             ),
    .dout                      ( cxl_rx_crc_flit_rasdp_data             ),
    .dout_prot                 ( /* Unused */                           ),
    .en                        ( 1'b1                                   ),
    .bypass                    ( 1'b0                                   ),
    .stall                     ( 1'b0                                   ),
    .stallout                  ( /* Unused */                           ),
    .valid_in                  ( cxl_rx_crc_flit_data_rasdp_valid       ),
    .halt_out                  ( /* Unused */                           ),
    .valid_out                 ( /* Unused */                           ),
    .halt_in                   ( 1'b0                                   ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                   ),
    .ras_dp_err_inband_kbd_out ( ras_dp_uncorr_err_ctrl[1]              ),
    .ras_dp_err_log            ( ras_dp_err_log_ctrl[1]                 )
    ,
    .ras_dp_err_inj            ( ras_dp_err_inj                         )
);

// -------------------------------------------------------------------------
// MultiStream Architecture RASDP Checker
// -------------------------------------------------------------------------
// Local wires and regs
logic                                      cxl_flit_data_valid_s;
logic [CXL_DATA_PROT_WD-1:0]               cxl_flit_data_chk_s;   // Protocol Flit Parity
logic [CXL_DATA_WD-1:0]                    cxl_flit_data_s;       // Flit Data After Ras Checker
logic                                      ras_dp_uncorr_err_unpack_r;

assign cxl_flit_data_valid_s = cxl_flit_valid_i & ( 1'b0 | cxl_pcie_flit_mode);
assign cxl_flit_data_256B_o  = cxl_flit_data_s;
assign cxl_flit_data_68B_o   = cxl_flit_data_i;
assign cxl_flit_data_chk_s = cxl_rx_unpack_flit_data_chk;

assign ras_dp_uncorr_err_unpack_latched = ras_dp_uncorr_err_unpack || ras_dp_uncorr_err_unpack_r;

// Latching unpacker uncorrectable error
delay_n_w_enable
 #(
    .N     (1),
    .WD    (1)
) u_cxl_ide_rx_flit_error (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .en    (ras_dp_uncorr_err_unpack),
    .din   (1'b1),
    .dout  (ras_dp_uncorr_err_unpack_r)
);

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                       ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 0                       ), // Bus Protect Genenator is not enabled
    .BUS_PROTECT_CHK_EN      ( 1                       ), // Bus Protect Checker is enabled
    .PROT_TYPE               ( CX_CXL_PROT_TYPE        ), // Protection type
    .PROT_RANGE              ( CX_CXL_PROT_RANGE       ), // Protection range
    .TOTAL_WIDTH             ( CXL_DATA_WD             ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( CXL_DATA_PROT_WD        ), // Protection code width
    .PARITY_MODE             ( CX_CXL_PARITY_MODE      ), // Parity mode
    .PROT_CORRECT_EN         ( 1                       ), // Correction is enabled
    .RAS_DP_PROT_CHK_ID_BASE ( CXL_RX_UNPACKER_RAS_ID  )  // Checker instance ID
) u_cxl_flit_data_ras_dp_pipe (
    .clk                       ( core_clk                               ),
    .rst_n                     ( core_rst_n                             ),
    .din                       ( cxl_flit_data_i                        ),
    .din_prot                  ( cxl_flit_data_chk_s                    ),
    .dout                      ( cxl_flit_data_s                        ),
    .dout_prot                 ( /* Unused */                           ),
    .en                        ( 1'b1                                   ),
    .bypass                    ( 1'b0                                   ),
    .stall                     ( 1'b0                                   ),
    .stallout                  ( /* Unused */                           ),
    .valid_in                  ( cxl_flit_data_valid_s                  ),
    .halt_out                  ( /* Unused */                           ),
    .valid_out                 ( /* Unused */                           ),
    .halt_in                   ( 1'b0                                   ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                   ),
    .ras_dp_err_inband_kbd_out ( ras_dp_uncorr_err_unpack               ),
    .ras_dp_err_log            ( ras_dp_err_log_unpack                  )
    ,
    .ras_dp_err_inj            ( ras_dp_err_inj                         )
);


// ------------------------------------------------------------------
// IDE Secure Interface RAS DP Generation
// ------------------------------------------------------------------

// CXL IDE Disable Mux Output -Flit Data RASDP Protection
assign cxl_rx_unpack_flit_data_chk = cxl_arb_mem_cache_data_chk;


endmodule
