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
// ---    $Revision: #7 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_cpl2mwr_pop.sv#7 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ctxPop_haltable_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_cpl2mwr_pop
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter         type P_CTXTYPE = dmaWrEngCtx_s
  ,parameter         type P_TLPTYPE = xradm_s
  ,parameter          P_C2W_BUFF_DP = 3
  ,parameter               P_DATAWD = 8
  ,parameter dmaEngType_e P_CHANNEL = E_WRITE
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_aclks_if.slave_mp           b_clk
  ,DWC_pcie_edmapf_tlp_if.slave_mp             b_cpl
  ,DWC_pcie_edmapf_ctxPop_haltable_if.slave_mp b_ctxPop
  ,DWC_pcie_edmapf_tlp_if.master_mp            b_tlpCtx
  );


// SNPS_SysML_CODE_START

  localparam integer LP_REG_DELAY_DENOM = 1000;
  localparam integer LP_REG_DELAY_TIME  = `TP * LP_REG_DELAY_DENOM;

  typedef struct packed {
    logic              hv     ;
    logic              dv     ;
    logic              eot    ;
    P_TLPTYPE          header ;
    logic [P_DATAWD:1] data   ;
  } tlpFifo_s;

  logic     s_tlpFifo_push_req_n ;
  logic     s_tlpFifo_pop_req_n  ;
  tlpFifo_s s_tlpFifo_data_in    ;
  tlpFifo_s w_tlpFifo_data_out   ;
  logic     w_tlpFifo_full       ;
  logic     w_tlpFifo_empty      ;

  DWC_pcie_ctl_bcm65_td
    #( //Synchronous (Single Clock) FIFO with Static Flags
     .WIDTH           ( $bits(tlpFifo_s)        )
    ,.DEPTH           ( P_C2W_BUFF_DP           )
    ,.AE_LEVEL        ( 1                       )
    ,.AF_LEVEL        ( 1                       )
    ,.ERR_MODE        ( 2                       )
    ,.RST_MODE        ( 0                       )
    ,.ADDR_WIDTH      ( $clog2(P_C2W_BUFF_DP)   )
    ,.REG_DELAY_TIME  ( LP_REG_DELAY_TIME       )
    ,.REG_DELAY_DENOM ( LP_REG_DELAY_DENOM      )
  )
  u_tlpFifo(
     .clk             ( b_clk.w_main_clk        )
    ,.rst_n           ( b_clk.w_reset_n         )
    ,.init_n          ( 1'b1                    )
    ,.push_req_n      ( s_tlpFifo_push_req_n    )
    ,.pop_req_n       ( s_tlpFifo_pop_req_n     )
    ,.data_in         ( s_tlpFifo_data_in       )
    ,.data_out        ( w_tlpFifo_data_out      )
    ,.full            ( w_tlpFifo_full          )
    ,.empty           ( w_tlpFifo_empty         )
    ,.diag_n          ( 1'b0                    )
    // SMD: Output port to an instance is not connected
    // SJ:  These ports are not used.
    // spyglass disable_block W287b
    ,.almost_empty    ( /* NC */                )
    ,.half_full       ( /* NC */                )
    ,.almost_full     ( /* NC */                )
    ,.error           ( /* NC */                )
    // spyglass enable_block W287b
    );


    assign s_tlpFifo_push_req_n = b_cpl.w_halt || !(b_cpl.w_dv || b_cpl.w_hv);
    assign s_tlpFifo_pop_req_n  = b_tlpCtx.w_halt || !(b_tlpCtx.w_dv || b_tlpCtx.w_hv);
    assign s_tlpFifo_data_in    = tlpFifo_s'{
       hv     : b_cpl.w_hv
      ,dv     : b_cpl.w_dv
      ,eot    : b_cpl.w_eot
      ,header : b_cpl.w_header
      ,data   : b_cpl.w_data
    };

    always_comb begin : tlpCtx_PROC
      b_tlpCtx.w_data           = w_tlpFifo_data_out.data   ;
      b_tlpCtx.w_header.header  = w_tlpFifo_data_out.header ;
      b_tlpCtx.w_header.ctx     = b_ctxPop.w_data           ;
      b_tlpCtx.w_headerProt = '0;
      if (!w_tlpFifo_empty ) begin
        if (w_tlpFifo_data_out.hv) begin
          if (b_ctxPop.w_valid) begin
            b_tlpCtx.w_hv  = w_tlpFifo_data_out.hv  ;
            b_tlpCtx.w_dv  = w_tlpFifo_data_out.dv  ;
            b_tlpCtx.w_eot = w_tlpFifo_data_out.eot ;
          end else begin // hv up, waitting for valid ctx
            b_tlpCtx.w_hv  = '0 ;
            b_tlpCtx.w_dv  = '0 ;
            b_tlpCtx.w_eot = '0 ;
          end
        end else begin // hv down, outputting data
          b_tlpCtx.w_hv  = w_tlpFifo_data_out.hv  ;
          b_tlpCtx.w_dv  = w_tlpFifo_data_out.dv  ;
          b_tlpCtx.w_eot = w_tlpFifo_data_out.eot ;
        end
      end else begin  // fifo empty
        b_tlpCtx.w_hv  = '0 ;
        b_tlpCtx.w_dv  = '0 ;
        b_tlpCtx.w_eot = '0 ;
      end
    end : tlpCtx_PROC

    assign b_cpl.w_halt      = w_tlpFifo_full && s_tlpFifo_pop_req_n;

    assign b_ctxPop.w_tag  = b_cpl.w_header.tag;
    assign b_ctxPop.w_pop  = b_cpl.w_hv && !b_cpl.w_halt ;
    assign b_ctxPop.w_halt = b_tlpCtx.w_halt || !b_tlpCtx.w_hv;

// SNPS_SysML_CODE_END

endmodule
