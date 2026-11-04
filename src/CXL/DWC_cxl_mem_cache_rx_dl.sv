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
// ---   $Revision: #15 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_rx_dl.sv#15 $
// ----------------------------------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------------------------------
// --- Design Ware Core's CXL Receiver Data Link Layer
// --- Features : 
// ---     CRC check for flit validation.
// ---     Extract flit header information.
// ---     Manage credit communication with transmit link layer.
// ---     Unpacking of the protocol flits and pass them to receiver transaction layer.
// ---     Decode link layer control flits and pass information to transmit link layer.
// ----------------------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Spif/pkg/spif_pkg.svh"

module DWC_cxl_mem_cache_rx_dl
   import DWC_cxl_pkg::*;
   import spif_pkg::protocol_cfg_t;
   import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
   import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
#(
    parameter TP = `TP
) (
    input                                           core_clk              ,  // Core Clk input
    input                                           core_rst_n            ,
    input protocol_cfg_t                            cxl_protocol_cfg      ,
    DWC_cxl_cdmregs_if.master_rx_mp                 b_cdm                 ,  // RX CDM interface
    DWC_cxl_arb_llctrl_if.slave_rx_mp               b_arb_llctrl          ,  // ARB/MUX RX link layer control Interface
    DWC_cxl_rxdl_llctrl_if.master_mp                b_rxdl_llctrl         ,  // Receiver link layer interface to link layer control
    input                                           cxl_pl_block_dl_init  ,  // Disable Link Layer initialization

    input ras_dp_err_inj_t                          ras_dp_err_inj , // RASDP Error Injection control
    output ras_dp_err_log_t                         ras_dp_err_log , // RASDP Error Log
    output [CXL_RX_LL_RAS_UNCORR_NUM-1:0]           ras_dp_uncorr_err, // RASDP Uncorr Error to trigger Viral
    DWC_cxl_rxtl_llctrl_if.master_mp                b_rxtl_llctrl                , // Transaction Layer Interface
    input                  [CACHE_REQ_VALID_WD-1:0] cxl_rx_tl_cache_req_valid    , // Number of CXL.cache Request messages offloaded from Receive Queue
    input                  [CACHE_RSP_VALID_WD-1:0] cxl_rx_tl_cache_rsp_valid    , // Number of CXL.cache Response messages offloaded from Receive Queue
    input [HD_DDATA_NUM - 1: 0]                     cxl_rx_tl_cache_data_valid   , // Number of CXL.cache Data messages offloaded from Receive Queue
    input                  [MEM_NDR_VALID_WD-1:0]   cxl_rx_tl_mem_ndr_valid      , // Number of CXL.mem Request/Response messages offloaded from Receive Queue
    input [MS_SM_DDATA_NUM - 1: 0]                  cxl_rx_tl_mem_data_valid     , // Number of CXL.mem Data messages offloaded from Receive Queue
    input                  [MEM_BI_VALID_WD-1:0]    cxl_rx_tl_mem_bi_valid       , // Number of CXL.mem BI Snoop/Response messages offloaded from Receive Queue
    output                                          cxl_rx_mdh_error,                      // Multi-Data Header received when MDH is disabled
    output                                          cxl_rx_crc_error,                      // Received Flit CRC error
    output [CXL_DATA_WD-1:0]                        cxl_rx_flit_data,                      // Received Data Flit
    output [CXL_DATA_PROT_WD-1:0]                   cxl_rx_flit_data_chk,                  // Receiver Data Parity
    output                                          cxl_ras_cache_poison,                  // CXL.cache Poisoned Data Received
    output                                          cxl_ras_mem_poison,                    // CXL.mem Poisoned Data Received
    output                                          cxl_rx_crc_error_hit,                  // Crc error thresold hit 
    output                                          cxl_rx_rsvd_enc_error,                 // Slot Reserved Fields Encoding Violation 
    output                                          cxl_rx_dl_idle                         // CXL RX Data Link Layer Idle
);



//Internal Connections for wrapper module and the other modules
logic [CXL_DATA_WD-1:0]             cxl_flit_data_256B_s;         // RX 256B  Flit Data to unpacker
logic [CXL_DATA_WD-1:0]             cxl_flit_data_68B_s;          // RX 68B  Flit Data to unpacker

//------------------------------------------------------------

// Net Declarations
logic                           cxl_rx_crc_flit_valid       ; // CXL Flit Valid after CRC check
logic [CXL_DATA_WD-1:0]         cxl_rx_crc_flit_data        ; // CXL Flit Data  after CRC check
logic [CXL_DATA_WD-1:0]         cxl_rx_crc_flit_data_s      ; // CXL Flit Data after CRC check (To Rxlink_ctrl after RAS checker - 256B - Multistream)
logic                           cxl_rx_crc_err_s            ; // CRC error received
logic [CXL_DATA_WD-1:0]         cxl_rx_unpack_flit_data     ; // RX Unpacker Flit Data
logic [CXL_DATA_PROT_WD-1:0]    cxl_rx_unpack_flit_data_chk ; // RX Unpacker Flit Data RASDP Protection
logic                           cxl_rx_unpack_flit_prot_en  ; // RX Unpacker Protocol Flit Valid
logic                           cxl_rx_unpack_flit_error    ; // RX Unpacker Protocol Flit CRC Error
logic                           chi_rx_unpack_flit_prot_en  ; // RX Unpacker Protocol Flit Valid
logic                           chi_rx_all_data_flit_s      ; // RX Unpacker All Data Flit Indication
logic                           chi_rx_rsvd_enc_error       ; // RX Unpacker Reserved Encoding Violation
logic [1:0]                     chi_rx_poisoned_data_s      ; // RX Unpacker Poison Data bits

logic                           cxl_rx_llctrl_flit_ctrl_en  ; // RX LLCTRL Control Flit Valid
logic                           cxl_rx_llctrl_flit_prot_en  ; // RX LLCTRL Protocol Flit Valid
logic                           cxl_rx_llctrl_flit_prot_adf ; // RX LLCTRL Protocol Flit ADF
logic [127:0]                   cxl_rx_llctrl_flit_data     ; // RX LLCTRL Flit Data
logic [LLCTRL_FLIT_WD-1:0]      cxl_rx_llctrl_flit_data_s   ; // RX LLCTRL Flit Data (To Rxlink_ctrl after RAS checker - 256B - Multistream)
logic [15:0]                    cxl_rx_crd_flit_data        ; // RX CRD Flit Data

logic                           cxl_256b_rx_late_poison_s           ; // CXL Control Poison bit indicates that the transmitting agent is in Poison state for 256B flit
logic [3:0]                     cxl_256b_rx_late_poison_msg_offset_s; // CXL Control Poison Offset Of Data Header Poisoned

logic                           cxl_all_data_flit_s         ; // All Data Flit(ADF) Indication
logic                           cxl_ctrl_flit_vld_s         ; // Filtered Link Layer Control Flit

localparam CXL_RX_DL_RAS_ERR_LOG_NUM = 2 + 1;
logic                                                  ras_dp_uncorr_err_unpacker    ; // Uncorrectable Error from Unpacker
logic                                                  ras_dp_uncorr_err_unpacker_latched ; // Uncorrectable Error from Unpacker (Latched)
logic            [CXL_RXLINK_CTRL_RAS_UNCORR_NUM-1:0]  ras_dp_uncorr_err_rxlink_ctrl ; // Uncorrectable Error from Link Control
ras_dp_err_log_t                                       ras_dp_err_log_unpacker       ; // Error Log from Unpacker
ras_dp_err_log_t [1:0]                                 ras_dp_err_log_rxlink_ctrl    ; // Error Log from Link Control
ras_dp_err_log_t [CXL_RX_DL_RAS_ERR_LOG_NUM-1:0]       ras_dp_err_log_arr            ; // Error Log from Link Layer
ras_dp_err_inj_t                                       ras_dp_err_inj_s              ; // Error injection for RX Link Layer Checkers

assign ras_dp_err_log_arr = { ras_dp_err_log_unpacker, ras_dp_err_log_rxlink_ctrl};
assign ras_dp_uncorr_err = { ras_dp_uncorr_err_unpacker, ras_dp_uncorr_err_rxlink_ctrl};

ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N ( CXL_RX_DL_RAS_ERR_LOG_NUM )
) u_cxl_rx_dl_ras_dp_err_mgr (
    .clk                ( core_clk             ),
    .rst_n              ( core_rst_n           ),
    .in_ras_dp_err_inj  ( ras_dp_err_inj       ),
    .out_ras_dp_err_inj ( ras_dp_err_inj_s     ),
    .in_ras_dp_err_log  ( ras_dp_err_log_arr   ),
    .out_ras_dp_err_log ( ras_dp_err_log       )
);


assign  b_rxdl_llctrl.s_cxl_rx_cache_req_valid    = cxl_rx_tl_cache_req_valid;
assign  b_rxdl_llctrl.s_cxl_rx_cache_rsp_valid    = cxl_rx_tl_cache_rsp_valid;
assign  b_rxdl_llctrl.s_cxl_rx_mem_ndr_valid      = cxl_rx_tl_mem_ndr_valid;
assign  b_rxdl_llctrl.s_cxl_rx_mem_bi_valid       = cxl_rx_tl_mem_bi_valid;

assign b_cdm.s_cxl_rx_rcvd_retry_req_num_retry  = b_rxdl_llctrl.s_cxl_rx_req_num_retry;
// -------------------------------------------------------------------------------------
// Multiplex between CXS and Channel Message Interface Unpackers
// -------------------------------------------------------------------------------------
assign cxl_rx_flit_data      = cxl_rx_crc_flit_data      ;
assign cxl_rx_flit_data_chk  = b_arb_llctrl.s_cxl_arb_mem_cache_data_chk;
assign cxl_all_data_flit_s   = chi_rx_all_data_flit_s    ;
assign cxl_rx_rsvd_enc_error = chi_rx_rsvd_enc_error     ;
assign cxl_ras_cache_poison  = chi_rx_poisoned_data_s[0] ;
assign cxl_ras_mem_poison    = chi_rx_poisoned_data_s[1] ;
// Used by cxlWbIfConnect only
assign cxl_rx_unpack_flit_prot_en = chi_rx_unpack_flit_prot_en;
// -------------------------------------------------------------------------------------



// -------------------------------------------------------------------------------------
// RX Data Link Layer IDLE indication
// -------------------------------------------------------------------------------------
logic [3:0] cxl_rx_idle_cnt_r, cxl_rx_idle_cnt_nxt;

assign cxl_rx_dl_idle = !(|cxl_rx_idle_cnt_nxt);

always_comb begin
    if (b_rxdl_llctrl.s_cxl_lrsm_drop_flits || cxl_rx_unpack_flit_prot_en) begin
        cxl_rx_idle_cnt_nxt = '1;
    end
    else if (|cxl_rx_idle_cnt_r) begin
        cxl_rx_idle_cnt_nxt = cxl_rx_idle_cnt_r - 4'd1;
    end
    else begin
        cxl_rx_idle_cnt_nxt = cxl_rx_idle_cnt_r;
    end
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        cxl_rx_idle_cnt_r <= # TP '0;
    end else begin
        cxl_rx_idle_cnt_r <= # TP cxl_rx_idle_cnt_nxt;
    end
end
// -------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------
// Flit Checker module decodes the flit header information and checks crc error for the received flit data
// It sends protocol flit enable signal along with data to unpacker module which decodes all protocol flits
// It sends Control flit enable signal along with ack to rxlink_ctrl module which decodes all control flits
// It sends Request, Repsonse, Data Credits to TX module
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_flit_checker
 U_DWC_cxl_mem_cache_flit_checker (
    // Inputs
    .core_clk                             ( core_clk                                     ),
    .core_rst_n                           ( core_rst_n                                   ),
    .cxl_pcie_flit_mode                   ( cxl_protocol_cfg.cxl_pcie_flit_mode          ),
    .cxl_rx_max_crc_error                 ( b_cdm.s_cxl_rx_max_crc_error                 ),
    .cxl_arb_mem_cache_valid              ( b_arb_llctrl.s_cxl_arb_mem_cache_valid       ),
    .cxl_arb_mem_cache_data               ( b_arb_llctrl.s_cxl_arb_mem_cache_data        ),
    .cxl_lrsm_drop_flits                  ( b_rxdl_llctrl.s_cxl_lrsm_drop_flits          ),
    .cxl_rx_unpack_flit_prot_adf          ( cxl_all_data_flit_s                          ),
    .cxl_rx_unpack_ras_dp_err             ( ras_dp_uncorr_err_unpacker_latched          ),
    // Outputs
    .chi_rx_unpack_flit_prot_en           ( chi_rx_unpack_flit_prot_en                   ),
    .cxl_rx_unpack_flit_error             ( cxl_rx_unpack_flit_error                     ),
    .cxl_rx_unpack_flit_data              ( cxl_rx_unpack_flit_data                      ),
    .cxl_rx_llctrl_flit_ctrl_en           ( cxl_rx_llctrl_flit_ctrl_en                   ),
    .cxl_rx_llctrl_flit_prot_en           ( cxl_rx_llctrl_flit_prot_en                   ),
    .cxl_rx_llctrl_flit_prot_adf          ( cxl_rx_llctrl_flit_prot_adf                  ),
    .cxl_rx_llctrl_flit_data              ( cxl_rx_llctrl_flit_data                      ),
    .cxl_rx_crd_flit_data                 ( cxl_rx_crd_flit_data                         ),
    .cxl_rx_crc_flit_valid                ( cxl_rx_crc_flit_valid                        ),
    .cxl_rx_crc_flit_data                 ( cxl_rx_crc_flit_data                         ),
    .cxl_rx_crc_flit_error                ( cxl_rx_crc_err_s                             ),
    .cxl_rx_crc_error                     ( b_rxdl_llctrl.s_cxl_rx_crc_err               ),
    .cxl_tl_rx_crc_error                  ( cxl_rx_crc_error                             ),
    .cxl_rx_crc_error_hit                 ( cxl_rx_crc_error_hit                         )
);

// -------------------------------------------------------------------------------------
// RX Flit Unpacker Instantiation
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_unpacker
 u_DWC_cxl_mem_cache_unpacker (
    // Inputs
    .core_clk                             ( core_clk                                     ),                  
    .core_rst_n                           ( core_rst_n                                   ), 
    .cxl_device_mode                      ( b_cdm.s_cfg_dev_mode                         ),
    .cxl_pcie_flit_mode                   ( cxl_protocol_cfg.cxl_pcie_flit_mode          ),
    .cxl_flit_valid_i                     ( chi_rx_unpack_flit_prot_en                   ),
    .cxl_rx_crc_error_i                   ( cxl_rx_unpack_flit_error                     ),
    .cxl_ctrl_flit_vld_i                  ( cxl_ctrl_flit_vld_s                          ),
    .cxl_mdh_disable_i                    ( b_cdm.s_cfg_cxl_mdh_disable                  ),
    .cxl_tl_cache_crdret_i                ( cxl_rx_tl_cache_data_valid                   ),
    .cxl_rx_cache_crdret_o                ( b_rxdl_llctrl.s_cxl_rx_cache_data_valid      ),
    .cxl_tl_mem_crdret_i                  ( cxl_rx_tl_mem_data_valid                     ),
    .cxl_rx_mem_crdret_o                  ( b_rxdl_llctrl.s_cxl_rx_mem_data_valid        ),
    .cxl_flit_data_68B_i                  ( cxl_flit_data_68B_s                          ),
    .cxl_flit_data_256B_i                 ( cxl_flit_data_256B_s                         ),
    .cxl_256b_rx_late_poison              ( cxl_256b_rx_late_poison_s                    ),
    .cxl_256b_rx_late_poison_msg_offset   ( cxl_256b_rx_late_poison_msg_offset_s         ),
    // Outputs
    .rsvd_enc_error_o                     ( chi_rx_rsvd_enc_error                        ),
    .poisoned_data_o                      ( chi_rx_poisoned_data_s                       ),
    .cxl_mdh_error_o                      ( cxl_rx_mdh_error                             ),
    .cxl_flit_adf_o                       ( chi_rx_all_data_flit_s                       ),
    .b_unpack                             ( b_rxtl_llctrl                                )
);
// -------------------------------------------------------------------------------------

  
// -------------------------------------------------------------------------------------
// RX Link Control Instantiation
//
// Decodes the control flit information.
// Control flit could be any of the llcrd, retry request, retry ack, init flits.  
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_rxlink_ctrl
 U_DWC_cxl_mem_cache_rxlink_ctrl (
    //Inputs
    .core_clk                             ( core_clk                                     ),
    .core_rst_n                           ( core_rst_n                                   ),
    .cxl_vlsm_recovery                    ( b_rxdl_llctrl.s_cxl_vlsm_recovery            ),
    .cxl_pl_block_dl_init                 ( cxl_pl_block_dl_init                         ),
    .cxl_rx_crc_flit_valid                ( cxl_rx_crc_flit_valid                        ),
    .cxl_rx_crc_error                     ( cxl_rx_crc_err_s                             ),
    .cxl_rx_crc_flit_data                 ( cxl_rx_crc_flit_data_s                       ),
    .cxl_rx_llctrl_flit_ctrl_en           ( cxl_rx_llctrl_flit_ctrl_en                   ),
    .cxl_rx_llctrl_flit_prot_en           ( cxl_rx_llctrl_flit_prot_en                   ),
    .cxl_rx_llctrl_flit_prot_adf          ( cxl_rx_llctrl_flit_prot_adf                  ),
    .cxl_rx_crd_flit_data                 ( cxl_rx_crd_flit_data                         ),
    .cxl_pcie_flit_mode                   ( cxl_protocol_cfg.cxl_pcie_flit_mode          ),
    .cxl_rx_llctrl_flit_data              ( cxl_rx_llctrl_flit_data_s                    ),
    //Outputs 
    .cxl_rx_full_ack                      ( b_rxdl_llctrl.s_cxl_rx_full_ack              ),
    .cxl_rx_rcvd_non_retry                ( b_rxdl_llctrl.s_cxl_rx_rcvd_non_retry        ),
    .cxl_256b_rx_rcvd_inerr_poison        ( cxl_256b_rx_late_poison_s                    ),
    .cxl_256b_rx_rcvd_inerr_poison_msg_offset ( cxl_256b_rx_late_poison_msg_offset_s     ),
    .cxl_rx_256B_crd                      ( b_rxdl_llctrl.s_cxl_rx_256B_crd              ),
    .cxl_rx_rcvd_retry_flit               ( b_rxdl_llctrl.s_cxl_rx_rcvd_retry            ),
    .cxl_rx_rcvd_init_param_flit          ( b_rxdl_llctrl.s_cxl_rx_rcvd_init_param       ),
    .cxl_rx_rcvd_retry_req                ( b_rxdl_llctrl.s_cxl_rx_retry_req             ),
    .cxl_rx_rcvd_retry_req_eseq           ( b_rxdl_llctrl.s_cxl_rx_eseq                  ),
    .cxl_rx_rcvd_retry_req_num_retry      ( b_rxdl_llctrl.s_cxl_rx_req_num_retry         ),
    .cxl_rx_rcvd_retry_ack                ( b_rxdl_llctrl.s_cxl_rx_retry_ack             ),
    .cxl_rx_rcvd_retry_ack_num_retry      ( b_rxdl_llctrl.s_cxl_rx_rack_num_retry        ),
    .cxl_rx_rcvd_init_llr_wrap_value      ( b_cdm.s_cxl_rx_rcvd_init_llr_wrap_value      ),
    .cxl_rx_control_flit_error            ( b_cdm.s_cxl_rx_control_flit_error            ),
    .cxl_rx_rcvd_retry_req_num_phy_reinit ( b_cdm.s_cxl_rx_rcvd_retry_req_num_phy_reinit ),
    .cxl_rx_rcvd_retry_ack_empty          ( b_rxdl_llctrl.s_cxl_rx_rcvd_retry_ack_empty  ),
    .cxl_rx_rcvd_init_cxl_version         ( b_cdm.s_cxl_rx_rcvd_init_cxl_version         ),
    .cxl_rx_rcvd_retry_ack_viral          ( b_cdm.s_cxl_rx_rcvd_retry_ack_viral          ),
    .cxl_rx_retry_ack_wrptr               ( b_cdm.s_cxl_rx_retry_ack_wrptr               ),
    .cxl_rx_retry_ack_eseq                ( b_cdm.s_cxl_rx_retry_ack_eseq                ),
    .cxl_rx_retry_ack_numfreebuf          ( b_cdm.s_cxl_rx_retry_ack_numfreebuf          ),
    .cxl_rx_mem_cache_req_crd             ( b_rxdl_llctrl.s_cxl_rx_req_crd               ),
    .cxl_rx_mem_cache_data_crd            ( b_rxdl_llctrl.s_cxl_rx_data_crd              ),
    .cxl_rx_mem_cache_rsp_crd             ( b_rxdl_llctrl.s_cxl_rx_rsp_crd               ),
    .cxl_rx_ctrl_flit_valid               ( cxl_ctrl_flit_vld_s                          )
);
// -------------------------------------------------------------------------------------



// -------------------------------------------------------------------------------------
// Multistream Data Link RAS Wrapper
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_rx_dl_rasdp_wr_ms
 u_ms_dl_ras_wrapper (
  //inputs
     .core_clk                     ( core_clk                                   )
    ,.core_rst_n                   ( core_rst_n                                 )
    ,.cxl_pcie_flit_mode           ( cxl_protocol_cfg.cxl_pcie_flit_mode        )                                                      
    ,.cxl_rx_llctrl_flit_ctrl_en   ( cxl_rx_llctrl_flit_ctrl_en                 )     
    ,.cxl_rx_llctrl_flit_prot_en   ( cxl_rx_llctrl_flit_prot_en                 )
    ,.ras_dp_err_inj               ( ras_dp_err_inj_s                           )
  // RASDP Checker for only 256B Unpacker
    ,.cxl_flit_valid_i             ( chi_rx_unpack_flit_prot_en                 )    
    ,.cxl_flit_data_i              ( cxl_rx_unpack_flit_data                    )   
    ,.cxl_flit_data_256B_o         ( cxl_flit_data_256B_s                       )
    ,.cxl_flit_data_68B_o          ( cxl_flit_data_68B_s                        )     
    ,.ras_dp_err_log_unpack        ( ras_dp_err_log_unpacker                    )        
    ,.ras_dp_uncorr_err_unpack     ( ras_dp_uncorr_err_unpacker                 )
    ,.ras_dp_uncorr_err_unpack_latched ( ras_dp_uncorr_err_unpacker_latched     )
  // RASDP Checker For Rxlink_ctrl
    ,.cxl_rx_crc_flit_valid        ( cxl_rx_crc_flit_valid                      )
    ,.cxl_rx_crc_flit_data         ( cxl_rx_crc_flit_data                       )
    ,.cxl_rx_crc_flit_data_o       ( cxl_rx_crc_flit_data_s                     )
    ,.cxl_rx_llctrl_flit_data      ( cxl_rx_llctrl_flit_data                    )
    ,.cxl_rx_llctrl_flit_data_o    ( cxl_rx_llctrl_flit_data_s                  )               
    ,.ras_dp_err_log_ctrl          ( ras_dp_err_log_rxlink_ctrl                 )                  
    ,.ras_dp_uncorr_err_ctrl       ( ras_dp_uncorr_err_rxlink_ctrl              )
    ,.cxl_arb_mem_cache_data_chk    ( b_arb_llctrl.s_cxl_arb_mem_cache_data_chk  )
    ,.cxl_rx_unpack_flit_data_chk   ( cxl_rx_unpack_flit_data_chk                )
  
);


endmodule
