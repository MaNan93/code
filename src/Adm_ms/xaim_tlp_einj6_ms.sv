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
// ---    $DateTime: 2023/10/02 00:29:22 $
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/xaim_tlp_einj6_ms.sv#3 $
// -------------------------------------------------------------------------

// --- Module Description: 
// --- TLP header/prefix error injection
// -----------------------------------------------------------------------------

`include "DWC_pcie_ctl_pkg.svh"
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Adm_ms/xaim_ms_pkg.svh"
 
module xaim_tlp_einj6_ms
import DWC_pcie_core_pkg::*;
import DWC_pcie_ctl_pkg::*;
import xaim_ms_pkg::*;
(
  // Clocks/Resets
  input                                     core_clk,
  input                                     core_rst_n,
  // Configuration Structs
  input  cdm_xaim_cfg_t                     cdm_xaim_cfg,
  // Input Packet
  input  xadm_pkt_t                         i_xadm_pkt,
  output logic                              o_xadm_halt,
  // Output Packet
  output xadm_pkt_t                         o_xadm_pkt,
  input  logic                              i_xadm_halt,
  output logic                              xaim_einj6_valid,
  output logic                              xaim_einj6_tlp_evt
);

// Parameter/Enum Defines
typedef enum {
  BIG,
  LITTLE
} endian_e;

localparam NW_HDR           = ADM_PRFX_HDR_NW - NW_PRFX;
localparam EINJ_HDR_DW_3_0  = 0;
localparam EINJ_PRFX_DW_3_0 = 1; // Check register bits
localparam EINJ_PRFX_DW_7_4 = 2; // Check register bits
localparam EINJ_HDR_DW_7_4  = 3;
localparam EINJ_HDR_DW_11_8 = 4;

// Logic Defines
xadm_pkt_t              xadm_pkt_recon;      // reconstructed XADM packet with errors injected
xadm_pkt_t              xadm_pkt_d;
logic                   xadm_halt_d;
logic                   path_sel;
logic                   einj6_en;
logic                       [255:0] tlp_prfx_extract;
logic                         [1:0] tlp_prfx_evt;
logic                       [255:0] tlp_prfx_change;
logic [$clog2(ADM_PRFX_HDR_NW)-1:0] tlp_hdr_cnt_extract;
logic [$clog2(ADM_PRFX_HDR_NW)-1:0] tlp_hdr_cnt_recon;
logic      [ADM_PRFX_HDR_NW*32-1:0] tlp_hdr_extract;
logic                         [2:0] tlp_hdr_evt;
logic      [ADM_PRFX_HDR_NW*32-1:0] tlp_hdr_change;

logic     [1:0] [127:0] test_cmp;
logic     [1:0] [127:0] test_chg;

///////////////////////////////////////////
// Protection from the confiction between
// transmiting TLPs and switching einj
// enable bit
///////////////////////////////////////////
always_ff @( posedge core_clk or negedge core_rst_n ) begin
  if ( ~core_rst_n ) begin
    path_sel <= #TP 1'b0 ;
  end else begin
    if ( !i_xadm_pkt.hv && !i_xadm_pkt.dv && !o_xadm_halt && !xadm_pkt_d.hv && !xadm_pkt_d.dv && !xadm_halt_d )
      path_sel <= #TP cdm_xaim_cfg.einj6_enable ;
  end
end

assign einj6_en = path_sel & cdm_xaim_cfg.einj6_enable ;

///////////////////////////////////////////
// Extract Prefixes/Header/OHC
///////////////////////////////////////////
always_comb begin
  tlp_prfx_extract    = '0;
  tlp_hdr_extract     = '0;
  tlp_hdr_cnt_extract = '0; 

  // Prefix Extract
  for (int i=0; i<NW_PRFX; i++) begin
    if ( i_xadm_pkt.prfx_dwen[i] ) 
      tlp_prfx_extract[32*i+:32] = i_xadm_pkt.prfx_hdr[i];
  end

  // Header Extract
  for (int i=0; i<ADM_PRFX_HDR_NW; i++) begin
    if ( i_xadm_pkt.hdr_dwen[i] ) begin
      tlp_hdr_extract[32*tlp_hdr_cnt_extract+:32] = i_xadm_pkt.prfx_hdr[i];
      tlp_hdr_cnt_extract = tlp_hdr_cnt_extract + 1;
    end
  end
end

logic [127:0] tlp_hdr_extract_dw_11_8; 
generate
    if (ADM_PRFX_HDR_NW <= 8) begin : g_tlp_hdr_extract_dw_11_8
        assign tlp_hdr_extract_dw_11_8 = '0;
    end else if (ADM_PRFX_HDR_NW < 12) begin
        assign tlp_hdr_extract_dw_11_8 = {{(12-ADM_PRFX_HDR_NW){32'b0}}, tlp_hdr_extract[(ADM_PRFX_HDR_NW*32)-1:256]};
    end else begin
        assign tlp_hdr_extract_dw_11_8 = {                               tlp_hdr_extract[(             12*32)-1:256]};
    end
endgenerate

///////////////////////////////////////////
// DW Error Injection - Compare/Change
///////////////////////////////////////////
always_comb begin
  tlp_prfx_evt          = '0;
  tlp_prfx_change       = '0;
  tlp_hdr_evt           = '0;
  tlp_hdr_change[255:0] = '0;

  //Comparing
  tlp_prfx_evt[0]          = ( cdm_xaim_cfg.einj6_pkt_type == EINJ_PRFX_DW_3_0 ) ? f_compare ( einj6_en, cdm_xaim_cfg, i_xadm_pkt, o_xadm_halt, tlp_prfx_extract[127:0]   ) : '0;
  tlp_prfx_evt[1]          = ( cdm_xaim_cfg.einj6_pkt_type == EINJ_PRFX_DW_7_4 ) ? f_compare ( einj6_en, cdm_xaim_cfg, i_xadm_pkt, o_xadm_halt, tlp_prfx_extract[255:128] ) : '0;
  test_cmp                 = f_cmpArray (BIG, cdm_xaim_cfg);
  tlp_hdr_evt[0]           = ( cdm_xaim_cfg.einj6_pkt_type == EINJ_HDR_DW_3_0  ) ? f_compare ( einj6_en, cdm_xaim_cfg, i_xadm_pkt, o_xadm_halt, tlp_hdr_extract[127:0]   )  : '0;
  tlp_hdr_evt[1]           = ( cdm_xaim_cfg.einj6_pkt_type == EINJ_HDR_DW_7_4  ) ? f_compare ( einj6_en, cdm_xaim_cfg, i_xadm_pkt, o_xadm_halt, tlp_hdr_extract[255:128] )  : '0;
  tlp_hdr_evt[2]           = ( cdm_xaim_cfg.einj6_pkt_type == EINJ_HDR_DW_11_8 ) ? f_compare ( einj6_en, cdm_xaim_cfg, i_xadm_pkt, o_xadm_halt, tlp_hdr_extract_dw_11_8  )  : '0;

  // Changing
  tlp_prfx_change[127:0]   = f_change ( tlp_prfx_evt[0], cdm_xaim_cfg, tlp_prfx_extract[127:0]   );
  tlp_prfx_change[255:128] = f_change ( tlp_prfx_evt[1], cdm_xaim_cfg, tlp_prfx_extract[255:128] );
  test_chg                 = f_chgArray( BIG, cdm_xaim_cfg);
  tlp_hdr_change[127:0]    = f_change ( tlp_hdr_evt[0],  cdm_xaim_cfg, tlp_hdr_extract[127:0]    );
  tlp_hdr_change[255:128]  = f_change ( tlp_hdr_evt[1],  cdm_xaim_cfg, tlp_hdr_extract[255:128]  );
end

logic [127:0] tlp_hdr_change_dw_11_8;
generate
    if (ADM_PRFX_HDR_NW > 12) begin : g_tlp_hdr_change_dw_11_8
        always_comb begin
            tlp_hdr_change_dw_11_8        = f_change ( tlp_hdr_evt[2],  cdm_xaim_cfg, tlp_hdr_extract_dw_11_8   );
            tlp_hdr_change[(12*32)-1:256] = tlp_hdr_change_dw_11_8[((4)*32)-1:0];
        end
        assign tlp_hdr_change[(ADM_PRFX_HDR_NW*32)-1:(12*32)]  = tlp_hdr_extract[(ADM_PRFX_HDR_NW*32)-1:(12*32)];
    end else if (ADM_PRFX_HDR_NW > 8) begin : g_tlp_hdr_change_dw_gt_12
        always_comb begin
            tlp_hdr_change_dw_11_8                     = f_change ( tlp_hdr_evt[2],  cdm_xaim_cfg, tlp_hdr_extract_dw_11_8   );
            tlp_hdr_change[(ADM_PRFX_HDR_NW*32)-1:256] = tlp_hdr_change_dw_11_8[((ADM_PRFX_HDR_NW-8)*32)-1:0];
        end
    end
endgenerate

///////////////////////////////////////////
// Re-Insert Prefixes/Header/OHC
///////////////////////////////////////////
always_comb begin
  xadm_pkt_recon    = i_xadm_pkt;
  tlp_hdr_cnt_recon = 0;

  // Prefix Re-Insert
  for (int i=0; i<NW_PRFX; i++) begin
    if ( i_xadm_pkt.prfx_dwen[i] )
      xadm_pkt_recon.prfx_hdr[i] = tlp_prfx_change[32*i+:32];
  end

  // Header Re-Insert
  for (int i=0; i<ADM_PRFX_HDR_NW; i++) begin
    if ( i_xadm_pkt.hdr_dwen[i] ) begin
      xadm_pkt_recon.prfx_hdr[i] = tlp_hdr_change[32*tlp_hdr_cnt_recon+:32];
      tlp_hdr_cnt_recon = tlp_hdr_cnt_recon + 1;
    end
  end
end

///////////////////////////////////////////
// Delay/Anti-Glitch Logic
///////////////////////////////////////////
delay_n_w_stalling
 #(
  .N                   ( 1                     ), 
  .WD                  ( $bits(xadm_pkt_recon) ), 
  .CAN_STALL           ( 1                     ) 
) u_xadm_anti_glitch_pipe (
  .clk                 ( core_clk              ),
  .rst_n               ( core_rst_n            ),
  .stall               ( i_xadm_halt           ),
  .clear               ( 1'b0                  ),
  .din                 ( xadm_pkt_recon        ),
  .stallout            ( xadm_halt_d           ),
  .dout                ( xadm_pkt_d            )
);

///////////////////////////////////////////
// Output Assigns
///////////////////////////////////////////
assign o_xadm_pkt         = path_sel ? xadm_pkt_d  : xadm_pkt_recon;
assign o_xadm_halt        = path_sel ? xadm_halt_d : i_xadm_halt;
assign xaim_einj6_tlp_evt = ((|tlp_hdr_evt) | (|tlp_prfx_evt));
assign xaim_einj6_valid   = path_sel ;

///////////////////////////////////////////
// Functions
///////////////////////////////////////////
function automatic [127:0] f_swapEndian (
  input logic [127:0] data
);
  for (int i=0; i<4; i++) begin
    f_swapEndian[32*i   +:8] = data[32*i+24+:8];
    f_swapEndian[32*i+8 +:8] = data[32*i+16+:8];
    f_swapEndian[32*i+16+:8] = data[32*i+8 +:8];
    f_swapEndian[32*i+24+:8] = data[32*i   +:8];
  end
endfunction // f_swapEndian

function automatic [1:0] [127:0] f_cmpArray (
  input endian_e       endian,
  input cdm_xaim_cfg_t cdm_xaim_cfg
);
  begin
    logic [1:0] [127:0] int_array;

    int_array[0] = {cdm_xaim_cfg.einj6_cmp_point_h3, cdm_xaim_cfg.einj6_cmp_point_h2, cdm_xaim_cfg.einj6_cmp_point_h1, cdm_xaim_cfg.einj6_cmp_point_h0};
    int_array[1] = {cdm_xaim_cfg.einj6_cmp_value_h3, cdm_xaim_cfg.einj6_cmp_value_h2, cdm_xaim_cfg.einj6_cmp_value_h1, cdm_xaim_cfg.einj6_cmp_value_h0};

    if ( endian == BIG ) begin
      f_cmpArray[0] = f_swapEndian(int_array[0]);
      f_cmpArray[1] = f_swapEndian(int_array[1]);
    end else begin
      f_cmpArray[0] = int_array[0];
      f_cmpArray[1] = int_array[1];
    end

  end
endfunction // f_cmpArray

function automatic [1:0] [127:0] f_chgArray (
  input endian_e       endian,
  input cdm_xaim_cfg_t cdm_xaim_cfg
);
  begin
    logic [1:0] [127:0] int_array;

    int_array[0] = {cdm_xaim_cfg.einj6_chg_point_h3, cdm_xaim_cfg.einj6_chg_point_h2, cdm_xaim_cfg.einj6_chg_point_h1, cdm_xaim_cfg.einj6_chg_point_h0};
    int_array[1] = {cdm_xaim_cfg.einj6_chg_value_h3, cdm_xaim_cfg.einj6_chg_value_h2, cdm_xaim_cfg.einj6_chg_value_h1, cdm_xaim_cfg.einj6_chg_value_h0};

    if ( endian == BIG ) begin
      f_chgArray[0] = f_swapEndian(int_array[0]);
      f_chgArray[1] = f_swapEndian(int_array[1]);
    end else begin
      f_chgArray[0] = int_array[0];
      f_chgArray[1] = int_array[1];
    end
  end
endfunction // f_chgArray

function automatic logic f_compare (
  input logic          einj6_en,
  input cdm_xaim_cfg_t cdm_xaim_cfg,
  input xadm_pkt_t     xadm_pkt,
  input logic          halt,
  input logic  [127:0] dw_extract 
);
  begin
    logic [1:0] [127:0] dw_compare;
    dw_compare = f_cmpArray ( BIG, cdm_xaim_cfg);
    f_compare = einj6_en & xadm_pkt.hv & ~halt & ( (dw_extract & dw_compare[0]) == (dw_compare[0] & dw_compare[1]) );
  end
endfunction // f_compare

function automatic logic [127:0] f_change (
  input logic          evt,
  input cdm_xaim_cfg_t cdm_xaim_cfg,
  input logic  [127:0] dw_extract
);
  begin
    logic [1:0] [127:0] dw_change;
    dw_change = f_chgArray( BIG, cdm_xaim_cfg);
    if ( evt ) begin
      if ( cdm_xaim_cfg.einj6_invt_cont )
        f_change = ( dw_extract & ~dw_change[0] ) | ( ~dw_extract & dw_change[0] );
      else
        f_change = ( dw_extract & ~dw_change[0] ) | ( dw_change[1] & dw_change[0] );
    end else
      f_change = dw_extract;
  end
endfunction // f_change

endmodule // xaim_tlp_einj6_ms
