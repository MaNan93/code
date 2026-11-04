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
// ---    $DateTime: 2023/04/29 12:35:01 $ 
// ---    $Revision: #3 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/outbound/DWC_pcie_bridge_ob_np_dcmp_ts.sv#3 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Bridge/outbound/svif/DWC_pcie_bridge_ob_np_dcmp_tsq_pkto_if.svh"
`include "Bridge/outbound/svif/DWC_pcie_bridge_ob_np_dcmp_tst_wtrls_if.svh"
`include "Bridge/outbound/svif/DWC_pcie_bridge_ob_np_dcmp_tst_wtasg_if.svh"
`include "Bridge/outbound/svif/DWC_pcie_bridge_ob_np_dcmp_tsq_pkti_if.svh"
`include "Bridge/outbound/svif/DWC_pcie_bridge_ob_np_dcmp_tsq_clk_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_bridge_ob_np_dcmp_ts
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter type P_PKT_IN_TYPE  = logic
  ,parameter type P_PKT_OUT_TYPE = logic
  ,parameter            CC_MAX_SLV_TAG = `CC_MAX_SLV_TAG
  ,parameter         CC_MAX_SLV_TAG_PW = `CC_MAX_SLV_TAG_PW
  ,parameter              MAX_WIRE_TAG = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_TAG_HIGH       : `CX_MAX_TAG
  ,parameter           MAX_WIRE_TAG_PW = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_TAG_HIGH_WIDTH : `CX_LUT_PTR_WIDTH
  ,parameter          FIFO_BYTE_LEN_WD = `CC_SLV_MTU_PW < (`CC_SLV_RD_REQ_SIZE_PW+1) ? `CC_SLV_MTU_PW : `CC_SLV_RD_REQ_SIZE_PW
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################

  // ############################## Clocks and Resets #########################
   input logic                                   slv_aclk
  ,input logic                                   slv_aresetn

  // ############################## Configuration #############################
  ,input logic                                   cfg_ext_tag_en
  ,input logic                                   cfg_10b_tag_en

  ,input                          P_PKT_IN_TYPE  inq_pkt
  ,output                         P_PKT_OUT_TYPE ts_pkt
  ,input  logic                                  tagq_pkt_halt
  ,output logic                                  inq_pkt_halt

  // ############ Slvclock virtual wiretag assignment out to hdf  #############
  ,output logic                                  slv_wt_assigned_valid
  ,output logic [        CC_MAX_SLV_TAG_PW -1:0] slv_wt_assigned_apptag

  // ############## Wiretag order interface to slave read #####################
  ,input  logic [        CC_MAX_SLV_TAG_PW -1:0] slv_lookup_apptag
  ,input  logic                                  slv_pop_wiretag
  ,output logic [          MAX_WIRE_TAG_PW -1:0] slv_lookup_wiretag
  ,output logic                                  slv_lookup_wiretag_is_last

  ,input  logic [          MAX_WIRE_TAG_PW -1:0] rdr_lookup_wiretag
  ,input  logic                                  rdr_pop_wiretag
  );

  // ##########################################################################
  //                               Wiring Declaration                          
  // ##########################################################################

  // ########################## Interface instances ###########################
  DWC_pcie_bridge_ob_np_dcmp_tsq_clk_if                                                                               b_tagq_clk        ();
  DWC_pcie_bridge_ob_np_dcmp_tst_clk_if                                                                               b_trkr_clk        ();

  DWC_pcie_bridge_ob_np_dcmp_tst_wtasg_if #(.CC_MAX_SLV_TAG_PW(CC_MAX_SLV_TAG_PW), .MAX_WIRE_TAG_PW(MAX_WIRE_TAG_PW)) b_tagq_wt_assigned();
  DWC_pcie_bridge_ob_np_dcmp_tst_wtrls_if #(.MAX_WIRE_TAG_PW(MAX_WIRE_TAG_PW))                                        b_tagq_wt_released();

  DWC_pcie_bridge_ob_np_dcmp_tst_llo_if   #(.CC_MAX_SLV_TAG_PW(CC_MAX_SLV_TAG_PW), .MAX_WIRE_TAG_PW(MAX_WIRE_TAG_PW)) b_slv_rd_ll       ();

  DWC_pcie_bridge_ob_np_dcmp_tsq_pkti_if  #(.P_PKT_TYPE(P_PKT_IN_TYPE))                                               b_tagq_pkt_inq    ();
  DWC_pcie_bridge_ob_np_dcmp_tsq_pkto_if  #(.P_PKT_TYPE(P_PKT_IN_TYPE))                                               b_tagq_pkt_tagq   ();

  // ########################## Connect tagq clocks ###########################
  assign b_tagq_clk.w_slv_aclk    = slv_aclk   ;
  assign b_tagq_clk.w_slv_aresetn = slv_aresetn;

  // ########################## Connect trkr clocks ###########################
  assign b_trkr_clk.w_slv_aclk    = slv_aclk   ;
  assign b_trkr_clk.w_slv_aresetn = slv_aresetn;

  assign b_tagq_pkt_inq.w_cfg_ext_tag_en = cfg_ext_tag_en;
  assign b_tagq_pkt_inq.w_cfg_10b_tag_en = cfg_10b_tag_en;

  assign b_tagq_pkt_inq.w_pkt = inq_pkt;
  assign inq_pkt_halt = b_tagq_pkt_inq.w_pkt_halt;

  assign ts_pkt = '{
    iq2tq           : b_tagq_pkt_tagq.w_pkt
   ,pkt_out_tag     : b_tagq_wt_assigned.w_new_wiretag
//   ,pkt_out_tag_only: !b_tagq_pkt_tagq.w_pkt.hv
  };
  assign b_tagq_pkt_tagq.w_pkt_halt = tagq_pkt_halt;

  // ################ Connect virtual wiretag injection to hdf ################
  assign slv_wt_assigned_valid  = b_tagq_wt_assigned.w_new_wiretag_valid;
  assign slv_wt_assigned_apptag = b_tagq_wt_assigned.w_new_apptag       ;

  // ###################### Connect trkr_if to slv ############################
  assign b_slv_rd_ll.w_apptag                   =             slv_lookup_apptag;
  assign b_slv_rd_ll.w_pop_wiretag              =             slv_pop_wiretag  ;
  assign             slv_lookup_wiretag         = b_slv_rd_ll.w_wiretag        ;
  assign             slv_lookup_wiretag_is_last = b_slv_rd_ll.w_wiretag_is_last;


  // ##########################################################################
  //                             Instances Declaration                         
  // ##########################################################################

  localparam type L_APPTAG_PTR_TYPE = logic [CC_MAX_SLV_TAG_PW -1:0];
  localparam type L_BYTE_LEN_TYPE   = logic  [FIFO_BYTE_LEN_WD -1:0];

  DWC_pcie_bridge_ob_np_dcmp_tsq
   #(
    .P_PKT_TYPE                ( P_PKT_IN_TYPE             )
   ,.P_APPTAG_PTR_TYPE         ( L_APPTAG_PTR_TYPE         )
   ,.P_BYTE_LEN_TYPE           ( L_BYTE_LEN_TYPE           )
   ,.MAX_WIRE_TAG              ( MAX_WIRE_TAG              )
   ,.MAX_WIRE_TAG_PW           ( MAX_WIRE_TAG_PW           )
  ) u_tagq (
    .b_clk              (         b_tagq_clk.slave_mp  )
   ,.b_inq              (     b_tagq_pkt_inq.slave_mp  )
   ,.b_tagq             (    b_tagq_pkt_tagq.master_mp )
   ,.b_slv_wt_assigned  ( b_tagq_wt_assigned.master_mp )
   ,.b_slv_wt_released  ( b_tagq_wt_released.slave_mp  )

   ,.rdr_lookup_wiretag ( rdr_lookup_wiretag           )
   ,.rdr_pop_wiretag    ( rdr_pop_wiretag              )
  );

  DWC_pcie_bridge_ob_np_dcmp_tst
   #(
    .CC_MAX_SLV_TAG    ( CC_MAX_SLV_TAG    )
   ,.CC_MAX_SLV_TAG_PW ( CC_MAX_SLV_TAG_PW )
   ,.MAX_WIRE_TAG      ( MAX_WIRE_TAG      )
   ,.MAX_WIRE_TAG_PW   ( MAX_WIRE_TAG_PW   )
  ) u_trkr (
    .b_clk              (         b_trkr_clk.slave_mp  )
   ,.b_slv_wt_assigned  ( b_tagq_wt_assigned.slave_mp  )
   ,.b_slv_tag_released ( b_tagq_wt_released.master_mp )
   ,.b_slv_rd_ll        (        b_slv_rd_ll.master_mp )
  );
endmodule : DWC_pcie_bridge_ob_np_dcmp_ts
