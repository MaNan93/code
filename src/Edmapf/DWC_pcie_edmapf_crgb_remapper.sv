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
// ---    $Revision: #10 $ 
// ---    $Author: dnolan $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_crgb_remapper.sv#10 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_crgb_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_crgb_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_crgb_remapper
  import DWC_pcie_edmapf_crgb_pkg::*;
  import DWC_pcie_edmapf_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter P_CRGB_ADDR_WD = `CC_CRGB_ADDR_WIDTH
  ,parameter P_CRGB_DATA_WD = 32
  ,parameter  P_NUM_RD_CHAN = `CC_NUM_DMA_RD_CHAN
  ,parameter  P_NUM_WR_CHAN = `CC_NUM_DMA_WR_CHAN
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_aclks_if.slave_mp b_clk
  ,DWC_pcie_edmapf_crgb_if.slave_mp  b_in
  ,DWC_pcie_edmapf_crgb_if.master_mp b_out
  );


// SNPS_SysML_CODE_START

  /*
  * crgb fsm states
  */
  typedef enum logic [1:0] {
     E_CRGBFSM_IDLE    // waiting for crgb, register at reception
    ,E_CRGBFSM_TEST    // register setup new crgb and registers
    ,E_CRGBFSM_REQUEST // send crgb request
    ,E_CRGBFSM_ACK     // buble state for sending crgb ack
  } crgbfsm_e;

  typedef struct packed{
    hdma_v1_reg_map_u data ;
    logic            valid;
  } autoReply_s;

  function automatic autoReply_s f_getAutoReply ( input crgbAddr_s i_addr );
    autoReply_s reply;
    case (i_addr)
      'hA6C   : reply = '{data: '1, valid: '1};
      default : begin
        reply.data = '0;
        if (
          (i_addr.chanType == E_READ  && i_addr.chanNumber < P_NUM_RD_CHAN) || 
          (i_addr.chanType == E_WRITE && i_addr.chanNumber < P_NUM_WR_CHAN)
        ) begin
          case (i_addr.slot)
            E_HDMAREG_EN                      : reply.valid = '0;
            E_HDMAREG_DOORBELL                : reply.valid = '0;
            E_HDMAREG_ELEM_PF                 : reply.valid = '0;
            E_HDMAREG_LLP_LOW                 : reply.valid = '0;
            E_HDMAREG_LLP_HIGH                : reply.valid = '0;
            E_HDMAREG_CYCLE                   : reply.valid = '0;
            E_HDMAREG_XFERSIZE                : reply.valid = '0;
            E_HDMAREG_SAR_LOW                 : reply.valid = '0;
            E_HDMAREG_SAR_HIGH                : reply.valid = '0;
            E_HDMAREG_DAR_LOW                 : reply.valid = '0;
            E_HDMAREG_DAR_HIGH                : reply.valid = '0;
            E_HDMAREG_WATERMARK_EN            : reply.valid = '0;
            E_HDMAREG_CONTROL1                : reply.valid = '0;
            E_HDMAREG_FUNC_NUM                : reply.valid = '0;
            E_HDMAREG_QOS                     : reply.valid = '0;
            E_HDMAREG_STATUS                  : reply.valid = '0;
            E_HDMAREG_INT_STATUS              : reply.valid = '0;
            E_HDMAREG_INT_SETUP               : reply.valid = '0;
            E_HDMAREG_INT_CLEAR               : reply.valid = '0;
            E_HDMAREG_MSI_ADDR_STOP_LOW       : reply.valid = '0;
            E_HDMAREG_MSI_ADDR_STOP_HIGH      : reply.valid = '0;
            E_HDMAREG_MSI_ADDR_WATERMARK_LOW  : reply.valid = '0;
            E_HDMAREG_MSI_ADDR_WATERMARK_HIGH : reply.valid = '0;
            E_HDMAREG_MSI_ADDR_ABORT_LOW      : reply.valid = '0;
            E_HDMAREG_MSI_ADDR_ABORT_HIGH     : reply.valid = '0;
            E_HDMAREG_MSI_MSGD                : reply.valid = '0;
            default                           : reply.valid = '1;
          endcase
        end else begin
          reply.valid = '1;
        end
      end
    endcase
    f_getAutoReply = reply;
  endfunction
  
  struct packed {
    logic             inReqIsWr       ;
    crgbAddr_s        inAddr          ;
    hdma_v1_reg_map_u inWrData        ;
    hdma_v1_reg_map_u inWrMask        ;
    hdma_v1_reg_map_u outRdData       ;
    crgbfsm_e crgbfsm;
  } r,s;

  always_ff @(posedge b_clk.w_aux_clk, negedge b_clk.w_reset_n) begin : r_reg_PROC
    if (!b_clk.w_reset_n) begin
      r <= #`TP '0;
    end else begin
      r <= #`TP s;
    end
  end

  autoReply_s s_autoReply;
  
  logic s_idle2test    ;
  logic s_test2idle    ;
  logic s_test2request ;
  logic s_request2ack  ;
  logic s_ack2idle     ;
  
  assign s_idle2test    = (r.crgbfsm == E_CRGBFSM_IDLE   ) && (b_in.w_rden || b_in.w_wren);
  assign s_test2idle    = (r.crgbfsm == E_CRGBFSM_TEST   ) && (s_autoReply.valid);
  assign s_test2request = (r.crgbfsm == E_CRGBFSM_TEST   ) && (!s_autoReply.valid);
  assign s_request2ack  = (r.crgbfsm == E_CRGBFSM_REQUEST) && (b_out.w_ack);
  assign s_ack2idle     = (r.crgbfsm == E_CRGBFSM_ACK    ) && (E_TRUE);

  /*
  * fsm next crgbfsm logic
  */
  always_comb begin : crgbfsm_PROC
    case (r.crgbfsm)
      default : // E_IDLE
        if (s_idle2test) begin
          s.crgbfsm = E_CRGBFSM_TEST;
        end else begin
          s.crgbfsm = r.crgbfsm;
        end
      E_CRGBFSM_TEST :
        if (s_test2idle) begin
          s.crgbfsm = E_CRGBFSM_IDLE;
        end else if (s_test2request) begin
          s.crgbfsm = E_CRGBFSM_REQUEST;
        end else begin
          s.crgbfsm = r.crgbfsm;
        end
      E_CRGBFSM_REQUEST :
        if (s_request2ack) begin
          s.crgbfsm = E_CRGBFSM_ACK;
        end else begin
          s.crgbfsm = r.crgbfsm;
        end
      E_CRGBFSM_ACK :
        if (s_ack2idle) begin
          s.crgbfsm = E_CRGBFSM_IDLE;
        end else begin
          s.crgbfsm = r.crgbfsm;
        end
    endcase
  end : crgbfsm_PROC

  always_comb begin : in_pipeline_PROC
    if (s_idle2test) begin
      s.inAddr          = b_in.w_address        ;
      s.inWrData        = b_in.w_wr_data        ;
      s.inWrMask        = b_in.w_wr_mask        ;
      s.inReqIsWr       = b_in.w_wren           ;
    end else begin
      s.inAddr          = r.inAddr         ;
      s.inWrData        = r.inWrData       ;
      s.inWrMask        = r.inWrMask       ;
      s.inReqIsWr       = r.inReqIsWr      ;
    end
  end

  always_comb begin : out_pipeline_PROC
    if (s_request2ack) begin
      s.outRdData       = b_out.w_rd_data       ;
    end else begin
      s.outRdData       = r.outRdData      ;
    end
  end

  assign s_autoReply = f_getAutoReply(r.inAddr);
  assign b_in.w_ack = s_ack2idle || s_test2idle;
  assign b_out.w_rden = (s_test2request || r.crgbfsm == E_CRGBFSM_REQUEST) && !r.inReqIsWr;
  assign b_out.w_wren = (s_test2request || r.crgbfsm == E_CRGBFSM_REQUEST) && r.inReqIsWr;

  assign b_out.w_wr_mask         = r.inWrMask;
  assign b_out.w_source          = '0;
  assign b_out.w_address         = r.inAddr;
  assign b_out.w_wr_data         = r.inWrData;
  
  assign b_in.w_rd_data          = s_test2idle ? s_autoReply.data : r.outRdData        ;


// SNPS_SysML_CODE_END

endmodule
