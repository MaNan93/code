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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Axi/DWC_pcie_axi_rs.sv#7 $
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
module DWC_pcie_axi_rs
  #(
   parameter P_FEED_READY = 1
  ,parameter CHAN_WD = 31
  ,parameter TP = `TP
  )
  (

   input                      clk
  ,input                      rstn
  ,input                      clrn

  ,input                      vld_from_src //Valid from source
  ,input        [CHAN_WD-1:0] chanl_from_src //AXI channel from source
  ,input                      rdy_from_dest //Ready from destination

  ,output logic               vld_to_dest //Valid to destination
  ,output logic [CHAN_WD-1:0] chanl_to_dest //AXI channel to destination
  ,output logic               rdy_to_src      //Ready to source 
   
  );
  /*
    Internal structure to concatenate the data with valid signal
  */
  typedef struct packed {
    logic               valid;
    logic [CHAN_WD-1:0] data;
  } internalPipe_s;
  /*
    Internal signals
  */
  internalPipe_s s_head;
  internalPipe_s r_head;
  logic          s_headUpdate;
  
  /*
    Connections with external ports from destination
  */
  always_comb begin : c_externalPortsConnections_PROC
    vld_to_dest   = r_head.valid;
    chanl_to_dest = r_head.data;
  end : c_externalPortsConnections_PROC
  
  /*
    Defining if final register should be updated
  */
  always_comb begin : c_headUpdate_PROC
    s_headUpdate = rdy_from_dest || (!r_head.valid);
  end : c_headUpdate_PROC
  
  /*
    Final register stage
  */
  always_ff @(posedge clk, negedge rstn) begin : s_finalRegisterStage_PROC
    if (!rstn) begin
      r_head <= #`TP '0;
    end else begin
      if(!clrn) begin
        r_head <= #`TP '0;
      end else if(s_headUpdate) begin
        r_head <= #`TP s_head;
      end
    end
  end : s_finalRegisterStage_PROC
  
  generate
    if(P_FEED_READY) begin : FEEDTHROUGH_FROM_VALID_TO_READY
      /*
        Indicating when module is ready to receive data
      */
      always_comb begin : c_readyToReceived_PROC
        rdy_to_src = s_headUpdate;
      end : c_readyToReceived_PROC
      
      /*
        Connecting with external ports from source
      */
      always_comb begin : c_s_head_PROC
        s_head.valid = vld_from_src;
        s_head.data  = chanl_from_src;
      end : c_s_head_PROC
      
    end else begin : NO_FEEDTHROUGH_FROM_VALID_TO_READY
      internalPipe_s s_tail;
      internalPipe_s r_tail;
      logic          s_tailUpdate;
      logic          s_tailWrite;
      logic          s_tailRead;
      
      /*
        Selecting the correct source for final register
      */
      always_comb begin : c_muxingSourceFinalRegister_PROC
        if (r_tail.valid) begin
          s_head = r_tail;
        end else begin
          s_head.valid = vld_from_src;
          s_head.data  = chanl_from_src;
        end
      end : c_muxingSourceFinalRegister_PROC
      
      /*
        Defining when the initial register is read
      */
      always_comb begin : c_initialRegisterRead_PROC
        s_tailRead = r_tail.valid && s_headUpdate;
      end : c_initialRegisterRead_PROC
      
      /*
        Defining when the initial register is write
      */
      always_comb begin : c_initialRegisterWrite_PROC
        s_tailWrite = !r_tail.valid && r_head.valid && !s_headUpdate;
      end : c_initialRegisterWrite_PROC
      
      /*
        Defining when the initial register should be updated
      */
      always_comb begin : c_initialRegisterUpdate_PROC
        s_tailUpdate = s_tailWrite || s_tailRead;
      end : c_initialRegisterUpdate_PROC
      
      /*
        Initial register stage
      */
      always_ff @(posedge clk, negedge rstn) begin : s_initialRegisterStage_PROC
        if (!rstn) begin
          r_tail <= #`TP '0;
        end else begin
          if(!clrn) begin
            r_tail <= #`TP '0;
          end else if (s_tailUpdate) begin
            r_tail <= #`TP s_tail;
          end
        end
      end : s_initialRegisterStage_PROC
      
      /*
        Selecting the data to be written into the initial register
      */
      always_comb begin : c_muxingSourceInitialRegister_PROC
        if (s_tailRead) begin
          s_tail = '0;
        end else begin
          s_tail.valid = vld_from_src;
          s_tail.data  = chanl_from_src;
        end
      end : c_muxingSourceInitialRegister_PROC
      
      /*
        Indicating when module is ready to receive data
      */
      always_comb begin : c_readyToReceived_PROC
        rdy_to_src = !r_tail.valid;
      end : c_readyToReceived_PROC
      
    end
  endgenerate
endmodule // DWC_pcie_axi_rs
