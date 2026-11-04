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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_stsh_xfpMngr.sv#6 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_wack_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_chanNotify_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ChNtfyEn_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_dbNtfy_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_rvData_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_genericData_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_stsh_xfpMngr
  import DWC_pcie_edmapf_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter type P_PIPE_TYPE = stshPipeRd_s
  ,parameter           P_CHAN = 4
  ,parameter P_MAXINT_OUTSTND = 31
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_aclks_if.slave_mp        b_clk
  ,DWC_pcie_edmapf_ChNtfyEn_if.master_mp    b_doorB2IntMngr
  ,DWC_pcie_edmapf_chanNotify_if.master_mp  b_doorB2mon
  ,DWC_pcie_edmapf_dbNtfy_if.slave_mp       b_doorbell
  ,DWC_pcie_edmapf_rvData_if.slave_mp       b_in
  ,DWC_pcie_edmapf_wack_if.slave_mp         b_msiAck
  ,DWC_pcie_edmapf_wack_if.slave_mp         b_msiRAck
  ,DWC_pcie_edmapf_rvData_if.master_mp      b_out
  ,DWC_pcie_edmapf_genericData_if.master_mp b_xferPending
  );


// SNPS_SysML_CODE_START
  
  localparam L_OUTSTND_CNTR_WD = $clog2(P_MAXINT_OUTSTND);
  localparam integer LP_REG_DELAY_DENOM  = 1000;
  localparam integer LP_REG_DELAY_TIME   = `TP * LP_REG_DELAY_DENOM;

  localparam L_LLACK_LAT = 4;  
  localparam L_LLACK_DAMPER_CNT_WD = $clog2(L_LLACK_LAT) + 2;

  logic       s_llAckFifo_push_req_n ;
  logic       s_llAckFifo_pop_req_n  ;
  P_PIPE_TYPE s_llAckFifo_data_in    ;
  P_PIPE_TYPE s_llAckFifo_data_out   ;
  logic       s_llAckFifo_full       ;
  logic       s_llAckFifo_empty      ;

  logic [L_LLACK_DAMPER_CNT_WD-1:0] r_llAckDamper_cnt;
  logic                             s_llAckDamper_cnt_inc;
  logic                             s_llAckDamper_cnt_dec;

  logic s_llAckFifo_data_out_is_watermark;

  struct packed {
    struct packed {
      logic [P_CHAN-1:0] xferPend;
    } auxc;
    struct packed {
      logic [P_CHAN-1:0][L_OUTSTND_CNTR_WD-1:0] counter;
      logic [P_CHAN-1:0] waiting;
    } mainc;
  } r,s;
  
  /*
  * r, auxc clock register.
  */
  always_ff @(posedge b_clk.w_aux_clk, negedge b_clk.w_reset_n) begin : r_aux_PROC
    if (!b_clk.w_reset_n) begin
      r.auxc <= #`TP '0;
    end else begin
      r.auxc <= #`TP s.auxc;
    end
  end : r_aux_PROC

  /*
  * r, mainc clock register.
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : r_main_PROC
    if (!b_clk.w_reset_n) begin
      r.mainc <= #`TP '0;
    end else begin
      r.mainc <= #`TP s.mainc;
    end
  end : r_main_PROC

  always_comb begin : waiting_PROC
    int i;
    for (i = 0; i < (P_CHAN-1-0+1); i += 1) begin 
      if (b_doorbell.w_valid && (b_doorbell.w_channel == i)) begin
        s.mainc.waiting[i] = '0;
      end else if (b_out.w_ready && b_out.w_valid && b_out.w_data.channel == i && ( b_out.w_data.interrupts.pins.abort || b_out.w_data.interrupts.pins.stop )) begin
        s.mainc.waiting[i] = '1;
      end else if (r.mainc.counter == '0) begin
        s.mainc.waiting[i] = '0;
      end else begin
        s.mainc.waiting[i] = r.mainc.waiting[i];
      end
    end
  end

  always_comb begin : counter_PROC
    int i;
    for (i = 0; i < (P_CHAN-1-0+1); i += 1) begin 
      s.mainc.counter[i] = r.mainc.counter[i];
      if (b_out.w_ready && b_out.w_valid && b_out.w_data.channel == i) begin
        s.mainc.counter[i] = s.mainc.counter[i] + 1'b1;
      end
      if (b_msiRAck.w_valid && (b_msiRAck.w_channel == i)) begin
        s.mainc.counter[i] = s.mainc.counter[i] - 1'd1;
      end
      if (b_msiAck.w_valid  && (b_msiAck.w_channel  == i)) begin
        s.mainc.counter[i] = s.mainc.counter[i] - 1'b1;
      end
    end
  end

  always_comb begin : xferPend_PROC
    int i;
    for (i = 0; i < (P_CHAN-1-0+1); i += 1) begin 
      if (b_doorbell.w_valid && (b_doorbell.w_channel == i)) begin
        s.auxc.xferPend[i] = 'b1;
      end else if ((r.mainc.counter[i] == '0) && r.mainc.waiting[i]) begin
        s.auxc.xferPend[i] = 'b0;
      end else begin
        s.auxc.xferPend[i] = r.auxc.xferPend[i];
      end
    end
  end

  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : llAckDamper_cnt_PROC
    if (!b_clk.w_reset_n) begin
      r_llAckDamper_cnt <= #`TP '0;
    end else begin
      case ({s_llAckDamper_cnt_inc,s_llAckDamper_cnt_dec})
        2'b01   : r_llAckDamper_cnt <= #`TP r_llAckDamper_cnt - 1'b1 ;
        2'b10   : r_llAckDamper_cnt <= #`TP r_llAckDamper_cnt + 1'b1 ;
        default : r_llAckDamper_cnt <= #`TP r_llAckDamper_cnt        ;
      endcase
    end
  end

  `ifndef SYNTHESIS
  `endif //!SYNTHESIS

  DWC_pcie_ctl_bcm65_td
    #( //Synchronous (Single Clock) FIFO with Static Flags
     .WIDTH           ( $bits(P_PIPE_TYPE)     )
    ,.DEPTH           ( L_LLACK_LAT            )
    ,.AE_LEVEL        ( 1                      )
    ,.AF_LEVEL        ( 1                      )
    ,.ERR_MODE        ( 2                      )
    ,.RST_MODE        ( 0                      )
    ,.ADDR_WIDTH      ( $clog2(L_LLACK_LAT)    )
    ,.REG_DELAY_TIME  ( LP_REG_DELAY_TIME      )
    ,.REG_DELAY_DENOM ( LP_REG_DELAY_DENOM     )
  ) u_llAckFifo(
     .clk             ( b_clk.w_main_clk       )
    ,.rst_n           ( b_clk.w_reset_n        )
    ,.init_n          ( 1'b1                   )
    ,.push_req_n      ( s_llAckFifo_push_req_n )
    ,.pop_req_n       ( s_llAckFifo_pop_req_n  )
    ,.data_in         ( s_llAckFifo_data_in    )
    ,.full            ( s_llAckFifo_full       )
    ,.data_out        ( s_llAckFifo_data_out   )
    ,.empty           ( s_llAckFifo_empty      )
    ,.diag_n          ( 1'b0                   )
    // SMD: Output port to an instance is not connected
    // SJ:  These ports are not used.
    // spyglass disable_block W287b
    ,.almost_empty    ( /* NC */               )
    ,.half_full       ( /* NC */               )
    ,.almost_full     ( /* NC */               )
    ,.error           ( /* NC */               )
    // spyglass enable_block W287b
    );


  assign s_llAckDamper_cnt_inc             = |b_doorbell.w_chstWaterMark;
  assign s_llAckDamper_cnt_dec             = !s_llAckFifo_pop_req_n && s_llAckFifo_data_out_is_watermark;

  assign s_llAckFifo_push_req_n            = !(b_in.w_valid && b_in.w_ready);
  assign s_llAckFifo_data_in               = b_in.w_data;
  assign s_llAckFifo_pop_req_n             = !(b_out.w_valid && b_out.w_ready);
  assign s_llAckFifo_data_out_is_watermark = s_llAckFifo_data_out.interrupts.chStatus == E_CS_RUNNING && s_llAckFifo_data_out.interrupts.pins.watermark && |s_llAckFifo_data_out.watermarkEn ;

  assign b_xferPending.w_data              = r.auxc.xferPend;
  assign b_out.w_data                      = s_llAckFifo_data_out;
  assign b_in.w_ready                      = !s_llAckFifo_full;
  assign b_msiAck.w_halt                   = '0;
  assign b_msiRAck.w_halt                  = '0;
  assign b_out.w_valid                     = !s_llAckFifo_empty && (!s_llAckFifo_data_out_is_watermark || |r_llAckDamper_cnt);


  //Converts between doorbell notifies interfaces
  always_comb begin : xferPend2db_PROC
    foreach (r.auxc.xferPend[i]) begin
      b_doorbell.w_xferPend[i] = r.auxc.xferPend[i];
      b_doorbell.w_chEn[i]     = b_doorB2IntMngr.w_chEn[i];
      b_doorbell.w_chstRun[i]  = b_doorB2IntMngr.w_chstRun[i];
    end
  end
  assign b_doorB2IntMngr.w_channel = b_doorbell.w_channel;
  assign b_doorB2IntMngr.w_valid   = b_doorbell.w_valid;
  assign b_doorB2mon.w_channel     = b_doorbell.w_channel;
  assign b_doorB2mon.w_valid       = b_doorbell.w_valid;

// SNPS_SysML_CODE_END

endmodule
