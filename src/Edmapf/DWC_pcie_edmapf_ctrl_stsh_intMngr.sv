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
// ---    $Revision: #12 $ 
// ---    $Author: dnolan $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_stsh_intMngr.sv#12 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_wack_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ChNtfyEn_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ram1p_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_rvData_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_genericData_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_stsh_intMngr
  import DWC_pcie_edmapf_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter  type P_INT_TYPE = logic
  ,parameter type P_PIPE_TYPE = logic
  ,parameter           P_CHAN = 16
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_genericData_if.slave_mp  b_channelRunning
  ,DWC_pcie_edmapf_aclks_if.slave_mp        b_clk
  ,DWC_pcie_edmapf_ram1p_if.slave_mp        b_crgb
  ,DWC_pcie_edmapf_ChNtfyEn_if.slave_mp     b_doorbell
  ,DWC_pcie_edmapf_genericData_if.master_mp b_en
  ,DWC_pcie_edmapf_genericData_if.slave_mp  b_hwStop
  ,DWC_pcie_edmapf_rvData_if.slave_mp       b_in
  ,DWC_pcie_edmapf_genericData_if.master_mp b_int
  ,DWC_pcie_edmapf_wack_if.master_mp        b_noMsiAck
  ,DWC_pcie_edmapf_rvData_if.master_mp      b_out
  );


// SNPS_SysML_CODE_START
  localparam L_CHANWD = (P_CHAN == 1) ? 1 : $clog2(P_CHAN);

  P_INT_TYPE s_crgbWriteData;

  logic s_interrupt_pins_stop;
  logic s_interrupt_pins_abort;
  
  // SMD: Not all bits of a bus are set.
  // SJ:  All bits are properly set.
  // spyglass disable_block W497
  struct packed {
    struct packed {
      P_INT_TYPE [P_CHAN-1:0] intReg;
      struct packed {
        logic [31:0] rout ;
        logic        rdone;
        logic        wdone;
      } crgb;
    } auxc;
    struct packed {
      struct packed {
        P_PIPE_TYPE data;
        logic valid;
      } outPipe;
      struct packed {
        logic valid;
        logic [L_CHANWD-1:0] channel;
      } noMsi;
    } mainc;
  } r,s;
  // spyglass enable_block W497

  struct packed {
    P_INT_TYPE [P_CHAN-1:0] intReg;
  } s_regReport;
  /*
  * r, auxc clock register.
  */
  always_ff @(posedge b_clk.w_aux_clk, negedge b_clk.w_reset_n) begin : r_aux_PROC
    if (!b_clk.w_reset_n) begin
      int j;
      r.auxc.crgb <= #`TP '0;
      for (j = 0; j < P_CHAN; j += 1) begin 
        r.auxc.intReg[j] <= #`TP '{default: '0, masks:'1, chStatus: E_CS_STOPED, errors: E_DMAERR_NONE};
      end
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

  /*
  * Replace the abort interrupt stop interrupt when hard stop is activated 
  */
  assign s_interrupt_pins_stop  = b_in.w_data.interrupts.pins.stop  | (b_hwStop.w_data[b_in.w_data.channel] && !b_in.w_data.interrupts.pins.watermark); 
  assign s_interrupt_pins_abort = b_in.w_data.interrupts.pins.abort & !b_hwStop.w_data[b_in.w_data.channel];

  always_comb begin : noMsi_PROC
    if (b_in.w_ready && b_in.w_valid) begin
      s.mainc.noMsi.valid = 
                            !(r.auxc.intReg[b_in.w_data.channel].stopEn.rie  && s_interrupt_pins_stop                ) &&
                            !(r.auxc.intReg[b_in.w_data.channel].abortEn.rie && s_interrupt_pins_abort               ) &&
                            !(b_in.w_data.watermarkEn.rie                    && b_in.w_data.interrupts.pins.watermark);
      s.mainc.noMsi.channel = b_in.w_data.channel;
    end else begin
      s.mainc.noMsi = '0;
    end
  end

  assign b_noMsiAck.w_valid   = r.mainc.noMsi.valid;
  assign b_noMsiAck.w_channel = r.mainc.noMsi.channel;
  assign b_noMsiAck.w_error   = '0;
  assign b_noMsiAck.w_tag     = '0;
  `ifndef SYNTHESIS
  `endif

  always_comb begin : pins_PROC
    int i;
    for (i = 0; i < (P_CHAN-1-0+1); i += 1) begin 
      b_int.w_data[i] = r.auxc.intReg[i].pins & ~r.auxc.intReg[i].masks;
    end
  end

  always_comb begin : chEnable_PROC
    int i;
    for (i = 0; i < (P_CHAN-1-0+1); i += 1) begin 
      b_en.w_data[i] = r.auxc.intReg[i].chEnable;
    end
  end

  always_comb begin : intReg_PROC
    int i;
    for (i = 0; i < (P_CHAN-1-0+1); i += 1) begin 
      P_INT_TYPE intRegCh;
      if ((b_in.w_data.channel == i) && b_in.w_valid && b_in.w_ready) begin
        intRegCh.pins.stop      = (r.auxc.intReg[i].pins.stop      && !r.auxc.intReg[i].clears.stop      ) || (s_interrupt_pins_stop                 && r.auxc.intReg[i].stopEn.lie);
        intRegCh.pins.abort     = (r.auxc.intReg[i].pins.abort     && !r.auxc.intReg[i].clears.abort     ) || (s_interrupt_pins_abort                && r.auxc.intReg[i].abortEn.lie);
        intRegCh.pins.watermark = (r.auxc.intReg[i].pins.watermark && !r.auxc.intReg[i].clears.watermark ) || (b_in.w_data.interrupts.pins.watermark && b_in.w_data.watermarkEn.lie);
        intRegCh.errors         = b_hwStop.w_data[i] ? E_DMAERR_NONE : b_in.w_data.interrupts.errors;
      end else begin
        intRegCh.pins = r.auxc.intReg[i].pins & ~r.auxc.intReg[i].clears;
        intRegCh.errors = r.auxc.intReg[i].clears.abort ? E_DMAERR_NONE : r.auxc.intReg[i].errors;
      end
      if ((b_doorbell.w_channel == i) && b_doorbell.w_valid) begin
        intRegCh.chStatus = E_CS_RUNNING;
      end else if ((b_in.w_data.channel == i) && b_in.w_valid && b_in.w_ready) begin
        intRegCh.chStatus = (b_hwStop.w_data[i] && b_in.w_data.interrupts.chStatus == E_CS_ABORTED) ? E_CS_STOPED : b_in.w_data.interrupts.chStatus;
      end else begin
        intRegCh.chStatus = r.auxc.intReg[i].chStatus;
      end
      if (b_crgb.w_addr == i && b_crgb.w_wren) begin
        intRegCh.abortEn  = s_crgbWriteData.abortEn   ;
        intRegCh.stopEn   = s_crgbWriteData.stopEn    ;
        intRegCh.masks    = s_crgbWriteData.masks     ;
        intRegCh.clears   = s_crgbWriteData.clears    ;
        intRegCh.chEnable = s_crgbWriteData.chEnable  ;
      end else begin
        intRegCh.abortEn  = r.auxc.intReg[i].abortEn  ;
        intRegCh.stopEn   = r.auxc.intReg[i].stopEn   ;
        intRegCh.masks    = r.auxc.intReg[i].masks    ;
        intRegCh.clears   = '0                        ;
        intRegCh.chEnable = r.auxc.intReg[i].chEnable ;
      end
      s.auxc.intReg[i] = intRegCh;
      b_doorbell.w_chEn[i] = r.auxc.intReg[i].chEnable ;
      b_doorbell.w_chstRun[i] = (r.auxc.intReg[i].chStatus == E_CS_RUNNING);
    end
  end
  `ifndef SYNTHESIS
  `endif

  /*
    Keep status running until the xferPending falls
  */
  always_comb begin : c_s_regReport_PROC
    logic [P_CHAN-1:0] channelRunning;
    channelRunning = b_channelRunning.w_data;

    s_regReport.intReg        = r.auxc.intReg;
    foreach (s_regReport.intReg[i]) begin
      s_regReport.intReg[i].chStatus        = (s_regReport.intReg[i].chStatus inside {E_CS_STOPED, E_CS_ABORTED} && channelRunning[i]) ? E_CS_RUNNING : r.auxc.intReg[i].chStatus;
    end
  end : c_s_regReport_PROC
  // SMD: A signal or variable is set but never read.
  // SJ:  This assign makes acessing the fields easier, however some of the signals are read-only through the crgb interface, therefor they are not used.
  // spyglass disable_block W528
  assign s_crgbWriteData = b_crgb.w_din[$bits(P_INT_TYPE)-1:0];
  // spyglass enable_block W528

  always_comb begin : crgb_read_PROC
    if (b_crgb.w_rden) begin
      s.auxc.crgb.rout  = {{32-$bits(P_INT_TYPE){1'b0}},s_regReport.intReg[b_crgb.w_addr]};
      s.auxc.crgb.rdone = '1;
    end else begin
      s.auxc.crgb.rout  = r.auxc.crgb.rout;
      s.auxc.crgb.rdone = '0;
    end
  end

  always_comb begin : crgb_write_PROC
    if (b_crgb.w_wren) begin
      s.auxc.crgb.wdone = '1;
    end else begin
      s.auxc.crgb.wdone = '0;
    end
  end

  always_comb begin : out_PROC
    s.mainc.outPipe.data = b_in.w_data;
    if (b_in.w_ready) begin
      s.mainc.outPipe.valid                          = b_in.w_valid && !s.mainc.noMsi.valid;
      s.mainc.outPipe.data.interrupts.chEnable       = '0;
      s.mainc.outPipe.data.interrupts.chStatus       = E_CS_RESERVED;
      s.mainc.outPipe.data.interrupts.clears         = '0;
      s.mainc.outPipe.data.interrupts.masks          = '0;
      s.mainc.outPipe.data.interrupts.pins.stop      = s_interrupt_pins_stop                 && r.auxc.intReg[b_in.w_data.channel].stopEn.rie;
      s.mainc.outPipe.data.interrupts.pins.abort     = s_interrupt_pins_abort                && r.auxc.intReg[b_in.w_data.channel].abortEn.rie;
      s.mainc.outPipe.data.interrupts.pins.watermark = b_in.w_data.interrupts.pins.watermark && b_in.w_data.watermarkEn.rie;
    end else begin
      s.mainc.outPipe = r.mainc.outPipe;
    end
  end

  assign b_crgb.w_dout  = r.auxc.crgb.rout ;
  assign b_crgb.w_rdone = r.auxc.crgb.rdone;
  assign b_crgb.w_wdone = r.auxc.crgb.wdone;

  assign b_out.w_valid = r.mainc.outPipe.valid;
  assign b_out.w_data  = r.mainc.outPipe.data ;
  assign b_in.w_ready  = !r.mainc.outPipe.valid || b_out.w_ready ;
// SNPS_SysML_CODE_END

endmodule
