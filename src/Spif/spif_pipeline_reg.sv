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
// ---  $Id: //dwh/pcie_iip/main/fairbanks/design/Spif/spif_pipeline_reg.sv#4 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// SPIF Interface Pipeline Register
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Spif/pkg/spif_pkg.svh"
`include "Spif/svif/spif_if.svh"

module spif_pipeline_reg 
  import spif_pkg::protocol_cfg_t;
  import spif_pkg::PCIE_MODE;
  import spif_pkg::FMT_NONE_FLIT;
  import spif_pkg::RESET;
  import spif_pkg::SID_RSVD;
(
  // Interfaces
  spif_if.master_mp                   b_spif_mp,              // SPIF interface from Link Layer to Physical Layer
  spif_if.slave_mp                    b_spif_sp               // SPIF interface from Physical Layer to Link Layer
);

logic    [1:0] spif_tb_mode; // 00b: Connected to Controller; 01b: Disconnected (tie-off); 10b: Connect TB to MP; 11b: Connect TB to SP
spif_if        b_spif_tb();  // TB SPIF Interface

assign spif_tb_mode = 2'b00;

// -------------------------------------------------------------------------------------
// SMLH SPIF Interface Connections
// -------------------------------------------------------------------------------------
assign b_spif_mp.s_pl_device_port   = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_device_port   : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_device_port   : '0 ;
assign b_spif_mp.s_pl_phyinl1       = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_phyinl1       : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_phyinl1       : '0 ;
assign b_spif_mp.s_pl_phyinl2       = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_phyinl2       : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_phyinl2       : '0 ;
assign b_spif_mp.s_pl_phyinretrain  = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_phyinretrain  : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_phyinretrain  : '0 ;
assign b_spif_mp.s_pl_phyinrxl0s    = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_phyinrxl0s    : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_phyinrxl0s    : '0 ;
assign b_spif_mp.s_pl_phyrcvdeiosq  = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_phyrcvdeiosq  : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_phyrcvdeiosq  : '0 ;
assign b_spif_mp.s_pl_speedmode     = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_speedmode     : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_speedmode     : '0 ;
assign b_spif_mp.s_pl_bw_ratio      = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_bw_ratio      : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_bw_ratio      : '0 ;
assign b_spif_mp.s_pl_linkmode      = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_linkmode      : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_linkmode      : '0 ;
assign b_spif_mp.s_pl_protocol_vld  = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_protocol_vld  : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_protocol_vld  : '0 ;
assign b_spif_mp.s_pl_protocol      = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_protocol      : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_protocol      : PCIE_MODE ;
assign b_spif_mp.s_pl_protocol_fmt  = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_protocol_fmt  : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_protocol_fmt  : FMT_NONE_FLIT ;
assign b_spif_mp.s_pl_inband_pres   = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_inband_pres   : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_inband_pres   : '0 ;
assign b_spif_mp.s_pl_link_up       = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_link_up       : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_link_up       : '0 ;
assign b_spif_mp.s_pl_link_down     = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_link_down     : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_link_down     : '0 ;
assign b_spif_mp.s_pl_clk_req       = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_clk_req       : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_clk_req       : '0 ;
assign b_spif_mp.s_pl_wake_ack      = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_wake_ack      : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_wake_ack      : '0 ;
assign b_spif_mp.s_pl_block_dl_init = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_block_dl_init : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_block_dl_init : '0 ;
assign b_spif_mp.s_pl_rx_active_req = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_rx_active_req : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_rx_active_req : '0 ;
assign b_spif_mp.s_pl_stall_req     = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_stall_req     : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_stall_req     : '0 ;
assign b_spif_mp.s_pl_state_sts     = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_state_sts     : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_state_sts     : RESET ;

assign b_spif_sp.s_lp_linkmode_rmt  = (spif_tb_mode == 2'b00) ? b_spif_mp.s_lp_linkmode_rmt  : (spif_tb_mode == 2'b11) ? b_spif_tb.s_lp_linkmode_rmt  : '0 ;
assign b_spif_sp.s_lp_linkmode_pri  = (spif_tb_mode == 2'b00) ? b_spif_mp.s_lp_linkmode_pri  : (spif_tb_mode == 2'b11) ? b_spif_tb.s_lp_linkmode_pri  : '0 ;
assign b_spif_sp.s_lp_linkmode      = (spif_tb_mode == 2'b00) ? b_spif_mp.s_lp_linkmode      : (spif_tb_mode == 2'b11) ? b_spif_tb.s_lp_linkmode      : '0 ;
assign b_spif_sp.s_lp_linkerror     = (spif_tb_mode == 2'b00) ? b_spif_mp.s_lp_linkerror     : (spif_tb_mode == 2'b11) ? b_spif_tb.s_lp_linkerror     : '0 ;
assign b_spif_sp.s_lp_clk_ack       = (spif_tb_mode == 2'b00) ? b_spif_mp.s_lp_clk_ack       : (spif_tb_mode == 2'b11) ? b_spif_tb.s_lp_clk_ack       : '0 ;
assign b_spif_sp.s_lp_wake_req      = (spif_tb_mode == 2'b00) ? b_spif_mp.s_lp_wake_req      : (spif_tb_mode == 2'b11) ? b_spif_tb.s_lp_wake_req      : '0 ;
assign b_spif_sp.s_lp_dl_active     = (spif_tb_mode == 2'b00) ? b_spif_mp.s_lp_dl_active     : (spif_tb_mode == 2'b11) ? b_spif_tb.s_lp_dl_active     : '0 ;
assign b_spif_sp.s_lp_rx_active_sts = (spif_tb_mode == 2'b00) ? b_spif_mp.s_lp_rx_active_sts : (spif_tb_mode == 2'b11) ? b_spif_tb.s_lp_rx_active_sts : '0 ;
assign b_spif_sp.s_lp_state_req     = (spif_tb_mode == 2'b00) ? b_spif_mp.s_lp_state_req     : (spif_tb_mode == 2'b11) ? b_spif_tb.s_lp_state_req     : RESET ;
assign b_spif_sp.s_lp_stall_ack     = (spif_tb_mode == 2'b00) ? b_spif_mp.s_lp_stall_ack     : (spif_tb_mode == 2'b11) ? b_spif_tb.s_lp_stall_ack     : '0 ;

assign b_spif_tb.s_pl_device_port   = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_device_port   : '0 ;
assign b_spif_tb.s_pl_phyinl1       = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_phyinl1       : '0 ;
assign b_spif_tb.s_pl_phyinl2       = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_phyinl2       : '0 ;
assign b_spif_tb.s_pl_phyinretrain  = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_phyinretrain  : '0 ;
assign b_spif_tb.s_pl_phyinrxl0s    = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_phyinrxl0s    : '0 ;
assign b_spif_tb.s_pl_phyrcvdeiosq  = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_phyrcvdeiosq  : '0 ;
assign b_spif_tb.s_pl_speedmode     = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_speedmode     : '0 ;
assign b_spif_tb.s_pl_bw_ratio      = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_bw_ratio      : '0 ;
assign b_spif_tb.s_pl_linkmode      = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_linkmode      : '0 ;
assign b_spif_tb.s_pl_protocol_vld  = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_protocol_vld  : '0 ;
assign b_spif_tb.s_pl_protocol      = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_protocol      : PCIE_MODE ;
assign b_spif_tb.s_pl_protocol_fmt  = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_protocol_fmt  : FMT_NONE_FLIT ;
assign b_spif_tb.s_pl_inband_pres   = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_inband_pres   : '0 ;
assign b_spif_tb.s_pl_link_up       = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_link_up       : '0 ;
assign b_spif_tb.s_pl_link_down     = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_link_down     : '0 ;
assign b_spif_tb.s_pl_clk_req       = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_clk_req       : '0 ;
assign b_spif_tb.s_pl_wake_ack      = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_wake_ack      : '0 ;
assign b_spif_tb.s_pl_block_dl_init = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_block_dl_init : '0 ;
assign b_spif_tb.s_pl_rx_active_req = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_rx_active_req : '0 ;
assign b_spif_tb.s_pl_stall_req     = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_stall_req     : '0 ;
assign b_spif_tb.s_pl_state_sts     = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_state_sts     : RESET ;

assign b_spif_tb.s_lp_linkmode_rmt  = (spif_tb_mode == 2'b10) ? b_spif_mp.s_lp_linkmode_rmt  : '0 ;
assign b_spif_tb.s_lp_linkmode_pri  = (spif_tb_mode == 2'b10) ? b_spif_mp.s_lp_linkmode_pri  : '0 ;
assign b_spif_tb.s_lp_linkmode      = (spif_tb_mode == 2'b10) ? b_spif_mp.s_lp_linkmode      : '0 ;
assign b_spif_tb.s_lp_linkerror     = (spif_tb_mode == 2'b10) ? b_spif_mp.s_lp_linkerror     : '0 ;
assign b_spif_tb.s_lp_clk_ack       = (spif_tb_mode == 2'b10) ? b_spif_mp.s_lp_clk_ack       : '0 ;
assign b_spif_tb.s_lp_wake_req      = (spif_tb_mode == 2'b10) ? b_spif_mp.s_lp_wake_req      : '0 ;
assign b_spif_tb.s_lp_dl_active     = (spif_tb_mode == 2'b10) ? b_spif_mp.s_lp_dl_active     : '0 ;
assign b_spif_tb.s_lp_rx_active_sts = (spif_tb_mode == 2'b10) ? b_spif_mp.s_lp_rx_active_sts : '0 ;
assign b_spif_tb.s_lp_state_req     = (spif_tb_mode == 2'b10) ? b_spif_mp.s_lp_state_req     : RESET ;
assign b_spif_tb.s_lp_stall_ack     = (spif_tb_mode == 2'b10) ? b_spif_mp.s_lp_stall_ack     : '0 ;
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// XPLH SPIF Interface Connections
// -------------------------------------------------------------------------------------
assign b_spif_mp.s_pl_dllp_trdy     = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_dllp_trdy    : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_dllp_trdy     : '0 ;
assign b_spif_mp.s_pl_skip_trdy     = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_skip_trdy    : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_skip_trdy     : '0 ;
assign b_spif_mp.s_pl_trdy          = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_trdy         : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_trdy          : '0 ;

assign b_spif_sp.s_lp_stream        = (spif_tb_mode == 2'b00) ? b_spif_mp.s_lp_stream       : (spif_tb_mode == 2'b11) ? b_spif_tb.s_lp_stream        : SID_RSVD ;
assign b_spif_sp.s_lp_irdy          = (spif_tb_mode == 2'b00) ? b_spif_mp.s_lp_irdy         : (spif_tb_mode == 2'b11) ? b_spif_tb.s_lp_irdy          : '0 ;
assign b_spif_sp.s_lp_pri           = (spif_tb_mode == 2'b00) ? b_spif_mp.s_lp_pri          : (spif_tb_mode == 2'b11) ? b_spif_tb.s_lp_pri           : '0 ;
assign b_spif_sp.s_lp_valid         = (spif_tb_mode == 2'b00) ? b_spif_mp.s_lp_valid        : (spif_tb_mode == 2'b11) ? b_spif_tb.s_lp_valid         : '0 ;
assign b_spif_sp.s_lp_data          = (spif_tb_mode == 2'b00) ? b_spif_mp.s_lp_data         : (spif_tb_mode == 2'b11) ? b_spif_tb.s_lp_data          : '0 ;
assign b_spif_sp.s_lp_crc_valid     = (spif_tb_mode == 2'b00) ? b_spif_mp.s_lp_crc_valid    : (spif_tb_mode == 2'b11) ? b_spif_tb.s_lp_crc_valid     : '0 ;
assign b_spif_sp.s_lp_crc_data      = (spif_tb_mode == 2'b00) ? b_spif_mp.s_lp_crc_data     : (spif_tb_mode == 2'b11) ? b_spif_tb.s_lp_crc_data      : '0 ;
assign b_spif_sp.s_lp_data_chk      = (spif_tb_mode == 2'b00) ? b_spif_mp.s_lp_data_chk     : (spif_tb_mode == 2'b11) ? b_spif_tb.s_lp_data_chk      : '0 ;
assign b_spif_sp.s_lp_rasdp_error   = (spif_tb_mode == 2'b00) ? b_spif_mp.s_lp_rasdp_error  : (spif_tb_mode == 2'b11) ? b_spif_tb.s_lp_rasdp_error   : '0 ;
assign b_spif_sp.s_lp_dlp_start     = (spif_tb_mode == 2'b00) ? b_spif_mp.s_lp_dlp_start    : (spif_tb_mode == 2'b11) ? b_spif_tb.s_lp_dlp_start     : '0 ;
assign b_spif_sp.s_lp_dlp_end       = (spif_tb_mode == 2'b00) ? b_spif_mp.s_lp_dlp_end      : (spif_tb_mode == 2'b11) ? b_spif_tb.s_lp_dlp_end       : '0 ;
assign b_spif_sp.s_lp_tlp_start     = (spif_tb_mode == 2'b00) ? b_spif_mp.s_lp_tlp_start    : (spif_tb_mode == 2'b11) ? b_spif_tb.s_lp_tlp_start     : '0 ;
assign b_spif_sp.s_lp_tlp_end       = (spif_tb_mode == 2'b00) ? b_spif_mp.s_lp_tlp_end      : (spif_tb_mode == 2'b11) ? b_spif_tb.s_lp_tlp_end       : '0 ;
assign b_spif_sp.s_lp_nop_flit      = (spif_tb_mode == 2'b00) ? b_spif_mp.s_lp_nop_flit     : (spif_tb_mode == 2'b11) ? b_spif_tb.s_lp_nop_flit      : '0 ;
assign b_spif_sp.s_lp_corrupt_crc   = (spif_tb_mode == 2'b00) ? b_spif_mp.s_lp_corrupt_crc  : (spif_tb_mode == 2'b11) ? b_spif_tb.s_lp_corrupt_crc   : '0 ;
assign b_spif_sp.s_lp_dllp_valid    = (spif_tb_mode == 2'b00) ? b_spif_mp.s_lp_dllp_valid   : (spif_tb_mode == 2'b11) ? b_spif_tb.s_lp_dllp_valid    : '0 ;
assign b_spif_sp.s_lp_dllp_ofc      = (spif_tb_mode == 2'b00) ? b_spif_mp.s_lp_dllp_ofc     : (spif_tb_mode == 2'b11) ? b_spif_tb.s_lp_dllp_ofc      : '0 ;
assign b_spif_sp.s_lp_dllp_data     = (spif_tb_mode == 2'b00) ? b_spif_mp.s_lp_dllp_data    : (spif_tb_mode == 2'b11) ? b_spif_tb.s_lp_dllp_data     : '0 ;

assign b_spif_tb.s_pl_dllp_trdy     = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_dllp_trdy     : '0 ;
assign b_spif_tb.s_pl_skip_trdy     = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_skip_trdy     : '0 ;
assign b_spif_tb.s_pl_trdy          = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_trdy          : '0 ;

assign b_spif_tb.s_lp_stream        = (spif_tb_mode == 2'b10) ? b_spif_mp.s_lp_stream        : SID_RSVD ;
assign b_spif_tb.s_lp_irdy          = (spif_tb_mode == 2'b10) ? b_spif_mp.s_lp_irdy          : '0 ;
assign b_spif_tb.s_lp_pri           = (spif_tb_mode == 2'b10) ? b_spif_mp.s_lp_pri           : '0 ;
assign b_spif_tb.s_lp_valid         = (spif_tb_mode == 2'b10) ? b_spif_mp.s_lp_valid         : '0 ;
assign b_spif_tb.s_lp_data          = (spif_tb_mode == 2'b10) ? b_spif_mp.s_lp_data          : '0 ;
assign b_spif_tb.s_lp_crc_valid     = (spif_tb_mode == 2'b10) ? b_spif_mp.s_lp_crc_valid     : '0 ;
assign b_spif_tb.s_lp_crc_data      = (spif_tb_mode == 2'b10) ? b_spif_mp.s_lp_crc_data      : '0 ;
assign b_spif_tb.s_lp_data_chk      = (spif_tb_mode == 2'b10) ? b_spif_mp.s_lp_data_chk      : '0 ;
assign b_spif_tb.s_lp_rasdp_error   = (spif_tb_mode == 2'b10) ? b_spif_mp.s_lp_rasdp_error   : '0 ;
assign b_spif_tb.s_lp_dlp_start     = (spif_tb_mode == 2'b10) ? b_spif_mp.s_lp_dlp_start     : '0 ;
assign b_spif_tb.s_lp_dlp_end       = (spif_tb_mode == 2'b10) ? b_spif_mp.s_lp_dlp_end       : '0 ;
assign b_spif_tb.s_lp_tlp_start     = (spif_tb_mode == 2'b10) ? b_spif_mp.s_lp_tlp_start     : '0 ;
assign b_spif_tb.s_lp_tlp_end       = (spif_tb_mode == 2'b10) ? b_spif_mp.s_lp_tlp_end       : '0 ;
assign b_spif_tb.s_lp_nop_flit      = (spif_tb_mode == 2'b10) ? b_spif_mp.s_lp_nop_flit      : '0 ;
assign b_spif_tb.s_lp_corrupt_crc   = (spif_tb_mode == 2'b10) ? b_spif_mp.s_lp_corrupt_crc   : '0 ;
assign b_spif_tb.s_lp_dllp_valid    = (spif_tb_mode == 2'b10) ? b_spif_mp.s_lp_dllp_valid    : '0 ;
assign b_spif_tb.s_lp_dllp_ofc      = (spif_tb_mode == 2'b10) ? b_spif_mp.s_lp_dllp_ofc      : '0 ;
assign b_spif_tb.s_lp_dllp_data     = (spif_tb_mode == 2'b10) ? b_spif_mp.s_lp_dllp_data     : '0 ;
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// RPLH SPIF Interface Connections
// -------------------------------------------------------------------------------------
assign b_spif_mp.s_pl_stream        = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_stream       : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_stream        : SID_RSVD ;
assign b_spif_mp.s_pl_valid         = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_valid        : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_valid         : '0 ;
assign b_spif_mp.s_pl_data          = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_data         : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_data          : '0 ;
assign b_spif_mp.s_pl_data_chk      = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_data_chk     : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_data_chk      : '0 ;
assign b_spif_mp.s_pl_crc_valid     = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_crc_valid    : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_crc_valid     : '0 ;
assign b_spif_mp.s_pl_crc_data      = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_crc_data     : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_crc_data      : '0 ;
assign b_spif_mp.s_pl_rx_flush      = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_rx_flush     : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_rx_flush      : '0 ;
assign b_spif_mp.s_pl_rx_nak        = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_rx_nak       : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_rx_nak        : '0 ;
assign b_spif_mp.s_pl_dlp_start     = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_dlp_start    : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_dlp_start     : '0 ;
assign b_spif_mp.s_pl_dlp_end       = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_dlp_end      : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_dlp_end       : '0 ;
assign b_spif_mp.s_pl_tlp_start     = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_tlp_start    : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_tlp_start     : '0 ;
assign b_spif_mp.s_pl_tlp_end       = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_tlp_end      : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_tlp_end       : '0 ;
assign b_spif_mp.s_pl_tlp_edb       = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_tlp_edb      : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_tlp_edb       : '0 ;
assign b_spif_mp.s_pl_error         = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_error        : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_error         : '0 ;
assign b_spif_mp.s_pl_nullified     = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_nullified    : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_nullified     : '0 ;
assign b_spif_mp.s_pl_poisoned      = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_poisoned     : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_poisoned      : '0 ;
assign b_spif_mp.s_pl_dllp_valid    = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_dllp_valid   : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_dllp_valid    : '0 ;
assign b_spif_mp.s_pl_dllp_ofc      = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_dllp_ofc     : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_dllp_ofc      : '0 ;
assign b_spif_mp.s_pl_dllp_data     = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_dllp_data    : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_dllp_data     : '0 ;

assign b_spif_tb.s_pl_stream        = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_stream        : SID_RSVD ;
assign b_spif_tb.s_pl_valid         = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_valid         : '0 ;
assign b_spif_tb.s_pl_data          = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_data          : '0 ;
assign b_spif_tb.s_pl_data_chk      = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_data_chk      : '0 ;
assign b_spif_tb.s_pl_crc_valid     = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_crc_valid     : '0 ;
assign b_spif_tb.s_pl_crc_data      = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_crc_data      : '0 ;
assign b_spif_tb.s_pl_rx_flush      = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_rx_flush      : '0 ;
assign b_spif_tb.s_pl_rx_nak        = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_rx_nak        : '0 ;
assign b_spif_tb.s_pl_dlp_start     = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_dlp_start     : '0 ;
assign b_spif_tb.s_pl_dlp_end       = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_dlp_end       : '0 ;
assign b_spif_tb.s_pl_tlp_start     = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_tlp_start     : '0 ;
assign b_spif_tb.s_pl_tlp_end       = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_tlp_end       : '0 ;
assign b_spif_tb.s_pl_tlp_edb       = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_tlp_edb       : '0 ;
assign b_spif_tb.s_pl_error         = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_error         : '0 ;
assign b_spif_tb.s_pl_nullified     = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_nullified     : '0 ;
assign b_spif_tb.s_pl_poisoned      = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_poisoned      : '0 ;
assign b_spif_tb.s_pl_dllp_valid    = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_dllp_valid    : '0 ;
assign b_spif_tb.s_pl_dllp_ofc      = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_dllp_ofc      : '0 ;
assign b_spif_tb.s_pl_dllp_data     = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_dllp_data     : '0 ;
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// CFGI SPIF Interface Connections
// -------------------------------------------------------------------------------------
assign b_spif_mp.s_pl_cfg_vld       = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_cfg_vld      : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_cfg_vld       : '0 ;
assign b_spif_mp.s_pl_cfg_data      = (spif_tb_mode == 2'b00) ? b_spif_sp.s_pl_cfg_data     : (spif_tb_mode == 2'b10) ? b_spif_tb.s_pl_cfg_data      : '0 ;

assign b_spif_sp.s_lp_cfg_vld       = (spif_tb_mode == 2'b00) ? b_spif_mp.s_lp_cfg_vld      : (spif_tb_mode == 2'b11) ? b_spif_tb.s_lp_cfg_vld       : '0 ;
assign b_spif_sp.s_lp_cfg_data      = (spif_tb_mode == 2'b00) ? b_spif_mp.s_lp_cfg_data     : (spif_tb_mode == 2'b11) ? b_spif_tb.s_lp_cfg_data      : '0 ;

assign b_spif_tb.s_pl_cfg_vld       = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_cfg_vld       : '0 ;
assign b_spif_tb.s_pl_cfg_data      = (spif_tb_mode == 2'b11) ? b_spif_sp.s_pl_cfg_data      : '0 ;

assign b_spif_tb.s_lp_cfg_vld       = (spif_tb_mode == 2'b10) ? b_spif_mp.s_lp_cfg_vld       : '0 ;
assign b_spif_tb.s_lp_cfg_data      = (spif_tb_mode == 2'b10) ? b_spif_mp.s_lp_cfg_data      : '0 ;
// -------------------------------------------------------------------------------------

endmodule
