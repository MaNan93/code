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
// ---    $Revision: #10 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/common/DWC_pcie_bridge_sync_fifo_ram_latency.sv#10 $
// ---------------------------------------------------------------------------------------
// ---------------------------------------------------------------------------------------
// --- Module Description:
// ---------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"


 module DWC_pcie_bridge_sync_fifo_ram_latency
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::MAX_RAS_PROT_CHK_N;
  import DWC_pcie_ctl_pkg::UNCORRECTABLE;
  import DWC_pcie_ctl_pkg::CORRECTABLE;
  import DWC_pcie_ctl_pkg::RAS_ERROR_TYPE_INDEX;
  import DWC_pcie_ctl_pkg::RAS_ERROR_TYPE_WD;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
 #(
  parameter DATA_WIDTH                    = 1,
  parameter RAM_REG_IN                    = 1,
  parameter RAM_RD_LATENCY                = 1,
  parameter ECC_WIDTH                     = 8,
  parameter CX_RAS_RAM_PROT_RANGE         = 64,
  parameter CX_RAS_PARITY_MODE            = `CX_RAS_PARITY_MODE,
  parameter RAS_DP_ID                     = 2,
  parameter RAM_DEPTH                     = 4,
  parameter RAM_ADDR_WIDTH                = 2,
  parameter AF_LVL                        = {RAM_ADDR_WIDTH{1'b1}},

  parameter RAM_DATA_WIDTH                = DATA_WIDTH + ECC_WIDTH,


  parameter TP                            = `TP

  )
  (
  input                             clk,
  input                             rst_n,
  // ---------------------------------------------------------------------------
  // RAS.DP register interface
  input                             cfg_ras_correct,
  output wire                       ras_recc_corr_cnt_pulse,
  output wire                       ras_recc_ucorr_cnt_pulse,
  output wire [RAM_ADDR_WIDTH-1:0]  ras_recc_cnt_addr,
  output ras_dp_err_log_t           recc_syn_fifo_ras_dp_err_log,
  input ras_dp_err_inj_t           ras_dp_err_inj,
  // -------------------------------------------------------------------------------------
  // External RAM interface
  // Write
  output wire                       sfifo_wen,
  output wire [RAM_ADDR_WIDTH-1:0]  sfifo_waddr,
  output wire [RAM_DATA_WIDTH-1:0]  sfifo_wdata,
  // Read
  output wire [RAM_ADDR_WIDTH-1:0]  sfifo_raddr,
  output wire                       sfifo_ren,
  input       [RAM_DATA_WIDTH-1:0]  rdata,
  // -------------------------------------------------------------------------------------
  // Push interface
  input                             push_req_n,
  input [DATA_WIDTH-1:0]            push_data,
  output wire                       sfifo_f,
  output wire                       sfifo_af,
  // -------------------------------------------------------------------------------------
  // Pop interface
  output wire                       sfifo_pop_valid,
  output wire [DATA_WIDTH-1:0]      sfifo_pop_data,
  output wire                       sfifo_e,
  input                             ready
  );


  // -------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------

  localparam AE_LVL                           = {RAM_ADDR_WIDTH{1'b0}};

  // under/overflow and pointer checking
  localparam ERR_MODE                         = 1'b0;

  // DIAG_MODE_N applies if ERR_MODE !=0
  localparam DIAG_MODE_N                      = 1'b1;

  // Width of the pipe data on latency path
  localparam LATENCY_PIPE_WIDTH = RAM_DATA_WIDTH
                                  + RAM_ADDR_WIDTH
                                  ;

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
  localparam RAS_DP_ERR_LOG_WD = $clog2(MAX_RAS_PROT_CHK_N);

  // -------------------------------------------------------------------------------------
  // Wire/Reg
  // -------------------------------------------------------------------------------------
  wire                                     s_pop_req_n;
  wire                                     s_push_req_n;

  wire                                     fctl_error;

  wire                                     fctl_wr_en_n;
  wire [RAM_ADDR_WIDTH-1:0]                fctl_wr_addr;
  wire [RAM_ADDR_WIDTH-1:0]                fctl_rd_addr;
  wire                                     fctl_wr_en;
  wire                                     s_rd_en;
  wire [RAM_DATA_WIDTH-1:0]                s_fmem_rdata;
  reg  [RAM_DATA_WIDTH-1:0]                r_fmem_rdata;
  reg  [RAM_DATA_WIDTH-1:0]                ram_fmem_rdata;
  wire [RAM_DATA_WIDTH-1:0]                fmem_rdata;

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
  wire                                    cfg_ras_correct_n;
  wire                                    chk_recc_corr_cnt_pulse;
  wire                                    chk_recc_ucorr_cnt_pulse;

  wire [RAM_ADDR_WIDTH-1:0]               dly_rd_addr;
  wire [RAM_ADDR_WIDTH-1:0]               s_rd_addr;

  reg                                     r_ltcy_out_data_valid;
  reg  [DATA_WIDTH-1:0]                   r_echk_out_data;
   wire [DATA_WIDTH-1:0]                  s_echk_out_data;
  wire [DATA_WIDTH-1:0]                   echk_out_data;



  // -------------------------------------------------------------------------------------
  // Design
  // -------------------------------------------------------------------------------------

  //
  // RAS Generation stage - Calculate the RAM ECC
  //

  ras_dp_pipe
  
   #(
    .PIPELINE_TYPE             (0                               ), // 0: delay_n
    .RESETVAL                  (0                               ),
    .N_STAGES                  (0                               ),
    .CAN_STALL                 (0                               ),
    .RESET_STALL               (0                               ),
    .BUS_PROTECT_GEN_EN        (1                               ),  // 0: Bus Protection Generator is not present
    .BUS_PROTECT_CHK_EN        (0                               ),  // 1: Bus Protection Checker is present (ECC/Parity)
    .PROT_TYPE                 (0                               ),  // 0=Ecc, 1=Simple Parity
    .PROT_RANGE                (CX_RAS_RAM_PROT_RANGE           ), // Number of bits to calculate parity/ECC on
    .PROT_WD                   (ECC_WIDTH                       ),
    .PARITY_MODE               (CX_RAS_PARITY_MODE              ),
    .PROT_CORRECT_EN           (1                               ), // 0: no correction on single-errors, 1: correction on single-errors
    .TOTAL_WIDTH               (RAM_ADDR_WIDTH + DATA_WIDTH     ), // RAM_ADDR_WIDTH + DATA_WIDTH
    .EXCLUDE_PROT_WIDTH        (0                               ),
    .RAS_DP_PROT_CHK_ID_BASE   (100                             ),
    .ADDR_ECC_PROT_EN          (1                               ),
    .ADDR_LOG_EN               (1                               ),
    .ADDR_INDEX                (DATA_WIDTH                      ),
    .ADDR_WD                   (RAM_ADDR_WIDTH                  )
  ) u_eccg (
    .clk                       ( clk                            ),
    .rst_n                     ( rst_n                          ),
    .din                       ( {fctl_wr_addr, push_data}      ), // Address in MSB and data in LSB
    .din_prot                  ( {ECC_WIDTH{1'b0}}              ),
    .dout                      ( /* Not Connected */            ),
    .dout_prot                 ( eccg_push_data                 ),
    .en                        ( 1'b1                           ),
    .bypass                    ( 1'b0                           ),
    .stall                     ( 1'b0                           ),
    .stallout                  ( /* Not Connected */            ),
    .valid_in                  ( fctl_wr_en                     ),
    .halt_out                  ( /* Not Connected */            ),
    .valid_out                 ( /* Not Connected */            ),
    .halt_in                   ( 1'b0                           ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                           ),
    .ras_dp_err_inband_kbd_out ( /* Not Connected */            ),
    .ras_dp_err_log            ( /* Not Connected */            )
      ,
      .ras_dp_err_inj          (ras_dp_err_inj                  )
    );


  assign s_ram_in_data = {eccg_push_data, push_data};


  //
  // Instantiate FIFO controller
  //
  DWC_pcie_ctl_bcm86
   #(
      .DEPTH                ( RAM_DEPTH       ),
      .ERR_MODE             ( ERR_MODE        ),
      .ADDR_WIDTH           ( RAM_ADDR_WIDTH  ),
      .REG_DELAY_TIME       ( REG_DELAY_TIME  ),
      .REG_DELAY_DENOM      ( REG_DELAY_DENOM )
  )
  u_fctl (
      .clk                  ( clk             ),
      .rst_n                ( rst_n           ),
      .init_n               ( 1'b1            ),
      .diag_n               ( DIAG_MODE_N     ),
      .af_thresh            ( AF_LVL          ),
      .ae_level             ( AE_LVL          ),
      // Push interface
      .push_req_n           ( s_push_req_n    ),
      .almost_full          ( sfifo_af        ),
      .full                 ( sfifo_f         ),
      .half_full            (                 ),
      // Pop interface
      .pop_req_n            ( s_pop_req_n     ),
      .almost_empty         (                 ),
      .empty                ( sfifo_e         ),
      .wrd_count            (                 ),
      .error                ( fctl_error      ),
      // RAM interface
      .we_n                 ( fctl_wr_en_n    ),
      .wr_addr              ( fctl_wr_addr    ),
      .rd_addr              ( fctl_rd_addr    ),
      .nxt_empty_n          (                 ),
      .nxt_full             (                 ),
      .nxt_error            (                 )
  );

  //
  // Disable push while full
  //
  assign s_push_req_n = push_req_n || sfifo_f;

  //
  // Pop unless stalled by the pop interface
  //
  assign s_pop_req_n = !(!sfifo_e && !ltcy_halt_out);

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

       always @(posedge clk or negedge rst_n) begin : proc_seq_ram_intf
         if (!rst_n) begin
           ram_wr_en     <= # TP 1'b0;
           ram_wr_addr   <= # TP {RAM_ADDR_WIDTH{1'b0}};
           ram_push_data <= # TP {RAM_DATA_WIDTH{1'b0}};
           ram_rd_en     <= # TP 1'b0;
           ram_rd_addr   <= # TP {RAM_ADDR_WIDTH{1'b0}};
         end else begin
           ram_wr_en     <= # TP fctl_wr_en;
           if (fctl_wr_en) begin
             ram_wr_addr   <= # TP fctl_wr_addr;
             ram_push_data <= # TP s_ram_in_data;
           end
           ram_rd_en     <= # TP s_rd_en;
           ram_rd_addr   <= # TP fctl_rd_addr;
         end
       end

     end
  endgenerate


  //
  // Connect to external FIFO RAM Interface
  //
  assign sfifo_wen    = ram_wr_en;
  assign sfifo_waddr  = ram_wr_addr;
  assign sfifo_wdata  = ram_push_data;
  assign sfifo_raddr  = ram_rd_addr;
  assign sfifo_ren    = ram_rd_en;
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
      .clk      ( clk                ),
      .rst_n    ( rst_n              ),
      .clear    ( 1'b0               ),
      .din      ( ram_rd_addr        ),
      .dout     ( dly_rd_addr        )
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

       always @(posedge clk or negedge rst_n) begin : proc_seq_ram_reg_out
         if (!rst_n) begin
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
      .WD       ( 1                  ),
      .N        ( RAM_RD_LATENCY     )
  )
  u_dly_rdreq (
      .clk      ( clk                ),
      .rst_n    ( rst_n              ),
      .clear    ( 1'b0               ),
      .din      ( rd_data_valid      ),
      .dout     ( dly_rd_en          )
  );

  //
  // Hold data between pop requests. Allows the RAM read port to be disabled
  //
  always @(posedge clk or negedge rst_n) begin : proc_seq_mem_data
    if (!rst_n) begin
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
      .core_clk            ( clk                 ),
      .core_rst_n          ( rst_n               ),
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
    .clk                       ( clk                                 ),
    .rst_n                     ( rst_n                               ),
    .din                       ( {s_rd_addr,
                                  s_ltcy_out_data[DATA_WIDTH-1:0]}   ),
    .din_prot                  ( s_ltcy_out_data[RAM_DATA_WIDTH-1:DATA_WIDTH]),
    .dout                      ( {s_echk_out_addr,s_echk_out_data}   ),
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
    .ras_dp_err_log            (recc_syn_fifo_ras_dp_err_log         )
      ,
      .ras_dp_err_inj          (ras_dp_err_inj)
    );

  // Extract and detect Error type (correctable) from ras_dp_pipe.log
  assign chk_recc_corr_cnt_pulse   = (recc_syn_fifo_ras_dp_err_log.log[RAS_ERROR_TYPE_INDEX +: RAS_ERROR_TYPE_WD] == CORRECTABLE) &&
                                     (ltcy_out_data_valid & !ltcy_halt_in) && recc_syn_fifo_ras_dp_err_log.valid;

  // Extract and detect Error type (Uncorrectable) from ras_dp_pipe.log
  assign chk_recc_ucorr_cnt_pulse  = (recc_syn_fifo_ras_dp_err_log.log[RAS_ERROR_TYPE_INDEX +: RAS_ERROR_TYPE_WD] == UNCORRECTABLE) &&
                                     (ltcy_out_data_valid & !ltcy_halt_in) && recc_syn_fifo_ras_dp_err_log.valid;

  assign echk_out_data = (ltcy_out_data_valid & !ltcy_halt_in) ? s_echk_out_data : s_ltcy_out_data[DATA_WIDTH-1:0];

  assign ras_recc_corr_cnt_pulse  = chk_recc_corr_cnt_pulse  & ltcy_out_data_valid & !ltcy_halt_in;
  assign ras_recc_ucorr_cnt_pulse = chk_recc_ucorr_cnt_pulse & ltcy_out_data_valid & !ltcy_halt_in;

  //
  // Register output data to break timing
  //
  always @(posedge clk or negedge rst_n) begin : proc_seq_ecc_pipeline
    if (!rst_n) begin
      r_ltcy_out_data_valid  <= # TP 1'b0;
      r_echk_out_data        <= # TP {DATA_WIDTH{1'b0}};
    end else if (!ltcy_halt_in) begin
      r_ltcy_out_data_valid  <= # TP ltcy_out_data_valid;
      r_echk_out_data        <= # TP echk_out_data;
    end
  end

  assign ltcy_halt_in = !ready && r_ltcy_out_data_valid;

  assign sfifo_pop_data = r_echk_out_data;
  assign sfifo_pop_valid = r_ltcy_out_data_valid;




`ifndef SYNTHESIS
`endif

endmodule
