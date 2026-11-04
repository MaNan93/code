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

//-------------------------------------------------------------------------
//---  RCS information:
//---    $DateTime: 2023/04/29 12:35:01 $
//---    $Revision: #10 $
//---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/outbound/DWC_pcie_bridge_ob_np_dcmp_srlzr.sv#10 $
//-------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_bridge_ob_np_dcmp_srlzr (

    core_clk,
    core_rst_n,

    cfg_ax_snp_en,

  // Outbound Non Posted Decomposer request interface
    outq_pkt_hv,
    outq_pkt_dv,
    outq_pkt_eot,
    outq_pkt_dcmp_rd,
    outq_pkt_first_wrp_split_xact,
    outq_pkt_wrp_valid,
    outq_pkt_serial_req,
    outq_pkt_out_tag,
    outq_pkt_axi_id,
    outq_pkt_cpl_stat,
    client1_halt,

    tm_next_tag,
    tm_next_tag_vld,
    srlzr_use_tag,
    srlzr_out_tag,

  // Completion interface
    ibrtr_inbd_hv,
    ibrtr_inbd_tag,
    ibrtr_inbd_last,
    ibrtr_inbd_dllp_abort,
    ibrtr_inbd_tlp_abort,
    ibrtr_inbd_eot,

  // Timeout interface
    radm_cpl_timeout,
    radm_timeout_cpl_tag,

  // Halt for decomposer out queue FSM

    srlzr_halt,
    srlzr_hv,
    srlzr_dv,
    srlzr_eot,

    s_wtag_active_lut

   );

parameter  TP                                = `TP;

localparam MAX_WIRE_8BIT_TAG                 = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_8BIT_TAG_HIGH        :  `CX_MAX_TAG;
localparam MAX_WIRE_8BIT_TAG_PW              = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_8BIT_TAG_HIGH_WIDTH  :  `CX_LUT_PTR_WIDTH;
localparam MAX_WIRE_10BIT_TAG                = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_10BIT_TAG_HIGH       :  `CX_MAX_TAG;
localparam MAX_WIRE_10BIT_TAG_PW             = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_10BIT_TAG_HIGH_WIDTH :  10;
localparam MAX_WIRE_TAG                      = MAX_WIRE_10BIT_TAG;
localparam MAX_WIRE_TAG_PW                   = MAX_WIRE_10BIT_TAG_PW;
localparam CX_TAG_SIZE                       = `CX_TAG_SIZE;
localparam CC_SLV_BUS_ID_WIDTH               = `CC_SLV_BUS_ID_WIDTH;

localparam MAX_WIRE_TAG_LOG2                 = MAX_WIRE_TAG > 1 ? $clog2(MAX_WIRE_TAG) : 1;

localparam AXI_LUT_ARY_WD                    = CC_SLV_BUS_ID_WIDTH+1+2;
localparam AXI_ID_HIGH                       = AXI_LUT_ARY_WD-1;
localparam AXI_ID_LOW                        = AXI_ID_HIGH-CC_SLV_BUS_ID_WIDTH;

input                                   core_clk;
input                                   core_rst_n;

input                                   cfg_ax_snp_en;

input                                   outq_pkt_hv;
input                                   outq_pkt_dv;
input                                   outq_pkt_eot;
input                                   outq_pkt_dcmp_rd;
input                                   outq_pkt_first_wrp_split_xact;
input                                   outq_pkt_wrp_valid;
input                                   outq_pkt_serial_req;
input  [MAX_WIRE_TAG_PW-1:0]            outq_pkt_out_tag;
input  [CC_SLV_BUS_ID_WIDTH:0]          outq_pkt_axi_id;
input  [2:0]                            outq_pkt_cpl_stat;
input                                   client1_halt;

input  [MAX_WIRE_TAG_PW-1:0]            tm_next_tag;
input                                   tm_next_tag_vld;
output                                  srlzr_use_tag;
output [MAX_WIRE_TAG_PW-1:0]            srlzr_out_tag;
output logic [MAX_WIRE_TAG :0]          s_wtag_active_lut;

input                                   ibrtr_inbd_hv;
input  [MAX_WIRE_TAG_PW-1:0]            ibrtr_inbd_tag;
input                                   ibrtr_inbd_last;
input                                   ibrtr_inbd_dllp_abort;
input                                   ibrtr_inbd_tlp_abort;
input                                   ibrtr_inbd_eot;

input                                   radm_cpl_timeout;
input  [CX_TAG_SIZE-1:0]                radm_timeout_cpl_tag;

output                                  srlzr_halt;

output                                  srlzr_hv;
output                                  srlzr_dv;
output                                  srlzr_eot;

reg    [AXI_LUT_ARY_WD-1:0]             axi_lut_ary[MAX_WIRE_TAG:0];
reg    [AXI_LUT_ARY_WD-1:0]             next_axi_lut_ary[MAX_WIRE_TAG:0];
reg                                     s_srlzr_halt;

reg    [MAX_WIRE_TAG_PW-1:0]            r_tm_tag;
reg                                     r_tag_vld;

// Reduced width nets to fix ImproperRangeIndex Lint error
wire   [MAX_WIRE_TAG_LOG2-1:0]          srlzr_out_tag_int;
wire   [MAX_WIRE_TAG_LOG2-1:0]          ibrtr_inbd_tag_int;
wire   [MAX_WIRE_TAG_LOG2-1:0]          radm_timeout_cpl_tag_int;

always@(posedge core_clk or negedge core_rst_n) begin : R_TAG_VLD_SEQ_PROC
  if (!core_rst_n) begin
    r_tag_vld <= #TP 1'b0;
  end else begin          
    if (srlzr_hv) begin
      if (!client1_halt) begin
        r_tag_vld <= #TP 1'b0;
      end else begin
        r_tag_vld <= #TP 1'b1;
      end
    end     
  end
end

always@(posedge core_clk or negedge core_rst_n) begin : R_TM_TAG_SEQ_PROC
  if (!core_rst_n) begin
    r_tm_tag <= #TP {MAX_WIRE_TAG_PW{1'b0}};
  end else begin          
    if (!r_tag_vld) begin
      r_tm_tag <= #TP tm_next_tag;
    end     
  end
end

//assign srlzr_out_tag = r_tag_vld ? r_tm_tag : tm_next_tag;
assign srlzr_out_tag = outq_pkt_out_tag;
assign srlzr_use_tag = srlzr_hv && !r_tag_vld;

// Array used to store AXI ID, Wire tag and active bit,
// stored in the following order: {[AXI ID],[Wire tag],allDcmpRdInflight,active}
always@(posedge core_clk or negedge core_rst_n)
begin : AXI_LUT_ARY_SEQ_PROC
  integer i;
  if (!core_rst_n) begin
    for (i=0; i<=MAX_WIRE_TAG; i=i+1) begin
      axi_lut_ary[i] <= {(AXI_LUT_ARY_WD){1'b0}};
    end
  end else begin
    for (i=0; i<=MAX_WIRE_TAG; i=i+1) begin
      axi_lut_ary[i] <= next_axi_lut_ary[i];
    end
  end
end

// Reduced width nets to fix ImproperRangeIndex Lint error
assign srlzr_out_tag_int        = srlzr_out_tag [MAX_WIRE_TAG_LOG2-1:0];
assign ibrtr_inbd_tag_int       = ibrtr_inbd_tag[MAX_WIRE_TAG_LOG2-1:0];
assign radm_timeout_cpl_tag_int = (radm_timeout_cpl_tag > MAX_WIRE_TAG) ? '0 : radm_timeout_cpl_tag[MAX_WIRE_TAG_LOG2-1:0];

always@(*)
begin : AXI_LUT_ARY_COMB_PROC
  integer i;

  for (i=0; i<=MAX_WIRE_TAG; i=i+1) begin
    next_axi_lut_ary[i] = axi_lut_ary[i];

    if(outq_pkt_hv && !srlzr_halt && !(outq_pkt_dcmp_rd || (outq_pkt_first_wrp_split_xact && outq_pkt_wrp_valid)) && (axi_lut_ary[i][AXI_LUT_ARY_WD-1:2] == outq_pkt_axi_id) && axi_lut_ary[i][0]) begin
      next_axi_lut_ary[i][1] = 1'b1;                                               // if a new non-dcmp req is issued, set allDcmpRdInflight bit for all active wiretags with the same axi id
    end
  end

  if(outq_pkt_hv && !srlzr_halt && (outq_pkt_cpl_stat == 3'b000)) begin                                         // if a new request is accepted then point to the array position that matches the wire tag and
    next_axi_lut_ary[srlzr_out_tag_int][AXI_LUT_ARY_WD-1:2] = outq_pkt_axi_id;     // store the AXI ID
    next_axi_lut_ary[srlzr_out_tag_int][1]                  = !(outq_pkt_dcmp_rd || (outq_pkt_first_wrp_split_xact && outq_pkt_wrp_valid));   // reset allDcmpRdInflight bit if this request is dcmp
    next_axi_lut_ary[srlzr_out_tag_int][0]                  = 1'b1;                // set the active bit
  end
                                                                                   // completions and timeouts need to be handled separately because they can arrive simultaneoulsy
  if(ibrtr_inbd_last && ibrtr_inbd_eot &&                                          // if a completion is received
     !ibrtr_inbd_dllp_abort && !ibrtr_inbd_tlp_abort)begin                         // without error
    next_axi_lut_ary[ibrtr_inbd_tag_int][0]                    = 1'b0;             // reset the active bit at the location matching the wire tag received
  end

  if(radm_cpl_timeout)begin                                                        // if a timeout is received
    next_axi_lut_ary[radm_timeout_cpl_tag_int][0]              = 1'b0;             // reset the active bit at the location matching the timed out wire tag
  end
end

always@(*)
begin : SRLZR_HALT_COMB_PROC
  integer i;
  s_srlzr_halt = 1'b0;
  for (i=0; i<=MAX_WIRE_TAG; i=i+1) begin
    if ((axi_lut_ary[i][AXI_LUT_ARY_WD-1:2] == outq_pkt_axi_id) && outq_pkt_hv && // if request AXI ID matches a previous LUT entry AND
      ( (cfg_ax_snp_en &&                                                         // ( serialization is enabled AND
         outq_pkt_serial_req &&                                                   //   request is serialized AND
         axi_lut_ary[i][1:0] == 2'b11) ) ) begin                                  //   the wiretag is active and all dcmp reqs were issued for this request )
      s_srlzr_halt = 1'b1;                                                        // assert halt
    end
  end
end

always_comb begin : s_wtag_active_lut_COMB_PROC
  foreach(s_wtag_active_lut[i]) begin
    s_wtag_active_lut[i] = axi_lut_ary[i][0];
  end
end : s_wtag_active_lut_COMB_PROC

assign srlzr_halt = s_srlzr_halt || client1_halt || !(tm_next_tag_vld || r_tag_vld);

assign srlzr_hv   = outq_pkt_hv  && !s_srlzr_halt && (tm_next_tag_vld || r_tag_vld);
assign srlzr_dv   = outq_pkt_dv  && !s_srlzr_halt && (tm_next_tag_vld || r_tag_vld);
assign srlzr_eot  = outq_pkt_eot && !s_srlzr_halt && (tm_next_tag_vld || r_tag_vld);


endmodule // DWC_pcie_bridge_ob_np_dcmp_srlzr

