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
// ---    $DateTime: 2024/01/12 11:11:14 $
// ---    $Revision: #44 $

// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_error_reg.sv#44 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the AER capability registers.
// --- Both PF and VF implementations are supported, selected via the VF_IMPL parameter.
// --- The differences between the two implementations are:
// ---  - for VFs mask/severity registers are taken from corresponding inputs
// ---  - ...
// -----------------------------------------------------------------------------
// legend
// pci: pci-compatible error reporting
// base: pcie baseline error reporting
// aer: pcie advanced error reporting

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
 
 module cdm_error_reg
 import DWC_pcie_ctl_pkg::MSG_TLP_WD;
 import DWC_pcie_ctl_pkg::ERROR_TLP_WD;
 import DWC_pcie_core_pkg::radm_hdr_log_s;
 import DWC_pcie_core_pkg::xadm_xmt_pci_errors_t;
 (
// -- inputs --
    core_clk,
    non_sticky_rst_n,
    sticky_rst_n,
    cdm_clk_g,
    device_type,
    lbc_cdm_data,
    lbc_cdm_dbi,
    err_write_pulse,
    err_read_pulse,
    err_reg_id,
    rcrb_err_write_pulse,
    rcrb_err_read_pulse,
    rcrb_err_reg_id_0,
    pm_bus_num, // aer && rc
    pm_dev_num, // aer && rc
    cfg_int_disable, // aer && rc
    cfg_msi_en, // aer && rc
    cfg_msix_en, // aer && rc
    cfg_reg_perren, // pci
    cfg_reg_serren,
    cfg_br_ctrl_serren, // pci, aer && rc
    cfg_br_ctrl_perren, // pci
    cfg_cor_err_rpt_en, // (base, aer)
    cfg_nf_err_rpt_en, // (base, aer)
    cfg_f_err_rpt_en, // (base, aer)
    cfg_unsupt_req_rpt_en, // (base, aer)
    cdm_err_detect,
    app_advisory_nf_err,
    app_hdr_log_overflow_det,
    cdm_err_advisory,

    // Error sources
    rmlh_rcvd_err, // (base, aer) && pf - corr (non-func specific)
    rdlh_bad_tlp_err, // (base, aer) && pf - corr (non-func specific)
    rdlh_bad_dllp_err, // (base, aer) && pf - corr (non-func specific)
    dl_prot_err, // (base, aer) && pf - corr (non-func specific)
    surprise_down_err, // (base, aer) && pf
    xdlh_replay_timeout_err, // (base, aer) && pf - corr (non-func specific)
    xdlh_replay_num_rlover_err, // (base, aer) && pf - corr (non-func specific)

    radm_rcvd_wreq_poisoned,
    radm_rcvd_cpl_poisoned,
    radm_rcvd_req_ur,
    radm_rcvd_req_ca,
    radm_cpl_timeout_err, // (base, aer)
    radm_unexp_cpl_err,// (base, aer) && pf - (non-func specific)
    radm_ecrc_err, // aer && pf (non-func specific)

    tlp_trans_egress_blk,
    radm_atomic_egress_blk, // aer && pf (non-func specific)
    rtlh_fc_prot_err, // (base, aer) && pf (non-func specific)
    rtlh_overfl_err, // (base, aer) && pf (non-func specific)
    radm_mlf_tlp_err, // (base, aer) && pf (non-func specific)
    radm_acs_violation, // (aer)
    acs_viol_svrity_mask_wr_en, // Indicates that ACS Violation Severity and Mask fields are writable
    internal_err,       // (base, aer) && pf (non-func specific)
    corr_internal_err,  // (base, aer) && pf - corr (non-func specific)
    lbc_xmt_cpl_ca, // pci
    xal_xmt_cpl_ca, // pci
    xal_rcvd_cpl_ca, // pci
    xal_rcvd_cpl_ur, // pci
    xal_perr, // pci
    xal_serr, // pci
    xal_set_trgt_abort_primary, // pci
    xal_set_mstr_abort_primary, // pci
    xal_pci_addr_perr, // pci
    radm_rcvd_cpl_ur, // pci
    radm_rcvd_cpl_ca, // pci
    xadm_xmt_pci_errors,
    radm_hdr_log_valid,
    radm_hdr_log_flitmode,
    radm_hdr_log_hdrsize,
    radm_hdr_log_np_req,
    radm_hdr_log,
    tlp_prfx_blocked_err,
    psnd_tlp_egrss_blckd_err,

    radm_correctable_err, // aer && rc
    radm_nonfatal_err, // pci, aer && rc
    radm_fatal_err, // pci, aer && rc
    radm_msg_req_id, // aer && rc
    // PF settings used by VFs
    pf_cfg_aer_uncorr_mask, // aer && vf
    pf_cfg_aer_uncorr_svrity, // aer && vf
    pf_cfg_aer_corr_mask, // aer && vf
    pf_multi_hdr_rec_en,  // aer && vf
    dbi_ro_wr_en,
    cfg_pcie_surp_dn_rpt_cap,
    cfg_ecrc_chk_en,
    cdm_dpc_triggered,
    cdm_dpc_trig_status,
    cdm_dpc_trig_en,
    int_dpc_sw_trigger,
    dpc_triggered_detect,
    int_dpc_err_cor_en,
    cfg_p2p_err_rpt_ctrl,

    cxl_rcrb_enable,
    msggen_cdm_send_f_err,
    msggen_cdm_send_nf_err,
// -- outputs --
    ecrc_chk_en, // aer && pf
    ecrc_gen_en, // aer && pf
    err_reg_data,
    cfg_send_cor_err, // base
    cfg_send_nf_err, // base
    cfg_send_f_err, // base
    cfg_func_spec_err, // (base, aer) && pf
    cfg_aer_rc_err_int, // aer && rc
    cfg_aer_rc_err_msi, // aer && rc
    cfg_aer_int_msg_num, // aer && rc
    cfg_rprt_err_cor, // aer && rc
    cfg_rprt_err_nf, // aer && rc
    cfg_rprt_err_f, // aer && rc
    cfg_cor_err_det, // base
    cfg_nf_err_det, // base
    cfg_f_err_det, // base
    cfg_unsupt_req_det, // base
    master_data_perr_det, // pci
    signaled_target_abort_det, // pci
    rcvd_target_abort_det, // pci
    rcvd_master_abort_det, // pci
    signaled_sys_err_det, // pci
    perr_det, // pci
    master_data_perr_det2, // pci
    signaled_target_abort_det2, // pci
    rcvd_target_abort_det2, // pci
    rcvd_master_abort_det2, // pci
    signaled_sys_err_det2, // pci
    perr_det2, // pci
    // PF settings exported to VFs
    cfg_aer_uncorr_mask, // aer && pf
    cfg_aer_uncorr_svrity, // aer && pf
    cfg_aer_corr_mask, // aer && pf
    multi_hdr_rec_en // aer && pf
    ,
    int_dpc_triggered,
    int_dpc_trig_reason,
    int_dpc_trig_reason_extn,
    cdm_aer_dpc_triggered,
    cdm_core_in_dpc,
    dpc_err_src_id
    ,cfg_uncor_internal_err_sts,
    cfg_rcvr_overflow_err_sts,
    cfg_fc_protocol_err_sts,
    cfg_mlf_tlp_err_sts,
    cfg_surprise_down_er_sts,
    cfg_dl_protocol_err_sts,
    cfg_ecrc_err_sts,
    cfg_corrected_internal_err_sts,
    cfg_replay_number_rollover_err_sts,
    cfg_replay_timer_timeout_err_sts,
    cfg_bad_dllp_err_sts,
    cfg_bad_tlp_err_sts,
    cfg_rcvr_err_sts,
    advisory_nf_sts, 
    hdr_log_overflow_sts
);
parameter INST      = 0;                        // The uniquifying parameter for each port logic instance.
parameter FUNC_NUM  = 3'h0;                     // uniquifying parameter per function
parameter VF_IMPL   = 0;                        // 0: PF impl. 1: VF impl.
parameter TP        = `TP;                      // Clock to Q delay (simulator insurance)
parameter NF        = `CX_NFUNC;                // Number of functions
parameter NFUNC_WD  = `CX_NFUNC_WD;             // Width of physical function number
//`ifdef VF_HDR_LOG_SHARED_ENABLED
parameter NVF       = `CX_NVFUNC;
parameter NPRFX     = `CX_NPRFX;//`CX_TLP_PREFIX_ENABLE;
parameter MAX_END2END_TLP_PRFXS_VALUE = `CX_MAX_END2END_TLP_PRFXS_VALUE; 
//`endif
localparam VFI_WD    = `CX_LOGBASE2(NVF);      // number of bits needed to represent the vf index [0 ... NVF-1]
localparam VF_WD     = `CX_LOGBASE2(NVF) + 1;  // number of bits needed to represent the vf number plus one bit to indicate vf_active, i.e. if the pf,vf pair indicates a pf only or a vf within a pf
parameter PF_WD         = `CX_NFUNC_WD;             // number of bits needed to represent the pf number [0..NF-1], when this block is configured for sriov it is calculated as log2(NF), hardcoded to 3 otherwise
localparam FX_TLP    = `CX_FX_TLP;             // Number of TLPs received in a single cycle after formation block

localparam PRFX_SIZE                  = NPRFX>3 ? 128 : NPRFX>2 ? 96 : NPRFX>1 ? 64 : 32; // size of variable fields in TLP Prefix Log
localparam FEPTR_SIZE                 = 5;
localparam AER_CAP_ENABLE             = VF_IMPL ? `VF_AER_ENABLE   : `AER_ENABLE;
localparam CX_HDR_LOG_DEPTH           = `CX_HDR_LOG_DEPTH;
localparam VF_HDR_LOG_DEPTH           = `VF_HDR_LOG_DEPTH;
localparam VF_HDR_LOG_SHARED          = `VF_HDR_LOG_SHARED;
localparam VF_IMPL_VF_HDR_LOG_SHARED  = ((VF_IMPL != 0) && `VF_AER_ENABLE && VF_HDR_LOG_SHARED);
localparam LOCAL_AER_NEXT_PTR         = VF_IMPL ? `VF_AER_NEXT_PTR : ((FUNC_NUM==0) ? `AER_NEXT_PTR_0 : `AER_NEXT_PTR_N);
localparam HDR_SIZE                   = `CX_AER_HDR_WIDTH;  //HDR Size in bits
localparam HDR_SIZE_DW                = `CX_MAX_HDR_LOG_SZ; //HDR SIZE IN DWs
localparam TLP_SIZE                   = HDR_SIZE ;
localparam HDR_LOG_SIZE_WD            = 5; //`CX_LOGBASE2(HDR_SIZE_DW); // number of bits needed to indicated the number of Header Size in DWs
localparam HDRLOG_WD                  = `CX_LOGBASE2(HDR_SIZE_DW);
localparam FLIT_MODE_ENABLE           = `CX_FLIT_MODE_SUPPORTED;
localparam ELQ_WIDTH                  = TLP_SIZE+FEPTR_SIZE+1+HDR_LOG_SIZE_WD;
localparam ERR_REG_ID_WD              = 




  1? 19:
                                         18; 

localparam HDR_PRFX_WD                = (NPRFX > 0) ? (TLP_SIZE + PRFX_SIZE) : TLP_SIZE;

localparam [4:0] AER_INT_MSG_NUM       = VF_IMPL ? 0                : `AER_INT_MSG_NUM;
localparam DATA_DELAY_BCM36_NHS = 3;  // Type of random delay to be added to signal in simulation by bcm36_nhs
// -------------- Inputs ---------------
input           core_clk;
input           non_sticky_rst_n;
input           sticky_rst_n;
input           cdm_clk_g;                  // gated version of the aux_clk_g, based on access activity to cdm, enable signal comes from lbc
input   [3:0]   device_type;

input   [31:0]  lbc_cdm_data;                   // Data for write
input           lbc_cdm_dbi;
input   [3:0]   err_write_pulse;
input           err_read_pulse;
input   [ERR_REG_ID_WD -1:0]  err_reg_id;
input   [3:0]   rcrb_err_write_pulse;
input           rcrb_err_read_pulse;
input           rcrb_err_reg_id_0;
input   [7:0]   pm_bus_num;                     // Current bus #
input   [4:0]   pm_dev_num;                     // Current device #
input           cfg_int_disable;                // Interrupt disable
input           cfg_msi_en;                     // MSI enable
input           cfg_msix_en;                    // MSI-X enable
input           cfg_reg_perren;                 // Parity error response enable
input           cfg_reg_serren;                 // SERR# enable
input           cfg_br_ctrl_serren;             // Bridge control: SERR# enable
input           cfg_br_ctrl_perren;             // Bridge Control: Parity Error Response Enable
input           cfg_cor_err_rpt_en;             // Correctable error reporting enable
input           cfg_nf_err_rpt_en;              // Non-fatal error reporting enable
input           cfg_f_err_rpt_en;               // Fatal error reporting enable
input           cfg_unsupt_req_rpt_en;          // Unsupported request error reporting enable
input          cdm_err_detect;                  // Detector of Error, 0 - Core, 1 - Application
input          app_advisory_nf_err;             // Advisory nonfatal error from application.
input          app_hdr_log_overflow_det;        // Header Log overflow error from application.
input [FX_TLP-1:0] cdm_err_advisory;               // Advisory non-fatal error

// Error sources
// Physical Layer errors
input           rmlh_rcvd_err;                  // Receiver error
// Data Link Layer errors
input           rdlh_bad_tlp_err;               // Bad TLP error
input           rdlh_bad_dllp_err;              // Bad DLLP error
input           dl_prot_err;                    // Data Link Protocol Error
input           surprise_down_err;              // Surprise Down Error
input           xdlh_replay_timeout_err;        // Replay timer timeout
input           xdlh_replay_num_rlover_err;     // Replay_num rollover
// Transaction Layer errors
input [ERROR_TLP_WD-1:0]  radm_rcvd_wreq_poisoned;    // Received poisoned write request
input [ERROR_TLP_WD-1:0]  radm_rcvd_cpl_poisoned;     // Received poisoned CPL
input [ERROR_TLP_WD-1:0]  radm_rcvd_req_ur;           // Received unsuported request
input [ERROR_TLP_WD-1:0]  radm_rcvd_req_ca;           // Received completer abort request
input [ERROR_TLP_WD-1:0]  radm_cpl_timeout_err;       // Completion time out
input [ERROR_TLP_WD-1:0]  radm_unexp_cpl_err;         // unexpected completion
input [(ERROR_TLP_WD*NF)-1:0]  radm_ecrc_err;              // Ecrc error
input               tlp_trans_egress_blk;       //TLP translation egress Blocked Error
input               radm_atomic_egress_blk;     // AtomicOp Egress Blocked Error
input [ERROR_TLP_WD-1:0]  radm_mlf_tlp_err;           // Malformed TLP
input [ERROR_TLP_WD-1:0]  radm_acs_violation;         // ACS Violation
input               acs_viol_svrity_mask_wr_en; // Indicates that ACS Violation Severity and Mask fields are writable
input           rtlh_fc_prot_err;               // Flow control protocol error
input           rtlh_overfl_err;                // Receiver overflow
input           internal_err;                   // Uncorrectable Internal Error
input           corr_internal_err;              // Corrected Internal Error
// Errors associated Bridge/Switch
input           lbc_xmt_cpl_ca;                 // LBC sent a CPL w/ CA
input           xal_xmt_cpl_ca;                 // internal logic side transmit completion with CA
input           xal_rcvd_cpl_ca;                // Received a CPL w/ CA when core is a requester
input           xal_rcvd_cpl_ur;                // Received a CPL w/ UR when core is a requester
input           xal_perr;                       // Received PERR# on secondary interface(PCIe -> PCI/PCI-X bridge)
input           xal_serr;                       // Received SERR# on secondary interface(PCIe -> PCI/PCI-X bridge)
input           xal_set_trgt_abort_primary;     // Set trgt abort of primary(PCIe -> PCI/PCI-X bridge)
input           xal_set_mstr_abort_primary;     // Set mstr abort of primary(PCIe -> PCI/PCI-X bridge)
input           xal_pci_addr_perr;              // Set secondary parity err detected(PCIe -> PCI/PCI-X bridge address/attribute error)
input [ERROR_TLP_WD-1:0]  radm_rcvd_cpl_ur;           // Received completion with UR status
input [ERROR_TLP_WD-1:0]  radm_rcvd_cpl_ca;           // Received completion with CA status
input xadm_xmt_pci_errors_t xadm_xmt_pci_errors;
// Header error logging
input [ERROR_TLP_WD-1:0]       radm_hdr_log_valid;    // TLP Error Header Ready
input        radm_hdr_log_flitmode;
input [HDR_LOG_SIZE_WD-1:0]  radm_hdr_log_hdrsize;
input        radm_hdr_log_np_req;

input [HDR_SIZE-1: 0] radm_hdr_log;

input                    tlp_prfx_blocked_err;  // TLP Prefix Blocked Error (from App interface)
input                    psnd_tlp_egrss_blckd_err; // Poisoned TLP Egress Blocked Error (from App interface)

// Received error messages
input [MSG_TLP_WD-1:0]       radm_correctable_err;  // Received Correctable Error MSG
input [MSG_TLP_WD-1:0]       radm_nonfatal_err;     // Received Non-Fatal Uncorrectable Error MSG
input [MSG_TLP_WD-1:0]       radm_fatal_err;        // Received Fatal Uncorrectable Error MSG
input [(MSG_TLP_WD*16)-1:0]  radm_msg_req_id;       // Corresponding Requester ID of error MSG

// PF settings used by VFs
input   [31:0]  pf_cfg_aer_uncorr_mask; // uncorrectable mask register in, used to let VFs inherit PF settings
input   [31:0]  pf_cfg_aer_uncorr_svrity; // uncorrectable severity register in, used to let VFs inherit PF settings
input   [31:0]  pf_cfg_aer_corr_mask; // correctable mask register in, used to let VFs inherit PF settings
input           pf_multi_hdr_rec_en;           // Multiple Header Recording Enable register in, used to let VFs inherit PF settings
input           dbi_ro_wr_en;
input           cfg_pcie_surp_dn_rpt_cap;
input [NF-1:0]  cfg_ecrc_chk_en;

input           cdm_dpc_triggered;              // DPC has been triggered indication
input           cdm_dpc_trig_status;            // DPC trigger status from DPC Status Register
input [1:0]     cdm_dpc_trig_en;                // DPC trigger enable from DPC Control Register
input           int_dpc_sw_trigger;           // 1 clock cycle pulse when DPC is triggered by DPC Software Trigger bit in the DPC Control Register.
input           dpc_triggered_detect;           // 1 clock cycle pulse when DPC is triggered. 
input           int_dpc_err_cor_en;             // DPC ERR_COR Enable
input           cfg_p2p_err_rpt_ctrl;           // P2P_ERR_RPT_CTRL

input           cxl_rcrb_enable;                // Indicates that the CXL Link is up
input           msggen_cdm_send_f_err;          // Asserted for functions that will send a Fatal Message, and de-asserted for functions that will not send a message
input           msggen_cdm_send_nf_err;         // Asserted for functions that will send a Non-Fatal Message, and de-asserted for functions that will not send a message
// -------------- Outputs --------------
output          ecrc_chk_en;                    // ECRC checking enable
output          ecrc_gen_en;                    // ECRC generation enable
output  [31:0]  err_reg_data;                   // Read data back from core

output          cfg_send_f_err;                 // Send fatal uncorrectable error MSG upstream
output          cfg_send_nf_err;                // Send non-fatal uncorrectable error MSG upstream
output          cfg_send_cor_err;               // Send correctable error MSG upstream
output  [2:0]   cfg_func_spec_err;              // Indicate function specific error.  Bit 0 for cor, bit 1 for NF, bit 2 for F
output          cfg_aer_rc_err_int;             // RC Error Interrupt
output          cfg_aer_rc_err_msi;             // RC Error MSI
output  [4:0]   cfg_aer_int_msg_num;            // Advanced Error Interrupt Message Number (for MSI)
output          cfg_rprt_err_cor;               // System Error factor by Correctable Error
output          cfg_rprt_err_nf;                // System Error factor by Non-Fatal Error
output          cfg_rprt_err_f;                 // System Error factor by Fatal Error
output          cfg_cor_err_det;                // Correctable error detected
output          cfg_nf_err_det;                 // Non-fatal error detected
output          cfg_f_err_det;                  // Fatal error detected
output          cfg_unsupt_req_det;             // Non-advisory unsupported request error detected
// to cdm_cfg_reg
output          master_data_perr_det;
output          signaled_target_abort_det;
output          rcvd_target_abort_det;
output          rcvd_master_abort_det;
output          signaled_sys_err_det;
output          perr_det;

output          master_data_perr_det2;
output          signaled_target_abort_det2;
output          rcvd_target_abort_det2;
output          rcvd_master_abort_det2;
output          signaled_sys_err_det2;
output          perr_det2;
// PF settings exported to VFs
output  [31:0]  cfg_aer_uncorr_mask; // uncorrectable mask register out, used to export PF setting to VFs
output  [31:0]  cfg_aer_uncorr_svrity; // uncorrectable severity register out, used to export PF setting to VFs
output  [31:0]  cfg_aer_corr_mask; // correctable mask register out, used to export PF setting to VFs
output          multi_hdr_rec_en; // Multiple Header Recording Enable register out, used to export PF setting to VFs

output          int_dpc_triggered;
output  [1:0]   int_dpc_trig_reason;
output  [1:0]   int_dpc_trig_reason_extn;
output          cdm_aer_dpc_triggered;
output          cdm_core_in_dpc;
output  [15:0]  dpc_err_src_id;          // DPC Error Source ID.
output          cfg_uncor_internal_err_sts;
output          cfg_rcvr_overflow_err_sts;
output          cfg_fc_protocol_err_sts;
output          cfg_mlf_tlp_err_sts;
output          cfg_surprise_down_er_sts;
output          cfg_dl_protocol_err_sts;
output          cfg_ecrc_err_sts;
output          cfg_corrected_internal_err_sts;
output          cfg_replay_number_rollover_err_sts;
output          cfg_replay_timer_timeout_err_sts;
output          cfg_bad_dllp_err_sts;
output          cfg_bad_tlp_err_sts;
output          cfg_rcvr_err_sts;
output reg      advisory_nf_sts;
output wire     hdr_log_overflow_sts;     // Header Log Overflow Status ,found in Correctable Error Status Register


// Registers & Wires
reg     [31:0]  err_reg_data;                   // Read data back from core
//Leda is not failing when depths are equivalent for all funcitons
//
// LMD: Undriven net Range
// LJ: All nets are driven
// leda NTL_CON12 off
wire    [4:0]   fe_pointer_q;                   // first error ptr in header log queue
wire    [4:0]   fe_pointer;                     // first error ptr
// leda NTL_CON12 on
wire            fm_pointer_q;
wire    [HDR_LOG_SIZE_WD-1:0]   size_pointer_q;


wire            tlp_trans_egress_blk_sts;
wire            tlp_trans_egress_blk_mask;
wire            tlp_trans_egress_blk_svrity;
reg             tlp_trans_egress_blk_sts_temp;
reg             tlp_trans_egress_blk_mask_temp;
reg             tlp_trans_egress_blk_svrity_temp;
reg             dl_prot_err_sts;                // data link protocol error status
reg             surprise_down_err_sts;          // surprise down error status
reg             rx_tlp_poisoned_sts;            // poisoned TLP status
reg             rx_fc_prot_err_sts;             // flow control protocol error status
reg             cpl_timeout_sts;                // completion timeout status
reg             acs_violation_sts;
reg             cpl_tx_abort_sts;               // completer abort status
reg             unexp_tx_cpl_sts;               // unexpected completion status
reg             rx_overfl_sts;                  // receiver overflow TLP status
reg             rx_mlf_tlp_sts;                 // malformed TLP Status
reg             rx_ecrc_err_sts;                // ECRC Error Status
reg             tx_unsupt_req_err_sts;          // Unsupported Request Error Status
reg             internal_err_sts;
reg             tx_atomic_egress_blk_sts;       // AtomicOp Egress Blocked Error Status
reg             tx_atomic_egress_blk_mask;
reg             atomic_egress_blk_svrity;
reg             tlp_prfx_blocked_err_sts;       // TLP Prefix Blocked Error Status
reg             tlp_prfx_blocked_err_mask;
reg             tlp_prfx_blocked_err_svrity;
reg             psnd_tlp_egrss_blckd_err_sts;    // Poisoned TLP Egress Blocked Status
reg             psnd_tlp_egrss_blckd_err_mask;
reg             psnd_tlp_egrss_blckd_err_svrity;
wire            int_uncor_err_dpc_triggered;
reg             dl_prot_err_mask;
reg             surprise_down_err_mask;
reg             rx_tlp_poisoned_mask;
reg             rx_fc_prot_err_mask;
reg             cpl_timeout_mask;
reg             acs_violation_mask;
reg             cpl_tx_abort_mask;
reg             unexp_tx_cpl_mask;
reg             rx_overfl_mask;
reg             rx_mlf_tlp_mask;
reg             rx_ecrc_err_mask;
reg             tx_unsupt_req_err_mask;
reg             internal_err_mask;
reg             dl_prot_err_svrity;
reg             surprise_down_err_svrity;
reg             rx_tlp_poisoned_svrity;
reg             rx_fc_prot_err_svrity;
reg             cpl_timeout_svrity;
reg             acs_violation_svrity;
reg             rcvd_req_ca_err_svrity;
reg             unexp_tx_cpl_svrity;
reg             rx_overfl_svrity;
reg             rx_mlf_tlp_svrity;
reg             rx_ecrc_err_svrity;
reg             rcvd_req_ur_err_svrity;
reg             internal_err_svrity;
reg             rx_err_sts;
reg             bad_tlp_sts;
reg             bad_dllp_sts;
reg             replay_num_rlover_sts;
reg             replay_timeout_sts;
reg             corr_internal_err_sts;
reg             int_ecrc_gen_en;            // ECRC Generation Enable
reg             int_ecrc_chk_en;            // ECRC Check Enable
reg             int_ecrc_gen_cap;            // ECRC Generation Capable
reg             int_ecrc_chk_cap;            // ECRC Check Capable
wire            int_ecrc_chk_cap_d;          // ECRC Check Capable going out from BCM36_NHS, designating the signal as quasi-static
wire            fe_ptr_valid;
reg             rx_err_mask;
reg             bad_tlp_mask;
reg             bad_dllp_mask;
reg             replay_num_rlover_mask;
reg             replay_timeout_mask;
reg             advisory_nf_mask;
reg             hdr_log_overflow_mask; 
reg             corr_internal_err_mask;
wire            status_err_reg_clear;       // clear any bit of status err reg
wire [ERROR_TLP_WD-1:0]   rtlh_poisoned_err;
wire [ERROR_TLP_WD-1:0]   int_radm_rcvd_req_ur;
wire            int_advisory_nf_err;
reg             cfg_aer_rc_err_int;
reg             cfg_aer_rc_err_msi;
reg     [4:0]   cfg_aer_int_msg_num;

wire    [7:0]   ecfg_reg_0;
wire    [7:0]   ecfg_reg_1;
wire    [7:0]   ecfg_reg_2;
wire    [7:0]   ecfg_reg_3;
wire    [7:0]   ecfg_reg_4;
wire    [7:0]   ecfg_reg_5;
wire    [7:0]   ecfg_reg_6;
wire    [7:0]   ecfg_reg_7;
wire    [7:0]   ecfg_reg_8;
wire    [7:0]   ecfg_reg_9;
wire    [7:0]   ecfg_reg_10;
wire    [7:0]   ecfg_reg_11;
wire    [7:0]   ecfg_reg_12;
wire    [7:0]   ecfg_reg_13;
wire    [7:0]   ecfg_reg_14;
wire    [7:0]   ecfg_reg_15;
wire    [7:0]   ecfg_reg_16;
wire    [7:0]   ecfg_reg_17;
wire    [7:0]   ecfg_reg_18;
wire    [7:0]   ecfg_reg_19;
wire    [7:0]   ecfg_reg_20;
wire    [7:0]   ecfg_reg_21;
wire    [7:0]   ecfg_reg_22;
wire    [7:0]   ecfg_reg_23;
wire    [7:0]   ecfg_reg_24;
wire    [7:0]   ecfg_reg_25;
wire    [7:0]   ecfg_reg_26;
wire    [7:0]   ecfg_reg_27;

//Leda is not failing when depths are equivalent for all funcitons
//
// LMD: Undriven net Range
// LJ: All nets are driven
// leda NTL_CON12 off
wire    [7:0]   ecfg_reg_28;
wire    [7:0]   ecfg_reg_29;
wire    [7:0]   ecfg_reg_30;
wire    [7:0]   ecfg_reg_31;
wire    [7:0]   ecfg_reg_32;
wire    [7:0]   ecfg_reg_33;
wire    [7:0]   ecfg_reg_34;
wire    [7:0]   ecfg_reg_35;
wire    [7:0]   ecfg_reg_36;
wire    [7:0]   ecfg_reg_37;
wire    [7:0]   ecfg_reg_38;
wire    [7:0]   ecfg_reg_39;
wire    [7:0]   ecfg_reg_40;
wire    [7:0]   ecfg_reg_41;
wire    [7:0]   ecfg_reg_42;
wire    [7:0]   ecfg_reg_43;
// leda NTL_CON12 on

wire    [7:0]   ecfg_reg_44;
wire    [7:0]   ecfg_reg_45;
wire    [7:0]   ecfg_reg_46;
wire    [7:0]   ecfg_reg_47;
wire    [7:0]   ecfg_reg_48;
wire    [7:0]   ecfg_reg_49;
wire    [7:0]   ecfg_reg_50;
wire    [7:0]   ecfg_reg_51;
wire    [7:0]   ecfg_reg_52;
wire    [7:0]   ecfg_reg_53;
wire    [7:0]   ecfg_reg_54;
wire    [7:0]   ecfg_reg_55;
//TLP Prefix wires, registers are in the Q no matter what depth it is, if CX_TLP_PREFIX_ENABLE
wire     [7:0]   ecfg_reg_56, ecfg_reg_57, ecfg_reg_58, ecfg_reg_59;
wire     [7:0]   ecfg_reg_60, ecfg_reg_61, ecfg_reg_62, ecfg_reg_63;
wire     [7:0]   ecfg_reg_64, ecfg_reg_65, ecfg_reg_66, ecfg_reg_67;
wire     [7:0]   ecfg_reg_68, ecfg_reg_69, ecfg_reg_70, ecfg_reg_71;
wire     [7:0]   ecfg_reg_75, ecfg_reg_74, ecfg_reg_73, ecfg_reg_72;

wire [ERROR_TLP_WD-1:0] valid_ecrc_err;

wire            dbi_ro_wr_en;
wire            int_lbc_cdm_dbi;
assign int_lbc_cdm_dbi = lbc_cdm_dbi & dbi_ro_wr_en;
localparam FUNC_NUM_WD = `CX_LOGBASE2(FUNC_NUM);      // number of bits needed to represent the FUNC_NUM
// LMD: Undriven net Range
// LJ: All nets are driven
// leda NTL_CON12 off
wire    [NFUNC_WD-1:0]   function_number;
// leda NTL_CON12 on
assign function_number = {{(NFUNC_WD-FUNC_NUM_WD){1'b0}},FUNC_NUM};
wire [7:0] func_id_8b = {{(8-NFUNC_WD){1'b0}},function_number}; // drive at 0 most significant bits


wire  [15:0] int_req_id; // Requester ID for internally generated err MSG
// Requester ID = {Bus Number[7:0], Device Number[4:0], Function Number[2:0]}
assign int_req_id = {pm_bus_num, pm_dev_num, function_number[2:0]};       // internally generated err MSG

// Device Types
wire    end_device;
wire    rc_device;
wire    pcie_sw_up;
wire    pcie_sw_down;
wire    switch_device;
wire    pcie_br_up;
wire    pcie_br_down;
wire    bridge_device;
wire    sw_br_up;
wire    sw_br_down;
wire    upstream_port;
wire    downstream_port;
assign end_device       = (device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY);
assign rc_device        = (device_type == `PCIE_RC);
assign pcie_sw_up       = (device_type == `PCIE_SW_UP);
assign pcie_sw_down     = (device_type == `PCIE_SW_DOWN);
assign switch_device    = pcie_sw_up | pcie_sw_down;
assign pcie_br_up       = (device_type == `PCIE_PCIX);
assign pcie_br_down     = (device_type == `PCIX_PCIE);
assign bridge_device    = pcie_br_up | pcie_br_down;
assign sw_br_up         = pcie_br_up | pcie_sw_up;
assign sw_br_down       = pcie_br_down | pcie_sw_down;
assign upstream_port    = end_device | pcie_br_up | pcie_sw_up;
assign downstream_port  = rc_device | pcie_sw_down;


// For DFT best practice, downstream_port is registered to avoid direct
// connection from input to output.
reg          r_downstream_port;
always_ff @(posedge core_clk or negedge sticky_rst_n) begin : r_downstream_port_PROC
  if(!sticky_rst_n) begin
    r_downstream_port  <= #TP 1'b0;
  end else begin
    r_downstream_port  <= #TP downstream_port;
  end
end

wire         core_in_dpc = r_downstream_port ? cdm_dpc_trig_status : 0;                          // Core is in Downstream Port Containment mode
wire         core_in_dpc_plus = r_downstream_port ? (cdm_dpc_trig_status | cdm_dpc_triggered) : 0; // early indication that core is in Downstream Port Containment mode

// Non function specific errors: ignoring TLP errors as they can be back to back
//tlp_prfx_blocked_err
//radm_atomic_egress_blk
//internal_err
//radm_ecrc_err
//radm_mlf_tlp_err
//rtlh_overfl_err
//dl_prot_err
//rtlh_fc_prot_err
//surprise_down_err
reg internal_err_d;
reg rtlh_overfl_err_d;
reg dl_prot_err_d;
reg rtlh_fc_prot_err_d;

always@(posedge core_clk or negedge sticky_rst_n)
begin
  if(!sticky_rst_n) begin
     internal_err_d              <= #TP 0;
     rtlh_overfl_err_d           <= #TP 0;
     dl_prot_err_d               <= #TP 0;
     rtlh_fc_prot_err_d          <= #TP 0;
  end else begin
     internal_err_d              <= #TP internal_err;
     rtlh_overfl_err_d           <= #TP rtlh_overfl_err;
     dl_prot_err_d               <= #TP dl_prot_err;
     rtlh_fc_prot_err_d          <= #TP rtlh_fc_prot_err;
  end //if !sticky_rst_n
end // always


assign int_radm_rcvd_req_ur = core_in_dpc ? 0 : radm_rcvd_req_ur & ~rtlh_poisoned_err; // Separate poisoned requests from other received UR requests

wire [ERROR_TLP_WD-1:0] logged_error;          // Header Log Register updated due to TLP error

wire              int_tlp_trans_egress_blk             = core_in_dpc ? 0 : tlp_trans_egress_blk;
wire [ERROR_TLP_WD-1:0] int_radm_cpl_timeout_err       = core_in_dpc ? 0 : radm_cpl_timeout_err;
wire [ERROR_TLP_WD-1:0] int_radm_rcvd_req_ca           = core_in_dpc ? 0 : radm_rcvd_req_ca;
wire              int_radm_atomic_egress_blk     = core_in_dpc ? 0 : radm_atomic_egress_blk;
wire              int_tlp_prfx_blocked_err       = core_in_dpc ? 0 : tlp_prfx_blocked_err;
wire              int_psnd_tlp_egrss_blckd_err   = core_in_dpc ? 0 : psnd_tlp_egrss_blckd_err;
wire [ERROR_TLP_WD-1:0] int_radm_unexp_cpl_err         = core_in_dpc ? 0 : radm_unexp_cpl_err;
wire [ERROR_TLP_WD-1:0] int_radm_mlf_tlp_err           = core_in_dpc ? 0 : radm_mlf_tlp_err;
wire [ERROR_TLP_WD-1:0] int_radm_acs_violation         = core_in_dpc ? 0 : radm_acs_violation;

// =============================================================================
// Mux between base or advanced error reporting
// =============================================================================
// Device Status Register
// corr/non-fatal/fatal/UR error detect.  regardless mask/rpt_en.
// if AER, take from AER, otherwise take base.
wire            cfg_cor_err_det;
wire            cfg_nf_err_det;
wire            cfg_f_err_det;
wire            cfg_unsupt_req_det;
wire            base_cor_err_det;
wire            base_nf_err_det;
wire            base_f_err_det;
wire            adv_cor_err_det;
wire            adv_nf_err_det;
wire            adv_f_err_det;
wire    [ERROR_TLP_WD-1:0] int_err_advisory;

// Inputs to Device Status register (cdm_cfg_reg.v):
assign cfg_cor_err_det      = (AER_CAP_ENABLE ? adv_cor_err_det  : base_cor_err_det);
assign cfg_nf_err_det       = (AER_CAP_ENABLE ? adv_nf_err_det   : base_nf_err_det);
assign cfg_f_err_det        = (AER_CAP_ENABLE ? adv_f_err_det    : base_f_err_det);
assign cfg_unsupt_req_det   = core_in_dpc ? 1'b0 : (AER_CAP_ENABLE ? |(radm_rcvd_req_ur & ~rtlh_poisoned_err ) : |(radm_rcvd_req_ur & ~int_err_advisory & ~rtlh_poisoned_err));

// Sending MSG
// Corresponding error reporting enable control each type
// If SERR# enabled, send non-fatal & fatal errors
// If UR reporting is enabled, UR error message is sent regardless other settings
wire            cfg_send_cor_err;
wire            cfg_send_nf_err;
wire            cfg_send_f_err;
wire            send_adv_cor_err;
wire            send_adv_nf_err;
wire            send_adv_f_err;
wire            send_base_cor_err;
wire            send_base_nf_err;
wire            send_base_f_err;
wire    [2:0]   base_func_spec_err;
wire    [2:0]   adv_func_spec_err;


assign cfg_send_cor_err     = (AER_CAP_ENABLE ? send_adv_cor_err : send_base_cor_err);
assign cfg_send_nf_err      = (r_downstream_port && int_uncor_err_dpc_triggered) ? 1'b0 : (AER_CAP_ENABLE ? send_adv_nf_err  : send_base_nf_err);
assign cfg_send_f_err       = (r_downstream_port && int_uncor_err_dpc_triggered) ? 1'b0 : (AER_CAP_ENABLE ? send_adv_f_err   : send_base_f_err);
assign cfg_func_spec_err    = (AER_CAP_ENABLE ? adv_func_spec_err : base_func_spec_err);

wire xtlh_xmt_wreq_poisoned = |xadm_xmt_pci_errors.wreq_poisoned[FUNC_NUM];
wire xtlh_xmt_cpl_poisoned = |xadm_xmt_pci_errors.cpl_poisoned[FUNC_NUM];
wire xtlh_xmt_cpl_ca = |xadm_xmt_pci_errors.cpl_ca[FUNC_NUM];
wire xtlh_xmt_cpl_ur = |xadm_xmt_pci_errors.cpl_ur[FUNC_NUM];

// =============================================================================
// Base error reporting
// =============================================================================

// Only look at poisoned completion and poisoned write request
// Ignore poisoned read request
wire [ERROR_TLP_WD-1:0]   rcvd_poisoned_tlp;
assign rcvd_poisoned_tlp = radm_rcvd_cpl_poisoned | radm_rcvd_wreq_poisoned;

wire xmt_poisoned_tlp;
assign xmt_poisoned_tlp = xtlh_xmt_cpl_poisoned | xtlh_xmt_wreq_poisoned;

// ------- \\
// PRIMARY \\
// ------- \\

// 7.5.1.2:
// EP: set when receiving a poisoned completion or transmitting a poisoned
// request
// 7.5.1.2 and 6.2.8.1(ignoring 6.2.8.1 typo in 2.1(errata doc. is correct))
// RC/SWup/SWdn: receiving a completion going downstream or transmitting
// a request upstream
// 7.5.1.7:
// RC/SWdn: Primary side status applies to internal logic (application),
// secondary side = wire.
// SWup: Primary side status applies to wire, secondary side = internal logic
// (application).
// Wire signals radm_rcvd_cpl_poisoned and radm_rcvd_wreq_poisoned
// App signals xtlh_xmt_cpl_poisoned and xtlh_xmt_wreq_poisoned
// ep : radm_rcvd_cpl_poisoned || xtlh_xmt_wreq_poisoned
// SW up: radm_rcvd_cpl_poisoned || xtlh_xmt_wreq_poisoned
// RC/SW dn: xtlh_xmt_cpl_poisoned || radm_rcvd_wreq_poisoned
// depends only on upstream_port
wire master_data_perr;
assign master_data_perr  = upstream_port ?
    (|radm_rcvd_cpl_poisoned || xtlh_xmt_wreq_poisoned):
    (xtlh_xmt_cpl_poisoned || (|radm_rcvd_wreq_poisoned));

// for Signaled Target Abort of primary
// When primary side completes a request using CA. Actually _sends_ CPL w/ CA
// EP/BRup: When core sends a CPL w/ CA.
// RC & SW/BRdn & SWup: Application tell us when there was a request from above that got CAed.
wire xmt_cpl_ca_primary;
assign xmt_cpl_ca_primary = (end_device | pcie_br_up) ?
    xtlh_xmt_cpl_ca : xal_xmt_cpl_ca;

// for Received Target Abort of primary
// When primary side initiate a request and got a CPL w/ CA back
// EP/BRup: Core receives CPL w/ CA.
// SW/BRdn: Application tell us when CPL w/ CA is for us.
// RC & SW: Hardwire to 0, primary side can't initiate request
wire rcvd_cpl_ca_primary;
assign rcvd_cpl_ca_primary = (rc_device | pcie_sw_up) ? 1'b0 :
                             (end_device ) ? |radm_rcvd_cpl_ca :
                             (pcie_br_up) ? xal_set_trgt_abort_primary
                                                    : xal_rcvd_cpl_ca;

// for Received Master Abort of primary
// When primary side initiate a request and got a CPL w/ UR back
// EP/BRup: Core receives CPL w/ UR
// SW/BRdn: Application tell us when CPL w/ UR is for us.
// RC & SW: Hardwire to 0, primary side can't initiate request
wire rcvd_cpl_ur_primary;
assign rcvd_cpl_ur_primary = (rc_device | pcie_sw_up) ? 1'b0 :
                             (end_device ) ? |radm_rcvd_cpl_ur :
                             (pcie_br_up) ? xal_set_mstr_abort_primary
                                                    : xal_rcvd_cpl_ur;

// for Signaled System Error of primary
// Sends or receives ERR_FATAL or ERR_NONFATAL message (SERR# = 1)
// EP & SW/: core sends ERR_FATAL or ERR_NONFATAL message (can't receive since err MSG travels upstream)
// RC & SW/BRdn: core sends or receives ERR_FATAL or ERR_NONFATAL message
// BRup: Core receives xal_serr and error forwarding is enabled.
wire xmt_serr_primary;
assign xmt_serr_primary = ((msggen_cdm_send_nf_err | msggen_cdm_send_f_err) & cfg_reg_serren) |
                          ((!upstream_port & (|radm_fatal_err | (|radm_nonfatal_err)) || pcie_br_up && xal_serr) & cfg_br_ctrl_serren & cfg_reg_serren);

// for Detected Parity Error
// 7.5.1.2: set when primary side receives a poisoned TLP
// EP, SW/BRup: Received poisoned TLP
// RC, SW/BRdn: Transmitted poisoned TLP
// Note that for a SWup this bit is set for both type0 (locally terminated) and type1 (forwarded) poisoned TLPs,
// the difference is in the filter which generates UR in the first case, SU in the second.
wire rcvd_poisoned_tlp_primary = upstream_port ? |rcvd_poisoned_tlp : xmt_poisoned_tlp;

// Status Register:
assign master_data_perr_det     = (master_data_perr) && cfg_reg_perren;
assign signaled_target_abort_det= xmt_cpl_ca_primary;
assign rcvd_target_abort_det    = rcvd_cpl_ca_primary;
assign rcvd_master_abort_det    = rcvd_cpl_ur_primary;
assign signaled_sys_err_det     = xmt_serr_primary;
assign perr_det                 = rcvd_poisoned_tlp_primary || bridge_device && |valid_ecrc_err;

// --------- \\
// SECONDARY \\
// --------- \\

// 7.5.1.2 and 6.2.8.1(ignoring 6.2.8.1 typo in 2.1(2.1 errata doc. is
// correct))
// RC/SWup/SWdn: receiving a completion going upstream or transmitting
// a request downstream
// 7.5.1.7:
// RC/SWdn: Secondary side status applies to wire, primary side = internal
// (application).
// SWup: Secondary side status applies to internal logic (application),
// primary side = wire.
// Wire signals radm_rcvd_cpl_poisoned and radm_rcvd_wreq_poisoned
// App signals xtlh_xmt_cpl_poisoned and xtlh_xmt_wreq_poisoned
// SW up: radm_rcvd_wreq_poisoned or xtlh_xmt_cpl_poisoned
// RC/SW dn: xtlh_mxt_wreq_poisoned or radm_rcvd_cpl_poisoned
// depends only on upstream_port
wire master_data_perr2;
assign master_data_perr2  = upstream_port ?
    (|radm_rcvd_wreq_poisoned || xtlh_xmt_cpl_poisoned ||
    pcie_br_up && xal_perr):
    (|radm_rcvd_cpl_poisoned || xtlh_xmt_wreq_poisoned);

// for Signaled Target Abort of secondary bus
// When secondary side completes a request using CA. Actually _sends_ CPL w/ CA
// Downstream port: Set when LBC sends a CPL w/ CA.
// Upstream port: Application tell us when we sent the CPL w/ CA, not just fwding.
wire xmt_cpl_ca_secondary;
assign xmt_cpl_ca_secondary = !upstream_port ? ( lbc_xmt_cpl_ca | (|int_radm_acs_violation) ) : xal_xmt_cpl_ca;

// for Received Target Abort of secondary bus
// When secondary side initiate a request and got a CPL w/ CA back
// Downstream port:
//      SW: Hardwire to 0 since no request is initiated from secondary side.
//      RC: Set when a CA completion is received from the wire unless P2P
//      support is enabled
// Upstream port:
//      Application tell us when we sent the request, not just fwding the CPL
//      w/ CA.
wire rcvd_cpl_ca_secondary;
assign rcvd_cpl_ca_secondary = upstream_port & xal_rcvd_cpl_ca
    || rc_device && |radm_rcvd_cpl_ca
    ;

// for Received Master Abort of secondary bus
// When secondary side initiate a request and got a CPL w/ UR back
// Downstream port:
//      SW: Hardwire to 0 since no request is initiated from secondary side.
//      RC: Set when a UR completion is received from the wire unless P2P
//      support is enabled
// Upstream port:
//      Application tell us when we sent the request, not just fwding the CPL
//      w/ UR.
wire rcvd_cpl_ur_secondary;
assign rcvd_cpl_ur_secondary = upstream_port & xal_rcvd_cpl_ur
    || rc_device && |radm_rcvd_cpl_ur
    ;

// for Signaled System Error of secondary bus
// PCIe 1.1: Set when secondary side receives ERR_FATAL or ERR_NONFATAL message
// Downstream port: Receives fatal or nonfatal message
// Upstream port: Hardwire to 0 because error MSG travels upstream only
// Bridge port: Set on assertion of xal_serr.
wire rcvd_serr_secondary;
assign rcvd_serr_secondary = !upstream_port & (|radm_fatal_err | (|radm_nonfatal_err)) || pcie_br_up && xal_serr;

// for Detected Parity Error
// Secondary side receives a poisoned TLP
// Downstream port: Receives poisoned TLP
// Upstream port: Transmit poisoned TLP
// 6.2.8.1: Set on receiving side when a poisoned TLP forwarded from Secondary to Primary
wire rcvd_poisoned_tlp_secondary = !upstream_port ? |rcvd_poisoned_tlp : xmt_poisoned_tlp;

// Secondary Status Register:
assign master_data_perr_det2        = (end_device) ? 1'b0 : master_data_perr2 && cfg_br_ctrl_perren;
assign signaled_target_abort_det2   = (end_device) ? 1'b0 : xmt_cpl_ca_secondary;
assign rcvd_target_abort_det2       = (end_device) ? 1'b0 : rcvd_cpl_ca_secondary;
assign rcvd_master_abort_det2       = (end_device) ? 1'b0 : rcvd_cpl_ur_secondary;
assign signaled_sys_err_det2        = (end_device) ? 1'b0 : rcvd_serr_secondary;
assign perr_det2                    = (end_device) ? 1'b0 :
   (pcie_br_up) ? xal_pci_addr_perr :
    rcvd_poisoned_tlp_secondary;

// ---------------------- \\
// Device Status Register \\
// ---------------------- \\
// corr/non-fatal/fatal/UR error detect.  regardless mask/rpt_en.

// Differentiate between Non-posted and Posted incoming CA/UR request.
wire    [4:0]           radm_hdr_pkt_type[ERROR_TLP_WD-1:0];
wire    [1:0]           radm_hdr_pkt_fmt[ERROR_TLP_WD-1:0];
wire    [ERROR_TLP_WD-1:0]    np_req;
wire    [ERROR_TLP_WD-1:0]    radm_rcvd_req_ur_np;
wire    [ERROR_TLP_WD-1:0]    radm_rcvd_req_ca_np;
wire    [ERROR_TLP_WD-1:0]    radm_rcvd_acs_err_np;
wire    [TLP_SIZE-1:0]  int_radm_hdr_log[ERROR_TLP_WD-1:0];
wire    [PRFX_SIZE-1:0]         int_radm_prfx_log[ERROR_TLP_WD-1:0];   //internal TLP Prefix Log values



genvar i;
generate
for(i=0; i<ERROR_TLP_WD; i=i+1) begin : gen_device_status
  if (i>0) begin : gen_int_hdrlog_zero
    assign int_radm_hdr_log[i]  = {TLP_SIZE{1'b0}};
  end else begin : gen_int_hdrlog
    assign int_radm_hdr_log[i]  = radm_hdr_log[TLP_SIZE*i +: TLP_SIZE];
  end

assign radm_rcvd_req_ur_np[i]  = radm_rcvd_req_ur[i]       & radm_hdr_log_np_req;
assign radm_rcvd_req_ca_np[i]  = int_radm_rcvd_req_ca[i]   & radm_hdr_log_np_req;
assign radm_rcvd_acs_err_np[i] = int_radm_acs_violation[i] & radm_hdr_log_np_req;

// If it's Non-Posted UR/CA error, then it's an advisory error
// Need to "OR" it in here since radm_filter doesn't tell us
assign int_err_advisory[i] = cdm_err_detect ? cdm_err_advisory[i]                                                      // Application Detected Error
                                            : cdm_err_advisory[i] | radm_rcvd_req_ca_np[i] | (radm_rcvd_req_ur_np[i] & (!rcvd_poisoned_tlp[i]))
                      | radm_rcvd_acs_err_np[i]
                      | (valid_ecrc_err[i] & radm_hdr_log_np_req )
                      ; // Core Detected Error
end // gen_device_status
endgenerate

// If it's advisory error, don't send any error message.
// This signal is not actually used.
wire base_advisory_nf_err;
assign base_advisory_nf_err = |((int_err_advisory & (rtlh_poisoned_err | int_radm_cpl_timeout_err | valid_ecrc_err | int_radm_rcvd_req_ur | int_radm_rcvd_req_ca)
                     | int_radm_acs_violation
                               ) | int_radm_unexp_cpl_err);

// Error status signals
assign base_cor_err_det = ((rmlh_rcvd_err | rdlh_bad_tlp_err | rdlh_bad_dllp_err) & ~core_in_dpc) |
                          xdlh_replay_timeout_err | xdlh_replay_num_rlover_err
                              | corr_internal_err
                          ;

assign base_nf_err_det  = |((~int_err_advisory & rcvd_poisoned_tlp)    |
                            (~int_err_advisory & int_radm_cpl_timeout_err) |
                            (~int_err_advisory & valid_ecrc_err)       |
                            (~int_err_advisory & int_radm_rcvd_req_ur) |
                            (~int_err_advisory & int_radm_rcvd_req_ca)
               |(~int_err_advisory & int_radm_acs_violation)
                            );
//                            int_radm_unexp_cpl_err |            // advisory error

assign base_f_err_det   = dl_prot_err | surprise_down_err |
                          rtlh_overfl_err | rtlh_fc_prot_err | (|int_radm_mlf_tlp_err)
                              | (internal_err & ~internal_err_d)
                          ;
// Error message
assign send_base_cor_err = (base_cor_err_det | (dpc_triggered_detect & int_dpc_err_cor_en)) & cfg_cor_err_rpt_en;
assign send_base_nf_err  = |((~int_err_advisory & rcvd_poisoned_tlp) |
                             (~int_err_advisory & int_radm_cpl_timeout_err) |
                             (~int_err_advisory & valid_ecrc_err) |
                             (~int_err_advisory & int_radm_rcvd_req_ur & {ERROR_TLP_WD{(cfg_unsupt_req_rpt_en | cfg_reg_serren)}}) |
                             (~int_err_advisory & int_radm_rcvd_req_ca)
                 | (~int_err_advisory & int_radm_acs_violation)
               ) &   (cfg_nf_err_rpt_en | cfg_reg_serren);
assign send_base_f_err   = base_f_err_det & (cfg_f_err_rpt_en | cfg_reg_serren);

// Indicate whether an error is function specific or not
// Correctable errors are always non function specific
assign base_func_spec_err[0] = 1'b0;
// Non-fatal errors are function specific if it's NON-advisory poisoned, CPL timeout error or CA error
// UR error is handled by the radm_filter.  If it's non function specific, then it would "broadcast"
// the error to all function.  If it's function specific, then it would only signaled one function.
// Therefore, we can always treat it as non function specific.
assign base_func_spec_err[1] = |(~int_err_advisory & (rcvd_poisoned_tlp | int_radm_cpl_timeout_err | int_radm_rcvd_req_ca
                   | int_radm_acs_violation
                               ));
// Fatal errors are always non function specific
assign base_func_spec_err[2] = 1'b0;

// =============================================================================
// Advanced Error Reporting
// =============================================================================

// -----------------------------------------------------------------------------
// The following errors are non function specific errors
// -----------------------------------------------------------------------------
// Correctable
wire int_rmlh_rcvd_err              = rmlh_rcvd_err & ~core_in_dpc;
wire int_rdlh_bad_tlp_err           = rdlh_bad_tlp_err & ~core_in_dpc;
wire int_rdlh_bad_dllp_err          = rdlh_bad_dllp_err & ~core_in_dpc;
wire int_xdlh_replay_timeout_err    = xdlh_replay_timeout_err;
wire int_xdlh_replay_num_rlover_err = xdlh_replay_num_rlover_err;
wire int_corr_internal_err          = corr_internal_err;
// Uncorrectable
wire int_dl_prot_err                = (dl_prot_err & ~dl_prot_err_d) & ~core_in_dpc;
wire int_surprise_down_err          = (surprise_down_err) & ~core_in_dpc;
wire int_rtlh_overfl_err            = (rtlh_overfl_err & ~rtlh_overfl_err_d) & ~core_in_dpc;
wire int_rtlh_fc_prot_err           = (rtlh_fc_prot_err & ~rtlh_fc_prot_err_d) & ~core_in_dpc;
wire int_internal_err               = (internal_err & ~internal_err_d) & ~core_in_dpc;
wire                              hdr_log_overflow_det;     //to send an Error Status message
wire  int_hdr_log_overflow_det; 
assign int_hdr_log_overflow_det = hdr_log_overflow_det | app_hdr_log_overflow_det ;
// only when ecrc_check enable is set, the ecrc_error will be reported,
assign valid_ecrc_err               = (!core_in_dpc && |cfg_ecrc_chk_en) ? | radm_ecrc_err : 0 ;
// -----------------------------------------------------------------------------
// Indicate whether an error is function specific or not
// -----------------------------------------------------------------------------
// bit 0: Correctable errors, bit 1: Non-Fatal errors, bit 2: Fatal errors
// Correctable errors are non function specific except when the following is true
assign adv_func_spec_err[0] = (int_err_advisory[0] & (
                               (rtlh_poisoned_err[0]    & !rx_tlp_poisoned_mask   & !rx_tlp_poisoned_svrity ) |
                               (int_radm_cpl_timeout_err[0] & !cpl_timeout_mask       & !cpl_timeout_svrity     ) |
                               (int_radm_rcvd_req_ca[0] & !cpl_tx_abort_mask      & !rcvd_req_ca_err_svrity )
                  |(int_radm_acs_violation[0]   & !acs_violation_mask     & !acs_violation_svrity   )
                               ))
                               ;

assign adv_func_spec_err[1] = (!int_err_advisory[0] & (
                              (rtlh_poisoned_err[0]    & !rx_tlp_poisoned_mask   & !rx_tlp_poisoned_svrity ) |
                              (int_radm_cpl_timeout_err[0] & !cpl_timeout_mask       & !cpl_timeout_svrity     ) |
                              (int_radm_rcvd_req_ca[0]     & !cpl_tx_abort_mask      & !rcvd_req_ca_err_svrity )
                  |(int_radm_acs_violation[0]  & !acs_violation_mask     & !acs_violation_svrity   )

                ))
                              ;

assign adv_func_spec_err[2] = (rtlh_poisoned_err[0]    & !rx_tlp_poisoned_mask   & rx_tlp_poisoned_svrity ) |
                              (int_radm_cpl_timeout_err[0] & !cpl_timeout_mask       & cpl_timeout_svrity     ) |
                              (int_radm_rcvd_req_ca[0]     & !cpl_tx_abort_mask      & rcvd_req_ca_err_svrity )
                  |(int_radm_acs_violation[0]  & !acs_violation_mask     & acs_violation_svrity   )

                
                              ;

// -----------------------------------------------------------------------------
// Advisory Non-Fatal errors: (PCIe 1.1 sec 6.2.3.2.4)
// 1. Completer sending a completion with UR/CA status
// 2. Intermediate receiver
// 3. Ultimate PCIe receiver of a poisoned TLP
// 4. Requester with completion timeout
// 5. Receiver with unexpected completion
// 6. AtomicOp Request and Egress Blocked
//
// Unexpected CPL is always advisory.
// AtomicOp Egress Blocked are always advisory.
// The others can be advisory or
// non advisory
assign int_advisory_nf_err = (int_err_advisory[0] &
                              ((rtlh_poisoned_err[0]    & !rx_tlp_poisoned_svrity ) |
                               (valid_ecrc_err[0]       & !rx_ecrc_err_svrity     ) |
                               (int_radm_cpl_timeout_err[0] & !cpl_timeout_svrity     ) |
                               (int_radm_rcvd_req_ur[0] & !rcvd_req_ur_err_svrity ) |
                               (int_radm_acs_violation[0]   & !acs_violation_svrity   ) | 
                               (int_tlp_prfx_blocked_err & !tlp_prfx_blocked_err_svrity) |
                               (int_psnd_tlp_egrss_blckd_err & !psnd_tlp_egrss_blckd_err_svrity) |
                               (int_radm_rcvd_req_ca[0]     & !rcvd_req_ca_err_svrity ))) |
                             (int_tlp_trans_egress_blk       & !tlp_trans_egress_blk_svrity_temp) |
                             (int_radm_atomic_egress_blk    & !atomic_egress_blk_svrity) |
                             (int_radm_unexp_cpl_err[0]     & !unexp_tx_cpl_svrity    );

assign rtlh_poisoned_err = core_in_dpc ? 0 : (radm_rcvd_wreq_poisoned | radm_rcvd_cpl_poisoned);

// to err_gen - send MSG TLP
assign send_adv_cor_err  = (int_hdr_log_overflow_det        & !hdr_log_overflow_mask     & cfg_cor_err_rpt_en) |
                           (int_rmlh_rcvd_err               & !rx_err_mask               & cfg_cor_err_rpt_en) |
                           (int_rdlh_bad_tlp_err            & !bad_tlp_mask              & cfg_cor_err_rpt_en) |
                           (int_rdlh_bad_dllp_err           & !bad_dllp_mask             & cfg_cor_err_rpt_en) |
                           (int_xdlh_replay_num_rlover_err  & !replay_num_rlover_mask    & cfg_cor_err_rpt_en) |
                           (int_xdlh_replay_timeout_err     & !replay_timeout_mask       & cfg_cor_err_rpt_en) |
                           (int_corr_internal_err           & !corr_internal_err_mask    & cfg_cor_err_rpt_en) |
                           (!advisory_nf_mask &
                            ((int_err_advisory[0] &
                              ((rtlh_poisoned_err[0]           & !rx_tlp_poisoned_svrity                        ) |
                               (valid_ecrc_err[0]              & !rx_ecrc_err_svrity                            ) |
                               (int_radm_cpl_timeout_err[0]        & !cpl_timeout_svrity                            ) |
                               (int_radm_rcvd_req_ca[0]            & !rcvd_req_ca_err_svrity                        ) |
                               (int_radm_acs_violation[0]          & !acs_violation_svrity                          ) |
                             (int_tlp_prfx_blocked_err             & !tlp_prfx_blocked_err_svrity                   ) |
                             (int_psnd_tlp_egrss_blckd_err & !psnd_tlp_egrss_blckd_err_svrity & cfg_cor_err_rpt_en) |
                               (int_radm_rcvd_req_ur[0]        & !rcvd_req_ur_err_svrity    & cfg_unsupt_req_rpt_en)) & cfg_cor_err_rpt_en) |
                              (int_tlp_trans_egress_blk            & !tlp_trans_egress_blk_svrity_temp      & cfg_cor_err_rpt_en) |
                             (int_radm_atomic_egress_blk           & !atomic_egress_blk_svrity  & cfg_cor_err_rpt_en) |
                             (int_radm_unexp_cpl_err[0]            & !unexp_tx_cpl_svrity       & cfg_cor_err_rpt_en)))
                           | (dpc_triggered_detect & int_dpc_err_cor_en & cfg_cor_err_rpt_en)         // ERR_COR sent when DPC is triggered.
                             ;
// Send ERR_NONFATAL for non-advisory errors
assign send_adv_nf_err   = (int_dl_prot_err             & !dl_prot_err_mask       & !dl_prot_err_svrity    & (cfg_nf_err_rpt_en | cfg_reg_serren)) |
                           (int_surprise_down_err       & !surprise_down_err_mask & !surprise_down_err_svrity & (cfg_nf_err_rpt_en | cfg_reg_serren)) |
                           (int_rtlh_overfl_err         & !rx_overfl_mask         & !rx_overfl_svrity      & (cfg_nf_err_rpt_en | cfg_reg_serren)) |
                           (int_rtlh_fc_prot_err        & !rx_fc_prot_err_mask    & !rx_fc_prot_err_svrity & (cfg_nf_err_rpt_en | cfg_reg_serren)) |
                           (int_internal_err            & !internal_err_mask      & !internal_err_svrity   & (cfg_nf_err_rpt_en | cfg_reg_serren)) |
                           (int_radm_mlf_tlp_err[0]            & !rx_mlf_tlp_mask        & !rx_mlf_tlp_svrity     & (cfg_nf_err_rpt_en | cfg_reg_serren)) |
// Unexpected CPL is always treated as an advisory error
//                           (int_radm_unexp_cpl_err          & !unexp_tx_cpl_mask      & !unexp_tx_cpl_svrity    ) |
// Poisoned, ECRC, CA/UR and CPL Timeout error *could* be advisory errors.  Only used here if they're not.
                           (int_radm_rcvd_req_ur[0]        & !tx_unsupt_req_err_mask & !rcvd_req_ur_err_svrity & !int_err_advisory[0] & ((cfg_nf_err_rpt_en & cfg_unsupt_req_rpt_en) | cfg_reg_serren)) |
                           (int_radm_rcvd_req_ca[0]            & !cpl_tx_abort_mask      & !rcvd_req_ca_err_svrity & !int_err_advisory[0] & (cfg_nf_err_rpt_en | cfg_reg_serren)) |
                           (rtlh_poisoned_err[0]           & !rx_tlp_poisoned_mask   & !rx_tlp_poisoned_svrity & !int_err_advisory[0] & (cfg_nf_err_rpt_en | cfg_reg_serren)) |
                           (valid_ecrc_err[0]              & !rx_ecrc_err_mask       & !rx_ecrc_err_svrity     & !int_err_advisory[0] & (cfg_nf_err_rpt_en | cfg_reg_serren)) |
                           (int_radm_cpl_timeout_err[0]        & !cpl_timeout_mask       & !cpl_timeout_svrity     & !int_err_advisory[0] & (cfg_nf_err_rpt_en | cfg_reg_serren))
              |(int_radm_acs_violation[0]          & !acs_violation_mask     & !acs_violation_svrity   & !int_err_advisory[0] & (cfg_nf_err_rpt_en | cfg_reg_serren))

                           |
                            (int_tlp_prfx_blocked_err  & !tlp_prfx_blocked_err_mask & !tlp_prfx_blocked_err_svrity   & !int_err_advisory[0] & (cfg_nf_err_rpt_en | cfg_reg_serren))
                           |
                           (int_psnd_tlp_egrss_blckd_err & !psnd_tlp_egrss_blckd_err_mask & !psnd_tlp_egrss_blckd_err_svrity & !int_err_advisory[0] & (cfg_nf_err_rpt_en | cfg_reg_serren))
               
                           ;

assign send_adv_f_err    = (int_dl_prot_err             & !dl_prot_err_mask          & dl_prot_err_svrity       & (cfg_f_err_rpt_en | cfg_reg_serren) ) |
                           (int_surprise_down_err       & !surprise_down_err_mask    & surprise_down_err_svrity & (cfg_f_err_rpt_en | cfg_reg_serren) ) |
                           (int_rtlh_overfl_err         & !rx_overfl_mask            & rx_overfl_svrity         & (cfg_f_err_rpt_en | cfg_reg_serren) ) |
                           (int_rtlh_fc_prot_err        & !rx_fc_prot_err_mask       & rx_fc_prot_err_svrity    & (cfg_f_err_rpt_en | cfg_reg_serren) ) |
                           (int_internal_err            & !internal_err_mask         & internal_err_svrity      & (cfg_f_err_rpt_en | cfg_reg_serren)) |
                           (int_radm_mlf_tlp_err[0]            & !rx_mlf_tlp_mask           & rx_mlf_tlp_svrity        & (cfg_f_err_rpt_en | cfg_reg_serren) ) |
                           (rtlh_poisoned_err[0]           & !rx_tlp_poisoned_mask      & rx_tlp_poisoned_svrity   & (cfg_f_err_rpt_en | cfg_reg_serren) ) |
                           (valid_ecrc_err[0]              & !rx_ecrc_err_mask          & rx_ecrc_err_svrity       & (cfg_f_err_rpt_en | cfg_reg_serren) ) |
                           (int_radm_rcvd_req_ur[0]        & !tx_unsupt_req_err_mask    & rcvd_req_ur_err_svrity   & ((cfg_f_err_rpt_en & cfg_unsupt_req_rpt_en) | cfg_reg_serren)) |
                           (int_radm_cpl_timeout_err[0]        & !cpl_timeout_mask          & cpl_timeout_svrity       & (cfg_f_err_rpt_en | cfg_reg_serren) ) |
                           (int_radm_rcvd_req_ca[0]            & !cpl_tx_abort_mask         & rcvd_req_ca_err_svrity   & (cfg_f_err_rpt_en | cfg_reg_serren) ) |
                           (int_tlp_trans_egress_blk           & !tlp_trans_egress_blk_mask_temp      & tlp_trans_egress_blk_svrity_temp   & (cfg_f_err_rpt_en | cfg_reg_serren) ) |
                           (int_radm_atomic_egress_blk         & !tx_atomic_egress_blk_mask & atomic_egress_blk_svrity & (cfg_f_err_rpt_en | cfg_reg_serren) ) |
                           (int_tlp_prfx_blocked_err        & !tlp_prfx_blocked_err_mask & tlp_prfx_blocked_err_svrity & (cfg_f_err_rpt_en | cfg_reg_serren) ) |
                           (int_psnd_tlp_egrss_blckd_err       & !psnd_tlp_egrss_blckd_err_mask & psnd_tlp_egrss_blckd_err_svrity & (cfg_f_err_rpt_en | cfg_reg_serren) ) |
                           (int_radm_unexp_cpl_err[0]          & !unexp_tx_cpl_mask      & unexp_tx_cpl_svrity    & (cfg_f_err_rpt_en | cfg_reg_serren) )
              |(int_radm_acs_violation[0]          & !acs_violation_mask     & acs_violation_svrity   & (cfg_f_err_rpt_en | cfg_reg_serren) )

                           ;


// AER detects an error - goes to Device Status register
assign adv_cor_err_det  =  int_rmlh_rcvd_err              |
                           int_rdlh_bad_tlp_err           |
                           int_rdlh_bad_dllp_err          |
                           int_xdlh_replay_num_rlover_err |
                           int_xdlh_replay_timeout_err    |
                           int_corr_internal_err          |
                           int_hdr_log_overflow_det       |
                           // Advisory errors:
                           (valid_ecrc_err[0]                & !rx_ecrc_err_svrity     & int_err_advisory[0]) |
                           (rtlh_poisoned_err[0]             & !rx_tlp_poisoned_svrity & int_err_advisory[0]) |
                           (int_radm_cpl_timeout_err[0]          & !cpl_timeout_svrity     & int_err_advisory[0]) |
                           (int_radm_rcvd_req_ur[0]          & !rcvd_req_ur_err_svrity & int_err_advisory[0]) |
                           (int_radm_rcvd_req_ca[0]              & !rcvd_req_ca_err_svrity & int_err_advisory[0]) |
                           (int_tlp_prfx_blocked_err          & !tlp_prfx_blocked_err_svrity & int_err_advisory[0] ) |
                           (int_psnd_tlp_egrss_blckd_err         & !psnd_tlp_egrss_blckd_err_svrity & int_err_advisory[0] ) |
                           (int_tlp_trans_egress_blk             & !tlp_trans_egress_blk_svrity_temp  ) |
                           (int_radm_atomic_egress_blk           & !atomic_egress_blk_svrity) |
                           (int_radm_unexp_cpl_err[0]            & !unexp_tx_cpl_svrity    )
              |(int_radm_acs_violation[0]            & !acs_violation_svrity   & int_err_advisory[0])
                           ;

// Set non fatal uncorrectable error status bit in Device status register
// Errors are logged in this register regardless of whether error reporting is enabled or not in the Device Control register
assign adv_nf_err_det    = (int_dl_prot_err               & !dl_prot_err_svrity     ) |
                           (int_surprise_down_err         & !surprise_down_err_svrity) |
                           (int_rtlh_overfl_err           & !rx_overfl_svrity       ) |
                           (int_rtlh_fc_prot_err          & !rx_fc_prot_err_svrity  ) |
                           (int_internal_err              & !internal_err_svrity    ) |
                           (int_radm_mlf_tlp_err[0]              & !rx_mlf_tlp_svrity      ) |
                           (valid_ecrc_err[0]                & !rx_ecrc_err_svrity     & !int_err_advisory[0]) |
                           (rtlh_poisoned_err[0]             & !rx_tlp_poisoned_svrity & !int_err_advisory[0]) |
                           (int_radm_cpl_timeout_err[0]          & !cpl_timeout_svrity     & !int_err_advisory[0]) |
                           (int_radm_rcvd_req_ur[0]          & !rcvd_req_ur_err_svrity & !int_err_advisory[0]) |
                           (int_radm_rcvd_req_ca[0]              & !rcvd_req_ca_err_svrity & !int_err_advisory[0])
                           |
                           (int_radm_acs_violation[0]            & !acs_violation_svrity   & !int_err_advisory[0])
                           // Set non fatal uncorrectable error status bit in Device status register
                           | 
                            (int_tlp_prfx_blocked_err          & !tlp_prfx_blocked_err_svrity & !int_err_advisory[0] ) 
                           |
                           (int_psnd_tlp_egrss_blckd_err & !psnd_tlp_egrss_blckd_err_svrity & !int_err_advisory[0])
                           ;


assign adv_f_err_det     = (int_dl_prot_err               &  dl_prot_err_svrity       ) |
                           (int_surprise_down_err         &  surprise_down_err_svrity ) |
                           (int_rtlh_overfl_err           &  rx_overfl_svrity         ) |
                           (int_rtlh_fc_prot_err          &  rx_fc_prot_err_svrity    ) |
                           (int_internal_err              &  internal_err_svrity      ) |
                           (int_radm_mlf_tlp_err[0]           &  rx_mlf_tlp_svrity        ) |
                           (rtlh_poisoned_err[0]          &  rx_tlp_poisoned_svrity   ) |
                           (valid_ecrc_err[0]             &  rx_ecrc_err_svrity       ) |
                           (int_radm_rcvd_req_ur[0]       &  rcvd_req_ur_err_svrity   ) |
                           (int_radm_cpl_timeout_err[0]       &  cpl_timeout_svrity       ) |
                           (int_radm_rcvd_req_ca[0]           &  rcvd_req_ca_err_svrity   ) |
                           (int_tlp_trans_egress_blk          &  tlp_trans_egress_blk_svrity_temp   ) |
                           (int_radm_atomic_egress_blk        &  atomic_egress_blk_svrity ) |
                           (int_tlp_prfx_blocked_err          & tlp_prfx_blocked_err_svrity ) |
                           (int_psnd_tlp_egrss_blckd_err      & psnd_tlp_egrss_blckd_err_svrity ) |
                           (int_radm_unexp_cpl_err[0]         &  unexp_tx_cpl_svrity      )
                           |
                           (int_radm_acs_violation[0]         & acs_violation_svrity  )
                           ;

/////////////////////////////////////////////////////////////////////////////
//
// Non-logged FE Pointer Register, for errors for which no header is logged
//
/////////////////////////////////////////////////////////////////////////////

reg     [4:0]   no_log_fe_ptr_reg;          // register holding first error ptr not logged in the header log queue
wire    [4:0]   no_log_fe_ptr_r;            // copy of no_log_fe_ptr_reg, allowing value to be assigned when VF Shared Header Log is implemented
reg             no_log_fe_ptr_active_reg;   // flag indicating the value in no_log_fe_ptr_reg is active and is to be used when reading FE pointer 
wire            no_log_fe_ptr_active;       // copy of no_log_fe_ptr_active_reg, feeds back to next value of no_log_fe_ptr_active_reg
wire            no_log_fe_ptr_active_clr;   // clear the no_log_fe_ptr active bit
wire    [2:0]   no_log_sts_bit_count;       // number of status bits corresponding to non-header logged errors which are currently set in the Uncorrectable Status Register
wire            no_log_fe_ptr_valid0, no_log_fe_ptr_valid1, no_log_fe_ptr_valid2; // no_log_fe_ptr_reg value valid, corresponding to bits set in bytes0, 1 and 2 of the Uncorrectable Status Register

wire [4:0]                  no_log_fe_ptr;  //FE pointer value assigned when non-header logged errors are asserted       
wire                        Q_empty;        //Q with capacity = 1 is empty
wire                        single_Q_empty; //Q with capacity > 1, but with the multiple header recording enable bit cleared, is empty

assign no_log_sts_bit_count = {2'b0,cpl_timeout_sts}+{2'b0,surprise_down_err_sts}+{2'b0,dl_prot_err_sts}+{2'b0,rx_overfl_sts}+{2'b0,rx_fc_prot_err_sts};

parameter INACTIVE_FE_STATE = 5'h0;
parameter DL_PROT_ERR_FE_STATE = 5'h4;
parameter SURPRISE_DOWN_ERR_FE_STATE = 5'h5;
parameter RX_OVERFL_ERR_FE_STATE = 5'h11;
parameter FC_PROT_ERR_FE_STATE = 5'hD;
parameter CPL_TIMEOUT_ERR_FE_STATE = 5'hE;

generate
  if(VF_IMPL_VF_HDR_LOG_SHARED==0) begin : gen_no_log_fe_ptr_reg
    assign no_log_fe_ptr_r      = no_log_fe_ptr_reg; // Copy to wire
    assign no_log_fe_ptr        = (int_dl_prot_err        & !dl_prot_err_mask                                                          ) ? DL_PROT_ERR_FE_STATE
                              : (int_surprise_down_err  & !surprise_down_err_mask                                                      ) ? SURPRISE_DOWN_ERR_FE_STATE
                              : (int_rtlh_overfl_err    & !rx_overfl_mask                                                              ) ? RX_OVERFL_ERR_FE_STATE
                              : (int_rtlh_fc_prot_err   & !rx_fc_prot_err_mask                                                         ) ? FC_PROT_ERR_FE_STATE
                            // fatal errors that could've been advisory                              
                              : (|int_radm_cpl_timeout_err   & !cpl_timeout_mask          & cpl_timeout_svrity                             ) ? CPL_TIMEOUT_ERR_FE_STATE
                            // non-advisory non-fatal errors 
                              : (|int_radm_cpl_timeout_err   & !cpl_timeout_mask          & !cpl_timeout_svrity       & !int_err_advisory[0] ) ? CPL_TIMEOUT_ERR_FE_STATE
                            // advisory non-fatal errors
                              : (|int_radm_cpl_timeout_err   & !cpl_timeout_mask          & !cpl_timeout_svrity       & int_err_advisory[0] & !advisory_nf_mask ) ? CPL_TIMEOUT_ERR_FE_STATE
                              : INACTIVE_FE_STATE;

    assign no_log_fe_ptr_active = no_log_fe_ptr_active_reg;

    assign no_log_fe_ptr_valid0 = (no_log_fe_ptr_reg<=SURPRISE_DOWN_ERR_FE_STATE & no_log_fe_ptr_reg>=DL_PROT_ERR_FE_STATE);  // no_log_fe_ptr_reg points to a valid value corresponding to a bit set byte 0 of the Uncorrectable Status Register
    assign no_log_fe_ptr_valid1 = (no_log_fe_ptr_reg<=CPL_TIMEOUT_ERR_FE_STATE & no_log_fe_ptr_reg>=FC_PROT_ERR_FE_STATE); // no_log_fe_ptr_reg points to a valid value corresponding to a bit set byte 1 of the Uncorrectable Status Register
    assign no_log_fe_ptr_valid2 = (no_log_fe_ptr_reg==RX_OVERFL_ERR_FE_STATE);                         // no_log_fe_ptr_reg points to a valid value corresponding to a bit set byte 2 of the Uncorrectable Status Register

    // Clear the active bit when correct status bit is written to it
    assign no_log_fe_ptr_active_clr = no_log_fe_ptr_active & !(|no_log_fe_ptr) & err_reg_id[1] & 
                                                   ((err_write_pulse[0] & no_log_fe_ptr_valid0) |
                                                   (err_write_pulse[1] & no_log_fe_ptr_valid1) |
                                                   (err_write_pulse[2] & no_log_fe_ptr_valid2)) 
                   & lbc_cdm_data[no_log_fe_ptr_reg] 
                   & no_log_fe_ptr_reg!=INACTIVE_FE_STATE;

    // no_log_fe_ptr register assignment
    always@(posedge core_clk or negedge sticky_rst_n)
    begin
      if(!sticky_rst_n) begin
        no_log_fe_ptr_active_reg <= #TP 1'b0;
        no_log_fe_ptr_reg        <= #TP INACTIVE_FE_STATE;
  
      end else if (!(no_log_fe_ptr_valid0 | no_log_fe_ptr_valid1 | no_log_fe_ptr_valid2) & no_log_fe_ptr_reg!=INACTIVE_FE_STATE) begin
        no_log_fe_ptr_active_reg <= #TP 1'b0;
        no_log_fe_ptr_reg        <= #TP INACTIVE_FE_STATE;

      end else if (!no_log_fe_ptr_active && Q_empty && single_Q_empty && |no_log_fe_ptr) begin
        no_log_fe_ptr_active_reg <= #TP 1'b1;              // set the active bit
        no_log_fe_ptr_reg        <= #TP no_log_fe_ptr;     // assign the FE pointer value
  
      end else if (no_log_fe_ptr_active_clr) begin
        no_log_fe_ptr_active_reg <= #TP 1'b0;       // clear the active bit
        no_log_fe_ptr_reg        <= #TP (no_log_sts_bit_count<=3'd1) ? INACTIVE_FE_STATE : no_log_fe_ptr_reg; //If all bits in the uncorrectable status register are cleared, set the non-logged FE pointer to the inactive value
      end //if !sticky_rst_n
    end // always
 
  end else begin : gen_no_log_fe_ptr_reg // end if
    // no_log_fe_ptr assignment to inactive when VF Shared Header Log
    assign no_log_fe_ptr_r      = INACTIVE_FE_STATE;
    assign no_log_fe_ptr_active = 1'b0;
  end // end else
endgenerate // gen_no_log_fe_ptr


  //////////////////////////////////////////////////////
  //
  //  Start of Q logic 
  //
  //////////////////////////////////////////////////////

  localparam ELQ_MAX_DEPTH          = VF_IMPL ? VF_HDR_LOG_DEPTH : CX_HDR_LOG_DEPTH;
  localparam ELQ_MAX_DEPTH_MINUS1   = (ELQ_MAX_DEPTH - 1);
  localparam ADDR_WIDTH             = (ELQ_MAX_DEPTH>1) ? `CX_LOGBASE2(ELQ_MAX_DEPTH) : 1;           //log base 2 of depth

  wire multi_hdr_rec_cap;
  wire multi_hdr_rec_en;
  wire multi_hdr_rec_en_change;   //the multiple header log enable bit has changed

  wire [ELQ_WIDTH-1:0]              elq [ELQ_MAX_DEPTH_MINUS1:0];

  wire [(ERROR_TLP_WD*5)-1:0]             Q_fe_ptr;      
  wire                              elq_pop;
  wire [ADDR_WIDTH - 1:0]           wr_ptr;
  wire [ADDR_WIDTH - 1:0]           rd_ptr; 
  wire [ADDR_WIDTH:0]               elq_depth; 


//Leda is not failing when depths are equivalent for all funcitons
//
// LMD: Undriven net Range
// LJ: All nets are driven
// leda NTL_CON12 off
  wire    [1:0]                     writes_allowed;
// leda NTL_CON12 on

// -------------- Internal Signals --------------
  wire [(ERROR_TLP_WD-1):0]               Q_msg;
  wire [((ERROR_TLP_WD*ELQ_WIDTH)-1):0]   Q_msg_payload;
  wire [((ERROR_TLP_WD*TLP_SIZE)-1):0]    Q_tlp;

  wire  [((ERROR_TLP_WD*HDR_LOG_SIZE_WD)-1):0] Q_tlp_size;
  wire  [(ERROR_TLP_WD-1):0] Q_tlp_fm;


  wire [((ERROR_TLP_WD*PRFX_SIZE)-1):0]    Q_prefix;
  
  wire    [ADDR_WIDTH:0]            elq_max_depth;
  wire    [ADDR_WIDTH:0]            elq_remaining;




genvar m;

generate
  if(VF_IMPL_VF_HDR_LOG_SHARED==0) begin : gen_hdr_log_queue
    reg [1:0]                         radm_hdr_log_valid_count;               // Number valid error messages from all filters
  
                      //set message received signal, reason signal and payload for each channel 0 to (ERROR_TLP_WD-1)
    for(m=0;m<ERROR_TLP_WD;m=m+1) begin : gen_message_types     //determines if an error is to be logged
      assign Q_msg[m]                           = (logged_error[m] && radm_hdr_log_valid[m]) | (Q_fe_ptr[m*5+:5] > 0);  //internal errors can set the FE Pointer and Status bits
                                                             // the TLP data                //internal and CPL Timeout contain no header data 
      assign Q_tlp[m*TLP_SIZE+:TLP_SIZE]        = int_internal_err        ? {TLP_SIZE{1'b1}}    :
                                                  radm_hdr_log_valid[m]   ? int_radm_hdr_log[m] : 
                                                  'h0;


      assign Q_tlp_size [m*HDR_LOG_SIZE_WD+:HDR_LOG_SIZE_WD] = radm_hdr_log_hdrsize;
      assign Q_tlp_fm   [m]                          = radm_hdr_log_flitmode;

      if(m==0 && ERROR_TLP_WD>1) begin : gen_Q_msg_payload   // if 256 bit, and channel 0 
       assign Q_msg_payload[m*ELQ_WIDTH+:ELQ_WIDTH] = { Q_fe_ptr[m*5+:5],
                                                        Q_tlp_fm[m],
                                                        Q_tlp_size[m*HDR_LOG_SIZE_WD+:HDR_LOG_SIZE_WD],
                                                        Q_tlp[m*TLP_SIZE+:TLP_SIZE]
                                                       };

      end else begin : gen_Q_msg_payload  // end if

       assign Q_msg_payload[m*ELQ_WIDTH+:ELQ_WIDTH] = { Q_fe_ptr[m*5+:5],
                                                        Q_tlp_fm[m],
                                                        Q_tlp_size[m*HDR_LOG_SIZE_WD+:HDR_LOG_SIZE_WD],
                                                        Q_tlp[m*TLP_SIZE+:TLP_SIZE]
                                                       };
      end // end else
    end   // end for m 
  //end

    // spyglass disable_block W164a
    // SMD: Identifies assignments in which the LHS width is less than the RHS width
    // SJ: ERROR_TLP_WD is never more than two and Q_msg can never be more than
    // 1 (single bit value) therefore no possibility to overflow
    always@(*)          // count the number of error messages recieved across each 128 bit TLP's
    begin : proc_count_valid_hdr_log
    integer c; 
      radm_hdr_log_valid_count = 0; 
  
      for(c=0;c<ERROR_TLP_WD;c=c+1) begin
        radm_hdr_log_valid_count = radm_hdr_log_valid_count + Q_msg[c];
      end //for
  
    end //always
    // spyglass enable_block W164a
  

  if(ELQ_MAX_DEPTH>1) begin : gen_multi                         // generate the FIFO Q (not the VF shared log)

    reg [ELQ_WIDTH-1:0]               elq_reg [ELQ_MAX_DEPTH_MINUS1:0];      //AER Error Log Q for any size from 1 up
    

    reg     [ADDR_WIDTH:0]    wr_addr;
    reg     [ADDR_WIDTH:0]    rd_addr;
    reg                       single_Q_empty_reg; //Indicates that a Q with capacity > 1, but with the multiple header recording enable bit cleared, is empty
    
//Leda is not failing when depths are equivalent for all funcitons
//
// LMD: Undriven net Range
// LJ: All nets are driven
// leda NTL_CON12 off
    assign Q_empty = (wr_addr == rd_addr);
  
    assign single_Q_empty = single_Q_empty_reg;
// leda NTL_CON12 on  
  
    //Q with capacity > 1, but with the multiple header recording enable bit cleared, is empty
    always@(posedge core_clk or negedge sticky_rst_n)
    begin
      if(!sticky_rst_n) begin
        single_Q_empty_reg <= #TP 1'b1;
  
      end else if (!multi_hdr_rec_en && ((|Q_msg && single_Q_empty) || (elq_pop && |Q_msg && !single_Q_empty))) begin
        single_Q_empty_reg <= #TP 1'b0;
  
      end else if (!multi_hdr_rec_en && elq_pop && !single_Q_empty) begin
        single_Q_empty_reg <= #TP 1'b1;
  
      end else begin
        single_Q_empty_reg <= #TP multi_hdr_rec_en_change ? 1'b1 : single_Q_empty_reg;

      end //if !sticky_rst_n
    end // always
  
  
    assign elq_max_depth            = multi_hdr_rec_en ? ELQ_MAX_DEPTH : 1;
    assign wr_ptr                   = wr_addr[ADDR_WIDTH-1:0];
    assign rd_ptr                   = rd_addr[ADDR_WIDTH-1:0];       
    
    // spyglass disable_block W164a
    // SMD: Identifies assignments in which the LHS width is less than the RHS width
    // SJ: elq_depth assignment subject to check (rd_addr > wr_addr)
    assign elq_depth[ADDR_WIDTH:0] = !multi_hdr_rec_en ? {{(ADDR_WIDTH){1'b0}},!single_Q_empty} : (rd_addr > wr_addr) ? (~rd_addr + wr_addr + 1) : (wr_addr - rd_addr);
    // spyglass enable_block W164a
 
    // spyglass disable_block W164a
    // SMD: Identifies assignments in which the LHS width is less than the RHS width
    // SJ: elq_max_depth is always greater than elq_depth
    assign elq_remaining           = (elq_depth <= elq_max_depth ) ? (elq_max_depth-elq_depth) : elq_max_depth;
    // spyglass enable_block W164a
    
//Leda is not failing when depths are equivalent for all funcitons
//
// LMD: Undriven net Range
// LJ: All nets are driven
// leda NTL_CON12 off

    // the number of writable Q location at any time is a function of the
    // remaining space in the Q, whether or not a 'Pop' is signalled, the value
    // of ERROR_TLP_WD, and how many error TLPs were received

    // 2 writes_allowed           2 messages && elq_remaining>=2    
    //
    //                            2 messages && elq_remaining==1 && Q popped 
    //
    //
    // 1 writes_allowed           2 messages && elq_remaining==0 && Q popped     
    //  
    //                            1 message && elq_remaining>=1      
    //                            
    //                            1 message && elq_remaining==0 && Q popped 
    //                            
    //otherwise                   0

    assign writes_allowed           = ((Q_msg[ERROR_TLP_WD-1:0]==2'b11 && elq_remaining>=2) ||
                                       (Q_msg[ERROR_TLP_WD-1:0]==2'b11 && elq_remaining==1 && elq_pop)) ? 2 :

                                      ((Q_msg[ERROR_TLP_WD-1:0]==2'b11 && elq_remaining==0 && elq_pop) ||
                                       (Q_msg[ERROR_TLP_WD-1:0]==2'b11 && elq_remaining==1) ||
                                       (^Q_msg && elq_remaining>=1) ||  
                                       (^Q_msg && elq_remaining==0 && elq_pop) )                  ? 1 :

                                       0;
    
// leda NTL_CON12 on  
  
    // write address counter
    always@(posedge core_clk or negedge sticky_rst_n)
    begin
     
      if(!sticky_rst_n) begin
        wr_addr <= #TP 0;
  
      end else begin 
        // spyglass disable_block W164a
        // SMD: Identifies assignments in which the LHS width is less than the RHS width
        // SJ: wr_addr wraps around modulo ADDR_WIDTH+1
        wr_addr <= #TP multi_hdr_rec_en_change ? 0 : multi_hdr_rec_en ? (wr_addr + writes_allowed ) : 0;
        // spyglass enable_block W164a
       
      end //if sticky

    end // always
  

    // the FIFO Q storage registers
    always@(posedge core_clk or negedge sticky_rst_n) begin
    integer p, r;
   
      if(!sticky_rst_n) begin
        for(p=0;p<ELQ_WIDTH;p=p+1) begin
          for(r=0;r<ELQ_MAX_DEPTH;r=r+1) begin
            elq_reg[r][p]  <= #TP 1'b0;
          end // for r
        end //for p
  
      end else if (multi_hdr_rec_en_change) begin       //if the enable bit has changed clear the Q
        for(p=0;p<ELQ_WIDTH;p=p+1) begin
          for(r=0;r<ELQ_MAX_DEPTH;r=r+1) begin
            elq_reg[r][p]  <= #TP 1'b0;
          end  //for r
        end //for p
       
      end else begin  // if sticky
      integer q;
        for(q=0;q<ERROR_TLP_WD;q=q+1) begin
          if (Q_msg[q]) begin
            if (q == 0) begin
              elq_reg[wr_ptr + q] <= #TP (writes_allowed>=1) ? Q_msg_payload[q*ELQ_WIDTH+:ELQ_WIDTH] : 
                                 ((!multi_hdr_rec_en & Q_msg[q] & single_Q_empty) | (!multi_hdr_rec_en & Q_msg[q] & elq_pop & !single_Q_empty)) ? Q_msg_payload[q*ELQ_WIDTH+:ELQ_WIDTH] :
                                 elq_reg[wr_ptr];
            end else    if (Q_msg[0]) begin //q>0 
               elq_reg[wr_ptr + q] <= #TP (writes_allowed>=(q+1)) ? Q_msg_payload[q*ELQ_WIDTH+:ELQ_WIDTH] :
                                 ((!multi_hdr_rec_en & Q_msg[q] & single_Q_empty) | (!multi_hdr_rec_en & Q_msg[q] & elq_pop & !single_Q_empty)) ? Q_msg_payload[q*ELQ_WIDTH+:ELQ_WIDTH] :
                                 elq_reg[wr_ptr + q];
            end else begin
               elq_reg[wr_ptr] <= #TP (writes_allowed>=1) ? Q_msg_payload[q*ELQ_WIDTH+:ELQ_WIDTH] : 
                                 ((!multi_hdr_rec_en & Q_msg[q] & single_Q_empty) | (!multi_hdr_rec_en & Q_msg[q] & elq_pop & !single_Q_empty)) ? Q_msg_payload[q*ELQ_WIDTH+:ELQ_WIDTH] :
                                 elq_reg[wr_ptr];
            end
          end 
        end // for 
      end // else sticky

    end //always

assign elq = elq_reg;

 
  
    //Read address counter
    always@(posedge core_clk or negedge sticky_rst_n)
    begin
      if(!sticky_rst_n) 
        rd_addr <= #TP 0;
  
      else if(elq_pop && !Q_empty) begin
        
        if (rd_ptr == (elq_max_depth-1) && multi_hdr_rec_en) begin
          rd_addr[ADDR_WIDTH-1:0] <= #TP 0;                         //the lower bits
          rd_addr[ADDR_WIDTH]     <= #TP ~rd_addr[ADDR_WIDTH];      //the upper bit
  
        end else begin // if rd_ptr
          rd_addr                 <= #TP multi_hdr_rec_en ? (rd_addr + 1) : 0;
  
        end // if rd_ptr
      end else begin // if sticky_rst_n
          rd_addr                 <= #TP multi_hdr_rec_en_change ? 0 : rd_addr;
      
      end // if sticky
  
    end // always
  
  
  end // End of (ELQ_MAX_DEPTH>1)
  

  //If the Log Depth has a maximum of 1 - Not multiple header logging capable
  //
  if( ELQ_MAX_DEPTH==1) begin : gen_elq_max_depth1     // Q depth of 1 special case, this RTL has its own Q_empty_reg 

//Leda is not failing when depths are equivalent for all funcitons
//
// LMD: Undriven net Range
// LJ: All nets are driven
// leda NTL_CON12 off
    assign writes_allowed = 0;
    assign single_Q_empty = 1;
    assign rd_ptr=0;
    reg [ELQ_WIDTH-1:0]               elq_reg;
    reg Q_empty_reg;
    assign Q_empty = Q_empty_reg;
// leda NTL_CON12 on    
 



    always@(posedge core_clk or negedge sticky_rst_n)
    begin
      if(!sticky_rst_n) begin             //reset all bits of the register
      integer p;
        for(p=0;p<ELQ_WIDTH;p=p+1) begin        
            elq_reg[p]  <= #TP 1'b0;
        end // for p
  
      // any error message received and Q empty
      end else if(|Q_msg & Q_empty_reg) begin     //error can be on either channel in 256 bit but channel 1 error message is mapped to lower bits if
                                                  // channel 0 is empty, if not Channel 0 always take priority
        elq_reg  <= #TP Q_msg_payload[0+:ELQ_WIDTH];
  
      // Q popped and full Q and any error message received      
      end else if(|Q_msg & elq_pop & !Q_empty_reg) begin
        elq_reg  <= #TP Q_msg_payload[0+:ELQ_WIDTH];
  
      end // if sticky 
    end //always

    assign elq[0] = elq_reg;
  
    //in a single depth Q states whether or not Q is empty
    always@(posedge core_clk or negedge sticky_rst_n)
    begin
      if(!sticky_rst_n) begin
        Q_empty_reg <= #TP 1'b1;
  
        // any error message received and empty,    Q popped and full Q and any error message received
      end else if ((|Q_msg & Q_empty_reg) | (elq_pop & |Q_msg & !Q_empty_reg)) begin
        Q_empty_reg <= #TP 1'b0;
  
        //Q popped and full Q and NO error message received
      end else if ((elq_pop && !Q_empty_reg)) begin         //OR the multiple header log enable bit has changed
        Q_empty_reg <= #TP 1'b1;
  
      end //if sticky
    end //always

  end // ELQ_MAX_DEPTH==1

  assign hdr_log_overflow_det =                                core_in_dpc ? 1'b0 :                                                      //multi enabled, space is less than attempted writes
                                (ELQ_MAX_DEPTH>1) && ((multi_hdr_rec_en && writes_allowed<radm_hdr_log_valid_count) ||                                                                                        //multi disabled, Q full, any writes, not popped
                                                      (!multi_hdr_rec_en && !single_Q_empty && |Q_msg && !elq_pop)  ||  
                                                      //multi disabled, Q empty, 2 writes,not popped
                                                      (!multi_hdr_rec_en && single_Q_empty && Q_msg=={2{1'b1}} && !elq_pop) ) ? 1'b1 :
   
     //MAX Depth of 1, Full Q, any message received and not popping   , MAX Depth 1, Empty Q and 2 Error TLPs received (256 bit core) and not popping 
                                ((ELQ_MAX_DEPTH==1 && !Q_empty && |Q_msg && !elq_pop) || (ELQ_MAX_DEPTH==1 && Q_empty && Q_msg=={2{1'b1}} && !elq_pop)) ? 1'b1 : 1'b0;

  //Header Log Overflow Status registers
  //

  reg                 hdr_log_overflow_sts_reg;   // Header Log Overflow Status ,found in Correctable Error Status Register
  
  always @( posedge core_clk or negedge sticky_rst_n ) begin : err_overflow_PROC
    if ( !sticky_rst_n ) begin
      hdr_log_overflow_sts_reg      <= #TP 1'b0;      // RW1C
            
    end else  begin                              // write 1 to clear Overflow Status, or if header enable bit changes           
      hdr_log_overflow_sts_reg      <= #TP int_hdr_log_overflow_det                                                             ? 1'b1 : 
                                           ((err_reg_id[4] & err_write_pulse[1] & lbc_cdm_data[15]) || multi_hdr_rec_en_change) ? 1'b0 : 
                                           hdr_log_overflow_sts_reg; //RW1C

    end // if sticky
  end //always err_overflow_PROC


  assign hdr_log_overflow_sts       = hdr_log_overflow_sts_reg;


//End of Header Log Overflow Registers

//  end // End of (VF_IMPL_VF_HDR_LOG_SHARED==0)



//Pop the Q when correct status bit is written to it
  assign elq_pop = fe_ptr_valid & err_reg_id[1] & ((err_write_pulse[0] & (fe_pointer_q<=3)) |
                                                   (err_write_pulse[0] & (fe_pointer_q<=7 & fe_pointer_q>=6)) |
                                                   (err_write_pulse[1] & (fe_pointer_q<=12 & fe_pointer_q>=8)) |
                                                   (err_write_pulse[1] & (fe_pointer_q==15)) |
                                                   (err_write_pulse[2] & (fe_pointer_q<=23 & fe_pointer_q>=16)) |
                                                   (err_write_pulse[3] & (fe_pointer_q>=24)))
                   & lbc_cdm_data[fe_pointer_q] 
                   & fe_pointer_q!=0;
  
end // VF_IMPL_VF_HDR_LOG_SHARED = 0
  
  else if(VF_IMPL_VF_HDR_LOG_SHARED) begin : gen_no_fifo  //only for VFs, shared VF header logging

    assign Q_empty    = 1'b0;
    assign elq_depth  = {ADDR_WIDTH{1'b0}};
    assign rd_ptr     = {ADDR_WIDTH{1'b0}};
    assign hdr_log_overflow_det       = 1'b0;
    assign elq_pop = 1'b0;
    assign elq_remaining = 1'b0;
    assign elq_max_depth = 1'b0;
    assign single_Q_empty=1'b1;
    assign writes_allowed = 0;

    for(m=0;m<ELQ_MAX_DEPTH;m++) begin : gen_elq
      assign elq[m]        = {ELQ_WIDTH{1'b0}};//elq_reg;
    end

  end // gen_hdr_log_queue 

// -------------------------------------
// finish of Header Recording Log 
// -------------------------------------

endgenerate 


// -----------------------------------------------------------------------------
// Advanced Error Reporting Enhanced Capability Header
// ecfig_reg_id     - 0
// PCIE Offset      - `AER_PTR
// length           - 4 byte
// default value    - 0h
// Cfig register    - ecfg_reg_3, ecfg_reg_2, ecfg_reg_1, ecfg_reg_0
// -----------------------------------------------------------------------------

// Capabilities such as ARI should not be visible to a DM product in Root
// Port mode; hence, when rc_device is true then the next pointer is in
// a smaller linked list (DM_RP_AER_NEXT_PTR):

reg [15:0]  cfg_aer_id;          // AER Capability ID
reg [3:0]   cfg_aer_ver;         // AER Capability Version
reg [11:0]  cfg_aer_next_ptr;    // AER Next Capability Offset
reg         err_next_ptr_wr_updated;    // Asserted when AER Capability header has been changed by a DBI write


assign {ecfg_reg_1, ecfg_reg_0} = cfg_aer_id;
assign {ecfg_reg_3, ecfg_reg_2} = {cfg_aer_next_ptr, cfg_aer_ver};

always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin : cap_hdr_PROC
    if ( !sticky_rst_n ) begin
        cfg_aer_id[15:0]       <= #TP `PCIE_AER_ECAP_ID;
        cfg_aer_ver[3:0]       <= #TP `PCIE_AER_ECAP_VER;
    end else begin
        // Read-Only registers, but writable through DBI
        cfg_aer_id[7:0]        <= #TP (err_reg_id[0] & err_write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[7:0] : cfg_aer_id[7:0];
        cfg_aer_id[15:8]       <= #TP (err_reg_id[0] & err_write_pulse[1] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[15:8] : cfg_aer_id[15:8];
        cfg_aer_ver[3:0]       <= #TP (err_reg_id[0] & err_write_pulse[2] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[19:16] : cfg_aer_ver[3:0];
    end
end

always @( posedge core_clk or negedge sticky_rst_n ) begin : cap_next_ptr_PROC
    if ( !sticky_rst_n ) begin
        cfg_aer_next_ptr[11:0]  <= #TP LOCAL_AER_NEXT_PTR;       // Assume EP linked list at reset.
    end else if (err_reg_id[0] && lbc_cdm_dbi && dbi_ro_wr_en) begin
        // Read-Only registers, but writable through DBI
        cfg_aer_next_ptr[3:0]  <= #TP err_write_pulse[2] ? lbc_cdm_data[23:20] : cfg_aer_next_ptr[3:0];
        cfg_aer_next_ptr[11:4] <= #TP err_write_pulse[3] ? lbc_cdm_data[31:24] : cfg_aer_next_ptr[11:4];
    end else if ((rc_device || pcie_sw_down) && !err_next_ptr_wr_updated) begin      // If RP or downstream port of SW, then use smaller linked list.
        cfg_aer_next_ptr[11:0] <= #TP `DM_RP_AER_NEXT_PTR;
    end else if (!err_next_ptr_wr_updated) begin
        cfg_aer_next_ptr[11:0]  <= #TP (cxl_rcrb_enable && upstream_port && (VF_IMPL == 0)) ? `CXL_AER_NEXT_PTR : LOCAL_AER_NEXT_PTR;       // If RP or upstream port of SW, then use full linked list. Device type could change if crosslink enable is true.
    end
end

// If next pointer is modified by a DBI write, then only the Application
// (via another DBI write) is allowed any further update.
always @( posedge core_clk or negedge sticky_rst_n ) begin : err_next_ptr_wr_update_PROC
    if ( !sticky_rst_n ) begin
        err_next_ptr_wr_updated <= #TP 1'b0;
    end else if (err_reg_id[0] && lbc_cdm_dbi && dbi_ro_wr_en && |err_write_pulse[3:2]) begin
        err_next_ptr_wr_updated <= #TP 1'b1;
    end
end


// AER Next Pointer for RCRB

reg [11:0]  rcrb_cfg_aer_next_ptr;    // AER Next Capability Offset
reg         rcrb_err_next_ptr_wr_updated;    // Asserted when AER Capability header has been changed by a DBI write

always @( posedge core_clk or negedge sticky_rst_n ) begin
    if ( !sticky_rst_n ) begin
        rcrb_cfg_aer_next_ptr[11:0]  <= #TP LOCAL_AER_NEXT_PTR;       // Assume EP linked list at reset.
    end else if (rcrb_err_reg_id_0 && lbc_cdm_dbi && dbi_ro_wr_en) begin
        // Read-Only registers, but writable through DBI
        rcrb_cfg_aer_next_ptr[3:0]  <= #TP rcrb_err_write_pulse[2] ? lbc_cdm_data[23:20] : rcrb_cfg_aer_next_ptr[3:0];
        rcrb_cfg_aer_next_ptr[11:4] <= #TP rcrb_err_write_pulse[3] ? lbc_cdm_data[31:24] : rcrb_cfg_aer_next_ptr[11:4];
    end else if ((rc_device || pcie_sw_down) && !rcrb_err_next_ptr_wr_updated) begin      // If RP or downstream port of SW, then use smaller linked list.
        rcrb_cfg_aer_next_ptr[11:0] <= #TP `DM_RP_AER_NEXT_PTR;
    end else if (!rcrb_err_next_ptr_wr_updated) begin
        rcrb_cfg_aer_next_ptr[11:0]  <= #TP (cxl_rcrb_enable && upstream_port)? `RCRB_AER_NEXT_PTR : LOCAL_AER_NEXT_PTR;       // If RP or upstream port of SW, then use full linked list. Device type could change if crosslink enable is true.
    end
end

// If next pointer is modified by a DBI write, then only the Application
// (via another DBI write) is allowed any further update.
always @( posedge core_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
        rcrb_err_next_ptr_wr_updated <= #TP 1'b0;
    end else if (rcrb_err_reg_id_0 && lbc_cdm_dbi && dbi_ro_wr_en && |rcrb_err_write_pulse[3:2]) begin
        rcrb_err_next_ptr_wr_updated <= #TP 1'b1;
    end
end






// -----------------------------------------------------------------------------
// Uncorrectable Error Status Register
// ecfig_reg_id     - 1
// PCIE Offset      - `AER_PTR + 04h
// length           - 4 byte
// default value    - 0h
// Cfig register    - ecfg_reg_7, ecfg_reg_6, ecfg_reg_5, ecfg_reg_4
// -----------------------------------------------------------------------------
wire cfg_uncor_internal_err_sts;
wire cfg_rcvr_overflow_err_sts;
wire cfg_fc_protocol_err_sts;
wire cfg_mlf_tlp_err_sts;
wire cfg_surprise_down_er_sts;
wire cfg_dl_protocol_err_sts;
wire cfg_ecrc_err_sts;
assign cfg_uncor_internal_err_sts = internal_err_sts;
assign cfg_rcvr_overflow_err_sts  = rx_overfl_sts;
assign cfg_fc_protocol_err_sts    = rx_fc_prot_err_sts;
assign cfg_mlf_tlp_err_sts        = rx_mlf_tlp_sts;
assign cfg_surprise_down_er_sts   = surprise_down_err_sts;
assign cfg_dl_protocol_err_sts    = dl_prot_err_sts;
assign cfg_ecrc_err_sts           = rx_ecrc_err_sts;

generate
if(VF_IMPL_VF_HDR_LOG_SHARED == 0) begin : gen_uncorr_err_sts

assign fe_pointer = no_log_fe_ptr_active ? no_log_fe_ptr_r : fe_pointer_q;

// all sticky bits
assign ecfg_reg_4   = {2'b0, 
                       ((fe_pointer == 5'h5) | surprise_down_err_sts),
                       ((fe_pointer == 5'h4) | dl_prot_err_sts), 
                       4'b0};
assign ecfg_reg_5   = {((fe_pointer == 5'hF) | cpl_tx_abort_sts), 
                       ((fe_pointer == 5'hE) | cpl_timeout_sts), 
                       ((fe_pointer == 5'hD) | rx_fc_prot_err_sts), 
                       ((fe_pointer == 5'hC) | rx_tlp_poisoned_sts), 
                       4'b0};
assign ecfg_reg_6   = {1'b0, 
                       ((fe_pointer == 5'h16) | internal_err_sts),
                       ((fe_pointer == 5'h15) | acs_violation_sts),
                       ((fe_pointer == 5'h14) | tx_unsupt_req_err_sts), 
                       ((fe_pointer == 5'h13) | rx_ecrc_err_sts), 
                       ((fe_pointer == 5'h12) | rx_mlf_tlp_sts), 
                       ((fe_pointer == 5'h11) | rx_overfl_sts), 
                       ((fe_pointer == 5'h10) | unexp_tx_cpl_sts)
                       };
                       
assign tlp_trans_egress_blk_sts = ((fe_pointer == 5'h1F) | tlp_trans_egress_blk_sts_temp);
 
assign ecfg_reg_7   = { tlp_trans_egress_blk_sts
                       ,3'b0
                       ,1'b0
                       ,((fe_pointer == 5'h1a) | psnd_tlp_egrss_blckd_err_sts)
                       ,((fe_pointer == 5'h19) | tlp_prfx_blocked_err_sts)
                       ,((fe_pointer == 5'h18) | tx_atomic_egress_blk_sts)
                       };

end else begin : gen_uncorr_err_sts
  
assign ecfg_reg_4   = 8'b0; 

assign ecfg_reg_5   = {cpl_tx_abort_sts, 
                       cpl_timeout_sts, 
                       1'b0, 
                       rx_tlp_poisoned_sts, 
                       4'b0
                       };

assign ecfg_reg_6   = {2'b0,
                       acs_violation_sts,
                       tx_unsupt_req_err_sts, 
                       4'b0
                       };

assign ecfg_reg_7   = 8'b0;

end // gen_uncorr_err_sts
endgenerate   // !VF_IMPL_VF_HDR_LOG_SHARED


always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        dl_prot_err_sts             <= #TP 1'b0;
        surprise_down_err_sts       <= #TP 1'b0;
        rx_tlp_poisoned_sts         <= #TP 1'b0;
        rx_fc_prot_err_sts          <= #TP 1'b0;
        cpl_timeout_sts             <= #TP 1'b0;
        cpl_tx_abort_sts            <= #TP 1'b0;
        unexp_tx_cpl_sts            <= #TP 1'b0;
        rx_overfl_sts               <= #TP 1'b0;
        rx_mlf_tlp_sts              <= #TP 1'b0;
        rx_ecrc_err_sts             <= #TP 1'b0;
        tx_unsupt_req_err_sts       <= #TP 1'b0;
        tx_atomic_egress_blk_sts    <= #TP 1'b0;
        tlp_prfx_blocked_err_sts    <= #TP 1'b0;
        psnd_tlp_egrss_blckd_err_sts <= #TP 1'b0;
        tlp_trans_egress_blk_sts_temp    <= #TP 1'b0;
        
        internal_err_sts            <= #TP 1'b0;
        acs_violation_sts           <= #TP 1'b0;
    end else begin
    // data link protocol error status bit
        dl_prot_err_sts         <= #TP int_dl_prot_err ? 1'b1
                                        : err_reg_id[1] & err_write_pulse[0] & lbc_cdm_data[4]  ? 1'b0
                                        : multi_hdr_rec_en_change ? 1'b0
                                        : dl_prot_err_sts;
    // Surprise Down error status bit
        surprise_down_err_sts         <= #TP int_surprise_down_err ? 1'b1
                                        : err_reg_id[1] & err_write_pulse[0] & lbc_cdm_data[5]  ? 1'b0
                                        : multi_hdr_rec_en_change ? 1'b0
                                        : surprise_down_err_sts;
                                        

    // Poisoned TLP Status bit (could be advisory)
        rx_tlp_poisoned_sts     <= #TP ((rtlh_poisoned_err[0] &  int_err_advisory[0] & !rx_tlp_poisoned_svrity & !advisory_nf_mask) |
                                        (rtlh_poisoned_err[0] &  int_err_advisory[0] &  rx_tlp_poisoned_svrity) |
                                        (rtlh_poisoned_err[0] & !int_err_advisory[0]))                ? 1'b1
                                        : err_reg_id[1] & err_write_pulse[1] & lbc_cdm_data[12] ? 1'b0
                                        : multi_hdr_rec_en_change ? 1'b0
                                        : rx_tlp_poisoned_sts;
     // ECRC Error Status bit (could be advisory)
        rx_ecrc_err_sts         <= #TP ((valid_ecrc_err[0] &  int_err_advisory[0] & !rx_ecrc_err_svrity & !advisory_nf_mask) |
                                        (valid_ecrc_err[0] &  int_err_advisory[0] &  rx_ecrc_err_svrity) |
                                        (valid_ecrc_err[0] & !int_err_advisory[0]))                   ? 1'b1
                                        : err_reg_id[1] & err_write_pulse[2] & lbc_cdm_data[19] ? 1'b0
                                        : multi_hdr_rec_en_change ? 1'b0
                                        : rx_ecrc_err_sts;
    // Unsupported Request Error Status bit (could be advisory)
        tx_unsupt_req_err_sts   <= #TP ((int_radm_rcvd_req_ur[0] &  int_err_advisory[0] & !rcvd_req_ur_err_svrity & !advisory_nf_mask) |
                                        (int_radm_rcvd_req_ur[0] &  int_err_advisory[0] &  rcvd_req_ur_err_svrity) |
                                        (int_radm_rcvd_req_ur[0] &  !int_err_advisory[0])) ? 1'b1
                                        : err_reg_id[1] & err_write_pulse[2] & lbc_cdm_data[20] ? 1'b0
                                        : multi_hdr_rec_en_change ? 1'b0
                                        : tx_unsupt_req_err_sts;
    // Completion Timeout Status Bit (could be advisory)
        cpl_timeout_sts         <= #TP ((int_radm_cpl_timeout_err[0] &  int_err_advisory[0] & !cpl_timeout_svrity & !advisory_nf_mask) |
                                        (int_radm_cpl_timeout_err[0] &  int_err_advisory[0] &  cpl_timeout_svrity) |
                                        (int_radm_cpl_timeout_err[0] & !int_err_advisory[0]))             ? 1'b1
                                        : err_reg_id[1] & err_write_pulse[1] & lbc_cdm_data[14] ? 1'b0
                                        : multi_hdr_rec_en_change ? 1'b0
                                        : cpl_timeout_sts;
    // Completer Abort Status Bit (could be advisory)
        cpl_tx_abort_sts        <= #TP ((int_radm_rcvd_req_ca[0] &  int_err_advisory[0] & !rcvd_req_ca_err_svrity & !advisory_nf_mask) |
                                        (int_radm_rcvd_req_ca[0] &  int_err_advisory[0] &  rcvd_req_ca_err_svrity) |
                                        (int_radm_rcvd_req_ca[0] & !int_err_advisory[0]))           ? 1'b1
                                        : err_reg_id[1] & err_write_pulse[1] & lbc_cdm_data[15] ? 1'b0
                                        : multi_hdr_rec_en_change ? 1'b0
                                        : cpl_tx_abort_sts;
    // AtomicOp Egress Blocked Error Status bit (always advisory)
        tx_atomic_egress_blk_sts <= #TP ((int_radm_atomic_egress_blk & !atomic_egress_blk_svrity & !advisory_nf_mask) |
                                         (int_radm_atomic_egress_blk &  atomic_egress_blk_svrity))   ? 1'b1
                                         :err_reg_id[1] & err_write_pulse[3] & lbc_cdm_data[24]  ? 1'b0
                                         : multi_hdr_rec_en_change ? 1'b0
                                         :tx_atomic_egress_blk_sts;
    // TLP Prefix Blocked Error Status
        tlp_prfx_blocked_err_sts <= #TP ((int_tlp_prfx_blocked_err &  int_err_advisory[0] & !tlp_prfx_blocked_err_svrity & !advisory_nf_mask) |
                                        (int_tlp_prfx_blocked_err &  int_err_advisory[0] &  tlp_prfx_blocked_err_svrity) |
                                        (int_tlp_prfx_blocked_err & !int_err_advisory[0]))                   ? 1'b1
                                         :err_reg_id[1] & err_write_pulse[3] & lbc_cdm_data[25]  ? 1'b0
                                         : multi_hdr_rec_en_change ? 1'b0
                                         :tlp_prfx_blocked_err_sts;
    // Poisoned TLP Egress Blocked Status
        psnd_tlp_egrss_blckd_err_sts <= #TP upstream_port                                         ? 1'b0 
                                        : ((int_psnd_tlp_egrss_blckd_err &  int_err_advisory[0] & !psnd_tlp_egrss_blckd_err_svrity & !advisory_nf_mask) |
                                           (int_psnd_tlp_egrss_blckd_err &  int_err_advisory[0] &  psnd_tlp_egrss_blckd_err_svrity) |
                                           (int_psnd_tlp_egrss_blckd_err & !int_err_advisory[0])) ? 1'b1
                                        : err_reg_id[1] & err_write_pulse[3] & lbc_cdm_data[26]   ? 1'b0
                                        : multi_hdr_rec_en_change                                 ? 1'b0
                                        : psnd_tlp_egrss_blckd_err_sts;

    //TLP Translation Egress Blocked Status bit
      tlp_trans_egress_blk_sts_temp   <= #TP ((int_tlp_trans_egress_blk & !tlp_trans_egress_blk_svrity_temp & !advisory_nf_mask) |
                                         (int_tlp_trans_egress_blk &  tlp_trans_egress_blk_svrity_temp)) ? 1'b1
                                         : err_reg_id[1] & err_write_pulse[3] & lbc_cdm_data[31]  ? 1'b0
                                         : multi_hdr_rec_en_change ? 1'b0
                                         : tlp_trans_egress_blk_sts_temp;
    
    // Unexpected Completion Status Bit (always advisory)
        unexp_tx_cpl_sts        <= #TP ((int_radm_unexp_cpl_err[0] & !unexp_tx_cpl_svrity & !advisory_nf_mask) |
                                        (int_radm_unexp_cpl_err[0] &  unexp_tx_cpl_svrity))            ? 1'b1
                                        : err_reg_id[1] & err_write_pulse[2] & lbc_cdm_data[16] ? 1'b0
                                        : multi_hdr_rec_en_change ? 1'b0
                                        : unexp_tx_cpl_sts;
    // Receive Overflow Status bit
        rx_overfl_sts           <= #TP int_rtlh_overfl_err ? 1'b1
                                        : err_reg_id[1] & err_write_pulse[2] & lbc_cdm_data[17] ? 1'b0
                                        : multi_hdr_rec_en_change ? 1'b0
                                        : rx_overfl_sts;
    // internal Error Status bit
        internal_err_sts        <= #TP int_internal_err ? 1'b1
                                        : err_reg_id[1] & err_write_pulse[2] & lbc_cdm_data[22] ? 1'b0
                                        : multi_hdr_rec_en_change ? 1'b0
                                        : internal_err_sts;
    // Flow control protocol status bit
        rx_fc_prot_err_sts      <= #TP int_rtlh_fc_prot_err ? 1'b1
                                        : err_reg_id[1] & err_write_pulse[1] & lbc_cdm_data[13] ? 1'b0
                                        : multi_hdr_rec_en_change ? 1'b0
                                        : rx_fc_prot_err_sts;
    // Malformed TLP Status bit
        rx_mlf_tlp_sts          <= #TP int_radm_mlf_tlp_err[0] ? 1'b1
                                        : err_reg_id[1] & err_write_pulse[2] & lbc_cdm_data[18] ? 1'b0
                                        : multi_hdr_rec_en_change ? 1'b0
                                        : rx_mlf_tlp_sts;
        acs_violation_sts     <= #TP   ((int_radm_acs_violation[0] &  int_err_advisory[0] & !acs_violation_svrity & !advisory_nf_mask) |
                                        (int_radm_acs_violation[0] &  int_err_advisory[0] &  acs_violation_svrity) |
                                        (int_radm_acs_violation[0] & !int_err_advisory[0]))                ? 1'b1
                                        : err_reg_id[1] & err_write_pulse[2] & lbc_cdm_data[21] ? 1'b0
                                        : multi_hdr_rec_en_change ? 1'b0
                                        : acs_violation_sts;
        if( VF_IMPL ) begin
            // VFs only implement a subset of the status bits. Implemented bits correspond to commented lines below.
            dl_prot_err_sts           <= #TP 1'b0;
            surprise_down_err_sts     <= #TP 1'b0;
            //rx_tlp_poisoned_sts     <= #TP 1'b0;
            rx_ecrc_err_sts           <= #TP 1'b0;
            //tx_unsupt_req_err_sts   <= #TP 1'b0;
            //cpl_timeout_sts         <= #TP 1'b0;
            //cpl_tx_abort_sts        <= #TP 1'b0;
            //unexp_tx_cpl_sts        <= #TP 1'b0;
            rx_overfl_sts             <= #TP 1'b0;
            rx_fc_prot_err_sts        <= #TP 1'b0;
            rx_mlf_tlp_sts            <= #TP 1'b0;
            internal_err_sts          <= #TP 1'b0;
            tx_atomic_egress_blk_sts  <= #TP 1'b0;
            tlp_trans_egress_blk_sts_temp  <= #TP 1'b0;
            //acs_violation_sts         <= #TP 1'b0;
        end
    end
end



// -----------------------------------------------------------------------------
// Uncorrectable Error Mask Register
// ecfig_reg_id     - 2
// PCIE Offset      - `AER_PTR + 08h
// length           - 4 byte
// default value    - 0h
// Cfig register    - ecfg_reg_11, ecfg_reg_10, ecfg_reg_9, ecfg_reg_8
// -----------------------------------------------------------------------------
assign ecfg_reg_8   = VF_IMPL ? 8'b0 : {2'b0, surprise_down_err_mask, dl_prot_err_mask, 4'b0};

assign ecfg_reg_9   = VF_IMPL ? 8'b0 : {cpl_tx_abort_mask, cpl_timeout_mask, rx_fc_prot_err_mask, rx_tlp_poisoned_mask, 4'b0};

assign ecfg_reg_10  = VF_IMPL ? 8'b0 : {1'b0, internal_err_mask, 
                                        acs_violation_mask, 
                                        tx_unsupt_req_err_mask, rx_ecrc_err_mask, rx_mlf_tlp_mask, rx_overfl_mask, unexp_tx_cpl_mask};

assign tlp_trans_egress_blk_mask  =  tlp_trans_egress_blk_mask_temp;

assign ecfg_reg_11  = VF_IMPL ? 8'b0 : { tlp_trans_egress_blk_mask
                       ,3'b0
                       ,1'b0
                       ,psnd_tlp_egrss_blckd_err_mask
                       ,tlp_prfx_blocked_err_mask // only applicable to root and switch ports
                       ,tx_atomic_egress_blk_mask // only applicable to root ports and switch ports, so no VFs even though VFs log function specific errors
                       };

assign cfg_aer_uncorr_mask = {ecfg_reg_11, ecfg_reg_10, ecfg_reg_9, ecfg_reg_8};


reg int_dl_prot_err_mask;
reg int_surprise_down_err_mask;
reg int_rx_tlp_poisoned_mask;
reg int_rx_fc_prot_err_mask;
reg int_cpl_timeout_mask;
reg int_cpl_tx_abort_mask;
reg int_unexp_tx_cpl_mask;
reg int_rx_overfl_mask;
reg int_rx_mlf_tlp_mask;
reg int_rx_ecrc_err_mask;
reg int_tx_unsupt_req_err_mask;
reg int_internal_err_mask;
reg int_tx_atomic_egress_blk_mask;
reg int_tlp_trans_egress_blk_mask;
reg int_tlp_prfx_blocked_err_mask;
reg int_psnd_tlp_egrss_blckd_err_mask;
reg int_acs_violation_mask;

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        int_psnd_tlp_egrss_blckd_err_mask <= #TP 1'b1;
    end else
    begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        int_psnd_tlp_egrss_blckd_err_mask <= #TP upstream_port ? 1'b0 : 
                                                 (err_reg_id[2] & err_write_pulse[3]) ? lbc_cdm_data[26] : int_psnd_tlp_egrss_blckd_err_mask;
       
    end
end

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        int_dl_prot_err_mask          <= #TP 1'b0;
        int_surprise_down_err_mask    <= #TP 1'b0;
        int_rx_tlp_poisoned_mask      <= #TP 1'b0;
        int_rx_fc_prot_err_mask       <= #TP 1'b0;
        int_cpl_timeout_mask          <= #TP 1'b0;
        int_cpl_tx_abort_mask         <= #TP 1'b0;
        int_unexp_tx_cpl_mask         <= #TP 1'b0;
        int_rx_overfl_mask            <= #TP 1'b0;
        int_rx_mlf_tlp_mask           <= #TP 1'b0;
        int_rx_ecrc_err_mask          <= #TP 1'b0;
        int_tx_unsupt_req_err_mask    <= #TP 1'b0;
        int_tx_atomic_egress_blk_mask <= #TP 1'b0;
        int_tlp_prfx_blocked_err_mask <= #TP 1'b0;
        int_tlp_trans_egress_blk_mask <= #TP 1'b0;
        int_internal_err_mask         <= #TP 1'b1;
        int_acs_violation_mask        <= #TP 1'b0;
    end else
    begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        int_dl_prot_err_mask          <= #TP (err_reg_id[2] & err_write_pulse[0]) ? lbc_cdm_data[4]  : int_dl_prot_err_mask;
        int_surprise_down_err_mask    <= #TP !cfg_pcie_surp_dn_rpt_cap ? 1'b0 : (err_reg_id[2] & err_write_pulse[0]) ? lbc_cdm_data[5]  : int_surprise_down_err_mask;
        int_rx_tlp_poisoned_mask      <= #TP (err_reg_id[2] & err_write_pulse[1]) ? lbc_cdm_data[12] : int_rx_tlp_poisoned_mask;
        int_rx_fc_prot_err_mask       <= #TP (err_reg_id[2] & err_write_pulse[1]) ? lbc_cdm_data[13] : int_rx_fc_prot_err_mask;
        int_cpl_timeout_mask          <= #TP (err_reg_id[2] & err_write_pulse[1]) ? lbc_cdm_data[14] : int_cpl_timeout_mask;
        int_cpl_tx_abort_mask         <= #TP (err_reg_id[2] & err_write_pulse[1]) ? lbc_cdm_data[15] : int_cpl_tx_abort_mask;
        int_unexp_tx_cpl_mask         <= #TP (err_reg_id[2] & err_write_pulse[2]) ? lbc_cdm_data[16] : int_unexp_tx_cpl_mask;
        int_rx_overfl_mask            <= #TP (err_reg_id[2] & err_write_pulse[2]) ? lbc_cdm_data[17] : int_rx_overfl_mask;
        int_rx_mlf_tlp_mask           <= #TP (err_reg_id[2] & err_write_pulse[2]) ? lbc_cdm_data[18] : int_rx_mlf_tlp_mask;
        int_rx_ecrc_err_mask          <= #TP ((`DEFAULT_ECRC_CHK_CAP==1) & err_reg_id[2] & err_write_pulse[2]) ? lbc_cdm_data[19] : int_rx_ecrc_err_mask;
        int_tx_unsupt_req_err_mask    <= #TP (err_reg_id[2] & err_write_pulse[2]) ? lbc_cdm_data[20] : int_tx_unsupt_req_err_mask;
        int_acs_violation_mask        <= #TP acs_viol_svrity_mask_wr_en ? (err_reg_id[2] & err_write_pulse[2]) ? lbc_cdm_data[21] : int_acs_violation_mask : 1'b0;
        int_internal_err_mask         <= #TP (err_reg_id[2] & err_write_pulse[2]) ? lbc_cdm_data[22] : int_internal_err_mask;
        // Uncorrectable error mask Register fields for bits not implemented by the Function are hardwired to 0b        
        // In the Device control register, the applicable functions for AtomicOP Egress blocking are Switch ports and Root Ports
        // that implement AtomicOp routing capability; otherwise must be hardwired to 0b.        
            if (rc_device || switch_device) 
            begin 
                int_tx_atomic_egress_blk_mask <= #TP (err_reg_id[2] & err_write_pulse[3]) ? lbc_cdm_data[24] : int_tx_atomic_egress_blk_mask;
            end
            else 
            begin
                int_tx_atomic_egress_blk_mask <= #TP 0;
            end        
        // End-to-End TLP prefix blocking is applicable for Root port and switch ports functions, and is RSVDP for other cases.
            if (rc_device || switch_device) 
            begin 
                int_tlp_prfx_blocked_err_mask <= #TP (err_reg_id[2] & err_write_pulse[3]) ? lbc_cdm_data[25] : int_tlp_prfx_blocked_err_mask;
            end
            else 
            begin
                int_tlp_prfx_blocked_err_mask <= #TP 0;
            end
        //TLP translation Egress Blocked
            if (rc_device || switch_device) 
            begin 
                int_tlp_trans_egress_blk_mask <= #TP (err_reg_id[2] & err_write_pulse[3]) ? lbc_cdm_data[31] : int_tlp_trans_egress_blk_mask;
            end
            else 
            begin
                int_tlp_trans_egress_blk_mask <= #TP 0;
            end    
    end
end

always @(*)
begin
    // VFs only implement a subset of the mask bits. Implemented bits inherit settings from PF
    dl_prot_err_mask          = VF_IMPL ? 1'b0                       : int_dl_prot_err_mask;
    surprise_down_err_mask    = VF_IMPL ? 1'b0                       : int_surprise_down_err_mask;
    rx_tlp_poisoned_mask      = VF_IMPL ? pf_cfg_aer_uncorr_mask[12] : int_rx_tlp_poisoned_mask;
    rx_fc_prot_err_mask       = VF_IMPL ? 1'b0                       : int_rx_fc_prot_err_mask;
    cpl_timeout_mask          = VF_IMPL ? pf_cfg_aer_uncorr_mask[14] : int_cpl_timeout_mask;
    cpl_tx_abort_mask         = VF_IMPL ? pf_cfg_aer_uncorr_mask[15] : int_cpl_tx_abort_mask;
    unexp_tx_cpl_mask         = VF_IMPL ? pf_cfg_aer_uncorr_mask[16] : int_unexp_tx_cpl_mask;
    rx_overfl_mask            = VF_IMPL ? 1'b0                       : int_rx_overfl_mask;
    rx_mlf_tlp_mask           = VF_IMPL ? 1'b0                       : int_rx_mlf_tlp_mask;
    rx_ecrc_err_mask          = VF_IMPL ? 1'b0                       : int_rx_ecrc_err_mask;
    tx_unsupt_req_err_mask    = VF_IMPL ? pf_cfg_aer_uncorr_mask[20] : int_tx_unsupt_req_err_mask;
    tx_atomic_egress_blk_mask = VF_IMPL ? 1'b0                       : int_tx_atomic_egress_blk_mask;
    tlp_prfx_blocked_err_mask = VF_IMPL ? 1'b0                       : int_tlp_prfx_blocked_err_mask;
    psnd_tlp_egrss_blckd_err_mask = VF_IMPL ? 1'b0                   : int_psnd_tlp_egrss_blckd_err_mask;
    tlp_trans_egress_blk_mask_temp = VF_IMPL ? 1'b0                  : int_tlp_trans_egress_blk_mask;
    internal_err_mask         = VF_IMPL ? 1'b0                       : int_internal_err_mask;
    acs_violation_mask        = VF_IMPL ? pf_cfg_aer_uncorr_mask[21] : int_acs_violation_mask;
end

// -----------------------------------------------------------------------------
// Uncorrectable Error Severity Register
// ecfig_reg_id     - 3
// PCIE Offset      - `AER_PTR + 0Ch
// length           - 4 byte
// default value    - 0h
// Cfig register    - ecfg_reg_15, ecfg_reg_14, ecfg_reg_13, ecfg_reg_12
// -----------------------------------------------------------------------------
assign ecfg_reg_12  = VF_IMPL ? 8'b0 : {2'b0, surprise_down_err_svrity, dl_prot_err_svrity, 4'b0};

assign ecfg_reg_13  = VF_IMPL ? 8'b0 : {rcvd_req_ca_err_svrity, cpl_timeout_svrity, rx_fc_prot_err_svrity, rx_tlp_poisoned_svrity, 4'b0};
assign ecfg_reg_14  = VF_IMPL ? 8'b0 : {1'b0, internal_err_svrity,
                       acs_violation_svrity, 
                       rcvd_req_ur_err_svrity, rx_ecrc_err_svrity, rx_mlf_tlp_svrity, rx_overfl_svrity, unexp_tx_cpl_svrity};

assign tlp_trans_egress_blk_svrity = tlp_trans_egress_blk_svrity_temp ;

assign ecfg_reg_15  = VF_IMPL ? 8'b0 : { tlp_trans_egress_blk_svrity
                       ,3'b0
                       ,1'b0
                       ,psnd_tlp_egrss_blckd_err_svrity
                       ,tlp_prfx_blocked_err_svrity
                       ,atomic_egress_blk_svrity
                       };


assign cfg_aer_uncorr_svrity = {ecfg_reg_15, ecfg_reg_14, ecfg_reg_13, ecfg_reg_12};

// the severity regs are needed for upstream report generation
reg int_dl_prot_err_svrity;
reg int_surprise_down_err_svrity;
reg int_rx_tlp_poisoned_svrity;
reg int_rx_fc_prot_err_svrity;
reg int_cpl_timeout_svrity;
reg int_rcvd_req_ca_err_svrity;
reg int_unexp_tx_cpl_svrity;
reg int_rx_overfl_svrity;
reg int_rx_mlf_tlp_svrity;
reg int_rx_ecrc_err_svrity;
reg int_rcvd_req_ur_err_svrity;
reg int_atomic_egress_blk_svrity;
reg int_tlp_prfx_blocked_err_svrity;
reg int_psnd_tlp_egrss_blckd_err_svrity;
reg int_tlp_trans_egress_blk_svrity;
reg int_internal_err_svrity;
reg int_acs_violation_svrity;
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        int_dl_prot_err_svrity          <= #TP 1'b1;
        int_surprise_down_err_svrity    <= #TP 1'b1;
        int_rx_tlp_poisoned_svrity      <= #TP 1'b0;
        int_rx_fc_prot_err_svrity       <= #TP 1'b1;
        int_cpl_timeout_svrity          <= #TP 1'b0;
        int_rcvd_req_ca_err_svrity      <= #TP 1'b0;
        int_unexp_tx_cpl_svrity         <= #TP 1'b0;
        int_rx_overfl_svrity            <= #TP 1'b1;
        int_rx_mlf_tlp_svrity           <= #TP 1'b1;
        int_rx_ecrc_err_svrity          <= #TP 1'b0;
        int_rcvd_req_ur_err_svrity      <= #TP 1'b0;
        int_atomic_egress_blk_svrity    <= #TP 1'b0;
        
        int_tlp_prfx_blocked_err_svrity    <= #TP 1'b0;
        int_psnd_tlp_egrss_blckd_err_svrity <= #TP 1'b0;
        int_tlp_trans_egress_blk_svrity  <= #TP 1'b0;
        int_internal_err_svrity         <= #TP 1'b1;
        int_acs_violation_svrity        <= #TP 1'b0;
    end else
    begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        int_dl_prot_err_svrity          <= #TP err_reg_id[3] & err_write_pulse[0] ? lbc_cdm_data[4]  : int_dl_prot_err_svrity;

        int_surprise_down_err_svrity    <= #TP !cfg_pcie_surp_dn_rpt_cap ? 1'b1 : err_reg_id[3] & err_write_pulse[0] ? lbc_cdm_data[5]  : int_surprise_down_err_svrity;
        int_rx_tlp_poisoned_svrity      <= #TP err_reg_id[3] & err_write_pulse[1] ? lbc_cdm_data[12] : int_rx_tlp_poisoned_svrity;
        int_rx_fc_prot_err_svrity       <= #TP err_reg_id[3] & err_write_pulse[1] ? lbc_cdm_data[13] : int_rx_fc_prot_err_svrity;
        int_cpl_timeout_svrity          <= #TP err_reg_id[3] & err_write_pulse[1] ? lbc_cdm_data[14] : int_cpl_timeout_svrity;
        int_rcvd_req_ca_err_svrity      <= #TP err_reg_id[3] & err_write_pulse[1] ? lbc_cdm_data[15] : int_rcvd_req_ca_err_svrity;
        int_unexp_tx_cpl_svrity         <= #TP err_reg_id[3] & err_write_pulse[2] ? lbc_cdm_data[16] : int_unexp_tx_cpl_svrity;
        int_rx_overfl_svrity            <= #TP err_reg_id[3] & err_write_pulse[2] ? lbc_cdm_data[17] : int_rx_overfl_svrity;
        int_rx_mlf_tlp_svrity           <= #TP err_reg_id[3] & err_write_pulse[2] ? lbc_cdm_data[18] : int_rx_mlf_tlp_svrity;
        int_rx_ecrc_err_svrity          <= #TP (`DEFAULT_ECRC_CHK_CAP==1) & err_reg_id[3] & err_write_pulse[2] ? lbc_cdm_data[19] : int_rx_ecrc_err_svrity;
        int_rcvd_req_ur_err_svrity      <= #TP err_reg_id[3] & err_write_pulse[2] ? lbc_cdm_data[20] : int_rcvd_req_ur_err_svrity;
        int_acs_violation_svrity        <= #TP acs_viol_svrity_mask_wr_en ? err_reg_id[3] & err_write_pulse[2] ? lbc_cdm_data[21] : int_acs_violation_svrity : 1'b0;
        int_internal_err_svrity         <= #TP err_reg_id[3] & err_write_pulse[2] ? lbc_cdm_data[22] : int_internal_err_svrity;
        // For uncorrectable error severity registers,  Register fields for bits not implemented by the Function are
        // hardwired to an implementation specific value. AtomicOP routing is applicable to root and switch ports.
            if (rc_device || switch_device) 
            begin        
                int_atomic_egress_blk_svrity <= #TP err_reg_id[3] & err_write_pulse[3] ? lbc_cdm_data[24] : int_atomic_egress_blk_svrity;
            end
            else
            begin
                int_atomic_egress_blk_svrity <= #TP 0;
            end        
        // Applicable to functions that enable End-End TLP which are root and switch ports.
            if (rc_device || switch_device) 
            begin        
                int_tlp_prfx_blocked_err_svrity <= #TP err_reg_id[3] & err_write_pulse[3] ? lbc_cdm_data[25] : int_tlp_prfx_blocked_err_svrity;
            end
            else
            begin
                int_tlp_prfx_blocked_err_svrity <= #TP 0;
            end
        int_psnd_tlp_egrss_blckd_err_svrity <= #TP upstream_port ? 1'b0 :
                                                   (err_reg_id[3] & err_write_pulse[3]) ? lbc_cdm_data[26] : int_psnd_tlp_egrss_blckd_err_svrity;
        if (rc_device || switch_device) 
            begin        
                int_tlp_trans_egress_blk_svrity <= #TP err_reg_id[3] & err_write_pulse[3] ? lbc_cdm_data[31] : int_tlp_trans_egress_blk_svrity;
            end
            else
            begin
                int_tlp_trans_egress_blk_svrity <= #TP 0;
            end      

    end
end

always @(*)
begin
    // VFs only implement a subset of the severity bits. Implemented bits inherit settings from PF
    dl_prot_err_svrity          = VF_IMPL ? 1'b0                         : int_dl_prot_err_svrity;
    surprise_down_err_svrity    = VF_IMPL ? 1'b0                         : int_surprise_down_err_svrity;
    rx_tlp_poisoned_svrity      = VF_IMPL ? pf_cfg_aer_uncorr_svrity[12] : int_rx_tlp_poisoned_svrity;
    rx_fc_prot_err_svrity       = VF_IMPL ? 1'b0                         : int_rx_fc_prot_err_svrity;
    cpl_timeout_svrity          = VF_IMPL ? pf_cfg_aer_uncorr_svrity[14] : int_cpl_timeout_svrity;
    rcvd_req_ca_err_svrity      = VF_IMPL ? pf_cfg_aer_uncorr_svrity[15] : int_rcvd_req_ca_err_svrity;
    unexp_tx_cpl_svrity         = VF_IMPL ? pf_cfg_aer_uncorr_svrity[16] : int_unexp_tx_cpl_svrity;
    rx_overfl_svrity            = VF_IMPL ? 1'b0                         : int_rx_overfl_svrity;
    rx_mlf_tlp_svrity           = VF_IMPL ? 1'b0                         : int_rx_mlf_tlp_svrity;
    rx_ecrc_err_svrity          = VF_IMPL ? 1'b0                         :  int_rx_ecrc_err_svrity ;
    rcvd_req_ur_err_svrity      = VF_IMPL ? pf_cfg_aer_uncorr_svrity[20] : int_rcvd_req_ur_err_svrity;
    atomic_egress_blk_svrity    = VF_IMPL ? 1'b0                         : int_atomic_egress_blk_svrity;
    tlp_prfx_blocked_err_svrity = VF_IMPL ? 1'b0                         : int_tlp_prfx_blocked_err_svrity;
    psnd_tlp_egrss_blckd_err_svrity = VF_IMPL ? 1'b0                     : int_psnd_tlp_egrss_blckd_err_svrity;
    tlp_trans_egress_blk_svrity_temp = VF_IMPL ? 1'b0                         : int_tlp_trans_egress_blk_svrity;
    internal_err_svrity         = VF_IMPL ? 1'b0                         : int_internal_err_svrity;
    acs_violation_svrity        = VF_IMPL ? pf_cfg_aer_uncorr_svrity[21] : int_acs_violation_svrity;
end


// -----------------------------------------------------------------------------
// Correctable Error Status Register
// ecfig_reg_id     - 4
// PCIE Offset      - `AER_PTR + 10h
// length           - 4 byte
// default value    - 0h
// Cfig register    - ecfg_reg_19, ecfg_reg_18, ecfg_reg_17, ecfg_reg_16
// -----------------------------------------------------------------------------
wire cfg_corrected_internal_err_sts;
wire cfg_replay_number_rollover_err_sts;
wire cfg_replay_timer_timeout_err_sts;
wire cfg_bad_dllp_err_sts;
wire cfg_bad_tlp_err_sts;
wire cfg_rcvr_err_sts;
assign cfg_corrected_internal_err_sts     = corr_internal_err_sts;
assign cfg_replay_number_rollover_err_sts = replay_num_rlover_sts;
assign cfg_replay_timer_timeout_err_sts   = replay_timeout_sts;
assign cfg_bad_dllp_err_sts               = bad_dllp_sts;
assign cfg_bad_tlp_err_sts                = bad_tlp_sts;
assign cfg_rcvr_err_sts                   = rx_err_sts;

assign ecfg_reg_16 = {bad_dllp_sts, bad_tlp_sts, 5'b0, rx_err_sts};
assign ecfg_reg_17 = {hdr_log_overflow_sts, corr_internal_err_sts, advisory_nf_sts, replay_timeout_sts, 3'b0, replay_num_rlover_sts};
assign ecfg_reg_18 = 8'b0;
assign ecfg_reg_19 = 8'b0;

always @(posedge core_clk or negedge sticky_rst_n)
    if (!sticky_rst_n) begin
        rx_err_sts              <= #TP 1'b0;
        bad_tlp_sts             <= #TP 1'b0;
        bad_dllp_sts            <= #TP 1'b0;
        replay_num_rlover_sts   <= #TP 1'b0;
        replay_timeout_sts      <= #TP 1'b0;
        advisory_nf_sts         <= #TP 1'b0;
        corr_internal_err_sts   <= #TP 1'b0;
    end else begin
        rx_err_sts              <= #TP int_rmlh_rcvd_err                                        ? 1'b1
                                        :(err_reg_id[4] & err_write_pulse[0] & lbc_cdm_data[0]) ? 1'b0
                                        : rx_err_sts;
        bad_tlp_sts             <= #TP int_rdlh_bad_tlp_err                                     ? 1'b1
                                        :(err_reg_id[4] & err_write_pulse[0] & lbc_cdm_data[6]) ? 1'b0
                                        : bad_tlp_sts;
        bad_dllp_sts            <= #TP int_rdlh_bad_dllp_err                                    ? 1'b1
                                        :(err_reg_id[4] & err_write_pulse[0] & lbc_cdm_data[7]) ? 1'b0
                                        : bad_dllp_sts;
        replay_num_rlover_sts   <= #TP int_xdlh_replay_num_rlover_err                           ? 1'b1
                                        :(err_reg_id[4] & err_write_pulse[1] & lbc_cdm_data[8]) ? 1'b0
                                        : replay_num_rlover_sts;
        replay_timeout_sts      <= #TP int_xdlh_replay_timeout_err                              ? 1'b1
                                        :(err_reg_id[4] & err_write_pulse[1] & lbc_cdm_data[12])? 1'b0
                                        : replay_timeout_sts;
                                        advisory_nf_sts <= #TP int_advisory_nf_err | app_advisory_nf_err ? 1'b1
                                        :(err_reg_id[4] & err_write_pulse[1] & lbc_cdm_data[13])? 1'b0
                                        : advisory_nf_sts;
        corr_internal_err_sts   <= #TP int_corr_internal_err ? 1'b1
                                        : err_reg_id[4] & err_write_pulse[1] & lbc_cdm_data[14] ? 1'b0
                                        : corr_internal_err_sts;
        if( VF_IMPL ) begin
            // VFs only implement a subset of the status bits. Implemented bits correspond to commented lines below.
            rx_err_sts              <= #TP 1'b0;
            bad_tlp_sts             <= #TP 1'b0;
            bad_dllp_sts            <= #TP 1'b0;
            replay_num_rlover_sts   <= #TP 1'b0;
            replay_timeout_sts      <= #TP 1'b0;
            //advisory_nf_sts         <= #TP 1'b0;
            corr_internal_err_sts   <= #TP 1'b0;
        end
    end

// -----------------------------------------------------------------------------
// Correctable Error Mask Register
// ecfig_reg_id     - 5
// PCIE Offset      - `AER_PTR + 14h
// length           - 4 byte
// default value    - 0h
// Cfig register    - ecfg_reg_23, ecfg_reg_22, ecfg_reg_21, ecfg_reg_20
// -----------------------------------------------------------------------------
assign ecfg_reg_20 = VF_IMPL ? 8'b0 : {bad_dllp_mask, bad_tlp_mask, 5'b0, rx_err_mask};
assign ecfg_reg_21 = VF_IMPL ? {hdr_log_overflow_mask, 7'b0} : 
                     {hdr_log_overflow_mask, corr_internal_err_mask, advisory_nf_mask, replay_timeout_mask, 3'b0, replay_num_rlover_mask};
assign ecfg_reg_22 = 8'b0;
assign ecfg_reg_23 = 8'b0;

assign cfg_aer_corr_mask = {ecfg_reg_23, ecfg_reg_22, ecfg_reg_21, ecfg_reg_20};

reg int_rx_err_mask;
reg int_bad_tlp_mask;
reg int_bad_dllp_mask;
reg int_replay_num_rlover_mask;
reg int_replay_timeout_mask;
reg int_advisory_nf_mask;
reg int_corr_internal_err_mask;
reg int_hdr_log_overflow_mask;        //Header Log Overflow Mask


always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        int_rx_err_mask             <= #TP 1'b0;
        int_bad_tlp_mask            <= #TP 1'b0;
        int_bad_dllp_mask           <= #TP 1'b0;
        int_replay_num_rlover_mask  <= #TP 1'b0;
        int_replay_timeout_mask     <= #TP 1'b0;
        int_advisory_nf_mask        <= #TP 1'b1;
        int_corr_internal_err_mask  <= #TP 1'b1;
        int_hdr_log_overflow_mask   <= #TP 1'b1;      //defaults to Masked
        
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        // Receiver Error mask
        int_rx_err_mask             <= #TP (err_reg_id[5] & err_write_pulse[0]) ? lbc_cdm_data[0] : int_rx_err_mask;
        // Bad TLP mask
        int_bad_tlp_mask            <= #TP (err_reg_id[5] & err_write_pulse[0]) ? lbc_cdm_data[6] : int_bad_tlp_mask;
        // Bad DLLP mask
        int_bad_dllp_mask           <= #TP (err_reg_id[5] & err_write_pulse[0]) ? lbc_cdm_data[7] : int_bad_dllp_mask;
        // REPLAY NUM Rollover mask
        int_replay_num_rlover_mask  <= #TP (err_reg_id[5] & err_write_pulse[1]) ? lbc_cdm_data[8] : int_replay_num_rlover_mask;
        // Replay Timer Timeout mask
        int_replay_timeout_mask     <= #TP (err_reg_id[5] & err_write_pulse[1]) ? lbc_cdm_data[12]: int_replay_timeout_mask;
        // Advisory Non-Fatal Eror mask
        int_advisory_nf_mask        <= #TP (err_reg_id[5] & err_write_pulse[1]) ? lbc_cdm_data[13]: int_advisory_nf_mask;
        int_corr_internal_err_mask  <= #TP (err_reg_id[5] & err_write_pulse[1]) ? lbc_cdm_data[14] : int_corr_internal_err_mask;
        int_hdr_log_overflow_mask   <= #TP (err_reg_id[5] & err_write_pulse[1]) ? lbc_cdm_data[15] : int_hdr_log_overflow_mask;

    end
end

always @(*)
begin
    // VFs only implement a subset of the mask bits. Implemented bits inherit settings from PF
    // Note: this is slightly different from sriov spec 1.0, table 4-5, because in our interpretation this table is incorrect
    rx_err_mask             = VF_IMPL ? 1'b0                     : int_rx_err_mask;
    bad_tlp_mask            = VF_IMPL ? 1'b0                     : int_bad_tlp_mask;
    bad_dllp_mask           = VF_IMPL ? 1'b0                     : int_bad_dllp_mask;
    replay_num_rlover_mask  = VF_IMPL ? 1'b0                     : int_replay_num_rlover_mask;
    replay_timeout_mask     = VF_IMPL ? 1'b0                     : int_replay_timeout_mask;
    advisory_nf_mask        = VF_IMPL ? pf_cfg_aer_corr_mask[13] : int_advisory_nf_mask;
    corr_internal_err_mask  = VF_IMPL ? 1'b0                     : int_corr_internal_err_mask;
    hdr_log_overflow_mask   = VF_IMPL_VF_HDR_LOG_SHARED ? 1'b0 : int_hdr_log_overflow_mask;      // both PF and VF implement this value
 
end

// -----------------------------------------------------------------------------
// Advanced Error Capabilities and Control Register
// ecfig_reg_id     - 6
// PCIE Offset      - `AER_PTR + 18h
// length           - 4 byte
// default value    - 0h
// Cfig register    - ecfg_reg_27, ecfg_reg_26, ecfg_reg_25, ecfg_reg_24
// -----------------------------------------------------------------------------

// Completion Timeout Prefix/Header Log Capable bit field (bit 12) 
wire       cfg_cto_prfx_hdr_log_cap;
assign cfg_cto_prfx_hdr_log_cap = 1'b0;

wire       cfg_tlp_prfx_log_present; // TLP Prefix Log present indication
wire  [3:0] cfg_aer_ecrc_cap_ctrl;   // ecrc capability and control register out, used to export PF setting to VFs

// VFs inherit all ECRC settings from PF
assign cfg_aer_ecrc_cap_ctrl = VF_IMPL ? 4'b0000 : 
                                         {int_ecrc_chk_en, int_ecrc_chk_cap_d, int_ecrc_gen_en, int_ecrc_gen_cap};

wire [4:0] hdr_log_size;
assign hdr_log_size = 5'b0+HDR_SIZE_DW;

assign {ecfg_reg_27, ecfg_reg_26, ecfg_reg_25, ecfg_reg_24} = {8'b0,
                                                               {{5-HDR_LOG_SIZE_WD{1'b0}},size_pointer_q},
                                                               fm_pointer_q,
                                                               hdr_log_size,
                                                               cfg_cto_prfx_hdr_log_cap,
                                                               cfg_tlp_prfx_log_present, 
                                                               multi_hdr_rec_en,             //Multi Header Recording Enabled bit
                                                               multi_hdr_rec_cap, 
                                                               cfg_aer_ecrc_cap_ctrl[3:0], 
                                                               fe_pointer[4:0]};

// The ECRC Generation and Checking enable has to be ANDed with core's capability.
assign ecrc_gen_en = AER_CAP_ENABLE ? &cfg_aer_ecrc_cap_ctrl[1:0] : 1'b0;
assign ecrc_chk_en = AER_CAP_ENABLE ? &cfg_aer_ecrc_cap_ctrl[3:2] : 1'b0;

// For TLP Prefix capability, TLP Prefix Log is valid
// when Header and Prefix Logs are updated. This is indicated by TLP Prefix
// Log Present bit. Cleared when There is no Log in the Logs Registers/RAM (they are clear)
wire cfg_tlp_prfx_log_pres_s;


assign cfg_tlp_prfx_log_pres_s = (AER_CAP_ENABLE && (fe_pointer_q>0))?
                                                              (fm_pointer_q? 1'b0                    : ((elq[rd_ptr][0*32+:32 ] == 'h0)?1'b0:1'b1) //CX_HDR_LOG_IN_RAM
                                                              ): 1'b0 ;

assign cfg_tlp_prfx_log_present = cfg_tlp_prfx_log_pres_s;



generate
if(VF_IMPL_VF_HDR_LOG_SHARED==0) begin : gen_multi_hdr_rec

  reg multi_hdr_rec_en_reg;                 //Multiple Header Recording Enable
  reg multi_hdr_rec_en_d;

  
  always @(posedge cdm_clk_g or negedge sticky_rst_n)
  begin
      if (!sticky_rst_n) begin
        multi_hdr_rec_en_reg  <= #TP 1'b0;         
  
      end else begin          
        multi_hdr_rec_en_reg <= #TP (ELQ_MAX_DEPTH < 2 )                  ? 1'b0              : //non capable permitted to hardwire to 0
                                    (err_reg_id[6] & err_write_pulse[1])  ? lbc_cdm_data[10]  : multi_hdr_rec_en_reg;
  
      end
  end

  assign multi_hdr_rec_en   = multi_hdr_rec_en_reg; 
  assign multi_hdr_rec_cap  = (ELQ_MAX_DEPTH > 1 ) ? 1'b1 : 1'b0;


  always @(posedge cdm_clk_g or negedge sticky_rst_n)
  begin
      if (!sticky_rst_n) begin
        multi_hdr_rec_en_d  <= #TP 1'b0;         
  
      end else begin          
        multi_hdr_rec_en_d <= #TP multi_hdr_rec_en;
  
      end
  end

  assign multi_hdr_rec_en_change = multi_hdr_rec_en!=multi_hdr_rec_en_d;    //indicates that multiple header enable bit has changed

end else begin : gen_multi_hdr_rec // VF_IMPL_VF_HDR_LOG_SHARED != 0
  assign multi_hdr_rec_en         = 1'b0; 
  assign multi_hdr_rec_cap        = 1'b0;
  assign multi_hdr_rec_en_change  = 1'b0;
end // gen_multi_hdr_rec

endgenerate // VF_IMPL_VF_HDR_LOG_SHARED==0


// The fe_pointer (First Error Pointer) register points to the unmasked uncorrectable
// error that occurred first. The fe_pointer register remains valid until all of
// the Uncorrectable Error register bits are cleared. The fe_pointer must clear when
// all the corresponding bits in the uncorrectable error status registers are cleared.
assign status_err_reg_clear = ({ecfg_reg_4, ecfg_reg_5, ecfg_reg_6, ecfg_reg_7} == 0);

assign fe_ptr_valid         =                              !(fe_pointer<=30 && fe_pointer>=28) && 
                              !(fe_pointer<=11 && fe_pointer>=6) && 
                              !(fe_pointer<=3);


always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        int_ecrc_gen_en  <= #TP 1'b0;
        int_ecrc_chk_en  <= #TP 1'b0;
        int_ecrc_gen_cap <= #TP `DEFAULT_ECRC_GEN_CAP;
        int_ecrc_chk_cap <= #TP `DEFAULT_ECRC_CHK_CAP;
    end else begin

        int_ecrc_gen_en  <= #TP (err_reg_id[6] & err_write_pulse[0]) ? lbc_cdm_data[6] : int_ecrc_gen_en;
        int_ecrc_chk_en  <= #TP (err_reg_id[6] & err_write_pulse[1]) ? lbc_cdm_data[8] : int_ecrc_chk_en;
        int_ecrc_gen_cap <= #TP (int_lbc_cdm_dbi & err_reg_id[6] & err_write_pulse[0]) ? lbc_cdm_data[5] : int_ecrc_gen_cap;
        int_ecrc_chk_cap <= #TP (int_lbc_cdm_dbi & err_reg_id[6] & err_write_pulse[0]) ? lbc_cdm_data[7] : int_ecrc_chk_cap;

   end
end

DWC_pcie_ctl_bcm36_nhs
 #(
  .WIDTH      ($bits(int_ecrc_chk_cap)),
  .DATA_DELAY (DATA_DELAY_BCM36_NHS)
) u_bcm36_nhs_ecrc_chk_cap (
`ifndef SYNTHESIS
  .clk_d   (core_clk),
  .rst_d_n (sticky_rst_n),
`endif // SYNTHESIS
  .data_s  (int_ecrc_chk_cap),
  .data_d  (int_ecrc_chk_cap_d)
);


  generate
    if(VF_IMPL_VF_HDR_LOG_SHARED==0) begin : gen_fe_pointer

//Leda is not failing when depths are equivalent for all funcitons
//
// LMD: Undriven net Range
// LJ: All nets are driven
// leda NTL_CON12 off

      if(ELQ_MAX_DEPTH>1) begin : gen_fe_pointer_assign

            // FE Pointer is at the most significant 5 bits of the log
           //needs to take Prefix into account, ERROR_TLP_WD not relevant at Q output
           assign fe_pointer_q = ((multi_hdr_rec_en & (elq_depth == 0)) | (!multi_hdr_rec_en & single_Q_empty))  ? 5'b0  :
 elq[rd_ptr][(ELQ_WIDTH-FEPTR_SIZE)+:FEPTR_SIZE];
           assign fm_pointer_q = ((multi_hdr_rec_en & (elq_depth == 0)) | (!multi_hdr_rec_en & single_Q_empty))  ? 1'b0  :
 elq[rd_ptr][(TLP_SIZE+HDR_LOG_SIZE_WD)+:1];
           assign size_pointer_q = ((multi_hdr_rec_en & (elq_depth == 0)) | (!multi_hdr_rec_en & single_Q_empty))  ? {HDR_LOG_SIZE_WD{1'b0}}  :
 elq[rd_ptr][(TLP_SIZE)+:HDR_LOG_SIZE_WD];

      end else begin : gen_fe_pointer_assign // ELQ_MAX_DEPTH == 1       
          assign fe_pointer_q = Q_empty                                                                         ? 5'b0  : 
                              elq[0][(ELQ_WIDTH-FEPTR_SIZE)+:FEPTR_SIZE];
          assign fm_pointer_q = Q_empty                                                                         ? 1'b0  : 
                              elq[0][(TLP_SIZE+HDR_LOG_SIZE_WD)+:1];
          assign size_pointer_q = Q_empty                                                                       ? {HDR_LOG_SIZE_WD{1'b0}}  : 
                              elq[0][(TLP_SIZE)+:HDR_LOG_SIZE_WD];
      end

// leda NTL_CON12 on



          assign Q_fe_ptr[4:0] = 
                              (int_internal_err       & !internal_err_mask                                                            ) ? 5'h16
                              : (int_radm_mlf_tlp_err[0]       & !rx_mlf_tlp_mask                                                         ) ? 5'h12
                            // fatal errors that could've been advisory
                              : (valid_ecrc_err[0]         & !rx_ecrc_err_mask          & rx_ecrc_err_svrity                          ) ? 5'h13
                              : (rtlh_poisoned_err[0]      & !rx_tlp_poisoned_mask      & rx_tlp_poisoned_svrity                      ) ? 5'hC
                              : (int_radm_rcvd_req_ur[0]   & !tx_unsupt_req_err_mask    & rcvd_req_ur_err_svrity                      ) ? 5'h14
                              : (int_radm_rcvd_req_ca[0]       & !cpl_tx_abort_mask         & rcvd_req_ca_err_svrity                      ) ? 5'hF
                              : (int_radm_atomic_egress_blk    & !tx_atomic_egress_blk_mask & atomic_egress_blk_svrity                    ) ? 5'h18
                              : (int_tlp_prfx_blocked_err   & !tlp_prfx_blocked_err_mask & tlp_prfx_blocked_err_svrity                ) ? 5'h19    // TLP Prefix Blocked Error is
                                                                                                                                                  // bit 25 of uncorrectable error register
                              : (int_psnd_tlp_egrss_blckd_err & !psnd_tlp_egrss_blckd_err_mask & psnd_tlp_egrss_blckd_err_svrity      ) ? 5'h1A    // Poisoned TLP Egress Blocked Error is bit 26 of uncorrectable error register
                              : (int_tlp_trans_egress_blk      & !tlp_trans_egress_blk_mask_temp      & tlp_trans_egress_blk_svrity_temp            ) ? 5'h1F
                              : (int_radm_acs_violation[0]     & !acs_violation_mask        & acs_violation_svrity                        ) ? 5'h15
                              : (int_radm_unexp_cpl_err[0]     & !unexp_tx_cpl_mask         & unexp_tx_cpl_svrity                         ) ? 5'h10


                            // non-advisory non-fatal errors
                              : (valid_ecrc_err[0]         & !rx_ecrc_err_mask          & !rx_ecrc_err_svrity       & !int_err_advisory[0] ) ? 5'h13
                              : (rtlh_poisoned_err[0]      & !rx_tlp_poisoned_mask      & !rx_tlp_poisoned_svrity   & !int_err_advisory[0] ) ? 5'hC
                              : (int_radm_rcvd_req_ur[0]   & !tx_unsupt_req_err_mask    & !rcvd_req_ur_err_svrity   & !int_err_advisory[0] ) ? 5'h14
                              : (int_radm_rcvd_req_ca[0]       & !cpl_tx_abort_mask         & !rcvd_req_ca_err_svrity   & !int_err_advisory[0] ) ? 5'hF
                                // TLP Prefix Blocked Error is  bit 25 of uncorrectable error register
                              : (int_tlp_prfx_blocked_err   & !tlp_prfx_blocked_err_mask & !tlp_prfx_blocked_err_svrity & !int_err_advisory[0] ) ? 5'h19

                              : (int_psnd_tlp_egrss_blckd_err & !psnd_tlp_egrss_blckd_err_mask & !psnd_tlp_egrss_blckd_err_svrity & !int_err_advisory[0] ) ? 5'h1A
                              : (int_radm_acs_violation[0]     & !acs_violation_mask        & !acs_violation_svrity     & !int_err_advisory[0] ) ? 5'h15


                            // advisory non-fatal errors
                              : (valid_ecrc_err[0]         & !rx_ecrc_err_mask          & !rx_ecrc_err_svrity       & int_err_advisory[0] & !advisory_nf_mask ) ? 5'h13
                              : (rtlh_poisoned_err[0]      & !rx_tlp_poisoned_mask      & !rx_tlp_poisoned_svrity   & int_err_advisory[0] & !advisory_nf_mask ) ? 5'hC
                              : (int_radm_rcvd_req_ur[0]   & !tx_unsupt_req_err_mask    & !rcvd_req_ur_err_svrity   & int_err_advisory[0] & !advisory_nf_mask ) ? 5'h14
                              : (int_radm_rcvd_req_ca[0]       & !cpl_tx_abort_mask         & !rcvd_req_ca_err_svrity   & int_err_advisory[0] & !advisory_nf_mask ) ? 5'hF

                                // TLP Prefix Blocked Error is  bit 25 of uncorrectable error register
                              : (int_tlp_prfx_blocked_err  & !tlp_prfx_blocked_err_mask & !tlp_prfx_blocked_err_svrity & int_err_advisory[0] & !advisory_nf_mask ) ? 5'h19

                              : (int_psnd_tlp_egrss_blckd_err & !psnd_tlp_egrss_blckd_err_mask & !psnd_tlp_egrss_blckd_err_svrity & int_err_advisory[0] & !advisory_nf_mask ) ? 5'h1A
                              : (int_tlp_trans_egress_blk      & !tlp_trans_egress_blk_mask_temp      & !tlp_trans_egress_blk_svrity_temp   & !advisory_nf_mask ) ? 5'h1F
                              : (int_radm_atomic_egress_blk    & !tx_atomic_egress_blk_mask & !atomic_egress_blk_svrity & !advisory_nf_mask ) ? 5'h18
                              : (int_radm_acs_violation[0]     & !acs_violation_mask        & !acs_violation_svrity     & int_err_advisory[0] & !advisory_nf_mask ) ? 5'h15
                              : (int_radm_unexp_cpl_err[0]     & !unexp_tx_cpl_mask         & !unexp_tx_cpl_svrity      & !advisory_nf_mask ) ? 5'h10

                              : 5'h0;
                              

                              //end of Q_fe_ptr

// -----------------------------------------------------------------------------
// Header Log Register
// ecfig_reg_id     - 7-10
// PCIE Offset      - `AER_PTR + 1Ch
// length           - 16 byte
// default value    - 0h
// Cfig register    - ecfg_reg_43 ... ecfg_reg_28
// -----------------------------------------------------------------------------

assign logged_error[0] = ((int_radm_mlf_tlp_err[0]       & !rx_mlf_tlp_mask                                                              ) |
                // fatal errors that could've been advisory
                          (valid_ecrc_err[0]             & !rx_ecrc_err_mask      & rx_ecrc_err_svrity                               ) |
                          (rtlh_poisoned_err[0]      & !rx_tlp_poisoned_mask      & rx_tlp_poisoned_svrity                           ) |
                          (int_radm_acs_violation[0]     & !acs_violation_mask        & acs_violation_svrity                             ) |
                          (int_radm_rcvd_req_ur[0]   & !tx_unsupt_req_err_mask    & rcvd_req_ur_err_svrity                           ) |
                          (int_radm_rcvd_req_ca[0]       & !cpl_tx_abort_mask         & rcvd_req_ca_err_svrity                           ) |
                          (int_tlp_prfx_blocked_err  & !tlp_prfx_blocked_err_mask & tlp_prfx_blocked_err_svrity                      ) |
                          (int_psnd_tlp_egrss_blckd_err & !psnd_tlp_egrss_blckd_err_mask & psnd_tlp_egrss_blckd_err_svrity            ) |
                          (int_tlp_trans_egress_blk      & !tlp_trans_egress_blk_mask_temp      & tlp_trans_egress_blk_svrity_temp                 ) |
                          (int_radm_atomic_egress_blk    & !tx_atomic_egress_blk_mask & atomic_egress_blk_svrity                         ) |
                          (int_radm_unexp_cpl_err[0]     & !unexp_tx_cpl_mask         & unexp_tx_cpl_svrity                              ) |
                // non-advisory non-fatal errors
                          (valid_ecrc_err[0]             & !rx_ecrc_err_mask      & !rx_ecrc_err_svrity       & !int_err_advisory[0] ) |
                          (rtlh_poisoned_err[0]      & !rx_tlp_poisoned_mask      & !rx_tlp_poisoned_svrity   & !int_err_advisory[0] ) |
                          (int_radm_acs_violation[0]     & !acs_violation_mask        & !acs_violation_svrity     & !int_err_advisory[0] ) |
                          (int_radm_rcvd_req_ur[0]   & !tx_unsupt_req_err_mask    & !rcvd_req_ur_err_svrity   & !int_err_advisory[0] ) |
                          (int_radm_rcvd_req_ca[0]       & !cpl_tx_abort_mask         & !rcvd_req_ca_err_svrity   & !int_err_advisory[0] ) |
                          (int_tlp_prfx_blocked_err  & !tlp_prfx_blocked_err_mask & !tlp_prfx_blocked_err_svrity & !int_err_advisory[0] ) |
                          (int_psnd_tlp_egrss_blckd_err & !psnd_tlp_egrss_blckd_err_mask & !psnd_tlp_egrss_blckd_err_svrity & !int_err_advisory[0] ) |
                // advisory non-fatal errors
                          (valid_ecrc_err[0]         & !rx_ecrc_err_mask          & !rx_ecrc_err_svrity       & int_err_advisory[0] & !advisory_nf_mask ) |
                          (rtlh_poisoned_err[0]      & !rx_tlp_poisoned_mask      & !rx_tlp_poisoned_svrity   & int_err_advisory[0] & !advisory_nf_mask ) |
                          (int_radm_acs_violation[0]     & !acs_violation_mask        & !acs_violation_svrity     & int_err_advisory[0] & !advisory_nf_mask ) |
                          (int_radm_rcvd_req_ur[0]   & !tx_unsupt_req_err_mask    & !rcvd_req_ur_err_svrity   & int_err_advisory[0] & !advisory_nf_mask ) |
                          (int_radm_rcvd_req_ca[0]       & !cpl_tx_abort_mask         & !rcvd_req_ca_err_svrity   & int_err_advisory[0] & !advisory_nf_mask ) |
                          (int_tlp_prfx_blocked_err  & !tlp_prfx_blocked_err_mask & !tlp_prfx_blocked_err_svrity & int_err_advisory[0] & !advisory_nf_mask ) |
                          (int_psnd_tlp_egrss_blckd_err & !psnd_tlp_egrss_blckd_err_mask & !psnd_tlp_egrss_blckd_err_svrity & !int_err_advisory[0] & !advisory_nf_mask ) |
                          (int_tlp_trans_egress_blk      & !tlp_trans_egress_blk_mask_temp      & !tlp_trans_egress_blk_svrity_temp   & !advisory_nf_mask ) |
                          (int_radm_atomic_egress_blk    & !tx_atomic_egress_blk_mask & !atomic_egress_blk_svrity & !advisory_nf_mask ) |
                          (int_radm_unexp_cpl_err[0]     & !unexp_tx_cpl_mask         & !unexp_tx_cpl_svrity      & !advisory_nf_mask ));


 // spyglass disable_block W468
 // SMD: Variable/signal which cannot index the full range of this vector.
 // SJ: It is expected that 'hdr_dw0_index' only points to the first part of 'hdrlog_ram_ctrl_data_in'. 
  

  if(ELQ_MAX_DEPTH>1) begin : gen_fe_pointer_ecfg_regs_ms
        assign {ecfg_reg_31, ecfg_reg_30, ecfg_reg_29, ecfg_reg_28} = (AER_CAP_ENABLE && (fe_pointer_q>0))  ? 

                              (fm_pointer_q?             elq[rd_ptr][0*32+:32] :             elq[rd_ptr][((0*32)+MAX_END2END_TLP_PRFXS_VALUE*32)+:32])                              : 32'h0;
        assign {ecfg_reg_35, ecfg_reg_34, ecfg_reg_33, ecfg_reg_32} = (AER_CAP_ENABLE && (fe_pointer_q>0))  ?

                              (fm_pointer_q?             elq[rd_ptr][1*32+:32] :             elq[rd_ptr][((1*32)+MAX_END2END_TLP_PRFXS_VALUE*32)+:32])                              : 32'h0;
        assign {ecfg_reg_39, ecfg_reg_38, ecfg_reg_37, ecfg_reg_36} = (AER_CAP_ENABLE && (fe_pointer_q>0))  ?

                              (fm_pointer_q?             elq[rd_ptr][2*32+:32] :             elq[rd_ptr][((2*32)+MAX_END2END_TLP_PRFXS_VALUE*32)+:32])                              : 32'h0;
        assign {ecfg_reg_43, ecfg_reg_42, ecfg_reg_41, ecfg_reg_40} = (AER_CAP_ENABLE && (fe_pointer_q>0))  ?

                              (fm_pointer_q?             elq[rd_ptr][3*32+:32] :             elq[rd_ptr][((3*32)+MAX_END2END_TLP_PRFXS_VALUE*32)+:32])                              : 32'h0;

  end else begin : gen_fe_pointer_q_ecfg_regs_ms // ELQ_MAX_DEPTH==1
        assign {ecfg_reg_31, ecfg_reg_30, ecfg_reg_29, ecfg_reg_28} = (AER_CAP_ENABLE && (fe_pointer_q>0))  ?
                                 (fm_pointer_q?             elq[0][0*32+:32] : elq[0][((0*32)+MAX_END2END_TLP_PRFXS_VALUE*32)+:32])  : 32'h0;
  
        assign {ecfg_reg_35, ecfg_reg_34, ecfg_reg_33, ecfg_reg_32} = (AER_CAP_ENABLE && (fe_pointer_q>0))  ?
                                 (fm_pointer_q?             elq[0][1*32+:32] : elq[0][((1*32)+MAX_END2END_TLP_PRFXS_VALUE*32)+:32])  : 32'h0;
  
        assign {ecfg_reg_39, ecfg_reg_38, ecfg_reg_37, ecfg_reg_36} = (AER_CAP_ENABLE && (fe_pointer_q>0))  ?
                                 (fm_pointer_q?             elq[0][2*32+:32] : elq[0][((2*32)+MAX_END2END_TLP_PRFXS_VALUE*32)+:32])  : 32'h0;
  
        assign {ecfg_reg_43, ecfg_reg_42, ecfg_reg_41, ecfg_reg_40} = (AER_CAP_ENABLE && (fe_pointer_q>0))  ?
                                 (fm_pointer_q?             elq[0][3*32+:32] : elq[0][((3*32)+MAX_END2END_TLP_PRFXS_VALUE*32)+:32])  : 32'h0;
  
  end // ELQ_MAX_DEPTH
  // spyglass enable_block W468



end else begin : gen_fe_pointer //VF_IMPL_VF_HDR_LOG_SHARED

        assign logged_error = {ERROR_TLP_WD{1'b0}};

        assign hdr_log_overflow_sts = 1'b0;

        assign fe_pointer = 5'b0;

        assign {ecfg_reg_28, ecfg_reg_29, ecfg_reg_30, ecfg_reg_31} = 32'h0;
  
        assign {ecfg_reg_32, ecfg_reg_33, ecfg_reg_34, ecfg_reg_35} = 32'h0;
  
        assign {ecfg_reg_36, ecfg_reg_37, ecfg_reg_38, ecfg_reg_39} = 32'h0;
  
        assign {ecfg_reg_40, ecfg_reg_41, ecfg_reg_42, ecfg_reg_43} = 32'h0;

end // gen_fe_pointer 
endgenerate


// -----------------------------------------------------------------------------
// Root Error Command Register
// ecfig_reg_id     - 11
// PCIE Offset      - `AER_PTR + 2Ch
// length           - 4 bytes
// default value    - 0h
// Cfig register    - ecfg_reg_44 - ecfg_reg_47
// -----------------------------------------------------------------------------

reg     rc_fatal_err_en;
reg     rc_nonfatal_err_en;
reg     rc_corr_err_en;

assign ecfg_reg_44 = rc_device ? {5'b0, rc_fatal_err_en, rc_nonfatal_err_en, rc_corr_err_en} : 8'h0;
assign ecfg_reg_45 = 8'h0;
assign ecfg_reg_46 = 8'h0;
assign ecfg_reg_47 = 8'h0;

always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
        rc_corr_err_en      <= #TP 0;
        rc_nonfatal_err_en  <= #TP 0;
        rc_fatal_err_en     <= #TP 0;
    end
    else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        rc_corr_err_en      <= #TP (err_reg_id[11] & err_write_pulse[0]) ? lbc_cdm_data[0] : rc_corr_err_en;
        rc_nonfatal_err_en  <= #TP (err_reg_id[11] & err_write_pulse[0]) ? lbc_cdm_data[1] : rc_nonfatal_err_en;
        rc_fatal_err_en     <= #TP (err_reg_id[11] & err_write_pulse[0]) ? lbc_cdm_data[2] : rc_fatal_err_en;
        if( VF_IMPL ) begin
            // This register is not applicable to Devices.
            rc_corr_err_en      <= #TP 0;
            rc_nonfatal_err_en  <= #TP 0;
            rc_fatal_err_en     <= #TP 0;
        end
    end
end

// -----------------------------------------------------------------------------
// Root Error Status Register
// ecfig_reg_id     - 12
// PCIE Offset      - `AER_PTR + 30h
// length           - 4 bytes
// default value    - 0h
// Cfig register    - ecfg_reg_48 - ecfg_reg_51
// -----------------------------------------------------------------------------
reg     rcvd_corr_err;
reg     rcvd_multi_corr_err;
reg     rcvd_uncorr_err;
reg     rcvd_multi_uncorr_err;
reg     first_uncorr_fatal;
reg     rcvd_nonfatal_err;
reg     rcvd_fatal_err;

assign ecfg_reg_48 = rc_device ? {1'b0,                  rcvd_fatal_err,  rcvd_nonfatal_err,   first_uncorr_fatal,
                                  rcvd_multi_uncorr_err, rcvd_uncorr_err, rcvd_multi_corr_err, rcvd_corr_err}
                               : 8'h0;
assign ecfg_reg_49 = 8'h0;
assign ecfg_reg_50 = 8'h0;
assign ecfg_reg_51 = rc_device ? {cfg_aer_int_msg_num, 3'h0} : 8'h0;

wire   [MSG_TLP_WD-1:0] radm_uncorr_err;
wire    cfg_send_uncorr_err;
wire    rprt_rcv_err_cor_msg ;
wire    rprt_rcv_err_nf_msg ;
wire    rprt_rcv_err_f_msg ;
wire    cfg_rprt_err_cor ;
wire    cfg_rprt_err_nf ;
wire    cfg_rprt_err_f ;
wire    cfg_rprt_err_uncor ;
wire    rprt_multi_err_cor ;
wire    rprt_multi_err_uncor ;

wire         int_radm_correctable_err = |radm_correctable_err & ~core_in_dpc_plus;
wire         block_rcv_err_nf_msg     = core_in_dpc_plus & ( (cdm_dpc_trig_en[1:0] == 2'b10) |  ((cdm_dpc_trig_en[1:0] == 2'b01) & radm_fatal_err[0]) ) | core_in_dpc;
wire         block_rcv_err_f_msg      = (cdm_dpc_trig_en[1:0] == 2'b01) | (cdm_dpc_trig_en[1:0] == 2'b10) & r_downstream_port;

wire         int_radm_nonfatal_err    = |radm_nonfatal_err;
wire         int_radm_fatal_err       = |radm_fatal_err;

assign radm_uncorr_err     = (radm_nonfatal_err | radm_fatal_err);
assign cfg_send_uncorr_err = (cfg_send_nf_err | cfg_send_f_err);

assign rprt_rcv_err_cor_msg = int_radm_correctable_err & cfg_br_ctrl_serren & cfg_cor_err_rpt_en ;
assign rprt_rcv_err_nf_msg  = int_radm_nonfatal_err    & cfg_br_ctrl_serren & (cfg_nf_err_rpt_en | cfg_reg_serren) & ~block_rcv_err_nf_msg;
assign rprt_rcv_err_f_msg   = int_radm_fatal_err       & cfg_br_ctrl_serren & (cfg_f_err_rpt_en  | cfg_reg_serren) & ~block_rcv_err_f_msg;
assign cfg_rprt_err_cor     = rprt_rcv_err_cor_msg | cfg_send_cor_err ;
assign cfg_rprt_err_nf      = rprt_rcv_err_nf_msg  | cfg_send_nf_err ;
assign cfg_rprt_err_f       = rprt_rcv_err_f_msg   | cfg_send_f_err ;
assign cfg_rprt_err_uncor   = cfg_rprt_err_nf      | cfg_rprt_err_f ;



assign rprt_multi_err_cor   =  (rprt_rcv_err_cor_msg  & cfg_send_cor_err    ) ;
assign rprt_multi_err_uncor =  (rprt_rcv_err_nf_msg & cfg_send_nf_err) //internal error and receive TLP MSG ERROR in same clock cycle
                             | (rprt_rcv_err_f_msg  & cfg_send_f_err ) //internal error and receive TLP MSG ERROR in same clock cycle
                             | (cfg_rprt_err_nf     & cfg_rprt_err_f );



always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        rcvd_corr_err           <= #TP 0;
        rcvd_multi_corr_err     <= #TP 0;
        rcvd_uncorr_err         <= #TP 0;
        rcvd_multi_uncorr_err   <= #TP 0;
        first_uncorr_fatal      <= #TP 0;
        rcvd_nonfatal_err       <= #TP 0;
        rcvd_fatal_err          <= #TP 0;
    end
    else begin
    // The following registers are RW1CS
        // Received correctable error message (or produced internally)
        rcvd_corr_err           <= #TP    cfg_rprt_err_cor                                          ? 1'b1
                                        : (err_reg_id[12] & err_write_pulse[0] & lbc_cdm_data[0])   ? 1'b0
                                        : rcvd_corr_err;
        // Received correctable error message (or produced internally) when above is already set
        rcvd_multi_corr_err     <= #TP ( (cfg_rprt_err_cor & rcvd_corr_err)
                                        || rprt_multi_err_cor
                                        ) ? 1'b1
                                        : (err_reg_id[12] & err_write_pulse[0] & lbc_cdm_data[1])   ? 1'b0
                                        : rcvd_multi_corr_err;
        // Received uncorrectable error message (or produced internally)
        rcvd_uncorr_err         <= #TP    cfg_rprt_err_uncor                                        ? 1'b1
                                        : (err_reg_id[12] & err_write_pulse[0] & lbc_cdm_data[2])   ? 1'b0
                                        : rcvd_uncorr_err;
        // Received uncorrectable error message (or produced internally) when above is already set
        rcvd_multi_uncorr_err   <= #TP ((cfg_rprt_err_uncor & rcvd_uncorr_err)
                                        || rprt_multi_err_uncor
                                        ) ? 1'b1
                                        : (err_reg_id[12] & err_write_pulse[0] & lbc_cdm_data[3])   ? 1'b0
                                        : rcvd_multi_uncorr_err;
        // First uncorrectable error message received is for a fatal error
        first_uncorr_fatal      <= #TP ( cfg_rprt_err_f & ~rcvd_uncorr_err
                                        && !(radm_nonfatal_err[0] && rprt_rcv_err_nf_msg)// First uncorrectable error is not fatal error if TLP 0 is nonfatal
                                        )       ? 1'b1
                                        : (err_reg_id[12] & err_write_pulse[0] & lbc_cdm_data[4])   ? 1'b0
                                        : first_uncorr_fatal;
        // Received uncorrectable NON-FATAL error message (or produced internally)
        rcvd_nonfatal_err       <= #TP     cfg_rprt_err_nf                                          ? 1'b1
                                        : (err_reg_id[12] & err_write_pulse[0] & lbc_cdm_data[5])   ? 1'b0
                                        : rcvd_nonfatal_err;
        // Received uncorrectable FATAL error message (or produced internally)
        rcvd_fatal_err          <= #TP    cfg_rprt_err_f                                            ? 1'b1
                                        : (err_reg_id[12] & err_write_pulse[0] & lbc_cdm_data[6])   ? 1'b0
                                        : rcvd_fatal_err;
        if( VF_IMPL ) begin
            // This register is not applicable to Devices.
            rcvd_corr_err           <= #TP 0;
            rcvd_multi_corr_err     <= #TP 0;
            rcvd_uncorr_err         <= #TP 0;
            rcvd_multi_uncorr_err   <= #TP 0;
            first_uncorr_fatal      <= #TP 0;
            rcvd_nonfatal_err       <= #TP 0;
            rcvd_fatal_err          <= #TP 0;
        end
    end
end

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        cfg_aer_int_msg_num     <= #TP AER_INT_MSG_NUM;
    end
    else begin
        cfg_aer_int_msg_num     <= #TP AER_CAP_ENABLE ?
                                       ((int_lbc_cdm_dbi & err_write_pulse[3] & err_reg_id[12]) ? lbc_cdm_data[31:27]: cfg_aer_int_msg_num)
                                       : 5'b0;
        if( VF_IMPL ) begin
            // This register is not applicable to Devices.
            cfg_aer_int_msg_num     <= #TP 0;
        end
    end
end    

// -----------------------------------------------------------------------------
// Error Source Identification Register
// ecfig_reg_id     - 13
// PCIE Offset      - `AER_PTR + 34h
// length           - 4 bytes
// default value    - 0h
// Cfig register    - ecfg_reg_52 - ecfg_reg_55
// -----------------------------------------------------------------------------
reg [15:0]  uncorr_err_reqid;
reg [15:0]  corr_err_reqid;

assign {ecfg_reg_55, ecfg_reg_54} = rc_device ? uncorr_err_reqid : 16'h0;
assign {ecfg_reg_53, ecfg_reg_52} = rc_device ? corr_err_reqid : 16'h0;

wire   [MSG_TLP_WD-1:0] rprt_rcv_err_uncor_msg;

  genvar b;                   
  generate
    for(b=0;b<MSG_TLP_WD;b=b+1) begin : gen_rprt_rcv_err_uncor_msg
      assign rprt_rcv_err_uncor_msg[b]         =  radm_uncorr_err[b] & (rprt_rcv_err_nf_msg | rprt_rcv_err_f_msg) ;
    end
  endgenerate

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        corr_err_reqid      <= #TP 0;
        uncorr_err_reqid    <= #TP 0;
    end
    else begin
        corr_err_reqid      <= #TP ((|radm_correctable_err & rprt_rcv_err_cor_msg) & ~rcvd_corr_err)   ? obtain_corr_err_reqid (radm_msg_req_id, radm_correctable_err, rprt_rcv_err_cor_msg, rcvd_corr_err )     // received err MSG
                                 :  (cfg_send_cor_err & ~rcvd_corr_err)                                  ? int_req_id                // internally generated err MSG
                                 :  corr_err_reqid;
        uncorr_err_reqid    <= #TP (|rprt_rcv_err_uncor_msg                        & ~rcvd_uncorr_err) ? obtain_uncorr_err_reqid (radm_msg_req_id, rprt_rcv_err_uncor_msg, rcvd_uncorr_err )     // received err MSG
                                 :  (cfg_send_uncorr_err & ~rcvd_uncorr_err)                             ? int_req_id                // internally generated err MSG
                                 :  uncorr_err_reqid;
        if( VF_IMPL ) begin
            // This register is not applicable to Devices.
            corr_err_reqid      <= #TP 0;
            uncorr_err_reqid    <= #TP 0;
        end
    end
end


function automatic[15:0]obtain_corr_err_reqid;
    input [(MSG_TLP_WD*16)-1:0] radm_msg_req_id;
    input [MSG_TLP_WD-1:0] radm_correctable_err;
    input rprt_rcv_err_cor_msg;
    input rcvd_corr_err;

    integer k; 
    begin
      obtain_corr_err_reqid = 16'd0; 

       for(k = MSG_TLP_WD-1; k >= 0; k = k - 1) begin
          if(radm_correctable_err[k] & rprt_rcv_err_cor_msg &~rcvd_corr_err)
            obtain_corr_err_reqid = radm_msg_req_id[16*k +: 16]; 
       end
    end
endfunction

function automatic[15:0]obtain_uncorr_err_reqid;
    input [(MSG_TLP_WD*16)-1:0] radm_msg_req_id;
    input [MSG_TLP_WD-1:0] radm_uncorrectable_err;
    input rcvd_uncorr_err;

    integer k; 
    begin
      obtain_uncorr_err_reqid = 16'd0; 

       for(k = MSG_TLP_WD-1; k >= 0; k = k - 1) begin
          if(radm_uncorrectable_err[k] &~rcvd_uncorr_err)
            obtain_uncorr_err_reqid = radm_msg_req_id[16*k +: 16]; 
       end
    end
endfunction


// -----------------------------------------------------------------------------
// Error Interrupt & MSI generation
// -----------------------------------------------------------------------------
wire aer_rc_msi_src;
reg aer_rc_msi_src_d;

assign aer_rc_msi_src = (cfg_msi_en | cfg_msix_en) &
                        ((rc_fatal_err_en & rcvd_fatal_err) |
                         (rc_nonfatal_err_en & rcvd_nonfatal_err) |
                         (rc_corr_err_en & rcvd_corr_err));

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
        cfg_aer_rc_err_int  <= #TP 1'b0;
        aer_rc_msi_src_d    <= #TP 1'b0;
        cfg_aer_rc_err_msi  <= #TP 1'b0;
    end
    else begin
        // Interrupt - level signal
        cfg_aer_rc_err_int  <= #TP AER_CAP_ENABLE ? ~cfg_int_disable & ~(cfg_msi_en | cfg_msix_en) &
                                            ((rc_fatal_err_en & rcvd_fatal_err) |
                                             (rc_nonfatal_err_en & rcvd_nonfatal_err) |
                                             (rc_corr_err_en & rcvd_corr_err))
                                          : 1'b0;
        // MSI - pulse signal
        aer_rc_msi_src_d    <= #TP aer_rc_msi_src;
        cfg_aer_rc_err_msi  <= #TP AER_CAP_ENABLE ? (aer_rc_msi_src & ~aer_rc_msi_src_d) : 1'b0;
        if( VF_IMPL ) begin
            // This register is not applicable to Devices.
            cfg_aer_rc_err_int  <= #TP 1'b0;
            aer_rc_msi_src_d    <= #TP 1'b0;
            cfg_aer_rc_err_msi  <= #TP 1'b0;
        end
    end
end


// -----------------------------------------------------------------------------
// TLP Prefix Log Register
// ecfig_reg_id     - 14 - 23
// PCIE Offset      - `AER_PTR + 38h
// length           - 16 byte
// default value    - 0h
// Cfig register    - ecfg_reg_95 ... ecfg_reg_56
// -----------------------------------------------------------------------------

// TLP Prefix Log is updated for identical conditions as the Header Log.
// or TLP Header on FLIT Mode Supported
// ---------------------------------------------------------------------
generate 
 if ( HDR_SIZE_DW > 4) begin : gen_HDR_DW5

   if(ELQ_MAX_DEPTH==1) begin : gen_HDR_DW5_single_reg
     assign {ecfg_reg_59, ecfg_reg_58, ecfg_reg_57, ecfg_reg_56} = (AER_CAP_ENABLE && (fe_pointer_q>0))  ? (fm_pointer_q ?   elq[0][4*32+:32] : elq[0][0*32+:32] ) : 'h0;
   end else begin: gen_HDR_DW5_multi_reg
     assign {ecfg_reg_59, ecfg_reg_58, ecfg_reg_57, ecfg_reg_56} = (AER_CAP_ENABLE && (fe_pointer_q>0))  ?
                                                                                             (fm_pointer_q?             elq[rd_ptr][4*32+:32] : elq[rd_ptr][0*32+:32] )  
                                                                   : 32'h0;
   end
      
 end else begin : gen_no_HDR_DW5
    assign {ecfg_reg_59, ecfg_reg_58, ecfg_reg_57, ecfg_reg_56} = 0;
 end
   
 if ( HDR_SIZE_DW > 5) begin : gen_HDR_DW6

   if(ELQ_MAX_DEPTH==1) begin : gen_HDR_DW6_single_reg
     assign {ecfg_reg_63, ecfg_reg_62, ecfg_reg_61, ecfg_reg_60} = (AER_CAP_ENABLE && (fe_pointer_q>0))  ? (fm_pointer_q ?   elq[0][5*32+:32] : elq[0][1*32+:32] ) : 'h0;
   end else begin:gen_HDR_DW6_multi_reg
     assign {ecfg_reg_63, ecfg_reg_62, ecfg_reg_61, ecfg_reg_60} = (AER_CAP_ENABLE && (fe_pointer_q>0))  ?
                                                                                             (fm_pointer_q?             elq[rd_ptr][5*32+:32] : elq[rd_ptr][1*32+:32] )  
                                                                   : 32'h0;
   end
     
 end else begin : gen_no_HDR_DW6
    assign {ecfg_reg_63, ecfg_reg_62, ecfg_reg_61, ecfg_reg_60} = 0;
 end

 if ( HDR_SIZE_DW > 6) begin : gen_HDR_DW7

   if(ELQ_MAX_DEPTH==1) begin : gen_HDR_DW7_single_reg
     assign {ecfg_reg_67, ecfg_reg_66, ecfg_reg_65, ecfg_reg_64} = (AER_CAP_ENABLE && (fe_pointer_q>0))  ? (fm_pointer_q ?   elq[0][6*32+:32] : elq[0][2*32+:32] ) : 'h0; 
   end else begin:gen_HDR_DW7_multi_reg
     assign {ecfg_reg_67, ecfg_reg_66, ecfg_reg_65, ecfg_reg_64} = (AER_CAP_ENABLE && (fe_pointer_q>0))  ?
                                                                                             (fm_pointer_q?             elq[rd_ptr][6*32+:32] : elq[rd_ptr][2*32+:32] )  
                                                                   : 32'h0;
   end
     
 end else begin : gen_no_HDR_DW7
    assign {ecfg_reg_67, ecfg_reg_66, ecfg_reg_65, ecfg_reg_64} = 0;
 end

 if ( HDR_SIZE_DW > 7) begin : gen_HDR_DW8

   if(ELQ_MAX_DEPTH==1) begin : gen_HDR_DW8_single_reg
     assign {ecfg_reg_71, ecfg_reg_70, ecfg_reg_69, ecfg_reg_68} = (AER_CAP_ENABLE && (fe_pointer_q>0))  ? (fm_pointer_q ?   elq[0][7*32+:32] : 32'h0 ) : 'h0;
   end else begin:gen_HDR_DW8_multi_reg
     assign {ecfg_reg_71, ecfg_reg_70, ecfg_reg_69, ecfg_reg_68} = (AER_CAP_ENABLE && (fe_pointer_q>0))  ?
                                                                                             (fm_pointer_q?             elq[rd_ptr][7*32+:32] : 32'h0 )  
                                                                   : 32'h0;
   end
     
 end else begin : gen_no_HDR_DW8
    assign {ecfg_reg_71, ecfg_reg_70, ecfg_reg_69, ecfg_reg_68} = 0;
 end

 if ( HDR_SIZE_DW > 8) begin : gen_HDR_DW9

   if(ELQ_MAX_DEPTH==1) begin : gen_HDR_DW9_single_reg
     assign {ecfg_reg_75, ecfg_reg_74, ecfg_reg_73, ecfg_reg_72} = (AER_CAP_ENABLE && (fe_pointer_q>0))  ? (fm_pointer_q ?   elq[0][8*32+:32] : 32'h0 ) : 'h0;
   end else begin:gen_HDR_DW9_multi_reg
     assign {ecfg_reg_75, ecfg_reg_74, ecfg_reg_73, ecfg_reg_72} = (AER_CAP_ENABLE && (fe_pointer_q>0))  ?
                                                                                             (fm_pointer_q?             elq[rd_ptr][8*32+:32] : 32'h0 )  
                                                                   : 32'h0;
   end
     
 end else begin : gen_no_HDR_DW9
    assign {ecfg_reg_75, ecfg_reg_74, ecfg_reg_73, ecfg_reg_72} = 0;
 end

 if ( HDR_SIZE_DW > 9) begin : gen_HDR_DW10

   if(ELQ_MAX_DEPTH==1) begin : gen_HDR_DW10_single_reg
     assign {ecfg_reg_79, ecfg_reg_78, ecfg_reg_77, ecfg_reg_76} = (AER_CAP_ENABLE && (fe_pointer_q>0))  ? (fm_pointer_q ?   elq[0][9*32+:32] : 32'h0  ) : 'h0;
   end else begin:gen_HDR_DW10_multi_reg
     assign {ecfg_reg_79, ecfg_reg_78, ecfg_reg_77, ecfg_reg_76} = (AER_CAP_ENABLE && (fe_pointer_q>0))  ?
                                                                                             (fm_pointer_q?             elq[rd_ptr][9*32+:32] :  32'h0 )  
                                                                   : 32'h0;
   end
     
 end else begin : gen_no_HDR_DW10
    assign {ecfg_reg_79, ecfg_reg_78, ecfg_reg_77, ecfg_reg_76} = 0;
 end
   
 if ( HDR_SIZE_DW > 10) begin : gen_HDR_DW11

   if(ELQ_MAX_DEPTH==1) begin : gen_HDR_DW11_single_reg
     assign {ecfg_reg_83, ecfg_reg_82, ecfg_reg_81, ecfg_reg_80} = (AER_CAP_ENABLE && (fe_pointer_q>0))  ? (fm_pointer_q ?   elq[0][10*32+:32] :  32'h0 ) : 'h0;
   end else begin:gen_HDR_DW11_multi_reg
     assign {ecfg_reg_83, ecfg_reg_82, ecfg_reg_81, ecfg_reg_80} = (AER_CAP_ENABLE && (fe_pointer_q>0))  ?
                                                                                             (fm_pointer_q?             elq[rd_ptr][10*32+:32] : 32'h0 )  
                                                                   : 32'h0;
   end
     
 end else begin : gen_no_HDR_DW11
    assign {ecfg_reg_83, ecfg_reg_82, ecfg_reg_81, ecfg_reg_80} = 0;
 end

 if ( HDR_SIZE_DW > 11) begin : gen_HDR_DW12

   if(ELQ_MAX_DEPTH==1) begin : gen_HDR_DW12_single_reg
     assign {ecfg_reg_87, ecfg_reg_86, ecfg_reg_85, ecfg_reg_84} = (AER_CAP_ENABLE && (fe_pointer_q>0))  ? (fm_pointer_q ?   elq[0][11*32+:32] : 32'h0 ) : 'h0;
   end else begin:gen_HDR_DW12_multi_reg
     assign {ecfg_reg_87, ecfg_reg_86, ecfg_reg_85, ecfg_reg_84} = (AER_CAP_ENABLE && (fe_pointer_q>0))  ?
                                                                                             (fm_pointer_q?             elq[rd_ptr][11*32+:32] : 32'h0  )  
                                                                   : 32'h0;
   end
     
 end else begin : gen_no_HDR_DW12
    assign {ecfg_reg_87, ecfg_reg_86, ecfg_reg_85, ecfg_reg_84} = 0;
 end

 if ( HDR_SIZE_DW > 12) begin : gen_HDR_DW13

   if(ELQ_MAX_DEPTH==1) begin : gen_HDR_DW13_single_reg
     assign {ecfg_reg_91, ecfg_reg_90, ecfg_reg_89, ecfg_reg_88} = (AER_CAP_ENABLE && (fe_pointer_q>0))  ? (fm_pointer_q ?   elq[0][12*32+:32] : 32'h0  ) : 'h0;
   end else begin:gen_HDR_DW13_multi_reg
     assign {ecfg_reg_91, ecfg_reg_90, ecfg_reg_89, ecfg_reg_88} = (AER_CAP_ENABLE && (fe_pointer_q>0))  ?
                                                                                             (fm_pointer_q?             elq[rd_ptr][12*32+:32] : 32'h0 )  
                                                                   : 32'h0;
   end
     
 end else begin : gen_no_HDR_DW13
    assign {ecfg_reg_91, ecfg_reg_90, ecfg_reg_89, ecfg_reg_88} = 0;
 end

 if ( HDR_SIZE_DW > 13) begin : gen_HDR_DW14

   if(ELQ_MAX_DEPTH==1) begin : gen_HDR_DW14_single_reg
     assign {ecfg_reg_95, ecfg_reg_94, ecfg_reg_93, ecfg_reg_92} = (AER_CAP_ENABLE && (fe_pointer_q>0))  ? (fm_pointer_q ?   elq[0][13*32+:32] : 32'h0  ) : 'h0;
   end else begin:gen_HDR_DW14_multi_reg
     assign {ecfg_reg_95, ecfg_reg_94, ecfg_reg_93, ecfg_reg_92} = (AER_CAP_ENABLE && (fe_pointer_q>0))  ?
                                                                                             (fm_pointer_q?             elq[rd_ptr][13*32+:32] : 32'h0 )  
                                                                   : 32'h0;
   end
     
 end else begin : gen_no_HDR_DW14
    assign {ecfg_reg_95, ecfg_reg_94, ecfg_reg_93, ecfg_reg_92} = 0;
 end

endgenerate

//_-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


wire        int_dpc_triggered;
wire [1:0]  int_dpc_trig_reason;
wire [1:0]  int_dpc_trig_reason_extn;
wire        uncor_err_dpc_triggered;
wire        rx_err_msg_dpc;
wire        rx_err_msg_dpc_triggered;
wire        dpc_trig_rsn_extn = int_dpc_sw_trigger;
wire        cdm_core_in_dpc;
wire [15:0] dpc_err_src_id;          // DPC Error Source ID.
wire [MSG_TLP_WD-1:0] dpc_rcv_err_uncor_msg;

assign uncor_err_dpc_triggered   = int_advisory_nf_err ? 1'b0 :
                                                         (int_dl_prot_err             & !dl_prot_err_mask       ) |
                                                         (int_surprise_down_err       & !surprise_down_err_mask ) |
                                                         (int_rtlh_overfl_err         & !rx_overfl_mask         ) |
                                                         (int_rtlh_fc_prot_err        & !rx_fc_prot_err_mask    ) |
                                                         (int_internal_err            & !internal_err_mask      ) |
                                                         (int_radm_unexp_cpl_err[0]   & !unexp_tx_cpl_mask      ) |
                                                         (int_radm_mlf_tlp_err[0]     & !rx_mlf_tlp_mask        ) |
                                                         (int_radm_rcvd_req_ur[0]     & ~tx_unsupt_req_err_mask & (cfg_unsupt_req_rpt_en | cfg_reg_serren)) |
                                                         (int_radm_rcvd_req_ca[0]     & !cpl_tx_abort_mask      ) |
                                                         (rtlh_poisoned_err[0]        & !rx_tlp_poisoned_mask   ) |
                                                         (valid_ecrc_err[0]           & !rx_ecrc_err_mask       ) |
                                                         (int_radm_cpl_timeout_err[0] & !cpl_timeout_mask       )
                                                         | (int_radm_acs_violation[0] & !acs_violation_mask     )
                                                        | (int_radm_atomic_egress_blk   & !tx_atomic_egress_blk_mask)
                                                        | (int_tlp_prfx_blocked_err     & !tlp_prfx_blocked_err_mask)
                                                        | (int_psnd_tlp_egrss_blckd_err & !psnd_tlp_egrss_blckd_err_mask)
                                                         ;

assign rx_err_msg_dpc           = (cdm_dpc_trig_en == 2'b01) ? |radm_fatal_err : (cdm_dpc_trig_en == 2'b10) ? (|radm_fatal_err) | (|radm_nonfatal_err) : 1'b0;
assign rx_err_msg_dpc_triggered = rx_err_msg_dpc & cfg_br_ctrl_serren;
assign int_uncor_err_dpc_triggered = (cdm_dpc_trig_en == 2'b01 || cdm_dpc_trig_en == 2'b10) ? uncor_err_dpc_triggered : 1'b0;

// DPC can be triggered from several sources: an unmasked uncorrectable error, a received error message, by software (DPC control bit) or 
// by a Root Port PIO uncorrectable error (if supported).
assign int_dpc_triggered = r_downstream_port && !core_in_dpc && (cdm_dpc_trig_en[0] ^ cdm_dpc_trig_en[1]) ?  (int_uncor_err_dpc_triggered | rx_err_msg_dpc_triggered | int_dpc_sw_trigger ) 
                                                                                                          : 1'b0;
assign int_dpc_trig_reason      = obtain_dpc_trig_reason (radm_nonfatal_err,dpc_rcv_err_uncor_msg,dpc_trig_rsn_extn);


function automatic[1:0]obtain_dpc_trig_reason;
    input [MSG_TLP_WD-1:0] radm_nonfatal_err;
    input [MSG_TLP_WD-1:0] dpc_rcv_err_uncor_msg;
    input dpc_trig_rsn_extn;

    integer k; 
    begin
      if (dpc_trig_rsn_extn) begin
        obtain_dpc_trig_reason = 2'b11;
      end else begin
        obtain_dpc_trig_reason = 2'b00;
      end

       for(k = MSG_TLP_WD-1; k >= 0; k = k - 1) begin
          if(dpc_rcv_err_uncor_msg[k]) begin
           if (radm_nonfatal_err[k]) begin
               obtain_dpc_trig_reason = 2'b01;
             end else begin
               obtain_dpc_trig_reason = 2'b10;
             end
          end
       end
    end
endfunction


assign int_dpc_trig_reason_extn = int_dpc_sw_trigger ? 2'b01 : 2'b00;  // by default, reason_extn is RP PIO error
assign cdm_core_in_dpc          = core_in_dpc;
assign cdm_aer_dpc_triggered = int_uncor_err_dpc_triggered & int_dpc_triggered;


 genvar c;                   
  generate
    for(c=0;c<MSG_TLP_WD;c=c+1) begin : gen_dpc_rcv_err_uncor_msg
      assign dpc_rcv_err_uncor_msg[c]         =  (cdm_dpc_trig_en == 2'b01) ? radm_uncorr_err[c] & radm_fatal_err[c] :
                                                 (cdm_dpc_trig_en == 2'b10) ? radm_uncorr_err[c] & (radm_fatal_err[c] | radm_nonfatal_err[c]):
                                                 1'b0 ;
    end
  endgenerate


wire [15:0] dpc_err_src_id_f;
assign  dpc_err_src_id_f  =  obtain_dpc_err_src_id_f (radm_msg_req_id, dpc_rcv_err_uncor_msg, int_req_id );


function automatic[15:0]obtain_dpc_err_src_id_f;
    input [(MSG_TLP_WD*16)-1:0] radm_msg_req_id;
    input [MSG_TLP_WD-1:0] dpc_rcv_err_uncor_msg;
    input [15:0] int_req_id;

    integer k; 
    begin
      obtain_dpc_err_src_id_f = int_req_id; 

       for(k = MSG_TLP_WD-1; k >= 0; k = k - 1) begin
          if(dpc_rcv_err_uncor_msg[k])
            obtain_dpc_err_src_id_f = radm_msg_req_id[16*k +: 16]; 
       end
    end
endfunction




assign dpc_err_src_id = dpc_err_src_id_f;



// =============================================================================
// Configuration Register Read Operation
// =============================================================================

// Extended Configuration registers
// read PCI cfg space registers
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (!sticky_rst_n)
        err_reg_data <= #TP 32'b0;
    else 
      if ( err_read_pulse & AER_CAP_ENABLE) begin
            unique case (1'b1)
            err_reg_id[ 0]: err_reg_data    <= #TP {ecfg_reg_3,  ecfg_reg_2,  ecfg_reg_1,  ecfg_reg_0 };
            err_reg_id[ 1]: err_reg_data    <= #TP {ecfg_reg_7,  ecfg_reg_6,  ecfg_reg_5,  ecfg_reg_4 };
            err_reg_id[ 2]: err_reg_data    <= #TP {ecfg_reg_11, ecfg_reg_10, ecfg_reg_9,  ecfg_reg_8 };
            err_reg_id[ 3]: err_reg_data    <= #TP {ecfg_reg_15, ecfg_reg_14, ecfg_reg_13, ecfg_reg_12};
            err_reg_id[ 4]: err_reg_data    <= #TP {ecfg_reg_19, ecfg_reg_18, ecfg_reg_17, ecfg_reg_16};
            err_reg_id[ 5]: err_reg_data    <= #TP {ecfg_reg_23, ecfg_reg_22, ecfg_reg_21, ecfg_reg_20};
            err_reg_id[ 6]: err_reg_data    <= #TP {ecfg_reg_27, ecfg_reg_26, ecfg_reg_25, ecfg_reg_24};
            err_reg_id[ 7]: err_reg_data    <= #TP {ecfg_reg_31, ecfg_reg_30, ecfg_reg_29, ecfg_reg_28};
            err_reg_id[ 8]: err_reg_data    <= #TP {ecfg_reg_35, ecfg_reg_34, ecfg_reg_33, ecfg_reg_32};
            err_reg_id[ 9]: err_reg_data    <= #TP {ecfg_reg_39, ecfg_reg_38, ecfg_reg_37, ecfg_reg_36};
            err_reg_id[10]: err_reg_data    <= #TP {ecfg_reg_43, ecfg_reg_42, ecfg_reg_41, ecfg_reg_40};
            err_reg_id[11]: err_reg_data    <= #TP {ecfg_reg_47, ecfg_reg_46, ecfg_reg_45, ecfg_reg_44};
            err_reg_id[12]: err_reg_data    <= #TP {ecfg_reg_51, ecfg_reg_50, ecfg_reg_49, ecfg_reg_48};
            err_reg_id[13]: err_reg_data    <= #TP {ecfg_reg_55, ecfg_reg_54, ecfg_reg_53, ecfg_reg_52};
            err_reg_id[14]: err_reg_data    <= #TP {ecfg_reg_59, ecfg_reg_58, ecfg_reg_57, ecfg_reg_56};
            err_reg_id[15]: err_reg_data    <= #TP {ecfg_reg_63, ecfg_reg_62, ecfg_reg_61, ecfg_reg_60};
            err_reg_id[16]: err_reg_data    <= #TP {ecfg_reg_67, ecfg_reg_66, ecfg_reg_65, ecfg_reg_64};
            err_reg_id[17]: err_reg_data    <= #TP {ecfg_reg_71, ecfg_reg_70, ecfg_reg_69, ecfg_reg_68};
            err_reg_id[18]: err_reg_data    <= #TP {ecfg_reg_75, ecfg_reg_74, ecfg_reg_73, ecfg_reg_72};
            default: err_reg_data    <= #TP `PCIE_UNUSED_RESPONSE;
            endcase
        end
        //Upstream RCRB does not log AER. null capability at 100h in Upstream RCRB linked list
        //the null capability only has the te pointer to next capability.
        else if (rcrb_err_read_pulse) begin
            if (rcrb_err_reg_id_0) err_reg_data    <= #TP {rcrb_cfg_aer_next_ptr , 20'h0};
            else                err_reg_data    <= #TP 32'h0;
        end
        else
            err_reg_data <= #TP err_reg_data;
end


`ifndef SYNTHESIS
`endif // SYNTHESIS



endmodule // cdm_error_reg
