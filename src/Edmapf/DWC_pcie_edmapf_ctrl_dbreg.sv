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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_dbreg.sv#8 $
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ram1p_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ChRegfile_DB_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_genericData_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_llFetchNtfy_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_dbreg

  import DWC_pcie_edmapf_pkg::*;
  #(
    // ##########################################################################
    //                             Parameters Declaration
    // ##########################################################################
    parameter dmaEngType_e P_CHANNEL           = E_WRITE
    ,parameter CC_NUM_DMA_CHAN_WIDTH       = 4
    ,parameter CX_NUM_DMA_CHAN             = 16
    ,parameter type P_DBMNGR_ELPFETCH_TYPE = DbMngrWrElPfetch_t
    )(

      DWC_pcie_edmapf_aclks_if.slave_mp          b_clk

      ,DWC_pcie_edmapf_ram1p_if.slave_mp         b_crgbdata

      ,DWC_pcie_edmapf_ChRegfile_DB_if.master_mp b_ChStartStop

      ,DWC_pcie_edmapf_genericData_if.master_mp  b_ChElPfetch 

      ,DWC_pcie_edmapf_llFetchNtfy_if.slave_mp   b_llFetchNtfy
     );


  /*
   * This module implements the following registers
   * E_DOORBELL - two bits
   *
   * It has one entry for each channel in the following format
   * {E_DOORBELL.db_stop, E_DOORBELL.db_start}
   * 
   * E_ELEM_PF - 7 bits
   */

  typedef struct packed{
    logic        db_stop;
    logic        db_start;
  } s_dbregfile;

  typedef logic [CX_NUM_DMA_CHAN-1:0] [6:0] DbMngrElPfetch_t; 

  s_dbregfile r_dbreg[0:CX_NUM_DMA_CHAN-1];
  s_dbregfile s_dbreg[0:CX_NUM_DMA_CHAN-1];

  DbMngrElPfetch_t r_ChElPfetch;
  DbMngrElPfetch_t s_ChElPfetch;

  localparam LP_DMA_LLQ       = (P_CHANNEL == E_WRITE) ? K_DMA_WR_LLQ   : K_DMA_RD_LLQ  ;
  localparam LP_DMA_NUM_CH    = (P_CHANNEL == E_WRITE) ? `CC_NUM_DMA_WR_CHAN : `CC_NUM_DMA_RD_CHAN;
  localparam LP_MAX_PFETCH    = LP_DMA_NUM_CH * LP_DMA_LLQ;
  localparam LP_MAX_PFETCH_WD = (LP_MAX_PFETCH == 1) ? 1 : $clog2(LP_MAX_PFETCH);

  logic [LP_MAX_PFETCH_WD-1:0] ChElPfetch;

  always_ff @ (posedge b_clk.w_aux_clk or negedge b_clk.w_reset_n) begin : PROC_ff_dbregfile
    if (!b_clk.w_reset_n) begin
      b_crgbdata.w_wdone <= # `TP '0;
      for (int i = 0;i<CX_NUM_DMA_CHAN;i++) begin
        r_dbreg[i] <= # `TP '0;
      end
    end else begin
      if (b_crgbdata.w_wren) begin
        b_crgbdata.w_wdone <= # `TP '1;
      end else begin
        b_crgbdata.w_wdone <= # `TP '0;
      end
      for (int i = 0;i<CX_NUM_DMA_CHAN;i++) begin
        r_dbreg[i] <= # `TP s_dbreg[i];
      end
    end
  end

  always_comb begin : PROC_cb_dbregfile
    foreach(r_dbreg[i]) begin
      if ((i == b_crgbdata.w_addr[CC_NUM_DMA_CHAN_WIDTH-1:0]) && b_crgbdata.w_wren) begin
        s_dbreg[i] = s_dbregfile'(b_crgbdata.w_din[1:0]);
      end else begin
        s_dbreg[i] = '0;
      end
    end
  end

  always_ff @ (posedge b_clk.w_aux_clk or negedge b_clk.w_reset_n) begin : PROC_ff_rdone
    if (!b_clk.w_reset_n) begin
      b_crgbdata.w_rdone <= # `TP '0;
    end else begin
      b_crgbdata.w_rdone <= # `TP b_crgbdata.w_rden;
    end
  end

  always_comb begin : PROC_cb_ChStartStop
    logic [CX_NUM_DMA_CHAN-1:0] s_db_start, r_db_start;
    logic [CX_NUM_DMA_CHAN-1:0] s_db_stop,  r_db_stop;
    foreach(r_dbreg[i]) begin
      r_db_start[i] = r_dbreg[i].db_start;
      r_db_stop[i]  = r_dbreg[i].db_stop;
    end
    foreach(s_dbreg[j]) begin
      s_db_start[j] = s_dbreg[j].db_start;
      s_db_stop[j]  = s_dbreg[j].db_stop;
    end
    if (|(s_db_start & ~r_db_start)) begin
      b_ChStartStop.w_start = 1'b1;
    end else begin
      b_ChStartStop.w_start = 1'b0;
    end
    if (|(s_db_stop & ~r_db_stop)) begin
      b_ChStartStop.w_stop = 1'b1;
    end else begin
      b_ChStartStop.w_stop = 1'b0;
    end
    b_ChStartStop.w_channel_num = b_crgbdata.w_addr[CC_NUM_DMA_CHAN_WIDTH-1:0];
    b_ChStartStop.w_halt_llerr = E_DMAERR_NONE;
  end

  generate
    if (LP_MAX_PFETCH_WD >= 7) begin : GEN_wide_fetch
      always_comb begin : PROC_ChElPfetch_wide
        for (int i =0; i < CX_NUM_DMA_CHAN; i++) begin
          ChElPfetch = '0;
          ChElPfetch = LP_MAX_PFETCH_WD'(r_ChElPfetch[i]);          
          b_ChElPfetch.w_data[i] = '0;
          if (ChElPfetch < LP_MAX_PFETCH)
            b_ChElPfetch.w_data[i][6:0] = r_ChElPfetch[i][6:0];
          else //avoids overflowing LL processor when element prefetch is badly configured
            b_ChElPfetch.w_data[i][6:0] =  7'(LP_MAX_PFETCH - 1); 
        end
      end
    end else begin : GEN_narrow_fetch
       always_comb begin : PROC_ChElPfetch_narrow
        for (int i =0; i < CX_NUM_DMA_CHAN; i++) begin
          ChElPfetch = '0;
          ChElPfetch = LP_MAX_PFETCH_WD'(r_ChElPfetch[i]);          
          b_ChElPfetch.w_data[i] = '0;
          if (ChElPfetch < LP_MAX_PFETCH) begin
            b_ChElPfetch.w_data[i][LP_MAX_PFETCH_WD-1:0] = r_ChElPfetch[i][LP_MAX_PFETCH_WD-1:0];
          end else begin
            //avoids overflowing LL processor when element prefetch is badly configured
            b_ChElPfetch.w_data[i][LP_MAX_PFETCH_WD-1:0] = LP_MAX_PFETCH_WD'(LP_MAX_PFETCH - 1);
          end
        end
      end 
    end
  endgenerate 

  always_ff @ (posedge b_clk.w_aux_clk or negedge b_clk.w_reset_n) begin : PROC_ff_ChElPfetch
    if (!b_clk.w_reset_n) begin
      r_ChElPfetch <= # `TP '0;
    end else begin
      r_ChElPfetch <= # `TP s_ChElPfetch;
    end
  end

  always_comb begin : PROC_cb_ChElPfetch
    logic i_elPfetchReady;
    i_elPfetchReady = '0;
    s_ChElPfetch = r_ChElPfetch;
    foreach (s_ChElPfetch[i]) begin
      if ((i == b_crgbdata.w_addr[CC_NUM_DMA_CHAN_WIDTH-1:0]) && b_crgbdata.w_wren) begin
        s_ChElPfetch[i] = b_crgbdata.w_din[8:2];
      end else if (b_llFetchNtfy.w_elPfetchValid && (i == b_llFetchNtfy.w_elPfetchCh) && !(b_crgbdata.w_lock && (i == b_crgbdata.w_addr[CC_NUM_DMA_CHAN_WIDTH-1:0]))) begin
        s_ChElPfetch[i] = b_llFetchNtfy.w_elPfetch;
        i_elPfetchReady = '1;
      end else begin
        s_ChElPfetch[i] = r_ChElPfetch[i];
      end
    end
    b_llFetchNtfy.w_elPfetchReady = i_elPfetchReady;
  end

  assign b_llFetchNtfy.w_db_llerr = '0;
  assign b_llFetchNtfy.w_db_apperr = '0;
  assign b_llFetchNtfy.w_db_chstRun = '0;
  assign b_llFetchNtfy.w_chFilter = '0;
 
  always_comb begin : PROC_cb_wdout
    b_crgbdata.w_dout = '0;
    foreach(r_dbreg[i]) begin
      if (i == b_crgbdata.w_addr[CC_NUM_DMA_CHAN_WIDTH-1:0]) begin
        b_crgbdata.w_dout[8:0] = {r_ChElPfetch[i], r_dbreg[i]};
      end
    end
  end
 

endmodule : DWC_pcie_edmapf_ctrl_dbreg
