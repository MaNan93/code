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
// ---    $Author: lnicola $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Amba/mstr_cpl_buf/DWC_pcie_amba_mstr_cpl_ctl_rd_dly.sv#5 $
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Amba/mstr_cpl_buf/DWC_pcie_amba_mstr_cpl_buf_pkg.svh"

// Module description:

module DWC_pcie_amba_mstr_cpl_ctl_rd_dly
  import DWC_pcie_amba_mstr_cpl_buf_pkg::*;
  #(
    parameter type P_CPLQ_TYPE                     = logic
   ,parameter type P_RD_CTL_TYPE                   = logic
   ,parameter type P_MCCTL_TYPE                    = logic
   ,parameter      CC_MSTR_CPL_SEG_DATA_NUM_DWORDS = 1
   ,parameter      MSTR_CPL_CTRL_DELAY             = 1
   ,parameter      TP                              = `TP
  ) (
    input  logic                                        i_clk
   ,input  logic                                        i_rst_n

    // SBC pop interface <-- u_rd / u_sbc (legacy) / u_chunkrd (axi-g)
   ,input  P_RD_CTL_TYPE                                i_rd_ndly_ctl
   ,input  P_CPLQ_TYPE                                  i_rd_ndly_q
   ,input  logic [CC_MSTR_CPL_SEG_DATA_NUM_DWORDS -1:0] i_sb_dwen

    // SBC control latency-delayed --> u_rrlb
   ,output P_MCCTL_TYPE                                 o_mcctl
  );

  localparam L_DLY_WD = $bits(P_CPLQ_TYPE) + $bits(P_RD_CTL_TYPE);

  P_CPLQ_TYPE   r_dly_q;
  P_RD_CTL_TYPE r_dly_ctl;
  logic         s_mcctl_dv;

  // -------------------------------------------------------------------------------------
  // Align header info with RAM pop data.
  // -------------------------------------------------------------------------------------
  // Instantiate completion queue pipe line
  delay_n
   #(
    .WD ( L_DLY_WD            )
   ,.N  ( MSTR_CPL_CTRL_DELAY )
  ) u_dly (
    .clk   ( i_clk                        )
   ,.rst_n ( i_rst_n                      )
   ,.clear ( 1'b0                         )
   ,.din   ( {i_rd_ndly_ctl, i_rd_ndly_q} )
   ,.dout  ( {r_dly_ctl,     r_dly_q    } )
  );


  // Completion control signals delayed by MSTR_CPL_CTRL_DELAY cycles to align with seg buf data.
  // Data valid if split completion successful and valid data pushed to segment buffer.
  // Data valid de-asserted for CPL completions (error response and non-posted writes)

  assign s_mcctl_dv = (r_dly_q.q.status == `SU_CPL_STATUS) && r_dly_ctl.dv && (|i_sb_dwen);

  assign o_mcctl = P_MCCTL_TYPE'{
    // Errored completion hv generated on the last flushed data beat.
    hv          : (r_dly_q.q.status == `SU_CPL_STATUS) ? r_dly_ctl.hv : r_dly_ctl.eot
   ,dv          : s_mcctl_dv
   ,eot         : r_dly_ctl.eot
   ,last        : r_dly_ctl.last
   ,fmt         : s_mcctl_dv ? K_CPLD_FMT  : K_CPL_FMT
   ,stype       : s_mcctl_dv ? K_CPLD_TYPE : K_CPL_TYPE
   ,lookup_id   : r_dly_q.q.seg_num
   ,dw_len_bytes: s_mcctl_dv ? (`DC_MCB_MAX_CPL_NUM_BYTES_WD)'(r_dly_q.q.dw_len << 2) : '0
   ,status      : r_dly_q.q.status
   ,func        : r_dly_ctl.func
   ,ep          : s_mcctl_dv ? r_dly_q.q.ep : '0
   ,tc          : r_dly_q.q.tc
   ,dma_chan    : r_dly_q.dma_chan
   ,dma_type    : r_dly_q.dma_type
  };

`ifndef SYNTHESIS
`endif // SYNTHESIS

`ifndef SYNTHESIS
`endif // SYNTHESIS

endmodule : DWC_pcie_amba_mstr_cpl_ctl_rd_dly
