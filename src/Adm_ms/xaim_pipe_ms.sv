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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/xaim_pipe_ms.sv#5 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
//
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Adm_ms/xaim_ms_pkg.svh"

module xaim_pipe_ms
import DWC_pcie_ctl_pkg::*;
import DWC_pcie_core_pkg::*;
import xaim_ms_pkg::*;
#(
  parameter BUS_PROTECT_GEN_EN_PRFX = 0,
  parameter BUS_PROTECT_CHK_EN_PRFX = 1,
  parameter BUS_PROTECT_GEN_EN_HDR  = 1,
  parameter BUS_PROTECT_CHK_EN_HDR  = 1,
  parameter BUS_PROTECT_GEN_EN_DATA = 0,
  parameter BUS_PROTECT_CHK_EN_DATA = 1,
  parameter RAS_DP_PROT_CHK_ID_BASE = 0,
  parameter tx_port_id_e PORT_E     = E_TX_PORT_ID_XALI,
  parameter N                       = 2,
  parameter PIPE                    = 1,
  parameter CAN_STALL               = 1
)
(
  input  logic                                clk,
  input  logic                                rst_n,
  output ras_dp_err_log_t       [N-1:0] [2:0] ras_dp_err_log,
  input  ras_dp_err_inj_t                     ras_dp_err_inj,
  input  xaim_pkt_t                   [N-1:0] i_xaim_pkt,
  output logic                        [N-1:0] o_xaim_halt,
  output xaim_pkt_t                   [N-1:0] o_xaim_pkt,
  input  logic                        [N-1:0] i_xaim_halt
);

// Parameter Defines
localparam PROT_TYPE       = `CX_RAS_PROT_TYPE;
localparam PROT_RANGE      = `CX_RAS_PROT_RANGE;
localparam PARITY_MODE     = `CX_RAS_PARITY_MODE;
localparam PROT_CORRECT_EN = PROT_TYPE ? 0 : `CX_RAS_CORRECTION_EN;
parameter HDR_PROT_WD    = ((PORT_E == E_TX_PORT_ID_LBC) | (PORT_E == E_TX_PORT_ID_MSG)) ? LBC_MSG_HDR_PROT_WD    : XALI_HDR_PROT_WD;
parameter HDR_WO_PROT_WD = ((PORT_E == E_TX_PORT_ID_LBC) | (PORT_E == E_TX_PORT_ID_MSG)) ? LBC_MSG_HDR_WO_PROT_WD : XALI_HDR_WO_PROT_WD;

// Logic Defines
xaim_pkt_t       [N-1:0]                           xaim_pkt_pre_delay;
xaim_pkt_t       [N-1:0]                           xaim_pkt_post_delay;
ras_dp_err_log_t [N-1:0][2:0] ras_dp_err_log_int;
logic            [N-1:0]   [XALI_PRFX_PROT_WD-1:0] prfx_prot_post_delay;
logic            [N-1:0]                           rasdp_kbd_prfx;
logic            [N-1:0]      [HDR_WO_PROT_WD-1:0] hdr_pre_delay;
logic            [N-1:0]         [HDR_PROT_WD-1:0] hdr_prot_pre_delay;
logic            [N-1:0]         [HDR_PROT_WD-1:0] hdr_prot_post_delay;
logic            [N-1:0]                           rasdp_kbd_hdr;
logic            [N-1:0]   [XALI_DATA_PROT_WD-1:0] data_prot_post_delay;
logic            [N-1:0]                           rasdp_kbd_data;
logic            [N-1:0]                           hdr_valid_in;
logic                                              port_is_msglbc;

assign port_is_msglbc = ((PORT_E == E_TX_PORT_ID_LBC) | (PORT_E == E_TX_PORT_ID_MSG));

///////////////////////////////////////////
// Null old codes if new generated
///////////////////////////////////////////
always_comb begin
  for (int i=0; i<N; i++) begin : null_prot_codes
    xaim_pkt_pre_delay[i] = i_xaim_pkt[i];

    if (BUS_PROTECT_GEN_EN_PRFX == 1)
      xaim_pkt_pre_delay[i].prfx_prot       = '0;
    if (BUS_PROTECT_GEN_EN_HDR  == 1) begin
      xaim_pkt_pre_delay[i].hdr_prot        = '0;
      xaim_pkt_pre_delay[i].hdr_prot_msglbc = '0;
    end
    if (BUS_PROTECT_GEN_EN_DATA == 1)
      xaim_pkt_pre_delay[i].data_prot       = '0;
  end
end

logic [N-1:0] valid_in;
logic [N-1:0] valid_out;
generate 
  for (genvar i=0; i<N; i++) begin : xaim_pkt_pipe
    assign valid_in[i] = xaim_pkt_pre_delay[i].fs.hv || xaim_pkt_pre_delay[i].fs.dv;
    ///////////////////////////////////////////
    // Pipeline delay for xaim_pkt_t type
    ///////////////////////////////////////////
    pipe_w_hs
     #(
        .WD            ($bits(xaim_pkt_t)),
        .FORWARD_PIPE  (PIPE),
        .BACKWARD_PIPE (CAN_STALL)
    ) u_pipe_w_hs (
        .clk       (clk                   ),
        .rst_n     (rst_n                 ),
        .valid_in  (valid_in[i]           ),
        .halt_out  (o_xaim_halt[i]        ),
        .d_in      (xaim_pkt_pre_delay[i] ),
        .valid_out (valid_out[i]          ),
        .halt_in   (i_xaim_halt[i]        ),
        .d_out     (xaim_pkt_post_delay[i])
    );


    ///////////////////////////////////////////
    // RASDP CHK/GEN delay for prefix
    ///////////////////////////////////////////
    ras_dp_pipe
     #(
      .PIPELINE_TYPE      ( 2                        ),
      .RESETVAL           ( 0                        ),
      .N_STAGES           ( PIPE                     ),
      .CAN_STALL          ( CAN_STALL                ),
      .RESET_STALL        ( 0                        ),
      .BUS_PROTECT_GEN_EN ( BUS_PROTECT_GEN_EN_PRFX  ),
      .BUS_PROTECT_CHK_EN ( BUS_PROTECT_CHK_EN_PRFX  ),
      .PROT_TYPE          ( PROT_TYPE                ),
      .PROT_RANGE         ( PROT_RANGE               ),
      .PROT_WD            ( XALI_PRFX_PROT_WD        ),
      .PARITY_MODE        ( PARITY_MODE              ),
      .PROT_CORRECT_EN    ( PROT_CORRECT_EN          ),
      .TOTAL_WIDTH        ( XALI_PRFX_WO_PROT_WD     ),
      .EXCLUDE_PROT_WIDTH ( 0                        ),
      .RAS_DP_PROT_CHK_ID_BASE ( RAS_DP_PROT_CHK_ID_BASE + (i*(3)) )
    ) u_ras_dp_pipe_prfx_prot (
      .clk,
      .rst_n,
      .en                        ( 1'b1                         ),
      .bypass                    ( 1'b0                         ),
      .ras_dp_err_inband_kbd_in  ( i_xaim_pkt[i].rasdp_kbd_prfx ),
      .ras_dp_err_inband_kbd_out ( rasdp_kbd_prfx[i]            ),
      .ras_dp_err_log            ( ras_dp_err_log_int[i][0]     ),
      .ras_dp_err_inj            ( ras_dp_err_inj               ),
      .stall                     ( i_xaim_halt[i]               ),
      .valid_in                  ( i_xaim_pkt[i].fs.hv          ),
      .halt_in                   ( 1'b0                         ),
      .din                       ( i_xaim_pkt[i].prfx           ),
      .din_prot                  ( i_xaim_pkt[i].prfx_prot      ),
      .stallout                  (                              ),
      .valid_out                 (                              ),
      .halt_out                  (                              ),
      .dout_prot                 ( prfx_prot_post_delay[i]      ),
      .dout                      (                              )
    );

    ///////////////////////////////////////////
    // RASDP CHK/GEN delay for header
    ///////////////////////////////////////////
    assign hdr_pre_delay[i]      = port_is_msglbc ? (HDR_WO_PROT_WD)'(i_xaim_pkt[i].hdr_msglbc) : (HDR_WO_PROT_WD)'(f_protected_xali_hdr(i_xaim_pkt[i]));
    assign hdr_prot_pre_delay[i] = port_is_msglbc ? (HDR_PROT_WD)'(i_xaim_pkt[i].hdr_prot_msglbc) : (HDR_PROT_WD)'(i_xaim_pkt[i].hdr_prot);
    //assign hdr_valid_in[i]       = port_is_msglbc ? 1'b0 : i_xaim_pkt[i].fs.hv;

    ras_dp_pipe
     #(
      .PIPELINE_TYPE      ( 2                        ),
      .RESETVAL           ( 0                        ),
      .N_STAGES           ( PIPE                     ),
      .CAN_STALL          ( CAN_STALL                ),
      .RESET_STALL        ( 0                        ),
      .BUS_PROTECT_GEN_EN ( BUS_PROTECT_GEN_EN_HDR   ),
      .BUS_PROTECT_CHK_EN ( BUS_PROTECT_CHK_EN_HDR   ),
      .PROT_TYPE          ( PROT_TYPE                ),
      .PROT_RANGE         ( PROT_RANGE               ),
      .PROT_WD            ( HDR_PROT_WD              ),
      .PARITY_MODE        ( PARITY_MODE              ),
      .PROT_CORRECT_EN    ( PROT_CORRECT_EN          ),
      .TOTAL_WIDTH        ( HDR_WO_PROT_WD           ),
      .EXCLUDE_PROT_WIDTH ( 0                        ),
      .RAS_DP_PROT_CHK_ID_BASE ( RAS_DP_PROT_CHK_ID_BASE + 1 + (i*(3)) )
    ) u_ras_dp_pipe_hdr_prot (
      .clk,
      .rst_n,
      .en                        ( 1'b1                        ),
      .bypass                    ( 1'b0                        ),
      .ras_dp_err_inband_kbd_in  ( i_xaim_pkt[i].rasdp_kbd_hdr ),
      .ras_dp_err_inband_kbd_out ( rasdp_kbd_hdr[i]            ),
      .ras_dp_err_log            ( ras_dp_err_log_int[i][1]    ),
      .ras_dp_err_inj            ( ras_dp_err_inj              ),
      .stall                     ( i_xaim_halt[i]              ),
      .valid_in                  ( i_xaim_pkt[i].fs.hv         ),
      .halt_in                   ( 1'b0                        ),
      .din                       ( hdr_pre_delay[i]            ),
      .din_prot                  ( hdr_prot_pre_delay[i]       ),
      .stallout                  (                             ),
      .valid_out                 (                             ),
      .halt_out                  (                             ),
      .dout_prot                 ( hdr_prot_post_delay[i]      ),
      .dout                      (                             )  
    );

    ///////////////////////////////////////////
    // RASDP CHK/GEN delay for data
    ///////////////////////////////////////////
    ras_dp_pipe
     #(
      .PIPELINE_TYPE      ( 2                        ),
      .RESETVAL           ( 0                        ),
      .N_STAGES           ( PIPE                     ),
      .CAN_STALL          ( CAN_STALL                ),
      .RESET_STALL        ( 0                        ),
      .BUS_PROTECT_GEN_EN ( BUS_PROTECT_GEN_EN_DATA  ),
      .BUS_PROTECT_CHK_EN ( BUS_PROTECT_CHK_EN_DATA  ),
      .PROT_TYPE          ( PROT_TYPE                ),
      .PROT_RANGE         ( PROT_RANGE               ),
      .PROT_WD            ( XALI_DATA_PROT_WD        ),
      .PARITY_MODE        ( PARITY_MODE              ),
      .PROT_CORRECT_EN    ( PROT_CORRECT_EN          ),
      .TOTAL_WIDTH        ( XALI_DATA_WO_PROT_WD     ),
      .EXCLUDE_PROT_WIDTH ( 0                        ),
      .RAS_DP_PROT_CHK_ID_BASE ( RAS_DP_PROT_CHK_ID_BASE + 2 + (i*(3)) )
    ) u_ras_dp_pipe_data_prot (
      .clk,
      .rst_n,
      .en                        ( 1'b1                         ),
      .bypass                    ( 1'b0                         ),
      .ras_dp_err_inband_kbd_in  ( i_xaim_pkt[i].rasdp_kbd_data ),
      .ras_dp_err_inband_kbd_out ( rasdp_kbd_data[i]            ),
      .ras_dp_err_log            ( ras_dp_err_log_int[i][2]     ),
      .ras_dp_err_inj            ( ras_dp_err_inj               ),
      .stall                     ( i_xaim_halt[i]               ),
      .valid_in                  ( i_xaim_pkt[i].fs.dv          ),
      .halt_in                   ( 1'b0                         ),
      .din                       ( i_xaim_pkt[i].data           ),
      .din_prot                  ( i_xaim_pkt[i].data_prot      ),
      .stallout                  (                              ),
      .valid_out                 (                              ),
      .halt_out                  (                              ),
      .dout_prot                 ( data_prot_post_delay[i]      ),
      .dout                      (                              )
    );
  end
endgenerate

///////////////////////////////////////////
// Merge newly generated codes/kbds
///////////////////////////////////////////
always_comb begin
  for (int i=0; i<N; i++) begin : merge_prot_codes
    o_xaim_pkt[i]                = xaim_pkt_post_delay[i];
    o_xaim_pkt[i].fs.hv          = xaim_pkt_post_delay[i].fs.hv      && valid_out[i];
    o_xaim_pkt[i].fs.dv          = xaim_pkt_post_delay[i].fs.dv      && valid_out[i];
    o_xaim_pkt[i].fs.eot         = xaim_pkt_post_delay[i].fs.eot     && valid_out[i];
    o_xaim_pkt[i].fs.bad_eot     = xaim_pkt_post_delay[i].fs.bad_eot && valid_out[i];

    if (BUS_PROTECT_GEN_EN_PRFX == 1)
      o_xaim_pkt[i].prfx_prot = prfx_prot_post_delay[i];
    if (BUS_PROTECT_GEN_EN_HDR  == 1) begin
      o_xaim_pkt[i].hdr_prot        = ~port_is_msglbc ? (XALI_HDR_PROT_WD)'(hdr_prot_post_delay[i])    : '0;
      o_xaim_pkt[i].hdr_prot_msglbc = port_is_msglbc  ? (LBC_MSG_HDR_PROT_WD)'(hdr_prot_post_delay[i]) : '0;
    end
    if (BUS_PROTECT_GEN_EN_DATA == 1)
      o_xaim_pkt[i].data_prot = data_prot_post_delay[i];
    o_xaim_pkt[i].rasdp_kbd_prfx = rasdp_kbd_prfx[i];
    o_xaim_pkt[i].rasdp_kbd_hdr  = rasdp_kbd_hdr[i];
    o_xaim_pkt[i].rasdp_kbd_data = rasdp_kbd_data[i];
  end
end

///////////////////////////////////////////
// Gate Error Logs
///////////////////////////////////////////
logic [1:0] IN_OFFSET;

always_comb begin
  ras_dp_err_log = '0;
  IN_OFFSET = '0;
  // place prefix ras_dp_err_log if present
  for (int i=0; i<N; i++) begin
      ras_dp_err_log[i][IN_OFFSET] = ras_dp_err_log_int[i][0];
  end
  IN_OFFSET = IN_OFFSET + BUS_PROTECT_CHK_EN_PRFX;
  // place hdr ras_dp_err_log if present
  for (int i=0; i<N; i++) begin
      ras_dp_err_log[i][IN_OFFSET] = ras_dp_err_log_int[i][1];
  end
  IN_OFFSET = IN_OFFSET + BUS_PROTECT_CHK_EN_HDR;
  // place data ras_dp_err_log if present
  for (int i=0; i<N; i++) begin
      ras_dp_err_log[i][IN_OFFSET] = ras_dp_err_log_int[i][2];
  end
end


///////////////////////////////////////////
// The purpose of this function is to
// extract the information which is protected
// with the hdr_prot code from the incoming
// packet and to format this into a vector
// for both checking/generation
///////////////////////////////////////////
function automatic logic [XALI_HDR_WO_PROT_WD-1:0] f_protected_xali_hdr (
  input xaim_pkt_t xaim_pkt
);
  f_protected_xali_hdr  = 0;
  f_protected_xali_hdr  = {
                       xaim_pkt.tlp_hdr_pkt.tlp_th,
                       xaim_pkt.tlp_hdr_pkt.tlp_st[7:0],
                       xaim_pkt.tlp_hdr_pkt.tlp_ph,
                       (PF_WD)'(xaim_pkt.tlp_hdr_pkt.tlp_fn),
                       (ATTR_WD)'(xaim_pkt.tlp_hdr_pkt.tlp_attr),
                       xaim_pkt.tlp_hdr_pkt.tlp_at,
                       xaim_pkt.tlp_hdr_pkt.tlp_nw,
                       xaim_pkt.addr_align_en,
                       xaim_pkt.tlp_hdr_pkt.tlp_ldw_be,
                       xaim_pkt.tlp_hdr_pkt.tlp_fdw_be,
                       xaim_pkt.tlp_hdr_pkt.tlp_req_id,
                       xaim_pkt.tlp_hdr_pkt.tlp_cpl_status,
                       xaim_pkt.tlp_hdr_pkt.tlp_bcm,
                       xaim_pkt.tlp_hdr_pkt.tlp_byte_count,
                       (TAG_SIZE)'(xaim_pkt.tlp_hdr_pkt.tlp_tag),
                       //{xaim_pkt.tlp_hdr_pkt.tlp_len, xaim_pkt.tlp_byte_len[1:0]},
                       xaim_pkt.tlp_byte_len,
                       xaim_pkt.tlp_hdr_pkt.tlp_ep,
                       xaim_pkt.tlp_hdr_pkt.tlp_td,
                       xaim_pkt.tlp_hdr_pkt.tlp_tc,
                       xaim_pkt.tlp_hdr_pkt.tlp_type,
                       xaim_pkt.tlp_hdr_pkt.tlp_fmt[1:0],
                       xaim_pkt.tlp_hdr_pkt.tlp_addr
                     };
endfunction // f_protected_xali_hdr



endmodule

