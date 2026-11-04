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
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/xali_xaim_cpl_ms.sv#6 $
// -------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// This module handles the processing of all Completion Messages from the both 
// the RADM and the Application
//
// -----------------------------------------------------------------------------

`include "DWC_pcie_ctl_pkg.svh"
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Adm_ms/xaim_ms_pkg.svh"
`include "products/pcie_pkg.svh"

module xali_xaim_cpl_ms
import DWC_pcie_core_pkg::*;
import DWC_pcie_ctl_pkg::*;
import xaim_ms_pkg::*;
import pcie_pkg::*;
#(
  
  parameter N_LOGS            = 1,
  parameter RAS_DP_ID_BASE_CPL_TLUT = 0,
  parameter RAS_DP_ID_BASE_CPL_HDR  = 0,
  parameter N_XALI_CPL_IF           = 0, // Number of Completion Application Interfaces
  parameter N_TRGT_NP_IF            = 1
) 
                       (
  // Clocks/Resets
  input                                      core_clk,
  input                                      core_rst_n,
  // Configuration Structs
  input  xali_xaim_cfg_t                     xali_xaim_cfg,         // Configuration from Application
  input  cdm_xaim_cfg_t                      cdm_xaim_cfg,          // Configuration from CDM
  input    [N_XALI_CPL_IF-1:0]  [NVC_WD-1:0] vc_in,
  input                                      rstctl_core_flush_req, // Flush request from Reset Controller
  input  pmctrl_xaim_pkt_t                   pmctrl_xaim_pkt,
  // Interfaces for the instantiation of the Target LUT
  input  xaim_xali_cfg_t                     xaim_xali_cfg,
  input  radm_xaim_pkt_t  [N_TRGT_NP_IF-1:0] radm_xaim_pkt,         // From RADM
  input  logic            [N_TRGT_NP_IF-1:0] radm_xaim_halt,        // From RADM
  output xaim_radm_pkt_t  [N_TRGT_NP_IF-1:0] xaim_radm_pkt,         // To RADM
  output xaim_xali_pkt_t  [N_TRGT_NP_IF-1:0] xaim_xali_pkt,         // To Application
  output ras_dp_err_log_t [N_XALI_CPL_IF-1:0] [N_LOGS-1:0] ras_dp_err_log,
  input  ras_dp_err_inj_t                    ras_dp_err_inj,
  output logic           [N_XALI_CPL_IF-1:0] xaim_einj6_tlp_evt,
  // TLP Packet Interfaces from Application
  input  xaim_pkt_t      [N_XALI_CPL_IF-1:0] i_xaim_pkt,           // From Application
  output logic           [N_XALI_CPL_IF-1:0] o_xaim_halt,          // To Application
  // TLP Packet Interfaces to XADM
  output xadm_pkt_t      [N_XALI_CPL_IF-1:0] o_xaim_pkt,           // To XADM
  input  logic           [N_XALI_CPL_IF-1:0] i_xaim_halt           // From XADM

);

// Logic Defines
xaim_pkt_t [N_XALI_CPL_IF-1:0] hdr_in_pkt;
logic      [N_XALI_CPL_IF-1:0] hdr_out_halt;
xaim_pkt_t [N_XALI_CPL_IF-1:0] flush_out_pkt;
logic      [N_XALI_CPL_IF-1:0] flush_in_halt;
ras_dp_err_log_t [N_XALI_CPL_IF-1:0] [5 :0] ras_dp_err_log_tlut;
ras_dp_err_log_t [N_XALI_CPL_IF-1:0] [4 :0] ras_dp_err_log_hdr;

////////////////////////////////////////////
// TLP Halt Manager
////////////////////////////////////////////
generate
  for (genvar i=0; i<N_XALI_CPL_IF; i++) begin : flush_halt_manager
    xaim_flush_mgr_ms
     #(
      .FC_TYPE                      ( E_CPL                                     ) 
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

///////////////////////////////////////////////
// Target Completion LUT
///////////////////////////////////////////////

// Logic Defines
xaim_pkt_t [N_XALI_CPL_IF-1:0] ipipe_out_pkt;
logic      [N_XALI_CPL_IF-1:0] ipipe_in_halt;

////////////////////////////////////////////
// Input pipeline
////////////////////////////////////////////
xaim_pipe_w_order_ms
 #(
 .BUS_PROTECT_GEN_EN_PRFX   ( CPL_TLUT_IPIPE_BPG_EN_PRFX         ),
 .BUS_PROTECT_GEN_EN_HDR    ( CPL_TLUT_IPIPE_BPG_EN_HDR          ),
 .BUS_PROTECT_GEN_EN_DATA   ( CPL_TLUT_IPIPE_BPG_EN_DATA         ),
 .BUS_PROTECT_CHK_EN        ( CPL_TLUT_IPIPE_BPC_EN              ),
 .RAS_DP_PROT_CHK_ID_BASE   ( RAS_DP_ID_BASE_CPL_TLUT            ),
 .N                         ( 1                                  ),
 .PIPE                      ( CPL_TLUT_IPIPE_EN                  ),
 .CAN_STALL                 ( CPL_TLUT_IPIPE_EN                  )
) U_xaim_ipipe_w_order_ms (
  .clk                      ( core_clk                           ),
  .rst_n                    ( core_rst_n                         ),
  .mode                     ( cdm_xaim_cfg.mode                  ),
  .ras_dp_err_log           ( ras_dp_err_log_tlut[0][2 :0]        ),
  .ras_dp_err_inj           ( ras_dp_err_inj                     ),
  .in_pkt                   ( flush_out_pkt                      ),
  .in_prev_stage_halt       ( 1'b0                               ),
  .out_halt                 ( flush_in_halt                      ),
  .out_pkt                  ( ipipe_out_pkt                      ),
  .in_halt                  ( ipipe_in_halt                      )
);


assign ras_dp_err_log_tlut[0][5 :3] = 0;


// Logic Defines
xaim_pkt_t [N_XALI_CPL_IF-1:0] trgt_lut_hdr_pkt;
logic      [N_XALI_CPL_IF-1:0] hdr_trgt_lut_halt;

// Variable Defines
genvar k;

/*

xaim_pkt_t [N_XALI_CPL_IF-1:0] trgt_lut_test_pkt;

target_cpl_lut_ms #(
  .N_CPL_IF                    ( N_XALI_CPL_IF                       ),
  `ifdef CX_RASDP_EN
  `ifdef CX_TLP_PREFIX_ENABLE
  .IPIPE_BPG_EN_PRFX           ( CPL_TLUT_IPIPE_BPG_EN_PRFX          ),
  .OPIPE_BPG_EN_PRFX           ( CPL_TLUT_OPIPE_BPG_EN_PRFX          ),
  `endif // CX_TLP_PREFIX_ENABLE
  .IPIPE_BPG_EN_HDR            ( CPL_TLUT_IPIPE_BPG_EN_HDR           ),
  .IPIPE_BPG_EN_DATA           ( CPL_TLUT_IPIPE_BPG_EN_DATA          ),
  .IPIPE_BPC_EN                ( CPL_TLUT_IPIPE_BPC_EN               ),
  .OPIPE_BPG_EN_HDR            ( CPL_TLUT_OPIPE_BPG_EN_HDR           ),
  .OPIPE_BPG_EN_DATA           ( CPL_TLUT_OPIPE_BPG_EN_DATA          ),
  .OPIPE_BPC_EN                ( CPL_TLUT_OPIPE_BPC_EN               ),
  .RAS_DP_PROT_CHK_ID_BASE     ( RAS_DP_ID_BASE_CPL_TLUT             ),
  `endif // CX_RASDP_EN
  .IPIPE_EN                    ( CPL_TLUT_IPIPE_EN                   ),
  .OPIPE_EN                    ( CPL_TLUT_OPIPE_EN                   )
) U_target_cpl_lut_ms (
  .core_clk,
  .core_rst_n,
  .xali_xaim_cfg,
  .cdm_xaim_cfg,
  .xaim_xali_cfg, 
  `ifdef CX_RASDP_EN
  .ras_dp_err_log              ( ras_dp_err_log_tlut                 ),
  `ifdef CX_RAS_ERROR_INJ_EN
  .ras_dp_err_inj,
  `endif // CX_RAS_ERROR_INJ_EN
  `endif // CX_RASDP_EN
  .i_xaim_pkt                  ( flush_out_pkt                       ),     // From Application
  //.o_xaim_halt                 ( flush_in_halt                       ),    // To Application
  .o_xaim_halt                 ( ),
  `ifdef CX_FREQ_STEP_DL_EN
  .cxpl_xaim_pkt               ( ),
  `endif // CX_FREQ_STEP_DL_EN
  .radm_xaim_pkt,     // From RADM
  .radm_xaim_halt,    // From RADM
  .xaim_radm_pkt               ( ),
  .xaim_xali_pkt               ( ),
  .xaim_cdm_pkt                ( ),

  .o_xaim_pkt                  ( trgt_lut_test_pkt                   ), // To Header Formation
  .i_xaim_halt                 ( hdr_out_halt                        )  // From Header Formation
);
*/

logic                [7:0] trgt_lookup_id;
logic                [1:0] tlp_attr;
logic               [11:0] cpl_byte_cnt;
logic                [2:0] tlp_tc;
logic               [15:0] remote_req_id;
logic                [4:0] tlp_type;
logic       [TAG_SIZE-1:0] tlp_tid;
logic                      cpl_type;
logic                [6:0] low_addr;
logic                [8:0] req_segment;

always_comb begin
  trgt_lut_hdr_pkt[0]                   = ipipe_out_pkt[0];
  if ( cpl_type ) begin
    trgt_lut_hdr_pkt[0].tlp_hdr_pkt.tlp_byte_count  = cpl_byte_cnt;
    trgt_lut_hdr_pkt[0].tlp_hdr_pkt.tlp_tc          = tlp_tc;
    trgt_lut_hdr_pkt[0].tlp_hdr_pkt.tlp_attr[1:0]   = tlp_attr;
    trgt_lut_hdr_pkt[0].tlp_hdr_pkt.tlp_req_id      = remote_req_id;
    trgt_lut_hdr_pkt[0].tlp_hdr_pkt.tlp_tag         = tlp_tid;
    //trgt_lut_hdr_pkt[0].hdr.tlp_type      = {4'b0,cpl_type};
    trgt_lut_hdr_pkt[0].tlp_hdr_pkt.tlp_addr[6:0]   = low_addr       ; 
    //`ifndef CX_IS_EP
    trgt_lut_hdr_pkt[0].tlp_hdr_pkt.tlp_dsv         = req_segment[8] ;
    trgt_lut_hdr_pkt[0].tlp_hdr_pkt.tlp_dst_seg     = req_segment[7:0] ;
    //`endif //!CX_IS_EP
  end
end

//generate
//  for (k=0; k<N_XALI_CPL_IF; k++) begin : target_completion_lut_legacy

    //assign trgt_lut_hdr_pkt[j] = i_xaim_pkt[j]; // Header information will be added below
    //assign xaim_xali_pkt[k].trgt_lookup_id = trgt_lookup_id;

    logic [6:0] fmt_type;      assign fmt_type = {radm_xaim_pkt[0].fmt, radm_xaim_pkt[0].tlp_type};
    logic       tlp_is_cfgrd;  assign tlp_is_cfgrd = (fmt_type == `CFGRD1) || (fmt_type == `CFGRD0);
    logic       tlp_is_cfgwr;  assign tlp_is_cfgwr = (fmt_type == `CFGWR1) || (fmt_type == `CFGWR0);
    logic [8:0] i_req_segment; assign i_req_segment = (tlp_is_cfgrd | tlp_is_cfgwr) ? 8'h0 : radm_xaim_pkt[0].req_segment;

    target_cpl_lut_ms
    
    U_target_cpl_lut (
      .core_clk,
      .core_rst_n,
      .cfg_tc_struc_vc_map           ( cdm_xaim_cfg.cfg_tc_struc_vc_map           ),
      .device_type                   ( xali_xaim_cfg.device_type                  ),
      .trgt1_radm_halt               ( radm_xaim_halt[0]                          ),
      .radm_trgt1_hv                 ( radm_xaim_pkt[0].hv                        ),
      .radm_trgt1_eot                ( radm_xaim_pkt[0].eot                       ),
      .radm_trgt1_ecrc_err           ( radm_xaim_pkt[0].ecrc_err                  ),
      .radm_trgt1_tlp_abort          ( radm_xaim_pkt[0].tlp_abort                 ),
      .radm_trgt1_dllp_abort         ( radm_xaim_pkt[0].dllp_abort                ),
      .radm_trgt1_fmt                ( radm_xaim_pkt[0].fmt                       ),
      .radm_trgt1_type               ( radm_xaim_pkt[0].tlp_type                  ),
      .radm_trgt1_tc                 ( radm_xaim_pkt[0].tc                        ),
      .radm_trgt1_attr               ( radm_xaim_pkt[0].attr[1:0]                 ),
      .radm_trgt1_reqid              ( radm_xaim_pkt[0].reqid                     ),
      .radm_trgt1_req_segment        ( i_req_segment                              ),
      .radm_trgt1_tag                ( radm_xaim_pkt[0].tag                       ),
      .radm_trgt1_dw_len             ( radm_xaim_pkt[0].dw_len                    ),
      .radm_trgt1_first_be           ( radm_xaim_pkt[0].first_be                  ),
      .radm_trgt1_last_be            ( radm_xaim_pkt[0].last_be                   ),
      .radm_trgt1_addr               ( radm_xaim_pkt[0].addr                      ),
      .radm_trgt1_func_num           ( radm_xaim_pkt[0].func_num                  ),
      .radm_trgt1_at                 ( radm_xaim_pkt[0].at                        ),
     
      .xadm_client_halt              ( ipipe_in_halt[0]                            ),
      .client_tlp_hv                 ( ipipe_out_pkt[0].fs.hv                      ),
      .client_tlp_eot                ( ipipe_out_pkt[0].fs.eot                     ),
      .client_tlp_bad_eot            ( ipipe_out_pkt[0].fs.bad_eot                 ),
      .client_tlp_fmt                ( ipipe_out_pkt[0].tlp_hdr_pkt.tlp_fmt[1:0]  ),
      .client_tlp_type               ( ipipe_out_pkt[0].tlp_hdr_pkt.tlp_type        ),
      .client_cpl_bcm                ( ipipe_out_pkt[0].tlp_hdr_pkt.tlp_bcm         ),
      .client_cpl_status             ( ipipe_out_pkt[0].tlp_hdr_pkt.tlp_cpl_status  ),
      .client_tlp_byte_len           ( ipipe_out_pkt[0].tlp_byte_len              ),
      .client_cpl_lookup_id          ( ipipe_out_pkt[0].cpl_lookup_id             ),
      .cfg_trgt_cpl_lut_delete_entry ( cdm_xaim_cfg.cfg_trgt_cpl_lut_delete_entry ),
      .flit_mode                     ( cdm_xaim_cfg.mode                          ),
      .cfg_rcb_128                   ( cdm_xaim_cfg.cfg_rcb_128                   ),
      .current_data_rate             ( pmctrl_xaim_pkt.current_data_rate          ),                                          // 
      //.radm_grant_tlp_type           ( {NVC*3{radm_xaim_pkt[0].hv & ~radm_xaim_pkt[0].tlp_abort}} ),
      .radm_grant_tlp_type           ( radm_xaim_pkt[0].radm_grant_tlp_type          ),
      .trgt_lut_trgt1_radm_pkt_halt  ( xaim_radm_pkt[0].trgt_lut_trgt1_radm_pkt_halt ),
      .radm_trgt1_dma_grant          ( xali_xaim_cfg.radm_trgt1_dma_grant      ),
      .radm_trgt1_dma_cpl_rlsd       ( xali_xaim_cfg.radm_trgt1_dma_cpl_rlsd   ),
      .trgt_lut_dma_pkt_halt         ( xaim_xali_pkt[0].trgt_lut_dma_pkt_halt     ),

      .trgt_lookup_id                ( xaim_xali_pkt[0].trgt_lookup_id            ),     // Does this go to the RADM?
      .trgt_lookup_empty             ( xaim_xali_pkt[0].trgt_lookup_empty         ),
      .trgt_cpl_lut_empty            ( xaim_xali_pkt[0].trgt_cpl_lut_empty        ),

      .client_cpl_byte_cnt           ( cpl_byte_cnt       ),
      .client_tlp_tc                 ( tlp_tc             ),
      .client_tlp_req_seqment        ( req_segment        ),
      .client_tlp_attr               ( tlp_attr           ),
      .client_cpl_req_id             ( remote_req_id      ),
      .client_cpl_tag                ( tlp_tid            ),
      .client_cpl_low_addr           ( low_addr           ),
      .client_cpl_type               ( cpl_type           ),
      .cfg_remote_max_bridge_tag     ( xaim_xali_cfg.cfg_remote_max_bridge_tag     ),
      .radm_trgt1_cpl_lookup_id_rlsd ( xaim_radm_pkt[0].cpl_lookup_id_rlsd            ),
      .radm_trgt1_lookup_id_consmd   ( xaim_xali_pkt[0].radm_trgt1_lookup_id_consmd   ),
      .trgt_cpl_timeout              ( xaim_xali_pkt[0].trgt_cpl_timeout              ),
      .trgt_timeout_cpl_tc           ( xaim_xali_pkt[0].trgt_timeout_cpl_tc           ),
      .trgt_timeout_cpl_attr         ( xaim_xali_pkt[0].trgt_timeout_cpl_attr         ),
      .trgt_timeout_cpl_len          ( xaim_xali_pkt[0].trgt_timeout_cpl_len          ),
      .trgt_timeout_lookup_id        ( xaim_xali_pkt[0].trgt_timeout_lookup_id        ),
      .trgt_timeout_cpl_func_num     ( xaim_xali_pkt[0].trgt_timeout_cpl_func_num     )
    );

  assign xaim_radm_pkt[0].temp = 0;

  assign hdr_in_pkt[0]    = trgt_lut_hdr_pkt[0];
  assign ipipe_in_halt[0] = hdr_out_halt[0];
//  end
//endgenerate


///////////////////////////////////////////////
// Posted/Non-Posted Header Formation
///////////////////////////////////////////////
xaim_hdr_form_ms
 #(
  .FC_TYPE                 ( E_CPL                               ),
  .N                       ( N_XALI_CPL_IF                       ),
  .PORT_E                  ( E_TX_PORT_ID_XALI                   ),
  .MSG                     ( 1                                   ),
  .IPIPE_BPG_EN_PRFX       ( CPL_HDR_IPIPE_BPG_EN_PRFX           ),
  .IPIPE_BPG_EN_HDR        ( CPL_HDR_IPIPE_BPG_EN_HDR            ),
  .IPIPE_BPG_EN_DATA       ( CPL_HDR_IPIPE_BPG_EN_DATA           ),
  .IPIPE_BPC_EN            ( CPL_HDR_IPIPE_BPC_EN                ),
  .IPIPE_BPC_EN_PRFX       ( CPL_HDR_IPIPE_BPC_EN_PRFX           ),
  .CPIPE_BPG_EN            ( CPL_HDR_CPIPE_BPG_EN                ),
  .CPIPE_BPC_EN            ( CPL_HDR_CPIPE_BPC_EN                ),
  .OPIPE_BPG_EN            ( CPL_HDR_OPIPE_BPG_EN                ),
  .OPIPE_BPC_EN            ( CPL_HDR_OPIPE_BPC_EN                ),
  .RAS_DP_PROT_CHK_ID_BASE ( RAS_DP_ID_BASE_CPL_HDR              ),
  .IPIPE_EN                ( CPL_HDR_IPIPE_EN                    ),
  .CPIPE_EN                ( CPL_HDR_CPIPE_EN                    ),
  .OPIPE_EN                ( CPL_HDR_OPIPE_EN                    )
) U_xaim_hdr_form_ms_xali_cpl (
  .core_clk,
  .core_rst_n,
  .xali_xaim_cfg,
  .cdm_xaim_cfg,
  .vc_in                   ( vc_in                               ),
  .ras_dp_err_log          ( ras_dp_err_log_hdr                  ),
  .ras_dp_err_inj,
  .xaim_einj6_tlp_evt      ( xaim_einj6_tlp_evt                  ),
  .i_xaim_pkt              ( hdr_in_pkt                          ),   // To Header Formation
  .o_xaim_halt             ( hdr_out_halt                        ),   // From Header Formation
  .o_xaim_pkt              ( o_xaim_pkt                          ),   // To XADM
  .i_xaim_halt             ( i_xaim_halt                         )    // From XADM
);

////////////////////////////////////////////
// RASDP Error Logging
////////////////////////////////////////////
logic [$clog2(ACT_NLOGS_CPL)-1:0] idx;
logic [2:0]                       CPL_HDR_PIPE_OFFSET;
always_comb begin
  //ras_dp_err_log = '0;
  for (int i=0; i<N_XALI_CPL_IF; i++) begin
    idx                 = '0;
    CPL_HDR_PIPE_OFFSET = '0;
    ras_dp_err_log[i]   = '0;
    if ( CPL_TLUT_IPIPE_BPC_EN == 1 ) begin ras_dp_err_log[i][idx+:NLOGS_XAIM_ACT]  = ras_dp_err_log_tlut[i][0 + 2 +1 -1:0]; idx=idx+NLOGS_XAIM_ACT; end
    if ( CPL_TLUT_OPIPE_BPC_EN == 1 ) begin ras_dp_err_log[i][idx+:NLOGS_XAIM_ACT]  = ras_dp_err_log_tlut[i][6 + 2 +1 -1:3]; idx=idx+NLOGS_XAIM_ACT; end

    if (CPL_HDR_IPIPE_BPC_EN_PRFX == 1) begin
      // place input pipe ras_dp_err_log's if present
      ras_dp_err_log[i][idx] = ras_dp_err_log_hdr[i][CPL_HDR_PIPE_OFFSET];
    end
    if (CPL_HDR_IPIPE_BPC_EN == 1) begin
      idx                 = idx                 + CPL_HDR_IPIPE_BPC_EN_PRFX;
      CPL_HDR_PIPE_OFFSET = CPL_HDR_PIPE_OFFSET + CPL_HDR_IPIPE_BPC_EN_PRFX;
      // place input pipe ras_dp_err_log's if present
      ras_dp_err_log[i][idx] = ras_dp_err_log_hdr[i][CPL_HDR_PIPE_OFFSET];
      idx                 = idx                 + CPL_HDR_IPIPE_BPC_EN;
      CPL_HDR_PIPE_OFFSET = CPL_HDR_PIPE_OFFSET + CPL_HDR_IPIPE_BPC_EN;
      // place input pipe ras_dp_err_log's if present
      ras_dp_err_log[i][idx] = ras_dp_err_log_hdr[i][CPL_HDR_PIPE_OFFSET];
    end


    if (CPL_HDR_CPIPE_BPC_EN == 1) begin
      idx                 = idx                 + CPL_HDR_IPIPE_BPC_EN ;
      CPL_HDR_PIPE_OFFSET = CPL_HDR_PIPE_OFFSET + CPL_HDR_IPIPE_BPC_EN ;
      // place central pipe ras_dp_err_log's if present
      ras_dp_err_log[i][idx] = ras_dp_err_log_hdr[i][CPL_HDR_PIPE_OFFSET];
    end
        
    if (CPL_HDR_OPIPE_BPC_EN == 1) begin
      idx                 = idx                 + CPL_HDR_CPIPE_BPC_EN;
      CPL_HDR_PIPE_OFFSET = CPL_HDR_PIPE_OFFSET + CPL_HDR_CPIPE_BPC_EN;
      // place output pipe ras_dp_err_log's if present
      ras_dp_err_log[i][idx] = ras_dp_err_log_hdr[i][CPL_HDR_PIPE_OFFSET];
    end

  end
end

endmodule // xali_xaim_cpl_ms
