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
// ---    $DateTime: 2023/04/29 12:35:01 $ 
// ---    $Revision: #10 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_wackAdapter.sv#10 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_wresp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_wack_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_wackAdapter
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter P_MAXMWR = 1024
  ,parameter  P_TAGWD = 10
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_aclks_if.slave_mp     b_clk
  ,DWC_pcie_edmapf_tlp_if.slave_mp       b_mwrIn
  ,DWC_pcie_edmapf_tlp_if.master_mp      b_mwrOut
  ,DWC_pcie_edmapf_wack_if.master_mp     b_wack
  ,DWC_pcie_edmapf_tlp_wresp_if.slave_mp b_wresp
  );


// SNPS_SysML_CODE_START
  localparam integer L_REG_DELAY_DENOM = 1000;
  localparam integer L_REG_DELAY_TIME  = `TP * L_REG_DELAY_DENOM;

  logic                              s_wrespFifo_push_req_n  ;
  logic                              s_wrespFifo_pop_req_n   ;
  logic                              w_wrespFifo_empty       ;
  logic                              s_wrespFifo_data_in     ;
  logic                              w_wrespFifo_data_out    ;

  logic                              s_mwrTagFifo_push_req_n ;
  logic                              s_mwrTagFifo_pop_req_n  ;
  logic                              w_mwrTagFifo_full       ;
  logic [P_TAGWD+K_RD_DMACHANWD-1:0] s_mwrTagFifo_data_in    ;
  logic [P_TAGWD+K_RD_DMACHANWD-1:0] w_mwrTagFifo_data_out   ;

  // Disabled to improve coverage forced by design and assetion below
  //logic               s_isMWr                 ;

  //assign s_isMWr = (b_mwrIn.w_header ==? K_MWRHEADER);

  assign b_mwrOut.w_data   = b_mwrIn.w_data   ;
  assign b_mwrOut.w_header = b_mwrIn.w_header ;
  assign b_mwrOut.w_headerProt = b_mwrIn.w_headerProt ;

  always_comb begin : halt_PROC
    if (b_mwrIn.w_hv /*&& s_isMWr*/ && w_mwrTagFifo_full) begin
      b_mwrOut.w_hv  = '0;
      b_mwrOut.w_dv  = '0;
      b_mwrOut.w_eot = '0;
      b_mwrIn.w_halt = '1;
    end else begin
      b_mwrOut.w_hv  = b_mwrIn.w_hv    ;
      b_mwrOut.w_dv  = b_mwrIn.w_dv    ;
      b_mwrOut.w_eot = b_mwrIn.w_eot   ;
      b_mwrIn.w_halt = b_mwrOut.w_halt ;
    end
  end

  assign b_wack.w_tag     = w_mwrTagFifo_data_out[K_RD_DMACHANWD+:P_TAGWD]                        ;
  assign b_wack.w_error   = w_wrespFifo_data_out                                                  ;
  assign b_wack.w_valid   = !w_wrespFifo_empty                                                    ;
  assign b_wack.w_channel = (K_DMACHANWD)'(w_mwrTagFifo_data_out[K_RD_DMACHANWD-1:0]) ;

  assign s_wrespFifo_data_in    =  b_wresp.w_error ;
  assign s_wrespFifo_push_req_n = !b_wresp.w_valid ;
  assign s_wrespFifo_pop_req_n  = w_wrespFifo_empty || b_wack.w_halt;
  assign s_mwrTagFifo_pop_req_n = w_wrespFifo_empty || b_wack.w_halt;

  assign s_mwrTagFifo_push_req_n = !(/*s_isMWr && */b_mwrIn.w_hv && !b_mwrOut.w_halt && !w_mwrTagFifo_full);
  assign s_mwrTagFifo_data_in    = {b_mwrIn.w_header.tag , b_mwrIn.w_header.dma.channel[K_RD_DMACHANWD-1:0]};

  DWC_pcie_ctl_bcm65_td
   #(
     .WIDTH           ( 1                       )
    ,.DEPTH           ( P_MAXMWR                )
    ,.AE_LEVEL        ( 1                       )
    ,.AF_LEVEL        ( 1                       )
    ,.ERR_MODE        ( 2                       )
    ,.RST_MODE        ( 0                       )
    ,.ADDR_WIDTH      ( $clog2(P_MAXMWR)        )
    ,.REG_DELAY_TIME  ( L_REG_DELAY_TIME        )
    ,.REG_DELAY_DENOM ( L_REG_DELAY_DENOM       )
  ) u_wrespFifo(
     .clk             ( b_clk.w_main_clk        )
    ,.rst_n           ( b_clk.w_reset_n         )
    ,.init_n          ( 1'b1                    )
    ,.push_req_n      ( s_wrespFifo_push_req_n  )
    ,.pop_req_n       ( s_wrespFifo_pop_req_n   )
    ,.empty           ( w_wrespFifo_empty       )
    ,.data_in         ( s_wrespFifo_data_in     )
    ,.data_out        ( w_wrespFifo_data_out    )
    ,.diag_n          ( 1'b0                    )
    // SMD: Output port to an instance is not connected
    // SJ:  These ports are not used.
    // spyglass disable_block W287b
    ,.almost_empty    ( /* NC */                )
    ,.almost_full     ( /* NC */                )
    ,.error           ( /* NC */                )
    ,.full            ( /* NC */                )
    ,.half_full       ( /* NC */                )
    // spyglass enable_block W287b
    );

  DWC_pcie_ctl_bcm65_td
   #(
     .WIDTH           ( P_TAGWD+K_RD_DMACHANWD  )
    ,.DEPTH           ( P_MAXMWR                )
    ,.AE_LEVEL        ( 1                       )
    ,.AF_LEVEL        ( 1                       )
    ,.ERR_MODE        ( 2                       )
    ,.RST_MODE        ( 0                       )
    ,.ADDR_WIDTH      ( $clog2(P_MAXMWR)        )
    ,.REG_DELAY_TIME  ( L_REG_DELAY_TIME        )
    ,.REG_DELAY_DENOM ( L_REG_DELAY_DENOM       )
  ) u_mwrTagFifo(
     .clk             ( b_clk.w_main_clk        )
    ,.rst_n           ( b_clk.w_reset_n         )
    ,.init_n          ( 1'b1                    )
    ,.push_req_n      ( s_mwrTagFifo_push_req_n )
    ,.pop_req_n       ( s_mwrTagFifo_pop_req_n  )
    ,.full            ( w_mwrTagFifo_full       )
    ,.data_in         ( s_mwrTagFifo_data_in    )
    ,.data_out        ( w_mwrTagFifo_data_out   )
    ,.diag_n          ( 1'b0                    )
    // SMD: Output port to an instance is not connected
    // SJ:  These ports are not used.
    // spyglass disable_block W287b
    ,.almost_empty    ( /* NC */                )
    ,.almost_full     ( /* NC */                )
    ,.empty           ( /* NC */                )
    ,.error           ( /* NC */                )
    ,.half_full       ( /* NC */                )
    // spyglass enable_block W287b
    );




// SNPS_SysML_CODE_END

endmodule
