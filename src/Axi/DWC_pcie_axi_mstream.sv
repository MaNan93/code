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
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Axi/DWC_pcie_axi_mstream.sv#5 $
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Axi/DWC_pcie_axi_xali_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

module DWC_pcie_axi_mstream
  import DWC_pcie_axi_xali_pkg::*;
  import DWC_pcie_ctl_pkg::N_XADM_P_IF;
  #(
  parameter                         NVC = `CX_NVC,
  parameter         CC_SLV_BUS_ID_WIDTH = `CC_SLV_BUS_ID_WIDTH,
  parameter            DC_CPL_STATUS_WD = `DC_CPL_STATUS_WD,
  parameter SLV_MSTREAM_P_ORDR_QUEUE_DP = `CC_SLV_MSTREAM_P_ORDR_QUEUE_DP,
  parameter            CORE_DATA_BUS_WD = `CC_CORE_DATA_BUS_WD,
  parameter       PCIE_CORE_DATA_BUS_WD = `PCIE_CORE_DATA_BUS_WD,
  parameter                 ADDR_PAR_WD = `CX_ADDR_PAR_WD,
  parameter           CX_RAS_PROT_RANGE = `CX_RAS_PROT_RANGE,
  parameter                          TP = `TP
  ) (
  input logic                            core_clk,
  input logic                            core_rst_n,
  input  logic                           slv_aclk,
  input  logic                           slv_aresetn,
  input  axi_xali_client0_s              axi_client0_s,
  input  axi_xali_client1_s              axi_client1_s,
  input  axi_xali_client2_s              axi_client2_s,

  output axi_xali_exp_client0_s          exp_client0_s,
  output axi_xali_exp_client1_s          exp_client1_s,
  output axi_xali_exp_client2_s          exp_client2_s,

  input  logic [NVC-1:0]                 xadm_client0_halt,
  input  logic [NVC-1:0]                 xadm_client1_halt,
  input  logic [NVC-1:0]                 xadm_client2_halt,

  input  vc_map_s                        cfg_tc_struc_vc_map,
  input [N_XADM_P_IF-1:0]                xali_posted_tlp_sent,

  output logic                           axi_client0_halt,
  output logic                           axi_client1_halt,
  output logic                           axi_client2_halt,

  // Responses interface
  input logic                            pdcmp_p_rsp_valid,          // TLP Posted request issued
  input logic                            pdcmp_p_rsp_null_or_err,    // Null request or request with error
  input logic                            pdcmp_p_rsp_last,           // Last TLP request of a decomposed request issued
  input logic [2:0]                      pdcmp_p_rsp_vc_num,         // VC Number
  input logic [CC_SLV_BUS_ID_WIDTH-1:0]  pdcmp_p_rsp_id,             // Request ID
  input logic [DC_CPL_STATUS_WD-1:0]     pdcmp_p_rsp_cpl_stat,       // Completion Status
  output logic                           mstream_p_rsp_valid,
  output logic [CC_SLV_BUS_ID_WIDTH-1:0] mstream_p_rsp_id,           // Request ID
  output logic [DC_CPL_STATUS_WD-1:0]    mstream_p_rsp_cpl_stat     // Completion Status
  );


  // --------------------------------------------------------------------
  // Local parameters declaration
  // --------------------------------------------------------------------
  localparam XALI_EXP_CLIENT0_WD           = $bits(axi_xali_client0_s);
  localparam XALI_EXP_CLIENT1_WD           = $bits(axi_xali_client1_s);
  localparam XALI_EXP_CLIENT2_WD           = $bits(axi_xali_client2_s);

  localparam POSTED_WR_RESP_INTF           = `CC_SLV_BUS_ID_WIDTH+3;
  localparam C2APRSP_FIFO_DEPTH            = `CC_SLV_NUM_OUTSTND_WR_REQ;
  localparam C2APRSP_FIFO_ADDR_WD          = `CC_SLV_NUM_OUTSTND_WR_REQ_LOG2;
  localparam C2APRSP_PUSH_AF_LVL           = 1; // one from full
  localparam C2APRSP_POP_AE_LVL            = 1; // one from empty
  localparam C2APRSP_RST_MODE              = 0; // Include memory reset
  localparam C2APRSP_PUSH_AE_LVL           = 1;
  localparam C2APRSP_POP_AF_LVL            = 1;
  localparam C2APRSP_PUSH_SYNC             = `CX_PCIE_SYNC_DEPTH;
  localparam C2APRSP_POP_SYNC              = `CX_PCIE_SYNC_DEPTH;
  localparam C2APRSP_HOLD_RD_ADDR          = 0;
  // Sticky error flag
  localparam C2APRSP_ERR_MODE              = 1'b0;


  // --------------------------------------------------------------------
  // Signals declaration
  // --------------------------------------------------------------------
  axi_xali_client0_s                   xadm_client0_vc0_s;
  axi_xali_client0_s                   xadm_client0_vc1_s;
  axi_xali_client0_s                   xadm_client0_vc7_s;
  axi_xali_client0_s                   xadm_client0_vc6_s;
  axi_xali_client0_s                   xadm_client0_vc5_s;
  axi_xali_client0_s                   xadm_client0_vc4_s;
  axi_xali_client0_s                   xadm_client0_vc3_s;
  axi_xali_client0_s                   xadm_client0_vc2_s;

  axi_xali_client1_s                   xadm_client1_vc0_s;
  axi_xali_client1_s                   xadm_client1_vc1_s;
  axi_xali_client1_s                   xadm_client1_vc7_s;
  axi_xali_client1_s                   xadm_client1_vc6_s;
  axi_xali_client1_s                   xadm_client1_vc5_s;
  axi_xali_client1_s                   xadm_client1_vc4_s;
  axi_xali_client1_s                   xadm_client1_vc3_s;
  axi_xali_client1_s                   xadm_client1_vc2_s;

  axi_xali_client2_s                   xadm_client2_vc0_s;
  axi_xali_client2_s                   xadm_client2_vc1_s;
  axi_xali_client2_s                   xadm_client2_vc7_s;
  axi_xali_client2_s                   xadm_client2_vc6_s;
  axi_xali_client2_s                   xadm_client2_vc5_s;
  axi_xali_client2_s                   xadm_client2_vc4_s;
  axi_xali_client2_s                   xadm_client2_vc3_s;
  axi_xali_client2_s                   xadm_client2_vc2_s;

  logic                                s_c2aprsp_push_req_n;
  logic [POSTED_WR_RESP_INTF-1:0]      s_c2aprsp_push_data;
  logic                                c2aprsp_push_af_nc;
  logic                                c2aprsp_push_full_nc;
  logic                                c2aprsp_pop_empty;
  logic [POSTED_WR_RESP_INTF-1:0]      c2aprsp_pop_data;

  logic                                s_mstream_p_rsp_valid;
  logic [CC_SLV_BUS_ID_WIDTH-1:0]      s_mstream_p_rsp_id;
  logic [DC_CPL_STATUS_WD-1:0]         s_mstream_p_rsp_cpl_stat;
  logic                                s_mstream_halt, ss_mstream_halt, mstream_halt;
  logic                                r_client2_multi_beat;

  axi_xali_client0_s                   s_axi_client0_s;
  axi_xali_client1_s                   s_axi_client1_s;
  axi_xali_client2_s                   s_axi_client2_s, ss_axi_client2_s;
  logic                                s_axi_client2_valid;

  logic                                s_axi_client0_halt, s_axi_client0_ready;
  logic                                s_axi_client1_halt, s_axi_client1_ready;
  logic                                s_axi_client2_halt, s_axi_client2_ready;

  logic                                s_client0_valid;
  logic                                s_client1_valid;
  logic                                s_client2_valid;

       


  // --------------------------------------------------------------------
  // Module design
  // --------------------------------------------------------------------

  assign s_client0_valid = axi_client0_s.tlp_hv ||  axi_client0_s.tlp_dv;

  // --------------------------------------------------------------------
  // Pipeline stage for Client 0
  // --------------------------------------------------------------------
  DWC_pcie_axi_rs
  
  #(
    .P_FEED_READY      (1'b0                 )
   ,.CHAN_WD           (XALI_EXP_CLIENT0_WD  )
  ) u_xali_client0_rs (
      .clk             (core_clk             )
     ,.rstn            (core_rst_n           )
     ,.clrn            (1'b1                 )
     ,.vld_from_src    (s_client0_valid      )
     ,.chanl_from_src  (axi_client0_s        )
     ,.rdy_from_dest   (!s_axi_client0_halt  )
     ,.vld_to_dest     (                     )
     ,.chanl_to_dest   (s_axi_client0_s      )
     ,.rdy_to_src      (s_axi_client0_ready  )
  );

  assign axi_client0_halt = !s_axi_client0_ready;

  assign xadm_client0_vc0_s = s_axi_client0_s;
  assign s_axi_client0_halt = xadm_client0_halt;


  assign s_client1_valid = axi_client1_s.tlp_hv ||  axi_client1_s.tlp_dv;

  // --------------------------------------------------------------------
  // Pipeline stage for Client 1
  // --------------------------------------------------------------------
  DWC_pcie_axi_rs
  
  #(
    .P_FEED_READY     (1'b0                 )
   ,.CHAN_WD          (XALI_EXP_CLIENT1_WD  )
  ) u_xali_client1_rs (
      .clk            (core_clk             )
     ,.rstn           (core_rst_n           )
     ,.clrn           (1'b1                 )
     ,.vld_from_src   (s_client1_valid      )
     ,.chanl_from_src (axi_client1_s        )
     ,.rdy_from_dest  (!s_axi_client1_halt  )
     ,.vld_to_dest    (                     )
     ,.chanl_to_dest  (s_axi_client1_s      )
     ,.rdy_to_src     (s_axi_client1_ready    )
  );

  assign axi_client1_halt = !s_axi_client1_ready;

  assign xadm_client1_vc0_s = s_axi_client1_s;
  assign s_axi_client1_halt = xadm_client1_halt;


  //
  // Client 2 halt management to P Decomposer
  // Multistream P-Ordering module asserts halt whenever P management queue gets full, which may happen
  // the first cycle of a transfer, that is, upon HV signal.
  // This logic prevents from halting P Decomposer in the middle of a TLP transfer.
  //
  always_ff @(posedge core_clk or negedge core_rst_n) begin

    if (!core_rst_n) begin : proc_seq_rsp_counter
      r_client2_multi_beat  <= #TP 1'b0;
    end else begin
      if (axi_client2_s.tlp_hv && !axi_client2_s.tlp_eot && !axi_client2_halt) begin 
        r_client2_multi_beat  <= #TP 1'b1;
      end else if (axi_client2_s.tlp_eot && !axi_client2_halt) begin
        r_client2_multi_beat  <= #TP 1'b0;
      end 
    end
  end

  assign s_mstream_halt = r_client2_multi_beat ? 1'b0 : mstream_halt;
  assign s_client2_valid = (axi_client2_s.tlp_hv ||  axi_client2_s.tlp_dv) && ~axi_client2_halt;

  // --------------------------------------------------------------------
  // Pipeline stage for Client 2
  // --------------------------------------------------------------------
  DWC_pcie_axi_rs
  
  #(
    .P_FEED_READY     (1'b0                             )
   ,.CHAN_WD          (XALI_EXP_CLIENT2_WD            )
  ) u_xali_client2_rs (
      .clk            (core_clk                         )
     ,.rstn           (core_rst_n                       )
     ,.clrn           (1'b1                             )
     ,.vld_from_src   (s_client2_valid                  )
     ,.chanl_from_src (axi_client2_s                    )
     ,.rdy_from_dest  (!s_axi_client2_halt              )
     ,.vld_to_dest    ( s_axi_client2_valid             )
     ,.chanl_to_dest  (s_axi_client2_s                  )
     ,.rdy_to_src     (s_axi_client2_ready              )
  );

  assign axi_client2_halt = !s_axi_client2_ready || s_mstream_halt;

  //
  // Gate hv when data coming out of rs is not valid.
  //
  always_comb begin
    ss_axi_client2_s = s_axi_client2_s;
    if ( ~s_axi_client2_valid ) begin
       ss_axi_client2_s.tlp_hv = 1'b0;
       ss_axi_client2_s.tlp_dv = 1'b0;
       ss_axi_client2_s.tlp_eot = 1'b0;
    end
  end

    assign xadm_client2_vc0_s = ss_axi_client2_s;
    assign s_axi_client2_halt = xadm_client2_halt;


  DWC_pcie_axi_mstream_arch_p_ordr
   #(
    .NVC                        (NVC                           ),
    .CC_SLV_BUS_ID_WIDTH        (CC_SLV_BUS_ID_WIDTH           ),
    .DC_CPL_STATUS_WD           (DC_CPL_STATUS_WD              ),
    .SLV_MSTREAM_P_ORDR_QUEUE_DP(SLV_MSTREAM_P_ORDR_QUEUE_DP   )
  ) u_ms_p_ordr (
    .core_clk                   (core_clk                      ),
    .core_rst_n                 (core_rst_n                    ),
    .xali_posted_tlp_sent       (xali_posted_tlp_sent          ),
    .pdcmp_p_rsp_valid          (pdcmp_p_rsp_valid             ),
    .pdcmp_p_rsp_null_or_err    (pdcmp_p_rsp_null_or_err       ),
    .pdcmp_p_rsp_last           (pdcmp_p_rsp_last              ),
    .pdcmp_p_rsp_vc_num         (pdcmp_p_rsp_vc_num            ),
    .pdcmp_p_rsp_id             (pdcmp_p_rsp_id                ),
    .pdcmp_p_rsp_cpl_stat       (pdcmp_p_rsp_cpl_stat          ),
    .mstream_halt               (mstream_halt                  ),
    .mstream_p_rsp_valid        (s_mstream_p_rsp_valid         ),
    .mstream_p_rsp_id           (s_mstream_p_rsp_id            ),
    .mstream_p_rsp_cpl_stat     (s_mstream_p_rsp_cpl_stat      )
  );


  // Push ID to CDC FIFO
  assign s_c2aprsp_push_req_n = !s_mstream_p_rsp_valid;
  assign s_c2aprsp_push_data  =  { s_mstream_p_rsp_cpl_stat,s_mstream_p_rsp_id};

  // Instantiate FIFO controller + flip-flop based memory
  // By design the FIFO never overflows
  DWC_pcie_amba_cdc_fifo_dff
  
  #(.WIDTH                             (POSTED_WR_RESP_INTF)
   ,.DEPTH                             (C2APRSP_FIFO_DEPTH)
   ,.ADDR_WIDTH                        (C2APRSP_FIFO_ADDR_WD)
   ,.COUNT_WIDTH                       (C2APRSP_FIFO_ADDR_WD+1)
   ,.PUSH_AE_LVL                       (C2APRSP_PUSH_AE_LVL)
   ,.PUSH_AF_LVL                       (C2APRSP_PUSH_AF_LVL)
   ,.POP_AE_LVL                        (C2APRSP_POP_AE_LVL)
   ,.POP_AF_LVL                        (C2APRSP_POP_AF_LVL)
   ,.ERR_MODE                          (C2APRSP_ERR_MODE)
   ,.PUSH_SYNC                         (C2APRSP_PUSH_SYNC)
   ,.POP_SYNC                          (C2APRSP_POP_SYNC)
   ,.RST_MODE                          (C2APRSP_RST_MODE)
   ,.HOLD_RD_ADDR                      (C2APRSP_HOLD_RD_ADDR)
  )
  u_c2aprsp
  (.clk_push                          (core_clk)
  ,.rst_push_n                        (core_rst_n)
  ,.clk_pop                           (slv_aclk)
  ,.rst_pop_n                         (slv_aresetn)
  // Master P request info push interface
  ,.push_req_n                        (s_c2aprsp_push_req_n)
  ,.push_data                         (s_c2aprsp_push_data)
  ,.push_af                           (c2aprsp_push_af_nc)
  ,.push_full                         (c2aprsp_push_full_nc)
  ,.push_word_count                   (/*UNCONNECTED*/)
  // Master P request info pop interface
  ,.pop_req_n                         (c2aprsp_pop_empty)
  ,.pop_empty                         (c2aprsp_pop_empty)
  ,.pop_data                          (c2aprsp_pop_data)
  ,.halt                              (1'b0)
  );

  assign mstream_p_rsp_valid                       = !c2aprsp_pop_empty;
  assign { mstream_p_rsp_cpl_stat,mstream_p_rsp_id} =  c2aprsp_pop_data;


//DTIM STREAM INTERFACE - CDC FIFO from core_clk to mstr_aclk


  // --------------------------------------------------------------------
  // XALI 0 Bus Expansion
  // --------------------------------------------------------------------
  assign exp_client0_s.tlp_hv = {
      xadm_client0_vc0_s.tlp_hv
      };

  assign exp_client0_s.tlp_dv = {
      xadm_client0_vc0_s.tlp_dv
      };

  assign exp_client0_s.tlp_eot = {
      xadm_client0_vc0_s.tlp_eot
      };

  assign exp_client0_s.tlp_fmt = {
      xadm_client0_vc0_s.tlp_fmt
      };

  assign exp_client0_s.tlp_type = {
      xadm_client0_vc0_s.tlp_type
      };

  assign exp_client0_s.tlp_td = {
      xadm_client0_vc0_s.tlp_td
      };

  assign exp_client0_s.tlp_ep = {
      xadm_client0_vc0_s.tlp_ep
      };

  assign exp_client0_s.tlp_attr = {
      xadm_client0_vc0_s.tlp_attr
      };

  assign exp_client0_s.tlp_bad_eot = {
      xadm_client0_vc0_s.tlp_bad_eot
      };

  assign exp_client0_s.addr_align_en = {
      xadm_client0_vc0_s.addr_align_en
      };

  assign exp_client0_s.tlp_func_num = {
      xadm_client0_vc0_s.tlp_func_num
      };

  assign exp_client0_s.cpl_cmpltr_id = {
      xadm_client0_vc0_s.cpl_cmpltr_id
      };

  assign exp_client0_s.cpl_status = {
      xadm_client0_vc0_s.cpl_status
      };

  assign exp_client0_s.cpl_bcm = {
      xadm_client0_vc0_s.cpl_bcm
      };

  assign exp_client0_s.cpl_byte_cnt = {
      xadm_client0_vc0_s.cpl_byte_cnt
      };

  assign exp_client0_s.cpl_last = {
      xadm_client0_vc0_s.cpl_last
      };

  assign exp_client0_s.tlp_ats = {
      xadm_client0_vc0_s.tlp_ats
      };

  assign exp_client0_s.tlp_nw = {
      xadm_client0_vc0_s.tlp_nw
      };

  assign exp_client0_s.tlp_tid = {
      xadm_client0_vc0_s.tlp_tid
      };

  assign exp_client0_s.tlp_byte_len = {
      xadm_client0_vc0_s.tlp_byte_len
      };

  assign exp_client0_s.tlp_addr = {
      swap_addr_par(xadm_client0_vc0_s.tlp_addr)
      };

  assign exp_client0_s.tlp_addr_par = {
      swap_addr_par_only(xadm_client0_vc0_s.tlp_addr)
      };


  assign exp_client0_s.tlp_byte_en = {
      xadm_client0_vc0_s.tlp_byte_en
      };

  assign exp_client0_s.tlp_tc = {
      xadm_client0_vc0_s.tlp_tc
      };

  assign exp_client0_s.tlp_data = {
      swap_data_par(xadm_client0_vc0_s.tlp_data)
      };

  assign exp_client0_s.cpl_lookup_id = {
      xadm_client0_vc0_s.cpl_lookup_id
      };



  assign exp_client0_s.tlp_atu_bypass = {
      xadm_client0_vc0_s.tlp_atu_bypass
      };

  assign exp_client0_s.tlp_dma = {
      xadm_client0_vc0_s.tlp_dma
      };

  assign exp_client0_s.tlp_dma_channel = {
      xadm_client0_vc0_s.tlp_dma_channel
      };

  assign exp_client0_s.tlp_prv_dma = {
      xadm_client0_vc0_s.tlp_prv_dma
      };

  assign exp_client0_s.tlp_prv_dma_chan = {
      xadm_client0_vc0_s.tlp_prv_dma_chan
      };

  assign exp_client0_s.tlp_th = {
      xadm_client0_vc0_s.tlp_th
      };

  assign exp_client0_s.tlp_ph = {
      xadm_client0_vc0_s.tlp_ph
      };

  assign exp_client0_s.tlp_st = {
      xadm_client0_vc0_s.tlp_st
      };



  assign exp_client0_s.tlp_dst_segment = {
      xadm_client0_vc0_s.tlp_dst_segment
      };


  assign exp_client0_s.tlp_order_seqnum = {
      xadm_client0_vc0_s.tlp_order_seqnum
      };

  // --------------------------------------------------------------------
  // XALI 1 Bus Expansion
  // --------------------------------------------------------------------
  assign exp_client1_s.tlp_hv = {
      xadm_client1_vc0_s.tlp_hv
      };

  assign exp_client1_s.tlp_dv = {
      xadm_client1_vc0_s.tlp_dv
      };

  assign exp_client1_s.tlp_eot = {
      xadm_client1_vc0_s.tlp_eot
      };

  assign exp_client1_s.tlp_fmt = {
      xadm_client1_vc0_s.tlp_fmt
      };

  assign exp_client1_s.tlp_type = {
      xadm_client1_vc0_s.tlp_type
      };

  assign exp_client1_s.tlp_td = {
      xadm_client1_vc0_s.tlp_td
      };

  assign exp_client1_s.tlp_ep = {
      xadm_client1_vc0_s.tlp_ep
      };

  assign exp_client1_s.tlp_attr = {
      xadm_client1_vc0_s.tlp_attr
      };

  assign exp_client1_s.tlp_bad_eot = {
      xadm_client1_vc0_s.tlp_bad_eot
      };

  assign exp_client1_s.addr_align_en = {
      xadm_client1_vc0_s.addr_align_en
      };

  assign exp_client1_s.tlp_func_num = {
      xadm_client1_vc0_s.tlp_func_num
      };

  assign exp_client1_s.cpl_cmpltr_id = {
      xadm_client1_vc0_s.cpl_cmpltr_id
      };

  assign exp_client1_s.cpl_status = {
      xadm_client1_vc0_s.cpl_status
      };

  assign exp_client1_s.cpl_bcm = {
      xadm_client1_vc0_s.cpl_bcm
      };

  assign exp_client1_s.cpl_byte_cnt = {
      xadm_client1_vc0_s.cpl_byte_cnt
      };


  assign exp_client1_s.tlp_ats = {
      xadm_client1_vc0_s.tlp_ats
      };

  assign exp_client1_s.tlp_nw = {
      xadm_client1_vc0_s.tlp_nw
      };

  assign exp_client1_s.tlp_tid = {
      xadm_client1_vc0_s.tlp_tid
      };

  assign exp_client1_s.tlp_byte_len = {
      xadm_client1_vc0_s.tlp_byte_len
      };

  assign exp_client1_s.tlp_addr = {
      swap_addr_par(xadm_client1_vc0_s.tlp_addr)
      };

  assign exp_client1_s.tlp_addr_par = {
      swap_addr_par_only(xadm_client1_vc0_s.tlp_addr)
      };

  assign exp_client1_s.tlp_byte_en = {
      xadm_client1_vc0_s.tlp_byte_en
      };

  assign exp_client1_s.tlp_tc = {
      xadm_client1_vc0_s.tlp_tc
      };

  assign exp_client1_s.tlp_data = {
      swap_data_par(xadm_client1_vc0_s.tlp_data)
      };

  assign exp_client1_s.cpl_lookup_id = {
      xadm_client1_vc0_s.cpl_lookup_id
      };

  assign exp_client1_s.tlp_prfx = {
      xadm_client1_vc0_s.tlp_prfx
      };


  assign exp_client1_s.tlp_atu_bypass = {
      xadm_client1_vc0_s.tlp_atu_bypass
      };

  assign exp_client1_s.tlp_dma = {
      xadm_client1_vc0_s.tlp_dma
      };

  assign exp_client1_s.tlp_dma_channel = {
      xadm_client1_vc0_s.tlp_dma_channel
      };

  assign exp_client1_s.tlp_th = {
      xadm_client1_vc0_s.tlp_th
      };

  assign exp_client1_s.tlp_ph = {
      xadm_client1_vc0_s.tlp_ph
      };

  assign exp_client1_s.tlp_st = {
      xadm_client1_vc0_s.tlp_st
      };



  assign exp_client1_s.tlp_dst_segment = {
      xadm_client1_vc0_s.tlp_dst_segment
      };


  assign exp_client1_s.tlp_order_seqnum = {
      xadm_client1_vc0_s.tlp_order_seqnum
      };

  // --------------------------------------------------------------------
  // XALI 2 Bus Expansion
  // --------------------------------------------------------------------
  assign exp_client2_s.tlp_hv = {
      xadm_client2_vc0_s.tlp_hv
      };

  assign exp_client2_s.tlp_dv = {
      xadm_client2_vc0_s.tlp_dv
      };

  assign exp_client2_s.tlp_eot = {
      xadm_client2_vc0_s.tlp_eot
      };

  assign exp_client2_s.tlp_fmt = {
      xadm_client2_vc0_s.tlp_fmt
      };

  assign exp_client2_s.tlp_type = {
      xadm_client2_vc0_s.tlp_type
      };

  assign exp_client2_s.tlp_td = {
      xadm_client2_vc0_s.tlp_td
      };

  assign exp_client2_s.tlp_ep = {
      xadm_client2_vc0_s.tlp_ep
      };

  assign exp_client2_s.tlp_attr = {
      xadm_client2_vc0_s.tlp_attr
      };

  assign exp_client2_s.tlp_bad_eot = {
      xadm_client2_vc0_s.tlp_bad_eot
      };

  assign exp_client2_s.addr_align_en = {
      xadm_client2_vc0_s.addr_align_en
      };

  assign exp_client2_s.tlp_func_num = {
      xadm_client2_vc0_s.tlp_func_num
      };

  assign exp_client2_s.remote_req_id = {
      xadm_client2_vc0_s.remote_req_id
      };

  assign exp_client2_s.cpl_status = {
      xadm_client2_vc0_s.cpl_status
      };

  assign exp_client2_s.cpl_bcm = {
      xadm_client2_vc0_s.cpl_bcm
      };

  assign exp_client2_s.cpl_byte_cnt = {
      xadm_client2_vc0_s.cpl_byte_cnt
      };

  assign exp_client2_s.tlp_ats = {
      xadm_client2_vc0_s.tlp_ats
      };

  assign exp_client2_s.tlp_nw = {
      xadm_client2_vc0_s.tlp_nw
      };

  assign exp_client2_s.tlp_tid = {
      xadm_client2_vc0_s.tlp_tid
      };

  assign exp_client2_s.tlp_byte_len = {
      xadm_client2_vc0_s.tlp_byte_len
      };


  assign exp_client2_s.tlp_addr = {
      swap_addr_par(xadm_client2_vc0_s.tlp_addr)
      };

  assign exp_client2_s.tlp_addr_par = {
      swap_addr_par_only(xadm_client2_vc0_s.tlp_addr)
      };

  assign exp_client2_s.tlp_byte_en = {
      xadm_client2_vc0_s.tlp_byte_en
      };

  assign exp_client2_s.tlp_tc = {
      xadm_client2_vc0_s.tlp_tc
      };

  assign exp_client2_s.tlp_data = {
      swap_data_par(xadm_client2_vc0_s.tlp_data)
      };

  assign exp_client2_s.cpl_lookup_id = {
      xadm_client2_vc0_s.cpl_lookup_id
      };

  assign exp_client2_s.tlp_prfx = {
      xadm_client2_vc0_s.tlp_prfx
      };


  assign exp_client2_s.tlp_atu_bypass = {
      xadm_client2_vc0_s.tlp_atu_bypass
      };

  assign exp_client2_s.tlp_dma = {
      xadm_client2_vc0_s.tlp_dma
      };

  assign exp_client2_s.tlp_dma_channel = {
      xadm_client2_vc0_s.tlp_dma_channel
      };

  assign exp_client2_s.tlp_th = {
      xadm_client2_vc0_s.tlp_th
      };

  assign exp_client2_s.tlp_ph = {
      xadm_client2_vc0_s.tlp_ph
      };

  assign exp_client2_s.tlp_st = {
      xadm_client2_vc0_s.tlp_st
      };




  assign exp_client2_s.tlp_dst_segment = {
      xadm_client2_vc0_s.tlp_dst_segment
      };


  assign exp_client2_s.tlp_order_seqnum = {
      xadm_client2_vc0_s.tlp_order_seqnum
      };


  function automatic [CORE_DATA_BUS_WD -1:0] swap_data_par;
    input [CORE_DATA_BUS_WD -1:0]        in_data;
    integer                              i,j;
    reg [CORE_DATA_BUS_WD -1:0]          i_swap_data_par;
    begin
       i_swap_data_par = {CORE_DATA_BUS_WD{1'b0}};
       for (i=0; i<(CORE_DATA_BUS_WD-PCIE_CORE_DATA_BUS_WD); i=i+1) begin
          for (j=0; j<CX_RAS_PROT_RANGE; j=j+1) begin
             i_swap_data_par[i*CX_RAS_PROT_RANGE +j] = in_data[i*CX_RAS_PROT_RANGE +j +i];
          end
          i_swap_data_par[CORE_DATA_BUS_WD - (CORE_DATA_BUS_WD-PCIE_CORE_DATA_BUS_WD) +i] = in_data[(i+1)*CX_RAS_PROT_RANGE +i];
       end
       swap_data_par = i_swap_data_par;
    end
  endfunction

  function automatic [63:0] swap_addr_par;
    input [63 + ADDR_PAR_WD:0]   in_addr;
    integer                      i,j;
    reg [63 + ADDR_PAR_WD:0]     i_swap_addr_par;
    begin
       i_swap_addr_par = {63 + ADDR_PAR_WD{1'b0}};
       for (i=0; i<ADDR_PAR_WD; i=i+1) begin
          for (j=0; j<CX_RAS_PROT_RANGE; j=j+1) begin
             i_swap_addr_par[i*CX_RAS_PROT_RANGE +j] = in_addr[i*CX_RAS_PROT_RANGE +j +i];
          end
          i_swap_addr_par[64 + i] = in_addr[(i+1)*CX_RAS_PROT_RANGE +i];
       end
       swap_addr_par = i_swap_addr_par[63:0];
    end
  endfunction

  function automatic [ADDR_PAR_WD-1:0] swap_addr_par_only;
    input [63 + ADDR_PAR_WD:0]   in_addr;
    integer                      i,j;
    reg [63 + ADDR_PAR_WD:0]     i_swap_addr_par;
    begin
      i_swap_addr_par = {63 + ADDR_PAR_WD{1'b0}};
      for (i=0; i<ADDR_PAR_WD; i=i+1) begin
         for (j=0; j<CX_RAS_PROT_RANGE; j=j+1) begin
            i_swap_addr_par[i*CX_RAS_PROT_RANGE +j] = in_addr[i*CX_RAS_PROT_RANGE +j +i];
         end
         i_swap_addr_par[64 + i] = in_addr[(i+1)*CX_RAS_PROT_RANGE +i];
      end
      swap_addr_par_only = i_swap_addr_par[63 + ADDR_PAR_WD:64];
    end
  endfunction

endmodule


