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
// ---    $Revision: #8 $ 
// ---    $Author: lnicola $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_tlpFetchSize.sv#8 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_cdmregs_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"

module DWC_pcie_edmapf_tlpFetchSize

  import DWC_pcie_edmapf_pkg::*;

  import DWC_pcie_tlp_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration
  // ##########################################################################
   parameter dmaEngType_e P_CHANNEL    = E_WRITE
  ) (
  // ##########################################################################
  //                                Ports Declaration
  // ##########################################################################

   DWC_pcie_edmapf_cdmregs_if.slave_mp  b_cdm

  ,DWC_pcie_edmapf_aclks_if.slave_mp    b_clk
  ,input  logic        i_reqValid
  ,input  logic [ 7:0] i_reqPF   
  ,input  logic [31:0] i_reqSize 
  ,input  logic [63:0] i_reqSAR  
  ,input  logic [63:0] i_reqDAR  
  ,output logic        o_reqHalt 
  ,input  logic        i_tlpHalt 
  ,output logic        o_tlpValid
  ,output logic [31:0] o_tlpSize 
  ,output logic [63:0] o_tlpSAR  
  ,output logic [63:0] o_tlpDAR  
  );

  typedef struct packed {
    logic [ 7:0]      pf             ;
    logic [31:0]      xferSize       ;
    logic [63:0]      sar            ;
    logic [63:0]      dar            ;
  } reqData_s ;

  typedef struct packed {
    logic [31:0]      xferSize       ;
    logic [63:0]      sar            ;
    logic [63:0]      dar            ;
  } tlpData_s ;

  typedef struct packed {
    logic [12:0]      payloadSize    ;
    reqData_s         reqData        ;
  } calcPayloadData_s;

  typedef struct packed {
    logic [31:0]      xferDelta      ;
    reqData_s         reqData        ;
  } calcXferData_s;

  typedef struct packed {
    calcPayloadData_s data           ;
    logic             valid          ;
  } calcPayload_s;

  typedef struct packed {
    calcXferData_s    data           ;
    logic             valid          ;
  } calcXfer_s;

  typedef struct packed {
    tlpData_s         data           ;
    logic             valid          ;
  } calcUpdate_s;
  
  calcPayloadData_s s_calcPayloadData;
  reqData_s s_reqData;

  always_comb begin : s_calcPayloadData_PROC
    s_calcPayloadData.reqData = s_reqData;
    s_calcPayloadData.payloadSize = dmactrl_max_pload_calc(
      .WRITE_CH_NOT_READ_CH          ( P_CHANNEL == E_WRITE                  ),
      .pf                            ( s_reqData.pf                          ), 
      .cfg_max_payload_size          ( b_cdm.w_cfg_max_payload_size          ),
      .cfg_max_rd_req_size           ( b_cdm.w_cfg_max_rd_req_size           ),
      .cfg_remote_rd_req_bridge_size ( b_cdm.w_cfg_remote_rd_req_bridge_size )
      );
  end

  function automatic tlpData_s f_calcUpdate(input calcXferData_s lastPoint);
    tlpData_s nextPoint;
    nextPoint.xferSize = 32'({1'b0,lastPoint.reqData.xferSize} - {1'b0,lastPoint.xferDelta});
    nextPoint.sar      = 64'({1'b0,lastPoint.reqData.sar     } + {1'b0,lastPoint.xferDelta});
    nextPoint.dar      = 64'({1'b0,lastPoint.reqData.dar     } + {1'b0,lastPoint.xferDelta});
    return nextPoint;
  endfunction

  logic s_calcXfer_ready         ;
  logic s_calcUpdate_ready       ;

  struct packed {
    calcPayload_s calcPayload    ;
    calcXfer_s    calcXfer       ;
    calcUpdate_s  calcUpdate     ;
  } r,s;

  /*
  * r register.
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : r_PROC
    if (!b_clk.w_reset_n) begin
      r <= #`TP '0;
    end else begin
      r <= #`TP s;
    end
  end : r_PROC

  assign s_reqData.pf       = i_reqPF                    ;
  assign s_reqData.xferSize = i_reqSize                  ;
  assign s_reqData.sar      = i_reqSAR                   ;
  assign s_reqData.dar      = i_reqDAR                   ;
  assign o_tlpValid         = r.calcUpdate.valid         ;
  assign o_tlpSize          = r.calcUpdate.data.xferSize ;
  assign o_tlpSAR           = r.calcUpdate.data.sar      ;
  assign o_tlpDAR           = r.calcUpdate.data.dar      ;

  assign o_reqHalt = r.calcPayload.valid && !s_calcXfer_ready;
  always_comb begin : calcPayload_PROC
    if (!o_reqHalt) begin
      s.calcPayload.data  = s_calcPayloadData;
      s.calcPayload.valid = i_reqValid;
    end else begin
      s.calcPayload = r.calcPayload;
    end
  end

  assign s_calcXfer_ready = !r.calcXfer.valid || s_calcUpdate_ready;
  always_comb begin : calcXfer_PROC
    if (s_calcXfer_ready) begin
      s.calcXfer.data.xferDelta = dma_xferSize_calc(
                                                    .WRITE_CH_NOT_READ_CH (P_CHANNEL == E_WRITE               ),
                                                    .mtu                  (r.calcPayload.data.payloadSize     ),
                                                    .ctrl_ch_dar_ptr      (r.calcPayload.data.reqData.dar     ),
                                                    .ctrl_ch_sar_ptr      (r.calcPayload.data.reqData.sar     ),
                                                    .ctrl_ch_xfersize     (r.calcPayload.data.reqData.xferSize)
                                                   );
      s.calcXfer.data.reqData = r.calcPayload.data.reqData;
      s.calcXfer.valid = r.calcPayload.valid;
    end else begin
      s.calcXfer = r.calcXfer;
    end
  end

  assign s_calcUpdate_ready = !r.calcUpdate.valid || !i_tlpHalt;
  always_comb begin : calcUpdate_PROC
    if (s_calcUpdate_ready) begin
      s.calcUpdate.data  = f_calcUpdate(r.calcXfer.data);
      s.calcUpdate.valid = r.calcXfer.valid;
    end else begin
      s.calcUpdate = r.calcUpdate;
    end
  end


endmodule : DWC_pcie_edmapf_tlpFetchSize
