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
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/xaim_channel_ms.sv#4 $
// -------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// This module handles the processing of all TLPs through the XAIM
//
// -----------------------------------------------------------------------------

`include "DWC_pcie_ctl_pkg.svh"
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Adm_ms/xaim_ms_pkg.svh"
`include "products/pcie_pkg.svh"

module xaim_channel_ms
import DWC_pcie_core_pkg::*;
import DWC_pcie_ctl_pkg::*;
import xaim_ms_pkg::*;
import pcie_pkg::*;
#(
  parameter ATU_IPIPE_BPG_EN_PRFX = 0,
  parameter ATU_CPIPE_BPG_EN_PRFX = 0,
  parameter ATU_OPIPE_BPG_EN_PRFX = 0,
  parameter ATU_IPIPE_BPG_EN_HDR  = 0,
  parameter ATU_IPIPE_BPG_EN_DATA = 0,
  parameter ATU_IPIPE_BPC_EN      = 0,
  parameter ATU_CPIPE_BPG_EN_HDR  = 0,
  parameter ATU_CPIPE_BPG_EN_DATA = 0,
  parameter ATU_CPIPE_BPC_EN      = 0,
  parameter ATU_OPIPE_BPG_EN_HDR  = 0,
  parameter ATU_OPIPE_BPG_EN_DATA = 0,
  parameter ATU_OPIPE_BPC_EN      = 0,
  parameter ATU_IPIPE_EN          = 0,
  parameter ATU_CPIPE_EN          = 0,
  parameter ATU_OPIPE_EN          = 0,

  parameter TLUT_IPIPE_BPG_EN_PRFX = 0,
  parameter TLUT_OPIPE_BPG_EN_PRFX = 0,
  parameter TLUT_IPIPE_BPG_EN_HDR  = 0,
  parameter TLUT_IPIPE_BPG_EN_DATA = 0,
  parameter TLUT_IPIPE_BPC_EN      = 0,
  parameter TLUT_OPIPE_BPG_EN_HDR  = 0,
  parameter TLUT_OPIPE_BPG_EN_DATA = 0,
  parameter TLUT_OPIPE_BPC_EN      = 0,
  parameter TLUT_IPIPE_EN          = 0,
  parameter TLUT_OPIPE_EN          = 0,

  parameter HDR_IPIPE_BPG_EN_PRFX  = 0,
  parameter HDR_IPIPE_BPG_EN_HDR   = 0,
  parameter HDR_IPIPE_BPG_EN_DATA  = 0,
  parameter HDR_IPIPE_BPC_EN       = 0,
  parameter HDR_IPIPE_BPC_EN_PRFX  = 0,
  parameter HDR_CPIPE_BPG_EN       = 0,
  parameter HDR_CPIPE_BPC_EN       = 0,
  parameter HDR_OPIPE_BPG_EN       = 0,
  parameter HDR_OPIPE_BPC_EN       = 0,
  parameter HDR_IPIPE_EN           = 0,
  parameter HDR_CPIPE_EN           = 0,
  parameter HDR_OPIPE_EN           = 1,
  

  parameter RAS_DP_ID_BASE_ATU  = 0,
  parameter RAS_DP_ID_BASE_TLUT = 0,
  parameter RAS_DP_ID_BASE_HDR  = 0,
  parameter N_LOGS              = 1,
  parameter N_CHAN              = 1,
  parameter N_TRGT              = 1,
  parameter fc_type_e FC_TYPE   = E_P,
  parameter tx_port_id_e PORT_E = E_TX_PORT_ID_LBC
) 
                      (
  // Clocks/Resets
  input                                             core_clk,
  input                                             core_rst_n,
  // Configuration Structs
  input  xali_xaim_cfg_t                            xali_xaim_cfg,         // Configuration from Application
  input  cdm_xaim_cfg_t                             cdm_xaim_cfg,          // Configuration from CDM for xaim
  input  cdm_atu_out_cfg_t                          cdm_atu_out_cfg,       // Configuration from CDM for ATU
  input                   [N_CHAN-1:0] [NVC_WD-1:0] vc_in,
  input                                             rstctl_core_flush_req, // Flush request from Reset Controller
  input  pmctrl_xaim_pkt_t                          pmctrl_xaim_pkt,
  input  xaim_xali_cfg_t                            xaim_xali_cfg,         // Should be output???
  input  radm_xaim_pkt_t               [N_TRGT-1:0] radm_xaim_pkt,         // From RADM
  input  logic                         [N_TRGT-1:0] radm_xaim_halt,        // From RADM
  output xaim_radm_pkt_t               [N_TRGT-1:0] xaim_radm_pkt,         // To RADM
  output xaim_xali_pkt_t               [N_TRGT-1:0] xaim_xali_pkt,         // To Application
  output ras_dp_err_log_t [N_CHAN-1:0] [N_LOGS-1:0] ras_dp_err_log,
  input  ras_dp_err_inj_t                           ras_dp_err_inj,
  output logic            [N_CHAN-1:0]              xaim_einj6_tlp_evt,
  // TLP Packet Interfaces from Application
  input  xaim_pkt_t       [N_CHAN-1:0]              i_xaim_pkt,
  output logic            [N_CHAN-1:0]              o_xaim_halt,
  // TLP Packet Interfaces to XADM
  output xadm_pkt_t       [N_CHAN-1:0]              o_xaim_pkt,
  input  logic            [N_CHAN-1:0]              i_xaim_halt
);

// Parameter Defines
localparam ATU_ENABLE  = ((PORT_E == E_TX_PORT_ID_XALI) && ((FC_TYPE == E_P) || (FC_TYPE == E_NP))) ? 1 : 0;
localparam TLUT_ENABLE = ((PORT_E == E_TX_PORT_ID_XALI) && (FC_TYPE == E_CPL)) ? 1 : 0;

// Logic Defines
xaim_pkt_t       [N_CHAN-1:0]       flush_out_pkt;
logic            [N_CHAN-1:0]       flush_in_halt;
xaim_pkt_t       [N_CHAN-1:0]       int_stage_pkt;
logic            [N_CHAN-1:0]       int_stage_halt;
xaim_pkt_t       [N_CHAN-1:0]       hdr_in_pkt;
logic            [N_CHAN-1:0]       hdr_out_halt;
//In case of seperated trailer bus, add 3 for atu IPIPE/CPIPE/OPIPE of trailer 
ras_dp_err_log_t [N_CHAN-1:0] [8:0] ras_dp_err_log_atu; 
//In case of seperated trailer bus, add 2 for tlut IPIPE/OPIPE and CPIPE of trailer
ras_dp_err_log_t [N_CHAN-1:0] [8:0] ras_dp_err_log_tlut;
//In case of seperated trailer bus, add 1 for hdr_form IPIPE of trailer
ras_dp_err_log_t [N_CHAN-1:0] [4:0] ras_dp_err_log_hdr;

////////////////////////////////////////////
// TLP Halt Manager
////////////////////////////////////////////
generate
  for (genvar i=0; i<N_CHAN; i++) begin : flush_manager
    xaim_flush_mgr_ms
     #(
      .FC_TYPE                      ( FC_TYPE                                   ),
      .PORT_E                       ( PORT_E                                    )
    ) U_xaim_flush_mgr_ms (
      .clk                          ( core_clk                                  ),
      .rst_n                        ( core_rst_n                                ),
      .in_flush                     ( rstctl_core_flush_req                     ),
      .pm_xtlh_block_tlp            ( pmctrl_xaim_pkt.xtlh_block_tlp            ),
      .pm_block_all_tlp             ( pmctrl_xaim_pkt.block_all_tlp             ),
      .cfg_client_p_block_new_tlp   ( cdm_xaim_cfg.cfg_client_p_block_new_tlp   ),
      .cfg_client_np_block_new_tlp  ( cdm_xaim_cfg.cfg_client_np_block_new_tlp  ),
      .cfg_client_cpl_block_new_tlp ( cdm_xaim_cfg.cfg_client_cpl_block_new_tlp ),
      .in_pkt                       ( i_xaim_pkt[i]                             ),
      .out_halt                     ( o_xaim_halt[i]                            ),
      .out_pkt                      ( flush_out_pkt[i]                          ),
      .in_halt                      ( flush_in_halt[i]                          )
    );
  end
endgenerate

generate
  if ( ATU_ENABLE == 1 ) begin : address_translation_unit
    ///////////////////////////////////////////////
    // Address Translation Unit
    ///////////////////////////////////////////////
    atu_out_ms
     #(
      .N                            ( N_CHAN                                    ),
      .IPIPE_BPG_EN_PRFX            ( ATU_IPIPE_BPG_EN_PRFX                     ),
      .CPIPE_BPG_EN_PRFX            ( ATU_CPIPE_BPG_EN_PRFX                     ),
      .OPIPE_BPG_EN_PRFX            ( ATU_OPIPE_BPG_EN_PRFX                     ),
      .IPIPE_BPG_EN_HDR             ( ATU_IPIPE_BPG_EN_HDR                      ),
      .IPIPE_BPG_EN_DATA            ( ATU_IPIPE_BPG_EN_DATA                     ),
      .IPIPE_BPC_EN                 ( ATU_IPIPE_BPC_EN                          ),
      .CPIPE_BPG_EN_HDR             ( ATU_CPIPE_BPG_EN_HDR                      ),
      .CPIPE_BPG_EN_DATA            ( ATU_CPIPE_BPG_EN_DATA                     ),
      .CPIPE_BPC_EN                 ( ATU_CPIPE_BPC_EN                          ),
      .OPIPE_BPG_EN_HDR             ( ATU_OPIPE_BPG_EN_HDR                      ),
      .OPIPE_BPG_EN_DATA            ( ATU_OPIPE_BPG_EN_DATA                     ),
      .OPIPE_BPC_EN                 ( ATU_OPIPE_BPC_EN                          ),
      .RAS_DP_PROT_CHK_ID_BASE      ( RAS_DP_ID_BASE_ATU                        ),
      .IPIPE_EN                     ( ATU_IPIPE_EN                              ),
      .CPIPE_EN                     ( ATU_CPIPE_EN                              ),
      .OPIPE_EN                     ( ATU_OPIPE_EN                              )
    ) U_atu_out_ms ( 
      .core_clk,
      .core_rst_n,
      .xali_xaim_cfg,
      .cdm_xaim_cfg,
      .cdm_atu_out_cfg,
      .ras_dp_err_log               ( ras_dp_err_log_atu                        ),
      .ras_dp_err_inj,
      .i_xaim_pkt                   ( flush_out_pkt                             ),
      .o_xaim_halt                  ( flush_in_halt                             ),
      .o_xaim_pkt                   ( int_stage_pkt                             ),
      .i_xaim_halt                  ( int_stage_halt                            ) 
    );

  end else begin
    always_comb begin
      for (int i=0; i<N_CHAN; i++) begin
        int_stage_pkt[i] = flush_out_pkt[i];
        flush_in_halt[i] = int_stage_halt[i];
      end
    end
  end 
endgenerate

generate
  if ( TLUT_ENABLE == 1 ) begin : target_completion_lut
    ///////////////////////////////////////////////
    // Target Completion LUT
    ///////////////////////////////////////////////
    target_cpl_lut_frag_ms #(
      .N_CPL_IF                     ( N_CHAN                                    ),
      .N_TRGT_IF                    ( N_TRGT                                    ),
      .IPIPE_BPG_EN_PRFX            ( TLUT_IPIPE_BPG_EN_PRFX                    ),
      .OPIPE_BPG_EN_PRFX            ( TLUT_OPIPE_BPG_EN_PRFX                    ),
      .IPIPE_BPG_EN_HDR             ( TLUT_IPIPE_BPG_EN_HDR                     ),
      .IPIPE_BPG_EN_DATA            ( TLUT_IPIPE_BPG_EN_DATA                    ),
      .IPIPE_BPC_EN                 ( TLUT_IPIPE_BPC_EN                         ),
      .OPIPE_BPG_EN_HDR             ( TLUT_OPIPE_BPG_EN_HDR                     ),
      .OPIPE_BPG_EN_DATA            ( TLUT_OPIPE_BPG_EN_DATA                    ),
      .OPIPE_BPC_EN                 ( TLUT_OPIPE_BPC_EN                         ),
      .RAS_DP_PROT_CHK_ID_BASE      ( RAS_DP_ID_BASE_TLUT                       ),
      .IPIPE_EN                     ( TLUT_IPIPE_EN                             ),
      .OPIPE_EN                     ( TLUT_OPIPE_EN                             )
    ) U_target_cpl_lut_frag_ms (
      .core_clk,
      .core_rst_n,
      .xali_xaim_cfg,
      .cdm_xaim_cfg,
      .xaim_xali_cfg,
      .ras_dp_err_log              ( ras_dp_err_log_tlut                       ),
      .ras_dp_err_inj,
      .i_xaim_pkt                  ( int_stage_pkt                             ),
      .o_xaim_halt                 ( int_stage_halt                            ),
      .radm_xaim_pkt,
      .radm_xaim_halt,
      .xaim_radm_pkt,
      .xaim_xali_pkt,
      .pmctrl_xaim_pkt,
      .o_xaim_pkt                  ( hdr_in_pkt                               ),
      .i_xaim_halt                 ( hdr_out_halt                             )
    );
  end else begin
    always_comb begin
      for (int i=0; i<N_CHAN; i++) begin
        hdr_in_pkt[i]     = int_stage_pkt[i];
        int_stage_halt[i] = hdr_out_halt[i];
      end
      for (int i=0; i<N_CHAN; i++) begin
        xaim_radm_pkt[i]  = '0;
        xaim_xali_pkt[i]  = '0;
      end
    end
  end
endgenerate

///////////////////////////////////////////////
// Header Formation
///////////////////////////////////////////////
xaim_hdr_form_ms
 #(
  .FC_TYPE                     ( FC_TYPE                                  ),
  .PORT_E                      ( PORT_E                                   ),
  .MSG                         ( 0                                        ),
  .N                           ( N_CHAN                                   ),
  .IPIPE_BPG_EN_PRFX           ( HDR_IPIPE_BPG_EN_PRFX                    ),
  .IPIPE_BPG_EN_HDR            ( HDR_IPIPE_BPG_EN_HDR                     ),
  .IPIPE_BPG_EN_DATA           ( HDR_IPIPE_BPG_EN_DATA                    ),
  .IPIPE_BPC_EN                ( HDR_IPIPE_BPC_EN                         ),
  .IPIPE_BPC_EN_PRFX           ( HDR_IPIPE_BPC_EN_PRFX                    ),
  .CPIPE_BPG_EN                ( HDR_CPIPE_BPG_EN                         ),
  .CPIPE_BPC_EN                ( HDR_CPIPE_BPC_EN                         ),
  .OPIPE_BPG_EN                ( HDR_OPIPE_BPG_EN                         ),
  .OPIPE_BPC_EN                ( HDR_OPIPE_BPC_EN                         ),
  .RAS_DP_PROT_CHK_ID_BASE     ( RAS_DP_ID_BASE_HDR                       ),
  .IPIPE_EN                    ( HDR_IPIPE_EN                             ),
  .CPIPE_EN                    ( HDR_CPIPE_EN                             ),
  .OPIPE_EN                    ( HDR_OPIPE_EN                             )
) U_xaim_hdr_form_ms (
  .core_clk,
  .core_rst_n,
  .xali_xaim_cfg,
  .cdm_xaim_cfg,
  .vc_in                       ( vc_in                                    ),
  .ras_dp_err_log              ( ras_dp_err_log_hdr                       ),
  .ras_dp_err_inj,
  .xaim_einj6_tlp_evt          ( xaim_einj6_tlp_evt                       ),
  .i_xaim_pkt                  ( hdr_in_pkt                               ),
  .o_xaim_halt                 ( hdr_out_halt                             ),
  .o_xaim_pkt                  ( o_xaim_pkt                               ),
  .i_xaim_halt                 ( i_xaim_halt                              ) 
);

////////////////////////////////////////////
// RASDP Error Logging
////////////////////////////////////////////
logic [$clog2(N_LOGS)-1:0] idx;
logic [2:0]                HDR_PIPE_OFFSET;

always_comb begin
  for (int i=0; i<N_CHAN; i++) begin
    idx               = '0;
    HDR_PIPE_OFFSET   = '0;
    ras_dp_err_log[i] = '0;

    if ((ATU_IPIPE_BPC_EN == 1)  && (ATU_ENABLE == 1))  begin ras_dp_err_log[i][idx+:NLOGS_XAIM_ACT] = ras_dp_err_log_atu[i][0 + 2 +1 -1:0]; idx=idx+NLOGS_XAIM_ACT; end
    if ((ATU_CPIPE_BPC_EN == 1)  && (ATU_ENABLE == 1))  begin ras_dp_err_log[i][idx+:NLOGS_XAIM_ACT] = ras_dp_err_log_atu[i][3 + 2 +1 -1:3]; idx=idx+NLOGS_XAIM_ACT; end
    if ((ATU_OPIPE_BPC_EN == 1)  && (ATU_ENABLE == 1))  begin ras_dp_err_log[i][idx+:NLOGS_XAIM_ACT] = ras_dp_err_log_atu[i][6 + 2 +1 -1:6]; idx=idx+NLOGS_XAIM_ACT; end
    if ((TLUT_IPIPE_BPC_EN == 1) && (TLUT_ENABLE == 1)) begin ras_dp_err_log[i][idx+:NLOGS_XAIM_ACT] = ras_dp_err_log_tlut[i][0 + 2 +1 -1:0]; idx=idx+NLOGS_XAIM_ACT; end
    if ((TLUT_OPIPE_BPC_EN == 1) && (TLUT_ENABLE == 1)) begin ras_dp_err_log[i][idx+:NLOGS_XAIM_ACT] = ras_dp_err_log_tlut[i][6 + 2 +1 -1:6]; idx=idx+NLOGS_XAIM_ACT; end


    if (HDR_IPIPE_BPC_EN_PRFX == 1) begin
      // place input pipe ras_dp_err_log's if present
      ras_dp_err_log[i][idx] = ras_dp_err_log_hdr[i][HDR_PIPE_OFFSET];
    end
    if (HDR_IPIPE_BPC_EN == 1) begin
      idx             = idx             + HDR_IPIPE_BPC_EN_PRFX;
      HDR_PIPE_OFFSET = HDR_PIPE_OFFSET + HDR_IPIPE_BPC_EN_PRFX;
      // place input pipe ras_dp_err_log's if present
      ras_dp_err_log[i][idx] = ras_dp_err_log_hdr[i][HDR_PIPE_OFFSET];
      idx             = idx             + HDR_IPIPE_BPC_EN;
      HDR_PIPE_OFFSET = HDR_PIPE_OFFSET + HDR_IPIPE_BPC_EN;
      // place input pipe ras_dp_err_log's if present
      ras_dp_err_log[i][idx] = ras_dp_err_log_hdr[i][HDR_PIPE_OFFSET];
    end


    if (HDR_CPIPE_BPC_EN == 1) begin
      idx             = idx             + HDR_IPIPE_BPC_EN ;
      HDR_PIPE_OFFSET = HDR_PIPE_OFFSET + HDR_IPIPE_BPC_EN ;
      // place central pipe ras_dp_err_log's if present
      ras_dp_err_log[i][idx] = ras_dp_err_log_hdr[i][HDR_PIPE_OFFSET];
    end
      
    if (HDR_OPIPE_BPC_EN == 1) begin
      idx             = idx             + HDR_CPIPE_BPC_EN;
      HDR_PIPE_OFFSET = HDR_PIPE_OFFSET + HDR_CPIPE_BPC_EN;
      // place output pipe ras_dp_err_log's if present
      ras_dp_err_log[i][idx] = ras_dp_err_log_hdr[i][HDR_PIPE_OFFSET];
    end

  end
end

endmodule // xaim_channel_ms
