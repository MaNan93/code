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
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/xaim_hdr_form_ms.sv#6 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

`include "DWC_pcie_ctl_pkg.svh"
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Adm_ms/xaim_ms_pkg.svh"
`include "products/pcie_pkg.svh"

module xaim_hdr_form_ms
import DWC_pcie_core_pkg::*;
import DWC_pcie_ctl_pkg::*;
import xaim_ms_pkg::*;
import pcie_pkg::*;
#(
  parameter fc_type_e FC_TYPE       = E_P,                  // FC Type
  parameter tx_port_id_e PORT_E     = E_TX_PORT_ID_LBC,     // Port Type
  parameter MSG                     = 1,                    // O: Posted/Non-Posted, 1: Completions
  parameter N                       = 1,                    // Number of Channels
  parameter IPIPE_BPG_EN_PRFX       = 0,
  parameter IPIPE_BPG_EN_HDR        = 0,
  parameter IPIPE_BPG_EN_DATA       = 0,
  parameter IPIPE_BPC_EN            = 1,
  parameter IPIPE_BPC_EN_PRFX       = 0,
  parameter CPIPE_BPG_EN            = 0,
  parameter CPIPE_BPC_EN            = 0,
  parameter OPIPE_BPG_EN            = 0,
  parameter OPIPE_BPC_EN            = 0,
  parameter RAS_DP_PROT_CHK_ID_BASE = 0,
  parameter IPIPE_EN                = 0,                      // 0: No Input  Pipeline, 1: Input Pipeline Inserted
  parameter CPIPE_EN                = 0,
  parameter OPIPE_EN                = 1
)
(
  // Clocks/Resets
  input                                 core_clk,
  input                                 core_rst_n,
  // Configuration Structs
  input  xali_xaim_cfg_t                xali_xaim_cfg,         // Configuration from Application
  input  cdm_xaim_cfg_t                 cdm_xaim_cfg,          // Configuration from CDM
  // Temporary signals
  input            [N-1:0] [NVC_WD-1:0] vc_in,      
  output ras_dp_err_log_t [N-1:0] [4:0] ras_dp_err_log,   //add 1 for IPIPE of trailer 
  input  ras_dp_err_inj_t               ras_dp_err_inj,
  output logic                  [N-1:0] xaim_einj6_tlp_evt,
  // TLP Packet from Application/CDM/LBC
  input  xaim_pkt_t             [N-1:0] i_xaim_pkt,            // From Application/CDM/LBC
  output logic                  [N-1:0] o_xaim_halt,           // To Application/CDM/LBC
  // Header Formed TLP Packet to XADM
  output xadm_pkt_t             [N-1:0] o_xaim_pkt,            // To XADM
  input  logic                  [N-1:0] i_xaim_halt            // From XADM
);

localparam RAS_DP_PROT_CHK_ID_BASE_IPIPE = RAS_DP_PROT_CHK_ID_BASE;
localparam RAS_DP_PROT_CHK_ID_BASE_CPIPE = RAS_DP_PROT_CHK_ID_BASE + (3)*N;  
localparam RAS_DP_PROT_CHK_ID_BASE_OPIPE = RAS_DP_PROT_CHK_ID_BASE + (4)*N;

localparam CPIPE_FIRST = (XAIM_RAS_DES_EN == 1) ? ((XAIM_ATU_CTRL_EN == 1) ? (((PORT_E == E_TX_PORT_ID_XALI) & ((FC_TYPE == E_P) | (FC_TYPE == E_NP))) ? 1 : 0) : 0) : 1;
localparam OPIPE_FIRST = (XAIM_RAS_DES_EN == 1) ? ((XAIM_ATU_CTRL_EN == 1) ? (((PORT_E == E_TX_PORT_ID_XALI) & ((FC_TYPE == E_P) | (FC_TYPE == E_NP))) ? 1 : 1) : 1) : 0;

// Logic Defines
xaim_pkt_t       [N-1:0]       hdr_in_pkt;
xadm_pkt_t       [N-1:0]       hdr_out_pkt;
xadm_pkt_t       [N-1:0]       opipe_in_pkt;
xadm_pkt_t       [N-1:0]       einj6_in_pkt;
logic            [N-1:0]       einj6_out_halt;
logic            [N-1:0]       opipe_out_halt;
logic            [N-1:0]       hdr_in_halt;
logic            [N-1:0]       hdr_out_halt;

ras_dp_err_log_t [N-1:0] [2 :0] ras_dp_err_log_ipipe; // Three logs back from xaim pipe + 1for trailer 
ras_dp_err_log_t [N-1:0]       ras_dp_err_log_cpipe; // One log back from xadm pipe
ras_dp_err_log_t [N-1:0]       ras_dp_err_log_opipe; // "

////////////////////////////////////////////
// Input pipeline
////////////////////////////////////////////
xaim_pipe_w_order_ms
 #(
 .BUS_PROTECT_GEN_EN_PRFX  ( IPIPE_BPG_EN_PRFX             ),
 .BUS_PROTECT_CHK_EN_PRFX  ( IPIPE_BPC_EN_PRFX             ),
 .BUS_PROTECT_GEN_EN_HDR   ( IPIPE_BPG_EN_HDR              ),
 .BUS_PROTECT_GEN_EN_DATA  ( IPIPE_BPG_EN_DATA             ),
 .BUS_PROTECT_CHK_EN       ( IPIPE_BPC_EN                  ),
 .RAS_DP_PROT_CHK_ID_BASE  ( RAS_DP_PROT_CHK_ID_BASE_IPIPE ),
 .PORT_E                   ( PORT_E                        ),
 .N                        ( N                             ),
 .PIPE                     ( IPIPE_EN                      ),
 .CAN_STALL                ( IPIPE_EN                      ),
 .PREV_STAGE_CAN_HALT      ( 0                             )
) U_xaim_ipipe_w_order_ms (
  .clk                     ( core_clk                      ),
  .rst_n                   ( core_rst_n                    ),
  .mode                    ( cdm_xaim_cfg.mode             ),
  .ras_dp_err_log          ( ras_dp_err_log_ipipe          ),
  .ras_dp_err_inj          ( ras_dp_err_inj                ),
  .in_pkt                  ( i_xaim_pkt                    ),
  .in_prev_stage_halt      ( '0                            ),
  .out_halt                ( o_xaim_halt                   ),
  .out_pkt                 ( hdr_in_pkt                    ),
  .in_halt                 ( hdr_out_halt                  )
);

generate
  for (genvar i=0; i<N; i++) begin : hdrdw
    if (( PORT_E == E_TX_PORT_ID_MSG ) | ( PORT_E == E_TX_PORT_ID_LBC ) | ((PORT_E == E_TX_PORT_ID_XALI) && (XAIM_CX_IS_SW == 0))) begin : form
      ////////////////////////////////////////////
      // Header DataWord Formation
      ////////////////////////////////////////////
      xaim_hdrdw_form_ms
       # (
        .PORT_E                  ( PORT_E                        )
      ) U_xaim_hdrdw_form_ms (
        .core_clk,
        .core_rst_n,
        .xali_xaim_cfg,
        .cdm_xaim_cfg,
        .i_xaim_pkt              ( hdr_in_pkt[i]                 ),
        .o_xaim_halt             ( hdr_out_halt[i]               ),
        .o_xadm_pkt              ( hdr_out_pkt[i]                ),
        .i_xadm_halt             ( hdr_in_halt[i]                )
      );
    end else begin : convert
      ////////////////////////////////////////////
      // Header DataWord Conversion
      ////////////////////////////////////////////
      xaim_hdrdw_convert_ms
       # (
        .PORT_E                  ( PORT_E                        )
      ) U_xaim_hdrdw_convert_ms (
        .core_clk,
        .core_rst_n,
        .xali_xaim_cfg,
        .cdm_xaim_cfg,
        .i_xaim_pkt              ( hdr_in_pkt[i]                 ),
        .o_xaim_halt             ( hdr_out_halt[i]               ),
        .o_xadm_pkt              ( hdr_out_pkt[i]                ),
        .i_xadm_halt             ( hdr_in_halt[i]                )
      );
    end
  end
endgenerate

////////////////////////////////////////////
// Central/RASDES pipeline
////////////////////////////////////////////
xadm_pipe_w_order_ms
 #(
 .BUS_PROTECT_GEN_EN       ( CPIPE_BPG_EN                  ),
 .BUS_PROTECT_CHK_EN       ( CPIPE_BPC_EN                  ),
 .RAS_DP_PROT_CHK_ID_BASE  ( RAS_DP_PROT_CHK_ID_BASE_CPIPE ),
 .N                        ( N                             ),
 .PIPE                     ( 1 /*CPIPE_EN*/                ),
 .CAN_STALL                ( 1 /*CPIPE_EN*/                ),
 .PREV_STAGE_CAN_HALT      ( 0                             ),
 .CAN_CHANGE_ON_HALT       ( 1                             )
) U_xadm_cpipe_w_order_ms (
  .clk                     ( core_clk                      ),
  .rst_n                   ( core_rst_n                    ),
  .ras_dp_err_log          ( ras_dp_err_log_cpipe          ),
  .ras_dp_err_inj          ( ras_dp_err_inj                ),
  .in_pkt                  ( hdr_out_pkt                   ),
  .in_prev_stage_halt      ( '0                            ),
  .out_halt                ( hdr_in_halt                   ),
  .out_pkt                 ( einj6_in_pkt                  ),
  .in_halt                 ( einj6_out_halt                )
);

////////////////////////////////////////////
// RAS DES Error Injection
////////////////////////////////////////////
generate
  for (genvar i=0; i<N; i++) begin : tlp_einj6
    xaim_tlp_einj6_ms
    
    U_xaim_tlp_einj6_ms (
      .core_clk,
      .core_rst_n,
      .cdm_xaim_cfg,
      .i_xadm_pkt              ( einj6_in_pkt[i]               ),
      .o_xadm_halt             ( einj6_out_halt[i]             ),
      .o_xadm_pkt              ( opipe_in_pkt[i]               ),
      .i_xadm_halt             ( opipe_out_halt[i]             ),
      .xaim_einj6_valid        (                               ),   
      .xaim_einj6_tlp_evt      ( xaim_einj6_tlp_evt[i]         )
    );
  end
endgenerate

////////////////////////////////////////////
// Output pipeline
////////////////////////////////////////////
xadm_pipe_w_order_ms
 #(
 .BUS_PROTECT_GEN_EN      ( OPIPE_BPG_EN                  ),
 .BUS_PROTECT_CHK_EN      ( OPIPE_BPC_EN                  ),
 .RAS_DP_PROT_CHK_ID_BASE ( RAS_DP_PROT_CHK_ID_BASE_OPIPE ),
 .N                       ( N                             ),
 .PIPE                    ( OPIPE_EN                      ),
 .CAN_STALL               ( OPIPE_EN                      ),
 .PREV_STAGE_CAN_HALT     ( 0                             )

) U_xadm_opipe_w_order_ms (
  .clk                    ( core_clk                      ),
  .rst_n                  ( core_rst_n                    ),
  .ras_dp_err_log         ( ras_dp_err_log_opipe          ),
  .ras_dp_err_inj         ( ras_dp_err_inj                ),
  .in_pkt                 ( opipe_in_pkt                  ),
  .in_prev_stage_halt     ( '0                            ),
  .out_halt               ( opipe_out_halt                ),
  .out_pkt                ( o_xaim_pkt                    ),
  .in_halt                ( i_xaim_halt                   )
);


////////////////////////////////////////////
// RASDP Error Logging
////////////////////////////////////////////
logic [2:0] IN_OFFSET;
logic [1:0] IPIPE_OFFSET;

always_comb begin
  ras_dp_err_log = '0;
  IN_OFFSET      = '0;
  IPIPE_OFFSET   = '0;

  if (IPIPE_BPC_EN_PRFX == 1) begin
    // place input pipe ras_dp_err_log's if present
    for (int i=0; i<N; i++) begin
      ras_dp_err_log[i][IN_OFFSET] = ras_dp_err_log_ipipe[i][IPIPE_OFFSET];
    end
  end

  if (IPIPE_BPC_EN == 1) begin
    IN_OFFSET    = IN_OFFSET    + IPIPE_BPC_EN_PRFX;
    IPIPE_OFFSET = IPIPE_OFFSET + IPIPE_BPC_EN_PRFX;
    // place input pipe ras_dp_err_log's if present
    for (int i=0; i<N; i++) begin
      ras_dp_err_log[i][IN_OFFSET] = ras_dp_err_log_ipipe[i][IPIPE_OFFSET];
    end
    IN_OFFSET    = IN_OFFSET    + IPIPE_BPC_EN;
    IPIPE_OFFSET = IPIPE_OFFSET + IPIPE_BPC_EN;
    // place input pipe ras_dp_err_log's if present
    for (int i=0; i<N; i++) begin
      ras_dp_err_log[i][IN_OFFSET] = ras_dp_err_log_ipipe[i][IPIPE_OFFSET];
    end
  end


  if (CPIPE_BPC_EN == 1) begin
    IN_OFFSET = IN_OFFSET +  IPIPE_BPC_EN ; 
    // place central pipe ras_dp_err_log's if present
    for (int i=0; i<N; i++) begin
      ras_dp_err_log[i][IN_OFFSET] = ras_dp_err_log_cpipe[i];
    end
  end
  
  if (OPIPE_BPC_EN == 1) begin
    IN_OFFSET = IN_OFFSET + CPIPE_BPC_EN;
    // place output pipe ras_dp_err_log's if present
    for (int i=0; i<N; i++) begin
      ras_dp_err_log[i][IN_OFFSET] = ras_dp_err_log_opipe[i];
    end
  end 
end

endmodule // xaim_hdr_form_ms

