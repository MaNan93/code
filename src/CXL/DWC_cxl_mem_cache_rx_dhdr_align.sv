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
// ---   $Revision: #2 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_rx_dhdr_align.sv#2 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// This module queue data headers and aligns it to its corresponding data then transmits 
// it to RAS module for protection and bypass other messages to RAS module for protection. 
// -------------------------------------------------------------------------------------
// CXL DWC_cxl_rx_data_hdr_aligner
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
`include "CXL/svif/DWC_cxl_rxtl_llctrl_if.svh"
`include "DWC_pcie_ctl_pkg.svh"

module DWC_cxl_mem_cache_rx_dhdr_align
  import DWC_cxl_pkg::*;
#(
  parameter TP           = `TP,
  parameter CHANNEL_NUM  = FLIT_SLOT_NUM/4
  
)(                                                                     
    // Inputs                                                          
    input                               clk_i                   ,   // Clock
    input                               rst_n_i                 ,   // Asynchronous Active Low Reset
    input [H2D_256B_DDATA_NUM-1:0]      cxl_h2d_poison_bit_i    ,  // Late Poison Bit 
    input [D2H_256B_DDATA_NUM-1:0]      cxl_d2h_poison_bit_i    ,  // Late Poison Bit
    input [M2S_256B_DDATA_NUM-1:0]      cxl_m2s_poison_bit_i    ,  // Late Poison Bit
    input [S2M_256B_DDATA_NUM-1:0]      cxl_s2m_poison_bit_i    ,  // Late Poison Bit 
    DWC_cxl_rxtl_llctrl_if.slave_mp     b_unpack_unaligned      ,  // Interface from the Unpacker to the Aligner 
    // Outputs
    DWC_cxl_rxtl_llctrl_if.master_mp    b_unpack_aligned           // Interface from the Aligner  to the RX_TL                                                    
 );
 
  assign b_unpack_aligned.s_cxl_h2d_req     = b_unpack_unaligned.s_cxl_h2d_req    ;
  assign b_unpack_aligned.s_cxl_h2d_resp    = b_unpack_unaligned.s_cxl_h2d_resp   ;
  assign b_unpack_aligned.s_cxl_d2h_req     = b_unpack_unaligned.s_cxl_d2h_req    ;
  assign b_unpack_aligned.s_cxl_d2h_resp    = b_unpack_unaligned.s_cxl_d2h_resp   ;
  assign b_unpack_aligned.s_cxl_m2s_req     = b_unpack_unaligned.s_cxl_m2s_req    ;
  assign b_unpack_aligned.s_cxl_s2m_ndr     = b_unpack_unaligned.s_cxl_s2m_ndr    ;
  assign b_unpack_aligned.s_cxl_m2s_bi_rsp  = b_unpack_unaligned.s_cxl_m2s_bi_rsp ;
  assign b_unpack_aligned.s_cxl_s2m_bi_snp  = b_unpack_unaligned.s_cxl_s2m_bi_snp ;
// -------------------------------------------------------------------------------------
// H2D Data Header Aligner
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_rx_chan_dhdr_align
 #(
   .HDR_NUM    (H2D_DATA_NUM      ),  
   .HDR_SIZE   (H2D_DHDR_SIZE     ),
   .DATA_SIZE  (H2D_DDATA_SIZE    ),
   .DATA_NUM   (H2D_DDATA_NUM     ),
   .BE_ENABLE  (1'b0              )
   ,   
   .POISON_BIT (H2D_256B_POISON_BIT)
) u_h2d_channel_hdr_aligner (
   .clk_i                     (clk_i                                   ),
   .rst_n_i                   (rst_n_i                                 ),
   .cxl_hdr_i                 (b_unpack_unaligned.s_cxl_h2d_dhr        ),
   .cxl_data_i                (b_unpack_unaligned.s_cxl_h2d_data       ),
   .cxl_be_i                  ('{default:'0}                           ),
   .cxl_data_valid_i          (b_unpack_unaligned.s_cxl_h2d_data_valid ),
   .cxl_be_valid_i            ('0                                      ),
   .cxl_poison_bit_i          (cxl_h2d_poison_bit_i                    ),
   .cxl_hdr_o                 (b_unpack_aligned.s_cxl_h2d_dhr          ),
   .cxl_data_o                (b_unpack_aligned.s_cxl_h2d_data         ),
   .cxl_be_o                  (/*Byte_En not Supported In H2D message*/),
   .cxl_data_valid_o          (b_unpack_aligned.s_cxl_h2d_data_valid   ),
   .cxl_be_valid_o            (/*Byte_En not Supported In H2D message*/)
);
// -------------------------------------------------------------------------------------
// D2H Data Header Aligner
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_rx_chan_dhdr_align
 #(
   .HDR_NUM    (D2H_DATA_NUM      ),
   .HDR_SIZE   (D2H_DHDR_SIZE     ),
   .DATA_SIZE  (D2H_DDATA_SIZE    ),
   .BE_SIZE    (D2H_DBE_SIZE      ),
   .DATA_NUM   (D2H_DDATA_NUM     ),
   .BE_ENABLE  (1'b1              )
   , 
   .POISON_BIT (D2H_256B_POISON_BIT) 
) u_d2h_channel_aligner (
   .clk_i                     (clk_i                                     ),
   .rst_n_i                   (rst_n_i                                   ),
   .cxl_hdr_i                 (b_unpack_unaligned.s_cxl_d2h_dhr          ),
   .cxl_data_i                (b_unpack_unaligned.s_cxl_d2h_data         ),
   .cxl_be_i                  (b_unpack_unaligned.s_cxl_d2h_byte_en      ),
   .cxl_data_valid_i          (b_unpack_unaligned.s_cxl_d2h_data_valid   ),
   .cxl_be_valid_i            (b_unpack_unaligned.s_cxl_d2h_byte_en_valid),
   .cxl_poison_bit_i          (cxl_d2h_poison_bit_i                      ),
   .cxl_hdr_o                 (b_unpack_aligned.s_cxl_d2h_dhr            ),
   .cxl_data_o                (b_unpack_aligned.s_cxl_d2h_data           ),
   .cxl_be_o                  (b_unpack_aligned.s_cxl_d2h_byte_en        ),
   .cxl_data_valid_o          (b_unpack_aligned.s_cxl_d2h_data_valid     ),
   .cxl_be_valid_o            (b_unpack_aligned.s_cxl_d2h_byte_en_valid  )
);
// -------------------------------------------------------------------------------------
// M2S Data Header Aligner
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_rx_chan_dhdr_align
 #(
   .HDR_NUM    (M2S_DATA_NUM      ),
   .HDR_SIZE   (M2S_DHDR_SIZE     ),
   .DATA_SIZE  (M2S_DDATA_SIZE    ),
   .BE_SIZE    (M2S_DBE_SIZE      ),
   .DATA_NUM   (M2S_DDATA_NUM     ),
   .BE_ENABLE  (1'b1              )
   , 
   .POISON_BIT (M2S_256B_POISON_BIT)
   
) u_m2s_channel_aligner (
   .clk_i                     (clk_i                                     ),
   .rst_n_i                   (rst_n_i                                   ),
   .cxl_hdr_i                 (b_unpack_unaligned.s_cxl_m2s_dhr          ),
   .cxl_data_i                (b_unpack_unaligned.s_cxl_m2s_data         ),
   .cxl_be_i                  (b_unpack_unaligned.s_cxl_m2s_byte_en      ),
   .cxl_data_valid_i          (b_unpack_unaligned.s_cxl_m2s_data_valid   ),
   .cxl_be_valid_i            (b_unpack_unaligned.s_cxl_m2s_byte_en_valid),
   .cxl_poison_bit_i          (cxl_m2s_poison_bit_i                      ),
   .cxl_hdr_o                 (b_unpack_aligned.s_cxl_m2s_dhr            ),
   .cxl_data_o                (b_unpack_aligned.s_cxl_m2s_data           ),
   .cxl_be_o                  (b_unpack_aligned.s_cxl_m2s_byte_en        ),
   .cxl_data_valid_o          (b_unpack_aligned.s_cxl_m2s_data_valid     ),
   .cxl_be_valid_o            (b_unpack_aligned.s_cxl_m2s_byte_en_valid  )
);
// -------------------------------------------------------------------------------------
// S2M Data Header Aligner
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_rx_chan_dhdr_align
 #(
   .HDR_NUM    (S2M_DATA_NUM      ),
   .HDR_SIZE   (S2M_DHDR_SIZE     ),
   .DATA_SIZE  (S2M_DDATA_SIZE    ),
   .DATA_NUM   (S2M_DDATA_NUM     ),
   .BE_ENABLE  (1'b0              )
   ,
   .POISON_BIT (S2M_256B_POISON_BIT)
) u_s2m_channel_aligner (
   .clk_i                     (clk_i                                   ),
   .rst_n_i                   (rst_n_i                                 ),
   .cxl_hdr_i                 (b_unpack_unaligned.s_cxl_s2m_drs        ),
   .cxl_data_i                (b_unpack_unaligned.s_cxl_s2m_data       ),
   .cxl_be_i                  ('{default:'0}                           ),
   .cxl_data_valid_i          (b_unpack_unaligned.s_cxl_s2m_data_valid ),
   .cxl_be_valid_i            ('0                                      ),
   .cxl_poison_bit_i          (cxl_s2m_poison_bit_i                    ),
   .cxl_hdr_o                 (b_unpack_aligned.s_cxl_s2m_drs          ),
   .cxl_data_o                (b_unpack_aligned.s_cxl_s2m_data         ),
   .cxl_be_o                  (/*Byte_En not Supported In S2M message*/),
   .cxl_data_valid_o          (b_unpack_aligned.s_cxl_s2m_data_valid   ),
   .cxl_be_valid_o            (/*Byte_En not Supported In S2M message*/)
);

endmodule 
