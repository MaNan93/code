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
// ---  $DateTime: 2023/12/22 07:15:34 $
// ---  $Revision: #4 $
// ---  $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/splh_spif.sv#4 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Packet Layer State Management (SPLH) - SPIF Interface
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Spif/pkg/spif_pkg.svh"
`include "Spif/svif/spif_if.svh"

module splh_spif 
  import spif_pkg::protocol_cfg_t;
(
  // Interfaces
  spif_if.smlh_slave_mp               b_smlh_spif,            // SMLH SPIF interface
  spif_if.xplh_slave_mp               b_xplh_spif,            // XPLH SPIF interface
  spif_if.rplh_slave_mp               b_rplh_spif,            // RPLH SPIF interface
  //spif_if.cfgi_slave_mp               b_cfgi_spif             // CFGI SPIF interface
  spif_if.master_mp                   b_splh_spif,            // SPLH SPIF interface
  // Inputs
  input                               core_clk,               // Core clock
  input                               core_rst_n,             // Core reset
  input                               splh_linkerror,         // PLH Layer Link Error indication
  // Outputs
  output  protocol_cfg_t              pl_protocol_cfg         // Protocol Configuration for PLH Layer
);

// SMLH SPIF Interface Connections
assign b_splh_spif.s_pl_device_port   = b_smlh_spif.s_pl_device_port   ;
assign b_splh_spif.s_pl_phyinl1       = b_smlh_spif.s_pl_phyinl1       ;
assign b_splh_spif.s_pl_phyinl2       = b_smlh_spif.s_pl_phyinl2       ;
assign b_splh_spif.s_pl_phyinretrain  = b_smlh_spif.s_pl_phyinretrain  ;
assign b_splh_spif.s_pl_phyinrxl0s    = b_smlh_spif.s_pl_phyinrxl0s    ;
assign b_splh_spif.s_pl_phyrcvdeiosq  = b_smlh_spif.s_pl_phyrcvdeiosq  ;
assign b_splh_spif.s_pl_speedmode     = b_smlh_spif.s_pl_speedmode     ;
assign b_splh_spif.s_pl_bw_ratio      = b_smlh_spif.s_pl_bw_ratio      ;
assign b_splh_spif.s_pl_linkmode      = b_smlh_spif.s_pl_linkmode      ;
assign b_splh_spif.s_pl_protocol_vld  = b_smlh_spif.s_pl_protocol_vld  ;
assign b_splh_spif.s_pl_protocol      = b_smlh_spif.s_pl_protocol      ;
assign b_splh_spif.s_pl_protocol_fmt  = b_smlh_spif.s_pl_protocol_fmt  ;
assign b_splh_spif.s_pl_inband_pres   = b_smlh_spif.s_pl_inband_pres   ;
assign b_splh_spif.s_pl_link_up       = b_smlh_spif.s_pl_link_up       ;
assign b_splh_spif.s_pl_link_down     = b_smlh_spif.s_pl_link_down     ;
assign b_splh_spif.s_pl_clk_req       = b_smlh_spif.s_pl_clk_req       ;
assign b_splh_spif.s_pl_wake_ack      = b_smlh_spif.s_pl_wake_ack      ;
assign b_splh_spif.s_pl_block_dl_init = b_smlh_spif.s_pl_block_dl_init ;
assign b_splh_spif.s_pl_rx_active_req = b_smlh_spif.s_pl_rx_active_req ;
assign b_splh_spif.s_pl_stall_req     = b_smlh_spif.s_pl_stall_req     ;
assign b_splh_spif.s_pl_state_sts     = b_smlh_spif.s_pl_state_sts     ;
assign b_smlh_spif.s_lp_linkmode_rmt  = b_splh_spif.s_lp_linkmode_rmt  ;
assign b_smlh_spif.s_lp_linkmode_pri  = b_splh_spif.s_lp_linkmode_pri  ;
assign b_smlh_spif.s_lp_linkmode      = b_splh_spif.s_lp_linkmode      ;
assign b_smlh_spif.s_lp_linkerror     = b_splh_spif.s_lp_linkerror || splh_linkerror ;
assign b_smlh_spif.s_lp_clk_ack       = b_splh_spif.s_lp_clk_ack       ;
assign b_smlh_spif.s_lp_wake_req      = b_splh_spif.s_lp_wake_req      ;
assign b_smlh_spif.s_lp_dl_active     = b_splh_spif.s_lp_dl_active     ;
assign b_smlh_spif.s_lp_rx_active_sts = b_splh_spif.s_lp_rx_active_sts ;
assign b_smlh_spif.s_lp_state_req     = b_splh_spif.s_lp_state_req     ;
assign b_smlh_spif.s_lp_stall_ack     = b_splh_spif.s_lp_stall_ack     ;

// XPLH SPIF Interface Connections
assign b_splh_spif.s_pl_dllp_trdy     = b_xplh_spif.s_pl_dllp_trdy     ;
assign b_splh_spif.s_pl_skip_trdy     = b_xplh_spif.s_pl_skip_trdy     ;
assign b_splh_spif.s_pl_trdy          = b_xplh_spif.s_pl_trdy          ;
assign b_xplh_spif.s_lp_stream        = b_splh_spif.s_lp_stream        ;
assign b_xplh_spif.s_lp_irdy          = b_splh_spif.s_lp_irdy          ;
assign b_xplh_spif.s_lp_pri           = b_splh_spif.s_lp_pri           ;
assign b_xplh_spif.s_lp_valid         = b_splh_spif.s_lp_valid         ;
assign b_xplh_spif.s_lp_data          = b_splh_spif.s_lp_data          ;
assign b_xplh_spif.s_lp_crc_valid     = b_splh_spif.s_lp_crc_valid     ;
assign b_xplh_spif.s_lp_crc_data      = b_splh_spif.s_lp_crc_data      ;
assign b_xplh_spif.s_lp_data_chk      = b_splh_spif.s_lp_data_chk      ;
assign b_xplh_spif.s_lp_rasdp_error   = b_splh_spif.s_lp_rasdp_error   ;
assign b_xplh_spif.s_lp_dlp_start     = b_splh_spif.s_lp_dlp_start     ;
assign b_xplh_spif.s_lp_dlp_end       = b_splh_spif.s_lp_dlp_end       ;
assign b_xplh_spif.s_lp_tlp_start     = b_splh_spif.s_lp_tlp_start     ;
assign b_xplh_spif.s_lp_tlp_end       = b_splh_spif.s_lp_tlp_end       ;
assign b_xplh_spif.s_lp_nop_flit      = b_splh_spif.s_lp_nop_flit      ;
assign b_xplh_spif.s_lp_corrupt_crc   = b_splh_spif.s_lp_corrupt_crc   ;
assign b_xplh_spif.s_lp_dllp_valid    = b_splh_spif.s_lp_dllp_valid    ;
assign b_xplh_spif.s_lp_dllp_ofc      = b_splh_spif.s_lp_dllp_ofc      ;
assign b_xplh_spif.s_lp_dllp_data     = b_splh_spif.s_lp_dllp_data     ;

// RPLH SPIF Interface Connections
assign b_splh_spif.s_pl_stream        = b_rplh_spif.s_pl_stream        ;
assign b_splh_spif.s_pl_valid         = b_rplh_spif.s_pl_valid         ;
assign b_splh_spif.s_pl_data          = b_rplh_spif.s_pl_data          ;
assign b_splh_spif.s_pl_data_chk      = b_rplh_spif.s_pl_data_chk      ;
assign b_splh_spif.s_pl_crc_valid     = b_rplh_spif.s_pl_crc_valid     ;
assign b_splh_spif.s_pl_crc_data      = b_rplh_spif.s_pl_crc_data      ;
assign b_splh_spif.s_pl_rx_flush      = b_rplh_spif.s_pl_rx_flush      ;
assign b_splh_spif.s_pl_rx_nak        = b_rplh_spif.s_pl_rx_nak        ;
assign b_splh_spif.s_pl_dlp_start     = b_rplh_spif.s_pl_dlp_start     ;
assign b_splh_spif.s_pl_dlp_end       = b_rplh_spif.s_pl_dlp_end       ;
assign b_splh_spif.s_pl_tlp_start     = b_rplh_spif.s_pl_tlp_start     ;
assign b_splh_spif.s_pl_tlp_end       = b_rplh_spif.s_pl_tlp_end       ;
assign b_splh_spif.s_pl_tlp_edb       = b_rplh_spif.s_pl_tlp_edb       ;
assign b_splh_spif.s_pl_error         = b_rplh_spif.s_pl_error         ;
assign b_splh_spif.s_pl_nullified     = b_rplh_spif.s_pl_nullified     ;
assign b_splh_spif.s_pl_poisoned      = b_rplh_spif.s_pl_poisoned      ;
assign b_splh_spif.s_pl_dllp_valid    = b_rplh_spif.s_pl_dllp_valid    ;
assign b_splh_spif.s_pl_dllp_ofc      = b_rplh_spif.s_pl_dllp_ofc      ;
assign b_splh_spif.s_pl_dllp_data     = b_rplh_spif.s_pl_dllp_data     ;

// CFGI SPIF Interface Connections
assign b_splh_spif.s_pl_cfg_vld       = '0; //b_cfgi_spif.s_pl_cfg_vld       ;
assign b_splh_spif.s_pl_cfg_data      = '0; //b_cfgi_spif.s_pl_cfg_data      ;
// assign b_cfgi_spif.s_lp_cfg_vld       = b_splh_spif.s_lp_cfg_vld       ;
// assign b_cfgi_spif.s_lp_cfg_data      = b_splh_spif.s_lp_cfg_data      ;

// -------------------------------------------------------------------------------------
// Protocol Decoder Instantiation to be used on the hierarchy level
// -------------------------------------------------------------------------------------
spif_protocol_dec
 u_spif_protocol (
    // Inputs
    .core_clk              ( core_clk                      ),
    .core_rst_n            ( core_rst_n                    ),
    .pl_protocol_vld       ( b_splh_spif.s_pl_protocol_vld ),
    .pl_protocol           ( b_splh_spif.s_pl_protocol     ),
    .pl_protocol_fmt       ( b_splh_spif.s_pl_protocol_fmt ),
    // Outputs
    .pl_protocol_cfg       ( pl_protocol_cfg               )
);
// -------------------------------------------------------------------------------------

endmodule
