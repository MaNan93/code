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
// ---  RCS information:
// ---    $DateTime: 2024/01/22 13:12:34 $
// ---    $Revision: #12 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/products/cx_lp.sv#12 $
// -------------------------------------------------------------------------
// --- Module Description: PCI-Express Core (Layers 2 and 3)
// -----------------------------------------------------------------------------
// --- This module contains PCIe/CXL.io DataLink layer and Transation layer.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer2/svif/tx_lp_if.svh"
`include "Spif/pkg/spif_pkg.svh"
`include "Spif/svif/spif_if.svh"
`include "products/cx_pl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "power_management/DWC_pcie_pm_pkg.svh"

module cx_lp 
    import cx_pl_pkg::rbuf_struct;
    import cx_pl_pkg::dllp_struct;
    import cx_pl_pkg::tx_cmd_struct;
    import cx_pl_pkg::NFM_DW_W_PAR;
    import cx_pl_pkg::P_NFM_RBUF_WD;
    import cx_pl_pkg::l0p_dllp_struct;
    import cx_pl_pkg::l0p_ack_struct;
    import cx_pl_pkg::fm_dllp_struct;
    import cx_pl_pkg::tx_flit_struct;
    import DWC_pcie_core_pkg::rtlh_rfc_t;
    import DWC_pcie_core_pkg::rtlh_radm_datapath_t;
    import DWC_pcie_ctl_pkg::N_XADM_IF;
    import DWC_pcie_ctl_pkg::N_XADM_P_IF;
    import DWC_pcie_core_pkg::xtlh_pkt_t;
    import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
    import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
    import spif_pkg::link_adm_if_t;
    import spif_pkg::protocol_cfg_t;
    import spif_pkg::ACTIVE;
    import spif_pkg::RETRAIN;
    import spif_pkg::IDLE_L1_1;
    import spif_pkg::L2;
    import spif_pkg::SPIF_NWORDS;
    import spif_pkg::ACTIVE_L0S_PMNAK;
    import spif_pkg::RESET;
    import spif_pkg::DISABLED;
    import spif_pkg::LINKRESET;
    import spif_pkg::LINKERROR;
  import DWC_pcie_pm_pkg::usp_prot_fsm_state_e;
  import DWC_pcie_pm_pkg::dsp_prot_fsm_state_e;
  import DWC_pcie_pm_pkg::pm_active_l0s_fsm_e;
  import DWC_pcie_pm_pkg::pm_protocol_to_link_struct;
  import DWC_pcie_pm_pkg::pm_link_to_protocol_struct;
#(
    parameter   INST                     = 0,                              // The uniquifying parameter for each port logic instance.
    parameter   NB                       = `CX_NB,                         // Number of symbols (bytes) per clock cycle
    parameter   NW                       = `CX_NW,                         // Number of 32-bit dwords handled by the datapath each clock.
    parameter   NW_NFM                   = (NW > 16) ? 16 : NW,            // Number of 32-bit dwords handled by the datapath each clock in Non-Flit Mode.
    parameter   DATA_PAR_WD              = `TRGT_DATA_PROT_WD,             // data bus parity width
    parameter   DW_W_PAR                 = (32*NW)+DATA_PAR_WD,            // Width of datapath in bits plus the parity bits.
    parameter   DW_WO_PAR                = (32*NW),                        // Width of datapath in bits.
    parameter   RAS_PCIE_HDR_PROT_WD     = `CX_RAS_PCIE_HDR_PROT_WD,
    parameter   TX_HW_W_PAR              = 128 + RAS_PCIE_HDR_PROT_WD,
    parameter   NF                       = `CX_NFUNC,                      // Number of functions
    parameter   NVC                      = `CX_NVC,                        // Number of virtual channels
    parameter   RX_NDLLP                 = `CX_RX_NDLLP,                   // Max number of DLLPs received per cycle
    parameter   TX_NDLLP                 = `CX_TX_NDLLP,
    parameter   RX_TLP                   = `CX_RX_TLP,                     // Number of TLPs that can be processed in a single cycle
    parameter   DCAW                     = `CX_LOGBASE2(NW/4+1),           // Number of bits needed to represent the maximum number 
                                                                           // of Data CA returned from the radm (512:3, 256:2, 128 or below:1)
    parameter   RBUF_WD_NFM              = (NW>16) ? P_NFM_RBUF_WD : `RBUF_WIDTH,
    parameter   RBUF_PW                  = `RBUF_PW,
    parameter   SOTBUF_WD                = `SOTBUF_WIDTH,
    parameter   SOTBUF_PW                = `SOTBUF_L2DEPTH,                // Indexed by sequence number (or some bits of it)
    parameter   CNT_WIDTH                = 3,
    parameter   DEVNUM_WD                = `CX_DEVNUM_WD,
    parameter   NW_PRFX                  = `CX_NPRFX,
    parameter   PRFX_PAR_WD              = `CX_PRFX_PAR_WD,
    parameter   PRFX_DW                  = (32*NW_PRFX)+ PRFX_PAR_WD,
    parameter   NUM_EOT                  = `CX_NUM_EOT,
    parameter   RAS_RDLH_COUNTERS        = `CX_RAS_RDLH_COUNTERS,
    parameter   RAS_RTLH_COUNTERS        = `CX_RAS_RTLH_COUNTERS,
    parameter   ERROR_INJ_EN_WD          = `CX_RAS_ERROR_INJ_EN_WD,
    parameter   ERROR_INJ_MASK_WD        = `CX_RAS_ERROR_INJ_MASK_WD,
    parameter   HCRD_WD                  = `SCALED_FC_SUPPORTED ? 12 : 8,
    parameter   DCRD_WD                  = `SCALED_FC_SUPPORTED ? 16 : 12,
    parameter   TAG_SIZE                 = `CX_TAG_SIZE,
    parameter   CTL_WD                   = (NW >= 16) ? 16 : `CX_XTLH_XDLH_CTL_WD,
    parameter   TP                       = `TP,       // Clock to Q delay (simulator insurance)
    parameter   INT_NVF                  = `CX_INTERNAL_NVFUNC          // Number of Internal virtual functions
) 
                (
// ----------------------------------------------------------------------------
// Interfaces
// ----------------------------------------------------------------------------
    spif_if.slave_mp                b_sdlh_splh_spif,               // Link Layer to Packet Layer SPIF Interface
    spif_if.cfgi_master_mp          b_cfgi_lbc,                     // SPIF.CFG Interface
    tx_lp_if.master_mp              b_xdlh_xplh,                    // XDLH -> XPLH Transmit Interface
// ----------------------------------------------------------------------------
// Clock and Reset
// ----------------------------------------------------------------------------
    input                           core_clk,                       // Core clock
    input                           core_rst_n,                     // When asserted, reset the core except for the PMC domain.
// ----------------------------------------------------------------------------
// Top-Level Interface
// ----------------------------------------------------------------------------
    input  [3:0]                    device_type,                    // Device Type
    input                           pm_rstctl_core_flush_req,
    input                           rstctl_core_flush_req,
// ----------------------------------------------------------------------------
// Configuration Interface
// ----------------------------------------------------------------------------
    input                           cfg_endpoint,                   // Endpoint device when it is high
    input                           cfg_upstream_port,              // Upstream port when it is high
    input                           cfg_root_compx,                 // Root complex port
    input                           cfg_dll_lnk_en,                 // Data link layer link enabled when it is asserted. This is a debug
                                                                    // feature. Default is 1. It enables data link control and management
                                                                    // state machine.
    input  [7:0]                    cfg_ack_freq,                   // ACK frequency. It is the number of ACK that is allowed to coalesce when
                                                                    // timer is not expired. Default is 1 which will enable ACK on every TLP received.
    input  [15:0]                   cfg_ack_latency_timer,          // ACK latency timer. Default value is expected to be chosen from table 3-5
                                                                    // of Specification1.0a based on different application.
    input  [16:0]                   cfg_replay_timer_value,         // Replay Timer value.  Default value is expected to be chosen from table 3-4
                                                                    // of Specification1.0a based on different application.
    input  [12:0]                   cfg_fc_latency_value,           // FC update latency timer value
    input  [31:0]                   cfg_other_msg_payload,          // Other MSG payload, for test equipment purpose. It is a way to allow a DLLP
                                                                    // message being sent by CORE.
    input                           cfg_other_msg_request,          // Other MSG request, for test equipment purpose. Control signal for the request.
    input  [31:0]                   cfg_corrupt_crc_pattern,        // Corrupted CRC pattern, for test equipment purpose. It carries corruption pattern.
    input                           cfg_flow_control_disable,       // Disable flow control. This disables the flow control DLLP generation. It is
                                                                    // for test/debug purpose. Default should be 0.
    input                           cfg_acknack_disable,            // ACK/NACK disable. For test/debug purpose. Default is 0.
    input                           cfg_ext_synch,                  // Extended synch. This is only asserted if PHY is desired to have it. Otherwise,
                                                                    // default is 0.
    input  [2:0]                    cfg_max_payload,                // MTU size. It is chosen by application. Default is 001 for 256Bytes.
    input  [2:0]                    cfg_max_payload_rx,             // In flit mode, The max payload -also known as "RX_MPS_limit"- has the value from the 'max_payload_size_supported' field.
    input  [7:0]                    cfg_tc_enable,                  // Supported highest TC. Report error if received tc number is higher than this.
                                                                    // Default is at 7. All TC traffic is supported.
    input  [NVC-1:0]                cfg_vc_enable,                  // Per VC enable
    input  [3*NVC-1:0]              cfg_vc_struc_vc_id_map,         // Virtual channel structure to virtual channel ID map.
    input  [23:0]                   cfg_vc_id_vc_struc_map,         // vc id to structure id map
    input  [23:0]                   cfg_tc_struc_vc_map,            // Index by TC, returns VC
    input                           cfg_fc_wdog_disable,            // disable watch dog timer in FC for some debug purpose
    input  [(NVC*8)-1:0]            cfg_fc_credit_ph,               // Posted header wire to control the FC initial value for FC credit advertisement
    input  [(NVC*8)-1:0]            cfg_fc_credit_nph,              // Nonposted header wire to control the FC initial value for FC credit advertisement
    input  [(NVC*8)-1:0]            cfg_fc_credit_cplh,             // Completion header Wire to control the FC initial value for FC credit advertisement
    input  [(NVC*12)-1:0]           cfg_fc_credit_pd,               // Posted data wire to control the FC initial value for FC credit advertisement
    input  [(NVC*12)-1:0]           cfg_fc_credit_npd,              // Nonposted data wire to control the FC initial value for FC credit advertisement
    input  [(NVC*12)-1:0]           cfg_fc_credit_cpld,             // Completion data wire to control the FC initial value for FC credit advertisement
    input                           dl_feature_en,                  // Indicates Data Link Features supported
    input                           cfg_remote_feature_ack,         // Indicates remote Data Link Features handshake completed
    input  [22:0]                   cfg_local_feature_support,      // Local Feature (Including local scaled flow control) Support
    input                           cfg_dlink_feature_valid,        // Has received a Data Link Feature DLLP after the Link entered L0
    input                           fc_scaled_en,
    input  [(NVC*2)-1:0]            hdr_scale_p,                    // The HdrScale field contains the scaling factor for headers of the indicated type
    input  [(NVC*2)-1:0]            hdr_scale_np,                   // The HdrScale field contains the scaling factor for headers of the indicated type
    input  [(NVC*2)-1:0]            hdr_scale_cpl,                  // The HdrScale field contains the scaling factor for headers of the indicated type
    input  [(NVC*2)-1:0]            data_scale_p,                   // The DataScale field contains the scaling factor for payload data of the indicated type
    input  [(NVC*2)-1:0]            data_scale_np,                  // The DataScale field contains the scaling factor for payload data of the indicated type
    input  [(NVC*2)-1:0]            data_scale_cpl,                 // The DataScale field contains the scaling factor for payload data of the indicated type
    input  [(2*NF)-1:0]             cfg_max_end2end_tlp_prfxs,      // the maximum number of End-End TLP Prefixes supported; DBI writeable.
    input                           dpc_fatal_err_gate,             // DPC trigger gating for fatal error message
    input                           dpc_nonfatal_err_gate,          // DPC trigger gating for non-fatal error message
    input                           cfg_p2p_track_cpl_to,
    input                           cfg_l0p_enable,                 // L0p Enable
    input                           cfg_l0p_autowidth_dis,          // Hardware Autonomous Width Disable bit in the Link Control register (bit[9])
    input                           cfg_l0p_priority,               // Port Logic register bit to set L0p.Priority bit in DLLP
    input  [2:0]                    cfg_l0p_linkmode,               // Target Link Width in Device Control 3 Register (bit[6:4])
    input                           cfg_l0p_linkmode_req,           // Link Width change request asserted on the write access to Device Control 3 Register
    input  [5:0]                    cfg_l0p_max_link_width,         // TOVEREMOVED: Maximum supported Link Width
    input  [5:0]                    cfg_l0p_neg_link_width,         // TOVEREMOVED: Negotiated Link Width
    input                           cfg_pcie_l0p_disable,           // PCIe/CXL.io: Disable dynamic L0p
    input                           cfg_pcie_l0p_request,           // PCIe/CXL.io: L0p Request bit
    input                           cfg_pcie_l0p_priority,          // PCIe/CXL.io: L0p Priority bit
    input  [2:0]                    cfg_pcie_l0p_linkmode,          // PCIe/CXL.io: L0p Target Link Width
    output logic                    app_dynamic_l0p_enable,         // Application Interface signal indicates that Dynamic L0p is enabled
    output logic                    app_dynamic_l0p_rejected,       // Application Interface signal indicates that L0p request is NAK-ed
    input                           cdm_err_inj_en,                      
    input                           cdm_tx_err_inj_en,             
// ----------------------------------------------------------------------------
// RAS-DES Interface (Inputs)
// ----------------------------------------------------------------------------
    input                           cdm_ras_des_force_linkdown_noack,// Level : Force Link down when MAC does not receive ACK DLLP for long time
    input                           cdm_ras_des_einj0_enable,       // Error injection 0 enable
    input  [3:0]                    cdm_ras_des_einj0_crc_type,     // Error injection 0 CRC type
    input  [7:0]                    cdm_ras_des_einj0_count,        // Error injection 0 count
    input                           cdm_ras_des_einj1_enable ,      // Error injection 1 enable
    input                           cdm_ras_des_einj1_seq_type ,    // Error injection 1 seq# type
    input  [12:0]                   cdm_ras_des_einj1_bad_seq ,     // Error injection 1 bad seq# value
    input  [7:0]                    cdm_ras_des_einj1_count ,       // Error injection 1 count
    input                           cdm_ras_des_einj2_enable,       // Error injection 2 enable
    input  [1:0]                    cdm_ras_des_einj2_dllp_type,    // Error injection 2 DLLP type
    input                           cdm_ras_des_einj4_enable,       // Error injection 4 enable
    input  [2:0]                    cdm_ras_des_einj4_updfc_type,   // Error injection 4 UpdateFC type
    input  [2:0]                    cdm_ras_des_einj4_vcnum,        // Error injection 4 VC number
    input  [12:0]                   cdm_ras_des_einj4_badfc_value,  // Error injection 4 bad FC value
    input                           cdm_ras_des_einj5_enable,       // Error injection 5 enable
    input  [7:0]                    cdm_ras_des_einj5_count,        // Error injection 5 count
    input                           cdm_ras_des_einj5_tlp_type,     // Error injection 5 tlp type (dup/nul)
// ----------------------------------------------------------------------------
// RAS Interface
// ----------------------------------------------------------------------------
    input                           cfg_rasdp_linkdown_en,          // Enable Link Down on RASDP uncorrectable error
    input                           cfg_rasdp_error_mode_en,
    input                           cfg_rasdp_error_mode,
    input  [6:0]                    ras_prot_t_disable,
    input  [6:0]                    ras_prot_r_disable,
    input  [ERROR_INJ_EN_WD  -1:0]  ras_err_inj_en_array,
    input  [ERROR_INJ_MASK_WD-1:0]  ras_err_inj_mask,
    input  ras_dp_err_inj_t         ras_dp_err_inj,
// ----------------------------------------------------------------------------
// CRC Error Injection Interface (Inputs)
// ----------------------------------------------------------------------------
    input                           lcrc_err_en,
    input                           ecrc_err_en,
// ----------------------------------------------------------------------------
// PM Controller Interface
// ----------------------------------------------------------------------------
    input                           pm_cfg_retrain_req,             // Config Retrain Request (latched in PM Wakeup)
    input                           pm_app_init_rst,                // Application Link Reset Request (latched in PM Wakeup)
    output protocol_cfg_t           sdlh_protocol_cfg,              // Protocol Configuration for DLH Layer
    output link_adm_if_t            pcie_link_adm_if,               // PCIe Link Layer to ADM Interface
    output dllp_struct              pm_xdlh_dllp_req,
    input                           pm_xtlh_block_tlp,              // PMC directs XTLH to block TLP
    output logic                    pm_xmlh_lp_req,                 // PM Request to xtlh_cmd_if to enter low power
    output                          xdlh_not_expecting_ack,         // Transmitter has received all its ACKs for all transmitted TLPs. It is a signal
                                                                    // for PMC.
    output                          xdlh_nodllp_pending,            // XDLH has no dllp pending. It is a signal for PMC (power management module).
    output                          xdlh_no_acknak_dllp_pending,    // XDLH has no ACK/NAK dllp pending. It is a signal for PMC (power management module).
    input                           xdlh_no_acknak_dllp_pending_s,  // XDLH has no ACK/NAK dllp pending. It is a signal for PMC (power management module).
    output                          xdlh_xmt_pme_ack,               // XDLH sends acknowledgement to the requester (PMC) block to indicate a completion
    output                          xtlh_pm_pme_to_ack,
// ----------------------------------------------------------------------------
// RX Application Layer Interface (to/from RADM)
// ----------------------------------------------------------------------------
    input  [DCAW*NVC-1:0]           radm_rtlh_ph_ca,                // Credit allocated (posted header)
    input  [DCAW*NVC-1:0]           radm_rtlh_pd_ca,                // Credit allocated (posted data)
    input  [DCAW*NVC-1:0]           radm_rtlh_nph_ca,               // Credit allocated (non-posted header)
    input  [DCAW*NVC-1:0]           radm_rtlh_npd_ca,               // Credit allocated (non-posted data)
    input  [DCAW*NVC-1:0]           radm_rtlh_cplh_ca,              // Credit allocated (completion header)
    input  [DCAW*NVC-1:0]           radm_rtlh_cpld_ca,              // Credit allocated (completion data)
    output rtlh_radm_datapath_t     rtlh_radm,                      // RTLH to RADM datapath structure
// ----------------------------------------------------------------------------
// TX Application Layer Interface (to/from XADM)
// ----------------------------------------------------------------------------
    input                           xadm_all_type_infinite,         // XADM FC book keeping block indicates that remote link advertised all FC credits to infinite.
    input  xtlh_pkt_t  [N_XADM_IF-1:0] xadm_xtlh_pkt,               // XADM Packet Interfaces
    output [N_XADM_IF-1:0]          xtlh_xadm_pkt_halt,             // XTLH XADM Packet Halts
    output [N_XADM_P_IF-1:0]        xtlh_xadm_posted_tlp_sent,


// ----------------------------------------------------------------------------
// Native Link Layer to Packet Layer Interface (to be removed after SPIF adoption)
// ----------------------------------------------------------------------------
    output                          pm_prot_req_l2,                 // PM Protocol FSM requests Link Layer to enter L2
    output                          pm_block_tlp_ack,               // SDLH Command Interface PM BLOCK_TLP Acknowledge
    input                           smlh_flit_mode_enable,
    input  [7:0]                    smlh_flit_mode_enable_modules,  // both sides agreed to support flit mode per modules [0] rmlh [1] rplh [2] rdlh [3] xfsh/rfsh [4] xmlh [5] xdlh [6] xplh [7] xtlh
    input  [5:0]                    smlh_link_mode,                 // 6 bit link width; 10000 = x16, 1000 = x8, 100 = x4, 10 = x2, 1 = x1
    input  [5:0]                    smlh_link_rxmode,               // 6 bit link width; 10000 = x16, 1000 = x8, 100 = x4, 10 = x2, 1 = x1
    input                           smlh_link_up,                   // Link state machine is in link up when asserted.
    input                           smlh_in_l0,                     // LTSSM in l0
    input                           smlh_in_l0s,                    // LTSSM Transmitter in l0s
    input                           smlh_in_rl0s,                   // LTSSM Receiver in rL0s
    input                           smlh_in_l1,                     // LTSSM  in L1
    input                           smlh_link_in_training,          // LTSSM in Recovery
    input                           smlh_in_l23,                    // LTSSM  in L23
    input                           smlh_l123_eidle_timeout,        // LTSSM 2ms Timer timeout waiting for EIDLE
    input                           latched_rcvd_eidle_set,
    input                           smlh_eq_pending,                // Equalization Pending
    input                           smlh_usp_eq_pending,
    input                           smlh_l0p_capable,               // l0p capable
    input  [5:0]                    smlh_l0p_link_mode,             // 10000 -- x16, 01000 -- x8, 00100 -- x4, 00010 -- x2, 00001 -- x1
    input                           smlh_ltssm_l0p_ready,
    input                           smlh_xdlh_eios_rcvd,            // Received eieos in flit mode
    output logic                    xdlh_smlh_enter_recovery,
    output                          xdlh_smlh_link_req,
    output [4:0]                    xdlh_smlh_link_width,
    output                          xdlh_smlh_link_initiated,
    input  [2:0]                    pm_current_data_rate_others,    // 0=running at gen1 speeds, 1=running at gen2 speeds, 2=running at gen3 data rate, 3=running at gen4 data rate
    input                           xmlh_xplh_halt,                 // Halt transmit datapath
    input  [NW_NFM-1:0]             xplh_xmlh_eot,                  // Indicates which DW contains end of TLP/DLLP
    output                          xdlh_smlh_start_link_retrain,
    output                          rtlh_req_link_retrain,

    input  [NW-1:0]                 rplh_rdlh_dllp_start,           // 1-4  for 4dword, indicates which DW is start of DLP
    input  [NW-1:0]                 rplh_rdlh_tlp_start,            // 1-4  for 4dword, indicates which DW is start of TLP
    input  [NW-1:0]                 rplh_rdlh_pkt_end,              // 1-4  for 4dword, indicates which DW is pkt good end
    input  [NW-1:0]                 rplh_rdlh_pkt_edb,              // 1-4  for 4dword, indicates which DW is pkt bad end
    input  [DW_W_PAR-1:0]           rplh_rdlh_pkt_data,             // Packet data bus.
    input                           rplh_rdlh_pkt_dv,               // Packet data is valid.
    input  [NW-1:0]                 rplh_rdlh_pkt_err,              // Framing error or phy_error
    input  [NW-1:0]                 rplh_rdlh_nak,                  // NAK indication
    input  [NW-1:0]                 rplh_rdlh_tlp_idl,
    input  [NW-1:0]                 rplh_rdlh_tlp_pfx,
    input                           rplh_rdlh_fm_nullified,         // The last TLP ending was Nullified by the Flit Marker
    input                           rplh_rdlh_fm_poisoned,          // The last TLP ending was Poisoned by the Flit Marker
    input  [31:0]                   rplh_rdlh_fm_dllp_data,         // DLLP data extracted from DL bytes
    input                           rplh_rdlh_fm_dllp_valid,        // Valid DLLP data
    input                           rplh_rdlh_fm_dllp_opt_fc_up,    // DLLP is an Optimized FC update
    input                           rplh_ptm_sot,
    input                           rplh_ptm_request,
    input                           rplh_ptm_response,
    input                           rplh_ptm_duplicate,
    input                           xplh_ptm_sot,
    input                           xplh_ptm_request,
    input                           xplh_ptm_response,
    input                           xplh_ptm_retry_flit,
    input                           xmtbyte_stp_start,
    input                           xplh_ras_des_einj2_enable,      // Error injection 2 enable
    input  [1:0]                    xplh_ras_des_einj2_dllp_type,   // Error injection 2 DLLP type
    input  tx_cmd_struct            xplh_xdlh_cmd,                  // Command from XPLH to XDLH
    output                          xdlh_xplh_cmd_ack,              // Command Complete Acknowledge from XDLH to XPLH
    input  [CNT_WIDTH-1:0]          xplh_flit_count,
    output                          xplh_flit_count_en,
    input                           xplh_xdlh_dllp_halt,
    output fm_dllp_struct           xdlh_xplh_dllp_out,
    output                          xdlh_update_fc_fm,              // Update FC sent FM
    output                          xtlh_xdlh_fm_sof,
    input dllp_struct               xplh_pm_dllp_ack,
    input                           pm_wake_req_exit_l0s,           // TLP pending on XADM interface so exit L0S
    input                           xadm_tlp_pending,               // XADM TLP pending flag
    input                           xaim_tlp_pending,               // XAIM TLP pending flag
  input                             xplh_pending,                   // XPLH pending flag (used only when SPIF is not enabled)
    input                           msg_gen_asnak_grt,              // Indication from msg_gen that PM_Active_State_Nak has been granted
    input                           pm_l2_entry_flag,               // PM_Turnoff message has been received so L2 negotiation should start
    input  [2:0]                    l0s_entr_latency_timer,         // L0s transmitter L0s exit timer
    input  [2:0]                    l1_entr_latency_timer,          // L1 transmitter l1 exit timer
    input                           pm_l1_entr_wo_rl0s,             // Start L1 timer without rL0s
    input                           pm_aspm_l1_timer_enable,        // Control ASPM L1 timer
    input  [NVC-1:0]                xtlh_had_enough_credit,         // XTLH had enough credit
    input  [NVC-1:0]                xadm_no_fc_credit,              // no FC credits are available to transmit anything
    input                           radm_pm_asnak,                  // received AS_NAK
    input                           app_req_entr_l1,                // Provide a capability for applications to request PM state to enter L1. This is only effective when ASPM of L1 is enabled.
    input                           radm_trgt0_pending,             // A TLP is enroute to TRGT0, delay L1 entry
    input                           lbc_active,                     // The LBC may require a CPL to be sent, stop L1 timer
    input                           pm_wake_any_if_pending,
    input                           app_xfer_pending,
    input  [3:0]                    cfg_dsp_pcipm_l1_enter_delay,
    input                           xmlh_cmd_if_lp_ack,             // Acknowledge from xtlh_cmd_if to PM indicating entering flush state
    input                           software_entr_l1,
    input                           software_entr_l23,
    input                           pm_aspm_l0s_en,                  // PME Controller indicates to the PM Protocol FSM that L0s ASPM is enabled
    input                           pm_aspm_l1_en,                   // PME Controller indicates to the PM Protocol FSM that L1 ASPM is enabled
    input                           lp_pcie_l1_exit,                 // SPIF: Request to PCIe/CXL.io Link Layer to change requested from IDLE_L1_1 to ACTIVE and initiate L1 exit
    input                           lp_pcie_clk_ack,                 // SPIF: PCIe/CXL.io Link Layer acknowledges LogPHY request to remove the clock gating
    input                           lp_pcie_wake_req,                // SPIF: PCIe/CXL.io Link Layer requests LogPHY to remove the clock gating
    input   pm_link_to_protocol_struct  pm_link_to_protocol_signals,
    output  pm_protocol_to_link_struct  pm_protocol_to_link_signals,
    output  logic                   pm_xmt_asnak,
    output  logic                   pm_block_all_tlp,
    output  logic                   pm_l1_aspm_entr,
    output  logic                   pm_xdlh_enter_l23,
    output  logic                   pm_l1_entry_started,
    output  logic                   pm_l1_in_progress,               // L1 entry negotiation in progress
    output  logic                   pm_aspm_l1_enter_ready,
    output  usp_prot_fsm_state_e    pm_usp_prot_state,
    output  dsp_prot_fsm_state_e    pm_dsp_prot_state,
    output  pm_active_l0s_fsm_e     pm_l0s_state,
    output  logic                   latch_as_entr_l1,
    output  logic                   pm_prot_idle_flag,
    output  logic                   lp_sdb_l1sub_aspm,
    output  logic                   lp_sdb_l1sub_pcipm,
    output                          xdlh_ptm_sot,
    output                          xdlh_ptm_multi_cycle,
    output                          xdlh_ptm_request,
    output                          xdlh_ptm_response,
    output                          xdlh_rbuf_replaying,
    output                          rdlh_ptm_sot,
    output                          rdlh_ptm_multi_cycle,
    output                          rdlh_ptm_request,
    output                          rdlh_ptm_response,
    output                          rdlh_duplicate_tlp,
    output [NW-1:0]                 rdlh_rtlh_tlp_sot,
    output                          rdlh_rcvd_dllp,                 // Indicates that RDLH received DLLP
// ----------------------------------------------------------------------------
// ADM Adaptor/CDM/Top-Level
// ----------------------------------------------------------------------------
    output [7:0]                    rtfcgen_ph_diff,
    output                          rtlh_overfl_err,                // Indicates receiver overflow (credit based)
    output rtlh_rfc_t               rtlh_rfc,                       // Received FC update: Update Transmit credit information
    output                          rtlh_parerr,
    output [NVC-1:0]                rtlh_fc_init_status,            // FC init status. This signal indicates that FC control state machine
    output [NVC-1:0]                rtlh_crd_not_rtn,               // Flow Control credit not returned
    output                          rdlh_rcvd_dl_feature,           // Feature DLLP Received
    output [31:0]                   rcvd_dl_feature_content,        // Feature DLLP content
    output                          rdlh_bad_tlp_err,               // Data link layer receive bad TLP error
    output                          rdlh_bad_dllp_err,              // Data link layer receive bad DLLP error
    output  [1:0]                   rdlh_rtlh_link_state,           // Data link layer state machine output
    output                          rdlh_prot_err,                  // Data link layer protocol error
    output                          rdlh_link_up,                   // Data link layer is link up.
    output                          rdlh_link_down,                 // Data link layer is link down.
    output                          xdlh_retry_req,                 //Retry Req
    output  [16:0]                  xdlh_replay_timer_value,        // XDLH retry buffer replay timer
    output                          xdlh_replay_timeout_err,        // output from xdlh 
    output                          xdlh_retrybuf_not_empty,        // Data link layer retry buffer not empty
    output  [11:0]                  xdlh_rbuf_pkt_cnt,              // XDLH packet counter
    output                          xtlh_tlp_pending,               // XTLH has TLP pending to be sent.
    output                          xtlh_data_parerr,               // XTLH has detected data parrity error on the data bus
    output logic                    latched_flit_mode_enable,
// ----------------------------------------------------------------------------
// RAS-DES Interface (Outputs)
// ----------------------------------------------------------------------------
    output                          xdlh_nak_sent,                  // Nak sent 
    output                          xdlh_ack_sent,                  // Ack  sent 
    output  [TX_NDLLP-1:0]          xdlh_update_fc_sent,            // Update FC sent NFM
    output                          xdlh_smlh_goto_detect,
    output  [RX_NDLLP -1:0]         rtlh_rcvd_ufc_perdllp,          // Puls : Rx Update-FC DLLP Event per TLP for Ras D.E.S event counter
    output  [RX_TLP-1:0]            rtlh_rx_memwr_evt,              // Puls : Rx Memory Write TLP for Ras D.E.S event counter
    output  [RX_TLP-1:0]            rtlh_rx_defmemwr_evt,           // Puls : Rx Deferrable Memory Write TLP for Ras D.E.S event counter
    output  [RX_TLP-1:0]            rtlh_rx_memrd_evt,              // Puls : Rx Memory Read TLP for Ras D.E.S event counter
    output  [RX_TLP-1:0]            rtlh_rx_cfgwr_evt,              // Puls : Rx Config Write TLP for Ras D.E.S event counter
    output  [RX_TLP-1:0]            rtlh_rx_cfgrd_evt,              // Puls : Rx Config Read TLP for Ras D.E.S event counter
    output  [RX_TLP-1:0]            rtlh_rx_iowr_evt,               // Puls : Rx I/O Write TLP for Ras D.E.S event counter
    output  [RX_TLP-1:0]            rtlh_rx_iord_evt,               // Puls : Rx I/O Read TLP for Ras D.E.S event counter
    output  [RX_TLP-1:0]            rtlh_rx_cplwod_evt,             // Puls : Rx Completion without Data TLP for Ras D.E.S event counter
    output  [RX_TLP-1:0]            rtlh_rx_cplwd_evt,              // Puls : Rx Completion with Data TLP for Ras D.E.S event counter
    output  [RX_TLP-1:0]            rtlh_rx_msg_evt,                // Puls : Rx Message TLP for Ras D.E.S event counter
    output  [RX_TLP-1:0]            rtlh_rx_atmcop_evt,             // Puls : Rx AtomicOp TLP for Ras D.E.S event counter
    output  [RX_TLP-1:0]            rtlh_rx_tlpwprefix_evt,         // Puls : Rx TLP with Prefix for Ras D.E.S event counter
    output  [RX_TLP*11-1:0]         rtlh_rx_tlp_dpsize,             // Receiving TLP's data payload size[DW]

    output  [RX_TLP-1:0]            rdlh_bad_tlp_err_pertlp,        // Pulse : Rx Bad TLP Event per TLP for Ras D.E.S event counter
    output  [RX_TLP-1:0]            rdlh_lcrc_tlp_err_pertlp,       // Pulse : Rx LCRC Error TLP Event per TLP for Ras D.E.S event counter
    output  [RX_TLP-1:0]            rdlh_nulified_tlp_err_pertlp,   // Pulse : Rx Nullified TLP Event per TLP for Ras D.E.S event counter
    output  [RX_TLP-1:0]            rdlh_duplicate_tlp_err_pertlp,  // Pulse : Rx Duplicate TLP Event per TLP for Ras D.E.S event counter
    output  [RX_NDLLP-1:0]          rdlh_bad_dllp_err_perdllp,      // Pulse : Rx Bad DLLP Event per DLLP for Ras D.E.S event counter
    output  [RX_NDLLP-1:0]          rdlh_rcvd_ack_perdllp,          // Pulse : Rx Ack DLLP Event per DLLP for Ras D.E.S event counter
    output  [RX_NDLLP-1:0]          rdlh_rcvd_nack_perdllp,         // Pulse : Rx Nak DLLP Event per DLLP for Ras D.E.S event counter
    output                          rdlh_vc0_initfc1_status,        // Level : VC0 Init-FC1 status for Ras D.E.S Silicon Debug
    output                          rdlh_vc0_initfc2_status,        // Level : VC0 Init-FC2 status for Ras D.E.S Silicon Debug 
    output  [11:0]                  rdlh_curnt_rx_ack_seqnum,       // Level : Current Rx Ack Sequence number status for Ras D.E.S Silicon Debug
    output  [11:0]                  xdlh_curnt_seqnum,              // Level : Current Tx Sequence number status for Ras D.E.S Silicon Debug

    output  [(NVC*HCRD_WD)-1:0]     rtlh_fc_rcvd_ph,                // Level : Current FC Credit Received(Posted Header) for Ras D.E.S Silicon Debug
    output  [(NVC*DCRD_WD)-1:0]     rtlh_fc_rcvd_pd,                // Level : Current FC Credit Received(Posted Data) for Ras D.E.S Silicon Debug
    output  [(NVC*HCRD_WD)-1:0]     rtlh_fc_rcvd_nph,               // Level : Current FC Credit Received(Non-Posted Header) for Ras D.E.S Silicon Debug
    output  [(NVC*DCRD_WD)-1:0]     rtlh_fc_rcvd_npd,               // Level : Current FC Credit Received(Non-Posted Data) for Ras D.E.S Silicon Debug
    output  [(NVC*HCRD_WD)-1:0]     rtlh_fc_rcvd_cplh,              // Level : Current FC Credit Received(Completion Header) for Ras D.E.S Silicon Debug
    output  [(NVC*DCRD_WD)-1:0]     rtlh_fc_rcvd_cpld,              // Level : Current FC Credit Received(Completion Data) for Ras D.E.S Silicon Debug
    output  [(NVC*HCRD_WD)-1:0]     rtlh_fc_allctd_ph,              // Level : Current FC Credit Allocated(Posted Header) for Ras D.E.S Silicon Debug
    output  [(NVC*DCRD_WD)-1:0]     rtlh_fc_allctd_pd,              // Level : Current FC Credit Allocated(Posted Data) for Ras D.E.S Silicon Debug
    output  [(NVC*HCRD_WD)-1:0]     rtlh_fc_allctd_nph,             // Level : Current FC Credit Allocated(Non-Posted Header) for Ras D.E.S Silicon Debug
    output  [(NVC*DCRD_WD)-1:0]     rtlh_fc_allctd_npd,             // Level : Current FC Credit Allocated(Non-Posted Data) for Ras D.E.S Silicon Debug
    output  [(NVC*HCRD_WD)-1:0]     rtlh_fc_allctd_cplh,            // Level : Current FC Credit Allocated(Completion Header) for Ras D.E.S Silicon Debug
    output  [(NVC*DCRD_WD)-1:0]     rtlh_fc_allctd_cpld,            // Level : Current FC Credit Allocated(Completion Data) for Ras D.E.S Silicon Debug
    output  [2:0]                   rdlh_einj0_lcrc_evt,            // Error injection 0 event flag
    output  [1:0]                   xdlh_einj0_lcrc_evt,            // Error injection 0 LCRC event
    output                          xdlh_einj0_fcrc_evt,            // Error injection 0 ECRC event
    output  [1:0]                   xdlh_einj0_dllpcrc_evt,         // Error injection 0 DLLP CRC event
    output  [1:0]                   xdlh_ras_des_einj1_exp_sequm_evt, 
    output                          xdlh_ras_des_einj1_ack_nak_sequm_evt,
    output                          xdlh_einj2_nak_evt,             // Error injection 2 NAK event
    output                          rtlh_einj4_fc_evt,              // Error injection 4 FC event
    output                          xdlh_einj5_nultlp_evt,          // Error injection 5 nullified TLP event
    output                          xdlh_einj5_dup_evt,             // Error injection 5 Duplicate TLP event
// ----------------------------------------------------------------------------
// RAS Interface (Outputs)
// ----------------------------------------------------------------------------
    output [ RAS_RDLH_COUNTERS-1:0] ras_stat_rdlh_corr,
    output [ RAS_RTLH_COUNTERS-1:0] ras_stat_rtlh_corr,
    output [ RAS_RDLH_COUNTERS-1:0] ras_stat_rdlh_uncorr,
    output [ RAS_RTLH_COUNTERS-1:0] ras_stat_rtlh_uncorr,
    output                          ras_err_inj_done,
    output ras_dp_err_log_t         ras_dp_err_log_xtlh,
    output ras_dp_err_log_t         ras_dp_err_log_xdlh,
// ----------------------------------------------------------------------------
// CRC Error Injection Interface (Outputs)
// ----------------------------------------------------------------------------
    output                          lcrc_err_asserted,
    output                          ecrc_err_asserted,
// ----------------------------------------------------------------------------
// Retry Buffer RAM Interface
// ----------------------------------------------------------------------------
    input   [RBUF_WD_NFM-1:0]       retryram_xdlh_data,             // Data coming back from Retry buffer RAM
    input   [RBUF_PW -1:0]          retryram_xdlh_depth,            // How big is the external retry buffer
    input                           retryram_xdlh_parerr,           // retry buffer ram parity error detected
    output  rbuf_struct             xdlh_retryram_if,               // Retry buffer interface
    output                          xdlh_retryram_par_chk_val,      // parity check is valid
    output                          xdlh_retryram_halt,
    input   [SOTBUF_WD -1:0]        retrysotram_xdlh_data,          // Data coming back from Retry buffer RAM
    input   [SOTBUF_PW -1:0]        retrysotram_xdlh_depth,
    input                           retrysotram_xdlh_parerr,
    output                          xdlh_retrysotram_par_chk_val,   // parity check is valid
    output  [SOTBUF_WD -1:0]        xdlh_retrysotram_data,          // Write data to retry buffer RAM
    output                          xdlh_retrysotram_we,            // Write enable to retry buffer RAM
    output                          xdlh_retrysotram_en,            // Read enable to retry buffer RAM
    output  [SOTBUF_PW -1:0]        xdlh_retrysotram_waddr,         // Write Adrress to retry buffer RAM
    output  [SOTBUF_PW -1:0]        xdlh_retrysotram_raddr          // Read Adrress to retry buffer RAM
    ,
    input  [6:0]                    cfg_tx_arb_control
);

// ----------------------------------------------------------------------------
// SPIF Interface and Signals
// ----------------------------------------------------------------------------
spif_if                      b_xdlh_spif();                 // XDLH SPIF Interface
spif_if                      b_rdlh_spif();                 // RDLH SPIF Interface
//protocol_cfg_t               sdlh_protocol_cfg;             // SPIF Protocol Configuration to DLH hierarchy

logic                        xdlh_pl_stall_req;             // SPIF SDLH to XDLH Stall Request
logic                        xdlh_lp_stall_ack;             // SPIF XDLH to SDLH Stall Acknowledge
logic                        xdlh_pm_state_req;             // SPIF SDLH to XDLH PM Entry Request (allows DLLP propagation when stall_req is asserted)
logic                        rdlh_retrain_req;              // RDLH Retrain Request
dllp_struct                  xdlh_pm_dllp_ack;              // XDLH PM DLLP Acknowledge
// ----------------------------------------------------------------------------
// Command Interface Hieararchy Connections: SDLH->XDLH->XTLH
// ----------------------------------------------------------------------------
tx_cmd_struct                sdlh_xdlh_cmd;                 // Command from SDLH to XDLH
tx_cmd_struct                xdlh_xtlh_cmd_org;             // Command from XDLH         (original version)
tx_cmd_struct                xdlh_xtlh_cmd_ovr;             // Command           to XTLH (override flit_mode)
logic                        xdlh_sdlh_cmd_ack;             // Command Complete Acknowledge from XDLH to SDLH
logic                        xtlh_xdlh_cmd_ack;             // Command Complete Acknowledge from XTLH to XDLH
logic                        xdlh_retry_pending;            // Command from XDLH to SDLH indicating TLP pending to be sent or retry FSM is in the reply state
logic                        xdlh_tlp_pending;              // XDLH has TLP pending to be sent.
// ----------------------------------------------------------------------------
// RDLH-SDLH Connections
// ----------------------------------------------------------------------------
logic                        pm_freeze_fc_timer;            // Command from SDLH to RDLH to Freeze FC Timer
logic                        rdlh_rcvd_pm_enter_l1;         // Command from RDLH to SDLH indicating received DLLP PM_ENTER_L1
logic                        rdlh_rcvd_pm_enter_l23;        // Command from RDLH to SDLH indicating received DLLP PM_ENTER_L23
logic                        rdlh_rcvd_pm_req_ack;          // Command from RDLH to SDLH indicating received DLLP PM_REQ_ACK
logic                        rdlh_rcvd_as_req_l1;           // Command from RDLH to SDLH indicating received DLLP AS REQ L1
// ----------------------------------------------------------------------------
// XDLH-RDLH Connections
// ----------------------------------------------------------------------------
wire    [11:0]               xdlh_rdlh_last_xmt_seqnum;     // the last transmitted highest sequence number of TLP's DLLP. Receiver needs this signal to identify out of order TLP
wire                         nak_scheduled;                 // dllp generation block requests nak is scheduled to be transmitted
wire                         xdlh_rdlh_feature_ack;
// ----------------------------------------------------------------------------
// RDLH-XDLH Connections
// ----------------------------------------------------------------------------
wire                         rdlh_xdlh_rcvd_nack;           // RDLH pulse signal to indicate that there was a NACK PKT received, and its nack sequence number drove to RDLH_RCVD_ACKNACK_SEQ_NUM
wire                         rdlh_xdlh_rcvd_ack;            // RDLH pulse signal to indicate that there was a ACK PKT received, and its ACK sequence number drove to RDLH_RCVD_ACKNACK_SEQ_NUM
wire    [11:0]               rdlh_xdlh_rcvd_acknack_seqnum; // 12 bits indicated the sequence number of received ACK/NACK DLLP Packet
wire                         rdlh_xdlh_req2send_ack;        // RDLH received a good packet and has been asked to send an ACK back. This signal is mutually exclusive with NACK signal. Its received transaction sequence number droved at  RDLH_RCVD_PKT_SEQ_NUM
wire                         rdlh_xdlh_req2send_ack_due2dup;// RDLH received a packet that is a duplicated PKT . RDLH_REQ2SEND_ACK signal will be asserted while RDLH_RCVD_DUP is asserted.
wire                         rdlh_xdlh_req2send_nack;       // RDLH received a good packet and has been asked to send an NACK back. This signal is mutually exclusive with NACK signal. Its received transaction sequence number droved at  RDLH_RCVD_PKT_SEQ_NUM
wire    [11:0]               rdlh_xdlh_req_acknack_seqnum;  // RDLH received a packet with this sequence number
dllp_struct                  xdlh_l0p_dllp;                 // L0P DLLP
l0p_ack_struct               xdlh_dllp_l0p_ack;             // Acknowledge the L0P DLLP has been Transmitted
logic                        xplh_l0p_dllps_count;
l0p_dllp_struct              rdlh_xdlh_l0p_dllp;
logic                        rdlh_xdlh_fm_dllp_valid;
wire                         send_feature_dllp;
`ifndef SYNTHESIS
`endif // SYNTHESIS
// ----------------------------------------------------------------------------
// RDLH-RTLH Connections
// ----------------------------------------------------------------------------
wire    [RX_NDLLP-1:0]       rdlh_rtlh_rcvd_dllp;           // When asserted, it indicates it is DLLP1 packet (Each 128-bit words could carry two DLLP packets)
wire                         rdlh_rtlh_rcvd_dllp_fm_opt_fc_up;// When assered, indicate that we have received a FM Optimized FC update dllp packet
wire    [(RX_NDLLP*32)-1:0]  rdlh_rtlh_dllp_content;        // The received DLLP packet
wire    [DW_W_PAR-1:0]       rdlh_rtlh_tlp_data;            // Current TLP header and data
wire                         rdlh_rtlh_tlp_dv;              // Data bus is valid this cycle
wire    [NW-1:0]             rdlh_rtlh_tlp_soh;
assign  rdlh_rtlh_tlp_sot =  rdlh_rtlh_tlp_soh;
wire    [NW-1:0]             rdlh_rtlh_tlp_eot;             // When asserted, it indicates the end of a good TLP pkt

wire    [NW-1:0]             rdlh_rtlh_tlp_abort;           // Packet was nullified or DL errored -- abort it.
wire    [NW-1:0]             rdlh_rtlh_tlp_idl;
wire    [NW-1:0]             rdlh_rtlh_tlp_pfx;
wire                         rdlh_rtlh_fm_nullified;
wire                         rdlh_rtlh_fm_poisoned;
// ----------------------------------------------------------------------------
// RTLH-RDLH Connections
// ----------------------------------------------------------------------------
wire                         rtlh_rdlh_fci1_fci2;           // RTLH flow control init 1 and init 2.
wire                         init_fc1_rcvd;
// ----------------------------------------------------------------------------
// RTLH-XDLH Connections
// ----------------------------------------------------------------------------
wire    [TX_NDLLP-1:0]       rtlh_xdlh_fc_req;              // Request to send a FCP
wire                         rtlh_xdlh_fc_req_hi;           // Request to send a high-priority FCP that is higher than ACK/NACK
wire                         rtlh_xdlh_fc_req_low;          // Request to send a low-priority FCP that is lower than TLP
wire    [(TX_NDLLP*32)-1:0]  rtlh_xdlh_fc_data;             // Data associated with request
// ----------------------------------------------------------------------------
// XDLH-SDLH Connections
// ----------------------------------------------------------------------------
wire                         xdlh_sdlh_retrain_req;         // Request to start link retrain
// ----------------------------------------------------------------------------
// XDLH-RTLH Connections
// ----------------------------------------------------------------------------
wire                         xdlh_rtlh_fc_ack;              // When asserted, it indicates XDLH has accepted the request to XMIT a FC packet
// ----------------------------------------------------------------------------
// XDLH-XTLH Connections
// ----------------------------------------------------------------------------
wire                         xdlh_xtlh_halt;                // stop xtlh xmt immediatelly
wire   [NVC-1:0]             xdlh_xtlh_fc_init_done;
wire                         xdlh_rasdp_error_mode;
// ----------------------------------------------------------------------------
// XTLH-XDLH Connections
// ----------------------------------------------------------------------------
wire                         xtlh_xdlh_dv;                  // XTLH pushes down packet down qualified by this data
wire    [CTL_WD-1:0]         xtlh_xdlh_sot;                 // XTLH Start Of TLP control bus
wire    [CTL_WD-1:0]         xtlh_xdlh_eot;                 // XTLH End Of TLP control bus
wire    [CTL_WD-1:0]         xtlh_xdlh_badeot;              // XTLH Bad Eot control bus
wire    [NFM_DW_W_PAR-1:0]   xtlh_xdlh_data;                // XTLH outputs header/data bus to XDLH
wire    [10:0]               xtlh_xdlh_tlp_len;
wire                         xtlh_sot_is_first;
wire                         xtlh_eot_sot_eot;
wire                         xtlh_badeot;
wire                         xtlh_first_badeot;
wire                         xtlh_eot_sot;
tx_flit_struct               xtlh_xdlh_flit;
// ----------------------------------------------------------------------------
// PTM: PCIe Flit Mode Mux and Signals
// ----------------------------------------------------------------------------
wire                         int_smlh_flit_mode_enable;
wire                         i_xdlh_ptm_sot;
wire                         i_xdlh_ptm_multi_cycle;
wire                         i_xdlh_ptm_request;
wire                         i_xdlh_ptm_response;
wire                         i_xdlh_rbuf_replaying;

wire                         i_rdlh_ptm_sot;
wire                         i_rdlh_ptm_multi_cycle;
wire                         i_rdlh_ptm_request;
wire                         i_rdlh_ptm_response;
wire                         i_rdlh_duplicate_tlp;

assign xdlh_ptm_sot          = (int_smlh_flit_mode_enable) ? xplh_ptm_sot        : i_xdlh_ptm_sot;
assign xdlh_ptm_request      = (int_smlh_flit_mode_enable) ? xplh_ptm_request    : i_xdlh_ptm_request;
assign xdlh_ptm_response     = (int_smlh_flit_mode_enable) ? xplh_ptm_response   : i_xdlh_ptm_response;
assign xdlh_ptm_multi_cycle  = (int_smlh_flit_mode_enable) ? 1'b0                : i_xdlh_ptm_multi_cycle;
assign xdlh_rbuf_replaying   = (int_smlh_flit_mode_enable) ? xplh_ptm_retry_flit : i_xdlh_rbuf_replaying;

assign rdlh_ptm_sot          = (int_smlh_flit_mode_enable) ? rplh_ptm_sot        : i_rdlh_ptm_sot;
assign rdlh_ptm_request      = (int_smlh_flit_mode_enable) ? rplh_ptm_request    : i_rdlh_ptm_request;
assign rdlh_ptm_response     = (int_smlh_flit_mode_enable) ? rplh_ptm_response   : i_rdlh_ptm_response;
assign rdlh_ptm_multi_cycle  = (int_smlh_flit_mode_enable) ? 1'b0                : i_rdlh_ptm_multi_cycle;
assign rdlh_duplicate_tlp    = (int_smlh_flit_mode_enable) ? rplh_ptm_duplicate  : i_rdlh_duplicate_tlp;
// ----------------------------------------------------------------------------
// RAS Error Injection Connections
// ----------------------------------------------------------------------------
wire                         ras_err_inj_done_xtlh;
assign ras_err_inj_done_xtlh = '0;
wire                         ras_err_inj_done_rdlh;
wire                         ras_err_inj_done_rtlh;
assign ras_err_inj_done =    1'b0
                              || ras_err_inj_done_xtlh || ras_err_inj_done_rdlh || ras_err_inj_done_rtlh
                             ;
// ----------------------------------------------------------------------------
// Other internal signals
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// Internal assignments
// ----------------------------------------------------------------------------
// Added to identify whether or not LTSSM is enabled to transmit TLP
// In CXL mode enable transmit datapath when vLSM.io is active.
// In PCIe mode enable transmit datapath when LTSSM is in L0.
logic  tmp_smlh_in_l0;
logic  smlh_in_rl0s_r;

assign tmp_smlh_in_l0 = (smlh_in_l0 || ((smlh_in_rl0s || smlh_in_rl0s_r) && !smlh_in_l0s));

// Pipeline on smlh_in_rl0s to align LTSSM state changes from L0S to L0
delay_n
 #(
  .N ( 1 )
) u_smlh_in_rl0s_reg (
  .clk   ( core_clk       ),
  .rst_n ( core_rst_n     ),
  .clear ( 1'b0           ),
  .din   ( smlh_in_rl0s   ),
  .dout  ( smlh_in_rl0s_r )
);


assign rdlh_rcvd_dllp = |rdlh_rtlh_rcvd_dllp;
assign ecrc_err_asserted = 1'b0;
assign xtlh_data_parerr = 1'b0;
assign xtlh_xdlh_fm_sof = xtlh_xdlh_flit.sof;
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// SPIF MUX on SMLH interface signals
// ----------------------------------------------------------------------------
wire       int_smlh_l123_eidle_timeout;
wire       int_latched_rcvd_eidle_set;
wire       int_smlh_in_l0;
wire       int_smlh_in_l0s;
wire       int_smlh_in_rl0s;
wire       int_smlh_in_l1;
wire       int_smlh_in_l23;
wire       int_smlh_link_in_training;
wire       int_smlh_link_up;
wire [5:0] int_smlh_link_mode;
wire [5:0] int_smlh_link_rxmode;
wire [2:0] int_current_data_rate;
wire       int_smlh_eq_pending;
wire       int_block_dl_init;
wire       int_dl_active;
wire       rdlh_flit_mode_enable;
wire       rtlh_flit_mode_enable;

wire tmp_smlh_link_up;
// Pipeline on smlh_link_up to align with protocol_vld
delay_n
 #(
  .N ( 0 + 4 )
) u_smlh_link_up_reg (
  .clk   ( core_clk ),
  .rst_n ( core_rst_n ),
  .clear ( 1'b0 ),
  .din   ( smlh_link_up ),
  .dout  ( tmp_smlh_link_up )
);

logic int_tx_enable_s;
logic int_tx_enable_r;

// Enable transmit datapath when States Status is in ACTIVE and stall_req/ack handshake is complete
assign int_tx_enable_s = sdlh_protocol_cfg.spif_enable && ((b_sdlh_splh_spif.s_pl_state_sts == ACTIVE) && !b_sdlh_splh_spif.s_pl_stall_req && !b_sdlh_splh_spif.s_lp_stall_ack);

// Delay TX enable flag to filter out a single cycle transmit datapath enable events (back-2-back recoveries)
delay_n
 #(
  .N ( 1 )
) u_tx_enable_reg (
  .clk   ( core_clk ),
  .rst_n ( core_rst_n ),
  .clear ( 1'b0 ),
  .din   ( int_tx_enable_s ),
  .dout  ( int_tx_enable_r )
);

assign int_smlh_in_l0            = sdlh_protocol_cfg.spif_enable ? (int_tx_enable_s && int_tx_enable_r) : tmp_smlh_in_l0;
assign int_smlh_in_l0s           = sdlh_protocol_cfg.spif_enable ? ((b_sdlh_splh_spif.s_pl_state_sts == ACTIVE_L0S_PMNAK) && sdlh_protocol_cfg.pcie_mode_enable) : smlh_in_l0s;
assign int_smlh_in_rl0s          = sdlh_protocol_cfg.spif_enable ? (b_sdlh_splh_spif.s_pl_phyinrxl0s && sdlh_protocol_cfg.pcie_mode_enable                     ) : smlh_in_rl0s;
assign int_smlh_in_l1            = sdlh_protocol_cfg.spif_enable ? (b_sdlh_splh_spif.s_pl_state_sts == IDLE_L1_1       ) : smlh_in_l1;
assign int_smlh_in_l23           = sdlh_protocol_cfg.spif_enable ? (b_sdlh_splh_spif.s_pl_state_sts == L2                                                      ) : smlh_in_l23;
assign int_smlh_link_in_training = sdlh_protocol_cfg.spif_enable ? (b_sdlh_splh_spif.s_pl_state_sts == RETRAIN         ) : smlh_link_in_training;
assign int_smlh_link_up          = sdlh_protocol_cfg.spif_enable ? b_sdlh_splh_spif.s_pl_link_up                         : tmp_smlh_link_up;
assign int_smlh_l123_eidle_timeout   = sdlh_protocol_cfg.spif_enable ? 1'b0                                                                                      : smlh_l123_eidle_timeout ;
assign int_latched_rcvd_eidle_set    = sdlh_protocol_cfg.spif_enable ? 1'b0                                                                                      : latched_rcvd_eidle_set  ;

// TBD!!! pl_linkmode is derived from smlh_link_rxmode, smlh_link_mode is used for PAD to be moved to XPLH and L0p which need to be revised
assign int_smlh_link_mode        = sdlh_protocol_cfg.spif_enable ? b_sdlh_splh_spif.s_pl_linkmode                        : smlh_link_mode;
assign int_smlh_link_rxmode      = sdlh_protocol_cfg.spif_enable ? b_sdlh_splh_spif.s_pl_linkmode                        : smlh_link_rxmode;
assign int_smlh_eq_pending       = sdlh_protocol_cfg.spif_enable ? 1'b0                                                  : smlh_eq_pending;
assign rdlh_flit_mode_enable     = sdlh_protocol_cfg.spif_enable ? sdlh_protocol_cfg.pcie_flit_mode                      : smlh_flit_mode_enable_modules[2];
assign rtlh_flit_mode_enable     = sdlh_protocol_cfg.spif_enable ? sdlh_protocol_cfg.pcie_flit_mode                      : smlh_flit_mode_enable;
assign int_smlh_flit_mode_enable = sdlh_protocol_cfg.spif_enable ? sdlh_protocol_cfg.pcie_flit_mode                      : smlh_flit_mode_enable;

assign int_current_data_rate     = sdlh_protocol_cfg.spif_enable ? b_sdlh_splh_spif.s_pl_speedmode                       : pm_current_data_rate_others;
assign int_block_dl_init         = sdlh_protocol_cfg.spif_enable ? b_sdlh_splh_spif.s_pl_block_dl_init                   : (rdlh_rtlh_link_state ==  `S_DL_INACTIVE);
assign int_dl_active             = sdlh_protocol_cfg.spif_enable ? b_sdlh_splh_spif.s_lp_dl_active                       : (rdlh_rtlh_link_state ==  `S_DL_ACTIVE);
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// Link Layer Interface with ADM
// ----------------------------------------------------------------------------
assign pcie_link_adm_if.pl_bw_ratio      = b_sdlh_splh_spif.s_pl_bw_ratio;
assign pcie_link_adm_if.pl_speedmode     = b_sdlh_splh_spif.s_pl_speedmode;
assign pcie_link_adm_if.pl_link_up       = b_sdlh_splh_spif.s_pl_link_up;
assign pcie_link_adm_if.pl_state_sts     = b_sdlh_splh_spif.s_pl_state_sts;
assign pcie_link_adm_if.pl_protocol_cfg  = sdlh_protocol_cfg;
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// Override Flit Mode Enable in XTLH Command Interface
// TOBEREMOVED: SPIF Protocol Configuration Structure always preserves negotiated modes
// ----------------------------------------------------------------------------
// When Flit is set, it can only be cleared via a reset.
always @(posedge core_clk or negedge core_rst_n) begin : proc_latched_flit_mode_enable
       if (!core_rst_n)                                  latched_flit_mode_enable <= # `TP 1'b0; 
  else if (int_smlh_flit_mode_enable & int_smlh_link_up) latched_flit_mode_enable <= # `TP 1'b1;
end

always_comb begin : xdlh_xtlh_cmd_ovr_PROC
  xdlh_xtlh_cmd_ovr = xdlh_xtlh_cmd_org;
  xdlh_xtlh_cmd_ovr.flit_mode = latched_flit_mode_enable;
end : xdlh_xtlh_cmd_ovr_PROC
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// Data Link Layer State Management (SDLH) instantiation
// ----------------------------------------------------------------------------
assign xdlh_smlh_start_link_retrain = xdlh_sdlh_retrain_req; 

sdlh
 u_sdlh (
    // Interfaces
    .b_xdlh_spif                        ( b_xdlh_spif.xplh_master_mp           ),
    .b_rdlh_spif                        ( b_rdlh_spif.rplh_master_mp           ),
    .b_cfgi_spif                        ( b_cfgi_lbc                           ),
    .b_splh_spif                        ( b_sdlh_splh_spif                     ),
    // Inputs
    .core_clk                           ( core_clk                             ),
    .core_rst_n                         ( core_rst_n                           ),
    .pm_rstctl_core_flush_req           ( pm_rstctl_core_flush_req             ),
    .xplh_pm_dllp_ack                   ( xplh_pm_dllp_ack                     ),
    .xdlh_retry_pending                 ( xdlh_retry_pending                   ),
    .pm_wake_req_exit_l0s               ( pm_wake_req_exit_l0s                 ),
    .xadm_tlp_pending                   ( xadm_tlp_pending                     ),
    .xaim_tlp_pending                   ( xaim_tlp_pending                     ),
    .xtlh_tlp_pending                   ( xtlh_tlp_pending                     ),
    .xdlh_tlp_pending                   ( xdlh_tlp_pending                     ),
    .xplh_pending                       ( xplh_pending                         ),
    .msg_gen_asnak_grt                  ( msg_gen_asnak_grt                    ),
    .pm_l2_entry_flag                   ( pm_l2_entry_flag                     ),
    .cfg_upstream_port                  ( cfg_upstream_port                    ),
    .l0s_entr_latency_timer             ( l0s_entr_latency_timer               ),
    .l1_entr_latency_timer              ( l1_entr_latency_timer                ),
    .pm_l1_entr_wo_rl0s                 ( pm_l1_entr_wo_rl0s                   ),
    .pm_aspm_l1_timer_enable            ( pm_aspm_l1_timer_enable              ),
    .xdlh_not_expecting_ack             ( xdlh_not_expecting_ack               ),
    .xtlh_had_enough_credit             ( xtlh_had_enough_credit               ),
    .rdlh_rcvd_as_req_l1                ( rdlh_rcvd_as_req_l1                  ),
    .rdlh_rcvd_pm_enter_l1              ( rdlh_rcvd_pm_enter_l1                ),
    .rdlh_rcvd_pm_req_ack               ( rdlh_rcvd_pm_req_ack                 ),
    .rdlh_rcvd_pm_enter_l23             ( rdlh_rcvd_pm_enter_l23               ),
    .xadm_no_fc_credit                  ( xadm_no_fc_credit                    ),
    .xdlh_nodllp_pending                ( xdlh_nodllp_pending                  ),
    .xdlh_no_acknak_dllp_pending        ( xdlh_no_acknak_dllp_pending_s        ),
    .radm_pm_asnak                      ( radm_pm_asnak                        ),
    .smlh_in_l0                         ( int_smlh_in_l0                       ),
    .smlh_in_l0s                        ( int_smlh_in_l0s                      ),
    .smlh_in_rl0s                       ( int_smlh_in_rl0s                     ),
    .smlh_in_l1                         ( int_smlh_in_l1                       ),
    .smlh_in_l23                        ( int_smlh_in_l23                      ),
    .smlh_l123_eidle_timeout            ( int_smlh_l123_eidle_timeout          ),
    .latched_rcvd_eidle_set             ( int_latched_rcvd_eidle_set           ),
    .app_req_entr_l1                    ( app_req_entr_l1                      ),
    .smlh_link_up                       ( int_smlh_link_up                     ),
    .smlh_link_in_training              ( int_smlh_link_in_training            ),
    .radm_trgt0_pending                 ( radm_trgt0_pending                   ),
    .lbc_active                         ( lbc_active                           ),
    .pm_wake_any_if_pending             ( pm_wake_any_if_pending               ),
    .app_xfer_pending                   ( app_xfer_pending                     ),
    .cfg_dsp_pcipm_l1_enter_delay       ( cfg_dsp_pcipm_l1_enter_delay         ),
    .xmlh_cmd_if_lp_ack                 ( xmlh_cmd_if_lp_ack                   ),
    .software_entr_l1                   ( software_entr_l1                     ),
    .software_entr_l23                  ( software_entr_l23                    ),
    .pm_aspm_l0s_en                     ( pm_aspm_l0s_en                       ),
    .pm_aspm_l1_en                      ( pm_aspm_l1_en                        ),
    .lp_pcie_l1_exit                    ( lp_pcie_l1_exit                      ),
    .lp_pcie_clk_ack                    ( lp_pcie_clk_ack                      ),
    .lp_pcie_wake_req                   ( lp_pcie_wake_req                     ),
    .cfg_rasdp_linkdown_en              ( cfg_rasdp_linkdown_en                ),
    .rdlh_link_up                       ( rdlh_link_up                         ),
    .rdlh_link_state                    ( rdlh_rtlh_link_state                 ),
    .rdlh_retrain_req                   ( rdlh_retrain_req                     ),
    .rtlh_retrain_req                   ( rtlh_req_link_retrain                ),
    .xdlh_retrain_req                   ( xdlh_sdlh_retrain_req                ),
    .pm_cfg_retrain_req                 ( pm_cfg_retrain_req                   ),
    .pm_app_init_rst                    ( pm_app_init_rst                      ),
    .pl_speedmode                       ( int_current_data_rate                ),
    .pm_prot_req_l2                     ( pm_prot_req_l2                       ),
    .pm_block_tlp_ack                   ( pm_block_tlp_ack                     ),
    .xdlh_sdlh_cmd_ack                  ( xdlh_sdlh_cmd_ack                    ), // Command Complete Acknowledge from XDLH to SDLH
    .sdlh_xdlh_cmd                      ( sdlh_xdlh_cmd                        ), // Command from SDLH to XDLH
    .xdlh_xplh_cmd_ack                  ( xdlh_xplh_cmd_ack                    ), // Command Complete Acknowledge from XDLH to XPLH
    .xplh_xdlh_cmd                      ( xplh_xdlh_cmd                        ), // Command from XPLH to XDLH
    .xdlh_lp_stall_ack                  ( xdlh_lp_stall_ack                    ),
    // Outputs
    .xdlh_pl_stall_req                  ( xdlh_pl_stall_req                    ),
    .xdlh_pm_state_req                  ( xdlh_pm_state_req                    ),
    .pl_protocol_cfg                    ( sdlh_protocol_cfg                    ),
    .xdlh_pm_dllp_ack                   ( xdlh_pm_dllp_ack                     ),
    .pm_link_to_protocol_signals        ( pm_link_to_protocol_signals          ),
    .pm_protocol_to_link_signals        ( pm_protocol_to_link_signals          ),
    .pm_xmlh_lp_req                     ( pm_xmlh_lp_req                       ),
    .pm_xmt_asnak                       ( pm_xmt_asnak                         ),
    .pm_block_all_tlp                   ( pm_block_all_tlp                     ),
    .pm_l1_aspm_entr                    ( pm_l1_aspm_entr                      ),
    .pm_xdlh_dllp_req                   ( pm_xdlh_dllp_req                     ),
    .pm_xdlh_enter_l23                  ( pm_xdlh_enter_l23                    ),
    .pm_freeze_fc_timer                 ( pm_freeze_fc_timer                   ),
    .pm_l1_entry_started                ( pm_l1_entry_started                  ),
    .pm_l1_in_progress                  ( pm_l1_in_progress                    ),
    .pm_aspm_l1_enter_ready             ( pm_aspm_l1_enter_ready               ),
    .pm_usp_prot_state                  ( pm_usp_prot_state                    ),
    .pm_dsp_prot_state                  ( pm_dsp_prot_state                    ),
    .pm_l0s_state                       ( pm_l0s_state                         ),
    .latch_as_entr_l1                   ( latch_as_entr_l1                     ),
    .lp_sdb_l1sub_aspm                  ( lp_sdb_l1sub_aspm                    ),
    .lp_sdb_l1sub_pcipm                 ( lp_sdb_l1sub_pcipm                   ),
    .pm_prot_idle_flag                  ( pm_prot_idle_flag                    )
    ,
    .cfg_l0p_enable                     ( cfg_l0p_enable                       ),
    .cfg_l0p_autowidth_dis              ( cfg_l0p_autowidth_dis                ),
    .cfg_l0p_priority                   ( cfg_l0p_priority                     ),
    .cfg_l0p_linkmode                   ( cfg_l0p_linkmode                     ),
    .cfg_l0p_linkmode_req               ( cfg_l0p_linkmode_req                 ),
    .cfg_l0p_max_link_width             ( cfg_l0p_max_link_width               ),
    .cfg_l0p_neg_link_width             ( cfg_l0p_neg_link_width               ),
    .cfg_pcie_l0p_disable               ( cfg_pcie_l0p_disable                 ),
    .cfg_pcie_l0p_request               ( cfg_pcie_l0p_request                 ),
    .cfg_pcie_l0p_priority              ( cfg_pcie_l0p_priority                ),
    .cfg_pcie_l0p_linkmode              ( cfg_pcie_l0p_linkmode                ),
    .app_dynamic_l0p_enable             ( app_dynamic_l0p_enable               ),
    .app_dynamic_l0p_rejected           ( app_dynamic_l0p_rejected             ),
    .xdlh_smlh_link_width               ( xdlh_smlh_link_width                 ),
    .smlh_l0p_link_mode                 ( smlh_l0p_link_mode                   ),
    .smlh_l0p_capable                   ( smlh_l0p_capable                     ),
    .smlh_xdlh_eios_rcvd                ( smlh_xdlh_eios_rcvd                  ),
    .smlh_ltssm_l0p_ready               ( smlh_ltssm_l0p_ready                 ),
    .xdlh_smlh_link_req                 ( xdlh_smlh_link_req                   ),
    .xdlh_smlh_link_initiated           ( xdlh_smlh_link_initiated             ),
    .xdlh_smlh_enter_recovery           ( xdlh_smlh_enter_recovery             ),
    .xplh_flit_count                    ( xplh_flit_count                      ),
    .xplh_flit_count_en                 ( xplh_flit_count_en                   ),
    .smlh_link_mode                     ( smlh_link_mode                       ),
    .xdlh_l0p_dllp                      ( xdlh_l0p_dllp                        ),
    .xdlh_dllp_l0p_ack                  ( xdlh_dllp_l0p_ack                    ),
    .xplh_l0p_dllps_count               ( xplh_l0p_dllps_count                 ),
    .rdlh_xdlh_l0p_dllp                 ( rdlh_xdlh_l0p_dllp                   ),
    .rdlh_xdlh_fm_dllp_valid            ( rdlh_xdlh_fm_dllp_valid              ),
    .current_data_rate                  ( int_current_data_rate                )
);

// ----------------------------------------------------------------------------
// Layer 2 Receive Datapath (RDLH) instantiation
// ----------------------------------------------------------------------------
rdlh

#(INST) u_rdlh(
    .b_rdlh_spif                        ( b_rdlh_spif.rplh_slave_mp            ),
    .rdlh_protocol_cfg                  ( sdlh_protocol_cfg                    ),
    .core_clk                           ( core_clk                             ),
    .core_rst_n                         ( core_rst_n                           ),
    .smlh_link_mode                     ( int_smlh_link_rxmode                 ),
    .smlh_link_up                       ( int_smlh_link_up                     ),
    .cfg_dll_lnk_en                     ( cfg_dll_lnk_en                       ),
    .rtlh_fci_done                      ( rtlh_fc_init_status[0]               ),
    .rtlh_fci1_fci2                     ( rtlh_rdlh_fci1_fci2                  ),
    .rplh_rdlh_dllp_start               ( rplh_rdlh_dllp_start                 ),
    .rplh_rdlh_tlp_start                ( rplh_rdlh_tlp_start                  ),
    .rplh_rdlh_pkt_end                  ( rplh_rdlh_pkt_end                    ),
    .rplh_rdlh_pkt_edb                  ( rplh_rdlh_pkt_edb                    ),
    .rplh_rdlh_pkt_data                 ( rplh_rdlh_pkt_data                   ),
    .rplh_rdlh_pkt_dv                   ( rplh_rdlh_pkt_dv                     ),
    .rplh_rdlh_pkt_err                  ( rplh_rdlh_pkt_err                    ),
    .rplh_rdlh_nak                      ( rplh_rdlh_nak                        ),
    .xdlh_rdlh_last_xmt_seqnum          ( xdlh_rdlh_last_xmt_seqnum            ),
    .nak_scheduled                      ( nak_scheduled                        ),
    .ras_prot_r_disable                 ( ras_prot_r_disable                   ),
    .ras_err_inj_en_array               ( ras_err_inj_en_array                 ),
    .ras_err_inj_mask                   ( ras_err_inj_mask                     ),
    .cdm_ras_des_einj0_enable           ( cdm_ras_des_einj0_enable             ),
    .cdm_ras_des_einj0_crc_type         ( cdm_ras_des_einj0_crc_type           ),
    .cdm_ras_des_einj0_count            ( cdm_ras_des_einj0_count              ),
    .dl_feature_en                      ( dl_feature_en                        ),
    .cfg_remote_feature_ack             ( cfg_remote_feature_ack               ),
    .init_fc1_rcvd                      ( init_fc1_rcvd                        ),
    .rplh_rdlh_tlp_idl                  ( rplh_rdlh_tlp_idl                    ),
    .rplh_rdlh_tlp_pfx                  ( rplh_rdlh_tlp_pfx                    ),
    .rplh_rdlh_fm_nullified             ( rplh_rdlh_fm_nullified               ),
    .rplh_rdlh_fm_poisoned              ( rplh_rdlh_fm_poisoned                ),
    .smlh_flit_mode_enable              ( rdlh_flit_mode_enable                ),
    .rplh_rdlh_fm_dllp_data             ( rplh_rdlh_fm_dllp_data               ),
    .rplh_rdlh_fm_dllp_valid            ( rplh_rdlh_fm_dllp_valid              ),
    .rplh_rdlh_fm_dllp_opt_fc_up        ( rplh_rdlh_fm_dllp_opt_fc_up          ),

// ---- outputs ---------------
    .rdlh_ptm_sot                       ( i_rdlh_ptm_sot                       ),
    .rdlh_ptm_multi_cycle               ( i_rdlh_ptm_multi_cycle               ),
    .rdlh_ptm_request                   ( i_rdlh_ptm_request                   ),
    .rdlh_ptm_response                  ( i_rdlh_ptm_response                  ),
    .rdlh_duplicate_tlp                 ( i_rdlh_duplicate_tlp                 ),
    .rdlh_retrain_req                   ( rdlh_retrain_req                     ),
    .rdlh_xdlh_rcvd_nack                ( rdlh_xdlh_rcvd_nack                  ),
    .rdlh_xdlh_rcvd_ack                 ( rdlh_xdlh_rcvd_ack                   ),
    .rdlh_xdlh_rcvd_acknack_seqnum      ( rdlh_xdlh_rcvd_acknack_seqnum        ),
    .rdlh_rtlh_rcvd_dllp                ( rdlh_rtlh_rcvd_dllp                  ),
    .rdlh_rtlh_rcvd_dllp_fm_opt_fc_up   ( rdlh_rtlh_rcvd_dllp_fm_opt_fc_up     ),
    .rdlh_rtlh_dllp_content             ( rdlh_rtlh_dllp_content               ),
    .rdlh_rtlh_tlp_soh                  ( rdlh_rtlh_tlp_soh                    ),
    .rdlh_rtlh_tlp_dv                   ( rdlh_rtlh_tlp_dv                     ),
    .rdlh_rtlh_tlp_eot                  ( rdlh_rtlh_tlp_eot                    ),
    .rdlh_rtlh_tlp_data                 ( rdlh_rtlh_tlp_data                   ),
    .rdlh_rtlh_tlp_abort                ( rdlh_rtlh_tlp_abort                  ),
    .send_feature_dllp                  ( send_feature_dllp                    ),
    .rdlh_rcvd_dl_feature               ( rdlh_rcvd_dl_feature                 ),
    .rcvd_dl_feature_content            ( rcvd_dl_feature_content              ),
    .xdlh_rdlh_feature_ack              ( xdlh_rdlh_feature_ack                ),
    .ras_stat_rdlh_corr                 ( ras_stat_rdlh_corr                   ),
    .ras_stat_rdlh_uncorr               ( ras_stat_rdlh_uncorr                 ),
    .rdlh_xdlh_req2send_ack             ( rdlh_xdlh_req2send_ack               ),
    .rdlh_xdlh_req2send_nack            ( rdlh_xdlh_req2send_nack              ),
    .rdlh_xdlh_req_acknack_seqnum       ( rdlh_xdlh_req_acknack_seqnum         ),
    .rdlh_xdlh_req2send_ack_due2dup     ( rdlh_xdlh_req2send_ack_due2dup       ),
`ifndef SYNTHESIS
`endif // SYNTHESIS
    .rdlh_link_up                       ( rdlh_link_up                         ),
    .rdlh_link_down                     ( rdlh_link_down                       ),
    .rdlh_rtlh_link_state               ( rdlh_rtlh_link_state                 ),
    .rdlh_bad_dllp_err                  ( rdlh_bad_dllp_err                    ),
    .ras_err_inj_done                   ( ras_err_inj_done_rdlh                ),
    .rdlh_bad_tlp_err                   ( rdlh_bad_tlp_err                     ),
    .rdlh_prot_err                      ( rdlh_prot_err                        ),
    .rdlh_rcvd_as_req_l1                ( rdlh_rcvd_as_req_l1                  ),
    .rdlh_rcvd_pm_enter_l1              ( rdlh_rcvd_pm_enter_l1                ),
    .rdlh_rcvd_pm_enter_l23             ( rdlh_rcvd_pm_enter_l23               ),
    .rdlh_rcvd_pm_req_ack               ( rdlh_rcvd_pm_req_ack                 )
    ,
    .rdlh_bad_tlp_err_pertlp            ( rdlh_bad_tlp_err_pertlp              ),
    .rdlh_lcrc_tlp_err_pertlp           ( rdlh_lcrc_tlp_err_pertlp             ),
    .rdlh_nulified_tlp_err_pertlp       ( rdlh_nulified_tlp_err_pertlp         ),
    .rdlh_duplicate_tlp_err_pertlp      ( rdlh_duplicate_tlp_err_pertlp        ),
    .rdlh_bad_dllp_err_perdllp          ( rdlh_bad_dllp_err_perdllp            ),
    .rdlh_rcvd_nack_perdllp             ( rdlh_rcvd_nack_perdllp               ),
    .rdlh_rcvd_ack_perdllp              ( rdlh_rcvd_ack_perdllp                ),
    .rdlh_vc0_initfc1_status            ( rdlh_vc0_initfc1_status              ),
    .rdlh_vc0_initfc2_status            ( rdlh_vc0_initfc2_status              ),
    .rdlh_curnt_rx_ack_seqnum           ( rdlh_curnt_rx_ack_seqnum             )
    ,
    .rdlh_einj0_lcrc_evt                ( rdlh_einj0_lcrc_evt                  )
   ,.rdlh_rtlh_tlp_idl                  ( rdlh_rtlh_tlp_idl                    ),
    .rdlh_rtlh_tlp_pfx                  ( rdlh_rtlh_tlp_pfx                    )
   ,.rdlh_rtlh_fm_nullified             ( rdlh_rtlh_fm_nullified               ),
    .rdlh_rtlh_fm_poisoned              ( rdlh_rtlh_fm_poisoned                )
    ,
    .rdlh_xdlh_fm_dllp_valid            ( rdlh_xdlh_fm_dllp_valid              ),
    .rdlh_xdlh_l0p_dllp                 ( rdlh_xdlh_l0p_dllp                   )
); //rdlh


// ----------------------------------------------------------------------------
// Layer 3 Receive Datapath (RTLH) instantiation
// ----------------------------------------------------------------------------
rtlh

#(INST) u_rtlh (
    .core_clk                           ( core_clk                             ),
    .core_rst_n                         ( core_rst_n                           ),
    .rstctl_core_flush_req              ( rstctl_core_flush_req                ),
    .cfg_max_payload                    ( cfg_max_payload                      ),
    .cfg_max_payload_rx                 ( cfg_max_payload_rx                   ),
    .cfg_endpoint                       ( cfg_endpoint                         ),
    .cfg_root_compx                     ( cfg_root_compx                       ),
    .cfg_upstream_port                  ( cfg_upstream_port                    ),
    .cfg_tc_enable                      ( cfg_tc_enable                        ),
    .cfg_ext_synch                      ( cfg_ext_synch                        ),
    .cfg_vc_enable                      ( cfg_vc_enable                        ),
    .cfg_vc_struc_vc_id_map             ( cfg_vc_struc_vc_id_map               ),
    .cfg_vc_id_vc_struc_map             ( cfg_vc_id_vc_struc_map               ),
    .cfg_tc_struc_vc_map                ( cfg_tc_struc_vc_map                  ),
    .cfg_fc_wdog_disable                ( cfg_fc_wdog_disable                  ),
    .cfg_fc_latency_value               ( cfg_fc_latency_value                 ),
    .cfg_fc_credit_ph                   ( cfg_fc_credit_ph                     ),
    .cfg_fc_credit_nph                  ( cfg_fc_credit_nph                    ),
    .cfg_fc_credit_cplh                 ( cfg_fc_credit_cplh                   ),
    .cfg_fc_credit_pd                   ( cfg_fc_credit_pd                     ),
    .cfg_fc_credit_npd                  ( cfg_fc_credit_npd                    ),
    .cfg_fc_credit_cpld                 ( cfg_fc_credit_cpld                   ),
    .ras_prot_r_disable                 ( ras_prot_r_disable                   ),
    .fc_scaled_en                       ( fc_scaled_en                         ),
    .hdr_scale_p                        ( hdr_scale_p                          ),
    .hdr_scale_np                       ( hdr_scale_np                         ),
    .hdr_scale_cpl                      ( hdr_scale_cpl                        ),
    .data_scale_p                       ( data_scale_p                         ),
    .data_scale_np                      ( data_scale_np                        ),
    .data_scale_cpl                     ( data_scale_cpl                       ),
    .cfg_max_end2end_tlp_prfxs          ( cfg_max_end2end_tlp_prfxs            ),
    .dpc_fatal_err_gate                 ( dpc_fatal_err_gate                   ),
    .dpc_nonfatal_err_gate              ( dpc_nonfatal_err_gate                ),
    .smlh_in_l1                         ( int_smlh_in_l1                       ),
    .smlh_flit_mode_enable              ( rtlh_flit_mode_enable                ),
    .rdlh_rtlh_rcvd_dllp_fm_opt_fc_up   ( rdlh_rtlh_rcvd_dllp_fm_opt_fc_up     ),
    .rdlh_rtlh_rcvd_dllp                ( rdlh_rtlh_rcvd_dllp                  ),
    .rdlh_rtlh_dllp_content             ( rdlh_rtlh_dllp_content               ),
    .rdlh_rtlh_data                     ( rdlh_rtlh_tlp_data                   ),
    .rdlh_rtlh_soh                      ( rdlh_rtlh_tlp_soh                    ),
    .rdlh_rtlh_eot                      ( rdlh_rtlh_tlp_eot                    ),
    .rdlh_rtlh_idl                      ( rdlh_rtlh_tlp_idl                    ),
    .rdlh_rtlh_pfx                      ( rdlh_rtlh_tlp_pfx                    ),
    .rdlh_rtlh_fm_nullified             ( rdlh_rtlh_fm_nullified               ),
    .rdlh_rtlh_fm_poisoned              ( rdlh_rtlh_fm_poisoned                ),       
    .rdlh_rtlh_dv                       ( rdlh_rtlh_tlp_dv                     ),
    .rdlh_rtlh_abort                    ( rdlh_rtlh_tlp_abort                  ),
    .rdlh_rtlh_link_state               ( rdlh_rtlh_link_state                 ),
    .pm_freeze_fc_timer                 ( pm_freeze_fc_timer                   ),
    .current_data_rate                  ( int_current_data_rate                ),

    .radm_rtlh_ph_ca                    ( radm_rtlh_ph_ca                      ),
    .radm_rtlh_pd_ca                    ( radm_rtlh_pd_ca                      ),
    .radm_rtlh_nph_ca                   ( radm_rtlh_nph_ca                     ),
    .radm_rtlh_npd_ca                   ( radm_rtlh_npd_ca                     ),
    .radm_rtlh_cplh_ca                  ( radm_rtlh_cplh_ca                    ),
    .radm_rtlh_cpld_ca                  ( radm_rtlh_cpld_ca                    ),
    .xdlh_rtlh_fc_ack                   ( xdlh_rtlh_fc_ack                     ),
    .xadm_all_type_infinite             ( xadm_all_type_infinite               ),

    .cdm_ras_des_einj4_enable           ( cdm_ras_des_einj4_enable             ),
    .cdm_ras_des_einj4_updfc_type       ( cdm_ras_des_einj4_updfc_type         ),
    .cdm_ras_des_einj4_vcnum            ( cdm_ras_des_einj4_vcnum              ),
    .cdm_ras_des_einj4_badfc_value      ( cdm_ras_des_einj4_badfc_value        ),
    .cfg_flow_control_disable           ( cfg_flow_control_disable             ),
    .cdm_ras_des_einj2_enable           ( xplh_ras_des_einj2_enable            ),
    .cdm_ras_des_einj2_dllp_type        ( xplh_ras_des_einj2_dllp_type         ),
    .ras_err_inj_en_array               ( ras_err_inj_en_array                 ),
    .ras_err_inj_mask                   ( ras_err_inj_mask                     ),
// ---- outputs ---------------
    .ras_stat_rtlh_corr                 ( ras_stat_rtlh_corr                   ),
    .ras_stat_rtlh_uncorr               ( ras_stat_rtlh_uncorr                 ),
    .ras_err_inj_done                   ( ras_err_inj_done_rtlh                ),
    .init_fc1_rcvd                      ( init_fc1_rcvd                        ),
    .rtlh_rdlh_fci1_fci2                ( rtlh_rdlh_fci1_fci2                  ),
    .rtlh_xdlh_fc_req                   ( rtlh_xdlh_fc_req                     ),
    .rtlh_xdlh_fc_req_hi                ( rtlh_xdlh_fc_req_hi                  ),
    .rtlh_xdlh_fc_req_low               ( rtlh_xdlh_fc_req_low                 ),
    .rtlh_xdlh_fc_data                  ( rtlh_xdlh_fc_data                    ),
    .rtlh_parerr                        ( rtlh_parerr                          ),
    .rtlh_rfc                           ( rtlh_rfc                             ),

    .rtlh_radm                          ( rtlh_radm                            ),
    .rtlh_fc_init_status                ( rtlh_fc_init_status                  ),
    .rtlh_crd_not_rtn                   ( rtlh_crd_not_rtn                     ),
    .rtlh_req_link_retrain              ( rtlh_req_link_retrain                ),
    .rtfcgen_ph_diff_vc0                ( rtfcgen_ph_diff                      ),
    .rtlh_overfl_err                    ( rtlh_overfl_err                      )
    ,
    .rtlh_rcvd_ufc_perdllp              ( rtlh_rcvd_ufc_perdllp                ),
    .rtlh_rx_memwr_evt                  ( rtlh_rx_memwr_evt                    ),
    .rtlh_rx_defmemwr_evt               ( rtlh_rx_defmemwr_evt                 ),
    .rtlh_rx_memrd_evt                  ( rtlh_rx_memrd_evt                    ),
    .rtlh_rx_cfgwr_evt                  ( rtlh_rx_cfgwr_evt                    ),
    .rtlh_rx_cfgrd_evt                  ( rtlh_rx_cfgrd_evt                    ),
    .rtlh_rx_iowr_evt                   ( rtlh_rx_iowr_evt                     ),
    .rtlh_rx_iord_evt                   ( rtlh_rx_iord_evt                     ),
    .rtlh_rx_cplwod_evt                 ( rtlh_rx_cplwod_evt                   ),
    .rtlh_rx_cplwd_evt                  ( rtlh_rx_cplwd_evt                    ),
    .rtlh_rx_msg_evt                    ( rtlh_rx_msg_evt                      ),
    .rtlh_rx_atmcop_evt                 ( rtlh_rx_atmcop_evt                   ),
    .rtlh_rx_tlpwprefix_evt             ( rtlh_rx_tlpwprefix_evt               ),
    .rtlh_rx_tlp_dpsize                 ( rtlh_rx_tlp_dpsize                   ),
    .rtlh_fc_rcvd_ph                    ( rtlh_fc_rcvd_ph                      ),
    .rtlh_fc_rcvd_pd                    ( rtlh_fc_rcvd_pd                      ),
    .rtlh_fc_rcvd_nph                   ( rtlh_fc_rcvd_nph                     ),
    .rtlh_fc_rcvd_npd                   ( rtlh_fc_rcvd_npd                     ),
    .rtlh_fc_rcvd_cplh                  ( rtlh_fc_rcvd_cplh                    ),
    .rtlh_fc_rcvd_cpld                  ( rtlh_fc_rcvd_cpld                    ),
    .rtlh_fc_allctd_ph                  ( rtlh_fc_allctd_ph                    ),
    .rtlh_fc_allctd_pd                  ( rtlh_fc_allctd_pd                    ),
    .rtlh_fc_allctd_nph                 ( rtlh_fc_allctd_nph                   ),
    .rtlh_fc_allctd_npd                 ( rtlh_fc_allctd_npd                   ),
    .rtlh_fc_allctd_cplh                ( rtlh_fc_allctd_cplh                  ),
    .rtlh_fc_allctd_cpld                ( rtlh_fc_allctd_cpld                  )
    ,
    .rtlh_einj4_fc_evt                  ( rtlh_einj4_fc_evt                    )
); //rtlh


// ----------------------------------------------------------------------------
// Layer 2 Transmit Datapath (XDLH) instantiation
// ----------------------------------------------------------------------------
xdlh_128b

#(INST) u_xdlh(
    .b_xdlh_xplh_mp                     ( b_xdlh_xplh                          ),
    .b_xdlh_spif                        ( b_xdlh_spif.xplh_slave_mp            ),
    .core_clk                           ( core_clk                             ),
    .core_rst_n                         ( core_rst_n                           ),
    .xmlh_xplh_halt                     ( xmlh_xplh_halt                       ),
    .xplh_xmlh_eot                      ( xplh_xmlh_eot[NW_NFM-1:0]            ),
    .xdlh_l0p_dllp                      ( xdlh_l0p_dllp                        ),
    .xdlh_dllp_l0p_ack                  ( xdlh_dllp_l0p_ack                    ),
    .xplh_l0p_dllps_count               ( xplh_l0p_dllps_count                 ),
    .cfg_upstream_port                  ( cfg_upstream_port                    ),
    .cfg_replay_timer_value             ( cfg_replay_timer_value               ),
    .cfg_ack_freq                       ( cfg_ack_freq                         ),
    .cfg_ack_latency_timer              ( cfg_ack_latency_timer                ),
    .cfg_other_msg_payload              ( cfg_other_msg_payload                ),
    .cfg_other_msg_request              ( cfg_other_msg_request                ),
    .cfg_corrupt_crc_pattern            ( cfg_corrupt_crc_pattern              ),
    .cfg_flow_control_disable           ( cfg_flow_control_disable             ),
    .cfg_acknack_disable                ( cfg_acknack_disable                  ),
    .pm_xdlh_dllp_req                   ( pm_xdlh_dllp_req                     ),
    .smlh_link_in_training              ( int_smlh_link_in_training            ),
    .smlh_in_l0                         ( int_smlh_in_l0                       ),
    .smlh_in_l0s                        ( int_smlh_in_l0s                      ),
    .smlh_in_l1                         ( int_smlh_in_l1                       ),
    .smlh_eq_pending                    ( int_smlh_eq_pending                  ),
    .pm_freeze_ack_timer                ( 1'b0                                 ),
    .current_data_rate                  ( int_current_data_rate                ),
    .cfg_rasdp_error_mode_en            ( cfg_rasdp_error_mode_en              ),
    .cfg_rasdp_error_mode               ( cfg_rasdp_error_mode                 ),
    .xdlh_rasdp_error_mode              ( xdlh_rasdp_error_mode                ),
    .ras_dp_err_log                     ( ras_dp_err_log_xdlh                  ),
    .ras_dp_err_inj                     ( ras_dp_err_inj                       ),
    .xtlh_xdlh_tlp_len                  ( xtlh_xdlh_tlp_len                    ),       // When TLP Prefix is enabled in GEN3, need the TLP LEN info for STP.

    .xtlh_sot_is_first                  ( xtlh_sot_is_first                    ),
    .xtlh_eot_sot_eot                   ( xtlh_eot_sot_eot                     ),
    .xtlh_badeot                        ( xtlh_badeot                          ),
    .xtlh_first_badeot                  ( xtlh_first_badeot                    ),
    .xtlh_eot_sot                       ( xtlh_eot_sot                         ),
    .xtlh_xdlh_data                     ( xtlh_xdlh_data                       ),
    .xtlh_xdlh_dv                       ( xtlh_xdlh_dv                         ),
    .xtlh_xdlh_sot                      ( xtlh_xdlh_sot                        ),
    .xtlh_xdlh_eot                      ( xtlh_xdlh_eot                        ),
    .xtlh_xdlh_badeot                   ( xtlh_xdlh_badeot                     ),
    .rdlh_link_up                       ( rdlh_link_up                         ),
    .rdlh_xdlh_rcvd_nack                ( rdlh_xdlh_rcvd_nack                  ),
    .rdlh_xdlh_rcvd_ack                 ( rdlh_xdlh_rcvd_ack                   ),
    .rdlh_xdlh_rcvd_acknack_seqnum      ( rdlh_xdlh_rcvd_acknack_seqnum        ),
    .rdlh_xdlh_req2send_ack             ( rdlh_xdlh_req2send_ack               ),
    .rdlh_xdlh_req2send_ack_due2dup     ( rdlh_xdlh_req2send_ack_due2dup       ),
    .rdlh_xdlh_req2send_nack            ( rdlh_xdlh_req2send_nack              ),
    .rdlh_xdlh_req_acknack_seqnum       ( rdlh_xdlh_req_acknack_seqnum         ),
    .rtlh_xdlh_fc_req                   ( rtlh_xdlh_fc_req                     ),
    .rtlh_xdlh_fc_req_hi                ( rtlh_xdlh_fc_req_hi                  ),
    .rtlh_xdlh_fc_req_low               ( rtlh_xdlh_fc_req_low                 ),
    .rtlh_xdlh_fc_data                  ( rtlh_xdlh_fc_data                    ),
    .xdlh_block_dl_init                 ( int_block_dl_init                    ),
    .xdlh_dl_active                     ( int_dl_active                        ),
    .xdlh_protocol_cfg                  ( sdlh_protocol_cfg                    ),
    .xdlh_pl_stall_req                  ( xdlh_pl_stall_req                    ),
    .xdlh_lp_stall_ack                  ( xdlh_lp_stall_ack                    ),
    .xdlh_pm_state_req                  ( xdlh_pm_state_req                    ),
    .xdlh_pm_dllp_ack                   ( xdlh_pm_dllp_ack                     ),
    .send_feature_dllp                  ( send_feature_dllp                    ),
    .cfg_local_feature_support          ( cfg_local_feature_support            ),
    .cfg_dlink_feature_valid            ( cfg_dlink_feature_valid              ),
    .xdlh_rdlh_feature_ack              ( xdlh_rdlh_feature_ack                ),
    .xmlh_stp_start                     ( xmtbyte_stp_start                    ),
    .smlh_link_mode                     ( int_smlh_link_mode                   ),
    .lcrc_err_en                        ( lcrc_err_en                          ),
    .cdm_ras_des_force_linkdown_noack   ( cdm_ras_des_force_linkdown_noack     ),
    .cdm_ras_des_einj0_enable           ( cdm_ras_des_einj0_enable             ),
    .cdm_ras_des_einj0_crc_type         ( cdm_ras_des_einj0_crc_type           ),
    .cdm_ras_des_einj0_count            ( cdm_ras_des_einj0_count              ),
    .cdm_ras_des_einj1_enable           ( cdm_ras_des_einj1_enable             ),
    .cdm_ras_des_einj1_seq_type         ( cdm_ras_des_einj1_seq_type           ),
    .cdm_ras_des_einj1_bad_seq          ( cdm_ras_des_einj1_bad_seq            ),
    .cdm_ras_des_einj1_count            ( cdm_ras_des_einj1_count              ),
    .cdm_ras_des_einj2_enable           ( cdm_ras_des_einj2_enable             ),
    .cdm_ras_des_einj2_dllp_type        ( cdm_ras_des_einj2_dllp_type          ),
    .cdm_ras_des_einj5_enable           ( cdm_ras_des_einj5_enable             ),
    .cdm_ras_des_einj5_count            ( cdm_ras_des_einj5_count              ),
    .cdm_ras_des_einj5_tlp_type         ( cdm_ras_des_einj5_tlp_type           ),
    .smlh_in_rcvry                      ( int_smlh_link_in_training            ),
// ---- outputs ---------------
    .lcrc_err_asserted                  ( lcrc_err_asserted                    ),
    .xdlh_xtlh_halt                     ( xdlh_xtlh_halt                       ),
    .xdlh_rdlh_last_xmt_seqnum          ( xdlh_rdlh_last_xmt_seqnum            ),
    .xdlh_rtlh_fc_ack                   ( xdlh_rtlh_fc_ack                     ),
    .xdlh_smlh_start_link_retrain       ( xdlh_sdlh_retrain_req                ),
    .xdlh_curnt_seqnum                  ( xdlh_curnt_seqnum                    ),
    .xdlh_retrybuf_not_empty            ( xdlh_retrybuf_not_empty              ),
    .xdlh_not_expecting_ack             ( xdlh_not_expecting_ack               ),
    .xdlh_xmt_pme_ack                   ( xdlh_xmt_pme_ack                     ),
    .xdlh_nodllp_pending                ( xdlh_nodllp_pending                  ),
    .xdlh_no_acknak_dllp_pending        ( xdlh_no_acknak_dllp_pending          ),
    .xdlh_tlp_pending                   ( xdlh_tlp_pending                     ),
    .xdlh_retry_pending                 ( xdlh_retry_pending                   ),


    // Retry buffer external RAM interface
    .xdlh_retryram_if                   ( xdlh_retryram_if                     ),
    .xdlh_retryram_par_chk_val          ( xdlh_retryram_par_chk_val            ),
    .xdlh_retryram_halt                 ( xdlh_retryram_halt                   ),
    .retryram_xdlh_data                 ( retryram_xdlh_data                   ),
    .retryram_xdlh_depth                ( retryram_xdlh_depth                  ),
    .retryram_xdlh_parerr               ( retryram_xdlh_parerr                 ),

//   Performance change - 2p RAM I/F
    .xdlh_retrysotram_waddr             ( xdlh_retrysotram_waddr               ),
    .xdlh_retrysotram_raddr             ( xdlh_retrysotram_raddr               ),
    .xdlh_retrysotram_data              ( xdlh_retrysotram_data                ),
    .xdlh_retrysotram_en                ( xdlh_retrysotram_en                  ),
    .xdlh_retrysotram_we                ( xdlh_retrysotram_we                  ),
    .xdlh_retrysotram_par_chk_val       ( xdlh_retrysotram_par_chk_val         ),
    .retrysotram_xdlh_data              ( retrysotram_xdlh_data                ),
    .retrysotram_xdlh_parerr            ( retrysotram_xdlh_parerr              ),
    .retrysotram_xdlh_depth             ( retrysotram_xdlh_depth               ),
    .nak_scheduled                      ( nak_scheduled                        ),
    .xdlh_retry_req                     ( xdlh_retry_req                       )
    ,
    .xdlh_nak_sent                      ( xdlh_nak_sent                        ),
    .xdlh_ack_sent                      ( xdlh_ack_sent                        ),
    .xdlh_update_fc_sent                ( xdlh_update_fc_sent                  ),
    .xdlh_smlh_goto_detect              ( xdlh_smlh_goto_detect                )
    ,
    .xdlh_einj0_lcrc_evt                ( xdlh_einj0_lcrc_evt                  ),
    .xdlh_einj0_fcrc_evt                ( xdlh_einj0_fcrc_evt                  ),
    .xdlh_einj0_dllpcrc_evt             ( xdlh_einj0_dllpcrc_evt               ),
    .xdlh_einj1_tx_tlp_snum_evt         ( xdlh_ras_des_einj1_exp_sequm_evt     ),
    .xdlh_einj1_tx_dllp_snum_evt        ( xdlh_ras_des_einj1_ack_nak_sequm_evt ),
    .xdlh_einj2_nak_evt                 ( xdlh_einj2_nak_evt                   ),
    .xdlh_einj5_nultlp_evt              ( xdlh_einj5_nultlp_evt                ),
    .xdlh_einj5_dup_evt                 ( xdlh_einj5_dup_evt                   )
    ,
    .rbuf_pkt_cnt                       ( xdlh_rbuf_pkt_cnt                    )
    ,  
    .xdlh_ptm_sot                       ( i_xdlh_ptm_sot                       ),
    .xdlh_ptm_multi_cycle               ( i_xdlh_ptm_multi_cycle               ),
    .xdlh_ptm_request                   ( i_xdlh_ptm_request                   ),
    .xdlh_ptm_response                  ( i_xdlh_ptm_response                  ),
    .xdlh_rbuf_replaying                ( i_xdlh_rbuf_replaying                )
    ,
    .xdlh_replay_timeout                ( xdlh_replay_timeout_err              ),
    .xdlh_replay_timer_value            ( xdlh_replay_timer_value              )
    ,
    .xplh_xdlh_cmd                      ( sdlh_xdlh_cmd                        ),
    .xdlh_xplh_cmd_ack                  ( xdlh_sdlh_cmd_ack                    ),
    .xdlh_xtlh_cmd                      ( xdlh_xtlh_cmd_org                    ),
    .xtlh_xdlh_cmd_ack                  ( xtlh_xdlh_cmd_ack                    )
    ,
    .xtlh_xdlh_flit                     ( xtlh_xdlh_flit                       ),
    .xplh_xdlh_dllp_halt                ( xplh_xdlh_dllp_halt                  ),
    .xdlh_xplh_dllp_out                 ( xdlh_xplh_dllp_out                   ),
    .rtlh_fc_init_status                ( rtlh_fc_init_status                  ),
    .xdlh_upd_fc_sent                   ( xdlh_update_fc_fm                    ),
    .xdlh_xtlh_fc_init_done             ( xdlh_xtlh_fc_init_done               )
); //xdlh_128b




// ----------------------------------------------------------------------------
// Layer 3 Transmit
// ----------------------------------------------------------------------------

xtlh_ms
 u_xtlh (
    .rstctl_core_flush_req              ( rstctl_core_flush_req                ),
    .cfg_rasdp_error_mode               ( cfg_rasdp_error_mode                 ),
    .xdlh_rasdp_error_mode              ( xdlh_rasdp_error_mode                ),
    .ras_dp_err_log                     ( ras_dp_err_log_xtlh                  ),
    .ras_dp_err_inj                     ( ras_dp_err_inj                       ),
    .core_clk                           ( core_clk                             ),
    .core_rst_n                         ( core_rst_n                           ),
    .spif_enable                        ( sdlh_protocol_cfg.spif_enable        ),
    .xadm_xtlh_pkt                      ( xadm_xtlh_pkt                        ),
    .xtlh_xadm_pkt_halt                 ( xtlh_xadm_pkt_halt                   ),
    .xdlh_xtlh_cmd                      ( xdlh_xtlh_cmd_ovr                    ),
    .xtlh_xdlh_cmd_ack                  ( xtlh_xdlh_cmd_ack                    )
    ,
    .xtlh_xdlh_flit                     ( xtlh_xdlh_flit                       ),
    .xdlh_xtlh_fc_init_done             ( xdlh_xtlh_fc_init_done               )
    ,
    .cdm_err_inj_en                     ( cdm_err_inj_en                       ),
    .cdm_tx_err_inj_en                  ( cdm_tx_err_inj_en                    )
    ,
    .xdlh_xtlh_halt                     ( xdlh_xtlh_halt                       ),
    .xtlh_tlp_pending                   ( xtlh_tlp_pending                     ),
    .xtlh_xdlh_data                     ( xtlh_xdlh_data                       ),
    .xtlh_xdlh_dv                       ( xtlh_xdlh_dv                         ),
    .xtlh_xdlh_sot                      ( xtlh_xdlh_sot                        ),
    .xtlh_xdlh_eot                      ( xtlh_xdlh_eot                        ),
    .xtlh_xdlh_badeot                   ( xtlh_xdlh_badeot                     ),
    .xtlh_xdlh_sot_is_first             ( xtlh_sot_is_first                    ),
    .xtlh_xdlh_badeot_or                ( xtlh_badeot                          ),
    .xtlh_xdlh_first_badeot             ( xtlh_first_badeot                    ),
    .xtlh_xdlh_eot_sot                  ( xtlh_eot_sot                         ),
    .xtlh_xdlh_eot_sot_eot              ( xtlh_eot_sot_eot                     ),
    .cfg_tx_arb_control                 ( cfg_tx_arb_control                   )
    ,
    .xtlh_xdlh_tlp_len                  ( xtlh_xdlh_tlp_len                    )
    ,
    .xtlh_pm_pme_to_ack                 ( xtlh_pm_pme_to_ack                   )
    ,
    .xtlh_xadm_posted_tlp_sent          ( xtlh_xadm_posted_tlp_sent            )
);



`ifndef SYNTHESIS
`endif // SYNTHESIS

endmodule // cx_lp
