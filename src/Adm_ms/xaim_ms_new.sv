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
// ---    $DateTime: 2024/01/19 09:25:58 $
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/xaim_ms_new.sv#7 $
// -------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// The xaim Module contains several submodules
//
// XAIM_HDR_FORM: Form PCIE tlp header received from the XALI.
//
// -----------------------------------------------------------------------------

`include "DWC_pcie_ctl_pkg.svh"
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Adm_ms/xaim_ms_pkg.svh"                
`include "products/pcie_pkg.svh"

module xaim_ms_new
import DWC_pcie_core_pkg::*;
import DWC_pcie_ctl_pkg::*;
import xaim_ms_pkg::*;
import pcie_pkg::*;
//`ifdef CX_RASDP_EN
//import DWC_pcie_ctl_pkg::RAS_DP_PROT_CHK_ID_BASE_XAIM;
//`endif // CX_RASDP_EN

                  (
  // Clocks/Resets
  input                                     core_clk,
  input                                     core_rst_n,
  // Configuration Structs
  input  xali_xaim_cfg_t                    xali_xaim_cfg,         // Configuration from Application
  input  cdm_xaim_cfg_t                     cdm_xaim_cfg,          // Configuration from CDM for Xaim
  input  cdm_atu_out_cfg_t                  cdm_atu_out_cfg,       // Configuration from CDM for ATU
  // TLP Packet Interfaces from Application/CDM/LBC
  input  xali_pkt_t         [N_XALI_IF-1:0] xali_xaim_pkt,         // From Application
  output logic              [N_XALI_IF-1:0] xaim_xali_halt,        // To Application
  input  msg_lbc_xaim_pkt_t                 msg_xaim_pkt,          // From MSG Gen  
  output logic                              xaim_msg_halt,         // To MSG Gen
  input  msg_lbc_xaim_pkt_t                 lbc_xaim_pkt,          // From LBC
  output logic                              xaim_lbc_halt,         // To LBC
  input  xaim_xali_cfg_t                    xaim_xali_cfg,
  input  radm_xaim_pkt_t [N_TRGT_NP_IF-1:0] radm_xaim_pkt,
  input logic            [N_TRGT_NP_IF-1:0] radm_xaim_halt,        // From Radm             // Halt?
  output xaim_radm_pkt_t [N_TRGT_NP_IF-1:0] xaim_radm_pkt,         // To Radm
  output xaim_xali_pkt_t [N_TRGT_NP_IF-1:0] xaim_xali_pkt,         // To Application
  // RASDP Interfaces
  output ras_dp_err_log_t                   ras_dp_err_log,
  input  ras_dp_err_inj_t                   ras_dp_err_inj,
  // RASDES Interfaces
  output logic    [$clog2(N_XALI_IF+2)-1:0] xaim_einj6_tlp_evt,
  input                                     rstctl_core_flush_req, // Flush request from Reset Controller
  output xaim_pmctrl_pkt_t                  xaim_pmctrl_pkt,       // To PM Controller
  input  pmctrl_xaim_pkt_t                  pmctrl_xaim_pkt,       // From PM Controller
  // TLP Packet Interfaces to XADM
  output xadm_pkt_t         [N_XALI_IF-1:0] xaim_xadm_xali_pkt,    // To XADM
  input                     [N_XALI_IF-1:0] xadm_xaim_xali_halt,   // From XADM
  output xadm_pkt_t                         xaim_xadm_msg_pkt,     // To XADM
  input                                     xadm_xaim_msg_halt,    // From XADM
  output xadm_pkt_t                         xaim_xadm_lbc_pkt,     // To XADM
  input                                     xadm_xaim_lbc_halt     // From XADM
);

// Logic Defines
xaim_pkt_t                   [N_XALI_P_IF-1:0] xali_xaim_pkt_p;
logic                        [N_XALI_P_IF-1:0] xaim_xali_halt_p;
xaim_pkt_t                  [N_XALI_NP_IF-1:0] xali_xaim_pkt_np;
logic                       [N_XALI_NP_IF-1:0] xaim_xali_halt_np;
xaim_pkt_t                 [N_XALI_CPL_IF-1:0] xali_xaim_pkt_cpl;
logic                      [N_XALI_CPL_IF-1:0] xaim_xali_halt_cpl;
xaim_pkt_t                                     lbc_xaim_pkt_new;
xaim_pkt_t                                     msg_xaim_pkt_new;

xadm_pkt_t                   [N_XALI_P_IF-1:0] xaim_xadm_xali_pkt_p;
logic                        [N_XALI_P_IF-1:0] xadm_xaim_xali_halt_p;
xadm_pkt_t                  [N_XALI_NP_IF-1:0] xaim_xadm_xali_pkt_np;
logic                       [N_XALI_NP_IF-1:0] xadm_xaim_xali_halt_np;
xadm_pkt_t                 [N_XALI_CPL_IF-1:0] xaim_xadm_xali_pkt_cpl;
logic                      [N_XALI_CPL_IF-1:0] xadm_xaim_xali_halt_cpl;

logic                          [N_XALI_IF+1:0] in_incoming_pkt_valid;
logic                          [N_XALI_IF+1:0] in_incoming_pkt_halt;
logic                          [N_XALI_IF+1:0] in_outgoing_pkt_valid;
logic                          [N_XALI_IF+1:0] in_outgoing_pkt_halt;

ras_dp_err_log_t [N_XALI_P_IF-1:0]  [ACT_NLOGS_P_NP-1:0] ras_dp_err_log_p;
ras_dp_err_log_t [N_XALI_NP_IF-1:0] [ACT_NLOGS_P_NP-1:0] ras_dp_err_log_np;
ras_dp_err_log_t [N_XALI_CPL_IF-1:0] [ACT_NLOGS_CPL-1:0] ras_dp_err_log_cpl;
ras_dp_err_log_t                     [ACT_NLOGS_MSG-1:0] ras_dp_err_log_msg;
ras_dp_err_log_t                     [ACT_NLOGS_LBC-1:0] ras_dp_err_log_lbc;

ras_dp_err_log_t [BLOCK_RAS_DP_PROT_CHK_N-1:0] ras_dp_err_log_from_checkers;
ras_dp_err_inj_t                               ras_dp_err_inj_to_checkers;

logic                        [N_XALI_P_IF-1:0] xaim_einj6_tlp_evt_p;
logic                       [N_XALI_NP_IF-1:0] xaim_einj6_tlp_evt_np;
logic                      [N_XALI_CPL_IF-1:0] xaim_einj6_tlp_evt_cpl;
logic                                          xaim_einj6_tlp_evt_msg;
logic                                          xaim_einj6_tlp_evt_lbc;

///////////////////////////////////////////////
// XALI/XADM IO Muxing
///////////////////////////////////////////////
always_comb begin : io_muxing
  for (int i=0; i<N_XALI_P_IF; i++) begin : p
    xali_xaim_pkt_p[i]                   = f_xali_to_xaim ( cdm_xaim_cfg.mode, xali_xaim_pkt[i] );                // Posted TLPs from Application to ATU/Header Formation
    xaim_xali_halt[i]                    = xaim_xali_halt_p[i];                                                   // "      Halts from ATU/Header Formation to Application
    xaim_xadm_xali_pkt[i]                = xaim_xadm_xali_pkt_p[i];                                               // "      TLPs from ATU/Header Formation to XADM
    xadm_xaim_xali_halt_p[i]             = xadm_xaim_xali_halt[i];                                                // "      Halts from XADM to ATU/Header Formation
  end

  for (int i=0; i<N_XALI_NP_IF; i++) begin : np
    xali_xaim_pkt_np[i]                  = f_xali_to_xaim ( cdm_xaim_cfg.mode, xali_xaim_pkt[i+N_XALI_P_IF] );    // Non-Posted TLPs from Application to ATU/Header Formation
    xaim_xali_halt[i+N_XALI_P_IF]        = xaim_xali_halt_np[i];                                                  // "          Halts from ATU/Header Formation to Application
    xaim_xadm_xali_pkt[i+N_XALI_P_IF]    = xaim_xadm_xali_pkt_np[i];                                              // "          TLPs from ATU/Header Formation to XADM
    xadm_xaim_xali_halt_np[i]            = xadm_xaim_xali_halt[i+N_XALI_P_IF];                                    // "          Halts from XADM to ATU/Header Formation
  end

  for (int i=0; i<N_XALI_CPL_IF; i++) begin : cpl
    xali_xaim_pkt_cpl[i]                 = f_xali_to_xaim ( cdm_xaim_cfg.mode, xali_xaim_pkt[i+N_XALI_P_NP_IF] ); // Completion TLPs from Application to Target CPL LUT/Header Formation
    xaim_xali_halt[i+N_XALI_P_NP_IF]     = xaim_xali_halt_cpl[i];                                                 // "          Halts from CPL LUT/Header Formation to Application
    xaim_xadm_xali_pkt[i+N_XALI_P_NP_IF] = xaim_xadm_xali_pkt_cpl[i];                                             // "          TLPs from CPL LUT/Header Formation to XADM
    xadm_xaim_xali_halt_cpl[i]           = xadm_xaim_xali_halt[i+N_XALI_P_NP_IF];                                 // "          Halts from XADM to Target CPL LUT/Header Formation
  end

  lbc_xaim_pkt_new = f_msglbc_to_xaim ( lbc_xaim_pkt );                                                           // Completion TLPs from LBC
  msg_xaim_pkt_new = f_msglbc_to_xaim ( msg_xaim_pkt );                                                           // Message TLPs from Message Gen
end

///////////////////////////////////////////////
// RASDP Error Log Muxing
///////////////////////////////////////////////
localparam P_OFFSET    = ACT_NLOGS_P_NP * N_XALI_P_IF;
localparam NP_OFFSET   = ACT_NLOGS_P_NP * N_XALI_NP_IF;
localparam P_NP_OFFSET = P_OFFSET + NP_OFFSET;
localparam CPL_OFFSET  = ACT_NLOGS_CPL  * N_XALI_CPL_IF;
localparam MSG_OFFSET  = ACT_NLOGS_MSG;
localparam LBC_OFFSET  = ACT_NLOGS_LBC;

always_comb begin : rasdp_muxing
  ras_dp_err_log_from_checkers = '0;

  for (int i=0; i<N_XALI_P_IF; i++) begin    // No of P Interfaces
    ras_dp_err_log_from_checkers[i*ACT_NLOGS_P_NP+:ACT_NLOGS_P_NP]               = ras_dp_err_log_p[i];
  end
  for (int i=0; i<N_XALI_NP_IF; i++) begin    // No of NP Interfaces
    ras_dp_err_log_from_checkers[(i*ACT_NLOGS_P_NP+P_OFFSET)+:ACT_NLOGS_P_NP]    = ras_dp_err_log_np[i];
  end
  for (int i=0; i<N_XALI_CPL_IF; i++) begin  // No of CPL Interfaces
    ras_dp_err_log_from_checkers[(i*ACT_NLOGS_CPL+P_NP_OFFSET)+:ACT_NLOGS_CPL]   = ras_dp_err_log_cpl[i];
  end
  ras_dp_err_log_from_checkers[P_NP_OFFSET+CPL_OFFSET+:ACT_NLOGS_MSG]            = ras_dp_err_log_msg;
  ras_dp_err_log_from_checkers[P_NP_OFFSET+CPL_OFFSET+MSG_OFFSET+:ACT_NLOGS_LBC] = ras_dp_err_log_lbc;
end

logic unused_out_ras_dp_wake_up;
ras_dp_err_mgr
 #(
  .BLOCK_RAS_DP_PROT_CHK_N (BLOCK_RAS_DP_PROT_CHK_N)
) u_ras_dp_err_mgr (
  .clk                ( core_clk                         ),
  .rst_n              ( core_rst_n                       ),
  .out_ras_dp_wake_up (unused_out_ras_dp_wake_up         ),
  .in_ras_dp_err_inj  ( ras_dp_err_inj                   ),
  .out_ras_dp_err_inj ( ras_dp_err_inj_to_checkers       ),
  .in_ras_dp_err_log  ( ras_dp_err_log_from_checkers     ),
  .out_ras_dp_err_log ( ras_dp_err_log                   )
);

///////////////////////////////////////////////
// RASDES Error Event Muxing
///////////////////////////////////////////////
assign xaim_einj6_tlp_evt = f_to_int({xaim_einj6_tlp_evt_lbc, xaim_einj6_tlp_evt_msg, xaim_einj6_tlp_evt_cpl, xaim_einj6_tlp_evt_np, xaim_einj6_tlp_evt_p});

///////////////////////////////////////////////
// XALI Posted Channel
///////////////////////////////////////////////
xaim_channel_ms
 #(
  .ATU_IPIPE_BPG_EN_PRFX   ( P_NP_ATU_IPIPE_BPG_EN_PRFX  ),
  .ATU_CPIPE_BPG_EN_PRFX   ( P_NP_ATU_CPIPE_BPG_EN_PRFX  ),
  .ATU_OPIPE_BPG_EN_PRFX   ( P_NP_ATU_OPIPE_BPG_EN_PRFX  ),
  .ATU_IPIPE_BPG_EN_HDR    ( P_NP_ATU_IPIPE_BPG_EN_HDR   ),
  .ATU_IPIPE_BPG_EN_DATA   ( P_NP_ATU_IPIPE_BPG_EN_DATA  ),
  .ATU_IPIPE_BPC_EN        ( P_NP_ATU_IPIPE_BPC_EN       ),
  .ATU_CPIPE_BPG_EN_HDR    ( P_NP_ATU_CPIPE_BPG_EN_HDR   ),
  .ATU_CPIPE_BPG_EN_DATA   ( P_NP_ATU_CPIPE_BPG_EN_DATA  ),
  .ATU_CPIPE_BPC_EN        ( P_NP_ATU_CPIPE_BPC_EN       ),
  .ATU_OPIPE_BPG_EN_HDR    ( P_NP_ATU_OPIPE_BPG_EN_HDR   ),
  .ATU_OPIPE_BPG_EN_DATA   ( P_NP_ATU_OPIPE_BPG_EN_DATA  ),
  .ATU_OPIPE_BPC_EN        ( P_NP_ATU_OPIPE_BPC_EN       ),
  .ATU_IPIPE_EN            ( P_NP_ATU_IPIPE_EN           ),
  .ATU_CPIPE_EN            ( P_NP_ATU_CPIPE_EN           ),
  .ATU_OPIPE_EN            ( P_NP_ATU_OPIPE_EN           ),
  .HDR_IPIPE_BPG_EN_PRFX   ( P_NP_HDR_IPIPE_BPG_EN_PRFX  ),
  .HDR_IPIPE_BPG_EN_HDR    ( P_NP_HDR_IPIPE_BPG_EN_HDR   ),
  .HDR_IPIPE_BPG_EN_DATA   ( P_NP_HDR_IPIPE_BPG_EN_DATA  ),
  .HDR_IPIPE_BPC_EN        ( P_NP_HDR_IPIPE_BPC_EN       ),
  .HDR_IPIPE_BPC_EN_PRFX   ( P_NP_HDR_IPIPE_BPC_EN_PRFX  ),
  .HDR_CPIPE_BPG_EN        ( P_NP_HDR_CPIPE_BPG_EN       ),
  .HDR_CPIPE_BPC_EN        ( P_NP_HDR_CPIPE_BPC_EN       ),
  .HDR_OPIPE_BPG_EN        ( P_NP_HDR_OPIPE_BPG_EN       ),
  .HDR_OPIPE_BPC_EN        ( P_NP_HDR_OPIPE_BPC_EN       ),
  .RAS_DP_ID_BASE_ATU      ( RAS_DP_ID_BASE_P_ATU        ),
  .RAS_DP_ID_BASE_HDR      ( RAS_DP_ID_BASE_P_HDR        ),
  .N_LOGS                  ( ACT_NLOGS_P_NP              ),
  .HDR_IPIPE_EN            ( P_NP_HDR_IPIPE_EN           ),
  .HDR_CPIPE_EN            ( P_NP_HDR_CPIPE_EN           ),
  .HDR_OPIPE_EN            ( P_NP_HDR_OPIPE_EN           ),
  .N_CHAN                  ( N_XALI_P_IF                 ),
  .FC_TYPE                 ( E_P                         ),
  .PORT_E                  ( E_TX_PORT_ID_XALI           )
) U_xali_channel_p_ms ( 
  .core_clk,
  .core_rst_n,
  .xali_xaim_cfg,
  .cdm_xaim_cfg,
  .cdm_atu_out_cfg,
  .vc_in                   ( '0                          ),
  .rstctl_core_flush_req,
  .pmctrl_xaim_pkt,
  .xaim_xali_cfg,
  .radm_xaim_pkt,
  .radm_xaim_halt,
  .xaim_radm_pkt           ( ),
  .xaim_xali_pkt           ( ),
  .ras_dp_err_log          ( ras_dp_err_log_p            ),
  .ras_dp_err_inj          ( ras_dp_err_inj_to_checkers  ),
  .xaim_einj6_tlp_evt      ( xaim_einj6_tlp_evt_p        ),
  .i_xaim_pkt              ( xali_xaim_pkt_p             ),
  .o_xaim_halt             ( xaim_xali_halt_p            ), 
  .o_xaim_pkt              ( xaim_xadm_xali_pkt_p        ),
  .i_xaim_halt             ( xadm_xaim_xali_halt_p       )
);

///////////////////////////////////////////////
// XALI Non-Posted Channel
///////////////////////////////////////////////
xaim_channel_ms
 #(
  .ATU_IPIPE_BPG_EN_PRFX   ( P_NP_ATU_IPIPE_BPG_EN_PRFX  ),
  .ATU_CPIPE_BPG_EN_PRFX   ( P_NP_ATU_CPIPE_BPG_EN_PRFX  ),
  .ATU_OPIPE_BPG_EN_PRFX   ( P_NP_ATU_OPIPE_BPG_EN_PRFX  ),
  .ATU_IPIPE_BPG_EN_HDR    ( P_NP_ATU_IPIPE_BPG_EN_HDR   ),
  .ATU_IPIPE_BPG_EN_DATA   ( P_NP_ATU_IPIPE_BPG_EN_DATA  ),
  .ATU_IPIPE_BPC_EN        ( P_NP_ATU_IPIPE_BPC_EN       ),
  .ATU_CPIPE_BPG_EN_HDR    ( P_NP_ATU_CPIPE_BPG_EN_HDR   ),
  .ATU_CPIPE_BPG_EN_DATA   ( P_NP_ATU_CPIPE_BPG_EN_DATA  ),
  .ATU_CPIPE_BPC_EN        ( P_NP_ATU_CPIPE_BPC_EN       ),
  .ATU_OPIPE_BPG_EN_HDR    ( P_NP_ATU_OPIPE_BPG_EN_HDR   ),
  .ATU_OPIPE_BPG_EN_DATA   ( P_NP_ATU_OPIPE_BPG_EN_DATA  ),
  .ATU_OPIPE_BPC_EN        ( P_NP_ATU_OPIPE_BPC_EN       ),
  .ATU_IPIPE_EN            ( P_NP_ATU_IPIPE_EN           ),
  .ATU_CPIPE_EN            ( P_NP_ATU_CPIPE_EN           ),
  .ATU_OPIPE_EN            ( P_NP_ATU_OPIPE_EN           ),
  .HDR_IPIPE_BPG_EN_PRFX   ( P_NP_HDR_IPIPE_BPG_EN_PRFX  ),
  .HDR_IPIPE_BPG_EN_HDR    ( P_NP_HDR_IPIPE_BPG_EN_HDR   ),
  .HDR_IPIPE_BPG_EN_DATA   ( P_NP_HDR_IPIPE_BPG_EN_DATA  ),
  .HDR_IPIPE_BPC_EN        ( P_NP_HDR_IPIPE_BPC_EN       ),
  .HDR_IPIPE_BPC_EN_PRFX   ( P_NP_HDR_IPIPE_BPC_EN_PRFX  ),
  .HDR_CPIPE_BPG_EN        ( P_NP_HDR_CPIPE_BPG_EN       ),
  .HDR_CPIPE_BPC_EN        ( P_NP_HDR_CPIPE_BPC_EN       ),
  .HDR_OPIPE_BPG_EN        ( P_NP_HDR_OPIPE_BPG_EN       ),
  .HDR_OPIPE_BPC_EN        ( P_NP_HDR_OPIPE_BPC_EN       ),
  .RAS_DP_ID_BASE_ATU      ( RAS_DP_ID_BASE_NP_ATU       ),
  .RAS_DP_ID_BASE_HDR      ( RAS_DP_ID_BASE_NP_HDR       ),
  .N_LOGS                  ( ACT_NLOGS_P_NP              ),
  .HDR_IPIPE_EN            ( P_NP_HDR_IPIPE_EN           ),
  .HDR_CPIPE_EN            ( P_NP_HDR_CPIPE_EN           ),
  .HDR_OPIPE_EN            ( P_NP_HDR_OPIPE_EN           ),
  .N_CHAN                  ( N_XALI_NP_IF                ),
  .FC_TYPE                 ( E_NP                        ),
  .PORT_E                  ( E_TX_PORT_ID_XALI           )
) U_xali_channel_np_ms (
  .core_clk,
  .core_rst_n,
  .xali_xaim_cfg,
  .cdm_xaim_cfg,
  .cdm_atu_out_cfg,
  .vc_in                   ( '0                          ),
  .rstctl_core_flush_req,
  .pmctrl_xaim_pkt,
  .xaim_xali_cfg,
  .radm_xaim_pkt,
  .radm_xaim_halt,
  .xaim_radm_pkt           ( ),
  .xaim_xali_pkt           ( ),
  .ras_dp_err_log          ( ras_dp_err_log_np           ),
  .ras_dp_err_inj          ( ras_dp_err_inj_to_checkers  ),
  .xaim_einj6_tlp_evt      ( xaim_einj6_tlp_evt_np       ),
  .i_xaim_pkt              ( xali_xaim_pkt_np            ),
  .o_xaim_halt             ( xaim_xali_halt_np           ),
  .o_xaim_pkt              ( xaim_xadm_xali_pkt_np       ),
  .i_xaim_halt             ( xadm_xaim_xali_halt_np      )
);

///////////////////////////////////////////////
// XALI Completion Channel
///////////////////////////////////////////////
xali_xaim_cpl_ms
 #(
  .N_LOGS                  ( ACT_NLOGS_CPL               ),
  .RAS_DP_ID_BASE_CPL_TLUT ( RAS_DP_ID_BASE_CPL_TLUT     ),
  .RAS_DP_ID_BASE_CPL_HDR  ( RAS_DP_ID_BASE_CPL_HDR      ),
  .N_XALI_CPL_IF           ( N_XALI_CPL_IF               )
) U_xali_xaim_cpl_ms (
  .core_clk,
  .core_rst_n,
  .xali_xaim_cfg,
  .cdm_xaim_cfg,
  .vc_in                   ( '0                          ),
  .rstctl_core_flush_req,
  .pmctrl_xaim_pkt,
  .xaim_xali_cfg,
  .radm_xaim_pkt,           
  .radm_xaim_halt,
  .xaim_radm_pkt,
  .xaim_xali_pkt,
  .ras_dp_err_log          ( ras_dp_err_log_cpl          ),
  .ras_dp_err_inj          ( ras_dp_err_inj_to_checkers  ),
  .xaim_einj6_tlp_evt      ( xaim_einj6_tlp_evt_cpl      ),
  .i_xaim_pkt              ( xali_xaim_pkt_cpl           ),
  .o_xaim_halt             ( xaim_xali_halt_cpl          ),
  .o_xaim_pkt              ( xaim_xadm_xali_pkt_cpl      ),
  .i_xaim_halt             ( xadm_xaim_xali_halt_cpl     )
);

///////////////////////////////////////////////
// MSG Gen Channel
///////////////////////////////////////////////
xaim_channel_ms
 #(
  .HDR_IPIPE_BPG_EN_PRFX   ( MSG_HDR_IPIPE_BPG_EN_PRFX   ),
  .HDR_IPIPE_BPG_EN_HDR    ( MSG_HDR_IPIPE_BPG_EN_HDR    ),
  .HDR_IPIPE_BPG_EN_DATA   ( MSG_HDR_IPIPE_BPG_EN_DATA   ),
  .HDR_IPIPE_BPC_EN        ( MSG_HDR_IPIPE_BPC_EN        ),
  .HDR_IPIPE_BPC_EN_PRFX   ( MSG_HDR_IPIPE_BPC_EN_PRFX   ),
  .HDR_CPIPE_BPG_EN        ( MSG_HDR_CPIPE_BPG_EN        ),
  .HDR_CPIPE_BPC_EN        ( MSG_HDR_CPIPE_BPC_EN        ),
  .HDR_OPIPE_BPG_EN        ( MSG_HDR_OPIPE_BPG_EN        ),
  .HDR_OPIPE_BPC_EN        ( MSG_HDR_OPIPE_BPC_EN        ),
  .RAS_DP_ID_BASE_HDR      ( RAS_DP_ID_BASE_MSG_HDR      ),
  .N_LOGS                  ( ACT_NLOGS_MSG               ),
  .HDR_IPIPE_EN            ( MSG_HDR_IPIPE_EN            ),
  .HDR_CPIPE_EN            ( MSG_HDR_CPIPE_EN            ),
  .HDR_OPIPE_EN            ( MSG_HDR_OPIPE_EN            ),
  .N_CHAN                  ( 1                           ),
  .FC_TYPE                 ( E_FC_NONE                   ),
  .PORT_E                  ( E_TX_PORT_ID_MSG            )
) U_xaim_msg_ms (
  .core_clk,
  .core_rst_n,
  .xali_xaim_cfg,
  .cdm_xaim_cfg,
  .cdm_atu_out_cfg,
  .vc_in                   ( '0                          ),
  .rstctl_core_flush_req,
  .pmctrl_xaim_pkt,
  .xaim_xali_cfg,
  .radm_xaim_pkt,
  .radm_xaim_halt,
  .xaim_radm_pkt           ( ),
  .xaim_xali_pkt           ( ),
  .ras_dp_err_log          ( ras_dp_err_log_msg          ),
  .ras_dp_err_inj          ( ras_dp_err_inj_to_checkers  ),
  .xaim_einj6_tlp_evt      ( xaim_einj6_tlp_evt_msg      ),
  .i_xaim_pkt              ( msg_xaim_pkt_new            ),
  .o_xaim_halt             ( xaim_msg_halt               ),
  .o_xaim_pkt              ( xaim_xadm_msg_pkt           ),
  .i_xaim_halt             ( xadm_xaim_msg_halt          )
);

///////////////////////////////////////////////
// LBC Channel
///////////////////////////////////////////////
xaim_channel_ms
 #(
  .HDR_IPIPE_BPG_EN_PRFX   ( LBC_HDR_IPIPE_BPG_EN_PRFX   ),
  .HDR_IPIPE_BPG_EN_HDR    ( LBC_HDR_IPIPE_BPG_EN_HDR    ),
  .HDR_IPIPE_BPG_EN_DATA   ( LBC_HDR_IPIPE_BPG_EN_DATA   ),
  .HDR_IPIPE_BPC_EN        ( LBC_HDR_IPIPE_BPC_EN        ),
  .HDR_IPIPE_BPC_EN_PRFX   ( LBC_HDR_IPIPE_BPC_EN_PRFX   ),
  .HDR_CPIPE_BPG_EN        ( LBC_HDR_CPIPE_BPG_EN        ),
  .HDR_CPIPE_BPC_EN        ( LBC_HDR_CPIPE_BPC_EN        ),
  .HDR_OPIPE_BPG_EN        ( LBC_HDR_OPIPE_BPG_EN        ),
  .HDR_OPIPE_BPC_EN        ( LBC_HDR_OPIPE_BPC_EN        ),
  .RAS_DP_ID_BASE_HDR      ( RAS_DP_ID_BASE_LBC_HDR      ),
  .N_LOGS                  ( ACT_NLOGS_LBC               ),
  .HDR_IPIPE_EN            ( LBC_HDR_IPIPE_EN            ),
  .HDR_CPIPE_EN            ( LBC_HDR_CPIPE_EN            ),
  .HDR_OPIPE_EN            ( LBC_HDR_OPIPE_EN            ),
  .N_CHAN                  ( 1                           ),
  .FC_TYPE                 ( E_FC_NONE                   ),
  .PORT_E                  ( E_TX_PORT_ID_LBC            )
) U_xaim_lbc_ms (
  .core_clk,
  .core_rst_n,
  .xali_xaim_cfg,
  .cdm_xaim_cfg,
  .cdm_atu_out_cfg,
  .vc_in                   ( '0                          ),
  .rstctl_core_flush_req,
  .pmctrl_xaim_pkt,
  .xaim_xali_cfg,
  .radm_xaim_pkt,
  .radm_xaim_halt,
  .xaim_radm_pkt           ( ),
  .xaim_xali_pkt           ( ),
  .ras_dp_err_log          ( ras_dp_err_log_lbc          ),
  .ras_dp_err_inj          ( ras_dp_err_inj_to_checkers  ),
  .xaim_einj6_tlp_evt      ( xaim_einj6_tlp_evt_lbc      ),
  .i_xaim_pkt              ( lbc_xaim_pkt_new            ),
  .o_xaim_halt             ( xaim_lbc_halt               ),
  .o_xaim_pkt              ( xaim_xadm_lbc_pkt           ),
  .i_xaim_halt             ( xadm_xaim_lbc_halt          )
);

///////////////////////////////////////////////
// TLP Tracker
///////////////////////////////////////////////
always_comb begin
  in_incoming_pkt_valid[N_XALI_IF+1-:2] = { msg_xaim_pkt.hv,      lbc_xaim_pkt.hv      };
  in_incoming_pkt_halt[N_XALI_IF+1-:2]  = { xaim_msg_halt,        xaim_lbc_halt        };
  in_outgoing_pkt_valid[N_XALI_IF+1-:2] = { xaim_xadm_msg_pkt.hv, xaim_xadm_lbc_pkt.hv };
  in_outgoing_pkt_halt[N_XALI_IF+1-:2]  = { xadm_xaim_msg_halt,   xadm_xaim_lbc_halt   };
  for (int i=0; i<N_XALI_IF; i++ ) begin
    in_incoming_pkt_valid[i] = xali_xaim_pkt[i].hdr.tlp_hv;
    in_incoming_pkt_halt[i]  = xaim_xali_halt[i];
    in_outgoing_pkt_valid[i] = xaim_xadm_xali_pkt[i].eot;
    in_outgoing_pkt_halt[i]  = xadm_xaim_xali_halt[i];
  end
end

tlp_tracker_ms
 #(
  .N_IN                  ( N_XALI_IF+2             ), // +2 for LBC+MSG Channels
  .N_OUT                 ( N_XALI_IF+2             ),
  .MAX_PIPE_STAGES       ( 5                       )
) U_tlp_tracker_ms (
  .clk                   ( core_clk                ),
  .rst_n                 ( core_rst_n              ),
  .in_incoming_pkt_valid,
  .in_incoming_pkt_halt,
  .in_outgoing_pkt_valid,
  .in_outgoing_pkt_halt,
  .out_pkt_pending       ( xaim_pmctrl_pkt.pkt_pending )
);

function automatic logic [$clog2(N_XALI_IF+2)-1:0] f_to_int (
  input [N_XALI_IF+1:0] data
);
  begin
    int to_int = 0;
    for (int i=0; i<N_XALI_IF+2; i++) begin
      if (data[i])
        to_int = to_int + 1;
    end
    f_to_int = ($clog2(N_XALI_IF+2))'(to_int);
  end
endfunction // f_to_int

endmodule // xaim_ms_new
