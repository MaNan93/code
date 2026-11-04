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
// ---   $DateTime: 2024/01/19 09:25:58 $
// ---   $Revision: #3 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_tx_rasdp_wr_ms.sv#3 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// CXL Transmitter RASDP Wrapper Module for Multistream Architecture
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

`include "CXL/svif/DWC_cxl_clk_rst_if.svh"
`include "CXL/svif/DWC_cxl_txtl_llctrl_if.svh"

module DWC_cxl_mem_cache_tx_rasdp_wr_ms
    import DWC_cxl_pkg::*;
    import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
    import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
    import DWC_pcie_ctl_pkg::RAS_DP_PROT_CHK_ID_BASE_CXL;

#(
    parameter TP = `TP
 )
                                           (
    // Clock and Reset
      input                                       core_clk                    // Core clock
    , input                                       core_rst_n                  // Core active low asynchronous reset
    , DWC_cxl_txtl_llctrl_if.slave_rasdp_mp       b_txtl_rasdp                // Transaction Layer - RASDP Wrapper Interface
    , input                                       cfg_dev_mode                // Device Mode: 1 - Host, 0 - Device
    , input                                       cxl_pcie_flit_mode          // 256B Mode Enable
    , input ras_dp_err_inj_t                      ras_dp_err_inj
    , output ras_dp_err_log_t                     ras_dp_err_log              // Error Logs from RASDP instances
    , output [CXL_TX_TL_RAS_UNCORR_NUM-1:0]       ras_dp_uncorr_err           // RASDP Uncorrectable Error to trigger Viral
    // -------------------------------------------------------------------------------------
    // CXL Interface Channels
    // -------------------------------------------------------------------------------------
    , DWC_cxl_txtl_llctrl_if.master_host_mp       b_txtl_mst_host             // RASDP Wrapper - Link Layer Interface for Host Channels
    , DWC_cxl_txtl_llctrl_if.slave_host_mp        b_txtl_slv_host             // Transaction Layer - RASDP Wrapper Interface for Host Channels
    , DWC_cxl_txtl_llctrl_if.master_dev_mp        b_txtl_mst_dev              // RASDP Wrapper - Link Layer Interface for Host Channels
    , DWC_cxl_txtl_llctrl_if.slave_dev_mp         b_txtl_slv_dev              // Transaction Layer - RASDP Wrapper Interface for Host Channels
    ,output logic                                 cxl_s2m_data_pis 
    ,output logic                                 cxl_m2s_data_pis 
    ,output logic                                 cxl_h2d_data_pis 
    ,output logic                                 cxl_d2h_data_pis 
);


// -------------------------------------------------------------------------------------
// Passing signals from Transaction Layer to Link Layer Interface
// -------------------------------------------------------------------------------------
assign b_txtl_mst_dev.s_cxl_cache_app_pending = b_txtl_slv_dev.s_cxl_cache_app_pending;
assign b_txtl_mst_host.s_cxl_cache_app_pending = b_txtl_slv_host.s_cxl_cache_app_pending;

assign b_txtl_mst_dev.s_cxl_mem_app_pending = b_txtl_slv_dev.s_cxl_mem_app_pending;
assign b_txtl_mst_host.s_cxl_mem_app_pending = b_txtl_slv_host.s_cxl_mem_app_pending;
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// RASDP Checker Instances IDs
// -------------------------------------------------------------------------------------
localparam CXL_TX_H2D_REQ_RAS_ID         = RAS_DP_PROT_CHK_ID_BASE_CXL + CXL_TX_H2D_REQ_RAS_ID_INDEX;
localparam CXL_TX_H2D_RESP_RAS_ID        = RAS_DP_PROT_CHK_ID_BASE_CXL + CXL_TX_H2D_RESP_RAS_ID_INDEX; 
localparam CXL_TX_H2D_HDR_RAS_ID         = RAS_DP_PROT_CHK_ID_BASE_CXL + CXL_TX_H2D_HDR_RAS_ID_INDEX; 
localparam CXL_TX_H2D_DATA_RAS_ID        = RAS_DP_PROT_CHK_ID_BASE_CXL + CXL_TX_H2D_DATA_RAS_ID_INDEX; 
localparam CXL_TX_M2S_NDR_RAS_ID         = RAS_DP_PROT_CHK_ID_BASE_CXL + CXL_TX_M2S_NDR_RAS_ID_INDEX; 
localparam CXL_TX_M2S_HDR_RAS_ID         = RAS_DP_PROT_CHK_ID_BASE_CXL + CXL_TX_M2S_HDR_RAS_ID_INDEX; 
localparam CXL_TX_M2S_BE_RAS_ID          = RAS_DP_PROT_CHK_ID_BASE_CXL + CXL_TX_M2S_BE_RAS_ID_INDEX; 
localparam CXL_TX_M2S_DATA_RAS_ID        = RAS_DP_PROT_CHK_ID_BASE_CXL + CXL_TX_M2S_DATA_RAS_ID_INDEX;
localparam CXL_TX_S2M_NDR_RAS_ID         = RAS_DP_PROT_CHK_ID_BASE_CXL + CXL_TX_S2M_NDR_RAS_ID_INDEX;
localparam CXL_TX_S2M_HDR_RAS_ID         = RAS_DP_PROT_CHK_ID_BASE_CXL + CXL_TX_S2M_HDR_RAS_ID_INDEX;
localparam CXL_TX_S2M_DATA_RAS_ID        = RAS_DP_PROT_CHK_ID_BASE_CXL + CXL_TX_S2M_DATA_RAS_ID_INDEX;
localparam CXL_TX_D2H_REQ_RAS_ID         = RAS_DP_PROT_CHK_ID_BASE_CXL + CXL_TX_D2H_REQ_RAS_ID_INDEX;
localparam CXL_TX_D2H_RESP_RAS_ID        = RAS_DP_PROT_CHK_ID_BASE_CXL + CXL_TX_D2H_RESP_RAS_ID_INDEX;
localparam CXL_TX_D2H_HDR_RAS_ID         = RAS_DP_PROT_CHK_ID_BASE_CXL + CXL_TX_D2H_HDR_RAS_ID_INDEX;
localparam CXL_TX_D2H_BE_RAS_ID          = RAS_DP_PROT_CHK_ID_BASE_CXL + CXL_TX_D2H_BE_RAS_ID_INDEX;
localparam CXL_TX_D2H_DATA_RAS_ID        = RAS_DP_PROT_CHK_ID_BASE_CXL + CXL_TX_D2H_DATA_RAS_ID_INDEX;
localparam CXL_TX_S2M_BI_SNP_RAS_ID      = RAS_DP_PROT_CHK_ID_BASE_CXL + CXL_TX_S2M_BI_SNP_RAS_ID_INDEX;
localparam CXL_TX_M2S_BI_RSP_RAS_ID      = RAS_DP_PROT_CHK_ID_BASE_CXL + CXL_TX_M2S_BI_RSP_RAS_ID_INDEX; 

// -------------------------------------------------------------------------------------
// Total Cache/Mem Error Logs
// -------------------------------------------------------------------------------------
// H2D Managers (Err Logs) = 4: Req, Rsp, HDR, Data
// D2H Managers (Err Logs) = 5: Req, Rsp, HDR, Data, BE
localparam CXL_CACHE_ERR_LOG_NUM = 0 
  + 4
  + 5
;

ras_dp_err_log_t [CXL_CACHE_ERR_LOG_NUM-1:0] ras_dp_err_log_cache_arr;
ras_dp_err_log_t                             ras_dp_err_log_cache;
ras_dp_err_inj_t                             ras_dp_err_inj_cache;

// M2S Managers (Err Logs) = 4: Req, HDR, Data, BE
// S2M Managers (Err Logs) = 3: Req, HDR, Data
// M2S BI Managers (Err Logs) = 1: BI RSP
// S2M BI Managers (Err Logs) = 1: BI SNP
localparam CXL_MEM_ERR_LOG_NUM = 0 
      + 4
      + 3
   + 1
   + 1
;

ras_dp_err_log_t [CXL_MEM_ERR_LOG_NUM-1:0] ras_dp_err_log_mem_arr;
ras_dp_err_log_t                           ras_dp_err_log_mem;
ras_dp_err_inj_t                           ras_dp_err_inj_mem;

localparam CXL_CACHE_MEM_ERR_LOG_NUM = 0
 + 1
   + 1
;

ras_dp_err_log_t [CXL_CACHE_MEM_ERR_LOG_NUM-1:0] ras_dp_err_log_cache_mem;
ras_dp_err_inj_t                                 ras_dp_err_inj_cache_mem;
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// CXL.cache H2D Message Channel Interface between Transaction and Link Layer
// -------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------
// H2D REQ Protection
// -------------------------------------------------------------------------------------
parameter H2D_REQ_PROT_WD     = H2D_REQ_CHK_SIZE;
parameter H2D_REQ_DATA_WD     = H2D_REQ_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;
parameter H2D_REQ_W_CNT_SIZE  = H2D_REQ_SIZE + H2D_MSG_CNT_WD;

logic [H2D_REQ_DATA_WD-1:0]                     datain_h2d_req [0:H2D_REQ_NUM-1];
logic [H2D_REQ_DATA_WD-1:0]                     dataout_h2d_req_int [0:H2D_REQ_NUM-1];
logic [H2D_REQ_NUM-1:0][H2D_REQ_SIZE-1:0]       dataout_h2d_req;
logic [H2D_REQ_NUM-1:0][H2D_REQ_W_CNT_SIZE-1:0] dataout_h2d_req_w_cnt;
logic [H2D_REQ_W_CNT_SIZE-1:0]                  dataout_h2d_req_w_cnt_r [0:H2D_REQ_NUM-1];
logic [H2D_REQ_NUM-1:0]                         err_multpl_h2d_req;
logic [H2D_REQ_NUM-1:0]                         ras_dp_valid_in_h2d_req;

ras_dp_err_log_t [H2D_REQ_NUM-1:0]              ras_dp_err_log_h2d_req_arr;
ras_dp_err_log_t                                ras_dp_err_log_h2d_req;
ras_dp_err_inj_t                                ras_dp_err_inj_h2d_req;

generate
  for (genvar i = 0; i < H2D_REQ_NUM; i++) begin : h2d_req_checker

// RAS DP Checker Input Message and Valid
assign datain_h2d_req[i] = {b_txtl_slv_host.s_cxl_h2d_req[i], {(H2D_REQ_DATA_WD - H2D_REQ_SIZE){1'b0}}};
assign ras_dp_valid_in_h2d_req[i] = b_txtl_slv_host.s_cxl_h2d_req[i][0];

// RAS DP Checker Output Message
assign dataout_h2d_req[i] = { dataout_h2d_req_int[i][H2D_REQ_DATA_WD-1:(H2D_REQ_DATA_WD - H2D_REQ_SIZE)]};

// Combine Message Count with Message before propagating through output register
assign dataout_h2d_req_w_cnt[i] = {b_txtl_slv_host.s_cxl_h2d_req_cnt[i] , dataout_h2d_req[i]};
assign {b_txtl_mst_host.s_cxl_h2d_req_cnt[i], b_txtl_mst_host.s_cxl_h2d_req[i]} = dataout_h2d_req_w_cnt_r[i];

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                         ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                         ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 0                         ), // Bus Protect Genenator is not enabled
    .BUS_PROTECT_CHK_EN      ( 1                         ), // Bus Protect Checker is enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE      ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE     ), // Protection range
    .TOTAL_WIDTH             ( H2D_REQ_DATA_WD           ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( H2D_REQ_PROT_WD           ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE    ), // Parity mode
    .PROT_CORRECT_EN         ( 1                         ), // Correction is enabled
    .RAS_DP_PROT_CHK_ID_BASE ( CXL_TX_H2D_REQ_RAS_ID + i )  // Checker instance ID
) u_cxl_h2d_req_ras_dp_pipe (
    .clk                       ( core_clk                               ),
    .rst_n                     ( core_rst_n                             ),
    .din                       ( datain_h2d_req[i]                      ),
    .din_prot                  ( b_txtl_rasdp.s_cxl_h2d_req_chk[i]      ),
    .dout                      ( dataout_h2d_req_int[i]                 ),
    .dout_prot                 ( /* Unused */                           ),
    .en                        ( 1'b1                                   ),
    .bypass                    ( 1'b0                                   ),
    .stall                     ( 1'b0                                   ),
    .stallout                  ( /* Unused */                           ),
    .valid_in                  ( ras_dp_valid_in_h2d_req[i]             ),
    .halt_out                  ( /* Unused */                           ),
    .valid_out                 ( /* Unused */                           ),
    .halt_in                   ( 1'b0                                   ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                   ),
    .ras_dp_err_inband_kbd_out ( err_multpl_h2d_req[i]                  ),
    .ras_dp_err_log            ( ras_dp_err_log_h2d_req_arr[i]          )
    ,
    .ras_dp_err_inj            ( ras_dp_err_inj_h2d_req                 )
);
  end
endgenerate

ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N ( H2D_REQ_NUM )
) u_h2d_req_ras_dp_err_mgr (
    .clk                ( core_clk                    ),
    .rst_n              ( core_rst_n                  ),
    .in_ras_dp_err_inj  ( ras_dp_err_inj_cache        ),
    .out_ras_dp_err_inj ( ras_dp_err_inj_h2d_req      ),
    .in_ras_dp_err_log  ( ras_dp_err_log_h2d_req_arr  ),
    .out_ras_dp_err_log ( ras_dp_err_log_h2d_req      )
);

DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_NUM       ( H2D_REQ_NUM        ),
    .CXL_CHMSG_WIDTH     ( H2D_REQ_W_CNT_SIZE ),
    .CXL_CHMSG_REG       ( 1'b1               )
) u_h2d_req_regout (
    .core_clk            ( core_clk                           ),
    .core_rst_n          ( core_rst_n                         ),
    .cxl_tl_chmsg_vld_i  ( '0                                 ),
    .cxl_tl_chmsg_i      ( dataout_h2d_req_w_cnt              ),
    .cxl_ll_chmsg_halt_i ( b_txtl_mst_host.s_cxl_h2d_req_halt ),
    .cxl_ll_chmsg_o      ( dataout_h2d_req_w_cnt_r            ),
    .cxl_tl_chmsg_halt_o ( b_txtl_slv_host.s_cxl_h2d_req_halt )
);

// -------------------------------------------------------------------------------------
// H2D Rsp Protection
// -------------------------------------------------------------------------------------
parameter H2D_RESP_PROT_WD     = H2D_RESP_CHK_SIZE;
parameter H2D_RESP_DATA_WD     = H2D_RESP_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;
parameter H2D_RESP_W_CNT_SIZE  = H2D_RESP_SIZE + H2D_MSG_CNT_WD;

logic [H2D_RESP_DATA_WD-1:0]                      datain_h2d_rsp         [0:H2D_RESP_NUM-1];
logic [H2D_RESP_DATA_WD-1:0]                      dataout_h2d_rsp_int    [0:H2D_RESP_NUM-1];
logic [H2D_RESP_NUM-1:0][H2D_RESP_SIZE-1:0]       dataout_h2d_rsp;
logic [H2D_RESP_NUM-1:0][H2D_RESP_W_CNT_SIZE-1:0] dataout_h2d_rsp_w_cnt;
logic [H2D_RESP_W_CNT_SIZE-1:0]                   dataout_h2d_rsp_w_cnt_r [0:H2D_RESP_NUM-1];
logic [H2D_RESP_NUM-1:0]                          err_multpl_h2d_rsp;
logic [H2D_RESP_NUM-1:0]                          ras_dp_valid_in_h2d_rsp;

ras_dp_err_log_t [H2D_RESP_NUM-1:0] ras_dp_err_log_h2d_rsp_arr;
ras_dp_err_log_t                    ras_dp_err_log_h2d_rsp;
ras_dp_err_inj_t                    ras_dp_err_inj_h2d_rsp;

generate
  for (genvar i = 0; i < H2D_RESP_NUM; i++) begin : h2d_rsp_checker

// RAS DP Checker Input Message and Valid
assign datain_h2d_rsp[i] = {b_txtl_slv_host.s_cxl_h2d_rsp[i], {(H2D_RESP_DATA_WD - H2D_RESP_SIZE){1'b0}}};
assign ras_dp_valid_in_h2d_rsp[i] = b_txtl_slv_host.s_cxl_h2d_rsp[i][0];

// RAS DP Checker Output Message
assign dataout_h2d_rsp[i] = dataout_h2d_rsp_int[i][H2D_RESP_DATA_WD-1:(H2D_RESP_DATA_WD - H2D_RESP_SIZE)];
    
// Combine Message Count with Message before propagating through output register
assign dataout_h2d_rsp_w_cnt[i] = {b_txtl_slv_host.s_cxl_h2d_rsp_cnt[i] , dataout_h2d_rsp[i]};
assign {b_txtl_mst_host.s_cxl_h2d_rsp_cnt[i] , b_txtl_mst_host.s_cxl_h2d_rsp[i]} = dataout_h2d_rsp_w_cnt_r[i];

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                          ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                          ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 0                          ), // Bus Protect Genenator is not enabled
    .BUS_PROTECT_CHK_EN      ( 1                          ), // Bus Protect Checker is enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE       ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE      ), // Protection range
    .TOTAL_WIDTH             ( H2D_RESP_DATA_WD           ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( H2D_RESP_PROT_WD           ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE     ), // Parity mode
    .PROT_CORRECT_EN         ( 1                          ), // Correction is enabled
    .RAS_DP_PROT_CHK_ID_BASE ( CXL_TX_H2D_RESP_RAS_ID + i )  // Checker instance ID
) u_cxl_h2d_rsp_ras_dp_pipe (
    .clk                       ( core_clk                            ),
    .rst_n                     ( core_rst_n                          ),
    .din                       ( datain_h2d_rsp[i]                   ),
    .din_prot                  ( b_txtl_rasdp.s_cxl_h2d_rsp_chk[i]   ),
    .dout                      ( dataout_h2d_rsp_int[i]              ),
    .dout_prot                 ( /* Unused */                        ),
    .en                        ( 1'b1                                ),
    .bypass                    ( 1'b0                                ),
    .stall                     ( 1'b0                                ),
    .stallout                  ( /* Unused */                        ),
    .valid_in                  ( ras_dp_valid_in_h2d_rsp[i]          ),
    .halt_out                  ( /* Unused */                        ),
    .valid_out                 ( /* Unused */                        ),
    .halt_in                   ( 1'b0                                ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                ),
    .ras_dp_err_inband_kbd_out ( err_multpl_h2d_rsp[i]               ),
    .ras_dp_err_log            ( ras_dp_err_log_h2d_rsp_arr[i]       )
    ,
    .ras_dp_err_inj            ( ras_dp_err_inj_h2d_rsp              )
);
  end
endgenerate

ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N ( H2D_RESP_NUM )
) u_h2d_rsp_ras_dp_err_mgr (
    .clk                ( core_clk                    ),
    .rst_n              ( core_rst_n                  ),
    .in_ras_dp_err_inj  ( ras_dp_err_inj_cache        ),
    .out_ras_dp_err_inj ( ras_dp_err_inj_h2d_rsp      ),
    .in_ras_dp_err_log  ( ras_dp_err_log_h2d_rsp_arr  ),
    .out_ras_dp_err_log ( ras_dp_err_log_h2d_rsp      )
);

DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_NUM       ( H2D_RESP_NUM        ),
    .CXL_CHMSG_WIDTH     ( H2D_RESP_W_CNT_SIZE ),
    .CXL_CHMSG_REG       ( 1'b1                )
) u_h2d_rsp_regout (
    .core_clk            ( core_clk                           ),
    .core_rst_n          ( core_rst_n                         ),
    .cxl_tl_chmsg_vld_i  ( '0                                 ),
    .cxl_tl_chmsg_i      ( dataout_h2d_rsp_w_cnt              ),
    .cxl_ll_chmsg_halt_i ( b_txtl_mst_host.s_cxl_h2d_rsp_halt ),
    .cxl_ll_chmsg_o      ( dataout_h2d_rsp_w_cnt_r            ),
    .cxl_tl_chmsg_halt_o ( b_txtl_slv_host.s_cxl_h2d_rsp_halt )
);

// -------------------------------------------------------------------------------------
// H2D Data Protection
// -------------------------------------------------------------------------------------
parameter H2D_DATA_PROT_WD    = H2D_DDATA_CHK_SIZE;
parameter H2D_DATA_DATA_WD    = H2D_DDATA_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

parameter H2D_HDR_PROT_WD     = H2D_DHDR_CHK_SIZE;
parameter H2D_HDR_DATA_WD     = H2D_DHDR_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

logic [H2D_DATA_NUM-1:0][H2D_DATA_DATA_WD-1:0] s_dataout_h2d_data;
logic [H2D_DATA_NUM-1:0][H2D_DHDR_SIZE-1:0]    s_dataout_h2d_hdr;
logic [H2D_HDR_DATA_WD-1:0]                    datain_h2d_hdr [0:H2D_DATA_NUM-1];
logic [H2D_HDR_DATA_WD-1:0]                    dataout_h2d_hdr [0:H2D_DATA_NUM-1];
logic [H2D_HDR_DATA_WD-1:0]                    dataout_h2d_hdr_s [0:H2D_DATA_NUM-1];
logic [H2D_DATA_NUM-1:0]                       err_multpl_h2d_data;
logic [H2D_DATA_NUM-1:0]                       err_multpl_h2d_hdr;
logic [H2D_DATA_NUM-1:0]                       ras_dp_valid_in_h2d_hdr;
logic [H2D_DATA_NUM-1:0]                       ras_dp_valid_in_h2d_data;

ras_dp_err_log_t [H2D_DATA_NUM-1:0]            ras_dp_err_log_h2d_hdr_arr;
ras_dp_err_log_t [H2D_DATA_NUM-1:0]            ras_dp_err_log_h2d_data_arr;
ras_dp_err_log_t                               ras_dp_err_log_h2d_hdr;
ras_dp_err_log_t                               ras_dp_err_log_h2d_data;
ras_dp_err_inj_t                               ras_dp_err_inj_h2d_hdr;
ras_dp_err_inj_t                               ras_dp_err_inj_h2d_data;

// First data checker should be enabled when data_vld is asserted
// For 68B flit mode , Poison supported, header is aligned with data so headers are used as valid signal for data RAS checkers 
// For 256B flit mode, Posion is not supported, RAS checkers from (DDATA_NUM) to (DATA_NUM) are not enabled 
always_comb begin
  for(int h2d_idx = 0; h2d_idx < H2D_DDATA_NUM; h2d_idx++) begin
    ras_dp_valid_in_h2d_data[h2d_idx] = b_txtl_slv_host.s_cxl_h2d_data_vld[h2d_idx] ;
  end
  for(int h2d_idx = H2D_DDATA_NUM; h2d_idx < H2D_DATA_NUM; h2d_idx++) begin
    ras_dp_valid_in_h2d_data[h2d_idx] = b_txtl_slv_host.s_cxl_h2d_hdr[h2d_idx][0] && !cxl_pcie_flit_mode;
  end
end


always_ff@(posedge core_clk or negedge core_rst_n) //poison interrupt for h2d data
begin //
  if(!core_rst_n) begin
      cxl_h2d_data_pis<=#TP 'b0;
  end
  else begin
    // Poison is only supported for 68B flit mode so in case of an uncorrectable error in data error, error will interrupt poison 
    // Poison is not supported for 256B mode so in case of an uncorrectable error in data, error will be assigned to the ras uncorrectable error register
      cxl_h2d_data_pis<=#TP (cxl_pcie_flit_mode)? '0 : (|err_multpl_h2d_data);
  end
end //always_ff

generate 
  for (genvar i = 0; i < H2D_DATA_NUM; i++) begin : h2d_data_checker

assign datain_h2d_hdr[i] = {b_txtl_slv_host.s_cxl_h2d_hdr[i], {(H2D_HDR_DATA_WD - H2D_DHDR_SIZE){1'b0}}};
assign ras_dp_valid_in_h2d_hdr[i] = b_txtl_slv_host.s_cxl_h2d_hdr[i][0];

assign s_dataout_h2d_hdr[i] = dataout_h2d_hdr[i][H2D_HDR_DATA_WD-1:(H2D_HDR_DATA_WD - H2D_DHDR_SIZE)];
  
always_comb begin
    dataout_h2d_hdr[i] = dataout_h2d_hdr_s[i];

    if (err_multpl_h2d_data[i] && b_txtl_mst_host.s_cxl_h2d_hdr[i][0])begin //whenver valid data header is there.
    //set poison field in header in case of an uncorrectable error in data
    // Supporting poison for 68B mode only
      if (!cxl_pcie_flit_mode) begin
        dataout_h2d_hdr[i][H2D_HDR_DATA_WD - H2D_DHDR_SIZE + H2D_68B_POISON_BIT] = 1'b1;
      end
    end
end

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                         ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                         ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 0                         ), // Bus Protect Genenator is not enabled
    .BUS_PROTECT_CHK_EN      ( 1                         ), // Bus Protect Checker is enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE      ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE     ), // Protection range
    .TOTAL_WIDTH             ( H2D_HDR_DATA_WD           ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( H2D_HDR_PROT_WD           ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE    ), // Parity mode
    .PROT_CORRECT_EN         ( 1                         ), // Correction is enabled
    .RAS_DP_PROT_CHK_ID_BASE ( CXL_TX_H2D_HDR_RAS_ID + i )  // Checker instance ID
) u_cxl_h2d_hdr_ras_dp_pipe (
    .clk                       ( core_clk                            ),
    .rst_n                     ( core_rst_n                          ),
    .din                       ( datain_h2d_hdr[i]                   ),
    .din_prot                  ( b_txtl_rasdp.s_cxl_h2d_hdr_chk[i]   ),
    .dout                      ( dataout_h2d_hdr_s[i]                ),
    .dout_prot                 ( /* Unused */                        ),
    .en                        ( 1'b1                                ),
    .bypass                    ( 1'b0                                ),
    .stall                     ( 1'b0                                ),
    .stallout                  ( /* Unused */                        ),
    .valid_in                  ( ras_dp_valid_in_h2d_hdr[i]          ),
    .halt_out                  ( /* Unused */                        ),
    .valid_out                 ( /* Unused */                        ),
    .halt_in                   ( 1'b0                                ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                ),
    .ras_dp_err_inband_kbd_out ( err_multpl_h2d_hdr[i]               ),
    .ras_dp_err_log            ( ras_dp_err_log_h2d_hdr_arr[i]       )
    ,
    .ras_dp_err_inj            ( ras_dp_err_inj_h2d_hdr              )
);

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                          ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                          ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 0                          ), // Bus Protect Genenator is not enabled
    .BUS_PROTECT_CHK_EN      ( 1                          ), // Bus Protect Checker is enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE       ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE      ), // Protection range
    .TOTAL_WIDTH             ( H2D_DATA_DATA_WD           ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( H2D_DATA_PROT_WD           ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE     ), // Parity mode
    .PROT_CORRECT_EN         ( 1                          ), // Correction is enabled
    .RAS_DP_PROT_CHK_ID_BASE ( CXL_TX_H2D_DATA_RAS_ID + i )  // Checker instance ID
) u_cxl_h2d_data_ras_dp_pipe (
    .clk                       ( core_clk                            ),
    .rst_n                     ( core_rst_n                          ),
    .en                        ( 1'b1                                ),
    .bypass                    ( 1'b0                                ),
    .stall                     ( 1'b0                                ),
    .stallout                  (                                     ),
    //---------- Inputs ---------------
    .valid_in                  ( ras_dp_valid_in_h2d_data[i]         ),
    .din                       ( b_txtl_rasdp.s_cxl_h2d_data_arr[i]  ),
    .din_prot                  ( b_txtl_rasdp.s_cxl_h2d_data_chk[i]  ),
    .halt_out                  (                                     ),
    //---------- Outputs --------------
    .valid_out                 (                                     ),
    .dout                      ( s_dataout_h2d_data[i]               ),
    .dout_prot                 (                                     ),
    .halt_in                   ( 1'b0                                ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                ),
    .ras_dp_err_inband_kbd_out ( err_multpl_h2d_data[i]              ),
    .ras_dp_err_log            ( ras_dp_err_log_h2d_data_arr[i]      )
    ,
    .ras_dp_err_inj            ( ras_dp_err_inj_h2d_data             )
);
  end
endgenerate

ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N ( H2D_DATA_NUM )
) u_h2d_hdr_ras_dp_err_mgr (
    .clk                ( core_clk                    ),
    .rst_n              ( core_rst_n                  ),
    .in_ras_dp_err_inj  ( ras_dp_err_inj_cache        ),
    .out_ras_dp_err_inj ( ras_dp_err_inj_h2d_hdr      ),
    .in_ras_dp_err_log  ( ras_dp_err_log_h2d_hdr_arr  ),
    .out_ras_dp_err_log ( ras_dp_err_log_h2d_hdr      )
);

ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N ( H2D_DATA_NUM )
) u_h2d_data_ras_dp_err_mgr (
    .clk                ( core_clk                    ),
    .rst_n              ( core_rst_n                  ),
    .in_ras_dp_err_inj  ( ras_dp_err_inj_cache        ),
    .out_ras_dp_err_inj ( ras_dp_err_inj_h2d_data     ),
    .in_ras_dp_err_log  ( ras_dp_err_log_h2d_data_arr ),
    .out_ras_dp_err_log ( ras_dp_err_log_h2d_data     )
);

DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_NUM       ( H2D_DATA_NUM  ),
    .CXL_CHMSG_WIDTH     ( H2D_DHDR_SIZE ),
    .CXL_CHMSG_REG       ( 1'b1          )
) u_h2d_hdr_regout (
    .core_clk            ( core_clk                           ),
    .core_rst_n          ( core_rst_n                         ),
    .cxl_tl_chmsg_vld_i  ( '0                                 ),
    .cxl_tl_chmsg_i      ( s_dataout_h2d_hdr                  ),
    .cxl_ll_chmsg_halt_i ( b_txtl_mst_host.s_cxl_h2d_hdr_halt ),
    .cxl_ll_chmsg_o      ( b_txtl_mst_host.s_cxl_h2d_hdr      ),
    .cxl_tl_chmsg_halt_o ( b_txtl_slv_host.s_cxl_h2d_hdr_halt )
);

DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_DATA      ( 1'b1             ),
    .CXL_CHMSG_NUM       ( H2D_DDATA_NUM    ),
    .CXL_CHMSG_VLD_NUM   ( H2D_DDATA_NUM    ),
    .CXL_CHMSG_WIDTH     ( H2D_DATA_DATA_WD ),
    .CXL_CHMSG_REG       ( 1'b1             )
) u_h2d_data_regout (
    .core_clk            ( core_clk                               ),
    .core_rst_n          ( core_rst_n                             ),
    .cxl_tl_chmsg_i      ( s_dataout_h2d_data[H2D_DDATA_NUM-1:0]  ),
    .cxl_tl_chmsg_vld_i  ( b_txtl_slv_host.s_cxl_h2d_data_vld     ),
    .cxl_ll_chmsg_halt_i ( b_txtl_mst_host.s_cxl_h2d_data_halt    ),
    .cxl_ll_chmsg_o      ( b_txtl_mst_host.s_cxl_h2d_data         ),
    .cxl_ll_chmsg_vld_o  ( b_txtl_mst_host.s_cxl_h2d_data_vld     ),
    .cxl_tl_chmsg_halt_o ( b_txtl_slv_host.s_cxl_h2d_data_halt    )
);

// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// CXL.mem M2S Message Channel Interface between Transaction and Link Layer
// -------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------
// M2S NDR Protection
// -------------------------------------------------------------------------------------
parameter M2S_NDR_PROT_WD     = M2S_NDR_CHK_SIZE;
parameter M2S_NDR_DATA_WD     = M2S_NDR_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

logic [M2S_NDR_DATA_WD-1:0]                datain_m2s_req  [0:M2S_NDR_NUM-1];
logic [M2S_NDR_DATA_WD-1:0]                dataout_m2s_req [0:M2S_NDR_NUM-1];
logic [M2S_NDR_NUM-1:0][M2S_NDR_SIZE-1:0]  s_dataout_m2s_req;
logic [M2S_NDR_NUM-1:0]                    err_multpl_m2s_req;
logic [M2S_NDR_NUM-1:0]                    ras_dp_valid_in_m2s_req;

ras_dp_err_log_t [M2S_NDR_NUM-1:0]         ras_dp_err_log_m2s_req_arr;
ras_dp_err_log_t                           ras_dp_err_log_m2s_req;
ras_dp_err_inj_t                           ras_dp_err_inj_m2s_req;

generate
  for (genvar i = 0; i < M2S_NDR_NUM; i++) begin : m2s_req_checker

assign datain_m2s_req[i] = {b_txtl_slv_host.s_cxl_m2s_req[i], {(M2S_NDR_DATA_WD - M2S_NDR_SIZE){1'b0}}};
assign ras_dp_valid_in_m2s_req[i] = b_txtl_slv_host.s_cxl_m2s_req[i][0];

assign s_dataout_m2s_req[i] = dataout_m2s_req[i][M2S_NDR_DATA_WD-1:(M2S_NDR_DATA_WD - M2S_NDR_SIZE)];

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                          ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                          ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 0                          ), // Bus Protect Genenator is not enabled
    .BUS_PROTECT_CHK_EN      ( 1                          ), // Bus Protect Checker is enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE       ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE      ), // Protection range
    .TOTAL_WIDTH             ( M2S_NDR_DATA_WD            ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( M2S_NDR_PROT_WD            ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE     ), // Parity mode
    .PROT_CORRECT_EN         ( 1                          ), // Correction is enabled
    .RAS_DP_PROT_CHK_ID_BASE ( CXL_TX_M2S_NDR_RAS_ID + i  )  // Checker instance ID
) u_cxl_m2s_req_ras_dp_pipe (
    .clk                       ( core_clk                            ),
    .rst_n                     ( core_rst_n                          ),
    .en                        ( 1'b1                                ),
    .bypass                    ( 1'b0                                ),
    .stall                     ( 1'b0                                ),
    .stallout                  (                                     ),
    //---------- Inputs ---------------
    .valid_in                  ( ras_dp_valid_in_m2s_req[i]          ),
    .din                       ( datain_m2s_req[i]                   ),
    .din_prot                  ( b_txtl_rasdp.s_cxl_m2s_req_chk[i]   ),
    .halt_out                  (                                     ),
    //---------- Outputs --------------
    .valid_out                 (                                     ),
    .dout                      ( dataout_m2s_req[i]                  ),
    .dout_prot                 (                                     ),
    .halt_in                   ( 1'b0                                ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                ),
    .ras_dp_err_inband_kbd_out ( err_multpl_m2s_req[i]               ),
    .ras_dp_err_log            ( ras_dp_err_log_m2s_req_arr[i]       )
    ,
    .ras_dp_err_inj            ( ras_dp_err_inj_m2s_req              )
);
  end
endgenerate

ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N ( M2S_NDR_NUM )
) u_m2s_req_ras_dp_err_mgr (
    .clk                ( core_clk                    ),
    .rst_n              ( core_rst_n                  ),
    .in_ras_dp_err_inj  ( ras_dp_err_inj_mem          ),
    .out_ras_dp_err_inj ( ras_dp_err_inj_m2s_req      ),
    .in_ras_dp_err_log  ( ras_dp_err_log_m2s_req_arr  ),
    .out_ras_dp_err_log ( ras_dp_err_log_m2s_req      )
);

DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_NUM       ( M2S_NDR_NUM   ),
    .CXL_CHMSG_WIDTH     ( M2S_NDR_SIZE  ),
    .CXL_CHMSG_REG       ( 1'b1          )
) u_m2s_req_regout (
    .core_clk            ( core_clk                           ),
    .core_rst_n          ( core_rst_n                         ),
    .cxl_tl_chmsg_vld_i  ( '0                                 ),
    .cxl_tl_chmsg_i      ( s_dataout_m2s_req                  ),
    .cxl_ll_chmsg_halt_i ( b_txtl_mst_host.s_cxl_m2s_req_halt ),
    .cxl_ll_chmsg_o      ( b_txtl_mst_host.s_cxl_m2s_req      ),
    .cxl_tl_chmsg_halt_o ( b_txtl_slv_host.s_cxl_m2s_req_halt )
);


// -------------------------------------------------------------------------------------
// M2S Data Protection
// -------------------------------------------------------------------------------------
parameter M2S_HDR_PROT_WD     = M2S_DHDR_CHK_SIZE;
parameter M2S_HDR_DATA_WD     = M2S_DHDR_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

parameter M2S_BE_PROT_WD      = M2S_DBE_CHK_SIZE;
parameter M2S_BE_DATA_WD      = M2S_DBE_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

parameter M2S_DATA_PROT_WD    = M2S_DDATA_CHK_SIZE;
parameter M2S_DATA_DATA_WD    = M2S_DDATA_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

parameter M2S_DATA_BE_WD      = M2S_DATA_DATA_WD + M2S_BE_DATA_WD;

logic [M2S_HDR_DATA_WD-1:0]                    datain_m2s_hdr [0:M2S_DATA_NUM-1];
logic [M2S_HDR_DATA_WD-1:0]                    dataout_m2s_hdr [0:M2S_DATA_NUM-1];
logic [M2S_HDR_DATA_WD-1:0]                    dataout_m2s_hdr_s [0:M2S_DATA_NUM-1];
logic [M2S_DATA_NUM-1:0][M2S_DHDR_SIZE-1:0]    s_dataout_m2s_hdr;
logic [M2S_DATA_NUM-1:0][M2S_DATA_DATA_WD-1:0] s_dataout_m2s_data;
logic [M2S_DATA_NUM-1:0][M2S_BE_DATA_WD-1:0]   s_dataout_m2s_be;
logic [M2S_DATA_NUM-1:0][M2S_DATA_BE_WD-1:0]   cxl_m2s_data_be_s;
logic [M2S_DATA_BE_WD-1:0]                     cxl_m2s_data_be_r [0:M2S_DATA_NUM-1];
logic [M2S_DATA_DATA_WD-1:0]                   cxl_m2s_data_r [0:M2S_DATA_NUM-1];
logic [M2S_BE_DATA_WD-1:0]                     cxl_m2s_be_r [0:M2S_DATA_NUM-1];
logic [M2S_DATA_NUM-1:0]                       err_multpl_m2s_hdr;
logic [M2S_DATA_NUM-1:0]                       err_multpl_m2s_data;
logic [M2S_DATA_NUM-1:0]                       err_multpl_m2s_be;
logic [M2S_DATA_NUM-1:0]                       s_m2s_bi_conflict;
logic [M2S_DATA_NUM-1:0]                       ras_dp_valid_in_m2s_hdr;
logic [M2S_DATA_NUM-1:0]                       ras_dp_valid_in_m2s_data;

ras_dp_err_log_t [M2S_DATA_NUM-1:0]            ras_dp_err_log_m2s_hdr_arr;
ras_dp_err_log_t [M2S_DATA_NUM-1:0]            ras_dp_err_log_m2s_be_arr;
ras_dp_err_log_t [M2S_DATA_NUM-1:0]            ras_dp_err_log_m2s_data_arr;
ras_dp_err_log_t                               ras_dp_err_log_m2s_hdr;
ras_dp_err_log_t                               ras_dp_err_log_m2s_be;
ras_dp_err_log_t                               ras_dp_err_log_m2s_data;
ras_dp_err_inj_t                               ras_dp_err_inj_m2s_hdr;
ras_dp_err_inj_t                               ras_dp_err_inj_m2s_be;
ras_dp_err_inj_t                               ras_dp_err_inj_m2s_data;

// First data/be checker should be enabled when data_vld is asserted
always_comb begin
  for(int m2s_idx = 0; m2s_idx < M2S_DDATA_NUM; m2s_idx++) begin
    ras_dp_valid_in_m2s_data[m2s_idx] = b_txtl_slv_host.s_cxl_m2s_data_vld[m2s_idx];
  end
  for(int m2s_idx = M2S_DDATA_NUM; m2s_idx < M2S_DATA_NUM; m2s_idx++) begin
    ras_dp_valid_in_m2s_data[m2s_idx] = b_txtl_slv_host.s_cxl_m2s_hdr[m2s_idx][0] && !cxl_pcie_flit_mode;
  end
end

always_ff@(posedge core_clk or negedge core_rst_n) //poison interrupt for m2s data
begin //
  if(!core_rst_n) begin
      cxl_m2s_data_pis<=#TP 'b0;
  end
  else begin
      cxl_m2s_data_pis<=#TP (cxl_pcie_flit_mode)? '0 : ((|err_multpl_m2s_data) || (|err_multpl_m2s_be)) ;
  end
end //always_ff

generate
  for (genvar i = 0; i < M2S_DDATA_NUM; i++) begin : m2s_data_outputs
    assign b_txtl_mst_host.s_cxl_m2s_data[i]  = cxl_m2s_data_r[i];
    assign b_txtl_mst_host.s_cxl_m2s_be[i]    = cxl_m2s_be_r[i];
  end
endgenerate

generate
  for (genvar i = 0; i < M2S_DATA_NUM; i++) begin : m2s_data_checker
// RAS DP Checker Inputs
assign datain_m2s_hdr[i] = {b_txtl_slv_host.s_cxl_m2s_hdr[i], {(M2S_HDR_DATA_WD - M2S_DHDR_SIZE){1'b0}}};
assign ras_dp_valid_in_m2s_hdr[i] = b_txtl_slv_host.s_cxl_m2s_hdr[i][0];

// RAS DP Checker Output
assign s_dataout_m2s_hdr[i] = dataout_m2s_hdr[i][M2S_HDR_DATA_WD-1:(M2S_HDR_DATA_WD - M2S_DHDR_SIZE)];

// Combine each BE with its corresponding data before being delayed through ch_reg
assign cxl_m2s_data_be_s[i] = {s_dataout_m2s_be[i],  s_dataout_m2s_data[i]};
assign {cxl_m2s_be_r[i], cxl_m2s_data_r[i]} = cxl_m2s_data_be_r[i];
assign b_txtl_mst_host.s_cxl_m2s_be_vld_n[i] = &cxl_m2s_be_r[i];

assign s_m2s_bi_conflict[i] = (dataout_m2s_hdr_s[i][M2S_HDR_DATA_WD - M2S_DHDR_SIZE + M2S_OPCODE_MSB:M2S_HDR_DATA_WD - M2S_DHDR_SIZE + M2S_OPCODE_LSB] == M2S_BI_CONFLICT);

always_comb begin
    dataout_m2s_hdr[i] = dataout_m2s_hdr_s[i];

    // The data supplied with M2S RwD is undefined for Back-Invalidate Conflict operation, 
    // the Controller must disable error reporting and setting Poison bit when M2S RwD Opcode is equal to 0x4 (BI Conflict)
    if ((err_multpl_m2s_be[i] || err_multpl_m2s_data[i]) && b_txtl_mst_host.s_cxl_m2s_hdr[i][0] && !s_m2s_bi_conflict[i]) begin
      if (!cxl_pcie_flit_mode) begin
        dataout_m2s_hdr[i][M2S_HDR_DATA_WD - M2S_DHDR_SIZE + M2S_68B_POISON_BIT] = 1'b1;
      end
    end
end

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                         ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                         ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 0                         ), // Bus Protect Genenator is not enabled
    .BUS_PROTECT_CHK_EN      ( 1                         ), // Bus Protect Checker is enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE      ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE     ), // Protection range
    .TOTAL_WIDTH             ( M2S_HDR_DATA_WD           ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( M2S_HDR_PROT_WD           ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE    ), // Parity mode
    .PROT_CORRECT_EN         ( 1                         ), // Correction is enabled
    .RAS_DP_PROT_CHK_ID_BASE ( CXL_TX_M2S_HDR_RAS_ID + i )  // Checker instance ID
) u_cxl_m2s_hdr_ras_dp_pipe (
    .clk                       ( core_clk                            ),
    .rst_n                     ( core_rst_n                          ),
    .en                        ( 1'b1                                ),
    .bypass                    ( 1'b0                                ),
    .stall                     ( 1'b0                                ),
    .stallout                  (                                     ),
    //---------- Inputs ---------------
    .valid_in                  ( ras_dp_valid_in_m2s_hdr[i]          ),
    .din                       ( datain_m2s_hdr[i]                   ),
    .din_prot                  ( b_txtl_rasdp.s_cxl_m2s_hdr_chk[i]   ),
    .halt_out                  (                                     ),
    //---------- Outputs --------------
    .valid_out                 (                                     ),
    .dout                      ( dataout_m2s_hdr_s[i]                ),
    .dout_prot                 (                                     ),
    .halt_in                   ( 1'b0                                ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                ),
    .ras_dp_err_inband_kbd_out ( err_multpl_m2s_hdr[i]               ),
    .ras_dp_err_log            ( ras_dp_err_log_m2s_hdr_arr[i]       )
    ,
    .ras_dp_err_inj            ( ras_dp_err_inj_m2s_hdr              )
);

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                        ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                        ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 0                        ), // Bus Protect Genenator is not enabled
    .BUS_PROTECT_CHK_EN      ( 1                        ), // Bus Protect Checker is enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE     ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE    ), // Protection range
    .TOTAL_WIDTH             ( M2S_BE_DATA_WD           ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( M2S_BE_PROT_WD           ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE   ), // Parity mode
    .PROT_CORRECT_EN         ( 1                        ), // Correction is enabled
    .RAS_DP_PROT_CHK_ID_BASE ( CXL_TX_M2S_BE_RAS_ID + i )  // Checker instance ID
) u_cxl_m2s_be_ras_dp_pipe (
    .clk                       ( core_clk                            ),
    .rst_n                     ( core_rst_n                          ),
    .en                        ( 1'b1                                ),
    .bypass                    ( 1'b0                                ),
    .stall                     ( 1'b0                                ),
    .stallout                  (                                     ),
    //---------- Inputs ---------------
    .valid_in                  ( ras_dp_valid_in_m2s_data[i]         ),
    .din                       ( b_txtl_rasdp.s_cxl_m2s_be_arr[i]    ),
    .din_prot                  ( b_txtl_rasdp.s_cxl_m2s_be_chk[i]    ),
    .halt_out                  (                                     ),
    //---------- Outputs --------------
    .valid_out                 (                                     ),
    .dout                      ( s_dataout_m2s_be[i]                 ),
    .dout_prot                 (                                     ),
    .halt_in                   ( 1'b0                                ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                ),
    .ras_dp_err_inband_kbd_out ( err_multpl_m2s_be[i]                ),
    .ras_dp_err_log            ( ras_dp_err_log_m2s_be_arr[i]        )
    ,
    .ras_dp_err_inj            ( ras_dp_err_inj_m2s_be               )
);

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                          ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                          ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 0                          ), // Bus Protect Genenator is not enabled
    .BUS_PROTECT_CHK_EN      ( 1                          ), // Bus Protect Checker is enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE       ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE      ), // Protection range
    .TOTAL_WIDTH             ( M2S_DATA_DATA_WD           ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( M2S_DATA_PROT_WD           ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE     ), // Parity mode
    .PROT_CORRECT_EN         ( 1                          ), // Correction is enabled
    .RAS_DP_PROT_CHK_ID_BASE ( CXL_TX_M2S_DATA_RAS_ID + i )  // Checker instance ID
) u_cxl_m2s_data_ras_dp_pipe (
    .clk                       ( core_clk                            ),
    .rst_n                     ( core_rst_n                          ),
    .en                        ( 1'b1                                ),
    .bypass                    ( 1'b0                                ),
    .stall                     ( 1'b0                                ),
    .stallout                  (                                     ),
    //---------- Inputs ---------------
    .valid_in                  ( ras_dp_valid_in_m2s_data[i]         ),
    .din                       ( b_txtl_rasdp.s_cxl_m2s_data_arr[i]  ),
    .din_prot                  ( b_txtl_rasdp.s_cxl_m2s_data_chk[i]  ),
    .halt_out                  (                                     ),
    //---------- Outputs --------------
    .valid_out                 (                                     ),
    .dout                      ( s_dataout_m2s_data[i]               ),
    .dout_prot                 (                                     ),
    .halt_in                   ( 1'b0                                ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                ),
    .ras_dp_err_inband_kbd_out ( err_multpl_m2s_data[i]              ),
    .ras_dp_err_log            ( ras_dp_err_log_m2s_data_arr[i]      )
    ,
    .ras_dp_err_inj            ( ras_dp_err_inj_m2s_data             )
);

  end
endgenerate

ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N ( M2S_DATA_NUM )
) u_m2s_hdr_ras_dp_err_mgr (
    .clk                ( core_clk                    ),
    .rst_n              ( core_rst_n                  ),
    .in_ras_dp_err_inj  ( ras_dp_err_inj_mem          ),
    .out_ras_dp_err_inj ( ras_dp_err_inj_m2s_hdr      ),
    .in_ras_dp_err_log  ( ras_dp_err_log_m2s_hdr_arr  ),
    .out_ras_dp_err_log ( ras_dp_err_log_m2s_hdr      )
);

ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N ( M2S_DATA_NUM )
) u_m2s_be_ras_dp_err_mgr (
    .clk                ( core_clk                    ),
    .rst_n              ( core_rst_n                  ),
    .in_ras_dp_err_inj  ( ras_dp_err_inj_mem          ),
    .out_ras_dp_err_inj ( ras_dp_err_inj_m2s_be       ),
    .in_ras_dp_err_log  ( ras_dp_err_log_m2s_be_arr   ),
    .out_ras_dp_err_log ( ras_dp_err_log_m2s_be       )
);

ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N ( M2S_DATA_NUM )
) u_m2s_data_ras_dp_err_mgr (
    .clk                ( core_clk                    ),
    .rst_n              ( core_rst_n                  ),
    .in_ras_dp_err_inj  ( ras_dp_err_inj_mem          ),
    .out_ras_dp_err_inj ( ras_dp_err_inj_m2s_data     ),
    .in_ras_dp_err_log  ( ras_dp_err_log_m2s_data_arr ),
    .out_ras_dp_err_log ( ras_dp_err_log_m2s_data     )
);

DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_NUM       ( M2S_DATA_NUM      ),
    .CXL_CHMSG_WIDTH     ( M2S_DHDR_SIZE     ),
    .CXL_CHMSG_REG       ( 1'b1              )
) u_m2s_hdr_regout (
    .core_clk            ( core_clk                           ),
    .core_rst_n          ( core_rst_n                         ),
    .cxl_tl_chmsg_vld_i  ( '0                                 ),
    .cxl_tl_chmsg_i      ( s_dataout_m2s_hdr                  ),
    .cxl_ll_chmsg_halt_i ( b_txtl_mst_host.s_cxl_m2s_hdr_halt ),
    .cxl_ll_chmsg_o      ( b_txtl_mst_host.s_cxl_m2s_hdr      ),
    .cxl_tl_chmsg_halt_o ( b_txtl_slv_host.s_cxl_m2s_hdr_halt )
);

DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_DATA      ( 1'b1             ),
    .CXL_CHMSG_NUM       ( M2S_DATA_NUM     ),
    .CXL_CHMSG_VLD_NUM   ( M2S_DDATA_NUM    ),
    .CXL_CHMSG_WIDTH     ( M2S_DATA_BE_WD   ),
    .CXL_CHMSG_REG       ( 1'b1             )
) u_m2s_data_regout (
    .core_clk            ( core_clk                            ),
    .core_rst_n          ( core_rst_n                          ),
    .cxl_tl_chmsg_i      ( cxl_m2s_data_be_s                   ),
    .cxl_tl_chmsg_vld_i  ( b_txtl_slv_host.s_cxl_m2s_data_vld  ),
    .cxl_ll_chmsg_halt_i ( b_txtl_mst_host.s_cxl_m2s_data_halt ),
    .cxl_ll_chmsg_o      ( cxl_m2s_data_be_r                   ),
    .cxl_ll_chmsg_vld_o  ( b_txtl_mst_host.s_cxl_m2s_data_vld  ),
    .cxl_tl_chmsg_halt_o ( b_txtl_slv_host.s_cxl_m2s_data_halt )
);
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// CXL.cache D2H Message Channel Interface between Transaction and Link Layer
// -------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------
// D2H REQ Protection
// -------------------------------------------------------------------------------------
parameter D2H_REQ_PROT_WD     = D2H_REQ_CHK_SIZE;
parameter D2H_REQ_DATA_WD     = D2H_REQ_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

logic [D2H_REQ_DATA_WD-1:0]                  datain_d2h_req  [0:D2H_REQ_NUM-1];
logic [D2H_REQ_DATA_WD-1:0]                  dataout_d2h_req [0:D2H_REQ_NUM-1];
logic [D2H_REQ_NUM-1:0][D2H_REQ_SIZE-1:0]    s_dataout_d2h_req;
logic [D2H_REQ_NUM-1:0]                      err_multpl_d2h_req;
logic [D2H_REQ_NUM-1:0]                      ras_dp_valid_in_d2h_req;

ras_dp_err_log_t [D2H_REQ_NUM-1:0]           ras_dp_err_log_d2h_req_arr;
ras_dp_err_log_t                             ras_dp_err_log_d2h_req;
ras_dp_err_inj_t                             ras_dp_err_inj_d2h_req;

generate
  for (genvar i = 0; i < D2H_REQ_NUM; i++) begin : d2h_req_checker

assign datain_d2h_req[i] = {b_txtl_slv_dev.s_cxl_d2h_req[i], {(D2H_REQ_DATA_WD - D2H_REQ_SIZE){1'b0}}};
assign ras_dp_valid_in_d2h_req[i] = b_txtl_slv_dev.s_cxl_d2h_req[i][0];

assign s_dataout_d2h_req[i] = dataout_d2h_req[i][D2H_REQ_DATA_WD-1:(D2H_REQ_DATA_WD - D2H_REQ_SIZE)];

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                         ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                         ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 0                         ), // Bus Protect Genenator is not enabled
    .BUS_PROTECT_CHK_EN      ( 1                         ), // Bus Protect Checker is enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE      ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE     ), // Protection range
    .TOTAL_WIDTH             ( D2H_REQ_DATA_WD           ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( D2H_REQ_PROT_WD           ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE    ), // Parity mode
    .PROT_CORRECT_EN         ( 1                         ), // Correction is enabled
    .RAS_DP_PROT_CHK_ID_BASE ( CXL_TX_D2H_REQ_RAS_ID + i )  // Checker instance ID
) u_cxl_d2h_req_ras_dp_pipe (
    .clk                       ( core_clk                            ),
    .rst_n                     ( core_rst_n                          ),
    .en                        ( 1'b1                                ),
    .bypass                    ( 1'b0                                ),
    .stall                     ( 1'b0                                ),
    .stallout                  (                                     ),
    //---------- Inputs ---------------
    .valid_in                  ( ras_dp_valid_in_d2h_req[i]          ),
    .din                       ( datain_d2h_req[i]                   ),
    .din_prot                  ( b_txtl_rasdp.s_cxl_d2h_req_chk[i]   ),
    .halt_out                  (                                     ),
    //---------- Outputs --------------
    .valid_out                 (                                     ),
    .dout                      ( dataout_d2h_req[i]                  ),
    .dout_prot                 (                                     ),
    .halt_in                   ( 1'b0                                ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                ),
    .ras_dp_err_inband_kbd_out ( err_multpl_d2h_req[i]               ),
    .ras_dp_err_log            ( ras_dp_err_log_d2h_req_arr[i]       )
    ,
    .ras_dp_err_inj            ( ras_dp_err_inj_d2h_req              )
);

  end
endgenerate

ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N ( D2H_REQ_NUM )
) u_d2h_req_ras_dp_err_mgr (
    .clk                ( core_clk                    ),
    .rst_n              ( core_rst_n                  ),
    .in_ras_dp_err_inj  ( ras_dp_err_inj_cache        ),
    .out_ras_dp_err_inj ( ras_dp_err_inj_d2h_req      ),
    .in_ras_dp_err_log  ( ras_dp_err_log_d2h_req_arr  ),
    .out_ras_dp_err_log ( ras_dp_err_log_d2h_req      )
);

DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_NUM       ( D2H_REQ_NUM   ),
    .CXL_CHMSG_WIDTH     ( D2H_REQ_SIZE  ),
    .CXL_CHMSG_REG       ( 1'b1          )
) u_d2h_req_regout (
    .core_clk            ( core_clk                           ),
    .core_rst_n          ( core_rst_n                         ),
    .cxl_tl_chmsg_vld_i  ( '0                                 ),
    .cxl_tl_chmsg_i      ( s_dataout_d2h_req                  ),
    .cxl_ll_chmsg_halt_i ( b_txtl_mst_dev.s_cxl_d2h_req_halt  ),
    .cxl_ll_chmsg_o      ( b_txtl_mst_dev.s_cxl_d2h_req       ),
    .cxl_tl_chmsg_halt_o ( b_txtl_slv_dev.s_cxl_d2h_req_halt  )
);

// -------------------------------------------------------------------------------------
// D2H RSP Protection
// -------------------------------------------------------------------------------------
parameter D2H_RESP_PROT_WD     = D2H_RESP_CHK_SIZE;
parameter D2H_RESP_DATA_WD     = D2H_RESP_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

logic [D2H_RESP_DATA_WD-1:0]                datain_d2h_rsp  [0:D2H_RESP_NUM-1];
logic [D2H_RESP_DATA_WD-1:0]                dataout_d2h_rsp [0:D2H_RESP_NUM-1];
logic [D2H_RESP_NUM-1:0][D2H_RESP_SIZE-1:0] s_dataout_d2h_rsp;
logic [D2H_RESP_NUM-1:0]                    err_multpl_d2h_rsp;
logic [D2H_RESP_NUM-1:0]                    ras_dp_valid_in_d2h_rsp;

ras_dp_err_log_t [D2H_RESP_NUM-1:0]         ras_dp_err_log_d2h_rsp_arr;
ras_dp_err_log_t                            ras_dp_err_log_d2h_rsp;
ras_dp_err_inj_t                            ras_dp_err_inj_d2h_rsp;

generate
  for (genvar i = 0; i < D2H_RESP_NUM; i++) begin : d2h_rsp_checker

assign datain_d2h_rsp[i] = {b_txtl_slv_dev.s_cxl_d2h_rsp[i], {(D2H_RESP_DATA_WD - D2H_RESP_SIZE){1'b0}}};
assign ras_dp_valid_in_d2h_rsp[i] = b_txtl_slv_dev.s_cxl_d2h_rsp[i][0];

assign s_dataout_d2h_rsp[i] = dataout_d2h_rsp[i][D2H_RESP_DATA_WD-1:(D2H_RESP_DATA_WD - D2H_RESP_SIZE)];

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                          ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                          ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 0                          ), // Bus Protect Genenator is not enabled
    .BUS_PROTECT_CHK_EN      ( 1                          ), // Bus Protect Checker is enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE       ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE      ), // Protection range
    .TOTAL_WIDTH             ( D2H_RESP_DATA_WD           ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( D2H_RESP_PROT_WD           ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE     ), // Parity mode
    .PROT_CORRECT_EN         ( 1                          ), // Correction is enabled
    .RAS_DP_PROT_CHK_ID_BASE ( CXL_TX_D2H_RESP_RAS_ID + i )  // Checker instance ID
) u_cxl_d2h_resp_ras_dp_pipe (
    .clk                       ( core_clk                           ),
    .rst_n                     ( core_rst_n                         ),
    .en                        ( 1'b1                               ),
    .bypass                    ( 1'b0                               ),
    .stall                     ( 1'b0                               ),
    .stallout                  (                                    ),
    //---------- Inputs ---------------
    .valid_in                  ( ras_dp_valid_in_d2h_rsp[i]         ),
    .din                       ( datain_d2h_rsp[i]                  ),
    .din_prot                  ( b_txtl_rasdp.s_cxl_d2h_rsp_chk[i]  ),
    .halt_out                  (                                    ),
    //---------- Outputs --------------
    .valid_out                 (                                    ),
    .dout                      ( dataout_d2h_rsp[i]                 ),
    .dout_prot                 (                                    ),
    .halt_in                   ( 1'b0                               ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                               ),
    .ras_dp_err_inband_kbd_out ( err_multpl_d2h_rsp[i]              ),
    .ras_dp_err_log            ( ras_dp_err_log_d2h_rsp_arr[i]      )
    ,
    .ras_dp_err_inj            ( ras_dp_err_inj_d2h_rsp             )
);

  end
endgenerate

ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N ( D2H_RESP_NUM )
) u_d2h_rsp_ras_dp_err_mgr (
    .clk                ( core_clk                    ),
    .rst_n              ( core_rst_n                  ),
    .in_ras_dp_err_inj  ( ras_dp_err_inj_cache        ),
    .out_ras_dp_err_inj ( ras_dp_err_inj_d2h_rsp      ),
    .in_ras_dp_err_log  ( ras_dp_err_log_d2h_rsp_arr  ),
    .out_ras_dp_err_log ( ras_dp_err_log_d2h_rsp      )
);

DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_NUM       ( D2H_RESP_NUM  ),
    .CXL_CHMSG_WIDTH     ( D2H_RESP_SIZE ),
    .CXL_CHMSG_REG       ( 1'b1          )
) u_d2h_rsp_regout (
    .core_clk            ( core_clk                          ),
    .core_rst_n          ( core_rst_n                        ),
    .cxl_tl_chmsg_vld_i  ( '0                                ),
    .cxl_tl_chmsg_i      ( s_dataout_d2h_rsp                 ),
    .cxl_ll_chmsg_halt_i ( b_txtl_mst_dev.s_cxl_d2h_rsp_halt ),
    .cxl_ll_chmsg_o      ( b_txtl_mst_dev.s_cxl_d2h_rsp      ),
    .cxl_tl_chmsg_halt_o ( b_txtl_slv_dev.s_cxl_d2h_rsp_halt )
);

// -------------------------------------------------------------------------------------
// D2H Data Protection
// -------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------
// D2H HDR Protection
// -------------------------------------------------------------------------------------
parameter D2H_HDR_PROT_WD     = D2H_DHDR_CHK_SIZE;
parameter D2H_HDR_DATA_WD     = D2H_DHDR_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

parameter D2H_BE_PROT_WD      = D2H_DBE_CHK_SIZE;
parameter D2H_BE_DATA_WD      = D2H_DBE_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

parameter D2H_DATA_PROT_WD    = D2H_DDATA_CHK_SIZE;
parameter D2H_DATA_DATA_WD    = D2H_DDATA_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

parameter D2H_DATA_BE_WD      = D2H_DATA_DATA_WD + D2H_BE_DATA_WD;

logic [D2H_HDR_DATA_WD-1:0]                    datain_d2h_hdr [0:D2H_DATA_NUM-1];
logic [D2H_HDR_DATA_WD-1:0]                    dataout_d2h_hdr [0:D2H_DATA_NUM-1];
logic [D2H_DATA_NUM-1:0][D2H_DHDR_SIZE-1:0]    s_dataout_d2h_hdr;
logic [D2H_DATA_NUM-1:0][D2H_DATA_DATA_WD-1:0] s_dataout_d2h_data;
logic [D2H_DATA_NUM-1:0][D2H_DBE_SIZE-1:0]     s_dataout_d2h_be;
logic [D2H_DATA_NUM-1:0][D2H_DATA_BE_WD-1:0]   cxl_d2h_data_be_s;
logic [D2H_DATA_BE_WD-1:0]                     cxl_d2h_data_be_r [0:D2H_DATA_NUM-1];
logic [D2H_DATA_DATA_WD-1:0]                   cxl_d2h_data_r [0:D2H_DATA_NUM-1];
logic [D2H_BE_DATA_WD-1:0]                     cxl_d2h_be_r [0:D2H_DATA_NUM-1];
logic [D2H_HDR_DATA_WD-1:0]                    dataout_d2h_hdr_s [0:D2H_DATA_NUM-1];
logic [D2H_DATA_NUM-1:0]                       err_multpl_d2h_hdr;
logic [D2H_DATA_NUM-1:0]                       err_multpl_d2h_be;
logic [D2H_DATA_NUM-1:0]                       err_multpl_d2h_data;
logic [D2H_DATA_NUM-1:0]                       ras_dp_valid_in_d2h_hdr;
logic [D2H_DATA_NUM-1:0]                       ras_dp_valid_in_d2h_data;

ras_dp_err_log_t [D2H_DATA_NUM-1:0]            ras_dp_err_log_d2h_hdr_arr;
ras_dp_err_log_t [D2H_DATA_NUM-1:0]            ras_dp_err_log_d2h_be_arr;
ras_dp_err_log_t [D2H_DATA_NUM-1:0]            ras_dp_err_log_d2h_data_arr;
ras_dp_err_log_t                               ras_dp_err_log_d2h_hdr;
ras_dp_err_log_t                               ras_dp_err_log_d2h_be;
ras_dp_err_log_t                               ras_dp_err_log_d2h_data;
ras_dp_err_inj_t                               ras_dp_err_inj_d2h_hdr;
ras_dp_err_inj_t                               ras_dp_err_inj_d2h_be;
ras_dp_err_inj_t                               ras_dp_err_inj_d2h_data;

always_ff@(posedge core_clk or negedge core_rst_n) //poison interrupt for d2h data
begin //
  if(!core_rst_n) begin
      cxl_d2h_data_pis<=#TP 'b0;
  end
  else begin
      cxl_d2h_data_pis<=#TP (cxl_pcie_flit_mode)? '0 : ((|err_multpl_d2h_data) || (|err_multpl_d2h_be));
  end
end //always_ff

// First data/be checker should be enabled when data_vld is asserted
always_comb begin
  for(int d2h_idx = 0; d2h_idx < D2H_DDATA_NUM; d2h_idx++) begin
    ras_dp_valid_in_d2h_data[d2h_idx] = b_txtl_slv_dev.s_cxl_d2h_data_vld[d2h_idx];
  end
  for(int d2h_idx = D2H_DDATA_NUM; d2h_idx < D2H_DATA_NUM; d2h_idx++) begin
    ras_dp_valid_in_d2h_data[d2h_idx] = b_txtl_slv_dev.s_cxl_d2h_hdr[d2h_idx][0] && !cxl_pcie_flit_mode;
  end
end

generate
  for (genvar i = 0; i < D2H_DDATA_NUM; i++) begin : d2h_data_outputs
    assign b_txtl_mst_dev.s_cxl_d2h_data[i]  = cxl_d2h_data_r[i];
    assign b_txtl_mst_dev.s_cxl_d2h_be[i]    = cxl_d2h_be_r[i];
  end
endgenerate

generate
  for (genvar i = 0; i < D2H_DATA_NUM; i++) begin : d2h_hdr_checker

// RAS DP Checker Inputs
assign datain_d2h_hdr[i] = {b_txtl_slv_dev.s_cxl_d2h_hdr[i], {(D2H_HDR_DATA_WD - D2H_DHDR_SIZE){1'b0}}};
assign ras_dp_valid_in_d2h_hdr[i] = b_txtl_slv_dev.s_cxl_d2h_hdr[i][0];

// RAS DP Checker Output
assign s_dataout_d2h_hdr[i] = dataout_d2h_hdr[i][D2H_HDR_DATA_WD-1:(D2H_HDR_DATA_WD - D2H_DHDR_SIZE)];

// Combine each BE with its corresponding data before being delayed through ch_reg
assign cxl_d2h_data_be_s[i] = {s_dataout_d2h_be[i],  s_dataout_d2h_data[i]};
assign {cxl_d2h_be_r[i], cxl_d2h_data_r[i]} = cxl_d2h_data_be_r[i];
assign b_txtl_mst_dev.s_cxl_d2h_be_vld_n[i] = &cxl_d2h_be_r[i];

always_comb begin
    dataout_d2h_hdr[i] = dataout_d2h_hdr_s[i];

    if ((err_multpl_d2h_be[i] || err_multpl_d2h_data[i]) && b_txtl_mst_dev.s_cxl_d2h_hdr[i][0]) begin
        //set poison field in header in case of an uncorrectable error in be or data
      if (!cxl_pcie_flit_mode) begin
        dataout_d2h_hdr[i][D2H_HDR_DATA_WD - D2H_DHDR_SIZE + D2H_68B_POISON_BIT] = 1'b1;
      end
    end
end

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                         ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                         ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 0                         ), // Bus Protect Genenator is not enabled
    .BUS_PROTECT_CHK_EN      ( 1                         ), // Bus Protect Checker is enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE      ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE     ), // Protection range
    .TOTAL_WIDTH             ( D2H_HDR_DATA_WD           ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( D2H_HDR_PROT_WD           ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE    ), // Parity mode
    .PROT_CORRECT_EN         ( 1                         ), // Correction is enabled
    .RAS_DP_PROT_CHK_ID_BASE ( CXL_TX_D2H_HDR_RAS_ID + i )  // Checker instance ID
) u_cxl_d2h_hdr_ras_dp_pipe (
    .clk                       ( core_clk                          ),
    .rst_n                     ( core_rst_n                        ),
    .en                        ( 1'b1                              ),
    .bypass                    ( 1'b0                              ),
    .stall                     ( 1'b0                              ),
    .stallout                  (                                   ),
    //---------- Inputs ---------------
    .valid_in                  ( ras_dp_valid_in_d2h_hdr[i]        ),
    .din                       ( datain_d2h_hdr[i]                 ),
    .din_prot                  ( b_txtl_rasdp.s_cxl_d2h_hdr_chk[i] ),
    .halt_out                  (                                   ),
    //---------- Outputs --------------
    .valid_out                 (                                   ),
    .dout                      ( dataout_d2h_hdr_s[i]              ),
    .dout_prot                 (                                   ),
    .halt_in                   ( 1'b0                              ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                              ),
    .ras_dp_err_inband_kbd_out ( err_multpl_d2h_hdr[i]             ),
    .ras_dp_err_log            ( ras_dp_err_log_d2h_hdr_arr[i]     )
    ,
    .ras_dp_err_inj            ( ras_dp_err_inj_d2h_hdr            )
);

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                        ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                        ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 0                        ), // Bus Protect Genenator is not enabled
    .BUS_PROTECT_CHK_EN      ( 1                        ), // Bus Protect Checker is enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE     ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE    ), // Protection range
    .TOTAL_WIDTH             ( D2H_BE_DATA_WD           ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( D2H_BE_PROT_WD           ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE   ), // Parity mode
    .PROT_CORRECT_EN         ( 1                        ), // Correction is enabled
    .RAS_DP_PROT_CHK_ID_BASE ( CXL_TX_D2H_BE_RAS_ID + i )  // Checker instance ID
) u_cxl_d2h_be_ras_dp_pipe (
    .clk                       ( core_clk                           ),
    .rst_n                     ( core_rst_n                         ),
    .en                        ( 1'b1                               ),
    .bypass                    ( 1'b0                               ),
    .stall                     ( 1'b0                               ),
    .stallout                  (                                    ),
    //---------- Inputs ---------------
    .valid_in                  ( ras_dp_valid_in_d2h_data[i]        ),
    .din                       ( b_txtl_rasdp.s_cxl_d2h_be_arr[i]   ),
    .din_prot                  ( b_txtl_rasdp.s_cxl_d2h_be_chk[i]   ),
    .halt_out                  (                                    ),
    //---------- Outputs --------------
    .valid_out                 (                                    ),
    .dout                      ( s_dataout_d2h_be[i]                ),
    .dout_prot                 (                                    ),
    .halt_in                   ( 1'b0                               ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                               ),
    .ras_dp_err_inband_kbd_out ( err_multpl_d2h_be[i]               ),
    .ras_dp_err_log            ( ras_dp_err_log_d2h_be_arr[i]       )
    ,
    .ras_dp_err_inj            ( ras_dp_err_inj_d2h_be              )
);

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                          ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                          ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 0                          ), // Bus Protect Genenator is not enabled
    .BUS_PROTECT_CHK_EN      ( 1                          ), // Bus Protect Checker is enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE       ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE      ), // Protection range
    .TOTAL_WIDTH             ( D2H_DATA_DATA_WD           ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( D2H_DATA_PROT_WD           ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE     ), // Parity mode
    .PROT_CORRECT_EN         ( 1                          ), // Correction is enabled
    .RAS_DP_PROT_CHK_ID_BASE ( CXL_TX_D2H_DATA_RAS_ID + i )  // Checker instance ID
) u_cxl_d2h_data_ras_dp_pipe (
    .clk                       ( core_clk                           ),
    .rst_n                     ( core_rst_n                         ),
    .en                        ( 1'b1                               ),
    .bypass                    ( 1'b0                               ),
    .stall                     ( 1'b0                               ),
    .stallout                  (                                    ),
    //---------- Inputs ---------------
    .valid_in                  ( ras_dp_valid_in_d2h_data[i]        ),
    .din                       ( b_txtl_rasdp.s_cxl_d2h_data_arr[i] ),
    .din_prot                  ( b_txtl_rasdp.s_cxl_d2h_data_chk[i] ),
    .halt_out                  (                                    ),
    //---------- Outputs --------------
    .valid_out                 (                                    ),
    .dout                      ( s_dataout_d2h_data[i]              ),
    .dout_prot                 (                                    ),
    .halt_in                   ( 1'b0                               ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                               ),
    .ras_dp_err_inband_kbd_out ( err_multpl_d2h_data[i]             ),
    .ras_dp_err_log            ( ras_dp_err_log_d2h_data_arr[i]     )
    ,
    .ras_dp_err_inj            ( ras_dp_err_inj_d2h_data            )
);
  end
endgenerate

ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N ( D2H_DATA_NUM )
) u_d2h_hdr_ras_dp_err_mgr (
    .clk                ( core_clk                    ),
    .rst_n              ( core_rst_n                  ),
    .in_ras_dp_err_inj  ( ras_dp_err_inj_cache        ),
    .out_ras_dp_err_inj ( ras_dp_err_inj_d2h_hdr      ),
    .in_ras_dp_err_log  ( ras_dp_err_log_d2h_hdr_arr  ),
    .out_ras_dp_err_log ( ras_dp_err_log_d2h_hdr      )
);

ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N ( D2H_DATA_NUM )
) u_d2h_be_ras_dp_err_mgr (
    .clk                ( core_clk                    ),
    .rst_n              ( core_rst_n                  ),
    .in_ras_dp_err_inj  ( ras_dp_err_inj_cache        ),
    .out_ras_dp_err_inj ( ras_dp_err_inj_d2h_be       ),
    .in_ras_dp_err_log  ( ras_dp_err_log_d2h_be_arr   ),
    .out_ras_dp_err_log ( ras_dp_err_log_d2h_be       )
);

ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N ( D2H_DATA_NUM )
) u_d2h_data_ras_dp_err_mgr (
    .clk                ( core_clk                    ),
    .rst_n              ( core_rst_n                  ),
    .in_ras_dp_err_inj  ( ras_dp_err_inj_cache        ),
    .out_ras_dp_err_inj ( ras_dp_err_inj_d2h_data     ),
    .in_ras_dp_err_log  ( ras_dp_err_log_d2h_data_arr ),
    .out_ras_dp_err_log ( ras_dp_err_log_d2h_data     )
);

DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_NUM       ( D2H_DATA_NUM      ),
    .CXL_CHMSG_WIDTH     ( D2H_DHDR_SIZE     ),
    .CXL_CHMSG_REG       ( 1'b1          )
) u_d2h_hdr_regout (
    .core_clk            ( core_clk                          ),
    .core_rst_n          ( core_rst_n                        ),
    .cxl_tl_chmsg_vld_i  ( '0                                ),
    .cxl_tl_chmsg_i      ( s_dataout_d2h_hdr                 ),
    .cxl_ll_chmsg_halt_i ( b_txtl_mst_dev.s_cxl_d2h_hdr_halt ),
    .cxl_ll_chmsg_o      ( b_txtl_mst_dev.s_cxl_d2h_hdr      ),
    .cxl_tl_chmsg_halt_o ( b_txtl_slv_dev.s_cxl_d2h_hdr_halt )
);

DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_DATA      ( 1'b1             ),
    .CXL_CHMSG_NUM       ( D2H_DATA_NUM     ),
    .CXL_CHMSG_VLD_NUM   ( D2H_DDATA_NUM    ),
    .CXL_CHMSG_WIDTH     ( D2H_DATA_BE_WD   ),
    .CXL_CHMSG_REG       ( 1'b1             )
) u_d2h_data_regout (
    .core_clk            ( core_clk                           ),
    .core_rst_n          ( core_rst_n                         ),
    .cxl_tl_chmsg_i      ( cxl_d2h_data_be_s                  ),
    .cxl_tl_chmsg_vld_i  ( b_txtl_slv_dev.s_cxl_d2h_data_vld  ),
    .cxl_ll_chmsg_halt_i ( b_txtl_mst_dev.s_cxl_d2h_data_halt ),
    .cxl_ll_chmsg_o      ( cxl_d2h_data_be_r                  ),
    .cxl_ll_chmsg_vld_o  ( b_txtl_mst_dev.s_cxl_d2h_data_vld  ),
    .cxl_tl_chmsg_halt_o ( b_txtl_slv_dev.s_cxl_d2h_data_halt )
);
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// CXL.mem S2M Message Channel Interface between Transaction and Link Layer
// -------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------
// S2M NDR Protection
// -------------------------------------------------------------------------------------
parameter S2M_NDR_PROT_WD     = S2M_NDR_CHK_SIZE;
parameter S2M_NDR_DATA_WD     = S2M_NDR_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

logic [S2M_NDR_DATA_WD-1:0]               datain_s2m_ndr  [0:S2M_NDR_NUM-1];
logic [S2M_NDR_DATA_WD-1:0]               dataout_s2m_ndr [0:S2M_NDR_NUM-1];
logic [S2M_NDR_NUM-1:0][S2M_NDR_SIZE-1:0] s_dataout_s2m_ndr;
logic [S2M_NDR_NUM-1:0]                   err_multpl_s2m_ndr;
logic [S2M_NDR_NUM-1:0]                   ras_dp_valid_in_s2m_ndr;

ras_dp_err_log_t [S2M_NDR_NUM-1:0]        ras_dp_err_log_s2m_ndr_arr;
ras_dp_err_log_t                          ras_dp_err_log_s2m_ndr;
ras_dp_err_inj_t                          ras_dp_err_inj_s2m_ndr;

generate
  for (genvar i = 0; i < S2M_NDR_NUM; i++) begin : s2m_ndr_checker

assign datain_s2m_ndr[i] = {b_txtl_slv_dev.s_cxl_s2m_ndr[i], {(S2M_NDR_DATA_WD - S2M_NDR_SIZE){1'b0}}};
assign ras_dp_valid_in_s2m_ndr[i] = b_txtl_slv_dev.s_cxl_s2m_ndr[i][0];

assign s_dataout_s2m_ndr[i] = dataout_s2m_ndr[i][S2M_NDR_DATA_WD-1:(S2M_NDR_DATA_WD - S2M_NDR_SIZE)];

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                         ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                         ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 0                         ), // Bus Protect Genenator is not enabled
    .BUS_PROTECT_CHK_EN      ( 1                         ), // Bus Protect Checker is enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE      ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE     ), // Protection range
    .TOTAL_WIDTH             ( S2M_NDR_DATA_WD           ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( S2M_NDR_PROT_WD           ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE    ), // Parity mode
    .PROT_CORRECT_EN         ( 1                         ), // Correction is enabled
    .RAS_DP_PROT_CHK_ID_BASE ( CXL_TX_S2M_NDR_RAS_ID + i )  // Checker instance ID
) u_cxl_s2m_ndr_ras_dp_pipe (
    .clk                       ( core_clk                           ),
    .rst_n                     ( core_rst_n                         ),
    .en                        ( 1'b1                               ),
    .bypass                    ( 1'b0                               ),
    .stall                     ( 1'b0                               ),
    .stallout                  (                                    ),
    //---------- Inputs ---------------
    .valid_in                  ( ras_dp_valid_in_s2m_ndr[i]         ),
    .din                       ( datain_s2m_ndr[i]                  ),
    .din_prot                  ( b_txtl_rasdp.s_cxl_s2m_ndr_chk[i]  ),
    .halt_out                  (                                    ),
    //---------- Outputs --------------
    .valid_out                 (                                    ),
    .dout                      ( dataout_s2m_ndr[i]                 ),
    .dout_prot                 (                                    ),
    .halt_in                   ( 1'b0                               ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                               ),
    .ras_dp_err_inband_kbd_out ( err_multpl_s2m_ndr[i]              ),
    .ras_dp_err_log            ( ras_dp_err_log_s2m_ndr_arr[i]      )
    ,
    .ras_dp_err_inj            ( ras_dp_err_inj                     )
);
  end
endgenerate

ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N ( S2M_NDR_NUM )
) u_s2m_ndr_ras_dp_err_mgr (
    .clk                ( core_clk                    ),
    .rst_n              ( core_rst_n                  ),
    .in_ras_dp_err_inj  ( ras_dp_err_inj_mem          ),
    .out_ras_dp_err_inj ( ras_dp_err_inj_s2m_ndr      ),
    .in_ras_dp_err_log  ( ras_dp_err_log_s2m_ndr_arr  ),
    .out_ras_dp_err_log ( ras_dp_err_log_s2m_ndr      )
);

DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_NUM       ( S2M_NDR_NUM   ),
    .CXL_CHMSG_WIDTH     ( S2M_NDR_SIZE  ),
    .CXL_CHMSG_REG       ( 1'b1          )
) u_s2m_ndr_regout (
    .core_clk            ( core_clk                          ),
    .core_rst_n          ( core_rst_n                        ),
    .cxl_tl_chmsg_vld_i  ( '0                                ),
    .cxl_tl_chmsg_i      ( s_dataout_s2m_ndr                 ),
    .cxl_ll_chmsg_halt_i ( b_txtl_mst_dev.s_cxl_s2m_ndr_halt ),
    .cxl_ll_chmsg_o      ( b_txtl_mst_dev.s_cxl_s2m_ndr      ),
    .cxl_tl_chmsg_halt_o ( b_txtl_slv_dev.s_cxl_s2m_ndr_halt )
);


// -------------------------------------------------------------------------------------
// S2M Data and BE Protection
// -------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------
// S2M HDR Protection
// -------------------------------------------------------------------------------------
parameter S2M_HDR_PROT_WD     = S2M_DHDR_CHK_SIZE;
parameter S2M_HDR_DATA_WD     = S2M_DHDR_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

parameter S2M_DATA_PROT_WD    = S2M_DDATA_CHK_SIZE;
parameter S2M_DATA_DATA_WD    = S2M_DDATA_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

logic [S2M_HDR_DATA_WD-1:0]                     datain_s2m_hdr [0:S2M_DATA_NUM-1];
logic [S2M_HDR_DATA_WD-1:0]                     dataout_s2m_hdr [0:S2M_DATA_NUM-1];
logic [S2M_HDR_DATA_WD-1:0]                     dataout_s2m_hdr_s [0:S2M_DATA_NUM-1];
logic [S2M_DATA_NUM-1:0]                        err_multpl_s2m_hdr;
logic [S2M_DATA_NUM-1:0]                        err_multpl_s2m_data;
logic [S2M_DATA_NUM-1:0][S2M_DHDR_SIZE-1:0]     s_dataout_s2m_hdr;
logic [S2M_DATA_NUM-1:0][S2M_DATA_DATA_WD-1:0]  s_dataout_s2m_data;
logic [S2M_DATA_NUM-1:0]                        ras_dp_valid_in_s2m_hdr;
logic [S2M_DATA_NUM-1:0]                        ras_dp_valid_in_s2m_data;

ras_dp_err_log_t [S2M_DATA_NUM-1:0]             ras_dp_err_log_s2m_hdr_arr;
ras_dp_err_log_t [S2M_DATA_NUM-1:0]             ras_dp_err_log_s2m_data_arr;
ras_dp_err_log_t                                ras_dp_err_log_s2m_hdr;
ras_dp_err_log_t                                ras_dp_err_log_s2m_data;
ras_dp_err_inj_t                                ras_dp_err_inj_s2m_hdr;
ras_dp_err_inj_t                                ras_dp_err_inj_s2m_data;

// First data checker should be enabled when data_vld is asserted
always_comb begin
  for(int s2m_idx = 0; s2m_idx < S2M_DDATA_NUM; s2m_idx++) begin
    ras_dp_valid_in_s2m_data[s2m_idx] = b_txtl_slv_dev.s_cxl_s2m_data_vld[s2m_idx] ;
  end
  for(int s2m_idx = S2M_DDATA_NUM; s2m_idx < S2M_DATA_NUM; s2m_idx++) begin
    ras_dp_valid_in_s2m_data[s2m_idx] = b_txtl_slv_dev.s_cxl_s2m_hdr[s2m_idx][0] && !cxl_pcie_flit_mode;
  end
end

always_ff@(posedge core_clk or negedge core_rst_n) //poison interrupt for s2m data
begin //
  if(!core_rst_n) begin
      cxl_s2m_data_pis<=#TP 'b0;
  end
  else begin
      cxl_s2m_data_pis<=#TP (cxl_pcie_flit_mode)? '0 : (|err_multpl_s2m_data); 
  end
end //always_ff

generate
  for (genvar i = 0; i < S2M_DATA_NUM; i++) begin : s2m_hdr_checker

assign datain_s2m_hdr[i] = {b_txtl_slv_dev.s_cxl_s2m_hdr[i], {(S2M_HDR_DATA_WD - S2M_DHDR_SIZE){1'b0}}};
assign ras_dp_valid_in_s2m_hdr[i] = b_txtl_slv_dev.s_cxl_s2m_hdr[i][0];

assign s_dataout_s2m_hdr[i] = dataout_s2m_hdr[i][S2M_HDR_DATA_WD-1:(S2M_HDR_DATA_WD - S2M_DHDR_SIZE)];

always_comb begin
    dataout_s2m_hdr[i] = dataout_s2m_hdr_s[i];

    if (err_multpl_s2m_data[i] && b_txtl_mst_dev.s_cxl_s2m_hdr[i][0]) begin
        //set poison field in header in case of an uncorrectable error in data
      if (!cxl_pcie_flit_mode) begin
        dataout_s2m_hdr[i][S2M_HDR_DATA_WD - S2M_DHDR_SIZE + S2M_68B_POISON_BIT] = 1'b1;
      end
    end
end

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                         ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                         ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 0                         ), // Bus Protect Genenator is not enabled
    .BUS_PROTECT_CHK_EN      ( 1                         ), // Bus Protect Checker is enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE      ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE     ), // Protection range
    .TOTAL_WIDTH             ( S2M_HDR_DATA_WD           ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( S2M_HDR_PROT_WD           ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE    ), // Parity mode
    .PROT_CORRECT_EN         ( 1                         ), // Correction is enabled
    .RAS_DP_PROT_CHK_ID_BASE ( CXL_TX_S2M_HDR_RAS_ID + i )  // Checker instance ID
) u_cxl_s2m_hdr_ras_dp_pipe (
    .clk                       ( core_clk                           ),
    .rst_n                     ( core_rst_n                         ),
    .en                        ( 1'b1                               ),
    .bypass                    ( 1'b0                               ),
    .stall                     ( 1'b0                               ),
    .stallout                  (                                    ),
    //---------- Inputs ---------------
    .valid_in                  ( ras_dp_valid_in_s2m_hdr[i]         ),
    .din                       ( datain_s2m_hdr[i]                  ),
    .din_prot                  ( b_txtl_rasdp.s_cxl_s2m_hdr_chk[i]  ),
    .halt_out                  (                                    ),
    //---------- Outputs --------------
    .valid_out                 (                                    ),
    .dout                      ( dataout_s2m_hdr_s[i]               ),
    .dout_prot                 (                                    ),
    .halt_in                   ( 1'b0                               ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                               ),
    .ras_dp_err_inband_kbd_out ( err_multpl_s2m_hdr[i]              ),
    .ras_dp_err_log            ( ras_dp_err_log_s2m_hdr_arr[i]      )
    ,
    .ras_dp_err_inj            ( ras_dp_err_inj_s2m_hdr             )
);

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                          ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                          ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 0                          ), // Bus Protect Genenator is not enabled
    .BUS_PROTECT_CHK_EN      ( 1                          ), // Bus Protect Checker is enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE       ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE      ), // Protection range
    .TOTAL_WIDTH             ( S2M_DATA_DATA_WD           ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( S2M_DATA_PROT_WD           ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE     ), // Parity mode
    .PROT_CORRECT_EN         ( 1                          ), // Correction is enabled
    .RAS_DP_PROT_CHK_ID_BASE ( CXL_TX_S2M_DATA_RAS_ID + i )  // Checker instance ID
) u_cxl_s2m_data_ras_dp_pipe (
    .clk                       ( core_clk                           ),
    .rst_n                     ( core_rst_n                         ),
    .en                        ( 1'b1                               ),
    .bypass                    ( 1'b0                               ),
    .stall                     ( 1'b0                               ),
    .stallout                  (                                    ),
    //---------- Inputs ---------------
    .valid_in                  ( ras_dp_valid_in_s2m_data[i]        ),
    .din                       ( b_txtl_rasdp.s_cxl_s2m_data_arr[i] ),
    .din_prot                  ( b_txtl_rasdp.s_cxl_s2m_data_chk[i] ),
    .halt_out                  (                                    ),
    //---------- Outputs --------------
    .valid_out                 (                                    ),
    .dout                      ( s_dataout_s2m_data[i]              ),
    .dout_prot                 (                                    ),
    .halt_in                   ( 1'b0                               ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                               ),
    .ras_dp_err_inband_kbd_out ( err_multpl_s2m_data[i]             ),
    .ras_dp_err_log            ( ras_dp_err_log_s2m_data_arr[i]     )
    ,
    .ras_dp_err_inj            ( ras_dp_err_inj_s2m_data            )
);

  end
endgenerate

ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N ( S2M_DATA_NUM )
) u_s2m_hdr_ras_dp_err_mgr (
    .clk                ( core_clk                    ),
    .rst_n              ( core_rst_n                  ),
    .in_ras_dp_err_inj  ( ras_dp_err_inj_mem          ),
    .out_ras_dp_err_inj ( ras_dp_err_inj_s2m_hdr      ),
    .in_ras_dp_err_log  ( ras_dp_err_log_s2m_hdr_arr  ),
    .out_ras_dp_err_log ( ras_dp_err_log_s2m_hdr      )
);

ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N ( S2M_DATA_NUM )
) u_s2m_data_ras_dp_err_mgr (
    .clk                ( core_clk                    ),
    .rst_n              ( core_rst_n                  ),
    .in_ras_dp_err_inj  ( ras_dp_err_inj_mem          ),
    .out_ras_dp_err_inj ( ras_dp_err_inj_s2m_data     ),
    .in_ras_dp_err_log  ( ras_dp_err_log_s2m_data_arr ),
    .out_ras_dp_err_log ( ras_dp_err_log_s2m_data     )
);

DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_NUM       ( S2M_DATA_NUM  ),
    .CXL_CHMSG_WIDTH     ( S2M_DHDR_SIZE ),
    .CXL_CHMSG_REG       ( 1'b1          )
) u_s2m_hdr_regout (
    .core_clk            ( core_clk                          ),
    .core_rst_n          ( core_rst_n                        ),
    .cxl_tl_chmsg_vld_i  ( '0                                ),
    .cxl_tl_chmsg_i      ( s_dataout_s2m_hdr                 ),
    .cxl_ll_chmsg_halt_i ( b_txtl_mst_dev.s_cxl_s2m_hdr_halt ),
    .cxl_ll_chmsg_o      ( b_txtl_mst_dev.s_cxl_s2m_hdr      ),
    .cxl_tl_chmsg_halt_o ( b_txtl_slv_dev.s_cxl_s2m_hdr_halt )
);

DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_DATA      ( 1'b1             ),
    .CXL_CHMSG_NUM       ( S2M_DDATA_NUM    ),
    .CXL_CHMSG_VLD_NUM   ( S2M_DDATA_NUM    ),
    .CXL_CHMSG_WIDTH     ( S2M_DATA_DATA_WD ),
    .CXL_CHMSG_REG       ( 1'b1             )
) u_s2m_data_regout (
    .core_clk            ( core_clk                              ),
    .core_rst_n          ( core_rst_n                            ),
    .cxl_tl_chmsg_i      ( s_dataout_s2m_data[S2M_DDATA_NUM-1:0] ),
    .cxl_tl_chmsg_vld_i  ( b_txtl_slv_dev.s_cxl_s2m_data_vld     ),
    .cxl_ll_chmsg_halt_i ( b_txtl_mst_dev.s_cxl_s2m_data_halt    ),
    .cxl_ll_chmsg_o      ( b_txtl_mst_dev.s_cxl_s2m_data         ),
    .cxl_ll_chmsg_vld_o  ( b_txtl_mst_dev.s_cxl_s2m_data_vld     ),
    .cxl_tl_chmsg_halt_o ( b_txtl_slv_dev.s_cxl_s2m_data_halt    )
);

// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// S2M BI SNP Protection
// -------------------------------------------------------------------------------------

parameter S2M_BI_SNP_PROT_WD     = S2M_BI_SNP_CHK_SIZE;
parameter S2M_BI_SNP_DATA_WD     = S2M_BI_SNP_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

logic [S2M_BI_SNP_DATA_WD-1:0]                   datain_s2m_bi_snp  [0:S2M_BI_SNP_NUM-1];
logic [S2M_BI_SNP_DATA_WD-1:0]                   dataout_s2m_bi_snp [0:S2M_BI_SNP_NUM-1];
logic [S2M_BI_SNP_NUM-1:0][S2M_BI_SNP_SIZE-1:0]  s_dataout_s2m_bi_snp;
logic [S2M_BI_SNP_NUM-1:0]                       err_multpl_s2m_bi_snp;
logic [S2M_BI_SNP_NUM-1:0]                       ras_dp_valid_in_s2m_bi_snp;

ras_dp_err_log_t [S2M_BI_SNP_NUM-1:0]            ras_dp_err_log_s2m_bi_snp_arr;
ras_dp_err_log_t                                 ras_dp_err_log_s2m_bi_snp;
ras_dp_err_inj_t                                 ras_dp_err_inj_s2m_bi_snp;

generate
  for (genvar i = 0; i < S2M_BI_SNP_NUM; i++) begin : s2m_bi_snp_checker

assign datain_s2m_bi_snp[i] = {b_txtl_slv_dev.s_cxl_s2m_bi_snp[i], {(S2M_BI_SNP_DATA_WD - S2M_BI_SNP_SIZE){1'b0}}};
assign ras_dp_valid_in_s2m_bi_snp[i] = b_txtl_slv_dev.s_cxl_s2m_bi_snp[i][0];

assign s_dataout_s2m_bi_snp[i] = dataout_s2m_bi_snp[i][S2M_BI_SNP_DATA_WD-1:(S2M_BI_SNP_DATA_WD - S2M_BI_SNP_SIZE)];

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                            ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                            ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 0                            ), // Bus Protect Genenator is not enabled
    .BUS_PROTECT_CHK_EN      ( 1                            ), // Bus Protect Checker is enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE         ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE        ), // Protection range
    .TOTAL_WIDTH             ( S2M_BI_SNP_DATA_WD           ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( S2M_BI_SNP_PROT_WD           ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE       ), // Parity mode
    .PROT_CORRECT_EN         ( 1                            ), // Correction is enabled
    .RAS_DP_PROT_CHK_ID_BASE ( CXL_TX_S2M_BI_SNP_RAS_ID + i )  // Checker instance ID
) u_cxl_s2m_bi_snp_ras_dp_pipe (
    .clk                       ( core_clk                              ),
    .rst_n                     ( core_rst_n                            ),
    .en                        ( 1'b1                                  ),
    .bypass                    ( 1'b0                                  ),
    .stall                     ( 1'b0                                  ),
    .stallout                  (                                       ),
    //---------- Inputs ---------------
    .valid_in                  ( ras_dp_valid_in_s2m_bi_snp[i]         ),
    .din                       ( datain_s2m_bi_snp[i]                  ),
    .din_prot                  ( b_txtl_rasdp.s_cxl_s2m_bi_snp_chk[i]  ),
    .halt_out                  (                                       ),
    //---------- Outputs --------------
    .valid_out                 (                                       ),
    .dout                      ( dataout_s2m_bi_snp[i]                 ),
    .dout_prot                 (                                       ),
    .halt_in                   ( 1'b0                                  ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                  ),
    .ras_dp_err_inband_kbd_out ( err_multpl_s2m_bi_snp[i]              ),
    .ras_dp_err_log            ( ras_dp_err_log_s2m_bi_snp_arr[i]      )
    ,
    .ras_dp_err_inj            ( ras_dp_err_inj_s2m_bi_snp             )
);

  end
endgenerate

ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N ( S2M_BI_SNP_NUM )
) u_s2m_bi_snp_ras_dp_err_mgr (
    .clk                ( core_clk                      ),
    .rst_n              ( core_rst_n                    ),
    .in_ras_dp_err_inj  ( ras_dp_err_inj_mem            ),
    .out_ras_dp_err_inj ( ras_dp_err_inj_s2m_bi_snp     ),
    .in_ras_dp_err_log  ( ras_dp_err_log_s2m_bi_snp_arr ),
    .out_ras_dp_err_log ( ras_dp_err_log_s2m_bi_snp     )
);

DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_NUM       ( S2M_BI_SNP_NUM   ),
    .CXL_CHMSG_WIDTH     ( S2M_BI_SNP_SIZE  ),
    .CXL_CHMSG_REG       ( 1'b1             )
) u_s2m_bi_snp_regout (
    .core_clk            ( core_clk                             ),
    .core_rst_n          ( core_rst_n                           ),
    .cxl_tl_chmsg_vld_i  ( '0                                   ),
    .cxl_tl_chmsg_i      ( s_dataout_s2m_bi_snp                 ),
    .cxl_ll_chmsg_halt_i ( b_txtl_mst_dev.s_cxl_s2m_bi_snp_halt ),
    .cxl_ll_chmsg_o      ( b_txtl_mst_dev.s_cxl_s2m_bi_snp      ),
    .cxl_tl_chmsg_halt_o ( b_txtl_slv_dev.s_cxl_s2m_bi_snp_halt )
);



// -------------------------------------------------------------------------------------
// M2S BI RSP Protection
// -------------------------------------------------------------------------------------

parameter M2S_BI_RSP_PROT_WD     = M2S_BI_RSP_CHK_SIZE;
parameter M2S_BI_RSP_DATA_WD     = M2S_BI_RSP_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

logic [M2S_BI_RSP_DATA_WD-1:0]                  datain_m2s_bi_rsp  [0:M2S_BI_RSP_NUM-1];
logic [M2S_BI_RSP_DATA_WD-1:0]                  dataout_m2s_bi_rsp [0:M2S_BI_RSP_NUM-1];
logic [M2S_BI_RSP_NUM-1:0]                      err_multpl_m2s_bi_rsp;
logic [M2S_BI_RSP_NUM-1:0][M2S_BI_RSP_SIZE-1:0] s_dataout_m2s_bi_rsp;
logic [M2S_BI_RSP_NUM-1:0]                      ras_dp_valid_in_m2s_bi_rsp;

ras_dp_err_log_t [M2S_BI_RSP_NUM-1:0]           ras_dp_err_log_m2s_bi_rsp_arr;
ras_dp_err_log_t                                ras_dp_err_log_m2s_bi_rsp;
ras_dp_err_inj_t                                ras_dp_err_inj_m2s_bi_rsp;

generate
  for (genvar i = 0; i < M2S_BI_RSP_NUM; i++) begin : m2s_bi_rsp_checker

assign datain_m2s_bi_rsp[i] = {b_txtl_slv_host.s_cxl_m2s_bi_rsp[i], {(M2S_BI_RSP_DATA_WD - M2S_BI_RSP_SIZE){1'b0}}};
assign ras_dp_valid_in_m2s_bi_rsp[i] = b_txtl_slv_host.s_cxl_m2s_bi_rsp[i][0];

assign s_dataout_m2s_bi_rsp[i] = dataout_m2s_bi_rsp[i][M2S_BI_RSP_DATA_WD-1:(M2S_BI_RSP_DATA_WD - M2S_BI_RSP_SIZE)];

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                            ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                            ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 0                            ), // Bus Protect Genenator is not enabled
    .BUS_PROTECT_CHK_EN      ( 1                            ), // Bus Protect Checker is enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE         ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE        ), // Protection range: 8 bits per 64-bits
    .TOTAL_WIDTH             ( M2S_BI_RSP_DATA_WD           ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( M2S_BI_RSP_PROT_WD           ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE       ), // Parity mode: N/A
    .PROT_CORRECT_EN         ( 1                            ), // Correction is enabled
    .RAS_DP_PROT_CHK_ID_BASE ( CXL_TX_M2S_BI_RSP_RAS_ID + i )  // Checker instance ID
) u_cxl_s2m_bi_rsp_ras_dp_pipe (
    .clk                       ( core_clk                               ),
    .rst_n                     ( core_rst_n                             ),
    .en                        ( 1'b1                                   ),
    .bypass                    ( 1'b0                                   ),
    .stall                     ( 1'b0                                   ),
    .stallout                  (                                        ),
    //---------- Inputs ---------------
    .valid_in                  ( ras_dp_valid_in_m2s_bi_rsp[i]          ),
    .din                       ( datain_m2s_bi_rsp[i]                   ),
    .din_prot                  ( b_txtl_rasdp.s_cxl_m2s_bi_rsp_chk[i]   ),
    .halt_out                  (                                        ),
    //---------- Outputs --------------
    .valid_out                 (                                        ),
    .dout                      ( dataout_m2s_bi_rsp[i]                  ),
    .dout_prot                 (                                        ),
    .halt_in                   ( 1'b0                                   ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                   ),
    .ras_dp_err_inband_kbd_out ( err_multpl_m2s_bi_rsp[i]               ),
    .ras_dp_err_log            ( ras_dp_err_log_m2s_bi_rsp_arr[i]       )
    ,
    .ras_dp_err_inj            ( ras_dp_err_inj_m2s_bi_rsp              )
);
  end
endgenerate

ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N ( M2S_BI_RSP_NUM )
) u_m2s_bi_rsp_ras_dp_err_mgr (
    .clk                ( core_clk                      ),
    .rst_n              ( core_rst_n                    ),
    .in_ras_dp_err_inj  ( ras_dp_err_inj_mem            ),
    .out_ras_dp_err_inj ( ras_dp_err_inj_m2s_bi_rsp     ),
    .in_ras_dp_err_log  ( ras_dp_err_log_m2s_bi_rsp_arr ),
    .out_ras_dp_err_log ( ras_dp_err_log_m2s_bi_rsp     )
);

DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_NUM       ( M2S_BI_RSP_NUM   ),
    .CXL_CHMSG_WIDTH     ( M2S_BI_RSP_SIZE  ),
    .CXL_CHMSG_REG       ( 1'b1             )
) u_m2s_bi_rsp_regout (
    .core_clk            ( core_clk                              ),
    .core_rst_n          ( core_rst_n                            ),
    .cxl_tl_chmsg_vld_i  ( '0                                    ),
    .cxl_tl_chmsg_i      ( s_dataout_m2s_bi_rsp                  ),
    .cxl_ll_chmsg_halt_i ( b_txtl_mst_host.s_cxl_m2s_bi_rsp_halt ),
    .cxl_ll_chmsg_o      ( b_txtl_mst_host.s_cxl_m2s_bi_rsp      ),
    .cxl_tl_chmsg_halt_o ( b_txtl_slv_host.s_cxl_m2s_bi_rsp_halt )
);


// -------------------------------------------------------------------------------------
// Grouping Cache Error Logs
// -------------------------------------------------------------------------------------

assign ras_dp_err_log_cache_arr = {
ras_dp_err_log_h2d_req,
ras_dp_err_log_h2d_rsp,
ras_dp_err_log_h2d_hdr,
ras_dp_err_log_h2d_data
  ,
ras_dp_err_log_d2h_req,
ras_dp_err_log_d2h_rsp,
ras_dp_err_log_d2h_hdr,
ras_dp_err_log_d2h_be,
ras_dp_err_log_d2h_data
};

ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N ( CXL_CACHE_ERR_LOG_NUM )
) u_cache_ras_dp_err_mgr (
    .clk                ( core_clk                      ),
    .rst_n              ( core_rst_n                    ),
    .in_ras_dp_err_inj  ( ras_dp_err_inj_cache_mem      ),
    .out_ras_dp_err_inj ( ras_dp_err_inj_cache          ),
    .in_ras_dp_err_log  ( ras_dp_err_log_cache_arr      ),
    .out_ras_dp_err_log ( ras_dp_err_log_cache          )
);


// -------------------------------------------------------------------------------------
// Grouping Mem Error Logs
// -------------------------------------------------------------------------------------

assign ras_dp_err_log_mem_arr = {
ras_dp_err_log_m2s_req,
ras_dp_err_log_m2s_hdr,
ras_dp_err_log_m2s_be,
ras_dp_err_log_m2s_data
  ,
ras_dp_err_log_s2m_ndr,
ras_dp_err_log_s2m_hdr,
ras_dp_err_log_s2m_data
,
ras_dp_err_log_s2m_bi_snp
,
ras_dp_err_log_m2s_bi_rsp
};

ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N ( CXL_MEM_ERR_LOG_NUM )
) u_mem_ras_dp_err_mgr (
    .clk                ( core_clk                      ),
    .rst_n              ( core_rst_n                    ),
    .in_ras_dp_err_inj  ( ras_dp_err_inj_cache_mem      ),
    .out_ras_dp_err_inj ( ras_dp_err_inj_mem            ),
    .in_ras_dp_err_log  ( ras_dp_err_log_mem_arr        ),
    .out_ras_dp_err_log ( ras_dp_err_log_mem            )
);

// -------------------------------------------------------------------------------------
// Grouping Cache/Mem Error Logs
// -------------------------------------------------------------------------------------
assign ras_dp_err_log_cache_mem = {
ras_dp_err_log_cache
,
ras_dp_err_log_mem
};

ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N ( CXL_CACHE_MEM_ERR_LOG_NUM )
) u_cache_mem_ras_dp_err_mgr (
    .clk                ( core_clk                      ),
    .rst_n              ( core_rst_n                    ),
    .in_ras_dp_err_inj  ( ras_dp_err_inj                ),
    .out_ras_dp_err_inj ( ras_dp_err_inj_cache_mem      ),
    .in_ras_dp_err_log  ( ras_dp_err_log_cache_mem      ),
    .out_ras_dp_err_log ( ras_dp_err_log                )
);

// -------------------------------------------------------------------------------------
// RAS Statistics - Uncorrectable Errors
// -------------------------------------------------------------------------------------
logic [CXL_TX_TL_RAS_UNCORR_NUM-1:0]    ras_dp_uncorr_err_nxt;  // RAS Statistics - Uncorrectable error detected

delay_n
 #(
    .N     (1),
    .WD    (CXL_TX_TL_RAS_UNCORR_NUM)
) u_delay_ras_stat (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .din   (ras_dp_uncorr_err_nxt),
    .dout  (ras_dp_uncorr_err)
);

always_comb begin
   ras_dp_uncorr_err_nxt = '0;
    ras_dp_uncorr_err_nxt[6] = ras_dp_uncorr_err_nxt[6] | (cfg_dev_mode ? (|err_multpl_h2d_req) : '0);
    ras_dp_uncorr_err_nxt[5] = ras_dp_uncorr_err_nxt[5] | (cfg_dev_mode ? (|err_multpl_h2d_rsp) : '0);
    // for 256B flit mode Poison is not supported, so in case of an uncorrectable error in data, This error will be assigned to the ras uncorrectable error register
    ras_dp_uncorr_err_nxt[4] = ras_dp_uncorr_err_nxt[4] | (cfg_dev_mode ? ( (|err_multpl_h2d_hdr) | ((cxl_pcie_flit_mode)? (|err_multpl_h2d_data) : 1'b0) ) : 1'b0);

    ras_dp_uncorr_err_nxt[2] = ras_dp_uncorr_err_nxt[2] | (cfg_dev_mode ? (|err_multpl_m2s_req) : '0);
    ras_dp_uncorr_err_nxt[0] = ras_dp_uncorr_err_nxt[0] | (cfg_dev_mode ? ( (|err_multpl_m2s_hdr) | ((cxl_pcie_flit_mode)? (|err_multpl_m2s_data) | (|err_multpl_m2s_be) : 1'b0) ) : 1'b0);

    ras_dp_uncorr_err_nxt[6] = ras_dp_uncorr_err_nxt[6] | (!cfg_dev_mode ? (|err_multpl_d2h_req) : '0);
    ras_dp_uncorr_err_nxt[5] = ras_dp_uncorr_err_nxt[5] | (!cfg_dev_mode ? (|err_multpl_d2h_rsp) : '0);
    ras_dp_uncorr_err_nxt[4] = ras_dp_uncorr_err_nxt[4] | (!cfg_dev_mode ? ( (|err_multpl_d2h_hdr) | ((cxl_pcie_flit_mode)? (|err_multpl_d2h_data) | (|err_multpl_d2h_be) : 1'b0) ) : 1'b0);

    ras_dp_uncorr_err_nxt[1] = ras_dp_uncorr_err_nxt[1] | (!cfg_dev_mode ? (|err_multpl_s2m_ndr) : '0);
    ras_dp_uncorr_err_nxt[0] = ras_dp_uncorr_err_nxt[0] | (!cfg_dev_mode ? ( (|err_multpl_s2m_hdr) | ((cxl_pcie_flit_mode)? (|err_multpl_s2m_data) : 1'b0) ) : 1'b0);

    ras_dp_uncorr_err_nxt[2] = ras_dp_uncorr_err_nxt[2] | (!cfg_dev_mode ? (|err_multpl_s2m_bi_snp) : '0);

    ras_dp_uncorr_err_nxt[1] = ras_dp_uncorr_err_nxt[1] | (cfg_dev_mode ? (err_multpl_m2s_bi_rsp) : '0);
end

// -------------------------------------------------------------------------------------
always_comb begin
    b_txtl_mst_host.s_cxl_cache_enable = 1'b0 || b_txtl_slv_host.s_cxl_cache_enable;
    b_txtl_mst_host.s_cxl_mem_enable   = 1'b0 || b_txtl_slv_host.s_cxl_mem_enable;
end

always_comb begin
    b_txtl_mst_dev.s_cxl_cache_enable = 1'b0 || b_txtl_slv_dev.s_cxl_cache_enable;
    b_txtl_mst_dev.s_cxl_mem_enable   = 1'b0 || b_txtl_slv_dev.s_cxl_mem_enable;
end
// -------------------------------------------------------------------------------------

endmodule : DWC_cxl_mem_cache_tx_rasdp_wr_ms
