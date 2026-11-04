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
// ---   $Revision: #3 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Spif/svif/spif_if.svh#3 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Link Layer to Packet Layer Interface (SPIF)
// ----------------------------------------------------------------------------
`ifndef __GUARD__SPIF_IF__SVH__
`define __GUARD__SPIF_IF__SVH__

interface spif_if

  import spif_pkg::SPIF_LP_NVLD;
  import spif_pkg::SPIF_PL_NVLD;
  import spif_pkg::SPIF_NBYTES;
  import spif_pkg::SPIF_NDPBITS;
  import spif_pkg::SPIF_NCRC;
  import spif_pkg::SPIF_NWORDS;
  import spif_pkg::SPIF_NDLLP;
  import spif_pkg::SPIF_NCFG;
  import spif_pkg::protocol_type_e;
  import spif_pkg::protocol_fmt_e;
  import spif_pkg::state_enc_e;
  import spif_pkg::stream_id_e;
  #();

  // Link vLSM to Protocol Data Link Layer Interface
  logic                      s_pl_device_port   ; // Packet Layer Device Port Mode: 0 - Upstream; 1 - Downstream
  logic                      s_pl_phyinl1       ; // Physical Layer is in L1
  logic                      s_pl_phyinl2       ; // Physical Layer is in L2
  logic                      s_pl_phyinretrain  ; // Physical Layer is in Retrain
  logic                      s_pl_phyinrxl0s    ; // Physical Layer RX is in L0s
  logic                      s_pl_phyrcvdeiosq  ; // Physical Layer Received EIOSQ Order Set
  logic [2:0]                s_pl_speedmode     ; // Physical Layer Speed Mode, Gen1 (000b), Gen2 (001b), Gen3 (010b), etc.
  logic [2:0]                s_pl_bw_ratio      ; // Current bandwidth ratio between Physical Layer and Link Layer: 1:1 (001b), 1:2 (010b), 1:4 (011b), 1:8 (100b), 1:16 (101b)
  logic [5:0]                s_pl_linkmode      ; // Physical Layer Link Mode, indicates width of the port:  x1 (000001b), x2, x4, x8, x16, x32 (100000b)
  logic                      s_pl_protocol_vld  ; // Packet Layer Protocol Valid
  protocol_type_e            s_pl_protocol      ; // Packet Layer Protocol Type
  protocol_fmt_e             s_pl_protocol_fmt  ; // Packet Layer Protocol Flit Format
  logic                      s_pl_inband_pres   ; // Packet Layer Inband Presence Detected
  logic                      s_pl_link_up       ; // Link Up state inidcation from Packet Layer
  logic                      s_pl_link_down     ; // Reporting surprise link down as seen by the Packet Layer
  logic                      s_pl_clk_req       ; // Physical Layer requests Link Layer to remove the clock gating from the internal logic
  logic                      s_pl_wake_ack      ; // Physical Layer responds to lp_wake_req after it has removed clock gating
  logic                      s_pl_block_dl_init ; // DL Init
  logic                      s_pl_rx_active_req ; // Packet Layer asserts this signal to request the Link Layer to open its
                                                  // Receiver's data path and get ready for receiving protocol data or Flits. The
                                                  // rising edge of this signal must be when pl_state_sts is Reset, Retrain or Active.
  logic                      s_pl_stall_req     ; // Packet Layer to Link Layer request to flush all packets
  state_enc_e                s_pl_state_sts     ; // Packet Layer to Link Layer state status

  // Transmit Datapath Signals from Packet Layer to Link Layer
  logic                      s_pl_trdy          ; // Packet Layer is ready to accept data
  logic                      s_pl_skip_trdy     ; // Packet Layer indicates that it is ready to insert Skip Ordered Set
  logic                      s_pl_dllp_trdy     ; // Packet Layer is ready to accept DLLP

  // Receive Datapath Signals from Packet Layer to Link Layer
  stream_id_e                s_pl_stream        ; // Packet Layer indicates the Stream ID to use with data
  logic [SPIF_PL_NVLD-1:0]   s_pl_valid         ; // Packet Layer indicates data valid on the corresponding pl_data bytes
  logic [SPIF_NBYTES*8-1:0]  s_pl_data          ; // Packet Layer data
  logic [SPIF_NDPBITS-1:0]   s_pl_data_chk      ; // Packet Layer data protection code
  logic                      s_pl_crc_valid     ; // Packet Layer indication that corresponding CRC bytes are valid
  logic [SPIF_NCRC*8-1:0]    s_pl_crc_data      ; // Packet Layer CRC bytes
  logic                      s_pl_rx_flush      ; // Packet Layer request Link Layer to flush its receiver pipeline
  logic [SPIF_NWORDS-1:0]    s_pl_rx_nak        ; // Packet Layer indicates to Link Layer that NAK is required

  // PCIe Framing-Related Signals from Packet Layer to Link Layer
  logic [SPIF_NWORDS-1:0]    s_pl_dlp_start     ; // Start of Data Link Layer Packet in the word
  logic [SPIF_NWORDS-1:0]    s_pl_dlp_end       ; // End of Data Link Layer Packet in the word
  logic [SPIF_NWORDS-1:0]    s_pl_tlp_start     ; // Start of Transaction Layer Packet in the word
  logic [SPIF_NWORDS-1:0]    s_pl_tlp_end       ; // End of Transaction Layer Packet in the word
  logic [SPIF_NWORDS-1:0]    s_pl_tlp_edb       ; // End of Nullified TLP (EDB) in the word
  logic                      s_pl_error         ; // Packet Layer to Link Layer indication of framing error

  logic                      s_pl_nullified     ; // Packet Layer to Link Layer - Last Nullified TLP Flit Marker
  logic                      s_pl_poisoned      ; // Packet Layer to Link Layer - Last Poisoned TLP Flit Marker
  logic                      s_pl_dllp_valid    ; // Packet Layer to Link Layer - DLLP Valid
  logic                      s_pl_dllp_ofc      ; // Packet Layer to Link Layer - DLLP Optimized_Update_FC
  logic [SPIF_NDLLP*8-1:0]   s_pl_dllp_data     ; // Packet Layer to Link Layer - DLLP Payload

  // Transmit Datapath Signals from Link Layer to Packet Layer
  stream_id_e                s_lp_stream        ; // Link Layer indicates the Stream ID to use with data
  logic                      s_lp_irdy          ; // Link Layer is ready to transfer data
  logic [1:0]                s_lp_pri           ; // Link Layer indicating priority of lp_irdy. lp_pri[0]==0: High; lp_pri[0]==1: Low.
  logic [SPIF_LP_NVLD-1:0]   s_lp_valid         ; // Link Layer indicates data valid on the corresponding lp_data bytes
  logic [SPIF_NBYTES*8-1:0]  s_lp_data          ; // Link Layer data
  logic                      s_lp_crc_valid     ; // Link Layer indication that corresponding CRC bytes are valid
  logic [SPIF_NCRC*8-1:0]    s_lp_crc_data      ; // Link Layer CRC bytes
  
  logic                      s_lp_corrupt_crc   ; // Link Layer indicates that the flit needs containment
  logic                      s_lp_nop_flit      ; // Link Layer indicates that the flit is NOP and is permitted to bypass TX Retry Buffer
  logic                      s_lp_dllp_valid    ; // Link Layer to Packet Layer - DLLP Valid
  logic                      s_lp_dllp_ofc      ; // Link Layer to Packet Layer - DLLP Optimized_Update_FC
  logic [SPIF_NDLLP*8-1:0]   s_lp_dllp_data     ; // Link Layer to Packet Layer - DLLP Payload
  logic [SPIF_NDPBITS-1:0]   s_lp_data_chk      ; // Link Layer data protection code
  logic                      s_lp_rasdp_error   ; // Link Layer indicates that the datapath protection error is detected in the Link Layer protocol stack

  // PCIe Framing-Related Signals from Link Layer to Packet Layer
  logic [SPIF_NWORDS-1:0]    s_lp_dlp_start     ; // Start of Data Link Layer Packet in the word
  logic [SPIF_NWORDS-1:0]    s_lp_dlp_end       ; // End of Data Link Layer Packet in the word
  logic [SPIF_NWORDS-1:0]    s_lp_tlp_start     ; // Start of Transaction Layer Packet in the word
  logic [SPIF_NWORDS-1:0]    s_lp_tlp_end       ; // End of Transaction Layer Packet in the word

  // State and Flow Control Signals from Link Layer to Packet Layer
  logic                      s_lp_linkmode_rmt  ; // Link Layer inidcates that the Link Mode change is requested by the remote partner
  logic                      s_lp_linkmode_pri  ; // Link Layer inidcates that the Link Mode change is a Priority request
  logic [5:0]                s_lp_linkmode      ; // Link Layer indicates the requested Link Mode:  x1 (000001b), x2, x4, x8, x16, x32 (100000b)
  logic                      s_lp_linkerror     ; // Link Layer to Packet Layer indication of fatal error that requires link down or link disable
  logic                      s_lp_dl_active     ; // DL Active
  logic                      s_lp_clk_ack       ; // Link Layer responds to pl_clk_req after it has removed clock gating
  logic                      s_lp_wake_req      ; // Link Layer requests Packet Layer to remove the clock gating from the internal logic of LogPHY
  logic                      s_lp_rx_active_sts ; // Link Layer responds to pl_rx_active_req after it is ready to receive and parse protocol data or Flits.
  logic                      s_lp_stall_ack     ; // Link Layer to Packet Layer stall request acknowledge
  state_enc_e                s_lp_state_req     ; // Link Layer to Packet Layer state change request

  // Configuration Interface Signals from Link Layer to Packet Layer
  logic                      s_lp_cfg_vld       ; // Configuration Interface packet valid
  logic [SPIF_NCFG-1:0]      s_lp_cfg_data      ; // Configuration Interface packet from Link Layer to Physical Layer

  // Configuration Interface Signals from Packet Layer to Link Layer
  logic                      s_pl_cfg_vld       ; // Configuration Interface packet valid
  logic [SPIF_NCFG-1:0]      s_pl_cfg_data      ; // Configuration Interface packet from Physical Layer to Link Layer

  modport master_mp (
    input     s_lp_cfg_vld,
    input     s_lp_cfg_data,
    input     s_lp_linkmode_rmt,
    input     s_lp_linkmode_pri,
    input     s_lp_linkmode,
    input     s_lp_linkerror,
    input     s_lp_clk_ack,
    input     s_lp_wake_req,
    input     s_lp_dl_active,
    input     s_lp_rx_active_sts,
    input     s_lp_state_req,
    input     s_lp_stall_ack,
    input     s_lp_stream,
    input     s_lp_irdy,
    input     s_lp_pri,
    input     s_lp_valid,
    input     s_lp_data,
    input     s_lp_crc_valid,
    input     s_lp_crc_data,
    input     s_lp_dlp_start,
    input     s_lp_dlp_end,
    input     s_lp_tlp_start,
    input     s_lp_tlp_end,
    input     s_lp_data_chk,
    input     s_lp_rasdp_error,
    input     s_lp_nop_flit,
    input     s_lp_corrupt_crc,
    input     s_lp_dllp_valid,
    input     s_lp_dllp_ofc,
    input     s_lp_dllp_data,
    output    s_pl_dllp_trdy,
    output    s_pl_trdy,
    output    s_pl_skip_trdy,
    output    s_pl_stream,
    output    s_pl_valid,
    output    s_pl_data,
    output    s_pl_data_chk,
    output    s_pl_crc_valid,
    output    s_pl_crc_data,
    output    s_pl_rx_flush,
    output    s_pl_rx_nak,
    output    s_pl_dlp_start,
    output    s_pl_dlp_end,
    output    s_pl_tlp_start,
    output    s_pl_tlp_end,
    output    s_pl_tlp_edb,
    output    s_pl_error,
    output    s_pl_nullified,
    output    s_pl_poisoned,
    output    s_pl_dllp_valid,
    output    s_pl_dllp_ofc,
    output    s_pl_dllp_data,
    output    s_pl_cfg_vld,
    output    s_pl_cfg_data,
    output    s_pl_device_port,
    output    s_pl_phyinl1,
    output    s_pl_phyinl2,
    output    s_pl_phyinretrain,
    output    s_pl_phyinrxl0s,
    output    s_pl_phyrcvdeiosq,
    output    s_pl_speedmode,
    output    s_pl_bw_ratio,
    output    s_pl_linkmode,
    output    s_pl_protocol_vld,
    output    s_pl_protocol,
    output    s_pl_protocol_fmt,
    output    s_pl_inband_pres,
    output    s_pl_link_up,
    output    s_pl_link_down,
    output    s_pl_clk_req,
    output    s_pl_wake_ack,
    output    s_pl_block_dl_init,
    output    s_pl_rx_active_req,
    output    s_pl_stall_req,
    output    s_pl_state_sts
  );

  modport slave_mp (
    output    s_lp_cfg_vld,
    output    s_lp_cfg_data,
    output    s_lp_linkmode_rmt,
    output    s_lp_linkmode_pri,
    output    s_lp_linkmode,
    output    s_lp_linkerror,
    output    s_lp_clk_ack,
    output    s_lp_wake_req,
    output    s_lp_dl_active,
    output    s_lp_rx_active_sts,
    output    s_lp_state_req,
    output    s_lp_stall_ack,
    output    s_lp_stream,
    output    s_lp_irdy,
    output    s_lp_pri,
    output    s_lp_valid,
    output    s_lp_data,
    output    s_lp_crc_valid,
    output    s_lp_crc_data,
    output    s_lp_dlp_start,
    output    s_lp_dlp_end,
    output    s_lp_tlp_start,
    output    s_lp_tlp_end,
    output    s_lp_data_chk,
    output    s_lp_rasdp_error,
    output    s_lp_nop_flit,
    output    s_lp_corrupt_crc,
    output    s_lp_dllp_valid,
    output    s_lp_dllp_ofc,
    output    s_lp_dllp_data,
    input     s_pl_dllp_trdy,
    input     s_pl_trdy,
    input     s_pl_skip_trdy,
    input     s_pl_stream,
    input     s_pl_valid,
    input     s_pl_data,
    input     s_pl_data_chk,
    input     s_pl_crc_valid,
    input     s_pl_crc_data,
    input     s_pl_rx_flush,
    input     s_pl_rx_nak,
    input     s_pl_dlp_start,
    input     s_pl_dlp_end,
    input     s_pl_tlp_start,
    input     s_pl_tlp_end,
    input     s_pl_tlp_edb,
    input     s_pl_error,
    input     s_pl_nullified,
    input     s_pl_poisoned,
    input     s_pl_dllp_valid,
    input     s_pl_dllp_ofc,
    input     s_pl_dllp_data,
    input     s_pl_cfg_vld,
    input     s_pl_cfg_data,
    input     s_pl_device_port,
    input     s_pl_phyinl1,
    input     s_pl_phyinl2,
    input     s_pl_phyinretrain,
    input     s_pl_phyinrxl0s,
    input     s_pl_phyrcvdeiosq,
    input     s_pl_speedmode,
    input     s_pl_bw_ratio,
    input     s_pl_linkmode,
    input     s_pl_protocol_vld,
    input     s_pl_protocol,
    input     s_pl_protocol_fmt,
    input     s_pl_inband_pres,
    input     s_pl_link_up,
    input     s_pl_link_down,
    input     s_pl_clk_req,
    input     s_pl_wake_ack,
    input     s_pl_block_dl_init,
    input     s_pl_rx_active_req,
    input     s_pl_stall_req,
    input     s_pl_state_sts
  );


// ----------------------------------------------------------------------------
// Sub-set of SMLH signals on SPIF Interface
// ----------------------------------------------------------------------------
  modport smlh_master_mp (
    input     s_lp_linkmode_rmt,
    input     s_lp_linkmode_pri,
    input     s_lp_linkmode,
    input     s_lp_linkerror,
    input     s_lp_clk_ack,
    input     s_lp_wake_req,
    input     s_lp_dl_active,
    input     s_lp_rx_active_sts,
    input     s_lp_state_req,
    input     s_lp_stall_ack,
    output    s_pl_device_port,
    output    s_pl_phyinl1,
    output    s_pl_phyinl2,
    output    s_pl_phyinretrain,
    output    s_pl_phyinrxl0s,
    output    s_pl_phyrcvdeiosq,
    output    s_pl_speedmode,
    output    s_pl_bw_ratio,
    output    s_pl_linkmode,
    output    s_pl_protocol_vld,
    output    s_pl_protocol,
    output    s_pl_protocol_fmt,
    output    s_pl_inband_pres,
    output    s_pl_link_up,
    output    s_pl_link_down,
    output    s_pl_clk_req,
    output    s_pl_wake_ack,
    output    s_pl_block_dl_init,
    output    s_pl_rx_active_req,
    output    s_pl_stall_req,
    output    s_pl_state_sts
  );

  modport smlh_slave_mp (
    output    s_lp_linkmode_rmt,
    output    s_lp_linkmode_pri,
    output    s_lp_linkmode,
    output    s_lp_linkerror,
    output    s_lp_clk_ack,
    output    s_lp_wake_req,
    output    s_lp_dl_active,
    output    s_lp_rx_active_sts,
    output    s_lp_state_req,
    output    s_lp_stall_ack,
    input     s_pl_device_port,
    input     s_pl_phyinl1,
    input     s_pl_phyinl2,
    input     s_pl_phyinretrain,
    input     s_pl_phyinrxl0s,
    input     s_pl_phyrcvdeiosq,
    input     s_pl_speedmode,
    input     s_pl_bw_ratio,
    input     s_pl_linkmode,
    input     s_pl_protocol_vld,
    input     s_pl_protocol,
    input     s_pl_protocol_fmt,
    input     s_pl_inband_pres,
    input     s_pl_link_up,
    input     s_pl_link_down,
    input     s_pl_clk_req,
    input     s_pl_wake_ack,
    input     s_pl_block_dl_init,
    input     s_pl_rx_active_req,
    input     s_pl_stall_req,
    input     s_pl_state_sts
  );

  modport smlh_sts_master_mp (
    output    s_pl_device_port,
    output    s_pl_phyinl1,
    output    s_pl_phyinl2,
    output    s_pl_phyinretrain,
    output    s_pl_phyinrxl0s,
    output    s_pl_phyrcvdeiosq,
    output    s_pl_speedmode,
    output    s_pl_bw_ratio,
    output    s_pl_linkmode,
    output    s_pl_protocol_vld,
    output    s_pl_protocol,
    output    s_pl_protocol_fmt,
    output    s_pl_inband_pres,
    output    s_pl_link_up,
    output    s_pl_link_down
  );

  modport smlh_sts_slave_mp (
    input     s_pl_device_port,
    input     s_pl_phyinl1,
    input     s_pl_phyinl2,
    input     s_pl_phyinretrain,
    input     s_pl_phyinrxl0s,
    input     s_pl_phyrcvdeiosq,
    input     s_pl_speedmode,
    input     s_pl_bw_ratio,
    input     s_pl_linkmode,
    input     s_pl_protocol_vld,
    input     s_pl_protocol,
    input     s_pl_protocol_fmt,
    input     s_pl_inband_pres,
    input     s_pl_link_up,
    input     s_pl_link_down
  );
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// Sub-set of XPLH signals on SPIF Interface
// ----------------------------------------------------------------------------
  modport xplh_master_mp (
    input     s_lp_stream,
    input     s_lp_irdy,
    input     s_lp_pri,
    input     s_lp_valid,
    input     s_lp_data,
    input     s_lp_crc_valid,
    input     s_lp_crc_data,
    input     s_lp_dlp_start,
    input     s_lp_dlp_end,
    input     s_lp_tlp_start,
    input     s_lp_tlp_end,
    input     s_lp_data_chk,
    input     s_lp_rasdp_error,
    input     s_lp_nop_flit,
    input     s_lp_corrupt_crc,
    input     s_lp_dllp_valid,
    input     s_lp_dllp_ofc,
    input     s_lp_dllp_data,
    output    s_pl_dllp_trdy,
    output    s_pl_trdy,
    output    s_pl_skip_trdy
  );

  modport xplh_slave_mp (
    output    s_lp_stream,
    output    s_lp_irdy,
    output    s_lp_pri,
    output    s_lp_valid,
    output    s_lp_data,
    output    s_lp_crc_valid,
    output    s_lp_crc_data,
    output    s_lp_dlp_start,
    output    s_lp_dlp_end,
    output    s_lp_tlp_start,
    output    s_lp_tlp_end,
    output    s_lp_data_chk,
    output    s_lp_rasdp_error,
    output    s_lp_nop_flit,
    output    s_lp_corrupt_crc,
    output    s_lp_dllp_valid,
    output    s_lp_dllp_ofc,
    output    s_lp_dllp_data,
    input     s_pl_dllp_trdy,
    input     s_pl_trdy,
    input     s_pl_skip_trdy
  );
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// Sub-set of RPLH signals on SPIF Interface
// ----------------------------------------------------------------------------
  modport rplh_master_mp (
    output    s_pl_stream,
    output    s_pl_valid,
    output    s_pl_data,
    output    s_pl_data_chk,
    output    s_pl_crc_valid,
    output    s_pl_crc_data,
    output    s_pl_rx_flush,
    output    s_pl_rx_nak,
    output    s_pl_dlp_start,
    output    s_pl_dlp_end,
    output    s_pl_tlp_start,
    output    s_pl_tlp_end,
    output    s_pl_tlp_edb,
    output    s_pl_error
    ,
    output    s_pl_nullified,
    output    s_pl_poisoned,
    output    s_pl_dllp_valid,
    output    s_pl_dllp_ofc,
    output    s_pl_dllp_data
  );

  modport rplh_slave_mp (
    input     s_pl_stream,
    input     s_pl_valid,
    input     s_pl_data,
    input     s_pl_data_chk,
    input     s_pl_crc_valid,
    input     s_pl_crc_data,
    input     s_pl_rx_flush,
    input     s_pl_rx_nak,
    input     s_pl_dlp_start,
    input     s_pl_dlp_end,
    input     s_pl_tlp_start,
    input     s_pl_tlp_end,
    input     s_pl_tlp_edb,
    input     s_pl_error
    ,
    input     s_pl_nullified,
    input     s_pl_poisoned,
    input     s_pl_dllp_valid,
    input     s_pl_dllp_ofc,
    input     s_pl_dllp_data
  );
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// Sub-set of Configuration Interface signals on SPIF Interface
// ----------------------------------------------------------------------------
  modport cfgi_master_mp (
    input     s_lp_cfg_vld,
    input     s_lp_cfg_data,
    output    s_pl_cfg_vld,
    output    s_pl_cfg_data
  );

  modport cfgi_slave_mp (
    output    s_lp_cfg_vld,
    output    s_lp_cfg_data,
    input     s_pl_cfg_vld,
    input     s_pl_cfg_data
  );
// ----------------------------------------------------------------------------


endinterface : spif_if

`endif // __GUARD__SPIF_IF__SVH__
