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
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Amba/DWC_pcie_amba_presp_retime.sv#8 $
// -------------------------------------------------------------------------
// Module Description:
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_amba_presp_retime
 #(
  // -------------------------------------------------------------------------------------
  // Parameters modified by an instantiation parameter assignment
  // -------------------------------------------------------------------------------------
  // Minimum CDC fifo setup is 3, two for CDC crossing plus 1 to allow avoiding having
  // FIFO go easily to full state
  // But it takes ar worst 4 core clock cycles to propate the info from input to output
  // In a performance setup 128 bytes MTU and 256 core data width a burst is precisely 4
  // cycles. So 3 FIFO positions is just over the edge, that can be easily bronken by
  // an incoming MSI that consumes one master clock and takes 4 to propagate in this CDC
  // to accomodate a single MSI interleaved with non-MSI posted, 4 CDC positions were
  // selected.
  parameter CDC_FIFO_DEPTH           = 4,
  parameter CDC_FIFO_ADDR_WIDTH      = 2,
  parameter CX_NVC_LOG2              = 1,
  parameter CC_AMBA_TLP_SEQ_WD       = 8,
  parameter CC_DMA_ENABLE_VALUE      = `CC_DMA_ENABLE_VALUE,
  parameter CC_NUM_DMA_RD_CHAN_WIDTH = `CC_NUM_DMA_RD_CHAN_WIDTH,
  parameter P_N_PRESP_STREAMS_WD     = `CX_NVC_LOG2,
  // -------------------------------------------------------------------------------------
  // Parameters not modified by an instantiation parameter assignment
  // -------------------------------------------------------------------------------------
  parameter TP                       = `TP
 )
 (
  // -------------------------------------------------------------------------------------
  // Clocks and resets
  // -------------------------------------------------------------------------------------
  input                                     mstr_aclk ,
  input                                     mstr_aresetn ,
  input                                     core_clock ,
  input                                     core_reset_n ,
  // -------------------------------------------------------------------------------------
  // Responses from the AMBA master in the master clock domain
  // -------------------------------------------------------------------------------------
  input                                     gm_presp_cmplt ,
  input [CC_AMBA_TLP_SEQ_WD-1:0]            gm_presp_rpseq,
  input [1:0]                               gm_presp_type ,
  input [P_N_PRESP_STREAMS_WD-1:0]          gm_presp_stream ,
  input [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]      gm_presp_dma_chan_num ,
  input                                     gm_presp_dma_err ,
  output wire                               rtime_cdc_halt ,
  //almost halt
  output wire                               rtime_cdc_alm_halt,
  // -------------------------------------------------------------------------------------
  // Responses from the AMBA master in the master clock domain
  // -------------------------------------------------------------------------------------
  output reg                                rtime_cmplt ,
  output reg [CC_AMBA_TLP_SEQ_WD-1:0]       rtime_rpseq,
  output reg [CC_NUM_DMA_RD_CHAN_WIDTH-1:0] rtime_dma_chan_num ,
  output reg                                rtime_dma_err ,
  output reg [P_N_PRESP_STREAMS_WD-1:0]     rtime_stream ,
  output reg [1:0]                          rtime_type
  );

  // -------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------
  localparam CDC_FIFO_COUNT_WIDTH = CDC_FIFO_ADDR_WIDTH+1;
  localparam CDC_FIFO_WIDTH = 2 
                            + CC_AMBA_TLP_SEQ_WD
                            + CC_DMA_ENABLE_VALUE * ( 1
                                                    + CC_NUM_DMA_RD_CHAN_WIDTH
                                                    )
                            + P_N_PRESP_STREAMS_WD
                            ;
  localparam CDC_FIFO_PUSH_AE_LVL                  = 1;
  localparam CDC_FIFO_PUSH_AF_LVL                  = 1; // one from full
  localparam CDC_FIFO_POP_AE_LVL                   = 1; // one from empty
  localparam CDC_FIFO_POP_AF_LVL                   = 1;
  localparam CDC_FIFO_ERR_MODE                     = 1'b0; // sticky flag
  localparam CDC_FIFO_PUSH_SYNC                    = `CX_PCIE_SYNC_DEPTH;
  localparam CDC_FIFO_POP_SYNC                     = `CX_PCIE_SYNC_DEPTH;
  localparam CDC_FIFO_HOLD_RD_ADDR                 = 0;
  // Exclude memory reset
  localparam CDC_FIFO_RST_MODE                     = 1;

  typedef struct packed{
    logic [CC_NUM_DMA_RD_CHAN_WIDTH-1:0] dma_chan_num;
    logic                                dma_err;
    logic [CC_AMBA_TLP_SEQ_WD-1:0]       rpseq;
    logic [P_N_PRESP_STREAMS_WD-1:0]     stream;
    logic [1:0]                          typ;
  } intf_struct;


  // -------------------------------------------------------------------------------------
  // Internal wires
  // -------------------------------------------------------------------------------------
  intf_struct s_presp_intf ;
  intf_struct s_rtime_intf ;
  wire [CDC_FIFO_WIDTH-1:0] presp_intf;
  wire [CDC_FIFO_WIDTH-1:0] rtime_intf;

  wire cdc_fifo_pop_empty;

  assign presp_intf   = CDC_FIFO_WIDTH'(s_presp_intf);
  assign s_rtime_intf = intf_struct'(rtime_intf);

  always_comb begin : s_presp_intf_PROC
    s_presp_intf.dma_chan_num = gm_presp_dma_chan_num;
    s_presp_intf.dma_err      = gm_presp_dma_err     ;
    s_presp_intf.rpseq        = gm_presp_rpseq       ;
    s_presp_intf.stream       = gm_presp_stream      ;
    s_presp_intf.typ          = gm_presp_type        ;
  end

  // Instantiate FIFO
  //
  DWC_pcie_amba_cdc_fifo_dff
   #(
     .WIDTH                 ( CDC_FIFO_WIDTH        )
    ,.DEPTH                 ( CDC_FIFO_DEPTH        )
    ,.ADDR_WIDTH            ( CDC_FIFO_ADDR_WIDTH   )
    ,.COUNT_WIDTH           ( CDC_FIFO_COUNT_WIDTH  )
    ,.PUSH_AE_LVL           ( CDC_FIFO_PUSH_AE_LVL  )
    ,.PUSH_AF_LVL           ( CDC_FIFO_PUSH_AF_LVL  )
    ,.POP_AE_LVL            ( CDC_FIFO_POP_AE_LVL   )
    ,.POP_AF_LVL            ( CDC_FIFO_POP_AF_LVL   )
    ,.ERR_MODE              ( CDC_FIFO_ERR_MODE     )
    ,.PUSH_SYNC             ( CDC_FIFO_PUSH_SYNC    )
    ,.POP_SYNC              ( CDC_FIFO_POP_SYNC     )
    ,.RST_MODE              ( CDC_FIFO_RST_MODE     )
    ,.HOLD_RD_ADDR          ( CDC_FIFO_HOLD_RD_ADDR )
    )
    u_cdc_fifo_dff_resp(
       .clk_push            ( mstr_aclk             )
      ,.rst_push_n          ( mstr_aresetn          )
      ,.clk_pop             ( core_clock            )
      ,.rst_pop_n           ( core_reset_n          )
      // Master Response tracker on master clock domain
      ,.push_req_n          ( ~(gm_presp_cmplt ))
      ,.push_data           ( presp_intf            )
      ,.push_af             ( rtime_cdc_alm_halt    )
      ,.push_full           ( rtime_cdc_halt        )
      ,.push_word_count     ( /*UNCONNECTED*/       )
      // Master Response tracker on the core clock domain
      ,.pop_req_n           ( cdc_fifo_pop_empty    )
      ,.pop_empty           ( cdc_fifo_pop_empty    )
      ,.pop_data            ( rtime_intf            )
      ,.halt                ( 1'b0                  )
      );

   always @ (posedge core_clock or negedge core_reset_n) begin : proc_seq_out_reg
      if (!core_reset_n) begin
         rtime_cmplt        <= # TP 1'b0;
         rtime_dma_chan_num <= # TP 'd0;
         rtime_dma_err      <= # TP 1'b0;
         rtime_type         <= # TP 2'd0;
         rtime_rpseq        <= # TP {CC_AMBA_TLP_SEQ_WD{1'b0}};
         rtime_stream       <= # TP '0;
      end else begin
         rtime_cmplt        <= # TP ~cdc_fifo_pop_empty ;
         if (~cdc_fifo_pop_empty) begin
             rtime_dma_chan_num <= # TP s_rtime_intf.dma_chan_num;
             rtime_dma_err      <= # TP s_rtime_intf.dma_err;
             rtime_rpseq        <= # TP s_rtime_intf.rpseq;
             rtime_stream       <= # TP s_rtime_intf.stream;
             rtime_type         <= # TP s_rtime_intf.typ;
         end
      end
   end

endmodule
