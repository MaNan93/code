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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Axi/DWC_pcie_axi_mstream_arch_p_ordr.sv#2 $
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Axi/DWC_pcie_axi_xali_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

module DWC_pcie_axi_mstream_arch_p_ordr
  import DWC_pcie_axi_xali_pkg::*;
  import DWC_pcie_ctl_pkg::N_XADM_P_IF;
  #(
  parameter                         NVC = `CX_NVC,
  parameter         CC_SLV_BUS_ID_WIDTH = `CC_SLV_BUS_ID_WIDTH,
  parameter            DC_CPL_STATUS_WD = `DC_CPL_STATUS_WD,
  parameter SLV_MSTREAM_P_ORDR_QUEUE_DP = `CC_SLV_MSTREAM_P_ORDR_QUEUE_DP,
  parameter TP                          = `TP
  ) (
  input  logic                            core_clk,
  input  logic                            core_rst_n,

  input [N_XADM_P_IF-1:0]                 xali_posted_tlp_sent,
  input logic                             pdcmp_p_rsp_valid,          // TLP Posted request issued
  input logic                             pdcmp_p_rsp_null_or_err,    // Null request or request with error
  input logic                             pdcmp_p_rsp_last,           // Last TLP request of a decomposed request issued
  input logic [2:0]                       pdcmp_p_rsp_vc_num,         // VC Number
  input logic [CC_SLV_BUS_ID_WIDTH-1:0]   pdcmp_p_rsp_id,             // Request ID
  input logic [DC_CPL_STATUS_WD-1:0]      pdcmp_p_rsp_cpl_stat,       // Completion Status
  output logic                            mstream_p_rsp_valid,
  output logic [CC_SLV_BUS_ID_WIDTH-1:0]  mstream_p_rsp_id,           // Request ID
  output logic [DC_CPL_STATUS_WD-1:0]     mstream_p_rsp_cpl_stat,     // Completion Status
  output logic                            mstream_halt
  );


  // --------------------------------------------------------------------
  // Local parameters declaration
  // --------------------------------------------------------------------
  localparam SLV_MSTREAM_P_ORDR_QUEUE_WD = $clog2(SLV_MSTREAM_P_ORDR_QUEUE_DP);


  // --------------------------------------------------------------------
  // Signals declaration
  // --------------------------------------------------------------------
  typedef struct packed {
    logic                                          ready;
    logic                                          last;
    logic [2:0]                                    vc_num;
    logic [CC_SLV_BUS_ID_WIDTH-1:0]                axi_id;
    logic [DC_CPL_STATUS_WD-1:0]                   cpl_stat;
    logic                                          null_or_err;
  } p_rsp_slot;


  logic                                            s_mstream_p_rsp_valid, r_mstream_p_rsp_valid;
  logic [CC_SLV_BUS_ID_WIDTH-1:0]                  s_mstream_p_rsp_id, r_mstream_p_rsp_id;
  logic [DC_CPL_STATUS_WD-1:0]                     s_mstream_p_rsp_cpl_stat, r_mstream_p_rsp_cpl_stat;
  p_rsp_slot [0:SLV_MSTREAM_P_ORDR_QUEUE_DP-1]     s_p_rsp_queue, r_p_rsp_queue ;

  logic [SLV_MSTREAM_P_ORDR_QUEUE_WD-1:0]          r_tlp_srlz_cnt; 
  logic [SLV_MSTREAM_P_ORDR_QUEUE_WD-1:0]          r_p_rsp_queue_rd_ptr; 

  logic                                            s_valid_pdcmp_p_rsp;
  logic                                            s_rd_queue_valid;
  logic                                            s_rd_queue_srlz;



  assign s_valid_pdcmp_p_rsp    = pdcmp_p_rsp_valid || (pdcmp_p_rsp_null_or_err && pdcmp_p_rsp_last);


  always_comb begin : proc_comb_rsp_queue
    
    s_p_rsp_queue = r_p_rsp_queue;

    if (s_valid_pdcmp_p_rsp) begin

      s_p_rsp_queue[0].ready  = (
                                   (pdcmp_p_rsp_null_or_err && pdcmp_p_rsp_last)
                                   ) ? 1'b1 : 1'b0; // Null or error TLPs and MIS-X are not passed to Client 2, thus no need to wait for serialization
      s_p_rsp_queue[0].last      = pdcmp_p_rsp_last;
      s_p_rsp_queue[0].axi_id    = pdcmp_p_rsp_id;
      s_p_rsp_queue[0].vc_num    = pdcmp_p_rsp_vc_num;
      s_p_rsp_queue[0].cpl_stat  = pdcmp_p_rsp_cpl_stat;
    end
  end


  //
  // Set the pointer for the oldest element in the queue
  //
  always_ff @(posedge core_clk or negedge core_rst_n) begin

    if (!core_rst_n) begin : proc_seq_queue_rd_ptr
      r_p_rsp_queue_rd_ptr <= #TP '0;
    end else begin

      case ({s_valid_pdcmp_p_rsp, s_rd_queue_valid}) 
         2'b10:   r_p_rsp_queue_rd_ptr <= #TP r_p_rsp_queue_rd_ptr + SLV_MSTREAM_P_ORDR_QUEUE_WD'(1);
         2'b01:   r_p_rsp_queue_rd_ptr <= #TP r_p_rsp_queue_rd_ptr - SLV_MSTREAM_P_ORDR_QUEUE_WD'(1);
         default: r_p_rsp_queue_rd_ptr <= #TP r_p_rsp_queue_rd_ptr;
      endcase

    end

  end


  //
  // Count outstanding transfers in P response queue that had already been serialized
  //
  always_ff @(posedge core_clk or negedge core_rst_n) begin

    if (!core_rst_n) begin : proc_seq_srlz_cnt
      r_tlp_srlz_cnt    <= #TP '0;
    end else begin
              //protection so that a sent is ignored if the queue is empty
      case ({(|xali_posted_tlp_sent) && (|r_p_rsp_queue_rd_ptr) , s_rd_queue_srlz}) 
         2'b10:   r_tlp_srlz_cnt <= #TP r_tlp_srlz_cnt + SLV_MSTREAM_P_ORDR_QUEUE_WD'(1);
         2'b01:   r_tlp_srlz_cnt <= #TP r_tlp_srlz_cnt - SLV_MSTREAM_P_ORDR_QUEUE_WD'(1);
         default: r_tlp_srlz_cnt <= #TP r_tlp_srlz_cnt;
      endcase

    end

  end




  //
  // Read from the queue either when:
  // a. a serialization acknowledge has been received
  // b. there's a null TLP or a TLP with error 
  //
  always_comb begin: proc_comb_rd_p_rsp_queue

    s_rd_queue_valid         = 1'b0;
    s_rd_queue_srlz          = 1'b0;
    s_mstream_p_rsp_valid    = 1'b0;
    s_mstream_p_rsp_id       = '0;
    s_mstream_p_rsp_cpl_stat = '0;



    if ((|r_tlp_srlz_cnt) || (r_p_rsp_queue[r_p_rsp_queue_rd_ptr].ready == 1'b1)) begin 
      s_rd_queue_valid           = 1'b1;

      // An element is removed from the queue due to serialization
      if ((|r_tlp_srlz_cnt) && (r_p_rsp_queue[r_p_rsp_queue_rd_ptr].ready == 1'b0)) begin
        s_rd_queue_srlz          = 1'b1;
      end


      // Acknowledge TLP serialization to Slave B response module
      if (r_p_rsp_queue[r_p_rsp_queue_rd_ptr].last) begin
        s_mstream_p_rsp_valid    = 1'b1;
        s_mstream_p_rsp_id       = r_p_rsp_queue[r_p_rsp_queue_rd_ptr].axi_id;
        s_mstream_p_rsp_cpl_stat = r_p_rsp_queue[r_p_rsp_queue_rd_ptr].cpl_stat;
      end

    end

  end


  //
  // Halt P decomposer when P responses queue gets full
  //
  assign mstream_halt = (r_p_rsp_queue_rd_ptr == SLV_MSTREAM_P_ORDR_QUEUE_WD'(SLV_MSTREAM_P_ORDR_QUEUE_DP-1));


  always_ff @(posedge core_clk or negedge core_rst_n) begin

    if (!core_rst_n) begin : proc_seq_r
      r_p_rsp_queue            <= #TP '0;
      r_mstream_p_rsp_valid    <= #TP '0;
      r_mstream_p_rsp_id       <= #TP '0;
      r_mstream_p_rsp_cpl_stat <= #TP '0;
    end else begin

      if (s_valid_pdcmp_p_rsp) begin
        r_p_rsp_queue[0] <= #TP '0; 
        r_p_rsp_queue[1:SLV_MSTREAM_P_ORDR_QUEUE_DP-1] <= #TP s_p_rsp_queue[0:SLV_MSTREAM_P_ORDR_QUEUE_DP-2]; // Shift 1 element
      end


      r_mstream_p_rsp_valid    <= #TP s_mstream_p_rsp_valid;
      r_mstream_p_rsp_id       <= #TP s_mstream_p_rsp_id;
      r_mstream_p_rsp_cpl_stat <= #TP s_mstream_p_rsp_cpl_stat;
    end
  end


  assign mstream_p_rsp_valid    = r_mstream_p_rsp_valid;
  assign mstream_p_rsp_id       = r_mstream_p_rsp_id;
  assign mstream_p_rsp_cpl_stat = r_mstream_p_rsp_cpl_stat;



`ifndef SYNTHESIS
`endif

endmodule
