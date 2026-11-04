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
// --- RCS information:
// ---   $DateTime: 2023/07/13 12:43:15 $
// ---   $Revision: #8 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_cache_h2d_rx_tl.sv#8 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// CXL Reciever Transaction Layer - Cache Device - H2D
//  Expected default sizes are:
//  H2D Request(2), Response(4), Data Header(4), Data(1) Message signals
// Data Path
//  Req : cxl_ch_dltl_h2d_req[(H2D_REQ_NUM-1):0]
//        -> DWC_cxl_rx_tl_queue_mapper (USAGE=0)
//        -> DWC_cxl_rx_tl_fifoctrl
//        -> DWC_cxl_rx_tl_interface_mapper
//        -> cxl_mst_h2d_req[(H2D_REQ_IFNUM-1):0]
//  Resp: cxl_ch_dltl_h2d_resp[(H2D_RESP_NUM-1):0]
//        -> DWC_cxl_rx_tl_queue_fifo_interface (USAGE=0)
//        -> cxl_mst_h2d_resp[(H2D_RESP_IFNUM-1):0]
//  Data: cxl_ch_dltl_h2d_dhr[(H2D_DDATA_NUM-1):0]
//        -> DWC_cxl_rx_tl_queue_fifo_interface (USAGE=2)
//        -> cxl_mst_h2d_data[(H2D_DATA_IFNUM-1):0]
//        {cxl_dltl_h2d_data,       -> Registered
//         cxl_dltl_h2d_data_valid}
// order management between req and resp
//  Req :
//        -> h2d_resp_wrptr_count(combo, order requirement)
//        -> h2d_resp_rdptr_count(order requirement)
//        -> h2d_resp_aux_ptr(order requirement)
//        -> h2d_resp_aux_ptr_ctrl_en(order requirement)
//        -> h2d_resp_fifo_pending(order requirement)
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

`include "CXL/svif/DWC_cxl_clk_rst_if.svh"
`include "CXL/svif/DWC_cxl_ram2p_if.svh"

module DWC_cxl_cache_h2d_rx_tl
  import DWC_cxl_pkg::*;
  #(
    parameter   TP                = `TP,
    parameter   H2D_REQ_RAM_NUM   = HREQ_DRSP_NUM,
    parameter   H2D_RESP_RAM_NUM  = HRSP_DREQ_NUM
  ) (
    DWC_cxl_clk_rst_if.slave_mp                   b_clk
  , input  logic                                  toggle_flag_cxl_clk
  , input  logic                                  cxl_rx_vlsm_req_flush
  //  Interface with DWC_cxl_mst_link_ctrl - Cache - s_cxl_clk domain
  , output logic                                  cxl_rx_tl_cache_h2d_pending
  , output logic                                  cxl_mst_rx_tl_h2d_req_ovflw
  , output logic                                  cxl_mst_rx_tl_h2d_rsp_ovflw
  , output logic                                  cxl_mst_rx_tl_h2d_data_ovflw
  , input  logic                                  cxl_rx_tl_cache_h2d_ch_msg_halt
  , input  logic                                  cxl_rx_tl_cache_h2d_nullify_crd
  , input  logic                                  cxl_rx_tl_cache_h2d_run_crd_cnt
  //  Interface with Link layer for communicating TL layer credit release - s_core_clk domain
  , output logic [(H2D_REQ_NUM-1):0]              cxl_rx_tl_cache_h2d_req_valid
  , output logic [(H2D_RESP_NUM-1):0]             cxl_rx_tl_cache_h2d_rsp_valid
  , output logic [(H2D_DDATA_NUM-1):0]            cxl_rx_tl_cache_h2d_data_valid
  //  Interface with RX Application Layer   - synchronous to s_cxl_clk
  //  H2D Request(1), Response(2), Data(1) Message signals
  , output logic [(H2D_REQ_IFNUM-1):0][(H2D_REQ_RX_CH_SIZE-1):0]   cxl_mst_h2d_req
  , output logic [(H2D_RESP_IFNUM-1):0][(H2D_RESP_RX_CH_SIZE-1):0] cxl_mst_h2d_resp
  , output logic [(H2D_DATA_IFNUM-1):0][(H2D_DATA_RX_CH_SIZE-1):0] cxl_mst_h2d_data
  //  H2D Credit signals per Message
  , input  logic [(H2D_REQ_IFNUM-1):0]            cxl_mst_h2d_req_crd
  , input  logic [(H2D_RESP_IFNUM-1):0]           cxl_mst_h2d_resp_crd
  , input  logic [(H2D_DATA_IFNUM-1):0]           cxl_mst_h2d_data_crd
  //  Interface with RX DATA Link Layer - synchronous to s_core_clk
  //  RX Data Link layer CRC Error signal - Needed for delayed msg invalidation - timing optimization
  , input  logic                                  cxl_dltl_h2d_crc_err
  //  H2D Request(2), Response(4), Data Header(4), Data(1) Message signals
  , input  logic [(H2D_REQ_NUM-1):0][(H2D_REQ_RX_CH_SIZE-1):0]      cxl_ch_dltl_h2d_req
  , input  logic [(H2D_RESP_NUM-1):0][(H2D_RESP_RX_CH_SIZE-1):0]    cxl_ch_dltl_h2d_resp
  , input  logic [(H2D_DDATA_NUM-1):0][(H2D_DHDR_RX_CH_SIZE-1):0]   cxl_ch_dltl_h2d_dhr
  , input  logic [(H2D_DDATA_NUM-1):0][(H2D_DDATA_RX_CH_SIZE-1): 0] cxl_dltl_h2d_data
  , input  logic [(H2D_DDATA_NUM-1):0]                              cxl_dltl_h2d_data_valid
  , output logic                                                    cxl_mst_h2d_req_fifo_data_out_ptr_err
  //  Expecting 2 power based no of instances(1/2/4).
  //  Address width and depth are calculated based on the no of RAM instances
  //  H2D Request RAM Interface(2)
  //  H2D Rdata, Wdata width is calculated to accomodate the write pointer of the H2D Response (H2D_RESP_PTR_SIZE)
  , DWC_cxl_ram2p_if.master_mp                     b_h2d_req_ram[(H2D_REQ_RAM_NUM-1):0]
  //  H2D Response RAM Interface(4)
  , DWC_cxl_ram2p_if.master_mp                     b_h2d_resp_ram[(H2D_RESP_RAM_NUM-1):0]
  //  H2D DATA RAM Interface(1)
  , DWC_cxl_ram2p_if.master_mp                     b_h2d_data_ram[(H2D_DDATA_NUM-1):0]
  );

  //============================================================================
  //  Declarations and common logic
  //============================================================================
  //  Pending indication
  logic                                           h2d_req_mapper_pending;
  logic                                           h2d_resp_mapper_pending;
  logic                                           h2d_data_fifo_pending;
  logic                                           h2d_dhr_mapper_pending;
assign h2d_dhr_mapper_pending ='0;

  //  H2D pending calculation based on inputs from each of its stages to
  //  control Master link control low power FSM state.
  assign cxl_rx_tl_cache_h2d_pending = (h2d_req_mapper_pending
                                      | h2d_data_fifo_pending
                                      | h2d_resp_mapper_pending
                                      );
  //  Overflow indication
  logic [($clog2(H2D_REQ_RAM_NUM)+1):0]           h2d_req_fifo_net_crd;
  logic signed [CACHE_REQ_CRD_WD:0]               cxl_mst_rx_tl_h2d_req_rxbuf_crd_cnt;

  logic [($clog2(H2D_RESP_RAM_NUM)+1):0]          h2d_resp_fifo_net_crd;
  logic signed [CACHE_RSP_CRD_WD:0]               cxl_mst_rx_tl_h2d_rsp_rxbuf_crd_cnt;

  logic [($clog2(H2D_DDATA_NUM)+1):0]             h2d_data_fifo_net_crd;
  logic signed [CACHE_DATA_CRD_WD:0]              cxl_mst_rx_tl_h2d_data_rxbuf_crd_cnt;

  always_ff @(posedge b_clk.s_core_clk or negedge b_clk.s_core_rst_n) begin
    if (!b_clk.s_core_rst_n) begin
         cxl_mst_rx_tl_h2d_req_rxbuf_crd_cnt  <= #TP '0;
         cxl_mst_rx_tl_h2d_rsp_rxbuf_crd_cnt  <= #TP '0;
         cxl_mst_rx_tl_h2d_data_rxbuf_crd_cnt <= #TP '0;
      end
      else begin
         cxl_mst_rx_tl_h2d_req_rxbuf_crd_cnt  <=
           #TP (CACHE_REQ_CRD_WD+1)'(cxl_mst_rx_tl_h2d_req_rxbuf_crd_cnt   + signed'(h2d_req_fifo_net_crd));
         cxl_mst_rx_tl_h2d_rsp_rxbuf_crd_cnt  <=
           #TP (CACHE_RSP_CRD_WD+1)'(cxl_mst_rx_tl_h2d_rsp_rxbuf_crd_cnt   + signed'(h2d_resp_fifo_net_crd));
         cxl_mst_rx_tl_h2d_data_rxbuf_crd_cnt <=
           #TP (CACHE_DATA_CRD_WD+1)'(cxl_mst_rx_tl_h2d_data_rxbuf_crd_cnt  + signed'(h2d_data_fifo_net_crd));
      end
  end

  assign cxl_mst_rx_tl_h2d_req_ovflw  =
          (cxl_mst_rx_tl_h2d_req_rxbuf_crd_cnt > {1'b1,{CACHE_REQ_CRD_WD{1'b0}}});

  assign cxl_mst_rx_tl_h2d_rsp_ovflw  =
          (cxl_mst_rx_tl_h2d_rsp_rxbuf_crd_cnt > {1'b1,{CACHE_RSP_CRD_WD{1'b0}}});

  assign cxl_mst_rx_tl_h2d_data_ovflw =
          (cxl_mst_rx_tl_h2d_data_rxbuf_crd_cnt > {1'b1,{CACHE_DATA_CRD_WD{1'b0}}});

  //  The following signals transfer information between the request mapper
  //  and the response mapper to allow for ordering requirements.

  //  h2d_resp_wrptr_count is a counter tracking total no of H2D Response
  //  messages already written into all H2D Response FIFO's plus the sum of
  //  valid bits of data available at the input of the Input Mapper.
  logic [(H2D_RESP_PTR_SIZE-1):0]                 h2d_resp_wrptr_count;

  //  h2d_resp_rdptr_count is a counter to track total no of H2D Response
  //  messages already sent towards application layer across all channels
  logic [(H2D_RESP_PTR_SIZE-1):0]                 h2d_resp_rdptr_count;

  logic [(H2D_RESP_PTR_SIZE-1):0]                 h2d_resp_aux_ptr;
  logic                                           h2d_resp_aux_ptr_ctrl_en;

  logic [(H2D_RESP_RAM_NUM-1):0]                  h2d_resp_fifo_pending;

  //============================================================================
  //  H2D REQ Mapper Stage. Inputs=H2D_REQ_NUM (expected to be 2).
  //  The total depth of FIFO is CACHE_REQ_CEIL2_DP.
  //  Thus depth of each individual FIFO is divided by H2D_REQ_RAM_NUM internally.
  //============================================================================
  DWC_cxl_rx_tl_queue_fifo_interface
   #(
      .USAGE           (0)
    , .CHNLS           (H2D_REQ_NUM)
    , .WR_PTR_WD       (H2D_RESP_PTR_SIZE)
    , .DW              (H2D_REQ_RX_CH_SIZE)
    , .ICW             (H2D_RESP_PTR_SIZE)
    , .FIFO_DEPTH      (CACHE_REQ_CEIL2_DP)
    , .FIFO_ADDR_WIDTH (CACHE_REQ_CRD_WD)
    , .FIFO_INTERFACE  (H2D_REQ_RAM_NUM)
    , .AL_IFNUM        (H2D_REQ_IFNUM)
    , .ORD             (2)
    , .F_DW            (H2D_REQ_RAM_DATAW)
    , .I_DW            (H2D_REQ_RAM_DATAW-H2D_RESP_PTR_DP_SIZE)
    ) U_DWC_cxl_rx_tl_h2d_req(
    //  Inputs
      .b_clk                   (b_clk)
    , .data_in                 (cxl_ch_dltl_h2d_req)
    , .crc_err                 (cxl_dltl_h2d_crc_err)
    , .fifo_push               ('1)
    , .AL_crd                  (cxl_mst_h2d_req_crd)
    , .ch_msg_halt             (cxl_rx_tl_cache_h2d_ch_msg_halt)
    , .nullify_crd_cnt         (cxl_rx_tl_cache_h2d_nullify_crd)
    , .run_crd_cnt             (cxl_rx_tl_cache_h2d_run_crd_cnt)
    , .toggle_flag             (toggle_flag_cxl_clk)
    , .fst_wrptr_count         (h2d_resp_wrptr_count)
    , .fst_chnl_pending        (|h2d_resp_fifo_pending) // OR all pending responses
    , .fst_chnl_rd_cnt         (h2d_resp_rdptr_count)
    , .read_aux_ptr            ('0)
    , .read_aux_ptr_en         ('0)
    //  Outputs
    , .q_map_wrptr_cnt_vld     ()
    , .q_fifo_pending          (h2d_req_mapper_pending)
    , .fifo_pending            ()
    , .fifo_net_crd            (h2d_req_fifo_net_crd)
    , .b_ram                   (b_h2d_req_ram)
    , .cxl_rx_tl_valid         (cxl_rx_tl_cache_h2d_req_valid)
    , .stored_aux_ptr          (h2d_resp_aux_ptr)
    , .stored_aux_ptr_ctrl_en  (h2d_resp_aux_ptr_ctrl_en)
    , .rdptr_count             ()
    , .r_map_data              (cxl_mst_h2d_req)
    , .ptr_err                 (cxl_mst_h2d_req_fifo_data_out_ptr_err)
    );

  //============================================================================
  //  H2D Response Mapper Stage. Inputs=H2D_RESP_NUM (expected to be 4).
  //  The total depth of FIFO is CACHE_RSPQ_CEIL2_DP.
  //  Thus depth of each individual FIFO is divided by H2D_RESP_RAM_NUM internally.
  //============================================================================
  DWC_cxl_rx_tl_queue_fifo_interface
   #(
      .USAGE           (0)
    , .CHNLS           (H2D_RESP_NUM)
    , .WR_PTR_WD       (H2D_RESP_PTR_SIZE)
    , .DW              (H2D_RESP_RX_CH_SIZE)
    , .OCW             (H2D_RESP_PTR_SIZE)
    , .FIFO_DEPTH      (CACHE_RSPQ_CEIL2_DP)
    , .FIFO_ADDR_WIDTH (CACHE_RSP_CRD_WD)
    , .FIFO_INTERFACE  (H2D_RESP_RAM_NUM)
    , .AL_IFNUM        (H2D_RESP_IFNUM)
    , .ORD             (1)
    ) U_DWC_cxl_rx_tl_h2d_resp(
    //  Inputs
      .b_clk                   (b_clk)
    , .data_in                 (cxl_ch_dltl_h2d_resp)
    , .crc_err                 (cxl_dltl_h2d_crc_err)
    , .fifo_push               ('1)
    , .AL_crd                  (cxl_mst_h2d_resp_crd)
    , .ch_msg_halt             (cxl_rx_tl_cache_h2d_ch_msg_halt)
    , .nullify_crd_cnt         (cxl_rx_tl_cache_h2d_nullify_crd)
    , .run_crd_cnt             (cxl_rx_tl_cache_h2d_run_crd_cnt)
    , .toggle_flag             (toggle_flag_cxl_clk)
    , .fst_wrptr_count         ('0)
    , .fst_chnl_pending        ('0)
    , .fst_chnl_rd_cnt         ('0)
    , .read_aux_ptr            (h2d_resp_aux_ptr)
    , .read_aux_ptr_en         (h2d_resp_aux_ptr_ctrl_en)
    //  Outputs
    , .q_map_wrptr_cnt_vld     (h2d_resp_wrptr_count)
    , .q_fifo_pending          (h2d_resp_mapper_pending)
    , .fifo_pending            (h2d_resp_fifo_pending)
    , .fifo_net_crd            (h2d_resp_fifo_net_crd)
    , .b_ram                   (b_h2d_resp_ram)
    , .cxl_rx_tl_valid         (cxl_rx_tl_cache_h2d_rsp_valid)
    , .stored_aux_ptr          ()
    , .stored_aux_ptr_ctrl_en  ()
    , .rdptr_count             (h2d_resp_rdptr_count)
    , .r_map_data              (cxl_mst_h2d_resp)
    , .ptr_err                 ()
    );

  //============================================================================
  //  - H2D Data Mapper Stage. Inputs=H2D_DATA_NUM (expected to be 4).
  //  - The total depth of FIFO is CACHE_DQ_CEIL2_DP.
  //  - Data Header Queue Mapper Will Be Bypassed(USAGE=2) as it is Moved To Link 
  //    Layer for Supporting Late Poison Feature as poison Bit Should be Asserted
  //    Before RAS Protection. 
  //============================================================================

  logic [(H2D_DDATA_NUM-1):0][(H2D_DATA_RX_CH_SIZE-1):0]  h2d_data_fifo_data_in;

  always_comb begin
    for(int i=0; i<H2D_DDATA_NUM; i=i+1) begin
      h2d_data_fifo_data_in[i] =  {
                cxl_dltl_h2d_data[i][H2D_DDATA_RX_CH_SIZE-1:H2D_DDATA_SIZE]
              , cxl_ch_dltl_h2d_dhr[i][H2D_DHDR_RX_CH_SIZE-1:H2D_DHDR_SIZE]
              ,                cxl_dltl_h2d_data[i][H2D_DDATA_SIZE-1:0]
              , cxl_ch_dltl_h2d_dhr[i][H2D_DHDR_SIZE-1:0]
                                  };
    end
  end

  DWC_cxl_rx_tl_queue_fifo_interface
   #(
      .USAGE           ( ((H2D_DDATA_NUM==1)? 2:0) )
    , .CHNLS           ( H2D_DDATA_NUM             )
    , .DW              ( H2D_DATA_RX_CH_SIZE       )
    , .FIFO_DEPTH      ( CACHE_DQ_CEIL2_DP         )
    , .FIFO_ADDR_WIDTH ( CACHE_DATA_CRD_WD         )
    , .AL_IFNUM        ( H2D_DATA_IFNUM            )
    ) U_DWC_cxl_rx_tl_h2d_data(
    //  Inputs
      .b_clk                   (b_clk)
    , .data_in                 (h2d_data_fifo_data_in)
    , .crc_err                 ('0)
    , .fifo_push               (cxl_dltl_h2d_data_valid)
    , .AL_crd                  (cxl_mst_h2d_data_crd)
    , .ch_msg_halt             (cxl_rx_tl_cache_h2d_ch_msg_halt)
    , .nullify_crd_cnt         (cxl_rx_tl_cache_h2d_nullify_crd)
    , .run_crd_cnt             (cxl_rx_tl_cache_h2d_run_crd_cnt)
    , .toggle_flag             (toggle_flag_cxl_clk)
    , .fst_wrptr_count         ('0)
    , .fst_chnl_pending        ('0)
    , .fst_chnl_rd_cnt         ('0)
    , .read_aux_ptr            ('0)
    , .read_aux_ptr_en         ('0)
    //  Outputs
    , .q_map_wrptr_cnt_vld     ()
    , .q_fifo_pending          (h2d_data_fifo_pending)
    , .fifo_pending            ()
    , .fifo_net_crd            (h2d_data_fifo_net_crd)
    , .b_ram                   (b_h2d_data_ram)
    , .cxl_rx_tl_valid         (cxl_rx_tl_cache_h2d_data_valid)
    , .stored_aux_ptr          ()
    , .stored_aux_ptr_ctrl_en  ()
    , .rdptr_count             ()
    , .r_map_data              (cxl_mst_h2d_data)
    , .ptr_err                 ()
    );

endmodule
