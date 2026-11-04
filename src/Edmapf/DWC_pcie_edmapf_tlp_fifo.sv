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
// ---    $DateTime: 2021/10/29 02:04:56 $
// ---    $Revision: #8 $
// ---    $Author: neira $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_tlp_fifo.sv#8 $
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_genericData_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_tlp_fifo
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration
  // ##########################################################################
   parameter type P_TLPTYPE = logic
  ,parameter       P_DATAWD = 32*K_NW
  ,parameter        P_DEPTH = 3
  ) (
  // ##########################################################################
  //                                Ports Declaration
  // ##########################################################################

   DWC_pcie_edmapf_aclks_if.slave_mp        b_clkrst

  ,DWC_pcie_edmapf_tlp_if.master_mp         b_dst

  ,DWC_pcie_edmapf_genericData_if.slave_mp  b_enable

  ,DWC_pcie_edmapf_genericData_if.master_mp b_fFull

  ,DWC_pcie_edmapf_tlp_if.slave_mp          b_src
  );


// SNPS_SysML_CODE_START
  localparam L_HEADERPROTWD = (($bits(P_TLPTYPE)-1)/K_RAS_PROT_RANGE+1);

  typedef struct packed{
    logic [P_DATAWD-1:0]       data       ;
    P_TLPTYPE                  header     ;
    logic [L_HEADERPROTWD-1:0] headerProt ;
    logic                      hv         ;
    logic                      dv         ;
    logic                      eot        ;
  } tlp_s;

  tlp_s s_src_tlp, s_dst_tlp;

  localparam LP_SIZEOF_TLP = $bits(s_src_tlp);

  assign s_src_tlp.data       = b_src.w_data;
  assign s_src_tlp.header     = b_src.w_header;
  assign s_src_tlp.headerProt = b_src.w_headerProt;
  assign s_src_tlp.hv         = b_src.w_hv;
  assign s_src_tlp.dv         = b_src.w_dv;
  assign s_src_tlp.eot        = b_src.w_eot;

  localparam integer LP_REG_DELAY_DENOM  = 1000;
  localparam integer LP_REG_DELAY_TIME   = `TP * LP_REG_DELAY_DENOM;
  localparam integer LP_DEPTH            = P_DEPTH < 2 ? 2 : P_DEPTH;
  localparam integer LP_DEPTH_LOG2       = $clog2(LP_DEPTH);

  logic s_push_req_n;
  logic s_pop_req_n;
  logic s_full, s_empty;
  logic nc_almost_empty;
  logic nc_half_full;
  logic nc_almost_full;
  logic s_error;
  typedef logic [LP_SIZEOF_TLP-1:0] t_tlp_raw;
  t_tlp_raw s_data_in, s_data_out;

  assign s_push_req_n = !(s_src_tlp.hv | s_src_tlp.dv) | b_src.w_halt;
  assign s_pop_req_n  = s_empty | b_dst.w_halt;

  assign s_data_in = t_tlp_raw'(s_src_tlp);

  DWC_pcie_ctl_bcm65_td
   #(
    .WIDTH          (LP_SIZEOF_TLP     ),
    .DEPTH          (LP_DEPTH          ),
    .AE_LEVEL       (1                 ),
    .AF_LEVEL       (1                 ),
    .ERR_MODE       (2                 ),
    .RST_MODE       (0                 ),
    .ADDR_WIDTH     (LP_DEPTH_LOG2     ),
    .REG_DELAY_TIME (LP_REG_DELAY_TIME ),
    .REG_DELAY_DENOM(LP_REG_DELAY_DENOM)
 )u_fifo (
    .clk         (b_clkrst.w_main_clk),
    .rst_n       (b_clkrst.w_reset_n ),
    .init_n      (1'b1               ),
    .push_req_n  (s_push_req_n       ),
    .pop_req_n   (s_pop_req_n        ),
    .diag_n      (1'b0               ),
    .data_in     (s_data_in          ),
    .empty       (s_empty            ),
    // SMD: A signal or variable is set but never read  
    // SJ:  BCM output signals not required by the logic
    // spyglass disable_block W528
    .almost_empty(nc_almost_empty    ),
    .half_full   (nc_half_full       ),
    .almost_full (nc_almost_full     ),
    .error       (s_error            ),
    // spyglass enable_block W528
    .full        (s_full             ),
    .data_out    (s_data_out         )
    );

  assign s_dst_tlp = tlp_s'(s_data_out);

  assign b_src.w_halt       = (s_full & s_pop_req_n ) || !b_enable.w_data;
  assign b_dst.w_hv         = s_dst_tlp.hv    & !s_empty;
  assign b_dst.w_dv         = s_dst_tlp.dv    & !s_empty;
  assign b_dst.w_eot        = s_dst_tlp.eot   & !s_empty;
  assign b_dst.w_header     = s_dst_tlp.header;
  assign b_dst.w_headerProt = s_dst_tlp.headerProt;
  assign b_dst.w_data       = s_dst_tlp.data  ;

  assign b_fFull.w_data = s_full;


// SNPS_SysML_CODE_END

endmodule : DWC_pcie_edmapf_tlp_fifo
