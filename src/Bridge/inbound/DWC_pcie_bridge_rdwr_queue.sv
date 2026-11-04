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
// ---    $DateTime: 2023/12/22 07:15:34 $
// ---    $Revision: #15 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/inbound/DWC_pcie_bridge_rdwr_queue.sv#15 $
// ---------------------------------------------------------------------------------------
// Module Description:
//
// ---------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"


 module DWC_pcie_bridge_rdwr_queue
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::RAS_ERROR_LOG_WD;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  #(
    parameter WR_NOT_RD_QUEUE              = 1'b1,
    parameter DC_INBD_HEADER_PNP_1STG_WD   = `DC_INBD_HEADER_PNP_1STG_WD,
    parameter DC_INBD_HEADER_PNP_WD        = `DC_INBD_HEADER_PNP_WD,
    parameter DC_INBD_MISCINFO_WD          = `DC_INBD_MISCINFO_WD,
    parameter MSTR_DATA_WD_GT_CORE_DATA_WD = `CC_MSTR_BUS_DATA_WIDTH > `CC_CORE_DATA_BUS_WD,
    parameter CORE_REQ_DATA_BUS_WD         = MSTR_DATA_WD_GT_CORE_DATA_WD ? `CC_MSTR_BUS_DATA_WIDTH : `CC_CORE_DATA_BUS_WD,
    parameter CX_RAS_RAM_PROT_RANGE        = `CX_RAS_RAM_PROT_RANGE,
    parameter IB_REQ_CDC_RAM_DP            = `CC_IB_RD_REQ_CDC_RAM_DP,
    parameter IB_REQ_CDC_RAM_ADDR_WD       = `CC_IB_RD_REQ_CDC_RAM_ADDR_WD,
    parameter IB_REQ_CDC_RAM_DATA_WD       = `CC_IB_RD_REQ_CDC_RAM_DATA_WD,
    parameter IB_REQ_CDC_RAM_DATA_WD_NOECC = `CC_IB_RD_REQ_CDC_RAM_DATA_WD_NOECC,
    parameter IB_REQ_CDC_RAM_RD_LATENCY    = `CC_IB_RD_REQ_CDC_RAM_RD_LATENCY,
    parameter CC_MRF_C2A_FIFO_SYNC_REGS    = 2, // double registered CDC
    parameter CC_MRF_A2C_FIFO_SYNC_REGS    = 2, // double registered CDC
    parameter CC_MRF_C2A_FIFO_HOLD_RD_ADDR = 1, //If the full flag is used the push interface will clobber the held read data.
    parameter CORE_ADDR_BUS_WD             = `CC_CORE_ADDR_BUS_WD,
    parameter REQ_NW                       = MSTR_DATA_WD_GT_CORE_DATA_WD ? `CC_MSTR_NW : `CX_NW,
    parameter CC_MSTR_BUS_DATA_WIDTH       = `CC_MSTR_BUS_DATA_WIDTH,
    parameter CC_MSTR_BUS_WSTRB_WIDTH      = `CC_MSTR_BUS_WSTRB_WIDTH,
    parameter CC_MSTR_BUS_ADDR_WIDTH       = `CC_MSTR_BUS_ADDR_WIDTH,
    parameter CC_MAX_MSTR_TAG_PW           = `CC_MAX_MSTR_TAG_PW,
    parameter CC_MSTR_BE_CTRL_WIDTH        = `CC_MSTR_BE_CTRL_WIDTH,
    parameter CC_MSTR_NW                   = `CC_MSTR_NW,
    parameter CC_MSTR_NUM_CONV_WD          = `CC_MSTR_NUM_CONV_WD,
    parameter CX_NW                        = `CX_NW,
    parameter CC_MSTR_MTU_PW               = `CC_MSTR_MTU_PW,
    parameter CORE_REQ_DATA_BUS_WSTRB_WD   = MSTR_DATA_WD_GT_CORE_DATA_WD ? `CC_MSTR_BUS_WSTRB_WIDTH : `CC_CORE_DATA_BUS_WSTRB_WD,
    parameter CX_NFUNC                     = `CX_NFUNC               ,
    parameter RADMX_TRGT1_REQ_HDR_WD       = `CC_RADMX_TRGT1_REQ_HDR_WD ,
    parameter CC_CORE_DATA_BUS_WD          = `CC_CORE_DATA_BUS_WD    ,
    parameter CX_NFUNC_WD                  = `CX_NFUNC_WD            ,
    parameter REMOTE_MAX_RD_SIZE_PW        = `CX_REMOTE_RD_REQ_SIZE_PW  ,
    parameter MSTR_ADDR_WD                 = `CC_MSTR_BUS_ADDR_WIDTH,
    parameter BE_CTRL_WD                   = `CC_MSTR_BE_CTRL_WIDTH,
    parameter ID_WD                        = `GMX_AXI_ID_WIDTH ,
    parameter CX_REMOTE_MAX_TAGS_WD        = `CX_REMOTE_MAX_TAGS_WD,
    parameter P_N_PRESP_STREAMS            = 1,
    parameter P_N_PRESP_STREAMS_WD         = 1,
    parameter DC_DMA_TYPE_WIDTH            = `DC_DMA_TYPE_WIDTH,
    parameter CC_NUM_DMA_CHAN_WIDTH        = `CC_NUM_DMA_MAX_CHAN_WIDTH,
    parameter RAS_DP_ID                    = 3,
    parameter RAM_RAS_DP_ID                = 0,
    // -------------------------------------------------------------------------------------
    // Parameters not modified by an instantiation parameter assignment
    // -------------------------------------------------------------------------------------
    parameter TP       = `TP
    )
   
                                  (
    input                                                  mstr_aclk, // Bridge Master Interface Clock
    input                                                  mstr_arstn, // Bridge Master Clock Reset

    input                                                  core_clk,
    input                                                  core_rstn,

    // ---------------------------------------------------------------------------
    // RAS.DP register interface
    // ---------------------------------------------------------------------------
    input                                                  cfg_rdwr_mrf_ras_recc_correct,
    output wire                                            rdwrq_mrf_ras_recc_corr_cnt_pulse,
    output wire                                            rdwrq_mrf_ras_recc_ucorr_cnt_pulse,
    output wire [IB_REQ_CDC_RAM_ADDR_WD-1:0]               rdwrq_mrf_ras_recc_cnt_addr,


    input [DC_INBD_HEADER_PNP_1STG_WD-1:0]                 inbd_hdr_pnp,
    input [63:0]                                           radm_trgt1_hdr_uppr_bytes,
    input [CC_CORE_DATA_BUS_WD-1:0]                        inbd_data_pnp,
    output wire                                            inbd_halt_pnp,

    output wire                                            trgt1_addr_parerr,
    output wire                                            trgt1_data_parerr,
    output ras_dp_err_log_t                                trgt1_dt_ras_dp_err_log,
    output ras_dp_err_log_t                                trgt1_ad_ras_dp_err_log,
    input  ras_dp_err_inj_t                                axi_bridge_ras_dp_err_inj_core_clk,
    input  ras_dp_err_inj_t                                core_clk_hp_mstr_ras_dp_err_inj,
    input  ras_dp_err_inj_t                                ras_dp_err_inj_mstr_aclk,
    output wire                                            mstr_req_addr_parerr,
    output wire                                            mstr_req_data_parerr,
    output ras_dp_err_log_t                                mrf_recc_cnt_ras_dp_err_log,
    output ras_dp_err_log_t                                mstr_req_ad_ras_dp_err_log,
    output ras_dp_err_log_t                                mstr_req_dt_ras_dp_err_log,
    //2pRAM interface

    output wire [IB_REQ_CDC_RAM_ADDR_WD-1:0]               rdwrq_c2a_ram_addra,
    output wire [IB_REQ_CDC_RAM_ADDR_WD-1:0]               rdwrq_c2a_ram_addrb,
    output wire                                            rdwrq_c2a_ram_wea,
    output wire                                            rdwrq_c2a_ram_enb,
    input [IB_REQ_CDC_RAM_DATA_WD-1:0]                     rdwrq_c2a_ram_doutb,
    output wire [IB_REQ_CDC_RAM_DATA_WD-1:0]               rdwrq_c2a_ram_dina,



    //Interface with the master completion buffer @ core_clk
    output wire                                            dcp_inbd_hdr_np_valid,
    output wire                                            dcp_inbd_hdr_ncbe,
    output wire [`DC_MCB_MAX_CPL_NUM_BYTES_WD-2:0]         dcp_inbd_hdr_low_addr,
    output wire [REMOTE_MAX_RD_SIZE_PW-1:0 ]               dcp_inbd_hdr_byte_len,
    output wire [CC_MAX_MSTR_TAG_PW-1:0]                   dcp_inbd_hdr_mstr_id,
    output wire [CX_REMOTE_MAX_TAGS_WD-1:0]                dcp_inbd_hdr_lookupid,
    output wire [CX_NFUNC_WD-1:0]                          dcp_inbd_hdr_func,
    output wire                                            dcp_inbd_hdr_last,
    output wire [DC_DMA_TYPE_WIDTH-1:0]                    dcp_inbd_hdr_dma_type,
    output wire [CC_NUM_DMA_CHAN_WIDTH-1:0]                dcp_inbd_hdr_dma_chan,
    output wire [DC_INBD_HEADER_PNP_WD-1:0]                dcp_inbd_hdr_pnp,
    input                                                  halt_dcp,

    //Interface with the master completion buffer @ mstr_aclk
    output wire                                            mrf_reqmcb_np_valid,
    output wire [CX_REMOTE_MAX_TAGS_WD-1:0]                mrf_reqmcb_mstrid,
    output wire                                            mrf_reqmcb_last,
    output                                                 mrf_reqmcb_atomic,
    input                                                  arbmcb_halt_mrf,

    // Interface with the AXI master
    // AMBA master request interface
    output wire [MSTR_ADDR_WD-1:0]                         maddr,
    output wire                                            mstrobe,
    output wire                                            mstrobe_last,
    output wire [CC_MSTR_MTU_PW -1:0]                      mlen,
    output wire [CC_MSTR_BUS_DATA_WIDTH-1:0]               mdata,
    output wire [CC_MSTR_BUS_WSTRB_WIDTH-1:0]              mbe,
    output wire [BE_CTRL_WD-1:0]                           mbe_ctrl,
    output wire [ID_WD-1 :0]                               mid,
    output wire                                            mabort,
    output wire                                            mlast,
    output wire [DC_INBD_MISCINFO_WD-1:0]                  mmisc,
    input                                                  saccept,

    input                                                  presp_cmplt,
    input [P_N_PRESP_STREAMS_WD-1:0]                       presp_stream,
    input [1:0]                                            presp_type
    );

   //Internal wires
   wire                                      inbd_hdr_np_halt;

   reg [DC_INBD_HEADER_PNP_WD-1:0]           s_dcp_inbd_hdr_pnp;
   wire                                      dcp_inbd_halt_pnp;
   wire [CC_CORE_DATA_BUS_WD-1:0]            dcp_inbd_data_pnp;

   wire [CC_CORE_DATA_BUS_WD-1:0]            dcp2mrf_inbd_data_pnp;

   wire                                      i_dcp_inbd_hdr_np_valid;
   logic [REMOTE_MAX_RD_SIZE_PW-1:0]         i_dcp_inbd_hdr_byte_len;

   reg [DC_INBD_HEADER_PNP_1STG_WD-1:0]      msi_inbd_hdr_pnp;
   reg [CC_CORE_DATA_BUS_WD-1:0]             msi_inbd_data_pnp;
   wire                                      msi_inbd_halt_pnp_wr;

   wire [DC_INBD_HEADER_PNP_1STG_WD-1:0]     ptrk_inbd_header_pnp_wr;
   wire [CC_CORE_DATA_BUS_WD-1:0]            ptrk_inbd_data_pnp_wr;
   wire [DC_INBD_HEADER_PNP_1STG_WD-1:0]     s1_inbd_hdr_pnp, ss_inbd_hdr_pnp;
   reg  [DC_INBD_HEADER_PNP_1STG_WD-1:0]     s_inbd_hdr_pnp;
   wire [CC_CORE_DATA_BUS_WD-1:0]            s_inbd_data_pnp, s1_inbd_data_pnp;

   wire [63:0]                               ptrk_hdr_uppr_bytes;
   wire [63:0]                               s_hdr_uppr_bytes;

   wire                                      msgh_inbd_halt_pnp_wr;


   generate
      if (WR_NOT_RD_QUEUE) begin : gen_wr_not_rd_queue_ordr


         assign inbd_halt_pnp     = msgh_inbd_halt_pnp_wr;
         assign ss_inbd_hdr_pnp   = inbd_hdr_pnp;
         assign s_hdr_uppr_bytes  = radm_trgt1_hdr_uppr_bytes;
         assign s_inbd_data_pnp   = inbd_data_pnp;


  // CRM_9001534832:
  //   Messages without data should have their Length field ignored
  wire [1:0] tlp_fmt              ;
  wire [4:0] tlp_type             ;
  wire       s_tlp_req_wo_data_len;

  assign tlp_fmt  = ss_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FMT_HIGH:`INBD_HDR_PNP_RANGE_FMT_LOW];
  assign tlp_type = ss_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TYPE_HIGH:`INBD_HDR_PNP_RANGE_TYPE_LOW];

  assign s_tlp_req_wo_data_len = ( ({tlp_fmt,tlp_type[4:3]} == `MSG_4    ) ||
                                   ({tlp_fmt,tlp_type[4:3]} == `MSG_AS_4 )   );

  always @( * ) begin : s_inbd_hdr_pnp_PROC
    s_inbd_hdr_pnp = ss_inbd_hdr_pnp;
    if(s_tlp_req_wo_data_len)
      s_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DW_LEN_HIGH:`INBD_HDR_PNP_RANGE_DW_LEN_LOW] = 10'b0;
  end

         /////////////////////////////////////////////////////////////////
         //----------------------------------------------------------------
         // MSG Handler block - manipulates the TLP if its Msg/MsgD and
         // translated by the iATU. Otherwise this block is bypassed
         //----------------------------------------------------------------

         DWC_pcie_bridge_ib_msg_hdlr
         

         u_msg_hdlr
           (
            .core_aclk          (core_clk),
            .core_rstn          (core_rstn),

            .inbd_hdr_pnp       (s_inbd_hdr_pnp),
            .inbd_data_pnp      (s_inbd_data_pnp),
            .msg_uppr_bytes     (s_hdr_uppr_bytes),
            .dwn_strm_pkt_halt  (msi_inbd_halt_pnp_wr),

            .inbd_hdr_pnp_mod   (s1_inbd_hdr_pnp),
            .inbd_data_pnp_mod  (s1_inbd_data_pnp),
            .inbd_halt_pnp_mod  (msgh_inbd_halt_pnp_wr)

            );
         // either halted by the Msg Handler or the Write req queue control



         /////////////////////////////////////////////////////////////////

         always @ (*) begin : comb_wr_inbd_assign
            msi_inbd_hdr_pnp  = s1_inbd_hdr_pnp;
            msi_inbd_data_pnp = s1_inbd_data_pnp;
         end


         assign msi_inbd_halt_pnp_wr   = inbd_hdr_np_halt;

      end else begin : gen_rd_not_wr_queue_ordr // block: gen_wr_not_rd_queue_ordr

         always @ (*) begin : comb_rd_inbd_assign
            msi_inbd_hdr_pnp = inbd_hdr_pnp;
            msi_inbd_data_pnp = inbd_data_pnp;
         end


         assign inbd_halt_pnp      = inbd_hdr_np_halt;

         assign s_inbd_data_pnp = {CC_CORE_DATA_BUS_WD{1'b0}};


      end
   endgenerate

   wire s_dcp_inbd_halt_pnp;

   // TLP Decomposition
   DWC_pcie_bridge_ibdecomp
   
     #(
       .DC_DMA_TYPE_WIDTH          (DC_DMA_TYPE_WIDTH         ),
       .CC_NUM_DMA_MAX_CHAN_WIDTH  (CC_NUM_DMA_CHAN_WIDTH     ),
       .WR_NOT_RD_QUEUE            (WR_NOT_RD_QUEUE           ),
       .CC_MAX_MSTR_TAG_PW         (CC_MAX_MSTR_TAG_PW        ),
       .CX_NW                      (CX_NW                     ),
       .CX_NFUNC                   (CX_NFUNC                  ),
       .RADMX_TRGT1_REQ_HDR_WD     (RADMX_TRGT1_REQ_HDR_WD    ),
       .CC_CORE_DATA_BUS_WD        (CC_CORE_DATA_BUS_WD       ),
       .CX_NFUNC_WD                (CX_NFUNC_WD               ),
       .CC_MSTR_BE_CTRL_WIDTH      (CC_MSTR_BE_CTRL_WIDTH     ),
       .REMOTE_MAX_RD_SIZE_PW      (REMOTE_MAX_RD_SIZE_PW     ),
       .DC_INBD_HEADER_PNP_1STG_WD (DC_INBD_HEADER_PNP_1STG_WD),
       .DC_INBD_HEADER_PNP_WD      (DC_INBD_HEADER_PNP_WD     ),
       .CX_REMOTE_MAX_TAGS_WD      (CC_MAX_MSTR_TAG_PW        ),
       .CC_MSTR_BUS_DATA_WIDTH     (CC_MSTR_BUS_DATA_WIDTH    )
       ) u_decrd
       (
        .clk                     (core_clk),
        .rstn                    (core_rstn),
        .inbd_hdr_pnp            (msi_inbd_hdr_pnp ),
        .inbd_data_pnp           (msi_inbd_data_pnp),
        .inbd_halt_pnp           (inbd_hdr_np_halt ),

        .trgt1_addr_parerr       (trgt1_addr_parerr     ),
        .trgt1_data_parerr       (trgt1_data_parerr     ),
        .trgt1_dt_ras_dp_err_log (trgt1_dt_ras_dp_err_log),
        .trgt1_ad_ras_dp_err_log (trgt1_ad_ras_dp_err_log),
        .axi_bridge_ras_dp_err_inj_core_clk (core_clk_hp_mstr_ras_dp_err_inj),

        .dcp_inbd_hdr_pnp        (dcp_inbd_hdr_pnp      ),
        .dcp_inbd_data_pnp       (dcp_inbd_data_pnp     ),
        .dcp_inbd_halt_pnp       (s_dcp_inbd_halt_pnp   ),
        .dcp_inbd_hdr_np_valid   (i_dcp_inbd_hdr_np_valid ),
        .dcp_inbd_hdr_ncbe       (dcp_inbd_hdr_ncbe     ),
        .dcp_inbd_hdr_low_addr   (dcp_inbd_hdr_low_addr ),
        .dcp_inbd_hdr_byte_len   (i_dcp_inbd_hdr_byte_len ),
        .dcp_inbd_hdr_mstr_id    (dcp_inbd_hdr_mstr_id  ),
        .dcp_inbd_hdr_lookupid   (dcp_inbd_hdr_lookupid ),
        .dcp_inbd_hdr_func       (dcp_inbd_hdr_func     ),
        .dcp_inbd_hdr_last       (dcp_inbd_hdr_last     )
        ,.dcp_inbd_hdr_dma_type  (dcp_inbd_hdr_dma_type ),
        .dcp_inbd_hdr_dma_chan   (dcp_inbd_hdr_dma_chan )
        );

   //Handling of halt generated by the master completion buffer
   //requesting interface
   assign s_dcp_inbd_halt_pnp = dcp_inbd_halt_pnp | halt_dcp;
   assign dcp_inbd_hdr_np_valid = dcp_inbd_halt_pnp ? 1'b0: i_dcp_inbd_hdr_np_valid;


  assign dcp_inbd_hdr_byte_len = ({dcp_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FMT_HIGH:`INBD_HDR_PNP_RANGE_FMT_LOW],dcp_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TYPE_HIGH:`INBD_HDR_PNP_RANGE_TYPE_LOW]} inside {7'b1001110,7'b1101110}) ? i_dcp_inbd_hdr_byte_len >> 1 : i_dcp_inbd_hdr_byte_len;

   always @ ( * ) begin : PROC_comb_halt
      s_dcp_inbd_hdr_pnp = dcp_inbd_hdr_pnp;
      if (halt_dcp) begin
         s_dcp_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_HV_HIGH:`INBD_HDR_PNP_RANGE_HV_LOW ]  = 1'b0;
         s_dcp_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DV_HIGH:`INBD_HDR_PNP_RANGE_DV_LOW ]  = 1'b0;
         s_dcp_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_EOT_HIGH:`INBD_HDR_PNP_RANGE_EOT_LOW] = 1'b0;
      end
   end

   generate
      if (WR_NOT_RD_QUEUE) begin : gen_wr_not_rd_queue_data
         assign dcp2mrf_inbd_data_pnp = dcp_inbd_data_pnp;
      end else begin : gen_wr_not_rd_queue_data_not
         assign dcp2mrf_inbd_data_pnp = {CC_CORE_DATA_BUS_WD{1'b0}}; //Not connected
      end
   endgenerate

   DWC_pcie_bridge_mrf
   
     #(
       .MRF_WR_NOT_RD_QUEUE               (WR_NOT_RD_QUEUE             ),
       .DC_INBD_HEADER_PNP_WD             (DC_INBD_HEADER_PNP_WD       ),
       .DC_INBD_MISCINFO_WD               (DC_INBD_MISCINFO_WD         ),
       .CX_RAS_RAM_PROT_RANGE             (CX_RAS_RAM_PROT_RANGE       ),
       .IB_REQ_CDC_RAM_DP                 (IB_REQ_CDC_RAM_DP           ),
       .IB_REQ_CDC_RAM_ADDR_WD            (IB_REQ_CDC_RAM_ADDR_WD      ),
       .IB_REQ_CDC_RAM_DATA_WD            (IB_REQ_CDC_RAM_DATA_WD      ),
       .IB_REQ_CDC_RAM_DATA_WD_NOECC      (IB_REQ_CDC_RAM_DATA_WD_NOECC),
       .IB_REQ_CDC_RAM_RD_LATENCY         (IB_REQ_CDC_RAM_RD_LATENCY   ),
       .CC_MRF_C2A_FIFO_SYNC_REGS         (CC_MRF_C2A_FIFO_SYNC_REGS   ),
       .CC_MRF_A2C_FIFO_SYNC_REGS         (CC_MRF_A2C_FIFO_SYNC_REGS   ),
       .CC_MRF_C2A_FIFO_HOLD_RD_ADDR      (CC_MRF_C2A_FIFO_HOLD_RD_ADDR),
       .MSTR_DATA_WD_GT_CORE_DATA_WD      (MSTR_DATA_WD_GT_CORE_DATA_WD),
       .CORE_REQ_DATA_BUS_WD              (CORE_REQ_DATA_BUS_WD        ),
       .REQ_NW                            (REQ_NW                      ),
       .CC_MSTR_BUS_DATA_WIDTH            (CC_MSTR_BUS_DATA_WIDTH      ),
       .CC_MSTR_BUS_WSTRB_WIDTH           (CC_MSTR_BUS_WSTRB_WIDTH     ),
       .CC_MSTR_BUS_ADDR_WIDTH            (CC_MSTR_BUS_ADDR_WIDTH      ),
       .CC_MAX_MSTR_TAG_PW                (CX_REMOTE_MAX_TAGS_WD       ),
       .CC_MSTR_BE_CTRL_WIDTH             (CC_MSTR_BE_CTRL_WIDTH       ),
       .CC_MSTR_NW                        (CC_MSTR_NW                  ),
       .CC_MSTR_NUM_CONV_WD               (CC_MSTR_NUM_CONV_WD         ),
       .CX_NW                             (CX_NW                       ),
       .CC_MSTR_MTU_PW                    (CC_MSTR_MTU_PW              ),
       .RAS_DP_ID                         (RAS_DP_ID                   ),
       .RAM_RAS_DP_ID                     (RAM_RAS_DP_ID               ),
       .CORE_REQ_DATA_BUS_WSTRB_WD        (CORE_REQ_DATA_BUS_WSTRB_WD  )
       ) u_mrf
       (
        .mstr_aclk             (mstr_aclk),
        .mstr_arstn            (mstr_arstn),
        .core_clk              (core_clk),
        .core_rstn             (core_rstn),
        .mrf_c2a_ram_addra     (rdwrq_c2a_ram_addra),
        .mrf_c2a_ram_addrb     (rdwrq_c2a_ram_addrb),
        .mrf_c2a_ram_wea       (rdwrq_c2a_ram_wea  ),
        .mrf_c2a_ram_enb       (rdwrq_c2a_ram_enb  ),
        .mrf_c2a_ram_doutb     (rdwrq_c2a_ram_doutb),
        .mrf_c2a_ram_dina      (rdwrq_c2a_ram_dina ),
        .cfg_ras_correct              (cfg_rdwr_mrf_ras_recc_correct),
        .mrf_ras_recc_corr_cnt_pulse  (rdwrq_mrf_ras_recc_corr_cnt_pulse),
        .mrf_ras_recc_ucorr_cnt_pulse (rdwrq_mrf_ras_recc_ucorr_cnt_pulse),
        .mrf_ras_recc_cnt_addr        (rdwrq_mrf_ras_recc_cnt_addr),
        .mstr_req_addr_parerr  (mstr_req_addr_parerr),
        .mstr_req_data_parerr  (mstr_req_data_parerr),
        .mrf_recc_cnt_ras_dp_err_log  (mrf_recc_cnt_ras_dp_err_log),
        .mstr_req_ad_ras_dp_err_log(mstr_req_ad_ras_dp_err_log),
        .mstr_req_dt_ras_dp_err_log (mstr_req_dt_ras_dp_err_log),
        .axi_bridge_ras_dp_err_inj_core_clk (axi_bridge_ras_dp_err_inj_core_clk),
        .ras_dp_err_inj_mstr_aclk           (ras_dp_err_inj_mstr_aclk),

        // Input TLP interface
        .inbd_hdr_pnp          (s_dcp_inbd_hdr_pnp),
        .inbd_data_pnp         (dcp2mrf_inbd_data_pnp),
        .inbd_halt_pnp         (dcp_inbd_halt_pnp),

        //MCB request interface
        .mrf_reqmcb_np_valid   (mrf_reqmcb_np_valid),
        .mrf_reqmcb_mstrid     (mrf_reqmcb_mstrid  ),
        .mrf_reqmcb_last       (mrf_reqmcb_last    ),
        .mrf_reqmcb_atomic     (mrf_reqmcb_atomic),
        .arbmcb_halt_mrf       (arbmcb_halt_mrf    ),

        .maddr                 (maddr   ),
        .mstrobe               (mstrobe ),
        .mstrobe_last          (mstrobe_last),
        .mlen                  (mlen    ),
        .mdata                 (mdata   ),
        .mbe                   (mbe     ),
        .mbe_ctrl              (mbe_ctrl),
        .mid                   (mid     ),
        .mabort                (mabort  ),
        .mlast                 (mlast   ),
        .mmisc                 (mmisc   ),
        .saccept               (saccept )
        );
`ifndef SYNTHESIS
   //--------------------------------------------------------------------
   // RAS.DP Testbench guides for error injection
   //--------------------------------------------------------------------

  `define IB_RD_REQ_ORDR_RAM_AD_PTR `INBD_HDR_PNP_RANGE_ADDR_LOW
  `define IB_RD_REQ_ORDR_RAM_AD_PTRW `FLT_Q_ADDR_WIDTH
  `define IB_RD_REQ_CDC_RAM_AD_PTR  `INBD_HDR_PNP_RANGE_ADDR_LOW
  `define IB_RD_REQ_CDC_RAM_AD_PTRW `FLT_Q_ADDR_WIDTH
  `define IB_WR_REQ_CDC_RAM_DT_PTR 0
  `define IB_WR_REQ_CDC_RAM_DT_PTRW ((`MASTER_BUS_DATA_WIDTH > `PCIE_CORE_DATA_BUS_WD) ? `MASTER_BUS_DATA_WIDTH : `PCIE_CORE_DATA_BUS_WD)
  `define IB_WR_REQ_CDC_RAM_AD_PTR `IB_WR_REQ_CDC_RAM_DT_PTRW + `INBD_HDR_PNP_RANGE_ADDR_LOW
  `define IB_WR_REQ_CDC_RAM_AD_PTRW `FLT_Q_ADDR_WIDTH

`endif //  `ifndef SYNTHESIS


endmodule
