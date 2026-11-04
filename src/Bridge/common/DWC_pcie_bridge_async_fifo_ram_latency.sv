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
// ---    $Revision: #11 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/common/DWC_pcie_bridge_async_fifo_ram_latency.sv#11 $
// ---------------------------------------------------------------------------------------
// ---------------------------------------------------------------------------------------
// --- Module Description:
// Independent dual clock crossing FIFO with static programmable
// almost empty and almost full flags
//
// Parameters                        Valid Values
// DATA_WIDTH  [ 1 to 256 ] - Width of the input data bus (does not includes ECC when RAS is enabled)
// ECC_WIDTH   : Number of  ECC bits when CX_RAS_EN is set
// DEPTH       [ 4 to 256 ]
// RAM_ADDR_WIDTH  [ 2 to 8 ]
// COUNT_WIDTH [ 3 to 9 ]
// PUSH_AE_LVL [ 1 to DEPTH-1 ]
// PUSH_AF_LVL [ 1 to DEPTH-1 ]
// POP_AE_LVL  [ 1 to DEPTH-1 ]
// POP_AF_LVL  [ 1 to DEPTH-1 ]
// ERR_MODE    [ 0 = sticky error flag,
//               1 = dynamic error flag ]
// PUSH_SYNC   [ 1 = single synchronized,
//               2 = double synchronized,
//               3 = triple synchronized,
//               4 = quadruple synchronized ]
// POP_SYNC    [ 1 = single synchronized,
//               2 = double synchronized,
//               3 = triple synchronized,
//               4 = quadruple synchronized ]
//`ifndef DWC_NO_TST_MODE
// TST_MODE    [ 0 = test input not connected
//               1 = lock-up latches inserted for scan test ]
//`endif

// ---------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

`include "DWC_pcie_ctl_pkg.svh"

module DWC_pcie_bridge_async_fifo_ram_latency
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::MAX_RAS_PROT_CHK_N;
  import DWC_pcie_ctl_pkg::UNCORRECTABLE;
  import DWC_pcie_ctl_pkg::CORRECTABLE;
  import DWC_pcie_ctl_pkg::RAS_ERROR_TYPE_INDEX;
  import DWC_pcie_ctl_pkg::RAS_ERROR_TYPE_WD;
  import DWC_pcie_ctl_pkg::MAX_SUPPORTED_WD;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
#(
  parameter MULT_RAS_DP_EN                = 1,
  parameter DATA_WIDTH                    = 1,
  parameter RAM_REG_IN                    = 1,
  parameter RAM_RD_LATENCY                = 1,
  parameter ECC_WIDTH                     = 8,
  parameter CX_RAS_RAM_PROT_RANGE         = 64,
  parameter CX_RAS_PARITY_MODE            = `CX_RAS_PARITY_MODE,
  parameter DEPTH                         = 4,
  parameter RAM_ADDR_WIDTH                = 2,

  parameter COUNT_WIDTH                   = 3,
  parameter PUSH_AE_LVL                   = 1,
  parameter PUSH_AF_LVL                   = 1,
  parameter POP_AE_LVL                    = 1,
  parameter POP_AF_LVL                    = 1,
  parameter ERR_MODE                      = 0,
  parameter PUSH_SYNC                     = 2,
  parameter POP_SYNC                      = 2,
  parameter HOLD_RD_ADDR                  = 0,

  parameter RAM_DATA_WIDTH                = DATA_WIDTH + ECC_WIDTH,
  parameter RAS_DP_ID                     = 0,
  parameter RAS_DP_ID_AUX                 = `IB_MCPL_DUAL_RAS_AUX_ID,
  parameter TP                            = `TP

  )
  (
  input                             clk_push,
  input                             rst_push_n,
  input                             clk_pop,
  input                             rst_pop_n,
  // ---------------------------------------------------------------------------
  // RAS.DP register interface
  input                               cfg_ras_correct,
  output wire  [MULT_RAS_DP_EN-1:0]   ras_recc_corr_cnt_pulse,
  output wire  [MULT_RAS_DP_EN-1:0]   ras_recc_ucorr_cnt_pulse,
  output wire  [RAM_ADDR_WIDTH-1:0]   ras_recc_cnt_addr,
  output ras_dp_err_log_t [MULT_RAS_DP_EN-1:0] recc_cnt_ras_dp_err_log,
  input  ras_dp_err_inj_t           ras_dp_err_inj,
  // -------------------------------------------------------------------------------------
  // External RAM interface
  // Write
  output wire                       asfifo_wen,
  output wire [RAM_ADDR_WIDTH-1:0]  asfifo_waddr,
  output wire [RAM_DATA_WIDTH-1:0]  asfifo_wdata,
  // Read
  output wire [RAM_ADDR_WIDTH-1:0]  asfifo_raddr,
  output wire                       asfifo_ren,
  input       [RAM_DATA_WIDTH-1:0]  rdata,
  // -------------------------------------------------------------------------------------
  // Push interface
  input                             push_req_n,
  input [DATA_WIDTH-1:0]            push_data,
  output wire                       asfifo_f,
  output wire                       asfifo_af,
  // -------------------------------------------------------------------------------------
  // Pop interface
  output wire                       asfifo_pop_valid,
  output wire [DATA_WIDTH-1:0]      asfifo_pop_data,
  output wire                       asfifo_e,
  input                             ready
  );

  // -------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------

  // Width of the pipe data on latency path
  localparam LATENCY_PIPE_WIDTH = RAM_DATA_WIDTH
                                  + RAM_ADDR_WIDTH
                                  ;

  // One from full if there is pipeline
  localparam AF_LVL                = (RAM_REG_IN==1) ? 1 : PUSH_AF_LVL;

  // Calculate the physical memory depth:
  // If addressable memory space is equal to 2^DEPTH then the FIFO controller DEPTH
  // parameter and physical memory depth parameter, RAM_DEPTH, are the same.
  // If the DEPTH parameter is odd then RAM_DEPTH = DEPTH+1.
  // If the DEPTH parameter is even then RAM_DEPTH = DEPTH+2.
  localparam RAM_DEPTH  = (DEPTH == (1<<RAM_ADDR_WIDTH)) ?
                          DEPTH :
                          DEPTH + (((DEPTH & 1) == 1) ? 1 : 2);

  // Number of delay cycles from rd request from bcm to read data is ready (excludes latency)
  localparam RAM_TOTAL_LATENCY = RAM_REG_IN + RAM_RD_LATENCY;

  // RAM output data register stage; always ON
  localparam RAM_RD_REG_OUT = 1;

  // Latency pipe halt thershold; assert 1 clock cycle before
  localparam LTCY_HALT_THLD = 1 + RAM_RD_REG_OUT;

  // Number of extra positions on RAM latency buffer.
  // Latency RAM must be dimensioned to consider the time between a pop request
  // and data availability. This is required to avoid bubbles in the output data path
  localparam LTCY_EXTRA_STORAGE = 2 + RAM_RD_REG_OUT + LTCY_HALT_THLD;


  localparam integer REG_DELAY_DENOM = 1000;
  localparam integer REG_DELAY_TIME  = `TP * REG_DELAY_DENOM;

  localparam         MEM_MODE  = 2*`CC_REG_ASYNC_FIFO_PUSH_ADDR+`CC_REG_ASYNC_FIFO_POP_ADDR;
  localparam RAS_DP_ERR_LOG_WD = $clog2(MAX_RAS_PROT_CHK_N)                                     ;

  localparam TOTAL_WIDTH_1     = 2048;
  localparam TOTAL_WIDTH_2     = DATA_WIDTH - TOTAL_WIDTH_1 + (2*RAM_ADDR_WIDTH);
  localparam DATA_WIDTH_1      = TOTAL_WIDTH_1 - RAM_ADDR_WIDTH;
  localparam DATA_WIDTH_2      = DATA_WIDTH - DATA_WIDTH_1;
  localparam ECC_WIDTH_1       = 256;
  localparam ECC_WIDTH_2       = ECC_WIDTH - ECC_WIDTH_1;
  localparam RAM_DATA_ECC_WD_2 = RAM_DATA_WIDTH - ECC_WIDTH_2;

  // -------------------------------------------------------------------------------------
  // Wire/Reg
  // -------------------------------------------------------------------------------------
  wire                                    s_pop_req_n;
  wire                                    s_push_req_n;

  wire                                    fctl_error_push;
  wire                                    fctl_error_pop;

  wire                                    fctl_af;
  wire                                    fctl_wr_en_n;
  wire [RAM_ADDR_WIDTH-1:0]               fctl_wr_addr;
  wire [RAM_ADDR_WIDTH-1:0]               fctl_rd_addr;
  wire                                    fctl_wr_en;
  wire                                    s_rd_en;
  wire [RAM_DATA_WIDTH-1:0]               s_fmem_rdata;
  reg  [RAM_DATA_WIDTH-1:0]               r_fmem_rdata;
  reg  [RAM_DATA_WIDTH-1:0]               ram_fmem_rdata;
  wire [RAM_DATA_WIDTH-1:0]               fmem_rdata;

  wire [RAM_DATA_WIDTH-1:0]               s_ram_in_data;
  reg  [RAM_DATA_WIDTH-1:0]               ram_push_data;
  reg                                     ram_wr_en;
  reg  [RAM_ADDR_WIDTH-1:0]               ram_wr_addr;
  reg  [RAM_ADDR_WIDTH-1:0]               ram_rd_addr;
  reg                                     ram_rd_en;
  wire                                    dly_rd_en;
  reg                                     rd_data_valid;

  wire                                    ltcy_halt_in;
  wire                                    ltcy_halt_out;
  wire [LATENCY_PIPE_WIDTH-1:0]           ltcy_in_data;
  wire [LATENCY_PIPE_WIDTH-1:0]           ltcy_out_data;
  wire [RAM_DATA_WIDTH-1:0]               s_ltcy_out_data;

  wire [ECC_WIDTH-1:0]                    eccg_push_data;

  wire [RAM_ADDR_WIDTH-1:0]               dly_rd_addr;
  wire [RAM_ADDR_WIDTH-1:0]               s_rd_addr;

  reg                                     r_ltcy_out_data_valid;
  reg  [DATA_WIDTH-1:0]                   r_echk_out_data;
  wire [DATA_WIDTH-1:0]                   echk_out_data;
  wire                                    cfg_ras_correct_n;
  wire [DATA_WIDTH-1:0]                   s_echk_out_data   ;
  wire [DATA_WIDTH-1:0]                   s_echk_out_data_1 ;
  wire [DATA_WIDTH-1:0]                   s_echk_out_data_2 ;
  wire [ECC_WIDTH_1-1:0]                  eccg_push_data_1  ;
  wire [ECC_WIDTH_2-1:0]                  eccg_push_data_2  ;


  // -------------------------------------------------------------------------------------
  // Design
  // -------------------------------------------------------------------------------------

  //
  // RAS Generation stage - Calculate the RAM ECC
  //
  // Generator
  generate 
    if (MULT_RAS_DP_EN == 1) begin : single_ras_dp_pipe_eccg

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
    .PROT_RANGE                (CX_RAS_RAM_PROT_RANGE                ), // Number of bits to calculate parity/ECC on
    .PROT_WD                   (ECC_WIDTH                            ),
    .PARITY_MODE               (CX_RAS_PARITY_MODE                   ),
    .PROT_CORRECT_EN           (1                                    ), // 0: no correction on single-errors, 1: correction on single-errors
    .TOTAL_WIDTH               (RAM_ADDR_WIDTH + DATA_WIDTH          ), // RAM_ADDR_WIDTH + DATA_WIDTH
    .EXCLUDE_PROT_WIDTH        (0                                    ),
    .RAS_DP_PROT_CHK_ID_BASE   ( /* NC */                            ),
    .ADDR_ECC_PROT_EN          (1                                    ),
    .ADDR_LOG_EN               (1                                    ),
    .ADDR_INDEX                (DATA_WIDTH                           ),
    .ADDR_WD                   (RAM_ADDR_WIDTH                       )
  ) u_eccg (
    .clk                       ( clk_push                            ),
    .rst_n                     ( rst_push_n                          ),
    .din                       ( {fctl_wr_addr, push_data}           ),
    .din_prot                  ( {ECC_WIDTH{1'b0}}                   ),
    .dout                      ( /* Not Connected */                 ),
    .dout_prot                 ( eccg_push_data                      ),
    .en                        ( 1'b1                                ),
    .bypass                    ( 1'b0                                ),
    .stall                     ( 1'b0                                ),
    .stallout                  ( /* Not Connected */                 ),
    .valid_in                  ( fctl_wr_en                          ),
    .halt_out                  ( /* Not Connected */                 ),
    .valid_out                 ( /* Not Connected */                 ),
    .halt_in                   (1'b0                                 ),
    .ras_dp_err_inband_kbd_in  (1'b0                                 ),
    .ras_dp_err_inband_kbd_out ( /* Not Connected */                 ),
    .ras_dp_err_log            ( /* Not Connected */                 )
      ,
      .ras_dp_err_inj          (ras_dp_err_inj                       )
    );

  end else begin                   : mult_ras_dp_pipe_eccg

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
    .PROT_RANGE                (CX_RAS_RAM_PROT_RANGE                ), // Number of bits to calculate parity/ECC on
    .PROT_WD                   (ECC_WIDTH_1                          ),
    .PARITY_MODE               (CX_RAS_PARITY_MODE                   ),
    .PROT_CORRECT_EN           (1                                    ), // 0: no correction on single-errors, 1: correction on single-errors
    .TOTAL_WIDTH               (TOTAL_WIDTH_1                        ), // RAM_ADDR_WIDTH + DATA_WIDTH
    .EXCLUDE_PROT_WIDTH        (0                                    ),
    .RAS_DP_PROT_CHK_ID_BASE   ( /* NC */                            ),
    .ADDR_ECC_PROT_EN          (1                                    ),
    .ADDR_LOG_EN               (1                                    ),
    .ADDR_INDEX                (DATA_WIDTH_1                         ),
    .ADDR_WD                   (RAM_ADDR_WIDTH                       )
  ) u_eccg_1 (
    .clk                       ( clk_push                            ),
    .rst_n                     ( rst_push_n                          ),
    .din                       ( {fctl_wr_addr,
                                 push_data[DATA_WIDTH_1-1:0]} ),
    .din_prot                  ( {ECC_WIDTH_1{1'b0}}                 ),
    .dout                      ( /* Not Connected */                 ),
    .dout_prot                 ( eccg_push_data[ECC_WIDTH_1-1:0] ),
    .en                        ( 1'b1                                ),
    .bypass                    ( 1'b0                                ),
    .stall                     ( 1'b0                                ),
    .stallout                  ( /* Not Connected */                 ),
    .valid_in                  ( fctl_wr_en                          ),
    .halt_out                  ( /* Not Connected */                 ),
    .valid_out                 ( /* Not Connected */                 ),
    .halt_in                   (1'b0                                 ),
    .ras_dp_err_inband_kbd_in  (1'b0                                 ),
    .ras_dp_err_inband_kbd_out ( /* Not Connected */                 ),
    .ras_dp_err_log            ( /* Not Connected */                 )
      ,
      .ras_dp_err_inj          (ras_dp_err_inj                       )
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
    .PROT_RANGE                (CX_RAS_RAM_PROT_RANGE                ), // Number of bits to calculate parity/ECC on
    .PROT_WD                   (ECC_WIDTH_2                          ),
    .PARITY_MODE               (CX_RAS_PARITY_MODE                   ),
    .PROT_CORRECT_EN           (1                                    ), // 0: no correction on single-errors, 1: correction on single-errors
    .TOTAL_WIDTH               (TOTAL_WIDTH_2                        ), // RAM_ADDR_WIDTH + DATA_WIDTH
    .EXCLUDE_PROT_WIDTH        (0                                    ),
    .RAS_DP_PROT_CHK_ID_BASE   ( /* NC */                            ),
    .ADDR_ECC_PROT_EN          (1                                    ),
    .ADDR_LOG_EN               (1                                    ),
    .ADDR_INDEX                (DATA_WIDTH_2                         ),
    .ADDR_WD                   (RAM_ADDR_WIDTH                       )
  ) u_eccg_2 (
    .clk                       ( clk_push                            ),
    .rst_n                     ( rst_push_n                          ),
    .din                       ( {fctl_wr_addr,
                                  push_data[DATA_WIDTH-1:DATA_WIDTH_1]} ),
    .din_prot                  ( {ECC_WIDTH_2{1'b0}}                 ),
    .dout                      ( /* Not Connected */                 ),
    .dout_prot                 ( eccg_push_data[ECC_WIDTH-1:ECC_WIDTH_1]     ),
    .en                        ( 1'b1                                ),
    .bypass                    ( 1'b0                                ),
    .stall                     ( 1'b0                                ),
    .stallout                  ( /* Not Connected */                 ),
    .valid_in                  ( fctl_wr_en                          ),
    .halt_out                  ( /* Not Connected */                 ),
    .valid_out                 ( /* Not Connected */                 ),
    .halt_in                   (1'b0                                 ),
    .ras_dp_err_inband_kbd_in  (1'b0                                 ),
    .ras_dp_err_inband_kbd_out ( /* Not Connected */                 ),
    .ras_dp_err_log            ( /* Not Connected */                 )
      ,
      .ras_dp_err_inj          (ras_dp_err_inj                       )
    );

  end
endgenerate

  assign s_ram_in_data = {eccg_push_data, push_data};


  //
  // Instantiate FIFO controller
  //
  DWC_pcie_ctl_bcm87
   #(
      .DEPTH                 ( DEPTH            ),
      .ADDR_WIDTH            ( RAM_ADDR_WIDTH   ),
      .COUNT_WIDTH           ( COUNT_WIDTH      ),
      .PUSH_AE_LVL           ( PUSH_AE_LVL      ),
      .PUSH_AF_LVL           ( AF_LVL           ),
      .POP_AE_LVL            ( POP_AE_LVL       ),
      .POP_AF_LVL            ( POP_AF_LVL       ),
      .ERR_MODE              ( ERR_MODE         ),
      .PUSH_SYNC             ( PUSH_SYNC        ),
      .POP_SYNC              ( POP_SYNC         ),
      .REG_DELAY_TIME        ( REG_DELAY_TIME   ),
      .REG_DELAY_DENOM       ( REG_DELAY_DENOM  ),
      .MEM_MODE              ( MEM_MODE         )
  )
  u_fctl (
      // Clocks and resets
      .clk_push              ( clk_push         ),
      .rst_push_n            ( rst_push_n       ),
      .init_push_n           ( 1'b1             ),
      .clk_pop               ( clk_pop          ),
      .rst_pop_n             ( rst_pop_n        ),
      .init_pop_n            ( 1'b1             ),
      // Push interface
      .push_req_n            ( s_push_req_n     ),
      .push_empty            ( /*UNCONNECTED*/  ),
      .push_ae               ( /*UNCONNECTED*/  ),
      .push_hf               ( /*UNCONNECTED*/  ),
      .push_af               ( asfifo_af        ),
      .push_full             ( fctl_af          ),
      .push_error            ( fctl_error_push  ),
      .push_word_count       ( /*UNCONNECTED*/  ),
      // Pop interface
      .pop_req_n             ( s_pop_req_n      ),
      .pop_empty             ( asfifo_e         ),
      .pop_ae                ( /*UNCONNECTED*/  ),
      .pop_hf                ( /*UNCONNECTED*/  ),
      .pop_af                ( /*UNCONNECTED*/  ),
      .pop_full              ( /*UNCONNECTED*/  ),
      .pop_error             ( fctl_error_pop   ),
      .pop_word_count        ( /*UNCONNECTED*/  ),
      // RAM interface
      .we_n                  ( fctl_wr_en_n     ),
      .wr_addr               ( fctl_wr_addr     ),
      .rd_addr               ( fctl_rd_addr     )
  );


  //
  // If PIPELINE is enabled full signal asserts at one from full stage.
  // The FIFO controller is placed before pipeline, thus need to prevent
  // writing data to a location that may still being written. This may happens
  // upon full dsignal de-assertion followed by a new push. The described scenario
  // depends on clock frequencies ratio and also on RAM architectures based on
  // address registering rather than data registering.
  //
  assign asfifo_f = (RAM_REG_IN==1) ? asfifo_af : fctl_af;

  //
  // Disable push while full
  //
  assign s_push_req_n = push_req_n || asfifo_f;

  //
  // Pop unless stalled by the pop interface
  //
  assign s_pop_req_n = !(!asfifo_e && !ltcy_halt_out);

  //
  // Enable the sync RAM
  //
  assign fctl_wr_en = !fctl_wr_en_n;
  assign s_rd_en = !s_pop_req_n;

  //
  // Pipeline RAM interface signals
  //
  generate
     if (RAM_REG_IN == 0) begin : gen_ram_not_reg_in

       always @(*) begin : proc_comb_ram_intf
         ram_wr_en     = fctl_wr_en;
         ram_wr_addr   = fctl_wr_addr;
         ram_rd_en     = s_rd_en;
         ram_rd_addr   = fctl_rd_addr;
         ram_push_data = s_ram_in_data;
       end

     end else begin : gen_ram_reg_in

       always @(posedge clk_push or negedge rst_push_n) begin : proc_seq_ram_push_intf
         if (!rst_push_n) begin
           ram_wr_en     <= # TP 1'b0;
           ram_wr_addr   <= # TP {RAM_ADDR_WIDTH{1'b0}};
           ram_push_data <= # TP {RAM_DATA_WIDTH{1'b0}};
         end else begin
           ram_wr_en     <= # TP fctl_wr_en;
           if (fctl_wr_en) begin
             ram_wr_addr   <= # TP fctl_wr_addr;
             ram_push_data <= # TP s_ram_in_data;
           end
         end
       end

       always @(posedge clk_pop or negedge rst_pop_n) begin : proc_seq_ram_pop_intf
         if (!rst_pop_n) begin
           ram_rd_en     <= # TP 1'b0;
           ram_rd_addr   <= # TP {RAM_ADDR_WIDTH{1'b0}};
         end else begin
           ram_rd_en     <= # TP s_rd_en;
           ram_rd_addr   <= # TP fctl_rd_addr;
         end
       end

     end
  endgenerate


  //
  // Connect to external FIFO RAM Interface
  //
  assign asfifo_wen    = ram_wr_en;
  assign asfifo_waddr  = ram_wr_addr;
  assign asfifo_wdata  = ram_push_data;
  assign asfifo_raddr  = ram_rd_addr;
  assign asfifo_ren    = ram_rd_en;
  assign s_fmem_rdata = rdata;


  //
  // Delay read address for the sake of address reporting
  //
  delay_n
   #(
      .WD       ( RAM_ADDR_WIDTH  ),
      .N        (
                  RAM_RD_LATENCY
                  + 1
                )
  )
  u_dly_rdaddr (
      .clk      ( clk_pop         ),
      .rst_n    ( rst_pop_n       ),
      .clear    ( 1'b0            ),
      .din      ( ram_rd_addr     ),
      .dout     ( dly_rd_addr     )
  );


  //
  // Pipeline RAM output data
  //
  generate
     if (RAM_RD_REG_OUT == 0) begin : gen_ram_not_reg_out

       always @(*) begin : proc_comb_ram_reg_out
         ram_fmem_rdata = s_fmem_rdata;
         rd_data_valid  = ram_rd_en;
       end

     end else begin : gen_ram_reg_out

       always @(posedge clk_pop or negedge rst_pop_n) begin : proc_seq_ram_reg_out
         if (!rst_pop_n) begin
           ram_fmem_rdata  <= # TP {RAM_DATA_WIDTH{1'b0}};
           rd_data_valid   <= # TP 1'b0;
         end else begin
           ram_fmem_rdata  <= # TP s_fmem_rdata;
           rd_data_valid   <= # TP ram_rd_en;
         end
       end

     end
  endgenerate


  delay_n
   #(
      .WD       ( 1  ),
      .N        ( RAM_RD_LATENCY  )
  )
  u_dly_rdreq (
      .clk      ( clk_pop         ),
      .rst_n    ( rst_pop_n       ),
      .clear    ( 1'b0            ),
      .din      ( rd_data_valid   ),
      .dout     ( dly_rd_en       )
  );

  //
  // Hold data between pop requests. Allows the RAM read port to be disabled
  //
  always @(posedge clk_pop or negedge rst_pop_n) begin : proc_seq_mem_data
    if (!rst_pop_n) begin
      r_fmem_rdata <= # TP {RAM_DATA_WIDTH{1'b0}};
    end
    else begin
      if (dly_rd_en) begin
        r_fmem_rdata <= # TP ram_fmem_rdata;
      end
    end
  end

  assign fmem_rdata = dly_rd_en ? ram_fmem_rdata : r_fmem_rdata;

  assign ltcy_in_data = {
                         dly_rd_addr,
                         fmem_rdata
                         };

  //
  // RAM read latency buffer
  //
  ram_latency_pipe
   #(
      .PIPE_WIDTH          ( LATENCY_PIPE_WIDTH  ),
      .PIPE_INPUT_REG      ( 0                   ),
      .PIPE_LATENCY        ( RAM_RD_LATENCY      ),
      .PIPE_EXTRA_STORAGE  ( LTCY_EXTRA_STORAGE  ),
      .HALT_THLD           ( LTCY_HALT_THLD      )
  )
  u_ltcy (
      .core_clk            ( clk_pop             ),
      .core_rst_n          ( rst_pop_n           ),
      .pipe_in_data_valid  ( rd_data_valid       ),
      .pipe_in_data        ( ltcy_in_data        ),
      .halt_out            ( ltcy_halt_out       ),
      .pipe_out_data       ( ltcy_out_data       ),
      .pipe_out_data_valid ( ltcy_out_data_valid ),
      .halt_in             ( ltcy_halt_in        )
  );

  assign {
         s_rd_addr ,
         s_ltcy_out_data
         } = ltcy_out_data;



  //
  // RAS ECC checking
  //
  assign cfg_ras_correct_n = ~cfg_ras_correct;
  assign ras_recc_cnt_addr = s_rd_addr;
  wire [RAM_ADDR_WIDTH-1:0] s_echk_out_addr;

 generate
 if (MULT_RAS_DP_EN == 1) begin  : single_ras_dp_pipe_echk

  ras_dp_pipe
   #(
    .PIPELINE_TYPE             (0                                    ), // 0: delay_n
    .RESETVAL                  (0                                    ),
    .N_STAGES                  (0                                    ),
    .CAN_STALL                 (0                                    ),
    .RESET_STALL               (0                                    ),
    .BUS_PROTECT_GEN_EN        (0                                    ),  // 0: Bus Protection Generator is not present
    .BUS_PROTECT_CHK_EN        (1                                    ),  // 1: Bus Protection Checker is present (ECC/Parity)
    .PROT_TYPE                 (0                                    ),  // 0=Ecc, 1=Simple Parity
    .PROT_RANGE                (CX_RAS_RAM_PROT_RANGE                ), // Number of bits to calculate parity/ECC on
    .PROT_WD                   (ECC_WIDTH                            ),
    .PARITY_MODE               (CX_RAS_PARITY_MODE                   ),
    .PROT_CORRECT_EN           (1                                    ), // 0: no correction on single-errors, 1: correction on single-errors
    .TOTAL_WIDTH               (RAM_ADDR_WIDTH + DATA_WIDTH          ),
    .EXCLUDE_PROT_WIDTH        (0                                    ),
    .RAS_DP_PROT_CHK_ID_BASE   (RAS_DP_ID                            ),
    .ADDR_ECC_PROT_EN          (1                                    ),
    .ADDR_LOG_EN               (1                                    ),
    .ADDR_INDEX                (DATA_WIDTH                           ),
    .ADDR_WD                   (RAM_ADDR_WIDTH                       )
  ) u_echk (
    .clk                       ( clk_pop                             ),
    .rst_n                     ( rst_pop_n                           ),
    .din                       ( {s_rd_addr,
                                  s_ltcy_out_data[DATA_WIDTH-1:0]}   ),
    .din_prot                  ( s_ltcy_out_data[RAM_DATA_WIDTH-1:DATA_WIDTH]),
    .dout                      ( {s_echk_out_addr,s_echk_out_data}   ), //Data is corrected
    .dout_prot                 ( /* Not Connected */                 ),
    .en                        (1'b1                                 ),
    .bypass                    (1'b0                                 ),
    .stall                     (1'b0                                 ),
    .stallout                  ( /* Not Connected */                 ),
    .valid_in                  ( ltcy_out_data_valid                 ),
    .halt_out                  ( /* Not Connected */                 ),
    .valid_out                 ( /* Not Connected */                 ),
    .halt_in                   (1'b0                                 ),
    .ras_dp_err_inband_kbd_in  (1'b0                                 ),
    .ras_dp_err_inband_kbd_out ( /* Not Connected */                 ),
    .ras_dp_err_log            (recc_cnt_ras_dp_err_log[0])
      ,
      .ras_dp_err_inj          (ras_dp_err_inj                       )
    );

 end else begin                  : mult_ras_dp_pipe_echk
  wire [RAM_ADDR_WIDTH-1:0] s_echk_out_addr_1;

  ras_dp_pipe
   #(
    .PIPELINE_TYPE             (0                                    ), // 0: delay_n
    .RESETVAL                  (0                                    ),
    .N_STAGES                  (0                                    ),
    .CAN_STALL                 (0                                    ),
    .RESET_STALL               (0                                    ),
    .BUS_PROTECT_GEN_EN        (0                                    ),  // 0: Bus Protection Generator is not present
    .BUS_PROTECT_CHK_EN        (1                                    ),  // 1: Bus Protection Checker is present (ECC/Parity)
    .PROT_TYPE                 (0                                    ),  // 0=Ecc, 1=Simple Parity
    .PROT_RANGE                (CX_RAS_RAM_PROT_RANGE                ), // Number of bits to calculate parity/ECC on
    .PROT_WD                   (ECC_WIDTH_1                          ),
    .PARITY_MODE               (CX_RAS_PARITY_MODE                   ),
    .PROT_CORRECT_EN           (1                                    ), // 0: no correction on single-errors, 1: correction on single-errors
    .TOTAL_WIDTH               (TOTAL_WIDTH_1                        ),
    .EXCLUDE_PROT_WIDTH        (0                                    ),
    .RAS_DP_PROT_CHK_ID_BASE   (RAS_DP_ID                            ),
    .ADDR_ECC_PROT_EN          (1                                    ),
    .ADDR_LOG_EN               (1                                    ),
    .ADDR_INDEX                (DATA_WIDTH_1                         ),
    .ADDR_WD                   (RAM_ADDR_WIDTH                       )
  ) u_echk_1 (
    .clk                       ( clk_pop                             ),
    .rst_n                     ( rst_pop_n                           ),
    .din                       ( {s_rd_addr,
                                  s_ltcy_out_data[DATA_WIDTH_1-1:0]}        ),
    .din_prot                  ( s_ltcy_out_data[RAM_DATA_ECC_WD_2-1:DATA_WIDTH] ),
    .dout                      ( {s_echk_out_addr,s_echk_out_data[DATA_WIDTH_1-1:0]} ), //Data is corrected
    .dout_prot                 ( /* Not Connected */                 ),
    .en                        (1'b1                                 ),
    .bypass                    (1'b0                                 ),
    .stall                     (1'b0                                 ),
    .stallout                  ( /* Not Connected */                 ),
    .valid_in                  ( ltcy_out_data_valid                 ),
    .halt_out                  ( /* Not Connected */                 ),
    .valid_out                 ( /* Not Connected */                 ),
    .halt_in                   (1'b0                                 ),
    .ras_dp_err_inband_kbd_in  (1'b0                                 ),
    .ras_dp_err_inband_kbd_out ( /* Not Connected */                 ),
    .ras_dp_err_log            (recc_cnt_ras_dp_err_log[MULT_RAS_DP_EN-1])
      ,
      .ras_dp_err_inj          (ras_dp_err_inj                       )
    );

  ras_dp_pipe
   #(
    .PIPELINE_TYPE             (0                                    ), // 0: delay_n
    .RESETVAL                  (0                                    ),
    .N_STAGES                  (0                                    ),
    .CAN_STALL                 (0                                    ),
    .RESET_STALL               (0                                    ),
    .BUS_PROTECT_GEN_EN        (0                                    ),  // 0: Bus Protection Generator is not present
    .BUS_PROTECT_CHK_EN        (1                                    ),  // 1: Bus Protection Checker is present (ECC/Parity)
    .PROT_TYPE                 (0                                    ),  // 0=Ecc, 1=Simple Parity
    .PROT_RANGE                (CX_RAS_RAM_PROT_RANGE                ), // Number of bits to calculate parity/ECC on
    .PROT_WD                   (ECC_WIDTH_2                          ),
    .PARITY_MODE               (CX_RAS_PARITY_MODE                   ),
    .PROT_CORRECT_EN           (1                                    ), // 0: no correction on single-errors, 1: correction on single-errors
    .TOTAL_WIDTH               (TOTAL_WIDTH_2                        ),
    .EXCLUDE_PROT_WIDTH        (0                                    ),
    .RAS_DP_PROT_CHK_ID_BASE   (RAS_DP_ID_AUX                        ),
    .ADDR_ECC_PROT_EN          (1                                    ),
    .ADDR_LOG_EN               (1                                    ),
    .ADDR_INDEX                (DATA_WIDTH_2                         ),
    .ADDR_WD                   (RAM_ADDR_WIDTH                       )
  ) u_echk_2 (
    .clk                       ( clk_pop                             ),
    .rst_n                     ( rst_pop_n                           ),
    .din                       ( {s_rd_addr,
                                  s_ltcy_out_data[DATA_WIDTH-1:DATA_WIDTH_1]}             ),
    .din_prot                  ( s_ltcy_out_data[RAM_DATA_WIDTH-1:RAM_DATA_ECC_WD_2] ),
    .dout                      ( {s_echk_out_addr_1,s_echk_out_data[DATA_WIDTH-1:DATA_WIDTH_1]} ), //Data is corrected
    .dout_prot                 ( /* Not Connected */                 ),
    .en                        (1'b1                                 ),
    .bypass                    (1'b0                                 ),
    .stall                     (1'b0                                 ),
    .stallout                  ( /* Not Connected */                 ),
    .valid_in                  ( ltcy_out_data_valid                 ),
    .halt_out                  ( /* Not Connected */                 ),
    .valid_out                 ( /* Not Connected */                 ),
    .halt_in                   (1'b0                                 ),
    .ras_dp_err_inband_kbd_in  (1'b0                                 ),
    .ras_dp_err_inband_kbd_out ( /* Not Connected */                 ),
    .ras_dp_err_log            (recc_cnt_ras_dp_err_log[0]           )
      ,
      .ras_dp_err_inj          (ras_dp_err_inj                       )
    );

  end
endgenerate

genvar i;
generate
  for (i = MULT_RAS_DP_EN-1; i >= 0; i=i-1) begin
    assign ras_recc_corr_cnt_pulse[i]                 = (recc_cnt_ras_dp_err_log[i].log[RAS_ERROR_TYPE_INDEX +: RAS_ERROR_TYPE_WD] == CORRECTABLE) &&
                                                        (ltcy_out_data_valid & !ltcy_halt_in) && recc_cnt_ras_dp_err_log[i].valid;

    assign ras_recc_ucorr_cnt_pulse[i]                = (recc_cnt_ras_dp_err_log[i].log[RAS_ERROR_TYPE_INDEX +: RAS_ERROR_TYPE_WD] == UNCORRECTABLE) &&
                                                        (ltcy_out_data_valid & !ltcy_halt_in) && recc_cnt_ras_dp_err_log[i].valid;
  end
endgenerate

  assign echk_out_data = s_echk_out_data;

  //
  // Register output data to break timing
  //
  always @(posedge clk_pop or negedge rst_pop_n) begin : proc_seq_ecc_pipeline
    if (!rst_pop_n) begin
      r_ltcy_out_data_valid  <= # TP 1'b0;
      r_echk_out_data        <= # TP {DATA_WIDTH{1'b0}};
    end else if (!ltcy_halt_in) begin
      r_ltcy_out_data_valid  <= # TP ltcy_out_data_valid;
      r_echk_out_data        <= # TP echk_out_data;
    end
  end

  assign ltcy_halt_in = !ready && r_ltcy_out_data_valid;

  assign asfifo_pop_data = r_echk_out_data;
  assign asfifo_pop_valid = r_ltcy_out_data_valid;



`ifndef SYNTHESIS
`endif
endmodule
