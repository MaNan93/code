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

// ---------------------------------------------------------------------------------------
// ---  RCS information:
// ---    $DateTime: 2023/04/29 12:35:01 $
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/inbound/DWC_pcie_bridge_ibdecomp.sv#5 $
// ---------------------------------------------------------------------------------------
// Module Description:
// ---------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"


 module DWC_pcie_bridge_ibdecomp
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::RAS_ERROR_LOG_WD;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  #(
    parameter WR_NOT_RD_QUEUE              = 1,
    parameter CC_MAX_MSTR_TAG_PW           = `CC_MAX_MSTR_TAG_PW,
    parameter CX_NW                        = `CX_NW,
    parameter CX_NFUNC                     = `CX_NFUNC,
    parameter RADMX_TRGT1_REQ_HDR_WD       = `CC_RADMX_TRGT1_REQ_HDR_WD,
    parameter CC_CORE_DATA_BUS_WD          = `CC_CORE_DATA_BUS_WD,
    parameter CC_CORE_ADDR_BUS_WD          = `CC_CORE_ADDR_BUS_WD,
    parameter CX_NFUNC_WD                  = `CX_NFUNC_WD,
    parameter CC_MSTR_BE_CTRL_WIDTH        = `CC_MSTR_BE_CTRL_WIDTH,
    parameter REMOTE_MAX_RD_SIZE_PW        = `CX_REMOTE_RD_REQ_SIZE_PW,
    parameter DC_INBD_HEADER_PNP_1STG_WD   = `DC_INBD_HEADER_PNP_1STG_WD,
    parameter DC_INBD_HEADER_PNP_WD        = `DC_INBD_HEADER_PNP_WD,
    parameter CC_MSTR_BUS_DATA_WIDTH       = `CC_MSTR_BUS_DATA_WIDTH,
    parameter LOW_ADDR_WD                  = `DC_MCB_MAX_CPL_NUM_BYTES_WD-1,
    parameter CX_NVC                       = `CX_NVC,
    parameter CX_NVC_LOG2                  = `CX_NVC_LOG2,
    parameter CX_REMOTE_MAX_TAGS_WD        = `CX_REMOTE_MAX_TAGS_WD,
    parameter DC_DMA_TYPE_WIDTH            = `DC_DMA_TYPE_WIDTH,
    parameter CC_NUM_DMA_MAX_CHAN_WIDTH    = `CC_NUM_DMA_MAX_CHAN_WIDTH,
    parameter TP                           = `TP
    )
   (
    input                                          clk,
    input                                          rstn,

    // Input TLP interface
    input [DC_INBD_HEADER_PNP_1STG_WD-1:0]         inbd_hdr_pnp,
    input [CC_CORE_DATA_BUS_WD-1:0]                inbd_data_pnp,
    output wire                                    inbd_halt_pnp,

    //Output TLP interface
    output wire [DC_INBD_HEADER_PNP_WD-1:0]        dcp_inbd_hdr_pnp,
    output wire [CC_CORE_DATA_BUS_WD-1:0]          dcp_inbd_data_pnp,
    input                                          dcp_inbd_halt_pnp,

    output wire                                    trgt1_addr_parerr,
    output wire                                    trgt1_data_parerr,
    output ras_dp_err_log_t                        trgt1_dt_ras_dp_err_log,
    output ras_dp_err_log_t                        trgt1_ad_ras_dp_err_log,
    input  ras_dp_err_inj_t                        axi_bridge_ras_dp_err_inj_core_clk,
    output wire [DC_DMA_TYPE_WIDTH-1:0]            dcp_inbd_hdr_dma_type,
    output wire [CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]    dcp_inbd_hdr_dma_chan,

    //Extra TLP interface targeted at the master completino buffer
    output wire                                    dcp_inbd_hdr_np_valid,
    output wire                                    dcp_inbd_hdr_ncbe,
    output wire [LOW_ADDR_WD-1:0]                  dcp_inbd_hdr_low_addr,
    output wire [REMOTE_MAX_RD_SIZE_PW-1:0 ]       dcp_inbd_hdr_byte_len,
    output wire [CC_MAX_MSTR_TAG_PW-1:0]           dcp_inbd_hdr_mstr_id,
    output wire [CX_REMOTE_MAX_TAGS_WD-1:0]        dcp_inbd_hdr_lookupid,
    output wire [CX_NFUNC_WD-1:0]                  dcp_inbd_hdr_func,
    output wire                                    dcp_inbd_hdr_last
    );

   //---------------------------------------------------------------------------
   // Local parameters
   //---------------------------------------------------------------------------

   localparam PKT_BYTE_LEN_WD = 13;
   localparam PAGE_BOUNDARY_BIT = `CC_MSTR_PAGE_BOUNDARY_PW;

   //---------------------------------------------------------------------------
   // Wires
   //---------------------------------------------------------------------------
   wire                                            req_pkt_mem_msg;
   wire [PKT_BYTE_LEN_WD-1:0]                      req_pkt_byte_len;

   //Internal Decomposed header
   wire [DC_INBD_HEADER_PNP_1STG_WD-1:0]           dcp_inbd_hdr_int;

   //Detects a non-posted xtact
   wire [1:0]                                      decmposed_pkt_fmt;
   wire [4:0]                                      decmposed_pkt_type;
   wire                                            decmposed_pkt_np;
   //~~~~~ before internal delay tap to the output signal ~~~~~~
   wire                                            i_dcp_inbd_hdr_hv;
   wire                                            i_dcp_inbd_hdr_dv;
   wire                                            i_dcp_inbd_hdr_eot;
   wire [CC_CORE_ADDR_BUS_WD-1:0]                  i_dcp_inbd_hdr_addr;
   wire [7:0]                                      i_dcp_inbd_hdr_byte_en;
   wire [PKT_BYTE_LEN_WD-1:0]                      i_dcp_inbd_hdr_byte_len;
   wire [PKT_BYTE_LEN_WD-1:0]                      i_dcp_inbd_hdr_req_byte_len;
   wire [CC_MSTR_BE_CTRL_WIDTH-1:0]                i_dcp_inbd_hdr_req_byte_en;

   wire                                            i_dcp_inbd_halt_pnp;
   reg [DC_INBD_HEADER_PNP_WD-1:0]                 i_dcp_inbd_hdr_pnp;
   wire [CC_CORE_DATA_BUS_WD-1:0]                  i_dcp_inbd_data_pnp;
   wire                                            i_dcp_inbd_hdr_np_valid;
   wire                                            i_dcp_inbd_hdr_ncbe;
   wire [LOW_ADDR_WD-1:0]                          i_dcp_inbd_hdr_low_addr;
   wire [CC_MAX_MSTR_TAG_PW-1:0]                   i_dcp_inbd_hdr_mstr_id;
   wire [CX_NFUNC_WD-1:0]                          i_dcp_inbd_hdr_func;
   wire                                            i_dcp_inbd_hdr_last;

   //---------------------------------------------------------------------------
   // Internal Design
   //---------------------------------------------------------------------------


   //note: macros bellow include arithmetic inside macros that addess a vector. SelfDeterminedExpr-ML does not applies 
   assign decmposed_pkt_fmt  = dcp_inbd_hdr_int[`INBD_HDR_PNP_RANGE_FMT_HIGH:`INBD_HDR_PNP_RANGE_FMT_LOW];  //spyglass disable SelfDeterminedExpr-ML
   assign decmposed_pkt_type = dcp_inbd_hdr_int[`INBD_HDR_PNP_RANGE_TYPE_HIGH:`INBD_HDR_PNP_RANGE_TYPE_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign decmposed_pkt_np = ((decmposed_pkt_fmt[1] == 1'b0) && (decmposed_pkt_type == 5'd0)) ||
                             ((decmposed_pkt_fmt[1] == 1'b0) && (decmposed_pkt_type == 5'd1)) ||
                             ((decmposed_pkt_fmt[0] == 1'b0) && (decmposed_pkt_type == 5'd2)) ||
                             ((decmposed_pkt_fmt[0] == 1'b0) && (decmposed_pkt_type == 5'd4)) ||
                             ((decmposed_pkt_fmt[0] == 1'b0) && (decmposed_pkt_type == 5'd5)) ||
                             ((decmposed_pkt_fmt[1] == 1'b1) && (decmposed_pkt_type == 5'd12)) ||
                             ((decmposed_pkt_fmt[1] == 1'b1) && (decmposed_pkt_type == 5'd13)) ||
                             ((decmposed_pkt_fmt[1] == 1'b1) && (decmposed_pkt_type == 5'd14));
   // SMD: Self determined expression present in the design
   // SJ: This self determined expression is over integers where no overflow is possbile with used configuration values. An overflow would should up as X's and would be picked in simulation.
   // spyglass disable_block SelfDeterminedExpr-ML
   assign req_pkt_mem_msg = (({inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FMT_HIGH:`INBD_HDR_PNP_RANGE_FMT_LOW], inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TYPE_HIGH:`INBD_HDR_PNP_RANGE_TYPE_LOW]} == `MRD32) ||
                         ({inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FMT_HIGH:`INBD_HDR_PNP_RANGE_FMT_LOW], inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TYPE_HIGH:`INBD_HDR_PNP_RANGE_TYPE_LOW]} == `MRD64) ||
                         ({inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FMT_HIGH:`INBD_HDR_PNP_RANGE_FMT_LOW], inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TYPE_HIGH:`INBD_HDR_PNP_RANGE_TYPE_LOW]} == `MRDLK32) ||
                         ({inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FMT_HIGH:`INBD_HDR_PNP_RANGE_FMT_LOW], inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TYPE_HIGH:`INBD_HDR_PNP_RANGE_TYPE_LOW]} == `MWR32) ||
                         ({inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FMT_HIGH:`INBD_HDR_PNP_RANGE_FMT_LOW], inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TYPE_HIGH:`INBD_HDR_PNP_RANGE_TYPE_LOW]} == `MWR64) ||
                         ({inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FMT_HIGH:`INBD_HDR_PNP_RANGE_FMT_LOW], inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TYPE_HIGH:`INBD_HDR_PNP_RANGE_TYPE_LOW]} == `MRDLK64) ||
                         ({inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FMT_HIGH:`INBD_HDR_PNP_RANGE_FMT_LOW], inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TYPE_HIGH:`INBD_HDR_PNP_RANGE_TYPE_LOW]} == `MRDLK64) ||
                         ({inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FMT_HIGH:`INBD_HDR_PNP_RANGE_FMT_LOW], inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TYPE_HIGH:`INBD_HDR_PNP_RANGE_TYPE_LOW]} == `IORD) ||
                         ({inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FMT_HIGH:`INBD_HDR_PNP_RANGE_FMT_LOW], inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TYPE_HIGH-:2]} == `MSGD_4) ||
                         ({inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FMT_HIGH:`INBD_HDR_PNP_RANGE_FMT_LOW], inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TYPE_HIGH-:2]} == `MSGD_AS_4) ||
                         ({inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FMT_HIGH:`INBD_HDR_PNP_RANGE_FMT_LOW], inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TYPE_HIGH:`INBD_HDR_PNP_RANGE_TYPE_LOW]} == `IOWR));

   assign req_pkt_byte_len  =   {((inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DW_LEN_HIGH:`INBD_HDR_PNP_RANGE_DW_LEN_LOW] == 0) && req_pkt_mem_msg), inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DW_LEN_HIGH:`INBD_HDR_PNP_RANGE_DW_LEN_LOW], 2'b0};
   // spyglass enable_block SelfDeterminedExpr-ML


   generate
      if (WR_NOT_RD_QUEUE) begin : gen_wr_decomp
         DWC_pcie_bridge_ib_wr_dcmp
         
           #(
             .PKT_OUT_TAG_WD       (CC_MAX_MSTR_TAG_PW),
             .NW                   (CX_NW),
             .NF                   (CX_NFUNC),
             .PKT_HDR_WD           (DC_INBD_HEADER_PNP_1STG_WD),
             .PKT_ADDR_WD          (CC_CORE_ADDR_BUS_WD),
             .IN_PKT_DATA_WD       (CC_CORE_DATA_BUS_WD),
             .OUT_PKT_DATA_WD      (CC_CORE_DATA_BUS_WD),
             .PKT_BYTE_LEN_IN_WD   (PKT_BYTE_LEN_WD),
             .PKT_BYTE_LEN_OUT_WD  (PKT_BYTE_LEN_WD),
             .PF_WD                (CX_NFUNC_WD),
             .PAGE_BOUNDARY_BIT    (PAGE_BOUNDARY_BIT),
             .PKT_LOW_ADDR_WD      (LOW_ADDR_WD)
             ) u_dcmpwr
             (
              .in_clk(clk),
              .in_rst_n(rstn),

              .dcmp_pkt_halt(inbd_halt_pnp),
              .req_pkt_hv(inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_HV_HIGH:`INBD_HDR_PNP_RANGE_HV_LOW]), //spyglass disable SelfDeterminedExpr-ML
              .req_pkt_dv(inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DV_HIGH:`INBD_HDR_PNP_RANGE_DV_LOW]), //spyglass disable SelfDeterminedExpr-ML
              .req_pkt_eot(inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_EOT_HIGH:`INBD_HDR_PNP_RANGE_EOT_LOW]), //spyglass disable SelfDeterminedExpr-ML
              .req_pkt_hdr(inbd_hdr_pnp),
              .req_pkt_addr(inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_ADDR_HIGH:`INBD_HDR_PNP_RANGE_ADDR_LOW]), //spyglass disable SelfDeterminedExpr-ML
              .req_pkt_data(inbd_data_pnp),
              .req_pkt_byte_en({inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_LAST_BE_HIGH:`INBD_HDR_PNP_RANGE_LAST_BE_LOW], //spyglass disable SelfDeterminedExpr-ML
                                inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FIRST_BE_HIGH:`INBD_HDR_PNP_RANGE_FIRST_BE_LOW]}), //spyglass disable SelfDeterminedExpr-ML
              .req_pkt_byte_len(req_pkt_byte_len),
              .req_pkt_func_num(inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FUNC_NUM_HIGH:`INBD_HDR_PNP_RANGE_FUNC_NUM_LOW]), //spyglass disable SelfDeterminedExpr-ML
              .req_pkt_out_tag(inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_LOOKUP_ID_HIGH:`INBD_HDR_PNP_RANGE_LOOKUP_ID_LOW]), //spyglass disable SelfDeterminedExpr-ML
              .req_pkt_fmt(inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FMT_HIGH:`INBD_HDR_PNP_RANGE_FMT_LOW]), //spyglass disable SelfDeterminedExpr-ML
              .req_pkt_type(inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TYPE_HIGH:`INBD_HDR_PNP_RANGE_TYPE_LOW]), //spyglass disable SelfDeterminedExpr-ML

              .dwnstrm_pkt_halt(i_dcp_inbd_halt_pnp),

              .dcmp_pkt_hv(i_dcp_inbd_hdr_hv),
              .dcmp_pkt_dv(i_dcp_inbd_hdr_dv),
              .dcmp_pkt_eot(i_dcp_inbd_hdr_eot),
              .dcmp_pkt_hdr(dcp_inbd_hdr_int),
              .dcmp_pkt_addr(i_dcp_inbd_hdr_addr),
              .dcmp_pkt_data(i_dcp_inbd_data_pnp),
              .dcmp_pkt_byte_en(i_dcp_inbd_hdr_byte_en),
              .dcmp_pkt_byte_len(i_dcp_inbd_hdr_byte_len),

              .dcmp_pkt_req_byte_len(i_dcp_inbd_hdr_req_byte_len),
              .dcmp_pkt_func_num(i_dcp_inbd_hdr_func),
              .dcmp_pkt_out_tag(i_dcp_inbd_hdr_mstr_id),
              .dcmp_pkt_ncbe(i_dcp_inbd_hdr_ncbe),
              .dcmp_pkt_last_tlp(i_dcp_inbd_hdr_last),
              .dcmp_pkt_low_addr(i_dcp_inbd_hdr_low_addr),
              .dcmp_pkt_np_tlp_issued(i_dcp_inbd_hdr_np_valid)

              ,.dcmp_addr_parerr(trgt1_addr_parerr)
              ,.dcmp_data_parerr(trgt1_data_parerr)
              ,.dcmp_dt_ras_dp_err_log (trgt1_dt_ras_dp_err_log)
              ,.dcmp_ad_ras_dp_err_log (trgt1_ad_ras_dp_err_log)
              ,.axi_bridge_ras_dp_err_inj_core_clk (axi_bridge_ras_dp_err_inj_core_clk)

              );

         assign i_dcp_inbd_hdr_req_byte_en = {CC_MSTR_BE_CTRL_WIDTH{1'b0}};

      end else begin : gen_rd_decomp
         DWC_pcie_bridge_ib_rd_dcmp
         
           #(
             .PKT_OUT_TAG_WD     (CC_MAX_MSTR_TAG_PW),
             .NW                 (CX_NW),
             .NF                 (CX_NFUNC),
             .PKT_HDR_WD         (DC_INBD_HEADER_PNP_1STG_WD),
             .PKT_ADDR_WD        (CC_CORE_ADDR_BUS_WD),
             .PKT_BYTE_LEN_IN_WD (PKT_BYTE_LEN_WD),
             .PKT_BYTE_LEN_OUT_WD(PKT_BYTE_LEN_WD),
             .PF_WD              (CX_NFUNC_WD),
             .PKT_LOW_ADDR_WD    (LOW_ADDR_WD),
             .PAGE_BOUNDARY_BIT  (PAGE_BOUNDARY_BIT)
             )  u_dcmprd
             (
              .in_clk(clk),
              .in_rst_n(rstn),

              .dcmp_pkt_halt(inbd_halt_pnp),
              .req_pkt_hv(inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_HV_HIGH:`INBD_HDR_PNP_RANGE_HV_LOW]), //spyglass disable SelfDeterminedExpr-ML
              .req_pkt_dv(inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DV_HIGH:`INBD_HDR_PNP_RANGE_DV_LOW]), //spyglass disable SelfDeterminedExpr-ML
              .req_pkt_eot(inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_EOT_HIGH:`INBD_HDR_PNP_RANGE_EOT_LOW]), //spyglass disable SelfDeterminedExpr-ML
              .req_pkt_hdr(inbd_hdr_pnp),
              .req_pkt_addr(inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_ADDR_HIGH:`INBD_HDR_PNP_RANGE_ADDR_LOW]), //spyglass disable SelfDeterminedExpr-ML
              .req_pkt_byte_en({inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_LAST_BE_HIGH:`INBD_HDR_PNP_RANGE_LAST_BE_LOW], //spyglass disable SelfDeterminedExpr-ML
                                inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FIRST_BE_HIGH:`INBD_HDR_PNP_RANGE_FIRST_BE_LOW]}), //spyglass disable SelfDeterminedExpr-ML
              .req_pkt_byte_len(req_pkt_byte_len),
              .req_pkt_func_num(inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FUNC_NUM_HIGH:`INBD_HDR_PNP_RANGE_FUNC_NUM_LOW]), //spyglass disable SelfDeterminedExpr-ML
              .req_pkt_out_tag(inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_LOOKUP_ID_HIGH:`INBD_HDR_PNP_RANGE_LOOKUP_ID_LOW]), //spyglass disable SelfDeterminedExpr-ML
              .req_pkt_fmt(inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FMT_HIGH:`INBD_HDR_PNP_RANGE_FMT_LOW]), //spyglass disable SelfDeterminedExpr-ML
              .req_pkt_type(inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TYPE_HIGH:`INBD_HDR_PNP_RANGE_TYPE_LOW]), //spyglass disable SelfDeterminedExpr-ML
              .dwnstrm_pkt_halt(i_dcp_inbd_halt_pnp),

              .dcmp_pkt_hv(i_dcp_inbd_hdr_hv),
              .dcmp_pkt_dv(i_dcp_inbd_hdr_dv),
              .dcmp_pkt_eot(i_dcp_inbd_hdr_eot),
              .dcmp_pkt_hdr(dcp_inbd_hdr_int),
              .dcmp_pkt_addr(i_dcp_inbd_hdr_addr),
              .dcmp_pkt_byte_en(i_dcp_inbd_hdr_byte_en),
              .dcmp_pkt_byte_len(i_dcp_inbd_hdr_byte_len),

              .dcmp_pkt_req_byte_len(i_dcp_inbd_hdr_req_byte_len),
              .dcmp_pkt_func_num(i_dcp_inbd_hdr_func),
              .dcmp_pkt_out_tag(i_dcp_inbd_hdr_mstr_id),
              .dcmp_pkt_ncbe(i_dcp_inbd_hdr_ncbe),
              .dcmp_pkt_last_tlp(i_dcp_inbd_hdr_last),
              .dcmp_pkt_req_byte_en(i_dcp_inbd_hdr_req_byte_en),
              .dcmp_pkt_low_addr(i_dcp_inbd_hdr_low_addr),
              .dcmp_pkt_np_tlp_issued(i_dcp_inbd_hdr_np_valid)
              ,.dcmp_addr_parerr(trgt1_addr_parerr)
              ,.dcmp_ad_ras_dp_err_log(trgt1_ad_ras_dp_err_log)
              ,.axi_bridge_ras_dp_err_inj_core_clk(axi_bridge_ras_dp_err_inj_core_clk)
              );

      assign i_dcp_inbd_data_pnp = {CC_CORE_DATA_BUS_WD{1'b0}};
      assign trgt1_data_parerr = 1'b0;
      assign trgt1_dt_ras_dp_err_log = ({{RAS_ERROR_LOG_WD{1'b0}},1'b0});

      end // else: !if(WR_NOT_RD_QUEUE)
   endgenerate

   always @ ( * ) begin : PROC_comb_assign
      i_dcp_inbd_hdr_pnp = {DC_INBD_HEADER_PNP_WD{1'b0}};
      i_dcp_inbd_hdr_pnp[DC_INBD_HEADER_PNP_1STG_WD-1:0] = dcp_inbd_hdr_int[DC_INBD_HEADER_PNP_1STG_WD-1:0];


      //Over-rides all decomposer changed header signals

      i_dcp_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_LOOKUP_ID_HIGH:`INBD_HDR_PNP_RANGE_LOOKUP_ID_LOW]           = i_dcp_inbd_hdr_mstr_id; //spyglass disable SelfDeterminedExpr-ML

      i_dcp_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_HV_HIGH:`INBD_HDR_PNP_RANGE_HV_LOW]                     = i_dcp_inbd_hdr_hv; //spyglass disable SelfDeterminedExpr-ML
      i_dcp_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DV_HIGH:`INBD_HDR_PNP_RANGE_DV_LOW]                     = i_dcp_inbd_hdr_dv; //spyglass disable SelfDeterminedExpr-ML
      i_dcp_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_EOT_HIGH:`INBD_HDR_PNP_RANGE_EOT_LOW]                   = i_dcp_inbd_hdr_eot; //spyglass disable SelfDeterminedExpr-ML
      i_dcp_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FIRST_BE_HIGH:`INBD_HDR_PNP_RANGE_FIRST_BE_LOW]         = i_dcp_inbd_hdr_byte_en[3:0]; //spyglass disable SelfDeterminedExpr-ML
      i_dcp_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_LAST_BE_HIGH:`INBD_HDR_PNP_RANGE_LAST_BE_LOW]           = i_dcp_inbd_hdr_byte_en[7:4]; //spyglass disable SelfDeterminedExpr-ML
      i_dcp_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_ADDR_HIGH:`INBD_HDR_PNP_RANGE_ADDR_LOW]                 = i_dcp_inbd_hdr_addr; //spyglass disable SelfDeterminedExpr-ML

      i_dcp_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DECMP_BECTRL_HIGH:`INBD_HDR_PNP_RANGE_DECMP_BECTRL_LOW] = i_dcp_inbd_hdr_req_byte_en; //spyglass disable SelfDeterminedExpr-ML

      i_dcp_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DECMP_LAST_HIGH:`INBD_HDR_PNP_RANGE_DECMP_LAST_LOW]     = i_dcp_inbd_hdr_last; //spyglass disable SelfDeterminedExpr-ML

      i_dcp_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DECMP_BELEN_HIGH:`INBD_HDR_PNP_RANGE_DECMP_BELEN_LOW]   = i_dcp_inbd_hdr_byte_len; //spyglass disable SelfDeterminedExpr-ML

      i_dcp_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_MCB_NP_VALID_HIGH:`INBD_HDR_PNP_RANGE_MCB_NP_VALID_LOW] = i_dcp_inbd_hdr_np_valid; //spyglass disable SelfDeterminedExpr-ML

   end

   //One tap delay to avoid asynchronous feedback loops with the decomposer logic
   delay_n_w_stalling
   
     #(
       // SMD: Self determined expression present in the design
       // SJ: This self determined expression is over integers where no overflow is possbile with used configuration values.
       // spyglass disable_block SelfDeterminedExpr-ML       
     .WD(
         DC_INBD_HEADER_PNP_WD +
         CC_CORE_DATA_BUS_WD +
         1 +
         LOW_ADDR_WD +
         REMOTE_MAX_RD_SIZE_PW +
         1
         ),
       // spyglass enable_block SelfDeterminedExpr-ML              
     .N(1),
     .CAN_STALL(1)
       )
   u_dly(
     .clk(clk),
     .rst_n(rstn),
     .stall(dcp_inbd_halt_pnp),
     .clear(1'b0),
     .din(
          {
           i_dcp_inbd_hdr_pnp,
           i_dcp_inbd_data_pnp,
           i_dcp_inbd_hdr_ncbe,
           i_dcp_inbd_hdr_low_addr,
           i_dcp_inbd_hdr_req_byte_len,
           i_dcp_inbd_hdr_last
           }
          ),
     .stallout(i_dcp_inbd_halt_pnp),
     .dout(
          {
           dcp_inbd_hdr_pnp,
           dcp_inbd_data_pnp,
           dcp_inbd_hdr_ncbe,
           dcp_inbd_hdr_low_addr,
           dcp_inbd_hdr_byte_len,
           dcp_inbd_hdr_last
           }
           )
         );


   assign dcp_inbd_hdr_lookupid = dcp_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_LOOKUP_ID_HIGH:`INBD_HDR_PNP_RANGE_LOOKUP_ID_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign dcp_inbd_hdr_mstr_id  = dcp_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_LOOKUP_ID_HIGH:`INBD_HDR_PNP_RANGE_LOOKUP_ID_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign dcp_inbd_hdr_func     = dcp_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FUNC_NUM_HIGH:`INBD_HDR_PNP_RANGE_FUNC_NUM_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign dcp_inbd_hdr_np_valid = dcp_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_MCB_NP_VALID_HIGH:`INBD_HDR_PNP_RANGE_MCB_NP_VALID_LOW]; //spyglass disable SelfDeterminedExpr-ML

   assign dcp_inbd_hdr_dma_type = dcp_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_REQ_DMA_HIGH:`INBD_HDR_PNP_RANGE_REQ_DMA_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign dcp_inbd_hdr_dma_chan = dcp_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_REQ_DMA_CHAN_HIGH:`INBD_HDR_PNP_RANGE_REQ_DMA_CHAN_LOW]; //spyglass disable SelfDeterminedExpr-ML


endmodule
