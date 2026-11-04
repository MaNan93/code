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
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/inbound/DWC_pcie_bridge_ib_scheduler_buf.sv#3 $
// ---------------------------------------------------------------------------------------
// Module Description:
// Does muxing of the inbound traffic, depending on the configuration
// Stamps to the incoming TLP a sequence number
// ---------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
 
module DWC_pcie_bridge_ib_scheduler_buf

  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::MAX_RAS_PROT_CHK_N;
  import DWC_pcie_ctl_pkg::UNCORRECTABLE;
  import DWC_pcie_ctl_pkg::CORRECTABLE;
  import DWC_pcie_ctl_pkg::RAS_ERROR_TYPE_INDEX;
  import DWC_pcie_ctl_pkg::RAS_ERROR_TYPE_WD;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  #(
     parameter SEGNUM                = 16
    ,parameter SEGNUM_LOG2           = 4
    ,parameter SEGDEPTH              = 4
    ,parameter SEGDEPTH_LOG2         = 2
    ,parameter P_NP_BUFFER           = 0
    ,parameter RAM_REG_IN            = 1
    ,parameter RAM_RD_LATENCY        = 1
    ,parameter HDR_WD                = 256
    ,parameter DATA_WD               = 256
    ,parameter HDR_WD_NP             = 256
    ,parameter ADDR_WD_NP            = 64
    ,parameter DATA_WD_NP            = 256
    ,parameter ADDR_WD               = 64
    ,parameter DATA_BYTES            = 32
    ,parameter HDR_RAM_ADDR_WD       = 4
    ,parameter HDR_RAM_DATA_WD       = 256
    ,parameter HDR_RAM_DEPTH         = 16
    ,parameter DATA_RAM_ADDR_WD      = 4
    ,parameter DATA_RAM_DATA_WD      = 256
    ,parameter DATA_RAM_DEPTH        = 16
    ,parameter NVC                   = 8
    ,parameter NVC_WD                = 3
    ,parameter NIDO_WD               = 3
    ,parameter PSEQNUM_WD            = 8
    ,parameter HDR_RAM_ECC_WD        = 4
    ,parameter DATA_RAM_ECC_WD       = 4
    ,parameter RAS_RAM_PROT_RANGE    = 8
    ,parameter RAS_PARITY_MODE       = 1
    ,parameter HDR_RAS_DP_ID         = 1
    ,parameter DT_RAS_DP_ID          = 2
    ,parameter HQ_RAS_DP_ID          = 3
    ,parameter DQ_RAS_DP_ID          = 4
    ,parameter CC_AMBA_TLP_SEQ_WD      = `CC_AMBA_TLP_SEQ_WD
    ,parameter CC_GEN6_AXI_MAX_P_DELAY = `CC_GEN6_AXI_MAX_P_DELAY

    // -------------------------------------------------------------------------------------
    // Parameters not modified by an instantiation parameter assignment
    // -------------------------------------------------------------------------------------
    ,parameter TP       = `TP
    )
   
                                         (
     input                                    clk
    ,input                                    rstn

    ,input  [7:0]                             cfg_ax_mstr_np_pass_p
    ,input  [`CX_NVC-1:0]                     cfg_enhanced_ordering_en
    ,input   [`CX_NVC-1:0]                    trgt1_p_xfer_pend_per_vc
    ,input  [HDR_WD-1:0]                      hdr_in
    ,input  [DATA_WD-1:0]                     data_in
    ,input  [CC_AMBA_TLP_SEQ_WD-1:0]          pseq_num_in
    ,input                                    hv_in
    ,input                                    dv_in
    ,input                                    eot_in
    ,output logic                             halt_out

    ,output logic [HDR_WD-1:0]                hdr_out
    ,output logic [DATA_WD-1:0]               data_out
    ,output logic                             hv_out
    ,output logic                             dv_out
    ,output logic                             eot_out
    ,input                                    halt_in

    ,input [NVC-1:0] [CC_AMBA_TLP_SEQ_WD-1:0] ibreq_presp_rpseq
    ,input [NVC-1:0] [CC_AMBA_TLP_SEQ_WD-1:0] ibreq_cfg_rpseq
    ,input [NVC-1:0] [CC_AMBA_TLP_SEQ_WD-1:0] last_req_pseq

    ,output logic                             hdr_ram_wea
    ,output logic [HDR_RAM_ADDR_WD-1:0]       hdr_ram_addra
    ,output logic [HDR_RAM_DATA_WD-1:0]       hdr_ram_dina
    ,output logic [HDR_RAM_ADDR_WD-1:0]       hdr_ram_addrb
    ,output logic                             hdr_ram_enb
    ,input        [HDR_RAM_DATA_WD-1:0]       hdr_ram_doutb

    ,output logic                             data_ram_wea
    ,output logic [DATA_RAM_ADDR_WD-1:0]      data_ram_addra
    ,output logic [DATA_RAM_DATA_WD-1:0]      data_ram_dina
    ,output logic [DATA_RAM_ADDR_WD-1:0]      data_ram_addrb
    ,output logic                             data_ram_enb
    ,input        [DATA_RAM_DATA_WD-1:0]      data_ram_doutb
    ,output logic                             axi_ras_par_ib_sch_ad_pulse
    ,output logic                             axi_ras_par_ib_sch_dt_pulse
    ,input                                    cfg_hq_ras_recc_correct
    ,output logic                             hq_ras_recc_corr_cnt_pulse
    ,output logic                             hq_ras_recc_ucorr_cnt_pulse
    ,output logic [HDR_RAM_ADDR_WD-1:0]       hq_ras_recc_cnt_addr
    ,input                                    cfg_dq_ras_recc_correct
    ,output logic                             dq_ras_recc_corr_cnt_pulse
    ,output logic                             dq_ras_recc_ucorr_cnt_pulse
    ,output ras_dp_err_log_t                  axi_ib_sch_ad_ras_dp_err_log
    ,output ras_dp_err_log_t                  axi_ib_sch_dt_ras_dp_err_log
    ,output ras_dp_err_log_t                  dq_ras_recc_cnt_ras_dp_err_log
    ,output ras_dp_err_log_t                  hq_ras_recc_cnt_ras_dp_err_log
    ,input ras_dp_err_inj_t                   core_clk_ordrb_ras_dp_err_inj
    ,output logic [DATA_RAM_ADDR_WD-1:0]      dq_ras_recc_cnt_addr

    );

localparam FLT_Q_ADDR_WIDTH      = `FLT_Q_ADDR_WIDTH;
localparam CC_CORE_ADDR_BUS_WD   = `CC_CORE_ADDR_BUS_WD;
localparam PCIE_CORE_DATA_BUS_WD = `PCIE_CORE_DATA_BUS_WD;
localparam CX_RAS_PROT_RANGE     = `CX_RAS_PROT_RANGE;
localparam CX_RAS_PARITY_MODE    = `CX_RAS_PARITY_MODE;
localparam NUM_ADDR_PAR_BLOCKS   =  ADDR_WD_NP/CX_RAS_PROT_RANGE;
localparam NUM_DATA_PAR_BLOCKS   =  DATA_WD_NP/CX_RAS_PROT_RANGE;
localparam RAS_DP_ERR_LOG_WD = $clog2(MAX_RAS_PROT_CHK_N)+1;

// RAM output data register stage; always ON
localparam RAM_RD_REG_OUT = 1;

// Latency pipe halt threshold; assert 1 clock cycle before
localparam LTCY_HALT_THLD = RAM_REG_IN + RAM_RD_REG_OUT;

// Number of extra positions on RAM latency buffer.
// Latency RAM must be dimensioned to consider the time between a pop request
// and data availability. This is required to avoid bubbles in the output data path
localparam LTCY_EXTRA_STORAGE = 1 + RAM_REG_IN + RAM_RD_REG_OUT + LTCY_HALT_THLD;


reg  [SEGNUM_LOG2-1:0]             r_seg_num        [SEGNUM-1:0];
reg  [CC_AMBA_TLP_SEQ_WD-1:0]      r_seg_pseq_num   [SEGNUM-1:0];
reg  [SEGNUM-1:0]                  r_seg_active                 ;
reg  [SEGNUM-1:0]                  r_seg_scheduled              ;
reg  [SEGDEPTH_LOG2-1:0]           r_seg_length     [SEGNUM-1:0];
reg  [SEGNUM-1:0]                  r_seg_req_w_data             ;
reg  [SEGNUM-1:0]                  r_seg_errored                ;

reg  [SEGNUM_LOG2-1:0]             s_seg_num        [SEGNUM-1:0];
reg  [CC_AMBA_TLP_SEQ_WD-1:0]      s_seg_pseq_num   [SEGNUM-1:0];
reg  [SEGNUM-1:0]                  s_seg_active                 ;
reg  [SEGNUM-1:0]                  s_seg_scheduled              ;
reg  [SEGDEPTH_LOG2-1:0]           s_seg_length     [SEGNUM-1:0];
reg  [SEGNUM-1:0]                  s_seg_req_w_data             ;
reg  [SEGNUM-1:0]                  s_seg_errored                ;

reg  [SEGDEPTH_LOG2-1:0]           r_seg_wr_addr;
reg  [SEGDEPTH_LOG2-1:0]           s_seg_wr_addr;

reg  [SEGDEPTH_LOG2-1:0]           r_seg_rd_addr;
reg  [SEGDEPTH_LOG2-1:0]           s_seg_rd_addr;

reg                                r_hdr_ram_enb;
reg                                r_data_ram_enb;

wire [HDR_RAM_DATA_WD-1:0]         s_hdr_in;
wire [DATA_RAM_DATA_WD-1:0]        s_data_in;
wire [HDR_WD-1:0]                  s_hdr_out;
wire [DATA_WD-1:0]                 s_data_out;

wire                               i_hdr_ram_wea;
wire [HDR_RAM_ADDR_WD-1:0]         i_hdr_ram_addra;
wire [HDR_RAM_DATA_WD-1:0]         i_hdr_ram_dina;
wire [HDR_RAM_ADDR_WD-1:0]         i_hdr_ram_addrb;
wire                               i_hdr_ram_enb;
reg                                s_hdr_ram_enb;
reg  [HDR_RAM_DATA_WD-1:0]         s_hdr_ram_doutb;
reg  [HDR_RAM_DATA_WD-1:0]         r_hdr_ram_doutb;

wire                               i_data_ram_wea;
wire [DATA_RAM_ADDR_WD-1:0]        i_data_ram_addra;
wire [DATA_RAM_DATA_WD-1:0]        i_data_ram_dina;
wire [DATA_RAM_ADDR_WD-1:0]        i_data_ram_addrb;
wire                               i_data_ram_enb;
reg                                s_data_ram_enb;
reg  [DATA_RAM_DATA_WD-1:0]        s_data_ram_doutb;
reg  [DATA_RAM_DATA_WD-1:0]        r_data_ram_doutb;

wire [ADDR_WD-1:0]                 addr_in;
wire                               addr_in_chk_en;
wire                               data_in_chk_en;
wire [HDR_RAM_ECC_WD-1:0]          eccg_hdr_in;
wire [DATA_RAM_ECC_WD-1:0]         eccg_data_in;
wire [HDR_WD_NP-1:0]               s_hdr_in_np;
wire [DATA_WD_NP-1:0]              s_data_in_np;
wire                               cfg_hq_ras_recc_correct_n;
wire                               cfg_dq_ras_recc_correct_n;
wire                               hq_chk_recc_corr_cnt_pulse;
wire                               dq_chk_recc_corr_cnt_pulse;

wire                               s_ltcy_halt;

wire                               i_hv_out , d_hv_out , s_hv_out ;
wire                               i_dv_out , d_dv_out , s_dv_out ;
wire                               i_eot_out, d_eot_out, s_eot_out;

reg                                r_hv_out;
reg                                r_dv_out;
reg                                r_eot_out;
reg  [HDR_WD-1:0]                  r_hdr_out;
reg  [DATA_WD-1:0]                 r_data_out;

wire                               s_halt_in;

wire                               s_ro_disable;

wire                               s_segment_released;
wire                               s_segment_consumed;
wire                               s_segment_available;
wire [SEGNUM_LOG2-1:0]             i_released_segment;
wire [SEGNUM_LOG2-1:0]             i_released_segment_index;
wire                               i_released_segment_valid;
wire [SEGNUM_LOG2-1:0]             s_released_segment;
wire [SEGNUM_LOG2-1:0]             s_released_segment_index;
wire                               s_released_segment_valid;
reg  [SEGNUM_LOG2-1:0]             r_released_segment;
reg  [SEGNUM_LOG2-1:0]             r_released_segment_index;
reg                                r_released_segment_valid;
wire [SEGNUM_LOG2-1:0]             s_consumed_segment;
reg  [SEGNUM-1:0]                  s_shift_released_segments_down;
reg  [SEGNUM-1:0]                  s_shift_consumed_segments_up;
reg  [SEGNUM-1:0]                  s_push_consumed_segment;
reg  [SEGNUM-1:0]                  s_push_released_segment;

reg                                r_previous_p_is_ro;
reg  [CC_AMBA_TLP_SEQ_WD-1:0]      r_previous_p_seq_num;
wire                               s_previous_p_is_ro;
wire [CC_AMBA_TLP_SEQ_WD-1:0]      s_previous_p_seq_num;
wire                               s_ro_req;
wire                               s_dma_req;
wire                               s_dllp_abort_in;
wire                               s_tlp_abort_in;
wire                               s_errored_req;
wire                               s_dropped_req;

wire [HDR_RAM_ADDR_WD-1:0]         dly_hdr_ram_addrb;
wire [DATA_RAM_ADDR_WD-1:0]        dly_data_ram_addrb;
wire [HDR_RAM_ADDR_WD-1:0]         hdr_ram_addr_ras_dp_pipe;
wire [DATA_RAM_ADDR_WD-1:0]        data_ram_addrb_ras_dp_pipe;
wire [HDR_RAM_DATA_WD-1:0]         s2_hdr_ram_doutb;
wire [DATA_RAM_DATA_WD-1:0]        s2_data_ram_doutb;
wire [HDR_WD_NP-1:0]               s3_hdr_ram_doutb;
wire [DATA_WD_NP-1:0]              s3_data_ram_doutb;
wire [HDR_WD_NP-1:0]               s3_hdr_ram_doutb_pipe;
wire [DATA_WD_NP-1:0]              s3_data_ram_doutb_pipe;
wire [HDR_WD-1:0]                  s_ltcy_out_hdr;
wire [DATA_WD-1:0]                 s_ltcy_out_data;

generate
if(P_NP_BUFFER)begin: GEN_S_RO_DISABLE
assign s_ro_disable = 1'b0;
end else begin
assign s_ro_disable = (     ({hdr_in[`INBD_HDR_PNP_RANGE_FMT_LOW-2:`INBD_HDR_PNP_RANGE_FMT_LOW-3],hdr_in[`INBD_HDR_PNP_RANGE_TYPE_HIGH-3:`INBD_HDR_PNP_RANGE_TYPE_LOW-3]} ==      `MRD64  )
                        ||  ({hdr_in[`INBD_HDR_PNP_RANGE_FMT_LOW-2:`INBD_HDR_PNP_RANGE_FMT_LOW-3],hdr_in[`INBD_HDR_PNP_RANGE_TYPE_HIGH-3:`INBD_HDR_PNP_RANGE_TYPE_LOW-3]} ==      `MRDLK64)
                        ||  ({hdr_in[`INBD_HDR_PNP_RANGE_FMT_LOW-2:`INBD_HDR_PNP_RANGE_FMT_LOW-3],hdr_in[`INBD_HDR_PNP_RANGE_TYPE_HIGH-3:`INBD_HDR_PNP_RANGE_TYPE_LOW-3]} ==      `MRD32  )
                        ||  ({hdr_in[`INBD_HDR_PNP_RANGE_FMT_LOW-2:`INBD_HDR_PNP_RANGE_FMT_LOW-3],hdr_in[`INBD_HDR_PNP_RANGE_TYPE_HIGH-3:`INBD_HDR_PNP_RANGE_TYPE_LOW-3]} ==      `MRDLK32)
                        ||  ({hdr_in[`INBD_HDR_PNP_RANGE_FMT_LOW-2:`INBD_HDR_PNP_RANGE_FMT_LOW-3],hdr_in[`INBD_HDR_PNP_RANGE_TYPE_HIGH-3:`INBD_HDR_PNP_RANGE_TYPE_LOW-3]} ==      `IORD   )
                        ||  ({hdr_in[`INBD_HDR_PNP_RANGE_FMT_LOW-2:`INBD_HDR_PNP_RANGE_FMT_LOW-3],hdr_in[`INBD_HDR_PNP_RANGE_TYPE_HIGH-3:`INBD_HDR_PNP_RANGE_TYPE_LOW-3]} ==      `IOWR   )
                        ||  ({hdr_in[`INBD_HDR_PNP_RANGE_FMT_LOW-2:`INBD_HDR_PNP_RANGE_FMT_LOW-3],hdr_in[`INBD_HDR_PNP_RANGE_TYPE_HIGH-3:`INBD_HDR_PNP_RANGE_TYPE_LOW-3]} ==      `CFGRD0 )
                        ||  ({hdr_in[`INBD_HDR_PNP_RANGE_FMT_LOW-2:`INBD_HDR_PNP_RANGE_FMT_LOW-3],hdr_in[`INBD_HDR_PNP_RANGE_TYPE_HIGH-3:`INBD_HDR_PNP_RANGE_TYPE_LOW-3]} ==      `CFGRD1 )
                        ||  ({hdr_in[`INBD_HDR_PNP_RANGE_FMT_LOW-2:`INBD_HDR_PNP_RANGE_FMT_LOW-3],hdr_in[`INBD_HDR_PNP_RANGE_TYPE_HIGH-3:`INBD_HDR_PNP_RANGE_TYPE_LOW-3]} ==      `CFGWR0 )
                        ||  ({hdr_in[`INBD_HDR_PNP_RANGE_FMT_LOW-2:`INBD_HDR_PNP_RANGE_FMT_LOW-3],hdr_in[`INBD_HDR_PNP_RANGE_TYPE_HIGH-3:`INBD_HDR_PNP_RANGE_TYPE_LOW-3]} ==      `CFGWR1 )
                                                                                                                                                                                                                   );
end
endgenerate


// segment queue; oldest segment is at the top of the queue, empty segments are at the bottom of the queue
always@(posedge clk or negedge rstn)begin: R_SEG_SEQ_PROC
  integer i,j;
  if(!rstn)begin
    for(i=0;i<SEGNUM;i=i+1)begin
      r_seg_num[i]      <= #TP i;
      r_seg_pseq_num[i] <= #TP '0; 
    end
    r_seg_active        <= #TP '0;
    r_seg_scheduled     <= #TP '0;
    r_seg_req_w_data    <= #TP '0;
    r_seg_errored       <= #TP '0;
  end else begin
    for(j=0;j<SEGNUM;j=j+1)begin
      r_seg_num[j]      <= #TP s_seg_num[j];
      r_seg_pseq_num[j] <= #TP s_seg_pseq_num[j]; 
    end
    r_seg_active        <= #TP s_seg_active;
    r_seg_scheduled     <= #TP s_seg_scheduled;
    r_seg_req_w_data    <= #TP s_seg_req_w_data;
    r_seg_errored       <= #TP s_seg_errored;
  end
end

generate
if(SEGDEPTH>1)begin: GEN_SEG_LENGTH_SEQ
always@(posedge clk or negedge rstn)begin: R_SEG_LENGTH_SEQ_PROC
  integer i,j;
  if(!rstn)begin
    for(i=0;i<SEGNUM;i=i+1)begin
      r_seg_length[i] <= #TP 0;
    end
  end else begin
    for(j=0;j<SEGNUM;j=j+1)begin
      r_seg_length[j] <= #TP s_seg_length[j];
    end
  end
end
end
endgenerate

// pointer to location where consumed segment needs to be pushed
always@(*)begin: S_PUSH_CONSUMED_COMB_PROC
  integer i;
  s_push_consumed_segment = '0;
  for(i=0;i<SEGNUM;i=i+1)begin
    if(s_segment_consumed)begin                                                 // If segment consumed (new request received)
      if(s_segment_released)begin                                               //   and segment released (request processed) on the same cycle
        if(i==SEGNUM-1)begin                                                    //     if the last segment
          if(r_seg_active[i])                                                   //       is active
            s_push_consumed_segment[i] = 1;                                     //         new request is pushed into end of queue
        end else begin                                                          //     else (last segment is free)
          if(r_seg_active[i] && !r_seg_active[i+1])                             //       find the last active segment in the queue
            s_push_consumed_segment[i] = 1;                                     //         and push new request into its location
        end                                                                     //
      end else begin                                                            //   else (no segment released)
        if(i==0)begin                                                           //     if the first segment
          if(!r_seg_active[i])                                                  //       is not active
            s_push_consumed_segment[i] = 1;                                     //         consumed segment (new request) is pushed into top of queue
        end else begin                                                          //     else
          if(r_seg_active[i-1] && !r_seg_active[i])                             //       find location of the last active segment
            s_push_consumed_segment[i] = 1;                                     //         and push consumed segment (new request) into the following location
        end
      end
    end
  end
end

// pointer to location where released segment needs to be pushed
always@(*)begin: S_PUSH_RELEASED_SEGMENT_COMB_PROC
  integer i;
  s_push_released_segment = '0;
  for(i=0;i<SEGNUM;i=i+1)begin
    if(s_segment_released)begin                                                 // If segment released (request processed)
      if(s_segment_consumed)begin                                               //   and segment consumed (new request received) on the same cycle
        if(i>0)                                                                 //     if not the first segment
          if(r_seg_active[i-1] && !r_seg_active[i])                             //       find the first inactive segment in the queue
            s_push_released_segment[i] = 1;                                     //         and push released segment into its location
      end else begin                                                            //   else (no segment consumed)
        if(i==SEGNUM-1)begin                                                    //     if the last segment
          if(r_seg_active[i])                                                   //       is active
            s_push_released_segment[i] = 1;                                     //         released segment is pushed into the last position in the queue
        end else begin                                                          //     else
          if(r_seg_active[i] && !r_seg_active[i+1])                             //       find location of the last active segment
            s_push_released_segment[i] = 1;                                     //         and push released segment into that location
        end
      end
    end
  end
end

// Active segments need to be shifted up whenever a segment is released (request processed)
always@(*)begin
  integer i;
  s_shift_consumed_segments_up = '0;
  for(i=0;i<SEGNUM;i=i+1)begin
    if(s_segment_released)                                                      // If segment released (request processed)
      if(i>s_released_segment_index && r_seg_active[i])                         //  if segment is after released segment location and is active
        s_shift_consumed_segments_up[i] = 1;                                    //    shift segment up
  end
end

// Released (inactive) segments need to be shifted down whenever a segment is consumed (new request received)
always@(*)begin: S_SHIFT_RELEASED_SEGMENTS_DOWN_COMB_PROC
  integer i;
  s_shift_released_segments_down = '0;
  for(i=0;i<SEGNUM;i=i+1)begin
    if(s_segment_consumed)                                                      // If segment consumed (new request received)
      if(!r_seg_active[i])                                                      //   if segment is released (not active)
        s_shift_released_segments_down[i] = 1;                                  //     shift segment down
  end
end

assign s_ro_req  =  hdr_in[`INBD_HDR_PNP_RANGE_ATTR_LOW-2];
assign s_dma_req = |hdr_in[`INBD_HDR_PNP_RANGE_REQ_DMA_HIGH-2:`INBD_HDR_PNP_RANGE_REQ_DMA_LOW-2];

assign s_dllp_abort_in = hdr_in[`INBD_HDR_PNP_RANGE_DLLP_ABORT_LOW-3];
assign s_tlp_abort_in  = hdr_in[`INBD_HDR_PNP_RANGE_TLP_ABORT_LOW-3];
assign s_errored_req   = s_dllp_abort_in || s_tlp_abort_in;
assign s_dropped_req   = P_NP_BUFFER ? s_dllp_abort_in : s_dllp_abort_in || s_tlp_abort_in;

// Detect RO P followed by SO P condition; if enhanced ordering is enabled a SO P must wait for the preceding RO P to complete
generate
if(P_NP_BUFFER)begin: GEN_PREVIOUS_P_IS_RO
always@(posedge clk or negedge rstn)begin: R_PREVIOUS_P_IS_RO_SEQ_PROC
  if(!rstn)begin
    r_previous_p_is_ro   <= #TP 0;
    r_previous_p_seq_num <= #TP 0;
  end else begin
    if(eot_in && !s_dropped_req && !halt_out && !s_dma_req)begin
      r_previous_p_is_ro   <= #TP hdr_in[`INBD_HDR_PNP_RANGE_ATTR_LOW-2];
      r_previous_p_seq_num <= #TP pseq_num_in;
    end
  end
end
assign s_previous_p_is_ro   = r_previous_p_is_ro;
assign s_previous_p_seq_num = r_previous_p_seq_num;
end else begin
assign s_previous_p_is_ro   = '0;
assign s_previous_p_seq_num = '0;
end
endgenerate

// Updating request queue
always@(*)begin: S_SEG_COMB_PROC

  integer i,j,k;

  reg [CC_AMBA_TLP_SEQ_WD-1:0] tmp_seg_pseq_num;
  reg [CC_AMBA_TLP_SEQ_WD-1:0] tmp_last_presp_pseq_per_vc;
  reg [CC_AMBA_TLP_SEQ_WD-1:0] tmp_last_req_pseq_per_vc;
  reg                          tmp_p_xfer_pend_per_vc;
  reg                          tmp_seg_scheduled;

  reg [CC_AMBA_TLP_SEQ_WD-1:0] tmp_max_pseq;
  reg                          tmp_range_reversal;
  reg [CC_AMBA_TLP_SEQ_WD-1:0] tmp_p_pseq_upper_lim;
  reg [CC_AMBA_TLP_SEQ_WD-1:0] tmp_p_pseq_lower_lim;


  for(i=0; i<SEGNUM;i=i+1)begin
    s_seg_num[i]      = r_seg_num[i];
    s_seg_pseq_num[i] = r_seg_pseq_num[i]; 
  end
  s_seg_active     = r_seg_active;
  s_seg_scheduled  = r_seg_scheduled;
  s_seg_req_w_data = r_seg_req_w_data;
  s_seg_errored    = r_seg_errored;

  for(j=0;j<SEGNUM;j=j+1)begin
    if(s_segment_consumed)begin
      if(s_push_consumed_segment[j])begin
        s_seg_num[j]          = s_consumed_segment;
        s_seg_active[j]       = 1;
        s_seg_pseq_num[j]     = P_NP_BUFFER ? ( cfg_enhanced_ordering_en ?  s_previous_p_seq_num                           : pseq_num_in ) : pseq_num_in; 
        s_seg_scheduled[j]    = P_NP_BUFFER ? ( cfg_enhanced_ordering_en ? !s_previous_p_is_ro || s_ro_req || s_dma_req: 1'b1 ) : cfg_ax_mstr_np_pass_p[0]         || (s_ro_req && !s_ro_disable) || s_dma_req;
        s_seg_req_w_data[j]   = dv_in;
        s_seg_errored[j]      = P_NP_BUFFER ? s_errored_req : 1'b0;
      end
      if((j!=(SEGNUM-1)) && s_shift_released_segments_down[j])begin
        s_seg_num[j+1]        = r_seg_num[j];
        s_seg_active[j+1]     = '0;
        s_seg_pseq_num[j+1]   = '0; 
        s_seg_scheduled[j+1]  = '0;
        s_seg_req_w_data[j+1] = '0;
        s_seg_errored[j+1]    = '0;
      end
    end
    if(s_segment_released)begin
      if(s_push_released_segment[j])begin
        s_seg_num[j]          = s_released_segment;
        s_seg_active[j]       = '0;
        s_seg_pseq_num[j]     = '0; 
        s_seg_scheduled[j]    = '0;
        s_seg_req_w_data[j]   = '0;
        s_seg_errored[j]      = '0;
      end
      if((j!=0) && s_shift_consumed_segments_up[j])begin
        s_seg_num[j-1]        = r_seg_num       [j];
        s_seg_active[j-1]     = r_seg_active    [j];
        s_seg_pseq_num[j-1]   = r_seg_pseq_num  [j]; 
        s_seg_scheduled[j-1]  = r_seg_scheduled [j];
        s_seg_req_w_data[j-1] = r_seg_req_w_data[j];
        s_seg_errored[j-1]    = r_seg_errored   [j];
      end    
    end
  end

  for(k=0;k<SEGNUM;k=k+1)begin

    tmp_seg_scheduled               = 0;
    tmp_seg_pseq_num                = s_seg_pseq_num[k];
    tmp_p_xfer_pend_per_vc          = trgt1_p_xfer_pend_per_vc;
    tmp_last_presp_pseq_per_vc      = !P_NP_BUFFER && !s_seg_req_w_data[k] ? ibreq_cfg_rpseq : ibreq_presp_rpseq ; // A NP request without data is a read request
    tmp_last_req_pseq_per_vc        = last_req_pseq ;
                                                                                                        // Request is released if:
//    tmp_seg_scheduled          = ((tmp_seg_pseq_num <= tmp_last_presp_pseq_per_vc                 ) ||  // sequence number is lower than or equal to last completed P or
//                                  (tmp_seg_pseq_num >= tmp_last_req_pseq_per_vc + RADM_P_QUEUE_DP ));   // sequence number is higher than or equal to last received P + RADM posted queue depth
//                                  (tmp_last_presp_pseq_per_vc == tmp_last_req_pseq_per_vc         ));   // last received and completed P sequence numbers match (no outstanding P requests)

    tmp_max_pseq         =   tmp_last_req_pseq_per_vc + CC_GEN6_AXI_MAX_P_DELAY;
    tmp_range_reversal   = ( tmp_last_presp_pseq_per_vc[CC_AMBA_TLP_SEQ_WD-1] == 1 ) && ( tmp_max_pseq[CC_AMBA_TLP_SEQ_WD-1] == 0 );
    tmp_p_pseq_upper_lim = tmp_range_reversal ? {!tmp_max_pseq              [CC_AMBA_TLP_SEQ_WD-1],tmp_max_pseq              [CC_AMBA_TLP_SEQ_WD-2:0]} : tmp_max_pseq;
    tmp_p_pseq_lower_lim = tmp_range_reversal ? {!tmp_last_presp_pseq_per_vc[CC_AMBA_TLP_SEQ_WD-1],tmp_last_presp_pseq_per_vc[CC_AMBA_TLP_SEQ_WD-2:0]} : tmp_last_presp_pseq_per_vc;
    tmp_seg_pseq_num     = tmp_range_reversal ? {!s_seg_pseq_num[k]         [CC_AMBA_TLP_SEQ_WD-1],s_seg_pseq_num[k]         [CC_AMBA_TLP_SEQ_WD-2:0]} : s_seg_pseq_num[k];
                                                                                               // Request is released if:
    tmp_seg_scheduled          = ( tmp_seg_pseq_num           <= tmp_p_pseq_lower_lim     ) || // sequence number is lower than or equal to last completed P or
                                 ( tmp_seg_pseq_num           >  tmp_p_pseq_upper_lim     ) || // sequence number is higher than or equal to last received P + RADM posted queue depth or
                                 ( !P_NP_BUFFER && !tmp_p_xfer_pend_per_vc                ) ;  // there are no outstanding P requests in the RADM or AXI bridge

    if(s_seg_active[k] && tmp_seg_scheduled)
      s_seg_scheduled[k] = 1'b1;
  end

end

// Update seg_length separately because it is only required if segment is deeper than 1
generate
if(SEGDEPTH>1)begin: GEN_SEG_LENGTH_COMB
always@(*)begin: S_SEG_LENGTH_COMB_PROC

  integer i,j;
  
  for(i=0; i<SEGNUM;i=i+1)begin
    s_seg_length[i] = r_seg_length[i];
  end

  for(j=0;j<SEGNUM;j=j+1)begin
    if(s_segment_consumed)begin
      if(s_push_consumed_segment[j])begin
        s_seg_length[j]       = s_errored_req ? '0 : r_seg_wr_addr;
      end
      if((j!=(SEGNUM-1)) && s_shift_released_segments_down[j])begin
        s_seg_length[j+1]     = '0;
      end
    end
    if(s_segment_released)begin
      if(s_push_released_segment[j])begin
        s_seg_length[j]       = '0;
      end
      if((j!=0) && s_shift_consumed_segments_up[j])begin
        s_seg_length[j-1]     = r_seg_length    [j];
      end    
    end
  end
end
end
endgenerate

assign s_consumed_segment  =  r_seg_num   [SEGNUM-1];
assign s_segment_available = !r_seg_active[SEGNUM-1];

// Write logic

generate
if(SEGDEPTH>1)begin: GEN_SEG_WR_ADDR
always@(posedge clk or negedge rstn)begin: R_SEG_WR_ADDR_SEQ_PROC
  if(!rstn)begin
    r_seg_wr_addr <= #TP '0;
  end else begin
    r_seg_wr_addr <= #TP s_seg_wr_addr;
  end   
end

always@(*)begin: S_SEG_WR_ADDR_COMB_PROC
  s_seg_wr_addr = r_seg_wr_addr;
  
  if(eot_in)begin
    s_seg_wr_addr = '0;
  end else begin
    if(dv_in && !halt_out)
      s_seg_wr_addr = r_seg_wr_addr + 1;
  end
end
end
endgenerate

assign s_segment_consumed =  eot_in && !s_dropped_req && !halt_out;
assign halt_out           = !s_segment_available;


assign addr_in = hdr_in[`INBD_HDR_PNP_RANGE_ADDR_HIGH-3:`INBD_HDR_PNP_RANGE_ADDR_LOW-3]; //spyglass disable SelfDeterminedExpr-ML

assign addr_in_chk_en = hv_in && !halt_out;

   ras_dp_pipe
    #(
    .PIPELINE_TYPE             (0                            ),
    .RESETVAL                  (0                            ),
    .N_STAGES                  (0                            ),
    .CAN_STALL                 (0                            ),
    .RESET_STALL               (0                            ),
    .BUS_PROTECT_GEN_EN        (0                            ),
    .BUS_PROTECT_CHK_EN        (1                            ),
    .PROT_TYPE                 (1                            ), // parity
    .PROT_RANGE                (CX_RAS_PROT_RANGE            ),
    .PROT_WD                   (NUM_ADDR_PAR_BLOCKS          ),
    .PARITY_MODE               (CX_RAS_PARITY_MODE           ),
    .PROT_CORRECT_EN           (0                            ),
    .TOTAL_WIDTH               (ADDR_WD_NP                   ),
    .EXCLUDE_PROT_WIDTH        (0                            ),
    .RAS_DP_PROT_CHK_ID_BASE   (HDR_RAS_DP_ID                )
  ) u_hdr_chk (
    .clk                       ( clk                         ),
    .rst_n                     ( rstn                        ),
    .din                       ( fn_addr_wo_par (addr_in)    ),
    .din_prot                  ( fn_prot_chkin_ad(addr_in)   ),
    .dout                      (  /* Not connected */        ),
    .dout_prot                 (  /* Not connected */        ),
    .en                        (1'b1                         ),
    .bypass                    (1'b0                         ),
    .stall                     (1'b0                         ),
    .stallout                  (  /* Not connected */        ),
    .valid_in                  ( addr_in_chk_en              ),
    .halt_out                  (  /* Not connected */        ),
    .valid_out                 (  /* Not connected */        ),
    .halt_in                   (1'b0                         ),
    .ras_dp_err_inband_kbd_in  (1'b0                         ),
    .ras_dp_err_inband_kbd_out (  /* Not connected */        ),
    .ras_dp_err_log            ( axi_ib_sch_ad_ras_dp_err_log)
      ,
      .ras_dp_err_inj          (core_clk_ordrb_ras_dp_err_inj)
    );

  assign axi_ras_par_ib_sch_ad_pulse = axi_ib_sch_ad_ras_dp_err_log.valid;


   assign s_hdr_in_np  = {
                          hdr_in[HDR_WD-1:`INBD_HDR_PNP_RANGE_ADDR_HIGH-2], //spyglass disable SelfDeterminedExpr-ML
                          fn_addr_wo_par(addr_in),
                          hdr_in[`INBD_HDR_PNP_RANGE_ADDR_LOW-4:0] //spyglass disable SelfDeterminedExpr-ML
                         };

assign data_in_chk_en = dv_in && !halt_out;

   ras_dp_pipe
    #(
    .PIPELINE_TYPE             (0                            ),
    .RESETVAL                  (0                            ),
    .N_STAGES                  (0                            ),
    .CAN_STALL                 (0                            ),
    .RESET_STALL               (0                            ),
    .BUS_PROTECT_GEN_EN        (0                            ),
    .BUS_PROTECT_CHK_EN        (1                            ),
    .PROT_TYPE                 (1                            ), // parity
    .PROT_RANGE                (CX_RAS_PROT_RANGE            ),
    .PROT_WD                   (NUM_DATA_PAR_BLOCKS          ),
    .PARITY_MODE               (CX_RAS_PARITY_MODE           ),
    .PROT_CORRECT_EN           (0                            ),
    .TOTAL_WIDTH               (DATA_WD_NP                   ),
    .EXCLUDE_PROT_WIDTH        (0                            ),
    .RAS_DP_PROT_CHK_ID_BASE   (DT_RAS_DP_ID                 )
  ) u_data_chk (
    .clk                       ( clk                         ),
    .rst_n                     ( rstn                        ),
    .din                       ( fn_data_wo_par (data_in)    ),
    .din_prot                  ( fn_prot_chkin_d(data_in)    ),
    .dout                      (  /* Not connected */        ),
    .dout_prot                 (  /* Not connected */        ),
    .en                        (1'b1                         ),
    .bypass                    (1'b0                         ),
    .stall                     (1'b0                         ),
    .stallout                  (  /* Not connected */        ),
    .valid_in                  ( data_in_chk_en              ),
    .halt_out                  (  /* Not connected */        ),
    .valid_out                 (  /* Not connected */        ),
    .halt_in                   (1'b0                         ),
    .ras_dp_err_inband_kbd_in  (1'b0                         ),
    .ras_dp_err_inband_kbd_out (  /* Not connected */        ),
    .ras_dp_err_log            ( axi_ib_sch_dt_ras_dp_err_log)
      ,
      .ras_dp_err_inj          (core_clk_ordrb_ras_dp_err_inj)
    );

  assign axi_ras_par_ib_sch_dt_pulse = axi_ib_sch_dt_ras_dp_err_log.valid;


   assign s_data_in_np =  fn_data_wo_par(data_in);

  //
  // RAS Generation stage - Calculate the RAM ECC
  //

   // Generator
   ras_dp_pipe
    #(
     .PIPELINE_TYPE             (0                                    ), // 0: delay_n
     .RESETVAL                  (0                                    ),
     .N_STAGES                  (0                                    ),
     .CAN_STALL                 (0                                    ),
     .RESET_STALL               (0                                    ),
     .BUS_PROTECT_GEN_EN        (1                                    ),  // 0: Bus Protection Generator is not present
     .BUS_PROTECT_CHK_EN        (0                                    ),  // 1: Bus Protection Checker is present (ECC/Parity)
     .PROT_TYPE                 (0                                    ),  // 0=Ecc, 1=Simple Parity
     .PROT_RANGE                (RAS_RAM_PROT_RANGE                   ), // Number of bits to calculate parity/ECC on
     .PROT_WD                   (HDR_RAM_ECC_WD                       ),
     .PARITY_MODE               (RAS_PARITY_MODE                      ),
     .PROT_CORRECT_EN           (0                                    ), // 0: no correction on single-errors, 1: correction on single-errors
     .TOTAL_WIDTH               ( HDR_RAM_ADDR_WD + HDR_WD_NP         ), // RAM_ADDR_WIDTH + DATA_WIDTH
     .EXCLUDE_PROT_WIDTH        (0                                    ),
     .RAS_DP_PROT_CHK_ID_BASE   ( /* NC */                            ),
     .ADDR_ECC_PROT_EN          (1                                    ),
     .ADDR_LOG_EN               (1                                    ),
     .ADDR_INDEX                (HDR_WD_NP                            ),
     .ADDR_WD                   (HDR_RAM_ADDR_WD                      )
   ) u_eccg_hdr (
     .clk                       ( clk                                 ),
     .rst_n                     ( rstn                                ),
     .din                       ( {i_hdr_ram_addra, s_hdr_in_np}      ),
     .din_prot                  ( {HDR_RAM_ECC_WD{1'b0}}              ),
     .dout                      ( /* NC */                            ),
     .dout_prot                 ( eccg_hdr_in                         ),
     .en                        ( 1'b1                                ),
     .bypass                    ( 1'b0                                ),
     .stall                     ( 1'b0                                ),
     .stallout                  ( /* Not Connected */                 ),
     .valid_in                  ( i_hdr_ram_wea                       ),
     .halt_out                  ( /* Not Connected */                 ),
     .valid_out                 ( /* Not Connected */                 ),
     .halt_in                   (1'b0                                 ),
     .ras_dp_err_inband_kbd_in  (1'b0                                 ),
     .ras_dp_err_inband_kbd_out ( /* Not Connected */                 ),
     .ras_dp_err_log            ( /* Not Connected */                 )
       ,
       .ras_dp_err_inj          ( {(RAS_DP_ERR_LOG_WD){1'b0}}       )
     );

   ras_dp_pipe
    #(
     .PIPELINE_TYPE             (0                                    ), // 0: delay_n
     .RESETVAL                  (0                                    ),
     .N_STAGES                  (0                                    ),
     .CAN_STALL                 (0                                    ),
     .RESET_STALL               (0                                    ),
     .BUS_PROTECT_GEN_EN        (1                                    ),  // 0: Bus Protection Generator is not present
     .BUS_PROTECT_CHK_EN        (0                                    ),  // 1: Bus Protection Checker is present (ECC/Parity)
     .PROT_TYPE                 (0                                    ),  // 0=Ecc, 1=Simple Parity
     .PROT_RANGE                (RAS_RAM_PROT_RANGE                   ), // Number of bits to calculate parity/ECC on
     .PROT_WD                   (DATA_RAM_ECC_WD                      ),
     .PARITY_MODE               (RAS_PARITY_MODE                      ),
     .PROT_CORRECT_EN           (0                                    ), // 0: no correction on single-errors, 1: correction on single-errors
     .TOTAL_WIDTH               (DATA_RAM_ADDR_WD + DATA_WD_NP        ), // RAM_ADDR_WIDTH + DATA_WIDTH
     .EXCLUDE_PROT_WIDTH        (0                                    ),
     .RAS_DP_PROT_CHK_ID_BASE   ( /* NC */                            ),
     .ADDR_ECC_PROT_EN          (1                                    ),
     .ADDR_LOG_EN               (1                                    ),
     .ADDR_INDEX                (DATA_WD_NP                           ),
     .ADDR_WD                   (DATA_RAM_ADDR_WD                     )
   ) u_eccg_data (
     .clk                       ( clk                                 ),
     .rst_n                     ( rstn                                ),
     .din                       ( {i_data_ram_addra, s_data_in_np}    ),
     .din_prot                  ( {DATA_RAM_ECC_WD{1'b0}}             ),
     .dout                      ( /* NC */                            ),
     .dout_prot                 ( eccg_data_in                        ),
     .en                        ( 1'b1                                ),
     .bypass                    ( 1'b0                                ),
     .stall                     ( 1'b0                                ),
     .stallout                  ( /* Not Connected */                 ),
     .valid_in                  ( i_data_ram_wea                      ),
     .halt_out                  ( /* Not Connected */                 ),
     .valid_out                 ( /* Not Connected */                 ),
     .halt_in                   (1'b0                                 ),
     .ras_dp_err_inband_kbd_in  (1'b0                                 ),
     .ras_dp_err_inband_kbd_out ( /* Not Connected */                 ),
     .ras_dp_err_log            ( /* Not Connected */                 )
       ,
       .ras_dp_err_inj          ({(RAS_DP_ERR_LOG_WD){1'b0}}          )
     );



  assign s_hdr_in  = {eccg_hdr_in , s_hdr_in_np };
  assign s_data_in = {eccg_data_in, s_data_in_np};


assign i_data_ram_wea   = dv_in && !halt_out;
generate
if(SEGDEPTH>1)begin: GEN_DATA_RAM_ADDRA
assign i_data_ram_addra = {r_seg_num[SEGNUM-1],r_seg_wr_addr};
end else begin
assign i_data_ram_addra = r_seg_num[SEGNUM-1];
end 
endgenerate
assign i_data_ram_dina  = s_data_in;

assign i_hdr_ram_wea    = s_segment_consumed;
assign i_hdr_ram_addra  = r_seg_num[SEGNUM-1];
assign i_hdr_ram_dina   = s_hdr_in;

//
// Pipeline RAM write interface signals
//
generate
if (RAM_REG_IN == 0) begin : gen_ram_wr_not_reg_in
  always @(*) begin : proc_comb_ram_intf
    hdr_ram_wea        = i_hdr_ram_wea;
    hdr_ram_addra      = i_hdr_ram_addra;
    hdr_ram_dina       = i_hdr_ram_dina;

    data_ram_wea       = i_data_ram_wea;
    data_ram_addra     = i_data_ram_addra;
    data_ram_dina      = i_data_ram_dina;
  end
end else begin : gen_ram_wr_reg_in
  always @(posedge clk or negedge rstn) begin : proc_seq_ram_intf
    if (!rstn) begin
      hdr_ram_wea        <= #TP '0;
      hdr_ram_addra      <= #TP '0;
      hdr_ram_dina       <= #TP '0;

      data_ram_wea       <= #TP '0;
      data_ram_addra     <= #TP '0;
      data_ram_dina      <= #TP '0;
    end else begin
      hdr_ram_wea          <= #TP i_hdr_ram_wea;
      if(i_hdr_ram_wea)begin
        hdr_ram_addra      <= #TP i_hdr_ram_addra;
        hdr_ram_dina       <= #TP i_hdr_ram_dina;
      end

      data_ram_wea         <= #TP i_data_ram_wea;
      if(i_data_ram_wea)begin
        data_ram_addra     <= #TP i_data_ram_addra;
        data_ram_dina      <= #TP i_data_ram_dina;
      end
    end
  end   
end
endgenerate

/*
     Read control logic
*/

generate
if(!P_NP_BUFFER)begin: GEN_S_RELEASED_SEGMENT
// If NP instance find the oldest scheduled request
  DWC_pcie_bridge_binsearch
  
   #(
     .ARRAY_DP  ( SEGNUM      ),
     .ARRAY_WD  ( SEGNUM_LOG2 ),
     .INDEX_WD  ( SEGNUM_LOG2 )
    ) u_binsearch (
     .valid_in    ( r_seg_active & r_seg_scheduled ),
     .array_in    ( r_seg_num                      ),
     .valid_out   ( i_released_segment_valid       ),
     .index_out   ( i_released_segment_index       ),
     .element_out ( i_released_segment             )
    );

always @(posedge clk or negedge rstn) begin: SEQ_R_RELEASED_SEGMENT_PROC
  if(!rstn)begin
    r_released_segment_valid <= #TP '0;
    r_released_segment_index <= #TP '0;
    r_released_segment       <= #TP '0;
  end else begin
    if(s_segment_released)begin
      r_released_segment_valid <= #TP '0;
      r_released_segment_index <= #TP '0;
      r_released_segment       <= #TP '0;
    end else begin
      if(!r_released_segment_valid && i_released_segment_valid && !s_ltcy_halt)begin
        r_released_segment_valid <= #TP i_released_segment_valid;
        r_released_segment_index <= #TP i_released_segment_index;
        r_released_segment       <= #TP i_released_segment;
      end
    end
  end
end

assign s_released_segment_valid = cfg_enhanced_ordering_en ? (r_released_segment_valid ? r_released_segment_valid : i_released_segment_valid) : r_seg_active[0];
assign s_released_segment_index = cfg_enhanced_ordering_en ? (r_released_segment_valid ? r_released_segment_index : i_released_segment_index) : '0;
assign s_released_segment       = cfg_enhanced_ordering_en ? (r_released_segment_valid ? r_released_segment       : i_released_segment      ) : r_seg_num[0];

end else begin
// If P instance always release from the top of the queue
assign s_released_segment_valid = r_seg_active[0] && r_seg_scheduled[0];
assign s_released_segment_index = '0;
assign s_released_segment       = r_seg_num[0];
end
endgenerate


generate
if(SEGDEPTH>1)begin: GEN_S_SEGMENT_RELEASED
assign s_segment_released = s_released_segment_valid && r_seg_active[s_released_segment_index] && !s_ltcy_halt && ((r_seg_rd_addr == r_seg_length[s_released_segment_index]) || !r_seg_req_w_data[s_released_segment_index]);
end else begin
assign s_segment_released = s_released_segment_valid && r_seg_active[s_released_segment_index] && !s_ltcy_halt;
end
endgenerate


assign i_hdr_ram_addrb      = s_released_segment;
generate
if(SEGDEPTH>1)begin: GEN_RAM_RD_INTERFACE
assign i_hdr_ram_enb        = s_released_segment_valid && r_seg_active[s_released_segment_index] && !s_ltcy_halt && r_seg_rd_addr == '0;
assign i_data_ram_addrb     = {s_released_segment,r_seg_rd_addr};
end else begin
assign i_hdr_ram_enb        = s_released_segment_valid && r_seg_active[s_released_segment_index] && !s_ltcy_halt;
assign i_data_ram_addrb     = s_released_segment;
end
endgenerate
assign i_data_ram_enb       = s_released_segment_valid && r_seg_active[s_released_segment_index] && r_seg_req_w_data[s_released_segment_index] && !s_ltcy_halt;


generate
if(SEGDEPTH>1)begin: GEN_SEG_RD_ADDR
always@(posedge clk or negedge rstn)begin: R_SEG_RD_ADDR_SEQ_PROC
  if(!rstn)begin
    r_seg_rd_addr <= #TP '0;
  end else begin
    r_seg_rd_addr <= #TP s_seg_rd_addr;
  end
end

always@(*)begin: S_SEG_RD_ADDR_COMB_PROC
  s_seg_rd_addr = r_seg_rd_addr;

  if(s_segment_released)begin
    s_seg_rd_addr = '0;
  end else begin
    if(i_data_ram_enb)
      s_seg_rd_addr = r_seg_rd_addr + 1;
  end
end
end
endgenerate


assign i_hv_out  = i_hdr_ram_enb;
assign i_dv_out  = i_data_ram_enb;
generate
if(SEGDEPTH>1)begin: GEN_S_EOT_OUT
assign i_eot_out = r_seg_req_w_data[s_released_segment_index] ? i_data_ram_enb && r_seg_rd_addr == r_seg_length[s_released_segment_index] : i_hdr_ram_enb;
end else begin
assign i_eot_out = i_hdr_ram_enb;
end
endgenerate


/*
    Pipeline RAM interface signals
*/

generate
if (RAM_REG_IN == 0) begin : gen_ram_rd_not_reg_in
always @(*) begin : proc_comb_ram_intf
  hdr_ram_addrb      = i_hdr_ram_addrb;
  hdr_ram_enb        = i_hdr_ram_enb;

  data_ram_addrb     = i_data_ram_addrb;
  data_ram_enb       = i_data_ram_enb;
end
end else begin : gen_ram_rd_reg_in
always @(posedge clk or negedge rstn) begin : proc_seq_ram_intf
  if (!rstn) begin
    hdr_ram_addrb      <= #TP '0;
    hdr_ram_enb        <= #TP '0;

    data_ram_addrb     <= #TP '0;
    data_ram_enb       <= #TP '0;
  end else begin
    hdr_ram_addrb        <= #TP i_hdr_ram_addrb;
    hdr_ram_enb          <= #TP i_hdr_ram_enb;

    data_ram_addrb       <= #TP i_data_ram_addrb;
    data_ram_enb         <= #TP i_data_ram_enb;
  end
end   
end
endgenerate

/*
    Delay read addresses for the sake of address reporting
*/
  delay_n
   #(
      .WD       ( HDR_RAM_ADDR_WD                 ),
      .N        ( RAM_RD_LATENCY + RAM_RD_REG_OUT )
  ) u_dly_hdr_rdaddr (
      .clk      ( clk                ),
      .rst_n    ( rstn               ),
      .clear    ( 1'b0               ),
      .din      ( hdr_ram_addrb      ),
      .dout     ( dly_hdr_ram_addrb  )
  );

  delay_n
   #(
      .WD       ( DATA_RAM_ADDR_WD                ),
      .N        ( RAM_RD_LATENCY + RAM_RD_REG_OUT )
  ) u_dly_data_rdaddr (
      .clk      ( clk                ),
      .rst_n    ( rstn               ),
      .clear    ( 1'b0               ),
      .din      ( data_ram_addrb     ),
      .dout     ( dly_data_ram_addrb )
  );


/*
    Pipeline RAM output data
*/

generate
if (RAM_RD_REG_OUT == 0) begin : gen_ram_not_reg_out
  always @(*) begin : proc_comb_ram_reg_out
    s_hdr_ram_enb    = hdr_ram_enb;
    s_hdr_ram_doutb  = hdr_ram_doutb;
    s_data_ram_enb   = data_ram_enb;
    s_data_ram_doutb = data_ram_doutb;
  end
end else begin : gen_ram_reg_out
  always @(posedge clk or negedge rstn) begin : proc_seq_ram_reg_out
    if (!rstn) begin
      s_hdr_ram_enb    <= #TP '0;
      s_hdr_ram_doutb  <= #TP '0;
      s_data_ram_enb   <= #TP '0;
      s_data_ram_doutb <= #TP '0;
    end else begin
      s_hdr_ram_enb    <= #TP hdr_ram_enb;
      s_hdr_ram_doutb  <= #TP hdr_ram_doutb;
      s_data_ram_enb   <= #TP data_ram_enb;
      s_data_ram_doutb <= #TP data_ram_doutb;
    end
  end
end
endgenerate

/*
    Delay control signals to align with RAM data output
*/

  delay_n
   #(
      .WD       ( 3                                   ),
      .N        ( RAM_REG_IN + RAM_RD_LATENCY + RAM_RD_REG_OUT )
  ) u_dly_ctl_0 (
      .clk      ( clk       ),
      .rst_n    ( rstn      ),
      .clear    ( 1'b0      ),
      .din      ( {i_eot_out, i_dv_out, i_hv_out } ),
      .dout     ( {d_eot_out, d_dv_out, d_hv_out} )
  );

/*
    Hold data between pop requests. Allows the RAM read port to be disabled
*/

  always @(posedge clk or negedge rstn) begin : SEQ_R_HDR_RAM_DOUTB_PROC
    if (!rstn) begin
      r_hdr_ram_doutb <= # TP '0;
    end else begin
      if (d_hv_out)
        r_hdr_ram_doutb <= # TP s_hdr_ram_doutb;
    end
  end

  always @(posedge clk or negedge rstn) begin : SEQ_R_DATA_RAM_DOUTB_PROC
    if (!rstn) begin
      r_data_ram_doutb <= # TP '0;
    end else begin
      if (d_dv_out)
        r_data_ram_doutb <= # TP s_data_ram_doutb;
    end
  end

  assign s2_hdr_ram_doutb  = d_hv_out ? s_hdr_ram_doutb  : r_hdr_ram_doutb ;
  assign s2_data_ram_doutb = d_dv_out ? s_data_ram_doutb : r_data_ram_doutb;

  //
  // RAS ECC checking
  //
  assign cfg_hq_ras_recc_correct_n = ~cfg_hq_ras_recc_correct;
  assign hq_ras_recc_cnt_addr      = dly_hdr_ram_addrb;


  ras_dp_pipe
   #(
    .PIPELINE_TYPE             (0                                   ), // 0: delay_n
    .RESETVAL                  (0                                   ),
    .N_STAGES                  (0                                   ),
    .CAN_STALL                 (0                                   ),
    .RESET_STALL               (0                                   ),
    .BUS_PROTECT_GEN_EN        (0                                   ), // 0: Bus Protection Generator is not present
    .BUS_PROTECT_CHK_EN        (1                                   ), // 1: Bus Protection Checker is present (ECC/Parity)
    .PROT_TYPE                 (0                                   ), // 0=Ecc, 1=Simple Parity
    .PROT_RANGE                (RAS_RAM_PROT_RANGE                  ), // Number of bits to calculate parity/ECC on
    .PROT_WD                   (HDR_RAM_ECC_WD                      ), // With address include in ECC needs + 1
    .PARITY_MODE               (RAS_PARITY_MODE                     ),
    .PROT_CORRECT_EN           (1                                   ), // 0: no correction on single-errors, 1: correction on single-errors
    .TOTAL_WIDTH               (HDR_WD_NP + HDR_RAM_ADDR_WD         ),
    .EXCLUDE_PROT_WIDTH        (0                                   ),
    .RAS_DP_PROT_CHK_ID_BASE   (HQ_RAS_DP_ID                        ),
    .ADDR_ECC_PROT_EN          (1                                   ),
    .ADDR_LOG_EN               (1                                   ),
    .ADDR_INDEX                (HDR_WD_NP                           ),
    .ADDR_WD                   (HDR_RAM_ADDR_WD                     )
  ) u_echk_hdr (
    .clk                       ( clk                                ),
    .rst_n                     ( rstn                               ),
    .din                       ( {dly_hdr_ram_addrb,
                                  s2_hdr_ram_doutb[HDR_WD_NP-1:0] } ),
    .din_prot                  ( s2_hdr_ram_doutb[HDR_RAM_DATA_WD-1:HDR_WD_NP]),
    .dout                      ( {hdr_ram_addr_ras_dp_pipe,
                                  s3_hdr_ram_doutb_pipe}            ), //Data is corrected
    .dout_prot                 ( /* Not Connected */                ),
    .en                        (1'b1                                ),
    .bypass                    (1'b0                                ),
    .stall                     (1'b0                                ),
    .stallout                  ( /* Not Connected */                ),
    .valid_in                  (d_hv_out                            ),
    .halt_out                  ( /* Not Connected */                ),
    .valid_out                 ( /* Not Connected */                ),
    .halt_in                   (1'b0                                ),
    .ras_dp_err_inband_kbd_in  (1'b0                                ),
    .ras_dp_err_inband_kbd_out ( /* Not Connected */                ),
    .ras_dp_err_log            (hq_ras_recc_cnt_ras_dp_err_log      )
      ,
      .ras_dp_err_inj          (core_clk_ordrb_ras_dp_err_inj       )
    );

  // Extract and detect Error type (correctable) from ras_dp_pipe.log
  assign hq_ras_recc_corr_cnt_pulse   = (hq_ras_recc_cnt_ras_dp_err_log.log[RAS_ERROR_TYPE_INDEX +: RAS_ERROR_TYPE_WD] == CORRECTABLE) && d_hv_out;

  // Extract and detect Error type (Uncorrectable) from ras_dp_pipe.log
  assign hq_ras_recc_ucorr_cnt_pulse = (hq_ras_recc_cnt_ras_dp_err_log.log[RAS_ERROR_TYPE_INDEX +: RAS_ERROR_TYPE_WD] == UNCORRECTABLE) && d_hv_out;

  assign s3_hdr_ram_doutb = s3_hdr_ram_doutb_pipe;


  assign cfg_dq_ras_recc_correct_n = ~cfg_dq_ras_recc_correct;
  assign dq_ras_recc_cnt_addr      = dly_data_ram_addrb;


  ras_dp_pipe
   #(
    .PIPELINE_TYPE             (0                                 ), // 0: delay_n
    .RESETVAL                  (0                                 ),
    .N_STAGES                  (0                                 ),
    .CAN_STALL                 (0                                 ),
    .RESET_STALL               (0                                 ),
    .BUS_PROTECT_GEN_EN        (0                                 ),  // 0: Bus Protection Generator is not present
    .BUS_PROTECT_CHK_EN        (1                                 ),  // 1: Bus Protection Checker is present (ECC/Parity)
    .PROT_TYPE                 (0                                 ),  // 0=Ecc, 1=Simple Parity
    .PROT_RANGE                (RAS_RAM_PROT_RANGE                ), // Number of bits to calculate parity/ECC on
    .PROT_WD                   (DATA_RAM_ECC_WD                   ),
    .PARITY_MODE               (RAS_PARITY_MODE                   ),
    .PROT_CORRECT_EN           (1                                 ), // 0: no correction on single-errors, 1: correction on single-errors
    .TOTAL_WIDTH               (DATA_WD_NP + DATA_RAM_ADDR_WD     ),
    .EXCLUDE_PROT_WIDTH        (0                                 ),
    .RAS_DP_PROT_CHK_ID_BASE   (DQ_RAS_DP_ID                      ),
    .ADDR_ECC_PROT_EN          (1                                 ),
    .ADDR_LOG_EN               (1                                 ),
    .ADDR_INDEX                (DATA_WD_NP                        ),
    .ADDR_WD                   (DATA_RAM_ADDR_WD                  )
  ) u_echk_data (
    .clk                       ( clk                              ),
    .rst_n                     ( rstn                             ),
    .din                       ( {dly_data_ram_addrb,
                                  s2_data_ram_doutb[DATA_WD_NP-1:0]}),
    .din_prot                  ( s2_data_ram_doutb[DATA_RAM_DATA_WD-1:DATA_WD_NP]),
    .dout                      ( {data_ram_addrb_ras_dp_pipe,
                                  s3_data_ram_doutb_pipe}         ), //Data is corrected
    .dout_prot                 ( /* Not Connected */              ),
    .en                        (1'b1                              ),
    .bypass                    (1'b0                              ),
    .stall                     (1'b0                              ),
    .stallout                  ( /* Not Connected */              ),
    .valid_in                  (d_dv_out                          ),
    .halt_out                  ( /* Not Connected */              ),
    .valid_out                 ( /* Not Connected */              ),
    .halt_in                   (1'b0                              ),
    .ras_dp_err_inband_kbd_in  (1'b0                              ),
    .ras_dp_err_inband_kbd_out ( /* Not Connected */              ),
    .ras_dp_err_log            (dq_ras_recc_cnt_ras_dp_err_log    )
      ,
      .ras_dp_err_inj          (core_clk_ordrb_ras_dp_err_inj     )
    );

  // Extract and detect Error type (correctable) from ras_dp_pipe.log
  assign dq_ras_recc_corr_cnt_pulse   = (dq_ras_recc_cnt_ras_dp_err_log.log[RAS_ERROR_TYPE_INDEX +: RAS_ERROR_TYPE_WD] == CORRECTABLE) && d_dv_out;

  // Extract and detect Error type (Uncorrectable) from ras_dp_pipe.log
  assign dq_ras_recc_ucorr_cnt_pulse = (dq_ras_recc_cnt_ras_dp_err_log.log[RAS_ERROR_TYPE_INDEX +: RAS_ERROR_TYPE_WD] == UNCORRECTABLE) && d_dv_out;

  assign s3_data_ram_doutb = s3_data_ram_doutb_pipe;

assign s_hdr_out  = {
                     s3_hdr_ram_doutb[HDR_WD_NP-1:(`INBD_HDR_PNP_RANGE_ADDR_LOW-3+ADDR_WD_NP)],//spyglass disable SelfDeterminedExpr-ML
                     fn_addr_w_par(s3_hdr_ram_doutb[`INBD_HDR_PNP_RANGE_ADDR_LOW-3+:ADDR_WD_NP]), //spyglass disable SelfDeterminedExpr-ML
                     s3_hdr_ram_doutb[`INBD_HDR_PNP_RANGE_ADDR_LOW-4:0] //spyglass disable SelfDeterminedExpr-ML
                    };

assign s_data_out = fn_data_w_par(s3_data_ram_doutb); //spyglass disable SelfDeterminedExpr-ML


  //
  // RAM read latency buffer
  //

  ram_latency_pipe
   #(
      .PIPE_WIDTH          ( HDR_WD + DATA_WD + 3 ),
      .PIPE_INPUT_REG      ( 0                    ),
      .PIPE_LATENCY        ( RAM_RD_LATENCY       ),
      .PIPE_EXTRA_STORAGE  ( LTCY_EXTRA_STORAGE   ),
      .HALT_THLD           ( LTCY_HALT_THLD       )
  ) u_ltcy  (
      .core_clk            ( clk                                                          ),
      .core_rst_n          ( rstn                                                         ),
      .pipe_in_data_valid  ( s_hdr_ram_enb || s_data_ram_enb                              ),
      .pipe_in_data        ( {s_data_out     ,s_hdr_out     ,d_eot_out,d_dv_out,d_hv_out} ),
      .halt_out            ( s_ltcy_halt                                                  ),
      .pipe_out_data       ( {s_ltcy_out_data,s_ltcy_out_hdr,s_eot_out,s_dv_out,s_hv_out} ),
      .pipe_out_data_valid ( ltcy_out_valid                                               ),
      .halt_in             ( s_halt_in                                                    )
  );


always@(posedge clk or negedge rstn)begin: R_OUT_SEQ_PROC
  if(!rstn)begin
    r_hv_out       <= #TP '0;
    r_dv_out       <= #TP '0;
    r_eot_out      <= #TP '0;
    r_hdr_out      <= #TP '0;
    r_data_out     <= #TP '0;
  end else begin
    if(!halt_in || !(r_hv_out || r_dv_out))begin
      r_hv_out       <= #TP s_hv_out;
      r_dv_out       <= #TP s_dv_out;
      r_eot_out      <= #TP s_eot_out;
      r_hdr_out      <= #TP s_ltcy_out_hdr;
      r_data_out     <= #TP s_ltcy_out_data;
    end
  end
end

assign hv_out    = r_hv_out;
assign dv_out    = r_dv_out;
assign eot_out   = r_eot_out;
assign hdr_out   = r_hdr_out;
assign data_out  = r_data_out;
assign s_halt_in = halt_in && (r_hv_out || r_dv_out);

  // Address without parity
  function automatic [ADDR_WD_NP-1:0] fn_addr_wo_par;
    input [CC_CORE_ADDR_BUS_WD-1:0] s_addr_w_par;
    integer i,j;
    begin
      for (i=0; i<NUM_ADDR_PAR_BLOCKS; i=i+1)  begin // interate thru parity block size
       for (j=0; j<CX_RAS_PROT_RANGE; j=j+1)  begin // interate thru parity block size bits
          fn_addr_wo_par[i*CX_RAS_PROT_RANGE +j] = s_addr_w_par[i*CX_RAS_PROT_RANGE +j +i];//spyglass disable SelfDeterminedExpr-ML
        end
      end
    end
  endfunction

  // Data without parity
  function automatic [DATA_WD_NP-1:0] fn_data_wo_par;
    input [DATA_WD-1:0] s_data_w_par;
    integer i,j;
    begin
      for (i=0; i<NUM_DATA_PAR_BLOCKS; i=i+1)  begin // interate thru parity block size
       for (j=0; j<CX_RAS_PROT_RANGE; j=j+1)  begin // interate thru parity block size bits
          fn_data_wo_par[i*CX_RAS_PROT_RANGE +j] = s_data_w_par[i*CX_RAS_PROT_RANGE +j +i];//spyglass disable SelfDeterminedExpr-ML
        end
      end
    end
  endfunction

  // Address with parity
  function automatic [CC_CORE_ADDR_BUS_WD-1:0] fn_addr_w_par;
    input [ADDR_WD_NP-1:0] s_addr_wo_par;

    integer i, j;
    reg [CX_RAS_PROT_RANGE-1:0] s_addr_for_par;

    begin
      fn_addr_w_par  = 0;
      s_addr_for_par = 0;
       // SMD: Self determined expression present in the design
       // SJ: Operations over integers. No overflow possible on the configuration space. Any error would be detected by simulation of the RAS.DP framework.
       // spyglass disable_block SelfDeterminedExpr-ML
      for (i=0; i<(NUM_ADDR_PAR_BLOCKS); i=i+1) begin
         for (j=0; j<CX_RAS_PROT_RANGE; j=j+1) begin
           s_addr_for_par[j]=s_addr_wo_par[i*CX_RAS_PROT_RANGE +j];
           fn_addr_w_par[i*CX_RAS_PROT_RANGE +j+i] = s_addr_wo_par[i*CX_RAS_PROT_RANGE +j];
         end
          fn_addr_w_par[(i+1)*CX_RAS_PROT_RANGE +i] = (CX_RAS_PARITY_MODE == '0) ? ^s_addr_for_par : ~(^s_addr_for_par);
      end
       // spyglass enable_block SelfDeterminedExpr-ML
    end
  endfunction

  // Data with parity
  function automatic [DATA_WD-1:0] fn_data_w_par;
    input [DATA_WD_NP-1:0] s_data_wo_par;

    integer i, j;
    reg [CX_RAS_PROT_RANGE-1:0] s_data_for_par;

    begin
      fn_data_w_par  = 0;
      s_data_for_par = 0;
       // SMD: Self determined expression present in the design
       // SJ: Operations over integers. No overflow possible on the configuration space. Any error would be detected by simulation of the RAS.DP framework.
       // spyglass disable_block SelfDeterminedExpr-ML
      for (i=0; i<(NUM_DATA_PAR_BLOCKS); i=i+1) begin
         for (j=0; j<CX_RAS_PROT_RANGE; j=j+1) begin
           s_data_for_par[j]=s_data_wo_par[i*CX_RAS_PROT_RANGE +j];
           fn_data_w_par[i*CX_RAS_PROT_RANGE +j+i] = s_data_wo_par[i*CX_RAS_PROT_RANGE +j];
         end
          fn_data_w_par[(i+1)*CX_RAS_PROT_RANGE +i] = (CX_RAS_PARITY_MODE == '0) ? ^s_data_for_par : ~(^s_data_for_par);
      end
       // spyglass enable_block SelfDeterminedExpr-ML
    end
  endfunction

  function automatic [NUM_ADDR_PAR_BLOCKS-1:0] fn_prot_chkin_ad;
    input [CC_CORE_ADDR_BUS_WD-1:0] s_addr_w_par;
    integer i;
    begin
      for (i=0; i<NUM_ADDR_PAR_BLOCKS; i=i+1) begin
        fn_prot_chkin_ad[i] = s_addr_w_par[i*CX_RAS_PROT_RANGE + i + CX_RAS_PROT_RANGE];
      end
    end
  endfunction

   function automatic [NUM_DATA_PAR_BLOCKS-1:0] fn_prot_chkin_d;
    input [DATA_WD-1:0] s_data_w_par;
    integer i;
    begin
      for (i=0; i<NUM_DATA_PAR_BLOCKS; i=i+1) begin
        fn_prot_chkin_d[i] = s_data_w_par[i*CX_RAS_PROT_RANGE + i + CX_RAS_PROT_RANGE];
      end
    end
  endfunction

// Need assertions to check:
// - segment number is never duplicated
// - no segment number missing (0 to n)

endmodule
