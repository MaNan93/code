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

// -----------------------------------------------------------------------------
// --- RCS information:
// ---   $DateTime: 2023/04/29 12:35:01 $
// ---   $Author: neira $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_ras_pkg.svh#2 $
// -----------------------------------------------------------------------------

`ifndef __GUARD__CDM_RAS_PKG__SVH__
`define __GUARD__CDM_RAS_PKG__SVH__

`include "products/DWC_pcie_core_pkg.svh"

package cdm_ras_pkg;

    import DWC_pcie_ctl_pkg::RAS_ERROR_TYPE_WD;
    import DWC_pcie_ctl_pkg::MAX_RAS_PROT_CHK_N;

    localparam RAS_TRACE_BUFFER_DEPTH         = `CX_RAS_TRACE_BUFFER_DEPTH;
    localparam RAS_ERROR_TRACER_FILTER_NUMBER = `CX_RAS_ERROR_TRACER_FILTER_NUMBER;

    // RAS_ERROR_TRACER_CAPABILITY
    typedef struct packed {
        logic [4:0] filter_number;
        logic [6:0] size;         
    } ras_error_tracer_capability_s;

    // RAS_ERROR_TRACER_CTRL
    typedef struct packed {
        logic       timestamp_ctrl_clr;
        logic [4:0] timestamp_ctrl_incr;
        logic [1:0] count_affinity;
        logic       ras_error_tracer_pending_enable;
        logic       enable;
    } ras_error_tracer_ctrl_s;

    // RAS_ERROR_TRACER_FILTER_CTRL
    localparam RAS_ERROR_TRACER_FILTER_TAG_WD = 23;
    typedef struct packed {
        logic                                          [$clog2(RAS_ERROR_TRACER_FILTER_NUMBER)-1:0] filter_id;
        logic                                                                                       filter_rule;
        logic [RAS_ERROR_TRACER_FILTER_NUMBER-1:0][1:0]                                             filter_rule_en;
        logic [RAS_ERROR_TRACER_FILTER_NUMBER-1:0][1:0][RAS_ERROR_TRACER_FILTER_TAG_WD-1:0]         filter_tag;
    } ras_error_tracer_filter_ctrl_s;

    // RAS ERROR TRACER LOG CTRL
    typedef struct packed {
        logic [$clog2(RAS_TRACE_BUFFER_DEPTH)-1:0] entry_id;
        logic                                      entry_clr;
    } ras_error_tracer_log_ctrl_s;

    // RAS ERROR TRACER LOG REPORT 0
    localparam RAS_REG_ERROR_SYNDROME_WD = 16;
    typedef struct packed {
        logic [RAS_REG_ERROR_SYNDROME_WD-1:0] syndrome;
        logic [15:0]                          count;
    } ras_error_tracer_log_report_0_s;

    // RAS ERROR TRACER LOG REPORT 1
    localparam RAS_REG_ERROR_SLICE_ID_WD = 8;
    typedef struct packed {
        logic [$clog2(MAX_RAS_PROT_CHK_N)-1:0] ras_prot_chk_id;
        logic [RAS_REG_ERROR_SLICE_ID_WD-1:0]  ras_prot_chk_slice_id;
        logic [RAS_ERROR_TYPE_WD-1:0]          error_type;
    } ras_error_tracer_log_report_1_s;

    // RAS ERROR TRACER LOG REPORT 2
    typedef struct packed {
        logic [RAS_ERROR_TRACER_FILTER_TAG_WD-1:0] addr_log;
    } ras_error_tracer_log_report_2_s;

    // RAS ERROR TRACER LOG REPORT 3
    typedef struct packed {
        logic [31:0] timestamp;
    } ras_error_tracer_log_report_3_s;

    typedef struct packed {
        ras_error_tracer_ctrl_s         ras_error_tracer_ctrl;
        ras_error_tracer_filter_ctrl_s  ras_error_tracer_filter_ctrl;
        ras_error_tracer_log_ctrl_s     ras_error_tracer_log_ctrl;
    } ras_err_tracer_ctrl_s;

    typedef struct packed {
        ras_error_tracer_capability_s   ras_error_tracer_capability;
        logic                           ras_error_tracer_pending_correctable;
        logic                           ras_error_tracer_pending_uncorrectable;
        logic                           ras_error_tracer_pending_err_inj_failure;
        logic                           ras_error_tracer_pending_err_inj_successful;
        ras_error_tracer_log_report_0_s ras_error_tracer_log_report_0;
        ras_error_tracer_log_report_1_s ras_error_tracer_log_report_1;
        ras_error_tracer_log_report_2_s ras_error_tracer_log_report_2;
        ras_error_tracer_log_report_3_s ras_error_tracer_log_report_3;
    } ras_err_tracer_rpt_s;

    typedef struct packed {
        logic [$clog2(MAX_RAS_PROT_CHK_N)-1:0] ras_prot_chk_id;
        logic                                  start_err_inj;
    } ras_err_inj_mgr_ctrl_s;
    
    typedef struct packed {
        logic valid;
        logic fail;
    } ras_err_inj_ack_s;
endpackage // cdm_ras_pkg
`endif // __GUARD__CDM_RAS_PKG__SVH__
