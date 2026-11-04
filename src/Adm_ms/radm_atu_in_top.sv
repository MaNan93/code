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
// ---    $DateTime: 2023/09/27 02:27:25 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_atu_in_top.sv#4 $
// -------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// --- Module description:  This is for core only wrapper for dual mode/end device/root complex/switch application.
// This file is instatiation of inbound ATU module in single ATU mode and ATU used before RADM Q in gen5 mode. 
// TO DO: SK: As of not we kept same Gen5 module. Later will remove one instance depends on final analysis/review

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"
`include "Cdm/cdm_pkg.svh"

module radm_atu_in_top

  import radm_ms_pkg::RADM_ATU_CPIPE_EN;

import radm_ms_pkg::ATU_IN_MIN1;
  import radm_ms_pkg::radm_cfg_atu_s;
  import radm_ms_pkg::radm_flt_atu_s;
import radm_ms_pkg::ATU_IPIPE_PROT_WD; 
import radm_ms_pkg::radm_atu_opipe_s; 
import radm_ms_pkg::ATU_OPIPE_PROT_WD; 
   import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;



  
                        (
    // ------------ Inputs ---------------
    input                                                     core_clk,
    input                                                     radm_clk_ug,
    input                                                     non_sticky_rst_n,
    // ATU inbound Region controls
    input radm_flt_atu_s                                      radm_flt_atu_hdr,
    input                                                     radm_flt_atu_hv,
    input                                                     dmux_flt_halt_in, 
    input radm_cfg_atu_s                                      radm_cfg_atu_in,
    // Address translation outputs to RADM
    output [64-1:0]                                           radm_atu_translated_addr,
      output logic [2-1:0]                                    radm_atu_translated_err,
    output logic                                              radm_atu_uppr_bytes_valid
      ,
      input                                                   radm_flt_atu_eot,
      output logic [$clog2(ATU_IN_MIN1)-1:0]                  radm_atu_sloc_region,
      output logic                                            radm_atu_sloc_match,
      output logic                                            radm_atu_cbuf_err
     ,input [ATU_IPIPE_PROT_WD-1:0]   radm_flt_atu_hdr_prot
     ,output ras_dp_err_log_t   [2+`CX_IATU_LATENCY_RADM-1:0] ras_dp_err_log
     ,input  ras_dp_err_inj_t                                ras_dp_err_inj
  
  );
  parameter RAS_DP_PROT_CHK_ID_BASE  = 0;
  parameter IPIPE_EN = 1;
  parameter CPIPE_EN = RADM_ATU_CPIPE_EN;
  parameter OPIPE_EN = `CX_IATU_LATENCY_RADM;


  localparam PROT_RANGE      = `CX_RAS_PROT_RANGE;
  localparam PROT_TYPE       = `CX_RAS_PROT_TYPE;
  localparam PARITY_MODE     = `CX_RAS_PARITY_MODE;
  localparam PROT_CORRECT_EN = PROT_TYPE? 0 : `CX_RAS_CORRECTION_EN;
  localparam ATU_IPIPE_DELAY = 1;
  localparam ATU_OPIPE_DELAY = 1;
  // ------------------------------------------------------------------------------------------
  // Interface Signal Descriptions
  // ------------------------------------------------------------------------------------------
  radm_flt_atu_s                    radm_flt_atu_hdr_d;
  logic [63 : 0]                    radm_atu_translated_addr_int;
  logic [1:0]                       radm_atu_translated_err_int;
  logic                             radm_atu_uppr_bytes_valid_int;
  logic                             radm_flt_atu_hv_d;
   logic [$clog2(ATU_IN_MIN1)-1:0]  radm_atu_sloc_region_int;
   logic                            radm_atu_sloc_match_int;
   logic                            radm_atu_cbuf_err_int;
   logic                            radm_flt_atu_eot_d;
  logic                                      radm_flt_atu_hv_en_d;
  
generate if(IPIPE_EN) begin : g_atu_pre_reg_on
  delay_n_w_enable
  
  #( .N (ATU_IPIPE_DELAY), .WD($bits(radm_flt_atu_s)) ) 
  u_atu_ipipe 
  (
    .clk        (core_clk),
    .rst_n      (non_sticky_rst_n),
    .clear      (1'b0),
    .en         (radm_flt_atu_hv),
    .din        (radm_flt_atu_hdr),
    .dout       (radm_flt_atu_hdr_d)
  );
 
    delay_n
    
    #( .N (ATU_IPIPE_DELAY), .WD(2) ) 
    u_atu_ipipe_eot 
    (
      .clk        (core_clk),
      .rst_n      (non_sticky_rst_n),
      .clear      (1'b0),
      .din        ({radm_flt_atu_hv, radm_flt_atu_eot}),
      .dout       ({radm_flt_atu_hv_d,radm_flt_atu_eot_d})
    );

  
  logic [ATU_IPIPE_PROT_WD-1:0] radm_flt_atu_hdr_prot_d;

  delay_n_w_enable
  
  #( .N (ATU_IPIPE_DELAY), .WD(ATU_IPIPE_PROT_WD) ) 
  u_atu_ipipe_prot_delay 
  (
    .clk        (core_clk),
    .rst_n      (non_sticky_rst_n),
    .clear      (1'b0),
    .en         (radm_flt_atu_hv),
    .din        (radm_flt_atu_hdr_prot),
    .dout       (radm_flt_atu_hdr_prot_d)
  );

  // DPP checker for ATU input
  ras_dp_pipe
   #(
      .PIPELINE_TYPE           (0),                       // No pipeline only checker instance
      .RESETVAL                (0),                       // Reset value set to 0
      .N_STAGES                (0),                       // No pipeline delay from module
      .CAN_STALL               (0),                       // No stalling
      .RESET_STALL             (0),                       // Stall reset value set to 0.
      .BUS_PROTECT_GEN_EN      (0),                       // generater disabled
      .BUS_PROTECT_CHK_EN      (1),                       // Checker enabled
      .PROT_TYPE               (PROT_TYPE),               
      .PROT_RANGE              (PROT_RANGE),    
      .PROT_WD                 (ATU_IPIPE_PROT_WD),
      .PARITY_MODE             (PARITY_MODE),             
      .PROT_CORRECT_EN         (PROT_CORRECT_EN),         
      .TOTAL_WIDTH             ($bits(radm_flt_atu_s)),                      // Total width  
      .EXCLUDE_PROT_WIDTH      (0),
      .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE),
      .PIPE_RAS_DP_ERR_LOG     (1)
  ) u_ras_dp_atu_ipipe_chk (
      .clk                      (core_clk           ),
      .rst_n                    (non_sticky_rst_n   ),
      .en                       (1'b1               ),
      .bypass                   (1'b0               ),
      .stall                    (1'b0               ),
      .stallout                 (                   ),
      
      .valid_in                 (radm_flt_atu_hv_d  ),
      .din                      (radm_flt_atu_hdr_d ),
      .din_prot                 (radm_flt_atu_hdr_prot_d), 
      .halt_out                 (                   ),
      
      .valid_out                (                   ),
      .dout                     (                   ),
      .dout_prot                (                   ),
      .halt_in                  (1'b0               ),
      .ras_dp_err_inband_kbd_in (1'b0               ),
      .ras_dp_err_inband_kbd_out(                   ),
      .ras_dp_err_log           (ras_dp_err_log[0]  )
      ,.ras_dp_err_inj          (ras_dp_err_inj     )
  );

end else begin : g_atu_pre_reg_off
  assign ras_dp_err_log[0]   = 'd0;
  assign radm_flt_atu_hdr_d  = radm_flt_atu_hdr;
  assign radm_flt_atu_hv_d   = radm_flt_atu_hv;
   assign radm_flt_atu_eot_d = radm_flt_atu_eot;
end
endgenerate

  // Integrated Address Translation Unit

    // Inbound Translation
    radm_atu_in
     
    #(.CPIPE_EN (CPIPE_EN), .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+1) )
    u_radm_atu_in
    (
      // ------------ Inputs ---------------
      .core_clk                                       (core_clk                       ),
      .radm_clk_ug                                    (radm_clk_ug                    ),
      .non_sticky_rst_n                               (non_sticky_rst_n               ),
          
      // TLP information from RADM          
      .radm_flt_atu_in                                (radm_flt_atu_hdr_d             ),
      .halt_in                                        (dmux_flt_halt_in               ),
      .radm_outq_pkt_hv                               (radm_flt_atu_hv_d              )
     ,
      .radm_cfg_atu_in                                (radm_cfg_atu_in                )
      // Address translation outputs to RADM

        ,
        .rtranslated_addr_in_d                        (radm_atu_translated_addr_int   ),
        .rtranslated_err_in_d                         (radm_atu_translated_err_int    )
      ,
      .atu_in_tlp_xlate                               (radm_atu_uppr_bytes_valid_int  ) 
        ,                                           
        .atu_in_sloc_region                           (radm_atu_sloc_region_int       ),
        .atu_in_sloc_match                            (radm_atu_sloc_match_int        ),
        .atu_in_cbuf_err                              (radm_atu_cbuf_err_int          ),
        .radm_outq_pkt_eot                            (radm_flt_atu_eot_d             )
      ,.ras_dp_err_log                                (ras_dp_err_log[1])
      ,.radm_atu_outq_pkt_hv_d                        (radm_flt_atu_hv_en_d)
      ,.ras_dp_err_inj                                (ras_dp_err_inj)
    );


  localparam  OPIPE_WIDTH = $bits(radm_atu_uppr_bytes_valid_int) 
                              + $bits(radm_atu_translated_addr_int) + $bits(radm_atu_translated_err_int)
                              + $bits(radm_atu_sloc_region_int) + $bits(radm_atu_sloc_match_int) + $bits(radm_atu_cbuf_err_int) 
;

  radm_atu_opipe_s                           radm_atu_opipe_data;
  radm_atu_opipe_s                           radm_atu_opipe_data_d;

  assign radm_atu_opipe_data = {radm_atu_uppr_bytes_valid_int,
                              radm_atu_translated_addr_int,radm_atu_translated_err_int
                              ,radm_atu_sloc_region_int, radm_atu_sloc_match_int, radm_atu_cbuf_err_int
                            };

generate if (`CX_IATU_LATENCY_RADM) begin : g_opipe_gen_chk_en

  ras_dp_pipe
   #(
      .PIPELINE_TYPE           (6),                       // No pipeline only checker instance
      .RESETVAL                (0),                       // Reset value set to 0
      .N_STAGES                (1),                       // No pipeline delay from module
      .CAN_STALL               (1),                       // No stalling
      .RESET_STALL             (0),                       // Stall reset value set to 0.
      .BUS_PROTECT_GEN_EN      (1),                       // generater enabled
      .BUS_PROTECT_CHK_EN      (1),                       // Checker enabled
      .PROT_TYPE               (PROT_TYPE),               
      .PROT_RANGE              (PROT_RANGE),    
      .PROT_WD                 (ATU_OPIPE_PROT_WD),
      .PARITY_MODE             (PARITY_MODE),             
      .PROT_CORRECT_EN         (PROT_CORRECT_EN),         
      .TOTAL_WIDTH             ($bits(radm_atu_opipe_s)),                      // Total width  
      .EXCLUDE_PROT_WIDTH      (0),
      .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+2),
      .PIPE_RAS_DP_ERR_LOG     (1)
  ) u_ras_dp_atu_opipe_chk (
      .clk                      (core_clk           ),
      .rst_n                    (non_sticky_rst_n   ),
      .en                       (1'b1               ),
      .bypass                   (1'b0               ),
      .stall                    (1'b0               ),
      .stallout                 (                   ),
      
      .valid_in                 (radm_flt_atu_hv_en_d ),
      .din                      (radm_atu_opipe_data),
      .din_prot                 ('0                 ), // If generator and checker enabled in same module, "din_port" should be "0" 
      .halt_out                 (                   ),
      
      .valid_out                (                   ),
      .dout                     ( { radm_atu_uppr_bytes_valid
                   , radm_atu_translated_addr, radm_atu_translated_err
                  , radm_atu_sloc_region, radm_atu_sloc_match, radm_atu_cbuf_err
                  }                  ),
      .dout_prot                (                   ),
      .halt_in                  (1'b0               ),
      .ras_dp_err_inband_kbd_in (1'b0               ),
      .ras_dp_err_inband_kbd_out(                   ),
      .ras_dp_err_log           (ras_dp_err_log[2]  )
      ,.ras_dp_err_inj          (ras_dp_err_inj     )
      );
end 
else begin : g_atu_post_reg_off
  assign radm_atu_uppr_bytes_valid = radm_atu_uppr_bytes_valid_int;
  assign radm_atu_translated_addr  = radm_atu_translated_addr_int;
  assign radm_atu_translated_err   = radm_atu_translated_err_int;
  assign radm_atu_sloc_region      = radm_atu_sloc_region_int;
  assign radm_atu_sloc_match       = radm_atu_sloc_match_int;
  assign radm_atu_cbuf_err         = radm_atu_cbuf_err_int;
end
endgenerate


endmodule
