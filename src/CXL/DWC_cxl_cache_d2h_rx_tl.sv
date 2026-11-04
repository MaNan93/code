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
// ---   $Revision: #7 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_cache_d2h_rx_tl.sv#7 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// CXL Reciever Transaction Layer - Cache Host - D2H
//  Expected default sizes are:
//  D2H Request(4), Response(2), Data Header(4), Data(1) Message signals
// Data Path
//  Req : cxl_ch_dltl_d2h_req[(D2H_REQ_NUM-1):0]
//        -> DWC_cxl_rx_tl_queue_fifo_interface (USAGE=0)
//        -> cxl_mst_d2h_req[(D2H_REQ_IFNUM-1):0]
//  Resp: cxl_ch_dltl_d2h_resp[(D2H_RESP_NUM-1):0]
//        -> DWC_cxl_rx_tl_queue_fifo_interface (USAGE=0)
//        -> cxl_mst_d2h_resp[(D2H_RESP_IFNUM-1):0]
//  Data: cxl_ch_dltl_d2h_dhr[(D2H_DDATA_NUM-1):0]
//        -> DWC_cxl_rx_tl_queue_fifo_interface (USAGE=2)
//        -> cxl_mst_d2h_data[(D2H_DATA_IFNUM-1):0]
//        {cxl_dltl_d2h_data,       -> Registered
//         cxl_dltl_d2h_data_valid,
//         cxl_dltl_d2h_byte_en,
//         cxl_dltl_d2h_byte_en_valid}
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

`include "CXL/svif/DWC_cxl_clk_rst_if.svh"
`include "CXL/svif/DWC_cxl_ram2p_if.svh"

module DWC_cxl_cache_d2h_rx_tl
  import DWC_cxl_pkg::*;
  #(
    parameter  TP               = `TP,
    parameter  D2H_REQ_RAM_NUM  = HRSP_DREQ_NUM,
    parameter  D2H_RESP_RAM_NUM = HREQ_DRSP_NUM
  ) (
    DWC_cxl_clk_rst_if.slave_mp                    b_clk
  , input  logic                                   toggle_flag_cxl_clk
  , input  logic                                   cxl_rx_vlsm_req_flush
  //  Interface with DWC_cxl_mst_link_ctrl - Cache - s_cxl_clk domain
  , output logic                                   cxl_rx_tl_cache_d2h_pending
  , output logic                                   cxl_mst_rx_tl_d2h_req_ovflw
  , output logic                                   cxl_mst_rx_tl_d2h_rsp_ovflw
  , output logic                                   cxl_mst_rx_tl_d2h_data_ovflw
  , input  logic                                   cxl_rx_tl_cache_d2h_ch_msg_halt
  , input  logic                                   cxl_rx_tl_cache_d2h_nullify_crd
  , input  logic                                   cxl_rx_tl_cache_d2h_run_crd_cnt
  //  Interface with Link layer for communicating TL layer credit release
  //  - s_core_clk domain
  , output logic [(D2H_REQ_NUM-1):0]               cxl_rx_tl_cache_d2h_req_valid
  , output logic [(D2H_RESP_NUM-1):0]              cxl_rx_tl_cache_d2h_rsp_valid
  , output logic [(D2H_DDATA_NUM-1):0]             cxl_rx_tl_cache_d2h_data_valid
  //  Interface with RX Application Layer   - synchronous to s_cxl_clk
  //  D2H Request(2), Response(1), Data(1) Message signals
  , output logic [(D2H_REQ_IFNUM-1):0][(D2H_REQ_RX_CH_SIZE-1):0]   cxl_mst_d2h_req
  , output logic [(D2H_RESP_IFNUM-1):0][(D2H_RESP_RX_CH_SIZE-1):0] cxl_mst_d2h_resp
  , output logic [(D2H_DATA_IFNUM-1):0][(D2H_DATA_RX_CH_SIZE-1):0] cxl_mst_d2h_data
  //  D2H Credit signals per Message
  , input  logic [(D2H_REQ_IFNUM-1):0]             cxl_mst_d2h_req_crd
  , input  logic [(D2H_RESP_IFNUM-1):0]            cxl_mst_d2h_resp_crd
  , input  logic                                   cxl_mst_d2h_data_crd
  //  Interface with RX DATA Link Layer - synchronous to s_core_clk
  //  RX Data Link layer CRC Error signal
  //  - Needed for delayed msg invalidation - timing optimization
  , input  logic                                   cxl_dltl_d2h_crc_err
  //  D2H Request(4), Response(2), Data Header(4), Data Byte en(1), Data(1)
  //  Message signals
  , input  logic [(D2H_REQ_NUM-1):0][(D2H_REQ_RX_CH_SIZE-1):0]     cxl_ch_dltl_d2h_req
  , input  logic [(D2H_RESP_NUM-1):0][(D2H_RESP_RX_CH_SIZE-1):0]   cxl_ch_dltl_d2h_resp
  , input  logic [(D2H_DDATA_NUM-1):0][(D2H_DHDR_RX_CH_SIZE-1):0]  cxl_ch_dltl_d2h_dhr
  , input  logic [(D2H_DDATA_NUM-1):0][(D2H_DDATA_RX_CH_SIZE-1):0] cxl_dltl_d2h_data
  , input  logic [(D2H_DDATA_NUM-1):0][(D2H_DBE_RX_CH_SIZE-1):0]   cxl_dltl_d2h_byte_en
  , input  logic [(D2H_DDATA_NUM-1):0]                             cxl_dltl_d2h_data_valid
  , input  logic [(D2H_DDATA_NUM-1):0]                             cxl_dltl_d2h_byte_en_valid
  //  Expecting 2 power based no of instances(1/2/4).
  //  Address width and depth are calculated based on the no of RAM instances
  //  D2H Request RAM Interface(4)
  , DWC_cxl_ram2p_if.master_mp                     b_d2h_req_ram[(D2H_REQ_RAM_NUM-1):0]
  //  D2H Response RAM Interface(2)
  , DWC_cxl_ram2p_if.master_mp                     b_d2h_resp_ram[(D2H_RESP_RAM_NUM-1):0]
  //  D2H Response DATA Interface
  , DWC_cxl_ram2p_if.master_mp                     b_d2h_data_ram[(D2H_DDATA_NUM-1):0]
  );

  //============================================================================
  //  Declarations and common logic
  //============================================================================
  //  Pending indication

  logic                                           d2h_req_mapper_pending;
  logic                                           d2h_resp_mapper_pending;
  logic                                           d2h_data_fifo_pending;
  logic                                           d2h_dhr_mapper_pending;
  logic                                           d2h_ddata_mapper_pending;
assign d2h_dhr_mapper_pending ='0;
assign d2h_ddata_mapper_pending ='0;


  //  D2H pending calculation based on inputs from each of its stages to
  //  control Master link control low power FSM state.
  assign cxl_rx_tl_cache_d2h_pending = (d2h_req_mapper_pending
                                      | d2h_resp_mapper_pending
                                      | d2h_data_fifo_pending
                                       );

  // Overflow indication
  logic [($clog2(D2H_REQ_RAM_NUM)+1):0]           d2h_req_fifo_net_crd;
  logic signed [CACHE_REQ_CRD_WD:0]               cxl_mst_rx_tl_d2h_req_rxbuf_crd_cnt;

  logic [($clog2(D2H_RESP_RAM_NUM)+1):0]          d2h_resp_fifo_net_crd;
  logic signed [CACHE_RSP_CRD_WD:0]               cxl_mst_rx_tl_d2h_rsp_rxbuf_crd_cnt;

  logic [($clog2(D2H_DDATA_NUM)+1):0]             d2h_data_fifo_net_crd;
  logic signed [CACHE_DATA_CRD_WD:0]              cxl_mst_rx_tl_d2h_data_rxbuf_crd_cnt;


  always_ff @(posedge b_clk.s_core_clk or negedge b_clk.s_core_rst_n) begin
    if (!b_clk.s_core_rst_n) begin
         cxl_mst_rx_tl_d2h_req_rxbuf_crd_cnt  <= #TP '0;
         cxl_mst_rx_tl_d2h_rsp_rxbuf_crd_cnt  <= #TP '0;
         cxl_mst_rx_tl_d2h_data_rxbuf_crd_cnt <= #TP '0;
      end
      else begin
         cxl_mst_rx_tl_d2h_req_rxbuf_crd_cnt  <=
           #TP (CACHE_REQ_CRD_WD+1)'(cxl_mst_rx_tl_d2h_req_rxbuf_crd_cnt   + signed'(d2h_req_fifo_net_crd));
         cxl_mst_rx_tl_d2h_rsp_rxbuf_crd_cnt  <=
           #TP (CACHE_RSP_CRD_WD+1)'(cxl_mst_rx_tl_d2h_rsp_rxbuf_crd_cnt   + signed'(d2h_resp_fifo_net_crd));
         cxl_mst_rx_tl_d2h_data_rxbuf_crd_cnt <=
           #TP (CACHE_DATA_CRD_WD+1)'(cxl_mst_rx_tl_d2h_data_rxbuf_crd_cnt  + signed'(d2h_data_fifo_net_crd));
      end
  end

  assign cxl_mst_rx_tl_d2h_req_ovflw  =
          (cxl_mst_rx_tl_d2h_req_rxbuf_crd_cnt > {1'b1,{CACHE_REQ_CRD_WD{1'b0}}});

  assign cxl_mst_rx_tl_d2h_rsp_ovflw  =
          (cxl_mst_rx_tl_d2h_rsp_rxbuf_crd_cnt > {1'b1,{CACHE_RSP_CRD_WD{1'b0}}});

  assign cxl_mst_rx_tl_d2h_data_ovflw =
          (cxl_mst_rx_tl_d2h_data_rxbuf_crd_cnt > {1'b1,{CACHE_DATA_CRD_WD{1'b0}}});


  //============================================================================
  //  D2H REQ Mapper Stage. Inputs=D2H_REQ_NUM (expected to be 4).
  //  The total depth of FIFO is CACHE_REQ_CEIL2_DP.
  //  Thus depth of each individual FIFO is divided by D2H_REQ_RAM_NUM internally.
  //============================================================================
  DWC_cxl_rx_tl_queue_fifo_interface
   #(
      .USAGE           (0)
    , .CHNLS           (D2H_REQ_NUM)
    , .DW              (D2H_REQ_RX_CH_SIZE)
    , .FIFO_DEPTH      (CACHE_REQ_CEIL2_DP)
    , .FIFO_ADDR_WIDTH (CACHE_REQ_CRD_WD)
    , .FIFO_INTERFACE  (D2H_REQ_RAM_NUM)
    , .AL_IFNUM        (D2H_REQ_IFNUM)
    ) U_DWC_cxl_rx_tl_d2h_req(
    //  Inputs
      .b_clk                   (b_clk)
    , .data_in                 (cxl_ch_dltl_d2h_req)
    , .crc_err                 (cxl_dltl_d2h_crc_err)
    , .fifo_push               ('1)
    , .AL_crd                  (cxl_mst_d2h_req_crd)
    , .ch_msg_halt             (cxl_rx_tl_cache_d2h_ch_msg_halt)
    , .nullify_crd_cnt         (cxl_rx_tl_cache_d2h_nullify_crd)
    , .run_crd_cnt             (cxl_rx_tl_cache_d2h_run_crd_cnt)
    , .toggle_flag             (toggle_flag_cxl_clk)
    , .fst_wrptr_count         ('0)
    , .fst_chnl_pending        ('0)
    , .fst_chnl_rd_cnt         ('0)
    , .read_aux_ptr            ('0)
    , .read_aux_ptr_en         ('0)
    //  Outputs
    , .q_map_wrptr_cnt_vld     ()
    , .q_fifo_pending          (d2h_req_mapper_pending)
    , .fifo_pending            ()
    , .fifo_net_crd            (d2h_req_fifo_net_crd)
    , .b_ram                   (b_d2h_req_ram)
    , .cxl_rx_tl_valid         (cxl_rx_tl_cache_d2h_req_valid)
    , .stored_aux_ptr          ()
    , .stored_aux_ptr_ctrl_en  ()
    , .rdptr_count             ()
    , .r_map_data              (cxl_mst_d2h_req)
    , .ptr_err                 ()
    );


  //============================================================================
  //  D2H RESP Mapper Stage. Inputs=D2H_RESP_NUM (expected to be 2).
  //  The total depth of FIFO is CACHE_RSPQ_CEIL2_DP.
  //  Thus depth of each individual FIFO is divided by D2H_RESP_RAM_NUM internally.
  //============================================================================
  DWC_cxl_rx_tl_queue_fifo_interface
   #(
      .USAGE           (0)
    , .CHNLS           (D2H_RESP_NUM)
    , .DW              (D2H_RESP_RX_CH_SIZE)
    , .FIFO_DEPTH      (CACHE_RSPQ_CEIL2_DP)
    , .FIFO_ADDR_WIDTH (CACHE_RSP_CRD_WD)
    , .FIFO_INTERFACE  (D2H_RESP_RAM_NUM)
    , .AL_IFNUM        (D2H_RESP_IFNUM)
    ) U_DWC_cxl_rx_tl_d2h_resp(
    //  Inputs
      .b_clk                   (b_clk)
    , .data_in                 (cxl_ch_dltl_d2h_resp)
    , .crc_err                 (cxl_dltl_d2h_crc_err)
    , .fifo_push               ('1)
    , .AL_crd                  (cxl_mst_d2h_resp_crd)
    , .ch_msg_halt             (cxl_rx_tl_cache_d2h_ch_msg_halt)
    , .nullify_crd_cnt         (cxl_rx_tl_cache_d2h_nullify_crd)
    , .run_crd_cnt             (cxl_rx_tl_cache_d2h_run_crd_cnt)
    , .toggle_flag             (toggle_flag_cxl_clk)
    , .fst_wrptr_count         ('0)
    , .fst_chnl_pending        ('0)
    , .fst_chnl_rd_cnt         ('0)
    , .read_aux_ptr            ('0)
    , .read_aux_ptr_en         ('0)
    //  Outputs
    , .q_map_wrptr_cnt_vld     ()
    , .q_fifo_pending          (d2h_resp_mapper_pending)
    , .fifo_pending            ()
    , .fifo_net_crd            (d2h_resp_fifo_net_crd)
    , .b_ram                   (b_d2h_resp_ram)
    , .cxl_rx_tl_valid         (cxl_rx_tl_cache_d2h_rsp_valid)
    , .stored_aux_ptr          ()
    , .stored_aux_ptr_ctrl_en  ()
    , .rdptr_count             ()
    , .r_map_data              (cxl_mst_d2h_resp)
    , .ptr_err                 ()
    );

  //============================================================================
  //  - D2H Data Mapper Stage. Inputs=D2H_DATA_NUM (expected to be 4).
  //  - The total depth of FIFO is CACHE_DQ_CEIL2_DP.
  //  - Data Header Queue Mapper Will Be Bypassed(USAGE=2) as it is Moved To Link 
  //    Layer for Supporting Late Poison Feature as poison Bit Should be Asserted 
  //    Before RAS Protection. 
  //============================================================================

  logic [(D2H_DDATA_NUM-1):0][(D2H_DATA_RX_CH_SIZE-1):0]  d2h_data_fifo_data_in;

  always_comb begin
    for(int i=0; i<D2H_DDATA_NUM; i=i+1) begin
      d2h_data_fifo_data_in[i] =  {
                cxl_dltl_d2h_data[i][D2H_DDATA_RX_CH_SIZE-1:D2H_DDATA_SIZE]
              , cxl_dltl_d2h_byte_en[i][D2H_DBE_RX_CH_SIZE-1:D2H_DBE_SIZE]
              , cxl_ch_dltl_d2h_dhr[i][D2H_DHDR_RX_CH_SIZE-1:D2H_DHDR_SIZE]
              ,                cxl_dltl_d2h_data[i][D2H_DDATA_SIZE-1:0]
              , cxl_dltl_d2h_byte_en[i][D2H_DBE_SIZE-1:0]
              , cxl_ch_dltl_d2h_dhr[i][D2H_DHDR_SIZE-1:0]
                                  };
    end
  end

  DWC_cxl_rx_tl_queue_fifo_interface
   #(
      .USAGE           ( ((D2H_DDATA_NUM==1)? 2:0) )
    , .CHNLS           ( D2H_DDATA_NUM             )
    , .DW              ( D2H_DATA_RX_CH_SIZE       )
    , .FIFO_DEPTH      ( CACHE_DQ_CEIL2_DP         )
    , .FIFO_ADDR_WIDTH ( CACHE_DATA_CRD_WD         )
    , .AL_IFNUM        ( D2H_DATA_IFNUM            )
    ) U_DWC_cxl_rx_tl_d2h_data(
    //  Inputs
      .b_clk                   (b_clk)
    , .data_in                 (d2h_data_fifo_data_in)
    , .crc_err                 ('0)
    , .fifo_push               (cxl_dltl_d2h_byte_en_valid & cxl_dltl_d2h_data_valid)
    , .AL_crd                  (cxl_mst_d2h_data_crd)
    , .ch_msg_halt             (cxl_rx_tl_cache_d2h_ch_msg_halt)
    , .nullify_crd_cnt         (cxl_rx_tl_cache_d2h_nullify_crd)
    , .run_crd_cnt             (cxl_rx_tl_cache_d2h_run_crd_cnt)
    , .toggle_flag             (toggle_flag_cxl_clk)
    , .fst_wrptr_count         ('0)
    , .fst_chnl_pending        ('0)
    , .fst_chnl_rd_cnt         ('0)
    , .read_aux_ptr            ('0)
    , .read_aux_ptr_en         ('0)
    //  Outputs
    , .q_map_wrptr_cnt_vld     ()
    , .q_fifo_pending          (d2h_data_fifo_pending)
    , .fifo_pending            ()
    , .fifo_net_crd            (d2h_data_fifo_net_crd)
    , .b_ram                   (b_d2h_data_ram)
    , .cxl_rx_tl_valid         (cxl_rx_tl_cache_d2h_data_valid)
    , .stored_aux_ptr          ()
    , .stored_aux_ptr_ctrl_en  ()
    , .rdptr_count             ()
    , .r_map_data              (cxl_mst_d2h_data)
    , .ptr_err                 ()
    );

endmodule
