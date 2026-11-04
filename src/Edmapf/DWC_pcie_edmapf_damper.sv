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
// ---    $Revision: #6 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_damper.sv#6 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_damper
  import DWC_pcie_edmapf_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter       type P_DATATYPE = logic
  ,parameter           P_DAMPER_DP = 6
  ,parameter               P_TAGWD = 1
  ,parameter bool_e P_POPTYPE_PEEK = E_FALSE
  ,parameter  bool_e P_POPTYPE_RDY = E_FALSE
  ,parameter  bool_e P_POPTYPE_REG = E_FALSE
  ) 
                               (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   interface.slave_mp                b_pop
  ,interface.master_mp               b_popHaltable
  ,DWC_pcie_edmapf_aclks_if.slave_mp b_clk
  );


// SNPS_SysML_CODE_START
  /*
     Local paramaters used internally
  */
  localparam integer LP_REG_DELAY_DENOM = 1000;
  localparam integer LP_REG_DELAY_TIME  = `TP * LP_REG_DELAY_DENOM;
  localparam                 LP_ADDR_WD = $clog2(P_DAMPER_DP);
  /*
     Internal signals
  */
  logic                  s_empty;

  logic               s_pop, r_pop;
  logic [P_TAGWD-1:0] s_tag, r_tag;
  logic               s_update;

  /*
    Connecting the signals between pop and popHaltable interfaces
  */

  generate    
    if (P_POPTYPE_REG == E_FALSE) begin : GEN_pop_not_reg
      assign b_pop.w_pop           = b_popHaltable.w_pop;
      assign b_pop.w_tag           = b_popHaltable.w_tag;
      assign s_pop                 = '0;
      assign r_pop                 = '0;
      assign s_tag                 = '0;
      assign r_tag                 = '0;
      assign s_update              = '0;
    end else begin : GEN_pop_reg
      assign b_pop.w_pop = r_pop;
      assign b_pop.w_tag = r_tag;
      assign s_update = !(r_pop && !b_pop.w_ready);

      assign s_pop = s_update ? b_popHaltable.w_pop : r_pop;
      assign s_tag = s_update ? b_popHaltable.w_tag : r_tag;

      always_ff @ ( posedge b_clk.w_main_clk or negedge b_clk.w_reset_n) begin
        if (!b_clk.w_reset_n) begin
          r_pop <= # `TP '0;
          r_tag <= # `TP '0;
        end else begin
          r_pop <= # `TP s_pop;
          r_tag <= # `TP s_tag; 
        end
      end
    end
  endgenerate

  assign b_popHaltable.w_valid = (!s_empty);
  generate
    if (P_POPTYPE_RDY && !P_POPTYPE_REG) begin : GEN_ready
      assign b_popHaltable.w_ready = b_pop.w_ready;
    end else if (P_POPTYPE_RDY && P_POPTYPE_REG) begin : GEN_regready
      assign b_popHaltable.w_ready = b_pop.w_ready || !r_pop;
    end
    if (P_POPTYPE_PEEK) begin : GEN_peek_feed
      assign b_pop.w_peek = b_popHaltable.w_peek;
    end else begin : GEN_peek_tied
      assign b_pop.w_peek = '0;
    end
  endgenerate
 
  /*
     FIFO module instantiation
  */
  DWC_pcie_ctl_bcm65_td
   #(
     .WIDTH           ( $bits(P_DATATYPE)               )
    ,.DEPTH           ( P_DAMPER_DP                     )
    ,.AE_LEVEL        ( 1                               )
    ,.AF_LEVEL        ( 1                               )
    ,.ERR_MODE        ( 2                               )
    ,.RST_MODE        ( 0                               )
    ,.ADDR_WIDTH      ( LP_ADDR_WD                      )
    ,.REG_DELAY_TIME  ( LP_REG_DELAY_TIME               )
    ,.REG_DELAY_DENOM ( LP_REG_DELAY_DENOM              )
  ) u_damper (
     .clk             ( b_clk.w_main_clk                )
    ,.rst_n           ( b_clk.w_reset_n                 )
    ,.init_n          ( 1'b1                            )
    ,.push_req_n      ( !b_pop.w_valid                  )
    ,.pop_req_n       ( s_empty || b_popHaltable.w_halt )
    ,.data_in         ( b_pop.w_data                    )
    ,.empty           ( s_empty                         )
    ,.data_out        ( b_popHaltable.w_data            )
    ,.diag_n          ( 1'b0                            )
  // SMD: Output port to an instance is not connected
  // SJ:  These ports are not used.
  // spyglass disable_block W287b
    ,.almost_empty    (             /* NC */            )
    ,.half_full       (             /* NC */            )
    ,.almost_full     (             /* NC */            )
    ,.full            (             /* NC */            )
    ,.error           (             /* NC */            )
  // spyglass enable_block W287b
    );

  
// SNPS_SysML_CODE_END

endmodule
