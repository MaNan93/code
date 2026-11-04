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
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_s2m_rx_tl.sv#8 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// CXL Reciever Transaction Layer Top Module - Mem Host - S2M
//  Expected default sizes are:
//  S2M NDR(2), Data Header(3), Data(1), BI-Snp(1) Message signals
// Data Path
//  Req : cxl_ch_dltl_s2m_ndrsp[(S2M_NDR_NUM-1):0]
//        -> DWC_cxl_rx_tl_queue_fifo_interface (USAGE=0)
//        -> cxl_mst_s2m_ndrsp[(S2M_NDR_IFNUM-1):0]
//  Data: cxl_ch_dltl_s2m_dhr[(S2M_DDATA_NUM-1):0]
//        -> DWC_cxl_rx_tl_queue_fifo_interface (USAGE=2)
//        -> cxl_mst_s2m_data[(S2M_DATA_IFNUM-1):0]
//        {cxl_dltl_s2m_data,       -> Registered
//         cxl_dltl_s2m_data_valid}
//  BI-Snp: cxl_dltl_s2m_bi_snp[(S2M_BI_SNP_NUM-1):0]
//        -> DWC_cxl_rx_tl_queue_fifo_interface (USAGE=0)
//        -> cxl_mst_s2m_bi_rsp[(S2M_BI_SNP_IFNUM-1):0]
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

`include "CXL/svif/DWC_cxl_clk_rst_if.svh"
`include "CXL/svif/DWC_cxl_ram2p_if.svh"

module DWC_cxl_mem_s2m_rx_tl
  import DWC_cxl_pkg::*;
  #(
    parameter  TP                   = `TP,
    parameter  S2M_NDR_RAM_NUM      = MS_SM_NDR_NUM,
    parameter  S2M_BI_SNP_RAM_NUM   = MS_BI_NUM
  ) (
    DWC_cxl_clk_rst_if.slave_mp                    b_clk
  , input  logic                                   toggle_flag_cxl_clk
  , input  logic                                   cxl_rx_vlsm_req_flush
  //  Interface with DWC_cxl_mst_link_ctrl - Mem - s_cxl_clk domain
  , output logic                                   cxl_rx_tl_mem_s2m_pending
  , output logic                                   cxl_mst_rx_tl_s2m_ndrsp_ovflw
  , output logic                                   cxl_mst_rx_tl_s2m_data_ovflw
//`ifdef CX_CXL_BI_SUPPORT
  , output logic                                   cxl_mst_rx_tl_s2m_bi_snp_ovflw
//`endif // CX_CXL_BI_SUPPORT
  , input  logic                                   cxl_rx_tl_mem_s2m_ch_msg_halt
  , input  logic                                   cxl_rx_tl_mem_s2m_nullify_crd
  , input  logic                                   cxl_rx_tl_mem_s2m_run_crd_cnt
  //  Interface with Link layer for communicating TL layer credit release - s_core_clk domain
  , output logic [(S2M_NDR_NUM-1):0]               cxl_rx_tl_mem_s2m_ndrsp_valid
  , output logic [(S2M_DDATA_NUM-1):0]             cxl_rx_tl_mem_s2m_data_valid
  //  Interface with RX Application Layer   - synchronous to s_cxl_clk
  //  S2M No Data Request(NDR)(2) Data(1) Message signals
  , output logic [(S2M_NDR_IFNUM-1):0][(S2M_NDR_RX_CH_SIZE-1):0]   cxl_mst_s2m_ndrsp
  , output logic [(S2M_DATA_IFNUM-1):0][(S2M_DATA_RX_CH_SIZE-1):0] cxl_mst_s2m_data
  //  S2M Credit signals per Message
  , input  logic [(S2M_NDR_IFNUM-1):0]             cxl_mst_s2m_ndrsp_crd
  , input  logic                                   cxl_mst_s2m_data_crd
  //  Interface with RX DATA Link Layer - synchronous to s_core_clk
  //  RX Data Link layer CRC Error signal
  //  - Needed for delayed msg invalidation - timing optimization
  , input  logic                                   cxl_dltl_s2m_crc_err
  //  S2M NDR(2), Data Header(3), Data(1), Message signals
  , input  logic [(S2M_NDR_NUM-1):0][(S2M_NDR_RX_CH_SIZE-1):0]     cxl_ch_dltl_s2m_ndrsp
  , input  logic [(S2M_DDATA_NUM-1):0][(S2M_DHDR_RX_CH_SIZE-1):0]   cxl_ch_dltl_s2m_dhr
  , input  logic [(S2M_DDATA_NUM-1):0][(S2M_DDATA_RX_CH_SIZE-1):0] cxl_dltl_s2m_data
  , input  logic [(S2M_DDATA_NUM-1):0]                             cxl_dltl_s2m_data_valid
  , output logic [(S2M_BI_SNP_NUM-1):0]                                cxl_rx_tl_mem_s2m_bi_snp_valid
  , output logic [(S2M_BI_SNP_IFNUM-1):0][(S2M_BI_SNP_RX_CH_SIZE-1):0] cxl_mst_s2m_bi_snp
  , input  logic [(S2M_BI_SNP_IFNUM-1):0]                              cxl_mst_s2m_bi_snp_crd
  , input  logic [(S2M_BI_SNP_NUM-1):0][(S2M_BI_SNP_RX_CH_SIZE-1):0]   cxl_dltl_s2m_bi_snp
  //  Expecting 2 power based no of instances(1/2/4).
  //  Address width and depth are calculated based on the no of RAM instances
  //  S2M NDR RAM Interface(2)
  , DWC_cxl_ram2p_if.master_mp                     b_s2m_ndrsp_ram[(S2M_NDR_RAM_NUM-1):0]
  //  S2M DATA RAM Interface(1)
  //  S2M Rdata, Wdata width is calculated to accomodate the write pointer of the S2M DATA (MEM_NDR_CRD_WD+1)
  , DWC_cxl_ram2p_if.master_mp                     b_s2m_data_ram[(S2M_DDATA_NUM-1):0]
  , DWC_cxl_ram2p_if.master_mp                     b_s2m_bi_snp_ram[(S2M_BI_SNP_RAM_NUM-1):0]
  );

  //============================================================================
  //  Declarations and common logic
  //============================================================================
  //  Pending indication
  logic                                           s2m_ndrsp_mapper_pending;
  logic                                           s2m_dhr_mapper_pending;
assign s2m_dhr_mapper_pending ='0;
  logic                                           s2m_data_fifo_pending;

  logic                                           s2m_bi_snp_mapper_pending;


  //  S2M pending calculation based on inputs from each of its stages
  //  to control Master link control low power FSM state.
  assign cxl_rx_tl_mem_s2m_pending = (s2m_ndrsp_mapper_pending
                                    | s2m_data_fifo_pending
                                    | s2m_bi_snp_mapper_pending
                                     );

  // Overflow indication
  logic [($clog2(S2M_NDR_RAM_NUM)+1):0]               s2m_ndrsp_fifo_net_crd;
  logic signed [MEM_NDR_CRD_WD:0]                 cxl_mst_rx_tl_s2m_ndrsp_rxbuf_crd_cnt;

  logic [($clog2(S2M_DDATA_NUM)+1):0]             s2m_data_fifo_net_crd;
  logic signed [MEM_DATA_CRD_WD:0]                cxl_mst_rx_tl_s2m_data_rxbuf_crd_cnt;

  logic [($clog2(S2M_BI_SNP_RAM_NUM)+1):0]            s2m_bi_snp_fifo_net_crd;
  logic signed [MEM_BI_SNP_CRD_WD:0]              cxl_mst_rx_tl_s2m_bi_snp_rxbuf_crd_cnt;

  always_ff @(posedge b_clk.s_core_clk or negedge b_clk.s_core_rst_n) begin
    if (!b_clk.s_core_rst_n) begin
         cxl_mst_rx_tl_s2m_ndrsp_rxbuf_crd_cnt  <= #TP '0;
         cxl_mst_rx_tl_s2m_data_rxbuf_crd_cnt   <= #TP '0;
         cxl_mst_rx_tl_s2m_bi_snp_rxbuf_crd_cnt     <= #TP '0;
      end
      else begin
        cxl_mst_rx_tl_s2m_ndrsp_rxbuf_crd_cnt  <=
          #TP (MEM_NDR_CRD_WD+1)'(cxl_mst_rx_tl_s2m_ndrsp_rxbuf_crd_cnt + signed'(s2m_ndrsp_fifo_net_crd));

        cxl_mst_rx_tl_s2m_data_rxbuf_crd_cnt   <=
          #TP (MEM_DATA_CRD_WD+1)'(cxl_mst_rx_tl_s2m_data_rxbuf_crd_cnt  + signed'(s2m_data_fifo_net_crd));

        cxl_mst_rx_tl_s2m_bi_snp_rxbuf_crd_cnt     <=
          #TP (MEM_BI_SNP_CRD_WD+1)'(cxl_mst_rx_tl_s2m_bi_snp_rxbuf_crd_cnt    + signed'(s2m_bi_snp_fifo_net_crd));
      end
  end

  assign cxl_mst_rx_tl_s2m_ndrsp_ovflw  =
          (cxl_mst_rx_tl_s2m_ndrsp_rxbuf_crd_cnt >  {1'b1,{MEM_NDR_CRD_WD{1'b0}}});

  assign cxl_mst_rx_tl_s2m_data_ovflw =
          (cxl_mst_rx_tl_s2m_data_rxbuf_crd_cnt >  {1'b1,{MEM_DATA_CRD_WD{1'b0}}});

  assign cxl_mst_rx_tl_s2m_bi_snp_ovflw =
          (cxl_mst_rx_tl_s2m_bi_snp_rxbuf_crd_cnt >  {1'b1,{MEM_BI_SNP_CRD_WD{1'b0}}});

  //============================================================================
  //  S2M NDR Mapper Stage. Inputs=S2M_NDR_NUM (expected to be 2).
  //  The total depth of FIFO is MEM_REQ_CEIL2_DP.
  //  Thus depth of each individual FIFO is divided by S2M_NDR_RAM_NUM internally.
  //============================================================================
  DWC_cxl_rx_tl_queue_fifo_interface
   #(
      .USAGE           (0)
    , .CHNLS           (S2M_NDR_NUM)
    , .DW              (S2M_NDR_RX_CH_SIZE)
    , .FIFO_DEPTH      (MEM_REQ_CEIL2_DP)
    , .FIFO_ADDR_WIDTH (MEM_NDR_CRD_WD)
    , .FIFO_INTERFACE  (S2M_NDR_RAM_NUM)
    , .AL_IFNUM        (S2M_NDR_IFNUM)
    ) U_DWC_cxl_rx_tl_s2m_ndrsp(
    //  Inputs
      .b_clk                   (b_clk)
    , .data_in                 (cxl_ch_dltl_s2m_ndrsp)
    , .crc_err                 (cxl_dltl_s2m_crc_err)
    , .fifo_push               ('1)
    , .AL_crd                  (cxl_mst_s2m_ndrsp_crd)
    , .ch_msg_halt             (cxl_rx_tl_mem_s2m_ch_msg_halt)
    , .nullify_crd_cnt         (cxl_rx_tl_mem_s2m_nullify_crd)
    , .run_crd_cnt             (cxl_rx_tl_mem_s2m_run_crd_cnt)
    , .toggle_flag             (toggle_flag_cxl_clk)
    , .fst_wrptr_count         ('0)
    , .fst_chnl_pending        ('0)
    , .fst_chnl_rd_cnt         ('0)
    , .read_aux_ptr            ('0)
    , .read_aux_ptr_en         ('0)
    //  Outputs
    , .q_map_wrptr_cnt_vld     ()
    , .q_fifo_pending          (s2m_ndrsp_mapper_pending)
    , .fifo_pending            ()
    , .fifo_net_crd            (s2m_ndrsp_fifo_net_crd)
    , .b_ram                   (b_s2m_ndrsp_ram)
    , .cxl_rx_tl_valid         (cxl_rx_tl_mem_s2m_ndrsp_valid)
    , .stored_aux_ptr          ()
    , .stored_aux_ptr_ctrl_en  ()
    , .rdptr_count             ()
    , .r_map_data              (cxl_mst_s2m_ndrsp)
    , .ptr_err                 ()
    );

  //============================================================================
  //  - S2M Data Mapper Stage.
  //  - Data Header Queue Mapper Will Be Bypassed(USAGE=2) as it is Moved To Link 
  //    Layer for Supporting Late Poison Feature as poison Bit Should be Asserted
  //    Before RAS Protection. 
  //============================================================================

  logic [(S2M_DDATA_NUM-1):0][(S2M_DATA_RX_CH_SIZE-1):0]  s2m_data_fifo_data_in;

  always_comb begin
    for(int i=0; i<S2M_DDATA_NUM; i=i+1) begin
      s2m_data_fifo_data_in[i] =  {
                cxl_dltl_s2m_data[i][S2M_DDATA_RX_CH_SIZE-1:S2M_DDATA_SIZE]
              , cxl_ch_dltl_s2m_dhr[i][S2M_DHDR_RX_CH_SIZE-1:S2M_DHDR_SIZE]
              ,                cxl_dltl_s2m_data[i][S2M_DDATA_SIZE-1:0]
              , cxl_ch_dltl_s2m_dhr[i][S2M_DHDR_SIZE-1:0]
                                  };
    end
  end

  DWC_cxl_rx_tl_queue_fifo_interface
   #(
      .USAGE           ( ((S2M_DDATA_NUM==1)? 2:0))
    , .CHNLS           ( S2M_DDATA_NUM            )
    , .DW              ( S2M_DATA_RX_CH_SIZE      )
    , .FIFO_DEPTH      ( MEM_DQ_CEIL2_DP          )
    , .FIFO_ADDR_WIDTH ( MEM_DATA_CRD_WD          )
    , .AL_IFNUM        ( S2M_DATA_IFNUM           )
    ) U_DWC_cxl_rx_tl_s2m_data_fifo_interface(
    //  Inputs
      .b_clk                   (b_clk)
    , .data_in                 (s2m_data_fifo_data_in)
    , .crc_err                 ('0)
    , .fifo_push               (cxl_dltl_s2m_data_valid)
    , .AL_crd                  (cxl_mst_s2m_data_crd)
    , .ch_msg_halt             (cxl_rx_tl_mem_s2m_ch_msg_halt)
    , .nullify_crd_cnt         (cxl_rx_tl_mem_s2m_nullify_crd)
    , .run_crd_cnt             (cxl_rx_tl_mem_s2m_run_crd_cnt)
    , .toggle_flag             (toggle_flag_cxl_clk)
    , .fst_wrptr_count         ('0)
    , .fst_chnl_pending        ('0)
    , .fst_chnl_rd_cnt         ('0)
    , .read_aux_ptr            ('0)
    , .read_aux_ptr_en         ('0)
    //  Outputs
    , .q_map_wrptr_cnt_vld     ()
    , .q_fifo_pending          (s2m_data_fifo_pending)
    , .fifo_pending            ()
    , .fifo_net_crd            (s2m_data_fifo_net_crd)
    , .b_ram                   (b_s2m_data_ram)
    , .cxl_rx_tl_valid         (cxl_rx_tl_mem_s2m_data_valid)
    , .stored_aux_ptr          ()
    , .stored_aux_ptr_ctrl_en  ()
    , .rdptr_count             ()
    , .r_map_data              (cxl_mst_s2m_data)
    , .ptr_err                 ()
    );

  //============================================================================
  //  S2M Back-Invalidate Snoop Stage.
  //  Inputs=S2M_BI_SNP_NUM (expected to be 1).
  //============================================================================
  DWC_cxl_rx_tl_queue_fifo_interface
   #(
      .USAGE           (0)
    , .CHNLS           (S2M_BI_SNP_NUM)
    , .DW              (S2M_BI_SNP_RX_CH_SIZE)
    , .FIFO_DEPTH      (MEM_BI_SNP_CEIL2_DP)
    , .FIFO_ADDR_WIDTH (S2M_BI_SNP_RAM_ADDRW)
    , .FIFO_INTERFACE  (S2M_BI_SNP_RAM_NUM)
    , .AL_IFNUM        (S2M_BI_SNP_IFNUM)
    ) U_DWC_cxl_rx_tl_s2m_bi_snp_fifo_interface(
    //  Inputs
      .b_clk                   (b_clk)
    , .data_in                 (cxl_dltl_s2m_bi_snp)
    , .crc_err                 (cxl_dltl_s2m_crc_err)
    , .fifo_push               ('1)
    , .AL_crd                  (cxl_mst_s2m_bi_snp_crd)
    , .ch_msg_halt             (cxl_rx_tl_mem_s2m_ch_msg_halt)
    , .nullify_crd_cnt         (cxl_rx_tl_mem_s2m_nullify_crd)
    , .run_crd_cnt             (cxl_rx_tl_mem_s2m_run_crd_cnt)
    , .toggle_flag             (toggle_flag_cxl_clk)
    , .fst_wrptr_count         ('0)
    , .fst_chnl_pending        ('0)
    , .fst_chnl_rd_cnt         ('0)
    , .read_aux_ptr            ('0)
    , .read_aux_ptr_en         ('0)
    //  Outputs
    , .q_map_wrptr_cnt_vld     ()
    , .q_fifo_pending          (s2m_bi_snp_mapper_pending)
    , .fifo_pending            ()
    , .fifo_net_crd            (s2m_bi_snp_fifo_net_crd)
    , .b_ram                   (b_s2m_bi_snp_ram)
    , .cxl_rx_tl_valid         (cxl_rx_tl_mem_s2m_bi_snp_valid)
    , .stored_aux_ptr          ()
    , .stored_aux_ptr_ctrl_en  ()
    , .rdptr_count             ()
    , .r_map_data              (cxl_mst_s2m_bi_snp)
    , .ptr_err                 ()
    );


endmodule
