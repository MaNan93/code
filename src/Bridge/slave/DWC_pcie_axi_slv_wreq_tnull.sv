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

// -------------------------------------------------------------------------------------
// ---  RCS information:
// ---    $DateTime: 2021/10/29 02:04:56 $
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/slave/DWC_pcie_axi_slv_wreq_tnull.sv#5 $
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_axi_slv_wreq_tnull
 #(
  parameter SLV_BUS_WSTRB_WIDTH            = 4,
  parameter TP                             = `TP
  )
  (
  input                                              slv_aclk,
  input                                              slv_aresetn,
  // -------------------------------------------------------------------------------------
  // Data width aligned control interface
  input                                              dwalgn_valid,
  input                                              dwalgn_last,
  input       [SLV_BUS_WSTRB_WIDTH-1:0]              dwalgn_strb,
  input       [2:0]                                  lnull_size,
  // -------------------------------------------------------------------------------------
  // Trailing null control interface
  output wire                                        tnull_valid,
  output wire                                        tnull_last,
  output wire                                        tnull_last_null_writes,
  input                                              ready
  );
  // -------------------------------------------------------------------------------------
  // Wire/Reg
  // -------------------------------------------------------------------------------------
  wire                                     s_leading_data_beat;

  reg                                      s_leading_data_beat_det;
  reg                                      r_leading_data_beat_det;

  reg                                      s_trailing_null_beat_det;
  reg                                      r_trailing_null_beat_det;
  wire                                     s_trailing_null_beat_det_hl;

  wire                                     s_last;


  // -------------------------------------------------------------------------------------
  // Design
  // -------------------------------------------------------------------------------------


  // Detect trailing null beat
  always @(*) begin : proc_comb_trailing_null_det
    s_trailing_null_beat_det = r_trailing_null_beat_det;

    if (dwalgn_valid) begin
      if (!dwalgn_last) begin
//        `ifdef CC_AXI_EXTENDED_NCBE
//        if (!(|dwalgn_strb)) begin
//          s_trailing_null_beat_det = 1'b1;
//        end
//        `else // !CC_AXI_EXTENDED_NCBE
        // leading data beat or beats detected followed by a trailing null beat
        // if there are any trailing null beats then the MSB of dwalgn_strb will be 0
        if (!dwalgn_strb[SLV_BUS_WSTRB_WIDTH-1]) begin
          s_trailing_null_beat_det = 1'b1;
        end
//        `endif //  CC_AXI_EXTENDED_NCBE
      end else if (dwalgn_last) begin
        s_trailing_null_beat_det = 1'b0;
      end
    end
  end



  always @(posedge slv_aclk or negedge slv_aresetn) begin : proc_seq_tnull_beat_det
    if (!slv_aresetn) begin
      r_trailing_null_beat_det <= # TP 1'b0;
    end else if (ready) begin
      r_trailing_null_beat_det <= # TP s_trailing_null_beat_det;
    end
  end

  assign s_trailing_null_beat_det_hl = s_trailing_null_beat_det && !r_trailing_null_beat_det;

  // Supress control signals when trailing null detected
  assign tnull_valid            = dwalgn_valid && !r_trailing_null_beat_det;
  assign s_last                 = dwalgn_last && !r_trailing_null_beat_det;
  // Generate last signal on trailing null beat
  assign tnull_last             = s_last || s_trailing_null_beat_det_hl;
  assign tnull_last_null_writes = dwalgn_last;

endmodule
