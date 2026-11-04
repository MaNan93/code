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
// ---    $Revision: #2 $ 
// ---    $Author: lnicola $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_hardStopMngr.sv#2 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_hard_stop_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_genericData_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_hardStopMngr
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter   P_CHAN = 16
  ,parameter P_CHANWD = 4
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_genericData_if.slave_mp  b_channelRunning
  ,DWC_pcie_edmapf_aclks_if.slave_mp        b_clk
  ,DWC_pcie_edmapf_tlp_if.slave_mp          b_data_cpl_in
  ,DWC_pcie_edmapf_tlp_if.master_mp         b_data_cpl_out
  ,DWC_pcie_edmapf_genericData_if.master_mp b_hwStop_active
  ,DWC_pcie_edmapf_genericData_if.master_mp b_hwStop_injected
  ,DWC_pcie_edmapf_hard_stop_if.slave_mp    b_hwStop_req
  ,DWC_pcie_edmapf_tlp_if.slave_mp          b_ll_cpl_in
  ,DWC_pcie_edmapf_tlp_if.master_mp         b_ll_cpl_out
  ,DWC_pcie_edmapf_genericData_if.slave_mp  b_swStopPulse
  );


// SNPS_SysML_CODE_START
  localparam L_HEADERPROTWD = (($bits(xradm_s)-1)/K_RAS_PROT_RANGE+1);

  typedef struct packed {
    logic [P_CHAN-1:0] disabled;
    logic [P_CHAN-1:0] active;
    logic [P_CHAN-1:0] ll_cpl_err_inj;
    logic [P_CHAN-1:0] data_cpl_err_inj;
  } hw_stop_state_s;

  /*
    Signals declaration
  */
  logic                      r_hard_stop_ack;
  logic [P_CHAN-1:0]         s_hard_stop_req;
  logic [P_CHAN-1:0]         s_cpl_err;
  hw_stop_state_s            s_hard_stop_state;
  hw_stop_state_s            r_hard_stop_state;
  xradm_s                    s_ll_cpl_header;
  xradm_s                    s_data_cpl_header;
  xradm_s                    s_ll_cpl_headerOut;
  xradm_s                    s_data_cpl_headerOut;
  logic [L_HEADERPROTWD-1:0] s_ll_cpl_headerProt;
  logic [L_HEADERPROTWD-1:0] s_data_cpl_headerProt;
  logic                      s_ll_cpl_ras_gen_en;
  logic                      s_data_cpl_ras_gen_en;  

  bus_protect_gen
   #(
   .PROT_TYPE              (1                  )
  ,.PROT_RANGE             (K_RAS_PROT_RANGE   )
  ,.PROT_WD                (L_HEADERPROTWD     )
  ,.DATA_WD                ($bits(xradm_s)     )  
  ,.PARITY_MODE            (K_RAS_PARITY_MODE  )
  ,.FORCE_ERR_INJ_OFF      (1                  )
  ) u_ll_cpl_ras_gen(
     .gen                  (s_ll_cpl_ras_gen_en)
    ,.datain               (s_ll_cpl_header    )
    ,.core_clk             (b_clk.w_main_clk   )
    ,.core_rst_n           (b_clk.w_reset_n    )
    ,.error_inj_mask       ('0                 )
    ,.error_inj_en         ('0                 )
    ,.error_inj_data_valid ('0                 )
    ,.error_inj_eot        ('0                 )
    ,.error_inj_done       ( /* NC */          )
    ,.chkout               (s_ll_cpl_headerProt)
    ,.dataout              (s_ll_cpl_headerOut )
  );

  bus_protect_gen
   #(
   .PROT_TYPE              (1                    )
  ,.PROT_RANGE             (K_RAS_PROT_RANGE     )
  ,.PROT_WD                (L_HEADERPROTWD       )
  ,.DATA_WD                ($bits(xradm_s)       )  
  ,.PARITY_MODE            (K_RAS_PARITY_MODE    )
  ,.FORCE_ERR_INJ_OFF      (1                    )
  ) u_data_cpl_ras_gen(
     .gen                  (s_data_cpl_ras_gen_en)
    ,.datain               (s_data_cpl_header    )
    ,.core_clk             (b_clk.w_main_clk     )
    ,.core_rst_n           (b_clk.w_reset_n      )
    ,.error_inj_mask       ('0                   )
    ,.error_inj_en         ('0                   )
    ,.error_inj_data_valid ('0                   )
    ,.error_inj_eot        ('0                   )
    ,.error_inj_done       ( /* NC */            )
    ,.chkout               (s_data_cpl_headerProt)
    ,.dataout              (s_data_cpl_headerOut )
  );

  assign s_ll_cpl_ras_gen_en   = (s_ll_cpl_header.common2.cpl_status   == E_CPL_STATUS_CA);
  assign s_data_cpl_ras_gen_en = (s_data_cpl_header.common2.cpl_status == E_CPL_STATUS_CA);


  /*
    Generating the ack pulse after receiving a req
  */
  always_ff @(posedge b_clk.w_aux_clk, negedge b_clk.w_reset_n) begin : s_hwStopAck_PROC
    if (!b_clk.w_reset_n) begin
      r_hard_stop_ack <= #`TP '0;
    end else if (b_hwStop_req.w_req && !r_hard_stop_ack) begin
      r_hard_stop_ack <= #`TP '1;
    end else begin
      r_hard_stop_ack <= #`TP '0;  
    end
  end : s_hwStopAck_PROC

  /*
  Hard_stop channel state register
  */
  always_ff @(posedge b_clk.w_aux_clk, negedge b_clk.w_reset_n) begin : s_hwStopState_PROC
    if (!b_clk.w_reset_n) begin
      r_hard_stop_state <= #`TP '0;
    end else begin
      r_hard_stop_state <= #`TP s_hard_stop_state; 
    end    
  end : s_hwStopState_PROC

  /*
    Hard stop request per channel
  */
  always_comb begin : c_hwReq_PROC
    for (int i = 0; i < P_CHAN; i += 1) begin
      s_hard_stop_req[i] = (b_hwStop_req.w_req && b_hwStop_req.w_ack && b_hwStop_req.w_channel == i);           
    end
  end : c_hwReq_PROC  

  /*
    Completion error 
  */
  always_comb begin : c_CplErr_PROC
    logic [P_CHAN-1:0] ll_cpl_err;
    logic [P_CHAN-1:0] data_cpl_err;  
    for (int i = 0; i < P_CHAN; i += 1) begin
      ll_cpl_err[i]   = (b_ll_cpl_in.w_hv   && !b_ll_cpl_in.w_halt   && b_ll_cpl_in.w_header.dma.channel   == i && b_ll_cpl_in.w_header.common2.cpl_status   != E_CPL_STATUS_SC); 
      data_cpl_err[i] = (b_data_cpl_in.w_hv && !b_data_cpl_in.w_halt && b_data_cpl_in.w_header.dma.channel == i && b_data_cpl_in.w_header.common2.cpl_status != E_CPL_STATUS_SC);          
    end
    s_cpl_err = ll_cpl_err | data_cpl_err;
  end : c_CplErr_PROC

  /*
    Hard stop is disbaled when Software stop or Completion error was previously received  
  */
  always_comb begin : c_hwStopDisable_PROC  
    s_hard_stop_state.disabled = r_hard_stop_state.disabled;    
    for (int i = 0; i < P_CHAN; i += 1) begin
      if (b_channelRunning.w_data[i] == 1'b0) begin
        s_hard_stop_state.disabled[i] = 1'b0;
      end else if ((b_swStopPulse.w_data[i] || s_cpl_err[i]) && !r_hard_stop_state.active[i]) begin
        s_hard_stop_state.disabled[i] = 1'b1;  
      end 
    end
  end : c_hwStopDisable_PROC

  /*
  Hard stop state active  
  */
  always_comb begin : c_hwStopActive_PROC    
    s_hard_stop_state.active = r_hard_stop_state.active;
    for (int i = 0; i < P_CHAN; i += 1) begin
      if (b_channelRunning.w_data[i] == 1'b0) begin
        s_hard_stop_state.active[i] = 1'b0;
      end else if (s_hard_stop_req[i] && !s_hard_stop_state.disabled[i]) begin
        s_hard_stop_state.active[i] = 1'b1;  
      end
    end  
  end : c_hwStopActive_PROC

  /*
  Injecting Completion Abort Error on the first receiving LL/Data Completion 
  */
  always_comb begin : c_CplErrorInj_PROC
    s_hard_stop_state.ll_cpl_err_inj   = r_hard_stop_state.ll_cpl_err_inj;
    s_hard_stop_state.data_cpl_err_inj = r_hard_stop_state.data_cpl_err_inj;
    s_ll_cpl_header                    = b_ll_cpl_in.w_header;
    s_data_cpl_header                  = b_data_cpl_in.w_header;
    for (int i = 0; i < P_CHAN; i += 1) begin
      if (b_channelRunning.w_data[i] == 1'b0) begin
        s_hard_stop_state.ll_cpl_err_inj[i]   = 1'b0;
        s_hard_stop_state.data_cpl_err_inj[i] = 1'b0;
      end else if (r_hard_stop_state.active[i]) begin
        if (b_ll_cpl_in.w_hv && !b_ll_cpl_in.w_halt && b_ll_cpl_in.w_header.dma.channel == i && !r_hard_stop_state.ll_cpl_err_inj[i]) begin
          s_hard_stop_state.ll_cpl_err_inj[i] = 1'b1;  
          s_ll_cpl_header.common2.cpl_status  = E_CPL_STATUS_CA; 
        end else if (b_data_cpl_in.w_hv && !b_data_cpl_in.w_halt && b_data_cpl_in.w_header.dma.channel == i && !r_hard_stop_state.data_cpl_err_inj[i]) begin
          s_hard_stop_state.data_cpl_err_inj[i] = 1'b1;  
          s_data_cpl_header.common2.cpl_status  = E_CPL_STATUS_CA;
        end  
      end 
    end
  end : c_CplErrorInj_PROC

  /*
    Driving the LL Completion
  */
  always_comb begin : c_driving_llCpl_PROC
    b_ll_cpl_out.w_data   = b_ll_cpl_in.w_data;
    b_ll_cpl_out.w_hv     = b_ll_cpl_in.w_hv;
    b_ll_cpl_out.w_dv     = b_ll_cpl_in.w_dv;
    b_ll_cpl_out.w_eot    = b_ll_cpl_in.w_eot;    
    b_ll_cpl_out.w_header     = s_ll_cpl_headerOut;
    b_ll_cpl_out.w_headerProt = s_ll_cpl_ras_gen_en ? s_ll_cpl_headerProt : b_ll_cpl_in.w_headerProt;
    b_ll_cpl_in.w_halt    = b_ll_cpl_out.w_halt;
  end : c_driving_llCpl_PROC

  /*
    Driving the Data Completion 
  */
  always_comb begin : c_driving_dataCpl_PROC
    b_data_cpl_out.w_data   = b_data_cpl_in.w_data;
    b_data_cpl_out.w_hv     = b_data_cpl_in.w_hv;
    b_data_cpl_out.w_dv     = b_data_cpl_in.w_dv;
    b_data_cpl_out.w_eot    = b_data_cpl_in.w_eot;
    b_data_cpl_out.w_header     = s_data_cpl_headerOut;
    b_data_cpl_out.w_headerProt = s_data_cpl_ras_gen_en ? s_data_cpl_headerProt : b_data_cpl_in.w_headerProt;
    b_data_cpl_in.w_halt    = b_data_cpl_out.w_halt;
  end : c_driving_dataCpl_PROC  

  /*
    Driving the hard stop ack
  */
  always_comb begin : c_feedingHaltSignal_PROC
    b_hwStop_req.w_ack = r_hard_stop_ack;
  end : c_feedingHaltSignal_PROC

  /*
    Driving the hard stop channel active and injected
  */
  always_comb begin : c_drivingHwStop_PROC
    b_hwStop_active.w_data   = r_hard_stop_state.active;
    b_hwStop_injected.w_data = r_hard_stop_state.ll_cpl_err_inj | r_hard_stop_state.data_cpl_err_inj;
  end : c_drivingHwStop_PROC

// SNPS_SysML_CODE_END

endmodule
