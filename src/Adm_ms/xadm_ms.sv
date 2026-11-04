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
// ---    $DateTime: 2023/12/22 07:15:34 $
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/xadm_ms.sv#5 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
//
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Adm_ms/xadm_ms_pkg.svh"
`include "products/pcie_pkg.svh"

module xadm_ms
import DWC_pcie_ctl_pkg::TP;
import DWC_pcie_ctl_pkg::HCRD_WD;
import DWC_pcie_ctl_pkg::DCRD_WD;
import DWC_pcie_ctl_pkg::NVC;
import DWC_pcie_ctl_pkg::N_XADM_IF;
import DWC_pcie_ctl_pkg::N_XALI_IF;
import DWC_pcie_ctl_pkg::N_DMA_IF;
import DWC_pcie_ctl_pkg::N_CCIX_IF;
import DWC_pcie_core_pkg::radm_xadm_rcvd_cpl_t;
import DWC_pcie_core_pkg::radm_xadm_timeout_npr_t;
import DWC_pcie_core_pkg::xadm_radm_tx_npr_t;
import DWC_pcie_core_pkg::xtlh_pkt_t;
import xadm_ms_pkg::xadm_restore_fc_crdt_t;
import DWC_pcie_core_pkg::xadm_xmt_pci_errors_t;
import DWC_pcie_core_pkg::xadm_pkt_t;
import DWC_pcie_core_pkg::rtlh_rfc_t;
import DWC_pcie_ctl_pkg::NVC_WD;
import DWC_pcie_core_pkg::xadm_rasdes_tlp_trace_t;
import DWC_pcie_ctl_pkg::N_XADM_P_IF;
import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
import DWC_pcie_ctl_pkg::RAS_DP_PROT_CHK_ID_BASE_XADM;
import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
import DWC_pcie_ctl_pkg::N_XADM_P_IF_VC;
import pcie_pkg::fc_type_e;

              (
    input logic                                    core_clk,                                
    input logic                                    core_rst_n,                              
    
    // From/to CDM
    input logic       [NVC-1:0][2:0]               cfg_vc_id,                            
    input logic       [NVC-1:0]                    cfg_vc_enable,                        
    input logic                                    cfg_fc_scaled_en,                     
    input logic       [2:0]                        cfg_max_payload_size,                 
    input logic                                    cfg_can_transmit_atomic,              
    input logic                                    cfg_can_transmit_dmwr,                
    
    output xadm_xmt_pci_errors_t                   xadm_xmt_pci_errors,                  

    output logic                                   xadm_msg_ltr,                         
    output logic [31:0]                            xadm_msg_ltr_latency,                 

    output logic                                   xadm_fc_prot_err,                     
    
    // From/to RADM
    output  xadm_radm_tx_npr_t                     xadm_radm_tx_npr,                     
    output  logic                                  xadm_radm_wakeup,                     
    
    // From/to RDLH
    input logic                                    rdlh_link_down,                       
    
    // From/to RTLH
    input logic       [NVC-1:0]                    rtlh_fc_init_status,                  
    input rtlh_rfc_t                               rtlh_rfc,                             
    
    // From/to XTLH
    input logic                                    xtlh_flit_mode_enable,                
    
    // From/to PM
    output logic      [NVC-1:0]                    xadm_pm_no_fc_credit,                 
    output logic      [NVC-1:0]                    xadm_pm_had_enough_credit,            
    output logic                                   xadm_pm_pkt_pending,                  

    // CMD FLUSH Interface
    input logic                                    rstctl_core_flush_req,                

    // xali posted tlp sent interface
    input  logic      [N_XADM_P_IF-1:0]            xtlh_xadm_posted_tlp_sent, 
    output logic      [N_XADM_P_IF-1:0]            xali_posted_tlp_sent,                 
    input  logic                                   diag_ctrl,
    input  logic                                   einj0_enable,
    input  logic [7:0]                             einj0_count,
    input  logic [3:0]                             einj0_crc_type,
    input  logic [2:0]                             einj0_ecrc_vc_sel,
    input  fc_type_e                               einj0_ecrc_fc_sel,
    input  logic                                   einj0_ecrc_intf_sel,
    output logic                                   einj0_ecrc_evt,

    // RASDES Interface
    output logic      [NVC-1:0][HCRD_WD-1:0]       xadm_fc_cnsmd_ph,                
    output logic      [NVC-1:0][DCRD_WD-1:0]       xadm_fc_cnsmd_pd,                
    output logic      [NVC-1:0][HCRD_WD-1:0]       xadm_fc_limit_ph,                
    output logic      [NVC-1:0][DCRD_WD-1:0]       xadm_fc_limit_pd,                
    output logic      [NVC-1:0][HCRD_WD-1:0]       xadm_fc_cnsmd_nph,               
    output logic      [NVC-1:0][DCRD_WD-1:0]       xadm_fc_cnsmd_npd,               
    output logic      [NVC-1:0][HCRD_WD-1:0]       xadm_fc_limit_nph,               
    output logic      [NVC-1:0][DCRD_WD-1:0]       xadm_fc_limit_npd,               
    output logic      [NVC-1:0][HCRD_WD-1:0]       xadm_fc_cnsmd_cplh,              
    output logic      [NVC-1:0][DCRD_WD-1:0]       xadm_fc_cnsmd_cpld,              
    output logic      [NVC-1:0][HCRD_WD-1:0]       xadm_fc_limit_cplh,              
    output logic      [NVC-1:0][DCRD_WD-1:0]       xadm_fc_limit_cpld,              
    output xadm_rasdes_tlp_trace_t                 xadm_rasdes_tlp_trace,           
    
    output logic      [NVC-1:0][HCRD_WD-1:0]       xadm_ph_cdts,                    
    output logic      [NVC-1:0][DCRD_WD-1:0]       xadm_pd_cdts,                    
    output logic      [NVC-1:0][HCRD_WD-1:0]       xadm_nph_cdts,                   
    output logic      [NVC-1:0][DCRD_WD-1:0]       xadm_npd_cdts,                   
    output logic      [NVC-1:0][HCRD_WD-1:0]       xadm_cplh_cdts,     
    output logic      [NVC-1:0][DCRD_WD-1:0]       xadm_cpld_cdts,     
    output logic               [HCRD_WD-1:0]       xadm_ph_shrd_cdts,  
    output logic               [DCRD_WD-1:0]       xadm_pd_shrd_cdts,  
    output logic               [HCRD_WD-1:0]       xadm_nph_shrd_cdts, 
    output logic               [DCRD_WD-1:0]       xadm_npd_shrd_cdts, 
    output logic               [HCRD_WD-1:0]       xadm_cplh_shrd_cdts,
    output logic               [DCRD_WD-1:0]       xadm_cpld_shrd_cdts,
    
    // XAIM/XADM PKT interfaces (MSG,LBC,XALI, DMA, CCIX)
    input xadm_pkt_t                               xaim_xadm_msg_pkt,               
    output logic                                   xadm_xaim_msg_halt,              

    input xadm_pkt_t                               xaim_xadm_lbc_pkt,               
    output logic                                   xadm_xaim_lbc_halt,              

    input xadm_pkt_t  [N_XALI_IF-1:0]              xaim_xadm_xali_pkt,              
    output logic      [N_XALI_IF-1:0]              xadm_xaim_xali_halt,             
    input xadm_pkt_t  [N_DMA_IF-1:0]               xaim_xadm_dma_pkt,               
    output logic      [N_DMA_IF-1:0]               xadm_xaim_dma_halt,              
    
    // XADM/IDE PKT Interface
    // XADM/XTLH PKT Interface
    output xtlh_pkt_t [N_XADM_IF-1:0]              xadm_xtlh_pkt,                   
    input logic       [N_XADM_IF-1:0]              xtlh_xadm_pkt_halt,              
    output logic                                   xadm_all_type_infinite           
    ,
    input logic                                    rasdp_error_mode
    ,
    output ras_dp_err_log_t                        ras_dp_err_log                   
    ,
    input  ras_dp_err_inj_t                        ras_dp_err_inj                   
);

xadm_pkt_t [N_XADM_IF-1:0] port_arb_ecrc_hdr_pkt;
logic      [N_XADM_IF-1:0] ecrc_hdr_port_arb_halt;

xadm_pkt_t [N_XADM_IF-1:0] ecrc_hdr_cplq_calc_pkt;
logic      [N_XADM_IF-1:0] cplq_calc_ecrc_hdr_halt;

xadm_pkt_t [N_XADM_IF-1:0] cplq_calc_fc_chk_pkt;
logic      [N_XADM_IF-1:0] fc_chk_cplq_calc_halt;

xadm_pkt_t [N_XADM_IF-1:0] fc_chk_ecrc_data_pkt;
logic      [N_XADM_IF-1:0] ecrc_data_fc_chk_halt;

xadm_pkt_t [N_XADM_IF-1:0] ecrc_data_fm_prfx_pkt;
logic      [N_XADM_IF-1:0] fm_prfx_ecrc_data_halt;

xadm_pkt_t [N_XADM_IF-1:0] fm_prfx_cplq_mng_pkt;
logic      [N_XADM_IF-1:0] cplq_mng_fm_prfx_halt;

xadm_pkt_t [N_XADM_IF-1:0] cplq_mng_xtlh_form_pkt;
logic      [N_XADM_IF-1:0] xtlh_form_cplq_mng_halt;

xadm_pkt_t [N_XADM_IF-1:0] cplq_mng_ide_pkt;
logic      [N_XADM_IF-1:0] ide_cplq_mng_halt;

xadm_pkt_t [N_XADM_IF-1:0] ide_xtlh_form_pkt;
logic      [N_XADM_IF-1:0] xtlh_form_ide_halt;

xtlh_pkt_t [N_XADM_IF-1:0] xtlh_form_tlp_bin_pkt;
logic      [N_XADM_IF-1:0] tlp_bin_xtlh_form_halt;

xadm_restore_fc_crdt_t [NVC-1:0][2:0][1:0] internal_restore_crdt;
xadm_restore_fc_crdt_t [NVC-1:0][2:0][1:0] fc_restore_crdt;

logic                      flush;

assign flush           = rstctl_core_flush_req | rasdp_error_mode;
assign fc_restore_crdt = flush? '0 : internal_restore_crdt;
////////////////////////////////////////////
// Register xtlh_flit_mode_enable
////////////////////////////////////////////
// The logic below:
// - registers flit mode to have good timing closure
// - ensures XAIM and XADM use the same flit mode in all conditions
logic flit_mode_enable;
always_ff@(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        flit_mode_enable <= #TP '0;
    end else begin
        if ( ~rstctl_core_flush_req )
            flit_mode_enable <= #TP xtlh_flit_mode_enable;
    end
end
// The logic below:
// - registers flit mode to have good timing closure
// - ensures RTLH and XADM use the same flit mode for credit management in all conditions
logic credit_flit_mode_enable;
always_ff@(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        credit_flit_mode_enable <= #TP '0;
    end else begin
        credit_flit_mode_enable <= #TP xtlh_flit_mode_enable;
    end
end

////////////////////////////////////////////
// 0.TRACKER AND RAS DP ERROR MANAGER
// Pipeline: NO
////////////////////////////////////////////
logic [N_XALI_IF-1:0] xaim_xadm_xali_pkt_hv;
logic [N_XADM_IF-1:0] xtlh_form_tlp_bin_eot;
logic [N_DMA_IF-1:0] xaim_xadm_dma_pkt_hv;
always_comb begin
    for(int i = 0; i < N_XALI_IF; i++) xaim_xadm_xali_pkt_hv[i] = xaim_xadm_xali_pkt[i].hv;
    for(int i = 0; i < N_XADM_IF; i++) xtlh_form_tlp_bin_eot[i] = xtlh_form_tlp_bin_pkt[i].eot;
    for(int i = 0; i < N_DMA_IF; i++)  xaim_xadm_dma_pkt_hv[i]  = xaim_xadm_dma_pkt[i].hv;
end
localparam MAX_PIPE_STAGES = 0 +1 + 
                             0 +1 +
                             0 +1 +
                             0 +
                             0 +
                             `CX_IDE_MAX_DELAY +
                             0 +1 ;

tlp_tracker_ms
 #(
    .N_IN              (1+1+N_XALI_IF+N_DMA_IF+N_CCIX_IF),
    .N_OUT             (N_XADM_IF),
    .MAX_PIPE_STAGES   (MAX_PIPE_STAGES)
) u_tlp_tracker_ms (
    .clk                   (core_clk                                                                                                                                                                       ),
    .rst_n                 (core_rst_n                                                                                                                                                                     ),
    .in_incoming_pkt_valid ({xaim_xadm_msg_pkt.hv, xaim_xadm_lbc_pkt.hv, xaim_xadm_xali_pkt_hv , xaim_xadm_dma_pkt_hv }),
    .in_incoming_pkt_halt  ({xadm_xaim_msg_halt,   xadm_xaim_lbc_halt,   xadm_xaim_xali_halt , xadm_xaim_dma_halt }),
    
    .in_outgoing_pkt_valid (xtlh_form_tlp_bin_eot                                                                                                                                                          ),
    .in_outgoing_pkt_halt  (tlp_bin_xtlh_form_halt                                                                                                                                                         ),
    
    .out_pkt_pending       (xadm_pm_pkt_pending                                                                                                                                                            )
);

localparam RAS_CORRECTION_EN      = 0;
localparam CPLQ_MANAGEMENT_ENABLE = 0;
localparam LOCAL_FC_PRFX          = 0 +1;
localparam IDE_ENABLE             = 0;
localparam IDE_TX_PKT_NUM         = 0;
localparam N_XADM_IDE_PIPE_CHK    = 4;


// Port Arbiter RAS Checkers are present only if:
//  - RAS Protection type is ECC with Correction enabled
localparam N_XADM_PORT_ARB_CHK       = (RAS_CORRECTION_EN == 1)? N_XADM_IF : 0;

// FC RAS Checkers are present only if :
//  - Local FC Prefix, CPL Queue Mgr and IDE are not present
//  - RAS Protection type is ECC with Correction enabled
localparam N_XADM_FC_CHK             = (((LOCAL_FC_PRFX == 0) && (CPLQ_MANAGEMENT_ENABLE == 0) && (IDE_ENABLE == 0)) || (RAS_CORRECTION_EN == 1))? N_XADM_IF : 0;

// Local FC Prefix RAS Checkers are present only if :
//  - Local FC Prefix itself is present
localparam N_XADM_LOCAL_FC_PRFX_CHK  = (LOCAL_FC_PRFX == 1)? N_XADM_IF : 0;

// CPL Queue Mgr RAS Checkers are present only if:
//  - IDE is not present
//  - RAS Protection type is ECC with Correction enabled
localparam N_XADM_CPLQ_MNG_CHK = ((IDE_ENABLE == 0) || (RAS_CORRECTION_EN == 1))? N_XADM_IF : 0;

// IDE Checkers are present if:
//  - IDE itself is present
localparam N_XADM_IDE_CHK            = (IDE_ENABLE == 1)? IDE_TX_PKT_NUM*(1+N_XADM_IDE_PIPE_CHK)+N_XADM_P_IF : 0;

// XADM XTLH Pkt Formation Checkers are present if:
//  - RAS Protection type is ECC with Correction enabled
localparam N_XADM_XTLH_PKT_FORMATION_CHK = (RAS_CORRECTION_EN == 1)? N_XADM_IF : 0;

localparam BLOCK_RAS_DP_PROT_CHK_N = 
                                     N_XADM_PORT_ARB_CHK          + // Port Arbiter RAS Checkers
                                     N_XADM_FC_CHK                + // Flow Control RAS Checkers
                                     N_XADM_LOCAL_FC_PRFX_CHK     + // Local FC Prefix RAS Checkers
                                     N_XADM_CPLQ_MNG_CHK          + // CPLQ Manager RAS Checkers
                                     N_XADM_IDE_CHK               + // IDE WRAP RAS Checkers
                                     N_XADM_XTLH_PKT_FORMATION_CHK; // XADM XTLH Packet formation
                                     
localparam RAS_DP_PROT_CHK_ID_BASE_PORT_ARB                = RAS_DP_PROT_CHK_ID_BASE_XADM ;
localparam RAS_DP_PROT_CHK_ID_BASE_FC                      = RAS_DP_PROT_CHK_ID_BASE_PORT_ARB      + N_XADM_PORT_ARB_CHK;
localparam RAS_DP_PROT_CHK_ID_BASE_LOCAL_FC_PRFX           = RAS_DP_PROT_CHK_ID_BASE_FC            + N_XADM_FC_CHK;
localparam RAS_DP_PROT_CHK_ID_BASE_CPLQ_MNG                = RAS_DP_PROT_CHK_ID_BASE_LOCAL_FC_PRFX + N_XADM_LOCAL_FC_PRFX_CHK;
localparam RAS_DP_PROT_CHK_ID_BASE_IDE_WRAP                = RAS_DP_PROT_CHK_ID_BASE_CPLQ_MNG      + N_XADM_CPLQ_MNG_CHK;
localparam RAS_DP_PROT_CHK_ID_BASE_XADM_XTLH_PKT_FORMATION = RAS_DP_PROT_CHK_ID_BASE_IDE_WRAP      + N_XADM_IDE_CHK;

ras_dp_err_log_t [BLOCK_RAS_DP_PROT_CHK_N-1:0]   ras_dp_err_log_from_checkers;

// RAS DP ERROR LOGGING ARRAY MAPPING
ras_dp_err_log_t [N_XADM_IF-1:0]                ras_dp_err_log_from_port_arb;
ras_dp_err_log_t [N_XADM_IF-1:0]                ras_dp_err_log_from_fc;
ras_dp_err_log_t [N_XADM_LOCAL_FC_PRFX_CHK-1:0] ras_dp_err_log_from_local_fc_prfx;
ras_dp_err_log_t [N_XADM_IF-1:0]                ras_dp_err_log_from_cplq_mng;
ras_dp_err_log_t [N_XADM_IF-1:0]                ras_dp_err_log_from_xadm_xtlh_pkt_formation;

logic [$clog2(BLOCK_RAS_DP_PROT_CHK_N)-1:0] CHK_OFFSET;

always_comb begin
    CHK_OFFSET = '0;
    ras_dp_err_log_from_checkers = '0;
    // Port Arbiter
    for (int slot = 0; slot < N_XADM_PORT_ARB_CHK; slot++) begin
        ras_dp_err_log_from_checkers[CHK_OFFSET] = ras_dp_err_log_from_port_arb[slot];                CHK_OFFSET=CHK_OFFSET+1;
    end
    
    // Flow Control Checker
    for (int slot = 0; slot < N_XADM_FC_CHK; slot++) begin
        ras_dp_err_log_from_checkers[CHK_OFFSET] = ras_dp_err_log_from_fc[slot];                      CHK_OFFSET=CHK_OFFSET+1;
    end

    // Local FC Prefix
    for (int slot = 0; slot < N_XADM_LOCAL_FC_PRFX_CHK; slot++) begin
        ras_dp_err_log_from_checkers[CHK_OFFSET] = ras_dp_err_log_from_local_fc_prfx[slot];           CHK_OFFSET=CHK_OFFSET+1;
    end

    // CPLQ Manager
    for (int slot = 0; slot < N_XADM_CPLQ_MNG_CHK; slot++) begin
        ras_dp_err_log_from_checkers[CHK_OFFSET] = ras_dp_err_log_from_cplq_mng[slot];                CHK_OFFSET=CHK_OFFSET+1;
    end

    
    // XADM XTLH Packet formation
    for (int slot = 0; slot < N_XADM_XTLH_PKT_FORMATION_CHK; slot++) begin
        ras_dp_err_log_from_checkers[CHK_OFFSET] = ras_dp_err_log_from_xadm_xtlh_pkt_formation[slot]; CHK_OFFSET=CHK_OFFSET+1;
    end
end

ras_dp_err_inj_t ras_dp_err_inj_to_checkers;

logic unused_out_ras_dp_wake_up;
ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N (BLOCK_RAS_DP_PROT_CHK_N)
) u_ras_dp_err_mgr (
    .clk                (core_clk                    ),
    .rst_n              (core_rst_n                  ),
    .out_ras_dp_wake_up (unused_out_ras_dp_wake_up   ),
    .in_ras_dp_err_inj  (ras_dp_err_inj              ),
    .out_ras_dp_err_inj (ras_dp_err_inj_to_checkers  ),
    .in_ras_dp_err_log  (ras_dp_err_log_from_checkers),
    .out_ras_dp_err_log (ras_dp_err_log              )
);

////////////////////////////////////////////
// 1.PORT ARBITER
// Pipeline: YES or NO
////////////////////////////////////////////
xadm_port_arb_wrap_ms
 #(
    .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE_PORT_ARB)
) u_xadm_port_arb_wrap_ms (
    .clk            (core_clk              ),
    .rst_n          (core_rst_n            ),
    .in_xali_pkt    (xaim_xadm_xali_pkt    ),
    .out_xali_halt  (xadm_xaim_xali_halt   ),
    .in_dma_pkt     (xaim_xadm_dma_pkt     ),
    .out_dma_halt   (xadm_xaim_dma_halt    ),
    .in_msg_pkt     (xaim_xadm_msg_pkt     ),
    .out_msg_halt   (xadm_xaim_msg_halt    ),
    .in_lbc_pkt     (xaim_xadm_lbc_pkt     ),
    .out_lbc_halt   (xadm_xaim_lbc_halt    ),
    .out_pkt        (port_arb_ecrc_hdr_pkt ),
    .in_halt        (ecrc_hdr_port_arb_halt)
    ,
    .ras_dp_err_log (ras_dp_err_log_from_port_arb)
    ,
    .ras_dp_err_inj (ras_dp_err_inj_to_checkers)
);

////////////////////////////////////////////
// 2.Latency Tolerance Reporting extraction stage
// Pipeline: NO
////////////////////////////////////////////
// LTR MSG TLPs have TC fixed to 0, so only VC0 Posted channels are connected to xadm_ltr_extract
xadm_ltr_extract
 #(
    .N(N_XADM_P_IF_VC[0])
) u_xadm_ltr_extract (
    .clk                  (core_clk                                    ),
    .rst_n                (core_rst_n                                  ),
    .in_pkt               (port_arb_ecrc_hdr_pkt[0+:N_XADM_P_IF_VC[0]] ),
    .out_halt             (ecrc_hdr_port_arb_halt[0+:N_XADM_P_IF_VC[0]]),
    .xadm_msg_ltr         (xadm_msg_ltr                                ),
    .xadm_msg_ltr_latency (xadm_msg_ltr_latency                        )
);

////////////////////////////////////////////
// 3.ECRC HEADER
// Pipeline: NO
////////////////////////////////////////////
xadm_ecrc_ms
 #(.N(N_XADM_IF), .IS_FOR_HDR(1), .USE_BCM49(0)) u_xadm_ecrc_ms_hdr
(
    .clk                    (core_clk               ),
    .rst_n                  (core_rst_n             ),
    .in_flit_mode_enable    (flit_mode_enable       ),
    .in_pkt                 (port_arb_ecrc_hdr_pkt  ),
    .out_halt               (ecrc_hdr_port_arb_halt ),
    .out_pkt                (ecrc_hdr_cplq_calc_pkt ),
    .in_halt                (cplq_calc_ecrc_hdr_halt));

////////////////////////////////////////////
// 4.CPLQ MANAGER PRE-STAGE LOGIC
// Pipeline: NO
////////////////////////////////////////////
assign cplq_calc_fc_chk_pkt    = ecrc_hdr_cplq_calc_pkt;
assign cplq_calc_ecrc_hdr_halt = fc_chk_cplq_calc_halt;

////////////////////////////////////////////
// 5.FLOW CONTROL CHECK
// Pipeline: YES or NO
////////////////////////////////////////////
xadm_fc_wrap_ms
 #(
    .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE_FC)
) u_xadm_fc_wrap_ms (
    .clk                       (core_clk                 ),
    .rst_n                     (core_rst_n               ),
    .rdlh_link_down            (rdlh_link_down           ),
    .in_flush                  (flush                    ),
    .cfg_max_payload_size      (cfg_max_payload_size     ),
    .cfg_vc_id                 (cfg_vc_id                ),
    .cfg_vc_enable             (cfg_vc_enable            ),
    .cfg_fc_scaled_en          (cfg_fc_scaled_en         ),
    .cfg_can_transmit_atomic   (cfg_can_transmit_atomic  ),
    .cfg_can_transmit_dmwr     (cfg_can_transmit_dmwr    ),
    .in_rtlh_fc_init_status    (rtlh_fc_init_status      ),
    .in_rtlh_rfc               (rtlh_rfc                 ),
    .in_internal_restore       (fc_restore_crdt          ),
    .out_fc_cnsmd_ph           (xadm_fc_cnsmd_ph         ),
    .out_fc_cnsmd_pd           (xadm_fc_cnsmd_pd         ),
    .out_fc_limit_ph           (xadm_fc_limit_ph         ),
    .out_fc_limit_pd           (xadm_fc_limit_pd         ),
    .out_fc_cnsmd_nph          (xadm_fc_cnsmd_nph        ),
    .out_fc_cnsmd_npd          (xadm_fc_cnsmd_npd        ),
    .out_fc_limit_nph          (xadm_fc_limit_nph        ),
    .out_fc_limit_npd          (xadm_fc_limit_npd        ),
    .out_fc_cnsmd_cplh         (xadm_fc_cnsmd_cplh       ),
    .out_fc_cnsmd_cpld         (xadm_fc_cnsmd_cpld       ),
    .out_fc_limit_cplh         (xadm_fc_limit_cplh       ),
    .out_fc_limit_cpld         (xadm_fc_limit_cpld       ),
    .out_fc_ph_cdts            (xadm_ph_cdts             ),
    .out_fc_pd_cdts            (xadm_pd_cdts             ),
    .out_fc_nph_cdts           (xadm_nph_cdts            ),
    .out_fc_npd_cdts           (xadm_npd_cdts            ),
    .out_fc_cplh_cdts          (xadm_cplh_cdts           ),
    .out_fc_cpld_cdts          (xadm_cpld_cdts           ),
    .out_fc_ph_shrd_cdts       (xadm_ph_shrd_cdts        ),
    .out_fc_pd_shrd_cdts       (xadm_pd_shrd_cdts        ),
    .out_fc_nph_shrd_cdts      (xadm_nph_shrd_cdts       ),
    .out_fc_npd_shrd_cdts      (xadm_npd_shrd_cdts       ),
    .out_fc_cplh_shrd_cdts     (xadm_cplh_shrd_cdts      ),
    .out_fc_cpld_shrd_cdts     (xadm_cpld_shrd_cdts      ),
    .out_pm_no_fc_credit       (xadm_pm_no_fc_credit     ),
    .out_pm_had_enough_credit  (xadm_pm_had_enough_credit),
    .out_rtlh_all_type_infinite(xadm_all_type_infinite   ),
    .out_fc_prot_err           (xadm_fc_prot_err         ),
    .in_pkt                    (cplq_calc_fc_chk_pkt     ),
    .out_halt                  (fc_chk_cplq_calc_halt    ),
    .out_pkt                   (fc_chk_ecrc_data_pkt     ),
    .in_halt                   (ecrc_data_fc_chk_halt    ),
    .smlh_flit_mode_enable     (credit_flit_mode_enable  )
    ,
    .ras_dp_err_log (ras_dp_err_log_from_fc)
    ,
    .ras_dp_err_inj (ras_dp_err_inj_to_checkers)
  );


////////////////////////////////////////////
// 6. ECRC DATA
// Pipeline: NO
////////////////////////////////////////////
xadm_ecrc_ms
 #(.N(N_XADM_IF), .IS_FOR_HDR(0), .USE_BCM49(0)) u_xadm_ecrc_ms_data
(
    .clk                    (core_clk               ),
    .rst_n                  (core_rst_n             ),
    .in_flit_mode_enable    (flit_mode_enable       ),
    .in_pkt                 (fc_chk_ecrc_data_pkt   ),
    .out_halt               (ecrc_data_fc_chk_halt  ),
    .out_pkt                (ecrc_data_fm_prfx_pkt ),
    .in_halt                (fm_prfx_ecrc_data_halt));

////////////////////////////////////////////
// 7. FLIT MODE LOCAL PREFIX 
// Pipeline: NO
////////////////////////////////////////////
xadm_fm_local_prefix_ms
 #(
    .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE_LOCAL_FC_PRFX)
) u_xadm_fm_local_prefix_ms(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .in_pkt     (ecrc_data_fm_prfx_pkt),
    .out_halt   (fm_prfx_ecrc_data_halt),
    .out_pkt    (fm_prfx_cplq_mng_pkt),
    .in_halt    (cplq_mng_fm_prfx_halt)
    ,
    .ras_dp_err_log (ras_dp_err_log_from_local_fc_prfx)
    ,
    .ras_dp_err_inj (ras_dp_err_inj_to_checkers)
);


////////////////////////////////////////////
// 8.CPLQ MANAGEMENT
// Pipeline: YES or NO
////////////////////////////////////////////
xadm_cplq_mng_wrap_ms
 #(
    .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE_CPLQ_MNG)
) u_xadm_cplq_mng_wrap_ms (
    .clk             (core_clk               ),
    .rst_n           (core_rst_n             ),
    .in_pkt          (fm_prfx_cplq_mng_pkt   ),
    .out_halt        (cplq_mng_fm_prfx_halt  ),
    .out_pkt         (cplq_mng_xtlh_form_pkt ),
    .in_halt         (xtlh_form_cplq_mng_halt)
    ,
    .ras_dp_err_log (ras_dp_err_log_from_cplq_mng)
    ,
    .ras_dp_err_inj (ras_dp_err_inj_to_checkers)
    );

////////////////////////////////////////////
// 9.To RADM CPL LUT and CDM
// Pipeline: NO
////////////////////////////////////////////
xadm_radm_cpl_lut_pkt_formation_ms
 u_xadm_radm_cpl_lut_pkt_formation_ms
(
    .clk                 (core_clk               ),
    .rst_n               (core_rst_n             ),
    .cfg_flit_mode_en    (flit_mode_enable       ),
    .in_pkt              (cplq_mng_xtlh_form_pkt ),
    .in_halt             (xtlh_form_cplq_mng_halt),
    .out_tx_npr          (xadm_radm_tx_npr       ),
    .out_wakeup          (xadm_radm_wakeup       ));
xadm_cdm_error_signals_ms
 u_xadm_cdm_error_signals_ms
(
    .clk             (core_clk               ),
    .rst_n           (core_rst_n             ),
    .cfg_flit_mode_en(flit_mode_enable       ),
    .in_pkt          (cplq_mng_xtlh_form_pkt ),
    .in_halt         (xtlh_form_cplq_mng_halt),
    .out_tx_errors   (xadm_xmt_pci_errors    ));
    
////////////////////////////////////////////
// 10.IDE
////////////////////////////////////////////
assign ide_xtlh_form_pkt = cplq_mng_xtlh_form_pkt;

assign xtlh_form_cplq_mng_halt = xtlh_form_ide_halt;

xadm_rasdes_tlp_tracer_ms
 u_xadm_rasdes_tlp_tracer_ms
(
    .clk                   (core_clk),
    .rst_n                 (core_rst_n),
    .in_flush              (flush),
    .in_pkt                (ide_xtlh_form_pkt),
    .in_halt               (xtlh_form_ide_halt),
    .flit_mode_enable      (flit_mode_enable),
    .xadm_rasdes_tlp_trace (xadm_rasdes_tlp_trace));

////////////////////////////////////////////
// 11.XTLH PKT Formation
// Pipeline: YES or NO
////////////////////////////////////////////
xadm_xtlh_pkt_formation_ms
 #(
    .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE_XADM_XTLH_PKT_FORMATION)
) u_xadm_xtlh_pkt_formation_ms (
    .clk                 (core_clk),
    .rst_n               (core_rst_n),
    .flit_mode_enable    (flit_mode_enable),
    .in_pkt              (ide_xtlh_form_pkt),
    .out_halt            (xtlh_form_ide_halt),
    .out_pkt             (xtlh_form_tlp_bin_pkt),
    .in_halt             (tlp_bin_xtlh_form_halt)

    ,
    .diag_ctrl           (diag_ctrl),
    .einj0_enable        (einj0_enable),
    .einj0_count         (einj0_count),
    .einj0_crc_type      (einj0_crc_type),
    .einj0_ecrc_vc_sel   (einj0_ecrc_vc_sel),
    .einj0_ecrc_fc_sel   (einj0_ecrc_fc_sel),
    .einj0_ecrc_intf_sel (einj0_ecrc_intf_sel),
    .einj0_ecrc_evt      (einj0_ecrc_evt)

    ,
    .ras_dp_err_log      (ras_dp_err_log_from_xadm_xtlh_pkt_formation)
    ,
    .ras_dp_err_inj      (ras_dp_err_inj_to_checkers)
    );

////////////////////////////////////////////
// 12.TLP BIN
// Pipeline: NO
////////////////////////////////////////////
xadm_tlp_bin_ms
 u_xadm_tlp_bin_ms
(
    .clk                        (core_clk),
    .rst_n                      (core_rst_n),
    .in_pkt                     (xtlh_form_tlp_bin_pkt),
    .out_halt                   (tlp_bin_xtlh_form_halt),
    .out_pkt                    (xadm_xtlh_pkt),
    .in_halt                    (xtlh_xadm_pkt_halt),
    .out_restore                (internal_restore_crdt)
    ,
    .flit_mode_enable           (flit_mode_enable)
    ,
    .xtlh_xadm_posted_tlp_sent  (xtlh_xadm_posted_tlp_sent)
    ,.xali_posted_tlp_sent       (xali_posted_tlp_sent)
);

endmodule

