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
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/atu_out_ms.sv#4 $
// -------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
`include "DWC_pcie_ctl_pkg.svh"
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Adm_ms/xaim_ms_pkg.svh"
`include "products/pcie_pkg.svh"

module atu_out_ms 
import DWC_pcie_core_pkg::*;
import DWC_pcie_ctl_pkg::*;
import xaim_ms_pkg::*;
import pcie_pkg::*;
#(
  parameter N                       = 1,  // Number of Channels
  parameter IPIPE_BPG_EN_PRFX       = 0,
  parameter CPIPE_BPG_EN_PRFX       = 0,
  parameter OPIPE_BPG_EN_PRFX       = 0,
  parameter IPIPE_BPG_EN_HDR        = 0,
  parameter IPIPE_BPG_EN_DATA       = 0,
  parameter IPIPE_BPC_EN            = 0,
  parameter CPIPE_BPG_EN_HDR        = 0,
  parameter CPIPE_BPG_EN_DATA       = 0,
  parameter CPIPE_BPC_EN            = 0,
  parameter OPIPE_BPG_EN_HDR        = 0,
  parameter OPIPE_BPG_EN_DATA       = 0,
  parameter OPIPE_BPC_EN            = 0,
  parameter RAS_DP_PROT_CHK_ID_BASE = 0,
  parameter IPIPE_EN                = 0,
  parameter CPIPE_EN                = 0,
  parameter OPIPE_EN                = 0
)
(
  // Clocks/Resets
  input                                     core_clk,
  input                                     core_rst_n,
  // Configuration Structs
  input  xali_xaim_cfg_t                    xali_xaim_cfg,       // Configuration from Application
  input  cdm_xaim_cfg_t                     cdm_xaim_cfg,        // Configuration from CDM for xaim
  input  cdm_atu_out_cfg_t                  cdm_atu_out_cfg,     // Configuration from CDM for ATU
  output ras_dp_err_log_t    [N-1:0]  [8:0] ras_dp_err_log, //add 3 for atu IPIPE/CPIPE/OPIPE of trailer
  input  ras_dp_err_inj_t                   ras_dp_err_inj,
  // TLP Packet Interfaces from Application
  input  xaim_pkt_t                 [N-1:0] i_xaim_pkt,          // From Application
  output logic                      [N-1:0] o_xaim_halt,         // To Application
  // TLP Packet Interfaces to Header Formation
  output xaim_pkt_t                 [N-1:0] o_xaim_pkt,          // To Header Formation
  input  logic                      [N-1:0] i_xaim_halt          // From Header Formation
);

localparam RAS_DP_PROT_CHK_ID_BASE_IPIPE = RAS_DP_PROT_CHK_ID_BASE;
localparam RAS_DP_PROT_CHK_ID_BASE_CPIPE = RAS_DP_PROT_CHK_ID_BASE + (3)*N;
localparam RAS_DP_PROT_CHK_ID_BASE_OPIPE = RAS_DP_PROT_CHK_ID_BASE + (6)*N;

// Logic Defines
xaim_pkt_t       [N-1:0]       ipipe_out_pkt;
xaim_pkt_t       [N-1:0]       cpipe_out_pkt;
xaim_pkt_t       [N-1:0]       opipe_in_pkt;
logic            [N-1:0]       ipipe_in_halt;
logic            [N-1:0]       cpipe_in_halt;
atu_pkt_t        [N-1:0]       atu_match_pkt;
atu_pkt_t        [N-1:0]       atu_translate_pkt;
tlp_hdr_pkt_s    [N-1:0]       atu_tlp_hdr_pkt;
logic            [N-1:0]       enable;
logic            [N-1:0]       inhibit_pyld;
ras_dp_err_log_t [N-1:0] [2:0] ras_dp_err_log_ipipe;
ras_dp_err_log_t [N-1:0] [2:0] ras_dp_err_log_cpipe;
ras_dp_err_log_t [N-1:0] [2:0] ras_dp_err_log_opipe;

////////////////////////////////////////////
// Input pipeline
////////////////////////////////////////////
xaim_pipe_w_order_ms
 #(
 .BUS_PROTECT_GEN_EN_PRFX   ( IPIPE_BPG_EN_PRFX                  ),
 .BUS_PROTECT_GEN_EN_HDR    ( IPIPE_BPG_EN_HDR                   ),
 .BUS_PROTECT_GEN_EN_DATA   ( IPIPE_BPG_EN_DATA                  ),
 .BUS_PROTECT_CHK_EN        ( IPIPE_BPC_EN                       ),
 .RAS_DP_PROT_CHK_ID_BASE   ( RAS_DP_PROT_CHK_ID_BASE_IPIPE      ),
 .N                         ( N                                  ),
 .PIPE                      ( IPIPE_EN                           ),
 .CAN_STALL                 ( IPIPE_EN                           )
) U_xaim_ipipe_w_order_ms (
  .clk                      ( core_clk                           ),
  .rst_n                    ( core_rst_n                         ),
  .mode                     ( cdm_xaim_cfg.mode                  ),
  .ras_dp_err_log           ( ras_dp_err_log_ipipe               ),
  .ras_dp_err_inj           ( ras_dp_err_inj                     ),
  .in_pkt                   ( i_xaim_pkt                         ),
  .in_prev_stage_halt       ( 1'b0                               ),
  .out_halt                 ( o_xaim_halt                        ),
  .out_pkt                  ( ipipe_out_pkt                      ),
  .in_halt                  ( ipipe_in_halt                      )
);

///////////////////////////////////////////////
// Address Match Functionality
///////////////////////////////////////////////
generate
  for (genvar i=0; i<N; i++) begin : atu_match
    atu_out_match
    
    U_atu_out_match (
      .clk                      ( core_clk                              ),
      .rst_n                    ( core_rst_n                            ),
      .cdm_atu_out_cfg,
      .dma                      ( ipipe_out_pkt[i].tlp_is_dma           ),
      .atu_bypass               ( ipipe_out_pkt[i].tlp_atu_bypass       ),
      .addr                     ( ipipe_out_pkt[i].tlp_hdr_pkt.tlp_addr ),
      .atu_pkt                  ( atu_match_pkt[i]                      )
    );
  end
endgenerate

///////////////////////////////////////////////
// Central Pipeline(s)
///////////////////////////////////////////////
generate
  for (genvar i=0; i<N; i++) begin : atu_pkt_cpipe
    delay_n_w_stalling
     #(
      .N                        ( CPIPE_EN                           ),
      .CAN_STALL                ( CPIPE_EN                           ),
      .WD                       ( $bits(atu_match_pkt)               )
    ) U_xaim_cpipe_atu (
      .clk                      ( core_clk                           ),
      .rst_n                    ( core_rst_n                         ),
      .stall                    ( cpipe_in_halt[i]                   ),
      .clear                    ( 1'b0                               ),
      .din                      ( atu_match_pkt[i]                   ),
      .stallout                 ( ),
      .dout                     ( atu_translate_pkt[i]               )
    );
  end
endgenerate

xaim_pipe_w_order_ms
 #(
 .BUS_PROTECT_GEN_EN_PRFX   ( CPIPE_BPG_EN_PRFX                  ),
 .BUS_PROTECT_GEN_EN_HDR    ( CPIPE_BPG_EN_HDR                   ),
 .BUS_PROTECT_GEN_EN_DATA   ( CPIPE_BPG_EN_DATA                  ),
 .BUS_PROTECT_CHK_EN        ( CPIPE_BPC_EN                       ),
 .RAS_DP_PROT_CHK_ID_BASE   ( RAS_DP_PROT_CHK_ID_BASE_CPIPE      ),
  .N                        ( N                                  ),
  .PIPE                     ( CPIPE_EN                           ),
  .CAN_STALL                ( CPIPE_EN                           )
) U_xaim_cpipe_w_order_ms (
  .clk                      ( core_clk                           ),
  .rst_n                    ( core_rst_n                         ),
  .mode                     ( cdm_xaim_cfg.mode                  ),
  .ras_dp_err_log           ( ras_dp_err_log_cpipe               ),
  .ras_dp_err_inj           ( ras_dp_err_inj                     ),
  .in_pkt                   ( ipipe_out_pkt                      ),
  .out_halt                 ( ipipe_in_halt                      ),
  .in_prev_stage_halt       ( 1'b0                               ),
  .out_pkt                  ( cpipe_out_pkt                      ),
  .in_halt                  ( cpipe_in_halt                      )
);

///////////////////////////////////////////////
// Address Translate Functionality
///////////////////////////////////////////////
generate
  for (genvar i=0; i<N; i++) begin : atu_translate
    atu_out_translate
    
    U_atu_out_translate (
      .clk                      ( core_clk                           ),
      .rst_n                    ( core_rst_n                         ),
      .mode                     ( cdm_xaim_cfg.mode                  ),
      .cdm_atu_out_cfg,
      .atu_pkt                  ( atu_translate_pkt[i]               ),
      .i_tlp_hdr_pkt            ( cpipe_out_pkt[i].tlp_hdr_pkt       ),
      .o_tlp_hdr_pkt            ( atu_tlp_hdr_pkt[i]                 ),
      .inhibit_pyld             ( inhibit_pyld[i]                    ),
      .enable                   ( enable[i]                          )
    );

    // Merge Packets
    always_comb begin
      opipe_in_pkt[i]                       = cpipe_out_pkt[i];
      opipe_in_pkt[i].tlp_is_atu_translated = enable[i];
      opipe_in_pkt[i].tlp_byte_len          = ( enable[i] & inhibit_pyld[i] ) ? '0 : cpipe_out_pkt[i].tlp_byte_len;

      if ( enable[i] ) begin
        opipe_in_pkt[i].tlp_hdr_pkt         = atu_tlp_hdr_pkt[i];
        opipe_in_pkt[i].tlp_byte_len        = inhibit_pyld[i] ? '0 : cpipe_out_pkt[i].tlp_byte_len;
        opipe_in_pkt[i].tlp_hdr_pkt.tlp_len = inhibit_pyld[i] ? '0 : cpipe_out_pkt[i].tlp_hdr_pkt.tlp_len;

        if ( cpipe_out_pkt[i].tlp_hdr_pkt.tlp_th & f_tlp_is_memrd( cdm_xaim_cfg.mode, cpipe_out_pkt[i].tlp_hdr_pkt ))
          {opipe_in_pkt[i].tlp_hdr_pkt.tlp_ldw_be,opipe_in_pkt[i].tlp_hdr_pkt.tlp_fdw_be} = cpipe_out_pkt[i].tlp_hdr_pkt.tlp_st[7:0];
      end
    end
  end
endgenerate


////////////////////////////////////////////
// Output Pipeline
////////////////////////////////////////////
xaim_pipe_w_order_ms
 #(
 .BUS_PROTECT_GEN_EN_PRFX   ( OPIPE_BPG_EN_PRFX                  ),
 .BUS_PROTECT_GEN_EN_HDR    ( OPIPE_BPG_EN_HDR                   ),
 .BUS_PROTECT_GEN_EN_DATA   ( OPIPE_BPG_EN_DATA                  ),
 .BUS_PROTECT_CHK_EN        ( OPIPE_BPC_EN                       ),
 .RAS_DP_PROT_CHK_ID_BASE   ( RAS_DP_PROT_CHK_ID_BASE_OPIPE      ),
 .N                         ( N                                  ),
 .PIPE                      ( OPIPE_EN                           ),
 .CAN_STALL                 ( OPIPE_EN                           )
) U_xaim_opipe_w_order_ms (
  .clk                      ( core_clk                           ),
  .rst_n                    ( core_rst_n                         ),
  .mode                     ( cdm_xaim_cfg.mode                  ),
  .ras_dp_err_log           ( ras_dp_err_log_opipe               ),
  .ras_dp_err_inj           ( ras_dp_err_inj                     ),
  .in_pkt                   ( opipe_in_pkt                       ),
  .in_prev_stage_halt       ( 1'b0                               ),
  .out_halt                 ( cpipe_in_halt                      ),
  .out_pkt                  ( o_xaim_pkt                         ),
  .in_halt                  ( i_xaim_halt                        )
);

////////////////////////////////////////////
// RASDP Error Logging
////////////////////////////////////////////
always_comb begin
  ras_dp_err_log = '0;
  for (int i=0; i<N; i++) begin
    if ( IPIPE_BPG_EN_PRFX | IPIPE_BPG_EN_HDR | IPIPE_BPG_EN_DATA | IPIPE_BPC_EN) 
      ras_dp_err_log[i][2:0] = ras_dp_err_log_ipipe[i];
    if ( CPIPE_BPG_EN_PRFX | CPIPE_BPG_EN_HDR | CPIPE_BPG_EN_DATA | CPIPE_BPC_EN)
      ras_dp_err_log[i][5:3] = ras_dp_err_log_cpipe[i];
    if ( OPIPE_BPG_EN_PRFX | OPIPE_BPG_EN_HDR | OPIPE_BPG_EN_DATA | OPIPE_BPC_EN) 
      ras_dp_err_log[i][8:6] = ras_dp_err_log_opipe[i];
  end
end

endmodule // atu_out_ms
