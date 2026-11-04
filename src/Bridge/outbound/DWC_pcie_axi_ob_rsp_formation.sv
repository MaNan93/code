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
// ---    $DateTime: 2023/04/29 12:35:01 $
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/outbound/DWC_pcie_axi_ob_rsp_formation.sv#5 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"

 
 module DWC_pcie_axi_ob_rsp_formation
  #(
  parameter SLV_MAX_RD_SIZE_PW             = 5,
  parameter SLV_BUS_DATA_WIDTH             = 32,
  parameter NPRSPF_TLP_DATA_WIDTH          = 32,
  parameter NPRSPF_TLP_NUM_STRBS           = 4,
  parameter SLV_CONV_FAC_WIDTH             = 2,
  parameter NFUNC_WD                       = 3,
  parameter SLV_MTU_PW                     = 7,
  parameter MAX_SLV_TAG_PW                 = 5,
  parameter NW                             = 1,
  parameter TP                             = `TP
  )
  (
  input                                              slv_aclk,
  input                                              slv_aresetn,
  // -------------------------------------------------------------------------------------
  // Composed completion interface
  input                                              cmp_cpl_hv,
  input                                              cmp_cpl_dv,
  input                                              cmp_cpl_eot,
  input       [NPRSPF_TLP_DATA_WIDTH-1:0]            cmp_cpl_data,
  input       [SLV_MAX_RD_SIZE_PW-1:0]               cmp_cpl_byte_len,
  input       [MAX_SLV_TAG_PW-1:0]                   cmp_cpl_tag,
  input                                              cmp_cpl_to,
  input                                              cmp_cpl_ido,
  input                                              cmp_cpl_ro,
  input                                              cmp_cpl_ns,
  input       [2:0]                                  cmp_cpl_tc,
  input       [NFUNC_WD-1:0]                         cmp_cpl_func_num,
  input       [2:0]                                  cmp_cpl_status,
  input                                              cmp_cpl_ep,
  input       [7:0]                                  cmp_cpl_cpl_segment,
  input       [8:0]                                  cmp_cpl_dst_segment,
  output wire                                        nprspf_halt,
  // -------------------------------------------------------------------------------------
  // AXI Slave response interface
  output wire                                        nprspf_valid,
  output wire                                        nprspf_last,
  output wire [SLV_BUS_DATA_WIDTH-1:0]               nprspf_data,
  output wire [MAX_SLV_TAG_PW-1:0]                   nprspf_tag,
  output wire                                        nprspf_to,
  output wire                                        nprspf_ido,
  output wire                                        nprspf_ro,
  output wire                                        nprspf_ns,
  output wire [2:0]                                  nprspf_tc,
  output wire [NFUNC_WD-1:0]                         nprspf_func_num,
  output wire [2:0]                                  nprspf_status,
  output wire                                        nprspf_ep,
  output wire [7:0]                                  nprspf_cpl_segment,
  output wire [8:0]                                  nprspf_dst_segment,
  input                                              sif_np_ready
  );
  // -------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------
  localparam RSP_INTF_WD = { 1                     // valid
                           + 1                     // last
                           + SLV_BUS_DATA_WIDTH    // data
                           + MAX_SLV_TAG_PW        // tag
                           + 1                     // to
                           + 1                     // ido
                           + 1                     // ro
                           + 1                     // ns
                           + 3                     // tc
                           + NFUNC_WD              // nfunc
                           + 3                     // status
                           + 1                     // ep
                           + 8                     // cpl_segment,
                           + 9                     // dst_segment
                           };



  // -------------------------------------------------------------------------------------
  // -------------------------------------------------------------------------------------
  // Internal wire/reg
  // -------------------------------------------------------------------------------------
  wire                                     ctl_valid, ctl_last;
  wire [NPRSPF_TLP_NUM_STRBS-1:0]          ctl_strb;



  wire                                     pdly2_ready;
  wire                                     pdly2_halt;

  wire [RSP_INTF_WD-1:0]                   s_nprsp_intf, pdly2_nprsp_intf;
  wire                                     s_nprspf_halt;

  // -------------------------------------------------------------------------------------
  // Design
  // -------------------------------------------------------------------------------------
  // Instantiate control block
  DWC_pcie_axi_ob_rsp_formation_ctl
  
  #(.SLV_MAX_RD_SIZE_PW                    (SLV_MAX_RD_SIZE_PW)
   ,.SLV_MTU_PW                            (SLV_MTU_PW)
   ,.NPRSPF_TLP_NUM_STRBS                  (NPRSPF_TLP_NUM_STRBS)
  )
  u_ctl
  (.slv_aclk                              (slv_aclk)
  ,.slv_aresetn                           (slv_aresetn)
  // -------------------------------------------------------------------------------------
  ,.cmp_cpl_hv                            (cmp_cpl_hv)
  ,.cmp_cpl_dv                            (cmp_cpl_dv)
  ,.cmp_cpl_eot                           (cmp_cpl_eot)
  ,.cmp_cpl_byte_len                      (cmp_cpl_byte_len)
  ,.cmp_cpl_to                            (cmp_cpl_to)
  ,.cmp_cpl_status                        (cmp_cpl_status)
  ,.ctl_halt                              (nprspf_halt)
  // -------------------------------------------------------------------------------------
  ,.ctl_valid                             (ctl_valid)
  ,.ctl_last                              (ctl_last)
  ,.ready                                 (pdly2_ready)
  );


  // Pack interface
  assign s_nprsp_intf = {{(RSP_INTF_WD-(1+1+NPRSPF_TLP_DATA_WIDTH+MAX_SLV_TAG_PW+1                                                                                    +1
                                                                                    +1+1+3+NFUNC_WD+3+1
                                                                                    + 8
                                                                                    + 9
                                                                                    )){1'b0}}
                        , ctl_valid
                        , ctl_last
                        , cmp_cpl_data
                        , cmp_cpl_tag
                        , cmp_cpl_to
                        , cmp_cpl_ido
                        , cmp_cpl_ro
                        , cmp_cpl_ns
                        , cmp_cpl_tc
                        , cmp_cpl_func_num
                        , cmp_cpl_status
                        , cmp_cpl_ep
                        , cmp_cpl_cpl_segment
                        , cmp_cpl_dst_segment
                        };


  assign pdly2_ready = !pdly2_halt;

  // -------------------------------------------------------------------------------------
  // Instantiate pipeline
  delay_1_w_stalling
  
  #(.DELAY_EN          (1)
   ,.WD                (RSP_INTF_WD)
   ,.CAN_STALL         (1)
  )
  u_pdly2
  (.clk                (slv_aclk)
  ,.rst_n              (slv_aresetn)
  ,.clear              (1'b0)
  ,.din                (s_nprsp_intf)
  ,.stallout           (pdly2_halt)

  ,.dout               (pdly2_nprsp_intf)
  ,.stall              (s_nprspf_halt)
  );

  // Unpack
  assign { nprspf_valid
         , nprspf_last
         , nprspf_data
         , nprspf_tag
         , nprspf_to
         , nprspf_ido
         , nprspf_ro
         , nprspf_ns
         , nprspf_tc
         , nprspf_func_num
         , nprspf_status
         , nprspf_ep
         , nprspf_cpl_segment
         , nprspf_dst_segment
         } =  pdly2_nprsp_intf;

  // Stall pipeline
  assign s_nprspf_halt = nprspf_valid && !sif_np_ready;

endmodule
