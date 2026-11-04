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
// ---   $DateTime: 2023/10/03 08:20:39 $
// ---   $Revision: #9 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_unpacker.sv#9 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// CXL Flit Unpacker
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
`include "CXL/svif/DWC_cxl_rxtl_llctrl_if.svh"
`include "DWC_pcie_ctl_pkg.svh"

module DWC_cxl_mem_cache_unpacker
  import DWC_cxl_pkg::*;
#(
  parameter TP = `TP
)
                                   (
    // Inputs
    input                                         core_clk,              // Clock
    input                                         core_rst_n,            // Asynchronous Active Low Reset
    input                                         cxl_device_mode,       // CXL Device Type
    input                                         cxl_pcie_flit_mode,
    input                                         cxl_flit_valid_i                  ,  // Protocol Flit Valid before CRC check
    input                                         cxl_rx_crc_error_i                ,  // CRC check error on the received flit
    input                                         cxl_mdh_disable_i                 ,  // Disable MDH support
    input   [HD_DDATA_NUM - 1: 0]                 cxl_tl_cache_crdret_i             ,  // Transaction Layer Return Cache Data Credit
    input   [MS_SM_DDATA_NUM - 1: 0]              cxl_tl_mem_crdret_i               ,  // Transaction Layer Return Mem Data Credit
    input                                         cxl_256b_rx_late_poison           ,  // late poison feature valid 
    input  [3:0]                                  cxl_256b_rx_late_poison_msg_offset,  // late poison message offset
    input                                         cxl_ctrl_flit_vld_i               ,  // Filtered Link Layer Control Flit
    input  [CXL_DATA_WD-1:0]                      cxl_flit_data_256B_i              ,  // RX unpacker 256B flit data
    input  [CXL_DATA_WD-1:0]                      cxl_flit_data_68B_i               ,  // RX unpacker 68B flit data     
    // Outputs
    output [1:0]                                  cxl_rx_cache_crdret_o, // RX Return Cache Data Credit
    output [1:0]                                  cxl_rx_mem_crdret_o,   // RX Return Mem Data Credit
    output                                        rsvd_enc_error_o,      // CXL Reserved Encoding Violation
    output [1:0]                                  poisoned_data_o,       // CXL Poison Data Detection
    output                                        cxl_mdh_error_o,       // MDH Error
    output                                        cxl_flit_adf_o,        // All Data Flit Indication
    DWC_cxl_rxtl_llctrl_if.master_mp              b_unpack
 );

 localparam CHANNEL_NUM      = FLIT_SLOT_NUM/4          ; 
 
 
 DWC_cxl_rxtl_llctrl_if #(.H2D_INT_DATA_NUM(H2D_DATA_NUM), .D2H_INT_DATA_NUM(D2H_DATA_NUM), .M2S_INT_DATA_NUM(M2S_DATA_NUM), .S2M_INT_DATA_NUM(S2M_DATA_NUM))   b_unpack_256B     ();
 DWC_cxl_rxtl_llctrl_if #(.H2D_INT_DATA_NUM(H2D_DATA_NUM), .D2H_INT_DATA_NUM(D2H_DATA_NUM), .M2S_INT_DATA_NUM(M2S_DATA_NUM), .S2M_INT_DATA_NUM(S2M_DATA_NUM))   b_unpack_68B      ();
 
 DWC_cxl_rxtl_llctrl_if #(.H2D_INT_DATA_NUM(H2D_DATA_NUM), .D2H_INT_DATA_NUM(D2H_DATA_NUM), .M2S_INT_DATA_NUM(M2S_DATA_NUM), .S2M_INT_DATA_NUM(S2M_DATA_NUM))   b_unpack_mux      ();
 
logic [1:0]    cxl_rx_mem_crdret_68B_s   ;
logic [1:0]    cxl_rx_mem_crdret_256B_s  ;
logic [1:0]    cxl_rx_cache_crdret_68B_s ;
logic [1:0]    cxl_rx_cache_crdret_256B_s;
logic [1:0]    poisoned_data_68B_s       ;
logic [1:0]    poisoned_data_256B_s      ;
logic          rsvd_enc_error_68B_s      ;
logic          rsvd_enc_error_256B_s     ;
logic          cxl_flit_adf_68B_s        ;
logic          cxl_flit_adf_256B_s       ;
logic          cxl_mdh_error_68B_s       ;
logic          cxl_mdh_error_256B_s      ;
logic          cxl_flit_valid_68B_s      ;
logic          cxl_flit_valid_256B_s     ;
logic [CHANNEL_NUM-1:0]           cxl_h2d_poison_bit_s      ;
logic [CHANNEL_NUM-1:0]           cxl_d2h_poison_bit_s      ;
logic [CHANNEL_NUM-1:0]           cxl_m2s_poison_bit_s      ;
logic [CHANNEL_NUM-1:0]           cxl_s2m_poison_bit_s      ;


  assign poisoned_data_o                   = cxl_pcie_flit_mode ? poisoned_data_256B_s                   : poisoned_data_68B_s                    ;
  assign rsvd_enc_error_o                  = cxl_pcie_flit_mode ? rsvd_enc_error_256B_s                  : rsvd_enc_error_68B_s                   ;
  assign cxl_flit_adf_o                    = cxl_pcie_flit_mode ? cxl_flit_adf_256B_s                    : cxl_flit_adf_68B_s                     ;
  assign cxl_mdh_error_o                   = cxl_pcie_flit_mode ? cxl_mdh_error_256B_s                   : cxl_mdh_error_68B_s                    ;
  assign cxl_rx_mem_crdret_o               = cxl_pcie_flit_mode ? cxl_rx_mem_crdret_256B_s               : cxl_rx_mem_crdret_68B_s                ;
  assign cxl_rx_cache_crdret_o             = cxl_pcie_flit_mode ? cxl_rx_cache_crdret_256B_s             : cxl_rx_cache_crdret_68B_s              ;
  assign b_unpack_mux.s_cxl_h2d_req            = (cxl_pcie_flit_mode)? b_unpack_256B.s_cxl_h2d_req           : b_unpack_68B.s_cxl_h2d_req           ;
  assign b_unpack_mux.s_cxl_h2d_resp           = (cxl_pcie_flit_mode)? b_unpack_256B.s_cxl_h2d_resp          : b_unpack_68B.s_cxl_h2d_resp          ;
  assign b_unpack_mux.s_cxl_h2d_dhr            = (cxl_pcie_flit_mode)? b_unpack_256B.s_cxl_h2d_dhr           : b_unpack_68B.s_cxl_h2d_dhr           ;
  assign b_unpack_mux.s_cxl_h2d_data           = (cxl_pcie_flit_mode)? b_unpack_256B.s_cxl_h2d_data          : b_unpack_68B.s_cxl_h2d_data          ;
  assign b_unpack_mux.s_cxl_h2d_data_valid     = (cxl_pcie_flit_mode)? b_unpack_256B.s_cxl_h2d_data_valid    : b_unpack_68B.s_cxl_h2d_data_valid    ;
  assign b_unpack_mux.s_cxl_d2h_req            = (cxl_pcie_flit_mode)? b_unpack_256B.s_cxl_d2h_req           : b_unpack_68B.s_cxl_d2h_req           ;
  assign b_unpack_mux.s_cxl_d2h_resp           = (cxl_pcie_flit_mode)? b_unpack_256B.s_cxl_d2h_resp          : b_unpack_68B.s_cxl_d2h_resp          ;
  assign b_unpack_mux.s_cxl_d2h_dhr            = (cxl_pcie_flit_mode)? b_unpack_256B.s_cxl_d2h_dhr           : b_unpack_68B.s_cxl_d2h_dhr           ;
  assign b_unpack_mux.s_cxl_d2h_data           = (cxl_pcie_flit_mode)? b_unpack_256B.s_cxl_d2h_data          : b_unpack_68B.s_cxl_d2h_data          ;
  assign b_unpack_mux.s_cxl_d2h_data_valid     = (cxl_pcie_flit_mode)? b_unpack_256B.s_cxl_d2h_data_valid    : b_unpack_68B.s_cxl_d2h_data_valid    ;
  assign b_unpack_mux.s_cxl_d2h_byte_en_valid  = (cxl_pcie_flit_mode)? b_unpack_256B.s_cxl_d2h_byte_en_valid : b_unpack_68B.s_cxl_d2h_byte_en_valid ;
  assign b_unpack_mux.s_cxl_d2h_byte_en        = (cxl_pcie_flit_mode)? b_unpack_256B.s_cxl_d2h_byte_en       : b_unpack_68B.s_cxl_d2h_byte_en       ;
  assign b_unpack_mux.s_cxl_m2s_dhr            = (cxl_pcie_flit_mode)? b_unpack_256B.s_cxl_m2s_dhr           : b_unpack_68B.s_cxl_m2s_dhr           ;
  assign b_unpack_mux.s_cxl_m2s_req            = (cxl_pcie_flit_mode)? b_unpack_256B.s_cxl_m2s_req           : b_unpack_68B.s_cxl_m2s_req           ;
  assign b_unpack_mux.s_cxl_m2s_data           = (cxl_pcie_flit_mode)? b_unpack_256B.s_cxl_m2s_data          : b_unpack_68B.s_cxl_m2s_data          ;
  assign b_unpack_mux.s_cxl_m2s_data_valid     = (cxl_pcie_flit_mode)? b_unpack_256B.s_cxl_m2s_data_valid    : b_unpack_68B.s_cxl_m2s_data_valid    ;
  assign b_unpack_mux.s_cxl_m2s_byte_en        = (cxl_pcie_flit_mode)? b_unpack_256B.s_cxl_m2s_byte_en       : b_unpack_68B.s_cxl_m2s_byte_en       ;
  assign b_unpack_mux.s_cxl_m2s_byte_en_valid  = (cxl_pcie_flit_mode)? b_unpack_256B.s_cxl_m2s_byte_en_valid : b_unpack_68B.s_cxl_m2s_byte_en_valid ;
  assign b_unpack_mux.s_cxl_s2m_ndr            = (cxl_pcie_flit_mode)? b_unpack_256B.s_cxl_s2m_ndr           : b_unpack_68B.s_cxl_s2m_ndr           ;
  assign b_unpack_mux.s_cxl_s2m_drs            = (cxl_pcie_flit_mode)? b_unpack_256B.s_cxl_s2m_drs           : b_unpack_68B.s_cxl_s2m_drs           ;
  assign b_unpack_mux.s_cxl_s2m_data_valid     = (cxl_pcie_flit_mode)? b_unpack_256B.s_cxl_s2m_data_valid    : b_unpack_68B.s_cxl_s2m_data_valid    ;
  assign b_unpack_mux.s_cxl_s2m_data           = (cxl_pcie_flit_mode)? b_unpack_256B.s_cxl_s2m_data          : b_unpack_68B.s_cxl_s2m_data          ;
  assign b_unpack_mux.s_cxl_m2s_bi_rsp         = (cxl_pcie_flit_mode)? b_unpack_256B.s_cxl_m2s_bi_rsp        : b_unpack_68B.s_cxl_m2s_bi_rsp           ;
  assign b_unpack_mux.s_cxl_s2m_bi_snp         = (cxl_pcie_flit_mode)? b_unpack_256B.s_cxl_s2m_bi_snp        : b_unpack_68B.s_cxl_s2m_bi_snp           ;

// -------------------------------------------------------------------------------------
// - Data Header Aligner
// - Queue the Data Headers in Link Layer for Supporting Late Poison Feature as poison Bit  
//   of Data Header Should be Asserted Before Transmission to RAS Module for Protection.
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_rx_dhdr_align
  u_data_hdr_aligner (
    // Inputs
    .clk_i                                ( core_clk             ),                  
    .rst_n_i                              ( core_rst_n           ),
    .cxl_h2d_poison_bit_i                 ( cxl_h2d_poison_bit_s ),
    .cxl_d2h_poison_bit_i                 ( cxl_d2h_poison_bit_s ),
    .cxl_m2s_poison_bit_i                 ( cxl_m2s_poison_bit_s ),
    .cxl_s2m_poison_bit_i                 ( cxl_s2m_poison_bit_s ),
    // Outputs                                                   
    .b_unpack_unaligned                   ( b_unpack_mux.slave_mp),
    .b_unpack_aligned                     ( b_unpack             )
);

// Gate the 68B unpacker in case PCIe Flit mode is enabeld
assign cxl_flit_valid_68B_s = (cxl_pcie_flit_mode)? 1'b0           : cxl_flit_valid_i;
assign cxl_flit_valid_256B_s = cxl_pcie_flit_mode & cxl_flit_valid_i;


// -------------------------------------------------------------------------------------
// RX 256B Byte Flit Unpacker Instantiation
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_unpacker_256byte
  u_unpacker_256byte (
    // Inputs
    .core_clk                             ( core_clk                                     ),                  
    .core_rst_n                           ( core_rst_n                                   ),
    .cxl_device_mode                      ( cxl_device_mode                              ),
    .cxl_flit_valid_i                     ( cxl_flit_valid_256B_s                        ),
    .cxl_flit_data_i                      ( cxl_flit_data_256B_i                         ),
    .cxl_rx_crc_error_i                   ( cxl_rx_crc_error_i                           ),
    .cxl_ctrl_flit_vld_i                  ( cxl_ctrl_flit_vld_i                          ),
    .cxl_mdh_disable_i                    ( cxl_mdh_disable_i                            ),
    .cxl_tl_cache_crdret_i                ( cxl_tl_cache_crdret_i                        ),
    .cxl_rx_cache_crdret_o                ( cxl_rx_cache_crdret_256B_s                   ),
    .cxl_tl_mem_crdret_i                  ( cxl_tl_mem_crdret_i                          ),
    .cxl_rx_mem_crdret_o                  ( cxl_rx_mem_crdret_256B_s                     ),
    .cxl_256b_rx_poison_i                 ( cxl_256b_rx_late_poison                     ),
    .cxl_256b_rx_poison_off_i             ( cxl_256b_rx_late_poison_msg_offset          ),
    // Outputs
    .cxl_h2d_poison_bit_o                 ( cxl_h2d_poison_bit_s                         ),
    .cxl_d2h_poison_bit_o                 ( cxl_d2h_poison_bit_s                         ),
    .cxl_m2s_poison_bit_o                 ( cxl_m2s_poison_bit_s                         ),
    .cxl_s2m_poison_bit_o                 ( cxl_s2m_poison_bit_s                         ),
    .cxl_flit_adf_o                       ( cxl_flit_adf_256B_s                          ),
    .rsvd_enc_error_o                     ( rsvd_enc_error_256B_s                        ),
    .poisoned_data_o                      ( poisoned_data_256B_s                         ),
    .cxl_mdh_error_o                      ( cxl_mdh_error_256B_s                         ),
    .b_unpack_256B                        ( b_unpack_256B.master_mp                      )
);
// -------------------------------------------------------------------------------------
// RX 68 Byte Flit Unpacker Instantiation
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_unpacker_68byte
  u_unpacker_68byte (
    // Inputs
    .core_clk                             ( core_clk                                     ),                  
    .core_rst_n                           ( core_rst_n                                   ), 
    .cxl_device_mode                      ( cxl_device_mode                              ),
    .cxl_flit_valid_i                     ( cxl_flit_valid_68B_s                         ),
    .cxl_flit_data_i                      ( cxl_flit_data_68B_i[511:0]                   ),
    .cxl_rx_crc_error_i                   ( cxl_rx_crc_error_i                           ),
    .cxl_mdh_disable_i                    ( cxl_mdh_disable_i                            ),
    .cxl_tl_cache_crdret_i                ( |cxl_tl_cache_crdret_i                       ),
    .cxl_rx_cache_crdret_o                ( cxl_rx_cache_crdret_68B_s                    ),
    .cxl_tl_mem_crdret_i                  ( |cxl_tl_mem_crdret_i                         ),
    .cxl_rx_mem_crdret_o                  ( cxl_rx_mem_crdret_68B_s                      ),
    // Outputs
    .rsvd_enc_error_o                     ( rsvd_enc_error_68B_s                         ),
    .poisoned_data_o                      ( poisoned_data_68B_s                          ),
    .cxl_mdh_error_o                      ( cxl_mdh_error_68B_s                          ),
    .cxl_flit_adf_o                       ( cxl_flit_adf_68B_s                           ),
    .b_unpack_68B                         ( b_unpack_68B.master_mp                       )
);
endmodule
